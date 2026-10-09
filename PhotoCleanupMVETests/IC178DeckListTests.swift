import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-178：「逐张整理」范围列表 (i) 年卡叠 → 年页（Decision_log 第 205 条第二节第 1 条；R2 画布 `i_s1`／`i_year_page`）。
///
/// 断言 1 钉卡片叠展示口径（步长、卡高、叠高、已看百分比、看完、进年页判据），2 钉年页身份在状态机里的守卫与
/// 生命周期（不入档、切维度清、对账后年消失清、S2 遮挡期间保留、不改状态与列表数据），3 钉五十个登记值与三个
/// 符号名，4 钉源码落位（S1View 换成 `NavigationStack` + 两只新视图、旧列表层退役、IC177 计数、状态机加法、
/// 新文件纪律与计数），5 钉目录七条 key。卡片叠的观感、推入动画、tab bar 隐藏与封面取图归 H96 真机。
final class IC178DeckListTests: XCTestCase {
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let cardsPath = "PhotoCleanupMVE/Features/S1/S1DeckCards.swift"
    private static let yearPagePath = "PhotoCleanupMVE/Features/S1/S1YearPageView.swift"
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    /// 七条新 key 与取值（卡内暂登，SPEC-S1 v11 回填）。
    private static let newKeyValues: [(String, String)] = [
        ("s1.deck.year.subtitle", "{count} 张 · {months} 个月"),
        ("s1.deck.pending", "待删 {count}"),
        ("s1.deck.seen", "已看 {percent}%"),
        ("s1.deck.done", "看完"),
        ("s1.yearPage.summary", "{count} 张 · {months} 个月 · 已看 {percent}% · 待删 {pending}"),
        ("s1.yearPage.organizeAll", "整理整年"),
        ("s1.yearPage.back", "返回")
    ]
    private static let dynamicNeedles = [
        "systemGroupedBackground", "secondarySystemGroupedBackground", "secondarySystemFill",
        "tertiaryLabel", "accentColor", "systemRed", "systemGreen", "systemOrange",
        "Color.primary", "Color.secondary", "uiColor: .separator", "Color(uiColor:", "systemBackground",
        "userInterfaceStyle", "dynamicColor(", "preferredColorScheme"
    ]

    // MARK: - 断言 1：卡片叠展示口径

