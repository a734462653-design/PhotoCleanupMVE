import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-192：S1 重设计批 ③b——「逐张整理」V1 页头与系统 `Menu`（SPEC-S1 v12 第三节前言与四态页头、第六节第 3、4 部分、
/// 第十一节第 2d 部分页头段）。
/// 1 展示口径：四态的数值位（骨架／照常／不显示）、副行前段三种写法、待删篮段的显隐、维度与排序名。
/// 2 登记值：2d 页头段逐值与两个推导量；骨架与受限条间距（卡内暂登）。
/// 3 目录：新增八条、退役五条。
/// 4 源码落位：页头新文件的纪律与写法（系统 `Menu` + `Picker`、首页同款待删篮入口与人像圆钮、三只维度胶囊）、
///   S1View 只就绪时整页滚动、旧顶排与两只自绘菜单退役、列表让出滚动。
///
/// **夹具驱动**：只验口径与源码；页头观感、`Menu` 浅／深色、滚动与四态版式归真机。
final class IC192PageHeaderTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let headerPath = "PhotoCleanupMVE/Features/S1/S1PageHeader.swift"
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let cardsPath = "PhotoCleanupMVE/Features/S1/S1DeckCards.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    private static let newKeyValues: [(String, String)] = [
        ("s1.header.title", "逐张整理"),
        ("s1.header.total_label", "照片与视频占用"),
        ("s1.header.seen_label", "已看"),
        ("s1.header.subtitle.date", "{count} 张 · {years} 年"),
        ("s1.header.subtitle.album", "{count} 张 · {albums} 个相册"),
        ("s1.header.basket", "待删篮 {count} 张"),
        ("s1.header.confirm", "去确认"),
        ("s1.volume.counting", "统计中")
    ]
    private static let retiredKeys = [
        "s1.chrome.subtitle_format", "s1.dimension.accessibility", "s1.menu.dimension.date_hint",
        "s1.menu.dimension.album_hint", "s1.menu.dimension.unclassified_hint"
    ]
    private static let dynamicNeedles = [
        "systemGroupedBackground", "secondarySystemGroupedBackground", "secondarySystemFill",
        "tertiaryLabel", "accentColor", "systemRed", "systemGreen", "systemOrange",
        "Color.primary", "Color.secondary", "uiColor: .separator", "Color(uiColor:", "systemBackground",
        "userInterfaceStyle", "dynamicColor(", "preferredColorScheme"
    ]

    // MARK: - 断言 1：展示口径

    func testIC192A_PresentationFollowsStateAndDimension() {
        XCTAssertEqual(S1PageHeaderPresentation.valueMode(for: .loading), .skeleton)
        XCTAssertEqual(S1PageHeaderPresentation.valueMode(for: .ready), .values)
        XCTAssertEqual(S1PageHeaderPresentation.valueMode(for: .empty), .values)
        XCTAssertEqual(S1PageHeaderPresentation.valueMode(for: .failed), .hidden)

        let summary = S1HeaderSummary(totalByteCount: nil, seenPercent: nil, assetCount: 4, topLevelRangeCount: 2)
        XCTAssertEqual(S1PageHeaderPresentation.subtitleLeading(summary: summary, groupingDimension: .date), "4 张 · 2 年")
        XCTAssertEqual(S1PageHeaderPresentation.subtitleLeading(summary: summary, groupingDimension: .album), "4 张 · 2 个相册")
        XCTAssertEqual(S1PageHeaderPresentation.subtitleLeading(summary: summary, groupingDimension: .unclassified), "4 张")
        // S1-3：前段按当前维度计为零。
        let empty = S1HeaderSummary(totalByteCount: nil, seenPercent: 0, assetCount: 0, topLevelRangeCount: 0)
        XCTAssertEqual(S1PageHeaderPresentation.subtitleLeading(summary: empty, groupingDimension: .date), "0 张 · 0 年")

        XCTAssertFalse(S1PageHeaderPresentation.showsBasketSegment(badgeCount: 0))
        XCTAssertTrue(S1PageHeaderPresentation.showsBasketSegment(badgeCount: 3))

        XCTAssertEqual(S1PageHeaderPresentation.dimensionTitle(.date), "按日期")
        XCTAssertEqual(S1PageHeaderPresentation.dimensionTitle(.album), "相册")
        XCTAssertEqual(S1PageHeaderPresentation.dimensionTitle(.unclassified), "未分类")
        XCTAssertEqual(S1PageHeaderPresentation.sortTitle(.newestFirst), "最新在前")
        XCTAssertEqual(S1PageHeaderPresentation.sortTitle(.oldestFirst), "最旧在前")

        // 四类件同用顶排模型：加载中排序钮／待删篮／人像圆钮降 40% 不可触发，维度胶囊不可触发。
        let loading = S1ChromeBarModel.make(state: .loading, badgeCount: 3)
        XCTAssertFalse(loading.controlsEnabled)
        XCTAssertEqual(loading.controlsOpacity, 0.4)
        XCTAssertFalse(loading.trashEnabled)
        let failed = S1ChromeBarModel.make(state: .failed, badgeCount: 3)
        XCTAssertTrue(failed.controlsEnabled)
        XCTAssertTrue(failed.trashEnabled, "读取失败不影响其他范围既有选择的提交")
    }

    // MARK: - 断言 2：登记值

    func testIC192B_MetricsMatchSpec2dHeader() {
        typealias M = S1PageHeaderMetrics
        XCTAssertEqual(M.titleFontSize, 17)
        XCTAssertEqual(M.titleKerning, 0.2)
        XCTAssertEqual(M.buttonSpacing, 10)
        XCTAssertEqual(M.heroTopFromChromeBottom, 14)
        XCTAssertEqual(M.heroHorizontalInset, 20)
        XCTAssertEqual(M.heroLabelFontSize, 14.5)
        XCTAssertEqual(M.heroLabelOpacity, 0.66)
        XCTAssertEqual(M.heroValueFontSize, 56)
        XCTAssertEqual(M.heroValueKerning, -2.4)
        XCTAssertEqual(M.heroUnitFontSize, 26)
        XCTAssertEqual(M.heroUnitKerning, -0.6)
        XCTAssertEqual(M.heroUnitOpacity, 0.72)
        XCTAssertEqual(M.heroUnitSpacing, 6)
        XCTAssertEqual(M.seenLabelFontSize, 12.5)
        XCTAssertEqual(M.seenLabelOpacity, 0.48)
        XCTAssertEqual(M.seenValueFontSize, 22)
        XCTAssertEqual(M.seenValueKerning, -0.6)
        XCTAssertEqual(M.seenPercentFontSize, 13)
        XCTAssertEqual(M.seenPercentSpacing, 2)
        XCTAssertEqual(M.seenBlockBottomPadding, 6)
        XCTAssertEqual(M.subtitleTopFromChromeBottom, 108)
        XCTAssertEqual(M.subtitleFontSize, 12.5)
        XCTAssertEqual(M.subtitleOpacity, 0.48)
        XCTAssertEqual(M.subtitleItemSpacing, 6)
        XCTAssertEqual(M.confirmLeadingSpacing, 4)
        XCTAssertEqual(M.chipTopFromChromeBottom, 134)
        XCTAssertEqual(M.chipHeight, 32)
        XCTAssertEqual(M.chipHorizontalPadding, 13)
        XCTAssertEqual(M.chipSpacing, 8)
        XCTAssertEqual(M.chipFontSize, 13.5)
        XCTAssertEqual(M.chipUnselectedTextOpacity, 0.78)
        XCTAssertEqual(M.chipUnselectedFillOpacity, 0.09)
        XCTAssertEqual(M.deckTopFromChromeBottom, 180)
        // 推导量：页头块高 = 胶囊顶 + 胶囊高；卡叠与之相隔 = 卡叠顶 − 页头块高。
        XCTAssertEqual(M.headerBlockHeight, 166)
        XCTAssertEqual(M.deckTopSpacing, 14)
        // 卡内暂登。
        XCTAssertEqual(M.bannerTopSpacing, 14)
        XCTAssertEqual(M.skeletonCornerRadius, 6)
        XCTAssertEqual(M.skeletonHeroWidth, 148)
        XCTAssertEqual(M.skeletonHeroHeight, 44)
        XCTAssertEqual(M.skeletonSeenWidth, 52)
        XCTAssertEqual(M.skeletonSeenHeight, 22)
        XCTAssertEqual(M.skeletonSubtitleWidth, 168)
        XCTAssertEqual(M.skeletonSubtitleHeight, 12)
        XCTAssertEqual(S1PageHeaderSymbol.separator, "·")
        // 顶排几何仍取 S1ChromeLayout（件间距 8 被首页与 S3 借用，V1 的 10 另立）。
        XCTAssertEqual(S1ChromeLayout.itemSpacing, 8)
        XCTAssertEqual(S1ChromeLayout.rowHeight, 44)
    }

    // MARK: - 断言 3：目录

    func testIC192C_CatalogAddsEightKeysAndRetiresFive() throws {
        let data = try XCTUnwrap(sourceText(Self.catalogPath)?.data(using: .utf8))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for (key, value) in Self.newKeyValues {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], key)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
            let zh = try XCTUnwrap(localizations["zh-Hans"] as? [String: Any], key)
            let unit = try XCTUnwrap(zh["stringUnit"] as? [String: Any], key)
            XCTAssertEqual(unit["value"] as? String, value, key)
            XCTAssertEqual(L10n.text(key), value, key)
        }
        for key in Self.retiredKeys {
            XCTAssertNil(strings[key], key)
        }
        // 借用的既有 key 仍在：未分类前段、维度名、排序名与读屏、人像圆钮读屏、待删篮入口读屏。
        for key in ["s1.range.total_count", "s1.dimension.date", "s1.dimension.album", "s1.dimension.unclassified",
                    "s1.sort.newest_first", "s1.sort.oldest_first", "s1.sort.accessibility", "s0.account.title",
                    "s1.trash.accessibility"] {
            XCTAssertNotNil(strings[key], key)
        }
        XCTAssertEqual(strings.keys.filter { $0.hasPrefix("s0.") }.count, 41, "s0. 不动")
        XCTAssertEqual(
            L10n.text("s1.header.basket", replacing: ["count": "3"]),
            "待删篮 3 张"
        )
    }

    // MARK: - 断言 4：源码落位

    func testIC192D_SourceWiring() throws {
        // 页头新文件：纪律与写法。
        let headerRaw = try XCTUnwrap(sourceText(Self.headerPath))
        let header = try XCTUnwrap(strippedSource(Self.headerPath))
        XCTAssertEqual(occurrences(of: "import ", in: headerRaw), 1)
        XCTAssertEqual(occurrences(of: "import SwiftUI", in: headerRaw), 1)
        XCTAssertEqual(occurrences(of: "Text(\"", in: headerRaw), 0)
        XCTAssertEqual(occurrences(of: "return \"", in: headerRaw), 0)
        for needle in ["Material", "colorScheme", "GlassEffectContainer", "NavigationStack", "@MainActor", "PHAsset",
                       "ScrollView", "S1StateMachine", "machine."] + Self.dynamicNeedles {
            XCTAssertEqual(occurrences(of: needle, in: header), 0, "header " + needle)
        }
        for (needle, expected) in [
            ("struct S1PageHeader: View {", 1),
            ("Menu {", 1),
            ("Picker(", 1),
            ("selection: sortOrder", 1),
            (".tag(S1SortOrder.newestFirst)", 1),
            (".tag(S1SortOrder.oldestFirst)", 1),
            ("S0DeckSymbol.sort", 1),
            ("S0BasketEntryView(style: .glass, count: badgeCount, action: onBasket)", 1),
            ("Button(action: onOpenAccount)", 1),
            ("S0DeckSymbol.account", 1),
            ("Button(action: onBasket)", 1),
            ("ForEach(S1GroupingDimension.allCases, id: \\.self)", 1),
            ("onSelectDimension(dimension)", 1),
            ("S0ByteCountSplit.split(", 1),
            ("S0DeckSymbol.percentSign", 1),
            ("s1ChromeCircleGlass()", 2),
            (".disabled(!chromeModel.controlsEnabled)", 4),
            (".opacity(chromeModel.controlsOpacity)", 3),
            (".disabled(!chromeModel.trashEnabled)", 1),
            ("S1PageHeaderPresentation.valueMode(for: state)", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: header), expected, "header " + needle)
        }
        XCTAssertEqual(occurrences(of: "L10n.text(\"s0.account.title\")", in: headerRaw), 1)
        XCTAssertEqual(occurrences(of: "L10n.text(\"s1.sort.accessibility\")", in: headerRaw), 2)
        for (key, _) in Self.newKeyValues where key != "s1.volume.counting" {
            XCTAssertEqual(occurrences(of: "\"" + key + "\"", in: headerRaw), 1, key)
        }
        XCTAssertEqual(occurrences(of: "\"s1.volume.counting\"", in: headerRaw), 2)
        let metrics = try XCTUnwrap(slice(header, from: "enum S1PageHeaderMetrics {", to: Self.newline + "}" + Self.newline))
        XCTAssertEqual(occurrences(of: "static let ", in: metrics), 41)
        XCTAssertEqual(occurrences(of: "static var ", in: metrics), 2)

        // S1View：页头换 V1，就绪才整页滚动；旧顶排、中胶囊、两只自绘菜单与维度提示退役。
        let s1 = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        let s1Raw = try XCTUnwrap(sourceText(Self.s1ViewPath))
        for retired in ["S1ChromeSubtitle", "S1ActiveMenu", "S1MenuStyle", "S1DimensionMenuHintModel", "activeMenu",
                        "chromeColumn", "chromeItems", "sortButton", "dimensionCapsule", "capsuleLabel", "trashButton",
                        "trashBadge", "menuScrim", "menuOverlay", "sortMenu", "dimensionMenu", "menuContainer",
                        "menuSeparator", "refreshDimensionHints", "albumHintRangeCount", "unclassifiedHintAssetCount",
                        "overlayTopOffset", "listTopOffset", "limitedListTopOffset", "bannerToListSpacing",
                        "capsuleChevronPointSize", "groupingTitle", "sortTitle"] {
            XCTAssertEqual(occurrences(of: retired, in: s1), 0, retired)
        }
        for (needle, expected) in [
            ("S1PageHeader(", 1),
            ("summary: machine.headerSummary", 1),
            ("machine.headerSummary", 1),
            ("onOpenAccount: {}", 1),
            ("sortOrderBinding", 2),
            ("machine.switchSortOrder(to: newValue)", 1),
            ("onBasket: openBasket", 1),
            ("onSelectDimension: selectDimension", 1),
            ("private func pageContainer<Content: View>(", 1),
            ("ScrollView {", 1),
            ("if machine.state == .ready {", 1),
            (".padding(.top, S1PageHeaderMetrics.deckTopSpacing)", 1),
            (".padding(.top, S1PageHeaderMetrics.bannerTopSpacing)", 1),
            ("S1TrashButtonAction.perform(", 2),
            ("readCurrentRequestIfPossible()", 4)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: s1), expected, "S1View " + needle)
        }
        XCTAssertEqual(occurrences(of: ".retry()", in: s1Raw), 1)
        let stateContent = try XCTUnwrap(slice(s1, from: "private var stateContent: some View {", to: "private var loadingState: some View {"))
        XCTAssertEqual(occurrences(of: ".padding(.top, S1PageHeaderMetrics.deckTopSpacing)", in: stateContent), 1)

        // 列表让出滚动：页面那只 `ScrollView` 负责滚动，列表按叠高占位。
        let cards = try XCTUnwrap(strippedSource(Self.cardsPath))
        let list = try XCTUnwrap(slice(cards, from: "struct S1DeckListView: View {", to: Self.newline + "}" + Self.newline))
        XCTAssertEqual(occurrences(of: "ScrollView", in: list), 0)
        // IC-193：叠高随展开态（V1）、底部留白退役（末卡延伸即留白）。
        XCTAssertEqual(occurrences(of: ".frame(height: S1DeckCardPresentation.stackHeight(count: rows.count, openIndex: openIndex))", in: list), 1)
        XCTAssertEqual(occurrences(of: "stackBottomPadding", in: list), 0)

        // 全产品：退役的四个类型名 0（新类型不复用）。
        let product = try productSources()
        for retired in ["S1ChromeSubtitle", "S1ActiveMenu", "S1MenuStyle", "S1DimensionMenuHintModel"] {
            XCTAssertEqual(product.values.reduce(0) { $0 + occurrences(of: retired, in: $1) }, 0, retired)
        }
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
