# IC-171 自验报告：类别页三件——收起导航条只留类别名、待删篮徽标叠到玻璃之外、长按进 S2 往返后滚动位置保留

> 任务卡：`<top>/Tasks/IC-20260924-171-category-page-trio.md`（S0 维护卡，可合并）
> 执行会话：2026-09-24。证据分级按 CLAUDE.md 第四节：①已验证事实、②样本观察、③合理推测、④项目判断。

## 一、结论（先行）

**代码交付完成，四个子项各自独立提交（A→B→C→D），CI 分支两次一次绿（888／0、892／0），已 `--no-ff` 合并入 `main` 并推送成功（本次合并与推送均未被权限分类器拦截），合并后 `main` 运行绿 892／0。** CI 预算 3 次只用 2 次（分支）+ 合并后 1 次自动运行（不计入分支预算，同 IC-170 报告口径）。

| 子项 | 提交（完整 SHA） | CI | 结果 |
|---|---|---|---|
| A 收起导航条只留类别名（裁定一） | `4465ab344150588fa10a49a65ac313d860eadd17` | 与 B、C 同推 | — |
| B 徽标叠到玻璃之外（裁定二） | `5db0b85c1b0ad1caf699ab312eb2450c33aa58e0` | 与 A、C 同推 | — |
| C 滚动位置保留（裁定三） | `e9df07ad387d3ad02cc74ced1c45295f696d1555` | **#346**（run `35978325250`） | 一次绿，**888 项 0 失败**，真实退出码 0 |
| D 新断言四条 | `0134c84cb52aea523410ee2f9e05ddd0f54f5d14` | **#347**（run `35979882247`） | 一次绿，**892 项 0 失败**，真实退出码 0 |
| 合并（已推送） | `e356aeda17da53a064892e04f39bea1032f5bf8d`（`--no-ff`，父 `af66a67a` + `0134c84c`） | **#348**（run `35981129494`） | 一次绿，**892 项 0 失败**，真实退出码 0 |

- G957～G962 全部满足（第九节逐条，含 git 现取证据）。
- 项数对账：888（继承）→（A）888 →（B）888 →（C）888 →（D）892，与卡面「项数：888 + 4 = 892」一致①。
- 卡面全部 12 处代码块锚句在基线 `af66a67a` 上逐条核实恰命中 1 处；子项 A、B、C、D 的全部计数预演值（剔注释口径，`Tasks/decision-tools/sim_ic171.py`／`check_ic171.py` 只读复算 + 本会话独立 Python 复算）与实测结果逐条相符，无一处偏差（第五节）。
- 摘取关系（惯例 40）在克隆里实测：A 单独、C 单独、A→B 均无冲突 cherry-pick 成功（第八节）。
- **合并与推送均一次成功，未被权限分类器拦截**（与 IC-170 不同，本卡未触发 `[Merge Without Review]`）。
- **报告落点（惯例 44）**：合并与合并后 `main` 运行（#348）之后，本报告与 `change-list.md` 作为恰一个 docs 提交追加到 `main`。
- 人工判定项 H90 八条留给 Lynn 真机判，执行端不代为下结论（第十一节）。

## 二、输入、继承与范围

- 输入：`<top>/CLAUDE.md` 全文；`<top>/SPEC-S0-20260923_v4.md` 第六节（类别页显示元素清单 `:294`、可用操作、迁出条件）、第十节第 1～2 部分、第十四节第 2 部分收起导航条五个登记值（`:834-838`）；任务卡全文；`Tasks/RESEARCH-IC-171-s0-facts.md`、`Tasks/REVIEW-IC-171-findings.md`、`Tasks/REVIEW-IC-171-round2-findings.md`（以卡为准）。
- 继承：`main` = `af66a67a2b184abbad1b71a971b0ff378285123b`（IC-170 报告补记提交；`git merge-base --is-ancestor ba65163db17b541e9a46ec0e82a7aab7b336e2eb main` 退出码 0，`ba65163` 为 IC-170 merge 提交）。
- 目标分支：`feature/ic-171-category-page-trio`（自上述 `main` 切出，已推送）。
- 范围边界：只做卡内四个子项（裁定一、二、三落地为 A/B/C，D 为新断言）。**未做**（卡「本卡不做」与「范围外」）：排序后导航条变黑（裁定四，先观察，不改代码）；玻璃一律深色（裁定五，归 IC-172）；`S0DeckHomeView.swift` 一字未动；SPEC 与 Decision_log；rebase／amend／force push。

