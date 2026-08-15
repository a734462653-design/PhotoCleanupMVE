import Foundation
import SwiftUI

struct S2ImageContentContext {
    let assetID: String
    let fittedSize: CGSize
    let scale: CGFloat
    let requestStrategy: S2ImageRequestStrategy?
    let requestRevision: Int
    let onRequestReading: (S2ImageRequestReading) -> Void
}

struct S2BottomStripItemPresentation {
    let assetID: String
    let index: Int
    let isCurrent: Bool
    let isMarked: Bool
    let stripState: S2BottomStripState
}

struct S2AlbumPickerActions {
    let select: (S2AlbumReference) -> Void
    let reportFailure: () -> Void
    let cancel: () -> Void
}

struct S2View: View {
    typealias PhotoContent = (S2ImageContentContext) -> AnyView
    typealias StripItemContent = (S2BottomStripItemPresentation) -> AnyView
    typealias AlbumPickerContent = (
        S2AlbumPickerRequest,
        S2AlbumPickerActions
    ) -> AnyView

    @ObservedObject var machine: S2StateMachine
    @ObservedObject var calibration: S2CalibrationModel

    private let assetAspectRatio: (String) -> CGFloat
    private let photoContent: PhotoContent
    private let stripItemContent: StripItemContent
    private let albumPickerContent: AlbumPickerContent
    private let onBack: (S2ExitPayload) -> Void
    private let onConfirmation: (S2ExitPayload) -> Void
    private let onFavoriteRequest: (S2AssetActionRequest) -> Void
    private let onRecentAlbumRequest: (S2AlbumActionRequest) -> Void

    @State private var pinchIsActive = false
    @State private var pinchStartTime: Date?
    @State private var pinchPreviousTime: Date?
    @State private var pinchPreviousMagnification: CGFloat = 1
    @State private var pinchPeakVelocity: CGFloat = 0
    @State private var mainDragStartTime: Date?
    @State private var mainDragStartOffset = CGSize.zero
    @State private var mainDragPreviousTime: Date?
    @State private var mainDragPreviousTranslation = CGSize.zero
    @State private var mainDragPeakVelocity: CGFloat = 0
    @State private var firstTapDate: Date?
    @State private var firstTapLocation: CGPoint?
    @State private var pendingSingleTap: DispatchWorkItem?
    @State private var parameterPanelVisible = false
    @State private var readingsVisible = false

    init(
        machine: S2StateMachine,
        calibration: S2CalibrationModel,
        assetAspectRatio: @escaping (String) -> CGFloat,
        photoContent: @escaping PhotoContent,
        stripItemContent: @escaping StripItemContent,
        albumPickerContent: @escaping AlbumPickerContent,
        onBack: @escaping (S2ExitPayload) -> Void = { _ in },
        onConfirmation: @escaping (S2ExitPayload) -> Void = { _ in },
        onFavoriteRequest: @escaping (S2AssetActionRequest) -> Void = { _ in },
        onRecentAlbumRequest: @escaping (S2AlbumActionRequest) -> Void = { _ in }
    ) {
        self.machine = machine
        self.calibration = calibration
        self.assetAspectRatio = assetAspectRatio
        self.photoContent = photoContent
        self.stripItemContent = stripItemContent
        self.albumPickerContent = albumPickerContent
        self.onBack = onBack
        self.onConfirmation = onConfirmation
        self.onFavoriteRequest = onFavoriteRequest
        self.onRecentAlbumRequest = onRecentAlbumRequest
    }

    var body: some View {
        GeometryReader { geometry in
            let ratio = assetAspectRatio(machine.currentAssetID)
            let viewportMetrics = S2ViewportLayout.metrics(
                physicalSize: geometry.size,
                presentationState: viewportPresentationState,
                assetAspectRatio: ratio,
                configuration: calibration.configuration
            )

            ZStack {
                Color.black
                    .ignoresSafeArea()

                mainPhoto(
                    viewportSize: viewportMetrics.viewportSize,
                    fittedSize: viewportMetrics.oneXDisplaySize,
                    assetAspectRatio: ratio
                )

                if machine.interfaceVisibility == .visible {
                    interfaceOverlay(
                        bottomStripHeight: viewportMetrics.bottomStripHeight
                    )
                }

                calibrationOverlay(
                    metrics: viewportMetrics,
                    assetAspectRatio: ratio
                )
            }
            .allowsHitTesting(machine.sheetState == .closed)
            .onAppear {
                machine.clampViewport(
                    viewportSize: viewportMetrics.viewportSize,
                    fittedSize: viewportMetrics.oneXDisplaySize
                )
                _ = machine.applyCalibration(calibration.configuration)
            }
            .onChange(of: geometry.size) { _, newSize in
                let nextMetrics = S2ViewportLayout.metrics(
                    physicalSize: newSize,
                    presentationState: viewportPresentationState,
                    assetAspectRatio: assetAspectRatio(machine.currentAssetID),
                    configuration: calibration.configuration
                )
                machine.clampViewport(
                    viewportSize: nextMetrics.viewportSize,
                    fittedSize: nextMetrics.oneXDisplaySize
                )
            }
            .onChange(of: machine.currentAssetID) { _, newAssetID in
                let nextMetrics = S2ViewportLayout.metrics(
                    physicalSize: geometry.size,
                    presentationState: viewportPresentationState,
                    assetAspectRatio: assetAspectRatio(newAssetID),
                    configuration: calibration.configuration
                )
                machine.clampViewport(
                    viewportSize: nextMetrics.viewportSize,
                    fittedSize: nextMetrics.oneXDisplaySize
                )
            }
            .onChange(of: calibration.configuration) { _, configuration in
                guard machine.applyCalibration(configuration) else {
                    return
                }
                let nextMetrics = S2ViewportLayout.metrics(
                    physicalSize: geometry.size,
                    presentationState: viewportPresentationState,
                    assetAspectRatio: assetAspectRatio(machine.currentAssetID),
                    configuration: configuration
                )
                machine.clampViewport(
                    viewportSize: nextMetrics.viewportSize,
                    fittedSize: nextMetrics.oneXDisplaySize
                )
            }
            .onDisappear {
                pendingSingleTap?.cancel()
                pendingSingleTap = nil
                firstTapDate = nil
                firstTapLocation = nil
            }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: albumSheetBinding) {
            albumSheet
        }
    }

