# IC-165 变更清单（「卡片叠」首页与新类别页搬成正式，旧首页与旧类别页退役）

任务卡：`<top>/Tasks/IC-20260923-165-deck-formal.md`。依据 SPEC-S0 v3（SHA-256 `F52FC2C1381949DDFE86BDE476A103BA3476EEBDA0BD77B5D2669BA2D0EF83F6`）与卡随附六条裁定。

## 一、提交链（全部在 `main` 上，`git log --first-parent` 可见合并提交）

| 序 | 提交 | 类型 | 首行 |
|---|---|---|---|
| A | `b6b8464f7de1998173140cdbc816c37dcaefc909` | feat | 子项 A 先加新——从 562f8b7 原样搬入卡片叠首页与新类别页（与 #327 同形态） |
| B | `5e968143822983d6f5ad00f77f44d8a04c3cd474` | feat | 子项 B 接线切换——卡片叠首页与新类别页为唯一页，补齐受限提示条／扫描首帧／VF 三态（裁定 四、五） |
| C | `4b6929c89c0578375106eedef858a910a9191788` | feat | 子项 C 共享符号搬家、旧首页与旧类别页退役、deck.* 改名与删 key（裁定 三、六） |
| D | `c7466fb371d9e23d1ffc39b81a21b125230a7a85` | test | 子项 D 新断言六条 |
| C′ | `dc7e49459f15fb6227c3f34903357ae490aaa7ed` | fix | 子项 C 补正——IC147 断言 11 跨前缀借用集改按集合比较（#331 红） |
| 合并 | `096fb08695972acafed660a9fc1423e3006d4245` | merge | merge(IC-165): 卡片叠首页与新类别页搬成正式，旧首页与旧类别页退役（SPEC-S0 v3） |
| docs | 本报告所在提交 | docs | 只含 `Reports/IC-165/` 两个文件，直接落在 `main`（惯例 44，卡面授权） |

合并提交两个父：`fbee8b1e24815f248fd67bcc02d59b64eea72dad`（原 `main`）与 `dc7e494`（分支 tip）。合并树 `7b8d2b24940be51716d9c605a8b284eb9a191270` 与 `dc7e494` 的树相同。

**C′ 是卡面四个子项之外多出的第五个提交**：#331 红一条，是我在 C 里改写的测试断言写错了（见 self-check 第八节）。卡不授权 amend，所以另起补正提交。它只改 `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` 一处，4 行加、2 行删，产品零改动。

## 二、逐提交文件清单（`git show --numstat`，加／删行数）

### A `b6b8464`

| 加 | 删 | 路径 |
|---|---|---|
| 32 | 0 | `PhotoCleanupMVE.xcodeproj/project.pbxproj` |
| 86 | 32 | `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift`（整文件取 `562f8b7` 版） |
| 955 | 0 | `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift`（= 预览版 :1-955） |
| 181 | 0 | `PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift` |
| 1086 | 0 | `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` |
| 806 | 0 | `PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift` |
| 32 | 0 | `PhotoCleanupMVE/Features/S0/S0DeckZoomTransition.swift`（新，文件头一句 + `import SwiftUI` + 空行 + 预览版 :957-985） |
| 21 | 0 | `PhotoCleanupMVE/Features/Shared/S0DeckAssetDates.swift` |
| 119 | 0 | `PhotoCleanupMVE/Features/Shared/S0DeckCoverView.swift` |
| 121 | 0 | `PhotoCleanupMVE/Localizable.xcstrings`（11 条 `deck.*`） |
| 180 | 0 | `PhotoCleanupMVETests/IC162DeckPreviewTests.swift` |
| 120 | 0 | `PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift`（整文件取 `562f8b7` 版，一个 hunk） |

### B `5e96814`

| 加 | 删 | 路径 |
|---|---|---|
| 31 | 66 | `S0CleanupFlowView.swift`（删首页与类别页的 `else` 分支和 `S0DeckPreview` 外壳；文件头一句随之更新） |
| 110 | 30 | `S0DeckHomeView.swift`（受限提示条、扫描首帧、`VF` 三态） |
| 0 | 9 | `S0DeckMetrics.swift`（删 `S0DeckPreview`） |
| 8 | 7 | `PhotoCleanupMVETests/IC156CategoryPageTests.swift`（仅断言 10） |
| 16 | 14 | `PhotoCleanupMVETests/IC160SelectionSurvivesS2Tests.swift`（仅断言 4） |

