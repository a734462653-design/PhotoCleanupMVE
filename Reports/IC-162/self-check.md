# IC-162 自验报告（「卡片叠」首页与新类别页 · 真机预览，探针分支不合并）

## 一、结论（先行）

卡内两项全部实装并落在 `probe/ic-162-deck-home-preview` 上，各自独立 commit，另加一个画布保真度订正提交（同一张卡、同一分支）。**分支不合并进 `main`**。CI 两次各一次绿，862 项 0 失败。

- **子项 A（首页）**：`S0DeckMetrics`／`S0DeckHomeModel`／`S0DeckCoverView`／`S0DeckHomeView` 四个新产品源文件 + 流程容器的编译期常量切换 + 七条 `deck.home.*` + 四条断言。
- **子项 B（类别页与过渡）**：`S0DeckCategoryPageView` 一个新文件 + `page(for:)` 的 if／else + `@Namespace` 一行 + `sections` + 五条 `deck.page.*` + 两条断言。
- **闸门**：G912（流程文件被钉计数）逐条相符；G913（白名单外零改动 + 四份 SHA-256 两侧相同）通过；G914（新产品源文件的扫描纪律、12 条 key、`s0.` 仍 38、`#available` 0 处）通过；**G915 通过**——CI 两次各一次绿，#326（`13adda1635bb50f61ff6eebd40fe60a03c5d0f6c`）**862 项 0 失败、真实退出码 0、IPA 已上传**，artifact `PhotoCleanupMVE-unsigned-13adda1635bb`（id `10587817557`，有效期至 2026-12-18T16:16:03Z）。
- **卡内没有根因假设**（本卡是视觉预览，不含 ③ 归因），故无「确认或推翻」一节。
- **本报告不代 Lynn 判定任何观感项**：H81 六条原样列在第九节。

> **`S0DeckPreview.isEnabled = true`**：本分支的两个 tab 页都走新版式。改成 `false` 即整条回到 `main` 的行为，旧文件一字未动。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260919-162-deck-home-preview.md` |
| 画布（只读参照） | `<top>/Tasks/design-s0-r2/r7.py`（卡片叠 M1）、`r8.py`（N2 总条）、`r9.py`（O1／O2 类别页） |
| 继承提交 | `main` = `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a`（本机与 `origin/main` `git ls-remote` 一致，退出码 0） |
| 目标分支 | `probe/ic-162-deck-home-preview`（从 `main` 切，**不合并**） |
| 范围边界 | 白名单九个路径；`S0View.swift`／`S0CategoryPageView.swift`／`S0TabContainer.swift`／`S0CleanupFlowModel.swift`／`App/`／`Core/`／`Services/`／`ThumbnailView.swift`／全部既有测试文件／`.github/`／`Scripts/` 一字未动 |
| 开工四步 | `git status --porcelain` 空 → `git merge-base --is-ancestor 091b60e main` 退出码 0 → `git ls-remote origin refs/heads/main` = `091b60e…3a0a` → **先切分支再改文件**（切分支后再建第一个文件） |

## 三、逐条验收门禁

### G912：`S0CleanupFlowView.swift` 改后，被钉的每条计数逐条 grep

口径与 `IC156CategoryPageTests`／`IC157LongPressIntoS2Tests`／`IC160SelectionSurvivesS2Tests` 的 helper 同源（`strippedSource` 剔 `//` 注释与字符串内容后计数；`numericLiterals` 同一提取器）——本机用 Python 逐行移植那两只 helper 后跑出下表，CI 上由那三份测试自己再验一次。

