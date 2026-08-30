import Combine
import CoreGraphics
import Foundation

enum S2State: String, CaseIterable, Equatable {
    case visibleOneXIdle = "S2-1"
    case visibleOneXStripDragging = "S2-2"
    case hiddenOneX = "S2-3"
    case visibleNxIdle = "S2-4"
    case visibleNxStripDragging = "S2-5"
    case hiddenNx = "S2-6"
}

enum S2InterfaceVisibility: Equatable {
    case visible
    case hidden
}

enum S2ZoomState: Equatable {
    case oneX
    case nX
}

enum S2BottomStripState: Equatable {
    case idle
    case dragging
}

enum S2SheetState: Equatable {
    case closed
    case presented
}

enum S2TouchSequenceOwner: Equatable {
    case none
    case pinch
    case bottomStrip
}

enum S2UndecidedPlaceholder: Equatable {
    case unresolved
}

enum S2UndecidedItem: String, CaseIterable, Equatable {
    case item01
    case item02
    case item03
    case item04a
    case item04b
    case item04c
    case item04d
    case item04e
    case item05
    case item06
    case item07
    case item08
    case item08ScaleChangeRequest
    case item08DegradedPreview
    case item09
    case item10
    case item13
    case item14
    case item15
    case item16
    case item17
    case item18
}

// v13 第九节全部未定项只在此处声明，不提供产品默认值。
enum S2UndecidedItems {
    static let item01InitialPresentation = S2UndecidedPlaceholder.unresolved
    static let item02LastAssetMarkOutcome = S2UndecidedPlaceholder.unresolved
    static let item03SequenceBoundaryFeedback = S2UndecidedPlaceholder.unresolved
    static let item04aPinchMaxScale = S2UndecidedPlaceholder.unresolved
    static let item04bZoomSnapBackThreshold = S2UndecidedPlaceholder.unresolved
    static let item04cAspectFillDegeneration = S2UndecidedPlaceholder.unresolved
    static let item04dDoubleTapAnchorStrategy = S2UndecidedPlaceholder.unresolved
    static let item04eEdgePagingThresholds = S2UndecidedPlaceholder.unresolved
    static let item05GestureRecognition = S2UndecidedPlaceholder.unresolved
    static let item06BottomStripMetrics = S2UndecidedPlaceholder.unresolved
    static let item07CopyLayoutAndStyle = S2UndecidedPlaceholder.unresolved
    static let item08AssetLoadingAndRecovery = S2UndecidedPlaceholder.unresolved
    static let item08ScaleChangeRequestPolicy = S2UndecidedPlaceholder.unresolved
    static let item08DegradedPreviewPolicy = S2UndecidedPlaceholder.unresolved
    static let item09EmptyPendingPresentation = S2UndecidedPlaceholder.unresolved
    static let item10SnapshotPersistence = S2UndecidedPlaceholder.unresolved
    static let item13AlbumHistoryDepth = S2UndecidedPlaceholder.unresolved
    static let item14AlbumHistoryPersistence = S2UndecidedPlaceholder.unresolved
    static let item15InFlightControls = S2UndecidedPlaceholder.unresolved
    static let item16AlreadyContainedCopy = S2UndecidedPlaceholder.unresolved
    static let item17AlbumBadgePresentation = S2UndecidedPlaceholder.unresolved
    static let item18BottomStripMarkPresentation = S2UndecidedPlaceholder.unresolved
}

enum S2ScaleChangeImageRequestPolicy: String, CaseIterable, Codable, Equatable {
    case everyScaleChange
    case pinchEnded
}

enum S2DegradedPreviewPolicy: String, CaseIterable, Codable, Equatable {
    case display
    case finalImageOnly
}

struct S2ImageRequestStrategy: Codable, Equatable {
    let scaleChangePolicy: S2ScaleChangeImageRequestPolicy
    let degradedPreviewPolicy: S2DegradedPreviewPolicy
}

enum S2DoubleTapAnchorStrategy: String, CaseIterable, Codable, Equatable {
    case touchPoint
}

/// IC-085：横栏几何与运动参数（来源：系统 Photos 录屏逐帧测量，见 Reports/IC-085）。
/// `switchDistance` 是相邻项目中心的节距（= 邻居宽 + 间距）；`currentItemGap` 是静止态
/// 当前张与两侧邻居的间隙；`leadingInset` 与 `edgeFadeWidth` 描述两侧可见区起点与线性渐隐。
struct S2BottomStripMetrics: Equatable {
    let currentItemSize: CGFloat
    let neighborItemWidth: CGFloat
    let neighborItemHeight: CGFloat
    let itemSpacing: CGFloat
    let currentItemGap: CGFloat
    let edgeFadeWidth: CGFloat
    let leadingInset: CGFloat
    let switchDistance: CGFloat
    let decelerationRate: CGFloat
    let expandDurationMilliseconds: CGFloat
    let collapseDurationMilliseconds: CGFloat
    /// IC-085 R3：松手手指速度低于此值（pt/s）无减速段，直接吸附展开。
    let flickVelocityThreshold: CGFloat
    /// IC-090 R1：横栏项目圆角半径（pt）。系统录屏静止段测得邻居与当前张同值，
    /// 与项目尺寸无关，展开／收缩全程为常量。
    let cornerRadius: CGFloat

    var height: CGFloat {
        max(currentItemSize, neighborItemHeight)
    }

    var isValid: Bool {
        currentItemSize > 0 &&
            neighborItemWidth > 0 &&
            neighborItemHeight > 0 &&
            itemSpacing >= 0 &&
            currentItemGap >= 0 &&
            edgeFadeWidth >= 0 &&
            leadingInset >= 0 &&
            switchDistance > 0 &&
            decelerationRate > 0 &&
            decelerationRate < 1 &&
            expandDurationMilliseconds >= 0 &&
            collapseDurationMilliseconds >= 0 &&
            flickVelocityThreshold >= 0 &&
            cornerRadius >= 0
    }
}

/// IC-078：求 `pinchMaxScale` 所需的资产缩放几何——像素尺寸、`s > 1` 几何基准
/// （全视口 aspectFit）下的显示尺寸与屏幕倍率。
struct S2AssetZoomGeometry: Equatable {
    let assetPixelSize: CGSize
    let fitSize: CGSize
    let displayScale: CGFloat
}

// 此类型只承接未来决议的显式注入；本卡不提供任何默认实例。
struct S2ResolvedParameters: Equatable {
    let pinchMaxScaleFloor: CGFloat
    let pinchMaxScaleCeiling: CGFloat
    let pinchMaxScaleOneToOneMultiplier: CGFloat
    let zoomSnapBackThreshold: CGFloat
    let minDoubleTapScale: CGFloat
    let doubleTapAnchorStrategy: S2DoubleTapAnchorStrategy
    let edgePagingTriggerDistance: CGFloat
    let edgePagingTriggerVelocity: CGFloat
    let verticalSwipeDistance: CGFloat
    let verticalSwipeVelocity: CGFloat
    let bottomStripMetrics: S2BottomStripMetrics

    init?(
        pinchMaxScaleFloor: CGFloat,
        pinchMaxScaleCeiling: CGFloat,
        pinchMaxScaleOneToOneMultiplier: CGFloat = 2,
        zoomSnapBackThreshold: CGFloat,
        minDoubleTapScale: CGFloat,
        doubleTapAnchorStrategy: S2DoubleTapAnchorStrategy,
        edgePagingTriggerDistance: CGFloat,
        edgePagingTriggerVelocity: CGFloat,
        verticalSwipeDistance: CGFloat,
        verticalSwipeVelocity: CGFloat,
        bottomStripMetrics: S2BottomStripMetrics
    ) {
        guard pinchMaxScaleFloor > 1,
              pinchMaxScaleCeiling >= pinchMaxScaleFloor,
              pinchMaxScaleOneToOneMultiplier > 0,
              zoomSnapBackThreshold >= 1,
              zoomSnapBackThreshold <= pinchMaxScaleFloor,
              minDoubleTapScale > 1,
              edgePagingTriggerDistance >= 0,
              edgePagingTriggerVelocity >= 0,
              verticalSwipeDistance >= 0,
              verticalSwipeVelocity >= 0,
              bottomStripMetrics.isValid else {
            return nil
        }

        self.pinchMaxScaleFloor = pinchMaxScaleFloor
        self.pinchMaxScaleCeiling = pinchMaxScaleCeiling
        self.pinchMaxScaleOneToOneMultiplier = pinchMaxScaleOneToOneMultiplier
        self.zoomSnapBackThreshold = zoomSnapBackThreshold
        self.minDoubleTapScale = minDoubleTapScale
        self.doubleTapAnchorStrategy = doubleTapAnchorStrategy
        self.edgePagingTriggerDistance = edgePagingTriggerDistance
        self.edgePagingTriggerVelocity = edgePagingTriggerVelocity
        self.verticalSwipeDistance = verticalSwipeDistance
        self.verticalSwipeVelocity = verticalSwipeVelocity
        self.bottomStripMetrics = bottomStripMetrics
    }
}