### C `4b6929c`

| 加 | 删 | 路径 |
|---|---|---|
| 16 | 24 | `project.pbxproj` |
| 0 | 220 | `Features/S0/S0CategoryPageMetrics.swift`（`git rm`） |
| 133 | 0 | `Features/S0/S0CategoryPageSelection.swift`（新） |
| 0 | 563 | `Features/S0/S0CategoryPageView.swift`（`git rm`） |
| 0 | 225 | `Features/S0/S0CategoryRow.swift`（`git rm`） |
| 22 | 0 | `Features/S0/S0CleanupDataProviding.swift`（新） |
| 6 | 0 | `Features/S0/S0CleanupFlowModel.swift`（并入 `S0CategoryPageRange`） |
| 38 | 21 | `Features/S0/S0DeckCategoryPageView.swift` |
| 8 | 17 | `Features/S0/S0DeckHomeView.swift` |
| 30 | 45 | `Features/S0/S0DeckMetrics.swift` |
| 0 | 273 | `Features/S0/S0HomeMetrics.swift`（`git rm`） |
| 0 | 409 | `Features/S0/S0SegmentBar.swift` → |
| 136 | 0 | `Features/S0/S0SegmentBarModel.swift`（`git mv` 后只留原 :1-136；相似度 33%，`git diff -M` 不认作改名，按删＋增计） |
| 61 | 0 | `Features/S0/S0Text.swift`（新） |
| 0 | 714 | `Features/S0/S0View.swift`（`git rm`） |
| 60 | 170 | `Localizable.xcstrings` |
| 64 | 28 | `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` |
| 110 | 499 | `PhotoCleanupMVETests/IC148S0VisualTests.swift` |
| 6 | 59 | `PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift` |
| 8 | 4 | `PhotoCleanupMVETests/IC153ScanServiceTests.swift` |
| 7 | 101 | `PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift` |
| 93 | 190 | `PhotoCleanupMVETests/IC156CategoryPageTests.swift` |
| 29 | 40 | `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` |
| 1 | 1 | `PhotoCleanupMVETests/IC162DeckPreviewTests.swift`（只改 :7 注释） |

### D `c7466fb`

| 加 | 删 | 路径 |
|---|---|---|
| 4 | 0 | `project.pbxproj` |
| 482 | 0 | `PhotoCleanupMVETests/IC165DeckFormalTests.swift`（新） |

### C′ `dc7e494`

| 加 | 删 | 路径 |
|---|---|---|
| 4 | 2 | `PhotoCleanupMVETests/IC147S0BehaviorTests.swift`（断言 11 的期望值 `[…]` → `Set([…])`，加两行注释） |

### 合计（`git diff --stat fbee8b1 096fb08`）

32 个文件，加 4895 行、删 3436 行；13 个新增、6 个删除、13 个修改（`--name-status -M`）。全部路径在卡面白名单内（逐文件对照见 self-check 第五节 G927）。

## 三、产品侧变更要点

**`Features/S0/`，改后 12 个文件**：
- `S0CategoryPageSelection`、`S0CleanupDataProviding`、`S0CleanupFlowModel`、`S0CleanupFlowView`
- `S0DeckCategoryPageView`、`S0DeckHomeModel`、`S0DeckHomeView`、`S0DeckMetrics`、`S0DeckZoomTransition`
- `S0SegmentBarModel`、`S0TabContainer`、`S0Text`

**`Features/Shared/`，新增两只**：`S0DeckCoverView`、`S0DeckAssetDates`。

### 流程文件 `S0CleanupFlowView.swift`

- A 取预览版原文。
- B 起只构造 `S0DeckHomeView(` 与 `S0DeckCategoryPageView(`，各 1 处；无 `else` 分支，无 `S0DeckPreview`。
- 根页 `.toolbar(.hidden, for: .navigationBar)` 1 处；类别页 toolbar 留在 Deck 页面内。

### 首页 `S0DeckHomeView.swift`