### 开工四步（① 实测）

1. `git status --porcelain` 输出为空，退出码 0。
2. `git merge-base --is-ancestor ba65163db17b541e9a46ec0e82a7aab7b336e2eb main` 退出码 0。
3. `git ls-remote origin refs/heads/main` = `af66a67a2b184abbad1b71a971b0ff378285123b`，与本地一致。
4. 改任何文件之前 `git switch -c feature/ic-171-category-page-trio`。

## 三、子项 A · 收起导航条只留类别名（裁定一）

- `S0DeckCategoryPageView.swift` 的 `compactNavTitle` 整段替换（锚句 `private var compactNavTitle: some View {` 基线恰 1 处，`:396-436`）：删体积（`S0ByteCountText.string(`）与占比（`s0.home.share`）两只 `Text`，类别名加 `.lineLimit(1)`，两侧 `Spacer` 与 `compactNavTitleItemSpacing` 不动。
- `S0DeckMetrics.swift` 删 9 行（三条登记值定义及各自出处注释）：`compactNavValueLetterSpacing`／`compactNavShareFontSize`／`compactNavShareOpacity`，不走「登记而无人用」豁免。
- 同一提交同步改 6 处既有断言引用（IC156 三处、IC165 一处、IC166 一处、IC167 一处），见第六节。
- 本机三道门禁（① 现取，真实退出码）：

  | 门禁 | 退出码 |
  |---|---|
  | `Scripts/selfcheck.ps1` | 0（结构自验通过，103 个 `.swift`／51 个测试源文件——D 提交后计数） |
  | `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0（用户可见硬编码残留：0） |
  | `git diff --check` | 0 |

## 四、子项 B · 徽标叠到玻璃合成边界之外（裁定二）

- `S1View.swift` 玻璃 helper 扩展收尾之后（锚句 `.s1ChromeGlassBackground(in: Circle(), interactive: true)` + `// MARK: - IC-128 B：封面缩略图` 基线恰 1 处连写）新增 `S1GlassBadgeAnchorKey`（`PreferenceKey`）、`extension View` 里的 `s1GlassBadgeOverlay`（单只玻璃钮场景，照 S1 `chromeBar`／S2 `topBar` 既有写法）与 `s1GlassBadgeHost`（钮不在容器边缘场景，经 `anchorPreference`／`overlayPreferenceValue` 在容器外画徽标）、`S1GlassBadgeLayer`。**所有版本判定都留在本文件**，S0 文件 `#available` 计数不变。
- `S0BasketEntryView.swift` 两处替换：`body` 改 `@ViewBuilder` + `switch style`（`.glass` 用 `s1GlassBadgeOverlay`、`.flat` 只报边界 `anchorPreference`），拆出 `showsBadge`／`button`；原 `badge` 属性抽成新顶层 `struct S0BasketBadge`。构造点 `S0BasketEntryView(style:count:action:)` 三处实参一字不动。
- `S0DeckCategoryPageView.swift` 的 `compactNav`：玻璃背景之后插入 `.s1GlassBadgeHost { S0BasketBadge(count: machine.mergedPendingDeletionCount) }`。
- `IC167BasketEntryAndTailTests.swift` 同步改两处既有断言（断言 2 入口 `overlay(alignment: .topTrailing)` 1→0；断言 5 页面 `machine.mergedPendingDeletionCount` 2→3），见第六节。
- 本机三道门禁全部退出码 0（同上表形式）。
- **A→B 提交后不单独推送**，与 C 一起 push（卡面要求「A→B→C 提交后 push 一次取 CI」），结果见第七节 #346。

## 五、子项 C · 滚动位置保留（裁定三）

