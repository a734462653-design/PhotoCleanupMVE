import SwiftUI

/// IC-156 C：类别页的选择集合 `SEL`（SPEC-S0 v2 第六节）。纯模型，可直接断言。
///
/// - 全部项默认不勾选，不预勾任何项；
/// - 网格顺序在页面存续期间稳定：移入待删篮只删项、不重排其余项；
/// - 「已选」计数与主按钮数值由同一份 `selected` 算出，不分别计算。
struct S0CategoryPageSelection: Equatable {
    private(set) var items: [S0CategoryAsset]
    private(set) var selected: Set<String> = []

    /// IC-160 A（裁定 三）：`preselected` 是跨 S2 往返带回来的保留集，与当前网格求交——
    /// 在 S2 里被标记的那几张已从列表消失，不该留在已选集合里。缺省为空即旧行为。
    init(items: [S0CategoryAsset], preselected: Set<String> = []) {
        self.items = items
        self.selected = preselected.intersection(Set(items.map { $0.id }))
    }

    /// 网格全部项的字节和（副行的体积）。
    var totalByteCount: Int64 {
        items.reduce(into: Int64(0)) { total, item in
            total += item.byteCount
        }
    }

    /// 已选项的字节和（常驻行与主按钮共用）。
    var selectedByteCount: Int64 {
        items.reduce(into: Int64(0)) { total, item in
            if selected.contains(item.id) {
                total += item.byteCount
            }
        }
    }

    /// 零选中时主按钮禁用（但不隐藏）。
    var isSubmitEnabled: Bool {
        !selected.isEmpty
    }

    /// 常驻行与主按钮两条文案共用的占位符取值：项数与字节量都取已选集合。
    var selectedTextReplacements: [String: String] {
        [
            "count": String(selected.count),
            "bytes": S0ByteCountText.string(forByteCount: selectedByteCount)
        ]
    }

    /// 副行文案的占位符取值：网格当前全部项的项数与字节量。
    var subtitleTextReplacements: [String: String] {
        [
            "count": String(items.count),
            "bytes": S0ByteCountText.string(forByteCount: totalByteCount)
        ]
    }

    /// 点格：切换其勾选态。不在网格里的标识不理会。
    mutating func toggle(_ id: String) {
        guard items.contains(where: { $0.id == id }) else {
            return
        }
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    /// 点「全选」：一项未选时全选当前网格全部项，否则全不选（第六节「再点为全不选」）。
    mutating func selectAllOrNone() {
        if selected.isEmpty {
            selected = Set(items.map { $0.id })
        } else {
            selected.removeAll()
        }
    }

    /// 移入成功：这些项从网格消失，其余项相对顺序不变；已选集合同步去掉它们。
    mutating func remove(ids: Set<String>) {
        items.removeAll { ids.contains($0.id) }
        selected.subtract(ids)
    }
}

/// IC-156 C：视频时长角标的文本。系统 `DateComponentsFormatter` 的位置式输出（分与秒、
/// 补零），不自拼分隔符、不进目录（裁定 五）。每次现造格式化器，照 `S0ByteCountText`。
enum S0CategoryPageDurationText {
    static func string(for duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: max(0, duration)) ?? String()
    }
}

/// IC-156 C：类别页底部短 toast 的呈现器。形状照 `S1FeedbackToastPresenter`：同一时刻只
/// 显示一条、新的一条替换旧的（旧的到期不清除新的）、计时经 `scheduler` 注入，测试不依赖
/// 真实时钟。类别页只有「已移入待删篮」一种提示，事件即已取好的文案本身。
final class S0FeedbackToastPresenter: ObservableObject {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    @Published private(set) var activeText: String?
    private(set) var presentedCount = 0
    private(set) var lastScheduledDurationSeconds: TimeInterval?
    private var generation = 0
    private let scheduler: Scheduler

    init(
        scheduler: @escaping Scheduler = { delay, action in
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay,
                execute: action
            )
        }
    ) {
        self.scheduler = scheduler
    }

    func present(text: String, durationMilliseconds: Double) {
        generation += 1
        let currentGeneration = generation
        presentedCount += 1
        activeText = text
        // 毫秒换秒走 `Measurement`，不写换算裸数。
        let seconds = Measurement(
            value: max(0, durationMilliseconds),
            unit: UnitDuration.milliseconds
        )
        .converted(to: .seconds)
        .value
        lastScheduledDurationSeconds = seconds
        scheduler(seconds) { [weak self] in
            self?.expire(generation: currentGeneration)
        }
    }

    private func expire(generation expiredGeneration: Int) {
        guard expiredGeneration == generation else {
            return
        }
        activeText = nil
    }
}

