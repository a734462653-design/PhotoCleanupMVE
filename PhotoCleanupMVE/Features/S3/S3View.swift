import SwiftUI

// MARK: - 展示口径（IC-133；IC-134 重写视图时保留这些类型与断言）

/// IC-133 A（SPEC-S1 v8 决策 31）：S3 分组的展示口径。
///
/// 输入协调器的 `s3Groups` 快照与状态机当前仍在 `D` 中的资产，输出**只含仍有
/// 资产的组**的有序列表；顺序保持 `s3Groups` 原序（不重排、不按名字排），每组
/// 带过滤后的有序资产与计数。某组最后一张被移除即从列表消失，其余组位置不变；
/// 全部为空时输出空列表（此时状态机已是 `S3-4`，视图走空态分支）。
/// `s3Groups` 本身不改，过滤在展示层每次重算。
struct S3GroupPresentation: Equatable {
    struct Group: Equatable {
        let sourceRangeID: SessionStore.RangeID
        let name: String
        let orderedAssets: [AssetDescriptor]

        var assetCount: Int {
            orderedAssets.count
        }
    }

    let groups: [Group]

    /// 非空组数——信息条副行的「来自 M 个范围」取此值，不取 `s3Groups.count`。
    var nonEmptyRangeCount: Int {
        groups.count
    }

    /// 各组输出计数之和；应恒等于状态机 `assetCount`（v8 第六节第 5 部分分组等式）。
    var assetCount: Int {
        groups.reduce(0) { $0 + $1.assetCount }
    }

    static func make(
        groups: [SessionStore.S3Submission.Group],
        currentAssets: [AssetDescriptor]
    ) -> S3GroupPresentation {
        let descriptorByID = Dictionary(
            currentAssets.map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let nonEmptyGroups = groups.compactMap { group -> Group? in
            let orderedAssets = group.orderedAssetIDs.compactMap { descriptorByID[$0] }
            guard !orderedAssets.isEmpty else {
                return nil
            }
            return Group(
                sourceRangeID: group.sourceRangeID,
                name: group.name,
                orderedAssets: orderedAssets
            )
        }
        return S3GroupPresentation(groups: nonEmptyGroups)
    }
}

/// IC-133 B（决策单 D1）：信息条副行口径——`count` = 状态机 `assetCount`，
/// `ranges` = `S3GroupPresentation` 输出的**非空组数**（不是 `s3Groups.count`）。
/// 视图只取这里产出的字符串。
enum S3HeaderSubtitle {
    static func text(assetCount: Int, rangeCount: Int) -> String {
        L10n.text(
            "s3.chrome.subtitle_format",
            replacing: [
                "count": String(assetCount),
                "ranges": String(rangeCount)
            ]
        )
    }
}

/// IC-133 C（决策单 D5）：「全部取消」两步动作模型——`request()` 置待确认态，
/// `confirm(cancelAll:)` 执行清空并回到空闲，`dismiss()` 直接回到空闲。空集或
/// 快照已冻结时 `request()` 无效（既有按钮禁用口径不变）。视图只绑定它的状态，
/// 系统 `confirmationDialog` 由 `isAwaitingConfirmation` 驱动。
struct S3CancelAllAction: Equatable {
    enum Phase: Equatable {
        case idle
        case awaitingConfirmation
    }

    private(set) var phase: Phase = .idle

    var isAwaitingConfirmation: Bool {
        phase == .awaitingConfirmation
    }

    static func isAvailable(assetCount: Int, isFrozen: Bool) -> Bool {
        assetCount > 0 && !isFrozen
    }

    /// 进入待确认态；不可用（空集／已冻结）时不进入并返回 false。
    @discardableResult
    mutating func request(assetCount: Int, isFrozen: Bool) -> Bool {
        guard Self.isAvailable(assetCount: assetCount, isFrozen: isFrozen) else {
            return false
        }
        phase = .awaitingConfirmation
        return true
    }

    /// 用户在对话框里放弃：回到空闲，不执行任何清空。
    mutating func dismiss() {
        phase = .idle
    }

