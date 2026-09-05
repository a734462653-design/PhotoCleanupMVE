import XCTest
import Photos
@testable import PhotoCleanupMVE

final class S1StateMachineTests: XCTestCase {
    // IC046-001：首次进入后直接到达 S1-1，且读取请求携带显式注入的 T。
    func testIC046_001InitialEntryReachesLoading() {
        let machine = makeMachine(state: .loading)

        XCTAssertEqual(machine.state, .loading)
        XCTAssertEqual(machine.loadingState, .loading)
        XCTAssertEqual(machine.currentReadRequest?.groupingDimension, .date)
        XCTAssertTrue(machine.ranges.isEmpty)
    }

    // IC046-002：读取成功且存在可用范围时，从 S1-1 到达 S1-2。
    func testIC046_002SuccessfulNonemptyReadReachesReady() {
        let machine = makeMachine(state: .loading)
        let request = tryUnwrap(machine.currentReadRequest)

        XCTAssertTrue(
            machine.completeRangeRead(
                .success([makeRange()]),
                for: request
            )
        )
        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.loadingState, .ready)
        XCTAssertEqual(machine.ranges.map(\.id), ["range-month"])
    }

    // IC046-003：读取成功但范围数为零时到达 S1-3，而不是 S1-2。
    func testIC046_003SuccessfulEmptyReadReachesEmpty() {
        let machine = makeMachine(state: .loading)
        let request = tryUnwrap(machine.currentReadRequest)

        XCTAssertTrue(machine.completeRangeRead(.success([]), for: request))
        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.loadingState, .ready)
        XCTAssertTrue(machine.ranges.isEmpty)
    }

    // IC046-004：读取失败到达 S1-4，并保留可区分的失败原因向上报告。
    func testIC046_004FailedReadReachesFailedWithDistinctReason() {
        let machine = makeMachine(state: .loading)
        let request = tryUnwrap(machine.currentReadRequest)
        let failure = S1RangeReadFailure(
            groupingDimension: .date,
            reason: .authorizationDenied
        )

        XCTAssertTrue(
            machine.completeRangeRead(.failure(failure), for: request)
        )
        XCTAssertEqual(machine.state, .failed)
        XCTAssertEqual(machine.loadingState, .failed)
        XCTAssertEqual(machine.readFailure, failure)
        XCTAssertNotEqual(
            failure,
            S1RangeReadFailure(
                groupingDimension: .date,
                reason: .missingCreationDate(assetID: "asset-1")
            )
        )
    }

    // IC046-005：四个起始状态切换 T 均回到 S1-1，且 M、K、O、O_记录、会话标识不变。
    func testIC046_005GroupingSwitchAlwaysReturnsToLoadingAndPreservesSession() {
        for initialState in allStates {
            let machine = makeMachine(
                state: initialState,
                store: makeStoreWithContinuation()
            )
            let originalStore = machine.sessionStore
            let originalSortOrder = machine.sortOrder
            let originalRecordedSortOrder = machine.sessionStore
                .continuationsByRangeID["range-month"]?.recordedSortOrder

            XCTAssertTrue(machine.switchGroupingDimension(to: .album))
            XCTAssertEqual(machine.state, .loading)
            XCTAssertEqual(machine.loadingState, .loading)
            XCTAssertEqual(machine.groupingDimension, .album)
            XCTAssertEqual(machine.sortOrder, originalSortOrder)
            XCTAssertEqual(machine.sessionStore, originalStore)
            XCTAssertEqual(
                machine.sessionStore.continuationsByRangeID["range-month"]?
                    .recordedSortOrder,
                originalRecordedSortOrder
            )
            XCTAssertEqual(machine.sessionStore.sessionID, originalStore.sessionID)
        }
    }

    // IC046-006：四个起始状态切换 O 均保持 L，且 T、M、K、O_记录、会话标识不变。
    func testIC046_006SortSwitchPreservesLoadingAndSessionState() {
        for initialState in allStates {
            let machine = makeMachine(
                state: initialState,
                store: makeStoreWithContinuation()
            )
            let originalLoadingState = machine.loadingState
            let originalGroupingDimension = machine.groupingDimension
            let originalStore = machine.sessionStore
            let originalRequest = machine.currentReadRequest

            XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
            XCTAssertEqual(machine.loadingState, originalLoadingState)
            XCTAssertEqual(machine.groupingDimension, originalGroupingDimension)
            XCTAssertEqual(machine.sessionStore, originalStore)
            XCTAssertEqual(machine.currentReadRequest, originalRequest)
            XCTAssertEqual(
                machine.sessionStore.continuationsByRangeID["range-month"]?
                    .recordedSortOrder,
                .newestFirst
            )
        }
    }

    // IC046-007：切换 T 后，旧读取的晚到结果被拒绝且不能覆盖新 T 的加载态。
    func testIC046_007StaleReadCompletionIsIgnoredAfterGroupingSwitch() {
        let machine = makeMachine(state: .loading)
        let staleRequest = tryUnwrap(machine.currentReadRequest)

        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        XCTAssertFalse(
            machine.completeRangeRead(
                .success([makeRange()]),
                for: staleRequest
            )
        )
        XCTAssertEqual(machine.state, .loading)
        XCTAssertEqual(machine.groupingDimension, .album)
        XCTAssertNotEqual(machine.currentReadRequest, staleRequest)
        XCTAssertTrue(machine.ranges.isEmpty)
    }

    // IC046-008：只有 S1-4 可重试，重试后对同一 T 形成新请求并到达 S1-1。
    func testIC046_008RetryFromFailureCreatesNewLoadingRequest() {
        let machine = makeMachine(
            state: .failed,
            store: makeStoreWithContinuation()
        )
        let originalStore = machine.sessionStore

        XCTAssertTrue(machine.retry())
        XCTAssertEqual(machine.state, .loading)
        XCTAssertEqual(machine.currentReadRequest?.groupingDimension, .date)
        XCTAssertEqual(machine.sessionStore, originalStore)
        XCTAssertFalse(machine.retry())
    }

    // IC046-009：加载中、失败与空态都不能形成 A 或 S1 到 S2 的交接数据。
    func testIC046_009LoadingFailedAndEmptyCannotFormS2Handoff() {
        for state in [S1State.loading, .failed, .empty] {
            let machine = makeMachine(state: state)
            XCTAssertNil(machine.makeS2Handoff(for: "range-month"))
        }
    }

    // IC046-010：当前 O 与 O_记录一致时，已处理集合取 p 及其之前。
    func testIC046_010ProcessedAssetsUsePrefixWhenOrdersMatch() {
        let machine = makeMachine(
            state: .ready,
            store: makeStoreWithContinuation()
        )

        XCTAssertEqual(
            machine.processedAssetIDs(for: "range-month"),
            ["asset-3", "asset-2"]
        )
    }

    // IC046-011：当前 O 与 O_记录不一致时，已处理集合按当前 A 取 p 及其之后。
    func testIC046_011ProcessedAssetsUseSuffixWhenOrderFlips() {
        let machine = makeMachine(
            state: .ready,
            store: makeStoreWithContinuation()
        )

        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(
            machine.processedAssetIDs(for: "range-month"),
            ["asset-2", "asset-3"]
        )
    }

    // IC046-012：徽标始终等于 D_全部 去重元素数，与当前 T、O 和 L 无关。
    func testIC046_012BadgeAlwaysUsesMergedDeletionSetCount() {
        var store = SessionStore(sessionID: "session-badge")
        store.setMarked(true, assetID: "asset-shared", rangeID: "range-month")
        store.setMarked(true, assetID: "asset-shared", rangeID: "range-album")
        store.setMarked(true, assetID: "asset-only", rangeID: "range-album")
        let machine = makeMachine(state: .ready, store: store)

        XCTAssertEqual(machine.badgeCount, 2)
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(machine.badgeCount, 2)
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        XCTAssertEqual(machine.state, .loading)
        XCTAssertEqual(machine.badgeCount, 2)

        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success([]), for: request))
        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.badgeCount, 2)
    }

    // IC046-013：六字段交接满足 A 非空有序唯一、c 属于 A、D 是 A 的子集及总数只读快照。
    func testIC046_013S2HandoffContainsSixValidFields() {
        let machine = makeMachine(
            state: .ready,
            store: makeStoreWithContinuation()
        )
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))

        let handoff = tryUnwrap(
            machine.makeS2Handoff(for: "range-month")
        )

        XCTAssertEqual(handoff.sessionID, "session-with-continuation")
        XCTAssertEqual(handoff.rangeDisplayInformation.rangeID, "range-month")
        XCTAssertEqual(handoff.rangeDisplayInformation.displayName, "2026-08")
        XCTAssertEqual(handoff.rangeDisplayInformation.totalAssetCount, 3)
        XCTAssertEqual(
            handoff.orderedAssetIDs,
            ["asset-1", "asset-2", "asset-3"]
        )
        XCTAssertEqual(Set(handoff.orderedAssetIDs).count, 3)
        XCTAssertEqual(handoff.currentAssetID, "asset-2")
        XCTAssertTrue(handoff.orderedAssetIDs.contains(handoff.currentAssetID))
        XCTAssertEqual(handoff.pendingDeletionAssetIDs, ["asset-1"])
        XCTAssertTrue(
            handoff.pendingDeletionAssetIDs.isSubset(
                of: Set(handoff.orderedAssetIDs)
            )
        )
        XCTAssertEqual(handoff.sessionMergedPendingDeletionCount, 1)

        let entryContext = SessionStore.S2EntryContext(
            rangeID: "range-month",
            orderedAssetIDs: ["asset-3", "asset-2", "asset-1"],
            sortOrder: .newestFirst
        )
        let returned = SessionStore.S2Return(
            sourceSessionID: "session-with-continuation",
            sourceRangeID: "range-month",
            pendingDeletionAssetIDs: [],
            currentAssetID: "asset-2",
            farthestAssetID: "asset-2"
        )
        XCTAssertTrue(
            machine.applyS2Return(returned, entryContext: entryContext)
        )
        XCTAssertEqual(handoff.sessionMergedPendingDeletionCount, 0)
    }

    // IC046-014：重复 A 或范围外 D 不能形成交接数据，且错误读取不得伪装为空态。
    func testIC046_014InvalidAOrDRejectsS2Handoff() {
        let invalidReadMachine = makeMachine(state: .loading)
        let request = tryUnwrap(invalidReadMachine.currentReadRequest)
        let duplicateRange = S1Range(
            id: "range-month",
            displayName: "2026-08",
            assetIDsNewestFirst: ["asset-1", "asset-1"]
        )

        XCTAssertFalse(
            invalidReadMachine.completeRangeRead(
                .success([duplicateRange]),
                for: request
            )
        )
        XCTAssertEqual(invalidReadMachine.state, .failed)
        XCTAssertNil(
            invalidReadMachine.makeS2Handoff(for: "range-month")
        )

        var invalidStore = SessionStore(sessionID: "session-invalid-d")
        invalidStore.setMarked(
            true,
            assetID: "asset-outside",
            rangeID: "range-month"
        )
        let invalidDMachine = makeMachine(state: .ready, store: invalidStore)
        XCTAssertNil(invalidDMachine.makeS2Handoff(for: "range-month"))
    }

    // IC046-015：O 只翻转月、年范围列表；相册列表保持读取方提供的占位顺序。
    func testIC046_015SortFlipsChronologicalRangesButNotAlbumRanges() {
        let chronologicalMachine = makeMachine(
            state: .ready,
            ranges: [
                makeRange(id: "newer", displayName: "2026-08"),
                makeRange(id: "older", displayName: "2026-07")
            ]
        )
        XCTAssertEqual(
            chronologicalMachine.visibleRanges.map(\.id),
            ["newer", "older"]
        )
        XCTAssertTrue(
            chronologicalMachine.switchSortOrder(to: .oldestFirst)
        )
        XCTAssertEqual(
            chronologicalMachine.visibleRanges.map(\.id),
            ["older", "newer"]
        )

        let albumMachine = makeMachine(
            state: .ready,
            groupingDimension: .album,
            ranges: [
                makeRange(id: "album-b", displayName: "B"),
                makeRange(id: "album-a", displayName: "A")
            ]
        )
        XCTAssertTrue(albumMachine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(
            albumMachine.visibleRanges.map(\.id),
            ["album-b", "album-a"]
        )
    }

    // IC046-016：Q 呈现时所有 S1 输入失效，关闭后恢复覆盖前状态与数据。
    func testIC046_016ObscurationBlocksInputsAndPreservesState() {
        let machine = makeMachine(
            state: .ready,
            store: makeStoreWithContinuation()
        )
        let originalStore = machine.sessionStore
        let originalRanges = machine.ranges

        machine.presentObscuration()
        XCTAssertFalse(machine.switchGroupingDimension(to: .album))
        XCTAssertFalse(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertNil(machine.makeS2Handoff(for: "range-month"))
        XCTAssertNil(machine.makeS3Submission())
        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.ranges, originalRanges)
        XCTAssertEqual(machine.sessionStore, originalStore)

        machine.dismissObscuration()
        XCTAssertNotNil(machine.makeS2Handoff(for: "range-month"))
    }

    // IC046-017：有效 S2 返回原子写回 M 与 K，并保持 T、O、L 与会话标识。
    func testIC046_017S2ReturnWritesSessionWithoutChangingS1Parameters() {
        var store = SessionStore(sessionID: "session-return")
        store.setMarked(true, assetID: "asset-1", rangeID: "range-month")
        let machine = makeMachine(state: .ready, store: store)
        let originalGroupingDimension = machine.groupingDimension
        let originalSortOrder = machine.sortOrder
        let context = SessionStore.S2EntryContext(
            rangeID: "range-month",
            orderedAssetIDs: ["asset-3", "asset-2", "asset-1"],
            sortOrder: .newestFirst
        )
        let returned = SessionStore.S2Return(
            sourceSessionID: "session-return",
            sourceRangeID: "range-month",
            pendingDeletionAssetIDs: ["asset-1"],
            currentAssetID: "asset-2",
            farthestAssetID: "asset-2"
        )

        XCTAssertTrue(machine.applyS2Return(returned, entryContext: context))
        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.groupingDimension, originalGroupingDimension)
        XCTAssertEqual(machine.sortOrder, originalSortOrder)
        XCTAssertEqual(machine.sessionStore.sessionID, "session-return")
        XCTAssertEqual(
            machine.sessionStore.continuationsByRangeID["range-month"],
            SessionStore.Continuation(
                currentAssetID: "asset-2",
                farthestAssetID: "asset-2",
                recordedSortOrder: .newestFirst
            )
        )
    }

    // IC046-018：S1 范围项投影同时给出显示名、资产总数、待删计数与已处理进度。
    func testIC046_018RangeRowContainsAllFourRequiredValues() {
        let machine = makeMachine(
            state: .ready,
            store: makeStoreWithContinuation()
        )
        let row = tryUnwrap(machine.rangeRows.first)

        XCTAssertEqual(row.displayName, "2026-08")
        XCTAssertEqual(row.totalAssetCount, 3)
        XCTAssertEqual(row.pendingDeletionCount, 1)
        XCTAssertEqual(row.processedAssetCount, 2)
    }

    // IC-127 E（未定项 8 定案）：多范围提交时，分组顺序 = 范围在 R(T) 中的顺序，
    // 组内顺序 = 当前 O 下的 A(r, O)，总表 = 各组顺序拼接；O 翻转后两级同时翻转。
    func testIC127E_SubmissionFollowsRangeOrderInRTAndCurrentSortOrder() {
        var store = SessionStore(sessionID: "session-ic127e")
        store.setMarked(true, assetID: "new-3", rangeID: "newer")
        store.setMarked(true, assetID: "new-1", rangeID: "newer")
        store.setMarked(true, assetID: "old-2", rangeID: "older")
        store.setMarked(true, assetID: "old-3", rangeID: "older")
        let machine = makeMachine(
            state: .ready,
            store: store,
            ranges: [
                S1Range(
                    id: "newer",
                    displayName: "2026-08",
                    assetIDsNewestFirst: ["new-3", "new-2", "new-1"]
                ),
                S1Range(
                    id: "older",
                    displayName: "2026-07",
                    assetIDsNewestFirst: ["old-3", "old-2", "old-1"]
                )
            ]
        )

        let newestFirst = tryUnwrap(machine.makeS3Submission())
        XCTAssertEqual(
            newestFirst.groups.map(\.sourceRangeID),
            machine.visibleRanges.map(\.id)
        )
        XCTAssertEqual(newestFirst.groups.map(\.sourceRangeID), ["newer", "older"])
        XCTAssertEqual(
            newestFirst.groups.map(\.orderedAssetIDs),
            [["new-3", "new-1"], ["old-3", "old-2"]]
        )
        XCTAssertEqual(
            newestFirst.orderedAssetIDs,
            ["new-3", "new-1", "old-3", "old-2"]
        )
        XCTAssertEqual(newestFirst.groups.map(\.name), ["2026-08", "2026-07"])

        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        let oldestFirst = tryUnwrap(machine.makeS3Submission())
        XCTAssertEqual(
            oldestFirst.groups.map(\.sourceRangeID),
            machine.visibleRanges.map(\.id)
        )
        XCTAssertEqual(oldestFirst.groups.map(\.sourceRangeID), ["older", "newer"])
        XCTAssertEqual(
            oldestFirst.groups.map(\.orderedAssetIDs),
            [["old-2", "old-3"], ["new-1", "new-3"]]
        )
        XCTAssertEqual(
            oldestFirst.orderedAssetIDs,
            ["old-2", "old-3", "new-1", "new-3"]
        )
        XCTAssertEqual(
            Set(oldestFirst.orderedAssetIDs),
            Set(newestFirst.orderedAssetIDs)
        )
    }

    // IC-127 E 回归：各分组资产数之和恒等于 D_全部 元素数（含跨范围重复标记与
    // 当前 R(T) 不含的范围——后者按稳定回退排在 R(T) 内范围之后）。
    func testIC127E_GroupCountsStillSumToMergedDeletionCount() {
        var store = SessionStore(sessionID: "session-ic127e-sum")
        store.setMarked(true, assetID: "shared", rangeID: "range-month")
        store.setMarked(true, assetID: "shared", rangeID: "range-album")
        store.setMarked(true, assetID: "album-only", rangeID: "range-album")
        store.setMarked(true, assetID: "asset-3", rangeID: "range-month")
        let machine = makeMachine(
            state: .ready,
            store: store,
            ranges: [
                S1Range(
                    id: "range-month",
                    displayName: "2026-08",
                    assetIDsNewestFirst: ["asset-3", "shared", "asset-1"]
                )
            ]
        )
        // range-album 不在当前 R(T) 中，但其名称须为已知才可提交；此处先在
        // 相册维度读到它一次，再切回月维度，模拟跨维度标记。
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        let albumRequest = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "range-album",
                        displayName: "Album",
                        assetIDsNewestFirst: ["album-only", "shared"]
                    )
                ]),
                for: albumRequest
            )
        )
        XCTAssertTrue(machine.switchGroupingDimension(to: .date))
        let monthRequest = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "range-month",
                        displayName: "2026-08",
                        assetIDsNewestFirst: ["asset-3", "shared", "asset-1"]
                    )
                ]),
                for: monthRequest
            )
        )

        let submission = tryUnwrap(machine.makeS3Submission())
        let groupCountSum = submission.groups.reduce(0) { $0 + $1.assetCount }
        XCTAssertEqual(groupCountSum, machine.sessionStore.allPendingDeletionAssetIDs.count)
        XCTAssertEqual(groupCountSum, submission.assetCount)
        XCTAssertEqual(groupCountSum, 3)
        XCTAssertEqual(
            Set(submission.orderedAssetIDs),
            machine.sessionStore.allPendingDeletionAssetIDs
        )
        XCTAssertEqual(
            submission.groups.map(\.sourceRangeID),
            ["range-month", "range-album"]
        )
        XCTAssertEqual(
            submission.groups.first?.orderedAssetIDs,
            ["asset-3", "shared"]
        )
        XCTAssertEqual(
            submission.groups.last?.orderedAssetIDs,
            ["album-only"]
        )
    }

    private var allStates: [S1State] {
        [.loading, .ready, .empty, .failed]
    }

    private func makeMachine(
        state: S1State,
        store: SessionStore = SessionStore(sessionID: "session-default"),
        groupingDimension: S1GroupingDimension = .date,
        ranges: [S1Range]? = nil
    ) -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: groupingDimension,
            initialSortOrder: .newestFirst
        )
        guard state != .loading,
              let request = machine.currentReadRequest else {
            return machine
        }

        switch state {
        case .loading:
            break
        case .ready:
            precondition(
                machine.completeRangeRead(
                    .success(ranges ?? [makeRange()]),
                    for: request
                )
            )
        case .empty:
            precondition(machine.completeRangeRead(.success([]), for: request))
        case .failed:
            precondition(
                machine.completeRangeRead(
                    .failure(
                        S1RangeReadFailure(
                            groupingDimension: groupingDimension,
                            reason: .invalidResponse
                        )
                    ),
                    for: request
                )
            )
        }
        return machine
    }

    private func makeRange(
        id: String = "range-month",
        displayName: String = "2026-08"
    ) -> S1Range {
        S1Range(
            id: id,
            displayName: displayName,
            assetIDsNewestFirst: ["asset-3", "asset-2", "asset-1"]
        )
    }

    private func makeStoreWithContinuation() -> SessionStore {
        var store = SessionStore(sessionID: "session-with-continuation")
        store.setMarked(true, assetID: "asset-1", rangeID: "range-month")
        let context = SessionStore.S2EntryContext(
            rangeID: "range-month",
            orderedAssetIDs: ["asset-3", "asset-2", "asset-1"],
            sortOrder: .newestFirst
        )
        let returned = SessionStore.S2Return(
            sourceSessionID: store.sessionID,
            sourceRangeID: "range-month",
            pendingDeletionAssetIDs: ["asset-1"],
            currentAssetID: "asset-2",
            farthestAssetID: "asset-2"
        )
        precondition(store.applyS2Return(returned, entryContext: context))
        return store
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        do {
            return try XCTUnwrap(value, file: file, line: line)
        } catch {
            XCTFail(String(describing: error), file: file, line: line)
            preconditionFailure()
        }
    }
}

