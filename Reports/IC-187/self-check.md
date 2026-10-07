# IC-187 自验报告

## 一、结论（先行）

- **四个子项全部按卡面原文完成，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-187-seen-archive`：A `504d98dd97231d5c20f434ecfc3dd1f72330349f` → B `80174cbc727fd133a5b53fed043ae26c3ba3e167` → C `dfd88950d65b22f0523878ed933ebaff450cee12` → D `a94ab09ebc1e17667397b9c53db148cd2c6e4761`。
- 分支 CI **#378**（run `37619158468`）一次绿：**952 项 0 失败**（948 + 4），真实退出码 0，`OS:26.2, name:iPhone 16`；四条 `testIC187*` 全部 passed，G1031 点名的 IC140／IC141／IC146／IC151／IC152／IC157／IC168／IC170／IC179／IC182／IC185 十一个测试类与 `FullFlowRoutingTests`、`S1SessionPersistenceTests` 全部 passed，`testIC048_006S5ExitEndsSessionAndRebuildsS1Session` passed（G1032）。合并后 `main` 运行 **#379**（run `37621228674`）一次绿：**952 项 0 失败**。CI 预算 3 次只用 2 次（分支一次、合并后 `main` 一次）。
- 合并提交 `e4bf9f89d1a71ae99bc4ddb8c6b5e8105548ff56`（双亲 `f25af4fb386485fe562e1650c7d4a386d3a4b40f`／`a94ab09ebc1e17667397b9c53db148cd2c6e4761`，树 `f04c27fa69042e39dcebb5c892a6b361196c388d` 与 D 提交树相同）。分支推送、合并、推 `main` 都一次通过，**没有被分类器拦**。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面二十二处锚（A1～A7、B1～B6、C1～C5、D1～D4）替换时各恰 1 处；五个被改文件基线 blob 与卡面相等；两个拷入文件 `git hash-object` 与卡面值相等；`sim_ic187.py`（只对基线跑，不加 `IC187_GATES`／`IC187_CLONE`）`FAILURES 0`；`check_ic187.py` 在 A／B／C／D 四个 tip 上 6／6、8／8、9／9、10／10 全 PASS、FAIL 0、退出码 0。**没有与卡面矛盾之处，没有停下问任何问题。**
- 零行为改动面：看过档在产品里只被 S2 状态机的回报闭包与协调器写入、读取，没有任何派生量读它（已看进度、进入位置仍读 `K`、返回契约字段一字未动）；`Core/S1StateMachine.swift`、`Core/SessionStore.swift`、App 入口、`S2NativePhotoPager.swift`、目录、既有测试文件一字未动。界面无可见变化。
- 本卡没有执行端过失（对照上一张卡 IC-186 的克隆事故：本次克隆一次成功、所有摘取命令都带 `git -C <克隆>`，原仓没有新建任何摘取分支，第十二节）。原仓里仍有上一张卡遗留的三个本地分支 `pickA`／`pickAB`／`pickABC`，未动。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡：`<top>/Tasks/IC-20261007-187-seen-archive.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-187.md`；调研 `Tasks/RESEARCH-S1R-2-seen-facts.md`（全文）；拆卡计划 `Tasks/PLAN-S1R-cards-20261007.md`（②a 一行）；复核 `Tasks/REVIEW-IC-187-findings.md` 第三节（第一轮处置）与第四节（第二轮处置）。以卡为准。
- 基线：`main` = `f25af4fb386485fe562e1650c7d4a386d3a4b40f`。开工四步：`git status --porcelain` 空（零输出）；`git merge-base --is-ancestor aaeecc31192122fcd58cb7bfc45e96d3d140577b main` 退出码 0；`git ls-remote origin refs/heads/main` = `f25af4fb386485fe562e1650c7d4a386d3a4b40f`（与本地一致）；五个被改文件 blob 与卡面表相等；先 `git checkout -b feature/ic-187-seen-archive` 再改文件。

| 路径 | 卡面 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | `0d8371c60f90c5334b3c50215042ea8e296fbcd9` | 相等 |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | `548a4c8d6be8e83724a40effb6421c8b968cfdc4` | 相等 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | `ea216665a203b60b2900d4bc4cc21ab44386e38b` | 相等 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `6baae5aa127873f7aa4077ad2b7af5a6ee022780` | 相等 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `6f4bc1cb79af06526219a4b32e9a00056a4b1f28` | 相等 |

- 范围边界：只做卡「本卡边界」四项。`Core/S1StateMachine.swift`、`Core/SessionStore.swift`、`S1View.swift` 与任何 S1／S0 视图、App 入口、`S2NativePhotoPager.swift`、目录 `Localizable.xcstrings`（blob `911848e37193b1491b60274549db5ec1c0425a33` 在基线与 D 相同）、`Scripts/`、`.github/`、任何既有测试文件、SPEC 与 Decision_log 均未触碰。
- 改法实施方式：执行端脚本 `scratchpad/ic187-exec/apply_card.py` 直接解析卡 markdown 里每个子项的「把／改为」两个 ```text 块，写盘前对每处断言「把」块在当时文本恰 1 处（数不对即退出码 1、本子项一处都不写）；全部通过才写。两个新文件用 `cp` 从 `Tasks/decision-tools/ic187/` 逐字节拷入（hash 见第八节）。各子项锚命中数：A 七处各 1（A1～A7）、B 六处各 1（B1～B6）、C 五处各 1（C1～C5）、D 四处各 1（D1～D4），合计 22 处各恰 1。

