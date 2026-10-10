import SwiftUI

/// IC-200：恢复滚动位置用的锚点与坐标系名（字符串登记，不是视觉值）。
enum OffsetRestoringScrollMetrics {
    static let coordinateSpaceName = "offsetRestoringScroll"
    static let anchorID = "offsetRestoringScroll.anchor"
    static let anchorHeight: CGFloat = 1
}

/// IC-200（SPEC-S1 v12 `:220`／`:284`、SPEC-S0 v6 第十二节第 12 条；取定 `Tasks/PLAN-NAVR-scroll-restore-rulings-20261009.md`）：
/// 路由往返重建后回到原来滚动位置的 `ScrollView`。
///
/// 卡片叠靠 `.offset(y:)` 摆位，`.offset` 不改布局帧，`scrollTo(卡)` 定位不到卡——所以不按卡、按偏移恢复：
/// - 记录：内容背后一只 `GeometryReader` 读内容顶部在本容器坐标系里的 `minY`，换算成偏移写进 `memory`（类属性、不写 `@State`）。
/// - 恢复：内容上叠一只 1 pt 高的透明锚，用 `.padding(.top:)` 把它的**布局帧**放到记下的偏移处（`padding` 改布局帧、`offset` 不改），
///   本视图**新建后第一次出现时**在 `.task` 里 `scrollTo(锚, anchor: .top)` 一次。恢复目标在新建那一刻取一次（`@State` 播种）——
///   否则首帧布局时记录件若先写回 0，锚点会跟着移走。
/// 每个实例只恢复一次：`.task` 在每次重新出现时都会再跑（切 tab、导航弹回根页），所以另用 `hasRestored` 闸住——
/// 只有路由往返重建与导航推出新建的那个实例的第一次出现会滚。`restores` 为 false 时本次不恢复（类别页长按锚点那条路优先，IC-171）。
/// 记录件 `initial: true`：新建那一刻也记一次真实位置，记忆不会停在已离开的旧偏移上。
struct OffsetRestoringScrollView<Content: View>: View {
    private let memory: ScrollOffsetMemory
    private let content: Content
    @State private var restoreTarget: CGFloat
    @State private var hasRestored = false

    init(
        memory: ScrollOffsetMemory,
        restores: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.memory = memory
        self.content = content()
        _restoreTarget = State(initialValue: restores ? memory.offset : 0)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .background(alignment: .top) {
                        recorder
                    }
                    .overlay(alignment: .top) {
                        anchor
                    }
            }
            .coordinateSpace(.named(OffsetRestoringScrollMetrics.coordinateSpaceName))
            .task {
                guard !hasRestored else {
                    return
                }
                hasRestored = true
                guard restoreTarget > 0 else {
                    return
                }
                proxy.scrollTo(OffsetRestoringScrollMetrics.anchorID, anchor: .top)
            }
        }
    }

    /// 只读不画：内容顶部的 `minY` 一变（含新建那一刻）就换算写进记忆（不触发重绘）。
    private var recorder: some View {
        GeometryReader { geometry in
            Color.clear
                .onChange(
                    of: geometry.frame(in: .named(OffsetRestoringScrollMetrics.coordinateSpaceName)).minY,
                    initial: true
                ) { _, minY in
                    memory.offset = ScrollOffsetMemory.offset(forContentMinY: minY)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 恢复锚：`.id` 挂在 1 pt 高的那一层上、`padding` 包在它外面——带 `id` 的视图的布局帧才落在记下的偏移处
    /// （若先 `padding` 再 `.id`，带 `id` 的帧从内容顶部起算，`scrollTo` 会滚回 0）。不吃点击、读屏不念。
    private var anchor: some View {
        Color.clear
            .frame(height: OffsetRestoringScrollMetrics.anchorHeight)
            .id(OffsetRestoringScrollMetrics.anchorID)
            .padding(.top, restoreTarget)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
