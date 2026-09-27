# IC-178 自验报告

## 一、结论（先行）

- **四个子项全部按卡面原文完成，已合并入 `main` 并推送。** 分支 `feature/ic-178-year-deck-and-page`：A `33014925c99302015c4976e55d856fc5a3d0190a` → B `80ec98560d7f21f8bfc3943d0b30f8aca7f03fb5` → C `96766ed97943720cc381a7a7c8c07cdc2df427d2` → D `ed8c9bf7a6dfeeb453cc8377f9a6c2eecb6cf313`。
- 分支 CI **#366**（run `36329748603`）一次绿：**935 项 0 失败**，真实退出码 0，`OS:26.2, name:iPhone 16`；五条新断言全部 passed。CI 预算 3 次只用 1 次（另加合并后 `main` 一次）。
- 合并提交 `d90ebb32ad3f7b07617f659cfcad30c3098d9fe8`（`--no-ff`，双亲 `fcde233…`／`ed8c9bf…`，树 `1252482f…` 与 D 提交树相同），首次推送即通过、未被分类器拦。合并后 `main` 运行 **#367（run `36330716310`）一次绿 935／0**。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面全部计数、锚句（每处恰 1）、三个拷入文件 hash、五个基线 blob、pbx 新 id、目录计数都与实测逐条相等；`check_ic178.py` 在四个提交上 126／126／126／127 全 PASS；`sim_ic178.py`（只对基线跑）`FAILURES 0`。**没有发现与卡面矛盾之处，没有停下的项。**
- 人工判定项（H96 十一条）全部保留给 Lynn 真机判，执行端不代为下结论。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡：`<top>/Tasks/IC-20260927-178-year-deck-and-page.md`（948 行）；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-178.md`；调研 `Tasks/RESEARCH-IC-178-facts.md`；复核 `Tasks/REVIEW-IC-178-findings.md`（两轮 + 两节处置，以卡为准）。
- 基线：`main` = `fcde23316c8ee4c4bca152515f7de18aa8192cd2`。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 496835aa998b98e03951d7c039830103689dec98 main` 退出码 0；`git ls-remote origin refs/heads/main` = `fcde23316c8ee4c4bca152515f7de18aa8192cd2`（与本地一致）；五个文件 blob 与卡面表逐条相等（下表）；**先 `git switch -c feature/ic-178-year-deck-and-page` 再改文件**。

| 路径 | 卡面 blob | 实测 `git rev-parse main:<路径>` |
|---|---|---|
| `Features/S1/S1View.swift` | `9f0de919e7ef82671279de0e41867c2b0734e175` | `9f0de919e7ef82671279de0e41867c2b0734e175` |
| `Core/S1StateMachine.swift` | `702e599df88bef73712eaa05a83490e97b5f7d3b` | `702e599df88bef73712eaa05a83490e97b5f7d3b` |
| `Localizable.xcstrings` | `9ec88f562791dadf4d4b1eed865b344f7f1333ab` | `9ec88f562791dadf4d4b1eed865b344f7f1333ab` |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `3026fadfbe82a93e580af70354bceda7b0f0421f` | `3026fadfbe82a93e580af70354bceda7b0f0421f` |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | `844572b4973615ec681278c3f59a345a13d2b21c` | `844572b4973615ec681278c3f59a345a13d2b21c` |

- 范围边界：只做列表层 + 年页（卡「本卡边界」）。页头、三件口径最终取值、旧附属物退役、四项排序、`S1RangeRow`／`visibleRanges`／`rangeRows` 语义、App／协调器／其余 `Core/`／`Services/`／S0～S5 均未触碰。
- 改法实施方式：卡面代码块由脚本从卡文件原文逐块取出（不手抄），每处替换前断言锚句在当时文本恰 1 处：A1～A4 各 1、目录 1、B1～B3 各 1、C1 1、C2 1（旧列表层 263 行整段）、C3 1、D1～D4 各 1——全部恰 1，无一处停下。目录为文本插入（未经 JSON 库重写），插入后 `json.load` 可解析：总数 281、`s1.` 33、`s1.deck.` 4、`s1.yearPage.` 3、`s0.` 41、`s2.tutorial.` 10。

## 三、提交列表

| 子项 | 提交 | 树 | 可摘性 |
|---|---|---|---|
| A 卡片叠与年页视图 + 目录 + pbx 产品登记 | `33014925c99302015c4976e55d856fc5a3d0190a` | `a37707d035b6949aae6fd80406a375b2eddf0d23` | 单独可摘（实测见第十三节） |
| B 年页身份 | `80ec98560d7f21f8bfc3943d0b30f8aca7f03fb5` | `d640ab07e2b60a0bad59c460a70a0147370938b0` | 单独可摘（实测见第十三节） |
| C S1View 接线 + IC177C 期望值 | `96766ed97943720cc381a7a7c8c07cdc2df427d2` | `25f7d2583af98d717a9e34724f0f90b9b3879641` | 依赖 A、B |
| D 新测试 + pbx 测试登记 | `ed8c9bf7a6dfeeb453cc8377f9a6c2eecb6cf313` | `1252482f239458ef5bd3354d2aaad087b04661de` | 依赖 A、B、C |
| 合并 | `d90ebb32ad3f7b07617f659cfcad30c3098d9fe8` | `1252482f239458ef5bd3354d2aaad087b04661de` | 双亲 `fcde23316c8ee4c4bca152515f7de18aa8192cd2`／`ed8c9bf7a6dfeeb453cc8377f9a6c2eecb6cf313` |

## 四、CI

