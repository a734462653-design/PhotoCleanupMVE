import SwiftUI

// MARK: - IC-193：V1 卡片叠（SPEC-S1 v12 第六节第 2 部分、第十一节第 2d 部分；R3 画布 `deck_row`／`deck_open`／`v1_year_page`）

/// 「逐张整理」V1 卡片叠与年页标题区的视觉登记（SPEC-S1 v12 第十一节第 2d 部分；取值出处 R3 画布 `Tasks/design-r3/gen.py`
/// 的 `ring()`／`deck_row()`／`deck_open()`／`v1_year_page()` 与 `BASE_CSS` 的 `.dk`／`.dimc`／`.shade`／`.edge`／`.pend`／`.newc`／
/// `.pct`／`.btnp`／`.bar`）。CSS 的 px 按 pt 读；阴影 blur 照 `S0DeckMetrics` 先例直接登记为 radius；纵向位置以「顶排底缘」
/// 为零点。色只登记画布里不在色板中的两处字面色（收起压暗、占比胶囊底）；文字与压暗走 `S1ChromeForeground`／
/// `S0DeckMetrics.dimmedText`，薄荷、强调与卡底走 `S0DeckMetrics`。自登、不引首页同名值（第 221 条第三节第 6 项）。
/// **不进** `S2CalibrationConfiguration`、不上标定面板。
enum S1DeckMetrics {
    // MARK: 叠与卡（`.dk`）

    /// 叠的左右边距（`.dk` `left 6`／`right 6`）。
    static let deckHorizontalInset: CGFloat = 6
    /// 卡圆角（命中区 = 此圆角矩形）。
    static let cardCornerRadius: CGFloat = 28
    /// 收起卡高、露出的一行（首页为 66）。
    static let stripCardHeight: CGFloat = 104
    static let stripVisibleHeight: CGFloat = 70
    /// 展开卡高；下缘被下一张盖住的高（展开卡可见 226；首页可见 200）。
    static let openCardHeight: CGFloat = 260
    static let cardOverhang: CGFloat = 34
    /// 末卡向下延伸出列表底的高（同 SPEC-S0 首页 `lastCardTailHeight`）。
    static let lastCardTailHeight: CGFloat = 320
    /// 上缘阴影（`box-shadow: 0 -14px 30px rgba(0,0,0,0.60)`）。
    static let cardShadowOpacity: Double = 0.60
    static let cardShadowRadius: CGFloat = 30
    static let cardShadowYOffset: CGFloat = -14
    /// 内描边两道（`.edge`：上缘高光 白 × 0.30、外圈 白 × 0.12，皆 0.5）。
    static let cardEdgeWidth: CGFloat = 0.5
    static let cardHighlightOpacity: Double = 0.30
    static let cardRingOpacity: Double = 0.12

    // MARK: 收起行（`deck_row`、`.dimc`）

    /// 收起压暗色（画布字面色 `#080A09`，近页面底色）与三档不透明度：卡顶、露出行底缘（70 处）、卡底。
    static let stripScrimColor = Color(red: 8.0 / 255, green: 10.0 / 255, blue: 9.0 / 255)
    static let stripScrimTopOpacity: Double = 0.76
    static let stripScrimRowOpacity: Double = 0.60
    static let stripScrimBottomOpacity: Double = 0.18
    static let stripLeadingInset: CGFloat = 18
    static let stripTrailingInset: CGFloat = 14
    static let stripItemSpacing: CGFloat = 10
    /// 已看小圆环：边长、线宽、轨道（前景 × 0.22）、起点 12 点（−90°，顺时针）。
    static let seenRingSide: CGFloat = 18
    static let seenRingLineWidth: CGFloat = 3
    static let seenRingTrackOpacity: Double = 0.22
    static let seenRingStartDegrees: Double = -90
    /// 名字（600 字重）。
    static let stripNameFontSize: CGFloat = 17
    /// 「待删 N」「新增 N」胶囊（`.pend`／`.newc`：高 22、圆角 11、内距 8、12／700）；新增 = 页面底色 × 0.72 底、薄荷字、
    /// 薄荷 × 0.45 内描边 0.5。
    static let pillHeight: CGFloat = 22
    static let pillHorizontalPadding: CGFloat = 8
    static let pillFontSize: CGFloat = 12
    static let newPillFillOpacity: Double = 0.72
    static let newPillRingOpacity: Double = 0.45
    static let newPillRingWidth: CGFloat = 0.5
    /// 占比灰字（前景 × 0.66，右对齐）。
    static let stripShareFontSize: CGFloat = 12.5
    static let stripShareOpacity: Double = 0.66
    /// GB：数字 22／800、字距 −0.6；单位 13、前景 × 0.70、左距 3。
    static let stripValueFontSize: CGFloat = 22
    static let stripValueKerning: CGFloat = -0.6
    static let stripUnitFontSize: CGFloat = 13
    static let stripUnitOpacity: Double = 0.70
    static let stripUnitSpacing: CGFloat = 3
    /// 箭头（前景 × 0.45）。
    static let stripChevronPointSize: CGFloat = 14
    static let stripChevronOpacity: Double = 0.45