- `S0CleanupFlowModel.swift` 加不发布字段 `var preservedScrollAnchor: String? = nil`（理由同 `preservedSelection`）。
- `S0CleanupFlowView.swift` 的 `enterCategory`／`leaveCategory` 各加一行 `flowModel.preservedScrollAnchor = nil`。
- `S0DeckCategoryPageView.swift` 三处：`body` 用 `ScrollViewReader` 包住 `scrollContent`、出现时 `.task` 调 `restoreScrollAnchor(using:)`；新增 `private func restoreScrollAnchor(using proxy: ScrollViewProxy)`（锚点非 nil 且仍在 `selection.items` 里才 `proxy.scrollTo(anchor, anchor: .center)`）；长按手势里先写 `flowModel.preservedScrollAnchor = isHeaderCollapsed ? item.id : nil`。**不使用 `scrollPosition(id:)` 持续绑定**（第一轮复核实质 2 指出的 get/set 不对称拉回风险已从机制上消除）；不新增独立 `.onAppear`／`.onChange`，未打破 IC160 的既有钉子（`.onAppear` 仍恰 1、`.onChange(of: selection.selected)` 仍恰 1）。
- 本机三道门禁全部退出码 0。
- **A→B→C 提交后 push 一次取 CI**：结果见第七节 #346（888／0，与继承基线一致，卡面预期 888／0 相符）。

## 六、子项 D · 新断言四条

新文件 `PhotoCleanupMVETests/IC171CategoryPageTrioTests.swift`（`final class IC171CategoryPageTrioTests: XCTestCase`），四条测试方法与卡面断言编号一一对应：

1. `testIC171A_CompactNavTitleShowsNameOnly`（标题只剩类别名）
2. `testIC171B_BadgeIsLaidOutsideGlassViaS1Helpers`（S1 helper 四符号、`.glass`／`.flat` 分支、`compactNav` 里玻璃背景先于宿主）
3. `testIC171C_ScrollAnchorIsUnpublishedAndClearedOnCategoryChange`（`preservedScrollAnchor` 不发布、`enterCategory`／`leaveCategory` 各清一次）
4. `testIC171C_PageRestoresLongPressedCellOnce`（`ScrollViewReader`／`restoreScrollAnchor`／`scrollTo` 逐一核对，锚点写入在 `onLongPress(` 之前）

源码扫描 helper（`newline`／`repoRoot`／`sourceText`／`strippedSource`／`occurrences`／`slice(_:from:to:)`）逐字照抄 `IC167BasketEntryAndTailTests.swift` 的同名私有成员（文件私有，不能跨文件调用，陷阱 23）。只钉本卡新增的符号与行为（惯例 46），未重复钉登记表 195、`s0.` 41 等已由别处钉住的计数。

`PhotoCleanupMVE.xcodeproj/project.pbxproj` 登记一个测试文件：登记前重扫 `git grep -oE` 得当前最大号 fileRef `…073`、buildFile `…070`（均为 `IC170S1FirstReadTests.swift`），新 id `100000000000000000000074`（fileRef）／`200000000000000000000071`（buildFile）登记前在全文件 0 命中，登记后（PBXBuildFile、PBXFileReference、group 列表、Sources 构建阶段共四行）各恰 3／2 处，定义行 `uniq -d` 为空。

本机三道门禁全部退出码 0；`selfcheck.ps1` 显示 103 个 `.swift`、51 个测试源文件（新增一个）。

**D 提交后 push 一次取 CI**：结果见第七节 #347（892／0）。

## 七、卡面计数预演值 vs 实测值

### 7.1 子项 A（剔注释，`Tasks/decision-tools/sim_ic171.py` 只读复算，`main` 基线 `af66a67a`）

| needle | 改前 | 卡面改后 | 实测改后 |
|---|---|---|---|
| 页面 `S0DeckMetrics.` | 153 | 147 | 147 |
| 页面 `S0ByteCountText.string(` | 4 | 3 | 3 |
| 页面 `compactNavTitleFontSize` | 2 | 1 | 1 |
| 页面 `compactNavTitleItemSpacing` | 1 | 1（不变） | 1 |
| 页面 `compactNavShare` | 2 | 0 | 0 |
| 页面 `compactNavValueLetterSpacing` | 1 | 0 | 0 |
| 页面 `sharePercentText` | 3 | 2 | 2 |
| 页面 `.lineLimit(1)` | 0 | 1 | 1 |
| 页面原文 `s0.home.share` | 2 | 1 | 1 |
| 登记表 `\n    static let ` | 206 | 203 | 203 |
| 登记表 `enum S0DeckMetrics` 切片 `static let ` | 198 | 195 | 195 |

