import SwiftUI

// MARK: - IC-179：S2 三句就地提示（Decision_log 第 207 条第五节；SPEC-S2 v22 决策 48 归 v23 改写）
//
// 六步教程（IC-110 D 起）**停用不删**：类型、接线与其 20 条测试原样留在 `S2View.swift`，
// 只是不再从视图启动；退役归后续维护卡。本文件是替代它的三句就地提示：
// 每句各自记「已会」，已会 = 用户真做过一次那个动作；× 只收本次进入期间、不记已会。

/// 三句提示。`rawValue` 同时是持久化键名的后缀。
enum S2InlineHint: String, CaseIterable, Equatable {
    /// 第 1 句：进 S2 立即出、不等动手；真实上滑标记一次即已会。
    case swipeUp
    /// 第 2 句：第一次标记成功后出、限时自动收起；真实撤标一次即已会。
    case markedOnce
    /// 第 3 句：篮内合并计数上升到 `S2InlineHintCoordinator.confirmThreshold` 出；点右上入口一次即已会。
    case confirmEntry

    /// 标题。每个分支各自整句取文案、不拼 key——硬编码扫描器只认写死的字面量 key。
    /// 第 3 句带张数占位符（目录既有的花括号写法）。
    func title(mergedCount: Int) -> String {
        switch self {
        case .swipeUp:
            return L10n.text("s2.hint.swipe_up")
        case .markedOnce:
            return L10n.text("s2.hint.marked")
        case .confirmEntry:
            return L10n.text(
                "s2.hint.confirm",
                replacing: ["count": String(mergedCount)]
            )
        }
    }

    /// 副句。
    var subtitle: String {
        switch self {
        case .swipeUp:
            return L10n.text("s2.hint.swipe_up.sub")
        case .markedOnce:
            return L10n.text("s2.hint.marked.sub")
        case .confirmEntry:
            return L10n.text("s2.hint.confirm.sub")
        }
    }

    /// 第 1／2 句压在主图中心上方的循环手势示意（IC-182 起为就地提示自己的 `S2InlineHintGestureView`）；第 3 句没有。
    var gestureDirection: S2TutorialGestureDirection? {
        switch self {
        case .swipeUp:
            return .up
        case .markedOnce:
            return .down
        case .confirmEntry:
            return nil
        }
    }

    /// IC-182（④ 第 211 条）：三句都挂右上、顶排之下；只有第 3 句带指向垃圾桶圆钮的小三角。
    var pointsAtConfirmEntry: Bool {
        self == .confirmEntry
    }

    /// 标题左侧的符号（照 `S0DeckSymbol` 的写法：登记为常量，不经 helper 返回字面量）。
    /// 第 3 句照 R2 画布不带符号。
    var symbolName: String? {
        switch self {
        case .swipeUp:
            return S2InlineHintSymbol.swipeUp
        case .markedOnce:
            return S2InlineHintSymbol.markedOnce
        case .confirmEntry:
            return nil
        }
    }
}

/// SF Symbol 名登记（R2 画布 `bubble()` 的 `up`／`shield`／`close`，`hint_gesture()` 的 `hand`／`up`／`down`）。
/// 手势示意三名由决策会话卡内取定，存在性由 CI 断言 `UIImage(systemName:)` 非空核。
enum S2InlineHintSymbol {
    static let swipeUp = "arrow.up"
    static let markedOnce = "checkmark.shield"
    static let dismiss = "xmark"
    static let gestureHand = "hand.point.up.left"
    static let gestureArrowDown = "arrow.down"
    static let gestureArrowRight = "arrow.right"
}

// MARK: - 持久化

/// 三个「已会」标志的持久化。协议化以便夹具注入内存实现（与 `S2TutorialCompletionStoring` 同款）。
/// **不入 `S2CalibrationConfiguration`**，因此不是出厂值、`schemaVersion` 不动。
protocol S2InlineHintStoring {
    func isLearned(_ hint: S2InlineHint) -> Bool
    func markLearned(_ hint: S2InlineHint)
    /// 标定面板「重看教程」用：清掉三个标志。
    func reset()
}