    // MARK: 展开卡（`deck_open`、`.shade`）

    /// 黑色压暗（位置:不透明度 = 0:0.34、0.30:0、0.46:0.05、1:0.76），渐变止于卡底向上 `cardOverhang` 处。
    static let openScrimTopOpacity: Double = 0.34
    static let openScrimClearLocation: Double = 0.30
    static let openScrimMiddleOpacity: Double = 0.05
    static let openScrimMiddleLocation: Double = 0.46
    static let openScrimBottomOpacity: Double = 0.76
    /// 左上胶囊组距卡左、卡顶；组内间距。
    static let openChipInset: CGFloat = 14
    static let openChipSpacing: CGFloat = 6
    /// 「占 N%」（`.pct`：高 26、圆角 13、内距 10、12／700、底 `#141615` × 0.62）。
    static let shareChipHeight: CGFloat = 26
    static let shareChipHorizontalPadding: CGFloat = 10
    static let shareChipFontSize: CGFloat = 12
    static let shareChipFill = Color(red: 20.0 / 255, green: 22.0 / 255, blue: 21.0 / 255)
    static let shareChipFillOpacity: Double = 0.62
    /// 左下文字组：左距、右侧让出按钮、底距卡顶 + `openCardHeight` 处向上（含被盖住的 34）。
    static let openTextLeadingInset: CGFloat = 20
    static let openTextTrailingInset: CGFloat = 150
    static let openTextBottomInset: CGFloat = 50
    /// 文字阴影（`text-shadow: 0 1px 8px rgba(0,0,0,0.5)`）。
    static let openTextShadowYOffset: CGFloat = 1
    static let openTextShadowRadius: CGFloat = 8
    static let openTextShadowOpacity: Double = 0.50
    static let openNameFontSize: CGFloat = 19
    /// 大号 GB（数字与单位同号）800 字重、字距 −1.4。
    static let openValueFontSize: CGFloat = 40
    static let openValueKerning: CGFloat = -1.4
    /// 副文（前景 × 0.80，上距 1）。
    static let openSubtitleFontSize: CGFloat = 12.5
    static let openSubtitleOpacity: Double = 0.80
    static let openSubtitleTopSpacing: CGFloat = 1
    /// 已看条：上距 8、宽 190；条高 3、圆角 2、轨道 白 × 0.20、填充薄荷（年进度条同轨道与填充）。
    static let openBarTopSpacing: CGFloat = 8
    static let openBarWidth: CGFloat = 190
    static let barHeight: CGFloat = 3
    static let barCornerRadius: CGFloat = 2
    static let barTrackOpacity: Double = 0.20
    /// 「去清理 ›」「去整理 ›」（`.btnp` 覆写：高 44、内距 0 14 0 18、15／700、间距 6、箭头 14；前景主色底、页面底色字）。
    static let ctaHeight: CGFloat = 44
    static let ctaLeadingPadding: CGFloat = 18
    static let ctaTrailingPadding: CGFloat = 14
    static let ctaFontSize: CGFloat = 15
    static let ctaItemSpacing: CGFloat = 6
    static let ctaChevronPointSize: CGFloat = 14
    static let ctaTrailingInset: CGFloat = 16
    static let ctaBottomInset: CGFloat = 54

    // MARK: 年页标题区（`v1_year_page`）

