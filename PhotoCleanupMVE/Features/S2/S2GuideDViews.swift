import SwiftUI

// MARK: - IC-196：S2 教学引导 D 的界面层（SPEC-S2 v24 第二节第 6 部分 K1～K8、第十一节第 2 部分「教学引导 D 登记」）
//
// 本文件只有登记值、符号、纯几何与运动函数和视图，**不接线**：`S2View` 仍挂 v23 三句就地提示（`S2InlineHints.swift`），
// 接线与三句退役归下一张卡。步骤、六个标志与出现／收起规则在 `S2GuideD.swift`（IC-195）。
// 取值出处 R3 画布 `Tasks/design-r3/gen.py`（`coach_card()`／`gesture_disc()`／`dots()`／`d_frame()`／`d_done()`／
// `done_toast()`，`BASE_CSS` 的 `.solid`／`.btnt`／`.dots`）；CSS px 即 pt，阴影 blur 直接用作半径。
// 色一律引 `S0DeckMetrics`（`background`／`cardBase`／`text`／`mint`）；画布里不在色板中的白与黑照录。

/// SF Symbol 名登记（规格「教学引导 D 登记」符号段；画布只给线条图标，名字由决策会话取定，CI 宿主核非空）。
enum S2GuideDSymbol {
    /// 第 1 步圆底符号、上滑示范的箭头。
    static let guideStep1Symbol = "arrow.up"
    /// 第 2 步圆底符号、下滑示范的箭头。
    static let guideStep2Symbol = "arrow.down"
    /// 第 3 步圆底符号、左右滑示范的箭头。
    static let guideStep3Symbol = "arrow.left.and.right"
    /// 第 4 步圆底符号。
    static let guideStep4Symbol = "trash"
    /// 第 2、4 步标题前置勾；完成提示的勾圆。
    static let leadCheck = "checkmark"
    /// 第 3 步标题前置撤回符号。
    static let leadUndo = "arrow.uturn.backward"
    /// 手势示范的手（沿 v23 `S2InlineHintSymbol.gestureHand`；画布为张开的手，观感随 D 实装再看）。
    static let guideHand = "hand.point.up.left"
}

/// 登记值（不进 `S2CalibrationConfiguration`、不上标定面板，`schemaVersion` 不动）。名字照规格；规格注释里的数各登一名。
/// 第 4 步阈值与完成提示秒数不在这里重复：分别是 `S2GuideCoordinator.confirmThreshold`／`.completionAutoDismissSeconds`。
/// 画布线宽（2／2.6／2.8／3）在 SF Symbol 上映射为字重：手 `.medium`，其余 `.bold`（③）。
enum S2GuideDMetrics {
    // MARK: 教练卡

    /// 上缘距顶排下缘（顶排下缘 = 安全区顶 + `S2OverlayLayout.topBarHeight`）；画布 D_TOP 164 − 顶排下缘 102。
    static let coachTopFromChromeBottom: CGFloat = 62
    static let coachHorizontalInset: CGFloat = 16
    static let coachCardHeight: CGFloat = 108
    static let coachCornerRadius: CGFloat = 28
    static let coachPaddingTop: CGFloat = 14
    static let coachPaddingTrailing: CGFloat = 16
    static let coachPaddingBottom: CGFloat = 14
    static let coachPaddingLeading: CGFloat = 14
    /// 顶行（步骤指示 + 跳过）与主行之间。
    static let coachRowSpacing: CGFloat = 10
    /// `.solid` 两道内描边的线宽：上缘高光白 × 0.16、外圈白 × 0.10。
    static let coachEdgeWidth: CGFloat = 0.5
    static let coachEdgeHighlightOpacity: Double = 0.16
    static let coachEdgeRingOpacity: Double = 0.10
    /// `.solid` 投影 `0 16px 40px rgba(0,0,0,0.55)`。
    static let coachShadowYOffset: CGFloat = 16
    static let coachShadowRadius: CGFloat = 40
    static let coachShadowOpacity: Double = 0.55

    // MARK: 顶行

    static let stepRowHeight: CGFloat = 16
    static let stepDotSide: CGFloat = 6
    static let stepDotCornerRadius: CGFloat = stepDotSide / 2
    static let stepDotSpacing: CGFloat = 5
    static let stepDotCurrentWidth: CGFloat = 18
    /// 未到的步 = 前景 × 0.28；已会的步 = 薄荷 × 0.55；当前步 = 薄荷。
    static let stepDotPendingOpacity: Double = 0.28
    static let stepDotLearnedOpacity: Double = 0.55
    /// 「跳过教程」：可见高 28、无底、前景 × 0.62、600 字重、水平留白 4；命中区扩到 44（布局仍按可见高）。
    static let skipButtonHeight: CGFloat = 28
    static let skipFontSize: CGFloat = 13
    static let skipForegroundOpacity: Double = 0.62
    static let skipHorizontalPadding: CGFloat = 4
    static let skipTouchTargetSide: CGFloat = S2OverlayLayout.minimumTouchTarget
    static let skipTouchOverhang: CGFloat = (skipTouchTargetSide - skipButtonHeight) / 2

    // MARK: 主行