## 三、提交列表

| 子项 | 提交 | 树 | 可摘性 |
|---|---|---|---|
| A 看过档 + 持久层 | `504d98dd97231d5c20f434ecfc3dd1f72330349f` | `3373962341afc7579425e05f4f7d31f80dcdb3b0` | 单独可摘（实测见第十二节） |
| B S2 记「看过」 | `80174cbc727fd133a5b53fed043ae26c3ba3e167` | `f6a47aa381ae26248661bbb088d76c78149fa8fd` | 单独可摘（实测见第十二节） |
| C 协调器 | `dfd88950d65b22f0523878ed933ebaff450cee12` | `29562fbadc8dfb8781dd6f921545e0a7ecd22e9a` | 依赖 A、B，只能 A→B→C 连续（实测见第十二节） |
| D 新测试 + pbx 测试登记 | `a94ab09ebc1e17667397b9c53db148cd2c6e4761` | `f04c27fa69042e39dcebb5c892a6b361196c388d` | 依赖 A、B、C |
| 合并 | `e4bf9f89d1a71ae99bc4ddb8c6b5e8105548ff56` | `f04c27fa69042e39dcebb5c892a6b361196c388d` | 双亲 `f25af4fb386485fe562e1650c7d4a386d3a4b40f`／`a94ab09ebc1e17667397b9c53db148cd2c6e4761`；首行 `merge(IC-187): 看过档与「看过」记录——S2 只记停稳成为当前的那一张（不改派生量与界面）` |

`git diff --name-only f25af4fb386485fe562e1650c7d4a386d3a4b40f..<tip>`：A 3 路径、B 累计 5、C 累计 6、D 累计 7（卡面白名单合计 7），D 实测恰为 `PhotoCleanupMVE.xcodeproj/project.pbxproj`、`PhotoCleanupMVE/App/CleanupCoordinator.swift`、`PhotoCleanupMVE/Core/S1SeenArchive.swift`、`PhotoCleanupMVE/Core/S2StateMachine.swift`、`PhotoCleanupMVE/Core/SessionPersistence.swift`、`PhotoCleanupMVE/Features/S2/S2View.swift`、`PhotoCleanupMVETests/IC187SeenArchiveTests.swift`（`git diff --shortstat`：7 files changed, 582 insertions(+), 1 deletion(-)；那一处删除是 B2 给既有 `recentAlbumDidChange` 形参行补逗号）。

## 四、CI

| 项 | 分支运行 #378 | 合并后 `main` 运行 #379 |
|---|---|---|
| run id | `37619158468`（attempt 1，push 事件，创建 2026-10-07T12:10:45Z） | `37621228674`（attempt 1，push 事件，创建 2026-10-07T12:28:24Z） |
| 被测提交 | `a94ab09ebc1e17667397b9c53db148cd2c6e4761` | `e4bf9f89d1a71ae99bc4ddb8c6b5e8105548ff56` |
| 结论 | completed／success，作业（job `112784759906`）十二步全部 success | completed／success，作业（job `112791716575`）十二步全部 success |
| XCTest | 「运行 XCTest」步骤日志里唯一 Test Case 行 952 条：952 passed／0 failed；`Executed 952 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`（1 行，无 `** TEST FAILED **`） | 同左：唯一 Test Case 行 952 条 952 passed／0 failed；`Executed 952 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **` |
| 执行摘要 notice | `Executed 952 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 952 tests / 0 failures` | 同左（与 xcodebuild 小计、唯一 Test Case 行集合三者一致，**无计数虚增**） |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（同左） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左（同一 id、`OS:26.2, name:iPhone 16`） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1985139，SHA-256 `ddd2f2f72e3fb57af623f46f236d0c9600cee4f47a0bcde401fb01934b5a8ed6` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1985139，SHA-256 `bba46ac65bb54f6472fddd5821e99c157a280e6234db1567fd3fb051b0241306` |
| 分段耗时 notice 原文 | `模拟器启动 101 s；xcodebuild test 516 s；总 618 s` | `模拟器启动 91 s；xcodebuild test 432 s；总 524 s` |
| artifact | `PhotoCleanupMVE-unsigned-a94ab09ebc1e`（id 11482356430，1985309 字节，有效期至 2027-01-05T12:10:45Z） | `PhotoCleanupMVE-unsigned-e4bf9f89d1a7`（id 11482169334，1985309 字节，有效期至 2027-01-05T12:28:24Z） |

数据来源：`actions/runs/<id>`、`actions/runs/<id>/attempts/1/jobs`、`check-runs/<job id>/annotations`（job id 取自该 run 自己的 jobs 现取）、`actions/runs/<id>/artifacts`，以及整包日志 zip（`runs/<id>/logs`，Python `zipfile` 读，`testzip()` 通过）中「9_运行 XCTest.txt」单文件（按唯一 Test Case 行计数；`Executed 952 tests` 与 `** TEST SUCCEEDED **` 取自该文件；整包 zip 根目录的作业日志与逐步日志重复，计数只用单步文件）。

