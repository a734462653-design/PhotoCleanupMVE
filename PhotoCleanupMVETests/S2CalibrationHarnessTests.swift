import XCTest
import Photos
import SwiftUI
import UIKit
@testable import PhotoCleanupMVE

private final class S2NativeZoomTestDelegate: NSObject, UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        (scrollView as? S2NativeZoomScrollView)?.zoomContentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
    }

    func scrollViewDidEndZooming(
        _ scrollView: UIScrollView,
        with view: UIView?,
        atScale scale: CGFloat
    ) {}
}

private final class S2ImageRequestCounter: S2PhotoImageRequesting {
    private(set) var requestCount = 0

    @discardableResult
    func requestImage(
        assetID: String,
        targetSize: CGSize,
        requestStrategy: S2ImageRequestStrategy,
        resultHandler: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID {
        requestCount += 1
        resultHandler(UIImage(), false)
        return PHInvalidImageRequestID
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {}

    func reset() {
        requestCount = 0
    }
}

final class S2CalibrationHarnessTests: XCTestCase {
    private var nativeZoomDelegates: [S2NativeZoomTestDelegate] = []

    // V1：界面显隐不改变全屏物理视口。
    func testV1InterfaceVisibilityKeepsViewportSizeEqual() {
        let visible = metrics(
            visibility: .visible,
            strip: .idle,
            sheet: .closed
        )
        let hidden = metrics(
            visibility: .hidden,
            strip: .idle,
            sheet: .closed
        )

        XCTAssertEqual(visible.viewportSize, hidden.viewportSize)
        XCTAssertEqual(visible.viewportSize, physicalSize)
    }

    // V2：横栏静止态与滑动态保持相同视口和固定外层高度。
    func testV2BottomStripStatesKeepViewportSizeAndHeightEqual() {
        let idle = metrics(
            visibility: .visible,
            strip: .idle,
            sheet: .closed
        )
        let dragging = metrics(
            visibility: .visible,
            strip: .dragging,
            sheet: .closed
        )

        XCTAssertEqual(idle.viewportSize, dragging.viewportSize)
        XCTAssertEqual(idle.bottomStripHeight, dragging.bottomStripHeight)
    }

    // V3：系统 sheet 只遮挡输入，不改变主图视口。
    func testV3SheetPresentationKeepsViewportSizeEqual() {
        let closed = metrics(
            visibility: .visible,
            strip: .idle,
            sheet: .closed
        )
        let presented = metrics(
            visibility: .visible,
            strip: .idle,
            sheet: .presented
        )

        XCTAssertEqual(closed.viewportSize, presented.viewportSize)
    }

    // V4 替代断言：界面状态只可改变框显照片的 1x 呈现，不改变缩放基准。
    func testV4ReplacementPresentationStatesPreserveViewportAndZoomBaselines() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.08
        let states = [
            S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .dragging,
                sheetState: .closed
            ),
            S2ViewportPresentationState(
                interfaceVisibility: .hidden,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .idle,
                sheetState: .presented
            )
        ]
        let allMetrics = states.map {
            S2ViewportLayout.metrics(
                physicalSize: physicalSize,
                presentationState: $0,
                assetAspectRatio: screenAspectRatio,
                configuration: configuration
            )
        }
        let first = tryUnwrap(allMetrics.first)

        for value in allMetrics.dropFirst() {
            XCTAssertEqual(value.aspectFitSize, first.aspectFitSize)
            XCTAssertEqual(value.viewportSize, first.viewportSize)
            XCTAssertEqual(
                value.aspectFillMultiplier,
                first.aspectFillMultiplier,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                value.doubleTapTargetScale,
                first.doubleTapTargetScale,
                accuracy: 0.000_001
            )
        }
    }

    // V5：销毁并重建模型后，进程持久化介质仍能读回全部配置。
    func testV5ParametersSurviveProcessModelRestart() {
        let suiteName = "S2CalibrationHarnessTests.V5.\(UUID().uuidString)"
        let defaults = tryUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let persistence = UserDefaultsCalibrationPersistence(
            defaults: defaults,
            key: "configuration"
        )
        let first = S2CalibrationModel(persistence: persistence)
        XCTAssertTrue(first.update {
            $0.pinchMaxScale = 5.5
            $0.zoomSnapBackThreshold = 1.25
            $0.fitInsetRatio = 0.075
            $0.fitCornerRadius = 36
            $0.fitInsetScope = .allPhotos
            $0.pageSpacing = 28
            $0.hapticOnPhotoSwitch = false
            $0.scaleChangeRequestPolicy = .pinchEnded
            $0.degradedPreviewPolicy = .display
            $0.animationDurationMilliseconds = 200
        })

        let restarted = S2CalibrationModel(
            persistence: UserDefaultsCalibrationPersistence(
                defaults: tryUnwrap(UserDefaults(suiteName: suiteName)),
                key: "configuration"
            )
        )
        XCTAssertEqual(restarted.configuration, first.configuration)
        XCTAssertTrue(restarted.exportText().contains("fitInsetRatio=0.075000"))
        XCTAssertTrue(restarted.exportText().contains("fitCornerRadius=36.000000"))
        XCTAssertTrue(restarted.exportText().contains("pageSpacing=28.000000"))
        XCTAssertTrue(restarted.exportText().contains("hapticOnPhotoSwitch=false"))
        XCTAssertTrue(
            restarted.exportText().contains(
                "valueStatus=④项目判断默认值，可修订"
            )
        )

        restarted.restoreFactoryPlaceholder()
        let resetRestart = S2CalibrationModel(persistence: persistence)
        XCTAssertEqual(
            resetRestart.configuration,
            S2CalibrationConfiguration.factoryPlaceholder
        )
    }

    // V6：四种策略组合从面板配置进入状态机并驱动同一请求判定器。
    func testV6AllFourImageRequestStrategiesTakeEffectImmediately() {
        let timings = S2ScaleChangeImageRequestPolicy.allCases
        let previews = S2DegradedPreviewPolicy.allCases
        XCTAssertEqual(timings.count * previews.count, 4)

        let machine = makeMachine()
        let panelModel = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        for timing in timings {
            for preview in previews {
                XCTAssertTrue(panelModel.update {
                    $0.scaleChangeRequestPolicy = timing
                    $0.degradedPreviewPolicy = preview
                })

                XCTAssertTrue(machine.applyCalibration(panelModel.configuration))
                let active = tryUnwrap(machine.imageRequestStrategy)
                XCTAssertEqual(
                    active,
                    panelModel.configuration.imageRequestStrategy
                )
                XCTAssertEqual(
                    S2ImageRequestDecision.shouldRequest(
                        for: .scaleChange,
                        strategy: active
                    ),
                    timing == .everyScaleChange
                )
                XCTAssertEqual(
                    S2ImageRequestDecision.shouldRequest(
                        for: .pinchEnded,
                        strategy: active
                    ),
                    timing == .pinchEnded
                )
                XCTAssertEqual(
                    S2ImageRequestDecision.shouldDisplay(
                        isDegraded: true,
                        strategy: active
                    ),
                    preview == .display
                )
            }
        }
    }

    // V7：无匹配素材时返回具名空结果并保留当前照片。
    func testV7MissingAspectCategoryReturnsExplicitEmptyResult() {
        let machine = makeMachine()
        let originalAssetID = machine.currentAssetID
        let result = machine.navigateToNextAsset(
            category: .extreme,
            viewportAspectRatio: screenAspectRatio,
            assetAspectRatio: { _ in 1 }
        )

        XCTAssertEqual(result, .empty)
        XCTAssertEqual(machine.assetNavigationResult, .empty)
        XCTAssertEqual(machine.currentAssetID, originalAssetID)
        XCTAssertTrue(
            S2AssetAspectCategory.extreme.matches(
                assetAspectRatio: 2.5,
                viewportAspectRatio: screenAspectRatio
            )
        )
    }

    // V8：内缩比例只改变实际显示尺寸，不改变视口，并遵守作用范围。
    func testV8FitInsetRatioGeometryAndScopeAreCorrect() {
        var zero = S2CalibrationConfiguration.factoryPlaceholder
        zero.fitInsetRatio = 0
        let zeroMetrics = metrics(configuration: zero)
        XCTAssertEqual(zeroMetrics.oneXDisplaySize, zeroMetrics.aspectFitSize)

        var inset = zero
        inset.fitInsetRatio = 0.1
        let insetMetrics = metrics(configuration: inset)
        let horizontalMarginRatio =
            (insetMetrics.viewportSize.width -
                insetMetrics.oneXDisplaySize.width) /
            2 / insetMetrics.viewportSize.width
        let verticalMarginRatio =
            (insetMetrics.viewportSize.height -
                insetMetrics.oneXDisplaySize.height) /
            2 / insetMetrics.viewportSize.height

        XCTAssertEqual(horizontalMarginRatio, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(verticalMarginRatio, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(zeroMetrics.viewportSize, insetMetrics.viewportSize)
        XCTAssertEqual(
            insetMetrics.aspectFillMultiplier,
            1,
            accuracy: 0.000_001
        )

        let nonScreenRatio: CGFloat = 1
        let scoped = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: nonScreenRatio,
            configuration: inset
        )
        XCTAssertEqual(scoped.oneXDisplaySize, scoped.aspectFitSize)

        inset.fitInsetScope = .allPhotos
        let global = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: nonScreenRatio,
            configuration: inset
        )
        XCTAssertEqual(
            global.oneXDisplaySize.width,
            global.aspectFitSize.width * 0.9,
            accuracy: 0.000_001
        )
        XCTAssertEqual(global.viewportSize, scoped.viewportSize)
    }

