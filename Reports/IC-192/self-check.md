# IC-192 自验报告

## 一、结论（先行）

- **两个子项全部按卡面完成（逐字节拷入 `ic192/stages/`，未手改一行），G1055～G1059 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-192-v1-header`：A `d68c65f923655af8bf4502acfa51c7afb15ec81d` → B `c56110df32ea23821d50206891d36a8236966c01`。
- 分支 CI **#388**（run `37934749742`，被测提交 B `c56110df32ea23821d50206891d36a8236966c01`）一次绿：**971 项 0 失败**（970 − 3 + 4），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 1998525 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `d8c10e312f700ac35defb5c8d7efecc363b2785b`（双亲 `bb2dee9e1abca32397e2db514eb2c2e084e7095d`／`c56110df32ea23821d50206891d36a8236966c01`，树 `cce7f8c6e3451ddaaa89d3dd89bf396c02c94e7c` 与 B 提交的树相同）。合并后 `main` CI **#389**（run `37936737759`）绿：971 项 0 失败，artifact `PhotoCleanupMVE-unsigned-d8c10e312f70`（id `11619411238`，有效期至 2027-01-07T13:25:30Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 11 个、B 2 个）、卡面 A「改后」计数与工作树实测逐条相等（A 段 69 条检查，0 处不符）；提交后 `check_ic192.py` A／B 两个 tip 全 PASS（13／14）。
- **有界面变化**：「逐张整理」tab 的页头与列表页结构整体换成 V1，人工判定项 H100 八条保留给 Lynn（第十四节），本报告不对观感下结论。
- 本次没有停卡项，没有执行端偏离卡面的改动，没有被分类器拦截，没有中途中断。唯一的网络波动：`git push origin main` 第一次报 `schannel: failed to receive handshake`（`main` 未变），原命令重试一次即成功（`bb2dee9..d8c10e3`）。`materialize_ic192.py` 未跑（明令不跑）；`sim_ic192.py` 对基线跑了一次（FAILURES 0，见第五节），它按约定重写了 `decision-tools/sim192/`；除此之外 `Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（`check_ic192.py` 与 `sim_ic192.py` 一律 `python -B`，无 `__pycache__`；`gh_runs.py` 用 `GH_OUT` 指向 scratchpad）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-192-v1-header.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-192.md`；调研 `Tasks/RESEARCH-S1R-3b-header-facts.md`；裁定 `Tasks/PLAN-S1R-3-rulings-20261009.md`（第三、五节）；复核结论 `Tasks/REVIEW-IC-192-findings.md` 第三、四节（处置与第二轮）。
- 基线 `main` = `bb2dee9e1abca32397e2db514eb2c2e084e7095d`（IC-191 报告补记；合并提交 `78983887aeaee2a239d07a29bb9efc37f2472056`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 78983887aeaee2a239d07a29bb9efc37f2472056 main` 退出码 0；`git ls-remote origin refs/heads/main` = `bb2dee9e1abca32397e2db514eb2c2e084e7095d`（与本地一致）；被改 10 个文件基线 blob 与卡面表逐一相等（下表，`git rev-parse HEAD:<路径>` 与 `git hash-object <路径>` 两种读法都核了）；**先切分支再改文件**（`git checkout -b feature/ic-192-v1-header`，此前本卡分支在本地与远端均不存在）。

| 路径 | 卡面基线 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `ee6960429c947b7d0cd64bdca6cbb55af22c4ea7` | 相等 |
| `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | `d275cd75204107cb4fdbf65a5441078be79b5aea` | 相等 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | `be813c91c3e471e7997e27be1be24f60cf4b919b` | 相等 |
| `PhotoCleanupMVE/Localizable.xcstrings` | `911848e37193b1491b60274549db5ec1c0425a33` | 相等 |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | `13a6c6fe0a2c69ed59124e11a146b1d8ddaf8960` | 相等 |
| `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift` | `c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2` | 相等 |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | `9e6055f6ed325f31d3721aff9c62c5a5b3667606` | 相等 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | `db7f7a63c6d54b1a04abb9043d99ef7dcc9326b0` | 相等 |
| `PhotoCleanupMVETests/IC183RetireRenderChainTests.swift` | `c3534e4febc66e8ef17fd8e5f0fec17df1c45d7f` | 相等 |
| `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `36b8952e54cb0b1254f692134740f44d246b4db3` | 相等 |

