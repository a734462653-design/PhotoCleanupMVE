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
    /// 箭头朝向：展开为 ▴、收起为 ▾。
    let isDetailExpanded: Bool

    static func make(
        asset: AssetDescriptor,
        conclusion: AssetScanConclusion?,
        breakdownItemCount: Int,
        isDetailExpanded: Bool = false
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
            showsDetailChevron: S3DetailExpansion.isExpandable(
                breakdownItemCount: breakdownItemCount
            ),
            isDetailExpanded: isDetailExpanded
        )
    }
}

/// IC-134 C：体积明细行的取值（④卡取值表）。
enum S3VolumeDetailMetrics {
    static let cornerRadius: CGFloat = 8
    static let verticalPadding: CGFloat = 8
    static let horizontalPadding: CGFloat = 10
    static let fontSize: CGFloat = 13
    /// 键与值、以及各项之间的间距（④取定：卡未给，取与组头同值 8 的一半，
    /// 使「键 值 · 键 值」读起来成组）。
    static let pairSpacing: CGFloat = 4
    static let itemSpacing: CGFloat = 8
}

/// IC-134 C：明细行的文案与数值来源（测试钉住）。种类名经 String Catalog，
/// 数值经 `DecimalVolumeFormatter`；源码里没有中文字面量。
enum S3VolumeDetailText {
    static func kindLabel(_ kind: AssetResourceKind) -> String {
        switch kind {
        case .photo:
            return L10n.text("s3.detail.kind.photo")
        case .video:
            return L10n.text("s3.detail.kind.video")
        case .liveVideo:
            return L10n.text("s3.detail.kind.live_video")
        case .other:
            return L10n.text("s3.detail.kind.other")
        }
    }

    static func value(_ bytes: Int64) -> String {
        DecimalVolumeFormatter.string(forByteCount: bytes)
    }
}

/// IC-134 C：明细展开口径（测试钉住）。
///
/// 同一时刻至多一行展开；点另一张切换、点已展开的收起；拆分项 < 2 不可展开
/// （缓存复用／未扫描／单资源都落在这一支）。
struct S3DetailExpansion: Equatable {
    private(set) var expandedAssetID: String?

    static func isExpandable(breakdownItemCount: Int) -> Bool {
        breakdownItemCount >= 2
    }

    func isExpanded(_ assetID: String) -> Bool {
        expandedAssetID == assetID
    }

    @discardableResult
    mutating func toggle(
        assetID: String,
        breakdownItemCount: Int
    ) -> Bool {
        guard Self.isExpandable(breakdownItemCount: breakdownItemCount) else {
            return false
        }
        expandedAssetID = expandedAssetID == assetID ? nil : assetID
        return true
    }
}

/// IC-134 C：三列网格的分行口径——明细行要插在「该格所在行」下方，故按 3 分块。
enum S3GridRows {
    static func rows(_ assets: [AssetDescriptor]) -> [[AssetDescriptor]] {
        stride(from: 0, to: assets.count, by: S3GridMetrics.columnCount).map {
            Array(assets[$0..<min($0 + S3GridMetrics.columnCount, assets.count)])
        }
    }

    static func rowIndex(
        ofAssetID assetID: String,
        in rows: [[AssetDescriptor]]
    ) -> Int? {
        rows.firstIndex { row in
            row.contains { $0.identifier == assetID }
        }
    }
}

/// IC-134 D：底部操作条的展示口径（测试钉住）。
///
/// 体积区（L2）两行右对齐：扫描中为「转圈 + 正在计算…」加「已知 X」副行；
/// 就绪且无不可用项为精确值、无副行；有不可用项为下界值加「另有 N 项」副行。
struct S3ActionBarModel: Equatable {
    enum Volume: Equatable {
        case scanning(primary: String, knownSoFar: String)
        case exact(String)
        case lowerBound(primary: String, unavailableNote: String)

        var isScanning: Bool {
            if case .scanning = self {
                return true
            }
            return false
        }
    }

    let volume: Volume
    let cancelAllEnabled: Bool
    let submitTitle: String
    let submitEnabled: Bool

    static func make(machine: S3StateMachine) -> S3ActionBarModel {
        let known = DecimalVolumeFormatter.string(
            forByteCount: machine.knownTotalBytes
        )
        let volume: Volume
        switch machine.state {
        case .scanning:
            volume = .scanning(
                primary: L10n.text("s3.bar.scanning"),
                knownSoFar: L10n.text(
                    "s3.bar.known_so_far",
                    replacing: ["known": known]
                )
            )
        case .ready where machine.unavailableCount == 0:
            volume = .exact(
                L10n.text("s3.bar.volume_exact", replacing: ["known": known])
            )
        case .ready, .empty:
            volume = .lowerBound(
                primary: L10n.text(
                    "s3.bar.volume_lower_bound",
                    replacing: ["known": known]
                ),
                unavailableNote: L10n.text(
                    "s3.bar.unavailable_count",
                    replacing: ["count": String(machine.unavailableCount)]
                )
            )
        }
        return S3ActionBarModel(
            volume: volume,
            cancelAllEnabled: S3CancelAllAction.isAvailable(
                assetCount: machine.assetCount,
                isFrozen: machine.frozenSnapshot != nil
            ),
            submitTitle: L10n.text(
                "s3.action.delete_count",
                replacing: ["count": String(machine.assetCount)]
            ),
            submitEnabled: machine.canSubmit
        )
    }
}