项数对账：基线 948（IC-186 合并后 #377 的 xcodebuild 真值）+ 4（D 新增）= **952**，与 #378／#379 唯一 Test Case 行数、`Executed 952 tests` 行、执行摘要 notice 三者一致。本机锚定 `^\s*func\s+test`（全测试目录）：基线 948、D 提交后 952，delta 4，新增四个函数名即第十三节所列。

`testIC063`（陷阱 26）：#378／#379 日志 `building pipeline` 均 0 行，`IC063_WARMUP_GATE_END` 各 1 行，`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 均 passed（6.854 s／6.213 s）；未触发复跑。两份日志各有 2 行含 `Invalidating`，但都不带 `building pipeline`，不影响判读。编译错误行（含 `.swift` 与 ` error: `）两份日志均 0。

## 五、本地门禁（四个提交各一份，真实退出码；提交前在暂存后的工作树上跑）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A `504d98d` | 0（「结构自验通过」；needle 变体审计扫 63 个测试源文件） | 0（残留 0，目录 key 与产品源码引用一致） | 0 |
| B `80174cb` | 0（63 个测试源文件） | 0 | 0 |
| C `dfd8895` | 0（63 个测试源文件） | 0 | 0 |
| D `a94ab09` | 0（64 个测试源文件，含新测试） | 0 | 0 |

## 六、子项 B、C「改后」计数实测表（卡面值 / 实测值；口径 = 与测试 `strippedSource` 同的剔注释与字面量内容，原文行标「原文」；脚本 `scratchpad/ic187-exec/counts.py` 读工作树文件、调用 `Tasks/decision-tools/strip.py` 只读；在 B 提交前与 C 提交前各跑一次，B 段 27 条、C 段 49 条，全部 OK、`FAILS 0`）

### 子项 B（`S2StateMachine.swift`、`S2View.swift`）

| needle | 卡面 | 实测 | 基线 |
|---|---|---|---|
| `private(set) var visitSeenAssetIDs: Set<String> = []` | 1 | 1 | 0 |
| `private let seenAssetDidSettle: (String) -> Void` | 1 | 1 | 0 |
| `seenAssetDidSettle: @escaping (String) -> Void = { _ in }` | 1 | 1 | 0 |
| `visitSeenAssetIDs = [entry.currentAssetID]` | 1 | 1 | 0 |
| `func notePagingSettled() {` | 1 | 1 | 0 |
| `private func markCurrentSeen() {` | 1 | 1 | 0 |
| `markCurrentSeen()`（定义 + `switchPhoto`／`endBottomStripDrag`／`notePagingSettled` 各 1） | 4 | 4 | 0 |
| `guard bottomStripState == .idle else {` | 1 | 1 | 0 |
| `seenAssetDidSettle(assetID)` | 1 | 1 | 0 |
| `handleNativePageChange` 函数体里 `markCurrentSeen()` | 0 | 0 | 0 |
| `handleSwipeUp` 函数体里 `markCurrentSeen()` | 0 | 0 | 0 |
| `holdsPageAfterNextMark`（IC182） | 3（既有） | 3 | 3 |
| `handleSwipeUp` 切片 `switchPhoto(by: 1)` 1／`resetZoomAfterPhotoChange()` 0（IC182） | 1／0（既有） | 1／0 | 1／0 |
| `func reportNativeViewport(`（IC152） | 1（既有） | 1 | 1 |
| `? handleSwipeDown()`（IC146） | 1（既有） | 1 | 1 |
| `S2StateMachine.swift` 净增行数 | 30 | 30 | — |
| `S2View.swift` `machine.notePagingSettled()` | 1 | 1 | 0 |
| `S2View.swift` `onPagingSettled: {` 闭包内含 `machine.notePagingSettled()` | 1 | 1 | — |
| 原文 `onPagingSettled:`（IC140 D） | 1（既有） | 1 | 1 |
| 原文 `livePlayback.`（IC140 D） | 6（既有） | 6 | 6 |
| 原文 `livePlayback.pagingSettled()`／`videoPlayback.pagingSettled()`（IC140 D／IC141 D） | 各 1（既有） | 各 1 | 各 1 |
| `S2View.swift` 净增行数 | 2 | 2 | — |

### 子项 C（`CleanupCoordinator.swift`）