- 范围边界：只做卡「本卡边界」两项（A 产品 + 目录 + 随改既有测试 + 页头 pbx；B 新测试 + pbx）。状态机、协调器、App 入口、`S1YearPageView.swift`、S0 各页、`S1View.swift` 的玻璃 helper 与徽标层、四态占位、年页构造、`Scripts/`、`.github/`、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）一字未动；`git diff --name-only bb2dee9e1abca32397e2db514eb2c2e084e7095d..c56110df32ea23821d50206891d36a8236966c01` 恰 12 路径，全在白名单内。
- 改法实施方式：`cp -r Tasks/decision-tools/ic192/stages/<子项>/. <repo>/`，每个子项拷入后对清单里该子项每个文件跑 `git hash-object`（读 `manifest.json` 与工作树的只读脚本），全部相等才逐个 `git add <路径>`（不用 `-A`）与提交；`git status --porcelain` 在 `add` 之前恰列该子项的文件（A 10 个 `M` + 1 个 `??`、B 1 个 `M` + 1 个 `??`）。`ic192/whole/`、`ic192/*.py`、`ic192/*.swift` 源料没有拷、没有跑。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `d68c65f923655af8bf4502acfa51c7afb15ec81d` | `f3606d0aef6c00b94f92b8d2e2d3f31aca664f26` | V1 页头与系统 `Menu`：新文件 `S1PageHeader.swift`；`S1View.swift` 页面结构重写（就绪时整页滚动、受限条挪到胶囊下），旧顶排／中胶囊／两只自绘菜单／维度提示等退役；`S1DeckListView` 让出滚动；目录 +8／−5；六个既有测试随改；pbx 四行（11 个文件） |
| B | `c56110df32ea23821d50206891d36a8236966c01` | `cce7f8c6e3451ddaaa89d3dd89bf396c02c94e7c` | 新测试 `IC192PageHeaderTests.swift`（四条，逐字节拷入）+ pbx 四行（2 个文件；依赖 A） |
| 合并 | `d8c10e312f700ac35defb5c8d7efecc363b2785b` | `cce7f8c6e3451ddaaa89d3dd89bf396c02c94e7c` | `merge(IC-192): 「逐张整理」V1 页头 + 系统 Menu——行内标题、排序 Menu、待删篮入口与人像圆钮、大数字区、副行、维度胶囊；就绪时整页滚动；旧顶排与自绘菜单退役` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-192/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --name-only` 基线..B 恰 12 路径（936 行增、714 行删）。分支推送一次成功（`git push -u origin feature/ic-192-v1-header`，git 直连无需代理，无分类器拦截）；推 `main` 第二次尝试成功（第一次 `schannel` 握手失败，见第一节）。

## 四、逐子项提交前对读与拷入文件 `git hash-object`

脚本 `scratchpad/ic192-exec/counts_a.py`：读工作树文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（`Tasks/decision-tools/strip.py` 只读导入），逐条数卡面「改后（剔注释）」段列出的计数，并解析目录 JSON 核键集；脚本 `verify_blobs.py` 读 `manifest.json` 与 `git hash-object`。每个子项都是提交前跑、全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic192.py` 又用 `git rev-parse <tip>:<路径>` 核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `a806db44f9867ee6f44a59b3645e1479b6b0f14b` | `a806db44f9867ee6f44a59b3645e1479b6b0f14b` | 相等 |
| A | `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | `09caecb79813ae1bafa9ac2608bb353d4575aaa0` | `09caecb79813ae1bafa9ac2608bb353d4575aaa0` | 相等 |
| A | `PhotoCleanupMVE/Features/S1/S1PageHeader.swift` | `e9ec888342b5312f6168fccfa3c24bf3c783ecd5` | `e9ec888342b5312f6168fccfa3c24bf3c783ecd5` | 相等 |
| A | `PhotoCleanupMVE/Features/S1/S1View.swift` | `b8261fa8d28014290f4852aa6ae3155debc3917c` | `b8261fa8d28014290f4852aa6ae3155debc3917c` | 相等 |
| A | `PhotoCleanupMVE/Localizable.xcstrings` | `855e9d34764d1465f242d68a6a5cae7b1825c4b2` | `855e9d34764d1465f242d68a6a5cae7b1825c4b2` | 相等 |
| A | `PhotoCleanupMVETests/IC128S1VisualTests.swift` | `e42933e2484b40739c58a987f2ed48a19d484d66` | `e42933e2484b40739c58a987f2ed48a19d484d66` | 相等 |
| A | `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift` | `ae88645f582b8c6d7af113e03f59be900df4e20c` | `ae88645f582b8c6d7af113e03f59be900df4e20c` | 相等 |
| A | `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | `ded3661611e7cfc5f714b66a57ee34f5f58219cd` | `ded3661611e7cfc5f714b66a57ee34f5f58219cd` | 相等 |
| A | `PhotoCleanupMVETests/IC178DeckListTests.swift` | `ba9ac874cd5f89ee4481271731151a1120c7ca76` | `ba9ac874cd5f89ee4481271731151a1120c7ca76` | 相等 |
| A | `PhotoCleanupMVETests/IC183RetireRenderChainTests.swift` | `734c3c897e443a8559033de583e9b8b75303616e` | `734c3c897e443a8559033de583e9b8b75303616e` | 相等 |
| A | `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `4a379bc4f6afca4ff87b32e5c51e1edeab5cdb1d` | `4a379bc4f6afca4ff87b32e5c51e1edeab5cdb1d` | 相等 |
| B | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `45f115fe4bb6fd4a5398f9def3c89e7bfde7cca2` | `45f115fe4bb6fd4a5398f9def3c89e7bfde7cca2` | 相等 |
| B | `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | `c26011857d2c7788a2300dc12754fe61cc8bf0e4` | `c26011857d2c7788a2300dc12754fe61cc8bf0e4` | 相等 |

