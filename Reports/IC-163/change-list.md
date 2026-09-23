# IC-163 变更清单（真机预览第二轮，探针分支，不合并；A、D 可单独摘到 `main`）

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260922-163-deck-home-preview-r2.md` |
| 基线 | `probe/ic-162-deck-home-preview` = `180b052edf24f168712c6e58754c60b88b342175`（**不是 `main`**；`main` = `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a` 是它的祖先，`is-ancestor` 退出码 0） |
| 分支 | `probe/ic-163-deck-home-preview-r2`，从 `180b052` 切，**不合并** |
| 子项 A 提交 | `105ada3f4acc9b5ad5ae9efb6cfb22b503ee1f0e` `fix(IC-163): 子项 A S2 写回只覆盖交接列表内的标记，类别篮不被抹（裁定 一，可摘到 main）` |
| 子项 D 提交 | `088e4b1deb7b38bd7fb333d149d9561a9b23a171` `feat(IC-163): 子项 D「视频」类取代「大视频」——全部已解析视频，录屏优先归录屏（裁定 五，可摘到 main）` |
| 子项 B 提交 | `9fd4c093f990c179179da2fc9e2fc0bee461d770` `fix(IC-163): 子项 B 首页两修一删——命中区收回卡内、展开切换过渡、撤销「建议先清」角标（裁定 二、三）` |
| 子项 C 提交 | `0b3dd0321ff8e347519b5572943587810de3aac8` `feat(IC-163): 子项 C 类别页三改——撤「最大的 N 个」、四处系统玻璃、排序钮与按月分节（裁定 三、四，依赖 B）` |
| 提交顺序 | A → D → B → C（卡面顺序），四个提交各自独立 |
| 报告 | 本文件与 `self-check.md`，另一个 docs 提交（同一分支、同一张卡，纪律 7） |
| 出厂值 | **无变更**。`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S2Calibration.swift` 不在 diff 里。本卡新登记值只进 `S0DeckMetrics`（不进配置、不上标定面板、不落盘）。扫描缓存 `S0ScanRules.cacheSchemaVersion` 仍 **1**（缓存只存原始证据，分类读缓存时现算） |
| 项数 | 862 → A 865 → D 865 → B 864 → C **865** |
| 摘取关系 | **A 单独可摘到 `main`**；**D 单独可摘到 `main`**；A→D 连续也可（克隆实测三种都无冲突，见第八节）。B 依赖 IC-162 链；C 依赖 B（同改 `S0DeckHomeModel`／`S0DeckMetrics`／目录／`IC162DeckPreviewTests`）与 A（往 A 新建的测试文件类尾追加），按提交不能脱离 A、B 单独摘取 |

## 二、文件清单（`git diff --numstat 180b052 0b3dd03`，全部在白名单内）

| 文件 | 合计增／删 | 白名单条目 | A | D | B | C |
|---|---|---|---|---|---|---|
| `PhotoCleanupMVE/Core/SessionStore.swift` | +3／−1 | A：`applyS2Return` 那一句赋值 + 取 `previous` 一行 | +3／−1 | — | — | — |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | +9／−4 | A：`applyPendingDeletionDiff` 签名与取消循环、两处调用实参 | +9／−4 | — | — | — |
| `PhotoCleanupMVE/Services/S0ScanRules.swift` | +1／−6 | D：删 `bigVideoMinimumByteCount` 一条登记与注释 | — | +1／−6 | — | — |
| `PhotoCleanupMVE/Services/S0ScanClassifier.swift` | +2／−2 | D：`hits` 里视频那一段 | — | +2／−2 | — | — |
| `PhotoCleanupMVE/Features/S0/S0DeckCoverView.swift` | +3／−0 | B：`contentShape` | — | — | +3 | — |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | +72／−148 | B：`contentShape`、过渡、删角标 | — | — | +72／−148 | — |
| `PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift` | +19／−44 | B：加 `expandContentRise`、删角标六个；C：删 `glassFill`／`dockFill`／`topSectionLimit`，加 `S0DeckSymbol.sort`／`monthSectionCountFontSize`／节间距 | — | — | +4／−18 | +15／−26 |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift` | +75／−17 | C：删 `sections`／`topSum`，加 `SortOrder`／`MonthSection`／`sorted`／`monthSections` | — | — | — | +75／−17 |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | +176／−170 | C | — | — | — | +176／−170 |
| `PhotoCleanupMVE/Features/S0/S0DeckAssetDates.swift`（新，21 行） | +21／−0 | C 新建 | — | — | — | +21 |
| `PhotoCleanupMVE/Localizable.xcstrings` | +9／−20 | D：改 `s0.category.bigVideo` 的值；B：删 `deck.home.suggest`；C：删三加三 | — | +1／−1 | −11 | +8／−8 |
| `PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift`（新，370 行） | +370／−0 | A 新建；C 类尾追加 | +250 | — | — | +120 |
| `PhotoCleanupMVETests/IC153ScanServiceTests.swift` | +32／−34 | D：只改期望值、字面量与注释 | — | +32／−34 | — | — |
| `PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift` | +10／−9 | D：同上 | — | +10／−9 | — | — |
| `PhotoCleanupMVETests/IC162DeckPreviewTests.swift` | +5／−109 | B：删 `testIC162A_TopSumClampsToCount`；C：删两条测试与 `assets(count:)` | — | — | +2／−25 | +3／−84 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +8／−0 | A：测试文件登记；C：新文件登记 | +4 | — | — | +4 |

