import SwiftUI
import UIKit

struct S2NativePageContent {
    let index: Int
    let assetID: String
    let fittedSize: CGSize
    let cornerRadius: CGFloat
    let doubleTapTargetScale: CGFloat
    let content: AnyView
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
    let onPhotoSwitch: () -> Void

    func makeUIViewController(context _: Context) -> S2NativePagerViewController {
        S2NativePagerViewController()
    }

    func updateUIViewController(
        _ controller: S2NativePagerViewController,
        context _: Context
    ) {
        controller.apply(
            machine: machine,
            configuration: configuration,
            viewportSize: viewportSize,
            pages: pages,
            onLongPress: onLongPress,
            onPhotoSwitch: onPhotoSwitch
        )
    }

    static func dismantleUIViewController(
        _ controller: S2NativePagerViewController,
        coordinator _: ()
    ) {
        controller.resetInteractionState()
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
        frame = CGRect(
            x: -self.pageSpacing / 2,
            y: 0,
            width: pageStride,
            height: viewportHeight
        )
        contentSize = CGSize(
            width: CGFloat(self.itemCount) * pageStride,
            height: viewportHeight
        )
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
    private(set) var fittedSize = CGSize.zero
    private(set) var nativeZoomInvocationCount = 0
    private(set) var lastNativeZoomRect: CGRect?
    private(set) var isApplyingNativeState = false

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
        maximumZoomScale: CGFloat
    ) {
        let nextMaximumScale = max(1, maximumZoomScale)
        self.maximumZoomScale = nextMaximumScale
        minimumZoomScale = 1

        if zoomContentView !== contentView {
            zoomContentView?.removeFromSuperview()
            zoomContentView = contentView
            addSubview(contentView)
        }

        let nextSize = CGSize(
            width: max(0, fittedSize.width),
            height: max(0, fittedSize.height)
        )
        guard self.fittedSize != nextSize else {
            enforceOneXContentGeometry(
                contentView: contentView,
                fittedSize: nextSize
            )
            if zoomScale > nextMaximumScale {
                setZoomScale(nextMaximumScale, animated: false)
            }
            updatePanAvailability()
            return
        }

        let previousScale = min(zoomScale, nextMaximumScale)
        isApplyingNativeState = true
        if zoomScale != 1 {
            setZoomScale(1, animated: false)
        }
        self.fittedSize = nextSize
        contentView.transform = .identity
        contentView.frame = CGRect(origin: .zero, size: nextSize)
        contentSize = nextSize
        if previousScale > 1 {
            setZoomScale(previousScale, animated: false)
        }
        isApplyingNativeState = false
        setNeedsLayout()
        layoutIfNeeded()
        updatePanAvailability()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let nextInset = UIEdgeInsets(
            top: max(0, (bounds.height - contentSize.height) / 2),
            left: max(0, (bounds.width - contentSize.width) / 2),
            bottom: max(0, (bounds.height - contentSize.height) / 2),
            right: max(0, (bounds.width - contentSize.width) / 2)
        )
        if contentInset != nextInset {
            contentInset = nextInset
        }
    }