    // L1：顶部四个元素全部从系统顶部安全区下沿开始布局。
    func testL1TopOverlayFramesRespectSafeAreaTop() {
        let snapshot = overlaySnapshot()

        XCTAssertEqual(snapshot.topElementFrames.count, 4)
        for frame in snapshot.topElementFrames {
            XCTAssertGreaterThanOrEqual(frame.minY, overlaySafeAreaInsets.top)
        }
    }

    // L2：底部操作与照片横栏都不进入主屏幕指示条区域。
    func testL2BottomOverlayFramesRespectHomeIndicator() {
        let snapshot = overlaySnapshot()
        let safeBottom = overlayPhysicalSize.height -
            overlaySafeAreaInsets.bottom

        XCTAssertEqual(snapshot.bottomElementFrames.count, 4)
        for frame in snapshot.bottomElementFrames {
            XCTAssertLessThanOrEqual(frame.maxY, safeBottom)
        }
    }

    // L3：返回、范围、状态与确认四个顶部元素之间均保留间距。
    func testL3TopOverlayFramesDoNotIntersect() {
        let frames = overlaySnapshot().topElementFrames

        for firstIndex in frames.indices {
            for secondIndex in frames.indices where secondIndex > firstIndex {
                XCTAssertFalse(
                    frames[firstIndex].intersects(frames[secondIndex]),
                    "顶部元素 \(firstIndex) 与 \(secondIndex) 不应相交"
                )
            }
        }
    }

    // L4：产品浮层、横栏与后台控制条的全部触控区域至少为 44 pt。
    func testL4ClickableOverlayControlsMeetMinimumTouchTarget() {
        let state = S2CalibrationOverlayState(
            controlsVisible: true,
            parameterPanelVisible: true,
            readingsVisible: true
        )
        let frames = overlaySnapshot(
            calibrationState: state
        ).clickableControlFrames

        XCTAssertEqual(frames.count, 8)
        for frame in frames {
            XCTAssertGreaterThanOrEqual(
                frame.width,
                S2OverlayLayout.minimumTouchTarget
            )
            XCTAssertGreaterThanOrEqual(
                frame.height,
                S2OverlayLayout.minimumTouchTarget
            )
        }
    }

    // L5：两个后台面板分别打开、关闭及同时打开都不改变视口。
    func testL5CalibrationPanelsDoNotChangeViewportSize() {
        var state = S2CalibrationOverlayState.initial
        let initial = metrics(calibrationState: state).viewportSize

        state.toggleAccessControls()
        state.toggleParameterPanel()
        XCTAssertEqual(metrics(calibrationState: state).viewportSize, initial)

        state.toggleParameterPanel()
        state.toggleReadings()
        XCTAssertEqual(metrics(calibrationState: state).viewportSize, initial)

        state.toggleParameterPanel()
        XCTAssertEqual(metrics(calibrationState: state).viewportSize, initial)

        state.toggleReadings()
        XCTAssertEqual(metrics(calibrationState: state).viewportSize, initial)
    }

    // L6：首次启动无面板、无控制条，也没有占据主界面的入口帧。
    func testL6CalibrationPanelsStartHiddenWithoutVisibleEntry() {
        let state = S2CalibrationOverlayState.initial
        let snapshot = overlaySnapshot(calibrationState: state)

        XCTAssertFalse(state.controlsVisible)
        XCTAssertFalse(state.parameterPanelVisible)
        XCTAssertFalse(state.readingsVisible)
        XCTAssertNil(snapshot.calibrationEntryFrame)

        var revealed = state
        revealed.toggleAccessControls()
        XCTAssertTrue(revealed.controlsVisible)
        XCTAssertFalse(revealed.parameterPanelVisible)
        XCTAssertFalse(revealed.readingsVisible)
    }

    // L7：完整出厂配置锁定 IC-055 指定值，避免系统惯例项漂移。
    func testL7FactoryDefaultsMatchSystemParityDecision() {
        let expected = S2CalibrationConfiguration(
            pinchMaxScale: 4,
            zoomSnapBackThreshold: 1.1,
            minDoubleTapScale: 2.5,
            doubleTapAnchorStrategy: .touchPoint,
            edgePagingTriggerDistance: 40,
            edgePagingTriggerVelocity: 300,
            verticalSwipeDistance: 40,
            verticalSwipeVelocity: 100,
            verticalSwipeMaximumDurationMilliseconds: 0,
            horizontalSwipeDistance: 40,
            horizontalSwipeVelocity: 100,
            horizontalSwipeMaximumDurationMilliseconds: 0,
            pinchMinimumScaleDelta: 0.01,
            pinchMinimumVelocityPerSecond: 0,
            pinchMaximumDurationMilliseconds: 0,
            mainDragMinimumDistance: 8,
            mainDragMinimumVelocity: 0,
            mainDragMaximumDurationMilliseconds: 0,
            singleTapMaximumMovement: 12,
            singleTapMaximumDurationMilliseconds: 280,
            doubleTapDecisionWindowMilliseconds: 200,
            singleTapTouchCount: 1,
            doubleTapTouchCount: 1,
            singleDragTouchCount: 1,
            pinchTouchCount: 2,
            gestureExclusivityPolicy: .pinchBeforeSingleDrag,
            scaleChangeRequestPolicy: .pinchEnded,
            degradedPreviewPolicy: .finalImageOnly,
            animationsEnabled: true,
            animationDurationMilliseconds: 180,
            fitInsetRatio: 0.30,
            fitCornerRadius: 28,
            fitInsetScope: .screenAspectOnly,
            screenshotImmersiveOnHide: true,
            pageSpacing: 20,
            hapticOnPhotoSwitch: true,
            bottomStripCurrentItemSize: 72,
            bottomStripNeighborItemWidth: 52,
            bottomStripNeighborItemHeight: 44,
            bottomStripItemSpacing: 8,
            bottomStripEdgeFadeWidth: 24,
            bottomStripDragMinimumDistance: 4,
            bottomStripSwitchDistance: 44
        )
        let actual = S2CalibrationConfiguration.factoryPlaceholder

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(
            actual.imageRequestStrategy,
            S2ImageRequestStrategy(
                scaleChangePolicy: .pinchEnded,
                degradedPreviewPolicy: .finalImageOnly
            )
        )
        XCTAssertTrue(
            actual.exportText().contains(
                "taskID=IC-20260815-061-immersive-transition-and-nx-stability"
            )
        )
        XCTAssertTrue(
            actual.exportText().contains(
                "valueStatus=④项目判断默认值，可修订"
            )
        )
        XCTAssertTrue(
            actual.exportText().contains("minDoubleTapScale=2.500000")
        )
        XCTAssertTrue(actual.exportText().contains("fitInsetRatio=0.300000"))
        XCTAssertTrue(actual.exportText().contains("fitCornerRadius=28.000000"))
        XCTAssertTrue(actual.exportText().contains("screenshotImmersiveOnHide=true"))
        XCTAssertTrue(actual.exportText().contains("pageSpacing=20.000000"))
        XCTAssertTrue(actual.exportText().contains("hapticOnPhotoSwitch=true"))
        XCTAssertFalse(
            actual.exportText().contains(
                "aspectFillDegenerateTolerancePercent"
            )
        )
        XCTAssertFalse(
            actual.exportText().contains("aspectFillDegenerateTargetScale")
        )
        XCTAssertTrue(
            actual.exportText().contains(
                "doubleTapDecisionWindowMilliseconds=200.000000"
            )
        )
        XCTAssertFalse(
            actual.exportText().contains("singleTapDecisionWindowMilliseconds")
        )
        XCTAssertFalse(actual.exportText().contains("未标定"))
    }

    // P1 替代断言：Nx 平移由原生滚动容器接管并产生非零 contentOffset。
    func testP1NxSingleFingerDragProducesNonzeroPan() {
        let scrollView = makeNativeZoomScrollView()
        scrollView.applyNativeState(
            scale: 2,
            viewportOffset: CGSize(width: 24, height: 16)
        )

        XCTAssertTrue(scrollView is UIScrollView)
        XCTAssertTrue(scrollView.panGestureRecognizer.isEnabled)
        XCTAssertNotEqual(scrollView.contentOffset, .zero)
        XCTAssertNotEqual(scrollView.reportedViewportOffset(), .zero)
    }

    // P2 替代断言：边缘目标交给 UIScrollView 后由其原生边界钳制。
    func testP2NxPanStopsAtContentBoundaryWithoutExtraMargin() {
        let scrollView = makeNativeZoomScrollView()
        _ = scrollView.performDoubleTapZoom(
            at: CGPoint(x: 1, y: physicalSize.height / 2),
            targetScale: 2.5,
            animated: false
        )
        let frame = tryUnwrap(scrollView.visibleContentFrame())

        XCTAssertEqual(frame.minX, 0, accuracy: 0.000_001)
        XCTAssertFalse(scrollView.bounces)
        XCTAssertFalse(scrollView.bouncesZoom)
    }

    // P3 替代断言：1x 时内层原生平移关闭，手势交给外层分页或竖滑语义。
    func testP3OneXSingleFingerDragDoesNotPanPhoto() {
        let scrollView = makeNativeZoomScrollView()
        scrollView.applyNativeState(
            scale: 1,
            viewportOffset: CGSize(width: 80, height: 60)
        )

        XCTAssertFalse(scrollView.panGestureRecognizer.isEnabled)
        XCTAssertEqual(scrollView.zoomScale, 1)
        XCTAssertEqual(scrollView.reportedViewportOffset(), .zero)
    }

