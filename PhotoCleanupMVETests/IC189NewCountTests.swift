import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-189 夹具时刻：自参考日期起 800 000 000 s 再偏移 `offset` 秒（文件级函数——存储属性初始化式里不能写 `Self.`）。
private func ic189At(_ offset: TimeInterval) -> Date {
    Date(timeIntervalSinceReferenceDate: 800_000_000 + offset)
}

/// IC-189：S1 重设计批第三张——「新增 N 张」的数据与派生量（SPEC-S1 v12 决策 45、第二节 `拍摄时间(a)`／`基线(r)`／`新增(r)`）。
/// 1 范围带逐张拍摄时间：新增 = 拍摄时间严格晚于基线、且不在看过集合里的张数；时间列缺失或与资产列不等长按无时间计 0；不依赖存储顺序。
/// 2 基线：月范围取自己与所属年两者离开时刻中较晚的，其余范围取自己的，都没有即无基线（0）；有月的年 = 各月之和，无月的年取自己。
/// 3 照片库读取：四类范围的时间列与资产列等长、同序、非增，逐张等于快照里的拍摄时间。
/// 4 协调器：离开时刻读口从看过档读（看过集合同源），行投影 `newAssetCount` 跟着变。
/// 5 源码落位：字段、读口、派生、注入与既有钉子。
///
/// **夹具驱动**：离开时刻由读口或预存的看过档给出，不经真实 S2 往返（陷阱 1）；界面接线归 V1 视图卡。
final class IC189NewCountTests: XCTestCase {
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let libraryPath = "PhotoCleanupMVE/Services/PhotoLibraryService.swift"

    private let year = S1Range(
        id: "year:1:2026:0",
        displayName: "2026年",
        assetIDsNewestFirst: ["a4", "a3", "a2", "a1", "b3", "b2", "b1"],
        creationDatesNewestFirst: [ic189At(400), ic189At(300), ic189At(200), ic189At(100), ic189At(-100), ic189At(-200), ic189At(-300)]
    )
    private let month9 = S1Range(
        id: "month:1:2026:9",
        displayName: "2026年9月",
        assetIDsNewestFirst: ["a4", "a3", "a2", "a1"],
        creationDatesNewestFirst: [ic189At(400), ic189At(300), ic189At(200), ic189At(100)],
        parentRangeID: "year:1:2026:0"
    )
    private let month8 = S1Range(
        id: "month:1:2026:8",
        displayName: "2026年8月",
        assetIDsNewestFirst: ["b3", "b2", "b1"],
        creationDatesNewestFirst: [ic189At(-100), ic189At(-200), ic189At(-300)],
        parentRangeID: "year:1:2026:0"
    )

    // MARK: - 断言 1：区间计数

    func testIC189A_RangeNewCountIsStrictlyLaterAndUnseen() {
        XCTAssertEqual(month9.newAssetCount(after: ic189At(200), excluding: []), 2)
        XCTAssertEqual(month9.newAssetCount(after: ic189At(200), excluding: ["a3", "elsewhere"]), 1)
        XCTAssertEqual(month9.newAssetCount(after: ic189At(0), excluding: []), 4)
        XCTAssertEqual(month9.newAssetCount(after: ic189At(1_000), excluding: []), 0)

        // 无时间（手造夹具、预览）与不等长：按无时间计 0。
        let undated = S1Range(id: "u", displayName: "u", assetIDsNewestFirst: ["p", "q"])
        XCTAssertEqual(undated.creationDatesNewestFirst, [])
        XCTAssertEqual(undated.newAssetCount(after: ic189At(-1_000), excluding: []), 0)
        let mismatched = S1Range(
            id: "m",
            displayName: "m",
            assetIDsNewestFirst: ["p", "q"],
            creationDatesNewestFirst: [ic189At(10)]
        )
        XCTAssertEqual(mismatched.newAssetCount(after: ic189At(-1_000), excluding: []), 0)

        // 不依赖存储顺序（整列扫描）。
        let unordered = S1Range(
            id: "o",
            displayName: "o",
            assetIDsNewestFirst: ["p", "q", "r"],
            creationDatesNewestFirst: [ic189At(-5), ic189At(5), ic189At(6)]
        )
        XCTAssertEqual(unordered.newAssetCount(after: ic189At(0), excluding: []), 2)
    }

    // MARK: - 断言 2：按范围取基线

