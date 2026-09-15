import SwiftUI

/// IC-148 A：S0 首页视觉登记制常量的**唯一落点**，共 **52 个**。
///
/// 与 `S2AmbientMetrics` 同制（照其注释体例）：每个常量的定义处注明取值出处，
/// 视图代码一个裸数都不写。不进 `S2CalibrationConfiguration`、不上标定面板，
/// 因此 `schemaVersion` 不动。
///
/// **`S0Ambient` 的十个值不在此登记**——IC-148 裁定 丙：氛围底原地复用
/// `Features/S2/S2AmbientBackdrop.swift` 的 `S2AmbientMetrics`，那是决策 61
/// 「S2 侧引用不复制」的唯一落点，本卡一行不改、不搬家、不复制。
///
/// **类别页网格（6）与组视图（5）也不在此登记**——属批次 5.2，范围外。
///
/// 52 = 玻璃卡 8 + 分段条 14 + 等待清空行 7 + 类别行 12 + hero 6 + 类别色 5。
enum S0HomeMetrics {

    // MARK: - 玻璃卡（8）：三层高光 + 投影

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `cardBlurRadius`。
    static let cardBlurRadius: CGFloat = 30

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `cardSaturation`。
    static let cardSaturation: Double = 1.70

    /// 内上缘高光。取值出处：SPEC-S0 v1 第十四节第 2 部分 `cardInnerTopOpacity`。
    static let cardInnerTopOpacity: Double = 0.42

    /// 内下缘高光。取值出处：SPEC-S0 v1 第十四节第 2 部分
    /// `cardInnerBottomOpacity`。
    static let cardInnerBottomOpacity: Double = 0.06

    /// 外圈描边。取值出处：SPEC-S0 v1 第十四节第 2 部分 `cardOuterRingOpacity`。
    static let cardOuterRingOpacity: Double = 0.10

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `cardShadowOpacity`。
    static let cardShadowOpacity: Double = 0.42

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `cardShadowRadius`。
    static let cardShadowRadius: CGFloat = 40

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `cardShadowYOffset`。
    static let cardShadowYOffset: CGFloat = 14

    // MARK: - 分段条 S0SegmentBar（14）

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `segmentBarHeight`。
    static let segmentBarHeight: CGFloat = 8

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `segmentBarCornerRadius`。
    static let segmentBarCornerRadius: CGFloat = 4

    /// 段间隙；末段「其余照片」同样适用。取值出处：SPEC-S0 v1 第十四节第 2 部分
    /// `segmentBarItemSpacing`。
    static let segmentBarItemSpacing: CGFloat = 3

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `segmentBarInnerHighlightOpacity`。
    static let segmentBarInnerHighlightOpacity: Double = 0.35

    /// 等待清空斜纹角度。取值出处：SPEC-S0 v1 第十四节第 2 部分
    /// `segmentHatchAngleDegrees`。
    static let segmentHatchAngleDegrees: Double = 135

    /// 斜纹宽。取值出处：SPEC-S0 v1 第十四节第 2 部分 `segmentHatchStripeWidth`。
    static let segmentHatchStripeWidth: CGFloat = 3

    /// 斜纹间隔。取值出处：SPEC-S0 v1 第十四节第 2 部分 `segmentHatchGapWidth`。
    static let segmentHatchGapWidth: CGFloat = 3

    /// 「其余照片」段的中性白不透明度。取值出处：SPEC-S0 v1 第十四节第 2 部分
    /// `segmentRestOpacity`。
    static let segmentRestOpacity: Double = 0.22

    /// 扫描中的「未扫描」段。取值出处：SPEC-S0 v1 第十四节第 2 部分
    /// `segmentUnscannedOpacity`。
    static let segmentUnscannedOpacity: Double = 0.10

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `legendDotSide`。
    static let legendDotSide: CGFloat = 8

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `legendDotCornerRadius`。
    static let legendDotCornerRadius: CGFloat = 2.5

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `legendFontSize`。
    static let legendFontSize: CGFloat = 12

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `legendItemSpacingH`。
    static let legendItemSpacingH: CGFloat = 14

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `legendItemSpacingV`。
    static let legendItemSpacingV: CGFloat = 6

    // MARK: - 等待清空行（7）

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `pendingRowHeight`。
    static let pendingRowHeight: CGFloat = 40

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `pendingRowCornerRadius`。
    static let pendingRowCornerRadius: CGFloat = 20

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `pendingRowLeadingInset`。
    static let pendingRowLeadingInset: CGFloat = 14

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `pendingRowFontSize`。
    static let pendingRowFontSize: CGFloat = 13

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `pendingButtonHeight`。
    static let pendingButtonHeight: CGFloat = 28

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `pendingButtonCornerRadius`。
    static let pendingButtonCornerRadius: CGFloat = 14

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `pendingButtonFontSize`。
    static let pendingButtonFontSize: CGFloat = 12.5

