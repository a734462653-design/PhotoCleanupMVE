import XCTest
@testable import PhotoCleanupMVE

/// IC-131 A：空态垃圾桶口径对齐锁定决策 8／24。
///
/// 修正对象：IC-128 卡取值表写错的「S1-3 空态：垃圾桶入口禁用、徽标不显示」。
/// 正确口径是四态统一——徽标与垃圾桶可触发性只取决于 `D_全部` 与「是否加载中」，
/// 与 `S1State` 的其余分支无关。
final class IC131S1TrashBadgeTests: XCTestCase {
    // 断言 3（四态穷举，一条测试八个用例）：把口径钉成表。
    // trashEnabled == (state != .loading && badgeCount > 0)
    // badgeText    == (badgeCount > 0 ? "3" : nil)
    func testIC131A_ChromeBarTrashAndBadgeFollowOnlyLoadingAndBadgeCount() {
        let states: [S1State] = [.loading, .ready, .empty, .failed]
        for state in states {
            for badgeCount in [0, 3] {
                let model = S1ChromeBarModel.make(
                    state: state,
                    badgeCount: badgeCount
                )
                let expectedTrashEnabled = state != .loading && badgeCount > 0
                let expectedBadgeText = badgeCount > 0 ? "3" : nil

                XCTAssertEqual(
                    model.trashEnabled,
                    expectedTrashEnabled,
                    "state=\(state) badgeCount=\(badgeCount) 的垃圾桶可触发性不符"
                )
                XCTAssertEqual(
                    model.badgeText,
                    expectedBadgeText,
                    "state=\(state) badgeCount=\(badgeCount) 的徽标文本不符"
                )
                // controlsEnabled／controlsOpacity 口径不变：只有加载中降 40%。
                XCTAssertEqual(model.controlsEnabled, state != .loading)
                XCTAssertEqual(
                    model.controlsOpacity,
                    state == .loading ? 0.4 : 1
                )
            }
        }
    }

    // 断言 2（状态机层）：维度 A 标记两张 → 切到一个 R(T) 为空的维度 →
    // 状态机到达 .empty → badgeCount 仍为 2，且 makeS3Submission() 仍能形成
    // 含这两张的提交。证明空态下提交路径畅通、不依赖当前 R(T)。
    func testIC131A_EmptyDimensionKeepsBadgeAndSubmissionPath() {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-131A"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )

        // 按日期维度读到一个范围，并在其中标记两张。
        let dateRequest = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "2026-08",
                        displayName: "2026年8月",
                        assetIDsNewestFirst: ["资产-3", "资产-2", "资产-1"]
                    )
                ]),
                for: dateRequest
            )
        )
        XCTAssertEqual(machine.state, .ready)
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["资产-1", "资产-2"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "2026-08",
                    orderedAssetIDs: ["资产-3", "资产-2", "资产-1"],
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            )
        )
        XCTAssertEqual(machine.badgeCount, 2)

        // 切到相册维度，读到空列表（设备上没有自建相册——很常见的场景）。
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        let albumRequest = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success([]), for: albumRequest))

        // S1-3 空态，但既有选择既没丢、也没被禁掉。
        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.badgeCount, 2)

        let model = S1ChromeBarModel.make(
            state: machine.state,
            badgeCount: machine.badgeCount
        )
        XCTAssertTrue(model.trashEnabled)
        XCTAssertEqual(model.badgeText, "2")

        // 提交路径畅通：空态下仍能形成含这两张的提交。
        let submission = tryUnwrap(machine.makeS3Submission())
        XCTAssertEqual(Set(submission.orderedAssetIDs), ["资产-1", "资产-2"])
        XCTAssertEqual(submission.sourceSessionID, "会话-131A")
        XCTAssertEqual(submission.groups.count, 1)
        let group = tryUnwrap(submission.groups.first)
        XCTAssertEqual(group.sourceRangeID, "2026-08")
        XCTAssertEqual(group.name, "2026年8月")
        XCTAssertEqual(Set(group.orderedAssetIDs), ["资产-1", "资产-2"])
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("期望非空值", file: file, line: line)
            fatalError("期望非空值")
        }
        return value
    }
}
