import SwiftUI
import UIKit

struct S2NativePhotoContentVersion: Equatable {
    let requestedScale: CGFloat
    let requestStrategy: S2ImageRequestStrategy?
    let requestRevision: Int
}

struct S2NativePageContent {
    let index: Int
    let assetID: String
    let interfaceVisibility: S2InterfaceVisibility
    let isFramedPhoto: Bool
    let fittedSize: CGSize
    let nativeZoomBaseSize: CGSize
    let cornerRadius: CGFloat
    let doubleTapTargetScale: CGFloat
    let assetPixelSize: CGSize
    let contentVersion: S2NativePhotoContentVersion
    let content: AnyView
}

struct S2ImmersiveTransitionFrame: Equatable {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let cornerRadius: CGFloat

    var scale: CGFloat {
        min(scaleX, scaleY)
    }
}

struct S2ImmersiveTransition: Equatable {
    let viewportAnchor: CGPoint
    let layoutSize: CGSize
    let targetSize: CGSize
    let sourceCornerRadius: CGFloat
    let targetCornerRadius: CGFloat

    var targetScaleX: CGFloat {
        targetScale
    }

    var targetScaleY: CGFloat {
        targetScale
    }

    var targetScale: CGFloat {
        guard layoutSize.width > 0, layoutSize.height > 0 else {
            return 1
        }
        return min(
            targetSize.width / layoutSize.width,
            targetSize.height / layoutSize.height
        )
    }

    func frame(at progress: CGFloat) -> S2ImmersiveTransitionFrame {
        let boundedProgress = min(1, max(0, progress))
        return S2ImmersiveTransitionFrame(
            scaleX: 1 + (targetScaleX - 1) * boundedProgress,
            scaleY: 1 + (targetScaleY - 1) * boundedProgress,
            cornerRadius: sourceCornerRadius +
                (targetCornerRadius - sourceCornerRadius) * boundedProgress
        )
    }

    func layerCornerRadius(at progress: CGFloat) -> CGFloat {
        frame(at: progress).cornerRadius
    }

    func size(at progress: CGFloat) -> CGSize {
        let frame = frame(at: progress)
        return CGSize(
            width: layoutSize.width * frame.scaleX,
            height: layoutSize.height * frame.scaleY
        )
    }
}

struct S2NxEdgePagingProjection: Equatable {
    let direction: S2PageDirection?
    let overflowDistance: CGFloat
    let pagingContentOffsetX: CGFloat
}

struct S2NxEdgePagingInteraction: Equatable {
    let restingPagingOffsetX: CGFloat
    let pageStride: CGFloat
    let translationOriginX: CGFloat
    let distanceToPreviousBoundary: CGFloat
    let distanceToNextBoundary: CGFloat

    func projection(translationX: CGFloat) -> S2NxEdgePagingProjection {
        let translation = translationX - translationOriginX
        guard translation != 0 else {
            return S2NxEdgePagingProjection(
                direction: nil,
                overflowDistance: 0,
                pagingContentOffsetX: restingPagingOffsetX
            )
        }
        let direction: S2PageDirection = translation < 0
            ? .next
            : .previous
        let distanceToBoundary = direction == .next
            ? distanceToNextBoundary
            : distanceToPreviousBoundary
        let overflow = max(0, abs(translation) - distanceToBoundary)
        let boundedOverflow = min(max(0, pageStride), overflow)
        let offset = direction == .next
            ? restingPagingOffsetX + boundedOverflow
            : restingPagingOffsetX - boundedOverflow
        return S2NxEdgePagingProjection(
            direction: direction,
            overflowDistance: overflow,
            pagingContentOffsetX: offset
        )
    }
}

struct S2NativePhotoPager: UIViewControllerRepresentable {
    let machine: S2StateMachine
    let configuration: S2CalibrationConfiguration
    let viewportSize: CGSize
    let pages: [S2NativePageContent]
    let onLongPress: () -> Void
    let diagnosticsCoordinator: S2GeometryDiagnosticsCoordinator
    let transitionDiagnosticsCoordinator:
        S2OnDeviceTransitionDiagnosticsCoordinator

    func makeUIViewController(context _: Context) -> S2NativePagerViewController {
        let controller = S2NativePagerViewController()
        diagnosticsCoordinator.attach(controller)
        transitionDiagnosticsCoordinator.attach(controller)
        return controller
    }

    func updateUIViewController(
        _ controller: S2NativePagerViewController,
        context _: Context
    ) {
        diagnosticsCoordinator.attach(controller)
        transitionDiagnosticsCoordinator.attach(controller)
        let geometryWriteCount = transitionDiagnosticsCoordinator
            .photoGeometryWriteCount
        controller.apply(
            machine: machine,
            configuration: configuration,
            viewportSize: viewportSize,
            pages: pages,
            onLongPress: onLongPress
        )
        transitionDiagnosticsCoordinator.recordUpdateUIView(
            wrotePhotoGeometry: transitionDiagnosticsCoordinator
                .photoGeometryWriteCount > geometryWriteCount
        )
    }

    static func dismantleUIViewController(
        _ controller: S2NativePagerViewController,
        coordinator _: ()
    ) {
        controller.resetInteractionState()
        controller.diagnosticsRun = nil
    }
}

final class S2NativePagingScrollView: UIScrollView {
    private(set) var pageSpacing: CGFloat = 0
    private(set) var pageWidth: CGFloat = 0
    private(set) var itemCount = 0
    private(set) var viewportHeight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureNativePaging()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureNativePaging()
    }

    var pageStride: CGFloat {
        pageWidth + pageSpacing
    }

    func configure(
        viewportSize: CGSize,
        itemCount: Int,
        pageSpacing: CGFloat
    ) {
        self.pageSpacing = max(0, pageSpacing)
        pageWidth = max(0, viewportSize.width)
        viewportHeight = max(0, viewportSize.height)
        self.itemCount = max(0, itemCount)
        let nextFrame = CGRect(
            x: -self.pageSpacing / 2,
            y: 0,
            width: pageStride,
            height: viewportHeight
        )
        if frame != nextFrame {
            frame = nextFrame
        }
        let nextContentSize = CGSize(
            width: CGFloat(self.itemCount) * pageStride,
            height: viewportHeight
        )
        if contentSize != nextContentSize {
            contentSize = nextContentSize
        }
    }

    func frameForPage(at index: Int) -> CGRect {
        CGRect(
            x: CGFloat(index) * pageStride + pageSpacing / 2,
            y: 0,
            width: pageWidth,
            height: viewportHeight
        )
    }

    func visibleFrameForPage(at index: Int) -> CGRect {
        frameForPage(at: index).offsetBy(
            dx: frame.minX - contentOffset.x,
            dy: 0
        )
    }

    func contentOffsetForPage(at index: Int) -> CGPoint {
        CGPoint(x: CGFloat(index) * pageStride, y: 0)
    }

    func pageIndex(forContentOffsetX offset: CGFloat) -> Int {
        guard itemCount > 0, pageStride > 0 else {
            return 0
        }
        return min(
            itemCount - 1,
            max(0, Int((offset / pageStride).rounded()))
        )
    }

    private func configureNativePaging() {
        isPagingEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        isDirectionalLockEnabled = true
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
        clipsToBounds = false
    }
}

