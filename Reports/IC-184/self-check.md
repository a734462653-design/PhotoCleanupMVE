# IC-184 自验报告

## 一、结论（先行）

- **三个子项全部按卡面原文完成，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-184-retire-caliber-enums`：B `96322c958fe02a774fc54945d006843aa07a35fd` → C `06fbbd35c5d8136222b3a269338de8430c78e050` → D `427ade499a7dff7e4384d2a77a66fbe5feba6fbd`。
- 分支 CI **#372**（run `36401559610`）一次绿：**940 项 0 失败**（943 − 4 − 2 + 3），真实退出码 0，`OS:26.2, name:iPhone 16`；三条新断言全部 passed。CI 预算 3 次只用 1 次（另加合并后 `main` 一次）。
- 合并提交 `d5cc28472ff36809220d31eda0993ce81b699452`（双亲 `e82d050d35f1f71ec07524fee692226afb4e9fb9`／`427ade499a7dff7e4384d2a77a66fbe5feba6fbd`，树 `77ebc40363ce98ee860fc0caffa0d8932fdd1c01` 与 D 提交树相同）；分支推送（第一次直连 `schannel` 失败、代理也失败，第三次直连成功，未被分类器拦）、合并、推 `main` 都通过。合并后 `main` 运行 **#373（run `36403233229`）一次绿：`Executed 940 tests, with 0 failures`**（摘要 notice 写 941，是日志交错造成的计数虚高，见第四节注与第十七节第 1 条）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面 35 处锚句（B1～B20、C1～C11、D1～D4）替换时各恰 1 处；卡面「改后」与「事实基础」计数逐条相等（第六节，累计 83／83）；八个基线 blob 相符；拷入文件 hash 相符；`sim_ic184.py`（只对基线跑）`FAILURES 0`；`check_ic184.py` 在三个 tip 上 B 105／105、C 106／106、D 107／107 全 PASS、FAIL 0、退出码 0。**没有与卡面矛盾之处，没有停下的项。**
- 零产品行为改动；人工判定项：无（卡「人工判定项」节）。
- 只整删了裁定 一列出的六个测试函数（④ Lynn 2026-09-28 聊天追认，派发提示与卡面均已写明），名单外未删任何测试函数。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡：`<top>/Tasks/IC-20260928-184-retire-caliber-enums.md`；调研 `Tasks/RESEARCH-IC-183-retire-facts.md`（〇、A.1、A.3、A.4、A.5、D）；复核 `Tasks/REVIEW-IC-184-findings.md`（「四、第一轮处置」「六、第二轮处置」，以卡为准）。
- 基线：`main` = `e82d050d35f1f71ec07524fee692226afb4e9fb9`。开工四步：`git status --porcelain` 空（零输出）；`git merge-base --is-ancestor cb83ef537117de4db28857a23435ee586db47a3f main` 退出码 0；`git ls-remote origin refs/heads/main` = `e82d050d35f1f71ec07524fee692226afb4e9fb9`（与本地一致）；八个文件 blob 与卡面表逐条相等（`git rev-parse e82d050:<路径>` 与工作树 `git hash-object` 两列都等于卡面）；**先 `git switch -c feature/ic-184-retire-caliber-enums` 再改文件**。

| 路径 | 卡面 blob | 实测 |
|---|---|---|
| `Features/S1/S1View.swift` | `96ab5dce0a2f56ad94399dc3f818bfb68b4383b4` | 相等 |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | `eeccb6f99f48959ff160bec075cc0193fff3c9d8` | 相等 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | `959a9e602b8e23961df5334db6440488f636487d` | 相等 |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | `9705c71d0d5a2e5864bdd34f959bafcb688c8434` | 相等 |
| `PhotoCleanupMVETests/IC183RetireRenderChainTests.swift` | `69541cdca734fc08798b1a0ed47ac5b63405b369` | 相等 |
| `Core/S1StateMachine.swift` | `bc80d95fc0b5e99c0be203823686c91e204e6f77` | 相等 |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | `64114ed919a4858aa0db4364781886e88692c0ee` | 相等 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `09a692b65b7ef4690cafe28fc47c22142cb93167` | 相等 |

- 范围边界：只做卡「本卡边界」四项。`fillFraction`、`coverAssetID`、`S1NotificationBadgeStyle` 六值与 `chromeRing`、`S1MenuStyle`、`S2AmbientMetrics` 正名、`S1PreviewData`、IC-178 前就零调用的四个成员、`import UIKit`／`Photos`／`PhotosUI`、IC178D 空转负向 needle、目录、`Features/S1/S1DeckCards.swift`／`S1YearPageView.swift`、`Core/` 其余文件、`Features/S0`／`S2～S5`／`Shared`、`Services`、`App`、`.github`、`Scripts`、SPEC 与 Decision_log 均未触碰。
- 改法实施方式：执行端脚本 `scratchpad/ic184-exec/apply.py` 只读导入替换表 `decision-tools/ic184_edits.py`，先把每条 OLD／NEW（去首尾换行）与卡文件原文比对（35／35 都在卡面原文中出现，无一处不符），再在工作树当时文本上断言每个 OLD 恰 1 处后替换、按 LF 字节写回。35 处全部恰 1，无一处停下。另：D 段后八个被改文件与 `sim_ic184.py` 在基线上确定性生成的 `decision-tools/sim184/` 对应文件 `cmp` 逐字节相同（8／8）。
- 空行口径：七个被改的既有文件改后连续两空行（`\n\n\n`）数均与基线相同（0）；删除块的「含其后空行」「含其前空行（B9）」「只删行」三种形状按块处理，行数与卡面一致（B2 3→0、B4 12→0、B5 14→10、B6 7→0、B7 14→0、B8 17→0、B9 6→0、B10 26→0、B15 66→0、B16 3→2、B17 6→0、B18 58→0、C1 11→10、C2 3→1、C3 25→1、C4 16→13、C5 2→1、C6 2→0、C8 35→0、C9 22→0、C10 6→2，其余一行换一行）。

## 三、提交列表

| 子项 | 提交 | 树 | 可摘性 |
|---|---|---|---|
| B 口径枚举退役 + 五份测试 | `96322c958fe02a774fc54945d006843aa07a35fd` | `3ebaebacca988a8ee922f3f98541293c5c2e6610` | 单独可摘（实测见第十二节） |
| C 展开 API 退役 + 两份测试 | `06fbbd35c5d8136222b3a269338de8430c78e050` | `cf7fa4c9a0237a96969bb85cedc51c50e5acc2bb` | 依赖 B（B→C 连续可摘，实测见第十二节） |
| D 新测试 + pbx 测试登记 | `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | `77ebc40363ce98ee860fc0caffa0d8932fdd1c01` | 依赖 B、C |
| 合并 | `d5cc28472ff36809220d31eda0993ce81b699452` | `77ebc40363ce98ee860fc0caffa0d8932fdd1c01` | 双亲 `e82d050d35f1f71ec07524fee692226afb4e9fb9`／`427ade499a7dff7e4384d2a77a66fbe5feba6fbd`；首行 `merge(IC-184): 纯重构（二）——口径枚举与同页展开／收起 API 退役、六个只测退役符号的测试函数整删；零行为改动` |