    private var viewportPresentationState: S2ViewportPresentationState {
        S2ViewportPresentationState(
            interfaceVisibility: machine.interfaceVisibility,
            bottomStripState: machine.bottomStripState,
            sheetState: machine.sheetState
        )
    }

    private func mainPhoto(
        viewportSize: CGSize,
        fittedSize: CGSize,
        assetAspectRatio: CGFloat
    ) -> some View {
        photoContent(
            S2ImageContentContext(
                assetID: machine.currentAssetID,
                fittedSize: fittedSize,
                scale: machine.scale,
                requestStrategy: machine.imageRequestStrategy,
                requestRevision: machine.imageRequestRevision,
                onRequestReading: machine.recordImageRequestReading
            )
        )
        .frame(width: fittedSize.width, height: fittedSize.height)
        .scaleEffect(machine.scale)
        .offset(machine.viewportOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .clipped()
        .modifier(S2MainGestureModifier(
            pinchBeforeSingleDrag:
                calibration.configuration.gestureExclusivityPolicy ==
                    .pinchBeforeSingleDrag,
            pinchGesture: pinchGesture(
                viewportSize: viewportSize,
                fittedSize: fittedSize
            ),
            singleDragGesture: mainDragGesture(
                viewportSize: viewportSize,
                fittedSize: fittedSize,
                assetAspectRatio: assetAspectRatio
            )
        ))
    }

    private func interfaceOverlay(
        bottomStripHeight: CGFloat
    ) -> some View {
        VStack {
            topBar
                .background(.regularMaterial)

            if let albumBadgeText {
                Text(albumBadgeText)
                    .accessibilityLabel(albumBadgeAccessibilityLabel)
                    .background(.regularMaterial)
            }

            Spacer()

            actionBar
                .background(.regularMaterial)

            S2BottomStripView(
                machine: machine,
                metrics: machine.parameters.bottomStripMetrics,
                itemContent: stripItemContent
            )
            .frame(height: bottomStripHeight)
            .background(.regularMaterial)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                guard let payload = machine.makeExitPayload() else {
                    return
                }
                onBack(payload)
            } label: {
                Label(
                    L10n.text("s2.action.back"),
                    systemImage: "chevron.left"
                )
            }

            Spacer()

            VStack {
                Text(L10n.text(
                    "s2.range.summary",
                    replacing: [
                        "range": machine.entry.rangeDisplayInformation.displayName,
                        "current": String(machine.currentIndex + 1),
                        "total": String(machine.orderedAssetIDs.count)
                    ]
                ))
                Text(currentStatusText)
            }

            Spacer()

            Button {
                guard let payload = machine.makeExitPayload() else {
                    return
                }
                onConfirmation(payload)
            } label: {
                Image(systemName: "trash")
                    .overlay(alignment: .topTrailing) {
                        Text(String(machine.sessionMergedPendingDeletionCount))
                            .monospacedDigit()
                    }
            }
            .accessibilityLabel(L10n.text(
                "s2.confirm.accessibility",
                replacing: [
                    "count": String(machine.sessionMergedPendingDeletionCount)
                ]
            ))
        }
        .disabled(machine.touchSequenceOwner != .none)
    }

    private var actionBar: some View {
        HStack {
            Button {
                guard let request = machine.makeFavoriteToggleRequest() else {
                    return
                }
                onFavoriteRequest(request)
            } label: {
                Label(
                    favoriteActionTitle,
                    systemImage: machine.currentIsFavorite
                        ? "heart.fill"
                        : "heart"
                )
            }

            if let album = machine.recentAlbum {
                Button {
                    guard let request = machine.makeRecentAlbumAdditionRequest() else {
                        return
                    }
                    onRecentAlbumRequest(request)
                } label: {
                    Label(
                        L10n.text(
                            "s2.action.add_recent_album",
                            replacing: ["album": album.name]
                        ),
                        systemImage: "clock"
                    )
                }
            }

            Button {
                _ = machine.presentAlbumPicker()
            } label: {
                Label(
                    L10n.text("s2.action.add_album"),
                    systemImage: "rectangle.stack.badge.plus"
                )
            }
        }
        .disabled(machine.touchSequenceOwner != .none)
    }

    private var albumBadgeText: String? {
        let albums = machine.currentAddedAlbums
        guard let latest = albums.last else {
            return nil
        }
        if albums.count == 1 {
            return L10n.text(
                "s2.album.badge.single",
                replacing: ["album": latest.name]
            )
        }
        return L10n.text(
            "s2.album.badge.multiple",
            replacing: [
                "album": latest.name,
                "count": String(albums.count - 1)
            ]
        )
    }

    private var currentStatusText: String {
        machine.currentIsMarked
            ? L10n.text("s2.status.marked")
            : L10n.text("s2.status.unmarked")
    }

    private var favoriteActionTitle: String {
        machine.currentIsFavorite
            ? L10n.text("s2.action.unfavorite")
            : L10n.text("s2.action.favorite")
    }

