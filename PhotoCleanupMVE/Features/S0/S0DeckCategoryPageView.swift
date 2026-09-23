import SwiftUI

/// IC-162 B：「卡片叠」语言下的类别页（画布 r9.py O1／O2）。
///
/// IC-165 起为正式类别页（SPEC-S0 v3 第六节），旧类别页退役；页面自用的 zoom 过渡两只修饰符在
/// `S0DeckZoomTransition.swift`（系统版本判定只在那一个文件）。
///
/// 版式与排序：
/// - 页头 = 展开卡那张照片放大（262 高）+ 返回／排序／全选 + 名称、体积、副行、占比角标 + 总条，
///   随内容一起滚走；滚过阈值后顶上出现一条玻璃导航（返回 · 名称 体积 占比 · 排序 全选）。
///   IC-167 D：页头与导航条的排序钮左侧各加一只待删篮入口（`S0BasketEntryView`）。
/// - IC-163 C（裁定 三、四）：「最大的 N 个」「其余 M 个」两节撤销。排序钮三项——从大到小
///   （默认，整页一张网格）、最新在前、最旧在前（按月分节，无日期的归最后一节）。IC-167 C 加
///   「从小到大」（整页一张网格，按体积升序、同体积按标识升序），共四项。
/// - 底栏是一条玻璃：左「已选 N 项」+ 体积，右「移入待删篮」。
///
/// 行为逐条照旧类别页（IC-162 裁定 五）：勾选、全选、长按进 S2、进篮成功才从网格
/// 删项并出 toast、零选中主按钮禁用不隐藏；勾选集合仍是页面唯一写入者，跨 S2 往返的保留集
/// 按 IC-160 的口径读写 `S0CleanupFlowModel.preservedSelection`（`init` 按「保留集 ∩ 当前
/// 列表」播种，根视图 `.onChange` 与 `.onAppear` 两处回报——`.onChange` 不对初值触发）。
///
/// 恒深色：不读 `colorScheme`；顶排借 S1 chrome 的登记常量。IC-163 C（裁定 四）起四处玻璃
/// （收起导航条、格底标签条、toast、底栏）一律经 S1 的玻璃 helper，玻璃容器里的钮不再各自
/// 套玻璃（S1／S2 从不嵌套）。页面其余取值只经 `S0DeckMetrics`。
struct S0DeckCategoryPageView: View {
    @ObservedObject var machine: S0StateMachine

    let category: S0CategorySnapshot
    /// 保留集的宿主。**不订阅**：`preservedSelection` 不是 `@Published`，页面在
    /// `.onChange` 里写它不该让本页或流程容器反复重求值（IC-160 裁定 二）。
    private let flowModel: S0CleanupFlowModel
    private let onMoveToBasket: (Set<String>) -> Bool
    private let onBack: () -> Void
    private let onLongPress: ([String], String) -> Void
    private let toastDurationMilliseconds: Double
    private let transitionNamespace: Namespace.ID
    /// IC-167 D（裁定 五）：页头与收起导航条两只待删篮入口的回调（与首页入口同一回调）。
    private let onEnterConfirmation: () -> Void

    @State private var selection: S0CategoryPageSelection
    /// 页头有没有滚走。**只在跨阈值时写**，静止不写（陷阱 5）。
    @State private var isHeaderCollapsed = false
    @StateObject private var toast = S0FeedbackToastPresenter()
    /// IC-163 C：排序态，页面自持、不持久化。
    @State private var sortOrder: S0DeckHomeModel.SortOrder = .size
    /// IC-163 C：网格项的拍摄日期，后台取回前为 nil（此时整只排序菜单禁用）。
    @State private var dates: [String: Date]? = nil

