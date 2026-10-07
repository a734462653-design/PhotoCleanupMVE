# IC-185 自验报告

## 一、结论（先行）

- **三个子项全部按卡面原文完成，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-185-nav-maintenance`：A `c37e8bfcac4468b48335f464d246012323ec1cf7` → B `c3e8d8e014e5373627b487264403c86277b83b37` → C `7872de5b90922c986fa9b7f9d2a6c3dd11580959`。
- 分支 CI **#374**（run `37572289018`）一次绿：**945 项 0 失败**（940 + 5），真实退出码 0，`OS:26.2, name:iPhone 16`；五条新断言全部 passed，G1021 点名的八个测试类全部 passed。合并后 `main` 运行 **#375**（run `37573346878`）一次绿：**945 项 0 失败**。CI 预算 3 次只用 2 次（分支一次、合并后 `main` 一次）。
- 合并提交 `04b8d47dd85c3dca81f601437bc39ad24c3c2462`（双亲 `46e82e7cb07aa964e00205d086d15a0d74726fb7`／`7872de5b90922c986fa9b7f9d2a6c3dd11580959`，树 `453a236891c300e92a17534186f2fbdd990cd8c4` 与 C 提交树相同）。分支推送、合并、推 `main` 都一次通过，**没有被分类器拦**。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面 18 处锚句（A1～A4、B0～B9、C1～C4）替换时各恰 1 处；三个被改文件基线 blob 相符；三个拷入文件 `git hash-object` 与卡面值相等；`sim_ic185.py`（只对基线跑，加 `IC185_GATES=1`、`IC185_CLONE=1`）`FAILURES 0`；`check_ic185.py` 在 A／B／C 三个 tip 上 5／5、8／8、9／9 全 PASS、FAIL 0、退出码 0。**没有与卡面矛盾之处，没有停下的项。**
- **探针已打印（G1022）**：三行 `first`／`rebuilt`／`hostScenes` 的 `uikit=` 全是 `na`（第十四节）。这是①模拟器数据，卡裁定 四要求只打印、不据它改任何东西，本卡没改。**对后续有用的一点（发现未处理第 1 条）：从 `UIHostingController` 沿 `UIViewController.children` 找不到 `UITabBarController`，真机上 `S0TabRouteDiagnostics.uikitSelectedTabIndex()`（同一遍历）很可能同样给 `na`，会削弱 `uikit=` 字段区分形状 (ii) 的能力。**
- 零行为改动面：B 只记不改（协调器、`S2View`、目录一字未动）；A 只在「栈里多于一页且无进行中转场」时让系统边缘手势开始。真机观感全部保留给 Lynn（H98，第十七节）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡：`<top>/Tasks/IC-20261006-185-nav-maintenance.md`；调研 `Tasks/RESEARCH-NAV-maintenance-facts.md`（全文）、`Tasks/RESEARCH-H96-H97-facts.md`（Q1、Q3）；复核 `Tasks/REVIEW-IC-185-findings.md`（第四节第一轮处置、第六节第二轮处置；该文件无第三节，是编号跳号），以卡为准。
- 基线：`main` = `46e82e7cb07aa964e00205d086d15a0d74726fb7`。开工四步：`git status --porcelain` 空（零输出）；`git merge-base --is-ancestor d5cc28472ff36809220d31eda0993ce81b699452 main` 退出码 0；`git ls-remote origin refs/heads/main` = `46e82e7cb07aa964e00205d086d15a0d74726fb7`（与本地一致）；三个被改文件 blob 与卡面表逐条相等（`git rev-parse main:<路径>` 与工作树 `git hash-object` 两列都等于卡面）；**先 `git checkout -b feature/ic-185-nav-maintenance 46e82e7…` 再改文件**。

| 路径 | 卡面 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `559b0c7cd6f2510fd3973a5d47cf668c6921c523` | 相等 |
| `PhotoCleanupMVE/Features/S0/S0TabContainer.swift` | `9a80395451f031f86e30873917f003c63c10c6c3` | 相等 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `e6d4721c7f1b23ba7f56cb2021fa9a69fbfdb5a5` | 相等 |

- 范围边界：只做卡「本卡边界」三项。`S1YearPageView.swift`、`S0DeckCategoryPageView.swift`、`S0CleanupFlowView.swift`、`S1View.swift`、`S2View.swift`、`CleanupCoordinator.swift`、目录 `Localizable.xcstrings`、`Scripts/`、`.github/`、任何既有测试文件、SPEC 与 Decision_log 均未触碰（`check_ic185.py` 逐段核目录 blob 不变）。
- 改法实施方式：执行端脚本 `scratchpad/ic185-exec/apply.py` 直接从卡文件原文解析每个「把／改为」代码块（18／18 都解析到），先在内存里对每处断言「把」块在当时文本恰 1 处（整行匹配）、全部通过才写盘，否则中止且不写任何文件；新文件从 `Tasks/decision-tools/ic185/` 逐字节 `copyfile`，写盘前核 `git hash-object`；按 LF 字节写回（仓库工作树文件为 LF）。18 处全部恰 1，无一处停下。

## 三、提交列表

| 子项 | 提交 | 树 | 可摘性 |
|---|---|---|---|
| A 左缘右滑 | `c37e8bfcac4468b48335f464d246012323ec1cf7` | `cf00ed0e1197b2feb4c0f761ddff8b54704d5170` | 单独可摘（实测见第十二节） |
| B tab 落点诊断 | `c3e8d8e014e5373627b487264403c86277b83b37` | `3252a727fbb130db363785283da2b70ce7a6345e` | 单独可摘；A→B 连续可摘（实测见第十二节） |
| C 新测试 + pbx 测试登记 | `7872de5b90922c986fa9b7f9d2a6c3dd11580959` | `453a236891c300e92a17534186f2fbdd990cd8c4` | 依赖 A、B |
| 合并 | `04b8d47dd85c3dca81f601437bc39ad24c3c2462` | `453a236891c300e92a17534186f2fbdd990cd8c4` | 双亲 `46e82e7cb07aa964e00205d086d15a0d74726fb7`／`7872de5b90922c986fa9b7f9d2a6c3dd11580959`；首行 `merge(IC-185): 导航维护——年页／类别页左缘右滑返回、tab 落点诊断时间线（只记不改）` |

`git diff --name-only 46e82e7…..<tip>`：A 2 路径、B 累计 5 路径、C 累计 6 路径（卡面白名单合计 6）。

## 四、CI

| 项 | 分支运行 #374 | 合并后 `main` 运行 #375 |
|---|---|---|
| run id | `37572289018`（attempt 1） | `37573346878`（attempt 1） |
| 被测提交 | `7872de5b90922c986fa9b7f9d2a6c3dd11580959` | `04b8d47dd85c3dca81f601437bc39ad24c3c2462` |
| 结论 | completed／success，作业（job `112633375264`）十二步全部 success | completed／success，作业（job `112636686586`）十二步全部 success |
| XCTest | 唯一 Test Case 行 945 条：945 passed／0 failed；`Executed 945 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC185NavigationMaintenanceTests` 5／5 | 同左：唯一 Test Case 行 945 条 945 passed／0 failed；`Executed 945 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC185NavigationMaintenanceTests` 5／5 |
| 执行摘要 notice | `Executed 945 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 945 tests / 0 failures` | 同左（与 xcodebuild 小计、唯一 Test Case 行集合三者一致，**无计数虚增**；两次日志里 Test Case 行都没有被 os_log 截断的） |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（同左） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左（同一 id、`OS:26.2, name:iPhone 16`） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1975842，SHA-256 `a294fcdda84d7c9477f2b3aa1b661353a98b642404007383d1ad87d85d687e7a` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1975842，SHA-256 `97460047129e94471121541e14ae68c441c1a2e8897009610c36a79453304bee` |
| 分段耗时 notice | `模拟器启动 82 s；xcodebuild test 374 s；总 458 s` | `模拟器启动 79 s；xcodebuild test 453 s；总 534 s` |
| artifact | `PhotoCleanupMVE-unsigned-7872de5b9092`（id 11461886263，1976012 字节，有效期至 2027-01-05T04:36:42Z） | `PhotoCleanupMVE-unsigned-04b8d47dd85c`（id 11460904781，1976012 字节，有效期至 2027-01-05T04:50:02Z） |

数据来源：`actions/runs/<id>`、`actions/runs/<id>/jobs`、`check-runs/<job id>/annotations`、`actions/runs/<id>/artifacts`，以及整包日志 zip 中「9_运行 XCTest.txt」单文件（剔 `##[error]` 与 ANSI 回显行后按唯一 Test Case 行计数；`Executed 945 tests` 与 `** TEST SUCCEEDED **` 取自该文件）。

