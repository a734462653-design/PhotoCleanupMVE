import SwiftUI

/// IC-162 A：两页用到的全部系统符号名与符号字面量，集中一处（陷阱 18：
/// 展示 helper 不得 `return` 字面量，一律 `static let`）。
enum S0DeckSymbol {
    /// 条右侧与「去清理」右侧的进入指示。
    static let chevron = "chevron.right"
    /// 类别页返回。
    static let back = "chevron.left"
    /// 网格视频格的播放符。
    static let play = "play.fill"
    /// 网格勾选。
    static let check = "checkmark"
    /// 底栏主按钮的垃圾桶。
    static let trash = "trash"
    /// IC-163 C（裁定 四）：类别页排序钮。
    static let sort = "arrow.up.arrow.down"
    /// 百分号。占比的实参形如 `36%`，百分号在实参里拼，不进目录值。
    static let percentSign = "%"
    /// IC-165 C（裁定 三）：顶排人像圆钮，由退役的旧首页 `S0HomeSymbol` 并入（值不变）。
    static let account = "person.crop.circle"
}

/// IC-162 A：「卡片叠」首页与新类别页的视觉登记制常量的唯一落点。
///
/// 取值出处一律是画布生成器源码 `<top>/Tasks/design-s0-r2/` 下的三份：
/// `r7.py`（卡片叠 M1）、`r8.py`（N2 总条）、`r9.py`（O1／O2 类别页）。
/// 三份都是生成器源码，CSS 里的 px 即 pt。每个常量的定义处注明取自哪一条 CSS。
///
/// **两页恒深色**：不读 `colorScheme`，色一律显式 sRGB 构造（与 `S0HomeMetrics` 的
/// 类别色同一理由）。类别页的四处玻璃改经 S1 chrome 的玻璃 helper（IC-163 裁定 四）。
///
/// 本族**不进** `S2CalibrationConfiguration`、不上标定面板，`schemaVersion` 不动。
enum S0DeckMetrics {

    // MARK: - 色（r7.py `BASE7` 与 `C`）

    /// `#0B0F0D`。取值出处：r7.py `.screen { background: #0B0F0D }`。
    static let background = Color(
        .sRGB,
        red: 11.0 / 255,
        green: 15.0 / 255,
        blue: 13.0 / 255,
        opacity: 1
    )

    /// `#FFFBF5`。取值出处：r7.py `.screen { color: #FFFBF5 }`。
    static let text = Color(
        .sRGB,
        red: 255.0 / 255,
        green: 251.0 / 255,
        blue: 245.0 / 255,
        opacity: 1
    )

    /// `#F26B4E`。取值出处：r7.py `.chipk { background: #F26B4E }`。
    static let accent = Color(
        .sRGB,
        red: 242.0 / 255,
        green: 107.0 / 255,
        blue: 78.0 / 255,
        opacity: 1
    )

    /// `#6FD6BE`。取值出处：r7.py `.hero .r .b { color: #6FD6BE }`。
    static let mint = Color(
        .sRGB,
        red: 111.0 / 255,
        green: 214.0 / 255,
        blue: 190.0 / 255,
        opacity: 1
    )

    /// `#161B18`：卡与格取不到图时的纯色底。取值出处：r7.py `.dk { background: #161B18 }`。
    static let cardBase = Color(
        .sRGB,
        red: 22.0 / 255,
        green: 27.0 / 255,
        blue: 24.0 / 255,
        opacity: 1
    )

    // MARK: - 类别色（r7.py `C`，六个）

    /// `#F26B4E`。取值出处：r7.py `C["video"]`。
    static let colorVideo = accent

    /// `#F59B5B`。取值出处：r7.py `C["sim"]`（IC-165 起不再借已删的节动作色，直接登记同值）。
    static let colorSimilar = Color(
        .sRGB,
        red: 245.0 / 255,
        green: 155.0 / 255,
        blue: 91.0 / 255,
        opacity: 1
    )

    /// `#FFD37A`。取值出处：r7.py `C["shot"]`。
    static let colorScreenshot = Color(
        .sRGB,
        red: 255.0 / 255,
        green: 211.0 / 255,
        blue: 122.0 / 255,
        opacity: 1
    )

    /// `#27C0A4`。取值出处：r7.py `C["rec"]`。
    static let colorScreenRecording = Color(
        .sRGB,
        red: 39.0 / 255,
        green: 192.0 / 255,
        blue: 164.0 / 255,
        opacity: 1
    )