    /// 用户确认：仅在待确认态执行一次 `cancelAll`，随后回到空闲；空闲时调用为无操作。
    @discardableResult
    mutating func confirm(cancelAll: () -> Void) -> Bool {
        guard phase == .awaitingConfirmation else {
            return false
        }
        phase = .idle
        cancelAll()
        return true
    }
}

// MARK: - IC-134 A：S3 视觉登记制常量
//
// 设计语言的唯一来源是 SPEC-S2 v18 第十一节第 2 部分。chrome 的一切取值**不新造**，
// 一律取自 S1 视觉层已登记的常量容器；此处只做「引用登记」，让断言能核对来源
// （断言 1 比对的是 S1 常量本身，不是 44、16 这类字面量）。
// 登记制：这些量不进 `S2CalibrationConfiguration`、不上标定面板。

/// 顶排 chrome 的取值——逐项引用 S1，S3 不自造语汇。
enum S3ChromeMetrics {
    static let rowHeight = S1ChromeLayout.rowHeight
    static let topRowTopInset = S1ChromeLayout.topRowTopInset
    static let horizontalMargin = S1ChromeLayout.horizontalMargin
    static let itemSpacing = S1ChromeLayout.itemSpacing
    static let titleFontSize = S1ChromeTypography.titleFontSize
    static let subtitleFontSize = S1ChromeTypography.subtitleFontSize
    static let circleIconPointSize = S1ChromeTypography.circleIconPointSize
}

/// 页面版式（④卡取值表逐条转录；「距安全区」的量随机型自适应）。
enum S3PageLayout {
    /// 「最近删除」提示句上缘距安全区顶。
    static let noticeTopInset: CGFloat = 59
    /// 提示句左右边距。
    static let noticeHorizontalMargin: CGFloat = 32
    /// 列表上缘距安全区顶。
    static let listTopInset: CGFloat = 87
    /// 列表左右边距。
    static let listHorizontalMargin: CGFloat = 16
    /// 分组卡之间的间距。
    static let cardSpacing: CGFloat = 16
    /// 末卡与操作条之间的间隙（④取定：卡只说「末卡不被遮」，未给具体值，
    /// 取与 chrome 件间距同值 8）。
    static let listToActionBarSpacing: CGFloat = 8

    /// 列表底部内边距 = 操作条高 + 操作条下缘距安全区底 + 末卡间隙。
    ///
    /// ④取定：卡内写「操作条高 + 8 + 安全区底」；安全区底由滚动容器自身的安全区
    /// 内边距承担，此处不重复计入，否则末卡下方会多出一个安全区高度的空白。
    static var listBottomClearance: CGFloat {
        S3ActionBarMetrics.height
            + S2OverlayLayout.bottomRowBottomInset
            + listToActionBarSpacing
    }
}

/// 底部操作条（④卡取值表）。
enum S3ActionBarMetrics {
    static let height: CGFloat = 56
    static let cornerRadius: CGFloat = 28
    static let horizontalMargin: CGFloat = 16
    static let leadingPadding: CGFloat = 16
    static let trailingPadding: CGFloat = 6
    static let itemSpacing: CGFloat = 10
    static let cancelFontSize: CGFloat = 15
    static let volumePrimaryFontSize: CGFloat = 13
    static let volumeSecondaryFontSize: CGFloat = 11
    static let scanningIndicatorSize: CGFloat = 16
    static let submitHeight: CGFloat = 44
    static let submitCornerRadius: CGFloat = 22
    static let submitFontSize: CGFloat = 15
    static let submitHorizontalPadding: CGFloat = 20
    /// 禁用态降幅——与 S1 加载态同值（v18 §11.2 的 40%）。
    static let disabledOpacity: Double = 0.4
}

/// 分组卡与三列网格（④卡取值表）。
enum S3GroupCardMetrics {
    static let cornerRadius: CGFloat = 14
    static let headerTopPadding: CGFloat = 12
    static let headerHorizontalPadding: CGFloat = 14
    static let headerBottomPadding: CGFloat = 8
    static let headerNameFontSize: CGFloat = 15
    static let headerCountFontSize: CGFloat = 13
    static let headerSpacing: CGFloat = 8
}

/// 三列等宽网格。格宽由卡宽反解，供封面按「格宽 × 倍率」请求像素。
enum S3GridMetrics {
    static let columnCount = 3
    static let interitemSpacing: CGFloat = 3
    static let contentPadding: CGFloat = 3
    static let cellCornerRadius: CGFloat = 6