项数对账：基线 940（IC-184 合并后 #373 的 xcodebuild 真值）+ 5（C 新增）= **945**，与 #374／#375 唯一 Test Case 行数、`Executed 945 tests` 行、执行摘要 notice 三者一致。本机锚定 `^\s*func\s+test`：基线 940、C 提交后 945。

`testIC063`（陷阱 26）：#374／#375 日志 `building pipeline` 均 0 行，`IC063_WARMUP_GATE_END` 各 1 行，`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 均 passed（6.417 s／6.729 s）；未触发复跑。

## 五、本地门禁（三个提交各一份，真实退出码；提交前在暂存后的工作树上跑）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A `c37e8bf` | 0（「结构自验通过」；needle 变体审计扫 61 个测试文件） | 0（残留 0，目录 key 与产品源码引用一致） | 0 |
| B `c3e8d8e` | 0（61 个测试文件） | 0 | 0 |
| C `7872de5` | 0（62 个测试文件，含新测试） | 0 | 0 |

## 六、子项 B「改后」计数实测表（卡面值 / 实测值）

口径：`s` = 剔注释并去字符串字面量内容（与测试 `strippedSource` 同口径，`decision-tools/strip.py`）；`r` = 原文。实测在 B 提交的树上用 `count_b.py`（基于 `scan.py`／`strip.py`）取，基线列为 `46e82e7` 同口径；32 行全部相等，`COUNT FAILS 0`。