B 做的三件（裁定 四）：
1. **受限提示条**：顶排之下、大数字区之上的 `limitedBanner`。
   - 守卫 `machine.isLimitedAuthorization && machine.state != .failed`；文案 `s1.limited.banner`。
   - 取值 `S1LimitedBannerStyle.textFontSize／horizontalPadding／height／cornerRadius`；文字色 `S0DeckMetrics.text`。
   - 底 `.s1ChromeGlassBackground(in: RoundedRectangle(cornerRadius: S1LimitedBannerStyle.cornerRadius, style: .continuous), interactive: false)`；外边距 `S1ChromeLayout.horizontalMargin`／`chromeToOverlaySpacing`。
2. **扫描首帧**：`heroValue` 改 `@ViewBuilder`。
   - `machine.state == .scanning && machine.snapshot.libraryTotalByteCount == 0` 时显示 `Text(L10n.text("s0.home.hero.scanning"))`，字号 `S1ChromeTypography.titleFontSize`。
   - 否则照旧显示大字。判据不含 `cleanableByteCount`。
3. **`VF` 三态**：`pendingRow` 内 `if` 之后接 `verificationRow`（`switch machine.verificationState`）与 `pendingStatusText` helper。
   - `.none` → `EmptyView`；`.checking`；`.passed` 显示 `lastVerifiedReleasedByteCount`；`.failed`。
   - 字号 `pendingRowFontSize`，色 `S0DeckMetrics.text.opacity(S0DeckMetrics.pendingRowOpacity)`，横向内距 `totalBarHorizontalInset`。
   - 写入仍只在 `machine.beginVerification()` 一处。

裁定 五：
- 四态分派保持 `switch machine.state`。
- `withAnimation(` 恰 1（展开切换，切片内含 `expandAnimationResponse`／`expandAnimationDamping`）。

C 做的：
- 账户钮改 `S0DeckSymbol.account`；「其余照片」卡改 `L10n.text("s0.category.rest")`。
- 删 `cardOpacity(for:)` 与其唯一调用（即删未识别压暗分支，`stripAwaitingOpacity` 随之无引用）。
- 六处 `deck.home.*` 改 `s0.home.*`。

### 类别页 `S0DeckCategoryPageView.swift`

A：
- 取预览版 :1-955，以 :955 的 `}` 收尾。
- 两只 zoom 过渡类型（`S0DeckZoomSource`／`S0DeckZoomDestination`）连同文档注释搬到 `S0DeckZoomTransition.swift`，`#available(iOS 18.0, *)` 两处只在那个文件。

C：
- **八处改名**：`deck.page.*` 与首页共用的 `deck.home.share`。
- **副行**：由 `deck.home.open.subtitle` 改为 `s0.categoryPage.subtitle`，`{order}` 实参取 `sortOrderName`：
  - `.size` → `s0.categoryPage.sort.size`
  - `.newestFirst` → `s1.sort.newest_first`
  - `.oldestFirst` → `s1.sort.oldest_first`
- **两个返回钮**（页头圆钮、收起导航返回钮）各挂 `.accessibilityLabel(L10n.text("s0.categoryPage.back"))`。
- **勾符号**字号改 `gridCheckGlyphFontSize`。
- **toast 与底栏**改用 `toastFontSize／toastHorizontalPadding／toastVerticalPadding／toastCornerRadius／toastToDockSpacing`；页面内 `S2OverlayLayout` 归 0。
- **收起导航排序平涂圆钮**直径改 `compactNavBackSide`（42；预览取 `S1ChromeLayout.rowHeight` 44）。

### 三个新文件（C，类型体与其前 `///` 文档注释从 `fbee8b1` 逐字搬，只加文件头一句与 `import`）

- `S0CleanupDataProviding.swift`（`import Foundation`）：原 `S0View.swift:10-23` 的协议连同其前 :5-9 文档注释（新文件 :4-22 与原 :5-23 `diff` 为空），含 `var onSnapshotDidChange: (() -> Void)? { get set }` 要求行。
- `S0Text.swift`（`import Foundation`）：`S0ByteCountText`、`S0CategoryText`（五 case 不变）、`S0ByteCountSplit`、`S0CategoryPageDurationText`。
- `S0CategoryPageSelection.swift`（`import Combine`、`import Foundation`）：`S0CategoryPageSelection`（含 IC-160 的 `init(items:preselected:)`）与 `S0FeedbackToastPresenter`。

### 其余搬家与退役（C）

