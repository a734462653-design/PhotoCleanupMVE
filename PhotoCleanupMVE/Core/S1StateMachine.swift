import Combine
import Foundation

enum S1State: String, Equatable, Sendable {
    case loading = "S1-1"
    case ready = "S1-2"
    case empty = "S1-3"
    case failed = "S1-4"
}

enum S1LoadingState: Equatable, Sendable {
    case loading
    case ready
    case failed
}

enum S1GroupingDimension: CaseIterable, Equatable, Hashable, Sendable {
    case month
    case year
    case album
    case unclassified
}

enum S1SortOrder: CaseIterable, Equatable, Hashable, Sendable {
    case newestFirst
    case oldestFirst

    var sessionSortOrder: SessionStore.SortOrder {
        switch self {
        case .newestFirst:
            return .newestFirst
        case .oldestFirst:
            return .oldestFirst
        }
    }
}

struct S1Range: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let assetIDsNewestFirst: [String]

    var totalAssetCount: Int {
        assetIDsNewestFirst.count
    }

    func orderedAssetIDs(for sortOrder: S1SortOrder) -> [String] {
        switch sortOrder {
        case .newestFirst:
            return assetIDsNewestFirst
        case .oldestFirst:
            return Array(assetIDsNewestFirst.reversed())
        }
    }
}

struct S1RangeReadRequest: Equatable, Sendable {
    let generation: Int
    let groupingDimension: S1GroupingDimension
}

struct S1RangeReadFailure: Error, Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case authorizationNotDetermined
        case authorizationDenied
        case authorizationRestricted
        case limitedAuthorizationPolicyUndecided
        case unknownAuthorizationStatus(Int)
        case missingCreationDate(assetID: String)
        case missingDisplayName(rangeID: String)
        case duplicateRangeID(String)
        case duplicateAssetID(rangeID: String, assetID: String)
        case invalidResponse
    }

    let groupingDimension: S1GroupingDimension
    let reason: Reason
}

struct S1RangeDisplayInformation: Equatable, Sendable {
    let rangeID: String
    let displayName: String
    let totalAssetCount: Int
}

struct S1ToS2Handoff {
    let sessionID: String
    let rangeDisplayInformation: S1RangeDisplayInformation
    let orderedAssetIDs: [String]
    let currentAssetID: String
    let pendingDeletionAssetIDs: Set<String>

    private let sessionMergedPendingDeletionCountProvider: () -> Int

    var sessionMergedPendingDeletionCount: Int {
        sessionMergedPendingDeletionCountProvider()
    }

    init(
        sessionID: String,
        rangeDisplayInformation: S1RangeDisplayInformation,
        orderedAssetIDs: [String],
        currentAssetID: String,
        pendingDeletionAssetIDs: Set<String>,
        sessionMergedPendingDeletionCountProvider: @escaping () -> Int
    ) {
        self.sessionID = sessionID
        self.rangeDisplayInformation = rangeDisplayInformation
        self.orderedAssetIDs = orderedAssetIDs
        self.currentAssetID = currentAssetID
        self.pendingDeletionAssetIDs = pendingDeletionAssetIDs
        self.sessionMergedPendingDeletionCountProvider =
            sessionMergedPendingDeletionCountProvider
    }
}

struct S1RangeRow: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let totalAssetCount: Int
    let pendingDeletionCount: Int
    let processedAssetCount: Int
}

enum S1UndecidedPlaceholder: Equatable, Sendable {
    case unresolved
}

enum S1UndecidedItems {
    static let item01InitialGroupingAndSort = S1UndecidedPlaceholder.unresolved
    static let item02AuthorizationStates = S1UndecidedPlaceholder.unresolved
    static let item03AlbumOrderingAndInclusion = S1UndecidedPlaceholder.unresolved
    static let item04EmptyChronologicalRanges = S1UndecidedPlaceholder.unresolved
    static let item05LongNameTruncation = S1UndecidedPlaceholder.unresolved
    static let item06ZeroPendingAndProgressPresentation = S1UndecidedPlaceholder.unresolved
    static let item07EmptyMergedDeletionTrashPresentation = S1UndecidedPlaceholder.unresolved
    static let item08MergedDeletionSubmissionOrder = S1UndecidedPlaceholder.unresolved
    static let item09FailureDetailAndRetryPolicy = S1UndecidedPlaceholder.unresolved
    static let item10LoadingIndicator = S1UndecidedPlaceholder.unresolved
    static let item11SessionPersistenceAndEnd = S1UndecidedPlaceholder.unresolved
    static let item12S2ReturnValidationFailurePresentation = S1UndecidedPlaceholder.unresolved
    static let item13ExternalPhotoLibraryChanges = S1UndecidedPlaceholder.unresolved
    static let item14DuplicateRangeCountExplanation = S1UndecidedPlaceholder.unresolved
    static let item14bS3GroupOrderingAndPaging = S1UndecidedPlaceholder.unresolved
    static let item14cEmptyS3GroupPresentation = S1UndecidedPlaceholder.unresolved
    static let item15EmptyAndFailureCopy = S1UndecidedPlaceholder.unresolved
    static let item16RecommendedCleanupArea = S1UndecidedPlaceholder.unresolved
    static let item17FileSizeSort = S1UndecidedPlaceholder.unresolved