B、C 两个提交树与复核第二轮克隆里按替换表生成的 B／C 树（`3ebaebac…`／`cf7fa4c9…`）相同。

## 四、CI

| 项 | 分支运行 #372 | 合并后 `main` 运行 #373 |
|---|---|---|
| run id | `36401559610`（attempt 1） | `36403233229`（attempt 1） |
| 被测提交 | `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | `d5cc28472ff36809220d31eda0993ce81b699452` |
| 结论 | completed／success，作业（job `108860386864`）十二步全部 success | completed／success，作业（job `108865791097`）十二步全部 success |
| XCTest | 唯一 Test Case 行 940 条：940 passed／0 failed、0 skipped；`Executed 940 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC184RetireCaliberEnumsTests` 3／3 | `Executed 940 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC184RetireCaliberEnumsTests` 3／3；唯一 Test Case 行见下注 |
| 执行摘要 notice | `Executed 940 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 940 tests / 0 failures` | `Executed 941 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 940 tests / 0 failures`（941 为计数虚高，见下注） |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（同左） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左（同一 id、`OS:26.2, name:iPhone 16`） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1969881，SHA-256 `bd36ba873b0069e35349ca7b0d874d5e44dc400d3adf0707a9601c9fbfed3d7b` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1969881，SHA-256 `6ad6bcbcbb92af13c59b5d836157ff2bc1f1b0252aa3f8a1e3df8800d18f9a94` |
| 分段耗时 notice | `模拟器启动 102 s；xcodebuild test 448 s；总 552 s` | `模拟器启动 99 s；xcodebuild test 372 s；总 478 s` |
| artifact | `PhotoCleanupMVE-unsigned-427ade499a7d`（id 10961077307，1970051 字节，有效期至 2026-12-27T09:08:05Z） | `PhotoCleanupMVE-unsigned-d5cc28472ff3`（id 10962180625，1970051 字节，有效期至 2026-12-27T09:23:56Z） |

数据来源：`actions/runs/<id>`、`actions/runs/<id>/jobs`、`check-runs/<job id>/annotations`、`actions/runs/<id>/artifacts`，以及整包日志 zip 中「9_运行 XCTest.txt」单文件（剔 `##[error]` 与 ANSI 回显行后按唯一 Test Case 行计数）。