    /// `#C9A0DC`。取值出处：r7.py `C["dup"]`。
    static let colorDuplicate = Color(
        .sRGB,
        red: 201.0 / 255,
        green: 160.0 / 255,
        blue: 220.0 / 255,
        opacity: 1
    )

    /// `#8A958F`。取值出处：r7.py `C["rest"]`。
    static let colorRest = Color(
        .sRGB,
        red: 138.0 / 255,
        green: 149.0 / 255,
        blue: 143.0 / 255,
        opacity: 1
    )

    // MARK: - 玻璃（r7.py `.tabbar`、r9.py `.dock`／`.cnav`／`.cell .lb`）
    //
    // IC-163 C（裁定 四）：类别页四处玻璃改走 S1 chrome 的玻璃 helper，原先的两个平涂
    // 填充色随之删去。

    /// 格底玻璃条 `rgba(20,22,21,0.52)`。取值出处：r9.py `.cell .lb`。
    static let cellLabelFill = Color(
        .sRGB,
        red: 20.0 / 255,
        green: 22.0 / 255,
        blue: 21.0 / 255,
        opacity: 0.52
    )

    /// 占比角标 `rgba(20,22,21,0.55)`。取值出处：r7.py `.pct`。
    static let shareBadgeFill = Color(
        .sRGB,
        red: 20.0 / 255,
        green: 22.0 / 255,
        blue: 21.0 / 255,
        opacity: 0.55
    )

    /// 玻璃顶缘高光的不透明度。取值出处：r9.py `.cnav` 同族的
    /// `inset 0 0.5px 0 rgba(255,255,255,0.34)`（r7.py `.dk .edge` 同值）。
    static let glassTopHighlightOpacity: Double = 0.34

    /// 玻璃顶缘高光线宽。取值出处：同上 `0.5px`。
    static let glassTopHighlightWidth: CGFloat = 0.5

    // MARK: - 大数字区（r7.py `.hero` / `.pend`）

    /// 顶排底缘 → 大数字区顶缘。取值出处：r7.py `.brand { top: 72px }` 与
    /// `.hero { top: 122px }` 之差，减去品牌行的行高。
    static let heroTopSpacing: CGFloat = 28

    /// 取值出处：r7.py `.hero .l { font-size: 14.5px }`。
    static let heroLabelFontSize: CGFloat = 14.5

    /// 取值出处：r7.py `.hero .l { color: rgba(255,251,245,0.7) }`。
    static let heroLabelOpacity: Double = 0.7

    /// 取值出处：r7.py `.hero .v { font-size: 60px }`。
    static let heroValueFontSize: CGFloat = 60

    /// 取值出处：r7.py `.hero .v { letter-spacing: -2.5px }`。
    static let heroValueLetterSpacing: CGFloat = -2.5

    /// 取值出处：r7.py `.hero .v span { font-size: 28px }`。
    static let heroUnitFontSize: CGFloat = 28

    /// 取值出处：r7.py `.hero .v span { color: rgba(255,251,245,0.72) }`。
    static let heroUnitOpacity: Double = 0.72

    /// 取值出处：r7.py `.hero .v span { margin-left: 6px }`。
    static let heroUnitSpacing: CGFloat = 6

    /// 取值出处：r7.py `.hero .r .a { font-size: 12.5px }`。
    static let releasedLabelFontSize: CGFloat = 12.5

    /// 取值出处：r7.py `.hero .r .a { color: rgba(255,251,245,0.55) }`。
    static let releasedLabelOpacity: Double = 0.55

    /// 取值出处：r7.py `.hero .r .b { font-size: 22px }`。
    static let releasedValueFontSize: CGFloat = 22

    /// 取值出处：r7.py `.hero .r .b { letter-spacing: -0.6px }`。
    static let releasedValueLetterSpacing: CGFloat = -0.6

    /// 取值出处：r7.py `.hero .r .b span { font-size: 13px }`。
    static let releasedUnitFontSize: CGFloat = 13

    /// 取值出处：r7.py `.hero .r { padding-bottom: 7px }`。
    static let releasedBaselinePadding: CGFloat = 7

    /// 大数字区底缘 → 等待清空行。取值出处：r7.py `.hero` 底缘与
    /// `.pend { top: 212px }` 之差。
    static let pendingRowTopSpacing: CGFloat = 8

    /// 取值出处：r7.py `.pend { font-size: 12.5px }`。
    static let pendingRowFontSize: CGFloat = 12.5

    /// 取值出处：r7.py `.pend { color: rgba(255,251,245,0.55) }`。
    static let pendingRowOpacity: Double = 0.55

