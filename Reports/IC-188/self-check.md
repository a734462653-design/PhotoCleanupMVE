# IC-188 自验报告

## 一、结论（先行）

- **五个子项全部按卡面原文完成，G1035～G1039 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-188-seen-switch`：A `41758c8897d5f70abbb0c2405884f7d06d3da04f` → B `f1c8aeb06dba114d48176737c02c6dbc097bef51` → C `42ae1af18a44394e0c1c9eaa8c442b1c16daf935` → D `a5b49de5c36d1158734e2416dff964b0626f19e3` → E `24b3cbd0c31cd7019be7f089523091dc61a8be5c`。
- 分支 CI **#380**（run `37877855901`）一次绿：**958 项 0 失败**（952 + 6），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`；六条 `testIC188*` 全部 passed，G1036 点名的十四个测试类全部 passed，G1037 `testIC048_006S5ExitEndsSessionAndRebuildsS1Session` passed。
- 合并提交 `c3ae531e685904664e64f54e1ffe895108318204`（双亲 `0d46d371b1047919397c73cd8d06067d7dcb2b90`／`24b3cbd0c31cd7019be7f089523091dc61a8be5c`，树 `947e4b108f381495ea077d8a994efeab076a8130` 与 E 提交的树相同）。合并后 `main` CI **#381**（run `37879265210`）一次绿：958 项 0 失败，同样 `** TEST SUCCEEDED **`、`OS:26.2, name:iPhone 16`。CI 预算 3 次只用 2（分支 1 + 合并后 1）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- **执行过程中断续做说明**：执行会话在取 #380 证据之后曾因 API 连接中断（ECONNRESET）被停下，决策会话让我从中断处续做；中断前已完成的步骤（五个提交、推送、#380、合并、推 `main`、#381 绿）没有重做，续做后补取 #381 完整日志并写本报告。中断没有改变仓库状态（中断时 `main` = 远端 = `c3ae531…`、工作树净，决策会话只读核过）。
- 卡面锚句（A1～A9、A10～A13、B1～B6、C1～C6、D1～D10、E1～E4）替换时各恰命中卡面声明的次数；十二个被改文件基线 blob 与卡面相等；三个拷入文件 `git hash-object` 与卡面值相等；`sim_ic188.py` 只对基线跑过（`FAILURES 0`）。
- 本次没有停卡项，没有执行端偏离卡面的改动。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261007-188-seen-switch.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-188.md`；调研 `Tasks/RESEARCH-S1R-2b-seen-switch-facts.md`（全文）；拆卡计划 ②b 一行；复核 `Tasks/REVIEW-IC-188-findings.md` 第三、四节（处置节）。
- 基线 `main` = `0d46d371b1047919397c73cd8d06067d7dcb2b90`。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor e4bf9f89d1a71ae99bc4ddb8c6b5e8105548ff56 main` 退出码 0；`git ls-remote origin refs/heads/main` = `0d46d37…`；十二个被改文件 blob 与卡面相等（见下表）；然后才 `git checkout -b feature/ic-188-seen-switch`。

| 路径 | 卡面 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `c92d2568cb2be3cf4203e3a4f73f88f0335c2d69` | 相等 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `47894556c4495a03b2b3364e7f67cf0527dcd116` | 相等 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `3b343d30528909f5233d6a82a4974a90844d5164` | 相等 |
| `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | `a56f0972057d8c090d9e22ac8d772917c655e1b8` | 相等 |
| `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | `774f3c0cc1a3e7e00bba6cec21a277038cf2363a` | 相等 |
| `PhotoCleanupMVETests/IC131S1WriteBackToastTests.swift` | `26765ee9b48a030e530f4e57a6559329e92019ee` | 相等 |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | `4dddc8fdb3568c0235a636d8243c418160b9fb16` | 相等 |
| `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | `fdb22e65205b1c2ebb180258b883dc1542ada016` | 相等 |
| `PhotoCleanupMVETests/IC170S1FirstReadTests.swift` | `4a632c7b4ed2d5478c6af4ef40d1fd6ef28c5ded` | 相等 |
| `PhotoCleanupMVETests/IC187SeenArchiveTests.swift` | `4cbb36576c2e4568fac6e3757a3bed4a52768c3f` | 相等 |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | `b755a6bd85b3b247a69dd477bae3e6c2c4818352` | 相等 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | `e933151a14a5bd771471e21347dd504541195209` | 相等 |

- **三个拷入文件 `git hash-object` 实测**（`cp` 自 `Tasks/decision-tools/ic188/` 后再对仓库内文件复测，均等于卡面）：

| 仓库路径 | 卡面 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVETests/TestPersistenceIsolation.swift` | `64b6a04b2d9ffde79a0ce89b9bc90a629bba8af4` | `64b6a04b2d9ffde79a0ce89b9bc90a629bba8af4` |
| `PhotoCleanupMVE/Core/S1LegacyProgressMigration.swift` | `10839f915450a1798a5d03424d51c6b86c56acbf` | `10839f915450a1798a5d03424d51c6b86c56acbf` |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `96f157a7a6d4dbdf1ec15bea1b02f7dbf097ed77` | `96f157a7a6d4dbdf1ec15bea1b02f7dbf097ed77` |

