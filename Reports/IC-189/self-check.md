# IC-189 自验报告

## 一、结论（先行）

- **三个子项全部按卡面原文完成，G1040～G1044 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-189-new-count`：A `552ae54cdb203056ab8ed55f0fa4be4798f7ee54` → B `7ade7c1187d3545ded33000c42e41c9d5eebd639` → C `e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a`。
- 分支 CI **#382**（run `37884495677`）一次绿：**963 项 0 失败**（958 + 5），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`；五条 `testIC189*` 全部 passed，G1041 点名的十三个测试类全部 passed，G1042 两条 passed。
- 合并提交 `3bf92f22822ccc4850a996ae5a87bbb639c24d38`（双亲 `17d1798a6d69d8608a3db0e10de7f8aba7c009f7`／`e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a`，树 `f1f3b19966e141d994ae016238edb5ebcfb6ba87` 与 C 提交的树相同）。合并后 `main` CI **#383**（run `37885424916`）一次绿：963 项 0 失败，同样 `** TEST SUCCEEDED **`、`OS:26.2, name:iPhone 16`。CI 预算 3 次只用 2（分支 1 + 合并后 1）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面 17 处替换（A 六处、B 七处、C 四处）的锚句在替换时各恰命中 1 次；六个被改文件基线 blob 与卡面相等；拷入文件 `git hash-object` 与卡面值相等；`sim_ic189.py` 只对基线跑过（`FAILURES 0`）；执行端另做一次独立核对：卡内全部 34 个 `text` 代码块与 `ic189_edits.py` 替换表逐块逐字相等（0 处不符）。
- 本次没有停卡项，没有执行端偏离卡面的改动，没有被分类器拦截，没有中途中断。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261008-189-new-count.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-189.md`；调研 `Tasks/RESEARCH-S1R-2c-new-count-facts.md`（全文）；拆卡计划 ②c 一行；复核 `Tasks/REVIEW-IC-189-findings.md` 第三、四节（处置节）。
- 基线 `main` = `17d1798a6d69d8608a3db0e10de7f8aba7c009f7`。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor c3ae531e685904664e64f54e1ffe895108318204 main` 退出码 0；`git ls-remote origin refs/heads/main` = `17d1798…`；六个被改文件 blob 与卡面相等（见下表）；远端与本地都没有 `feature/ic-189-new-count`；然后才 `git checkout -b feature/ic-189-new-count 17d1798…`。

| 路径 | 卡面 blob | 实测（HEAD 与工作树，`--no-filters`） |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `5c911bc5306162a64e26b1ac9df960ea90e56f97` | 相等 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `458bc570b4ce9cbe21564d3d076b8ec9637c25b0` | 相等 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `957d2b198e114f58f920211ff3371a3695696aed` | 相等 |
| `PhotoCleanupMVE/Services/PhotoLibraryService.swift` | `84c125327948948f2261b0c677eb5db6243da4a6` | 相等 |
| `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `e4d76bff90b5d3ab44b13e53d80ed482065afb07` | 相等 |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `96f157a7a6d4dbdf1ec15bea1b02f7dbf097ed77` | 相等 |

- **拷入文件 `git hash-object` 实测**（`cp` 自 `Tasks/decision-tools/ic189/` 后对仓库内文件复测；拷入前对源文件也测过，同值）：

| 仓库路径 | 卡面 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVETests/IC189NewCountTests.swift` | `14904de5f6de651e0e6a53fd73f4ed7c991ef234` | `14904de5f6de651e0e6a53fd73f4ed7c991ef234` |

