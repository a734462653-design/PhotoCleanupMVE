import XCTest
@testable import PhotoCleanupMVE

final class SessionStoreTests: XCTestCase {
    // IC043-001：SPEC-S1 v3 第七节第 4 部分，交集更新后的并集恰等于返回集合。
    func testIC043_001IntersectionReturnMakesUnionEqualReturnedSet() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-B", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-B", rangeID: "范围-相册")
        store.setMarked(true, assetID: "资产-C", rangeID: "范围-相册")

        XCTAssertTrue(
            store.applyS3Return(
                .init(
                    sourceSessionID: store.sessionID,
                    currentPendingDeletionAssetIDs: ["资产-B", "资产-C"]
                )
            )
        )

        XCTAssertEqual(store.allPendingDeletionAssetIDs, ["资产-B", "资产-C"])
        XCTAssertEqual(
            store.pendingDeletionAssetIDsByRangeID["范围-月"],
            ["资产-B"]
        )
        XCTAssertEqual(
            store.pendingDeletionAssetIDsByRangeID["范围-相册"],
            ["资产-B", "资产-C"]
        )
    }

    // IC043-002：决策 10，各分组资产数之和恒等于合并待删集合元素数。
    func testIC043_002GroupCountsSumEqualsMergedDeletionCount() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-相册")
        store.setMarked(true, assetID: "资产-相册独有", rangeID: "范围-相册")

        let submission = store.makeS3Submission { "名称-\($0)" }
        let groupCountSum = submission.assetCountByRangeID.values.reduce(0, +)
        let derivedGroupCountSum = store.pendingDeletionGroupsByRangeID.values
            .reduce(0) { $0 + $1.count }

        XCTAssertEqual(groupCountSum, store.allPendingDeletionAssetIDs.count)
        XCTAssertEqual(derivedGroupCountSum, store.allPendingDeletionAssetIDs.count)
        XCTAssertEqual(groupCountSum, submission.assetCount)
    }

    // IC043-003：第二节数据定义，F 已有键时不得被其他范围改写。
    func testIC043_003FirstMarkedRangeRemainsSingleValued() {
        var store = makeStore()

        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-首次")
        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-后来")

        XCTAssertEqual(
            store.firstMarkedRangeIDByAssetID["资产-共享"],
            "范围-首次"
        )
    }

    // IC043-004：第二节共同不变量，资产不再属于任何 M[r] 时删除 F 的键。
    func testIC043_004FirstMarkedRangeKeyIsRemovedOnlyAfterEveryRangeUnmarks() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-首次")
        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-后来")

        store.setMarked(false, assetID: "资产-共享", rangeID: "范围-首次")
        XCTAssertEqual(
            store.firstMarkedRangeIDByAssetID["资产-共享"],
            "范围-首次"
        )

        store.setMarked(false, assetID: "资产-共享", rangeID: "范围-后来")
        XCTAssertNil(store.firstMarkedRangeIDByAssetID["资产-共享"])
    }

    // IC043-005：决策 1 与共同不变量，跨范围重复资产全局去重、局部分别计数。
    func testIC043_005DuplicateAcrossRangesCountsOnceGloballyAndOncePerRange() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-共享", rangeID: "范围-相册")

        XCTAssertEqual(store.allPendingDeletionAssetIDs, ["资产-共享"])
        XCTAssertEqual(store.pendingDeletionCount(for: "范围-月"), 1)
        XCTAssertEqual(store.pendingDeletionCount(for: "范围-相册"), 1)
    }

    // IC043-006：决策 2，当前 O 与 O_记录一致时取 p 及其之前。
    func testIC043_006ProcessedAssetsUsePrefixWhenSortOrderMatchesRecord() {
        let store = makeStoreWithContinuation()

        XCTAssertEqual(
            store.processedAssetIDs(
                for: "范围-月",
                orderedAssetIDs: ["资产-A", "资产-B", "资产-C", "资产-D"],
                currentSortOrder: .newestFirst
            ),
            ["资产-A", "资产-B"]
        )
    }

    // IC043-007：决策 2，当前 O 与 O_记录不一致时取 p 及其之后。
    func testIC043_007ProcessedAssetsUseSuffixWhenSortOrderFlips() {
        let store = makeStoreWithContinuation()

        XCTAssertEqual(
            store.processedAssetIDs(
                for: "范围-月",
                orderedAssetIDs: ["资产-D", "资产-C", "资产-B", "资产-A"],
                currentSortOrder: .oldestFirst
            ),
            ["资产-B", "资产-A"]
        )
    }

    // IC043-008：第七节第 4 部分，返回空集时所有 M 为空、F 清空、D_全部为空。
    func testIC043_008EmptyS3ReturnClearsEveryPendingSetAndOwnershipKey() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-B", rangeID: "范围-相册")

        XCTAssertTrue(
            store.applyS3Return(
                .init(
                    sourceSessionID: store.sessionID,
                    currentPendingDeletionAssetIDs: []
                )
            )
        )

        XCTAssertTrue(
            store.pendingDeletionAssetIDsByRangeID.values.allSatisfy(\.isEmpty)
        )
        XCTAssertTrue(store.firstMarkedRangeIDByAssetID.isEmpty)
        XCTAssertTrue(store.allPendingDeletionAssetIDs.isEmpty)
    }

    // IC043-009：第二节边界，M 中全部范围为空时派生集合、分组与计数均为空。
    func testIC043_009AllEmptyRangeSetsProduceEmptyDerivedValues() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-B", rangeID: "范围-相册")
        store.setMarked(false, assetID: "资产-A", rangeID: "范围-月")
        store.setMarked(false, assetID: "资产-B", rangeID: "范围-相册")

        let submission = store.makeS3Submission { "名称-\($0)" }

        XCTAssertEqual(store.pendingDeletionAssetIDsByRangeID.count, 2)
        XCTAssertTrue(
            store.pendingDeletionAssetIDsByRangeID.values.allSatisfy(\.isEmpty)
        )
        XCTAssertTrue(store.allPendingDeletionAssetIDs.isEmpty)
        XCTAssertTrue(submission.orderedAssetIDs.isEmpty)
        XCTAssertTrue(submission.groups.isEmpty)
        XCTAssertTrue(submission.assetCountByRangeID.isEmpty)
    }

    // IC043-010：第二节边界，从未进入过的范围没有 M/K 键且派生量为空。
    func testIC043_010NeverEnteredRangeHasNoStoredStateAndEmptyDerivedValues() {
        let store = makeStore()

        XCTAssertNil(store.pendingDeletionAssetIDsByRangeID["范围-未进入"])
        XCTAssertNil(store.continuationsByRangeID["范围-未进入"])
        XCTAssertEqual(store.pendingDeletionCount(for: "范围-未进入"), 0)
        XCTAssertTrue(
            store.processedAssetIDs(
                for: "范围-未进入",
                orderedAssetIDs: ["资产-A"],
                currentSortOrder: .newestFirst
            ).isEmpty
        )
    }

    // IC043-011：第七节第 2 部分，五字段任一校验失败时 M、K、F 均不写回。
    func testIC043_011InvalidS2ReturnLeavesWholeStoreUnchanged() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
        let context = SessionStore.S2EntryContext(
            rangeID: "范围-月",
            orderedAssetIDs: ["资产-A", "资产-B"],
            sortOrder: .newestFirst
        )
        let invalidReturns = [
            SessionStore.S2Return(
                sourceSessionID: "其他会话",
                sourceRangeID: "范围-月",
                pendingDeletionAssetIDs: ["资产-A"],
                currentAssetID: "资产-A",
                farthestAssetID: "资产-B"
            ),
            SessionStore.S2Return(
                sourceSessionID: store.sessionID,
                sourceRangeID: "其他范围",
                pendingDeletionAssetIDs: ["资产-A"],
                currentAssetID: "资产-A",
                farthestAssetID: "资产-B"
            ),
            SessionStore.S2Return(
                sourceSessionID: store.sessionID,
                sourceRangeID: "范围-月",
                pendingDeletionAssetIDs: ["资产-范围外"],
                currentAssetID: "资产-A",
                farthestAssetID: "资产-B"
            ),
            SessionStore.S2Return(
                sourceSessionID: store.sessionID,
                sourceRangeID: "范围-月",
                pendingDeletionAssetIDs: ["资产-A"],
                currentAssetID: "资产-范围外",
                farthestAssetID: "资产-B"
            ),
            SessionStore.S2Return(
                sourceSessionID: store.sessionID,
                sourceRangeID: "范围-月",
                pendingDeletionAssetIDs: ["资产-A"],
                currentAssetID: "资产-A",
                farthestAssetID: "资产-范围外"
            ),
            SessionStore.S2Return(
                sourceSessionID: store.sessionID,
                sourceRangeID: "范围-月",
                pendingDeletionAssetIDs: ["资产-A", "资产-B"],
                currentAssetID: "资产-A",
                farthestAssetID: "资产-B"
            )
        ]

        for returned in invalidReturns {
            var candidate = store

            XCTAssertFalse(candidate.applyS2Return(returned, entryContext: context))
            XCTAssertEqual(candidate, store)
        }
    }

    // IC043-012：第七节第 2 部分，有效五字段一次写回 M 与 K，并清理失效 F 键。
    func testIC043_012ValidS2ReturnAtomicallyWritesPendingSetAndContinuation() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-B", rangeID: "范围-月")
        let context = SessionStore.S2EntryContext(
            rangeID: "范围-月",
            orderedAssetIDs: ["资产-A", "资产-B", "资产-C"],
            sortOrder: .oldestFirst
        )
        let returned = SessionStore.S2Return(
            sourceSessionID: store.sessionID,
            sourceRangeID: "范围-月",
            pendingDeletionAssetIDs: ["资产-A"],
            currentAssetID: "资产-B",
            farthestAssetID: "资产-C"
        )

        XCTAssertTrue(store.applyS2Return(returned, entryContext: context))
        XCTAssertEqual(
            store.pendingDeletionAssetIDsByRangeID["范围-月"],
            ["资产-A"]
        )
        XCTAssertEqual(
            store.continuationsByRangeID["范围-月"],
            SessionStore.Continuation(
                currentAssetID: "资产-B",
                farthestAssetID: "资产-C",
                recordedSortOrder: .oldestFirst
            )
        )
        XCTAssertNil(store.firstMarkedRangeIDByAssetID["资产-B"])
    }

    // IC043-013：第七节第 3 部分，S3 数据含稳定有序总表、分组划分和分组计数。
    func testIC043_013S3SubmissionContainsStablePartitionNamesAndCounts() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-Z", rangeID: "范围-月")
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-相册")
        store.setMarked(true, assetID: "资产-M", rangeID: "范围-月")
        let names = ["范围-月": "八月", "范围-相册": "假期"]

        let submission = store.makeS3Submission { names[$0] ?? "" }
        let repeatedSubmission = store.makeS3Submission { names[$0] ?? "" }

        XCTAssertEqual(submission, repeatedSubmission)
        XCTAssertEqual(submission.sourceSessionID, store.sessionID)
        XCTAssertEqual(submission.orderedAssetIDs, ["资产-A", "资产-M", "资产-Z"])
        XCTAssertEqual(
            Set(submission.groups.flatMap(\.orderedAssetIDs)),
            store.allPendingDeletionAssetIDs
        )
        XCTAssertEqual(
            Set(submission.groups.map(\.name)),
            ["八月", "假期"]
        )
        XCTAssertEqual(submission.assetCountByRangeID["范围-月"], 2)
        XCTAssertEqual(submission.assetCountByRangeID["范围-相册"], 1)
    }

    // IC043-014：第七节第 4 部分，错误会话或非子集返回不得更新会话层。
    func testIC043_014InvalidS3ReturnLeavesWholeStoreUnchanged() {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
        let invalidReturns = [
            SessionStore.S3Return(
                sourceSessionID: "其他会话",
                currentPendingDeletionAssetIDs: []
            ),
            SessionStore.S3Return(
                sourceSessionID: store.sessionID,
                currentPendingDeletionAssetIDs: ["资产-A", "资产-范围外"]
            )
        ]

        for returned in invalidReturns {
            var candidate = store

            XCTAssertFalse(candidate.applyS3Return(returned))
            XCTAssertEqual(candidate, store)
        }
    }

    private func makeStore() -> SessionStore {
        SessionStore(sessionID: "会话-IC043")
    }

    private func makeStoreWithContinuation() -> SessionStore {
        var store = makeStore()
        store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
        let context = SessionStore.S2EntryContext(
            rangeID: "范围-月",
            orderedAssetIDs: ["资产-A", "资产-B", "资产-C", "资产-D"],
            sortOrder: .newestFirst
        )
        let returned = SessionStore.S2Return(
            sourceSessionID: store.sessionID,
            sourceRangeID: "范围-月",
            pendingDeletionAssetIDs: ["资产-A"],
            currentAssetID: "资产-A",
            farthestAssetID: "资产-B"
        )

        precondition(store.applyS2Return(returned, entryContext: context))
        return store
    }
}