**子项 A「改后」计数（卡面 vs 工作树实测，提交前）**——69 条检查全相等（下表把同类并列项合并；`S1View` 退役名 14 个各 0、页头文件纪律 8 个各 0、目录新 key 8 个在／退役 key 5 个不在各合为一行）：

| 对象 | 计数项 | 卡面 | 实测 |
|---|---|---|---|
| `S1View.swift`（剔注释） | `S1ChromeForeground.` | 17 | 17 |
| 同上 | `S0DeckMetrics.` | 7 | 7 |
| 同上 | `colorScheme, .dark)` | 5 | 5 |
| 同上 | `s1ChromeGlassBackground(` | 3 | 3 |
| 同上 | `Material` | 2 | 2 |
| 同上 | `ultraThin` | 1 | 1 |
| 同上 | `.primary` | 5 | 5 |
| 同上 | `S1PageHeader(` | 1 | 1 |
| 同上 | `machine.headerSummary` | 1 | 1 |
| 同上 | `onOpenAccount: {}` | 1 | 1 |
| 同上 | `sortOrderBinding` | 2 | 2 |
| 同上 | `machine.switchSortOrder(to: newValue)` | 1 | 1 |
| 同上 | `ScrollView {` | 1 | 1 |
| 同上 | `if machine.state == .ready {` | 1 | 1 |
| 同上 | `S1TrashButtonAction.perform(` | 2 | 2 |
| 同上 | `readCurrentRequestIfPossible()` | 4 | 4 |
| 同上 | `ZStack(alignment: .top) {` | 1 | 1 |
| 同上 | `S1DeckListView(` | 1 | 1 |
| 同上 | `S1YearPageView(` | 1 | 1 |
| 同上 | `enterRange(` | 4 | 4 |
| 同上 | 退役名 `S1ChromeSubtitle`／`S1ActiveMenu`／`S1MenuStyle`／`S1DimensionMenuHintModel`／`activeMenu`／`chromeColumn`／`menuContainer`／`overlayTopOffset`／`listTopOffset`／`limitedListTopOffset`／`bannerToListSpacing`／`capsuleChevronPointSize`／`groupingTitle`／`sortTitle` | 各 0 | 各 0 |
| 同上（原文） | `.retry()` | 1 | 1 |
| `S1PageHeader.swift`（原文） | `import `／`import SwiftUI` | 各 1 | 各 1 |
| 同上（原文） | `Text("`／`return "` | 各 0 | 各 0 |
| 同上（剔注释） | `Material`／`colorScheme`／`GlassEffectContainer`／`NavigationStack`／`@MainActor`／`PHAsset`／`ScrollView`／`S1StateMachine` | 各 0 | 各 0 |
| 同上 | `Menu {` | 1 | 1 |
| 同上 | `Picker(` | 1 | 1 |
| 同上 | `S0BasketEntryView(style: .glass, count: badgeCount, action: onBasket)` | 1 | 1 |
| 同上 | `.disabled(!chromeModel.controlsEnabled)` | 4 | 4 |
| 同上 | `.opacity(chromeModel.controlsOpacity)` | 3 | 3 |
| 同上 | `S1PageHeaderMetrics` 切片 `static let` | 41 | 41 |
| `S1DeckListView` 切片（剔注释） | `ScrollView` | 0 | 0 |
| 目录 | 键数 | 284 | 284 |
| 同上 | 八条新 key 在（`s1.header.title`／`total_label`／`seen_label`／`subtitle.date`／`subtitle.album`／`basket`／`confirm`、`s1.volume.counting`） | 是 | 是 |
| 同上 | 五条退役 key 不在（`s1.chrome.subtitle_format`、`s1.dimension.accessibility`、三条 `s1.menu.dimension.*`） | 是 | 是 |
| 同上 | `s0.` 键数 | 41 | 41 |

