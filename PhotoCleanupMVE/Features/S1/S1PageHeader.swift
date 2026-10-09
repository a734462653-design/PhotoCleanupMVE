import SwiftUI

/// IC-192：「逐张整理」V1 页头的登记值（SPEC-S1 v12 第十一节第 2d 部分页头段；纵向位置以顶排底缘为零点）。
/// 色只走 `S1ChromeForeground` 与 `S0DeckMetrics`；画布字面白底照录。骨架与受限条间距为卡内暂登（规格欠账）。
enum S1PageHeaderMetrics {
    /// 行内标题「逐张整理」：700 字重、字距 0.2。
    static let titleFontSize: CGFloat = 17
    static let titleKerning: CGFloat = 0.2
    /// 右侧排序钮／待删篮入口／人像圆钮之间。
    static let buttonSpacing: CGFloat = 10
    /// 大数字区顶（距顶排底缘）。
    static let heroTopFromChromeBottom: CGFloat = 14
    static let heroHorizontalInset: CGFloat = 20
    /// 「照片与视频占用」：500 字重、前景 × 0.66。
    static let heroLabelFontSize: CGFloat = 14.5
    static let heroLabelOpacity: Double = 0.66
    /// 大数字：800 字重、字距 -2.4、等宽数字。
    static let heroValueFontSize: CGFloat = 56
    static let heroValueKerning: CGFloat = -2.4
    /// 单位：字距 -0.6、前景 × 0.72、左距 6。
    static let heroUnitFontSize: CGFloat = 26
    static let heroUnitKerning: CGFloat = -0.6
    static let heroUnitOpacity: Double = 0.72
    static let heroUnitSpacing: CGFloat = 6
    /// 右块「已看」标签：前景 × 0.48。
    static let seenLabelFontSize: CGFloat = 12.5
    static let seenLabelOpacity: Double = 0.48
    /// 已看百分比：800 字重、字距 -0.6、薄荷；「%」左距 2；右块底内边距 6。
    static let seenValueFontSize: CGFloat = 22
    static let seenValueKerning: CGFloat = -0.6
    static let seenPercentFontSize: CGFloat = 13
    static let seenPercentSpacing: CGFloat = 2
    static let seenBlockBottomPadding: CGFloat = 6
    /// 副行顶（距顶排底缘）：前景 × 0.48、件间距 6；「去确认」700 字重、前景主色、左距 4。
    static let subtitleTopFromChromeBottom: CGFloat = 108
    static let subtitleFontSize: CGFloat = 12.5
    static let subtitleOpacity: Double = 0.48
    static let subtitleItemSpacing: CGFloat = 6
    static let confirmLeadingSpacing: CGFloat = 4
    /// 维度胶囊顶（距顶排底缘）：左边距 16、间距 8。
    static let chipTopFromChromeBottom: CGFloat = 134
    static let chipHeight: CGFloat = 32
    static let chipHorizontalPadding: CGFloat = 13
    static let chipSpacing: CGFloat = 8
    /// 胶囊字：600 字重；未选中 = 前景 × 0.78 字、白 × 0.09 底；选中 = 页面底色字、前景主色底。
    static let chipFontSize: CGFloat = 13.5
    static let chipUnselectedTextOpacity: Double = 0.78
    static let chipUnselectedFillOpacity: Double = 0.09
    /// 卡片叠顶（距顶排底缘）。
    static let deckTopFromChromeBottom: CGFloat = 180
    /// 卡内暂登：受限提示条在胶囊与卡叠之间，上距取胶囊底到卡叠顶的同一间距。
    static let bannerTopSpacing: CGFloat = 14
    /// 卡内暂登：S1-1 骨架（圆角矩形，底取前景表分隔线色）。
    static let skeletonCornerRadius: CGFloat = 6
    static let skeletonHeroWidth: CGFloat = 148
    static let skeletonHeroHeight: CGFloat = 44
    static let skeletonSeenWidth: CGFloat = 52
    static let skeletonSeenHeight: CGFloat = 22
    static let skeletonSubtitleWidth: CGFloat = 168
    static let skeletonSubtitleHeight: CGFloat = 12

    /// 页头块高 = 胶囊顶 + 胶囊高；卡叠与之相隔 = 卡叠顶 − 页头块高（推导量）。
    static var headerBlockHeight: CGFloat {
        chipTopFromChromeBottom + chipHeight
    }

    static var deckTopSpacing: CGFloat {
        deckTopFromChromeBottom - headerBlockHeight
    }
}