enum S2LockedValues {
    static let verticalDirectionBoundaryAngleDegrees: CGFloat = 35
}

struct S2RangeDisplayInformation: Equatable {
    let rangeID: String
    let displayName: String
    let totalAssetCount: Int
}

struct S2EntryContext {
    let sessionID: String
    let rangeDisplayInformation: S2RangeDisplayInformation
    let orderedAssetIDs: [String]
    let currentAssetID: String
    let pendingDeletionAssetIDs: Set<String>

    private let sessionMergedPendingDeletionCountProvider: () -> Int

    var sessionMergedPendingDeletionCount: Int {
        sessionMergedPendingDeletionCountProvider()
    }

    init(
        sessionID: String,
        rangeDisplayInformation: S2RangeDisplayInformation,
        orderedAssetIDs: [String],
        currentAssetID: String,
        pendingDeletionAssetIDs: Set<String>,
        sessionMergedPendingDeletionCountProvider: @escaping () -> Int
    ) {
        self.sessionID = sessionID
        self.rangeDisplayInformation = rangeDisplayInformation
        self.orderedAssetIDs = orderedAssetIDs
        self.currentAssetID = currentAssetID
        self.pendingDeletionAssetIDs = pendingDeletionAssetIDs
        self.sessionMergedPendingDeletionCountProvider =
            sessionMergedPendingDeletionCountProvider
    }

    init(handoff: S1ToS2Handoff) {
        self.init(
            sessionID: handoff.sessionID,
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: handoff.rangeDisplayInformation.rangeID,
                displayName: handoff.rangeDisplayInformation.displayName,
                totalAssetCount: handoff.rangeDisplayInformation.totalAssetCount
            ),
            orderedAssetIDs: handoff.orderedAssetIDs,
            currentAssetID: handoff.currentAssetID,
            pendingDeletionAssetIDs: handoff.pendingDeletionAssetIDs,
            sessionMergedPendingDeletionCountProvider: {
                handoff.sessionMergedPendingDeletionCount
            }
        )
    }
}

struct S2InitialPresentation: Equatable {
    let interfaceVisibility: S2InterfaceVisibility
    let scale: CGFloat
    let viewportOffset: CGSize
}

struct S2ContinuationSnapshot: Equatable {
    let orderedAssetIDs: [String]
    let currentAssetID: String
    let pendingDeletionAssetIDs: Set<String>
    let rangeDisplayInformation: S2RangeDisplayInformation
}

struct S2ExitPayload: Equatable {
    let upstreamReturn: SessionStore.S2Return
    let continuationSnapshot: S2ContinuationSnapshot
}

struct S2AlbumReference: Identifiable, Hashable {
    let id: String
    let name: String
}

/// IC-114 C：相簿选择器的一行。列表要显示键图、名称与数量，
/// 但 `S2AlbumReference` 是持久化「最近相簿」用的最小模型，
/// 不宜为了列表展示往里塞字段——故另立一个只服务于列表的类型。
struct S2AlbumListItem: Identifiable, Equatable {
    let album: S2AlbumReference
    let assetCount: Int
    /// 键图资产标识；相簿为空时为 nil，此时列表行显示占位底。
    let keyAssetID: String?

    var id: String {
        album.id
    }
}

struct S2AssetActionRequest: Equatable {
    let targetAssetID: String
}

struct S2AlbumActionRequest: Equatable {
    let targetAssetID: String
    let album: S2AlbumReference
}

/// IC-113 B：最近一次**成功**加入相簿的记录。中央指示据此显示
/// 「已加入「名」」并提供撤回；`id` 单调递增，供视图识别「又发生了一次」
/// （同一资产重复加入同一相簿时，`assetID` 与 `album` 都不变）。
struct S2AlbumAdditionRecord: Equatable {
    let id: Int
    let assetID: String
    let album: S2AlbumReference
}

struct S2AlbumPickerRequest: Equatable {
    let targetAssetID: String
}

/// IC-076：相簿选择 sheet 中「选中 → 写入中 → 结果」三段的中间记录；
/// 结果必须作用于 `request.targetAssetID`（`x`）与选中时的相册。
struct S2AlbumPickerSelection: Equatable {
    let request: S2AlbumPickerRequest
    let album: S2AlbumReference
}

enum S2AlbumAdditionOutcome: Equatable {
    case success(alreadyContained: Bool)
    case failure
    case albumUnavailable
}

enum S2SemanticNotice: Equatable {
    case alreadyMarked(assetID: String)
}

/// IC-076（v15 第二节第 4 部分）：操作条三个按钮各自维护一个进行中标志。
enum S2ActionBarButton: CaseIterable, Equatable, Hashable {
    case favorite
    case recentAlbum
    case albumPicker
}

/// IC-076（v15 回写决策 29）：写入失败的一次性反馈事件，由视图层以底部短 toast 呈现。
/// 只有两种失败；成功不发事件。同一时刻只保留最新一条，新事件替换旧事件。
enum S2FeedbackEventKind: Equatable {
    case favoriteWriteFailed
    case albumAdditionFailed
    /// IC-114 C：新建相簿失败。沿用既有反馈通道，只多一个分支。
    case albumCreationFailed
}

struct S2FeedbackEvent: Equatable, Identifiable {
    let id: Int
    let kind: S2FeedbackEventKind
}

enum S2PageDirection: Equatable {
    case previous
    case next

    var indexOffset: Int {
        switch self {
        case .previous:
            return -1
        case .next:
            return 1
        }
    }
}

enum S2DragDirection: Equatable {
    case vertical
    case horizontal
}

enum S2TransitionEvent: CaseIterable, Equatable {
    case enterFromS1
    case singleTapMainImage
    case doubleTapMainImage
    case pinchMainImage
    case swipeUpMainImage
    case swipeDownMainImage
    case horizontalSwipeMainImage
    case dragMainImageWithoutPaging
    case beginBottomStripDrag
    case changeCurrentPhotoDuringBottomStripDrag
    case endBottomStripDrag
    case tapFavorite
    case tapRecentAlbum
    case tapAddAlbum
    case operateUnderlyingS2WhileSheetPresented
    case selectAlbumAndWriteSucceeds
    case selectAlbumAndWriteFails
    case cancelAlbumSheet
    case tapBack
    case tapConfirmation
    case systemEdgeSwipeBack
}

enum S2TransitionOrigin: Equatable {
    case pageOutside
    case state(S2State)
}

enum S2TransitionAvailability: Equatable {
    case available
    case conditional
    case ignored
    case unavailable
}

enum S2TransitionTarget: Equatable {
    case pageOutside
    case state(S2State)
    case sameState
    case dynamic
    case none
}

struct S2TransitionRule: Equatable {
    let availability: S2TransitionAvailability
    let target: S2TransitionTarget

    static let unavailable = S2TransitionRule(
        availability: .unavailable,
        target: .none
    )

    static func available(_ target: S2TransitionTarget) -> S2TransitionRule {
        S2TransitionRule(availability: .available, target: target)
    }

    static func conditional(_ target: S2TransitionTarget) -> S2TransitionRule {
        S2TransitionRule(availability: .conditional, target: target)
    }

    static func ignored(_ target: S2TransitionTarget) -> S2TransitionRule {
        S2TransitionRule(availability: .ignored, target: target)
    }
}

enum S2GestureInput: CaseIterable, Equatable {
    case singleTapMainImage
    case doubleTapMainImage
    case pinchMainImage
    case swipeUpMainImage
    case swipeDownMainImage
    case horizontalSwipeMainImage
    case dragMainImage
    case dragBottomStrip
    case tapUnderlyingControl
    case tapSheetControl
    case systemEdgeSwipe
    case undefinedMainImageGesture
}