| needle | 口径 | 卡面 | 实测 | 判定 |
|---|---|---|---|---|
| `S0View(` | == | 1 | 1 | OK |
| `S0CategoryPageView(` | == | 1 | 1 | OK |
| `machine.ingest(` | == | 3 | 3 | OK |
| `navigationDestination(item:` | == | 1 | 1 | OK |
| `.returnedFromCategoryPage` | == | 1 | 1 | OK |
| `.toolbar(.hidden, for: .tabBar)` | == | 1 | 1 | OK |
| `.toolbar(.hidden, for: .navigationBar)` | == | 2 | 2 | OK |
| `@State ` | == | 0 | 0 | OK |
| `@StateObject` | == | 0 | 0 | OK |
| `@ObservedObject` | == | 1 | 1 | OK |
| `flowModel.preservedSelection` | == | 4 | 4 | OK |
| `initialSelection: flowModel.preservedSelection` | == | 1 | 1 | OK |
| `flowModel.preservedSelection = $0` | == | 1 | 1 | OK |
| `flowModel.preservedSelection = []` | == | 2 | 2 | OK |
| `flowModel.presentedCategory` | ≥ | 3 | 5 | OK |
| `onEnterS2` | ≥ | 2 | 6 | OK |
| `NavigationStack` | ≥ | 1 | 1 | OK |
| `.onAppear` | ≥ | 1 | 1 | OK |
| `static func shouldRecomputeOnAppear(presentedCategory:` | == | 1 | 1 | OK |
| `CleanupCoordinator` | == | 0 | 0 | OK |
| `SessionStore` | == | 0 | 0 | OK |
| `S1StateMachine` | == | 0 | 0 | OK |
| 数字字面量 | ⊆ {0,1,2} | — | 只有 `0`（来自 `= $0`） | OK |
| PhotoKit 七 needle | == | 0 | 0 | OK |
| 动态外观七 needle（`colorScheme`／`systemBackground`／`UIColor.label`／`.primary`／`S2ChromeForeground`／`Material`／`ultraThin`） | == | 0 | 0 | OK |
| 原文 `Text("` | == | 0 | 0 | OK |
| `#available` | == | 0 | 0 | OK |

**关键实现点**：为让 `flowModel.preservedSelection` 的四处与三个子计数一条不变，两只闭包外提成 `enterCategory(_:)`／`leaveCategory()`，新旧两个分支共用；新类别页**不经** `initialSelection:`／`onSelectionChange:` 形参拿保留集（那两处只属旧分支），而是直接收 `flowModel`。`#available` 与两只过渡修饰符全部落在新视图文件里——写进流程文件会被数字字面量提取器取出 `18.0`，必红。

### G913：白名单外零改动

`git diff --stat main..HEAD` 只含九个路径（逐条与白名单对应，清单见 `change-list.md` 第二节）。