子项 B 没有「改后」计数段（卡面只给「XCTest 970 → 971；`git diff --name-only` 恰 12 路径」）；提交前核了拷入 blob（上表）、pbx 撞号扫描（第十二节）、本地门禁（第六节）、`IC192PageHeaderTests.swift` 里恰 4 个 `func test`（`testIC192A_…`／`B_…`／`C_…`／`D_…`），以及 `IC128S1VisualTests.swift` 的 `func test` 数基线 11 → 8（−3）。

## 五、`check_ic192.py` 两段 SUMMARY 与 `sim_ic192.py`

`check_ic192.py` 在刚提交的 tip 上跑（基线取脚本默认值 `bb2dee9`；`IC_REPO` 指向原仓；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `d68c65f923655af8bf4502acfa51c7afb15ec81d` | `SUMMARY 13 pass / 13`（blob 11 + `changed paths == whitelist (11)` + `base is ancestor`） | 0 |
| B | `c56110df32ea23821d50206891d36a8236966c01` | `SUMMARY 14 pass / 14`（blob 12 + `changed paths == whitelist (12)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

`python -B sim_ic192.py`（只对基线跑，默认选项，未加 `IC192_GATES`／`IC192_CLONE`）：`FAILURES 0 []`；其中 `XCTest count base 970 after 971`、`pbx lines added 8`、`pbx duplicate ids []`、目录与产品源码引用键双向一致、新测试四个函数名与卡面一致。

## 六、本地门禁（两个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 用 `powershell -NoProfile -ExecutionPolicy Bypass -File …`（Windows PowerShell 5.1）在仓库根跑；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0（「结构自验通过」，扫描 69 个测试源文件） | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致」） | 0 |
| B | 0（扫描 70 个测试源文件，含新测试文件） | 0 | 0 |

## 七、验收门禁逐条（G1055～G1059）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1055 行为与落位 | 满足 | 第五节：`check_ic192.py` A、B 两个 tip 全 PASS |
| G1056 新断言与随改断言 | 满足 | CI #388 与 #389 的整包日志按唯一 Test Case 行数出 971 passed／0 failed；四条 `testIC192*` 全部 passed（`IC192PageHeaderTests` 套件 passed）；`IC128S1VisualTests`（含改名 `testIC128C_LimitedBannerVisibility`）、`IC172GlassAlwaysDarkTests`、`IC177UnifiedBackgroundTests`、`IC178DeckListTests`、`IC183RetireRenderChainTests`、`IC184RetireCaliberEnumsTests`、`IC148S0VisualTests`、`IC156CategoryPageTests`、`IC171CategoryPageTrioTests`、`AlbumScopeWiringTests`、`IC131S1TrashBadgeTests`、`IC132SubmissionDeadEndTests`、`IC191DeckDataTests` 十三个测试类在 #388 的日志里各出现 `Test Suite '…' passed` |
| G1057 不回退 | 满足 | `IC178DeckListTests.testIC178B_YearPageIdentityLivesInMachineWithGuards`（#388 0.003 s）、`IC191DeckDataTests.testIC191C_OpenCardsFollowTheOpenRule`（0.001 s）、`FullFlowRoutingTests.testIC048_006S5ExitEndsSessionAndRebuildsS1Session`（0.029 s）在 #388 均 passed |
| G1058 合并前置 | 满足 | G1055～G1057 + CI #388 绿（见第八节：真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 1998525 字节与 SHA-256、分段耗时 notice；摘要 971 与 xcodebuild 小计 971 一致，无需按第 217 条第四节另核）+ 37 条被保护分支 tip 未变（第十一节）+ pbxproj 撞号扫描（第十二节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote origin refs/heads/main` 仍为 `bb2dee9e1abca32397e2db514eb2c2e084e7095d`） |
| G1059 合并后 | 满足 | 合并后 `main` CI #389 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #388 | 合并后 `main` 运行 #389 |
|---|---|---|
| run id | `37934749742` | `37936737759` |
| 被测提交 | `c56110df32ea23821d50206891d36a8236966c01` | `d8c10e312f700ac35defb5c8d7efecc363b2785b` |
| 触发 | push 到 `feature/ic-192-v1-header`（2026-10-09T13:08:34Z 创建） | push 到 `main`（2026-10-09T13:25:29Z 创建） |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 971 项，0 失败（xcodebuild `Executed 971 tests, with 0 failures (0 unexpected) in 48.281 (49.689) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 971 passed／0 failed） | 971 项，0 失败（`Executed 971 tests, with 0 failures (0 unexpected) in 61.259 (66.946) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 971 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 971 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 971 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`；日志 `XCTest 已全部通过。`） | 0（同） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（日志另有 xcodebuild 警告 `Using the first of multiple matching destinations`，目的地已按 id 钉死） | 同一行 |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 1998525 字节，SHA-256 `57580c9634ef440d4f2e473ed06e14dbc62d2542c44a08385816a045c674216f` | 1998525 字节，SHA-256 `34a7638c615766cf44d2de7a9dd06df917010cd2d308500a3fbfbc09238d330a`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 85 s；xcodebuild test 367 s；总 454 s` | `模拟器启动 99 s；xcodebuild test 517 s；总 618 s` |
| artifact | `PhotoCleanupMVE-unsigned-c56110df32ea`，id `11618077548`，1998695 字节，有效期至 2027-01-07T13:08:35Z | `PhotoCleanupMVE-unsigned-d8c10e312f70`，id `11619411238`，1998695 字节，有效期至 2027-01-07T13:25:30Z |
| 四条 `testIC192*` 用例耗时（日志 `Test Case … passed (N seconds)`） | A `testIC192A_PresentationFollowsStateAndDimension` 0.003 s；B `testIC192B_MetricsMatchSpec2dHeader` 0.001 s；C `testIC192C_CatalogAddsEightKeysAndRetiresFive` 0.007 s；D `testIC192D_SourceWiring` 0.268 s | A 0.006 s；B 0.001 s；C 0.004 s；D 0.383 s |

