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

    // V1ï¼çé¢æ¾éä¸æ¹åå¨å±ç©çè§å£ã
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

    // V2ï¼æ¨ªæ éæ­¢æä¸æ»å¨æä¿æç¸åè§å£ååºå®å¤å±é«åº¦ã
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

    // V3ï¼ç³»ç» sheet åªé®æ¡è¾å¥ï¼ä¸æ¹åä¸»å¾è§å£ã
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

    // V4 æ¿ä»£æ­è¨ï¼çé¢ç¶æåªå¯æ¹åæ¡æ¾ç§çç 1x åç°ï¼ä¸æ¹åç¼©æ¾åºåã
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

    // V5ï¼éæ¯å¹¶éå»ºæ¨¡ååï¼è¿ç¨æä¹åä»è´¨ä»è½è¯»åå¨é¨éç½®ã
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
                "valueStatus=â£é¡¹ç®å¤æ­é»è®¤å¼ï¼å¯ä¿®è®¢"
            )
        )

        restarted.restoreFactoryPlaceholder()
        let resetRestart = S2CalibrationModel(persistence: persistence)
        XCTAssertEqual(
            resetRestart.configuration,
            S2CalibrationConfiguration.factoryPlaceholder
        )
    }

    // V6ï¼åç§ç­ç¥ç»åä»é¢æ¿éç½®è¿å¥ç¶ææºå¹¶é©±å¨åä¸è¯·æ±å¤å®å¨ã
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

    // V7ï¼æ å¹éç´ ææ¶è¿åå·åç©ºç»æå¹¶ä¿çå½åç§çã
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

    // V8 æ¹åï¼åç¼©æ¯ä¾åªä½ç¨äºæªå¾åæ°æ®ï¼æ§ä½ç¨èå´ä¸åæ¹åå ä½ã
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

    // L1ï¼é¡¶é¨ä¸ä¸ªåç´ å¨é¨ä»ç³»ç»é¡¶é¨å®å¨åºä¸æ²¿å¼å§å¸å±ï¼IC-075 èµ·ä¸ºä¸ä»¶ï¼ã
    func testL1TopOverlayFramesRespectSafeAreaTop() {
        let snapshot = overlaySnapshot()

        XCTAssertEqual(snapshot.topElementFrames.count, 3)
        for frame in snapshot.topElementFrames {
            XCTAssertGreaterThanOrEqual(frame.minY, overlaySafeAreaInsets.top)
        }
    }

    // L2ï¼åºé¨æä½ä¸ç§çæ¨ªæ é½ä¸è¿å¥ä¸»å±å¹æç¤ºæ¡åºåã
    func testL2BottomOverlayFramesRespectHomeIndicator() {
        let snapshot = overlaySnapshot()
        let safeBottom = overlayPhysicalSize.height -
            overlaySafeAreaInsets.bottom

        XCTAssertEqual(snapshot.bottomElementFrames.count, 4)
        for frame in snapshot.bottomElementFrames {
            XCTAssertLessThanOrEqual(frame.maxY, safeBottom)
        }
    }

    // IC-075 G104ï¼é¡¶é¨ä¸å¸§äºä¸éå ãåå¨é¡¶é¨åºååï¼è¿åä¸ç¡®è®¤é¡µå¥å£ â¥ 44ptï¼
    // å¯ç¹å»å¸§å«å¸§ 0 ä¸å¸§ 2ãä¸å«åºå·å¸§ 1ã
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
                "é¡¶é¨åç´  \(index) åºè½å¨é¡¶é¨åºååï¼\(frame)"
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

    // L3ï¼è¿åãåºå·ä¸ç¡®è®¤é¡µå¥å£ä¸ä¸ªé¡¶é¨åç´ ä¹é´åä¿çé´è·ã
    func testL3TopOverlayFramesDoNotIntersect() {
        let frames = overlaySnapshot().topElementFrames

        for firstIndex in frames.indices {
            for secondIndex in frames.indices where secondIndex > firstIndex {
                XCTAssertFalse(
                    frames[firstIndex].intersects(frames[secondIndex]),
                    "é¡¶é¨åç´  \(firstIndex) ä¸ \(secondIndex) ä¸åºç¸äº¤"
                )
            }
        }
    }

    // L4ï¼äº§åæµ®å±ãæ¨ªæ ä¸åå°æ§å¶æ¡çå¨é¨è§¦æ§åºåè³å°ä¸º 44 ptã
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

    // L5ï¼ä¸¤ä¸ªåå°é¢æ¿åå«æå¼ãå³é­ååæ¶æå¼é½ä¸æ¹åè§å£ã
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

    // L6ï¼é¦æ¬¡å¯å¨æ é¢æ¿ãæ æ§å¶æ¡ï¼ä¹æ²¡æå æ®ä¸»çé¢çå¥å£å¸§ã
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

    // L7ï¼å®æ´åºåéç½®åå« IC-064 çæ¾éæ¶é¿ä¸æè¾¹å®æ¡ã
    func testL7FactoryDefaultsMatchSystemParityDecision() {
        let expected = S2CalibrationConfiguration(
            pinchMaxScaleFloor: 4,
            pinchMaxScaleCeiling: 10,
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
                "valueStatus=â£é¡¹ç®å¤æ­é»è®¤å¼ï¼å¯ä¿®è®¢"
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
        XCTAssertFalse(actual.exportText().contains("æªæ å®"))
    }

    // IC-067 C5ï¼é¢æ¿ç¶æè¡¨éä¸è¦çå¨é¨éç½®å­æ®µï¼ä¸ä¸ºæ­»åæ°è¡¥æ¥çäº§é»è¾ã
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
        XCTAssertEqual(statuses["edgePagingTriggerDistance"], .effective)
    }

    // IC-074 G96ï¼éç½®å­æ®µæ° 33 ä¸ªï¼å¯¼åº 37 è¡ï¼å« schemaVersion=2 ä¸ v15 è§æ ¼åºçº¿ã
    func testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export() {
        let fieldNames = Mirror(
            reflecting: S2CalibrationConfiguration.factoryPlaceholder
        ).children.compactMap(\.label)
        XCTAssertEqual(fieldNames.count, 37)

        let lines = S2CalibrationConfiguration.factoryPlaceholder
            .exportText()
            .split(separator: "\n")
            .map(String.init)
        XCTAssertEqual(lines.count, 37 + 4)
        XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 2)
        XCTAssertTrue(lines.contains("schemaVersion=2"))
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
        // å¯¼åºè¡ = 4 ä¸ªå¤´é¨é® + 33 ä¸ªå­æ®µï¼æ²¡æä»»ä½åºæ­¢åæ°æ®çã
        XCTAssertEqual(exportedNames.count, fieldNames.count + 4)
    }

    // IC-074 G97ï¼ç»è®°è¡¨ 33 æ¡ãåç¶æï¼decided éåæ°ä¸º v15 ç¬¬åä¸èç¬¬ 1ã2 é¨åå·²å­å¨ç 16 é¡¹ã
    func testIC074G97ParameterRegistryDecidedSetMatchesV15() {
        let connections = S2CalibrationConfiguration.parameterConnections
        XCTAssertEqual(connections.count, 37)
        XCTAssertEqual(Set(connections.map(\.name)).count, 37)

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
        XCTAssertEqual(placeholder.count, 14)
        XCTAssertTrue(decided.isDisjoint(with: placeholder))
        XCTAssertFalse(placeholder.contains("pinchMaxScale"))
        XCTAssertEqual(
            S2CalibrationConfiguration.factoryPlaceholder.pinchMaxScaleFloor,
            4
        )
        XCTAssertEqual(
            S2CalibrationConfiguration.factoryPlaceholder.pinchMaxScaleCeiling,
            10
        )
        for connection in connections {
            XCTAssertFalse(connection.specStatus.title.isEmpty)
            XCTAssertFalse(connection.wiringStatus.title.isEmpty)
        }
    }

    // IC-077 G127ï¼åçåé¡µæ§å¶å¨å¤¹å· + èæ¬ååç­ç¥è®¡æ°ï¼é¡µçªå£æ S2View.mainPhoto è§åä¸ºå½åé¡µ Â±1ï¼ï¼
    // æåä¸­è¿ç»­ 10 æ¬¡ s åå 0 æ¬¡è¯·æ±ï¼æåç»æ 1 æ¬¡ï¼åå»å°è¾¾ç®æ åç 1 æ¬¡ï¼éåºä¸è¿å¥å 1ï¼ï¼
    // ç¿»é¡µåæ°è¿çªå£çä¸é¡µ 1 æ¬¡ãç¦»å¼çªå£çä¸é¡µæ§è¯·æ±è¢«åæ¶ãæä¸ºå½åé¡µçä¸é¡µä¸éå¤è¯·æ±ï¼
    // è§å£å°ºå¯¸ååå½åé¡µ 1 æ¬¡ã
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
        XCTAssertEqual(strategy.requestCount(for: current), 1, "åå§è¯·æ±ä¸æ¬¡")
        XCTAssertEqual(strategy.requestCount(for: "asset-1"), 1)
        XCTAssertEqual(strategy.requestCount(for: "asset-3"), 1)
        XCTAssertEqual(strategy.requestCount(for: "asset-4"), 0, "çªå£å¤ä¸è¯·æ±")
        let firstPageRequestID = strategy.requests.first { $0.assetID == "asset-1" }?.id
        XCTAssertNotNil(firstPageRequestID)

        // æåï¼è¿ç»­ s åå 0 æ¬¡è¯·æ±ã
        XCTAssertTrue(machine.beginPinch())
        for step in 1...10 {
            machine.reportNativeViewport(
                scale: 1 + CGFloat(step) * 0.1,
                viewportOffset: .zero
            )
            applyWindowedPages()
        }
        XCTAssertEqual(strategy.requestCount(for: current), 1, "æåä¸­ä¸å¾è¯·æ±")

        // æåç»æ 1 æ¬¡ã
        XCTAssertNotNil(machine.finishNativePinch(
            scale: 2,
            viewportOffset: .zero,
            accepted: true
        ))
        applyWindowedPages()
        XCTAssertEqual(strategy.requestCount(for: current), 2, "æåç»æè¯·æ±ä¸æ¬¡")

        // åå»éåº Nx å°è¾¾ s=1ï¼1 æ¬¡ï¼ååå»è¿å¥ç®æ åçï¼1 æ¬¡ã
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.zoomState, .oneX)
        applyWindowedPages()
        XCTAssertEqual(strategy.requestCount(for: current), 3, "åå»éåºè¯·æ±ä¸æ¬¡")
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.zoomState, .nX)
        applyWindowedPages()
        XCTAssertEqual(strategy.requestCount(for: current), 4, "åå»è¿å¥è¯·æ±ä¸æ¬¡")
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        applyWindowedPages()
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(strategy.requestCount(for: "asset-1"), 1, "ç¸é»é¡µä¸åå½±å")

        // ç¿»é¡µï¼æ°è¿çªå£ç asset-4 è¯·æ±ä¸æ¬¡ï¼ç¦»å¼çªå£ç asset-1 æ§è¯·æ±è¢«åæ¶ï¼å½åé¡µä¸éå¤è¯·æ±ã
        let beforePaging = strategy.requestCount
        XCTAssertTrue(machine.handleNativePageChange(to: 2))
        applyWindowedPages()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount(for: "asset-4"), 1, "ç¿»é¡µåæ°é¡µè¯·æ±ä¸æ¬¡")
        XCTAssertEqual(strategy.requestCount(for: "asset-3"), 1, "æä¸ºå½åé¡µä¸éå¤è¯·æ±")
        XCTAssertEqual(strategy.requestCount - beforePaging, 1, "ç¿»é¡µåªæ°å¢ä¸æ¬¡è¯·æ±")
        // IC-079 èµ·åé¡µæ§å¶å¨ä¿ç currentIndex Â± 2 åçé¡µï¼asset-1 å¨ç¿»å°ç´¢å¼ 2 æ¶ä»ä¿çï¼
        // åç¿»ä¸é¡µå°ç´¢å¼ 3 æç¦»å¼çªå£ï¼ç¦»å¼çªå£çé¡µæ§è¯·æ±è¢«åæ¶çè¯­ä¹ä¸åã
        XCTAssertFalse(
            strategy.cancelledIDs.contains(firstPageRequestID ?? PHInvalidImageRequestID),
            "ä»å¨ä¿çåå¾åçé¡µä¸åæ¶"
        )
        XCTAssertTrue(machine.handleNativePageChange(to: 3))
        applyWindowedPages()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount(for: "asset-5"), 1, "åç¿»é¡µåæ°é¡µè¯·æ±ä¸æ¬¡")
        XCTAssertEqual(strategy.requestCount(for: "asset-4"), 1, "æä¸ºå½åé¡µä¸éå¤è¯·æ±")
        XCTAssertTrue(
            strategy.cancelledIDs.contains(firstPageRequestID ?? PHInvalidImageRequestID),
            "ç¦»å¼çªå£çé¡µåºåæ¶æ§è¯·æ±"
        )

        // è§å£å°ºå¯¸ååï¼å½åé¡µè¯·æ±ä¸æ¬¡ã
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
            "è§å£å°ºå¯¸ååè¯·æ±ä¸æ¬¡"
        )
    }

    // IC-078 G132ï¼`pinchMaxScale` åå¼è§åæ­è¨è¡¨ï¼è§å£ 402Ã874 ptãdisplayScale 3ãF æå¨è§å£ aspectFitï¼ã
    func testIC078G132PinchMaxScaleRuleTable() throws {
        let viewport = CGSize(width: 402, height: 874)
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let parameters = try XCTUnwrap(configuration.resolvedParameters)
        XCTAssertEqual(parameters.pinchMaxScaleFloor, 4)
        XCTAssertEqual(parameters.pinchMaxScaleCeiling, 10)
        let table: [(CGSize, CGFloat)] = [
            (CGSize(width: 1_206, height: 2_622), 4),
            (CGSize(width: 4_032, height: 3_024), 4),
            (CGSize(width: 3_024, height: 4_032), 4),
            (CGSize(width: 8_000, height: 6_000), 6.63),
            (CGSize(width: 12_000, height: 9_000), 9.95),
            (CGSize(width: 16_000, height: 12_000), 10),
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
                ceiling: parameters.pinchMaxScaleCeiling
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
        // åºåå°ºå¯¸ä¸ºé¶ãåçéæ³æ¶å floorï¼ceiling < floor æ¶æ floor å°é¡¶ã
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: .zero,
                displayScale: 3,
                floor: 4,
                ceiling: 10
            ),
            4
        )
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: CGSize(width: 402, height: 301.5),
                displayScale: 0,
                floor: 4,
                ceiling: 10
            ),
            4
        )
        XCTAssertEqual(
            S2PinchMaxScaleRule.pinchMaxScale(
                assetPixelSize: CGSize(width: 8_000, height: 6_000),
                fitSize: CGSize(width: 402, height: 301.5),
                displayScale: 3,
                floor: 4,
                ceiling: 2
            ),
            4
        )
        // `zoomSnapBackThreshold â¤ pinchMaxScaleFloor` ä¸ `ceiling â¥ floor` æ ¡éªã
        var invalid = configuration
        invalid.zoomSnapBackThreshold = 4.5
        XCTAssertNil(invalid.resolvedParameters)
        invalid = configuration
        invalid.pinchMaxScaleCeiling = 3
        XCTAssertNil(invalid.resolvedParameters)
        // å¯¼åºä¸ç»è®°è¡¨ä¸åå«åä¸ `pinchMaxScale`ã
        let exported = configuration.exportText()
        XCTAssertFalse(exported.contains("pinchMaxScale="))
        XCTAssertTrue(exported.contains("pinchMaxScaleFloor=4"))
        XCTAssertTrue(exported.contains("pinchMaxScaleCeiling=10"))
        XCTAssertFalse(
            S2CalibrationConfiguration.parameterConnections.contains {
                $0.name == "pinchMaxScale"
            }
        )
    }

    // IC-078 G135ï¼å¤¹å·é©±å¨ï¼ï¼æ¯é¡µ maximumZoomScale æåèªèµäº§åå¼ï¼åç´ å°ºå¯¸åå°æ¶æ´æ°ä¸æ¬¡ï¼
    // contentOffset / contentSize / contentInset / ç§ç frame ä¸åï¼ç§çå ä½åå¥äºä»¶ 0 æ¡ã
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
        // åç´ å°ºå¯¸æªè§£æï¼æªç»è®°å ä½ï¼ï¼ä¸¤é¡µåä¸º floorã
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

        // åç´ å°ºå¯¸åå°ï¼asset-1 å°å¾ â floorï¼asset-2 å¤§å¾ â 1:1 åç´ åçã
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
            ceiling: 10
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

    // IC-079 G139ï¼åºæ¯ D éå¸§å­æ®µä¸ä¸ç±»æ°äºä»¶æ R1 æ¸åå­å¨ï¼å¯¼åºå¤´é¨å£°æ + çå®éæ ·è¡ + æ ·ä¾äºä»¶ï¼ã
    func testIC079G139FastPagingScenarioExportsWindowFieldsAndEvents() {
        XCTAssertEqual(S2OnDeviceTransitionScenario.fastPaging.exportTitle, "D å¿«éè¿ç»­ç¿»é¡µ")
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
        diagnostics.recordPagingContentOffsetWrite(offsetX: 320, animated: false, source: "æµè¯æ¥æº")
        diagnostics.recordNativePageChange(from: 1, to: 2, accepted: true)
        diagnostics.stop()
        diagnostics.export()

        let text = diagnostics.reportText
        XCTAssertTrue(text.contains("åºæ¯=D å¿«éè¿ç»­ç¿»é¡µ"))
        XCTAssertTrue(text.contains(
            "éå¸§å­æ®µ=time,animationKeys,modelFrame,presentationFrame," +
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
        XCTAssertTrue(text.contains("event=é¡µåå»º\tsource=S2NativePagerViewController.apply\tdetails=pageIndex=3ï¼asset=asset-4"))
        XCTAssertTrue(text.contains("event=é¡µç§»é¤\tsource=S2NativePagerViewController.apply\tdetails=pageIndex=0ï¼asset=asset-1"))
        XCTAssertTrue(text.contains("event=å¤å±setContentOffset\tsource=æµè¯æ¥æº\tdetails=x=320.000000ï¼animated=false"))
        XCTAssertTrue(text.contains("event=handleNativePageChange\tsource=S2NativePagerViewController.finishNativePaging\tdetails=from=1ï¼to=2ï¼accepted=true"))

        // å³é­å½å¶æ¶é¶å¯ä½ç¨ï¼è®°å½æ°ä¸åã
        let countAfterStop = diagnostics.recordedEntries.count
        diagnostics.recordPageLifecycle(created: true, pageIndex: 9, assetLocalIdentifier: "x")
        diagnostics.recordPagingContentOffsetWrite(offsetX: 1, animated: true, source: "x")
        diagnostics.recordNativePageChange(from: 0, to: 1, accepted: false)
        XCTAssertEqual(diagnostics.recordedEntries.count, countAfterStop)
    }

    // IC-079 G141ï¼å¤¹å·é©±å¨ï¼çæºæªè¦çï¼ï¼çäº§é¡µçªå£ + é¡µåå®¹æä¾èãè¿ç»­ä¸¤æ¬¡æ»å¨å° i+2ï¼
    // ç»è¿ i+1 ä¸å°è¾¾ i+2 æ¶é¡µæ§å¶å¨åå·²å­å¨ï¼æ»å¨æé´å¤å± setContentOffset(animated:false) åå¥ 0 æ¬¡ï¼
    // ç»ç®å currentIndex == i+2ãåé¡µ scale == 1ãV ä¸åï¼æåä¸é¡µåæ»æ è¶çé¡µåå»ºã
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
                    return name == "å¤å±setContentOffset" && details.hasSuffix("animated=false")
                }
                return false
            }.count
        }

        applyProductionWindow()
        let paging = controller.pagingScrollView
        let visibilityBefore = machine.interfaceVisibility
        XCTAssertEqual(controller.diagnosticPageIndicesPresent, [0, 1, 2])
        let writesBeforeScrolling = nonAnimatedOffsetWriteCount()

        // ç¬¬ä¸æ¬¡æ»å¨å° i+1 å¹¶æ»åï¼SwiftUI å°æªå·æ°æ¶ç«å³å¼å§ç¬¬äºæ¬¡æ»å¨ã
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
        XCTAssertNotNil(controller.pageControllers[2], "ç»è¿ i+1 æ¶é¡µå­å¨")
        XCTAssertNotNil(controller.pageControllers[3], "æ»å i+2 æ¶ç®æ é¡µå·²å­å¨")
        paging.setContentOffset(paging.contentOffsetForPage(at: 3), animated: false)
        XCTAssertNotNil(controller.pageControllers[3], "å°è¾¾ i+2 æ¶é¡µå­å¨")
        XCTAssertNotNil(controller.pageControllers[4], "i+2 çä¸ä¸é¡µå·²é¢åå­å¨")
        controller.scrollViewDidEndDecelerating(paging)

        XCTAssertEqual(
            nonAnimatedOffsetWriteCount() - writesBeforeScrolling,
            0,
            "æ»å¨æé´ä¸å¾æéå¨ç»åç§»åå¥"
        )
        XCTAssertEqual(machine.currentIndex, 3)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.interfaceVisibility, visibilityBefore)
        XCTAssertEqual(paging.contentOffset, paging.contentOffsetForPage(at: 3))
        for (_, pageController) in controller.pageControllers {
            XCTAssertEqual(pageController.zoomScrollView.zoomScale, 1, accuracy: 0.000_001)
        }

        // SwiftUI å·æ°ï¼çªå£ 2â¦4 ä¿çï¼æéåå»ºçé¡µå¨ä¿çåå¾åä¸è¢«ç§»é¤ã
        applyProductionWindow()
        XCTAssertEqual(controller.diagnosticPageIndicesPresent, [1, 2, 3, 4, 5].filter {
            controller.pageControllers[$0] != nil
        })
        XCTAssertNotNil(controller.pageControllers[2])
        XCTAssertNotNil(controller.pageControllers[3])
        XCTAssertNotNil(controller.pageControllers[4])
        XCTAssertNil(controller.pageControllers[0], "è¶åºä¿çåå¾çé¡µè¢«ç§»é¤")
        XCTAssertEqual(paging.contentOffset, paging.contentOffsetForPage(at: 3))

        // åºåè¾¹çï¼æåä¸é¡µåæ»ï¼æ è¶çé¡µåå»ºã
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

    // IC-079 R1 å¤¹å·æ¢éï¼ä»æå°ï¼ä¸åæ­è¨ï¼ï¼çäº§é¡µçªå£ï¼å½åé¡µ Â±1ï¼ä¸ï¼ç¬¬ä¸é¡µæ»ååã
    // SwiftUI å·æ°ï¼éæ° applyï¼åç«å³å¼å§ç¬¬äºæ¬¡æ»å¨å° i+2ï¼éæ­¥æå° pageIndicesPresent ä¸ contentOffsetã
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
            print("[IC-079 æ¢é] \(step)ï¼currentIndex=\(machine.currentIndex) settledIndex=\(controller.settledIndex) contentOffsetX=\(paging.contentOffset.x) åç§»æå¨é¡µ=\(target) pageIndicesPresent=\(controller.diagnosticPageIndicesPresent) ç®æ é¡µå­å¨=\(controller.pageControllers[target] != nil)")
        }

        applyProductionWindow()
        dump("0 åå§ï¼çªå£ iÂ±1ï¼")
        // ç¬¬ä¸æ¬¡æ»å¨ï¼å° i+1 å¹¶æ»åï¼åçåéç»æåè°ï¼ã
        paging.setContentOffset(paging.contentOffsetForPage(at: 2), animated: false)
        dump("1 ç¬¬ä¸æ¬¡æ»å¨å° i+1ï¼æ»ååï¼")
        controller.scrollViewDidEndDecelerating(paging)
        dump("2 ç¬¬ä¸æ¬¡æ»åï¼finishNativePaging åï¼SwiftUI å°æªå·æ°ï¼")
        // ç¬¬äºæ¬¡æ»å¨å¨ SwiftUI å·æ°åç«å³å¼å§ï¼ç®æ  i+2ã
        paging.setContentOffset(paging.contentOffsetForPage(at: 3), animated: false)
        dump("3 ç¬¬äºæ¬¡æ»å¨å° i+2ï¼å·æ°åï¼")
        controller.scrollViewDidEndDecelerating(paging)
        dump("4 ç¬¬äºæ¬¡æ»åï¼finishNativePaging åï¼")
        applyProductionWindow()
        dump("5 SwiftUI å·æ°ï¼éæ° apply çªå£ï¼å")
        // è¾¹çï¼æåä¸é¡µåæ»ã
        _ = machine.handleNativePageChange(to: 5)
        applyProductionWindow()
        paging.setContentOffset(CGPoint(x: paging.contentOffsetForPage(at: 5).x + 80, y: 0), animated: false)
        dump("6 æåä¸é¡µåæ» 80ptï¼è¶çï¼")
        controller.scrollViewDidEndDecelerating(paging)
        dump("7 è¶çæ»å")

        diagnostics.stop()
        diagnostics.export()
        for line in diagnostics.reportText.split(separator: "\n")
        where line.contains("kind=event") &&
            (line.contains("å¤å±setContentOffset") || line.contains("é¡µåå»º") ||
                line.contains("é¡µç§»é¤") || line.contains("handleNativePageChange")) {
            print("[IC-079 æ¢éäºä»¶] \(line)")
        }
    }

    // P1 æ¿ä»£æ­è¨ï¼Nx å¹³ç§»ç±åçæ»å¨å®¹å¨æ¥ç®¡å¹¶äº§çéé¶ contentOffsetã
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

    // P2 æ¿ä»£æ­è¨ï¼è¾¹ç¼ç®æ äº¤ç» UIScrollView åç±å¶åçè¾¹çé³å¶ã
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

    // P3 æ¿ä»£æ­è¨ï¼1x æ¶åå±åçå¹³ç§»å³é­ï¼æå¿äº¤ç»å¤å±åé¡µæç«æ»è¯­ä¹ã
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

    // R1 æ¿ä»£æ­è¨ï¼åçæåä¸æ¥æé´è¯·æ±åçä¸åï¼ç»æååªåä¸æ¬¡è¯·æ±ä¿¡å·ã
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

    // R2ï¼IC-077 æ¹åï¼ï¼åºå degradedPreviewPolicy=.displayï¼éè´¨é¢è§è¿å¥æ¾ç¤ºåºåå¹¶ç±æç»å¾åä½æ¿æ¢ã
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

    // T1 æ¿ä»£æ­è¨ï¼åç contentOffset ä»¤å½åé¡µä¸ç¸é»é¡µç­éãååãåè°è·æã
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

    // T2 æ¿ä»£æ­è¨ï¼åçåé¡µå·²å¯ç¨ï¼æªè·¨åé¡µçè½ç¹ä»æ¥åå½ååé¡µååã
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

    // T3 æ¿ä»£æ­è¨ï¼åé¡µååå°ºå¯¸åºå®ï¼åçè½é¡µä¸æ¥åç¼©æ¾å½ä¸ã
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

    // D1 åæ¹åï¼æªå¾ææ°åºåå¼ç­æ¯ééå° 0.70 è§å£æ¡ã
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

    // D2ï¼åç¼©æ¯ä¾ä¸ºé¶æ¶ï¼1x æ¾ç¤ºä¸¥æ ¼ç­äºçº¯ç­æ¯ééã
    func testD2ZeroFitInsetMatchesPureAspectFit() {
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.fitInsetRatio = 0
        let value = metrics(configuration: configuration)

        XCTAssertEqual(value.oneXDisplaySize, value.aspectFitSize)
    }

    // D3 æ¹åï¼å³ä½¿æ§ä½ç¨èå´ä¸ºå¨é¨ç§çï¼éæªå¾ç 1x æ¾ç¤ºä»ä¸åã
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

    // D4 æ¿ä»£æ­è¨ï¼å±å¹æ¯ä¾ç§ççåçç®æ ç©å½¢éç¨æå°ç®æ åæ° 2ã
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

    // D5 æ¿ä»£æ­è¨ï¼éå±å¹æ¯ä¾ç§çåªéç¨å¡«æ»¡åæ°ï¼ä¸åä¸æå°åæ°åå¤§ã
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

    // D6 æ¿ä»£æ­è¨ï¼å·¦è¾¹ç¼åå»äº¤ç»åç zoom åï¼åå®¹å·¦è¾¹çè´´é½è§å£ã
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

    // D7 æ¿ä»£æ­è¨ï¼å³ãä¸ãä¸è¾¹ç¼åå»åç±åçè¾¹çé³å¶è´´é½è§å£ã
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

    // D8 æ¿ä»£æ­è¨ï¼åçåå»éåº Nx å scrollView ä¸ç¶ææºåæ¶å½ä¸ã
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

    // E1 åæ¿ä»£æ­è¨ï¼UIKit å®£ååå»å¤±è´¥åï¼åå»åè°æåæ¢æ¾éã
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

    // E2 åæ¿ä»£æ­è¨ï¼åå»è¯å«æåæ¶ä¸äº§çåå»æ¾éå¨ä½ã
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

    // E3 åæ¿ä»£æ­è¨ï¼ä¸¤æ¬¡åå«è¢« UIKit è£å³çåå»åçæä¸æ¬¡ã
    func testE3ReplacementTwoResolvedSingleTapsToggleTwice() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.scale, 1)
    }

    // E4 åæ¿ä»£æ­è¨ï¼åçåå»åè°ä¸ç´æ¥åå»å¥å£ç»æå®å¨ä¸è´ã
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

    // E5ï¼è¯»æ°æ¨¡ååæ¶æ´é²ç§çãè§å£å®½é«æ¯åå®éåå»ç®æ åæ°ã
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

    // E6ï¼æå¼å®æ¶è¯»æ°æ¶å³é­é¿åæ°é¢æ¿ï¼é¿åè¯»æ°è¢«æ¤åºå¯è§åºåã
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

    // N1ï¼ä¸»å¾ä½¿ç¨åçå¯ç¼©æ¾å®¹å¨ï¼åçä¸ä¸éåå«ä¸º 1 ä¸ pinchMaxScaleFloorï¼IC-078ï¼åç´ å°ºå¯¸æªè§£ææ¶çå¼ï¼ã
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

    // N2 æ¿ä»£æ­è¨ï¼åå»è°ç¨åç zoom(to:)ï¼ç®æ ç©å½¢éç¨åç±»åçç®æ åæ°ã
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

    // N3ï¼åçåé¡µå·²å¼å¯ï¼ç¸é»åé¡µååé´è·ç­äº pageSpacingã
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

    // N4ï¼pageSpacing åºåå¼ä¸åæ°å¯¼åºåä¸º 20ã
    func testN4PageSpacingFactoryDefaultIsTwentyPoints() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder

        XCTAssertEqual(configuration.pageSpacing, 20)
        XCTAssertTrue(
            configuration.exportText().contains("pageSpacing=20.000000")
        )
    }

    // N5ï¼Nx åå»åªåæ¢æ¾éï¼ä¸æ¹ååçæç¶ææºè§å£ã
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

    // N6ï¼1x åå»ç»§ç»­åæ¢çé¢æ¾éã
    func testN6OneXSingleTapTogglesInterfaceVisibility() {
        let machine = makeMachine(scale: 1)

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
    }

    // N7ï¼åçåé¡µè½å°æ°ç§çæ¶ï¼ç¶ææºç¼©æ¾ä¸åç§»å½ä¸ã
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

    // N8ï¼åçæåè¿ç¨ä¸­ä¸è¯·æ±ï¼ç»æååªååºä¸æ¬¡è¯·æ±ä¿®è®¢ã
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

    // IC-063ï¼åçåºååæ¢å¸å±å°ºå¯¸æ¶ï¼ä¸ææåå¼å§è¯¯æ¥ä¸ºå¾çè§å£ååã
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

    // G1ï¼1x ä¸æ»è¾¾å°æ¢æéå¼åæ è®°è§¦æ¸å¼å§æ¶çå½åèµäº§ã
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

    // G2 æ¿ä»£æ­è¨ï¼Nx ç«åæ»å¨ç±åçå¹³ç§»æ¥ç®¡ï¼ä¸è¿å¥æ è®°è¯å«å¨ã
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

    // G9ï¼Nx ä¸æ»ä¸å¾æ¹åå¾å éå D æå½ååºå· cã
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

    // G10ï¼Nx ä¸æ»ä¸å¾æ¹åå¾å éå D æå½ååºå· cã
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

    // G11ï¼Nx ç«åæå¨ç± UIScrollView æ¹å y åç§»ï¼ä¸ç»æçå¨åå®¹è¾¹çåã
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

    // G12ï¼æåå¸éåä¸¥æ ¼ 1x åï¼ç«åæ è®°è¯­ä¹ç«å³æ¢å¤ã
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

    // IC-063 G1 æ¹åï¼éèæçå±å¹æ¯ä¾æªå¾ç­æ¯ééç©çå±å¹ã
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

    // IC-063 G2 æ¹åï¼è£åæªå¾å¨æ¾ç¤ºæç­æ¯åç¼©ä¸åè¾¹å±ä¸­ã
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

    // IC-063 G3 æ¹åï¼åå»ä»æå±å¹æ¯ä¾åç±»ï¼ä¸åæªå¾åæ°æ®æ§å¶ã
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

    // IC-063 G4ï¼åå»ä¸¤åå¨ç»åä¿æåçåçä¸å¨ï¼ç»ç¹åæ­¥å¸§è§è§ç¸ç­ã
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
            "è¿å¥åæ­¥å=\(entrySynchronization.beforeWindowFrame)ï¼" +
                "åæ­¥å=\(entrySynchronization.afterWindowFrame)"
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
                "è¿åº¦=\(progress)ï¼è¿å¥å¸§=\(reading.beforeWindowFrame)ï¼" +
                    "éåºååå¸§=\(reading.afterWindowFrame)"
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

    // IC-063 G5ï¼Nx åæ¢ V ä¸æ¹åä»»ä½åçå ä½éæåè§ã
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

    // IC-063 G6ï¼Nx å»¶è¿æ¾éç®æ å¨éåºæ¶åªæäº¤ä¸æ¬¡ã
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

    // IC-063 G7ï¼åå¤æ»å¨è§å¾è¿è¡æ¶åæç¡®å³é­å®å¨åºèªå¨ insetã
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

    // IC-063 G8ï¼æ°æ§å ä½å¥çº¦å±ç¨åä¸æµè¯é¶ï¼ä¸ä»¥æ¿ä»£ç¶ææºè§é¿åå½ã
    func testIC063G8NativePagerStillUsesOriginalStateMachineInstance() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(controller.diagnosticMachine?.currentAssetID, machine.currentAssetID)
    }

    // åç½®è¯æ­ï¼èªå¨å®æå«ç±»æ¶æºéæ ·å¹¶è¾åºå¯å¤å¶æ¥åã
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
            "è¯æ­åè°å¨åºå¨æéåæè½½å¹¶å¼å§å¯¼åº"
        )
        let deadline = Date(timeIntervalSinceNow: 10)
        while diagnostics.isExporting, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        let report = diagnostics.reportText
        XCTAssertFalse(diagnostics.isExporting)
        XCTAssertTrue(report.contains("ä¸­é´å¸§é¨ç¦ï¼éè¿"))
        XCTAssertTrue(report.contains("V=æ¾ç¤ºãs=1 ç¨³å®æ"))
        XCTAssertTrue(report.contains("åå»å V=éèãs=1 ç¨³å®æ"))
        XCTAssertTrue(report.contains("åå»è¿å¥ Nxï¼å¨ç»ç»æç¨³å®æ"))
        XCTAssertTrue(report.contains("åå»éåº Nxï¼å¨ç»ç»æç¨³å®æ"))
        XCTAssertGreaterThanOrEqual(
            report.components(separatedBy: "åå»è¿å¥ Nxï¼å¨ç»ä¸­é´å¸§").count - 1,
            3
        )
        XCTAssertGreaterThanOrEqual(
            report.components(separatedBy: "åå»éåº Nxï¼å¨ç»ä¸­é´å¸§").count - 1,
            5
        )
        XCTAssertTrue(report.contains("Q1ï¼"))
        XCTAssertTrue(report.contains("Q2ï¼"))
        XCTAssertTrue(report.contains("Q3ï¼"))
        XCTAssertTrue(report.contains("Q4ï¼"))
        XCTAssertTrue(report.contains(
            "Q1ï¼é¡¶é¨ç©ºç½ 0.000000pxï¼contentInset=0.000000pxï¼" +
                "safeAreaInsets=0.000000pxï¼aspectFit=0.000000pxï¼" +
                "å å=0.000000pxã"
        ))
        XCTAssertTrue(report.contains(
            "Q2ï¼s>1 å¨é¨æ ·æ¬åå± transform æç­=true"
        ))
        XCTAssertTrue(report.contains("ç¨³å® Nx zoomScale=2.000000"))
        XCTAssertTrue(report.contains("è¿å¥å¨ç»åç zoomScale æå®=true"))
        XCTAssertTrue(report.contains("éåºå¨ç»åç zoomScale æå®=true"))
        XCTAssertTrue(report.contains(
            "zoomScale ä¸åå± transform åæ¶éé»è®¤=false"
        ))
        XCTAssertTrue(report.contains(
            "å¨ç»å¸§åå± transform æç­=true"
        ))
        XCTAssertTrue(report.contains(
            "ä¸ç¨è¿æ¸¡å± transform å¨é¨å­åç»åéåè°=true"
        ))
        XCTAssertTrue(report.contains("å¨ç»å¸§ contentOffset æ è·³å=true"))
        XCTAssertTrue(report.contains(
            "Q4ï¼V=æ¾ç¤ºæ¶ç¶ææ éè=falseï¼" +
                "V=éèæ¶ç¶ææ éè=trueã"
        ))
        print("IC063_DIAGNOSTICS_SAMPLE_BEGIN\n\(report)\nIC063_DIAGNOSTICS_SAMPLE_END")
    }

    // G3 æ¿ä»£æ­è¨ï¼åçåå»ä¸æ§è¡ä¹ä¸æ¤éä»»ä½åå»æ¾éå¨ä½ã
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

    // G4 æ¿ä»£æ­è¨ï¼ä¸¤æ¬¡ç± UIKit åå«è£å³çåå»åæ¢ä¸¤æ¬¡ä¸ä¸æ¹åçã
    func testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom() {
        let machine = makeMachine()
        let controller = makeNativePagerController(machine: machine)
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertTrue(page.applyRecognizedSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.scale, 1)
    }

    // M1ï¼å½ä¸­å±å¹æ¯ä¾åç¼©å¤å®æ¶ï¼åå»åªéç¨æå°ç®æ åæ°ã
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

    // M2ï¼æªå½ä¸­å±å¹æ¯ä¾å¤å®æ¶ï¼åå»åªéç¨å¡«æ»¡è§å£åæ°ã
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

    // F1ï¼0.30 åç¼©ä»¤å±å¹æ¯ä¾ç§çç 1x ç­è¾¹ç­äºè§å£ç­è¾¹ç 0.70ã
    func testF1FactoryInsetShrinksShortEdgeToSeventyPercent() {
        let value = metrics()

        XCTAssertEqual(
            min(value.oneXDisplaySize.width, value.oneXDisplaySize.height),
            min(value.viewportSize.width, value.viewportSize.height) * 0.70,
            accuracy: 1
        )
    }

    // F2 æ¹åï¼åè§ä»éæªå¾åæ°æ®çæï¼æ®éç§çä¸¥æ ¼ä¸ºé¶ã
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

    // F3 æ¿ä»£æ­è¨ï¼éæ¡æ¾ç§çå¨çé¢æ¾éååçå°ºå¯¸ä¸åè§å®å¨ä¸è´ã
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

    // F4ï¼åç¼©åªæ¹å 1x æ¾ç¤ºå°ºå¯¸ï¼ä¸æ¹åè§å£æå¡«æ»¡åæ°åºåã
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

    // IC-082 G152ï¼åºæ¯ E `nxEdgePaging` éå¸§è¿½å ä¸ä¸ªå­æ®µãä¸ç±»äºä»¶éæ¡å­å¨ï¼å³é­å½å¶é¶å¯ä½ç¨ã
    func testIC082G152NxEdgePagingScenarioExportsFieldsAndEvents() {
        XCTAssertEqual(S2OnDeviceTransitionScenario.nxEdgePaging.exportTitle, "E Nx è´´è¾¹ç¿»é¡µ")
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
        let interaction = S2NxEdgePagingInteraction(
            restingPagingOffsetX: 320,
            pageStride: 320,
            translationOriginX: 0,
            distanceToPreviousBoundary: 20,
            distanceToNextBoundary: 0
        )
        diagnostics.recordNXEdgePagingBegin(interaction)
        diagnostics.recordHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: 60,
            velocity: 300,
            accepted: true
        )
        diagnostics.recordSynchronizeNativeState(
            animatedPaging: true,
            currentIndex: 2,
            scale: 1
        )
        diagnostics.stop()
        diagnostics.export()

        let text = diagnostics.reportText
        XCTAssertTrue(text.contains("åºæ¯=E Nx è´´è¾¹ç¿»é¡µ"))
        XCTAssertTrue(text.contains(
            "éå¸§å­æ®µ=time,animationKeys,modelFrame,presentationFrame," +
                "transform,zoomScale,contentOffset,contentSize," +
                "contentInset,adjustedContentInset,V,s," +
                "pagingContentOffsetX,pagingIsDragging,pagingIsDecelerating," +
                "currentIndex,settledIndex,pageIndicesPresent,pageLoadStates," +
                "nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance"
        ))
        // éè´´è¾¹æå¨æé´ä¸ä¸ªå­æ®µä¸º nilï¼åå± contentOffset / contentSize / zoomScale ä¸å¤å±åç§»æ¢æå­æ®µåå¨ã
        XCTAssertTrue(text.contains("\tnxDistanceToPreviousBoundary=nil\tnxDistanceToNextBoundary=nil\tnxOverflowDistance=nil"))
        XCTAssertTrue(text.contains("\tzoomScale=1.000000\tcontentOffset="))
        XCTAssertTrue(text.contains("\tcontentSize="))
        XCTAssertTrue(text.contains("\tpagingContentOffsetX="))
        XCTAssertTrue(text.contains("\tpagingIsDragging=false\tpagingIsDecelerating=false"))
        XCTAssertTrue(text.contains("\tcurrentIndex=1"))
        XCTAssertTrue(text.contains(
            "event=beginNXEdgePaging\tsource=S2NativePagerViewController.beginNXEdgePaging" +
                "\tdetails=restingPagingOffsetX=320.000000ï¼distanceToPreviousBoundary=20.000000ï¼distanceToNextBoundary=0.000000"
        ))
        XCTAssertTrue(text.contains(
            "event=handleHorizontalSwipe\tsource=S2NativePagerViewController.finishNXEdgePaging" +
                "\tdetails=direction=nextï¼startedAtPagingEdge=trueï¼distance=60.000000ï¼velocity=300.000000ï¼accepted=true"
        ))
        XCTAssertTrue(text.contains(
            "event=synchronizeNativeStateToMachine\tsource=S2NativePagerViewController.synchronizeNativeStateToMachine" +
                "\tdetails=animatedPaging=trueï¼currentIndex=2ï¼s=1.000000"
        ))

        let countAfterStop = diagnostics.recordedEntries.count
        diagnostics.recordNXEdgePagingBegin(interaction)
        diagnostics.recordHorizontalSwipe(direction: .next, startedAtPagingEdge: false, distance: 0, velocity: 0, accepted: false)
        diagnostics.recordSynchronizeNativeState(animatedPaging: false, currentIndex: 1, scale: 1)
        diagnostics.captureFrame()
        XCTAssertEqual(diagnostics.recordedEntries.count, countAfterStop)
    }

    // IC-082 G153（R2）：贴边起始由拖动开始时的边界距离判定。
    // 起始不贴边（20pt）+ 溢出 60pt + 阈值速度 → 不翻页；起始贴边 + 同样溢出 → 翻页；
    // 起始贴边 + 溢出 39pt → 不翻页。
    func testIC082G153NxEdgePagingRequiresEdgeAtDragStart() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let velocity = CGFloat(configuration.edgePagingTriggerVelocity)

        let offEdge = S2NxEdgePagingInteraction(
            restingPagingOffsetX: 320,
            pageStride: 320,
            translationOriginX: 0,
            distanceToPreviousBoundary: 0,
            distanceToNextBoundary: 20
        )
        XCTAssertFalse(offEdge.startedAtPagingEdge(for: .next))
        XCTAssertTrue(offEdge.startedAtPagingEdge(for: .previous))
        let offEdgeProjection = offEdge.projection(translationX: -80)
        XCTAssertEqual(offEdgeProjection.direction, .next)
        XCTAssertEqual(offEdgeProjection.overflowDistance, 60)
        let offEdgeMachine = makeMachine(scale: 2, configuration: configuration)
        XCTAssertFalse(offEdgeMachine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: offEdge.startedAtPagingEdge(for: .next),
            distance: offEdgeProjection.overflowDistance,
            velocity: velocity
        ))
        XCTAssertEqual(offEdgeMachine.currentIndex, 1)
        XCTAssertEqual(offEdgeMachine.scale, 2)

        let atEdge = S2NxEdgePagingInteraction(
            restingPagingOffsetX: 320,
            pageStride: 320,
            translationOriginX: 0,
            distanceToPreviousBoundary: 120,
            distanceToNextBoundary: 0.4
        )
        XCTAssertTrue(atEdge.startedAtPagingEdge(for: .next))
        XCTAssertFalse(atEdge.startedAtPagingEdge(for: .previous))
        let atEdgeProjection = atEdge.projection(translationX: -60.4)
        XCTAssertEqual(atEdgeProjection.overflowDistance, 60, accuracy: 0.000_001)
        let atEdgeMachine = makeMachine(scale: 2, configuration: configuration)
        XCTAssertTrue(atEdgeMachine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: atEdge.startedAtPagingEdge(for: .next),
            distance: atEdgeProjection.overflowDistance,
            velocity: velocity
        ))
        XCTAssertEqual(atEdgeMachine.currentIndex, 2)
        XCTAssertEqual(atEdgeMachine.scale, 1)

        let shortProjection = atEdge.projection(translationX: -39.4)
        XCTAssertEqual(shortProjection.overflowDistance, 39, accuracy: 0.000_001)
        let shortMachine = makeMachine(scale: 2, configuration: configuration)
        XCTAssertFalse(shortMachine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: atEdge.startedAtPagingEdge(for: .next),
            distance: shortProjection.overflowDistance,
            velocity: velocity
        ))
        XCTAssertEqual(shortMachine.currentIndex, 1)
        XCTAssertEqual(shortMachine.scale, 2)
    }

    // IC-082 R1 å¤¹å·æ¢éï¼ä»æå°ï¼ä¸åæ­è¨ï¼ï¼ä¸¤æ¡åºåä¸æ§å¤å®ï¼æº¢åº > 0ï¼ä¸æ°å¤å®ï¼èµ·å§è·ç¦» â¤ 0.5ï¼
    // åèªç»åºç startedAtPagingEdge ä¸ç¿»é¡µç»æã
    func testIC082R1NxEdgePagingStartConditionProbe() {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let velocity = CGFloat(configuration.edgePagingTriggerVelocity)
        let sequences: [(String, CGFloat)] = [
            ("èµ·å§è·è¾¹ç 20ptãæå¨æº¢åº 60pt æ¾æ", 20),
            ("èµ·å§è´´è¾¹ãæº¢åº 60pt æ¾æ", 0)
        ]
        for (title, distanceToNext) in sequences {
            let interaction = S2NxEdgePagingInteraction(
                restingPagingOffsetX: 320,
                pageStride: 320,
                translationOriginX: 0,
                distanceToPreviousBoundary: 0,
                distanceToNextBoundary: distanceToNext
            )
            let projection = interaction.projection(translationX: -(60 + distanceToNext))
            let legacyStarted = projection.overflowDistance > 0
            let started = interaction.startedAtPagingEdge(for: .next)
            let legacyMachine = makeMachine(scale: 2, configuration: configuration)
            let legacyResult = legacyMachine.handleHorizontalSwipe(
                direction: .next,
                startedAtPagingEdge: legacyStarted,
                distance: projection.overflowDistance,
                velocity: velocity
            )
            let machine = makeMachine(scale: 2, configuration: configuration)
            let result = machine.handleHorizontalSwipe(
                direction: .next,
                startedAtPagingEdge: started,
                distance: projection.overflowDistance,
                velocity: velocity
            )
            print(
                "[IC-082 æ¢é] \(title)ï¼overflow=\(projection.overflowDistance) " +
                    "æ§å¤å® startedAtPagingEdge=\(legacyStarted) ç¿»é¡µ=\(legacyResult) currentIndex=\(legacyMachine.currentIndex)ï¼" +
                    "æ°å¤å® startedAtPagingEdge=\(started) ç¿»é¡µ=\(result) currentIndex=\(machine.currentIndex)"
            )
        }
    }

    // B1ï¼Nx åå®¹å°è¾¹çåï¼ç»§ç»­æå¨çæº¢åºéç­éå¸¦å¨å¤å±åé¡µã
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

    // B2ï¼Nx è¾¹çç¿»é¡µæªåæ¶è¾¾å°è·ç¦»ä¸éåº¦éå¼æ¶åå¼¹ä¸ c ä¸åã
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

    // B3ï¼Nx è¾¹çç¿»é¡µå®æåï¼æ°ç§çåçä¸¥æ ¼å½ä¸ä¸º 1ã
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

    // H1 æ¿ä»£æ­è¨ï¼å¼å¯åæ°æ¶ä¹åªæç¼©ç¥å¾æå¨æ¢çååºè§¦è§ã
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

    // H2 æ¿ä»£æ­è¨ï¼å³é­åæ°åç¼©ç¥å¾ååä¹ä¸åè§¦è§ã
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

    // K1ï¼åå»è¯å«å¨æ¾å¼ç­å¾åå»è¯å«å¨å¤±è´¥ã
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

    // K2ï¼åå»å¨ç¨ä¸åæ¢æ¾éï¼æç»åçç­äºåç±»åçç®æ åæ°ã
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

    // K3ï¼UIKit å®£ååå»å¤±è´¥åï¼åå»åè°åªåæ¢ä¸æ¬¡æ¾éã
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

    // K4ï¼åå»è£å³è¯æ­ç®æ åºåå¼ä¸º 200 æ¯«ç§å¹¶å®éåä¸è¾¾æ å¤æ­ã
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

    // S1ï¼æ¡æ¾ç§çå¨æ¾ç¤ºæä½¿ç¨ 70% ç­è¾¹å 28 ç¹åè§ã
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

    // S2 æ¿ä»£æ­è¨ï¼æ¡æ¾ç§çéèåä¸¤è½´ä¸¥æ ¼å¡«æ»¡è§å£ä¸åè§å½é¶ã
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

    // S3ï¼éæ¡æ¾ç§çå¨æ¾ç¤ºæä¸éèæçå°ºå¯¸ååè§ä¸¥æ ¼ç¸ç­ã
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

    // S4ï¼æªå¾æ²æµ¸æ¾éä¸æ¹åè§å£ãå¡«æ»¡åæ°æåå»ç®æ åæ°ã
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

    // X1ï¼ç¼©æ¾åæ¢çå®ééç¹åºå®å¨ç©çè§å£ä¸­å¿ã
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

    // X2ï¼å¨ç»æé´ä¿çæºæ frame åºåï¼æ¾ç¤ºå±åªæ¿è½½ç»ç¹ç­æ¯ transformã
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

    // X3ï¼åè§ä¸ç¼©æ¾å±ç¨çº¿æ§è¿åº¦ï¼ä¸¤ä¸ªæ¹åçç«¯ç¹åä¸­ç¹è¿ç»­ã
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

    // X4ï¼å³é­å¨ç»åä¸ä¿çä»»ä½è¿æ¸¡æï¼ç®æ å ä½ä¸æ¬¡å°ä½ã
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

    // X5ï¼Nx æ¾éåæ¢ååäºé¡¹åçå ä½éåç§çå¯è§æ¡ä¸¥æ ¼ç¸ç­ã
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

    // X6ï¼Nx å»¶è¿ç®æ å¨å®éåå° 1x ååªæäº¤ä¸æ¬¡å¹¶è¾¾å°å½åæ¾éç«¯ç¹ã
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

    // X7ï¼Nx æªåæ¢æ¾éæ¶ï¼éåºåªæ§è¡æ¢æç¼©æ¾å½ä¸ï¼ä¸æ°å¢åç°æäº¤ã
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

    // X8ï¼è¿æ¸¡æªç»æåä¸æ¿æ¢ç§çåå®¹ï¼çå®å¾åè¯·æ±è®¡æ°ä¿æä¸ºé¶ã
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

    // Y1ï¼ç³»ç»ç¶ææ éçé¢éèæéèãéæ¾ç¤ºææ¢å¤ï¼å¹¶å±ç¨æ¾éæ¶é¿ã
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

    // Y2 æ¹åï¼æ¯ä¾åç¦»å±å¹çæªå¾å¨éèæç­æ¯ééå¨è§å£ä¸åè§ä¸ºé¶ã
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

    // Y3ï¼æªå½ä¸­ç§çå¨ä¸¤ç§çé¢ç¶æä¸çå°ºå¯¸ååè§åä¿æä¸åã
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

    // Y4 æ¿ä»£æ­è¨ï¼åå»éåºåªç±ä¸ç¨è¿æ¸¡å±é©±å¨ï¼åçåçå¨åæ­¥åä¸åã
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

    // Y5ï¼ä½äºå¸ééå¼çæåå½ä½ç»§ç»­ä½¿ç¨åç UIScrollView å¨ç»ã
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

    // Y6ï¼åçéåºå®æåå½ä¸åçä¸åç§»ï¼å¹¶æå½åéèææäº¤æ²æµ¸ç»ç¹ã
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

    // å¾åè¯·æ±åå½ï¼Nx æ æ¾éå ä½ååæ¶ï¼æåç»æè¯·æ±ä»ææ¢æç­ç¥æ§è¡ã
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

    // A1ï¼åçå·¦å³åé¡µæååæ¢ç§çæ¶è§¦è§è°ç¨æ¬¡æ°ä»ä¸ºé¶ã
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

    // A2ï¼ç¼©ç¥å¾æå¨æ¯è·¨è¿ä¸å¼ å½åé¡¹å°±æ°å¥½è§¦åä¸æ¬¡è§¦è§ã
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

    // A3ï¼å³é­è§¦è§åæ°åï¼ä»»ä½ç§çåæ¢æ¥æºé½ä¸ä¼è§¦åè§¦è§ã
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

    // å¨ç»åå½ï¼ç»ä¸ç­ç¥å¨å³é­å¼å³æ¶ææ¾å¼æ¶é¿å½é¶ã
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

    // IC-065 G26ï¼é«åº¦åéãçªäºè§å£çå®æ´ééç§çå¨ 1x æ°´å¹³å±ä¸­ã
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

    // IC-065 G27ï¼å®½åº¦åéãç®äºè§å£çå®æ´ééç§çå¨ 1x åç´å±ä¸­ã
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

    // IC-065 G28ï½G29ï¼60Hz presentation è½¨è¿¹å¨æ¥ç®¡é¦å¸§åå¨ç¨ä¿æå°å°ºå¯¸æ¹åå±ä¸­ã
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
                        "æ ·æ¬=\(name)ï¼åºå·=\(index)"
                    )
                }
                if frame.height < viewport.height - 0.5 {
                    XCTAssertEqual(
                        frame.midY,
                        viewport.midY,
                        accuracy: 0.5,
                        "æ ·æ¬=\(name)ï¼åºå·=\(index)"
                    )
                }
            }
        }
    }

    // IC-065 G30ï¼å¤§äºè§å£çæ¹ååªä½¿ç¨åçåå®¹è¾¹çï¼ä¸å¢å é¢å¤ä½éã
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

    // IC-065 G31 æ¹åï¼æªå¾åæ°æ®ç»§ç»­ä¿æ IC-063 G1ï½G2 çç­æ¯ä¸åç¼©ç»æã
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

    // IC-065 G32 æ¹åï¼C8 æ¿ä»£çº¿æ§åºååï¼ä¸¤æ¹åä»å±ç¨åä¸ springã
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

    // IC-065 G34ï¼æ ¡ååæ°ä¸­æ²¡æå¼å¥ä»»ä½æåéç¹å­æ®µã
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

    // IC-067 G36ï¼è£åæªå¾å¨æ¾ç¤ºæç­æ¯éé 0.70 è§å£æ¡ï¼éèæç­æ¯ééå¨è§å£ã
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

    // IC-067 G37ï¼æ®éç§çä¸¤ç§ V åä½¿ç¨å¨è§å£ç­æ¯ééï¼ä¸åå»ååå ä½ä¸åã
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

    // IC-064 G13ï½G18 æ¹åï¼æ¾ç¤ºå±ç«¯ç¹ä¸ CA å³é®å¸§æ»¡è¶³åå springã
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

    // IC-064 G19ï¼ä¸ç§ç³»ç»æ ·æ¬çå·¦å³æè¾¹åç´ åè½å¥ç®æ å®¹å·®ã
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

    // IC-064 G20ï¼1pt æè¾¹ä½äºç§çå±åï¼ä¸æ¹åç§çæ»å°ºå¯¸ã
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

    // IC-064 G21 æ¹åï¼Nx æè¾¹å½é¶ï¼spring è¿å²åè§è§çº¿å®½æ¶æã
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

    // IC-064 G22ï¼trait ææåæ¢åæè¾¹é¢è²åå°æ´æ°ï¼æ ééå»ºé¡µé¢ã
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

    // IC-067 G39ï¼åä¸ä¸ª S2 é¡µé¢é trait åå°åæ¢çº¯é»ä¸çº¯ç½èæ¯ã
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

    // IC-067 G40ï¼å¤¹å·é©±å¨ï¼ï¼æ¥ç®¡å ä½ä¸èçæ´æ°å¤äºåä¸ç¦å¨ç»äºå¡ã
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

    // IC-067 G41ï¼å¤¹å·é©±å¨ï¼ï¼ä¸¥æ ¼åå° 1x æ¶æ¢å¤å½å V çç®æ å ä½ã
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

    // IC-067 G42ï¼å¤¹å·é©±å¨ï¼ï¼åååæä¸­é´å¸§ï¼å¤å±åè°ä¸åè¦åç§çã
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

    // IC-067 G43ï¼å¤¹å·é©±å¨ï¼ï¼åè®¸é»å°¼èå´åè¿å²ä¸è¶è¿ 10%ï¼éåæ¶æã
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

    // IC-064 C7ï¼æ¾éå¨ç»ä½¿ç¨ç¬ç« 220ms åæ°ï¼ä¸æ¹å¨åå»ç 180ms åæ°ã
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

    // IC-068 G47ï¼å½å¶å³é­æ¶ä¸äº§çè®°å½ï¼ä¹ä¸æ¹åç»ä¸å¥å£çå ä½ç»æã
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

    // IC-068 G48ï¼ç»ä¸å¥å£ä¸æ¶æåçèµå¼é¡ºåºãframe å transform å®å¨ä¸è´ã
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

    // IC-068 G49ï¼å¯¼åºåè®®åå«å¨é¨éå¸§å­æ®µãç©ºå¨ç»é®åå¨é¨ç¦»æ£äºä»¶æã
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
            "SwiftUIç¶æåå¸",
            "updateUIView",
            "layoutSubviews",
            "viewDidLayoutSubviews",
            "ç§çå ä½åå¥",
            "ç§çå¨ç»è°ç¨:add(animation:)",
            "ç§çå¨ç»è°ç¨:removeAnimation",
            "ç§çå¨ç»è°ç¨:removeAllAnimations",
            "CATransactionæäº¤è¾¹ç",
            "æå¶å¤å±å¸å±åå¥çæ"
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
                    source: "æµè¯æ¥æº",
                    details: "key=æµè¯é®ï¼åå¥ç§çå ä½=true"
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
            "æ¶é=CACurrentMediaTime()",
            "éæ ·é¢çä¸éHz=60",
            "å½å¶ä¸éç§=5.000000",
            "animationKeys=[]",
            "modelFrame=",
            "presentationFrame=",
            "transform=(a=",
            "zoomScale=",
            "contentOffset=",
            "contentSize=",
            "V=éè",
            "s=1.000000",
            "source=æµè¯æ¥æº",
            "details=key=æµè¯é®"
        ]
        for field in requiredFields {
            XCTAssertTrue(text.contains(field), "ç¼ºå°å¯¼åºå­æ®µï¼\(field)")
        }
        for eventName in eventNames {
            XCTAssertTrue(text.contains("event=\(eventName)"))
        }
    }

    // IC-070 G79ï¼éå¸§å­æ®µå« contentInset ä¸ adjustedContentInsetï¼ä¸éèªçå®æ»å¨è§å¾ã
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
            "éå¸§å­æ®µ=time,animationKeys,modelFrame,presentationFrame," +
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

    // IC-070 R5 å®æµæ¢éï¼å¤¹å·é©±å¨ï¼ä¸åæ­è¨ï¼ï¼æå°æ¥ç®¡åæ­¥ç
    // inset/offset/contentSize ä¸å¯è§ä¸­å¿ï¼å¹¶æ¨¡æ UIKit å¨åä¸å¸§åå¥è¿æ offsetã
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

    // IC-070 R6 å®æµæ¢éï¼å¤¹å·é©±å¨ï¼ä¸åæ­è¨ï¼ï¼æ²¿åè§ 45Â° å¯¹è§çº¿ä¸ç´è¾¹æ«æ
    // åç´ ç°åº¦ï¼å¹¶æå°æè¾¹å±è¿è¡æ¶å±æ§ã
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

    // IC-070 G75/G76ï¼å¤¹å·é©±å¨ï¼çæºæªè¦çï¼ï¼æ¥ç®¡å¸§ä¸æ¥ç®¡åä¸å¸§å±ä¸­éä¸è´ï¼
    // æ¥ç®¡å¨è¿ç¨å«å¯¹ææ§çè¿æ offset åå¥ï¼inset+offset èåå±ä¸­éå¸§è¿ç»­ã
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
                let message = "æ ·æ¬=\(name)ï¼é¶æ®µ=\(phase)ï¼" +
                    "frame=\(frame)ï¼inset=\(inset)ï¼offset=\(offset)"
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
            // G76ï¼æ¥ç®¡å¸§ä¸æ¥ç®¡åä¸å¸§çå¯è§å±ä¸­éä¹å·® â¤ 0.5ptã
            XCTAssertEqual(takeover.midX, before.midX, accuracy: 0.5, name)
            XCTAssertEqual(takeover.midY, before.midY, accuracy: 0.5, name)
            assertCentered("takeover_sync")

            // å¯¹æï¼æ¨¡æ UIKit æåå¤çå¨åä¸å¸§ç¨è¿æ inset åå offset=0ï¼
            // èåå±ä¸­å¿é¡»å¨æ¬æ¬¡å¸å±æäº¤åæ¢å¤ã
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

    // IC-070 G77ï¼åè§ 45Â° å¯¹è§çº¿ç±å¤ååé¦ä¸ªéèæ¯åç´ ä¸ºæè¾¹åç´ ï¼
    // æè¾¹å¨ç´è¾¹ä¸åè§å¤çå¯è§å®½åº¦ä¹å·® â¤ 0.5ptãåå§æä¸éèâæ¾ç¤ºä¹ååéªä¸æ¬¡ã
    func testIC070G77FitBorderIsConcentricAtCornersBeforeAndAfterToggle() {
        // æµè¯ä¸ç¨ï¼ææµè²æè¾¹ alpha æå° 1 ä»¥åç¦»æè¾¹ä¸ç§çç°åº¦ï¼åºåå¼ä¸åã
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

    // IC-070 G78ï¼è¿æ¸¡æé´æè¾¹å±ä¸ç§çå±ä½¿ç¨åä¸ç»åè§å³é®å¸§ï¼éå¸§ä¹å·® â¤ 0.5ptï¼
    // è¿æ¸¡æ¶å£åä¸¤å±åæ æ®çå¨ç»ï¼æè¾¹å±åå¾ä¸çº¿å®½åå°å½åé¡µç®æ å¼ã
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
            XCTAssertEqual(pair.0, pair.1, accuracy: 0.5, "å³é®å¸§=\(index)")
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
                "é¶æ®µ=\(phase)ï¼è§=\(name)ï¼é¦ä¸ªéèæ¯åç´ ä¸æ¯æè¾¹",
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
            "é¶æ®µ=\(phase)ï¼ç´è¾¹æè¾¹å®½åº¦",
            file: file,
            line: line
        )
        for (index, width) in cornerWidths.enumerated() {
            XCTAssertEqual(
                width,
                edgeWidth,
                accuracy: 0.5,
                "é¶æ®µ=\(phase)ï¼è§åºå·=\(index)ï¼åè§ä¸ç´è¾¹å®½åº¦å·®",
                file: file,
                line: line
            )
        }
    }

    // IC-075 G108ï¼å¤¹å·é©±å¨ï¼ï¼æ¨ªæ å¾å æ è®°é D æ¾éï¼å°ºå¯¸è¯»èª bottomStripMarkSizeï¼
    // éæ­¢æä¸æ»å¨æä¸è´ã
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

    // IC-075 G107ï¼å¤¹å·é©±å¨ï¼ï¼ä¸»å¾æ è®°åªå¨ V=æ¾ç¤º â§ câD æ¸²æï¼èå²åªå¨ V=æ¾ç¤ºæ¶
    // æ¶è´¹ alreadyMarked è§¦åä¸æ¬¡ï¼V=éèæ¶éç¥ç§å¸¸æ¶è´¹ãä¸èå²ã
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

    // IC-075 G107 / é¸é¨ Aï¼å¤¹å·é©±å¨ï¼çæºæªè¦çï¼ï¼å®¿ä¸» S2View ä¸ï¼æ è®°æ¾ç¤ºä¸èå²
    // æé´ç§çå ä½åå¥ä¸º 0ï¼å·²æ è®°åä¸æ»åéç¥è¢«æ¶è´¹ä¸èå² +1ï¼éèæä¸èå²ã
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

    // IC-068 G50ï¼ç¸åæåéçæ¶éè¯»æ°ä»è¢«å½ä¸ä¸ºä¸¥æ ¼éå¢çç»ä¸äºä»¶æµã
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
            "é¡ºåº=å¨é¨è®°å½æåä¸åè°æ¶éä¸¥æ ¼éå¢"
        ))
    }

    // IC-069 G53ï¼ä¸»çº¿ç¨åæè¶è¿å¨ç»æ¶é¿æ¶ï¼æ¸²æå±ä»å°è¾¾ç»æã
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

    // IC-069 R1bï¼æ¾éåæ¢ä¸éå»ºç¼©ç¥æ¡ï¼å èä¸éå¤è¿å¥å¾çè¯·æ±è·¯å¾ã
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

    // IC-069 G54/G55ï¼åååä»¥æºæ frame ä¸ºåºåï¼é¦æ«å¸§ä¸¥æ ¼å½ä¸­ä¸¤ç«¯ã
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

    // IC-069 G56ï¼å·²è§£æèµäº§ä½¿ç¨çå®ééå°ºå¯¸ï¼æªç¥èµäº§ä¸åçæµå ä½ã
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

    // IC-069 G57ï¼æ è¾å¥çä¸ç§å¸å±çªå£åä¸éå¤åç§çå ä½ã
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

    // IC-069 G58ï¼å ä½åå¥ä¸åå¤å±å¸å±äºä»¶åå¯å®ä½å°é¡µé¢åèµäº§ã
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
            "ç§çå ä½åå¥",
            "layoutSubviews",
            "viewDidLayoutSubviews"
        ])
        let validContexts = Set(
            machine.orderedAssetIDs.enumerated().map {
                "pageIndex=\($0.offset)ï¼" +
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
                "è¯æ­äºä»¶ç¼ºå°å¹éçé¡µé¢ä¸èµäº§æ è¯ï¼\(details)"
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

    /// æ«æè¯»æ°ï¼é¦ä¸ªéèæ¯æ ·æ¬ç°åº¦ï¼ä»¥åç§çåºåä¹åçæè¾¹è¦çéï¼æ ·æ¬æ°ï¼ã
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
            XCTFail("æªå¾ç¼ºå°åç´ æ°æ®")
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
            XCTFail("æ æ³è£åæè¾¹åç´ ")
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
            XCTFail("æ æ³åå»ºåç´ åæ ·ä¸ä¸æ")
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
                    displayName: "æµè¯èå´",
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
            XCTFail("é¢æå¼ä¸åºä¸ºç©º", file: file, line: line)
            fatalError("æµè¯æ æ³ç»§ç»­")
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
