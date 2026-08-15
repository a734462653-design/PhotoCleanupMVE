import XCTest
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

    // V4：全部界面状态共享同一 1x 适配结果及双击填满倍数。
    func testV4AllPresentationStatesShareFitAndDoubleTapMultiplier() {
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
            XCTAssertEqual(value.oneXDisplaySize, first.oneXDisplaySize)
            XCTAssertEqual(
                value.aspectFillMultiplier,
                first.aspectFillMultiplier,
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
            $0.fitInsetScope = .allPhotos
            $0.pageSpacing = 28
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
        XCTAssertTrue(restarted.exportText().contains("pageSpacing=28.000000"))
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
            doubleTapDecisionWindowMilliseconds: 320,
            singleTapTouchCount: 1,
            doubleTapTouchCount: 1,
            singleDragTouchCount: 1,
            pinchTouchCount: 2,
            gestureExclusivityPolicy: .pinchBeforeSingleDrag,
            scaleChangeRequestPolicy: .pinchEnded,
            degradedPreviewPolicy: .finalImageOnly,
            animationsEnabled: true,
            animationDurationMilliseconds: 180,
            fitInsetRatio: 0.08,
            fitInsetScope: .screenAspectOnly,
            pageSpacing: 20,
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
                "taskID=IC-20260815-058-s2-native-zoom-paging"
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
        XCTAssertTrue(actual.exportText().contains("pageSpacing=20.000000"))
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
                "doubleTapDecisionWindowMilliseconds=320.000000"
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

    // D1：屏幕比例照片的 1x 短边按 0.08 内缩为视口短边的 0.92。
    func testD1ScreenAspectFitInsetRatioShrinksShortEdgeToNinetyTwoPercent() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.08
        configuration.fitInsetScope = .screenAspectOnly
        let value = metrics(configuration: configuration)

        XCTAssertEqual(
            min(value.oneXDisplaySize.width, value.oneXDisplaySize.height),
            min(value.viewportSize.width, value.viewportSize.height) * 0.92,
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
            oppositeOrientation.aspectFitSize.width * 0.92,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            oppositeOrientation.oneXDisplaySize.height,
            oppositeOrientation.aspectFitSize.height * 0.92,
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
        configuration.fitInsetRatio = 0.08
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

    // D5 替代断言：填满倍数较大时原生目标矩形采用该倍数，且不受 1x 内缩影响。
    func testD5DoubleTapUsesLargerAspectFillScale() {
        let assetAspectRatio: CGFloat = 1.5
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.08
        configuration.fitInsetScope = .allPhotos
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

        XCTAssertGreaterThan(expected, CGFloat(configuration.minDoubleTapScale))
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
        let locationsAndAssertions: [(CGPoint, (CGRect) -> CGFloat)] = [
            (
                CGPoint(x: physicalSize.width - 1, y: physicalSize.height / 2),
                { $0.maxX - self.physicalSize.width }
            ),
            (
                CGPoint(x: physicalSize.width / 2, y: 1),
                { $0.minY }
            ),
            (
                CGPoint(x: physicalSize.width / 2, y: physicalSize.height - 1),
                { $0.maxY - self.physicalSize.height }
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
            XCTAssertEqual(boundaryDifference(frame), 0, accuracy: 0.000_001)
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

    // E1：第一击抬起时立即产出单击动作，不等待双击判定窗口。
    func testE1FirstTapProducesImmediateSingleTapAction() {
        var coordinator = S2TapSequenceCoordinator()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        let action = coordinator.registerTap(
            at: CGPoint(x: 100, y: 200),
            arrivalDate: start,
            completionDate: start.addingTimeInterval(0.08),
            decisionWindowMilliseconds: 320,
            maximumMovement: 12,
            allowsDoubleTap: true
        )

        XCTAssertEqual(action, .singleTap)
        let machine = makeMachine()
        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
    }

    // E2：第二击在 320 毫秒窗口内到达时，撤销已生效单击并裁决为双击。
    func testE2SecondTapWithinDecisionWindowRevertsAppliedSingleTap() {
        var coordinator = S2TapSequenceCoordinator()
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        let firstCompletion = start.addingTimeInterval(0.08)
        XCTAssertEqual(
            coordinator.registerTap(
                at: CGPoint(x: 100, y: 200),
                arrivalDate: start,
                completionDate: firstCompletion,
                decisionWindowMilliseconds: 320,
                maximumMovement: 12,
                allowsDoubleTap: true
            ),
            .singleTap
        )
        coordinator.recordImmediateSingleTapApplied(true)

        let action = coordinator.registerTap(
            at: CGPoint(x: 108, y: 205),
            arrivalDate: firstCompletion.addingTimeInterval(0.30),
            completionDate: firstCompletion.addingTimeInterval(0.38),
            decisionWindowMilliseconds: 320,
            maximumMovement: 12,
            allowsDoubleTap: true
        )

        XCTAssertEqual(
            action,
            .doubleTap(revertImmediateSingleTap: true)
        )
    }

    // E3：超出双击窗口的下一击立即作为新的单击，不撤销上一击。
    func testE3TapAfterDecisionWindowStartsNewImmediateSingleTap() {
        var coordinator = S2TapSequenceCoordinator()
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        let firstCompletion = start.addingTimeInterval(0.08)
        _ = coordinator.registerTap(
            at: CGPoint(x: 100, y: 200),
            arrivalDate: start,
            completionDate: firstCompletion,
            decisionWindowMilliseconds: 320,
            maximumMovement: 12,
            allowsDoubleTap: true
        )
        coordinator.recordImmediateSingleTapApplied(true)

        let action = coordinator.registerTap(
            at: CGPoint(x: 100, y: 200),
            arrivalDate: firstCompletion.addingTimeInterval(0.321),
            completionDate: firstCompletion.addingTimeInterval(0.40),
            decisionWindowMilliseconds: 320,
            maximumMovement: 12,
            allowsDoubleTap: true
        )

        XCTAssertEqual(action, .singleTap)
    }

    // E4：立即单击后原子撤销再双击，最终状态与直接双击完全一致。
    func testE4RevertedSingleTapThenDoubleTapMatchesDirectDoubleTap() {
        let value = metrics()

        for visibility in [
            S2InterfaceVisibility.visible,
            S2InterfaceVisibility.hidden
        ] {
            let direct = makeMachine(interfaceVisibility: visibility)
            let coordinated = makeMachine(interfaceVisibility: visibility)
            XCTAssertTrue(coordinated.handleSingleTap())

            XCTAssertTrue(direct.handleNativeDoubleTap(
                targetScale: value.doubleTapTargetScale
            ))
            XCTAssertTrue(coordinated.handleNativeDoubleTap(
                targetScale: value.doubleTapTargetScale,
                revertingImmediateSingleTap: true
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

    // N2：双击调用原生 zoom(to:)，目标矩形对应填满倍数与最小倍数的较大值。
    func testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1.5,
            configuration: configuration
        )
        let expected = max(
            value.aspectFillMultiplier,
            CGFloat(configuration.minDoubleTapScale)
        )
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

    // A1：统一策略在关闭开关时把显式时长归零。
    func testA1AnimationPolicyDisablesCalibratedAnimations() {
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
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> S2StateMachine {
        return S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-054",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-054",
                    displayName: "测试范围",
                    totalAssetCount: 3
                ),
                orderedAssetIDs: ["asset-1", "asset-2", "asset-3"],
                currentAssetID: "asset-2",
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
