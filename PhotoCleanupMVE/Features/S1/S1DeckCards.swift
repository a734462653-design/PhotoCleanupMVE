import SwiftUI

// MARK: - IC-178 A：年卡叠／月卡叠（Decision_log 第 205 条第二节第 1 条；R2 画布 `Tasks/design-s1-r2/gen.py`）

/// 「逐张整理」范围列表 (i) 年卡叠 → 年页的视觉登记。取值全部出自 R2 画布（`gen.py` 的 `.ph`／`.edge`／
/// `.pend`／`.bar`／`card_head`／`cover_card`／`year_stack`／`month_stack`／`i_year_page`／`album_s1`），CSS 的
/// px 按 pt 读；阴影照 `S0DeckMetrics` 的先例把 blur px 直接登记为 radius。色不在此登记：文字、描边与压暗走
/// `S1ChromeForeground`，薄荷与强调走 `S0DeckMetrics`。卡内暂登，SPEC-S1 v11 第十一节回填；**不进**
/// `S2CalibrationConfiguration`、不上标定面板。
enum S1DeckMetrics {
    // MARK: 叠与卡（`cover_card`／`year_stack`／`month_stack`／`album_s1`）

    /// 叠的左右边距（`cover_card` `left 16`／`right 16`）。
    static let horizontalMargin: CGFloat = 16
    /// 卡圆角（`cover_card` `radius=28`；与 `S0DeckMetrics.cardCornerRadius` 同值，各自登记）。
    static let cardCornerRadius: CGFloat = 28
    /// 卡高（`h = 170`）。
    static let cardHeight: CGFloat = 170
    /// 末卡高（`h = 190`，整张露出）。
    static let lastCardHeight: CGFloat = 190
    /// 年卡叠步长（`year_stack` `step=72`）。
    static let yearStep: CGFloat = 72
    /// 月卡叠步长（`i_year_page` 里 `month_stack(220, …, step=80)`）。
    static let monthStep: CGFloat = 80
    /// 相册／未分类叠步长（`album_s1` `step=84`）。
    static let albumStep: CGFloat = 84
    /// 叠底部留白（`i_s1` 全长 `… + 190 + 24`）。
    static let stackBottomPadding: CGFloat = 24
    /// 卡上缘阴影（`box-shadow: 0 -10px 24px rgba(0,0,0,0.45)`）。
    static let cardShadowOpacity: Double = 0.45
    static let cardShadowRadius: CGFloat = 24
    static let cardShadowYOffset: CGFloat = -10
    /// 卡外圈描边宽（`.edge` `inset 0 0 0 0.5px`；色 = `S1ChromeForeground.separator`，同为 0.14）。
    static let cardRingWidth: CGFloat = 0.5
    /// 卡面压暗渐变（`linear-gradient(180deg, rgba(11,15,13,0.78) 0%, rgba(11,15,13,0.18) 46%, rgba(11,15,13,0) 70%)`；
    /// 色 = 页面底色）。
    static let scrimTopOpacity: Double = 0.78
    static let scrimMiddleOpacity: Double = 0.18
    static let scrimMiddleLocation: Double = 0.46
    static let scrimEndLocation: Double = 0.70

    // MARK: 卡头（`card_head`）

    /// 卡头内距（`left 20`／`right 16`／`top 16`）与横排间距（`gap 10`）。
    static let headLeadingInset: CGFloat = 20
    static let headTrailingInset: CGFloat = 16
    static let headTopInset: CGFloat = 16
    static let headSpacing: CGFloat = 10
    /// 年卡标题 26、月卡与相册卡标题 24，皆 800 字重、字距 −0.4。
    static let yearTitleFontSize: CGFloat = 26
    static let monthTitleFontSize: CGFloat = 24
    static let titleKerning: CGFloat = -0.4
    /// 副文（`.dim` 13.5／500）。
    static let subtitleFontSize: CGFloat = 13.5
    /// 「待删 N」胶囊（`.pend`：高 24、内距 0 9、13／700、强调色底白字）。
    static let pendingPillHeight: CGFloat = 24
    static let pendingPillHorizontalPadding: CGFloat = 9
    static let pendingPillFontSize: CGFloat = 13
    /// 「已看 N%」（`.dim` 13／600）与「看完」（薄荷 13／700 + 勾 15，间距 4）。
    static let seenFontSize: CGFloat = 13
    static let doneSymbolPointSize: CGFloat = 15
    static let doneSpacing: CGFloat = 4

