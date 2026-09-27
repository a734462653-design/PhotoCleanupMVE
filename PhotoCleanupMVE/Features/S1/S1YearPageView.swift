import SwiftUI

/// IC-178 A：年页（Decision_log 第 205 条第二节第 1 条；R2 画布 `i_year_page`）。
///
/// - 顶排：返回圆钮（左）+ 待删篮入口（右，借 S0 的 `S0BasketEntryView`——同一只 S1 徽标样式与同一条
///   读屏 key，首页顶排、类别页页头、收起导航条之后的第四处）。
/// - 正文：年标题 +「整理整年」（进 S2 年范围）、汇总行「N 张 · M 个月 · 已看 X% · 待删 Y」、年进度条、
///   月卡叠（点月卡进 S2 月范围）。年进度与汇总里的「已看」都看年范围自己的 `K[year]`（④ 口径待 Lynn）。
/// - 身份在 `S1StateMachine.presentedYearRangeID`，本视图只收数据与回调；由 `S1View` 的 `NavigationStack`
///   推出，隐藏系统导航栏与 tab bar（照类别页 `S0DeckCategoryPageView`；R2 年页板没有 tab bar）。
/// - 色只走 `S1ChromeForeground`／`S0DeckMetrics`；玻璃只走 S1 圆钮 helper（自带深色覆盖，第 203 条）。
struct S1YearPageView: View {
    let yearRow: S1RangeRow
    let monthRows: [S1RangeRow]
    let basketCount: Int
    let coverAssetID: (S1RangeRow) -> String?
    let onBack: () -> Void
    let onOrganizeYear: () -> Void
    let onEnterMonth: (S1RangeRow) -> Void
    let onTrash: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            S1ChromeForeground.pageBackground
                .ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        titleRow
                        summary
                            .padding(.top, S1DeckMetrics.summaryTopSpacing)
                        S1DeckProgressBar(
                            processed: yearRow.processedAssetCount,
                            total: yearRow.totalAssetCount,
                            height: S1DeckMetrics.yearBarHeight
                        )
                        .padding(.horizontal, S1DeckMetrics.barHorizontalInset)
                        .padding(.top, S1DeckMetrics.yearBarTopSpacing)
                        S1DeckStack(
                            rows: monthRows,
                            kind: .months,
                            width: max(0, geometry.size.width - S1DeckMetrics.horizontalMargin * 2),
                            coverAssetID: coverAssetID,
                            onTap: onEnterMonth
                        )
                        .padding(.horizontal, S1DeckMetrics.horizontalMargin)
                        .padding(.top, S1DeckMetrics.monthStackTopSpacing)
                        .padding(.bottom, S1DeckMetrics.stackBottomPadding)
                    }
                    .padding(
                        .top,
                        S1ChromeLayout.topRowTopInset
                            + S1ChromeLayout.rowHeight
                            + S1DeckMetrics.yearPageTitleRowTopSpacing
                    )
                }
            }
            topRow
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - 顶排（借 S1 chrome 与 S0 待删篮入口，零新几何）

    private var topRow: some View {
        HStack(spacing: S1ChromeLayout.itemSpacing) {
            Button(action: onBack) {
                Image(systemName: S1DeckSymbol.back)
                    .foregroundStyle(S1ChromeForeground.primary)
                    .s1ChromeCircleGlass()
            }
            .accessibilityLabel(L10n.text("s1.yearPage.back"))
            Spacer(minLength: 0)
            S0BasketEntryView(style: .glass, count: basketCount, action: onTrash)
        }
        .frame(height: S1ChromeLayout.rowHeight)
        .padding(.horizontal, S1ChromeLayout.horizontalMargin)
        .padding(.top, S1ChromeLayout.topRowTopInset)
    }

    // MARK: - 标题行、汇总行

    private var titleRow: some View {
        HStack(spacing: S1DeckMetrics.headSpacing) {
            Text(yearRow.displayName)
                .font(
                    .system(
                        size: S1DeckMetrics.yearPageTitleFontSize,
                        weight: .black
                    )
                )
                .kerning(S1DeckMetrics.yearPageTitleKerning)
                .foregroundStyle(S1ChromeForeground.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            organizeButton
        }
        .frame(height: S1DeckMetrics.yearPageTitleRowHeight)
        .padding(.leading, S1DeckMetrics.headLeadingInset)
        .padding(.trailing, S1DeckMetrics.headTrailingInset)
    }

    private var organizeButton: some View {
        Button(action: onOrganizeYear) {
            HStack(spacing: S1DeckMetrics.organizeButtonSpacing) {
                Image(systemName: S1DeckSymbol.organizeAll)
                    .font(
                        .system(
                            size: S1DeckMetrics.organizeButtonSymbolPointSize,
                            weight: .semibold
                        )
                    )
                Text(L10n.text("s1.yearPage.organizeAll"))
                    .font(
                        .system(
                            size: S1DeckMetrics.organizeButtonFontSize,
                            weight: .semibold
                        )
                    )
            }
            .foregroundStyle(S1ChromeForeground.primary)
            .lineLimit(1)
            .padding(.horizontal, S1DeckMetrics.organizeButtonHorizontalPadding)
            .frame(height: S1DeckMetrics.organizeButtonHeight)
            .background(
                S1ChromeForeground.primary.opacity(S1DeckMetrics.organizeButtonFillOpacity),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private var summary: some View {
        Text(
            L10n.text(
                "s1.yearPage.summary",
                replacing: [
                    "count": String(yearRow.totalAssetCount),
                    "months": String(yearRow.childCount),
                    "percent": String(
                        S1DeckCardPresentation.seenPercent(
                            processed: yearRow.processedAssetCount,
                            total: yearRow.totalAssetCount
                        )
                    ),
                    "pending": String(yearRow.pendingDeletionCount)
                ]
            )
        )
        .font(.system(size: S1DeckMetrics.summaryFontSize))
        .monospacedDigit()
        .foregroundStyle(S1ChromeForeground.secondary)
        .lineLimit(1)
        .padding(.horizontal, S1DeckMetrics.barHorizontalInset)
    }
}
