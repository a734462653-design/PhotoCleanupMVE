import SwiftUI
import UIKit

// MARK: - IC-128 A：S1 视觉常量（登记制，照 S2 `S2ChromePillMetrics`／`S2ChromeGlass` 形状）
// 不进 `S2CalibrationConfiguration`、不上标定面板。凡注「v18 §11.2」的取值转录自
// SPEC-S2 v18 第十一节第 2 部分；注「④卡」的为 IC-128 画布定稿转录；注「④取定」
// 的为卡内未给、本卡取定并在报告登记的微观值。

/// S1 chrome 布局锚。画布基准 393×852、安全区顶 59：卡内「距屏顶」的 114／122／174
/// 在此登记为「距安全区顶」的推导量（卡内 122 = 62 + 44 + 16 自证推导式），随机型
/// 安全区自适应。
enum S1ChromeLayout {
    /// 圆钮直径 = 胶囊高 = chrome 行高（v18 §11.2 chromeRowHeight）。
    static let rowHeight: CGFloat = 44
    /// 顶排上缘距安全区顶（v18 §11.2 topRowTopInset）。
    static let topRowTopInset: CGFloat = 3
    /// chrome 左右边距（v18 §11.2 chromeHorizontalMargin）。
    static let horizontalMargin: CGFloat = 16
    /// 顶排件间距（④卡）。
    static let itemSpacing: CGFloat = 8
    /// chrome 底缘 → 菜单／受限提示条顶缘（④卡：画布 114 − 106）。
    static let chromeToOverlaySpacing: CGFloat = 8
    /// chrome 底缘 → 列表起始（④卡：画布 122 − 106）。
    static let chromeToListSpacing: CGFloat = 16
    /// 受限提示条底缘 → 列表起始（④卡：画布 174 − 158）。
    static let bannerToListSpacing: CGFloat = 16
    /// 菜单／受限提示条顶缘距安全区顶（④卡：画布 114 − 59 = 3 + 44 + 8）。
    static let overlayTopOffset: CGFloat = 55
    /// 正常列表起始距安全区顶（④卡：画布 122 − 59 = 3 + 44 + 16）。
    static let listTopOffset: CGFloat = 63
    /// 受限提示条在场时列表起始距安全区顶（④卡：画布 174 − 59 = 55 + 44 + 16）。
    static let limitedListTopOffset: CGFloat = 115
}

/// S1 玻璃配方（v18 §11.2 glass*，与 S2 同族同值）。
enum S1ChromeGlass {
    static let tintOpacity: Double = 0.03
    static let innerHighlightTop: Double = 0.30
    static let innerHighlightBottom: Double = 0.06
    static let innerStrokeWidth: CGFloat = 1
    static let outerRingOpacity: Double = 0.12
    static let outerStrokeWidth: CGFloat = 0.5
}

/// chrome 前景（v18 回写决策 42）：必须用**具体动态色**——层级样式在启用态
/// Button 内会解析成 tint 蓝（IC-121 实证），`Color.primary/.secondary` 不参与
/// tint／层级解析。
enum S1ChromeForeground {
    static let primary = Color.primary
    static let secondary = Color.secondary
}

/// chrome 文字与图标字号（v18 §11.2；capsuleChevronPointSize 为 ④取定）。
enum S1ChromeTypography {
    /// 中胶囊主行（v18 §11.2 titleFontSize）。
    static let titleFontSize: CGFloat = 15
    /// 中胶囊副行（v18 §11.2 subtitleFontSize）。
    static let subtitleFontSize: CGFloat = 11.5
    /// 圆钮图标（v18 §11.2 circleIconPointSize）。
    static let circleIconPointSize: CGFloat = 17
    /// 中胶囊主行下箭头字号（④取定：主行 15 的随行小箭头）。
    static let capsuleChevronPointSize: CGFloat = 11
}

/// 通知徽标样式（v18 §11.2 badge*，与 S2 确认入口徽标同族）。垃圾桶徽标描边取
/// 系统底色（v18 回写决策 43）；范围卡待删红点描边取卡片底色（④卡）。
enum S1NotificationBadgeStyle {
    static let fontSize: CGFloat = 12
    static let minDiameter: CGFloat = 18
    static let horizontalPadding: CGFloat = 5
    static let ringWidth: CGFloat = 1.5
    static let fill = Color.red
    static let digitColor = Color.white
    static var chromeRing: Color {
        Color(uiColor: .systemBackground)
    }
    static var cardRing: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
}