| needle | 卡面 | 实测 | 基线 |
|---|---|---|---|
| `func currentSeenArchive() -> S1SeenArchive {` | 1 | 1 | 0 |
| `private func flushSeenArchive() {` | 1 | 1 | 0 |
| `flushSeenArchive()`（定义 + `defer` + 转入非活跃） | 3 | 3 | 0 |
| `persistence.saveS1SeenArchive(` | 1 | 1 | 0 |
| `persistence.loadS1SeenArchive()` | 1 | 1 | 0 |
| `seenAssetDidSettle: { [weak self] assetID in` | 1 | 1 | 0 |
| `recordSeenAssets(` | 4 | 4 | 0 |
| `recordS2Leave(` | 2 | 2 | 0 |
| `finishSession()` 函数体里 `Seen` | 0 | 0 | 0 |
| IC168：`sampleS2Exit(` 3／`s2ExitGuardFailure(` 3／`recordS2ExitDiagnostics(` 7／`cancelS2Handoff(virtualRangeID:` 1／原文 `return "` 0 | 不变 | 3／3／7／1／0 | 同 |
| IC170：`completeRangeRead(` 1／`currentReadRequest` 1／`photoLibrary.s1RangeRead(` 2／`publishS1FeedbackEvent(.submissionUnavailable)` 4／`func enterConfirmationFromS0() -> Bool` 1 | 不变 | 1／1／2／4／1 | 同 |
| IC185：`S0Tab` | 0（不变） | 0 | 0 |
| 文件净增行数 | 57 | 57 | — |

### 子项 A／D 的落位计数（卡面 D 第 1 条 4 点所钉，对 A 提交树实测）

`SessionPersistence.swift`：原文 `"s1-seen.json"` 1、`func saveS1SeenArchive(` 1、`func loadS1SeenArchive()` 1、`clearS1SeenArchive` 0、净增 23 行（复核员口径，卡面没写）；`S1SeenArchive.swift`：原文 `import ` 1、`import Foundation` 1，剔注释 `Photos`／`PHAsset`／`L10n.`／`@MainActor`／`S0` 各 0、`static let currentSchemaVersion = 1` 1。13 条全部与卡面相符。

## 七、`check_ic187.py` 输出（`python -B check_ic187.py <tip> <段>`，仓库取脚本默认路径；有 FAIL 退出码 1）

| 段 | tip | 输出 | 退出码 |
|---|---|---|---|
| A | `504d98dd97231d5c20f434ecfc3dd1f72330349f` | `PASS blob …/project.pbxproj`、`PASS blob …/Core/S1SeenArchive.swift`、`PASS blob …/Core/SessionPersistence.swift`、`PASS changed paths == whitelist (3)`、`PASS base is ancestor`、`PASS catalog blob unchanged`；`SUMMARY 6 pass / 6` | 0 |
| B | `80174cbc727fd133a5b53fed043ae26c3ba3e167` | 另加 `PASS blob …/Core/S2StateMachine.swift`、`PASS blob …/Features/S2/S2View.swift`，`changed paths == whitelist (5)`；`SUMMARY 8 pass / 8` | 0 |
| C | `dfd88950d65b22f0523878ed933ebaff450cee12` | 另加 `PASS blob …/App/CleanupCoordinator.swift`，`changed paths == whitelist (6)`；`SUMMARY 9 pass / 9` | 0 |
| D | `a94ab09ebc1e17667397b9c53db148cd2c6e4761` | 另加 `PASS blob …/PhotoCleanupMVETests/IC187SeenArchiveTests.swift`，`changed paths == whitelist (7)`；`SUMMARY 10 pass / 10` | 0 |

四段都没有 FAIL 行。`sim_ic187.py`（只对基线跑，不加 `IC187_GATES`／`IC187_CLONE`）：127 条 `ok`、`FAILURES 0 []`，退出码 0（含：二十二处锚各恰 1（输出 `anchors OK`）、八行 pbx 锚、两个新文件 LF 无 BOM、扫描器两向检查、全产品递归扫描退役名 0、XCTest 本机锚定 948 → 952、四个新函数名、新测试无 `Test Case` 字样、行数差 +23／+30／+2／+57）。该脚本会确定性重写 `decision-tools/sim187/`（提示词允许的唯一例外），跑完 `decision-tools/` 里无 `__pycache__`（全部 Python 用 `python -B`）。`docs` 段在 docs 提交落到 `main` 之后另跑，结果在回报里（报告提交本身不能引用自己）。

## 八、拷入文件（`git hash-object`，卡面值 / 实测值）

| 仓库路径 | 卡面 blob | 实测（拷入后） | D 提交树里 |
|---|---|---|---|
| `PhotoCleanupMVE/Core/S1SeenArchive.swift` | `4573c8d697e3fe63f8166f9ac7e96ad0aaa88065` | `4573c8d697e3fe63f8166f9ac7e96ad0aaa88065` | 相等 |
| `PhotoCleanupMVETests/IC187SeenArchiveTests.swift` | `4cbb36576c2e4568fac6e3757a3bed4a52768c3f` | `4cbb36576c2e4568fac6e3757a3bed4a52768c3f` | 相等 |

两个文件 LF、无 BOM。改动文件改后 blob（均与 `check_ic187.py` 对「基线 + 卡面改法」推出的 blob 相等）：`PhotoCleanupMVE/Core/SessionPersistence.swift` `9464a81223faef9c1eea31cd7d2b4a73544d6ad5`（A）、`PhotoCleanupMVE/Core/S2StateMachine.swift` `2ecdc5c8e8e0110f3d8afbd5a8fe17d73274656e`（B）、`PhotoCleanupMVE/Features/S2/S2View.swift` `39acc0052234d23b811bf2c332bafe6a0b688fc1`（B）、`PhotoCleanupMVE/App/CleanupCoordinator.swift` `47894556c4495a03b2b3364e7f67cf0527dcd116`（C）、`PhotoCleanupMVE.xcodeproj/project.pbxproj` `7218820250b155fb1b782b6f82187b1f607cbfc7`（A 后）／`c92d2568cb2be3cf4203e3a4f73f88f0335c2d69`（D 后）。

