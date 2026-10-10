import Photos
import PhotosUI
import SwiftUI
import UIKit

// MARK: - IC-128 A：S1 视觉常量（登记制，照 S2 `S2ChromePillMetrics`／`S2ChromeGlass` 形状）
// 不进 `S2CalibrationConfiguration`、不上标定面板。凡注「v18 §11.2」的取值转录自
// SPEC-S2 v18 第十一节第 2 部分；注「④卡」的为 IC-128 画布定稿转录；注「④取定」
// 的为卡内未给、本卡取定并在报告登记的微观值。

/// S1 chrome 布局锚（v18 §11.2 与 IC-128 画布）。顶排四值另被「空间清理」与 S3／S4／S5 借用；
/// 列表起始与菜单的三个推导偏移随 V1 页头退役（IC-192，SPEC-S1 v12 第十一节第 2d 部分改为距顶排底缘）。
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

/// chrome 与页面体前景（v18 回写决策 42 → IC-177 改恒定色）：全部屏统一「空间清理」的色板、
/// 不随系统外观（Decision_log 第 205 条第二节第 1 条）；仍是具体颜色值、不是层级样式——层级样式
/// 在启用态 Button 内会解析成 tint 蓝（IC-121 实证）。S3／S4／S5 引用本表；色板本身登记在
/// `S0DeckMetrics`（幕底 #0B0F0D、卡底 #161B18、文字 #FFFBF5、强调 #F26B4E）。三个不透明度取自
/// R2 画布 `.dim`／`.dim2`／`.edge`（卡内暂登，SPEC-S1 v11 回填）。
enum S1ChromeForeground {
    static let primary = S0DeckMetrics.text
    static let secondary = S0DeckMetrics.text.opacity(secondaryOpacity)
    /// 占位图标、空态与失败态图标（原 `.tertiaryLabel`）。
    static let tertiary = S0DeckMetrics.text.opacity(tertiaryOpacity)
    /// 分隔线：卡片叠外圈描边（`S1DeckCards`）、页头骨架（`S1PageHeader`；原 `.separator`）。
    static let separator = S0DeckMetrics.text.opacity(separatorOpacity)
    /// 选中态、「管理」与重试、S3 提交、S5 失败数与「返回确认页」（原系统 tint 蓝与系统红）。
    static let accent = S0DeckMetrics.accent
    static let pageBackground = S0DeckMetrics.background
    static let cardBackground = S0DeckMetrics.cardBase
    static let secondaryOpacity: Double = 0.62
    static let tertiaryOpacity: Double = 0.45
    static let separatorOpacity: Double = 0.14
}

/// chrome 文字与图标字号（v18 §11.2；中胶囊随 V1 页头退役，两个字号仍被「空间清理」与 S3／S4／S5 借用）。
enum S1ChromeTypography {
    /// 中胶囊主行（v18 §11.2 titleFontSize）。
    static let titleFontSize: CGFloat = 15
    /// 中胶囊副行（v18 §11.2 subtitleFontSize）。
    static let subtitleFontSize: CGFloat = 11.5
    /// 圆钮图标（v18 §11.2 circleIconPointSize）。
    static let circleIconPointSize: CGFloat = 17
}

/// 通知徽标样式（v18 §11.2 badge*，与 S2 确认入口徽标同族）。垃圾桶徽标描边取
/// 页面底色（v18 回写决策 43；IC-177 起为恒定色）；范围卡待删红点描边 `cardRing` 随旧列表层退役（IC-184）。
enum S1NotificationBadgeStyle {
    static let fontSize: CGFloat = 12
    static let minDiameter: CGFloat = 18
    static let horizontalPadding: CGFloat = 5
    static let ringWidth: CGFloat = 1.5
    static let fill = Color.red
    static let digitColor = Color.white
    static var chromeRing: Color {
        S1ChromeForeground.pageBackground
    }
}