    // MARK: 进度条（`.bar`）

    /// 卡上进度条：左右内缩 20、距卡顶 54、高 3、圆角 2。
    static let barHorizontalInset: CGFloat = 20
    static let barTopInset: CGFloat = 54
    static let barHeight: CGFloat = 3
    static let barCornerRadius: CGFloat = 2
    /// 轨道（`rgba(255,255,255,0.18)`，落在前景色上）；填充 = `S0DeckMetrics.mint`。0% 也画轨道。
    static let barTrackOpacity: Double = 0.18

    // MARK: 年页（`i_year_page`）

    /// 年标题 40／900、字距 −1.2、行高 44。
    static let yearPageTitleFontSize: CGFloat = 40
    static let yearPageTitleKerning: CGFloat = -1.2
    static let yearPageTitleRowHeight: CGFloat = 44
    /// 顶排底缘 → 标题行顶（110 − 58 − 44）。
    static let yearPageTitleRowTopSpacing: CGFloat = 8
    /// 「整理整年」（`.btns` 覆写：高 40、内距 0 14、底 0.10、15／600、前置符号 18、间距 6）。
    static let organizeButtonHeight: CGFloat = 40
    static let organizeButtonHorizontalPadding: CGFloat = 14
    static let organizeButtonFillOpacity: Double = 0.10
    static let organizeButtonFontSize: CGFloat = 15
    static let organizeButtonSymbolPointSize: CGFloat = 18
    static let organizeButtonSpacing: CGFloat = 6
    /// 汇总行（`.dim` 14；标题行底 → 汇总行顶 = 160 − 154）。
    static let summaryFontSize: CGFloat = 14
    static let summaryTopSpacing: CGFloat = 6
    /// 汇总行底 → 年进度条顶（190 − 160 − 14 pt 字的行高约 17 → 13）；年进度条高 4；条底 → 月卡叠顶（220 − 194）。
    static let yearBarTopSpacing: CGFloat = 13
    static let yearBarHeight: CGFloat = 4
    static let monthStackTopSpacing: CGFloat = 26
}

/// 卡片叠与年页用到的 SF Symbol 名（决策会话取定；R2 画布只给了线条图标 `back`／`stack`／`check`）。
/// 待删篮入口的垃圾桶由 `S0BasketEntryView` 自带，不在此登记。
enum S1DeckSymbol {
    static let back = "chevron.left"
    static let organizeAll = "rectangle.stack"
    static let done = "checkmark"
}

/// 一叠卡是哪一种：年卡（`T=按日期` 的一级范围）、月卡（年页）、相册／未分类卡（其他维度的一级范围，月卡样式）。
enum S1DeckCardKind: Equatable {
    case years
    case months
    case albums
}

/// 卡片叠的展示口径（测试钉住）。
///
/// - 步长与标题字号按种类；末卡整张露出（190），其余 170；叠高 = 步长 ×（n − 1）+ 末卡高，空叠为 0。
/// - 「已看 N%」= 该范围自己的已处理数 ÷ 总数，整数向下取、钳到 [0, 100]；只有全部处理完才是 100 与「看完」
///   （年卡看年范围自己的 `K[year]`，不并各月——④ 口径待 Lynn，第 212 条）。
/// - 有子节点的卡进年页，其余直接进 S2（与 IC-127 A 的 `hasExpandZone(childCount:)` 同一判据）。
enum S1DeckCardPresentation {
    static func step(for kind: S1DeckCardKind) -> CGFloat {
        switch kind {
        case .years:
            return S1DeckMetrics.yearStep
        case .months:
            return S1DeckMetrics.monthStep
        case .albums:
            return S1DeckMetrics.albumStep
        }
    }

    static func titleFontSize(for kind: S1DeckCardKind) -> CGFloat {
        switch kind {
        case .years:
            return S1DeckMetrics.yearTitleFontSize
        case .months, .albums:
            return S1DeckMetrics.monthTitleFontSize
        }
    }

    static func showsMonthCount(for kind: S1DeckCardKind) -> Bool {
        kind == .years
    }

    static func cardHeight(index: Int, count: Int) -> CGFloat {
        index == count - 1 ? S1DeckMetrics.lastCardHeight : S1DeckMetrics.cardHeight
    }