/// IC-156 C：类别页网格的一格——方形缩略图、右下单张体积标签、视频类左下播放符与时长、
/// 右上圆圈勾；选中格加白色外圈。缩略图视图自己先框后裁（陷阱 24），这里不再包一层；
/// 取图禁网络，本机取不到缩略图时留空。
struct S0CategoryGridCell: View {
    let item: S0CategoryAsset
    let side: CGFloat
    let isSelected: Bool

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ThumbnailView(
            assetIdentifier: item.id,
            sideLength: side,
            displayScale: displayScale,
            cornerRadius: S0CategoryPageMetrics.gridCellCornerRadius,
            showsPlaceholderGlyph: false
        )
        .overlay(alignment: .bottomTrailing) {
            sizeLabel
        }
        .overlay(alignment: .bottomLeading) {
            if item.isVideo {
                durationLabel
            }
        }
        .overlay(alignment: .topTrailing) {
            checkMark
        }
        .overlay {
            if isSelected {
                RoundedRectangle(
                    cornerRadius: S0CategoryPageMetrics.gridCellCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    Color.white,
                    lineWidth: S0CategoryPageMetrics.gridSelectedRingWidth
                )
            }
        }
    }

    private var sizeLabel: some View {
        Text(S0ByteCountText.string(forByteCount: item.byteCount))
            .font(
                .system(
                    size: S0CategoryPageMetrics.gridSizeLabelFontSize,
                    weight: .semibold
                )
            )
            .foregroundStyle(S0HomePalette.text)
            .padding(.horizontal, S0CategoryPageMetrics.gridSizeLabelPaddingHorizontal)
            .padding(.vertical, S0CategoryPageMetrics.gridSizeLabelPaddingVertical)
            .background(
                Color.black.opacity(S0CategoryPageMetrics.gridSizeLabelBackgroundOpacity),
                in: RoundedRectangle(
                    cornerRadius: S0CategoryPageMetrics.gridSizeLabelCornerRadius,
                    style: .continuous
                )
            )
            .padding(S0CategoryPageMetrics.gridBadgeInset)
    }

    private var durationLabel: some View {
        HStack(spacing: S0CategoryPageMetrics.gridDurationGlyphSpacing) {
            Image(systemName: S0CategoryPageSymbol.play)
            Text(S0CategoryPageDurationText.string(for: item.duration))
        }
        .font(
            .system(
                size: S0CategoryPageMetrics.gridDurationFontSize,
                weight: .semibold
            )
        )
        .foregroundStyle(S0HomePalette.text)
        .shadow(
            color: Color.black.opacity(S0CategoryPageMetrics.gridDurationShadowOpacity),
            radius: S0CategoryPageMetrics.gridDurationShadowRadius
        )
        .padding(S0CategoryPageMetrics.gridBadgeInset)
    }

    /// 圆圈勾。选中态为白底深色对勾；对勾字号登记表未给，取同格体积标签的登记字号
    /// （登记表缺口，已在 IC-156 自验报告登记）。
    private var checkMark: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.white)
                Image(systemName: S0CategoryPageSymbol.check)
                    .font(
                        .system(
                            size: S0CategoryPageMetrics.gridSizeLabelFontSize,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(S2AmbientMetrics.baseColor)
            } else {
                Circle()
                    .fill(
                        Color.black.opacity(
                            S0CategoryPageMetrics.gridCheckUnselectedFillOpacity
                        )
                    )
                Circle()
                    .strokeBorder(
                        Color.white.opacity(S0CategoryPageMetrics.gridCheckRingOpacity),
                        lineWidth: S0CategoryPageMetrics.gridCheckRingWidth
                    )
            }
        }
        .frame(
            width: S0CategoryPageMetrics.gridCheckSide,
            height: S0CategoryPageMetrics.gridCheckSide
        )
        .padding(S0CategoryPageMetrics.gridBadgeInset)
    }
}

/// IC-156 C：类别页（SPEC-S0 v2 第六节）。
///
/// 纯呈现加回调：不认识状态机、不碰会话层；进篮经 `onMoveToBasket`（成功才从网格删项、
/// 清空已选、出 toast），返回经 `onBack`。恒深色，与首页共用同一只氛围底视图（裁定 一）；
/// 顶排一律借 S1 chrome 的登记常量与玻璃 helper，页面其余取值只经 `S0CategoryPageMetrics`。
///
/// 结构：顶排、大标题与副行、常驻「已选」行固定；只有网格滚动，底部渐隐与主按钮压在网格
/// 上方，网格底部留出主按钮的高度与底距，滚到底时最后一行不被主按钮压住。
struct S0CategoryPageView: View {
    let category: S0CategorySnapshot
    private let onMoveToBasket: (Set<String>) -> Bool
    private let onBack: () -> Void
    /// IC-157 B：长按任一格进 S2。实参是网格当前顺序（全部项标识）与被长按那张的标识；
    /// 不改 `SEL`、不进篮。
    private let onLongPress: ([String], String) -> Void
    /// IC-160 B：勾选每次变化都回报给流程模型（裁定 二）。页面仍是已选集合的唯一写入者，
    /// 模型只存一份跨 S2 往返用的副本。
    private let onSelectionChange: (Set<String>) -> Void
    private let toastDurationMilliseconds: Double