- `S0CategoryPageRange` 逐字并入 `S0CleanupFlowModel.swift` 末尾。App 的引用不变，App 目录树对象两侧相同。
- `S0SegmentBar.swift` 经 `git mv` 改名为 `S0SegmentBarModel.swift`，只留原 :1-136（文件头 + `import SwiftUI` + `S0SegmentBarModel`）。
- `git rm` 五个文件：`S0View`、`S0HomeMetrics`（含 `S0HomePalette`）、`S0CategoryRow`、`S0CategoryPageMetrics`（含 `S0CategoryPageSymbol`）、`S0CategoryPageView`。

## 四、目录 `Localizable.xcstrings`

条目数：`main` 253 → A 264 → C 起 254。`s0.` 38 → 39；`s0.categoryPage.` 6 → 9；`deck.` 0 → 11 → 0。修改方式是按既有键序插入与删块，未整体重序列化。

**A 新增（11 条 `deck.*`，值与 `562f8b7` 逐字相同）**：
- `deck.home.hero.label`、`deck.home.released`、`deck.home.share`
- `deck.home.bar.caption`、`deck.home.open.action`、`deck.home.open.subtitle`
- `deck.page.selected`、`deck.page.submit`、`deck.page.sort.size`
- `deck.page.month.count`、`deck.page.undated`

**C 删除（20 条）**：
- 上面 11 条 `deck.*`
- 作废 8 条：`s0.home.hero.growing`、`s0.home.hero.library`、`s0.home.hero.overlap`、`s0.home.legend.rest`、`s0.home.legend.unscanned`、`s0.home.category.counting`、`s0.home.category.empty`、`s0.home.category.waiting`
- `s0.categoryPage.longPressHint`

**C 新增（10 条）**：

| key | 值 |
|---|---|
| `s0.home.released` | 累计已腾出 |
| `s0.home.share` | 占 {percent} |
| `s0.home.bar.caption` | 占 {percent} · {bytes} |
| `s0.home.open.action` | 去清理 |
| `s0.home.open.subtitle` | {count} 项 · 从大到小 |
| `s0.category.rest` | 其余照片 |
| `s0.categoryPage.back` | 返回 |
| `s0.categoryPage.sort.size` | 从大到小 |
| `s0.categoryPage.month.count` | {count} 项 |
| `s0.categoryPage.undated` | 未知日期 |

**C 改值（4 条）**：

| key | `main` 值 | 新值 |
|---|---|---|
| `s0.home.hero.label` | 可清理约 | 可清理的空间 |
| `s0.categoryPage.selected` | 已选 {count} 项 · {bytes} | 已选 {count} 项 |
| `s0.categoryPage.submit` | 移入待删篮 · {count} 项 {bytes} | 移入待删篮 |
| `s0.categoryPage.subtitle` | {count} 个 · {bytes} · 按体积从大到小 | {count} 项 · {order} |

`deck.home.hero.label`／`deck.page.selected`／`deck.page.submit` 三条改名后落到的是 `main` 已有的 key，所以表现为「删 `deck.*` + 改既有值」，不另增条目。扫描器（双向门禁）在 A、B 报「目录 264 = 引用 264」，在 C、D、C′ 报「254 = 254」，残留 0。

## 五、登记值（`Features/S0/S0DeckMetrics.swift`）

`enum S0DeckMetrics`：预览 203 个 `static let` → 改后 **198**。

**删 11 个**（v3 未登记）：
- `sectionAction`、`sectionActionCornerRadius`、`sectionActionFontSize`、`sectionActionHeight`、`sectionActionHorizontalPadding`、`sectionActionItemSpacing`、`sectionActionRingOpacity`、`sectionActionRingWidth`
- `sectionTopSpacing`、`compactNavTopInset`、`stripAwaitingOpacity`

**加 6 个**（取值出处注明「SPEC-S0 v3 第十四节第 2 部分」）：

| 名 | 值 |
|---|---|
| `gridCheckGlyphFontSize` | 13 |
| `toastFontSize` | 15 |
| `toastHorizontalPadding` | 16 |
| `toastVerticalPadding` | 8 |
| `toastCornerRadius` | 27 |
| `toastToDockSpacing` | 8 |