| 文件 | 口径 | needle | 基线 | 卡面 | 实测 |
|---|---|---|---|---|---|
| App | s | `@StateObject private var tabDiagnostics = S0TabRouteDiagnostics()` | 0 | 1 | 1 |
| App | s | `s0TabSelection.onSelect = {` | 0 | 1 | 1 |
| App | s | `tabDiagnostics.note(` | 0 | 2 | 2 |
| App | s | `.onChange(of: coordinator.route) {` | 0 | 1 | 1 |
| App | s | `exitDiagnosticsText: coordinator.s2ExitDiagnosticsText.withTabDiagnostics(tabDiagnostics.text)` | 0 | 1 | 1 |
| App | s | `S0TabRouteDiagnostics.uikitSelectedTabIndex()` | 0 | 2 | 2 |
| App | r | `" uikit="` | 0 | 1 | 1 |
| App | r | `"settled uikit="` | 0 | 1 | 1 |
| App | s | `exitDiagnosticsText: coordinator.s2ExitDiagnosticsText`（既有） | 1 | 1 | 1 |
| App | s | `s0TabSelection.selectedTab == .cleanup`（既有） | 2 | 2 | 2 |
| App | s | `s0TabSelection.select(`（既有） | 1 | 1 | 1 |
| App | s | `S0TabContainer(`（既有） | 1 | 1 | 1 |
| App | s | `tabContainer(s1Machine: machine)`（既有） | 1 | 1 | 1 |
| App | s | `presentCleanupFeedbackEvent(`（既有） | 3 | 3 | 3 |
| App | s | `consumeS1FeedbackEvent()`（既有） | 2 | 2 | 2 |
| App | s | `feedbackToastDurationMilliseconds`（既有） | 4 | 4 | 4 |
| App | s | `advanceScan()`（既有） | 2 | 2 | 2 |
| App | s | `onSnapshotDidChange`（既有） | 1 | 1 | 1 |
| App | r | `similarDiagnosticsText: s0DataProvider.similarDiagnosticsReport()`（既有） | 1 | 1 | 1 |
| App | r | `case .s2:` 六行逐字块（既有） | 1 | 1 | 1 |
| App | r | 启动守卫 `if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {…}`（既有） | 1 | 1 | 1 |
| 容器 | s | `var onSelect: ((S0Tab, S0Tab) -> Void)?` | 0 | 1 | 1 |
| 容器 | s | `let previous = selectedTab` | 0 | 1 | 1 |
| 容器 | s | `onSelect?(previous, tab)` | 0 | 1 | 1 |
| 容器 | s | `selectedTab = tab`（仍唯一赋值） | 1 | 1 | 1 |
| 容器 | s | `selectionCount += 1` | 1 | 1 | 1 |
| 容器 | s | `.tabItem` | 2 | 2 | 2 |
| 容器 | s | `.tag(S0Tab.` | 2 | 2 | 2 |
| 容器 | s | `TabView(` | 1 | 1 | 1 |
| 协调器 | s | `S0Tab` | 0 | 0 | 0 |
| 协调器 | s | `tabDiagnostics` | 0 | 0 | 0 |
| 协调器 | s | `S0TabRouteDiagnostics` | 0 | 0 | 0 |