    // MARK: - 类别行 S0CategoryRow（12）

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryRowHeight`。
    static let categoryRowHeight: CGFloat = 78

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryRowCornerRadius`。
    static let categoryRowCornerRadius: CGFloat = 24

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryRowSpacing`。
    static let categoryRowSpacing: CGFloat = 8

    /// 单张封面（决策 166：由四格改单张）。取值出处：SPEC-S0 v1 第十四节第 2 部分
    /// `categoryCoverSide`。
    static let categoryCoverSide: CGFloat = 60

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryCoverCornerRadius`。
    static let categoryCoverCornerRadius: CGFloat = 16

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryColorDotSide`。
    static let categoryColorDotSide: CGFloat = 8

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryNameFontSize`。
    static let categoryNameFontSize: CGFloat = 17

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categorySubFontSize`。
    static let categorySubFontSize: CGFloat = 12.5

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categorySubOpacity`。
    static let categorySubOpacity: Double = 0.52

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryValueFontSize`。
    static let categoryValueFontSize: CGFloat = 24

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `categoryValueUnitFontSize`。
    static let categoryValueUnitFontSize: CGFloat = 12

    /// 「无项目」灰显。取值出处：SPEC-S0 v1 第十四节第 2 部分
    /// `categoryDisabledOpacity`。
    static let categoryDisabledOpacity: Double = 0.45

    // MARK: - hero（6）

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `heroLabelFontSize`。
    static let heroLabelFontSize: CGFloat = 15

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `heroValueFontSize`。
    static let heroValueFontSize: CGFloat = 96

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `heroValueLetterSpacing`。
    static let heroValueLetterSpacing: CGFloat = -5.5

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `heroUnitFontSize`。
    static let heroUnitFontSize: CGFloat = 26

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `heroSubFontSize`。
    static let heroSubFontSize: CGFloat = 14

    /// 取值出处：SPEC-S0 v1 第十四节第 2 部分 `heroSubOpacity`。
    static let heroSubOpacity: Double = 0.50

    // MARK: - 类别色（5）

    // 五个值一律用 `sRGB` 显式构造，不用 asset 目录色——IC-148 裁定 甲：
    // S0 首页恒为深色配方、不随系统外观切换，asset 色会跟着 trait 走
    // （与 `S2AmbientMetrics.baseColor` 同一理由）。
    // 规格在该族注了「无品牌依据，品牌定案后统一替换」：**取值已给，照用即可**，
    // 不属未定项；品牌定案后改这五行。

    /// `#6E9BFF`。取值出处：SPEC-S0 v1 第十四节第 2 部分 `colorBigVideo`。
    static let colorBigVideo = Color(
        .sRGB,
        red: 110.0 / 255,
        green: 155.0 / 255,
        blue: 255.0 / 255,
        opacity: 1
    )

    /// `#3FD1B0`。取值出处：SPEC-S0 v1 第十四节第 2 部分 `colorSimilar`。
    static let colorSimilar = Color(
        .sRGB,
        red: 63.0 / 255,
        green: 209.0 / 255,
        blue: 176.0 / 255,
        opacity: 1
    )

    /// `#FFB54A`。取值出处：SPEC-S0 v1 第十四节第 2 部分 `colorScreenshot`。
    static let colorScreenshot = Color(
        .sRGB,
        red: 255.0 / 255,
        green: 181.0 / 255,
        blue: 74.0 / 255,
        opacity: 1
    )

    /// `#C89BFF`。取值出处：SPEC-S0 v1 第十四节第 2 部分 `colorScreenRecording`。
    static let colorScreenRecording = Color(
        .sRGB,
        red: 200.0 / 255,
        green: 155.0 / 255,
        blue: 255.0 / 255,
        opacity: 1
    )

    /// `#FF8FA3`。取值出处：SPEC-S0 v1 第十四节第 2 部分 `colorDuplicate`。
    static let colorDuplicate = Color(
        .sRGB,
        red: 255.0 / 255,
        green: 143.0 / 255,
        blue: 163.0 / 255,
        opacity: 1
    )

    // MARK: - 派生（不是登记值，故不计入 52）

    /// 类别标识到类别色的映射。是**函数**不是常量，因而不增加登记值个数；
    /// 五个取值全部来自上面五个登记常量，此处不写任何新色。
    static func categoryColor(
        for identifier: S0CategoryIdentifier
    ) -> Color {
        switch identifier {
        case .bigVideo:
            return colorBigVideo
        case .screenshot:
            return colorScreenshot
        case .screenRecording:
            return colorScreenRecording
        case .duplicate:
            return colorDuplicate
        case .similar:
            return colorSimilar
        }
    }
}

/// S0 首页的前景色**派生规则**（不是登记值，故不计入 52）。
///
/// SPEC-S0 v1 第十四节第 2 部分登记了字号与若干副行不透明度，**没有登记任何
/// 前景色**；而 IC-148 裁定 甲 又禁用层级样式、系统标签色与 chrome 前景那
/// 几个随 trait 解析的色源（禁用名单见该裁定原文）。首页恒为深色配方，因此：
///
/// - 主文字 = 纯白（`Color.white` 与 trait 无关）；
/// - 副文字 = 纯白 × **该族已登记的副行不透明度**（hero 取 `heroSubOpacity`，
///   类别行取 `categorySubOpacity`），不另造不透明度。
///
/// 这条派生已在 IC-148 自验报告登记为登记表缺口，待决策会话补登记前景色。
enum S0HomePalette {
    static let text = Color.white

    static func dimmedText(opacity: Double) -> Color {
        Color.white.opacity(opacity)
    }
}