## 九、闸门 G1030～G1034

| 闸门 | 判据 | 结果 |
|---|---|---|
| G1030（行为与落位） | `check_ic187.py` 在 A／B／C／D 四个 tip 上全 PASS | 通过：6／6、8／8、9／9、10／10（第七节） |
| G1031（新断言） | 四条 `testIC187*` passed；IC140／IC141／IC146／IC151／IC152／IC157／IC168／IC170／IC179／IC182／IC185 与 `FullFlowRoutingTests`、`S1SessionPersistenceTests` 全部 passed | 通过：#378 与 #379 里四条新测试 passed（第十三节）；IC140LivePhotoPlaybackTests 18／18、IC141VideoPlaybackTests 16／16、IC146ChromeRoundTwoTests 19／19、IC151AmbientFixedColorTests 7／7、IC152DiagnosticPathTests 6／6、IC157LongPressIntoS2Tests 8／8、IC168FallbackDiagnosticsTests 6／6、IC170S1FirstReadTests 6／6、IC179InlineHintsTests 9／9、IC182TutorialRoundTwoTests 5／5、IC185NavigationMaintenanceTests 5／5、FullFlowRoutingTests 6／6、S1SessionPersistenceTests 6／6 全 passed（两次运行相同，0 失败） |
| G1032（不回退） | `FullFlowRoutingTests.testIC048_006S5ExitEndsSessionAndRebuildsS1Session` passed | 通过：#378 **0.019 s**、#379 **0.032 s**（S5 离开照旧清会话档；本卡的 `finishSession()` 一字未动、函数体里 `Seen` 0 处） |
| G1033（合并前置） | G1030～G1032 + CI 绿 + 三十二条被保护分支 tip 未变 + pbxproj 撞号扫描 + 工作树净 + `main` 未被他人推进 | 全部满足后才合并：#378 绿（第四节全部项）；32／32 保护分支 tip 与远端头相符（推送分支后、合并前各查一次，第十节）；撞号扫描通过（第十一节）；`git status --porcelain` 空；合并前 `git ls-remote origin refs/heads/main` 仍 `f25af4fb386485fe562e1650c7d4a386d3a4b40f` |
| G1034（合并后） | `main` 运行绿，报告记 artifact 名称／id／有效期 | 通过：#379 绿；`PhotoCleanupMVE-unsigned-e4bf9f89d1a7`，id 11482169334，有效期至 2027-01-05T12:28:24Z |

## 十、被保护分支（32 条）

卡面 G1033 列名的三十二条：`Reports/IC-186/self-check.md` 第十节列名的三十一条——`Reports/IC-184/self-check.md` 第十节的 28 条短 SHA（`probe/ic-067-screenshot-subtype` `9db02b9` … `feature/ic-182-tutorial-round-two` `1dbf013`）+ `feature/ic-183-retire-render-chain` `fe96fce8bab6cbcba821262b680c70c37336ddbe` + `feature/ic-184-retire-caliber-enums` `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` + `feature/ic-185-nav-maintenance` `7872de5b90922c986fa9b7f9d2a6c3dd11580959`——再加 `feature/ic-186-range-volume-interface` `d2f21e5249646cee7d5d31114740effd076b7436`。用脚本 `scratchpad/ic187-exec/protected.py` 对 `git ls-remote --heads origin` 逐条比对前缀（28 条短 SHA）与全 SHA（4 条）：**开工前 32／32、推送分支后 32／32、合并前 32／32、合并并推 `main` 之后 32／32、#379 完成之后 32／32 与远端头相符**（远端 heads 共 106 行 = 开工前 105 行 + 本分支一行）。三条冻结分支与各条探针分支均在这三十二条之内、未触碰。

**排除项（按任务指令）**：原仓本地分支 `pickA`／`pickAB`／`pickABC` 是上一张卡（IC-186）遗留，不在这三十二条之内、也不在远端；本卡没有动它们，开工前与收工后本地 `refs/heads` 的差别只有本卡新建的 `feature/ic-187-seen-archive` 一条（`branches_before.txt`／`branches_now.txt` 对比）。

## 十一、pbxproj 撞号扫描与四个新 id

