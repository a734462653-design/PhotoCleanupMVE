import SwiftUI

/// IC-162 B：「卡片叠」语言下的类别页（画布 r9.py O1／O2）。
///
/// **本文件是预览，不是实装**：`S0CategoryPageView.swift` 一字未动，两者由
/// `S0DeckPreview.isEnabled` 在 `S0CleanupFlowView.page(for:)` 里二选一（裁定 一）。
///
/// 与旧类别页的差别只在版式与分节：
/// - 页头 = 展开卡那张照片放大（262 高）+ 返回／全选 + 名称、体积、副行、占比角标 + 总条，
///   随内容一起滚走；滚过阈值后顶上出现一条玻璃导航（返回 · 名称 体积 占比 · 全选）。
/// - 网格分两节：`最大的 N 个`（右侧一键把这 N 个并入已选）与 `其余 M 个`；总数 ≤ N 时只有第一节。
/// - 底栏是一条玻璃：左「已选 N 项」+ 体积，右「移入待删篮」。
///
/// 行为逐条照 `S0CategoryPageView`（裁定 五）：勾选、全选、长按进 S2、进篮成功才从网格
/// 删项并出 toast、零选中主按钮禁用不隐藏；勾选集合仍是页面唯一写入者，跨 S2 往返的保留集
/// 按 IC-160 的口径读写 `S0CleanupFlowModel.preservedSelection`（`init` 按「保留集 ∩ 当前
/// 列表」播种，根视图 `.onChange` 与 `.onAppear` 两处回报——`.onChange` 不对初值触发）。
///
/// 恒深色：不读 `colorScheme`、不用系统材质；顶排借 S1 chrome 的登记常量与玻璃 helper，
/// 页面其余取值只经 `S0DeckMetrics`。
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

    @State private var selection: S0CategoryPageSelection
    /// 页头有没有滚走。**只在跨阈值时写**，静止不写（陷阱 5）。
    @State private var isHeaderCollapsed = false
    @StateObject private var toast = S0FeedbackToastPresenter()

    init(
        machine: S0StateMachine,
        category: S0CategorySnapshot,
        items: [S0CategoryAsset],
        flowModel: S0CleanupFlowModel,
        onMoveToBasket: @escaping (Set<String>) -> Bool,
        onBack: @escaping () -> Void,
        onLongPress: @escaping ([String], String) -> Void,
        toastDurationMilliseconds: Double,
        transitionNamespace: Namespace.ID
    ) {
        self.machine = machine
        self.category = category
        self.flowModel = flowModel
        self.onMoveToBasket = onMoveToBasket
        self.onBack = onBack
        self.onLongPress = onLongPress
        self.toastDurationMilliseconds = toastDurationMilliseconds
        self.transitionNamespace = transitionNamespace
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
    }

    // MARK: - 滚动内容

    private func scrollContent(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                scrollOffsetReader
                header(width: width)
                sectionsAndGrids(width: width)
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
            Spacer(minLength: 0)
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
                    "deck.home.open.subtitle",
                    replacing: ["count": String(selection.items.count)]
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
                "deck.home.share",
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
                compactNavTitle
                compactNavSelectAll
            }
            .padding(.leading, S0DeckMetrics.compactNavLeadingPadding)
            .padding(.trailing, S0DeckMetrics.compactNavTrailingPadding)
            .frame(height: S0DeckMetrics.compactNavHeight)
            .modifier(
                S0DeckGlassPanel(
                    cornerRadius: S0DeckMetrics.compactNavCornerRadius
                )
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
                    "deck.home.share",
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

    // MARK: - 两节与网格

    private func sectionsAndGrids(width: CGFloat) -> some View {
        let split = S0DeckHomeModel.sections(
            selection.items,
            topLimit: S0DeckMetrics.topSectionLimit
        )
        let side = cellWidth(forWidth: width)
        return VStack(alignment: .leading, spacing: 0) {
            topSectionHeader(split.top)
            grid(split.top, width: side)
            restSectionHeader(split.rest)
            grid(split.rest, width: side)
        }
    }

    /// 网格空了（整类都进了待删篮）时整节不画——否则会读出「最大的 0 个」与
    /// 「全选这 0 个」。
    @ViewBuilder
    private func topSectionHeader(_ items: [S0CategoryAsset]) -> some View {
        if !items.isEmpty {
            sectionHeader(
                title: L10n.text(
                    "deck.page.top.title",
                    replacing: ["count": String(items.count)]
                ),
                detail: S0ByteCountText.string(
                    forByteCount: S0DeckHomeModel.topSum(
                        items,
                        limit: items.count
                    ).byteCount
                ),
                action: L10n.text(
                    "deck.page.top.action",
                    replacing: ["count": String(items.count)]
                ),
                handler: { selectTopSection(items) }
            )
        }
    }

    @ViewBuilder
    private func restSectionHeader(_ items: [S0CategoryAsset]) -> some View {
        if !items.isEmpty {
            sectionHeader(
                title: L10n.text(
                    "deck.page.rest.title",
                    replacing: ["count": String(items.count)]
                ),
                detail: S0ByteCountText.string(
                    forByteCount: S0DeckHomeModel.topSum(
                        items,
                        limit: items.count
                    ).byteCount
                ),
                action: nil,
                handler: nil
            )
        }
    }

    private func sectionHeader(
        title: String,
        detail: String,
        action: String?,
        handler: (() -> Void)?
    ) -> some View {
        HStack(spacing: S0DeckMetrics.sectionTitleItemSpacing) {
            Text(title)
                .font(
                    .system(
                        size: S0DeckMetrics.sectionTitleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
            Text(detail)
                .font(
                    .system(
                        size: S0DeckMetrics.sectionTitleFontSize,
                        weight: .medium
                    )
                )
                .monospacedDigit()
                .foregroundStyle(
                    S0DeckMetrics.dimmedText(
                        opacity: S0DeckMetrics.sectionTitleDimmedOpacity
                    )
                )
            Spacer(minLength: 0)
            sectionAction(action, handler: handler)
        }
        .frame(height: S0DeckMetrics.sectionHeight)
        .padding(.leading, S0DeckMetrics.sectionLeadingInset)
        .padding(.trailing, S0DeckMetrics.sectionTrailingInset)
        .padding(.top, S0DeckMetrics.sectionTopSpacing)
    }

    @ViewBuilder
    private func sectionAction(
        _ action: String?,
        handler: (() -> Void)?
    ) -> some View {
        if let action, let handler {
            Button(action: handler) {
                HStack(spacing: S0DeckMetrics.sectionActionItemSpacing) {
                    Image(systemName: S0DeckSymbol.sparkle)
                    Text(action)
                }
                .font(
                    .system(
                        size: S0DeckMetrics.sectionActionFontSize,
                        weight: .bold
                    )
                )
                .foregroundStyle(S0DeckMetrics.sectionAction)
                .padding(
                    .horizontal,
                    S0DeckMetrics.sectionActionHorizontalPadding
                )
                .frame(height: S0DeckMetrics.sectionActionHeight)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: S0DeckMetrics.sectionActionCornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        S0DeckMetrics.sectionAction.opacity(
                            S0DeckMetrics.sectionActionRingOpacity
                        ),
                        lineWidth: S0DeckMetrics.sectionActionRingWidth
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func grid(_ items: [S0CategoryAsset], width: CGFloat) -> some View {
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
            .padding(.top, S0DeckMetrics.sectionToGridSpacing)
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
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                onLongPress(selection.items.map(\.id), item.id)
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
        .modifier(
            S0DeckGlassPanel(
                cornerRadius: S0DeckMetrics.gridLabelCornerRadius
            )
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
                            size: S0DeckMetrics.gridLabelFontSize,
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
        VStack(spacing: S2OverlayLayout.minimumSpacing) {
            toastView
            dockBar
        }
        .padding(.horizontal, S0DeckMetrics.dockHorizontalInset)
        .padding(.bottom, S0DeckMetrics.dockBottomInset)
    }

    @ViewBuilder
    private var toastView: some View {
        if let text = toast.activeText {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(S0DeckMetrics.text)
                .padding(.horizontal, S2OverlayLayout.minimumSpacing * 2)
                .padding(.vertical, S2OverlayLayout.minimumSpacing)
                .modifier(
                    S0DeckGlassPanel(
                        cornerRadius: S0DeckMetrics.compactNavCornerRadius
                    )
                )
                .allowsHitTesting(false)
                .accessibilityAddTraits(.isStaticText)
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
        .modifier(
            S0DeckGlassPanel(cornerRadius: S0DeckMetrics.dockCornerRadius)
        )
    }

    private var dockReadout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(
                L10n.text(
                    "deck.page.selected",
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
                Text(L10n.text("deck.page.submit"))
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

    /// 「全选这 N 个」：把这一节并入已选。**幂等**——已选的不再 `toggle`，
    /// 否则第二次点会把它们反选掉。
    private func selectTopSection(_ items: [S0CategoryAsset]) {
        for item in items where !selection.selected.contains(item.id) {
            selection.toggle(item.id)
        }
    }

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
            restByteCount: 0,
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

/// 玻璃面：半透明填充 + 顶缘一道高光。**不用系统材质**（两页恒深色，材质随 trait 变）。
struct S0DeckGlassPanel: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                S0DeckMetrics.glassFill,
                in: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        S0DeckTopHighlight.gradient,
                        lineWidth: S0DeckMetrics.glassTopHighlightWidth
                    )
            }
    }
}

/// 首页展开卡的过渡源。iOS 18 起首页那张卡放大成类别页页头；iOS 17 走默认 push。
struct S0DeckZoomSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

/// 类别页的过渡目的地。与 `S0DeckZoomSource` 同一 `id` 才配得上。
struct S0DeckZoomDestination: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
