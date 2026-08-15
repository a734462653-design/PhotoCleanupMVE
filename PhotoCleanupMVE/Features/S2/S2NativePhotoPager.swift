import SwiftUI
import UIKit

struct S2NativePageContent {
    let index: Int
    let assetID: String
    let fittedSize: CGSize
    let doubleTapTargetScale: CGFloat
    let content: AnyView
}

struct S2NativePhotoPager: UIViewControllerRepresentable {
    let machine: S2StateMachine
    let configuration: S2CalibrationConfiguration
    let viewportSize: CGSize
    let pages: [S2NativePageContent]
    let onLongPress: () -> Void

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
            onLongPress: onLongPress
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

final class S2ImmediateTapGestureRecognizer: UITapGestureRecognizer {
    private(set) var arrivalDate = Date()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        arrivalDate = Date()
        super.touchesBegan(touches, with: event)
    }
}

final class S2NativeZoomPageController: UIViewController,
    UIScrollViewDelegate {
    let index: Int
    let zoomScrollView = S2NativeZoomScrollView()
    private let hostingController: UIHostingController<AnyView>
    private let tapRecognizer = S2ImmediateTapGestureRecognizer()
    private weak var owner: S2NativePagerViewController?
    private(set) var fittedSize: CGSize
    private(set) var doubleTapTargetScale: CGFloat
    private var pinchIsActive = false
    private var pinchStartDate: Date?
    private var pinchStartScale: CGFloat = 1
    private var pinchPeakVelocity: CGFloat = 0

    init(
        page: S2NativePageContent,
        owner: S2NativePagerViewController
    ) {
        index = page.index
        fittedSize = page.fittedSize
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
        hostingController.didMove(toParent: self)
        tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        zoomScrollView.addGestureRecognizer(tapRecognizer)
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
        doubleTapTargetScale = page.doubleTapTargetScale
        hostingController.rootView = page.content
        tapRecognizer.numberOfTouchesRequired = max(
            1,
            configuration.singleTapTouchCount
        )
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

    @objc private func handleTap(_ recognizer: S2ImmediateTapGestureRecognizer) {
        owner?.handleTap(on: self, recognizer: recognizer)
    }
}

final class S2NativePagerViewController: UIViewController,
    UIScrollViewDelegate {
    let pagingScrollView = S2NativePagingScrollView()
    private(set) var pageControllers: [Int: S2NativeZoomPageController] = [:]
    private weak var machine: S2StateMachine?
    private var configuration = S2CalibrationConfiguration.factoryPlaceholder
    private var viewportSize = CGSize.zero
    private var tapSequenceCoordinator = S2TapSequenceCoordinator()
    private var onLongPress: (() -> Void)?
    private var isApplyingSnapshot = false
    private var settledIndex = 0
    private var outerDragStartDate: Date?
    private var lastOuterTranslation = CGSize.zero
    private var lastOuterVelocity: CGFloat = 0
    private var lastOuterDuration: TimeInterval = 0

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
                addChild(controller)
                pagingScrollView.addSubview(controller.view)
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
        tapSequenceCoordinator.reset()
        outerDragStartDate = nil
        lastOuterTranslation = .zero
        onLongPress = nil
    }

    func handleTap(
        on page: S2NativeZoomPageController,
        recognizer: S2ImmediateTapGestureRecognizer
    ) {
        guard let machine,
              page.index == machine.currentIndex else {
            return
        }
        let completionDate = Date()
        let action = tapSequenceCoordinator.registerTap(
            at: recognizer.location(in: page.zoomScrollView),
            arrivalDate: recognizer.arrivalDate,
            completionDate: completionDate,
            decisionWindowMilliseconds:
                configuration.doubleTapDecisionWindowMilliseconds,
            maximumMovement: CGFloat(configuration.singleTapMaximumMovement),
            allowsDoubleTap: configuration.doubleTapTouchCount == 1
        )

        switch action {
        case .singleTap:
            let applied = machine.handleSingleTap()
            tapSequenceCoordinator.recordImmediateSingleTapApplied(applied)
        case let .doubleTap(revertImmediateSingleTap):
            let wasZoomed = machine.zoomState == .nX
            guard machine.handleNativeDoubleTap(
                targetScale: page.doubleTapTargetScale,
                revertingImmediateSingleTap: revertImmediateSingleTap
            ) else {
                return
            }
            if wasZoomed {
                page.zoomScrollView.setZoomScale(
                    1,
                    animated: configuration.animationsEnabled
                )
            } else {
                _ = page.zoomScrollView.performDoubleTapZoom(
                    at: recognizer.location(in: page.zoomScrollView),
                    targetScale: page.doubleTapTargetScale,
                    animated: configuration.animationsEnabled
                )
            }
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
            synchronizeNativeStateToMachine()
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
            tapSequenceCoordinator.reset()
        } else if targetIndex == previousIndex {
            reportSequenceBoundaryAttemptIfNeeded()
        }
        settledIndex = machine.currentIndex
        synchronizeNativeStateToMachine()
        outerDragStartDate = nil
    }

    private func synchronizeNativeStateToMachine() {
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
            animated: false
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
