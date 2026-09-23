import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-163：「卡片叠」首页与新类别页真机预览第二轮。
///
/// 依据任务卡 IC-20260922-163 的五条裁定。子项 A（裁定 一：S2 写回只覆盖交接列表内的标记，
/// 列表外的既有标记原样保留）建本文件；子项 C（裁定 四：类别页排序与按月分节的纯函数）在类尾
/// 追加。A 可单独摘到 `main`；C 往 A 建的文件里追加，按提交不能脱离 A 单独摘取。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：类别页进篮后长按进 S2、点垃圾桶进 S3 看到这一组，
/// 以及从 S2 返回后已进篮项不回到网格，只有 H82 第 6／7 条能判。
final class IC163DeckPreviewRoundTwoTests: XCTestCase {

    // MARK: - 子项 A：S2 写回不抹类别篮

    /// 负对照：真实范围的交接列表恒等于整个范围，列表外的既有标记恒为空集，写回结果与改前一致。
    func testIC163A_RealRangeReturnUnchanged() throws {
        var store = SessionStore(sessionID: "session-ic163-real")
        store.setMarked(true, assetID: "a", rangeID: "range-month")
        let machine = makeMachine(
            state: .ready,
            store: store,
            ranges: [
                S1Range(
                    id: "range-month",
                    displayName: "2026-08",
                    assetIDsNewestFirst: ["a", "b", "c"]
                )
            ]
        )
        XCTAssertEqual(machine.state, .ready)
        let handoff = try XCTUnwrap(machine.makeS2Handoff(for: "range-month"))
        XCTAssertEqual(handoff.orderedAssetIDs, ["a", "b", "c"])
        XCTAssertEqual(handoff.pendingDeletionAssetIDs, ["a"])
        let entry = SessionStore.S2EntryContext(
            rangeID: "range-month",
            orderedAssetIDs: handoff.orderedAssetIDs,
            sortOrder: .newestFirst
        )

        // S2 里取消 a、新标 b：逐张镜像回报全集 {b}。
        XCTAssertTrue(machine.applyS2PendingDeletionChange(["b"], entryContext: entry))
        XCTAssertEqual(machine.sessionStore.pendingDeletionAssetIDsByRangeID["range-month"], ["b"])
        XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["a"])
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["b"], "range-month")

        XCTAssertTrue(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: machine.sessionStore.sessionID,
                    sourceRangeID: "range-month",
                    pendingDeletionAssetIDs: ["b"],
                    currentAssetID: "b",
                    farthestAssetID: "c"
                ),
                entryContext: entry
            )
        )
        XCTAssertEqual(machine.sessionStore.pendingDeletionAssetIDsByRangeID["range-month"], ["b"])
        XCTAssertEqual(machine.sessionStore.allPendingDeletionAssetIDs, ["b"])

        // 会话层单独对照（照 `SessionStoreTests` IC043-012 的用法）：进 S2 前标 {a}，返回集 {b}，
        // 写回后该范围集 = {b}，a 的首标记录随之清掉。
        var direct = SessionStore(sessionID: "session-ic163-direct")
        direct.setMarked(true, assetID: "a", rangeID: "range-month")
        direct.setMarked(true, assetID: "b", rangeID: "range-month")
        direct.setMarked(false, assetID: "a", rangeID: "range-month")
        XCTAssertTrue(
            direct.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: direct.sessionID,
                    sourceRangeID: "range-month",
                    pendingDeletionAssetIDs: ["b"],
                    currentAssetID: "b",
                    farthestAssetID: "c"
                ),
                entryContext: entry
            )
        )
        XCTAssertEqual(direct.pendingDeletionAssetIDsByRangeID["range-month"], ["b"])
        XCTAssertNil(direct.firstMarkedRangeIDByAssetID["a"])
    }

    /// 类别页先进篮 {p, q}（已进篮项不在网格里、也就不在交接列表里），再长按进 S2 标 y：
    /// 逐张镜像与整体写回都只动列表内的标记，p、q 留在篮里，S3 提交里这一组有三项。
    func testIC163A_VirtualRangeReturnKeepsBasketOutsideHandoff() throws {
        let machine = makeMachine(state: .empty)
        XCTAssertEqual(machine.state, .empty)
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["p", "q"],
                virtualRangeID: "cat:bigVideo",
                displayName: "视频"
            )
        )
        let handoff = try XCTUnwrap(
            machine.makeS2Handoff(virtualRangeID: "cat:bigVideo",
                                  displayName: "视频",
                                  orderedAssetIDs: ["x", "y", "z"],
                                  currentAssetID: "x")
        )
        XCTAssertEqual(handoff.pendingDeletionAssetIDs, [])
        XCTAssertEqual(machine.badgeCount, 2)
        let entry = SessionStore.S2EntryContext(
            rangeID: "cat:bigVideo",
            orderedAssetIDs: ["x", "y", "z"],
            sortOrder: .newestFirst
        )

        XCTAssertTrue(machine.applyS2PendingDeletionChange(["y"], entryContext: entry))
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"],
            ["p", "q", "y"]
        )
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["p"], "cat:bigVideo")
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["q"], "cat:bigVideo")
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["y"], "cat:bigVideo")

        XCTAssertTrue(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: machine.sessionStore.sessionID,
                    sourceRangeID: "cat:bigVideo",
                    pendingDeletionAssetIDs: ["y"],
                    currentAssetID: "y",
                    farthestAssetID: "y"
                ),
                entryContext: entry
            )
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"],
            ["p", "q", "y"]
        )
        XCTAssertEqual(machine.badgeCount, 3)
        XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)

        let submission = try XCTUnwrap(machine.makeS3Submission())
        let group = try XCTUnwrap(
            submission.groups.first { $0.sourceRangeID == "cat:bigVideo" }
        )
        XCTAssertEqual(group.name, "视频")
        XCTAssertEqual(group.orderedAssetIDs.count, 3)
        XCTAssertEqual(Set(group.orderedAssetIDs), ["p", "q", "y"])
    }

    /// 同上，但 S2 里先标 y 再取消（返回集为空）：列表内的 y 照常被取消，列表外的 p、q 不受影响。
    func testIC163A_VirtualRangeUnmarkInsideHandoffStillWorks() throws {
        let machine = makeMachine(state: .empty)
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["p", "q"],
                virtualRangeID: "cat:bigVideo",
                displayName: "视频"
            )
        )
        XCTAssertNotNil(
            machine.makeS2Handoff(virtualRangeID: "cat:bigVideo",
                                  displayName: "视频",
                                  orderedAssetIDs: ["x", "y", "z"],
                                  currentAssetID: "x")
        )
        let entry = SessionStore.S2EntryContext(
            rangeID: "cat:bigVideo",
            orderedAssetIDs: ["x", "y", "z"],
            sortOrder: .newestFirst
        )

        XCTAssertTrue(machine.applyS2PendingDeletionChange(["y"], entryContext: entry))
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"],
            ["p", "q", "y"]
        )
        XCTAssertTrue(machine.applyS2PendingDeletionChange([], entryContext: entry))
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"],
            ["p", "q"]
        )
        XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["y"])

        XCTAssertTrue(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: machine.sessionStore.sessionID,
                    sourceRangeID: "cat:bigVideo",
                    pendingDeletionAssetIDs: [],
                    currentAssetID: "z",
                    farthestAssetID: "z"
                ),
                entryContext: entry
            )
        )
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"],
            ["p", "q"]
        )
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["p"], "cat:bigVideo")
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["q"], "cat:bigVideo")
        XCTAssertEqual(machine.badgeCount, 2)
    }

    // MARK: - 子项 A 的夹具

    /// 照抄 `IC157LongPressIntoS2Tests` 的私有同名 helper（该 helper 为文件私有，不能跨文件调用）。
    /// 新构造的机器停在 `.loading`，`makeS3Submission()` 因加载态守卫恒 nil；虚拟范围用例取 `.empty`。
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
                    .success(ranges ?? []),
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
}