| 项 | 分支运行 #366 | 合并后 `main` 运行 #367 |
|---|---|---|
| run id | `36329748603`（attempt 1） | `36330716310`（attempt 1） |
| 被测提交 | `ed8c9bf7a6dfeeb453cc8377f9a6c2eecb6cf313` | `d90ebb32ad3f7b07617f659cfcad30c3098d9fe8` |
| 结论 | completed／success，作业十二步全部 success | completed／success，作业十二步全部 success |
| XCTest | 唯一 Test Case 行 935 条：935 passed／0 failed；`Executed 935 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC178DeckListTests` 5／5；`testIC063` 族 10 条全 passed | 唯一 Test Case 行 935 条：935 passed／0 failed；`Executed 935 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC178DeckListTests` 5／5；`testIC063` 族 10 条全 passed |
| 执行摘要 notice | `Executed 935 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 935 tests / 0 failures` | `Executed 935 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 935 tests / 0 failures` |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（另一行同 id 的 `arch:x86_64`） | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（另一行同 id 的 `arch:x86_64`） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1964764，SHA-256 `2f4e86973c7a1fb372fd16b232b15ca95099e0cb5bf70115fc5eaece64c23845` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1964764，SHA-256 `452dd54358e97c848c527b465cdd683a2606c8dc6d2ce3cbeb157bd55288ce4c` |
| 分段耗时 notice | `模拟器启动 83 s；xcodebuild test 395 s；总 478 s` | `模拟器启动 79 s；xcodebuild test 443 s；总 522 s` |
| artifact | `PhotoCleanupMVE-unsigned-ed8c9bf7a6df`（id 10935378103，1964934 字节，有效期至 2026-12-26T15:29:39Z） | `PhotoCleanupMVE-unsigned-d90ebb32ad3f`（id 10935911311，1964934 字节，有效期至 2026-12-26T15:45:18Z） |

数据来源：`actions/runs/<id>`、`…/jobs`、`check-runs/<id>/annotations`（各自运行现取的 check-run id）、`…/artifacts`，以及整包日志 zip 中「9_运行 XCTest.txt」单文件（剔 `##[error]` 与 ANSI 回显行后按唯一 Test Case 行计数）。

项数对账：基线 930（IC-180 合并后 #365）+ 本卡新增 5 条（D 子项；A、B、C 不增删测试）= **935**，与 #366 唯一 Test Case 行数、`Executed` 行、执行摘要 notice 三者一致。

## 五、本地门禁（四个提交各一份，真实退出码；提交前在暂存态上跑）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A `3301492` | 0 | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） | 0 |
| B `80ec985` | 0 | 0 | 0 |
| C `96766ed` | 0 | 0（C 删掉旧红点角标后 `s1.range.pending_count` 仍由新胶囊读屏引用，双向一致——复核 F1 的修法实证） | 0 |
| D `ed8c9bf` | 0（「结构自验通过…不少于 189 项测试的数量门禁均符合要求」） | 0 | 0 |

另：每个子项提交前，先把暂存区写成一个不挂分支的临时提交（`git write-tree` + `git commit-tree`），在其上跑 `IC178_BASE=fcde233… python -B check_ic178.py <临时提交> <段>`，全 PASS 后才正式提交；正式提交后在四个真实提交上复跑：A 126／126、B 126／126、C 126／126、D 127／127 PASS。

## 六、子项计数实测表（卡面值 / 实测值；剔注释口径 = 测试 `strippedSource` 的 Python 移植 `decision-tools/strip.py`，切片口径同测试 `slice`；脚本 `scratchpad/ic178-exec/counts.py` 在各提交对象上读）

### 6.1 子项 A（提交 `3301492`，`REV=<A> counts.py A`）

