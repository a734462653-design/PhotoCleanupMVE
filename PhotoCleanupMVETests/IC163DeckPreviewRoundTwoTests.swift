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

    // MARK: - 子项 C：类别页排序与按月分节（只测纯函数，不构造视图、不碰 PhotoKit）

    /// 五项（入参即数据源给的体积降序），其中 d2、d4 无日期。
    func testIC163C_SortedBySizeKeepsOrderAndTimeOrdersPutUndatedLast() throws {
        let calendar = try Self.utcCalendar()
        let items = Self.categoryAssets(["d0", "d1", "d2", "d3", "d4"])
        let dates: [String: Date] = try [
            "d0": Self.noon(2026, 3, 2, in: calendar),
            "d1": Self.noon(2026, 3, 30, in: calendar),
            "d3": Self.noon(2026, 2, 11, in: calendar)
        ]

        XCTAssertEqual(
            S0DeckHomeModel.sorted(items, by: .size, dates: dates).map { $0.id },
            ["d0", "d1", "d2", "d3", "d4"]
        )
        // 最新在前：有日期的按日期降序；无日期的两项在末尾，保持入参相对序。
        XCTAssertEqual(
            S0DeckHomeModel.sorted(items, by: .newestFirst, dates: dates).map { $0.id },
            ["d1", "d0", "d3", "d2", "d4"]
        )
        // 最旧在前：有日期的升序；无日期的仍在末尾。
        XCTAssertEqual(
            S0DeckHomeModel.sorted(items, by: .oldestFirst, dates: dates).map { $0.id },
            ["d3", "d0", "d1", "d2", "d4"]
        )
        // 没有任何日期：两种时间排序都等于入参顺序（全部归「无日期」）。
        XCTAssertEqual(
            S0DeckHomeModel.sorted(items, by: .newestFirst, dates: [:]).map { $0.id },
            ["d0", "d1", "d2", "d3", "d4"]
        )

        // 同日期按标识升序（两种方向都是）。
        let tied = Self.categoryAssets(["t-z", "t-a"])
        let sameDay = try Self.noon(2026, 1, 5, in: calendar)
        let tiedDates = ["t-z": sameDay, "t-a": sameDay]
        XCTAssertEqual(
            S0DeckHomeModel.sorted(tied, by: .newestFirst, dates: tiedDates).map { $0.id },
            ["t-a", "t-z"]
        )
        XCTAssertEqual(
            S0DeckHomeModel.sorted(tied, by: .oldestFirst, dates: tiedDates).map { $0.id },
            ["t-a", "t-z"]
        )
    }

    /// 最新在前排好后传入：3 月两项、2 月一项、无日期两项 → 三节，节序与节内序随入参。
    func testIC163C_MonthSectionsGroupByYearMonthInInputOrder() throws {
        let calendar = try Self.utcCalendar()
        let sorted = Self.categoryAssets(["m1", "m2", "m3", "u1", "u2"])
        let dates: [String: Date] = try [
            "m1": Self.noon(2026, 3, 30, in: calendar),
            "m2": Self.noon(2026, 3, 2, in: calendar),
            "m3": Self.noon(2026, 2, 11, in: calendar)
        ]

        let sections = S0DeckHomeModel.monthSections(sorted, dates: dates, calendar: calendar)
        XCTAssertEqual(sections.count, 3)
        XCTAssertEqual(sections.map { $0.items.map { $0.id } }, [["m1", "m2"], ["m3"], ["u1", "u2"]])

        // `monthStart` = 该月 1 日 0 点，用同一 `Calendar` 反算。
        let march = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))
        )
        let february = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))
        )
        XCTAssertEqual(sections[0].monthStart, march)
        XCTAssertEqual(sections[1].monthStart, february)
        XCTAssertNil(sections[2].monthStart)
        let marchParts = calendar.dateComponents([.day, .hour, .minute, .second], from: march)
        XCTAssertEqual(marchParts.day, 1)
        XCTAssertEqual(marchParts.hour, 0)
        XCTAssertEqual(marchParts.minute, 0)
        XCTAssertEqual(marchParts.second, 0)
    }

    func testIC163C_MonthSectionsEmptyInputGivesNoSections() throws {
        let calendar = try Self.utcCalendar()
        XCTAssertEqual(
            S0DeckHomeModel.monthSections([], dates: [:], calendar: calendar),
            []
        )
    }

    // MARK: - 子项 C 的夹具

    /// 固定公历、UTC，不用 `Calendar.current`。
    private static func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return calendar
    }

    /// 某日正午（UTC），离月界足够远。
    private static func noon(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        in calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: year, month: month, day: day, hour: 12)
            )
        )
    }

    /// 体积严格递减的若干项，顺序即入参（类别页数据源给的体积降序）。
    private static func categoryAssets(_ ids: [String]) -> [S0CategoryAsset] {
        ids.enumerated().map { pair in
            S0CategoryAsset(
                id: pair.element,
                byteCount: Int64(1_000 - pair.offset),
                isVideo: false,
                duration: 0
            )
        }
    }
}