// MARK: - IC-127（并入本文件：工程文件未在授权范围内，新增测试文件无法登记）

/// IC-127 A：`T=date` 两级树（Decision_log 140 漂移 A，SPEC-S1 第二／六节）。
final class S1DateTreeTests: XCTestCase {
    // 三类维度枚举齐全且仅此三类。
    func testIC127A_GroupingDimensionHasExactlyThreeCases() {
        XCTAssertEqual(
            S1GroupingDimension.allCases,
            [.date, .album, .unclassified]
        )
        XCTAssertEqual(S1GroupingDimension.allCases.count, 3)
    }

    // 读取方按日期形成两级树：年为一级、月为二级并指向所属年；
    // 年节点资产 = 其月节点资产之并，总数相等；列表顺序为「年，其下月……」新到旧。
    @MainActor
    func testIC127A_ServiceBuildsYearMonthTreeAndYearTotalEqualsSumOfMonths() throws {
        let service = PhotoLibraryService(
            s1Source: makeSource(
                allAssets: [
                    makeAsset("资产-2026-08-a", year: 2026, month: 8, day: 15),
                    makeAsset("资产-2026-08-b", year: 2026, month: 8, day: 2),
                    makeAsset("资产-2026-03", year: 2026, month: 3, day: 10),
                    makeAsset("资产-2024-01", year: 2024, month: 1, day: 5)
                ]
            )
        )

        let ranges = try service.s1Ranges(groupedBy: .date).get()
        let years = ranges.filter { $0.parentRangeID == nil }

        XCTAssertEqual(ranges.count, 5)
        XCTAssertEqual(years.count, 2)
        XCTAssertTrue(years.allSatisfy { $0.id.hasPrefix("year:") })
        XCTAssertEqual(years.map(\.totalAssetCount), [3, 1])
        XCTAssertEqual(
            ranges.map(\.parentRangeID),
            [nil, years[0].id, years[0].id, nil, years[1].id]
        )
        for year in years {
            let months = ranges.filter { $0.parentRangeID == year.id }
            XCTAssertFalse(months.isEmpty)
            XCTAssertTrue(months.allSatisfy { $0.id.hasPrefix("month:") })
            XCTAssertEqual(
                months.reduce(0) { $0 + $1.totalAssetCount },
                year.totalAssetCount
            )
            XCTAssertEqual(
                Set(months.flatMap(\.assetIDsNewestFirst)),
                Set(year.assetIDsNewestFirst)
            )
        }
        XCTAssertEqual(
            years[0].assetIDsNewestFirst,
            ["资产-2026-08-a", "资产-2026-08-b", "资产-2026-03"]
        )
    }

