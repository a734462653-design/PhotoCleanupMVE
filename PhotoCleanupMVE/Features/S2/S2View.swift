import Foundation
import SwiftUI
import UIKit

struct S2PhotoSwitchHapticFeedback {
    enum Source: Equatable {
        case bottomStripDrag
        case nativePaging
    }

    let selectionChanged: () -> Void

    static let live = S2PhotoSwitchHapticFeedback {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    func notify(isEnabled: Bool, source: Source) {
        guard isEnabled, source == .bottomStripDrag else {
            return
        }
        selectionChanged()
    }
}

enum S2BottomStripPhotoSwitcher {
    @discardableResult
    static func switchPhoto(
        machine: S2StateMachine,
        by offset: Int,
        onPhotoSwitch: () -> Void
    ) -> Bool {
        guard machine.changeCurrentPhotoDuringBottomStripDrag(
            by: offset
        ) else {
            return false
        }
        onPhotoSwitch()
        return true
    }
}

struct S2ImageContentContext {
    let assetID: String
    let fittedSize: CGSize
    let requestBaseSize: CGSize
    let contentMode: ContentMode
    let scale: CGFloat
    let requestStrategy: S2ImageRequestStrategy?
    let requestRevision: Int
    let onRequestReading: (S2ImageRequestReading) -> Void
    /// IC-079 R1：图像加载态回调，仅供诊断埋点记录。
    var onLoadStateChange: (S2ImageLoadState) -> Void = { _ in }
}

struct S2BottomStripItemPresentation {
    let assetID: String
    let index: Int
    let isCurrent: Bool
    let isMarked: Bool
    let stripState: S2BottomStripState
}

/// IC-075（v15 回写决策 29）：确认页入口的呈现只由会话合并待删总数决定——
/// 大于 0 时显示纯数字徽标并可点击；等于 0 时不渲染徽标且入口禁用。
struct S2ConfirmationEntryPresentation: Equatable {
    let sessionPendingCount: Int

    var isEnabled: Bool {
        sessionPendingCount > 0
    }

    var showsBadge: Bool {
        isEnabled
    }

    var badgeText: String? {
        showsBadge ? String(sessionPendingCount) : nil
    }

    var accessibilityLabel: String {
        let replacements = ["count": String(sessionPendingCount)]
        if isEnabled {
            return L10n.text(
                "s2.confirm.accessibility",
                replacing: replacements
            )
        }
        return L10n.text(
            "s2.confirm.disabled.accessibility",
            replacing: replacements
        )
    }
}

/// IC-075（v15 第六节第 1 部分）：横栏待删标记由横栏视图自身叠加在缩略图右上角
/// 内侧，不依赖内容闭包，因此生产与夹具路径同时生效；静止态与滑动态相同。
struct S2BottomStripMarkPresentation: Equatable {
    static let symbolName = "trash.circle.fill"

    let isShown: Bool
    let size: CGFloat

    static func make(
        isMarked: Bool,
        markSize: CGFloat
    ) -> S2BottomStripMarkPresentation {
        S2BottomStripMarkPresentation(
            isShown: isMarked,
            size: max(0, markSize)
        )
    }
}

/// IC-075（v15 S2-1 / S2-4）：主图待删标记是视口右上角的浮层，只在 `V=显示`
/// 且 `c ∈ D` 时渲染；它不参与照片几何，也不触发任何几何写入。已标记照片再次
/// 上滑时消费 `.alreadyMarked` 并做一次 scale 脉冲；`V=隐藏` 时通知照常消费、不脉冲。
final class S2PrimaryMarkPresenter: ObservableObject {
    static let symbolName = "trash.circle.fill"

    @Published private(set) var pulseID = 0
    private(set) var pulseCount = 0
    private(set) var consumedNoticeCount = 0

    static func showsMark(
        interfaceVisibility: S2InterfaceVisibility,
        isMarked: Bool
    ) -> Bool {
        interfaceVisibility == .visible && isMarked
    }

    /// ④ 本卡取定的占位派生值：主图标记尺寸 = `bottomStripMarkSize × 2`，不新增参数。
    static func markSize(bottomStripMarkSize: Double) -> CGFloat {
        CGFloat(max(0, bottomStripMarkSize)) * 2
    }

    @discardableResult
    func consume(
        _ notice: S2SemanticNotice?,
        interfaceVisibility: S2InterfaceVisibility
    ) -> Bool {
        guard let notice else {
            return false
        }
        consumedNoticeCount += 1
        guard case .alreadyMarked = notice,
              interfaceVisibility == .visible else {
            return false
        }
        pulseCount += 1
        pulseID += 1
        return true
    }
}

/// v15 回写决策 24：主图视口背景深色模式纯黑、浅色模式纯白，随 trait 实时切换。
/// `UIColor.systemBackground` 在 iOS 上恰为这两个值；本枚举是视口背景的唯一定义处，
/// 主图加载中的背景也复用它（IC-077）。
enum S2ViewportBackground {
    static let uiColor = UIColor.systemBackground

    static var color: Color {
        Color(uiColor: uiColor)
    }
}

/// IC-076（v15 回写决策 29）：写入失败的底部短 toast。由状态机的一次性反馈事件驱动，
/// 时长为定案参数 `feedbackToastDurationMilliseconds`；同一时刻只显示一条，新事件替换
/// 旧事件（旧事件的到期不再清除新事件）。计时经 `scheduler` 注入，测试不依赖真实时钟。
final class S2FeedbackToastPresenter: ObservableObject {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    @Published private(set) var activeEvent: S2FeedbackEvent?
    private(set) var presentedCount = 0
    private(set) var lastScheduledDurationSeconds: TimeInterval?
    private var generation = 0
    private let scheduler: Scheduler

    init(
        scheduler: @escaping Scheduler = { delay, action in
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay,
                execute: action
            )
        }
    ) {
        self.scheduler = scheduler
    }

    static func text(for kind: S2FeedbackEventKind) -> String {
        switch kind {
        case .favoriteWriteFailed:
            return L10n.text("s2.feedback.favorite_failed")
        case .albumAdditionFailed:
            return L10n.text("s2.feedback.album_addition_failed")
        }
    }

    func present(
        _ event: S2FeedbackEvent,
        durationMilliseconds: Double
    ) {
        generation += 1
        let currentGeneration = generation
        presentedCount += 1
        activeEvent = event
        let seconds = max(0, durationMilliseconds) / 1_000
        lastScheduledDurationSeconds = seconds
        scheduler(seconds) { [weak self] in
            self?.expire(generation: currentGeneration)
        }
    }

    private func expire(generation expiredGeneration: Int) {
        guard expiredGeneration == generation else {
            return
        }
        activeEvent = nil
    }
}

/// IC-076（v15 第二节第 4 部分）：操作条三个按钮的启用态。某按钮写入进行中时只禁用
/// 该按钮；横栏拖动（`touchSequenceOwner != .none`）仍整体禁用操作条，与既有规则相同。
struct S2ActionBarPresentation: Equatable {
    let favoriteEnabled: Bool
    let recentAlbumEnabled: Bool
    let addAlbumEnabled: Bool
    let showsRecentAlbum: Bool

