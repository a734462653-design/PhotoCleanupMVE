import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-178：「逐张整理」范围列表 (i) 年卡叠 → 年页（Decision_log 第 205 条第二节第 1 条；R2 画布 `i_s1`／`i_year_page`）。
///
/// 断言 2 钉年页身份在状态机里的守卫与生命周期（不入档、切维度清、对账后年消失清、S2 遮挡期间保留、不改状态与
/// 列表数据），4 钉源码落位（S1View 的 `NavigationStack` + 两只视图、旧列表层退役、IC177 计数、状态机加法、新文件纪律）。
/// IC-193：断言 1（旧叠口径）、3（五十个旧登记值）、5（七条 key，其中一条退役）随 V1 卡片叠整删，仍成立的断言与两张
/// 新文件计数表移入 `IC193V1DeckTests`（IC-184／IC-192 先例）。卡片叠的观感、推入动画与封面取图归真机。
final class IC178DeckListTests: XCTestCase {
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let cardsPath = "PhotoCleanupMVE/Features/S1/S1DeckCards.swift"
    private static let yearPagePath = "PhotoCleanupMVE/Features/S1/S1YearPageView.swift"
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    private static let dynamicNeedles = [
        "systemGroupedBackground", "secondarySystemGroupedBackground", "secondarySystemFill",
        "tertiaryLabel", "accentColor", "systemRed", "systemGreen", "systemOrange",
        "Color.primary", "Color.secondary", "uiColor: .separator", "Color(uiColor:", "systemBackground",
        "userInterfaceStyle", "dynamicColor(", "preferredColorScheme"
    ]

    // MARK: - 断言 2：年页身份在状态机里

    func testIC178B_YearPageIdentityLivesInMachineWithGuards() throws {
        let machine = makeTreeMachine()
        var writes = 0
        machine.persistenceSink = { _ in writes += 1 }
        let rowsBefore = machine.rangeRows

        XCTAssertNil(machine.presentedYearRangeID, "默认不在年页")
        XCTAssertFalse(machine.presentYearPage("m2026-08"), "月不是一级节点")
        XCTAssertFalse(machine.presentYearPage("nope"), "未知范围")
        XCTAssertNil(machine.presentedYearRangeID)
        XCTAssertTrue(machine.presentYearPage("y2026"))
        XCTAssertEqual(machine.presentedYearRangeID, "y2026")
        XCTAssertEqual(machine.state, .ready, "进年页不改状态")
        XCTAssertEqual(machine.rangeRows, rowsBefore, "进年页不改列表数据")
        XCTAssertEqual(machine.groupingDimension, .date)
        XCTAssertEqual(writes, 0, "年页身份不入档")
        XCTAssertTrue(machine.presentYearPage("y2024"), "换一年直接替换")
        XCTAssertEqual(machine.presentedYearRangeID, "y2024")
        machine.dismissYearPage()
        XCTAssertNil(machine.presentedYearRangeID)
        machine.dismissYearPage()
        XCTAssertNil(machine.presentedYearRangeID, "重复返回无副作用")
        XCTAssertEqual(writes, 0)

        // 回到年页（同页展开／收起 API 已随 IC-184 退役）。
        XCTAssertTrue(machine.presentYearPage("y2026"))

        // S2 遮挡期间保留（进 S2 再回来仍在年页）；遮挡中不能切年页、不能返回到别处。
        machine.presentObscuration()
        XCTAssertEqual(machine.presentedYearRangeID, "y2026")
        XCTAssertFalse(machine.presentYearPage("y2024"))
        XCTAssertEqual(machine.presentedYearRangeID, "y2026")
        machine.dismissObscuration()

        // 对账后年还在：留；年消失：清（`ranges` 每次被替换都过一遍）。
        XCTAssertTrue(machine.reconcile(with: .success(treeRanges())))
        XCTAssertEqual(machine.presentedYearRangeID, "y2026")
        let without2026 = treeRanges().filter { $0.id != "y2026" && $0.parentRangeID != "y2026" }
        XCTAssertTrue(machine.reconcile(with: .success(without2026)))
        XCTAssertNil(machine.presentedYearRangeID, "年在对账后消失即弹回列表")
        XCTAssertEqual(machine.state, .ready)

        // 切维度：`ranges` 归空、回到 loading，身份随之清；加载中与非日期维度都进不了年页。
        XCTAssertTrue(machine.presentYearPage("y2024"))
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        XCTAssertNil(machine.presentedYearRangeID)
        XCTAssertEqual(machine.state, .loading)
        XCTAssertFalse(machine.presentYearPage("y2024"), "加载中")
        let albumRequest = try XCTUnwrap(machine.currentReadRequest)
        let albums = [S1Range(id: "alb", displayName: "Album", assetIDsNewestFirst: ["z1", "z2"])]
        XCTAssertTrue(machine.completeRangeRead(.success(albums), for: albumRequest))
        XCTAssertEqual(machine.state, .ready)
        // 接 sink 后首次对账（不留基准）、切维度、读到新范围名各写一次快照——那是既有出口；年页身份的进出从未触发写出。
        let writesAfterSwitch = writes
        XCTAssertGreaterThanOrEqual(writesAfterSwitch, 1)
        XCTAssertFalse(machine.presentYearPage("alb"), "相册维度没有年页")
        XCTAssertNil(machine.presentedYearRangeID)
        machine.dismissYearPage()
        XCTAssertEqual(writes, writesAfterSwitch, "年页身份不入档")
    }