| scope | needle | card | actual | |
|---|---|---|---|---|
| cards | `S1ChromeForeground.` | 9 | 9 | ok |
| cards | `S0DeckMetrics.` | 2 | 2 | ok |
| cards | `S1NotificationBadgeStyle.` | 1 | 1 | ok |
| cards | `S1ProgressLinePresentation.fillFraction(` | 1 | 1 | ok |
| cards | `S0DeckCoverView(` | 1 | 1 | ok |
| cards | `.id(coverAssetID)` | 1 | 1 | ok |
| cards | `.clipShape(` | 1 | 1 | ok |
| cards | `.contentShape(` | 1 | 1 | ok |
| cards | `.zIndex(` | 1 | 1 | ok |
| cards | `.offset(y:` | 1 | 1 | ok |
| cards | `.accessibilityHidden(true)` | 1 | 1 | ok |
| cards | `.accessibilityLabel(` | 1 | 1 | ok |
| cards | `.layoutPriority(1)` | 1 | 1 | ok |
| cards | `.fixedSize()` | 2 | 2 | ok |
| cards | `.buttonStyle(.plain)` | 1 | 1 | ok |
| cards | `Button(action:` | 1 | 1 | ok |
| cards | `LinearGradient(` | 1 | 1 | ok |
| cards | `.kerning(` | 1 | 1 | ok |
| cards | `.shadow(` | 1 | 1 | ok |
| cards | `strokeBorder(` | 1 | 1 | ok |
| cards | `S1DeckMetrics slice static let` | 50 | 50 | ok |
| cards | `S1DeckSymbol slice static let` | 3 | 3 | ok |
| cards | `"s1.deck.year.subtitle" raw` | 1 | 1 | ok |
| cards | `"s1.deck.pending" raw` | 1 | 1 | ok |
| cards | `"s1.deck.seen" raw` | 1 | 1 | ok |
| cards | `"s1.deck.done" raw` | 1 | 1 | ok |
| cards | `"s1.range.total_count" raw` | 1 | 1 | ok |
| cards | `"s1.range.pending_count" raw` | 1 | 1 | ok |
| yearPage | `S1ChromeForeground.` | 6 | 6 | ok |
| yearPage | `S0DeckMetrics.` | 0 | 0 | ok |
| yearPage | `S1ChromeLayout.` | 6 | 6 | ok |
| yearPage | `.toolbar(.hidden, for: .tabBar)` | 1 | 1 | ok |
| yearPage | `.toolbar(.hidden, for: .navigationBar)` | 1 | 1 | ok |
| yearPage | `S0BasketEntryView(style: .glass` | 1 | 1 | ok |
| yearPage | `s1ChromeCircleGlass()` | 1 | 1 | ok |
| yearPage | `.accessibilityLabel(` | 1 | 1 | ok |
| yearPage | `.buttonStyle(.plain)` | 1 | 1 | ok |
| yearPage | `Button(action:` | 2 | 2 | ok |
| yearPage | `S1DeckStack(` | 1 | 1 | ok |
| yearPage | `S1DeckProgressBar(` | 1 | 1 | ok |
| yearPage | `kind: .months` | 1 | 1 | ok |
| yearPage | `.kerning(` | 1 | 1 | ok |
| yearPage | `"s1.yearPage.summary" raw` | 1 | 1 | ok |
| yearPage | `"s1.yearPage.organizeAll" raw` | 1 | 1 | ok |
| yearPage | `"s1.yearPage.back" raw` | 1 | 1 | ok |
| yearPage | `"s1.trash.accessibility" raw` | 0 | 0 | ok |
| cards | `raw Text("` | 0 | 0 | ok |
| cards | `raw return "` | 0 | 0 | ok |
| cards | `raw import ` | 1 | 1 | ok |
| cards | `systemGroupedBackground` | 0 | 0 | ok |
| cards | `secondarySystemGroupedBackground` | 0 | 0 | ok |
| cards | `secondarySystemFill` | 0 | 0 | ok |
| cards | `tertiaryLabel` | 0 | 0 | ok |
| cards | `accentColor` | 0 | 0 | ok |
| cards | `systemRed` | 0 | 0 | ok |
| cards | `systemGreen` | 0 | 0 | ok |
| cards | `systemOrange` | 0 | 0 | ok |
| cards | `Color.primary` | 0 | 0 | ok |
| cards | `Color.secondary` | 0 | 0 | ok |
| cards | `uiColor: .separator` | 0 | 0 | ok |
| cards | `Color(uiColor:` | 0 | 0 | ok |
| cards | `systemBackground` | 0 | 0 | ok |
| cards | `userInterfaceStyle` | 0 | 0 | ok |
| cards | `dynamicColor(` | 0 | 0 | ok |
| cards | `preferredColorScheme` | 0 | 0 | ok |
| cards | `Material` | 0 | 0 | ok |
| cards | `colorScheme` | 0 | 0 | ok |
| cards | `GlassEffectContainer` | 0 | 0 | ok |
| cards | `NavigationStack` | 0 | 0 | ok |
| cards | `@MainActor` | 0 | 0 | ok |
| cards | `PHAsset` | 0 | 0 | ok |
| cards | `import Photos` | 0 | 0 | ok |
| cards | `S1RangeCardMetrics.` | 0 | 0 | ok |
| cards | `S1YearStackStyle.` | 0 | 0 | ok |
| cards | `CJK string literals` | 0 | 0 | ok |
| yearPage | `raw Text("` | 0 | 0 | ok |
| yearPage | `raw return "` | 0 | 0 | ok |
| yearPage | `raw import ` | 1 | 1 | ok |
| yearPage | `systemGroupedBackground` | 0 | 0 | ok |
| yearPage | `secondarySystemGroupedBackground` | 0 | 0 | ok |
| yearPage | `secondarySystemFill` | 0 | 0 | ok |
| yearPage | `tertiaryLabel` | 0 | 0 | ok |
| yearPage | `accentColor` | 0 | 0 | ok |
| yearPage | `systemRed` | 0 | 0 | ok |
| yearPage | `systemGreen` | 0 | 0 | ok |
| yearPage | `systemOrange` | 0 | 0 | ok |
| yearPage | `Color.primary` | 0 | 0 | ok |
| yearPage | `Color.secondary` | 0 | 0 | ok |
| yearPage | `uiColor: .separator` | 0 | 0 | ok |
| yearPage | `Color(uiColor:` | 0 | 0 | ok |
| yearPage | `systemBackground` | 0 | 0 | ok |
| yearPage | `userInterfaceStyle` | 0 | 0 | ok |
| yearPage | `dynamicColor(` | 0 | 0 | ok |
| yearPage | `preferredColorScheme` | 0 | 0 | ok |
| yearPage | `Material` | 0 | 0 | ok |
| yearPage | `colorScheme` | 0 | 0 | ok |
| yearPage | `GlassEffectContainer` | 0 | 0 | ok |
| yearPage | `NavigationStack` | 0 | 0 | ok |
| yearPage | `@MainActor` | 0 | 0 | ok |
| yearPage | `PHAsset` | 0 | 0 | ok |
| yearPage | `import Photos` | 0 | 0 | ok |
| yearPage | `S1RangeCardMetrics.` | 0 | 0 | ok |
| yearPage | `S1YearStackStyle.` | 0 | 0 | ok |
| yearPage | `CJK string literals` | 0 | 0 | ok |
| pbx | `fileRef 07E` | 3 | 3 | ok |
| pbx | `fileRef 07F` | 3 | 3 | ok |
| pbx | `buildFile 07B` | 2 | 2 | ok |
| pbx | `buildFile 07C` | 2 | 2 | ok |
| pbx | `test fileRef 080` | 0 | 0 | ok |
| pbx | `test buildFile 07D` | 0 | 0 | ok |
| pbx | `duplicate definition ids` | [] | [] | ok |
| xcstrings | `total` | 281 | 281 | ok |
| xcstrings | `s1.` | 33 | 33 | ok |
| xcstrings | `s1.deck.` | 4 | 4 | ok |
| xcstrings | `s1.yearPage.` | 3 | 3 | ok |
| xcstrings | `s0.` | 41 | 41 | ok |
| xcstrings | `s2.tutorial.` | 10 | 10 | ok |