/// IC-192：页头分隔符（界面文字不写裸字面量，分隔符走常量）。
enum S1PageHeaderSymbol {
    static let separator = "·"
}

/// IC-192：页头数值位怎么画——SPEC-S1 v12 第三节各态页头条款。
enum S1PageHeaderValueMode: Equatable {
    /// S1-1：读取完成前不显示数值，显示骨架；副行待删篮段照常（「去确认」不可触发）。
    case skeleton
    /// S1-2／S1-3：照常（取不到的写「统计中」）。
    case values
    /// S1-4：大数字区与副行前段不显示数值；副行前段不画，待删篮段自左缘起照常。
    case hidden
}

/// IC-192：页头的展示口径（测试钉住——不驱动渲染也能验）。
enum S1PageHeaderPresentation {
    static func valueMode(for state: S1State) -> S1PageHeaderValueMode {
        switch state {
        case .loading:
            return .skeleton
        case .ready, .empty:
            return .values
        case .failed:
            return .hidden
        }
    }

    /// 副行前段：按日期「N 张 · M 年」、相册「N 张 · M 个相册」、未分类「N 张」（N = 一级范围资产之并）。
    static func subtitleLeading(
        summary: S1HeaderSummary,
        groupingDimension: S1GroupingDimension
    ) -> String {
        let count = String(summary.assetCount)
        let ranges = String(summary.topLevelRangeCount)
        switch groupingDimension {
        case .date:
            return L10n.text("s1.header.subtitle.date", replacing: ["count": count, "years": ranges])
        case .album:
            return L10n.text("s1.header.subtitle.album", replacing: ["count": count, "albums": ranges])
        case .unclassified:
            return L10n.text("s1.range.total_count", replacing: ["count": count])
        }
    }

    /// 副行后段「待删篮 N 张 · 去确认」：`D_全部` 为空时整段不显示（第六节第 3 部分）。
    static func showsBasketSegment(badgeCount: Int) -> Bool {
        badgeCount > 0
    }

    static func dimensionTitle(_ dimension: S1GroupingDimension) -> String {
        switch dimension {
        case .date:
            return L10n.text("s1.dimension.date")
        case .album:
            return L10n.text("s1.dimension.album")
        case .unclassified:
            return L10n.text("s1.dimension.unclassified")
        }
    }

    static func sortTitle(_ sortOrder: S1SortOrder) -> String {
        switch sortOrder {
        case .newestFirst:
            return L10n.text("s1.sort.newest_first")
        case .oldestFirst:
            return L10n.text("s1.sort.oldest_first")
        }
    }
}

