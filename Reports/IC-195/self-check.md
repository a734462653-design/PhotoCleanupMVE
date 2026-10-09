# IC-195 自验报告

## 一、结论（先行）

- **三个子项全部按卡面完成（逐字节拷入 `ic195/stages/`，未手改一行），G1070～G1074 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-195-s2-guide-d-logic`：A `1e0629c5b8e9c491456f452410c9538896c27985` → B `e4fcb224c2f7f88e1cd44c01a5a1e46e9c4ba946` → C `3415eac9ffd6e53532c0536f6434601a8a93cee3`。
- 分支 CI **#394**（run `37973661392`，被测提交 C `3415eac9ffd6e53532c0536f6434601a8a93cee3`）一次绿：**986 项 0 失败**（978 + 8），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 2037709 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `77246b7403586674da299165b5b2cc664eb3f306`（双亲 `ae4776f846a70faaf9a05bb7cb445de56b2ad48c`／`3415eac9ffd6e53532c0536f6434601a8a93cee3`，树 `fd5a3407658959c66d8d8fc146585b90ea642472` 与 C 提交的树相同）。合并后 `main` CI **#395**（run `37975469359`）绿：986 项 0 失败，artifact `PhotoCleanupMVE-unsigned-77246b740358`（id `11638692677`，有效期至 2027-01-07T18:45:18Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 1 个、B 2 个、C 2 个）、卡面 A／B「改后（剔注释）」计数与工作树实测逐条相等（A 20 项检查、B 含 pbx 的全部检查、C 的 `testIC195H` 全部 needle 44 项，0 处不符）；提交后 `check_ic195.py` A／B／C 三个 tip 全 PASS（3／3、5／5、6／6）。
- **无界面变化，无人工判定项**：协调器只建不接，运行中的引导仍是 v23 三句就地提示（`S2InlineHints.swift`、`S2View.swift` 一字未动）。
- 本次没有停卡项，没有执行端偏离卡面的改动，没有被分类器拦截，没有中途中断，没有任何一次 CI 红。红因清单 (1)(2) 点名的编译风险（新枚举位置、`private(set) var` 可选、`@Published` 带 `didSet`、`switch` 里 `case .step(.markedOnce)?:`、协议 `{ get }` 由类存储属性满足、私有夹具类作协议实参、`UserDefaults(suiteName:)`）一项都没触发：两次整包日志里 swift error 0 行，warning 47 行（两次相同，基线既有），没有一条指向 `S2StateMachine.swift`、`S2GuideD.swift`、`IC195GuideDLogicTests.swift`。
- 网络：`git push -u origin feature/ic-195-s2-guide-d-logic` 与 `git push origin main` 都是第一次尝试即成功（git 直连、无代理）；合并后一次 `git ls-remote origin refs/heads/main` 撞上一次 `schannel: failed to receive handshake`，立即重试第一次即成功（该次调用未用来比对，空结果未被当作比对）。
- 未用的脚本：`materialize_ic195.py`、`gen_ic195_card.py` 未跑（明令不跑）；`sim_ic195.py` 只对基线跑了一次默认形态（0 失败，XCTest 计数 978 → 986），`IC195_GATES=1`／`IC195_CLONE=1` 两个开关没开——本地门禁与摘取实测我用自己的命令在真实提交上做了（第五、六节）。`Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（脚本一律 `python -B`，`ls | grep -c __pycache__` 为 0；`check_ic195.py` 在该目录里以 `python -B` 运行，输出写在 stdout）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-195-s2-guide-d-logic.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-195.md`；调研 `Tasks/RESEARCH-S2-guide-D-facts.md`（基线 `f550040`）与对时 `Tasks/RESEARCH-S2-guide-D-refresh.md`（对到 `bb2dee9`，文首抽查注）、拆卡与取定 `Tasks/PLAN-S2D-guide-rulings-20261009.md`；复核结论 `Tasks/REVIEW-IC-195-findings.md` 第四节「决策会话处置」（W1～W7 已体现在卡里，Q1～Q3 只记不定，已读）。
- 继承提交 / 基线：`main` = `ae4776f846a70faaf9a05bb7cb445de56b2ad48c`（IC-194 报告补记；merge `3920cd74279b76cca3f4b912f48513a616fe0a76`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 3920cd74279b76cca3f4b912f48513a616fe0a76 main` 退出码 0；`git ls-remote origin refs/heads/main` = `ae4776f846a70faaf9a05bb7cb445de56b2ad48c`；两个被改文件基线 blob 与卡面表逐个相等（`project.pbxproj` `a6907640369fa549c8bb9d91419d75291d678e5e`、`S2StateMachine.swift` `93885fb9ee540e9595fe701630f009dd1b724d89`）；本地与远端均无同名分支；先 `git checkout -b feature/ic-195-s2-guide-d-logic`（自 `ae4776f`）再拷文件。
- 目标分支：`feature/ic-195-s2-guide-d-logic`，合并入 `main`。
- 范围边界：白名单 4 路径（`project.pbxproj`、`S2StateMachine.swift`、新 `S2GuideD.swift`、新 `IC195GuideDLogicTests.swift`），`git diff --name-only ae4776f846a70faaf9a05bb7cb445de56b2ad48c..3415eac9ffd6e53532c0536f6434601a8a93cee3` 恰这 4 行。`S2View.swift`、`S2InlineHints.swift`、`Localizable.xcstrings`、协调器、App、`IC179`／`IC182` 两个既有测试文件、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）、`Scripts/`、`.github/` 一字未动。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `1e0629c5b8e9c491456f452410c9538896c27985` | `706a5d5c7691ce4f5f46bef4edcb267ccac86a81` | `S2StateMachine.swift`：新增枚举 `S2PendingDeletionChangeSource`（`.mark`／`.undo`／`.albumRemoval`）与 `S2CurrentAssetChangeCause`（`.markAdvance`／`.browse`）、两个 `private(set) var` 可选存储（不发布、不入档、不入标定），七个写入点赋值（+26）。1 个文件 |
| B | `e4fcb224c2f7f88e1cd44c01a5a1e46e9c4ba946` | `9c33e8a310149bcb10846cf528f0d531a780baf5` | 新文件 `Features/S2/S2GuideD.swift`（299 行：`S2GuideStep`、`S2GuideDisplay`、`S2GuideStoring` + `S2UserDefaultsGuideStore`、`S2GuideCoordinator`）+ pbx 源码登记四行。2 个文件 |
| C | `3415eac9ffd6e53532c0536f6434601a8a93cee3` | `fd5a3407658959c66d8d8fc146585b90ea642472` | 新测试 `IC195GuideDLogicTests.swift`（八条，675 行）+ pbx 测试登记四行。2 个文件 |
| 合并 | `77246b7403586674da299165b5b2cc664eb3f306` | `fd5a3407658959c66d8d8fc146585b90ea642472` | `merge(IC-195): S2 教学引导 D 的逻辑层——状态机两个一次性信号与引导协调器（四步 + 完成、跳过、进门压暗、六个已会标志）；不接视图` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-195/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --numstat` 基线..C：`project.pbxproj` +8／−0、`S2StateMachine.swift` +26／−0、`S2GuideD.swift` +299／−0、`IC195GuideDLogicTests.swift` +675／−0。分支推送一次成功（git 直连，无分类器拦截）；推 `main` 一次成功。

## 四、逐子项提交前对读与拷入文件 `git hash-object`

脚本（scratchpad `ic195-exec/count_a.py`、`count_b.py`、`count_c.py`）：读工作树文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（直接 `import` 了 `Tasks/decision-tools/strip.py` 的 `strip_text`，只读），逐条数卡面子项 A、B「改后（剔注释）」段、测试 H 的全部 needle、切片内计数与次序。每个子项都是提交前跑、全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic195.py` 又用 `git rev-parse <tip>:<路径>` 核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE/Core/S2StateMachine.swift` | `14b801bbbc32706db33d31424d63aee638ecd2a5` | `14b801bbbc32706db33d31424d63aee638ecd2a5` | 相等 |
| B | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `6a87133b54f6f9f08c1577b84c39c21c316fba6b` | `6a87133b54f6f9f08c1577b84c39c21c316fba6b` | 相等 |
| B | `PhotoCleanupMVE/Features/S2/S2GuideD.swift` | `64092070a824b59c30119fdee7ee78419b27d0e2` | `64092070a824b59c30119fdee7ee78419b27d0e2` | 相等 |
| C | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `0cb33b6255d203de7a997de753a8206755e21377` | `0cb33b6255d203de7a997de753a8206755e21377` | 相等 |
| C | `PhotoCleanupMVETests/IC195GuideDLogicTests.swift` | `018b4606cefa3b043acb2445d6c79d68b701cf6e` | `018b4606cefa3b043acb2445d6c79d68b701cf6e` | 相等 |

每个子项拷入后 `git status --porcelain` 只列该子项的文件（A：` M S2StateMachine.swift`；B：` M project.pbxproj`、`?? S2GuideD.swift`；C：` M project.pbxproj`、`?? IC195GuideDLogicTests.swift`），按清单逐个 `git add <路径>`（未用 `-A`）。

**子项 A「改后（剔注释）」计数实测**（`S2StateMachine.swift`；每行「实测／卡面」，0 处不符）

| needle | 实测／卡面 |
|---|---|
| `enum S2PendingDeletionChangeSource: Equatable {` | 1／1 |
| `enum S2CurrentAssetChangeCause: Equatable {` | 1／1 |
| `private(set) var lastPendingDeletionChangeSource: S2PendingDeletionChangeSource?` | 1／1 |
| `private(set) var lastCurrentAssetChangeCause: S2CurrentAssetChangeCause?` | 1／1 |
| `lastPendingDeletionChangeSource = .mark`／`.undo`／`.albumRemoval` | 各 1／1 |
| `lastCurrentAssetChangeCause = .markAdvance` | 1／1 |
| `lastCurrentAssetChangeCause = .browse` | 4／4 |
| `replacePendingDeletionAssetIDs(` | 4／4（不变） |
| `holdsPageAfterNextMark` | 3／3（不变）；`var holdsPageAfterNextMark = false` 1／1 |
| `? handleSwipeDown()`、`func handleSwipeDown()` | 各 1／1（不变，IC146 钉子） |
| `markCurrentSeen()` | 4／4（不变，IC187D 钉子）；`handleSwipeUp` 切片内 0、`handleNativePageChange` 切片内 0、`switchPhoto(by:)` 本体内 1 |
| `handleSwipeUp` 切片次序：来源赋值 < `replacePendingDeletionAssetIDs(with: nextPending)` < 原因赋值 < `if holdsPageAfterNextMark && zoomState == .oneX {` < `switchPhoto(by: 1)` | 成立 |
| `handleSwipeUp` 切片内 `switchPhoto(by: 1)` 1／1、`resetZoomAfterPhotoChange()` 0／0、`pendingUndecidedItem = .item02` 1／1 | 全相符（IC182C 钉子） |
| `switchPhoto(by:)` 本体 `lastCurrentAssetChangeCause` | 0／0 |

**子项 B「改后（剔注释）」计数实测**（`S2GuideD.swift`）

| needle | 实测／卡面 |
|---|---|
| `enum S2GuideStep: String, CaseIterable, Equatable {`、`enum S2GuideDisplay: Equatable {`、`protocol S2GuideStoring {`、`struct S2UserDefaultsGuideStore: S2GuideStoring {`、`final class S2GuideCoordinator: ObservableObject {` | 各 1／1 |
| `@Published private(set) var display: S2GuideDisplay?`、`@Published private(set) var showsIntroDim = false` | 各 1／1 |
| `static let confirmThreshold = 5`、`static let completionAutoDismissSeconds: TimeInterval = 2` | 各 1／1 |
| `init(store: S2GuideStoring = S2UserDefaultsGuideStore())` | 1／1 |
| `@MainActor`、`L10n.`、`View`、`Text(`、`S2InlineHint` | 各 0／0 |
| 原文 `import `（`Combine`、`Foundation`） | 2／2 |
| 原文 `return "` | 0／0 |
| 含汉字的字符串字面量 | 0 |

pbx（B）：`git diff -U0 HEAD` 恰 4 行新增、0 行删除（`PBXBuildFile` `200000000000000000000094`、`PBXFileReference` `100000000000000000000097`、`S2` 组 children、Sources 阶段）。

## 五、`check_ic195.py` 三段 SUMMARY 与摘取实测

`check_ic195.py` 在刚提交的 tip 上跑（基线取脚本默认值 `ae4776f`，`python -B`，在 `Tasks/decision-tools/` 里运行；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `1e0629c5b8e9c491456f452410c9538896c27985` | `SUMMARY 3 pass / 3`（blob 1 + `changed paths == whitelist (1)` + `base is ancestor`） | 0 |
| B | `e4fcb224c2f7f88e1cd44c01a5a1e46e9c4ba946` | `SUMMARY 5 pass / 5`（blob 3 + `changed paths == whitelist (3)` + `base is ancestor`） | 0 |
| C | `3415eac9ffd6e53532c0536f6434601a8a93cee3` | `SUMMARY 6 pass / 6`（blob 4 + `changed paths == whitelist (4)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

另按提示词在基线上跑了一次 `python -B sim_ic195.py`（不带开关）：`FAILURES 0 []`，XCTest 计数 `978 → 986`、`+8`。

**摘取关系实测**（克隆 `git clone --no-hardlinks` 到 scratchpad `ic195-exec/clone`，克隆成功；命令全部 `git -C <克隆>`，从未落到原仓；克隆里自基线 `ae4776f846a70faaf9a05bb7cb445de56b2ad48c` 起 `checkout -B pick`，对我的真实三个提交 `cherry-pick -x`；只证文本无冲突，绿由 CI 证）：

| 组合 | 退出码 | 结果树 | 备注 |
|---|---|---|---|
| A 单独 | 0 | `706a5d5c7691ce4f5f46bef4edcb267ccac86a81` | 与分支上 A 提交的树相同 |
| A → B | 0（两步各 0） | `9c33e8a310149bcb10846cf528f0d531a780baf5` | 与分支上 B 提交的树相同 |
| A → B → C | 0（三步各 0） | `fd5a3407658959c66d8d8fc146585b90ea642472` | 与分支 tip C 的树、合并提交的树相同 |

（备注：克隆里我的循环对每组用了 `-c core.autocrlf=false` 的 `git status`，而克隆本身 `core.autocrlf=true` 检出的是 CRLF 工作文件，所以那一行 `status` 行数显示 7，是行尾设置差异；改用克隆自己的配置再看 `git status --porcelain` 为空。树 SHA 才是判定依据，三个结果树与分支上的树逐个相同。）

## 六、本地门禁（三个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 用 `powershell -NoProfile -ExecutionPolicy Bypass -File …`（Windows PowerShell 5.1，在 PowerShell 工具里取 `$LASTEXITCODE`）在仓库根跑；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0（「结构自验通过」，扫描 72 个测试源文件，137 个 .swift 括号结构通过） | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致」） | 0 |
| B | 0（72 个测试源文件） | 0（同） | 0 |
| C | 0（扫描 73 个测试源文件，含新测试文件） | 0（同） | 0 |

## 七、验收门禁逐条（G1070～G1074）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1070 行为与落位 | 满足 | 第五节：`check_ic195.py` A、B、C 三个 tip 全 PASS |
| G1071 新断言 | 满足 | 八条 `testIC195*` 在 #394 与 #395 整包日志里全部 passed（第九节） |
| G1072 不回退 | 满足 | `IC182TutorialRoundTwoTests`（5 条）、`IC179InlineHintsTests`（9 条）、`IC146ChromeRoundTwoTests`（19 条）、`IC187SeenArchiveTests`（4 条）、`S2ActionBarWiringTests`（65 条）、`S2StateMachineTests`（52 条）在 #394 与 #395 的整包日志里按唯一 Test Case 行数全部 passed、0 failed（顺带：`IC194S3ReturnLandingTests` 6 条也全 passed） |
| G1073 合并前置 | 满足 | G1070～G1072 + CI #394 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice；摘要 986 与 xcodebuild 小计 986 一致，无需按第 217 条第四节另核）+ 40 条被保护分支 tip 未变（第十一节，推送前、合并前各核一次，合并后再核一次）+ pbxproj 撞号扫描（第十节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote origin refs/heads/main` 仍为 `ae4776f846a70faaf9a05bb7cb445de56b2ad48c`） |
| G1074 合并后 | 满足 | 合并后 `main` CI #395 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #394 | 合并后 `main` 运行 #395 |
|---|---|---|
| run id | `37973661392` | `37975469359` |
| 被测提交 | `3415eac9ffd6e53532c0536f6434601a8a93cee3` | `77246b7403586674da299165b5b2cc664eb3f306` |
| 触发 | push 到 `feature/ic-195-s2-guide-d-logic` | push 到 `main` |
| 作业起止 | 2026-10-09T18:29:50Z～18:43:34Z | 2026-10-09T18:45:25Z～18:55:36Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 986 项，0 失败（xcodebuild `Executed 986 tests, with 0 failures (0 unexpected) in 51.352 (52.835) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 986 passed／0 failed） | 986 项，0 失败（`Executed 986 tests, with 0 failures (0 unexpected) in 51.321 (53.138) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 986 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 986 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 986 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`） | 0（同） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2037709 字节，SHA-256 `db7686d34dda29c01e1d4bd42b54a98921a862c1a2abfd3b6f743ee1287a132a` | 2037709 字节，SHA-256 `74a0437ac06deef63e607f2d46e1d56a5c7419f42534a9761506833f40ee32b1`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 103 s；xcodebuild test 385 s；总 490 s` | `模拟器启动 69 s；xcodebuild test 344 s；总 414 s` |
| artifact | `PhotoCleanupMVE-unsigned-3415eac9ffd6`，id `11638690707`，2037879 字节，有效期至 2027-01-07T18:29:42Z | `PhotoCleanupMVE-unsigned-77246b740358`，id `11638692677`，2037879 字节，有效期至 2027-01-07T18:45:18Z |
| 八条 `testIC195*` 用例耗时（日志 `Test Case … passed (N seconds)`） | A `testIC195A_EntryRules` 0.003 s；B `testIC195B_MarkHoldAndCollapse` 0.002 s；C `testIC195C_UnmarkAndUndoneStep` 0.001 s；D `testIC195D_CountRiseShowsConfirmEntryInEitherOrder` 0.006 s；E `testIC195E_ConfirmSkipCompletionLeaveReset` 0.001 s；F `testIC195F_UserDefaultsStoreReusesV23Keys` 0.013 s；G `testIC195G_StateMachineChangeSignals` 0.002 s；H `testIC195H_SourceWiring` 0.103 s | A 0.003 s；B 0.002 s；C 0.001 s；D 0.005 s；E 0.001 s；F 0.011 s；G 0.001 s；H 0.109 s |

- 两次构建日志里 swift error 行 0 条、warning 行 47 条（两次相同），没有任何一条指向 `S2StateMachine.swift`、`S2GuideD.swift`、`IC195GuideDLogicTests.swift`；没有类型检查超时、result builder 报错或扫描器红。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）：`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` #394 7.090 s、#395 7.014 s，均 passed；两次日志里 `building pipeline` 均 0 次，各有两行 `Invalidating cache`（既有，与本卡无关）。
- CI 预算 3 次，用了 1 次（#394）；#395 为合并后 `main` 运行，不计入试错预算。

## 九、八条新断言（`PhotoCleanupMVETests/IC195GuideDLogicTests.swift`，逐字节拷入，blob `018b4606cefa3b043acb2445d6c79d68b701cf6e`，675 行）

| 断言 | 函数名 | 内容（据卡面 C 节） |
|---|---|---|
| A | `testIC195A_EntryRules` | J2：新装出第 1 步与进门压暗、压暗出现即记标志；再进不再压暗；第 1 步已会时篮内 5 张出第 4 步、4 张不出；四步都已会出完成提示并记标志、到点收起、再进不出；只学会 v23 三句的设备进入不出 |
| B | `testIC195B_MarkHoldAndCollapse` | J3／J4／L1／L3：停住出第 2 步、压暗随第 1 步消失、不再停；翻看或标记后自动进下一张收起第 2 步、不记已会、本次不再出、下次进入仍停；没停住（放大态）不出也不记收起、两回调两种顺序结果相同、下一次停住的标记出第 2 步 |
| C | `testIC195C_UnmarkAndUndoneStep` | J5／J6：下滑撤标出第 3 步、翻看记已会；相簿静默移除只记第 2 步已会；第 1 步在显时撤标不出第 3 步；第 3 步在显时标记后自动进下一张只收起不记已会、本次不再出；第 4 步在显时撤标不出第 3 步 |
| D | `testIC195D_CountRiseShowsConfirmEntryInEitherOrder` | J7：标记（没停住／停住）与计数上升到 5 两种顺序都只见第 4 步、第 2 步本次不再出；只在上升且达阈值时出、下降不触发、在显第 4 步时再升不变；被顶掉的第 3 步本次不再出 |
| E | `testIC195E_ConfirmSkipCompletionLeaveReset` | J8～J12：进 S3 是最后一步时下一次进入出完成提示；当场学会最后一步且 `V=显示` 当场出、`V=隐藏` 下次进入出；跳过收起与压暗、本次不再出任何一项、不停留、动作本身照常学会、离开后清空；重看教程清零六标志并当场重出第 1 步与压暗 |
| F | `testIC195F_UserDefaultsStoreReusesV23Keys` | 独立 suite 的 `UserDefaults`：第 1、2、4 步的键与 v23 `S2UserDefaultsInlineHintStore` 逐字相同、v23 记下的「已会」原样读到；六标志往返、换实例读回、重置清空 |
| G | `testIC195G_StateMachineChangeSignals` | 上滑（`.mark`／`.markAdvance`）、左右滑与原生分页（`.browse`）、下滑（`.undo`）、学习例外停住（原因照记、当前张不变）、横栏拖动（`.browse`）、加入最近相簿成功（`.albumRemoval`） |
| H | `testIC195H_SourceWiring` | 状态机与新文件的计数、次序与切片，`S2View.swift` 与 `S2InlineHints.swift` 里没有引导 D 的名字 |

**随改的既有断言**：无（卡面未要求；既有钉子 IC146／IC182A／C／IC187D 在状态机里的计数与次序全部不变，已在第四节与整包日志双证）。

**项数对账**：978 + 8 = **986**；#394 与 #395 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行数三者都是 986；提交前本机 `func test*` 行数（剔注释后）986，IC195 文件 8。

## 十、pbxproj 撞号扫描与四个新 id

- 推进前扫描：基线 `project.pbxproj` 全文 `100000000000000000000097`、`200000000000000000000094`、`100000000000000000000098`、`200000000000000000000095` 四个 id 各出现 0 次；基线最大号 fileRef `100000000000000000000096`、buildFile `200000000000000000000093`（IC-194），`PBXBuildFile`／`PBXFileReference` 共 318 条定义，重复 id `[]`。
- B 提交前：`git diff -U0 HEAD` 恰四行新增；定义 320 条，重复 `[]`；`100000000000000000000097` 全文 3 次（定义 + buildFile 引用 + 组）、`200000000000000000000094` 全文 2 次（定义 + Sources 阶段）。C 提交前：定义 322 条，重复 `[]`；`100000000000000000000098` 全文 3 次、`200000000000000000000095` 全文 2 次；最大号 fileRef `100000000000000000000098`、buildFile `200000000000000000000095`。
- 四个新 id：源码 fileRef `100000000000000000000097`／buildFile `200000000000000000000094`（`S2GuideD.swift`，接在 `S2InlineHints.swift` 之后）；测试 fileRef `100000000000000000000098`／buildFile `200000000000000000000095`（`IC195GuideDLogicTests.swift`，接在 `IC194S3ReturnLandingTests.swift` 之后）。

## 十一、G1073 被保护分支核对

清单 `Tasks/decision-tools/ic195_protected_branches.txt` 恰 40 行（`分支名 SHA`，无注释行）。对 `git ls-remote --heads origin` 逐条比对：推送后 CI 期间（远端 114 个 head）、合并前（114）——**不符 0 条（40／40 相等）**；合并并推送 `main` 之后又比了一次（远端 114 个 head），同样 40／40 相等、不符 0 条。比对脚本遇 `ls-remote` 返回空即重试，空列表不算比对（本次每次第一次返回即非空）。合并后 `main` = `77246b7403586674da299165b5b2cc664eb3f306`。

## 十二、规格欠账（卡面七条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S2 修订）

1. J3／J4／L3 合读——标记后没停住时不出第 2 步、也不记本次收起（规格 J4 字面「自动进入下一张收起第 2 步、本次不再出」与 L3「例外留给下一次 `s = 1` 的标记」冲突，取后者）。
2. J7 第 4 步出现时一律记第 2 步本次不再出（不论当时是否在显，沿 v23）。
3. J10「当场出完成提示」要 `V=显示`，由视图同步 `isInterfaceVisible`。
4. 两个信号初值 nil，视图读到 nil 时视作哪种来源／原因归 D2 定。
5. 落盘键名：沿用 v23 前缀，第 3 步 `…s2.hint.undone`、完成已出 `…s2.hint.completed`、压暗已出 `…s2.hint.introDimmed`（J12「落盘键名由实装卡登记」）。
6. `S2GuideCoordinator.confirmThreshold` 与 v23 `S2InlineHintCoordinator.confirmThreshold` 同值并存到 D2 退役旧族。
7. 中央「撤销」与下滑在状态机里同为 `.undo`（视图的撤销钮调的是同一个 `handleSwipeDown()`），规格 J5 本就同口径，不另分。

另（复核只记不定、已写入决策会话处置的 Q1～Q3，我只转述）：Q1 放大态标记不出第 2 步也不记收起（＝欠账 1）；Q2 第 4 步出现一律记第 2 步本次不再出（＝欠账 2）；Q3 跳过那次进入里做过的动作照常记已会，与未定项 36 相邻。

**D2 前置（卡「范围外」与计划第三节，只转述）**：`testIC195H_SourceWiring` 末段钉「`S2View.swift`／`S2InlineHints.swift` 里没有引导 D 的名字」，D2 接线后必改，D2 白名单须含 `IC195GuideDLogicTests.swift`；`isInterfaceVisible` 的同步取法（W3）、`start(mergedCount:)` 每次进入只调一次（W4）、`holdsPageOnNextMark` 的显式同步与两个信号只在 `.onChange` 体内同步读（W5）见 `PLAN-S2D-guide-rulings-20261009.md` 第三节。

## 十三、docs 提交与最终核验

- 惯例 44：本报告与 `change-list.md` 随合并与合并后 `main` 运行之后的**恰一个 docs 提交**落在 `main` 上（仅 `Reports/IC-195/` 两个文件，`Reports/**` 命中 `ci.yml` 的 `paths-ignore`，该提交不触发 CI）。
- 报告写完后，对报告里出现的每个 40 位 SHA 跑了 `git cat-file -e <sha>^{<类型>}`：结果见本文末「报告内 SHA 核验」。

## 十四、人工判定项

**无。** 本卡不接视图，没有界面变化，运行中的引导仍是 v23 三句；夹具驱动的测试只验协调器规则与状态机信号，视图、观感、真机回调顺序归 D2。

## 十五、发现但未处理的问题（按纪律只报告不修）

1. 无产品或卡面缺陷发现。执行中没有偏离卡面的改动。
2. 琐碎的工具备注（非缺陷）：`git merge -F -` 不支持从标准输入读消息，第一次合并命令因此以退出码 129 失败、未产生任何合并（`main` 与工作树未动）；改用 scratchpad 里的消息文件 `-F <文件>` 一次成功。
3. 提示词的 `IC195_GATES=1`／`IC195_CLONE=1` 两个开关我没有开（`sim_ic195.py` 的克隆用的是它自己合成的提交链），摘取关系与本地门禁用真实提交各做了一遍；若决策会话要 sim 输出存档，需要自己跑。
4. 合并后 `main` 运行的前台等待命令超过工具的 10 分钟前台上限，被工具自动转入后台、随后读到完成结果，不影响结论；两次 run 都在推送后约 1 分钟内出现在 API 里。

## 报告内 SHA 核验

两份报告里出现的全部 40 位 SHA（去重后见下表，正则按前后非十六进制字符取，SHA-256 与 blob 哈希中的子串不会被误取）逐个跑 `git cat-file -e <sha>^{<类型>}`，退出码全 0，缺失 0 个（SHA-256 `db7686d3…`、`74a0437a…` 不是 git 对象，不在此表）：

| SHA | 对象类型 | `cat-file -e` 退出码 |
|---|---|---|
| `1e0629c5b8e9c491456f452410c9538896c27985` | commit | 0 |
| `e4fcb224c2f7f88e1cd44c01a5a1e46e9c4ba946` | commit | 0 |
| `3415eac9ffd6e53532c0536f6434601a8a93cee3` | commit | 0 |
| `77246b7403586674da299165b5b2cc664eb3f306` | commit | 0 |
| `ae4776f846a70faaf9a05bb7cb445de56b2ad48c` | commit | 0 |
| `fd5a3407658959c66d8d8fc146585b90ea642472` | tree | 0 |
| `3920cd74279b76cca3f4b912f48513a616fe0a76` | commit | 0 |
| `a6907640369fa549c8bb9d91419d75291d678e5e` | blob | 0 |
| `93885fb9ee540e9595fe701630f009dd1b724d89` | blob | 0 |
| `706a5d5c7691ce4f5f46bef4edcb267ccac86a81` | tree | 0 |
| `9c33e8a310149bcb10846cf528f0d531a780baf5` | tree | 0 |
| `14b801bbbc32706db33d31424d63aee638ecd2a5` | blob | 0 |
| `6a87133b54f6f9f08c1577b84c39c21c316fba6b` | blob | 0 |
| `64092070a824b59c30119fdee7ee78419b27d0e2` | blob | 0 |
| `0cb33b6255d203de7a997de753a8206755e21377` | blob | 0 |
| `018b4606cefa3b043acb2445d6c79d68b701cf6e` | blob | 0 |

共 16 个，缺失／不通过 0 个。