struct S2UserDefaultsInlineHintStore: S2InlineHintStoring {
    /// `UserDefaults` 键名前缀，后接 `S2InlineHint.rawValue`；值为 `Bool`，缺失视为「未会」。
    /// 与旧教程的 `…s2.tutorial-completed` 互不相干：老用户即使走完过六步教程，三句提示照常各出一次。
    static let defaultsKeyPrefix =
        "com.iphonephotomanagement.PhotoCleanupMVE.s2.hint."

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func defaultsKey(for hint: S2InlineHint) -> String {
        defaultsKeyPrefix + hint.rawValue
    }

    func isLearned(_ hint: S2InlineHint) -> Bool {
        defaults.bool(forKey: Self.defaultsKey(for: hint))
    }

    func markLearned(_ hint: S2InlineHint) {
        defaults.set(true, forKey: Self.defaultsKey(for: hint))
    }

    func reset() {
        for hint in S2InlineHint.allCases {
            defaults.removeObject(forKey: Self.defaultsKey(for: hint))
        }
    }
}

// MARK: - 协调器

/// 三句就地提示的状态机。**不旁路手势分派**（同 IC-110 D 的纪律）：三个真实事件全部来自
/// `S2View` 已经在读的已发布状态——上滑标记＝`pendingDeletionAssetIDs` 新增、撤标＝同集合
/// 移除（下滑、中央「撤销」、加入相簿后的静默移除都算）、攒到几张＝`sessionMergedPendingDeletionCount`
/// 上升；点入口来自入口按钮自己的 action。
///
/// 同一时刻至多一句在显。第 1 句被真实标记学会后紧接着出第 2 句；第 2 句限时
/// （`markedOnceAutoDismissSeconds`）到点不记已会地收起；第 3 句只在计数**上升**到阈值时出，
/// 并顶掉在显的第 1／2 句（顶掉时第 2 句本次进入不再出）——标记与计数两个回调在同一次
/// 更新里不论谁先跑，结果都是第 3 句在显、第 2 句本次不再出。
final class S2InlineHintCoordinator: ObservableObject {
    /// 第 3 句的阈值（④ 卡内取定：「攒到几张」= 5）。
    static let confirmThreshold = 5
    /// 第 2 句的限时秒数（④ 卡内取定）：到点不记已会地收起，本次进入不再出。
    static let markedOnceAutoDismissSeconds: TimeInterval = 6

    @Published private(set) var activeHint: S2InlineHint?

    /// 本次进入期间不再出的句子（× 收起、限时到点、被第 3 句顶掉），**不记已会**；
    /// `startIfNeeded`／`leaveScreen`／`reset` 清空。
    private(set) var dismissedThisVisit: Set<S2InlineHint> = []

    /// 上一次看到的篮内合并计数；第 3 句只在计数上升时判。
    private(set) var lastMergedCount = 0

    private let store: S2InlineHintStoring

    init(store: S2InlineHintStoring) {
        self.store = store
    }

    func isLearned(_ hint: S2InlineHint) -> Bool {
        store.isLearned(hint)
    }

    /// IC-182（④ 第 211 条）：下一次标记成功后要不要停在刚标记的这张——恰当第 2 句会在那一刻出现时
    /// （无句在显或第 1 句在显，且第 2 句未会、本次未收起）。视图据此置 `S2StateMachine.holdsPageAfterNextMark`。
    var holdsPageOnNextMark: Bool {
        (activeHint == nil || activeHint == .swipeUp) && canShow(.markedOnce)
    }

    /// 进 S2 立即调（`onAppear`）：未会第 1 句就出第 1 句；否则若篮内已攒到阈值且未会第 3 句就出第 3 句。
    func startIfNeeded(mergedCount: Int) {
        dismissedThisVisit = []
        lastMergedCount = mergedCount
        guard activeHint == nil else {
            return
        }
        if canShow(.swipeUp) {
            activeHint = .swipeUp
            return
        }
        if mergedCount >= Self.confirmThreshold, canShow(.confirmEntry) {
            activeHint = .confirmEntry
        }
    }

    /// 真实上滑标记（待删集合新增）：第 1 句已会并收起；随即出第 2 句（未会且本次未收起过）。
    func assetDidBecomeMarked() {
        learn(.swipeUp)
        if activeHint == nil, canShow(.markedOnce) {
            activeHint = .markedOnce
        }
    }