    func testIC189B_BaselinePerRangeAndYearSumsMonths() throws {
        let machine = try makeReadyMachine(ranges: [year, month9, month8])
        XCTAssertEqual(newCounts(machine), [year.id: 0, month9.id: 0, month8.id: 0])
        XCTAssertNil(machine.newAssetBaseline(for: month9))

        // 9 月自己 +250、年 +150：9 月取较晚的 +250（a4、a3）；8 月没有自己的、取年的 +150（0 张）；
        // 年 = 各月之和 2——不是拿年自己的 +150 对全年算（那样是 3）。
        var leaveTimes: [String: Date] = [month9.id: ic189At(250), year.id: ic189At(150)]
        machine.leaveTimeProvider = { leaveTimes[$0] }
        XCTAssertEqual(machine.newAssetBaseline(for: month9), ic189At(250))
        XCTAssertEqual(machine.newAssetBaseline(for: month8), ic189At(150))
        XCTAssertEqual(machine.newAssetBaseline(for: year), ic189At(150))
        XCTAssertEqual(newCounts(machine), [year.id: 2, month9.id: 2, month8.id: 0])

        // 看过的不算。
        machine.seenAssetIDsProvider = { ["a4"] }
        XCTAssertEqual(newCounts(machine), [year.id: 1, month9.id: 1, month8.id: 0])

        // 年在 9 月之后又离开过一次（+350）：9 月取较晚的年 +350，只剩 a4、已看过。
        leaveTimes[year.id] = ic189At(350)
        XCTAssertEqual(machine.newAssetBaseline(for: month9), ic189At(350))
        XCTAssertEqual(newCounts(machine), [year.id: 0, month9.id: 0, month8.id: 0])
        machine.seenAssetIDsProvider = nil
        XCTAssertEqual(newCounts(machine), [year.id: 1, month9.id: 1, month8.id: 0])

        // 与排序无关；不存在的范围为 0。
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(newCounts(machine), [year.id: 1, month9.id: 1, month8.id: 0])
        XCTAssertEqual(machine.newAssetCount(for: "month:1:2026:1"), 0)

        // 没有月的范围（年页之外的一级范围，相册与未分类同一路径）取自己的基线。
        let lone = S1Range(
            id: "year:1:2025:0",
            displayName: "2025年",
            assetIDsNewestFirst: ["c2", "c1"],
            creationDatesNewestFirst: [ic189At(60), ic189At(-60)]
        )
        let loneMachine = try makeReadyMachine(ranges: [lone])
        XCTAssertEqual(loneMachine.newAssetCount(for: lone.id), 0)
        loneMachine.leaveTimeProvider = { $0 == lone.id ? ic189At(0) : nil }
        XCTAssertEqual(loneMachine.newAssetCount(for: lone.id), 1)
        XCTAssertEqual(newCounts(loneMachine), [lone.id: 1])
    }

    // MARK: - 断言 3：照片库读取带拍摄时间

    /// `PhotoLibraryService` 是 `@MainActor` 类（与仓内其它构造它的测试同写法）。
    @MainActor
    func testIC189C_ServiceCarriesCreationDatesInRangeOrder() throws {
        let day: TimeInterval = 86_400
        let snapshots = [
            S1PhotoAssetSnapshot(identifier: "s-1", creationDate: ic189At(0)),
            S1PhotoAssetSnapshot(identifier: "s-2", creationDate: ic189At(day)),
            S1PhotoAssetSnapshot(identifier: "s-3", creationDate: ic189At(40 * day)),
            S1PhotoAssetSnapshot(identifier: "s-4", creationDate: ic189At(40 * day)),
            S1PhotoAssetSnapshot(identifier: "s-5", creationDate: ic189At(70 * day))
        ]
        var dateByID: [String: Date] = [:]
        for snapshot in snapshots {
            dateByID[snapshot.identifier] = snapshot.creationDate
        }
        let box = IC127LibraryBox(assets: snapshots)
        let service = PhotoLibraryService(s1Source: box.source)
        for dimension in [S1GroupingDimension.date, .unclassified] {
            let ranges = try service.s1Ranges(groupedBy: dimension).get()
            XCTAssertFalse(ranges.isEmpty, dimension.rawValue)
            for range in ranges {
                XCTAssertEqual(range.creationDatesNewestFirst.count, range.assetIDsNewestFirst.count, range.id)
                XCTAssertEqual(range.creationDatesNewestFirst, range.assetIDsNewestFirst.compactMap { dateByID[$0] }, range.id)
                XCTAssertTrue(
                    zip(range.creationDatesNewestFirst, range.creationDatesNewestFirst.dropFirst()).allSatisfy { pair in pair.0 >= pair.1 },
                    range.id
                )
            }
        }
        let years = try service.s1Ranges(groupedBy: .date).get().filter { $0.parentRangeID == nil }
        XCTAssertEqual(years.reduce(0) { $0 + $1.creationDatesNewestFirst.count }, snapshots.count)
        // 桩的读取闭包对 `box` 是 `unowned` 引用：保证读完之前 `box` 不被提前释放。
        withExtendedLifetime(box) {}
    }

    // MARK: - 断言 4：协调器从看过档读离开时刻