final class S2NativeZoomScrollView: UIScrollView {
    private(set) weak var zoomContentView: UIView?
    private(set) weak var presentationContentView: UIView?
    private(set) var fittedSize = CGSize.zero
    private(set) var nativeZoomBaseSize = CGSize.zero
    private(set) var viewportSize = CGSize.zero
    private(set) var hasResolvedAssetGeometry = true
    private(set) var nativeZoomInvocationCount = 0
    private(set) var lastNativeZoomRect: CGRect?
    private(set) var minimumZoomScaleAnimationInvocationCount = 0
    private(set) var lastMinimumZoomScaleAnimationTarget: CGFloat?
    private(set) var lastMinimumZoomScaleAnimationWasAnimated: Bool?
    private(set) var independentContentOffsetWriteCount = 0
    private(set) var isApplyingNativeState = false
    private var diagnosticPageIndex: Int?
    private var diagnosticAssetLocalIdentifier: String?
    weak var transitionDiagnostics:
        S2OnDeviceTransitionDiagnosticsCoordinator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureNativeZoom()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureNativeZoom()
    }

    func configure(
        contentView: UIView,
        fittedSize: CGSize,
        nativeZoomBaseSize: CGSize,
        viewportSize: CGSize,
        maximumZoomScale: CGFloat,
        assetPixelSize: CGSize? = nil
    ) {
        let nextMaximumScale = max(1, maximumZoomScale)
        self.maximumZoomScale = nextMaximumScale
        minimumZoomScale = 1

        if zoomContentView == nil {
            let zoomContentView = UIView()
            zoomContentView.backgroundColor = .clear
            zoomContentView.clipsToBounds = false
            self.zoomContentView = zoomContentView
            addSubview(zoomContentView)
        }
        guard let zoomContentView else {
            return
        }
        if presentationContentView !== contentView {
            presentationContentView?.removeFromSuperview()
            presentationContentView = contentView
            contentView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            zoomContentView.addSubview(contentView)
        }

        let nextFittedSize = CGSize(
            width: max(0, fittedSize.width),
            height: max(0, fittedSize.height)
        )
        let nextNativeZoomBaseSize = CGSize(
            width: max(0, nativeZoomBaseSize.width),
            height: max(0, nativeZoomBaseSize.height)
        )
        let nextViewportSize = CGSize(
            width: max(0, viewportSize.width),
            height: max(0, viewportSize.height)
        )
        let geometryChanged = self.fittedSize != nextFittedSize ||
            self.nativeZoomBaseSize != nextNativeZoomBaseSize ||
            self.viewportSize != nextViewportSize
        self.fittedSize = nextFittedSize
        self.nativeZoomBaseSize = nextNativeZoomBaseSize
        self.viewportSize = nextViewportSize
        hasResolvedAssetGeometry = assetPixelSize.map {
            $0.width > 0 && $0.height > 0
        } ?? true

        if zoomScale > nextMaximumScale {
            setZoomScale(nextMaximumScale, animated: false)
        }
        if geometryChanged,
           abs(zoomScale - minimumZoomScale) <= 0.000_001 {
            enforceOneXContentGeometry()
        }
        updatePanAvailability()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        transitionDiagnostics?.recordInnerLayoutSubviews(
            pageIndex: diagnosticPageIndex,
            assetLocalIdentifier: diagnosticAssetLocalIdentifier
        )
        applyJointCentering()
    }

    /// IC-070 R5：`contentOffset` 即 `bounds.origin`，UIKit 自身的捏合处理与
    /// 外部调用写入偏移都经过这里，且不会随之触发 `layoutSubviews`。
    /// 内容小于视口的方向在写入瞬间就钳回 `-contentInset`，过期偏移
    /// 不会留到下一帧；内容大于视口的方向原样放行。
    override var bounds: CGRect {
        didSet {
            guard !isCorrectingJointCenteringOffset else {
                return
            }
            let size = bounds.size
            var origin = bounds.origin
            if contentSize.width <= size.width + 0.000_001 {
                origin.x = -contentInset.left
            }
            if contentSize.height <= size.height + 0.000_001 {
                origin.y = -contentInset.top
            }
            guard abs(origin.x - bounds.origin.x) > 0.000_001 ||
                abs(origin.y - bounds.origin.y) > 0.000_001 else {
                return
            }
            isCorrectingJointCenteringOffset = true
            bounds = CGRect(origin: origin, size: size)
            isCorrectingJointCenteringOffset = false
        }
    }

    private var isCorrectingJointCenteringOffset = false

    /// IC-070 R5：`contentInset` 与 `contentOffset` 的联合居中在同一次布局
    /// 提交内一并写入。内容在某方向小于视口时，该方向唯一合法的偏移是
    /// `-inset`；任何外部写入的过期偏移都会在本次布局内被纠正，不留空档。
    /// 内容大于视口的方向不改动偏移，保留 `s > 1` 的平移边界语义。
    @discardableResult
    private func applyJointCentering() -> Bool {
        let nextInset = UIEdgeInsets(
            top: max(0, (bounds.height - contentSize.height) / 2),
            left: max(0, (bounds.width - contentSize.width) / 2),
            bottom: max(0, (bounds.height - contentSize.height) / 2),
            right: max(0, (bounds.width - contentSize.width) / 2)
        )
        var changed = false
        if contentInset != nextInset {
            contentInset = nextInset
            changed = true
        }
        var nextOffset = contentOffset
        if contentSize.width <= bounds.width + 0.000_001 {
            nextOffset.x = -nextInset.left
        }
        if contentSize.height <= bounds.height + 0.000_001 {
            nextOffset.y = -nextInset.top
        }
        if abs(nextOffset.x - contentOffset.x) > 0.000_001 ||
            abs(nextOffset.y - contentOffset.y) > 0.000_001 {
            contentOffset = nextOffset
            changed = true
        }
        return changed
    }

    func performDoubleTapZoom(
        at pointInViewport: CGPoint,
        targetScale: CGFloat,
        animated: Bool
    ) -> CGRect? {
        guard bounds.width > 0,
              bounds.height > 0,
              targetScale.isFinite,
              targetScale > 1 else {
            return nil
        }
        let baseOrigin = oneXNativeBaseOrigin
        let pointInContent = CGPoint(
            x: pointInViewport.x - baseOrigin.x,
            y: pointInViewport.y - baseOrigin.y
        )
        let targetRect = CGRect(
            x: pointInContent.x - bounds.width / (2 * targetScale),
            y: pointInContent.y - bounds.height / (2 * targetScale),
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        lastNativeZoomRect = targetRect
        nativeZoomInvocationCount += 1
        if !animated {
            applyDoubleTapTarget(
                scale: targetScale,
                focusPoint: pointInViewport
            )
        }
        return targetRect
    }

    func animateToMinimumZoomScale() {
        minimumZoomScaleAnimationInvocationCount += 1
        lastMinimumZoomScaleAnimationTarget = minimumZoomScale
        lastMinimumZoomScaleAnimationWasAnimated = true
        setZoomScale(minimumZoomScale, animated: true)
    }

    func requestedScale(for targetRect: CGRect) -> CGFloat? {
        guard targetRect.width > 0,
              targetRect.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return nil
        }
        return min(
            bounds.width / targetRect.width,
            bounds.height / targetRect.height
        )
    }

    func applyNativeState(
        scale: CGFloat,
        viewportOffset: CGSize
    ) {
        guard let zoomContentView else {
            return
        }
        let nextScale = min(maximumZoomScale, max(minimumZoomScale, scale))
        isApplyingNativeState = true
        if nextScale > minimumZoomScale + 0.000_001 {
            prepareNativeZoomGeometry()
            if abs(zoomScale - nextScale) > 0.000_001 {
                setZoomScale(nextScale, animated: false)
            }
        } else {
            if abs(zoomScale - minimumZoomScale) > 0.000_001 {
                setZoomScale(minimumZoomScale, animated: false)
            }
            enforceOneXContentGeometry()
        }
        setNeedsLayout()
        layoutIfNeeded()
        let nextOffset = nextScale > minimumZoomScale + 0.000_001
            ? CGPoint(
                x: zoomContentView.frame.midX - bounds.width / 2 -
                    viewportOffset.width,
                y: zoomContentView.frame.midY - bounds.height / 2 -
                    viewportOffset.height
            )
            : .zero
        if abs(contentOffset.x - nextOffset.x) > 0.000_001 ||
            abs(contentOffset.y - nextOffset.y) > 0.000_001 {
            independentContentOffsetWriteCount += 1
            setContentOffset(nextOffset, animated: false)
        }
        isApplyingNativeState = false
        updatePanAvailability()
    }

    struct DoubleTapTarget: Equatable {
        let presentationFrame: CGRect
        let contentOffset: CGPoint
    }

    func doubleTapTarget(
        scale: CGFloat,
        focusPoint: CGPoint
    ) -> DoubleTapTarget? {
        guard scale.isFinite,
              scale > 1,
              viewportSize.width > 0,
              viewportSize.height > 0,
              nativeZoomBaseSize.width > 0,
              nativeZoomBaseSize.height > 0 else {
            return nil
        }
        let baseOrigin = oneXNativeBaseOrigin
        let pointInBase = CGPoint(
            x: min(
                nativeZoomBaseSize.width,
                max(0, focusPoint.x - baseOrigin.x)
            ),
            y: min(
                nativeZoomBaseSize.height,
                max(0, focusPoint.y - baseOrigin.y)
            )
        )
        let scaledSize = CGSize(
            width: nativeZoomBaseSize.width * scale,
            height: nativeZoomBaseSize.height * scale
        )
        let maximumOffset = CGPoint(
            x: max(0, scaledSize.width - viewportSize.width),
            y: max(0, scaledSize.height - viewportSize.height)
        )
        let offset = CGPoint(
            x: min(
                maximumOffset.x,
                max(0, pointInBase.x * scale - viewportSize.width / 2)
            ),
            y: min(
                maximumOffset.y,
                max(0, pointInBase.y * scale - viewportSize.height / 2)
            )
        )
        let origin = CGPoint(
            x: scaledSize.width < viewportSize.width
                ? (viewportSize.width - scaledSize.width) / 2
                : -offset.x,
            y: scaledSize.height < viewportSize.height
                ? (viewportSize.height - scaledSize.height) / 2
                : -offset.y
        )
        return DoubleTapTarget(
            presentationFrame: CGRect(origin: origin, size: scaledSize),
            contentOffset: offset
        )
    }

    @discardableResult
    func applyDoubleTapTarget(
        scale: CGFloat,
        focusPoint: CGPoint
    ) -> DoubleTapTarget? {
        guard let target = doubleTapTarget(
            scale: scale,
            focusPoint: focusPoint
        ) else {
            return nil
        }
        isApplyingNativeState = true
        prepareNativeZoomGeometry()
        setZoomScale(scale, animated: false)
        setNeedsLayout()
        layoutIfNeeded()
        setContentOffset(target.contentOffset, animated: false)
        isApplyingNativeState = false
        updatePanAvailability()
        return target
    }

    @discardableResult
    func prepareForNativeZoom(
        synchronizedUpdates: () -> Void = {}
    ) -> Bool {
        guard abs(zoomScale - minimumZoomScale) <= 0.000_001 else {
            return false
        }
        guard hasResolvedAssetGeometry else {
            return false
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        guard prepareNativeZoomGeometry() else {
            CATransaction.commit()
            return false
        }
        synchronizedUpdates()
        setNeedsLayout()
        layoutIfNeeded()
        CATransaction.commit()
        transitionDiagnostics?.recordCATransactionCommit(
            source: "S2NativeZoomScrollView.prepareForNativeZoom"
        )
        return true
    }

    func restoreOneXGeometry() {
        guard abs(zoomScale - minimumZoomScale) <= 0.000_001 else {
            return
        }
        enforceOneXContentGeometry()
        updatePanAvailability()
    }

    var oneXPresentationFrame: CGRect {
        CGRect(
            x: (viewportSize.width - fittedSize.width) / 2,
            y: (viewportSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    func reportedViewportOffset() -> CGSize {
        guard let zoomContentView, zoomScale > 1 else {
            return .zero
        }
        return CGSize(
            width: zoomContentView.frame.midX - contentOffset.x -
                bounds.width / 2,
            height: zoomContentView.frame.midY - contentOffset.y -
                bounds.height / 2
        )
    }

    func visibleContentFrame() -> CGRect? {
        guard let zoomContentView else {
            return nil
        }
        return zoomContentView.convert(zoomContentView.bounds, to: self)
    }

    func visiblePresentationFrame() -> CGRect? {
        guard let presentationContentView else {
            return nil
        }
        let contentFrame = presentationContentView.convert(
            presentationContentView.bounds,
            to: self
        )
        return contentFrame.offsetBy(
            dx: -bounds.minX,
            dy: -bounds.minY
        )
    }

    func presentationAnchorInViewport() -> CGPoint? {
        guard let presentationContentView else {
            return nil
        }
        let anchorPoint = presentationContentView.layer.anchorPoint
        let anchorInScrollCoordinates = presentationContentView.convert(
            CGPoint(
                x: presentationContentView.bounds.width * anchorPoint.x,
                y: presentationContentView.bounds.height * anchorPoint.y
            ),
            to: self
        )
        return CGPoint(
            x: anchorInScrollCoordinates.x - bounds.minX,
            y: anchorInScrollCoordinates.y - bounds.minY
        )
    }

    func updatePanAvailability() {
        let shouldEnable = zoomScale > minimumZoomScale + 0.000_001
        if panGestureRecognizer.isEnabled != shouldEnable {
            panGestureRecognizer.isEnabled = shouldEnable
        }
    }

    func writePhotoGeometry(
        reason: S2PhotoGeometryWriteReason,
        mutation: (UIView) -> Void
    ) {
        guard let contentView = presentationContentView else {
            return
        }
        mutation(contentView)
        transitionDiagnostics?.recordPhotoGeometryWrite(
            frame: contentView.layer.frame,
            transform: contentView.layer.affineTransform(),
            reason: reason,
            pageIndex: diagnosticPageIndex,
            assetLocalIdentifier: diagnosticAssetLocalIdentifier
        )
    }

    func updateDiagnosticContext(
        pageIndex: Int,
        assetLocalIdentifier: String
    ) {
        diagnosticPageIndex = pageIndex
        diagnosticAssetLocalIdentifier = assetLocalIdentifier
    }

    func removeAllPhotoAnimations(source: String) {
        guard let photoLayer = presentationContentView?.layer else {
            return
        }
        transitionDiagnostics?.recordPhotoAnimationOperation(
            operation: "removeAllAnimations",
            key: "*",
            source: source
        )
        photoLayer.removeAllAnimations()
    }

    private var oneXNativeBaseOrigin: CGPoint {
        CGPoint(
            x: (viewportSize.width - nativeZoomBaseSize.width) / 2,
            y: (viewportSize.height - nativeZoomBaseSize.height) / 2
        )
    }

    private func enforceOneXContentGeometry() {
        guard abs(zoomScale - minimumZoomScale) <= 0.000_001 else {
            return
        }
        guard let zoomContentView,
              let presentationContentView else {
            return
        }
        var geometryChanged = false
        let targetZoomBounds = CGRect(
            origin: .zero,
            size: nativeZoomBaseSize
        )
        let targetZoomCenter = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height / 2
        )
        if zoomContentView.transform != .identity {
            zoomContentView.transform = .identity
            geometryChanged = true
        }
        if zoomContentView.bounds != targetZoomBounds {
            zoomContentView.bounds = targetZoomBounds
            geometryChanged = true
        }
        if zoomContentView.center != targetZoomCenter {
            zoomContentView.center = targetZoomCenter
            geometryChanged = true
        }
        let targetPhotoBounds = CGRect(origin: .zero, size: fittedSize)
        let targetPhotoCenter = CGPoint(
            x: targetZoomBounds.midX,
            y: targetZoomBounds.midY
        )
        if presentationContentView.transform != .identity ||
            presentationContentView.bounds != targetPhotoBounds ||
            presentationContentView.center != targetPhotoCenter {
            writePhotoGeometry(reason: .enforceOneXContentGeometry) {
                contentView in
                contentView.transform = .identity
                contentView.bounds = targetPhotoBounds
                contentView.center = targetPhotoCenter
            }
            geometryChanged = true
        }
        if contentInset != .zero {
            contentInset = .zero
            geometryChanged = true
        }
        if contentSize != viewportSize {
            contentSize = viewportSize
            geometryChanged = true
        }
        if contentOffset != .zero {
            setContentOffset(.zero, animated: false)
            geometryChanged = true
        }
        if geometryChanged {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    @discardableResult
    private func prepareNativeZoomGeometry() -> Bool {
        guard hasResolvedAssetGeometry else {
            return false
        }
        guard let zoomContentView,
              presentationContentView != nil else {
            return false
        }
        if abs(zoomScale - minimumZoomScale) <= 0.000_001 {
            zoomContentView.transform = .identity
            zoomContentView.frame = CGRect(
                origin: .zero,
                size: nativeZoomBaseSize
            )
            writePhotoGeometry(reason: .prepareNativeZoomGeometry) {
                contentView in
                contentView.transform = .identity
                contentView.bounds = CGRect(
                    origin: .zero,
                    size: nativeZoomBaseSize
                )
                contentView.center = CGPoint(
                    x: zoomContentView.bounds.midX,
                    y: zoomContentView.bounds.midY
                )
            }
            contentSize = nativeZoomBaseSize
            applyJointCentering()
        }
        return true
    }

    private func configureNativeZoom() {
        minimumZoomScale = 1
        maximumZoomScale = 1
        bounces = false
        bouncesZoom = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
        clipsToBounds = true
        delaysContentTouches = false
    }
}

final class S2SingleTapGestureRecognizer: UITapGestureRecognizer {
    private(set) weak var requiredDoubleTapRecognizer:
        UITapGestureRecognizer?

    func recordRequiredDoubleTapRecognizer(
        _ doubleTapRecognizer: UITapGestureRecognizer
    ) {
        requiredDoubleTapRecognizer = doubleTapRecognizer
    }
}

struct S2DoubleTapTransition: Equatable {
    let sourceFrame: CGRect
    let targetFrame: CGRect
    let sourceCornerRadius: CGFloat
    let targetCornerRadius: CGFloat
    let sourceZoomScale: CGFloat
    let targetZoomScale: CGFloat
    let isEnteringNx: Bool

    func frame(at progress: CGFloat) -> CGRect {
        let value = min(1, max(0, progress))
        return CGRect(
            x: sourceFrame.minX +
                (targetFrame.minX - sourceFrame.minX) * value,
            y: sourceFrame.minY +
                (targetFrame.minY - sourceFrame.minY) * value,
            width: sourceFrame.width +
                (targetFrame.width - sourceFrame.width) * value,
            height: sourceFrame.height +
                (targetFrame.height - sourceFrame.height) * value
        )
    }

    func cornerRadius(at progress: CGFloat) -> CGFloat {
        let value = min(1, max(0, progress))
        return sourceCornerRadius +
            (targetCornerRadius - sourceCornerRadius) * value
    }

    func transform(at progress: CGFloat) -> CGAffineTransform {
        let frame = frame(at: progress)
        guard sourceFrame.width > 0, sourceFrame.height > 0 else {
            return .identity
        }
        return CGAffineTransform(
            a: frame.width / sourceFrame.width,
            b: 0,
            c: 0,
            d: frame.height / sourceFrame.height,
            tx: frame.midX - sourceFrame.midX,
            ty: frame.midY - sourceFrame.midY
        )
    }
}

struct S2DoubleTapSynchronizationReading: Equatable {
    let beforeWindowFrame: CGRect
    let afterWindowFrame: CGRect

    var maximumDifference: CGFloat {
        [
            abs(beforeWindowFrame.minX - afterWindowFrame.minX),
            abs(beforeWindowFrame.minY - afterWindowFrame.minY),
            abs(beforeWindowFrame.width - afterWindowFrame.width),
            abs(beforeWindowFrame.height - afterWindowFrame.height)
        ].max() ?? 0
    }
}

enum S2DoubleTapTransitionEvent {
    case started(S2DoubleTapTransition)
    case progressed(S2DoubleTapTransition, CGFloat)
    case completed(
        S2DoubleTapTransition,
        S2DoubleTapSynchronizationReading
    )
}

private final class S2DoubleTapTransitionView: UIView {
    init(snapshotView: UIView, sourceFrame: CGRect) {
        super.init(frame: sourceFrame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        snapshotView.frame = bounds
        snapshotView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(snapshotView)
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

final class S2NativeZoomPageController: UIViewController,
    UIScrollViewDelegate,
    UIGestureRecognizerDelegate {
    let index: Int
    let zoomScrollView = S2NativeZoomScrollView()
    let singleTapRecognizer = S2SingleTapGestureRecognizer()
    let doubleTapRecognizer = UITapGestureRecognizer()
    let verticalSwipeRecognizer = UIPanGestureRecognizer()
    let fitBorderLayer = CALayer()
    private let hostingController: UIHostingController<AnyView>
    private weak var owner: S2NativePagerViewController?
    weak var transitionDiagnostics:
        S2OnDeviceTransitionDiagnosticsCoordinator? {
        didSet {
            zoomScrollView.transitionDiagnostics = transitionDiagnostics
            zoomScrollView.updateDiagnosticContext(
                pageIndex: index,
                assetLocalIdentifier: assetID
            )
        }
    }
    private var assetID: String
    private var interfaceVisibility: S2InterfaceVisibility
    private var isFramedPhoto: Bool
    private var contentVersion: S2NativePhotoContentVersion
    private(set) var fittedSize: CGSize
    private(set) var nativeZoomBaseSize: CGSize
    private(set) var cornerRadius: CGFloat
    private(set) var doubleTapTargetScale: CGFloat
    private(set) var assetPixelSize: CGSize
    private(set) var lastPresentationTransitionDuration: TimeInterval = 0
    private(set) var lastPresentationTransition: S2ImmersiveTransition?
    private(set) var lastPresentationScaleKeyframes: [CGFloat] = []
    private(set) var isPresentationTransitionActive = false
    private(set) var presentationTransitionCount = 0
    private(set) var presentationGeometryCommitCount = 0
    private(set) var isDoubleTapTransitionActive = false
    private(set) var lastDoubleTapTransition: S2DoubleTapTransition?
    private(set) var lastDoubleTapSynchronization:
        S2DoubleTapSynchronizationReading?
    private(set) var doubleTapTransitionProgressSamples: [CGFloat] = []
    private(set) var lastTapDecisionReading: S2TapDecisionReading?
    private var pendingPresentationPage: S2NativePageContent?
    private var presentationTransitionGeneration = 0
    private static let presentationAnimationKey =
        "S2NativeZoomPageController.presentationTransition"
    private var presentationCompletionWorkItem: DispatchWorkItem?
    private var presentationTransitionDuration: TimeInterval = 0
    private var presentationSpringCurve = S2PresentationSpringCurve(
        dampingRatio: 0.86
    )
    private var presentationSourceScale: CGFloat = 1
    private var presentationTargetScale: CGFloat = 1
    private var presentationSourceVisualCornerRadius: CGFloat = 0
    private var presentationTargetVisualCornerRadius: CGFloat = 0
    private var presentationSourceVisualBorderWidth: CGFloat = 0
    private var presentationTargetVisualBorderWidth: CGFloat = 0
    private var latestConfiguration =
        S2CalibrationConfiguration.factoryPlaceholder
    private var latestViewportSize = CGSize.zero
    private var pinchIsActive = false
    private var pinchStartDate: Date?
    private var pinchStartScale: CGFloat = 1
    private var pinchPeakVelocity: CGFloat = 0
    private var verticalSwipeStartDate: Date?
    private var singleTapTouchTimestamp: TimeInterval?
    private var doubleTapTransitionView: S2DoubleTapTransitionView?
    private var doubleTapDisplayLink: CADisplayLink?
    private var doubleTapTransitionStartTimestamp: CFTimeInterval?
    private var doubleTapTransitionDuration: TimeInterval = 0
    private var doubleTapFocusPoint = CGPoint.zero
    private var activeDoubleTapTargetScale: CGFloat = 1
    private var doubleTapTargetPage: S2NativePageContent?
    private var doubleTapLatestPage: S2NativePageContent?
    var doubleTapTransitionObserver:
        ((S2DoubleTapTransitionEvent) -> Void)?
    private var tapDecisionPolicy = S2TapDecisionDiagnosticPolicy(
        configuration: .factoryPlaceholder
    )
    private(set) var nativeScrollPriorityIsConfigured = false

    var hasDeferredPresentation: Bool {
        pendingPresentationPage != nil && !isPresentationTransitionActive
    }

    var diagnosticInterfaceVisibility: S2InterfaceVisibility {
        interfaceVisibility
    }

    var diagnosticAssetLocalIdentifier: String {
        assetID
    }

    var diagnosticAdditionalSafeAreaInsets: UIEdgeInsets {
        hostingController.additionalSafeAreaInsets
    }

    var diagnosticHostingSafeAreaInsets: UIEdgeInsets {
        hostingController.view.safeAreaInsets
    }

    var diagnosticTransitionTransform: CGAffineTransform {
        doubleTapTransitionView?.transform ?? .identity
    }

    init(
        page: S2NativePageContent,
        owner: S2NativePagerViewController
    ) {
        index = page.index
        assetID = page.assetID
        interfaceVisibility = page.interfaceVisibility
        isFramedPhoto = page.isFramedPhoto
        contentVersion = page.contentVersion
        fittedSize = page.fittedSize
        nativeZoomBaseSize = page.nativeZoomBaseSize
        cornerRadius = page.cornerRadius
        doubleTapTargetScale = page.doubleTapTargetScale
        assetPixelSize = page.assetPixelSize
        hostingController = UIHostingController(
            rootView: AnyView(page.content.ignoresSafeArea())
        )
        self.owner = owner
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .clear
        rootView.clipsToBounds = true
        rootView.insetsLayoutMarginsFromSafeArea = false
        zoomScrollView.frame = rootView.bounds
        zoomScrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        rootView.addSubview(zoomScrollView)
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        zoomScrollView.transitionDiagnostics = transitionDiagnostics
        zoomScrollView.updateDiagnosticContext(
            pageIndex: index,
            assetLocalIdentifier: assetID
        )
        additionalSafeAreaInsets = .zero
        zoomScrollView.delegate = self
        hostingController.view.backgroundColor = .clear
        hostingController.additionalSafeAreaInsets = .zero
        addChild(hostingController)
        fitBorderLayer.backgroundColor = UIColor.clear.cgColor
        fitBorderLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "borderWidth": NSNull(),
            "borderColor": NSNull(),
            "cornerRadius": NSNull()
        ]
        hostingController.view.layer.addSublayer(fitBorderLayer)
        zoomScrollView.configure(
            contentView: hostingController.view,
            fittedSize: fittedSize,
            nativeZoomBaseSize: nativeZoomBaseSize,
            viewportSize: latestViewportSize,
            maximumZoomScale: 1,
            assetPixelSize: assetPixelSize
        )
        applyCornerMask()
        hostingController.didMove(toParent: self)

        singleTapRecognizer.addTarget(
            self,
            action: #selector(handleSingleTap(_:))
        )
        singleTapRecognizer.numberOfTapsRequired = 1
        singleTapRecognizer.cancelsTouchesInView = false
        singleTapRecognizer.delegate = self

        doubleTapRecognizer.addTarget(
            self,
            action: #selector(handleDoubleTap(_:))
        )
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.cancelsTouchesInView = false
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        singleTapRecognizer.recordRequiredDoubleTapRecognizer(
            doubleTapRecognizer
        )

        verticalSwipeRecognizer.addTarget(
            self,
            action: #selector(handleVerticalSwipe(_:))
        )
        verticalSwipeRecognizer.cancelsTouchesInView = true
        verticalSwipeRecognizer.delegate = self

        zoomScrollView.addGestureRecognizer(singleTapRecognizer)
        zoomScrollView.addGestureRecognizer(doubleTapRecognizer)
        zoomScrollView.addGestureRecognizer(verticalSwipeRecognizer)
        zoomScrollView.panGestureRecognizer.addTarget(
            self,
            action: #selector(handleNativePan(_:))
        )
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle !=
                traitCollection.userInterfaceStyle else {
            return
        }
        refreshFitBorderColor(
            userInterfaceStyle: traitCollection.userInterfaceStyle
        )
    }

    func update(
        page: S2NativePageContent,
        configuration: S2CalibrationConfiguration,
        scale: CGFloat,
        viewportOffset: CGSize,
        isCurrent: Bool,
        viewportSize: CGSize
    ) {
        loadViewIfNeeded()
        latestConfiguration = configuration
        latestViewportSize = viewportSize
        doubleTapTargetScale = page.doubleTapTargetScale
        tapDecisionPolicy = S2TapDecisionDiagnosticPolicy(
            configuration: configuration
        )
        singleTapRecognizer.numberOfTouchesRequired = max(
            1,
            configuration.singleTapTouchCount
        )
        doubleTapRecognizer.numberOfTouchesRequired = max(
            1,
            configuration.doubleTapTouchCount
        )
        let verticalTouchCount = max(
            1,
            configuration.singleDragTouchCount
        )
        verticalSwipeRecognizer.minimumNumberOfTouches = verticalTouchCount
        verticalSwipeRecognizer.maximumNumberOfTouches = verticalTouchCount

        let sameAsset = assetID == page.assetID
        if isDoubleTapTransitionActive, sameAsset {
            doubleTapLatestPage = page
            return
        }
        let presentationChanged = sameAsset &&
            interfaceVisibility != page.interfaceVisibility &&
            isFramedPhoto && page.isFramedPhoto &&
            (fittedSize != page.fittedSize ||
                cornerRadius != page.cornerRadius)
        let nativeZoomIsAboveOne = isCurrent &&
            zoomScrollView.zoomScale > 1.000_001
        if scale > 1.000_001 || nativeZoomIsAboveOne {
            if presentationChanged {
                pendingPresentationPage = page
                lastPresentationTransitionDuration = 0
                return
            }
            if sameAsset &&
                fittedSize == page.fittedSize &&
                cornerRadius == page.cornerRadius {
                pendingPresentationPage = nil
                applyPhotoContent(
                    page,
                    onlyIfVersionChanged: true
                )
            }
            lastPresentationTransitionDuration = 0
            let interactionIsActive = pinchIsActive ||
                zoomScrollView.isTracking ||
                zoomScrollView.isDragging ||
                zoomScrollView.isDecelerating ||
                zoomScrollView.isZooming
            if !interactionIsActive {
                zoomScrollView.configure(
                    contentView: hostingController.view,
                    fittedSize: fittedSize,
                    nativeZoomBaseSize: nativeZoomBaseSize,
                    viewportSize: viewportSize,
                    maximumZoomScale: CGFloat(configuration.pinchMaxScale),
                    assetPixelSize: assetPixelSize
                )
                zoomScrollView.applyNativeState(
                    scale: isCurrent ? scale : 1,
                    viewportOffset: isCurrent ? viewportOffset : .zero
                )
                applyCornerMask()
            }
            return
        }

        if isPresentationTransitionActive,
           pendingPresentationMatches(page) {
            pendingPresentationPage = page
            return
        }

        if presentationChanged ||
            (isPresentationTransitionActive && sameAsset) {
            startPresentationTransition(
                to: page,
                configuration: configuration,
                viewportSize: viewportSize
            )
            return
        }

        pendingPresentationPage = nil
        applyPageImmediately(
            page,
            configuration: configuration,
            countsAsPresentationCommit: false
        )
        let interactionIsActive = pinchIsActive ||
            zoomScrollView.isTracking ||
            zoomScrollView.isDragging ||
            zoomScrollView.isDecelerating ||
            zoomScrollView.isZooming
        if !interactionIsActive {
            zoomScrollView.applyNativeState(
                scale: isCurrent ? scale : 1,
                viewportOffset: isCurrent ? viewportOffset : .zero
            )
            applyCornerMask()
        }
    }

    func resetZoom() {
        pinchIsActive = false
        zoomScrollView.applyNativeState(scale: 1, viewportOffset: .zero)
        applyCornerMask()
        applyDeferredPresentationIfPossible()
    }

    func finishActivePresentationTransition() {
        if isPresentationTransitionActive {
            finishPresentationTransition(
                generation: presentationTransitionGeneration
            )
            return
        }
        guard let page = pendingPresentationPage else {
            return
        }
        commitPresentation(page)
    }

    @discardableResult
    func startDoubleTapTransition(
        enteringNx: Bool,
        targetScale: CGFloat,
        at focusPoint: CGPoint,
        configuration: S2CalibrationConfiguration
    ) -> Bool {
        guard !isDoubleTapTransitionActive,
              !isPresentationTransitionActive,
              let presentationContentView =
                zoomScrollView.presentationContentView else {
            return false
        }
        view.layoutIfNeeded()
        let sourceFrame = presentationContentView.convert(
            presentationContentView.bounds,
            to: view
        )
        let targetFrame: CGRect
        let targetCornerRadius: CGFloat
        if enteringNx {
            guard let target = zoomScrollView.doubleTapTarget(
                scale: targetScale,
                focusPoint: focusPoint
            ) else {
                return false
            }
            targetFrame = target.presentationFrame
            targetCornerRadius = 0
            doubleTapTargetPage = nil
        } else {
            let page = pendingPresentationPage
            let targetSize = page?.fittedSize ?? fittedSize
            targetFrame = CGRect(
                x: (view.bounds.width - targetSize.width) / 2,
                y: (view.bounds.height - targetSize.height) / 2,
                width: targetSize.width,
                height: targetSize.height
            )
            targetCornerRadius = page?.cornerRadius ?? cornerRadius
            doubleTapTargetPage = page
        }
        guard sourceFrame.width > 0,
              sourceFrame.height > 0,
              targetFrame.width > 0,
              targetFrame.height > 0 else {
            return false
        }

        let transition = S2DoubleTapTransition(
            sourceFrame: sourceFrame,
            targetFrame: targetFrame,
            sourceCornerRadius:
                presentationContentView.layer.cornerRadius,
            targetCornerRadius: targetCornerRadius,
            sourceZoomScale: zoomScrollView.zoomScale,
            targetZoomScale: targetScale,
            isEnteringNx: enteringNx
        )
        let transitionView = S2DoubleTapTransitionView(
            snapshotView: makeDoubleTapSnapshot(),
            sourceFrame: sourceFrame
        )
        transitionView.layer.cornerCurve = .continuous
        transitionView.layer.cornerRadius = transition.sourceCornerRadius
        transitionView.layer.masksToBounds =
            transition.sourceCornerRadius > 0 ||
                transition.targetCornerRadius > 0
        view.addSubview(transitionView)

        lastDoubleTapTransition = transition
        lastDoubleTapSynchronization = nil
        doubleTapTransitionProgressSamples = []
        doubleTapTransitionView = transitionView
        doubleTapFocusPoint = focusPoint
        activeDoubleTapTargetScale = targetScale
        doubleTapLatestPage = nil
        doubleTapTransitionStartTimestamp = nil
        let policy = S2AnimationPolicy(configuration: configuration)
        doubleTapTransitionDuration = policy.shouldAnimate
            ? policy.durationSeconds
            : 0
        isDoubleTapTransitionActive = true
        presentationContentView.isHidden = true
        zoomScrollView.isUserInteractionEnabled = false
        doubleTapTransitionObserver?(.started(transition))

        guard doubleTapTransitionDuration > 0,
              view.window != nil else {
            applyDoubleTapTransitionProgress(1)
            finishActiveDoubleTapTransition()
            return true
        }
        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(advanceDoubleTapTransition(_:))
        )
        doubleTapDisplayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
        return true
    }

    func finishActiveDoubleTapTransition() {
        guard isDoubleTapTransitionActive,
              let transition = lastDoubleTapTransition,
              let transitionView = doubleTapTransitionView,
              let presentationContentView =
                zoomScrollView.presentationContentView else {
            return
        }
        doubleTapDisplayLink?.invalidate()
        doubleTapDisplayLink = nil
        applyDoubleTapTransitionProgress(1)
        let window = view.window
        let beforeFrame = transitionView.convert(
            transitionView.bounds,
            to: window
        )

        if transition.isEnteringNx {
            _ = zoomScrollView.applyDoubleTapTarget(
                scale: activeDoubleTapTargetScale,
                focusPoint: doubleTapFocusPoint
            )
            applyCornerMask()
        } else {
            let targetPage = doubleTapLatestPage ?? doubleTapTargetPage
            if let targetPage {
                let geometryChanged = fittedSize != targetPage.fittedSize ||
                    cornerRadius != targetPage.cornerRadius ||
                    interfaceVisibility != targetPage.interfaceVisibility
                applyPageImmediately(
                    targetPage,
                    configuration: latestConfiguration,
                    countsAsPresentationCommit: geometryChanged
                )
            }
            zoomScrollView.applyNativeState(
                scale: 1,
                viewportOffset: .zero
            )
            applyCornerMask()
        }

        if transition.isEnteringNx,
           let actualFrame = zoomScrollView.visiblePresentationFrame() {
            let targetFrame = transition.targetFrame
            let correction = CGPoint(
                x: actualFrame.minX - targetFrame.minX,
                y: actualFrame.minY - targetFrame.minY
            )
            if abs(correction.x) > 0.000_001 ||
                abs(correction.y) > 0.000_001 {
                zoomScrollView.setContentOffset(
                    CGPoint(
                        x: zoomScrollView.contentOffset.x + correction.x,
                        y: zoomScrollView.contentOffset.y + correction.y
                    ),
                    animated: false
                )
            }
        }
        let afterFrame = presentationContentView.convert(
            presentationContentView.bounds,
            to: window
        )
        let reading = S2DoubleTapSynchronizationReading(
            beforeWindowFrame: beforeFrame,
            afterWindowFrame: afterFrame
        )
        lastDoubleTapSynchronization = reading

        presentationContentView.isHidden = false
        transitionView.removeFromSuperview()
        doubleTapTransitionView = nil
        doubleTapTargetPage = nil
        doubleTapLatestPage = nil
        isDoubleTapTransitionActive = false
        zoomScrollView.isUserInteractionEnabled = true
        owner?.doubleTapTransitionDidComplete(on: self)
        doubleTapTransitionObserver?(.completed(transition, reading))
    }

    private func makeDoubleTapSnapshot() -> UIView {
        if let snapshot = hostingController.view.snapshotView(
            afterScreenUpdates: false
        ) {
            return snapshot
        }
        let renderer = UIGraphicsImageRenderer(
            bounds: hostingController.view.bounds
        )
        let image = renderer.image { context in
            hostingController.view.layer.render(in: context.cgContext)
        }
        return UIImageView(image: image)
    }

    private func applyDoubleTapTransitionProgress(_ progress: CGFloat) {
        guard let transition = lastDoubleTapTransition,
              let transitionView = doubleTapTransitionView else {
            return
        }
        let value = min(1, max(0, progress))
        transitionView.transform = transition.transform(at: value)
        transitionView.layer.cornerRadius = transition.cornerRadius(at: value)
        if value > 0, value < 1 {
            doubleTapTransitionProgressSamples.append(value)
        }
        doubleTapTransitionObserver?(.progressed(transition, value))
    }

    @objc private func advanceDoubleTapTransition(
        _ displayLink: CADisplayLink
    ) {
        if doubleTapTransitionStartTimestamp == nil {
            doubleTapTransitionStartTimestamp = displayLink.timestamp
        }
        let elapsed = displayLink.timestamp -
            (doubleTapTransitionStartTimestamp ?? displayLink.timestamp)
        let progress = doubleTapTransitionDuration > 0
            ? CGFloat(elapsed / doubleTapTransitionDuration)
            : 1
        applyDoubleTapTransitionProgress(progress)
        if progress >= 1 {
            finishActiveDoubleTapTransition()
        }
    }

    private func startPresentationTransition(
        to page: S2NativePageContent,
        configuration: S2CalibrationConfiguration,
        viewportSize: CGSize
    ) {
        let transition = S2ImmersiveTransition(
            viewportAnchor: CGPoint(
                x: viewportSize.width / 2,
                y: viewportSize.height / 2
            ),
            layoutSize: fittedSize,
            targetSize: page.fittedSize,
            sourceCornerRadius: cornerRadius,
            targetCornerRadius: page.cornerRadius
        )
        let animationPolicy = S2AnimationPolicy(
            configuration: configuration,
            durationMilliseconds:
                configuration.presentationToggleDuration
        )
        lastPresentationTransition = transition
        lastPresentationTransitionDuration = animationPolicy.shouldAnimate
            ? animationPolicy.durationSeconds
            : 0

        guard animationPolicy.shouldAnimate,
              let presentationContentView =
                zoomScrollView.presentationContentView else {
            UIView.performWithoutAnimation {
                self.applyPageImmediately(
                    page,
                    configuration: configuration,
                    countsAsPresentationCommit: true,
                    onlyIfContentVersionChanged: true
                )
            }
            return
        }

        zoomScrollView.applyNativeState(scale: 1, viewportOffset: .zero)
        view.layoutIfNeeded()
        let sourceLayer = presentationContentView.layer.presentation() ??
            presentationContentView.layer
        let sourceFrame = sourceLayer.frame
        let sourceScale = min(
            sourceLayer.bounds.width > 0
                ? abs(sourceFrame.width / sourceLayer.bounds.width)
                : 1,
            sourceLayer.bounds.height > 0
                ? abs(sourceFrame.height / sourceLayer.bounds.height)
                : 1
        )
        let sourceVisualCornerRadius = sourceLayer.cornerRadius * sourceScale
        let sourceBorderLayer = fitBorderLayer.presentation() ?? fitBorderLayer
        let sourceVisualBorderWidth = sourceBorderLayer.borderWidth *
            sourceScale

        guard fittedSize.width > 0,
              fittedSize.height > 0,
              page.fittedSize.width > 0,
              page.fittedSize.height > 0 else {
            return
        }
        let targetScaleOnSource = min(
            page.fittedSize.width / fittedSize.width,
            page.fittedSize.height / fittedSize.height
        )
        let safeSourceScale = max(0.000_001, sourceScale)
        let safeTargetScale = max(0.000_001, targetScaleOnSource)
        let targetLayerCornerRadius = max(0, page.cornerRadius)
        let targetBorderWidth = page.interfaceVisibility == .visible &&
            page.isFramedPhoto
            ? max(0, CGFloat(configuration.fitBorderWidth))
            : 0
        let targetBorderColor = resolvedFitBorderColor()

        pendingPresentationPage = page
        isPresentationTransitionActive = true
        presentationTransitionCount += 1
        presentationTransitionGeneration += 1
        presentationTransitionDuration = animationPolicy.durationSeconds
        presentationSpringCurve = S2PresentationSpringCurve(
            dampingRatio: configuration.presentationToggleDamping
        )
        presentationSourceScale = safeSourceScale
        presentationTargetScale = safeTargetScale
        presentationSourceVisualCornerRadius = sourceVisualCornerRadius
        presentationTargetVisualCornerRadius = targetLayerCornerRadius
        presentationSourceVisualBorderWidth = sourceVisualBorderWidth
        presentationTargetVisualBorderWidth = targetBorderWidth
        presentationContentView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        presentationContentView.layer.cornerCurve = .continuous
        UIView.performWithoutAnimation {
            self.zoomScrollView.writePhotoGeometry(
                reason: .presentationTransitionSetup
            ) { contentView in
                contentView.transform = CGAffineTransform(
                    scaleX: safeTargetScale,
                    y: safeTargetScale
                )
            }
            presentationContentView.layer.cornerRadius =
                targetLayerCornerRadius / safeTargetScale
            presentationContentView.layer.borderWidth = 0
            self.fitBorderLayer.borderColor =
                targetBorderColor
            self.fitBorderLayer.cornerRadius =
                targetLayerCornerRadius / safeTargetScale
            self.fitBorderLayer.borderWidth =
                targetBorderWidth / safeTargetScale
            presentationContentView.layer.masksToBounds =
                sourceVisualCornerRadius > 0 ||
                    targetLayerCornerRadius > 0
        }
        addPresentationLayerAnimations(
            to: presentationContentView,
            duration: presentationTransitionDuration
        )
        let generation = presentationTransitionGeneration
        let completion = DispatchWorkItem { [weak self] in
            self?.finishPresentationTransition(generation: generation)
        }
        presentationCompletionWorkItem = completion
        DispatchQueue.main.asyncAfter(
            deadline: .now() + presentationTransitionDuration,
            execute: completion
        )
    }

    private func addPresentationLayerAnimations(
        to presentationContentView: UIView,
        duration: TimeInterval
    ) {
        let sampleCount = max(2, Int(ceil(duration * 120)) + 1)
        let progressValues = (0..<sampleCount).map { index in
            presentationSpringCurve.value(
                at: CGFloat(index) / CGFloat(sampleCount - 1)
            )
        }
        let scales = progressValues.map { value in
            presentationSourceScale +
                (presentationTargetScale - presentationSourceScale) * value
        }
        lastPresentationScaleKeyframes = scales
        let visualCornerRadii = progressValues.map { value in
            max(
                0,
                presentationSourceVisualCornerRadius +
                    (presentationTargetVisualCornerRadius -
                        presentationSourceVisualCornerRadius) * value
            )
        }
        let visualBorderWidths = progressValues.map { value in
            max(
                0,
                presentationSourceVisualBorderWidth +
                    (presentationTargetVisualBorderWidth -
                        presentationSourceVisualBorderWidth) * value
            )
        }
        let keyTimes = (0..<sampleCount).map { index in
            NSNumber(value: Double(index) / Double(sampleCount - 1))
        }
        let layerCornerRadii = zip(visualCornerRadii, scales).map { pair in
            NSNumber(value: Double(
                pair.0 / max(0.000_001, pair.1)
            ))
        }
        let layerBorderWidths = zip(visualBorderWidths, scales).map { pair in
            NSNumber(value: Double(
                pair.0 / max(0.000_001, pair.1)
            ))
        }

        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = scales.map { NSNumber(value: Double($0)) }
        scaleAnimation.keyTimes = keyTimes
        let cornerAnimation = CAKeyframeAnimation(keyPath: "cornerRadius")
        cornerAnimation.values = layerCornerRadii
        cornerAnimation.keyTimes = keyTimes
        let photoGroup = presentationAnimationGroup(
            animations: [scaleAnimation, cornerAnimation],
            duration: duration
        )
        transitionDiagnostics?.recordPhotoAnimationOperation(
            operation: "add(animation:)",
            key: Self.presentationAnimationKey,
            source: "S2NativeZoomPageController.startPresentationTransition"
        )
        presentationContentView.layer.add(
            photoGroup,
            forKey: Self.presentationAnimationKey
        )

        let borderCornerAnimation = CAKeyframeAnimation(
            keyPath: "cornerRadius"
        )
        borderCornerAnimation.values = layerCornerRadii
        borderCornerAnimation.keyTimes = keyTimes
        let borderWidthAnimation = CAKeyframeAnimation(keyPath: "borderWidth")
        borderWidthAnimation.values = layerBorderWidths
        borderWidthAnimation.keyTimes = keyTimes
        fitBorderLayer.add(
            presentationAnimationGroup(
                animations: [borderCornerAnimation, borderWidthAnimation],
                duration: duration
            ),
            forKey: Self.presentationAnimationKey
        )
    }

    private func presentationAnimationGroup(
        animations: [CAAnimation],
        duration: TimeInterval
    ) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        animations.forEach { $0.duration = duration }
        group.animations = animations
        group.duration = duration
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        return group
    }

    private func finishPresentationTransition(generation: Int) {
        guard isPresentationTransitionActive,
              presentationTransitionGeneration == generation else {
            return
        }
        guard zoomScrollView.presentationContentView != nil else {
            presentationCompletionWorkItem?.cancel()
            presentationCompletionWorkItem = nil
            isPresentationTransitionActive = false
            pendingPresentationPage = nil
            return
        }
        presentationCompletionWorkItem?.cancel()
        presentationCompletionWorkItem = nil
        guard let page = pendingPresentationPage else {
            isPresentationTransitionActive = false
            return
        }
        UIView.performWithoutAnimation {
            self.applyPageImmediately(
                page,
                configuration: self.latestConfiguration,
                countsAsPresentationCommit: true,
                onlyIfContentVersionChanged: true
            )
        }
    }

    private func applyDeferredPresentationIfPossible() {
        guard !isPresentationTransitionActive,
              !zoomScrollView.isZooming,
              zoomScrollView.zoomScale <= 1.000_001,
              let page = pendingPresentationPage else {
            return
        }
        startPresentationTransition(
            to: page,
            configuration: latestConfiguration,
            viewportSize: latestViewportSize
        )
    }

    private func pendingPresentationMatches(
        _ page: S2NativePageContent
    ) -> Bool {
        guard let pendingPresentationPage else {
            return false
        }
        return pendingPresentationPage.assetID == page.assetID &&
            pendingPresentationPage.interfaceVisibility ==
                page.interfaceVisibility &&
            pendingPresentationPage.isFramedPhoto == page.isFramedPhoto &&
            pendingPresentationPage.fittedSize == page.fittedSize &&
            pendingPresentationPage.nativeZoomBaseSize ==
                page.nativeZoomBaseSize &&
            pendingPresentationPage.cornerRadius == page.cornerRadius
    }

    private func commitPresentation(_ page: S2NativePageContent) {
        UIView.performWithoutAnimation {
            self.applyPageImmediately(
                page,
                configuration: self.latestConfiguration,
                countsAsPresentationCommit: true,
                onlyIfContentVersionChanged: true
            )
            self.zoomScrollView.applyNativeState(
                scale: 1,
                viewportOffset: .zero
            )
            self.applyCornerMask()
        }
    }

    private func applyPageImmediately(
        _ page: S2NativePageContent,
        configuration: S2CalibrationConfiguration,
        countsAsPresentationCommit: Bool,
        onlyIfContentVersionChanged: Bool = false
    ) {
        presentationTransitionGeneration += 1
        presentationCompletionWorkItem?.cancel()
        presentationCompletionWorkItem = nil
        zoomScrollView.removeAllPhotoAnimations(
            source: "S2NativeZoomPageController.applyPageImmediately"
        )
        removeFitBorderAnimations(
            source: "S2NativeZoomPageController.applyPageImmediately"
        )
        isPresentationTransitionActive = false
        pendingPresentationPage = nil
        assetID = page.assetID
        zoomScrollView.updateDiagnosticContext(
            pageIndex: index,
            assetLocalIdentifier: assetID
        )
        interfaceVisibility = page.interfaceVisibility
        isFramedPhoto = page.isFramedPhoto
        fittedSize = page.fittedSize
        nativeZoomBaseSize = page.nativeZoomBaseSize
        cornerRadius = page.cornerRadius
        assetPixelSize = page.assetPixelSize
        applyPhotoContent(
            page,
            onlyIfVersionChanged: onlyIfContentVersionChanged
        )
        zoomScrollView.configure(
            contentView: hostingController.view,
            fittedSize: fittedSize,
            nativeZoomBaseSize: nativeZoomBaseSize,
            viewportSize: latestViewportSize,
            maximumZoomScale: CGFloat(configuration.pinchMaxScale),
            assetPixelSize: assetPixelSize
        )
        applyCornerMask()
        zoomScrollView.layoutIfNeeded()
        if countsAsPresentationCommit {
            presentationGeometryCommitCount += 1
        }
    }

    private func applyPhotoContent(
        _ page: S2NativePageContent,
        onlyIfVersionChanged: Bool
    ) {
        if onlyIfVersionChanged,
           contentVersion == page.contentVersion {
            return
        }
        contentVersion = page.contentVersion
        hostingController.rootView = AnyView(
            page.content.ignoresSafeArea()
        )
    }

    func prioritizeVerticalSwipe(
        over pagingPanGestureRecognizer: UIPanGestureRecognizer
    ) {
        guard !nativeScrollPriorityIsConfigured else {
            return
        }
        zoomScrollView.panGestureRecognizer.require(
            toFail: verticalSwipeRecognizer
        )
        pagingPanGestureRecognizer.require(
            toFail: verticalSwipeRecognizer
        )
        nativeScrollPriorityIsConfigured = true
    }

    @discardableResult
    func applyRecognizedSingleTap(
        decisionLatencyMilliseconds: Double? = nil
    ) -> Bool {
        if let decisionLatencyMilliseconds {
            let reading = tapDecisionPolicy.reading(
                latencyMilliseconds: decisionLatencyMilliseconds
            )
            lastTapDecisionReading = reading
            owner?.recordTapDecisionReading(reading)
        }
        return owner?.handleSingleTap(on: self) == true
    }

    @discardableResult
    func applyRecognizedDoubleTap(at location: CGPoint) -> Bool {
        return owner?.handleDoubleTap(
            on: self,
            at: location
        ) == true
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView === zoomScrollView
            ? zoomScrollView.zoomContentView
            : nil
    }

    func scrollViewWillBeginZooming(
        _ scrollView: UIScrollView,
        with view: UIView?
    ) {
        let pinchState = scrollView.pinchGestureRecognizer?.state
        guard scrollView === zoomScrollView,
              pinchState == .began || pinchState == .changed,
              owner?.beginNativePinch(on: self) == true else {
            return
        }
        zoomScrollView.prepareForNativeZoom {
            self.applyCornerMask(forceNx: true)
        }
        pinchIsActive = true
        pinchStartDate = Date()
        pinchStartScale = zoomScrollView.zoomScale
        pinchPeakVelocity = 0
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard scrollView === zoomScrollView else {
            return
        }
        zoomScrollView.setNeedsLayout()
        zoomScrollView.layoutIfNeeded()
        zoomScrollView.updatePanAvailability()
        if pinchIsActive {
            pinchPeakVelocity = max(
                pinchPeakVelocity,
                abs(zoomScrollView.pinchGestureRecognizer?.velocity ?? 0)
            )
        }
        owner?.reportNativeViewport(from: self)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === zoomScrollView,
              !zoomScrollView.isApplyingNativeState else {
            return
        }
        owner?.reportNativeViewport(from: self)
    }

    func scrollViewDidEndZooming(
        _ scrollView: UIScrollView,
        with view: UIView?,
        atScale scale: CGFloat
    ) {
        guard scrollView === zoomScrollView else {
            return
        }
        let endedAtMinimum = abs(
            scale - zoomScrollView.minimumZoomScale
        ) <= 0.000_001
        if pinchIsActive {
            let duration = Date().timeIntervalSince(pinchStartDate ?? Date())
            let displacement = abs(
                scale / max(0.000_001, pinchStartScale) - 1
            )
            pinchIsActive = false
            owner?.finishNativePinch(
                on: self,
                scale: scale,
                displacement: displacement,
                peakVelocity: pinchPeakVelocity,
                duration: duration
            )
            pinchStartDate = nil
            pinchPeakVelocity = 0
        }
        if endedAtMinimum {
            completeNativeOneXReturn()
        }
        applyDeferredPresentationIfPossible()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === zoomScrollView else {
            return
        }
        completeNativeOneXReturn()
        applyDeferredPresentationIfPossible()
    }

    private func completeNativeOneXReturn() {
        zoomScrollView.restoreOneXGeometry()
        applyCornerMask()
        owner?.reportNativeViewport(from: self)
    }

    func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === verticalSwipeRecognizer else {
            return true
        }
        let velocity = verticalSwipeRecognizer.velocity(in: zoomScrollView)
        return shouldBeginVerticalSwipe(for: velocity)
    }

    func shouldBeginVerticalSwipe(for velocity: CGPoint) -> Bool {
        guard owner?.allowsVerticalSwipeRecognition(on: self) == true else {
            return false
        }
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        if gestureRecognizer === singleTapRecognizer,
           touch.tapCount == 1 {
            singleTapTouchTimestamp = touch.timestamp
        }
        return true
    }

    /// IC-070 R6：描边层与照片层共用同一组过渡关键帧，但过渡动画组以
    /// `isRemovedOnCompletion = false` 挂载。过渡收口只清照片层动画时，
    /// 描边层会停留在过渡末帧的层内半径与线宽（例如 28/0.7、1/0.7），
    /// 而照片层已复位到 28 与恒等变换——描边因此比照片圆角更圆并向内收。
    /// 收口与非过渡期的几何提交必须把描边层动画一并移除。
    private func removeFitBorderAnimations(source: String) {
        guard let keys = fitBorderLayer.animationKeys(),
              !keys.isEmpty else {
            return
        }
        transitionDiagnostics?.recordPhotoAnimationOperation(
            operation: "removeAllAnimations",
            key: "fitBorderLayer.*",
            source: source
        )
        fitBorderLayer.removeAllAnimations()
    }

    private func applyCornerMask(forceNx: Bool = false) {
        if !isPresentationTransitionActive {
            removeFitBorderAnimations(
                source: "S2NativeZoomPageController.applyCornerMask"
            )
        }
        let isNx = forceNx || zoomScrollView.zoomScale >
            zoomScrollView.minimumZoomScale + 0.000_001
        let resolvedRadius = isNx
            ? 0
            : max(0, cornerRadius)
        let borderWidth = isNx ? 0 : resolvedFitBorderWidth()
        if hostingController.view.transform != .identity {
            zoomScrollView.writePhotoGeometry(reason: .cornerMaskReset) {
                contentView in
                contentView.transform = .identity
            }
        }
        let photoLayer = hostingController.view.layer
        if photoLayer.cornerRadius != resolvedRadius {
            photoLayer.cornerRadius = resolvedRadius
        }
        photoLayer.cornerCurve = .continuous
        if photoLayer.borderWidth != 0 {
            photoLayer.borderWidth = 0
        }
        applyBorderColor()
        let shouldMask = resolvedRadius > 0
        if photoLayer.masksToBounds != shouldMask {
            photoLayer.masksToBounds = shouldMask
        }
        if fitBorderLayer.frame != hostingController.view.bounds {
            fitBorderLayer.frame = hostingController.view.bounds
        }
        if fitBorderLayer.cornerRadius != resolvedRadius {
            fitBorderLayer.cornerRadius = resolvedRadius
        }
        fitBorderLayer.cornerCurve = .continuous
        if fitBorderLayer.borderWidth != borderWidth {
            fitBorderLayer.borderWidth = borderWidth
        }
        if fitBorderLayer.superlayer !== photoLayer ||
            photoLayer.sublayers?.last !== fitBorderLayer {
            fitBorderLayer.removeFromSuperlayer()
            photoLayer.addSublayer(fitBorderLayer)
        }
        if let zoomLayer = zoomScrollView.zoomContentView?.layer {
            if zoomLayer.cornerRadius != 0 {
                zoomLayer.cornerRadius = 0
            }
            if zoomLayer.masksToBounds {
                zoomLayer.masksToBounds = false
            }
        }
    }

    private func resolvedFitBorderWidth() -> CGFloat {
        guard interfaceVisibility == .visible,
              isFramedPhoto else {
            return 0
        }
        return max(0, CGFloat(latestConfiguration.fitBorderWidth))
    }

    private func resolvedFitBorderColor(
        userInterfaceStyle: UIUserInterfaceStyle? = nil
    ) -> CGColor {
        let style = userInterfaceStyle ?? traitCollection.userInterfaceStyle
        if style == .dark {
            return UIColor.white.withAlphaComponent(
                CGFloat(latestConfiguration.fitBorderDarkAlpha)
            ).cgColor
        }
        return UIColor.black.withAlphaComponent(
            CGFloat(latestConfiguration.fitBorderLightAlpha)
        ).cgColor
    }

    private func applyBorderColor() {
        fitBorderLayer.borderColor = resolvedFitBorderColor()
    }

    func refreshFitBorderColor(
        userInterfaceStyle: UIUserInterfaceStyle
    ) {
        fitBorderLayer.borderColor = resolvedFitBorderColor(
            userInterfaceStyle: userInterfaceStyle
        )
    }

    @objc private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }
        let latencyMilliseconds = singleTapTouchTimestamp.map {
            max(0, ProcessInfo.processInfo.systemUptime - $0) * 1_000
        }
        singleTapTouchTimestamp = nil
        _ = applyRecognizedSingleTap(
            decisionLatencyMilliseconds: latencyMilliseconds
        )
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }
        _ = applyRecognizedDoubleTap(
            at: recognizer.location(in: zoomScrollView)
        )
    }

    @objc private func handleVerticalSwipe(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            verticalSwipeStartDate = Date()
        case .ended:
            let duration = Date().timeIntervalSince(
                verticalSwipeStartDate ?? Date()
            )
            verticalSwipeStartDate = nil
            _ = owner?.finishVerticalSwipe(
                on: self,
                translation: CGSize(
                    width: recognizer.translation(in: zoomScrollView).x,
                    height: recognizer.translation(in: zoomScrollView).y
                ),
                duration: duration
            )
        case .cancelled, .failed:
            verticalSwipeStartDate = nil
        default:
            break
        }
    }

    @objc private func handleNativePan(_ recognizer: UIPanGestureRecognizer) {
        owner?.handleNativePan(on: self, recognizer: recognizer)
    }
}