### 6.2 子项 B（提交 `80ec985`）

| scope | needle | card | actual | |
|---|---|---|---|---|
| machine | `presentedYearRangeID` | 5 | 5 | ok |
| machine | `func presentYearPage(` | 1 | 1 | ok |
| machine | `func dismissYearPage()` | 1 | 1 | ok |
| machine | `func pruneYearPageIfNeeded()` | 1 | 1 | ok |
| machine | `didSet { pruneYearPageIfNeeded() }` | 1 | 1 | ok |
| machine | `didSet { publishSnapshotIfChanged() }` | 3 | 3 | ok |
| machine | `didSet` | 4 | 4 | ok |
| machine | `publishSnapshotIfChanged()` | 6 | 6 | ok |
| machine | `setMarked(` | 3 | 3 | ok |
| machine | `applyPendingDeletionDiff(` | 3 | 3 | ok |
| machine | `private(set) var activeVirtualRangeIDs: Set<String> = []` | 1 | 1 | ok |
| machine | `raw Timer.scheduledTimer` | 0 | 0 | ok |
| machine | `raw s1.placeholder.` | 0 | 0 | ok |

### 6.3 子项 C（提交 `96766ed`）

| scope | needle | card | actual | |
|---|---|---|---|---|
| S1View | `S1ChromeForeground.` | 31 | 31 | ok |
| S1View | `S0DeckMetrics.` | 7 | 7 | ok |
| S1View | `ProgressView()` | 1 | 1 | ok |
| S1View | `ProgressView().tint(S1ChromeForeground.secondary)` | 1 | 1 | ok |
| S1View | `colorScheme, .dark)` | 7 | 7 | ok |
| S1View | `s1ChromeGlassBackground(` | 4 | 4 | ok |
| S1View | `.primary` | 10 | 10 | ok |
| S1View | `Material` | 3 | 3 | ok |
| S1View | `ultraThin` | 2 | 2 | ok |
| S1View | `static let ` | 99 | 99 | ok |
| S1View | `NavigationStack {` | 1 | 1 | ok |
| S1View | `.navigationDestination(item: presentedYearRangeBinding)` | 1 | 1 | ok |
| S1View | `.toolbar(.hidden, for: .navigationBar)` | 1 | 1 | ok |
| S1View | `.toolbar(.hidden, for: .tabBar)` | 0 | 0 | ok |
| S1View | `S1DeckListView(` | 1 | 1 | ok |
| S1View | `S1YearPageView(` | 1 | 1 | ok |
| S1View | `machine.presentYearPage(` | 1 | 1 | ok |
| S1View | `machine.dismissYearPage()` | 2 | 2 | ok |
| S1View | `toggleYearExpansion` | 0 | 0 | ok |
| S1View | `LazyVStack` | 0 | 0 | ok |
| S1View | `S1RangeCardPresentation.` | 0 | 0 | ok |
| S1View | `S1YearStackStyle.` | 0 | 0 | ok |
| S1View | `S1RangeCoverThumbnail(` | 0 | 0 | ok |
| S1View | `private func enterRange(` | 1 | 1 | ok |
| S1View | `enterRange(` | 4 | 4 | ok |
| S1View | `.overlay(alignment: .bottom) {` | 1 | 1 | ok |
| S1View | `S1TrashButtonAction.perform(` | 2 | 2 | ok |
| S1View | `S1RangeCoverPolicy.coverAssetID(` | 1 | 1 | ok |
| S1View | `ZStack(alignment: .top) {` | 1 | 1 | ok |
| S1View | `.sheet(` | 0 | 0 | ok |
| S1View | `ScrollViewReader` | 0 | 0 | ok |
| S1View | `scaledToFill` | 1 | 1 | ok |
| S1View | `Image(uiImage:` | 1 | 1 | ok |
| S1View | `systemGroupedBackground` | 0 | 0 | ok |
| S1View | `secondarySystemGroupedBackground` | 0 | 0 | ok |
| S1View | `secondarySystemFill` | 0 | 0 | ok |
| S1View | `tertiaryLabel` | 0 | 0 | ok |
| S1View | `accentColor` | 0 | 0 | ok |
| S1View | `systemRed` | 0 | 0 | ok |
| S1View | `systemGreen` | 0 | 0 | ok |
| S1View | `systemOrange` | 0 | 0 | ok |
| S1View | `Color.primary` | 0 | 0 | ok |
| S1View | `Color.secondary` | 0 | 0 | ok |
| S1View | `uiColor: .separator` | 0 | 0 | ok |
| S1View | `Color(uiColor:` | 0 | 0 | ok |
| S1View | `systemBackground` | 0 | 0 | ok |
| S1View | `userInterfaceStyle` | 0 | 0 | ok |
| S1View | `dynamicColor(` | 0 | 0 | ok |
| S1View | `raw .retry()` | 1 | 1 | ok |
| S1View | `raw Timer.scheduledTimer` | 0 | 0 | ok |
| S1View | `raw s1.placeholder.` | 0 | 0 | ok |
| S1View body | `NavigationStack {` | 1 | 1 | ok |
| S1View body | `feedbackToastOverlay` | 1 | 1 | ok |
| S1View body | `allowsHitTesting(!machine.isObscured)` | 1 | 1 | ok |
| S1View body | `yearPage(rangeID)` | 1 | 1 | ok |
| S1View body | `readCurrentRequestIfPossible()` | 1 | 1 | ok |
| S1View rootPage | `ZStack(alignment: .top) {` | 1 | 1 | ok |
| S1View rootPage | `stateContent` | 1 | 1 | ok |
| S1View rootPage | `chromeColumn` | 1 | 1 | ok |
| S1View rootPage | `menuScrim` | 1 | 1 | ok |
| S1View rootPage | `menuOverlay` | 1 | 1 | ok |
| S1View rootPage | `S1ChromeForeground.pageBackground` | 1 | 1 | ok |
| S1View list | `S1DeckListView(` | 1 | 1 | ok |
| S1View list | `S1YearPageView(` | 1 | 1 | ok |
| S1View list | `kind: machine.groupingDimension == .date ? .years : .albums` | 1 | 1 | ok |
| S1View list | `machine.presentYearPage(` | 1 | 1 | ok |
| S1View list | `machine.dismissYearPage()` | 1 | 1 | ok |
| S1View list | `S1TrashButtonAction.perform(` | 1 | 1 | ok |
| S1View list | `S1RangeCoverPolicy.coverAssetID(` | 1 | 1 | ok |
| S1View list | `enterRange(` | 3 | 3 | ok |
| S1View list | `S1ChromeForeground.` | 0 | 0 | ok |
| IC172 slice | `func s1ChromeGlassBackground<S: InsettableShape>(` | 1 | 1 | ok |
| IC172 slice | `func s1LegacyChromeGlassBackground<S: InsettableShape>(` | 1 | 1 | ok |
| IC172 slice | `private var chromeBar: some View {` | 1 | 1 | ok |
| IC172 slice | `func s1GlassBadgeOverlay<Badge: View>(` | 1 | 1 | ok |
| IC172 slice | `func s1GlassBadgeHost<Badge: View>(` | 1 | 1 | ok |
| IC172 slice | `private var feedbackToastOverlay: some View {` | 1 | 1 | ok |
| IC172 slice | `private func menuContainer<Content: View>(` | 1 | 1 | ok |
| IC172 toast order | `dark before .padding(` | True | True | ok |
| IC171 | `struct S1GlassBadgeAnchorKey: PreferenceKey` | 1 | 1 | ok |
| IC171 | `func s1GlassBadgeOverlay<Badge: View>(` | 1 | 1 | ok |
| IC171 | `func s1GlassBadgeHost<Badge: View>(` | 1 | 1 | ok |
| IC171 | `struct S1GlassBadgeLayer<Badge: View>: View` | 1 | 1 | ok |
| IC171 overlay slice | `#available(iOS 26.0, *)` | 1 | 1 | ok |
| IC171 overlay slice | `GlassEffectContainer {` | 1 | 1 | ok |
| IC171 overlay slice | `overlay(alignment: .topTrailing)` | 2 | 2 | ok |
| IC171 host slice | `overlayPreferenceValue(S1GlassBadgeAnchorKey.self)` | 2 | 2 | ok |
| IC156 slice | `S1ChromeTypography.circleIconPointSize` | 1 | 1 | ok |
| IC177 | `(Self.s1Path, 31, 7, 1),` | 1 | 1 | ok |
| IC177 | `(Self.s1Path, 37, 7, 1),` | 0 | 0 | ok |