/// IC-128 A：顶排 chrome 的展示口径（测试钉住）。
/// S1-1 加载中：三件降 40% 不透明并禁用，垃圾桶入口与徽标照常显示、只是不可触发；
/// S1-3 空态：垃圾桶入口禁用、徽标不显示；
/// 其余：徽标数值 = `D_全部`，为 0 时不显示且入口禁用。
struct S1ChromeBarModel: Equatable {
    let controlsEnabled: Bool
    let controlsOpacity: Double
    let trashEnabled: Bool
    let badgeText: String?

    static func make(state: S1State, badgeCount: Int) -> S1ChromeBarModel {
        let isLoading = state == .loading
        let badgeVisible = badgeCount > 0 && state != .empty
        return S1ChromeBarModel(
            controlsEnabled: !isLoading,
            controlsOpacity: isLoading ? 0.4 : 1,
            trashEnabled: !isLoading && state != .empty && badgeCount > 0,
            badgeText: badgeVisible ? String(badgeCount) : nil
        )
    }
}

/// IC-128 A：中胶囊副行口径——总数 = `R(T)` 各范围资产**并集**数（相册维度同一
/// 资产可属多相册、日期维度年月两级重叠，取并集避免重复计数）；范围数 = `R(T)`
/// 范围项总数（年与月都是范围）。卡内未指明口径，此为 ④取定登记。
enum S1ChromeSubtitle {
    static func counts(
        for ranges: [S1Range]
    ) -> (assetCount: Int, rangeCount: Int) {
        var union = Set<String>()
        for range in ranges {
            union.formUnion(range.assetIDsNewestFirst)
        }
        return (union.count, ranges.count)
    }
}

/// IC-128 A/C：两菜单互斥——单一枚举承载同一时刻至多一个；点开着的那个再点一次
/// 即关闭，点另一个则切换（开一个必然关另一个）。
enum S1ActiveMenu: Equatable {
    case none
    case sort
    case dimension

    func toggling(_ tapped: S1ActiveMenu) -> S1ActiveMenu {
        self == tapped ? .none : tapped
    }
}

// MARK: - IC-128 A：S1 玻璃族（与 S2 同语汇：iOS 26+ 系统 glassEffect，17–25 回落配方）

private extension View {
    @ViewBuilder
    func s1ChromeGlassBackground<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: shape
            )
        } else {
            s1LegacyChromeGlassBackground(in: shape)
        }
    }

    func s1LegacyChromeGlassBackground<S: InsettableShape>(
        in shape: S
    ) -> some View {
        background {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(S1ChromeGlass.tintOpacity))
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(S1ChromeGlass.innerHighlightTop),
                        Color.white.opacity(S1ChromeGlass.innerHighlightBottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: S1ChromeGlass.innerStrokeWidth
            )
        }
        .overlay {
            shape.strokeBorder(
                Color.white.opacity(S1ChromeGlass.outerRingOpacity),
                lineWidth: S1ChromeGlass.outerStrokeWidth
            )
        }
    }

    /// 玻璃圆钮：定尺 Ø44 + 玻璃底（圆钮走交互变体）。
    func s1ChromeCircleGlass() -> some View {
        font(
            .system(
                size: S1ChromeTypography.circleIconPointSize,
                weight: .semibold
            )
        )
        .frame(
            width: S1ChromeLayout.rowHeight,
            height: S1ChromeLayout.rowHeight
        )
        .s1ChromeGlassBackground(in: Circle(), interactive: true)
    }
}

// MARK: - S1View

struct S1View: View {
    /// IC-127 D：读取方回传结果 + 受限标志。
    typealias RangeReader = (S1GroupingDimension) -> S1RangeReadResponse

    @ObservedObject var machine: S1StateMachine
    @State private var activeMenu: S1ActiveMenu = .none

    private let rangeReader: RangeReader?
    private let onS2Handoff: (S1ToS2Handoff) -> Void
    private let onS3Submission: (SessionStore.S3Submission) -> Void

