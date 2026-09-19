# IC-162 变更清单（真机预览，探针分支，不合并）

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260919-162-deck-home-preview.md` |
| 基线 `main` | `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a` |
| 分支 | `probe/ic-162-deck-home-preview`（**不合并进 `main`**，与 `probe/ic-137-media-playback`、`probe/ic-145-scan-service`、`probe/ic-161-similar-photos` 同例） |
| 子项 A 提交 | `35a08eb758182cff03995116997533461d1e4241` `feat(IC-162): 子项 A「卡片叠」首页预览（编译期常量切换，旧首页一字未动）` |
| 子项 B 提交 | `a7ed9463ccd9f56451d5e33172d913f1dc944f8c` `feat(IC-162): 子项 B 新类别页与进页过渡（依赖 A，旧类别页一字未动）` |
| 订正提交 | `13adda1635bb50f61ff6eebd40fe60a03c5d0f6c` `fix(IC-162): 四处画布保真度订正（裁定 二与 r7／r9 逐条对读后发现）`——只改观感，不动行为、不动任何被钉计数、不新增登记值与 key |
| 报告 | 本文件与 `self-check.md`，另一个 docs 提交（同一分支、同一张卡，纪律 7） |
| 出厂值 | **无变更**。`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S2Calibration.swift` 不在 diff 里；本卡全部取值落在新文件 `S0DeckMetrics.swift` 的 `enum S0DeckMetrics` 里，不进配置、不上标定面板、不落盘 |
| 项数 | 856 + 4（A） + 2（B） = **862**（CI #325／#326 各一次实证） |
| CI | #325（`a7ed946`）与 #326（`13adda1`）各一次绿，均 862 项 0 失败；**Lynn 装 #326 的产物** `PhotoCleanupMVE-unsigned-13adda1635bb`（id `10587817557`，有效期至 2026-12-18T16:16:03Z） |
| 摘取关系 | A 单独可摘；**B 依赖 A**（B 往 A 新建的三个文件追加、引用 A 的登记常量），只能作 A→B 连续序列 |

## 二、文件清单（`git diff --numstat 091b60e 13adda1`，全部在白名单内）

| 文件 | 合计增／删 | 白名单条目 | A | B | 订正 |
|---|---|---|---|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift`（新，831 行） | +831／−0 | A 新建 | +831 | — | — |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift`（新，123 行） | +123／−0 | A 新建；B 只追加 `sections` | +113 | +10 | — |
| `PhotoCleanupMVE/Features/S0/S0DeckCoverView.swift`（新，116 行） | +116／−0 | A 新建 | +116 | — | — |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift`（新，1 162 行） | +1162／−0 | A 新建；B 只加命名空间形参与过渡修饰符 | +1121 | +10／−1 | +37／−5 |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift`（新，979 行） | +979／−0 | B 新建 | — | +976 | +23／−20 |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | +86／−32 | A 仅 `homeScreen` 与两只新方法、`page(for:)` 的 `onBack` 闭包体；B 仅 `page(for:)` 的 if／else、`@Namespace` 一行、首页新分支多一个实参 | +38／−15 | +50／−19 | — |
| `PhotoCleanupMVE/Localizable.xcstrings` | +132／−0 | A 七条 `deck.home.*`；B 五条 `deck.page.*` | +77 | +55 | — |
| `PhotoCleanupMVETests/IC162DeckPreviewTests.swift`（新，284 行） | +284／−0 | A 断言 1～4；B 断言 5～6 | +209 | +75 | — |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +24／−0 | A 五个文件登记；B 一个 | +20 | +4 | — |

合计 **9 个路径**，与白名单逐条对应，白名单之外零改动（G913）。订正提交只落在两个新视图文件上，不碰白名单里的其余七个路径。

### 订正提交逐条（`13adda1`）

| # | 处 | 改动 | 依据 |
|---|---|---|---|
| 1 | `S0DeckHomeView.stripRow` | 「其余照片」卡不再画右箭头（只有 `isEnterable` 的条才画） | 裁定 二「不可点、无右箭头」；与 `S0CategoryRowPresentation.showsDisclosure` 同口径 |
| 2 | `S0DeckHomeView.cardSurface` | 卡上补一道上缘高光描边 | `r7.py .dk .edge` 是**两道** inset 阴影：`inset 0 0 0 0.5px rgba(255,255,255,0.12)` 与 `inset 0 0.5px 0 rgba(255,255,255,0.34)`；原本只实装了前者 |
| 3 | `S0DeckHomeView`（新增 `S0DeckTopHighlight`）与 `S0DeckGlassPanel` | 顶缘高光由整圈 0.34 描边改竖向渐变（上 0.34 → 下 0） | 同上 CSS 只亮上缘；取值仍是登记的 `glassTopHighlightOpacity`／`glassTopHighlightWidth`，零新数 |
| 4 | `S0DeckCategoryPageView.topSectionHeader` | 网格空了时整节不画 | 整类进了待删篮后会读出「最大的 0 个」「全选这 0 个」；与第二节 `restSectionHeader` 同口径 |

## 三、逐项变更

### 子项 A · 首页

| 处 | 位置 | 变更 |
|---|---|---|
| A1 | `Features/S0/S0DeckMetrics.swift`（新） | `enum S0DeckPreview { static let isEnabled = true }`（裁定 一的唯一开关）；`enum S0DeckSymbol` 七个符号字面量（`chevron`／`back`／`sparkle`／`play`／`check`／`trash`／`percentSign`，一律 `static let`，不经 `return`——陷阱 18）；`enum S0DeckMetrics` **一族 `static let`**，覆盖色（底／字／强调／青绿／节动作／卡底）、六个类别色、四个玻璃填充与顶缘高光、大数字区、总条、卡片叠、展开卡、收起条、类别页页头、分节、网格、底栏、收起后的导航、展开动画、分节上限；每个常量的定义处注明取自 `r7.py`／`r8.py`／`r9.py` 的哪条 CSS。另有两个**派生**（不是登记值）：`categoryColor(for:)`／`cardColor(for:)` 与 `dimmedText(opacity:)`。 |
| A2 | `Features/S0/S0DeckHomeModel.swift`（新） | 纯函数层，只 `import Foundation`。`static let restCardID = "__rest__"`；`struct Card: Equatable, Identifiable`（`id`／`category`／`byteCount`／`fraction`／`percent`／`isEnterable`）；`cards(categories:restByteCount:libraryTotalByteCount:)`（保 `hasItems`、保入参序、`LIB ≤ 0` 时占比 0、`restByteCount > 0` 才追加其余卡且恒不可点）；`defaultOpenID(_:)`；`resolvedOpenID(current:cards:)`；`topSum(_:limit:)`。 |
| A3 | `Features/S0/S0DeckCoverView.swift`（新） | 宽幅封面，**本分支唯一 `import Photos` 的新文件**（裁定 三）。`targetPixelSize(width:height:displayScale:)`；`requestImage(for:targetSize:contentMode:options:)` 实参 `contentMode: .aspectFill`、`deliveryMode = .opportunistic`、`resizeMode = .fast`、`isNetworkAccessAllowed = false`；`onAppear` 取、`onDisappear` 取消；**两道换图防护**——内部 `.onChange(of: assetIdentifier)` 取消旧请求、代次自增、清图重取，回调里 `guard currentGeneration == generation`，加上每个构造点挂 `.id(assetIdentifier)`；取不到图显示 `S0DeckMetrics.cardBase`（`#161B18`）纯色底、不放占位图标；先 `.frame(width:height:)` 后 `.clipped()`（陷阱 24）。 |
| A4 | `Features/S0/S0DeckHomeView.swift`（新） | 首页本体。形参与默认值照抄 `S0View.init` 的八个。`body` 最外层 `.onAppear { bootstrapIfNeeded() }`，该方法与 `hasBootstrapped` 逐字照抄 `S0View.swift:615-631`。顶排照 `S0View.topRow` 的件与回调（`s0.home.title`、待删篮胶囊、人像圆钮，仍借 `s1ChromeGlassBackground(in:interactive:)`／`s1ChromeCircleGlass()`）。大数字取 `machine.snapshot.libraryTotalByteCount`（④ 第 187 条）。扫描中在大数字下加 `s0.home.hero.progress`。`cumulativeReleasedByteCount > 0` 才画「累计已腾出」。等待清空行与「我已清空」（`machine.beginVerification()`）照旧。总条走 `S0SegmentBarModel.make(...)`，当前段不透明度 1、其余 `0.38`，标注行跟着展开卡变。卡片叠：`ZStack` + 每张卡 `.offset(y:)` + `.zIndex`，展开／收起一次 `withAnimation(.spring(response: 0.42, dampingFraction: 0.86))`，无定时器、无逐帧驱动（陷阱 6）。「建议先清」角标在 `.onAppear` 与 `.onChange(of: suggestionKey)` 里算好放 `@State`（键 = 类别 id + 候选数 + 候选字节量）。四态：`.ready`／`.scanning` 走整套版式，`.empty`／`.failed` 居中显示既有标题 key 与动作按钮。 |
| A5 | `Features/S0/S0CleanupFlowView.swift` | `homeScreen` 加 `@ViewBuilder` 与 `if S0DeckPreview.isEnabled { 新 } else { 旧 }`，**旧构造的实参逐字不动**；两只闭包外提成 `enterCategory(_:)`／`leaveCategory()`（原闭包里的注释挪到方法上），新旧共用；`page(for:)` 里只把 `onBack` 闭包体换成 `leaveCategory()`。 |
| A6 | `Localizable.xcstrings` | 加七条：`deck.home.open.action`／`deck.home.share`／`deck.home.suggest`／`deck.home.released`／`deck.home.bar.caption`／`deck.home.hero.label`／`deck.home.open.subtitle`，取值与卡面逐字一致。**文本插入**（不整体重序列化），其余 253 条条目字节未动。 |
| A7 | `project.pbxproj` | 登记五个文件。加登记前重扫当前最大号：fileRef `…61`、buildFile `…5E`；新号 fileRef `…62`～`…66`、buildFile `…5F`～`…63`，逐个核对仓内出现次数为 0 后再写（CLAUDE.md：撞号不报错、后登记的文件静默掉出编译列表）。 |
| A8 | `IC162DeckPreviewTests.swift`（新） | 断言 1～4，**只测纯函数**：不构造视图、不碰 PhotoKit。 |