- 两次构建日志里没有任何一条 warning 指向 `S1PageHeader.swift`、`S1View.swift`、`S1DeckCards.swift` 或本卡改动的测试文件（整包日志逐行扫描）；没有出现类型检查超时、`Menu`／`Picker` 推断错误或扫描器红。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）。#389 的 xcodebuild 段（517 s）比 #388（367 s）长 150 s，两次的唯一 Test Case 行都是 971 passed，属 runner 耗时波动，未归因（③：同一代码树两次运行的差异，没有对应的测试内证据）。
- CI 预算 3 次，用了 1 次（#388）；#389 为合并后 `main` 运行，不计入试错预算。

## 九、四条新断言与随改、删除的既有断言

**四条新断言（`PhotoCleanupMVETests/IC192PageHeaderTests.swift`，逐字节拷入，blob `c26011857d2c7788a2300dc12754fe61cc8bf0e4`）**

| 断言 | 函数名 | 内容（据卡面 B 节） |
|---|---|---|
| 1 展示口径 | `testIC192A_PresentationFollowsStateAndDimension` | 四态数值位（骨架／照常／照常／不显示）、副行前段三种写法与 S1-3 的零、待删篮段显隐、维度与排序名、四类件同用顶排模型（加载中 0.4 不可触发、读取失败待删篮仍可触发） |
| 2 登记值 | `testIC192B_MetricsMatchSpec2dHeader` | 2d 页头段逐值、两个推导量（页头块高 166、卡叠上距 14）、卡内暂登八值、分隔符、`S1ChromeLayout.itemSpacing` 仍 8 |
| 3 目录 | `testIC192C_CatalogAddsEightKeysAndRetiresFive` | 八条新 key 的值与 `L10n.text`、五条退役 key 不在、借用 key 仍在、`s0.` 41、待删篮格式串 |
| 4 源码落位 | `testIC192D_SourceWiring` | 页头文件纪律与写法计数、S1View 退役名 0 与新接线计数、`stateContent` 里卡叠上距、列表让出滚动、全产品四个退役类型名 0 |

