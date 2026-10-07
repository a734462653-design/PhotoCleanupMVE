# IC-186 自验报告

## 一、结论（先行）

- **三个子项全部按卡面原文完成，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-186-range-volume-interface`：A `e18ba07e69f1f9b110e242ca7f7eb8783d7f84e8` → B `46d9f35a6e8201ee4c9629321c94c8f3fde12434` → C `d2f21e5249646cee7d5d31114740effd076b7436`。
- 分支 CI **#376**（run `37608559375`）一次绿：**948 项 0 失败**（945 + 3），真实退出码 0，`OS:26.2, name:iPhone 16`；三条新断言全部 passed，G1026 点名的 IC153／IC155／IC166／IC175／IC183 五个测试类全部 passed。合并后 `main` 运行 **#377**（run `37610138648`）一次绿：**948 项 0 失败**。CI 预算 3 次只用 2 次（分支一次、合并后 `main` 一次）。
- 合并提交 `aaeecc31192122fcd58cb7bfc45e96d3d140577b`（双亲 `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`／`d2f21e5249646cee7d5d31114740effd076b7436`，树 `205a5e8b91ab94befca20cadbcec72b5a6be255a` 与 C 提交树相同）。分支推送、合并、推 `main` 都一次通过，**没有被分类器拦**。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面十一处锚（A1～A4、B1～B3、C1～C4）替换时各恰 1 处；两个被改文件基线 blob 与卡面相等；两个拷入文件 `git hash-object` 与卡面值相等；`sim_ic186.py`（只对基线跑）`FAILURES 0`；`check_ic186.py` 在 A／B／C 三个 tip 上 5／5、6／6、7／7 全 PASS、FAIL 0、退出码 0。**没有与卡面矛盾之处，没有停下问任何问题。**
- 零行为改动面：新读口在产品里没有调用者（卡边界），不进协议、不进桩、不进 App、不碰状态机与视图；既有测试一字未动。体积的界面呈现与接线归 V1 视图卡。
- **一件执行端过失要如实说（第十八节第 1 条）**：做摘取实测时第一次 `git clone --local` 失败（跨盘硬链接 `Improper link`），其后几行没有 `cd` 保护的命令在**原仓**里执行了，建出了三个本地分支 `pickA`／`pickAB`／`pickABC`（都指向基线 `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`、无提交、无文件改动、未推送）。我随即切回功能分支；删除它们的 `git branch -d` 被权限层拒绝，所以三个分支仍留在本地原仓，需要有权限的人执行 `git branch -d pickA pickAB pickABC`。对合并结果与远端没有任何影响。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡：`<top>/Tasks/IC-20261007-186-range-volume-interface.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-186.md`；调研 `Tasks/RESEARCH-S1R-1-volume-facts.md`（全文）；复核 `Tasks/REVIEW-IC-186-findings.md` 第三节（第一轮处置）与第四节（第二轮处置）。以卡为准。
- 基线：`main` = `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`。开工四步：`git status --porcelain` 空（零输出）；`git merge-base --is-ancestor 04b8d47dd85c3dca81f601437bc39ad24c3c2462 main` 退出码 0；`git ls-remote origin refs/heads/main` = `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`（与本地一致）；两个被改文件 blob 与卡面表相等；先 `git switch -c feature/ic-186-range-volume-interface` 再改文件（切分支后 `git ls-remote origin refs/heads/feature/ic-186-range-volume-interface` 无输出，远端无同名分支）。

| 路径 | 卡面 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVE/Services/S0LibraryScanService.swift` | `e40100309d9703f709527b001a690daaa4f564db` | 相等 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `3c2f0d5d8f30a8682bbdda3acd818ddd4bc04ccb` | 相等 |

