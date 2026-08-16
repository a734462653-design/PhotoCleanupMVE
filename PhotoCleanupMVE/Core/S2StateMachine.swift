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
    case item11
    case item12
    case item13
    case item14
    case item15
    case item16
    case item17
    case item18
    case item19
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
    static let item11WriteFailureFeedback = S2UndecidedPlaceholder.unresolved
    static let item12AlbumRemovalHint = S2UndecidedPlaceholder.unresolved
    static let item13AlbumHistoryDepth = S2UndecidedPlaceholder.unresolved
    static let item14AlbumHistoryPersistence = S2UndecidedPlaceholder.unresolved
    static let item15InFlightControls = S2UndecidedPlaceholder.unresolved
    static let item16AlreadyContainedCopy = S2UndecidedPlaceholder.unresolved
    static let item17AlbumBadgePresentation = S2UndecidedPlaceholder.unresolved
    static let item18BottomStripMarkPresentation = S2UndecidedPlaceholder.unresolved
    static let item19AlreadyMarkedHint = S2UndecidedPlaceholder.unresolved
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

struct S2BottomStripMetrics: Equatable {
    let currentItemSize: CGFloat
    let neighborItemWidth: CGFloat
    let neighborItemHeight: CGFloat
    let itemSpacing: CGFloat
    let edgeFadeWidth: CGFloat
    let dragMinimumDistance: CGFloat
    let switchDistance: CGFloat

    var height: CGFloat {
        max(currentItemSize, neighborItemHeight)
    }

    var isValid: Bool {
        currentItemSize > 0 &&
            neighborItemWidth > 0 &&
            neighborItemHeight > 0 &&
            itemSpacing >= 0 &&
            edgeFadeWidth >= 0 &&
            dragMinimumDistance >= 0 &&
            switchDistance > 0
    }
}

// 此类型只承接未来决议的显式注入；本卡不提供任何默认实例。
struct S2ResolvedParameters: Equatable {
    let pinchMaxScale: CGFloat
    let zoomSnapBackThreshold: CGFloat
    let minDoubleTapScale: CGFloat
    let doubleTapAnchorStrategy: S2DoubleTapAnchorStrategy
    let edgePagingTriggerDistance: CGFloat
    let edgePagingTriggerVelocity: CGFloat
    let verticalSwipeDistance: CGFloat
    let verticalSwipeVelocity: CGFloat
    let horizontalSwipeDistance: CGFloat
    let horizontalSwipeVelocity: CGFloat
    let pinchMinimumScaleDelta: CGFloat
    let mainDragMinimumDistance: CGFloat
    let bottomStripMetrics: S2BottomStripMetrics