合计 **16 个路径**，与白名单逐条对应，白名单之外零改动（G917）。`S0CleanupFlowView.swift`、`S0View.swift`、`S0CategoryPageView.swift`、`S0CleanupFlowModel.swift`、`App/`、`Services/` 里除 D 两个文件之外的一切、`Features/S1`～`S5`、`ThumbnailView.swift`、`.github/`、`Scripts/` 零改动。

## 三、逐项变更

### 子项 A · S2 写回不抹类别篮（裁定 一）

| 处 | 位置 | 变更 |
|---|---|---|
| A1 | `Core/SessionStore.swift` `applyS2Return` | 原 `pendingDeletionAssetIDsByRangeID[rangeID] = returned.pendingDeletionAssetIDs`（整个覆盖）改为先取 `let previous = nextState.pendingDeletionAssetIDsByRangeID[entryContext.rangeID] ?? []`，再赋 `previous.subtracting(assetIDSet).union(returned.pendingDeletionAssetIDs)`；`assetIDSet` 用 guard 上方既有的那个。另加一行注释。`firstMarkedRangeIDByAssetID` 的过滤与其后的守卫一字未动。 |
| A2 | `Core/S1StateMachine.swift` `applyPendingDeletionDiff` | 加形参 `scope: Set<String>`；取消循环由 `previous.subtracting(new)` 改为 `previous.intersection(scope).subtracting(new)`；新增标记循环不变。函数文档注释追加两行说明。 |
| A3 | 同文件两处调用 | 虚拟范围路径与真实范围路径各加实参 `scope: Set(entryContext.orderedAssetIDs)`。`makeS2Handoff(for:)`、`makeS2Handoff(virtualRangeID:…)` 与交接列表口径**一字未动**。 |
| A4 | `IC163DeckPreviewRoundTwoTests.swift`（新） | 三条测试 + 照抄 IC157 的私有 `makeMachine(state:…)`（`.ready` 分支不带默认范围，由调用方给）。 |
| A5 | `project.pbxproj` | 四行登记，插在 `main` 上也有的四个锚行之后（见第五节）。 |

`git diff main -- PhotoCleanupMVE/Core/` 只含 `SessionStore.swift`（+3／−1）与 `S1StateMachine.swift`（+9／−4），变更行合计 17 ≤ 30。

### 子项 D · 「视频」类取代「大视频」（裁定 五）