**#373 计数注（①，日志实读）**：#373 日志里一条 `passed` 行被模拟器的 os_log 行截断——第 1905 行起 `Test Case '-[PhotoCleanupM2026-09-28 09:31:29.141934+0000 PhotoCleanupMVE[11023:35717] [Client] XPC connection interrupted`，下一行接 `VETests.IC139MediaBadgesTests testIC139A_MediaKindMapsEveryProbeKindWithoutReimplementingPredicate]' passed (0.013 seconds).`。因此：(1) 按完整行正则去重得 939（缺的正是该用例，其 `started` 行与被截断的 `passed` 续行都在，用例实为 passed）；(2) `Scripts/summarize-xctest-log.sh` 的 `identity()` 从被截断行里取到假身份串 `-[PhotoCleanupM2026-09-28 … PhotoCleanupMVE[11023:35717]`，多计 1 得 941。xcodebuild 自身两行 `Executed 940 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`、步骤退出码 0 一致，**#373 真实项数 940、0 失败**；与分支 #372（同树 `77ebc403…`）的 940 项集合比对，只差这一条截断行。该计数脚本不在本卡白名单，未改（第十七节第 1 条）。

项数对账：基线 943（IC-183 合并后 #371）− 4（B 整删 IC128 四函数）− 2（C 整删 S1StateMachineTests 两函数）+ 3（D 新增）= **940**，与 #372 唯一 Test Case 行数（940 passed／0 failed）、`Executed 940 tests` 行、执行摘要 notice 三者一致。本机锚定 `^\s*func\s+test` 计数：B 提交前 939、C 提交前 937、D 提交前 940。整删六个函数名在 #372／#373 日志中均不出现；两个改名后的函数 `testIC177B_HeroPaletteAndAmbientBaseAreFixed`、`testIC128B_ProgressLineFraction` 以新名出现且 passed，旧名不出现。

闸门 G1015 相关测试类（#372 唯一 Test Case 行，全部 passed）：`IC184RetireCaliberEnumsTests` 3／3、`IC183RetireRenderChainTests` 3／3、`IC177UnifiedBackgroundTests` 3／3、`IC178DeckListTests` 5／5、`IC128S1VisualTests` 11／11、`S1StateMachineTests` 20／20、`IC172GlassAlwaysDarkTests` 7／7、`IC171CategoryPageTrioTests` 4／4、`IC156CategoryPageTests` 9／9、`IC148S0VisualTests` 12／12、`IC157LongPressIntoS2Tests` 8／8、`IC167BasketEntryAndTailTests` 5／5、`IC168FallbackDiagnosticsTests` 6／6、`IC169MarkedStateFollowsBasketTests` 6／6（#373 同）。

`testIC063`（陷阱 26）：#372／#373 日志 `building pipeline` 均 0 行，`IC063_WARMUP_GATE_END` 各 1 行，`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 均 passed（6.716 s／7.059 s）。

## 五、本地门禁（三个提交各一份，真实退出码；提交前在工作树改后态上跑）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| B `96322c9` | 0（「结构自验通过」；needle 变体审计扫 60 个测试文件） | 0（残留 0，目录 key 与产品源码引用一致） | 0 |
| C `06fbbd3` | 0 | 0 | 0 |
| D `427ade4` | 0（needle 变体审计扫 61 个测试文件，含新测试） | 0 | 0 |

另：`git diff --check e82d050..427ade4` 包含在三段 `--cached --check` 之内，均 0。

## 六、子项计数实测表（卡面值 / 实测值）