struct S2PresentationTapLayoutReading: Equatable {
    var callbackCount = 0
    var photoFrameWriteCount = 0
    var suppressedPhotoFrameWriteCount = 0
    var firstCallbackDelayMilliseconds: Double?
}

final class S2NativePagerViewController: UIViewController,
    UIScrollViewDelegate {
    let pagingScrollView = S2NativePagingScrollView()
    private(set) var pageControllers: [Int: S2NativeZoomPageController] = [:]
    private weak var machine: S2StateMachine?
    private var configuration = S2CalibrationConfiguration.factoryPlaceholder
    private var viewportSize = CGSize.zero
    private var onLongPress: (() -> Void)?
    private var isApplyingSnapshot = false
    private var settledIndex = 0
    private var outerDragStartDate: Date?
    private var lastOuterTranslation = CGSize.zero
    private var lastOuterVelocity: CGFloat = 0
    private var lastOuterDuration: TimeInterval = 0
    private var nXEdgePagingInteraction: S2NxEdgePagingInteraction?
    private var lastNXEdgePagingProjection: S2NxEdgePagingProjection?
    private var pendingPresentationTapPageIndex: Int?
    private var presentationTapStartTimestamp: CFTimeInterval?
    private var isHandlingOuterLayoutCallback = false
    private(set) var nativeZoomReturnInvocationCount = 0
    private(set) var presentationTapLayoutReading =
        S2PresentationTapLayoutReading()
    var diagnosticsRun: S2GeometryDiagnosticsRun?
    weak var transitionDiagnostics:
        S2OnDeviceTransitionDiagnosticsCoordinator? {
        didSet {
            pageControllers.values.forEach {
                $0.transitionDiagnostics = transitionDiagnostics
            }
        }
    }

    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .clear
        rootView.clipsToBounds = true
        rootView.addSubview(pagingScrollView)
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        pagingScrollView.delegate = self
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.8
        longPress.cancelsTouchesInView = false
        view.addGestureRecognizer(longPress)
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle !=
                traitCollection.userInterfaceStyle else {
            return
        }
        pageControllers.values.forEach {
            $0.refreshFitBorderColor(
                userInterfaceStyle: traitCollection.userInterfaceStyle
            )
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let currentPage = diagnosticCurrentPage
        transitionDiagnostics?.recordOuterViewDidLayoutSubviews(
            pageIndex: currentPage?.index,
            assetLocalIdentifier:
                currentPage?.diagnosticAssetLocalIdentifier
        )
        guard view.bounds.size.width > 0, view.bounds.size.height > 0 else {
            return
        }
        if pendingPresentationTapPageIndex != nil {
            presentationTapLayoutReading.callbackCount += 1
            if presentationTapLayoutReading
                .firstCallbackDelayMilliseconds == nil,
               let presentationTapStartTimestamp {
                presentationTapLayoutReading
                    .firstCallbackDelayMilliseconds = max(
                        0,
                        (CACurrentMediaTime() -
                            presentationTapStartTimestamp) * 1_000
                    )
            }
        }
        viewportSize = view.bounds.size
        isHandlingOuterLayoutCallback = true
        layoutNativePages()
        isHandlingOuterLayoutCallback = false
    }

    func apply(
        machine: S2StateMachine,
        configuration: S2CalibrationConfiguration,
        viewportSize: CGSize,
        pages: [S2NativePageContent],
        onLongPress: @escaping () -> Void
    ) {
        loadViewIfNeeded()
        self.machine = machine
        self.configuration = configuration
        self.viewportSize = viewportSize
        self.onLongPress = onLongPress
        isApplyingSnapshot = true

        let pageIndices = Set(pages.map(\.index))
        let removedIndices = pageControllers.keys.filter {
            !pageIndices.contains($0)
        }
        for index in removedIndices {
            guard let controller = pageControllers[index] else {
                continue
            }
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            pageControllers.removeValue(forKey: index)
        }

        for page in pages {
            let controller: S2NativeZoomPageController
            if let existing = pageControllers[page.index] {
                controller = existing
            } else {
                controller = S2NativeZoomPageController(
                    page: page,
                    owner: self
                )
                controller.transitionDiagnostics = transitionDiagnostics
                addChild(controller)
                pagingScrollView.addSubview(controller.view)
                controller.prioritizeVerticalSwipe(
                    over: pagingScrollView.panGestureRecognizer
                )
                controller.didMove(toParent: self)
                pageControllers[page.index] = controller
            }
            controller.update(
                page: page,
                configuration: configuration,
                scale: machine.scale,
                viewportOffset: machine.viewportOffset,
                isCurrent: page.index == machine.currentIndex,
                viewportSize: viewportSize
            )
            if pendingPresentationTapPageIndex == page.index {
                pendingPresentationTapPageIndex = nil
                presentationTapStartTimestamp = nil
            }
        }

        settledIndex = machine.currentIndex
        layoutNativePages()
        if !pagingScrollView.isTracking &&
            !pagingScrollView.isDragging &&
            !pagingScrollView.isDecelerating {
            pagingScrollView.setContentOffset(
                pagingScrollView.contentOffsetForPage(at: settledIndex),
                animated: false
            )
        }
        isApplyingSnapshot = false
    }

    func resetInteractionState() {
        pageControllers.values.forEach {
            $0.finishActiveDoubleTapTransition()
            $0.doubleTapTransitionObserver = nil
        }
        outerDragStartDate = nil
        pendingPresentationTapPageIndex = nil
        presentationTapStartTimestamp = nil
        lastOuterTranslation = .zero
        nXEdgePagingInteraction = nil
        lastNXEdgePagingProjection = nil
        onLongPress = nil
        diagnosticsRun?.cancel()
        diagnosticsRun = nil
    }

    var diagnosticMachine: S2StateMachine? {
        machine
    }

    var diagnosticCurrentPage: S2NativeZoomPageController? {
        guard let machine else {
            return nil
        }
        return pageControllers[machine.currentIndex]
    }

    func beginDiagnosticDoubleTap(
        minimumMiddleFrames: Int,
        observer: @escaping (S2DoubleTapTransitionEvent) -> Void
    ) -> Bool {
        guard let machine,
              let page = diagnosticCurrentPage else {
            return false
        }
        let wasZoomed = machine.zoomState == .nX
        guard machine.handleNativeDoubleTap(
            targetScale: page.doubleTapTargetScale
        ) else {
            return false
        }
        var diagnosticConfiguration = configuration
        diagnosticConfiguration.animationsEnabled = true
        diagnosticConfiguration.animationDurationMilliseconds = max(
            diagnosticConfiguration.animationDurationMilliseconds,
            Double(max(1, minimumMiddleFrames) + 2) * 50
        )
        page.doubleTapTransitionObserver = observer
        return page.startDoubleTapTransition(
            enteringNx: !wasZoomed,
            targetScale: wasZoomed ? 1 : machine.scale,
            at: CGPoint(
                x: viewportSize.width / 2,
                y: viewportSize.height / 2
            ),
            configuration: diagnosticConfiguration
        )
    }

    func normalizeDiagnosticState(
        completion: @escaping (Bool) -> Void
    ) {
        guard let machine else {
            completion(false)
            return
        }
        if let page = diagnosticCurrentPage {
            page.finishActivePresentationTransition()
            page.finishActiveDoubleTapTransition()
        }
        if machine.zoomState == .nX {
            guard let page = diagnosticCurrentPage,
                  machine.handleNativeDoubleTap(
                    targetScale: page.doubleTapTargetScale
                  ) else {
                completion(false)
                return
            }
            var immediateConfiguration = configuration
            immediateConfiguration.animationsEnabled = false
            guard page.startDoubleTapTransition(
                enteringNx: false,
                targetScale: 1,
                at: CGPoint(
                    x: viewportSize.width / 2,
                    y: viewportSize.height / 2
                ),
                configuration: immediateConfiguration
            ) else {
                completion(false)
                return
            }
        }
        if machine.interfaceVisibility == .hidden {
            _ = machine.handleSingleTap()
        }
        waitForDiagnosticStableState(
            visibility: .visible,
            zoomState: .oneX,
            remainingAttempts: 200,
            completion: completion
        )
    }

    func waitForDiagnosticStableState(
        visibility: S2InterfaceVisibility,
        zoomState: S2ZoomState,
        remainingAttempts: Int = 200,
        completion: @escaping (Bool) -> Void
    ) {
        guard remainingAttempts > 0,
              let machine,
              let page = diagnosticCurrentPage else {
            completion(false)
            return
        }
        let zoomMatches = zoomState == .oneX
            ? abs(page.zoomScrollView.zoomScale - 1) <= 0.000_001
            : page.zoomScrollView.zoomScale > 1
        if machine.interfaceVisibility == visibility,
           machine.zoomState == zoomState,
           page.diagnosticInterfaceVisibility == visibility,
           !page.isPresentationTransitionActive,
           !page.isDoubleTapTransitionActive,
           zoomMatches {
            completion(true)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.waitForDiagnosticStableState(
                visibility: visibility,
                zoomState: zoomState,
                remainingAttempts: remainingAttempts - 1,
                completion: completion
            )
        }
    }

    func recordTapDecisionReading(_ reading: S2TapDecisionReading) {
        machine?.recordTapDecisionReading(reading)
    }

    func allowsVerticalSwipeRecognition(
        on page: S2NativeZoomPageController
    ) -> Bool {
        guard let machine,
              page.index == machine.currentIndex else {
            return false
        }
        return machine.scale == 1
    }

    @discardableResult
    func handleSingleTap(on page: S2NativeZoomPageController) -> Bool {
        guard let machine,
              page.index == machine.currentIndex else {
            return false
        }
        pendingPresentationTapPageIndex = page.index
        presentationTapStartTimestamp = CACurrentMediaTime()
        presentationTapLayoutReading = S2PresentationTapLayoutReading()
        let previousVisibility = machine.interfaceVisibility
        let handled = machine.handleSingleTap()
        if handled, previousVisibility != machine.interfaceVisibility {
            transitionDiagnostics?.recordSwiftUIStatePublication(
                from: previousVisibility,
                to: machine.interfaceVisibility
            )
        }
        if !handled {
            pendingPresentationTapPageIndex = nil
            presentationTapStartTimestamp = nil
        }
        return handled
    }

    @discardableResult
    func handleDoubleTap(
        on page: S2NativeZoomPageController,
        at location: CGPoint
    ) -> Bool {
        guard let machine,
              page.index == machine.currentIndex else {
            return false
        }
        let wasZoomed = machine.zoomState == .nX
        guard machine.handleNativeDoubleTap(
            targetScale: page.doubleTapTargetScale
        ) else {
            return false
        }
        let targetScale = wasZoomed ? CGFloat(1) : machine.scale
        if !page.startDoubleTapTransition(
            enteringNx: !wasZoomed,
            targetScale: targetScale,
            at: location,
            configuration: configuration
        ) {
            page.zoomScrollView.applyNativeState(
                scale: targetScale,
                viewportOffset: .zero
            )
        }
        return true
    }

    func doubleTapTransitionDidComplete(
        on page: S2NativeZoomPageController
    ) {
        guard let machine,
              page.index == machine.currentIndex else {
            return
        }
        if machine.scale > 1 {
            reportNativeViewport(from: page)
        }
    }

    func beginNativePinch(on page: S2NativeZoomPageController) -> Bool {
        guard let machine,
              page.index == machine.currentIndex,
              configuration.pinchTouchCount == 2 else {
            return false
        }
        return machine.beginPinch()
    }

    func reportNativeViewport(from page: S2NativeZoomPageController) {
        guard let machine,
              page.index == machine.currentIndex,
              !page.zoomScrollView.isApplyingNativeState else {
            return
        }
        machine.reportNativeViewport(
            scale: page.zoomScrollView.zoomScale,
            viewportOffset: page.zoomScrollView.reportedViewportOffset()
        )
    }

    func finishNativePinch(
        on page: S2NativeZoomPageController,
        scale: CGFloat,
        displacement: CGFloat,
        peakVelocity: CGFloat,
        duration: TimeInterval
    ) {
        guard let machine, page.index == machine.currentIndex else {
            return
        }
        machine.recordGestureReading(S2GestureReading(
            displacementDistance: displacement,
            peakVelocity: peakVelocity,
            duration: duration
        ))
        // IC-074：原 pinchMinimumVelocityPerSecond / pinchMaximumDurationMilliseconds
        // 过滤已随参数废止删除；出厂值均为 0（语义为无限制），过滤恒通过，
        // 因此这里恒以 accepted=true 交给状态机，行为不变。
        guard let targetScale = machine.finishNativePinch(
            scale: scale,
            viewportOffset: page.zoomScrollView.reportedViewportOffset(),
            accepted: true
        ) else {
            return
        }
        if abs(
            targetScale - page.zoomScrollView.minimumZoomScale
        ) <= 0.000_001 {
            returnToMinimumZoomScale(on: page)
        } else if abs(
            page.zoomScrollView.zoomScale - targetScale
        ) > 0.000_001 {
            page.zoomScrollView.setZoomScale(
                targetScale,
                animated: configuration.animationsEnabled
            )
        }
        page.zoomScrollView.updatePanAvailability()
    }

    private func returnToMinimumZoomScale(
        on page: S2NativeZoomPageController
    ) {
        nativeZoomReturnInvocationCount += 1
        page.zoomScrollView.animateToMinimumZoomScale()
    }

    @discardableResult
    func finishVerticalSwipe(
        on page: S2NativeZoomPageController,
        translation: CGSize,
        duration: TimeInterval
    ) -> Bool {
        guard let machine, page.index == machine.currentIndex else {
            return false
        }
        let distance = hypot(translation.width, translation.height)
        let velocity = duration > 0
            ? distance / CGFloat(duration)
            : CGFloat.infinity
        machine.recordGestureReading(S2GestureReading(
            displacementDistance: distance,
            peakVelocity: velocity,
            duration: duration
        ))
        let previousIndex = machine.currentIndex
        let handled = machine.completeMainDrag(
            translation: translation,
            duration: duration,
            startedOffset: machine.viewportOffset,
            viewportSize: viewportSize,
            fittedSize: page.fittedSize
        )
        if machine.currentIndex != previousIndex {
            settledIndex = machine.currentIndex
            synchronizeNativeStateToMachine(animatedPaging: false)
        }
        return handled
    }

    func handleNativePan(
        on page: S2NativeZoomPageController,
        recognizer: UIPanGestureRecognizer
    ) {
        guard let machine,
              page.index == machine.currentIndex,
              machine.zoomState == .nX else {
            resetNXEdgePaging(animated: false)
            return
        }
        switch recognizer.state {
        case .began:
            beginNXEdgePaging(on: page, recognizer: recognizer)
        case .changed:
            updateNXEdgePaging(recognizer: recognizer)
        case .ended:
            updateNXEdgePaging(recognizer: recognizer)
            finishNXEdgePaging(
                velocity: abs(recognizer.velocity(
                    in: page.zoomScrollView
                ).x)
            )
        case .cancelled, .failed:
            resetNXEdgePaging(
                animated: configuration.animationsEnabled
            )
        default:
            break
        }
    }

    private func beginNXEdgePaging(
        on page: S2NativeZoomPageController,
        recognizer: UIPanGestureRecognizer
    ) {
        guard let machine,
              let contentFrame = page.zoomScrollView.visibleContentFrame()
        else {
            return
        }
        let bounds = page.zoomScrollView.bounds
        nXEdgePagingInteraction = S2NxEdgePagingInteraction(
            restingPagingOffsetX: pagingScrollView
                .contentOffsetForPage(at: machine.currentIndex).x,
            pageStride: pagingScrollView.pageStride,
            translationOriginX: recognizer.translation(
                in: page.zoomScrollView
            ).x,
            distanceToPreviousBoundary: max(
                0,
                bounds.minX - contentFrame.minX
            ),
            distanceToNextBoundary: max(
                0,
                contentFrame.maxX - bounds.maxX
            )
        )
        lastNXEdgePagingProjection = nil
    }

    private func updateNXEdgePaging(recognizer: UIPanGestureRecognizer) {
        guard let machine, let interaction = nXEdgePagingInteraction else {
            return
        }
        let projection = interaction.projection(
            translationX: recognizer.translation(in: pagingScrollView).x
        )
        lastNXEdgePagingProjection = projection
        guard let direction = projection.direction,
              machine.orderedAssetIDs.indices.contains(
                machine.currentIndex + direction.indexOffset
              ) else {
            pagingScrollView.setContentOffset(
                CGPoint(
                    x: interaction.restingPagingOffsetX,
                    y: pagingScrollView.contentOffset.y
                ),
                animated: false
            )
            return
        }
        pagingScrollView.setContentOffset(
            CGPoint(
                x: projection.pagingContentOffsetX,
                y: pagingScrollView.contentOffset.y
            ),
            animated: false
        )
    }

    private func finishNXEdgePaging(velocity: CGFloat) {
        guard let machine,
              let projection = lastNXEdgePagingProjection,
              let direction = projection.direction else {
            resetNXEdgePaging(animated: configuration.animationsEnabled)
            return
        }
        _ = machine.handleHorizontalSwipe(
            direction: direction,
            startedAtPagingEdge: projection.overflowDistance > 0,
            distance: projection.overflowDistance,
            velocity: velocity
        )
        settledIndex = machine.currentIndex
        nXEdgePagingInteraction = nil
        lastNXEdgePagingProjection = nil
        synchronizeNativeStateToMachine(
            animatedPaging: configuration.animationsEnabled
        )
    }

    private func resetNXEdgePaging(animated: Bool) {
        guard nXEdgePagingInteraction != nil ||
                lastNXEdgePagingProjection != nil else {
            return
        }
        nXEdgePagingInteraction = nil
        lastNXEdgePagingProjection = nil
        synchronizeNativeStateToMachine(animatedPaging: animated)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === pagingScrollView else {
            return
        }
        outerDragStartDate = Date()
        lastOuterTranslation = .zero
        lastOuterVelocity = 0
        lastOuterDuration = 0
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        guard scrollView === pagingScrollView else {
            return
        }
        captureOuterGestureReading()
        let handledVerticalGesture = handleOneXVerticalGestureIfNeeded()
        if handledVerticalGesture || !decelerate {
            finishNativePaging()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === pagingScrollView else {
            return
        }
        finishNativePaging()
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        onLongPress?()
    }

    private func layoutNativePages() {
        let previousApplyingState = isApplyingSnapshot
        isApplyingSnapshot = true
        pagingScrollView.configure(
            viewportSize: viewportSize,
            itemCount: machine?.orderedAssetIDs.count ?? 0,
            pageSpacing: CGFloat(configuration.pageSpacing)
        )
        for (index, controller) in pageControllers {
            let pageFrame = pagingScrollView.frameForPage(at: index)
            if controller.view.frame != pageFrame {
                controller.view.frame = pageFrame
            }
            let canApplyNativeState =
                !controller.isDoubleTapTransitionActive &&
                !controller.isPresentationTransitionActive &&
                !controller.zoomScrollView.isTracking &&
                !controller.zoomScrollView.isDragging &&
                !controller.zoomScrollView.isDecelerating &&
                !controller.zoomScrollView.isZooming
            if let machine,
               canApplyNativeState,
               index != pendingPresentationTapPageIndex {
                if isHandlingOuterLayoutCallback,
                   pendingPresentationTapPageIndex != nil,
                   index == machine.currentIndex {
                    presentationTapLayoutReading.photoFrameWriteCount += 1
                }
                controller.zoomScrollView.applyNativeState(
                    scale: index == machine.currentIndex ? machine.scale : 1,
                    viewportOffset: index == machine.currentIndex
                        ? machine.viewportOffset
                        : .zero
                )
            } else if canApplyNativeState,
                      index == pendingPresentationTapPageIndex,
                      isHandlingOuterLayoutCallback {
                presentationTapLayoutReading
                    .suppressedPhotoFrameWriteCount += 1
                transitionDiagnostics?.recordOuterLayoutSuppression(
                    pageIndex: index,
                    assetLocalIdentifier:
                        controller.diagnosticAssetLocalIdentifier
                )
            }
        }
        if !pagingScrollView.isTracking &&
            !pagingScrollView.isDragging &&
            !pagingScrollView.isDecelerating {
            let settledOffset = pagingScrollView.contentOffsetForPage(
                at: settledIndex
            )
            if pagingScrollView.contentOffset != settledOffset {
                pagingScrollView.contentOffset = settledOffset
            }
        }
        isApplyingSnapshot = previousApplyingState
    }

    private func captureOuterGestureReading() {
        let translation = pagingScrollView.panGestureRecognizer.translation(
            in: pagingScrollView
        )
        let velocity = pagingScrollView.panGestureRecognizer.velocity(
            in: pagingScrollView
        )
        lastOuterTranslation = CGSize(
            width: translation.x,
            height: translation.y
        )
        lastOuterVelocity = hypot(velocity.x, velocity.y)
        lastOuterDuration = Date().timeIntervalSince(
            outerDragStartDate ?? Date()
        )
        machine?.recordGestureReading(S2GestureReading(
            displacementDistance: hypot(translation.x, translation.y),
            peakVelocity: lastOuterVelocity,
            duration: lastOuterDuration
        ))
    }

    private func handleOneXVerticalGestureIfNeeded() -> Bool {
        guard let machine,
              machine.zoomState == .oneX,
              S2StateMachine.dragDirection(
                for: lastOuterTranslation
              ) == .vertical,
              let page = pageControllers[machine.currentIndex] else {
            return false
        }
        let previousIndex = machine.currentIndex
        _ = machine.completeMainDrag(
            translation: lastOuterTranslation,
            duration: lastOuterDuration,
            startedOffset: .zero,
            viewportSize: viewportSize,
            fittedSize: page.fittedSize
        )
        if machine.currentIndex != previousIndex {
            synchronizeNativeStateToMachine(animatedPaging: false)
        }
        return true
    }

    private func finishNativePaging() {
        guard let machine else {
            return
        }
        let targetIndex = pagingScrollView.pageIndex(
            forContentOffsetX: pagingScrollView.contentOffset.x
        )
        let previousIndex = machine.currentIndex
        if targetIndex != previousIndex {
            _ = machine.handleNativePageChange(to: targetIndex)
        } else if targetIndex == previousIndex {
            reportSequenceBoundaryAttemptIfNeeded()
        }
        settledIndex = machine.currentIndex
        synchronizeNativeStateToMachine(animatedPaging: false)
        outerDragStartDate = nil
    }

    private func synchronizeNativeStateToMachine(animatedPaging: Bool) {
        guard let machine else {
            return
        }
        isApplyingSnapshot = true
        for (index, controller) in pageControllers {
            controller.zoomScrollView.applyNativeState(
                scale: index == machine.currentIndex ? machine.scale : 1,
                viewportOffset: index == machine.currentIndex
                    ? machine.viewportOffset
                    : .zero
            )
        }
        pagingScrollView.setContentOffset(
            pagingScrollView.contentOffsetForPage(at: machine.currentIndex),
            animated: animatedPaging
        )
        isApplyingSnapshot = false
    }

    private func reportSequenceBoundaryAttemptIfNeeded() {
        guard let machine,
              S2StateMachine.dragDirection(
                for: lastOuterTranslation
              ) == .horizontal else {
            return
        }
        let direction: S2PageDirection = lastOuterTranslation.width < 0
            ? .next
            : .previous
        let destination = machine.currentIndex + direction.indexOffset
        guard !machine.orderedAssetIDs.indices.contains(destination) else {
            return
        }
        let distance = abs(lastOuterTranslation.width)
        let velocity = lastOuterDuration > 0
            ? max(lastOuterVelocity, distance / CGFloat(lastOuterDuration))
            : CGFloat.infinity
        _ = machine.handleHorizontalSwipe(
            direction: direction,
            startedAtPagingEdge: true,
            distance: distance,
            velocity: velocity
        )
    }

}

final class S2GeometryDiagnosticsCoordinator: ObservableObject {
    @Published private(set) var reportText = ""
    @Published private(set) var isExporting = false
    private weak var controller: S2NativePagerViewController?

    func attach(_ controller: S2NativePagerViewController) {
        self.controller = controller
    }

    func detach(_ controller: S2NativePagerViewController) {
        guard self.controller === controller else {
            return
        }
        controller.diagnosticsRun?.cancel()
        controller.diagnosticsRun = nil
        self.controller = nil
    }

    func export() {
        guard !isExporting,
              let controller else {
            return
        }
        isExporting = true
        reportText = ""
        let run = S2GeometryDiagnosticsRun(controller: controller) {
            [weak self, weak controller] report in
            self?.reportText = report
            self?.isExporting = false
            controller?.diagnosticsRun = nil
        }
        controller.diagnosticsRun = run
        run.start()
    }
}

struct S2GeometryDiagnosticSample {
    let label: String
    let visibility: S2InterfaceVisibility
    let scale: CGFloat
    let screenBounds: CGRect
    let screenScale: CGFloat
    let windowBounds: CGRect
    let scrollFrame: CGRect
    let scrollBounds: CGRect
    let safeAreaInsets: UIEdgeInsets
    let hostingSafeAreaInsets: UIEdgeInsets
    let additionalSafeAreaInsets: UIEdgeInsets
    let hostingAdditionalSafeAreaInsets: UIEdgeInsets
    let adjustmentBehaviorRawValue: Int
    let contentInset: UIEdgeInsets
    let adjustedContentInset: UIEdgeInsets
    let contentSize: CGSize
    let contentOffset: CGPoint
    let zoomScale: CGFloat
    let minimumZoomScale: CGFloat
    let maximumZoomScale: CGFloat
    let innerWindowFrame: CGRect
    let innerBounds: CGRect
    let innerTransform: CGAffineTransform
    let transitionTransform: CGAffineTransform
    let cornerRadius: CGFloat
    let masksToBounds: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    let normalizedAssetAspectRatio: CGFloat
    let normalizedViewportAspectRatio: CGFloat
    let aspectDifferencePercent: CGFloat
    let screenAspectMatch: Bool
    let statusBarChain: String
    let effectiveStatusBarHidden: Bool
    let verticalRecognizers: String
    let topBlank: CGFloat
    let contentInsetTopContribution: CGFloat
    let safeAreaTopContribution: CGFloat
    let aspectFitTopContribution: CGFloat
}

final class S2GeometryDiagnosticsRun {
    private weak var controller: S2NativePagerViewController?
    private let completion: (String) -> Void
    private var samples: [S2GeometryDiagnosticSample] = []
    private var errors: [String] = []
    private var cancelled = false
    private var middleThresholds: [CGFloat] = []
    private var activeMiddlePrefix = ""

    init(
        controller: S2NativePagerViewController,
        completion: @escaping (String) -> Void
    ) {
        self.controller = controller
        self.completion = completion
    }

    func start() {
        guard let controller else {
            finish(with: "诊断失败：主图控制器不存在。")
            return
        }
        controller.normalizeDiagnosticState { [weak self] succeeded in
            guard let self, !self.cancelled else {
                return
            }
            guard succeeded else {
                self.finish(with: "诊断失败：无法归一到 V=显示、s=1。")
                return
            }
            self.capture("V=显示、s=1 稳定态")
            self.toggleToHidden()
        }
    }

    func cancel() {
        cancelled = true
        controller?.diagnosticCurrentPage?.doubleTapTransitionObserver = nil
    }

    private func stabilityDescription(
        controller: S2NativePagerViewController,
        visibility: S2InterfaceVisibility,
        zoomState: S2ZoomState
    ) -> String {
        guard let machine = controller.diagnosticMachine,
              let page = controller.diagnosticCurrentPage else {
            return "状态机或当前页不存在"
        }
        let zoomMatches = zoomState == .oneX
            ? abs(page.zoomScrollView.zoomScale - 1) <= 0.000_001
            : page.zoomScrollView.zoomScale > 1
        return [
            "状态机V匹配=\(machine.interfaceVisibility == visibility)",
            "状态机缩放态匹配=\(machine.zoomState == zoomState)",
            "页面V匹配=\(page.diagnosticInterfaceVisibility == visibility)",
            "显隐转场中=\(page.isPresentationTransitionActive)",
            "双击转场中=\(page.isDoubleTapTransitionActive)",
            "原生缩放匹配=\(zoomMatches)",
            "原生倍率=\(page.zoomScrollView.zoomScale)"
        ].joined(separator: "，")
    }

    private func toggleToHidden() {
        guard let controller,
              let machine = controller.diagnosticMachine,
              machine.handleSingleTap() else {
            finish(with: "诊断失败：无法切换到 V=隐藏。")
            return
        }
        controller.waitForDiagnosticStableState(
            visibility: .hidden,
            zoomState: .oneX
        ) { [weak self] succeeded in
            guard let self, !self.cancelled else {
                return
            }
            guard succeeded else {
                self.finish(
                    with: "诊断失败：V=隐藏、s=1 未稳定；" +
                        self.stabilityDescription(
                            controller: controller,
                            visibility: .hidden,
                            zoomState: .oneX
                        ) + "。"
                )
                return
            }
            self.capture("单击后 V=隐藏、s=1 稳定态")
            self.toggleBackToVisible()
        }
    }

    private func toggleBackToVisible() {
        guard let controller,
              let machine = controller.diagnosticMachine,
              machine.handleSingleTap() else {
            finish(with: "诊断失败：无法切回 V=显示。")
            return
        }
        controller.waitForDiagnosticStableState(
            visibility: .visible,
            zoomState: .oneX
        ) { [weak self] succeeded in
            guard let self, !self.cancelled else {
                return
            }
            guard succeeded else {
                self.finish(
                    with: "诊断失败：V=显示、s=1 未稳定；" +
                        self.stabilityDescription(
                            controller: controller,
                            visibility: .visible,
                            zoomState: .oneX
                        ) + "。"
                )
                return
            }
            self.capture("再次单击回 V=显示 稳定态")
            self.startDoubleTapEntry()
        }
    }

    private func startDoubleTapEntry() {
        capture("双击进入 Nx：动画开始前一帧")
        startDoubleTap(
            minimumMiddleFrames: 3,
            middlePrefix: "双击进入 Nx：动画中间帧",
            stableVisibility: .visible,
            stableZoomState: .nX,
            completionLabel: "双击进入 Nx：动画结束稳定态"
        ) { [weak self] in
            self?.startDoubleTapExit()
        }
    }

    private func startDoubleTapExit() {
        capture("双击退出 Nx：动画开始前一帧")
        startDoubleTap(
            minimumMiddleFrames: 5,
            middlePrefix: "双击退出 Nx：动画中间帧",
            stableVisibility: .visible,
            stableZoomState: .oneX,
            completionLabel: "双击退出 Nx：动画结束稳定态"
        ) { [weak self] in
            self?.finishReport()
        }
    }

    private func startDoubleTap(
        minimumMiddleFrames: Int,
        middlePrefix: String,
        stableVisibility: S2InterfaceVisibility,
        stableZoomState: S2ZoomState,
        completionLabel: String,
        onComplete: @escaping () -> Void
    ) {
        guard let controller else {
            finish(with: "诊断失败：双击阶段缺少控制器。")
            return
        }
        activeMiddlePrefix = middlePrefix
        middleThresholds = (1...minimumMiddleFrames).map {
            CGFloat($0) / CGFloat(minimumMiddleFrames + 1)
        }
        let started = controller.beginDiagnosticDoubleTap(
            minimumMiddleFrames: minimumMiddleFrames
        ) { [weak self] event in
            guard let self, !self.cancelled else {
                return
            }
            switch event {
            case .started:
                break
            case let .progressed(_, progress):
                if let threshold = self.middleThresholds.first,
                   progress >= threshold,
                   progress < 1 {
                    let number = minimumMiddleFrames -
                        self.middleThresholds.count + 1
                    self.capture("\(self.activeMiddlePrefix) #\(number)")
                    self.middleThresholds.removeFirst()
                }
            case .completed:
                controller.diagnosticCurrentPage?
                    .doubleTapTransitionObserver = nil
                if !self.middleThresholds.isEmpty {
                    self.errors.append(
                        "\(middlePrefix) 少于 \(minimumMiddleFrames) 帧"
                    )
                }
                controller.waitForDiagnosticStableState(
                    visibility: stableVisibility,
                    zoomState: stableZoomState
                ) { [weak self] succeeded in
                    guard let self, !self.cancelled else {
                        return
                    }
                    guard succeeded else {
                        self.finish(
                            with: "诊断失败：双击终态未稳定；" +
                                self.stabilityDescription(
                                    controller: controller,
                                    visibility: stableVisibility,
                                    zoomState: stableZoomState
                                ) + "。"
                        )
                        return
                    }
                    self.capture(completionLabel)
                    onComplete()
                }
            }
        }
        if !started {
            finish(with: "诊断失败：无法启动双击转场。")
        }
    }

    private func capture(_ label: String) {
        guard let controller,
              let machine = controller.diagnosticMachine,
              let page = controller.diagnosticCurrentPage,
              let innerView = page.zoomScrollView.presentationContentView else {
            errors.append("\(label)：缺少运行时视图")
            return
        }
        let scrollView = page.zoomScrollView
        let window = controller.view.window
        let windowBounds = window?.bounds ?? .zero
        let innerFrame = innerView.convert(innerView.bounds, to: window)
        let viewportFrame = scrollView.convert(scrollView.bounds, to: window)
        let pixelWidth = max(0, Int(page.assetPixelSize.width.rounded()))
        let pixelHeight = max(0, Int(page.assetPixelSize.height.rounded()))
        let assetRatio = pixelWidth > 0 && pixelHeight > 0
            ? CGFloat(pixelWidth) / CGFloat(pixelHeight)
            : page.nativeZoomBaseSize.width /
                max(0.000_001, page.nativeZoomBaseSize.height)
        let viewportRatio = scrollView.bounds.width /
            max(0.000_001, scrollView.bounds.height)
        let normalizedAssetRatio = min(assetRatio, 1 / assetRatio)
        let normalizedViewportRatio = min(viewportRatio, 1 / viewportRatio)
        let difference = abs(
            normalizedAssetRatio - normalizedViewportRatio
        ) / max(0.000_001, normalizedViewportRatio) * 100
        let isMatch = S2Geometry.isScreenAspectMatch(
            assetAspectRatio: assetRatio,
            viewportAspectRatio: viewportRatio
        )
        let physicalViewportTop = windowBounds.minY
        let topBlank = max(0, innerFrame.minY - physicalViewportTop)
        let insetContribution = max(0, scrollView.contentInset.top)
        let safeContribution = max(
            0,
            viewportFrame.minY - physicalViewportTop
        )
        let aspectContribution = max(
            0,
            topBlank - insetContribution - safeContribution
        )
        let status = statusBarReading(window: window)
        let vertical = controller.pageControllers.keys.sorted().compactMap {
            index -> String? in
            guard let item = controller.pageControllers[index] else {
                return nil
            }
            return "页\(index):state=\(item.verticalSwipeRecognizer.state.rawValue)," +
                "begin=\(controller.allowsVerticalSwipeRecognition(on: item))"
        }.joined(separator: ";")

        samples.append(S2GeometryDiagnosticSample(
            label: label,
            visibility: machine.interfaceVisibility,
            scale: machine.scale,
            screenBounds: UIScreen.main.bounds,
            screenScale: UIScreen.main.scale,
            windowBounds: windowBounds,
            scrollFrame: scrollView.frame,
            scrollBounds: scrollView.bounds,
            safeAreaInsets: page.view.safeAreaInsets,
            hostingSafeAreaInsets: page.diagnosticHostingSafeAreaInsets,
            additionalSafeAreaInsets: page.additionalSafeAreaInsets,
            hostingAdditionalSafeAreaInsets:
                page.diagnosticAdditionalSafeAreaInsets,
            adjustmentBehaviorRawValue:
                scrollView.contentInsetAdjustmentBehavior.rawValue,
            contentInset: scrollView.contentInset,
            adjustedContentInset: scrollView.adjustedContentInset,
            contentSize: scrollView.contentSize,
            contentOffset: scrollView.contentOffset,
            zoomScale: scrollView.zoomScale,
            minimumZoomScale: scrollView.minimumZoomScale,
            maximumZoomScale: scrollView.maximumZoomScale,
            innerWindowFrame: innerFrame,
            innerBounds: innerView.bounds,
            innerTransform: innerView.transform,
            transitionTransform: page.diagnosticTransitionTransform,
            cornerRadius: innerView.layer.cornerRadius,
            masksToBounds: innerView.layer.masksToBounds,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            normalizedAssetAspectRatio: normalizedAssetRatio,
            normalizedViewportAspectRatio: normalizedViewportRatio,
            aspectDifferencePercent: difference,
            screenAspectMatch: isMatch,
            statusBarChain: status.chain,
            effectiveStatusBarHidden: status.isHidden,
            verticalRecognizers: vertical,
            topBlank: topBlank,
            contentInsetTopContribution: insetContribution,
            safeAreaTopContribution: safeContribution,
            aspectFitTopContribution: aspectContribution
        ))
    }

    private func statusBarReading(
        window: UIWindow?
    ) -> (chain: String, isHidden: Bool) {
        guard var current = window?.rootViewController else {
            return ("无根控制器", false)
        }
        var values: [String] = []
        var visited = Set<ObjectIdentifier>()
        while !visited.contains(ObjectIdentifier(current)) {
            visited.insert(ObjectIdentifier(current))
            values.append(
                "\(String(describing: type(of: current)))=" +
                    "\(current.prefersStatusBarHidden)"
            )
            if let presented = current.presentedViewController {
                current = presented
            } else if let child = current.childForStatusBarHidden {
                current = child
            } else {
                break
            }
        }
        return (values.joined(separator: " -> "), current.prefersStatusBarHidden)
    }

    private func finishReport() {
        finish(with: makeReport())
    }

    private func finish(with text: String) {
        guard !cancelled else {
            return
        }
        completion(text)
    }

    private func makeReport() -> String {
        var lines = [
            "# S2 几何诊断",
            "",
            "采样总数：\(samples.count)",
            "中间帧门禁：\(errors.isEmpty ? "通过" : "失败")"
        ]
        if !errors.isEmpty {
            lines.append("错误：\(errors.joined(separator: "；"))")
        }
        for sample in samples {
            lines.append(contentsOf: [
                "",
                "## \(sample.label)",
                "V=\(visibilityText(sample.visibility)), s=\(number(sample.scale))",
                "UIScreen.main.bounds=\(rect(sample.screenBounds))",
                "UIScreen.main.scale=\(number(sample.screenScale))",
                "window.bounds=\(rect(sample.windowBounds))",
                "scrollView.frame=\(rect(sample.scrollFrame))",
                "scrollView.bounds=\(rect(sample.scrollBounds))",
                "view.safeAreaInsets=\(insets(sample.safeAreaInsets))",
                "hosting.view.safeAreaInsets=\(insets(sample.hostingSafeAreaInsets))",
                "additionalSafeAreaInsets=\(insets(sample.additionalSafeAreaInsets))",
                "hosting.additionalSafeAreaInsets=\(insets(sample.hostingAdditionalSafeAreaInsets))",
                "contentInsetAdjustmentBehavior.rawValue=\(sample.adjustmentBehaviorRawValue)",
                "contentInset=\(insets(sample.contentInset))",
                "adjustedContentInset=\(insets(sample.adjustedContentInset))",
                "contentSize=\(size(sample.contentSize))",
                "contentOffset=\(point(sample.contentOffset))",
                "zoomScale=\(number(sample.zoomScale)), minimumZoomScale=\(number(sample.minimumZoomScale)), maximumZoomScale=\(number(sample.maximumZoomScale))",
                "内层照片 window.frame=\(rect(sample.innerWindowFrame))",
                "内层照片 bounds=\(rect(sample.innerBounds))",
                "内层照片 transform=\(transform(sample.innerTransform))",
                "专用过渡层 transform=\(transform(sample.transitionTransform))",
                "layer.cornerRadius=\(number(sample.cornerRadius)), layer.masksToBounds=\(sample.masksToBounds)",
                "资产 pixelWidth=\(sample.pixelWidth), pixelHeight=\(sample.pixelHeight)",
                "方向归一照片宽高比=\(number(sample.normalizedAssetAspectRatio)), 方向归一视口宽高比=\(number(sample.normalizedViewportAspectRatio)), 差值百分比=\(number(sample.aspectDifferencePercent))%, 屏幕比例判定=\(sample.screenAspectMatch)",
                "状态栏链路=\(sample.statusBarChain), 实际生效隐藏值=\(sample.effectiveStatusBarHidden)",
                "竖向识别器=\(sample.verticalRecognizers)"
            ])
        }
        lines.append(contentsOf: questionAnswers())
        return lines.joined(separator: "\n")
    }

    private func questionAnswers() -> [String] {
        let hidden = samples.first {
            $0.label == "单击后 V=隐藏、s=1 稳定态"
        }
        let stableNx = samples.first {
            $0.label == "双击进入 Nx：动画结束稳定态"
        }
        let nxSamples = samples.filter { $0.scale > 1.000_001 }
        let entryAnimationSamples = samples.filter {
            $0.label.hasPrefix("双击进入 Nx：动画开始前") ||
                $0.label.hasPrefix("双击进入 Nx：动画中间帧")
        }
        let exitAnimationSamples = samples.filter {
            $0.label.hasPrefix("双击退出 Nx：动画开始前") ||
                $0.label.hasPrefix("双击退出 Nx：动画中间帧")
        }
        let visible = samples.first {
            $0.label == "V=显示、s=1 稳定态"
        }
        let exitFrames = samples.filter {
            $0.label.hasPrefix("双击退出 Nx：动画开始前") ||
                $0.label.hasPrefix("双击退出 Nx：动画中间帧")
        }
        var result = ["", "# 逐题回答"]
        if let hidden {
            let contentInsetPixels = hidden.contentInsetTopContribution *
                hidden.screenScale
            let safeAreaPixels = hidden.safeAreaTopContribution *
                hidden.screenScale
            let aspectFitPixels = hidden.aspectFitTopContribution *
                hidden.screenScale
            let topBlankPixels = hidden.topBlank * hidden.screenScale
            let sum = contentInsetPixels + safeAreaPixels + aspectFitPixels
            result.append(
                "Q1：顶部空白 \(number(topBlankPixels))px；" +
                    "contentInset=\(number(contentInsetPixels))px，" +
                    "safeAreaInsets=\(number(safeAreaPixels))px，" +
                    "aspectFit=\(number(aspectFitPixels))px；" +
                    "加和=\(number(sum))px。"
            )
        }
        if let stableNx {
            let innerTransformIsAlwaysIdentity = nxSamples.allSatisfy {
                $0.innerTransform.isIdentity
            }
            let bothAreNonDefault = nxSamples.contains {
                abs($0.zoomScale - 1) > 0.000_001 &&
                    !$0.innerTransform.isIdentity
            }
            let transitionScales = nxSamples.map {
                number($0.transitionTransform.a)
            }.joined(separator: "→")
            let entryZoomScaleIsStable = valuesAreEqual(
                entryAnimationSamples.map(\.zoomScale)
            )
            let exitZoomScaleIsStable = valuesAreEqual(
                exitAnimationSamples.map(\.zoomScale)
            )
            result.append(
                "Q2：s>1 全部样本内层 transform 恒等=" +
                    "\(innerTransformIsAlwaysIdentity)；" +
                    "稳定 Nx zoomScale=\(number(stableNx.zoomScale))，" +
                    "内层 transform 承载=" +
                    "\(number(stableNx.innerTransform.a)) 倍，" +
                    "专用过渡层样本倍率=\(transitionScales)；" +
                    "进入动画原生 zoomScale 恒定=" +
                    "\(entryZoomScaleIsStable)，" +
                    "退出动画原生 zoomScale 恒定=" +
                    "\(exitZoomScaleIsStable)；" +
                    "zoomScale 与内层 transform 同时非默认=" +
                    "\(bothAreNonDefault)。"
            )
        }
        let offsets = exitFrames.map {
            "\($0.label):offset=\(point($0.contentOffset))," +
                "innerTransform=\(transform($0.innerTransform))," +
                "transitionTransform=\(transform($0.transitionTransform))"
        }.joined(separator: "；")
        let exitInnerTransformIsIdentity = exitFrames.allSatisfy {
            $0.innerTransform.isIdentity
        }
        let transformIsMonotonic = [
            exitFrames.map(\.transitionTransform.a),
            exitFrames.map(\.transitionTransform.b),
            exitFrames.map(\.transitionTransform.c),
            exitFrames.map(\.transitionTransform.d),
            exitFrames.map(\.transitionTransform.tx),
            exitFrames.map(\.transitionTransform.ty)
        ].allSatisfy {
            valuesAreMonotonic($0)
        }
        let offsetsAreStable = zip(exitFrames, exitFrames.dropFirst())
            .allSatisfy { pair in
                abs(
                    pair.0.contentOffset.x - pair.1.contentOffset.x
                ) <= 0.5 &&
                    abs(
                        pair.0.contentOffset.y - pair.1.contentOffset.y
                    ) <= 0.5
            }
        result.append(
            "Q3：\(offsets)。动画帧内层 transform 恒等=" +
                "\(exitInnerTransformIsIdentity)，" +
                "专用过渡层 transform 全部六元组分量单调=" +
                "\(transformIsMonotonic)，" +
                "动画帧 contentOffset 无跳变=\(offsetsAreStable)；" +
                "终点只执行一次无动画原生同步。"
        )
        if let visible, let hidden {
            result.append(
                "Q4：V=显示时状态栏隐藏=\(visible.effectiveStatusBarHidden)；" +
                    "V=隐藏时状态栏隐藏=\(hidden.effectiveStatusBarHidden)。"
            )
        }
        return result
    }

    private func valuesAreMonotonic(_ values: [CGFloat]) -> Bool {
        let pairs = zip(values, values.dropFirst())
        let nondecreasing = pairs.allSatisfy {
            $0.0 <= $0.1 + 0.000_001
        }
        let nonincreasing = zip(values, values.dropFirst()).allSatisfy {
            $0.0 >= $0.1 - 0.000_001
        }
        return nondecreasing || nonincreasing
    }

    private func valuesAreEqual(_ values: [CGFloat]) -> Bool {
        guard let first = values.first else {
            return false
        }
        return values.dropFirst().allSatisfy {
            abs($0 - first) <= 0.000_001
        }
    }

    private func number<T: BinaryFloatingPoint>(_ value: T) -> String {
        String(
            format: "%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(value)
        )
    }

    private func rect(_ value: CGRect) -> String {
        "(x=\(number(value.minX)),y=\(number(value.minY))," +
            "w=\(number(value.width)),h=\(number(value.height)))"
    }

    private func size(_ value: CGSize) -> String {
        "(w=\(number(value.width)),h=\(number(value.height)))"
    }

    private func point(_ value: CGPoint) -> String {
        "(x=\(number(value.x)),y=\(number(value.y)))"
    }

    private func insets(_ value: UIEdgeInsets) -> String {
        "(top=\(number(value.top)),left=\(number(value.left))," +
            "bottom=\(number(value.bottom)),right=\(number(value.right)))"
    }

    private func transform(_ value: CGAffineTransform) -> String {
        "(a=\(number(value.a)),b=\(number(value.b))," +
            "c=\(number(value.c)),d=\(number(value.d))," +
            "tx=\(number(value.tx)),ty=\(number(value.ty)))"
    }

    private func visibilityText(_ value: S2InterfaceVisibility) -> String {
        value == .visible ? "显示" : "隐藏"
    }
}

enum S2OnDeviceTransitionScenario: String, CaseIterable, Identifiable {
    case tapShow
    case tapHide
    case pinchStart

    var id: String { rawValue }

    var exportTitle: String {
        switch self {
        case .tapShow:
            return "A 单击显示（问题方向）"
        case .tapHide:
            return "B 单击隐藏（对照组）"
        case .pinchStart:
            return "C 捏合起始"
        }
    }
}

enum S2PhotoGeometryWriteReason: String {
    case enforceOneXContentGeometry =
        "S2NativeZoomScrollView.enforceOneXContentGeometry"
    case prepareNativeZoomGeometry =
        "S2NativeZoomScrollView.prepareNativeZoomGeometry"
    case presentationTransitionSetup =
        "S2NativeZoomPageController.startPresentationTransition"
    case cornerMaskReset =
        "S2NativeZoomPageController.applyCornerMask"
}

struct S2OnDeviceTransitionFrameSample: Equatable {
    let animationKeys: [String]
    let modelFrame: CGRect?
    let presentationFrame: CGRect?
    let transform: CGAffineTransform?
    let zoomScale: CGFloat?
    let contentOffset: CGPoint?
    let contentSize: CGSize?
    let contentInset: UIEdgeInsets?
    let adjustedContentInset: UIEdgeInsets?
    let visibility: S2InterfaceVisibility?
    let scale: CGFloat?
}

enum S2OnDeviceTransitionPayload: Equatable {
    case frame(S2OnDeviceTransitionFrameSample)
    case event(name: String, source: String, details: String)
}

struct S2OnDeviceTransitionRecord: Equatable {
    let timestamp: CFTimeInterval
    let sequence: Int
    let payload: S2OnDeviceTransitionPayload
}

final class S2OnDeviceTransitionDiagnosticsCoordinator: NSObject,
    ObservableObject {
    static let recordingLimitSeconds: CFTimeInterval = 5
    static let minimumSamplingFramesPerSecond = 60

    @Published var selectedScenario: S2OnDeviceTransitionScenario = .tapShow
    @Published private(set) var isRecording = false
    @Published private(set) var reportText = ""

    private(set) var recordedEntries: [S2OnDeviceTransitionRecord] = []
    private(set) var photoGeometryWriteCount = 0
    private weak var controller: S2NativePagerViewController?
    private let clock: () -> CFTimeInterval
    private var recordedScenario: S2OnDeviceTransitionScenario?
    private var recordingStartedAt: CFTimeInterval?
    private var recordingStoppedAt: CFTimeInterval?
    private var displayLink: CADisplayLink?
    private var timeoutWorkItem: DispatchWorkItem?

    init(clock: @escaping () -> CFTimeInterval = { CACurrentMediaTime() }) {
        self.clock = clock
        super.init()
    }

    deinit {
        displayLink?.invalidate()
        timeoutWorkItem?.cancel()
    }

    var canStart: Bool {
        controller != nil && !isRecording
    }

    var canExport: Bool {
        !isRecording && !recordedEntries.isEmpty
    }

    func attach(_ controller: S2NativePagerViewController) {
        if self.controller !== controller, isRecording {
            finishRecording(source: "控制器切换自动停止")
        }
        self.controller = controller
        controller.transitionDiagnostics = self
    }

    func detach(_ controller: S2NativePagerViewController) {
        guard self.controller === controller else {
            return
        }
        if isRecording {
            finishRecording(source: "控制器卸载自动停止")
        }
        controller.transitionDiagnostics = nil
        self.controller = nil
    }

    func start() {
        guard !isRecording, controller != nil else {
            return
        }
        displayLink?.invalidate()
        timeoutWorkItem?.cancel()
        recordedEntries = []
        photoGeometryWriteCount = 0
        reportText = ""
        recordedScenario = selectedScenario
        let startedAt = clock()
        recordingStartedAt = startedAt
        recordingStoppedAt = nil
        isRecording = true
        append(
            timestamp: startedAt,
            payload: .event(
                name: "录制开始",
                source: "调试面板",
                details: "上限秒=5；采样频率下限Hz=60"
            )
        )
        captureFrame()

        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(captureDisplayFrame(_:))
        )
        let maximum = max(
            Self.minimumSamplingFramesPerSecond,
            UIScreen.main.maximumFramesPerSecond
        )
        displayLink.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(Self.minimumSamplingFramesPerSecond),
            maximum: Float(maximum),
            preferred: Float(maximum)
        )
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)

        let timeout = DispatchWorkItem { [weak self] in
            self?.finishRecording(source: "五秒上限自动停止")
        }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.recordingLimitSeconds,
            execute: timeout
        )
    }

    func stop() {
        finishRecording(source: "调试面板")
    }

    func export() {
        guard canExport,
              let scenario = recordedScenario,
              let startedAt = recordingStartedAt else {
            return
        }
        reportText = S2OnDeviceTransitionText.export(
            scenario: scenario,
            startedAt: startedAt,
            stoppedAt: recordingStoppedAt ??
                recordedEntries.last?.timestamp ?? startedAt,
            records: recordedEntries
        )
    }

    func captureFrame() {
        guard isRecording else {
            return
        }
        let machine = controller?.diagnosticMachine
        let scrollView = controller?.diagnosticCurrentPage?.zoomScrollView
        let photoLayer = scrollView?.presentationContentView?.layer
        append(payload: .frame(S2OnDeviceTransitionFrameSample(
            animationKeys: photoLayer?.animationKeys() ?? [],
            modelFrame: photoLayer?.frame,
            presentationFrame: photoLayer?.presentation()?.frame,
            transform: photoLayer?.affineTransform(),
            zoomScale: scrollView?.zoomScale,
            contentOffset: scrollView?.contentOffset,
            contentSize: scrollView?.contentSize,
            contentInset: scrollView?.contentInset,
            adjustedContentInset: scrollView?.adjustedContentInset,
            visibility: machine?.interfaceVisibility,
            scale: machine?.scale
        )))
    }

    func recordSwiftUIStatePublication(
        from previous: S2InterfaceVisibility,
        to next: S2InterfaceVisibility
    ) {
        recordEvent(
            name: "SwiftUI状态发布",
            source: "S2StateMachine.handleSingleTap @Published(V)",
            details: "V从\(S2OnDeviceTransitionText.visibility(previous))" +
                "变为\(S2OnDeviceTransitionText.visibility(next))"
        )
    }

    func recordUpdateUIView(wrotePhotoGeometry: Bool) {
        recordEvent(
            name: "updateUIView",
            source: "S2NativePhotoPager.updateUIViewController",
            details: "写入照片几何=\(wrotePhotoGeometry)"
        )
    }

    func recordInnerLayoutSubviews(
        pageIndex: Int? = nil,
        assetLocalIdentifier: String? = nil
    ) {
        recordEvent(
            name: "layoutSubviews",
            source: "S2NativeZoomScrollView.layoutSubviews",
            details: "层级=内层；" + diagnosticContext(
                pageIndex: pageIndex,
                assetLocalIdentifier: assetLocalIdentifier
            )
        )
    }

    func recordOuterViewDidLayoutSubviews(
        pageIndex: Int? = nil,
        assetLocalIdentifier: String? = nil
    ) {
        recordEvent(
            name: "viewDidLayoutSubviews",
            source: "S2NativePagerViewController.viewDidLayoutSubviews",
            details: "层级=外层；" + diagnosticContext(
                pageIndex: pageIndex,
                assetLocalIdentifier: assetLocalIdentifier
            )
        )
    }

    func recordPhotoGeometryWrite(
        frame: CGRect,
        transform: CGAffineTransform,
        reason: S2PhotoGeometryWriteReason,
        pageIndex: Int? = nil,
        assetLocalIdentifier: String? = nil
    ) {
        guard isRecording else {
            return
        }
        photoGeometryWriteCount += 1
        append(payload: .event(
            name: "照片几何写入",
            source: reason.rawValue,
            details: "frame=\(S2OnDeviceTransitionText.rect(frame))；" +
                "transform=\(S2OnDeviceTransitionText.transform(transform))；" +
                diagnosticContext(
                    pageIndex: pageIndex,
                    assetLocalIdentifier: assetLocalIdentifier
                )
        ))
    }

    func recordPhotoAnimationOperation(
        operation: String,
        key: String,
        source: String
    ) {
        recordEvent(
            name: "照片动画调用",
            source: source,
            details: "operation=\(operation)；key=\(key)"
        )
    }

    func recordCATransactionCommit(source: String) {
        recordEvent(
            name: "CATransaction提交边界",
            source: source,
            details: "commit=true"
        )
    }

    func recordOuterLayoutSuppression(
        pageIndex: Int,
        assetLocalIdentifier: String? = nil
    ) {
        recordEvent(
            name: "抑制外层布局写入生效",
            source: "S2NativePagerViewController.layoutNativePages",
            details: diagnosticContext(
                pageIndex: pageIndex,
                assetLocalIdentifier: assetLocalIdentifier
            )
        )
    }

    private func diagnosticContext(
        pageIndex: Int?,
        assetLocalIdentifier: String?
    ) -> String {
        let pageIndexText = pageIndex.map { String($0) } ?? "nil"
        return "pageIndex=\(pageIndexText)；" +
            "assetLocalIdentifier=\(assetLocalIdentifier ?? "nil")"
    }

    private func finishRecording(source: String) {
        guard isRecording else {
            return
        }
        append(payload: .event(
            name: "录制停止",
            source: source,
            details: "已保留记录数=\(recordedEntries.count + 1)"
        ))
        recordingStoppedAt = recordedEntries.last?.timestamp ?? clock()
        isRecording = false
        displayLink?.invalidate()
        displayLink = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    @objc private func captureDisplayFrame(_ displayLink: CADisplayLink) {
        guard displayLink === self.displayLink,
              let startedAt = recordingStartedAt else {
            displayLink.invalidate()
            return
        }
        if clock() - startedAt >= Self.recordingLimitSeconds {
            finishRecording(source: "五秒上限自动停止")
            return
        }
        captureFrame()
    }

    private func recordEvent(
        name: String,
        source: String,
        details: String
    ) {
        guard isRecording else {
            return
        }
        append(payload: .event(
            name: name,
            source: source,
            details: details
        ))
    }

    private func append(
        timestamp: CFTimeInterval? = nil,
        payload: S2OnDeviceTransitionPayload
    ) {
        let proposedTimestamp = timestamp ?? clock()
        let resolvedTimestamp: CFTimeInterval
        if let previous = recordedEntries.last?.timestamp {
            resolvedTimestamp = max(proposedTimestamp, previous.nextUp)
        } else {
            resolvedTimestamp = proposedTimestamp
        }
        recordedEntries.append(S2OnDeviceTransitionRecord(
            timestamp: resolvedTimestamp,
            sequence: recordedEntries.count,
            payload: payload
        ))
    }
}