| 处 | 位置 | 变更 |
|---|---|---|
| D1 | `Services/S0ScanRules.swift` | 删 `bigVideoMinimumByteCount: Int64 = 100_000_000` 及其三行注释与一个空行；类型文档「恰七个常量」改「恰六个常量」。 |
| D2 | `Services/S0ScanClassifier.swift` `hits(...)` | 视频段由「录屏证据命中 → 插 `.screenRecording`；字节 ≥ 门槛 → 插 `.bigVideo`（两者可同时）」改为 `if 录屏证据命中 { .screenRecording } else { .bigVideo }`，加一行注释。未解析仍在函数开头 `guard` 返回空集。`attributionPriority` 与 `main` 逐字相同；形参 `byteCount` 保留（签名不变，测试直调它）。 |
| D3 | `Localizable.xcstrings` | `s0.category.bigVideo` 的值 `大视频` → `视频`。key、枚举 case `bigVideo`、虚拟范围 `cat:bigVideo` 一律不改名。 |
| D4 | `IC153ScanServiceTests.swift`、`IC155CategoryDataAndCoverTests.swift` | 规则变更、测试随之改，逐行见第四节。两份文件的 `func test` 数与 `main` 相同（13／9）。 |

`git diff main -- PhotoCleanupMVE/Services/` 只含这两个文件，变更行 10 ≤ 20。旧首页 `S0View`／`S0CategoryRow` 等只经 `displayName(for:)` 取名，一字未动。

### 子项 B · 首页两修一删（裁定 二、三）

| 处 | 位置 | 变更 |
|---|---|---|
| B1 | `S0DeckCoverView.body` | `.clipped()` 之后加 `.contentShape(Rectangle())`（加两行注释）。类别页格子与页头同用此视图，随之修好。 |
| B2 | `S0DeckHomeView.cardSurface` | `.clipShape(RoundedRectangle(cardCornerRadius, .continuous))` 之后加同形 `.contentShape(...)`（加两行注释）。 |
| B3 | `S0DeckHomeView.cardContent` | 展开切换过渡。原来是 `if isOpen { cover.overlay…×5 } else { cover.overlay…×2 }` 两支；改为**一只封面 + 六个 `overlay`，每个 overlay 里各自 `if isOpen`／`if !isOpen`**：大字块、「去清理」、左上占比角标三层 `.transition(Self.openContentTransition)`（= `AnyTransition.opacity.combined(with: .offset(y: expandContentRise))`，静态计算属性），收起条一行 `.transition(.opacity)`；两道压暗渐变不写过渡（默认淡入淡出）。封面挂 `.id(coverAssetID).id(isOpen)`——保持改前「展开态一变就按新尺寸新建封面、重取图」的行为（改前两支各建一只封面，效果相同）。节奏仍是 `expandCard` 里既有的 spring（0.42／0.86 不改），无定时器、无逐帧驱动。**为什么改结构**（③）：整支 `if`／`else` 换掉时，嵌在被插入分支内部的 `.transition` 不保证生效；让每层自己成为被插入／移除的视图，过渡才确定作用在它身上。 |
| B4 | `S0DeckHomeView` 删角标 | 删 `@State suggestion` 与注释、`.onAppear` 里的 `refreshSuggestion()`、`.onChange(of: suggestionKey)`、右上角标 overlay、`suggestBadge`、`suggestionKey`／`refreshSuggestion` 整节、`S0DeckSuggestionKey`／`S0DeckSuggestion` 两个结构体。`dataProvider` 仍由 `bootstrapIfNeeded()` 使用。 |
| B5 | `S0DeckMetrics.swift` | 删 `suggestBadgeHeight`／`CornerRadius`／`LeadingPadding`／`TrailingPadding`／`ItemSpacing`／`FontSize` 六个；加 `expandContentRise: CGFloat = 8`（注明出处）。`topSum` 与 `topSectionLimit` 在 B 里不删（类别页仍在用），B 提交后可编译。 |
| B6 | `Localizable.xcstrings` | 删 `deck.home.suggest`（11 行块）。 |
| B7 | `IC162DeckPreviewTests.swift` | 删 `testIC162A_TopSumClampsToCount`，原位留两行注释说明。 |

### 子项 C · 类别页三改（裁定 三、四）