    /// 标题区：距顶排底缘 12、左 20、右 16；年份 40／900、字距 −1.2。
    static let yearTitleTopFromChromeBottom: CGFloat = 12
    static let yearTitleLeadingInset: CGFloat = 20
    static let yearTitleTrailingInset: CGFloat = 16
    static let yearTitleFontSize: CGFloat = 40
    static let yearTitleKerning: CGFloat = -1.2
    /// 体积行：「X GB」15／700、上距 4；「占全部 N%」500 字重、前景 × 0.66、左距 8。
    static let yearSizeFontSize: CGFloat = 15
    static let yearSizeTopSpacing: CGFloat = 4
    static let yearShareSpacing: CGFloat = 8
    static let yearShareOpacity: Double = 0.66
    /// 「整理整年」：维度胶囊同式（字号、字重、字色、底色引 `S1PageHeaderMetrics`），高 40、圆角 16、内距 14、符号 18、间距 6。
    static let organizeButtonHeight: CGFloat = 40
    static let organizeButtonCornerRadius: CGFloat = 16
    static let organizeButtonHorizontalPadding: CGFloat = 14
    static let organizeButtonSymbolPointSize: CGFloat = 18
    static let organizeButtonSpacing: CGFloat = 6
    /// 汇总行：距顶排底缘 92、13 字号、前景 × 0.66、左右 20。
    static let yearSummaryTopFromChromeBottom: CGFloat = 92
    static let yearSummaryFontSize: CGFloat = 13
    static let yearSummaryOpacity: Double = 0.66
    static let yearSummaryHorizontalInset: CGFloat = 20
    /// 年进度条：距顶排底缘 116、高 4（左右同汇总行）。
    static let yearBarTopFromChromeBottom: CGFloat = 116
    static let yearBarHeight: CGFloat = 4
    /// 月卡叠顶（距顶排底缘）——年页标题区块高即此值。
    static let monthDeckTopFromChromeBottom: CGFloat = 142
}

/// 卡片叠与年页用到的 SF Symbol 名（决策会话取定；R3 画布只给线条图标）。箭头与排序、人像借 `S0DeckSymbol`，
/// 待删篮入口的垃圾桶由 `S0BasketEntryView` 自带，都不在此登记。
enum S1DeckSymbol {
    static let back = "chevron.left"
    static let organizeAll = "rectangle.stack"
}

/// 一叠卡是哪一种：年卡（`T=按日期` 的一级范围）、月卡（年页）、相册／未分类卡（其他维度的一级范围）。
/// 决定展开卡副文（年卡带「M 个月」）与按钮（有月范围的年卡「去清理」，其余「去整理」）。
enum S1DeckCardKind: Equatable {
    case years
    case months
    case albums
}

/// 卡叠读展开态的哪一只：列表页（一级范围）或年页（月卡）。
enum S1DeckOpenSlot: Equatable {
    case list
    case yearPage
}

/// V1 卡片叠的展示口径（测试钉住）。
///
/// - 几何照「空间清理」首页：可见高 = 展开 226／收起 70；卡高 = 可见高 +（末卡 320，其余 34）；第 i 张的上偏移 =
///   前 i 张可见高之和；叠高 = 全部可见高之和 + 320，空叠为 0。
/// - 「已看 N%」= 已看数 ÷ 总数，整数向下取、钳到 [0, 100]；只有全部看过才是 100 与「看完」。
/// - 有子节点的卡进年页，其余直接进 S2（判据 `opensYearPage(childCount:)`：`childCount > 0`）。
/// - 展开卡副文与年页汇总行由既有 key 拼接，分隔 `separator`；汇总行的待删、新增两段为零不显示（规格推论，未定项 30）。
enum S1DeckCardPresentation {
    static let separator = " · "

    static func visibleHeight(isOpen: Bool) -> CGFloat {
        isOpen
            ? S1DeckMetrics.openCardHeight - S1DeckMetrics.cardOverhang
            : S1DeckMetrics.stripVisibleHeight
    }

    static func cardHeight(index: Int, count: Int, isOpen: Bool) -> CGFloat {
        visibleHeight(isOpen: isOpen)
            + (index == count - 1 ? S1DeckMetrics.lastCardTailHeight : S1DeckMetrics.cardOverhang)
    }

    static func openIndex(of rangeID: String?, in rangeIDs: [String]) -> Int? {
        guard let rangeID else {
            return nil
        }
        return rangeIDs.firstIndex(of: rangeID)
    }

    static func offset(index: Int, openIndex: Int?) -> CGFloat {
        var total: CGFloat = 0
        for position in 0..<max(0, index) {
            total += visibleHeight(isOpen: position == openIndex)
        }
        return total
    }

    static func stackHeight(count: Int, openIndex: Int?) -> CGFloat {
        guard count > 0 else {
            return 0
        }
        return offset(index: count, openIndex: openIndex) + S1DeckMetrics.lastCardTailHeight
    }