- 范围边界：只做卡「本卡边界」三项。数据源协议 `Features/S0/S0CleanupDataProviding.swift`、桩 `Services/S0CleanupDataStub.swift`、App 入口、`Core/S1StateMachine.swift`、任何视图文件、目录 `Localizable.xcstrings`（blob `911848e37193b1491b60274549db5ec1c0425a33` 在基线与 C 相同）、`Scripts/`、`.github/`、任何既有测试文件、SPEC 与 Decision_log 均未触碰。
- 改法实施方式：执行端脚本（`scratchpad/ic186-exec/pbx_edit.py`、`svc_edit.py`）把卡面「把／改为」块内嵌，写盘前对每处断言「把」块在当时文本恰 1 处（pbx 另断言 4 个新 id 在原文里出现 0 次），数不对即退出码 2 且不写盘；全部通过才写。两个新文件用 `cp` 从 `Tasks/decision-tools/ic186/` 逐字节拷入。

## 三、提交列表

| 子项 | 提交 | 树 | 可摘性 |
|---|---|---|---|
| A Core 体积口径 | `e18ba07e69f1f9b110e242ca7f7eb8783d7f84e8` | `929e775cbf9db0343a000997f17424f95ff920d7` | 单独可摘（实测见第十二节） |
| B 扫描服务读口 | `46d9f35a6e8201ee4c9629321c94c8f3fde12434` | `0f6e25687f415342ab051f00fb69f36e368f9075` | 依赖 A，只能 A→B 连续（实测见第十二节） |
| C 新测试 + pbx 测试登记 | `d2f21e5249646cee7d5d31114740effd076b7436` | `205a5e8b91ab94befca20cadbcec72b5a6be255a` | 依赖 A、B |
| 合并 | `aaeecc31192122fcd58cb7bfc45e96d3d140577b` | `205a5e8b91ab94befca20cadbcec72b5a6be255a` | 双亲 `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`／`d2f21e5249646cee7d5d31114740effd076b7436`；首行 `merge(IC-186): 范围体积接口——扫描服务体积表与 Core 体积口径（不做界面）` |

`git diff --name-only f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6..<tip>`：A 2 路径、B 累计 3 路径、C 累计 4 路径（卡面白名单合计 4），C 实测恰为 `PhotoCleanupMVE.xcodeproj/project.pbxproj`、`PhotoCleanupMVE/Core/S1RangeVolumes.swift`、`PhotoCleanupMVE/Services/S0LibraryScanService.swift`、`PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift`。

## 四、CI

| 项 | 分支运行 #376 | 合并后 `main` 运行 #377 |
|---|---|---|
| run id | `37608559375`（attempt 1） | `37610138648`（attempt 1） |
| 被测提交 | `d2f21e5249646cee7d5d31114740effd076b7436` | `aaeecc31192122fcd58cb7bfc45e96d3d140577b` |
| 结论 | completed／success，作业（job `112749941210`）十二步全部 success | completed／success，作业（job `112755145856`）十二步全部 success |
| XCTest | 唯一 Test Case 行 948 条：948 passed／0 failed；`Executed 948 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC186RangeVolumeInterfaceTests` 3／3 | 同左：唯一 Test Case 行 948 条 948 passed／0 failed；`Executed 948 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC186RangeVolumeInterfaceTests` 3／3 |
| 执行摘要 notice | `Executed 948 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 948 tests / 0 failures` | 同左（与 xcodebuild 小计、唯一 Test Case 行集合三者一致，**无计数虚增**） |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（同左） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左（同一 id、`OS:26.2, name:iPhone 16`） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1977380，SHA-256 `441413bd1a3fc63410f8be7626460c25f13856e2c1958b3ec20f3c2aec4054d9` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1977380，SHA-256 `4b64fc9bcc4e48be9dae8deff63db9814540dd559a08e903cf981276c82ca9dd` |
| 分段耗时 notice | `模拟器启动 68 s；xcodebuild test 456 s；总 526 s` | `模拟器启动 104 s；xcodebuild test 588 s；总 694 s` |
| artifact | `PhotoCleanupMVE-unsigned-d2f21e524964`（id 11477491132，1977550 字节，有效期至 2027-01-05T10:36:49Z） | `PhotoCleanupMVE-unsigned-aaeecc311921`（id 11477698207，1977550 字节，有效期至 2027-01-05T10:51:20Z） |

数据来源：`actions/runs/<id>`、`actions/runs/<id>/jobs`、`check-runs/<job id>/annotations`、`actions/runs/<id>/artifacts`，以及整包日志 zip 中「9_运行 XCTest.txt」单文件（按唯一 Test Case 行计数；`Executed 948 tests` 与 `** TEST SUCCEEDED **` 取自该文件）。