### 子项 B · 类别页与过渡

| 处 | 位置 | 变更 |
|---|---|---|
| B1 | `Features/S0/S0DeckCategoryPageView.swift`（新） | 新类别页。多收一个 `machine: S0StateMachine`（`@ObservedObject`），页头与收起后的导航条要画「占比角标 + 总条」，库总量与段模型从 `machine.snapshot` 在本文件内自取，流程文件里不为它算任何东西。页头 = 262 高宽幅封面 + 压暗渐变 + 返回／全选（借 S1 chrome）+ 名称、体积、副行、占比角标 + 总条，随内容一起滚走。滚过阈值切 `@State isHeaderCollapsed`（**只在跨阈值时写**，静止不写——陷阱 5），顶上出现玻璃导航（返回 · 名称 体积 占比 · 全选）。两节网格：`最大的 N 个`（N = `min(10, 总数)`，右侧「全选这 N 个」并入已选）与 `其余 M 个`（为空时整节不画）。行为逐条照 `S0CategoryPageView`：勾选、全选、长按进 S2（`.simultaneousGesture(LongPressGesture())`，`Button` 语义保留）、`onMoveToBasket` 返回 `true` 后 `selection.remove(ids:)` + toast、零选中主按钮禁用不隐藏。保留集按 IC-160 口径直接读写 `flowModel.preservedSelection`（`init` 按「保留集 ∩ 当前列表」播种，根视图 `.onChange(of: selection.selected)` 与 `.onAppear` 两处回报）；`flowModel` 以**普通 `let`** 持有，不 `@ObservedObject`——`preservedSelection` 不发布，写它不该引起重求值。两层 `.toolbar(.hidden, ...)` 由本页自己挂。 |
| B2 | 同文件 | 另有四个文件内类型：`S0DeckPageShade`（页头压暗渐变）、`S0DeckGlassPanel`（半透明玻璃面 + 顶缘高光，**不用系统材质**）、`S0DeckZoomSource`／`S0DeckZoomDestination`（各包一只 `ViewModifier`，`#available(iOS 18.0, *)` 只出现在这里；iOS 17 原样返回 `content`，走默认 push）。 |
| B3 | `Features/S0/S0DeckHomeModel.swift` | 只追加 `sections(_:topLimit:)`：前 `topLimit` 项为 `top`、其余为 `rest`，总数 ≤ `topLimit` 时 `rest` 为空，两节都保入参顺序。 |
| B4 | `Features/S0/S0DeckHomeView.swift` | 只加两处：`private let transitionNamespace: Namespace.ID` 与 `init` 末位形参（`Namespace.ID` 没有缺省值，故排在带缺省值的八个之后）；卡上 `.modifier(S0DeckZoomSource(id: card.id, namespace: transitionNamespace))`。 |
| B5 | `Features/S0/S0CleanupFlowView.swift` | `@Namespace private var deckNamespace` 一行；`page(for:)` 加 if／else，新分支传 `machine`／`flowModel`／`onBack: { leaveCategory() }`／`transitionNamespace: deckNamespace` 与三个与旧分支同值的实参；`homeScreen` 新分支多传 `transitionNamespace: deckNamespace`。**旧分支的实参与两层 `.toolbar` 逐字不动。** |
| B6 | `Localizable.xcstrings` | 加五条：`deck.page.top.title`／`deck.page.top.action`／`deck.page.rest.title`／`deck.page.selected`／`deck.page.submit`。 |
| B7 | `project.pbxproj` | 再登记一个文件。重扫最大号 fileRef `…66`、buildFile `…63`；新号 `…67`／`…64`，仓内出现次数 0。 |
| B8 | `IC162DeckPreviewTests.swift` | 类尾追加断言 5～6，与 A 的四条之间隔一行 `// MARK: - 子项 B`。 |

