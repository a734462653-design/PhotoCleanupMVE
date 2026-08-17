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

    // IC-067 前提探针：真实截图经 PhotoKit 裁切编辑后仍保留截图子类型。
    func testIC067ProbeEditedScreenshotRetainsMediaSubtype() throws {
        let authorizationExpectation = expectation(
            description: "等待照片读取授权"
        )
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            authorizationExpectation.fulfill()
        }
        wait(for: [authorizationExpectation], timeout: 10)
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(
            for: .readWrite
        )
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        print(
            "IC067_G38_AUTH " +
                "bundleID=\(bundleID) " +
                "status=\(authorizationStatus.rawValue)"
        )
        XCTAssertEqual(
            authorizationStatus,
            .authorized
        )

        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var screenshot: PHAsset?
        assets.enumerateObjects { asset, _, stop in
            guard asset.mediaSubtypes.contains(.photoScreenshot) else {
                return
            }
            screenshot = asset
            stop.pointee = true
        }
        let original = try XCTUnwrap(screenshot)
        XCTAssertTrue(original.canPerform(.content))

        let inputExpectation = expectation(description: "读取截图编辑输入")
        let inputOptions = PHContentEditingInputRequestOptions()
        inputOptions.isNetworkAccessAllowed = false
        var editingInput: PHContentEditingInput?
        original.requestContentEditingInput(with: inputOptions) { input, _ in
            editingInput = input
            inputExpectation.fulfill()
        }
        wait(for: [inputExpectation], timeout: 10)

        let input = try XCTUnwrap(editingInput)
        let sourceURL = try XCTUnwrap(input.fullSizeImageURL)
        let sourceImage = try XCTUnwrap(
            UIImage(contentsOfFile: sourceURL.path)
        )
        let cropSize = CGSize(
            width: max(1, floor(sourceImage.size.width * 0.2)),
            height: sourceImage.size.height
        )
        let cropOrigin = CGPoint(
            x: floor((sourceImage.size.width - cropSize.width) / 2),
            y: 0
        )
        let rendered = UIGraphicsImageRenderer(size: cropSize).image { _ in
            sourceImage.draw(
                at: CGPoint(x: -cropOrigin.x, y: -cropOrigin.y)
            )
        }
        let renderedData = try XCTUnwrap(
            rendered.jpegData(compressionQuality: 1)
        )
        let output = PHContentEditingOutput(contentEditingInput: input)
        try renderedData.write(to: output.renderedContentURL, options: .atomic)
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: "com.iphonephotomanagement.ic067-probe",
            formatVersion: "1",
            data: Data("{\"cropWidthRatio\":0.2}".utf8)
        )

        try PHPhotoLibrary.shared().performChangesAndWait {
            PHAssetChangeRequest(for: original).contentEditingOutput = output
        }

        let edited = try XCTUnwrap(
            PHAsset.fetchAssets(
                withLocalIdentifiers: [original.localIdentifier],
                options: nil
            ).firstObject
        )
        print(
            "IC067_G38_PROBE " +
                "beforeSubtypes=\(original.mediaSubtypes.rawValue) " +
                "afterSubtypes=\(edited.mediaSubtypes.rawValue) " +
                "renderedSize=\(Int(cropSize.width))x\(Int(cropSize.height))"
        )
        XCTAssertTrue(edited.mediaSubtypes.contains(.photoScreenshot))
    }

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

    // L7：完整出厂配置包含 IC-064 的显隐时长与描边定案。
    func testL7FactoryDefaultsMatchSystemParityDecision() {
        let expected = S2CalibrationConfiguration(
            pinchMaxScale: 4,
            zoomSnapBackThreshold: 1.1,
            minDoubleTapScale: 2,
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
            presentationToggleDuration: 220,
            fitInsetRatio: 0.30,
            fitCornerRadius: 28,
            fitBorderWidth: 1,
            fitBorderDarkAlpha: 0.09,
            fitBorderLightAlpha: 0.055,
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
                "taskID=IC-20260817-064-s2-presentation-toggle-animation"
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
        XCTAssertTrue(actual.exportText().contains("fitBorderWidth=1.000000"))
        XCTAssertTrue(actual.exportText().contains("fitBorderDarkAlpha=0.090000"))
        XCTAssertTrue(actual.exportText().contains("fitBorderLightAlpha=0.055000"))
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
            physicalSize.width * 0.70,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            oppositeOrientation.oneXDisplaySize.height,
            physicalSize.height * 0.70,
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

    // IC-063 G1：隐藏态 1x 的命中照片严格铺满物理屏幕。
    func testIC063G1HiddenMatchedPhotoWindowFrameEqualsScreenBounds() {
        let viewportSize = UIScreen.main.bounds.size
        let assetRatio = viewportSize.width / viewportSize.height
        let machine = makeMachine(interfaceVisibility: .hidden)
        let controller = makeNativePagerController(
            machine: machine,
            assetAspectRatio: assetRatio,
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

    // IC-063 G2：显示态 1x 按 fitInsetRatio 内缩且四边对称。
    func testIC063G2VisibleMatchedPhotoUsesInsetLayoutAndIsCentered() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let nearToleranceRatio = screenAspectRatio * 1.009
        let machine = makeMachine(configuration: configuration)
        let controller = makeNativePagerController(
            machine: machine,
            configuration: configuration,
            assetAspectRatio: nearToleranceRatio
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let frame = tryUnwrap(page.zoomScrollView.visiblePresentationFrame())
        let expectedScale = 1 - CGFloat(configuration.fitInsetRatio)

        XCTAssertEqual(
            frame.width,
            physicalSize.width * expectedScale,
            accuracy: 0.5
        )
        XCTAssertEqual(
            frame.height,
            physicalSize.height * expectedScale,
            accuracy: 0.5
        )
        XCTAssertEqual(frame.minX, physicalSize.width - frame.maxX, accuracy: 0.5)
        XCTAssertEqual(frame.minY, physicalSize.height - frame.maxY, accuracy: 0.5)
    }

    // IC-063 G3：命中照片双击目标固定为 2，未命中照片仍取填满倍数。
    func testIC063G3DoubleTapTargetUsesTwoOnlyForMatchedPhotos() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let matched = metrics(configuration: configuration)
        let nonMatchedRatio: CGFloat = 0.75
        let nonMatched = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: presentationState,
            assetAspectRatio: nonMatchedRatio,
            configuration: configuration
        )
        let fill = tryUnwrap(S2Geometry.aspectFillMultiplier(
            viewportSize: physicalSize,
            assetAspectRatio: nonMatchedRatio
        ))

        XCTAssertEqual(configuration.minDoubleTapScale, 2, accuracy: 0.000_001)
        XCTAssertEqual(matched.doubleTapTargetScale, 2, accuracy: 0.000_001)
        XCTAssertFalse(nonMatched.isFramedPhoto)
        XCTAssertEqual(nonMatched.doubleTapTargetScale, fill, accuracy: 0.000_001)
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

        diagnostics.export()
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

    // S2 替代断言：框显照片隐藏后两轴严格填满视口且圆角归零。
    func testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let hidden = metrics(
            visibility: .hidden,
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
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.cornerRadius, hidden.oneXCornerRadius)
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

    // X2：终态几何在动画开始前提交，照片显示层只承载等比 transform。
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
        XCTAssertEqual(page.fittedSize, transition.targetSize)
        XCTAssertEqual(page.zoomScrollView.fittedSize, transition.targetSize)
        XCTAssertEqual(page.zoomScrollView.contentSize, contentSize)
        XCTAssertEqual(
            page.zoomScrollView.presentationContentView?.bounds.size,
            transition.targetSize
        )
        let sourceScale = min(
            transition.layoutSize.width / transition.targetSize.width,
            transition.layoutSize.height / transition.targetSize.height
        )
        XCTAssertEqual(transform.a, sourceScale, accuracy: 0.000_001)
        XCTAssertEqual(transform.b, 0, accuracy: 0.000_001)
        XCTAssertEqual(transform.c, 0, accuracy: 0.000_001)
        XCTAssertEqual(transform.d, sourceScale, accuracy: 0.000_001)
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
            hiding.frame(at: 0).cornerRadius,
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
            showing.frame(at: 0).cornerRadius,
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
        XCTAssertEqual(page.fittedSize, hidden.oneXDisplaySize)
        XCTAssertEqual(page.presentationTransitionCount, 1)
        XCTAssertEqual(page.presentationGeometryCommitCount, 1)
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

    // Y2：容差内命中但比例不完全相等时，隐藏态仍严格填满两轴且圆角为零。
    func testY2MatchedPhotoHiddenDisplayStrictlyEqualsViewportAndHasZeroRadius() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let assetAspectRatio = screenAspectRatio * 1.008
        let visible = S2ViewportLayout.metrics(
            physicalSize: physicalSize,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: .visible,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: assetAspectRatio,
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
            configuration: configuration
        )

        XCTAssertTrue(hidden.isFramedPhoto)
        XCTAssertNotEqual(hidden.aspectFitSize, hidden.viewportSize)
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
            configuration: configuration,
            assetAspectRatio: assetAspectRatio
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio
        )

        let targetFrame = tryUnwrap(page.lastPresentationTransition).frame(at: 1)
        XCTAssertEqual(
            visible.oneXDisplaySize.width * targetFrame.scaleX,
            hidden.viewportSize.width,
            accuracy: 1
        )
        XCTAssertEqual(
            visible.oneXDisplaySize.height * targetFrame.scaleY,
            hidden.viewportSize.height,
            accuracy: 1
        )
        page.finishActivePresentationTransition()
        XCTAssertEqual(page.fittedSize.width, physicalSize.width, accuracy: 1)
        XCTAssertEqual(page.fittedSize.height, physicalSize.height, accuracy: 1)
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
            assetAspectRatio: assetAspectRatio
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let initialSize = page.fittedSize
        let initialRadius = page.cornerRadius
        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: configuration,
            assetAspectRatio: assetAspectRatio
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

    // IC-065 G31：命中屏幕比例时继续保持 IC-063 G1～G2 的铺满与内缩结果。
    func testIC065G31MatchedPhotoKeepsIC063Geometry() {
        let assetAspectRatio = screenAspectRatio * 1.008
        let states: [S2InterfaceVisibility] = [.hidden, .visible]

        for visibility in states {
            let hosted = makeIC065HostedPage(
                assetAspectRatio: assetAspectRatio,
                interfaceVisibility: visibility
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

    // IC-065 G32：冻结 IC-064 交付报告中的双向逐帧宽度序列。
    func testIC065G32IC064DeliveredWidthSequenceRemainsExact() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let hidingWidths: [CGFloat] = [
            210.000, 210.000, 217.844, 224.675, 231.492, 238.315,
            245.085, 251.904, 258.730, 265.534, 272.353, 279.176,
            286.031, 292.821, 299.653, 300.000
        ]
        let showingWidths: [CGFloat] = [
            300.000, 300.000, 287.290, 280.497, 273.712, 266.895,
            260.095, 253.281, 246.460, 239.626, 232.759, 225.990,
            219.187, 212.319, 210.000
        ]

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )
        let hiding = tryUnwrap(page.lastPresentationTransition)
        XCTAssertEqual(page.lastPresentationTransitionDuration, 0.22)
        for expectedWidth in hidingWidths {
            let progress = (expectedWidth - 210) / 90
            XCTAssertEqual(
                hiding.size(at: progress).width,
                expectedWidth,
                accuracy: 0.5
            )
        }
        page.finishActivePresentationTransition()

        XCTAssertTrue(machine.handleSingleTap())
        applyNativePagerController(
            controller,
            machine: machine,
            configuration: .factoryPlaceholder
        )
        let showing = tryUnwrap(page.lastPresentationTransition)
        XCTAssertEqual(page.lastPresentationTransitionDuration, 0.22)
        for expectedWidth in showingWidths {
            let progress = (300 - expectedWidth) / 90
            XCTAssertEqual(
                showing.size(at: progress).width,
                expectedWidth,
                accuracy: 0.5
            )
        }
        page.finishActivePresentationTransition()
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

    // IC-064 G13～G18：真实显示层采样同时满足等比、中心、双向与稳定性。
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
            Set(hiding.map { Int(($0.frame.width * 1_000).rounded()) }).count,
            3
        )
        XCTAssertGreaterThan(
            Set(showing.map { Int(($0.frame.width * 1_000).rounded()) }).count,
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
        let hidingBounds = hiding.last?.bounds ?? .zero
        let showingBounds = showing.last?.bounds ?? .zero
        XCTAssertTrue(hiding.dropFirst().allSatisfy {
            $0.bounds == hidingBounds
        })
        XCTAssertTrue(showing.dropFirst().allSatisfy {
            $0.bounds == showingBounds
        })
        XCTAssertEqual(hiding.first?.frame.width ?? -1, 210, accuracy: 0.5)
        XCTAssertEqual(hiding.last?.frame.width ?? -1, 300, accuracy: 0.5)
        XCTAssertEqual(showing.first?.frame.width ?? -1, 300, accuracy: 0.5)
        XCTAssertEqual(showing.last?.frame.width ?? -1, 210, accuracy: 0.5)
        assertMonotonic(
            hiding.map(\.frame.width),
            direction: .increasing
        )
        assertMonotonic(
            showing.map(\.frame.width),
            direction: .decreasing
        )
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
        assertMonotonic(showingCornerRadii, direction: .increasing)
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

    // IC-064 G21：Nx 描边归零，显隐过渡中的视觉线宽连续收敛。
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
        assertMonotonic(showingWidths, direction: .increasing)
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
        XCTAssertTrue(machine.handleSingleTap())
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

    private func makeIC065HostedPage(
        assetAspectRatio: CGFloat,
        interfaceVisibility: S2InterfaceVisibility = .visible
    ) -> (
        window: UIWindow,
        machine: S2StateMachine,
        controller: S2NativePagerViewController,
        page: S2NativeZoomPageController
    ) {
        let machine = makeMachine(interfaceVisibility: interfaceVisibility)
        let controller = makeNativePagerController(
            machine: machine,
            assetAspectRatio: assetAspectRatio
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
            maximumZoomScale: CGFloat(configuration.pinchMaxScale)
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
        viewportSize: CGSize? = nil
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
            viewportSize: resolvedViewportSize
        )
        return controller
    }

    private func applyNativePagerController(
        _ controller: S2NativePagerViewController,
        machine: S2StateMachine,
        configuration: S2CalibrationConfiguration,
        photoContent: ((String, CGSize, CGFloat, Int) -> AnyView)? = nil,
        assetAspectRatio: CGFloat? = nil,
        viewportSize: CGSize? = nil
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
                content: content
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
}