- 登记前重扫（脚本 `scratchpad/ic187-exec/pbx_scan.py`，对基线 pbxproj 与 D 提交各扫一次）：基线定义行 290 条、无重复；fileRef 族（`1…`）最大 `100000000000000000000088`、buildFile 族（`2…`）最大 `200000000000000000000085`，与卡面一致；`100000000000000000000089`／`200000000000000000000086`／`10000000000000000000008A`／`200000000000000000000087` 登记前出现 0 次。
- 登记后（D 提交）：定义行 294 条、无重复定义；`100000000000000000000089` 3 处（fileRef 定义 + 组 children + buildFile 的 fileRef 引用）、`200000000000000000000086` 2 处（buildFile 定义 + 源码阶段）、`10000000000000000000008A` 3 处、`200000000000000000000087` 2 处，与卡面一致；八行照卡面原文（制表符与既有行相同，`git diff` 逐行核对，仅 8 行新增、无删除）。组与阶段归属：A4～A7 落在 PBXBuildFile／PBXFileReference／Core 组 children／应用源码阶段，D1～D4 落在 PBXBuildFile／PBXFileReference／测试组 children／测试源码阶段（锚行分别是 `SessionPersistence.swift` 与 `IC186RangeVolumeInterfaceTests.swift` 之后，二者互不相邻）。

| 文件 | fileRef | buildFile | 所在组 |
|---|---|---|---|
| `S1SeenArchive.swift` | `100000000000000000000089` | `200000000000000000000086` | Core |
| `IC187SeenArchiveTests.swift` | `10000000000000000000008A` | `200000000000000000000087` | 测试组 |

## 十二、摘取关系实测（本机克隆 `scratchpad/ic187-exec/clone`，`git clone --no-hardlinks` 原仓一次成功，所有命令带 `git -C <克隆路径>`，自基线 `f25af4fb386485fe562e1650c7d4a386d3a4b40f` 起，未推送；脚本 `pick2.sh`，每次先 `checkout -q -b <名> <基线>`）

| 摘取 | 命令 | 退出码 | 结果树 | 对照 |
|---|---|---|---|---|
| A 单独 | `git cherry-pick -x 504d98dd97231d5c20f434ecfc3dd1f72330349f` | 0 | `3373962341afc7579425e05f4f7d31f80dcdb3b0` | 与 A 提交树相同；`diff --name-only` 恰 3 路径 |
| B 单独 | `git cherry-pick -x 80174cbc727fd133a5b53fed043ae26c3ba3e167` | 0 | （树只存在于克隆里，不是原仓对象，不作核验对象） | 恰 2 路径（`S2StateMachine.swift`、`S2View.swift`）；两个文件 blob 与 B 提交相同（`2ecdc5c8e8e0110f3d8afbd5a8fe17d73274656e`／`39acc0052234d23b811bf2c332bafe6a0b688fc1`） |
| A→B 连续 | `git cherry-pick -x` 两个提交一条命令 | 0 | `f6a47aa381ae26248661bbb088d76c78149fa8fd` | 与 B 提交树相同；恰 5 路径 |
| A→B→C 连续 | `git cherry-pick -x` 三个提交一条命令 | 0 | `29562fbadc8dfb8781dd6f921545e0a7ecd22e9a` | 与 C 提交树相同；恰 6 路径 |
| A→B→C→D 全部 | `git cherry-pick -x` 四个提交一条命令 | 0 | `f04c27fa69042e39dcebb5c892a6b361196c388d` | 与 D 提交树相同；恰 7 路径 |

每次摘取后克隆工作树净（`dirty_files=0`）。C 单独摘取未测（卡「摘取关系」：C 用到 A 的类型与持久层方法、B 的形参与集合，只能在 A、B 之后；文本上能摘不等于能编译）。克隆里摘取产生的新提交 SHA 与原提交不同，不作为本报告的引用对象。原仓在克隆测试前后无新增分支、工作树净（第十节末）。

## 十三、四条新断言与函数名（#378／#379 均 passed；用例耗时取「运行 XCTest」步骤日志）

| 断言 | 函数 | 钉住的内容（卡「子项 D」） | #378／#379 用时 |
|---|---|---|---|
| 1 档往返与坏档 | `testIC187A_ArchiveRoundTripAndCorruption` | 隔离目录：无档 nil；保存后读回逐位相等（含小数秒时刻）；清会话档两步不碰看过档；不可解析、版本 2、标识重复三种坏档都读成 nil；同形合法档读得回 | 0.009 s／0.010 s |
| 2 S2 只记停稳的 | `testIC187B_S2RecordsOnlySettledPhotos` | 协调器 + 隔离目录 + 六张月范围：进入时第一张 `a1` 即看过；上滑后自动进入的 `a2` 看过；横栏拖经 `a3` 停在 `a4`——拖动中集合不变、结束记 `a4`；`handleNativePageChange(to: 4)` 不记、`notePagingSettled()` 记 `a5`、再停一次不变；实时并入协调器、离开前未写盘、离开时刻为空 | 0.005 s／0.006 s |
| 3 协调器离开时刻与写盘 | `testIC187C_CoordinatorRecordsLeaveTimesAndPersists` | 第一次进入看 `a1`／`a5` 后返回：写盘、离开时刻夹在前后之间、迁移标记 false；第二次交回会话不符的载荷：写回失败、`a3` 照样写盘、离开时刻不变；第三次看 `a6` 后转入非活跃：写盘；虚拟范围 `cat:video` 记看过与离开时刻；换一个协调器读回同一份档 | 0.012 s／0.019 s |
| 4 源码落位 | `testIC187D_SourceWiring` | 子项 B、C 新增符号的计数与切片，另复核三条相邻既有钉子（`handleSwipeUp` 切片 `switchPhoto(by: 1)` 1、停稳闭包里 `livePlayback.pagingSettled()`／`videoPlayback.pagingSettled()` 各 1）；持久层原文 `"s1-seen.json"` 1、两个方法声明各 1、`clearS1SeenArchive` 0；新文件 `import ` 1、剔注释 `Photos`／`PHAsset`／`L10n.`／`@MainActor`／`S0` 0、`static let currentSchemaVersion = 1` 1 | 0.075 s／0.066 s |