    init?(
        pinchMaxScale: CGFloat,
        zoomSnapBackThreshold: CGFloat,
        minDoubleTapScale: CGFloat,
        doubleTapAnchorStrategy: S2DoubleTapAnchorStrategy,
        edgePagingTriggerDistance: CGFloat,
        edgePagingTriggerVelocity: CGFloat,
        verticalSwipeDistance: CGFloat,
        verticalSwipeVelocity: CGFloat,
        horizontalSwipeDistance: CGFloat,
        horizontalSwipeVelocity: CGFloat,
        pinchMinimumScaleDelta: CGFloat,
        mainDragMinimumDistance: CGFloat,
        bottomStripMetrics: S2BottomStripMetrics
    ) {
        guard pinchMaxScale > 1,
              zoomSnapBackThreshold >= 1,
              zoomSnapBackThreshold <= pinchMaxScale,
              minDoubleTapScale > 1,
              edgePagingTriggerDistance >= 0,
              edgePagingTriggerVelocity >= 0,
              verticalSwipeDistance >= 0,
              verticalSwipeVelocity >= 0,
              horizontalSwipeDistance >= 0,
              horizontalSwipeVelocity >= 0,
              pinchMinimumScaleDelta >= 0,
              mainDragMinimumDistance >= 0,
              bottomStripMetrics.isValid else {
            return nil
        }

        self.pinchMaxScale = pinchMaxScale
        self.zoomSnapBackThreshold = zoomSnapBackThreshold
        self.minDoubleTapScale = minDoubleTapScale
        self.doubleTapAnchorStrategy = doubleTapAnchorStrategy
        self.edgePagingTriggerDistance = edgePagingTriggerDistance
        self.edgePagingTriggerVelocity = edgePagingTriggerVelocity
        self.verticalSwipeDistance = verticalSwipeDistance
        self.verticalSwipeVelocity = verticalSwipeVelocity
        self.horizontalSwipeDistance = horizontalSwipeDistance
        self.horizontalSwipeVelocity = horizontalSwipeVelocity
        self.pinchMinimumScaleDelta = pinchMinimumScaleDelta
        self.mainDragMinimumDistance = mainDragMinimumDistance
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

struct S2AssetActionRequest: Equatable {
    let targetAssetID: String
}

struct S2AlbumActionRequest: Equatable {
    let targetAssetID: String
    let album: S2AlbumReference
}

struct S2AlbumPickerRequest: Equatable {
    let targetAssetID: String
}

enum S2AlbumAdditionOutcome: Equatable {
    case success(alreadyContained: Bool)
    case failure
    case albumUnavailable
}

enum S2SemanticNotice: Equatable {
    case alreadyMarked(assetID: String)
    case albumAdditionRemovedPendingDeletion(assetID: String)
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
    @Published private(set) var imageRequestStrategy: S2ImageRequestStrategy?

    @Published private(set) var interfaceVisibility: S2InterfaceVisibility
    @Published private(set) var scale: CGFloat
    @Published private(set) var viewportOffset: CGSize
    @Published private(set) var bottomStripState: S2BottomStripState = .idle
    @Published private(set) var sheetState: S2SheetState = .closed
    @Published private(set) var touchSequenceOwner: S2TouchSequenceOwner = .none
    @Published private(set) var currentIndex: Int
    @Published private(set) var farthestIndex: Int
    @Published private(set) var pendingDeletionAssetIDs: Set<String>
    @Published private(set) var favoriteAssetIDs: Set<String>
    @Published private(set) var recentAlbum: S2AlbumReference?
    @Published private(set) var addedAlbumsByAssetID: [String: [S2AlbumReference]] = [:]
    @Published private(set) var semanticNotice: S2SemanticNotice?
    @Published private(set) var pendingUndecidedItem: S2UndecidedItem?
    @Published private(set) var imageRequestRevision = 0
    @Published private(set) var imageRequestAssetID: String?
    @Published private(set) var lastGestureReading: S2GestureReading?
    @Published private(set) var lastTapDecisionReading: S2TapDecisionReading?
    @Published private(set) var lastImageRequestReading: S2ImageRequestReading?
    @Published private(set) var assetNavigationResult: S2AssetNavigationResult?
    private(set) var imageRequestScale: CGFloat

    private let pendingDeletionDidChange: (Set<String>) -> Void
    private var pinchStartScale: CGFloat?
    private var albumPickerTargetAssetID: String?

    init?(
        entry: S2EntryContext,
        initialPresentation: S2InitialPresentation,
        parameters: S2ResolvedParameters,
        imageRequestStrategy: S2ImageRequestStrategy?,
        initialFavoriteAssetIDs: Set<String>,
        initialRecentAlbum: S2AlbumReference?,
        pendingDeletionDidChange: @escaping (Set<String>) -> Void
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
              initialPresentation.scale <= parameters.pinchMaxScale else {
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

    var currentAddedAlbums: [S2AlbumReference] {
        addedAlbumsByAssetID[currentAssetID] ?? []
    }

    var sessionMergedPendingDeletionCount: Int {
        entry.sessionMergedPendingDeletionCount
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
            switch origin {
            case .pageOutside:
                return .unavailable
            case .state(.visibleOneXIdle):
                return .available(.state(.visibleNxIdle))
            case .state(.visibleOneXStripDragging),
                 .state(.visibleNxStripDragging):
                return .unavailable
            case .state(.hiddenOneX):
                return .available(.state(.hiddenNx))
            case .state(.visibleNxIdle):
                return .available(.state(.visibleOneXIdle))
            case .state(.hiddenNx):
                return .available(.state(.hiddenOneX))
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
            case .state(.visibleOneXIdle), .state(.hiddenOneX):
                return .conditional(.sameState)
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
            case .state(_):
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

    static func gestureRule(
        for input: S2GestureInput,
        context: S2GestureContext
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
            return S2GestureRule(
                availability: .available,
                effect: .markCurrent
            )

        case .swipeDownMainImage:
            return context == .oneX
                ? S2GestureRule(
                    availability: .available,
                    effect: .unmarkCurrent
                )
                : S2GestureRule(
                    availability: .conditional,
                    effect: .panOnly
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
            scale = 1
            imageRequestScale = 1
            viewportOffset = .zero
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

        scale = nextScale
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
            scale = 1
            imageRequestScale = 1
            viewportOffset = .zero
            return true
        }

        guard targetScale.isFinite, targetScale > 1 else {
            return false
        }
        let resolvedScale = min(parameters.pinchMaxScale, targetScale)
        guard resolvedScale > 1 else {
            return false
        }
        scale = resolvedScale
        imageRequestScale = resolvedScale
        viewportOffset = .zero
        return true
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
        self.scale = min(parameters.pinchMaxScale, max(1, scale))
        self.viewportOffset = self.scale == 1 ? .zero : viewportOffset
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
            self.scale = 1
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
        scale = min(
            parameters.pinchMaxScale,
            max(1, pinchStartScale * magnification)
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
            scale = 1
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
        scale = pinchStartScale
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
        let assetID = currentAssetID
        guard !pendingDeletionAssetIDs.contains(assetID) else {
            semanticNotice = .alreadyMarked(assetID: assetID)
            pendingUndecidedItem = .item19
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
              zoomState == .oneX,
              pendingDeletionAssetIDs.contains(currentAssetID) else {
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

        if direction == .horizontal,
           horizontalDistance >= parameters.horizontalSwipeDistance,
           horizontalVelocity >= parameters.horizontalSwipeVelocity {
            return handleHorizontalSwipe(
                direction: translation.width < 0 ? .next : .previous,
                startedAtPagingEdge: true,
                distance: horizontalDistance,
                velocity: horizontalVelocity
            )
        }
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

    func makeFavoriteToggleRequest() -> S2AssetActionRequest? {
        guard controlsCanReceiveInput else {
            return nil
        }
        return S2AssetActionRequest(targetAssetID: currentAssetID)
    }

    @discardableResult
    func completeFavoriteToggle(
        _ request: S2AssetActionRequest,
        succeeded: Bool
    ) -> Bool {
        guard succeeded, orderedAssetIDs.contains(request.targetAssetID) else {
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
        guard controlsCanReceiveInput, let recentAlbum else {
            return nil
        }
        return S2AlbumActionRequest(
            targetAssetID: currentAssetID,
            album: recentAlbum
        )
    }

    @discardableResult
    func completeRecentAlbumAddition(
        _ request: S2AlbumActionRequest,
        outcome: S2AlbumAdditionOutcome
    ) -> Bool {
        guard orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }
        switch outcome {
        case .success(_):
            recentAlbum = request.album
            recordAlbum(request.album, for: request.targetAssetID)
            removeFromPendingAfterAlbumAddition(request.targetAssetID)
            return true
        case .failure:
            pendingUndecidedItem = .item11
            return false
        case .albumUnavailable:
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

    @discardableResult
    func completeAlbumPickerSelection(
        _ request: S2AlbumPickerRequest,
        album: S2AlbumReference
    ) -> Bool {
        guard sheetState == .presented,
              albumPickerTargetAssetID == request.targetAssetID,
              orderedAssetIDs.contains(request.targetAssetID) else {
            return false
        }

        recentAlbum = album
        recordAlbum(album, for: request.targetAssetID)
        removeFromPendingAfterAlbumAddition(request.targetAssetID)
        sheetState = .closed
        albumPickerTargetAssetID = nil
        return true
    }

    @discardableResult
    func reportAlbumPickerFailure(_ request: S2AlbumPickerRequest) -> Bool {
        guard sheetState == .presented,
              albumPickerTargetAssetID == request.targetAssetID else {
            return false
        }
        pendingUndecidedItem = .item11
        return true
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
    func applyCalibration(
        _ configuration: S2CalibrationConfiguration
    ) -> Bool {
        guard let resolvedParameters = configuration.resolvedParameters else {
            return false
        }
        parameters = resolvedParameters
        imageRequestStrategy = configuration.imageRequestStrategy
        if scale > resolvedParameters.pinchMaxScale {
            scale = resolvedParameters.pinchMaxScale
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
        scale = 1
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

    private func recordAlbum(_ album: S2AlbumReference, for assetID: String) {
        var albums = addedAlbumsByAssetID[assetID] ?? []
        albums.removeAll { $0.id == album.id }
        albums.append(album)
        addedAlbumsByAssetID[assetID] = albums
    }

    private func removeFromPendingAfterAlbumAddition(_ assetID: String) {
        guard pendingDeletionAssetIDs.contains(assetID) else {
            return
        }
        var nextPending = pendingDeletionAssetIDs
        nextPending.remove(assetID)
        replacePendingDeletionAssetIDs(with: nextPending)
        semanticNotice = .albumAdditionRemovedPendingDeletion(assetID: assetID)
        pendingUndecidedItem = .item12
    }

    private func invalidateAlbum(_ album: S2AlbumReference) {
        if recentAlbum?.id == album.id {
            recentAlbum = nil
        }
        for assetID in Array(addedAlbumsByAssetID.keys) {
            addedAlbumsByAssetID[assetID]?.removeAll { $0.id == album.id }
        }
    }
}