/// IC-192：「逐张整理」V1 页头（SPEC-S1 v12 第三节前言、第六节第 3、4 部分）。顶排一行（行内标题、排序钮
/// = 系统 `Menu`、待删篮入口、人像圆钮）→ 大数字区（总占用 + 已看）→ 副行 → 维度胶囊。只收值与回调，
/// 不认识状态机；排序写进状态机经调用方给的 `Binding`。人像圆钮照「空间清理」首页先例画出、点了无动作
/// （④ 第 228 条，待 IC-181 账户 sheet）。S1-1 时排序钮、待删篮入口与人像圆钮降 40% 不可触发，维度胶囊
/// 不可触发但不降暗。
struct S1PageHeader: View {
    let state: S1State
    let summary: S1HeaderSummary
    let groupingDimension: S1GroupingDimension
    let badgeCount: Int
    let chromeModel: S1ChromeBarModel
    let sortOrder: Binding<S1SortOrder>
    let onBasket: () -> Void
    let onSelectDimension: (S1GroupingDimension) -> Void
    let onOpenAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            ZStack(alignment: .topLeading) {
                heroBlock
                    .padding(.top, S1PageHeaderMetrics.heroTopFromChromeBottom)
                subtitleRow
                    .padding(.top, S1PageHeaderMetrics.subtitleTopFromChromeBottom)
                chipsRow
                    .padding(.top, S1PageHeaderMetrics.chipTopFromChromeBottom)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: S1PageHeaderMetrics.headerBlockHeight,
                maxHeight: S1PageHeaderMetrics.headerBlockHeight,
                alignment: .topLeading
            )
        }
    }

    private var valueMode: S1PageHeaderValueMode {
        S1PageHeaderPresentation.valueMode(for: state)
    }

    // MARK: - 顶排

    private var topRow: some View {
        HStack(spacing: S1PageHeaderMetrics.buttonSpacing) {
            Text(L10n.text("s1.header.title"))
                .font(.system(size: S1PageHeaderMetrics.titleFontSize, weight: .bold))
                .kerning(S1PageHeaderMetrics.titleKerning)
                .foregroundStyle(S1ChromeForeground.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            sortMenu
            S0BasketEntryView(style: .glass, count: badgeCount, action: onBasket)
                .disabled(!chromeModel.controlsEnabled)
                .opacity(chromeModel.controlsOpacity)
            accountButton
        }
        .frame(height: S1ChromeLayout.rowHeight)
        .padding(.horizontal, S1ChromeLayout.horizontalMargin)
        .padding(.top, S1ChromeLayout.topRowTopInset)
    }

    /// 系统 `Menu`、两项、当前项系统勾选；外观随系统、不加深色覆盖（第六节第 4 部分；观感见未定项 28）。
    private var sortMenu: some View {
        Menu {
            Picker(L10n.text("s1.sort.accessibility"), selection: sortOrder) {
                Text(S1PageHeaderPresentation.sortTitle(.newestFirst))
                    .tag(S1SortOrder.newestFirst)
                Text(S1PageHeaderPresentation.sortTitle(.oldestFirst))
                    .tag(S1SortOrder.oldestFirst)
            }
        } label: {
            Image(systemName: S0DeckSymbol.sort)
                .foregroundStyle(S1ChromeForeground.primary)
                .s1ChromeCircleGlass()
        }
        .disabled(!chromeModel.controlsEnabled)
        .opacity(chromeModel.controlsOpacity)
        .accessibilityLabel(L10n.text("s1.sort.accessibility"))
    }

    private var accountButton: some View {
        Button(action: onOpenAccount) {
            Image(systemName: S0DeckSymbol.account)
                .foregroundStyle(S1ChromeForeground.primary)
                .s1ChromeCircleGlass()
        }
        .disabled(!chromeModel.controlsEnabled)
        .opacity(chromeModel.controlsOpacity)
        .accessibilityLabel(L10n.text("s0.account.title"))
    }

    // MARK: - 大数字区

    private var heroBlock: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.text("s1.header.total_label"))
                    .font(.system(size: S1PageHeaderMetrics.heroLabelFontSize, weight: .medium))
                    .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.heroLabelOpacity))
                heroValue
            }
            Spacer(minLength: 0)
            seenBlock
        }
        .padding(.horizontal, S1PageHeaderMetrics.heroHorizontalInset)
    }

    @ViewBuilder
    private var heroValue: some View {
        switch valueMode {
        case .skeleton:
            skeleton(width: S1PageHeaderMetrics.skeletonHeroWidth, height: S1PageHeaderMetrics.skeletonHeroHeight)
        case .hidden:
            Color.clear
                .frame(width: S1PageHeaderMetrics.skeletonHeroWidth, height: S1PageHeaderMetrics.skeletonHeroHeight)
        case .values:
            if let totalByteCount = summary.totalByteCount {
                let parts = S0ByteCountSplit.split(S0ByteCountText.string(forByteCount: totalByteCount))
                HStack(alignment: .lastTextBaseline, spacing: S1PageHeaderMetrics.heroUnitSpacing) {
                    Text(parts.value)
                        .font(.system(size: S1PageHeaderMetrics.heroValueFontSize, weight: .heavy))
                        .tracking(S1PageHeaderMetrics.heroValueKerning)
                        .monospacedDigit()
                        .foregroundStyle(S1ChromeForeground.primary)
                    Text(parts.unit)
                        .font(.system(size: S1PageHeaderMetrics.heroUnitFontSize))
                        .tracking(S1PageHeaderMetrics.heroUnitKerning)
                        .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.heroUnitOpacity))
                }
                .lineLimit(1)
            } else {
                Text(L10n.text("s1.volume.counting"))
                    .font(.system(size: S1PageHeaderMetrics.heroUnitFontSize, weight: .semibold))
                    .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.heroUnitOpacity))
            }
        }
    }

    private var seenBlock: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(L10n.text("s1.header.seen_label"))
                .font(.system(size: S1PageHeaderMetrics.seenLabelFontSize))
                .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.seenLabelOpacity))
            seenValue
        }
        .padding(.bottom, S1PageHeaderMetrics.seenBlockBottomPadding)
    }

    @ViewBuilder
    private var seenValue: some View {
        switch valueMode {
        case .skeleton:
            skeleton(width: S1PageHeaderMetrics.skeletonSeenWidth, height: S1PageHeaderMetrics.skeletonSeenHeight)
        case .hidden:
            Color.clear
                .frame(width: S1PageHeaderMetrics.skeletonSeenWidth, height: S1PageHeaderMetrics.skeletonSeenHeight)
        case .values:
            if let seenPercent = summary.seenPercent {
                HStack(alignment: .lastTextBaseline, spacing: S1PageHeaderMetrics.seenPercentSpacing) {
                    Text(String(seenPercent))
                        .font(.system(size: S1PageHeaderMetrics.seenValueFontSize, weight: .heavy))
                        .tracking(S1PageHeaderMetrics.seenValueKerning)
                        .monospacedDigit()
                    Text(S0DeckSymbol.percentSign)
                        .font(.system(size: S1PageHeaderMetrics.seenPercentFontSize))
                }
                .foregroundStyle(S0DeckMetrics.mint)
            } else {
                Text(L10n.text("s1.volume.counting"))
                    .font(.system(size: S1PageHeaderMetrics.seenPercentFontSize, weight: .semibold))
                    .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.seenLabelOpacity))
            }
        }
    }

    // MARK: - 副行

    private var subtitleRow: some View {
        HStack(spacing: S1PageHeaderMetrics.subtitleItemSpacing) {
            switch valueMode {
            case .skeleton:
                skeleton(
                    width: S1PageHeaderMetrics.skeletonSubtitleWidth,
                    height: S1PageHeaderMetrics.skeletonSubtitleHeight
                )
                if S1PageHeaderPresentation.showsBasketSegment(badgeCount: badgeCount) {
                    Text(S1PageHeaderSymbol.separator)
                    basketSegment
                }
            case .values:
                Text(S1PageHeaderPresentation.subtitleLeading(summary: summary, groupingDimension: groupingDimension))
                if S1PageHeaderPresentation.showsBasketSegment(badgeCount: badgeCount) {
                    Text(S1PageHeaderSymbol.separator)
                    basketSegment
                }
            case .hidden:
                if S1PageHeaderPresentation.showsBasketSegment(badgeCount: badgeCount) {
                    basketSegment
                }
            }
        }
        .font(.system(size: S1PageHeaderMetrics.subtitleFontSize).monospacedDigit())
        .foregroundStyle(S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.subtitleOpacity))
        .lineLimit(1)
        .padding(.horizontal, S1PageHeaderMetrics.heroHorizontalInset)
    }

    /// 「待删篮 N 张 · 去确认」；「去确认」与待删篮入口同一动作（决策 8）。
    private var basketSegment: some View {
        HStack(spacing: S1PageHeaderMetrics.subtitleItemSpacing) {
            Text(L10n.text("s1.header.basket", replacing: ["count": String(badgeCount)]))
            Text(S1PageHeaderSymbol.separator)
            Button(action: onBasket) {
                Text(L10n.text("s1.header.confirm"))
                    .font(.system(size: S1PageHeaderMetrics.subtitleFontSize, weight: .bold))
                    .foregroundStyle(S1ChromeForeground.primary)
            }
            .buttonStyle(.plain)
            .disabled(!chromeModel.trashEnabled)
            .padding(.leading, S1PageHeaderMetrics.confirmLeadingSpacing)
        }
    }

    // MARK: - 维度胶囊

    private var chipsRow: some View {
        HStack(spacing: S1PageHeaderMetrics.chipSpacing) {
            ForEach(S1GroupingDimension.allCases, id: \.self) { dimension in
                chip(dimension)
            }
        }
        .padding(.horizontal, S1ChromeLayout.horizontalMargin)
    }

    private func chip(_ dimension: S1GroupingDimension) -> some View {
        let isSelected = dimension == groupingDimension
        return Button {
            onSelectDimension(dimension)
        } label: {
            Text(S1PageHeaderPresentation.dimensionTitle(dimension))
                .font(.system(size: S1PageHeaderMetrics.chipFontSize, weight: .semibold))
                .foregroundStyle(
                    isSelected
                        ? S1ChromeForeground.pageBackground
                        : S0DeckMetrics.dimmedText(opacity: S1PageHeaderMetrics.chipUnselectedTextOpacity)
                )
                .padding(.horizontal, S1PageHeaderMetrics.chipHorizontalPadding)
                .frame(height: S1PageHeaderMetrics.chipHeight)
                .background(
                    isSelected
                        ? S1ChromeForeground.primary
                        : Color.white.opacity(S1PageHeaderMetrics.chipUnselectedFillOpacity),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!chromeModel.controlsEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 骨架

    private func skeleton(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: S1PageHeaderMetrics.skeletonCornerRadius, style: .continuous)
            .fill(S1ChromeForeground.separator)
            .frame(width: width, height: height)
    }
}