    /// 封面恒为卡宽 × `openCardHeight`、取图一次；收起时上移让卡身（`stripCardHeight`）露出这张图的居中带（同画布与首页的
    /// 收起取景），展开时归零。随展开的 spring 一起移动，视图身份不变、不重新取图。
    static func coverOffset(isOpen: Bool) -> CGFloat {
        ((isOpen ? S1DeckMetrics.openCardHeight : S1DeckMetrics.stripCardHeight) - S1DeckMetrics.openCardHeight) / 2
    }

    /// 收起压暗的中间一档落在露出行底缘（70）处；卡越高（末卡）这一档越靠上。
    static func stripScrimRowLocation(cardHeight: CGFloat) -> Double {
        guard cardHeight > 0 else {
            return 1
        }
        return min(1, Double(S1DeckMetrics.stripVisibleHeight / cardHeight))
    }

    static func seenPercent(processed: Int, total: Int) -> Int {
        guard total > 0 else {
            return 0
        }
        return min(max(processed, 0), total) * 100 / total
    }

    static func isComplete(processed: Int, total: Int) -> Bool {
        total > 0 && processed >= total
    }

    static func opensYearPage(childCount: Int) -> Bool {
        childCount > 0
    }

    static func showsPendingPill(count: Int) -> Bool {
        count > 0
    }

    static func showsNewPill(count: Int) -> Bool {
        count > 0
    }

    /// 「已看 N%」，全部看过写「看完」。
    static func seenText(processed: Int, total: Int) -> String {
        if isComplete(processed: processed, total: total) {
            return L10n.text("s1.deck.done")
        }
        return L10n.text(
            "s1.deck.seen",
            replacing: ["percent": String(seenPercent(processed: processed, total: total))]
        )
    }

    /// 展开卡副文：年卡「N 张 · M 个月 · 已看 N%」，月卡与相册卡「N 张 · 已看 N%」。
    static func openSubtitle(for row: S1RangeRow, kind: S1DeckCardKind) -> String {
        let lead: String
        switch kind {
        case .years:
            lead = L10n.text(
                "s1.deck.year.subtitle",
                replacing: ["count": String(row.totalAssetCount), "months": String(row.childCount)]
            )
        case .months, .albums:
            lead = L10n.text("s1.range.total_count", replacing: ["count": String(row.totalAssetCount)])
        }
        return [lead, seenText(processed: row.processedAssetCount, total: row.totalAssetCount)]
            .joined(separator: separator)
    }

    /// 展开卡按钮：有月范围的年卡「去清理」（进年页），其余「去整理」（进 S2）。
    static func actionTitle(kind: S1DeckCardKind, childCount: Int) -> String {
        if kind == .years, opensYearPage(childCount: childCount) {
            return L10n.text("s1.deck.action.yearPage")
        }
        return L10n.text("s1.deck.action.organize")
    }

    /// 年页汇总行「N 张 · M 个月 · 已看 N% · 待删 N · 新增 N」，待删、新增为零的段不显示。
    static func yearSummary(for row: S1RangeRow) -> String {
        var parts = [
            L10n.text(
                "s1.deck.year.subtitle",
                replacing: ["count": String(row.totalAssetCount), "months": String(row.childCount)]
            ),
            seenText(processed: row.processedAssetCount, total: row.totalAssetCount)
        ]
        if showsPendingPill(count: row.pendingDeletionCount) {
            parts.append(L10n.text("s1.deck.pending", replacing: ["count": String(row.pendingDeletionCount)]))
        }
        if showsNewPill(count: row.newAssetCount) {
            parts.append(L10n.text("s1.deck.new", replacing: ["count": String(row.newAssetCount)]))
        }
        return parts.joined(separator: separator)
    }

    /// 展开与收起同「空间清理」首页一次 spring（SPEC-S1 v12 第六节第 2 部分，取值引 `S0DeckMetrics`）。
    static var expandAnimation: Animation {
        .spring(
            response: S0DeckMetrics.expandAnimationResponse,
            dampingFraction: S0DeckMetrics.expandAnimationDamping
        )
    }

    /// 展开卡内容层的过渡：淡入并自下而上升 `expandContentRise`（同首页）。
    static var openContentTransition: AnyTransition {
        AnyTransition.opacity.combined(
            with: AnyTransition.offset(y: S0DeckMetrics.expandContentRise)
        )
    }
}