    @State private var selection: S0CategoryPageSelection
    @StateObject private var toast = S0FeedbackToastPresenter()

    init(
        category: S0CategorySnapshot,
        items: [S0CategoryAsset],
        onMoveToBasket: @escaping (Set<String>) -> Bool,
        onBack: @escaping () -> Void,
        onLongPress: @escaping ([String], String) -> Void = { _, _ in },
        initialSelection: Set<String> = [],
        onSelectionChange: @escaping (Set<String>) -> Void = { _ in },
        toastDurationMilliseconds: Double
    ) {
        self.category = category
        self.onMoveToBasket = onMoveToBasket
        self.onBack = onBack
        self.onLongPress = onLongPress
        self.onSelectionChange = onSelectionChange
        self.toastDurationMilliseconds = toastDurationMilliseconds
        _selection = State(
            initialValue: S0CategoryPageSelection(
                items: items,
                preselected: initialSelection
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            S2AmbientBackdropView()
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                topRow
                titleBlock
                pinnedRow
                gridScroll
            }
            bottomBar
        }
        .onChange(of: selection.selected) { _, current in
            onSelectionChange(current)
        }
        // IC-160 B（裁定 三）：`.onChange` 不对初值触发——出现时先回报一次，模型即收敛为
        // 页面真正显示的那一份；否则已消失的标识会留在保留集里，日后它重新回到网格时会被
        // 自动勾上，与裁定 一的口径不符。
        .onAppear {
            onSelectionChange(selection.selected)
        }
    }

    // MARK: - 顶排（借 S1 chrome，零新数）

    private var topRow: some View {
        HStack(spacing: S1ChromeLayout.itemSpacing) {
            Button(action: onBack) {
                Image(systemName: S0CategoryPageSymbol.back)
                    .foregroundStyle(S0HomePalette.text)
                    .s1ChromeCircleGlass()
            }
            Spacer(minLength: 0)
            Button {
                selection.selectAllOrNone()
            } label: {
                Text(L10n.text("s0.categoryPage.selectAll"))
                    .font(.system(size: S1ChromeTypography.titleFontSize))
                    .foregroundStyle(S0HomePalette.text)
                    .padding(.horizontal, S1ChromeLayout.itemSpacing)
                    .frame(height: S1ChromeLayout.rowHeight)
                    .s1ChromeGlassBackground(in: Capsule(), interactive: true)
            }
        }
        .frame(height: S1ChromeLayout.rowHeight)
        .padding(.horizontal, S1ChromeLayout.horizontalMargin)
        .padding(.top, S1ChromeLayout.topRowTopInset)
    }