/// IC-128 A／IC-131 A：顶排 chrome 的展示口径（测试钉住）。IC-192：V1 页头四类件同用本模型——排序钮、
/// 待删篮入口、人像圆钮按 `controlsEnabled`／`controlsOpacity`（S1-1 降 40% 不可触发），维度胶囊只按
/// `controlsEnabled`（S1-1 不可触发、不降暗）；「去确认」按 `trashEnabled`。
///
/// 四态统一口径（锁定决策 8：S1 的四个状态**均**显示垃圾桶入口；其中 S1-1
/// 加载中显示但不可触发）：
/// - 徽标数值 = `D_全部`，`> 0` 即显示，**与状态无关**（加载中、空态同样显示）；
/// - 垃圾桶可触发 = 非加载中且 `D_全部 > 0`，**与状态无关**。
///
/// IC-131 A 修正：原实装在 `.empty` 时一律禁用垃圾桶且不显示徽标，与锁定决策 8
/// 及 v8 第三节 S1-3「其他范围的既有选择仍可提交」直接冲突——切到一个 `R(T)`
/// 为空的维度（如设备无自建相册）会让既有选择看起来丢失且无法提交。
struct S1ChromeBarModel: Equatable {
    let controlsEnabled: Bool
    let controlsOpacity: Double
    let trashEnabled: Bool
    let badgeText: String?

    static func make(state: S1State, badgeCount: Int) -> S1ChromeBarModel {
        let isLoading = state == .loading
        let badgeVisible = badgeCount > 0
        return S1ChromeBarModel(
            controlsEnabled: !isLoading,
            controlsOpacity: isLoading ? 0.4 : 1,
            trashEnabled: !isLoading && badgeCount > 0,
            badgeText: badgeVisible ? String(badgeCount) : nil
        )
    }
}

// MARK: - IC-128 B：范围口径（IC-184 起只剩进度线比例与封面取图策略）