    private var albumBadgeAccessibilityLabel: String {
        L10n.text(
            "s2.album.badge.accessibility",
            replacing: ["value": albumBadgeText ?? String()]
        )
    }

    private var albumSheetBinding: Binding<Bool> {
        Binding(
            get: { machine.sheetState == .presented },
            set: { isPresented in
                if !isPresented {
                    _ = machine.cancelAlbumPicker()
                }
            }
        )
    }

    @ViewBuilder
    private var albumSheet: some View {
        if let request = machine.albumPickerRequest {
            albumPickerContent(
                request,
                S2AlbumPickerActions(
                    select: { album in
                        _ = machine.completeAlbumPickerSelection(
                            request,
                            album: album
                        )
                    },
                    reportFailure: {
                        _ = machine.reportAlbumPickerFailure(request)
                    },
                    cancel: {
                        _ = machine.cancelAlbumPicker()
                    }
                )
            )
        } else {
            EmptyView()
        }
    }

    private func calibrationOverlay(
        metrics: S2ViewportMetrics,
        assetAspectRatio: CGFloat
    ) -> some View {
        VStack(alignment: .trailing) {
            HStack {
                Button(parameterPanelToggleTitle) {
                    parameterPanelVisible.toggle()
                }
                Button(readingsToggleTitle) {
                    readingsVisible.toggle()
                }
            }
            .background(.regularMaterial)

            if parameterPanelVisible {
                calibrationPanel(
                    viewportSize: metrics.viewportSize
                )
                .frame(
                    maxWidth: 520,
                    maxHeight: metrics.viewportSize.height * 0.7
                )
                .background(.regularMaterial)
            }

            if readingsVisible {
                readingsPanel(
                    metrics: metrics,
                    assetAspectRatio: assetAspectRatio
                )
                .background(.regularMaterial)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topTrailing
        )
    }

    private func calibrationPanel(
        viewportSize: CGSize
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(L10n.text("s2.calibration.value_status"))

                S2CalibrationSliderRow(
                    title: "pinchMaxScale",
                    value: calibrationBinding(\.pinchMaxScale),
                    range: 1.01...10,
                    step: 0.01
                )
                S2CalibrationSliderRow(
                    title: "zoomSnapBackThreshold",
                    value: calibrationBinding(\.zoomSnapBackThreshold),
                    range: 1...calibration.configuration.pinchMaxScale,
                    step: 0.01
                )
                S2CalibrationSliderRow(
                    title: "aspectFillDegenerateTolerancePercent",
                    value: calibrationBinding(
                        \.aspectFillDegenerateTolerancePercent
                    ),
                    range: 0...10,
                    step: 0.1
                )
                S2CalibrationSliderRow(
                    title: "aspectFillDegenerateTargetScale",
                    value: calibrationBinding(\.aspectFillDegenerateTargetScale),
                    range: 1.01...calibration.configuration.pinchMaxScale,
                    step: 0.01
                )
                Picker(
                    "doubleTapAnchorStrategy",
                    selection: calibrationBinding(\.doubleTapAnchorStrategy)
                ) {
                    ForEach(S2DoubleTapAnchorStrategy.allCases, id: \.self) {
                        Text(doubleTapAnchorTitle($0)).tag($0)
                    }
                }
                S2CalibrationSliderRow(
                    title: "edgePagingTriggerDistance",
                    value: calibrationBinding(\.edgePagingTriggerDistance),
                    range: 0...300,
                    step: 1
                )
                S2CalibrationSliderRow(
                    title: "edgePagingTriggerVelocity",
                    value: calibrationBinding(\.edgePagingTriggerVelocity),
                    range: 0...3_000,
                    step: 25
                )
                S2CalibrationSliderRow(
                    title: "verticalSwipeDistance",
                    value: calibrationBinding(\.verticalSwipeDistance),
                    range: 0...300,
                    step: 1
                )
                S2CalibrationSliderRow(
                    title: "verticalSwipeVelocity",
                    value: calibrationBinding(\.verticalSwipeVelocity),
                    range: 0...3_000,
                    step: 25
                )
                S2CalibrationSliderRow(
                    title: "verticalSwipeMaximumDurationMilliseconds",
                    value: calibrationBinding(
                        \.verticalSwipeMaximumDurationMilliseconds
                    ),
                    range: 0...2_000,
                    step: 10
                )
                S2CalibrationSliderRow(
                    title: "horizontalSwipeDistance",
                    value: calibrationBinding(\.horizontalSwipeDistance),
                    range: 0...300,
                    step: 1
                )
                S2CalibrationSliderRow(
                    title: "horizontalSwipeVelocity",
                    value: calibrationBinding(\.horizontalSwipeVelocity),
                    range: 0...3_000,
                    step: 25
                )
                S2CalibrationSliderRow(
                    title: "horizontalSwipeMaximumDurationMilliseconds",
                    value: calibrationBinding(
                        \.horizontalSwipeMaximumDurationMilliseconds
                    ),
                    range: 0...2_000,
                    step: 10
                )
                S2CalibrationSliderRow(
                    title: "pinchMinimumScaleDelta",
                    value: calibrationBinding(\.pinchMinimumScaleDelta),
                    range: 0...0.5,
                    step: 0.001
                )
                S2CalibrationSliderRow(
                    title: "pinchMinimumVelocityPerSecond",
                    value: calibrationBinding(\.pinchMinimumVelocityPerSecond),
                    range: 0...10,
                    step: 0.1
                )
                S2CalibrationSliderRow(
                    title: "pinchMaximumDurationMilliseconds",
                    value: calibrationBinding(\.pinchMaximumDurationMilliseconds),
                    range: 0...5_000,
                    step: 10
                )
                S2CalibrationSliderRow(
                    title: "mainDragMinimumDistance",
                    value: calibrationBinding(\.mainDragMinimumDistance),
                    range: 0...100,
                    step: 1
                )
                S2CalibrationSliderRow(
                    title: "mainDragMinimumVelocity",
                    value: calibrationBinding(\.mainDragMinimumVelocity),
                    range: 0...3_000,
                    step: 25
                )
                S2CalibrationSliderRow(
                    title: "mainDragMaximumDurationMilliseconds",
                    value: calibrationBinding(
                        \.mainDragMaximumDurationMilliseconds
                    ),
                    range: 0...5_000,
                    step: 10
                )
                S2CalibrationSliderRow(
                    title: "singleTapMaximumMovement",
                    value: calibrationBinding(\.singleTapMaximumMovement),
                    range: 0...100,
                    step: 1
                )
                S2CalibrationSliderRow(
                    title: "singleTapMaximumDurationMilliseconds",
                    value: calibrationBinding(
                        \.singleTapMaximumDurationMilliseconds
                    ),
                    range: 0...1_000,
                    step: 10
                )
                S2CalibrationSliderRow(
                    title: "singleTapDecisionWindowMilliseconds",
                    value: calibrationBinding(
                        \.singleTapDecisionWindowMilliseconds
                    ),
                    range: 0...1_000,
                    step: 10
                )
                S2CalibrationSliderRow(
                    title: "doubleTapDecisionWindowMilliseconds",
                    value: calibrationBinding(
                        \.doubleTapDecisionWindowMilliseconds
                    ),
                    range: 0...1_000,
                    step: 10
                )
                calibrationTouchCountSteppers
                Picker(
                    "gestureExclusivityPolicy",
                    selection: calibrationBinding(\.gestureExclusivityPolicy)
                ) {
                    ForEach(S2GestureExclusivityPolicy.allCases, id: \.self) {
                        Text(gestureExclusivityTitle($0)).tag($0)
                    }
                }
                Picker(
                    "scaleChangeRequestPolicy",
                    selection: calibrationBinding(\.scaleChangeRequestPolicy)
                ) {
                    ForEach(
                        S2ScaleChangeImageRequestPolicy.allCases,
                        id: \.self
                    ) {
                        Text(scaleChangeRequestTitle($0)).tag($0)
                    }
                }
                Picker(
                    "degradedPreviewPolicy",
                    selection: calibrationBinding(\.degradedPreviewPolicy)
                ) {
                    ForEach(S2DegradedPreviewPolicy.allCases, id: \.self) {
                        Text(degradedPreviewTitle($0)).tag($0)
                    }
                }
                Toggle(
                    L10n.text("s2.calibration.animation.enabled"),
                    isOn: calibrationBinding(\.animationsEnabled)
                )
                Picker(
                    "animationDurationMilliseconds",
                    selection: calibrationBinding(
                        \.animationDurationMilliseconds
                    )
                ) {
                    Text(verbatim: "0 ms").tag(Double(0))
                    Text(verbatim: "200 ms").tag(Double(200))
                }
                S2CalibrationSliderRow(
                    title: "fitInsetRatio",
                    value: calibrationBinding(\.fitInsetRatio),
                    range: 0...0.45,
                    step: 0.005
                )
                Picker(
                    "fitInsetScope",
                    selection: calibrationBinding(\.fitInsetScope)
                ) {
                    ForEach(S2FitInsetScope.allCases, id: \.self) {
                        Text(fitInsetScopeTitle($0)).tag($0)
                    }
                }

                Text(L10n.text("s2.calibration.navigation.title"))
                ForEach(S2AssetAspectCategory.allCases, id: \.self) { category in
                    Button(categoryTitle(category)) {
                        guard viewportSize.height > 0 else {
                            return
                        }
                        performCalibratedAnimation {
                            _ = machine.navigateToNextAsset(
                                category: category,
                                viewportAspectRatio:
                                    viewportSize.width / viewportSize.height,
                                assetAspectRatio: assetAspectRatio
                            )
                        }
                    }
                }
                if machine.assetNavigationResult == .empty {
                    Text(L10n.text("s2.calibration.navigation.empty"))
                }

                ShareLink(item: calibration.exportText()) {
                    Text(L10n.text("s2.calibration.export"))
                }
                Button(L10n.text("s2.calibration.restore_factory")) {
                    calibration.restoreFactoryPlaceholder()
                }
                if calibration.persistenceFailed {
                    Text(L10n.text("s2.calibration.persistence_failed"))
                }
            }
        }
    }

    private var calibrationTouchCountSteppers: some View {
        Group {
            Stepper(
                value: calibrationBinding(\.singleTapTouchCount),
                in: 1...5
            ) {
                Text(verbatim: "singleTapTouchCount=\(calibration.configuration.singleTapTouchCount)")
            }
            Stepper(
                value: calibrationBinding(\.doubleTapTouchCount),
                in: 1...5
            ) {
                Text(verbatim: "doubleTapTouchCount=\(calibration.configuration.doubleTapTouchCount)")
            }
            Stepper(
                value: calibrationBinding(\.singleDragTouchCount),
                in: 1...5
            ) {
                Text(verbatim: "singleDragTouchCount=\(calibration.configuration.singleDragTouchCount)")
            }
            Stepper(
                value: calibrationBinding(\.pinchTouchCount),
                in: 1...5
            ) {
                Text(verbatim: "pinchTouchCount=\(calibration.configuration.pinchTouchCount)")
            }
        }
    }

    private func readingsPanel(
        metrics: S2ViewportMetrics,
        assetAspectRatio: CGFloat
    ) -> some View {
        VStack(alignment: .leading) {
            Text(L10n.text(
                "s2.calibration.reading.scale",
                replacing: ["value": decimal(machine.scale)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.asset_ratio",
                replacing: ["value": decimal(assetAspectRatio)]
            ))
            let viewportRatio = metrics.viewportSize.height > 0
                ? metrics.viewportSize.width / metrics.viewportSize.height
                : 0
            Text(L10n.text(
                "s2.calibration.reading.viewport_ratio",
                replacing: ["value": decimal(viewportRatio)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.aspect_fill",
                replacing: ["value": decimal(metrics.aspectFillMultiplier)]
            ))
            Text(L10n.text(
                "s2.calibration.reading.display_size",
                replacing: [
                    "width": decimal(metrics.oneXDisplaySize.width),
                    "height": decimal(metrics.oneXDisplaySize.height)
                ]
            ))
            if let reading = machine.lastGestureReading {
                Text(L10n.text(
                    "s2.calibration.reading.gesture",
                    replacing: [
                        "distance": decimal(reading.displacementDistance),
                        "velocity": decimal(reading.peakVelocity),
                        "duration": decimal(reading.duration * 1_000)
                    ]
                ))
            } else {
                Text(L10n.text("s2.calibration.reading.gesture_empty"))
            }
            if let reading = machine.lastImageRequestReading {
                Text(L10n.text(
                    "s2.calibration.reading.image_request",
                    replacing: [
                        "trigger": imageRequestTriggerTitle(reading.trigger),
                        "return": imageReturnTypeTitle(reading.returnType)
                    ]
                ))
            } else {
                Text(L10n.text("s2.calibration.reading.image_request_empty"))
            }
        }
    }

    private func calibrationBinding<Value>(
        _ keyPath: WritableKeyPath<S2CalibrationConfiguration, Value>
    ) -> Binding<Value> {
        Binding(
            get: { calibration.configuration[keyPath: keyPath] },
            set: { value in
                _ = calibration.update { configuration in
                    configuration[keyPath: keyPath] = value
                }
            }
        )
    }

    private func categoryTitle(_ category: S2AssetAspectCategory) -> String {
        switch category {
        case .screenAspect:
            return L10n.text("s2.calibration.navigation.screen_aspect")
        case .portrait:
            return L10n.text("s2.calibration.navigation.portrait")
        case .landscape:
            return L10n.text("s2.calibration.navigation.landscape")
        case .square:
            return L10n.text("s2.calibration.navigation.square")
        case .extreme:
            return L10n.text("s2.calibration.navigation.extreme")
        }
    }

    private func doubleTapAnchorTitle(
        _ strategy: S2DoubleTapAnchorStrategy
    ) -> String {
        switch strategy {
        case .screenCenter:
            return L10n.text("s2.calibration.option.anchor.screen_center")
        case .touchPoint:
            return L10n.text("s2.calibration.option.anchor.touch_point")
        case .previousTouchPoint:
            return L10n.text("s2.calibration.option.anchor.previous_touch_point")
        case .touchPointToCenter:
            return L10n.text("s2.calibration.option.anchor.touch_point_to_center")
        }
    }

    private func gestureExclusivityTitle(
        _ policy: S2GestureExclusivityPolicy
    ) -> String {
        switch policy {
        case .pinchBeforeSingleDrag:
            return L10n.text("s2.calibration.option.gesture.pinch_first")
        case .singleDragBeforePinch:
            return L10n.text("s2.calibration.option.gesture.drag_first")
        }
    }

    private func scaleChangeRequestTitle(
        _ policy: S2ScaleChangeImageRequestPolicy
    ) -> String {
        switch policy {
        case .everyScaleChange:
            return L10n.text("s2.calibration.option.request.every_scale_change")
        case .pinchEnded:
            return L10n.text("s2.calibration.option.request.pinch_ended")
        }
    }

    private func degradedPreviewTitle(
        _ policy: S2DegradedPreviewPolicy
    ) -> String {
        switch policy {
        case .display:
            return L10n.text("s2.calibration.option.preview.display")
        case .finalImageOnly:
            return L10n.text("s2.calibration.option.preview.final_only")
        }
    }

    private func fitInsetScopeTitle(_ scope: S2FitInsetScope) -> String {
        switch scope {
        case .screenAspectOnly:
            return L10n.text("s2.calibration.option.fit_scope.screen_aspect")
        case .allPhotos:
            return L10n.text("s2.calibration.option.fit_scope.all_photos")
        }
    }

    private func imageRequestTriggerTitle(
        _ trigger: S2ImageRequestTrigger
    ) -> String {
        switch trigger {
        case .initial:
            return L10n.text("s2.calibration.reading.trigger.initial")
        case .assetChange:
            return L10n.text("s2.calibration.reading.trigger.asset_change")
        case .viewportChange:
            return L10n.text("s2.calibration.reading.trigger.viewport_change")
        case .scaleChange:
            return L10n.text("s2.calibration.reading.trigger.scale_change")
        case .pinchEnded:
            return L10n.text("s2.calibration.reading.trigger.pinch_ended")
        case .strategyChange:
            return L10n.text("s2.calibration.reading.trigger.strategy_change")
        }
    }

    private func imageReturnTypeTitle(
        _ returnType: S2ImageReturnType
    ) -> String {
        switch returnType {
        case .pending:
            return L10n.text("s2.calibration.reading.return.pending")
        case .degradedPreview:
            return L10n.text("s2.calibration.reading.return.degraded_preview")
        case .finalImage:
            return L10n.text("s2.calibration.reading.return.final_image")
        case .failure:
            return L10n.text("s2.calibration.reading.return.failure")
        }
    }

    private var parameterPanelToggleTitle: String {
        parameterPanelVisible
            ? L10n.text("s2.calibration.panel.hide")
            : L10n.text("s2.calibration.panel.show")
    }

    private var readingsToggleTitle: String {
        readingsVisible
            ? L10n.text("s2.calibration.readings.hide")
            : L10n.text("s2.calibration.readings.show")
    }

    private func decimal<T: BinaryFloatingPoint>(_ value: T) -> String {
        String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(value)
        )
    }

    private func pinchGesture(
        viewportSize: CGSize,
        fittedSize: CGSize
    ) -> some Gesture {
        MagnifyGesture(
            minimumScaleDelta: machine.parameters.pinchMinimumScaleDelta
        )
            .onChanged { value in
                if !pinchIsActive {
                    guard calibration.configuration.pinchTouchCount == 2 else {
                        return
                    }
                    pinchIsActive = machine.beginPinch()
                    let now = Date()
                    pinchStartTime = now
                    pinchPreviousTime = now
                    pinchPreviousMagnification = value.magnification
                    pinchPeakVelocity = 0
                }
                guard pinchIsActive else {
                    return
                }
                let now = Date()
                if let previousTime = pinchPreviousTime {
                    let elapsed = now.timeIntervalSince(previousTime)
                    if elapsed > 0 {
                        let velocity = abs(
                            value.magnification - pinchPreviousMagnification
                        ) / CGFloat(elapsed)
                        pinchPeakVelocity = max(pinchPeakVelocity, velocity)
                    }
                }
                pinchPreviousTime = now
                pinchPreviousMagnification = value.magnification
                _ = machine.updatePinch(
                    magnification: value.magnification,
                    viewportSize: viewportSize,
                    fittedSize: fittedSize
                )
            }
            .onEnded { value in
                guard pinchIsActive else {
                    return
                }
                let duration = Date().timeIntervalSince(
                    pinchStartTime ?? Date()
                )
                machine.recordGestureReading(S2GestureReading(
                    displacementDistance: abs(value.magnification - 1),
                    peakVelocity: pinchPeakVelocity,
                    duration: duration
                ))
                let configuration = calibration.configuration
                let accepted =
                    pinchPeakVelocity >=
                        CGFloat(configuration.pinchMinimumVelocityPerSecond) &&
                    durationIsAllowed(
                        duration,
                        maximumMilliseconds:
                            configuration.pinchMaximumDurationMilliseconds
                    )
                performCalibratedAnimation {
                    if accepted {
                        _ = machine.endPinch(
                            viewportSize: viewportSize,
                            fittedSize: fittedSize
                        )
                    } else {
                        _ = machine.cancelPinch(
                            viewportSize: viewportSize,
                            fittedSize: fittedSize
                        )
                    }
                }
                pinchIsActive = false
                pinchStartTime = nil
                pinchPreviousTime = nil
                pinchPreviousMagnification = 1
                pinchPeakVelocity = 0
            }
    }

    private func mainDragGesture(
        viewportSize: CGSize,
        fittedSize: CGSize,
        assetAspectRatio: CGFloat
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 0,
            coordinateSpace: .local
        )
        .onChanged { value in
            if mainDragStartTime == nil {
                mainDragStartTime = value.time
                mainDragStartOffset = machine.viewportOffset
                mainDragPreviousTime = value.time
                mainDragPreviousTranslation = value.translation
                mainDragPeakVelocity = 0
            } else if let previousTime = mainDragPreviousTime {
                let elapsed = value.time.timeIntervalSince(previousTime)
                if elapsed > 0 {
                    let delta = CGSize(
                        width: value.translation.width -
                            mainDragPreviousTranslation.width,
                        height: value.translation.height -
                            mainDragPreviousTranslation.height
                    )
                    mainDragPeakVelocity = max(
                        mainDragPeakVelocity,
                        hypot(delta.width, delta.height) / CGFloat(elapsed)
                    )
                }
                mainDragPreviousTime = value.time
                mainDragPreviousTranslation = value.translation
            }
            guard calibration.configuration.singleDragTouchCount == 1,
                  hypot(value.translation.width, value.translation.height) >=
                    machine.parameters.mainDragMinimumDistance else {
                return
            }
            _ = machine.updateMainPan(
                from: mainDragStartOffset,
                translation: value.translation,
                viewportSize: viewportSize,
                fittedSize: fittedSize
            )
        }
        .onEnded { value in
            let startedAt = mainDragStartTime ?? value.time
            let duration = value.time.timeIntervalSince(startedAt)
            let distance = hypot(
                value.translation.width,
                value.translation.height
            )
            let averageVelocity = duration > 0
                ? distance / CGFloat(duration)
                : 0
            let peakVelocity = max(mainDragPeakVelocity, averageVelocity)
            machine.recordGestureReading(S2GestureReading(
                displacementDistance: distance,
                peakVelocity: peakVelocity,
                duration: duration
            ))

            let configuration = calibration.configuration
            let direction = S2StateMachine.dragDirection(
                for: value.translation
            )
            let directionalMaximumDuration = direction == .vertical
                ? configuration.verticalSwipeMaximumDurationMilliseconds
                : configuration.horizontalSwipeMaximumDurationMilliseconds
            if configuration.singleTapTouchCount == 1,
               distance <= CGFloat(configuration.singleTapMaximumMovement),
               duration * 1_000 <=
                configuration.singleTapMaximumDurationMilliseconds {
                registerTap(
                    at: value.location,
                    viewportSize: viewportSize,
                    oneXDisplaySize: fittedSize,
                    assetAspectRatio: assetAspectRatio
                )
            } else if configuration.singleDragTouchCount == 1,
                      distance >= machine.parameters.mainDragMinimumDistance,
                      peakVelocity >=
                        CGFloat(configuration.mainDragMinimumVelocity),
                      durationIsAllowed(
                          duration,
                          maximumMilliseconds:
                            configuration.mainDragMaximumDurationMilliseconds
                      ),
                      durationIsAllowed(
                          duration,
                          maximumMilliseconds: directionalMaximumDuration
                      ) {
                performCalibratedAnimation {
                    _ = machine.completeMainDrag(
                        translation: value.translation,
                        duration: duration,
                        startedOffset: mainDragStartOffset,
                        viewportSize: viewportSize,
                        fittedSize: fittedSize
                    )
                }
            }
            mainDragStartTime = nil
            mainDragStartOffset = machine.viewportOffset
            mainDragPreviousTime = nil
            mainDragPreviousTranslation = .zero
            mainDragPeakVelocity = 0
        }
    }

    private func registerTap(
        at location: CGPoint,
        viewportSize: CGSize,
        oneXDisplaySize: CGSize,
        assetAspectRatio: CGFloat
    ) {
        let now = Date()
        let configuration = calibration.configuration
        if let firstTapDate,
           let firstTapLocation,
           configuration.doubleTapTouchCount == 1 {
            let interval = now.timeIntervalSince(firstTapDate) * 1_000
            let movement = hypot(
                location.x - firstTapLocation.x,
                location.y - firstTapLocation.y
            )
            if interval <= configuration.doubleTapDecisionWindowMilliseconds,
               movement <= CGFloat(configuration.singleTapMaximumMovement) {
                pendingSingleTap?.cancel()
                pendingSingleTap = nil
                self.firstTapDate = nil
                self.firstTapLocation = nil
                performCalibratedAnimation {
                    _ = machine.handleDoubleTap(
                        at: location,
                        viewportSize: viewportSize,
                        assetAspectRatio: assetAspectRatio,
                        oneXDisplaySize: oneXDisplaySize
                    )
                }
                return
            }
            pendingSingleTap?.cancel()
            performCalibratedAnimation {
                _ = machine.handleSingleTap()
            }
        }

        firstTapDate = now
        firstTapLocation = location
        let work = DispatchWorkItem {
            guard self.firstTapDate == now else {
                return
            }
            self.firstTapDate = nil
            self.firstTapLocation = nil
            self.pendingSingleTap = nil
            self.performCalibratedAnimation {
                _ = machine.handleSingleTap()
            }
        }
        pendingSingleTap = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() +
                configuration.singleTapDecisionWindowMilliseconds / 1_000,
            execute: work
        )
    }

    private func durationIsAllowed(
        _ duration: TimeInterval,
        maximumMilliseconds: Double
    ) -> Bool {
        maximumMilliseconds == 0 || duration * 1_000 <= maximumMilliseconds
    }

    private func performCalibratedAnimation(_ action: () -> Void) {
        let configuration = calibration.configuration
        if configuration.animationsEnabled,
           configuration.animationDurationMilliseconds > 0 {
            withAnimation(.linear(
                duration: configuration.animationDurationMilliseconds / 1_000
            )) {
                action()
            }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                action()
            }
        }
    }
}