/// 已看条与年进度条：轨道 + 薄荷填充，0% 也画轨道。比例沿用 `S1ProgressLinePresentation.fillFraction`。
/// 不接收点击、不进读屏。
struct S1DeckProgressBar: View {
    let processed: Int
    let total: Int
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: S1DeckMetrics.barCornerRadius)
                    .fill(Color.white.opacity(S1DeckMetrics.barTrackOpacity))
                RoundedRectangle(cornerRadius: S1DeckMetrics.barCornerRadius)
                    .fill(S0DeckMetrics.mint)
                    .frame(
                        width: proxy.size.width
                            * S1ProgressLinePresentation.fillFraction(
                                processed: processed,
                                total: total
                            )
                    )
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 收起行左端的已看小圆环：轨道恒画、薄荷填充自 12 点顺时针、圆头；0% 只画轨道。
struct S1DeckSeenRing: View {
    let processed: Int
    let total: Int

    private var fraction: Double {
        S1ProgressLinePresentation.fillFraction(processed: processed, total: total)
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    S1ChromeForeground.primary.opacity(S1DeckMetrics.seenRingTrackOpacity),
                    lineWidth: S1DeckMetrics.seenRingLineWidth
                )
            if fraction > 0 {
                Circle()
                    .inset(by: S1DeckMetrics.seenRingLineWidth / 2)
                    .trim(from: 0, to: CGFloat(fraction))
                    .stroke(
                        S0DeckMetrics.mint,
                        style: StrokeStyle(lineWidth: S1DeckMetrics.seenRingLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(S1DeckMetrics.seenRingStartDegrees))
            }
        }
        .frame(width: S1DeckMetrics.seenRingSide, height: S1DeckMetrics.seenRingSide)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 一张 V1 卡：整卡宽幅封面 + 收起行（自顶向下压暗）或展开内容（自底向上压暗、左上胶囊组、左下文字组、右下按钮标签）。
/// 整卡是一个按钮；命中区 = 圆角矩形（IC-163 裁定 二）。封面一只、尺寸恒为卡宽 × `openCardHeight`，收起时上移露出居中带，
/// 挂 `.id(coverAssetID)` 而**不挂 `.id(isOpen)`**——展开收起同一视图身份、不重新取图（SPEC-S1 v12 决策 34）。
struct S1DeckCardView: View {
    let row: S1RangeRow
    let kind: S1DeckCardKind
    let isOpen: Bool
    let coverAssetID: String?
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: S1DeckMetrics.cardCornerRadius,
            style: .continuous
        )
    }

    private var visibleHeight: CGFloat {
        S1DeckCardPresentation.visibleHeight(isOpen: isOpen)
    }

    /// 文字组与按钮从卡顶 + `openCardHeight` 处向上量（G1）：末卡的延伸只加长卡底与压暗。
    private var openContentBottomExtra: CGFloat {
        height - S1DeckMetrics.openCardHeight
    }

    var body: some View {
        Button(action: onTap) {
            surface
        }
        .buttonStyle(.plain)
    }

    /// 封面与各层内容（照首页先例与外框分成两段，避免一条修饰链过长、类型检查超时——陷阱 16）。
    private var layers: some View {
        ZStack(alignment: .top) {
            S0DeckMetrics.cardBase
            S0DeckCoverView(
                assetIdentifier: coverAssetID,
                width: width,
                height: S1DeckMetrics.openCardHeight
            )
            .id(coverAssetID)
            .offset(y: S1DeckCardPresentation.coverOffset(isOpen: isOpen))
        }
        .frame(width: width, height: height, alignment: .top)
        .overlay {
            if !isOpen {
                stripScrim
            }
        }
        .overlay(alignment: .top) {
            if isOpen {
                openScrim
                    .frame(height: visibleHeight)
            }
        }
        // 可见区之下保持渐变末档压暗至卡底；非末卡这一层被下一张卡盖住。
        .overlay(alignment: .bottom) {
            if isOpen {
                Color.black.opacity(S1DeckMetrics.openScrimBottomOpacity)
                    .frame(height: height - visibleHeight)
            }
        }
        .overlay(alignment: .topLeading) {
            if isOpen {
                openChips
                    .padding(S1DeckMetrics.openChipInset)
                    .transition(S1DeckCardPresentation.openContentTransition)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isOpen {
                openTextBlock
                    .padding(.leading, S1DeckMetrics.openTextLeadingInset)
                    .padding(.trailing, S1DeckMetrics.openTextTrailingInset)
                    .padding(.bottom, openContentBottomExtra + S1DeckMetrics.openTextBottomInset)
                    .transition(S1DeckCardPresentation.openContentTransition)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isOpen {
                actionLabel
                    .padding(.trailing, S1DeckMetrics.ctaTrailingInset)
                    .padding(.bottom, openContentBottomExtra + S1DeckMetrics.ctaBottomInset)
                    .transition(S1DeckCardPresentation.openContentTransition)
            }
        }
        .overlay(alignment: .top) {
            if !isOpen {
                stripRow
                    .frame(height: S1DeckMetrics.stripVisibleHeight)
                    .transition(.opacity)
            }
        }
    }

    /// 外框：裁成圆角矩形、命中区同形、两道内描边、上缘阴影。
    private var surface: some View {
        layers
        .clipShape(shape)
        .contentShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.white.opacity(S1DeckMetrics.cardRingOpacity),
                lineWidth: S1DeckMetrics.cardEdgeWidth
            )
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(S1DeckMetrics.cardHighlightOpacity),
                        Color.white.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: S1DeckMetrics.cardEdgeWidth
            )
        }
        .shadow(
            color: Color.black.opacity(S1DeckMetrics.cardShadowOpacity),
            radius: S1DeckMetrics.cardShadowRadius,
            y: S1DeckMetrics.cardShadowYOffset
        )
    }

    // MARK: - 压暗

    private var stripScrim: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: S1DeckMetrics.stripScrimColor.opacity(S1DeckMetrics.stripScrimTopOpacity),
                    location: 0
                ),
                Gradient.Stop(
                    color: S1DeckMetrics.stripScrimColor.opacity(S1DeckMetrics.stripScrimRowOpacity),
                    location: S1DeckCardPresentation.stripScrimRowLocation(cardHeight: height)
                ),
                Gradient.Stop(
                    color: S1DeckMetrics.stripScrimColor.opacity(S1DeckMetrics.stripScrimBottomOpacity),
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var openScrim: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: Color.black.opacity(S1DeckMetrics.openScrimTopOpacity),
                    location: 0
                ),
                Gradient.Stop(
                    color: Color.black.opacity(0),
                    location: S1DeckMetrics.openScrimClearLocation
                ),
                Gradient.Stop(
                    color: Color.black.opacity(S1DeckMetrics.openScrimMiddleOpacity),
                    location: S1DeckMetrics.openScrimMiddleLocation
                ),
                Gradient.Stop(
                    color: Color.black.opacity(S1DeckMetrics.openScrimBottomOpacity),
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - 收起行

    private var stripRow: some View {
        HStack(spacing: S1DeckMetrics.stripItemSpacing) {
            S1DeckSeenRing(
                processed: row.processedAssetCount,
                total: row.totalAssetCount
            )
            Text(row.displayName)
                .font(.system(size: S1DeckMetrics.stripNameFontSize, weight: .semibold))
                .foregroundStyle(S1ChromeForeground.primary)
                .lineLimit(1)
            if S1DeckCardPresentation.showsPendingPill(count: row.pendingDeletionCount) {
                pendingPill
                    .fixedSize()
            }
            if S1DeckCardPresentation.showsNewPill(count: row.newAssetCount) {
                newPill(L10n.text("s1.deck.new", replacing: ["count": String(row.newAssetCount)]))
                    .fixedSize()
            }
            // 占比右对齐、占据剩余宽：留白可缩到零，再往下只压缩名字（决策 22 v12）。
            Spacer(minLength: 0)
            if let sharePercent = row.sharePercent {
                Text(String(sharePercent) + S0DeckSymbol.percentSign)
                    .font(.system(size: S1DeckMetrics.stripShareFontSize).monospacedDigit())
                    .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.stripShareOpacity))
                    .fixedSize()
            }
            stripValue
                .fixedSize()
            Image(systemName: S0DeckSymbol.chevron)
                .font(.system(size: S1DeckMetrics.stripChevronPointSize, weight: .semibold))
                .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.stripChevronOpacity))
        }
        .padding(.leading, S1DeckMetrics.stripLeadingInset)
        .padding(.trailing, S1DeckMetrics.stripTrailingInset)
    }

    @ViewBuilder
    private var stripValue: some View {
        if let byteCount = row.byteCount {
            let parts = S0ByteCountSplit.split(S0ByteCountText.string(forByteCount: byteCount))
            HStack(alignment: .lastTextBaseline, spacing: S1DeckMetrics.stripUnitSpacing) {
                Text(parts.value)
                    .font(.system(size: S1DeckMetrics.stripValueFontSize, weight: .heavy).monospacedDigit())
                    .kerning(S1DeckMetrics.stripValueKerning)
                    .foregroundStyle(S1ChromeForeground.primary)
                Text(parts.unit)
                    .font(.system(size: S1DeckMetrics.stripUnitFontSize))
                    .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.stripUnitOpacity))
            }
            .lineLimit(1)
        } else {
            Text(L10n.text("s1.volume.counting"))
                .font(.system(size: S1DeckMetrics.stripUnitFontSize, weight: .semibold))
                .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.stripUnitOpacity))
                .lineLimit(1)
        }
    }

    // MARK: - 胶囊

    private var pendingPill: some View {
        Text(
            L10n.text(
                "s1.deck.pending",
                replacing: ["count": String(row.pendingDeletionCount)]
            )
        )
        .font(.system(size: S1DeckMetrics.pillFontSize, weight: .bold).monospacedDigit())
        .foregroundStyle(S1NotificationBadgeStyle.digitColor)
        .lineLimit(1)
        .padding(.horizontal, S1DeckMetrics.pillHorizontalPadding)
        .frame(height: S1DeckMetrics.pillHeight)
        .background(S0DeckMetrics.accent, in: Capsule())
        // 读屏口径沿用旧红点角标的那条 key（目录 key 双向一致：删旧角标后它仍有引用）。
        .accessibilityLabel(
            L10n.text(
                "s1.range.pending_count",
                replacing: ["count": String(row.pendingDeletionCount)]
            )
        )
    }

    private func newPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: S1DeckMetrics.pillFontSize, weight: .bold).monospacedDigit())
            .foregroundStyle(S0DeckMetrics.mint)
            .lineLimit(1)
            .padding(.horizontal, S1DeckMetrics.pillHorizontalPadding)
            .frame(height: S1DeckMetrics.pillHeight)
            .background(
                S1ChromeForeground.pageBackground.opacity(S1DeckMetrics.newPillFillOpacity),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        S0DeckMetrics.mint.opacity(S1DeckMetrics.newPillRingOpacity),
                        lineWidth: S1DeckMetrics.newPillRingWidth
                    )
            }
    }

    // MARK: - 展开卡

    private var openChips: some View {
        HStack(spacing: S1DeckMetrics.openChipSpacing) {
            if let sharePercent = row.sharePercent {
                Text(L10n.text("s1.deck.share", replacing: ["percent": String(sharePercent)]))
                    .font(.system(size: S1DeckMetrics.shareChipFontSize, weight: .bold).monospacedDigit())
                    .foregroundStyle(S1ChromeForeground.primary)
                    .lineLimit(1)
                    .padding(.horizontal, S1DeckMetrics.shareChipHorizontalPadding)
                    .frame(height: S1DeckMetrics.shareChipHeight)
                    .background(
                        S1DeckMetrics.shareChipFill.opacity(S1DeckMetrics.shareChipFillOpacity),
                        in: Capsule()
                    )
            }
            if S1DeckCardPresentation.showsPendingPill(count: row.pendingDeletionCount) {
                pendingPill
            }
            if S1DeckCardPresentation.showsNewPill(count: row.newAssetCount) {
                newPill(L10n.text("s1.deck.new.open", replacing: ["count": String(row.newAssetCount)]))
            }
        }
        .fixedSize()
    }

    private var openTextBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(row.displayName)
                    .font(.system(size: S1DeckMetrics.openNameFontSize, weight: .semibold))
                    .lineLimit(1)
                openValue
                Text(S1DeckCardPresentation.openSubtitle(for: row, kind: kind))
                    .font(.system(size: S1DeckMetrics.openSubtitleFontSize).monospacedDigit())
                    .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.openSubtitleOpacity))
                    .lineLimit(1)
                    .padding(.top, S1DeckMetrics.openSubtitleTopSpacing)
            }
            .foregroundStyle(S1ChromeForeground.primary)
            .shadow(
                color: Color.black.opacity(S1DeckMetrics.openTextShadowOpacity),
                radius: S1DeckMetrics.openTextShadowRadius,
                y: S1DeckMetrics.openTextShadowYOffset
            )
            S1DeckProgressBar(
                processed: row.processedAssetCount,
                total: row.totalAssetCount,
                height: S1DeckMetrics.barHeight
            )
            .frame(width: S1DeckMetrics.openBarWidth)
            .padding(.top, S1DeckMetrics.openBarTopSpacing)
        }
    }

    @ViewBuilder
    private var openValue: some View {
        if let byteCount = row.byteCount {
            Text(S0ByteCountText.string(forByteCount: byteCount))
                .font(.system(size: S1DeckMetrics.openValueFontSize, weight: .heavy).monospacedDigit())
                .kerning(S1DeckMetrics.openValueKerning)
                .lineLimit(1)
        } else {
            Text(L10n.text("s1.volume.counting"))
                .font(.system(size: S1DeckMetrics.openValueFontSize, weight: .semibold))
                .lineLimit(1)
        }
    }

    /// 「去清理 ›」「去整理 ›」是卡上的标签不是另一只按钮：整张展开卡即入口（首页裁定 五先例）。
    private var actionLabel: some View {
        HStack(spacing: S1DeckMetrics.ctaItemSpacing) {
            Text(S1DeckCardPresentation.actionTitle(kind: kind, childCount: row.childCount))
                .font(.system(size: S1DeckMetrics.ctaFontSize, weight: .bold))
            Image(systemName: S0DeckSymbol.chevron)
                .font(.system(size: S1DeckMetrics.ctaChevronPointSize, weight: .bold))
        }
        .foregroundStyle(S1ChromeForeground.pageBackground)
        .lineLimit(1)
        .padding(.leading, S1DeckMetrics.ctaLeadingPadding)
        .padding(.trailing, S1DeckMetrics.ctaTrailingPadding)
        .frame(height: S1DeckMetrics.ctaHeight)
        .background(S1ChromeForeground.primary, in: Capsule())
    }
}