测试 A 的三条手拼 JSON 已由决策会话在第一轮复核后改成 `archiveJSON(schemaVersion:seenAssetIDs:)` 工具函数（卡第三节处置 W3），本次编译与类型检查一次通过（两次 CI 均无编译错误行）。三条用例中 B、C 是夹具驱动（翻页停稳由测试直接调 `notePagingSettled()`，真机由分页器经视图转来），真机行为本卡不下结论（见第十六节）。

## 十四、卡面事实判断

- 卡「事实基础」表（`installS1Session` 每次新造状态机、会话档读写加锁与测试隔离口、`currentIndex` 四个写入点、实时同步先例、`applyS2ExitPayload` 成败分支、既有钉子对读、扫描器、pbxproj 最大号）在基线上全部与实测相符：五个被改文件 blob 相等、22 处锚各恰 1、全部计数对读与卡面逐条相等（第六节）。本卡没有与卡面或调研矛盾的实测，所以没有「假设被推翻」项。
- 卡裁定 一～六在 CI 上的实证（①夹具驱动，模拟器）：裁定 一（看过档与会话档分开、不随 S5 清）由 `testIC187A`（清会话档两步不碰看过档）与 `testIC048_006S5ExitEndsSessionAndRebuildsS1Session` 在 #378／#379 passed 实证；裁定 二（汇集口与四个入口）、裁定 三（实时并入、离开与转入非活跃时合并写盘）、裁定 四（`t_离开` 写回成功才记、虚拟范围同记、校验失败不记）由 `testIC187B`／`testIC187C` passed 实证；裁定 五（迁移标记本卡恒 false、只随档往返）由 `testIC187C` 的「迁移标记 false」与 `testIC187A` 往返实证；裁定 六（不改派生量）由既有测试全部 passed 与零改动文件清单实证。

## 十五、规格欠账（三条，本卡不改任何规格；归下一次 S1／S2 修订，照卡原文记）

1. SPEC-S1 v12 `:253` 迁移的触发写作「`看过档` 尚不存在时」——本卡先建档、②b 才迁移，所以改用档内标记 `hasMigratedLegacyProgress`（本卡恒 false）判「尚未迁移」，行为等价（卡裁定 五）。
2. 规格「不处于翻页过渡中时的 `c`」——上滑后自动进下一张与 Nx 贴边翻页在 `switchPhoto` 当即记看过，不等过渡动画走完（卡裁定 二，③ 近似；真机观感随 ②b／③ 的人工判定看）。
3. 规格第七节第 2 部分「S2 迁出时返回契约再交一次本次看过集合」——返回契约字段归 ②d，本卡由协调器在写回成功时直接从 S2 状态机取本次看过集合作最后一次同步（`recordSeenAssets(s2Machine?.visitSeenAssetIDs ?? [])`，行为等价）。

## 十六、人工判定项

**无**（卡「人工判定项」：本卡界面上没有任何可见变化；「看过」在真机上的手感——翻页停稳、横栏拖完、上滑后自动进下一张是否都算——随 ②b 的已看进度与 ③ 的 V1 卡面一起判）。H 装包取最新即可；合并后 `main` 产物 `PhotoCleanupMVE-unsigned-e4bf9f89d1a7`（#379，id 11482169334）即可。

## 十七、占位值登记

本卡无出厂值变更，不动 `S2CalibrationConfiguration`，`schemaVersion` 仍 7；目录 `Localizable.xcstrings` 一字未动（blob `911848e37193b1491b60274549db5ec1c0425a33`，基线与 D 相同，仍 281 条）。无新增登记制常量；新增产品字符串字面量只有 `"s1-seen.json"`（ASCII、不在 `return`／视图调用里，扫描器残留 0）。

## 十八、发现但未处理（按纪律只报告不修）