enum S2OnDeviceTransitionText {
    static func export(
        scenario: S2OnDeviceTransitionScenario,
        startedAt: CFTimeInterval,
        stoppedAt: CFTimeInterval,
        records: [S2OnDeviceTransitionRecord]
    ) -> String {
        let sortedRecords = records.sorted {
            if $0.timestamp == $1.timestamp {
                return $0.sequence < $1.sequence
            }
            return $0.timestamp < $1.timestamp
        }
        var lines = [
            "# IC-068 真机过渡诊断",
            "格式版本=1",
            "场景=\(scenario.exportTitle)",
            "时钟=CACurrentMediaTime()",
            "采样频率下限Hz=\(S2OnDeviceTransitionDiagnosticsCoordinator.minimumSamplingFramesPerSecond)",
            "录制上限秒=\(number(S2OnDeviceTransitionDiagnosticsCoordinator.recordingLimitSeconds))",
            "起始绝对时间=\(timestamp(startedAt))",
            "停止绝对时间=\(timestamp(stoppedAt))",
            "记录总数=\(sortedRecords.count)",
            "顺序=全部记录按同一单调时钟严格递增",
            "逐帧字段=time,animationKeys,modelFrame,presentationFrame,transform,zoomScale,contentOffset,contentSize,contentInset,adjustedContentInset,V,s",
            "离散事件字段=time,event,source,details",
            "---"
        ]
        for (index, record) in sortedRecords.enumerated() {
            let prefix = String(format: "%06d", index + 1) +
                "\ttime=\(timestamp(record.timestamp - startedAt))"
            switch record.payload {
            case let .frame(sample):
                lines.append(prefix +
                    "\tkind=frame" +
                    "\tanimationKeys=\(animationKeys(sample.animationKeys))" +
                    "\tmodelFrame=\(optionalRect(sample.modelFrame))" +
                    "\tpresentationFrame=\(optionalRect(sample.presentationFrame))" +
                    "\ttransform=\(optionalTransform(sample.transform))" +
                    "\tzoomScale=\(optionalNumber(sample.zoomScale))" +
                    "\tcontentOffset=\(optionalPoint(sample.contentOffset))" +
                    "\tcontentSize=\(optionalSize(sample.contentSize))" +
                    "\tcontentInset=\(optionalInsets(sample.contentInset))" +
                    "\tadjustedContentInset=\(optionalInsets(sample.adjustedContentInset))" +
                    "\tV=\(sample.visibility.map(visibility) ?? "nil")" +
                    "\ts=\(optionalNumber(sample.scale))")
            case let .event(name, source, details):
                lines.append(prefix +
                    "\tkind=event" +
                    "\tevent=\(name)" +
                    "\tsource=\(source)" +
                    "\tdetails=\(details)")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func visibility(_ value: S2InterfaceVisibility) -> String {
        value == .visible ? "显示" : "隐藏"
    }

    static func rect(_ value: CGRect) -> String {
        "(x=\(number(value.minX)),y=\(number(value.minY))," +
            "w=\(number(value.width)),h=\(number(value.height)))"
    }

    static func transform(_ value: CGAffineTransform) -> String {
        "(a=\(number(value.a)),b=\(number(value.b))," +
            "c=\(number(value.c)),d=\(number(value.d))," +
            "tx=\(number(value.tx)),ty=\(number(value.ty)))"
    }

    private static func timestamp(_ value: CFTimeInterval) -> String {
        String(
            format: "%.15f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }

    private static func number<T: BinaryFloatingPoint>(_ value: T) -> String {
        String(
            format: "%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(value)
        )
    }

    private static func animationKeys(_ values: [String]) -> String {
        "[" + values.map {
            "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\""
        }.joined(separator: ",") + "]"
    }

    private static func optionalRect(_ value: CGRect?) -> String {
        value.map(rect) ?? "nil"
    }

    private static func optionalTransform(
        _ value: CGAffineTransform?
    ) -> String {
        value.map(transform) ?? "nil"
    }

    private static func optionalNumber<T: BinaryFloatingPoint>(
        _ value: T?
    ) -> String {
        value.map(number) ?? "nil"
    }

    private static func optionalPoint(_ value: CGPoint?) -> String {
        guard let value else {
            return "nil"
        }
        return "(x=\(number(value.x)),y=\(number(value.y)))"
    }

    private static func optionalSize(_ value: CGSize?) -> String {
        guard let value else {
            return "nil"
        }
        return "(w=\(number(value.width)),h=\(number(value.height)))"
    }

    private static func optionalInsets(_ value: UIEdgeInsets?) -> String {
        guard let value else {
            return "nil"
        }
        return "(top=\(number(value.top)),left=\(number(value.left))," +
            "bottom=\(number(value.bottom)),right=\(number(value.right)))"
    }
}