    /// 取值出处：r7.py `.pend a { margin-left: 6px }`。
    static let pendingActionSpacing: CGFloat = 6

    // MARK: - 总条（r8.py `.tbar` / `.tlab`）

    /// 等待清空行 → 总条。取值出处：r8.py `.tbar { top: 244px }`。
    static let totalBarTopSpacing: CGFloat = 16

    /// 取值出处：r8.py `.tbar { left: 20px; right: 20px }`。
    static let totalBarHorizontalInset: CGFloat = 20

    /// 取值出处：r8.py `.tbar { height: 14px }`。
    static let totalBarHeight: CGFloat = 14

    /// 取值出处：r8.py `.tbar a { border-radius: 7px }`。
    static let totalBarCornerRadius: CGFloat = 7

    /// 取值出处：r8.py `.tbar { gap: 3px }`。
    static let totalBarItemSpacing: CGFloat = 3

    /// 非当前段的不透明度。取值出处：r8.py `.tbar a { opacity: 0.38 }`。
    static let totalBarDimmedOpacity: Double = 0.38

    /// 「未扫描」段的中性填充不透明度。**画布缺口**：N2 画的是就绪态，没有未扫段；
    /// 取同族最低一档（r7.py `.dk .dim` 末段 `0.18`），已在 IC-162 自验报告登记。
    static let totalBarUnscannedFillOpacity: Double = 0.18

    /// 总条 → 标注行。取值出处：r8.py `.tbar` 底缘与 `.tlab { top: 264px }` 之差。
    static let totalBarCaptionTopSpacing: CGFloat = 6

    /// 取值出处：r8.py `.tlab { font-size: 12.5px }`。
    static let totalBarCaptionFontSize: CGFloat = 12.5

    /// 取值出处：r8.py `.tlab b { color: rgba(255,251,245,0.55) }`。
    static let totalBarCaptionDimmedOpacity: Double = 0.55

    /// 取值出处：r8.py `.tlab { gap: 6px }`。
    static let totalBarCaptionItemSpacing: CGFloat = 6

    /// 取值出处：r8.py `.tlab i { width: 8px; height: 8px }`。
    static let totalBarCaptionDotSide: CGFloat = 8

    /// 取值出处：r8.py `.tlab i { border-radius: 4px }`。
    static let totalBarCaptionDotCornerRadius: CGFloat = 4

    // MARK: - 卡片叠（r7.py `.deck` / `.dk`，r8.py N2 的两个可见高）

    /// 标注行 → 卡片叠。取值出处：r8.py `.deck.low { top: 290px }`。
    static let deckTopSpacing: CGFloat = 10

    /// 取值出处：r7.py `.deck { left: 6px; right: 6px }`。
    static let deckHorizontalInset: CGFloat = 6

    /// 取值出处：r7.py `.dk { border-radius: 28px }`。
    static let cardCornerRadius: CGFloat = 28

    /// 每张卡向下多伸出、被下一张盖住的量。取值出处：r7.py `OVER = 34`。
    static let cardOverhang: CGFloat = 34

    /// 末张卡向下拖出屏幕的量。取值出处：r7.py `strip(..., last=True)` 的 `h = 320`。
    static let lastCardTailHeight: CGFloat = 320

    /// 展开卡的可见高。取值出处：r8.py `N2 = screen(..., deck(200, ...))`。
    static let openCardVisibleHeight: CGFloat = 200

    /// 收起条的可见高。取值出处：r8.py `N2` 的 `[66, 66, 66, 66]`。
    static let stripVisibleHeight: CGFloat = 66

    /// 卡上缘阴影的不透明度。取值出处：r7.py `.dk { box-shadow: 0 -14px 30px rgba(0,0,0,0.60) }`。
    static let cardShadowOpacity: Double = 0.60

    /// 取值出处：同上 `30px`。
    static let cardShadowRadius: CGFloat = 30

    /// 取值出处：同上 `-14px`（向上）。
    static let cardShadowYOffset: CGFloat = -14

    /// 卡外圈描边。取值出处：r7.py `.dk .edge { inset 0 0 0 0.5px rgba(255,255,255,0.12) }`。
    static let cardRingOpacity: Double = 0.12

    /// 取值出处：同上 `0.5px`。
    static let cardRingWidth: CGFloat = 0.5

    // MARK: - 收起条（r7.py `.dk .row` / `.dk .dim`）

    /// 条内压暗渐变的三个停靠点。取值出处：r7.py
    /// `.dk .dim { linear-gradient(180deg, rgba(8,10,9,0.74) 0px, rgba(8,10,9,0.58) 70px, rgba(8,10,9,0.18) 100%) }`。
    static let stripDimTopOpacity: Double = 0.74

