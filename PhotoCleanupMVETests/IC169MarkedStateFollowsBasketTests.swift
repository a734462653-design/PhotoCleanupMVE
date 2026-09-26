import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-169：S2 标记态按合并待删集合显示（决策 42／63）；逐张镜像与返回写回只把本次会话新标的写进本范围、
/// 撤标从全部范围移除（④ 第 201 条 (b)）；S1 范围封面红角标按「合并待删集合 ∩ 本范围资产」计数
/// （④ 第 200 条第五节 (c)）。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：S2 里篮内照片显示为已标记、在别处撤标后类别篮里那张消失、
/// 范围角标与 S3 分组的观感，只有 H86 能判。
final class IC169MarkedStateFollowsBasketTests: XCTestCase {
    private static let monthID = "range-month"
    private static let categoryID = "cat:screenshot"

    // MARK: - 子项 A：交接初值

    /// 真实与虚拟两处交接的初值都是「合并待删集合 ∩ 列表」，不论照片在哪个范围标的；交接本身不写 M。
    func testIC169A_HandoffPendingSetIsBasketIntersectedWithList() throws {
        let machine = makeMachine(ranges: [monthRange()])
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["x", "p"],
                virtualRangeID: Self.categoryID,
                displayName: "截图"
            )
        )

        let real = try XCTUnwrap(machine.makeS2Handoff(for: Self.monthID))
        XCTAssertEqual(real.pendingDeletionAssetIDs, Set(["x"]))

        let virtual = try XCTUnwrap(
            machine.makeS2Handoff(
                virtualRangeID: "cat:bigVideo",
                displayName: "视频",
                orderedAssetIDs: ["p", "w"],
                currentAssetID: "w"
            )
        )
        XCTAssertEqual(virtual.pendingDeletionAssetIDs, Set(["p"]))
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.monthID] ?? [],
            Set<String>()
        )
    }

    // MARK: - 子项 B：逐张镜像

    /// 在月份的 S2 里下滑取消类别篮里的 x：x 从全部范围移除、首标记录删掉，篮里只剩 p；返回写回不改变这一结果。
    func testIC169B_UnmarkInAnotherRangeRemovesFromBasketEverywhere() throws {
        let machine = makeMachine(ranges: [monthRange()])
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["x", "p"],
                virtualRangeID: Self.categoryID,
                displayName: "截图"
            )
        )
        let handoff = try XCTUnwrap(machine.makeS2Handoff(for: Self.monthID))
        XCTAssertEqual(handoff.pendingDeletionAssetIDs, Set(["x"]))

        XCTAssertTrue(machine.applyS2PendingDeletionChange([], entryContext: monthEntry()))
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.categoryID],
            Set(["p"])
        )
        XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["x"])
        XCTAssertEqual(machine.badgeCount, 1)
        XCTAssertEqual(monthBadge(machine), 0)

        XCTAssertTrue(
            machine.applyS2Return(
                monthReturn(machine, pending: [], current: "x"),
                entryContext: monthEntry()
            )
        )
        XCTAssertEqual(machine.sessionStore.allPendingDeletionAssetIDs, Set(["p"]))
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.categoryID],
            Set(["p"])
        )
    }

    /// 同一会话里先取消 x 再标回：标回时 x 已不在篮，算新标，写进本范围、首标记录改为本范围。
    func testIC169B_UnmarkThenRemarkWritesCurrentRangeAndMovesFirstMark() throws {
        let machine = makeMachine(ranges: [monthRange()])
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["x", "p"],
                virtualRangeID: Self.categoryID,
                displayName: "截图"
            )
        )
        _ = try XCTUnwrap(machine.makeS2Handoff(for: Self.monthID))

        XCTAssertTrue(machine.applyS2PendingDeletionChange([], entryContext: monthEntry()))
        XCTAssertTrue(machine.applyS2PendingDeletionChange(["x"], entryContext: monthEntry()))
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.monthID],
            Set(["x"])
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.categoryID],
            Set(["p"])
        )
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["x"], Self.monthID)
        XCTAssertEqual(machine.badgeCount, 2)
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionGroupsByRangeID,
            [Self.categoryID: Set(["p"]), Self.monthID: Set(["x"])]
        )

        XCTAssertTrue(
            machine.applyS2Return(
                monthReturn(machine, pending: ["x"], current: "x"),
                entryContext: monthEntry()
            )
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.monthID],
            Set(["x"])
        )
        XCTAssertEqual(machine.badgeCount, 2)
    }

    // MARK: - 子项 C：返回写回

    /// 只看不改地往返：已在篮的 x 不写进月份、首标记录不变；类别范围对账移出 x 后首标记录随之删掉，
    /// 重建会话档不判坏档（RESEARCH-IC-169-addendum 第三节那条路径对新数据关闭）。
    func testIC169C_LookOnlyRoundTripWritesNothingIntoRange() throws {
        let machine = makeMachine(ranges: [monthRange()])
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["x"],
                virtualRangeID: Self.categoryID,
                displayName: "截图"
            )
        )
        let handoff = try XCTUnwrap(machine.makeS2Handoff(for: Self.monthID))
        XCTAssertTrue(
            machine.applyS2Return(
                monthReturn(machine, pending: handoff.pendingDeletionAssetIDs, current: "x"),
                entryContext: monthEntry()
            )
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.monthID] ?? [],
            Set<String>()
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.categoryID],
            Set(["x"])
        )
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["x"], Self.categoryID)
        XCTAssertEqual(machine.badgeCount, 1)
        XCTAssertEqual(monthBadge(machine), 1)

        var store = machine.sessionStore
        _ = store.reconcileRange(Self.categoryID, availableAssetIDsNewestFirst: [])
        XCTAssertNil(store.firstMarkedRangeIDByAssetID["x"])
        XCTAssertNotNil(
            SessionStore(
                sessionID: store.sessionID,
                pendingDeletionAssetIDsByRangeID: store.pendingDeletionAssetIDsByRangeID,
                continuationsByRangeID: store.continuationsByRangeID,
                firstMarkedRangeIDByAssetID: store.firstMarkedRangeIDByAssetID
            )
        )
    }

    /// 返回写回是最后一次同步加校验：没经逐张镜像的新标（无首标记录）整份拒绝、会话不变；
    /// 没经逐张镜像的取消照样从全部范围移除。
    func testIC169C_ReturnAppliesBothRulesAndKeepsFirstMarkGuard() throws {
        var store = SessionStore(sessionID: "session-ic169-return")
        store.setMarked(true, assetID: "y", rangeID: Self.monthID)
        let machine = makeMachine(store: store, ranges: [monthRange()])
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["x", "p"],
                virtualRangeID: Self.categoryID,
                displayName: "截图"
            )
        )
        let handoff = try XCTUnwrap(machine.makeS2Handoff(for: Self.monthID))
        XCTAssertEqual(handoff.pendingDeletionAssetIDs, Set(["x", "y"]))

        let storeBefore = machine.sessionStore
        XCTAssertFalse(
            machine.applyS2Return(
                monthReturn(machine, pending: ["x", "y", "z"], current: "z"),
                entryContext: monthEntry()
            )
        )
        XCTAssertEqual(machine.sessionStore, storeBefore)

        XCTAssertTrue(
            machine.applyS2Return(
                monthReturn(machine, pending: ["y"], current: "y"),
                entryContext: monthEntry()
            )
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.categoryID],
            Set(["p"])
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID[Self.monthID],
            Set(["y"])
        )
        XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["x"])
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["y"], Self.monthID)
        XCTAssertEqual(machine.badgeCount, 2)
    }

    // MARK: - 子项 D：范围角标

    /// 没进过 S2 的范围也按「合并待删集合 ∩ 本范围资产」显示角标；会话层的范围计数（`M[r]`）不变。
    func testIC169D_RangeBadgeCountsBasketWithinRange() throws {
        let machine = makeMachine(
            ranges: [
                S1Range(id: "range-a", displayName: "2026-07", assetIDsNewestFirst: ["x", "y"]),
                S1Range(id: "range-b", displayName: "2026-06", assetIDsNewestFirst: ["z", "w"])
            ]
        )
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["y", "z", "q"],
                virtualRangeID: Self.categoryID,
                displayName: "截图"
            )
        )
        XCTAssertEqual(
            machine.rangeRows.first { $0.id == "range-a" }?.pendingDeletionCount,
            1
        )
        XCTAssertEqual(
            machine.rangeRows.first { $0.id == "range-b" }?.pendingDeletionCount,
            1
        )
        XCTAssertEqual(machine.sessionStore.pendingDeletionCount(for: "range-a"), 0)
        XCTAssertEqual(machine.badgeCount, 3)
    }

    // MARK: - 夹具

    private func monthRange() -> S1Range {
        S1Range(id: Self.monthID, displayName: "2026-08", assetIDsNewestFirst: ["x", "y", "z"])
    }

    private func monthEntry() -> SessionStore.S2EntryContext {
        SessionStore.S2EntryContext(
            rangeID: Self.monthID,
            orderedAssetIDs: ["x", "y", "z"],
            sortOrder: .newestFirst
        )
    }

    private func monthReturn(
        _ machine: S1StateMachine,
        pending: Set<String>,
        current: String
    ) -> SessionStore.S2Return {
        SessionStore.S2Return(
            sourceSessionID: machine.sessionStore.sessionID,
            sourceRangeID: Self.monthID,
            pendingDeletionAssetIDs: pending,
            currentAssetID: current,
            farthestAssetID: "z"
        )
    }

    private func monthBadge(_ machine: S1StateMachine) -> Int? {
        machine.rangeRows.first { $0.id == Self.monthID }?.pendingDeletionCount
    }

    /// 就绪态机器，照 `IC163DeckPreviewRoundTwoTests.makeMachine` 的 `.ready` 分支。
    private func makeMachine(
        store: SessionStore = SessionStore(sessionID: "session-ic169"),
        ranges: [S1Range]
    ) -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        if let request = machine.currentReadRequest {
            precondition(machine.completeRangeRead(.success(ranges), for: request))
        }
        precondition(machine.state == .ready)
        return machine
    }
}