/// 一叠卡：恰一张展开（`openIndex`），其余收起为一行；后一张压在前一张可见区之下，后画的卡 `zIndex` 更高，被压住的
/// 部分不可命中（命中区已裁成圆角矩形）。**非惰性**：全部卡的封面在出现时一起请求。
struct S1DeckStack: View {
    let rows: [S1RangeRow]
    let kind: S1DeckCardKind
    let openIndex: Int?
    let width: CGFloat
    let coverAssetID: (S1RangeRow) -> String?
    let onTap: (S1RangeRow, Bool) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { item in
                S1DeckCardView(
                    row: item.element,
                    kind: kind,
                    isOpen: item.offset == openIndex,
                    coverAssetID: coverAssetID(item.element),
                    width: width,
                    height: S1DeckCardPresentation.cardHeight(
                        index: item.offset,
                        count: rows.count,
                        isOpen: item.offset == openIndex
                    ),
                    onTap: { onTap(item.element, item.offset == openIndex) }
                )
                .zIndex(Double(item.offset))
                .offset(y: S1DeckCardPresentation.offset(index: item.offset, openIndex: openIndex))
            }
        }
        .frame(
            width: width,
            height: S1DeckCardPresentation.stackHeight(count: rows.count, openIndex: openIndex),
            alignment: .top
        )
    }
}