    // 年节点与月节点各自可进入 S2，交接数据正确且互不串味。
    func testIC127A_YearAndMonthNodesEachFormValidS2Handoff() {
        let machine = makeTreeMachine()

        let yearHandoff = tryUnwrap(machine.makeS2Handoff(for: "y2026"))
        XCTAssertEqual(yearHandoff.rangeDisplayInformation.displayName, "2026")
        XCTAssertEqual(yearHandoff.rangeDisplayInformation.totalAssetCount, 3)
        XCTAssertEqual(yearHandoff.orderedAssetIDs, ["a8", "a3b", "a3a"])
        XCTAssertEqual(yearHandoff.currentAssetID, "a8")

        let monthHandoff = tryUnwrap(machine.makeS2Handoff(for: "m2026-03"))
        XCTAssertEqual(monthHandoff.rangeDisplayInformation.displayName, "2026-03")
        XCTAssertEqual(monthHandoff.rangeDisplayInformation.totalAssetCount, 2)
        XCTAssertEqual(monthHandoff.orderedAssetIDs, ["a3b", "a3a"])

        // 在年范围内标记一张，月范围的 D 不受影响（范围级 D 各自记录）。
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["a3a"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "y2026",
                    orderedAssetIDs: ["a8", "a3b", "a3a"],
                    sortOrder: .newestFirst
                )
            )
        )
        XCTAssertEqual(
            machine.makeS2Handoff(for: "y2026")?.pendingDeletionAssetIDs,
            ["a3a"]
        )
        XCTAssertEqual(
            machine.makeS2Handoff(for: "m2026-03")?.pendingDeletionAssetIDs,
            []
        )
        XCTAssertEqual(machine.badgeCount, 1)
    }

    // 收起后月节点不出现在可见列表，但范围数据仍在，月范围仍可进入 S2。
    func testIC127A_CollapsingYearHidesMonthRowsButKeepsRangeData() {
        let machine = makeTreeMachine()
        let originalRanges = machine.ranges
        let originalStore = machine.sessionStore

        XCTAssertTrue(machine.isYearExpanded("y2026"))
        XCTAssertTrue(machine.toggleYearExpansion("y2026"))
        XCTAssertFalse(machine.isYearExpanded("y2026"))
        XCTAssertEqual(
            machine.visibleRanges.map(\.id),
            ["y2026", "y2024", "m2024-01"]
        )
        XCTAssertEqual(
            machine.rangeRows.map(\.id),
            ["y2026", "y2024", "m2024-01"]
        )
        XCTAssertEqual(machine.rangeRows.first?.isExpanded, false)
        XCTAssertEqual(machine.rangeRows.first?.childCount, 2)
        XCTAssertEqual(machine.ranges, originalRanges)
        XCTAssertEqual(machine.sessionStore, originalStore)
        XCTAssertEqual(machine.state, .ready)
        XCTAssertNotNil(machine.makeS2Handoff(for: "m2026-08"))

        XCTAssertTrue(machine.toggleYearExpansion("y2026"))
        XCTAssertEqual(
            machine.visibleRanges.map(\.id),
            ["y2026", "m2026-08", "m2026-03", "y2024", "m2024-01"]
        )

        // 月节点、无子节点的范围与非日期维度都不是可展开目标。
        XCTAssertFalse(machine.toggleYearExpansion("m2026-08"))
        XCTAssertFalse(machine.toggleYearExpansion("missing"))
    }

    // O 翻转时年序与年内月序同时翻转。
    func testIC127A_SortFlipReversesYearOrderAndMonthOrderTogether() {
        let machine = makeTreeMachine()

        XCTAssertEqual(
            machine.visibleRanges.map(\.id),
            ["y2026", "m2026-08", "m2026-03", "y2024", "m2024-01"]
        )
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(
            machine.visibleRanges.map(\.id),
            ["y2024", "m2024-01", "y2026", "m2026-03", "m2026-08"]
        )
        XCTAssertEqual(
            machine.makeS2Handoff(for: "y2026")?.orderedAssetIDs,
            ["a3a", "a3b", "a8"]
        )
        XCTAssertTrue(machine.switchSortOrder(to: .newestFirst))
        XCTAssertEqual(
            machine.visibleRanges.map(\.id),
            ["y2026", "m2026-08", "m2026-03", "y2024", "m2024-01"]
        )
    }

    // 读取校验：年节点资产集合必须恰等于其月节点之并，不等即视为无效读取。
    func testIC127A_ReadRejectsYearWhoseAssetsDifferFromMonthUnion() {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-tree-invalid"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = tryUnwrap(machine.currentReadRequest)
        let mismatched = [
            S1Range(id: "y", displayName: "2026", assetIDsNewestFirst: ["a", "b", "c"]),
            S1Range(
                id: "m",
                displayName: "2026-08",
                assetIDsNewestFirst: ["a", "b"],
                parentRangeID: "y"
            )
        ]

        XCTAssertFalse(machine.completeRangeRead(.success(mismatched), for: request))
        XCTAssertEqual(machine.state, .failed)
        XCTAssertEqual(machine.readFailure?.reason, .invalidResponse)

        // 父引用必须指向同列表中的一级节点（不允许三级或悬空父）。
        let retryMachine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-tree-orphan"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let retryRequest = tryUnwrap(retryMachine.currentReadRequest)
        let orphan = [
            S1Range(
                id: "m",
                displayName: "2026-08",
                assetIDsNewestFirst: ["a"],
                parentRangeID: "missing-year"
            )
        ]
        XCTAssertFalse(retryMachine.completeRangeRead(.success(orphan), for: retryRequest))
        XCTAssertEqual(retryMachine.state, .failed)
    }

    // 展开／收起与进入年范围是两个可区分的目标：展开不形成交接、不改 T／O／M／K；
    // 进入不改展开态。
    func testIC127A_ExpandAndEnterAreDistinctTargets() {
        let machine = makeTreeMachine()
        let originalStore = machine.sessionStore
        let originalGrouping = machine.groupingDimension
        let originalSort = machine.sortOrder
        let originalRequest = machine.currentReadRequest

        XCTAssertTrue(machine.toggleYearExpansion("y2024"))
        XCTAssertEqual(machine.sessionStore, originalStore)
        XCTAssertEqual(machine.groupingDimension, originalGrouping)
        XCTAssertEqual(machine.sortOrder, originalSort)
        XCTAssertEqual(machine.currentReadRequest, originalRequest)
        XCTAssertEqual(machine.loadingState, .ready)

        let handoff = tryUnwrap(machine.makeS2Handoff(for: "y2024"))
        XCTAssertEqual(handoff.rangeDisplayInformation.rangeID, "y2024")
        XCTAssertFalse(machine.isYearExpanded("y2024"))
        XCTAssertEqual(machine.collapsedYearRangeIDs, ["y2024"])
    }

    // MARK: - Fixtures

    private func makeTreeMachine() -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-tree"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(.success(treeRanges()), for: request)
        )
        return machine
    }

    private func treeRanges() -> [S1Range] {
        [
            S1Range(
                id: "y2026",
                displayName: "2026",
                assetIDsNewestFirst: ["a8", "a3b", "a3a"]
            ),
            S1Range(
                id: "m2026-08",
                displayName: "2026-08",
                assetIDsNewestFirst: ["a8"],
                parentRangeID: "y2026"
            ),
            S1Range(
                id: "m2026-03",
                displayName: "2026-03",
                assetIDsNewestFirst: ["a3b", "a3a"],
                parentRangeID: "y2026"
            ),
            S1Range(
                id: "y2024",
                displayName: "2024",
                assetIDsNewestFirst: ["b1"]
            ),
            S1Range(
                id: "m2024-01",
                displayName: "2024-01",
                assetIDsNewestFirst: ["b1"],
                parentRangeID: "y2024"
            )
        ]
    }

    private func makeSource(
        allAssets: [S1PhotoAssetSnapshot]
    ) -> S1PhotoLibrarySource {
        S1PhotoLibrarySource(
            authorizationStatus: { .authorized },
            fetchAssets: { allAssets },
            fetchAssetCollections: { _, _ in [] }
        )
    }

    private func makeAsset(
        _ identifier: String,
        year: Int,
        month: Int,
        day: Int
    ) -> S1PhotoAssetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: 12
            )
        )!
        return S1PhotoAssetSnapshot(identifier: identifier, creationDate: date)
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        do {
            return try XCTUnwrap(value, file: file, line: line)
        } catch {
            XCTFail(String(describing: error), file: file, line: line)
            preconditionFailure()
        }
    }
}