/// 进度线口径（测试钉住；卡片叠进度条借用）：填充比例 = 已处理数 / 该范围总数，钳到 [0, 1]。
/// 旧列表层的显隐口径 `isVisible` 随之退役（IC-184）。
enum S1ProgressLinePresentation {
    static func fillFraction(processed: Int, total: Int) -> Double {
        guard total > 0 else {
            return 0
        }
        return min(1, max(0, Double(processed) / Double(total)))
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
}

// MARK: - IC-128 C：受限提示条常量（两只自绘菜单随 V1 页头退役，IC-192）

/// 受限授权提示条（④卡：高 44 圆角 22 玻璃底、左起 17pt 图标、文案 13.5 单行
/// 省略、右端「管理」小胶囊高 30 圆角 15 水平内边距 12 tint 文字 + tint 10% 底；
/// 内水平边距 14 取胶囊留白同值为 ④取定）。
enum S1LimitedBannerStyle {
    static let height: CGFloat = 44
    static let cornerRadius: CGFloat = 22
    static let iconPointSize: CGFloat = 17
    static let textFontSize: CGFloat = 13.5
    static let manageHeight: CGFloat = 30
    static let manageCornerRadius: CGFloat = 15
    static let manageHorizontalPadding: CGFloat = 12
    static let manageTintBackgroundOpacity: Double = 0.10
    static let horizontalPadding: CGFloat = 14
}

/// IC-128 C：受限提示条显隐口径（测试钉住）。受限不进失败态：提示条挂在列表在场的状态（就绪／空态）；
/// V1 起位于维度胶囊下方、卡叠之上（IC-192），列表起始偏移随之退役。
enum S1LimitedBannerPresentation {
    static func isVisible(
        isLimitedAuthorization: Bool,
        state: S1State
    ) -> Bool {
        isLimitedAuthorization && (state == .ready || state == .empty)
    }
}

// MARK: - IC-128 D：四态版式常量与元素清单

/// 四态中央版式（④卡：图标 52pt、跑道胶囊按钮高 44 圆角 22 水平内边距 24
/// tint 文字玻璃底；主句 17 半粗、副句 13.5 次级色、加载文案 15 次级色与
/// 元素间距 12 为 ④取定登记）。
enum S1StatePlaceholderStyle {
    static let iconPointSize: CGFloat = 52
    static let buttonHeight: CGFloat = 44
    static let buttonCornerRadius: CGFloat = 22
    static let buttonHorizontalPadding: CGFloat = 24
    static let titleFontSize: CGFloat = 17
    static let subtitleFontSize: CGFloat = 13.5
    static let loadingTextFontSize: CGFloat = 15
    static let contentSpacing: CGFloat = 12
}

/// IC-128 D：四态元素清单（测试钉住）。
enum S1StateElement: Equatable {
    case dimmedDisabledChrome
    case progressIndicator
    case loadingText
    case emptyIcon
    case emptyText
    case authorizationIcon
    case authorizationTitle
    case authorizationSubtitle
    case openSettingsButton
    case readFailureIcon
    case readFailureTitle
    case readFailureSubtitle
    case retryButton
}

/// 四态版式：S1-1 chrome 降 40% 禁用 + 中央 ProgressView + 一行文案（不显示
/// 进度与预计数量）；S1-3 图标 + 主句、无操作按钮；S1-4 授权类给「打开系统
/// 设置」不给重试，读取类给「重试」不自动重试。
enum S1StateLayout {
    static func elements(
        state: S1State,
        failureCategory: S1FailureCategory?
    ) -> [S1StateElement] {
        switch state {
        case .loading:
            return [.dimmedDisabledChrome, .progressIndicator, .loadingText]
        case .ready:
            return []
        case .empty:
            return [.emptyIcon, .emptyText]
        case .failed:
            if failureCategory == .authorization {
                return [
                    .authorizationIcon,
                    .authorizationTitle,
                    .authorizationSubtitle,
                    .openSettingsButton
                ]
            }
            return [
                .readFailureIcon,
                .readFailureTitle,
                .readFailureSubtitle,
                .retryButton
            ]
        }
    }
}

// MARK: - IC-128 A：S1 玻璃族（与 S2 同语汇：iOS 26+ 系统 glassEffect，17–25 回落配方）

/// IC-134 前置（④ Lynn 2026-09-06 授权，白名单就此一行）：由 `private` 放宽为
/// internal，使 S3／S4／S5 的顶排 chrome 能**直接引用**这两个 helper，而不是各自
/// 重造一份等价 modifier。玻璃配方因此保持单一来源（H60 第 1 项「五页 chrome
/// 是否同一套」正是要看这个）。取值与行为一字未动。
extension View {
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
            // IC-172（④ 第 200 条第三节第 1 条）：玻璃一律按系统深色模式的效果、不随浅／深色变。
            // 覆盖只包住本 helper 返回的子树，内容的动态前景色随之解析到深色分支。
            .environment(\.colorScheme, .dark)
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
        // IC-172：回落配方同样恒深（系统材质随外观变，#289 实证）。
        .environment(\.colorScheme, .dark)
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

// MARK: - IC-171 B：徽标叠在玻璃合成边界之外

/// 玻璃钮报出自己的边界，供玻璃合成边界之外的一层叠徽标（S0 待删篮入口借用）。
struct S1GlassBadgeAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? {
        nil
    }

    static func reduce(
        value: inout Anchor<CGRect>?,
        nextValue: () -> Anchor<CGRect>?
    ) {
        value = value ?? nextValue()
    }
}

extension View {
    /// IC-120 B 同教训（S1 `chromeBar`、S2 `topBar` 两处先例）：iOS 26 玻璃会把叠在玻璃上的普通
    /// overlay 合成进玻璃层，徽标因此发虚。本视图包进一个玻璃合成边界，徽标叠在边界之外、右上
    /// 对齐；iOS 17～25 没有合成边界，直接叠。单只玻璃钮（S0 页头与首页的待删篮入口）用这个。
    @ViewBuilder
    func s1GlassBadgeOverlay<Badge: View>(
        @ViewBuilder badge: () -> Badge
    ) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                self
            }
            // IC-172：容器恒深；徽标在容器之外，不受覆盖。
            .environment(\.colorScheme, .dark)
            .overlay(alignment: .topTrailing) {
                badge()
            }
        } else {
            overlay(alignment: .topTrailing) {
                badge()
            }
        }
    }

    /// 同一原理，用于徽标所在的钮不在本视图边缘的情形（S0 类别页收起导航条：整条是一层玻璃，
    /// 垃圾桶右边还有排序与「全选」）：徽标叠在边界之外、子视图经 `S1GlassBadgeAnchorKey` 报出的
    /// 边界上（右上对齐，与直接叠在钮上同一位置）。
    @ViewBuilder
    func s1GlassBadgeHost<Badge: View>(
        @ViewBuilder badge: @escaping () -> Badge
    ) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                self
            }
            // IC-172：容器恒深；徽标层在容器之外，不受覆盖。
            .environment(\.colorScheme, .dark)
            .overlayPreferenceValue(S1GlassBadgeAnchorKey.self) { anchor in
                S1GlassBadgeLayer(anchor: anchor, badge: badge)
            }
        } else {
            overlayPreferenceValue(S1GlassBadgeAnchorKey.self) { anchor in
                S1GlassBadgeLayer(anchor: anchor, badge: badge)
            }
        }
    }
}