    enum LocalizedCopy {
        case loading
        case empty
        case failure
        case retry
        case zeroPending
        case progress
        case emptyTrash
    }

    static func localizedCopy(
        _ copy: LocalizedCopy,
        replacing replacements: [String: String] = [:]
    ) -> String {
        switch copy {
        case .loading:
            return L10n.text("s1.placeholder.loading")
        case .empty:
            return L10n.text("s1.placeholder.empty")
        case .failure:
            return L10n.text("s1.placeholder.failure")
        case .retry:
            return L10n.text("s1.placeholder.retry")
        case .zeroPending:
            return L10n.text("s1.placeholder.pending_zero")
        case .progress:
            return L10n.text(
                "s1.placeholder.processed_progress",
                replacing: replacements
            )
        case .emptyTrash:
            return L10n.text("s1.placeholder.trash_empty")
        }
    }
}

final class S1StateMachine: ObservableObject {
    @Published private(set) var loadingState: S1LoadingState = .loading
    @Published private(set) var groupingDimension: S1GroupingDimension
    @Published private(set) var sortOrder: S1SortOrder
    @Published private(set) var isObscured = false
    @Published private(set) var ranges: [S1Range] = []
    @Published private(set) var readFailure: S1RangeReadFailure?
    @Published private(set) var sessionStore: SessionStore

    private var readGeneration = 0
    private var knownRangeNamesByID: [String: String] = [:]

    init(
        sessionStore: SessionStore,
        initialGroupingDimension: S1GroupingDimension,
        initialSortOrder: S1SortOrder
    ) {
        self.sessionStore = sessionStore
        groupingDimension = initialGroupingDimension
        sortOrder = initialSortOrder
    }

    var state: S1State {
        switch loadingState {
        case .loading:
            return .loading
        case .ready:
            return ranges.isEmpty ? .empty : .ready
        case .failed:
            return .failed
        }
    }

    var currentReadRequest: S1RangeReadRequest? {
        guard loadingState == .loading else {
            return nil
        }
        return S1RangeReadRequest(
            generation: readGeneration,
            groupingDimension: groupingDimension
        )
    }

    var badgeCount: Int {
        sessionStore.allPendingDeletionAssetIDs.count
    }

    var visibleRanges: [S1Range] {
        guard groupingDimension == .month || groupingDimension == .year,
              sortOrder == .oldestFirst else {
            return ranges
        }
        return Array(ranges.reversed())
    }

    var rangeRows: [S1RangeRow] {
        visibleRanges.map { range in
            return S1RangeRow(
                id: range.id,
                displayName: range.displayName,
                totalAssetCount: range.totalAssetCount,
                pendingDeletionCount: sessionStore.pendingDeletionCount(
                    for: range.id
                ),
                processedAssetCount: processedAssetIDs(for: range.id).count
            )
        }
    }

    func processedAssetIDs(for rangeID: String) -> Set<String> {
        guard let range = ranges.first(where: { $0.id == rangeID }) else {
            return []
        }
        return sessionStore.processedAssetIDs(
            for: range.id,
            orderedAssetIDs: range.orderedAssetIDs(for: sortOrder),
            currentSortOrder: sortOrder.sessionSortOrder
        )
    }

    @discardableResult
    func completeRangeRead(
        _ result: Result<[S1Range], S1RangeReadFailure>,
        for request: S1RangeReadRequest
    ) -> Bool {
        guard request == currentReadRequest else {
            return false
        }

        switch result {
        case let .success(newRanges):
            guard Self.areValid(newRanges) else {
                ranges = []
                readFailure = S1RangeReadFailure(
                    groupingDimension: request.groupingDimension,
                    reason: .invalidResponse
                )
                loadingState = .failed
                return false
            }
            ranges = newRanges
            for range in newRanges {
                knownRangeNamesByID[range.id] = range.displayName
            }
            readFailure = nil
            loadingState = .ready
            return true

        case let .failure(failure):
            guard failure.groupingDimension == request.groupingDimension else {
                ranges = []
                readFailure = S1RangeReadFailure(
                    groupingDimension: request.groupingDimension,
                    reason: .invalidResponse
                )
                loadingState = .failed
                return false
            }
            ranges = []
            readFailure = failure
            loadingState = .failed
            return true
        }
    }

    @discardableResult
    func switchGroupingDimension(to newValue: S1GroupingDimension) -> Bool {
        guard !isObscured, newValue != groupingDimension else {
            return false
        }
        groupingDimension = newValue
        ranges = []
        readFailure = nil
        loadingState = .loading
        readGeneration += 1
        return true
    }