    // R1 替代断言：原生捏合上报期间请求倍率不变，结束后只发一次请求信号。
    func testR1PinchRequestsExactlyOnceAfterPinchEnded() {
        let machine = makeMachine()
        let strategy = S2CalibrationConfiguration.factoryPlaceholder
            .imageRequestStrategy
        let triggers: [S2ImageRequestTrigger] = [
            .scaleChange,
            .scaleChange,
            .scaleChange,
            .pinchEnded
        ]
        let requests = triggers.filter {
            S2ImageRequestDecision.shouldRequest(for: $0, strategy: strategy)
        }

        XCTAssertEqual(requests, [.pinchEnded])
        XCTAssertTrue(machine.beginPinch())
        machine.reportNativeViewport(scale: 1.2, viewportOffset: .zero)
        machine.reportNativeViewport(
            scale: 1.6,
            viewportOffset: CGSize(width: 20, height: 10)
        )
        XCTAssertEqual(machine.imageRequestRevision, 0)
        XCTAssertEqual(machine.imageRequestScale, 1)
        let finalScale = tryUnwrap(machine.finishNativePinch(
            scale: 1.6,
            viewportOffset: CGSize(width: 20, height: 10),
            accepted: true
        ))
        XCTAssertEqual(finalScale, 1.6, accuracy: 0.000_001)
        XCTAssertEqual(machine.imageRequestRevision, 1)
        XCTAssertEqual(machine.imageRequestScale, 1.6)
        XCTAssertEqual(machine.imageRequestAssetID, machine.currentAssetID)
    }

    // R2：降质回调不进入显示序列，只允许最终图一次性替换。
    func testR2PinchDoesNotReplaceWithDegradedPreview() {
        let strategy = S2CalibrationConfiguration.factoryPlaceholder
            .imageRequestStrategy
        let returns: [(S2ImageReturnType, Bool)] = [
            (.degradedPreview, true),
            (.finalImage, false)
        ]
        let displayed = returns.filter {
            S2ImageRequestDecision.shouldDisplay(
                isDegraded: $0.1,
                strategy: strategy
            )
        }.map { $0.0 }

        XCTAssertEqual(displayed, [.finalImage])
    }

    // T1 替代断言：原生 contentOffset 令当前页与相邻页等量、同向、单调跟手。
    func testT1AdjacentPageTracksFingerWithSameSignAndMonotonicOffset() {
        let paging = makeNativePagingScrollView()
        let restingCurrent = paging.visibleFrameForPage(at: 1).minX
        let restingNeighbor = paging.visibleFrameForPage(at: 2).minX
        let offsets: [CGFloat] = [20, 60, 120]
        let displacements = offsets.map { offset -> (CGFloat, CGFloat) in
            paging.contentOffset = CGPoint(
                x: paging.contentOffsetForPage(at: 1).x + offset,
                y: 0
            )
            return (
                paging.visibleFrameForPage(at: 1).minX - restingCurrent,
                paging.visibleFrameForPage(at: 2).minX - restingNeighbor
            )
        }

        XCTAssertEqual(displacements.map { $0.0 }, offsets.map { -$0 })
        XCTAssertEqual(displacements.map { $0.1 }, offsets.map { -$0 })
        for index in 1..<displacements.count {
            XCTAssertLessThan(
                displacements[index].0,
                displacements[index - 1].0
            )
        }
    }

    // T2 替代断言：原生分页已启用，未跨半页的落点仍报告当前分页单元。
    func testT2BelowSnapThresholdReturnsToCurrentPage() {
        let paging = makeNativePagingScrollView()
        let currentOffset = paging.contentOffsetForPage(at: 1).x

        XCTAssertTrue(paging.isPagingEnabled)
        XCTAssertEqual(
            paging.pageIndex(
                forContentOffsetX: currentOffset + paging.pageStride * 0.49
            ),
            1
        )
    }

    // T3 替代断言：分页单元尺寸固定；原生落页上报后缩放归一。
    func testT3PagingKeepsPhotoSizeAndResetsScaleAfterSwitch() {
        let machine = makeMachine(scale: 2)
        let paging = makeNativePagingScrollView()

        XCTAssertEqual(
            paging.frameForPage(at: 1).size,
            paging.frameForPage(at: 2).size
        )
        XCTAssertEqual(paging.frameForPage(at: 1).size, physicalSize)
        XCTAssertTrue(machine.handleNativePageChange(to: 2))
        XCTAssertEqual(machine.currentIndex, 2)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
    }

    // D1 替代断言：屏幕比例照片按新出厂值内缩为视口短边的 0.70。
    func testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.30
        configuration.fitInsetScope = .screenAspectOnly
        let value = metrics(configuration: configuration)

