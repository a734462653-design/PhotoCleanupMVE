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
        XCTAssertTrue(restarted.exportText().contains("valueStatus=未标定"))

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

    private let physicalSize = CGSize(width: 300, height: 600)

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
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> S2ViewportMetrics {
        S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: visibility,
                bottomStripState: strip,
                sheetState: sheet
            ),
            assetAspectRatio: screenAspectRatio,
            configuration: configuration
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
