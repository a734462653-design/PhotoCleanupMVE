import Foundation
import QuartzCore
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
    /// IC-090 R2：请求返回结果与图片替换回调，仅供诊断埋点记录。
    var onRequestResult: (S2ImageRequestResult) -> Void = { _ in }
    var onImageReplaced: (S2ImageRequestResult) -> Void = { _ in }
    /// IC-093 R1：被抑制的替换回调，仅供诊断埋点记录。
    var onImageReplacementSuppressed:
        (S2ImageReplacementSuppressionReading) -> Void = { _ in }
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

/// IC-093 R2（④ Lynn 2026-08-24 选 A）：主图与横栏两处待删标记的**统一渲染**。
/// `trash.circle.fill` 以 palette 双色渲染——符号白、圆底黑 `circleOpacity`；
/// **固定色值，不随明暗模式变化**（两模式逐像素相同）。
///
/// 规格口径：标记叠在照片内容上，锚定的是内容可读性而不是界面主题，故 v15 回写决策 24
/// 「全部颜色走语义色」在这两处记例外，随 v16 修订记录。圆底不透明度是④技术负责人取定，
/// Lynn 真机可修订（H40）；它不是标定参数，不进配置也不进面板。
///
/// 本视图只管颜色与符号：尺寸由调用点传入，位置、显示条件、脉冲动画与圆角裁切关系
/// 全部留在各自调用点，本卡一行未改。
struct S2PendingDeletionMark: View {
    static let symbolName = "trash.circle.fill"
    static let symbolColor = Color.white
    static let circleOpacity = 0.55
    static let circleColor = Color.black.opacity(circleOpacity)

    let size: CGFloat