**`colorSimilar` 改写（卡面缺口，值不变）**：预览里写作 `static let colorSimilar = sectionAction`，借用的正是要删的 `sectionAction`（`#F59B5B`）。删 `sectionAction` 后改为自带同值：`Color(.sRGB, red: 245.0 / 255, green: 155.0 / 255, blue: 91.0 / 255, opacity: 1)`，文档注释注明「IC-165 起不再借已删的节动作色，直接登记同值」。色值与预览逐位相同；名字数量不变。

**保留两个 0 引用的 v3 登记值**：`cellLabelFill`、`pageTitleTopSpacing`（后者预览未接线，见 self-check「发现但未处理」）。

`enum S0DeckSymbol` 共 8 个：预览 8 − `sparkle` + `account`（`"person.crop.circle"`，`main:S0View.swift` `S0HomeSymbol.account` 实读值）。改后依次为：`chevron`、`back`、`play`、`check`、`trash`、`sort`、`percentSign`、`account`。

B 删 `enum S0DeckPreview`（`isEnabled` 开关）。

## 六、`project.pbxproj`

**A 新增八组**：

| 文件 | fileRef | buildFile | group |
|---|---|---|---|
| `S0DeckMetrics.swift` | `…62` | `…5F` | S0 |
| `S0DeckHomeModel.swift` | `…63` | `…60` | S0 |
| `S0DeckCoverView.swift` | `…64` | `…61` | Shared |
| `S0DeckHomeView.swift` | `…65` | `…62` | S0 |
| `IC162DeckPreviewTests.swift` | `…66` | `…63` | Tests |
| `S0DeckCategoryPageView.swift` | `…67` | `…64` | S0 |
| `S0DeckAssetDates.swift` | `…69` | `…66` | Shared |
| `S0DeckZoomTransition.swift` | `…6A` | `…67` | S0 |

前七组沿用预览 id。Shared group 即 `ThumbnailView.swift` 所在组。

**C 新增三组**：

| 文件 | fileRef | buildFile |
|---|---|---|
| `S0CleanupDataProviding.swift` | `…6B` | `…68` |
| `S0Text.swift` | `…6C` | `…69` |
| `S0CategoryPageSelection.swift` | `…6D` | `…6A` |

**C 删五组**（每组 fileRef 3 处 + buildFile 2 处 = 4 行，共 20 行）：

| 文件 | fileRef | buildFile |
|---|---|---|
| `S0View` | `…49` | `…46` |
| `S0HomeMetrics` | `…4C` | `…49` |
| `S0CategoryRow` | `…4E` | `…4B` |
| `S0CategoryPageMetrics` | `…5B` | `…58` |
| `S0CategoryPageView` | `…5D` | `…5A` |

**C 改名**：`S0SegmentBar.swift` → `S0SegmentBarModel.swift`，id `…4D／…4A` 保留。

**D 新增一组**：`IC165DeckFormalTests.swift`，`…6E／…6B`。

改后最大号：fileRef `10000000000000000000006E`、buildFile `20000000000000000000006B`。撞号扫描、逐 id 计数与退役删净证据见 self-check 第五节 G928。

## 七、测试变更（项数 859 → 865）