**删除与改名（`IC128S1VisualTests`）**

| 动作 | 函数名 | 说明 |
|---|---|---|
| 整删 | `testIC128A_CapsuleSubtitleCountsUnionAndRangeCount` | 只测退役符号 `S1ChromeSubtitle`（IC-184 先例） |
| 整删 | `testIC128C_MenusAreMutuallyExclusive` | 只测退役符号 `S1ActiveMenu` |
| 整删 | `testIC128C_DimensionMenuHintsFollowReadState` | 只测退役符号 `S1DimensionMenuHintModel` |
| 改名 | `testIC128C_LimitedBannerVisibilityAndListTopOffset` → `testIC128C_LimitedBannerVisibility` | 删偏移半段（`S1LimitedBannerPresentation.listTopOffset`），留显隐半段 |
| 删半段 | `ChromeMetrics` 里 `overlayTopOffset`／`listTopOffset`／`limitedListTopOffset` 的恒等式 | 三个偏移与 `bannerToListSpacing` 退役 |

**随改的既有断言（均由 A 的拷入文件带入，未手改）**

| 文件 | 断言 | 旧 → 新 |
|---|---|---|
| `IC172GlassAlwaysDarkTests` | 子项 C 菜单配方探针（`menuReference`／`menuOverride`/`assertOverride(…"menu")`）整段删；S1 深色覆盖落位 | 三种材质配方 → 两种；`colorScheme, .dark)` 7 → 5；十三处 → 十一处；切片列表删 `chromeBar` 与 `menuContainer` 两片 |
| `IC177UnifiedBackgroundTests` | `testIC177C` S1 行元组与正对照 | 元组 `(S1View 路径, 28, 7, 1)` → `(…, 17, 7, 1)`（第一列 `S1ChromeForeground.` 28 → 17，其余列不变）；`colorScheme, .dark)` 7 → 5；`s1ChromeGlassBackground(` 4 → 3；注释随改 |
| `IC178DeckListTests` | `testIC178D` 计数表与 `rootPage` 切片 | `S1ChromeForeground.` 28 → 17、`colorScheme, .dark)` 7 → 5、`s1ChromeGlassBackground(` 4 → 3；`rootPage` 切片名单换为 `ZStack(alignment: .top) {`／`stateContent`／`pageHeader`／`limitedBannerRow`／`pageContainer {`／`S1ChromeForeground.pageBackground` 各 1，另加 `chromeColumn`／`menuScrim`／`menuOverlay` 各 0 |
| `IC183RetireRenderChainTests` | `testIC183A` | `S1ChromeForeground.` 28 → 17、`s1ChromeGlassBackground(` 4 → 3 |
| `IC184RetireCaliberEnumsTests` | `testIC184B` | 同上 28 → 17、4 → 3 |

项数对账：`970 − 3 + 4 = 971`（CI 的 `Executed 971 tests`，唯一 Test Case 行 971）。

## 十、摘取关系实测

克隆：`git clone --no-hardlinks -c core.autocrlf=false D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE <scratchpad>/ic192-exec/clone1`，克隆成功（退出码 0）后才开始；所有命令带 `git -C <克隆>`；克隆里每个单元先 `checkout -b pick* bb2dee9e1abca32397e2db514eb2c2e084e7095d` 再 `cherry-pick -x`，原仓没有建任何其它分支。