    /// 薄荷圆底，本步符号取页面底色。
    static let coachGlyphCircleSide: CGFloat = 52
    static let coachGlyphPointSize: CGFloat = 26
    static let coachMainRowSpacing: CGFloat = 14
    /// 标题 800 字重、单行。
    static let coachTitleFontSize: CGFloat = 18
    /// 标题前置勾／撤回符号，薄荷。
    static let coachTitleLeadPointSize: CGFloat = 18
    static let coachTitleLeadSpacing: CGFloat = 6
    /// 副句前景 × 0.66、行高 18（单行）。
    static let coachSubtitleFontSize: CGFloat = 13.5
    static let coachSubtitleLineHeight: CGFloat = 18
    static let coachSubtitleTopSpacing: CGFloat = 3
    /// 画布 `.dim`：教练卡副句与完成提示副句同取前景 × 0.66。
    static let secondaryTextOpacity: Double = 0.66

    // MARK: 第 4 步指向

    /// 小三角：卡底色方块转 45°、圆角 3，左上缘高光白 × 0.16（`coachEdgeHighlightOpacity`）；中心对准确认入口圆钮中心、上半露出卡外。
    static let coachPointerSide: CGFloat = 14
    static let coachPointerCornerRadius: CGFloat = 3
    static let coachPointerRotationDegrees: Double = 45
    /// 确认入口圆钮下缘 → 小三角的薄荷虚线：线宽 2.5、距圆钮下缘 8、长 48。
    static let coachPointerLineWidth: CGFloat = 2.5
    static let confirmDashGapFromButton: CGFloat = 8
    static let confirmDashLength: CGFloat = 48
    /// 画布 CSS `dashed` 不给段长：段 6、隙 4（③，进人工判定）。
    static let confirmDashSegment: CGFloat = 6
    static let confirmDashSpace: CGFloat = 4
    /// 确认入口外两圈高亮（自圆钮外缘起）：内圈宽 5 薄荷 × 0.55、外圈宽 12 薄荷 × 0.18。
    static let confirmHaloInnerWidth: CGFloat = 5
    static let confirmHaloInnerOpacity: Double = 0.55
    static let confirmHaloOuterWidth: CGFloat = 12
    static let confirmHaloOuterOpacity: Double = 0.18

    // MARK: 进门压暗

    /// 页面底色 × 0.42。
    static let introScrimOpacity: Double = 0.42

    // MARK: 中央手势示范（第 1～3 步）

    static let gestureDiscSideStep1: CGFloat = 72
    static let gestureDiscSide: CGFloat = 60
    /// 圆底页面底色 × 0.82；圆外贴边一圈前景 × 0.35（宽 1.5）、再外一圈页面底色 × 0.28（宽 10）。
    static let gestureDiscFillOpacity: Double = 0.82
    static let gestureDiscRingWidth: CGFloat = 1.5
    static let gestureDiscRingOpacity: Double = 0.35
    static let gestureDiscHaloWidth: CGFloat = 10
    static let gestureDiscHaloOpacity: Double = 0.28
    /// 投影 `0 10px 30px rgba(0,0,0,0.5)`。
    static let gestureDiscShadowYOffset: CGFloat = 10
    static let gestureDiscShadowRadius: CGFloat = 30
    static let gestureDiscShadowOpacity: Double = 0.50
    /// 手（前景主色）= 圆径 × 0.5。
    static let gestureHandScale: CGFloat = 0.5
    /// 箭头圆：薄荷圆底、页面底色箭头；投影 `0 4px 14px rgba(0,0,0,0.45)`。
    static let gestureArrowCircleSide: CGFloat = 34
    static let gestureArrowShadowYOffset: CGFloat = 4
    static let gestureArrowShadowRadius: CGFloat = 14
    static let gestureArrowShadowOpacity: Double = 0.45
    static let gestureDiscArrowPointSize: CGFloat = 20
    /// 箭头圆**远缘**距手势圆缘：上滑在上、下滑在下 40；左右滑在上 36。
    static let gestureArrowOffset: CGFloat = 40
    static let gestureArrowOffsetHorizontal: CGFloat = 36
    /// 上下滑拖尾：宽 4、长 40、距手势圆缘 2；薄荷 0.95 → 0 渐变（近圆一端浓）、圆角 = 半宽；外描 1.5 页面底色 × 0.45。左右滑无拖尾。
    static let gestureTrailWidth: CGFloat = 4
    static let gestureTrailLength: CGFloat = 40
    static let gestureTrailGap: CGFloat = 2
    static let gestureTrailStartOpacity: Double = 0.95
    static let gestureTrailOutlineWidth: CGFloat = 1.5
    static let gestureTrailOutlineOpacity: Double = 0.45

    // MARK: 完成提示（只有标题，④ 第 223 条；副句随 IC-181 加回）

    /// 与教练卡同区、上缘再下 14；横向居中。卡底、内描边与投影同教练卡。
    static let doneTopFromCoachTop: CGFloat = 14
    static let doneCornerRadius: CGFloat = 24
    static let doneHorizontalPadding: CGFloat = 20
    static let doneVerticalPadding: CGFloat = 16
    static let doneSpacing: CGFloat = 12
    /// 薄荷圆底、页面底色勾。
    static let doneCheckCircleSide: CGFloat = 40
    static let doneCheckPointSize: CGFloat = 24
    /// 800 字重。
    static let doneTitleFontSize: CGFloat = 17