    static func cellWidth(cardWidth: CGFloat) -> CGFloat {
        let spacing = interitemSpacing * CGFloat(columnCount - 1)
        let padding = contentPadding * 2
        return max(0, (cardWidth - spacing - padding) / CGFloat(columnCount))
    }
}

/// 格子三件角标（④卡取值表）。
enum S3CellBadgeMetrics {
    static let removeDiameter: CGFloat = 22
    static let removeTopInset: CGFloat = 5
    static let removeTrailingInset: CGFloat = 5
    static let removeGlyphWidth: CGFloat = 12
    static let removeGlyphThickness: CGFloat = 3
    /// 命中区扩到 44×44（引用 S2 已登记的最小触控带）。
    static let removeHitTarget = S2OverlayLayout.minimumTouchTarget
    static let favoritePointSize: CGFloat = 14
    static let favoriteLeadingInset: CGFloat = 6
    static let favoriteBottomInset: CGFloat = 6
    static let volumeHeight: CGFloat = 18
    static let volumeCornerRadius: CGFloat = 9
    static let volumeHorizontalPadding: CGFloat = 6
    static let volumeFontSize: CGFloat = 11
    static let volumeTrailingInset: CGFloat = 5
    static let volumeBottomInset: CGFloat = 5
    static let detailChevronPointSize: CGFloat = 9
    /// 角标底色不透明度。
    static let scrimOpacity: Double = 0.55
    static var scrim: Color {
        Color.black.opacity(scrimOpacity)
    }
}

/// 空态（S3-4）——尺寸引用 S1 已登记的四态版式常量。
enum S3EmptyStateMetrics {
    static let iconPointSize = S1StatePlaceholderStyle.iconPointSize
    static let titleFontSize = S1StatePlaceholderStyle.titleFontSize
    static let contentSpacing = S1StatePlaceholderStyle.contentSpacing
}

// MARK: - IC-134 A：顶排 chrome 与三态元素清单（测试钉住）

/// 顶排 chrome 的展示口径。副行**只**取 IC-133 的 `S3HeaderSubtitle`，不另起格式串。
struct S3ChromeBarModel: Equatable {
    let title: String
    let subtitle: String

    static func make(assetCount: Int, rangeCount: Int) -> S3ChromeBarModel {
        S3ChromeBarModel(
            title: L10n.text("s3.chrome.title"),
            subtitle: S3HeaderSubtitle.text(
                assetCount: assetCount,
                rangeCount: rangeCount
            )
        )
    }
}

/// 三态版式的元素清单。
enum S3StateElement: Equatable {
    case chrome
    case recentlyDeletedNotice
    case groupCards
    case actionBar
    case emptyIcon
    case emptyTitle
}

/// IC-134 B：单个格子的角标口径（测试钉住）。
///
/// 体积标签文本只有四种来源：已知走 `DecimalVolumeFormatter`；不可用「—」；
/// 未开始／进行中「…」。拆分项 ≥ 2 时右侧才有展开箭头。
struct S3CellBadgeModel: Equatable {
    let showsFavorite: Bool
    let volumeText: String
    let showsDetailChevron: Bool

    static func make(
        asset: AssetDescriptor,
        conclusion: AssetScanConclusion?,
        breakdownItemCount: Int
    ) -> S3CellBadgeModel {
        let volumeText: String
        switch conclusion {
        case let .knownBytes(bytes):
            volumeText = DecimalVolumeFormatter.string(forByteCount: bytes)
        case .unavailable:
            volumeText = L10n.text("s3.cell.volume_unavailable")
        case .notStarted, .inProgress, .none:
            volumeText = L10n.text("s3.cell.volume_pending")
        }
        return S3CellBadgeModel(
            showsFavorite: asset.isFavorite,
            volumeText: volumeText,
            showsDetailChevron: breakdownItemCount >= 2
        )
    }
}

/// IC-134 B：⊖ 移除的动作口径（测试钉住）。冻结快照后不响应。
enum S3RemoveButtonAction {
    static func perform(isFrozen: Bool, remove: () -> Void) {
        guard !isFrozen else {
            return
        }
        remove()
    }
}

enum S3StatePresentation {
    /// S3-4 空集：顶排 + 中央图标 + 主句，**无操作条、无提示句**。
    /// S3-1／S3-2：顶排 + 提示句 + 分组卡 + 操作条——两者差别在格子与操作条的
    /// **内容**（未完成格「…」、转圈与删除禁用），不在元素清单。
    static func elements(for state: S3State) -> [S3StateElement] {
        switch state {
        case .scanning, .ready:
            return [.chrome, .recentlyDeletedNotice, .groupCards, .actionBar]
        case .empty:
            return [.chrome, .emptyIcon, .emptyTitle]
        }
    }

    static func showsActionBar(for state: S3State) -> Bool {
        elements(for: state).contains(.actionBar)
    }