enum S2GestureContext: CaseIterable, Equatable {
    case oneX
    case nX
    case albumSheetPresented
}

enum S2GestureAvailability: Equatable {
    case available
    case conditional
    case ignored
    case blocked
    case unavailable
}

enum S2GestureEffect: Equatable {
    case toggleInterface
    /// IC-104 B（第 132 条）：只迁 `V=显示`，不像单击那样双向切换。
    case revealInterface
    case toggleZoom
    case continuousPinch
    case markCurrent
    case unmarkCurrent
    case switchPhoto
    case routeOneXDrag
    case panOnly
    case panOrEdgePaging
    case dragBottomStripWhenVisible
    case useVisibleControl
    case sheetControl
    case systemBackDisabled
    case none
}

struct S2GestureRule: Equatable {
    let availability: S2GestureAvailability
    let effect: S2GestureEffect
}

enum S2Geometry {
    // 函数来源：IC-20260812-007-s2-gesture-calibration；仅把模型读取改为显式参数。
    static func aspectFitSize(
        viewportSize: CGSize,
        assetAspectRatio ratio: CGFloat
    ) -> CGSize {
        guard viewportSize.height > 0, viewportSize.width > 0 else {
            return .zero
        }
        if viewportSize.width / viewportSize.height > ratio {
            return CGSize(width: viewportSize.height * ratio, height: viewportSize.height)
        }
        return CGSize(width: viewportSize.width, height: viewportSize.width / ratio)
    }

    // 函数来源：IC-20260812-022-demo-aspect-fill-zoom；公式保持原实现。
    static func aspectFillMultiplier(
        viewportSize: CGSize,
        assetAspectRatio: CGFloat
    ) -> CGFloat? {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              assetAspectRatio > 0 else {
            return nil
        }

        let viewportAspectRatio = viewportSize.width / viewportSize.height
        let calculatedMultiplier = max(
            viewportAspectRatio / assetAspectRatio,
            assetAspectRatio / viewportAspectRatio
        )
        return calculatedMultiplier
    }

    // IC-056 的方向归一屏幕比例判定；所有双击与内缩路径共用同一容差。
    static func isScreenAspectMatch(
        assetAspectRatio: CGFloat,
        viewportAspectRatio: CGFloat
    ) -> Bool {
        guard assetAspectRatio > 0, viewportAspectRatio > 0 else {
            return false
        }
        let normalizedAssetRatio = min(
            assetAspectRatio,
            1 / assetAspectRatio
        )
        let normalizedViewportRatio = min(
            viewportAspectRatio,
            1 / viewportAspectRatio
        )
        return abs(normalizedAssetRatio - normalizedViewportRatio) /
            normalizedViewportRatio <= 0.01
    }

    // IC-056 仅保留触点锚定：缩放前后的触点对应同一照片位置。
    static func doubleTapAnchorOffset(
        strategy: S2DoubleTapAnchorStrategy,
        location: CGPoint,
        viewportSize: CGSize,
        zoomScale: CGFloat
    ) -> CGSize {
        let center = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height / 2
        )
        switch strategy {
        case .touchPoint:
            let scaleDelta = zoomScale - 1
            return CGSize(
                width: (center.x - location.x) * scaleDelta,
                height: (center.y - location.y) * scaleDelta
            )
        }
    }

    // 函数来源：IC-20260812-007；v13 将余量锁为零，因此签名不保留余量参数。
    static func panLimits(
        viewportSize: CGSize,
        fittedSize: CGSize,
        zoomScale: CGFloat
    ) -> CGSize {
        guard zoomScale > 1 else {
            return .zero
        }
        return CGSize(
            width: max(0, (fittedSize.width * zoomScale - viewportSize.width) / 2),
            height: max(0, (fittedSize.height * zoomScale - viewportSize.height) / 2)
        )
    }

    // 函数来源：IC-20260812-007-s2-gesture-calibration；逐轴钳制公式保持原实现。
    static func clampedOffset(
        _ offset: CGSize,
        viewportSize: CGSize,
        fittedSize: CGSize,
        zoomScale: CGFloat
    ) -> CGSize {
        let limits = panLimits(
            viewportSize: viewportSize,
            fittedSize: fittedSize,
            zoomScale: zoomScale
        )
        return CGSize(
            width: min(max(offset.width, -limits.width), limits.width),
            height: min(max(offset.height, -limits.height), limits.height)
        )
    }
}

final class S2StateMachine: ObservableObject {
    let entry: S2EntryContext
    @Published private(set) var parameters: S2ResolvedParameters
    /// IC-078：按资产登记的缩放几何；非发布属性，登记不触发视图刷新。
    private var assetZoomGeometries: [String: S2AssetZoomGeometry] = [:]
    @Published private(set) var imageRequestStrategy: S2ImageRequestStrategy?

    @Published private(set) var interfaceVisibility: S2InterfaceVisibility
    @Published private(set) var scale: CGFloat

    /// IC-114 D（⑤a ④）：放大前的 `V`。`s` 由 1 进入 >1 时记下，
    /// 回到 1 时据此恢复；不在放大中时为 nil。
    private var visibilityBeforeZoom: S2InterfaceVisibility?
    @Published private(set) var viewportOffset: CGSize
    @Published private(set) var bottomStripState: S2BottomStripState = .idle
    @Published private(set) var sheetState: S2SheetState = .closed
    @Published private(set) var touchSequenceOwner: S2TouchSequenceOwner = .none
    @Published private(set) var currentIndex: Int
    @Published private(set) var farthestIndex: Int
    @Published private(set) var pendingDeletionAssetIDs: Set<String>
    @Published private(set) var favoriteAssetIDs: Set<String>
    @Published private(set) var recentAlbum: S2AlbumReference?
    @Published private(set) var semanticNotice: S2SemanticNotice?
    @Published private(set) var pendingUndecidedItem: S2UndecidedItem?
    /// IC-076：进行中的操作条写入。某按钮进行中时只禁用该按钮，其余照常。
    @Published private(set) var inFlightActions: Set<S2ActionBarButton> = []
    /// IC-076：最新一条写入失败反馈事件；新事件替换旧事件，成功不发事件。
    @Published private(set) var feedbackEvent: S2FeedbackEvent?
    private(set) var feedbackEventCount = 0
    @Published private(set) var imageRequestRevision = 0
    @Published private(set) var imageRequestAssetID: String?
    @Published private(set) var lastGestureReading: S2GestureReading?
    @Published private(set) var lastTapDecisionReading: S2TapDecisionReading?
    @Published private(set) var lastImageRequestReading: S2ImageRequestReading?
    @Published private(set) var assetNavigationResult: S2AssetNavigationResult?
    private(set) var imageRequestScale: CGFloat

    private let pendingDeletionDidChange: (Set<String>) -> Void
    private let recentAlbumDidChange: (S2AlbumReference?) -> Void
    private var pinchStartScale: CGFloat?
    private var albumPickerTargetAssetID: String?
    private var inFlightFavoriteRequest: S2AssetActionRequest?
    private var inFlightRecentAlbumRequest: S2AlbumActionRequest?
    private var inFlightAlbumPickerSelection: S2AlbumPickerSelection?

    /// IC-113 B：最近一次成功加入相簿。撤回成功后清空。
    @Published private(set) var lastAlbumAddition: S2AlbumAdditionRecord?
    private var albumAdditionCount = 0
    /// 撤回（从相簿移除）是否在途。**不进 `inFlightActions`**——
    /// 那个集合驱动操作条三按钮的启用规则，撤回钮不在其列，
    /// 混进去会连带改变操作条语义（G284 要求手势与操作条语义不变）。
    private(set) var isAlbumRemovalInFlight = false

