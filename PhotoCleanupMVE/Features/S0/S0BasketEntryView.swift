import SwiftUI

/// IC-167 B（裁定 二）：待删篮入口——垃圾桶圆钮 + 右上纯数字徽标（SPEC-S0 v4 第三节顶排、
/// 第六节类别页页头与收起导航条；SPEC-S1 v10 决策 43）。首页顶排、类别页页头、类别页收起
/// 导航条三处同用这一只。
///
/// - 徽标 = `D_全部` 的元素数；为零时徽标不显示、入口不可触发（决策 24），入口本身恒显示。
///   **不显示体积**。
/// - 形态借 S1（S0 不自造 chrome 语汇）：页头走 S1 的圆钮玻璃 helper；收起导航条本身是玻璃
///   容器，钮不再套玻璃，与排序平涂圆钮同直径、同底。徽标取 `S1NotificationBadgeStyle` 的
///   登记值，描边色取 S0 底色（S0 恒深色，不用 S1 随外观解析的系统色）。
/// - 无障碍标签挂在按钮上、徽标叠在按钮之外且不接收点击（与「逐张整理」tab 的入口同序）。
/// - 恒深色：前景只经 `S0DeckMetrics`；不碰 PhotoKit。
struct S0BasketEntryView: View {
    enum Style {
        /// 页头：S1 圆钮玻璃。
        case glass
        /// 收起导航条内：平涂圆钮。
        case flat
    }

    let style: Style
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
        }
        .disabled(count == 0)
        .accessibilityLabel(
            L10n.text(
                "s1.trash.accessibility",
                replacing: ["count": String(count)]
            )
        )
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                badge
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch style {
        case .glass:
            Image(systemName: S0DeckSymbol.trash)
                .foregroundStyle(S0DeckMetrics.text)
                .s1ChromeCircleGlass()
        case .flat:
            Image(systemName: S0DeckSymbol.trash)
                .font(
                    .system(
                        size: S1ChromeTypography.circleIconPointSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0DeckMetrics.text)
                .frame(
                    width: S0DeckMetrics.compactNavBackSide,
                    height: S0DeckMetrics.compactNavBackSide
                )
                .background(
                    S0DeckMetrics.text.opacity(
                        S0DeckMetrics.compactNavActionFillOpacity
                    ),
                    in: Circle()
                )
        }
    }

    /// 照「逐张整理」tab 的徽标逐行搬，只把描边色换成 S0 底色。
    private var badge: some View {
        Text(String(count))
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
                    S0DeckMetrics.background,
                    lineWidth: S1NotificationBadgeStyle.ringWidth
                )
            }
            .allowsHitTesting(false)
    }
}