    static func showsRecentlyDeletedNotice(for state: S3State) -> Bool {
        elements(for: state).contains(.recentlyDeletedNotice)
    }
}

// MARK: - S3View

struct S3View: View {
    @ObservedObject var coordinator: CleanupCoordinator
    @Environment(\.displayScale) private var displayScale
    @State private var cancelAllAction = S3CancelAllAction()

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            if let machine = coordinator.s3Machine {
                content(machine)
            } else {
                ProgressView()
                    .id("s3-loading")
            }
        }
    }

    @ViewBuilder
    private func content(_ machine: S3StateMachine) -> some View {
        let presentation = S3GroupPresentation.make(
            groups: coordinator.s3Groups,
            currentAssets: machine.assets
        )
        ZStack(alignment: .top) {
            if machine.state == .empty {
                emptyState
            } else {
                groupList(presentation, machine: machine)
                recentlyDeletedNotice
            }
            chromeBar(machine, presentation: presentation)
        }
    }

    // MARK: - IC-134 A：顶排 chrome（左圆钮 + 中胶囊，无右件）

    private func chromeBar(
        _ machine: S3StateMachine,
        presentation: S3GroupPresentation
    ) -> some View {
        let model = S3ChromeBarModel.make(
            assetCount: machine.assetCount,
            rangeCount: presentation.nonEmptyRangeCount
        )
        return HStack(spacing: S3ChromeMetrics.itemSpacing) {
            backButton
            capsule(model)
        }
        .padding(.top, S3ChromeMetrics.topRowTopInset)
        .padding(.horizontal, S3ChromeMetrics.horizontalMargin)
    }

    private var backButton: some View {
        Button {
            coordinator.leaveConfirmation()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundStyle(S1ChromeForeground.primary)
                .s1ChromeCircleGlass()
        }
        .accessibilityLabel(L10n.text("s3.action.back"))
    }

    /// 跑道胶囊占满剩余宽，右缘对齐右边距。
    private func capsule(_ model: S3ChromeBarModel) -> some View {
        VStack(spacing: 0) {
            Text(model.title)
                .font(
                    .system(
                        size: S3ChromeMetrics.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
            Text(model.subtitle)
                .font(.system(size: S3ChromeMetrics.subtitleFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .frame(height: S3ChromeMetrics.rowHeight)
        .s1ChromeGlassBackground(in: Capsule())
    }

    // MARK: - IC-134 A：提示句

    private var recentlyDeletedNotice: some View {
        Text(L10n.text("s3.confirmation.recently_deleted_notice"))
            .font(.system(size: S3ChromeMetrics.subtitleFontSize))
            .foregroundStyle(S1ChromeForeground.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, S3PageLayout.noticeHorizontalMargin)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, S3PageLayout.noticeTopInset)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - IC-134 A：列表容器（分组卡由子项 B 填充）

    private func groupList(
        _ presentation: S3GroupPresentation,
        machine: S3StateMachine
    ) -> some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width
                - S3PageLayout.listHorizontalMargin * 2
            ScrollView {
                LazyVStack(spacing: S3PageLayout.cardSpacing) {
                    ForEach(presentation.groups, id: \.sourceRangeID) { group in
                        groupCard(
                            group,
                            machine: machine,
                            cardWidth: cardWidth
                        )
                    }
                }
                .padding(.horizontal, S3PageLayout.listHorizontalMargin)
                .padding(.top, S3PageLayout.listTopInset)
                .padding(.bottom, S3PageLayout.listBottomClearance)
            }
        }
    }

    // MARK: - IC-134 B：分组卡与三列网格

    private func groupCard(
        _ group: S3GroupPresentation.Group,
        machine: S3StateMachine,
        cardWidth: CGFloat
    ) -> some View {
        let cellWidth = S3GridMetrics.cellWidth(cardWidth: cardWidth)
        return VStack(alignment: .leading, spacing: 0) {
            groupHeader(group)
            grid(group, machine: machine, cellWidth: cellWidth)
        }
        .background(
            RoundedRectangle(
                cornerRadius: S3GroupCardMetrics.cornerRadius,
                style: .continuous
            )
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func groupHeader(_ group: S3GroupPresentation.Group) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: S3GroupCardMetrics.headerSpacing) {
            Text(group.name)
                .font(
                    .system(
                        size: S3GroupCardMetrics.headerNameFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(
                L10n.text(
                    "s3.group.count_format",
                    replacing: ["count": String(group.assetCount)]
                )
            )
            .font(
                .system(
                    size: S3GroupCardMetrics.headerCountFontSize,
                    design: .monospaced
                )
            )
            .foregroundStyle(S1ChromeForeground.secondary)
            Spacer(minLength: 0)
        }
        .padding(.top, S3GroupCardMetrics.headerTopPadding)
        .padding(.horizontal, S3GroupCardMetrics.headerHorizontalPadding)
        .padding(.bottom, S3GroupCardMetrics.headerBottomPadding)
    }

    private func grid(
        _ group: S3GroupPresentation.Group,
        machine: S3StateMachine,
        cellWidth: CGFloat
    ) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .flexible(),
                    spacing: S3GridMetrics.interitemSpacing
                ),
                count: S3GridMetrics.columnCount
            ),
            spacing: S3GridMetrics.interitemSpacing
        ) {
            ForEach(group.orderedAssets, id: \.identifier) { asset in
                cell(asset, machine: machine, cellWidth: cellWidth)
            }
        }
        .padding(.horizontal, S3GridMetrics.contentPadding)
        .padding(.bottom, S3GridMetrics.contentPadding)
    }

    private func cell(
        _ asset: AssetDescriptor,
        machine: S3StateMachine,
        cellWidth: CGFloat
    ) -> some View {
        let model = S3CellBadgeModel.make(
            asset: asset,
            conclusion: machine.cachedConclusion(for: asset.identifier),
            // 子项 C 接入扫描侧通道后改为真实拆分项数；此处先按「无拆分」渲染。
            breakdownItemCount: 0
        )
        return ThumbnailView(
            assetIdentifier: asset.identifier,
            sideLength: cellWidth,
            displayScale: displayScale,
            cornerRadius: S3GridMetrics.cellCornerRadius
        )
        .overlay(alignment: .topTrailing) {
            removeBadge(asset, machine: machine, model: model)
        }
        .overlay(alignment: .bottomLeading) {
            if model.showsFavorite {
                favoriteBadge
            }
        }
        .overlay(alignment: .bottomTrailing) {
            volumeBadge(model)
        }
    }

    private func removeBadge(
        _ asset: AssetDescriptor,
        machine: S3StateMachine,
        model: S3CellBadgeModel
    ) -> some View {
        Button {
            S3RemoveButtonAction.perform(
                isFrozen: machine.frozenSnapshot != nil
            ) {
                coordinator.removeAsset(asset.identifier)
            }
        } label: {
            Circle()
                .fill(S3CellBadgeMetrics.scrim)
                .frame(
                    width: S3CellBadgeMetrics.removeDiameter,
                    height: S3CellBadgeMetrics.removeDiameter
                )
                .overlay {
                    Capsule()
                        .fill(Color.white)
                        .frame(
                            width: S3CellBadgeMetrics.removeGlyphWidth,
                            height: S3CellBadgeMetrics.removeGlyphThickness
                        )
                }
                .frame(
                    width: S3CellBadgeMetrics.removeHitTarget,
                    height: S3CellBadgeMetrics.removeHitTarget,
                    alignment: .topTrailing
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, S3CellBadgeMetrics.removeTopInset)
        .padding(.trailing, S3CellBadgeMetrics.removeTrailingInset)
        .accessibilityLabel(
            L10n.text(
                "s3.cell.remove.accessibility",
                replacing: ["volume": model.volumeText]
            )
        )
    }

    private var favoriteBadge: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: S3CellBadgeMetrics.favoritePointSize))
            .foregroundStyle(Color.white)
            .padding(.leading, S3CellBadgeMetrics.favoriteLeadingInset)
            .padding(.bottom, S3CellBadgeMetrics.favoriteBottomInset)
            .accessibilityLabel(L10n.text("s3.cell.favorite.accessibility"))
    }

    private func volumeBadge(_ model: S3CellBadgeModel) -> some View {
        HStack(spacing: 2) {
            Text(model.volumeText)
                .font(
                    .system(
                        size: S3CellBadgeMetrics.volumeFontSize,
                        weight: .semibold,
                        design: .monospaced
                    )
                )
            if model.showsDetailChevron {
                Image(systemName: "chevron.down")
                    .font(
                        .system(size: S3CellBadgeMetrics.detailChevronPointSize)
                    )
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, S3CellBadgeMetrics.volumeHorizontalPadding)
        .frame(height: S3CellBadgeMetrics.volumeHeight)
        .background(
            Capsule().fill(S3CellBadgeMetrics.scrim)
        )
        .padding(.trailing, S3CellBadgeMetrics.volumeTrailingInset)
        .padding(.bottom, S3CellBadgeMetrics.volumeBottomInset)
    }

    // MARK: - IC-134 A：S3-4 空态

    private var emptyState: some View {
        VStack(spacing: S3EmptyStateMetrics.contentSpacing) {
            Image(systemName: "trash")
                .font(.system(size: S3EmptyStateMetrics.iconPointSize))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
            Text(L10n.text("s3.state.empty"))
                .font(.system(size: S3EmptyStateMetrics.titleFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