    /// 撤标（待删集合移除）：第 2 句已会并收起。
    func assetDidBecomeUnmarked() {
        learn(.markedOnce)
    }

    /// 篮内合并计数变化：只在**上升**到阈值、第 3 句未会且本次未收起过时出第 3 句，
    /// 顶掉在显的第 1／2 句（第 2 句本次进入不再出；第 1 句由同一次标记学会）。
    func mergedCountDidChange(_ count: Int) {
        let previous = lastMergedCount
        lastMergedCount = count
        guard count > previous,
              count >= Self.confirmThreshold,
              activeHint != .confirmEntry,
              canShow(.confirmEntry) else {
            return
        }
        dismissedThisVisit.insert(.markedOnce)
        activeHint = .confirmEntry
    }

    /// 第 2 句限时到点：不记已会地收起，本次进入不再出。只对第 2 句有效。
    func hintDidTimeOut(_ hint: S2InlineHint) {
        guard hint == .markedOnce, activeHint == .markedOnce else {
            return
        }
        dismissedThisVisit.insert(.markedOnce)
        activeHint = nil
    }

    /// 点右上确认入口：第 3 句已会并收起。
    func confirmEntryTapped() {
        learn(.confirmEntry)
    }

    /// × 钮：只收本次进入期间，不记已会（已会 = 真做过一次）。
    func dismiss() {
        guard let hint = activeHint else {
            return
        }
        dismissedThisVisit.insert(hint)
        activeHint = nil
    }

    /// 离开 S2：收起，不记。
    func leaveScreen() {
        activeHint = nil
        dismissedThisVisit = []
    }

    /// 标定面板「重看教程」：清掉三个已会标志并当场重出第 1 句。
    func reset() {
        store.reset()
        dismissedThisVisit = []
        activeHint = .swipeUp
    }

    private func canShow(_ hint: S2InlineHint) -> Bool {
        !store.isLearned(hint) && !dismissedThisVisit.contains(hint)
    }

    private func learn(_ hint: S2InlineHint) {
        store.markLearned(hint)
        if activeHint == hint {
            activeHint = nil
        }
    }
}

// MARK: - 视觉登记（卡内暂登，SPEC-S2 v23 第十一节回填）