    init?(
        entry: S2EntryContext,
        initialPresentation: S2InitialPresentation,
        parameters: S2ResolvedParameters,
        imageRequestStrategy: S2ImageRequestStrategy?,
        initialFavoriteAssetIDs: Set<String>,
        initialRecentAlbum: S2AlbumReference?,
        pendingDeletionDidChange: @escaping (Set<String>) -> Void,
        recentAlbumDidChange: @escaping (S2AlbumReference?) -> Void = { _ in }
    ) {
        let assetIDSet = Set(entry.orderedAssetIDs)
        guard !entry.sessionID.isEmpty,
              !entry.rangeDisplayInformation.rangeID.isEmpty,
              !entry.rangeDisplayInformation.displayName.isEmpty,
              entry.rangeDisplayInformation.totalAssetCount ==
                entry.orderedAssetIDs.count,
              !entry.orderedAssetIDs.isEmpty,
              assetIDSet.count == entry.orderedAssetIDs.count,
              !assetIDSet.contains(String()),
              assetIDSet.contains(entry.currentAssetID),
              entry.pendingDeletionAssetIDs.isSubset(of: assetIDSet),
              initialFavoriteAssetIDs.isSubset(of: assetIDSet),
              entry.sessionMergedPendingDeletionCount >= 0,
              initialPresentation.scale >= 1,
              initialPresentation.scale <= parameters.pinchMaxScaleFloor else {
            return nil
        }

        self.entry = entry
        self.parameters = parameters
        self.imageRequestStrategy = imageRequestStrategy
        interfaceVisibility = initialPresentation.interfaceVisibility
        scale = initialPresentation.scale
        imageRequestScale = initialPresentation.scale
        viewportOffset = initialPresentation.scale == 1
            ? .zero
            : initialPresentation.viewportOffset
        let initialCurrentIndex = entry.orderedAssetIDs.firstIndex(
            of: entry.currentAssetID
        ) ?? 0
        currentIndex = initialCurrentIndex
        farthestIndex = initialCurrentIndex
        pendingDeletionAssetIDs = entry.pendingDeletionAssetIDs
        favoriteAssetIDs = initialFavoriteAssetIDs
        recentAlbum = initialRecentAlbum
        self.pendingDeletionDidChange = pendingDeletionDidChange
        self.recentAlbumDidChange = recentAlbumDidChange
    }

    var orderedAssetIDs: [String] {
        entry.orderedAssetIDs
    }

    var currentAssetID: String {
        orderedAssetIDs[currentIndex]
    }

    var farthestAssetID: String {
        orderedAssetIDs[farthestIndex]
    }

    var currentIsMarked: Bool {
        pendingDeletionAssetIDs.contains(currentAssetID)
    }

    var currentIsFavorite: Bool {
        favoriteAssetIDs.contains(currentAssetID)
    }

    var sessionMergedPendingDeletionCount: Int {
        entry.sessionMergedPendingDeletionCount
    }

    /// IC-075（v15 回写决策 29）：会话合并待删总数为 0 时确认页入口禁用、徽标不显示。
    /// 只读派生量，视图只读它；`makeExitPayload` 不受影响。
    var canEnterConfirmation: Bool {
        sessionMergedPendingDeletionCount > 0
    }

    var zoomState: S2ZoomState {
        scale == 1 ? .oneX : .nX
    }

    var state: S2State {
        switch (interfaceVisibility, zoomState, bottomStripState) {
        case (.visible, .oneX, .idle):
            return .visibleOneXIdle
        case (.visible, .oneX, .dragging):
            return .visibleOneXStripDragging
        case (.hidden, .oneX, _):
            return .hiddenOneX
        case (.visible, .nX, .idle):
            return .visibleNxIdle
        case (.visible, .nX, .dragging):
            return .visibleNxStripDragging
        case (.hidden, .nX, _):
            return .hiddenNx
        }
    }

    var gestureContext: S2GestureContext {
        if sheetState == .presented {
            return .albumSheetPresented
        }
        return zoomState == .oneX ? .oneX : .nX
    }

    var albumPickerRequest: S2AlbumPickerRequest? {
        guard sheetState == .presented,
              let albumPickerTargetAssetID else {
            return nil
        }
        return S2AlbumPickerRequest(targetAssetID: albumPickerTargetAssetID)
    }

    static func transitionRule(
        for event: S2TransitionEvent,
        from origin: S2TransitionOrigin
    ) -> S2TransitionRule {
        switch event {
        case .enterFromS1:
            return origin == .pageOutside
                ? .conditional(.dynamic)
                : .unavailable

        case .singleTapMainImage:
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXIdle):
                return .available(.state(.hiddenOneX))
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            case .state(.hiddenOneX):
                return .available(.state(.visibleOneXIdle))
            case .state(.visibleNxIdle):
                return .available(.state(.hiddenNx))
            case .state(.hiddenNx):
                return .available(.state(.visibleNxIdle))
            }

