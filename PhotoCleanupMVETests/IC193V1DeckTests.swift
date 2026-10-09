import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-193：S1 重设计批 ③c＋③d——「逐张整理」V1 卡片叠（列表页年卡与相册卡、年页月卡同一套）与年页标题区
/// （SPEC-S1 v12 第六节第 1、2 部分、第十一节第 2d 部分；裁定 `Tasks/PLAN-S1R-3-rulings-20261009.md` 第六节）。
/// 1 展示口径：可见高、卡高、上偏移、叠高随展开态；收起压暗中间档的位置；已看百分比与看完、进年页、胶囊显隐（由 IC178A
///   移入）；展开卡副文、按钮名与年页汇总行的拼接。
/// 2 登记值：2d 卡片叠与年页段逐值、两条推导恒等式、两处字面色、两个符号名。
/// 3 目录：新增六条、退役 `s1.yearPage.summary`、仍在用的旧 key（由 IC178E 移入）。
/// 4 源码落位：新卡与年页的写法（一只封面、不挂 `.id(isOpen)`、卡叠自己观察展开态、首页同一 spring）、S1View 的
///   两处接线、两张计数表（由 IC178D 移入）。
///
/// **夹具驱动**：只验口径与源码；卡片观感、展开动画、封面不重取与末卡延伸归真机。
final class IC193V1DeckTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let cardsPath = "PhotoCleanupMVE/Features/S1/S1DeckCards.swift"
    private static let yearPagePath = "PhotoCleanupMVE/Features/S1/S1YearPageView.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    private static let newKeyValues: [(String, String)] = [
        ("s1.deck.new", "新增 {count}"),
        ("s1.deck.new.open", "新增 {count} 张"),
        ("s1.deck.share", "占 {percent}%"),
        ("s1.deck.action.yearPage", "去清理"),
        ("s1.deck.action.organize", "去整理"),
        ("s1.yearPage.share", "占全部 {percent}%")
    ]
    /// 仍在用的既有 key（IC-178 起；IC178E 随 V1 整删后由本测试钉）。
    private static let keptKeyValues: [(String, String)] = [
        ("s1.deck.year.subtitle", "{count} 张 · {months} 个月"),
        ("s1.deck.pending", "待删 {count}"),
        ("s1.deck.seen", "已看 {percent}%"),
        ("s1.deck.done", "看完"),
        ("s1.yearPage.organizeAll", "整理整年"),
        ("s1.yearPage.back", "返回")
    ]

    // MARK: - 断言 1：展示口径

    func testIC193A_DeckPresentationRules() {
        typealias P = S1DeckCardPresentation
        XCTAssertEqual(P.visibleHeight(isOpen: true), 226)
        XCTAssertEqual(P.visibleHeight(isOpen: false), 70)
        XCTAssertEqual(P.cardHeight(index: 0, count: 3, isOpen: false), 104, "收起非末卡 = stripCardHeight")
        XCTAssertEqual(P.cardHeight(index: 0, count: 3, isOpen: true), 260, "展开非末卡 = openCardHeight")
        XCTAssertEqual(P.cardHeight(index: 2, count: 3, isOpen: false), 390, "末卡延伸 320")
        XCTAssertEqual(P.cardHeight(index: 2, count: 3, isOpen: true), 546)
        XCTAssertEqual(P.cardHeight(index: 0, count: 1, isOpen: true), 546, "只有一张：展开且延伸")
        XCTAssertNil(P.openIndex(of: nil, in: ["a", "b"]))
        XCTAssertEqual(P.openIndex(of: "b", in: ["a", "b"]), 1)
        XCTAssertNil(P.openIndex(of: "x", in: ["a", "b"]), "所指的卡不在这一叠")
        XCTAssertEqual(P.offset(index: 0, openIndex: 0), 0)
        XCTAssertEqual(P.offset(index: 1, openIndex: 0), 226)
        XCTAssertEqual(P.offset(index: 2, openIndex: 0), 296)
        XCTAssertEqual(P.offset(index: 2, openIndex: 1), 296, "前两张一收一展，与次序无关")
        XCTAssertEqual(P.offset(index: 3, openIndex: 1), 366)
        XCTAssertEqual(P.offset(index: 1, openIndex: nil), 70)
        XCTAssertEqual(P.stackHeight(count: 0, openIndex: nil), 0, "空叠")
        XCTAssertEqual(P.stackHeight(count: 1, openIndex: 0), 546)
        XCTAssertEqual(P.stackHeight(count: 3, openIndex: nil), 530)
        XCTAssertEqual(P.stackHeight(count: 7, openIndex: 0), 966, "R3 七年、第一张展开：226 + 6 × 70 + 320")
        XCTAssertEqual(P.stripScrimRowLocation(cardHeight: 104), 70.0 / 104.0, accuracy: 0.000_001)
        XCTAssertEqual(P.stripScrimRowLocation(cardHeight: 390), 70.0 / 390.0, accuracy: 0.000_001)
        XCTAssertEqual(P.stripScrimRowLocation(cardHeight: 50), 1, "钳到 1")
        XCTAssertEqual(P.stripScrimRowLocation(cardHeight: 0), 1)
        XCTAssertEqual(P.coverOffset(isOpen: true), 0, "展开：封面与卡顶对齐")
        XCTAssertEqual(P.coverOffset(isOpen: false), -78, "收起：上移 (104 − 260) ÷ 2，露出居中带")
        // 由 IC178A 移入（口径不变）。
        XCTAssertEqual(P.seenPercent(processed: 0, total: 0), 0, "空范围")
        XCTAssertEqual(P.seenPercent(processed: 0, total: 10), 0)
        XCTAssertEqual(P.seenPercent(processed: 1, total: 3), 33, "向下取整")
        XCTAssertEqual(P.seenPercent(processed: 29, total: 100), 29, "整数运算，不受浮点误差影响")
        XCTAssertEqual(P.seenPercent(processed: 999, total: 1000), 99, "未看完不显示 100")
        XCTAssertEqual(P.seenPercent(processed: 10, total: 10), 100)
        XCTAssertEqual(P.seenPercent(processed: 12, total: 10), 100, "钳到 100")
        XCTAssertEqual(P.seenPercent(processed: -1, total: 10), 0, "钳到 0")
        XCTAssertFalse(P.isComplete(processed: 0, total: 0), "空范围不算看完")
        XCTAssertFalse(P.isComplete(processed: 9, total: 10))
        XCTAssertTrue(P.isComplete(processed: 10, total: 10))
        XCTAssertTrue(P.isComplete(processed: 11, total: 10))
        XCTAssertFalse(P.opensYearPage(childCount: 0))
        XCTAssertTrue(P.opensYearPage(childCount: 1))
        XCTAssertFalse(P.showsPendingPill(count: 0))
        XCTAssertTrue(P.showsPendingPill(count: 1))
        XCTAssertFalse(P.showsNewPill(count: 0))
        XCTAssertTrue(P.showsNewPill(count: 2))
        XCTAssertEqual(S1ProgressLinePresentation.fillFraction(processed: 1, total: 4), 0.25, accuracy: 0.000_001)
        // 文本拼接（既有 key + 分隔）。
        XCTAssertEqual(P.separator, " · ")
        let year = row(id: "y2026", name: "2026", total: 2375, pending: 15, seen: 1045, new: 3, children: 9)
        XCTAssertEqual(P.seenText(processed: 1045, total: 2375), "已看 44%")
        XCTAssertEqual(P.seenText(processed: 0, total: 0), "已看 0%", "空范围不写看完")
        XCTAssertEqual(P.seenText(processed: 7, total: 7), "看完")
        XCTAssertEqual(P.openSubtitle(for: year, kind: .years), "2375 张 · 9 个月 · 已看 44%")
        let month = row(id: "m2026-09", name: "2026年9月", total: 412, pending: 0, seen: 412, new: 0, children: 0)
        XCTAssertEqual(P.openSubtitle(for: month, kind: .months), "412 张 · 看完")
        XCTAssertEqual(P.openSubtitle(for: month, kind: .albums), "412 张 · 看完")
        XCTAssertEqual(P.actionTitle(kind: .years, childCount: 9), "去清理")
        XCTAssertEqual(P.actionTitle(kind: .years, childCount: 0), "去整理", "没有月范围的年直接进 S2")
        XCTAssertEqual(P.actionTitle(kind: .months, childCount: 0), "去整理")
        XCTAssertEqual(P.actionTitle(kind: .albums, childCount: 2), "去整理", "只有年卡进年页")
        XCTAssertEqual(P.yearSummary(for: year), "2375 张 · 9 个月 · 已看 44% · 待删 15 · 新增 3")
        let quiet = row(id: "y2025", name: "2025", total: 2375, pending: 0, seen: 1045, new: 0, children: 9)
        XCTAssertEqual(P.yearSummary(for: quiet), "2375 张 · 9 个月 · 已看 44%", "待删、新增为零不显示")
        let onlyNew = row(id: "y2024", name: "2024", total: 10, pending: 0, seen: 10, new: 2, children: 1)
        XCTAssertEqual(P.yearSummary(for: onlyNew), "10 张 · 1 个月 · 看完 · 新增 2")
    }

    // MARK: - 断言 2：登记值

    func testIC193B_MetricsMatchSpec2d() {
        typealias M = S1DeckMetrics
        XCTAssertEqual(M.deckHorizontalInset, 6)
        XCTAssertEqual(M.cardCornerRadius, 28)
        XCTAssertEqual(M.stripCardHeight, 104)
        XCTAssertEqual(M.stripVisibleHeight, 70)
        XCTAssertEqual(M.openCardHeight, 260)
        XCTAssertEqual(M.cardOverhang, 34)
        XCTAssertEqual(M.lastCardTailHeight, 320)
        XCTAssertEqual(M.cardShadowOpacity, 0.60, accuracy: 0.000_001)
        XCTAssertEqual(M.cardShadowRadius, 30)
        XCTAssertEqual(M.cardShadowYOffset, -14)
        XCTAssertEqual(M.cardEdgeWidth, 0.5)
        XCTAssertEqual(M.cardHighlightOpacity, 0.30, accuracy: 0.000_001)
        XCTAssertEqual(M.cardRingOpacity, 0.12, accuracy: 0.000_001)
        XCTAssertEqual(M.stripScrimTopOpacity, 0.76, accuracy: 0.000_001)
        XCTAssertEqual(M.stripScrimRowOpacity, 0.60, accuracy: 0.000_001)
        XCTAssertEqual(M.stripScrimBottomOpacity, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(M.stripLeadingInset, 18)
        XCTAssertEqual(M.stripTrailingInset, 14)
        XCTAssertEqual(M.stripItemSpacing, 10)
        XCTAssertEqual(M.seenRingSide, 18)
        XCTAssertEqual(M.seenRingLineWidth, 3)
        XCTAssertEqual(M.seenRingTrackOpacity, 0.22, accuracy: 0.000_001)
        XCTAssertEqual(M.seenRingStartDegrees, -90)
        XCTAssertEqual(M.stripNameFontSize, 17)
        XCTAssertEqual(M.pillHeight, 22)
        XCTAssertEqual(M.pillHorizontalPadding, 8)
        XCTAssertEqual(M.pillFontSize, 12)
        XCTAssertEqual(M.newPillFillOpacity, 0.72, accuracy: 0.000_001)
        XCTAssertEqual(M.newPillRingOpacity, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(M.newPillRingWidth, 0.5)
        XCTAssertEqual(M.stripShareFontSize, 12.5)
        XCTAssertEqual(M.stripShareOpacity, 0.66, accuracy: 0.000_001)
        XCTAssertEqual(M.stripValueFontSize, 22)
        XCTAssertEqual(M.stripValueKerning, -0.6)
        XCTAssertEqual(M.stripUnitFontSize, 13)
        XCTAssertEqual(M.stripUnitOpacity, 0.70, accuracy: 0.000_001)
        XCTAssertEqual(M.stripUnitSpacing, 3)
        XCTAssertEqual(M.stripChevronPointSize, 14)
        XCTAssertEqual(M.stripChevronOpacity, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(M.openScrimTopOpacity, 0.34, accuracy: 0.000_001)
        XCTAssertEqual(M.openScrimClearLocation, 0.30, accuracy: 0.000_001)
        XCTAssertEqual(M.openScrimMiddleOpacity, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(M.openScrimMiddleLocation, 0.46, accuracy: 0.000_001)
        XCTAssertEqual(M.openScrimBottomOpacity, 0.76, accuracy: 0.000_001)
        XCTAssertEqual(M.openChipInset, 14)
        XCTAssertEqual(M.openChipSpacing, 6)
        XCTAssertEqual(M.shareChipHeight, 26)
        XCTAssertEqual(M.shareChipHorizontalPadding, 10)
        XCTAssertEqual(M.shareChipFontSize, 12)
        XCTAssertEqual(M.shareChipFillOpacity, 0.62, accuracy: 0.000_001)
        XCTAssertEqual(M.openTextLeadingInset, 20)
        XCTAssertEqual(M.openTextTrailingInset, 150)
        XCTAssertEqual(M.openTextBottomInset, 50)
        XCTAssertEqual(M.openTextShadowYOffset, 1)
        XCTAssertEqual(M.openTextShadowRadius, 8)
        XCTAssertEqual(M.openTextShadowOpacity, 0.50, accuracy: 0.000_001)
        XCTAssertEqual(M.openNameFontSize, 19)
        XCTAssertEqual(M.openValueFontSize, 40)
        XCTAssertEqual(M.openValueKerning, -1.4)
        XCTAssertEqual(M.openSubtitleFontSize, 12.5)
        XCTAssertEqual(M.openSubtitleOpacity, 0.80, accuracy: 0.000_001)
        XCTAssertEqual(M.openSubtitleTopSpacing, 1)
        XCTAssertEqual(M.openBarTopSpacing, 8)
        XCTAssertEqual(M.openBarWidth, 190)
        XCTAssertEqual(M.barHeight, 3)
        XCTAssertEqual(M.barCornerRadius, 2)
        XCTAssertEqual(M.barTrackOpacity, 0.20, accuracy: 0.000_001)
        XCTAssertEqual(M.ctaHeight, 44)
        XCTAssertEqual(M.ctaLeadingPadding, 18)
        XCTAssertEqual(M.ctaTrailingPadding, 14)
        XCTAssertEqual(M.ctaFontSize, 15)
        XCTAssertEqual(M.ctaItemSpacing, 6)
        XCTAssertEqual(M.ctaChevronPointSize, 14)
        XCTAssertEqual(M.ctaTrailingInset, 16)
        XCTAssertEqual(M.ctaBottomInset, 54)
        XCTAssertEqual(M.yearTitleTopFromChromeBottom, 12)
        XCTAssertEqual(M.yearTitleLeadingInset, 20)
        XCTAssertEqual(M.yearTitleTrailingInset, 16)
        XCTAssertEqual(M.yearTitleFontSize, 40)
        XCTAssertEqual(M.yearTitleKerning, -1.2)
        XCTAssertEqual(M.yearSizeFontSize, 15)
        XCTAssertEqual(M.yearSizeTopSpacing, 4)
        XCTAssertEqual(M.yearShareSpacing, 8)
        XCTAssertEqual(M.yearShareOpacity, 0.66, accuracy: 0.000_001)
        XCTAssertEqual(M.organizeButtonHeight, 40)
        XCTAssertEqual(M.organizeButtonCornerRadius, 16)
        XCTAssertEqual(M.organizeButtonHorizontalPadding, 14)
        XCTAssertEqual(M.organizeButtonSymbolPointSize, 18)
        XCTAssertEqual(M.organizeButtonSpacing, 6)
        XCTAssertEqual(M.yearSummaryTopFromChromeBottom, 92)
        XCTAssertEqual(M.yearSummaryFontSize, 13)
        XCTAssertEqual(M.yearSummaryOpacity, 0.66, accuracy: 0.000_001)
        XCTAssertEqual(M.yearSummaryHorizontalInset, 20)
        XCTAssertEqual(M.yearBarTopFromChromeBottom, 116)
        XCTAssertEqual(M.yearBarHeight, 4)
        XCTAssertEqual(M.monthDeckTopFromChromeBottom, 142)
        // 推导恒等式：收起卡 = 露出行 + 被盖住的；展开卡可见 226（首页 200）。
        XCTAssertEqual(M.stripCardHeight, M.stripVisibleHeight + M.cardOverhang)
        XCTAssertEqual(M.openCardHeight - M.cardOverhang, 226)
        XCTAssertEqual(M.cardCornerRadius, S0DeckMetrics.cardCornerRadius, "与首页同值、各自登记")
        // 两处画布字面色：收起压暗 #080A09、占比胶囊底 #141615。
        assertColor(M.stripScrimColor, red: 8, green: 10, blue: 9)
        assertColor(M.shareChipFill, red: 20, green: 22, blue: 21)
        XCTAssertEqual(S1DeckSymbol.back, "chevron.left")
        XCTAssertEqual(S1DeckSymbol.organizeAll, "rectangle.stack")
        for name in [S1DeckSymbol.back, S1DeckSymbol.organizeAll, S0DeckSymbol.chevron] {
            XCTAssertNotNil(UIImage(systemName: name), name)
        }
    }

    // MARK: - 断言 3：目录

    func testIC193C_CatalogAddsSixKeysAndRetiresSummary() throws {
        let data = try XCTUnwrap(sourceText(Self.catalogPath)?.data(using: .utf8))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for (key, value) in Self.newKeyValues + Self.keptKeyValues {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], key)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
            let zh = try XCTUnwrap(localizations["zh-Hans"] as? [String: Any], key)
            let unit = try XCTUnwrap(zh["stringUnit"] as? [String: Any], key)
            XCTAssertEqual(unit["value"] as? String, value, key)
            XCTAssertEqual(L10n.text(key), value, key)
        }
        XCTAssertNil(strings["s1.yearPage.summary"], "汇总行改由既有 key 拼接")
        for key in ["s1.range.total_count", "s1.range.pending_count", "s1.volume.counting", "s1.trash.accessibility"] {
            XCTAssertNotNil(strings[key], key)
        }
        XCTAssertEqual(strings.keys.filter { $0.hasPrefix("s0.") }.count, 41, "s0. 不动")
        XCTAssertEqual(L10n.text("s1.deck.share", replacing: ["percent": "40"]), "占 40%")
        XCTAssertEqual(L10n.text("s1.deck.new.open", replacing: ["count": "3"]), "新增 3 张")
        XCTAssertEqual(L10n.text("s1.yearPage.share", replacing: ["percent": "12"]), "占全部 12%")
    }

    // MARK: - 断言 4：源码落位

    func testIC193D_SourceWiring() throws {
        let cards = try XCTUnwrap(strippedSource(Self.cardsPath))
        let cardsRaw = try XCTUnwrap(sourceText(Self.cardsPath))
        for (needle, expected) in [
            ("S0DeckCoverView(", 1),
            ("height: S1DeckMetrics.openCardHeight", 1),
            (".id(coverAssetID)", 1),
            (".id(isOpen)", 0),
            (".offset(y: S1DeckCardPresentation.coverOffset(isOpen: isOpen))", 1),
            ("S0DeckMetrics.cardBase", 1),
            ("@ObservedObject var openCards: S1OpenCardState", 1),
            ("withAnimation(S1DeckCardPresentation.expandAnimation)", 1),
            ("S0DeckMetrics.expandAnimationResponse", 1),
            ("S0DeckMetrics.expandAnimationDamping", 1),
            ("S0DeckMetrics.expandContentRise", 1),
            (".transition(S1DeckCardPresentation.openContentTransition)", 3),
            ("S1ProgressLinePresentation.fillFraction(", 2),
            ("S1DeckSeenRing(", 1),
            ("S1DeckProgressBar(", 1),
            ("S1DeckCardView(", 1),
            ("S1DeckStack(", 1),
            (".zIndex(", 1),
            (".clipShape(", 1),
            (".contentShape(", 1),
            ("Button(action:", 1),
            (".buttonStyle(.plain)", 1),
            ("S1NotificationBadgeStyle.digitColor", 1),
            ("S0DeckMetrics.accent", 1),
            ("S0DeckSymbol.chevron", 2),
            ("S0DeckSymbol.percentSign", 1),
            ("stackBottomPadding", 0),
            ("S1DeckSymbol.done", 0),
            ("ScrollView", 0),
            ("GeometryReader", 2)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: cards), expected, "cards " + needle)
        }
        let metrics = try XCTUnwrap(slice(cards, from: "enum S1DeckMetrics {", to: Self.newline + "}" + Self.newline))
        XCTAssertEqual(occurrences(of: "static let ", in: metrics), 98, "V1 登记值恰九十八个（含两处字面色）")
        let symbols = try XCTUnwrap(slice(cards, from: "enum S1DeckSymbol {", to: Self.newline + "}" + Self.newline))
        XCTAssertEqual(occurrences(of: "static let ", in: symbols), 2)
        for (key, expected) in [
            ("s1.deck.year.subtitle", 2), ("s1.deck.pending", 2), ("s1.deck.seen", 1), ("s1.deck.done", 1),
            ("s1.deck.new", 2), ("s1.deck.new.open", 1), ("s1.deck.share", 1), ("s1.deck.action.yearPage", 1),
            ("s1.deck.action.organize", 1), ("s1.range.total_count", 1), ("s1.range.pending_count", 1),
            ("s1.volume.counting", 2), ("s1.yearPage.summary", 0)
        ] {
            XCTAssertEqual(occurrences(of: "\"" + key + "\"", in: cardsRaw), expected, "cards " + key)
        }

        let yearPage = try XCTUnwrap(strippedSource(Self.yearPagePath))
        let yearPageRaw = try XCTUnwrap(sourceText(Self.yearPagePath))
        for (needle, expected) in [
            ("S1DeckListView(", 1),
            ("slot: .yearPage", 1),
            ("kind: .months", 1),
            ("S1DeckStack(", 0),
            ("GeometryReader", 0),
            ("S1DeckProgressBar(", 1),
            ("S1DeckCardPresentation.yearSummary(for: yearRow)", 1),
            ("S1PageHeaderMetrics.chip", 3),
            ("S0BasketEntryView(style: .glass", 1),
            ("s1ChromeCircleGlass()", 1),
            (".toolbar(.hidden, for: .tabBar)", 1),
            (".toolbar(.hidden, for: .navigationBar)", 1),
            ("Button(action:", 2),
            (".buttonStyle(.plain)", 1),
            (".accessibilityLabel(", 1),
            (".kerning(", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: yearPage), expected, "yearPage " + needle)
        }
        for (key, expected) in [
            ("s1.yearPage.share", 1), ("s1.volume.counting", 1), ("s1.yearPage.organizeAll", 1),
            ("s1.yearPage.back", 1), ("s1.yearPage.summary", 0), ("s1.trash.accessibility", 0)
        ] {
            XCTAssertEqual(occurrences(of: "\"" + key + "\"", in: yearPageRaw), expected, "yearPage " + key)
        }

        // S1View：两处接线（列表页与年页把展开态与「展开／进入」两只回调交给卡叠）。
        let s1 = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        for (needle, expected) in [
            ("S1DeckListView(", 1),
            ("S1YearPageView(", 1),
            ("openCards: machine.openCards", 2),
            ("slot: .list", 1),
            ("_ = machine.openListCard(row.id)", 1),
            ("_ = machine.openYearPageCard(row.id)", 1),
            ("onTap:", 0),
            ("enterRange(", 4)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: s1), expected, "S1View " + needle)
        }

        // 全产品：只有卡叠观察展开态。
        let product = try productSources()
        XCTAssertEqual(product.values.reduce(0) { $0 + occurrences(of: "@ObservedObject var openCards", in: $1) }, 1)
    }

    // MARK: - 工具（与既有测试同口径）

    private func row(
        id: String,
        name: String,
        total: Int,
        pending: Int,
        seen: Int,
        new: Int,
        children: Int
    ) -> S1RangeRow {
        S1RangeRow(
            id: id,
            displayName: name,
            totalAssetCount: total,
            pendingDeletionCount: pending,
            processedAssetCount: seen,
            newAssetCount: new,
            byteCount: nil,
            sharePercent: nil,
            parentRangeID: nil,
            childCount: children
        )
    }

    private func assertColor(_ color: Color, red: Int, green: Int, blue: Int, file: StaticString = #filePath, line: UInt = #line) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a), file: file, line: line)
        XCTAssertEqual(Int((r * 255).rounded()), red, file: file, line: line)
        XCTAssertEqual(Int((g * 255).rounded()), green, file: file, line: line)
        XCTAssertEqual(Int((b * 255).rounded()), blue, file: file, line: line)
    }

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