全部相符，无一处偏差。

### 7.2 子项 A 第 3 条 grep 命中表（改前 → 改后，测试目录）

| needle | 改前命中（① 现取，基线 `af66a67a`） | 改后命中（`main` 合并后现取） |
|---|---|---|
| `198)` | 3 处：`IC156CategoryPageTests.swift:191`、`IC165DeckFormalTests.swift:215`、`IC166RestCategoryTests.swift:336` | 0 处 |
| `, 153)` | 2 处：`IC156CategoryPageTests.swift:170`、`IC167BasketEntryAndTailTests.swift:235`（IC-170 后行号） | 0 处 |

与卡面第 173 行「预期 `198)` 恰 3 处、`, 153)` 恰 2 处」完全一致。

### 7.3 子项 B（剔注释）

| needle | 改前 | 卡面改后 | 实测改后 |
|---|---|---|---|
| 入口 `overlay(alignment: .topTrailing)` | 1 | 0 | 0 |
| 入口新增 `struct S0BasketBadge: View` | 0 | 1 | 1 |
| 入口新增 `.s1GlassBadgeOverlay {` | 0 | 1 | 1 |
| 入口新增 `.anchorPreference(key: S1GlassBadgeAnchorKey.self, value: .bounds)` | 0 | 1 | 1 |
| 入口新增 `S0BasketBadge(count: count)` | 0 | 1 | 1 |
| 入口新增 `showsBadge` | 0 | 3 | 3 |
| 页面 `machine.mergedPendingDeletionCount` | 2 | 3 | 3 |
| 页面新增 `.s1GlassBadgeHost {` | 0 | 1 | 1 |
| 页面新增 `S0BasketBadge(count: machine.mergedPendingDeletionCount)` | 0 | 1 | 1 |
| `S1View.swift` `#available` | 2 | 4 | 4 |
| `S1View.swift` `GlassEffectContainer {` | 1 | 3 | 3 |
| `S1View.swift` `overlay(alignment: .topTrailing)` | 3 | 5 | 5 |
| `S1View.swift` `extension View {` | 1 | 2 | 2 |
| `S1View.swift` `Material`／`ultraThin`／`.primary` | 3／2／12 | 不变 | 3／2／12 |

全部相符，无一处偏差。入口内其余「恰 1」类既有钉子（`Image(systemName: S0DeckSymbol.trash)` 2、`Button(action: action)` 1、`.disabled(count == 0)` 1、`count > 0` 1、`.allowsHitTesting(false)` 1、`.monospacedDigit()` 1、`#available` 0、十二个禁用 needle 0）逐条核对不变。

### 7.4 子项 C（剔注释）

| needle | 改前 | 卡面改后 | 实测改后 |
|---|---|---|---|
| 模型新增 `var preservedScrollAnchor: String? = nil` | 0 | 1 | 1 |
| 流程新增 `flowModel.preservedScrollAnchor = nil` | 0 | 2 | 2 |
| 页面新增 `ScrollViewReader { proxy in` | 0 | 1 | 1 |
| 页面新增 `restoreScrollAnchor(using: proxy)` | 0 | 1 | 1 |
| 页面新增 `private func restoreScrollAnchor(using proxy: ScrollViewProxy)` | 0 | 1 | 1 |
| 页面新增 `proxy.scrollTo(anchor, anchor: .center)` | 0 | 1 | 1 |
| 页面新增 `flowModel.preservedScrollAnchor = isHeaderCollapsed ? item.id : nil` | 0 | 1 | 1 |
| 页面 `flowModel.preservedScrollAnchor`（总数） | 0 | 2 | 2 |
| 页面 `scrollPosition` | 0 | 0（不变，未采用持续绑定） | 0 |
| 既有钉子 `.onAppear`／`.onChange(of: selection.selected)`／`@State `（模型 1／流程 0／页面 4）／`machine.ingest(`／`@Published` | 各自不变 | 不变 | 全部不变 |

全部相符。

### 7.5 子项 D（本会话独立 Python 复算，脚本未纳入版本控制，逻辑与 `strippedSource`/`occurrences` 同口径）

四条断言涉及的全部 41 项计数（含切片断言、位置比较断言）在提交前对working tree现算全部通过（41/41），提交后用 `Tasks/decision-tools/check_ic171.py <rev> D` 只读复算亦全部通过（见第九节 G957～G960）。