项数对账：基线 945（IC-185 合并后 #375 的 xcodebuild 真值）+ 3（C 新增）= **948**，与 #376／#377 唯一 Test Case 行数、`Executed 948 tests` 行、执行摘要 notice 三者一致。本机锚定 `^\s*func\s+test`：基线 945、C 提交后 948。

`testIC063`（陷阱 26）：#376／#377 日志 `building pipeline` 均 0 行，`IC063_WARMUP_GATE_END` 各 1 行，`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 均 passed（6.286 s／6.336 s）；未触发复跑。两份日志各有 2 行含 `Invalidating`，但都不带 `building pipeline`，不影响判读。

## 五、本地门禁（三个提交各一份，真实退出码；提交前在暂存后的工作树上跑）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A `e18ba07` | 0（「结构自验通过」；needle 变体审计扫 62 个测试文件） | 0（残留 0，目录 key 与产品源码引用一致） | 0 |
| B `46d9f35` | 0（62 个测试文件） | 0 | 0 |
| C `d2f21e5` | 0（63 个测试文件，含新测试） | 0 | 0 |

## 六、子项 B「改后」计数实测表（卡面值 / 实测值；口径 = 与测试 `strippedSource` 同的剔注释与字面量内容，脚本 `scratchpad/ic186-exec/count_B.py` 读工作树文件，调用 `Tasks/decision-tools/strip.py`）

| needle | 卡面 | 实测 | 基线 |
|---|---|---|---|
| `func assetByteCountTable() -> S1AssetByteCountTable? {` | 1 | 1 | 0 |
| `guard outcome == .completed else {` | 1 | 1 | 0 |
| `memoizedByteCountTable` | 3 | 3 | 0 |
| `for identifier in libraryIdentifiers {` | 1 | 1 | 0 |
| `withLocalIdentifiers` | 0 | 0 | 0 |
| `fetchAssets(withLocalIdentifiers` | 0 | 0 | 0 |
| `PHAsset.fetchAssets(with: nil)` | 1 | 1 | 1 |
| `attributedCategory(` | 1 | 1 | 1 |
| `hits.contains(` | 0 | 0 | 0 |
| `withCheckedContinuation` | 1 | 1 | 1 |
| `withTaskCancellationHandler` | 1 | 1 | 1 |
| `extractFeaturePrint` | 4 | 4 | 4 |
| `func cachedAsset(for identifier: String) -> PHAsset?` | 1（既有钉子） | 1 | 1 |
| `func similarDiagnosticsReport() -> String` | 1 | 1 | 1 |
| `isNetworkAccessAllowed = true` | 0（IC153 断言 12） | 0 | 0 |
| `value(forKey:` | 0（IC153 断言 12） | 0 | 0 |
| 原文 `同一个归属判定` | 1 | 1 | 1 |
| 原文 `import Vision` | 0 | 0 | 0 |
| 原文 `"fileSize"` | 0（IC153 断言 12） | 0 | 0 |
| 文件净增行数 | 34 | 34 | — |

子项 C 落位断言（`count_C.py`，对工作树逐条）：服务四条新计数与三条既有钉子同上；协议文件、桩、App 剔注释后 `assetByteCountTable` 与 `S1AssetByteCountTable` 各 0（6 条全 0）；Core 新文件原文 `import ` 1、`import Foundation` 1，剔注释后 `Photos`／`PHAsset`／`S0`／`L10n.`／`@MainActor` 各 0，三个声明行各 1；全部与卡面相符，`FAILS 0`。

## 七、`check_ic186.py` 输出（`IC_REPO=<仓库> python -B check_ic186.py <tip> <段>`）

