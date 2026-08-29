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
    /// IC-104 C v3：`s = 1` 显示帧的竖直中心（视口坐标）。
    /// `nil` 表示沿用视口居中（改前行为），非截图与隐藏态均为该值。
    var fittedCenterY: CGFloat? = nil
    let nativeZoomBaseSize: CGSize
    let cornerRadius: CGFloat
    let doubleTapTargetScale: CGFloat
    let assetPixelSize: CGSize
    let contentVersion: S2NativePhotoContentVersion
    let content: AnyView
    /// IC-078：求该页 `pinchMaxScale` 的资产缩放几何；为 nil 或像素尺寸未解析时取 floor。
    var zoomGeometry: S2AssetZoomGeometry? = nil
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

struct S2NativePhotoPager: UIViewControllerRepresentable {
    let machine: S2StateMachine
    let configuration: S2CalibrationConfiguration
    let viewportSize: CGSize
    let pages: [S2NativePageContent]
    let onLongPress: () -> Void
    let diagnosticsCoordinator: S2GeometryDiagnosticsCoordinator
    let transitionDiagnosticsCoordinator:
        S2OnDeviceTransitionDiagnosticsCoordinator
    var imageLoadStateRegistry: S2ImageLoadStateRegistry? = nil
    /// IC-108 B：双击丝滑度探针。nil = 关闭 = 埋点零开销。
    var doubleTapProbe: S2DoubleTapSmoothnessProbeCoordinator? = nil
    /// IC-111 B：标记残影协调器。nil ⟹ 不放残影（几何诊断等宿主可不接）。
    var markAfterimages: S2MarkAfterimageCoordinator? = nil
    /// IC-079 R2：按索引提供任意页内容，供分页控制器在滚动中按需创建页。
    var pageContentProvider: ((Int) -> S2NativePageContent?)? = nil

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
        controller.imageLoadStateRegistry = imageLoadStateRegistry
        controller.doubleTapProbe = doubleTapProbe
        controller.markAfterimages = markAfterimages
        controller.installAlbumAfterimageHook()
        let photoWriteCountBefore = transitionDiagnosticsCoordinator
            .photoGeometryWriteCount
        // IC-095 R1：本次重进是否落笔任何几何，取录制窗口内几何写入总数的差值。
        let geometryWriteCountBefore = transitionDiagnosticsCoordinator
            .geometryWriteCount
        controller.apply(
            machine: machine,
            configuration: configuration,
            viewportSize: viewportSize,
            pages: pages,
            onLongPress: onLongPress,
            pageContentProvider: pageContentProvider
        )
        transitionDiagnosticsCoordinator.recordUpdateUIView(
            wrotePhotoGeometry: transitionDiagnosticsCoordinator
                .photoGeometryWriteCount > photoWriteCountBefore,
            wroteAnyGeometry: transitionDiagnosticsCoordinator
                .geometryWriteCount > geometryWriteCountBefore
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
    /// IC-104 C v3：`s = 1` 显示帧的竖直中心（视口坐标）；`nil` = 视口居中。
    private(set) var fittedCenterY: CGFloat?
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
        assetPixelSize: CGSize? = nil,
        fittedCenterY: CGFloat? = nil
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
            self.viewportSize != nextViewportSize ||
            self.fittedCenterY != fittedCenterY
        self.fittedSize = nextFittedSize
        self.fittedCenterY = fittedCenterY
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
        // IC-095 R1 补：联合居中是布局回调里唯一的几何写入点，此前无埋点。
        // 只在确有落笔时记录，静止态不产生任何记录。
        if changed {
            transitionDiagnostics?.recordJointCenteringWrite(
                inset: nextInset,
                offset: nextOffset,
                pageIndex: diagnosticPageIndex,
                assetLocalIdentifier: diagnosticAssetLocalIdentifier
            )
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
        // IC-095 R3：只有本次确有几何落笔才标脏并强制一次布局。无写入时保留
        // `layoutIfNeeded()`——它只冲刷别处已标脏的待布局，干净时不触发 layoutSubviews。
        var wroteGeometry = false
        if nextScale > minimumZoomScale + 0.000_001 {
            let wasAtMinimumZoomScale =
                abs(zoomScale - minimumZoomScale) <= 0.000_001
            if prepareNativeZoomGeometry(), wasAtMinimumZoomScale {
                wroteGeometry = true
            }
            if abs(zoomScale - nextScale) > 0.000_001 {
                setZoomScale(nextScale, animated: false)
                wroteGeometry = true
            }
        } else {
            if abs(zoomScale - minimumZoomScale) > 0.000_001 {
                setZoomScale(minimumZoomScale, animated: false)
                wroteGeometry = true
            }
            if enforceOneXContentGeometry() {
                wroteGeometry = true
            }
        }
        if wroteGeometry {
            setNeedsLayout()
        }
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
            transitionDiagnostics?.recordInnerContentOffsetWrite(
                offset: nextOffset,
                source: "S2NativeZoomScrollView.applyNativeState",
                pageIndex: diagnosticPageIndex,
                assetLocalIdentifier: diagnosticAssetLocalIdentifier
            )
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
        enforceOneXContentGeometry(
            diagnosticSource: "S2NativeZoomScrollView.restoreOneXGeometry"
        )
        updatePanAvailability()
    }

    /// IC-090 R2：所有 `setZoomScale(_:animated:)` 写入的统一记录点。只记录后原样
    /// 调用 super，不改变任何行为；关闭录制时 `recordSetZoomScale` 为零副作用。
    override func setZoomScale(_ scale: CGFloat, animated: Bool) {
        transitionDiagnostics?.recordSetZoomScale(
            scale: scale,
            animated: animated,
            previousScale: zoomScale,
            source: "S2NativeZoomScrollView.setZoomScale"
        )
        super.setZoomScale(scale, animated: animated)
    }

    /// IC-090 R2：被缩放视图图层 presentation 的 transform.a——捏合松手后的
    /// 呈现层实际倍率。无 presentation（未在动画中）时为 nil。
    var diagnosticPresentationZoomScale: CGFloat? {
        zoomContentView?.layer.presentation()?.affineTransform().a
    }

    /// IC-104 C v3：`s = 1` 照片中心在 `zoomContentView` 坐标系中的竖直位置。
    /// `fittedCenterY` 是**视口坐标**；`zoomContentView` 的 bounds 为
    /// `nativeZoomBaseSize`、居中于视口，故需减去其在视口中的顶偏移。
    /// 截图的 `nativeZoomBaseSize` 即视口，偏移为 0；非截图时 `fittedCenterY`
    /// 为视口中心，换算后恰为 `nativeZoomBaseSize.height / 2`——与改前一致。
    var oneXPhotoCenterYInZoomContent: CGFloat {
        photoCenterYInZoomContent(
            fittedCenterY: fittedCenterY,
            nativeZoomBaseHeight: nativeZoomBaseSize.height
        )
    }

    /// 同一换算的通用形式：过渡需要用**目标页**的值算终点，故单独暴露。
    func photoCenterYInZoomContent(
        fittedCenterY: CGFloat?,
        nativeZoomBaseHeight: CGFloat
    ) -> CGFloat {
        guard let fittedCenterY else {
            return nativeZoomBaseHeight / 2
        }
        let zoomTopInViewport =
            (viewportSize.height - nativeZoomBaseHeight) / 2
        return fittedCenterY - zoomTopInViewport
    }

    var oneXPresentationFrame: CGRect {
        CGRect(
            x: (viewportSize.width - fittedSize.width) / 2,
            y: (fittedCenterY ?? viewportSize.height / 2) -
                fittedSize.height / 2,
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

    /// IC-095 R3：返回本次是否确有几何落笔。既有的逐项 `!=` 守卫与诊断事件不变，
    /// 调用方据此决定是否还需要强制一次布局。
    @discardableResult
    private func enforceOneXContentGeometry(
        diagnosticSource: String = "S2NativeZoomScrollView.enforceOneXContentGeometry"
    ) -> Bool {
        guard abs(zoomScale - minimumZoomScale) <= 0.000_001 else {
            return false
        }
        guard let zoomContentView,
              let presentationContentView else {
            return false
        }
        var geometryChanged = false
        // IC-090 R2：仅用于事件 details，不参与任何判定。
        var wrotePhotoGeometry = false
        var wroteContentInset = false
        var wroteContentSize = false
        var wroteContentOffset = false
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
        // IC-104 C v3：竖直摆放取适配带中心（显示态截图）或视口中心（其余）。
        let targetPhotoCenter = CGPoint(
            x: targetZoomBounds.midX,
            y: oneXPhotoCenterYInZoomContent
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
            wrotePhotoGeometry = true
            geometryChanged = true
        }
        if contentInset != .zero {
            contentInset = .zero
            wroteContentInset = true
            geometryChanged = true
        }
        if contentSize != viewportSize {
            contentSize = viewportSize
            wroteContentSize = true
            geometryChanged = true
        }
        if contentOffset != .zero {
            setContentOffset(.zero, animated: false)
            wroteContentOffset = true
            geometryChanged = true
        }
        if geometryChanged {
            setNeedsLayout()
            layoutIfNeeded()
        }
        transitionDiagnostics?.recordOneXSnapBackWrite(
            source: diagnosticSource,
            wroteContentInset: wroteContentInset,
            wroteContentSize: wroteContentSize,
            wroteContentOffset: wroteContentOffset,
            wrotePhotoGeometry: wrotePhotoGeometry,
            pageIndex: diagnosticPageIndex,
            assetLocalIdentifier: diagnosticAssetLocalIdentifier
        )
        return geometryChanged
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

// IC-110 A：双击缩放过渡的时长与缓动。上游 ④ 定案「≈300ms、缓动接近系统」，
// IC-108 探针①已实证零丢帧满 60fps，故性能假设推翻、只改观感参数。
// 两者均为**常量**：不入 `S2CalibrationConfiguration`、不上参数面板、
// `schemaVersion` 不动（同 IC-091 `edgeTolerance`、IC-108 B 探针开关先例）。
enum S2DoubleTapTransitionTiming {
    /// 过渡时长。60fps 下约 18 帧，与 H47 复测的帧数预期一致。
    static let durationSeconds: TimeInterval = 0.3

    /// UIKit `curveEaseInOut` 的控制点。以三次贝塞尔原样求值，
    /// 而非近似式——「接近系统」按系统曲线本身理解。
    static let controlPoint1 = CGPoint(x: 0.42, y: 0)
    static let controlPoint2 = CGPoint(x: 0.58, y: 1)

    /// 线性进度 → 缓动后进度。端点恒等（0→0、1→1），故端点语义零变化。
    static func easedProgress(_ progress: CGFloat) -> CGFloat {
        let x = min(1, max(0, progress))
        if x <= 0 || x >= 1 {
            return x
        }
        return bezierValue(at: solveCurveTime(for: x))
    }

    // x(t) 的多项式系数：x(t) = ((ax·t + bx)·t + cx)·t
    private static let cx = 3 * controlPoint1.x
    private static let bx = 3 * (controlPoint2.x - controlPoint1.x) - cx
    private static let ax = 1 - cx - bx

    // y(t) 同构
    private static let cy = 3 * controlPoint1.y
    private static let by = 3 * (controlPoint2.y - controlPoint1.y) - cy
    private static let ay = 1 - cy - by

    private static func curveX(at t: CGFloat) -> CGFloat {
        ((ax * t + bx) * t + cx) * t
    }

    private static func curveXSlope(at t: CGFloat) -> CGFloat {
        (3 * ax * t + 2 * bx) * t + cx
    }

    private static func bezierValue(at t: CGFloat) -> CGFloat {
        ((ay * t + by) * t + cy) * t
    }

    /// 先牛顿迭代；斜率过小或越界时退回二分，保证单调有界收敛。
    private static func solveCurveTime(for x: CGFloat) -> CGFloat {
        var t = x
        for _ in 0..<8 {
            let error = curveX(at: t) - x
            if abs(error) < 0.000_001 {
                return t
            }
            let slope = curveXSlope(at: t)
            if abs(slope) < 0.000_001 {
                break
            }
            let next = t - error / slope
            if next < 0 || next > 1 {
                break
            }
            t = next
        }
        var lower: CGFloat = 0
        var upper: CGFloat = 1
        t = x
        while upper - lower > 0.000_001 {
            let value = curveX(at: t)
            if abs(value - x) < 0.000_001 {
                return t
            }
            if value < x {
                lower = t
            } else {
                upper = t
            }
            t = (upper + lower) / 2
        }
        return t
    }
}

// MARK: - IC-111 B：标记残影飞入右上垃圾桶

/// 残影的飞行参数与几何。**纯常量 + 纯函数**：不入 `S2CalibrationConfiguration`、
/// 不上参数面板、`schemaVersion` 不受影响；几何可被单测直接复算。
///
/// 与 IC-110 C 的区别不只是落点：那版由 SwiftUI `keyframeAnimator` 逐帧推进，
/// H47 判为「跟卡机了一样」。本版整条位移/缩放/淡出交给 `CAAnimation` 族，
/// 主线程不参与逐帧（陷阱 6）。
enum S2MarkAfterimageFlight {
    /// 总时长。卡内区间 300–340 ms，取中位 320 ms。
    static let durationSeconds: CFTimeInterval = 0.32

    /// 落点缩放与透明度（画布 ④）。
    static let startScale: CGFloat = 1
    static let endScale: CGFloat = 0.18
    static let startOpacity: Float = 0.85
    static let endOpacity: Float = 0

    /// 控制点相对「落点与主图右缘中较靠右者」再向右外推的量，
    /// 制造「先横后纵」的甩入感。
    static let controlOvershoot: CGFloat = 28

    /// 二次贝塞尔控制点：横坐标推到右外侧、纵坐标取**起点**高度。
    /// 于是曲线离开起点时近乎水平向右甩出，再上扬收进落点，
    /// 外鼓点落在主图右上外侧——即卡内「控制点在主图右上外侧」。
    static func controlPoint(
        from: CGPoint,
        to: CGPoint,
        photoMaxX: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: max(to.x, photoMaxX) + controlOvershoot,
            y: from.y
        )
    }

    /// 弧线上的点。端点恒等：0 → from，1 → to。
    static func point(
        from: CGPoint,
        to: CGPoint,
        photoMaxX: CGFloat,
        progress: CGFloat
    ) -> CGPoint {
        let t = min(1, max(0, progress))
        let control = controlPoint(from: from, to: to, photoMaxX: photoMaxX)
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * from.x +
                2 * inverse * t * control.x +
                t * t * to.x,
            y: inverse * inverse * from.y +
                2 * inverse * t * control.y +
                t * t * to.y
        )
    }

    static func path(
        from: CGPoint,
        to: CGPoint,
        photoMaxX: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(
            to: to,
            control: controlPoint(from: from, to: to, photoMaxX: photoMaxX)
        )
        return path
    }

    /// 右上垃圾桶圆钮中心（视口坐标）。**与 chrome 渲染共用
    /// `S2OverlayLayout.topElementFrames`**，不另起一套真相。
    static func trashCenter(
        viewportSize: CGSize,
        safeAreaTop: CGFloat
    ) -> CGPoint {
        let bounds = CGRect(
            x: 0,
            y: safeAreaTop,
            width: viewportSize.width,
            height: S2OverlayLayout.topBarHeight
        )
        let frames = S2OverlayLayout.topElementFrames(in: bounds)
        guard frames.count == 3 else {
            return CGPoint(x: viewportSize.width, y: safeAreaTop)
        }
        return CGPoint(x: frames[2].midX, y: frames[2].midY)
    }
}

/// IC-111 C：加入相簿残影的飞行参数与几何。与 B 同一套机制、同一 spring 家族，
/// 只在路径方向（向下弧线）与落点（底部中胶囊）上不同。
enum S2AlbumAfterimageFlight {
    /// 总时长。卡内区间 280–320 ms，取中位 300 ms。
    static let durationSeconds: CFTimeInterval = 0.3

    static let endScale: CGFloat = 0.15
    static let startOpacity: Float = 0.85
    static let endOpacity: Float = 0

    /// 弧线下垂系数：控制点自弦中点向**屏幕下方**推的比例。
    static let arcDropRatio: CGFloat = 0.28

    /// 二次贝塞尔控制点：弦中点再向下推，得到卡内的「向下弧线」。
    static func controlPoint(from: CGPoint, to: CGPoint) -> CGPoint {
        let midpoint = CGPoint(
            x: (from.x + to.x) / 2,
            y: (from.y + to.y) / 2
        )
        let chordLength = hypot(to.x - from.x, to.y - from.y)
        return CGPoint(
            x: midpoint.x,
            y: midpoint.y + chordLength * arcDropRatio
        )
    }

    /// 弧线上的点。端点恒等：0 → from，1 → to。
    static func point(
        from: CGPoint,
        to: CGPoint,
        progress: CGFloat
    ) -> CGPoint {
        let t = min(1, max(0, progress))
        let control = controlPoint(from: from, to: to)
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * from.x +
                2 * inverse * t * control.x +
                t * t * to.x,
            y: inverse * inverse * from.y +
                2 * inverse * t * control.y +
                t * t * to.y
        )
    }

    static func path(from: CGPoint, to: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(to: to, control: controlPoint(from: from, to: to))
        return path
    }

    /// 底部中胶囊中心（视口坐标）。与 `S2OverlayLayout.snapshot` 的底排构造
    /// **同一套表达式**：左右各 Ø`chromeRowHeight` 圆钮贴 `chromeHorizontalMargin`，
    /// 胶囊占两者之间、各留 `minimumSpacing`。
    static func bottomCapsuleCenter(
        viewportSize: CGSize,
        safeAreaInsets: S2OverlaySafeAreaInsets
    ) -> CGPoint {
        let minX = safeAreaInsets.leading
        let maxX = viewportSize.width - safeAreaInsets.trailing
        let leadingMaxX = minX + S2OverlayLayout.chromeHorizontalMargin +
            S2OverlayLayout.chromeRowHeight
        let trailingMinX = maxX - S2OverlayLayout.chromeHorizontalMargin -
            S2OverlayLayout.chromeRowHeight
        let capsuleMinX = leadingMaxX + S2OverlayLayout.minimumSpacing
        let capsuleMaxX = trailingMinX - S2OverlayLayout.minimumSpacing
        let centerY = viewportSize.height -
            S2OverlayLayout.actionBandCenterFromViewportBottom(
                safeAreaBottom: safeAreaInsets.bottom
            )
        return CGPoint(
            x: (capsuleMinX + capsuleMaxX) / 2,
            y: centerY
        )
    }
}

/// IC-111 C：中胶囊入场（淡入 + 上浮）的参数。首次经选择器换新相簿时先播它，
/// 播完才允许残影起飞（④ 时序规则）。
enum S2AlbumCapsuleEntrance {
    /// 入场时长（卡内 ④）。
    static let durationSeconds: TimeInterval = 0.12
    /// 上浮距离（卡内 ④）。
    static let rise: CGFloat = 8
}

/// IC-111 B：残影协调器。只做「在途计数」与「落点通知」，不碰几何也不碰动画。
///
/// 落点通知是 chrome 侧垃圾桶回弹与角标滚动的**唯一**触发源——
/// 卡内要求两者与落点**同帧**，故角标显示值要压到落点才跟上模型值。
final class S2MarkAfterimageCoordinator: ObservableObject {
    /// 在途残影数。卡内允许多枚并发，**不设上限**（IC-110 C 的 3 枚上限
    /// 随该版实现一并废止，本卡未要求）。
    @Published private(set) var inFlightCount = 0

    /// 落点计数。每落一枚 +1。
    @Published private(set) var landedTick = 0

    func willLaunch() {
        inFlightCount += 1
    }

    func didLand() {
        inFlightCount = max(0, inFlightCount - 1)
        landedTick += 1
    }

    // MARK: IC-111 C：加入相簿残影

    /// 由 pager 安装的起飞入口。chrome 侧（SwiftUI）请求起飞时调它——
    /// 快照与 `CAAnimation` 都在 UIKit 侧，与 B 同一套机制。
    var launchAlbumAfterimage: (() -> Void)?

    /// 加入相簿残影的落点计数，触发中胶囊回弹。与 B 的 `landedTick` 分开，
    /// 两种残影可同屏并存、互不阻塞。
    @Published private(set) var albumLandedTick = 0

    func albumDidLand() {
        albumLandedTick += 1
    }
}

/// IC-111 B：残影图层动画器。整段位移/缩放/淡出交给渲染层，
/// 主线程只在起飞与收口各参与一次。
enum S2MarkAfterimagePresenter {
    /// IC-111 B/C 共用。两种残影（标记飞垃圾桶、加入相簿飞中胶囊）只在
    /// 路径与参数上不同，机制完全同一套：路径走 `CAKeyframeAnimation`，
    /// 缩放与淡出各一条 `CABasicAnimation`，主线程不逐帧参与。
    static func launch(
        snapshot: UIView,
        in container: UIView,
        from: CGPoint,
        to: CGPoint,
        path: CGPath,
        duration: CFTimeInterval,
        endScale: CGFloat,
        startOpacity: Float,
        endOpacity: Float,
        keyPrefix: String,
        onLanded: @escaping () -> Void
    ) {
        snapshot.center = from
        snapshot.isUserInteractionEnabled = false
        container.addSubview(snapshot)

        let layer = snapshot.layer

        let position = CAKeyframeAnimation(keyPath: "position")
        position.path = path
        position.duration = duration
        // 卡内：位移 easeIn
        position.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = endScale
        scale.duration = duration
        scale.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = startOpacity
        opacity.toValue = endOpacity
        opacity.duration = duration
        // 卡内：淡出 linear
        opacity.timingFunction = CAMediaTimingFunction(name: .linear)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak snapshot] in
            // 陷阱 8：动画就挂在这一层，收口时把这一层整个摘掉，不留残余。
            snapshot?.layer.removeAllAnimations()
            snapshot?.removeFromSuperview()
            onLanded()
        }
        // 先把模型值落到终态，再叠动画：动画结束即模型态，无需
        // `isRemovedOnCompletion = false` 撑住末帧，也就没有残留层要清。
        layer.position = to
        layer.opacity = endOpacity
        layer.transform = CATransform3DMakeScale(endScale, endScale, 1)
        layer.add(position, forKey: keyPrefix + ".position")
        layer.add(scale, forKey: keyPrefix + ".scale")
        layer.add(opacity, forKey: keyPrefix + ".opacity")
        CATransaction.commit()
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
    /// IC-108 B：双击丝滑度探针。默认 nil（探针关闭），埋点均为可选链空调用。
    weak var doubleTapProbe: S2DoubleTapSmoothnessProbeCoordinator?
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
    /// IC-104 C v3：`s = 1` 显示帧竖直中心（视口坐标）；`nil` = 视口居中。
    private(set) var fittedCenterY: CGFloat?
    private(set) var nativeZoomBaseSize: CGSize
    private(set) var cornerRadius: CGFloat
    private(set) var doubleTapTargetScale: CGFloat
    private(set) var assetPixelSize: CGSize
    /// IC-078：本页按资产求得的 `pinchMaxScale`；像素尺寸未解析时为 floor，解析后由 `update` 更新。
    private(set) var latestMaximumZoomScale: CGFloat = 1
    private(set) var lastPresentationTransitionDuration: TimeInterval = 0
    private(set) var lastPresentationTransition: S2ImmersiveTransition?
    private(set) var lastPresentationScaleKeyframes: [CGFloat] = []
    /// IC-104 C v3：过渡的位置端点与关键帧（供夹具核验，产品不读）。
    private(set) var lastPresentationPositionKeyframes: [CGPoint] = []
    private var presentationSourcePosition: CGPoint = .zero
    private var presentationTargetPosition: CGPoint = .zero
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
    /// IC-095 R3：首次内容装配（`applyPageImmediately`）是否已完成。`viewDidLoad` 里的
    /// `configure` 用的是零视口与倍率 1，未经过一次装配之前不得判定「输入未变」。
    private var hasAppliedPageImmediately = false

    var hasDeferredPresentation: Bool {
        pendingPresentationPage != nil && !isPresentationTransitionActive
    }

    /// IC-095 R2：本页是否有手势、缩放、减速或双击 / 呈现过渡动画在途。
    /// 外层静止偏移的写回判定用它排除「任何手势或动画在途」的时刻——
    /// 内层被拖动时外层即便被 UIKit 带偏也不写回，交回 UIKit 自己结算。
    var isInteractionOrTransitionActive: Bool {
        pinchIsActive ||
            isDoubleTapTransitionActive ||
            isPresentationTransitionActive ||
            zoomScrollView.isTracking ||
            zoomScrollView.isDragging ||
            zoomScrollView.isDecelerating ||
            zoomScrollView.isZooming
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
        fittedCenterY = page.fittedCenterY
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
            assetPixelSize: assetPixelSize,
            fittedCenterY: fittedCenterY
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
        maximumZoomScale: CGFloat,
        scale: CGFloat,
        viewportOffset: CGSize,
        isCurrent: Bool,
        viewportSize: CGSize
    ) {
        loadViewIfNeeded()
        latestConfiguration = configuration
        // IC-095 R3：`applyPageImmediately` 的 `configure(...)` 用的就是这两个量，
        // 判定「本页输入是否真的变了」时必须把它们的前值一并比对。
        let previousViewportSize = latestViewportSize
        let previousMaximumZoomScale = latestMaximumZoomScale
        latestViewportSize = viewportSize
        latestMaximumZoomScale = max(1, maximumZoomScale)
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
                    maximumZoomScale: latestMaximumZoomScale,
                    assetPixelSize: assetPixelSize,
                    fittedCenterY: fittedCenterY
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

        // IC-095 R3：资产、呈现输入、内容版本、视口尺寸与本页 pinchMaxScale 全部未变，
        // 且首次内容装配已完成时，本次不重建也不重配——`applyPageImmediately` 的每一步
        // （代次自增、动画清除、rootView 重挂、`configure`、`layoutIfNeeded`）在无变化时
        // 都是空转，而 rootView 重挂与 `layoutIfNeeded` 正是静止态几何写入的来源。
        // 原生状态与圆角遮罩仍照常下发，两者自身都是逐项 `!=` 守卫的幂等写入。
        let pageInputsAreUnchanged = hasAppliedPageImmediately &&
            sameAsset &&
            pendingPresentationPage == nil &&
            !isPresentationTransitionActive &&
            interfaceVisibility == page.interfaceVisibility &&
            isFramedPhoto == page.isFramedPhoto &&
            fittedSize == page.fittedSize &&
            nativeZoomBaseSize == page.nativeZoomBaseSize &&
            cornerRadius == page.cornerRadius &&
            assetPixelSize == page.assetPixelSize &&
            contentVersion == page.contentVersion &&
            previousViewportSize == latestViewportSize &&
            previousMaximumZoomScale == latestMaximumZoomScale
        if !pageInputsAreUnchanged {
            pendingPresentationPage = nil
            applyPageImmediately(
                page,
                configuration: configuration,
                countsAsPresentationCommit: false
            )
        }
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
        configuration: S2CalibrationConfiguration,
        durationOverrideSeconds: TimeInterval? = nil
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
            // IC-104 C v3：回 1x 的竖直中心同样取适配带中心（显示态截图）。
            let targetCenterY = page?.fittedCenterY ?? fittedCenterY
                ?? view.bounds.height / 2
            targetFrame = CGRect(
                x: (view.bounds.width - targetSize.width) / 2,
                y: targetCenterY - targetSize.height / 2,
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
        // IC-110 A：时长改常量（≈300ms）。`policy.shouldAnimate` 仍作为
        // 「是否动画」的闸门保持不变——关动画、时长置 0 的既有测试路径照旧生效；
        // 只有时长取值不再跟随 `animationDurationMilliseconds`。
        // `durationOverrideSeconds` 仅供几何诊断显式加长以保证中间帧数，
        // 产品路径永远走常量。
        let policy = S2AnimationPolicy(configuration: configuration)
        doubleTapTransitionDuration = policy.shouldAnimate
            ? (durationOverrideSeconds
                ?? S2DoubleTapTransitionTiming.durationSeconds)
            : 0
        isDoubleTapTransitionActive = true
        presentationContentView.isHidden = true
        zoomScrollView.isUserInteractionEnabled = false
        doubleTapProbe?.recordDoubleTapBegan(
            enteringNx: enteringNx,
            targetScale: targetScale,
            assetID: assetID,
            pageIndex: index,
            startScale: zoomScrollView.zoomScale,
            timestamp: CACurrentMediaTime()
        )
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
        doubleTapProbe?.recordDoubleTapEnded(
            endScale: zoomScrollView.zoomScale,
            timestamp: CACurrentMediaTime()
        )
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

    /// IC-111 B：标记残影用的**当前已解码图快照**。
    ///
    /// `afterScreenUpdates: false` ⟹ 取渲染层现成内容，**不同步重读图**、
    /// 不触发重新解码（卡内明令）。取不到就返回 nil，调用方跳过残影，
    /// 绝不为了出动画而回退到同步读图。
    func makeMarkAfterimageSnapshot(
        in targetView: UIView
    ) -> (view: UIView, frame: CGRect)? {
        guard let content = zoomScrollView.presentationContentView,
              let snapshot = content.snapshotView(afterScreenUpdates: false)
        else {
            return nil
        }
        let frame = content.convert(content.bounds, to: targetView)
        guard frame.width > 0, frame.height > 0 else {
            return nil
        }
        snapshot.frame = frame
        return (snapshot, frame)
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
        doubleTapProbe?.recordDoubleTapFrame(
            timestamp: displayLink.timestamp,
            nominalInterval: displayLink.duration
        )
        let elapsed = displayLink.timestamp -
            (doubleTapTransitionStartTimestamp ?? displayLink.timestamp)
        // IC-110 A：线性进度只用于计时与收口判定；落到几何上的是缓动后进度。
        // 缓动端点恒等，故终点几何与既有契约一致。
        let linearProgress = doubleTapTransitionDuration > 0
            ? CGFloat(elapsed / doubleTapTransitionDuration)
            : 1
        applyDoubleTapTransitionProgress(
            S2DoubleTapTransitionTiming.easedProgress(linearProgress)
        )
        if linearProgress >= 1 {
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
        // IC-104 C v3：端点不同心时 morph 含平移。源取当前呈现层 position，
        // 目标由 `page.fittedCenterY` 换算到 `zoomContentView` 坐标。
        // 曲线、时长、阻尼与 scale/cornerRadius 完全一致（同一 progressValues）。
        presentationSourcePosition = sourceLayer.position
        presentationTargetPosition = CGPoint(
            x: sourceLayer.position.x,
            y: zoomScrollView.photoCenterYInZoomContent(
                fittedCenterY: page.fittedCenterY,
                nativeZoomBaseHeight: page.nativeZoomBaseSize.height
            )
        )
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
                // IC-104 C v3：模型层直接置于目标位置，动画负责从源位置补间，
                // 与 transform 的处理方式一致。
                contentView.layer.position = self.presentationTargetPosition
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
        let positions = progressValues.map { value -> CGPoint in
            CGPoint(
                x: presentationSourcePosition.x +
                    (presentationTargetPosition.x -
                        presentationSourcePosition.x) * value,
                y: presentationSourcePosition.y +
                    (presentationTargetPosition.y -
                        presentationSourcePosition.y) * value
            )
        }
        lastPresentationPositionKeyframes = positions
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
        // IC-104 C v3：位置分量。`fitBorderLayer` 是照片层的**子层**
        // （`hostingController.view.layer.addSublayer`，帧 = 父层 bounds），
        // 随父层平移，故不另加位置分量——再加一份会双重平移。
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = positions.map { NSValue(cgPoint: $0) }
        positionAnimation.keyTimes = keyTimes
        let photoGroup = presentationAnimationGroup(
            animations: [
                scaleAnimation,
                cornerAnimation,
                positionAnimation
            ],
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
        fittedCenterY = page.fittedCenterY
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
            maximumZoomScale: latestMaximumZoomScale,
            assetPixelSize: assetPixelSize,
            fittedCenterY: fittedCenterY
        )
        applyCornerMask()
        zoomScrollView.layoutIfNeeded()
        hasAppliedPageImmediately = true
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
        // IC-090 R2：只记录，不改判定。
        transitionDiagnostics?.recordScrollViewDidEndZooming(
            scale: scale,
            endedAtMinimum: endedAtMinimum,
            pinchWasActive: pinchIsActive,
            pageIndex: index,
            assetLocalIdentifier: diagnosticAssetLocalIdentifier
        )
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
    /// IC-111 B：标记残影协调器。nil ⟹ 不放残影。
    var markAfterimages: S2MarkAfterimageCoordinator?
    private var isApplyingSnapshot = false
    private(set) var settledIndex = 0
    /// IC-079 R1：各资产图像加载态（只读埋点，来自 S2View 的加载态回调）。
    weak var imageLoadStateRegistry: S2ImageLoadStateRegistry?
    private var outerDragStartDate: Date?
    /// IC-108 A：本次外层滑动序列内是否已在滑动中推进过 `machine.currentIndex`。
    /// 只是每手势一个布尔标志，**不是索引副本**——索引唯一来源仍是
    /// `machine.currentIndex`。用途见 `finishNativePaging` 里的边界提示门控。
    private var didAdvanceIndexDuringScroll = false
    private var lastOuterTranslation = CGSize.zero
    private var lastOuterVelocity: CGFloat = 0
    private var lastOuterDuration: TimeInterval = 0
    private var pendingPresentationTapPageIndex: Int?
    private var presentationTapStartTimestamp: CFTimeInterval?
    private var isHandlingOuterLayoutCallback = false
    private(set) var nativeZoomReturnInvocationCount = 0
    private(set) var presentationTapLayoutReading =
        S2PresentationTapLayoutReading()
    var diagnosticsRun: S2GeometryDiagnosticsRun?
    /// IC-108 B：双击丝滑度探针，向各页控制器传播。默认 nil = 关闭 = 零开销。
    weak var doubleTapProbe: S2DoubleTapSmoothnessProbeCoordinator? {
        didSet {
            pageControllers.values.forEach {
                $0.doubleTapProbe = doubleTapProbe
            }
        }
    }
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
        onLongPress: @escaping () -> Void,
        pageContentProvider: ((Int) -> S2NativePageContent?)? = nil
    ) {
        loadViewIfNeeded()
        self.machine = machine
        self.configuration = configuration
        self.viewportSize = viewportSize
        self.onLongPress = onLongPress
        self.pageContentProvider = pageContentProvider
        isApplyingSnapshot = true

        // IC-079 R2：SwiftUI 传入的页列表（当前页 ±1）之外，滚动中按需创建的页
        // 只要仍在 `currentIndex ± retainedPageRadius` 内就保留，避免翻页刷新时
        // 先移除再重建；超出保留半径的页才移除。
        let pageIndices = Set(pages.map(\.index))
        let retainedRange = (machine.currentIndex - Self.retainedPageRadius)...
            (machine.currentIndex + Self.retainedPageRadius)
        let removedIndices = pageControllers.keys.filter {
            !pageIndices.contains($0) && !retainedRange.contains($0)
        }
        for index in removedIndices {
            removePageController(at: index)
        }

        for page in pages {
            applyPage(page, machine: machine)
        }
        // 按需创建且不在本次列表内的页，用提供者的最新内容同步一次。
        for index in pageControllers.keys.sorted() where !pageIndices.contains(index) {
            if let page = pageContentProvider?(index) {
                applyPage(page, machine: machine)
            }
        }

        settledIndex = machine.currentIndex
        layoutNativePages()
        // IC-095 R2：外层静止偏移只在确已偏离且无任何手势 / 动画在途时写一次。
        // `layoutNativePages` 已按同一判定写过时这里返回 nil，本次总计仍是一次写入；
        // 该重排可能改变 `contentSize` 并被 UIKit 反钳偏移，故此处再判一次。
        if let settledOffset = pendingSettledPagingOffset() {
            writePagingContentOffset(
                settledOffset,
                animated: false,
                source: "S2NativePagerViewController.apply"
            )
        }
        isApplyingSnapshot = false
    }

    /// IC-079 R2：页保留半径（当前页 ±2）。页窗口大小不是规格量；保留半径只决定
    /// 翻页刷新时哪些按需创建的页不被移除。
    static let retainedPageRadius = 2
    private var pageContentProvider: ((Int) -> S2NativePageContent?)?

    private func applyPage(_ page: S2NativePageContent, machine: S2StateMachine) {
        let controller = pageControllers[page.index] ?? makePageController(for: page)
        if let zoomGeometry = page.zoomGeometry {
            machine.updateAssetZoomGeometry(zoomGeometry, for: page.assetID)
        }
        controller.update(
            page: page,
            configuration: configuration,
            maximumZoomScale: machine.pinchMaxScale(for: page.assetID),
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

    private func makePageController(
        for page: S2NativePageContent
    ) -> S2NativeZoomPageController {
        let controller = S2NativeZoomPageController(
            page: page,
            owner: self
        )
        controller.transitionDiagnostics = transitionDiagnostics
        controller.doubleTapProbe = doubleTapProbe
        addChild(controller)
        pagingScrollView.addSubview(controller.view)
        controller.prioritizeVerticalSwipe(
            over: pagingScrollView.panGestureRecognizer
        )
        controller.didMove(toParent: self)
        pageControllers[page.index] = controller
        transitionDiagnostics?.recordPageLifecycle(
            created: true,
            pageIndex: page.index,
            assetLocalIdentifier: page.assetID
        )
        return controller
    }

    private func removePageController(at index: Int) {
        guard let controller = pageControllers[index] else {
            return
        }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        pageControllers.removeValue(forKey: index)
        transitionDiagnostics?.recordPageLifecycle(
            created: false,
            pageIndex: index,
            assetLocalIdentifier: controller.diagnosticAssetLocalIdentifier
        )
    }

    /// IC-079 R2：滚动经过的页在进入视口前必须已存在。按外层偏移求当前覆盖的
    /// 页索引区间并向两侧各扩一页，缺失的页由提供者按最新内容创建；越界索引不创建。
    /// 只创建与布局，不写外层偏移、不改当前页的原生状态。
    private func ensurePagesExistAroundPagingOffset() {
        guard let machine, let pageContentProvider,
              pagingScrollView.pageStride > 0 else {
            return
        }
        let position = pagingScrollView.contentOffset.x / pagingScrollView.pageStride
        let lower = Int(position.rounded(.down)) - 1
        let upper = Int(position.rounded(.up)) + 1
        let validRange = 0..<machine.orderedAssetIDs.count
        var created = false
        for index in lower...upper where validRange.contains(index) {
            guard pageControllers[index] == nil,
                  let page = pageContentProvider(index) else {
                continue
            }
            let controller = makePageController(for: page)
            if let zoomGeometry = page.zoomGeometry {
                machine.updateAssetZoomGeometry(zoomGeometry, for: page.assetID)
            }
            controller.update(
                page: page,
                configuration: configuration,
                maximumZoomScale: machine.pinchMaxScale(for: page.assetID),
                scale: 1,
                viewportOffset: .zero,
                isCurrent: false,
                viewportSize: viewportSize
            )
            controller.view.frame = pagingScrollView.frameForPage(at: index)
            created = true
        }
        if created {
            pagingScrollView.layoutIfNeeded()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === pagingScrollView, !isApplyingSnapshot else {
            return
        }
        ensurePagesExistAroundPagingOffset()
        advanceCurrentIndexToPagingOffsetIfNeeded()
    }

    /// IC-108 A（④ Lynn 2026-08-30，未定项 22 定案）：主图每越过一页边界即刻更新
    /// `machine.currentIndex`，两个跟随者（底部横栏当前项、顶部日期/序号）因此逐张
    /// 立即随动，不再等滑动停稳。
    ///
    /// 只改**索引更新时机**，不碰几何：本方法不写任何 `contentOffset`、不调
    /// `synchronizeNativeStateToMachine`（那是停稳路径 `finishNativePaging` 的职责），
    /// 故不引入静止态几何写入（陷阱 5）。外层滑动期间 `pendingSettledPagingOffset()`
    /// 已由 `isTracking / isDragging / isDecelerating` 守住，`apply` 路径不会回写偏移
    /// （IC-095 R2）。
    private func advanceCurrentIndexToPagingOffsetIfNeeded() {
        guard let machine else {
            return
        }
        let targetIndex = pagingScrollView.pageIndex(
            forContentOffsetX: pagingScrollView.contentOffset.x
        )
        let previousIndex = machine.currentIndex
        guard targetIndex != previousIndex else {
            return
        }
        let accepted = machine.handleNativePageChange(to: targetIndex)
        if accepted {
            didAdvanceIndexDuringScroll = true
        }
        transitionDiagnostics?.recordNativePageChange(
            from: previousIndex,
            to: targetIndex,
            accepted: accepted
        )
    }

    /// IC-079 R1：外层分页偏移的唯一 `setContentOffset` 入口，带来源与 animated 标志记入诊断。
    private func writePagingContentOffset(
        _ offset: CGPoint,
        animated: Bool,
        source: String
    ) {
        transitionDiagnostics?.recordPagingContentOffsetWrite(
            offsetX: offset.x,
            animated: animated,
            source: source
        )
        pagingScrollView.setContentOffset(offset, animated: animated)
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
        onLongPress = nil
        diagnosticsRun?.cancel()
        diagnosticsRun = nil
    }

    var diagnosticPageIndicesPresent: [Int] {
        pageControllers.keys.sorted()
    }

    var diagnosticPageLoadStates: [Int: String] {
        var states: [Int: String] = [:]
        for (index, controller) in pageControllers {
            states[index] = imageLoadStateRegistry?
                .state(for: controller.diagnosticAssetLocalIdentifier)
                .map(\.diagnosticName) ?? "unknown"
        }
        return states
    }

    var diagnosticMachine: S2StateMachine? {
        machine
    }

    /// IC-090 R2：当前张最近一次图片请求结果与全局最近一次图片替换。
    var diagnosticCurrentImageRequestResult: String? {
        guard let machine,
              machine.orderedAssetIDs.indices.contains(machine.currentIndex) else {
            return nil
        }
        return imageLoadStateRegistry?.requestResult(
            for: machine.orderedAssetIDs[machine.currentIndex]
        )
    }

    var diagnosticLastImageReplacement: S2ImageReplacementRecord? {
        imageLoadStateRegistry?.lastImageReplacement
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
        // IC-110 A：时长改常量后，诊断不能再靠改配置加长过渡；改为显式传时长，
        // 取值与改动前完全一致，中间帧数保证不变。
        return page.startDoubleTapTransition(
            enteringNx: !wasZoomed,
            targetScale: wasZoomed ? 1 : machine.scale,
            at: CGPoint(
                x: viewportSize.width / 2,
                y: viewportSize.height / 2
            ),
            configuration: diagnosticConfiguration,
            durationOverrideSeconds:
                diagnosticConfiguration.animationDurationMilliseconds / 1_000
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

    /// IC-111 C：把「起飞加入相簿残影」的入口装到协调器上，供 chrome 侧调用。
    func installAlbumAfterimageHook() {
        markAfterimages?.launchAlbumAfterimage = { [weak self] in
            self?.launchAlbumAfterimage()
        }
    }

    /// IC-111 B：起飞一枚残影。主图本体不参与位移——飞的是独立快照视图，
    /// 故标记后立刻可以翻页。
    private func launchMarkAfterimage(
        snapshot: UIView,
        photoFrame: CGRect
    ) {
        guard let markAfterimages else {
            return
        }
        let target = S2MarkAfterimageFlight.trashCenter(
            viewportSize: view.bounds.size,
            safeAreaTop: view.safeAreaInsets.top
        )
        let from = CGPoint(x: photoFrame.midX, y: photoFrame.midY)
        markAfterimages.willLaunch()
        S2MarkAfterimagePresenter.launch(
            snapshot: snapshot,
            in: view,
            from: from,
            to: target,
            path: S2MarkAfterimageFlight.path(
                from: from,
                to: target,
                photoMaxX: photoFrame.maxX
            ),
            duration: S2MarkAfterimageFlight.durationSeconds,
            endScale: S2MarkAfterimageFlight.endScale,
            startOpacity: S2MarkAfterimageFlight.startOpacity,
            endOpacity: S2MarkAfterimageFlight.endOpacity,
            keyPrefix: "s2.markAfterimage",
            onLanded: { [weak markAfterimages] in
                markAfterimages?.didLand()
            }
        )
    }

    /// IC-111 C：起飞一枚「加入相簿」残影——当前已解码图快照沿向下弧线飞入
    /// 底部中胶囊。与 B 同一套机制，可同屏并存、互不阻塞。
    private func launchAlbumAfterimage() {
        // 加入相簿针对的是**当前**这张，故取当前页快照。
        guard let markAfterimages,
              let index = machine?.currentIndex,
              let page = pageControllers[index],
              let prelaunch = page.makeMarkAfterimageSnapshot(in: view)
        else {
            return
        }
        let insets = S2OverlaySafeAreaInsets(
            top: view.safeAreaInsets.top,
            leading: view.safeAreaInsets.left,
            bottom: view.safeAreaInsets.bottom,
            trailing: view.safeAreaInsets.right
        )
        let target = S2AlbumAfterimageFlight.bottomCapsuleCenter(
            viewportSize: view.bounds.size,
            safeAreaInsets: insets
        )
        let from = CGPoint(
            x: prelaunch.frame.midX,
            y: prelaunch.frame.midY
        )
        S2MarkAfterimagePresenter.launch(
            snapshot: prelaunch.view,
            in: view,
            from: from,
            to: target,
            path: S2AlbumAfterimageFlight.path(from: from, to: target),
            duration: S2AlbumAfterimageFlight.durationSeconds,
            endScale: S2AlbumAfterimageFlight.endScale,
            startOpacity: S2AlbumAfterimageFlight.startOpacity,
            endOpacity: S2AlbumAfterimageFlight.endOpacity,
            keyPrefix: "s2.albumAfterimage",
            onLanded: { [weak markAfterimages] in
                markAfterimages?.albumDidLand()
            }
        )
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
        // IC-074：原捏合结束的最小速度／最长时长过滤已随参数废止删除；
        // 两者出厂值均为 0（语义为无限制），过滤恒通过，因此这里恒以
        // accepted=true 交给状态机，行为不变。
        let targetScale = machine.finishNativePinch(
            scale: scale,
            viewportOffset: page.zoomScrollView.reportedViewportOffset(),
            accepted: true
        )
        // IC-090 R2：先判定走哪条分支再记录，随后按原逻辑执行；判定与执行都不变。
        let path: String
        if let targetScale {
            if abs(
                targetScale - page.zoomScrollView.minimumZoomScale
            ) <= 0.000_001 {
                path = "returnToMinimum"
            } else if abs(
                page.zoomScrollView.zoomScale - targetScale
            ) > 0.000_001 {
                path = "setZoomScale"
            } else {
                path = "noWrite"
            }
        } else {
            path = "none"
        }
        transitionDiagnostics?.recordFinishNativePinch(
            scale: scale,
            targetScale: targetScale,
            displacement: displacement,
            peakVelocity: peakVelocity,
            duration: duration,
            path: path
        )
        guard let targetScale else {
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
        // IC-111 B：残影快照必须取在状态变更**之前**——标记成功会立刻翻到下一张，
        // 之后再快照就拍到别人了。只在「上滑且当前张尚未标记」时才预拍，
        // 其余手势零开销。快照走 `afterScreenUpdates: false`，不重读图。
        //
        // G274：这里只在既有结算调用的前后读已发布状态，**不碰任何手势识别器、
        // 不改手势判定**；标记与否仍全由 `completeMainDrag` 决定。
        let pendingBefore = machine.pendingDeletionAssetIDs
        let markCandidate = markAfterimages != nil &&
            translation.height < 0 &&
            !pendingBefore.contains(machine.currentAssetID)
        let prelaunch = markCandidate
            ? page.makeMarkAfterimageSnapshot(in: view)
            : nil

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
        // 确有新增才起飞；没标记成功就把预拍的快照丢掉。
        if let prelaunch,
           machine.pendingDeletionAssetIDs.count > pendingBefore.count {
            launchMarkAfterimage(
                snapshot: prelaunch.view,
                photoFrame: prelaunch.frame
            )
        }
        return handled
    }

    /// IC-082 R3（v15 决策 4）：Nx 下左右拖动不再由自定义投影写外层偏移。内层缩放滚动视图在
    /// 拖动方向仍可滚动时只平移；内层到达内容边界后，同一手势由 UIKit 嵌套滚动交接给外层分页
    /// 滚动视图，外层按原生分页判定是否翻页并原生回弹，结算沿用 `finishNativePaging`。
    /// 这天然满足「画面已平移贴边」：起始不贴边时内层先消耗位移，外层不动。

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === pagingScrollView else {
            return
        }
        outerDragStartDate = Date()
        didAdvanceIndexDuringScroll = false
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

    /// IC-095 R2：`layoutNativePages` 的重排输入。这些量全部相等时，重排的每一步
    /// 都只会写回与现值相同的几何，因此本次调用整段跳过。
    private struct S2NativePagerLayoutInputs: Equatable {
        struct Page: Equatable {
            let index: Int
            let assetID: String
            let fittedSize: CGSize
            let nativeZoomBaseSize: CGSize
        }

        let viewportSize: CGSize
        let itemCount: Int
        let pageSpacing: CGFloat
        let currentIndex: Int
        let scale: CGFloat
        let viewportOffset: CGSize
        let pages: [Page]
    }

    private var lastLayoutInputs: S2NativePagerLayoutInputs?

    private func currentLayoutInputs() -> S2NativePagerLayoutInputs {
        S2NativePagerLayoutInputs(
            viewportSize: viewportSize,
            itemCount: machine?.orderedAssetIDs.count ?? 0,
            pageSpacing: CGFloat(configuration.pageSpacing),
            currentIndex: machine?.currentIndex ?? 0,
            scale: machine?.scale ?? 1,
            viewportOffset: machine?.viewportOffset ?? .zero,
            pages: pageControllers.keys.sorted().compactMap { index in
                guard let controller = pageControllers[index] else {
                    return nil
                }
                return S2NativePagerLayoutInputs.Page(
                    index: index,
                    assetID: controller.diagnosticAssetLocalIdentifier,
                    fittedSize: controller.fittedSize,
                    nativeZoomBaseSize: controller.nativeZoomBaseSize
                )
            }
        )
    }

    /// IC-095 R2：外层静止偏移写回的唯一判定入口。返回非 nil 表示「应当写一次」。
    /// 三个条件同时成立才写，任一不成立就一个字节都不写：
    /// 1. 外层自身无手势、无减速——`isTracking` / `isDragging` / `isDecelerating` 均为假；
    /// 2. 没有任何页的内层手势、缩放、减速或双击 / 呈现过渡在途；
    /// 3. 外层当前偏移确已偏离 `settledIndex` 的静止偏移，差值超过 ε = 0.000001。
    private func pendingSettledPagingOffset() -> CGPoint? {
        guard !pagingScrollView.isTracking,
              !pagingScrollView.isDragging,
              !pagingScrollView.isDecelerating,
              !pageControllers.values.contains(
                  where: \.isInteractionOrTransitionActive
              ) else {
            return nil
        }
        let settledOffset = pagingScrollView.contentOffsetForPage(
            at: settledIndex
        )
        guard abs(pagingScrollView.contentOffset.x - settledOffset.x) >
            0.000_001 ||
            abs(pagingScrollView.contentOffset.y - settledOffset.y) >
            0.000_001 else {
            return nil
        }
        return settledOffset
    }

    private func layoutNativePages() {
        let previousApplyingState = isApplyingSnapshot
        isApplyingSnapshot = true
        let inputs = currentLayoutInputs()
        // IC-095 R2：页集合、视口尺寸、页间距、逐页几何输入与状态机视口状态全部未变时
        // 不重排——重排的每一步都是几何写入的来源。等待呈现结算的单击页例外：
        // 该页的布局回调计数与抑制计数必须逐次落实（IC-067 / IC-076 门禁）。
        if inputs != lastLayoutInputs || pendingPresentationTapPageIndex != nil {
            layoutNativePagesUnconditionally()
            lastLayoutInputs = inputs
        }
        // 外层静止偏移的偏离判定不在跳过之列：外层可能被 UIKit 带偏而重排输入未变。
        if let settledOffset = pendingSettledPagingOffset() {
            transitionDiagnostics?.recordPagingContentOffsetWrite(
                offsetX: settledOffset.x,
                animated: false,
                source: "S2NativePagerViewController.layoutNativePages"
            )
            pagingScrollView.contentOffset = settledOffset
        }
        isApplyingSnapshot = previousApplyingState
    }

    private func layoutNativePagesUnconditionally() {
        pagingScrollView.configure(
            viewportSize: viewportSize,
            itemCount: machine?.orderedAssetIDs.count ?? 0,
            pageSpacing: CGFloat(configuration.pageSpacing)
        )
        for (index, controller) in pageControllers {
            let pageFrame = pagingScrollView.frameForPage(at: index)
            if controller.view.frame != pageFrame {
                controller.view.frame = pageFrame
                transitionDiagnostics?.recordPageFrameWrite(
                    pageIndex: index,
                    frame: pageFrame,
                    assetLocalIdentifier:
                        controller.diagnosticAssetLocalIdentifier
                )
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
            let accepted = machine.handleNativePageChange(to: targetIndex)
            transitionDiagnostics?.recordNativePageChange(
                from: previousIndex,
                to: targetIndex,
                accepted: accepted
            )
        } else if targetIndex == previousIndex,
                  !didAdvanceIndexDuringScroll {
            // IC-108 A：索引已在滑动中推进过时，停稳处的「目标 == 当前」不再表示
            // 「这次拖动没能翻页」，故不得据此报边界。只有整个滑动序列自始至终
            // 未改变索引，才与改前语义一致。
            reportSequenceBoundaryAttemptIfNeeded()
        }
        settledIndex = machine.currentIndex
        synchronizeNativeStateToMachine(animatedPaging: false)
        outerDragStartDate = nil
        didAdvanceIndexDuringScroll = false
    }

    private func synchronizeNativeStateToMachine(animatedPaging: Bool) {
        guard let machine else {
            return
        }
        transitionDiagnostics?.recordSynchronizeNativeState(
            animatedPaging: animatedPaging,
            currentIndex: machine.currentIndex,
            scale: machine.scale
        )
        isApplyingSnapshot = true
        for (index, controller) in pageControllers {
            controller.zoomScrollView.applyNativeState(
                scale: index == machine.currentIndex ? machine.scale : 1,
                viewportOffset: index == machine.currentIndex
                    ? machine.viewportOffset
                    : .zero
            )
        }
        // IC-079 R2：停止时偏移已是原生分页的结算位置则不再二次写入；
        // 只有偏移确实偏离（如竖向手势接管后）才对齐。
        let settledOffset = pagingScrollView.contentOffsetForPage(
            at: machine.currentIndex
        )
        if animatedPaging ||
            abs(pagingScrollView.contentOffset.x - settledOffset.x) > 0.5 ||
            abs(pagingScrollView.contentOffset.y - settledOffset.y) > 0.5 {
            writePagingContentOffset(
                settledOffset,
                animated: animatedPaging,
                source: "S2NativePagerViewController.synchronizeNativeStateToMachine"
            )
        }
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
        let accepted = machine.handleHorizontalSwipe(
            direction: direction,
            startedAtPagingEdge: true,
            distance: distance,
            velocity: velocity
        )
        transitionDiagnostics?.recordHorizontalSwipe(
            direction: direction,
            startedAtPagingEdge: true,
            distance: distance,
            velocity: velocity,
            accepted: accepted,
            source: "S2NativePagerViewController.reportSequenceBoundaryAttemptIfNeeded"
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
    case fastPaging
    case nxEdgePaging

    var id: String { rawValue }

    var exportTitle: String {
        switch self {
        case .tapShow:
            return "A 单击显示（问题方向）"
        case .tapHide:
            return "B 单击隐藏（对照组）"
        case .pinchStart:
            return "C 捏合起始"
        case .fastPaging:
            return "D 快速连续翻页"
        case .nxEdgePaging:
            return "E Nx 贴边翻页"
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
    /// IC-079 场景 D 追加：外层分页容器与页窗口状态；默认值保证既有构造不变。
    var pagingContentOffsetX: CGFloat? = nil
    var pagingIsDragging: Bool? = nil
    var pagingIsDecelerating: Bool? = nil
    var currentIndex: Int? = nil
    var settledIndex: Int? = nil
    var pageIndicesPresent: [Int] = []
    var pageLoadStates: [Int: String] = [:]
    /// IC-082 场景 E 追加：贴边翻页起始时的边界距离与当前投影溢出量；非贴边拖动期间为 nil。
    var nxDistanceToPreviousBoundary: CGFloat? = nil
    var nxDistanceToNextBoundary: CGFloat? = nil
    var nxOverflowDistance: CGFloat? = nil
    /// IC-090 R2 场景 C 追加：捏合松手瞬间「模型值已结算、呈现层仍在动」的判据。
    /// `presentationZoomScale` 取被缩放视图（`viewForZooming`）图层 presentation
    /// 的 transform.a，与既有的模型 `zoomScale` 对照。
    var presentationZoomScale: CGFloat? = nil
    var isZoomBouncing: Bool? = nil
    var isDecelerating: Bool? = nil
    /// 当前张最近一次图片请求结果（`S2ImageRequestResult` 分支名）与最近一次图片替换。
    var imageRequestResult: String? = nil
    var lastImageReplacement: S2ImageReplacementRecord? = nil
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
    /// IC-095 R1：录制窗口内**实际发生**的几何写入总数。计入六类埋点：
    /// 外层 `setContentOffset`、页 frame 写入、内层 `setContentOffset`、
    /// `setZoomScale`、吸附归位写入（四个布尔任一为真时）、照片几何写入。
    /// 未真正落笔的调用一律不计。`updateUIView` 事件的 `写入任意几何` 由本计数差值得出。
    private(set) var geometryWriteCount = 0
    /// IC-095 R1：录制窗口内外层分页容器 `setContentOffset` 的实际写入次数。
    private(set) var pagingContentOffsetWriteCount = 0
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
        geometryWriteCount = 0
        pagingContentOffsetWriteCount = 0
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
            scale: machine?.scale,
            pagingContentOffsetX: controller?.pagingScrollView.contentOffset.x,
            pagingIsDragging: controller?.pagingScrollView.isDragging,
            pagingIsDecelerating: controller?.pagingScrollView.isDecelerating,
            currentIndex: machine?.currentIndex,
            settledIndex: controller?.settledIndex,
            pageIndicesPresent: controller?.diagnosticPageIndicesPresent ?? [],
            pageLoadStates: controller?.diagnosticPageLoadStates ?? [:],
            // IC-082 R3：自定义贴边投影已删除，三个字段保留为 nil（见 export-format.md）。
            nxDistanceToPreviousBoundary: nil,
            nxDistanceToNextBoundary: nil,
            nxOverflowDistance: nil,
            // IC-090 R2 场景 C：呈现层倍率与两个原生标志、当前张图片请求状态。
            presentationZoomScale: scrollView?.diagnosticPresentationZoomScale,
            isZoomBouncing: scrollView?.isZoomBouncing,
            isDecelerating: scrollView?.isDecelerating,
            imageRequestResult: controller?.diagnosticCurrentImageRequestResult,
            lastImageReplacement: controller?.diagnosticLastImageReplacement
        )))
    }

    /// IC-082 R1/R3：`handleHorizontalSwipe` 调用与返回值（R3 后仅序列边界尝试路径调用）、原生状态同步。
    func recordHorizontalSwipe(
        direction: S2PageDirection,
        startedAtPagingEdge: Bool,
        distance: CGFloat,
        velocity: CGFloat,
        accepted: Bool,
        source: String
    ) {
        recordEvent(
            name: "handleHorizontalSwipe",
            source: source,
            details: "direction=\(direction == .next ? "next" : "previous")；" +
                "startedAtPagingEdge=\(startedAtPagingEdge)；" +
                "distance=\(String(format: "%.6f", Double(distance)))；" +
                "velocity=\(String(format: "%.6f", Double(velocity)))；" +
                "accepted=\(accepted)"
        )
    }

    func recordSynchronizeNativeState(
        animatedPaging: Bool,
        currentIndex: Int,
        scale: CGFloat
    ) {
        recordEvent(
            name: "synchronizeNativeStateToMachine",
            source: "S2NativePagerViewController.synchronizeNativeStateToMachine",
            details: "animatedPaging=\(animatedPaging)；currentIndex=\(currentIndex)；" +
                "s=\(String(format: "%.6f", Double(scale)))"
        )
    }

    /// IC-079 R1：页创建 / 移除、外层 `setContentOffset` 写入、`handleNativePageChange`。
    func recordPageLifecycle(
        created: Bool,
        pageIndex: Int,
        assetLocalIdentifier: String
    ) {
        recordEvent(
            name: created ? "页创建" : "页移除",
            source: "S2NativePagerViewController.apply",
            details: "pageIndex=\(pageIndex)；asset=\(assetLocalIdentifier)"
        )
    }

    func recordPagingContentOffsetWrite(
        offsetX: CGFloat,
        animated: Bool,
        source: String
    ) {
        guard isRecording else {
            return
        }
        geometryWriteCount += 1
        pagingContentOffsetWriteCount += 1
        recordEvent(
            name: "外层setContentOffset",
            source: source,
            details: "x=\(String(format: "%.6f", Double(offsetX)))；animated=\(animated)"
        )
    }

    /// IC-095 R1：外层页容器子视图 frame 的实际写入（`layoutNativePages` 唯一写入点）。
    func recordPageFrameWrite(
        pageIndex: Int,
        frame: CGRect,
        assetLocalIdentifier: String?
    ) {
        guard isRecording else {
            return
        }
        geometryWriteCount += 1
        recordEvent(
            name: "页frame写入",
            source: "S2NativePagerViewController.layoutNativePages",
            details: "frame=\(S2OnDeviceTransitionText.rect(frame))；" +
                diagnosticContext(
                    pageIndex: pageIndex,
                    assetLocalIdentifier: assetLocalIdentifier
                )
        )
    }

    /// IC-095 R1 补：布局回调里的联合居中写入（`contentInset` 与 `contentOffset` 同帧写入）。
    func recordJointCenteringWrite(
        inset: UIEdgeInsets,
        offset: CGPoint,
        pageIndex: Int?,
        assetLocalIdentifier: String?
    ) {
        guard isRecording else {
            return
        }
        geometryWriteCount += 1
        recordEvent(
            name: "联合居中写入",
            source: "S2NativeZoomScrollView.applyJointCentering",
            details: "contentInset=(top=\(S2OnDeviceTransitionText.number(inset.top))," +
                "left=\(S2OnDeviceTransitionText.number(inset.left))," +
                "bottom=\(S2OnDeviceTransitionText.number(inset.bottom))," +
                "right=\(S2OnDeviceTransitionText.number(inset.right)))；" +
                "contentOffset=\(S2OnDeviceTransitionText.point(offset))；" +
                diagnosticContext(
                    pageIndex: pageIndex,
                    assetLocalIdentifier: assetLocalIdentifier
                )
        )
    }

    /// IC-095 R1：内层缩放容器 `setContentOffset` 的实际写入（`applyNativeState` 的独立写入点）。
    func recordInnerContentOffsetWrite(
        offset: CGPoint,
        source: String,
        pageIndex: Int?,
        assetLocalIdentifier: String?
    ) {
        guard isRecording else {
            return
        }
        geometryWriteCount += 1
        recordEvent(
            name: "内层setContentOffset",
            source: source,
            details: "offset=\(S2OnDeviceTransitionText.point(offset))；" +
                diagnosticContext(
                    pageIndex: pageIndex,
                    assetLocalIdentifier: assetLocalIdentifier
                )
        )
    }

    func recordNativePageChange(
        from previousIndex: Int,
        to targetIndex: Int,
        accepted: Bool
    ) {
        recordEvent(
            name: "handleNativePageChange",
            source: "S2NativePagerViewController.finishNativePaging",
            details: "from=\(previousIndex)；to=\(targetIndex)；accepted=\(accepted)"
        )
    }

    /// IC-090 R2 场景 C：捏合结束链路上的五类事件。全部只在录制中追加记录，
    /// 不改变任何产品行为。
    func recordScrollViewDidEndZooming(
        scale: CGFloat,
        endedAtMinimum: Bool,
        pinchWasActive: Bool,
        pageIndex: Int?,
        assetLocalIdentifier: String?
    ) {
        let scaleText = S2OnDeviceTransitionText.number(scale)
        let flags = "scale=\(scaleText)；" +
            "endedAtMinimum=\(endedAtMinimum)；" +
            "pinchWasActive=\(pinchWasActive)；"
        recordEvent(
            name: "scrollViewDidEndZooming",
            source: "S2NativeZoomPageController.scrollViewDidEndZooming",
            details: flags + diagnosticContext(
                pageIndex: pageIndex,
                assetLocalIdentifier: assetLocalIdentifier
            )
        )
    }

    func recordFinishNativePinch(
        scale: CGFloat,
        targetScale: CGFloat?,
        displacement: CGFloat,
        peakVelocity: CGFloat,
        duration: TimeInterval,
        path: String
    ) {
        let targetText: String
        if let targetScale {
            targetText = S2OnDeviceTransitionText.number(targetScale)
        } else {
            targetText = "nil"
        }
        let scaleText = S2OnDeviceTransitionText.number(scale)
        let displacementText = S2OnDeviceTransitionText.number(displacement)
        let velocityText = S2OnDeviceTransitionText.number(peakVelocity)
        let durationText = S2OnDeviceTransitionText.number(duration)
        recordEvent(
            name: "finishNativePinch",
            source: "S2NativePagerViewController.finishNativePinch",
            details: "scale=\(scaleText)；targetScale=\(targetText)；" +
                "displacement=\(displacementText)；" +
                "peakVelocity=\(velocityText)；" +
                "duration=\(durationText)；path=\(path)"
        )
    }

    func recordSetZoomScale(
        scale: CGFloat,
        animated: Bool,
        previousScale: CGFloat,
        source: String
    ) {
        guard isRecording else {
            return
        }
        geometryWriteCount += 1
        let scaleText = S2OnDeviceTransitionText.number(scale)
        let fromText = S2OnDeviceTransitionText.number(previousScale)
        recordEvent(
            name: "setZoomScale",
            source: source,
            details: "scale=\(scaleText)；animated=\(animated)；from=\(fromText)"
        )
    }

    /// 归位到 1x 的几何写入：照片层几何本身仍由既有「照片几何写入」事件记录，
    /// 本事件补的是同一次归位里 `contentInset` / `contentSize` / `contentOffset` 的写入。
    func recordOneXSnapBackWrite(
        source: String,
        wroteContentInset: Bool,
        wroteContentSize: Bool,
        wroteContentOffset: Bool,
        wrotePhotoGeometry: Bool,
        pageIndex: Int?,
        assetLocalIdentifier: String?
    ) {
        guard isRecording else {
            return
        }
        // IC-095 R1：本次归位确有落笔时才计入几何写入；四项全假的空转不计。
        if wroteContentInset || wroteContentSize ||
            wroteContentOffset || wrotePhotoGeometry {
            geometryWriteCount += 1
        }
        let writes = "contentInset=\(wroteContentInset)；" +
            "contentSize=\(wroteContentSize)；" +
            "contentOffset=\(wroteContentOffset)；" +
            "照片几何=\(wrotePhotoGeometry)；"
        recordEvent(
            name: "吸附归位写入",
            source: source,
            details: writes + diagnosticContext(
                pageIndex: pageIndex,
                assetLocalIdentifier: assetLocalIdentifier
            )
        )
    }

    /// IC-093 R1：一次被抑制的图片替换（同资产、像素更少，未上屏）。
    /// 与 `图片替换` 互斥：同一次返回结果只会产生其中一条。
    func recordImageReplacementSuppressed(
        assetID: String,
        resultName: String,
        displayedPixelSize: CGSize,
        candidatePixelSize: CGSize
    ) {
        let displayed = "displayed=(w=" +
            S2OnDeviceTransitionText.number(displayedPixelSize.width) +
            ",h=" +
            S2OnDeviceTransitionText.number(displayedPixelSize.height) +
            ")；"
        let candidate = "candidate=(w=" +
            S2OnDeviceTransitionText.number(candidatePixelSize.width) +
            ",h=" +
            S2OnDeviceTransitionText.number(candidatePixelSize.height) +
            ")"
        recordEvent(
            name: "图片替换被抑制",
            source: "S2TemporaryPhotoImageView.requestImage",
            details: "asset=\(assetID)；result=\(resultName)；" +
                displayed + candidate
        )
    }

    func recordImageReplacement(_ record: S2ImageReplacementRecord) {
        let widthText = S2OnDeviceTransitionText.number(record.pixelSize.width)
        let heightText = S2OnDeviceTransitionText.number(record.pixelSize.height)
        recordEvent(
            name: "图片替换",
            source: "S2TemporaryPhotoImageView.requestImage",
            details: "asset=\(record.assetID)；" +
                "result=\(record.resultName)；" +
                "pixel=(w=\(widthText),h=\(heightText))"
        )
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

    func recordUpdateUIView(
        wrotePhotoGeometry: Bool,
        wroteAnyGeometry: Bool
    ) {
        recordEvent(
            name: "updateUIView",
            source: "S2NativePhotoPager.updateUIViewController",
            details: "写入照片几何=\(wrotePhotoGeometry)；" +
                "写入任意几何=\(wroteAnyGeometry)"
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
        geometryWriteCount += 1
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
            "逐帧字段=time,animationKeys,modelFrame,presentationFrame,transform,zoomScale,contentOffset,contentSize,contentInset,adjustedContentInset,V,s,pagingContentOffsetX,pagingIsDragging,pagingIsDecelerating,currentIndex,settledIndex,pageIndicesPresent,pageLoadStates,nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance,presentationZoomScale,isZoomBouncing,isDecelerating,imageRequestResult,lastImageReplacement",
            "离散事件字段=time,event,source,details",
            "---"
        ]
        for (index, record) in sortedRecords.enumerated() {
            let prefix = String(format: "%06d", index + 1) +
                "\ttime=\(timestamp(record.timestamp - startedAt))"
            switch record.payload {
            case let .frame(sample):
                // IC-090 R2：逐帧行按 IC-068 / IC-079 / IC-082 / IC-090 四段拼接，
                // 字段顺序与头部声明行完全一致；分段只为不让单个表达式随字段数变长。
                let base = "\tkind=frame" +
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
                    "\ts=\(optionalNumber(sample.scale))"
                let paging = "\tpagingContentOffsetX=\(optionalNumber(sample.pagingContentOffsetX))" +
                    "\tpagingIsDragging=\(optionalBool(sample.pagingIsDragging))" +
                    "\tpagingIsDecelerating=\(optionalBool(sample.pagingIsDecelerating))" +
                    "\tcurrentIndex=\(optionalIndex(sample.currentIndex))" +
                    "\tsettledIndex=\(optionalIndex(sample.settledIndex))" +
                    "\tpageIndicesPresent=\(indexList(sample.pageIndicesPresent))" +
                    "\tpageLoadStates=\(loadStates(sample.pageLoadStates))"
                let nx = "\tnxDistanceToPreviousBoundary=\(optionalNumber(sample.nxDistanceToPreviousBoundary))" +
                    "\tnxDistanceToNextBoundary=\(optionalNumber(sample.nxDistanceToNextBoundary))" +
                    "\tnxOverflowDistance=\(optionalNumber(sample.nxOverflowDistance))"
                let pinchEnd = "\tpresentationZoomScale=\(optionalNumber(sample.presentationZoomScale))" +
                    "\tisZoomBouncing=\(optionalBool(sample.isZoomBouncing))" +
                    "\tisDecelerating=\(optionalBool(sample.isDecelerating))" +
                    "\timageRequestResult=\(sample.imageRequestResult ?? "nil")" +
                    "\tlastImageReplacement=\(imageReplacement(sample.lastImageReplacement))"
                lines.append(prefix + base + paging + nx + pinchEnd)
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

    static func optionalBool(_ value: Bool?) -> String {
        value.map { $0 ? "true" : "false" } ?? "nil"
    }

    static func optionalIndex(_ value: Int?) -> String {
        value.map(String.init) ?? "nil"
    }

    static func indexList(_ values: [Int]) -> String {
        "[" + values.sorted().map(String.init).joined(separator: ",") + "]"
    }

    /// IC-090 R2：最近一次图片替换。`t` 与逐帧记录同源（`CACurrentMediaTime()` 绝对值），
    /// 与头部「起始绝对时间」相减即可对齐到 `time` 相对时间轴。
    static func imageReplacement(_ value: S2ImageReplacementRecord?) -> String {
        guard let value else {
            return "nil"
        }
        return "(asset=\(value.assetID),result=\(value.resultName)," +
            "w=\(number(value.pixelSize.width)),h=\(number(value.pixelSize.height))," +
            "t=\(number(value.timestamp)))"
    }

    static func loadStates(_ values: [Int: String]) -> String {
        "[" + values.keys.sorted().map { "\($0)=\(values[$0] ?? "nil")" }
            .joined(separator: ",") + "]"
    }

    static func visibility(_ value: S2InterfaceVisibility) -> String {
        value == .visible ? "显示" : "隐藏"
    }

    /// IC-095 R1：事件 details 复用与逐帧记录相同的点格式。
    static func point(_ value: CGPoint) -> String {
        "(x=\(number(value.x)),y=\(number(value.y)))"
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

    /// IC-090 R2：事件 details 复用同一数值格式，故由 private 放开为内部可见。
    static func number<T: BinaryFloatingPoint>(_ value: T) -> String {
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

/// IC-090 R2：一次图片替换的诊断记录。`timestamp` 与逐帧记录同用
/// `CACurrentMediaTime()`，因此可与松手后的逐帧差分对齐。
struct S2ImageReplacementRecord: Equatable {
    let assetID: String
    let resultName: String
    let pixelSize: CGSize
    let timestamp: CFTimeInterval
}

/// IC-079 R1：按资产记录图像加载态，仅供诊断埋点读取；不发布、不影响产品状态。
/// IC-090 R2：同时登记每个资产最近一次图片请求结果与最近一次图片替换。
final class S2ImageLoadStateRegistry: ObservableObject {
    private var states: [String: S2ImageLoadState] = [:]
    private var requestResults: [String: String] = [:]
    private(set) var lastImageReplacement: S2ImageReplacementRecord?

    func update(_ state: S2ImageLoadState, for assetID: String) {
        states[assetID] = state
    }

    func state(for assetID: String) -> S2ImageLoadState? {
        states[assetID]
    }

    func updateRequestResult(
        _ result: S2ImageRequestResult,
        for assetID: String
    ) {
        requestResults[assetID] = result.diagnosticName
    }

    func requestResult(for assetID: String) -> String? {
        requestResults[assetID]
    }

    func recordImageReplacement(_ record: S2ImageReplacementRecord) {
        lastImageReplacement = record
    }
}

/// IC-090 R2：一次图片请求结果的诊断名。与 `S2ImageLoadState.diagnosticName` 同处
/// 诊断协议段落，故与它一样不进 String Catalog（不是用户可见文案）。
extension S2ImageRequestResult {
    var diagnosticName: String {
        switch self {
        case .degradedPreview:
            return "degradedPreview"
        case .finalImage:
            return "finalImage"
        case .failure:
            return "failure"
        case .cancelled:
            return "cancelled"
        case .assetUnavailable:
            return "assetUnavailable"
        }
    }
}

extension S2ImageLoadState {
    var diagnosticName: String {
        switch self {
        case .loading:
            return "loading"
        case .displayed:
            return "displayed"
        case .failed:
            return "failed"
        }
    }
}

// MARK: - IC-099b R2：字节数探针（仅诊断，零产品行为）

/// 探针的资产类别。
enum S2AssetSizeProbeMediaKind: String, CaseIterable, Sendable {
    case photo
    case livePhoto
    case video

    var displayName: String {
        switch self {
        case .photo:
            return "照片"
        case .livePhoto:
            return "LivePhoto"
        case .video:
            return "视频"
        }
    }
}

/// 单条取数的失败原因。两条途径共用同一套枚举；P2 断言逐项覆盖。
enum S2AssetSizeProbeFailure: String, CaseIterable, Sendable {
    /// 本地没有登记这个资产（S2 范围与相册状态不一致）。
    case assetUnavailable
    /// 资产没有可用的主资源（`PHAssetResource.assetResources(for:)` 为空或类型不匹配）。
    case resourceUnavailable
    /// 请求返回错误。
    case requestFailed
    /// 请求被系统取消。
    case cancelled
    /// 资源只在 iCloud，禁网络时取不到。
    case notLocal
    /// 请求成功但没有可用的文件 URL（已编辑视频的合成资产没有单一 URL 即此类）。
    case noURL
    /// 拿到 URL 但读文件属性失败。
    case fileAttributeUnavailable

    var displayName: String {
        switch self {
        case .assetUnavailable:
            return "资产不可用"
        case .resourceUnavailable:
            return "无主资源"
        case .requestFailed:
            return "请求失败"
        case .cancelled:
            return "请求被取消"
        case .notLocal:
            return "资源不在本地"
        case .noURL:
            return "无可用URL"
        case .fileAttributeUnavailable:
            return "文件属性不可读"
        }
    }
}

/// 一个资产上两条途径的取数结果。纯数据，不含任何 PhotoKit 类型。
struct S2AssetSizeProbeMeasurement: Equatable, Sendable {
    let assetID: String
    let mediaKind: S2AssetSizeProbeMediaKind
    let isEdited: Bool
    /// URL 途径：照片 `fullSizeImageURL`、视频 `AVURLAsset.url` 的文件属性字节。
    let urlByteCount: Int64?
    let urlFailure: S2AssetSizeProbeFailure?
    let urlElapsedMilliseconds: Double
    /// 数据途径：主资源 `requestData` 流式累加字节（语义基准，仅探针内使用）。
    let dataByteCount: Int64?
    let dataFailure: S2AssetSizeProbeFailure?
    let dataElapsedMilliseconds: Double

    /// 两途径都成功时的差值（URL − 数据）。已编辑资产上非零即语义差的实测值。
    var byteDelta: Int64? {
        guard let urlByteCount, let dataByteCount else {
            return nil
        }
        return urlByteCount - dataByteCount
    }
}

/// 取数接口。产品侧只有调试面板按钮会调用它；PhotoKit 实现在 `Services/` 层。
protocol S2AssetSizeProbing: AnyObject {
    func measure(assetID: String) async -> S2AssetSizeProbeMeasurement
}

/// 探针报告的全部文本拼装。纯函数，P2 直接断言。
enum S2AssetSizeProbeText {
    static let formatVersion = 1
    static let columns =
        "assetID前8位｜类型｜是否已编辑｜URL字节｜数据字节｜差值｜" +
        "URL耗时｜数据耗时｜失败原因"

    static func identifierPrefix(_ assetID: String) -> String {
        String(assetID.prefix(8))
    }

    static func row(_ measurement: S2AssetSizeProbeMeasurement) -> String {
        [
            identifierPrefix(measurement.assetID),
            measurement.mediaKind.displayName,
            "已编辑=" + boolText(measurement.isEdited),
            "URL字节=" + optionalCount(measurement.urlByteCount),
            "数据字节=" + optionalCount(measurement.dataByteCount),
            "差值=" + optionalCount(measurement.byteDelta),
            "URL耗时=" + milliseconds(measurement.urlElapsedMilliseconds),
            "数据耗时=" + milliseconds(measurement.dataElapsedMilliseconds),
            "失败原因=" + failureText(measurement)
        ].joined(separator: "｜")
    }

    static func header(sampleCount: Int, totalCount: Int, limit: Int) -> String {
        var lines = [
            "IC-099b 字节数探针",
            "格式版本=\(formatVersion)",
            "列=" + columns,
            "URL途径=照片 requestContentEditingInput→fullSizeImageURL 文件属性；" +
                "视频 requestAVAsset→AVURLAsset.url 文件属性（均禁网络）",
            "数据途径=主资源 requestData 流式累加（禁网络），仅探针内使用",
            "样本数=\(sampleCount)；范围内资产总数=\(totalCount)；上限=\(limit)"
        ]
        if totalCount > sampleCount {
            lines.append("注：范围内资产超过上限，只取前 \(sampleCount) 个")
        }
        return lines.joined(separator: "\n")
    }

    static func summary(
        _ measurements: [S2AssetSizeProbeMeasurement]
    ) -> String {
        let total = measurements.count
        let urlSuccess = measurements.filter { $0.urlByteCount != nil }.count
        let dataSuccess = measurements.filter { $0.dataByteCount != nil }.count
        let editedCount = measurements.filter(\.isEdited).count
        let nonZeroDelta = measurements.filter {
            ($0.byteDelta ?? 0) != 0
        }.count
        let kindCounts = S2AssetSizeProbeMediaKind.allCases.map { kind in
            kind.displayName + "=" +
                String(measurements.filter { $0.mediaKind == kind }.count)
        }.joined(separator: "｜")

        var lines = [
            "汇总｜URL途径成功=\(urlSuccess)/\(total)（" +
                percentage(urlSuccess, of: total) + "）｜" +
                "数据途径成功=\(dataSuccess)/\(total)（" +
                percentage(dataSuccess, of: total) + "）",
            "汇总｜逐类样本数：" + kindCounts,
            "汇总｜已编辑样本=\(editedCount)",
            "汇总｜两途径均成功且差值非零=\(nonZeroDelta)"
        ]
        let failures = failureDistribution(measurements)
        lines.append("汇总｜失败原因分布：" + (failures.isEmpty ? "无" : failures))
        return lines.joined(separator: "\n")
    }

    static func report(
        measurements: [S2AssetSizeProbeMeasurement],
        totalCount: Int,
        limit: Int
    ) -> String {
        (
            [header(
                sampleCount: measurements.count,
                totalCount: totalCount,
                limit: limit
            )] +
            measurements.map(row) +
            [summary(measurements)]
        ).joined(separator: "\n")
    }

    static func progress(finished: Int, total: Int) -> String {
        "字节数探针 \(finished)/\(total)"
    }

    private static func failureDistribution(
        _ measurements: [S2AssetSizeProbeMeasurement]
    ) -> String {
        var parts: [String] = []
        for failure in S2AssetSizeProbeFailure.allCases {
            let urlCount = measurements.filter { $0.urlFailure == failure }.count
            if urlCount > 0 {
                parts.append("URL:\(failure.displayName)=\(urlCount)")
            }
            let dataCount = measurements.filter {
                $0.dataFailure == failure
            }.count
            if dataCount > 0 {
                parts.append("数据:\(failure.displayName)=\(dataCount)")
            }
        }
        return parts.joined(separator: "｜")
    }

    private static func failureText(
        _ measurement: S2AssetSizeProbeMeasurement
    ) -> String {
        var parts: [String] = []
        if let urlFailure = measurement.urlFailure {
            parts.append("URL:" + urlFailure.displayName)
        }
        if let dataFailure = measurement.dataFailure {
            parts.append("数据:" + dataFailure.displayName)
        }
        return parts.isEmpty ? "无" : parts.joined(separator: "，")
    }

    private static func boolText(_ value: Bool) -> String {
        value ? "是" : "否"
    }

    private static func optionalCount(_ value: Int64?) -> String {
        value.map { String($0) } ?? "nil"
    }

    private static func milliseconds(_ value: Double) -> String {
        String(
            format: "%.2fms",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }

    private static func percentage(_ value: Int, of total: Int) -> String {
        guard total > 0 else {
            return "0.0%"
        }
        return String(
            format: "%.1f%%",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(value) * 100 / Double(total)
        )
    }
}

/// 探针的运行协调器。**关闭状态零副作用**：不注册任何观察者、不持有取数实现、
/// 不发起任何请求、不写持久化；只有面板按钮显式调用 `run` 才会开始串行取数。
final class S2AssetSizeProbeCoordinator: ObservableObject {
    /// 卡内上限：范围内资产超过该数时只取前 60 个，并在报告头部注明。
    static let assetLimit = 60

    @Published private(set) var isRunning = false
    @Published private(set) var progressText = ""
    @Published private(set) var reportText = ""

    private(set) var measurements: [S2AssetSizeProbeMeasurement] = []
    private var runTask: Task<Void, Never>?

    var canExport: Bool {
        !isRunning && !reportText.isEmpty
    }

    func run(assetIDs: [String], using prober: S2AssetSizeProbing) {
        guard !isRunning, !assetIDs.isEmpty else {
            return
        }
        let totalCount = assetIDs.count
        let sample = Array(assetIDs.prefix(Self.assetLimit))
        isRunning = true
        measurements = []
        reportText = ""
        progressText = S2AssetSizeProbeText.progress(
            finished: 0,
            total: sample.count
        )
        runTask = Task { @MainActor [weak self] in
            var collected: [S2AssetSizeProbeMeasurement] = []
            for (index, assetID) in sample.enumerated() {
                let measurement = await prober.measure(assetID: assetID)
                collected.append(measurement)
                guard let self else {
                    return
                }
                self.measurements = collected
                self.progressText = S2AssetSizeProbeText.progress(
                    finished: index + 1,
                    total: sample.count
                )
            }
            guard let self else {
                return
            }
            self.reportText = S2AssetSizeProbeText.report(
                measurements: collected,
                totalCount: totalCount,
                limit: Self.assetLimit
            )
            self.isRunning = false
            self.runTask = nil
        }
    }
}


// MARK: - IC-108 B：双击丝滑度诊断探针（只测不改）
//
// 模式照 IC-099b 字节数探针：coordinator + 报告文本 + 标定面板只读区与复制入口。
// 开关是**运行态**：不入 `S2CalibrationConfiguration`（`schemaVersion` 不动）、
// 不进 `export-format.md`；默认关闭，关闭时 pager 侧的 `doubleTapProbe` 为 nil，
// 所有埋点是可选链空调用，**零开销**。
//
// 本探针不改双击 / 缩放 / 解码的任何行为，只做观测。

/// 一次图像请求在双击窗口内的观测。`finishedAt` 为 nil 表示录制结束时仍未回。
struct S2DoubleTapProbeImageRequest: Equatable {
    let assetID: String
    let targetSize: CGSize
    let startedAt: CFTimeInterval
    var finishedAt: CFTimeInterval?
    /// 原始回调所在线程是否为主线程——在 `DispatchQueue.main.async` 之前捕获，
    /// 故反映的是解码 / 回调的真实线程，而不是切回主线程之后的假象。
    var callbackOnMainThread: Bool?
    /// 返回图像的像素尺寸；未回或无图时为 `.zero`。
    var returnedPixelSize: CGSize = .zero
}

/// `imageRequestScale` 的一次变化。
struct S2DoubleTapProbeScaleChange: Equatable {
    let scale: CGFloat
    let timestamp: CFTimeInterval
}

/// 一次双击事件的完整观测。
struct S2DoubleTapProbeEvent: Equatable {
    /// 进入 `Nx` 为 true，退回 `1x` 为 false。
    let enteringNx: Bool
    let targetScale: CGFloat
    let assetID: String
    let pageIndex: Int
    let startScale: CGFloat
    let startedAt: CFTimeInterval
    var endedAt: CFTimeInterval?
    var endScale: CGFloat?
    /// CADisplayLink 每帧时间戳；统计量在出报告时才算，采样期只做 O(1) 追加，
    /// 不做任何排序或格式化，避免阻塞主线程。
    var frameTimestamps: [CFTimeInterval] = []
    /// 显示链路的标称帧间隔（`CADisplayLink.duration`），用于判定丢帧。
    var nominalFrameInterval: CFTimeInterval = 0
    var imageRequestScaleChanges: [S2DoubleTapProbeScaleChange] = []
    var imageRequests: [S2DoubleTapProbeImageRequest] = []

    var frameIntervals: [CFTimeInterval] {
        guard frameTimestamps.count >= 2 else {
            return []
        }
        return zip(frameTimestamps, frameTimestamps.dropFirst()).map {
            $1 - $0
        }
    }

    var totalFrameCount: Int {
        frameTimestamps.count
    }

    /// 丢帧数：间隔超过标称帧间隔 1.5 倍的帧数（标称值缺失时按 60Hz 兜底）。
    var droppedFrameCount: Int {
        let nominal = nominalFrameInterval > 0
            ? nominalFrameInterval
            : 1.0 / 60.0
        return frameIntervals.filter { $0 > nominal * 1.5 }.count
    }

    var maximumFrameInterval: CFTimeInterval {
        frameIntervals.max() ?? 0
    }

    /// p95 帧间隔：升序后取第 `ceil(0.95 * n) - 1` 位。
    var p95FrameInterval: CFTimeInterval {
        let sorted = frameIntervals.sorted()
        guard !sorted.isEmpty else {
            return 0
        }
        let rank = Int((0.95 * Double(sorted.count)).rounded(.up))
        return sorted[min(sorted.count - 1, max(0, rank - 1))]
    }

    var durationSeconds: CFTimeInterval {
        guard let endedAt else {
            return 0
        }
        return endedAt - startedAt
    }
}

final class S2DoubleTapSmoothnessProbeCoordinator: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var reportText = ""

    private(set) var events: [S2DoubleTapProbeEvent] = []
    private var activeEventIndex: Int?

    var canExport: Bool {
        !isRecording && !events.isEmpty
    }

    func start() {
        guard !isRecording else {
            return
        }
        events = []
        activeEventIndex = nil
        reportText = ""
        isRecording = true
    }

    func stop() {
        guard isRecording else {
            return
        }
        isRecording = false
        activeEventIndex = nil
        reportText = S2DoubleTapProbeText.report(events: events)
    }

    // MARK: 埋点（关闭时调用方持 nil 引用，这些方法根本不会被调到）

    func recordDoubleTapBegan(
        enteringNx: Bool,
        targetScale: CGFloat,
        assetID: String,
        pageIndex: Int,
        startScale: CGFloat,
        timestamp: CFTimeInterval
    ) {
        guard isRecording else {
            return
        }
        events.append(
            S2DoubleTapProbeEvent(
                enteringNx: enteringNx,
                targetScale: targetScale,
                assetID: assetID,
                pageIndex: pageIndex,
                startScale: startScale,
                startedAt: timestamp
            )
        )
        activeEventIndex = events.count - 1
    }

    func recordDoubleTapFrame(
        timestamp: CFTimeInterval,
        nominalInterval: CFTimeInterval
    ) {
        guard isRecording, let index = activeEventIndex else {
            return
        }
        events[index].frameTimestamps.append(timestamp)
        if events[index].nominalFrameInterval <= 0 {
            events[index].nominalFrameInterval = nominalInterval
        }
    }

    func recordDoubleTapEnded(
        endScale: CGFloat,
        timestamp: CFTimeInterval
    ) {
        guard isRecording, let index = activeEventIndex else {
            return
        }
        events[index].endedAt = timestamp
        events[index].endScale = endScale
        activeEventIndex = nil
    }

    func recordImageRequestScaleChange(
        scale: CGFloat,
        timestamp: CFTimeInterval
    ) {
        guard isRecording, let index = activeEventIndex else {
            return
        }
        events[index].imageRequestScaleChanges.append(
            S2DoubleTapProbeScaleChange(scale: scale, timestamp: timestamp)
        )
    }

    func recordImageRequestStarted(
        assetID: String,
        targetSize: CGSize,
        timestamp: CFTimeInterval
    ) {
        guard isRecording, let index = activeEventIndex else {
            return
        }
        events[index].imageRequests.append(
            S2DoubleTapProbeImageRequest(
                assetID: assetID,
                targetSize: targetSize,
                startedAt: timestamp
            )
        )
    }

    func recordImageRequestFinished(
        assetID: String,
        onMainThread: Bool,
        pixelSize: CGSize,
        timestamp: CFTimeInterval
    ) {
        guard isRecording, let index = activeEventIndex else {
            return
        }
        guard let requestIndex = events[index].imageRequests.lastIndex(
            where: { $0.assetID == assetID && $0.finishedAt == nil }
        ) else {
            return
        }
        events[index].imageRequests[requestIndex].finishedAt = timestamp
        events[index].imageRequests[requestIndex].callbackOnMainThread =
            onMainThread
        events[index].imageRequests[requestIndex].returnedPixelSize = pixelSize
    }
}

enum S2DoubleTapProbeText {
    static let formatVersion = 1
    static let columns =
        "序号｜方向｜目标倍率｜s起｜s止｜时长ms｜总帧数｜丢帧数｜" +
        "最大间隔ms｜p95间隔ms｜页索引｜资产前8位"

    static func milliseconds(_ seconds: CFTimeInterval) -> String {
        String(format: "%.2f", seconds * 1_000)
    }

    static func decimal(_ value: CGFloat) -> String {
        String(format: "%.4f", Double(value))
    }

    static func identifierPrefix(_ assetID: String) -> String {
        String(assetID.prefix(8))
    }

    static func row(index: Int, event: S2DoubleTapProbeEvent) -> String {
        [
            "\(index + 1)",
            event.enteringNx ? "进" : "出",
            decimal(event.targetScale),
            decimal(event.startScale),
            event.endScale.map(decimal) ?? "未结束",
            milliseconds(event.durationSeconds),
            "\(event.totalFrameCount)",
            "\(event.droppedFrameCount)",
            milliseconds(event.maximumFrameInterval),
            milliseconds(event.p95FrameInterval),
            "\(event.pageIndex)",
            identifierPrefix(event.assetID)
        ].joined(separator: "｜")
    }

    static func scaleChangeLines(
        _ event: S2DoubleTapProbeEvent
    ) -> [String] {
        event.imageRequestScaleChanges.map { change in
            "  imageRequestScale变化｜倍率=" + decimal(change.scale) +
                "｜距起始ms=" +
                milliseconds(change.timestamp - event.startedAt)
        }
    }

    static func imageRequestLines(
        _ event: S2DoubleTapProbeEvent
    ) -> [String] {
        event.imageRequests.map { request in
            let finished = request.finishedAt.map {
                milliseconds($0 - event.startedAt)
            } ?? "未回"
            let thread = request.callbackOnMainThread.map {
                $0 ? "主线程" : "非主线程"
            } ?? "未回"
            return "  图像请求｜资产=" + identifierPrefix(request.assetID) +
                "｜发起距起始ms=" +
                milliseconds(request.startedAt - event.startedAt) +
                "｜完成距起始ms=" + finished +
                "｜回调线程=" + thread +
                "｜目标尺寸=(w=" +
                S2OnDeviceTransitionText.number(request.targetSize.width) +
                ",h=" +
                S2OnDeviceTransitionText.number(request.targetSize.height) +
                ")｜返回像素=(w=" +
                S2OnDeviceTransitionText.number(
                    request.returnedPixelSize.width
                ) +
                ",h=" +
                S2OnDeviceTransitionText.number(
                    request.returnedPixelSize.height
                ) + ")"
        }
    }

    static func report(events: [S2DoubleTapProbeEvent]) -> String {
        var lines = [
            "IC-108 B 双击丝滑度探针",
            "格式版本=\(formatVersion)",
            "列=" + columns,
            "口径=帧间隔取 CADisplayLink 相邻时间戳之差；" +
                "丢帧=间隔超过标称帧间隔 1.5 倍的帧数；" +
                "回调线程在切回主线程之前捕获",
            "事件数=\(events.count)"
        ]
        for (index, event) in events.enumerated() {
            lines.append(row(index: index, event: event))
            lines.append(contentsOf: scaleChangeLines(event))
            lines.append(contentsOf: imageRequestLines(event))
        }
        return lines.joined(separator: "\n")
    }
}