    init(machine: S2StateMachine) {
        let barEnabled = machine.touchSequenceOwner == .none
        favoriteEnabled = barEnabled && !machine.isActionInFlight(.favorite)
        recentAlbumEnabled = barEnabled &&
            !machine.isActionInFlight(.recentAlbum)
        addAlbumEnabled = barEnabled
        showsRecentAlbum = machine.recentAlbum != nil
    }
}

/// IC-076：sheet 内容只发起「选中」与「取消」；写入与结果由协调器经状态机三段流程处理。
struct S2AlbumPickerActions {
    let select: (S2AlbumReference) -> Void
    let cancel: () -> Void
}

/// IC-076：相簿选择 sheet 的呈现——用户相册列表按系统返回顺序、每项显示相册名；
/// 列表为空时显示一行占位文案；含「取消」。
struct S2AlbumPickerListPresentation: Equatable {
    let albums: [S2AlbumReference]

    var showsEmptyPlaceholder: Bool {
        albums.isEmpty
    }

    var rowTitles: [String] {
        albums.map(\.name)
    }

    var title: String {
        L10n.text("s2.album_picker.title")
    }

    var emptyPlaceholder: String {
        L10n.text("s2.album_picker.empty")
    }
}

struct S2AlbumPickerListView: View {
    let albums: [S2AlbumReference]
    let actions: S2AlbumPickerActions

    private var presentation: S2AlbumPickerListPresentation {
        S2AlbumPickerListPresentation(albums: albums)
    }

    var body: some View {
        VStack(spacing: S2OverlayLayout.minimumSpacing) {
            Text(presentation.title)
                .font(.headline)
                .padding(.top, S2OverlayLayout.minimumSpacing)
            if presentation.showsEmptyPlaceholder {
                Text(presentation.emptyPlaceholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(albums) { album in
                    Button {
                        actions.select(album)
                    } label: {
                        Text(verbatim: album.name)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: S2OverlayLayout.minimumTouchTarget,
                                alignment: .leading
                            )
                    }
                    .accessibilityLabel(Text(verbatim: album.name))
                }
                .listStyle(.plain)
            }
            Button(L10n.text("s2.action.cancel")) {
                actions.cancel()
            }
            .frame(
                maxWidth: .infinity,
                minHeight: S2OverlayLayout.minimumTouchTarget
            )
            .padding(.bottom, S2OverlayLayout.minimumSpacing)
        }
    }
}

struct S2View: View {
    typealias PhotoContent = (S2ImageContentContext) -> AnyView
    typealias StripItemContent = (S2BottomStripItemPresentation) -> AnyView
    typealias AlbumPickerContent = (
        S2AlbumPickerRequest,
        S2AlbumPickerActions
    ) -> AnyView

    @ObservedObject var machine: S2StateMachine
    @ObservedObject var calibration: S2CalibrationModel

    private let assetAspectRatio: (String) -> CGFloat
    private let assetIsScreenshot: (String) -> Bool
    private let assetPixelSize: (String) -> CGSize
    /// IC-078：`pinchMaxScale` 的 1:1 像素倍率按屏幕倍率换算。
    @Environment(\.displayScale) private var displayScale
    /// IC-079 R1：各资产图像加载态登记，仅供诊断录制场景 D 读取。
    @StateObject private var imageLoadStateRegistry = S2ImageLoadStateRegistry()
    private let photoContent: PhotoContent
    private let stripItemContent: StripItemContent
    private let albumPickerContent: AlbumPickerContent
    private let onBack: (S2ExitPayload) -> Void
    private let onConfirmation: (S2ExitPayload) -> Void
    private let onFavoriteRequest: (S2AssetActionRequest) -> Void
    private let onRecentAlbumRequest: (S2AlbumActionRequest) -> Void
    private let onAlbumPickerSelection: (
        S2AlbumPickerRequest,
        S2AlbumReference
    ) -> Void
    private let photoSwitchHapticFeedback: S2PhotoSwitchHapticFeedback

    @State private var calibrationOverlayState =
        S2CalibrationOverlayState.initial
    @State private var safeAreaInsets = S2OverlaySafeAreaInsets.zero
    @State private var statusBarHidden: Bool
    @StateObject private var geometryDiagnostics:
        S2GeometryDiagnosticsCoordinator
    @StateObject private var transitionDiagnostics:
        S2OnDeviceTransitionDiagnosticsCoordinator
    @StateObject private var primaryMark: S2PrimaryMarkPresenter
    @StateObject private var feedbackToast: S2FeedbackToastPresenter

