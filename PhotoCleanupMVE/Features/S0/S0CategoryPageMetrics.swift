import SwiftUI

/// IC-156 A：S0 类别页视觉登记制常量的**唯一落点**，共 **42 个**。
///
/// 与 `S0HomeMetrics` 同制：每个常量的定义处注明取值出处，视图代码一个裸数都不写。
/// 不进 `S2CalibrationConfiguration`、不上标定面板，因此 `schemaVersion` 不动。
///
/// **顶排不在此登记**——返回圆钮与「全选」胶囊一律借 `S1ChromeLayout`／
/// `S1ChromeTypography` 与两个 S1 玻璃 helper（SPEC-S0 v2 第十四节第 1 部分
/// 「S0 不自造 chrome 语汇」优先于画布顶排的 40 高、20 边距）。
///
/// **颜色不在此登记**：前景白取 `S0HomePalette.text`；勾选态的对勾、主按钮字色与
/// 底部渐隐的终点色取 `S2AmbientMetrics.baseColor`；选中白底与描边白取 `Color.white`。
/// 字重不是数值，写在各常量注释里，不另设常量。
///
/// 42 = v2 已登记网格 5 + 本卡补登 37（页面边距 2 + 大标题 6 + 副行 3 + 常驻行 3 +
/// 网格位置 2 + 体积标签 4 + 时长角标 4 + 勾 3 + 选中外圈 1 + 主按钮 8 + 渐隐 1）。
enum S0CategoryPageMetrics {

    // MARK: - 网格（v2 已登记 5）

    /// 网格列数。取值出处：SPEC-S0 v2 第十四节第 2 部分 `gridColumns`。
    static let gridColumns: Int = 3

    /// 格间距（行、列同值）。取值出处：SPEC-S0 v2 第十四节第 2 部分 `gridItemSpacing`。
    static let gridItemSpacing: CGFloat = 4

    /// 格圆角。取值出处：SPEC-S0 v2 第十四节第 2 部分 `gridCellCornerRadius`。
    static let gridCellCornerRadius: CGFloat = 10

    /// 右下体积标签字号（半粗）。取值出处：SPEC-S0 v2 第十四节第 2 部分
    /// `gridSizeLabelFontSize`。
    static let gridSizeLabelFontSize: CGFloat = 11

    /// 右上圆圈勾的直径。取值出处：SPEC-S0 v2 第十四节第 2 部分 `gridCheckSide`。
    static let gridCheckSide: CGFloat = 22

    // MARK: - 页面边距（补登 2）

    /// 网格与主按钮的左右边距（画布 `.grid`／`.cta` 的 left、right）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let pageHorizontalInset: CGFloat = 20

    /// 大标题与常驻行的左右边距（画布 `.h1`／`.sel` 的 left、right）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let textHorizontalInset: CGFloat = 24

    // MARK: - 大标题（补登 6）

    /// 顶排底缘 → 大标题顶（画布标题顶 118 − S1 顶排底缘 62 + 44）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let titleTopSpacing: CGFloat = 12

    /// 大标题字号（粗体）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let titleFontSize: CGFloat = 30

    /// 大标题字距。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let titleLetterSpacing: CGFloat = -0.7

    /// 大标题行高。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let titleLineHeight: CGFloat = 34

    /// 类别色点直径（圆）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let titleDotSide: CGFloat = 10

    /// 色点 → 类别名的间距。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let titleDotSpacing: CGFloat = 10

    // MARK: - 副行（补登 3）

    /// 副行字号（常规）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let subtitleFontSize: CGFloat = 14

    /// 副行白色不透明度。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let subtitleOpacity: Double = 0.55

    /// 大标题底 → 副行顶。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let subtitleTopSpacing: CGFloat = 4

    // MARK: - 常驻「已选」行（补登 3）

    /// 副行底 → 常驻行顶。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let pinnedRowTopSpacing: CGFloat = 12

    /// 常驻行字号（常规）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let pinnedRowFontSize: CGFloat = 13

    /// 常驻行白色不透明度。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let pinnedRowOpacity: Double = 0.60

    // MARK: - 网格位置（补登 2）

    /// 常驻行底 → 网格顶。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridTopSpacing: CGFloat = 12

    /// 体积标签、时长角标、勾距格边。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridBadgeInset: CGFloat = 6

    // MARK: - 体积标签（补登 4）

    /// 体积标签的黑底不透明度。画布另有 8 的背景模糊——固定色方案不上系统材质，不登记。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridSizeLabelBackgroundOpacity: Double = 0.50

    /// 体积标签底的圆角。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridSizeLabelCornerRadius: CGFloat = 7

    /// 体积标签左右内距。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridSizeLabelPaddingHorizontal: CGFloat = 6

    /// 体积标签上下内距。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridSizeLabelPaddingVertical: CGFloat = 2

    // MARK: - 时长角标（补登 4）

    /// 视频时长字号（半粗；播放符随同一字号）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridDurationFontSize: CGFloat = 11

    /// 播放符 → 时长数字的间距。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridDurationGlyphSpacing: CGFloat = 3

    /// 时长角标字影半径。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridDurationShadowRadius: CGFloat = 4

    /// 时长角标字影的黑色不透明度。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridDurationShadowOpacity: Double = 0.70

    // MARK: - 勾（补登 3）

    /// 未选态白描边线宽。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridCheckRingWidth: CGFloat = 1.5

    /// 未选态白描边不透明度。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridCheckRingOpacity: Double = 0.90

    /// 未选态黑底不透明度。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridCheckUnselectedFillOpacity: Double = 0.25

    // MARK: - 选中外圈（补登 1）

    /// 选中格的白色外圈线宽。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let gridSelectedRingWidth: CGFloat = 2

    // MARK: - 主按钮（补登 8）

    /// 主按钮底缘距屏底（含安全区 34）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaBottomInset: CGFloat = 42

    /// 主按钮高。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaHeight: CGFloat = 52

    /// 主按钮圆角。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaCornerRadius: CGFloat = 26

    /// 主按钮字号（粗体）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaFontSize: CGFloat = 17

    /// 主按钮投影的纵向偏移。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaShadowYOffset: CGFloat = 10

    /// 主按钮投影半径。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaShadowRadius: CGFloat = 30

    /// 主按钮投影的黑色不透明度。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaShadowOpacity: Double = 0.45

    /// 零选中时主按钮的不透明度（禁用但不隐藏）。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let ctaDisabledOpacity: Double = 0.35

    // MARK: - 渐隐（补登 1）

    /// 网格底部向页底色的渐隐高度。
    /// 取值出处：画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）。
    static let fadeHeight: CGFloat = 190
}

/// 类别页用到的系统符号名。集中一处，不散落字面量。
enum S0CategoryPageSymbol {
    static let back = "chevron.left"
    static let play = "play.fill"
    static let check = "checkmark"
}

/// 类别页「移入待删篮」写入会话层时的虚拟范围标识前缀：范围标识为前缀加类别标识。
/// 字符串登记，不是视觉值，不计入上面的 42 个。
enum S0CategoryPageRange {
    static let prefix = "cat:"
}