| 文件 | 本卡前 | 本卡后 | 退役函数 | 主要改动 |
|---|---|---|---|---|
| `IC147S0BehaviorTests` | 16 | 16 | — | C：断言 C 改扫 Deck 首页，`showsCategoryRows` 恰 1 → `switch machine.state {` 恰 1 + `content` 分派段内三个 case 各 1（Lynn 裁定，见 self-check 第九节）；07／09／10／11 名单与路径；38 → 39；hero.label 值；借用集四条；新增 `slice`／`newline` 两个 helper（抄 IC157）。C′：断言 11 期望值改 `Set` |
| `IC148S0VisualTests` | 14 | 12 | `testIC148AAssertion01RegistryMatchesSpecSection14`、`testIC148…12SortsByBytesAndSinksEmpty` | `newProductFiles`／`viewFiles`／`viewBodyAnchors` 名单；02 改钉 `enum S0DeckMetrics`；03／04／05／06／07／10／11／13／14 按卡面第四节改写（05 四态锚、06 原地重写、11 `withAnimation(` 0 → 1 + 切片） |
| `IC151AmbientFixedColorTests` | 8 | 7 | `testIC151D_GlassSurfaceIsTranslucentFill` | `s0ViewPath` → Deck 首页；`D_S0Drops…` 删 `S2AmbientBackdropView()` 恰 1 那条 |
| `IC153ScanServiceTests` | 13 | 13 | — | `C_AppWiringAndS0ViewUntouched`：`machine.ingest` 改扫 Deck 首页，`onSnapshotDidChange` 与协议要求行改扫 `S0CleanupDataProviding.swift` |
| `IC155CategoryDataAndCoverTests` | 9 | 8 | `testIC155C_RowBuildsForAllCoverStates` | `C_CoverSlot…` 删 S0 段、留 Shared／S3 段；`s0ViewPath` → 协议文件 |
| `IC156CategoryPageTests` | 11 | 9 | `testIC156A_RegistryHasFortyTwoConstantsWithProvenance`、`testIC156A_MetricsValuesMatchCanvas` | B：断言 10 四个计数。C：6（纪律名单 → Deck 页 + 流程；`S0DeckMetrics.` 153；198 名逐个引用 + 豁免 `{cellLabelFill, pageTitleTopSpacing}`；`Image(systemName: ` 7；`DateComponentsFormatter` 改扫 `S0Text.swift`）、7（39／9／三条新值；页面 `s0.categoryPage.` 集合 = 九条、页面全部 key = 13 条；占位符）、9（路径 → Deck 页） |
| `IC157LongPressIntoS2Tests` | 8 | 8 | — | B4：`Button {` 3、`longPressHint` 0、删常驻行切片段、`Image(systemName: ` 7；B5：39／9／三条新值、四句 `39)` needle |
| `IC160SelectionSurvivesS2Tests` | 4 | 4 | — | B：断言 4 页面侧改扫 Deck 页、流程侧四个计数 |
| `IC162DeckPreviewTests` | — | 3 | — | A 新增；C 只改 :7 注释 |
| `IC163DeckPreviewRoundTwoTests` | 3 | 6 | — | A 整文件取 `562f8b7` 版（:1-249 与 `main` 相同） |
| `IC165DeckFormalTests` | — | 6 | — | D 新增六条（函数名见 self-check 第六节） |

退役 6 条，新增 3 + 3 + 6 = 12 条；859 − 6 + 12 = 865。

## 八、占位值登记

- **无出厂值变更**。本卡不碰 `Features/S2/S2Calibration.swift`，**`S2CalibrationConfiguration.schemaVersion` 仍 7**。
- `S0ScanRules.cacheSchemaVersion` 仍 1（`Services/` 目录树对象两侧相同）。
- `S0DeckMetrics` 的增删属 S0 视觉登记表，不入 `S2CalibrationConfiguration`，不涉及 Keychain 旧值覆盖。

## 九、与 SPEC-S0 v3 的三处暂时偏离（裁定 一，归 IC-166）

1. 「其余照片」卡仍不可进入（`S0DeckHomeModel.isEnterable` 与 `restCardID` 未动）。
2. hero 大数字仍取含 `D_全部` 的 `libraryTotalByteCount`（v3 要求 `LIB` 排除 `D_全部` 与账本）。
3. S0-3 判据仍按 `cleanableAssetCount == 0`（v3 要求 `N_成员 = 0`）。

## 十、摘取关系（惯例 40，克隆实测）

在 scratchpad 克隆里自 `fbee8b1` 逐个 `cherry-pick`，全部无冲突：

| 单元 | 结果树 | 对照 |
|---|---|---|
| A 单独 | `e012ac1468677568df82e8881938a16ea7cf28e9` | = `b6b8464` 的树 |
| A→B | `265ead14712637be217e9f9e54ba726e5a316d70` | = `5e96814` 的树 |
| A→B→C | `2cd65e75506d7b0ca383d072c72a75352dd558d5` | = `4b6929c` 的树 |
| A→B→C→C′→D | `7b8d2b24940be51716d9c605a8b284eb9a191270` | = `dc7e494` 的树，= 合并树 |

可摘单元：A、A→B、A→B→C→C′、A→B→C→C′→D。

- **C 不应脱离 C′ 单独摘**：C 里 IC147 断言 11 的比较与集合迭代顺序有关，每次进程随机，可能过也可能红（#331 是红的一次）。
- C′ 只动 IC147 一个文件，与 D 不相交，放在 D 之前或之后树都相同。