## 四、文案登记（本卡新增 12 条，全部 `deck.` 前缀）

| key | zh-Hans 值 | 引用点 | 子项 |
|---|---|---|---|
| `deck.home.hero.label` | `可清理的空间` | 首页大数字标签 | A |
| `deck.home.released` | `累计已腾出` | 首页右上 | A |
| `deck.home.bar.caption` | `占 {percent} · {bytes}` | 总条标注行 | A |
| `deck.home.share` | `占 {percent}` | 展开卡左上角标、类别页页头与收起后导航的占比 | A |
| `deck.home.suggest` | `建议先清 · 最大 {count} 个 {bytes}` | 展开卡右上角标 | A |
| `deck.home.open.subtitle` | `{count} 项 · 从大到小` | 展开卡副行、类别页页头副行 | A |
| `deck.home.open.action` | `去清理` | 展开卡右下 | A |
| `deck.page.top.title` | `最大的 {count} 个` | 类别页第一节标题 | B |
| `deck.page.top.action` | `全选这 {count} 个` | 类别页第一节动作 | B |
| `deck.page.rest.title` | `其余 {count} 个` | 类别页第二节标题 | B |
| `deck.page.selected` | `已选 {count} 项` | 底栏左 | B |
| `deck.page.submit` | `移入待删篮` | 底栏右 | B |