/// IC-134 D：删除按钮的动作口径（测试钉住）。禁用时不调下游。
enum S3SubmitButtonAction {
    static func perform(isEnabled: Bool, submit: () -> Void) {
        guard isEnabled else {
            return
        }
        submit()
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
    @State private var detailExpansion = S3DetailExpansion()

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
            if S3StatePresentation.showsActionBar(for: machine.state) {
                actionBar(machine)
            }
        }
        .confirmationDialog(
            L10n.text(
                "s3.cancel_all.confirm.title",
                replacing: ["count": String(machine.assetCount)]
            ),
            isPresented: cancelAllDialogBinding,
            titleVisibility: .visible
        ) {
            Button(
                L10n.text("s3.cancel_all.confirm.action"),
                role: .destructive
            ) {
                cancelAllAction.confirm {
                    coordinator.cancelAllAssets()
                }
            }
        }
    }

    private var cancelAllDialogBinding: Binding<Bool> {
        Binding(
            get: { cancelAllAction.isAwaitingConfirmation },
            set: { isPresented in
                if !isPresented {
                    cancelAllAction.dismiss()
                }
            }
        )
    }

    // MARK: - IC-134 D：底部操作条

    private func actionBar(_ machine: S3StateMachine) -> some View {
        let model = S3ActionBarModel.make(machine: machine)
        return HStack(spacing: S3ActionBarMetrics.itemSpacing) {
            cancelAllButton(machine, model: model)
            Spacer(minLength: 0)
            volumeSummary(model)
            submitButton(model)
        }
        .padding(.leading, S3ActionBarMetrics.leadingPadding)
        .padding(.trailing, S3ActionBarMetrics.trailingPadding)
        .frame(height: S3ActionBarMetrics.height)
        .s1ChromeGlassBackground(
            in: RoundedRectangle(
                cornerRadius: S3ActionBarMetrics.cornerRadius,
                style: .continuous
            )
        )
        .padding(.horizontal, S3ActionBarMetrics.horizontalMargin)
        .padding(.bottom, S2OverlayLayout.bottomRowBottomInset)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func cancelAllButton(
        _ machine: S3StateMachine,
        model: S3ActionBarModel
    ) -> some View {
        Button {
            cancelAllAction.request(
                assetCount: machine.assetCount,
                isFrozen: machine.frozenSnapshot != nil
            )
        } label: {
            Text(L10n.text("s3.action.cancel_all"))
                .font(.system(size: S3ActionBarMetrics.cancelFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!model.cancelAllEnabled)
    }

    private func volumeSummary(_ model: S3ActionBarModel) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            switch model.volume {
            case let .scanning(primary, knownSoFar):
                HStack(spacing: S3VolumeDetailMetrics.pairSpacing) {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(
                            width: S3ActionBarMetrics.scanningIndicatorSize,
                            height: S3ActionBarMetrics.scanningIndicatorSize
                        )
                        .id("s3-bar-scanning")
                    Text(primary)
                }
                .font(
                    .system(
                        size: S3ActionBarMetrics.volumePrimaryFontSize,
                        design: .monospaced
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
                Text(knownSoFar)
                    .font(
                        .system(size: S3ActionBarMetrics.volumeSecondaryFontSize)
                    )
                    .foregroundStyle(S1ChromeForeground.secondary)
            case let .exact(primary):
                volumePrimaryText(primary)
            case let .lowerBound(primary, note):
                volumePrimaryText(primary)
                Text(note)
                    .font(
                        .system(size: S3ActionBarMetrics.volumeSecondaryFontSize)
                    )
                    .foregroundStyle(S1ChromeForeground.secondary)
            }
        }
        .lineLimit(1)
    }

    private func volumePrimaryText(_ text: String) -> some View {
        Text(text)
            .font(
                .system(
                    size: S3ActionBarMetrics.volumePrimaryFontSize,
                    design: .monospaced
                )
            )
            .foregroundStyle(S1ChromeForeground.primary)
    }

    private func submitButton(_ model: S3ActionBarModel) -> some View {
        Button {
            S3SubmitButtonAction.perform(isEnabled: model.submitEnabled) {
                coordinator.submitDeletion()
            }
        } label: {
            Text(model.submitTitle)
                .font(
                    .system(
                        size: S3ActionBarMetrics.submitFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(Color.white)
                .padding(
                    .horizontal,
                    S3ActionBarMetrics.submitHorizontalPadding
                )
                .frame(height: S3ActionBarMetrics.submitHeight)
                .background(
                    RoundedRectangle(
                        cornerRadius: S3ActionBarMetrics.submitCornerRadius,
                        style: .continuous
                    )
                    .fill(Color(uiColor: .systemRed))
                )
        }
        .buttonStyle(.plain)
        .disabled(!model.submitEnabled)
        .opacity(
            model.submitEnabled ? 1 : S3ActionBarMetrics.disabledOpacity
        )
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

    /// 手工分行而不是 `LazyVGrid`：明细行必须插在**该格所在行**的下方，
    /// 且跨满三列——网格容器给不出这个插入点。
    private func grid(
        _ group: S3GroupPresentation.Group,
        machine: S3StateMachine,
        cellWidth: CGFloat
    ) -> some View {
        let rows = S3GridRows.rows(group.orderedAssets)
        let expandedRow = detailExpansion.expandedAssetID.flatMap {
            S3GridRows.rowIndex(ofAssetID: $0, in: rows)
        }
        return VStack(spacing: S3GridMetrics.interitemSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: S3GridMetrics.interitemSpacing) {
                    ForEach(row, id: \.identifier) { asset in
                        cell(asset, machine: machine, cellWidth: cellWidth)
                    }
                    if row.count < S3GridMetrics.columnCount {
                        ForEach(row.count..<S3GridMetrics.columnCount, id: \.self) { _ in
                            Color.clear.frame(width: cellWidth, height: cellWidth)
                        }
                    }
                }
                if expandedRow == index, let assetID = detailExpansion.expandedAssetID {
                    volumeDetailRow(assetID)
                }
            }
        }
        .padding(.horizontal, S3GridMetrics.contentPadding)
        .padding(.bottom, S3GridMetrics.contentPadding)
    }

    /// 跨三列的一行明细：「照片 3.1 MB · 实况视频 2.4 MB」。
    private func volumeDetailRow(_ assetID: String) -> some View {
        let items = coordinator.scanBreakdown(for: assetID)
        return HStack(spacing: S3VolumeDetailMetrics.itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text(verbatim: "·")
                        .foregroundStyle(S1ChromeForeground.secondary)
                }
                HStack(spacing: S3VolumeDetailMetrics.pairSpacing) {
                    Text(S3VolumeDetailText.kindLabel(item.kind))
                        .foregroundStyle(S1ChromeForeground.secondary)
                    Text(S3VolumeDetailText.value(item.bytes))
                        .foregroundStyle(S1ChromeForeground.primary)
                }
            }
            Spacer(minLength: 0)
        }
        .font(
            .system(
                size: S3VolumeDetailMetrics.fontSize,
                design: .monospaced
            )
        )
        .padding(.vertical, S3VolumeDetailMetrics.verticalPadding)
        .padding(.horizontal, S3VolumeDetailMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: S3VolumeDetailMetrics.cornerRadius,
                style: .continuous
            )
            .fill(Color(uiColor: .systemGroupedBackground))
        )
    }

    private func cell(
        _ asset: AssetDescriptor,
        machine: S3StateMachine,
        cellWidth: CGFloat
    ) -> some View {
        let breakdownItemCount = coordinator.scanBreakdownItemCount(
            for: asset.identifier
        )
        let model = S3CellBadgeModel.make(
            asset: asset,
            conclusion: machine.cachedConclusion(for: asset.identifier),
            breakdownItemCount: breakdownItemCount,
            isDetailExpanded: detailExpansion.isExpanded(asset.identifier)
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
            volumeBadge(
                model,
                assetID: asset.identifier,
                breakdownItemCount: breakdownItemCount
            )
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

    private func volumeBadge(
        _ model: S3CellBadgeModel,
        assetID: String,
        breakdownItemCount: Int
    ) -> some View {
        Button {
            detailExpansion.toggle(
                assetID: assetID,
                breakdownItemCount: breakdownItemCount
            )
        } label: {
            volumeBadgeLabel(model)
        }
        .buttonStyle(.plain)
        .disabled(
            !S3DetailExpansion.isExpandable(
                breakdownItemCount: breakdownItemCount
            )
        )
        .padding(.trailing, S3CellBadgeMetrics.volumeTrailingInset)
        .padding(.bottom, S3CellBadgeMetrics.volumeBottomInset)
    }

    private func volumeBadgeLabel(_ model: S3CellBadgeModel) -> some View {
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
                Image(
                    systemName: model.isDetailExpanded
                        ? "chevron.up"
                        : "chevron.down"
                )
                .font(.system(size: S3CellBadgeMetrics.detailChevronPointSize))
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, S3CellBadgeMetrics.volumeHorizontalPadding)
        .frame(height: S3CellBadgeMetrics.volumeHeight)
        .background(
            Capsule().fill(S3CellBadgeMetrics.scrim)
        )
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