        case .doubleTapMainImage:
            // IC-115（⑤a ④）：进入放大自动隐藏，退出恢复**进入前**的 V。
            // 进入两行是确定的（无论从显示还是隐藏进入，落点都是隐藏 Nx）；
            // 退出两行的落点取决于记录值，**不是原状态的函数**，
            // 故与捏合行同样标 `conditional(.dynamic)`。
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXIdle):
                return .available(.state(.hiddenNx))
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            case .state(.hiddenOneX):
                return .available(.state(.hiddenNx))
            case .state(.visibleNxIdle), .state(.hiddenNx):
                return .conditional(.dynamic)
            }

        case .pinchMainImage:
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            case .state(_):
                return .conditional(.dynamic)
            }

        case .swipeUpMainImage:
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            case .state(.visibleOneXIdle):
                return .conditional(.sameState)
            // IC-104 B（第 132 条）：V=隐藏 且 1x，上滑完全无效果——
            // 不标记、不改 D、不翻页、不发提示。
            case .state(.hiddenOneX):
                return .ignored(.sameState)
            case .state(.visibleNxIdle), .state(.hiddenNx):
                return .conditional(.dynamic)
            }

        case .swipeDownMainImage:
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            // IC-104 B（第 132 条）：V=隐藏 且 1x，下滑迁 V=显示，与单击同形。
            case .state(.hiddenOneX):
                return .available(.state(.visibleOneXIdle))
            case .state(.visibleOneXIdle),
                 .state(.visibleNxIdle),
                 .state(.hiddenNx):
                return .conditional(.sameState)
            }

        case .horizontalSwipeMainImage:
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            case .state(.visibleOneXIdle), .state(.hiddenOneX):
                return .conditional(.sameState)
            case .state(.visibleNxIdle), .state(.hiddenNx):
                return .conditional(.dynamic)
            }

        case .dragMainImageWithoutPaging:
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            case .state(_):
                return .available(.sameState)
            }

        case .beginBottomStripDrag:
            switch origin {
            case .state(.visibleOneXIdle):
                return .available(.state(.visibleOneXStripDragging))
            case .state(.visibleNxIdle):
                return .available(.state(.visibleNxStripDragging))
            default:
                return .unavailable
            }

        case .changeCurrentPhotoDuringBottomStripDrag:
            switch origin {
            case .state(.visibleOneXStripDragging):
                return .available(.sameState)
            case .state(.visibleNxStripDragging):
                return .available(.state(.visibleOneXStripDragging))
            default:
                return .unavailable
            }

        case .endBottomStripDrag:
            switch origin {
            case .state(.visibleOneXStripDragging):
                return .available(.state(.visibleOneXIdle))
            case .state(.visibleNxStripDragging):
                return .available(.state(.visibleNxIdle))
            default:
                return .unavailable
            }

        case .tapFavorite, .tapRecentAlbum:
            switch origin {
            case .state(.visibleOneXIdle), .state(.visibleNxIdle):
                return .conditional(.sameState)
            default:
                return .unavailable
            }

        case .tapAddAlbum:
            switch origin {
            case .state(.visibleOneXIdle), .state(.visibleNxIdle):
                return .available(.sameState)
            default:
                return .unavailable
            }

        case .operateUnderlyingS2WhileSheetPresented,
             .selectAlbumAndWriteSucceeds,
             .selectAlbumAndWriteFails,
             .cancelAlbumSheet:
            switch origin {
            case .state(.visibleOneXIdle), .state(.visibleNxIdle):
                return .conditional(.sameState)
            default:
                return .unavailable
            }

        case .tapBack:
            switch origin {
            case .state(.visibleOneXIdle), .state(.visibleNxIdle):
                return .available(.pageOutside)
            default:
                return .unavailable
            }

        case .tapConfirmation:
            switch origin {
            case .state(.visibleOneXIdle), .state(.visibleNxIdle):
                return .conditional(.pageOutside)
            default:
                return .unavailable
            }

        case .systemEdgeSwipeBack:
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(_):
                return .ignored(.sameState)
            }
        }
    }

    /// 手势矩阵。`visibility` 是 IC-104 B（第 132 条）引入的界面可见性维度：
    /// 只有 1x 的上滑 / 下滑两格随 `V` 分叉，其余格在两个 `V` 上取值相同，
    /// 故形参取默认值 `.visible`，既有调用点语义不变。
    static func gestureRule(
        for input: S2GestureInput,
        context: S2GestureContext,
        visibility: S2InterfaceVisibility = .visible
    ) -> S2GestureRule {
        if context == .albumSheetPresented {
            if input == .tapSheetControl {
                return S2GestureRule(
                    availability: .available,
                    effect: .sheetControl
                )
            }
            return S2GestureRule(availability: .blocked, effect: .none)
        }

        switch input {
        case .singleTapMainImage:
            return S2GestureRule(
                availability: .available,
                effect: .toggleInterface
            )

        case .doubleTapMainImage:
            return S2GestureRule(
                availability: .available,
                effect: .toggleZoom
            )

        case .pinchMainImage:
            return S2GestureRule(
                availability: .available,
                effect: .continuousPinch
            )

        case .swipeUpMainImage:
            // IC-104 B（第 132 条）：V=隐藏 且 1x 完全无效果；Nx 分层不变。
            if context == .oneX, visibility == .hidden {
                return S2GestureRule(availability: .ignored, effect: .none)
            }
            return S2GestureRule(
                availability: .available,
                effect: .markCurrent
            )

        case .swipeDownMainImage:
            guard context == .oneX else {
                return S2GestureRule(
                    availability: .conditional,
                    effect: .panOnly
                )
            }
            // IC-104 B（第 132 条）：V=隐藏 且 1x 下滑迁 V=显示。
            if visibility == .hidden {
                return S2GestureRule(
                    availability: .available,
                    effect: .revealInterface
                )
            }
            return S2GestureRule(
                availability: .available,
                effect: .unmarkCurrent
            )

        case .horizontalSwipeMainImage:
            return context == .oneX
                ? S2GestureRule(
                    availability: .available,
                    effect: .switchPhoto
                )
                : S2GestureRule(
                    availability: .conditional,
                    effect: .panOrEdgePaging
                )

        case .dragMainImage:
            return context == .oneX
                ? S2GestureRule(
                    availability: .conditional,
                    effect: .routeOneXDrag
                )
                : S2GestureRule(
                    availability: .available,
                    effect: .panOrEdgePaging
                )

        case .dragBottomStrip:
            return S2GestureRule(
                availability: .conditional,
                effect: .dragBottomStripWhenVisible
            )

        case .tapUnderlyingControl:
            return S2GestureRule(
                availability: .conditional,
                effect: .useVisibleControl
            )

        case .tapSheetControl:
            return S2GestureRule(
                availability: .unavailable,
                effect: .none
            )

        case .systemEdgeSwipe:
            return S2GestureRule(
                availability: .blocked,
                effect: .systemBackDisabled
            )

        case .undefinedMainImageGesture:
            return S2GestureRule(availability: .ignored, effect: .none)
        }
    }

    @discardableResult
    func handleSingleTap() -> Bool {
        guard receivesUnobscuredInput else {
            return false
        }
        interfaceVisibility = interfaceVisibility == .visible
            ? .hidden
            : .visible
        return true
    }

    func recordTapDecisionReading(_ reading: S2TapDecisionReading) {
        lastTapDecisionReading = reading
    }

    @discardableResult
    func handleDoubleTap(
        at location: CGPoint,
        viewportSize: CGSize,
        assetAspectRatio: CGFloat,
        oneXDisplaySize: CGSize? = nil
    ) -> Bool {
        guard receivesUnobscuredInput else {
            return false
        }

        if zoomState == .nX {
            setScale(1)
            imageRequestScale = 1
            viewportOffset = .zero
            requestImageAfterScaleSettled()
            return true
        }

        guard let calculatedMultiplier = S2Geometry.aspectFillMultiplier(
            viewportSize: viewportSize,
            assetAspectRatio: assetAspectRatio
        ) else {
            return false
        }
        let viewportAspectRatio = viewportSize.width / viewportSize.height
        let nextScale = S2Geometry.isScreenAspectMatch(
            assetAspectRatio: assetAspectRatio,
            viewportAspectRatio: viewportAspectRatio
        )
            ? parameters.minDoubleTapScale
            : calculatedMultiplier
        guard nextScale > 1 else {
            return false
        }

        setScale(nextScale)
        imageRequestScale = nextScale
        let fittedSize = oneXDisplaySize ?? S2Geometry.aspectFitSize(
            viewportSize: viewportSize,
            assetAspectRatio: assetAspectRatio
        )
        viewportOffset = S2Geometry.clampedOffset(
            S2Geometry.doubleTapAnchorOffset(
                strategy: parameters.doubleTapAnchorStrategy,
                location: location,
                viewportSize: viewportSize,
                zoomScale: scale
            ),
            viewportSize: viewportSize,
            fittedSize: fittedSize,
            zoomScale: scale
        )
        requestImageAfterScaleSettled()
        return true
    }

    // 原生容器只向状态机上报结果；触点锚定与边界钳制由 UIScrollView 完成。
    @discardableResult
    func handleNativeDoubleTap(
        targetScale: CGFloat
    ) -> Bool {
        guard receivesUnobscuredInput else {
            return false
        }

        if zoomState == .nX {
            setScale(1)
            imageRequestScale = 1
            viewportOffset = .zero
            requestImageAfterScaleSettled()
            return true
        }

        guard targetScale.isFinite, targetScale > 1 else {
            return false
        }
        let resolvedScale = min(pinchMaxScale(for: currentAssetID), targetScale)
        guard resolvedScale > 1 else {
            return false
        }
        setScale(resolvedScale)
        imageRequestScale = resolvedScale
        viewportOffset = .zero
        requestImageAfterScaleSettled()
        return true
    }

    /// IC-077（v15 回写决策 28）：双击到达目标倍率（进入或退出 Nx）时请求一次。
    /// 与捏合结束共用同一信号（`imageRequestRevision`），视图层按 `pinchEnded` 触发器处理；
    /// `everyScaleChange` 策略下由倍率变化本身触发请求，此处不再重复递增。
    private func requestImageAfterScaleSettled() {
        guard imageRequestStrategy?.scaleChangePolicy == .pinchEnded else {
            return
        }
        imageRequestAssetID = currentAssetID
        imageRequestRevision += 1
    }

    func reportNativeViewport(
        scale: CGFloat,
        viewportOffset: CGSize
    ) {
        guard scale.isFinite,
              viewportOffset.width.isFinite,
              viewportOffset.height.isFinite else {
            return
        }
        // IC-095 R4：等值不发布。钳制后的取值与既有实现逐字相同，只是相同的值不再
        // 重新赋值一次 @Published——发布出去的值序列与时序不变，非几何订阅者
        // （徽标、横栏、工作表）读到的状态完全一致；断掉的只是「内层每帧回报同一
        //  视口 → SwiftUI 重进 → apply → 几何写入 → 布局回调 → 再次回报」的自激环。
        let nextScale = min(pinchMaxScale(for: currentAssetID), max(1, scale))
        let nextViewportOffset = nextScale == 1 ? .zero : viewportOffset
        if self.scale != nextScale {
            // IC-118 A：真机捏合的 `s` 走这里（scrollViewDidZoom 逐帧回报），
            // 此前直写绕过了 `setScale`，⑤a 自动隐藏因此在捏合入口失效。
            // 改道后仅当捏合在途才应用显隐规则：捏合结束后的回弹动画帧同样
            // 经此回报，若也应用规则会在恢复 V 后又瞬时重隐藏一次（闪烁）。
            setScale(
                nextScale,
                appliesZoomVisibilityRule: touchSequenceOwner == .pinch
            )
        }
        if self.viewportOffset != nextViewportOffset {
            self.viewportOffset = nextViewportOffset
        }
    }

    @discardableResult
    func finishNativePinch(
        scale: CGFloat,
        viewportOffset: CGSize,
        accepted: Bool
    ) -> CGFloat? {
        guard touchSequenceOwner == .pinch,
              let pinchStartScale else {
            return nil
        }

        reportNativeViewport(
            scale: accepted ? scale : pinchStartScale,
            viewportOffset: viewportOffset
        )
        if self.scale < parameters.zoomSnapBackThreshold {
            // IC-118 A：改道 `setScale`——回 1 时恢复进入前 V（此刻捏合仍在途）。
            setScale(1)
            self.viewportOffset = .zero
        }
        imageRequestScale = self.scale
        self.pinchStartScale = nil
        touchSequenceOwner = .none
        if imageRequestStrategy?.scaleChangePolicy == .pinchEnded {
            imageRequestAssetID = currentAssetID
            imageRequestRevision += 1
        }
        return self.scale
    }

    @discardableResult
    func handleNativePageChange(to index: Int) -> Bool {
        guard receivesUnobscuredInput,
              orderedAssetIDs.indices.contains(index),
              index != currentIndex else {
            return false
        }
        currentIndex = index
        farthestIndex = max(farthestIndex, index)
        resetZoomAfterPhotoChange()
        return true
    }

    @discardableResult
    func beginPinch() -> Bool {
        guard receivesUnobscuredInput else {
            return false
        }
        pinchStartScale = scale
        touchSequenceOwner = .pinch
        return true
    }

    @discardableResult
    func updatePinch(
        magnification: CGFloat,
        viewportSize: CGSize,
        fittedSize: CGSize
    ) -> Bool {
        guard touchSequenceOwner == .pinch,
              let pinchStartScale,
              magnification.isFinite,
              magnification > 0 else {
            return false
        }
        setScale(
            min(
                pinchMaxScale(for: currentAssetID),
                max(1, pinchStartScale * magnification)
            )
        )
        if scale == 1 {
            viewportOffset = .zero
        } else {
            viewportOffset = S2Geometry.clampedOffset(
                viewportOffset,
                viewportSize: viewportSize,
                fittedSize: fittedSize,
                zoomScale: scale
            )
        }
        return true
    }

    @discardableResult
    func endPinch(
        viewportSize: CGSize,
        fittedSize: CGSize
    ) -> Bool {
        guard touchSequenceOwner == .pinch else {
            return false
        }
        if scale < parameters.zoomSnapBackThreshold {
            setScale(1)
            viewportOffset = .zero
        } else {
            viewportOffset = S2Geometry.clampedOffset(
                viewportOffset,
                viewportSize: viewportSize,
                fittedSize: fittedSize,
                zoomScale: scale
            )
        }
        pinchStartScale = nil
        touchSequenceOwner = .none
        imageRequestScale = scale
        if imageRequestStrategy?.scaleChangePolicy == .pinchEnded {
            imageRequestAssetID = currentAssetID
            imageRequestRevision += 1
        }
        return true
    }

    @discardableResult
    func cancelPinch(
        viewportSize: CGSize,
        fittedSize: CGSize
    ) -> Bool {
        guard touchSequenceOwner == .pinch,
              let pinchStartScale else {
            return false
        }
        setScale(pinchStartScale)
        viewportOffset = S2Geometry.clampedOffset(
            viewportOffset,
            viewportSize: viewportSize,
            fittedSize: fittedSize,
            zoomScale: scale
        )
        self.pinchStartScale = nil
        touchSequenceOwner = .none
        imageRequestScale = scale
        if imageRequestStrategy?.scaleChangePolicy == .pinchEnded {
            imageRequestAssetID = currentAssetID
            imageRequestRevision += 1
        }
        return true
    }

    @discardableResult
    func handleSwipeUp() -> Bool {
        guard receivesUnobscuredInput else {
            return false
        }
        // IC-104 B（第 132 条）：V=隐藏 且 1x，上滑完全无效果——不标记、不改 D、
        // 不翻页、不发提示。必须置于下面的 `.alreadyMarked` 语义提示之前，
        // 否则隐藏态仍会发出提示，与「无提示」相悖。
        if interfaceVisibility == .hidden, zoomState == .oneX {
            return false
        }
        let assetID = currentAssetID
        guard !pendingDeletionAssetIDs.contains(assetID) else {
            // v15：已标记再上滑只触发主图标记脉冲（由视图消费），不弹文字。
            semanticNotice = .alreadyMarked(assetID: assetID)
            return false
        }

        var nextPending = pendingDeletionAssetIDs
        nextPending.insert(assetID)
        replacePendingDeletionAssetIDs(with: nextPending)
        if !switchPhoto(by: 1) {
            pendingUndecidedItem = .item02
        }
        return true
    }

    @discardableResult
    func handleSwipeDown() -> Bool {
        guard receivesUnobscuredInput,
              zoomState == .oneX else {
            return false
        }
        // IC-104 B（第 132 条）：V=隐藏 且 1x，下滑迁 V=显示；缩放、页索引、
        // `D`、徽标一律不变，与是否已标记无关，故置于 `D` 判断之前。
        // 过渡复用单击显隐切换的同款：视图层由 published `interfaceVisibility`
        // 变化驱动 `startPresentationTransition`，本处不新增任何可调参数。
        if interfaceVisibility == .hidden {
            interfaceVisibility = .visible
            return true
        }
        guard pendingDeletionAssetIDs.contains(currentAssetID) else {
            return false
        }
        var nextPending = pendingDeletionAssetIDs
        nextPending.remove(currentAssetID)
        replacePendingDeletionAssetIDs(with: nextPending)
        return true
    }

    @discardableResult
    func handleHorizontalSwipe(
        direction: S2PageDirection,
        startedAtPagingEdge: Bool,
        distance: CGFloat,
        velocity: CGFloat
    ) -> Bool {
        guard receivesUnobscuredInput else {
            return false
        }
        if zoomState == .nX {
            guard startedAtPagingEdge,
                  distance >= parameters.edgePagingTriggerDistance,
                  velocity >= parameters.edgePagingTriggerVelocity else {
                return false
            }
        }
        return switchPhoto(by: direction.indexOffset)
    }

    @discardableResult
    func updateMainPan(
        from startOffset: CGSize,
        translation: CGSize,
        viewportSize: CGSize,
        fittedSize: CGSize
    ) -> Bool {
        guard receivesUnobscuredInput, zoomState == .nX else {
            return false
        }
        let proposed = CGSize(
            width: startOffset.width + translation.width,
            height: startOffset.height + translation.height
        )
        viewportOffset = S2Geometry.clampedOffset(
            proposed,
            viewportSize: viewportSize,
            fittedSize: fittedSize,
            zoomScale: scale
        )
        return true
    }

    @discardableResult
    func completeMainDrag(
        translation: CGSize,
        duration: TimeInterval,
        startedOffset: CGSize,
        viewportSize: CGSize,
        fittedSize: CGSize
    ) -> Bool {
        guard receivesUnobscuredInput else {
            return false
        }

        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        let horizontalVelocity = duration > 0
            ? horizontalDistance / CGFloat(duration)
            : CGFloat.infinity
        let verticalVelocity = duration > 0
            ? verticalDistance / CGFloat(duration)
            : CGFloat.infinity
        let direction = Self.dragDirection(for: translation)

        if direction == .vertical,
           verticalDistance >= parameters.verticalSwipeDistance,
           verticalVelocity >= parameters.verticalSwipeVelocity {
            if translation.height < 0 {
                return handleSwipeUp()
            }
            return zoomState == .oneX
                ? handleSwipeDown()
                : false
        }

        if zoomState == .nX {
            guard direction == .horizontal else {
                return false
            }
            let limits = S2Geometry.panLimits(
                viewportSize: viewportSize,
                fittedSize: fittedSize,
                zoomScale: scale
            )
            let pageDirection: S2PageDirection
            let startedAtEdge: Bool
            if translation.width < 0 {
                pageDirection = .next
                startedAtEdge = startedOffset.width <= -limits.width
            } else {
                pageDirection = .previous
                startedAtEdge = startedOffset.width >= limits.width
            }
            return handleHorizontalSwipe(
                direction: pageDirection,
                startedAtPagingEdge: startedAtEdge,
                distance: horizontalDistance,
                velocity: horizontalVelocity
            )
        }

        // IC-074：1x 下以横向结束的主图拖动不再由状态机切页。
        // v15 规定 1x 左右滑只由外层原生分页承担；此处返回 false 是本卡
        // 唯一有意的行为变化（Decision_log 第 122 条）。
        return false
    }

    static func dragDirection(for translation: CGSize) -> S2DragDirection {
        let angleFromVertical = atan2(
            abs(translation.width),
            abs(translation.height)
        ) * 180 / .pi
        return angleFromVertical <=
            S2LockedValues.verticalDirectionBoundaryAngleDegrees
            ? .vertical
            : .horizontal
    }

    @discardableResult
    func beginBottomStripDrag() -> Bool {
        guard receivesUnobscuredInput, interfaceVisibility == .visible else {
            return false
        }
        bottomStripState = .dragging
        touchSequenceOwner = .bottomStrip
        return true
    }

    @discardableResult
    func changeCurrentPhotoDuringBottomStripDrag(by offset: Int) -> Bool {
        guard touchSequenceOwner == .bottomStrip,
              bottomStripState == .dragging else {
            return false
        }
        return switchPhoto(by: offset)
    }

    @discardableResult
    func endBottomStripDrag() -> Bool {
        guard touchSequenceOwner == .bottomStrip,
              bottomStripState == .dragging else {
            return false
        }
        bottomStripState = .idle
        touchSequenceOwner = .none
        return true
    }

    // MARK: - 操作条（IC-076）

    func isActionInFlight(_ button: S2ActionBarButton) -> Bool {
        inFlightActions.contains(button)
    }

    /// 相簿选择 sheet 当前进行中的选择；sheet 关闭或无写入时为 nil。
    var albumPickerSelectionInFlight: S2AlbumPickerSelection? {
        inFlightAlbumPickerSelection
    }

    func makeFavoriteToggleRequest() -> S2AssetActionRequest? {
        guard controlsCanReceiveInput,
              !isActionInFlight(.favorite) else {
            return nil
        }
        return S2AssetActionRequest(targetAssetID: currentAssetID)
    }

    /// 点击时把请求登记为进行中：`x` 已在 `request` 中绑定，此后翻页不改变目标。
    @discardableResult
    func beginFavoriteToggle(_ request: S2AssetActionRequest) -> Bool {
        guard !isActionInFlight(.favorite),
              orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }
        inFlightFavoriteRequest = request
        inFlightActions.insert(.favorite)
        return true
    }

    @discardableResult
    func completeFavoriteToggle(
        _ request: S2AssetActionRequest,
        succeeded: Bool
    ) -> Bool {
        if inFlightFavoriteRequest == request {
            inFlightFavoriteRequest = nil
            inFlightActions.remove(.favorite)
        }
        guard orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }
        guard succeeded else {
            publishFeedback(.favoriteWriteFailed)
            return false
        }
        if favoriteAssetIDs.contains(request.targetAssetID) {
            favoriteAssetIDs.remove(request.targetAssetID)
        } else {
            favoriteAssetIDs.insert(request.targetAssetID)
        }
        return true
    }

    func makeRecentAlbumAdditionRequest() -> S2AlbumActionRequest? {
        guard controlsCanReceiveInput,
              !isActionInFlight(.recentAlbum),
              let recentAlbum else {
            return nil
        }
        return S2AlbumActionRequest(
            targetAssetID: currentAssetID,
            album: recentAlbum
        )
    }

    @discardableResult
    func beginRecentAlbumAddition(_ request: S2AlbumActionRequest) -> Bool {
        guard !isActionInFlight(.recentAlbum),
              orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }
        inFlightRecentAlbumRequest = request
        inFlightActions.insert(.recentAlbum)
        return true
    }

    @discardableResult
    func completeRecentAlbumAddition(
        _ request: S2AlbumActionRequest,
        outcome: S2AlbumAdditionOutcome
    ) -> Bool {
        if inFlightRecentAlbumRequest == request {
            inFlightRecentAlbumRequest = nil
            inFlightActions.remove(.recentAlbum)
        }
        guard orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }
        switch outcome {
        case .success:
            // v15 未定项 16 定案：已包含与首次加入不区分，均走完整成功路径。
            setRecentAlbum(request.album)
            removeFromPendingAfterAlbumAddition(request.targetAssetID)
            // IC-113 B：登记成功，供中央指示显示「已加入「名」」。
            publishAlbumAddition(
                assetID: request.targetAssetID,
                album: request.album
            )
            return true
        case .failure:
            publishFeedback(.albumAdditionFailed)
            return false
        case .albumUnavailable:
            // v15 第二节第 4 部分：历史相册已不存在时清除 `H`、不弹错误提示。
            invalidateAlbum(request.album)
            return false
        }
    }

    func presentAlbumPicker() -> S2AlbumPickerRequest? {
        guard controlsCanReceiveInput else {
            return nil
        }
        albumPickerTargetAssetID = currentAssetID
        sheetState = .presented
        return albumPickerRequest
    }

    /// 三段之一：选中 → 写入中。sheet 保持呈现，列表由视图按进行中标志禁用。
    @discardableResult
    func beginAlbumPickerSelection(
        _ request: S2AlbumPickerRequest,
        album: S2AlbumReference
    ) -> Bool {
        guard sheetState == .presented,
              albumPickerTargetAssetID == request.targetAssetID,
              orderedAssetIDs.contains(request.targetAssetID),
              !isActionInFlight(.albumPicker) else {
            return false
        }
        inFlightAlbumPickerSelection = S2AlbumPickerSelection(
            request: request,
            album: album
        )
        inFlightActions.insert(.albumPicker)
        return true
    }

    /// 三段之三：结果。成功 → 更新 `H`、`x ∈ D` 时静默移出、关闭 sheet；
    /// 失败 → sheet 保持打开、列表恢复、发反馈事件；目标相册已不存在 →
    /// 与该相册相同的 `H` 失效，并按失败处理（sheet 保持打开、发反馈事件）。
    @discardableResult
    func completeAlbumPickerSelection(
        _ request: S2AlbumPickerRequest,
        album: S2AlbumReference,
        outcome: S2AlbumAdditionOutcome
    ) -> Bool {
        let selection = S2AlbumPickerSelection(request: request, album: album)
        if inFlightAlbumPickerSelection == selection {
            inFlightAlbumPickerSelection = nil
            inFlightActions.remove(.albumPicker)
        }
        guard orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }
        switch outcome {
        case .success:
            setRecentAlbum(album)
            removeFromPendingAfterAlbumAddition(request.targetAssetID)
            // IC-113 B：选择器路径同样登记成功。
            publishAlbumAddition(
                assetID: request.targetAssetID,
                album: album
            )
            if sheetState == .presented,
               albumPickerTargetAssetID == request.targetAssetID {
                sheetState = .closed
                albumPickerTargetAssetID = nil
            }
            return true
        case .failure:
            publishFeedback(.albumAdditionFailed)
            return false
        case .albumUnavailable:
            invalidateAlbum(album)
            publishFeedback(.albumAdditionFailed)
            return false
        }
    }

    @discardableResult
    func cancelAlbumPicker() -> Bool {
        guard sheetState == .presented else {
            return false
        }
        sheetState = .closed
        albumPickerTargetAssetID = nil
        return true
    }

    /// 视图消费一次性反馈事件后调用；不影响计数。
    func consumeFeedbackEvent() -> S2FeedbackEvent? {
        let event = feedbackEvent
        feedbackEvent = nil
        return event
    }

    func makeExitPayload() -> S2ExitPayload? {
        guard controlsCanReceiveInput else {
            return nil
        }
        return S2ExitPayload(
            upstreamReturn: SessionStore.S2Return(
                sourceSessionID: entry.sessionID,
                sourceRangeID: entry.rangeDisplayInformation.rangeID,
                pendingDeletionAssetIDs: pendingDeletionAssetIDs,
                currentAssetID: currentAssetID,
                farthestAssetID: farthestAssetID
            ),
            continuationSnapshot: S2ContinuationSnapshot(
                orderedAssetIDs: orderedAssetIDs,
                currentAssetID: currentAssetID,
                pendingDeletionAssetIDs: pendingDeletionAssetIDs,
                rangeDisplayInformation: entry.rangeDisplayInformation
            )
        )
    }

    @discardableResult
    func handleSystemEdgeSwipeBack() -> Bool {
        false
    }

    func clampViewport(viewportSize: CGSize, fittedSize: CGSize) {
        viewportOffset = S2Geometry.clampedOffset(
            viewportOffset,
            viewportSize: viewportSize,
            fittedSize: fittedSize,
            zoomScale: scale
        )
    }

    func consumeSemanticNotice() -> S2SemanticNotice? {
        let notice = semanticNotice
        semanticNotice = nil
        return notice
    }

    func clearPendingUndecidedItem() {
        pendingUndecidedItem = nil
    }

    @discardableResult
    /// IC-078：按资产求当前最大倍率（v15 第十一节第 1 部分）。
    /// 尚未登记资产缩放几何（像素尺寸未解析）时取 `pinchMaxScaleFloor`。
    func pinchMaxScale(for assetID: String) -> CGFloat {
        guard let geometry = assetZoomGeometries[assetID] else {
            return parameters.pinchMaxScaleFloor
        }
        return parameters.pinchMaxScale(
            assetPixelSize: geometry.assetPixelSize,
            fitSize: geometry.fitSize,
            displayScale: geometry.displayScale
        )
    }

    func assetZoomGeometry(for assetID: String) -> S2AssetZoomGeometry? {
        assetZoomGeometries[assetID]
    }

    /// 视图层在页面绑定资产或像素尺寸解析后登记；不触发任何状态发布，
    /// 也不改写当前 `s`（静止态零写入），上限只在下一次钳制时生效。
    func updateAssetZoomGeometry(
        _ geometry: S2AssetZoomGeometry,
        for assetID: String
    ) {
        guard assetZoomGeometries[assetID] != geometry else {
            return
        }
        assetZoomGeometries[assetID] = geometry
    }

    func applyCalibration(
        _ configuration: S2CalibrationConfiguration
    ) -> Bool {
        guard let resolvedParameters = configuration.resolvedParameters else {
            return false
        }
        parameters = resolvedParameters
        imageRequestStrategy = configuration.imageRequestStrategy
        let currentPinchMaxScale = pinchMaxScale(for: currentAssetID)
        if scale > currentPinchMaxScale {
            setScale(currentPinchMaxScale)
            imageRequestScale = scale
        }
        return true
    }

    func recordGestureReading(_ reading: S2GestureReading) {
        lastGestureReading = reading
    }

    func recordImageRequestReading(_ reading: S2ImageRequestReading) {
        lastImageRequestReading = reading
    }

    @discardableResult
    func navigateToNextAsset(
        category: S2AssetAspectCategory,
        viewportAspectRatio: CGFloat,
        assetAspectRatio: (String) -> CGFloat
    ) -> S2AssetNavigationResult {
        let result = S2AssetAspectNavigator.next(
            in: orderedAssetIDs,
            after: currentIndex,
            category: category,
            viewportAspectRatio: viewportAspectRatio,
            assetAspectRatio: assetAspectRatio
        )
        assetNavigationResult = result
        if case let .found(index, _) = result {
            currentIndex = index
            farthestIndex = max(farthestIndex, index)
            resetZoomAfterPhotoChange()
        }
        return result
    }

    private var receivesUnobscuredInput: Bool {
        sheetState == .closed && touchSequenceOwner == .none
    }

    private var controlsCanReceiveInput: Bool {
        receivesUnobscuredInput &&
            (state == .visibleOneXIdle || state == .visibleNxIdle)
    }

    @discardableResult
    private func switchPhoto(by offset: Int) -> Bool {
        let destination = currentIndex + offset
        guard orderedAssetIDs.indices.contains(destination) else {
            pendingUndecidedItem = .item03
            return false
        }
        currentIndex = destination
        farthestIndex = max(farthestIndex, destination)
        resetZoomAfterPhotoChange()
        return true
    }

    private func resetZoomAfterPhotoChange() {
        setScale(1)
        imageRequestScale = 1
        viewportOffset = .zero
    }

    private func replacePendingDeletionAssetIDs(with nextValue: Set<String>) {
        guard nextValue != pendingDeletionAssetIDs else {
            return
        }
        pendingDeletionAssetIDs = nextValue
        pendingDeletionDidChange(nextValue)
    }

    /// v15 回写决策 29：加入相册后从 `D` 移除静默完成，以待删标记的消失为唯一反馈。
    private func removeFromPendingAfterAlbumAddition(_ assetID: String) {
        guard pendingDeletionAssetIDs.contains(assetID) else {
            return
        }
        var nextPending = pendingDeletionAssetIDs
        nextPending.remove(assetID)
        replacePendingDeletionAssetIDs(with: nextPending)
    }

    /// 决策 16：历史相册失效只作用于 `H`；`G(a)` 已随 v15 移除。
    /// `H` 的每次变化都经由 `recentAlbumDidChange` 交给协调器持久化。
    private func invalidateAlbum(_ album: S2AlbumReference) {
        if recentAlbum?.id == album.id {
            setRecentAlbum(nil)
        }
    }

    /// IC-113 B：中央指示「撤回」——把资产从刚加入的相簿移除。
    /// 三段式与相簿加入同构：取请求 → 登记在途 → 结果。
    func makeAlbumRemovalRequest() -> S2AlbumActionRequest? {
        guard let record = lastAlbumAddition,
              !isAlbumRemovalInFlight,
              orderedAssetIDs.contains(record.assetID) else {
            return nil
        }
        return S2AlbumActionRequest(
            targetAssetID: record.assetID,
            album: record.album
        )
    }

    @discardableResult
    func beginAlbumRemoval(_ request: S2AlbumActionRequest) -> Bool {
        guard !isAlbumRemovalInFlight,
              orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }
        isAlbumRemovalInFlight = true
        return true
    }

    /// 成功即清掉加入记录——中央指示随之失去「已加入」这一态。
    /// 失败沿用既有反馈通道，不新增分支。
    @discardableResult
    func completeAlbumRemoval(
        _ request: S2AlbumActionRequest,
        succeeded: Bool
    ) -> Bool {
        isAlbumRemovalInFlight = false
        guard succeeded else {
            publishFeedback(.albumAdditionFailed)
            return false
        }
        if lastAlbumAddition?.assetID == request.targetAssetID,
           lastAlbumAddition?.album == request.album {
            lastAlbumAddition = nil
        }
        return true
    }

    /// IC-114 C：新建相簿失败——只发一次反馈，不改任何状态。
    func reportAlbumCreationFailure() {
        publishFeedback(.albumCreationFailed)
    }

    private func publishAlbumAddition(
        assetID: String,
        album: S2AlbumReference
    ) {
        albumAdditionCount += 1
        lastAlbumAddition = S2AlbumAdditionRecord(
            id: albumAdditionCount,
            assetID: assetID,
            album: album
        )
    }

    /// IC-114 D（⑤a ④）：**唯一的 `scale` 写入口**。
    ///
    /// 除构造时的初始赋值外，状态机内所有缩放写入都经此分派，
    /// 「放大自动隐藏」因而不可能被旁路（B1 同族闸门）。
    /// IC-118 A：原声称「只剩两处直写」漏了 `reportNativeViewport` 与
    /// `finishNativePinch` 两处（真机捏合路径），已一并改道。
    ///
    /// 规则：
    /// - `s` 由 1 进入 >1：记下进入前 `V`；若当时是显示态则自动置隐藏。
    ///   进入时 `V` 已是隐藏 → 记录隐藏、无动作。
    /// - 由 >1 回到 1：恢复进入前 `V`，并清空记录。
    /// - 放大中的倍率变化（>1 → >1）：不触碰 `V`。
    /// - `appliesZoomVisibilityRule == false`（仅供无手势在途的视口回声，
    ///   如捏合回弹动画帧）：只写倍率，不触碰 `V` 与记录。
    private func setScale(
        _ newValue: CGFloat,
        appliesZoomVisibilityRule: Bool = true
    ) {
        let previous = scale
        scale = newValue
        guard previous != newValue,
              appliesZoomVisibilityRule else {
            return
        }
        if previous == 1, newValue > 1 {
            visibilityBeforeZoom = interfaceVisibility
            if interfaceVisibility == .visible {
                interfaceVisibility = .hidden
            }
        } else if previous > 1, newValue == 1 {
            if let remembered = visibilityBeforeZoom {
                interfaceVisibility = remembered
            }
            visibilityBeforeZoom = nil
        }
    }

    /// 测试可见：当前记下的「进入前 V」。
    var recordedVisibilityBeforeZoom: S2InterfaceVisibility? {
        visibilityBeforeZoom
    }

    private func setRecentAlbum(_ album: S2AlbumReference?) {
        guard recentAlbum != album else {
            return
        }
        recentAlbum = album
        recentAlbumDidChange(album)
    }

    private func publishFeedback(_ kind: S2FeedbackEventKind) {
        feedbackEventCount += 1
        feedbackEvent = S2FeedbackEvent(id: feedbackEventCount, kind: kind)
    }
}