`git diff --name-only 46e82e7…..<B>` 恰 5 路径（卡面「改后」）。C 提交里的诊断文件与测试源码断言（`@MainActor` 2、`@Published` 0、`return "` 0、`import ` 2 等）由 `testIC185B_SourceWiringRecordsOnlyAndKeepsExistingPins` 在 CI 上实跑通过（#374／#375 passed），并经 `sim_ic185.py` 预演相符。

## 七、`check_ic185.py` 输出（`python -B check_ic185.py <tip> <段>`）

| 段 | tip | SUMMARY | FAIL 行 | 退出码 |
|---|---|---|---|---|
| A | `c37e8bfcac4468b48335f464d246012323ec1cf7` | 5 pass / 5 | 无 | 0 |
| B | `c3e8d8e014e5373627b487264403c86277b83b37` | 8 pass / 8 | 无 | 0 |
| C | `7872de5b90922c986fa9b7f9d2a6c3dd11580959` | 9 pass / 9 | 无 | 0 |
| docs（合并之后、docs 提交落地前，在 `git commit-tree` 造的试写提交上只核路径集合；该试写提交不入任何分支，不列 SHA） | 试写提交（合并提交之上、含两份报告） | 9 pass / 9 | 无 | 0 |

每段核的内容：累计触及的每个路径的 git blob 逐一等于「基线 + 卡面改法 + 拷入新文件」；`git diff --name-only` 恰等于白名单；基线是 tip 的祖先；目录 blob 不变。提交前的预核用 `git commit-tree` 造临时提交对象（不动任何分支）在 A 与 B 上各跑一次，也全 PASS；未提交的 C 在写盘后直接对真提交跑。

`sim_ic185.py 46e82e7… `（`IC185_GATES=1 IC185_CLONE=1`）：`FAILURES 0`；锚句 A 4 + B 10 + C 4 = 18 处各恰 1；叠加树本地门禁两项退出码 0；A 单独／B 单独／A→B 摘取干净；XCTest 本机锚定 940 → 945。该脚本按卡文确定性重写了 `decision-tools/sim185/`（卡许可的唯一例外）。

## 八、拷入文件（`git hash-object`，卡面值 / 实测值）

