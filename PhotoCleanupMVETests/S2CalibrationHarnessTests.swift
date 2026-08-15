import XCTest
@testable import PhotoCleanupMVE

final class S2CalibrationHarnessTests: XCTestCase {
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

        XCTAssertEqual(horizontalMarginRatio, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(verticalMarginRatio, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(zeroMetrics.viewportSize, insetMetrics.viewportSize)
        XCTAssertEqual(
            insetMetrics.aspectFillMultiplier,
            1.25,
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
            global.aspectFitSize.width * 0.8,
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
    func testL7FactoryDefaultsMatchUsableBuildDecision() {
        let expected = S2CalibrationConfiguration(
            pinchMaxScale: 4,
            zoomSnapBackThreshold: 1.1,
            aspectFillDegenerateTolerancePercent: 1,
            aspectFillDegenerateTargetScale: 2,
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
            singleTapDecisionWindowMilliseconds: 280,
            doubleTapDecisionWindowMilliseconds: 320,
            singleTapTouchCount: 1,
            doubleTapTouchCount: 1,
            singleDragTouchCount: 1,
            pinchTouchCount: 2,
            gestureExclusivityPolicy: .pinchBeforeSingleDrag,
            scaleChangeRequestPolicy: .everyScaleChange,
            degradedPreviewPolicy: .finalImageOnly,
            animationsEnabled: true,
            animationDurationMilliseconds: 220,
            fitInsetRatio: 0.05,
            fitInsetScope: .screenAspectOnly,
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
                scaleChangePolicy: .everyScaleChange,
                degradedPreviewPolicy: .finalImageOnly
            )
        )
        XCTAssertTrue(
            actual.exportText().contains(
                "taskID=IC-20260815-055-s2-usable-build"
            )
        )
        XCTAssertTrue(
            actual.exportText().contains(
                "valueStatus=④项目判断默认值，可修订"
            )
        )
        XCTAssertFalse(actual.exportText().contains("未标定"))
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

    private func makeMachine() -> S2StateMachine {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
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
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            ),
            parameters: tryUnwrap(configuration.resolvedParameters),
            imageRequestStrategy: configuration.imageRequestStrategy,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in }
        )!
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
