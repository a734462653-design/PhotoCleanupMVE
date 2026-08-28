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
        resultHandler: @escaping (S2ImageRequestResult) -> Void
    ) -> PHImageRequestID {
        requestCount += 1
        resultHandler(.finalImage(UIImage()))
        return PHInvalidImageRequestID
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {}

    func reset() {
        requestCount = 0
    }
}

private struct IC064PresentationSample {
    let timestamp: CFTimeInterval
    let frame: CGRect
    let bounds: CGRect
    let contentsRect: CGRect
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
}

private final class IC064PresentationLayerSampler: NSObject {
    private weak var page: S2NativeZoomPageController?
    private var displayLink: CADisplayLink?
    private var startTimestamp: CFTimeInterval?
    private(set) var samples: [IC064PresentationSample] = []

    init(page: S2NativeZoomPageController) {
        self.page = page
    }

    deinit {
        displayLink?.invalidate()
    }

    func start() {
        samples = []
        startTimestamp = nil
        capture(timestamp: CACurrentMediaTime())
        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(captureDisplayFrame(_:))
        )
        displayLink.preferredFramesPerSecond = 60
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    func stop() -> [IC064PresentationSample] {
        displayLink?.invalidate()
        displayLink = nil
        capture(timestamp: CACurrentMediaTime())
        return samples
    }

    @objc private func captureDisplayFrame(_ displayLink: CADisplayLink) {
        capture(timestamp: displayLink.timestamp)
    }

    private func capture(timestamp: CFTimeInterval) {
        guard let page,
              let presentationContentView =
                page.zoomScrollView.presentationContentView,
              let zoomContentView =
                page.zoomScrollView.zoomContentView else {
            return
        }
        let scrollView = page.zoomScrollView
        let layer = presentationContentView.layer.presentation() ??
            presentationContentView.layer
        let borderLayer = page.fitBorderLayer.presentation() ??
            page.fitBorderLayer
        let frame = zoomContentView.convert(
            layer.frame,
            to: scrollView
        ).offsetBy(
            dx: -scrollView.bounds.minX,
            dy: -scrollView.bounds.minY
        )
        let firstTimestamp = startTimestamp ?? timestamp
        startTimestamp = firstTimestamp
        samples.append(IC064PresentationSample(
            timestamp: timestamp - firstTimestamp,
            frame: frame,
            bounds: layer.bounds,
            contentsRect: layer.contentsRect,
            cornerRadius: layer.cornerRadius,
            borderWidth: borderLayer.borderWidth
        ))
    }
}

private struct IC065PinchPresentationSample {
    let timestamp: CFTimeInterval
    let phase: String
    let zoomScale: CGFloat
    let frameInWindow: CGRect
    let contentSize: CGSize
    let contentOffset: CGPoint
    let contentInset: UIEdgeInsets
}

private final class IC065PinchPresentationSampler: NSObject {
    private weak var scrollView: S2NativeZoomScrollView?
    private weak var window: UIWindow?
    private var displayLink: CADisplayLink?
    private var startTimestamp: CFTimeInterval?
    private var phase = "one_x"
    private(set) var samples: [IC065PinchPresentationSample] = []

    init(scrollView: S2NativeZoomScrollView, window: UIWindow) {
        self.scrollView = scrollView
        self.window = window
    }

    deinit {
        displayLink?.invalidate()
    }

    func start() {
        samples = []
        startTimestamp = nil
        capture(timestamp: CACurrentMediaTime())
        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(captureDisplayFrame(_:))
        )
        displayLink.preferredFramesPerSecond = 60
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    func mark(_ phase: String) {
        self.phase = phase
        capture(timestamp: CACurrentMediaTime())
    }

    func stop() -> [IC065PinchPresentationSample] {
        displayLink?.invalidate()
        displayLink = nil
        capture(timestamp: CACurrentMediaTime())
        return samples
    }

    @objc private func captureDisplayFrame(_ displayLink: CADisplayLink) {
        capture(timestamp: displayLink.timestamp)
    }

    private func capture(timestamp: CFTimeInterval) {
        guard let scrollView,
              let window,
              let presentationContentView =
                scrollView.presentationContentView,
              let zoomContentView = scrollView.zoomContentView else {
            return
        }
        let layer = presentationContentView.layer.presentation() ??
            presentationContentView.layer
        let frameInWindow = zoomContentView.convert(layer.frame, to: window)
        let firstTimestamp = startTimestamp ?? timestamp
        startTimestamp = firstTimestamp
        samples.append(IC065PinchPresentationSample(
            timestamp: timestamp - firstTimestamp,
            phase: phase,
            zoomScale: scrollView.zoomScale,
            frameInWindow: frameInWindow,
            contentSize: scrollView.contentSize,
            contentOffset: scrollView.contentOffset,
            contentInset: scrollView.contentInset
        ))
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
                isScreenshot: true,
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
            $0.pinchMaxScaleFloor = 5.5
            $0.pinchMaxScaleCeiling = 12
            $0.pinchMaxScaleOneToOneMultiplier = 3
            $0.zoomSnapBackThreshold = 1.25
            $0.fitCornerRadius = 36
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

    // IC-087 G171：持久化数据的 `schemaVersion` 与代码版本不等（或缺失）→ 整套丢弃、取出厂值并删除条目；
    // 相等 → 按现行逐字段解码。IC-104 C：删除 fitInsetRatio，出厂值集合变更，版本 4 → 6
    // （5 已被冻结的 feature/ic-092-nx-window-follow 链占用），导出文本含 schemaVersion=6。
    func testIC087G171SchemaVersionGateDiscardsStaleStoreAndDeletesEntry() throws {
        XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 6)
        XCTAssertTrue(
            S2CalibrationConfiguration.factoryPlaceholder.exportText()
                .contains("schemaVersion=6")
        )

        // 1) schemaVersion=3（IC-087 旧版）且 ceiling=10 → 出厂 40，且存储被删除。
        let stale = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: 3, ceiling: 10)
        )
        let staleModel = S2CalibrationModel(persistence: stale)
        XCTAssertEqual(staleModel.configuration, .factoryPlaceholder)
        XCTAssertEqual(staleModel.configuration.pinchMaxScaleCeiling, 40)
        XCTAssertNil(stale.data)
        XCTAssertEqual(stale.deleteCount, 1)
        XCTAssertEqual(stale.saveCount, 0)
        XCTAssertFalse(staleModel.persistenceFailed)

        // 2) schemaVersion=6 且 ceiling=12 → 12，存储保留。
        let current = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: 6, ceiling: 12)
        )
        let currentModel = S2CalibrationModel(persistence: current)
        XCTAssertEqual(currentModel.configuration.pinchMaxScaleCeiling, 12)
        XCTAssertNotNil(current.data)
        XCTAssertEqual(current.deleteCount, 0)

        // 3) 无 schemaVersion 字段（视为 0）→ 出厂，且存储被删除。
        let legacy = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: nil, ceiling: 10)
        )
        let legacyModel = S2CalibrationModel(persistence: legacy)
        XCTAssertEqual(legacyModel.configuration, .factoryPlaceholder)
        XCTAssertNil(legacy.data)
        XCTAssertEqual(legacy.deleteCount, 1)

        // 保存后的数据顶层带 schemaVersion=6，重新加载得同一配置。
        XCTAssertTrue(currentModel.update { $0.pinchMaxScaleCeiling = 15 })
        let saved = try XCTUnwrap(current.data)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: saved) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 6)
        XCTAssertEqual(
            S2CalibrationModel(persistence: current).configuration,
            currentModel.configuration
        )

        // 删除失败时 persistenceFailed 置位，配置仍为出厂。
        let failing = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: 3, ceiling: 10)
        )
        failing.deleteError = S2CalibrationPersistenceError.keychain(-1)
        let failingModel = S2CalibrationModel(persistence: failing)
        XCTAssertEqual(failingModel.configuration, .factoryPlaceholder)
        XCTAssertTrue(failingModel.persistenceFailed)
    }

    // IC-087 G172（夹具驱动，真机未覆盖）：「恢复出厂值」把配置重置为出厂、删除存储条目；
    // 经 applyCalibration + 重新 apply 后当前页 maximumZoomScale == 出厂规则值，
    // contentOffset / contentSize / contentInset / 照片 frame 不变，照片几何写入事件 0 条。
    func testIC087G172RestoreFactoryResetsDeletesStoreAndAppliesToCurrentPage() throws {
        XCTAssertTrue(
            L10n.text("s2.calibration.restore_factory").hasPrefix("【未定项 21 占位】")
        )
        let store = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: 6, ceiling: 12)
        )
        let model = S2CalibrationModel(persistence: store)
        XCTAssertEqual(model.configuration.pinchMaxScaleCeiling, 12)
        var configuration = model.configuration
        let machine = makeMachine(
            configuration: configuration,
            orderedAssetIDs: ["asset-1", "asset-2"],
            currentIndex: 0
        )
        let pixelSizes: [String: CGSize] = [
            "asset-1": CGSize(width: 4_032, height: 3_024),
            "asset-2": CGSize(width: 600, height: 1_200)
        ]
        let zoomGeometry: (String, CGSize) -> S2AssetZoomGeometry? = { assetID, fitSize in
            S2AssetZoomGeometry(
                assetPixelSize: pixelSizes[assetID] ?? .zero,
                fitSize: fitSize,
                displayScale: 3
            )
        }
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            zoomGeometry: zoomGeometry
        )
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()
        defer { diagnostics.stop() }
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        let current = tryUnwrap(controller.pageControllers[0])
        func expected(ceiling: CGFloat) -> CGFloat {
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: pixelSizes["asset-1"]!,
                fitSize: current.zoomScrollView.nativeZoomBaseSize,
                displayScale: 3,
                floor: 4,
                ceiling: ceiling,
                multiplier: 6
            )
        }
        // 存储值 ceiling 12 在生效：4032 宽 × 6 超过 12，被钳到 12。
        XCTAssertEqual(current.zoomScrollView.maximumZoomScale, expected(ceiling: 12), accuracy: 0.000_001)
        XCTAssertEqual(current.zoomScrollView.maximumZoomScale, 12, accuracy: 0.000_001)

        struct GeometrySnapshot: Equatable {
            let contentOffset: CGPoint
            let contentSize: CGSize
            let contentInset: UIEdgeInsets
            let photoFrame: CGRect
        }
        func snapshot(_ page: S2NativeZoomPageController) -> GeometrySnapshot {
            GeometrySnapshot(
                contentOffset: page.zoomScrollView.contentOffset,
                contentSize: page.zoomScrollView.contentSize,
                contentInset: page.zoomScrollView.contentInset,
                photoFrame: page.zoomScrollView.presentationContentView?.frame ?? .null
            )
        }
        let before = snapshot(current)
        let writesBefore = diagnostics.photoGeometryWriteCount

        // 恢复出厂值：配置 == 出厂、存储为空（删除而非覆盖）。
        model.restoreFactoryPlaceholder()
        XCTAssertEqual(model.configuration, .factoryPlaceholder)
        XCTAssertNil(store.data)
        XCTAssertEqual(store.deleteCount, 1)
        XCTAssertEqual(store.saveCount, 0)
        XCTAssertFalse(model.persistenceFailed)

        // 即时生效（产品侧链路：onChange → applyCalibration → apply）。
        configuration = model.configuration
        XCTAssertTrue(machine.applyCalibration(configuration))
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            zoomGeometry: zoomGeometry
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        XCTAssertEqual(
            current.zoomScrollView.maximumZoomScale,
            expected(ceiling: 40),
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(current.zoomScrollView.maximumZoomScale, 12)
        XCTAssertEqual(machine.pinchMaxScale(for: "asset-1"), expected(ceiling: 40), accuracy: 0.000_001)

        XCTAssertEqual(snapshot(current), before)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, writesBefore)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
        XCTAssertEqual(current.zoomScrollView.zoomScale, 1)
        XCTAssertEqual(machine.scale, 1)
    }

    /// IC-087：按出厂值编码后改写顶层 `schemaVersion`（nil 表示删除该字段）与 `pinchMaxScaleCeiling`。
    private func makeStoredCalibration(
        schemaVersion: Int?,
        ceiling: Double
    ) throws -> Data {
        let encoded = try JSONEncoder().encode(
            S2CalibrationConfiguration.factoryPlaceholder
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        if let schemaVersion {
            object["schemaVersion"] = schemaVersion
        } else {
            object.removeValue(forKey: "schemaVersion")
        }
        object["pinchMaxScaleCeiling"] = ceiling
        return try JSONSerialization.data(withJSONObject: object)
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

    // IC-104 C v3：截图在**显示态**的适配带顶缘回到旧位（0.15 × 视口高），
    // 底距 = 顶距 = g；「横栏—操作条」30.7 不参与等距；隐藏态仍沉浸填满；
    // 非截图零变化。
    func testIC104CScreenshotFitBoxAnchorsLegacyTopWithEqualGaps() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        // IC-104 C v3：带顶缘 = 0.15 × 视口高，故必须用**真实配对**的视口与安全区
        // （393×852 / 顶 59），而非夹具 300×600 配 59pt 顶——后者不对应任何机型，
        // 会得出 g < 0 的伪几何。
        let viewport = overlayPhysicalSize
        let aspect = viewport.width / viewport.height
        let insets = overlaySafeAreaInsets
        let spacing = S2OverlayLayout.stripToActionVisibleBandSpacing
        let stripHeight = max(
            CGFloat(configuration.bottomStripCurrentItemSize),
            CGFloat(configuration.bottomStripNeighborItemHeight)
        )
        let screenshot = S2ViewportLayout.metrics(
            physicalSize: viewport,
            presentationState: presentationState,
            assetAspectRatio: aspect,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: insets
        )

        // 带高严格等于推导式，且照片被带高约束（高度受限而非宽度受限）
        let bandHeight = S2ViewportLayout.screenshotBandHeight(
            physicalSize: viewport,
            safeAreaInsets: insets,
            bottomStripHeight: stripHeight
        )
        XCTAssertEqual(
            screenshot.oneXDisplaySize.height,
            bandHeight,
            accuracy: 0.000_001
        )
        XCTAssertLessThanOrEqual(
            screenshot.oneXDisplaySize.width,
            viewport.width
        )

        // 带顶缘 = 0.15 × 视口高（旧位）；g = 带顶缘 − 顶部栏底缘；
        // 带底缘 = 横栏顶缘 − g，即底距 = 顶距。
        let topBarBottom = insets.top + S2OverlayLayout.topBarHeight
        let stripTop = viewport.height -
            S2OverlayLayout.stripTopFromViewportBottom(
                safeAreaBottom: insets.bottom,
                bottomStripHeight: stripHeight
            )
        let bandTop = S2ViewportLayout.screenshotBandTop(
            physicalSize: viewport
        )
        let g = S2ViewportLayout.screenshotBandTopSpacing(
            physicalSize: viewport,
            safeAreaInsets: insets
        )
        XCTAssertEqual(
            bandTop,
            viewport.height * 0.15,
            accuracy: 0.000_001
        )
        XCTAssertEqual(g, bandTop - topBarBottom, accuracy: 0.000_001)
        XCTAssertGreaterThan(g, 0)

        // 摆放：显示态截图竖直居中于带；顶缘落在带顶缘、底缘落在带底缘
        let photoTop = screenshot.oneXDisplayCenterY -
            screenshot.oneXDisplaySize.height / 2
        let photoBottom = photoTop + screenshot.oneXDisplaySize.height
        XCTAssertEqual(photoTop, bandTop, accuracy: 0.000_001)
        XCTAssertEqual(photoBottom, stripTop - g, accuracy: 0.000_001)

        // 底距 = 顶距
        XCTAssertEqual(photoTop - topBarBottom, g, accuracy: 0.000_001)
        XCTAssertEqual(stripTop - photoBottom, g, accuracy: 0.000_001)

        // 「横栏—操作条」间距维持 30.7，不参与等距（④ Lynn 明确选定）
        let stripBottom = viewport.height -
            S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: insets.bottom
            )
        let actionVisibleBandTop = viewport.height -
            S2OverlayLayout.actionVisibleBandTopFromViewportBottom(
                safeAreaBottom: insets.bottom
            )
        XCTAssertEqual(
            actionVisibleBandTop - stripBottom,
            spacing,
            accuracy: 0.000_001
        )
        XCTAssertEqual(spacing, 30.7, accuracy: 0.000_001)

        // 水平仍是等比适配 + 居中
        XCTAssertEqual(
            screenshot.oneXDisplaySize.width,
            screenshot.oneXDisplaySize.height * aspect,
            accuracy: 0.000_001
        )

        // 隐藏态维持规格 v16 第 121/177 行的截图沉浸：填满视口、圆角归零，
        // chrome 带只作用于显示态
        let hidden = S2ViewportLayout.metrics(
            physicalSize: viewport,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .hidden,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: aspect,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: insets
        )
        XCTAssertEqual(hidden.oneXDisplaySize, hidden.aspectFitSize)
        XCTAssertEqual(hidden.oneXCornerRadius, 0)
        XCTAssertNotEqual(hidden.oneXDisplaySize, screenshot.oneXDisplaySize)
        // 隐藏态沉浸 = 视口居中；显示态 = 带中心，两者不同心（morph 含平移）
        XCTAssertEqual(
            hidden.oneXDisplayCenterY,
            viewport.height / 2,
            accuracy: 0.000_001
        )
        XCTAssertNotEqual(
            hidden.oneXDisplayCenterY,
            screenshot.oneXDisplayCenterY
        )

        // 裁切截图（非屏幕比例）同样按带高适配
        let croppedScreenshotRatio: CGFloat = 0.1823
        let cropped = S2ViewportLayout.metrics(
            physicalSize: viewport,
            presentationState: presentationState,
            assetAspectRatio: croppedScreenshotRatio,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: insets
        )
        XCTAssertEqual(
            cropped.oneXDisplaySize.height,
            bandHeight,
            accuracy: 0.000_001
        )

        // 非截图零变化：仍是全视口等比适配，且不受 chrome 影响
        let ordinaryPhoto = S2ViewportLayout.metrics(
            physicalSize: viewport,
            presentationState: presentationState,
            assetAspectRatio: aspect,
            isScreenshot: false,
            configuration: configuration,
            safeAreaInsets: insets
        )
        XCTAssertEqual(
            ordinaryPhoto.oneXDisplaySize,
            ordinaryPhoto.aspectFitSize
        )
        XCTAssertEqual(
            ordinaryPhoto.oneXDisplayCenterY,
            viewport.height / 2,
            accuracy: 0.000_001
        )
        XCTAssertFalse(ordinaryPhoto.isFramedPhoto)
        XCTAssertEqual(
            ordinaryPhoto.aspectFillMultiplier,
            1,
            accuracy: 0.000_001
        )
    }

    // IC-104 C v3：**渲染帧**摆放断言——显示态截图的实际帧顶缘落在 0.15 × 视口高，
    // 底缘距横栏顶缘 = g；隐藏态回到视口居中。C v2 只断言了计算值，未校验摆放。
    func testIC104CScreenshotRenderedFrameSitsAtLegacyTopAnchor() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        // 夹具走 `.zero` 安全区：带顶缘 90、g = 90 − 48 = 42
        let stripHeight = max(
            CGFloat(configuration.bottomStripCurrentItemSize),
            CGFloat(configuration.bottomStripNeighborItemHeight)
        )
        let bandTop = S2ViewportLayout.screenshotBandTop(
            physicalSize: physicalSize
        )
        let g = S2ViewportLayout.screenshotBandTopSpacing(
            physicalSize: physicalSize,
            safeAreaInsets: .zero
        )
        let stripTop = physicalSize.height -
            S2OverlayLayout.stripTopFromViewportBottom(
                safeAreaBottom: 0,
                bottomStripHeight: stripHeight
            )
        XCTAssertGreaterThan(g, 0)

        let visibleFrame = tryUnwrap(
            page.zoomScrollView.visiblePresentationFrame()
        )
        XCTAssertEqual(visibleFrame.minY, bandTop, accuracy: 0.000_001)
        XCTAssertEqual(
            stripTop - visibleFrame.maxY,
            g,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            visibleFrame.minY - S2OverlayLayout.topBarHeight,
            g,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            visibleFrame.midX,
            physicalSize.width / 2,
            accuracy: 0.000_001
        )

        // 隐藏态：沉浸填满 + 视口居中
        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        page.finishActivePresentationTransition()
        let hiddenFrame = tryUnwrap(
            page.zoomScrollView.visiblePresentationFrame()
        )
        XCTAssertEqual(hiddenFrame.minY, 0, accuracy: 0.5)
        XCTAssertEqual(
            hiddenFrame.midY,
            physicalSize.height / 2,
            accuracy: 0.5
        )
        XCTAssertEqual(hiddenFrame.height, physicalSize.height, accuracy: 0.5)
    }

    // L1：顶部三个元素全部从系统顶部安全区下沿开始布局（IC-075 起为三件）。
    func testL1TopOverlayFramesRespectSafeAreaTop() {
        let snapshot = overlaySnapshot()

        XCTAssertEqual(snapshot.topElementFrames.count, 3)
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

    // IC-075 G104：顶部三帧互不重叠、均在顶部区域内；返回与确认页入口 ≥ 44pt；
    // 可点击帧含帧 0 与帧 2、不含序号帧 1。
    func testIC075G104TopBarHasThreeElementsWithClickableEnds() {
        let snapshot = overlaySnapshot()
        let frames = snapshot.topElementFrames
        XCTAssertEqual(frames.count, 3)

        let topBounds = CGRect(
            x: overlaySafeAreaInsets.leading,
            y: overlaySafeAreaInsets.top,
            width: overlayPhysicalSize.width - overlaySafeAreaInsets.leading -
                overlaySafeAreaInsets.trailing,
            height: S2OverlayLayout.topBarHeight
        )
        for (index, frame) in frames.enumerated() {
            XCTAssertTrue(
                topBounds.insetBy(dx: -0.001, dy: -0.001).contains(frame),
                "顶部元素 \(index) 应落在顶部区域内：\(frame)"
            )
        }
        for first in frames.indices {
            for second in frames.indices where second > first {
                XCTAssertFalse(frames[first].intersects(frames[second]))
            }
        }
        for index in [0, 2] {
            XCTAssertGreaterThanOrEqual(
                frames[index].width,
                S2OverlayLayout.minimumTouchTarget
            )
            XCTAssertGreaterThanOrEqual(
                frames[index].height,
                S2OverlayLayout.minimumTouchTarget
            )
        }
        XCTAssertEqual(frames[0].width, S2OverlayLayout.topLeadingControlWidth)
        XCTAssertEqual(frames[2].width, S2OverlayLayout.topLeadingControlWidth)
        XCTAssertLessThan(frames[0].maxX, frames[1].minX)
        XCTAssertLessThan(frames[1].maxX, frames[2].minX)

        let clickable = snapshot.clickableControlFrames
        XCTAssertTrue(clickable.contains(frames[0]))
        XCTAssertTrue(clickable.contains(frames[2]))
        XCTAssertFalse(clickable.contains(frames[1]))
    }

    // L3：返回、序号与确认页入口三个顶部元素之间均保留间距。
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

    // L7：完整出厂配置包含 IC-064 的显隐时长与描边定案。
    func testL7FactoryDefaultsMatchSystemParityDecision() {
        let expected = S2CalibrationConfiguration(
            pinchMaxScaleFloor: 4,
            pinchMaxScaleCeiling: 40,
            pinchMaxScaleOneToOneMultiplier: 6,
            zoomSnapBackThreshold: 1.1,
            minDoubleTapScale: 2,
            doubleTapAnchorStrategy: .touchPoint,
            edgePagingTriggerDistance: 40,
            edgePagingTriggerVelocity: 300,
            verticalSwipeDistance: 40,
            verticalSwipeVelocity: 100,
            doubleTapDecisionWindowMilliseconds: 200,
            singleTapTouchCount: 1,
            doubleTapTouchCount: 1,
            singleDragTouchCount: 1,
            pinchTouchCount: 2,
            scaleChangeRequestPolicy: .pinchEnded,
            degradedPreviewPolicy: .display,
            animationsEnabled: true,
            animationDurationMilliseconds: 180,
            presentationToggleDuration: 220,
            presentationToggleDamping: 0.86,
            fitCornerRadius: 28,
            fitBorderWidth: 1,
            fitBorderDarkAlpha: 0.09,
            fitBorderLightAlpha: 0.055,
            pageSpacing: 20,
            hapticOnPhotoSwitch: true,
            bottomStripCurrentItemSize: 30,
            bottomStripNeighborItemWidth: 20,
            bottomStripNeighborItemHeight: 30,
            bottomStripItemSpacing: 3,
            bottomStripCurrentItemGap: 13,
            bottomStripEdgeFadeWidth: 18.7,
            bottomStripLeadingInset: 20.3,
            bottomStripSwitchDistance: 23,
            bottomStripDecelerationRate: 0.998,
            bottomStripExpandDurationMilliseconds: 600,
            bottomStripCollapseDurationMilliseconds: 100,
            bottomStripFlickVelocityThreshold: 300,
            bottomStripCornerRadius: 8.0 / 3.0,
            bottomStripMarkSize: 14,
            markPulseDurationMilliseconds: 150,
            feedbackToastDurationMilliseconds: 2000
        )
        let actual = S2CalibrationConfiguration.factoryPlaceholder

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(
            actual.imageRequestStrategy,
            S2ImageRequestStrategy(
                scaleChangePolicy: .pinchEnded,
                degradedPreviewPolicy: .display
            )
        )
        XCTAssertTrue(
            actual.exportText().contains(
                "taskID=IC-20260821-074-parameter-layer-v15-alignment"
            )
        )
        XCTAssertTrue(
            actual.exportText().contains(
                "valueStatus=④项目判断默认值，可修订"
            )
        )
        XCTAssertTrue(
            actual.exportText().contains("minDoubleTapScale=2.000000")
        )
        XCTAssertTrue(actual.exportText().contains("fitCornerRadius=28.000000"))
        XCTAssertTrue(actual.exportText().contains(
            "presentationToggleDuration=220.000000"
        ))
        XCTAssertTrue(actual.exportText().contains(
            "presentationToggleDamping=0.860000"
        ))
        XCTAssertTrue(actual.exportText().contains("fitBorderWidth=1.000000"))
        XCTAssertTrue(actual.exportText().contains("fitBorderDarkAlpha=0.090000"))
        XCTAssertTrue(actual.exportText().contains("fitBorderLightAlpha=0.055000"))
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

    // IC-067 C5：面板状态表逐一覆盖全部配置字段，不为死参数补接生产逻辑。
    func testIC067C5ParameterConnectionStatusesCoverEveryFieldExactlyOnce() {
        let parameterNames = Mirror(
            reflecting: S2CalibrationConfiguration.factoryPlaceholder
        ).children.compactMap(\.label)
        let connections = S2CalibrationConfiguration.parameterConnections
        let connectionNames = connections.map(\.name)
        let statuses = Dictionary(uniqueKeysWithValues: connections.map {
            ($0.name, $0.wiringStatus)
        })

        XCTAssertEqual(Set(connectionNames), Set(parameterNames))
        XCTAssertEqual(connectionNames.count, parameterNames.count)
        XCTAssertEqual(Set(connectionNames).count, connectionNames.count)
        XCTAssertEqual(
            statuses["doubleTapDecisionWindowMilliseconds"],
            .unwired
        )
        // IC-085：横栏渐隐接线为 effective；废止参数不再登记。
        XCTAssertEqual(statuses["bottomStripEdgeFadeWidth"], .effective)
        XCTAssertEqual(statuses["bottomStripLeadingInset"], .effective)
        XCTAssertEqual(statuses["bottomStripDecelerationRate"], .effective)
        XCTAssertNil(statuses["bottomStripDragMinimumDistance"])
        XCTAssertEqual(
            statuses["presentationToggleDamping"],
            .effective
        )
        XCTAssertEqual(statuses["pinchMaxScaleFloor"], .effective)
        XCTAssertEqual(statuses["pinchMaxScaleCeiling"], .effective)
        XCTAssertEqual(statuses["pinchMaxScaleOneToOneMultiplier"], .effective)
        // IC-082 R3：贴边翻页交给原生嵌套滚动，两项阈值登记为 unwired。
        XCTAssertEqual(statuses["edgePagingTriggerDistance"], .unwired)
        XCTAssertEqual(statuses["edgePagingTriggerVelocity"], .unwired)
    }

    // IC-074 G96：配置字段恰 33 个；导出 37 行，含 schemaVersion 与 v15 规格基线。
    // IC-085：废止 1 项、新增 5 项横栏参数，字段 37 → 41，导出 41 + 4 行；R3 新增 1 项：42。
    // IC-088 合并：+ IC-081 乘数 1 项 = 43，导出 43 + 4 = 47；IC-087：schemaVersion=3。
    // IC-090 R1：+ bottomStripCornerRadius 1 项 = 44，导出 44 + 4 = 48；schemaVersion=4。
    // IC-104 C：− fitInsetRatio 1 项 = 43，导出 43 + 4 = 47；出厂值集合变了，schemaVersion=6。
    func testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export() {
        let fieldNames = Mirror(
            reflecting: S2CalibrationConfiguration.factoryPlaceholder
        ).children.compactMap(\.label)
        XCTAssertEqual(fieldNames.count, 43)

        let lines = S2CalibrationConfiguration.factoryPlaceholder
            .exportText()
            .split(separator: "\n")
            .map(String.init)
        XCTAssertEqual(lines.count, 43 + 4)
        XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 6)
        XCTAssertTrue(lines.contains("schemaVersion=6"))
        XCTAssertTrue(lines.contains(
            "taskID=IC-20260821-074-parameter-layer-v15-alignment"
        ))
        XCTAssertTrue(lines.contains("specBaseline=SPEC-S2-20260821_v15"))
        XCTAssertTrue(lines.contains { $0.hasPrefix("valueStatus=") })
        let exportedNames = Set(lines.map {
            String($0.split(separator: "=", maxSplits: 1)[0])
        })
        for name in fieldNames {
            XCTAssertTrue(exportedNames.contains(name), name)
        }
        // 导出行 = 4 个头部键 + 33 个字段，没有任何废止参数残留。
        XCTAssertEqual(exportedNames.count, fieldNames.count + 4)
    }

    // IC-074 G97：登记表 33 条、双状态；decided 集合恰为 v15 第十一节第 1、2 部分已存在的 16 项。
    // IC-085：登记表 41 条；横栏 11 项（6 项既有 + 5 项新增）全部 decided；R3 新增 placeholder 1 项：42 条。
    // IC-090 R1：+ bottomStripCornerRadius（decided / effective）：44 条，decided 35。
    func testIC074G97ParameterRegistryDecidedSetMatchesV15() {
        let connections = S2CalibrationConfiguration.parameterConnections
        XCTAssertEqual(connections.count, 43)
        XCTAssertEqual(Set(connections.map(\.name)).count, 43)

        let decided = Set(connections
            .filter { $0.specStatus == .decided }
            .map(\.name))
        let placeholder = Set(connections
            .filter { $0.specStatus == .placeholder }
            .map(\.name))
        XCTAssertEqual(decided, [
            "zoomSnapBackThreshold", "minDoubleTapScale",
            "presentationToggleDuration", "presentationToggleDamping",
            "fitCornerRadius", "fitBorderWidth",
            "fitBorderDarkAlpha", "fitBorderLightAlpha",
            "verticalSwipeDistance", "verticalSwipeVelocity",
            "pageSpacing", "hapticOnPhotoSwitch",
            "doubleTapDecisionWindowMilliseconds",
            "edgePagingTriggerDistance", "edgePagingTriggerVelocity",
            "bottomStripMarkSize", "markPulseDurationMilliseconds",
            "feedbackToastDurationMilliseconds",
            "scaleChangeRequestPolicy", "degradedPreviewPolicy",
            "pinchMaxScaleFloor", "pinchMaxScaleCeiling",
            "bottomStripCurrentItemSize", "bottomStripNeighborItemWidth",
            "bottomStripNeighborItemHeight", "bottomStripItemSpacing",
            "bottomStripCurrentItemGap", "bottomStripEdgeFadeWidth",
            "bottomStripLeadingInset", "bottomStripSwitchDistance",
            "bottomStripDecelerationRate",
            "bottomStripExpandDurationMilliseconds",
            "bottomStripCollapseDurationMilliseconds",
            "bottomStripCornerRadius"
        ])
        // IC-088 合并：decided 34（IC-085）；placeholder 8（IC-085）+ 乘数 1（IC-081）= 9。
        // IC-090 R1：decided 34 → 35（圆角半径），placeholder 不变。
        // IC-104 C：decided 35 → 34（删 fitInsetRatio），placeholder 不变。
        XCTAssertEqual(decided.count, 34)
        XCTAssertEqual(placeholder.count, 9)
        XCTAssertTrue(placeholder.contains("bottomStripFlickVelocityThreshold"))
        XCTAssertTrue(decided.isDisjoint(with: placeholder))
        XCTAssertFalse(placeholder.contains("pinchMaxScale"))
        XCTAssertTrue(placeholder.contains("pinchMaxScaleOneToOneMultiplier"))
        XCTAssertEqual(
            S2CalibrationConfiguration.factoryPlaceholder.pinchMaxScaleOneToOneMultiplier,
            6
        )
        XCTAssertEqual(
            S2CalibrationConfiguration.factoryPlaceholder.pinchMaxScaleFloor,
            4
        )
        XCTAssertEqual(
            S2CalibrationConfiguration.factoryPlaceholder.pinchMaxScaleCeiling,
            40
        )
        for connection in connections {
            XCTAssertFalse(connection.specStatus.title.isEmpty)
            XCTAssertFalse(connection.wiringStatus.title.isEmpty)
        }
    }

    // IC-077 G127（原生分页控制器夹具 + 脚本化假策略计数；页窗口按 S2View.mainPhoto 规则为当前页 ±1）：
    // 捏合中连续 10 次 s 变化 0 次请求；捏合结束 1 次；双击到达目标倍率 1 次（退出与进入各 1）；
    // 翻页后新进窗口的一页 1 次、离开窗口的一页旧请求被取消、成为当前页的一页不重复请求；
    // 视口尺寸变化当前页 1 次。
    func testIC077G127RequestThrottlingAcrossPinchDoubleTapPagingAndViewport() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetIDs = ["asset-1", "asset-2", "asset-3", "asset-4", "asset-5"]
        let machine = makeMachine(
            configuration: configuration,
            orderedAssetIDs: assetIDs,
            currentIndex: 1
        )
        let strategy = S2ScriptedImageStrategy()
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }

        func applyWindowedPages(viewportSize: CGSize = physicalSize) {
            let firstIndex = max(0, machine.currentIndex - 1)
            let lastIndex = min(
                machine.orderedAssetIDs.count - 1,
                machine.currentIndex + 1
            )
            let state = S2ViewportPresentationState(
                interfaceVisibility: machine.interfaceVisibility,
                bottomStripState: machine.bottomStripState,
                sheetState: machine.sheetState
            )
            let pages = (firstIndex...lastIndex).map { index -> S2NativePageContent in
                let assetID = machine.orderedAssetIDs[index]
                let value = S2ViewportLayout.metrics(
                    physicalSize: viewportSize,
                    presentationState: state,
                    assetAspectRatio: screenAspectRatio,
                    isScreenshot: false,
                    configuration: configuration
                )
                let requestedScale = index == machine.currentIndex
                    ? machine.imageRequestScale
                    : 1
                let requestRevision = machine.imageRequestAssetID == assetID
                    ? machine.imageRequestRevision
                    : 0
                return S2NativePageContent(
                    index: index,
                    assetID: assetID,
                    interfaceVisibility: machine.interfaceVisibility,
                    isFramedPhoto: value.isFramedPhoto,
                    fittedSize: value.oneXDisplaySize,
                    fittedCenterY: value.oneXDisplayCenterY,
                    nativeZoomBaseSize: value.nativeZoomBaseSize,
                    cornerRadius: value.oneXCornerRadius,
                    doubleTapTargetScale: value.doubleTapTargetScale,
                    assetPixelSize: CGSize(
                        width: screenAspectRatio * 1_000,
                        height: 1_000
                    ),
                    contentVersion: S2NativePhotoContentVersion(
                        requestedScale: requestedScale,
                        requestStrategy: configuration.imageRequestStrategy,
                        requestRevision: requestRevision
                    ),
                    content: AnyView(
                        S2TemporaryPhotoImageView(
                            strategy: strategy,
                            assetID: assetID,
                            requestBaseSize: value.nativeZoomBaseSize,
                            requestedScale: requestedScale,
                            requestStrategy: configuration.imageRequestStrategy,
                            requestRevision: requestRevision,
                            showsOpaqueLoadingBackground: true,
                            onReading: { _ in }
                        )
                        .frame(
                            width: value.oneXDisplaySize.width,
                            height: value.oneXDisplaySize.height
                        )
                    )
                )
            }
            controller.view.frame = CGRect(origin: .zero, size: viewportSize)
            controller.apply(
                machine: machine,
                configuration: configuration,
                viewportSize: viewportSize,
                pages: pages,
                onLongPress: {}
            )
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        applyWindowedPages()
        let current = "asset-2"
        XCTAssertEqual(strategy.requestCount(for: current), 1, "初始请求一次")
        XCTAssertEqual(strategy.requestCount(for: "asset-1"), 1)
        XCTAssertEqual(strategy.requestCount(for: "asset-3"), 1)
        XCTAssertEqual(strategy.requestCount(for: "asset-4"), 0, "窗口外不请求")
        let firstPageRequestID = strategy.requests.first { $0.assetID == "asset-1" }?.id
        XCTAssertNotNil(firstPageRequestID)

        // 捏合：连续 s 变化 0 次请求。
        XCTAssertTrue(machine.beginPinch())
        for step in 1...10 {
            machine.reportNativeViewport(
                scale: 1 + CGFloat(step) * 0.1,
                viewportOffset: .zero
            )
            applyWindowedPages()
        }
        XCTAssertEqual(strategy.requestCount(for: current), 1, "捏合中不得请求")

        // 捏合结束 1 次。
        XCTAssertNotNil(machine.finishNativePinch(
            scale: 2,
            viewportOffset: .zero,
            accepted: true
        ))
        applyWindowedPages()
        XCTAssertEqual(strategy.requestCount(for: current), 2, "捏合结束请求一次")

        // 双击退出 Nx 到达 s=1：1 次；再双击进入目标倍率：1 次。
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.zoomState, .oneX)
        applyWindowedPages()
        XCTAssertEqual(strategy.requestCount(for: current), 3, "双击退出请求一次")
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.zoomState, .nX)
        applyWindowedPages()
        XCTAssertEqual(strategy.requestCount(for: current), 4, "双击进入请求一次")
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        applyWindowedPages()
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(strategy.requestCount(for: "asset-1"), 1, "相邻页不受影响")

        // 翻页：新进窗口的 asset-4 请求一次；离开窗口的 asset-1 旧请求被取消；当前页不重复请求。
        let beforePaging = strategy.requestCount
        XCTAssertTrue(machine.handleNativePageChange(to: 2))
        applyWindowedPages()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount(for: "asset-4"), 1, "翻页后新页请求一次")
        XCTAssertEqual(strategy.requestCount(for: "asset-3"), 1, "成为当前页不重复请求")
        XCTAssertEqual(strategy.requestCount - beforePaging, 1, "翻页只新增一次请求")
        // IC-079 起分页控制器保留 currentIndex ± 2 内的页：asset-1 在翻到索引 2 时仍保留，
        // 再翻一页到索引 3 才离开窗口；离开窗口的页旧请求被取消的语义不变。
        XCTAssertFalse(
            strategy.cancelledIDs.contains(firstPageRequestID ?? PHInvalidImageRequestID),
            "仍在保留半径内的页不取消"
        )
        XCTAssertTrue(machine.handleNativePageChange(to: 3))
        applyWindowedPages()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount(for: "asset-5"), 1, "再翻页后新页请求一次")
        XCTAssertEqual(strategy.requestCount(for: "asset-4"), 1, "成为当前页不重复请求")
        XCTAssertTrue(
            strategy.cancelledIDs.contains(firstPageRequestID ?? PHInvalidImageRequestID),
            "离开窗口的页应取消旧请求"
        )

        // 视口尺寸变化：当前页请求一次。
        let beforeResize = strategy.requestCount(for: "asset-4")
        applyWindowedPages(
            viewportSize: CGSize(
                width: physicalSize.width,
                height: physicalSize.height - 120
            )
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(
            strategy.requestCount(for: "asset-4") - beforeResize,
            1,
            "视口尺寸变化请求一次"
        )
    }

    // IC-078 G132 / IC-081 G148 / IC-086 G168：`pinchMaxScale` 取值规则断言表（视口 402×874 pt、
    // displayScale 3、F 按全视口 aspectFit、乘数 6.0、天花板 40）。
    func testIC078G132PinchMaxScaleRuleTable() throws {
        let viewport = CGSize(width: 402, height: 874)
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let parameters = try XCTUnwrap(configuration.resolvedParameters)
        XCTAssertEqual(parameters.pinchMaxScaleFloor, 4)
        XCTAssertEqual(parameters.pinchMaxScaleCeiling, 40)
        XCTAssertEqual(parameters.pinchMaxScaleOneToOneMultiplier, 6)
        let table: [(CGSize, CGFloat)] = [
            (CGSize(width: 1_206, height: 2_622), 6),
            (CGSize(width: 4_032, height: 3_024), 20.06),
            (CGSize(width: 3_024, height: 4_032), 15.04),
            (CGSize(width: 4_672, height: 7_008), 23.24),
            (CGSize(width: 8_000, height: 6_000), 39.80),
            (CGSize(width: 12_000, height: 9_000), 40),
            (CGSize.zero, 4)
        ]
        for (pixelSize, expected) in table {
            let fitSize = S2PinchMaxScaleRule.aspectFitSize(
                assetPixelSize: pixelSize,
                in: viewport
            )
            let value = S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: pixelSize,
                fitSize: fitSize,
                displayScale: 3,
                floor: parameters.pinchMaxScaleFloor,
                ceiling: parameters.pinchMaxScaleCeiling,
                multiplier: parameters.pinchMaxScaleOneToOneMultiplier
            )
            XCTAssertEqual(value, expected, accuracy: 0.01, "\(pixelSize)")
            XCTAssertEqual(
                parameters.pinchMaxScale(
                    assetPixelSize: pixelSize,
                    fitSize: fitSize,
                    displayScale: 3
                ),
                value
            )
        }
        // 基准尺寸为零、倍率非法时取 floor；ceiling < floor 时按 floor 封顶。
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: .zero,
                displayScale: 3,
                floor: 4,
                ceiling: 10,
                multiplier: 2
            ),
            4
        )
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: CGSize(width: 402, height: 301.5),
                displayScale: 0,
                floor: 4,
                ceiling: 10,
                multiplier: 2
            ),
            4
        )
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: CGSize(width: 402, height: 301.5),
                displayScale: 3,
                floor: 4,
                ceiling: 2,
                multiplier: 2
            ),
            4
        )
        // `zoomSnapBackThreshold ≤ pinchMaxScaleFloor` 与 `ceiling ≥ floor` 校验。
        var invalid = configuration
        invalid.zoomSnapBackThreshold = 4.5
        XCTAssertNil(invalid.resolvedParameters)
        invalid = configuration
        invalid.pinchMaxScaleCeiling = 3
        XCTAssertNil(invalid.resolvedParameters)
        // 导出与登记表不再含单一 `pinchMaxScale`。
        let exported = configuration.exportText()
        XCTAssertFalse(exported.contains("pinchMaxScale="))
        XCTAssertTrue(exported.contains("pinchMaxScaleFloor=4"))
        XCTAssertTrue(exported.contains("pinchMaxScaleCeiling=40"))
        XCTAssertTrue(exported.contains("pinchMaxScaleOneToOneMultiplier=6"))
        // 乘数 1 还原 IC-078 的 1:1 取值；乘数 ≤ 0 取 floor。
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: CGSize(width: 402, height: 301.5),
                displayScale: 3,
                floor: 4,
                ceiling: 10,
                multiplier: 1
            ),
            8_000 / 1_206,
            accuracy: 0.01
        )
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: CGSize(width: 402, height: 301.5),
                displayScale: 3,
                floor: 4,
                ceiling: 10,
                multiplier: 0
            ),
            4
        )
        XCTAssertFalse(
            S2CalibrationConfiguration.parameterConnections.contains {
                $0.name == "pinchMaxScale"
            }
        )
    }

    // IC-078 G135（夹具驱动）：每页 maximumZoomScale 按各自资产取值；像素尺寸后到时更新一次，
    // contentOffset / contentSize / contentInset / 照片 frame 不变，照片几何写入事件 0 条。
    func testIC078G135PerPageMaximumZoomScaleFollowsAssetWithoutGeometryWrites() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            configuration: configuration,
            orderedAssetIDs: ["asset-1", "asset-2"],
            currentIndex: 0
        )
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()
        defer { diagnostics.stop() }
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        let first = tryUnwrap(controller.pageControllers[0])
        let second = tryUnwrap(controller.pageControllers[1])
        // 像素尺寸未解析（未登记几何）：两页均为 floor。
        XCTAssertEqual(first.zoomScrollView.maximumZoomScale, 4, accuracy: 0.000_001)
        XCTAssertEqual(second.zoomScrollView.maximumZoomScale, 4, accuracy: 0.000_001)
        XCTAssertEqual(machine.pinchMaxScale(for: "asset-2"), 4)

        struct GeometrySnapshot: Equatable {
            let contentOffset: CGPoint
            let contentSize: CGSize
            let contentInset: UIEdgeInsets
            let photoFrame: CGRect
        }
        func snapshot(_ page: S2NativeZoomPageController) -> GeometrySnapshot {
            GeometrySnapshot(
                contentOffset: page.zoomScrollView.contentOffset,
                contentSize: page.zoomScrollView.contentSize,
                contentInset: page.zoomScrollView.contentInset,
                photoFrame: page.zoomScrollView.presentationContentView?.frame ?? .null
            )
        }
        let firstBefore = snapshot(first)
        let secondBefore = snapshot(second)
        let writesBefore = diagnostics.photoGeometryWriteCount

        // 像素尺寸后到：asset-1 小图 → floor；asset-2 大图 → 1:1 像素倍率。
        let pixelSizes: [String: CGSize] = [
            "asset-1": CGSize(width: 600, height: 1_200),
            "asset-2": CGSize(width: 8_000, height: 6_000)
        ]
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            zoomGeometry: { assetID, fitSize in
                S2AssetZoomGeometry(
                    assetPixelSize: pixelSizes[assetID] ?? .zero,
                    fitSize: fitSize,
                    displayScale: 3
                )
            }
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        let expectedSecond = S2PinchMaxScaleRule.pinchMaxScale(
            assetPixelSize: CGSize(width: 8_000, height: 6_000),
            fitSize: second.zoomScrollView.nativeZoomBaseSize,
            displayScale: 3,
            floor: 4,
            ceiling: 40,
            multiplier: 6
        )
        XCTAssertGreaterThan(expectedSecond, 4)
        XCTAssertEqual(
            second.zoomScrollView.maximumZoomScale,
            expectedSecond,
            accuracy: 0.000_001
        )
        XCTAssertEqual(first.zoomScrollView.maximumZoomScale, 4, accuracy: 0.000_001)
        XCTAssertEqual(machine.pinchMaxScale(for: "asset-2"), expectedSecond)
        XCTAssertEqual(machine.pinchMaxScale(for: "asset-1"), 4)
        XCTAssertEqual(snapshot(first), firstBefore)
        XCTAssertEqual(snapshot(second), secondBefore)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, writesBefore)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
        XCTAssertEqual(first.zoomScrollView.zoomScale, 1)
        XCTAssertEqual(second.zoomScrollView.zoomScale, 1)
    }

    // IC-079 G139：场景 D 逐帧字段与三类新事件按 R1 清单存在（导出头部声明 + 真实采样行 + 样例事件）。
    func testIC079G139FastPagingScenarioExportsWindowFieldsAndEvents() {
        XCTAssertEqual(S2OnDeviceTransitionScenario.fastPaging.exportTitle, "D 快速连续翻页")
        XCTAssertTrue(S2OnDeviceTransitionScenario.allCases.contains(.fastPaging))

        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            configuration: configuration,
            orderedAssetIDs: ["asset-1", "asset-2", "asset-3"],
            currentIndex: 1
        )
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let registry = S2ImageLoadStateRegistry()
        registry.update(.displayed, for: "asset-2")
        registry.update(.loading, for: "asset-3")
        controller.imageLoadStateRegistry = registry
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.selectedScenario = .fastPaging
        diagnostics.start()
        diagnostics.captureFrame()
        diagnostics.recordPageLifecycle(created: true, pageIndex: 3, assetLocalIdentifier: "asset-4")
        diagnostics.recordPageLifecycle(created: false, pageIndex: 0, assetLocalIdentifier: "asset-1")
        diagnostics.recordPagingContentOffsetWrite(offsetX: 320, animated: false, source: "测试来源")
        diagnostics.recordNativePageChange(from: 1, to: 2, accepted: true)
        diagnostics.stop()
        diagnostics.export()

        let text = diagnostics.reportText
        XCTAssertTrue(text.contains("场景=D 快速连续翻页"))
        XCTAssertTrue(text.contains(
            "逐帧字段=time,animationKeys,modelFrame,presentationFrame," +
                "transform,zoomScale,contentOffset,contentSize," +
                "contentInset,adjustedContentInset,V,s," +
                "pagingContentOffsetX,pagingIsDragging,pagingIsDecelerating," +
                "currentIndex,settledIndex,pageIndicesPresent,pageLoadStates," +
                "nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance"
        ))
        let expectedOffsetX = controller.pagingScrollView.contentOffsetForPage(at: 1).x
        XCTAssertTrue(text.contains(
            "\tpagingContentOffsetX=" + String(format: "%.6f", Double(expectedOffsetX))
        ))
        XCTAssertTrue(text.contains("\tpagingIsDragging=false"))
        XCTAssertTrue(text.contains("\tpagingIsDecelerating=false"))
        XCTAssertTrue(text.contains("\tcurrentIndex=1"))
        XCTAssertTrue(text.contains("\tsettledIndex=1"))
        XCTAssertTrue(text.contains("\tpageIndicesPresent=[0,1,2]"))
        XCTAssertTrue(text.contains("\tpageLoadStates=[0=unknown,1=displayed,2=loading]"))
        XCTAssertTrue(text.contains("event=页创建\tsource=S2NativePagerViewController.apply\tdetails=pageIndex=3；asset=asset-4"))
        XCTAssertTrue(text.contains("event=页移除\tsource=S2NativePagerViewController.apply\tdetails=pageIndex=0；asset=asset-1"))
        XCTAssertTrue(text.contains("event=外层setContentOffset\tsource=测试来源\tdetails=x=320.000000；animated=false"))
        XCTAssertTrue(text.contains("event=handleNativePageChange\tsource=S2NativePagerViewController.finishNativePaging\tdetails=from=1；to=2；accepted=true"))

        // 关闭录制时零副作用：记录数不变。
        let countAfterStop = diagnostics.recordedEntries.count
        diagnostics.recordPageLifecycle(created: true, pageIndex: 9, assetLocalIdentifier: "x")
        diagnostics.recordPagingContentOffsetWrite(offsetX: 1, animated: true, source: "x")
        diagnostics.recordNativePageChange(from: 0, to: 1, accepted: false)
        XCTAssertEqual(diagnostics.recordedEntries.count, countAfterStop)
    }

    // IC-079 G141（夹具驱动，真机未覆盖）：生产页窗口 + 页内容提供者。连续两次滚动到 i+2：
    // 经过 i+1 与到达 i+2 时页控制器均已存在；滚动期间外层 setContentOffset(animated:false) 写入 0 次；
    // 结算后 currentIndex == i+2、各页 scale == 1、V 不变；最后一页再滑无越界页创建。
    func testIC079G141FastPagingKeepsPagesPresentWithoutOffsetWrites() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetIDs = (1...6).map { "asset-\($0)" }
        let machine = makeMachine(
            configuration: configuration,
            orderedAssetIDs: assetIDs,
            currentIndex: 1
        )
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.selectedScenario = .fastPaging
        diagnostics.start()
        defer { diagnostics.stop() }

        func page(at index: Int) -> S2NativePageContent? {
            guard assetIDs.indices.contains(index) else {
                return nil
            }
            let state = S2ViewportPresentationState(
                interfaceVisibility: machine.interfaceVisibility,
                bottomStripState: machine.bottomStripState,
                sheetState: machine.sheetState
            )
            let value = S2ViewportLayout.metrics(
                physicalSize: physicalSize,
                presentationState: state,
                assetAspectRatio: screenAspectRatio,
                isScreenshot: true,
                configuration: configuration
            )
            return S2NativePageContent(
                index: index,
                assetID: assetIDs[index],
                interfaceVisibility: machine.interfaceVisibility,
                isFramedPhoto: value.isFramedPhoto,
                fittedSize: value.oneXDisplaySize,
                fittedCenterY: value.oneXDisplayCenterY,
                nativeZoomBaseSize: value.nativeZoomBaseSize,
                cornerRadius: value.oneXCornerRadius,
                doubleTapTargetScale: value.doubleTapTargetScale,
                assetPixelSize: CGSize(width: screenAspectRatio * 1_000, height: 1_000),
                contentVersion: S2NativePhotoContentVersion(
                    requestedScale: 1,
                    requestStrategy: configuration.imageRequestStrategy,
                    requestRevision: 0
                ),
                content: AnyView(Color.clear.frame(
                    width: value.oneXDisplaySize.width,
                    height: value.oneXDisplaySize.height
                ))
            )
        }
        func applyProductionWindow() {
            let firstIndex = max(0, machine.currentIndex - 1)
            let lastIndex = min(assetIDs.count - 1, machine.currentIndex + 1)
            controller.apply(
                machine: machine,
                configuration: configuration,
                viewportSize: physicalSize,
                pages: (firstIndex...lastIndex).compactMap(page(at:)),
                onLongPress: {},
                pageContentProvider: page(at:)
            )
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
        func nonAnimatedOffsetWriteCount() -> Int {
            diagnostics.recordedEntries.filter {
                if case let .event(name, _, details) = $0.payload {
                    return name == "外层setContentOffset" && details.hasSuffix("animated=false")
                }
                return false
            }.count
        }

        applyProductionWindow()
        let paging = controller.pagingScrollView
        let visibilityBefore = machine.interfaceVisibility
        XCTAssertEqual(controller.diagnosticPageIndicesPresent, [0, 1, 2])
        let writesBeforeScrolling = nonAnimatedOffsetWriteCount()

        // 第一次滚动到 i+1 并滚停；SwiftUI 尚未刷新时立即开始第二次滚动。
        controller.scrollViewWillBeginDragging(paging)
        paging.setContentOffset(
            CGPoint(x: paging.contentOffsetForPage(at: 1).x + paging.pageStride * 0.5, y: 0),
            animated: false
        )
        paging.setContentOffset(paging.contentOffsetForPage(at: 2), animated: false)
        controller.scrollViewDidEndDecelerating(paging)
        XCTAssertEqual(machine.currentIndex, 2)

        controller.scrollViewWillBeginDragging(paging)
        paging.setContentOffset(
            CGPoint(x: paging.contentOffsetForPage(at: 2).x + paging.pageStride * 0.5, y: 0),
            animated: false
        )
        XCTAssertNotNil(controller.pageControllers[2], "经过 i+1 时页存在")
        XCTAssertNotNil(controller.pageControllers[3], "滚向 i+2 时目标页已存在")
        paging.setContentOffset(paging.contentOffsetForPage(at: 3), animated: false)
        XCTAssertNotNil(controller.pageControllers[3], "到达 i+2 时页存在")
        XCTAssertNotNil(controller.pageControllers[4], "i+2 的下一页已预先存在")
        controller.scrollViewDidEndDecelerating(paging)

        XCTAssertEqual(
            nonAnimatedOffsetWriteCount() - writesBeforeScrolling,
            0,
            "滚动期间不得有非动画偏移写入"
        )
        XCTAssertEqual(machine.currentIndex, 3)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.interfaceVisibility, visibilityBefore)
        XCTAssertEqual(paging.contentOffset, paging.contentOffsetForPage(at: 3))
        for (_, pageController) in controller.pageControllers {
            XCTAssertEqual(pageController.zoomScrollView.zoomScale, 1, accuracy: 0.000_001)
        }

        // SwiftUI 刷新：窗口 2…4 保留，按需创建的页在保留半径内不被移除。
        applyProductionWindow()
        XCTAssertEqual(controller.diagnosticPageIndicesPresent, [1, 2, 3, 4, 5].filter {
            controller.pageControllers[$0] != nil
        })
        XCTAssertNotNil(controller.pageControllers[2])
        XCTAssertNotNil(controller.pageControllers[3])
        XCTAssertNotNil(controller.pageControllers[4])
        XCTAssertNil(controller.pageControllers[0], "超出保留半径的页被移除")
        XCTAssertEqual(paging.contentOffset, paging.contentOffsetForPage(at: 3))

        // 序列边界：最后一页再滑，无越界页创建。
        XCTAssertTrue(machine.handleNativePageChange(to: 5))
        applyProductionWindow()
        controller.scrollViewWillBeginDragging(paging)
        paging.setContentOffset(
            CGPoint(x: paging.contentOffsetForPage(at: 5).x + 80, y: 0),
            animated: false
        )
        XCTAssertNil(controller.pageControllers[6])
        XCTAssertTrue(controller.diagnosticPageIndicesPresent.allSatisfy { $0 < assetIDs.count })
        paging.setContentOffset(paging.contentOffsetForPage(at: 5), animated: false)
        controller.scrollViewDidEndDecelerating(paging)
        XCTAssertEqual(machine.currentIndex, 5)
    }

    // IC-079 R1 夹具探针（仅打印，不做断言）：生产页窗口（当前页 ±1）下，第一页滚停后、
    // SwiftUI 刷新（重新 apply）前立即开始第二次滚动到 i+2，逐步打印 pageIndicesPresent 与 contentOffset。
    func testIC079R1FastPagingWindowProbe() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetIDs = (1...6).map { "asset-\($0)" }
        let machine = makeMachine(
            configuration: configuration,
            orderedAssetIDs: assetIDs,
            currentIndex: 1
        )
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.selectedScenario = .fastPaging
        diagnostics.start()
        defer { diagnostics.stop() }

        func applyProductionWindow() {
            let firstIndex = max(0, machine.currentIndex - 1)
            let lastIndex = min(assetIDs.count - 1, machine.currentIndex + 1)
            let state = S2ViewportPresentationState(
                interfaceVisibility: machine.interfaceVisibility,
                bottomStripState: machine.bottomStripState,
                sheetState: machine.sheetState
            )
            let pages = (firstIndex...lastIndex).map { index -> S2NativePageContent in
                let value = S2ViewportLayout.metrics(
                    physicalSize: physicalSize,
                    presentationState: state,
                    assetAspectRatio: screenAspectRatio,
                    isScreenshot: true,
                    configuration: configuration
                )
                return S2NativePageContent(
                    index: index,
                    assetID: assetIDs[index],
                    interfaceVisibility: machine.interfaceVisibility,
                    isFramedPhoto: value.isFramedPhoto,
                    fittedSize: value.oneXDisplaySize,
                    fittedCenterY: value.oneXDisplayCenterY,
                    nativeZoomBaseSize: value.nativeZoomBaseSize,
                    cornerRadius: value.oneXCornerRadius,
                    doubleTapTargetScale: value.doubleTapTargetScale,
                    assetPixelSize: CGSize(width: screenAspectRatio * 1_000, height: 1_000),
                    contentVersion: S2NativePhotoContentVersion(
                        requestedScale: 1,
                        requestStrategy: configuration.imageRequestStrategy,
                        requestRevision: 0
                    ),
                    content: AnyView(Color.clear.frame(
                        width: value.oneXDisplaySize.width,
                        height: value.oneXDisplaySize.height
                    ))
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
        let paging = controller.pagingScrollView
        func dump(_ step: String) {
            let target = paging.pageIndex(forContentOffsetX: paging.contentOffset.x)
            print("[IC-079 探针] \(step)：currentIndex=\(machine.currentIndex) settledIndex=\(controller.settledIndex) contentOffsetX=\(paging.contentOffset.x) 偏移所在页=\(target) pageIndicesPresent=\(controller.diagnosticPageIndicesPresent) 目标页存在=\(controller.pageControllers[target] != nil)")
        }

        applyProductionWindow()
        dump("0 初始（窗口 i±1）")
        // 第一次滚动：到 i+1 并滚停（原生减速结束回调）。
        paging.setContentOffset(paging.contentOffsetForPage(at: 2), animated: false)
        dump("1 第一次滚动到 i+1（滚停前）")
        controller.scrollViewDidEndDecelerating(paging)
        dump("2 第一次滚停（finishNativePaging 后，SwiftUI 尚未刷新）")
        // 第二次滚动在 SwiftUI 刷新前立即开始：目标 i+2。
        paging.setContentOffset(paging.contentOffsetForPage(at: 3), animated: false)
        dump("3 第二次滚动到 i+2（刷新前）")
        controller.scrollViewDidEndDecelerating(paging)
        dump("4 第二次滚停（finishNativePaging 后）")
        applyProductionWindow()
        dump("5 SwiftUI 刷新（重新 apply 窗口）后")
        // 边界：最后一页再滑。
        _ = machine.handleNativePageChange(to: 5)
        applyProductionWindow()
        paging.setContentOffset(CGPoint(x: paging.contentOffsetForPage(at: 5).x + 80, y: 0), animated: false)
        dump("6 最后一页再滑 80pt（越界）")
        controller.scrollViewDidEndDecelerating(paging)
        dump("7 越界滚停")

        diagnostics.stop()
        diagnostics.export()
        for line in diagnostics.reportText.split(separator: "\n")
        where line.contains("kind=event") &&
            (line.contains("外层setContentOffset") || line.contains("页创建") ||
                line.contains("页移除") || line.contains("handleNativePageChange")) {
            print("[IC-079 探针事件] \(line)")
        }
    }

    // IC-081 G149（夹具驱动，真机未覆盖）：面板调节乘数后经 applyCalibration + 重新 apply，
    // 当前页与相邻页 maximumZoomScale 按新乘数即时更新；contentOffset / contentSize / contentInset /
    // 照片 frame 不变，照片几何写入事件 0 条。
    func testIC081G149MultiplierChangeUpdatesMaximumZoomScaleWithoutGeometryWrites() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            configuration: configuration,
            orderedAssetIDs: ["asset-1", "asset-2"],
            currentIndex: 0
        )
        let pixelSizes: [String: CGSize] = [
            "asset-1": CGSize(width: 4_032, height: 3_024),
            "asset-2": CGSize(width: 600, height: 1_200)
        ]
        let zoomGeometry: (String, CGSize) -> S2AssetZoomGeometry? = { assetID, fitSize in
            S2AssetZoomGeometry(
                assetPixelSize: pixelSizes[assetID] ?? .zero,
                fitSize: fitSize,
                displayScale: 3
            )
        }
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            zoomGeometry: zoomGeometry
        )
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()
        defer { diagnostics.stop() }
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        let current = tryUnwrap(controller.pageControllers[0])
        let next = tryUnwrap(controller.pageControllers[1])
        func expected(multiplier: CGFloat) -> CGFloat {
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: pixelSizes["asset-1"]!,
                fitSize: current.zoomScrollView.nativeZoomBaseSize,
                displayScale: 3,
                floor: 4,
                ceiling: 40,
                multiplier: multiplier
            )
        }
        XCTAssertEqual(
            current.zoomScrollView.maximumZoomScale,
            expected(multiplier: 6),
            accuracy: 0.000_001
        )
        XCTAssertEqual(next.zoomScrollView.maximumZoomScale, 4, accuracy: 0.000_001)

        struct GeometrySnapshot: Equatable {
            let contentOffset: CGPoint
            let contentSize: CGSize
            let contentInset: UIEdgeInsets
            let photoFrame: CGRect
        }
        func snapshot(_ page: S2NativeZoomPageController) -> GeometrySnapshot {
            GeometrySnapshot(
                contentOffset: page.zoomScrollView.contentOffset,
                contentSize: page.zoomScrollView.contentSize,
                contentInset: page.zoomScrollView.contentInset,
                photoFrame: page.zoomScrollView.presentationContentView?.frame ?? .null
            )
        }
        let currentBefore = snapshot(current)
        let nextBefore = snapshot(next)
        let writesBefore = diagnostics.photoGeometryWriteCount

        // 面板把乘数拖到 1.0：当前页上限回到 1:1（4032/900 ≈ 4.48），相邻页仍为 floor。
        configuration.pinchMaxScaleOneToOneMultiplier = 1
        XCTAssertTrue(machine.applyCalibration(configuration))
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            zoomGeometry: zoomGeometry
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let unit = expected(multiplier: 1)
        XCTAssertNotEqual(unit, expected(multiplier: 6))
        XCTAssertEqual(current.zoomScrollView.maximumZoomScale, unit, accuracy: 0.000_001)
        XCTAssertEqual(machine.pinchMaxScale(for: "asset-1"), unit, accuracy: 0.000_001)
        XCTAssertEqual(next.zoomScrollView.maximumZoomScale, 4, accuracy: 0.000_001)

        // 再拖到 3.0：上限按新乘数重写（3 × 4032/1206 ≈ 10.03，低于 ceiling 40）。
        configuration.pinchMaxScaleOneToOneMultiplier = 3
        XCTAssertTrue(machine.applyCalibration(configuration))
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            zoomGeometry: zoomGeometry
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        XCTAssertEqual(
            current.zoomScrollView.maximumZoomScale,
            expected(multiplier: 3),
            accuracy: 0.000_001
        )

        XCTAssertEqual(snapshot(current), currentBefore)
        XCTAssertEqual(snapshot(next), nextBefore)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, writesBefore)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
        XCTAssertEqual(current.zoomScrollView.zoomScale, 1)
        XCTAssertEqual(machine.scale, 1)
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

    // R2（IC-077 改写）：出厂 degradedPreviewPolicy=.display，降质预览进入显示序列并由最终图原位替换。
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

        XCTAssertEqual(displayed, [.degradedPreview, .finalImage])
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

    // D1 再改写（IC-104 C）：截图适配到 chrome 带内，横竖两种资产比例都成立。
    func testD1ScreenshotAspectFitsIntoChromeBand() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        // IC-104 C v3：带顶缘按视口高推导，用 `.zero` 安全区与夹具视口配对
        // （g = 90 − 48 = 42 > 0）；真实机型配对由 testIC104C 覆盖。
        let insets = S2OverlaySafeAreaInsets.zero
        let bandHeight = S2ViewportLayout.screenshotBandHeight(
            physicalSize: physicalSize,
            safeAreaInsets: insets,
            bottomStripHeight: max(
                CGFloat(configuration.bottomStripCurrentItemSize),
                CGFloat(configuration.bottomStripNeighborItemHeight)
            )
        )
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: insets
        )

        // 竖向资产：带高受限，显示高恰为带高
        XCTAssertEqual(
            value.oneXDisplaySize.height,
            bandHeight,
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            value.oneXDisplaySize.height,
            value.aspectFitSize.height
        )

        // 横向资产：视口宽受限，显示宽恰为视口宽，且不超出带高
        let oppositeOrientation = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1 / screenAspectRatio,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: insets
        )
        XCTAssertEqual(
            oppositeOrientation.oneXDisplaySize.width,
            physicalSize.width,
            accuracy: 0.000_001
        )
        XCTAssertLessThanOrEqual(
            oppositeOrientation.oneXDisplaySize.height,
            bandHeight + 0.000_001
        )
    }

    // D2 改写（IC-104 C v3）：带顶缘只随视口高变，带底缘随安全区底与 g 变。
    func testD2ScreenshotBandAdaptsToSafeArea() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let stripHeight = max(
            CGFloat(configuration.bottomStripCurrentItemSize),
            CGFloat(configuration.bottomStripNeighborItemHeight)
        )
        // IC-104 C v3：`.zero` 起算，两种安全区下 g 分别为 42 与 32，均 > 0。
        let base = S2OverlaySafeAreaInsets.zero
        let taller = S2OverlaySafeAreaInsets(
            top: base.top + 10,
            leading: base.leading,
            bottom: base.bottom + 7,
            trailing: base.trailing
        )

        let baseBand = S2ViewportLayout.screenshotBandHeight(
            physicalSize: physicalSize,
            safeAreaInsets: base,
            bottomStripHeight: stripHeight
        )
        let tallerBand = S2ViewportLayout.screenshotBandHeight(
            physicalSize: physicalSize,
            safeAreaInsets: taller,
            bottomStripHeight: stripHeight
        )

        // IC-104 C v3：带顶缘只随视口高变（0.15 × H），与安全区顶无关；
        // 安全区顶 +10 令 g 减小 10、带底缘随之下移 10，安全区底 +7 令横栏
        // 顶缘上移 7 —— 净效果为带高 +10 − 7 = +3。
        XCTAssertEqual(tallerBand - baseBand, 3, accuracy: 0.000_001)

        // 显示尺寸随之变化，视口尺寸不受影响
        let baseMetrics = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: base
        )
        let tallerMetrics = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: taller
        )
        XCTAssertEqual(
            tallerMetrics.oneXDisplaySize.height -
                baseMetrics.oneXDisplaySize.height,
            3,
            accuracy: 0.000_001
        )
        XCTAssertEqual(baseMetrics.viewportSize, tallerMetrics.viewportSize)
        // 带顶缘与安全区无关，两种安全区下完全一致
        XCTAssertEqual(
            S2ViewportLayout.screenshotBandTop(physicalSize: physicalSize),
            physicalSize.height * 0.15,
            accuracy: 0.000_001
        )
    }

    // D3 改写：即使旧作用范围为全部照片，非截图的 1x 显示仍不变。
    func testD3AllPhotosScopeLeavesNonScreenshotUnchanged() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: false,
            configuration: configuration
        )

        XCTAssertEqual(value.oneXDisplaySize, value.aspectFitSize)
        XCTAssertEqual(value.oneXCornerRadius, 0)
        XCTAssertFalse(value.isFramedPhoto)
    }

    // D4 替代断言：屏幕比例照片的原生目标矩形采用最小目标倍数 2。
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
        let assetAspectRatio: CGFloat = 0.75
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false,
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
            isScreenshot: false,
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

    // N1：主图使用原生可缩放容器，倍率上下限分别为 1 与 pinchMaxScaleFloor（IC-078：像素尺寸未解析时的值）。
    func testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let scrollView = makeNativeZoomScrollView(configuration: configuration)

        XCTAssertTrue(scrollView is UIScrollView)
        XCTAssertEqual(scrollView.minimumZoomScale, 1)
        XCTAssertEqual(
            scrollView.maximumZoomScale,
            CGFloat(configuration.pinchMaxScaleFloor),
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
            isScreenshot: false,
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

    // IC-063：原生基准切换布局尺寸时，不把捏合开始误报为图片视口变化。
    func testIC063NativeBaseResizeIssuesNoImageRequestBeforePinchEnd() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let requestCounter = S2ImageRequestCounter()
        let content = S2TemporaryPhotoImageView(
            strategy: requestCounter,
            assetID: "asset-1",
            requestBaseSize: physicalSize,
            requestedScale: 1,
            requestStrategy: configuration.imageRequestStrategy,
            requestRevision: 0,
            showsOpaqueLoadingBackground: true,
            onReading: { _ in }
        )
        let controller = UIHostingController(rootView: content)
        let container = UIViewController()
        container.addChild(controller)
        controller.view.frame = CGRect(
            origin: .zero,
            size: CGSize(width: 210, height: 420)
        )
        container.view.addSubview(controller.view)
        controller.didMove(toParent: container)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = container
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertGreaterThan(requestCounter.requestCount, 0)
        requestCounter.reset()

        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(requestCounter.requestCount, 0)
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

    // G2 替代断言：Nx 竖向滑动由原生平移接管，不进入标记识别器。
    func testG2NxVerticalSwipeRecognizerYieldsToNativePan() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(scale: 2, configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertFalse(page.shouldBeginVerticalSwipe(
            for: CGPoint(x: 0, y: -100)
        ))
        XCTAssertTrue(page.zoomScrollView.panGestureRecognizer.isEnabled)
        XCTAssertEqual(machine.scale, 2)
    }

    // G9：Nx 上滑不得改变待删集合 D 或当前序号 c。
    func testG9NxSwipeUpLeavesDeletionSetAndCurrentIndexUnchanged() {
        let machine = makeMachine(scale: 2)
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let originalDeletionSet = machine.pendingDeletionAssetIDs
        let originalIndex = machine.currentIndex

        XCTAssertFalse(page.shouldBeginVerticalSwipe(
            for: CGPoint(x: 0, y: -100)
        ))
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalDeletionSet)
        XCTAssertEqual(machine.currentIndex, originalIndex)
    }

    // G10：Nx 下滑不得改变待删集合 D 或当前序号 c。
    func testG10NxSwipeDownLeavesDeletionSetAndCurrentIndexUnchanged() {
        let machine = makeMachine(
            scale: 2,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let originalDeletionSet = machine.pendingDeletionAssetIDs
        let originalIndex = machine.currentIndex

        XCTAssertFalse(page.shouldBeginVerticalSwipe(
            for: CGPoint(x: 0, y: 100)
        ))
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalDeletionSet)
        XCTAssertEqual(machine.currentIndex, originalIndex)
    }

    // G11：Nx 竖向拖动由 UIScrollView 改变 y 偏移，且结果留在内容边界内。
    func testG11NxVerticalPanChangesContentOffsetWithinNativeBounds() {
        let machine = makeMachine(scale: 2)
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let scrollView = page.zoomScrollView
        let originalOffsetY = scrollView.contentOffset.y
        let minimumOffsetY = -scrollView.adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            scrollView.contentSize.height +
                scrollView.adjustedContentInset.bottom -
                scrollView.bounds.height
        )
        let targetOffsetY = min(maximumOffsetY, originalOffsetY + 24)

        XCTAssertFalse(page.shouldBeginVerticalSwipe(
            for: CGPoint(x: 0, y: -100)
        ))
        XCTAssertTrue(scrollView.panGestureRecognizer.isEnabled)
        XCTAssertGreaterThan(targetOffsetY, originalOffsetY)
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: targetOffsetY),
            animated: false
        )
        XCTAssertGreaterThan(scrollView.contentOffset.y, originalOffsetY)
        XCTAssertGreaterThanOrEqual(
            scrollView.contentOffset.y,
            minimumOffsetY - 0.000_001
        )
        XCTAssertLessThanOrEqual(
            scrollView.contentOffset.y,
            maximumOffsetY + 0.000_001
        )
    }

    // G12：捏合吸附回严格 1x 后，竖向标记语义立即恢复。
    func testG12PinchSnapBackImmediatelyRestoresSwipeUpMarking() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            scale: 1.05,
            configuration: configuration
        )
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let originalAssetID = machine.currentAssetID

        XCTAssertTrue(machine.beginPinch())
        controller.finishNativePinch(
            on: page,
            scale: 1.05,
            displacement: 0.01,
            peakVelocity: 0,
            duration: 0.05
        )

        XCTAssertEqual(machine.scale, 1)
        XCTAssertTrue(page.shouldBeginVerticalSwipe(
            for: CGPoint(x: 0, y: -100)
        ))
        XCTAssertTrue(controller.finishVerticalSwipe(
            on: page,
            translation: CGSize(width: 0, height: -40),
            duration: 0.4
        ))
        XCTAssertTrue(machine.pendingDeletionAssetIDs.contains(originalAssetID))
    }

    // IC-063 G1 改写：隐藏态的屏幕比例截图等比适配物理屏幕。
    func testIC063G1HiddenScreenAspectScreenshotMatchesScreenBounds() {
        let viewportSize = UIScreen.main.bounds.size
        let assetRatio = viewportSize.width / viewportSize.height
        let machine = makeMachine(interfaceVisibility: .hidden)
        let controller = makeNativePagerController(
            machine: machine,
            assetAspectRatio: assetRatio,
            isScreenshot: true,
            viewportSize: viewportSize
        )
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let inner = tryUnwrap(page.zoomScrollView.presentationContentView)
        let frame = inner.convert(inner.bounds, to: window)

        XCTAssertEqual(frame.minX, UIScreen.main.bounds.minX, accuracy: 0.5)
        XCTAssertEqual(frame.minY, UIScreen.main.bounds.minY, accuracy: 0.5)
        XCTAssertEqual(frame.width, UIScreen.main.bounds.width, accuracy: 0.5)
        XCTAssertEqual(frame.height, UIScreen.main.bounds.height, accuracy: 0.5)
    }

    // IC-063 G2 再改写（IC-104 C）：裁切截图适配到 chrome 带且四边居中。
    func testIC063G2VisibleCroppedScreenshotUsesAspectFitInsetAndIsCentered() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let croppedScreenshotRatio: CGFloat = 0.1823
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            assetAspectRatio: croppedScreenshotRatio,
            isScreenshot: true
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let frame = tryUnwrap(page.zoomScrollView.visiblePresentationFrame())
        // 夹具未传 safeAreaInsets，带高按 `.zero` 安全区推导
        let expectedBand = S2ViewportLayout.screenshotBandHeight(
            physicalSize: physicalSize,
            safeAreaInsets: .zero,
            bottomStripHeight: max(
                CGFloat(configuration.bottomStripCurrentItemSize),
                CGFloat(configuration.bottomStripNeighborItemHeight)
            )
        )

        XCTAssertEqual(
            frame.height,
            expectedBand,
            accuracy: 0.5
        )
        XCTAssertEqual(
            frame.width,
            expectedBand * croppedScreenshotRatio,
            accuracy: 0.5
        )
        XCTAssertEqual(frame.minX, physicalSize.width - frame.maxX, accuracy: 0.5)
        // IC-104 C v3：竖直不再对称于视口——顶缘落在带顶缘、中心落在带中心。
        XCTAssertEqual(
            frame.minY,
            S2ViewportLayout.screenshotBandTop(physicalSize: physicalSize),
            accuracy: 0.5
        )
        XCTAssertEqual(
            frame.midY,
            expectedScreenshotBandCenterY(configuration: configuration),
            accuracy: 0.5
        )
        XCTAssertEqual(
            page.cornerRadius,
            CGFloat(configuration.fitCornerRadius)
        )
        XCTAssertEqual(
            page.fitBorderLayer.borderWidth,
            CGFloat(configuration.fitBorderWidth)
        )
    }

    // IC-063 G3 改写：双击仍按屏幕比例分类，不受截图元数据控制。
    func testIC063G3DoubleTapTargetStillUsesScreenAspectClassification() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let screenRatioOrdinaryPhoto = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: false,
            configuration: configuration
        )
        let nonMatchedRatio: CGFloat = 0.75
        let croppedScreenshot = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: nonMatchedRatio,
            isScreenshot: true,
            configuration: configuration
        )
        let fill = tryUnwrap(S2Geometry.aspectFillMultiplier(
            viewportSize: physicalSize,
            assetAspectRatio: nonMatchedRatio
        ))

        XCTAssertEqual(configuration.minDoubleTapScale, 2, accuracy: 0.000_001)
        XCTAssertFalse(screenRatioOrdinaryPhoto.isFramedPhoto)
        XCTAssertEqual(
            screenRatioOrdinaryPhoto.doubleTapTargetScale,
            2,
            accuracy: 0.000_001
        )
        XCTAssertTrue(croppedScreenshot.isFramedPhoto)
        XCTAssertEqual(
            croppedScreenshot.doubleTapTargetScale,
            fill,
            accuracy: 0.000_001
        )
    }

    // IC-063 G4：双击两向动画均保持原生倍率不动，终点同步帧视觉相等。
    func testIC063G4DoubleTapSynchronizationPreservesWindowFrameBothWays() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2)
        ))
        XCTAssertTrue(page.isDoubleTapTransitionActive)
        XCTAssertEqual(page.zoomScrollView.zoomScale, 1, accuracy: 0.000_001)
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )
        XCTAssertEqual(page.zoomScrollView.zoomScale, 1, accuracy: 0.000_001)
        XCTAssertTrue(
            tryUnwrap(page.zoomScrollView.presentationContentView)
                .transform.isIdentity
        )
        let entryTransition = tryUnwrap(page.lastDoubleTapTransition)
        page.finishActiveDoubleTapTransition()
        let entrySynchronization = tryUnwrap(
            page.lastDoubleTapSynchronization
        )
        XCTAssertLessThanOrEqual(
            entrySynchronization.maximumDifference,
            0.5,
            "进入同步前=\(entrySynchronization.beforeWindowFrame)，" +
                "同步后=\(entrySynchronization.afterWindowFrame)"
        )

        let nxScale = page.zoomScrollView.zoomScale
        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2)
        ))
        XCTAssertTrue(page.isDoubleTapTransitionActive)
        XCTAssertEqual(page.zoomScrollView.zoomScale, nxScale, accuracy: 0.000_001)
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )
        XCTAssertEqual(
            page.zoomScrollView.zoomScale,
            nxScale,
            accuracy: 0.000_001
        )
        XCTAssertTrue(
            tryUnwrap(page.zoomScrollView.presentationContentView)
                .transform.isIdentity
        )
        let exitTransition = tryUnwrap(page.lastDoubleTapTransition)
        for progress in [CGFloat(0), 0.25, 0.5, 0.75, 1] {
            let reading = S2DoubleTapSynchronizationReading(
                beforeWindowFrame: entryTransition.frame(at: progress),
                afterWindowFrame: exitTransition.frame(at: 1 - progress)
            )
            XCTAssertLessThanOrEqual(
                reading.maximumDifference,
                0.5,
                "进度=\(progress)，进入帧=\(reading.beforeWindowFrame)，" +
                    "退出反向帧=\(reading.afterWindowFrame)"
            )
            XCTAssertEqual(
                entryTransition.cornerRadius(at: progress),
                exitTransition.cornerRadius(at: 1 - progress),
                accuracy: 0.5
            )
        }
        page.finishActiveDoubleTapTransition()
        XCTAssertLessThanOrEqual(
            tryUnwrap(page.lastDoubleTapSynchronization).maximumDifference,
            0.5
        )
    }

    // IC-063 G5：Nx 切换 V 不改变任何原生几何量或圆角。
    func testIC063G5NxVisibilityTogglePreservesNativeGeometryAndCorner() {
        let machine = makeMachine(
            scale: 2,
            viewportOffset: CGSize(width: 24, height: 16)
        )
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let before = (
            page.zoomScrollView.zoomScale,
            page.zoomScrollView.contentOffset,
            page.zoomScrollView.contentSize,
            page.zoomScrollView.visiblePresentationFrame(),
            page.zoomScrollView.presentationContentView?.layer.cornerRadius
        )

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )

        XCTAssertEqual(page.zoomScrollView.zoomScale, before.0)
        XCTAssertEqual(page.zoomScrollView.contentOffset, before.1)
        XCTAssertEqual(page.zoomScrollView.contentSize, before.2)
        XCTAssertEqual(page.zoomScrollView.visiblePresentationFrame(), before.3)
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.layer.cornerRadius,
            before.4
        )
    }

    // IC-063 G6：Nx 延迟显隐目标在退出时只提交一次。
    func testIC063G6NxDeferredPresentationCommitsExactlyOnceOnExit() {
        let machine = makeMachine(scale: 2)
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let hidden = metrics(visibility: .hidden)

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )
        XCTAssertTrue(page.hasDeferredPresentation)
        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2)
        ))

        XCTAssertEqual(page.presentationGeometryCommitCount, 1)
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, hidden.oneXCornerRadius)
        XCTAssertFalse(page.hasDeferredPresentation)
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )
        XCTAssertEqual(page.presentationGeometryCommitCount, 1)
    }

    // IC-063 G7：内外滚动视图运行时均明确关闭安全区自动 inset。
    func testIC063G7AllPhotoScrollViewsReadBackNeverAdjustment() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertEqual(
            controller.pagingScrollView.contentInsetAdjustmentBehavior,
            .never
        )
        XCTAssertEqual(
            page.zoomScrollView.contentInsetAdjustmentBehavior,
            .never
        )
        XCTAssertEqual(page.additionalSafeAreaInsets, .zero)
        XCTAssertEqual(page.diagnosticAdditionalSafeAreaInsets, .zero)
    }

    // IC-063 G8：新旧几何契约共用同一测试靶，不以替代状态机规避回归。
    func testIC063G8NativePagerStillUsesOriginalStateMachineInstance() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(controller.diagnosticMachine?.currentAssetID, machine.currentAssetID)
    }

    // 内置诊断：自动完成八类时机采样并输出可复制报告。
    func testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages() {
        let screenBounds = UIScreen.main.bounds
        let diagnosticAspectRatio = screenBounds.width / screenBounds.height
        let machine = makeMachine()
        let calibration = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        let diagnostics = S2GeometryDiagnosticsCoordinator()
        let view = S2View(
            machine: machine,
            calibration: calibration,
            assetAspectRatio: { _ in diagnosticAspectRatio },
            assetIsScreenshot: { _ in true },
            assetPixelSize: { _ in
                CGSize(width: diagnosticAspectRatio * 3_000, height: 3_000)
            },
            photoContent: { _ in AnyView(Color.gray) },
            stripItemContent: { _ in AnyView(Color.clear) },
            albumPickerContent: { _, _ in AnyView(EmptyView()) },
            geometryDiagnostics: diagnostics
        )
        let hostingController = UIHostingController(rootView: view)
        let window: UIWindow
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            window = UIWindow(windowScene: windowScene)
            window.frame = screenBounds
        } else {
            window = UIWindow(frame: screenBounds)
        }
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertNotNil(hostingController.view.window)

        let attachmentDeadline = Date(timeIntervalSinceNow: 2)
        while !diagnostics.isExporting,
              diagnostics.reportText.isEmpty,
              Date() < attachmentDeadline {
            diagnostics.export()
            if !diagnostics.isExporting {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            }
        }
        XCTAssertTrue(
            diagnostics.isExporting || !diagnostics.reportText.isEmpty,
            "诊断协调器应在期限内挂载并开始导出"
        )
        let deadline = Date(timeIntervalSinceNow: 10)
        while diagnostics.isExporting, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        let report = diagnostics.reportText
        XCTAssertFalse(diagnostics.isExporting)
        XCTAssertTrue(report.contains("中间帧门禁：通过"))
        XCTAssertTrue(report.contains("V=显示、s=1 稳定态"))
        XCTAssertTrue(report.contains("单击后 V=隐藏、s=1 稳定态"))
        XCTAssertTrue(report.contains("双击进入 Nx：动画结束稳定态"))
        XCTAssertTrue(report.contains("双击退出 Nx：动画结束稳定态"))
        XCTAssertGreaterThanOrEqual(
            report.components(separatedBy: "双击进入 Nx：动画中间帧").count - 1,
            3
        )
        XCTAssertGreaterThanOrEqual(
            report.components(separatedBy: "双击退出 Nx：动画中间帧").count - 1,
            5
        )
        XCTAssertTrue(report.contains("Q1："))
        XCTAssertTrue(report.contains("Q2："))
        XCTAssertTrue(report.contains("Q3："))
        XCTAssertTrue(report.contains("Q4："))
        XCTAssertTrue(report.contains(
            "Q1：顶部空白 0.000000px；contentInset=0.000000px，" +
                "safeAreaInsets=0.000000px，aspectFit=0.000000px；" +
                "加和=0.000000px。"
        ))
        XCTAssertTrue(report.contains(
            "Q2：s>1 全部样本内层 transform 恒等=true"
        ))
        XCTAssertTrue(report.contains("稳定 Nx zoomScale=2.000000"))
        XCTAssertTrue(report.contains("进入动画原生 zoomScale 恒定=true"))
        XCTAssertTrue(report.contains("退出动画原生 zoomScale 恒定=true"))
        XCTAssertTrue(report.contains(
            "zoomScale 与内层 transform 同时非默认=false"
        ))
        XCTAssertTrue(report.contains(
            "动画帧内层 transform 恒等=true"
        ))
        XCTAssertTrue(report.contains(
            "专用过渡层 transform 全部六元组分量单调=true"
        ))
        XCTAssertTrue(report.contains("动画帧 contentOffset 无跳变=true"))
        XCTAssertTrue(report.contains(
            "Q4：V=显示时状态栏隐藏=false；" +
                "V=隐藏时状态栏隐藏=true。"
        ))
        print("IC063_DIAGNOSTICS_SAMPLE_BEGIN\n\(report)\nIC063_DIAGNOSTICS_SAMPLE_END")
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
        let assetAspectRatio: CGFloat = 0.75
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false,
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
            assetAspectRatio: assetAspectRatio
        ))
        XCTAssertEqual(
            legacyMachine.scale,
            value.aspectFillMultiplier,
            accuracy: 0.000_001
        )
    }

    // F1 改写（IC-104 C v2）：显示态截图的 1x 高度等于 chrome 带高。
    func testF1FactoryFitBoxMatchesChromeBandHeight() {
        let value = metrics()

        XCTAssertEqual(
            value.oneXDisplaySize.height,
            expectedScreenshotBandHeight(),
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            value.oneXDisplaySize.height,
            value.aspectFitSize.height
        )
    }

    // F2 改写：圆角仅随截图元数据生效，普通照片严格为零。
    func testF2CornerRadiusAppliesOnlyToScreenshots() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let matching = metrics(configuration: configuration)
        let nonMatching = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: false,
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
            page.zoomScrollView.presentationContentView?.layer.cornerRadius,
            CGFloat(configuration.fitCornerRadius)
        )
        XCTAssertEqual(
            page.zoomScrollView.zoomContentView?.layer.cornerRadius,
            0
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
            isScreenshot: false,
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
            isScreenshot: false,
            configuration: configuration
        )

        XCTAssertFalse(visible.isFramedPhoto)
        XCTAssertEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)
        XCTAssertEqual(hidden.oneXCornerRadius, visible.oneXCornerRadius)
    }

    // F4 改写（IC-104 C）：chrome 带只改变 1x 显示尺寸，不改变视口或填满倍数基准。
    func testF4ChromeBandDoesNotChangeViewportOrAspectFillMultiplier() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        // IC-104 C v3：带顶缘按视口高推导，用 `.zero` 安全区与夹具视口配对
        // （g = 90 − 48 = 42 > 0）；真实机型配对由 testIC104C 覆盖。
        let insets = S2OverlaySafeAreaInsets.zero
        let plain = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: false,
            configuration: configuration,
            safeAreaInsets: insets
        )
        let framed = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: true,
            configuration: configuration,
            safeAreaInsets: insets
        )

        XCTAssertNotEqual(plain.oneXDisplaySize, framed.oneXDisplaySize)
        XCTAssertEqual(plain.viewportSize, framed.viewportSize)
        XCTAssertEqual(plain.aspectFitSize, framed.aspectFitSize)
        XCTAssertEqual(
            plain.aspectFillMultiplier,
            framed.aspectFillMultiplier,
            accuracy: 0.000_001
        )
    }

    // IC-082 G152：场景 E `nxEdgePaging` 逐帧追加三个字段、三类事件逐条存在；关闭录制零副作用。
    func testIC082G152NxEdgePagingScenarioExportsFieldsAndEvents() {
        XCTAssertEqual(S2OnDeviceTransitionScenario.nxEdgePaging.exportTitle, "E Nx 贴边翻页")
        XCTAssertTrue(S2OnDeviceTransitionScenario.allCases.contains(.nxEdgePaging))

        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.selectedScenario = .nxEdgePaging
        diagnostics.start()
        diagnostics.captureFrame()
        diagnostics.recordHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: 60,
            velocity: 300,
            accepted: true,
            source: "S2NativePagerViewController.reportSequenceBoundaryAttemptIfNeeded"
        )
        diagnostics.recordSynchronizeNativeState(
            animatedPaging: true,
            currentIndex: 2,
            scale: 1
        )
        diagnostics.stop()
        diagnostics.export()

        let text = diagnostics.reportText
        XCTAssertTrue(text.contains("场景=E Nx 贴边翻页"))
        XCTAssertTrue(text.contains(
            "逐帧字段=time,animationKeys,modelFrame,presentationFrame," +
                "transform,zoomScale,contentOffset,contentSize," +
                "contentInset,adjustedContentInset,V,s," +
                "pagingContentOffsetX,pagingIsDragging,pagingIsDecelerating," +
                "currentIndex,settledIndex,pageIndicesPresent,pageLoadStates," +
                "nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance"
        ))
        // 非贴边拖动期间三个字段为 nil；内层 contentOffset / contentSize / zoomScale 与外层偏移既有字段同在。
        XCTAssertTrue(text.contains("\tnxDistanceToPreviousBoundary=nil\tnxDistanceToNextBoundary=nil\tnxOverflowDistance=nil"))
        XCTAssertTrue(text.contains("\tzoomScale=1.000000\tcontentOffset="))
        XCTAssertTrue(text.contains("\tcontentSize="))
        XCTAssertTrue(text.contains("\tpagingContentOffsetX="))
        XCTAssertTrue(text.contains("\tpagingIsDragging=false\tpagingIsDecelerating=false"))
        XCTAssertTrue(text.contains("\tcurrentIndex=1"))
        // IC-082 R3：自定义投影路径已删除，`beginNXEdgePaging` 不再产生；
        // `handleHorizontalSwipe` 仅由序列边界尝试路径记录。
        XCTAssertFalse(text.contains("event=beginNXEdgePaging"))
        XCTAssertTrue(text.contains(
            "event=handleHorizontalSwipe\tsource=S2NativePagerViewController.reportSequenceBoundaryAttemptIfNeeded" +
                "\tdetails=direction=next；startedAtPagingEdge=true；distance=60.000000；velocity=300.000000；accepted=true"
        ))
        XCTAssertTrue(text.contains(
            "event=synchronizeNativeStateToMachine\tsource=S2NativePagerViewController.synchronizeNativeStateToMachine" +
                "\tdetails=animatedPaging=true；currentIndex=2；s=1.000000"
        ))

        let countAfterStop = diagnostics.recordedEntries.count
        diagnostics.recordHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: false,
            distance: 0,
            velocity: 0,
            accepted: false,
            source: "测试来源"
        )
        diagnostics.recordSynchronizeNativeState(animatedPaging: false, currentIndex: 1, scale: 1)
        diagnostics.captureFrame()
        XCTAssertEqual(diagnostics.recordedEntries.count, countAfterStop)
    }

    // IC-082 G153（R2，R3 后改为状态机层）：贴边起始条件由 UIKit 嵌套滚动交接天然满足——
    // 起始不贴边时内层先消耗位移、外层不动；状态机对显式的 startedAtPagingEdge 仍按三条正反规则钳制：
    // 起始不贴边 + 溢出 60pt + 阈值速度 → 不翻页；起始贴边 + 同样溢出 → 翻页；起始贴边 + 溢出 39pt → 不翻页。
    func testIC082G153NxEdgePagingRequiresEdgeAtDragStart() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let velocity = CGFloat(configuration.edgePagingTriggerVelocity)

        let offEdgeMachine = makeMachine(scale: 2, configuration: configuration)
        XCTAssertFalse(offEdgeMachine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: false,
            distance: 60,
            velocity: velocity
        ))
        XCTAssertEqual(offEdgeMachine.currentIndex, 1)
        XCTAssertEqual(offEdgeMachine.scale, 2)

        let atEdgeMachine = makeMachine(scale: 2, configuration: configuration)
        XCTAssertTrue(atEdgeMachine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: 60,
            velocity: velocity
        ))
        XCTAssertEqual(atEdgeMachine.currentIndex, 2)
        XCTAssertEqual(atEdgeMachine.scale, 1)

        let shortMachine = makeMachine(scale: 2, configuration: configuration)
        XCTAssertFalse(shortMachine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: 39,
            velocity: velocity
        ))
        XCTAssertEqual(shortMachine.currentIndex, 1)
        XCTAssertEqual(shortMachine.scale, 2)
    }

    // IC-082 G154（R3，夹具驱动，真机未覆盖）：Nx 下内层未贴边时外层偏移不变；内层贴边后外层随原生
    // 拖动变化并经 finishNativePaging 结算：currentIndex+1、新页与旧页 scale 均为 1、V 不变；
    // 全程外层偏移写入只来自原生路径（apply / layoutNativePages / synchronizeNativeStateToMachine），无自定义投影来源。
    func testIC082G154NxPagingHandsOffToOuterNativeScrollWithoutCustomWrites() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(scale: 2, configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.selectedScenario = .nxEdgePaging
        diagnostics.start()
        defer { diagnostics.stop() }

        let paging = controller.pagingScrollView
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let inner = page.zoomScrollView
        XCTAssertEqual(machine.zoomState, .nX)
        XCTAssertEqual(inner.zoomScale, 2, accuracy: 0.000_001)
        XCTAssertFalse(inner.bounces)
        XCTAssertTrue(paging.isPagingEnabled)
        let restingOffset = paging.contentOffsetForPage(at: machine.currentIndex)
        XCTAssertEqual(paging.contentOffset, restingOffset)
        let visibilityBefore = machine.interfaceVisibility

        // 内层未贴边：内层向左平移一段，外层偏移不变，无任何非动画外层写入。
        let writesBefore = diagnostics.recordedEntries.filter { entry in
            if case let .event(name, _, _) = entry.payload {
                return name == "外层setContentOffset"
            }
            return false
        }.count
        let maxInnerX = inner.contentSize.width - inner.bounds.width
        XCTAssertGreaterThan(maxInnerX, 0)
        inner.setContentOffset(CGPoint(x: maxInnerX / 2, y: inner.contentOffset.y), animated: false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        XCTAssertEqual(paging.contentOffset, restingOffset, "内层未贴边时外层不动")
        let writesMid = diagnostics.recordedEntries.filter { entry in
            if case let .event(name, _, _) = entry.payload {
                return name == "外层setContentOffset"
            }
            return false
        }.count
        XCTAssertEqual(writesMid - writesBefore, 0)

        // 内层贴边后：外层由原生拖动接管（夹具以 pan 回调 + 偏移驱动），结算为翻页。
        inner.setContentOffset(CGPoint(x: maxInnerX, y: inner.contentOffset.y), animated: false)
        let previousIndex = machine.currentIndex
        controller.scrollViewWillBeginDragging(paging)
        paging.setContentOffset(
            CGPoint(x: restingOffset.x + paging.pageStride * 0.5, y: restingOffset.y),
            animated: false
        )
        paging.setContentOffset(paging.contentOffsetForPage(at: previousIndex + 1), animated: false)
        controller.scrollViewDidEndDecelerating(paging)

        XCTAssertEqual(machine.currentIndex, previousIndex + 1)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.interfaceVisibility, visibilityBefore)
        XCTAssertEqual(inner.zoomScale, 1, accuracy: 0.000_001, "旧页复位")
        let newPage = tryUnwrap(controller.pageControllers[machine.currentIndex])
        XCTAssertEqual(newPage.zoomScrollView.zoomScale, 1, accuracy: 0.000_001, "新页 s=1")
        XCTAssertEqual(paging.contentOffset, paging.contentOffsetForPage(at: machine.currentIndex))

        let sources = diagnostics.recordedEntries.compactMap { entry -> String? in
            if case let .event(name, source, _) = entry.payload, name == "外层setContentOffset" {
                return source
            }
            return nil
        }
        let nativeSources: Set<String> = [
            "S2NativePagerViewController.apply",
            "S2NativePagerViewController.layoutNativePages",
            "S2NativePagerViewController.synchronizeNativeStateToMachine"
        ]
        XCTAssertTrue(
            sources.allSatisfy { nativeSources.contains($0) },
            "外层偏移写入来源只能是原生路径：\(sources)"
        )
        XCTAssertFalse(diagnostics.recordedEntries.contains { entry in
            if case let .event(name, _, _) = entry.payload {
                return name == "beginNXEdgePaging"
            }
            return false
        })
        XCTAssertTrue(diagnostics.recordedEntries.contains { entry in
            if case let .event(name, _, details) = entry.payload {
                return name == "handleNativePageChange" && details.hasSuffix("accepted=true")
            }
            return false
        })
        diagnostics.captureFrame()
        diagnostics.stop()
        diagnostics.export()
        XCTAssertTrue(diagnostics.reportText.contains(
            "\tnxDistanceToPreviousBoundary=nil\tnxDistanceToNextBoundary=nil\tnxOverflowDistance=nil"
        ))
    }

    // B1（IC-082 R3 删除）：自定义溢出投影已移除，Nx 边界后的外层位移由 UIKit 嵌套滚动交接产生；
    // 对应断言见 testIC082G154…。

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

    // S1 改写（IC-104 C v2）：框显照片在显示态适配 chrome 带，圆角 28 点。
    func testS1FramedPhotoVisibleStateFitsChromeBandAndRadiusTwentyEight() {
        let value = metrics(visibility: .visible)

        XCTAssertTrue(value.isFramedPhoto)
        XCTAssertEqual(
            value.oneXDisplaySize.height,
            expectedScreenshotBandHeight(),
            accuracy: 0.000_001
        )
        XCTAssertEqual(value.oneXCornerRadius, 28, accuracy: 0.000_001)
    }

    // S2 替代断言：框显照片隐藏后两轴严格填满视口且圆角归零。
    func testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let hidden = metrics(
            visibility: .hidden,
            configuration: configuration
        )
        let visible = metrics(
            visibility: .visible,
            configuration: configuration
        )

        XCTAssertTrue(hidden.isFramedPhoto)
        XCTAssertEqual(
            hidden.oneXDisplaySize.width,
            hidden.viewportSize.width,
            accuracy: 1
        )
        XCTAssertEqual(
            hidden.oneXDisplaySize.height,
            hidden.viewportSize.height,
            accuracy: 1
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
        XCTAssertTrue(page.isPresentationTransitionActive)
        XCTAssertEqual(page.fittedSize, visible.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, visible.oneXCornerRadius)
        XCTAssertEqual(
            page.lastPresentationTransitionDuration,
            0.22,
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

    // X2：动画期间保留源态 frame 基准，显示层只承载终点等比 transform。
    func testX2ImmersiveTransitionKeepsLayoutSizeAndUsesTransform() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let contentSize = page.zoomScrollView.contentSize

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
        XCTAssertEqual(page.fittedSize, transition.layoutSize)
        XCTAssertEqual(page.zoomScrollView.fittedSize, transition.layoutSize)
        XCTAssertEqual(page.zoomScrollView.contentSize, contentSize)
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.bounds.size,
            transition.layoutSize
        )
        XCTAssertEqual(transform.a, transition.targetScale, accuracy: 0.000_001)
        XCTAssertEqual(transform.b, 0, accuracy: 0.000_001)
        XCTAssertEqual(transform.c, 0, accuracy: 0.000_001)
        XCTAssertEqual(transform.d, transition.targetScale, accuracy: 0.000_001)
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
        let hidingContentView = tryUnwrap(
            page.zoomScrollView.presentationContentView
        )
        XCTAssertEqual(
            hidingContentView.layer.cornerRadius *
                abs(hidingContentView.transform.a),
            hiding.frame(at: 1).cornerRadius,
            accuracy: 0.000_001
        )
        page.finishActivePresentationTransition()
        XCTAssertEqual(hidingContentView.layer.cornerRadius, 0)

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
        let showingContentView = tryUnwrap(
            page.zoomScrollView.presentationContentView
        )
        XCTAssertEqual(
            showingContentView.layer.cornerRadius *
                abs(showingContentView.transform.a),
            showing.frame(at: 1).cornerRadius,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            showing.layerCornerRadius(at: 1),
            CGFloat(configuration.fitCornerRadius),
            accuracy: 0.000_001
        )
        page.finishActivePresentationTransition()
        XCTAssertEqual(
            showingContentView.layer.cornerRadius,
            showing.layerCornerRadius(at: 1),
            accuracy: 0.000_001
        )
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

    // Y1：系统状态栏随界面隐藏态隐藏、随显示态恢复，并共用显隐时长。
    func testY1StatusBarTracksHiddenAndVisibleInterfaceStates() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let visibleAppearance = S2StatusBarAppearance(
            interfaceVisibility: .visible,
            configuration: configuration
        )
        let hiddenAppearance = S2StatusBarAppearance(
            interfaceVisibility: .hidden,
            configuration: configuration
        )

        XCTAssertFalse(visibleAppearance.isHidden)
        XCTAssertTrue(hiddenAppearance.isHidden)
        XCTAssertEqual(
            hiddenAppearance.transitionDuration,
            S2AnimationPolicy(configuration: configuration).durationSeconds,
            accuracy: 0.000_001
        )

        let machine = makeMachine(configuration: configuration)
        let calibration = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        let view = S2View(
            machine: machine,
            calibration: calibration,
            assetAspectRatio: { _ in self.screenAspectRatio },
            assetIsScreenshot: { _ in true },
            photoContent: { context in
                AnyView(Color.clear.frame(
                    width: context.fittedSize.width,
                    height: context.fittedSize.height
                ))
            },
            stripItemContent: { _ in AnyView(Color.clear) },
            albumPickerContent: { _, _ in AnyView(EmptyView()) }
        )
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertFalse(controller.prefersStatusBarHidden)
        XCTAssertTrue(machine.handleSingleTap())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(controller.prefersStatusBarHidden)
        XCTAssertTrue(machine.handleSingleTap())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(controller.prefersStatusBarHidden)
        window.isHidden = true
    }

    // Y2 改写：比例偏离屏幕的截图在隐藏态等比适配全视口且圆角为零。
    func testY2CroppedScreenshotHiddenDisplayUsesFullViewportAspectFit() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetAspectRatio: CGFloat = 0.1823
        let visible = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: assetAspectRatio,
            isScreenshot: true,
            configuration: configuration
        )
        let hidden = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .hidden,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: assetAspectRatio,
            isScreenshot: true,
            configuration: configuration
        )

        XCTAssertTrue(hidden.isFramedPhoto)
        XCTAssertNotEqual(hidden.aspectFitSize, hidden.viewportSize)
        XCTAssertEqual(hidden.oneXDisplaySize, hidden.aspectFitSize)
        XCTAssertEqual(hidden.oneXCornerRadius, 0)

        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: true
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: true
        )

        let targetFrame = tryUnwrap(page.lastPresentationTransition).frame(at: 1)
        XCTAssertEqual(
            visible.oneXDisplaySize.width * targetFrame.scaleX,
            hidden.oneXDisplaySize.width,
            accuracy: 1
        )
        XCTAssertEqual(
            visible.oneXDisplaySize.height * targetFrame.scaleY,
            hidden.oneXDisplaySize.height,
            accuracy: 1
        )
        page.finishActivePresentationTransition()
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, 0)
    }

    // Y3：未命中照片在两种界面状态下的尺寸和圆角均保持不变。
    func testY3NonMatchingPhotoGeometryRemainsUnchangedInBothVisibilityStates() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetAspectRatio: CGFloat = 1
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

        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let initialSize = page.fittedSize
        let initialRadius = page.cornerRadius
        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false
        )

        XCTAssertFalse(page.isPresentationTransitionActive)
        XCTAssertEqual(page.fittedSize, initialSize)
        XCTAssertEqual(page.cornerRadius, initialRadius)
    }

    // Y4 替代断言：双击退出只由专用过渡层驱动，原生倍率在同步前不变。
    func testY4DoubleTapExitUsesSingleNativeMinimumZoomAnimationWithoutOffsetWrite() {
        let machine = makeMachine(
            scale: 2,
            viewportOffset: CGSize(width: 24, height: 16)
        )
        let controller = makeNativePagerController(machine: machine)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let nativeScale = page.zoomScrollView.zoomScale

        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: 150, y: 300)
        ))

        XCTAssertTrue(page.isDoubleTapTransitionActive)
        XCTAssertEqual(page.zoomScrollView.zoomScale, nativeScale)
        XCTAssertEqual(controller.nativeZoomReturnInvocationCount, 0)
        XCTAssertEqual(
            page.zoomScrollView.minimumZoomScaleAnimationInvocationCount,
            0
        )
        page.finishActiveDoubleTapTransition()
        XCTAssertEqual(page.zoomScrollView.zoomScale, 1)
        XCTAssertLessThanOrEqual(
            tryUnwrap(page.lastDoubleTapSynchronization).maximumDifference,
            0.5
        )
    }

    // Y5：低于吸附阈值的捏合归位继续使用原生 UIScrollView 动画。
    func testY5PinchSnapBackUsesSameSingleNativeMinimumZoomAnimationPath() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            scale: 1.05,
            viewportOffset: CGSize(width: 8, height: 4),
            configuration: configuration
        )
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let initialOffsetWriteCount = page.zoomScrollView
            .independentContentOffsetWriteCount

        XCTAssertTrue(machine.beginPinch())
        controller.finishNativePinch(
            on: page,
            scale: 1.05,
            displacement: 0.01,
            peakVelocity: 0,
            duration: 0.05
        )

        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(controller.nativeZoomReturnInvocationCount, 1)
        XCTAssertEqual(
            page.zoomScrollView.minimumZoomScaleAnimationInvocationCount,
            1
        )
        XCTAssertEqual(
            page.zoomScrollView.lastMinimumZoomScaleAnimationTarget,
            page.zoomScrollView.minimumZoomScale
        )
        XCTAssertEqual(
            page.zoomScrollView.lastMinimumZoomScaleAnimationWasAnimated,
            true
        )
        XCTAssertEqual(
            page.zoomScrollView.independentContentOffsetWriteCount,
            initialOffsetWriteCount
        )
    }

    // Y6：原生退出完成后归一倍率与偏移，并按当前隐藏态提交沉浸终点。
    func testY6ZoomExitCompletionNormalizesStateAndAppliesCurrentPresentation() {
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
        XCTAssertTrue(page.hasDeferredPresentation)
        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: 150, y: 300)
        ))

        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
        XCTAssertEqual(page.zoomScrollView.zoomScale, 1)
        XCTAssertEqual(page.zoomScrollView.reportedViewportOffset(), .zero)
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, hidden.oneXCornerRadius)
        XCTAssertEqual(page.presentationGeometryCommitCount, 1)
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

    // IC-065 G26：高度受限、窄于视口的完整适配照片在 1x 水平居中。
    func testIC065G26WidthLimitedOneXIsHorizontallyCentered() {
        let hosted = makeIC065HostedPage(assetAspectRatio: 478.0 / 2_622.0)
        defer { hosted.window.isHidden = true }
        let frame = ic065PresentationFrameInWindow(
            page: hosted.page,
            window: hosted.window
        )

        XCTAssertLessThan(frame.width, hosted.window.bounds.width)
        XCTAssertEqual(
            frame.midX,
            hosted.window.bounds.midX,
            accuracy: 0.5
        )
    }

    // IC-065 G27 改写（IC-104 C v3）：矮于视口的截图在 `s = 1` 显示态居中于
    // **适配带**（④ 带锚定），顶缘落在 0.15 × 视口高。
    func testIC065G27HeightLimitedOneXSitsAtBandCenter() {
        let hosted = makeIC065HostedPage(assetAspectRatio: 9.0 / 16.0)
        defer { hosted.window.isHidden = true }
        let frame = ic065PresentationFrameInWindow(
            page: hosted.page,
            window: hosted.window
        )

        XCTAssertLessThan(frame.height, hosted.window.bounds.height)
        XCTAssertEqual(
            frame.midY,
            expectedScreenshotBandCenterY(),
            accuracy: 0.5
        )
        XCTAssertEqual(
            frame.minY,
            S2ViewportLayout.screenshotBandTop(physicalSize: physicalSize),
            accuracy: 0.5
        )
        // 带中心与视口中心之差即 `s > 1` 进入瞬间的跳变量，恒 > 0
        XCTAssertEqual(
            hosted.window.bounds.midY - frame.midY,
            expectedOneXToNxCenterJump(),
            accuracy: 0.5
        )
    }

    // IC-065 G28～G29 改述（IC-104 C v3）：60Hz presentation 轨迹全程，每一帧的
    // 中心恒等于其所处 `s` 态的**规定中心**——`s = 1` 帧为适配带中心（④ 带锚定），
    // `s > 1` 帧为视口中心（SPEC 决策 20「跳到该基准」）。两者之差即接管首帧的
    // 位置跳变量，本身写成精确契约；接管之后各帧之间不再有跳变。
    func testIC065G28ToG29PinchTrackCentersPerZoomState() {
        let samples: [(String, CGFloat)] = [
            ("width_limited", 478.0 / 2_622.0),
            ("height_limited", 9.0 / 16.0)
        ]
        let scales: [CGFloat] = [1.001, 1.05, 1.10, 1.25, 1.50, 2, 3, 4]

        for (name, assetAspectRatio) in samples {
            let hosted = makeIC065HostedPage(
                assetAspectRatio: assetAspectRatio
            )
            defer { hosted.window.isHidden = true }
            let scrollView = hosted.page.zoomScrollView
            let sampler = IC065PinchPresentationSampler(
                scrollView: scrollView,
                window: hosted.window
            )

            sampler.start()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            scrollView.prepareForNativeZoom()
            sampler.mark("pinch_began")
            RunLoop.main.run(
                until: Date(timeIntervalSinceNow: 1.0 / 60.0)
            )
            for scale in scales {
                scrollView.setZoomScale(scale, animated: false)
                scrollView.setNeedsLayout()
                scrollView.layoutIfNeeded()
                sampler.mark(String(format: "scale_%.3f", scale))
                RunLoop.main.run(
                    until: Date(timeIntervalSinceNow: 1.0 / 60.0)
                )
            }
            let trace = sampler.stop()

            let oneX = tryUnwrap(trace.first { $0.phase == "one_x" })
            let pinchBegan = tryUnwrap(
                trace.first { $0.phase == "pinch_began" }
            )
            let firstGrowth = tryUnwrap(
                trace.first { $0.phase == "scale_1.001" }
            )
            let bandCenterY = expectedScreenshotBandCenterY()
            let viewportMidY = hosted.window.bounds.midY
            // 横向全程无跳变（水平中心不受 ④ 影响）
            XCTAssertLessThanOrEqual(
                abs(pinchBegan.frameInWindow.midX - oneX.frameInWindow.midX),
                0.5
            )
            XCTAssertLessThanOrEqual(
                abs(firstGrowth.frameInWindow.midX -
                    pinchBegan.frameInWindow.midX),
                0.5
            )
            // 竖向：`s = 1` 帧居中于带，接管首帧起居中于视口
            XCTAssertEqual(
                oneX.frameInWindow.midY,
                bandCenterY,
                accuracy: 0.5,
                "样本=\(name)"
            )
            XCTAssertEqual(
                pinchBegan.frameInWindow.midY,
                viewportMidY,
                accuracy: 0.5,
                "样本=\(name)"
            )
            // 跳变量恰为两中心之差（精确契约，非容差放宽）
            XCTAssertEqual(
                pinchBegan.frameInWindow.midY - oneX.frameInWindow.midY,
                expectedOneXToNxCenterJump(),
                accuracy: 0.5,
                "样本=\(name)"
            )
            // 接管之后各帧之间不再有跳变
            XCTAssertLessThanOrEqual(
                abs(firstGrowth.frameInWindow.midY -
                    pinchBegan.frameInWindow.midY),
                0.5
            )
            XCTAssertGreaterThanOrEqual(trace.count, scales.count * 2)
            for (index, sample) in trace.enumerated() {
                let frame = sample.frameInWindow
                let viewport = hosted.window.bounds
                if frame.width < viewport.width - 0.5 {
                    XCTAssertEqual(
                        frame.midX,
                        viewport.midX,
                        accuracy: 0.5,
                        "样本=\(name)，序号=\(index)"
                    )
                }
                if frame.height < viewport.height - 0.5 {
                    // 每帧中心取其所处 `s` 态的规定中心
                    XCTAssertEqual(
                        frame.midY,
                        sample.phase == "one_x"
                            ? bandCenterY
                            : viewport.midY,
                        accuracy: 0.5,
                        "样本=\(name)，序号=\(index)，阶段=\(sample.phase)"
                    )
                }
            }
        }
    }

    // IC-065 G30：大于视口的方向只使用原生内容边界，不增加额外余量。
    func testIC065G30OversizedDirectionsUseNativeContentBounds() {
        let assetAspectRatios: [CGFloat] = [
            478.0 / 2_622.0,
            9.0 / 16.0
        ]
        for assetAspectRatio in assetAspectRatios {
            let hosted = makeIC065HostedPage(
                assetAspectRatio: assetAspectRatio
            )
            defer { hosted.window.isHidden = true }
            let scrollView = hosted.page.zoomScrollView
            scrollView.prepareForNativeZoom()

            for scale in [CGFloat(1.001), 2, 4] {
                scrollView.setZoomScale(scale, animated: false)
                scrollView.setNeedsLayout()
                scrollView.layoutIfNeeded()
                let maximumOffset = CGPoint(
                    x: max(0, scrollView.contentSize.width -
                        scrollView.bounds.width),
                    y: max(0, scrollView.contentSize.height -
                        scrollView.bounds.height)
                )
                if scrollView.contentSize.width >
                    scrollView.bounds.width + 0.5 {
                    XCTAssertEqual(scrollView.contentInset.left, 0)
                    XCTAssertEqual(scrollView.contentInset.right, 0)
                    XCTAssertGreaterThanOrEqual(scrollView.contentOffset.x, 0)
                    XCTAssertLessThanOrEqual(
                        scrollView.contentOffset.x,
                        maximumOffset.x
                    )
                }
                if scrollView.contentSize.height >
                    scrollView.bounds.height + 0.5 {
                    XCTAssertEqual(scrollView.contentInset.top, 0)
                    XCTAssertEqual(scrollView.contentInset.bottom, 0)
                    XCTAssertGreaterThanOrEqual(scrollView.contentOffset.y, 0)
                    XCTAssertLessThanOrEqual(
                        scrollView.contentOffset.y,
                        maximumOffset.y
                    )
                }
            }
        }
    }

    // IC-065 G31 改写：截图元数据继续保持 IC-063 G1～G2 的等比与内缩结果。
    func testIC065G31ScreenshotMetadataKeepsIC063Geometry() {
        let assetAspectRatio = screenAspectRatio * 1.008
        let states: [S2InterfaceVisibility] = [.hidden, .visible]

        for visibility in states {
            let hosted = makeIC065HostedPage(
                assetAspectRatio: assetAspectRatio,
                interfaceVisibility: visibility,
                isScreenshot: true
            )
            defer { hosted.window.isHidden = true }
            let expected = S2ViewportLayout.metrics(
                physicalSize: physicalSize,
                presentationState: S2ViewportPresentationState(
                    interfaceVisibility: visibility,
                    bottomStripState: .idle,
                    sheetState: .closed
                ),
                assetAspectRatio: assetAspectRatio,
                isScreenshot: true,
                configuration: .factoryPlaceholder
            )
            let frame = ic065PresentationFrameInWindow(
                page: hosted.page,
                window: hosted.window
            )

            XCTAssertTrue(expected.isFramedPhoto)
            // IC-104 C v2：带高由多项加减推导，经渲染层往返后与直接计算值
            // 存在 ~1e-13 的浮点噪声（旧口径是单次乘法，两侧位级相同）。
            XCTAssertEqual(
                frame.size.width,
                expected.oneXDisplaySize.width,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                frame.size.height,
                expected.oneXDisplaySize.height,
                accuracy: 0.000_001
            )
            XCTAssertEqual(frame.midX, hosted.window.bounds.midX, accuracy: 0.5)
            // IC-104 C v3：竖直中心取该 `V` 的规定中心——显示态为带中心、
            // 隐藏态为视口中心（沉浸填满）。
            XCTAssertEqual(
                frame.midY,
                expected.oneXDisplayCenterY,
                accuracy: 0.5
            )
        }
    }

    // IC-065 G32 改写：C8 替代线性序列后，两方向仍共用同一 spring。
    func testIC065G32BothDirectionsUseSameSpringCurveAndDuration() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let curve = S2PresentationSpringCurve(
            dampingRatio: configuration.presentationToggleDamping
        )
        let policy = S2AnimationPolicy(
            configuration: configuration,
            durationMilliseconds: configuration.presentationToggleDuration
        )

        XCTAssertEqual(policy.durationSeconds, 0.22, accuracy: 0.000_001)
        for step in 0...100 {
            let progress = CGFloat(step) / 100
            let value = curve.value(at: progress)
            let hidingWidth = 210 + 90 * value
            let showingWidth = 300 - 90 * value
            XCTAssertEqual(
                hidingWidth + showingWidth,
                510,
                accuracy: 0.000_001
            )
        }
    }

    // IC-065 G34：校准参数中没有引入任何捏合锚点字段。
    func testIC065G34DoesNotAddPinchAnchorParameters() {
        let parameterNames = Mirror(
            reflecting: S2CalibrationConfiguration.factoryPlaceholder
        ).children.compactMap(\.label)
        XCTAssertFalse(parameterNames.contains {
            let normalized = $0.lowercased()
            return normalized.contains("pinch") &&
                normalized.contains("anchor")
        })
    }

    // IC-067 G36 改写（IC-104 C v2）：裁切截图在显示态等比适配到 chrome 带，
    // 隐藏态沉浸填满全视口；圆角仍只在显示态出现。
    func testIC067G36CroppedScreenshotUsesMetadataDrivenAspectFitFrame() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetAspectRatio: CGFloat = 0.1823
        let visible = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: assetAspectRatio,
            isScreenshot: true,
            configuration: configuration
        )
        let hidden = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .hidden,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: assetAspectRatio,
            isScreenshot: true,
            configuration: configuration
        )
        // 两处调用都未传 safeAreaInsets，故带高按 `.zero` 安全区推导
        let expectedBand = S2ViewportLayout.screenshotBandHeight(
            physicalSize: physicalSize,
            safeAreaInsets: .zero,
            bottomStripHeight: max(
                CGFloat(configuration.bottomStripCurrentItemSize),
                CGFloat(configuration.bottomStripNeighborItemHeight)
            )
        )

        XCTAssertTrue(visible.isFramedPhoto)
        XCTAssertEqual(
            visible.oneXDisplaySize.height,
            expectedBand,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            visible.oneXDisplaySize.width,
            expectedBand * assetAspectRatio,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            visible.oneXCornerRadius,
            CGFloat(configuration.fitCornerRadius)
        )
        // 隐藏态沉浸不变（规格 v16 第 121/177 行）：填满视口、圆角为 0
        XCTAssertEqual(hidden.oneXDisplaySize, hidden.aspectFitSize)
        XCTAssertNotEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)
        XCTAssertEqual(hidden.oneXCornerRadius, 0)

        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: true
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let frame = page.zoomScrollView.oneXPresentationFrame
        XCTAssertEqual(frame.midX, physicalSize.width / 2, accuracy: 0.5)
        // IC-104 C v3：显示态截图的 `s = 1` 中心为带中心。
        XCTAssertEqual(
            frame.midY,
            expectedScreenshotBandCenterY(configuration: configuration),
            accuracy: 0.5
        )
        XCTAssertEqual(
            page.fitBorderLayer.borderWidth,
            CGFloat(configuration.fitBorderWidth)
        )
    }

    // IC-067 G37：普通照片两种 V 均使用全视口等比适配，且单击前后几何不变。
    func testIC067G37NonScreenshotGeometryAndDecorationStayUnchanged() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetAspectRatio: CGFloat = 9.0 / 16.0
        let visible = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false,
            configuration: configuration
        )
        let hidden = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .hidden,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false,
            configuration: configuration
        )

        XCTAssertFalse(visible.isFramedPhoto)
        XCTAssertEqual(visible.oneXDisplaySize, visible.aspectFitSize)
        XCTAssertEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)
        XCTAssertEqual(visible.oneXCornerRadius, 0)
        XCTAssertEqual(hidden.oneXCornerRadius, 0)

        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let before = tryUnwrap(
            page.zoomScrollView.visiblePresentationFrame()
        )
        XCTAssertEqual(page.fitBorderLayer.borderWidth, 0)
        XCTAssertTrue(page.applyRecognizedSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: false
        )
        let after = tryUnwrap(
            page.zoomScrollView.visiblePresentationFrame()
        )

        XCTAssertEqual(after, before)
        XCTAssertEqual(page.cornerRadius, 0)
        XCTAssertEqual(page.fitBorderLayer.borderWidth, 0)
        XCTAssertNil(page.lastPresentationTransition)
    }

    // IC-064 G13～G18 改写：显示层端点与 CA 关键帧满足双向 spring。
    func testIC064G13ToG18PresentationSamplesMeetGeometryContract() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        // IC-104 C v2：显示态端点改由 chrome 带推导；
        // 隐藏态端点仍是视口全尺寸（规格 v16 第 121/177 行的截图沉浸）。
        let visibleMetrics = metrics(
            visibility: .visible,
            configuration: configuration
        )
        let visibleSize = visibleMetrics.oneXDisplaySize
        let visibleCenterY = visibleMetrics.oneXDisplayCenterY

        let hiding = capturePresentationToggle(
            machine: machine,
            controller: controller,
            page: page,
            configuration: configuration
        )
        let hidingScaleKeyframes = page.lastPresentationScaleKeyframes
        let hidingLayoutReading = controller.presentationTapLayoutReading
        let hiddenFrame = page.zoomScrollView.visiblePresentationFrame()
        let hiddenStableSamples = captureStablePresentationWindow(
            page: page,
            duration: 0.30
        )
        let showing = capturePresentationToggle(
            machine: machine,
            controller: controller,
            page: page,
            configuration: configuration
        )
        let showingScaleKeyframes = page.lastPresentationScaleKeyframes
        let showingPositionKeyframes = page.lastPresentationPositionKeyframes
        let showingLayoutReading = controller.presentationTapLayoutReading
        let visibleFrame = page.zoomScrollView.visiblePresentationFrame()
        let visibleStableSamples = captureStablePresentationWindow(
            page: page,
            duration: 0.30
        )

        XCTAssertGreaterThanOrEqual(hiding.count, 3)
        XCTAssertGreaterThanOrEqual(showing.count, 3)
        XCTAssertGreaterThanOrEqual(hiddenStableSamples.count, 3)
        XCTAssertGreaterThanOrEqual(visibleStableSamples.count, 3)
        XCTAssertTrue(hiddenStableSamples.allSatisfy { $0.frame == hiddenFrame })
        XCTAssertTrue(visibleStableSamples.allSatisfy { $0.frame == visibleFrame })
        XCTAssertGreaterThan(
            Set(hidingScaleKeyframes.map {
                Int(($0 * visibleSize.width * 1_000).rounded())
            }).count,
            3
        )
        XCTAssertGreaterThan(
            Set(showingScaleKeyframes.map {
                Int(($0 * physicalSize.width * 1_000).rounded())
            }).count,
            3
        )
        XCTAssertEqual(
            hiding.last?.timestamp ?? 0,
            showing.last?.timestamp ?? 0,
            accuracy: 0.010
        )
        XCTAssertEqual(hiding.last?.timestamp ?? 0, 0.22, accuracy: 0.020)
        XCTAssertEqual(showing.last?.timestamp ?? 0, 0.22, accuracy: 0.020)
        for sample in hiding + showing {
            let aspectRatio = sample.frame.height > 0
                ? sample.frame.width / sample.frame.height
                : 0
            let scaleX = sample.bounds.width > 0
                ? sample.frame.width / sample.bounds.width
                : 0
            let scaleY = sample.bounds.height > 0
                ? sample.frame.height / sample.bounds.height
                : 0
            XCTAssertEqual(
                aspectRatio,
                screenAspectRatio,
                accuracy: screenAspectRatio * 0.01
            )
            XCTAssertEqual(
                sample.frame.midX,
                physicalSize.width / 2,
                accuracy: 0.5
            )
            // IC-104 C v3：两端点不同心，midY 在过渡期间随 spring 平移，
            // 故逐采样只核区间（含过冲余量），端点由下方精确断言把关。
            let lowerBound = min(visibleCenterY, physicalSize.height / 2)
            let upperBound = max(visibleCenterY, physicalSize.height / 2)
            let overshoot = (upperBound - lowerBound) * 0.10 + 0.5
            XCTAssertGreaterThanOrEqual(
                sample.frame.midY,
                lowerBound - overshoot
            )
            XCTAssertLessThanOrEqual(
                sample.frame.midY,
                upperBound + overshoot
            )
            XCTAssertEqual(
                sample.bounds.width / sample.bounds.height,
                screenAspectRatio,
                accuracy: screenAspectRatio * 0.01
            )
            XCTAssertEqual(scaleX, scaleY, accuracy: max(scaleX, scaleY) * 0.01)
            XCTAssertEqual(
                sample.contentsRect,
                CGRect(x: 0, y: 0, width: 1, height: 1)
            )
        }
        XCTAssertEqual(hiding.first?.bounds.size ?? .zero, visibleSize)
        XCTAssertEqual(hiding.last?.bounds.size ?? .zero, physicalSize)
        XCTAssertEqual(showing.first?.bounds.size ?? .zero, physicalSize)
        XCTAssertEqual(showing.last?.bounds.size ?? .zero, visibleSize)
        // IC-104 C v3：位置关键帧与 scale 同组同长度，端点覆盖两个中心。
        XCTAssertEqual(
            showingPositionKeyframes.count,
            showingScaleKeyframes.count
        )
        XCTAssertGreaterThanOrEqual(showingPositionKeyframes.count, 3)
        XCTAssertEqual(
            showingPositionKeyframes.last?.y ?? -1,
            visibleCenterY,
            accuracy: 0.5
        )
        XCTAssertEqual(
            showingPositionKeyframes.first?.y ?? -1,
            physicalSize.height / 2,
            accuracy: 0.5
        )
        // IC-104 C v3：端点摆放为精确断言——显示端 = 带中心，隐藏端 = 视口中心。
        XCTAssertEqual(
            hiding.first?.frame.midY ?? -1,
            visibleCenterY,
            accuracy: 0.5
        )
        XCTAssertEqual(
            hiding.last?.frame.midY ?? -1,
            physicalSize.height / 2,
            accuracy: 0.5
        )
        XCTAssertEqual(
            showing.first?.frame.midY ?? -1,
            physicalSize.height / 2,
            accuracy: 0.5
        )
        XCTAssertEqual(
            showing.last?.frame.midY ?? -1,
            visibleCenterY,
            accuracy: 0.5
        )
        XCTAssertNotEqual(visibleCenterY, physicalSize.height / 2)
        XCTAssertEqual(
            hiding.first?.frame.width ?? -1,
            visibleSize.width,
            accuracy: 0.5
        )
        XCTAssertEqual(
            hiding.last?.frame.width ?? -1,
            physicalSize.width,
            accuracy: 0.5
        )
        XCTAssertEqual(
            showing.first?.frame.width ?? -1,
            physicalSize.width,
            accuracy: 0.5
        )
        XCTAssertEqual(
            showing.last?.frame.width ?? -1,
            visibleSize.width,
            accuracy: 0.5
        )
        assertSpringOvershootAndConvergence(
            hidingScaleKeyframes.map { $0 * visibleSize.width },
            source: visibleSize.width,
            target: physicalSize.width
        )
        assertSpringOvershootAndConvergence(
            showingScaleKeyframes.map { $0 * physicalSize.width },
            source: physicalSize.width,
            target: visibleSize.width
        )
        for reading in [hidingLayoutReading, showingLayoutReading] {
            XCTAssertGreaterThanOrEqual(reading.callbackCount, 1)
            XCTAssertEqual(reading.photoFrameWriteCount, 0)
            XCTAssertGreaterThanOrEqual(
                reading.suppressedPhotoFrameWriteCount,
                1
            )
            XCTAssertNotNil(reading.firstCallbackDelayMilliseconds)
        }
        let hidingCornerRadii = hiding.map {
            $0.bounds.width > 0
                ? $0.cornerRadius * $0.frame.width / $0.bounds.width
                : 0
        }
        let showingCornerRadii = showing.map {
            $0.bounds.width > 0
                ? $0.cornerRadius * $0.frame.width / $0.bounds.width
                : 0
        }
        XCTAssertEqual(hidingCornerRadii.first ?? -1, 28, accuracy: 0.5)
        XCTAssertEqual(hidingCornerRadii.last ?? -1, 0, accuracy: 0.5)
        XCTAssertEqual(showingCornerRadii.first ?? -1, 0, accuracy: 0.5)
        XCTAssertEqual(showingCornerRadii.last ?? -1, 28, accuracy: 0.5)
        assertMonotonic(hidingCornerRadii, direction: .decreasing)
        assertSpringOvershootAndConvergence(
            showingCornerRadii,
            source: 0,
            target: 28,
            requiresMeasuredOvershoot: false
        )
        printPresentationSummary(direction: "hiding", samples: hiding)
        printPresentationSummary(direction: "showing", samples: showing)
    }

    // IC-064 G19：三种系统样本的左右描边像素均落入目标容差。
    func testIC064G19FitBorderPixelsMatchDarkAndLightSamples() {
        let darkBlack = fitBorderPixelGrays(
            style: .dark,
            photoGray: 2
        )
        let lightBlack = fitBorderPixelGrays(
            style: .light,
            photoGray: 2
        )
        let lightGray = fitBorderPixelGrays(
            style: .light,
            photoGray: 237
        )

        print("IC064_BORDER_PIXELS scene=dark_black values=\(darkBlack)")
        print("IC064_BORDER_PIXELS scene=light_black values=\(lightBlack)")
        print("IC064_BORDER_PIXELS scene=light_gray_237 values=\(lightGray)")

        for value in darkBlack {
            XCTAssertEqual(Double(value), 25, accuracy: 6)
        }
        for value in lightBlack {
            XCTAssertEqual(Double(value), 2, accuracy: 4)
        }
        for value in lightGray {
            XCTAssertEqual(Double(value), 224, accuracy: 6)
        }
    }

    // IC-064 G20：1pt 描边位于照片层内，不改变照片总尺寸。
    func testIC064G20FitBorderKeepsPhotoGeometryUnchanged() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let value = metrics(configuration: configuration)
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let frameWithBorder = page.zoomScrollView.visiblePresentationFrame()

        var borderlessConfiguration = configuration
        borderlessConfiguration.fitBorderWidth = 0
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: borderlessConfiguration
        )
        let borderlessPage = tryUnwrap(
            controller.pageControllers[machine.currentIndex]
        )
        let borderWidthWithoutBorder = borderlessPage.fitBorderLayer.borderWidth
        let frameWithoutBorder = borderlessPage.zoomScrollView
            .visiblePresentationFrame()

        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        let restoredPage = tryUnwrap(
            controller.pageControllers[machine.currentIndex]
        )
        let restoredFrame = restoredPage.zoomScrollView
            .visiblePresentationFrame()

        XCTAssertEqual(
            borderWidthWithoutBorder,
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            restoredPage.fitBorderLayer.borderWidth,
            1,
            accuracy: 0.000_001
        )
        XCTAssertTrue(page === borderlessPage)
        XCTAssertTrue(page === restoredPage)
        XCTAssertEqual(page.fittedSize, value.oneXDisplaySize)
        // IC-104 C v2：fittedSize 仍精确相等；只有经渲染层往返的 frame
        // 带 ~1e-13 浮点噪声，故按容差比较两轴。
        XCTAssertEqual(
            frameWithBorder?.size.width ?? -1,
            value.oneXDisplaySize.width,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            frameWithBorder?.size.height ?? -1,
            value.oneXDisplaySize.height,
            accuracy: 0.000_001
        )
        XCTAssertEqual(frameWithoutBorder, frameWithBorder)
        XCTAssertEqual(restoredFrame, frameWithBorder)
    }

    // IC-064 G21 改写：Nx 描边归零，spring 过冲后视觉线宽收敛。
    func testIC064G21FitBorderTracksScaleAndPresentationProgress() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let nxMachine = makeMachine(scale: 2, configuration: configuration)
        let nxController = makeNativePagerController(
            machine: nxMachine,
            configuration: configuration
        )
        let nxPage = tryUnwrap(
            nxController.pageControllers[nxMachine.currentIndex]
        )
        XCTAssertEqual(
            nxPage.fitBorderLayer.borderWidth,
            0
        )

        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let hiding = capturePresentationToggle(
            machine: machine,
            controller: controller,
            page: page,
            configuration: configuration
        )
        let hidingWidths = hiding.map {
            $0.bounds.width > 0
                ? $0.borderWidth * $0.frame.width / $0.bounds.width
                : 0
        }
        let showing = capturePresentationToggle(
            machine: machine,
            controller: controller,
            page: page,
            configuration: configuration
        )
        let showingWidths = showing.map {
            $0.bounds.width > 0
                ? $0.borderWidth * $0.frame.width / $0.bounds.width
                : 0
        }
        XCTAssertEqual(hidingWidths.first ?? 0, 1, accuracy: 0.01)
        XCTAssertEqual(hidingWidths.last ?? 1, 0, accuracy: 0.01)
        XCTAssertEqual(showingWidths.first ?? 1, 0, accuracy: 0.01)
        XCTAssertEqual(showingWidths.last ?? 0, 1, accuracy: 0.01)
        assertMonotonic(hidingWidths, direction: .decreasing)
        assertSpringOvershootAndConvergence(
            showingWidths,
            source: 0,
            target: 1,
            requiresMeasuredOvershoot: false
        )
    }

    // IC-064 G22：trait 明暗切换后描边颜色原地更新，无需重建页面。
    func testIC064G22FitBorderUpdatesWithInterfaceStyle() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let host = UIViewController()
        host.view.frame = CGRect(origin: .zero, size: physicalSize)
        host.addChild(controller)
        controller.view.frame = host.view.bounds
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        host.setOverrideTraitCollection(
            UITraitCollection(userInterfaceStyle: .dark),
            forChild: controller
        )
        let darkColor = tryUnwrap(
            page.fitBorderLayer.borderColor
        )
        host.setOverrideTraitCollection(
            UITraitCollection(userInterfaceStyle: .light),
            forChild: controller
        )
        let lightColor = tryUnwrap(
            page.fitBorderLayer.borderColor
        )

        XCTAssertNotEqual(
            UIColor(cgColor: darkColor),
            UIColor(cgColor: lightColor)
        )
        XCTAssertEqual(
            UIColor(cgColor: darkColor).cgColor.alpha,
            CGFloat(configuration.fitBorderDarkAlpha),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            UIColor(cgColor: lightColor).cgColor.alpha,
            CGFloat(configuration.fitBorderLightAlpha),
            accuracy: 0.000_001
        )
    }

    // IC-067 G39：同一个 S2 页面随 trait 原地切换纯黑与纯白背景。
    func testIC067G39ViewportBackgroundTracksInterfaceStyle() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        XCTAssertTrue(machine.handleSingleTap())
        let calibration = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        let view = S2View(
            machine: machine,
            calibration: calibration,
            assetAspectRatio: { _ in self.screenAspectRatio },
            assetIsScreenshot: { _ in true },
            photoContent: { context in
                AnyView(Color.clear.frame(
                    width: context.fittedSize.width,
                    height: context.fittedSize.height
                ))
            },
            stripItemContent: { _ in AnyView(Color.clear) },
            albumPickerContent: { _, _ in AnyView(EmptyView()) }
        )
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.backgroundColor = .red
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }

        controller.overrideUserInterfaceStyle = .dark
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let darkGray = viewportBackgroundPixelGray(controller: controller)

        controller.overrideUserInterfaceStyle = .light
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let lightGray = viewportBackgroundPixelGray(controller: controller)

        XCTAssertEqual(darkGray, 0, accuracy: 3)
        XCTAssertEqual(lightGray, 255, accuracy: 3)
    }

    // IC-067 G40（夹具驱动）：接管几何与蒙版更新处于同一禁动画事务。
    func testIC067G40PinchTakeoverCommitsCenteredGeometrySynchronously() {
        let hosted = makeIC065HostedPage(
            assetAspectRatio: screenAspectRatio,
            interfaceVisibility: .visible,
            isScreenshot: true
        )
        defer { hosted.window.isHidden = true }
        let scrollView = hosted.page.zoomScrollView
        var synchronizedUpdateWasInsideTransaction = false

        scrollView.prepareForNativeZoom {
            synchronizedUpdateWasInsideTransaction =
                CATransaction.disableActions()
        }
        let frame = ic065PresentationFrameInWindow(
            page: hosted.page,
            window: hosted.window
        )

        XCTAssertTrue(synchronizedUpdateWasInsideTransaction)
        XCTAssertEqual(frame.midX, hosted.window.bounds.midX, accuracy: 0.5)
        XCTAssertEqual(frame.midY, hosted.window.bounds.midY, accuracy: 0.5)
    }

    // IC-067 G41（夹具驱动）：严格回到 1x 时恢复当前 V 的目标几何。
    func testIC067G41OneXReturnRestoresCurrentVisibilityGeometry() {
        for visibility in [S2InterfaceVisibility.visible, .hidden] {
            let hosted = makeIC065HostedPage(
                assetAspectRatio: screenAspectRatio,
                interfaceVisibility: visibility,
                isScreenshot: true
            )
            defer { hosted.window.isHidden = true }
            let scrollView = hosted.page.zoomScrollView
            let expected = metrics(visibility: visibility)

            scrollView.prepareForNativeZoom()
            scrollView.setZoomScale(1.5, animated: false)
            scrollView.setZoomScale(1, animated: false)
            hosted.page.scrollViewDidEndZooming(
                scrollView,
                with: scrollView.zoomContentView,
                atScale: 1
            )

            let frame = scrollView.oneXPresentationFrame
            XCTAssertEqual(frame.midX, physicalSize.width / 2, accuracy: 0.5)
            // IC-104 C v3：竖直中心取该 `V` 的规定中心。
            XCTAssertEqual(
                frame.midY,
                expected.oneXDisplayCenterY,
                accuracy: 0.5
            )
            XCTAssertEqual(
                frame.size.width,
                expected.oneXDisplaySize.width,
                accuracy: 0.5
            )
            XCTAssertEqual(
                frame.size.height,
                expected.oneXDisplaySize.height,
                accuracy: 0.5
            )
            XCTAssertEqual(scrollView.zoomScale, 1, accuracy: 0.000_001)
        }
    }

    // IC-067 G42（夹具驱动）：双向均有中间帧，外层回调不再覆写照片。
    func testIC067G42BothDirectionsAnimateWithoutOuterLayoutPhotoWrites() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        let hiding = capturePresentationToggle(
            machine: machine,
            controller: controller,
            page: page,
            configuration: configuration
        )
        let hidingScaleKeyframes = page.lastPresentationScaleKeyframes
        let hidingReading = controller.presentationTapLayoutReading
        let showing = capturePresentationToggle(
            machine: machine,
            controller: controller,
            page: page,
            configuration: configuration
        )
        let showingScaleKeyframes = page.lastPresentationScaleKeyframes
        let showingReading = controller.presentationTapLayoutReading

        XCTAssertGreaterThanOrEqual(hiding.count, 3)
        XCTAssertGreaterThanOrEqual(showing.count, 3)
        XCTAssertGreaterThan(
            Set(hidingScaleKeyframes.map {
                Int(($0 * 210 * 1_000).rounded())
            }).count,
            3
        )
        XCTAssertGreaterThan(
            Set(showingScaleKeyframes.map {
                Int(($0 * 300 * 1_000).rounded())
            }).count,
            3
        )
        for reading in [hidingReading, showingReading] {
            XCTAssertGreaterThanOrEqual(reading.callbackCount, 1)
            XCTAssertEqual(reading.photoFrameWriteCount, 0)
            XCTAssertGreaterThanOrEqual(
                reading.suppressedPhotoFrameWriteCount,
                1
            )
        }
    }

    // IC-067 G43（夹具驱动）：允许阻尼范围内过冲不超过 10%，随后收敛。
    func testIC067G43SpringOvershootAndConvergenceMeetC8() {
        for damping in [0.6, 0.86, 1.0] {
            let curve = S2PresentationSpringCurve(dampingRatio: damping)
            let values = (0...1_000).map {
                curve.value(at: CGFloat($0) / 1_000)
            }
            let peak = values.max() ?? 0

            XCTAssertEqual(values.first ?? -1, 0, accuracy: 0.000_001)
            XCTAssertEqual(values.last ?? -1, 1, accuracy: 0.000_001)
            XCTAssertLessThanOrEqual(peak - 1, 0.10)
            if damping < 1 {
                XCTAssertGreaterThan(peak, 1)
            }
            let peakIndex = values.firstIndex(of: peak) ?? values.endIndex
            if peakIndex < values.count - 1 {
                assertMonotonic(
                    Array(values[peakIndex...]),
                    direction: .decreasing
                )
            }
        }

        let factory = S2PresentationSpringCurve(dampingRatio: 0.86)
        XCTAssertLessThan(
            factory.value(at: 0.000_1) / 0.000_1,
            0.01
        )
    }

    // IC-064 C7：显隐动画使用独立 220ms 参数，不改动双击的 180ms 参数。
    func testIC064PresentationToggleUsesDedicatedDuration() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let togglePolicy = S2AnimationPolicy(
            configuration: configuration,
            durationMilliseconds:
                configuration.presentationToggleDuration
        )
        let existingPolicy = S2AnimationPolicy(configuration: configuration)

        XCTAssertEqual(togglePolicy.durationSeconds, 0.22, accuracy: 0.000_001)
        XCTAssertEqual(existingPolicy.durationSeconds, 0.18, accuracy: 0.000_001)
    }

    // IC-068 G47：录制关闭时不产生记录，也不改变统一入口的几何结果。
    func testIC068G47RecorderOffHasNoDiagnosticSideEffect() {
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator(
            clock: { 1_000 }
        )
        let scrollView = makeNativeZoomScrollView()
        scrollView.transitionDiagnostics = diagnostics
        let contentView = tryUnwrap(scrollView.presentationContentView)
        let targetTransform = CGAffineTransform(
            a: 0.75,
            b: 0.1,
            c: -0.1,
            d: 0.75,
            tx: 3,
            ty: -4
        )

        scrollView.writePhotoGeometry(reason: .cornerMaskReset) {
            $0.transform = targetTransform
        }
        diagnostics.recordInnerLayoutSubviews()
        diagnostics.recordUpdateUIView(
            wrotePhotoGeometry: true,
            wroteAnyGeometry: true
        )
        diagnostics.export()

        XCTAssertEqual(contentView.transform, targetTransform)
        XCTAssertTrue(diagnostics.recordedEntries.isEmpty)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
        XCTAssertTrue(diagnostics.reportText.isEmpty)
    }

    // IC-068 G48：统一入口与收敛前的赋值顺序、frame 和 transform 完全一致。
    func testIC068G48UnifiedPhotoGeometryWriteIsExactlyEquivalent() {
        let scrollView = makeNativeZoomScrollView()
        let managedView = tryUnwrap(scrollView.presentationContentView)
        let directView = UIView()
        directView.bounds = managedView.bounds
        directView.center = managedView.center
        directView.transform = CGAffineTransform(
            scaleX: 0.91,
            y: 0.91
        )
        managedView.transform = directView.transform
        let targetBounds = CGRect(
            x: 0,
            y: 0,
            width: 237,
            height: 411
        )
        let targetCenter = CGPoint(x: 147.5, y: 299.25)

        directView.transform = .identity
        directView.bounds = targetBounds
        directView.center = targetCenter
        scrollView.writePhotoGeometry(
            reason: .enforceOneXContentGeometry
        ) { contentView in
            contentView.transform = .identity
            contentView.bounds = targetBounds
            contentView.center = targetCenter
        }

        XCTAssertEqual(managedView.bounds, directView.bounds)
        XCTAssertEqual(managedView.center, directView.center)
        XCTAssertEqual(managedView.frame, directView.frame)
        XCTAssertEqual(managedView.transform, directView.transform)
        XCTAssertEqual(
            managedView.layer.affineTransform(),
            directView.layer.affineTransform()
        )
    }

    // IC-068 G49：导出协议包含全部逐帧字段、空动画键和全部离散事件族。
    func testIC068G49ExportContainsCompleteUnifiedSchema() {
        let sample = S2OnDeviceTransitionFrameSample(
            animationKeys: [],
            modelFrame: CGRect(x: 10, y: 20, width: 30, height: 40),
            presentationFrame: CGRect(x: 11, y: 21, width: 29, height: 39),
            transform: CGAffineTransform(
                a: 0.7,
                b: 0,
                c: 0,
                d: 0.7,
                tx: 2,
                ty: 3
            ),
            zoomScale: 1,
            contentOffset: CGPoint(x: 4, y: 5),
            contentSize: CGSize(width: 300, height: 600),
            contentInset: UIEdgeInsets(top: 6, left: 7, bottom: 8, right: 9),
            adjustedContentInset: UIEdgeInsets(
                top: 10,
                left: 11,
                bottom: 12,
                right: 13
            ),
            visibility: .hidden,
            scale: 1
        )
        let eventNames = [
            "SwiftUI状态发布",
            "updateUIView",
            "layoutSubviews",
            "viewDidLayoutSubviews",
            "照片几何写入",
            "照片动画调用:add(animation:)",
            "照片动画调用:removeAnimation",
            "照片动画调用:removeAllAnimations",
            "CATransaction提交边界",
            "抑制外层布局写入生效"
        ]
        var records = [S2OnDeviceTransitionRecord(
            timestamp: 500,
            sequence: 0,
            payload: .frame(sample)
        )]
        records.append(contentsOf: eventNames.enumerated().map { pair in
            let (index, name) = pair
            return S2OnDeviceTransitionRecord(
                timestamp: 500 + Double(index + 1) / 100,
                sequence: index + 1,
                payload: .event(
                    name: name,
                    source: "测试来源",
                    details: "key=测试键；写入照片几何=true"
                )
            )
        })

        let text = S2OnDeviceTransitionText.export(
            scenario: .tapShow,
            startedAt: 500,
            stoppedAt: 500.2,
            records: records
        )
        let requiredFields = [
            "时钟=CACurrentMediaTime()",
            "采样频率下限Hz=60",
            "录制上限秒=5.000000",
            "animationKeys=[]",
            "modelFrame=",
            "presentationFrame=",
            "transform=(a=",
            "zoomScale=",
            "contentOffset=",
            "contentSize=",
            "V=隐藏",
            "s=1.000000",
            "source=测试来源",
            "details=key=测试键"
        ]
        for field in requiredFields {
            XCTAssertTrue(text.contains(field), "缺少导出字段：\(field)")
        }
        for eventName in eventNames {
            XCTAssertTrue(text.contains("event=\(eventName)"))
        }
    }


    // IC-090 G182：场景 C 逐帧新增 presentationZoomScale / isZoomBouncing / isDecelerating /
    // imageRequestResult / lastImageReplacement 五个字段，离散事件新增
    // scrollViewDidEndZooming / finishNativePinch / setZoomScale / 吸附归位写入 / 图片替换 五类。
    // 既有字段与事件一项不改；关闭录制时全部埋点零副作用。
    // （夹具驱动：真实两指捏合无法在 XCTest 内复现，`pinchWasActive` 恒为 false；
    //   松手抖动本身的归因留给 Lynn 的场景 C 真机录制。）
    func testIC090G182PinchEndScenarioExportsNewFieldsAndEvents() {
        XCTAssertEqual(S2OnDeviceTransitionScenario.pinchStart.exportTitle, "C 捏合起始")

        let hosted = makeIC065HostedPage(
            assetAspectRatio: 3.0 / 4.0,
            isScreenshot: false
        )
        defer { hosted.window.isHidden = true }
        let controller = hosted.controller
        let registry = S2ImageLoadStateRegistry()
        registry.update(.displayed, for: "asset-2")
        controller.imageLoadStateRegistry = registry
        XCTAssertEqual(hosted.machine.currentIndex, 1)
        XCTAssertEqual(hosted.machine.orderedAssetIDs[1], "asset-2")

        // 登记表在录制之外也持续登记，故录制一开始即能读到当前张已有的请求状态。
        registry.updateRequestResult(.finalImage(UIImage()), for: "asset-2")
        let replacement = S2ImageReplacementRecord(
            assetID: "asset-2",
            resultName: S2ImageRequestResult.finalImage(UIImage()).diagnosticName,
            pixelSize: CGSize(width: 1_206, height: 2_622),
            timestamp: 1_234.5
        )
        registry.recordImageReplacement(replacement)
        XCTAssertEqual(controller.diagnosticCurrentImageRequestResult, "finalImage")
        XCTAssertEqual(controller.diagnosticLastImageReplacement, replacement)

        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.selectedScenario = .pinchStart
        diagnostics.start()
        let page = hosted.page
        let scrollView = page.zoomScrollView

        // 真实调用点：`setZoomScale(_:animated:)` 的重写与 1x 归位写入。
        // 先 `prepareForNativeZoom()` 确保内外层视图已就绪且几何被改脏，
        // 归位才真的有写入可记（返回 true 即两个内容视图都存在）。
        XCTAssertTrue(scrollView.prepareForNativeZoom())
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        scrollView.restoreOneXGeometry()
        // 夹具驱动：直接调用缩放结束的委托实现与捏合结算入口。
        page.scrollViewDidEndZooming(
            scrollView,
            with: scrollView.zoomContentView,
            atScale: scrollView.zoomScale
        )
        controller.finishNativePinch(
            on: page,
            scale: scrollView.zoomScale,
            displacement: 0.5,
            peakVelocity: 3,
            duration: 0.2
        )
        diagnostics.recordImageReplacement(replacement)
        // 与 captureFrame 同一 runloop 回合读取，避免呈现层随时间变化造成比较不稳。
        let expectedPresentationZoomScale =
            scrollView.diagnosticPresentationZoomScale
        diagnostics.captureFrame()
        diagnostics.stop()
        diagnostics.export()

        let text = diagnostics.reportText
        XCTAssertTrue(text.contains("场景=C 捏合起始"))
        // 头部字段声明行：既有 22 项原序不变，五个新字段追加在末尾。
        XCTAssertTrue(text.contains(
            "逐帧字段=time,animationKeys,modelFrame,presentationFrame," +
                "transform,zoomScale,contentOffset,contentSize," +
                "contentInset,adjustedContentInset,V,s," +
                "pagingContentOffsetX,pagingIsDragging,pagingIsDecelerating," +
                "currentIndex,settledIndex,pageIndicesPresent,pageLoadStates," +
                "nxDistanceToPreviousBoundary,nxDistanceToNextBoundary," +
                "nxOverflowDistance," +
                "presentationZoomScale,isZoomBouncing,isDecelerating," +
                "imageRequestResult,lastImageReplacement"
        ))
        XCTAssertTrue(text.contains("\tpresentationZoomScale="))
        XCTAssertTrue(text.contains("\tisZoomBouncing=false"))
        XCTAssertTrue(text.contains("\tisDecelerating=false"))
        XCTAssertTrue(text.contains("\timageRequestResult=finalImage"))
        XCTAssertTrue(text.contains(
            "\tlastImageReplacement=(asset=asset-2,result=finalImage," +
                "w=1206.000000,h=2622.000000,t=1234.500000)"
        ))

        // 逐帧样本取自真实滚动视图，不是常量。
        let frames = diagnostics.recordedEntries.compactMap {
            record -> S2OnDeviceTransitionFrameSample? in
            if case let .frame(sample) = record.payload {
                return sample
            }
            return nil
        }
        let last = tryUnwrap(frames.last)
        XCTAssertEqual(last.isZoomBouncing, scrollView.isZoomBouncing)
        XCTAssertEqual(last.isDecelerating, scrollView.isDecelerating)
        XCTAssertEqual(last.imageRequestResult, "finalImage")
        XCTAssertEqual(last.lastImageReplacement, replacement)
        XCTAssertEqual(last.presentationZoomScale, expectedPresentationZoomScale)

        func events(named name: String) -> [(source: String, details: String)] {
            diagnostics.recordedEntries.compactMap {
                entry -> (source: String, details: String)? in
                if case let .event(eventName, source, details) = entry.payload,
                   eventName == name {
                    return (source: source, details: details)
                }
                return nil
            }
        }
        func event(named name: String) -> (source: String, details: String)? {
            events(named: name).first
        }
        let endZooming = tryUnwrap(event(named: "scrollViewDidEndZooming"))
        XCTAssertEqual(
            endZooming.source,
            "S2NativeZoomPageController.scrollViewDidEndZooming"
        )
        XCTAssertTrue(endZooming.details.contains("endedAtMinimum=true"))
        XCTAssertTrue(endZooming.details.contains("pinchWasActive=false"))

        let finishPinch = tryUnwrap(event(named: "finishNativePinch"))
        XCTAssertEqual(
            finishPinch.source,
            "S2NativePagerViewController.finishNativePinch"
        )
        XCTAssertTrue(finishPinch.details.contains("displacement=0.500000"))
        XCTAssertTrue(finishPinch.details.contains("peakVelocity=3.000000"))
        XCTAssertTrue(finishPinch.details.contains("path="))

        let setZoomEvents = events(named: "setZoomScale")
        XCTAssertFalse(setZoomEvents.isEmpty)
        for setZoom in setZoomEvents {
            XCTAssertEqual(setZoom.source, "S2NativeZoomScrollView.setZoomScale")
            XCTAssertTrue(setZoom.details.contains("scale="))
            XCTAssertTrue(setZoom.details.contains("from="))
        }
        XCTAssertTrue(setZoomEvents.contains {
            $0.details.contains("animated=false")
        })

        let snapBackEvents = events(named: "吸附归位写入")
        XCTAssertFalse(snapBackEvents.isEmpty)
        for snapBack in snapBackEvents {
            XCTAssertTrue(
                [
                    "S2NativeZoomScrollView.restoreOneXGeometry",
                    "S2NativeZoomScrollView.enforceOneXContentGeometry"
                ].contains(snapBack.source),
                snapBack.source
            )
            for key in [
                "contentInset=", "contentSize=", "contentOffset=", "照片几何="
            ] {
                XCTAssertTrue(snapBack.details.contains(key), key)
            }
        }
        XCTAssertTrue(snapBackEvents.contains {
            $0.source == "S2NativeZoomScrollView.restoreOneXGeometry"
        })

        let replacementEvent = tryUnwrap(event(named: "图片替换"))
        XCTAssertEqual(
            replacementEvent.source,
            "S2TemporaryPhotoImageView.requestImage"
        )
        XCTAssertTrue(replacementEvent.details.contains("asset=asset-2"))
        XCTAssertTrue(replacementEvent.details.contains("result=finalImage"))
        XCTAssertTrue(
            replacementEvent.details.contains("pixel=(w=1206.000000,h=2622.000000)")
        )

        // 关闭录制后同样的调用零副作用：记录条数不变。
        let recordedCount = diagnostics.recordedEntries.count
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        scrollView.restoreOneXGeometry()
        page.scrollViewDidEndZooming(
            scrollView,
            with: scrollView.zoomContentView,
            atScale: scrollView.zoomScale
        )
        controller.finishNativePinch(
            on: page,
            scale: scrollView.zoomScale,
            displacement: 0.5,
            peakVelocity: 3,
            duration: 0.2
        )
        diagnostics.recordImageReplacement(replacement)
        diagnostics.captureFrame()
        XCTAssertEqual(diagnostics.recordedEntries.count, recordedCount)
        diagnostics.detach(controller)
    }

    // IC-090 G182：请求结果与图片替换的登记入口——`S2ImageRequestResult` 五个分支
    // 逐一映射为诊断名；替换记录按最近一次覆盖；未登记的资产读出 nil。
    func testIC090G182ImageRequestResultRegistryTracksLatestResultAndReplacement() {
        let registry = S2ImageLoadStateRegistry()
        XCTAssertNil(registry.requestResult(for: "asset-1"))
        XCTAssertNil(registry.lastImageReplacement)

        let image = UIImage()
        let expected: [(S2ImageRequestResult, String)] = [
            (.degradedPreview(image), "degradedPreview"),
            (.finalImage(image), "finalImage"),
            (.failure, "failure"),
            (.cancelled, "cancelled"),
            (.assetUnavailable, "assetUnavailable")
        ]
        for (result, name) in expected {
            XCTAssertEqual(result.diagnosticName, name)
            registry.updateRequestResult(result, for: "asset-1")
            XCTAssertEqual(registry.requestResult(for: "asset-1"), name)
        }
        XCTAssertNil(registry.requestResult(for: "asset-2"))

        let first = S2ImageReplacementRecord(
            assetID: "asset-1",
            resultName: "degradedPreview",
            pixelSize: CGSize(width: 10, height: 20),
            timestamp: 1
        )
        let second = S2ImageReplacementRecord(
            assetID: "asset-1",
            resultName: "finalImage",
            pixelSize: CGSize(width: 100, height: 200),
            timestamp: 2
        )
        registry.recordImageReplacement(first)
        XCTAssertEqual(registry.lastImageReplacement, first)
        registry.recordImageReplacement(second)
        XCTAssertEqual(registry.lastImageReplacement, second)

        XCTAssertEqual(
            S2OnDeviceTransitionText.imageReplacement(nil),
            "nil"
        )
        XCTAssertEqual(
            S2OnDeviceTransitionText.imageReplacement(second),
            "(asset=asset-1,result=finalImage," +
                "w=100.000000,h=200.000000,t=2.000000)"
        )
    }

    // IC-070 G79：逐帧字段含 contentInset 与 adjustedContentInset，且采自真实滚动视图。
    func testIC070G79FrameSamplesExportContentInsetFields() {
        let hosted = makeIC065HostedPage(
            assetAspectRatio: 3.0 / 4.0,
            isScreenshot: false
        )
        defer { hosted.window.isHidden = true }
        let scrollView = hosted.page.zoomScrollView
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(hosted.controller)
        diagnostics.start()
        XCTAssertTrue(scrollView.prepareForNativeZoom())
        diagnostics.captureFrame()
        diagnostics.stop()
        diagnostics.export()

        let text = diagnostics.reportText
        XCTAssertTrue(text.contains(
            "逐帧字段=time,animationKeys,modelFrame,presentationFrame," +
                "transform,zoomScale,contentOffset,contentSize," +
                "contentInset,adjustedContentInset,V,s"
        ))
        let frames = diagnostics.recordedEntries.compactMap {
            record -> S2OnDeviceTransitionFrameSample? in
            if case let .frame(sample) = record.payload {
                return sample
            }
            return nil
        }
        XCTAssertGreaterThanOrEqual(frames.count, 2)
        let last = tryUnwrap(frames.last)
        XCTAssertEqual(last.contentInset, scrollView.contentInset)
        XCTAssertEqual(
            last.adjustedContentInset,
            scrollView.adjustedContentInset
        )
        XCTAssertTrue(text.contains("\tcontentInset=(top="))
        XCTAssertTrue(text.contains("\tadjustedContentInset=(top="))
        XCTAssertFalse(text.contains("contentInset=nil"))
    }

    // IC-070 R5 实测探针（夹具驱动，不做断言）：打印接管各步的
    // inset/offset/contentSize 与可见中心，并模拟 UIKit 在同一帧写入过期 offset。
    func testIC070R5TakeoverCenteringProbe() {
        let hosted = makeIC065HostedPage(
            assetAspectRatio: 3.0 / 4.0,
            isScreenshot: false
        )
        defer { hosted.window.isHidden = true }
        let scrollView = hosted.page.zoomScrollView
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(hosted.controller)
        diagnostics.start()
        let viewport = hosted.window.bounds
        let probe: (String) -> Void = { label in
            diagnostics.captureFrame()
            let frame = self.ic065PresentationFrameInWindow(
                page: hosted.page,
                window: hosted.window
            )
            let inset = scrollView.contentInset
            print(String(
                format: "IC070_R5_PROBE step=%@ zoom=%.6f " +
                    "offset=(%.3f,%.3f) " +
                    "inset=(t=%.3f,l=%.3f,b=%.3f,r=%.3f) " +
                    "contentSize=(%.3f,%.3f) " +
                    "visibleMid=(%.3f,%.3f) viewportMid=(%.3f,%.3f) " +
                    "dy=%.3f",
                label,
                scrollView.zoomScale,
                scrollView.contentOffset.x,
                scrollView.contentOffset.y,
                inset.top,
                inset.left,
                inset.bottom,
                inset.right,
                scrollView.contentSize.width,
                scrollView.contentSize.height,
                frame.midX,
                frame.midY,
                viewport.midX,
                viewport.midY,
                frame.midY - viewport.midY
            ))
        }

        probe("one_x")
        XCTAssertTrue(scrollView.prepareForNativeZoom())
        probe("takeover_sync")
        scrollView.contentOffset = .zero
        probe("uikit_stale_offset_zero")
        scrollView.setZoomScale(1.005269, animated: false)
        probe("zoom_1.005269_before_layout")
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        probe("zoom_1.005269_after_layout")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0 / 60.0))
        probe("next_runloop_frame")
        for scale in [1.05, 1.25, 2.0] as [CGFloat] {
            scrollView.setZoomScale(scale, animated: false)
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
            probe(String(format: "zoom_%.3f", scale))
        }
        diagnostics.stop()
        diagnostics.export()
        for line in diagnostics.reportText.split(separator: "\n")
        where line.contains("kind=frame") {
            print("IC070_R5_EXPORT \(line)")
        }
    }

    // IC-070 R6 实测探针（夹具驱动，不做断言）：沿四角 45° 对角线与直边扫描
    // 像素灰度，并打印描边层运行时属性。
    func testIC070R6BorderConcentricityProbe() {
        var opaqueBorder = S2CalibrationConfiguration.factoryPlaceholder
        opaqueBorder.fitBorderLightAlpha = 1
        let variants: [(String, S2CalibrationConfiguration, Int)] = [
            ("opaque_border", opaqueBorder, 237),
            ("factory", .factoryPlaceholder, 237)
        ]
        for (label, configuration, photoGray) in variants {
            let scene = makeBorderScanScene(
                style: .light,
                photoGray: photoGray,
                configuration: configuration
            )
            defer { scene.window.isHidden = true }
            let rendered = renderBorderScan(scene)
            let frame = rendered.frame
            let page = scene.page
            let photoLayer = tryUnwrap(
                page.zoomScrollView.presentationContentView
            ).layer
            print(String(
                format: "IC070_R6_LAYER config=%@ frame=(%.3f,%.3f,%.3f,%.3f) " +
                    "photoRadius=%.3f photoMasks=%d photoCurve=%@ " +
                    "borderFrame=(%.3f,%.3f,%.3f,%.3f) borderRadius=%.3f " +
                    "borderWidth=%.3f borderCurve=%@ superlayerIsPhoto=%d",
                label,
                frame.minX, frame.minY, frame.width, frame.height,
                photoLayer.cornerRadius,
                photoLayer.masksToBounds ? 1 : 0,
                photoLayer.cornerCurve.rawValue,
                page.fitBorderLayer.frame.minX,
                page.fitBorderLayer.frame.minY,
                page.fitBorderLayer.frame.width,
                page.fitBorderLayer.frame.height,
                page.fitBorderLayer.cornerRadius,
                page.fitBorderLayer.borderWidth,
                page.fitBorderLayer.cornerCurve.rawValue,
                page.fitBorderLayer.superlayer === photoLayer ? 1 : 0
            ))
            let step: CGFloat = 1.0 / 3.0
            let corners: [(String, CGPoint, CGVector)] = [
                ("topLeft", CGPoint(x: frame.minX, y: frame.minY),
                 CGVector(dx: step, dy: step)),
                ("topRight", CGPoint(x: frame.maxX, y: frame.minY),
                 CGVector(dx: -step, dy: step)),
                ("bottomLeft", CGPoint(x: frame.minX, y: frame.maxY),
                 CGVector(dx: step, dy: -step)),
                ("bottomRight", CGPoint(x: frame.maxX, y: frame.maxY),
                 CGVector(dx: -step, dy: -step))
            ]
            for (name, corner, direction) in corners {
                let start = CGPoint(
                    x: corner.x - direction.dx * 6,
                    y: corner.y - direction.dy * 6
                )
                let grays = grayRun(
                    image: rendered.image,
                    from: start,
                    step: direction,
                    count: 60
                )
                print("IC070_R6_SCAN config=\(label) path=diag_\(name) " +
                    "start=(\(start.x),\(start.y)) grays=\(grays)")
            }
            let edges: [(String, CGPoint, CGVector)] = [
                ("left", CGPoint(x: frame.minX - 2, y: frame.midY),
                 CGVector(dx: step, dy: 0)),
                ("right", CGPoint(x: frame.maxX + 2, y: frame.midY),
                 CGVector(dx: -step, dy: 0)),
                ("top", CGPoint(x: frame.midX, y: frame.minY - 2),
                 CGVector(dx: 0, dy: step)),
                ("bottom", CGPoint(x: frame.midX, y: frame.maxY + 2),
                 CGVector(dx: 0, dy: -step))
            ]
            for (name, start, direction) in edges {
                let grays = grayRun(
                    image: rendered.image,
                    from: start,
                    step: direction,
                    count: 18
                )
                print("IC070_R6_SCAN config=\(label) path=edge_\(name) " +
                    "start=(\(start.x),\(start.y)) grays=\(grays)")
            }
        }
    }

    // IC-070 G75/G76（夹具驱动，真机未覆盖）：接管帧与接管前一帧居中量一致；
    // 接管全过程含对抗性的过期 offset 写入，inset+offset 联合居中逐帧连续。
    func testIC070G75AndG76TakeoverKeepsJointCenteringEveryFrame() {
        let samples: [(String, CGFloat)] = [
            ("3_4", 3.0 / 4.0),
            ("narrow", 478.0 / 2_622.0)
        ]
        for (name, assetAspectRatio) in samples {
            let hosted = makeIC065HostedPage(
                assetAspectRatio: assetAspectRatio,
                isScreenshot: false
            )
            defer { hosted.window.isHidden = true }
            let scrollView = hosted.page.zoomScrollView
            let viewport = hosted.window.bounds
            let assertCentered: (String) -> Void = { phase in
                let frame = self.ic065PresentationFrameInWindow(
                    page: hosted.page,
                    window: hosted.window
                )
                let inset = scrollView.contentInset
                let offset = scrollView.contentOffset
                let message = "样本=\(name)，阶段=\(phase)，" +
                    "frame=\(frame)，inset=\(inset)，offset=\(offset)"
                if frame.width < viewport.width - 0.5 {
                    XCTAssertEqual(
                        frame.midX,
                        viewport.midX,
                        accuracy: 0.5,
                        message
                    )
                    XCTAssertEqual(offset.x, -inset.left, accuracy: 0.5, message)
                }
                if frame.height < viewport.height - 0.5 {
                    XCTAssertEqual(
                        frame.midY,
                        viewport.midY,
                        accuracy: 0.5,
                        message
                    )
                    XCTAssertEqual(offset.y, -inset.top, accuracy: 0.5, message)
                }
            }

            let before = ic065PresentationFrameInWindow(
                page: hosted.page,
                window: hosted.window
            )
            assertCentered("one_x")
            XCTAssertTrue(scrollView.prepareForNativeZoom())
            let takeover = ic065PresentationFrameInWindow(
                page: hosted.page,
                window: hosted.window
            )
            // G76：接管帧与接管前一帧的可见居中量之差 ≤ 0.5pt。
            XCTAssertEqual(takeover.midX, before.midX, accuracy: 0.5, name)
            XCTAssertEqual(takeover.midY, before.midY, accuracy: 0.5, name)
            assertCentered("takeover_sync")

            // 对抗：模拟 UIKit 捏合处理在同一帧用过期 inset 写回 offset=0，
            // 联合居中必须在本次布局提交内恢复。
            scrollView.contentOffset = .zero
            assertCentered("stale_offset_immediate")
            scrollView.contentOffset = .zero
            scrollView.layoutIfNeeded()
            assertCentered("stale_offset_then_layout")
            scrollView.contentOffset = .zero
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0 / 60.0))
            assertCentered("stale_offset_then_runloop")
            scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            assertCentered("stale_setContentOffset_immediate")

            let scales: [CGFloat] = [1.001, 1.005269, 1.05, 1.25, 1.5, 2, 3]
            for scale in scales {
                scrollView.setZoomScale(scale, animated: false)
                scrollView.setNeedsLayout()
                scrollView.layoutIfNeeded()
                assertCentered(String(format: "scale_%.6f", scale))
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0 / 60.0))
                assertCentered(String(format: "scale_%.6f_next_frame", scale))
            }
        }
    }

    // IC-070 G77：四角 45° 对角线由外向内首个非背景像素为描边像素；
    // 描边在直边与圆角处的可见宽度之差 ≤ 0.5pt。初始态与隐藏→显示之后各验一次。
    func testIC070G77FitBorderIsConcentricAtCornersBeforeAndAfterToggle() {
        // 测试专用：把浅色描边 alpha 提到 1 以分离描边与照片灰度；出厂值不变。
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitBorderLightAlpha = 1
        let photoGray = 237
        let scene = makeBorderScanScene(
            style: .light,
            photoGray: photoGray,
            configuration: configuration
        )
        defer { scene.window.isHidden = true }

        assertFitBorderConcentric(
            scene: scene,
            phase: "initial",
            photoGray: photoGray
        )

        _ = capturePresentationToggle(
            machine: scene.machine,
            controller: scene.controller,
            page: scene.page,
            configuration: configuration
        )
        _ = capturePresentationToggle(
            machine: scene.machine,
            controller: scene.controller,
            page: scene.page,
            configuration: configuration
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(
            scene.page.diagnosticInterfaceVisibility,
            .visible
        )
        assertFitBorderConcentric(
            scene: scene,
            phase: "after_hide_show",
            photoGray: photoGray
        )
    }

    // IC-070 G78：过渡期间描边层与照片层使用同一组圆角关键帧，逐帧之差 ≤ 0.5pt；
    // 过渡收口后两层均无残留动画，描边层半径与线宽回到当前页目标值。
    func testIC070G78FitBorderCornerRadiusTracksPhotoThroughTransition() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let photoLayer = tryUnwrap(
            page.zoomScrollView.presentationContentView
        ).layer
        let key = "S2NativeZoomPageController.presentationTransition"

        _ = capturePresentationToggle(
            machine: machine,
            controller: controller,
            page: page,
            configuration: configuration
        )
        XCTAssertEqual(page.fitBorderLayer.animationKeys() ?? [], [])

        XCTAssertTrue(page.applyRecognizedSingleTap())
        controller.viewDidLayoutSubviews()
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        XCTAssertTrue(page.isPresentationTransitionActive)
        let photoGroup = tryUnwrap(
            photoLayer.animation(forKey: key) as? CAAnimationGroup
        )
        let borderGroup = tryUnwrap(
            page.fitBorderLayer.animation(forKey: key) as? CAAnimationGroup
        )
        let photoRadii = keyframeValues(photoGroup, keyPath: "cornerRadius")
        let borderRadii = keyframeValues(borderGroup, keyPath: "cornerRadius")
        XCTAssertGreaterThan(photoRadii.count, 2)
        XCTAssertEqual(photoRadii.count, borderRadii.count)
        for (index, pair) in zip(photoRadii, borderRadii).enumerated() {
            XCTAssertEqual(pair.0, pair.1, accuracy: 0.5, "关键帧=\(index)")
        }

        var presentationPairs = 0
        let deadline = Date(timeIntervalSinceNow: 1)
        while page.isPresentationTransitionActive, Date() < deadline {
            if let photo = photoLayer.presentation(),
               let border = page.fitBorderLayer.presentation() {
                XCTAssertEqual(
                    photo.cornerRadius,
                    border.cornerRadius,
                    accuracy: 0.5
                )
                presentationPairs += 1
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
        XCTAssertFalse(page.isPresentationTransitionActive)
        print("IC070_G78 presentationPairs=\(presentationPairs) " +
            "keyframes=\(photoRadii.count)")

        XCTAssertEqual(page.fitBorderLayer.animationKeys() ?? [], [])
        XCTAssertEqual(photoLayer.animationKeys() ?? [], [])
        XCTAssertEqual(
            page.fitBorderLayer.cornerRadius,
            photoLayer.cornerRadius,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            page.fitBorderLayer.cornerRadius,
            CGFloat(configuration.fitCornerRadius),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            page.fitBorderLayer.borderWidth,
            CGFloat(configuration.fitBorderWidth),
            accuracy: 0.000_001
        )
        XCTAssertEqual(photoLayer.affineTransform(), .identity)
        if let border = page.fitBorderLayer.presentation(),
           let photo = photoLayer.presentation() {
            XCTAssertEqual(border.cornerRadius, photo.cornerRadius, accuracy: 0.5)
            XCTAssertEqual(
                border.borderWidth,
                CGFloat(configuration.fitBorderWidth),
                accuracy: 0.01
            )
        }
    }

    private func keyframeValues(
        _ group: CAAnimationGroup,
        keyPath: String
    ) -> [CGFloat] {
        let animation = group.animations?
            .compactMap { $0 as? CAKeyframeAnimation }
            .first { $0.keyPath == keyPath }
        return (animation?.values as? [NSNumber])?.map {
            CGFloat($0.doubleValue)
        } ?? []
    }

    private func assertFitBorderConcentric(
        scene: BorderScanScene,
        phase: String,
        photoGray: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rendered = renderBorderScan(scene)
        let frame = rendered.frame
        let step: CGFloat = 1.0 / 3.0
        let diagonals: [(String, CGPoint, CGVector)] = [
            ("topLeft", CGPoint(x: frame.minX, y: frame.minY),
             CGVector(dx: step, dy: step)),
            ("topRight", CGPoint(x: frame.maxX, y: frame.minY),
             CGVector(dx: -step, dy: step)),
            ("bottomLeft", CGPoint(x: frame.minX, y: frame.maxY),
             CGVector(dx: step, dy: -step)),
            ("bottomRight", CGPoint(x: frame.maxX, y: frame.maxY),
             CGVector(dx: -step, dy: -step))
        ]
        let edges: [(String, CGPoint, CGVector)] = [
            ("left", CGPoint(x: frame.minX - 2, y: frame.midY),
             CGVector(dx: step, dy: 0)),
            ("right", CGPoint(x: frame.maxX + 2, y: frame.midY),
             CGVector(dx: -step, dy: 0)),
            ("top", CGPoint(x: frame.midX, y: frame.minY - 2),
             CGVector(dx: 0, dy: step)),
            ("bottom", CGPoint(x: frame.midX, y: frame.maxY + 2),
             CGVector(dx: 0, dy: -step))
        ]
        var cornerWidths: [CGFloat] = []
        for (name, corner, direction) in diagonals {
            let start = CGPoint(
                x: corner.x - direction.dx * 6,
                y: corner.y - direction.dy * 6
            )
            let grays = grayRun(
                image: rendered.image,
                from: start,
                step: direction,
                count: 60
            )
            let reading = borderScanReading(grays: grays, photoGray: photoGray)
            let width = reading.coverage * sqrt(2) / 3
            cornerWidths.append(width)
            print("IC070_G77 phase=\(phase) path=diag_\(name) " +
                "first=\(reading.firstNonBackground.map(String.init) ?? "nil") " +
                "width=\(width) grays=\(grays)")
            let first = tryUnwrap(reading.firstNonBackground, file: file, line: line)
            XCTAssertLessThan(
                first,
                photoGray - 3,
                "阶段=\(phase)，角=\(name)：首个非背景像素不是描边",
                file: file,
                line: line
            )
        }
        var edgeWidths: [CGFloat] = []
        for (name, start, direction) in edges {
            let grays = grayRun(
                image: rendered.image,
                from: start,
                step: direction,
                count: 18
            )
            let reading = borderScanReading(grays: grays, photoGray: photoGray)
            let width = reading.coverage / 3
            edgeWidths.append(width)
            print("IC070_G77 phase=\(phase) path=edge_\(name) " +
                "width=\(width) grays=\(grays)")
        }
        let edgeWidth = edgeWidths.reduce(0, +) / CGFloat(edgeWidths.count)
        let cornerWidth = cornerWidths.reduce(0, +) / CGFloat(cornerWidths.count)
        print("IC070_G77 phase=\(phase) edgeWidth=\(edgeWidth) " +
            "cornerWidth=\(cornerWidth)")
        XCTAssertEqual(
            edgeWidth,
            1,
            accuracy: 0.34,
            "阶段=\(phase)：直边描边宽度",
            file: file,
            line: line
        )
        for (index, width) in cornerWidths.enumerated() {
            XCTAssertEqual(
                width,
                edgeWidth,
                accuracy: 0.5,
                "阶段=\(phase)，角序号=\(index)：圆角与直边宽度差",
                file: file,
                line: line
            )
        }
    }

    // IC-083 G158（夹具驱动）：横栏缩略图裁满——横图与竖图项目的可见内容帧均等于项目帧
    // （当前项方形、邻居矩形，尺寸规则不变），裁满内容帧恰好覆盖项目帧且居中裁切；标记位置不变。
    // IC-088 合并：083 的 `S2BottomStripItemLayout.fillSize` / `fillContentSize(at:)` 按合并规则弃用，
    // 本测试改读 085 的等价物 `S2BottomStripLayout.itemSize(at:currentIndex:expansion:)` 与
    // `S2BottomStripLayout.fillContentSize(cellSize:assetAspectRatio:)`；断言意图不变。
    func testIC083G158BottomStripItemsFillAndClipToItemFrame() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let metrics = tryUnwrap(configuration.resolvedParameters).bottomStripMetrics
        let layout = S2BottomStripLayout(metrics: metrics)
        let ratios: [String: CGFloat] = [
            "asset-1": 4_032 / 3_024,
            "asset-2": 3_024 / 4_032,
            "asset-3": 1
        ]
        let machine = makeMachine(
            configuration: configuration,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        let strip = S2BottomStripView(
            machine: machine,
            metrics: metrics,
            markSize: CGFloat(configuration.bottomStripMarkSize),
            itemContent: { _ in AnyView(Color.clear) },
            assetAspectRatio: { ratios[$0] ?? 1 },
            onPhotoSwitch: {}
        )
        func itemFrameSize(at index: Int, expansion: CGFloat) -> CGSize {
            layout.itemSize(
                at: index,
                currentIndex: machine.currentIndex,
                expansion: expansion
            )
        }
        func fillContentSize(at index: Int, expansion: CGFloat) -> CGSize {
            S2BottomStripLayout.fillContentSize(
                cellSize: itemFrameSize(at: index, expansion: expansion),
                assetAspectRatio: ratios[machine.orderedAssetIDs[index]] ?? 1
            )
        }

        // 静止态（expansion 1）：邻居矩形（横图 asset-1）、当前项方形（竖图 asset-2）、邻居矩形（方图 asset-3）。
        XCTAssertEqual(
            itemFrameSize(at: 0, expansion: 1),
            CGSize(width: metrics.neighborItemWidth, height: metrics.neighborItemHeight)
        )
        XCTAssertEqual(
            itemFrameSize(at: 1, expansion: 1),
            CGSize(width: metrics.currentItemSize, height: metrics.currentItemSize)
        )
        XCTAssertEqual(
            itemFrameSize(at: 2, expansion: 1),
            CGSize(width: metrics.neighborItemWidth, height: metrics.neighborItemHeight)
        )
        for index in 0..<3 {
            let item = itemFrameSize(at: index, expansion: 1)
            let fill = fillContentSize(at: index, expansion: 1)
            let ratio = ratios[machine.orderedAssetIDs[index]]!
            XCTAssertGreaterThanOrEqual(fill.width, item.width - 0.000_001, "\(index)")
            XCTAssertGreaterThanOrEqual(fill.height, item.height - 0.000_001, "\(index)")
            XCTAssertTrue(
                abs(fill.width - item.width) < 0.000_001 ||
                    abs(fill.height - item.height) < 0.000_001,
                "裁满内容帧在一个维度上与项目帧相等 \(index)"
            )
            XCTAssertEqual(fill.width / fill.height, ratio, accuracy: 0.000_001)
        }
        // 横图在邻居矩形内：高度受限；竖图在当前方形内：宽度受限，高 = 边长 ÷ 宽高比。
        XCTAssertEqual(fillContentSize(at: 0, expansion: 1).height, metrics.neighborItemHeight, accuracy: 0.000_001)
        XCTAssertEqual(fillContentSize(at: 1, expansion: 1).width, metrics.currentItemSize, accuracy: 0.000_001)
        XCTAssertEqual(fillContentSize(at: 1, expansion: 1).height, metrics.currentItemSize / (3_024 / 4_032), accuracy: 0.000_001)

        // 纯函数边界：非法宽高比或零尺寸退回项目帧。
        XCTAssertEqual(
            S2BottomStripLayout.fillContentSize(cellSize: CGSize(width: 52, height: 44), assetAspectRatio: 0),
            CGSize(width: 52, height: 44)
        )
        XCTAssertEqual(
            S2BottomStripLayout.fillContentSize(cellSize: .zero, assetAspectRatio: 2),
            .zero
        )

        // 滑动态（expansion 0）：全部为邻居矩形，裁满规则同样成立。
        XCTAssertTrue(machine.beginBottomStripDrag())
        for index in 0..<3 {
            XCTAssertEqual(
                itemFrameSize(at: index, expansion: 0),
                CGSize(width: metrics.neighborItemWidth, height: metrics.neighborItemHeight)
            )
            let fill = fillContentSize(at: index, expansion: 0)
            XCTAssertGreaterThanOrEqual(fill.width, metrics.neighborItemWidth - 0.000_001)
            XCTAssertGreaterThanOrEqual(fill.height, metrics.neighborItemHeight - 0.000_001)
        }

        // 标记位置规则不变：仍由项目帧右上角叠加，尺寸读自 bottomStripMarkSize。
        let marks = machine.orderedAssetIDs.map { strip.markPresentation(for: $0) }
        XCTAssertEqual(marks.map(\.isShown), [false, true, false])
        XCTAssertTrue(marks.allSatisfy { $0.size == CGFloat(configuration.bottomStripMarkSize) })
    }

    // IC-075 G108（夹具驱动）：横栏待删标记随 D 显隐，尺寸读自 bottomStripMarkSize，
    // 静止态与滑动态一致。
    func testIC075G108BottomStripMarkFollowsPendingSetAndMarkSize() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        XCTAssertEqual(configuration.bottomStripMarkSize, 14)
        XCTAssertEqual(S2BottomStripMarkPresentation.symbolName, "trash.circle.fill")

        let markSize = CGFloat(configuration.bottomStripMarkSize)
        let marked = S2BottomStripMarkPresentation.make(
            isMarked: true,
            markSize: markSize
        )
        XCTAssertTrue(marked.isShown)
        XCTAssertEqual(marked.size, 14)
        let unmarked = S2BottomStripMarkPresentation.make(
            isMarked: false,
            markSize: markSize
        )
        XCTAssertFalse(unmarked.isShown)

        let machine = makeMachine(
            configuration: configuration,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        let strip = S2BottomStripView(
            machine: machine,
            metrics: tryUnwrap(configuration.resolvedParameters).bottomStripMetrics,
            markSize: markSize,
            itemContent: { _ in AnyView(Color.clear) },
            onPhotoSwitch: {}
        )
        let idle = machine.orderedAssetIDs.map { strip.markPresentation(for: $0) }
        XCTAssertEqual(idle.map(\.isShown), [false, true, false])
        XCTAssertTrue(idle.allSatisfy { $0.size == 14 })

        XCTAssertTrue(machine.beginBottomStripDrag())
        XCTAssertEqual(machine.bottomStripState, .dragging)
        let dragging = machine.orderedAssetIDs.map {
            strip.markPresentation(for: $0)
        }
        XCTAssertEqual(dragging, idle)
    }

    // IC-075 G107（夹具驱动）：主图标记只在 V=显示 ∧ c∈D 渲染；脉冲只在 V=显示时
    // 消费 alreadyMarked 触发一次；V=隐藏时通知照常消费、不脉冲。
    func testIC075G107PrimaryMarkVisibilityMatrixAndPulseConsumption() {
        XCTAssertTrue(S2PrimaryMarkPresenter.showsMark(
            interfaceVisibility: .visible,
            isMarked: true
        ))
        XCTAssertFalse(S2PrimaryMarkPresenter.showsMark(
            interfaceVisibility: .visible,
            isMarked: false
        ))
        XCTAssertFalse(S2PrimaryMarkPresenter.showsMark(
            interfaceVisibility: .hidden,
            isMarked: true
        ))
        XCTAssertFalse(S2PrimaryMarkPresenter.showsMark(
            interfaceVisibility: .hidden,
            isMarked: false
        ))
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        XCTAssertEqual(configuration.markPulseDurationMilliseconds, 150)
        XCTAssertEqual(
            S2PrimaryMarkPresenter.markSize(
                bottomStripMarkSize: configuration.bottomStripMarkSize
            ),
            28
        )
        XCTAssertEqual(S2PrimaryMarkPresenter.symbolName, "trash.circle.fill")

        let presenter = S2PrimaryMarkPresenter()
        XCTAssertFalse(presenter.consume(nil, interfaceVisibility: .visible))
        XCTAssertEqual(presenter.consumedNoticeCount, 0)
        XCTAssertTrue(presenter.consume(
            .alreadyMarked(assetID: "asset-2"),
            interfaceVisibility: .visible
        ))
        XCTAssertEqual(presenter.pulseCount, 1)
        XCTAssertEqual(presenter.pulseID, 1)
        XCTAssertFalse(presenter.consume(
            .alreadyMarked(assetID: "asset-2"),
            interfaceVisibility: .hidden
        ))
        XCTAssertEqual(presenter.consumedNoticeCount, 2)
        XCTAssertEqual(presenter.pulseCount, 1)
    }

    // IC-075 G107 / 闸门 A（夹具驱动，真机未覆盖）：宿主 S2View 下，标记显示与脉冲
    // 期间照片几何写入为 0；已标记再上滑后通知被消费且脉冲 +1；隐藏态不脉冲。
    func testIC075G107HostedPrimaryMarkPulsesWithoutPhotoGeometryWrites() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            configuration: configuration,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        XCTAssertTrue(machine.currentIsMarked)
        let calibration = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        let presenter = S2PrimaryMarkPresenter()
        let view = S2View(
            machine: machine,
            calibration: calibration,
            assetAspectRatio: { _ in self.screenAspectRatio },
            assetIsScreenshot: { _ in true },
            photoContent: { _ in AnyView(Color.clear) },
            stripItemContent: { _ in AnyView(Color.clear) },
            albumPickerContent: { _, _ in AnyView(EmptyView()) },
            transitionDiagnostics: diagnostics,
            primaryMarkPresenter: presenter
        )
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        XCTAssertTrue(diagnostics.canStart)
        diagnostics.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)

        XCTAssertFalse(machine.handleSwipeUp())
        XCTAssertNotNil(machine.semanticNotice)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
        XCTAssertNil(machine.semanticNotice)
        XCTAssertEqual(presenter.pulseCount, 1)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
        XCTAssertTrue(machine.currentIsMarked)
        XCTAssertEqual(machine.currentAssetID, "asset-2")
        diagnostics.stop()

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        // IC-104 B（第 132 条）：隐藏态 1x 上滑完全无效果——连语义提示也不发，
        // 故消费计数停在显示态那一次（改前隐藏态也会发一次，计数为 2）。
        XCTAssertFalse(machine.handleSwipeUp())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertNil(machine.semanticNotice)
        XCTAssertEqual(presenter.consumedNoticeCount, 1)
        XCTAssertEqual(presenter.pulseCount, 1)
    }

    // IC-068 G50：相同或回退的时钟读数仍被归一为严格递增的统一事件流。
    func testIC068G50UnifiedClockRecordsAreStrictlyOrdered() {
        var readings: [CFTimeInterval] = [
            800,
            800,
            799,
            800,
            800,
            800,
            800
        ]
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator {
            readings.isEmpty ? 800 : readings.removeFirst()
        }
        let machine = makeMachine(interfaceVisibility: .hidden)
        let controller = makeNativePagerController(machine: machine)
        diagnostics.attach(controller)
        diagnostics.start()
        diagnostics.recordUpdateUIView(
            wrotePhotoGeometry: false,
            wroteAnyGeometry: false
        )
        diagnostics.recordInnerLayoutSubviews()
        diagnostics.recordOuterViewDidLayoutSubviews()
        diagnostics.stop()
        diagnostics.export()

        XCTAssertGreaterThanOrEqual(diagnostics.recordedEntries.count, 6)
        XCTAssertTrue(zip(
            diagnostics.recordedEntries,
            diagnostics.recordedEntries.dropFirst()
        ).allSatisfy { pair in
            pair.0.timestamp < pair.1.timestamp
        })
        XCTAssertTrue(diagnostics.reportText.contains(
            "顺序=全部记录按同一单调时钟严格递增"
        ))
    }

    // IC-069 G53：主线程停摆超过动画时长时，渲染层仍到达终态。
    func testIC069G53PresentationLayerFinishesWhileMainThreadIsBlocked() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let photoLayer = tryUnwrap(
            page.zoomScrollView.presentationContentView?.layer
        )
        let target = metrics(
            visibility: .hidden,
            configuration: configuration
        ).oneXDisplaySize

        XCTAssertTrue(page.applyRecognizedSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        CATransaction.flush()
        XCTAssertTrue(photoLayer.animationKeys()?.isEmpty == false)
        let keyframes = page.lastPresentationScaleKeyframes
        XCTAssertGreaterThanOrEqual(keyframes.count, 3)
        XCTAssertEqual(keyframes.first ?? -1, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            (keyframes.last ?? -1) * metrics(
                visibility: .visible,
                configuration: configuration
            ).oneXDisplaySize.width,
            target.width,
            accuracy: 0.5
        )

        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(photoLayer.animationKeys()?.isEmpty == false)
        let completedFrame = photoLayer.presentation()?.frame ??
            photoLayer.frame
        XCTAssertEqual(completedFrame.width, target.width, accuracy: 0.5)
        XCTAssertEqual(completedFrame.height, target.height, accuracy: 0.5)
        page.finishActivePresentationTransition()
    }

    // IC-069 R1b：显隐切换不重建缩略条，因而不重复进入图片请求路径。
    func testIC069R1bPresentationToggleKeepsThumbnailViewsAlive() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let calibration = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        var thumbnailAppearCount = 0
        let view = S2View(
            machine: machine,
            calibration: calibration,
            assetAspectRatio: { _ in self.screenAspectRatio },
            assetIsScreenshot: { _ in true },
            photoContent: { _ in AnyView(Color.clear) },
            stripItemContent: { _ in
                AnyView(Color.clear.onAppear {
                    thumbnailAppearCount += 1
                })
            },
            albumPickerContent: { _, _ in AnyView(EmptyView()) }
        )
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let initialAppearCount = thumbnailAppearCount
        XCTAssertGreaterThan(initialAppearCount, 0)

        XCTAssertTrue(machine.handleSingleTap())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(machine.handleSingleTap())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(thumbnailAppearCount, initialAppearCount)
    }

    // IC-069 G54/G55：双向均以源态 frame 为基准，首末帧严格命中两端。
    func testIC069G54AndG55BothDirectionsUseSourceGeometryBaseline() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let visibleSize = metrics(
            visibility: .visible,
            configuration: configuration
        ).oneXDisplaySize
        let hiddenSize = metrics(
            visibility: .hidden,
            configuration: configuration
        ).oneXDisplaySize

        func assertSequence(source: CGSize, target: CGSize) {
            let scales = page.lastPresentationScaleKeyframes
            XCTAssertGreaterThanOrEqual(scales.count, 3)
            let sizes = scales.map {
                CGSize(width: source.width * $0, height: source.height * $0)
            }
            XCTAssertEqual(sizes.first?.width ?? 0, source.width, accuracy: 0.5)
            XCTAssertEqual(sizes.first?.height ?? 0, source.height, accuracy: 0.5)
            XCTAssertEqual(sizes.last?.width ?? 0, target.width, accuracy: 0.5)
            XCTAssertEqual(sizes.last?.height ?? 0, target.height, accuracy: 0.5)
            let middle = sizes[sizes.count / 2]
            XCTAssertNotEqual(middle, source)
            XCTAssertNotEqual(middle, target)
            XCTAssertEqual(
                tryUnwrap(page.lastPresentationTransition).layoutSize,
                source
            )
            XCTAssertEqual(page.fittedSize, source)
            XCTAssertEqual(
                tryUnwrap(
                    page.zoomScrollView.presentationContentView
                ).bounds.size,
                source
            )
        }

        XCTAssertTrue(page.applyRecognizedSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        assertSequence(source: visibleSize, target: hiddenSize)
        page.finishActivePresentationTransition()
        XCTAssertEqual(page.fittedSize, hiddenSize)

        XCTAssertTrue(page.applyRecognizedSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        assertSequence(source: hiddenSize, target: visibleSize)
        page.finishActivePresentationTransition()
        XCTAssertEqual(page.fittedSize, visibleSize)
    }

    // IC-069 G56：已解析资产使用真实适配尺寸，未知资产不写猜测几何。
    func testIC069G56PinchTakeoverRequiresResolvedAssetGeometry() {
        let resolvedScrollView = S2NativeZoomScrollView(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        let resolvedContent = UIView()
        let resolvedSize = CGSize(width: 109.38, height: 600)
        resolvedScrollView.configure(
            contentView: resolvedContent,
            fittedSize: resolvedSize,
            nativeZoomBaseSize: resolvedSize,
            viewportSize: physicalSize,
            maximumZoomScale: 4,
            assetPixelSize: CGSize(width: 547, height: 3_000)
        )
        resolvedScrollView.applyNativeState(scale: 1, viewportOffset: .zero)
        let resolvedBefore = resolvedScrollView.oneXPresentationFrame

        XCTAssertTrue(resolvedScrollView.prepareForNativeZoom())
        XCTAssertEqual(
            resolvedScrollView.oneXPresentationFrame,
            resolvedBefore
        )

        let unresolvedScrollView = S2NativeZoomScrollView(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        let unresolvedContent = UIView()
        unresolvedScrollView.configure(
            contentView: unresolvedContent,
            fittedSize: resolvedSize,
            nativeZoomBaseSize: CGSize(width: 300, height: 225),
            viewportSize: physicalSize,
            maximumZoomScale: 4,
            assetPixelSize: .zero
        )
        unresolvedScrollView.applyNativeState(scale: 1, viewportOffset: .zero)
        let unresolvedFrame = unresolvedContent.frame
        let unresolvedBounds = unresolvedContent.bounds
        let unresolvedCenter = unresolvedContent.center
        let unresolvedTransform = unresolvedContent.transform
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        let diagnosticController = makeNativePagerController(
            machine: makeMachine()
        )
        diagnostics.attach(diagnosticController)
        unresolvedScrollView.transitionDiagnostics = diagnostics
        diagnostics.start()

        XCTAssertFalse(unresolvedScrollView.prepareForNativeZoom())

        diagnostics.stop()
        XCTAssertEqual(unresolvedContent.frame, unresolvedFrame)
        XCTAssertEqual(unresolvedContent.bounds, unresolvedBounds)
        XCTAssertEqual(unresolvedContent.center, unresolvedCenter)
        XCTAssertEqual(unresolvedContent.transform, unresolvedTransform)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
    }

    // IC-069 G57：无输入的一秒布局窗口内不重复写照片几何。
    func testIC069G57StableLayoutWritesNoPhotoGeometryForOneSecond() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()
        let deadline = Date(timeIntervalSinceNow: 1)

        while Date() < deadline {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        diagnostics.stop()
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
    }

    // IC-069 G58：几何写入与内外层布局事件均可定位到页面和资产。
    func testIC069G58GeometryDiagnosticsIdentifyPageAndAsset() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()

        page.zoomScrollView.writePhotoGeometry(reason: .cornerMaskReset) {
            $0.transform = $0.transform
        }
        page.zoomScrollView.setNeedsLayout()
        page.zoomScrollView.layoutIfNeeded()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        diagnostics.stop()

        let requiredNames = Set([
            "照片几何写入",
            "layoutSubviews",
            "viewDidLayoutSubviews"
        ])
        let validContexts = Set(
            machine.orderedAssetIDs.enumerated().map {
                "pageIndex=\($0.offset)；" +
                    "assetLocalIdentifier=\($0.element)"
            }
        )
        var recordedNames = Set<String>()
        for record in diagnostics.recordedEntries {
            guard case let .event(name, _, details) = record.payload,
                  requiredNames.contains(name) else {
                continue
            }
            recordedNames.insert(name)
            XCTAssertTrue(
                validContexts.contains { details.contains($0) },
                "诊断事件缺少匹配的页面与资产标识：\(details)"
            )
        }
        XCTAssertEqual(recordedNames, requiredNames)
    }

    // MARK: - IC-095 G207：apply 及其下游写入的条件化与幂等

    /// IC-095 G207 F1（夹具驱动，真机未覆盖，由 H41 场景三兜底）：
    /// 静止态（无手势、无减速、无动画、无翻页，页集合与视口未变）连调 `apply` 十次，
    /// 录制窗口内几何写入总数、外层 `setContentOffset` 次数、照片几何写入次数均为 0，
    /// 外层偏移与逐页几何一个字节不变。`wroteAnyGeometry` 即由几何写入总数的差值得出，
    /// 故总数增量为 0 等价于这十次的 `写入任意几何` 全为 `false`。
    func testIC095G207F1IdleApplyWritesNoGeometry() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        struct PageGeometry: Equatable {
            let index: Int
            let pageFrame: CGRect
            let zoomScale: CGFloat
            let contentOffset: CGPoint
            let contentSize: CGSize
            let contentInset: UIEdgeInsets
            let photoFrame: CGRect
        }
        func snapshot() -> [PageGeometry] {
            controller.pageControllers.keys.sorted().compactMap { index in
                guard let page = controller.pageControllers[index] else {
                    return nil
                }
                return PageGeometry(
                    index: index,
                    pageFrame: page.view.frame,
                    zoomScale: page.zoomScrollView.zoomScale,
                    contentOffset: page.zoomScrollView.contentOffset,
                    contentSize: page.zoomScrollView.contentSize,
                    contentInset: page.zoomScrollView.contentInset,
                    photoFrame: page.zoomScrollView
                        .presentationContentView?.frame ?? .null
                )
            }
        }

        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()
        let geometryBefore = snapshot()
        let pagingOffsetBefore = controller.pagingScrollView.contentOffset
        XCTAssertFalse(geometryBefore.isEmpty)

        for _ in 0..<10 {
            applyNativePagerController(
                controller,
                machine: machine,
                configuration: configuration
            )
        }
        diagnostics.stop()

        XCTAssertEqual(diagnostics.geometryWriteCount, 0)
        XCTAssertEqual(diagnostics.pagingContentOffsetWriteCount, 0)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
        XCTAssertEqual(snapshot(), geometryBefore)
        XCTAssertEqual(
            controller.pagingScrollView.contentOffset,
            pagingOffsetBefore
        )
        let writeEventNames = Set([
            "外层setContentOffset",
            "页frame写入",
            "内层setContentOffset",
            "照片几何写入",
            "setZoomScale"
        ])
        for record in diagnostics.recordedEntries {
            guard case let .event(name, _, details) = record.payload else {
                continue
            }
            XCTAssertFalse(writeEventNames.contains(name), name)
            if name == "吸附归位写入" {
                XCTAssertFalse(details.contains("=true"), details)
            }
        }
    }

    /// IC-095 G207 F1b（夹具驱动，真机未覆盖）：宿主 S2View 下由非几何状态发布
    /// 触发的 SwiftUI 重进，导出中每一条 `updateUIView` 的 `写入任意几何` 都是 `false`，
    /// 且录制窗口内几何写入总数为 0。
    func testIC095G207F1HostedUpdateUIViewReportsNoGeometryWrite() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(
            configuration: configuration,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        XCTAssertTrue(machine.currentIsMarked)
        let calibration = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        let view = S2View(
            machine: machine,
            calibration: calibration,
            assetAspectRatio: { _ in self.screenAspectRatio },
            assetIsScreenshot: { _ in true },
            photoContent: { _ in AnyView(Color.clear) },
            stripItemContent: { _ in AnyView(Color.clear) },
            albumPickerContent: { _, _ in AnyView(EmptyView()) },
            transitionDiagnostics: diagnostics
        )
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        XCTAssertTrue(diagnostics.canStart)
        diagnostics.start()
        // 已标记资产再上滑：只发布语义提示，不改变任何几何输入。
        XCTAssertFalse(machine.handleSwipeUp())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        diagnostics.stop()

        var updateEventCount = 0
        for record in diagnostics.recordedEntries {
            guard case let .event(name, source, details) = record.payload,
                  name == "updateUIView" else {
                continue
            }
            updateEventCount += 1
            XCTAssertEqual(
                source,
                "S2NativePhotoPager.updateUIViewController"
            )
            XCTAssertTrue(details.contains("写入照片几何=false"), details)
            XCTAssertTrue(details.contains("写入任意几何=false"), details)
        }
        XCTAssertGreaterThan(updateEventCount, 0)
        XCTAssertEqual(diagnostics.geometryWriteCount, 0)
        XCTAssertEqual(diagnostics.photoGeometryWriteCount, 0)
    }

    /// IC-095 G207 F2（夹具驱动，真机未覆盖，由 H41 场景一兜底）：
    /// Nx 下内层视口偏移逐帧变化并连调 `apply`，外层 `setContentOffset` 增量为 0，
    /// 外层偏移始终停在静止偏移上。
    func testIC095G207F2NxViewportPanKeepsPagingOffsetWritesAtZero() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(scale: 2, configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertGreaterThan(machine.scale, 1)

        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()
        let pagingOffsetBefore = controller.pagingScrollView.contentOffset

        for step in 1...20 {
            machine.reportNativeViewport(
                scale: 2,
                viewportOffset: CGSize(width: CGFloat(step), height: 0)
            )
            applyNativePagerController(
                controller,
                machine: machine,
                configuration: configuration
            )
        }
        diagnostics.stop()

        XCTAssertEqual(diagnostics.pagingContentOffsetWriteCount, 0)
        XCTAssertEqual(
            controller.pagingScrollView.contentOffset,
            pagingOffsetBefore
        )
        XCTAssertEqual(
            controller.pagingScrollView.contentOffset,
            controller.pagingScrollView.contentOffsetForPage(
                at: controller.settledIndex
            )
        )
        for record in diagnostics.recordedEntries {
            guard case let .event(name, source, _) = record.payload,
                  name == "外层setContentOffset" else {
                continue
            }
            XCTFail("Nx 平移期间不应出现外层写入：\(source)")
        }
    }

    /// IC-095 G207 F3（夹具驱动，真机未覆盖）：外层被程序性带偏 5 pt。
    /// 无手势、无动画在途时下一次 `apply` 恰写一次归位；有双击过渡在途时一次不写。
    func testIC095G207F3DeviatedPagingOffsetIsRealignedExactlyOnce() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let settledOffset = controller.pagingScrollView.contentOffsetForPage(
            at: controller.settledIndex
        )
        XCTAssertEqual(controller.pagingScrollView.contentOffset, settledOffset)

        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.start()
        controller.pagingScrollView.contentOffset = CGPoint(
            x: settledOffset.x + 5,
            y: settledOffset.y
        )
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        XCTAssertEqual(diagnostics.pagingContentOffsetWriteCount, 1)
        XCTAssertEqual(controller.pagingScrollView.contentOffset, settledOffset)

        // 再连调 apply：已归位，一次都不再写。
        for _ in 0..<5 {
            applyNativePagerController(
                controller,
                machine: machine,
                configuration: configuration
            )
        }
        XCTAssertEqual(diagnostics.pagingContentOffsetWriteCount, 1)
        diagnostics.stop()

        // 有动画在途：双击过渡期间外层被带偏也不写回。
        let transitionMachine = makeMachine(configuration: configuration)
        let transitionController = makeNativePagerController(
            machine: transitionMachine,
            configuration: configuration
        )
        let transitionWindow = UIWindow(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        transitionWindow.rootViewController = transitionController
        transitionWindow.isHidden = false
        defer { transitionWindow.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let page = tryUnwrap(
            transitionController.pageControllers[transitionMachine.currentIndex]
        )
        XCTAssertTrue(page.applyRecognizedDoubleTap(
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2)
        ))
        XCTAssertTrue(page.isDoubleTapTransitionActive)

        let transitionDiagnostics =
            S2OnDeviceTransitionDiagnosticsCoordinator()
        transitionDiagnostics.attach(transitionController)
        transitionDiagnostics.start()
        let transitionSettledOffset = transitionController.pagingScrollView
            .contentOffsetForPage(at: transitionController.settledIndex)
        let deviatedOffset = CGPoint(
            x: transitionSettledOffset.x + 5,
            y: transitionSettledOffset.y
        )
        transitionController.pagingScrollView.contentOffset = deviatedOffset
        applyNativePagerController(
            transitionController,
            machine: transitionMachine,
            configuration: configuration
        )
        transitionDiagnostics.stop()
        XCTAssertEqual(
            transitionDiagnostics.pagingContentOffsetWriteCount,
            0
        )
        XCTAssertEqual(
            transitionController.pagingScrollView.contentOffset,
            deviatedOffset
        )
    }

    /// IC-095 G207 F4（夹具驱动，真机未覆盖）：页集合变化与视口尺寸变化时
    /// `layoutNativePages` 照常重排——页 frame、外层 contentSize 与静止偏移全部跟随。
    func testIC095G207F4PageSetAndViewportChangesStillRelayout() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        func assertPageFramesMatchLayout(_ line: UInt = #line) {
            for (index, page) in controller.pageControllers {
                XCTAssertEqual(
                    page.view.frame,
                    controller.pagingScrollView.frameForPage(at: index),
                    "页 \(index) 的 frame 与布局不符",
                    line: line
                )
            }
        }
        assertPageFramesMatchLayout()
        let initialStride = controller.pagingScrollView.pageStride
        XCTAssertGreaterThan(initialStride, 0)
        XCTAssertEqual(
            controller.pagingScrollView.contentSize,
            CGSize(
                width: CGFloat(machine.orderedAssetIDs.count) * initialStride,
                height: physicalSize.height
            )
        )

        // 视口尺寸变化：重排照常发生。
        let nextViewportSize = CGSize(
            width: physicalSize.width + 40,
            height: physicalSize.height + 20
        )
        window.frame = CGRect(origin: .zero, size: nextViewportSize)
        controller.view.frame = CGRect(origin: .zero, size: nextViewportSize)
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            viewportSize: nextViewportSize
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let nextStride = controller.pagingScrollView.pageStride
        XCTAssertEqual(
            nextStride,
            nextViewportSize.width + CGFloat(configuration.pageSpacing),
            accuracy: 0.000_001
        )
        assertPageFramesMatchLayout()
        XCTAssertEqual(
            controller.pagingScrollView.contentSize,
            CGSize(
                width: CGFloat(machine.orderedAssetIDs.count) * nextStride,
                height: nextViewportSize.height
            )
        )
        XCTAssertEqual(
            controller.pagingScrollView.contentOffset,
            controller.pagingScrollView.contentOffsetForPage(
                at: controller.settledIndex
            )
        )

        // 页集合变化：翻页后新页存在、frame 正确、外层偏移落到新页。
        XCTAssertTrue(machine.handleNativePageChange(to: 2))
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            viewportSize: nextViewportSize
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(controller.settledIndex, 2)
        assertPageFramesMatchLayout()
        XCTAssertNotNil(controller.pageControllers[2])
        XCTAssertEqual(
            controller.pagingScrollView.contentOffset,
            controller.pagingScrollView.contentOffsetForPage(at: 2)
        )
    }

    // MARK: - IC-099b P1：S2 单张资产占用空间口径（④ Lynn 2026-08-28 定案 2）

    /// 卡内八个用例逐条断言。三档边界全部向下截断，无四舍五入。
    /// 与 S3 合计口径并存——本节不触碰 `DecimalVolumeFormatter` 的任何断言。
    func testIC099bP1SingleAssetVolumeUsesKilobyteMegabyteGigabyteTiers() {
        let cases: [(Int64, String)] = [
            (0, "0 KB"),
            (324_846, "324 KB"),
            (999_999, "999 KB"),
            (1_000_000, "1.0 MB"),
            (2_466_000, "2.4 MB"),
            (999_949_999, "999.9 MB"),
            (1_000_000_000, "1.0 GB"),
            (25_480_000_000, "25.4 GB")
        ]
        for (byteCount, expected) in cases {
            XCTAssertEqual(
                S2AssetVolumeFormatter.string(forByteCount: byteCount),
                expected,
                "\(byteCount) 应显示为 \(expected)"
            )
        }
    }

    /// 档位切换恰好发生在 1_000_000 与 1_000_000_000，且两侧都不进位。
    func testIC099bP1TierBoundariesTruncateInsteadOfRounding() {
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 999_999),
            "999 KB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_000_000),
            "1.0 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_099_999),
            "1.0 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 999_999_999),
            "999.9 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_000_000_000),
            "1.0 GB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_099_999_999),
            "1.0 GB"
        )
    }

    /// S2 口径与 S3 口径互不影响：同一字节数在两处给出各自档位的结果。
    func testIC099bP1SingleAssetTierDoesNotChangeAggregateTier() {
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 324_846),
            "324 KB"
        )
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 324_846),
            "0 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 2_466_000),
            "2.4 MB"
        )
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 2_466_000),
            "2 MB"
        )
    }

    // MARK: - IC-099b P2 / P3：字节数探针（纯函数与零副作用）

    private func makeProbeMeasurement(
        assetID: String = "ABCDEFGH-1234-5678",
        mediaKind: S2AssetSizeProbeMediaKind = .photo,
        isEdited: Bool = false,
        urlByteCount: Int64? = 2_466_000,
        urlFailure: S2AssetSizeProbeFailure? = nil,
        urlElapsedMilliseconds: Double = 3.214,
        dataByteCount: Int64? = 2_400_000,
        dataFailure: S2AssetSizeProbeFailure? = nil,
        dataElapsedMilliseconds: Double = 14.081
    ) -> S2AssetSizeProbeMeasurement {
        S2AssetSizeProbeMeasurement(
            assetID: assetID,
            mediaKind: mediaKind,
            isEdited: isEdited,
            urlByteCount: urlByteCount,
            urlFailure: urlFailure,
            urlElapsedMilliseconds: urlElapsedMilliseconds,
            dataByteCount: dataByteCount,
            dataFailure: dataFailure,
            dataElapsedMilliseconds: dataElapsedMilliseconds
        )
    }

    /// IC-099b P2：行格式化按卡内九列原样拼装，两途径都成功时差值为实测差。
    func testIC099bP2ProbeRowRendersNineColumnsInOrder() {
        let measurement = makeProbeMeasurement(isEdited: true)
        XCTAssertEqual(measurement.byteDelta, 66_000)
        XCTAssertEqual(
            S2AssetSizeProbeText.row(measurement),
            "ABCDEFGH｜照片｜已编辑=是｜URL字节=2466000｜数据字节=2400000｜" +
                "差值=66000｜URL耗时=3.21ms｜数据耗时=14.08ms｜失败原因=无"
        )
        XCTAssertEqual(
            S2AssetSizeProbeText.row(measurement)
                .components(separatedBy: "｜").count,
            9
        )
    }

    /// IC-099b P2：任一途径失败时该列与差值都是 `nil`，失败原因逐条列出。
    func testIC099bP2ProbeRowRendersFailuresAndNilColumns() {
        let urlFailed = makeProbeMeasurement(
            assetID: "IJKLMNOPQR",
            mediaKind: .video,
            urlByteCount: nil,
            urlFailure: .notLocal,
            urlElapsedMilliseconds: 120.5,
            dataByteCount: 13_612_393,
            dataElapsedMilliseconds: 18.03
        )
        XCTAssertNil(urlFailed.byteDelta)
        XCTAssertEqual(
            S2AssetSizeProbeText.row(urlFailed),
            "IJKLMNOP｜视频｜已编辑=否｜URL字节=nil｜数据字节=13612393｜" +
                "差值=nil｜URL耗时=120.50ms｜数据耗时=18.03ms｜" +
                "失败原因=URL:资源不在本地"
        )

        let bothFailed = makeProbeMeasurement(
            assetID: "STUVWXYZ00",
            mediaKind: .livePhoto,
            urlByteCount: nil,
            urlFailure: .noURL,
            urlElapsedMilliseconds: 0,
            dataByteCount: nil,
            dataFailure: .requestFailed,
            dataElapsedMilliseconds: 0
        )
        XCTAssertEqual(
            S2AssetSizeProbeText.row(bothFailed),
            "STUVWXYZ｜LivePhoto｜已编辑=否｜URL字节=nil｜数据字节=nil｜" +
                "差值=nil｜URL耗时=0.00ms｜数据耗时=0.00ms｜" +
                "失败原因=URL:无可用URL，数据:请求失败"
        )
    }

    /// IC-099b P2：失败原因枚举齐全——七个分支各有互不相同的非空文案，
    /// 且每一个都能在行文本里原样出现。
    func testIC099bP2ProbeFailureReasonsAreCompleteAndDistinct() {
        XCTAssertEqual(S2AssetSizeProbeFailure.allCases.count, 7)
        XCTAssertEqual(S2AssetSizeProbeMediaKind.allCases.count, 3)

        var names = Set<String>()
        for failure in S2AssetSizeProbeFailure.allCases {
            XCTAssertFalse(failure.displayName.isEmpty, failure.rawValue)
            names.insert(failure.displayName)
            let row = S2AssetSizeProbeText.row(makeProbeMeasurement(
                urlByteCount: nil,
                urlFailure: failure
            ))
            XCTAssertTrue(
                row.contains("失败原因=URL:" + failure.displayName),
                row
            )
        }
        XCTAssertEqual(names.count, S2AssetSizeProbeFailure.allCases.count)

        var kindNames = Set<String>()
        for kind in S2AssetSizeProbeMediaKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty, kind.rawValue)
            kindNames.insert(kind.displayName)
        }
        XCTAssertEqual(
            kindNames.count,
            S2AssetSizeProbeMediaKind.allCases.count
        )
    }

    /// IC-099b P2：汇总行给出两途径成功率、逐类样本数、已编辑数与差值非零行数。
    func testIC099bP2ProbeSummaryCountsSuccessKindsAndDeltas() {
        let measurements = [
            makeProbeMeasurement(assetID: "AAAAAAAA"),
            makeProbeMeasurement(
                assetID: "BBBBBBBB",
                mediaKind: .video,
                isEdited: true,
                urlByteCount: nil,
                urlFailure: .notLocal
            ),
            makeProbeMeasurement(
                assetID: "CCCCCCCC",
                mediaKind: .livePhoto,
                urlByteCount: 1_000,
                dataByteCount: 1_000
            )
        ]
        let summary = S2AssetSizeProbeText.summary(measurements)
        XCTAssertTrue(
            summary.contains("URL途径成功=2/3（66.7%）"),
            summary
        )
        XCTAssertTrue(
            summary.contains("数据途径成功=3/3（100.0%）"),
            summary
        )
        XCTAssertTrue(
            summary.contains("照片=1｜LivePhoto=1｜视频=1"),
            summary
        )
        XCTAssertTrue(summary.contains("已编辑样本=1"), summary)
        // 第一条差值 66000 非零；第二条 URL 失败不计；第三条差值 0 不计。
        XCTAssertTrue(
            summary.contains("两途径均成功且差值非零=1"),
            summary
        )
        XCTAssertTrue(
            summary.contains("失败原因分布：URL:资源不在本地=1"),
            summary
        )
    }

    /// IC-099b P2：头部声明列清单与样本／上限，超出上限时注明只取前 N 个。
    func testIC099bP2ProbeHeaderDeclaresColumnsAndLimitNote() {
        let within = S2AssetSizeProbeText.header(
            sampleCount: 12,
            totalCount: 12,
            limit: 60
        )
        XCTAssertTrue(within.contains("格式版本=1"), within)
        XCTAssertTrue(
            within.contains("列=" + S2AssetSizeProbeText.columns),
            within
        )
        XCTAssertTrue(
            within.contains("样本数=12；范围内资产总数=12；上限=60"),
            within
        )
        XCTAssertFalse(within.contains("只取前"), within)

        let truncated = S2AssetSizeProbeText.header(
            sampleCount: 60,
            totalCount: 128,
            limit: 60
        )
        XCTAssertTrue(truncated.contains("只取前 60 个"), truncated)
    }

    /// IC-099b P3：探针未被触发时零副作用——不取数、不出报告、不进运行态。
    func testIC099bP3ProbeIsInertUntilExplicitlyRun() {
        let prober = CountingAssetSizeProber()
        let coordinator = S2AssetSizeProbeCoordinator()

        XCTAssertFalse(coordinator.isRunning)
        XCTAssertTrue(coordinator.reportText.isEmpty)
        XCTAssertTrue(coordinator.progressText.isEmpty)
        XCTAssertTrue(coordinator.measurements.isEmpty)
        XCTAssertFalse(coordinator.canExport)
        XCTAssertEqual(prober.measureCount, 0)

        // 空范围同样不启动：不置运行态、不发起任何取数。
        coordinator.run(assetIDs: [], using: prober)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(coordinator.isRunning)
        XCTAssertTrue(coordinator.reportText.isEmpty)
        XCTAssertEqual(prober.measureCount, 0)
    }

    /// IC-099b P3：显式运行后逐资产串行取数一次，报告含头部、每行与汇总。
    func testIC099bP3ProbeRunMeasuresEachAssetOnceAndBuildsReport() {
        let prober = CountingAssetSizeProber()
        let coordinator = S2AssetSizeProbeCoordinator()
        let assetIDs = ["asset-1", "asset-2", "asset-3"]

        coordinator.run(assetIDs: assetIDs, using: prober)
        let deadline = Date(timeIntervalSinceNow: 2)
        while coordinator.isRunning, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        XCTAssertFalse(coordinator.isRunning)
        XCTAssertEqual(prober.measureCount, assetIDs.count)
        XCTAssertEqual(prober.requestedAssetIDs, assetIDs)
        XCTAssertEqual(coordinator.measurements.count, assetIDs.count)
        XCTAssertTrue(coordinator.canExport)
        XCTAssertEqual(
            coordinator.progressText,
            S2AssetSizeProbeText.progress(finished: 3, total: 3)
        )
        for assetID in assetIDs {
            XCTAssertTrue(
                coordinator.reportText.contains(
                    S2AssetSizeProbeText.identifierPrefix(assetID)
                ),
                assetID
            )
        }
        XCTAssertTrue(
            coordinator.reportText.contains("格式版本=1"),
            coordinator.reportText
        )
        XCTAssertTrue(
            coordinator.reportText.contains("汇总｜逐类样本数："),
            coordinator.reportText
        )
    }

    /// IC-099b P3：范围超过上限时只取前 60 个，并在头部注明总数。
    func testIC099bP3ProbeStopsAtAssetLimitAndNotesTotal() {
        let prober = CountingAssetSizeProber()
        let coordinator = S2AssetSizeProbeCoordinator()
        let assetIDs = (1...70).map { "asset-\($0)" }

        XCTAssertEqual(S2AssetSizeProbeCoordinator.assetLimit, 60)
        coordinator.run(assetIDs: assetIDs, using: prober)
        let deadline = Date(timeIntervalSinceNow: 5)
        while coordinator.isRunning, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        XCTAssertFalse(coordinator.isRunning)
        XCTAssertEqual(prober.measureCount, 60)
        XCTAssertEqual(coordinator.measurements.count, 60)
        XCTAssertTrue(
            coordinator.reportText.contains(
                "样本数=60；范围内资产总数=70；上限=60"
            ),
            coordinator.reportText
        )
        XCTAssertTrue(
            coordinator.reportText.contains("只取前 60 个"),
            coordinator.reportText
        )
    }

    // MARK: - IC-099 阶段二：顶部信息区（日期主行 + 序号·占用空间副行）

    private func zhCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return tryUnwrap(calendar.date(from: components))
    }

    /// IC-104 A：路线分派六行全覆盖（三类型 × 是否已编辑）。
    ///
    /// 第 133 条把「占用空间」定为**原始资源字节数**，已编辑资产一律走原始主资源；
    /// 未编辑资产维持 IC-099 的两条 URL 路线。
    func testIC104AVolumeRouteDispatchCoversAllSixRows() {
        // 未编辑视频走 requestAVAsset → URL
        XCTAssertEqual(
            S2AssetVolumeRouter.route(mediaKind: .video, isEdited: false),
            .videoAssetURL
        )
        // 未编辑照片 / LivePhoto 走 contentEditingInput → fullSizeImageURL
        XCTAssertEqual(
            S2AssetVolumeRouter.route(mediaKind: .photo, isEdited: false),
            .contentEditingInputURL
        )
        XCTAssertEqual(
            S2AssetVolumeRouter.route(mediaKind: .livePhoto, isEdited: false),
            .contentEditingInputURL
        )
        // 已编辑资产（三类型全部）走原始主资源流式累加
        XCTAssertEqual(
            S2AssetVolumeRouter.route(mediaKind: .photo, isEdited: true),
            .originalPrimaryResource
        )
        XCTAssertEqual(
            S2AssetVolumeRouter.route(mediaKind: .livePhoto, isEdited: true),
            .originalPrimaryResource
        )
        // 已编辑视频改走原始主资源（IC-099 时走 videoAssetURL，第 133 条改口径）
        XCTAssertEqual(
            S2AssetVolumeRouter.route(mediaKind: .video, isEdited: true),
            .originalPrimaryResource
        )
        // 三条路线各不相同，且枚举没有第四条
        XCTAssertEqual(S2AssetVolumeRoute.allCases.count, 3)
        // 六行覆盖三类型 × 两编辑态，无遗漏
        XCTAssertEqual(S2AssetSizeProbeMediaKind.allCases.count, 3)
        for kind in S2AssetSizeProbeMediaKind.allCases {
            for edited in [false, true] {
                let route = S2AssetVolumeRouter.route(
                    mediaKind: kind,
                    isEdited: edited
                )
                // 已编辑一律原始主资源；未编辑按类型二分
                XCTAssertEqual(
                    route == .originalPrimaryResource,
                    edited,
                    "\(kind)/\(edited)"
                )
            }
        }
    }

    /// IC-099 阶段二 C1 续：任一路失败 → 副行只显示序号，不显示大小、不显示占位符。
    func testIC099v2C1FailureDegradesToPositionOnly() {
        XCTAssertEqual(
            S2TopBarInfoPresentation.subtitleText(
                currentIndex: 2,
                totalCount: 128,
                byteCount: nil
            ),
            "3/128"
        )
        // 负字节数同样按失败处理
        XCTAssertEqual(
            S2TopBarInfoPresentation.subtitleText(
                currentIndex: 0,
                totalCount: 1,
                byteCount: -1
            ),
            "1/1"
        )
    }

    /// IC-099 阶段二 C2：会话级缓存命中不再发起第二次取数（含失败结论）。
    func testIC099v2C2StoreFetchesEachAssetAtMostOnce() {
        let provider = CountingAssetVolumeProvider(byteCounts: [
            "asset-1": 2_466_000,
            "asset-2": nil
        ])
        let store = S2AssetVolumeStore()

        store.requestIfNeeded(assetID: "asset-1", using: provider)
        store.requestIfNeeded(assetID: "asset-1", using: provider)
        store.requestIfNeeded(assetID: "asset-2", using: provider)
        let deadline = Date(timeIntervalSinceNow: 2)
        while !(store.isResolved("asset-1") && store.isResolved("asset-2")),
              Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        XCTAssertEqual(store.byteCount(for: "asset-1"), 2_466_000)
        XCTAssertNil(store.byteCount(for: "asset-2"))
        XCTAssertTrue(store.isResolved("asset-2"))
        XCTAssertEqual(provider.requestedAssetIDs.sorted(), ["asset-1", "asset-2"])

        // 已解析（成功与失败各一）后再请求，都不再发起
        store.requestIfNeeded(assetID: "asset-1", using: provider)
        store.requestIfNeeded(assetID: "asset-2", using: provider)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(provider.requestCount, 2)
    }

    /// IC-099 阶段二 C3：未就绪 / 失败 / 切资产三态的副行文本。
    func testIC099v2C3SubtitleReflectsPendingFailureAndAssetSwitch() {
        let provider = CountingAssetVolumeProvider(byteCounts: [
            "asset-1": 2_466_000,
            "asset-2": 324_846
        ])
        let store = S2AssetVolumeStore()

        // 未就绪：只显示序号
        XCTAssertNil(store.byteCount(for: "asset-1"))
        XCTAssertEqual(
            S2TopBarInfoPresentation.subtitleText(
                currentIndex: 0,
                totalCount: 2,
                byteCount: store.byteCount(for: "asset-1")
            ),
            "1/2"
        )

        store.requestIfNeeded(assetID: "asset-1", using: provider)
        let deadline = Date(timeIntervalSinceNow: 2)
        while !store.isResolved("asset-1"), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertEqual(
            S2TopBarInfoPresentation.subtitleText(
                currentIndex: 0,
                totalCount: 2,
                byteCount: store.byteCount(for: "asset-1")
            ),
            "1/2 · 2.4 MB"
        )

        // 切到还没取数的资产：读到的是 nil，**不会是上一张的值**
        XCTAssertNil(store.byteCount(for: "asset-2"))
        XCTAssertEqual(
            S2TopBarInfoPresentation.subtitleText(
                currentIndex: 1,
                totalCount: 2,
                byteCount: store.byteCount(for: "asset-2")
            ),
            "2/2"
        )

        store.requestIfNeeded(assetID: "asset-2", using: provider)
        let secondDeadline = Date(timeIntervalSinceNow: 2)
        while !store.isResolved("asset-2"), Date() < secondDeadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertEqual(
            S2TopBarInfoPresentation.subtitleText(
                currentIndex: 1,
                totalCount: 2,
                byteCount: store.byteCount(for: "asset-2")
            ),
            "2/2 · 324 KB"
        )
    }

    /// IC-099 阶段二 C4：日期主行——当年 `M月d日`、非当年 `yyyy年M月d日`、
    /// 元旦与跨年边界、`nil` 不显示主行。
    func testIC099v2C4DateTextCoversYearBoundaryAndNil() {
        let calendar = zhCalendar()
        let now = date(2026, 8, 28, calendar: calendar)

        XCTAssertEqual(
            S2TopBarInfoPresentation.dateText(
                creationDate: date(2026, 8, 27, calendar: calendar),
                now: now,
                calendar: calendar
            ),
            "8月27日"
        )
        // 当年元旦：仍是当年格式，月与日都不补零
        XCTAssertEqual(
            S2TopBarInfoPresentation.dateText(
                creationDate: date(2026, 1, 1, calendar: calendar),
                now: now,
                calendar: calendar
            ),
            "1月1日"
        )
        // 跨年前一天：非当年格式
        XCTAssertEqual(
            S2TopBarInfoPresentation.dateText(
                creationDate: date(2025, 12, 31, calendar: calendar),
                now: now,
                calendar: calendar
            ),
            "2025年12月31日"
        )
        // 老照片
        XCTAssertEqual(
            S2TopBarInfoPresentation.dateText(
                creationDate: date(2011, 3, 5, calendar: calendar),
                now: now,
                calendar: calendar
            ),
            "2011年3月5日"
        )
        // 无拍摄日期：主行不显示
        XCTAssertNil(
            S2TopBarInfoPresentation.dateText(
                creationDate: nil,
                now: now,
                calendar: calendar
            )
        )
    }

    /// IC-099 阶段二 C4 续：副行原文——半角斜杠无空格、分隔为「 · 」、
    /// 口径沿用 IC-099b 已交付的 `S2AssetVolumeFormatter`（视频同规则）。
    func testIC099v2C4SubtitleTextUsesSlashAndMiddleDot() {
        XCTAssertEqual(
            S2TopBarInfoPresentation.subtitleText(
                currentIndex: 2,
                totalCount: 128,
                byteCount: 2_466_000
            ),
            "3/128 · 2.4 MB"
        )
        // 分隔符是「空格 + U+00B7 + 空格」
        let text = S2TopBarInfoPresentation.subtitleText(
            currentIndex: 0,
            totalCount: 9,
            byteCount: 25_480_000_000
        )
        XCTAssertEqual(text, "1/9 \u{00B7} 25.4 GB")
        XCTAssertFalse(text.contains(" / "))

        // 三档口径与 IC-099b P1 同源，视频资产走同一函数、同一结果
        for (byteCount, expected) in [
            (Int64(0), "1/1 · 0 KB"),
            (Int64(324_846), "1/1 · 324 KB"),
            (Int64(999_999), "1/1 · 999 KB"),
            (Int64(1_000_000), "1/1 · 1.0 MB"),
            (Int64(999_949_999), "1/1 · 999.9 MB"),
            (Int64(1_000_000_000), "1/1 · 1.0 GB")
        ] {
            XCTAssertEqual(
                S2TopBarInfoPresentation.subtitleText(
                    currentIndex: 0,
                    totalCount: 1,
                    byteCount: byteCount
                ),
                expected
            )
        }
    }
    // MARK: - IC-100 v2：底部竖向排布互换（安全区 → 操作条 → 横栏）

    /// IC-100 B1：触控带中心锚在安全区上沿 + 22；操作条同时满足 L2 与 L4；
    /// 横栏在操作条上方，底缘按推导式落在「可见图标带顶缘 + 30.7」。
    func testIC100B1BottomOverlayOrderAndAnchors() {
        let snapshot = overlaySnapshot()
        let frames = snapshot.bottomElementFrames
        XCTAssertEqual(frames.count, 4)
        let actionFrames = Array(frames.prefix(3))
        let stripFrame = frames[3]
        let viewportBottom = overlayPhysicalSize.height
        let safeBottom = viewportBottom - overlaySafeAreaInsets.bottom

        for frame in actionFrames {
            // 触控带中心距视口底 = 安全区底 + 半个触控带（常规机型 34 + 22 = 56.0）
            XCTAssertEqual(
                viewportBottom - frame.midY,
                overlaySafeAreaInsets.bottom +
                    S2OverlayLayout.minimumTouchTarget / 2,
                accuracy: 0.5
            )
            XCTAssertEqual(viewportBottom - frame.midY, 56, accuracy: 0.5)
            // L2 / L4 判据原样，一行未改
            XCTAssertLessThanOrEqual(frame.maxY, safeBottom)
            XCTAssertGreaterThanOrEqual(
                frame.width,
                S2OverlayLayout.minimumTouchTarget
            )
            XCTAssertGreaterThanOrEqual(
                frame.height,
                S2OverlayLayout.minimumTouchTarget
            )
        }

        // 顺序：横栏整条在操作条触控带上方
        XCTAssertLessThan(stripFrame.maxY, actionFrames[0].minY)
        XCTAssertLessThanOrEqual(stripFrame.maxY, safeBottom)

        // 横栏底缘距视口底 = 可见图标带顶缘 + 30.7（常规机型 67.0 + 30.7 = 97.7）
        XCTAssertEqual(
            viewportBottom - stripFrame.maxY,
            S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: overlaySafeAreaInsets.bottom
            ),
            accuracy: 1
        )
        XCTAssertEqual(viewportBottom - stripFrame.maxY, 97.7, accuracy: 1)

        // 触控带顶缘与横栏底缘之间的净空（卡内要求 ≥ 15 pt）
        XCTAssertGreaterThanOrEqual(
            actionFrames[0].minY - stripFrame.maxY,
            15
        )
    }

    /// IC-100 B1 续：安全区更高时整组随之上移，L2 仍成立，两间距语义不变。
    func testIC100B1LayoutFollowsLargerBottomSafeArea() {
        let tallInsets = S2OverlaySafeAreaInsets(
            top: 59,
            leading: 0,
            bottom: 60,
            trailing: 0
        )
        let snapshot = S2OverlayLayout.snapshot(
            physicalSize: overlayPhysicalSize,
            safeAreaInsets: tallInsets,
            bottomStripHeight: 72,
            showsRecentAlbumAction: true,
            calibrationState: .initial
        )
        let frames = snapshot.bottomElementFrames
        let actionFrame = frames[0]
        let stripFrame = frames[3]
        let viewportBottom = overlayPhysicalSize.height
        let safeBottom = viewportBottom - tallInsets.bottom

        XCTAssertEqual(
            viewportBottom - actionFrame.midY,
            tallInsets.bottom + S2OverlayLayout.minimumTouchTarget / 2,
            accuracy: 0.5
        )
        XCTAssertEqual(viewportBottom - actionFrame.midY, 82, accuracy: 0.5)
        for frame in frames {
            XCTAssertLessThanOrEqual(frame.maxY, safeBottom)
        }
        // 两间距语义保持：横栏底缘仍是「可见带顶缘 + 30.7」
        XCTAssertEqual(
            viewportBottom - stripFrame.maxY -
                S2OverlayLayout.actionVisibleBandTopFromViewportBottom(
                    safeAreaBottom: tallInsets.bottom
                ),
            S2OverlayLayout.stripToActionVisibleBandSpacing,
            accuracy: 0.000_001
        )
    }

    /// IC-100 B2：底部几何与 `V` 无关——`V` 只在渲染侧作整体显隐门控
    /// （`interfaceOverlay` 的 opacity / hitTesting / accessibilityHidden，本卡未动）。
    /// 因此隐藏再恢复后几何逐值相同。
    func testIC100B2GeometryIsIndependentOfInterfaceVisibility() {
        let machine = makeMachine(interfaceVisibility: .visible)
        let before = overlaySnapshot()

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        let whileHidden = overlaySnapshot()
        XCTAssertEqual(whileHidden, before)

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(overlaySnapshot(), before)
    }

    /// IC-100 B6：toast 底缘 = 横栏顶缘 + 8，且与横栏、操作条均无纵向重叠。
    func testIC100B6ToastSitsAboveStripWithoutOverlap() {
        let safeBottom = overlaySafeAreaInsets.bottom
        let stripHeight: CGFloat = 72
        let actionTop = S2OverlayLayout.actionBandTopFromViewportBottom(
            safeAreaBottom: safeBottom
        )
        let stripBottom = S2OverlayLayout.stripBottomFromViewportBottom(
            safeAreaBottom: safeBottom
        )
        let stripTop = S2OverlayLayout.stripTopFromViewportBottom(
            safeAreaBottom: safeBottom,
            bottomStripHeight: stripHeight
        )
        let toastBottom = S2OverlayLayout.toastBottomFromViewportBottom(
            safeAreaBottom: safeBottom,
            bottomStripHeight: stripHeight
        )

        XCTAssertEqual(S2OverlayLayout.toastToStripSpacing, 8)
        XCTAssertEqual(
            toastBottom - stripTop,
            S2OverlayLayout.toastToStripSpacing,
            accuracy: 0.5
        )
        // 三者自下而上严格递增：操作条触控带顶 < 横栏底 < 横栏顶 < toast 底
        XCTAssertLessThan(actionTop, stripBottom)
        XCTAssertLessThan(stripBottom, stripTop)
        XCTAssertLessThan(stripTop, toastBottom)

        // 与快照里的横栏帧对齐
        let stripFrame = overlaySnapshot().bottomElementFrames[3]
        XCTAssertEqual(
            overlayPhysicalSize.height - stripFrame.minY,
            stripTop,
            accuracy: 0.000_001
        )
    }

    /// IC-100 B7：门禁侧几何模型与渲染侧共用同一组推导式。
    ///
    /// 渲染侧 `S2View.interfaceOverlay` 的两个 `.padding(.bottom, …)` 传的就是
    /// `stripBottomFromViewportBottom` 与 `actionBandBottomFromViewportBottom`；
    /// 本断言逐值核对「快照帧距视口底」等于同名函数的返回值，两侧不会各算各的。
    /// 逐像素比对渲染结果需要给产品视图加测试专用探针，属「不为测试改产品」禁止项，
    /// 未做——报告已如实标注并挂账收敛卡。
    func testIC100B7SnapshotMatchesRenderDerivations() {
        let safeBottom = overlaySafeAreaInsets.bottom
        let frames = overlaySnapshot().bottomElementFrames
        let actionFrame = frames[0]
        let stripFrame = frames[3]
        let viewportBottom = overlayPhysicalSize.height

        XCTAssertEqual(
            viewportBottom - stripFrame.maxY,
            S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            viewportBottom - actionFrame.maxY,
            S2OverlayLayout.actionBandBottomFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            accuracy: 0.000_001
        )
        // 「操作条避让安全区贴近底缘」＝触控带底缘恰为安全区上沿
        XCTAssertEqual(
            S2OverlayLayout.actionBandBottomFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            safeBottom,
            accuracy: 0.000_001
        )
        // 推导式自洽：顶 − 底 = 触控带高；可见带顶 − 中心 = 半个可见带
        XCTAssertEqual(
            S2OverlayLayout.actionBandTopFromViewportBottom(
                safeAreaBottom: safeBottom
            ) -
                S2OverlayLayout.actionBandBottomFromViewportBottom(
                    safeAreaBottom: safeBottom
                ),
            S2OverlayLayout.minimumTouchTarget,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2OverlayLayout.actionVisibleBandTopFromViewportBottom(
                safeAreaBottom: safeBottom
            ) -
                S2OverlayLayout.actionBandCenterFromViewportBottom(
                    safeAreaBottom: safeBottom
                ),
            S2OverlayLayout.actionBarVisibleBandHeight / 2,
            accuracy: 0.000_001
        )
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

    private enum MonotonicDirection {
        case increasing
        case decreasing
    }

    private func capturePresentationToggle(
        machine: S2StateMachine,
        controller: S2NativePagerViewController,
        page: S2NativeZoomPageController,
        configuration: S2CalibrationConfiguration
    ) -> [IC064PresentationSample] {
        let sampler = IC064PresentationLayerSampler(page: page)
        sampler.start()
        XCTAssertTrue(page.applyRecognizedSingleTap())
        controller.viewDidLayoutSubviews()
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration
        )
        let deadline = Date(timeIntervalSinceNow: 1)
        while page.isPresentationTransitionActive, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
        XCTAssertFalse(page.isPresentationTransitionActive)
        return sampler.stop()
    }

    private func captureStablePresentationWindow(
        page: S2NativeZoomPageController,
        duration: TimeInterval
    ) -> [IC064PresentationSample] {
        let sampler = IC064PresentationLayerSampler(page: page)
        sampler.start()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
        return sampler.stop()
    }

    private func printPresentationSummary(
        direction: String,
        samples: [IC064PresentationSample]
    ) {
        let widths = samples.map {
            String(format: "%.3f", $0.frame.width)
        }.joined(separator: ",")
        print(String(format:
            "IC064_FINAL_CURVE direction=%@ samples=%d duration=%.6f widths=%@",
            direction,
            samples.count,
            samples.last?.timestamp ?? 0,
            widths
        ))
    }

    private func assertMonotonic(
        _ values: [CGFloat],
        direction: MonotonicDirection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(values.count, 2, file: file, line: line)
        for (previous, next) in zip(values, values.dropFirst()) {
            switch direction {
            case .increasing:
                XCTAssertGreaterThanOrEqual(
                    next + 0.01,
                    previous,
                    file: file,
                    line: line
                )
            case .decreasing:
                XCTAssertLessThanOrEqual(
                    next - 0.01,
                    previous,
                    file: file,
                    line: line
                )
            }
        }
    }

    private func assertSpringOvershootAndConvergence(
        _ values: [CGFloat],
        source: CGFloat,
        target: CGFloat,
        requiresMeasuredOvershoot: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(values.count, 3, file: file, line: line)
        let amplitude = abs(target - source)
        if target > source {
            let extreme = values.max() ?? source
            XCTAssertLessThanOrEqual(
                extreme,
                target + amplitude * 0.10 + 0.01,
                file: file,
                line: line
            )
            if requiresMeasuredOvershoot {
                XCTAssertGreaterThan(
                    extreme,
                    target,
                    file: file,
                    line: line
                )
            }
            // 未测到过冲时极值即末样本，尾部切片只有一个元素——单元素平凡单调，
            // 无需再查（assertMonotonic 要求至少两个元素）。
            if let index = values.firstIndex(of: extreme),
               values.count - index >= 2 {
                assertMonotonic(
                    Array(values[index...]),
                    direction: .decreasing,
                    file: file,
                    line: line
                )
            }
        } else {
            let extreme = values.min() ?? source
            XCTAssertGreaterThanOrEqual(
                extreme,
                target - amplitude * 0.10 - 0.01,
                file: file,
                line: line
            )
            if requiresMeasuredOvershoot {
                XCTAssertLessThan(
                    extreme,
                    target,
                    file: file,
                    line: line
                )
            }
            // 同上：未测到过冲时尾部切片只有一个元素。
            if let index = values.firstIndex(of: extreme),
               values.count - index >= 2 {
                assertMonotonic(
                    Array(values[index...]),
                    direction: .increasing,
                    file: file,
                    line: line
                )
            }
        }
    }

    private func fitBorderPixelGrays(
        style: UIUserInterfaceStyle,
        photoGray: Int
    ) -> [Int] {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            photoContent: { _, size, _, _ in
                AnyView(
                    Color(
                        UIColor(
                            white: CGFloat(photoGray) / 255,
                            alpha: 1
                        )
                    )
                    .frame(width: size.width, height: size.height)
                )
            }
        )
        let host = UIViewController()
        host.view.frame = CGRect(origin: .zero, size: physicalSize)
        host.view.backgroundColor = style == .dark ? .black : .white
        host.addChild(controller)
        controller.view.frame = host.view.bounds
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(userInterfaceStyle: style),
            forChild: controller
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        host.view.layoutIfNeeded()

        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let contentView = tryUnwrap(
            page.zoomScrollView.presentationContentView
        )
        let frame = contentView.convert(contentView.bounds, to: host.view)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            bounds: host.view.bounds,
            format: format
        ).image { _ in
            _ = host.view.drawHierarchy(
                in: host.view.bounds,
                afterScreenUpdates: true
            )
        }
        return [
            pixelGray(
                image: image,
                point: CGPoint(x: frame.minX + 0.5, y: frame.midY)
            ),
            pixelGray(
                image: image,
                point: CGPoint(x: frame.maxX - 0.5, y: frame.midY)
            )
        ]
    }

    private struct BorderScanScene {
        let window: UIWindow
        let host: UIViewController
        let controller: S2NativePagerViewController
        let machine: S2StateMachine
        let page: S2NativeZoomPageController
    }

    private func makeBorderScanScene(
        style: UIUserInterfaceStyle,
        photoGray: Int,
        configuration: S2CalibrationConfiguration
    ) -> BorderScanScene {
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            photoContent: { _, size, _, _ in
                AnyView(
                    Color(
                        UIColor(
                            white: CGFloat(photoGray) / 255,
                            alpha: 1
                        )
                    )
                    .frame(width: size.width, height: size.height)
                )
            }
        )
        let host = UIViewController()
        host.view.frame = CGRect(origin: .zero, size: physicalSize)
        host.view.backgroundColor = style == .dark ? .black : .white
        host.addChild(controller)
        controller.view.frame = host.view.bounds
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(userInterfaceStyle: style),
            forChild: controller
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = host
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        host.view.layoutIfNeeded()
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        return BorderScanScene(
            window: window,
            host: host,
            controller: controller,
            machine: machine,
            page: page
        )
    }

    private func renderBorderScan(
        _ scene: BorderScanScene
    ) -> (frame: CGRect, image: UIImage) {
        scene.host.view.layoutIfNeeded()
        let contentView = tryUnwrap(
            scene.page.zoomScrollView.presentationContentView
        )
        let frame = contentView.convert(contentView.bounds, to: scene.host.view)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            bounds: scene.host.view.bounds,
            format: format
        ).image { _ in
            _ = scene.host.view.drawHierarchy(
                in: scene.host.view.bounds,
                afterScreenUpdates: true
            )
        }
        return (frame, image)
    }

    /// 扫描读数：首个非背景样本灰度，以及照片区域之前的描边覆盖量（样本数）。
    private func borderScanReading(
        grays: [Int],
        photoGray: Int
    ) -> (firstNonBackground: Int?, coverage: CGFloat) {
        var first: Int?
        var coverage: CGFloat = 0
        for gray in grays {
            if gray >= 250 {
                if first != nil {
                    break
                }
                continue
            }
            if first == nil {
                first = gray
            }
            if gray >= photoGray - 3 {
                break
            }
            coverage += CGFloat(255 - gray) / 255
        }
        return (first, coverage)
    }

    private func grayRun(
        image: UIImage,
        from start: CGPoint,
        step: CGVector,
        count: Int
    ) -> [Int] {
        (0..<count).map { index in
            pixelGray(
                image: image,
                point: CGPoint(
                    x: start.x + step.dx * CGFloat(index),
                    y: start.y + step.dy * CGFloat(index)
                )
            )
        }
    }

    private func viewportBackgroundPixelGray(
        controller: UIViewController
    ) -> Int {
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            bounds: controller.view.bounds,
            format: format
        ).image { _ in
            _ = controller.view.drawHierarchy(
                in: controller.view.bounds,
                afterScreenUpdates: true
            )
        }
        return pixelGray(
            image: image,
            point: CGPoint(x: 5, y: physicalSize.height / 2)
        )
    }

    private func pixelGray(image: UIImage, point: CGPoint) -> Int {
        guard let source = image.cgImage else {
            XCTFail("截图缺少像素数据")
            return -1
        }
        let x = min(
            source.width - 1,
            max(0, Int(point.x * image.scale))
        )
        let y = min(
            source.height - 1,
            max(0, Int(point.y * image.scale))
        )
        guard let cropped = source.cropping(to: CGRect(
            x: x,
            y: y,
            width: 1,
            height: 1
        )) else {
            XCTFail("无法裁取描边像素")
            return -1
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let didDraw = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(
                cropped,
                in: CGRect(x: 0, y: 0, width: 1, height: 1)
            )
            return true
        }
        guard didDraw else {
            XCTFail("无法创建像素取样上下文")
            return -1
        }
        return (Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])) / 3
    }

    /// IC-104 C v2：夹具（`.zero` 安全区）下截图**显示态**适配带的带高。
    /// 隐藏态不走这条推导——按规格 v16 第 121/177 行仍填满视口。
    private func expectedScreenshotBandHeight(
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> CGFloat {
        S2ViewportLayout.screenshotBandHeight(
            physicalSize: physicalSize,
            safeAreaInsets: .zero,
            bottomStripHeight: max(
                CGFloat(configuration.bottomStripCurrentItemSize),
                CGFloat(configuration.bottomStripNeighborItemHeight)
            )
        )
    }

    /// IC-104 C v3：夹具（`.zero` 安全区）下截图**显示态** `s = 1` 的帧中心。
    /// 即适配带中心。`s > 1` 的几何基准中心恒为视口中心（SPEC 决策 20），
    /// 两者之差即捏合／双击进入瞬间的位置跳变量。
    private func expectedScreenshotBandCenterY(
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> CGFloat {
        S2ViewportLayout.screenshotBandTop(physicalSize: physicalSize) +
            expectedScreenshotBandHeight(configuration: configuration) / 2
    }

    /// `s = 1` 显示态截图中心与 `s > 1` 基准中心之差（跳变量），恒 > 0。
    private func expectedOneXToNxCenterJump(
        configuration: S2CalibrationConfiguration = .factoryPlaceholder
    ) -> CGFloat {
        physicalSize.height / 2 -
            expectedScreenshotBandCenterY(configuration: configuration)
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
            isScreenshot: true,
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
            isScreenshot: false,
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

    private func makeIC065HostedPage(
        assetAspectRatio: CGFloat,
        interfaceVisibility: S2InterfaceVisibility = .visible,
        isScreenshot: Bool = true
    ) -> (
        window: UIWindow,
        machine: S2StateMachine,
        controller: S2NativePagerViewController,
        page: S2NativeZoomPageController
    ) {
        let machine = makeMachine(interfaceVisibility: interfaceVisibility)
        let controller = makeNativePagerController(
            machine: machine,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: isScreenshot
        )
        let window = UIWindow(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        window.rootViewController = controller
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let page = tryUnwrap(
            controller.pageControllers[machine.currentIndex]
        )
        return (window, machine, controller, page)
    }

    private func ic065PresentationFrameInWindow(
        page: S2NativeZoomPageController,
        window: UIWindow
    ) -> CGRect {
        let scrollView = page.zoomScrollView
        let contentView = tryUnwrap(scrollView.presentationContentView)
        let zoomContentView = tryUnwrap(scrollView.zoomContentView)
        let layer = contentView.layer.presentation() ?? contentView.layer
        return zoomContentView.convert(layer.frame, to: window)
    }

    private func makeMachine(
        scale: CGFloat = 1,
        viewportOffset: CGSize = .zero,
        interfaceVisibility: S2InterfaceVisibility = .visible,
        configuration: S2CalibrationConfiguration = .factoryPlaceholder,
        orderedAssetIDs: [String] = ["asset-1", "asset-2", "asset-3"],
        currentIndex: Int = 1,
        pendingDeletionAssetIDs: Set<String> = []
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
                pendingDeletionAssetIDs: pendingDeletionAssetIDs,
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
        let value = metrics(configuration: configuration)
        scrollView.configure(
            contentView: contentView,
            fittedSize: value.oneXDisplaySize,
            nativeZoomBaseSize: value.nativeZoomBaseSize,
            viewportSize: physicalSize,
            maximumZoomScale: CGFloat(configuration.pinchMaxScaleFloor)
        )
        scrollView.layoutIfNeeded()
        scrollView.applyNativeState(scale: 1, viewportOffset: .zero)
        return scrollView
    }

    private func makeNativePagerController(
        machine: S2StateMachine,
        configuration: S2CalibrationConfiguration = .factoryPlaceholder,
        photoContent: ((String, CGSize, CGFloat, Int) -> AnyView)? = nil,
        assetAspectRatio: CGFloat? = nil,
        isScreenshot: Bool = true,
        viewportSize: CGSize? = nil,
        zoomGeometry: ((String, CGSize) -> S2AssetZoomGeometry?)? = nil
    ) -> S2NativePagerViewController {
        let resolvedViewportSize = viewportSize ?? physicalSize
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(
            origin: .zero,
            size: resolvedViewportSize
        )
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            photoContent: photoContent,
            assetAspectRatio: assetAspectRatio,
            isScreenshot: isScreenshot,
            viewportSize: resolvedViewportSize,
            zoomGeometry: zoomGeometry
        )
        return controller
    }

    private func applyNativePagerController(
        _ controller: S2NativePagerViewController,
        machine: S2StateMachine,
        configuration: S2CalibrationConfiguration,
        photoContent: ((String, CGSize, CGFloat, Int) -> AnyView)? = nil,
        assetAspectRatio: CGFloat? = nil,
        isScreenshot: Bool = true,
        viewportSize: CGSize? = nil,
        zoomGeometry: ((String, CGSize) -> S2AssetZoomGeometry?)? = nil
    ) {
        let resolvedViewportSize = viewportSize ?? physicalSize
        let state = S2ViewportPresentationState(
            interfaceVisibility: machine.interfaceVisibility,
            bottomStripState: machine.bottomStripState,
            sheetState: machine.sheetState
        )
        let pages = machine.orderedAssetIDs.enumerated().map { index, assetID in
            let value = S2ViewportLayout.metrics(
                physicalSize: resolvedViewportSize,
                presentationState: state,
                assetAspectRatio: assetAspectRatio ?? screenAspectRatio,
                isScreenshot: isScreenshot,
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
                fittedCenterY: value.oneXDisplayCenterY,
                nativeZoomBaseSize: value.nativeZoomBaseSize,
                cornerRadius: value.oneXCornerRadius,
                doubleTapTargetScale: value.doubleTapTargetScale,
                assetPixelSize: CGSize(
                    width: (assetAspectRatio ?? screenAspectRatio) * 1_000,
                    height: 1_000
                ),
                contentVersion: S2NativePhotoContentVersion(
                    requestedScale: requestedScale,
                    requestStrategy: configuration.imageRequestStrategy,
                    requestRevision: requestRevision
                ),
                content: content,
                zoomGeometry: zoomGeometry?(assetID, value.nativeZoomBaseSize)
            )
        }
        controller.apply(
            machine: machine,
            configuration: configuration,
            viewportSize: resolvedViewportSize,
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

/// IC-099b P3：计数用的假取数实现。只记录被问过哪些资产，不做任何 IO。
/// IC-099 阶段二 C2/C3：计数用的假取数实现。记录被问过哪些资产，不做任何 IO。
private final class CountingAssetVolumeProvider: S2AssetVolumeProviding {
    private let byteCounts: [String: Int64?]
    /// `byteCount(assetID:)` 是非隔离 `async`，多个在途资产会在并发执行器上同时
    /// 进入该方法，记录数组必须过锁；读取一并过锁，避免读到半个写入。
    private let recordLock = NSLock()
    private var recordedAssetIDs: [String] = []

    var requestedAssetIDs: [String] {
        recordLock.lock()
        defer { recordLock.unlock() }
        return recordedAssetIDs
    }

    var requestCount: Int {
        requestedAssetIDs.count
    }

    init(byteCounts: [String: Int64?]) {
        self.byteCounts = byteCounts
    }

    func byteCount(assetID: String) async -> Int64? {
        recordLock.lock()
        recordedAssetIDs.append(assetID)
        recordLock.unlock()
        guard let value = byteCounts[assetID] else {
            return nil
        }
        return value
    }
}

private final class CountingAssetSizeProber: S2AssetSizeProbing {
    /// 同 `CountingAssetVolumeProvider`：`measure(assetID:)` 非隔离且可并发进入。
    private let recordLock = NSLock()
    private var recordedAssetIDs: [String] = []

    var requestedAssetIDs: [String] {
        recordLock.lock()
        defer { recordLock.unlock() }
        return recordedAssetIDs
    }

    var measureCount: Int {
        requestedAssetIDs.count
    }

    func measure(assetID: String) async -> S2AssetSizeProbeMeasurement {
        recordLock.lock()
        recordedAssetIDs.append(assetID)
        recordLock.unlock()
        return S2AssetSizeProbeMeasurement(
            assetID: assetID,
            mediaKind: .photo,
            isEdited: false,
            urlByteCount: 1_000_000,
            urlFailure: nil,
            urlElapsedMilliseconds: 1,
            dataByteCount: 1_000_000,
            dataFailure: nil,
            dataElapsedMilliseconds: 2
        )
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

    func delete() throws {
        defaults.removeObject(forKey: key)
    }
}

/// IC-087：可注入的假存储，记录保存 / 删除次数并可模拟删除失败。
private final class InMemoryCalibrationPersistence: S2CalibrationPersisting {
    var data: Data?
    var saveCount = 0
    var deleteCount = 0
    var deleteError: Error?

    init(data: Data?) {
        self.data = data
    }

    func load() throws -> Data? {
        data
    }

    func save(_ data: Data) throws {
        saveCount += 1
        self.data = data
    }

    func delete() throws {
        deleteCount += 1
        if let deleteError {
            throw deleteError
        }
        data = nil
    }
}

// MARK: - IC-085 横栏系统对齐

/// IC-085 R1：系统 Photos 录屏 IMG_6743.MP4（1206×2622，59.99 fps）逐帧测量参考表。
/// 像素→pt 按 3.0 换算。几何帧号为 30 fps 抽帧序号，减速段为 60 fps 抽帧序号。
/// 完整测量表见 Reports/IC-085/self-check.md。
enum S2BottomStripSystemReference {
    /// 60 px；30 fps 帧 218–236（极差 59–61）、325–341（59–60）。
    static let neighborItemWidth: CGFloat = 20
    /// 90 px；帧 218–236、325–341。
    static let neighborItemHeight: CGFloat = 30
    /// 90×90 px 方形；帧 218–236、325–341 极差 0，帧 97–136 由间隙反推同形。
    static let currentItemSize: CGFloat = 30
    /// 9 px；帧 218–236（8–9）、325–341（9–11）。
    static let itemSpacing: CGFloat = 3
    /// 39 px；帧 218–236、325–341 极差 0。
    static let currentItemGap: CGFloat = 13
    /// 61 px；帧 76 左缘、帧 166 右缘亮度剖面。
    static let leadingInset: CGFloat = 20.3
    /// 56 px 线性斜坡；同上两帧。
    static let edgeFadeWidth: CGFloat = 18.7
    /// 60 fps 帧 53–159、291–397、503–609 三段拟合 k = 0.99796～0.99805。
    static let decelerationRate: CGFloat = 0.998
    /// 30 fps 帧 199–217、305–323：18 帧 = 600 ms。
    static let expandDurationMilliseconds: CGFloat = 600
    /// 60 fps 帧 27–32：约 6 帧 = 100 ms。
    static let collapseDurationMilliseconds: CGFloat = 100
    /// IC-090 R1：8.08 px（≈ 2.69 pt）。30 fps 帧 97–136 / 218–236 / 325–341 静止段，
    /// 901 个邻居项目实例 × 4 角以「多样本逐像素最大值 → alpha 图 → 缺口面积
    /// A = r²(1 − π/4)」求得（四角 7.96～8.17 px）；当前张两个内容饱和角 8.15 / 8.24 px，
    /// 与邻居同值。技术负责人独立复核 759 个邻居实例得四角 8.22～8.37 px。
    /// IC-090 R3（v2，④ Lynn 2026-08-23）：两家测量均落在 8.1～8.4 px，取最接近的
    /// @3x 整像素值 8 px = 8/3 pt（阶段一「四舍五入到 0.5 pt」的 2.5 pt = 7.5 px 系统性偏小）。
    static let cornerRadius: CGFloat = 8.0 / 3.0

    /// run1（60 fps 帧 53–159）初速 42.3 px/帧 = 845.3 pt/s。
    static let decelerationInitialVelocity: CGFloat = 845.3
    /// run1 松手后累计位移（pt）检查点，5 帧中值滤波后求和。
    static let decelerationDisplacementCheckpoints: [(elapsed: TimeInterval, displacement: CGFloat)] = [
        (elapsed: 0.25, displacement: 162.0),
        (elapsed: 0.50, displacement: 274.3),
        (elapsed: 0.75, displacement: 340.7),
        (elapsed: 1.00, displacement: 379.3),
        (elapsed: 1.25, displacement: 402.3),
        (elapsed: 1.50, displacement: 415.0),
        (elapsed: 1.75, displacement: 421.3)
    ]
    /// 吸附 + 展开进度（30 fps 帧 199–217 左邻总位移 73 px 的累计占比）。
    static let settleProgressSamples: [(elapsed: TimeInterval, progress: CGFloat)] = [
        (elapsed: 0.1, progress: 0.55),
        (elapsed: 0.2, progress: 0.78),
        (elapsed: 0.3, progress: 0.86)
    ]
}

/// 夹具帧驱动：不自行触发，测试按注入时钟显式调用 `tick()`。
final class S2BottomStripManualFrameDriver: S2BottomStripFrameDriving {
    private(set) var isRunning = false
    private(set) var startCount = 0

    func start(_ onFrame: @escaping () -> Void) {
        isRunning = true
        startCount += 1
    }

    func stop() {
        isRunning = false
    }
}

extension S2CalibrationHarnessTests {
    private static let referenceMetrics = S2BottomStripMetrics(
        currentItemSize: S2BottomStripSystemReference.currentItemSize,
        neighborItemWidth: S2BottomStripSystemReference.neighborItemWidth,
        neighborItemHeight: S2BottomStripSystemReference.neighborItemHeight,
        itemSpacing: S2BottomStripSystemReference.itemSpacing,
        currentItemGap: S2BottomStripSystemReference.currentItemGap,
        edgeFadeWidth: S2BottomStripSystemReference.edgeFadeWidth,
        leadingInset: S2BottomStripSystemReference.leadingInset,
        switchDistance: S2BottomStripSystemReference.neighborItemWidth +
            S2BottomStripSystemReference.itemSpacing,
        decelerationRate: S2BottomStripSystemReference.decelerationRate,
        expandDurationMilliseconds: S2BottomStripSystemReference.expandDurationMilliseconds,
        collapseDurationMilliseconds: S2BottomStripSystemReference.collapseDurationMilliseconds,
        flickVelocityThreshold: 300,
        cornerRadius: S2BottomStripSystemReference.cornerRadius
    )

    private static let stripViewportSize = CGSize(width: 402, height: 30)

    private func makeStripMotion(
        assetCount: Int = 5,
        currentIndex: Int = 2,
        onPhotoSwitch: @escaping () -> Void = {}
    ) -> (
        machine: S2StateMachine,
        motion: S2BottomStripMotionController,
        driver: S2BottomStripManualFrameDriver,
        clock: S2StripTestClock
    ) {
        let machine = makeMachine(
            orderedAssetIDs: (1...assetCount).map { "asset-\($0)" },
            currentIndex: currentIndex
        )
        let driver = S2BottomStripManualFrameDriver()
        let clock = S2StripTestClock()
        let motion = S2BottomStripMotionController(
            layout: S2BottomStripLayout(
                metrics: tryUnwrap(
                    S2CalibrationConfiguration.factoryPlaceholder.resolvedParameters
                ).bottomStripMetrics
            ),
            hooks: S2BottomStripMotionController.hooks(
                machine: machine,
                onPhotoSwitch: onPhotoSwitch
            ),
            clock: { clock.now },
            frameDriver: driver
        )
        motion.synchronize(count: assetCount, currentIndex: currentIndex)
        return (machine, motion, driver, clock)
    }

    // IC-085 G161/G162：出厂值逐项等于系统录屏参考表（几何容差 0.5 pt，k 容差 0.0005）；
    // 节距 = 邻居宽 + 间距；废止参数在字段、导出、登记表中均为 0；新参数集全部导出。
    func testIC085G162FactoryBottomStripValuesMatchSystemReference() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        XCTAssertEqual(configuration.bottomStripNeighborItemWidth, Double(S2BottomStripSystemReference.neighborItemWidth), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripNeighborItemHeight, Double(S2BottomStripSystemReference.neighborItemHeight), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripCurrentItemSize, Double(S2BottomStripSystemReference.currentItemSize), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripItemSpacing, Double(S2BottomStripSystemReference.itemSpacing), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripCurrentItemGap, Double(S2BottomStripSystemReference.currentItemGap), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripLeadingInset, Double(S2BottomStripSystemReference.leadingInset), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripEdgeFadeWidth, Double(S2BottomStripSystemReference.edgeFadeWidth), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripDecelerationRate, Double(S2BottomStripSystemReference.decelerationRate), accuracy: 0.0005)
        XCTAssertEqual(configuration.bottomStripExpandDurationMilliseconds, Double(S2BottomStripSystemReference.expandDurationMilliseconds), accuracy: 0.5)
        XCTAssertEqual(configuration.bottomStripCollapseDurationMilliseconds, Double(S2BottomStripSystemReference.collapseDurationMilliseconds), accuracy: 0.5)
        XCTAssertEqual(
            configuration.bottomStripSwitchDistance,
            configuration.bottomStripNeighborItemWidth + configuration.bottomStripItemSpacing,
            accuracy: 0.5
        )
        XCTAssertEqual(
            tryUnwrap(configuration.resolvedParameters).bottomStripMetrics,
            Self.referenceMetrics
        )

        let fieldNames = Set(Mirror(reflecting: configuration).children.compactMap(\.label))
        let exported = configuration.exportText()
        let registry = Set(S2CalibrationConfiguration.parameterConnections.map(\.name))
        XCTAssertFalse(fieldNames.contains("bottomStripDragMinimumDistance"))
        XCTAssertFalse(exported.contains("bottomStripDragMinimumDistance"))
        XCTAssertFalse(registry.contains("bottomStripDragMinimumDistance"))
        for name in [
            "bottomStripCurrentItemSize", "bottomStripNeighborItemWidth",
            "bottomStripNeighborItemHeight", "bottomStripItemSpacing",
            "bottomStripCurrentItemGap", "bottomStripEdgeFadeWidth",
            "bottomStripLeadingInset", "bottomStripSwitchDistance",
            "bottomStripDecelerationRate",
            "bottomStripExpandDurationMilliseconds",
            "bottomStripCollapseDurationMilliseconds"
        ] {
            XCTAssertTrue(fieldNames.contains(name), name)
            XCTAssertTrue(exported.contains("\(name)="), name)
            XCTAssertTrue(registry.contains(name), name)
        }
        XCTAssertTrue(exported.contains("bottomStripDecelerationRate=0.998000"))
        XCTAssertTrue(exported.contains("bottomStripLeadingInset=20.300000"))
        XCTAssertTrue(exported.contains("bottomStripEdgeFadeWidth=18.700000"))
        // IC-090 R1：横栏 decided + effective 由 12 增至 13（新增 bottomStripCornerRadius）。
        XCTAssertEqual(
            S2CalibrationConfiguration.parameterConnections
                .filter { $0.name.hasPrefix("bottomStrip") }
                .filter { $0.specStatus == .decided && $0.wiringStatus == .effective }
                .count,
            13
        )
    }

    // IC-085 R3-1：项目帧固定（邻居 20×30、当前张 30×30），与资产宽高比无关；
    // 内容框按 aspectFill 放大到覆盖项目帧（横图裁左右、竖图裁上下）。
    func testIC085R3ItemFramesFixedAndContentFillsCell() {
        let layout = S2BottomStripLayout(metrics: Self.referenceMetrics)
        let neighbor = CGSize(width: 20, height: 30)
        let current = CGSize(width: 30, height: 30)

        // 帧：`frame(at:)` 不接收宽高比，任何索引只有邻居/当前张两种尺寸。
        for index in 0..<5 {
            let frame = layout.frame(
                at: index,
                currentIndex: 2,
                expansion: 1,
                contentX: layout.contentCenterX(of: 2),
                viewportSize: Self.stripViewportSize
            )
            XCTAssertEqual(frame.size, index == 2 ? current : neighbor, "index=\(index)")
        }

        // 内容框：横图按高填满、竖图按宽填满，且永不小于帧。
        let landscapeInNeighbor = S2BottomStripLayout.fillContentSize(cellSize: neighbor, assetAspectRatio: 4.0 / 3.0)
        XCTAssertEqual(landscapeInNeighbor.width, 40, accuracy: 0.001)
        XCTAssertEqual(landscapeInNeighbor.height, 30, accuracy: 0.001)
        // 3:4 比 20×30（2:3）略宽，按高填满后宽 22.5，左右各裁 1.25。
        let portraitInNeighbor = S2BottomStripLayout.fillContentSize(cellSize: neighbor, assetAspectRatio: 3.0 / 4.0)
        XCTAssertEqual(portraitInNeighbor.width, 22.5, accuracy: 0.001)
        XCTAssertEqual(portraitInNeighbor.height, 30, accuracy: 0.001)
        let tallInNeighbor = S2BottomStripLayout.fillContentSize(cellSize: neighbor, assetAspectRatio: 9.0 / 16.0)
        XCTAssertEqual(tallInNeighbor.width, 20, accuracy: 0.001)
        XCTAssertEqual(tallInNeighbor.height, 20 * 16 / 9, accuracy: 0.001)
        let landscapeInCurrent = S2BottomStripLayout.fillContentSize(cellSize: current, assetAspectRatio: 4.0 / 3.0)
        XCTAssertEqual(landscapeInCurrent.width, 40, accuracy: 0.001)
        XCTAssertEqual(landscapeInCurrent.height, 30, accuracy: 0.001)
        let portraitInCurrent = S2BottomStripLayout.fillContentSize(cellSize: current, assetAspectRatio: 3.0 / 4.0)
        XCTAssertEqual(portraitInCurrent.width, 30, accuracy: 0.001)
        XCTAssertEqual(portraitInCurrent.height, 40, accuracy: 0.001)
        for ratio: CGFloat in [0.25, 0.5, 0.75, 1, 4.0 / 3.0, 16.0 / 9.0, 3] {
            for cell in [neighbor, current] {
                let size = S2BottomStripLayout.fillContentSize(cellSize: cell, assetAspectRatio: ratio)
                XCTAssertGreaterThanOrEqual(size.width + 0.001, cell.width, "ratio=\(ratio)")
                XCTAssertGreaterThanOrEqual(size.height + 0.001, cell.height, "ratio=\(ratio)")
                XCTAssertEqual(size.width / size.height, ratio, accuracy: 0.001, "ratio=\(ratio)")
            }
        }
        // 非法比例退化为帧本身。
        XCTAssertEqual(S2BottomStripLayout.fillContentSize(cellSize: neighbor, assetAspectRatio: 0), neighbor)
        XCTAssertEqual(S2BottomStripLayout.fillContentSize(cellSize: neighbor, assetAspectRatio: .nan), neighbor)
    }

    // IC-085 R3-2：松手速度 |v| < bottomStripFlickVelocityThreshold（placeholder，出厂 300 pt/s）
    // 无减速段，直接吸附展开；达到阈值才进入减速。新参数登记为 placeholder / effective。
    func testIC085R3SlowReleaseSkipsInertiaBelowFlickThreshold() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        XCTAssertEqual(configuration.bottomStripFlickVelocityThreshold, 300, accuracy: 0.5)
        let connection = tryUnwrap(
            S2CalibrationConfiguration.parameterConnections
                .first { $0.name == "bottomStripFlickVelocityThreshold" }
        )
        XCTAssertEqual(connection.specStatus, .placeholder)
        XCTAssertEqual(connection.wiringStatus, .effective)
        XCTAssertTrue(configuration.exportText().contains("bottomStripFlickVelocityThreshold=300.000000"))
        XCTAssertEqual(
            tryUnwrap(configuration.resolvedParameters).bottomStripMetrics.flickVelocityThreshold,
            300
        )

        // 慢拖：拖 8 pt 后以 299 pt/s 松手 → 立即进入吸附（无 decelerating），状态机已 idle。
        let slow = makeStripMotion(assetCount: 9, currentIndex: 4)
        let startX = slow.motion.contentX
        XCTAssertTrue(slow.motion.beginDrag())
        slow.motion.updateDrag(translation: 0)
        slow.motion.updateDrag(translation: -8)
        slow.clock.advance(by: 0.2)
        slow.motion.tick()
        slow.motion.endDrag(velocity: -299)
        XCTAssertEqual(slow.motion.phase, .settling)
        XCTAssertEqual(slow.machine.bottomStripState, .idle)
        XCTAssertEqual(slow.machine.currentIndex, 4)
        slow.clock.advance(by: 0.6)
        slow.motion.tick()
        XCTAssertEqual(slow.motion.phase, .idle)
        XCTAssertEqual(slow.motion.contentX, startX, accuracy: 0.001)
        XCTAssertEqual(slow.motion.expansion, 1, accuracy: 0.001)
        XCTAssertFalse(slow.driver.isRunning)

        // 同样位移、300 pt/s 松手 → 进入减速，状态机保持 dragging。
        let flick = makeStripMotion(assetCount: 9, currentIndex: 4)
        XCTAssertTrue(flick.motion.beginDrag())
        flick.motion.updateDrag(translation: 0)
        flick.motion.updateDrag(translation: -8)
        flick.clock.advance(by: 0.2)
        flick.motion.tick()
        flick.motion.endDrag(velocity: -300)
        XCTAssertEqual(flick.motion.phase, .decelerating)
        XCTAssertEqual(flick.machine.bottomStripState, .dragging)

        // 阈值为 0 时任何速度都减速（面板可调到 0）。
        let zero = makeStripMotion(assetCount: 9, currentIndex: 4)
        let base = zero.motion.layout.metrics
        let metrics = S2BottomStripMetrics(
            currentItemSize: base.currentItemSize,
            neighborItemWidth: base.neighborItemWidth,
            neighborItemHeight: base.neighborItemHeight,
            itemSpacing: base.itemSpacing,
            currentItemGap: base.currentItemGap,
            edgeFadeWidth: base.edgeFadeWidth,
            leadingInset: base.leadingInset,
            switchDistance: base.switchDistance,
            decelerationRate: base.decelerationRate,
            expandDurationMilliseconds: base.expandDurationMilliseconds,
            collapseDurationMilliseconds: base.collapseDurationMilliseconds,
            flickVelocityThreshold: 0,
            cornerRadius: base.cornerRadius
        )
        zero.motion.layout = S2BottomStripLayout(metrics: metrics)
        XCTAssertTrue(zero.motion.beginDrag())
        zero.motion.updateDrag(translation: 0)
        zero.motion.updateDrag(translation: -8)
        zero.motion.endDrag(velocity: -60)
        XCTAssertEqual(zero.motion.phase, .decelerating)
    }

    // IC-085 R3-3：主图翻页（非横栏拖动）引起的定位项变化：横栏以 expandDuration 的
    // ease-out 滚到新当前张并展开，不跳变；横栏拖动引起的切换不触发该动画。
    func testIC085R3ExternalIndexChangeScrollsAndExpandsWithoutJump() {
        let fixture = makeStripMotion(assetCount: 9, currentIndex: 2)
        let layout = fixture.motion.layout
        let fromX = fixture.motion.contentX
        let toX = layout.contentCenterX(of: 5)
        XCTAssertEqual(fixture.motion.phase, .idle)

        // 外部翻到第 6 张（索引 5）：立即进入 settling，位置不跳变，展开度从 0 起。
        fixture.motion.synchronize(count: 9, currentIndex: 5, animated: true)
        XCTAssertEqual(fixture.motion.phase, .settling)
        XCTAssertEqual(fixture.motion.contentX, fromX, accuracy: 0.001)
        XCTAssertEqual(fixture.motion.expansion, 0, accuracy: 0.001)
        XCTAssertTrue(fixture.driver.isRunning)
        XCTAssertEqual(fixture.machine.bottomStripState, .idle)

        // 进度与 R2 吸附曲线一致；逐帧单调、无跳变（单帧位移 < 总位移的 1/3）。
        var previousX = fromX
        var frame = 0
        while fixture.motion.phase == .settling, frame < 120 {
            fixture.clock.advance(by: 1.0 / 60.0)
            fixture.motion.tick()
            frame += 1
            let x = fixture.motion.contentX
            XCTAssertGreaterThanOrEqual(x + 0.001, previousX, "frame=\(frame)")
            XCTAssertLessThanOrEqual(x, toX + 0.001, "frame=\(frame)")
            XCTAssertLessThan(abs(x - previousX), abs(toX - fromX) / 3, "frame=\(frame)")
            previousX = x
            let elapsed = TimeInterval(frame) / 60
            for sample in S2BottomStripSystemReference.settleProgressSamples
            where abs(elapsed - sample.elapsed) < 1.0 / 120 {
                let progress = (x - fromX) / (toX - fromX)
                XCTAssertEqual(progress, sample.progress, accuracy: 0.1, "t=\(sample.elapsed)")
                XCTAssertEqual(fixture.motion.expansion, progress, accuracy: 0.001, "t=\(sample.elapsed)")
            }
        }
        XCTAssertTrue((36...37).contains(frame), "600 ms ≈ 36 帧后结束，实际 \(frame)")
        XCTAssertEqual(fixture.motion.phase, .idle)
        XCTAssertEqual(fixture.motion.contentX, toX, accuracy: 0.001)
        XCTAssertEqual(fixture.motion.expansion, 1, accuracy: 0.001)
        XCTAssertEqual(fixture.motion.trackedIndex, 5)
        XCTAssertFalse(fixture.driver.isRunning)

        // 同一索引重复同步：不重启动画。
        let startCount = fixture.driver.startCount
        fixture.motion.synchronize(count: 9, currentIndex: 5, animated: true)
        XCTAssertEqual(fixture.motion.phase, .idle)
        XCTAssertEqual(fixture.driver.startCount, startCount)

        // 动画进行中再次翻页：改向新目标，不跳变。
        fixture.motion.synchronize(count: 9, currentIndex: 7, animated: true)
        fixture.clock.advance(by: 0.1)
        fixture.motion.tick()
        let midX = fixture.motion.contentX
        fixture.motion.synchronize(count: 9, currentIndex: 3, animated: true)
        XCTAssertEqual(fixture.motion.phase, .settling)
        XCTAssertEqual(fixture.motion.contentX, midX, accuracy: 0.001)
        fixture.clock.advance(by: 0.6)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.contentX, layout.contentCenterX(of: 3), accuracy: 0.001)
        XCTAssertEqual(fixture.motion.phase, .idle)

        // 横栏拖动引起的切换：拖动中 onChange 同样会调 synchronize(animated:)，必须是空操作。
        let drag = makeStripMotion(assetCount: 9, currentIndex: 3)
        XCTAssertTrue(drag.motion.beginDrag())
        drag.motion.updateDrag(translation: 0)
        drag.motion.updateDrag(translation: -layout.pitch)
        XCTAssertEqual(drag.machine.currentIndex, 4)
        let dragX = drag.motion.contentX
        drag.motion.synchronize(count: 9, currentIndex: 4, animated: true)
        XCTAssertEqual(drag.motion.phase, .dragging)
        XCTAssertEqual(drag.motion.contentX, dragX, accuracy: 0.001)
        drag.motion.endDrag(velocity: -900)
        XCTAssertEqual(drag.motion.phase, .decelerating)
        drag.motion.synchronize(count: 9, currentIndex: drag.machine.currentIndex, animated: true)
        XCTAssertEqual(drag.motion.phase, .decelerating)

        // 非动画同步（首帧/张数变化）仍直接居中。
        let snap = makeStripMotion(assetCount: 9, currentIndex: 2)
        snap.motion.synchronize(count: 9, currentIndex: 6)
        XCTAssertEqual(snap.motion.phase, .idle)
        XCTAssertEqual(snap.motion.contentX, layout.contentCenterX(of: 6), accuracy: 0.001)
        XCTAssertEqual(snap.motion.expansion, 1, accuracy: 0.001)
    }

    // IC-085 R3-4 像素门禁：横栏渲染为位图（不透明测试内容，按资产比例 fit 的黑块），
    // 断言每个项目帧内无背景像素；当前张 30×30 正方形且四角非背景；邻居 20×30；
    // 帧间距 3、当前张两侧 13。
    @MainActor
    func testIC085R3RenderedStripHasNoBackgroundInsideItemFrames() throws {
        let assetIDs = (1...5).map { "asset-\($0)" }
        let machine = makeMachine(orderedAssetIDs: assetIDs, currentIndex: 1)
        let metrics = tryUnwrap(
            S2CalibrationConfiguration.factoryPlaceholder.resolvedParameters
        ).bottomStripMetrics
        let viewport = Self.stripViewportSize
        // 偶数索引横图 4:3、奇数索引竖图 3:4；内容按自身比例 fit（模拟 App 层 .fit 闭包）。
        let ratio: (String) -> CGFloat = { assetID in
            let index = assetIDs.firstIndex(of: assetID) ?? 0
            return index.isMultiple(of: 2) ? 4.0 / 3.0 : 3.0 / 4.0
        }
        let strip = S2BottomStripView(
            machine: machine,
            metrics: metrics,
            markSize: 0,
            itemContent: { item in
                AnyView(
                    Color.black.aspectRatio(ratio(item.assetID), contentMode: .fit)
                )
            },
            assetAspectRatio: ratio,
            onPhotoSwitch: {}
        )
        let renderer = ImageRenderer(
            content: ZStack {
                Color.white
                strip
            }
            .frame(width: viewport.width, height: viewport.height)
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(viewport)
        let cgImage = try XCTUnwrap(renderer.cgImage)
        let bitmap = try S2StripBitmap(cgImage: cgImage)
        XCTAssertEqual(bitmap.width, Int(viewport.width))
        XCTAssertEqual(bitmap.height, Int(viewport.height))

        let layout = S2BottomStripLayout(metrics: metrics)
        let contentX = layout.contentCenterX(of: 1)
        let frames = (0..<5).map { index in
            layout.frame(
                at: index,
                currentIndex: 1,
                expansion: 1,
                contentX: contentX,
                viewportSize: viewport
            )
        }
        // 预期帧（整数像素）：当前张 186–216×0–30；左邻 153–173；右邻 229–249；再右 252–272。
        XCTAssertEqual(frames[1], CGRect(x: 186, y: 0, width: 30, height: 30))
        XCTAssertEqual(frames[0], CGRect(x: 153, y: 0, width: 20, height: 30))
        XCTAssertEqual(frames[2], CGRect(x: 229, y: 0, width: 20, height: 30))
        XCTAssertEqual(frames[3], CGRect(x: 252, y: 0, width: 20, height: 30))
        XCTAssertEqual(frames[4], CGRect(x: 275, y: 0, width: 20, height: 30))

        // 每个项目帧内无背景像素——IC-090 R1 起四角按 bottomStripCornerRadius 裁圆，
        // 因此四角各 ceil(r) × ceil(r) 的方块排除在外；圆角本身由 G181 在 scale=3
        // 位图上按 45° 对角线与首行／末行扫描逐像素判定。
        let cornerMargin = Int(
            CGFloat(
                S2CalibrationConfiguration.factoryPlaceholder
                    .bottomStripCornerRadius
            ).rounded(.up)
        )
        func isInCornerBlock(x: Int, y: Int, frame: CGRect) -> Bool {
            let dx = min(x - Int(frame.minX), Int(frame.maxX) - 1 - x)
            let dy = min(y - Int(frame.minY), Int(frame.maxY) - 1 - y)
            return dx < cornerMargin && dy < cornerMargin
        }
        for (index, frame) in frames.enumerated() {
            var background = 0
            for y in Int(frame.minY)..<Int(frame.maxY) {
                for x in Int(frame.minX)..<Int(frame.maxX)
                where !isInCornerBlock(x: x, y: y, frame: frame) &&
                    bitmap.isBackground(x: x, y: y) {
                    background += 1
                }
            }
            XCTAssertEqual(background, 0, "index=\(index) frame=\(frame)")
        }
        // 当前张为正方形；IC-090 R1 起四角最外一像素被圆角切掉（背景），
        // 沿对角线内移 cornerMargin 后为内容。
        let current = frames[1]
        XCTAssertEqual(current.width, current.height)
        for (x, y) in [
            (Int(current.minX), Int(current.minY)),
            (Int(current.maxX) - 1, Int(current.minY)),
            (Int(current.minX), Int(current.maxY) - 1),
            (Int(current.maxX) - 1, Int(current.maxY) - 1)
        ] {
            XCTAssertTrue(bitmap.isBackground(x: x, y: y), "corner=(\(x),\(y))")
        }
        for (x, y) in [
            (Int(current.minX) + cornerMargin, Int(current.minY) + cornerMargin),
            (Int(current.maxX) - 1 - cornerMargin, Int(current.minY) + cornerMargin),
            (Int(current.minX) + cornerMargin, Int(current.maxY) - 1 - cornerMargin),
            (Int(current.maxX) - 1 - cornerMargin, Int(current.maxY) - 1 - cornerMargin)
        ] {
            XCTAssertFalse(bitmap.isBackground(x: x, y: y), "inset corner=(\(x),\(y))")
        }
        // 间隙像素为背景：当前张两侧各 13、邻居间 3，按中线逐像素计数。
        let row = Int(viewport.height / 2)
        func backgroundRun(from x: Int, direction: Int) -> Int {
            var count = 0
            var cursor = x
            while cursor >= 0, cursor < bitmap.width, bitmap.isBackground(x: cursor, y: row) {
                count += 1
                cursor += direction
            }
            return count
        }
        XCTAssertEqual(backgroundRun(from: Int(current.minX) - 1, direction: -1), 13)
        XCTAssertEqual(backgroundRun(from: Int(current.maxX), direction: 1), 13)
        XCTAssertEqual(backgroundRun(from: Int(frames[2].maxX), direction: 1), 3)
        XCTAssertEqual(backgroundRun(from: Int(frames[3].maxX), direction: 1), 3)
        // 邻居帧上下边之外立即是背景（高度正好 30 = 视口高，无上下越界内容可验；
        // 改验邻居帧宽度：左右边之外为背景）。
        XCTAssertTrue(bitmap.isBackground(x: Int(frames[0].minX) - 1, y: row))
        XCTAssertTrue(bitmap.isBackground(x: Int(frames[0].maxX), y: row))
        XCTAssertFalse(bitmap.isBackground(x: Int(frames[0].minX), y: row))
        XCTAssertFalse(bitmap.isBackground(x: Int(frames[0].maxX) - 1, y: row))
    }


    /// IC-090 R1 圆角像素门禁夹具：以 scale = 3 渲染横栏（1 pt = 3 px，与真机 @3x 一致），
    /// 项目内容为纯色块，故同尺寸的两个项目除标记外逐像素相同。
    private static let stripAssetIDs = (1...5).map { "asset-\($0)" }
    private static let stripRenderScale = 3

    private struct StripRender {
        let bitmap: S2StripBitmap
        let frames: [CGRect]
    }

    @MainActor
    private func renderStrip(
        markedAssetIDs: Set<String>,
        markSize: CGFloat,
        // IC-090：要观察标记就不能用纯黑内容；圆角几何门禁仍用纯黑
        // （0 / 1 覆盖的像素不受内容明度影响）。
        // IC-093 R2 起标记为固定双色（白符号 + 半透黑圆底），与环境前景色无关。
        contentWhite: Double = 0,
        // IC-093 D1：两个明暗模式下渲染同一份内容，用于逐像素比对。
        colorScheme: ColorScheme = .light
    ) throws -> StripRender {
        let assetIDs = Self.stripAssetIDs
        let machine = makeMachine(
            orderedAssetIDs: assetIDs,
            currentIndex: 1,
            pendingDeletionAssetIDs: markedAssetIDs
        )
        let metrics = tryUnwrap(
            S2CalibrationConfiguration.factoryPlaceholder.resolvedParameters
        ).bottomStripMetrics
        let viewport = Self.stripViewportSize
        let strip = S2BottomStripView(
            machine: machine,
            metrics: metrics,
            markSize: markSize,
            itemContent: { _ in AnyView(Color(white: contentWhite)) },
            assetAspectRatio: { _ in 1 },
            onPhotoSwitch: {}
        )
        let renderer = ImageRenderer(
            content: ZStack {
                Color.white
                strip
            }
            .frame(width: viewport.width, height: viewport.height)
            .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = CGFloat(Self.stripRenderScale)
        renderer.proposedSize = ProposedViewSize(viewport)
        let cgImage = try XCTUnwrap(renderer.cgImage)
        let layout = S2BottomStripLayout(metrics: metrics)
        let contentX = layout.contentCenterX(of: 1)
        let frames = assetIDs.indices.map { index in
            layout.frame(
                at: index,
                currentIndex: 1,
                expansion: 1,
                contentX: contentX,
                viewportSize: viewport
            )
        }
        let bitmap = try S2StripBitmap(cgImage: cgImage)
        return StripRender(bitmap: bitmap, frames: frames)
    }

    // IC-090 G180 / G190（v2）：圆角半径出厂值 = 系统录屏测量值对齐到 @3x 像素栅格
    // （参考表 `S2BottomStripSystemReference.cornerRadius` = 8/3 pt = 8 px），
    // `schemaVersion == 4`（v2 保持不变，schema 4 从未随可安装包发出）；
    // 参数进导出文本与登记表（decided / effective）；
    // 邻居与当前张同半径，故只有一个参数、不存在 `bottomStripCurrentCornerRadius`。
    func testIC090G180FactoryCornerRadiusMatchesSystemReference() throws {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        XCTAssertEqual(
            configuration.bottomStripCornerRadius,
            8.0 / 3.0,
            accuracy: 0.000_000_001
        )
        XCTAssertEqual(
            configuration.bottomStripCornerRadius,
            Double(S2BottomStripSystemReference.cornerRadius),
            accuracy: 0.000_000_001
        )
        XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 6)

        let metrics = tryUnwrap(configuration.resolvedParameters).bottomStripMetrics
        XCTAssertEqual(
            metrics.cornerRadius,
            S2BottomStripSystemReference.cornerRadius,
            accuracy: 0.000_000_001
        )
        // @3x 下正好是 8 个设备像素。
        XCTAssertEqual(metrics.cornerRadius * 3, 8, accuracy: 0.000_000_001)

        let lines = configuration.exportText()
            .split(separator: "\n")
            .map(String.init)
        XCTAssertTrue(lines.contains("bottomStripCornerRadius=2.666667"))
        let hasCurrentCornerRadius = lines.contains(where: {
            $0.hasPrefix("bottomStripCurrentCornerRadius=")
        })
        XCTAssertFalse(hasCurrentCornerRadius)

        let connections = Dictionary(
            uniqueKeysWithValues: S2CalibrationConfiguration.parameterConnections
                .map { ($0.name, $0) }
        )
        XCTAssertEqual(
            connections["bottomStripCornerRadius"]?.specStatus,
            .decided
        )
        XCTAssertEqual(
            connections["bottomStripCornerRadius"]?.wiringStatus,
            .effective
        )
        XCTAssertNil(connections["bottomStripCurrentCornerRadius"])

        // 负值不合法；旧持久化缺该键按出厂值补齐，含该键时往返一致。
        var invalid = configuration
        invalid.bottomStripCornerRadius = -1
        XCTAssertFalse(invalid.isValid)

        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(
            S2CalibrationConfiguration.self,
            from: encoded
        )
        XCTAssertEqual(decoded, configuration)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertEqual(json["schemaVersion"] as? Int, 6)
        json.removeValue(forKey: "bottomStripCornerRadius")
        let legacy = try JSONSerialization.data(withJSONObject: json)
        let migrated = try JSONDecoder().decode(
            S2CalibrationConfiguration.self,
            from: legacy
        )
        XCTAssertEqual(migrated, configuration)
    }

    // IC-090 G181 / G191（v2）像素门禁（scale = 3，1 pt = 3 px，出厂 8/3 pt = 8 px）：
    // 每个项目帧四角沿 45° 对角线由角点向内扫描（同 IC-070 G77 方法），半径内为背景、
    // 半径外为内容；首行／末行与首列／末列的直线扫描给出另一个方向的夹逼。
    // 各阈值按 r = 8 px 逐像素覆盖率重算（圆心 (r,r)、半径 r 的解析覆盖率）：
    //   对角偏移 0/1 覆盖率 0.000、2 为 0.760、3…7 为 1.000；
    //   直线偏移 0…3 覆盖率 0.000、4 为 0.191、5 为 0.593、8…9 为 1.000。
    // 故：对角偏移 0/1 断言背景（⇒ r > 6.83 px），偏移 3…7 断言内容（⇒ r ≤ 10.24 px）；
    // 直线偏移 0…3 断言背景（⇒ r ≥ 7.83 px，较 v1 的 0…2 收紧），偏移 8 断言内容
    // （⇒ r ≤ 8.00 px）。合计夹逼 7.83 px ≤ r ≤ 8.00 px。
    // 注：scale = 3 的二值判据无法把 7.5 px 与 8.0 px 分开（差异全在部分覆盖像素上），
    // 出厂值本身由 G190 以 accuracy 1e-9 钉死。
    @MainActor
    func testIC090G181RenderedStripCornersAreClippedByCornerRadius() throws {
        let render = try renderStrip(markedAssetIDs: [], markSize: 0)
        let bitmap = render.bitmap
        let scale = Self.stripRenderScale
        XCTAssertEqual(bitmap.width, Int(Self.stripViewportSize.width) * scale)
        XCTAssertEqual(bitmap.height, Int(Self.stripViewportSize.height) * scale)

        for (index, frame) in render.frames.enumerated() {
            let minX = Int(frame.minX) * scale
            let maxX = Int(frame.maxX) * scale - 1
            let minY = Int(frame.minY) * scale
            let maxY = Int(frame.maxY) * scale - 1
            let corners: [(String, Int, Int, Int, Int)] = [
                ("TL", minX, minY, 1, 1),
                ("TR", maxX, minY, -1, 1),
                ("BL", minX, maxY, 1, -1),
                ("BR", maxX, maxY, -1, -1)
            ]
            for (name, cx, cy, sx, sy) in corners {
                let label = "index=\(index) corner=\(name)"
                // 半径内（对角偏移 0、1）为背景。
                for offset in 0...1 {
                    XCTAssertTrue(
                        bitmap.isBackground(
                            x: cx + sx * offset,
                            y: cy + sy * offset
                        ),
                        "\(label) diag=\(offset) 应为背景"
                    )
                }
                // 半径外（对角偏移 3…7）为内容。
                for offset in 3...7 {
                    XCTAssertFalse(
                        bitmap.isBackground(
                            x: cx + sx * offset,
                            y: cy + sy * offset
                        ),
                        "\(label) diag=\(offset) 应为内容"
                    )
                }
                // 沿该角所在的水平边扫描：偏移 0…3 背景、偏移 8 内容。
                for offset in 0...3 {
                    XCTAssertTrue(
                        bitmap.isBackground(x: cx + sx * offset, y: cy),
                        "\(label) edge=\(offset) 应为背景"
                    )
                }
                XCTAssertFalse(
                    bitmap.isBackground(x: cx + sx * 8, y: cy),
                    "\(label) edge=8 应为内容"
                )
                // 沿该角所在的竖直边同样。
                for offset in 0...3 {
                    XCTAssertTrue(
                        bitmap.isBackground(x: cx, y: cy + sy * offset),
                        "\(label) vedge=\(offset) 应为背景"
                    )
                }
                XCTAssertFalse(
                    bitmap.isBackground(x: cx, y: cy + sy * 8),
                    "\(label) vedge=8 应为内容"
                )
            }
        }
    }

    // IC-090 G181 / G191（v2 R4）：待删标记叠层与项目内容受同一圆角裁切，且标记确实渲染。
    // 取证只在已标记项目的右上 `markSize × markSize` 框内进行（v1 用整帧逐像素比较，
    // 其「两项目除标记外逐像素相同」的前提在渲染位图里不成立，见 v2 报告第五节）：
    //   (a) 该角沿 45° 对角线偏移 0/1 的像素为背景 —— 标记所在角同样被圆角裁掉；
    //   (b) 框内存在明显暗于项目内容色的像素 —— 标记确实渲染了；
    //   (c) 框外不做逐像素比较。
    // 内容色取非黑（`Color(white: 0.1)`），否则系统前景色渲染的标记与纯黑内容逐像素相同。
    // (b) 取「暗于内容」而不是「不等于内容」：圆角裁切与抗锯齿只会把像素**混向背景白**
    // （更亮），只有标记字形能比平坦内容更暗，故该判据不会被圆角自身或 ±1 级噪声满足。
    // 「标记不被圆角裁掉」的最终判定是 H36，留给 Lynn 真机并排观感确认。
    @MainActor
    func testIC090G181StripMarkOverlayIsClippedByTheSameCornerRadius() throws {
        let assetIDs = Self.stripAssetIDs
        let scale = Self.stripRenderScale
        let markSize = 14
        // 只标记索引 0 的邻居项目；其余项目保持未标记。
        let render = try renderStrip(
            markedAssetIDs: [assetIDs[0]],
            markSize: CGFloat(markSize),
            contentWhite: 0.1
        )
        let frame = render.frames[0]
        let minX = Int(frame.minX) * scale
        let maxX = Int(frame.maxX) * scale - 1
        let minY = Int(frame.minY) * scale
        let width = Int(frame.width) * scale
        let height = Int(frame.height) * scale
        let boxSide = markSize * scale
        XCTAssertLessThanOrEqual(boxSide, width)
        XCTAssertLessThanOrEqual(boxSide, height)

        // 内容色参照点：同一项目内、标记框之外的下半部中心（不属于框内取证）。
        let referenceX = minX + width / 2
        let referenceY = minY + height - boxSide / 2
        let contentLuminance = render.bitmap.luminance(x: referenceX, y: referenceY)
        XCTAssertFalse(
            render.bitmap.isBackground(x: referenceX, y: referenceY),
            "内容参照点应为内容像素"
        )

        // (a) 标记所在的右上角沿 45° 对角线偏移 0/1 仍为背景：该角被圆角裁掉，
        //     标记叠层没有把它填上。
        for offset in 0...1 {
            XCTAssertTrue(
                render.bitmap.isBackground(x: maxX - offset, y: minY + offset),
                "标记角 diag=\(offset) 应为背景"
            )
        }

        // (b) 右上 markSize × markSize 框内存在明显暗于内容色的像素 —— 标记渲染了。
        var markPixelCount = 0
        var minimumLuminance = 255
        var maximumLuminance = 0
        var firstMarkPixel: (x: Int, y: Int)?
        for dy in 0..<boxSide {
            for dx in (width - boxSide)..<width {
                let luminance = render.bitmap.luminance(
                    x: minX + dx,
                    y: minY + dy
                )
                minimumLuminance = min(minimumLuminance, luminance)
                maximumLuminance = max(maximumLuminance, luminance)
                if luminance + 8 < contentLuminance {
                    markPixelCount += 1
                    if firstMarkPixel == nil {
                        firstMarkPixel = (x: minX + dx, y: minY + dy)
                    }
                }
            }
        }
        // 失败时把判据所需的全部读数带进消息，并按 IC-090 阶段二闸门 C 导出框内位图
        // （每 3 px 取一个样，'#' 暗于内容、'.' 等于内容、' ' 亮于内容/背景）。
        if markPixelCount == 0 {
            print("IC090_G181_MARKBOX frame=\(frame) box=" +
                "x[\(minX + width - boxSide)…\(minX + width - 1)] " +
                "y[\(minY)…\(minY + boxSide - 1)] " +
                "content=\(contentLuminance) min=\(minimumLuminance) " +
                "max=\(maximumLuminance)")
            for dy in stride(from: 0, to: boxSide, by: 3) {
                var row = ""
                for dx in stride(from: width - boxSide, to: width, by: 3) {
                    let luminance = render.bitmap.luminance(
                        x: minX + dx,
                        y: minY + dy
                    )
                    if luminance + 8 < contentLuminance {
                        row += "#"
                    } else if luminance == contentLuminance {
                        row += "."
                    } else {
                        row += " "
                    }
                }
                print("IC090_G181_MARKBOX row dy=\(dy) |\(row)|")
            }
        }
        XCTAssertGreaterThan(
            markPixelCount,
            0,
            "出厂尺寸下标记未渲染：框内内容色=\(contentLuminance)、" +
                "最暗=\(minimumLuminance)、最亮=\(maximumLuminance)"
        )
        XCTAssertNotNil(firstMarkPixel)

        // (c) 框外不做逐像素比较。
    }

    // IC-093 D1（夹具驱动，真机未覆盖）：横栏待删标记的双色渲染。
    // 取证只在已标记项目右上 markSize × markSize 框内，且只看「标记前后有差异」的像素——
    // 框角的背景像素在两次渲染里相同，因此不会被误当成符号或圆底。
    //   (a) 差异像素里存在亮度 > 200 的 —— 白色符号；
    //   (b) 差异像素里存在「明显暗于内容但远离纯黑」的 —— 半透明黑圆底（0.55 over 内容）；
    //   (c) 浅色与深色两个 colorScheme 下，标记框位图逐像素相同 —— 固定色值。
    // 观感是否合适由 H40 判定。
    @MainActor
    func testIC093D1StripMarkIsFixedTwoToneAcrossColorSchemes() throws {
        let markSize = 14
        let unmarked = try ic093StripMarkBox(
            markedAssetIDs: [],
            markSize: markSize
        )
        let light = try ic093StripMarkBox(
            markedAssetIDs: [Self.stripAssetIDs[0]],
            markSize: markSize
        )
        let dark = try ic093StripMarkBox(
            markedAssetIDs: [Self.stripAssetIDs[0]],
            markSize: markSize,
            colorScheme: .dark
        )
        XCTAssertEqual(light.luminances.count, unmarked.luminances.count)
        XCTAssertGreaterThan(light.contentLuminance, 80)
        XCTAssertLessThan(light.contentLuminance, 180)

        let differing = zip(light.luminances, unmarked.luminances)
            .filter { $0.0 != $0.1 }
            .map(\.0)
        XCTAssertFalse(differing.isEmpty, "标记框内应有像素因标记而改变")
        XCTAssertTrue(
            differing.contains { $0 > 200 },
            "应有白色符号像素：差异像素最亮=\(differing.max() ?? -1)"
        )
        XCTAssertTrue(
            differing.contains {
                $0 > 20 && $0 < light.contentLuminance - 20
            },
            "应有半透明暗色圆底像素：内容=\(light.contentLuminance)、" +
                "差异像素最暗=\(differing.min() ?? -1)"
        )
        XCTAssertEqual(
            light.luminances,
            dark.luminances,
            "标记框在浅色与深色下逐像素相同"
        )

        // D3：标记所在的右上角仍被圆角裁掉（与 IC-090 G181(a) 同判据，换新颜色后仍成立）。
        for offset in 0...1 {
            XCTAssertTrue(
                light.isBackgroundAtTopTrailingDiagonal(offset: offset),
                "标记角 diag=\(offset) 应为背景"
            )
        }
    }

    // IC-093 D2（夹具驱动，真机未覆盖）：主图标记与横栏标记是同一个渲染视图，
    // 判据与 D1 相同。主图标记在 `S2View` 的浮层里，位置 / 脉冲 / 显示条件不在本断言内
    // （既有断言覆盖），此处渲染两处共用的 `S2PendingDeletionMark` 本身。
    @MainActor
    func testIC093D2PrimaryMarkIsFixedTwoToneAcrossColorSchemes() throws {
        // 两处调用点用的是同一个符号常量与同一个渲染视图。
        XCTAssertEqual(
            S2PrimaryMarkPresenter.symbolName,
            S2PendingDeletionMark.symbolName
        )
        XCTAssertEqual(
            S2BottomStripMarkPresentation.symbolName,
            S2PendingDeletionMark.symbolName
        )
        XCTAssertEqual(S2PendingDeletionMark.circleOpacity, 0.55, accuracy: 0.000_001)

        let size = S2PrimaryMarkPresenter.markSize(
            bottomStripMarkSize: S2CalibrationConfiguration
                .factoryPlaceholder.bottomStripMarkSize
        )
        let light = try ic093PrimaryMarkLuminances(size: size)
        let dark = try ic093PrimaryMarkLuminances(
            size: size,
            colorScheme: .dark
        )
        let contentLuminance = 128

        XCTAssertTrue(
            light.contains { $0 > 200 },
            "应有白色符号像素：最亮=\(light.max() ?? -1)"
        )
        XCTAssertTrue(
            light.contains { $0 > 20 && $0 < contentLuminance - 20 },
            "应有半透明暗色圆底像素：最暗=\(light.min() ?? -1)"
        )
        XCTAssertEqual(light, dark, "主图标记在浅色与深色下逐像素相同")
    }

    // IC-093 R1：`图片替换被抑制` 事件的 details 原文；关闭录制时零副作用。
    func testIC093SuppressedReplacementEventDetails() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration
        )
        let diagnostics = S2OnDeviceTransitionDiagnosticsCoordinator()
        diagnostics.attach(controller)
        diagnostics.selectedScenario = .pinchStart
        diagnostics.start()
        diagnostics.recordImageReplacementSuppressed(
            assetID: "asset-2",
            resultName: "degradedPreview",
            displayedPixelSize: CGSize(width: 3_060, height: 4_080),
            candidatePixelSize: CGSize(width: 90, height: 120)
        )
        diagnostics.stop()
        diagnostics.export()

        XCTAssertTrue(diagnostics.reportText.contains(
            "event=图片替换被抑制" +
                "\tsource=S2TemporaryPhotoImageView.requestImage" +
                "\tdetails=asset=asset-2；result=degradedPreview；" +
                "displayed=(w=3060.000000,h=4080.000000)；" +
                "candidate=(w=90.000000,h=120.000000)"
        ))

        let countAfterStop = diagnostics.recordedEntries.count
        diagnostics.recordImageReplacementSuppressed(
            assetID: "x",
            resultName: "y",
            displayedPixelSize: .zero,
            candidatePixelSize: .zero
        )
        XCTAssertEqual(diagnostics.recordedEntries.count, countAfterStop)
    }

    // MARK: - IC-093 标记位图夹具

    private struct IC093MarkBox {
        let luminances: [Int]
        let side: Int
        let contentLuminance: Int
        private let cornerIsBackground: [Bool]

        init(
            luminances: [Int],
            side: Int,
            contentLuminance: Int,
            cornerIsBackground: [Bool]
        ) {
            self.luminances = luminances
            self.side = side
            self.contentLuminance = contentLuminance
            self.cornerIsBackground = cornerIsBackground
        }

        func isBackgroundAtTopTrailingDiagonal(offset: Int) -> Bool {
            guard cornerIsBackground.indices.contains(offset) else {
                return false
            }
            return cornerIsBackground[offset]
        }
    }

    /// IC-093 D1：取索引 0 项目右上 `markSize × markSize` 框的亮度阵列（行优先）。
    /// 内容用中灰（`Color(white: 0.5)`），这样白符号、半透黑圆底、内容三者互相区分得开。
    @MainActor
    private func ic093StripMarkBox(
        markedAssetIDs: Set<String>,
        markSize: Int,
        colorScheme: ColorScheme = .light
    ) throws -> IC093MarkBox {
        let scale = Self.stripRenderScale
        let render = try renderStrip(
            markedAssetIDs: markedAssetIDs,
            markSize: CGFloat(markSize),
            contentWhite: 0.5,
            colorScheme: colorScheme
        )
        let frame = render.frames[0]
        let minX = Int(frame.minX) * scale
        let maxX = Int(frame.maxX) * scale - 1
        let minY = Int(frame.minY) * scale
        let width = Int(frame.width) * scale
        let height = Int(frame.height) * scale
        let side = markSize * scale
        XCTAssertLessThanOrEqual(side, width)
        XCTAssertLessThanOrEqual(side, height)

        var luminances: [Int] = []
        luminances.reserveCapacity(side * side)
        for dy in 0..<side {
            for dx in (width - side)..<width {
                luminances.append(
                    render.bitmap.luminance(x: minX + dx, y: minY + dy)
                )
            }
        }
        let contentLuminance = render.bitmap.luminance(
            x: minX + width / 2,
            y: minY + height - side / 2
        )
        let corners = (0...1).map { offset in
            render.bitmap.isBackground(x: maxX - offset, y: minY + offset)
        }
        return IC093MarkBox(
            luminances: luminances,
            side: side,
            contentLuminance: contentLuminance,
            cornerIsBackground: corners
        )
    }

    /// IC-093 D2：把两处共用的 `S2PendingDeletionMark` 单独渲染在中灰底上。
    @MainActor
    private func ic093PrimaryMarkLuminances(
        size: CGFloat,
        colorScheme: ColorScheme = .light
    ) throws -> [Int] {
        let renderer = ImageRenderer(
            content: ZStack {
                Color(white: 0.5)
                S2PendingDeletionMark(size: size)
            }
            .frame(width: size, height: size)
            .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = CGFloat(Self.stripRenderScale)
        renderer.proposedSize = ProposedViewSize(
            CGSize(width: size, height: size)
        )
        let cgImage = try XCTUnwrap(renderer.cgImage)
        let bitmap = try S2StripBitmap(cgImage: cgImage)
        var luminances: [Int] = []
        luminances.reserveCapacity(bitmap.width * bitmap.height)
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                luminances.append(bitmap.luminance(x: x, y: y))
            }
        }
        return luminances
    }

    // IC-085 G162：旧版持久化数据缺新键时按出厂值补齐；含新键时往返一致。
    func testIC085G162PersistedConfigurationRoundTripsNewStripKeys() throws {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(S2CalibrationConfiguration.self, from: encoded)
        XCTAssertEqual(decoded, configuration)

        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        for key in [
            "bottomStripCurrentItemGap", "bottomStripLeadingInset",
            "bottomStripDecelerationRate",
            "bottomStripExpandDurationMilliseconds",
            "bottomStripCollapseDurationMilliseconds"
        ] {
            json.removeValue(forKey: key)
        }
        json["bottomStripDragMinimumDistance"] = 4
        let legacy = try JSONSerialization.data(withJSONObject: json)
        let migrated = try JSONDecoder().decode(S2CalibrationConfiguration.self, from: legacy)
        XCTAssertEqual(migrated, configuration)
    }

    // IC-085 G163：静止态当前张 30×30、两侧间隙 13；邻居 20×30、间距 3；当前张居中。
    func testIC085G163IdleLayoutCurrentItemSquareWithGaps() {
        let layout = S2BottomStripLayout(metrics: Self.referenceMetrics)
        let viewport = Self.stripViewportSize
        let current = 2
        let contentX = layout.contentCenterX(of: current)
        let frames = (0..<5).map { index in
            layout.frame(
                at: index,
                currentIndex: current,
                expansion: 1,
                contentX: contentX,
                viewportSize: viewport
            )
        }

        XCTAssertEqual(frames[2].size, CGSize(width: 30, height: 30))
        XCTAssertEqual(frames[2].midX, viewport.width / 2, accuracy: 0.001)
        XCTAssertEqual(frames[2].midY, viewport.height / 2, accuracy: 0.001)
        for index in [0, 1, 3, 4] {
            XCTAssertEqual(frames[index].size, CGSize(width: 20, height: 30), "index=\(index)")
            XCTAssertEqual(frames[index].midY, viewport.height / 2, accuracy: 0.001)
        }
        XCTAssertEqual(frames[2].minX - frames[1].maxX, 13, accuracy: 0.001)
        XCTAssertEqual(frames[3].minX - frames[2].maxX, 13, accuracy: 0.001)
        XCTAssertEqual(frames[1].minX - frames[0].maxX, 3, accuracy: 0.001)
        XCTAssertEqual(frames[4].minX - frames[3].maxX, 3, accuracy: 0.001)
        XCTAssertEqual(
            viewport.width / 2 - frames[1].maxX,
            frames[3].minX - viewport.width / 2,
            accuracy: 0.001
        )
    }

    // IC-085 G163：滑动态全部 20×30、等距 3，当前张不放大；两态内容带高度相同。
    func testIC085G163DraggingLayoutEquallySpacedAndHeightUnchanged() {
        let layout = S2BottomStripLayout(metrics: Self.referenceMetrics)
        let viewport = Self.stripViewportSize
        let contentX = layout.contentCenterX(of: 2) + 7
        let frames = (0..<5).map { index in
            layout.frame(
                at: index,
                currentIndex: 2,
                expansion: 0,
                contentX: contentX,
                viewportSize: viewport
            )
        }
        for index in 0..<5 {
            XCTAssertEqual(frames[index].size, CGSize(width: 20, height: 30), "index=\(index)")
        }
        for index in 1..<5 {
            XCTAssertEqual(frames[index].minX - frames[index - 1].maxX, 3, accuracy: 0.001)
            XCTAssertEqual(frames[index].midX - frames[index - 1].midX, 23, accuracy: 0.001)
        }
        XCTAssertEqual(frames[2].midX, viewport.width / 2 - 7, accuracy: 0.001)

        XCTAssertEqual(Self.referenceMetrics.height, 30)
        XCTAssertEqual(
            layout.itemSize(at: 2, currentIndex: 2, expansion: 1).height,
            layout.itemSize(at: 2, currentIndex: 2, expansion: 0).height
        )
        let idle = metrics(visibility: .visible, strip: .idle, sheet: .closed)
        let dragging = metrics(visibility: .visible, strip: .dragging, sheet: .closed)
        XCTAssertEqual(idle.bottomStripHeight, 30)
        XCTAssertEqual(idle.bottomStripHeight, dragging.bottomStripHeight)
    }

    // IC-085 G163：两侧渐隐遮罩——内边距内不可见，随后 edgeFadeWidth 内线性升到 1，右侧对称；
    // 可见索引区间只覆盖视口附近。
    func testIC085G163EdgeFadeStopsAndVisibleRange() {
        let layout = S2BottomStripLayout(metrics: Self.referenceMetrics)
        let width = Self.stripViewportSize.width
        let stops = layout.fadeStops(viewportWidth: width)
        XCTAssertEqual(stops.count, 6)
        XCTAssertEqual(stops[0].location, 0)
        XCTAssertEqual(stops[0].opacity, 0)
        XCTAssertEqual(stops[1].location * width, 20.3, accuracy: 0.001)
        XCTAssertEqual(stops[1].opacity, 0)
        XCTAssertEqual(stops[2].location * width, 39, accuracy: 0.001)
        XCTAssertEqual(stops[2].opacity, 1)
        XCTAssertEqual((1 - stops[3].location) * width, 39, accuracy: 0.001)
        XCTAssertEqual(stops[3].opacity, 1)
        XCTAssertEqual((1 - stops[4].location) * width, 20.3, accuracy: 0.001)
        XCTAssertEqual(stops[4].opacity, 0)
        XCTAssertEqual(stops[5].location, 1)
        XCTAssertEqual(stops[5].opacity, 0)
        for index in 1..<stops.count {
            XCTAssertGreaterThanOrEqual(stops[index].location, stops[index - 1].location)
        }

        let visible = layout.visibleIndices(
            contentX: layout.contentCenterX(of: 100),
            viewportWidth: width,
            count: 1000
        )
        XCTAssertTrue(visible.contains(100))
        XCTAssertTrue(visible.contains(100 - 9))
        XCTAssertTrue(visible.contains(100 + 9))
        XCTAssertLessThan(visible.count, 30)
        XCTAssertEqual(
            layout.visibleIndices(contentX: 0, viewportWidth: width, count: 3),
            0..<3
        )
    }

    // IC-085 G164：拖动开始 → 状态机进入 dragging、当前张在 100 ms 内收缩为矩形（展开度 0）。
    func testIC085G164DragStartCollapsesWithinHundredMilliseconds() {
        let fixture = makeStripMotion()
        XCTAssertEqual(fixture.motion.expansion, 1)
        XCTAssertEqual(fixture.motion.phase, .idle)

        XCTAssertTrue(fixture.motion.beginDrag())
        XCTAssertEqual(fixture.machine.bottomStripState, .dragging)
        XCTAssertEqual(fixture.motion.phase, .dragging)
        XCTAssertTrue(fixture.driver.isRunning)

        fixture.clock.advance(by: 0.05)
        fixture.motion.tick()
        XCTAssertGreaterThan(fixture.motion.expansion, 0)
        XCTAssertLessThan(fixture.motion.expansion, 1)

        fixture.clock.advance(by: 0.05)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.expansion, 0, accuracy: 0.000_001)
        fixture.motion.tick()
        XCTAssertFalse(fixture.driver.isRunning)
        XCTAssertEqual(fixture.motion.phase, .dragging)
        XCTAssertEqual(fixture.machine.bottomStripState, .dragging)
    }

    // IC-085 G164 / 既有语义：拖动中定位项每跨过一个节距即切主图一次，触感回调次数相等；
    // 越过末张时停在末张。
    func testIC085MainImageFollowsStripDuringDrag() {
        var switches = 0
        let fixture = makeStripMotion(assetCount: 5, currentIndex: 1) {
            switches += 1
        }
        let pitch = fixture.motion.layout.pitch
        XCTAssertTrue(fixture.motion.beginDrag())
        fixture.motion.updateDrag(translation: 0)
        fixture.motion.updateDrag(translation: -pitch * 0.4)
        XCTAssertEqual(fixture.machine.currentIndex, 1)
        fixture.motion.updateDrag(translation: -pitch * 0.6)
        XCTAssertEqual(fixture.machine.currentIndex, 2)
        XCTAssertEqual(switches, 1)
        fixture.motion.updateDrag(translation: -pitch * 2.6)
        XCTAssertEqual(fixture.machine.currentIndex, 4)
        XCTAssertEqual(switches, 3)
        fixture.motion.updateDrag(translation: -pitch * 9)
        XCTAssertEqual(fixture.machine.currentIndex, 4)
        XCTAssertEqual(
            fixture.motion.contentX,
            fixture.motion.layout.contentCenterX(of: 4),
            accuracy: 0.001
        )
        fixture.motion.updateDrag(translation: pitch * 0.6)
        XCTAssertEqual(fixture.machine.currentIndex, 0)
        XCTAssertEqual(switches, 7)
        XCTAssertEqual(fixture.machine.bottomStripState, .dragging)
    }

    // IC-085 G164：松手后逐帧位移与 k = 0.998 曲线误差 ≤ 10%，累计位移与录屏 run1 检查点误差 ≤ 10%；
    // 减速期间定位项变化照常切主图，状态机保持 dragging 直到减速结束。
    func testIC085G164DecelerationMatchesReferenceCurve() {
        var switches = 0
        let fixture = makeStripMotion(assetCount: 60, currentIndex: 0) {
            switches += 1
        }
        let layout = fixture.motion.layout
        let k = S2BottomStripSystemReference.decelerationRate
        let v0 = S2BottomStripSystemReference.decelerationInitialVelocity
        XCTAssertTrue(fixture.motion.beginDrag())
        fixture.motion.updateDrag(translation: 0)
        fixture.motion.updateDrag(translation: -1)
        fixture.clock.advance(by: 0.1)
        fixture.motion.tick()
        let startX = fixture.motion.contentX
        fixture.motion.endDrag(velocity: -v0)
        XCTAssertEqual(fixture.motion.phase, .decelerating)
        XCTAssertEqual(fixture.machine.bottomStripState, .dragging)

        let frame: TimeInterval = 1 / 60
        let duration = S2BottomStripInertia.duration(initial: v0, rate: k)
        XCTAssertGreaterThan(duration, 1.5)
        XCTAssertLessThan(duration, 2.0)
        var previousX = startX
        var elapsed: TimeInterval = 0
        var checkpoints = S2BottomStripSystemReference.decelerationDisplacementCheckpoints[...]
        var frameCount = 0
        while fixture.motion.phase == .decelerating {
            fixture.clock.advance(by: frame)
            elapsed += frame
            fixture.motion.tick()
            frameCount += 1
            let measured = fixture.motion.contentX - previousX
            previousX = fixture.motion.contentX
            if elapsed < duration - frame {
                let expected = S2BottomStripInertia.displacement(initial: v0, rate: k, elapsed: elapsed) -
                    S2BottomStripInertia.displacement(initial: v0, rate: k, elapsed: elapsed - frame)
                XCTAssertEqual(
                    measured,
                    expected,
                    accuracy: max(0.01, abs(expected) * 0.1),
                    "frame=\(frameCount) elapsed=\(elapsed)"
                )
            }
            if let checkpoint = checkpoints.first, elapsed >= checkpoint.elapsed - frame / 2 {
                checkpoints = checkpoints.dropFirst()
                XCTAssertEqual(
                    fixture.motion.contentX - startX,
                    checkpoint.displacement,
                    accuracy: checkpoint.displacement * 0.1,
                    "checkpoint t=\(checkpoint.elapsed)"
                )
            }
            if fixture.motion.phase == .decelerating {
                XCTAssertEqual(fixture.machine.bottomStripState, .dragging, "frame=\(frameCount)")
            }
            XCTAssertEqual(
                fixture.machine.currentIndex,
                layout.nearestIndex(toContentX: fixture.motion.contentX, count: 60),
                "frame=\(frameCount)"
            )
            XCTAssertLessThan(frameCount, 600)
        }
        XCTAssertTrue(checkpoints.isEmpty, "未到达的检查点：\(checkpoints.count)")
        XCTAssertEqual(fixture.motion.phase, .settling)
        XCTAssertEqual(fixture.machine.bottomStripState, .idle)
        let expectedIndex = layout.nearestIndex(toContentX: fixture.motion.contentX, count: 60)
        XCTAssertEqual(fixture.machine.currentIndex, expectedIndex)
        XCTAssertEqual(switches, expectedIndex)
        XCTAssertGreaterThanOrEqual(expectedIndex, 17)
        XCTAssertLessThanOrEqual(expectedIndex, 19)
    }

    // IC-085 G164：减速停止后 600 ms 内完成吸附到最近项与当前张展开，曲线与录屏采样相符；
    // 终态后再无几何变化、帧驱动停止。
    func testIC085G164SettleSnapsToNearestItemAndExpandsWithinSixHundredMilliseconds() {
        let fixture = makeStripMotion(assetCount: 9, currentIndex: 4)
        let layout = fixture.motion.layout
        XCTAssertTrue(fixture.motion.beginDrag())
        fixture.motion.updateDrag(translation: 0)
        // 停在第 4 张与第 5 张中心之间、偏向第 5 张（13 pt > 节距一半 11.5）。
        fixture.motion.updateDrag(translation: -13)
        XCTAssertEqual(fixture.machine.currentIndex, 5)
        fixture.clock.advance(by: 0.2)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.expansion, 0, accuracy: 0.000_001)
        let fromX = fixture.motion.contentX
        let targetX = layout.contentCenterX(of: 5)
        XCTAssertEqual(targetX - fromX, 10, accuracy: 0.001)

        fixture.motion.endDrag(velocity: 0)
        XCTAssertEqual(fixture.motion.phase, .settling)
        XCTAssertEqual(fixture.machine.bottomStripState, .idle)
        XCTAssertTrue(fixture.driver.isRunning)

        for sample in S2BottomStripSystemReference.settleProgressSamples {
            let fresh = makeStripMotion(assetCount: 9, currentIndex: 4)
            XCTAssertTrue(fresh.motion.beginDrag())
            fresh.motion.updateDrag(translation: 0)
            fresh.motion.updateDrag(translation: -13)
            fresh.clock.advance(by: 0.2)
            fresh.motion.tick()
            fresh.motion.endDrag(velocity: 0)
            fresh.clock.advance(by: sample.elapsed)
            fresh.motion.tick()
            let progress = (fresh.motion.contentX - fromX) / (targetX - fromX)
            XCTAssertEqual(progress, sample.progress, accuracy: 0.1, "t=\(sample.elapsed)")
            XCTAssertEqual(fresh.motion.expansion, progress, accuracy: 0.000_001)
            XCTAssertLessThan(fresh.motion.expansion, 1)
            XCTAssertEqual(fresh.motion.phase, .settling)
        }

        fixture.clock.advance(by: 0.6)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.phase, .idle)
        XCTAssertEqual(fixture.motion.contentX, targetX, accuracy: 0.000_001)
        XCTAssertEqual(fixture.motion.expansion, 1, accuracy: 0.000_001)
        XCTAssertFalse(fixture.driver.isRunning)
        XCTAssertEqual(fixture.machine.currentIndex, 5)

        fixture.clock.advance(by: 1)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.contentX, targetX, accuracy: 0.000_001)
        XCTAssertEqual(fixture.motion.expansion, 1, accuracy: 0.000_001)
        XCTAssertEqual(fixture.motion.phase, .idle)
        XCTAssertFalse(fixture.driver.isRunning)
    }

    // IC-085 G164：松手偏向原张（8 pt < 11.5）时吸附回原张，不切图；低于终止速度的松手不进入减速。
    func testIC085G164ReleaseBelowHalfPitchSnapsBackWithoutSwitching() {
        var switches = 0
        let fixture = makeStripMotion(assetCount: 9, currentIndex: 4) {
            switches += 1
        }
        let layout = fixture.motion.layout
        XCTAssertTrue(fixture.motion.beginDrag())
        fixture.motion.updateDrag(translation: 0)
        fixture.motion.updateDrag(translation: -8)
        XCTAssertEqual(fixture.machine.currentIndex, 4)
        fixture.motion.endDrag(velocity: -S2BottomStripInertia.stopSpeed / 2)
        XCTAssertEqual(fixture.motion.phase, .settling)
        XCTAssertEqual(fixture.machine.bottomStripState, .idle)
        fixture.clock.advance(by: 0.6)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.phase, .idle)
        XCTAssertEqual(fixture.motion.contentX, layout.contentCenterX(of: 4), accuracy: 0.000_001)
        XCTAssertEqual(fixture.machine.currentIndex, 4)
        XCTAssertEqual(switches, 0)
    }

    // IC-085：减速中再次触下接管（序列不重新开始）；静止态外部定位项变化直接居中。
    func testIC085G164TouchDuringDecelerationTakesOverAndExternalIndexRecenters() {
        let fixture = makeStripMotion(assetCount: 60, currentIndex: 0)
        let layout = fixture.motion.layout
        XCTAssertTrue(fixture.motion.beginDrag())
        fixture.motion.updateDrag(translation: 0)
        fixture.motion.updateDrag(translation: -1)
        fixture.motion.endDrag(velocity: -600)
        XCTAssertEqual(fixture.motion.phase, .decelerating)
        fixture.clock.advance(by: 0.3)
        fixture.motion.tick()
        let xDuringDeceleration = fixture.motion.contentX
        XCTAssertGreaterThan(xDuringDeceleration, 100)

        XCTAssertTrue(fixture.motion.beginDrag())
        XCTAssertEqual(fixture.motion.phase, .dragging)
        XCTAssertEqual(fixture.machine.bottomStripState, .dragging)
        fixture.clock.advance(by: 0.3)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.contentX, xDuringDeceleration, accuracy: 0.000_001)
        fixture.motion.endDrag(velocity: 0)
        fixture.clock.advance(by: 0.6)
        fixture.motion.tick()
        XCTAssertEqual(fixture.motion.phase, .idle)
        XCTAssertEqual(fixture.machine.bottomStripState, .idle)

        fixture.motion.synchronize(count: 60, currentIndex: 30)
        XCTAssertEqual(fixture.motion.contentX, layout.contentCenterX(of: 30), accuracy: 0.000_001)
        XCTAssertEqual(fixture.motion.expansion, 1)
        XCTAssertEqual(fixture.motion.phase, .idle)
    }

    // IC-085：惯性模型本身——闭式位移等于速度积分，终止时间按 stopSpeed 求得。
    func testIC085InertiaClosedFormMatchesIntegratedVelocity() {
        let k = S2BottomStripSystemReference.decelerationRate
        let v0: CGFloat = 845.3
        let duration = S2BottomStripInertia.duration(initial: v0, rate: k)
        XCTAssertEqual(
            S2BottomStripInertia.velocity(initial: v0, rate: k, elapsed: duration),
            S2BottomStripInertia.stopSpeed,
            accuracy: 0.001
        )
        var integrated: CGFloat = 0
        let step: TimeInterval = 0.0001
        var t: TimeInterval = 0
        while t < 1 {
            integrated += S2BottomStripInertia.velocity(initial: v0, rate: k, elapsed: t + step / 2) * CGFloat(step)
            t += step
        }
        XCTAssertEqual(
            S2BottomStripInertia.displacement(initial: v0, rate: k, elapsed: 1),
            integrated,
            accuracy: 0.05
        )
        XCTAssertEqual(S2BottomStripInertia.duration(initial: 10, rate: k), 0)
        XCTAssertEqual(S2BottomStripInertia.settleProgress(elapsed: 0.6, duration: 0.6), 1)
        XCTAssertEqual(S2BottomStripInertia.settleProgress(elapsed: 0, duration: 0.6), 0)
        XCTAssertEqual(S2BottomStripInertia.collapseProgress(elapsed: 0.1, duration: 0.1), 1)
    }
}

final class S2StripTestClock {
    private(set) var now: TimeInterval = 1_000

    func advance(by interval: TimeInterval) {
        now += interval
    }
}

/// IC-085 R3 像素门禁用位图：RGBA8，背景判定为亮度 > 128（测试背景白、内容黑）。
struct S2StripBitmap {
    let width: Int
    let height: Int
    private let pixels: [UInt8]

    init(cgImage: CGImage) throws {
        width = cgImage.width
        height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = buffer
    }

    /// `y` 自上而下。
    func isBackground(x: Int, y: Int) -> Bool {
        luminance(x: x, y: y) > 128
    }

    /// IC-090 R1：原始亮度，供标记叠层与内容的区分判定。越界返回背景亮度 255。
    ///
    /// IC-090 R4（v2）修正：`CGBitmapContext` 的**内存首行即图像顶行**（用户空间 y 向上，
    /// 但缓冲区按行自顶向下存储），故按 `y` 直接索引；此前的 `(height - 1 - y)` 反而把
    /// `y` 变成了自下而上。该错误此前不可见：IC-085 与 IC-090 的既有断言要么取四角
    /// （上下对称）、要么取满高循环、要么取中线，都对垂直方向不敏感。第一个把它暴露
    /// 出来的是右上角标记断言——按旧式读法，`.topTrailing` 的标记落在读坐标的底部
    /// （实测：读 y=69 得亮度 8 的标记像素，而读 y∈[0,41] 只有内容 25 与背景 255）。
    func luminance(x: Int, y: Int) -> Int {
        guard x >= 0, x < width, y >= 0, y < height else {
            return 255
        }
        let offset = (y * width + x) * 4
        return (Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / 3
    }
}