| 仓库路径 | 卡面 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVE/Features/Shared/NavigationEdgeSwipeBack.swift` | `3ead735f8914caf9556a5566d413eafdf7a24aef` | `3ead735f8914caf9556a5566d413eafdf7a24aef`（写盘前核一次，C 提交里 `git rev-parse` 再核一次，合并后 `main` 上又核一次，都相等） |
| `PhotoCleanupMVE/App/S0TabRouteDiagnostics.swift` | `762434217b66d4852b832eda9f388df9fbe36591` | `762434217b66d4852b832eda9f388df9fbe36591`（同） |
| `PhotoCleanupMVETests/IC185NavigationMaintenanceTests.swift` | `0220c6760997bb94db1e4700a5bd038f5c75f033` | `0220c6760997bb94db1e4700a5bd038f5c75f033`（同） |

三被改文件合并后 blob：`project.pbxproj` `3c2f0d5d8f30a8682bbdda3acd818ddd4bc04ccb`、`PhotoCleanupMVEApp.swift` `ee16d563bd2ca20987b3af34a57bc154bfa74724`、`S0TabContainer.swift` `7161544d064bd26283bb8f9825f7534b912ae7e3`（`check_ic185.py` 逐个与「基线 + 卡面改法」生成值相等）。

## 九、闸门 G1020～G1024

| 闸门 | 内容 | 结果 |
|---|---|---|
| G1020（行为与落位） | `check_ic185.py` 在 A／B／C 三个 tip 上全 PASS | 通过（第七节；5／5、8／8、9／9） |
| G1021（新断言） | 五条 `testIC185*` passed；IC147／IC148／IC156／IC157／IC165／IC168／IC175／IC178 全部 passed | 通过（#374／#375：五条新断言 5／5；IC147 16／16、IC148 12／12、IC156 9／9、IC157 8／8、IC165 6／6、IC168 6／6、IC175 8／8、IC178 5／5；另 IC160 4／4、IC167 5／5、IC170 6／6、IC171 4／4、IC172 7／7、IC177 3／3、IC179 9／9、IC182 5／5、IC183 3／3、IC184 3／3 也全 passed） |
| G1022（探针） | 贴 `IC185_TAB_PROBE_BEGIN`～`END` 之间三行 | 已打印，见第十四节 |
| G1023（合并前置） | G1020～G1022 + CI 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice、执行摘要与小计一致）+ 三十条被保护分支 tip 未变 + pbxproj 撞号扫描 + 工作树净 + `main` 未被他人推进 | 全部满足后才合并：#374 绿；30／30 保护分支 tip 与远端头相符（推送前、推送后、合并前各查一次，第十节）；撞号扫描通过（第十一节）；`git status --porcelain` 空；合并前 `git ls-remote origin refs/heads/main` 仍 `46e82e7…` |
| G1024（合并后） | `main` 运行绿，报告记 artifact | 通过：#375 绿，artifact `PhotoCleanupMVE-unsigned-04b8d47dd85c`（id 11460904781，有效期至 2027-01-05T04:50:02Z） |

## 十、被保护分支（30 条）

卡闸门 G1023 列名的三十条：`Reports/IC-184/self-check.md` 第十节的二十九条（该节所列 28 条短 SHA 加 `feature/ic-183-retire-render-chain` `fe96fce8bab6cbcba821262b680c70c37336ddbe`）+ `feature/ic-184-retire-caliber-enums` `427ade499a7dff7e4384d2a77a66fbe5feba6fbd`。用脚本 `scratchpad/ic185-exec/protected.py` 对 `git ls-remote origin` 逐条比对前缀：**推送分支前 30／30、推送分支后 30／30、合并前 30／30 与远端头相符**（远端 ref 共 104 行（推送前）→ 105 行（本分支一行））。合并并推 `main` 之后再查一次也是 30／30（合并只动 `main`）。三条冻结分支与各条探针分支均在这三十条之内、未触碰。

## 十一、pbxproj 撞号扫描与六个新 id

- 登记前（基线 `46e82e7`）用 `pbxscan.py` 重扫：一行对象定义共 fileRef 124／buildFile 121，**无重复 id**；fileRef 族最大 `100000000000000000000083`、buildFile 族最大 `200000000000000000000080`，与卡面一致；六个新 id 在基线各出现 0 次。
- 登记后（C 提交）：fileRef 127／buildFile 124，无重复 id；最大 `100000000000000000000086`／`200000000000000000000083`。六个新 id 各自出现次数与定义数：

| id | 文件 | 出现 | 定义 |
|---|---|---|---|
| `100000000000000000000084` | `NavigationEdgeSwipeBack.swift`（fileRef） | 3 | 1 |
| `200000000000000000000081` | 同上（buildFile） | 2 | 1 |
| `100000000000000000000085` | `S0TabRouteDiagnostics.swift`（fileRef） | 3 | 1 |
| `200000000000000000000082` | 同上（buildFile） | 2 | 1 |
| `100000000000000000000086` | `IC185NavigationMaintenanceTests.swift`（fileRef） | 3 | 1 |
| `200000000000000000000083` | 同上（buildFile） | 2 | 1 |

pbxproj 共新增 12 行（三个文件各四行，A 接 `S5GuideStepsView`、B 接 `CleanupCoordinator`、C 接 `IC184RetireCaliberEnumsTests`，互不相邻，制表符与既有行相同）。CI 上六个新 id 对应的三个文件都编进了产物（#374 编译通过、945 项含新测试）。

## 十二、摘取关系实测（本机克隆 `scratchpad/ic185-exec/clone`，`git clone --no-hardlinks` 原仓，自基线 `46e82e7` 起，未推送）

| 摘取 | 命令 | 退出码 | 结果树 | 对照 |
|---|---|---|---|---|
| A 单独 | `git cherry-pick -x c37e8bfcac4468b48335f464d246012323ec1cf7` | 0 | `cf00ed0e1197b2feb4c0f761ddff8b54704d5170` | 与 A 提交树相同；改动 2 路径 |
| B 单独 | `git cherry-pick -x c3e8d8e014e5373627b487264403c86277b83b37` | 0 | `158facc1322cd0aca406f89d7a85e71b14c7ab85` | 改动 4 路径（pbx、App、诊断文件、容器；无 A 的文件、不依赖 A） |
| A→B 连续 | `git cherry-pick -x c37e8bfcac4468b48335f464d246012323ec1cf7 c3e8d8e014e5373627b487264403c86277b83b37` | 0 | `3252a727fbb130db363785283da2b70ce7a6345e` | 与 B 提交树相同 |
| A→B→C 全部 | `git cherry-pick -x c37e8bfcac4468b48335f464d246012323ec1cf7 c3e8d8e014e5373627b487264403c86277b83b37 7872de5b90922c986fa9b7f9d2a6c3dd11580959` | 0 | `453a236891c300e92a17534186f2fbdd990cd8c4` | 与 C 提交树及合并提交树相同 |

每次摘取后克隆工作树 `git status --porcelain` 为空。C 单独未测（卡：C 依赖 A、B，可摘单元只有 A；B；A→B；全部）。

## 十三、五条新断言与函数名（#374／#375 均 passed）

1. `testIC185A_EdgeSwipeBackDelegateGatesOnStackDepth`——运行时：`UINavigationController` 加载视图后左缘手势代理 === 控制器自己，一页不开始、push 后开始、pop 回一页又不开始；源码：扩展文件六个 needle 各 1、原文 `import ` 1；全部产品源码剔注释 `extension UINavigationController` 1、`interactivePopGestureRecognizer` 1。
2. `testIC185B_TabSelectionReportsEveryWrite`——回报顺序与旧 → 新、计数 3；不接回报时照旧。
3. `testIC185B_TimelineFormatCapAndJoin`——首行 `format=ic185-tab-v1`、事件行 `t=<ms> <事件>`、上限 24 丢最旧、全 ASCII、两种拼接。
4. `testIC185B_SourceWiringRecordsOnlyAndKeepsExistingPins`——子项 B「改后」的全部 needle（含既有钉子不变）+ 协调器 `S0Tab`／`tabDiagnostics`／`S0TabRouteDiagnostics` 0 + 诊断文件落位。
5. `testIC185C_TabContainerRebuildProbe`——只打印三行，另断言写入计数 ≥ 1 与 `uikitSelectedTabIndex()` 非空。

## 十四、探针三行原文（①模拟器数据，iOS 26.2 / iPhone 16；#374 与 #375 完全相同）

```
IC185_TAB_PROBE_BEGIN
first tab=organize n=1 uikit=na
rebuilt tab=organize n=1 uikit=na
hostScenes uikit=na
IC185_TAB_PROBE_END
```

找法：整包日志 zip 里 `构建、XCTest 与未签名产物/9_运行 XCTest.txt`，`grep -n IC185_TAB_PROBE` 各 1 处 BEGIN／END。`testIC185C_TabContainerRebuildProbe` passed（0.820 s／0.823 s）。

读法（只陈述数据，不据此改任何东西）：
- ①`first` 与 `rebuilt` 两次：选中态都是 `organize`、写入计数都是 1（只有测试开头那一次 `select(.organize)`）——模拟器 iOS 26.2 上，把 `S0TabContainer` 建、拆、再建，`TabView` **没有**经 binding 额外回写任何 tab（形状 (i) 在模拟器上未出现）。这只能证伪模拟器 iOS 26.2，证明不了真机 26.5／26.6（卡裁定 二）。测试里的窗口是 `UIWindow(frame:)`、未挂在 scene 上。
- ①三行的 `uikit=` 都是 `na`：`first`／`rebuilt` 用的是从 `UIHostingController` 沿 `UIViewController.children` 递归找 `UITabBarController`，没找到；`hostScenes` 是测试宿主 App 自己的窗口（根路由停在 `.loading`，没有 `TabView`），`na` 在预期之内。
- ③推测：iOS 26.2 上 SwiftUI `TabView` 不是作为子视图控制器挂在 `UIHostingController` 之下的，所以产品里 `S0TabRouteDiagnostics.uikitSelectedTabIndex()`（同一套 `children` 遍历，从各 scene 窗口的根控制器起找）在真机上也很可能给 `na`。验证法：真机复现一次取回诊断文本，若 `appear`／`settled` 两笔的 `uikit=` 仍是 `na`，则该字段区分不了形状 (ii)，须另卡改成按视图层级找（`UITabBar`／responder chain）。

## 十五、根因假设

卡不含需要在本卡内确认或推翻的根因假设：根因 ③（S2 左上退出有时落到「空间清理」tab）本卡不修，只装诊断（卡 裁定 二，陷阱 7「先测再改」）。#374／#375 的探针数据（第十四节）与既有证据**不矛盾**：源码里没有任何写 `.cleanup` 的路径（调研 1.1），形状 (i) 在模拟器上未出现；真机取回的 `format=ic185-tab-v1` 时间线才能定案。

## 十六、规格欠账（三条，本卡不改任何规格；归本批 SPEC 同批修订，第 219 条第四节）

1. SPEC-S1 v11 五处「边缘右滑 ③ 真机待判，H96 第 3 条」（`:237`、`:322`、`:432`、`:457`、`:506`）改为条款「年页支持屏幕左缘右滑返回列表，与返回钮同一出口」。
2. SPEC-S0 v5 类别页全文无边缘右滑条款——新增「类别页支持屏幕左缘右滑返回首页，收尾与返回钮相同（重算、返回事件；保留集与滚动锚点在下次进类别时清空）」（S0 v6 同批）。
3. S1 v11 `:263`／`:346`／`:436` 只写「回到发起进入的那一页」、S2 v23 `:531` 只写「交回数据后离开 S2」，两份都无 tab 级落点条款——S1 v12 与 S2 v24 补「从『逐张整理』进入 S2，退出后仍在『逐张整理』tab」（修法待诊断，条款可先行）。

## 十七、人工判定项（H98，真机；保留给 Lynn，执行端不代判）

1. 「逐张整理」年页：屏幕左缘向右滑回到年卡列表，列表滚动位置与页头不变；滑到一半松手取消，停留在年页、不卡住。
2. 「空间清理」类别页：左缘右滑回到首页（类别页是缩放进入的，看右滑的观感是否自然）；回首页后卡片叠与总条正常；再进同一类别从最上面开始、勾选不保留（与返回钮一致）。滑到一半松手取消：留在类别页，勾选与滚动位置都不变、首页没有闪一下重排。
3. 两个 tab 的根页、S2 相簿 sheet 里的相簿列表：左缘右滑没有反应、不卡住；S2 看图页本身的左右翻页不受影响。
4. 快速进出年页／类别页、推入动画还没走完就右滑：不卡死、不白屏。
5. 若再遇到「S2 左上退出落到『空间清理』」：先切回「逐张整理」→ 再进一次 S2 → 长按顶部中胶囊 → 标定面板末段「S2 退出诊断」→ 复制整段发给决策会话（末尾有 `format=ic185-tab-v1` 那段时间线）。没遇到就记「未复现」。
6. 一两句总评。

装包取合并后 `main` 产物 `PhotoCleanupMVE-unsigned-04b8d47dd85c`（#375，id 11460904781）。

## 十八、发现但未处理（按纪律只报告不修）

1. **探针 `uikit=na`（①模拟器；③真机推测，第十四节）**：`uikitSelectedTabIndex()` 的 `children` 遍历在 iOS 26.2 模拟器上找不到 `UITabBarController`，真机上很可能也是，则诊断文本里 `uikit=` 字段区分不了形状 (ii)。时间线里的 `write …->…` 行与 `appear tab=… n=…` 仍然有效（区分形状 (i)）。卡裁定 四：只打印不改，本卡没动；需要时另卡改遍历方式。
2. **面板「无记录」分支不再可达（①，卡 裁定 三已写明的后果）**：`exitDiagnosticsText` 自此恒非 nil，`s2.calibration.exit_diagnostics.empty` 分支在产品里不再可达；key 与分支都留着，扫描器双向检查不受影响（#374 的「扫描用户可见硬编码字符串」步骤 success）。
3. **时间线只在「进 S2 那一刻」取一次（①，设计如此）**：`s2Screen(machine:)` 构造时取 `tabDiagnostics.text`，所以要看「退出之后」的 tab，须再进一次 S2 才能在面板末段看到（卡 H98 第 5 条已写步骤）。
4. **S2 相簿 sheet 内的 `NavigationStack` 也被新扩展接管代理（①，卡 事实基础已述）**：栈恒一页，`viewControllers.count > 1` 恒假，不开始；真机 H98 第 3 条看。
5. 执行端过程记录：后台轮询脚本第一版用裸 `bash` 调 `ghq.sh` 返回 127（Python 子进程找不到 PATH 里的 bash），改全路径后正常；不涉及仓库，未影响任何提交。
6. 本卡未触碰 `Scripts/summarize-xctest-log.sh`（第 217 条第四节的截断行多计问题）：#374／#375 日志里没有被截断的 Test Case 行，计数无虚增。

## 十九、40 位 SHA 核验（`git cat-file -e`）

对 `self-check.md` 与 `change-list.md` 两份报告里出现的全部 40 位十六进制串（21 个）逐个跑 `git cat-file -t <sha>` 取类型、再跑 `git cat-file -e <sha>^{<类型>}`，本机原仓；只存在于摘取实测克隆里的对象（B 单独摘取的结果树）在该克隆里核验并在行内标注。IPA SHA-256（64 位）与本报告所在 docs 提交自身不是核验对象。

| SHA | 类型 | `cat-file -e` 退出码 |
|---|---|---|
| `0220c6760997bb94db1e4700a5bd038f5c75f033` | blob | 0 |
| `04b8d47dd85c3dca81f601437bc39ad24c3c2462` | commit | 0 |
| `158facc1322cd0aca406f89d7a85e71b14c7ab85` | tree（只在摘取实测克隆里，原仓无此对象） | 0 |
| `3252a727fbb130db363785283da2b70ce7a6345e` | tree | 0 |
| `3c2f0d5d8f30a8682bbdda3acd818ddd4bc04ccb` | blob | 0 |
| `3ead735f8914caf9556a5566d413eafdf7a24aef` | blob | 0 |
| `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | commit | 0 |
| `453a236891c300e92a17534186f2fbdd990cd8c4` | tree | 0 |
| `46e82e7cb07aa964e00205d086d15a0d74726fb7` | commit | 0 |
| `559b0c7cd6f2510fd3973a5d47cf668c6921c523` | blob | 0 |
| `7161544d064bd26283bb8f9825f7534b912ae7e3` | blob | 0 |
| `762434217b66d4852b832eda9f388df9fbe36591` | blob | 0 |
| `7872de5b90922c986fa9b7f9d2a6c3dd11580959` | commit | 0 |
| `9a80395451f031f86e30873917f003c63c10c6c3` | blob | 0 |
| `c37e8bfcac4468b48335f464d246012323ec1cf7` | commit | 0 |
| `c3e8d8e014e5373627b487264403c86277b83b37` | commit | 0 |
| `cf00ed0e1197b2feb4c0f761ddff8b54704d5170` | tree | 0 |
| `d5cc28472ff36809220d31eda0993ce81b699452` | commit | 0 |
| `e6d4721c7f1b23ba7f56cb2021fa9a69fbfdb5a5` | blob | 0 |
| `ee16d563bd2ca20987b3af34a57bc154bfa74724` | blob | 0 |
| `fe96fce8bab6cbcba821262b680c70c37336ddbe` | commit | 0 |

核验结果：21 个全部退出码 0。