    init(
        machine: S1StateMachine,
        rangeReader: RangeReader? = nil,
        onS2Handoff: @escaping (S1ToS2Handoff) -> Void = { _ in },
        onS3Submission: @escaping (SessionStore.S3Submission) -> Void = { _ in }
    ) {
        self.machine = machine
        self.rangeReader = rangeReader
        self.onS2Handoff = onS2Handoff
        self.onS3Submission = onS3Submission
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            stateContent
                .padding(.top, S1ChromeLayout.listTopOffset)
            chromeColumn
        }
        .allowsHitTesting(!machine.isObscured)
        .onAppear {
            readCurrentRequestIfPossible()
        }
    }

    // MARK: - IC-128 A：顶排 chrome

    private var chromeModel: S1ChromeBarModel {
        S1ChromeBarModel.make(
            state: machine.state,
            badgeCount: machine.badgeCount
        )
    }

    private var chromeColumn: some View {
        chromeBar
            .padding(.top, S1ChromeLayout.topRowTopInset)
            .padding(.horizontal, S1ChromeLayout.horizontalMargin)
    }

    /// IC-120 B 同教训：iOS 26 玻璃容器会把普通 overlay 盖进合成层，
    /// 徽标以 overlay 叠在容器之外，两分支同一实现。
    @ViewBuilder
    private var chromeBar: some View {
        let model = chromeModel
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                chromeItems(model)
            }
            .overlay(alignment: .topTrailing) {
                trashBadge(model)
            }
            .opacity(model.controlsOpacity)
        } else {
            chromeItems(model)
                .overlay(alignment: .topTrailing) {
                    trashBadge(model)
                }
                .opacity(model.controlsOpacity)
        }
    }

    private func chromeItems(_ model: S1ChromeBarModel) -> some View {
        HStack(spacing: S1ChromeLayout.itemSpacing) {
            sortButton(model)
            dimensionCapsule(model)
            trashButton(model)
        }
    }

    private func sortButton(_ model: S1ChromeBarModel) -> some View {
        Button {
            activeMenu = activeMenu.toggling(.sort)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(S1ChromeForeground.primary)
                .s1ChromeCircleGlass()
        }
        .disabled(!model.controlsEnabled)
        .accessibilityLabel(L10n.text("s1.sort.accessibility"))
    }

    private func dimensionCapsule(_ model: S1ChromeBarModel) -> some View {
        Button {
            activeMenu = activeMenu.toggling(.dimension)
        } label: {
            capsuleLabel
        }
        .disabled(!model.controlsEnabled)
        .accessibilityLabel(L10n.text("s1.dimension.accessibility"))
    }

    private var capsuleLabel: some View {
        VStack(spacing: 1) {
            capsuleTitleLine
            capsuleSubtitleLine
        }
        .frame(maxWidth: .infinity)
        .frame(height: S1ChromeLayout.rowHeight)
        .s1ChromeGlassBackground(in: Capsule())
    }

    private var capsuleTitleLine: some View {
        HStack(spacing: 4) {
            Text(groupingTitle(machine.groupingDimension))
                .font(
                    .system(
                        size: S1ChromeTypography.titleFontSize,
                        weight: .semibold
                    )
                )
            Image(
                systemName: activeMenu == .dimension
                    ? "chevron.up"
                    : "chevron.down"
            )
            .font(
                .system(
                    size: S1ChromeTypography.capsuleChevronPointSize,
                    weight: .semibold
                )
            )
        }
        .foregroundStyle(S1ChromeForeground.primary)
    }

    private var capsuleSubtitleLine: some View {
        let counts = S1ChromeSubtitle.counts(for: machine.ranges)
        return Text(
            L10n.text(
                "s1.chrome.subtitle_format",
                replacing: [
                    "count": String(counts.assetCount),
                    "ranges": String(counts.rangeCount)
                ]
            )
        )
        .font(.system(size: S1ChromeTypography.subtitleFontSize))
        .monospacedDigit()
        .foregroundStyle(S1ChromeForeground.secondary)
    }

    private func trashButton(_ model: S1ChromeBarModel) -> some View {
        Button {
            guard let submission = machine.makeS3Submission() else {
                return
            }
            onS3Submission(submission)
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(S1ChromeForeground.primary)
                .s1ChromeCircleGlass()
        }
        .disabled(!model.trashEnabled)
        .accessibilityLabel(
            L10n.text(
                "s1.trash.accessibility",
                replacing: ["count": String(machine.badgeCount)]
            )
        )
    }

    @ViewBuilder
    private func trashBadge(_ model: S1ChromeBarModel) -> some View {
        if let badgeText = model.badgeText {
            Text(badgeText)
                .font(
                    .system(
                        size: S1NotificationBadgeStyle.fontSize,
                        weight: .semibold
                    )
                )
                .monospacedDigit()
                .foregroundStyle(S1NotificationBadgeStyle.digitColor)
                .padding(
                    .horizontal,
                    S1NotificationBadgeStyle.horizontalPadding
                )
                .frame(
                    minWidth: S1NotificationBadgeStyle.minDiameter,
                    minHeight: S1NotificationBadgeStyle.minDiameter
                )
                .background(S1NotificationBadgeStyle.fill, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(
                        S1NotificationBadgeStyle.chromeRing,
                        lineWidth: S1NotificationBadgeStyle.ringWidth
                    )
                }
                .allowsHitTesting(false)
        }
    }

    // MARK: - 状态内容（IC-128 D 重排前的暂留版式）

    @ViewBuilder
    private var stateContent: some View {
        switch machine.state {
        case .loading:
            placeholderState(
                S1UndecidedItems.localizedCopy(.loading)
            )

        case .ready:
            // IC-127 A：年节点行拆成「展开／收起」与「进入」两个可区分的点击目标，
            // 月节点行左侧内缩；卡片化视觉随 IC-128 B 落地。
            List(machine.rangeRows) { row in
                HStack(spacing: 12) {
                    if row.childCount > 0 {
                        Button {
                            _ = machine.toggleYearExpansion(row.id)
                        } label: {
                            Image(
                                systemName: row.isExpanded
                                    ? "chevron.down"
                                    : "chevron.right"
                            )
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        guard let handoff = machine.makeS2Handoff(for: row.id) else {
                            return
                        }
                        onS2Handoff(handoff)
                    } label: {
                        rangeRow(row)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, row.parentRangeID == nil ? 0 : 28)
            }

        case .empty:
            placeholderState(
                S1UndecidedItems.localizedCopy(.empty)
            )

        case .failed:
            VStack(spacing: 12) {
                Text(S1UndecidedItems.localizedCopy(.failure))
                    .multilineTextAlignment(.center)
                Button(S1UndecidedItems.localizedCopy(.retry)) {
                    guard machine.retry() else {
                        return
                    }
                    readCurrentRequestIfPossible()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private func placeholderState(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }

    private func rangeRow(_ row: S1RangeRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.displayName)
                .font(.headline)
            Text(L10n.text(
                "s1.range.total_count",
                replacing: ["count": String(row.totalAssetCount)]
            ))
            if row.pendingDeletionCount == 0 {
                Text(S1UndecidedItems.localizedCopy(.zeroPending))
            } else {
                Text(L10n.text(
                    "s1.range.pending_count",
                    replacing: ["count": String(row.pendingDeletionCount)]
                ))
            }
            Text(S1UndecidedItems.localizedCopy(
                .progress,
                replacing: [
                    "processed": String(row.processedAssetCount),
                    "total": String(row.totalAssetCount)
                ]
            ))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 读取与文案

    private func readCurrentRequestIfPossible() {
        guard let rangeReader,
              let request = machine.currentReadRequest else {
            return
        }
        let response = rangeReader(request.groupingDimension)
        _ = machine.completeRangeRead(
            response.result,
            for: request,
            isLimitedAuthorization: response.isLimitedAuthorization
        )
    }

    private func groupingTitle(_ dimension: S1GroupingDimension) -> String {
        switch dimension {
        case .date:
            return L10n.text("s1.dimension.date")
        case .album:
            return L10n.text("s1.dimension.album")
        case .unclassified:
            return L10n.text("s1.dimension.unclassified")
        }
    }

    private func sortTitle(_ sortOrder: S1SortOrder) -> String {
        switch sortOrder {
        case .newestFirst:
            return L10n.text("s1.sort.newest_first")
        case .oldestFirst:
            return L10n.text("s1.sort.oldest_first")
        }
    }
}

private enum S1PreviewData {
    static func machine(
        state: S1State
    ) -> S1StateMachine {
        var store = SessionStore(sessionID: "preview-session")
        store.setMarked(
            true,
            assetID: "preview-asset-2",
            rangeID: "preview-range"
        )
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        guard let request = machine.currentReadRequest else {
            return machine
        }

        switch state {
        case .loading:
            break
        case .ready:
            _ = machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "preview-year",
                        displayName: "2026",
                        assetIDsNewestFirst: [
                            "preview-asset-2",
                            "preview-asset-1"
                        ]
                    ),
                    S1Range(
                        id: "preview-range",
                        displayName: "2026-08",
                        assetIDsNewestFirst: [
                            "preview-asset-2",
                            "preview-asset-1"
                        ],
                        parentRangeID: "preview-year"
                    )
                ]),
                for: request
            )
        case .empty:
            _ = machine.completeRangeRead(.success([]), for: request)
        case .failed:
            _ = machine.completeRangeRead(
                .failure(
                    S1RangeReadFailure(
                        groupingDimension: .date,
                        reason: .invalidResponse
                    )
                ),
                for: request
            )
        }
        return machine
    }
}

#Preview("S1-1") {
    S1View(machine: S1PreviewData.machine(state: .loading))
}

#Preview("S1-2") {
    S1View(machine: S1PreviewData.machine(state: .ready))
}

#Preview("S1-3") {
    S1View(machine: S1PreviewData.machine(state: .empty))
}

#Preview("S1-4") {
    S1View(machine: S1PreviewData.machine(state: .failed))
}