| 处 | 位置 | 变更 |
|---|---|---|
| C1 | `S0DeckCategoryPageView` 分节 | 删 `sectionsAndGrids`／`topSectionHeader`／`restSectionHeader`／`sectionAction`／`selectTopSection`。`sectionHeader` 改为 `sectionHeader(title:count:)`：左节名 15／semibold、`Spacer`、右计数 `deck.page.month.count`（12.5，压暗 `sectionTitleDimmedOpacity` 0.55），高、左右内距沿用原节标题，顶距 `monthSectionSpacing`（12），不带动作钮。 |
| C2 | 同文件网格 | 新 `gridContent(width:)`：`.size` 下整页一张网格；`.newestFirst`／`.oldestFirst` 下 `ForEach(monthSections(…), id: \.monthStart)` 逐节「节标题 + 网格」。`grid(_:width:topSpacing:)` 加顶距形参：整页那张网格取 `monthSectionSpacing`（12，「首节距页头 12」同口径），节内网格取既有 `sectionToGridSpacing`（6）。 |
| C3 | 同文件玻璃四处 | 收起导航条 `s1ChromeGlassBackground(in: RoundedRectangle(compactNavCornerRadius), interactive: true)`；底栏同上（`dockCornerRadius`，`interactive: true`）；格底标签条（`gridLabelCornerRadius`）与 toast（`compactNavCornerRadius`）`interactive: false`。圆角与尺寸沿用现有登记值，只换填充。删 `S0DeckGlassPanel`。玻璃容器里的钮不套玻璃：收起导航里的「全选」保持 `text.opacity(0.10)` 平涂胶囊、新排序钮用同一平涂（圆形），底栏主按钮保持 `#FFFBF5` 实心；页头返回圆钮与「全选」胶囊原本就借 S1 玻璃、不动。 |
| C4 | 同文件排序 | `@State sortOrder: S0DeckHomeModel.SortOrder = .size`、`@State dates: [String: Date]? = nil`。`sortMenu(label:)`：`Menu { Picker(L10n.text("s1.sort.accessibility"), selection: $sortOrder) { 三个 Text(...).tag(...) } } label: { … }`，整只 `.disabled(dates == nil)`，`accessibilityLabel(s1.sort.accessibility)`。页头一只（`Image(systemName: S0DeckSymbol.sort).s1ChromeCircleGlass()`，照返回钮写法，44）、收起导航一只（44 圆、平涂底），都在「全选」左侧、间距 `S1ChromeLayout.itemSpacing`（8）。 |
| C5 | 同文件取日期 | 根视图 `.task(id: selection.items.map(\.id))` 里 `await Task.detached(priority: .userInitiated) { S0DeckAssetDates.creationDates(forLocalIdentifiers: ids) }.value`，未取消才写 `dates`。 |
| C6 | 同文件派生 | `displayedItems` = `S0DeckHomeModel.sorted(selection.items, by: sortOrder, dates: dates ?? [:])`；`monthTitle(for:)`：有日期 `DateFormatter` + `locale = Locale.current` + `setLocalizedDateFormatFromTemplate("yMMMM")`，无日期 `deck.page.undated`。长按交接改传 `displayedItems.map(\.id)`（网格当前显示顺序）。进篮后 `selection.remove(ids:)` 不变。 |
| C7 | 同文件文档注释 | 类型文档里「网格分两节」「不用系统材质」两处改写为现状。 |
| C8 | `S0DeckAssetDates.swift`（新） | `enum S0DeckAssetDates { static func creationDates(forLocalIdentifiers ids: [String]) -> [String: Date] }`：`PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)` 一次取全、`enumerateObjects` 遍历成字典，`creationDate` 为 nil 的不入字典。本分支第二个 `import Photos` 的 Deck 文件。 |
| C9 | `S0DeckHomeModel.swift` | 删 `topSum`／`sections`；加 `enum SortOrder { size, newestFirst, oldestFirst }`、`struct MonthSection: Equatable { monthStart: Date?; items: [S0CategoryAsset] }`、`sorted(_:by:dates:)`（`.size` 原样；时间序按日期、同日期按 id 升序、无日期的排最后且保持入参相对序）、`monthSections(_:dates:calendar:)`（按 `calendar.dateComponents([.year, .month])` 归组，节序按首次出现，节内随入参；无日期归最后一节 `monthStart = nil`；`monthStart = calendar.date(from: 年月)` 即该月 1 日 0 点）。仍只 `import Foundation`。 |
| C10 | `S0DeckMetrics.swift` | 删 `glassFill`、`dockFill`（连注释）与 `topSectionLimit`（连所在 MARK 节）；加 `S0DeckSymbol.sort = "arrow.up.arrow.down"`、`monthSectionCountFontSize: CGFloat = 12.5`、`monthSectionSpacing: CGFloat = 12`（各注明出处）。类型文档「不用系统材质」一句改写。 |
| C11 | `Localizable.xcstrings` | 删 `deck.page.top.title`／`deck.page.top.action`／`deck.page.rest.title`；加 `deck.page.sort.size` = `从大到小`、`deck.page.month.count` = `{count} 项`、`deck.page.undated` = `未知日期`。文本插入、按既有键序落位，不整体重序列化。 |
| C12 | `IC162DeckPreviewTests.swift` | 删 `testIC162B_SectionsSplitAtLimit`、`testIC162B_SelectingTopSectionUnionsIntoSelection` 与只剩它们用的 `assets(count:)`，原位留注释。 |
| C13 | `IC163DeckPreviewRoundTwoTests.swift` | 类尾 `// MARK: - 子项 C` 追加三条纯函数测试与三个夹具（固定公历 + UTC 的 `Calendar`、正午日期、体积递减的资产列表）。 |
| C14 | `project.pbxproj` | `S0DeckAssetDates.swift` 四行登记（app target）。 |