        XCTAssertEqual(
            min(value.oneXDisplaySize.width, value.oneXDisplaySize.height),
            min(value.viewportSize.width, value.viewportSize.height) * 0.70,
            accuracy: 1
        )
        XCTAssertTrue(S2ViewportLayout.insetApplies(
            assetAspectRatio: 1 / screenAspectRatio,
            viewportAspectRatio: screenAspectRatio,
            scope: .screenAspectOnly
        ))
        let oppositeOrientation = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1 / screenAspectRatio,
            configuration: configuration
        )
        XCTAssertEqual(
            oppositeOrientation.oneXDisplaySize.width,
            oppositeOrientation.aspectFitSize.width * 0.70,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            oppositeOrientation.oneXDisplaySize.height,
            oppositeOrientation.aspectFitSize.height * 0.70,
            accuracy: 0.000_001
        )
    }

    // D2：内缩比例为零时，1x 显示严格等于纯等比适配。
    func testD2ZeroFitInsetMatchesPureAspectFit() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0
        let value = metrics(configuration: configuration)

        XCTAssertEqual(value.oneXDisplaySize, value.aspectFitSize)
    }

    // D3：仅屏幕比例作用域不会改变非屏幕比例照片的 1x 显示。
    func testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.30
        configuration.fitInsetScope = .screenAspectOnly
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1,
            configuration: configuration
        )

        XCTAssertEqual(value.oneXDisplaySize, value.aspectFitSize)
    }

    // D4 替代断言：屏幕比例照片的原生目标矩形采用最小目标倍数 2.5。
    func testD4ScreenAspectDoubleTapUsesMinimumScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = metrics(configuration: configuration)
        let machine = makeMachine(configuration: configuration)
        let scrollView = makeNativeZoomScrollView(configuration: configuration)
        let targetRect = tryUnwrap(scrollView.performDoubleTapZoom(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            targetScale: value.doubleTapTargetScale,
            animated: false
        ))

        XCTAssertTrue(machine.handleNativeDoubleTap(
            targetScale: value.doubleTapTargetScale
        ))
        XCTAssertEqual(
            machine.scale,
            CGFloat(configuration.minDoubleTapScale),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            tryUnwrap(scrollView.requestedScale(for: targetRect)),
            CGFloat(configuration.minDoubleTapScale),
            accuracy: 0.000_001
        )
    }

    // D5 替代断言：非屏幕比例照片只采用填满倍数，不再与最小倍数取大。
    func testD5ReplacementNonScreenDoubleTapUsesAspectFillScale() {
        let assetAspectRatio: CGFloat = 1
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.30
        configuration.fitInsetScope = .screenAspectOnly
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: assetAspectRatio,
            configuration: configuration
        )
        let expected = tryUnwrap(S2Geometry.aspectFillMultiplier(
            viewportSize: physicalSize,
            assetAspectRatio: assetAspectRatio
        ))
        let machine = makeMachine(configuration: configuration)
        let scrollView = makeNativeZoomScrollView(configuration: configuration)
        let targetRect = tryUnwrap(scrollView.performDoubleTapZoom(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            targetScale: value.doubleTapTargetScale,
            animated: false
        ))

        XCTAssertLessThan(expected, CGFloat(configuration.minDoubleTapScale))
        XCTAssertEqual(value.doubleTapTargetScale, expected, accuracy: 0.000_001)
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: expected))
        XCTAssertEqual(machine.scale, expected, accuracy: 0.000_001)
        XCTAssertEqual(
            tryUnwrap(scrollView.requestedScale(for: targetRect)),
            expected,
            accuracy: 0.000_001
        )
    }

    // D6 替代断言：左边缘双击交给原生 zoom 后，内容左边界贴齐视口。
    func testD6LeftEdgeDoubleTapAlignsLeftContentBoundary() {
        let scrollView = makeNativeZoomScrollView()

        XCTAssertNotNil(scrollView.performDoubleTapZoom(
            at: CGPoint(x: 1, y: physicalSize.height / 2),
            targetScale: metrics().doubleTapTargetScale,
            animated: false
        ))
        let frame = tryUnwrap(scrollView.visibleContentFrame())
        XCTAssertEqual(frame.minX, 0, accuracy: 0.000_001)
    }

    // D7 替代断言：右、上、下边缘双击均由原生边界钳制贴齐视口。
    func testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary() {
        let locationsAndAssertions: [
            (CGPoint, (CGRect, CGRect) -> CGFloat)
        ] = [
            (
                CGPoint(x: physicalSize.width - 1, y: physicalSize.height / 2),
                { contentFrame, viewportBounds in
                    contentFrame.maxX - viewportBounds.maxX
                }
            ),
            (
                CGPoint(x: physicalSize.width / 2, y: 1),
                { contentFrame, viewportBounds in
                    contentFrame.minY - viewportBounds.minY
                }
            ),
            (
                CGPoint(x: physicalSize.width / 2, y: physicalSize.height - 1),
                { contentFrame, viewportBounds in
                    contentFrame.maxY - viewportBounds.maxY
                }
            )
        ]

        for (location, boundaryDifference) in locationsAndAssertions {
            let scrollView = makeNativeZoomScrollView()
            XCTAssertNotNil(scrollView.performDoubleTapZoom(
                at: location,
                targetScale: metrics().doubleTapTargetScale,
                animated: false
            ))
            let frame = tryUnwrap(scrollView.visibleContentFrame())
            XCTAssertEqual(
                boundaryDifference(frame, scrollView.bounds),
                0,
                accuracy: 0.000_001
            )
        }
    }

    // D8 替代断言：原生双击退出 Nx 后 scrollView 与状态机同时归一。
    func testD8DoubleTapExitResetsScaleAndOffset() {
        let value = metrics()
        let machine = makeMachine()
        let scrollView = makeNativeZoomScrollView()
        let location = CGPoint(x: 1, y: physicalSize.height / 2)

        XCTAssertTrue(machine.handleNativeDoubleTap(
            targetScale: value.doubleTapTargetScale
        ))
        XCTAssertNotNil(scrollView.performDoubleTapZoom(
            at: location,
            targetScale: value.doubleTapTargetScale,
            animated: false
        ))
        machine.reportNativeViewport(
            scale: scrollView.zoomScale,
            viewportOffset: scrollView.reportedViewportOffset()
        )
        XCTAssertTrue(machine.handleNativeDoubleTap(
            targetScale: value.doubleTapTargetScale
        ))
        scrollView.setZoomScale(1, animated: false)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
        XCTAssertEqual(scrollView.zoomScale, 1)
    }

    // E1 再替代断言：UIKit 宣告双击失败后，单击回调才切换显隐。
    func testE1ReplacementSingleTapRunsAfterDoubleTapFailure() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertEqual(page.singleTapRecognizer.numberOfTapsRequired, 1)
        XCTAssertTrue(
            page.singleTapRecognizer.requiredDoubleTapRecognizer ===
                page.doubleTapRecognizer
        )
        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
    }

    // E2 再替代断言：双击识别成功时不产生单击显隐动作。
    func testE2ReplacementDoubleTapSuppressesSingleTapAction() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let initialVisibility = machine.interfaceVisibility

        XCTAssertEqual(page.doubleTapRecognizer.numberOfTapsRequired, 2)
        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: 150, y: 300)
        ))
        XCTAssertEqual(
            machine.scale,
            metrics().doubleTapTargetScale,
            accuracy: 0.000_001
        )
        XCTAssertEqual(machine.interfaceVisibility, initialVisibility)
    }

    // E3 再替代断言：两次分别被 UIKit 裁决的单击各生效一次。
    func testE3ReplacementTwoResolvedSingleTapsToggleTwice() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.scale, 1)
    }

    // E4 再替代断言：原生双击回调与直接双击入口结果完全一致。
    func testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap() {
        for visibility in [
            S2InterfaceVisibility.visible,
            S2InterfaceVisibility.hidden
        ] {
            let direct = makeMachine(interfaceVisibility: visibility)
            let coordinated = makeMachine(interfaceVisibility: visibility)
            let directController = makeNativePagerController(machine: direct)
            let directPage = tryUnwrap(
                directController.pageControllers[direct.currentIndex]
            )
            let controller = makeNativePagerController(machine: coordinated)
            let page = tryUnwrap(
                controller.pageControllers[coordinated.currentIndex]
            )

            XCTAssertTrue(directPage.applyRecognizedDoubleTap(
                at: CGPoint(x: 150, y: 300)
            ))
            XCTAssertTrue(page.applyRecognizedDoubleTap(
                at: CGPoint(x: 150, y: 300)
            ))

            XCTAssertEqual(coordinated.interfaceVisibility, direct.interfaceVisibility)
            XCTAssertEqual(coordinated.scale, direct.scale)
            XCTAssertEqual(coordinated.viewportOffset, direct.viewportOffset)
            XCTAssertEqual(coordinated.state, direct.state)
        }
    }

    // E5：读数模型同时暴露照片、视口宽高比和实际双击目标倍数。
    func testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1.5,
            configuration: configuration
        )

        XCTAssertEqual(value.assetAspectRatio, 1.5, accuracy: 0.000_001)
        XCTAssertEqual(value.viewportAspectRatio, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(value.aspectFillMultiplier, 3, accuracy: 0.000_001)
        XCTAssertEqual(value.doubleTapTargetScale, 3, accuracy: 0.000_001)
    }

    // E6：打开实时读数时关闭长参数面板，避免读数被挤出可见区域。
    func testE6ReadingsAndParameterPanelsAreMutuallyExclusive() {
        var state = S2CalibrationOverlayState.initial
        state.toggleAccessControls()
        state.toggleParameterPanel()
        XCTAssertTrue(state.parameterPanelVisible)

        state.toggleReadings()
        XCTAssertFalse(state.parameterPanelVisible)
        XCTAssertTrue(state.readingsVisible)

        state.toggleParameterPanel()
        XCTAssertTrue(state.parameterPanelVisible)
        XCTAssertFalse(state.readingsVisible)
    }

    // N1：主图使用原生可缩放容器，倍率上下限分别为 1 与 pinchMaxScale。
    func testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let scrollView = makeNativeZoomScrollView(configuration: configuration)

        XCTAssertTrue(scrollView is UIScrollView)
        XCTAssertEqual(scrollView.minimumZoomScale, 1)
        XCTAssertEqual(
            scrollView.maximumZoomScale,
            CGFloat(configuration.pinchMaxScale),
            accuracy: 0.000_001
        )
    }

    // N2 替代断言：双击调用原生 zoom(to:)，目标矩形采用分类后的目标倍数。
    func testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1.5,
            configuration: configuration
        )
        let expected = value.aspectFillMultiplier
        XCTAssertEqual(value.doubleTapTargetScale, expected, accuracy: 0.000_001)
        let scrollView = makeNativeZoomScrollView(configuration: configuration)
        let rect = tryUnwrap(scrollView.performDoubleTapZoom(
            at: CGPoint(x: 40, y: 80),
            targetScale: expected,
            animated: false
        ))

        XCTAssertEqual(scrollView.nativeZoomInvocationCount, 1)
        XCTAssertEqual(scrollView.lastNativeZoomRect, rect)
        XCTAssertEqual(
            tryUnwrap(scrollView.requestedScale(for: rect)),
            expected,
            accuracy: 0.000_001
        )
    }

    // N3：原生分页已开启，相邻分页单元间距等于 pageSpacing。
    func testN3NativePagingUsesConfiguredPageSpacing() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let paging = makeNativePagingScrollView(configuration: configuration)
        let first = paging.frameForPage(at: 0)
        let second = paging.frameForPage(at: 1)

        XCTAssertTrue(paging is UIScrollView)
        XCTAssertTrue(paging.isPagingEnabled)
        XCTAssertEqual(
            second.minX - first.maxX,
            CGFloat(configuration.pageSpacing),
            accuracy: 0.000_001
        )
    }

    // N4：pageSpacing 出厂值与参数导出均为 20。
    func testN4PageSpacingFactoryDefaultIsTwentyPoints() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder

        XCTAssertEqual(configuration.pageSpacing, 20)
        XCTAssertTrue(
            configuration.exportText().contains("pageSpacing=20.000000")
        )
    }

    // N5：Nx 单击只切换显隐，不改变原生或状态机视口。
    func testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport() {
        let originalOffset = CGSize(width: 24, height: 16)
        let machine = makeMachine(scale: 2, viewportOffset: originalOffset)
        let scrollView = makeNativeZoomScrollView()
        scrollView.applyNativeState(scale: 2, viewportOffset: originalOffset)
        let nativeScale = scrollView.zoomScale
        let nativeOffset = scrollView.contentOffset

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.scale, 2)
        XCTAssertEqual(machine.viewportOffset, originalOffset)
        XCTAssertEqual(scrollView.zoomScale, nativeScale)
        XCTAssertEqual(scrollView.contentOffset, nativeOffset)
    }

    // N6：1x 单击继续切换界面显隐。
    func testN6OneXSingleTapTogglesInterfaceVisibility() {
        let machine = makeMachine(scale: 1)

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
    }

    // N7：原生分页落到新照片时，状态机缩放与偏移归一。
    func testN7NativePageChangeResetsZoomToOne() {
        let machine = makeMachine(
            scale: 2,
            viewportOffset: CGSize(width: 24, height: 16)
        )

        XCTAssertTrue(machine.handleNativePageChange(to: 2))
        XCTAssertEqual(machine.currentIndex, 2)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
        XCTAssertEqual(machine.imageRequestScale, 1)
    }

    // N8：原生捏合过程中不请求，结束后只发出一次请求修订。
    func testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd() {
        let machine = makeMachine()

        XCTAssertTrue(machine.beginPinch())
        machine.reportNativeViewport(scale: 1.2, viewportOffset: .zero)
        machine.reportNativeViewport(
            scale: 1.8,
            viewportOffset: CGSize(width: 20, height: 10)
        )
        XCTAssertEqual(machine.imageRequestRevision, 0)
        XCTAssertEqual(machine.imageRequestScale, 1)

        let finalScale = tryUnwrap(machine.finishNativePinch(
            scale: 1.8,
            viewportOffset: CGSize(width: 20, height: 10),
            accepted: true
        ))
        XCTAssertEqual(finalScale, 1.8, accuracy: 0.000_001)
        XCTAssertEqual(machine.imageRequestRevision, 1)
        XCTAssertEqual(machine.imageRequestAssetID, machine.currentAssetID)
        XCTAssertEqual(machine.imageRequestScale, 1.8, accuracy: 0.000_001)
    }

    // G1：1x 上滑达到既有阈值后标记触摸开始时的当前资产。
    func testG1OneXSwipeUpMarksCurrentAsset() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let originalAssetID = machine.currentAssetID
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertEqual(configuration.verticalSwipeDistance, 40)
        XCTAssertEqual(configuration.verticalSwipeVelocity, 100)
        XCTAssertTrue(page.nativeScrollPriorityIsConfigured)
        XCTAssertTrue(controller.finishVerticalSwipe(
            on: page,
            translation: CGSize(width: 0, height: -40),
            duration: 0.4
        ))
        XCTAssertTrue(machine.pendingDeletionAssetIDs.contains(originalAssetID))
    }

    // G2：Nx 上滑采用同一阈值，标记后切片并归一为 1x。
    func testG2NxSwipeUpMarksCurrentAsset() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(scale: 2, configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let originalAssetID = machine.currentAssetID
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(controller.finishVerticalSwipe(
            on: page,
            translation: CGSize(width: 0, height: -40),
            duration: 0.4
        ))
        XCTAssertTrue(machine.pendingDeletionAssetIDs.contains(originalAssetID))
        XCTAssertEqual(machine.scale, 1)
    }

    // G3 替代断言：原生双击不执行也不撤销任何单击显隐动作。
    func testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap() {
        let targetScale = metrics().doubleTapTargetScale
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let initialVisibility = machine.interfaceVisibility

        XCTAssertEqual(page.singleTapRecognizer.numberOfTapsRequired, 1)
        XCTAssertEqual(page.doubleTapRecognizer.numberOfTapsRequired, 2)
        XCTAssertTrue(
            page.singleTapRecognizer.requiredDoubleTapRecognizer ===
                page.doubleTapRecognizer
        )
        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: 150, y: 300)
        ))
        XCTAssertEqual(machine.scale, targetScale, accuracy: 0.000_001)
        XCTAssertEqual(machine.interfaceVisibility, initialVisibility)
    }

    // G4 替代断言：两次由 UIKit 分别裁决的单击切换两次且不改倍率。
    func testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.scale, 1)
    }

    // M1：命中屏幕比例内缩判定时，双击只采用最小目标倍数。
    func testM1ScreenAspectDoubleTapUsesMinimumScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = metrics(configuration: configuration)
        let machine = makeMachine(configuration: configuration)
        let legacyMachine = makeMachine(configuration: configuration)

        XCTAssertTrue(machine.handleNativeDoubleTap(
            targetScale: value.doubleTapTargetScale
        ))
        XCTAssertEqual(
            machine.scale,
            CGFloat(configuration.minDoubleTapScale),
            accuracy: 0.000_001
        )
        XCTAssertTrue(legacyMachine.handleDoubleTap(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            viewportSize: physicalSize,
            assetAspectRatio: screenAspectRatio
        ))
        XCTAssertEqual(
            legacyMachine.scale,
            CGFloat(configuration.minDoubleTapScale),
            accuracy: 0.000_001
        )
    }

    // M2：未命中屏幕比例判定时，双击只采用填满视口倍数。
    func testM2NonScreenPhotoDoubleTapUsesAspectFillScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1,
            configuration: configuration
        )
        let machine = makeMachine(configuration: configuration)
        let legacyMachine = makeMachine(configuration: configuration)

        XCTAssertTrue(machine.handleNativeDoubleTap(
            targetScale: value.doubleTapTargetScale
        ))
        XCTAssertEqual(
            machine.scale,
            value.aspectFillMultiplier,
            accuracy: 0.000_001
        )
        XCTAssertNotEqual(
            machine.scale,
            CGFloat(configuration.minDoubleTapScale),
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            value.aspectFillMultiplier,
            CGFloat(configuration.minDoubleTapScale)
        )
        XCTAssertTrue(legacyMachine.handleDoubleTap(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            viewportSize: physicalSize,
            assetAspectRatio: 1
        ))
        XCTAssertEqual(
            legacyMachine.scale,
            value.aspectFillMultiplier,
            accuracy: 0.000_001
        )
    }

    // F1：0.30 内缩令屏幕比例照片的 1x 短边等于视口短边的 0.70。
    func testF1FactoryInsetShrinksShortEdgeToSeventyPercent() {
        let value = metrics()

        XCTAssertEqual(
            min(value.oneXDisplaySize.width, value.oneXDisplaySize.height),
            min(value.viewportSize.width, value.viewportSize.height) * 0.70,
            accuracy: 1
        )
    }

    // F2：命中内缩时应用参数圆角，未命中时圆角严格为零。
    func testF2CornerRadiusAppliesOnlyToInsetPhotos() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let matching = metrics(configuration: configuration)
        let nonMatching = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1,
            configuration: configuration
        )
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertEqual(
            matching.oneXCornerRadius,
            CGFloat(configuration.fitCornerRadius)
        )
        XCTAssertEqual(nonMatching.oneXCornerRadius, 0)
        XCTAssertEqual(
            page.zoomScrollView.zoomContentView?.layer.cornerRadius,
            CGFloat(configuration.fitCornerRadius)
        )
    }

    // F3 替代断言：非框显照片在界面显隐前后的尺寸与圆角完全一致。
    func testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let visible = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: 1,
            configuration: configuration
        )
        let hidden = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .hidden,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: 1,
            configuration: configuration
        )

        XCTAssertFalse(visible.isFramedPhoto)
        XCTAssertEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)
        XCTAssertEqual(hidden.oneXCornerRadius, visible.oneXCornerRadius)
    }

    // F4：内缩只改变 1x 显示尺寸，不改变视口或填满倍数基准。
    func testF4InsetDoesNotChangeViewportOrAspectFillMultiplier() {
        var withoutInset = S2CalibrationConfiguration.factoryPlaceholder
        withoutInset.fitInsetRatio = 0
        let plain = metrics(configuration: withoutInset)
        let inset = metrics()

        XCTAssertNotEqual(plain.oneXDisplaySize, inset.oneXDisplaySize)
        XCTAssertEqual(plain.viewportSize, inset.viewportSize)
        XCTAssertEqual(
            plain.aspectFillMultiplier,
            inset.aspectFillMultiplier,
            accuracy: 0.000_001
        )
    }

    // B1：Nx 内容到边界后，继续拖动的溢出量等量带动外层分页。
    func testB1NxBoundaryContinuationProducesPagingDisplacement() {
        let interaction = S2NxEdgePagingInteraction(
            restingPagingOffsetX: 320,
            pageStride: 320,
            translationOriginX: 0,
            distanceToPreviousBoundary: 0,
            distanceToNextBoundary: 0
        )
        let projection = interaction.projection(translationX: -60)

        XCTAssertEqual(projection.direction, .next)
        XCTAssertEqual(projection.overflowDistance, 60)
        XCTAssertEqual(projection.pagingContentOffsetX, 380)
    }

    // B2：Nx 边界翻页未同时达到距离与速度阈值时回弹且 c 不变。
    func testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex() {
        let machine = makeMachine(scale: 2)
        let originalIndex = machine.currentIndex

        XCTAssertFalse(machine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: 39,
            velocity: 299
        ))
        XCTAssertEqual(machine.currentIndex, originalIndex)
        XCTAssertEqual(machine.scale, 2)
    }

    // B3：Nx 边界翻页完成后，新照片倍率严格归一为 1。
    func testB3NxBoundaryPagingCompletionResetsNewPhotoScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(scale: 2, configuration: configuration)

        XCTAssertTrue(machine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: CGFloat(configuration.edgePagingTriggerDistance),
            velocity: CGFloat(configuration.edgePagingTriggerVelocity)
        ))
        XCTAssertEqual(machine.currentIndex, 2)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
    }

    // H1 替代断言：开启参数时也只有缩略图拖动换片发出触觉。
    func testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges() {
        var hapticCount = 0
        let feedback = S2PhotoSwitchHapticFeedback {
            hapticCount += 1
        }
        let configuration = S2CalibrationConfiguration.factoryPlaceholder

        let stripMachine = makeMachine(configuration: configuration)
        XCTAssertTrue(stripMachine.beginBottomStripDrag())
        XCTAssertTrue(S2BottomStripPhotoSwitcher.switchPhoto(
            machine: stripMachine,
            by: 1,
            onPhotoSwitch: {
                feedback.notify(
                    isEnabled: configuration.hapticOnPhotoSwitch,
                    source: .bottomStripDrag
                )
            }
        ))
        XCTAssertEqual(hapticCount, 1)

        let pagingMachine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: pagingMachine,
            configuration: configuration
        )
        controller.pagingScrollView.contentOffset = controller
            .pagingScrollView.contentOffsetForPage(at: 2)
        controller.scrollViewDidEndDecelerating(
            controller.pagingScrollView
        )
        XCTAssertEqual(hapticCount, 1)
        controller.scrollViewDidEndDecelerating(
            controller.pagingScrollView
        )
        XCTAssertEqual(hapticCount, 1)

        controller.pagingScrollView.contentOffset = controller
            .pagingScrollView.contentOffsetForPage(at: 1)
        controller.scrollViewDidEndDecelerating(
            controller.pagingScrollView
        )
        XCTAssertEqual(hapticCount, 1)
        controller.scrollViewDidEndDecelerating(
            controller.pagingScrollView
        )
        XCTAssertEqual(hapticCount, 1)
    }

    // H2 替代断言：关闭参数后缩略图变化也不发触觉。
    func testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.hapticOnPhotoSwitch = false
        var hapticCount = 0
        let feedback = S2PhotoSwitchHapticFeedback {
            hapticCount += 1
        }

        let stripMachine = makeMachine(configuration: configuration)
        XCTAssertTrue(stripMachine.beginBottomStripDrag())
        XCTAssertTrue(S2BottomStripPhotoSwitcher.switchPhoto(
            machine: stripMachine,
            by: 1,
            onPhotoSwitch: {
                feedback.notify(
                    isEnabled: configuration.hapticOnPhotoSwitch,
                    source: .bottomStripDrag
                )
            }
        ))

        let pagingMachine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: pagingMachine,
            configuration: configuration
        )
        controller.pagingScrollView.contentOffset = controller
            .pagingScrollView.contentOffsetForPage(at: 2)
        controller.scrollViewDidEndDecelerating(
            controller.pagingScrollView
        )
        XCTAssertEqual(hapticCount, 0)
    }

    // K1：单击识别器显式等待双击识别器失败。
    func testK1SingleTapRequiresDoubleTapRecognizerToFail() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(
            page.singleTapRecognizer.requiredDoubleTapRecognizer ===
                page.doubleTapRecognizer
        )
        XCTAssertTrue(
            page.singleTapRecognizer.view === page.doubleTapRecognizer.view
        )
        XCTAssertEqual(page.singleTapRecognizer.numberOfTapsRequired, 1)
        XCTAssertEqual(page.doubleTapRecognizer.numberOfTapsRequired, 2)
    }

    // K2：双击全程不切换显隐，最终倍率等于分类后的目标倍数。
    func testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale() {
        for visibility in [
            S2InterfaceVisibility.visible,
            S2InterfaceVisibility.hidden
        ] {
            let machine = makeMachine(interfaceVisibility: visibility)
            let controller = makeNativePagerController(machine: machine)
            let page = tryUnwrap(
                controller.pageControllers[machine.currentIndex]
            )
            let targetScale = page.doubleTapTargetScale

            XCTAssertEqual(machine.interfaceVisibility, visibility)
            XCTAssertTrue(page.applyRecognizedDoubleTap(
                at: CGPoint(x: 150, y: 300)
            ))
            XCTAssertEqual(machine.interfaceVisibility, visibility)
            XCTAssertEqual(machine.scale, targetScale, accuracy: 0.000_001)

            let exitMachine = makeMachine(
                scale: targetScale,
                interfaceVisibility: visibility
            )
            let exitController = makeNativePagerController(
                machine: exitMachine
            )
            let exitPage = tryUnwrap(
                exitController.pageControllers[exitMachine.currentIndex]
            )
            XCTAssertTrue(exitMachine.handleSingleTap())
            let visibilityBeforeExit = exitMachine.interfaceVisibility
            XCTAssertTrue(exitPage.applyRecognizedDoubleTap(
                at: CGPoint(x: 150, y: 300)
            ))
            XCTAssertEqual(
                exitMachine.interfaceVisibility,
                visibilityBeforeExit
            )
            XCTAssertEqual(exitMachine.scale, 1)
        }
    }

    // K3：UIKit 宣告双击失败后，单击回调只切换一次显隐。
    func testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(
            page.singleTapRecognizer.requiredDoubleTapRecognizer ===
                page.doubleTapRecognizer
        )
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.scale, 1)
    }

    // K4：双击裁决诊断目标出厂值为 200 毫秒并实际参与达标判断。
    func testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let policy = S2TapDecisionDiagnosticPolicy(
            configuration: configuration
        )

        XCTAssertEqual(configuration.doubleTapDecisionWindowMilliseconds, 200)
        XCTAssertTrue(configuration.exportText().contains(
            "doubleTapDecisionWindowMilliseconds=200.000000"
        ))
        XCTAssertTrue(
            policy.reading(latencyMilliseconds: 199).metConfiguredTarget
        )
        XCTAssertFalse(
            policy.reading(latencyMilliseconds: 201).metConfiguredTarget
        )

        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        XCTAssertTrue(page.applyRecognizedSingleTap(
            decisionLatencyMilliseconds: 201
        ))
        XCTAssertEqual(machine.lastTapDecisionReading?.targetMilliseconds, 200)
        XCTAssertEqual(
            machine.lastTapDecisionReading?.metConfiguredTarget,
            false
        )
    }

    // S1：框显照片在显示态使用 70% 短边和 28 点圆角。
    func testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight() {
        let value = metrics(visibility: .visible)

        XCTAssertTrue(value.isFramedPhoto)
        XCTAssertEqual(
            min(value.oneXDisplaySize.width, value.oneXDisplaySize.height),
            min(value.viewportSize.width, value.viewportSize.height) * 0.70,
            accuracy: 1
        )
        XCTAssertEqual(value.oneXCornerRadius, 28, accuracy: 0.000_001)
    }

    // S2：框显照片隐藏后等比适配到视口边界、无裁切且圆角归零。
    func testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let hidden = metrics(
            visibility: .hidden,
            configuration: configuration
        )

        XCTAssertTrue(hidden.isFramedPhoto)
        XCTAssertEqual(hidden.oneXDisplaySize, hidden.aspectFitSize)
        XCTAssertLessThanOrEqual(
            hidden.oneXDisplaySize.width,
            hidden.viewportSize.width
        )
        XCTAssertLessThanOrEqual(
            hidden.oneXDisplaySize.height,
            hidden.viewportSize.height
        )
        XCTAssertTrue(
            abs(hidden.oneXDisplaySize.width - hidden.viewportSize.width) <
                0.000_001 ||
                abs(hidden.oneXDisplaySize.height - hidden.viewportSize.height) <
                0.000_001
        )
        XCTAssertEqual(hidden.oneXCornerRadius, 0)

        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let visible = metrics(
            visibility: .visible,
            configuration: configuration
        )
        XCTAssertTrue(page.isPresentationTransitionActive)
        XCTAssertEqual(page.fittedSize, visible.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, visible.oneXCornerRadius)
        XCTAssertEqual(
            page.lastPresentationTransitionDuration,
            0.18,
            accuracy: 0.000_001
        )
        page.finishActivePresentationTransition()
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, 0)

        var directConfiguration = configuration
        directConfiguration.animationsEnabled = false
        let directMachine = makeMachine(configuration: directConfiguration)
        let directController = makeNativePagerController(
            machine: directMachine,
            configuration: directConfiguration
        )
        XCTAssertTrue(directMachine.handleSingleTap())
        applyNativePagerController(
            directController,
            machine: directMachine,
            configuration: directConfiguration
        )
        let directPage = tryUnwrap(
            directController.pageControllers[directMachine.currentIndex]
        )
        XCTAssertEqual(directPage.lastPresentationTransitionDuration, 0)
    }

    // S3：非框显照片在显示态与隐藏态的尺寸及圆角严格相等。
    func testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let visible = nonFramedMetrics(
            visibility: .visible,
            configuration: configuration
        )
        let hidden = nonFramedMetrics(
            visibility: .hidden,
            configuration: configuration
        )

        XCTAssertFalse(visible.isFramedPhoto)
        XCTAssertFalse(hidden.isFramedPhoto)
        XCTAssertEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)
        XCTAssertEqual(hidden.oneXCornerRadius, visible.oneXCornerRadius)
    }

    // S4：截图沉浸显隐不改变视口、填满倍数或双击目标倍数。
    func testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget() {
        let visible = metrics(visibility: .visible)
        let hidden = metrics(visibility: .hidden)

        XCTAssertNotEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)
        XCTAssertEqual(hidden.viewportSize, visible.viewportSize)
        XCTAssertEqual(
            hidden.aspectFillMultiplier,
            visible.aspectFillMultiplier,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            hidden.doubleTapTargetScale,
            visible.doubleTapTargetScale,
            accuracy: 0.000_001
        )
    }

    // S5：关闭截图沉浸后，隐藏态继续保持手机框尺寸与圆角。
    func testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.screenshotImmersiveOnHide = false
        let visible = metrics(
            visibility: .visible,
            configuration: configuration
        )
        let hidden = metrics(
            visibility: .hidden,
            configuration: configuration
        )

        XCTAssertEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)
        XCTAssertEqual(hidden.oneXCornerRadius, visible.oneXCornerRadius)
        XCTAssertEqual(hidden.oneXCornerRadius, 28, accuracy: 0.000_001)
    }

    // S6：截图沉浸开关出厂值为开启并进入参数导出。
    func testS6ScreenshotImmersiveFactoryDefaultIsTrue() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder

        XCTAssertTrue(configuration.screenshotImmersiveOnHide)
        XCTAssertTrue(configuration.exportText().contains(
            "screenshotImmersiveOnHide=true"
        ))
    }

    // X1：缩放变换的实际锚点固定在物理视口中心。
    func testX1ImmersiveTransitionUsesViewportCenterAnchoredScaleTransform() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )

        let transition = tryUnwrap(page.lastPresentationTransition)
        let actualAnchor = tryUnwrap(
            page.zoomScrollView.presentationAnchorInViewport()
        )
        XCTAssertEqual(
            transition.viewportAnchor,
            CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2)
        )
        XCTAssertEqual(actualAnchor.x, transition.viewportAnchor.x, accuracy: 0.000_001)
        XCTAssertEqual(actualAnchor.y, transition.viewportAnchor.y, accuracy: 0.000_001)
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.layer.anchorPoint,
            CGPoint(x: 0.5, y: 0.5)
        )
        XCTAssertNotEqual(transition.targetScale, 1, accuracy: 0.000_001)
        page.finishActivePresentationTransition()

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )
        let reverseTransition = tryUnwrap(page.lastPresentationTransition)
        let reverseAnchor = tryUnwrap(
            page.zoomScrollView.presentationAnchorInViewport()
        )
        XCTAssertLessThan(reverseTransition.targetScale, 1)
        XCTAssertEqual(
            reverseTransition.viewportAnchor,
            transition.viewportAnchor
        )
        XCTAssertEqual(reverseAnchor.x, transition.viewportAnchor.x, accuracy: 0.000_001)
        XCTAssertEqual(reverseAnchor.y, transition.viewportAnchor.y, accuracy: 0.000_001)
        page.finishActivePresentationTransition()
    }

    // X2：动画区间内布局尺寸不变，尺寸差仅由等比变换承担。
    func testX2ImmersiveTransitionKeepsLayoutSizeAndUsesTransform() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let layoutSize = page.fittedSize
        let contentSize = page.zoomScrollView.contentSize
        let presentationBounds = tryUnwrap(
            page.zoomScrollView.presentationContentView
        ).bounds.size

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )

        let transition = tryUnwrap(page.lastPresentationTransition)
        let transform = tryUnwrap(
            page.zoomScrollView.presentationContentView
        ).transform
        XCTAssertTrue(page.isPresentationTransitionActive)
        XCTAssertEqual(page.fittedSize, layoutSize)
        XCTAssertEqual(page.zoomScrollView.fittedSize, layoutSize)
        XCTAssertEqual(page.zoomScrollView.contentSize, contentSize)
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.bounds.size,
            presentationBounds
        )
        XCTAssertEqual(transform.a, transition.targetScale, accuracy: 0.000_001)
        XCTAssertEqual(transform.d, transition.targetScale, accuracy: 0.000_001)
        XCTAssertEqual(transform.b, 0, accuracy: 0.000_001)
        XCTAssertEqual(transform.c, 0, accuracy: 0.000_001)
        page.finishActivePresentationTransition()
    }

    // X3：圆角与缩放共用线性进度，两个方向的端点和中点连续。
    func testX3CornerRadiusInterpolatesContinuouslyInBothDirections() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        let hiding = tryUnwrap(page.lastPresentationTransition)
        XCTAssertEqual(
            hiding.frame(at: 0).cornerRadius,
            CGFloat(configuration.fitCornerRadius),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            hiding.frame(at: 0.5).cornerRadius,
            CGFloat(configuration.fitCornerRadius) / 2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(hiding.frame(at: 1).cornerRadius, 0)
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.layer.cornerRadius,
            0
        )
        page.finishActivePresentationTransition()

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        let showing = tryUnwrap(page.lastPresentationTransition)
        XCTAssertEqual(showing.frame(at: 0).cornerRadius, 0)
        XCTAssertEqual(
            showing.frame(at: 0.5).cornerRadius,
            CGFloat(configuration.fitCornerRadius) / 2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            showing.frame(at: 1).cornerRadius,
            CGFloat(configuration.fitCornerRadius),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.layer.cornerRadius ?? 0,
            showing.layerCornerRadius(at: 1),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            showing.layerCornerRadius(at: 1) * showing.targetScale,
            CGFloat(configuration.fitCornerRadius),
            accuracy: 0.000_001
        )
        page.finishActivePresentationTransition()
    }

    // X4：关闭动画后不保留任何过渡态，目标几何一次到位。
    func testX4DisabledAnimationsReachEndpointWithoutTransition() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.animationsEnabled = false
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let hidden = metrics(
            visibility: .hidden,
            configuration: configuration
        )

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )

        XCTAssertFalse(page.isPresentationTransitionActive)
        XCTAssertFalse(page.hasDeferredPresentation)
        XCTAssertEqual(page.lastPresentationTransitionDuration, 0)
        XCTAssertEqual(page.presentationTransitionCount, 0)
        XCTAssertEqual(page.presentationGeometryCommitCount, 1)
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, hidden.oneXCornerRadius)
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.transform,
            .identity
        )
    }

    // X5：Nx 显隐切换前后五项原生几何量及照片可见框严格相等。
    func testX5NxVisibilityTogglePreservesAllNativeGeometry() {
        let originalOffset = CGSize(width: 24, height: 16)
        let machine = makeMachine(
            scale: 2,
            viewportOffset: originalOffset
        )
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let zoomScale = page.zoomScrollView.zoomScale
        let contentOffset = page.zoomScrollView.contentOffset
        let contentSize = page.zoomScrollView.contentSize
        let viewportSize = page.zoomScrollView.bounds.size
        let visibleFrame = page.zoomScrollView.visibleContentFrame()
        let presentationFrame = page.zoomScrollView.visiblePresentationFrame()
        let fittedSize = page.fittedSize
        let cornerRadius = page.cornerRadius

        XCTAssertGreaterThan(zoomScale, 1)
        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )

        XCTAssertEqual(page.zoomScrollView.zoomScale, zoomScale)
        XCTAssertEqual(page.zoomScrollView.contentOffset, contentOffset)
        XCTAssertEqual(page.zoomScrollView.contentSize, contentSize)
        XCTAssertEqual(page.zoomScrollView.bounds.size, viewportSize)
        XCTAssertEqual(page.zoomScrollView.visibleContentFrame(), visibleFrame)
        XCTAssertEqual(
            page.zoomScrollView.visiblePresentationFrame(),
            presentationFrame
        )
        XCTAssertEqual(page.fittedSize, fittedSize)
        XCTAssertEqual(page.cornerRadius, cornerRadius)
        XCTAssertTrue(page.hasDeferredPresentation)
        XCTAssertEqual(page.presentationTransitionCount, 0)
    }

    // X6：Nx 延迟目标在实际回到 1x 后只提交一次并达到当前显隐端点。
    func testX6NxDeferredPresentationAppliesOnceAfterReturningToOneX() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            scale: 2,
            viewportOffset: CGSize(width: 24, height: 16),
            configuration: configuration
        )
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let visible = metrics(
            visibility: .visible,
            configuration: configuration
        )
        let hidden = metrics(
            visibility: .hidden,
            configuration: configuration
        )

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        XCTAssertGreaterThan(page.zoomScrollView.zoomScale, 1)
        XCTAssertTrue(page.hasDeferredPresentation)
        XCTAssertEqual(page.fittedSize, visible.oneXDisplaySize)

        XCTAssertTrue(machine.handleNativeDoubleTap(
            targetScale: page.doubleTapTargetScale
        ))
        page.zoomScrollView.setZoomScale(1, animated: false)
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )

        let transition = tryUnwrap(page.lastPresentationTransition)
        XCTAssertTrue(page.isPresentationTransitionActive)
        XCTAssertEqual(page.fittedSize, visible.oneXDisplaySize)
        XCTAssertEqual(page.presentationTransitionCount, 1)
        XCTAssertEqual(page.presentationGeometryCommitCount, 0)
        XCTAssertNotEqual(transition.targetScale, 1, accuracy: 0.000_001)
        page.finishActivePresentationTransition()

        XCTAssertFalse(page.isPresentationTransitionActive)
        XCTAssertFalse(page.hasDeferredPresentation)
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, hidden.oneXCornerRadius)
        XCTAssertEqual(page.zoomScrollView.contentSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.presentationGeometryCommitCount, 1)

        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        XCTAssertEqual(page.presentationTransitionCount, 1)
        XCTAssertEqual(page.presentationGeometryCommitCount, 1)
    }

    // X7：Nx 未切换显隐时，退出只执行既有缩放归一，不新增呈现提交。
    func testX7NxExitWithoutVisibilityToggleKeepsExistingBehavior() {
        let machine = makeMachine(
            scale: 2,
            viewportOffset: CGSize(width: 24, height: 16)
        )
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let visible = metrics(visibility: .visible)

        XCTAssertTrue(machine.handleNativeDoubleTap(
            targetScale: page.doubleTapTargetScale
        ))
        page.zoomScrollView.setZoomScale(1, animated: false)
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )

        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
        XCTAssertEqual(page.zoomScrollView.zoomScale, 1)
        XCTAssertFalse(page.hasDeferredPresentation)
        XCTAssertFalse(page.isPresentationTransitionActive)
        XCTAssertNil(page.lastPresentationTransition)
        XCTAssertEqual(page.presentationTransitionCount, 0)
        XCTAssertEqual(page.presentationGeometryCommitCount, 0)
        XCTAssertEqual(page.fittedSize, visible.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, visible.oneXCornerRadius)
    }

    // X8：过渡未结束前不替换照片内容，真实图像请求计数保持为零。
    func testX8ImmersiveAnimationIssuesZeroImageRequests() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.animationDurationMilliseconds = 1_000
        let requestCounter = S2ImageRequestCounter()
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            photoContent: { assetID, size, requestedScale, requestRevision in
                AnyView(
                    S2TemporaryPhotoImageView(
                        strategy: requestCounter,
                        assetID: assetID,
                        requestedScale: requestedScale,
                        requestStrategy: configuration.imageRequestStrategy,
                        requestRevision: requestRevision,
                        showsOpaqueLoadingBackground: true,
                        onReading: { _ in }
                    )
                    .frame(width: size.width, height: size.height)
                )
            }
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertGreaterThan(requestCounter.requestCount, 0)
        requestCounter.reset()

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            photoContent: { assetID, size, requestedScale, requestRevision in
                AnyView(
                    S2TemporaryPhotoImageView(
                        strategy: requestCounter,
                        assetID: assetID,
                        requestedScale: requestedScale,
                        requestStrategy: configuration.imageRequestStrategy,
                        requestRevision: requestRevision,
                        showsOpaqueLoadingBackground: true,
                        onReading: { _ in }
                    )
                    .frame(width: size.width, height: size.height)
                )
            }
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        XCTAssertTrue(page.isPresentationTransitionActive)
        XCTAssertEqual(requestCounter.requestCount, 0)
        controller.pageControllers.values.forEach {
            $0.finishActivePresentationTransition()
        }
        window.isHidden = true
    }

    // 图像请求回归：Nx 无显隐几何变化时，捏合结束请求仍按既有策略执行。
    func testIC061NxPinchEndedStillUpdatesImageRequestWithoutPresentationChange() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let requestCounter = S2ImageRequestCounter()
        let machine = makeMachine(scale: 2, configuration: configuration)
        let content: (String, CGSize, CGFloat, Int) -> AnyView = {
            assetID,
            size,
            requestedScale,
            requestRevision in
            AnyView(
                S2TemporaryPhotoImageView(
                    strategy: requestCounter,
                    assetID: assetID,
                    requestedScale: requestedScale,
                    requestStrategy: configuration.imageRequestStrategy,
                    requestRevision: requestRevision,
                    showsOpaqueLoadingBackground: true,
                    onReading: { _ in }
                )
                .frame(width: size.width, height: size.height)
            )
        }
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            photoContent: content
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        requestCounter.reset()

        XCTAssertTrue(machine.beginPinch())
        XCTAssertNotNil(machine.finishNativePinch(
            scale: 2,
            viewportOffset: CGSize(width: 24, height: 16),
            accepted: true
        ))
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            photoContent: content
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(requestCounter.requestCount, 1)
        window.isHidden = true
    }

    // A1：原生左右分页成功切换照片时触觉调用次数仍为零。
    func testA1NativePagingPhotoSwitchProducesNoHaptic() {
        var hapticCount = 0
        let feedback = S2PhotoSwitchHapticFeedback {
            hapticCount += 1
        }
        feedback.notify(isEnabled: true, source: .nativePaging)

        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        controller.pagingScrollView.contentOffset = controller
            .pagingScrollView.contentOffsetForPage(at: 2)
        controller.scrollViewDidEndDecelerating(controller.pagingScrollView)

        XCTAssertEqual(machine.currentIndex, 2)
        XCTAssertEqual(hapticCount, 0)
    }

    // A2：缩略图拖动每跨过一张当前项就恰好触发一次触觉。
    func testA2BottomStripCurrentItemChangesProduceExactlyNHaptics() {
        let assets = (1...8).map { "asset-\($0)" }
        let machine = makeMachine(
            orderedAssetIDs: assets,
            currentIndex: 0
        )
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        var hapticCount = 0
        let feedback = S2PhotoSwitchHapticFeedback {
            hapticCount += 1
        }
        let expectedChanges = 5

        XCTAssertTrue(machine.beginBottomStripDrag())
        for _ in 0..<expectedChanges {
            XCTAssertTrue(S2BottomStripPhotoSwitcher.switchPhoto(
                machine: machine,
                by: 1,
                onPhotoSwitch: {
                    feedback.notify(
                        isEnabled: configuration.hapticOnPhotoSwitch,
                        source: .bottomStripDrag
                    )
                }
            ))
        }

        XCTAssertEqual(machine.currentIndex, expectedChanges)
        XCTAssertEqual(hapticCount, expectedChanges)
    }

    // A3：关闭触觉参数后，任何照片切换来源都不会触发触觉。
    func testA3DisabledPhotoSwitchHapticProducesNoHaptic() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.hapticOnPhotoSwitch = false
        var hapticCount = 0
        let feedback = S2PhotoSwitchHapticFeedback {
            hapticCount += 1
        }
        let machine = makeMachine(configuration: configuration)

        XCTAssertTrue(machine.beginBottomStripDrag())
        XCTAssertTrue(S2BottomStripPhotoSwitcher.switchPhoto(
            machine: machine,
            by: 1,
            onPhotoSwitch: {
                feedback.notify(
                    isEnabled: configuration.hapticOnPhotoSwitch,
                    source: .bottomStripDrag
                )
            }
        ))
        feedback.notify(
            isEnabled: configuration.hapticOnPhotoSwitch,
            source: .nativePaging
        )

        XCTAssertEqual(hapticCount, 0)
    }

    // 动画回归：统一策略在关闭开关时把显式时长归零。
    func testIC055AnimationPolicyDisablesCalibratedAnimations() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        let enabled = S2AnimationPolicy(configuration: configuration)
        XCTAssertTrue(enabled.shouldAnimate)
        XCTAssertEqual(enabled.durationSeconds, 0.18, accuracy: 0.000_001)

        configuration.animationsEnabled = false
        let disabled = S2AnimationPolicy(configuration: configuration)
        XCTAssertFalse(disabled.shouldAnimate)
        XCTAssertEqual(disabled.durationSeconds, 0)
    }

    private let physicalSize = CGSize(width: 300, height: 600)
    private let overlayPhysicalSize = CGSize(width: 393, height: 852)
    private let overlaySafeAreaInsets = S2OverlaySafeAreaInsets(
        top: 59,
        leading: 0,
        bottom: 34,
        trailing: 0
    )

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    private var presentationState: S2ViewportPresentationState {
        S2ViewportPresentationState(
            interfaceVisibility: .visible,
            bottomStripState: .idle,
            sheetState: .closed
        )
    }

    private func metrics(
        visibility: S2InterfaceVisibility = .visible,
        strip: S2BottomStripState = .idle,
        sheet: S2SheetState = .closed,
        calibrationState: S2CalibrationOverlayState = .initial,
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> S2ViewportMetrics {
        S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: visibility,
                bottomStripState: strip,
                sheetState: sheet,
                calibrationState: calibrationState
            ),
            assetAspectRatio: screenAspectRatio,
            configuration: configuration
        )
    }

    private func nonFramedMetrics(
        visibility: S2InterfaceVisibility,
        configuration: S2CalibrationConfiguration
    ) -> S2ViewportMetrics {
        S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: visibility,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: 1,
            configuration: configuration
        )
    }

    private func overlaySnapshot(
        calibrationState: S2CalibrationOverlayState = .initial
    ) -> S2OverlayLayoutSnapshot {
        S2OverlayLayout.snapshot(
            physicalSize: overlayPhysicalSize,
            safeAreaInsets: overlaySafeAreaInsets,
            bottomStripHeight: 72,
            showsRecentAlbumAction: true,
            calibrationState: calibrationState
        )
    }

    private func makeMachine(
        scale: CGFloat = 1,
        viewportOffset: CGSize = .zero,
        interfaceVisibility: S2InterfaceVisibility = .visible,
        configuration: S2CalibrationConfiguration = .factoryPlaceholder,
        orderedAssetIDs: [String] = ["asset-1", "asset-2", "asset-3"],
        currentIndex: Int = 1
    ) -> S2StateMachine {
        let resolvedCurrentIndex = min(
            max(0, currentIndex),
            orderedAssetIDs.count - 1
        )
        return S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-054",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-054",
                    displayName: "测试范围",
                    totalAssetCount: orderedAssetIDs.count
                ),
                orderedAssetIDs: orderedAssetIDs,
                currentAssetID: orderedAssetIDs[resolvedCurrentIndex],
                pendingDeletionAssetIDs: [],
                sessionMergedPendingDeletionCountProvider: { 0 }
            ),
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: interfaceVisibility,
                scale: scale,
                viewportOffset: viewportOffset
            ),
            parameters: tryUnwrap(configuration.resolvedParameters),
            imageRequestStrategy: configuration.imageRequestStrategy,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in }
        )!
    }

    private func makeNativeZoomScrollView(
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> S2NativeZoomScrollView {
        let scrollView = S2NativeZoomScrollView(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        let delegate = S2NativeZoomTestDelegate()
        nativeZoomDelegates.append(delegate)
        scrollView.delegate = delegate
        let contentView = UIView()
        scrollView.configure(
            contentView: contentView,
            fittedSize: metrics(
                configuration: configuration
            ).oneXDisplaySize,
            maximumZoomScale: CGFloat(configuration.pinchMaxScale)
        )
        scrollView.layoutIfNeeded()
        scrollView.applyNativeState(scale: 1, viewportOffset: .zero)
        return scrollView
    }

    private func makeNativePagerController(
        machine: S2StateMachine,
        configuration: S2CalibrationConfiguration = .factoryPlaceholder,
        photoContent: ((String, CGSize, CGFloat, Int) -> AnyView)? = nil
    ) -> S2NativePagerViewController {
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            photoContent: photoContent
        )
        return controller
    }

    private func applyNativePagerController(
        _ controller: S2NativePagerViewController,
        machine: S2StateMachine,
        configuration: S2CalibrationConfiguration,
        photoContent: ((String, CGSize, CGFloat, Int) -> AnyView)? = nil
    ) {
        let state = S2ViewportPresentationState(
            interfaceVisibility: machine.interfaceVisibility,
            bottomStripState: machine.bottomStripState,
            sheetState: machine.sheetState
        )
        let pages = machine.orderedAssetIDs.enumerated().map { index, assetID in
            let value = S2ViewportLayout.metrics(
                physicalSize: physicalSize,
                presentationState: state,
                assetAspectRatio: screenAspectRatio,
                configuration: configuration
            )
            let requestedScale = index == machine.currentIndex
                ? machine.imageRequestScale
                : 1
            let requestRevision = machine.imageRequestAssetID == assetID
                ? machine.imageRequestRevision
                : 0
            let content = photoContent?(
                assetID,
                value.oneXDisplaySize,
                requestedScale,
                requestRevision
            ) ??
                AnyView(
                    Color.clear.frame(
                        width: value.oneXDisplaySize.width,
                        height: value.oneXDisplaySize.height
                    )
                )
            return S2NativePageContent(
                index: index,
                assetID: assetID,
                interfaceVisibility: machine.interfaceVisibility,
                isFramedPhoto: value.isFramedPhoto,
                fittedSize: value.oneXDisplaySize,
                cornerRadius: value.oneXCornerRadius,
                doubleTapTargetScale: value.doubleTapTargetScale,
                contentVersion: S2NativePhotoContentVersion(
                    requestedScale: requestedScale,
                    requestStrategy: configuration.imageRequestStrategy,
                    requestRevision: requestRevision
                ),
                content: content
            )
        }
        controller.apply(
            machine: machine,
            configuration: configuration,
            viewportSize: physicalSize,
            pages: pages,
            onLongPress: {}
        )
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    private func makeNativePagingScrollView(
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> S2NativePagingScrollView {
        let scrollView = S2NativePagingScrollView()
        scrollView.configure(
            viewportSize: physicalSize,
            itemCount: 3,
            pageSpacing: CGFloat(configuration.pageSpacing)
        )
        scrollView.contentOffset = scrollView.contentOffsetForPage(at: 1)
        return scrollView
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("预期值不应为空", file: file, line: line)
            fatalError("测试无法继续")
        }
        return value
    }
}

private struct UserDefaultsCalibrationPersistence: S2CalibrationPersisting {
    let defaults: UserDefaults
    let key: String

    func load() throws -> Data? {
        defaults.data(forKey: key)
    }

    func save(_ data: Data) throws {
        defaults.set(data, forKey: key)
    }
}
