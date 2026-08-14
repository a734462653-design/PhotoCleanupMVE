import Foundation
import SwiftUI

struct S2ImageContentContext {
    let assetID: String
    let fittedSize: CGSize
    let scale: CGFloat
    let requestStrategy: S2ImageRequestStrategy?
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

    private let assetAspectRatio: (String) -> CGFloat
    private let photoContent: PhotoContent
    private let stripItemContent: StripItemContent
    private let albumPickerContent: AlbumPickerContent
    private let onBack: (S2ExitPayload) -> Void
    private let onConfirmation: (S2ExitPayload) -> Void
    private let onFavoriteRequest: (S2AssetActionRequest) -> Void
    private let onRecentAlbumRequest: (S2AlbumActionRequest) -> Void

    @State private var pinchIsActive = false
    @State private var mainDragStartTime: Date?
    @State private var mainDragStartOffset = CGSize.zero

    init(
        machine: S2StateMachine,
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
            let fittedSize = S2Geometry.aspectFitSize(
                viewportSize: geometry.size,
                assetAspectRatio: ratio
            )

            ZStack {
                Color.black
                    .ignoresSafeArea()

                mainPhoto(
                    viewportSize: geometry.size,
                    fittedSize: fittedSize,
                    assetAspectRatio: ratio
                )

                if machine.interfaceVisibility == .visible {
                    interfaceOverlay
                }
            }
            .allowsHitTesting(machine.sheetState == .closed)
            .onAppear {
                machine.clampViewport(
                    viewportSize: geometry.size,
                    fittedSize: fittedSize
                )
            }
            .onChange(of: geometry.size) { _, newSize in
                machine.clampViewport(
                    viewportSize: newSize,
                    fittedSize: S2Geometry.aspectFitSize(
                        viewportSize: newSize,
                        assetAspectRatio: assetAspectRatio(machine.currentAssetID)
                    )
                )
            }
            .onChange(of: machine.currentAssetID) { _, newAssetID in
                machine.clampViewport(
                    viewportSize: geometry.size,
                    fittedSize: S2Geometry.aspectFitSize(
                        viewportSize: geometry.size,
                        assetAspectRatio: assetAspectRatio(newAssetID)
                    )
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: albumSheetBinding) {
            albumSheet
        }
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
                requestStrategy: machine.imageRequestStrategy
            )
        )
        .frame(width: fittedSize.width, height: fittedSize.height)
        .scaleEffect(machine.scale)
        .offset(machine.viewportOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .clipped()
        .gesture(mainGesture(
            viewportSize: viewportSize,
            fittedSize: fittedSize,
            assetAspectRatio: assetAspectRatio
        ))
    }

    private var interfaceOverlay: some View {
        VStack {
            topBar

            if let albumBadgeText {
                Text(albumBadgeText)
                    .accessibilityLabel(albumBadgeAccessibilityLabel)
            }

            Spacer()

            actionBar

            S2BottomStripView(
                machine: machine,
                metrics: machine.parameters.bottomStripMetrics,
                itemContent: stripItemContent
            )
            .frame(height: machine.parameters.bottomStripMetrics.height)
        }
        .padding()
        .foregroundStyle(.white)
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

    private func mainGesture(
        viewportSize: CGSize,
        fittedSize: CGSize,
        assetAspectRatio: CGFloat
    ) -> some Gesture {
        pinchGesture(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        )
        .exclusively(before: doubleTapGesture(
            viewportSize: viewportSize,
            assetAspectRatio: assetAspectRatio
        ).exclusively(before: singleTapGesture.exclusively(before: mainDragGesture(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))))
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
                    pinchIsActive = machine.beginPinch()
                }
                guard pinchIsActive else {
                    return
                }
                _ = machine.updatePinch(
                    magnification: value.magnification,
                    viewportSize: viewportSize,
                    fittedSize: fittedSize
                )
            }
            .onEnded { _ in
                guard pinchIsActive else {
                    return
                }
                _ = machine.endPinch(
                    viewportSize: viewportSize,
                    fittedSize: fittedSize
                )
                pinchIsActive = false
            }
    }

    private func doubleTapGesture(
        viewportSize: CGSize,
        assetAspectRatio: CGFloat
    ) -> some Gesture {
        SpatialTapGesture(count: 2, coordinateSpace: .local)
            .onEnded { value in
                _ = machine.handleDoubleTap(
                    at: value.location,
                    viewportSize: viewportSize,
                    assetAspectRatio: assetAspectRatio
                )
            }
    }

    private var singleTapGesture: some Gesture {
        SpatialTapGesture(count: 1, coordinateSpace: .local)
            .onEnded { _ in
                _ = machine.handleSingleTap()
            }
    }

    private func mainDragGesture(
        viewportSize: CGSize,
        fittedSize: CGSize
    ) -> some Gesture {
        DragGesture(
            minimumDistance: machine.parameters.mainDragMinimumDistance,
            coordinateSpace: .local
        )
        .onChanged { value in
            if mainDragStartTime == nil {
                mainDragStartTime = value.time
                mainDragStartOffset = machine.viewportOffset
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
            _ = machine.completeMainDrag(
                translation: value.translation,
                duration: value.time.timeIntervalSince(startedAt),
                startedOffset: mainDragStartOffset,
                viewportSize: viewportSize,
                fittedSize: fittedSize
            )
            mainDragStartTime = nil
            mainDragStartOffset = machine.viewportOffset
        }
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
                Color.black

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

                if machine.bottomStripState == .idle {
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [.black, .black.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: metrics.edgeFadeWidth)
                        Spacer()
                        LinearGradient(
                            colors: [.black.opacity(0), .black],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: metrics.edgeFadeWidth)
                    }
                    .allowsHitTesting(false)
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
    // 以下数值只用于静态预览夹具，不是产品默认值或标定结果。
    static let parameters = S2ResolvedParameters(
        pinchMaxScale: 4,
        zoomSnapBackThreshold: 1.1,
        aspectFillDegenerateTolerancePercent: 1,
        aspectFillDegenerateTargetScale: 2,
        doubleTapAnchorStrategy: .touchPoint,
        edgePagingTriggerDistance: 40,
        edgePagingTriggerVelocity: 300,
        verticalSwipeDistance: 40,
        verticalSwipeVelocity: 100,
        horizontalSwipeDistance: 40,
        horizontalSwipeVelocity: 100,
        pinchMinimumScaleDelta: 0.01,
        mainDragMinimumDistance: 8,
        bottomStripMetrics: S2BottomStripMetrics(
            currentItemSize: 72,
            neighborItemWidth: 52,
            neighborItemHeight: 44,
            itemSpacing: 8,
            edgeFadeWidth: 24,
            dragMinimumDistance: 4,
            switchDistance: 44
        )
    )!

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