## 四、子项 D 两份测试的旧→新逐行登记（行号为 `main` 侧；`main` 与 `180b052` 上这两份文件逐字相同）

先用 Python 移植分类器与聚合器（`hits`／`primaryCategory`／`snapshot`／`categoryAssets` 排序），把两份测试里走真实分类器的夹具按旧、新规则各跑一遍，全部期望值由复算产出（②，手工移植，权威结论只取 CI）。

### `IC153ScanServiceTests.swift`

| # | 行 | 旧 | 新 | 类别 |
|---|---|---|---|---|
| 1 | :20-22 | `let threshold = S0ScanRules.bigVideoMinimumByteCount`、`// G874：…`、`XCTAssertEqual(threshold, 100_000_000)` | 删 | 符号已删，断言随之删（−1 条断言） |
| 2 | :47 | `// 小视频。` | `// 小视频：第 187 条取消门槛后同样进「视频」类（IC-163 裁定 五）。` | 注释 |
| 3 | :57-58 | `hits: []`／`primary: nil` | `hits: [.bigVideo]`／`primary: .bigVideo` | 期望值 |
| 4 | :60 | `// 不低于门槛的普通视频。` | `// 大体积的普通视频。` | 注释 |
| 5 | :73 | `// 不低于门槛且文件名前缀命中的录屏：两个类别都命中，去重归大视频。` | `// 大体积且文件名前缀命中的录屏：视频与录屏互斥，只归录屏（IC-163 裁定 五）。` | 注释 |
| 6 | :83-84 | `[.bigVideo, .screenRecording]`／`.bigVideo` | `[.screenRecording]`／`.screenRecording` | 期望值 |
| 7 | :107 | `byteCount: threshold,` | `byteCount: 100 * megabyte,` | 字面量（值不变） |
| 8 | :113 | `// 前缀判据大小写敏感：小写前缀不命中。` | `// 前缀判据大小写敏感：小写前缀不算录屏证据，归「视频」类。` | 注释 |
| 9 | :123-124 | `[]`／`nil` | `[.bigVideo]`／`.bigVideo` | 期望值 |
| 10 | :126 | `// 门槛恰好相等时命中（大于等于）。` | `// 恰为原门槛（100 MB）：照样命中「视频」类。` | 注释 |
| 11 | :134 | `byteCount: threshold` | `byteCount: 100 * megabyte` | 字面量（值不变） |
| 12 | :139 | `// 差一个字节不命中。` | `// 比原门槛差一个字节：门槛已取消，小视频也命中「视频」类。` | 注释 |
| 13 | :147 | `byteCount: threshold - 1` | `byteCount: 100 * megabyte - 1` | 字面量（值不变） |
| 14 | :149-150 | `[]`／`nil` | `[.bigVideo]`／`.bigVideo` | 期望值 |
| 15 | :265 | `// 类别全量：录屏同时计入大视频与屏幕录制两个类别。` | 两行：视频与录屏互斥、录屏只计入屏幕录制，唯一的普通视频在账本内、视频类此处无候选 | 注释 |
| 16 | :269-270、:272 | `.bigVideo` 快照 `candidateCount: 1`、`candidateByteCount: 150 * megabyte`、`coverAssetID: "recording"` | `0`、`0`、`nil` | 期望值 |
| 17 | :296 | `XCTAssertEqual(categorySum, 303 * megabyte)` | `153 * megabyte`（上方加一行注释） | 期望值 |
| 18 | :297 | `XCTAssertGreaterThan(categorySum, snapshot.cleanableByteCount)` | `XCTAssertEqual(categorySum, snapshot.cleanableByteCount)` | **断言关系改变**（见下） |
| 19 | :321 | `[2, 1, 2]` | `[1, 1, 2]` | 期望值 |
| 20 | :348 | `occurrences(of: "S0ScanRules.", in: classifier)` `>= 3` | `>= 2` | 期望值 |
| 21 | :350 | `// 登记表：恰七个常量，…` | `// 登记表：恰六个常量，…（IC-163 删去大视频门槛）。` | 注释 |
| 22 | :367-368 | `constantCount` 与 `出处：` 数 `7`、`7` | `6`、`6` | 期望值 |
| 23 | :372 | `["100000000", "1206", "2622", "200"]` | `["1206", "2622", "200"]` | 期望值 |
| 24 | :375 | `// 七个取值逐个钉住（任务卡白名单）。` | `// 六个取值逐个钉住（任务卡白名单）。` | 注释 |
| 25 | :376 | `XCTAssertEqual(S0ScanRules.bigVideoMinimumByteCount, 100_000_000)` | 删 | 符号已删，断言随之删（−1 条断言） |