    // MARK: - 断言 4：源码落位

    func testIC178D_SourceWiringAndDiscipline() throws {
        // S1View：列表本体换成两只新视图；IC-192 起页头换 V1（`S1PageHeader.swift`）、两只自绘菜单退役，计数随之改。
        let s1 = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        let s1Raw = try XCTUnwrap(sourceText(Self.s1ViewPath))
        for (needle, expected) in [
            ("S1ChromeForeground.", 17),
            ("S0DeckMetrics.", 7),
            ("ProgressView()", 1),
            ("ProgressView().tint(S1ChromeForeground.secondary)", 1),
            ("colorScheme, .dark)", 5),
            ("s1ChromeGlassBackground(", 3),
            ("NavigationStack {", 1),
            (".navigationDestination(item: presentedYearRangeBinding)", 1),
            (".toolbar(.hidden, for: .navigationBar)", 1),
            (".toolbar(.hidden, for: .tabBar)", 0),
            ("S1DeckListView(", 1),
            ("S1YearPageView(", 1),
            ("machine.presentYearPage(", 1),
            ("machine.dismissYearPage()", 2),
            ("toggleYearExpansion", 0),
            ("LazyVStack", 0),
            ("S1RangeCardPresentation.", 0),
            ("S1YearStackStyle.", 0),
            ("S1RangeCoverThumbnail(", 0),
            ("private func enterRange(", 1),
            ("enterRange(", 4),
            (".overlay(alignment: .bottom) {", 1),
            ("S1TrashButtonAction.perform(", 2),
            ("S1RangeCoverPolicy.coverAssetID(", 1),
            ("ZStack(alignment: .top) {", 1),
            (".sheet(", 0),
            ("ScrollViewReader", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: s1), expected, needle)
        }
        for needle in Self.dynamicNeedles where needle != "preferredColorScheme" {
            XCTAssertEqual(occurrences(of: needle, in: s1), 0, needle)
        }
        XCTAssertGreaterThan(occurrences(of: ".primary", in: s1), 0)
        XCTAssertGreaterThan(occurrences(of: "Material", in: s1), 0)
        XCTAssertEqual(occurrences(of: ".retry()", in: s1Raw), 1)
        let s1View = try XCTUnwrap(slice(s1, from: "struct S1View: View {", to: "private enum S1PreviewData {"))
        let body = try XCTUnwrap(slice(s1View, from: "var body: some View {", to: "private var rootPage: some View {"))
        for (needle, expected) in [
            ("NavigationStack {", 1),
            ("feedbackToastOverlay", 1),
            ("allowsHitTesting(!machine.isObscured)", 1),
            ("yearPage(rangeID)", 1),
            ("readCurrentRequestIfPossible()", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: body), expected, "body " + needle)
        }
        let root = try XCTUnwrap(slice(s1View, from: "private var rootPage: some View {", to: "private var presentedYearRangeBinding: Binding<String?> {"))
        for needle in ["ZStack(alignment: .top) {", "stateContent", "pageHeader", "limitedBannerRow", "pageContainer {", "S1ChromeForeground.pageBackground"] {
            XCTAssertEqual(occurrences(of: needle, in: root), 1, "rootPage " + needle)
        }
        // IC-192：旧顶排列、菜单暗层与菜单层随 V1 页头退役。
        for needle in ["chromeColumn", "menuScrim", "menuOverlay"] {
            XCTAssertEqual(occurrences(of: needle, in: root), 0, "rootPage " + needle)
        }
        let list = try XCTUnwrap(slice(s1View, from: "private var rangeList: some View {", to: "private func enterRange("))
        for (needle, expected) in [
            ("S1DeckListView(", 1),
            ("S1YearPageView(", 1),
            ("kind: machine.groupingDimension == .date ? .years : .albums", 1),
            ("machine.presentYearPage(", 1),
            ("machine.dismissYearPage()", 1),
            ("S1TrashButtonAction.perform(", 1),
            ("S1RangeCoverPolicy.coverAssetID(", 1),
            ("enterRange(", 3),
            ("S1ChromeForeground.", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: list), expected, "list " + needle)
        }

        // 状态机：只加不改——年页身份无快照 didSet，IC157 钉住的三个计数不变。
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        for (needle, expected) in [
            // IC-191：展开态回落与年页点卡各读一次年页身份，5 → 7；`ranges` 的 didSet 改为多行（先核年页、再回落展开卡）。
            ("presentedYearRangeID", 7),
            ("func presentYearPage(", 1),
            ("func dismissYearPage()", 1),
            ("func pruneYearPageIfNeeded()", 1),
            ("pruneYearPageIfNeeded()", 2),
            ("resolveOpenCards()", 2),
            ("didSet { publishSnapshotIfChanged() }", 3),
            ("didSet", 4),
            ("publishSnapshotIfChanged()", 6),
            ("setMarked(", 3),
            ("applyPendingDeletionDiff(", 3)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: machine), expected, needle)
        }

        // 新文件纪律：无裸文案、无系统材质、无动态外观、无导航栈、无 actor 标注、无 PhotoKit；色只走两张登记表。
        let cards = try XCTUnwrap(strippedSource(Self.cardsPath))
        let cardsRaw = try XCTUnwrap(sourceText(Self.cardsPath))
        let yearPage = try XCTUnwrap(strippedSource(Self.yearPagePath))
        let yearPageRaw = try XCTUnwrap(sourceText(Self.yearPagePath))
        for (label, stripped, raw) in [("cards", cards, cardsRaw), ("yearPage", yearPage, yearPageRaw)] {
            XCTAssertEqual(occurrences(of: "Text(\"", in: raw), 0, label)
            XCTAssertEqual(occurrences(of: "return \"", in: raw), 0, label)
            XCTAssertEqual(occurrences(of: "import ", in: raw), 1, label + " 只 import SwiftUI")
            for needle in Self.dynamicNeedles + ["Material", "colorScheme", "GlassEffectContainer", "NavigationStack", "@MainActor", "PHAsset", "import Photos", "S1RangeCardMetrics.", "S1YearStackStyle."] {
                XCTAssertEqual(occurrences(of: needle, in: stripped), 0, label + " " + needle)
            }
        }
        // IC-193：两张新文件计数表与 key 检查随 V1 卡片叠移入 `IC193V1DeckTests.testIC193D_SourceWiring`。
        XCTAssertEqual(occurrences(of: "\"s1.trash.accessibility\"", in: yearPageRaw), 0, "读屏 key 由 S0BasketEntryView 自带")
    }

    // MARK: - 夹具

    private func makeTreeMachine() -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-ic178"),
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

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start) else {
            return nil
        }
        let rest = text[startRange.upperBound...]
        guard let endRange = rest.range(of: end) else {
            return nil
        }
        return String(rest[..<endRange.lowerBound])
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
