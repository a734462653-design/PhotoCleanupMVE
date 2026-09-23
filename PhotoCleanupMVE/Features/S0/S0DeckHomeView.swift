import SwiftUI

/// IC-162 A：「卡片叠」首页（画布 r7.py M1 + r8.py N2「总条联动」，交互 A）。
///
/// IC-165 B 起为正式首页（SPEC-S0 v3 第三节），旧首页退役；并补齐旧首页已有而预览缺的
/// 三样：受限提示条、扫描首帧「正在扫描…」、等待清空行的 `VF` 三态读数（裁定 四）。
///
/// 行为一律照旧（IC-162 裁定 五）：
/// - 启动摄入 `bootstrapIfNeeded()` 与旧首页逐字同源（`hasBootstrapped` 闸 +
///   测试宿主守卫 + 摄入 + 按扫描回报发一次迁移事件）；
/// - 进类别页只在状态机判定为「迁至类别页」时回调容器；
/// - 「我已清空」= `machine.beginVerification()`。
///
/// 恒深色：不读随外观解析的色源，取值只经 `S0DeckMetrics`；顶排的圆钮与胶囊、受限提示条
/// 的玻璃一律借 S1 chrome 的登记常量与玻璃 helper（S0 不自造 chrome 语汇）。
struct S0DeckHomeView: View {
    @ObservedObject var machine: S0StateMachine

    /// 只摄入一次（照 `S0View`：`TabView` 的 tab 每次被选中都会重发 `onAppear`，
    /// 而 `.applicationOpened` 会把 `SC` 打回扫描中）。
    @State private var hasBootstrapped = false
    /// 用户点开的那张卡。落地取值经 `S0DeckHomeModel.resolvedOpenID`——
    /// 那张卡消失或变得不可点时自动回落，不在这里写状态（陷阱 5）。
    @State private var openedCardID: String?

    private let dataProvider: (any S0CleanupDataProviding)?
    private let onEnterCategoryPage: (S0CategoryIdentifier) -> Void
    private let onEnterConfirmation: () -> Void
    private let onOpenAccountSheet: () -> Void
    private let onSwitchToOrganizeTab: () -> Void
    private let onOpenSystemSettings: () -> Void
    private let onRetry: () -> Void
    /// IC-162 B：进类别页的 zoom 过渡命名空间。宿主是流程容器（`Namespace.ID` 没有
    /// 缺省值，故排在带缺省值的八个之后，由调用方显式给出）。
    private let transitionNamespace: Namespace.ID

    init(
        machine: S0StateMachine,
        dataProvider: (any S0CleanupDataProviding)? = nil,
        onEnterCategoryPage: @escaping (S0CategoryIdentifier) -> Void = { _ in },
        onEnterConfirmation: @escaping () -> Void = {},
        onOpenAccountSheet: @escaping () -> Void = {},
        onSwitchToOrganizeTab: @escaping () -> Void = {},
        onOpenSystemSettings: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        transitionNamespace: Namespace.ID
    ) {
        self.machine = machine
        self.dataProvider = dataProvider
        self.onEnterCategoryPage = onEnterCategoryPage
        self.onEnterConfirmation = onEnterConfirmation
        self.onOpenAccountSheet = onOpenAccountSheet
        self.onSwitchToOrganizeTab = onSwitchToOrganizeTab
        self.onOpenSystemSettings = onOpenSystemSettings
        self.onRetry = onRetry
        self.transitionNamespace = transitionNamespace
    }