**两处与卡面预演不同，按复算处理**：

- 第 18 条是卡面未列、复算发现的一处：夹具里唯一的普通视频在账本内，录屏只进屏幕录制，类别字节和 = 153 MB = hero。旧断言 `categorySum > cleanable` 钉的正是「同一资产计入两类」这件事，裁定 五让它不再成立，这条原样留着必红。只改关系、不改夹具，断言条数不变。
- 卡面「`:126-151` 两例合成一例」没有照做：白名单写「不删断言」，两例保留，门槛 `threshold` 改字面量 `100 * megabyte`／`100 * megabyte - 1`，期望值都改 `.bigVideo`，恰好覆盖「原门槛上下都进视频」。只有第 1、25 两处因符号被删而不得不删断言。
- 优先序断言（卡面 `:24-26`、`:183-186`、`:330-333`，`main` 行号）未动。

### `IC155CategoryDataAndCoverTests.swift`

| # | 行 | 旧 | 新 | 类别 |
|---|---|---|---|---|
| 1 | :170 | `// 账本内的视频比录屏大：它若没被排除，大视频的封面就会是它。` | `// 账本内的视频：它若没被排除，「视频」类的封面就会是它（录屏自 IC-163 起不计入视频类）。` | 注释 |
| 2 | :226 | `category(.bigVideo, in: snapshot)?.coverAssetID` 期望 `"recording"` | `nil`（上方加一行注释） | 期望值 |
| 3 | :248 | `withShotAPending` 的 `.bigVideo` 封面期望 `"recording"` | `nil` | 期望值 |
| 4 | :251 | `// 正对照：账本清空后，更大的账本视频回到大视频类别并成为封面。` | `// 正对照：账本清空后，账本视频回到「视频」类别并成为封面。` | 注释 |
| 5 | :461 | `.bigVideo: ["v-big-1", "v-big-2", "v-big-3", "rec-big"]` | `["v-big-1", "v-big-2", "v-big-3", "video-small"]` | 期望值 |
| 6 | :529 | `// 同属两个类别的资产进篮：两个列表一起少它。` | `// 录屏进篮：视频与录屏互斥（IC-163 裁定 五），只有录屏列表少它，「视频」列表不变。` | 注释 |
| 7 | :533 | `["v-big-2", "v-big-3"]` | `["v-big-2", "v-big-3", "video-small"]` | 期望值 |
| 8 | :702-703 | 样本库文档「含一条同属两类的录屏…一条不属任何类别的小视频」 | 「含一条大体积录屏（IC-163 起只归录屏）…一条小视频（IC-163 起归「视频」类）」 | 注释 |

