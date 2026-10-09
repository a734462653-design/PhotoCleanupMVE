import SwiftUI

/// IC-178 A／IC-193：年页（SPEC-S1 v12 第六节第 2 部分「年页」、第十一节第 2d 部分；R3 画布 `v1_year_page`）。
///
/// - 顶排：返回圆钮（左）+ 待删篮入口（右，借 S0 的 `S0BasketEntryView`——同一只 S1 徽标样式与同一条读屏 key）；
///   钉在页面上方，正文在其下滚动（v11 年页现状）。
/// - 标题区（V1）：大号年份、其下「X GB」+「占全部 N%」（体积或占比未知整行「统计中」）、右侧「整理整年」（进 S2 年范围）；
///   汇总行「N 张 · M 个月 · 已看 N% · 待删 N · 新增 N」（待删、新增为零不显示）、年进度条；纵向位置照 IC-192 落成
///   距顶排底缘的绝对上距，块高 = 月卡叠顶。
/// - 月卡叠：与列表页同一只 `S1DeckListView`（槽位 `.yearPage`，恰一张展开）；点收起的月卡展开它，点展开月卡进 S2 月范围。
/// - 身份在 `S1StateMachine.presentedYearRangeID`，本视图只收数据与回调；由 `S1View` 的 `NavigationStack` 推出，隐藏
///   系统导航栏与 tab bar。
/// - 色只走 `S1ChromeForeground`／`S0DeckMetrics`；玻璃只走 S1 圆钮 helper（自带深色覆盖，第 203 条）。
struct S1YearPageView: View {
    let yearRow: S1RangeRow
    let monthRows: [S1RangeRow]
    let basketCount: Int
    let openCards: S1OpenCardState
    let coverAssetID: (S1RangeRow) -> String?
    let onBack: () -> Void
    let onOrganizeYear: () -> Void
    let onOpenMonth: (S1RangeRow) -> Void
    let onEnterMonth: (S1RangeRow) -> Void
    let onTrash: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            S1ChromeForeground.pageBackground
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerBlock
                    S1DeckListView(
                        rows: monthRows,
                        kind: .months,
                        openCards: openCards,
                        slot: .yearPage,
                        coverAssetID: coverAssetID,
                        onOpen: onOpenMonth,
                        onEnter: onEnterMonth
                    )
                }
                .padding(.top, S1ChromeLayout.topRowTopInset + S1ChromeLayout.rowHeight)
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

    // MARK: - 标题区（距顶排底缘的绝对上距，不依赖字体行高）

    private var headerBlock: some View {
        ZStack(alignment: .topLeading) {
            titleBlock
                .padding(.top, S1DeckMetrics.yearTitleTopFromChromeBottom)
            summary
                .padding(.top, S1DeckMetrics.yearSummaryTopFromChromeBottom)
            S1DeckProgressBar(
                processed: yearRow.processedAssetCount,
                total: yearRow.totalAssetCount,
                height: S1DeckMetrics.yearBarHeight
            )
            .padding(.horizontal, S1DeckMetrics.yearSummaryHorizontalInset)
            .padding(.top, S1DeckMetrics.yearBarTopFromChromeBottom)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: S1DeckMetrics.monthDeckTopFromChromeBottom,
            maxHeight: S1DeckMetrics.monthDeckTopFromChromeBottom,
            alignment: .topLeading
        )
    }

    private var titleBlock: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(yearRow.displayName)
                    .font(.system(size: S1DeckMetrics.yearTitleFontSize, weight: .black))
                    .kerning(S1DeckMetrics.yearTitleKerning)
                    .foregroundStyle(S1ChromeForeground.primary)
                    .lineLimit(1)
                sizeLine
                    .padding(.top, S1DeckMetrics.yearSizeTopSpacing)
            }
            Spacer(minLength: 0)
            organizeButton
        }
        .padding(.leading, S1DeckMetrics.yearTitleLeadingInset)
        .padding(.trailing, S1DeckMetrics.yearTitleTrailingInset)
    }

    /// 「X GB」与「占全部 N%」两段（画布原文两段之间无「·」）；体积或占比未知整行「统计中」。
    @ViewBuilder
    private var sizeLine: some View {
        if let byteCount = yearRow.byteCount, let sharePercent = yearRow.sharePercent {
            HStack(alignment: .firstTextBaseline, spacing: S1DeckMetrics.yearShareSpacing) {
                Text(S0ByteCountText.string(forByteCount: byteCount))
                    .font(.system(size: S1DeckMetrics.yearSizeFontSize, weight: .bold).monospacedDigit())
                    .foregroundStyle(S1ChromeForeground.primary)
                Text(L10n.text("s1.yearPage.share", replacing: ["percent": String(sharePercent)]))
                    .font(.system(size: S1DeckMetrics.yearSizeFontSize, weight: .medium).monospacedDigit())
                    .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.yearShareOpacity))
            }
            .lineLimit(1)
        } else {
            Text(L10n.text("s1.volume.counting"))
                .font(.system(size: S1DeckMetrics.yearSizeFontSize, weight: .semibold))
                .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.yearShareOpacity))
                .lineLimit(1)
        }
    }

    /// 「整理整年」：维度胶囊同式（字号、字重、字色、底色引 `S1PageHeaderMetrics`），高 40 时圆角 16 非全圆。
    private var organizeButton: some View {
        Button(action: onOrganizeYear) {
            HStack(spacing: S1DeckMetrics.organizeButtonSpacing) {
                Image(systemName: S1DeckSymbol.organizeAll)
                    .font(.system(size: S1DeckMetrics.organizeButtonSymbolPointSize, weight: .semibold))
                Text(L10n.text("s1.yearPage.organizeAll"))
                    .font(.system(size: S1PageHeaderMetrics.chipFontSize, weight: .semibold))
            }
            .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.chipUnselectedTextOpacity))
            .lineLimit(1)
            .padding(.horizontal, S1DeckMetrics.organizeButtonHorizontalPadding)
            .frame(height: S1DeckMetrics.organizeButtonHeight)
            .background(
                Color.white.opacity(S1PageHeaderMetrics.chipUnselectedFillOpacity),
                in: RoundedRectangle(
                    cornerRadius: S1DeckMetrics.organizeButtonCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var summary: some View {
        Text(S1DeckCardPresentation.yearSummary(for: yearRow))
            .font(.system(size: S1DeckMetrics.yearSummaryFontSize).monospacedDigit())
            .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1DeckMetrics.yearSummaryOpacity))
            .lineLimit(1)
            .padding(.horizontal, S1DeckMetrics.yearSummaryHorizontalInset)
    }
}
