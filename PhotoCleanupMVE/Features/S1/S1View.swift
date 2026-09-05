import Photos
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

// MARK: - IC-128 B：范围卡常量与展示口径

/// 范围项卡片几何（④卡；contentSpacing 与 topLevelLeadingInset 为 ④取定）。
enum S1RangeCardMetrics {
    /// 列表卡片圆角（④卡 14）。
    static let cornerRadius: CGFloat = 14
    /// 列表左右边距（④卡 16）。
    static let horizontalMargin: CGFloat = 16
    /// 卡片间距（④卡 16）。
    static let cardSpacing: CGFloat = 16
    /// 缩略图边长（④卡 56）。
    static let thumbnailSide: CGFloat = 56
    /// 缩略图圆角（④卡 12）。
    static let thumbnailCornerRadius: CGFloat = 12
    /// 月／相册行高；年行取同值为最小行高（④卡 76）。
    static let rowHeight: CGFloat = 76
    /// 行上下内边距（④卡 10）。
    static let verticalPadding: CGFloat = 10
    /// 显示名字号（④卡 17；年节点 19 半粗）。
    static let nameFontSize: CGFloat = 17
    static let yearNameFontSize: CGFloat = 19
    /// 张数字号（④卡 13，次级色，等宽数字）。
    static let countFontSize: CGFloat = 13
    /// 右端进入指示箭头（④卡 13pt 次级）。
    static let chevronPointSize: CGFloat = 13
    /// 年行左侧展开／收起区宽与右缘分隔线（④卡 40 / 0.5）。
    static let expandZoneWidth: CGFloat = 40
    static let expandDividerWidth: CGFloat = 0.5
    /// 月行左内边距（④卡 52）。
    static let monthLeadingInset: CGFloat = 52
    /// 顶层行（相册／未分类／年行内容区）左右内边距与元素间距（④取定 12）。
    static let contentSpacing: CGFloat = 12
    /// 待删红点位置：top −5 / right −5（④卡）。
    static let pendingBadgeOffset: CGFloat = 5
}

/// 已处理进度线（④卡：左右各内缩 6、距底 6、高 3、圆角 2；底白 34%、填充白 95%）。
enum S1ProgressLineStyle {
    static let horizontalInset: CGFloat = 6
    static let bottomInset: CGFloat = 6
    static let height: CGFloat = 3
    static let cornerRadius: CGFloat = 2
    static let trackOpacity: Double = 0.34
    static let fillOpacity: Double = 0.95
}

/// 进度线口径（测试钉住）：填充比例 = 已处理数 / 该范围总数，钳到 [0, 1]；
/// 范围未开始（`r.id` 不在 `K` 中）时整条不画。
enum S1ProgressLinePresentation {
    static func fillFraction(processed: Int, total: Int) -> Double {
        guard total > 0 else {
            return 0
        }
        return min(1, max(0, Double(processed) / Double(total)))
    }

    static func isVisible(hasContinuation: Bool) -> Bool {
        hasContinuation
    }
}

/// 待删红点口径（测试钉住）：零待删不画。
enum S1PendingBadgePresentation {
    static func text(count: Int) -> String? {
        count > 0 ? String(count) : nil
    }
}

/// 范围卡结构口径（测试钉住）：展开区仅年节点（有子节点的行）持有；
/// 展开区与「进入年范围」是两个可区分的点击目标（规格第六节硬要求）。
enum S1RangeCardPresentation {
    static func hasExpandZone(childCount: Int) -> Bool {
        childCount > 0
    }

    static func leadingInset(isChildRow: Bool) -> CGFloat {
        isChildRow
            ? S1RangeCardMetrics.monthLeadingInset
            : S1RangeCardMetrics.contentSpacing
    }
}

/// 年节点缩略图垫卡（④卡：层一 top 5 / left 8 / 56×46；层二 top 2 / left 4 /
/// 56×50；圆角 10。top/left 解释为相对主图原点向右下的 x/y 位移——层高小于主图，
/// 唯有横向位移能露出层叠边，报告登记该解释）。
enum S1YearStackStyle {
    static let cornerRadius: CGFloat = 10
    static let layerOneSize = CGSize(width: 56, height: 46)
    static let layerOneOffset = CGSize(width: 8, height: 5)
    static let layerTwoSize = CGSize(width: 56, height: 50)
    static let layerTwoOffset = CGSize(width: 4, height: 2)

    /// 浅色 #D8D8DE、深色 #3A3A3C。
    static var layerOneColor: Color {
        dynamicColor(
            light: (0xD8, 0xD8, 0xDE),
            dark: (0x3A, 0x3A, 0x3C)
        )
    }