/// 取值出处：R2 画布 `Tasks/design-s1-r2/gen.py` 的 `.bub`（`:94`）、`bubble()`（`:451-459`）与
/// `hint_gesture()`；CSS px 即 pt。色一律引用 `S0DeckMetrics`（暖白底 `text`、深字 `background`、
/// 强调符号 `accent`），不复制、不随系统外观。标「④」的是卡内取定、偏离或补足画布之处。
enum S2InlineHintMetrics {
    /// `.bub { border-radius: 22px; padding: 12px 16px }`。
    static let cornerRadius: CGFloat = 22
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    /// 标题 `font-size: 16px; font-weight: 800`（`.heavy`）；④ 允许折行（画布 `nowrap`）。
    static let titleFontSize: CGFloat = 16
    /// 副句 `font-size: 13.5px; font-weight: 600`（`.semibold`）、`color: rgba(11,15,13,0.7)`、`margin-top: 4px`。
    static let subtitleFontSize: CGFloat = 13.5
    static let subtitleOpacity: Double = 0.7
    static let subtitleTopSpacing: CGFloat = 4
    /// 标题左侧符号 20 pt、与标题间距 8（`gap: 8px`）。
    static let symbolPointSize: CGFloat = 20
    static let symbolSpacing: CGFloat = 8
    /// × 钮可见 26 pt 圆、图标 14 pt、底 `rgba(11,15,13,0.08)`、与标题间距 6（`margin-left: 6px`）；
    /// ④ 命中区扩到仓内最小触控 44（可见尺寸不变，命中区向四周各多出 `dismissTouchOverhang`）。
    static let dismissButtonSide: CGFloat = 26
    static let dismissSymbolPointSize: CGFloat = 14
    static let dismissBackgroundOpacity: Double = 0.08
    static let dismissButtonLeading: CGFloat = 6
    static let dismissTouchTargetSide: CGFloat = S2OverlayLayout.minimumTouchTarget
    static let dismissTouchOverhang: CGFloat = (dismissTouchTargetSide - dismissButtonSide) / 2
    /// 气泡最大宽 300：IC-182 起三句都挂右上、框内右对齐，气泡右缘恒贴 `trailingMargin`（居中句的 340 退役）。
    static let trailingMaxWidth: CGFloat = 300
    /// `box-shadow: 0 10px 30px rgba(0,0,0,0.45)`（CSS 模糊半径 30 → SwiftUI radius 15）。
    static let shadowOpacity: Double = 0.45
    static let shadowRadius: CGFloat = 15
    static let shadowYOffset: CGFloat = 10
    /// 第 1／2 句的循环手势示意（不再与气泡绑成一个单元）：底缘距主图显示帧竖直中心 = 中央指示容器半高 + 16
    /// 的避让（④，避让值沿用旧教程 `S2TutorialHintAnchor.indicatorClearance`）。
    static let indicatorClearance: CGFloat = 16
    static let centeredUnitBottomInset: CGFloat =
        S2CenterIndicatorView.containerHeight / 2 + indicatorClearance
    /// 手势示意（R2 画布 `hint_gesture()`）：手 28 pt 在 Ø56 圆里（底暖白 0.18）、圆外 8 pt 光晕（暖白 0.08）、
    /// 箭头 28 pt、竖向间距 6；循环位移 40、周期 0.9 s（沿旧教程示意的节奏，④）；光晕画成圆外一圈环（CSS 外阴影不落在圆内）。
    static let gestureCircleSide: CGFloat = 56
    static let gestureCircleFillOpacity: Double = 0.18
    static let gestureHaloWidth: CGFloat = 8
    static let gestureHaloOpacity: Double = 0.08
    static let gestureHandPointSize: CGFloat = 28
    static let gestureArrowPointSize: CGFloat = 28
    static let gestureSpacing: CGFloat = 6
    static let gestureTravel: CGFloat = 40
    static let gestureCycleSeconds: TimeInterval = 0.9
    /// 手势示意的对比阴影（沿 IC-113 C：白填充在白照片上不可辨，整个单元加黑影 0.35／半径 3）。
    static let gestureShadowOpacity: Double = 0.35
    static let gestureShadowRadius: CGFloat = 3
    /// 第 3 句：小三角 14 pt 方块转 45°、圆角 3，压进气泡 8 pt（`margin-bottom: -8`）；④ 右缩进取 19
    /// （画布 18）：三角中心距气泡右缘 = 19 + 7 = 26，加气泡右边距 12 = 38 = 顶排右上圆钮中心距
    /// 视口右缘（`chromeHorizontalMargin` 16 + 圆钮半径 22）。
    static let pointerSide: CGFloat = 14
    static let pointerCornerRadius: CGFloat = 3
    static let pointerOverlap: CGFloat = 8
    static let pointerTrailingInset: CGFloat = 19
    static let trailingMargin: CGFloat = 12
    /// 气泡上缘（第 3 句为三角上缘）距顶排下缘（④）。
    static let topBarGap: CGFloat = 4
    /// 出现／消失的淡入淡出时长（④）。
    static let transitionSeconds: TimeInterval = 0.2
}

// MARK: - 视图