| 段 | tip | 输出 | 退出码 |
|---|---|---|---|
| A | `e18ba07e69f1f9b110e242ca7f7eb8783d7f84e8` | `PASS blob …/project.pbxproj`、`PASS blob …/Core/S1RangeVolumes.swift`、`PASS changed paths == whitelist (2)`、`PASS base is ancestor`、`PASS catalog blob unchanged`；`SUMMARY 5 pass / 5` | 0 |
| B | `46d9f35a6e8201ee4c9629321c94c8f3fde12434` | 另加 `PASS blob …/Services/S0LibraryScanService.swift`，`changed paths == whitelist (3)`；`SUMMARY 6 pass / 6` | 0 |
| C | `d2f21e5249646cee7d5d31114740effd076b7436` | 另加 `PASS blob …/PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift`，`changed paths == whitelist (4)`；`SUMMARY 7 pass / 7` | 0 |

三段都没有 FAIL 行。`sim_ic186.py f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`（只对基线跑，不加 `IC186_GATES`／`IC186_CLONE`）：103 条 `ok`、`FAILURES 0 []`，退出码 0（含：十一处锚各恰 1、八行 pbx 锚、两个新文件 LF 无 BOM、XCTest 本机锚定 945 → 948、`service line count +34`、扫描器两向检查、四个全产品递归扫描退役名 0）。`docs` 段在 docs 提交落到 `main` 之后另跑，结果在回报里（报告提交本身不能引用自己）。

## 八、拷入文件（`git hash-object`，卡面值 / 实测值）

| 仓库路径 | 卡面 blob | 实测（拷入后） | C 提交树里 |
|---|---|---|---|
| `PhotoCleanupMVE/Core/S1RangeVolumes.swift` | `095b98017d0f8f9ef6706dbad6d86ba5c4d300ce` | `095b98017d0f8f9ef6706dbad6d86ba5c4d300ce` | 相等 |
| `PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift` | `890044fee1e17d865f694a11ab065bde0219053e` | `890044fee1e17d865f694a11ab065bde0219053e` | 相等 |

两个文件 LF、无 BOM（`grep -c $'\r'` 均 0）。改动文件改后 blob：`PhotoCleanupMVE/Services/S0LibraryScanService.swift` `61675e9ed551fbf7713ba0ffa7f1200b607ba2f0`、`PhotoCleanupMVE.xcodeproj/project.pbxproj` `6f4bc1cb79af06526219a4b32e9a00056a4b1f28`（均与 `check_ic186.py` 对「基线 + 卡面改法」推出的 blob 相等）。

## 九、闸门 G1025～G1029

| 闸门 | 判据 | 结果 |
|---|---|---|
| G1025（行为与落位） | `check_ic186.py` 在 A／B／C 三个 tip 上全 PASS（blob = 基线 + 卡面改法、改动路径 = 白名单、目录 blob 不变） | 通过：5／5、6／6、7／7（第七节） |
| G1026（新断言） | 三条 `testIC186*` passed；IC153／IC155／IC166／IC175／IC183 全部 passed | 通过：#376 与 #377 里三条新测试 passed；IC153ScanServiceTests 13／13、IC155CategoryDataAndCoverTests 8／8、IC166RestCategoryTests 6／6、IC175SimilarRecognizerTests 8／8、IC183RetireRenderChainTests 3／3 全 passed（含五个被服务文件钉住的函数：`testIC153C_ProductionSourceFetchOptionsExcludeHiddenAndDeleted`、`testIC155B_ProtocolGainsOneRequirementAndKeepsHookLine`、`testIC166B_SourceDiscipline`、`testIC175F_SourceDisciplineAndWiring`、`testIC183D_StaleCommentsRewritten`） |
| G1027（规模不回退） | 无性能断言；报告只记 `testIC186B` 用例耗时，不作判据 | `testIC186B_ServiceTableFollowsScanOutcome`：#376 **0.051 s**、#377 **0.048 s** |
| G1028（合并前置） | G1025～G1027 + CI 绿 + 三十一条被保护分支 tip 未变 + 撞号扫描 + 工作树净 + `main` 未被他人推进 | 全部满足后才合并：#376 绿（第四节全部项）；31／31 保护分支 tip 与远端头相符（推送分支后、合并前各查一次，第十节）；撞号扫描通过（第十一节）；`git status --porcelain` 空；合并前 `git ls-remote origin refs/heads/main` 仍 `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6` |
| G1029（合并后） | `main` 运行绿，报告记 artifact 名称／id／有效期 | 通过：#377 绿；`PhotoCleanupMVE-unsigned-aaeecc311921`，id 11477698207，有效期至 2027-01-05T10:51:20Z |