    /// 取值出处：同上中段 `0.58`。
    static let stripDimMiddleOpacity: Double = 0.58

    /// 取值出处：同上末段 `0.18`。
    static let stripDimBottomOpacity: Double = 0.18

    /// 压暗渐变中段的位置（占整张条的比例）。取值出处：同上 `70px` 对整张条
    /// （可见高 66 + 伸出 34 = 100）的位置。
    static let stripDimMiddleLocation: Double = 0.7

    /// 取值出处：r7.py `.dk .row { left: 20px }`。
    static let stripLeadingInset: CGFloat = 20

    /// 取值出处：r7.py `.dk .row { right: 14px }`。
    static let stripTrailingInset: CGFloat = 14

    /// 取值出处：r7.py `.dk .row { gap: 10px }`。
    static let stripItemSpacing: CGFloat = 10

    /// 取值出处：r7.py `.dk .row i { width: 8px; height: 8px }`。
    static let stripDotSide: CGFloat = 8

    /// 取值出处：r7.py `.dk .row i { border-radius: 4px }`。
    static let stripDotCornerRadius: CGFloat = 4

    /// 取值出处：r7.py `.dk .row .n { font-size: 17px }`。
    static let stripNameFontSize: CGFloat = 17

    /// 取值出处：r7.py `.dk .row .p { font-size: 12.5px }`。
    static let stripShareFontSize: CGFloat = 12.5

    /// 取值出处：r7.py `.dk .row .p { color: rgba(255,251,245,0.5) }`。
    static let stripShareOpacity: Double = 0.5

    /// 取值出处：r7.py `.dk .row .g { font-size: 22px }`。
    static let stripValueFontSize: CGFloat = 22

    /// 取值出处：r7.py `.dk .row .g { letter-spacing: -0.7px }`。
    static let stripValueLetterSpacing: CGFloat = -0.7

    /// 取值出处：r7.py `.dk .row .g span { font-size: 13px }`。
    static let stripUnitFontSize: CGFloat = 13

    /// 取值出处：r7.py `.dk .row .g span { color: rgba(255,251,245,0.7) }`。
    static let stripUnitOpacity: Double = 0.7

    /// 取值出处：r7.py `.dk .row .g span { margin-left: 3px }`。
    static let stripUnitSpacing: CGFloat = 3

    /// 取值出处：r7.py `.dk .row .ch { opacity: 0.45 }`。
    static let stripChevronOpacity: Double = 0.45

    // MARK: - 展开卡（r7.py `.dk.open`）

    /// 展开卡底部压暗渐变的四个停靠点。取值出处：r7.py
    /// `.dk.open .shade { linear-gradient(180deg, rgba(0,0,0,0.30) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0.05) 48%, rgba(0,0,0,0.72) 100%) }`。
    static let openShadeTopOpacity: Double = 0.30

    /// 取值出处：同上 `30%` 处的 `0`。
    static let openShadeUpperLocation: Double = 0.30

    /// 取值出处：同上 `48%` 处的 `0.05`。
    static let openShadeLowerOpacity: Double = 0.05

    /// 取值出处：同上 `48%`。
    static let openShadeLowerLocation: Double = 0.48

    /// 取值出处：同上末端 `0.72`。
    static let openShadeBottomOpacity: Double = 0.72

    /// 取值出处：r7.py `.dk.open .tl { left: 14px; top: 14px }`（`.tr` 同值）。
    static let openBadgeInset: CGFloat = 14

    /// 取值出处：r7.py `.pct { height: 26px }`。
    static let shareBadgeHeight: CGFloat = 26

    /// 取值出处：r7.py `.pct { border-radius: 13px }`。
    static let shareBadgeCornerRadius: CGFloat = 13

    /// 取值出处：r7.py `.pct { padding: 0 10px }`。
    static let shareBadgeHorizontalPadding: CGFloat = 10

    /// 取值出处：r7.py `.pct { font-size: 12px }`。
    static let shareBadgeFontSize: CGFloat = 12

    /// 取值出处：r7.py `.dk.open .tx { left: 20px }`。
    static let openTextLeadingInset: CGFloat = 20

    /// 展开卡文字块底缘距卡底。取值出处：r7.py `.tx { bottom: OVER + 16 }`。
    static let openTextBottomInset: CGFloat = 16

    /// 取值出处：r7.py `.dk.open .tx .n { font-size: 19px }`。
    static let openNameFontSize: CGFloat = 19