    static func stackHeight(count: Int, kind: S1DeckCardKind) -> CGFloat {
        guard count > 0 else {
            return 0
        }
        return CGFloat(count - 1) * step(for: kind) + S1DeckMetrics.lastCardHeight
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
}

/// 进度条：轨道 + 薄荷填充，0% 也画轨道（与 IC-128 B「不在 `K` 就不画」的刻度线不同——SPEC-S1 v11 回填）。
/// 比例沿用 `S1ProgressLinePresentation.fillFraction`。不接收点击、不进读屏。
struct S1DeckProgressBar: View {
    let processed: Int
    let total: Int
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: S1DeckMetrics.barCornerRadius)
                    .fill(S1ChromeForeground.primary.opacity(S1DeckMetrics.barTrackOpacity))
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

/// 一张封面卡：整卡封面（`S0DeckCoverView`，宽幅取图）+ 压暗渐变 + 卡头（标题、副文、「待删 N」、
/// 「已看 N%」／「看完」）+ 进度条。整卡是一个按钮；命中区 = 圆角矩形（IC-163 裁定 二），图层先框后裁
/// （陷阱 24）；封面挂 `.id(coverAssetID)`（`S0DeckCoverView` 两道换图防护的第二道）。
struct S1DeckCardView: View {
    let row: S1RangeRow
    let kind: S1DeckCardKind
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

    var body: some View {
        Button(action: onTap) {
            S0DeckCoverView(
                assetIdentifier: coverAssetID,
                width: width,
                height: height
            )
            .id(coverAssetID)
            .overlay {
                scrim
            }
            .overlay(alignment: .top) {
                head
                    .padding(.leading, S1DeckMetrics.headLeadingInset)
                    .padding(.trailing, S1DeckMetrics.headTrailingInset)
                    .padding(.top, S1DeckMetrics.headTopInset)
            }
            .overlay(alignment: .top) {
                S1DeckProgressBar(
                    processed: row.processedAssetCount,
                    total: row.totalAssetCount,
                    height: S1DeckMetrics.barHeight
                )
                .padding(.horizontal, S1DeckMetrics.barHorizontalInset)
                .padding(.top, S1DeckMetrics.barTopInset)
            }
            .clipShape(shape)
            .contentShape(shape)
            .overlay {
                shape.strokeBorder(
                    S1ChromeForeground.separator,
                    lineWidth: S1DeckMetrics.cardRingWidth
                )
            }
            .shadow(
                color: Color.black.opacity(S1DeckMetrics.cardShadowOpacity),
                radius: S1DeckMetrics.cardShadowRadius,
                y: S1DeckMetrics.cardShadowYOffset
            )
        }
        .buttonStyle(.plain)
    }