    // MARK: 沿 v23 的值

    /// 中央状态指示避让线距主图显示帧竖直中心（= `S2InlineHintMetrics.centeredUnitBottomInset`）；v24 只作参照，示范可越过。
    static let gestureUnitBottomInset: CGFloat = 39
    /// 示范循环位移与周期（= `S2InlineHintMetrics.gestureTravel`／`.gestureCycleSeconds`）。
    static let guideGestureTravel: CGFloat = 40
    static let guideGestureCycleSeconds: TimeInterval = 0.9
    /// 出现、消失与换步的淡入淡出（= `S2InlineHintMetrics.transitionSeconds`）。
    static let guideTransitionSeconds: TimeInterval = 0.2
}

/// 中央手势示范的方向：第 1 步上滑、第 2 步下滑、第 3 步左右滑；第 4 步没有示范。
enum S2GuideGestureDirection: Equatable {
    case up
    case down
    case leftRight
}

/// 示范在某一时刻相对静止位的位移与不透明度。
struct S2GuideGestureMotion: Equatable {
    let offset: CGSize
    let opacity: Double
}

// MARK: - 步骤的文案与符号

extension S2GuideStep {
    /// 第几步（1～4），四点指示的读屏用。
    var ordinal: Int {
        (S2GuideStep.allCases.firstIndex(of: self) ?? 0) + 1
    }

    /// 教练卡标题。每个分支整句取文案、不拼 key；第 4 步带张数（确认入口徽标的显示值）。
    func title(mergedCount: Int) -> String {
        switch self {
        case .swipeUp:
            return L10n.text("s2.guide.swipe_up")
        case .markedOnce:
            return L10n.text("s2.guide.marked")
        case .undone:
            return L10n.text("s2.guide.undone")
        case .confirmEntry:
            return L10n.text(
                "s2.guide.confirm",
                replacing: ["count": String(mergedCount)]
            )
        }
    }

    /// 教练卡副句。
    var subtitle: String {
        switch self {
        case .swipeUp:
            return L10n.text("s2.guide.swipe_up.sub")
        case .markedOnce:
            return L10n.text("s2.guide.marked.sub")
        case .undone:
            return L10n.text("s2.guide.undone.sub")
        case .confirmEntry:
            return L10n.text("s2.guide.confirm.sub")
        }
    }

    /// 主行薄荷圆底里的本步符号。
    var glyphSymbolName: String {
        switch self {
        case .swipeUp:
            return S2GuideDSymbol.guideStep1Symbol
        case .markedOnce:
            return S2GuideDSymbol.guideStep2Symbol
        case .undone:
            return S2GuideDSymbol.guideStep3Symbol
        case .confirmEntry:
            return S2GuideDSymbol.guideStep4Symbol
        }
    }

    /// 标题前置符号：第 2、4 步勾，第 3 步撤回；第 1 步没有。
    var leadSymbolName: String? {
        switch self {
        case .swipeUp:
            return nil
        case .markedOnce, .confirmEntry:
            return S2GuideDSymbol.leadCheck
        case .undone:
            return S2GuideDSymbol.leadUndo
        }
    }
}

// MARK: - 纯几何与运动

/// 落位与运动的纯函数（视口坐标），视图与测试共用。
enum S2GuideDLayout {
    /// 教练卡上缘：顶排下缘 + 62。不随当前照片的显示帧移动（K1）。
    static func coachTop(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + S2OverlayLayout.topBarHeight +
            S2GuideDMetrics.coachTopFromChromeBottom
    }

    static func coachBottom(safeAreaTop: CGFloat) -> CGFloat {
        coachTop(safeAreaTop: safeAreaTop) + S2GuideDMetrics.coachCardHeight
    }

    /// 卡宽 = 视口宽 − 左右各 16。
    static func coachWidth(viewportWidth: CGFloat) -> CGFloat {
        max(0, viewportWidth - S2GuideDMetrics.coachHorizontalInset * 2)
    }

    /// 完成提示上缘 = 教练卡上缘 + 14（K5）。
    static func doneTop(safeAreaTop: CGFloat) -> CGFloat {
        coachTop(safeAreaTop: safeAreaTop) + S2GuideDMetrics.doneTopFromCoachTop
    }

    /// 确认入口圆钮中心：与 chrome 渲染、标记残影落点共用 `S2OverlayLayout.topElementFrames`。
    static func confirmEntryCenter(
        viewportSize: CGSize,
        safeAreaTop: CGFloat
    ) -> CGPoint {
        S2MarkAfterimageFlight.trashCenter(
            viewportSize: viewportSize,
            safeAreaTop: safeAreaTop
        )
    }