    @discardableResult
    func switchSortOrder(to newValue: S1SortOrder) -> Bool {
        guard !isObscured, newValue != sortOrder else {
            return false
        }
        sortOrder = newValue
        return true
    }

    @discardableResult
    func retry() -> Bool {
        guard !isObscured, loadingState == .failed else {
            return false
        }
        ranges = []
        readFailure = nil
        loadingState = .loading
        readGeneration += 1
        return true
    }

    func presentObscuration() {
        isObscured = true
    }

    func dismissObscuration() {
        isObscured = false
    }

    func makeS2Handoff(for rangeID: String) -> S1ToS2Handoff? {
        guard !isObscured,
              state == .ready,
              let range = ranges.first(where: { $0.id == rangeID }) else {
            return nil
        }

        let orderedAssetIDs = range.orderedAssetIDs(for: sortOrder)
        let assetIDSet = Set(orderedAssetIDs)
        let pendingDeletionAssetIDs =
            sessionStore.pendingDeletionAssetIDsByRangeID[range.id] ?? []
        let currentAssetID = sessionStore.continuationsByRangeID[range.id]?
            .currentAssetID ?? orderedAssetIDs.first

        guard !orderedAssetIDs.isEmpty,
              assetIDSet.count == orderedAssetIDs.count,
              pendingDeletionAssetIDs.isSubset(of: assetIDSet),
              let currentAssetID,
              assetIDSet.contains(currentAssetID) else {
            return nil
        }

        return S1ToS2Handoff(
            sessionID: sessionStore.sessionID,
            rangeDisplayInformation: S1RangeDisplayInformation(
                rangeID: range.id,
                displayName: range.displayName,
                totalAssetCount: range.totalAssetCount
            ),
            orderedAssetIDs: orderedAssetIDs,
            currentAssetID: currentAssetID,
            pendingDeletionAssetIDs: pendingDeletionAssetIDs,
            sessionMergedPendingDeletionCountProvider: { self.badgeCount }
        )
    }

    func makeS3Submission() -> SessionStore.S3Submission? {
        guard !isObscured, state != .loading else {
            return nil
        }
        let groupedRangeIDs = Set(
            sessionStore.pendingDeletionGroupsByRangeID.keys
        )
        guard groupedRangeIDs.allSatisfy({ knownRangeNamesByID[$0] != nil }) else {
            return nil
        }
        let rangeNamesByID = knownRangeNamesByID
        return sessionStore.makeS3Submission { rangeID in
            rangeNamesByID[rangeID] ?? String()
        }
    }

    @discardableResult
    func applyS2Return(
        _ returned: SessionStore.S2Return,
        entryContext: SessionStore.S2EntryContext
    ) -> Bool {
        guard !isObscured, state == .ready else {
            return false
        }
        var nextStore = sessionStore
        guard nextStore.applyS2Return(
            returned,
            entryContext: entryContext
        ) else {
            return false
        }
        sessionStore = nextStore
        return true
    }

    @discardableResult
    func applyS2PendingDeletionChange(
        _ pendingDeletionAssetIDs: Set<String>,
        entryContext: SessionStore.S2EntryContext
    ) -> Bool {
        guard !isObscured,
              state == .ready,
              let range = ranges.first(where: { $0.id == entryContext.rangeID }),
              entryContext.sortOrder == sortOrder.sessionSortOrder,
              entryContext.orderedAssetIDs == range.orderedAssetIDs(for: sortOrder),
              pendingDeletionAssetIDs.isSubset(
                  of: Set(entryContext.orderedAssetIDs)
              ) else {
            return false
        }

        var nextStore = sessionStore
        let previous = nextStore.pendingDeletionAssetIDsByRangeID[
            entryContext.rangeID
        ] ?? []
        for assetID in previous.subtracting(pendingDeletionAssetIDs).sorted() {
            nextStore.setMarked(
                false,
                assetID: assetID,
                rangeID: entryContext.rangeID
            )
        }
        for assetID in pendingDeletionAssetIDs.subtracting(previous).sorted() {
            nextStore.setMarked(
                true,
                assetID: assetID,
                rangeID: entryContext.rangeID
            )
        }
        sessionStore = nextStore
        return true
    }

    @discardableResult
    func applyS3Return(_ returned: SessionStore.S3Return) -> Bool {
        guard !isObscured else {
            return false
        }
        var nextStore = sessionStore
        guard nextStore.applyS3Return(returned) else {
            return false
        }
        sessionStore = nextStore
        return true
    }

    private static func areValid(_ ranges: [S1Range]) -> Bool {
        var rangeIDs = Set<String>()
        for range in ranges {
            let trimmedName = range.displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let assetIDs = Set(range.assetIDsNewestFirst)
            guard !range.id.isEmpty,
                  rangeIDs.insert(range.id).inserted,
                  !trimmedName.isEmpty,
                  !range.assetIDsNewestFirst.isEmpty,
                  assetIDs.count == range.assetIDsNewestFirst.count,
                  !assetIDs.contains(String()) else {
                return false
            }
        }
        return true
    }
}
