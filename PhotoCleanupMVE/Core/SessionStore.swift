struct SessionStore: Equatable, Sendable {
    typealias AssetID = String
    typealias RangeID = String

    enum SortOrder: Equatable, Sendable {
        case newestFirst
        case oldestFirst
    }

    struct Continuation: Equatable, Sendable {
        let currentAssetID: AssetID
        let farthestAssetID: AssetID
        let recordedSortOrder: SortOrder
    }

    struct S2EntryContext: Equatable, Sendable {
        let rangeID: RangeID
        let orderedAssetIDs: [AssetID]
        let sortOrder: SortOrder
    }

    struct S2Return: Equatable, Sendable {
        let sourceSessionID: String
        let sourceRangeID: RangeID
        let pendingDeletionAssetIDs: Set<AssetID>
        let currentAssetID: AssetID
        let farthestAssetID: AssetID
    }

    struct S3Return: Equatable, Sendable {
        let sourceSessionID: String
        let currentPendingDeletionAssetIDs: Set<AssetID>
    }

    struct S3Submission: Equatable, Sendable {
        struct Group: Equatable, Sendable {
            let sourceRangeID: RangeID
            let name: String
            let orderedAssetIDs: [AssetID]

            var assetCount: Int {
                orderedAssetIDs.count
            }
        }

        let sourceSessionID: String
        let orderedAssetIDs: [AssetID]
        let groups: [Group]

        var assetCount: Int {
            orderedAssetIDs.count
        }

        var assetCountByRangeID: [RangeID: Int] {
            Dictionary(
                uniqueKeysWithValues: groups.map { ($0.sourceRangeID, $0.assetCount) }
            )
        }
    }

    private struct State: Equatable, Sendable {
        var pendingDeletionAssetIDsByRangeID: [RangeID: Set<AssetID>] = [:]
        var continuationsByRangeID: [RangeID: Continuation] = [:]
        var firstMarkedRangeIDByAssetID: [AssetID: RangeID] = [:]
    }

    let sessionID: String
    private var state = State()

    var pendingDeletionAssetIDsByRangeID: [RangeID: Set<AssetID>] {
        state.pendingDeletionAssetIDsByRangeID
    }

    var continuationsByRangeID: [RangeID: Continuation] {
        state.continuationsByRangeID
    }

    var firstMarkedRangeIDByAssetID: [AssetID: RangeID] {
        state.firstMarkedRangeIDByAssetID
    }

    var allPendingDeletionAssetIDs: Set<AssetID> {
        Self.allPendingDeletionAssetIDs(in: state)
    }

    var pendingDeletionGroupsByRangeID: [RangeID: Set<AssetID>] {
        let pendingAssetIDs = allPendingDeletionAssetIDs
        let groups = state.firstMarkedRangeIDByAssetID.reduce(
            into: [RangeID: Set<AssetID>]()
        ) {
            if pendingAssetIDs.contains($1.key) {
                $0[$1.value, default: []].insert($1.key)
            }
        }
        precondition(
            groups.values.reduce(0) { $0 + $1.count } == pendingAssetIDs.count
        )
        return groups
    }

    init(sessionID: String) {
        precondition(!sessionID.isEmpty)
        self.sessionID = sessionID
    }

    mutating func setMarked(
        _ marked: Bool,
        assetID: AssetID,
        rangeID: RangeID
    ) {
        var nextState = state

        if marked {
            nextState.pendingDeletionAssetIDsByRangeID[rangeID, default: []]
                .insert(assetID)
            if nextState.firstMarkedRangeIDByAssetID[assetID] == nil {
                nextState.firstMarkedRangeIDByAssetID[assetID] = rangeID
            }
        }
        else {
            nextState.pendingDeletionAssetIDsByRangeID[rangeID]?.remove(assetID)
            let stillMarked = nextState.pendingDeletionAssetIDsByRangeID.values
                .contains { $0.contains(assetID) }
            if !stillMarked {
                nextState.firstMarkedRangeIDByAssetID.removeValue(forKey: assetID)
            }
        }

        state = nextState
    }

    func pendingDeletionCount(for rangeID: RangeID) -> Int {
        state.pendingDeletionAssetIDsByRangeID[rangeID]?.count ?? 0
    }

    func processedAssetIDs(
        for rangeID: RangeID,
        orderedAssetIDs: [AssetID],
        currentSortOrder: SortOrder
    ) -> Set<AssetID> {
        guard let continuation = state.continuationsByRangeID[rangeID],
              let farthestIndex = orderedAssetIDs.firstIndex(
                  of: continuation.farthestAssetID
              ) else {
            return []
        }

        if currentSortOrder == continuation.recordedSortOrder {
            return Set(orderedAssetIDs[...farthestIndex])
        }
        return Set(orderedAssetIDs[farthestIndex...])
    }

    @discardableResult
    mutating func applyS2Return(
        _ returned: S2Return,
        entryContext: S2EntryContext
    ) -> Bool {
        let assetIDSet = Set(entryContext.orderedAssetIDs)
        guard returned.sourceSessionID == sessionID,
              returned.sourceRangeID == entryContext.rangeID,
              !entryContext.orderedAssetIDs.isEmpty,
              assetIDSet.count == entryContext.orderedAssetIDs.count,
              returned.pendingDeletionAssetIDs.isSubset(of: assetIDSet),
              assetIDSet.contains(returned.currentAssetID),
              assetIDSet.contains(returned.farthestAssetID) else {
            return false
        }

        var nextState = state
        nextState.pendingDeletionAssetIDsByRangeID[entryContext.rangeID] =
            returned.pendingDeletionAssetIDs

        let remainingAssetIDs = Self.allPendingDeletionAssetIDs(in: nextState)
        nextState.firstMarkedRangeIDByAssetID =
            nextState.firstMarkedRangeIDByAssetID.filter {
                remainingAssetIDs.contains($0.key)
            }

        guard remainingAssetIDs.allSatisfy({
            nextState.firstMarkedRangeIDByAssetID[$0] != nil
        }) else {
            return false
        }

        nextState.continuationsByRangeID[entryContext.rangeID] = Continuation(
            currentAssetID: returned.currentAssetID,
            farthestAssetID: returned.farthestAssetID,
            recordedSortOrder: entryContext.sortOrder
        )
        state = nextState
        return true
    }

    @discardableResult
    mutating func applyS3Return(_ returned: S3Return) -> Bool {
        let submittedAssetIDs = allPendingDeletionAssetIDs
        guard returned.sourceSessionID == sessionID,
              returned.currentPendingDeletionAssetIDs.isSubset(
                  of: submittedAssetIDs
              ) else {
            return false
        }

        var nextState = state
        for rangeID in Array(nextState.pendingDeletionAssetIDsByRangeID.keys) {
            nextState.pendingDeletionAssetIDsByRangeID[rangeID]?
                .formIntersection(returned.currentPendingDeletionAssetIDs)
        }

        let remainingAssetIDs = Self.allPendingDeletionAssetIDs(in: nextState)
        nextState.firstMarkedRangeIDByAssetID =
            nextState.firstMarkedRangeIDByAssetID.filter {
                remainingAssetIDs.contains($0.key)
            }

        guard remainingAssetIDs == returned.currentPendingDeletionAssetIDs else {
            return false
        }

        state = nextState
        return true
    }

    func makeS3Submission(
        groupNameForRangeID: (RangeID) -> String
    ) -> S3Submission {
        let orderedAssetIDs = allPendingDeletionAssetIDs.sorted()
        let groupedAssetIDs = pendingDeletionGroupsByRangeID.mapValues { $0.sorted() }
        let groups = groupedAssetIDs.keys.sorted().map { rangeID in
            S3Submission.Group(
                sourceRangeID: rangeID,
                name: groupNameForRangeID(rangeID),
                orderedAssetIDs: groupedAssetIDs[rangeID] ?? []
            )
        }

        return S3Submission(
            sourceSessionID: sessionID,
            orderedAssetIDs: orderedAssetIDs,
            groups: groups
        )
    }

    /// IC-127 E（未定项 8 定案）：提交顺序 = 分组按其范围在 `R(T)` 中的顺序，
    /// 组内按当前 `O` 下该范围的 `A(r, O)` 顺序；总表为各组顺序拼接。
    /// `rangeOrder` 之外的范围（例如在另一维度下标记、当前 `R(T)` 不含）按
    /// 范围标识升序排在其后；`orderedAssetIDsForRangeID` 未覆盖到的资产按标识
    /// 升序补在该组末尾。两条回退只保证顺序稳定可重算，并保持各组资产数之和
    /// 恒等于 `D_全部` 元素数。
    func makeS3Submission(
        rangeOrder: [RangeID],
        orderedAssetIDsForRangeID: (RangeID) -> [AssetID],
        groupNameForRangeID: (RangeID) -> String
    ) -> S3Submission {
        let groupedAssetIDs = pendingDeletionGroupsByRangeID
        var rangeRank: [RangeID: Int] = [:]
        for (index, rangeID) in rangeOrder.enumerated()
        where rangeRank[rangeID] == nil {
            rangeRank[rangeID] = index
        }
        let orderedRangeIDs = groupedAssetIDs.keys.sorted { lhs, rhs in
            switch (rangeRank[lhs], rangeRank[rhs]) {
            case let (lhsRank?, rhsRank?):
                return lhsRank < rhsRank
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs < rhs
            }
        }
        let groups = orderedRangeIDs.map { rangeID -> S3Submission.Group in
            let members = groupedAssetIDs[rangeID] ?? []
            var ordered: [AssetID] = []
            var seen = Set<AssetID>()
            for assetID in orderedAssetIDsForRangeID(rangeID)
            where members.contains(assetID) && seen.insert(assetID).inserted {
                ordered.append(assetID)
            }
            ordered.append(contentsOf: members.subtracting(seen).sorted())
            return S3Submission.Group(
                sourceRangeID: rangeID,
                name: groupNameForRangeID(rangeID),
                orderedAssetIDs: ordered
            )
        }

        return S3Submission(
            sourceSessionID: sessionID,
            orderedAssetIDs: groups.flatMap(\.orderedAssetIDs),
            groups: groups
        )
    }

    private static func allPendingDeletionAssetIDs(in state: State) -> Set<AssetID> {
        state.pendingDeletionAssetIDsByRangeID.values.reduce(into: Set<AssetID>()) {
            $0.formUnion($1)
        }
    }
}