    init(
        machine: S0StateMachine,
        category: S0CategorySnapshot,
        items: [S0CategoryAsset],
        flowModel: S0CleanupFlowModel,
        onMoveToBasket: @escaping (Set<String>) -> Bool,
        onBack: @escaping () -> Void,
        onLongPress: @escaping ([String], String) -> Void,
        toastDurationMilliseconds: Double,
        transitionNamespace: Namespace.ID,
        onEnterConfirmation: @escaping () -> Void = {}
    ) {
        self.machine = machine
        self.category = category
        self.flowModel = flowModel
        self.onMoveToBasket = onMoveToBasket
        self.onBack = onBack
        self.onLongPress = onLongPress
        self.toastDurationMilliseconds = toastDurationMilliseconds
        self.transitionNamespace = transitionNamespace
        self.onEnterConfirmation = onEnterConfirmation
        _selection = State(
            initialValue: S0CategoryPageSelection(
                items: items,
                preselected: flowModel.preservedSelection
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                S0DeckMetrics.background
                    .ignoresSafeArea()
                scrollContent(width: geometry.size.width)
                compactNav
            }
            .overlay(alignment: .bottom) {
                dock
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(
            S0DeckZoomDestination(
                id: category.id.rawValue,
                namespace: transitionNamespace
            )
        )
        .onChange(of: selection.selected) { _, current in
            flowModel.preservedSelection = current
        }
        // IC-160 裁定 三：`.onChange` 不对初值触发——出现时先回报一次，模型即收敛为
        // 页面真正显示的那一份。
        .onAppear {
            flowModel.preservedSelection = selection.selected
        }
        // IC-163 C：日期在后台取——`.task` 本身在主 actor 上，直接调同步取数仍在主线程。
        // 网格项只会因进篮而减少，旧字典是新列表的超集，重取期间照旧可用。
        .task(id: selection.items.map(\.id)) {
            let ids = selection.items.map(\.id)
            let loaded = await Task.detached(priority: .userInitiated) {
                S0DeckAssetDates.creationDates(forLocalIdentifiers: ids)
            }.value
            guard !Task.isCancelled else {
                return
            }
            dates = loaded
        }
    }

    // MARK: - 滚动内容

    private func scrollContent(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                scrollOffsetReader
                header(width: width)
                gridContent(width: width)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(
                .bottom,
                S0DeckMetrics.dockBottomInset + S0DeckMetrics.dockHeight
            )
        }
        .coordinateSpace(.named(Self.scrollSpaceName))
    }

    /// 零高的偏移读数器。只读不画，**过阈值才写状态**。
    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(
                    of: proxy.frame(in: .named(Self.scrollSpaceName)).minY
                ) { _, value in
                    updateHeaderCollapsed(offset: value)
                }
        }
        .frame(height: 0)
    }

    private func updateHeaderCollapsed(offset: CGFloat) {
        let shouldCollapse = -offset > S0DeckMetrics.compactNavThreshold
        guard shouldCollapse != isHeaderCollapsed else {
            return
        }
        withAnimation(
            .spring(
                response: S0DeckMetrics.expandAnimationResponse,
                dampingFraction: S0DeckMetrics.expandAnimationDamping
            )
        ) {
            isHeaderCollapsed = shouldCollapse
        }
    }

    // MARK: - 页头（照片放大成整页的页头）

    private func header(width: CGFloat) -> some View {
        S0DeckCoverView(
            assetIdentifier: category.coverAssetID,
            width: width,
            height: S0DeckMetrics.pageHeaderHeight
        )
        .id(category.coverAssetID)
        .overlay {
            S0DeckPageShade.header
        }
        .overlay(alignment: .top) {
            topRow
        }
        .overlay(alignment: .bottom) {
            headerFoot
        }
    }

    private var topRow: some View {
        HStack(spacing: S1ChromeLayout.itemSpacing) {
            Button(action: onBack) {
                Image(systemName: S0DeckSymbol.back)
                    .foregroundStyle(S0DeckMetrics.text)
                    .s1ChromeCircleGlass()
            }
            .accessibilityLabel(L10n.text("s0.categoryPage.back"))
            Spacer(minLength: 0)
            // IC-167 D（裁定 五）：待删篮入口在排序钮左侧，与首页同一只（SPEC-S0 v4 第六节）。
            S0BasketEntryView(style: .glass,
                              count: machine.mergedPendingDeletionCount,
                              action: onEnterConfirmation)
            // IC-163 C：页头不在玻璃容器里，排序圆钮照返回钮的写法各自借 S1 玻璃。
            sortMenu {
                Image(systemName: S0DeckSymbol.sort)
                    .foregroundStyle(S0DeckMetrics.text)
                    .s1ChromeCircleGlass()
            }
            selectAllButton
        }
        .frame(height: S1ChromeLayout.rowHeight)
        .padding(.horizontal, S1ChromeLayout.horizontalMargin)
        .padding(.top, S1ChromeLayout.topRowTopInset)
    }

    private var selectAllButton: some View {
        Button {
            selection.selectAllOrNone()
        } label: {
            Text(L10n.text("s0.categoryPage.selectAll"))
                .font(.system(size: S1ChromeTypography.titleFontSize))
                .foregroundStyle(S0DeckMetrics.text)
                .padding(.horizontal, S1ChromeLayout.itemSpacing)
                .frame(height: S1ChromeLayout.rowHeight)
                .s1ChromeGlassBackground(in: Capsule(), interactive: true)
        }
    }

    /// 页头下半：名称、体积、副行、占比角标，再压一条总条。
    private var headerFoot: some View {
        VStack(alignment: .leading, spacing: S0DeckMetrics.pageTotalBarTopSpacing) {
            HStack(alignment: .bottom, spacing: 0) {
                titleColumn
                Spacer(minLength: 0)
                shareBadge
                    .padding(.bottom, S0DeckMetrics.pageShareBadgeBaselinePadding)
            }
            .padding(.horizontal, S0DeckMetrics.pageTitleHorizontalInset)
            pageTotalBar
        }
    }

    private var titleColumn: some View {
        let parts = S0ByteCountSplit.split(
            S0ByteCountText.string(forByteCount: category.candidateByteCount)
        )
        return VStack(alignment: .leading, spacing: 0) {
            Text(S0CategoryText.displayName(for: category.id))
                .font(
                    .system(
                        size: S0DeckMetrics.pageTitleNameFontSize,
                        weight: .medium
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
            HStack(
                alignment: .lastTextBaseline,
                spacing: S0DeckMetrics.pageTitleUnitSpacing
            ) {
                Text(parts.value)
                    .font(
                        .system(
                            size: S0DeckMetrics.pageTitleValueFontSize,
                            weight: .heavy
                        )
                    )
                    .tracking(S0DeckMetrics.pageTitleValueLetterSpacing)
                    .monospacedDigit()
                    .foregroundStyle(S0DeckMetrics.text)
                Text(parts.unit)
                    .font(.system(size: S0DeckMetrics.pageTitleUnitFontSize))
                    .foregroundStyle(
                        S0DeckMetrics.dimmedText(
                            opacity: S0DeckMetrics.pageTitleUnitOpacity
                        )
                    )
            }
            Text(
                L10n.text(
                    "s0.categoryPage.subtitle",
                    replacing: [
                        "count": String(selection.items.count),
                        "order": sortOrderName
                    ]
                )
            )
            .font(.system(size: S0DeckMetrics.pageTitleSubFontSize))
            .monospacedDigit()
            .foregroundStyle(
                S0DeckMetrics.dimmedText(
                    opacity: S0DeckMetrics.pageTitleSubOpacity
                )
            )
            .padding(.top, S0DeckMetrics.pageTitleSubTopSpacing)
        }
    }

    private var shareBadge: some View {
        Text(
            L10n.text(
                "s0.home.share",
                replacing: ["percent": sharePercentText]
            )
        )
        .font(
            .system(
                size: S0DeckMetrics.shareBadgeFontSize,
                weight: .bold
            )
        )
        .monospacedDigit()
        .foregroundStyle(S0DeckMetrics.text)
        .padding(.horizontal, S0DeckMetrics.shareBadgeHorizontalPadding)
        .frame(height: S0DeckMetrics.shareBadgeHeight)
        .background(
            S0DeckMetrics.shareBadgeFill,
            in: RoundedRectangle(
                cornerRadius: S0DeckMetrics.shareBadgeCornerRadius,
                style: .continuous
            )
        )
    }

    /// 页头总条：本类那一段亮着，其余压暗——用户知道自己还在整库的这一块里。
    private var pageTotalBar: some View {
        GeometryReader { geometry in
            let model = segmentBarModel
            let spacingTotal = S0DeckMetrics.totalBarItemSpacing
                * CGFloat(max(0, model.segments.count - 1))
            let usable = max(0, geometry.size.width - spacingTotal)
            HStack(spacing: S0DeckMetrics.totalBarItemSpacing) {
                ForEach(
                    Array(model.segments.enumerated()),
                    id: \.offset
                ) { item in
                    segmentView(item.element, usableWidth: usable)
                }
            }
        }
        .frame(height: S0DeckMetrics.pageTotalBarHeight)
        .padding(.horizontal, S0DeckMetrics.totalBarHorizontalInset)
    }

    private func segmentView(
        _ segment: S0SegmentBarModel.Segment,
        usableWidth: CGFloat
    ) -> some View {
        let isCurrent = S0DeckHomeView.cardID(for: segment.kind)
            == category.id.rawValue
        return RoundedRectangle(
            cornerRadius: S0DeckMetrics.pageTotalBarCornerRadius,
            style: .continuous
        )
        .fill(S0DeckHomeView.segmentColor(for: segment.kind))
        .opacity(isCurrent ? 1 : S0DeckMetrics.pageTotalBarDimmedOpacity)
        .frame(width: usableWidth * CGFloat(segment.widthFraction))
    }

    // MARK: - 收起后的玻璃导航

    @ViewBuilder
    private var compactNav: some View {
        if isHeaderCollapsed {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    Image(systemName: S0DeckSymbol.back)
                        .foregroundStyle(S0DeckMetrics.text)
                        .frame(
                            width: S0DeckMetrics.compactNavBackSide,
                            height: S0DeckMetrics.compactNavBackSide
                        )
                }
                .accessibilityLabel(L10n.text("s0.categoryPage.back"))
                compactNavTitle
                HStack(spacing: S1ChromeLayout.itemSpacing) {
                    // IC-167 D（裁定 五）：导航条本身是玻璃容器，入口用平涂圆钮 + 徽标。
                    S0BasketEntryView(style: .flat,
                                      count: machine.mergedPendingDeletionCount,
                                      action: onEnterConfirmation)
                    compactNavSort
                    compactNavSelectAll
                }
            }
            .padding(.leading, S0DeckMetrics.compactNavLeadingPadding)
            .padding(.trailing, S0DeckMetrics.compactNavTrailingPadding)
            .frame(height: S0DeckMetrics.compactNavHeight)
            .s1ChromeGlassBackground(
                in: RoundedRectangle(
                    cornerRadius: S0DeckMetrics.compactNavCornerRadius,
                    style: .continuous
                ),
                interactive: true
            )
            .padding(.horizontal, S0DeckMetrics.compactNavHorizontalInset)
            .padding(.top, S1ChromeLayout.topRowTopInset)
            .transition(.opacity)
        }
    }

    private var compactNavTitle: some View {
        HStack(spacing: S0DeckMetrics.compactNavTitleItemSpacing) {
            Spacer(minLength: 0)
            Text(S0CategoryText.displayName(for: category.id))
                .font(
                    .system(
                        size: S0DeckMetrics.compactNavTitleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
            Text(
                S0ByteCountText.string(
                    forByteCount: category.candidateByteCount
                )
            )
            .font(
                .system(
                    size: S0DeckMetrics.compactNavTitleFontSize,
                    weight: .heavy
                )
            )
            .tracking(S0DeckMetrics.compactNavValueLetterSpacing)
            .monospacedDigit()
            .foregroundStyle(S0DeckMetrics.text)
            Text(
                L10n.text(
                    "s0.home.share",
                    replacing: ["percent": sharePercentText]
                )
            )
            .font(.system(size: S0DeckMetrics.compactNavShareFontSize))
            .monospacedDigit()
            .foregroundStyle(
                S0DeckMetrics.dimmedText(
                    opacity: S0DeckMetrics.compactNavShareOpacity
                )
            )
            Spacer(minLength: 0)
        }
    }

    /// 收起导航条本身是玻璃容器：排序圆钮不再套玻璃，用与「全选」同一种平涂底。
    private var compactNavSort: some View {
        sortMenu {
            Image(systemName: S0DeckSymbol.sort)
                .font(
                    .system(
                        size: S1ChromeTypography.circleIconPointSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
                .frame(
                    width: S0DeckMetrics.compactNavBackSide,
                    height: S0DeckMetrics.compactNavBackSide
                )
                .background(
                    S0DeckMetrics.text.opacity(
                        S0DeckMetrics.compactNavActionFillOpacity
                    ),
                    in: Circle()
                )
        }
    }

    /// IC-163 C（裁定 四）：排序是系统 `Menu`，三项互斥（IC-167 C 起四项：加「从小到大」）。取回日期之前整只菜单禁用——
    /// `Menu` 里逐项 `.disabled` 在 iOS 17 上不可靠，不用。
    private func sortMenu<MenuLabel: View>(
        @ViewBuilder label: () -> MenuLabel
    ) -> some View {
        Menu {
            Picker(L10n.text("s1.sort.accessibility"), selection: $sortOrder) {
                Text(L10n.text("s0.categoryPage.sort.size"))
                    .tag(S0DeckHomeModel.SortOrder.size)
                Text(L10n.text("s0.categoryPage.sort.sizeAscending"))
                    .tag(S0DeckHomeModel.SortOrder.sizeAscending)
                Text(L10n.text("s1.sort.newest_first"))
                    .tag(S0DeckHomeModel.SortOrder.newestFirst)
                Text(L10n.text("s1.sort.oldest_first"))
                    .tag(S0DeckHomeModel.SortOrder.oldestFirst)
            }
        } label: {
            label()
        }
        .disabled(dates == nil)
        .accessibilityLabel(L10n.text("s1.sort.accessibility"))
    }

    private var compactNavSelectAll: some View {
        Button {
            selection.selectAllOrNone()
        } label: {
            Text(L10n.text("s0.categoryPage.selectAll"))
                .font(
                    .system(
                        size: S0DeckMetrics.compactNavActionFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
                .padding(
                    .horizontal,
                    S0DeckMetrics.compactNavActionHorizontalPadding
                )
                .frame(height: S0DeckMetrics.compactNavActionHeight)
                .background(
                    S0DeckMetrics.text.opacity(
                        S0DeckMetrics.compactNavActionFillOpacity
                    ),
                    in: RoundedRectangle(
                        cornerRadius:
                            S0DeckMetrics.compactNavActionCornerRadius,
                        style: .continuous
                    )
                )
        }
    }

    // MARK: - 网格（IC-163 C：从大到小整页一张；时间排序按月分节）

    @ViewBuilder
    private func gridContent(width: CGFloat) -> some View {
        let side = cellWidth(forWidth: width)
        let ordered = displayedItems
        switch sortOrder {
        case .size, .sizeAscending:
            grid(ordered, width: side, topSpacing: S0DeckMetrics.monthSectionSpacing)
        case .newestFirst, .oldestFirst:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(
                    S0DeckHomeModel.monthSections(
                        ordered,
                        dates: dates ?? [:],
                        calendar: Calendar.current
                    ),
                    id: \.monthStart
                ) { section in
                    sectionHeader(
                        title: monthTitle(for: section.monthStart),
                        count: section.items.count
                    )
                    grid(
                        section.items,
                        width: side,
                        topSpacing: S0DeckMetrics.sectionToGridSpacing
                    )
                }
            }
        }
    }

    /// 月份节标题：左节名（15／600），右计数（12.5，压暗 0.55）。版式沿用原分节标题，
    /// 不带动作钮。
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: S0DeckMetrics.sectionTitleItemSpacing) {
            Text(title)
                .font(
                    .system(
                        size: S0DeckMetrics.sectionTitleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
            Spacer(minLength: 0)
            Text(
                L10n.text(
                    "s0.categoryPage.month.count",
                    replacing: ["count": String(count)]
                )
            )
            .font(.system(size: S0DeckMetrics.monthSectionCountFontSize))
            .monospacedDigit()
            .foregroundStyle(
                S0DeckMetrics.dimmedText(
                    opacity: S0DeckMetrics.sectionTitleDimmedOpacity
                )
            )
        }
        .frame(height: S0DeckMetrics.sectionHeight)
        .padding(.leading, S0DeckMetrics.sectionLeadingInset)
        .padding(.trailing, S0DeckMetrics.sectionTrailingInset)
        .padding(.top, S0DeckMetrics.monthSectionSpacing)
    }

    @ViewBuilder
    private func grid(
        _ items: [S0CategoryAsset],
        width: CGFloat,
        topSpacing: CGFloat
    ) -> some View {
        if !items.isEmpty {
            LazyVGrid(
                columns: gridColumns(width: width),
                spacing: S0DeckMetrics.gridItemSpacing
            ) {
                ForEach(items) { item in
                    gridCell(item, width: width)
                }
            }
            .padding(.horizontal, S0DeckMetrics.gridHorizontalInset)
            .padding(.top, topSpacing)
        }
    }

    private func gridCell(
        _ item: S0CategoryAsset,
        width: CGFloat
    ) -> some View {
        Button {
            selection.toggle(item.id)
        } label: {
            cell(item, width: width)
        }
        .buttonStyle(.plain)
        // IC-157 B：长按与按钮并存（按钮语义与点按反馈保留），时长取系统默认。
        // IC-163 C：交接顺序 = 网格当前显示顺序（排序后）。
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                onLongPress(displayedItems.map(\.id), item.id)
            }
        )
    }

    private func cell(
        _ item: S0CategoryAsset,
        width: CGFloat
    ) -> some View {
        let isSelected = selection.selected.contains(item.id)
        return S0DeckCoverView(
            assetIdentifier: item.id,
            width: width,
            height: S0DeckMetrics.gridCellHeight
        )
        .id(item.id)
        .clipShape(
            RoundedRectangle(
                cornerRadius: S0DeckMetrics.gridCellCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: S0DeckMetrics.gridCellCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                isSelected
                    ? S0DeckMetrics.accent
                    : S0DeckMetrics.text.opacity(
                        S0DeckMetrics.gridCellRingOpacity
                    ),
                lineWidth: isSelected
                    ? S0DeckMetrics.gridSelectedRingWidth
                    : S0DeckMetrics.gridCellRingWidth
            )
        }
        .overlay(alignment: .bottom) {
            cellLabel(item)
                .padding(S0DeckMetrics.gridLabelInset)
        }
        .overlay(alignment: .topTrailing) {
            checkMark(isSelected: isSelected)
                .padding(S0DeckMetrics.gridCheckInset)
        }
    }

    private func cellLabel(_ item: S0CategoryAsset) -> some View {
        HStack(spacing: 0) {
            Text(S0ByteCountText.string(forByteCount: item.byteCount))
                .font(
                    .system(
                        size: S0DeckMetrics.gridLabelFontSize,
                        weight: .bold
                    )
                )
                .monospacedDigit()
                .foregroundStyle(S0DeckMetrics.text)
            Spacer(minLength: 0)
            cellDuration(item)
        }
        .padding(.horizontal, S0DeckMetrics.gridLabelHorizontalPadding)
        .frame(height: S0DeckMetrics.gridLabelHeight)
        .s1ChromeGlassBackground(
            in: RoundedRectangle(
                cornerRadius: S0DeckMetrics.gridLabelCornerRadius,
                style: .continuous
            ),
            interactive: false
        )
    }

    @ViewBuilder
    private func cellDuration(_ item: S0CategoryAsset) -> some View {
        if item.isVideo {
            HStack(spacing: S0DeckMetrics.gridLabelGlyphSpacing) {
                Image(systemName: S0DeckSymbol.play)
                Text(S0CategoryPageDurationText.string(for: item.duration))
                    .monospacedDigit()
            }
            .font(
                .system(
                    size: S0DeckMetrics.gridLabelFontSize,
                    weight: .medium
                )
            )
            .foregroundStyle(
                S0DeckMetrics.dimmedText(
                    opacity: S0DeckMetrics.gridLabelTrailingOpacity
                )
            )
        }
    }

    private func checkMark(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    isSelected
                        ? S0DeckMetrics.accent
                        : Color.black.opacity(
                            S0DeckMetrics.gridCheckUnselectedFillOpacity
                        )
                )
            Circle()
                .strokeBorder(
                    isSelected
                        ? S0DeckMetrics.accent
                        : S0DeckMetrics.text.opacity(
                            S0DeckMetrics.gridCheckRingOpacity
                        ),
                    lineWidth: S0DeckMetrics.gridCheckRingWidth
                )
            if isSelected {
                Image(systemName: S0DeckSymbol.check)
                    .font(
                        .system(
                            size: S0DeckMetrics.gridCheckGlyphFontSize,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(S0DeckMetrics.text)
            }
        }
        .frame(
            width: S0DeckMetrics.gridCheckSide,
            height: S0DeckMetrics.gridCheckSide
        )
    }

    // MARK: - 底栏玻璃与 toast

    private var dock: some View {
        VStack(spacing: S0DeckMetrics.toastToDockSpacing) {
            toastView
            dockBar
        }
        .padding(.horizontal, S0DeckMetrics.dockHorizontalInset)
        .padding(.bottom, S0DeckMetrics.dockBottomInset)
    }

    @ViewBuilder
    private var toastView: some View {
        if let text = toast.activeText {
            S0FeedbackToastLabel(text: text)
        }
    }

    private var dockBar: some View {
        HStack(spacing: 0) {
            dockReadout
            Spacer(minLength: 0)
            submitButton
        }
        .padding(.leading, S0DeckMetrics.dockLeadingPadding)
        .padding(.trailing, S0DeckMetrics.dockTrailingPadding)
        .frame(height: S0DeckMetrics.dockHeight)
        .s1ChromeGlassBackground(
            in: RoundedRectangle(
                cornerRadius: S0DeckMetrics.dockCornerRadius,
                style: .continuous
            ),
            interactive: true
        )
    }

    private var dockReadout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(
                L10n.text(
                    "s0.categoryPage.selected",
                    replacing: ["count": String(selection.selected.count)]
                )
            )
            .font(.system(size: S0DeckMetrics.dockLabelFontSize))
            .monospacedDigit()
            .foregroundStyle(
                S0DeckMetrics.dimmedText(
                    opacity: S0DeckMetrics.dockLabelOpacity
                )
            )
            Text(
                S0ByteCountText.string(
                    forByteCount: selection.selectedByteCount
                )
            )
            .font(
                .system(
                    size: S0DeckMetrics.dockValueFontSize,
                    weight: .heavy
                )
            )
            .tracking(S0DeckMetrics.dockValueLetterSpacing)
            .monospacedDigit()
            .foregroundStyle(S0DeckMetrics.text)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: S0DeckMetrics.dockButtonItemSpacing) {
                Image(systemName: S0DeckSymbol.trash)
                    .foregroundStyle(S0DeckMetrics.accent)
                Text(L10n.text("s0.categoryPage.submit"))
                    .foregroundStyle(S0DeckMetrics.background)
            }
            .font(
                .system(
                    size: S0DeckMetrics.dockButtonFontSize,
                    weight: .bold
                )
            )
            .padding(.leading, S0DeckMetrics.dockButtonLeadingPadding)
            .padding(.trailing, S0DeckMetrics.dockButtonTrailingPadding)
            .frame(height: S0DeckMetrics.dockButtonHeight)
            .background(
                S0DeckMetrics.text,
                in: RoundedRectangle(
                    cornerRadius: S0DeckMetrics.dockButtonCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!selection.isSubmitEnabled)
        .opacity(
            selection.isSubmitEnabled
                ? 1
                : S0DeckMetrics.dockButtonDisabledOpacity
        )
    }

    // MARK: - 动作

    private func submit() {
        let chosen = selection.selected
        guard !chosen.isEmpty, onMoveToBasket(chosen) else {
            return
        }
        selection.remove(ids: chosen)
        toast.present(
            text: L10n.text("s0.categoryPage.toast"),
            durationMilliseconds: toastDurationMilliseconds
        )
    }

    // MARK: - 派生

    /// 网格当前显示顺序：勾选模型里的现存项按排序态排列（日期未取回时按空字典，
    /// 此时菜单禁用、排序态恒为 `.size`）。
    private var displayedItems: [S0CategoryAsset] {
        S0DeckHomeModel.sorted(
            selection.items,
            by: sortOrder,
            dates: dates ?? [:]
        )
    }

    /// 月份节标题：有日期按系统语言环境的「年 月」模板（中文即 2026年3月），无日期取目录文案。
    private func monthTitle(for monthStart: Date?) -> String {
        guard let monthStart else {
            return L10n.text("s0.categoryPage.undated")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: monthStart)
    }

    /// 副行的排序名：与排序菜单各项同文案（后两项复用逐张整理 tab 的排序文案；IC-167 C 起四项）。
    private var sortOrderName: String {
        switch sortOrder {
        case .size:
            return L10n.text("s0.categoryPage.sort.size")
        case .sizeAscending:
            return L10n.text("s0.categoryPage.sort.sizeAscending")
        case .newestFirst:
            return L10n.text("s1.sort.newest_first")
        case .oldestFirst:
            return L10n.text("s1.sort.oldest_first")
        }
    }

    private var segmentBarModel: S0SegmentBarModel {
        let snapshot = machine.snapshot
        return S0SegmentBarModel.make(
            categories: machine.orderedCategories,
            ledgerEntries: snapshot.ledgerEntries,
            libraryTotalByteCount: snapshot.libraryTotalByteCount,
            progress: snapshot.progress,
            isScanning: machine.state == .scanning
        )
    }

    /// 占比读数与首页同一口径：本类字节量占照片库总占用。
    private var sharePercentText: String {
        let cards = S0DeckHomeModel.cards(
            categories: [category],
            libraryTotalByteCount: machine.snapshot.libraryTotalByteCount
        )
        let percent = cards.first?.percent ?? 0
        return String(percent) + S0DeckSymbol.percentSign
    }

    /// 格宽 = (页宽 − 两侧页面边距 − 列间距之和) ÷ 列数。
    private func cellWidth(forWidth width: CGFloat) -> CGFloat {
        let columnCount = CGFloat(S0DeckMetrics.gridColumns)
        let gapTotal = CGFloat(S0DeckMetrics.gridColumns - 1)
            * S0DeckMetrics.gridItemSpacing
        let available = width
            - S0DeckMetrics.gridHorizontalInset * 2
            - gapTotal
        return max(0, available / columnCount)
    }

    private func gridColumns(width: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(width),
                spacing: S0DeckMetrics.gridItemSpacing
            ),
            count: S0DeckMetrics.gridColumns
        )
    }

    private static let scrollSpaceName = "S0DeckCategoryPageScroll"
}