1. **每记一张就整份 `Set` 写时复制一次、写盘是主线程整份排序编码（卡裁定 三、复核 W8 已记，规格未定项 29）**：`recordSeenAssets`／`recordS2Leave` 里 `var archive = currentSeenArchive(); … seenArchiveCache = archive`，`flushSeenArchive` 里 `seenArchiveCache != writtenSeenArchive` 是 O(n) 的集合相等，`saveS1SeenArchive` 每次整份 `sorted()` + `JSONEncoder` + 原子写。6k 张量级无感，十万张量级由 ②b 起在真机上看；本卡只做上述合并写盘，不另做优化（复核员建议 ②b 起原地 `formUnion`、写盘量大时挪出主线程）。
2. **测试宿主默认目录（复核已记，本卡不处理）**：用默认 `SessionPersistence()` 的协调器测试（`CleanupCoordinator()` 无形参或默认 `persistence:`）在 `leaveS2`／转入非活跃时会把 `s1-seen.json` 写进模拟器宿主真实 Application Support；新测试 B／C 都用隔离目录，而其他测试没有读看过档的断言——同进程先后跑互不影响，#378／#379 两次 952／0 与之相符。
3. **`navigateToNextAsset`（标定面板专用）不接看过汇集口**——卡「范围外」已写明，不处理。
4. **`endBottomStripDrag` 在无任何滑动时也会记当前张**：`beginBottomStripDrag` 置 `.dragging` 后立刻 `endBottomStripDrag`，当前张本就是已停稳的那一张（进入时第一张已在集合里），`insert(...).inserted` 为 false 不回调，不是缺陷；记在这里只为下一张卡的人知道汇集口对重复调用幂等。
5. 原仓里上一张卡遗留的三个本地分支 `pickA`／`pickAB`／`pickABC` 仍在（待 Lynn 清，`git branch -d pickA pickAB pickABC`；删分支在权限层 deny 名单内，本卡不试），已从被保护分支核对中排除。
6. 本卡未触碰 `Scripts/summarize-xctest-log.sh`（第 217 条第四节的截断行多计问题）：#378／#379 日志里执行摘要 notice 的 952 与同条 xcodebuild 小计、唯一 Test Case 行集合一致，计数无虚增。
7. 执行过程记录：Bash 工具每次调用 cwd 都会复位到工作目录，脚本与路径一律用绝对路径；`sim_ic187.py` 按提示词只对基线跑一次，会确定性重写 `decision-tools/sim187/`（唯一例外），`decision-tools/` 里没有留 `__pycache__`；不涉及仓库。

## 十九、40 位 SHA 核验（`git cat-file -e`）

（下表由 docs 提交前的核验脚本生成并回填：对 `self-check.md` 与 `change-list.md` 两份报告里出现的全部 40 位十六进制串逐个跑 `git cat-file -t <sha>` 取类型、再跑 `git cat-file -e <sha>^{<类型>}`，本机原仓。IPA SHA-256（64 位）、pbx id（24 位）与本报告所在 docs 提交自身不是核验对象。）

| SHA | 类型 | `cat-file -e` 退出码 |
|---|---|---|
| `0d8371c60f90c5334b3c50215042ea8e296fbcd9` | blob | 0 |
| `29562fbadc8dfb8781dd6f921545e0a7ecd22e9a` | tree | 0 |
| `2ecdc5c8e8e0110f3d8afbd5a8fe17d73274656e` | blob | 0 |
| `3373962341afc7579425e05f4f7d31f80dcdb3b0` | tree | 0 |
| `39acc0052234d23b811bf2c332bafe6a0b688fc1` | blob | 0 |
| `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | commit | 0 |
| `4573c8d697e3fe63f8166f9ac7e96ad0aaa88065` | blob | 0 |
| `47894556c4495a03b2b3364e7f67cf0527dcd116` | blob | 0 |
| `4cbb36576c2e4568fac6e3757a3bed4a52768c3f` | blob | 0 |
| `504d98dd97231d5c20f434ecfc3dd1f72330349f` | commit | 0 |
| `548a4c8d6be8e83724a40effb6421c8b968cfdc4` | blob | 0 |
| `6baae5aa127873f7aa4077ad2b7af5a6ee022780` | blob | 0 |
| `6f4bc1cb79af06526219a4b32e9a00056a4b1f28` | blob | 0 |
| `7218820250b155fb1b782b6f82187b1f607cbfc7` | blob | 0 |
| `7872de5b90922c986fa9b7f9d2a6c3dd11580959` | commit | 0 |
| `80174cbc727fd133a5b53fed043ae26c3ba3e167` | commit | 0 |
| `911848e37193b1491b60274549db5ec1c0425a33` | blob | 0 |
| `9464a81223faef9c1eea31cd7d2b4a73544d6ad5` | blob | 0 |
| `a94ab09ebc1e17667397b9c53db148cd2c6e4761` | commit | 0 |
| `aaeecc31192122fcd58cb7bfc45e96d3d140577b` | commit | 0 |
| `c92d2568cb2be3cf4203e3a4f73f88f0335c2d69` | blob | 0 |
| `d2f21e5249646cee7d5d31114740effd076b7436` | commit | 0 |
| `dfd88950d65b22f0523878ed933ebaff450cee12` | commit | 0 |
| `e4bf9f89d1a71ae99bc4ddb8c6b5e8105548ff56` | commit | 0 |
| `ea216665a203b60b2900d4bc4cc21ab44386e38b` | blob | 0 |
| `f04c27fa69042e39dcebb5c892a6b361196c388d` | tree | 0 |
| `f25af4fb386485fe562e1650c7d4a386d3a4b40f` | commit | 0 |
| `f6a47aa381ae26248661bbb088d76c78149fa8fd` | tree | 0 |
| `fe96fce8bab6cbcba821262b680c70c37336ddbe` | commit | 0 |

共 29 个 40 位 SHA，退出码非 0 的 0 个。
