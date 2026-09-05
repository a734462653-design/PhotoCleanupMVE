struct SessionStore: Equatable, Sendable {
    typealias AssetID = String
    typealias RangeID = String

    enum SortOrder: String, Equatable, Sendable {
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

    /// IC-127 E／C：提交排序的兜底统计。`rangesOutsideOrder` = 有待删分组但不在
    /// `rangeOrder` 中的范围数；`assetsOutsideOrder` = 分组成员中未被该范围
    /// `A(r, O)` 覆盖、只能按标识升序补在组尾的资产数。
    struct S3SubmissionOrderingFallback: Equatable, Sendable {
        let rangesOutsideOrder: Int
        let assetsOutsideOrder: Int
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

    /// IC-127 B：由档恢复。恢复前逐条核第二节共同不变量——`F` 的键恰为 `D_全部`、
    /// `F[a]` 指向的范围确实含 `a`、续接字段非空；任一不成立返回 nil（视为坏档）。
    init?(
        sessionID: String,
        pendingDeletionAssetIDsByRangeID: [RangeID: Set<AssetID>],
        continuationsByRangeID: [RangeID: Continuation],
        firstMarkedRangeIDByAssetID: [AssetID: RangeID]
    ) {
        guard !sessionID.isEmpty else {
            return nil
        }
        var restored = State()
        restored.pendingDeletionAssetIDsByRangeID = pendingDeletionAssetIDsByRangeID
        restored.continuationsByRangeID = continuationsByRangeID
        restored.firstMarkedRangeIDByAssetID = firstMarkedRangeIDByAssetID

        let pendingAssetIDs = Self.allPendingDeletionAssetIDs(in: restored)
        guard Set(firstMarkedRangeIDByAssetID.keys) == pendingAssetIDs,
              !pendingAssetIDs.contains(String()),
              pendingDeletionAssetIDsByRangeID.keys.allSatisfy({ !$0.isEmpty }),
              firstMarkedRangeIDByAssetID.allSatisfy({ assetID, rangeID in
                  pendingDeletionAssetIDsByRangeID[rangeID]?.contains(assetID) == true
              }),
              continuationsByRangeID.allSatisfy({ rangeID, continuation in
                  !rangeID.isEmpty &&
                      !continuation.currentAssetID.isEmpty &&
                      !continuation.farthestAssetID.isEmpty
              }) else {
            return nil
        }
        self.sessionID = sessionID
        state = restored
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

    /// IC-127 C（未定项 13）：按新的可用资产序列对账一个范围。
    /// `M[r]` 剔除已不存在的资产（经 `setMarked(false)` 同步维护 `F`）；
    /// `K[r]` 的 `c_范围`／`p_范围` 若已不在序列中，钳到 `O_记录` 顺序下的序列末位。
    /// 幂等：对同一序列连调两次结果相同。返回是否有改动。
    @discardableResult
    mutating func reconcileRange(
        _ rangeID: RangeID,
        availableAssetIDsNewestFirst: [AssetID]
    ) -> Bool {
        let before = state
        let available = Set(availableAssetIDsNewestFirst)

        if let pending = state.pendingDeletionAssetIDsByRangeID[rangeID] {
            for assetID in pending.subtracting(available).sorted() {
                setMarked(false, assetID: assetID, rangeID: rangeID)
            }
        }

        if let continuation = state.continuationsByRangeID[rangeID],
           !availableAssetIDsNewestFirst.isEmpty {
            let recordedOrder: [AssetID]
            switch continuation.recordedSortOrder {
            case .newestFirst:
                recordedOrder = availableAssetIDsNewestFirst
            case .oldestFirst:
                recordedOrder = Array(availableAssetIDsNewestFirst.reversed())
            }
            let last = recordedOrder[recordedOrder.count - 1]
            let current = available.contains(continuation.currentAssetID)
                ? continuation.currentAssetID
                : last
            let farthest = available.contains(continuation.farthestAssetID)
                ? continuation.farthestAssetID
                : last
            if current != continuation.currentAssetID ||
                farthest != continuation.farthestAssetID {
                state.continuationsByRangeID[rangeID] = Continuation(
                    currentAssetID: current,
                    farthestAssetID: farthest,
                    recordedSortOrder: continuation.recordedSortOrder
                )
            }
        }

        return state != before
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
    /// 恒等于 `D_全部` 元素数。对账（IC-127 C）之后再提交，同维度内不应有任何
    /// 范围或资产走进回退分支（见 `s3SubmissionOrderingFallback`）。
    func makeS3Submission(
        rangeOrder: [RangeID],
        orderedAssetIDsForRangeID: (RangeID) -> [AssetID],
        groupNameForRangeID: (RangeID) -> String
    ) -> S3Submission {
        let ordering = orderedGroups(
            rangeOrder: rangeOrder,
            orderedAssetIDsForRangeID: orderedAssetIDsForRangeID
        )
        let groups = ordering.groups.map { entry in
            S3Submission.Group(
                sourceRangeID: entry.rangeID,
                name: groupNameForRangeID(entry.rangeID),
                orderedAssetIDs: entry.orderedAssetIDs
            )
        }
        return S3Submission(
            sourceSessionID: sessionID,
            orderedAssetIDs: groups.flatMap(\.orderedAssetIDs),
            groups: groups
        )
    }

    func s3SubmissionOrderingFallback(
        rangeOrder: [RangeID],
        orderedAssetIDsForRangeID: (RangeID) -> [AssetID]
    ) -> S3SubmissionOrderingFallback {
        orderedGroups(
            rangeOrder: rangeOrder,
            orderedAssetIDsForRangeID: orderedAssetIDsForRangeID
        ).fallback
    }

    private struct OrderedGroup {
        let rangeID: RangeID
        let orderedAssetIDs: [AssetID]
    }

    private func orderedGroups(
        rangeOrder: [RangeID],
        orderedAssetIDsForRangeID: (RangeID) -> [AssetID]
    ) -> (groups: [OrderedGroup], fallback: S3SubmissionOrderingFallback) {
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
        var rangesOutsideOrder = 0
        var assetsOutsideOrder = 0
        let groups = orderedRangeIDs.map { rangeID -> OrderedGroup in
            if rangeRank[rangeID] == nil {
                rangesOutsideOrder += 1
            }
            let members = groupedAssetIDs[rangeID] ?? []
            var ordered: [AssetID] = []
            var seen = Set<AssetID>()
            for assetID in orderedAssetIDsForRangeID(rangeID)
            where members.contains(assetID) && seen.insert(assetID).inserted {
                ordered.append(assetID)
            }
            let remainder = members.subtracting(seen).sorted()
            assetsOutsideOrder += remainder.count
            ordered.append(contentsOf: remainder)
            return OrderedGroup(rangeID: rangeID, orderedAssetIDs: ordered)
        }
        return (
            groups,
            S3SubmissionOrderingFallback(
                rangesOutsideOrder: rangesOutsideOrder,
                assetsOutsideOrder: assetsOutsideOrder
            )
        )
    }

    private static func allPendingDeletionAssetIDs(in state: State) -> Set<AssetID> {
        state.pendingDeletionAssetIDsByRangeID.values.reduce(into: Set<AssetID>()) {
            $0.formUnion($1)
        }
    }
}