/// 一只气泡：暖白底、深字；标题行 = 符号 + 标题 + ×（画布 `align-items: center`），副句整宽在下。
/// **只有 × 钮吃点击**——底与文字都禁用命中，手势原样落到主图（同中央指示的做法：可点控件
/// 叠在已禁用命中的子树之外）。
struct S2InlineHintBubble: View {
    let hint: S2InlineHint
    let mergedCount: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: S2InlineHintMetrics.subtitleTopSpacing) {
            HStack(spacing: 0) {
                HStack(spacing: S2InlineHintMetrics.symbolSpacing) {
                    if let symbolName = hint.symbolName {
                        Image(systemName: symbolName)
                            .font(.system(
                                size: S2InlineHintMetrics.symbolPointSize,
                                weight: .bold
                            ))
                            .foregroundStyle(S0DeckMetrics.accent)
                    }
                    Text(hint.title(mergedCount: mergedCount))
                        .font(.system(
                            size: S2InlineHintMetrics.titleFontSize,
                            weight: .heavy
                        ))
                        .foregroundStyle(S0DeckMetrics.background)
                }
                .allowsHitTesting(false)

                dismissButton
                    // 命中区 44 而布局仍按可见的 26 占位：负内距把多出的部分收回。
                    .padding(
                        .leading,
                        S2InlineHintMetrics.dismissButtonLeading -
                            S2InlineHintMetrics.dismissTouchOverhang
                    )
                    .padding(.trailing, -S2InlineHintMetrics.dismissTouchOverhang)
                    .padding(.vertical, -S2InlineHintMetrics.dismissTouchOverhang)
            }
            Text(hint.subtitle)
                .font(.system(
                    size: S2InlineHintMetrics.subtitleFontSize,
                    weight: .semibold
                ))
                .foregroundStyle(
                    S0DeckMetrics.background
                        .opacity(S2InlineHintMetrics.subtitleOpacity)
                )
                .allowsHitTesting(false)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, S2InlineHintMetrics.horizontalPadding)
        .padding(.vertical, S2InlineHintMetrics.verticalPadding)
        .background {
            RoundedRectangle(
                cornerRadius: S2InlineHintMetrics.cornerRadius,
                style: .continuous
            )
            .fill(S0DeckMetrics.text)
            .shadow(
                color: Color.black.opacity(S2InlineHintMetrics.shadowOpacity),
                radius: S2InlineHintMetrics.shadowRadius,
                x: 0,
                y: S2InlineHintMetrics.shadowYOffset
            )
            .allowsHitTesting(false)
        }
    }

    private var dismissButton: some View {
        Button {
            onDismiss()
        } label: {
            Image(systemName: S2InlineHintSymbol.dismiss)
                .font(.system(
                    size: S2InlineHintMetrics.dismissSymbolPointSize,
                    weight: .bold
                ))
                .foregroundStyle(S0DeckMetrics.background)
                .frame(
                    width: S2InlineHintMetrics.dismissButtonSide,
                    height: S2InlineHintMetrics.dismissButtonSide
                )
                .background(
                    S0DeckMetrics.background
                        .opacity(S2InlineHintMetrics.dismissBackgroundOpacity),
                    in: Circle()
                )
                .frame(
                    width: S2InlineHintMetrics.dismissTouchTargetSide,
                    height: S2InlineHintMetrics.dismissTouchTargetSide
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("s2.hint.dismiss"))
    }
}

/// 一句提示在视口里的落位（IC-182，④ 第 211 条：三句统一右上）。气泡一律右上、顶排之下、框内右对齐；
/// 第 3 句带小三角指向垃圾桶圆钮，第 1／2 句不带。第 1／2 句另有循环手势示意压在主图上：横向居中、
/// **底缘**锚在主图显示帧竖直中心（`oneXDisplayCenterY`）之上 `centeredUnitBottomInset`——避开同一锚点上的
/// 中央状态指示（「已标记 · 撤销」胶囊）。整层不设命中形状——除 × 钮外都穿透。
struct S2InlineHintLayer: View {
    let hint: S2InlineHint
    let mergedCount: Int
    let viewportSize: CGSize
    let photoCenterY: CGFloat
    /// 顶排下缘距视口上缘（安全区顶 + `S2OverlayLayout.topBarHeight`），由调用方算好传入。
    let topInset: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if let direction = hint.gestureDirection {
                S2InlineHintGestureView(direction: direction)
                    // 按方向重建整个示意（连同它的 `@State`）：第 1 → 2 句是同步换句，示意的位置与身份都不变，
                    // 只有在调用点换身份才能让循环动画从头以新方向跑（IC-114 B2 教训）。
                    .id(direction)
                    .frame(
                        width: viewportSize.width,
                        // 下滑示意循环向下位移 `gestureTravel`，避让量再加上它，示意的下半程也不扫进胶囊。
                        height: max(
                            0,
                            photoCenterY - S2InlineHintMetrics.centeredUnitBottomInset -
                                (direction == .down ? S2InlineHintMetrics.gestureTravel : 0)
                        ),
                        alignment: .bottom
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            VStack(alignment: .trailing, spacing: -S2InlineHintMetrics.pointerOverlap) {
                if hint.pointsAtConfirmEntry {
                    RoundedRectangle(
                        cornerRadius: S2InlineHintMetrics.pointerCornerRadius,
                        style: .continuous
                    )
                    .fill(S0DeckMetrics.text)
                    .frame(
                        width: S2InlineHintMetrics.pointerSide,
                        height: S2InlineHintMetrics.pointerSide
                    )
                    .rotationEffect(.degrees(45))
                    .padding(.trailing, S2InlineHintMetrics.pointerTrailingInset)
                    .allowsHitTesting(false)
                }
                S2InlineHintBubble(
                    hint: hint,
                    mergedCount: mergedCount,
                    onDismiss: onDismiss
                )
                .frame(
                    maxWidth: S2InlineHintMetrics.trailingMaxWidth,
                    alignment: .trailing
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topTrailing
            )
            .padding(.top, topInset + S2InlineHintMetrics.topBarGap)
            .padding(.trailing, S2InlineHintMetrics.trailingMargin)
        }
    }
}

/// IC-182：第 1／2 句的循环手势示意（R2 画布 `hint_gesture()`）——上滑：箭头在手之上；下滑：箭头在手之下；
/// 手在暖白半透明圆里、圆外一圈光晕环；整体沿方向循环平移 `gestureTravel` 并淡出；调用点按方向 `.id`
/// 重建（IC-114 B2 教训：跨方向复用实例会带着安装时的动画跑）。白照片上靠一层黑影可辨（IC-113 C）。
/// 不吃点击、不进读屏。旧教程的 `S2TutorialGestureHint` 原样保留（六步教程停用不删）。
struct S2InlineHintGestureView: View {
    let direction: S2TutorialGestureDirection