    func testIC178A_StackAndCardPresentationRules() {
        XCTAssertEqual(S1DeckCardPresentation.step(for: .years), 72)
        XCTAssertEqual(S1DeckCardPresentation.step(for: .months), 80)
        XCTAssertEqual(S1DeckCardPresentation.step(for: .albums), 84)
        XCTAssertEqual(S1DeckCardPresentation.titleFontSize(for: .years), 26)
        XCTAssertEqual(S1DeckCardPresentation.titleFontSize(for: .months), 24)
        XCTAssertEqual(S1DeckCardPresentation.titleFontSize(for: .albums), 24)
        XCTAssertTrue(S1DeckCardPresentation.showsMonthCount(for: .years))
        XCTAssertFalse(S1DeckCardPresentation.showsMonthCount(for: .months))
        XCTAssertFalse(S1DeckCardPresentation.showsMonthCount(for: .albums))
        XCTAssertEqual(S1DeckCardPresentation.cardHeight(index: 0, count: 3), 170)
        XCTAssertEqual(S1DeckCardPresentation.cardHeight(index: 1, count: 3), 170)
        XCTAssertEqual(S1DeckCardPresentation.cardHeight(index: 2, count: 3), 190, "末卡整张露出")
        XCTAssertEqual(S1DeckCardPresentation.cardHeight(index: 0, count: 1), 190)
        XCTAssertEqual(S1DeckCardPresentation.stackHeight(count: 0, kind: .years), 0)
        XCTAssertEqual(S1DeckCardPresentation.stackHeight(count: 1, kind: .years), 190)
        XCTAssertEqual(S1DeckCardPresentation.stackHeight(count: 15, kind: .years), 1198, "R2 十五年：14 × 72 + 190")
        XCTAssertEqual(S1DeckCardPresentation.stackHeight(count: 6, kind: .months), 590, "R2 年页六个月：5 × 80 + 190")
        XCTAssertEqual(S1DeckCardPresentation.stackHeight(count: 5, kind: .albums), 526, "R2 相册页签五个相册：4 × 84 + 190")
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: 0, total: 0), 0, "空范围")
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: 0, total: 10), 0)
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: 1, total: 3), 33, "向下取整")
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: 29, total: 100), 29, "整数运算，不受浮点误差影响")
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: 999, total: 1000), 99, "未看完不显示 100")
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: 10, total: 10), 100)
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: 12, total: 10), 100, "钳到 100")
        XCTAssertEqual(S1DeckCardPresentation.seenPercent(processed: -1, total: 10), 0, "钳到 0")
        XCTAssertFalse(S1DeckCardPresentation.isComplete(processed: 0, total: 0), "空范围不算看完")
        XCTAssertFalse(S1DeckCardPresentation.isComplete(processed: 9, total: 10))
        XCTAssertTrue(S1DeckCardPresentation.isComplete(processed: 10, total: 10))
        XCTAssertTrue(S1DeckCardPresentation.isComplete(processed: 11, total: 10))
        XCTAssertFalse(S1DeckCardPresentation.opensYearPage(childCount: 0), "相册、未分类、月：直接进 S2")
        XCTAssertTrue(S1DeckCardPresentation.opensYearPage(childCount: 1), "有月的年：进年页")
        XCTAssertFalse(S1DeckCardPresentation.showsPendingPill(count: 0))
        XCTAssertTrue(S1DeckCardPresentation.showsPendingPill(count: 1))
        // 进度条比例沿用 IC-128 B 的口径（同一只函数）。
        XCTAssertEqual(S1ProgressLinePresentation.fillFraction(processed: 1, total: 4), 0.25, accuracy: 0.000_001)
        XCTAssertEqual(S1ProgressLinePresentation.fillFraction(processed: 0, total: 0), 0, accuracy: 0.000_001)
    }

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

    // MARK: - 断言 3：登记值与符号

    func testIC178C_MetricsAndSymbolsMatchCanvas() {
        XCTAssertEqual(S1DeckMetrics.horizontalMargin, 16)
        XCTAssertEqual(S1DeckMetrics.cardCornerRadius, 28)
        XCTAssertEqual(S1DeckMetrics.cardHeight, 170)
        XCTAssertEqual(S1DeckMetrics.lastCardHeight, 190)
        XCTAssertEqual(S1DeckMetrics.yearStep, 72)
        XCTAssertEqual(S1DeckMetrics.monthStep, 80)
        XCTAssertEqual(S1DeckMetrics.albumStep, 84)
        XCTAssertEqual(S1DeckMetrics.stackBottomPadding, 24)
        XCTAssertEqual(S1DeckMetrics.cardShadowOpacity, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(S1DeckMetrics.cardShadowRadius, 24)
        XCTAssertEqual(S1DeckMetrics.cardShadowYOffset, -10)
        XCTAssertEqual(S1DeckMetrics.cardRingWidth, 0.5)
        XCTAssertEqual(S1DeckMetrics.scrimTopOpacity, 0.78, accuracy: 0.000_001)
        XCTAssertEqual(S1DeckMetrics.scrimMiddleOpacity, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(S1DeckMetrics.scrimMiddleLocation, 0.46, accuracy: 0.000_001)
        XCTAssertEqual(S1DeckMetrics.scrimEndLocation, 0.70, accuracy: 0.000_001)
        XCTAssertEqual(S1DeckMetrics.headLeadingInset, 20)
        XCTAssertEqual(S1DeckMetrics.headTrailingInset, 16)
        XCTAssertEqual(S1DeckMetrics.headTopInset, 16)
        XCTAssertEqual(S1DeckMetrics.headSpacing, 10)
        XCTAssertEqual(S1DeckMetrics.yearTitleFontSize, 26)
        XCTAssertEqual(S1DeckMetrics.monthTitleFontSize, 24)
        XCTAssertEqual(S1DeckMetrics.titleKerning, -0.4)
        XCTAssertEqual(S1DeckMetrics.subtitleFontSize, 13.5)
        XCTAssertEqual(S1DeckMetrics.pendingPillHeight, 24)
        XCTAssertEqual(S1DeckMetrics.pendingPillHorizontalPadding, 9)
        XCTAssertEqual(S1DeckMetrics.pendingPillFontSize, 13)
        XCTAssertEqual(S1DeckMetrics.seenFontSize, 13)
        XCTAssertEqual(S1DeckMetrics.doneSymbolPointSize, 15)
        XCTAssertEqual(S1DeckMetrics.doneSpacing, 4)
        XCTAssertEqual(S1DeckMetrics.barHorizontalInset, 20)
        XCTAssertEqual(S1DeckMetrics.barTopInset, 54)
        XCTAssertEqual(S1DeckMetrics.barHeight, 3)
        XCTAssertEqual(S1DeckMetrics.barCornerRadius, 2)
        XCTAssertEqual(S1DeckMetrics.barTrackOpacity, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(S1DeckMetrics.yearPageTitleFontSize, 40)
        XCTAssertEqual(S1DeckMetrics.yearPageTitleKerning, -1.2)
        XCTAssertEqual(S1DeckMetrics.yearPageTitleRowHeight, 44)
        XCTAssertEqual(S1DeckMetrics.yearPageTitleRowTopSpacing, 8)
        XCTAssertEqual(S1DeckMetrics.organizeButtonHeight, 40)
        XCTAssertEqual(S1DeckMetrics.organizeButtonHorizontalPadding, 14)
        XCTAssertEqual(S1DeckMetrics.organizeButtonFillOpacity, 0.10, accuracy: 0.000_001)
        XCTAssertEqual(S1DeckMetrics.organizeButtonFontSize, 15)
        XCTAssertEqual(S1DeckMetrics.organizeButtonSymbolPointSize, 18)
        XCTAssertEqual(S1DeckMetrics.organizeButtonSpacing, 6)
        XCTAssertEqual(S1DeckMetrics.summaryFontSize, 14)
        XCTAssertEqual(S1DeckMetrics.summaryTopSpacing, 6)
        XCTAssertEqual(S1DeckMetrics.yearBarTopSpacing, 13)
        XCTAssertEqual(S1DeckMetrics.yearBarHeight, 4)
        XCTAssertEqual(S1DeckMetrics.monthStackTopSpacing, 26)
        // 与既有登记同值的两处（各自登记，不互引）。
        XCTAssertEqual(S1DeckMetrics.cardCornerRadius, S0DeckMetrics.cardCornerRadius)
        XCTAssertEqual(S1DeckMetrics.horizontalMargin, S1ChromeLayout.horizontalMargin)
        XCTAssertEqual(S1DeckSymbol.back, "chevron.left")
        XCTAssertEqual(S1DeckSymbol.organizeAll, "rectangle.stack")
        XCTAssertEqual(S1DeckSymbol.done, "checkmark")
        for name in [S1DeckSymbol.back, S1DeckSymbol.organizeAll, S1DeckSymbol.done] {
            XCTAssertNotNil(UIImage(systemName: name), name)
        }
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
        for (needle, expected) in [
            ("S1ChromeForeground.", 9),
            ("S0DeckMetrics.", 2),
            ("S1NotificationBadgeStyle.", 1),
            ("S1ProgressLinePresentation.fillFraction(", 1),
            ("S0DeckCoverView(", 1),
            (".id(coverAssetID)", 1),
            (".clipShape(", 1),
            (".contentShape(", 1),
            (".zIndex(", 1),
            (".offset(y:", 1),
            (".accessibilityHidden(true)", 1),
            (".accessibilityLabel(", 1),
            (".layoutPriority(1)", 1),
            (".fixedSize()", 2),
            (".buttonStyle(.plain)", 1),
            ("Button(action:", 1),
            ("LinearGradient(", 1),
            (".kerning(", 1),
            (".shadow(", 1),
            ("strokeBorder(", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: cards), expected, "cards " + needle)
        }
        let metrics = try XCTUnwrap(slice(cards, from: "enum S1DeckMetrics {", to: Self.newline + "}" + Self.newline))
        XCTAssertEqual(occurrences(of: "static let ", in: metrics), 50, "登记值恰五十个")
        let symbols = try XCTUnwrap(slice(cards, from: "enum S1DeckSymbol {", to: Self.newline + "}" + Self.newline))
        XCTAssertEqual(occurrences(of: "static let ", in: symbols), 3)
        // 借的两条既有 key（张数、待删读屏）也在这里——目录双向一致：旧红点角标删掉后 `pending_count` 仍有引用。
        for key in ["s1.deck.year.subtitle", "s1.deck.pending", "s1.deck.seen", "s1.deck.done", "s1.range.total_count", "s1.range.pending_count"] {
            XCTAssertEqual(occurrences(of: "\"" + key + "\"", in: cardsRaw), 1, key)
        }
        for (needle, expected) in [
            ("S1ChromeForeground.", 6),
            ("S0DeckMetrics.", 0),
            ("S1ChromeLayout.", 6),
            (".toolbar(.hidden, for: .tabBar)", 1),
            (".toolbar(.hidden, for: .navigationBar)", 1),
            ("S0BasketEntryView(style: .glass", 1),
            ("s1ChromeCircleGlass()", 1),
            (".accessibilityLabel(", 1),
            (".buttonStyle(.plain)", 1),
            ("Button(action:", 2),
            ("S1DeckStack(", 1),
            ("S1DeckProgressBar(", 1),
            ("kind: .months", 1),
            (".kerning(", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: yearPage), expected, "yearPage " + needle)
        }
        for key in ["s1.yearPage.summary", "s1.yearPage.organizeAll", "s1.yearPage.back"] {
            XCTAssertEqual(occurrences(of: "\"" + key + "\"", in: yearPageRaw), 1, key)
        }
        XCTAssertEqual(occurrences(of: "\"s1.trash.accessibility\"", in: yearPageRaw), 0, "读屏 key 由 S0BasketEntryView 自带")
    }

    // MARK: - 断言 5：目录

    func testIC178E_CatalogGainsSevenKeys() throws {
        let catalog = try XCTUnwrap(sourceText(Self.catalogPath))
        for (key, value) in Self.newKeyValues {
            XCTAssertEqual(occurrences(of: "\"" + key + "\" : {", in: catalog), 1, key)
            let valueHits = occurrences(of: "\"value\" : \"" + value + "\"", in: catalog)
            if key == "s1.yearPage.back" {
                // 「返回」与 S0／S2／S3 各自的返回钮同一取值（各自 key），只要求存在。
                XCTAssertGreaterThanOrEqual(valueHits, 1, key)
            } else {
                XCTAssertEqual(valueHits, 1, key)
            }
            XCTAssertEqual(L10n.text(key), value, key)
        }
        XCTAssertEqual(L10n.text("s1.range.total_count", replacing: ["count": "412"]), "412 张")
        XCTAssertEqual(
            L10n.text("s1.yearPage.summary", replacing: ["count": "2375", "months": "9", "percent": "44", "pending": "15"]),
            "2375 张 · 9 个月 · 已看 44% · 待删 15"
        )
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