- 范围边界：只做卡「本卡边界」三项。`Core/SessionStore.swift`、`Core/SessionPersistence.swift`、`Core/S1SeenArchive.swift`、`areValid`、任何视图（含 `S1View.swift` 预览的两处 `S1Range(`）、S2 全部文件、App 入口、目录 `Localizable.xcstrings`（`check_ic189.py` 逐段 PASS「catalog blob unchanged」）、`Scripts/`、`.github/`、SPEC 与 Decision_log 一字未动。
- 改法实施方式：执行端脚本 `scratchpad/ic189-exec/apply189.py`——先把卡内全部 34 个 `text` 代码块与决策会话的替换表 `Tasks/decision-tools/ic189_edits.py` 逐块逐字比对（不符即停，本次 0 处不符），再逐处断言「把」块在当时工作树文本恰命中 1 次后按字节写入（LF 保持）；新测试文件用 `cp` 拷入。任一命中数不符即 `assert` 停下（本次未触发）。每个子项提交后立即对刚提交的 tip 跑 `check_ic189.py`。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `552ae54cdb203056ab8ed55f0fa4be4798f7ee54` | `0f276ac521e9e188c2249105a80011142eb15aa8` | `S1Range` 加 `creationDatesNewestFirst: [Date]`（构造形参带默认值 `[]`）与 `newAssetCount(after:excluding:)`；照片库年、月、相册、未分类四处范围构造各加一列 `.map(\.creationDate)` |
| B | `7ade7c1187d3545ded33000c42e41c9d5eebd639` | `cb1b0981f4cfaea01e710f1bc483c4f240152cbc` | `S1RangeRow.newAssetCount`；状态机 `leaveTimeProvider`、`newAssetCount(for:)`／`newAssetBaseline(for:)`、`rangeRows` 新列；协调器 `installS1Session` 注入离开时刻；`IC184`（7 → 8）与 `IC188F`（2 → 3）各一条期望随改 |
| C | `e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a` | `f1f3b19966e141d994ae016238edb5ebcfb6ba87` | 新测试 `IC189NewCountTests.swift`（五条，逐字节拷入）+ pbx 四行 |
| 合并 | `3bf92f22822ccc4850a996ae5a87bbb639c24d38` | `f1f3b19966e141d994ae016238edb5ebcfb6ba87` | `merge(IC-189): 「新增 N 张」的数据与派生量——范围带逐张拍摄时间、按离开时刻算基线、有月的年取各月之和` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-189/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --name-only 17d1798..e4e4bae` 恰 7 路径，全在白名单内。分支推送一次成功（无分类器拦截）；推 `main` 一次成功（`17d1798..3bf92f2`）。

## 四、逐子项提交前对读（卡面「改后」段 / 工作树实测，口径同测试 `strippedSource`）

脚本：`scratchpad/ic189-exec/count189.py`（读工作树文件，用 `Tasks/decision-tools/strip.py` 的 `strip_text` 与 `scan.py` 的 `occ`，只读调用）。每个子项都是提交前跑、全部相符后才提交。

**A 子项「改后」**（卡面值 / 实测值；15 条，0 处不符）：

| 计数 | 卡面 | 实测 |
|---|---|---|
| 状态机 `let creationDatesNewestFirst: [Date]` | 1 | 1 |
| 状态机 `creationDatesNewestFirst: [Date] = []` | 1 | 1 |
| 状态机 `func newAssetCount(after baseline: Date, excluding seenAssetIDs: Set<String>) -> Int {` | 1 | 1 |
| 照片库 `creationDatesNewestFirst:` | 4 | 4 |
| 照片库 `.map(\.creationDate)`（卡面隐含）／`.map(\.identifier)`（不变） | 4／4 | 4／4 |
| 状态机 `seenAssetIDsProvider?() ?? []` | 2（仍） | 2 |
| `S1RangeRow` 切片 `let ` | 7（仍） | 7 |
| 既有钉子：`publishSnapshotIfChanged()` 6／`didSet` 4／`setMarked(` 3／`applyPendingDeletionDiff(` 3／`presentedYearRangeID` 5 | 6／4／3／3／5 | 6／4／3／3／5 |
| `makeS2Handoff(for:)` 切片内 `seenAssetIDsProvider?() ?? []` 1／`continuationsByRangeID` 0 | 1／0 | 1／0 |

**B 子项「改后」**（26 条，0 处不符；含 A 段全部仍成立项）：

| 计数 | 卡面 | 实测 |
|---|---|---|
| 状态机 `var leaveTimeProvider: ((String) -> Date?)?` | 1 | 1 |
| 状态机 `leaveTimeProvider?(` | 2 | 2 |
| 状态机 `seenAssetIDsProvider?() ?? []` | 3 | 3 |
| `makeS2Handoff(for:)` 切片内 `seenAssetIDsProvider?() ?? []` | 1 | 1 |
| 状态机 `newAssetCount: newAssetCount(for: range.id)`；`rangeRows` 切片内 `newAssetCount(for: range.id)` | 1；1 | 1；1 |
| `S1RangeRow` 切片 `let ` | 8 | 8 |
| 既有钉子：`publishSnapshotIfChanged()` 6／`didSet` 4／`setMarked(` 3／`applyPendingDeletionDiff(` 3／`presentedYearRangeID` 5 | 6／4／3／3／5 | 6／4／3／3／5 |
| 协调器 `machine.leaveTimeProvider = {` | 1 | 1 |
| 协调器 `currentSeenArchive().leaveTimeByRangeID[rangeID]` | 1 | 1 |
| 协调器 `machine.seenAssetIDsProvider = {`／`machine.legacyProgressMigration = {` | 1／1 | 1／1 |
| 协调器 `recordS2Leave(`／`flushSeenArchive()`／`photoLibrary.s1RangeRead(` | 2／4／2 | 2／4／2 |

**C 子项**：`git hash-object IC189NewCountTests.swift` = 卡面值；`func test` 5 条（`testIC189A`～`E`）；pbx `10000000000000000000008E` 出现 3 次（卡面 3：定义 + 组 children + buildFile 引用）、`20000000000000000000008B` 出现 2 次（卡面 2）；基线两个 id 出现 0 次；对象定义行 24 位 id 去重扫描 267 个、重复 0；`git diff --name-only 17d1798..C` 恰 7 路径。

## 五、`check_ic189.py` 三段 SUMMARY（提交后、进下一子项之前对刚提交的 tip 跑，退出码 0；FAIL 行：无）

| 段 | tip | SUMMARY |
|---|---|---|
| A | `552ae54cdb203056ab8ed55f0fa4be4798f7ee54` | 5 pass / 5 |
| B | `7ade7c1187d3545ded33000c42e41c9d5eebd639` | 8 pass / 8 |
| C | `e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a` | 10 pass / 10 |

每段含：逐文件 blob 全等、`changed paths == whitelist`（2／5／7 路径）、`base is ancestor`、`catalog blob unchanged`。`docs` 段在 docs 提交后补跑（docs 提交的 SHA 无法写进自己，结果在回传给决策会话的回报里给出）。

## 六、本地门禁（三个提交各跑一次，贴真实退出码）

| 提交 | `git diff --cached --check` | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` |
|---|---|---|---|
| A | 0 | 0 | 0 |
| B | 0 | 0 | 0 |
| C | 0 | 0 | 0 |

（PowerShell 工具内 `& .\Scripts\….ps1` 调用，退出码取 `$LASTEXITCODE`；selfcheck 末行「结构自验通过」，扫描器末行「用户可见硬编码残留为 0，目录 key 与产品源码引用一致」；C 提交时 selfcheck 扫描 67 个测试源文件，A、B 时 66 个。）

## 七、验收门禁逐条（G1040～G1044）

| 门禁 | 结果 |
|---|---|
| **G1040**（`check_ic189.py` A～C 三个 tip 全 PASS） | 满足，见第五节 |
| **G1041**（五条 `testIC189*` passed；十三个点名测试类全部 passed） | 满足，见第九节 |
| **G1042**（`IC188SeenSwitchTests.testIC188D_CoordinatorMigratesOnceBeforeClamp` 与 `FullFlowRoutingTests.testIC048_006S5ExitEndsSessionAndRebuildsS1Session` passed） | 满足（#382、#383 的唯一 Test Case 行均 passed） |
| **G1043**（合并前置） | 满足：G1040～G1042 + CI 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice，摘要 notice 与 xcodebuild 小计一致均为 963，无需按第 217 条第四节另核）+ 三十四条被保护分支 tip 未变（见第十一节）+ pbxproj 撞号扫描（见第十二节）+ 工作树净 + 合并前 `git ls-remote origin refs/heads/main` 仍 `17d1798…`（`main` 未被他人推进） |
| **G1044**（合并后 `main` 运行绿，报告记 artifact 名称／id／有效期） | 满足，见第八节 |

## 八、CI

| 项 | 分支 #382 | 合并后 `main` #383 |
|---|---|---|
| run id | `37884495677` | `37885424916` |
| 被测提交 | `e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a` | `3bf92f22822ccc4850a996ae5a87bbb639c24d38` |
| 结论 | success（作业 12 步全 success，第 9 步「运行 XCTest」success） | success（12 步全 success） |
| XCTest | 963 项、0 失败（唯一 Test Case 行 963 passed／0 failed；xcodebuild 小计 `Executed 963 tests, with 0 failures (0 unexpected) in 47.689 (48.780) seconds`） | 963 项、0 失败（唯一 Test Case 行 963 passed；小计 `Executed 963 tests, with 0 failures (0 unexpected) in 48.974 (51.248) seconds`） |
| 摘要 notice | `Executed 963 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 963 tests / 0 failures`（与小计一致） | 同 |
| 真实退出码 | 「运行 XCTest」步骤 success、日志 `** TEST SUCCEEDED **`（脚本 `exit "$test_status"` 原样退出 = 0） | 同 |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一 id、`OS:26.2, name:iPhone 16` |
| IPA | 文件 `PhotoCleanupMVE-unsigned.ipa`，字节数 1993773，SHA-256 `ece623d48aaff195e39f510ec913f86d487698225eeba0ab8ca73d8af6cb338a` | 字节数 1993773，SHA-256 `2e983b8ee1444bf2686af1cac3509be27817bbf4dc9e47605528488eaf9d0730`（IPA 不可复现，同树两次 SHA 不同属预期） |
| 分段耗时 notice 原文 | `模拟器启动 91 s；xcodebuild test 332 s；总 426 s` | `模拟器启动 104 s；xcodebuild test 359 s；总 464 s` |
| artifact（G1044） | `PhotoCleanupMVE-unsigned-e4e4bae06dc5`，id `11595508910`，size 1993943，有效期至 2027-01-07T04:34:13Z | **`PhotoCleanupMVE-unsigned-3bf92f22822c`，id `11596069276`，size 1993943，未过期，有效期至 2027-01-07T04:46:14Z** |

- 两次日志里各有两行 `Errors found! Invalidating cache...`（陷阱 26 的模拟器着色器缓存失效行），时间点都在 `testIC063…ExportsAllRequiredStages` 用例块**开始之前**（#382：04:41:05 对 04:41:12 开始；#383：04:53:14 对 04:53:22 开始），两份日志都没有 `building pipeline … took` 行；`testIC063` 两次均 passed（6.324 s／6.519 s），不属红因 (6)。
- 日志取得方式：`gh api repos/…/actions/runs/<id>/logs` 整包 zip，`zipfile` 读取并 `testzip` 校验，各一次成功；唯一 Test Case 行按整作业日志根文件（`0_构建、XCTest 与未签名产物.txt`）去重统计。「`** TEST FAILED **`」在整包日志里有一处命中，位于工作流脚本源码回显（`count_fixed … '** TEST FAILED **'`，陷阱 25 所述回显），不是测试输出。

## 九、五条新断言与随改的既有断言

**五条新断言**（`IC189NewCountTests`，#382／#383 的 `Test Case` 行耗时）：

| 函数 | 内容 | #382 | #383 |
|---|---|---|---|
| `testIC189A_RangeNewCountIsStrictlyLaterAndUnseen` | 严格晚于、去掉看过的；没有时间列与不等长为 0；不依赖存储顺序 | 0.001 s | 0.001 s |
| `testIC189B_BaselinePerRangeAndYearSumsMonths` | 未注入为 0；月取自己与所属年较晚者；年 = 各月之和；看过的不算；与排序无关；不存在的范围 0；没有月的范围取自己 | 0.002 s | 0.001 s |
| `testIC189C_ServiceCarriesCreationDatesInRangeOrder`（`@MainActor`） | 服务读日期与未分类两维度：时间列与资产列等长、逐张等于快照时间、非增；年范围时间总数 = 快照数 | 0.003 s | 0.003 s |
| `testIC189D_CoordinatorFeedsLeaveTimesFromSeenArchive` | 隔离持久层预存看过档，协调器进 S1、采用范围后：9 月 2、8 月 0、年 2，看过档不变 | 0.004 s | 0.003 s |
| `testIC189E_SourceWiring` | 子项 A、B「改后」的计数与切片（含既有钉子） | 0.046 s | 0.031 s |

**G1041 点名的既有测试类**（#382 唯一 Test Case 行 passed／failed；#383 同数）：`IC184RetireCaliberEnumsTests` 3／0、`IC188SeenSwitchTests` 6／0、`IC187SeenArchiveTests` 4／0、`IC178DeckListTests` 5／0、`IC157LongPressIntoS2Tests` 8／0、`IC169MarkedStateFollowsBasketTests` 6／0、`IC168FallbackDiagnosticsTests` 6／0、`IC170S1FirstReadTests` 6／0、`S1StateMachineTests` 20／0、`S1DateTreeTests` 5／0、`AlbumScopeWiringTests` 7／0、`FullFlowRoutingTests` 6／0、`IC186RangeVolumeInterfaceTests` 3／0，`IC189NewCountTests` 5／0。

**随改的既有断言**（均按卡面「改为」块，没有卡外改动）：

| 位置 | 旧 → 新 |
|---|---|
| `IC184RetireCaliberEnumsTests.swift`（`testIC184C_ExpandAPIRetiredAndVisibleOrderUnchanged`）`S1RangeRow` 切片 `let ` | 7 → 8（加注释一行） |
| `IC188SeenSwitchTests.swift`（`testIC188F_SourceWiring`）状态机 `seenAssetIDsProvider?() ?? []` | 2 → 3（加注释一行） |

**项数对账式：`958 + 5 = 963`**（sim 预演 963；#382／#383 唯一 Test Case 行 963；摘要与小计 963）。

## 十、摘取关系实测

克隆：`git clone --no-hardlinks D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE <scratchpad>/ic189-exec/clone`，克隆成功（退出码 0）后才开始；所有命令带 `git -C <克隆>` 并先核 `rev-parse --show-toplevel` 等于克隆路径；克隆里三次 `checkout -b pick_X 17d1798…`。原仓没有新建任何摘取分支（原仓分支只有 `feature/ic-189-new-count` 为本卡新建）。克隆只证文本无冲突，绿由 CI 证。

| 单元 | 命令 | 退出码 | 结果树 |
|---|---|---|---|
| A 单独 | `cherry-pick -x A` | 0 | `0f276ac521e9e188c2249105a80011142eb15aa8`（= A 提交的树） |
| A→B 连续 | `cherry-pick -x A B` | 0 | `cb1b0981f4cfaea01e710f1bc483c4f240152cbc`（= B 提交的树） |
| A→B→C 连续 | `cherry-pick -x A B C` | 0 | `f1f3b19966e141d994ae016238edb5ebcfb6ba87`（= C 提交的树 = 合并提交的树） |

## 十一、G1043 被保护分支核对

`Tasks/decision-tools/ic189_protected_branches.txt`（34 行 `分支名 SHA`、无注释行）对 `git ls-remote --heads origin`（远端共 108 个分支，含本卡分支）逐条比对：**checked 34、mismatch 0**。推送分支之后第一次核（远端 `main` = `17d1798…`、本卡分支 = `e4e4bae…`），CI 绿后合并前再核一次均 0。清单含 `feature/ic-188-seen-switch` 的 `24b3cbd0c31cd7019be7f089523091dc61a8be5c`，该 tip 未变。

## 十二、pbxproj 撞号扫描与两个新 id

- 对象定义行（含 `= {isa`）的 24 位 id 去重扫描：定义 267 个、重复 0（合并后 `main` 上复测同值）。
- 两个新 id 出现次数：`10000000000000000000008E` 3（fileRef：定义 + 组 children + buildFile 引用）、`20000000000000000000008B` 2（buildFile：定义 + 源码阶段），与基线同形；基线上两个 id 出现 0 次。
- `git diff --cached --check` 三个提交均 0。

## 十三、规格欠账（卡面四条，本卡不改任何规格）

1. 时间列缺失或与资产列不等长（手造夹具、预览）按无时间计 0——SPEC-S1 v12 没写（裁定 二）。
2. 时区或日历变化让日期范围标识变化时，旧 `t_离开` 键失配、该范围视为无基线、不显示「新增」（③ 接受）。
3. 「新增」只数拍摄时间晚于离开时刻的：导入或同步进来的旧日期照片永远不算新增——规格字面如此（`:127`），写明以免验收误判。
4. `新增` 与 `W` 一样靠回到 S1 时视图重建读到新值（IC-188 同一假设，非 `@Published`）；`rangeRows` 每行多一次 `newAssetCount(for:)`（再读一次看过集合、有基线的范围整列扫一遍），5 万张量级估计毫秒级（③），真机滚动观感随 ③ V1 视图卡看，与规格未定项 29 同源。

## 十四、人工判定项

无（本卡无界面变化：`S1RangeRow` 多一个 `newAssetCount`，卡片叠与年页不读它；「新增 N」胶囊的真机观感随 ③ V1 视图卡判）。

## 十五、docs 提交与最终核验

- docs 提交只含 `Reports/IC-189/self-check.md` 与 `Reports/IC-189/change-list.md`（惯例 44：合并与合并后 `main` 运行之后追加，纯 `Reports/**` 提交不触发 CI，预期行为）。
- docs 提交前已对本报告与 `change-list.md` 出现的全部 40 位 SHA 跑 `git cat-file -e <sha>^{<类型>}`，结果见 `change-list.md` 末节「核验结果」；docs 提交之后补跑 `check_ic189.py <docs 提交> docs`，结果在回传的回报里给出（docs 提交自身的 SHA 不写进它自己）。

## 十六、发现但未处理的问题（按纪律只报告不修）

1. `rangeRows` 每行调 `newAssetCount(for:)`，其内再读一次 `seenAssetIDsProvider`（协调器闭包每次 `currentSeenArchive()` 结构体拷贝）与 `leaveTimeProvider`（月行最多两次字典查）；有月的年再遍历各月。卡面已把这一点登记为规格欠账 (4)，本卡 CI 夹具规模下耗时看不出，十万级与真机滚动观感无实测（只记录，不改）。
2. 两次日志的 `Errors found! Invalidating cache...` 行在 `testIC063` 用例块之前出现，本卡 `testIC063` 未红（见第八节），仅记录。
3. 本机 `core.autocrlf` 为 `true`，`.gitattributes` 对 `*.swift`／`*.pbxproj` 设 `eol=lf`；工作树文件为 LF，`git hash-object --no-filters` 与卡面值逐一相等，未出现行尾转换问题。
4. 执行提示词要求 `sim_ic189.py` 只对基线跑：已照办（不带 `IC189_GATES`／`IC189_CLONE`），它按约定重写了 `Tasks/decision-tools/sim189/`；除此之外没有改动或覆盖 `decision-tools/` 与 scratchpad 里已有文件，`decision-tools/` 内无 `__pycache__`。
5. 分支推送与合并推送均一次成功，未遇分类器拦截，也未遇 `schannel` 握手失败；仅在最后核仓时有一次 `git ls-remote` 报 `schannel: failed to receive handshake`（只读查询，已重试，不影响任何结论）。