private struct S2MainGestureModifier<
    PinchGestureType: Gesture,
    SingleDragGestureType: Gesture
>: ViewModifier {
    let pinchBeforeSingleDrag: Bool
    let pinchGesture: PinchGestureType
    let singleDragGesture: SingleDragGestureType

    @ViewBuilder
    func body(content: Content) -> some View {
        if pinchBeforeSingleDrag {
            content.gesture(
                pinchGesture.exclusively(before: singleDragGesture)
            )
        } else {
            content.gesture(
                singleDragGesture.exclusively(before: pinchGesture)
            )
        }
    }
}

private struct S2CalibrationSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text(verbatim: "\(title)=\(formattedValue)")
            Slider(value: $value, in: range, step: step)
        }
    }

    private var formattedValue: String {
        String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}

struct S2BottomStripView: View {
    @ObservedObject var machine: S2StateMachine

    let metrics: S2BottomStripMetrics
    let itemContent: S2View.StripItemContent

    @State private var residualTranslation: CGFloat = 0
    @State private var previousTranslation: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(
                    Array(machine.orderedAssetIDs.enumerated()),
                    id: \.element
                ) { index, assetID in
                    itemContent(
                        S2BottomStripItemPresentation(
                            assetID: assetID,
                            index: index,
                            isCurrent: machine.bottomStripState == .idle &&
                                index == machine.currentIndex,
                            isMarked: machine.pendingDeletionAssetIDs.contains(assetID),
                            stripState: machine.bottomStripState
                        )
                    )
                    .frame(
                        width: itemWidth(at: index),
                        height: itemHeight(at: index)
                    )
                    .position(
                        x: geometry.size.width / 2 +
                            positionOffset(for: index) +
                            residualTranslation,
                        y: geometry.size.height / 2
                    )
                    .accessibilityLabel(L10n.text(
                        "s2.strip.item.accessibility",
                        replacing: [
                            "current": String(index + 1),
                            "total": String(machine.orderedAssetIDs.count)
                        ]
                    ))
                    .accessibilityValue(markAccessibilityValue(for: assetID))
                }

            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(stripGesture)
        }
    }

    private func itemWidth(at index: Int) -> CGFloat {
        if machine.bottomStripState == .dragging {
            return metrics.neighborItemWidth
        }
        return index == machine.currentIndex
            ? metrics.currentItemSize
            : metrics.neighborItemWidth
    }

    private func markAccessibilityValue(for assetID: String) -> String {
        machine.pendingDeletionAssetIDs.contains(assetID)
            ? L10n.text("s2.strip.item.marked")
            : L10n.text("s2.strip.item.unmarked")
    }

    private func itemHeight(at index: Int) -> CGFloat {
        if machine.bottomStripState == .dragging {
            return metrics.neighborItemHeight
        }
        return index == machine.currentIndex
            ? metrics.currentItemSize
            : metrics.neighborItemHeight
    }

    private func positionOffset(for index: Int) -> CGFloat {
        let delta = index - machine.currentIndex
        guard delta != 0 else {
            return 0
        }

        if machine.bottomStripState == .dragging {
            return CGFloat(delta) *
                (metrics.neighborItemWidth + metrics.itemSpacing)
        }

        let firstStep = metrics.currentItemSize / 2 +
            metrics.itemSpacing +
            metrics.neighborItemWidth / 2
        let remainingSteps = CGFloat(max(0, abs(delta) - 1)) *
            (metrics.neighborItemWidth + metrics.itemSpacing)
        let distance = firstStep + remainingSteps
        return delta > 0 ? distance : -distance
    }

    private var stripGesture: some Gesture {
        DragGesture(minimumDistance: metrics.dragMinimumDistance)
            .onChanged { value in
                if previousTranslation == nil {
                    guard machine.beginBottomStripDrag() else {
                        return
                    }
                    previousTranslation = value.translation.width
                    return
                }

                let previous = previousTranslation ?? value.translation.width
                residualTranslation += value.translation.width - previous
                previousTranslation = value.translation.width
                applyStripSwitches()
            }
            .onEnded { _ in
                guard previousTranslation != nil else {
                    return
                }
                residualTranslation = 0
                previousTranslation = nil
                _ = machine.endBottomStripDrag()
            }
    }

    private func applyStripSwitches() {
        while residualTranslation <= -metrics.switchDistance {
            if machine.changeCurrentPhotoDuringBottomStripDrag(by: 1) {
                residualTranslation += metrics.switchDistance
            } else {
                residualTranslation = -metrics.switchDistance
                break
            }
        }

        while residualTranslation >= metrics.switchDistance {
            if machine.changeCurrentPhotoDuringBottomStripDrag(by: -1) {
                residualTranslation -= metrics.switchDistance
            } else {
                residualTranslation = metrics.switchDistance
                break
            }
        }
    }
}