    @MainActor
    func testIC189D_CoordinatorFeedsLeaveTimesFromSeenArchive() throws {
        let persistence = TestPersistenceIsolation.makePersistence()
        var archive = S1SeenArchive()
        archive.seenAssetIDs = ["a3"]
        archive.leaveTimeByRangeID = [month9.id: ic189At(150)]
        archive.hasMigratedLegacyProgress = true
        try persistence.saveS1SeenArchive(archive)

        let coordinator = CleanupCoordinator(persistence: persistence)
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-189D"))
        completeRead(coordinator, ranges: [year, month9, month8])
        let machine = try XCTUnwrap(coordinator.s1Machine)
        // 9 月基线 +150：a4、a3、a2 晚于基线，a3 已看过 → 2；8 月与年都没有基线 → 0；年 = 各月之和。
        XCTAssertEqual(machine.newAssetBaseline(for: month9), ic189At(150))
        XCTAssertNil(machine.newAssetBaseline(for: month8))
        XCTAssertEqual(newCounts(machine), [year.id: 2, month9.id: 2, month8.id: 0])
        XCTAssertEqual(coordinator.currentSeenArchive(), archive)
    }

    // MARK: - 断言 5：源码落位

    func testIC189E_SourceWiring() throws {
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        XCTAssertEqual(occurrences(of: "let creationDatesNewestFirst: [Date]", in: machine), 1)
        XCTAssertEqual(occurrences(of: "creationDatesNewestFirst: [Date] = []", in: machine), 1)
        XCTAssertEqual(occurrences(of: "func newAssetCount(after baseline: Date, excluding seenAssetIDs: Set<String>) -> Int {", in: machine), 1)
        XCTAssertEqual(occurrences(of: "var leaveTimeProvider: ((String) -> Date?)?", in: machine), 1)
        XCTAssertEqual(occurrences(of: "leaveTimeProvider?(", in: machine), 2)
        // IC-191：页头已看（`headerSummary`）也读看过集合，3 → 4。
        XCTAssertEqual(occurrences(of: "seenAssetIDsProvider?() ?? []", in: machine), 4)
        XCTAssertEqual(occurrences(of: "newAssetCount: newAssetCount(for: range.id)", in: machine), 1)
        let row = try XCTUnwrap(slice(machine, from: "struct S1RangeRow: Identifiable, Equatable, Sendable {", to: "let childCount: Int"))
        XCTAssertEqual(occurrences(of: "let newAssetCount: Int", in: row), 1)
        let rows = try XCTUnwrap(slice(machine, from: "var rangeRows: [S1RangeRow] {", to: "func processedAssetIDs(for rangeID: String) -> Set<String> {"))
        XCTAssertEqual(occurrences(of: "newAssetCount(for: range.id)", in: rows), 1)
        // 既有钉子不变：不加 `didSet`、不发快照、不碰待删。
        XCTAssertEqual(occurrences(of: "publishSnapshotIfChanged()", in: machine), 6)
        XCTAssertEqual(occurrences(of: "didSet", in: machine), 4)
        XCTAssertEqual(occurrences(of: "setMarked(", in: machine), 3)
        XCTAssertEqual(occurrences(of: "applyPendingDeletionDiff(", in: machine), 3)

        let library = try XCTUnwrap(strippedSource(Self.libraryPath))
        XCTAssertEqual(occurrences(of: "creationDatesNewestFirst:", in: library), 4)

        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "machine.leaveTimeProvider = {", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "currentSeenArchive().leaveTimeByRangeID[rangeID]", in: coordinator), 1)
        // IC-187／IC-188 的协调器钉子不变。
        XCTAssertEqual(occurrences(of: "machine.seenAssetIDsProvider = {", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "machine.legacyProgressMigration = {", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "recordS2Leave(", in: coordinator), 2)
        XCTAssertEqual(occurrences(of: "flushSeenArchive()", in: coordinator), 4)
        XCTAssertEqual(occurrences(of: "photoLibrary.s1RangeRead(", in: coordinator), 2)
    }

    // MARK: - 夹具

    private func makeReadyMachine(ranges: [S1Range]) throws -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-189"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = try XCTUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
        return machine
    }

    private func newCounts(_ machine: S1StateMachine) -> [String: Int] {
        var counts: [String: Int] = [:]
        for row in machine.rangeRows {
            counts[row.id] = row.newAssetCount
        }
        return counts
    }

    @MainActor
    private func completeRead(_ coordinator: CleanupCoordinator, ranges: [S1Range]) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
    }

    // MARK: - 工具（与既有测试同口径）

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.upperBound])
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceText(_ relativePath: String) -> String? {
        try? String(
            contentsOf: repoRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    /// 读源码并剔掉 `//` 注释与字符串字面量内容。
    private func strippedSource(_ relativePath: String) -> String? {
        guard let source = sourceText(relativePath) else {
            return nil
        }
        let newline = Character(UnicodeScalar(UInt8(10)))
        var output = ""
        var iterator = source.startIndex
        var inString = false
        while iterator < source.endIndex {
            let character = source[iterator]
            let next = source.index(after: iterator)
            if inString {
                if character == "\\" {
                    iterator = next < source.endIndex
                        ? source.index(after: next)
                        : source.endIndex
                    continue
                }
                if character == "\"" {
                    inString = false
                }
                iterator = next
                continue
            }
            if character == "\"" {
                inString = true
                iterator = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                while iterator < source.endIndex,
                      source[iterator] != newline {
                    iterator = source.index(after: iterator)
                }
                output.append(newline)
                continue
            }
            output.append(character)
            iterator = next
        }
        return output
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}