## 十、被保护分支（31 条）

卡面 G1028 列名的三十一条：`Reports/IC-184/self-check.md` 第十节的 28 条短 SHA（`probe/ic-067-screenshot-subtype` `9db02b9` … `feature/ic-182-tutorial-round-two` `1dbf013`）+ `feature/ic-183-retire-render-chain` `fe96fce8bab6cbcba821262b680c70c37336ddbe` + `feature/ic-184-retire-caliber-enums` `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` + `feature/ic-185-nav-maintenance` `7872de5b90922c986fa9b7f9d2a6c3dd11580959`。用脚本 `scratchpad/ic186-exec/protected.py` 对 `git ls-remote origin` 逐条比对前缀：**推送分支后 31／31、合并前 31／31、合并并推 `main`、#377 完成之后 31／31 与远端头相符**（远端 ref 共 106 行 = IC-185 报告的 105 行 + 本分支一行）。三条冻结分支与各条探针分支均在这三十一条之内、未触碰。

## 十一、pbxproj 撞号扫描与四个新 id

- 登记前重扫（脚本 `pbx_scan.py`，对基线 pbxproj 与 A、C 提交后各扫一次）：基线 fileRef 族（`1…`）最大 `100000000000000000000086`、buildFile 族（`2…`）最大 `200000000000000000000083`，与卡面一致；`100000000000000000000087`／`200000000000000000000084`／`100000000000000000000088`／`200000000000000000000085` 登记前出现 0 次。
- 登记后（C 提交）：定义行 290 条、无重复定义；`100000000000000000000087` 3 处（fileRef 定义 + 组 children + buildFile 的 fileRef 引用）、`200000000000000000000084` 2 处（buildFile 定义 + 源码阶段）、`100000000000000000000088` 3 处、`200000000000000000000085` 2 处，与卡面一致；八行照卡面原文（制表符与既有行相同，`git diff` 逐行核对，仅 8 行新增、无删除）。组与阶段归属核对：A3 落在 Core 组、A4 落在应用源码阶段，C3 落在测试组（`300000000000000000000009`）、C4 落在测试源码阶段（`400000000000000000000004`）。

## 十二、摘取关系实测（本机克隆 `scratchpad/ic186-exec/clone`，`git clone --no-hardlinks` 原仓，自基线 `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6` 起，未推送）

| 摘取 | 命令 | 退出码 | 结果树 | 对照 |
|---|---|---|---|---|
| A 单独 | `git cherry-pick -x e18ba07e69f1f9b110e242ca7f7eb8783d7f84e8` | 0 | `929e775cbf9db0343a000997f17424f95ff920d7` | 与 A 提交树相同；`diff --name-only` 恰 2 路径 |
| A→B 连续 | `git cherry-pick -x e18ba07e69f1f9b110e242ca7f7eb8783d7f84e8`，再 `git cherry-pick -x 46d9f35a6e8201ee4c9629321c94c8f3fde12434` | 0／0 | `0f6e25687f415342ab051f00fb69f36e368f9075` | 与 B 提交树相同；恰 3 路径 |
| A→B→C 连续 | `git cherry-pick -x` 三个提交一条命令 | 0 | `205a5e8b91ab94befca20cadbcec72b5a6be255a` | 与 C 提交树相同 |

B 单独未测（卡「摘取关系」：B 用到 A 的类型，不能单独摘；可摘单元只有 A、A→B、全部）。克隆里摘取产生的新提交 SHA 与原提交不同，不作为本报告的引用对象。

## 十三、三条新断言与函数名（#376／#377 均 passed）