    /// 小三角中心：横向对准确认入口圆钮中心，竖向在教练卡上缘（上半露出卡外，K2）。
    static func pointerCenter(
        viewportSize: CGSize,
        safeAreaTop: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: confirmEntryCenter(
                viewportSize: viewportSize,
                safeAreaTop: safeAreaTop
            ).x,
            y: coachTop(safeAreaTop: safeAreaTop)
        )
    }

    /// 虚线上端：确认入口圆钮下缘 + 8（圆钮直径 = chrome 行高）。
    static func dashTop(viewportSize: CGSize, safeAreaTop: CGFloat) -> CGFloat {
        confirmEntryCenter(viewportSize: viewportSize, safeAreaTop: safeAreaTop).y +
            S2OverlayLayout.chromeRowHeight / 2 +
            S2GuideDMetrics.confirmDashGapFromButton
    }

    /// 确认入口两圈高亮的外径（圆钮直径 + 两侧各一圈宽）。
    static func haloDiameter(ringWidth: CGFloat) -> CGFloat {
        S2OverlayLayout.chromeRowHeight + ringWidth * 2
    }

    /// 进门压暗的框（K4、计划裁定 4）：顶排下缘到横栏**视觉**顶缘的整条带，横向铺满；不随当前照片的显示帧移动。
    /// 横栏顶缘取 `stripBottomFromViewportBottom + bottomStripHeight`，不取含触控下限的 `stripTopFromViewportBottom`（陷阱 14）。
    static func introScrimFrame(
        viewportSize: CGSize,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        bottomStripHeight: CGFloat
    ) -> CGRect {
        let top = safeAreaTop + S2OverlayLayout.topBarHeight
        let stripTop = viewportSize.height -
            S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: safeAreaBottom
            ) - bottomStripHeight
        return CGRect(
            x: 0,
            y: top,
            width: viewportSize.width,
            height: max(0, stripTop - top)
        )
    }

    /// 中央状态指示避让线（主图显示帧竖直中心之上 39）。v24 只作参照：示范可越过（K3、未定项 38），只用于几何打印。
    static func indicatorAvoidanceLineY(photoCenterY: CGFloat) -> CGFloat {
        photoCenterY - S2GuideDMetrics.gestureUnitBottomInset
    }

    static func gestureDirection(for step: S2GuideStep) -> S2GuideGestureDirection? {
        switch step {
        case .swipeUp:
            return .up
        case .markedOnce:
            return .down
        case .undone:
            return .leftRight
        case .confirmEntry:
            return nil
        }
    }

    /// 第 1 步 72，第 2、3 步 60。
    static func gestureDiscSide(for step: S2GuideStep) -> CGFloat {
        step == .swipeUp ?
            S2GuideDMetrics.gestureDiscSideStep1 : S2GuideDMetrics.gestureDiscSide
    }

    /// 箭头圆中心相对手势圆心的竖直偏移：上滑与左右滑在上（负），下滑在下（正）。
    static func gestureArrowCenterOffsetY(
        direction: S2GuideGestureDirection,
        discSide: CGFloat
    ) -> CGFloat {
        let halfArrow = S2GuideDMetrics.gestureArrowCircleSide / 2
        switch direction {
        case .up:
            return -(discSide / 2 + S2GuideDMetrics.gestureArrowOffset - halfArrow)
        case .down:
            return discSide / 2 + S2GuideDMetrics.gestureArrowOffset - halfArrow
        case .leftRight:
            return -(discSide / 2 + S2GuideDMetrics.gestureArrowOffsetHorizontal - halfArrow)
        }
    }

    /// 拖尾中心相对手势圆心的竖直偏移：上滑拖在下（正），下滑拖在上（负）；左右滑无拖尾（nil）。
    static func gestureTrailCenterOffsetY(
        direction: S2GuideGestureDirection,
        discSide: CGFloat
    ) -> CGFloat? {
        let distance = discSide / 2 + S2GuideDMetrics.gestureTrailGap +
            S2GuideDMetrics.gestureTrailLength / 2
        switch direction {
        case .up:
            return distance
        case .down:
            return -distance
        case .leftRight:
            return nil
        }
    }

    /// 单元在运动全程中高出圆心的最大量：上滑 = 半径 + 箭头远缘 40 + 位移 40；下滑 = 半径 + 拖尾间距 2 + 拖尾 40
    /// （向下走、不再往上）；左右滑 = 半径 + 36。圆外两圈（≤ 10）都在这几项之内。
    static func gestureReachAboveCenter(
        direction: S2GuideGestureDirection,
        discSide: CGFloat
    ) -> CGFloat {
        switch direction {
        case .up:
            return discSide / 2 + S2GuideDMetrics.gestureArrowOffset +
                S2GuideDMetrics.guideGestureTravel
        case .down:
            return discSide / 2 + S2GuideDMetrics.gestureTrailGap +
                S2GuideDMetrics.gestureTrailLength
        case .leftRight:
            return discSide / 2 + S2GuideDMetrics.gestureArrowOffsetHorizontal
        }
    }

    /// 手势圆心的竖直位置（K3）：在主图显示帧竖直中心；运动中任何一帧压到教练卡时整体下移到恰好不压。
    static func gestureDiscCenterY(
        direction: S2GuideGestureDirection,
        discSide: CGFloat,
        photoCenterY: CGFloat,
        safeAreaTop: CGFloat
    ) -> CGFloat {
        max(
            photoCenterY,
            coachBottom(safeAreaTop: safeAreaTop) +
                gestureReachAboveCenter(direction: direction, discSide: discSide)
        )
    }

    /// 循环运动（K3）：每周期 `guideGestureCycleSeconds` 内沿方向位移 0 → `guideGestureTravel`、不透明度 1 → 0；
    /// 左右滑偶数周期向右、奇数周期向左。`elapsed` 为负按 0。
    static func gestureMotion(
        direction: S2GuideGestureDirection,
        elapsed: TimeInterval
    ) -> S2GuideGestureMotion {
        let cycles = max(0, elapsed) / S2GuideDMetrics.guideGestureCycleSeconds
        let completed = cycles.rounded(.down)
        let progress = cycles - completed
        let distance = S2GuideDMetrics.guideGestureTravel * CGFloat(progress)
        let offset: CGSize
        switch direction {
        case .up:
            offset = CGSize(width: 0, height: -distance)
        case .down:
            offset = CGSize(width: 0, height: distance)
        case .leftRight:
            let isEvenCycle = Int(completed) % 2 == 0
            offset = CGSize(width: isEvenCycle ? distance : -distance, height: 0)
        }
        return S2GuideGestureMotion(offset: offset, opacity: 1 - progress)
    }
}