    private var scrim: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: S1ChromeForeground.pageBackground.opacity(S1DeckMetrics.scrimTopOpacity),
                    location: 0
                ),
                Gradient.Stop(
                    color: S1ChromeForeground.pageBackground.opacity(S1DeckMetrics.scrimMiddleOpacity),
                    location: S1DeckMetrics.scrimMiddleLocation
                ),
                Gradient.Stop(
                    color: S1ChromeForeground.pageBackground.opacity(0),
                    location: S1DeckMetrics.scrimEndLocation
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var head: some View {
        HStack(spacing: S1DeckMetrics.headSpacing) {
            Text(row.displayName)
                .font(
                    .system(
                        size: S1DeckCardPresentation.titleFontSize(for: kind),
                        weight: .heavy
                    )
                )
                .kerning(S1DeckMetrics.titleKerning)
                .foregroundStyle(S1ChromeForeground.primary)
                .lineLimit(1)
                // 放不下时先截副文，年份／月名不截（画布 `white-space: nowrap` 溢出不截，这里必须选一个让）。
                .layoutPriority(1)
            Text(subtitle)
                .font(.system(size: S1DeckMetrics.subtitleFontSize, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(S1ChromeForeground.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            // 右侧两件不收缩：一行放不下时只有副文被截。
            if S1DeckCardPresentation.showsPendingPill(count: row.pendingDeletionCount) {
                pendingPill
                    .fixedSize()
            }
            seenLabel
                .fixedSize()
        }
    }

    /// 年卡「N 张 · M 个月」；月卡与相册卡「N 张」（借既有 key）。
    private var subtitle: String {
        if S1DeckCardPresentation.showsMonthCount(for: kind) {
            return L10n.text(
                "s1.deck.year.subtitle",
                replacing: [
                    "count": String(row.totalAssetCount),
                    "months": String(row.childCount)
                ]
            )
        }
        return L10n.text(
            "s1.range.total_count",
            replacing: ["count": String(row.totalAssetCount)]
        )
    }

    private var pendingPill: some View {
        Text(
            L10n.text(
                "s1.deck.pending",
                replacing: ["count": String(row.pendingDeletionCount)]
            )
        )
        .font(.system(size: S1DeckMetrics.pendingPillFontSize, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(S1NotificationBadgeStyle.digitColor)
        .lineLimit(1)
        .padding(.horizontal, S1DeckMetrics.pendingPillHorizontalPadding)
        .frame(height: S1DeckMetrics.pendingPillHeight)
        .background(S1ChromeForeground.accent, in: Capsule())
        // 读屏口径沿用旧红点角标的那条 key（目录 key 双向一致：删旧角标后它仍有引用）。
        .accessibilityLabel(
            L10n.text(
                "s1.range.pending_count",
                replacing: ["count": String(row.pendingDeletionCount)]
            )
        )
    }

    @ViewBuilder
    private var seenLabel: some View {
        if S1DeckCardPresentation.isComplete(
            processed: row.processedAssetCount,
            total: row.totalAssetCount
        ) {
            HStack(spacing: S1DeckMetrics.doneSpacing) {
                Image(systemName: S1DeckSymbol.done)
                    .font(
                        .system(
                            size: S1DeckMetrics.doneSymbolPointSize,
                            weight: .bold
                        )
                    )
                Text(L10n.text("s1.deck.done"))
                    .font(.system(size: S1DeckMetrics.seenFontSize, weight: .bold))
            }
            .foregroundStyle(S0DeckMetrics.mint)
            .lineLimit(1)
        } else {
            Text(
                L10n.text(
                    "s1.deck.seen",
                    replacing: [
                        "percent": String(
                            S1DeckCardPresentation.seenPercent(
                                processed: row.processedAssetCount,
                                total: row.totalAssetCount
                            )
                        )
                    ]
                )
            )
            .font(.system(size: S1DeckMetrics.seenFontSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(S1ChromeForeground.secondary)
            .lineLimit(1)
        }
    }
}

/// 一叠卡：后一张压在前一张下缘之上（步长按种类），末卡整张露出；容器高 = 步长 ×（n − 1）+ 末卡高。
/// 后画的卡 `zIndex` 更高，被压住的部分不可命中（命中区已裁成圆角矩形）。**非惰性**：全部卡的封面在出现时
/// 一起请求（③ 相册维度数量无上限时的代价未实测，报告登记）。
struct S1DeckStack: View {
    let rows: [S1RangeRow]
    let kind: S1DeckCardKind
    let width: CGFloat
    let coverAssetID: (S1RangeRow) -> String?
    let onTap: (S1RangeRow) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { item in
                S1DeckCardView(
                    row: item.element,
                    kind: kind,
                    coverAssetID: coverAssetID(item.element),
                    width: width,
                    height: S1DeckCardPresentation.cardHeight(
                        index: item.offset,
                        count: rows.count
                    ),
                    onTap: { onTap(item.element) }
                )
                .zIndex(Double(item.offset))
                .offset(y: CGFloat(item.offset) * S1DeckCardPresentation.step(for: kind))
            }
        }
        .frame(
            width: width,
            height: S1DeckCardPresentation.stackHeight(count: rows.count, kind: kind),
            alignment: .top
        )
    }
}

/// 「逐张整理」范围列表本体：一叠一级范围卡，可滚动；左右边距与底部留白按登记值。页头、四态与菜单仍在
/// `S1View`，本视图只收行、种类、封面取法与点击回调。
struct S1DeckListView: View {
    let rows: [S1RangeRow]
    let kind: S1DeckCardKind
    let coverAssetID: (S1RangeRow) -> String?
    let onTap: (S1RangeRow) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                S1DeckStack(
                    rows: rows,
                    kind: kind,
                    width: max(0, geometry.size.width - S1DeckMetrics.horizontalMargin * 2),
                    coverAssetID: coverAssetID,
                    onTap: onTap
                )
                .padding(.horizontal, S1DeckMetrics.horizontalMargin)
                .padding(.bottom, S1DeckMetrics.stackBottomPadding)
            }
        }
    }
}