    var body: some View {
        ZStack(alignment: .top) {
            S0DeckMetrics.background
                .ignoresSafeArea()
            content
        }
        .onAppear {
            bootstrapIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch machine.state {
        case .scanning, .ready:
            deckScreen
        case .empty:
            centeredBlock(
                title: L10n.text("s0.home.hero.empty.title"),
                action: L10n.text("s0.home.hero.empty.action"),
                handler: onSwitchToOrganizeTab
            )
        case .failed:
            failureBlock
        }
    }

    // MARK: - 就绪／扫描中的整套版式

    private var deckScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topRow
                limitedBanner
                heroBlock
                pendingRow
                totalBar
                totalBarCaption
                deck
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 顶排（借 S1 chrome，零新数）

    private var topRow: some View {
        HStack(spacing: S1ChromeLayout.itemSpacing) {
            Text(L10n.text("s0.home.title"))
                .font(
                    .system(
                        size: S1ChromeTypography.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
            Spacer(minLength: 0)
            if machine.accepts(.basketCapsule) {
                basketCapsule
            }
            accountButton
        }
        .frame(height: S1ChromeLayout.rowHeight)
        .padding(.horizontal, S1ChromeLayout.horizontalMargin)
        .padding(.top, S1ChromeLayout.topRowTopInset)
    }

    private var basketCapsule: some View {
        Button(action: onEnterConfirmation) {
            Text(
                L10n.text(
                    "s0.basket.capsule",
                    replacing: [
                        "count": String(machine.mergedPendingDeletionCount),
                        "volume": S0ByteCountText.string(
                            forByteCount: machine.pendingDeletionByteCount
                        )
                    ]
                )
            )
            .font(.system(size: S1ChromeTypography.titleFontSize))
            .foregroundStyle(S0DeckMetrics.text)
            .padding(.horizontal, S1ChromeLayout.itemSpacing)
            .frame(height: S1ChromeLayout.rowHeight)
            .s1ChromeGlassBackground(in: Capsule(), interactive: true)
        }
    }

    private var accountButton: some View {
        Button(action: onOpenAccountSheet) {
            Image(systemName: S0DeckSymbol.account)
                .foregroundStyle(S0DeckMetrics.text)
                .s1ChromeCircleGlass()
        }
        .accessibilityLabel(L10n.text("s0.account.title"))
    }

    // MARK: - 受限提示条（IC-165 B，裁定 四：照旧首页的写法搬）

    /// 几何取 `S1LimitedBannerStyle`、文案借「逐张整理」tab 的受限提示句（S0 不自造 chrome 语汇）；
    /// 玻璃经 S1 helper。本页没有旧首页的 `homeState`，S0-4 不显示的守卫改读状态机四态。
    /// 左右边距与距顶排的间隙沿用旧首页容器的 `S1ChromeLayout` 两值。
    @ViewBuilder
    private var limitedBanner: some View {
        if machine.isLimitedAuthorization && machine.state != .failed {
            Text(L10n.text("s1.limited.banner"))
                .font(.system(size: S1LimitedBannerStyle.textFontSize))
                .foregroundStyle(S0DeckMetrics.text)
                .padding(.horizontal, S1LimitedBannerStyle.horizontalPadding)
                .frame(
                    maxWidth: .infinity,
                    minHeight: S1LimitedBannerStyle.height,
                    alignment: .leading
                )
                .s1ChromeGlassBackground(
                    in: RoundedRectangle(
                        cornerRadius: S1LimitedBannerStyle.cornerRadius,
                        style: .continuous
                    ),
                    interactive: false
                )
                .padding(.horizontal, S1ChromeLayout.horizontalMargin)
                .padding(.top, S1ChromeLayout.chromeToOverlaySpacing)
        }
    }

    // MARK: - 大数字区

    private var heroBlock: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.text("s0.home.hero.label"))
                    .font(
                        .system(
                            size: S0DeckMetrics.heroLabelFontSize,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        S0DeckMetrics.dimmedText(
                            opacity: S0DeckMetrics.heroLabelOpacity
                        )
                    )
                heroValue
                scanningSubText
            }
            Spacer(minLength: 0)
            releasedBlock
        }
        .padding(.horizontal, S0DeckMetrics.totalBarHorizontalInset)
        .padding(.top, S0DeckMetrics.heroTopSpacing)
    }

    /// 大数字取**照片库总占用**（④ Decision_log 第 187 条：整库照片与视频占用都
    /// 计为「可清理空间」）。
    ///
    /// IC-165 B（裁定 四）：扫描中且首帧数据未到（`LIB` 仍为零）时显示「正在扫描…」，
    /// 不显示零字节大数字（第 165 条第 3 条）。判据只看 `LIB`，不看可清理量。
    /// v3 第十四节未登记该句字号，借 S1 标题字号（报告登记为 v3 订正候选）。
    @ViewBuilder
    private var heroValue: some View {
        if machine.state == .scanning && machine.snapshot.libraryTotalByteCount == 0 {
            Text(L10n.text("s0.home.hero.scanning"))
                .font(.system(size: S1ChromeTypography.titleFontSize))
                .foregroundStyle(S0DeckMetrics.text)
        } else {
            let parts = S0ByteCountSplit.split(
                S0ByteCountText.string(
                    forByteCount: machine.snapshot.libraryTotalByteCount
                )
            )
            HStack(
                alignment: .lastTextBaseline,
                spacing: S0DeckMetrics.heroUnitSpacing
            ) {
                Text(parts.value)
                    .font(
                        .system(
                            size: S0DeckMetrics.heroValueFontSize,
                            weight: .heavy
                        )
                    )
                    .tracking(S0DeckMetrics.heroValueLetterSpacing)
                    .monospacedDigit()
                    .foregroundStyle(S0DeckMetrics.text)
                Text(parts.unit)
                    .font(.system(size: S0DeckMetrics.heroUnitFontSize))
                    .foregroundStyle(
                        S0DeckMetrics.dimmedText(
                            opacity: S0DeckMetrics.heroUnitOpacity
                        )
                    )
            }
        }
    }