| 单元 | 命令 | 退出码 | 结果树 |
|---|---|---|---|
| A 单独 | `cherry-pick -x A` | 0 | `f3606d0aef6c00b94f92b8d2e2d3f31aca664f26`（= A 提交的树，改动 11 路径） |
| A→B 连续 | `cherry-pick -x A B` | 0 | `cce7f8c6e3451ddaaa89d3dd89bf396c02c94e7c`（= B 提交的树 = 合并提交的树，改动 12 路径） |

没有测 B 单独（卡面声明 B 单独文本可摘但编译依赖 A 的类型，不作可摘单元）。克隆实测只证文本无冲突，绿由 CI 证（#388 是 A→B 连续序列的绿，A 单独的绿未单独跑 CI）。

## 十一、G1058 被保护分支核对

`Tasks/decision-tools/ic192_protected_branches.txt`（37 行 `分支名 SHA`、无注释行，只读）对 `git ls-remote --heads origin` 逐条比对（每次 `ls-remote` 返回 111 行，非空）：

- 推送分支之后第一次核：checked 37、mismatch 0（`main` 仍为 `bb2dee9e1abca32397e2db514eb2c2e084e7095d`，本卡分支为 `c56110df32ea23821d50206891d36a8236966c01`）。
- 合并前再核（分支 CI 绿之后）：checked 37、mismatch 0（`main` 仍为 `bb2dee9e1abca32397e2db514eb2c2e084e7095d`）。
- 合并推送之后又核：checked 37、mismatch 0（`main` 为 `d8c10e312f700ac35defb5c8d7efecc363b2785b`，本卡分支仍为 `c56110df32ea23821d50206891d36a8236966c01`）。

三条冻结分支与其余被保护分支 tip 均未变。

## 十二、pbxproj 撞号扫描与四个新 id

- 对象定义行（`24 位 id /* … */ = {`）去重扫描：A 提交后定义 312、B 提交后定义 314，两次重复均为 0。
- 四个新 id 出现次数：fileRef `100000000000000000000093`（`S1PageHeader.swift`）3、`100000000000000000000094`（`IC192PageHeaderTests.swift`）3（定义 + 组 children + buildFile 引用）；buildFile `200000000000000000000090`、`200000000000000000000091` 各 2（定义 + 源码／测试阶段）。与卡面一致（基线最大号 fileRef `100000000000000000000092`、buildFile `20000000000000000000008F`）。
- `git diff --cached --check` 两个提交均 0。

## 十三、规格欠账与已知遗留（卡面十条 + 一条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S1 修订）

1. S1-1 骨架的样式与尺寸（卡内暂登 `skeleton*` 七值）。
2. 受限提示条在胶囊与卡叠之间的上距 14（卡内暂登）。
3. 「统计中」在大数字位与已看位的字号字重取同位单位字号（26）与百分号字号（13），规格未登记。
4. 人像圆钮读屏借 `s0.account.title`，值「你的空间」与规格「账户」不符。
5. S1-4 大数字区与已看位「不显示数值」落为同尺寸透明占位（不画骨架、不画「统计中」），副行前段不画、待删篮段自左缘起。
6. 页头已看在 `U` 取不到时与大数字同一「统计中」占位（G4，IC-191 欠账 (1) 的显示面）。
7. 年页仍是 v11 版式、自带滚动与钉住的顶排，V1 归 ③c／③d。
8. 维度胶囊 S1-1 不可触发但不降暗（规格字面），S1-1 在切维度时几乎看不到，真机难判。
9. S1-1 副行 = 前段骨架 + 待删篮段照常（「去确认」不可触发）——`:329` 与 `:342` 合读，规格没写待删篮段在骨架旁怎么排。
10. 页头随页滚动（就绪时整页一个 `ScrollView`，G2）照首页先例，规格无条文。
- **已知遗留（不在本卡删）**：`S1ChromeBarModel.badgeText` 与 `S1NotificationBadgeStyle.chromeRing` 在本卡之后只剩测试读者（徽标改由 `S0BasketEntryView` 画）。实测（合并后 `main`，`grep` 产品源码）：`chromeRing` 只剩 `S1View.swift:78` 的定义一行；`S1ChromeBarModel.badgeText` 只剩 `S1View.swift` 里的字段声明（`:99`）与 `make` 赋值（`:108`），没有产品读者（`S2View.swift` 里的 `badgeText` 属于另一个类型 `S2ConfirmationEntryPresentation`，不相干）。归后续退役卡。