**复用的既有 key（未新增、未改值）**：`s0.home.title`、`s0.basket.capsule`、`s0.account.title`、`s0.home.hero.progress`、`s0.home.pending.label`、`s0.home.pending.action`、`s0.home.hero.empty.title`、`s0.home.hero.empty.action`、`s0.home.failed.auth.title`／`.action`、`s0.home.failed.read.title`／`.action`、`s0.home.legend.rest`、`s0.category.*`（经 `S0CategoryText.displayName(for:)`）、`s0.categoryPage.selectAll`、`s0.categoryPage.toast`。

`{percent}` 的实参形如 `36%`：百分号在实参里由 `String(percent) + S0DeckSymbol.percentSign` 拼，不写进目录值以外的字面量。

目录 `s0.` 前缀 key **仍恰 38**；`deck.` 前缀 12；条目合计 253 → **265**。

## 五、占位值登记

**本卡不改任何出厂值**：`S2CalibrationConfiguration.schemaVersion` 仍 **7**，`S2Calibration.swift` 不在 diff 里。新增的取值全部是视图登记制常量（`S0DeckMetrics`），与 `S0HomeMetrics`／`S0CategoryPageMetrics` 同制——不进配置、不上标定面板、不落 Keychain。`S0HomeMetrics` 仍 52 个、`S0CategoryPageMetrics` 仍 42 个（两文件两侧 SHA-256 相同）。

## 六、pbxproj 撞号扫描与新登记 id

登记前对**当前** `project.pbxproj` 全量 `\b[0-9A-F]{24}\b` 取最大号，再逐个核对候选 id 的出现次数为 0；两个子项各扫一次。

| 子项 | 扫描时最大 fileRef | 扫描时最大 buildFile | 新登记 |
|---|---|---|---|
| A | `100000000000000000000061` | `20000000000000000000005E` | `S0DeckMetrics.swift` `…0062`／`…005F`；`S0DeckHomeModel.swift` `…0063`／`…0060`；`S0DeckCoverView.swift` `…0064`／`…0061`；`S0DeckHomeView.swift` `…0065`／`…0062`；`IC162DeckPreviewTests.swift` `…0066`／`…0063` |
| B | `100000000000000000000066` | `200000000000000000000063` | `S0DeckCategoryPageView.swift` `…0067`／`…0064` |

六个文件各在 pbxproj 里出现 6 次（buildFile 行 2 + fileRef 行 2 + 组内 1 + Sources 构建阶段 1）。

## 七、范围边界

本卡**未触碰**：`S0View.swift`、`S0CategoryPageView.swift`、`S0TabContainer.swift`、`S0CleanupFlowModel.swift`、`App/`、`Core/`、`Services/`、`ThumbnailView.swift`、全部既有测试文件、`.github/`、`Scripts/`、`S0HomeMetrics.swift`、`S0CategoryPageMetrics.swift`、`S0SegmentBar.swift`、`S0CategoryRow.swift`（逐文件 SHA-256 两侧相同，表见 `self-check.md` G913）。

未做（卡面范围外）：「视频」类取代「大视频」、「其余照片」可进入、相似照片、账本与「本月已腾出」、类目内 tag、截图三列密排、组视图、首页待删篮胶囊 → S3、账户页、SPEC 与 Decision_log、合并进 `main`。