    /// 取值出处：r7.py `.dk.open .tx .g { font-size: 40px }`。
    static let openValueFontSize: CGFloat = 40

    /// 取值出处：r7.py `.dk.open .tx .g { letter-spacing: -1.4px }`。
    static let openValueLetterSpacing: CGFloat = -1.4

    /// 取值出处：r7.py `.dk.open .tx .c { font-size: 12.5px }`。
    static let openSubFontSize: CGFloat = 12.5

    /// 取值出处：r7.py `.dk.open .tx .c { color: rgba(255,251,245,0.75) }`。
    static let openSubOpacity: Double = 0.75

    /// 取值出处：r7.py `.dk.open .tx .c { margin-top: 1px }`。
    static let openSubTopSpacing: CGFloat = 1

    /// 取值出处：r7.py `.dk.open .go { right: 16px }`。
    static let openActionTrailingInset: CGFloat = 16

    /// 「去清理」底缘距卡底。取值出处：r7.py `.go { bottom: OVER + 20 }`。
    static let openActionBottomInset: CGFloat = 20

    /// 取值出处：r7.py `.dk.open .go { height: 44px }`。
    static let openActionHeight: CGFloat = 44

    /// 取值出处：r7.py `.dk.open .go { border-radius: 22px }`。
    static let openActionCornerRadius: CGFloat = 22

    /// 取值出处：r7.py `.dk.open .go { padding: 0 14px 0 18px }` 的左内距。
    static let openActionLeadingPadding: CGFloat = 18

    /// 取值出处：同上右内距 `14px`。
    static let openActionTrailingPadding: CGFloat = 14

    /// 取值出处：r7.py `.dk.open .go { gap: 2px }`。
    static let openActionItemSpacing: CGFloat = 2

    /// 取值出处：r7.py `.dk.open .go { font-size: 15px }`。
    static let openActionFontSize: CGFloat = 15

    /// 卡上文字的投影不透明度。取值出处：r7.py `.dk.open .tx { text-shadow: 0 1px 8px rgba(0,0,0,0.5) }`。
    static let openTextShadowOpacity: Double = 0.5

    /// 取值出处：同上 `8px`。
    static let openTextShadowRadius: CGFloat = 8

    /// 取值出处：同上 `1px`。
    static let openTextShadowYOffset: CGFloat = 1

    // MARK: - 展开／收起动画（裁定 五）

    /// 取值出处：本卡裁定 五「`withAnimation(.spring(response: 0.42, dampingFraction: 0.86))`」。
    static let expandAnimationResponse: Double = 0.42

    /// 取值出处：同上。
    static let expandAnimationDamping: Double = 0.86

    /// 展开卡内容层（大字块、「去清理」、左上角标）出现时自下而上的位移。
    /// 取值出处：IC-163 卡「视觉取值」第一条（`expandContentRise = 8`）。
    static let expandContentRise: CGFloat = 8

    // MARK: - 类别页页头（r9.py `.hd` / `.ttl` / `.tbar`）

    /// 取值出处：r9.py `.hd { height: 262px }`。
    static let pageHeaderHeight: CGFloat = 262

    /// 页头压暗渐变的四个停靠点。取值出处：r9.py
    /// `.hd .fadeb { linear-gradient(180deg, rgba(11,15,13,0.55) 0%, rgba(11,15,13,0.10) 34%, rgba(11,15,13,0.55) 70%, #0B0F0D 100%) }`。
    static let pageHeaderFadeTopOpacity: Double = 0.55

    /// 取值出处：同上 `34%` 处的 `0.10`。
    static let pageHeaderFadeUpperOpacity: Double = 0.10

    /// 取值出处：同上 `34%`。
    static let pageHeaderFadeUpperLocation: Double = 0.34

    /// 取值出处：同上 `70%` 处的 `0.55`。
    static let pageHeaderFadeLowerLocation: Double = 0.70

    /// 取值出处：r9.py `.ttl { left: 20px; right: 20px }`。
    static let pageTitleHorizontalInset: CGFloat = 20

    /// 顶排底缘 → 标题块顶缘。取值出处：r9.py `.nav { top: 60px }` 与
    /// `.ttl { top: 138px }` 之差，减去顶排行高 44。
    static let pageTitleTopSpacing: CGFloat = 34

    /// 取值出处：r9.py `.ttl .n { font-size: 19px }`。
    static let pageTitleNameFontSize: CGFloat = 19

    /// 取值出处：r9.py `.ttl .g { font-size: 46px }`。
    static let pageTitleValueFontSize: CGFloat = 46