// MARK: - 视图

/// 教练卡与完成卡共用的深色实底（画布 `.solid`）：卡底色、两道内描边、投影。不吃点击。
struct S2GuideDSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        shape
            .fill(S0DeckMetrics.cardBase)
            .overlay {
                shape.strokeBorder(
                    Color.white.opacity(S2GuideDMetrics.coachEdgeRingOpacity),
                    lineWidth: S2GuideDMetrics.coachEdgeWidth
                )
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(S2GuideDMetrics.coachEdgeHighlightOpacity),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: S2GuideDMetrics.coachEdgeWidth
                )
            }
            .shadow(
                color: Color.black.opacity(S2GuideDMetrics.coachShadowOpacity),
                radius: S2GuideDMetrics.coachShadowRadius,
                x: 0,
                y: S2GuideDMetrics.coachShadowYOffset
            )
            .allowsHitTesting(false)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

/// 四点步骤指示：当前步拉长、薄荷；已会的步薄荷半透明；其余前景半透明。读屏念「第 N 步，共 4 步」。
struct S2GuideStepDots: View {
    let current: S2GuideStep
    let learnedSteps: Set<S2GuideStep>

    var body: some View {
        HStack(spacing: S2GuideDMetrics.stepDotSpacing) {
            ForEach(S2GuideStep.allCases, id: \.self) { step in
                RoundedRectangle(
                    cornerRadius: S2GuideDMetrics.stepDotCornerRadius,
                    style: .continuous
                )
                .fill(color(for: step))
                .frame(
                    width: step == current ?
                        S2GuideDMetrics.stepDotCurrentWidth : S2GuideDMetrics.stepDotSide,
                    height: S2GuideDMetrics.stepDotSide
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.text(
                "s2.guide.progress",
                replacing: [
                    "current": String(current.ordinal),
                    "total": String(S2GuideStep.allCases.count)
                ]
            )
        )
    }

    private func color(for step: S2GuideStep) -> Color {
        if step == current {
            return S0DeckMetrics.mint
        }
        if learnedSteps.contains(step) {
            return S0DeckMetrics.mint.opacity(S2GuideDMetrics.stepDotLearnedOpacity)
        }
        return S0DeckMetrics.text.opacity(S2GuideDMetrics.stepDotPendingOpacity)
    }
}

/// 「跳过教程」：引导里唯一吃点击的控件（K6）。可见高 28，命中区 44，布局仍按可见高占位。
struct S2GuideSkipButton: View {
    let onSkip: () -> Void

    var body: some View {
        Button {
            onSkip()
        } label: {
            Text(L10n.text("s2.guide.skip"))
                .font(.system(size: S2GuideDMetrics.skipFontSize, weight: .semibold))
                .foregroundStyle(
                    S0DeckMetrics.text.opacity(S2GuideDMetrics.skipForegroundOpacity)
                )
                .lineLimit(1)
                .padding(.horizontal, S2GuideDMetrics.skipHorizontalPadding)
                .frame(height: S2GuideDMetrics.skipButtonHeight)
                .frame(
                    minWidth: S2GuideDMetrics.skipTouchTargetSide,
                    minHeight: S2GuideDMetrics.skipTouchTargetSide
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 命中区 44 而布局仍按可见的 28 占位：负内距把多出的部分收回（同 v23 × 钮的做法）。
        .padding(.vertical, -S2GuideDMetrics.skipTouchOverhang)
    }
}

/// 教练卡（K1）：顶行四点指示 + 「跳过教程」，主行薄荷圆底符号 + 标题（前置符号）与副句。只有跳过钮吃点击。
struct S2GuideCoachCard: View {
    let step: S2GuideStep
    let mergedCount: Int
    let learnedSteps: Set<S2GuideStep>
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: S2GuideDMetrics.coachRowSpacing) {
            HStack(spacing: 0) {
                S2GuideStepDots(current: step, learnedSteps: learnedSteps)
                Spacer(minLength: 0)
                S2GuideSkipButton(onSkip: onSkip)
            }
            .frame(height: S2GuideDMetrics.stepRowHeight)
            HStack(spacing: S2GuideDMetrics.coachMainRowSpacing) {
                glyph
                VStack(
                    alignment: .leading,
                    spacing: S2GuideDMetrics.coachSubtitleTopSpacing
                ) {
                    titleRow
                    Text(step.subtitle)
                        .font(.system(size: S2GuideDMetrics.coachSubtitleFontSize))
                        .foregroundStyle(
                            S0DeckMetrics.text.opacity(S2GuideDMetrics.secondaryTextOpacity)
                        )
                        .lineLimit(1)
                        .frame(height: S2GuideDMetrics.coachSubtitleLineHeight)
                }
                .accessibilityElement(children: .combine)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(
            EdgeInsets(
                top: S2GuideDMetrics.coachPaddingTop,
                leading: S2GuideDMetrics.coachPaddingLeading,
                bottom: S2GuideDMetrics.coachPaddingBottom,
                trailing: S2GuideDMetrics.coachPaddingTrailing
            )
        )
        .frame(height: S2GuideDMetrics.coachCardHeight)
        .background {
            S2GuideDSurface(cornerRadius: S2GuideDMetrics.coachCornerRadius)
        }
    }

    private var glyph: some View {
        Image(systemName: step.glyphSymbolName)
            .font(.system(size: S2GuideDMetrics.coachGlyphPointSize, weight: .bold))
            .foregroundStyle(S0DeckMetrics.background)
            .frame(
                width: S2GuideDMetrics.coachGlyphCircleSide,
                height: S2GuideDMetrics.coachGlyphCircleSide
            )
            .background(S0DeckMetrics.mint, in: Circle())
            .accessibilityHidden(true)
    }

    private var titleRow: some View {
        HStack(spacing: S2GuideDMetrics.coachTitleLeadSpacing) {
            if let leadSymbolName = step.leadSymbolName {
                Image(systemName: leadSymbolName)
                    .font(.system(
                        size: S2GuideDMetrics.coachTitleLeadPointSize,
                        weight: .bold
                    ))
                    .foregroundStyle(S0DeckMetrics.mint)
                    .accessibilityHidden(true)
            }
            Text(step.title(mergedCount: mergedCount))
                .font(.system(size: S2GuideDMetrics.coachTitleFontSize, weight: .heavy))
                .foregroundStyle(S0DeckMetrics.text)
                .lineLimit(1)
        }
    }
}

/// 第 4 步卡片上缘的小三角（K2）：卡底色方块转 45°，先垫一层向左上错开半线宽的白 × 0.16 作上缘高光。
struct S2GuideCoachPointer: View {
    var body: some View {
        ZStack {
            shape
                .fill(Color.white.opacity(S2GuideDMetrics.coachEdgeHighlightOpacity))
                .offset(
                    x: -S2GuideDMetrics.coachEdgeWidth,
                    y: -S2GuideDMetrics.coachEdgeWidth
                )
            shape
                .fill(S0DeckMetrics.cardBase)
        }
        .frame(
            width: S2GuideDMetrics.coachPointerSide,
            height: S2GuideDMetrics.coachPointerSide
        )
        .rotationEffect(.degrees(S2GuideDMetrics.coachPointerRotationDegrees))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: S2GuideDMetrics.coachPointerCornerRadius,
            style: .continuous
        )
    }
}

/// 第 4 步：确认入口外两圈薄荷高亮 + 圆钮下缘到小三角的薄荷虚线（K2）。全屏框、视口坐标；不吃点击。
struct S2GuideConfirmHighlight: View {
    let viewportSize: CGSize
    let safeAreaTop: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .strokeBorder(
                    S0DeckMetrics.mint.opacity(S2GuideDMetrics.confirmHaloOuterOpacity),
                    lineWidth: S2GuideDMetrics.confirmHaloOuterWidth
                )
                .frame(width: outerDiameter, height: outerDiameter)
                .position(center)
            Circle()
                .strokeBorder(
                    S0DeckMetrics.mint.opacity(S2GuideDMetrics.confirmHaloInnerOpacity),
                    lineWidth: S2GuideDMetrics.confirmHaloInnerWidth
                )
                .frame(width: innerDiameter, height: innerDiameter)
                .position(center)
            Path { path in
                path.move(to: CGPoint(x: center.x, y: dashTop))
                path.addLine(
                    to: CGPoint(x: center.x, y: dashTop + S2GuideDMetrics.confirmDashLength)
                )
            }
            .stroke(
                S0DeckMetrics.mint,
                style: StrokeStyle(
                    lineWidth: S2GuideDMetrics.coachPointerLineWidth,
                    dash: [
                        S2GuideDMetrics.confirmDashSegment,
                        S2GuideDMetrics.confirmDashSpace
                    ]
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var center: CGPoint {
        S2GuideDLayout.confirmEntryCenter(viewportSize: viewportSize, safeAreaTop: safeAreaTop)
    }

    private var dashTop: CGFloat {
        S2GuideDLayout.dashTop(viewportSize: viewportSize, safeAreaTop: safeAreaTop)
    }

    private var outerDiameter: CGFloat {
        S2GuideDLayout.haloDiameter(ringWidth: S2GuideDMetrics.confirmHaloOuterWidth)
    }

    private var innerDiameter: CGFloat {
        S2GuideDLayout.haloDiameter(ringWidth: S2GuideDMetrics.confirmHaloInnerWidth)
    }
}

/// 完成提示（K5）：勾圆 + 「都学会了」，教练卡同区内横向居中；不吃点击。
struct S2GuideCompletionCard: View {
    var body: some View {
        HStack(spacing: S2GuideDMetrics.doneSpacing) {
            Image(systemName: S2GuideDSymbol.leadCheck)
                .font(.system(size: S2GuideDMetrics.doneCheckPointSize, weight: .bold))
                .foregroundStyle(S0DeckMetrics.background)
                .frame(
                    width: S2GuideDMetrics.doneCheckCircleSide,
                    height: S2GuideDMetrics.doneCheckCircleSide
                )
                .background(S0DeckMetrics.mint, in: Circle())
                .accessibilityHidden(true)
            Text(L10n.text("s2.guide.completed"))
                .font(.system(size: S2GuideDMetrics.doneTitleFontSize, weight: .heavy))
                .foregroundStyle(S0DeckMetrics.text)
                .lineLimit(1)
        }
        .padding(.horizontal, S2GuideDMetrics.doneHorizontalPadding)
        .padding(.vertical, S2GuideDMetrics.doneVerticalPadding)
        .fixedSize()
        .background {
            S2GuideDSurface(cornerRadius: S2GuideDMetrics.doneCornerRadius)
        }
        .allowsHitTesting(false)
    }
}

/// 中央手势示范（K3）：深色实心圆 + 白手 + 薄荷箭头圆，上下滑另有薄荷拖尾；整体按 `gestureMotion` 循环平移并淡出。
/// 调用点按步 `.id`（陷阱 17：换步从头循环）。不吃点击、不进读屏。
struct S2GuideGestureDemo: View {
    let direction: S2GuideGestureDirection
    let discSide: CGFloat

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { context in
            motionFrame(at: context.date)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func motionFrame(at date: Date) -> some View {
        let motion = S2GuideDLayout.gestureMotion(
            direction: direction,
            elapsed: date.timeIntervalSince(startDate)
        )
        return unit
            .offset(motion.offset)
            .opacity(motion.opacity)
    }

    private var unit: some View {
        ZStack {
            trail
            disc
            arrowCircle
        }
    }

    private var disc: some View {
        Image(systemName: S2GuideDSymbol.guideHand)
            .font(.system(
                size: discSide * S2GuideDMetrics.gestureHandScale,
                weight: .medium
            ))
            .foregroundStyle(S0DeckMetrics.text)
            .frame(width: discSide, height: discSide)
            .background(
                S0DeckMetrics.background.opacity(S2GuideDMetrics.gestureDiscFillOpacity),
                in: Circle()
            )
            .background {
                Circle()
                    .strokeBorder(
                        S0DeckMetrics.background.opacity(S2GuideDMetrics.gestureDiscHaloOpacity),
                        lineWidth: S2GuideDMetrics.gestureDiscHaloWidth
                    )
                    .padding(-S2GuideDMetrics.gestureDiscHaloWidth)
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        S0DeckMetrics.text.opacity(S2GuideDMetrics.gestureDiscRingOpacity),
                        lineWidth: S2GuideDMetrics.gestureDiscRingWidth
                    )
                    .padding(-S2GuideDMetrics.gestureDiscRingWidth)
            }
            .shadow(
                color: Color.black.opacity(S2GuideDMetrics.gestureDiscShadowOpacity),
                radius: S2GuideDMetrics.gestureDiscShadowRadius,
                x: 0,
                y: S2GuideDMetrics.gestureDiscShadowYOffset
            )
    }

    private var arrowSymbolName: String {
        switch direction {
        case .up:
            return S2GuideDSymbol.guideStep1Symbol
        case .down:
            return S2GuideDSymbol.guideStep2Symbol
        case .leftRight:
            return S2GuideDSymbol.guideStep3Symbol
        }
    }

    private var arrowCircle: some View {
        Image(systemName: arrowSymbolName)
            .font(.system(size: S2GuideDMetrics.gestureDiscArrowPointSize, weight: .bold))
            .foregroundStyle(S0DeckMetrics.background)
            .frame(
                width: S2GuideDMetrics.gestureArrowCircleSide,
                height: S2GuideDMetrics.gestureArrowCircleSide
            )
            .background(S0DeckMetrics.mint, in: Circle())
            .shadow(
                color: Color.black.opacity(S2GuideDMetrics.gestureArrowShadowOpacity),
                radius: S2GuideDMetrics.gestureArrowShadowRadius,
                x: 0,
                y: S2GuideDMetrics.gestureArrowShadowYOffset
            )
            .offset(
                y: S2GuideDLayout.gestureArrowCenterOffsetY(
                    direction: direction,
                    discSide: discSide
                )
            )
    }

    /// 拖尾渐变两端：浓的一端贴着手势圆——上滑拖在下、从上往下淡；下滑拖在上、从下往上淡。
    private var trailGradientStart: UnitPoint {
        direction == .up ? .top : .bottom
    }

    private var trailGradientEnd: UnitPoint {
        direction == .up ? .bottom : .top
    }

    @ViewBuilder
    private var trail: some View {
        if let offsetY = S2GuideDLayout.gestureTrailCenterOffsetY(
            direction: direction,
            discSide: discSide
        ) {
            RoundedRectangle(
                cornerRadius: S2GuideDMetrics.gestureTrailWidth / 2,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        S0DeckMetrics.mint.opacity(S2GuideDMetrics.gestureTrailStartOpacity),
                        S0DeckMetrics.mint.opacity(0)
                    ],
                    startPoint: trailGradientStart,
                    endPoint: trailGradientEnd
                )
            )
            .frame(
                width: S2GuideDMetrics.gestureTrailWidth,
                height: S2GuideDMetrics.gestureTrailLength
            )
            .background {
                RoundedRectangle(
                    cornerRadius: S2GuideDMetrics.gestureTrailWidth / 2 +
                        S2GuideDMetrics.gestureTrailOutlineWidth,
                    style: .continuous
                )
                .strokeBorder(
                    S0DeckMetrics.background.opacity(S2GuideDMetrics.gestureTrailOutlineOpacity),
                    lineWidth: S2GuideDMetrics.gestureTrailOutlineWidth
                )
                .padding(-S2GuideDMetrics.gestureTrailOutlineWidth)
            }
            .offset(y: offsetY)
        }
    }
}

/// 进门压暗（K4）：页面底色 × 0.42 铺在 `S2GuideDLayout.introScrimFrame` 的框里；不吃点击、不进读屏。
/// 在 `S2View` 里的层级（分页器之上、chrome 之下）与显隐由接线卡定。
struct S2GuideIntroScrim: View {
    let scrimFrame: CGRect

    var body: some View {
        S0DeckMetrics.background
            .opacity(S2GuideDMetrics.introScrimOpacity)
            .frame(width: scrimFrame.width, height: scrimFrame.height)
            .position(x: scrimFrame.midX, y: scrimFrame.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 卡层（K1、K2、K5～K8）：在显一步时画教练卡（第 4 步另加小三角、虚线与确认入口高亮），在显完成提示时画完成卡。
/// 全屏框左上对齐，换步与消失都在原位淡入淡出（K8：空容器原点钉在 (0, 0)，不随有无内容移动）。只有跳过钮吃点击。
struct S2GuideDCardLayer: View {
    let display: S2GuideDisplay?
    /// 确认入口徽标的显示值（残影落点才同步），第 4 步标题的张数。
    let mergedCount: Int
    let learnedSteps: Set<S2GuideStep>
    let viewportSize: CGSize
    let safeAreaTop: CGFloat
    let onSkip: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let step = currentStep {
                if step == .confirmEntry {
                    S2GuideConfirmHighlight(
                        viewportSize: viewportSize,
                        safeAreaTop: safeAreaTop
                    )
                    .transition(.opacity)
                }
                S2GuideCoachCard(
                    step: step,
                    mergedCount: mergedCount,
                    learnedSteps: learnedSteps,
                    onSkip: onSkip
                )
                .overlay(alignment: .topLeading) {
                    if step == .confirmEntry {
                        S2GuideCoachPointer()
                            .position(x: pointerX, y: 0)
                    }
                }
                .frame(width: S2GuideDLayout.coachWidth(viewportWidth: viewportSize.width))
                .padding(.top, S2GuideDLayout.coachTop(safeAreaTop: safeAreaTop))
                .padding(.leading, S2GuideDMetrics.coachHorizontalInset)
                .id(step)
                .transition(.opacity)
            } else if display == .completion {
                S2GuideCompletionCard()
                    .frame(width: viewportSize.width)
                    .padding(.top, S2GuideDLayout.doneTop(safeAreaTop: safeAreaTop))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(
            .easeOut(duration: S2GuideDMetrics.guideTransitionSeconds),
            value: display
        )
    }

    private var currentStep: S2GuideStep? {
        if case .step(let step)? = display {
            return step
        }
        return nil
    }

    /// 小三角中心在卡内的横坐标（卡左缘 = 视口左缘 + 16）。
    private var pointerX: CGFloat {
        S2GuideDLayout.pointerCenter(viewportSize: viewportSize, safeAreaTop: safeAreaTop).x -
            S2GuideDMetrics.coachHorizontalInset
    }
}

/// 手势示范层（K3）：第 1～3 步在显时画示范，横向居中、竖向按 `gestureDiscCenterY`；第 4 步与完成提示没有示范。
/// 全屏框左上对齐；不吃点击、不进读屏。与中央状态指示的层级由接线卡定（未定项 38）。
struct S2GuideDGestureLayer: View {
    let display: S2GuideDisplay?
    let viewportSize: CGSize
    let safeAreaTop: CGFloat
    /// 主图显示帧竖直中心（`S2ViewportMetrics.oneXDisplayCenterY`）。
    let photoCenterY: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let step = currentStep,
               let direction = S2GuideDLayout.gestureDirection(for: step) {
                S2GuideGestureDemo(
                    direction: direction,
                    discSide: S2GuideDLayout.gestureDiscSide(for: step)
                )
                .id(step)
                .position(
                    x: viewportSize.width / 2,
                    y: S2GuideDLayout.gestureDiscCenterY(
                        direction: direction,
                        discSide: S2GuideDLayout.gestureDiscSide(for: step),
                        photoCenterY: photoCenterY,
                        safeAreaTop: safeAreaTop
                    )
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(
            .easeOut(duration: S2GuideDMetrics.guideTransitionSeconds),
            value: display
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var currentStep: S2GuideStep? {
        if case .step(let step)? = display {
            return step
        }
        return nil
    }
}
