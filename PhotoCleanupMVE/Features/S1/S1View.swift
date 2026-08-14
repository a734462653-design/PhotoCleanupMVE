import SwiftUI

struct S1View: View {
    typealias RangeReader = (
        S1GroupingDimension
    ) -> Result<[S1Range], S1RangeReadFailure>

    @ObservedObject var machine: S1StateMachine

    private let rangeReader: RangeReader?
    private let onS2Handoff: (S1ToS2Handoff) -> Void
    private let onS3Submission: (SessionStore.S3Submission) -> Void

    init(
        machine: S1StateMachine,
        rangeReader: RangeReader? = nil,
        onS2Handoff: @escaping (S1ToS2Handoff) -> Void = { _ in },
        onS3Submission: @escaping (SessionStore.S3Submission) -> Void = { _ in }
    ) {
        self.machine = machine
        self.rangeReader = rangeReader
        self.onS2Handoff = onS2Handoff
        self.onS3Submission = onS3Submission
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(
                    L10n.text("s1.dimension.accessibility"),
                    selection: groupingSelection
                ) {
                    ForEach(S1GroupingDimension.allCases, id: \.self) { dimension in
                        Text(groupingTitle(dimension))
                            .tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Picker(
                    L10n.text("s1.sort.accessibility"),
                    selection: sortSelection
                ) {
                    ForEach(S1SortOrder.allCases, id: \.self) { sortOrder in
                        Text(sortTitle(sortOrder))
                            .tag(sortOrder)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom)

                stateContent
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    trashEntry
                }
            }
            .allowsHitTesting(!machine.isObscured)
            .onAppear {
                readCurrentRequestIfPossible()
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch machine.state {
        case .loading:
            placeholderState(
                S1UndecidedItems.localizedCopy(.loading)
            )

        case .ready:
            List(machine.rangeRows) { row in
                Button {
                    guard let handoff = machine.makeS2Handoff(for: row.id) else {
                        return
                    }
                    onS2Handoff(handoff)
                } label: {
                    rangeRow(row)
                }
                .buttonStyle(.plain)
            }

        case .empty:
            placeholderState(
                S1UndecidedItems.localizedCopy(.empty)
            )

        case .failed:
            VStack(spacing: 12) {
                Text(S1UndecidedItems.localizedCopy(.failure))
                    .multilineTextAlignment(.center)
                Button(S1UndecidedItems.localizedCopy(.retry)) {
                    guard machine.retry() else {
                        return
                    }
                    readCurrentRequestIfPossible()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private func placeholderState(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }

    private func rangeRow(_ row: S1RangeRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.displayName)
                .font(.headline)
            Text(L10n.text(
                "s1.range.total_count",
                replacing: ["count": String(row.totalAssetCount)]
            ))
            if row.pendingDeletionCount == 0 {
                Text(S1UndecidedItems.localizedCopy(.zeroPending))
            } else {
                Text(L10n.text(
                    "s1.range.pending_count",
                    replacing: ["count": String(row.pendingDeletionCount)]
                ))
            }
            Text(S1UndecidedItems.localizedCopy(
                .progress,
                replacing: [
                    "processed": String(row.processedAssetCount),
                    "total": String(row.totalAssetCount)
                ]
            ))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var trashEntry: some View {
        if machine.badgeCount == 0 {
            Image(systemName: "trash")
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption2)
                        .offset(x: 7, y: -7)
                }
                .accessibilityLabel(
                    S1UndecidedItems.localizedCopy(.emptyTrash)
                )
        } else {
            Button {
                guard let submission = machine.makeS3Submission() else {
                    return
                }
                onS3Submission(submission)
            } label: {
                Image(systemName: "trash")
                    .overlay(alignment: .topTrailing) {
                        Text(String(machine.badgeCount))
                            .font(.caption2)
                            .monospacedDigit()
                            .padding(3)
                            .background(.red, in: Circle())
                            .foregroundStyle(.white)
                            .offset(x: 8, y: -8)
                    }
            }
            .disabled(machine.state == .loading)
            .accessibilityLabel(L10n.text(
                "s1.trash.accessibility",
                replacing: ["count": String(machine.badgeCount)]
            ))
        }
    }

    private var groupingSelection: Binding<S1GroupingDimension> {
        Binding(
            get: { machine.groupingDimension },
            set: { newValue in
                guard machine.switchGroupingDimension(to: newValue) else {
                    return
                }
                readCurrentRequestIfPossible()
            }
        )
    }

    private var sortSelection: Binding<S1SortOrder> {
        Binding(
            get: { machine.sortOrder },
            set: { newValue in
                _ = machine.switchSortOrder(to: newValue)
            }
        )
    }

    private func readCurrentRequestIfPossible() {
        guard let rangeReader,
              let request = machine.currentReadRequest else {
            return
        }
        _ = machine.completeRangeRead(
            rangeReader(request.groupingDimension),
            for: request
        )
    }

    private func groupingTitle(_ dimension: S1GroupingDimension) -> String {
        switch dimension {
        case .month:
            return L10n.text("s1.dimension.month")
        case .year:
            return L10n.text("s1.dimension.year")
        case .album:
            return L10n.text("s1.dimension.album")
        case .unclassified:
            return L10n.text("s1.dimension.unclassified")
        }
    }

    private func sortTitle(_ sortOrder: S1SortOrder) -> String {
        switch sortOrder {
        case .newestFirst:
            return L10n.text("s1.sort.newest_first")
        case .oldestFirst:
            return L10n.text("s1.sort.oldest_first")
        }
    }
}

private enum S1PreviewData {
    static func machine(
        state: S1State
    ) -> S1StateMachine {
        var store = SessionStore(sessionID: "preview-session")
        store.setMarked(
            true,
            assetID: "preview-asset-2",
            rangeID: "preview-range"
        )
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: .month,
            initialSortOrder: .newestFirst
        )
        guard let request = machine.currentReadRequest else {
            return machine
        }

        switch state {
        case .loading:
            break
        case .ready:
            _ = machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "preview-range",
                        displayName: "2026-08",
                        assetIDsNewestFirst: [
                            "preview-asset-2",
                            "preview-asset-1"
                        ]
                    )
                ]),
                for: request
            )
        case .empty:
            _ = machine.completeRangeRead(.success([]), for: request)
        case .failed:
            _ = machine.completeRangeRead(
                .failure(
                    S1RangeReadFailure(
                        groupingDimension: .month,
                        reason: .invalidResponse
                    )
                ),
                for: request
            )
        }
        return machine
    }
}

#Preview("S1-1") {
    S1View(machine: S1PreviewData.machine(state: .loading))
}

#Preview("S1-2") {
    S1View(machine: S1PreviewData.machine(state: .ready))
}

#Preview("S1-3") {
    S1View(machine: S1PreviewData.machine(state: .empty))
}

#Preview("S1-4") {
    S1View(machine: S1PreviewData.machine(state: .failed))
}