剔注释口径 = 测试 `strippedSource` 的 Python 移植 `decision-tools/strip.py`（只读调用），不重叠计数；切片口径同测试（到 `\n}\n` 或 `\n    }\n`）。脚本 `scratchpad/ic184-exec/count.py` 在各段提交前的工作树上累计跑（后段复跑前段全部项）：B 48／48、C 80／80、D 83／83 全相等，退出码 0。「卡面值」取卡「子项 B／C／D 改后」与「事实基础」表（`static let`／`static func`／`static var`、`UIApplication`／`PHPhotoLibrary`、行数、`@Published`、`func `、`guard !isObscured,`、`state == .ready,` 等来自事实基础与复核表）。下表为 D 提交前的累计全表。

| 项 | 卡面值 | 实测值 | 判定 |
|---|---|---|---|
| S1View 剔注释 `S1RangeCardMetrics` | 0 | 0 | 相符 |
| S1View 剔注释 `S1PendingBadgePresentation` | 0 | 0 | 相符 |
| S1View 剔注释 `S1RangeCardPresentation` | 0 | 0 | 相符 |
| S1View 剔注释 `S1YearStackStyle` | 0 | 0 | 相符 |
| S1View 剔注释 `S1CoverImagePhase` | 0 | 0 | 相符 |
| S1View 剔注释 `targetPixelSize` | 0 | 0 | 相符 |
| S1View 剔注释 `cardRing` | 0 | 0 | 相符 |
| S1View 剔注释 `isVisible(hasContinuation` | 0 | 0 | 相符 |
| S1View 剔注释 `S1ChromeForeground.` | 28 | 28 | 相符 |
| S1View `enum S1ProgressLinePresentation {` 切片 `static func ` | 1 | 1 | 相符 |
| S1View `enum S1RangeCoverPolicy {` 切片 `static func ` | 1 | 1 | 相符 |
| S1View `enum S1NotificationBadgeStyle {` 切片 `static var ` | 1 | 1 | 相符 |
| S1View `enum S1NotificationBadgeStyle {` 切片 `static let ` | 6 | 6 | 相符 |
| S1View 剔注释 `S0DeckMetrics.` | 7 | 7 | 相符 |
| S1View 剔注释 `ProgressView()` | 1 | 1 | 相符 |
| S1View 剔注释 `s1ChromeGlassBackground(` | 4 | 4 | 相符 |
| S1View 剔注释 `enterRange(` | 4 | 4 | 相符 |
| S1View 剔注释 `S1RangeCoverPolicy.coverAssetID(` | 1 | 1 | 相符 |
| S1View 剔注释 `S1DeckListView(` | 1 | 1 | 相符 |
| S1View 剔注释 `S1YearPageView(` | 1 | 1 | 相符 |
| S1View 剔注释 `static let ` | 70 | 70 | 相符 |
| S1View 剔注释 `static func ` | 12 | 12 | 相符 |
| S1View 剔注释 `static var ` | 2 | 2 | 相符 |
| S1View 剔注释 `UIApplication` | 3 | 3 | 相符 |
| S1View 剔注释 `PHPhotoLibrary` | 1 | 1 | 相符 |
| S1View 剔注释 `.primary` > 0 | True | True | 相符 |
| S1View 剔注释 `Material` > 0 | True | True | 相符 |
| S1View 剔注释 `ultraThin` > 0 | True | True | 相符 |
| S1View 原文 `colorScheme, .dark)` | 7 | 7 | 相符 |
| S1View 原文 `.retry()` | 1 | 1 | 相符 |
| S1View 原文 `待删红点描边取卡片底色` | 0 | 0 | 相符 |
| S1View 原文 `范围卡常量与展示口径` | 0 | 0 | 相符 |
| S1View 行数 | 1538 | 1538 | 相符 |
| IC128 剔注释 `S1ProgressLinePresentation.isVisible(` | 0 | 0 | 相符 |
| IC128 剔注释 `S1ProgressLinePresentation.fillFraction(` | 5 | 5 | 相符 |
| IC128 剔注释 `testIC128B_CoverTargetPixelSizeFollowsDisplayScale` | 0 | 0 | 相符 |
| IC128 剔注释 `testIC128B_CoverReplacementNeverDowngrades` | 0 | 0 | 相符 |
| IC128 剔注释 `testIC128B_PendingBadgeHiddenAtZero` | 0 | 0 | 相符 |
| IC128 剔注释 `testIC128B_YearRowHasSeparateExpandAndEnterTargets` | 0 | 0 | 相符 |
| IC128 剔注释 `func testIC128B_ProgressLineFractionAndVisibility(` | 0 | 0 | 相符 |
| IC128 剔注释 `func testIC128B_ProgressLineFraction(` | 1 | 1 | 相符 |
| IC177 剔注释 `cardRing` | 0 | 0 | 相符 |
| IC177 剔注释 `S1YearStackStyle` | 0 | 0 | 相符 |
| IC177 剔注释 `S1NotificationBadgeStyle.chromeRing` | 1 | 1 | 相符 |
| IC177 剔注释 `testIC177B_YearStackHeroPaletteAndAmbientBaseAreFixed` | 0 | 0 | 相符 |
| IC177 剔注释 `func testIC177B_HeroPaletteAndAmbientBaseAreFixed(` | 1 | 1 | 相符 |
| IC183 剔注释 `let metrics` | 0 | 0 | 相符 |
| 状态机 剔注释 `collapsedYearRangeIDs` | 0 | 0 | 相符 |
| 状态机 剔注释 `isYearExpanded` | 0 | 0 | 相符 |
| 状态机 剔注释 `toggleYearExpansion` | 0 | 0 | 相符 |
| 状态机 剔注释 `isExpanded` | 0 | 0 | 相符 |
| 状态机 剔注释 `validRangeIDs` | 0 | 0 | 相符 |
| 状态机 原文 `展开／收起状态是会话内视图态` | 0 | 0 | 相符 |
| 状态机 `visibleRanges` 切片 `continue` | 0 | 0 | 相符 |
| 状态机 `visibleRanges` 切片 `childRanges(of: year.id)` | 1 | 1 | 相符 |
| 状态机 `visibleRanges` 切片 `visible.append(` | 2 | 2 | 相符 |
| 状态机 `S1RangeRow` 切片 `let ` | 7 | 7 | 相符 |
| 状态机 剔注释 `presentedYearRangeID` | 5 | 5 | 相符 |
| 状态机 剔注释 `func presentYearPage(` | 1 | 1 | 相符 |
| 状态机 剔注释 `func dismissYearPage()` | 1 | 1 | 相符 |
| 状态机 剔注释 `didSet` | 4 | 4 | 相符 |
| 状态机 剔注释 `didSet { publishSnapshotIfChanged() }` | 3 | 3 | 相符 |
| 状态机 剔注释 `didSet { pruneYearPageIfNeeded() }` | 1 | 1 | 相符 |
| 状态机 剔注释 `publishSnapshotIfChanged()` | 6 | 6 | 相符 |
| 状态机 剔注释 `setMarked(` | 3 | 3 | 相符 |
| 状态机 剔注释 `applyPendingDeletionDiff(` | 3 | 3 | 相符 |
| 状态机 剔注释 `activeVirtualRangeIDs.remove(` | 2 | 2 | 相符 |
| 状态机 剔注释 `continue` | 1 | 1 | 相符 |
| 状态机 剔注释 `@Published` | 9 | 9 | 相符 |
| 状态机 剔注释 `func ` | 29 | 29 | 相符 |
| 状态机 剔注释 `guard !isObscured,` | 7 | 7 | 相符 |
| 状态机 剔注释 `state == .ready,` | 3 | 3 | 相符 |
| 状态机 行数 | 984 | 984 | 相符 |
| 状态机 `makeS2Handoff(for:)` 函数体与基线逐字相同 | True | True | 相符 |
| S1View 原文 `展开集合恒空` | 0 | 0 | 相符 |
| S1StateMachineTests 剔注释 `testIC127A_CollapsingYearHidesMonthRowsButKeepsRangeData` | 0 | 0 | 相符 |
| S1StateMachineTests 剔注释 `testIC127A_ExpandAndEnterAreDistinctTargets` | 0 | 0 | 相符 |
| S1StateMachineTests 剔注释 `toggleYearExpansion` | 0 | 0 | 相符 |
| IC178 剔注释 `toggleYearExpansion` | 0 | 0 | 相符 |
| 新测试 `git hash-object` | e4d76bff90b5d3ab44b13e53d80ed482065afb07 | e4d76bff90b5d3ab44b13e53d80ed482065afb07 | 相符 |
| pbx `100000000000000000000083` | 3 | 3 | 相符 |
| pbx `200000000000000000000080` | 2 | 2 | 相符 |
| XCTest 锚定 `^\s*func\s+test` | 940 | 940 | 相符 |