    init(
        machine: S2StateMachine,
        calibration: S2CalibrationModel,
        assetAspectRatio: @escaping (String) -> CGFloat,
        assetIsScreenshot: @escaping (String) -> Bool = { _ in false },
        assetPixelSize: @escaping (String) -> CGSize = { _ in .zero },
        photoContent: @escaping PhotoContent,
        stripItemContent: @escaping StripItemContent,
        albumPickerContent: @escaping AlbumPickerContent,
        onBack: @escaping (S2ExitPayload) -> Void = { _ in },
        onConfirmation: @escaping (S2ExitPayload) -> Void = { _ in },
        onFavoriteRequest: @escaping (S2AssetActionRequest) -> Void = { _ in },
        onRecentAlbumRequest: @escaping (S2AlbumActionRequest) -> Void = { _ in },
        onAlbumPickerSelection: @escaping (
            S2AlbumPickerRequest,
            S2AlbumReference
        ) -> Void = { _, _ in },
        photoSwitchHapticFeedback: S2PhotoSwitchHapticFeedback = .live,
        geometryDiagnostics: S2GeometryDiagnosticsCoordinator =
            S2GeometryDiagnosticsCoordinator(),
        transitionDiagnostics: S2OnDeviceTransitionDiagnosticsCoordinator =
            S2OnDeviceTransitionDiagnosticsCoordinator(),
        primaryMarkPresenter: S2PrimaryMarkPresenter = S2PrimaryMarkPresenter(),
        feedbackToastPresenter: S2FeedbackToastPresenter =
            S2FeedbackToastPresenter()
    ) {
        self.machine = machine
        self.calibration = calibration
        self.assetAspectRatio = assetAspectRatio
        self.assetIsScreenshot = assetIsScreenshot
        self.assetPixelSize = assetPixelSize
        self.photoContent = photoContent
        self.stripItemContent = stripItemContent
        self.albumPickerContent = albumPickerContent
        self.onBack = onBack
        self.onConfirmation = onConfirmation
        self.onFavoriteRequest = onFavoriteRequest
        self.onRecentAlbumRequest = onRecentAlbumRequest
        self.onAlbumPickerSelection = onAlbumPickerSelection
        self.photoSwitchHapticFeedback = photoSwitchHapticFeedback
        _geometryDiagnostics = StateObject(wrappedValue: geometryDiagnostics)
        _transitionDiagnostics = StateObject(
            wrappedValue: transitionDiagnostics
        )
        _primaryMark = StateObject(wrappedValue: primaryMarkPresenter)
        _feedbackToast = StateObject(wrappedValue: feedbackToastPresenter)
        _statusBarHidden = State(
            initialValue: machine.interfaceVisibility == .hidden
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let ratio = assetAspectRatio(machine.currentAssetID)
            let viewportMetrics = S2ViewportLayout.metrics(
                physicalSize: geometry.size,
                presentationState: viewportPresentationState,
                assetAspectRatio: ratio,
                isScreenshot: assetIsScreenshot(machine.currentAssetID),
                configuration: calibration.configuration
            )

            ZStack {
                S2ViewportBackground.color
                    .ignoresSafeArea()

                mainPhoto(
                    viewportSize: viewportMetrics.viewportSize
                )

                interfaceOverlay(
                    bottomStripHeight: viewportMetrics.bottomStripHeight,
                    safeAreaInsets: safeAreaInsets
                )
                .opacity(machine.interfaceVisibility == .visible ? 1 : 0)
                .allowsHitTesting(machine.interfaceVisibility == .visible)
                .accessibilityHidden(machine.interfaceVisibility != .visible)

                primaryMarkOverlay(safeAreaInsets: safeAreaInsets)

                calibrationOverlay(
                    metrics: viewportMetrics,
                    safeAreaInsets: safeAreaInsets
                )

                feedbackToastOverlay(safeAreaInsets: safeAreaInsets)

                S2SafeAreaInsetsReader(insets: $safeAreaInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(machine.sheetState == .closed)
            .onAppear {
                _ = machine.applyCalibration(calibration.configuration)
            }
            .onChange(of: calibration.configuration) { _, configuration in
                _ = machine.applyCalibration(configuration)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(statusBarHidden)
        .onChange(of: machine.interfaceVisibility) { _, visibility in
            applyStatusBarAppearance(for: visibility)
        }
        .onChange(of: machine.semanticNotice) { _, notice in
            guard notice != nil else {
                return
            }
            primaryMark.consume(
                machine.consumeSemanticNotice(),
                interfaceVisibility: machine.interfaceVisibility
            )
        }
        .onChange(of: machine.feedbackEvent) { _, event in
            guard event != nil,
                  let consumed = machine.consumeFeedbackEvent() else {
                return
            }
            feedbackToast.present(
                consumed,
                durationMilliseconds:
                    calibration.configuration.feedbackToastDurationMilliseconds
            )
        }
        .transaction { transaction in
            if !calibration.configuration.animationsEnabled {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: albumSheetBinding) {
            albumSheet
                .disabled(machine.isActionInFlight(.albumPicker))
                .overlay(alignment: .bottom) {
                    feedbackToastOverlay(safeAreaInsets: .zero)
                }
                .interactiveDismissDisabled(
                    !calibration.configuration.animationsEnabled ||
                        machine.isActionInFlight(.albumPicker)
                )
        }
    }

    /// 底部短 toast：不接收点击、不遮挡手势；`P=呈现` 时同一呈现器也叠加在 sheet 底部，
    /// 使 sheet 内的写入失败反馈可见。
    @ViewBuilder
    private func feedbackToastOverlay(
        safeAreaInsets: S2OverlaySafeAreaInsets
    ) -> some View {
        if let event = feedbackToast.activeEvent {
            Text(S2FeedbackToastPresenter.text(for: event.kind))
                .font(.subheadline)
                .padding(.horizontal, S2OverlayLayout.minimumSpacing * 2)
                .padding(.vertical, S2OverlayLayout.minimumSpacing)
                .background(.regularMaterial, in: Capsule())
                .padding(
                    .bottom,
                    safeAreaInsets.bottom + S2OverlayLayout.minimumSpacing
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private var viewportPresentationState: S2ViewportPresentationState {
        S2ViewportPresentationState(
            interfaceVisibility: machine.interfaceVisibility,
            bottomStripState: machine.bottomStripState,
            sheetState: machine.sheetState,
            calibrationState: calibrationOverlayState
        )
    }

    private func mainPhoto(
        viewportSize: CGSize
    ) -> some View {
        let firstIndex = max(0, machine.currentIndex - 1)
        let lastIndex = min(
            machine.orderedAssetIDs.count - 1,
            machine.currentIndex + 1
        )
        let pages = Array(firstIndex...lastIndex).map { index in
            pageContent(index: index, viewportSize: viewportSize)
        }

        return S2NativePhotoPager(
            machine: machine,
            configuration: calibration.configuration,
            viewportSize: viewportSize,
            pages: pages,
            onLongPress: {
                calibrationOverlayState.toggleAccessControls()
            },
            diagnosticsCoordinator: geometryDiagnostics,
            transitionDiagnosticsCoordinator: transitionDiagnostics,
            imageLoadStateRegistry: imageLoadStateRegistry,
            // IC-079 R2：滚动中按需创建页时，分页控制器用同一构造取任意索引的页内容。
            pageContentProvider: { index in
                guard machine.orderedAssetIDs.indices.contains(index) else {
                    return nil
                }
                return pageContent(index: index, viewportSize: viewportSize)
            }
        )
        .frame(width: viewportSize.width, height: viewportSize.height)
        .clipped()
    }

    private func pageContent(
        index: Int,
        viewportSize: CGSize
    ) -> S2NativePageContent {
        let assetID = machine.orderedAssetIDs[index]
        do {
            let pageMetrics = S2ViewportLayout.metrics(
                physicalSize: viewportSize,
                presentationState: viewportPresentationState,
                assetAspectRatio: assetAspectRatio(assetID),
                isScreenshot: assetIsScreenshot(assetID),
                configuration: calibration.configuration
            )
            let requestRevision = machine.imageRequestAssetID == assetID
                ? machine.imageRequestRevision
                : 0
            let pixelSize = assetPixelSize(assetID)
            let content = photoContent(S2ImageContentContext(
                assetID: assetID,
                fittedSize: pageMetrics.oneXDisplaySize,
                requestBaseSize: pageMetrics.nativeZoomBaseSize,
                contentMode: .fit,
                scale: index == machine.currentIndex
                    ? machine.imageRequestScale
                    : 1,
                requestStrategy: machine.imageRequestStrategy,
                requestRevision: requestRevision,
                onRequestReading: { reading in
                    if index == machine.currentIndex {
                        machine.recordImageRequestReading(reading)
                    }
                },
                onLoadStateChange: { [imageLoadStateRegistry] state in
                    imageLoadStateRegistry.update(state, for: assetID)
                }
            ))
            return S2NativePageContent(
                index: index,
                assetID: assetID,
                interfaceVisibility: machine.interfaceVisibility,
                isFramedPhoto: pageMetrics.isFramedPhoto,
                fittedSize: pageMetrics.oneXDisplaySize,
                nativeZoomBaseSize: pageMetrics.nativeZoomBaseSize,
                cornerRadius: pageMetrics.oneXCornerRadius,
                doubleTapTargetScale: pageMetrics.doubleTapTargetScale,
                assetPixelSize: pixelSize,
                contentVersion: S2NativePhotoContentVersion(
                    requestedScale: index == machine.currentIndex
                        ? machine.imageRequestScale
                        : 1,
                    requestStrategy: machine.imageRequestStrategy,
                    requestRevision: requestRevision
                ),
                content: AnyView(content),
                zoomGeometry: S2AssetZoomGeometry(
                    assetPixelSize: pixelSize,
                    fitSize: pageMetrics.nativeZoomBaseSize,
                    displayScale: displayScale
                )
            )
        }
    }

    private func interfaceOverlay(
        bottomStripHeight: CGFloat,
        safeAreaInsets: S2OverlaySafeAreaInsets
    ) -> some View {
        VStack(spacing: 0) {
            topBar
                .frame(height: S2OverlayLayout.topBarHeight)
                .background(.regularMaterial)

            Spacer(minLength: S2OverlayLayout.minimumSpacing)

            VStack(spacing: S2OverlayLayout.minimumSpacing) {
                actionBar
                    .padding(
                        .horizontal,
                        S2OverlayLayout.horizontalPadding
                    )
                    .background(.regularMaterial)

                S2BottomStripView(
                    machine: machine,
                    metrics: machine.parameters.bottomStripMetrics,
                    markSize: CGFloat(
                        calibration.configuration.bottomStripMarkSize
                    ),
                    itemContent: stripItemContent,
                    onPhotoSwitch: {
                        photoSwitchHapticFeedback.notify(
                            isEnabled: calibration.configuration
                                .hapticOnPhotoSwitch,
                            source: .bottomStripDrag
                        )
                    }
                )
                .frame(height: bottomStripHeight)
                .background(.regularMaterial)
            }
        }
        .padding(.top, safeAreaInsets.top)
        .padding(.leading, safeAreaInsets.leading)
        .padding(.bottom, safeAreaInsets.bottom)
        .padding(.trailing, safeAreaInsets.trailing)
    }

    /// 主图待删标记浮层。位置固定于视口右上角（顶部信息区下方，距安全区右侧与
    /// 顶部信息区底边各 `horizontalPadding`），`Nx` 下不随平移移动；不参与命中测试。
    @ViewBuilder
    private func primaryMarkOverlay(
        safeAreaInsets: S2OverlaySafeAreaInsets
    ) -> some View {
        if S2PrimaryMarkPresenter.showsMark(
            interfaceVisibility: machine.interfaceVisibility,
            isMarked: machine.currentIsMarked
        ) {
            let size = S2PrimaryMarkPresenter.markSize(
                bottomStripMarkSize: calibration.configuration.bottomStripMarkSize
            )
            let halfPulse = max(
                0.000_001,
                calibration.configuration.markPulseDurationMilliseconds / 2_000
            )
            Image(systemName: S2PrimaryMarkPresenter.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .keyframeAnimator(
                    initialValue: CGFloat(1),
                    trigger: primaryMark.pulseID
                ) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.3, duration: halfPulse)
                    CubicKeyframe(1.0, duration: halfPulse)
                }
                .accessibilityLabel(L10n.text("s2.mark.primary.accessibility"))
                .padding(
                    .top,
                    safeAreaInsets.top + S2OverlayLayout.topBarHeight +
                        S2OverlayLayout.horizontalPadding
                )
                .padding(
                    .trailing,
                    safeAreaInsets.trailing + S2OverlayLayout.horizontalPadding
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )
                .allowsHitTesting(false)
        }
    }

    private var topBar: some View {
        S2TopBarLayout {
            Button {
                guard let payload = machine.makeExitPayload() else {
                    return
                }
                performCalibratedAnimation {
                    onBack(payload)
                }
            } label: {
                Label(
                    L10n.text("s2.action.back"),
                    systemImage: "chevron.left"
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
            .contentShape(Rectangle())

            Text(L10n.text(
                "s2.top.position",
                replacing: [
                    "current": String(machine.currentIndex + 1),
                    "total": String(machine.orderedAssetIDs.count)
                ]
            ))
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                guard let payload = machine.makeExitPayload() else {
                    return
                }
                performCalibratedAnimation {
                    onConfirmation(payload)
                }
            } label: {
                Image(systemName: "trash")
                    .overlay(alignment: .topTrailing) {
                        if let badgeText = confirmationEntry.badgeText {
                            Text(badgeText)
                                .monospacedDigit()
                        }
                    }
            }
            .disabled(!machine.canEnterConfirmation)
            .accessibilityLabel(confirmationEntry.accessibilityLabel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .disabled(machine.touchSequenceOwner != .none)
    }

    private var confirmationEntry: S2ConfirmationEntryPresentation {
        S2ConfirmationEntryPresentation(
            sessionPendingCount: machine.sessionMergedPendingDeletionCount
        )
    }

    private var actionBar: some View {
        let presentation = S2ActionBarPresentation(machine: machine)
        return HStack {
            Button {
                guard let request = machine.makeFavoriteToggleRequest() else {
                    return
                }
                onFavoriteRequest(request)
            } label: {
                Label(
                    favoriteActionTitle,
                    systemImage: machine.currentIsFavorite
                        ? "heart.fill"
                        : "heart"
                )
            }
            .disabled(!presentation.favoriteEnabled)
            .s2MinimumTouchTarget(expandsHorizontally: true)

            if let album = machine.recentAlbum {
                Button {
                    guard let request = machine.makeRecentAlbumAdditionRequest() else {
                        return
                    }
                    onRecentAlbumRequest(request)
                } label: {
                    Label(
                        L10n.text(
                            "s2.action.add_recent_album",
                            replacing: ["album": album.name]
                        ),
                        systemImage: "clock"
                    )
                }
                .disabled(!presentation.recentAlbumEnabled)
                .s2MinimumTouchTarget(expandsHorizontally: true)
            }

            Button {
                performCalibratedAnimation {
                    _ = machine.presentAlbumPicker()
                }
            } label: {
                Label(
                    L10n.text("s2.action.add_album"),
                    systemImage: "rectangle.stack.badge.plus"
                )
            }
            .disabled(!presentation.addAlbumEnabled)
            .s2MinimumTouchTarget(expandsHorizontally: true)
        }
        .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
    }

    private var favoriteActionTitle: String {
        machine.currentIsFavorite
            ? L10n.text("s2.action.unfavorite")
            : L10n.text("s2.action.favorite")
    }

    private var albumSheetBinding: Binding<Bool> {
        Binding(
            get: { machine.sheetState == .presented },
            set: { isPresented in
                if !isPresented {
                    performCalibratedAnimation {
                        _ = machine.cancelAlbumPicker()
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var albumSheet: some View {
        if let request = machine.albumPickerRequest {
            albumPickerContent(
                request,
                S2AlbumPickerActions(
                    select: { album in
                        onAlbumPickerSelection(request, album)
                    },
                    cancel: {
                        performCalibratedAnimation {
                            _ = machine.cancelAlbumPicker()
                        }
                    }
                )
            )
        } else {
            EmptyView()
        }
    }

    private func calibrationOverlay(
        metrics: S2ViewportMetrics,
        safeAreaInsets: S2OverlaySafeAreaInsets
    ) -> some View {
        Group {
            if calibrationOverlayState.controlsVisible {
                let availableWidth = max(
                    S2OverlayLayout.minimumTouchTarget,
                    min(
                        520,
                        metrics.viewportSize.width - safeAreaInsets.leading -
                            safeAreaInsets.trailing
                    )
                )
                let availableHeight = max(
                    S2OverlayLayout.minimumTouchTarget,
                    metrics.viewportSize.height - safeAreaInsets.top -
                        safeAreaInsets.bottom -
                        S2OverlayLayout.calibrationTopClearance
                )

                VStack(
                    alignment: .trailing,
                    spacing: S2OverlayLayout.minimumSpacing
                ) {
                    HStack(spacing: S2OverlayLayout.minimumSpacing) {
                        Button(parameterPanelToggleTitle) {
                            calibrationOverlayState.toggleParameterPanel()
                        }
                        .s2MinimumTouchTarget()

                        Button(readingsToggleTitle) {
                            calibrationOverlayState.toggleReadings()
                        }
                        .s2MinimumTouchTarget()
                    }
                    .background(.regularMaterial)

                    if calibrationOverlayState.parameterPanelVisible {
                        calibrationPanel(
                            viewportSize: metrics.viewportSize
                        )
                        .background(.regularMaterial)
                    }

                    if calibrationOverlayState.readingsVisible {
                        readingsPanel(metrics: metrics)
                        .background(.regularMaterial)
                    }
                }
                .frame(
                    maxWidth: availableWidth,
                    maxHeight: availableHeight,
                    alignment: .topTrailing
                )
                .padding(
                    .top,
                    safeAreaInsets.top +
                        S2OverlayLayout.calibrationTopClearance
                )
                .padding(.trailing, safeAreaInsets.trailing)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )
            }
        }
    }

    private func calibrationPanel(
        viewportSize: CGSize
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(L10n.text("s2.calibration.value_status"))
                Text(L10n.text("s2.calibration.core_gesture_hint"))

                S2CalibrationSliderRow(
                    title: "minDoubleTapScale",
                    value: calibrationBinding(\.minDoubleTapScale),
                    range: 1.1...4,
                    step: 0.1
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "doubleTapDecisionWindowMilliseconds",
                    value: calibrationBinding(
                        \.doubleTapDecisionWindowMilliseconds
                    ),
                    range: 0...600,
                    step: 10
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "pageSpacing",
                    value: calibrationBinding(\.pageSpacing),
                    range: 0...80,
                    step: 1
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "verticalSwipeDistance",
                    value: calibrationBinding(\.verticalSwipeDistance),
                    range: 0...300,
                    step: 1
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "verticalSwipeVelocity",
                    value: calibrationBinding(\.verticalSwipeVelocity),
                    range: 0...3_000,
                    step: 25
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                Picker(
                    "scaleChangeRequestPolicy",
                    selection: calibrationBinding(\.scaleChangeRequestPolicy)
                ) {
                    ForEach(
                        S2ScaleChangeImageRequestPolicy.allCases,
                        id: \.self
                    ) {
                        Text(scaleChangeRequestTitle($0)).tag($0)
                    }
                }
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                Picker(
                    "degradedPreviewPolicy",
                    selection: calibrationBinding(\.degradedPreviewPolicy)
                ) {
                    ForEach(S2DegradedPreviewPolicy.allCases, id: \.self) {
                        Text(degradedPreviewTitle($0)).tag($0)
                    }
                }
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                Toggle(
                    L10n.text("s2.calibration.animation.enabled"),
                    isOn: calibrationBinding(\.animationsEnabled)
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                Picker(
                    "animationDurationMilliseconds",
                    selection: calibrationBinding(
                        \.animationDurationMilliseconds
                    )
                ) {
                    Text(verbatim: "0 ms").tag(Double(0))
                    Text(verbatim: "180 ms").tag(Double(180))
                    Text(verbatim: "200 ms").tag(Double(200))
                    Text(verbatim: "220 ms").tag(Double(220))
                }
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                Picker(
                    "presentationToggleDuration",
                    selection: calibrationBinding(
                        \.presentationToggleDuration
                    )
                ) {
                    Text(verbatim: "0 ms").tag(Double(0))
                    Text(verbatim: "180 ms").tag(Double(180))
                    Text(verbatim: "200 ms").tag(Double(200))
                    Text(verbatim: "220 ms").tag(Double(220))
                    Text(verbatim: "240 ms").tag(Double(240))
                }
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "presentationToggleDamping",
                    value: calibrationBinding(
                        \.presentationToggleDamping
                    ),
                    range: 0.6...1,
                    step: 0.01
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "fitInsetRatio",
                    value: calibrationBinding(\.fitInsetRatio),
                    range: 0...0.45,
                    step: 0.005
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "fitCornerRadius",
                    value: calibrationBinding(\.fitCornerRadius),
                    range: 0...120,
                    step: 1
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "fitBorderWidth",
                    value: calibrationBinding(\.fitBorderWidth),
                    range: 0...4,
                    step: 0.1
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "fitBorderDarkAlpha",
                    value: calibrationBinding(\.fitBorderDarkAlpha),
                    range: 0...0.3,
                    step: 0.005
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                S2CalibrationSliderRow(
                    title: "fitBorderLightAlpha",
                    value: calibrationBinding(\.fitBorderLightAlpha),
                    range: 0...0.3,
                    step: 0.005
                )
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                Toggle(
                    isOn: calibrationBinding(\.hapticOnPhotoSwitch)
                ) {
                    Text(verbatim: "hapticOnPhotoSwitch")
                }
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)

                Text(L10n.text("s2.calibration.connection.title"))
                ForEach(S2CalibrationConfiguration.parameterConnections) {
                    parameter in
                    HStack {
                        Text(verbatim: parameter.name)
                        Spacer()
                        Text(parameter.specStatus.title)
                        Text(parameter.wiringStatus.title)
                    }
                    .font(.caption)
                }

                Text(L10n.text("s2.calibration.navigation.title"))
                ForEach(S2AssetAspectCategory.allCases, id: \.self) { category in
                    Button(categoryTitle(category)) {
                        guard viewportSize.height > 0 else {
                            return
                        }
                        performCalibratedAnimation {
                            _ = machine.navigateToNextAsset(
                                category: category,
                                viewportAspectRatio:
                                    viewportSize.width / viewportSize.height,
                                assetAspectRatio: assetAspectRatio
                            )
                        }
                    }
                    .s2MinimumTouchTarget()
                }
                if machine.assetNavigationResult == .empty {
                    Text(L10n.text("s2.calibration.navigation.empty"))
                }

                ShareLink(item: calibration.exportText()) {
                    Text(L10n.text("s2.calibration.export"))
                }
                .s2MinimumTouchTarget()
                Button(L10n.text("s2.calibration.diagnostics.export")) {
                    geometryDiagnostics.export()
                }
                .disabled(geometryDiagnostics.isExporting)
                .s2MinimumTouchTarget()
                if geometryDiagnostics.isExporting {
                    ProgressView(
                        L10n.text("s2.calibration.diagnostics.running")
                    )
                }
                if !geometryDiagnostics.reportText.isEmpty {
                    ShareLink(item: geometryDiagnostics.reportText) {
                        Text(L10n.text(
                            "s2.calibration.diagnostics.copy"
                        ))
                    }
                    .s2MinimumTouchTarget()
                    Text(verbatim: geometryDiagnostics.reportText)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }

                Divider()
                Text(L10n.text(
                    "s2.calibration.transition_diagnostics.title"
                ))
                Picker(
                    L10n.text(
                        "s2.calibration.transition_diagnostics.scenario"
                    ),
                    selection: $transitionDiagnostics.selectedScenario
                ) {
                    ForEach(S2OnDeviceTransitionScenario.allCases) {
                        scenario in
                        Text(transitionDiagnosticScenarioTitle(scenario))
                            .tag(scenario)
                    }
                }
                .disabled(transitionDiagnostics.isRecording)
                .frame(minHeight: S2OverlayLayout.minimumTouchTarget)
                Button(L10n.text(
                    "s2.calibration.transition_diagnostics.start"
                )) {
                    transitionDiagnostics.start()
                }
                .disabled(!transitionDiagnostics.canStart)
                .s2MinimumTouchTarget()
                Button(L10n.text(
                    "s2.calibration.transition_diagnostics.stop"
                )) {
                    transitionDiagnostics.stop()
                }
                .disabled(!transitionDiagnostics.isRecording)
                .s2MinimumTouchTarget()
                Button(L10n.text(
                    "s2.calibration.transition_diagnostics.export"
                )) {
                    transitionDiagnostics.export()
                }
                .disabled(!transitionDiagnostics.canExport)
                .s2MinimumTouchTarget()
                if transitionDiagnostics.isRecording {
                    ProgressView(L10n.text(
                        "s2.calibration.transition_diagnostics.recording"
                    ))
                }
                if !transitionDiagnostics.reportText.isEmpty {
                    ShareLink(item: transitionDiagnostics.reportText) {
                        Text(L10n.text(
                            "s2.calibration.transition_diagnostics.share"
                        ))
                    }
                    .s2MinimumTouchTarget()
                    Text(verbatim: transitionDiagnostics.reportText)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
                Button(L10n.text("s2.calibration.restore_factory")) {
                    calibration.restoreFactoryPlaceholder()
                }
                .s2MinimumTouchTarget()
                if calibration.persistenceFailed {
                    Text(L10n.text("s2.calibration.persistence_failed"))
                }
            }
        }
    }

    private func readingsPanel(metrics: S2ViewportMetrics) -> some View {
        VStack(alignment: .leading) {
            Text(L10n.text(
                "s2.calibration.reading.scale",
                replacing: ["value": decimal(machine.scale)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.asset_ratio",
                replacing: ["value": decimal(metrics.assetAspectRatio)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.viewport_ratio",
                replacing: ["value": decimal(metrics.viewportAspectRatio)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.aspect_fill",
                replacing: ["value": decimal(metrics.aspectFillMultiplier)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.double_tap_target",
                replacing: ["value": decimal(metrics.doubleTapTargetScale)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.display_size",
                replacing: [
                    "width": decimal(metrics.oneXDisplaySize.width),
                    "height": decimal(metrics.oneXDisplaySize.height)
                ]
            ))
            if let reading = machine.lastGestureReading {
                Text(L10n.text(
                    "s2.calibration.reading.gesture",
                    replacing: [
                        "distance": decimal(reading.displacementDistance),
                        "velocity": decimal(reading.peakVelocity),
                        "duration": decimal(reading.duration * 1_000)
                    ]
                ))
            } else {
                Text(L10n.text("s2.calibration.reading.gesture_empty"))
            }
            if let reading = machine.lastTapDecisionReading {
                Text(verbatim:
                    "singleTapDecisionLatencyMilliseconds=" +
                        decimal(reading.latencyMilliseconds)
                )
                Text(verbatim:
                    "doubleTapDecisionWindowMilliseconds=" +
                        decimal(reading.targetMilliseconds) +
                        ",targetMet=" +
                        String(reading.metConfiguredTarget)
                )
            }
            if let reading = machine.lastImageRequestReading {
                Text(L10n.text(
                    "s2.calibration.reading.image_request",
                    replacing: [
                        "trigger": imageRequestTriggerTitle(reading.trigger),
                        "return": imageReturnTypeTitle(reading.returnType)
                    ]
                ))
            } else {
                Text(L10n.text("s2.calibration.reading.image_request_empty"))
            }
        }
    }

    private func calibrationBinding<Value>(
        _ keyPath: WritableKeyPath<S2CalibrationConfiguration, Value>
    ) -> Binding<Value> {
        Binding(
            get: { calibration.configuration[keyPath: keyPath] },
            set: { value in
                _ = calibration.update { configuration in
                    configuration[keyPath: keyPath] = value
                }
            }
        )
    }

    private func categoryTitle(_ category: S2AssetAspectCategory) -> String {
        switch category {
        case .screenAspect:
            return L10n.text("s2.calibration.navigation.screen_aspect")
        case .portrait:
            return L10n.text("s2.calibration.navigation.portrait")
        case .landscape:
            return L10n.text("s2.calibration.navigation.landscape")
        case .square:
            return L10n.text("s2.calibration.navigation.square")
        case .extreme:
            return L10n.text("s2.calibration.navigation.extreme")
        }
    }

    private func scaleChangeRequestTitle(
        _ policy: S2ScaleChangeImageRequestPolicy
    ) -> String {
        switch policy {
        case .everyScaleChange:
            return L10n.text("s2.calibration.option.request.every_scale_change")
        case .pinchEnded:
            return L10n.text("s2.calibration.option.request.pinch_ended")
        }
    }

    private func degradedPreviewTitle(
        _ policy: S2DegradedPreviewPolicy
    ) -> String {
        switch policy {
        case .display:
            return L10n.text("s2.calibration.option.preview.display")
        case .finalImageOnly:
            return L10n.text("s2.calibration.option.preview.final_only")
        }
    }

    private func imageRequestTriggerTitle(
        _ trigger: S2ImageRequestTrigger
    ) -> String {
        switch trigger {
        case .initial:
            return L10n.text("s2.calibration.reading.trigger.initial")
        case .assetChange:
            return L10n.text("s2.calibration.reading.trigger.asset_change")
        case .viewportChange:
            return L10n.text("s2.calibration.reading.trigger.viewport_change")
        case .scaleChange:
            return L10n.text("s2.calibration.reading.trigger.scale_change")
        case .pinchEnded:
            return L10n.text("s2.calibration.reading.trigger.pinch_ended")
        case .strategyChange:
            return L10n.text("s2.calibration.reading.trigger.strategy_change")
        }
    }

    private func imageReturnTypeTitle(
        _ returnType: S2ImageReturnType
    ) -> String {
        switch returnType {
        case .pending:
            return L10n.text("s2.calibration.reading.return.pending")
        case .degradedPreview:
            return L10n.text("s2.calibration.reading.return.degraded_preview")
        case .finalImage:
            return L10n.text("s2.calibration.reading.return.final_image")
        case .failure:
            return L10n.text("s2.calibration.reading.return.failure")
        case .cancelled:
            return L10n.text("s2.calibration.reading.return.cancelled")
        case .assetUnavailable:
            return L10n.text("s2.calibration.reading.return.asset_unavailable")
        }
    }

    private var parameterPanelToggleTitle: String {
        calibrationOverlayState.parameterPanelVisible
            ? L10n.text("s2.calibration.panel.hide")
            : L10n.text("s2.calibration.panel.show")
    }

    private var readingsToggleTitle: String {
        calibrationOverlayState.readingsVisible
            ? L10n.text("s2.calibration.readings.hide")
            : L10n.text("s2.calibration.readings.show")
    }

    private func decimal<T: BinaryFloatingPoint>(_ value: T) -> String {
        String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(value)
        )
    }

    private var animationPolicy: S2AnimationPolicy {
        S2AnimationPolicy(configuration: calibration.configuration)
    }

    private func applyStatusBarAppearance(
        for visibility: S2InterfaceVisibility
    ) {
        let appearance = S2StatusBarAppearance(
            interfaceVisibility: visibility,
            configuration: calibration.configuration
        )
        if appearance.transitionDuration > 0 {
            withAnimation(.linear(
                duration: appearance.transitionDuration
            )) {
                statusBarHidden = appearance.isHidden
            }
        } else {
            performWithoutAnimation {
                statusBarHidden = appearance.isHidden
            }
        }
    }

    private func performCalibratedAnimation(_ action: () -> Void) {
        let policy = animationPolicy
        if policy.shouldAnimate {
            withAnimation(.linear(
                duration: policy.durationSeconds
            )) {
                action()
            }
        } else {
            performWithoutAnimation(action)
        }
    }

    private func performWithoutAnimation(_ action: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            action()
        }
    }

    private func transitionDiagnosticScenarioTitle(
        _ scenario: S2OnDeviceTransitionScenario
    ) -> String {
        switch scenario {
        case .tapShow:
            return L10n.text(
                "s2.calibration.transition_diagnostics.scenario_a"
            )
        case .tapHide:
            return L10n.text(
                "s2.calibration.transition_diagnostics.scenario_b"
            )
        case .pinchStart:
            return L10n.text(
                "s2.calibration.transition_diagnostics.scenario_c"
            )
        case .fastPaging:
            return L10n.text(
                "s2.calibration.transition_diagnostics.scenario_d"
            )
        case .nxEdgePaging:
            return L10n.text(
                "s2.calibration.transition_diagnostics.scenario_e"
            )
        }
    }
}

private struct S2TopBarLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews _: Subviews,
        cache _: inout ()
    ) -> CGSize {
        CGSize(
            width: proposal.width ?? 240,
            height: S2OverlayLayout.topBarHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let frames = S2OverlayLayout.topElementFrames(in: bounds)
        for (index, subview) in subviews.enumerated() where index < frames.count {
            let frame = frames[index]
            subview.place(
                at: frame.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: frame.width,
                    height: frame.height
                )
            )
        }
    }
}

private struct S2SafeAreaInsetsReader: UIViewRepresentable {
    @Binding var insets: S2OverlaySafeAreaInsets

    func makeUIView(context _: Context) -> S2SafeAreaInsetsReaderView {
        let view = S2SafeAreaInsetsReaderView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(
        _ view: S2SafeAreaInsetsReaderView,
        context _: Context
    ) {
        view.onInsetsChange = { value in
            let next = S2OverlaySafeAreaInsets(
                top: value.top,
                leading: value.left,
                bottom: value.bottom,
                trailing: value.right
            )
            DispatchQueue.main.async {
                if insets != next {
                    insets = next
                }
            }
        }
        view.publishInsetsIfNeeded()
    }
}

private final class S2SafeAreaInsetsReaderView: UIView {
    var onInsetsChange: ((UIEdgeInsets) -> Void)?
    private var publishedInsets: UIEdgeInsets?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        publishInsetsIfNeeded()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        publishInsetsIfNeeded()
    }

    func publishInsetsIfNeeded() {
        guard let onInsetsChange else {
            return
        }
        let currentInsets = window?.safeAreaInsets ?? safeAreaInsets
        guard publishedInsets != currentInsets else {
            return
        }
        publishedInsets = currentInsets
        onInsetsChange(currentInsets)
    }
}

private extension View {
    @ViewBuilder
    func s2MinimumTouchTarget(
        expandsHorizontally: Bool = false
    ) -> some View {
        if expandsHorizontally {
            frame(
                maxWidth: .infinity,
                minHeight: S2OverlayLayout.minimumTouchTarget
            )
            .contentShape(Rectangle())
        } else {
            frame(
                minWidth: S2OverlayLayout.minimumTouchTarget,
                minHeight: S2OverlayLayout.minimumTouchTarget
            )
            .contentShape(Rectangle())
        }
    }
}

private struct S2CalibrationSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text(verbatim: "\(title)=\(formattedValue)")
            Slider(value: $value, in: range, step: step)
        }
    }

    private var formattedValue: String {
        String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}

struct S2BottomStripView: View {
    @ObservedObject var machine: S2StateMachine

    let metrics: S2BottomStripMetrics
    let markSize: CGFloat
    let itemContent: S2View.StripItemContent
    let onPhotoSwitch: () -> Void

    @State private var residualTranslation: CGFloat = 0
    @State private var previousTranslation: CGFloat?

    func markPresentation(for assetID: String) -> S2BottomStripMarkPresentation {
        S2BottomStripMarkPresentation.make(
            isMarked: machine.pendingDeletionAssetIDs.contains(assetID),
            markSize: markSize
        )
    }

    @ViewBuilder
    private func stripMark(for assetID: String) -> some View {
        let mark = markPresentation(for: assetID)
        if mark.isShown {
            Image(systemName: S2BottomStripMarkPresentation.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: mark.size, height: mark.size)
                .accessibilityHidden(true)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(
                    Array(machine.orderedAssetIDs.enumerated()),
                    id: \.element
                ) { index, assetID in
                    itemContent(
                        S2BottomStripItemPresentation(
                            assetID: assetID,
                            index: index,
                            isCurrent: machine.bottomStripState == .idle &&
                                index == machine.currentIndex,
                            isMarked: machine.pendingDeletionAssetIDs.contains(assetID),
                            stripState: machine.bottomStripState
                        )
                    )
                    .frame(
                        width: itemWidth(at: index),
                        height: itemHeight(at: index)
                    )
                    .overlay(alignment: .topTrailing) {
                        stripMark(for: assetID)
                    }
                    .position(
                        x: geometry.size.width / 2 +
                            positionOffset(for: index) +
                            residualTranslation,
                        y: geometry.size.height / 2
                    )
                    .accessibilityLabel(L10n.text(
                        "s2.strip.item.accessibility",
                        replacing: [
                            "current": String(index + 1),
                            "total": String(machine.orderedAssetIDs.count)
                        ]
                    ))
                    .accessibilityValue(markAccessibilityValue(for: assetID))
                }

            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(stripGesture)
        }
    }

    private func itemWidth(at index: Int) -> CGFloat {
        if machine.bottomStripState == .dragging {
            return metrics.neighborItemWidth
        }
        return index == machine.currentIndex
            ? metrics.currentItemSize
            : metrics.neighborItemWidth
    }

    private func markAccessibilityValue(for assetID: String) -> String {
        machine.pendingDeletionAssetIDs.contains(assetID)
            ? L10n.text("s2.strip.item.marked")
            : L10n.text("s2.strip.item.unmarked")
    }

    private func itemHeight(at index: Int) -> CGFloat {
        if machine.bottomStripState == .dragging {
            return metrics.neighborItemHeight
        }
        return index == machine.currentIndex
            ? metrics.currentItemSize
            : metrics.neighborItemHeight
    }

    private func positionOffset(for index: Int) -> CGFloat {
        let delta = index - machine.currentIndex
        guard delta != 0 else {
            return 0
        }

        if machine.bottomStripState == .dragging {
            return CGFloat(delta) *
                (metrics.neighborItemWidth + metrics.itemSpacing)
        }

        let firstStep = metrics.currentItemSize / 2 +
            metrics.itemSpacing +
            metrics.neighborItemWidth / 2
        let remainingSteps = CGFloat(max(0, abs(delta) - 1)) *
            (metrics.neighborItemWidth + metrics.itemSpacing)
        let distance = firstStep + remainingSteps
        return delta > 0 ? distance : -distance
    }

    private var stripGesture: some Gesture {
        DragGesture(minimumDistance: metrics.dragMinimumDistance)
            .onChanged { value in
                if previousTranslation == nil {
                    guard machine.beginBottomStripDrag() else {
                        return
                    }
                    previousTranslation = value.translation.width
                    return
                }

                let previous = previousTranslation ?? value.translation.width
                residualTranslation += value.translation.width - previous
                previousTranslation = value.translation.width
                applyStripSwitches()
            }
            .onEnded { _ in
                guard previousTranslation != nil else {
                    return
                }
                residualTranslation = 0
                previousTranslation = nil
                _ = machine.endBottomStripDrag()
            }
    }

    private func applyStripSwitches() {
        while residualTranslation <= -metrics.switchDistance {
            if S2BottomStripPhotoSwitcher.switchPhoto(
                machine: machine,
                by: 1,
                onPhotoSwitch: onPhotoSwitch
            ) {
                residualTranslation += metrics.switchDistance
            } else {
                residualTranslation = -metrics.switchDistance
                break
            }
        }

        while residualTranslation >= metrics.switchDistance {
            if S2BottomStripPhotoSwitcher.switchPhoto(
                machine: machine,
                by: -1,
                onPhotoSwitch: onPhotoSwitch
            ) {
                residualTranslation -= metrics.switchDistance
            } else {
                residualTranslation = metrics.switchDistance
                break
            }
        }
    }
}

enum S2PreviewData {
    static let parameters =
        S2CalibrationConfiguration.factoryPlaceholder.resolvedParameters!
    static let calibration = S2CalibrationModel(
        persistence: S2DiscardingCalibrationPersistence()
    )

    static func machine(for state: S2State) -> S2StateMachine {
        let visibility: S2InterfaceVisibility
        switch state {
        case .hiddenOneX, .hiddenNx:
            visibility = .hidden
        default:
            visibility = .visible
        }
        let scale: CGFloat
        switch state {
        case .visibleNxIdle, .visibleNxStripDragging, .hiddenNx:
            scale = 2
        default:
            scale = 1
        }
        let entry = S2EntryContext(
            sessionID: "preview-session",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "preview-range",
                displayName: L10n.text("s2.preview.range"),
                totalAssetCount: 3
            ),
            orderedAssetIDs: [
                "preview-asset-1",
                "preview-asset-2",
                "preview-asset-3"
            ],
            currentAssetID: "preview-asset-2",
            pendingDeletionAssetIDs: ["preview-asset-2"],
            sessionMergedPendingDeletionCountProvider: { 1 }
        )
        let machine = S2StateMachine(
            entry: entry,
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: visibility,
                scale: scale,
                viewportOffset: .zero
            ),
            parameters: parameters,
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: S2AlbumReference(
                id: "preview-album",
                name: L10n.text("s2.preview.album")
            ),
            pendingDeletionDidChange: { _ in }
        )!
        if state == .visibleOneXStripDragging ||
            state == .visibleNxStripDragging {
            _ = machine.beginBottomStripDrag()
        }
        return machine
    }

    static func view(for state: S2State) -> S2View {
        S2View(
            machine: machine(for: state),
            calibration: calibration,
            assetAspectRatio: { assetID in
                assetID.hasSuffix("1")
                    ? CGFloat(3) / 4
                    : CGFloat(4) / 3
            },
            assetIsScreenshot: { _ in true },
            photoContent: { _ in
                AnyView(
                    ZStack {
                        Color.gray
                        Image(systemName: "photo")
                            .font(.largeTitle)
                    }
                )
            },
            stripItemContent: { item in
                AnyView(
                    ZStack {
                        Color.gray
                        Image(systemName: item.isMarked ? "trash.fill" : "photo")
                    }
                    .overlay {
                        Rectangle()
                            .stroke(item.isCurrent ? Color.primary : Color.clear)
                    }
                )
            },
            albumPickerContent: { _, actions in
                AnyView(
                    VStack {
                        Text(L10n.text("s2.preview.album_sheet"))
                        Button(L10n.text("s2.action.cancel")) {
                            actions.cancel()
                        }
                    }
                    .padding()
                )
            }
        )
    }
}

#Preview("S2-1") {
    S2PreviewData.view(for: .visibleOneXIdle)
}

#Preview("S2-2") {
    S2PreviewData.view(for: .visibleOneXStripDragging)
}

#Preview("S2-3") {
    S2PreviewData.view(for: .hiddenOneX)
}

#Preview("S2-4") {
    S2PreviewData.view(for: .visibleNxIdle)
}

#Preview("S2-5") {
    S2PreviewData.view(for: .visibleNxStripDragging)
}

#Preview("S2-6") {
    S2PreviewData.view(for: .hiddenNx)
}