## 八、摘取关系实测（惯例 40，克隆里真实 `git cherry-pick`，非只读推断）

在独立临时克隆（`scratchpad/ic171-exec/clonetest`，测完保留在 scratchpad、未触碰本仓库工作树）里，从 `af66a67a` 各建一支新分支：

- **A 单独**：`git cherry-pick 4465ab3` 到纯净 `af66a67a`：退出码 0，无冲突。
- **C 单独**：`git cherry-pick e9df07a` 到纯净 `af66a67a`：`Auto-merging` 页面文件，退出码 0，无冲突。
- **A→B 顺序**：`git cherry-pick 4465ab3` 后 `git cherry-pick 5db0b85`：均退出码 0，无冲突。

三种组合均与卡面「摘取关系」段的说法一致：A 单独、C 单独、A→B 均可无冲突摘取。

**额外观察（非卡面要求，附带发现）**：出于好奇追加测试了 B 单独（不含 A）cherry-pick 到纯净 `af66a67a`——git 的 3-way 合并（`recursive`/`ort`）同样无冲突成功（`Auto-merging` 两个文件）。这与卡面裁定「B 必须接在 A 之后……文本上不可单独摘」的表述在**cherry-pick 层面**不完全一致（git 的 3-way 合并比朴素 `patch`/`git apply` 更宽容，不依赖上下文行重叠）；但本卡实际交付顺序仍严格按 A→B→C→D 提交，不受此发现影响，此处仅如实记录供决策会话参考，不改变交付。

## 九、G957～G962 逐条核验（① 现取）

- **G957（标题）**：断言 1（`testIC171A_CompactNavTitleShowsNameOnly`）passed；子项 A 第 3 条 grep 命中表（7.2 节）与第 4 条计数实测（7.1 节）相符；IC156 断言 6／9、IC165 断言 5／6、IC166 断言 6、IC167 断言 5 改后均 passed（#347、#348 日志核对，见第十节）。
- **G958（徽标）**：断言 2（`testIC171B_BadgeIsLaidOutsideGlassViaS1Helpers`）passed；子项 B 第 5 条计数实测（7.3 节）相符；IC167 断言 2／5、IC165 断言 2（`#available` 只在 zoom 过渡文件，`S1View.swift` 不在其扫描范围）、IC147 断言 11、IC148 断言 2、IC156 `s1ChromeCircleGlass` 切片均 passed；`S0DeckHomeView.swift` blob 与基线相同（`8b2168801c41ffcfe51e13dd0ec9620bf1e60136`，两侧一致，第十二节）。
- **G959（滚动）**：断言 3／4 passed；子项 C 第 4 条计数实测（7.4 节）相符；IC160 全族、IC157 断言 6 均 passed。
- **G960（白名单外零改动）**：`git diff --name-only af66a67a..0134c84` 恰 12 路径（第十三节列全）；「不得打红」段两侧对象相同（`Tasks/decision-tools/check_ic171.py feature/ic-171-category-page-trio D` 153/153 全 PASS，含 App/Core/Services/Features-S2~S5/Shared/Localizable.xcstrings/.github/Scripts/`S0DeckHomeView.swift` 的「same object」比对，以及 Features/S0、Features/S1、PhotoCleanupMVETests 目录内白名单外文件的逐一比对）；十七条被保护分支 tip 经 `git ls-remote origin` 现取，逐条与 IC-170 报告记录的十六条短 SHA 吻合，另加 `feature/ic-170-s1-first-read` 仍为 `8007910`（现取 `800791020a8923e44043fea49c9d766a7edcd307`），共十七条全部未变（第十三节）。满足。
- **G961（合并前置）**：G957～G960 满足 + 两次 CI 绿（888／0、892／0，真实退出码 0，`OS:26.2, name:iPhone 16`，IPA 字节数与 SHA-256，分段耗时 notice，`testIC063` build 行均在 `IC063_WARMUP_GATE_END` 之前，未见异常）+ pbxproj 撞号扫描（定义行 `uniq -d` 空，`main` 上共 215 条定义行零重复；新 id `100000000000000000000074` 恰 3 处、`200000000000000000000071` 恰 2 处）+ 工作树净（`git status --porcelain` 空）+ `main` 未被他人推进（合并前 `git ls-remote` 确认仍 `af66a67a2b184abbad1b71a971b0ff378285123b`）。**满足，`--no-ff` 合并推送成功**（第十节）。
- **G962**：合并后 `main` 运行 #348（run `35981129494`，job `107573018911`，测合并提交 `e356aeda17da53a064892e04f39bea1032f5bf8d`）：全部步骤 `success`，`XCTest 执行摘要` notice `Executed 892 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 892 tests / 0 failures`；`未签名 IPA 校验` 字节数 `1835465`、SHA-256 `110720af2ed2b1fb3fcfa5dd031bcb2de4aa02080e8d9752eba8f57d5b1b495a`；`XCTest 分段耗时` `模拟器启动 96 s；xcodebuild test 435 s；总 534 s`；artifact `PhotoCleanupMVE-unsigned-e356aeda17da`（id `10800478861`，1835635 字节，2026-12-23T09:25:22Z 前有效）。满足。