/// 徽标层：徽标放进与报出边界同尺寸、同中心的框里右上对齐。不接收点击。
struct S1GlassBadgeLayer<Badge: View>: View {
    let anchor: Anchor<CGRect>?
    let badge: () -> Badge

    var body: some View {
        GeometryReader { proxy in
            if let anchor {
                let rect = proxy[anchor]
                badge()
                    .frame(
                        width: rect.width,
                        height: rect.height,
                        alignment: .topTrailing
                    )
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - IC-131 B：写回失败的一次性反馈

/// IC-131 B（v8 回写决策 29）：从 S2 返回时写回校验失败的一次性反馈。
/// 成功不发事件。
///
/// IC-132 B 追加 `submissionUnavailable`：写回**已生效**、但提交形成不了
/// （`makeS3Submission()` 为 nil 或确认页校验未过）。与 `writeBackFailed`
/// 的区别在于写回结果是否保留，两者文案也不同。
enum S1FeedbackEventKind: Equatable {
    case writeBackFailed
    case submissionUnavailable
}

struct S1FeedbackEvent: Equatable, Identifiable {
    let id: Int
    let kind: S1FeedbackEventKind
}

/// IC-131 B：S1 底部短 toast 的呈现器。形状与 S2 侧同名角色一致——一次性事件
/// 驱动、同一时刻只显示一条、新事件替换旧事件（旧事件到期不再清除新事件）、
/// 计时经 `scheduler` 注入使测试不依赖真实时钟。
///
/// 单独一份而不跨页复用 S2 的实例：S2 视图随路由销毁，写回失败恰恰发生在
/// 离开 S2 的那一刻，复用会连同实例一起消失。
final class S1FeedbackToastPresenter: ObservableObject {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    @Published private(set) var activeEvent: S1FeedbackEvent?
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

    static func text(for kind: S1FeedbackEventKind) -> String {
        switch kind {
        case .writeBackFailed:
            return L10n.text("s1.toast.writeback_failed")
        case .submissionUnavailable:
            return L10n.text("s1.toast.submission_unavailable")
        }
    }

    func present(
        _ event: S1FeedbackEvent,
        durationMilliseconds: Double
    ) {
        generation += 1
        let currentGeneration = generation
        presentedCount += 1
        activeEvent = event
        let seconds = max(0, durationMilliseconds) / 1_000
        lastScheduledDurationSeconds = seconds
        scheduler(seconds) { [weak self] in
            self?.expire(generation: currentGeneration)
        }
    }

    private func expire(generation expiredGeneration: Int) {
        guard expiredGeneration == generation else {
            return
        }
        activeEvent = nil
    }
}

/// IC-132 B：垃圾桶按钮的动作口径（测试钉住——按钮本身不驱动渲染也能验）。
///
/// 原实装在 `makeS3Submission()` 为 nil 时直接 `return`，于是徽标显示 N、
/// 点下去毫无反应（跨启动恢复后名字表为空即会如此）。现在改为交出一条
/// `.submissionUnavailable` 反馈。
enum S1TrashButtonAction {
    static func perform(
        machine: S1StateMachine,
        onS3Submission: (SessionStore.S3Submission) -> Void,
        onSubmissionUnavailable: () -> Void
    ) {
        guard let submission = machine.makeS3Submission() else {
            onSubmissionUnavailable()
            return
        }
        onS3Submission(submission)
    }
}

// MARK: - S1View

struct S1View: View {
    /// IC-127 D：读取方回传结果 + 受限标志。
    typealias RangeReader = (S1GroupingDimension) -> S1RangeReadResponse

    @ObservedObject var machine: S1StateMachine
    @StateObject private var feedbackToast = S1FeedbackToastPresenter()
    /// IC-132 B：本视图自发反馈的序号源（与协调器通道的序号互不相干）。
    @State private var localFeedbackEventCount = 0

    private let rangeReader: RangeReader?
    private let onS2Handoff: (S1ToS2Handoff) -> Void
    private let onS3Submission: (SessionStore.S3Submission) -> Void
    /// IC-131 B：协调器里等着的一次性「写回失败」事件。视图出现或事件变化时取走
    /// 并交给呈现器，随后经 `onFeedbackEventConsumed` 把通道清空——失败发生在
    /// S1 尚未挂载的那一刻，事件必须能等到视图出现，不能丢。
    private let feedbackEvent: S1FeedbackEvent?
    private let feedbackToastDurationMilliseconds: Double
    private let onFeedbackEventConsumed: () -> Void

    init(
        machine: S1StateMachine,
        rangeReader: RangeReader? = nil,
        onS2Handoff: @escaping (S1ToS2Handoff) -> Void = { _ in },
        onS3Submission: @escaping (SessionStore.S3Submission) -> Void = { _ in },
        feedbackEvent: S1FeedbackEvent? = nil,
        feedbackToastDurationMilliseconds: Double = 0,
        onFeedbackEventConsumed: @escaping () -> Void = {}
    ) {
        self.machine = machine
        self.rangeReader = rangeReader
        self.onS2Handoff = onS2Handoff
        self.onS3Submission = onS3Submission
        self.feedbackEvent = feedbackEvent
        self.feedbackToastDurationMilliseconds = feedbackToastDurationMilliseconds
        self.onFeedbackEventConsumed = onFeedbackEventConsumed
    }

    var body: some View {
        NavigationStack {
            rootPage
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: presentedYearRangeBinding) { rangeID in
                    yearPage(rangeID)
                }
        }
        .allowsHitTesting(!machine.isObscured)
        .overlay(alignment: .bottom) {
            feedbackToastOverlay
        }
        .onAppear {
            readCurrentRequestIfPossible()
            presentPendingFeedbackEventIfNeeded()
        }
        .onChange(of: feedbackEvent) { _, _ in
            presentPendingFeedbackEventIfNeeded()
        }
    }

    /// IC-192（G2）：列表页照「空间清理」首页——就绪时整页一个 `ScrollView`（页头、受限条、卡叠同滚）；
    /// 加载中、空态、失败不滚动，页头之下是居中占位。年页由外层 `NavigationStack` 推出，身份在状态机
    /// （进 S2 时 tab 容器整棵重建、视图 `@State` 活不过一次往返——IC-157 同一教训）；toast 挂在栈外。
    private var rootPage: some View {
        ZStack(alignment: .top) {
            S1ChromeForeground.pageBackground
                .ignoresSafeArea()
            pageContainer {
                VStack(alignment: .leading, spacing: 0) {
                    pageHeader
                    limitedBannerRow
                    stateContent
                }
            }
        }
    }

    /// 就绪才滚动：占位的 `maxHeight: .infinity` 放进 `ScrollView` 撑不满视口，非就绪态不进滚动容器。
    @ViewBuilder
    private func pageContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if machine.state == .ready {
            // IC-200：路由往返重建后回到原来的滚动位置（卡片叠靠 `.offset` 摆位、定位不到卡，按记下的偏移恢复）。
            OffsetRestoringScrollView(memory: machine.openCards.listScroll) {
                content()
            }
        } else {
            content()
        }
    }

    /// 系统返回（边缘右滑）把 item 置 nil 时走状态机的同一出口；推出只由 `presentYearPage` 发起。
    private var presentedYearRangeBinding: Binding<String?> {
        Binding(
            get: { machine.presentedYearRangeID },
            set: { newValue in
                if newValue == nil {
                    machine.dismissYearPage()
                }
            }
        )
    }

    // MARK: - IC-131 B：写回失败 toast

    /// 底部短 toast。样式取 S2 侧既有常量（同字号、同底、同圆角），不新造；
    /// 位置只锚安全区底 + `bottomRowBottomInset`——S1 没有底部横栏，不能套
    /// S2 那条含横栏高的推导式（视觉锚与触控锚是两套几何）。
    @ViewBuilder
    private var feedbackToastOverlay: some View {
        if let event = feedbackToast.activeEvent {
            Text(S1FeedbackToastPresenter.text(for: event.kind))
                .font(.subheadline)
                .padding(.horizontal, S2OverlayLayout.minimumSpacing * 2)
                .padding(.vertical, S2OverlayLayout.minimumSpacing)
                .background(.regularMaterial, in: Capsule())
                // IC-172：toast 的材质与文字同样恒深。
                .environment(\.colorScheme, .dark)
                .padding(.bottom, S2OverlayLayout.bottomRowBottomInset)
                .allowsHitTesting(false)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func presentPendingFeedbackEventIfNeeded() {
        guard let feedbackEvent else {
            return
        }
        feedbackToast.present(
            feedbackEvent,
            durationMilliseconds: feedbackToastDurationMilliseconds
        )
        onFeedbackEventConsumed()
    }

    /// IC-132 B：本视图自己产生的反馈（垃圾桶点不动）。此刻 S1 必然已挂载，
    /// 不必绕协调器的等待通道，直接驱动本地呈现器；`id` 取负数与协调器发来的
    /// 正序号分处两个命名空间，互不误判为同一条。
    private func presentLocalFeedback(_ kind: S1FeedbackEventKind) {
        localFeedbackEventCount += 1
        feedbackToast.present(
            S1FeedbackEvent(id: -localFeedbackEventCount, kind: kind),
            durationMilliseconds: feedbackToastDurationMilliseconds
        )
    }

    // MARK: - IC-192：V1 页头（SPEC-S1 v12 第三节前言、第六节第 3、4 部分）

    private var chromeModel: S1ChromeBarModel {
        S1ChromeBarModel.make(
            state: machine.state,
            badgeCount: machine.badgeCount
        )
    }

    /// 页头只收值与回调；一次 `body` 只取一次 `headerSummary`（IC-191 规格欠账 (3)）。
    private var pageHeader: some View {
        S1PageHeader(
            state: machine.state,
            summary: machine.headerSummary,
            groupingDimension: machine.groupingDimension,
            badgeCount: machine.badgeCount,
            chromeModel: chromeModel,
            sortOrder: sortOrderBinding,
            onBasket: openBasket,
            onSelectDimension: selectDimension,
            onOpenAccount: {}
        )
    }

    /// 系统 `Menu` 的选择写进状态机；同值或遮挡时状态机拒收，菜单照系统默认关闭。
    private var sortOrderBinding: Binding<S1SortOrder> {
        Binding(
            get: { machine.sortOrder },
            set: { newValue in
                _ = machine.switchSortOrder(to: newValue)
            }
        )
    }

    /// 待删篮入口与副行「去确认」同一动作（决策 8）。
    private func openBasket() {
        S1TrashButtonAction.perform(
            machine: machine,
            onS3Submission: onS3Submission,
            onSubmissionUnavailable: {
                presentLocalFeedback(.submissionUnavailable)
            }
        )
    }

    private var showsLimitedBanner: Bool {
        S1LimitedBannerPresentation.isVisible(
            isLimitedAuthorization: machine.isLimitedAuthorization,
            state: machine.state
        )
    }

    /// 受限提示条位于维度胶囊下方、卡叠之上（第六节第 4 部分）。
    @ViewBuilder
    private var limitedBannerRow: some View {
        if showsLimitedBanner {
            limitedBanner
                .padding(.horizontal, S1ChromeLayout.horizontalMargin)
                .padding(.top, S1PageHeaderMetrics.bannerTopSpacing)
        }
    }

    private func selectDimension(_ dimension: S1GroupingDimension) {
        guard machine.switchGroupingDimension(to: dimension) else {
            return
        }
        // IC-200：换维度是一张新列表——容器随加载态重建，不把旧偏移搬过来，从顶部开始。
        machine.openCards.listScroll.offset = 0
        readCurrentRequestIfPossible()
    }

    // MARK: - IC-128 C：受限授权提示条

    private var limitedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: S1LimitedBannerStyle.iconPointSize))
                .foregroundStyle(S1ChromeForeground.primary)
            Text(L10n.text("s1.limited.banner"))
                .font(.system(size: S1LimitedBannerStyle.textFontSize))
                .foregroundStyle(S1ChromeForeground.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            limitedManageButton
        }
        .padding(.horizontal, S1LimitedBannerStyle.horizontalPadding)
        .frame(height: S1LimitedBannerStyle.height)
        .frame(maxWidth: .infinity)
        .s1ChromeGlassBackground(in: Capsule())
    }

    private var limitedManageButton: some View {
        Button {
            presentLimitedLibraryManagement()
        } label: {
            Text(L10n.text("s1.limited.manage"))
                .font(
                    .system(
                        size: S1LimitedBannerStyle.textFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.accent)
                .padding(
                    .horizontal,
                    S1LimitedBannerStyle.manageHorizontalPadding
                )
                .frame(height: S1LimitedBannerStyle.manageHeight)
                .background(
                    S1ChromeForeground.accent.opacity(
                        S1LimitedBannerStyle.manageTintBackgroundOpacity
                    ),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    /// 卡内未指明「管理」动作语义；接系统受限照片管理入口（报告登记）。
    private func presentLimitedLibraryManagement() {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first
        guard let presenter = scene?.keyWindow?.rootViewController else {
            return
        }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
    }

    // MARK: - IC-128 D：四态版式

    @ViewBuilder
    private var stateContent: some View {
        switch machine.state {
        case .loading:
            loadingState
        case .ready:
            rangeList
                .padding(.top, S1PageHeaderMetrics.deckTopSpacing)
        case .empty:
            emptyState
        case .failed:
            failureState
        }
    }

    /// S1-1：中央系统 ProgressView + 一行文案，不显示进度、不显示预计数量。
    private var loadingState: some View {
        VStack(spacing: S1StatePlaceholderStyle.contentSpacing) {
            ProgressView().tint(S1ChromeForeground.secondary)
            Text(L10n.text("s1.state.loading"))
                .font(
                    .system(
                        size: S1StatePlaceholderStyle.loadingTextFontSize
                    )
                )
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// S1-3：中央线条图标（照片外框 52pt 三级色）+ 一行主句；无操作按钮。
    private var emptyState: some View {
        VStack(spacing: S1StatePlaceholderStyle.contentSpacing) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: S1StatePlaceholderStyle.iconPointSize))
                .foregroundStyle(S1ChromeForeground.tertiary)
            Text(L10n.text("s1.state.empty"))
                .font(
                    .system(
                        size: S1StatePlaceholderStyle.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var failureState: some View {
        if machine.readFailure?.category == .authorization {
            authorizationFailureState
        } else {
            readFailureState
        }
    }

    /// S1-4 授权类：锁形图标 + 主句 + 副句 + 「打开系统设置」；不给重试。
    private var authorizationFailureState: some View {
        VStack(spacing: S1StatePlaceholderStyle.contentSpacing) {
            Image(systemName: "lock")
                .font(.system(size: S1StatePlaceholderStyle.iconPointSize))
                .foregroundStyle(S1ChromeForeground.tertiary)
            Text(L10n.text("s1.state.auth_failure.title"))
                .font(
                    .system(
                        size: S1StatePlaceholderStyle.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
                .multilineTextAlignment(.center)
            Text(L10n.text("s1.state.auth_failure.subtitle"))
                .font(
                    .system(size: S1StatePlaceholderStyle.subtitleFontSize)
                )
                .foregroundStyle(S1ChromeForeground.secondary)
                .multilineTextAlignment(.center)
            placeholderButton(
                title: L10n.text("s1.state.auth_failure.button")
            ) {
                openSystemSettings()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// S1-4 读取类：三角感叹图标 + 主句 + 副句 + 「重试」；不自动重试
    /// （唯一的重试触发点即本按钮）。
    private var readFailureState: some View {
        VStack(spacing: S1StatePlaceholderStyle.contentSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: S1StatePlaceholderStyle.iconPointSize))
                .foregroundStyle(S1ChromeForeground.tertiary)
            Text(L10n.text("s1.state.read_failure.title"))
                .font(
                    .system(
                        size: S1StatePlaceholderStyle.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
                .multilineTextAlignment(.center)
            Text(L10n.text("s1.state.read_failure.subtitle"))
                .font(
                    .system(size: S1StatePlaceholderStyle.subtitleFontSize)
                )
                .foregroundStyle(S1ChromeForeground.secondary)
                .multilineTextAlignment(.center)
            placeholderButton(
                title: L10n.text("s1.state.read_failure.button")
            ) {
                guard machine.retry() else {
                    return
                }
                readCurrentRequestIfPossible()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// 跑道胶囊按钮（④卡：高 44、圆角 22、水平内边距 24、tint 色文字、玻璃底）。
    private func placeholderButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(
                    .system(
                        size: S1StatePlaceholderStyle.loadingTextFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.accent)
                .padding(
                    .horizontal,
                    S1StatePlaceholderStyle.buttonHorizontalPadding
                )
                .frame(height: S1StatePlaceholderStyle.buttonHeight)
                .s1ChromeGlassBackground(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - IC-178 C：年卡叠 → 年页（Decision_log 第 205 条第二节第 1 条；两级树的展开区退役）

    /// IC-193：一级范围一叠 V1 卡（`T=按日期` 是年卡，其余维度是相册／未分类卡），展开态由卡叠自己观察。点收起的卡展开它；
    /// 点展开卡：有子节点的进年页、其余直接进 S2。月卡数据从 `rangeRows` 里按 `parentRangeID` 过滤（全部月都在）。
    private var rangeList: some View {
        S1DeckListView(
            rows: machine.rangeRows.filter { $0.parentRangeID == nil },
            kind: machine.groupingDimension == .date ? .years : .albums,
            openCards: machine.openCards,
            slot: .list,
            coverAssetID: coverAssetID(for:),
            onOpen: { row in
                _ = machine.openListCard(row.id)
            },
            onEnter: { row in
                if S1DeckCardPresentation.opensYearPage(childCount: row.childCount) {
                    _ = machine.presentYearPage(row.id)
                } else {
                    enterRange(row.id)
                }
            }
        )
    }

    /// 年页：返回 + 待删篮入口、V1 标题区（年份、体积行、「整理整年」、汇总行、年进度条）、月卡叠。年在对账后消失时状态机
    /// 会把身份清掉、页面随之弹回；这里只对找不到行的一瞬做兜底，不画内容。
    @ViewBuilder
    private func yearPage(_ rangeID: String) -> some View {
        let rows = machine.rangeRows
        if let yearRow = rows.first(where: { $0.id == rangeID }) {
            S1YearPageView(
                yearRow: yearRow,
                monthRows: rows.filter { $0.parentRangeID == rangeID },
                basketCount: machine.badgeCount,
                openCards: machine.openCards,
                coverAssetID: coverAssetID(for:),
                onBack: {
                    machine.dismissYearPage()
                },
                onOrganizeYear: {
                    enterRange(rangeID)
                },
                onOpenMonth: { row in
                    _ = machine.openYearPageCard(row.id)
                },
                onEnterMonth: { row in
                    enterRange(row.id)
                },
                onTrash: {
                    S1TrashButtonAction.perform(
                        machine: machine,
                        onS3Submission: onS3Submission,
                        onSubmissionUnavailable: {
                            presentLocalFeedback(.submissionUnavailable)
                        }
                    )
                }
            )
        }
    }

    /// 封面沿用 IC-128 B 的口径：该范围按当前 `O` 的第一张；年取按 `O` 的首个月再取其第一张。
    private func coverAssetID(for row: S1RangeRow) -> String? {
        S1RangeCoverPolicy.coverAssetID(
            forRangeID: row.id,
            in: machine.ranges,
            sortOrder: machine.sortOrder
        )
    }

    private func enterRange(_ rangeID: String) {
        guard let handoff = machine.makeS2Handoff(for: rangeID) else {
            return
        }
        onS2Handoff(handoff)
    }

    // MARK: - 读取

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