/// 「逐张整理」的卡叠本体（列表页一级范围、年页月卡同用）：自己观察展开态（点卡只重画卡叠，不让观察状态机的整页重算，
/// IC-191），按槽位读列表页或年页那一只。点收起的卡 → 在首页同一 spring 里展开它；点展开卡 → 交给调用方进入
/// （有月范围的年卡进年页，其余进 S2）。滚动交给页面那只 `ScrollView`，本视图按叠高占位。
struct S1DeckListView: View {
    let rows: [S1RangeRow]
    let kind: S1DeckCardKind
    @ObservedObject var openCards: S1OpenCardState
    let slot: S1DeckOpenSlot
    let coverAssetID: (S1RangeRow) -> String?
    let onOpen: (S1RangeRow) -> Void
    let onEnter: (S1RangeRow) -> Void

    private var openIndex: Int? {
        let rangeID: String?
        switch slot {
        case .list:
            rangeID = openCards.listRangeID
        case .yearPage:
            rangeID = openCards.yearPageRangeID
        }
        return S1DeckCardPresentation.openIndex(of: rangeID, in: rows.map(\.id))
    }

    var body: some View {
        GeometryReader { geometry in
            S1DeckStack(
                rows: rows,
                kind: kind,
                openIndex: openIndex,
                width: max(0, geometry.size.width - S1DeckMetrics.deckHorizontalInset * 2),
                coverAssetID: coverAssetID,
                onTap: { row, isOpen in
                    if isOpen {
                        onEnter(row)
                    } else {
                        withAnimation(S1DeckCardPresentation.expandAnimation) {
                            onOpen(row)
                        }
                    }
                }
            )
            .padding(.horizontal, S1DeckMetrics.deckHorizontalInset)
        }
        .frame(height: S1DeckCardPresentation.stackHeight(count: rows.count, openIndex: openIndex))
    }
}