enum S2PreviewData {
    static let parameters =
        S2CalibrationConfiguration.factoryPlaceholder.resolvedParameters!
    static let calibration = S2CalibrationModel(
        persistence: S2DiscardingCalibrationPersistence()
    )

    static func machine(for state: S2State) -> S2StateMachine {
        let visibility: S2InterfaceVisibility
        switch state {
        case .hiddenOneX, .hiddenNx:
            visibility = .hidden
        default:
            visibility = .visible
        }
        let scale: CGFloat
        switch state {
        case .visibleNxIdle, .visibleNxStripDragging, .hiddenNx:
            scale = 2
        default:
            scale = 1
        }
        let entry = S2EntryContext(
            sessionID: "preview-session",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "preview-range",
                displayName: L10n.text("s2.preview.range"),
                totalAssetCount: 3
            ),
            orderedAssetIDs: [
                "preview-asset-1",
                "preview-asset-2",
                "preview-asset-3"
            ],
            currentAssetID: "preview-asset-2",
            pendingDeletionAssetIDs: ["preview-asset-2"],
            sessionMergedPendingDeletionCountProvider: { 1 }
        )
        let machine = S2StateMachine(
            entry: entry,
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: visibility,
                scale: scale,
                viewportOffset: .zero
            ),
            parameters: parameters,
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: S2AlbumReference(
                id: "preview-album",
                name: L10n.text("s2.preview.album")
            ),
            pendingDeletionDidChange: { _ in }
        )!
        if state == .visibleOneXStripDragging ||
            state == .visibleNxStripDragging {
            _ = machine.beginBottomStripDrag()
        }
        return machine
    }

    static func view(for state: S2State) -> S2View {
        S2View(
            machine: machine(for: state),
            calibration: calibration,
            assetAspectRatio: { assetID in
                assetID.hasSuffix("1")
                    ? CGFloat(3) / 4
                    : CGFloat(4) / 3
            },
            photoContent: { _ in
                AnyView(
                    ZStack {
                        Color.gray
                        Image(systemName: "photo")
                            .font(.largeTitle)
                    }
                )
            },
            stripItemContent: { item in
                AnyView(
                    ZStack {
                        Color.gray
                        Image(systemName: item.isMarked ? "trash.fill" : "photo")
                    }
                    .overlay {
                        Rectangle()
                            .stroke(item.isCurrent ? Color.white : Color.clear)
                    }
                )
            },
            albumPickerContent: { _, actions in
                AnyView(
                    VStack {
                        Text(L10n.text("s2.preview.album_sheet"))
                        Button(L10n.text("s2.action.cancel")) {
                            actions.cancel()
                        }
                    }
                    .padding()
                )
            }
        )
    }
}

#Preview("S2-1") {
    S2PreviewData.view(for: .visibleOneXIdle)
}

#Preview("S2-2") {
    S2PreviewData.view(for: .visibleOneXStripDragging)
}

#Preview("S2-3") {
    S2PreviewData.view(for: .hiddenOneX)
}

#Preview("S2-4") {
    S2PreviewData.view(for: .visibleNxIdle)
}

#Preview("S2-5") {
    S2PreviewData.view(for: .visibleNxStripDragging)
}

#Preview("S2-6") {
    S2PreviewData.view(for: .hiddenNx)
}