| 文件 | 两侧 SHA-256 | 判定 |
|---|---|---|
| `PhotoCleanupMVE/Features/S0/S0View.swift` | `4a81d3fa72ccf6f522265c202608e967ad8e7102712cfb37d165fdef6fcd558f` | 同 |
| `PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift` | `3529c5fc43b6b23af34ab0af62b7972c92b587a3124e92d4faa7c6b3aa65e082` | 同 |
| `PhotoCleanupMVE/Features/Shared/ThumbnailView.swift` | `be251cc8ec79f61c06f66ded323e18e6bb30682529a9445f3d604d3ff0af9677` | 同 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `ac224fd84fecbf8b62cb8330883a7b869edd2d1f4863a504d3cc1655b4b8474a` | 同 |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift` | `24830037467e919dee53efb3b7b6f2f74a47a505a6e0881cd4a3ea899b972707` | 同 |
| `PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift` | `2d88a10213b067ee5f62865f2968eca2f0f207b884bf01bb8efd28ca52b5a267` | 同 |
| `PhotoCleanupMVE/Features/S0/S0CategoryPageMetrics.swift` | `f7bb7bb65317bcdcb9811955e328e52779bf802e2d89a5949e95b60f9dd40bb2` | 同 |
| `PhotoCleanupMVE/Features/S0/S0SegmentBar.swift` | `b1261c79714ceb3bd4363ce78b1cd59012f439fb69698599b1f8e92f26b4d1ef` | 同 |
| `PhotoCleanupMVE/Features/S0/S0CategoryRow.swift` | `df67a0fcafa50c009acee6a0ee6884cc2019e86f48efdacdb7839fae301fb1fb` | 同 |
| `PhotoCleanupMVE/Features/S0/S0TabContainer.swift` | `2f914cfaa30bab29b3f3a5fcfa9b3262914597976994ef0fd11409ee2ffd2f34` | 同 |
| `PhotoCleanupMVE/Core/S0StateMachine.swift` | `29e1a38485a2f0305abeb62c9e8607494aa47c83895369687ad5994dd32b0425` | 同 |

`S0HomeMetrics` 仍 52 个登记值、`S0CategoryPageMetrics` 仍 42 个（两文件两侧字节相同，蕴含计数不变）。

### G914：新产品源文件的扫描纪律

扫描口径与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 一致——**对原始行匹配，不剔注释**（注释里的引文一律用「」，陷阱 18）。

| 文件 | 含汉字的字符串字面量 | `return "` | `Text("`／`Button("`／`Label("`／`accessibilityLabel("` | `import Photos` |
|---|---|---|---|---|
| `S0DeckMetrics.swift` | 0 | 0 | 0 | 0 |
| `S0DeckHomeModel.swift` | 0 | 0 | 0 | 0 |
| `S0DeckCoverView.swift` | 0 | 0 | 0 | **1**（裁定 三授权的唯一一处） |
| `S0DeckHomeView.swift` | 0 | 0 | 0 | 0 |
| `S0DeckCategoryPageView.swift` | 0 | 0 | 0 | 0 |

| 项 | 值 |
|---|---|
| 12 条 `deck.*` key 的产品源码引用数 | `deck.home.open.action` 1、`deck.home.share` 3、`deck.home.suggest` 1、`deck.home.released` 1、`deck.home.bar.caption` 1、`deck.home.hero.label` 1、`deck.home.open.subtitle` 2、`deck.page.top.title` 1、`deck.page.top.action` 1、`deck.page.rest.title` 1、`deck.page.selected` 1、`deck.page.submit` 1（**每条 ≥ 1**） |
| 目录 `s0.` 前缀 key | **38**（未动） |
| 目录 `deck.` 前缀 key | 12 |
| 目录条目合计 | 253 → **265**；扫描器报「产品源码引用 key：265」，双向核对通过 |
| `S0CleanupFlowView.swift` 里 `#available` | 0 |

> **口径注记**：本机复核脚本第一版把 key 引用 needle 写成 `L10n.text("<key>"` 连写，对**多行调用**恒零命中（四条 key 假红）。扫描器用的是 `L10n\.text\(\s*"([^"]+)"` 带 `Singleline`，复核脚本已改成同一条正则后全部命中。这正是记忆里「函数名(实参标签 连写 needle 遇多行调用空转」那一类。

### 卡面「六个新产品源文件」与实际五个

卡面 G914 写「新建的**产品源文件**（六个，不含测试文件）」，而白名单实际给出的新建产品源文件是**五个**（A 四个 + B 一个），第六个是测试文件 `IC162DeckPreviewTests.swift`。本报告按**五个**逐个执行该闸门，逐项结果见上表。

## 四、六条断言与测试函数名

| # | 断言 | 测试函数 | 子项 |
|---|---|---|---|
| 1 | 卡按入参序、丢掉无项目的类、末尾补「其余照片」；占比与百分数等于手算值；`LIB = 0` 时占比全 0 不崩 | `testIC162A_CardsKeepOrderDropEmptyAndAppendRest` | A |
| 2 | `restByteCount = 0` 时不出「其余照片」卡 | `testIC162A_RestCardOmittedWhenZero` | A |
| 3 | 默认展开第一张可点的卡（首卡 `.awaitingScanCompletion` 不可点、次卡 `.counting` 可点）；展开的那张消失或变得不可点时回落；仍可点则原样；全不可点为 nil | `testIC162A_DefaultAndResolvedOpenID` | A |
| 4 | 前 N 项求和夹到实际项数（3 取 10、12 取 10、空） | `testIC162A_TopSumClampsToCount` | A |
| 5 | 两节按上限切分、顺序不变（12／10、10、3、0 四种） | `testIC162B_SectionsSplitAtLimit` | B |
| 6 | 「全选这 N 个」并入已选且**幂等**（已选的不得被反选），并带一条负对照 | `testIC162B_SelectingTopSectionUnionsIntoSelection` | B |

六条**只测纯函数**：不构造视图、不碰 PhotoKit。夹具取值避开 `.5` 边界（本机 Python 复算：`0.285 * 100` 在双精度下是 `28.499999999999996`，`.rounded()` 得 28；本卡用 300／1000、120／1000、500／1000，`.rounded()` 分别得 30／12／50）。

**夹具驱动，真机未覆盖**（陷阱 1）：版式、展开／收起动画、进页过渡、页头收起、封面取图、手感一律钉不住，由 H81 六条真机兜底。

## 五、CI（G915）

**两次运行，各一次绿，预算 3 次用了 2 次。**

| 项 | #325 | **#326（最终，Lynn 装这个）** |
|---|---|---|
| 运行 id | `35453488799` | `35454401038` |
| run_attempt | 1 | 1 |
| 结论 | `success` | `success` |
| 被测提交（完整 SHA） | `a7ed9463ccd9f56451d5e33172d913f1dc944f8c`（A + B） | `13adda1635bb50f61ff6eebd40fe60a03c5d0f6c`（A + B + 订正） |
| 步骤 | 十二步全 `success` | 十二步全 `success` |
| XCTest 执行摘要 notice | `Executed 862 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 862 tests / 0 failures` | 同左 |
| 整包日志按**唯一 Test Case 行**复核（陷阱 25：先剔 `##[error]` 回显与 ANSI 脚本回显） | 862 passed / 0 failed | 862 passed / 0 failed |
| 真实退出码 | 0——工作流 `set -o pipefail` 且末句 `exit "$test_status"`；日志出现 `** TEST SUCCEEDED **`、无 `** TEST FAILED **`；「运行 XCTest」步骤 `success`，作业 `success` | 同左 |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左（同一 id） |
| 分段耗时 notice 原文 | `XCTest 分段耗时：模拟器启动 101 s；xcodebuild test 447 s；总 550 s` | `XCTest 分段耗时：模拟器启动 79 s；xcodebuild test 291 s；总 372 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1863875，SHA-256=57f9eb96fa581536802d32fe36d47e23ccdb29e651b68e430899474f744257b1` | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1867254，SHA-256=b34f490832163e0177603c08d5ee3f48c413ed43503a03b266cb5880d1f53ccd` |
| 本卡六条 | 全过 | 全过 |

### 产物（Lynn 要装的包）

| 项 | 值 |
|---|---|
| artifact 名称 | **`PhotoCleanupMVE-unsigned-13adda1635bb`** |
| artifact id | **`10587817557`** |
| 大小 | 1 867 424 字节（zip；内含 IPA 1 867 254 字节） |
| 生成时间 | 2026-09-19T16:26:25Z |
| **有效期至** | **2026-12-18T16:16:03Z**（`expired: false`） |
| 来自运行 | #326，`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/35454401038` |

> #325 的产物是 `PhotoCleanupMVE-unsigned-a7ed9463ccd9`（id `10588315012`，同日到期），**不含**第 11 节列的四处订正，不要装它。

### 项数对账

| 时点 | 项数 |
|---|---|
| `main` 基线（#321） | 856 |
| 子项 A 后 | 856 + 4 = **860** |
| 子项 B 后 | 860 + 2 = **862** |
| 订正提交后 | 862（订正不加不减用例） |
| #325／#326 实测 | **862**，0 失败 |

与卡面的 860／862 对账式一致。

### 相关既有用例逐族点名（#326 整包日志按唯一 Test Case 行统计，全过、零失败）

| 测试类 | 过 | 失败 |
|---|---|---|
| `IC147S0BehaviorTests` | 16 | 0 |
| `IC148S0VisualTests` | 14 | 0 |
| `IC151AmbientFixedColorTests` | 8 | 0 |
| `IC152DiagnosticPathTests` | 6 | 0 |
| `IC153ScanServiceTests` | 13 | 0 |
| `IC155CategoryDataAndCoverTests` | 9 | 0 |
| `IC156CategoryPageTests` | 11 | 0 |
| `IC157LongPressIntoS2Tests` | 8 | 0 |
| `IC160SelectionSurvivesS2Tests` | 4 | 0 |
| `IC162DeckPreviewTests`（本卡） | 6 | 0 |

这九族正是卡面事实基础第二行「八组既有断言」的落点——流程文件被钉的每条计数在 CI 上由它们自己再验了一遍，全部通过。

### `testIC063`（陷阱 26 口径）

两次都 passed（#325 14.179 s、#326 9.780 s）。按第 186 条的判法读 build 行相对 `IC063_WARMUP_GATE_END` 的先后：

- #325：`[error] building pipeline path_exterior-jba6la8feba4 took 7.620961 seconds` 在 16:07:03.20，`IC063_WARMUP_GATE_BEGIN` 在 16:07:03.47、`…_END` 在 16:07:03.66，`IC063_DIAGNOSTICS_SAMPLE_BEGIN` 在 16:07:06.81。
- #326：build 行在 16:21:47.33，`WARMUP_GATE_BEGIN` 16:21:48.99、`…_END` 16:21:49.05、`SAMPLE_BEGIN` 16:21:52.21。

两次的 Metal 管线编译都落在预热门禁**之前**（本次更早——发生在挂载循环那次导出上），计时段干净，与 IC-159 的结论一致。本卡未触碰该用例。

## 六、本地门禁结果与真实退出码

| 门禁 | 时点 | 退出码 |
|---|---|---|
| `Scripts/selfcheck.ps1` | 子项 A 提交前 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 子项 A 提交前 | 0 |
| `git diff --check` | 子项 A 提交前 | 0 |
| `Scripts/selfcheck.ps1` | 子项 B 提交前 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 子项 B 提交前 | 0 |
| `git diff --check` | 子项 B 提交前 | 0 |
| `Scripts/selfcheck.ps1` | 订正提交前 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 订正提交前 | 0 |
| `git diff --check` | 订正提交前 | 0 |

`selfcheck.ps1` 的两道内嵌门禁在最后一次运行里报：Swift 字符串与括号结构检查扫描 **95 个** `.swift`（含本卡五个新产品源文件），无未闭合字符串、无括号失衡；扫描 needle 与源码变体交叉审计扫描 44 个测试源文件，无 needle 喂错源码变体。

## 七、摘取关系实证（克隆 cherry-pick）

在 `--no-hardlinks` 克隆里从 `091b60e` 分别 detach 后 cherry-pick：

| 序列 | 结果 |
|---|---|
| A 单独 | **CLEAN** |
| B 单独 | **CONFLICT**（B 往 A 新建的三个文件追加） |
| A→B 连续 | **CLEAN** |

与卡面「A 单独可摘；B 依赖 A，只能作 A→B 连续序列」一致。订正提交 `13adda1` 只改 A、B 建的两个新视图文件，不是独立摘取单位，跟在 B 之后。

G912／G913／G914 三道闸门在订正提交之后**重跑一遍**，结果与上表逐项相同（`S0DeckMetrics.swift` 未被订正触碰，登记值与 12 条 key 一条未变）。

## 八、人工判定项

**本报告不代 Lynn 下任何观感结论。** 版式像不像画布、动画顺不顺、过渡自不自然、玻璃读不读得清、比现在的首页好在哪，全部留给 Lynn 装本分支 CI 产物后真机判定（H81 六条，见第九节）。

模拟器与测试宿主同样判不了的还有：封面取图（测试宿主与 CI 相册取不到图，`S0DeckCoverView` 在 CI 上一帧都没画过——陷阱 24 同源）、`matchedTransitionSource`／`navigationTransition(.zoom)` 的实际过渡、页头收起的滚动手感、长按进 S2 的时序。

## 九、H81 六条（原样列出，留给 Lynn）

1. 首页第一眼：和画布「N2 总条联动」那张比，像不像、好不好看；真照片当封面后展开卡清不清楚、字读不读得清。
2. 点收起的条 → 展开／收起的动画顺不顺、各卡位置有没有跳；总条上亮的那一段与标注有没有跟着变；点总条的段能不能切。
3. 点展开卡或「去清理」→ 进类别页的过渡（iOS 18 以上应是卡片放大成页头）自然不自然；返回时回到原位。
4. 类别页：「最大的 10 个」一节与「全选这 10 个」好不好用；格底玻璃条读不读得清；往下滚时页头收成导航条的那一下顺不顺；底栏玻璃压在滚动网格上的观感。
5. 功能没退步：勾选 → 移入待删篮 → 首页数字与条目同步减；长按进 S2 再回来落回类别页且勾选还在；杀掉重开仍是新首页、扫描照常。
6. 整体：比现在的首页好在哪、还差在哪（一两句话即可）。

## 十、过渡段是否保留（裁定 五的 ③）

**保留。** 卡面写「若这段在 CI 上编不过或第一次 CI 红在它身上：整段删掉、走默认 push」——两个条件都没触发：`matchedTransitionSource(id:in:)` 与 `navigationTransition(.zoom(sourceID:in:))` 各包在一只 `ViewModifier` 里、`@ViewBuilder func body(content:)` + `if #available(iOS 18.0, *)` else 原样返回 `content`，第一次 CI（#325）就编过且全绿，没有一条失败落在它身上。

实装位置：两只修饰符与版本判定全在 `S0DeckCategoryPageView.swift`；`S0DeckHomeView` 只多一个 `Namespace.ID` 形参并在卡上 `.modifier(S0DeckZoomSource(...))`；流程文件只多一行 `@Namespace private var deckNamespace`（`@Namespace` 不在被钉之列，`#available` 在该文件仍 0 处）。

**iOS 18 以下走默认 push**；过渡本身是否自然留给 H81 第 3 条真机判。

## 十一、发现但未处理的问题（按纪律只报告不修）

1. **卡面 G914 的「六个新产品源文件」与白名单不符**：白名单给出的新建**产品**源文件是五个（A 四个 + B 一个），第六个是测试文件。本报告按五个执行该闸门。
2. **`S0DeckMetrics.compactNavTopInset = 54` 登记了但没用上**。该值是画布的**绝对坐标**：①`gen.py` 的画板写死 `.screen { width: 393px; height: 852px }`，y=0 在屏幕最顶、含状态栏。②由 `.topr { top: 62px }` 与 `S1ChromeLayout.topRowTopInset = 3` 能对上，反推这块画板假定的安全区顶是 **59 pt**（正是 Dynamic Island 机型的常见值）；照此换算，`.cnav { top: 54px }` 的安全区相对坐标是 **−5**，没法直接当内距用。实装取 `S1ChromeLayout.topRowTopInset`，收起后的导航条因此落在原顶排的位置上（比画布低约 8 pt）。该常量仍作为 `compactNavThreshold = 262 − 54 − 54 = 154` 的推导中间量留在登记表里。SPEC-S0 v3 登记这一族时建议改登记**安全区相对值**。
3. **`S0DeckMetrics.totalBarUnscannedFillOpacity` 是画布缺口**：r8.py 的 N2 画的是就绪态，没有「未扫描」段；该值取同族最低一档（`.dk .dim` 末段 `0.18`）的中性白。扫描中首页的未扫段观感未经画布确认。
4. **首页各块的纵向间距与画布有系统性偏差约 12 pt**：画布的 `.brand` 是一行 17 pt 标题（72..94），而实装的顶排是 44 pt 的 S1 chrome 行（安全区 3..47 = 画板 62..106），因此 hero 起点落在画板 134 而画布是 122。纵向节奏按「上一块底缘 + 登记间距」推，不按画布绝对坐标钉。
5. **「去清理」在实装里是卡上的标签、不是独立按钮**：裁定 五写「点展开卡**或其上的「去清理」**」两者同一动作，故整张展开卡即入口，避免嵌套 `Button` 把点按语义拆成两处。观感上仍是一枚胶囊。
6. **末张卡的 320 pt 尾巴恒在**：照 r7.py `strip(..., last=True)` 的 `h = 320`，末张收起条向下多伸 320 pt。类别少时首页会因此多出一段可滚动的照片区。是否要按屏高收口，留给 Lynn 看过再定（H81 第 1 条）。
7. **`S0DeckCoverView` 在 CI 上一帧都没画过**：测试宿主与 CI 相册取不到图（与陷阱 24 同源），封面的取图、换图防护与宽幅构图只能靠真机验（H81 第 1、5 条）。
8. **进 S2 失败或写回失败时的提示**：新类别页与旧类别页同样只在 `onMoveToBasket` 返回 `true` 时才删项出 toast，失败时静默——与 `main` 行为一致，仍是第 184 条第四节记的那条 S0 维护卡候选，本卡不动。
9. **本机流程复盘（不是卡的缺陷，是我自己的近失）**：`change-list.md` 初稿里子项 A 的 40 位 SHA 是按短前缀补全写出来的（陷阱 15 正禁此事），提交前用 `git rev-parse` + `git cat-file -e` 复核时发现并订正；`self-check` 的 G914 复核脚本第一版把 key 引用 needle 写成连写形式，对多行 `L10n.text(` 调用恒零命中（四条 key 假红），改用扫描器同一条正则后全部命中。