    /// 扫描中：大数字下的小字用既有进度 key（裁定 四）。
    @ViewBuilder
    private var scanningSubText: some View {
        if machine.state == .scanning {
            Text(
                L10n.text(
                    "s0.home.hero.progress",
                    replacing: [
                        "scanned": String(
                            machine.snapshot.progress.scannedAssetCount
                        ),
                        "total": String(
                            machine.snapshot.progress.totalAssetCount
                        )
                    ]
                )
            )
            .font(.system(size: S0DeckMetrics.pendingRowFontSize))
            .monospacedDigit()
            .foregroundStyle(
                S0DeckMetrics.dimmedText(
                    opacity: S0DeckMetrics.pendingRowOpacity
                )
            )
        }
    }

    /// 累计已腾出：`Z` 为零时整块不显示（裁定 二）。
    @ViewBuilder
    private var releasedBlock: some View {
        if machine.cumulativeReleasedByteCount > 0 {
            let parts = S0ByteCountSplit.split(
                S0ByteCountText.string(
                    forByteCount: machine.cumulativeReleasedByteCount
                )
            )
            VStack(alignment: .trailing, spacing: 0) {
                Text(L10n.text("s0.home.released"))
                    .font(.system(size: S0DeckMetrics.releasedLabelFontSize))
                    .foregroundStyle(
                        S0DeckMetrics.dimmedText(
                            opacity: S0DeckMetrics.releasedLabelOpacity
                        )
                    )
                HStack(
                    alignment: .lastTextBaseline,
                    spacing: S0DeckMetrics.stripUnitSpacing
                ) {
                    Text(parts.value)
                        .font(
                            .system(
                                size: S0DeckMetrics.releasedValueFontSize,
                                weight: .heavy
                            )
                        )
                        .tracking(S0DeckMetrics.releasedValueLetterSpacing)
                        .monospacedDigit()
                    Text(parts.unit)
                        .font(
                            .system(size: S0DeckMetrics.releasedUnitFontSize)
                        )
                }
                .foregroundStyle(S0DeckMetrics.mint)
            }
            .padding(.bottom, S0DeckMetrics.releasedBaselinePadding)
        }
    }

    // MARK: - 等待清空行

