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
    /// IC-108 B：图像请求发起观测（目标尺寸），仅供探针记录。
    var onImageRequestStarted: (CGSize) -> Void = { _ in }
    /// IC-108 B：原始回调观测（是否主线程、返回像素尺寸），仅供探针记录。
    var onImageRequestRawResult: (Bool, CGSize) -> Void = { _, _ in }
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
    /// IC-108 B：双击丝滑度探针。默认关闭；关闭时不向 pager 传引用，埋点零开销。
    @StateObject private var doubleTapProbe =
        S2DoubleTapSmoothnessProbeCoordinator()
    /// IC-099 阶段二 R4：占用空间的会话级缓存与异步取数管线。随本视图释放。
    @StateObject private var assetVolumeStore = S2AssetVolumeStore()
    /// IC-111 B：标记残影协调器。飞行本身在 UIKit 侧由 CAAnimation 驱动，
    /// 这里只接落点通知，用于垃圾桶回弹与角标滚动。
    @StateObject private var markAfterimages = S2MarkAfterimageCoordinator()
    /// IC-111 B：角标**显示值**。卡内要求「落点同帧 +1」，故显示值不跟随模型
    /// 立即变化——有残影在途时压到落点再跟上。
    @State private var displayedPendingCount = 0
    /// IC-112 B：中央状态指示——当前显示态与最近一次动作。
    @State private var centerIndicatorState: S2CenterIndicatorState?
    @State private var centerIndicatorLastAction: S2CenterIndicatorAction?
    /// IC-111 C：加入相簿残影的时序闸门与中胶囊入场进度。
    @State private var albumAfterimageGate = S2AlbumAfterimageGate()
    /// 0 = 未入场（透明、下沉 8pt），1 = 已就位。
    @State private var albumCapsuleEntrance: CGFloat = 1
    /// IC-110 D：首次引导教程（未定项 20 ④）。持久化走 `UserDefaults`，
    /// 不入标定出厂值、`schemaVersion` 不动。
    @StateObject private var tutorial = S2TutorialCoordinator(
        store: S2UserDefaultsTutorialCompletionStore()
    )
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

                // IC-112 B：旧右上角角标移除，改为主图几何中心的状态指示。
                centerIndicatorOverlay(metrics: viewportMetrics)

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

                // IC-110 D：教程浮层压在最上层（标定浮层之上），
                // 但等真实手势的步骤整层不吃点击，手势原样落到主图。
                if let step = tutorial.activeStep {
                    S2TutorialOverlay(
                        step: step,
                        spotlight: S2TutorialSpotlight.targetRect(
                            step: step,
                            viewportSize: geometry.size,
                            safeAreaInsets: safeAreaInsets,
                            photoSize: viewportMetrics.oneXDisplaySize,
                            photoCenterY: viewportMetrics.oneXDisplayCenterY,
                            bottomStripHeight: viewportMetrics
                                .bottomStripHeight
                        ),
                        spotlightCornerRadius:
                            S2TutorialSpotlight.cornerRadius(for: step),
                        onAcknowledge: { tutorial.acknowledge() },
                        onSkip: { tutorial.skip() }
                    )
                    .task(id: step) {
                        // 第 2 步「点击任意处或 2 秒后推进」的计时分支。
                        guard step == .seeStripMark else {
                            return
                        }
                        try? await Task.sleep(
                            nanoseconds: UInt64(
                                S2TutorialCoordinator.autoAdvanceSeconds *
                                    1_000_000_000
                            )
                        )
                        tutorial.acknowledge()
                    }
                }

                S2SafeAreaInsetsReader(insets: $safeAreaInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(machine.sheetState == .closed)
            .onAppear {
                _ = machine.applyCalibration(calibration.configuration)
                // IC-111 B：进场时显示值与模型值对齐（无残影在途）。
                displayedPendingCount =
                    machine.sessionMergedPendingDeletionCount
                // IC-112 B：进场即按当前页状态落一次指示，不带动画。
                refreshCenterIndicator(animated: false)
                // IC-110 D：首次进入 S2 放一次；已完成/已跳过过不再放。
                tutorial.startIfNeeded()
            }
            .onDisappear {
                // IC-110 D：中途离开 S2 视为跳过，不拦截。
                tutorial.leaveScreen()
            }
            .onChange(of: calibration.configuration) { _, configuration in
                _ = machine.applyCalibration(configuration)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(statusBarHidden)
        // IC-108 B：`imageRequestScale` 变化时刻——探针关闭时 `record...` 内部
        // 的 `isRecording` 守卫直接返回，零记录。
        .onChange(of: machine.imageRequestScale) { _, scale in
            doubleTapProbe.recordImageRequestScaleChange(
                scale: scale,
                timestamp: CACurrentMediaTime()
            )
        }
        .onChange(of: machine.interfaceVisibility) { _, visibility in
            applyStatusBarAppearance(for: visibility)
            // IC-112 B：中央指示随 chrome 同显隐（V=隐藏 时不显示）。
            refreshCenterIndicator(animated: true)
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
        // IC-110 C：上滑标记成功＝待删集合新增元素。用已发布状态判定，
        // 不旁路手势分派（同 IC-104 B1 纪律）。下滑取消是移除、不进本分支，
        // 故取消无残影、也无反向飞出（卡内取定）；隐藏态与 Nx 无标记手势
        // （第 132 条），不会产生新增，残影路径天然不存在。
        .onChange(of: machine.pendingDeletionAssetIDs) { previous, current in
            let inserted = current.subtracting(previous)
            let removed = previous.subtracting(current)
            let ordered = machine.orderedAssetIDs
            for assetID in ordered where inserted.contains(assetID) {
                // IC-110 D 第 1 步：等的就是这个真实上滑标记。
                // IC-111 B：残影不再从这里起飞——改由 pager 在 UIKit 侧以
                // CAAnimation 驱动（见 `S2MarkAfterimagePresenter`）。
                tutorial.assetDidBecomeMarked(assetID: assetID)
            }
            // IC-110 D 第 4 步：真实下滑取消＝集合移除。
            // 残影不走这条分支——取消不做反向飞出（卡内取定）。
            for assetID in removed {
                tutorial.assetDidBecomeUnmarked(assetID: assetID)
            }
            // IC-112 B：标记/撤回都算一次「最近动作」，据此裁决两态并存时显示哪种。
            if !inserted.isEmpty || !removed.isEmpty {
                centerIndicatorLastAction = .mark
                refreshCenterIndicator(animated: true)
            }
        }
        // IC-112 B：收藏态变化——同上记一次最近动作。
        .onChange(of: machine.currentIsFavorite) { _, _ in
            centerIndicatorLastAction = .favorite
            refreshCenterIndicator(animated: true)
        }
        .onChange(of: machine.currentAssetID) { _, assetID in
            // IC-110 D 第 3 步：等用户真实翻回刚标记那张。
            tutorial.currentAssetDidChange(to: assetID)
            // IC-112 B：翻页即随新页状态刷新，且**不带动画**（卡内 ④）。
            // 新页的状态不是任何一次近期动作造成的，故清掉最近动作。
            centerIndicatorLastAction = nil
            centerIndicatorState = nil
            refreshCenterIndicator(animated: false)
        }
        // IC-111 B：模型值变化时——有残影在途就压住，等落点再跟上（卡内「同帧」）；
        // 没有在途残影（取消标记、确认页回来等）就立即跟上，不留滞后。
        .onChange(of: machine.sessionMergedPendingDeletionCount) { _, count in
            guard markAfterimages.inFlightCount == 0 else {
                return
            }
            displayedPendingCount = count
        }
        // IC-111 B：落点——同帧把角标滚到模型值。回弹由 landedTick 触发。
        .onChange(of: markAfterimages.landedTick) { _, _ in
            withAnimation(.snappy(duration: 0.2)) {
                displayedPendingCount =
                    machine.sessionMergedPendingDeletionCount
            }
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
            // IC-108 B：只有录制中才把探针引用交给 pager；关闭态传 nil，
            // pager 侧埋点是可选链空调用，零开销。
            doubleTapProbe: doubleTapProbe.isRecording ? doubleTapProbe : nil,
            // IC-111 B：标记残影由 pager 在 UIKit 侧起飞，这里只把协调器交过去。
            markAfterimages: markAfterimages,
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
                },
                // IC-108 B：图像请求发起 / 原始回调（含真实线程与返回像素）转给探针。
                onImageRequestStarted: { [doubleTapProbe] targetSize in
                    doubleTapProbe.recordImageRequestStarted(
                        assetID: assetID,
                        targetSize: targetSize,
                        timestamp: CACurrentMediaTime()
                    )
                },
                onImageRequestRawResult: { [doubleTapProbe] isMain, pixelSize in
                    doubleTapProbe.recordImageRequestFinished(
                        assetID: assetID,
                        onMainThread: isMain,
                        pixelSize: pixelSize,
                        timestamp: CACurrentMediaTime()
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
                // IC-111 A：顶栏帧高 = `topBarHeight`（3 + 44 = 47）；
                // 行内由 `S2TopBarLayout` 按 `topElementFrames` 落位——
                // 上缘留 `topRowTopInset` 3、左右 `chromeHorizontalMargin` 16。
                // 渲染与门禁模型共用同一个 `topElementFrames`，不另起真相。
                topBar
                    .frame(height: S2OverlayLayout.topBarHeight)

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
            .background(.ultraThinMaterial)
            .padding(
                .bottom,
                S2OverlayLayout.stripBottomFromViewportBottom(
                    safeAreaBottom: safeAreaInsets.bottom
                )
            )

            // 触控带底缘恰为安全区上沿——「避让安全区贴近底缘」，
            // 且满足既有门禁 L2（底部元素不进入主屏幕指示条区域）。
            // IC-110 B：同上，整条不再铺玻璃；触控带高与底缘锚点一字未动。
            actionBar
                .padding(
                    .horizontal,
                    S2OverlayLayout.chromeHorizontalMargin
                )
                .frame(maxWidth: .infinity)
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
    /// IC-112 B：中央状态指示浮层。位置 = **主图几何中心**
    /// （视口中心 X + `oneXDisplayCenterY`，故截图的适配带锚定同样正确）。
    ///
    /// 出现/消失 200 ms 淡入淡出 + scale 0.9→1 / 1→0.9；两者都是属性动画，
    /// 由渲染层推进。翻页引起的刷新**不带动画**（见 `refreshCenterIndicator`
    /// 的 `disablesAnimations` 事务）。
    @ViewBuilder
    private func centerIndicatorOverlay(
        metrics: S2ViewportMetrics
    ) -> some View {
        if let state = centerIndicatorState {
            S2CenterIndicatorView(state: state) {
                undoFavoriteFromCenterIndicator()
            }
            .position(
                x: metrics.viewportSize.width / 2,
                y: metrics.oneXDisplayCenterY
            )
            .task(id: state) {
                // 短提示到时自行淡出，随后按模型态复算（此时已非收藏态，
                // 故通常复算为 nil＝不显示）。
                guard case .removed = state else {
                    return
                }
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        S2CenterIndicatorResolver.removedNoticeSeconds *
                            1_000_000_000
                    )
                )
                withAnimation(
                    .easeInOut(
                        duration: S2CenterIndicatorResolver.transitionSeconds
                    )
                ) {
                    centerIndicatorState = nil
                }
                refreshCenterIndicator(animated: true)
            }
            .transition(
                .opacity.combined(
                    with: .scale(
                        scale: S2CenterIndicatorResolver.hiddenScale
                    )
                )
            )
        }
    }

    /// ♡ 所对应的系统「最爱」相簿名。
    ///
    /// 产品里 ♡ 是 `PHAsset` 收藏、没有相簿名概念（本卡登记的差异），
    /// 故这里取一个可本地化的常量名，格式参数的形状与卡内一致。
    private var favoritesAlbumName: String {
        L10n.text("s2.center.favorites_album")
    }

    /// IC-112 B：点撤回 → 取消收藏，短提示「已从「名」移除」后整块淡出。
    private func undoFavoriteFromCenterIndicator() {
        guard let request = machine.makeFavoriteToggleRequest() else {
            return
        }
        let albumName = favoritesAlbumName
        onFavoriteRequest(request)
        centerIndicatorLastAction = nil
        withAnimation(
            .easeInOut(duration: S2CenterIndicatorResolver.transitionSeconds)
        ) {
            centerIndicatorState = .removed(albumName: albumName)
        }
    }

    /// IC-112 B：按当前模型态重算中央指示。`animated == false` 用于翻页刷新。
    ///
    /// `removed` 是撤回后的短提示过渡态，不由模型产出，故刷新时不覆盖它——
    /// 它由自己的计时清掉。
    private func refreshCenterIndicator(animated: Bool) {
        if case .removed = centerIndicatorState {
            return
        }
        let next = S2CenterIndicatorResolver.state(
            interfaceVisibility: machine.interfaceVisibility,
            isMarked: machine.currentIsMarked,
            isFavorited: machine.currentIsFavorite,
            favoritesAlbumName: favoritesAlbumName,
            lastAction: centerIndicatorLastAction
        )
        guard next != centerIndicatorState else {
            return
        }
        if animated {
            withAnimation(
                .easeInOut(
                    duration: S2CenterIndicatorResolver.transitionSeconds
                )
            ) {
                centerIndicatorState = next
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                centerIndicatorState = next
            }
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
                Image(systemName: "chevron.backward")
                    .s2ChromeCircleGlass()
            }
            .accessibilityLabel(L10n.text("s2.action.back"))
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
            .contentShape(Rectangle())

            topInfoArea
                .s2ChromeCapsuleGlass()
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
                    .s2ChromeCircleGlass()
                    .overlay(alignment: .topTrailing) {
                        if let badgeText = displayedBadgeText {
                            Text(badgeText)
                                .monospacedDigit()
                                // IC-111 B：落点同帧的数字滚动。
                                .contentTransition(.numericText())
                        }
                    }
                    // IC-111 B：落点同帧的 spring 回弹 1 → 1.15 → 1。
                    // 触发源是残影落点计数，故与残影收口同帧。
                    .keyframeAnimator(
                        initialValue: CGFloat(1),
                        trigger: markAfterimages.landedTick
                    ) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.15, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.18)
                    }
            }
            // IC-111 D：教程态下确认删除**不可真实触发**——步 5 只指向入口。
            .disabled(!machine.canEnterConfirmation || tutorial.isRunning)
            .accessibilityLabel(confirmationEntry.accessibilityLabel)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .trailing
            )
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
                    .font(.system(
                        size: S2ChromePillMetrics.titleFontSize,
                        weight: .semibold
                    ))
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
            .font(.system(size: S2ChromePillMetrics.subtitleFontSize))
            // 画布 ④：副行为白 62%。深色 chrome 上以 `.white` 加不透明度表达，
            // 不用 `.secondary`——后者随环境浮动，对不上画布定值。
            .foregroundStyle(
                Color.white.opacity(S2ChromePillMetrics.subtitleOpacity)
            )
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

    /// 确认页入口呈现。**仍读模型值**——启用与否、无障碍标签都不得因残影而滞后。
    private var confirmationEntry: S2ConfirmationEntryPresentation {
        S2ConfirmationEntryPresentation(
            sessionPendingCount: machine.sessionMergedPendingDeletionCount
        )
    }

    /// IC-111 B：角标**文案**单独走显示值——卡内要求数字与残影落点同帧 +1，
    /// 故只有这一处被推迟，按钮启用与无障碍标签一律不受影响。
    private var displayedBadgeText: String? {
        S2ConfirmationEntryPresentation(
            sessionPendingCount: displayedPendingCount
        ).badgeText
    }

    /// IC-110 B：底部 chrome 换装为「左圆钮 + 中跑道胶囊 + 右圆钮」。
    ///
    /// 中胶囊承载**现有**「加入最近相簿」按钮（④ 2026-08-29 定案）：卡内 ④ 原写
    /// 「加入微信」，但代码库、SPEC v17、Decision_log 三处均无微信实现或条款（①），
    /// 新增该动作属按钮增删、不得自定，故按定案用现有按钮占位，微信另行立项。
    /// 该按钮沿用原有条件显示（`machine.recentAlbum == nil` 时不显示），
    /// 此时中位留空、只余左右圆钮。
    ///
    /// `S2ActionBarPresentation` 的启用/禁用规则与触控带高度零语义变化，只换容器样式。
    private var actionBar: some View {
        let presentation = S2ActionBarPresentation(machine: machine)
        // IC-111 A：左右圆钮贴边距 16，中胶囊被两侧 Spacer 夹住 ⟹ 宽随内容且
        // 水平居中（画布 ④）。无最近相簿时两个 Spacer 合并，只余左右圆钮。
        return HStack(spacing: S2OverlayLayout.minimumSpacing) {
            Button {
                guard let request = machine.makeFavoriteToggleRequest() else {
                    return
                }
                onFavoriteRequest(request)
            } label: {
                Image(
                    systemName: machine.currentIsFavorite
                        ? "heart.fill"
                        : "heart"
                )
                .s2ChromeCircleGlass()
            }
            .disabled(!presentation.favoriteEnabled)
            .accessibilityLabel(favoriteActionTitle)

            Spacer(minLength: 0)

            if let album = machine.recentAlbum {
                Button {
                    guard let request = machine.makeRecentAlbumAdditionRequest() else {
                        return
                    }
                    onRecentAlbumRequest(request)
                    // IC-111 C：直接点中胶囊加入 → 立即起飞（入场中则不放行）。
                    if albumAfterimageGate.requestDirectLaunch() {
                        markAfterimages.launchAlbumAfterimage?()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(
                                size: S2ChromePillMetrics
                                    .bottomCapsuleIconPointSize,
                                weight: .medium
                            ))
                        Text(verbatim: L10n.text(
                            "s2.action.add_recent_album",
                            replacing: ["album": album.name]
                        ))
                        .font(.system(
                            size: S2ChromePillMetrics
                                .bottomCapsuleTextFontSize
                        ))
                        .lineLimit(1)
                    }
                    .s2ChromeCapsuleGlass()
                }
                .disabled(!presentation.recentAlbumEnabled)
                // IC-111 C：落点同帧的回弹 1 → 1.12 → 1。
                .keyframeAnimator(
                    initialValue: CGFloat(1),
                    trigger: markAfterimages.albumLandedTick
                ) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(1.12, duration: 0.12)
                    SpringKeyframe(1.0, duration: 0.18)
                }
                // IC-111 C：入场＝淡入 + 上浮 8pt（未入场时下沉且透明）。
                .opacity(Double(albumCapsuleEntrance))
                .offset(
                    y: (1 - albumCapsuleEntrance) *
                        S2AlbumCapsuleEntrance.rise
                )

                Spacer(minLength: 0)
            }

            Button {
                performCalibratedAnimation {
                    _ = machine.presentAlbumPicker()
                }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .s2ChromeCircleGlass()
            }
            .disabled(!presentation.addAlbumEnabled)
            .accessibilityLabel(L10n.text("s2.action.add_album"))
        }
        .frame(height: S2OverlayLayout.chromeRowHeight)
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
                        // IC-111 C（④ 时序）：首次换新相簿——选择器收起后
                        // 中胶囊先入场（淡入 + 上浮 8pt，120ms），
                        // **入场完成才允许残影起飞**；同一相簿再来走立即路径。
                        if albumAfterimageGate.albumSelected(id: album.id) {
                            albumCapsuleEntrance = 0
                            withAnimation(
                                .easeOut(
                                    duration: S2AlbumCapsuleEntrance
                                        .durationSeconds
                                )
                            ) {
                                albumCapsuleEntrance = 1
                            }
                            Task { @MainActor in
                                try? await Task.sleep(
                                    nanoseconds: UInt64(
                                        S2AlbumCapsuleEntrance
                                            .durationSeconds * 1_000_000_000
                                    )
                                )
                                if albumAfterimageGate.entranceDidFinish() {
                                    markAfterimages.launchAlbumAfterimage?()
                                }
                            }
                        } else {
                            markAfterimages.launchAlbumAfterimage?()
                        }
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
                doubleTapProbeSection
                // IC-087：恢复出厂值——重置配置并删除 Keychain 条目；经 onChange(of: calibration.configuration)
                // → machine.applyCalibration → pager.apply 对当前页即时生效。
                Button(L10n.text("s2.calibration.restore_factory")) {
                    calibration.restoreFactoryPlaceholder()
                }
                .s2MinimumTouchTarget()
                // IC-110 D：重看教程。清掉持久化标记并当场重放。
                Button(L10n.text("s2.tutorial.replay")) {
                    tutorial.replay()
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

    /// IC-108 B：调试面板的双击丝滑度探针段。只读区 + 复制入口，模式照 IC-099b。
    /// 探针只做观测，不改双击 / 缩放 / 解码任何行为。
    @ViewBuilder
    private var doubleTapProbeSection: some View {
        Divider()
        Text(L10n.text("s2.calibration.double_tap_probe.title"))
        Button(
            doubleTapProbe.isRecording
                ? L10n.text("s2.calibration.double_tap_probe.stop")
                : L10n.text("s2.calibration.double_tap_probe.start")
        ) {
            if doubleTapProbe.isRecording {
                doubleTapProbe.stop()
            } else {
                doubleTapProbe.start()
            }
        }
        .s2MinimumTouchTarget()
        if !doubleTapProbe.reportText.isEmpty {
            ShareLink(item: doubleTapProbe.reportText) {
                Text(L10n.text("s2.calibration.double_tap_probe.share"))
            }
            .s2MinimumTouchTarget()
            Text(verbatim: doubleTapProbe.reportText)
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

/// IC-110 B：chrome 换装的视觉微观取值。参照系统 Photos 的玻璃圆钮 + 跑道胶囊。
///
/// 这些是**视觉微观取定**（卡内取定 + 报告登记），不是布局锚：
/// 不进 `S2CalibrationConfiguration`、不上参数面板、`schemaVersion` 不动。
/// 布局锚见 `S2OverlayLayout`——IC-111 A 已按 v18 画布整体重定
/// （`chromeRowHeight` 44、`topRowTopInset` 3、`bottomRowBottomInset` 8、
/// `chromeHorizontalMargin` 16、`stripToBottomRowSpacing` 24）。
enum S2ChromePillMetrics {
    /// 圆钮直径 = 胶囊高 = chrome 行高。IC-111 A 由 36 改为画布的 44，
    /// 与 `S2OverlayLayout.chromeRowHeight` 同源，可见带自此就是触控带本身。
    static var pillHeight: CGFloat {
        S2OverlayLayout.chromeRowHeight
    }

    /// 胶囊内水平留白。
    static let capsuleHorizontalPadding: CGFloat = 14

    /// 圆钮图标字号（画布 ④）。
    static let circleIconPointSize: CGFloat = 17

    /// 顶部胶囊主行（日期）字号与字重（画布 ④）。
    static let titleFontSize: CGFloat = 15

    /// 顶部胶囊副行（序号·大小）字号与不透明度（画布 ④：白 62%）。
    static let subtitleFontSize: CGFloat = 11.5
    static let subtitleOpacity: Double = 0.62

    /// 底部胶囊：时钟图标 17pt + 文字 15pt（画布 ④）。
    static let bottomCapsuleIconPointSize: CGFloat = 17
    static let bottomCapsuleTextFontSize: CGFloat = 15
}

/// IC-112 A：chrome 玻璃配方与高光描边（画布第三轮定稿 ④）。
///
/// **勘查结论（报告详录）**：不是层级问题——药丸材质本就位于照片层之上，
/// 且 chrome 祖先链上唯一的 `.opacity()` 在 `V=显示` 时恒为 1.0，
/// 而离屏合成组只在 opacity < 1 时产生，故稳定显示态下不抑制背景采样。
/// 真正要改的是**配方**：单用 `.ultraThinMaterial` 在深色环境下偏暗去饱和，
/// 读起来像实心块。故在材质之上补一层白色薄底并加高光描边。
///
/// 画布配方基准：底色白 ~6% + blur ~22 + 饱和 ~1.7 + 提亮 ~1.12。
/// blur 与饱和/提亮沿用系统材质自带的（卡内明示「系统材质能达到同观感即可，
/// 不强求逐参数复刻」）；**未叠加 `.saturation()` / `.brightness()`**——
/// 这两个滤镜会把子树推进离屏合成，反而会打掉材质的背景采样，得不偿失。
enum S2ChromeGlass {
    /// 材质之上的白色薄底（画布「底色白 ~6%」）。
    static let tintOpacity: Double = 0.06

    /// 内描边：顶缘内侧白 55%，渐弱至底缘 12%（画布 ④）。
    static let innerHighlightTop: Double = 0.55
    static let innerHighlightBottom: Double = 0.12
    static let innerStrokeWidth: CGFloat = 1

    /// 外圈细环白 22%（画布 ④）。
    static let outerRingOpacity: Double = 0.22
    static let outerStrokeWidth: CGFloat = 0.5
}

private extension View {
    /// IC-112 A：统一的玻璃底 + 高光描边。顶/底六件与中央指示容器共用同一族。
    ///
    /// 截图显示态下 chrome 背后为黑、透光弱是预期；**描边不依赖背景**，
    /// 故那种情形下描边仍在（卡内明示要求）。
    func s2ChromeGlassBackground<S: InsettableShape>(
        in shape: S
    ) -> some View {
        background {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(S2ChromeGlass.tintOpacity))
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(S2ChromeGlass.innerHighlightTop),
                        Color.white.opacity(S2ChromeGlass.innerHighlightBottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: S2ChromeGlass.innerStrokeWidth
            )
        }
        .overlay {
            shape.strokeBorder(
                Color.white.opacity(S2ChromeGlass.outerRingOpacity),
                lineWidth: S2ChromeGlass.outerStrokeWidth
            )
        }
    }

    /// 玻璃圆钮：定尺 Ø44 + 玻璃底 + 高光描边。
    func s2ChromeCircleGlass() -> some View {
        font(
            .system(
                size: S2ChromePillMetrics.circleIconPointSize,
                weight: .semibold
            )
        )
        .frame(
            width: S2ChromePillMetrics.pillHeight,
            height: S2ChromePillMetrics.pillHeight
        )
        .s2ChromeGlassBackground(in: Circle())
    }

    /// 玻璃跑道胶囊：宽随内容 + 定高 44 + 同族玻璃底与描边。
    func s2ChromeCapsuleGlass() -> some View {
        padding(
            .horizontal,
            S2ChromePillMetrics.capsuleHorizontalPadding
        )
        .frame(height: S2ChromePillMetrics.pillHeight)
        .s2ChromeGlassBackground(in: Capsule())
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
// MARK: - IC-110 D：首次引导教程

/// IC-111 D：教程手势图示的方向。
enum S2TutorialGestureDirection: Equatable {
    case up
    case down
    case right

    /// 单次循环的位移向量（沿方向走 `S2TutorialGestureHint.travel`）。
    var offset: CGSize {
        switch self {
        case .up:
            return CGSize(width: 0, height: -S2TutorialGestureHint.travel)
        case .down:
            return CGSize(width: 0, height: S2TutorialGestureHint.travel)
        case .right:
            return CGSize(width: S2TutorialGestureHint.travel, height: 0)
        }
    }
}

extension S2TutorialStep {
    /// 该步要示意的手势方向。观察/点击类步骤没有手势图示。
    var gestureDirection: S2TutorialGestureDirection? {
        switch self {
        case .swipeUpToMark:
            return .up
        case .returnToMarked:
            // 标记会前进一张，故「回到刚才那张」是向右拖回。
            return .right
        case .swipeDownToCancel:
            return .down
        case .seeStripMark, .confirmEntry:
            return nil
        }
    }
}

/// IC-111 D：聚光挖孔的目标矩形。**纯函数**，可被单测直接复算。
///
/// 步 1/3/4 套主图、步 2 套横栏、步 5 套右上垃圾桶圆钮（④）。
/// 横栏与圆钮都用 chrome 自己的推导式取，不另起一套真相。
enum S2TutorialSpotlight {
    /// 挖孔相对目标的外扩留白与圆角（卡内取定）。
    static let padding: CGFloat = 8
    static let cornerRadius: CGFloat = 18
    /// 圆钮那一步用正圆挖孔。
    static let circleCornerRadius: CGFloat = 999

    static func targetRect(
        step: S2TutorialStep,
        viewportSize: CGSize,
        safeAreaInsets: S2OverlaySafeAreaInsets,
        photoSize: CGSize,
        photoCenterY: CGFloat,
        bottomStripHeight: CGFloat
    ) -> CGRect {
        switch step {
        case .swipeUpToMark, .returnToMarked, .swipeDownToCancel:
            return CGRect(
                x: (viewportSize.width - photoSize.width) / 2,
                y: photoCenterY - photoSize.height / 2,
                width: photoSize.width,
                height: photoSize.height
            ).insetBy(dx: -padding, dy: -padding)
        case .seeStripMark:
            let bottom = S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: safeAreaInsets.bottom
            )
            return CGRect(
                x: safeAreaInsets.leading,
                y: viewportSize.height - bottom - bottomStripHeight,
                width: max(
                    0,
                    viewportSize.width - safeAreaInsets.leading -
                        safeAreaInsets.trailing
                ),
                height: bottomStripHeight
            ).insetBy(dx: -padding, dy: -padding)
        case .confirmEntry:
            let frames = S2OverlayLayout.topElementFrames(
                in: CGRect(
                    x: 0,
                    y: safeAreaInsets.top,
                    width: viewportSize.width,
                    height: S2OverlayLayout.topBarHeight
                )
            )
            guard frames.count == 3 else {
                return .zero
            }
            return frames[2].insetBy(dx: -padding, dy: -padding)
        }
    }

    static func cornerRadius(for step: S2TutorialStep) -> CGFloat {
        step == .confirmEntry ? circleCornerRadius : cornerRadius
    }
}

/// IC-111 D：手势图示——触点圆（Ø26 环 + Ø14 实心）+ 方向箭头，
/// 循环 0.9 s/次：沿方向位移 40 pt + 渐隐。
///
/// 用 `repeatForever` 的**属性动画**（位移与不透明度），由渲染层持续推进，
/// 主线程不逐帧参与；不是 `keyframeAnimator` 那种主线程步进。
struct S2TutorialGestureHint: View {
    let direction: S2TutorialGestureDirection

    /// 单次循环的位移与周期（卡内 ④）。
    static let travel: CGFloat = 40
    static let cycleSeconds: TimeInterval = 0.9
    /// 触点圆尺寸（卡内 ④）。
    static let ringDiameter: CGFloat = 26
    static let coreDiameter: CGFloat = 14

    @State private var looping = false

    var body: some View {
        VStack(spacing: 10) {
            if direction == .down {
                arrow
            }
            touchPoint
            if direction != .down {
                arrow
            }
        }
        .offset(
            x: looping ? direction.offset.width : 0,
            y: looping ? direction.offset.height : 0
        )
        .opacity(looping ? 0 : 1)
        .onAppear {
            withAnimation(
                .linear(duration: Self.cycleSeconds)
                    .repeatForever(autoreverses: false)
            ) {
                looping = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var touchPoint: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                .frame(
                    width: Self.ringDiameter,
                    height: Self.ringDiameter
                )
            Circle()
                .fill(Color.white)
                .frame(
                    width: Self.coreDiameter,
                    height: Self.coreDiameter
                )
        }
    }

    /// 方向箭头。符号名在调用点逐个内联——扫描器会把「返回字符串的展示
    /// helper」当成用户可见文案抓走，图标名不能从 helper 里返回。
    @ViewBuilder
    private var arrow: some View {
        Group {
            switch direction {
            case .up:
                Image(systemName: "arrow.up")
            case .down:
                Image(systemName: "arrow.down")
            case .right:
                Image(systemName: "arrow.right")
            }
        }
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
    }
}

/// IC-111 D：教程浮层。55% 黑遮罩 + 聚光挖孔 + 手势图示 + 玻璃提示卡。
///
/// 遮罩**不吞真实手势**：等真实手势的三步（1/3/4）整层不参与命中测试，
/// 手势原样落到主图；只有不等手势的两步（2/5）吃点击用于推进。
/// 挖孔在步骤间以 spring 移动变形，不闪切。
struct S2TutorialOverlay: View {
    let step: S2TutorialStep
    let spotlight: CGRect
    let spotlightCornerRadius: CGFloat
    let onAcknowledge: () -> Void
    let onSkip: () -> Void

    /// 遮罩黑度（卡内 ④）。
    static let dimOpacity: Double = 0.55

    var body: some View {
        ZStack {
            dimmedMask
                .allowsHitTesting(!step.waitsForRealGesture)
                .onTapGesture { onAcknowledge() }

            if let direction = step.gestureDirection {
                S2TutorialGestureHint(direction: direction)
                    .position(x: spotlight.midX, y: spotlight.midY)
            }

            VStack {
                Spacer()
                hintCard
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    /// 55% 黑，按聚光矩形挖孔；孔随步骤 spring 移动变形。
    private var dimmedMask: some View {
        Rectangle()
            .fill(Color.black.opacity(Self.dimOpacity))
            .mask {
                Rectangle()
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: spotlightCornerRadius,
                            style: .continuous
                        )
                        .frame(
                            width: spotlight.width,
                            height: spotlight.height
                        )
                        .position(x: spotlight.midX, y: spotlight.midY)
                        .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: step)
            .ignoresSafeArea()
    }

    private var hintCard: some View {
        VStack(spacing: 14) {
            Text(step.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            progressDots

            if step == .confirmEntry {
                Button(L10n.text("s2.tutorial.done")) {
                    onAcknowledge()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(Color.accentColor, in: Capsule())
            } else {
                Button(L10n.text("s2.tutorial.skip")) {
                    onSkip()
                }
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(
            cornerRadius: 20,
            style: .continuous
        ))
        .overlay(alignment: .topTrailing) {
            // 「跳过」常驻——步 5 主按钮换成「完成」后，跳过仍在右上角。
            if step == .confirmEntry {
                Button(L10n.text("s2.tutorial.skip")) {
                    onSkip()
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(10)
            }
        }
    }

    /// 五点进度。
    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(S2TutorialStep.allCases, id: \.rawValue) { item in
                Circle()
                    .fill(
                        item.rawValue <= step.rawValue
                            ? Color.primary
                            : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - IC-110 D：首次引导教程

/// 五步脚本（未定项 20，④ 流程 + 决策会话补充）。全程显示态、1x，
/// 用用户当前真实照片，**不发生任何真实删除**——第 5 步只指向确认入口并结束，
/// 不进入确认页。
enum S2TutorialStep: Int, CaseIterable, Equatable {
    /// 上滑手势示意 → 等用户**真实上滑标记**当前照片。
    case swipeUpToMark = 1
    /// 高亮横栏对应格位（残影动画自然发生）→ 点击任意处或 2 秒后推进。
    case seeStripMark = 2
    /// 引导翻回刚标记那张 → 等用户**真实回到该张**。
    case returnToMarked = 3
    /// 下滑手势示意 → 等用户**真实下滑取消**。
    case swipeDownToCancel = 4
    /// 指向右上角确认入口 → 点击任意处结束。
    case confirmEntry = 5

    /// 步骤文案。每个分支各自整句取文案，不拼 key、也不把 key 外传——
    /// 硬编码扫描器只认取文案调用里写死的字面量 key，拼出来的 key 它查不到，
    /// 会判成「目录有条目、源码无引用」而卡门禁。
    /// （本注释刻意不写出那个调用的样子：注释里的字面量同样会被扫描器抓成 key。）
    var text: String {
        switch self {
        case .swipeUpToMark:
            return L10n.text("s2.tutorial.step1")
        case .seeStripMark:
            return L10n.text("s2.tutorial.step2")
        case .returnToMarked:
            return L10n.text("s2.tutorial.step3")
        case .swipeDownToCancel:
            return L10n.text("s2.tutorial.step4")
        case .confirmEntry:
            return L10n.text("s2.tutorial.step5")
        }
    }

    /// 该步是否在等一个真实手势（等待期间不接受「点击推进」）。
    var waitsForRealGesture: Bool {
        switch self {
        case .swipeUpToMark, .returnToMarked, .swipeDownToCancel:
            return true
        case .seeStripMark, .confirmEntry:
            return false
        }
    }
}

enum S2TutorialOutcome: Equatable {
    case completed
    case skipped
}

/// IC-110 D：教程状态机。
///
/// **不旁路手势分派**（停线 D1，参照 IC-104 B1）：三处「等真实手势」全部靠
/// 状态机已发布的状态判定——上滑标记＝`pendingDeletionAssetIDs` 新增、
/// 下滑取消＝同集合移除、翻回＝`currentAssetID` 变为记下的那张。
/// 本类不接触任何手势识别器，故 D1 的前提不成立。
final class S2TutorialCoordinator: ObservableObject {
    /// 第 2 步的自动推进秒数（卡内取定）。
    static let autoAdvanceSeconds: TimeInterval = 2

    @Published private(set) var activeStep: S2TutorialStep?
    @Published private(set) var outcome: S2TutorialOutcome?

    /// 第 1 步标记下的那张，供第 3、4 步比对。
    private(set) var markedAssetID: String?

    private let store: S2TutorialCompletionStoring

    init(store: S2TutorialCompletionStoring) {
        self.store = store
    }

    var isRunning: Bool {
        activeStep != nil
    }

    /// 首次进入 S2 放一次；已完成或已跳过过就不再放。
    func startIfNeeded() {
        guard activeStep == nil,
              outcome == nil,
              !store.isCompleted() else {
            return
        }
        activeStep = .swipeUpToMark
    }

    /// 标定面板「重看教程」：清掉持久化标记并立即重放。
    func replay() {
        store.reset()
        outcome = nil
        markedAssetID = nil
        activeStep = .swipeUpToMark
    }

    // MARK: 真实事件（全部来自已发布状态，不来自手势识别器）

    func assetDidBecomeMarked(assetID: String) {
        guard activeStep == .swipeUpToMark else {
            return
        }
        markedAssetID = assetID
        activeStep = .seeStripMark
    }

    func currentAssetDidChange(to assetID: String) {
        guard activeStep == .returnToMarked,
              assetID == markedAssetID else {
            return
        }
        activeStep = .swipeDownToCancel
    }

    func assetDidBecomeUnmarked(assetID: String) {
        guard activeStep == .swipeDownToCancel,
              assetID == markedAssetID else {
            return
        }
        activeStep = .confirmEntry
    }

    /// 点击任意处或第 2 步计时到点。等真实手势的步骤对此无反应。
    func acknowledge() {
        guard let step = activeStep, !step.waitsForRealGesture else {
            return
        }
        switch step {
        case .seeStripMark:
            activeStep = .returnToMarked
        case .confirmEntry:
            finish(.completed)
        default:
            break
        }
    }

    /// 右上角常驻「跳过」。
    func skip() {
        guard activeStep != nil else {
            return
        }
        finish(.skipped)
    }

    /// 中途离开 S2 视为跳过，不拦截。
    func leaveScreen() {
        guard activeStep != nil else {
            return
        }
        finish(.skipped)
    }

    private func finish(_ outcome: S2TutorialOutcome) {
        activeStep = nil
        self.outcome = outcome
        store.markCompleted()
    }
}

/// IC-112 B：中央状态指示的视图。跑道圆框容器（玻璃 + 描边，与 chrome 同族），
/// 内为方形倒角块。
///
/// **命中测试（硬闸门）**：整块视觉体 `allowsHitTesting(false)`，
/// 只有撤回钮可点——它以 `overlay` 叠在**已禁用命中的子树之外**，
/// 故不受那层禁用影响。翻页 / 缩放 / 标记 / 显隐手势一律从指示区域穿透过去。
struct S2CenterIndicatorView: View {
    let state: S2CenterIndicatorState
    let onUndo: () -> Void

    /// 内部方形倒角块与容器尺寸（卡内取定）。
    static let blockSize: CGFloat = 30
    static let blockCornerRadius: CGFloat = 9
    static let containerHeight: CGFloat = 46
    static let horizontalPadding: CGFloat = 12

    /// 撤回钮是否存在（＝该状态下是否有可点元素）。
    static func showsUndoControl(for state: S2CenterIndicatorState) -> Bool {
        if case .favorited = state {
            return true
        }
        return false
    }

    var body: some View {
        content
            .frame(height: Self.containerHeight)
            .padding(.horizontal, Self.horizontalPadding)
            .s2ChromeGlassBackground(in: Capsule())
            // 视觉体整体不吃点击——手势穿透到主图。
            .allowsHitTesting(false)
            .overlay(alignment: .trailing) {
                // 唯一可点的元素。它在被禁用命中的子树**之外**，故仍可点。
                if Self.showsUndoControl(for: state) {
                    Button(L10n.text("s2.center.undo")) {
                        onUndo()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, Self.horizontalPadding)
                    .frame(height: Self.containerHeight)
                    .contentShape(Rectangle())
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .marked:
            markedBlock
                .accessibilityLabel(L10n.text("s2.mark.primary.accessibility"))
        case let .favorited(albumName):
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(verbatim: L10n.text(
                    "s2.center.favorited",
                    replacing: ["album": albumName]
                ))
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1)
                Divider()
                    .frame(height: 22)
                    .overlay(Color.white.opacity(0.35))
                // 撤回钮的占位：真正可点的那个以 overlay 叠在外层，
                // 这里只用等宽的隐形文本把版面撑出来。
                Text(verbatim: L10n.text("s2.center.undo"))
                    .font(.system(size: 15, weight: .semibold))
                    .opacity(0)
            }
        case let .removed(albumName):
            Text(verbatim: L10n.text(
                "s2.center.removed",
                replacing: ["album": albumName]
            ))
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .lineLimit(1)
        }
    }

    /// 已标记：单块垃圾桶图标（方形倒角块）。
    private var markedBlock: some View {
        RoundedRectangle(
            cornerRadius: Self.blockCornerRadius,
            style: .continuous
        )
        .fill(Color.white.opacity(0.16))
        .frame(width: Self.blockSize, height: Self.blockSize)
        .overlay {
            Image(systemName: "trash.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - IC-112 B：中央状态指示

/// 中央指示的最近一次动作。用于「两态并存时显示哪一种」的裁决（④）。
enum S2CenterIndicatorAction: Equatable {
    case mark
    case favorite
}

/// 中央状态指示的四态之一（同一时刻只显示一种，④）。
///
/// - `marked`：已标记，单块垃圾桶图标。
/// - `favorited`：已收藏，♡ + 收藏到「名」+ 分隔线 + 撤回钮。
///
/// 「下滑撤回」与「点撤回」都不是独立状态——它们的表现就是**整块消失**
/// （消失即撤回成功的确认），故解析结果为 `nil`。
enum S2CenterIndicatorState: Equatable {
    case marked
    case favorited(albumName: String)
    /// 点撤回后的**短提示**过渡态：「已从「名」移除」，随后整块淡出。
    /// 它不由 `resolver` 产出——模型里没有「刚移除」这回事，
    /// 是撤回动作显式置入、到时自行清掉的呈现态。
    case removed(albumName: String)
}

/// IC-112 B：中央指示的状态解析。**纯函数**，可被单测直接复算。
enum S2CenterIndicatorResolver {
    /// 出现/消失动画时长与缩放（画布 ④）。
    static let transitionSeconds: TimeInterval = 0.2
    static let hiddenScale: CGFloat = 0.9

    /// 撤回后「已从「名」移除」短提示的停留时长（卡内取定）。
    static let removedNoticeSeconds: TimeInterval = 1.2

    /// 解析当前该显示哪一种；`nil` = 不显示（含整块淡出的两种撤回路径）。
    ///
    /// 规则（④）：
    /// 1. `V=隐藏` 一律不显示——指示随 chrome 同显隐。
    /// 2. 两态并存时显示**最近一次动作**对应的那种。
    /// 3. 最近动作缺失（例如刚翻页到新的一张，本页的状态不是任何一次
    ///    近期动作造成的）且两态并存时，取 `marked`——待删意图更需要被看见。
    ///    这一条是卡内未覆盖的边角，**卡内取定并登记**。
    static func state(
        interfaceVisibility: S2InterfaceVisibility,
        isMarked: Bool,
        isFavorited: Bool,
        favoritesAlbumName: String,
        lastAction: S2CenterIndicatorAction?
    ) -> S2CenterIndicatorState? {
        guard interfaceVisibility == .visible else {
            return nil
        }
        switch (isMarked, isFavorited) {
        case (false, false):
            return nil
        case (true, false):
            return .marked
        case (false, true):
            return .favorited(albumName: favoritesAlbumName)
        case (true, true):
            switch lastAction {
            case .favorite:
                return .favorited(albumName: favoritesAlbumName)
            case .mark, .none:
                return .marked
            }
        }
    }
}

// MARK: - IC-111 C：加入相簿残影的时序闸门

/// 中胶囊入场闸门（④ 时序规则）。
///
/// - 直接点中胶囊加入 → **立即**起飞。
/// - **首次**经右侧选择器换新相簿 → 选择器收起后中胶囊先入场，
///   **入场完成才允许残影起飞**。
/// - 此后再加入**同一**相簿 → 走立即路径。
///
/// 「首次」按**相簿**计：每个相簿各有一次入场，故 `seenAlbumIDs` 记的是
/// 已经入过场的相簿。纯状态机，不碰动画也不碰几何。
struct S2AlbumAfterimageGate: Equatable {
    private(set) var seenAlbumIDs: Set<String> = []
    private(set) var isEntering = false
    private(set) var hasDeferredLaunch = false

    /// 直接点中胶囊。返回是否可以立即起飞（入场中则不放行，等入场完成）。
    mutating func requestDirectLaunch() -> Bool {
        !isEntering
    }

    /// 经选择器选定相簿。返回 true 表示**需要先播入场**、残影推迟到入场完成。
    mutating func albumSelected(id: String) -> Bool {
        guard !seenAlbumIDs.contains(id) else {
            // 同一相簿再来一次：不再入场，走立即路径。
            return false
        }
        seenAlbumIDs.insert(id)
        isEntering = true
        hasDeferredLaunch = true
        return true
    }

    /// 入场播完。返回 true 表示此刻应把推迟的那一枚残影放飞。
    mutating func entranceDidFinish() -> Bool {
        isEntering = false
        guard hasDeferredLaunch else {
            return false
        }
        hasDeferredLaunch = false
        return true
    }
}

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
