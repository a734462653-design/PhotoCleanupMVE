# IC-194 自验报告

## 一、结论（先行）

- **三个子项全部按卡面完成（逐字节拷入 `ic194/stages/`，未手改一行），G1065～G1069 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-194-s3-return-landing`：A `366a6a50dacf2377ee63a2ae637a1613f884c5d1` → B `a9877cde51e1600bfb002d28c5fabc3e12214e21` → C `da09a9435ab7085fd60a3a54ee327b0fea02885a`。
- 分支 CI **#392**（run `37964461543`，被测提交 C `da09a9435ab7085fd60a3a54ee327b0fea02885a`）一次绿：**978 项 0 失败**（972 + 6），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 2031842 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `3920cd74279b76cca3f4b912f48513a616fe0a76`（双亲 `b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066`／`da09a9435ab7085fd60a3a54ee327b0fea02885a`，树 `30ea3dfb04b847beadfc1a3e2a86543403956bce` 与 C 提交的树相同）。合并后 `main` CI **#393**（run `37966179688`）绿：978 项 0 失败，artifact `PhotoCleanupMVE-unsigned-3920cd74279b`（id `11633209923`，有效期至 2027-01-07T17:25:37Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 2 个、B 1 个、C 3 个）、卡面 A／B「改后（剔注释）」计数与工作树实测逐条相等（A 53 条、B 54 条、C 54 条，0 处不符）；提交后 `check_ic194.py` A／B／C 三个 tip 全 PASS（4／4、4／4、7／7）。
- **有行为变化**：S2 右上待删篮进确认页再返回，现在回到那次 S2（同一范围、离开时那张）而不是列表页；冷启动恢复「已取消」完成页后经「返回确认页」再返回，现在装上 S1 会话落「逐张整理」（此前是返回钮无反应）。人工判定项 H102 八条保留给 Lynn（第十四节），本报告不对观感下结论。
- 本次没有停卡项，没有执行端偏离卡面的改动，没有被分类器拦截，没有中途中断，没有任何一次 CI 红。红因清单 (1)(2) 点名的编译风险（嵌套类型、`if let` 简写、`guard let handoff`、私有夹具类型作默认实参、`waitUntil` 闭包读主 actor 属性）一项都没触发：两次整包日志里没有任何一条 warning 或 error 指向 `CleanupCoordinator.swift`、`S1StateMachine.swift`、`IC194S3ReturnLandingTests.swift`、`IC168FallbackDiagnosticsTests.swift`。
- 网络：`git push -u origin feature/ic-194-s3-return-landing` 与 `git push origin main` 都是第一次尝试即成功（git 直连、无代理、无 `schannel` 失败）；三次 `git ls-remote --heads origin` 都第一次返回非空（112／113／113 行）。
- 未跑 `sim_ic194.py`（提示词只规定它「只对基线跑」，没有要求执行端必跑；本卡的本地门禁、摘取实测我用自己的命令做了，见第五、六节）；`materialize_ic194.py`、`gen_ic194_card.py` 未跑（明令不跑）。`Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（`check_ic194.py` 一律 `python -B`，无 `__pycache__`，`find … -name __pycache__` 为空；`gh_runs.py`、`ghq.sh` 只读调用，输出写在我自己的临时目录）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-194-s3-return-landing.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-194.md`；调研 `Tasks/RESEARCH-S3-return-facts.md`（基线 `f550040`）与对时 `Tasks/RESEARCH-S3-return-refresh.md`（对到 `bb2dee9`，文首抽查注：计数类一律重核——本卡的计数由卡面「改后」段给出，我逐条在工作树上重核）；裁定 `Tasks/PLAN-S3R-return-rulings-20261009.md`；复核结论 `Tasks/REVIEW-IC-194-findings.md` 的处置节（已读，W1～W7 均已体现在卡里，Q1～Q4 只记不定）。
- 继承提交 / 基线：`main` = `b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066`（IC-193 报告补记；merge `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76 main` 退出码 0；`git ls-remote origin refs/heads/main` = `b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066`；四个被改文件基线 blob 与卡面表逐个相等（`project.pbxproj` `0cdb6c0df6eda43e2ff4f4d91cc63ebcd4bf6d1b`、`CleanupCoordinator.swift` `55f599914c2096fa614b5a7ae78e9f7b22452f26`、`S1StateMachine.swift` `756660c8ed29bea218c02a032c5ae3510501282f`、`IC168FallbackDiagnosticsTests.swift` `53fd4c93ad4c563ba9444bf79e378276f68e1886`）；远端无同名分支；先 `git checkout -b feature/ic-194-s3-return-landing b3ebd43…` 再拷文件。
- 目标分支：`feature/ic-194-s3-return-landing`，合并入 `main`。
- 范围边界：白名单 5 路径（`project.pbxproj`、`CleanupCoordinator.swift`、`S1StateMachine.swift`、`IC168FallbackDiagnosticsTests.swift`、新 `IC194S3ReturnLandingTests.swift`），`git diff --name-only b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066..da09a9435ab7085fd60a3a54ee327b0fea02885a` 恰这 5 行。App 入口与全部视图、`makeS2Handoff(for:)`／`makeS2Handoff(virtualRangeID:…)` 本体、`returnToConfirmation()`、`enterS2(from:)` 守卫、`SessionStore`、S2／S3／S4／S5 状态机、`Scripts/`、`.github/`、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）一字未动。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `366a6a50dacf2377ee63a2ae637a1613f884c5d1` | `1d6aca0840ec95bd135e67fa3823874769b2d5d9` | 协调器 `S3ReturnTarget`／`s3ReturnTarget`、`enterConfirmationFromS2` 写回前取落点并在进 S3 成功后记下、`enterConfirmationFromS1` 成功即清、`handleS3Return` 落上游后按记录重进（新私有 `reenterS2(returningTo:)`）、`installS1Session` 清（+82）；S1 状态机 `makeS2ReentryHandoff(for:)`（+21，放在 `cancelS2Handoff` 与 `makeS3Submission` 之间）。2 个文件 |
| B | `a9877cde51e1600bfb002d28c5fabc3e12214e21` | `67f51cf0235653588faace5c864c22e796e970f1` | `handleS3Return` 开头一个守卫：`route == .confirmation, sessionStore == nil, s1Machine == nil` → `enterS1ResumingPersistedSessionOrStartNew()`（+5）。1 个文件 |
| C | `da09a9435ab7085fd60a3a54ee327b0fea02885a` | `30ea3dfb04b847beadfc1a3e2a86543403956bce` | 新测试 `IC194S3ReturnLandingTests.swift`（六条，655 行）+ `IC168FallbackDiagnosticsTests` 协调器表 `cancelS2Handoff(virtualRangeID:` 1 → 2 + pbx 四行。3 个文件 |
| 合并 | `3920cd74279b76cca3f4b912f48513a616fe0a76` | `30ea3dfb04b847beadfc1a3e2a86543403956bce` | `merge(IC-194): S3 返回落点——从 S2 待删篮进的确认页返回回到那次 S2（同一范围、离开时那张）；经 S5 中转照旧；冷启动恢复后返回装上 S1 会话` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-194/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --numstat` 基线..C：`project.pbxproj` +4／−0、`CleanupCoordinator.swift` +87／−0、`S1StateMachine.swift` +21／−0、`IC168FallbackDiagnosticsTests.swift` +2／−1、`IC194S3ReturnLandingTests.swift` +655／−0。分支推送一次成功（git 直连，无分类器拦截）；推 `main` 一次成功。

## 四、逐子项提交前对读与拷入文件 `git hash-object`

脚本 `scratchpad/ic194-exec/counts.py`：读工作树（提交后再以 `COUNTS_REV=<tip>` 读 git 对象重跑存档）文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（与 `Tasks/decision-tools/strip.py` 同一实现，复制在我自己的脚本里），逐条数卡面子项 A、B「改后（剔注释）」段与测试 F 四张计数表、三组顺序、切片内计数。每个子项都是提交前跑、全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic194.py` 又用 `git rev-parse <tip>:<路径>` 核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `7fd3c8f6f9e157fd47ed5111ce546180f6adbd54` | `7fd3c8f6f9e157fd47ed5111ce546180f6adbd54` | 相等 |
| A | `PhotoCleanupMVE/Core/S1StateMachine.swift` | `d252a22096d3d2bae1905dfffa366d182ffda3f2` | `d252a22096d3d2bae1905dfffa366d182ffda3f2` | 相等 |
| B | `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `b872f1420b6de2dc82504467143b02abd0e0a00d` | `b872f1420b6de2dc82504467143b02abd0e0a00d` | 相等 |
| C | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `a6907640369fa549c8bb9d91419d75291d678e5e` | `a6907640369fa549c8bb9d91419d75291d678e5e` | 相等 |
| C | `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | `3692f42b302941e82a61dd0edc856151dd5ddae2` | `3692f42b302941e82a61dd0edc856151dd5ddae2` | 相等 |
| C | `PhotoCleanupMVETests/IC194S3ReturnLandingTests.swift` | `ff3620d978b337bb9343a97440f292a220702b5d` | `ff3620d978b337bb9343a97440f292a220702b5d` | 相等 |

**子项 A、B「改后（剔注释）」计数实测**（卡面值 = 实测值，0 处不符；每行格式「needle：实测／卡面」）

协调器（A 提交后；B 提交后只多下面「B」两行与 `enterS1ResumingPersistedSessionOrStartNew()` 2 → 3）：

| needle | 实测／卡面 |
|---|---|
| `struct S3ReturnTarget: Equatable {` | 1／1 |
| `private(set) var s3ReturnTarget: S3ReturnTarget?` | 1／1 |
| `s3ReturnTarget` | 6／6 |
| `s3ReturnTarget = returnTarget` | 1／1 |
| `s3ReturnTarget = nil` | 3／3 |
| `let returnTarget = S3ReturnTarget(`（在 `enterConfirmationFromS2` 切片内先于 `guard applyS2ExitPayload(payload) else {`、`guard enterConfirmationFromS1(submission) else {`、`s3ReturnTarget = returnTarget`） | 1／1，顺序成立 |
| `s1Machine?.activeVirtualRangeIDs.contains(` | 2／2（诊断取样 1 + 本卡 1） |
| `private func reenterS2(returningTo target: S3ReturnTarget) -> Bool {` | 1／1 |
| `reenterS2(returningTo` | 2／2 |
| `s1Machine.makeS2ReentryHandoff(for: target.rangeID)` | 1／1 |
| `cancelS2Handoff(virtualRangeID:` | 2／2 |
| `photoLibrary.existingAssetIdentifiers(` | 2／2 |
| `s3Groups = []\n        s3ReturnTarget = nil`（`installS1Session` 内） | 1／1 |
| `returnToConfirmation()` 体内 `s3ReturnTarget` | 0／0 |
| `reenterS2` 体内 `message`／`route`／`publishS1FeedbackEvent(`／`seenAssetIDsProvider` | 各 0／0 |
| `reenterS2` 体内 `reconcileS1WithPhotoLibrary()`／`photoLibrary.existingAssetIdentifiers(`／`currentSeenArchive().seenAssetIDs`／`continuationsByRangeID[target.rangeID]?.currentAssetID`／`s1Machine.makeS2Handoff(`／`s1Machine.makeS2ReentryHandoff(for: target.rangeID)`／`enterS2(from: handoff)`／`s1Machine.cancelS2Handoff(virtualRangeID: target.rangeID)` | 各 1／1 |
| 既有钉子 `installS1Session(` 6、`recordSeenAssets(` 4、`flushSeenArchive()` 4、`photoLibrary.s1RangeRead(` 2、`publishS1FeedbackEvent(.submissionUnavailable)` 4、`S0Tab` 0、原文 `return "` 0 | 全相符 |
| B：`if route == .confirmation, sessionStore == nil, s1Machine == nil {` | A 后 0、B 后 1／1，且在 `handleS3Return` 内先于 `let sessionReturn = SessionStore.S3Return(` |
| B：`enterS1ResumingPersistedSessionOrStartNew()` | A 后 2、B 后 3／3（定义 + 启动授权后 + 本卡） |
| `handleS3Return` 切片顺序（A）：`let sessionReturn = SessionStore.S3Return(` → `route = .upstream` → `s3ReturnTarget = nil` → `reenterS2(returningTo: target)` | 成立 |

状态机：`func makeS2ReentryHandoff(for rangeID: String) -> S1ToS2Handoff? {` 1／1、`makeS2ReentryHandoff(` 1／1、其体内 `makeS2Handoff(for: rangeID)` 1／1、`sessionStore.continuationsByRangeID[rangeID]?.currentAssetID` 1／1、`handoff.orderedAssetIDs.contains(resumedAssetID)` 1／1、`currentAssetID: resumedAssetID` 1／1、`publishSnapshotIfChanged()`／`activeVirtualRangeIDs`／`knownRangeNamesByID`／`seenAssetIDsProvider` 体内各 0／0；`func cancelS2Handoff(virtualRangeID: String) {` < `func makeS2ReentryHandoff(for rangeID: String)` < `func makeS3Submission()` 顺序成立；既有钉子 `publishSnapshotIfChanged()` 6、`seenAssetIDsProvider?() ?? []` 4、`didSet` 4、`setMarked(` 3、`applyPendingDeletionDiff(` 3、`presentedYearRangeID` 7 全相符。

存档输出：`scratchpad/ic194-exec/countsA.txt`（A tip，53 条 ok）、`countsB.txt`（B tip，54 条 ok）、`countsC.txt`（C tip，54 条 ok），三份末行 `FAILS 0`。**说明一处我自己脚本的错**：A 的第一次提交前运行里有 1 条 FAIL（"returnTarget before guard applyS2ExitPayload (first occurrences)"），是我的检查写成了在全文件里取第一处 `guard applyS2ExitPayload(payload) else {`，而该字面量在别的函数里也出现，作用域没限定到 `enterConfirmationFromS2`…`enterConfirmationFromS1(` 切片（测试 F 的 `assertOrder` 就是限定在切片内的）；我用一段独立脚本在切片内复核了同一顺序（成立），并把检查改成切片作用域，之后三次重跑全部 0 FAIL。产品文件与 `stages/` 里的文件都没有改动。

## 五、`check_ic194.py` 三段 SUMMARY 与摘取实测

`check_ic194.py` 在刚提交的 tip 上跑（基线取脚本默认值 `b3ebd43`；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `366a6a50dacf2377ee63a2ae637a1613f884c5d1` | `SUMMARY 4 pass / 4`（blob 2 + `changed paths == whitelist (2)` + `base is ancestor`） | 0 |
| B | `a9877cde51e1600bfb002d28c5fabc3e12214e21` | `SUMMARY 4 pass / 4`（blob 2 + `changed paths == whitelist (2)` + `base is ancestor`；B 只改协调器一个文件，脚本按「累计至 B」核两个文件） | 0 |
| C | `da09a9435ab7085fd60a3a54ee327b0fea02885a` | `SUMMARY 7 pass / 7`（blob 5 + `changed paths == whitelist (5)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

**摘取关系实测**（克隆 `git clone --no-hardlinks` 到 scratchpad、命令全部 `git -C <克隆>`，从未落到原仓；克隆里从基线 `b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066` 各开一支 `cherry-pick -x`；只证文本无冲突，绿由 CI 证）：

| 组合 | 退出码 | 结果树 | 备注 |
|---|---|---|---|
| A 单独 | 0 | `1d6aca0840ec95bd135e67fa3823874769b2d5d9` | 改 2 个文件（协调器、S1 状态机）；与分支上 A 提交的树相同。按卡面 W3：A 单独摘走须同带 IC168 那一行，否则 `testIC168BCD_NewSymbolsAreWired` 红 |
| B 单独 | 0 | 树只存在于已删除的克隆里（A 之外的 B 单独树，未写入原仓，所以不列 SHA；克隆里 `git diff --name-only` 只列协调器一个文件） | 改 1 个文件（协调器）；单独摘 B 时协调器里没有 A 的符号（`S3ReturnTarget`／`s3ReturnTarget`／`reenterS2`／`makeS2ReentryHandoff` 在 B-only 文本里各为 0 的核对由卡面预演给出，我只实测了 cherry-pick 干净） |
| A → B | 0 | `67f51cf0235653588faace5c864c22e796e970f1` | 与分支上 B 提交的树相同 |
| B → A | 0 | `67f51cf0235653588faace5c864c22e796e970f1` | 与 A → B 同一棵树（两种顺序一致） |
| A → B → C | 0 | `30ea3dfb04b847beadfc1a3e2a86543403956bce` | 与分支 tip C 的树、合并提交的树相同；改 5 个路径 |

## 六、本地门禁（三个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 用 `powershell -NoProfile -ExecutionPolicy Bypass -File …`（Windows PowerShell 5.1，在 PowerShell 工具里取 `$LASTEXITCODE`）在仓库根跑；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0（「结构自验通过」，扫描 71 个测试源文件） | 0（目录条目 289、产品源码引用 key 289、用户可见硬编码残留 0） | 0 |
| B | 0（71 个测试源文件） | 0（289／289／0） | 0 |
| C | 0（扫描 72 个测试源文件，含新测试文件；「结构自验通过」） | 0（289／289／0） | 0 |

## 七、验收门禁逐条（G1065～G1069）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1065 行为与落位 | 满足 | 第五节：`check_ic194.py` A、B、C 三个 tip 全 PASS |
| G1066 新断言与随改断言 | 满足 | 六条 `testIC194*` 全部 passed（第九节）；`IC168FallbackDiagnosticsTests`（6 条）、`IC157LongPressIntoS2Tests`（8 条）、`IC188SeenSwitchTests`（6 条）、`IC190LegacyRetirementTests`（5 条）、`IC187SeenArchiveTests`（4 条）、`IC170S1FirstReadTests`（6 条）、`IC191DeckDataTests`（4 条）在 #392 与 #393 的整包日志里按唯一 Test Case 行数全部 passed |
| G1067 不回退 | 满足 | `S3ReturnRouteTests`（5 条）、`FullFlowRoutingTests`（6 条，其中 `testIC048_004S1AndS2TrashPassMergedSetAndGroupsToS3`／`testIC048_005S3BackIntersectsEveryRangeAndReturnsToS1`／`testIC048_006S5ExitEndsSessionAndRebuildsS1Session` 在 #392 分别 0.032／0.083／0.021 s、#393 0.023／0.796／0.086 s 均 passed）、`IC132SubmissionDeadEndTests`（5 条）、`IC131S1WriteBackToastTests`（5 条）在两次日志里全部 passed |
| G1068 合并前置 | 满足 | G1065～G1067 + CI #392 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 2031842 字节与 SHA-256、分段耗时 notice；摘要 978 与 xcodebuild 小计 978 一致，无需按第 217 条第四节另核）+ 39 条被保护分支 tip 未变（第十一节，推送前、合并前、合并后各核一次）+ pbxproj 撞号扫描（第十节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote origin refs/heads/main` 仍为 `b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066`） |
| G1069 合并后 | 满足 | 合并后 `main` CI #393 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #392 | 合并后 `main` 运行 #393 |
|---|---|---|
| run id | `37964461543` | `37966179688` |
| 被测提交 | `da09a9435ab7085fd60a3a54ee327b0fea02885a` | `3920cd74279b76cca3f4b912f48513a616fe0a76` |
| 触发 | push 到 `feature/ic-194-s3-return-landing` | push 到 `main` |
| 作业起止 | 2026-10-09T17:11:08Z～17:23:00Z | 2026-10-09T17:25:37Z～17:41:22Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 978 项，0 失败（xcodebuild `Executed 978 tests, with 0 failures (0 unexpected) in 52.196 (55.726) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 978 passed／0 failed） | 978 项，0 失败（`Executed 978 tests, with 0 failures (0 unexpected) in 54.364 (59.950) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 978 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 978 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 978 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`） | 0（同） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2031842 字节，SHA-256 `b48d05f0f75f2fb6876efbed91e65d924d232a09d28461a8c3a7dae66b0cdffd` | 2031842 字节，SHA-256 `e7087a845d87c06ce4a3f0866182504f63734459f7e97c6898c026681fd6d1db`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 88 s；xcodebuild test 381 s；总 470 s` | `模拟器启动 94 s；xcodebuild test 581 s；总 678 s` |
| artifact | `PhotoCleanupMVE-unsigned-da09a9435ab7`，id `11632919837`，2032012 字节，有效期至 2027-01-07T17:11:09Z | `PhotoCleanupMVE-unsigned-3920cd74279b`，id `11633209923`，2032012 字节，有效期至 2027-01-07T17:25:37Z |
| 六条 `testIC194*` 用例耗时（日志 `Test Case … passed (N seconds)`） | A `testIC194A_RealRangeReturnReentersS2AtLeftAsset` 0.017 s；B `testIC194B_CategoryRangeReentryKeepsListDropsDeletedAndFallsBack` 0.008 s；C `testIC194C_OtherSourcesLandUpstreamAndReentryHandoffGuards` 0.012 s；D `testIC194D_ReturnThroughS5ConfirmationStillReentersOriginalS2` 0.035 s；E `testIC194E_ColdStartRestoredS5ReturnResumesS1` 0.015 s；F `testIC194F_SourceWiring` 0.312 s | A 0.016 s；B 0.015 s；C 0.019 s；D 0.035 s；E 0.008 s；F 0.273 s |

- 两次构建日志里没有任何一条 warning／error 指向 `CleanupCoordinator.swift`、`S1StateMachine.swift`、`IC194S3ReturnLandingTests.swift`、`IC168FallbackDiagnosticsTests.swift`（整包日志逐行扫描：全部 `.swift` warning 47 行，均不在这四个文件）；没有出现类型检查超时、result builder 报错或扫描器红。测试 D 的 `waitUntil` 闭包读主 actor 属性没有触发并发警告。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）：`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` #392 6.408 s、#393 6.347 s，均 passed；两次日志里 `building pipeline` 均 0 次。两次日志各有两行 `Errors found! Invalidating cache...`，都落在 `IC175SimilarRecognizerTests.testIC175C_ObservationArchiveRoundTripKeepsDistanceZero` 用例块内（#392 1.262 s、#393 1.823 s，均 passed），与本卡无关。
- CI 预算 3 次，用了 1 次（#392）；#393 为合并后 `main` 运行，不计入试错预算。

## 九、六条新断言与随改的既有断言

**六条新断言（`PhotoCleanupMVETests/IC194S3ReturnLandingTests.swift`，逐字节拷入，blob `ff3620d978b337bb9343a97440f292a220702b5d`，655 行）**

| 断言 | 函数名 | 内容（据卡面 C 节） |
|---|---|---|
| A | `testIC194A_RealRangeReturnReentersS2AtLeftAsset` | 「范围-月」进 S2 标 D、C 停在 B，待删篮进 S3，记下落点（`isVirtual` false）；S3 里移出 D、返回 → 路由 `.s2`、同一范围、起点 B（第一张没看过的是 A）、`D` = {C}、落点清空；再从 S2 返回 → `.s1` |
| B | `testIC194B_CategoryRangeReentryKeepsListDropsDeletedAndFallsBack` | `cat:screenshot` 长按进 S2、标「中」到「小」，进 S3 记落点（`isVirtual` true、在途集合已空）；「小」被删后返回 → 列表 [大, 中, 微]、起点回退到第一张没看过的「大」、显示名「屏幕截图」、重新登记在途；再标「大」到「中」、进 S3 返回 → 起点 = 离开时那张「中」；全被删后返回 → 留 `.upstream`、无 S2、无在途 |
| C | `testIC194C_OtherSourcesLandUpstreamAndReentryHandoffGuards` | S1 提交路径不记落点、返回落上游；S2 记下的落点被随后 S1 侧进 S3 抹掉；裸状态机上重进交接：无此范围 nil、无 `K` 取第一张没看过的、有 `K` 取 `K` 且列表／待删／显示信息／会话标识与进入交接相同、`K` 不在范围里回退、遮挡时 nil |
| D | `testIC194D_ReturnThroughS5ConfirmationStillReentersOriginalS2` | 同步 `@MainActor`，`waitUntil` 转主线程 run loop：S2 待删篮进 S3、等扫描结论落定后提交删除、删除桩回报用户取消 → S5 已取消态；落点仍在；「返回确认页」后仍在；返回 → 重进「范围-月」、起点 B、`D` = {D, C} |
| E | `testIC194E_ColdStartRestoredS5ReturnResumesS1` | 隔离持久层预存 S1 会话档与「已取消」完成档，`start()` 落 `.completion` 且无会话；「返回确认页」→ 返回 → `.s1`、恢复同一会话与 `T`／`O`、S5 档已清；无 S1 会话档时开新会话、默认 `T`／`O` |
| F | `testIC194F_SourceWiring` | 协调器与状态机的计数、顺序与五个切片，全产品只有协调器与状态机提到重进交接、只有协调器提到落点、只有 `S3View` 调 `coordinator.leaveConfirmation()` |

**随改的既有断言（1 处）**：`IC168FallbackDiagnosticsTests.testIC168BCD_NewSymbolsAreWired` 协调器表 `("cancelS2Handoff(virtualRangeID:", 1)` → `2`（并在其上加一行注释：写回失败回落一处 + S3 返回重进 S2 失败撤销一处）；App 表不动。`git diff` 恰这两行加一行注释（`+2／−1`）。

**项数对账**：972 + 6 = **978**；#392 与 #393 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行数三者都是 978。

## 十、pbxproj 撞号扫描与两个新 id

- 推进前扫描：基线 `project.pbxproj` 全文 `100000000000000000000096`、`200000000000000000000093` 出现 0 次；基线最大号 fileRef `100000000000000000000095`、buildFile `200000000000000000000092`（IC-193）。
- 子项 C 提交前：`git diff` 恰四行新增——`PBXBuildFile` `200000000000000000000093`（`fileRef = 100000000000000000000096`）、`PBXFileReference` `100000000000000000000096`、测试组 children 一行、测试 Sources 阶段一行；`PBXBuildFile`／`PBXFileReference` 共 283 条定义，重复 id 列表 `[]`；新 id 在全文各出现 3 次（fileRef：定义 + buildFile 引用 + 测试组）与 2 次（buildFile：定义 + Sources 阶段）。
- 两个新 id：fileRef `100000000000000000000096`、buildFile `200000000000000000000093`。

## 十一、G1068 被保护分支核对

清单 `Tasks/decision-tools/ic194_protected_branches.txt` 恰 39 行（`分支名 SHA`）。对 `git ls-remote --heads origin` 逐条比对三次：推送前（远端 112 个 head）、CI 绿后合并前（113 个，多出本卡分支）、合并后（113 个）——**不符 0 条**；三次的 `ls-remote` 都是第一次返回即非空，没有拿空列表当比对。合并后 `main` = `3920cd74279b76cca3f4b912f48513a616fe0a76`。

## 十二、规格欠账与已知遗留（卡面七条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S1 修订）

1. `src3` 规格列五种取值，实装只记「S2(r)」一种（协调器的 `s3ReturnTarget`），其余四种回原页靠既有保留状态（年页身份与展开态在 S1 状态机、类别页身份在 S0 流程模型、tab 在 App）——S1 v13 改写取值集合为「S2(r) 或上游」（计划裁定 6）。
2. 第 4 部分「返回落点」第 6 项「按 v11 现行回上游」：v11 现行此路径实为返回钮无反应（源码推得，③ 真机未取证），实装先恢复 S1 会话档、无档开新，落 `.s1`（与 `.upstream` 同一界面分支）；规格改写为「装上 S1 会话后回上游」。
3. 同项：来源会话不可得，不写交集（S3 内的移除不回写 `M`）——规格未写，补一句。
4. 真实范围重进前多一次对账（一次 `R(T)` 读取；对账会静默剔除已不在库中的待删资产，S3 里最后看到的集合与重进后 S2 的 `D` 可能少几张——规格第七节第 4 部分对 S3 返回没写对账）；重进成功时 `.upstream` 在同一次同步调用里被 `.s2` 覆盖，IC-185 tab 时间线不多出 `route=upstream`（③，复核 W1 订正计划裁定 9），重进失败留在上游时才有。
5. 第 1 项重进时 `S2StateMachine` 构造不过（标定参数无效）也留在上游、不提示——规格第 5 项只写了 `A` 为空。
6. `cat:` 重进的显示名取进 S3 前那次交接的显示名（不重新查类别名）。
7. `cat:` 重进时 `A'` 全部看过取第一张（真实范围「全看过取首元素」在 SPEC-S1 v12 `:673` 有写，`cat:` 在 SPEC-S0 v6 第十节第 1、6 部分与 SPEC-S1 v12 第七节第 4 部分第 1 项都没写）。

另（复核只记不定的产品问题，卡里已自行取定、待 Lynn 拍板，记入交接包「待 Lynn」，我只转述）：Q1 冷启动恢复后经确认页返回不回写 S3 内的移除；Q2 重进失败静默留上游；Q3 重进前同步对账的大库耗时未测（③）；Q4 tab 落点不在本卡修（归 H98 第 5 条修法卡）。

## 十三、docs 提交与最终核验

- 惯例 44：本报告与 `change-list.md` 随合并与合并后 `main` 运行之后的**恰一个 docs 提交**落在 `main` 上（仅 `Reports/IC-194/` 两个文件，`Reports/**` 命中 `ci.yml` 的 `paths-ignore`，该提交不触发 CI）。
- 报告写完后，对报告里出现的每个 40 位 SHA 跑了 `git cat-file -t`：结果见本文末「报告内 SHA 核验」。

## 十四、人工判定项（保留给 Lynn 真机判定，执行端不代为下结论）

H102 八条（装合并后 `main` 运行 #393 的包 `PhotoCleanupMVE-unsigned-3920cd74279b`；装过 #385 或更新的包就不要回装 #383 及更旧的包——IC-190 起写出的会话档旧构建读不了）：

1. 「逐张整理」进某个月的看图，上滑标几张、停在某一张，点右上待删篮进确认页，再点返回：回到刚才那个月的看图、停在离开时那张；中间不闪列表页。
2. 同上，在确认页先移出一两张再返回：移出的那几张在看图里不再显示已标记，其余仍是已标记。
3. 接着从看图返回：回到最初进看图的那一页（列表页或年页，年页展开的还是那张），已看与待删已更新。
4. 「空间清理」类别页长按一张进看图，标几张，右上待删篮进确认页再返回：回到同一个类别的看图、照片顺序与进确认页之前一样、停在离开时那张；在确认页移出一张再返回，那张在看图里不再显示已标记、仍在列表里；再返回回到类别页。
5. 从列表页、年页顶排，或「空间清理」首页、类别页的待删篮入口进确认页，返回：回原页（不进看图）。
6. 经看图进确认页 → 删除 → 系统弹窗点「不允许」→ 结果页「返回确认页」→ 返回：仍回到那个看图。
7. 在第 6 条的结果页（取消）直接杀掉 App 再打开 → 落在结果页 →「返回确认页」→ 返回：回到「逐张整理」（不再卡在确认页按返回没反应）。
8. 以上返回后落在哪个 tab：从「逐张整理」出发的是否仍在「逐张整理」、从「空间清理」出发的是否仍在「空间清理」（本卡不修 tab，落错请复制 S2 标定面板末段诊断文本，供 H98 第 5 条修法卡）；一两句总评。

以上八条我都没有做，也不替 Lynn 下结论；夹具驱动的测试（`IC194S3ReturnLandingTests` A～E）只验路由与状态，手势、界面过渡（确认页回到看图是否闪列表页）、tab 落点真机未覆盖。

## 十五、发现但未处理的问题（按纪律只报告不修）

1. 无产品或卡面缺陷发现。所有执行中的偏差只有一处，且是我自己检查脚本的问题（第四节说明），产品文件与 `stages/` 未受影响。
2. 提示词里的 `sim_ic194.py`（`IC194_GATES=1 IC194_CLONE=1`）我没有跑——它只对基线跑且会重写 `decision-tools/sim194/`；等价的本地门禁与摘取实测由我自己的命令完成（第五、六节）。决策会话若要 sim 输出存档，需要自己跑。
3. 卡「事实基础」表里"协调器 +87 行"含 A 的 82 行与 B 的 5 行（`git diff --numstat` 基线..C：87），与卡一致；新测试文件实测 655 行（复核报告里记的"648 行"是改前版本）。非缺陷，仅备查。

## 报告内 SHA 核验

两份报告里出现的全部 40 位 SHA（去重后 19 个，正则按前后非十六进制字符取，SHA-256 与 blob 哈希中的子串不会被误取）逐个跑 `git cat-file -t <sha>`，退出码全 0，缺失 0 个：

| SHA | 对象类型 | 退出码 |
|---|---|---|
| `366a6a50dacf2377ee63a2ae637a1613f884c5d1` | commit | 0 |
| `a9877cde51e1600bfb002d28c5fabc3e12214e21` | commit | 0 |
| `da09a9435ab7085fd60a3a54ee327b0fea02885a` | commit | 0 |
| `3920cd74279b76cca3f4b912f48513a616fe0a76` | commit | 0 |
| `b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066` | commit | 0 |
| `30ea3dfb04b847beadfc1a3e2a86543403956bce` | tree | 0 |
| `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76` | commit | 0 |
| `0cdb6c0df6eda43e2ff4f4d91cc63ebcd4bf6d1b` | blob | 0 |
| `55f599914c2096fa614b5a7ae78e9f7b22452f26` | blob | 0 |
| `756660c8ed29bea218c02a032c5ae3510501282f` | blob | 0 |
| `53fd4c93ad4c563ba9444bf79e378276f68e1886` | blob | 0 |
| `1d6aca0840ec95bd135e67fa3823874769b2d5d9` | tree | 0 |
| `67f51cf0235653588faace5c864c22e796e970f1` | tree | 0 |
| `7fd3c8f6f9e157fd47ed5111ce546180f6adbd54` | blob | 0 |
| `d252a22096d3d2bae1905dfffa366d182ffda3f2` | blob | 0 |
| `b872f1420b6de2dc82504467143b02abd0e0a00d` | blob | 0 |
| `a6907640369fa549c8bb9d91419d75291d678e5e` | blob | 0 |
| `3692f42b302941e82a61dd0edc856151dd5ddae2` | blob | 0 |
| `ff3620d978b337bb9343a97440f292a220702b5d` | blob | 0 |