    /// 取值出处：r9.py `.ttl .g { letter-spacing: -1.7px }`。
    static let pageTitleValueLetterSpacing: CGFloat = -1.7

    /// 取值出处：r9.py `.ttl .g span { font-size: 22px }`。
    static let pageTitleUnitFontSize: CGFloat = 22

    /// 取值出处：r9.py `.ttl .g span { color: rgba(255,251,245,0.75) }`。
    static let pageTitleUnitOpacity: Double = 0.75

    /// 取值出处：r9.py `.ttl .g span { margin-left: 5px }`。
    static let pageTitleUnitSpacing: CGFloat = 5

    /// 取值出处：r9.py `.ttl .c { font-size: 12.5px }`。
    static let pageTitleSubFontSize: CGFloat = 12.5

    /// 取值出处：r9.py `.ttl .c { color: rgba(255,251,245,0.72) }`。
    static let pageTitleSubOpacity: Double = 0.72

    /// 取值出处：r9.py `.ttl .c { margin-top: 2px }`。
    static let pageTitleSubTopSpacing: CGFloat = 2

    /// 取值出处：r9.py `.ttl .r { padding-bottom: 6px }`。
    static let pageShareBadgeBaselinePadding: CGFloat = 6

    /// 标题块底缘 → 页头总条。取值出处：r9.py `.ttl` 底缘与 `.tbar { top: 252px }` 之差。
    static let pageTotalBarTopSpacing: CGFloat = 14

    /// 取值出处：r9.py `.tbar { height: 10px }`。
    static let pageTotalBarHeight: CGFloat = 10

    /// 取值出处：r9.py `.tbar i { border-radius: 5px }`。
    static let pageTotalBarCornerRadius: CGFloat = 5

    /// 取值出处：r9.py `.tbar i { opacity: 0.34 }`。
    static let pageTotalBarDimmedOpacity: Double = 0.34

    // MARK: - 类别页分节（r9.py `.sec`）

    /// 取值出处：r9.py `.sec { left: 20px }`。
    static let sectionLeadingInset: CGFloat = 20

    /// 取值出处：r9.py `.sec { right: 14px }`。
    static let sectionTrailingInset: CGFloat = 14

    /// 取值出处：r9.py `.sec { height: 32px }`。
    static let sectionHeight: CGFloat = 32

    /// 取值出处：r9.py `.sec .a { font-size: 15px }`。
    static let sectionTitleFontSize: CGFloat = 15

    /// 取值出处：r9.py `.sec .a b { color: rgba(255,251,245,0.55) }`。
    static let sectionTitleDimmedOpacity: Double = 0.55

    /// 取值出处：r9.py `.sec .a b { margin-left: 8px }`。
    static let sectionTitleItemSpacing: CGFloat = 8

    /// 节标题 → 该节网格。取值出处：r9.py `.sec { top: 324px }` 与
    /// `.grid { top: 362px }` 之差，减去节行高 32。
    static let sectionToGridSpacing: CGFloat = 6

    /// 月份节标题右侧计数的字号（不透明度沿用 `sectionTitleDimmedOpacity`）。
    /// 取值出处：IC-163 卡「视觉取值」第三条（`monthSectionCountFontSize = 12.5`）。
    static let monthSectionCountFontSize: CGFloat = 12.5

    /// 月份节之间、首节与页头之间的间距（从大到小时整页那张网格与页头之间同用此值）。
    /// 取值出处：IC-163 卡「视觉取值」第三条（节间距 12，首节距页头 12）。
    static let monthSectionSpacing: CGFloat = 12

    // MARK: - 类别页网格（r9.py `.grid` / `.cell`）

    /// 取值出处：r9.py `.grid { left: 6px; right: 6px }`。
    static let gridHorizontalInset: CGFloat = 6

    /// 取值出处：r9.py `.grid { grid-template-columns: repeat(2, ...) }`。
    static let gridColumns = 2

    /// 取值出处：r9.py `.grid { gap: 5px }`。
    static let gridItemSpacing: CGFloat = 5

    /// 取值出处：r9.py `.cell { height: 172px }`。
    static let gridCellHeight: CGFloat = 172

    /// 取值出处：r9.py `.cell { border-radius: 20px }`。
    static let gridCellCornerRadius: CGFloat = 20

    /// 取值出处：r9.py `.cell .edge { inset 0 0 0 0.5px rgba(255,255,255,0.14) }`。
    static let gridCellRingOpacity: Double = 0.14

    /// 取值出处：同上 `0.5px`。
    static let gridCellRingWidth: CGFloat = 0.5