## 十、CI 详情（① 现取，`gh api` + 下载整包日志核验）

### #346（A→B→C，测 `e9df07ad387d3ad02cc74ced1c45295f696d1555`）

- run id `35978325250`，job id `107563970970`，全部步骤 `success`，job `conclusion=success`。
- `XCTest 执行摘要` notice：`Executed 888 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 888 tests / 0 failures`。整包日志唯一 `Executed 888 tests, with 0 failures` 最终行（`** TEST SUCCEEDED **` 之前）与摘要一致。
- `未签名 IPA 校验` notice：文件 `PhotoCleanupMVE-unsigned.ipa`，字节数 `1835465`，SHA-256 `4ef53540e7c8cf5718d612e1ea49600040aca86836f683d9384c8dd766f334fc`。
- `XCTest 分段耗时` notice：`模拟器启动 101 s；xcodebuild test 376 s；总 478 s`。
- 目的地实证行（整包日志「9_运行 XCTest.txt」）：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`。
- `testIC063`：`building pipeline path_exterior-jba6la8feba4 took 0.721474 seconds` 出现在 `IC063_WARMUP_GATE_END` **之前**，预热吸收编译停顿，计时导出未见异常（陷阱 26）。

### #347（D，测 `0134c84cb52aea523410ee2f9e05ddd0f54f5d14`）

- run id `35979882247`，job id `107568983161`，全部步骤 `success`，job `conclusion=success`。
- `XCTest 执行摘要` notice：`Executed 892 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 892 tests / 0 failures`。
- `未签名 IPA 校验` notice：文件 `PhotoCleanupMVE-unsigned.ipa`，字节数 `1835465`，SHA-256 `5ada8e8b74bda6dbb61090deec35d722320a0ed01e77b0eae23d9903690a0545`。
- `XCTest 分段耗时` notice：`模拟器启动 77 s；xcodebuild test 320 s；总 399 s`。
- 目的地实证行同上（`OS:26.2, name:iPhone 16`）。
- `testIC063`：build 行（0.678141 s）同样在 `IC063_WARMUP_GATE_END` 之前。
- 新四条断言与 8 处既有断言改写版均在整包日志「9_运行 XCTest.txt」中核到最终 `Executed 892 tests, with 0 failures` 汇总内（未见任何 `failed` 行）。

### 合并后 `main` 运行（G962）

#348（run `35981129494`，job `107573018911`，测合并提交 `e356aeda17da53a064892e04f39bea1032f5bf8d`）：全部步骤 `success`；`XCTest 执行摘要` notice `Executed 892 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 892 tests / 0 failures`；`未签名 IPA 校验` 字节数 `1835465`、SHA-256 `110720af2ed2b1fb3fcfa5dd031bcb2de4aa02080e8d9752eba8f57d5b1b495a`；`XCTest 分段耗时` `模拟器启动 96 s；xcodebuild test 435 s；总 534 s`；artifact `PhotoCleanupMVE-unsigned-e356aeda17da`（id `10800478861`，1835635 字节，2026-12-23T09:25:22Z 前有效）；`testIC063` build 行（1.288679 s）同样在 `IC063_WARMUP_GATE_END` 之前。

## 十一、人工判定项（H90 八条，原样列出，留给 Lynn）

1. 类别页往下滑到页头收起：顶上导航条中间**只有类别名**（单行），不再有体积与占比；换一个名字最长的类别（例如「屏幕录制」）看会不会被截断、有没有折行。
2. 三处垃圾桶徽标（首页顶排、类别页页头、类别页收起导航条）在篮里有东西时都是**实心红底白字**，与「逐张整理」tab 的垃圾桶徽标一样，不发虚；位置仍在垃圾桶右上角。收起导航条整条玻璃（圆角、模糊、透光）的观感跟改动前比有没有变化（本卡首次把一条自带玻璃的视图再包进玻璃容器）。
3. 首页顶排（垃圾桶 · 账户钮）与类别页页头（返回 … 垃圾桶 · 排序 · 全选）的间距与各钮左右位置，跟改动前比**有没有偏移**；垃圾桶点下去照常进 S3。
4. 类别页往下滑过页头（导航条出现）→ 长按一张进 S2 → 左上返回：**刚才长按的那张应在屏幕中间附近**，不是回到最顶部。「从大到小」与「最新在前」各试一次。
5. 页头还没收起时（在最上面）长按进 S2 → 返回：仍在最上面、页头完整。
6. 滑到很下面、长按**该类别体积最大的那张**（页头大图就是它）进 S2 再返回：记下落在它的格子上还是落回了页头（③ 同 id 的边界情况）。
7. 滑到下面后点左上返回首页，再进同一个类别：从最上面开始（不保留）；换另一个类别进去：从最上面开始。
8. 一两句总评。

**执行端不代为下结论。**

## 十二、报告级一次性证据补充

- `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift`：`af66a67a` 与 `main`（合并后）两侧 blob 均为 `8b2168801c41ffcfe51e13dd0ec9620bf1e60136`。
- `PhotoCleanupMVE/Features/S1/` 目录树在基线上只含 `S1View.swift`（本卡白名单文件本身），无其他文件需比对。
- `S2CalibrationConfiguration.schemaVersion` 仍 `7`（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`）；`S0ScanRules.cacheSchemaVersion` 仍 `1`；`S0DeckSymbol` 枚举切片 `static let` 仍 `8`；`Localizable.xcstrings` blob 两侧相同（未改动，目录 259／`s0.` 41 数字不变）。
- `git diff 0134c84 main --stat` 输出为空——合并树与分支尖端树逐字节相同（无冲突快进式内容）。