| 断言 | 函数 | 钉住的内容 | #376／#377 用时 |
|---|---|---|---|
| 1 纯口径 | `testIC186A_TableArithmetic` | 总占用 1000；范围体积 375／0／空范围 0／有一张不在表里为 nil；年 = 各月之并时年体积 = 各月之和；占比 125→13、375→38、333→33、0→0、1000→100、1500→100（钳）、-5→0（钳）、空表 0 | 0.001 s／0.001 s |
| 2 服务读口 | `testIC186B_ServiceTableFollowsScanOutcome` | 夹具源：未推进时回报扫描中、无表；一遍完成后表 = `p1` 3 MB、`p2`（待删篮）2 MB、`p3`（未解析）0、`v1` 120 MB，总占用 125 MB 且 = 快照 `libraryTotalByteCount + pendingDeletionByteCount`；修订号未变再读同一张表；第二遍删 `p3`、加 `n1` 并卡住取字节——回到扫描中、无表；放行后新表含 `n1`、不含 `p3`，总占用 130 MB；授权不可读 `.failed(.authorization)`、无表 | 0.051 s／0.048 s |
| 3 源码落位 | `testIC186C_SourceDiscipline` | 服务四条新计数 + 三条既有钉子；协议、桩、App 剔注释后 `assetByteCountTable`／`S1AssetByteCountTable` 各 0；Core 新文件原文 `import ` 1、`import Foundation` 1，剔注释 `Photos`／`PHAsset`／`S0`／`L10n.`／`@MainActor` 各 0，三个声明行各 1 | 0.021 s／0.011 s |

三条用例都是夹具驱动（夹具源不是 PhotoKit），不涉及真机行为。

## 十四、卡面事实判断

- 卡面事实基础（服务既有钉子、pbx 最大号、扫描器规则、百分比取整口径）在基线上全部与实测相符；本卡没有与卡面或调研矛盾的实测，所以没有「假设被推翻」项。
- 卡裁定 二「`LIB` + 待删篮字节 = 总占用」在 CI 上由 `testIC186B` 的对账断言实证（①夹具驱动，模拟器）：#376／#377 passed。

## 十五、规格欠账（三条，本卡不改任何规格；归下一次 S1 规格修订，照卡原文记）

1. SPEC-S1 v12 `:261` `占比(r)` 只写「格式与卡片叠同一」，未写取整——本卡取卡片叠同一取整（四舍五入、远离零），见卡裁定 三。
2. `:259`／`:307` 只把「扫描未完成或失败」定为「未知」——本卡另把「范围里有资产不在表里」（扫描完成之后才新增的照片、S1 读取与扫描枚举之间的时间差）也判为该范围「未知」，不给已知部分之和，见卡裁定 二（决策会话推论，可并入 S1 v12 未定项 30）。
3. `:260` 写 `总占用` = 全部年范围 `体积(y)` 之和——本卡取表内之和（`U` = 扫描服务的库内全部资产），两者只在 S1 读取与扫描枚举之间有新增或删除时不等（③，真机待 V1 卡）。

## 十六、人工判定项

**无**（卡「人工判定项」：只有数据接口、产品里暂无调用者，界面上没有可见变化）。装包取合并后 `main` 产物 `PhotoCleanupMVE-unsigned-aaeecc311921`（#377，id 11477698207）即可。

## 十七、占位值登记

本卡无出厂值变更，不动 `S2CalibrationConfiguration`，`schemaVersion` 仍 7；目录 `Localizable.xcstrings` 一字未动（281 条）。

## 十八、发现但未处理（按纪律只报告不修）