    func performDoubleTapZoom(
        at pointInViewport: CGPoint,
        targetScale: CGFloat,
        animated: Bool
    ) -> CGRect? {
        guard let zoomContentView,
              bounds.width > 0,
              bounds.height > 0,
              targetScale.isFinite,
              targetScale > 1 else {
            return nil
        }
        let pointInContent = convert(pointInViewport, to: zoomContentView)
        let targetRect = CGRect(
            x: pointInContent.x - bounds.width / (2 * targetScale),
            y: pointInContent.y - bounds.height / (2 * targetScale),
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        lastNativeZoomRect = targetRect
        nativeZoomInvocationCount += 1
        zoom(to: targetRect, animated: animated)
        return targetRect
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
        if abs(zoomScale - nextScale) > 0.000_001 {
            setZoomScale(nextScale, animated: false)
        }
        setNeedsLayout()
        layoutIfNeeded()
        let nextOffset = CGPoint(
            x: zoomContentView.frame.midX - bounds.width / 2 -
                viewportOffset.width,
            y: zoomContentView.frame.midY - bounds.height / 2 -
                viewportOffset.height
        )
        if abs(contentOffset.x - nextOffset.x) > 0.000_001 ||
            abs(contentOffset.y - nextOffset.y) > 0.000_001 {
            setContentOffset(nextOffset, animated: false)
        }
        isApplyingNativeState = false
        updatePanAvailability()
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

    func updatePanAvailability() {
        let shouldEnable = zoomScale > minimumZoomScale + 0.000_001
        if panGestureRecognizer.isEnabled != shouldEnable {
            panGestureRecognizer.isEnabled = shouldEnable
        }
    }

    private func enforceOneXContentGeometry(
        contentView: UIView,
        fittedSize: CGSize
    ) {
        guard abs(zoomScale - minimumZoomScale) <= 0.000_001 else {
            return
        }
        contentView.transform = .identity
        contentView.frame = CGRect(origin: .zero, size: fittedSize)
        contentSize = fittedSize
        setNeedsLayout()
        layoutIfNeeded()
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

final class S2NativeZoomPageController: UIViewController,
    UIScrollViewDelegate,
    UIGestureRecognizerDelegate {
    let index: Int
    let zoomScrollView = S2NativeZoomScrollView()
    let singleTapRecognizer = UITapGestureRecognizer()
    let doubleTapRecognizer = UITapGestureRecognizer()
    let verticalSwipeRecognizer = UIPanGestureRecognizer()
    private let hostingController: UIHostingController<AnyView>
    private weak var owner: S2NativePagerViewController?
    private(set) var fittedSize: CGSize
    private(set) var cornerRadius: CGFloat
    private(set) var doubleTapTargetScale: CGFloat
    private var pinchIsActive = false
    private var pinchStartDate: Date?
    private var pinchStartScale: CGFloat = 1
    private var pinchPeakVelocity: CGFloat = 0
    private var verticalSwipeStartDate: Date?
    private var immediateSingleTapWasApplied = false
    private(set) var nativeScrollPriorityIsConfigured = false

    init(
        page: S2NativePageContent,
        owner: S2NativePagerViewController
    ) {
        index = page.index
        fittedSize = page.fittedSize
        cornerRadius = page.cornerRadius
        doubleTapTargetScale = page.doubleTapTargetScale
        hostingController = UIHostingController(rootView: page.content)
        self.owner = owner
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        view = zoomScrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        zoomScrollView.delegate = self
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        zoomScrollView.configure(
            contentView: hostingController.view,
            fittedSize: fittedSize,
            maximumZoomScale: 1
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
        doubleTapRecognizer.delegate = self

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

    func update(
        page: S2NativePageContent,
        configuration: S2CalibrationConfiguration,
        scale: CGFloat,
        viewportOffset: CGSize,
        isCurrent: Bool
    ) {
        loadViewIfNeeded()
        fittedSize = page.fittedSize
        cornerRadius = page.cornerRadius
        doubleTapTargetScale = page.doubleTapTargetScale
        hostingController.rootView = page.content
        applyCornerMask()
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
        zoomScrollView.configure(
            contentView: hostingController.view,
            fittedSize: fittedSize,
            maximumZoomScale: CGFloat(configuration.pinchMaxScale)
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
        }
    }

    func resetZoom() {
        pinchIsActive = false
        zoomScrollView.applyNativeState(scale: 1, viewportOffset: .zero)
    }

    func resetTapState() {
        immediateSingleTapWasApplied = false
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
    func applyRecognizedSingleTap() -> Bool {
        let applied = owner?.handleSingleTap(on: self) == true
        immediateSingleTapWasApplied = applied
        return applied
    }

    @discardableResult
    func applyRecognizedDoubleTap(at location: CGPoint) -> Bool {
        let shouldRevert = immediateSingleTapWasApplied &&
            singleTapRecognizer.numberOfTouchesRequired ==
                doubleTapRecognizer.numberOfTouchesRequired
        immediateSingleTapWasApplied = false
        return owner?.handleDoubleTap(
            on: self,
            at: location,
            revertingImmediateSingleTap: shouldRevert
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
        guard scrollView === zoomScrollView,
              owner?.beginNativePinch(on: self) == true else {
            return
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
        guard scrollView === zoomScrollView, pinchIsActive else {
            return
        }
        let duration = Date().timeIntervalSince(pinchStartDate ?? Date())
        let displacement = abs(scale / max(0.000_001, pinchStartScale) - 1)
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

    func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === verticalSwipeRecognizer else {
            return true
        }
        let velocity = verticalSwipeRecognizer.velocity(in: zoomScrollView)
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer:
            UIGestureRecognizer
    ) -> Bool {
        let recognizers = [gestureRecognizer, otherGestureRecognizer]
        return recognizers.contains { $0 === singleTapRecognizer } &&
            recognizers.contains { $0 === doubleTapRecognizer }
    }

    private func applyCornerMask() {
        hostingController.view.layer.cornerRadius = max(0, cornerRadius)
        hostingController.view.layer.cornerCurve = .continuous
        hostingController.view.layer.masksToBounds = cornerRadius > 0
    }

    @objc private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }
        _ = applyRecognizedSingleTap()
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

final class S2NativePagerViewController: UIViewController,
    UIScrollViewDelegate {
    let pagingScrollView = S2NativePagingScrollView()
    private(set) var pageControllers: [Int: S2NativeZoomPageController] = [:]
    private weak var machine: S2StateMachine?
    private var configuration = S2CalibrationConfiguration.factoryPlaceholder
    private var viewportSize = CGSize.zero
    private var onLongPress: (() -> Void)?
    private var onPhotoSwitch: (() -> Void)?
    private var isApplyingSnapshot = false
    private var settledIndex = 0
    private var outerDragStartDate: Date?
    private var lastOuterTranslation = CGSize.zero
    private var lastOuterVelocity: CGFloat = 0
    private var lastOuterDuration: TimeInterval = 0
    private var nXEdgePagingInteraction: S2NxEdgePagingInteraction?
    private var lastNXEdgePagingProjection: S2NxEdgePagingProjection?

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.size.width > 0, view.bounds.size.height > 0 else {
            return
        }
        viewportSize = view.bounds.size
        layoutNativePages()
    }

    func apply(
        machine: S2StateMachine,
        configuration: S2CalibrationConfiguration,
        viewportSize: CGSize,
        pages: [S2NativePageContent],
        onLongPress: @escaping () -> Void,
        onPhotoSwitch: @escaping () -> Void
    ) {
        loadViewIfNeeded()
        self.machine = machine
        self.configuration = configuration
        self.viewportSize = viewportSize
        self.onLongPress = onLongPress
        self.onPhotoSwitch = onPhotoSwitch
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
                isCurrent: page.index == machine.currentIndex
            )
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
        pageControllers.values.forEach { $0.resetTapState() }
        outerDragStartDate = nil
        lastOuterTranslation = .zero
        nXEdgePagingInteraction = nil
        lastNXEdgePagingProjection = nil
        onLongPress = nil
        onPhotoSwitch = nil
    }

    @discardableResult
    func handleSingleTap(on page: S2NativeZoomPageController) -> Bool {
        guard let machine,
              page.index == machine.currentIndex else {
            return false
        }
        return machine.handleSingleTap()
    }

    @discardableResult
    func handleDoubleTap(
        on page: S2NativeZoomPageController,
        at location: CGPoint,
        revertingImmediateSingleTap: Bool
    ) -> Bool {
        guard let machine,
              page.index == machine.currentIndex else {
            return false
        }
        let wasZoomed = machine.zoomState == .nX
        guard machine.handleNativeDoubleTap(
            targetScale: page.doubleTapTargetScale,
            revertingImmediateSingleTap: revertingImmediateSingleTap
        ) else {
            return false
        }
        if wasZoomed {
            page.zoomScrollView.setZoomScale(
                1,
                animated: configuration.animationsEnabled
            )
        } else {
            _ = page.zoomScrollView.performDoubleTapZoom(
                at: location,
                targetScale: page.doubleTapTargetScale,
                animated: configuration.animationsEnabled
            )
        }
        return true
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
        let accepted = peakVelocity >=
            CGFloat(configuration.pinchMinimumVelocityPerSecond) &&
            durationIsAllowed(
                duration,
                maximumMilliseconds:
                    configuration.pinchMaximumDurationMilliseconds
            )
        guard let targetScale = machine.finishNativePinch(
            scale: scale,
            viewportOffset: page.zoomScrollView.reportedViewportOffset(),
            accepted: accepted
        ) else {
            return
        }
        if abs(page.zoomScrollView.zoomScale - targetScale) > 0.000_001 {
            page.zoomScrollView.setZoomScale(
                targetScale,
                animated: configuration.animationsEnabled
            )
        }
        page.zoomScrollView.updatePanAvailability()
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
            pageControllers.values.forEach { $0.resetTapState() }
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
        let switched = machine.handleHorizontalSwipe(
            direction: direction,
            startedAtPagingEdge: projection.overflowDistance > 0,
            distance: projection.overflowDistance,
            velocity: velocity
        )
        if switched {
            onPhotoSwitch?()
            pageControllers.values.forEach { $0.resetTapState() }
        }
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
            controller.view.frame = pagingScrollView.frameForPage(at: index)
            if let machine,
               !controller.zoomScrollView.isTracking,
               !controller.zoomScrollView.isDragging,
               !controller.zoomScrollView.isDecelerating,
               !controller.zoomScrollView.isZooming {
                controller.zoomScrollView.applyNativeState(
                    scale: index == machine.currentIndex ? machine.scale : 1,
                    viewportOffset: index == machine.currentIndex
                        ? machine.viewportOffset
                        : .zero
                )
            }
        }
        if !pagingScrollView.isTracking &&
            !pagingScrollView.isDragging &&
            !pagingScrollView.isDecelerating {
            pagingScrollView.contentOffset = pagingScrollView
                .contentOffsetForPage(at: settledIndex)
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
            if machine.handleNativePageChange(to: targetIndex) {
                onPhotoSwitch?()
                pageControllers.values.forEach { $0.resetTapState() }
            }
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

    private func durationIsAllowed(
        _ duration: TimeInterval,
        maximumMilliseconds: Double
    ) -> Bool {
        maximumMilliseconds == 0 ||
            duration * 1_000 <= maximumMilliseconds
    }
}