    var body: some View {
        Image(systemName: Self.symbolName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Self.symbolColor, Self.circleColor)
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
    /// IC-099 阶段二 R1：当前资产的拍摄日期。未接线时主行不显示。
    private let assetCreationDate: (String) -> Date?
    /// IC-099 阶段二 R4：占用空间取数实现。未接线时副行只显示序号。
    private let assetVolumeProvider: S2AssetVolumeProviding?
    /// IC-099b R2：字节数探针的取数实现。未接线（nil）时探针按钮禁用。
    /// 用现成对象而不是工厂闭包：闭包体是非隔离的，在里面调 `@MainActor` 的
    /// 协调器方法会触发隔离检查；由 App 层在自身的主线程上下文里造好传进来。
    private let assetSizeProber: S2AssetSizeProbing?

    @State private var calibrationOverlayState =
        S2CalibrationOverlayState.initial
    @State private var safeAreaInsets = S2OverlaySafeAreaInsets.zero
    @State private var statusBarHidden: Bool
    @StateObject private var geometryDiagnostics:
        S2GeometryDiagnosticsCoordinator
    @StateObject private var transitionDiagnostics:
        S2OnDeviceTransitionDiagnosticsCoordinator
    @StateObject private var primaryMark: S2PrimaryMarkPresenter
    /// IC-099b R2：字节数探针。**只在面板按钮触发时才取数**；未接线时按钮不可用。
    @StateObject private var assetSizeProbe = S2AssetSizeProbeCoordinator()
    /// IC-099 阶段二 R4：占用空间的会话级缓存与异步取数管线。随本视图释放。
    @StateObject private var assetVolumeStore = S2AssetVolumeStore()
    @StateObject private var feedbackToast: S2FeedbackToastPresenter

    init(
        machine: S2StateMachine,
        calibration: S2CalibrationModel,
        assetAspectRatio: @escaping (String) -> CGFloat,
        assetIsScreenshot: @escaping (String) -> Bool = { _ in false },
        assetPixelSize: @escaping (String) -> CGSize = { _ in .zero },
        assetCreationDate: @escaping (String) -> Date? = { _ in nil },
        assetVolumeProvider: S2AssetVolumeProviding? = nil,
        assetSizeProber: S2AssetSizeProbing? = nil,
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
        self.assetCreationDate = assetCreationDate
        self.assetVolumeProvider = assetVolumeProvider
        self.assetSizeProber = assetSizeProber
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
                configuration: calibration.configuration,
                // IC-104 C：截图适配框锚上下 chrome，需要真实安全区。
                safeAreaInsets: safeAreaInsets
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

                feedbackToastOverlay(
                    bottomInset: S2OverlayLayout
                        .toastBottomFromViewportBottom(
                            safeAreaBottom: safeAreaInsets.bottom,
                            bottomStripHeight: viewportMetrics
                                .bottomStripHeight
                        )
                )

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
                    feedbackToastOverlay(
                        bottomInset: S2OverlayLayout.minimumSpacing
                    )
                }
                .interactiveDismissDisabled(
                    !calibration.configuration.animationsEnabled ||
                        machine.isActionInFlight(.albumPicker)
                )
        }
    }

    /// 底部短 toast：不接收点击、不遮挡手势；`P=呈现` 时同一呈现器也叠加在 sheet 底部，
    /// 使 sheet 内的写入失败反馈可见。
    /// IC-100 v2 R2：落位改由调用方给出「底缘距容器底」的量。
    /// 主屏幕传 `S2OverlayLayout.toastBottomFromViewportBottom(...)`（横栏顶缘 + 8），
    /// 与操作条、横栏均无纵向重叠；sheet 内仍是紧贴底缘的 `minimumSpacing`，
    /// 与 IC-100 前逐字相同（改前该处传 `.zero` 安全区，落值同为 8）。
    @ViewBuilder
    private func feedbackToastOverlay(
        bottomInset: CGFloat
    ) -> some View {
        if let event = feedbackToast.activeEvent {
            Text(S2FeedbackToastPresenter.text(for: event.kind))
                .font(.subheadline)
                .padding(.horizontal, S2OverlayLayout.minimumSpacing * 2)
                .padding(.vertical, S2OverlayLayout.minimumSpacing)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, bottomInset)
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
                configuration: calibration.configuration,
                // IC-104 C：同上，逐页几何也必须用真实安全区。
                safeAreaInsets: safeAreaInsets
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
                },
                // IC-090 R2 场景 C：请求结果登记为逐帧字段；图片替换同时登记与追加事件。
                onRequestResult: { [imageLoadStateRegistry] result in
                    imageLoadStateRegistry.updateRequestResult(
                        result,
                        for: assetID
                    )
                },
                onImageReplaced: {
                    [imageLoadStateRegistry, transitionDiagnostics] result in
                    let record = S2ImageReplacementRecord(
                        assetID: assetID,
                        resultName: result.diagnosticName,
                        pixelSize: result.image?.size ?? .zero,
                        timestamp: CACurrentMediaTime()
                    )
                    imageLoadStateRegistry.recordImageReplacement(record)
                    transitionDiagnostics.recordImageReplacement(record)
                },
                // IC-093 R1：像素更少而未上屏的返回结果只记事件，不改任何登记状态。
                onImageReplacementSuppressed: {
                    [transitionDiagnostics] reading in
                    transitionDiagnostics.recordImageReplacementSuppressed(
                        assetID: assetID,
                        resultName: reading.result.diagnosticName,
                        displayedPixelSize: reading.displayedPixelSize,
                        candidatePixelSize: reading.candidatePixelSize
                    )
                }
            ))
            return S2NativePageContent(
                index: index,
                assetID: assetID,
                interfaceVisibility: machine.interfaceVisibility,
                isFramedPhoto: pageMetrics.isFramedPhoto,
                fittedSize: pageMetrics.oneXDisplaySize,
                fittedCenterY: pageMetrics.oneXDisplayCenterY,
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
        // IC-100 v2 R1：底部竖向顺序自下而上改为 系统安全区 → 常驻操作条 → 底部横栏。
        // 两个底部浮层不再套在同一个竖直堆叠里，而是各自按
        // `S2OverlayLayout` 的推导式独立锚定**视口**底缘；
        // `S2OverlayLayout.snapshot`（门禁侧几何模型）调用的是同一组函数，
        // 两侧不会各算各的（R3 双真相同步）。
        ZStack(alignment: .bottom) {
            // 顶部信息区：几何与 IC-100 前逐字相同（只受顶部安全区约束）。
            VStack(spacing: 0) {
                topBar
                    .frame(height: S2OverlayLayout.topBarHeight)
                    .background(.regularMaterial)

                Spacer(minLength: S2OverlayLayout.minimumSpacing)
            }
            .padding(.top, safeAreaInsets.top)

            S2BottomStripView(
                machine: machine,
                metrics: machine.parameters.bottomStripMetrics,
                markSize: CGFloat(
                    calibration.configuration.bottomStripMarkSize
                ),
                itemContent: stripItemContent,
                assetAspectRatio: assetAspectRatio,
                onPhotoSwitch: {
                    photoSwitchHapticFeedback.notify(
                        isEnabled: calibration.configuration
                            .hapticOnPhotoSwitch,
                        source: .bottomStripDrag
                    )
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: bottomStripHeight)
            .background(.regularMaterial)
            .padding(
                .bottom,
                S2OverlayLayout.stripBottomFromViewportBottom(
                    safeAreaBottom: safeAreaInsets.bottom
                )
            )

            // 触控带底缘恰为安全区上沿——「避让安全区贴近底缘」，
            // 且满足既有门禁 L2（底部元素不进入主屏幕指示条区域）。
            actionBar
                .padding(
                    .horizontal,
                    S2OverlayLayout.horizontalPadding
                )
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .padding(
                    .bottom,
                    S2OverlayLayout.actionBandBottomFromViewportBottom(
                        safeAreaBottom: safeAreaInsets.bottom
                    )
                )
        }
        .padding(.leading, safeAreaInsets.leading)
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
            // IC-093 R2：渲染收敛到 `S2PendingDeletionMark`；脉冲、位置、显示条件不变。
            S2PendingDeletionMark(size: size)
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

            topInfoArea
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

    /// IC-099 阶段二 R2（v16 回写决策 35）：顶部中部信息区两行——
    /// 主行为当前资产拍摄日期（无拍摄日期时整行不显示，④ 卡内取定），
    /// 副行为「{当前序号}/{总数} · {占用空间}」；占用空间未就绪或取数失败时
    /// 副行退化为「{当前序号}/{总数}」，不显示占位符。
    ///
    /// 字体 / 字号 / 颜色是**视觉稿前占位样式**（系统 `.caption` / `.caption2` +
    /// 语义色），不进标定参数、不进规格，见报告「占位值登记」。
    private var topInfoArea: some View {
        VStack(spacing: 0) {
            if let dateText = S2TopBarInfoPresentation.dateText(
                creationDate: assetCreationDate(machine.currentAssetID),
                now: Date()
            ) {
                Text(verbatim: dateText)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Text(verbatim: S2TopBarInfoPresentation.subtitleText(
                currentIndex: machine.currentIndex,
                totalCount: machine.orderedAssetIDs.count,
                byteCount: assetVolumeStore.byteCount(
                    for: machine.currentAssetID
                )
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .task(id: machine.currentAssetID) {
            guard let assetVolumeProvider else {
                return
            }
            assetVolumeStore.requestIfNeeded(
                assetID: machine.currentAssetID,
                using: assetVolumeProvider
            )
        }
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
                // IC-081：1:1 倍率乘数（placeholder，待真机标定后定案）；IC-086：出厂 6.0，范围 2…10。
                S2CalibrationSliderRow(
                    title: "pinchMaxScaleOneToOneMultiplier",
                    value: calibrationBinding(\.pinchMaxScaleOneToOneMultiplier),
                    range: 2...10,
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
                assetSizeProbeSection
                // IC-087：恢复出厂值——重置配置并删除 Keychain 条目；经 onChange(of: calibration.configuration)
                // → machine.applyCalibration → pager.apply 对当前页即时生效。
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

    /// IC-099b R2：调试面板的字节数探针段。单独抽出，既让面板主体少 8 个子视图，
    /// 也把这一段的类型检查与面板其余部分隔开。
    @ViewBuilder
    private var assetSizeProbeSection: some View {
        // IC-099b R2：字节数探针。只量当前范围内资产的字节数并生成可复制文本，
        // 不改任何产品行为、不写持久化、不碰图片请求策略。
        Divider()
        Text(L10n.text("s2.calibration.asset_size_probe.title"))
        Button(L10n.text("s2.calibration.asset_size_probe.start")) {
            guard let prober = assetSizeProber else {
                return
            }
            assetSizeProbe.run(
                assetIDs: machine.orderedAssetIDs,
                using: prober
            )
        }
        .disabled(
            assetSizeProber == nil || assetSizeProbe.isRunning
        )
        .s2MinimumTouchTarget()
        if assetSizeProbe.isRunning {
            ProgressView(assetSizeProbe.progressText)
        }
        if !assetSizeProbe.reportText.isEmpty {
            ShareLink(item: assetSizeProbe.reportText) {
                Text(L10n.text(
                    "s2.calibration.asset_size_probe.share"
                ))
            }
            .s2MinimumTouchTarget()
            Text(verbatim: assetSizeProbe.reportText)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
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

/// IC-085：横栏几何的单一入口。内容坐标以第 0 张中心为原点，第 i 张中心 = i × 节距；
/// `contentX` 是视口中心对应的内容坐标；`expansion` 取 0～1，是当前张的展开程度
/// （1 = 静止态方形放大 + 两侧间隙；0 = 滑动态全部等距矩形）。
struct S2BottomStripLayout: Equatable {
    let metrics: S2BottomStripMetrics

    /// 相邻项目中心的节距。
    var pitch: CGFloat {
        metrics.switchDistance
    }

    /// 完全展开时左右邻居各自外移的距离 = 当前张半边增量 + 间隙增量。
    var expansionShift: CGFloat {
        (metrics.currentItemSize - metrics.neighborItemWidth) / 2 +
            (metrics.currentItemGap - metrics.itemSpacing)
    }

    func contentCenterX(of index: Int) -> CGFloat {
        CGFloat(index) * pitch
    }

    func maximumContentX(count: Int) -> CGFloat {
        CGFloat(max(0, count - 1)) * pitch
    }

    func clampedContentX(_ x: CGFloat, count: Int) -> CGFloat {
        min(max(0, x), maximumContentX(count: count))
    }

    func nearestIndex(toContentX x: CGFloat, count: Int) -> Int {
        guard count > 0, pitch > 0 else {
            return 0
        }
        let raw = Int((x / pitch).rounded())
        return min(max(0, raw), count - 1)
    }

    func itemSize(
        at index: Int,
        currentIndex: Int,
        expansion: CGFloat
    ) -> CGSize {
        guard index == currentIndex else {
            return CGSize(
                width: metrics.neighborItemWidth,
                height: metrics.neighborItemHeight
            )
        }
        let progress = clampedExpansion(expansion)
        return CGSize(
            width: metrics.neighborItemWidth +
                (metrics.currentItemSize - metrics.neighborItemWidth) * progress,
            height: metrics.neighborItemHeight +
                (metrics.currentItemSize - metrics.neighborItemHeight) * progress
        )
    }

    /// 视口坐标中的项目 frame：视口原点在左上角，内容带垂直居中。
    func frame(
        at index: Int,
        currentIndex: Int,
        expansion: CGFloat,
        contentX: CGFloat,
        viewportSize: CGSize
    ) -> CGRect {
        let size = itemSize(
            at: index,
            currentIndex: currentIndex,
            expansion: expansion
        )
        let progress = clampedExpansion(expansion)
        var centerX = viewportSize.width / 2 + contentCenterX(of: index) - contentX
        if index < currentIndex {
            centerX -= expansionShift * progress
        } else if index > currentIndex {
            centerX += expansionShift * progress
        }
        return CGRect(
            x: centerX - size.width / 2,
            y: (viewportSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// 可能落入视口（含展开位移余量）的索引区间；只为这些索引创建内容视图。
    func visibleIndices(
        contentX: CGFloat,
        viewportWidth: CGFloat,
        count: Int
    ) -> Range<Int> {
        guard count > 0, pitch > 0 else {
            return 0..<0
        }
        let reach = viewportWidth / 2 + expansionShift + metrics.currentItemSize
        let lower = Int(((contentX - reach) / pitch).rounded(.down))
        let upper = Int(((contentX + reach) / pitch).rounded(.up))
        let lowerBound = min(max(0, lower), count)
        let upperBound = min(count, max(lowerBound, upper + 1))
        return lowerBound..<upperBound
    }

    /// 两侧线性渐隐的遮罩停靠点（相对位置 0～1，不透明度 0～1）：
    /// `leadingInset` 内完全不可见，随后 `edgeFadeWidth` 内线性升到 1，右侧对称。
    func fadeStops(viewportWidth: CGFloat) -> [(location: CGFloat, opacity: CGFloat)] {
        guard viewportWidth > 0,
              metrics.leadingInset + metrics.edgeFadeWidth > 0 else {
            return [(location: 0, opacity: 1), (location: 1, opacity: 1)]
        }
        let insetLocation = min(0.5, max(0, metrics.leadingInset / viewportWidth))
        let opaqueLocation = min(
            0.5,
            max(
                insetLocation,
                (metrics.leadingInset + metrics.edgeFadeWidth) / viewportWidth
            )
        )
        return [
            (location: 0, opacity: 0),
            (location: insetLocation, opacity: 0),
            (location: opaqueLocation, opacity: 1),
            (location: 1 - opaqueLocation, opacity: 1),
            (location: 1 - insetLocation, opacity: 0),
            (location: 1, opacity: 0)
        ]
    }

    /// IC-085 R3：项目帧固定，与资产宽高比无关；内容按 aspectFill 放大到覆盖项目帧
    /// （横图裁左右、竖图裁上下），由视图层以帧居中裁切。返回内容框尺寸。
    static func fillContentSize(
        cellSize: CGSize,
        assetAspectRatio: CGFloat
    ) -> CGSize {
        guard cellSize.width > 0, cellSize.height > 0,
              assetAspectRatio.isFinite, assetAspectRatio > 0 else {
            return cellSize
        }
        let cellRatio = cellSize.width / cellSize.height
        if assetAspectRatio >= cellRatio {
            return CGSize(
                width: cellSize.height * assetAspectRatio,
                height: cellSize.height
            )
        }
        return CGSize(
            width: cellSize.width,
            height: cellSize.width / assetAspectRatio
        )
    }

    private func clampedExpansion(_ expansion: CGFloat) -> CGFloat {
        min(max(0, expansion), 1)
    }
}

/// IC-085：横栏惯性减速的闭式模型 v(t) = v0 · k^(1000 t)，k 为每毫秒衰减率
/// （出厂 0.998 = 系统录屏拟合值 = `UIScrollView.DecelerationRate.normal`）。
/// 位置由经过的壁钟时间直接求得，不做逐帧累加，掉帧不丢位移。
enum S2BottomStripInertia {
    /// ③ 实现常量：减速终止速度。录屏减速尾帧位移 1 px/帧（60 fps）≈ 20 pt/s。
    static let stopSpeed: CGFloat = 20

    /// ③ 实现常量：吸附 + 展开曲线的指数时间常数，按录屏 600 ms 段逐帧位移拟合
    /// （100 ms 完成 55%、200 ms 完成 80%）。
    static let settleTimeConstant: TimeInterval = 0.125

    static func velocity(
        initial v0: CGFloat,
        rate k: CGFloat,
        elapsed t: TimeInterval
    ) -> CGFloat {
        guard k > 0, k < 1 else {
            return 0
        }
        return v0 * pow(k, CGFloat(t) * 1000)
    }

    static func displacement(
        initial v0: CGFloat,
        rate k: CGFloat,
        elapsed t: TimeInterval
    ) -> CGFloat {
        guard k > 0, k < 1 else {
            return 0
        }
        return v0 * (pow(k, CGFloat(t) * 1000) - 1) / (1000 * log(k))
    }

    /// 速度衰减到 `stopSpeed` 所需时间；初速不高于终止速度时为 0。
    static func duration(initial v0: CGFloat, rate k: CGFloat) -> TimeInterval {
        guard k > 0, k < 1, abs(v0) > stopSpeed else {
            return 0
        }
        return TimeInterval(log(stopSpeed / abs(v0)) / (1000 * log(k)))
    }

    /// 吸附 + 展开进度：指数 ease-out，在 `duration` 处归一到 1。
    static func settleProgress(
        elapsed t: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard duration > 0, t > 0 else {
            return duration > 0 ? 0 : 1
        }
        guard t < duration else {
            return 1
        }
        let tau = settleTimeConstant
        return CGFloat((1 - exp(-t / tau)) / (1 - exp(-duration / tau)))
    }

    /// 拖动开始的收缩进度：二次 ease-out。
    static func collapseProgress(
        elapsed t: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard duration > 0, t > 0 else {
            return duration > 0 ? 0 : 1
        }
        guard t < duration else {
            return 1
        }
        let linear = CGFloat(t / duration)
        return 1 - (1 - linear) * (1 - linear)
    }
}

/// 帧驱动：只负责在需要重算时唤醒控制器，位置本身由时间闭式求得。
protocol S2BottomStripFrameDriving: AnyObject {
    func start(_ onFrame: @escaping () -> Void)
    func stop()
}

final class S2BottomStripDisplayLinkFrameDriver: NSObject, S2BottomStripFrameDriving {
    private var displayLink: CADisplayLink?
    private var onFrame: (() -> Void)?

    deinit {
        displayLink?.invalidate()
    }

    func start(_ onFrame: @escaping () -> Void) {
        self.onFrame = onFrame
        guard displayLink == nil else {
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        onFrame = nil
    }

    @objc private func step() {
        onFrame?()
    }
}

/// IC-085：横栏运动控制器——拖动跟手、松手惯性、停止后吸附到最近项并展开当前张、
/// 拖动开始收缩。定位项一变化即通过 `hooks.switchPhoto` 切主图（既有语义）。
/// 触摸序列（`beginSequence`…`endSequence`）覆盖拖动与惯性减速两段；吸附与展开在
/// 序列结束之后、`bottomStripState == .idle` 下完成。
final class S2BottomStripMotionController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case dragging
        case decelerating
        case settling
    }

    struct Hooks {
        var beginSequence: () -> Bool
        var switchPhoto: (Int) -> Bool
        var endSequence: () -> Void
    }

    @Published private(set) var contentX: CGFloat = 0
    @Published private(set) var expansion: CGFloat = 1
    @Published private(set) var phase: Phase = .idle

    private(set) var trackedIndex = 0
    private(set) var itemCount = 0

    var layout: S2BottomStripLayout {
        didSet {
            guard layout != oldValue, phase == .idle else {
                return
            }
            contentX = layout.clampedContentX(
                layout.contentCenterX(of: trackedIndex),
                count: itemCount
            )
        }
    }

    var hooks: Hooks

    private let clock: () -> TimeInterval
    private let frameDriver: S2BottomStripFrameDriving

    private var dragAnchorContentX: CGFloat = 0
    private var dragAnchorTranslation: CGFloat?
    private var deceleration: (start: TimeInterval, x: CGFloat, v0: CGFloat)?
    private var settle: (
        start: TimeInterval,
        fromX: CGFloat,
        toX: CGFloat,
        fromExpansion: CGFloat
    )?
    private var collapse: (start: TimeInterval, fromExpansion: CGFloat)?

    init(
        layout: S2BottomStripLayout,
        hooks: Hooks,
        clock: @escaping () -> TimeInterval = { CACurrentMediaTime() },
        frameDriver: S2BottomStripFrameDriving = S2BottomStripDisplayLinkFrameDriver()
    ) {
        self.layout = layout
        self.hooks = hooks
        self.clock = clock
        self.frameDriver = frameDriver
    }

    deinit {
        frameDriver.stop()
    }

    private var metrics: S2BottomStripMetrics {
        layout.metrics
    }

    private var collapseDuration: TimeInterval {
        TimeInterval(metrics.collapseDurationMilliseconds) / 1000
    }

    private var expandDuration: TimeInterval {
        TimeInterval(metrics.expandDurationMilliseconds) / 1000
    }

    /// 外部定位项或张数变化。触摸序列进行中（拖动、减速）不打断——横栏拖动引起的
    /// 切换由 `updateTrackedIndex` 自行跟踪。
    /// `animated == false`：直接居中（首帧、张数变化、参数变化）。
    /// `animated == true`（IC-085 R3，主图翻页引起的定位项变化）：以
    /// `expandDurationMilliseconds` 的 ease-out 滚动到新当前张并展开，不跳变。
    func synchronize(count: Int, currentIndex: Int, animated: Bool = false) {
        itemCount = max(0, count)
        let target = min(max(0, currentIndex), max(0, itemCount - 1))
        switch phase {
        case .dragging, .decelerating:
            return
        case .idle, .settling:
            break
        }
        let targetX = layout.clampedContentX(
            layout.contentCenterX(of: target),
            count: itemCount
        )
        let alreadyThere = target == trackedIndex &&
            (phase == .settling || (contentX == targetX && expansion == 1))
        guard !alreadyThere else {
            return
        }
        trackedIndex = target
        guard animated, expandDuration > 0 else {
            settle = nil
            contentX = targetX
            expansion = 1
            if phase == .settling {
                phase = .idle
                frameDriver.stop()
            }
            return
        }
        settle = (
            start: clock(),
            fromX: contentX,
            toX: targetX,
            fromExpansion: 0
        )
        expansion = 0
        phase = .settling
        frameDriver.start { [weak self] in
            self?.tick()
        }
    }

    @discardableResult
    func beginDrag() -> Bool {
        switch phase {
        case .dragging:
            return true
        case .decelerating:
            break
        case .idle, .settling:
            guard hooks.beginSequence() else {
                return false
            }
        }
        let now = clock()
        deceleration = nil
        settle = nil
        phase = .dragging
        dragAnchorContentX = contentX
        dragAnchorTranslation = nil
        if expansion > 0 {
            collapse = (start: now, fromExpansion: expansion)
            frameDriver.start { [weak self] in
                self?.tick()
            }
        }
        return true
    }

    func updateDrag(translation: CGFloat) {
        guard phase == .dragging else {
            return
        }
        guard let anchor = dragAnchorTranslation else {
            dragAnchorTranslation = translation
            return
        }
        contentX = layout.clampedContentX(
            dragAnchorContentX - (translation - anchor),
            count: itemCount
        )
        updateTrackedIndex()
    }

    /// `velocity` 为手指速度（pt/s，向右为正）；内容速度与之反向。
    func endDrag(velocity: CGFloat) {
        guard phase == .dragging else {
            return
        }
        let now = clock()
        // IC-085 R3：手指速度低于阈值视为慢拖松手，无减速段，直接吸附展开。
        guard abs(velocity) >= metrics.flickVelocityThreshold else {
            finishSequence(at: now)
            return
        }
        let contentVelocity = -velocity
        let duration = S2BottomStripInertia.duration(
            initial: contentVelocity,
            rate: metrics.decelerationRate
        )
        guard duration > 0 else {
            finishSequence(at: now)
            return
        }
        deceleration = (start: now, x: contentX, v0: contentVelocity)
        phase = .decelerating
        frameDriver.start { [weak self] in
            self?.tick()
        }
    }

    /// 按当前壁钟时间重算位置与展开度；由帧驱动或测试显式调用。
    func tick() {
        let now = clock()
        if let collapse {
            let progress = S2BottomStripInertia.collapseProgress(
                elapsed: now - collapse.start,
                duration: collapseDuration
            )
            expansion = collapse.fromExpansion * (1 - progress)
            if progress >= 1 {
                self.collapse = nil
            }
        }

        switch phase {
        case .decelerating:
            guard let deceleration else {
                finishSequence(at: now)
                return
            }
            let elapsed = now - deceleration.start
            let duration = S2BottomStripInertia.duration(
                initial: deceleration.v0,
                rate: metrics.decelerationRate
            )
            let unclamped = deceleration.x + S2BottomStripInertia.displacement(
                initial: deceleration.v0,
                rate: metrics.decelerationRate,
                elapsed: min(elapsed, duration)
            )
            let clamped = layout.clampedContentX(unclamped, count: itemCount)
            contentX = clamped
            updateTrackedIndex()
            if elapsed >= duration || clamped != unclamped {
                finishSequence(at: now)
            }
        case .settling:
            guard let settle else {
                phase = .idle
                frameDriver.stop()
                return
            }
            let progress = S2BottomStripInertia.settleProgress(
                elapsed: now - settle.start,
                duration: expandDuration
            )
            contentX = settle.fromX + (settle.toX - settle.fromX) * progress
            expansion = settle.fromExpansion +
                (1 - settle.fromExpansion) * progress
            if progress >= 1 {
                self.settle = nil
                phase = .idle
                frameDriver.stop()
            }
        case .idle:
            if collapse == nil {
                frameDriver.stop()
            }
        case .dragging:
            if collapse == nil {
                frameDriver.stop()
            }
        }
    }

    private func updateTrackedIndex() {
        let target = layout.nearestIndex(toContentX: contentX, count: itemCount)
        while trackedIndex != target {
            let step = target > trackedIndex ? 1 : -1
            guard hooks.switchPhoto(step) else {
                return
            }
            trackedIndex += step
        }
    }

    private func finishSequence(at now: TimeInterval) {
        deceleration = nil
        collapse = nil
        hooks.endSequence()
        let target = layout.nearestIndex(toContentX: contentX, count: itemCount)
        trackedIndex = target
        let targetX = layout.clampedContentX(
            layout.contentCenterX(of: target),
            count: itemCount
        )
        guard expandDuration > 0 else {
            contentX = targetX
            expansion = 1
            phase = .idle
            frameDriver.stop()
            return
        }
        settle = (
            start: now,
            fromX: contentX,
            toX: targetX,
            fromExpansion: expansion
        )
        phase = .settling
        frameDriver.start { [weak self] in
            self?.tick()
        }
    }
}

extension S2BottomStripMotionController {
    /// 生产与夹具共用的状态机挂钩：序列起止落在 `beginBottomStripDrag` /
    /// `endBottomStripDrag`，切图经 `S2BottomStripPhotoSwitcher`（含触感回调）。
    static func hooks(
        machine: S2StateMachine,
        onPhotoSwitch: @escaping () -> Void
    ) -> Hooks {
        Hooks(
            beginSequence: { [weak machine] in
                machine?.beginBottomStripDrag() ?? false
            },
            switchPhoto: { [weak machine] offset in
                guard let machine else {
                    return false
                }
                return S2BottomStripPhotoSwitcher.switchPhoto(
                    machine: machine,
                    by: offset,
                    onPhotoSwitch: onPhotoSwitch
                )
            },
            endSequence: { [weak machine] in
                _ = machine?.endBottomStripDrag()
            }
        )
    }
}

struct S2BottomStripView: View {
    @ObservedObject var machine: S2StateMachine

    let metrics: S2BottomStripMetrics
    let markSize: CGFloat
    let itemContent: S2View.StripItemContent
    /// IC-085 R3：资产宽高比，仅用于把内容框放大到 aspectFill 尺寸；项目帧不受影响。
    let assetAspectRatio: (String) -> CGFloat
    let onPhotoSwitch: () -> Void

    @StateObject private var motion: S2BottomStripMotionController

    init(
        machine: S2StateMachine,
        metrics: S2BottomStripMetrics,
        markSize: CGFloat,
        itemContent: @escaping S2View.StripItemContent,
        assetAspectRatio: @escaping (String) -> CGFloat = { _ in 1 },
        onPhotoSwitch: @escaping () -> Void
    ) {
        _machine = ObservedObject(wrappedValue: machine)
        self.metrics = metrics
        self.markSize = markSize
        self.itemContent = itemContent
        self.assetAspectRatio = assetAspectRatio
        self.onPhotoSwitch = onPhotoSwitch
        let motion = S2BottomStripMotionController(
            layout: S2BottomStripLayout(metrics: metrics),
            hooks: S2BottomStripMotionController.hooks(
                machine: machine,
                onPhotoSwitch: onPhotoSwitch
            )
        )
        // 首帧即居中当前张，不等 onAppear（离屏渲染同样成立）。
        motion.synchronize(
            count: machine.orderedAssetIDs.count,
            currentIndex: machine.currentIndex
        )
        _motion = StateObject(wrappedValue: motion)
    }

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
            // IC-093 R2：渲染收敛到 `S2PendingDeletionMark`（白符号 + 半透黑圆底）；
            // 尺寸、位置、显示条件与圆角裁切关系不变。
            S2PendingDeletionMark(size: mark.size)
                .accessibilityHidden(true)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let assetIDs = machine.orderedAssetIDs
            let layout = motion.layout
            let visible = layout.visibleIndices(
                contentX: motion.contentX,
                viewportWidth: geometry.size.width,
                count: assetIDs.count
            )
            ZStack(alignment: .topLeading) {
                ForEach(Array(visible), id: \.self) { index in
                    let assetID = assetIDs[index]
                    let frame = layout.frame(
                        at: index,
                        currentIndex: machine.currentIndex,
                        expansion: motion.expansion,
                        contentX: motion.contentX,
                        viewportSize: geometry.size
                    )
                    let contentSize = S2BottomStripLayout.fillContentSize(
                        cellSize: frame.size,
                        assetAspectRatio: assetAspectRatio(assetID)
                    )
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
                    // IC-085 R3：内容框按 aspectFill 放大后以项目帧居中裁切。
                    .frame(width: contentSize.width, height: contentSize.height)
                    .frame(width: frame.width, height: frame.height)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        stripMark(for: assetID)
                    }
                    // IC-090 R1：内容与待删标记叠层一并按圆角裁切。半径为常量，
                    // 展开／收缩过程中不随项目尺寸变化（实测邻居 60 px 与当前张
                    // 90 px 同半径）。
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: metrics.cornerRadius,
                            style: .circular
                        )
                    )
                    .position(x: frame.midX, y: frame.midY)
                    .accessibilityLabel(L10n.text(
                        "s2.strip.item.accessibility",
                        replacing: [
                            "current": String(index + 1),
                            "total": String(assetIDs.count)
                        ]
                    ))
                    .accessibilityValue(markAccessibilityValue(for: assetID))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .mask {
                fadeMask(width: geometry.size.width)
            }
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(stripGesture)
            }
            .onAppear {
                motion.synchronize(
                    count: assetIDs.count,
                    currentIndex: machine.currentIndex
                )
            }
            .onChange(of: machine.currentIndex) { _, currentIndex in
                // 主图翻页引起的定位项变化：动画跟随；横栏拖动中由控制器自行跟踪。
                motion.synchronize(
                    count: machine.orderedAssetIDs.count,
                    currentIndex: currentIndex,
                    animated: true
                )
            }
            .onChange(of: machine.orderedAssetIDs.count) { _, count in
                motion.synchronize(
                    count: count,
                    currentIndex: machine.currentIndex
                )
            }
            .onChange(of: metrics) { _, metrics in
                motion.layout = S2BottomStripLayout(metrics: metrics)
                motion.synchronize(
                    count: machine.orderedAssetIDs.count,
                    currentIndex: machine.currentIndex
                )
            }
        }
    }

    private func fadeMask(width: CGFloat) -> some View {
        let stops = motion.layout.fadeStops(viewportWidth: width)
        return LinearGradient(
            stops: stops.map { stop in
                Gradient.Stop(
                    color: Color.black.opacity(Double(stop.opacity)),
                    location: stop.location
                )
            },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func markAccessibilityValue(for assetID: String) -> String {
        machine.pendingDeletionAssetIDs.contains(assetID)
            ? L10n.text("s2.strip.item.marked")
            : L10n.text("s2.strip.item.unmarked")
    }

    /// 拖动识别沿用原生 pan 默认起始距离；速度取自 iOS 17 `DragGesture.Value.velocity`。
    private var stripGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if motion.phase != .dragging {
                    guard motion.beginDrag() else {
                        return
                    }
                }
                motion.updateDrag(translation: value.translation.width)
            }
            .onEnded { value in
                motion.endDrag(velocity: value.velocity.width)
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