    /// 浅色 #CACAD1、深色 #2F2F31。
    static var layerTwoColor: Color {
        dynamicColor(
            light: (0xCA, 0xCA, 0xD1),
            dark: (0x2F, 0x2F, 0x31)
        )
    }

    private static func dynamicColor(
        light: (Int, Int, Int),
        dark: (Int, Int, Int)
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                let rgb = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat(rgb.0) / 255,
                    green: CGFloat(rgb.1) / 255,
                    blue: CGFloat(rgb.2) / 255,
                    alpha: 1
                )
            }
        )
    }
}

/// IC-128 B：范围封面取图策略（Decision_log 第 140 条挂给本卡的定案）。
/// 封面 = 该范围按当前 `O` 排序后的首张（与进入后首屏一致，`O` 翻转封面跟着变）；
/// 年节点递归取首个子范围的封面，不另取。
enum S1RangeCoverPolicy {
    static func coverAssetID(
        forRangeID rangeID: String,
        in ranges: [S1Range],
        sortOrder: S1SortOrder
    ) -> String? {
        guard let range = ranges.first(where: { $0.id == rangeID }) else {
            return nil
        }
        let children = ranges.filter { $0.parentRangeID == range.id }
        guard !children.isEmpty else {
            return range.orderedAssetIDs(for: sortOrder).first
        }
        let orderedChildren = sortOrder == .oldestFirst
            ? Array(children.reversed())
            : children
        guard let firstChild = orderedChildren.first else {
            return nil
        }
        return coverAssetID(
            forRangeID: firstChild.id,
            in: ranges,
            sortOrder: sortOrder
        )
    }

    /// 请求口径：目标尺寸按 56pt × 屏幕 scale（2× 取 112px、3× 取 168px）。
    static func targetPixelSize(displayScale: CGFloat) -> CGSize {
        let side = S1RangeCardMetrics.thumbnailSide * displayScale
        return CGSize(width: side, height: side)
    }
}

/// IC-128 B：封面呈现相位与「只升不降」替换规则（S2 决策 28、v16 回写决策 36
/// 同族口径）：降质图先上、最终图原位替换；已到最终图后不被降质图覆盖；
/// 取不到图（nil）只在尚无图可展示时落中性占位，不回退已有图。
enum S1CoverImagePhase: Equatable {
    case loading
    case placeholder
    case degraded
    case final

    static func shouldReplace(
        current: S1CoverImagePhase,
        incomingIsDegraded: Bool,
        incomingIsNil: Bool
    ) -> Bool {
        if incomingIsNil {
            return current == .loading
        }
        switch current {
        case .loading, .placeholder, .degraded:
            return true
        case .final:
            return !incomingIsDegraded
        }
    }
}

/// IC-128 B：封面图请求抽象。回调可多次（降质先上、最终图替换），主线程回调；
/// 测试注入夹具实现，生产走 PhotoKit。
protocol S1CoverImageLoading {
    func loadCoverImage(
        assetID: String,
        targetSize: CGSize,
        onImage: @escaping (UIImage?, _ isDegraded: Bool) -> Void
    )
}

/// 生产实现：`PHImageManager` 单次 opportunistic 请求——降质图先回、最终图后到；
/// 无预取、无磁盘缓存、无自建后台队列（卡内明示不做）。
struct S1PhotoKitCoverImageLoader: S1CoverImageLoading {
    func loadCoverImage(
        assetID: String,
        targetSize: CGSize,
        onImage: @escaping (UIImage?, Bool) -> Void
    ) {
        let fetched = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        )
        guard let asset = fetched.firstObject else {
            onImage(nil, false)
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? NSNumber)?
                .boolValue ?? false
            if Thread.isMainThread {
                onImage(image, isDegraded)
            } else {
                DispatchQueue.main.async {
                    onImage(image, isDegraded)
                }
            }
        }
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

// MARK: - IC-128 B：封面缩略图