## 十三、white-list 与 G960 支撑数据

`git diff --name-only af66a67a..0134c84`（12 路径，与卡面白名单逐条一致）：

```
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/Features/S0/S0BasketEntryView.swift
PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift
PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift
PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift
PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift
PhotoCleanupMVE/Features/S1/S1View.swift
PhotoCleanupMVETests/IC156CategoryPageTests.swift
PhotoCleanupMVETests/IC165DeckFormalTests.swift
PhotoCleanupMVETests/IC166RestCategoryTests.swift
PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift
PhotoCleanupMVETests/IC171CategoryPageTrioTests.swift
```

十七条被保护分支 tip（`git ls-remote origin` 现取，逐条核对）：`probe/ic-067-screenshot-subtype` `9db02b93eccbb87d126602901807e70823535111`、`probe/ic-125-sentinel-negative` `402cb6e52a11dc89ce2a8351b47314a5fe9185b8`、`probe/ic-137-media-playback` `486bcb769b59eb1146c5a231c7998847206777cc`、`probe/ic-145-scan-service` `d373afc7125104c01acfc296829229090e6871ce`、`probe/ic-161-similar-photos` `1f8ff9248e312cd4a04faec559ea9f34540b1379`、`probe/ic-162-deck-home-preview` `180b052edf24f168712c6e58754c60b88b342175`、`probe/ic-163-deck-home-preview-r2` `562f8b7afa14508e3efebbd57e980e275946ab95`、`feature/ic-089-nx-edge-bounce` `b368a6caee846e664391b0620350395bfe6fbc7f`、`feature/ic-091-nx-midgesture-handoff` `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`、`feature/ic-092-nx-window-follow` `a7cc1ec727a3a493f5263e688a316cbf4c743562`、`feature/ic-158-diagnostic-progress-clamp` `5cb67332437a446d98733ddc942e2905392d2891`、`feature/ic-164-pick-ic163-a-d` `cc85fa4a7cfa272092a3acfade432d13de7e4e0b`、`feature/ic-165-deck-formal` `dc7e49459f15fb6227c3f34903357ae490aaa7ed`、`feature/ic-166-rest-category-and-lib` `2734ccd0ef2f12fa4ce115f0136777321a96c548`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd1436fa25b8298caca2f3d2266024859df4e`、`feature/ic-168-s2-exit-diagnostics` `e7c1be085102b5d9685b0863f29feb6bfa006a38`、`feature/ic-170-s1-first-read` `800791020a8923e44043fea49c9d766a7edcd307`。全部未变。

## 十四、v4 欠账（本卡实装，不算规格冲突；SPEC-S0 v5 回填）

1. 第六节 `:294` 收起导航条「返回 · 类别名 `c.bytes` 占 N% · 待删篮入口 · 排序 · 「全选」」——④ 第 200 条第三节第 2 条改为只留类别名（单行、超宽截断）；v5 改 `:294`，第十四节第 2 部分删 `compactNavValueLetterSpacing`／`compactNavShareFontSize`／`compactNavShareOpacity` 三行（`:836-838`）。
2. 第十四节第 2 部分待删篮徽标只写「`badge*` 四项……不登记新值」，未写「徽标叠在玻璃合成边界之外」——④ 第三节第 4 条；v5 补一句（连同 IC-167 登记的描边色欠账）。
3. 第六节／第十节第 2 部分「返回落点 = 类别页；`SEL` 按第六节不变量保留」未写滚动位置——④ 第三节第 5 条：长按进 S2 往返后回到被长按的那一格（居中；长按时页头未收起则从顶部开始）；换类别、返回首页不保留。v5 补。

## 十五、③ 登记（待 H90 判）

- 徽标发虚机制与修法是否真的生效：只有真机能判（H90 第 2 条）。
- `.glass` 入口外包一层 `GlassEffectContainer` 后，首页顶排与类别页页头顶排的整体间距、相邻按钮位置有无偏移：H90 第 3 条。
- 收起导航条整条被再包一层 `GlassEffectContainer` 后，玻璃观感（圆角、模糊强度、透光）有无变化：H90 第 2 条（本仓库首次出现「单个已带玻璃效果的视图被二次包裹」的写法）。
- `.task` 时机是否足够晚、`LazyVGrid` 远处的格子能否被 `scrollTo` 到位：H90 第 4、6 条。
- 长按封面那张时（页头大图与网格同 `category.coverAssetID`／同 id），落点在页头还是网格格子：H90 第 6 条（③ 边界情况，报告登记）。

## 十六、发现但未处理的问题（按纪律只报告不修）

- 摘取关系（惯例 40）里 B 单独 cherry-pick 到纯净基线，git 的 3-way 合并实测无冲突成功，与卡面裁定「文本上不可单独摘」的表述在 cherry-pick 层面不完全一致（第八节「额外观察」）——不影响本卡交付（本卡严格按 A→B→C→D 顺序提交），仅记录供决策会话参考。
- 未发现其他产品缺陷或卡面执行歧义；卡面「本卡不做」列出的排序变黑观察（裁定四）与玻璃深色统一（裁定五）均未触碰，符合范围边界。

## 十七、40 位 SHA 核验（陷阱 15；`git cat-file -e <sha>^{commit}`，全部退出码 0）

| SHA | 用途 | 核验 |
|---|---|---|
| `af66a67a2b184abbad1b71a971b0ff378285123b` | 基线 `main` | OK |
| `ba65163db17b541e9a46ec0e82a7aab7b336e2eb` | IC-170 merge（基线祖先） | OK |
| `4465ab344150588fa10a49a65ac313d860eadd17` | 子项 A | OK |
| `5db0b85c1b0ad1caf699ab312eb2450c33aa58e0` | 子项 B | OK |
| `e9df07ad387d3ad02cc74ced1c45295f696d1555` | 子项 C | OK |
| `0134c84cb52aea523410ee2f9e05ddd0f54f5d14` | 子项 D | OK |
| `e356aeda17da53a064892e04f39bea1032f5bf8d` | 合并（已推送，#348 测此提交） | OK |