    // MARK: - 大标题与副行

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: S0CategoryPageMetrics.subtitleTopSpacing) {
            HStack(spacing: S0CategoryPageMetrics.titleDotSpacing) {
                Circle()
                    .fill(S0HomeMetrics.categoryColor(for: category.id))
                    .frame(
                        width: S0CategoryPageMetrics.titleDotSide,
                        height: S0CategoryPageMetrics.titleDotSide
                    )
                Text(S0CategoryText.displayName(for: category.id))
                    .font(
                        .system(
                            size: S0CategoryPageMetrics.titleFontSize,
                            weight: .bold
                        )
                    )
                    .tracking(S0CategoryPageMetrics.titleLetterSpacing)
                    .foregroundStyle(S0HomePalette.text)
                    .lineLimit(1)
            }
            .frame(height: S0CategoryPageMetrics.titleLineHeight)
            Text(
                L10n.text("s0.categoryPage.subtitle", replacing: selection.subtitleTextReplacements)
            )
            .font(.system(size: S0CategoryPageMetrics.subtitleFontSize))
            .foregroundStyle(
                S0HomePalette.dimmedText(opacity: S0CategoryPageMetrics.subtitleOpacity)
            )
        }
        .padding(.horizontal, S0CategoryPageMetrics.textHorizontalInset)
        .padding(.top, S0CategoryPageMetrics.titleTopSpacing)
    }

    // MARK: - 常驻「已选」行（右侧长按提示，与左文同一字号与明度：IC-157）

    private var pinnedRow: some View {
        HStack {
            Text(
                L10n.text("s0.categoryPage.selected", replacing: selection.selectedTextReplacements)
            )
            .font(.system(size: S0CategoryPageMetrics.pinnedRowFontSize))
            .foregroundStyle(
                S0HomePalette.dimmedText(opacity: S0CategoryPageMetrics.pinnedRowOpacity)
            )
            Spacer(minLength: 0)
            Text(L10n.text("s0.categoryPage.longPressHint"))
                .font(.system(size: S0CategoryPageMetrics.pinnedRowFontSize))
                .foregroundStyle(
                    S0HomePalette.dimmedText(opacity: S0CategoryPageMetrics.pinnedRowOpacity)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, S0CategoryPageMetrics.textHorizontalInset)
        .padding(.top, S0CategoryPageMetrics.pinnedRowTopSpacing)
    }

    // MARK: - 网格

    private var gridScroll: some View {
        GeometryReader { geometry in
            ScrollView {
                gridContent(side: cellSide(forWidth: geometry.size.width))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func gridContent(side: CGFloat) -> some View {
        LazyVGrid(
            columns: gridColumns(side: side),
            spacing: S0CategoryPageMetrics.gridItemSpacing
        ) {
            ForEach(selection.items) { item in
                gridCell(item, side: side)
            }
        }
        .padding(.horizontal, S0CategoryPageMetrics.pageHorizontalInset)
        .padding(.top, S0CategoryPageMetrics.gridTopSpacing)
        .padding(
            .bottom,
            S0CategoryPageMetrics.ctaBottomInset + S0CategoryPageMetrics.ctaHeight
        )
    }

    private func gridCell(_ item: S0CategoryAsset, side: CGFloat) -> some View {
        Button {
            selection.toggle(item.id)
        } label: {
            S0CategoryGridCell(
                item: item,
                side: side,
                isSelected: selection.selected.contains(item.id)
            )
        }
        .buttonStyle(.plain)
        // IC-157 B：长按与按钮并存（按钮语义与点按反馈保留），时长取系统默认。
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                onLongPress(selection.items.map(\.id), item.id)
            }
        )
    }

    /// 格边长 = (宽 − 两侧页面边距 − 列间距之和) ÷ 列数。
    private func cellSide(forWidth width: CGFloat) -> CGFloat {
        let columnCount = CGFloat(S0CategoryPageMetrics.gridColumns)
        let gapTotal = CGFloat(S0CategoryPageMetrics.gridColumns - 1)
            * S0CategoryPageMetrics.gridItemSpacing
        let available = width - S0CategoryPageMetrics.pageHorizontalInset * 2 - gapTotal
        return max(0, available / columnCount)
    }

    private func gridColumns(side: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(side),
                spacing: S0CategoryPageMetrics.gridItemSpacing
            ),
            count: S0CategoryPageMetrics.gridColumns
        )
    }

    // MARK: - 底部渐隐、toast 与主按钮

    private var bottomBar: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    S2AmbientMetrics.baseColor.opacity(0),
                    S2AmbientMetrics.baseColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: S0CategoryPageMetrics.fadeHeight)
            .allowsHitTesting(false)
            VStack(spacing: S2OverlayLayout.minimumSpacing) {
                toastView
                submitButton
            }
            .padding(.horizontal, S0CategoryPageMetrics.pageHorizontalInset)
            .padding(.bottom, S0CategoryPageMetrics.ctaBottomInset)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// toast 的字号与内距照 S1 叠层；底不用系统材质，经 S1 玻璃 helper（裁定 一：固定色
    /// 方案不上材质）；位置在主按钮正上方，不压住主按钮。
    @ViewBuilder
    private var toastView: some View {
        if let text = toast.activeText {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(S0HomePalette.text)
                .padding(.horizontal, S2OverlayLayout.minimumSpacing * 2)
                .padding(.vertical, S2OverlayLayout.minimumSpacing)
                .s1ChromeGlassBackground(in: Capsule())
                .allowsHitTesting(false)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text(
                L10n.text("s0.categoryPage.submit", replacing: selection.selectedTextReplacements)
            )
            .font(.system(size: S0CategoryPageMetrics.ctaFontSize, weight: .bold))
            .foregroundStyle(S2AmbientMetrics.baseColor)
            .frame(maxWidth: .infinity)
            .frame(height: S0CategoryPageMetrics.ctaHeight)
            .background(
                Color.white,
                in: RoundedRectangle(
                    cornerRadius: S0CategoryPageMetrics.ctaCornerRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(S0CategoryPageMetrics.ctaShadowOpacity),
                radius: S0CategoryPageMetrics.ctaShadowRadius,
                y: S0CategoryPageMetrics.ctaShadowYOffset
            )
        }
        .buttonStyle(.plain)
        .disabled(!selection.isSubmitEnabled)
        .opacity(selection.isSubmitEnabled ? 1 : S0CategoryPageMetrics.ctaDisabledOpacity)
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
}