- 范围边界：只做卡「本卡边界」五项。`Core/SessionStore.swift`、`Core/SessionPersistence.swift`、`Core/S1SeenArchive.swift`、S2 全部文件、任何视图、App 入口、目录 `Localizable.xcstrings`（`check_ic188.py` 逐段 PASS「catalog blob unchanged」）、`Scripts/`（含 `verify-IC-20260814-046.ps1`）、`.github/`、SPEC 与 Decision_log 一字未动。
- 改法实施方式：执行端脚本 `scratchpad/ic188-exec/apply_stage.py` 读取决策会话的替换表 `Tasks/decision-tools/ic188_edits.py`（卡由它生成），逐处断言「把」块的命中次数后写入、再把三个新文件 `copyfile` 拷入；任一命中数不符即 `exit 2` 停下（本次未触发）。每个子项提交后立即对刚提交的 tip 跑 `check_ic188.py`。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `41758c8897d5f70abbb0c2405884f7d06d3da04f` | `af3bf19251a0a0664ec3ddb8923e3074d5668467` | 新测试 helper `TestPersistenceIsolation.swift` + 七个测试文件九处构造点改传隔离持久层 + pbx 四行 |
| B | `f1c8aeb06dba114d48176737c02c6dbc097bef51` | `a471c3340493f8a1c3430110ef965ce93765ccec` | 状态机 `seenAssetIDsProvider` 与 `processedAssetIDs(for:)` 改 `W ∩ A(r)`；协调器 `installS1Session` 注入；`S1StateMachineTests` 010／011／018 |
| C | `42ae1af18a44394e0c1c9eaa8c442b1c16daf935` | `afec05aed253c9c3b92db02d7eea93a842a2596f` | `makeS2Handoff(for:)` 起点改第一张没看过的；IC157 逐字块；`testIC046_013`；IC187 测试 C 最终集合 |
| D | `a5b49de5c36d1158734e2416dff964b0626f19e3` | `5371c1586aa09dea181beb6972a19b5872f9042f` | 新文件 `S1LegacyProgressMigration.swift`；状态机迁移入口与 `adoptRanges` 钳制前调用；协调器注入与 `migrateLegacyProgressIfNeeded`；IC187 两处；pbx 四行 |
| E | `24b3cbd0c31cd7019be7f089523091dc61a8be5c` | `947e4b108f381495ea077d8a994efeab076a8130` | 新测试 `IC188SeenSwitchTests.swift`（六条）+ pbx 四行 |
| 合并 | `c3ae531e685904664e64f54e1ffe895108318204` | `947e4b108f381495ea077d8a994efeab076a8130` | `merge(IC-188): S1 改用看过集合——已看 = 看过集合 ∩ 本范围、从第一张没看过的进入、旧档进度迁移一次` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-188/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --name-only 0d46d37..24b3cbd0c31c` 恰 15 路径，全在白名单内。五个提交首行与分支推送：分支推送一次成功（无分类器拦截）。

## 四、逐子项提交前对读（卡面「改后」段 / 工作树实测，口径同测试 `strippedSource`）

脚本：`scratchpad/ic188-exec/counts.py`（读工作树文件，用 `Tasks/decision-tools/strip.py` 的 `strip_text`，只读调用）。每个子项都是提交前跑、全部相符后才提交。

**A**：`TestPersistenceIsolation.makePersistence()` 七个测试文件共 9 处（AlbumScope 1、FullFlow 1、IC131 1、IC157 1、IC168 3、IC170 1、S2ActionBar 1；卡面「9 处，IC168 文件 3、其余六文件各 1」），产品源码 0 处（卡面 0）；pbx 新增四行；`10000000000000000000008B` 出现 3 次（卡面 3）、`200000000000000000000088` 出现 2 次（卡面 2）；`git hash-object` helper = 卡面值。

**B**（卡面值 / 实测值）：

| 计数 | 卡面 | 实测 |
|---|---|---|
| 状态机 `var seenAssetIDsProvider: (() -> Set<String>)?` | 1 | 1 |
| 状态机 `seenAssetIDsProvider?() ?? []` | 1 | 1 |
| `processedAssetIDs(for:)` 切片内 `sessionStore.processedAssetIDs(` | 0 | 0 |
| 协调器 `machine.seenAssetIDsProvider = {` | 1 | 1 |
| 不变钉子：`publishSnapshotIfChanged()` 6／`didSet` 4／`setMarked(` 3／`applyPendingDeletionDiff(` 3／`presentedYearRangeID` 5／`S1RangeRow` 切片 `let ` 7 | 6／4／3／3／5／7 | 6／4／3／3／5／7 |

**C**：

| 计数 | 卡面 | 实测 |
|---|---|---|
| 状态机 `seenAssetIDsProvider?() ?? []` | 2（C 之后） | 2 |
| `makeS2Handoff(for:)` 体内 `continuationsByRangeID` | 0 | 0 |
| IC157 逐字块行数与 `makeS2Handoff(for:)` 原文（声明行到闭合花括号）逐字相等 | 36 行相等 | 36 行，相等 |
| 不变钉子（同 B） | 6／4／3／3／5／7 | 6／4／3／3／5／7 |

（脚本第一版取 IC157 数组时把 `realHandoffBodyLines[0]` 的 `[` 当成数组起点，得 38 行假不符；是我的计数脚本错，不是产品或测试问题，改为从声明行 `private static let realHandoffBodyLines` 取后得 36 行相等。）

**D 子项「改后（剔注释）」计数实测表**：

| 计数 | 卡面 | 实测 |
|---|---|---|
| 状态机 `seenAssetIDsProvider?() ?? []` | 2（`processedAssetIDs` 与 `makeS2Handoff` 各 1） | 2 |
| 状态机 `legacyProgressMigration?(newRanges, groupingDimension, sessionStore)` | 1 且先于 `Self.reconciledStore(sessionStore, against: newRanges)` | 1，先于 |
| `makeS2Handoff(for:)` 体内 `continuationsByRangeID` | 0 | 0 |
| 状态机 `publishSnapshotIfChanged()`／`didSet`／`setMarked(` | 6／4／3 | 6／4／3 |
| 协调器 `machine.seenAssetIDsProvider = {` | 1 | 1 |
| 协调器 `machine.legacyProgressMigration = {` | 1 | 1 |
| 协调器 `migrateLegacyProgressIfNeeded(` | 2 | 2 |
| 协调器 `readS1Ranges(groupedBy: dimension)` | 1 | 1 |
| 协调器 `adoptedDimension: groupingDimension` | 1 | 1 |
| 协调器 `archive.hasMigratedLegacyProgress = true` | 1 | 1 |
| 协调器 `flushSeenArchive()` | 4 | 4 |
| 协调器 `photoLibrary.s1RangeRead(` | 2（不变） | 2 |
| 既有钉子：`sampleS2Exit(` 3／`s2ExitGuardFailure(` 3／`recordS2ExitDiagnostics(` 7／`cancelS2Handoff(virtualRangeID:` 1／原文 `return "` 0 | 3／3／7／1／0 | 3／3／7／1／0 |
| 既有钉子：`completeRangeRead(` 1／`currentReadRequest` 1／`publishS1FeedbackEvent(.submissionUnavailable)` 4／`S0Tab` 0 | 1／1／4／0 | 1／1／4／0 |
| 既有钉子：`recordSeenAssets(` 4／`persistence.saveS1SeenArchive(` 1／`persistence.loadS1SeenArchive()` 1／`finishSession` 切片 `Seen` 0 | 4／1／1／0 | 4／1／1／0 |
| 迁移文件原文 `import ` | 1 | 1 |
| 迁移文件剔注释 `Photos`／`PHAsset`／`L10n.`／`@MainActor`／`S0` | 各 0 | 各 0 |
| pbx：`10000000000000000000008C` 出现次数／`200000000000000000000089` 出现次数 | 3／2 | 3／2 |

**E**：`git hash-object IC188SeenSwitchTests.swift` = 卡面值；`func testIC188` 6 条；pbx `10000000000000000000008D` 3 次、`20000000000000000000008A` 2 次；`git diff --name-only 基线..E` 恰 15 路径。

## 五、`check_ic188.py` 五段 SUMMARY（提交后、进下一子项之前对刚提交的 tip 跑，退出码 0；FAIL 行：无）

| 段 | tip | SUMMARY |
|---|---|---|
| A | `41758c8897d5f70abbb0c2405884f7d06d3da04f` | 12 pass / 12 |
| B | `f1c8aeb06dba114d48176737c02c6dbc097bef51` | 15 pass / 15 |
| C | `42ae1af18a44394e0c1c9eaa8c442b1c16daf935` | 16 pass / 16 |
| D | `a5b49de5c36d1158734e2416dff964b0626f19e3` | 17 pass / 17 |
| E | `24b3cbd0c31cd7019be7f089523091dc61a8be5c` | 18 pass / 18 |

每段含：逐文件 blob 全等、`changed paths == whitelist`（9／12／13／14／15 路径）、`base is ancestor`、`catalog blob unchanged`。`docs` 段在 docs 提交后补跑（docs 提交的 SHA 无法写进自己，结果在回传给决策会话的回报里给出）。

## 六、本地门禁（五个提交各跑一次，贴真实退出码）

| 提交 | `git diff --cached --check` | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` |
|---|---|---|---|
| A | 0 | 0 | 0 |
| B | 0 | 0 | 0 |
| C | 0 | 0 | 0 |
| D | 0 | 0 | 0 |
| E | 0 | 0 | 0 |

（`powershell -NoProfile -ExecutionPolicy Bypass -File …` 从 Git Bash 调用；两个脚本的中文输出在本机控制台显示为乱码，只影响屏显，退出码是真实值。）

## 七、验收门禁逐条（G1035～G1039）

| 门禁 | 结果 |
|---|---|
| **G1035**（`check_ic188.py` A～E 五个 tip 全 PASS） | 满足，见第五节 |
| **G1036**（六条 `testIC188*` passed；十四个既有测试类全部 passed） | 满足，见第九节 |
| **G1037**（`FullFlowRoutingTests.testIC048_006S5ExitEndsSessionAndRebuildsS1Session` passed） | 满足（#380、#381 的唯一 Test Case 行均 passed） |
| **G1038**（合并前置） | 满足：G1035～G1037 + CI 绿（见第八节）+ 三十三条被保护分支 tip 未变（见第十一节）+ pbxproj 撞号扫描（见第十二节）+ 工作树净 + 合并前 `git ls-remote origin refs/heads/main` 仍 `0d46d37…` |
| **G1039**（合并后 `main` 运行绿，报告记 artifact 名称／id／有效期） | 满足，见第八节 |

## 八、CI

| 项 | 分支 #380 | 合并后 `main` #381 |
|---|---|---|
| run id | `37877855901` | `37879265210` |
| 被测提交 | `24b3cbd0c31cd7019be7f089523091dc61a8be5c` | `c3ae531e685904664e64f54e1ffe895108318204` |
| 结论 | success（作业 12 步全 success） | success（12 步全 success） |
| XCTest | 958 项、0 失败（唯一 Test Case 行 958 passed／0 failed；xcodebuild 小计 `Executed 958 tests, with 0 failures`） | 958 项、0 失败（同上） |
| 摘要 notice | `Executed 958 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 958 tests / 0 failures`（与小计一致，无需按第 217 条第四节另核） | 同 |
| 真实退出码 | 「运行 XCTest」步骤 success、日志 `** TEST SUCCEEDED **`（脚本 `exit "$test_status"` 原样退出 = 0） | 同 |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同样含 `OS:26.2, name:iPhone 16` |
| IPA | 文件 `PhotoCleanupMVE-unsigned.ipa`，字节数 1989436，SHA-256 `e600d07790ce4b0356642647ee509eb29f70ddd5922bcc8d4e845f45cb601be7` | 字节数 1989436，SHA-256 `a24879bc56e1db1a208a0ecc3ad22d3c6c7364b9c849ec3648c7dd41c9d91a22`（IPA 不可复现，两次 SHA 不同属预期） |
| 分段耗时 notice 原文 | `模拟器启动 106 s；xcodebuild test 541 s；总 647 s` | `模拟器启动 64 s；xcodebuild test 309 s；总 374 s` |
| artifact（G1039） | `PhotoCleanupMVE-unsigned-24b3cbd0c31c`，id `11593906390`，size 1989606，有效期至 2027-01-07T03:08:00Z | **`PhotoCleanupMVE-unsigned-c3ae531e6859`，id `11594250361`，size 1989606，未过期，有效期至 2027-01-07T03:26:12Z** |

- 两次日志里各有两行 `Errors found! Invalidating cache...`（陷阱 26 的模拟器着色器缓存失效行；本次未核它们与 `testIC063` 用例块的先后，日志里没有 `building pipeline … took` 行）；`testIC063` 两次均 passed，不属红因 (6)。
- 日志取得方式：`gh api repos/…/actions/runs/<id>/logs` 整包 zip，`zipfile` 读取并 `testzip` 校验；第一次取 #381 日志重试 6 次内曾失败一次（`fail`），重新执行后成功。

## 九、六条新断言与随改的既有断言

**六条新断言**（`IC188SeenSwitchTests`，#380／#381 的 `Test Case` 行耗时）：

| 函数 | 内容 | #380 | #381 |
|---|---|---|---|
| `testIC188A_ProcessedIsSeenSetIntersection` | 未注入为空；注入 `W` 后已看 = `W ∩ A(r)`；翻转排序不变；不存在的范围为空 | 0.001 s | 0.001 s |
| `testIC188B_EntryStartsAtFirstUnseenAndIgnoresK` | 进入位置：`K` 记着 a3，从第一张没看过的开始；全部看过从当前 `O` 第一张 | 0.001 s | 0.000 s |
| `testIC188C_MigrationPureFunctions` | 迁移纯函数：前缀常量、维度判定、要另读的维度、前缀之并 | 0.001 s | 0.020 s |
| `testIC188D_CoordinatorMigratesOnceBeforeClamp` | 协调器：钳制前迁移一次、置标记、立即写盘；9 月 a2、8 月 b3；换维度不再迁 | 0.004 s | 0.004 s |
| `testIC188E_EmptyLegacyStoreSetsFlagWithoutWriting` | 新会话：置标记、不写盘 | 0.002 s | 0.003 s |
| `testIC188F_SourceWiring` | 子项 B～D「改后」计数与先后、迁移文件只依赖 Foundation、未分类标识同值 | 0.030 s | 0.028 s |

**G1036 点名的既有测试类**（#380 唯一 Test Case 行 passed／failed）：`S1StateMachineTests` 20／0、`IC157LongPressIntoS2Tests` 8／0、`IC187SeenArchiveTests` 4／0、`FullFlowRoutingTests` 6／0、`S1SessionPersistenceTests` 6／0、`AlbumScopeWiringTests` 7／0、`IC131S1WriteBackToastTests` 5／0、`IC168FallbackDiagnosticsTests` 6／0、`IC170S1FirstReadTests` 6／0、`S2ActionBarWiringTests` 65／0、`SessionStoreTests` 14／0、`IC178DeckListTests` 5／0、`IC184RetireCaliberEnumsTests` 3／0、`IC185NavigationMaintenanceTests` 5／0，`IC188SeenSwitchTests` 6／0。#381 同数。

**随改的既有断言**（均按卡面「改为」块，没有卡外改动）：

| 位置 | 旧 → 新 |
|---|---|
| `S1StateMachineTests.testIC046_010`（函数名不改，裁定 六） | 前缀 `["asset-3","asset-2"]` → 未注入 `[]`、注入 `W` 后 `["asset-1","asset-3"]` |
| `testIC046_011`（函数名不改） | 后缀 `["asset-2","asset-3"]` → 翻转排序前后均 `["asset-2"]` |
| `testIC046_018` | 注入 `["asset-2","asset-3"]` 后 `processedAssetCount` 仍 2 |
| `testIC046_013` | 起点 `asset-2` → `asset-1` |
| `IC157LongPressIntoS2Tests` 逐字块 | 起点两行 → 三行（36 行，与 `makeS2Handoff(for:)` 原文逐字相等） |
| `IC187SeenArchiveTests` 测试 C | 最终集合 `[a1,a3,a5,a6,v2]` → `[a1,a2,a3,a4,a5,a6,v2]`；迁移标记 `XCTAssertFalse` → `XCTAssertTrue` |
| `IC187SeenArchiveTests` 测试 D | `flushSeenArchive()` 3 → 4 |
| 九处协调器构造点（A1～A9） | 改传 `TestPersistenceIsolation.makePersistence()` |

**项数对账式：`952 + 6 = 958`**（sim 预演 958；#380／#381 唯一 Test Case 行 958；摘要与小计 958）。

## 十、摘取关系实测

克隆：`git clone --no-hardlinks D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE <scratchpad>/ic188-exec/cl/<名>`，三个克隆均成功后才开始；所有命令带 `git -C <克隆>`；每个克隆里 `checkout -b pick <基线>`。原仓没有新建任何摘取分支（原仓分支只有 `feature/ic-188-seen-switch`；`git branch --list 'pick*'` 空）。克隆只证文本无冲突，绿由 CI 证。

| 单元 | 命令 | 退出码 | 结果树 |
|---|---|---|---|
| A 单独 | `cherry-pick -x A` | 0 | `af3bf19251a0a0664ec3ddb8923e3074d5668467`（= A 提交的树） |
| B 单独 | `cherry-pick -x B` | 0 | `776ed0f42ae6961a8458445972f2cc01039169d5`（仅存在于克隆里，原仓无此对象） |
| A→B→C→D 连续 | `cherry-pick -x A B C D` | 0 | `5371c1586aa09dea181beb6972a19b5872f9042f`（= D 提交的树） |

## 十一、G1038 被保护分支核对

`Tasks/decision-tools/ic188_protected_branches.txt`（33 行 `分支名 SHA`）对 `git ls-remote --heads origin`（远端共 107 个分支，含本卡分支）逐条比对：**checked 33、mismatch 0**，开工后第一次核（推送分支之后）与合并前再核一次均 0。IC-186 遗留的 `pickA`／`pickAB`／`pickABC` 三个本地分支：**无**（`git branch --list 'pick*'` 空）。

## 十二、pbxproj 撞号扫描与六个新 id

- 对象定义行（含 `= {isa`）的 24 位 id 去重扫描：重复 0。
- 六个新 id 出现次数：`10000000000000000000008B` 3（helper fileRef）、`10000000000000000000008C` 3（迁移文件 fileRef）、`10000000000000000000008D` 3（新测试 fileRef）、`200000000000000000000088` 2（helper buildFile）、`200000000000000000000089` 2（迁移文件 buildFile）、`20000000000000000000008A` 2（新测试 buildFile）。每个 fileRef = 定义 + 组 children + buildFile 引用，每个 buildFile = 定义 + 源码阶段，与基线同形。
- `git diff --cached --check` 五个提交均 0（无尾随空白）。

## 十三、规格欠账（卡面五条，本卡不改任何规格）

1. SPEC-S1 v12 `:253` 迁移触发「`看过档` 尚不存在时」——按档内标记判（第 224 条已记，本卡落实）。
2. `:253`「取不到该范围序列的（范围已失效）跳过」——当前维度之外的范围不算「已失效」，本卡在迁移那一次按需同步读其它维度，读不到才跳过（裁定 四）。**后果**：标记在这一次就置位，另读失败（授权失败、受限子集）或读到的序列里已没有 `p` 的那部分旧进度永久不再迁。
3. 会话档在迁移之前就被清的路径（S4／S5 档恢复、`finishSession()`、坏档重建）上的旧 `K` 不迁——接受，记欠账。
4. 第七节末「`K` 不再钳制」与代码不符（`reconcileRange` 仍钳 `c`／`p`）——`p` 退役与钳制去留归 ②d。
5. 看过档坏档／丢档（或标记未落盘进程就被杀）后 `currentSeenArchive()` 回空档、标记为 false，下一次采用范围会把当时的 `K` 前缀再并一遍——②d 之前 `farthestAssetID` 仍被每次 S2 返回写，这一次重迁会把拖横栏跳过的张算成看过；触发条件窄，②d 退役 `farthestAssetID` 后自然消失。

## 十四、人工判定项 H99（真机，保留给 Lynn，执行端不代判；原文）

1. 装包后第一次打开「逐张整理」：以前整理过的范围，已看进度大致还在（旧档迁移；**若手机上的旧会话已随 S5 离开清掉，「进度还在」免判**，只看下一句）；第一次进入时有没有明显卡顿（`K` 里有其它分组维度的范围时迁移把那一维度读一遍，只这一次）。
2. 进一个范围，翻页停住、横栏拖完停住、上滑标记后自动进下一张，各看几张再返回：卡上的已看百分比按实际看过的张数涨；横栏拖动途中一闪而过的不算。
3. 再进同一个范围：从第一张没看过的开始（不是上次停的位置）；整个范围都看过时从第一张开始；「最新在前／最旧在前」两种排序都看一眼。
4. 从「空间清理」类别页长按进入看过的照片，回到「逐张整理」对应月份也算看过。
5. 清空最近删除、离开结果页之后：已看进度不清零（待删篮照旧清空）。
6. 一两句总评（年卡「看完」、年页汇总行的数字对不对得上）。

装包取合并后 `main` 的 artifact `PhotoCleanupMVE-unsigned-c3ae531e6859`（id `11594250361`，2027-01-07 前有效）。

## 十五、docs 提交与最终核验

- docs 提交只含 `Reports/IC-188/self-check.md` 与 `Reports/IC-188/change-list.md`（惯例 44：合并与合并后 `main` 运行之后追加，纯 `Reports/**` 提交不触发 CI，预期行为）。
- docs 提交前已对本报告与 `change-list.md` 出现的全部 40 位 SHA 跑 `git cat-file -e <sha>^{<类型>}`，结果见 `change-list.md` 末节「核验结果」；docs 提交之后补跑 `check_ic188.py <docs 提交> docs`，结果在回传的回报里给出（docs 提交自身的 SHA 不写进它自己）。

## 十六、发现但未处理的问题（按纪律只报告不修）

1. **分支推送无分类器拦截；推 `main` 首次失败是网络问题**：`git push origin main` 第一次报 `schannel: failed to receive handshake`（非分类器拒绝），按环境注记换 `git -c http.proxy=http://127.0.0.1:7890 -c https.proxy=… push` 第一次即成功（`0d46d37..c3ae531`）。没有换改写法绕过任何拦截。
2. 测试 helper `TestPersistenceIsolation.makePersistence()` 每次新建 `IC188-isolated-<UUID>` 临时目录且不清理（决策会话复核 W2 已知并明示不改；模拟器 tmp、CI 每次新模拟器）。
3. 迁移是协调器主线程同步读其它维度（`readS1Ranges(groupedBy:)`），真机耗时无数据（调研 3.4 ③）；H99 第 1 条的「明显卡顿」判定即为此项的验证。
4. `Errors found! Invalidating cache...` 两行在两次 CI 日志里都出现（模拟器着色器缓存，陷阱 26），本卡未触发 `testIC063` 红，仅记录。
5. 本机 `core.autocrlf` 为 `true`；工作树文件为 LF，`git hash-object` 与卡面值逐一相等，未出现行尾转换问题。
6. 执行会话因 API 连接中断（ECONNRESET）被停过一次、续做完成（第一节）。