### 6.4 子项 D（提交 `ed8c9bf`）pbx 测试登记

| scope | needle | card | actual | |
|---|---|---|---|---|
| pbx | `fileRef 07E` | 3 | 3 | ok |
| pbx | `fileRef 07F` | 3 | 3 | ok |
| pbx | `buildFile 07B` | 2 | 2 | ok |
| pbx | `buildFile 07C` | 2 | 2 | ok |
| pbx | `test fileRef 080` | 3 | 3 | ok |
| pbx | `test buildFile 07D` | 2 | 2 | ok |
| pbx | `duplicate definition ids` | [] | [] | ok |

四份表（A 199 行、B 199 行、C 220 行、D 220 行，含累计复核）MISMATCHES 均为 0；上面按子项只摘该子项的行。

## 七、三个拷入文件

| 文件 | 卡面 hash | 拷入后 `git hash-object` 实测 | 与源 `cmp` |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | `d275cd75204107cb4fdbf65a5441078be79b5aea` | `d275cd75204107cb4fdbf65a5441078be79b5aea` | 逐字节相同 |
| `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | `4d0cc41734542555bfbb0171c43eb338c72db093` | `4d0cc41734542555bfbb0171c43eb338c72db093` | 逐字节相同 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | `41acce5c9bab74e780f779ae5162841e32035c6e` | `41acce5c9bab74e780f779ae5162841e32035c6e` | 逐字节相同 |

三个源文件均无 CR（`.gitattributes` 对 `*.swift` 为 `eol=lf`），未改动其中任何一行。

## 八、闸门 G1000～G1004

| 闸门 | 结果 | 依据 |
|---|---|---|
| G1000 口径与登记 | 过 | #366：`testIC178A_StackAndCardPresentationRules`、`testIC178C_MetricsAndSymbolsMatchCanvas`、`testIC178E_CatalogGainsSevenKeys` passed（`s1.deck.seen`／`s1.yearPage.summary` 的裸 `%` 未造成不等） |
| G1001 年页身份 | 过 | #366：`testIC178B_YearPageIdentityLivesInMachineWithGuards` passed；`S1DateTreeTests`、`S1StateMachineTests`、`IC157LongPressIntoS2Tests`、`IC169MarkedStateFollowsBasketTests`、`AlbumScopeWiringTests`、`FullFlowRoutingTests` 全部 passed（935／0） |
| G1002 源码落位 | 过 | #366：`testIC178D_SourceWiringAndDiscipline` passed；A／B／C 计数与卡面「改后」逐条相等（第六节）；`IC177UnifiedBackgroundTests`、`IC172GlassAlwaysDarkTests`、`IC171CategoryPageTrioTests`、`IC156CategoryPageTests`、`IC151AmbientFixedColorTests`、`IC148S0VisualTests`、`IC128S1VisualTests`、`IC147S0BehaviorTests`、`IC165DeckFormalTests` 全部 passed |
| G1003 合并前置 | 过 | G1000～G1002；`git diff --name-only fcde233..ed8c9bf` 恰 8 路径；「不得打红」段两侧对象相同（第九节）；26 条被保护分支 tip 未变（第十节）；CI 绿（第四节）；pbx 撞号 0（第十一节）；合并前工作树净；合并前 `ls-remote` 与推送前快照相比只多本分支一行，`main` 未被他人推进（仍 `fcde233`） |
| G1004 合并后 | 过 | 合并后 `main` 运行 #367（run `36330716310`）一次绿 935／0；artifact `PhotoCleanupMVE-unsigned-d90ebb32ad3f`（id 10935911311，1964934 字节，有效期至 2026-12-26T15:45:18Z） |

## 九、「不得打红」段对象比对（基线 `fcde233` vs D `ed8c9bf`，`check_ic178.py` D 段输出）

| 对象 | 基线 = D |
|---|---|
| `PhotoCleanupMVE/Services` | `ae83298b1925e1defabbcf8a762a6ecd3032ba78` |
| `PhotoCleanupMVE/App` | `ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e` |
| `PhotoCleanupMVE/Features/S0` | `498da0346fdb9a6a59db517425d4d97047bda033` |
| `PhotoCleanupMVE/Features/S2` | `fa575d3bfcb682397ade667578785b27c0350b0e` |
| `PhotoCleanupMVE/Features/S3` | `be64dc867250a9edea24145b473b6bb8d25752a2` |
| `PhotoCleanupMVE/Features/S4` | `0d1c3618b0d435fad79067210205a0b8014d60cc` |
| `PhotoCleanupMVE/Features/S5` | `9fb0b4a4223094a2ce970328036ab4680d942c34` |
| `PhotoCleanupMVE/Features/Shared` | `c3962e5943d08dcc685d6713a9b64b07f299dcbc` |
| `.github` | `74088388c62a10eb277921ecf74e766a2d407e80` |
| `Scripts` | `514886dc0afc4083237c976c0f7be6ce597c50a8` |
| `Core/` 其余 8 文件（`AssetModels`、`L10n`、`S0`／`S2`／`S3`／`S4`／`S5StateMachine`、`SessionPersistence`、`SessionStore`） | 逐文件 blob 相同（PASS 8／8） |
| `Features/S1/` | 基线唯一文件 `S1View.swift` 保留；新增恰 `S1DeckCards.swift`、`S1YearPageView.swift` |
| 测试目录 | 新增恰 `IC178DeckListTests.swift`；除 `IC177UnifiedBackgroundTests.swift` 外全部既有测试文件 blob 相同 |

另：状态机 `publishSnapshotIfChanged()` 6／`setMarked(` 3／`applyPendingDeletionDiff(` 3 不变；IC157 的 `makeS2Handoff(for:)` 35 行逐字块在 B 后的 `S1StateMachine.swift` 中恰 1 处（按测试 `realHandoffBodyLines` 拼接后查找）；`schemaVersion` 7、`S0DeckMetrics` 195、`S0DeckSymbol` 8（`Features/S0` 树相同）。

## 十、被保护分支（26 条，推送前与合并前各 `ls-remote` 一次）

`Reports/IC-180/self-check.md` 第十节列名的 25 条 + `feature/ic-180-s5-guide-steps` `219be48`：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`、`feature/ic-169-marked-state-follows-basket` `bf9551e`、`feature/ic-175-similar-recognizer` `8d5bc7b`、`feature/ic-177-unified-background` `3cdae92`、`feature/ic-179-inline-hints` `3de1609`、`feature/ic-180-s5-guide-steps` `219be48`——**26／26 与远端头前缀相符**；合并前复查：全部远端 ref 与推送前快照（100 行）逐行相同，只多本分支一行（共 101 行）。

## 十一、pbxproj 撞号扫描与新 id

- 登记前重扫：fileRef 最大 `10000000000000000000007D`、buildFile 最大 `20000000000000000000007A`、组 `…0E`（与卡面「`…07D`／`…07A`」相符）；六个新 id 在基线 pbx 中各出现 0 次。
- 新 id（照卡面、未改号）：`S1DeckCards.swift` fileRef `10000000000000000000007E`／buildFile `20000000000000000000007B`；`S1YearPageView.swift` `10000000000000000000007F`／`20000000000000000000007C`（S1 组 `30000000000000000000000C`，接在 `S1View.swift` 之后）；`IC178DeckListTests.swift` `100000000000000000000080`／`20000000000000000000007D`。
- D 态：两个产品 fileRef 各 3 处、buildFile 各 2 处；测试 fileRef 3 处、buildFile 2 处；定义 id 重复 0。

## 十二、五条新断言与函数名（#366 均 passed）

1. `testIC178A_StackAndCardPresentationRules` — 卡片叠口径（步长、卡高、叠高 1198／590／526、已看百分比整数向下取与钳位、看完、进年页判据）
2. `testIC178B_YearPageIdentityLivesInMachineWithGuards` — 年页身份守卫与生命周期（五范围两年树夹具、`persistenceSink` 写出计数；夹具驱动，真机未覆盖）
3. `testIC178C_MetricsAndSymbolsMatchCanvas` — 五十个登记值 + 两处同值 + 三个 SF 名在宿主存在
4. `testIC178D_SourceWiringAndDiscipline` — 源码落位与新文件纪律
5. `testIC178E_CatalogGainsSevenKeys` — 目录七条 key 与取值、`L10n` 占位符替换

## 十三、摘取关系实测（本机克隆 `scratchpad/ic178-exec/clone`，自 `fcde233` 起，未推送）

| 操作 | 退出码 | 结果树 | 对照 |
|---|---|---|---|
| `cherry-pick -x 3301492`（A 单独） | 0 | `a37707d035b6949aae6fd80406a375b2eddf0d23` | 与 A 提交树相同 |
| 回到 `fcde233`，`cherry-pick -x 80ec985`（B 单独） | 0 | `fb2382ef0fbae3a5eca928173fd6e85ad49e3bcc` | 只改 `S1StateMachine.swift`，其 blob `bc80d95fc0b5e99c0be203823686c91e204e6f77` 与 B 提交中的相同；补丁与 A→B 的差分逐字相同 |

C、D 按卡只能作为 A→B→C(→D) 连续序列摘取（C 引用 A 的两只新视图与 B 的三个符号）。编译自洽性的实证是 #366（A～D 全部叠上）；A 单独、B 单独的编译未在 CI 上单独验证（③，按符号依赖推断：A 的新文件不被既有文件引用、B 只加不改无调用者）。

## 十四、根因假设

本卡不含根因假设（功能卡）。

## 十五、规格欠账（按本卡实装，不算规格冲突；原样照卡）

1. **SPEC-S1 v11** 锁定决策 3、第二节 `:216`、S1-2 可用操作 `:291-292`、迁移表 `:399`、输入矩阵 `:423`：「展开／收起年节点」改「点年卡 → 年页（留在 S1-2）」「年页返回」「年页『整理整年』→ S2 年范围」「年页点月卡 → S2 月范围」；「默认全部展开」「展开态不入档」随展开概念退役；「从 S2 返回」落点写明回到发起进入的那一页（年页或列表）；决策 28 改「年页身份为会话内视图态、不入档、S2 遮挡期间保留、年消失即清」。
2. 第六节第 2 部分整节重写为年卡叠 + 年页；「两个点击目标必须可区分」（H57 第 3 项）作废；决策 33 退役；决策 23 进度改「卡头下方进度条、0% 也画轨道、另有『已看 N%』／『看完』」；待删计数改「待删 N」胶囊；决策 34「56 pt × scale」改按卡宽高取图（`S0DeckCoverView`）。
3. 第十一节第 2 部分：`# 范围卡`／`# 已处理刻度线`／`# 待删角标`／`# 两级树` 四组换成 `S1DeckMetrics` 五十值 + `S1DeckSymbol` 三名（含 IC-177 已挂的 `yearStackLightColors` 退役）；第 3 部分文案：七条 `s1.deck.*`／`s1.yearPage.*` 与取值。
4. **三件口径待 Lynn**（本卡按默认实装）：年卡进度 = 年范围自己的 `K[year]` 还是年内各月已处理之并；年页汇总行「已看 X%」同上、「待删 Y」= 篮 ∩ 本年；月卡名沿用范围显示名还是「9 月」。
5. 页头三方不一致（代码 v8 三件、S1 v10 是 v9 版、R2 画布第三种）归下一张卡与 v11；`:246` 人像圆钮欠账仍在（IC-181 或页头卡）。
6. 未定项：非惰性卡片叠在相册维度数量无上限时的封面请求代价（③ 未实测）；会话结束后协调器装新状态机、年页身份随之消失（回列表）——要不要跨会话保留是 ④。

## 十六、人工判定项（H96 十一条，保留给 Lynn 装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-d90ebb32ad3f`（id 10935911311，1964934 字节，有效期至 2026-12-26T15:45:18Z） 判，执行端不代为下结论）

1. 「逐张整理」tab（按日期）：一叠年卡——后一张压住前一张下缘、只露 72 pt 一条、末卡整张（190）；每张卡：整卡封面 + 上部压暗、左上年份（26 粗）与「N 张 · M 个月」、右上「待删 N」胶囊（非 0 才有）与「已看 N%」或薄荷「看完」、下方薄荷进度条（0% 也有轨道）；十五年约 1.7 屏可滚；页头三件与从前一样。
2. 点年卡进年页：推入动画、系统导航栏与 tab bar 都不见；顶排左返回圆钮、右待删篮圆钮 + 徽标；年标题（40 特粗）右侧「整理整年」胶囊钮；汇总行「N 张 · M 个月 · 已看 X% · 待删 Y」；年进度条（4 高）；月卡叠（步长 80）。
3. 返回钮与屏幕左缘右滑都回到列表，列表滚动位置与页头不变。
4. 年页点「整理整年」进 S2（年范围，续接位置照旧）；返回后**仍在年页**，年卡进度／待删随之更新。点月卡进 S2 月范围；返回后仍在年页，该月卡的进度与「待删 N」更新。
5. 年页点待删篮进 S3；从 S3 返回仍在年页；篮为 0 时圆钮不可点、无徽标；篮非 0 但形成不了提交时（跨启动恢复的老档）底部 toast「暂时无法打开确认页，请重试。」——看 toast 在 tab bar 隐藏后的位置是否合适。
6. 切到「相册」「未分类」：一级卡叠（步长 84、标题 24、副文「N 张」）、点卡直接进 S2；切回「按日期」回到年卡叠（若切走时在年页，回来已是列表）。相册多的库（几十到一百个相册）切到相册维度看首屏耗时与有没有闪退——叠是非惰性的，全部封面一起请求（③ 每张约 2.2 MB 解码图，100 个相册约 220 MB）。
7. 排序翻转：年卡顺序与年页里月卡顺序都翻；封面跟着 `O` 换首张。
8. 封面：宽幅取图是否清晰、竖图裁切是否可接受、取不到图时纯色底；把某年封面那张移入待删篮再回来，封面是否换成下一张。
9. **三件口径反馈**：月卡名现在是范围显示名（③「2026年9月」形态）——要不要改「9 月」；年卡进度只算年范围自己看过的（逐月看过年卡仍 0%）——要不要并各月；年页汇总行同上。
10. 浅色模式再看一遍：两页都恒深色、玻璃件恒深。
11. 一两句总评：卡高 170／步长 72 是否合适、阴影与压暗是否过重、「待删 N」胶囊与「已看」并排会不会挤——数字大、待删多的年卡（如「2375 张 · 12 个月」+「待删 128」+「已看 44%」）一行放不下时只有副文被截成「2375 张 · 1…」——年份不截（`layoutPriority`）、「待删 N」胶囊与「已看 N%」不收缩（`fixedSize`）——这个取舍可不可以；若仍看到胶囊或百分比被截，原样记下机型与数字。

## 十七、发现但未处理（按纪律只报告不修）

1. 旧列表层附属物留作死代码：`S1RangeCoverThumbnail`（仍被 IC151A 当正对照）、`S1RangeCardMetrics`、`S1RangeCardPresentation`、`S1YearStackStyle`、`S1ProgressLineStyle`、`S1CoverImageLoading`／`S1PhotoKitCoverImageLoader`、`coverImageLoader` 形参（无调用者）、展开 API（`toggleYearExpansion`／`collapsedYearRangeIDs`／`isYearExpanded`／`S1RangeRow.isExpanded`）。退役总计会红 6～10 个既有测试函数，归纯重构卡。
2. `S1ChromeForeground.separator` 的文档注释仍写「年卡展开区右缘」，展开区已不再渲染。
3. 年页身份是视图导航态，进了 `Core/` 状态机（分层偏离，③，裁定 三已记录）。
4. 非惰性叠在相册多时的封面请求：③ 358×170 pt × 3 倍率约 2.2 MB／张、100 个相册约 220 MB；备选 `LazyVStack` 负间距。未实测。
5. 会话结束后协调器装新状态机，年页身份随之消失（回列表）。
6. 月卡名与年卡进度按默认口径（范围显示名、年范围自己的 `K[year]`）。
7. 卡头一行放不下时：年份 `layoutPriority(1)` 不截、胶囊与「已看」`fixedSize()` 不收缩，只截副文——SwiftUI 实际表现仅夹具／源码层面落实，真机观感见 H96 第 11 条。
8. 目录首次出现裸 `%`（`已看 {percent}%`）：#366 上 `testIC178E` 通过，`L10n.text` 原样返回；xcstringstool 是否有告警未专门查。
9. `sim_ic178.py` 按提示词只对基线跑，运行时确定性重写了 `Tasks/decision-tools/sim178/` 五个文件（提示词已预告）。

## 十八、40 位 SHA 核验（`git cat-file -e`）

| SHA | 类型 | `git cat-file -e` |
|---|---|---|
| `0d1c3618b0d435fad79067210205a0b8014d60cc` | tree | 存在（退出码 0） |
| `1252482f239458ef5bd3354d2aaad087b04661de` | tree | 存在（退出码 0） |
| `25f7d2583af98d717a9e34724f0f90b9b3879641` | tree | 存在（退出码 0） |
| `3026fadfbe82a93e580af70354bceda7b0f0421f` | blob | 存在（退出码 0） |
| `33014925c99302015c4976e55d856fc5a3d0190a` | commit | 存在（退出码 0） |
| `41acce5c9bab74e780f779ae5162841e32035c6e` | blob | 存在（退出码 0） |
| `496835aa998b98e03951d7c039830103689dec98` | commit | 存在（退出码 0） |
| `498da0346fdb9a6a59db517425d4d97047bda033` | tree | 存在（退出码 0） |
| `4d0cc41734542555bfbb0171c43eb338c72db093` | blob | 存在（退出码 0） |
| `514886dc0afc4083237c976c0f7be6ce597c50a8` | tree | 存在（退出码 0） |
| `702e599df88bef73712eaa05a83490e97b5f7d3b` | blob | 存在（退出码 0） |
| `74088388c62a10eb277921ecf74e766a2d407e80` | tree | 存在（退出码 0） |
| `80ec98560d7f21f8bfc3943d0b30f8aca7f03fb5` | commit | 存在（退出码 0） |
| `844572b4973615ec681278c3f59a345a13d2b21c` | blob | 存在（退出码 0） |
| `96766ed97943720cc381a7a7c8c07cdc2df427d2` | commit | 存在（退出码 0） |
| `9ec88f562791dadf4d4b1eed865b344f7f1333ab` | blob | 存在（退出码 0） |
| `9f0de919e7ef82671279de0e41867c2b0734e175` | blob | 存在（退出码 0） |
| `9fb0b4a4223094a2ce970328036ab4680d942c34` | tree | 存在（退出码 0） |
| `a37707d035b6949aae6fd80406a375b2eddf0d23` | tree | 存在（退出码 0） |
| `ae83298b1925e1defabbcf8a762a6ecd3032ba78` | tree | 存在（退出码 0） |
| `bc80d95fc0b5e99c0be203823686c91e204e6f77` | blob | 存在（退出码 0） |
| `be64dc867250a9edea24145b473b6bb8d25752a2` | tree | 存在（退出码 0） |
| `c3962e5943d08dcc685d6713a9b64b07f299dcbc` | tree | 存在（退出码 0） |
| `d275cd75204107cb4fdbf65a5441078be79b5aea` | blob | 存在（退出码 0） |
| `d640ab07e2b60a0bad59c460a70a0147370938b0` | tree | 存在（退出码 0） |
| `d90ebb32ad3f7b07617f659cfcad30c3098d9fe8` | commit | 存在（退出码 0） |
| `ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e` | tree | 存在（退出码 0） |
| `ed8c9bf7a6dfeeb453cc8377f9a6c2eecb6cf313` | commit | 存在（退出码 0） |
| `fa575d3bfcb682397ade667578785b27c0350b0e` | tree | 存在（退出码 0） |
| `fb2382ef0fbae3a5eca928173fd6e85ad49e3bcc` | tree | 仓库内无此对象（预期：B 单独摘取只在本机克隆里做、未推送）；在克隆 `scratchpad/ic178-exec/clone` 内 `git cat-file -e` 退出码 0 |
| `fcde23316c8ee4c4bca152515f7de18aa8192cd2` | commit | 存在（退出码 0） |

共 31 个不同的 40 位 SHA，缺失 0 个（本节自身不含新增 SHA 之外的对象）。