    @ViewBuilder
    private var pendingRow: some View {
        if machine.showsPendingClearanceRow {
            HStack(spacing: S0DeckMetrics.pendingActionSpacing) {
                Text(
                    L10n.text(
                        "s0.home.pending.label",
                        replacing: [
                            "total": S0ByteCountText.string(
                                forByteCount: machine.pendingClearanceByteCount
                            )
                        ]
                    )
                )
                .font(.system(size: S0DeckMetrics.pendingRowFontSize))
                .foregroundStyle(
                    S0DeckMetrics.dimmedText(
                        opacity: S0DeckMetrics.pendingRowOpacity
                    )
                )
                if machine.accepts(.ledgerCleared) {
                    pendingActionButton
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, S0DeckMetrics.totalBarHorizontalInset)
            .padding(.top, S0DeckMetrics.pendingRowTopSpacing)
        }
        verificationRow
    }

    /// IC-165 B（裁定 四）：`VF` 三态读数，照旧首页 `verificationRow` 的写法搬。
    ///
    /// `VF` 的呈现**只反映状态机给出的值**。**不自造「已通过」读数的淡出、计时或自动
    /// 清除**——第 170 条裁定 3：`VF=已通过` 的复位路径未定，归批次 5.3。本视图因此不含
    /// 任何定时器、不含任何把 `VF` 推进或复位的调用；写入仍只在「我已清空」那一处。
    @ViewBuilder
    private var verificationRow: some View {
        switch machine.verificationState {
        case .none:
            EmptyView()
        case .checking:
            pendingStatusText(L10n.text("s0.home.pending.checking"))
        case .passed:
            pendingStatusText(
                L10n.text(
                    "s0.home.pending.passed",
                    replacing: [
                        "released": S0ByteCountText.string(
                            forByteCount: machine.lastVerifiedReleasedByteCount
                        )
                    ]
                )
            )
        case .failed:
            pendingStatusText(L10n.text("s0.home.pending.failed"))
        }
    }

    /// 读数小字：与等待清空行同字号、同压暗（Deck 语汇，不加新登记值）。
    private func pendingStatusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: S0DeckMetrics.pendingRowFontSize))
            .foregroundStyle(
                S0DeckMetrics.text.opacity(S0DeckMetrics.pendingRowOpacity)
            )
            .padding(.horizontal, S0DeckMetrics.totalBarHorizontalInset)
    }

    private var pendingActionButton: some View {
        Button {
            machine.beginVerification()
        } label: {
            Text(L10n.text("s0.home.pending.action"))
                .font(
                    .system(
                        size: S0DeckMetrics.pendingRowFontSize,
                        weight: .bold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
        }
    }

    // MARK: - 总条与标注行（N2 联动）

    private var totalBar: some View {
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
        .frame(height: S0DeckMetrics.totalBarHeight)
        .padding(.horizontal, S0DeckMetrics.totalBarHorizontalInset)
        .padding(.top, S0DeckMetrics.totalBarTopSpacing)
    }

    private func segmentView(
        _ segment: S0SegmentBarModel.Segment,
        usableWidth: CGFloat
    ) -> some View {
        let identifier = Self.cardID(for: segment.kind)
        let isCurrent = identifier != nil && identifier == resolvedOpenID
        return RoundedRectangle(
            cornerRadius: S0DeckMetrics.totalBarCornerRadius,
            style: .continuous
        )
        .fill(Self.segmentColor(for: segment.kind))
        .opacity(isCurrent ? 1 : S0DeckMetrics.totalBarDimmedOpacity)
        .frame(width: usableWidth * CGFloat(segment.widthFraction))
        .contentShape(Rectangle())
        .onTapGesture {
            expandCard(withID: identifier)
        }
    }

    @ViewBuilder
    private var totalBarCaption: some View {
        if let card = openCard {
            HStack(spacing: S0DeckMetrics.totalBarCaptionItemSpacing) {
                RoundedRectangle(
                    cornerRadius: S0DeckMetrics.totalBarCaptionDotCornerRadius,
                    style: .continuous
                )
                .fill(S0DeckMetrics.cardColor(for: card.category))
                .frame(
                    width: S0DeckMetrics.totalBarCaptionDotSide,
                    height: S0DeckMetrics.totalBarCaptionDotSide
                )
                Text(Self.name(for: card))
                    .font(
                        .system(
                            size: S0DeckMetrics.totalBarCaptionFontSize,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(S0DeckMetrics.text)
                Text(
                    L10n.text(
                        "s0.home.bar.caption",
                        replacing: Self.shareReplacements(for: card)
                    )
                )
                .font(
                    .system(
                        size: S0DeckMetrics.totalBarCaptionFontSize,
                        weight: .medium
                    )
                )
                .monospacedDigit()
                .foregroundStyle(
                    S0DeckMetrics.dimmedText(
                        opacity: S0DeckMetrics.totalBarCaptionDimmedOpacity
                    )
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, S0DeckMetrics.totalBarHorizontalInset)
            .padding(.top, S0DeckMetrics.totalBarCaptionTopSpacing)
        }
    }

    // MARK: - 卡片叠

    private var deck: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { item in
                    cardButton(
                        item.element,
                        index: item.offset,
                        width: geometry.size.width
                    )
                    .zIndex(Double(item.offset))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(height: deckHeight)
        .padding(.horizontal, S0DeckMetrics.deckHorizontalInset)
        .padding(.top, S0DeckMetrics.deckTopSpacing)
    }

    private func cardButton(
        _ card: S0DeckHomeModel.Card,
        index: Int,
        width: CGFloat
    ) -> some View {
        let isOpen = card.id == resolvedOpenID
        let visible = isOpen
            ? S0DeckMetrics.openCardVisibleHeight
            : S0DeckMetrics.stripVisibleHeight
        let isTail = !isOpen && index == cards.count - 1
        let height = visible + (
            isTail
                ? S0DeckMetrics.lastCardTailHeight
                : S0DeckMetrics.cardOverhang
        )
        return Button {
            handleTap(on: card, isOpen: isOpen)
        } label: {
            cardSurface(
                card,
                isOpen: isOpen,
                width: width,
                height: height,
                visibleHeight: visible
            )
        }
        .buttonStyle(.plain)
        .disabled(!card.isEnterable)
        // IC-162 B：这张卡即进类别页的过渡源（iOS 18 起放大成页头，iOS 17 走默认 push）。
        .modifier(
            S0DeckZoomSource(id: card.id, namespace: transitionNamespace)
        )
        .offset(y: offset(forIndex: index))
    }

    private func cardSurface(
        _ card: S0DeckHomeModel.Card,
        isOpen: Bool,
        width: CGFloat,
        height: CGFloat,
        visibleHeight: CGFloat
    ) -> some View {
        cardContent(
            card,
            isOpen: isOpen,
            width: width,
            height: height,
            visibleHeight: visibleHeight
        )
        .frame(width: width, height: height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: S0DeckMetrics.cardCornerRadius,
                style: .continuous
            )
        )
        // IC-163 B（裁定 二）：命中区 = 卡的圆角矩形。`clipShape` 同样只裁绘制，后画的
        // 卡 `zIndex` 更高，溢出的命中区会盖住展开卡与总条。
        .contentShape(
            RoundedRectangle(
                cornerRadius: S0DeckMetrics.cardCornerRadius,
                style: .continuous
            )
        )
        // r7.py `.dk .edge` 是两道 inset 阴影：一圈 0.12 的描边，加上缘一道 0.34 的高光。
        .overlay {
            RoundedRectangle(
                cornerRadius: S0DeckMetrics.cardCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                S0DeckMetrics.text.opacity(S0DeckMetrics.cardRingOpacity),
                lineWidth: S0DeckMetrics.cardRingWidth
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: S0DeckMetrics.cardCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                S0DeckTopHighlight.gradient,
                lineWidth: S0DeckMetrics.glassTopHighlightWidth
            )
        }
        .shadow(
            color: Color.black.opacity(S0DeckMetrics.cardShadowOpacity),
            radius: S0DeckMetrics.cardShadowRadius,
            y: S0DeckMetrics.cardShadowYOffset
        )
    }

    /// IC-163 B：展开／收起的切换过渡。每一层内容都是自己被插入／移除的那个视图
    /// （条件写在各自的 `overlay` 里），过渡才会作用在它身上——整支 `if`／`else` 换掉时
    /// 嵌在里面的 `.transition` 不保证生效（③）。封面仍随展开态换身份、按新尺寸重取，
    /// 与改前的 `if`／`else` 两支各建一只封面同效。节奏跟随 `expandCard` 的 spring。
    private func cardContent(
        _ card: S0DeckHomeModel.Card,
        isOpen: Bool,
        width: CGFloat,
        height: CGFloat,
        visibleHeight: CGFloat
    ) -> some View {
        S0DeckCoverView(
            assetIdentifier: coverAssetID(for: card),
            width: width,
            height: height
        )
        .id(coverAssetID(for: card))
        .id(isOpen)
        .overlay {
            if !isOpen {
                S0DeckShade.strip
            }
        }
        .overlay(alignment: .top) {
            if isOpen {
                S0DeckShade.open
                    .frame(height: visibleHeight)
            }
        }
        .overlay(alignment: .topLeading) {
            if isOpen {
                shareBadge(card)
                    .padding(S0DeckMetrics.openBadgeInset)
                    .transition(Self.openContentTransition)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isOpen {
                openTextBlock(card)
                    .padding(.leading, S0DeckMetrics.openTextLeadingInset)
                    .padding(
                        .bottom,
                        S0DeckMetrics.cardOverhang
                            + S0DeckMetrics.openTextBottomInset
                    )
                    .transition(Self.openContentTransition)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isOpen {
                openActionLabel
                    .padding(
                        .trailing,
                        S0DeckMetrics.openActionTrailingInset
                    )
                    .padding(
                        .bottom,
                        S0DeckMetrics.cardOverhang
                            + S0DeckMetrics.openActionBottomInset
                    )
                    .transition(Self.openContentTransition)
            }
        }
        .overlay(alignment: .top) {
            if !isOpen {
                stripRow(card)
                    .frame(height: visibleHeight)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 展开卡的四件

    private func shareBadge(_ card: S0DeckHomeModel.Card) -> some View {
        Text(
            L10n.text(
                "s0.home.share",
                replacing: Self.shareReplacements(for: card)
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

    private func openTextBlock(_ card: S0DeckHomeModel.Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.name(for: card))
                .font(
                    .system(
                        size: S0DeckMetrics.openNameFontSize,
                        weight: .medium
                    )
                )
            Text(S0ByteCountText.string(forByteCount: card.byteCount))
                .font(
                    .system(
                        size: S0DeckMetrics.openValueFontSize,
                        weight: .heavy
                    )
                )
                .tracking(S0DeckMetrics.openValueLetterSpacing)
                .monospacedDigit()
            Text(
                L10n.text(
                    "s0.home.open.subtitle",
                    replacing: ["count": String(candidateCount(for: card))]
                )
            )
            .font(.system(size: S0DeckMetrics.openSubFontSize))
            .monospacedDigit()
            .foregroundStyle(
                S0DeckMetrics.dimmedText(
                    opacity: S0DeckMetrics.openSubOpacity
                )
            )
            .padding(.top, S0DeckMetrics.openSubTopSpacing)
        }
        .foregroundStyle(S0DeckMetrics.text)
        .shadow(
            color: Color.black.opacity(S0DeckMetrics.openTextShadowOpacity),
            radius: S0DeckMetrics.openTextShadowRadius,
            y: S0DeckMetrics.openTextShadowYOffset
        )
    }

    /// 「去清理」是**卡上的标签不是另一只按钮**：整张展开卡即入口（裁定 五），
    /// 嵌套按钮会把点按语义拆成两处。
    private var openActionLabel: some View {
        HStack(spacing: S0DeckMetrics.openActionItemSpacing) {
            Text(L10n.text("s0.home.open.action"))
            Image(systemName: S0DeckSymbol.chevron)
        }
        .font(
            .system(
                size: S0DeckMetrics.openActionFontSize,
                weight: .bold
            )
        )
        .foregroundStyle(S0DeckMetrics.background)
        .padding(.leading, S0DeckMetrics.openActionLeadingPadding)
        .padding(.trailing, S0DeckMetrics.openActionTrailingPadding)
        .frame(height: S0DeckMetrics.openActionHeight)
        .background(
            S0DeckMetrics.text,
            in: RoundedRectangle(
                cornerRadius: S0DeckMetrics.openActionCornerRadius,
                style: .continuous
            )
        )
    }

    // MARK: - 收起条

    private func stripRow(_ card: S0DeckHomeModel.Card) -> some View {
        let parts = S0ByteCountSplit.split(
            S0ByteCountText.string(forByteCount: card.byteCount)
        )
        return HStack(spacing: S0DeckMetrics.stripItemSpacing) {
            RoundedRectangle(
                cornerRadius: S0DeckMetrics.stripDotCornerRadius,
                style: .continuous
            )
            .fill(S0DeckMetrics.cardColor(for: card.category))
            .frame(
                width: S0DeckMetrics.stripDotSide,
                height: S0DeckMetrics.stripDotSide
            )
            Text(Self.name(for: card))
                .font(
                    .system(
                        size: S0DeckMetrics.stripNameFontSize,
                        weight: .medium
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
            Text(Self.shareText(for: card))
                .font(.system(size: S0DeckMetrics.stripShareFontSize))
                .monospacedDigit()
                .foregroundStyle(
                    S0DeckMetrics.dimmedText(
                        opacity: S0DeckMetrics.stripShareOpacity
                    )
                )
            Spacer(minLength: 0)
            stripValue(parts)
            // 裁定 二：「其余照片」不可点，**不画右箭头**（与 `showsDisclosure` 同口径：
            // 只有能进类别页的条才画）。
            if card.isEnterable {
                Image(systemName: S0DeckSymbol.chevron)
                    .foregroundStyle(
                        S0DeckMetrics.dimmedText(
                            opacity: S0DeckMetrics.stripChevronOpacity
                        )
                    )
            }
        }
        .padding(.leading, S0DeckMetrics.stripLeadingInset)
        .padding(.trailing, S0DeckMetrics.stripTrailingInset)
    }

    private func stripValue(_ parts: (value: String, unit: String)) -> some View {
        HStack(
            alignment: .lastTextBaseline,
            spacing: S0DeckMetrics.stripUnitSpacing
        ) {
            Text(parts.value)
                .font(
                    .system(
                        size: S0DeckMetrics.stripValueFontSize,
                        weight: .heavy
                    )
                )
                .tracking(S0DeckMetrics.stripValueLetterSpacing)
                .monospacedDigit()
                .foregroundStyle(S0DeckMetrics.text)
            Text(parts.unit)
                .font(.system(size: S0DeckMetrics.stripUnitFontSize))
                .foregroundStyle(
                    S0DeckMetrics.dimmedText(
                        opacity: S0DeckMetrics.stripUnitOpacity
                    )
                )
        }
    }

    // MARK: - 空态与失败态（版式不作要求，文案与回调照 `S0View`）

    private func centeredBlock(
        title: String,
        action: String,
        handler: @escaping () -> Void
    ) -> some View {
        VStack(spacing: S1ChromeLayout.chromeToListSpacing) {
            Text(title)
                .font(.system(size: S0DeckMetrics.heroUnitFontSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(S0DeckMetrics.text)
            Button(action: handler) {
                Text(action)
                    .font(.system(size: S1ChromeTypography.titleFontSize))
                    .foregroundStyle(S0DeckMetrics.text)
                    .padding(.horizontal, S1ChromeLayout.horizontalMargin)
                    .frame(height: S1ChromeLayout.rowHeight)
                    .s1ChromeGlassBackground(in: Capsule(), interactive: true)
            }
        }
        .padding(.horizontal, S0DeckMetrics.totalBarHorizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var failureBlock: some View {
        if machine.failureCategory == .authorization {
            centeredBlock(
                title: L10n.text("s0.home.failed.auth.title"),
                action: L10n.text("s0.home.failed.auth.action"),
                handler: onOpenSystemSettings
            )
        } else {
            centeredBlock(
                title: L10n.text("s0.home.failed.read.title"),
                action: L10n.text("s0.home.failed.read.action"),
                handler: onRetry
            )
        }
    }

    // MARK: - 取数与派生

    private var cards: [S0DeckHomeModel.Card] {
        S0DeckHomeModel.cards(
            categories: machine.orderedCategories,
            restByteCount: restByteCount,
            libraryTotalByteCount: machine.snapshot.libraryTotalByteCount
        )
    }

    /// 「其余照片」的字节量取分段条模型 `.rest` 段的现成读数（不另算一份）。
    private var restByteCount: Int64 {
        for segment in segmentBarModel.segments where segment.kind == .rest {
            return segment.byteCount
        }
        return 0
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

    /// 展开哪张：用户点过的那张仍在且仍可点就用它，否则回落到第一张可点的。
    private var resolvedOpenID: String? {
        S0DeckHomeModel.resolvedOpenID(current: openedCardID, cards: cards)
    }

    private var openCard: S0DeckHomeModel.Card? {
        guard let resolvedOpenID else {
            return nil
        }
        return cards.first { $0.id == resolvedOpenID }
    }

    private var deckHeight: CGFloat {
        var total = S0DeckMetrics.lastCardTailHeight
        for card in cards {
            total += card.id == resolvedOpenID
                ? S0DeckMetrics.openCardVisibleHeight
                : S0DeckMetrics.stripVisibleHeight
        }
        return total
    }

    private func offset(forIndex index: Int) -> CGFloat {
        var total: CGFloat = 0
        for (position, card) in cards.enumerated() where position < index {
            total += card.id == resolvedOpenID
                ? S0DeckMetrics.openCardVisibleHeight
                : S0DeckMetrics.stripVisibleHeight
        }
        return total
    }

    private func coverAssetID(for card: S0DeckHomeModel.Card) -> String? {
        guard let identifier = card.category else {
            return nil
        }
        return machine.category(identifier)?.coverAssetID
    }

    private func candidateCount(for card: S0DeckHomeModel.Card) -> Int {
        guard let identifier = card.category else {
            return 0
        }
        return machine.category(identifier)?.candidateCount ?? 0
    }

    // MARK: - 交互（裁定 五）

    /// 点展开卡 → 进类别页；点收起的条 → 它展开、原展开卡收成一条，各卡次序不变。
    private func handleTap(on card: S0DeckHomeModel.Card, isOpen: Bool) {
        guard isOpen else {
            expandCard(withID: card.id)
            return
        }
        guard let identifier = card.category else {
            return
        }
        // 迁移由状态机判定；只有判定为「迁至类别页」才回调容器。
        if case let .categoryPage(target) =
            machine.handle(.categoryRowTapped(identifier)) {
            onEnterCategoryPage(target)
        }
    }

    /// 展开某张卡。配不上卡、或那张卡不可点时什么也不做（总条上的段同此口径）。
    private func expandCard(withID identifier: String?) {
        guard let identifier,
              cards.contains(where: { $0.id == identifier && $0.isEnterable })
        else {
            return
        }
        withAnimation(
            .spring(
                response: S0DeckMetrics.expandAnimationResponse,
                dampingFraction: S0DeckMetrics.expandAnimationDamping
            )
        ) {
            openedCardID = identifier
        }
    }

    // MARK: - 取数（照 `S0View.bootstrapIfNeeded` 逐字）

    /// 遵循 E4 口径：测试宿主下不自动启动任何活动。真机与模拟器上首次出现时
    /// 摄入一次数据源的当前结果，并按其回报发一次迁移事件。
    private func bootstrapIfNeeded() {
        guard !hasBootstrapped,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              let provider = dataProvider else {
            return
        }
        hasBootstrapped = true
        machine.ingest(provider.currentSnapshot())
        switch provider.currentScanOutcome() {
        case .scanning:
            machine.handle(.applicationOpened)
        case .completed:
            machine.handle(.scanCompleted)
        case let .failed(category):
            machine.handle(.scanFailed(category))
        }
    }

    // MARK: - 与视图状态无关的派生（静态，便于逐条核对）

    /// IC-163 B：展开卡内容层的过渡——淡入并自下而上升 `expandContentRise`。
    static var openContentTransition: AnyTransition {
        AnyTransition.opacity.combined(
            with: AnyTransition.offset(y: S0DeckMetrics.expandContentRise)
        )
    }

    static func cardID(for kind: S0SegmentBarModel.Kind) -> String? {
        switch kind {
        case let .category(identifier):
            return identifier.rawValue
        case .rest:
            return S0DeckHomeModel.restCardID
        case .unscanned:
            return nil
        }
    }

    static func segmentColor(for kind: S0SegmentBarModel.Kind) -> Color {
        switch kind {
        case let .category(identifier):
            return S0DeckMetrics.categoryColor(for: identifier)
        case .rest:
            return S0DeckMetrics.colorRest
        case .unscanned:
            return S0DeckMetrics.dimmedText(
                opacity: S0DeckMetrics.totalBarUnscannedFillOpacity
            )
        }
    }

    static func name(for card: S0DeckHomeModel.Card) -> String {
        guard let identifier = card.category else {
            return L10n.text("s0.category.rest")
        }
        return S0CategoryText.displayName(for: identifier)
    }

    /// 占比的实参形如 `36%`：百分号在实参里拼，不进目录值以外的字面量。
    static func shareReplacements(
        for card: S0DeckHomeModel.Card
    ) -> [String: String] {
        [
            "percent": String(card.percent) + S0DeckSymbol.percentSign,
            "bytes": S0ByteCountText.string(forByteCount: card.byteCount)
        ]
    }

    static func shareText(for card: S0DeckHomeModel.Card) -> String {
        String(card.percent) + S0DeckSymbol.percentSign
    }
}

/// 顶缘高光：CSS 的 `inset 0 0.5px 0 rgba(255,255,255,0.34)` 只亮上缘，SwiftUI 侧
/// 用一道自上而下收到零的竖向渐变描边近似（与 `S0GlassSurface` 的既有做法同制）。
enum S0DeckTopHighlight {
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [
                S0DeckMetrics.text.opacity(
                    S0DeckMetrics.glassTopHighlightOpacity
                ),
                S0DeckMetrics.text.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// 卡上的两道压暗渐变。取值全部来自 `S0DeckMetrics`，视图体内不写裸数。
enum S0DeckShade {
    /// 收起条：整张条自上而下压暗（r7.py `.dk .dim`）。
    static var strip: LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: Color.black.opacity(
                        S0DeckMetrics.stripDimTopOpacity
                    ),
                    location: 0
                ),
                Gradient.Stop(
                    color: Color.black.opacity(
                        S0DeckMetrics.stripDimMiddleOpacity
                    ),
                    location: S0DeckMetrics.stripDimMiddleLocation
                ),
                Gradient.Stop(
                    color: Color.black.opacity(
                        S0DeckMetrics.stripDimBottomOpacity
                    ),
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 展开卡：上缘一道、下缘一大片，中间让照片透出来（r7.py `.dk.open .shade`）。
    static var open: LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: Color.black.opacity(
                        S0DeckMetrics.openShadeTopOpacity
                    ),
                    location: 0
                ),
                Gradient.Stop(
                    color: Color.black.opacity(0),
                    location: S0DeckMetrics.openShadeUpperLocation
                ),
                Gradient.Stop(
                    color: Color.black.opacity(
                        S0DeckMetrics.openShadeLowerOpacity
                    ),
                    location: S0DeckMetrics.openShadeLowerLocation
                ),
                Gradient.Stop(
                    color: Color.black.opacity(
                        S0DeckMetrics.openShadeBottomOpacity
                    ),
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