    /// 取值出处：r9.py `.cell .lb { left: 6px; right: 6px; bottom: 6px }`。
    static let gridLabelInset: CGFloat = 6

    /// 取值出处：r9.py `.cell .lb { height: 32px }`。
    static let gridLabelHeight: CGFloat = 32

    /// 取值出处：r9.py `.cell .lb { border-radius: 13px }`。
    static let gridLabelCornerRadius: CGFloat = 13

    /// 取值出处：r9.py `.cell .lb { padding: 0 11px }`。
    static let gridLabelHorizontalPadding: CGFloat = 11

    /// 取值出处：r9.py `.cell .lb { font-size: 13px }`。
    static let gridLabelFontSize: CGFloat = 13

    /// 取值出处：r9.py `.cell .lb span:last-child { color: rgba(255,251,245,0.8) }`。
    static let gridLabelTrailingOpacity: Double = 0.8

    /// 取值出处：r9.py `.cell .lb` 内播放符与时长之间的默认间隔（`gap` 未设，取
    /// 节动作同族的 `4px`）。
    static let gridLabelGlyphSpacing: CGFloat = 4

    /// 取值出处：r9.py `.cell .chk { right: 9px; top: 9px }`。
    static let gridCheckInset: CGFloat = 9

    /// 取值出处：r9.py `.cell .chk { width: 28px; height: 28px }`。
    static let gridCheckSide: CGFloat = 28

    /// 取值出处：r9.py `.cell .chk { border-width: 2px }`（`gen.py` `.chk` 的
    /// `border: 2px solid rgba(255,255,255,0.92)`）。
    static let gridCheckRingWidth: CGFloat = 2

    /// 取值出处：gen.py `.chk { border: 2px solid rgba(255,255,255,0.92) }`。
    static let gridCheckRingOpacity: Double = 0.92

    /// 取值出处：r9.py `.cell .chk { background: rgba(0,0,0,0.28) }`。
    static let gridCheckUnselectedFillOpacity: Double = 0.28

    /// 选中格的描边线宽。取值出处：r9.py `.cell.on .edge { inset 0 0 0 3px #F26B4E }`。
    static let gridSelectedRingWidth: CGFloat = 3

    /// 勾符号字号（weight bold）。取值出处：SPEC-S0 v3 第十四节第 2 部分。
    static let gridCheckGlyphFontSize: CGFloat = 13

    // MARK: - 类别页 toast（SPEC-S0 v3 第十四节第 2 部分）

    /// 「已移入待删篮」字号。取值出处：SPEC-S0 v3 第十四节第 2 部分。
    static let toastFontSize: CGFloat = 15

    /// 取值出处：SPEC-S0 v3 第十四节第 2 部分。
    static let toastHorizontalPadding: CGFloat = 16

    /// 取值出处：SPEC-S0 v3 第十四节第 2 部分。
    static let toastVerticalPadding: CGFloat = 8

    /// 取值出处：SPEC-S0 v3 第十四节第 2 部分。
    static let toastCornerRadius: CGFloat = 27

    /// toast 底缘 → 底栏顶缘。取值出处：SPEC-S0 v3 第十四节第 2 部分。
    static let toastToDockSpacing: CGFloat = 8

    // MARK: - 类别页底栏与收起后的导航（r9.py `.dock` / `.cnav`）

    /// 取值出处：r9.py `.dock { left: 12px; right: 12px }`。
    static let dockHorizontalInset: CGFloat = 12

    /// 取值出处：r9.py `.dock { bottom: 24px }`。
    static let dockBottomInset: CGFloat = 24

    /// 取值出处：r9.py `.dock { height: 72px }`。
    static let dockHeight: CGFloat = 72

    /// 取值出处：r9.py `.dock { border-radius: 36px }`。
    static let dockCornerRadius: CGFloat = 36

    /// 取值出处：r9.py `.dock { padding: 0 10px 0 26px }` 的左内距。
    static let dockLeadingPadding: CGFloat = 26

    /// 取值出处：同上右内距 `10px`。
    static let dockTrailingPadding: CGFloat = 10

    /// 取值出处：r9.py `.dock .a { font-size: 12.5px }`。
    static let dockLabelFontSize: CGFloat = 12.5

    /// 取值出处：r9.py `.dock .a { color: rgba(255,251,245,0.62) }`。
    static let dockLabelOpacity: Double = 0.62

    /// 取值出处：r9.py `.dock .g { font-size: 22px }`。
    static let dockValueFontSize: CGFloat = 22