## 十四、人工判定项（保留给 Lynn 真机判定，执行端不代为下结论）

H100 八条（装合并后 `main` 运行 #389 的包，artifact `PhotoCleanupMVE-unsigned-d8c10e312f70`，id `11619411238`）：

1. 「逐张整理」页头：左「逐张整理」、右排序钮／待删篮入口／人像圆钮；其下「照片与视频占用」大数字（扫描完成后是 GB 数、扫描中「统计中」）与右侧「已看 N%」；副行「N 张 · M 年」（有待删时接「待删篮 N 张 · 去确认」）；再下三只维度胶囊。整体观感与首页是否一个语言。
2. 排序钮：点开是系统菜单两项「最新在前」「最旧在前」、当前项打勾；选另一项年卡顺序翻转。浅色、深色模式各看一次弹出／收回有没有闪纯白或纯黑（H93 同形，未定项 28）。
3. 维度胶囊：点「相册」「未分类」切换、选中态正确；点当前一只没有反应。
4. 待删篮入口与副行「去确认」都进确认页；待删篮为空时两者都不可点、副行不显示后段。
5. 人像圆钮点了没有反应（④ 第 228 条：照首页先例，等账户 sheet）。
6. 列表就绪时页头随卡叠一起往上滚；受限授权时提示条在胶囊下、卡叠上。
7. 进年页、返回、进 S2 再回来，页头与列表位置正常；年页本身不变（V1 年页归后续卡）。
8. 读取失败时（在系统设置里关掉本 App 的照片权限再回来）：页头标题与右侧三件、三只维度胶囊都可点，大数字与已看的位置空着，副行只剩「待删篮 N 张 · 去确认」（待删篮为空则副行整行空）；页头下面是失败说明与「打开系统设置」。看完把权限改回来。

**覆盖说明**：夹具测试只验展示口径、登记值、目录与源码落位；页头观感、`Menu` 浅／深色表现、`ScrollView` 里玻璃圆钮取样、四态版式均属夹具驱动、真机未覆盖。S1-1（加载中）副行未被任何测试或本报告单独覆盖（一闪而过，由测试 A 与 H100 第 4 条间接覆盖）。

## 十五、docs 提交与最终核验

- docs 提交只含 `Reports/IC-192/self-check.md` 与 `Reports/IC-192/change-list.md`（惯例 44：合并与合并后 `main` 运行之后追加，纯 `Reports/**` 提交不触发 CI，预期行为）。
- docs 提交前已对本报告与 `change-list.md` 出现的全部 40 位 SHA 跑 `git cat-file -e <sha>^{<类型>}`，结果见 `change-list.md` 末节「核验结果」；docs 提交之后补跑 `check_ic192.py <docs 提交> docs`，结果在回传的回报里给出（docs 提交自身的 SHA 不写进报告）。

## 十六、发现但未处理的问题（按纪律只报告不修）

1. 卡面 A 节说新页头文件「407 行」，实际拷入文件 410 行（复核第一轮处置 F1／W1 之后的最终版；blob 与清单相等，无影响，仅文档计数过时）。
2. **已知遗留**（卡面已登记）：`S1ChromeBarModel.badgeText` 与 `S1NotificationBadgeStyle.chromeRing` 只剩测试读者，见第十三节。
3. 产品里 `S1StateElement`／`S1StateLayout` 本来就零读者、只有 `IC128D` 在用（调研 `RESEARCH-S1R-3b-header-facts.md` 第二节已记）；本卡未动，仍待后续退役卡。
4. `rangeReader` 形参按卡面保留（首读、切维度、重试都用），不是遗留。
5. 本机 `core.autocrlf` 为 `true`；拷入文件 `git hash-object`（经清洗过滤）与清单逐一相等，未出现行尾转换问题。
6. 页头的纵向叠放（`ZStack(alignment: .topLeading)` 三段上距 14／108／134，大数字区自然高约 84）是复核按字号推的（③），Dynamic Type 不影响（全部 `.system(size:)` 固定字号），需 H100 第 1 条真机核对；这不是执行端发现的缺陷，仅转述。
7. 分支推送、合并均一次成功，未遇分类器拦截；`git push origin main` 第一次的 `schannel` 握手失败是网络瞬断，同一命令重试成功，不是权限拒绝。