    @State private var looping = false

    var body: some View {
        VStack(spacing: S2InlineHintMetrics.gestureSpacing) {
            if direction == .up {
                arrow
            }
            hand
            if direction != .up {
                arrow
            }
        }
        .foregroundStyle(S0DeckMetrics.text)
        .shadow(
            color: Color.black.opacity(S2InlineHintMetrics.gestureShadowOpacity),
            radius: S2InlineHintMetrics.gestureShadowRadius,
            x: 0,
            y: 1
        )
        .offset(x: looping ? travelOffset.width : 0, y: looping ? travelOffset.height : 0)
        .opacity(looping ? 0 : 1)
        .onAppear {
            withAnimation(
                .linear(duration: S2InlineHintMetrics.gestureCycleSeconds)
                    .repeatForever(autoreverses: false)
            ) {
                looping = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var travelOffset: CGSize {
        switch direction {
        case .up:
            return CGSize(width: 0, height: -S2InlineHintMetrics.gestureTravel)
        case .down:
            return CGSize(width: 0, height: S2InlineHintMetrics.gestureTravel)
        case .right:
            return CGSize(width: S2InlineHintMetrics.gestureTravel, height: 0)
        }
    }

    private var arrowSymbolName: String {
        switch direction {
        case .up:
            return S2InlineHintSymbol.swipeUp
        case .down:
            return S2InlineHintSymbol.gestureArrowDown
        case .right:
            return S2InlineHintSymbol.gestureArrowRight
        }
    }

    private var arrow: some View {
        Image(systemName: arrowSymbolName)
            .font(.system(
                size: S2InlineHintMetrics.gestureArrowPointSize,
                weight: .bold
            ))
    }

    private var hand: some View {
        Image(systemName: S2InlineHintSymbol.gestureHand)
            .font(.system(
                size: S2InlineHintMetrics.gestureHandPointSize,
                weight: .medium
            ))
            .frame(
                width: S2InlineHintMetrics.gestureCircleSide,
                height: S2InlineHintMetrics.gestureCircleSide
            )
            .background {
                Circle()
                    .strokeBorder(
                        S0DeckMetrics.text.opacity(S2InlineHintMetrics.gestureHaloOpacity),
                        lineWidth: S2InlineHintMetrics.gestureHaloWidth
                    )
                    .padding(-S2InlineHintMetrics.gestureHaloWidth)
            }
            .background(
                S0DeckMetrics.text.opacity(S2InlineHintMetrics.gestureCircleFillOpacity),
                in: Circle()
            )
    }
}