    /// 取值出处：r9.py `.dock .g { letter-spacing: -0.6px }`。
    static let dockValueLetterSpacing: CGFloat = -0.6

    /// 取值出处：r9.py `.dock .btn { height: 52px }`。
    static let dockButtonHeight: CGFloat = 52

    /// 取值出处：r9.py `.dock .btn { border-radius: 26px }`。
    static let dockButtonCornerRadius: CGFloat = 26

    /// 取值出处：r9.py `.dock .btn { padding: 0 22px 0 18px }` 的左内距。
    static let dockButtonLeadingPadding: CGFloat = 18

    /// 取值出处：同上右内距 `22px`。
    static let dockButtonTrailingPadding: CGFloat = 22

    /// 取值出处：r9.py `.dock .btn { gap: 7px }`。
    static let dockButtonItemSpacing: CGFloat = 7

    /// 取值出处：r9.py `.dock .btn { font-size: 16px }`。
    static let dockButtonFontSize: CGFloat = 16

    /// 零选中时主按钮的不透明度（禁用但不隐藏）。取值出处：与
    /// `S0CategoryPageMetrics.ctaDisabledOpacity` 同值同源（Decision_log 第 183 条）。
    static let dockButtonDisabledOpacity: Double = 0.35

    /// 取值出处：r9.py `.cnav { left: 10px; right: 10px }`。
    static let compactNavHorizontalInset: CGFloat = 10

    /// 取值出处：r9.py `.cnav { height: 54px }`。
    static let compactNavHeight: CGFloat = 54

    /// 取值出处：r9.py `.cnav { border-radius: 27px }`。
    static let compactNavCornerRadius: CGFloat = 27

    /// 取值出处：r9.py `.cnav { padding: 0 8px 0 6px }` 的左内距。
    static let compactNavLeadingPadding: CGFloat = 6

    /// 取值出处：同上右内距 `8px`。
    static let compactNavTrailingPadding: CGFloat = 8

    /// 取值出处：r9.py `.cnav .bk { width: 42px; height: 42px }`。
    static let compactNavBackSide: CGFloat = 42

    /// 取值出处：r9.py `.cnav .t { font-size: 16px }`。
    static let compactNavTitleFontSize: CGFloat = 16

    /// 取值出处：r9.py `.cnav .t b { margin-left: 8px }`。
    static let compactNavTitleItemSpacing: CGFloat = 8

    /// 取值出处：r9.py `.cnav .t b { letter-spacing: -0.3px }`。
    static let compactNavValueLetterSpacing: CGFloat = -0.3

    /// 取值出处：r9.py `.cnav .t i { font-size: 12.5px }`。
    static let compactNavShareFontSize: CGFloat = 12.5

    /// 取值出处：r9.py `.cnav .t i { color: rgba(255,251,245,0.55) }`。
    static let compactNavShareOpacity: Double = 0.55

    /// 取值出处：r9.py `.cnav .all { height: 38px }`。
    static let compactNavActionHeight: CGFloat = 38

    /// 取值出处：r9.py `.cnav .all { border-radius: 19px }`。
    static let compactNavActionCornerRadius: CGFloat = 19

    /// 取值出处：r9.py `.cnav .all { padding: 0 14px }`。
    static let compactNavActionHorizontalPadding: CGFloat = 14

    /// 取值出处：r9.py `.cnav .all { font-size: 14px }`。
    static let compactNavActionFontSize: CGFloat = 14

    /// 取值出处：r9.py `.cnav .all { background: rgba(255,255,255,0.10) }`。
    static let compactNavActionFillOpacity: Double = 0.10

    /// 页头收成导航条的切换阈值（滚动偏移超过它即切）。取值出处：r9.py O2 的
    /// 页头已整段滚走，取页头高减导航条顶距与高。
    static let compactNavThreshold: CGFloat = 154

    // MARK: - 派生（不是登记值）

    /// 类别标识到卡片叠类别色的映射。取值全部来自上面六个登记常量。
    static func categoryColor(
        for identifier: S0CategoryIdentifier
    ) -> Color {
        switch identifier {
        case .bigVideo:
            return colorVideo
        case .screenshot:
            return colorScreenshot
        case .screenRecording:
            return colorScreenRecording
        case .duplicate:
            return colorDuplicate
        case .similar:
            return colorSimilar
        case .rest:
            return colorRest
        }
    }

    /// 前景色派生：主文字纯色、副文字按登记不透明度压暗（照 `S0HomePalette` 的体例）。
    static func dimmedText(opacity: Double) -> Color {
        text.opacity(opacity)
    }
}
