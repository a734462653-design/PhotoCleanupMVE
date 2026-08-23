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
            $0.fitInsetRatio = 0.075
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

    // IC-087 G171：持久化数据的 `schemaVersion` 与代码版本不等（或缺失）→ 整套丢弃、取出厂值并删除条目；
    // 相等 → 按现行逐字段解码。导出文本含 schemaVersion=3。
    func testIC087G171SchemaVersionGateDiscardsStaleStoreAndDeletesEntry() throws {
        XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 3)
        XCTAssertTrue(
            S2CalibrationConfiguration.factoryPlaceholder.exportText()
                .contains("schemaVersion=3")
        )

        // 1) schemaVersion=2 且 ceiling=10 → 出厂 40，且存储被删除。
        let stale = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: 2, ceiling: 10)
        )
        let staleModel = S2CalibrationModel(persistence: stale)
        XCTAssertEqual(staleModel.configuration, .factoryPlaceholder)
        XCTAssertEqual(staleModel.configuration.pinchMaxScaleCeiling, 40)
        XCTAssertNil(stale.data)
        XCTAssertEqual(stale.deleteCount, 1)
        XCTAssertEqual(stale.saveCount, 0)
        XCTAssertFalse(staleModel.persistenceFailed)

        // 2) schemaVersion=3 且 ceiling=12 → 12，存储保留。
        let current = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: 3, ceiling: 12)
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

        // 保存后的数据顶层带 schemaVersion=3，重新加载得同一配置。
        XCTAssertTrue(currentModel.update { $0.pinchMaxScaleCeiling = 15 })
        let saved = try XCTUnwrap(current.data)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: saved) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 3)
        XCTAssertEqual(
            S2CalibrationModel(persistence: current).configuration,
            currentModel.configuration
        )

        // 删除失败时 persistenceFailed 置位，配置仍为出厂。
        let failing = InMemoryCalibrationPersistence(
            data: try makeStoredCalibration(schemaVersion: 2, ceiling: 10)
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
            data: try makeStoredCalibration(schemaVersion: 3, ceiling: 12)
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

    // V8 改写：内缩比例只作用于截图元数据，旧作用范围不再改变几何。
    func testV8FitInsetRatioAppliesOnlyToScreenshotMetadata() {
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

        let croppedScreenshotRatio: CGFloat = 0.1823
        let scopedScreenshot = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: croppedScreenshotRatio,
            isScreenshot: true,
            configuration: inset
        )
        XCTAssertEqual(
            scopedScreenshot.oneXDisplaySize.width,
            scopedScreenshot.aspectFitSize.width * 0.9,
            accuracy: 0.000_001
        )

        let globalScreenshot = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: croppedScreenshotRatio,
            isScreenshot: true,
            configuration: inset
        )
        let ordinaryPhoto = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: screenAspectRatio,
            isScreenshot: false,
            configuration: inset
        )
        XCTAssertEqual(
            globalScreenshot.oneXDisplaySize,
            scopedScreenshot.oneXDisplaySize
        )
        XCTAssertEqual(
            ordinaryPhoto.oneXDisplaySize,
            ordinaryPhoto.aspectFitSize
        )
        XCTAssertFalse(ordinaryPhoto.isFramedPhoto)
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
            fitInsetRatio: 0.30,
            fitCornerRadius: 28,
            fitBorderWidth: 1,
            fitBorderDarkAlpha: 0.09,
            fitBorderLightAlpha: 0.055,
            pageSpacing: 20,
            hapticOnPhotoSwitch: true,
            bottomStripCurrentItemSize: 72,
            bottomStripNeighborItemWidth: 52,
            bottomStripNeighborItemHeight: 44,
            bottomStripItemSpacing: 8,
            bottomStripEdgeFadeWidth: 24,
            bottomStripDragMinimumDistance: 4,
            bottomStripSwitchDistance: 44,
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
        XCTAssertTrue(actual.exportText().contains("fitInsetRatio=0.300000"))
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
        XCTAssertEqual(statuses["bottomStripEdgeFadeWidth"], .unwired)
        XCTAssertEqual(
            statuses["presentationToggleDamping"],
            .effective
        )
        XCTAssertEqual(statuses["pinchMaxScaleFloor"], .effective)
        XCTAssertEqual(statuses["pinchMaxScaleCeiling"], .effective)
        XCTAssertEqual(statuses["pinchMaxScaleOneToOneMultiplier"], .effective)
        XCTAssertEqual(statuses["edgePagingTriggerDistance"], .effective)
    }

    // IC-074 G96：配置字段恰 33 个；导出 37 行，含 schemaVersion 与 v15 规格基线（IC-087：schemaVersion=3）。
    func testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export() {
        let fieldNames = Mirror(
            reflecting: S2CalibrationConfiguration.factoryPlaceholder
        ).children.compactMap(\.label)
        XCTAssertEqual(fieldNames.count, 38)

        let lines = S2CalibrationConfiguration.factoryPlaceholder
            .exportText()
            .split(separator: "\n")
            .map(String.init)
        XCTAssertEqual(lines.count, 38 + 4)
        XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 3)
        XCTAssertTrue(lines.contains("schemaVersion=3"))
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
    func testIC074G97ParameterRegistryDecidedSetMatchesV15() {
        let connections = S2CalibrationConfiguration.parameterConnections
        XCTAssertEqual(connections.count, 38)
        XCTAssertEqual(Set(connections.map(\.name)).count, 38)

        let decided = Set(connections
            .filter { $0.specStatus == .decided }
            .map(\.name))
        let placeholder = Set(connections
            .filter { $0.specStatus == .placeholder }
            .map(\.name))
        XCTAssertEqual(decided, [
            "zoomSnapBackThreshold", "minDoubleTapScale",
            "presentationToggleDuration", "presentationToggleDamping",
            "fitInsetRatio", "fitCornerRadius", "fitBorderWidth",
            "fitBorderDarkAlpha", "fitBorderLightAlpha",
            "verticalSwipeDistance", "verticalSwipeVelocity",
            "pageSpacing", "hapticOnPhotoSwitch",
            "doubleTapDecisionWindowMilliseconds",
            "edgePagingTriggerDistance", "edgePagingTriggerVelocity",
            "bottomStripMarkSize", "markPulseDurationMilliseconds",
            "feedbackToastDurationMilliseconds",
            "scaleChangeRequestPolicy", "degradedPreviewPolicy",
            "pinchMaxScaleFloor", "pinchMaxScaleCeiling"
        ])
        XCTAssertEqual(decided.count, 23)
        XCTAssertEqual(placeholder.count, 15)
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
                "currentIndex,settledIndex,pageIndicesPresent,pageLoadStates"
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

    // D1 再改写：截图按新出厂值等比适配到 0.70 视口框。
    func testD1ScreenshotAspectFitShrinksToSeventyPercentViewport() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.30
        let value = metrics(configuration: configuration)

        XCTAssertEqual(
            min(value.oneXDisplaySize.width, value.oneXDisplaySize.height),
            min(value.viewportSize.width, value.viewportSize.height) * 0.70,
            accuracy: 1
        )
        let oppositeOrientation = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: 1 / screenAspectRatio,
            isScreenshot: true,
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

    // D3 改写：即使旧作用范围为全部照片，非截图的 1x 显示仍不变。
    func testD3AllPhotosScopeLeavesNonScreenshotUnchanged() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0.30
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
        configuration.fitInsetRatio = 0.30
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

    // IC-063 G2 改写：裁切截图在显示态等比内缩且四边居中。
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
        let expectedScale = 1 - CGFloat(configuration.fitInsetRatio)
        let expectedFit = S2Geometry.aspectFitSize(
            viewportSize: physicalSize,
            assetAspectRatio: croppedScreenshotRatio
        )

        XCTAssertEqual(
            frame.width,
            expectedFit.width * expectedScale,
            accuracy: 0.5
        )
        XCTAssertEqual(
            frame.height,
            expectedFit.height * expectedScale,
            accuracy: 0.5
        )
        XCTAssertEqual(frame.minX, physicalSize.width - frame.maxX, accuracy: 0.5)
        XCTAssertEqual(frame.minY, physicalSize.height - frame.maxY, accuracy: 0.5)
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

    // F1：0.30 内缩令屏幕比例照片的 1x 短边等于视口短边的 0.70。
    func testF1FactoryInsetShrinksShortEdgeToSeventyPercent() {
        let value = metrics()

        XCTAssertEqual(
            min(value.oneXDisplaySize.width, value.oneXDisplaySize.height),
            min(value.viewportSize.width, value.viewportSize.height) * 0.70,
            accuracy: 1
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

    // IC-065 G27：宽度受限、矮于视口的完整适配照片在 1x 垂直居中。
    func testIC065G27HeightLimitedOneXIsVerticallyCentered() {
        let hosted = makeIC065HostedPage(assetAspectRatio: 9.0 / 16.0)
        defer { hosted.window.isHidden = true }
        let frame = ic065PresentationFrameInWindow(
            page: hosted.page,
            window: hosted.window
        )

        XCTAssertLessThan(frame.height, hosted.window.bounds.height)
        XCTAssertEqual(
            frame.midY,
            hosted.window.bounds.midY,
            accuracy: 0.5
        )
    }

    // IC-065 G28～G29：60Hz presentation 轨迹在接管首帧及全程保持小尺寸方向居中。
    func testIC065G28ToG29PinchTrackHasNoCenterJump() {
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
            XCTAssertLessThanOrEqual(
                abs(pinchBegan.frameInWindow.midX - oneX.frameInWindow.midX),
                0.5
            )
            XCTAssertLessThanOrEqual(
                abs(pinchBegan.frameInWindow.midY - oneX.frameInWindow.midY),
                0.5
            )
            XCTAssertLessThanOrEqual(
                abs(firstGrowth.frameInWindow.midX -
                    pinchBegan.frameInWindow.midX),
                0.5
            )
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
                    XCTAssertEqual(
                        frame.midY,
                        viewport.midY,
                        accuracy: 0.5,
                        "样本=\(name)，序号=\(index)"
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
            XCTAssertEqual(frame.size.width, expected.oneXDisplaySize.width)
            XCTAssertEqual(frame.size.height, expected.oneXDisplaySize.height)
            XCTAssertEqual(frame.midX, hosted.window.bounds.midX, accuracy: 0.5)
            XCTAssertEqual(frame.midY, hosted.window.bounds.midY, accuracy: 0.5)
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

    // IC-067 G36：裁切截图在显示态等比适配 0.70 视口框，隐藏态等比适配全视口。
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
        let expectedScale = 1 - CGFloat(configuration.fitInsetRatio)

        XCTAssertTrue(visible.isFramedPhoto)
        XCTAssertEqual(
            visible.oneXDisplaySize.width,
            visible.aspectFitSize.width * expectedScale,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            visible.oneXDisplaySize.height,
            visible.aspectFitSize.height * expectedScale,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            visible.oneXCornerRadius,
            CGFloat(configuration.fitCornerRadius)
        )
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
        let frame = page.zoomScrollView.oneXPresentationFrame
        XCTAssertEqual(frame.midX, physicalSize.width / 2, accuracy: 0.5)
        XCTAssertEqual(frame.midY, physicalSize.height / 2, accuracy: 0.5)
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
            XCTAssertEqual(
                sample.frame.midY,
                physicalSize.height / 2,
                accuracy: 0.5
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
        XCTAssertEqual(
            hiding.first?.bounds.size ?? .zero,
            CGSize(width: 210, height: 420)
        )
        XCTAssertEqual(hiding.last?.bounds.size ?? .zero, physicalSize)
        XCTAssertEqual(showing.first?.bounds.size ?? .zero, physicalSize)
        XCTAssertEqual(
            showing.last?.bounds.size ?? .zero,
            CGSize(width: 210, height: 420)
        )
        XCTAssertEqual(hiding.first?.frame.width ?? -1, 210, accuracy: 0.5)
        XCTAssertEqual(hiding.last?.frame.width ?? -1, 300, accuracy: 0.5)
        XCTAssertEqual(showing.first?.frame.width ?? -1, 300, accuracy: 0.5)
        XCTAssertEqual(showing.last?.frame.width ?? -1, 210, accuracy: 0.5)
        assertSpringOvershootAndConvergence(
            hidingScaleKeyframes.map { $0 * 210 },
            source: 210,
            target: 300
        )
        assertSpringOvershootAndConvergence(
            showingScaleKeyframes.map { $0 * 300 },
            source: 300,
            target: 210
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
        XCTAssertEqual(frameWithBorder?.size, value.oneXDisplaySize)
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
            XCTAssertEqual(frame.midY, physicalSize.height / 2, accuracy: 0.5)
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
        diagnostics.recordUpdateUIView(wrotePhotoGeometry: true)
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
        XCTAssertFalse(machine.handleSwipeUp())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertNil(machine.semanticNotice)
        XCTAssertEqual(presenter.consumedNoticeCount, 2)
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
        diagnostics.recordUpdateUIView(wrotePhotoGeometry: false)
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
            (keyframes.last ?? -1) * 210,
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
            if let index = values.firstIndex(of: extreme) {
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
            if let index = values.firstIndex(of: extreme) {
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