**与卡面预演的差异**（复算为准）：卡面列的 `:489-490`（时长去重数）复算后 **4 → 4 不变**（旧：42.25／61.5／30／95.5；新：42.25／61.5／30／8）；`:524`（进篮后视频类候选数）复算 **3 → 3 不变**（旧剩 v-big-2／v-big-3／rec-big，新剩 v-big-2／v-big-3／video-small）；卡面未列的 `:226`、`:248` 两处封面期望由 `"recording"` 变 `nil`，复算发现后改。`:224`／`:378`／`:458` 的类别顺序不变。

## 五、`project.pbxproj` 登记

加登记前重扫当前最大号：`180b052` 上 fileRef `…67`、buildFile `…64`（与卡面一致）；新号逐个核对仓内出现次数为 0 后再写。

| 文件 | fileRef | buildFile | 子项 | 插入位置 |
|---|---|---|---|---|
| `IC163DeckPreviewRoundTwoTests.swift` | `100000000000000000000068` | `200000000000000000000065` | A | PBXBuildFile：`20000000000000000000005D /* S0CleanupFlowModel.swift（源码） */` 之后；PBXFileReference：`100000000000000000000060 /* S0CleanupFlowModel.swift */` 之后；tests 组：`100000000000000000000013 /* S3StateMachineTests.swift */` 之后；tests Sources：`200000000000000000000010 /* S3StateMachineTests.swift（测试源码） */` 之后（四个锚行 `main` 上都有，惯例 40） |
| `S0DeckAssetDates.swift` | `100000000000000000000069` | `200000000000000000000066` | C | 各段紧跟 `S0DeckHomeView.swift` 那一行（S0 组、app Sources `400…001`） |

## 六、目录 key 变更

| key | 子项 | 变更 |
|---|---|---|
| `s0.category.bigVideo` | D | 值 `大视频` → `视频`（key 不改） |
| `deck.home.suggest` | B | 删 |
| `deck.page.top.title`／`deck.page.top.action`／`deck.page.rest.title` | C | 删 |
| `deck.page.sort.size` = `从大到小`、`deck.page.month.count` = `{count} 项`、`deck.page.undated` = `未知日期` | C | 加 |

`deck.` 12 → **11**（12 − 4 + 3），每个都有 `L10n.text` 字面量引用；`s0.` 仍 **38**；页面借用的 `s1.sort.accessibility`／`s1.sort.newest_first`／`s1.sort.oldest_first` 为既有 key。目录条目 265 → 265（D）→ 264（B）→ 264（C），扫描器「目录条目 = 产品源码引用 key」两数逐次相等。

## 七、占位值登记

本卡无出厂值变更，`schemaVersion` 不递增（仍 7）。新登记值（全部进 `S0DeckMetrics`，出处注明为本卡「视觉取值」）：`expandContentRise = 8`、`monthSectionCountFontSize = 12.5`、`monthSectionSpacing = 12`、`S0DeckSymbol.sort = "arrow.up.arrow.down"`。

## 八、摘取关系实证（草稿区克隆，只作证据，**未推 `main`**）

克隆 `D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE` 到会话草稿区，从 `origin/main`（`091b60e`）切临时分支：

| 序列 | 命令 | 结果 |
|---|---|---|
| A 单独 | `git switch -c pickA origin/main && git cherry-pick 105ada3` | 退出码 0，`Auto-merging project.pbxproj` 无冲突，新提交 `81940fc`，4 个文件 +266／−5 |
| D 单独 | `git switch -c pickD origin/main && git cherry-pick 088e4b1` | 退出码 0，`Auto-merging Localizable.xcstrings` 无冲突，新提交 `b8ea58a`，5 个文件 +46／−52 |
| A→D | `git switch -c pickAD origin/main && git cherry-pick 105ada3 088e4b1` | 退出码 0，两提交 `2052da6`／`33cdc4c` |

D 改的 `s0.category.bigVideo` 条目与本链新增、删除的 `deck.*` 条目不相邻（`deck.` 按字母序排在 `s0.` 之前，中间隔着全部 `s0.basket`～`s0.category.b` 之前的条目）；A 的四行 pbxproj 登记紧挨的锚行 `main` 上都有、且与 IC-162 的登记块之间隔着锚行本身。