/// 56×56 圆角 12 封面：降质先上、最终图原位替换（只升不降）；取不到图显示
/// 中性占位（次级色底 + 照片线条图标），不显示破图、不显示错误文案；
/// 请求异步回调，不阻塞列表渲染。
private struct S1RangeCoverThumbnail: View {
    let assetID: String?
    let loader: any S1CoverImageLoading

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var phase: S1CoverImagePhase = .loading
    @State private var requestedAssetID: String?

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: S1RangeCardMetrics.thumbnailCornerRadius
            )
            .fill(Color(uiColor: .secondarySystemFill))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if phase == .placeholder {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(S1ChromeForeground.secondary)
            }
        }
        .frame(
            width: S1RangeCardMetrics.thumbnailSide,
            height: S1RangeCardMetrics.thumbnailSide
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: S1RangeCardMetrics.thumbnailCornerRadius
            )
        )
        .onAppear {
            requestIfNeeded()
        }
        .onChange(of: assetID) { _, _ in
            image = nil
            phase = .loading
            requestedAssetID = nil
            requestIfNeeded()
        }
    }

    private func requestIfNeeded() {
        guard let assetID else {
            phase = .placeholder
            return
        }
        guard requestedAssetID != assetID else {
            return
        }
        requestedAssetID = assetID
        let targetSize = S1RangeCoverPolicy.targetPixelSize(
            displayScale: displayScale
        )
        loader.loadCoverImage(
            assetID: assetID,
            targetSize: targetSize
        ) { incoming, isDegraded in
            guard requestedAssetID == assetID else {
                return
            }
            guard S1CoverImagePhase.shouldReplace(
                current: phase,
                incomingIsDegraded: isDegraded,
                incomingIsNil: incoming == nil
            ) else {
                return
            }
            if let incoming {
                image = incoming
                phase = isDegraded ? .degraded : .final
            } else {
                image = nil
                phase = .placeholder
            }
        }
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
    private let coverImageLoader: any S1CoverImageLoading

    init(
        machine: S1StateMachine,
        rangeReader: RangeReader? = nil,
        onS2Handoff: @escaping (S1ToS2Handoff) -> Void = { _ in },
        onS3Submission: @escaping (SessionStore.S3Submission) -> Void = { _ in },
        coverImageLoader: any S1CoverImageLoading = S1PhotoKitCoverImageLoader()
    ) {
        self.machine = machine
        self.rangeReader = rangeReader
        self.onS2Handoff = onS2Handoff
        self.onS3Submission = onS3Submission
        self.coverImageLoader = coverImageLoader
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
            rangeList

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

    // MARK: - IC-128 B：范围卡列表

    /// IC-127 A 结构不变：年节点行的「展开／收起」与「进入」仍是两个可区分的
    /// 点击目标（展开区触发展开／收起，行其余部分触发进入）。
    private var rangeList: some View {
        ScrollView {
            LazyVStack(spacing: S1RangeCardMetrics.cardSpacing) {
                ForEach(machine.rangeRows) { row in
                    rangeCard(row)
                }
            }
            .padding(.horizontal, S1RangeCardMetrics.horizontalMargin)
            .padding(.bottom, S1RangeCardMetrics.cardSpacing)
        }
    }

    @ViewBuilder
    private func rangeCard(_ row: S1RangeRow) -> some View {
        if S1RangeCardPresentation.hasExpandZone(childCount: row.childCount) {
            yearCard(row)
        } else {
            plainCard(row)
        }
    }

    private func plainCard(_ row: S1RangeRow) -> some View {
        Button {
            enterRange(row.id)
        } label: {
            rowContent(row, isYear: false)
                .padding(
                    .leading,
                    S1RangeCardPresentation.leadingInset(
                        isChildRow: row.parentRangeID != nil
                    )
                )
                .padding(.trailing, S1RangeCardMetrics.contentSpacing)
        }
        .buttonStyle(.plain)
        .frame(minHeight: S1RangeCardMetrics.rowHeight)
        .background(cardBackground)
    }

    private func yearCard(_ row: S1RangeRow) -> some View {
        HStack(spacing: 0) {
            expandZone(row)
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(width: S1RangeCardMetrics.expandDividerWidth)
            Button {
                enterRange(row.id)
            } label: {
                rowContent(row, isYear: true)
                    .padding(
                        .horizontal,
                        S1RangeCardMetrics.contentSpacing
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: S1RangeCardMetrics.rowHeight)
        .background(cardBackground)
    }

    private func expandZone(_ row: S1RangeRow) -> some View {
        Button {
            _ = machine.toggleYearExpansion(row.id)
        } label: {
            Image(
                systemName: row.isExpanded
                    ? "chevron.down"
                    : "chevron.right"
            )
            .font(
                .system(
                    size: S1RangeCardMetrics.chevronPointSize,
                    weight: .semibold
                )
            )
            .foregroundStyle(S1ChromeForeground.secondary)
            .frame(width: S1RangeCardMetrics.expandZoneWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rowContent(_ row: S1RangeRow, isYear: Bool) -> some View {
        HStack(spacing: S1RangeCardMetrics.contentSpacing) {
            thumbnailStack(row, isYear: isYear)
            rowTexts(row, isYear: isYear)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: S1RangeCardMetrics.chevronPointSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .padding(.vertical, S1RangeCardMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func rowTexts(_ row: S1RangeRow, isYear: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.displayName)
                .font(
                    .system(
                        size: isYear
                            ? S1RangeCardMetrics.yearNameFontSize
                            : S1RangeCardMetrics.nameFontSize,
                        weight: isYear ? .semibold : .regular
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(L10n.text(
                "s1.range.total_count",
                replacing: ["count": String(row.totalAssetCount)]
            ))
            .font(.system(size: S1RangeCardMetrics.countFontSize))
            .monospacedDigit()
            .foregroundStyle(S1ChromeForeground.secondary)
        }
    }

    private func thumbnailStack(_ row: S1RangeRow, isYear: Bool) -> some View {
        let coverAssetID = S1RangeCoverPolicy.coverAssetID(
            forRangeID: row.id,
            in: machine.ranges,
            sortOrder: machine.sortOrder
        )
        let hasContinuation =
            machine.sessionStore.continuationsByRangeID[row.id] != nil
        return ZStack(alignment: .topLeading) {
            if isYear {
                yearStackLayers
            }
            S1RangeCoverThumbnail(
                assetID: coverAssetID,
                loader: coverImageLoader
            )
            .overlay(alignment: .bottom) {
                progressLine(row, hasContinuation: hasContinuation)
            }
            .overlay(alignment: .topTrailing) {
                pendingBadge(row)
            }
        }
        .padding(.trailing, isYear ? S1YearStackStyle.layerOneOffset.width : 0)
    }

    private var yearStackLayers: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: S1YearStackStyle.cornerRadius)
                .fill(S1YearStackStyle.layerOneColor)
                .frame(
                    width: S1YearStackStyle.layerOneSize.width,
                    height: S1YearStackStyle.layerOneSize.height
                )
                .offset(
                    x: S1YearStackStyle.layerOneOffset.width,
                    y: S1YearStackStyle.layerOneOffset.height
                )
            RoundedRectangle(cornerRadius: S1YearStackStyle.cornerRadius)
                .fill(S1YearStackStyle.layerTwoColor)
                .frame(
                    width: S1YearStackStyle.layerTwoSize.width,
                    height: S1YearStackStyle.layerTwoSize.height
                )
                .offset(
                    x: S1YearStackStyle.layerTwoOffset.width,
                    y: S1YearStackStyle.layerTwoOffset.height
                )
        }
    }

    @ViewBuilder
    private func progressLine(
        _ row: S1RangeRow,
        hasContinuation: Bool
    ) -> some View {
        if S1ProgressLinePresentation.isVisible(
            hasContinuation: hasContinuation
        ) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(
                        cornerRadius: S1ProgressLineStyle.cornerRadius
                    )
                    .fill(
                        Color.white.opacity(S1ProgressLineStyle.trackOpacity)
                    )
                    RoundedRectangle(
                        cornerRadius: S1ProgressLineStyle.cornerRadius
                    )
                    .fill(
                        Color.white.opacity(S1ProgressLineStyle.fillOpacity)
                    )
                    .frame(
                        width: proxy.size.width
                            * S1ProgressLinePresentation.fillFraction(
                                processed: row.processedAssetCount,
                                total: row.totalAssetCount
                            )
                    )
                }
            }
            .frame(height: S1ProgressLineStyle.height)
            .padding(.horizontal, S1ProgressLineStyle.horizontalInset)
            .padding(.bottom, S1ProgressLineStyle.bottomInset)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func pendingBadge(_ row: S1RangeRow) -> some View {
        if let badgeText = S1PendingBadgePresentation.text(
            count: row.pendingDeletionCount
        ) {
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
                        S1NotificationBadgeStyle.cardRing,
                        lineWidth: S1NotificationBadgeStyle.ringWidth
                    )
                }
                .offset(
                    x: S1RangeCardMetrics.pendingBadgeOffset,
                    y: -S1RangeCardMetrics.pendingBadgeOffset
                )
                .allowsHitTesting(false)
                .accessibilityLabel(
                    L10n.text(
                        "s1.range.pending_count",
                        replacing: [
                            "count": String(row.pendingDeletionCount)
                        ]
                    )
                )
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: S1RangeCardMetrics.cornerRadius)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func enterRange(_ rangeID: String) {
        guard let handoff = machine.makeS2Handoff(for: rangeID) else {
            return
        }
        onS2Handoff(handoff)
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