/// 类别页页头的压暗渐变（r9.py `.hd .fadeb`）。取值全部来自 `S0DeckMetrics`。
enum S0DeckPageShade {
    static var header: LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: S0DeckMetrics.background.opacity(
                        S0DeckMetrics.pageHeaderFadeTopOpacity
                    ),
                    location: 0
                ),
                Gradient.Stop(
                    color: S0DeckMetrics.background.opacity(
                        S0DeckMetrics.pageHeaderFadeUpperOpacity
                    ),
                    location: S0DeckMetrics.pageHeaderFadeUpperLocation
                ),
                Gradient.Stop(
                    color: S0DeckMetrics.background.opacity(
                        S0DeckMetrics.pageHeaderFadeTopOpacity
                    ),
                    location: S0DeckMetrics.pageHeaderFadeLowerLocation
                ),
                Gradient.Stop(
                    color: S0DeckMetrics.background,
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// IC-168 D（裁定 四）：类别页底部短 toast 的视图体，从 `toastView` 原样抽出。类别页自己的
/// 提示与 App 在清理 tab 上呈现的 S1 回落提示共用这一只（同字号、同玻璃、不接收点击）。
/// 留在本文件：页面的登记值与玻璃计数都钉在这里。
struct S0FeedbackToastLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: S0DeckMetrics.toastFontSize))
            .foregroundStyle(S0DeckMetrics.text)
            .padding(.horizontal, S0DeckMetrics.toastHorizontalPadding)
            .padding(.vertical, S0DeckMetrics.toastVerticalPadding)
            .s1ChromeGlassBackground(
                in: RoundedRectangle(
                    cornerRadius: S0DeckMetrics.toastCornerRadius,
                    style: .continuous
                ),
                interactive: false
            )
            .allowsHitTesting(false)
            .accessibilityAddTraits(.isStaticText)
    }
}
