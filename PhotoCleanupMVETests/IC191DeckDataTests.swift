import Combine
import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-191：S1 重设计批 ③a——V1 卡片叠与页头的数据与接线（SPEC-S1 v12 第二节 `体积(r)`、`U` 与 `总占用`、
/// `占比(r)`、`页头已看`、`open`；规格先行，界面归页头卡与卡片叠卡）。
/// 1 行体积与占比：没有读口、表里缺一张、读口给 nil 都按未知；有表时体积 = 范围内之和、占比四舍五入；
///   刷新信号只让观察者重读、不写快照。
/// 2 页头派生：一级范围资产之并与范围数、`总占用`、`页头已看`（按日期取年之并、其余维度取表的键集、取不到为 nil）。
/// 3 展开态：初值 = 当前次序第一张、翻转排序不动、点卡改展开、对账与切维度后回落、年页初值与回落；
///   点卡不让状态机发布、不写快照。
/// 4 源码落位。
///
/// **夹具驱动**：字节表与看过集合是注入的夹具；界面与真机观感归后续卡，本卡无人工判定项。
final class IC191DeckDataTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let headerPath = "PhotoCleanupMVE/Core/S1HeaderSummary.swift"
    private static let openPath = "PhotoCleanupMVE/Core/S1OpenCardState.swift"
    /// 四张资产共 1000 字节：a8 100、a3b 200、a3a 300、b1 400。
    private static let fullTable = S1AssetByteCountTable(
        byteCountByAssetID: ["a8": 100, "a3b": 200, "a3a": 300, "b1": 400]
    )

    // MARK: - 断言 1：行体积与占比

    func testIC191A_RowVolumesFollowTheScanTable() {
        let machine = makeTreeMachine()
        XCTAssertEqual(machine.rangeRows.map(\.id), ["y2026", "m2026-08", "m2026-03", "y2024", "m2024-01"])
        // 未注入读口：全部未知。
        XCTAssertEqual(machine.rangeRows.map(\.byteCount), [nil, nil, nil, nil, nil])
        XCTAssertEqual(machine.rangeRows.map(\.sharePercent), [nil, nil, nil, nil, nil])

        var table: S1AssetByteCountTable? = Self.fullTable
        machine.byteCountTableProvider = { table }
        // 有表：体积 = 范围内之和（年 = 各月之和），占比 = 体积 ÷ 表内之和、四舍五入。
        XCTAssertEqual(machine.rangeRows.map(\.byteCount), [600, 100, 500, 400, 400])
        XCTAssertEqual(machine.rangeRows.map(\.sharePercent), [60, 10, 50, 40, 40])
        // 其余列不受影响。
        XCTAssertEqual(machine.rangeRows.map(\.totalAssetCount), [3, 1, 2, 1, 1])
        XCTAssertEqual(machine.rangeRows.map(\.childCount), [2, 0, 0, 1, 0])

        // 表里缺一张（扫描完成之后才新增的）：它所在的月与年未知、占比位也不给，其余照常；占比的分母是表内之和。
        table = S1AssetByteCountTable(byteCountByAssetID: ["a8": 100, "a3b": 200, "b1": 300])
        XCTAssertEqual(machine.rangeRows.map(\.byteCount), [nil, 100, nil, 300, 300])
        XCTAssertEqual(machine.rangeRows.map(\.sharePercent), [nil, 17, nil, 50, 50])

        // 读口给 nil（当前一遍未完成或失败）：全部未知。
        table = nil
        XCTAssertEqual(machine.rangeRows.map(\.byteCount), [nil, nil, nil, nil, nil])
        XCTAssertEqual(machine.rangeRows.map(\.sharePercent), [nil, nil, nil, nil, nil])

        // 刷新信号：只让观察者重读一次，不写会话快照、不改状态。
        var writes = 0
        machine.persistenceSink = { _ in writes += 1 }
        var willChange = 0
        let subscription = machine.objectWillChange.sink { _ in willChange += 1 }
        machine.noteByteCountTableChanged()
        XCTAssertEqual(willChange, 1)
        XCTAssertEqual(writes, 0, "刷新信号不写会话快照")
        XCTAssertEqual(machine.state, .ready)
        subscription.cancel()
    }

    // MARK: - 断言 2：页头派生

    func testIC191B_HeaderSummaryDerivesTotalSeenAndCounts() {
        let years = treeRanges().filter { $0.parentRangeID == nil }
        // 按日期就绪：一级范围之并与范围数；页头已看 = 年之并里看过的、向下取（看过集合里库外的不算）。
        XCTAssertEqual(
            S1HeaderSummary.make(
                topLevelRanges: years, groupingDimension: .date, isReady: true,
                seenAssetIDs: ["a8", "b1", "x9"], table: Self.fullTable
            ),
            S1HeaderSummary(totalByteCount: 1_000, seenPercent: 50, assetCount: 4, topLevelRangeCount: 2)
        )
        // 没有字节表：总占用未知，按日期的已看照样按年之并。
        XCTAssertEqual(
            S1HeaderSummary.make(
                topLevelRanges: years, groupingDimension: .date, isReady: true,
                seenAssetIDs: ["a8"], table: nil
            ),
            S1HeaderSummary(totalByteCount: nil, seenPercent: 25, assetCount: 4, topLevelRangeCount: 2)
        )
        // 按日期未就绪：已看取不到；总占用只看表。
        XCTAssertEqual(
            S1HeaderSummary.make(
                topLevelRanges: [], groupingDimension: .date, isReady: false,
                seenAssetIDs: ["a8"], table: Self.fullTable
            ),
            S1HeaderSummary(totalByteCount: 1_000, seenPercent: nil, assetCount: 0, topLevelRangeCount: 0)
        )
        // 按日期就绪但没有范围（S1-3）：|U| = 0 得 0。
        XCTAssertEqual(
            S1HeaderSummary.make(
                topLevelRanges: [], groupingDimension: .date, isReady: true,
                seenAssetIDs: ["a8"], table: nil
            ),
            S1HeaderSummary(totalByteCount: nil, seenPercent: 0, assetCount: 0, topLevelRangeCount: 0)
        )
        // 相册维度：U 取表的键集（与维度无关）；副行前段取一级之并，相册重叠只计一次；没有表时已看取不到。
        let albums = [
            S1Range(id: "alb1", displayName: "A", assetIDsNewestFirst: ["a8", "a3b"]),
            S1Range(id: "alb2", displayName: "B", assetIDsNewestFirst: ["a3b", "b1"])
        ]
        XCTAssertEqual(
            S1HeaderSummary.make(
                topLevelRanges: albums, groupingDimension: .album, isReady: true,
                seenAssetIDs: ["a3b", "x9"], table: Self.fullTable
            ),
            S1HeaderSummary(totalByteCount: 1_000, seenPercent: 25, assetCount: 3, topLevelRangeCount: 2)
        )
        XCTAssertEqual(
            S1HeaderSummary.make(
                topLevelRanges: albums, groupingDimension: .album, isReady: true,
                seenAssetIDs: ["a3b"], table: nil
            ),
            S1HeaderSummary(totalByteCount: nil, seenPercent: nil, assetCount: 3, topLevelRangeCount: 2)
        )
        // 取整：向下取、钳 0～100、总数 0 得 0。
        XCTAssertEqual(S1HeaderSummary.percent(seen: 2, total: 3), 66)
        XCTAssertEqual(S1HeaderSummary.percent(seen: 3, total: 3), 100)
        XCTAssertEqual(S1HeaderSummary.percent(seen: 5, total: 3), 100)
        XCTAssertEqual(S1HeaderSummary.percent(seen: 0, total: 0), 0)

        // 状态机：看过集合与字节表都从注入读口来。
        let machine = makeTreeMachine()
        machine.seenAssetIDsProvider = { ["a3a", "a3b", "a8"] }
        machine.byteCountTableProvider = { Self.fullTable }
        XCTAssertEqual(
            machine.headerSummary,
            S1HeaderSummary(totalByteCount: 1_000, seenPercent: 75, assetCount: 4, topLevelRangeCount: 2)
        )
        // 翻转排序不改页头数据。
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(machine.headerSummary.seenPercent, 75)
        // 切到相册维度、尚未读完：U 改取表的键集（同一个数）；副行前段随 R(T) 归零。
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        XCTAssertEqual(
            machine.headerSummary,
            S1HeaderSummary(totalByteCount: 1_000, seenPercent: 75, assetCount: 0, topLevelRangeCount: 0)
        )
        machine.byteCountTableProvider = { nil }
        XCTAssertEqual(
            machine.headerSummary,
            S1HeaderSummary(totalByteCount: nil, seenPercent: nil, assetCount: 0, topLevelRangeCount: 0)
        )
    }

    // MARK: - 断言 3：展开态

    func testIC191C_OpenCardsFollowTheOpenRule() throws {
        let machine = makeTreeMachine()
        var writes = 0
        machine.persistenceSink = { _ in writes += 1 }
        let cards = machine.openCards

        // 初值 = 当前次序的第一张；年页不在前。
        XCTAssertEqual(machine.listCardRangeIDs, ["y2026", "y2024"])
        XCTAssertEqual(cards.listRangeID, "y2026")
        XCTAssertNil(cards.yearPageRangeID)
        // 翻转排序：次序变了，所指的卡仍在即不变（不跟着「第一张」跑）。
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(machine.listCardRangeIDs, ["y2024", "y2026"])
        XCTAssertEqual(cards.listRangeID, "y2026")

        // 点收起的卡即展开它；月卡与未知范围不是列表页的卡。点卡只让展开态对象发布：状态机不发布、不写快照。
        var machineChanges = 0
        var openChanges = 0
        let machineSubscription = machine.objectWillChange.sink { _ in machineChanges += 1 }
        let openSubscription = cards.objectWillChange.sink { _ in openChanges += 1 }
        let writesBefore = writes
        XCTAssertTrue(machine.openListCard("y2024"))
        XCTAssertEqual(cards.listRangeID, "y2024")
        XCTAssertTrue(machine.openListCard("y2024"), "点已展开的卡：照常成功")
        XCTAssertFalse(machine.openListCard("m2026-08"))
        XCTAssertFalse(machine.openListCard("nope"))
        XCTAssertEqual(cards.listRangeID, "y2024")
        XCTAssertEqual(openChanges, 1, "值没变不写")
        XCTAssertEqual(machineChanges, 0)
        XCTAssertEqual(writes, writesBefore)
        machineSubscription.cancel()
        openSubscription.cancel()

        // 年页：推入时取初值 = 当前次序下第一张月卡（此时最旧在前）；点月卡改展开；别处的卡不收。
        XCTAssertTrue(machine.presentYearPage("y2026"))
        XCTAssertEqual(machine.yearPageCardRangeIDs(of: "y2026"), ["m2026-03", "m2026-08"])
        XCTAssertEqual(cards.yearPageRangeID, "m2026-03")
        XCTAssertTrue(machine.openYearPageCard("m2026-08"))
        XCTAssertEqual(cards.yearPageRangeID, "m2026-08")
        XCTAssertFalse(machine.openYearPageCard("m2024-01"))
        XCTAssertFalse(machine.openYearPageCard("y2026"))
        XCTAssertEqual(cards.listRangeID, "y2024", "年页点卡不动列表页")

        // 遮挡期间（S2 在前）两页都保留、点卡不收。
        machine.presentObscuration()
        XCTAssertFalse(machine.openListCard("y2026"))
        XCTAssertFalse(machine.openYearPageCard("m2026-03"))
        XCTAssertEqual(cards.listRangeID, "y2024")
        XCTAssertEqual(cards.yearPageRangeID, "m2026-08")
        machine.dismissObscuration()

        // 对账：所指的卡仍在不变；所指的月消失则回落到第一张月卡。
        XCTAssertTrue(machine.reconcile(with: .success(treeRanges())))
        XCTAssertEqual(cards.listRangeID, "y2024")
        XCTAssertEqual(cards.yearPageRangeID, "m2026-08")
        XCTAssertTrue(machine.reconcile(with: .success(withoutAugust())))
        XCTAssertEqual(machine.presentedYearRangeID, "y2026")
        XCTAssertEqual(cards.yearPageRangeID, "m2026-03")
        XCTAssertEqual(cards.listRangeID, "y2024")

        // 年页返回：年页展开态清空；下次推入按当时的排序重新取初值。
        machine.dismissYearPage()
        XCTAssertNil(cards.yearPageRangeID)
        XCTAssertTrue(machine.reconcile(with: .success(treeRanges())))
        XCTAssertTrue(machine.switchSortOrder(to: .newestFirst))
        XCTAssertNil(cards.yearPageRangeID, "年页不在前时对账与翻转都不给年页展开态")
        XCTAssertTrue(machine.presentYearPage("y2026"))
        XCTAssertEqual(cards.yearPageRangeID, "m2026-08")

        // 列表页所指的年消失：回落到第一张；年页所在的年还在即不动。
        let only2026 = treeRanges().filter { $0.id != "y2024" && $0.parentRangeID != "y2024" }
        XCTAssertTrue(machine.reconcile(with: .success(only2026)))
        XCTAssertEqual(cards.listRangeID, "y2026")
        XCTAssertEqual(cards.yearPageRangeID, "m2026-08")

        // 切维度：R(T) 归空即没有卡、年页随之清；读到新范围后取第一张；相册维度没有年页。
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        XCTAssertNil(cards.listRangeID)
        XCTAssertNil(cards.yearPageRangeID)
        XCTAssertFalse(machine.openListCard("y2026"), "加载中")
        let request = try XCTUnwrap(machine.currentReadRequest)
        let albums = [
            S1Range(id: "alb1", displayName: "A", assetIDsNewestFirst: ["a8", "a3b"]),
            S1Range(id: "alb2", displayName: "B", assetIDsNewestFirst: ["a3b", "b1"])
        ]
        XCTAssertTrue(machine.completeRangeRead(.success(albums), for: request))
        XCTAssertEqual(cards.listRangeID, "alb1")
        XCTAssertTrue(machine.openListCard("alb2"))
        XCTAssertEqual(cards.listRangeID, "alb2")
        XCTAssertFalse(machine.openYearPageCard("alb1"), "相册维度没有年页")
        XCTAssertNil(cards.yearPageRangeID)

        // 纯规则：所指的卡仍在即不变，否则第一张，没有卡为 nil。
        XCTAssertEqual(S1OpenCardState.resolved("b", among: ["a", "b"]), "b")
        XCTAssertEqual(S1OpenCardState.resolved("z", among: ["a", "b"]), "a")
        XCTAssertEqual(S1OpenCardState.resolved(nil, among: ["a", "b"]), "a")
        XCTAssertNil(S1OpenCardState.resolved("a", among: []))
    }

    // MARK: - 断言 4：源码落位

    func testIC191D_SourceWiring() throws {
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        for (needle, expected) in [
            ("var byteCountTableProvider: (() -> S1AssetByteCountTable?)?", 1),
            ("byteCountTableProvider?()", 2),
            ("func noteByteCountTableChanged() {", 1),
            ("objectWillChange.send()", 1),
            ("var headerSummary: S1HeaderSummary {", 1),
            ("let openCards = S1OpenCardState()", 1),
            ("openCards.setListRangeID(", 2),
            ("openCards.setYearPageRangeID(", 5),
            ("func openListCard(_ rangeID: String) -> Bool {", 1),
            ("func openYearPageCard(_ rangeID: String) -> Bool {", 1),
            ("private func resolveOpenCards() {", 1),
            ("resolveOpenCards()", 2),
            // 既有钉子：不加 `didSet`、不发快照、不碰待删；看过集合多一处读（页头），年页身份多两处读（展开态）。
            ("publishSnapshotIfChanged()", 6),
            ("didSet", 4),
            ("setMarked(", 3),
            ("applyPendingDeletionDiff(", 3),
            ("seenAssetIDsProvider?() ?? []", 4),
            ("presentedYearRangeID", 7)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: machine), expected, needle)
        }
        let row = try XCTUnwrap(slice(machine, from: "struct S1RangeRow: Identifiable, Equatable, Sendable {", to: "let childCount: Int"))
        XCTAssertEqual(occurrences(of: "let byteCount: Int64?", in: row), 1)
        XCTAssertEqual(occurrences(of: "let sharePercent: Int?", in: row), 1)
        let rows = try XCTUnwrap(slice(machine, from: "var rangeRows: [S1RangeRow] {", to: "func processedAssetIDs(for rangeID: String) -> Set<String> {"))
        XCTAssertEqual(occurrences(of: "byteCountTableProvider?()", in: rows), 1, "每次求值只取一次表")
        XCTAssertEqual(occurrences(of: "table?.volume(of: range)", in: rows), 1)
        // `ranges` 的 didSet：先核年页身份，再回落展开卡。
        let observer = try XCTUnwrap(slice(machine, from: "@Published private(set) var ranges: [S1Range] = [] {", to: "@Published private(set) var readFailure"))
        let prune = try XCTUnwrap(observer.range(of: "pruneYearPageIfNeeded()"))
        let resolve = try XCTUnwrap(observer.range(of: "resolveOpenCards()"))
        XCTAssertLessThan(prune.lowerBound, resolve.lowerBound)
        // 推入年页取初值在身份写入之后。
        let present = try XCTUnwrap(slice(machine, from: "func presentYearPage(_ rangeID: String) -> Bool {", to: "func dismissYearPage() {"))
        let identity = try XCTUnwrap(present.range(of: "presentedYearRangeID = rangeID"))
        let initial = try XCTUnwrap(present.range(of: "openCards.setYearPageRangeID(yearPageCardRangeIDs(of: rangeID).first)"))
        XCTAssertLessThan(identity.lowerBound, initial.lowerBound)

        // App：读口接到扫描服务，刷新调用追加在既有那只快照回调末尾（仍只一处赋值），出现时补一次。
        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "s1Machine.byteCountTableProvider = {", in: app), 1)
        XCTAssertEqual(occurrences(of: "provider?.assetByteCountTable()", in: app), 1)
        XCTAssertEqual(occurrences(of: "noteByteCountTableChanged()", in: app), 2)
        XCTAssertEqual(occurrences(of: "onSnapshotDidChange", in: app), 1)
        let callback = try XCTUnwrap(slice(app, from: "provider.onSnapshotDidChange = {", to: "s1Machine?.noteByteCountTableChanged()"))
        XCTAssertEqual(occurrences(of: "weak s1Machine", in: callback), 1)
        XCTAssertEqual(occurrences(of: "machine.handle(event)", in: callback), 1)
        // 接线在 App 的前提：协调器只在路由离开 tab 容器那一支时装新机器（启动两处在 `.loading`、S5 离开一处在
        // `.completion`），装完路由回到容器、`.onAppear` 用新机器重接。新增装机器的路径会让这两条变。
        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "installS1Session(", in: coordinator), 6)
        XCTAssertEqual(occurrences(of: "s1Machine = machine", in: coordinator), 1)

        // 两个 Core 新文件：只依赖 Foundation（展开态另要 Combine），不碰 PhotoKit、不引用 S0 类型、不取文案。
        let headerRaw = try XCTUnwrap(sourceText(Self.headerPath))
        let header = try XCTUnwrap(strippedSource(Self.headerPath))
        XCTAssertEqual(occurrences(of: "import ", in: headerRaw), 1)
        XCTAssertEqual(occurrences(of: "import Foundation", in: headerRaw), 1)
        XCTAssertEqual(occurrences(of: "struct S1HeaderSummary: Equatable, Sendable {", in: header), 1)
        let openRaw = try XCTUnwrap(sourceText(Self.openPath))
        let openSource = try XCTUnwrap(strippedSource(Self.openPath))
        XCTAssertEqual(occurrences(of: "import ", in: openRaw), 2)
        XCTAssertEqual(occurrences(of: "import Combine", in: openRaw), 1)
        XCTAssertEqual(occurrences(of: "final class S1OpenCardState: ObservableObject {", in: openSource), 1)
        XCTAssertEqual(occurrences(of: "@Published private(set) var", in: openSource), 2)
        for text in [header, openSource] {
            for needle in ["Photos", "PHAsset", "S0", "L10n.", "@MainActor"] {
                XCTAssertEqual(occurrences(of: needle, in: text), 0, needle)
            }
        }
        // 展开态只经状态机写入：产品里调两个写方法的只有状态机（与声明它们的文件）。
        let writers = try productSources()
            .filter { $0.value.contains("setListRangeID(") || $0.value.contains("setYearPageRangeID(") }
            .keys
            .sorted()
        XCTAssertEqual(writers, ["S1OpenCardState.swift", "S1StateMachine.swift"])
    }

    // MARK: - 夹具

    private func makeTreeMachine() -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-ic191"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        guard let request = machine.currentReadRequest else {
            XCTFail("fresh machine has no read request")
            return machine
        }
        XCTAssertTrue(machine.completeRangeRead(.success(treeRanges()), for: request))
        return machine
    }

    private func treeRanges() -> [S1Range] {
        [
            S1Range(id: "y2026", displayName: "2026", assetIDsNewestFirst: ["a8", "a3b", "a3a"]),
            S1Range(id: "m2026-08", displayName: "2026-08", assetIDsNewestFirst: ["a8"], parentRangeID: "y2026"),
            S1Range(id: "m2026-03", displayName: "2026-03", assetIDsNewestFirst: ["a3b", "a3a"], parentRangeID: "y2026"),
            S1Range(id: "y2024", displayName: "2024", assetIDsNewestFirst: ["b1"]),
            S1Range(id: "m2024-01", displayName: "2024-01", assetIDsNewestFirst: ["b1"], parentRangeID: "y2024")
        ]
    }

    /// 2026 年只剩 3 月（8 月那张从库里消失）。
    private func withoutAugust() -> [S1Range] {
        [
            S1Range(id: "y2026", displayName: "2026", assetIDsNewestFirst: ["a3b", "a3a"]),
            S1Range(id: "m2026-03", displayName: "2026-03", assetIDsNewestFirst: ["a3b", "a3a"], parentRangeID: "y2026"),
            S1Range(id: "y2024", displayName: "2024", assetIDsNewestFirst: ["b1"]),
            S1Range(id: "m2024-01", displayName: "2024-01", assetIDsNewestFirst: ["b1"], parentRangeID: "y2024")
        ]
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

    /// 产品目录下全部 `.swift`，按文件名剔注释与字符串内容（被查的文件名在产品目录里唯一）。
    private func productSources() throws -> [String: String] {
        let root = repoRoot().appendingPathComponent(Self.productRoot)
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [String: String] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            result[url.lastPathComponent] = stripped(source)
        }
        return result
    }

    private func strippedSource(_ relativePath: String) -> String? {
        sourceText(relativePath).map { stripped($0) }
    }

    /// 剔掉 `//` 注释与字符串字面量内容。
    private func stripped(_ source: String) -> String {
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