分段：B 段累计 48 项（至 IC183 `let metrics` 与锚定 939）；C 段累计 80 项（加状态机、`展开集合恒空`、两份测试与锚定 937）；D 段 83 项（加 hash、两个 pbx id、锚定 940）。三段均无不符。

## 七、零行为钉子与 `check_ic184.py` 输出（`IC184_BASE=e82d050… python -B check_ic184.py <tip> <段>`）

| 段 | tip | SUMMARY | FAIL 行 | 退出码 |
|---|---|---|---|---|
| B | `96322c958fe02a774fc54945d006843aa07a35fd` | `SUMMARY 105 pass / 105` | 无 | 0 |
| C | `06fbbd35c5d8136222b3a269338de8430c78e050` | `SUMMARY 106 pass / 106` | 无 | 0 |
| D | `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | `SUMMARY 107 pass / 107` | 无 | 0 |

每段在提交前先对工作树的 `git write-tree` + `git commit-tree` 悬空提交跑一次（B 105／105、C 106／106、D 107／107），再对正式提交跑一次，结果相同；悬空提交与正式提交的树相同（B `3ebaebac…`、C `cf7fa4c9…`、D `77ebc403…`）。D 段关键行：`PASS machine stripped == stripped(card edits applied) (sha)`、`PASS machine makeS2Handoff(for:) body unchanged (sha)`、`PASS catalog blob unchanged`（`911848e37193b1491b60274549db5ec1c0425a33`）、`PASS changed paths outside whitelist got []`、`PASS changed whitelisted path count got 9 want 9`；76 条 `untouched` 全 PASS。

`sim_ic184.py e82d050…`（只对基线跑）：`anchors OK; edited: 8 files`，162 行 ok，打印 `expected delta` 16 条，`FAILURES 0 []`，退出码 0；`decision-tools/` 无 `__pycache__` 残留。

## 八、拷入文件

- `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift`：`cp` 自 `<top>/Tasks/decision-tools/IC184RetireCaliberEnumsTests.swift`，`cmp` 退出码 0，`git hash-object` = `e4d76bff90b5d3ab44b13e53d80ed482065afb07`（= 卡面值），未改任何一行。

## 九、闸门 G1014～G1017

- **G1014（零行为）**：`check_ic184.py` 三个 tip 全 PASS（第七节，含两条状态机钉子）；#372 绿、937 项既有测试全 passed（940 − 3 新）——满足。
- **G1015（新断言）**：三条新断言 passed；IC177／IC178／IC183／IC128／S1StateMachineTests／IC172／IC171／IC156／IC148／IC157／IC167／IC168／IC169 全部 passed（第四节）——满足。
- **G1016（合并前置）**：G1014～G1015；`git diff --name-only e82d050..427ade4` 恰 9 路径；`untouched` 与 `catalog blob unchanged` 全 PASS；二十九条被保护分支 tip 未变（第十节）；CI 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice，第四节）；pbxproj 撞号扫描（第十一节）；合并前 `git status --porcelain` 空；`ls-remote` 的 `main` 仍为 `e82d050d35f1f71ec07524fee692226afb4e9fb9`（未被他人推进）——满足，已合并推送。
- **G1017（合并后）**：`main` 运行 #373 绿，artifact `PhotoCleanupMVE-unsigned-d5cc28472ff3`（id 10962180625，有效期至 2026-12-27T09:23:56Z）——满足。

## 十、被保护分支（29 条，合并前 `ls-remote` 两次）

`Reports/IC-183/self-check.md` 第十节列名的 28 条（`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`、`feature/ic-169-marked-state-follows-basket` `bf9551e`、`feature/ic-175-similar-recognizer` `8d5bc7b`、`feature/ic-177-unified-background` `3cdae92`、`feature/ic-179-inline-hints` `3de1609`、`feature/ic-180-s5-guide-steps` `219be48`、`feature/ic-178-year-deck-and-page` `ed8c9bf`、`feature/ic-182-tutorial-round-two` `1dbf013`）+ `feature/ic-183-retire-render-chain` `fe96fce8bab6cbcba821262b680c70c37336ddbe`——推送分支后与合并前各查一次，**29／29 与远端头相符**。合并前远端 ref 共 104 行（= IC-183 报告的 103 行 + 本分支一行）。

## 十一、pbxproj 撞号扫描与新 id

- 登记前（C 提交后）重扫：fileRef 族最大 `100000000000000000000082`、buildFile 族最大 `20000000000000000000007F`，与卡面一致；`100000000000000000000083`／`200000000000000000000080` 登记前出现 0 次。
- 登记后：fileRef `100000000000000000000083` 3 处、buildFile `200000000000000000000080` 2 处（卡面值）；四行照卡面原文（制表符与既有行相同）。

## 十二、摘取关系实测（本机克隆 `scratchpad/ic184-exec/clone`，`git -c core.autocrlf=false clone --no-hardlinks` 原仓，再设 `core.autocrlf false`，自 `e82d050` 起，未推送）

| 摘取 | 命令 | 退出码 | 结果树 | 对照 |
|---|---|---|---|---|
| B 单独 | `git cherry-pick -x 96322c958fe02a774fc54945d006843aa07a35fd` | 0 | `3ebaebacca988a8ee922f3f98541293c5c2e6610` | 与 B 提交树相同 |
| B→C 连续 | `git cherry-pick -x 96322c958fe02a774fc54945d006843aa07a35fd 06fbbd35c5d8136222b3a269338de8430c78e050` | 0 | `cf7fa4c9a0237a96969bb85cedc51c50e5acc2bb` | 与 C 提交树相同 |

C 单独未测（卡裁定 二：C 单独可干净 apply 但编译红，摘取单元只有 B；B→C；全部）。

## 十三、三条新断言与函数名（#372／#373 均 passed）

1. `testIC184B_CaliberEnumsRetired`——口径枚举已从 `S1View` 与整个产品源码退役、留下的三只各只剩该留的成员、页头／菜单／玻璃 helper 计数不动、两处注释已改（含正对照）。
2. `testIC184C_ExpandAPIRetiredAndVisibleOrderUnchanged`——展开 API 已从状态机退役 + 树夹具两种 `O` 的可见顺序／行投影／`childCount`／S3 分组顺序／对账后角标。
3. `testIC184D_TestHygiene`——六个被删名 0、四个保留名 1、两个改名新 1 旧 0、退役符号在测试中剔注释 0 等。

## 十四、根因假设

- 本卡不含根因假设（纯重构）。卡「事实基础」的推论①（产品运行时收起集合恒空、删守卫后可见顺序逐位相同）由 `sim_ic184.py` 第 3b 节预演、`testIC184C` 夹具回归钉（#372 passed）与 937 项既有测试全绿共同支持，未见矛盾。

## 十五、规格欠账

两条，都归 SPEC-S1 v12（卡「规格欠账」原样）：
1. 第十一节退役组头五处括注改写——`:749` `S1RangeCardMetrics` 改「十三值 IC-183 已删、余三值 IC-184 已删」；`:764` `S1ProgressLineStyle` 六值 IC-183 已删、本卡另删同族口径 `isVisible`（`fillFraction` 仍被卡片叠借用）；`:772` `cardRing`「随之活代码零引用」→「IC-184 已删」；`:847` `cardRing`「死代码，删除归 IC-183／IC-184」→「IC-184 已删」；`:776` `S1YearStackStyle`「活代码零引用」→「IC-184 已删」。
2. 决策 34（`:77`）「只升不降」替换规则随 `S1CoverImagePhase` 与其唯一测试钉（IC128 `CoverReplacementNeverDowngrades`）退役后不再有测试钉；现役封面 `Features/Shared/S0DeckCoverView.swift` 用 `.opportunistic` 按代次赋值、无相位守卫（S1 封面自 IC-178 改用 `S0DeckCoverView` 起即如此，本卡不改）。

## 十六、人工判定项

- 无。零行为改动，真机不需要判；合并后 `main` 产物（#373 `PhotoCleanupMVE-unsigned-d5cc28472ff3`）与 #371 功能等价。若 Lynn 装包，装最新 `main` 产物即可。

## 十七、发现但未处理（按纪律只报告不修）

1. **执行摘要计数会被交错的 os_log 行虚增（①，#373 实例）**：`Scripts/summarize-xctest-log.sh` 的 `identity()` 对含 `Test Case ` 的行取第一个 `-[…]`，当 `Test Case` 行被模拟器日志行（`… PhotoCleanupMVE[pid:tid] [Client] XPC connection interrupted`）截断时，会取到假身份串并多计 1——#373 notice 写 941 而 xcodebuild 为 940。失败用例识别不受影响（本次 0 失败）。该脚本不在本卡白名单，未改；引用 #373 请以 `Executed 940 tests, with 0 failures` 与 `** TEST SUCCEEDED **` 为准。
2. `S1View.swift` 的 `import UIKit`／`Photos`／`PhotosUI` 保留（`UIApplication` 3、`PHPhotoLibrary` 1 仍在）。
3. `S1MenuStyle` 17 值待 S1 页头卡（随系统 `Menu` 一并退役）。
4. IC178D 三处（`("toggleYearExpansion", 0)`／`("S1RangeCardPresentation.", 0)`／`("S1YearStackStyle.", 0)`）与 IC178 新文件纪律名单两处（`"S1RangeCardMetrics."`／`"S1YearStackStyle."`）负向 needle 在符号整族退役后恒 0、空转（裁定 五，不删）。
5. `S2AmbientMetrics` 正名代价（5 文件 46 处 + 规格与日志 16 处），本卡不做。
6. `S1ChromeForeground` 与 `S1NotificationBadgeStyle` 文档里对 v18 §11.2 的引用仍指旧规格版本号。
7. SPEC-S1 v11 决策 34「只升不降」随 `S1CoverImagePhase` 退役失去测试钉、现役 `S0DeckCoverView` 无相位守卫（规格欠账 (2)）。
8. 分支首推时直连与 `-c http.proxy` 各失败一次（`schannel: failed to receive handshake`），第三次直连成功——网络抖动，非分类器拦截。

## 十八、40 位 SHA 核验（`git cat-file -e`）

见本节下方表（报告写完后对两份报告里出现的全部 40 位十六进制串逐个跑 `git cat-file -t <sha>` 取类型、再跑 `git cat-file -e <sha>^{<类型>}`，本机原仓）。`check_ic184.py` 输出里的剔注释文本哈希与 `makeS2Handoff(for:)` 函数体哈希（`hash-object --stdin` 现算、不写入对象库）以及 IPA SHA-256（64 位）不是仓库对象，不在核验范围。

| SHA | 类型 | `cat-file -e` 退出码 |
|---|---|---|
| `06fbbd35c5d8136222b3a269338de8430c78e050` | commit | 0 |
| `09a692b65b7ef4690cafe28fc47c22142cb93167` | blob | 0 |
| `13a6c6fe0a2c69ed59124e11a146b1d8ddaf8960` | blob | 0 |
| `3b343d30528909f5233d6a82a4974a90844d5164` | blob | 0 |
| `3ebaebacca988a8ee922f3f98541293c5c2e6610` | tree | 0 |
| `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | commit | 0 |
| `64114ed919a4858aa0db4364781886e88692c0ee` | blob | 0 |
| `69541cdca734fc08798b1a0ed47ac5b63405b369` | blob | 0 |
| `77ebc40363ce98ee860fc0caffa0d8932fdd1c01` | tree | 0 |
| `911848e37193b1491b60274549db5ec1c0425a33` | blob | 0 |
| `959a9e602b8e23961df5334db6440488f636487d` | blob | 0 |
| `96322c958fe02a774fc54945d006843aa07a35fd` | commit | 0 |
| `96ab5dce0a2f56ad94399dc3f818bfb68b4383b4` | blob | 0 |
| `9705c71d0d5a2e5864bdd34f959bafcb688c8434` | blob | 0 |
| `9e6055f6ed325f31d3721aff9c62c5a5b3667606` | blob | 0 |
| `b755a6bd85b3b247a69dd477bae3e6c2c4818352` | blob | 0 |
| `bc80d95fc0b5e99c0be203823686c91e204e6f77` | blob | 0 |
| `be813c91c3e471e7997e27be1be24f60cf4b919b` | blob | 0 |
| `c3534e4febc66e8ef17fd8e5f0fec17df1c45d7f` | blob | 0 |
| `cb83ef537117de4db28857a23435ee586db47a3f` | commit | 0 |
| `cf7fa4c9a0237a96969bb85cedc51c50e5acc2bb` | tree | 0 |
| `d5cc28472ff36809220d31eda0993ce81b699452` | commit | 0 |
| `e4d76bff90b5d3ab44b13e53d80ed482065afb07` | blob | 0 |
| `e6d4721c7f1b23ba7f56cb2021fa9a69fbfdb5a5` | blob | 0 |
| `e82d050d35f1f71ec07524fee692226afb4e9fb9` | commit | 0 |
| `eeccb6f99f48959ff160bec075cc0193fff3c9d8` | blob | 0 |
| `fab23ebaf50bf22c12207ca739b285efbe1a405c` | blob | 0 |
| `fe96fce8bab6cbcba821262b680c70c37336ddbe` | commit | 0 |

28 个 40 位 SHA 全部存在（commit 7、tree 3、blob 18），退出码全 0。