1. **执行端过失：原仓里留下三个本地分支（本卡范围外的副作用，需要人工清理）。** 摘取实测第一次 `git clone --local` 到 scratchpad 失败（`fatal: failed to create link … Improper link`，原仓在 D: 盘、scratchpad 在 C: 盘，硬链接不可用），随后同一条命令里的 `cd` 失败，而紧跟着的几行 `git checkout -q -b pickA|pickAB|pickABC f5500406…` 没有 `cd … || exit` 保护，于是在**原仓**里执行了；其后的 `git cherry-pick` 因变量为空以 usage 退出（退出码 129），没有产生任何提交。后果：本地原仓多了三个分支 `pickA`／`pickAB`／`pickABC`，都指向基线 `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6`，工作树无改动、未推送。我发现后立刻 `git switch` 回功能分支，再试 `git branch -d pickA pickAB pickABC` 被权限层拒绝（删分支在 deny 名单内），我没有换写法绕过。三个分支不影响任何提交、合并与远端；清理命令：`git branch -d pickA pickAB pickABC`。随后改用 `git clone --no-hardlinks` 并在每个命令前 `cd … || exit` 加路径断言，摘取实测全部在克隆里完成（第十二节）。
2. **记忆化命中侧没有行为断言（卡裁定 四、复核 W6，如实记）**：`S1AssetByteCountTable` 是值类型，命中与重算无法从外部区分，所以 `testIC186B` 只钉了失效侧行为（第二遍之后读到新表）与「修订号未变再读得到相等的表」，命中分支本身只由 `testIC186C` 的源码计数（`memoizedByteCountTable` 3）钉存在。
3. **读口在产品里暂无调用者（设计如此，卡边界）**：`assetByteCountTable()` 与 `S1AssetByteCountTable` 在 `main` 上只被新测试引用；V1 视图卡接线时要同时改 `testIC186C` 里「协议、桩、App 里都没有 `assetByteCountTable`」那一条期望（卡裁定 一已写明）。
4. **（卡「范围外」已记，执行端不处理）** 未解析重试阶段每次通知后读表都在锁内重建、任一遍发现新增或改动即整页 GB 一起回「统计中」、某张卡体积为 nil 而页头大数字有值时的显示——归 V1 视图卡输入。
5. 本卡未触碰 `Scripts/summarize-xctest-log.sh`（第 217 条第四节的截断行多计问题）：#376／#377 日志里没有被截断的 Test Case 行，执行摘要 notice 与 xcodebuild 小计、唯一 Test Case 行集合一致，计数无虚增。
6. 执行过程记录：Bash 工具每次调用 cwd 都会复位到工作目录，后台轮询脚本与 `ghq.sh` 用全路径调用后一次通过；不涉及仓库。

## 十九、40 位 SHA 核验（`git cat-file -e`）

（下表由 docs 提交前的核验脚本生成并回填；对 `self-check.md` 与 `change-list.md` 两份报告里出现的全部 40 位十六进制串逐个跑 `git cat-file -t <sha>` 取类型、再跑 `git cat-file -e <sha>^{<类型>}`，本机原仓。IPA SHA-256（64 位）、pbx id（24 位）与本报告所在 docs 提交自身不是核验对象。）

| SHA | 类型 | `cat-file -e` 退出码 |
|---|---|---|
| `04b8d47dd85c3dca81f601437bc39ad24c3c2462` | commit | 0 |
| `095b98017d0f8f9ef6706dbad6d86ba5c4d300ce` | blob | 0 |
| `0f6e25687f415342ab051f00fb69f36e368f9075` | tree | 0 |
| `205a5e8b91ab94befca20cadbcec72b5a6be255a` | tree | 0 |
| `3c2f0d5d8f30a8682bbdda3acd818ddd4bc04ccb` | blob | 0 |
| `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | commit | 0 |
| `46d9f35a6e8201ee4c9629321c94c8f3fde12434` | commit | 0 |
| `61675e9ed551fbf7713ba0ffa7f1200b607ba2f0` | blob | 0 |
| `6f4bc1cb79af06526219a4b32e9a00056a4b1f28` | blob | 0 |
| `7872de5b90922c986fa9b7f9d2a6c3dd11580959` | commit | 0 |
| `890044fee1e17d865f694a11ab065bde0219053e` | blob | 0 |
| `911848e37193b1491b60274549db5ec1c0425a33` | blob | 0 |
| `929e775cbf9db0343a000997f17424f95ff920d7` | tree | 0 |
| `aaeecc31192122fcd58cb7bfc45e96d3d140577b` | commit | 0 |
| `d2f21e5249646cee7d5d31114740effd076b7436` | commit | 0 |
| `e18ba07e69f1f9b110e242ca7f7eb8783d7f84e8` | commit | 0 |
| `e40100309d9703f709527b001a690daaa4f564db` | blob | 0 |
| `f5500406bc6ebd02bbbd0b1846a93faa2cce7cc6` | commit | 0 |
| `fe96fce8bab6cbcba821262b680c70c37336ddbe` | commit | 0 |

共 19 个 40 位 SHA，全部存在（失败 0）。
