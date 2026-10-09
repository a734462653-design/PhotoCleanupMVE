# IC-191 自验报告

## 一、结论（先行）

- **三个子项全部按卡面完成（逐字节拷入 `ic191/stages/`，未手改一行），G1050～G1054 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-191-v1-deck-data`：A `a9aa59a2d11fb72f4dc07c6b33dc29f451e2b5b0` → B `0c6524a2c21787eb3b46cbac25b82acac9623055` → C `6c1ab23716d09651e1e298849bba351bcabf97df`。
- 分支 CI **#386**（run `37918785462`，被测提交 C `6c1ab23716d09651e1e298849bba351bcabf97df`）一次绿：**970 项 0 失败**（966 + 4），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 1998911 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `78983887aeaee2a239d07a29bb9efc37f2472056`（双亲 `618f30e2387fc2618ec7c34b077007d46fcd3c43`／`6c1ab23716d09651e1e298849bba351bcabf97df`，树 `f6affd83e019aae69d2fc44200f5dfa31e0ca779` 与 C 提交的树相同）。合并后 `main` CI **#387**（run `37920144916`）绿：970 项 0 失败，artifact `PhotoCleanupMVE-unsigned-78983887aeae`（id `11611583395`，有效期至 2027-01-07T10:51:22Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 9 个、B 5 个、C 2 个）、卡面 A、B「改后」计数与工作树实测逐条相等（A 段 28 条检查、B 段 25 条检查，0 处不符）；提交后 `check_ic191.py` A／B／C 三个 tip 全 PASS（12／14／15）。
- 本次没有停卡项，没有执行端偏离卡面的改动，没有被分类器拦截，没有中途中断。`sim_ic191.py` 与 `materialize_ic191.py` 都没有跑（前者卡面允许对基线跑、非必需，且会重写 `decision-tools/sim191/`；后者明令不跑）。`Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（`check_ic191.py` 一律 `python -B`，无 `__pycache__`；`gh_runs.py` 用 `GH_OUT` 指向 scratchpad）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-191-v1-deck-data.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-191.md`；调研 `Tasks/RESEARCH-S1R-3-v1-deck-facts.md`（Q1、Q4、Q6、Q7）；裁定 `Tasks/PLAN-S1R-3-rulings-20261009.md`；复核结论 `Tasks/REVIEW-IC-191-findings.md` 第三、四节（处置与第二轮）。
- 基线 `main` = `618f30e2387fc2618ec7c34b077007d46fcd3c43`（IC-190 报告补记；合并提交 `8ce8c48a11f6ac9ad249eece4d5ac77833e71218`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 8ce8c48a11f6ac9ad249eece4d5ac77833e71218 main` 退出码 0；`git ls-remote origin refs/heads/main` = `618f30e2387fc2618ec7c34b077007d46fcd3c43`（与本地一致）；被改 9 个文件基线 blob 与卡面表逐一相等（下表）；**先切分支再改文件**（`git checkout -b feature/ic-191-v1-deck-data`，此前本卡分支在本地与远端均不存在）。

| 路径 | 卡面基线 blob | 实测（`git hash-object`） |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `13feab7d6d13d2e855ebeb590af209b32326ac66` | 相等 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `ee16d563bd2ca20987b3af34a57bc154bfa74724` | 相等 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `f0ddd930adcaf1f99b0af1808c925309622be9e4` | 相等 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | `fab23ebaf50bf22c12207ca739b285efbe1a405c` | 相等 |
| `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `07989aca1e0e0f4610e033055be01f0b1f63c40b` | 相等 |
| `PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift` | `890044fee1e17d865f694a11ab065bde0219053e` | 相等 |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `9023acfd2c5a40d1d813a23d4d7fd358140fa0d5` | 相等 |
| `PhotoCleanupMVETests/IC189NewCountTests.swift` | `14904de5f6de651e0e6a53fd73f4ed7c991ef234` | 相等 |
| `PhotoCleanupMVETests/IC190LegacyRetirementTests.swift` | `6fb64711861ba5d09310e0f11d252b41e21d42fd` | 相等 |

- 范围边界：只做卡「本卡边界」三项（A 体积接线与页头数据、B 两页展开态、C 新测试 + pbx）。三个视图文件（`S1View.swift`、`S1DeckCards.swift`、`S1YearPageView.swift`）、目录 `Localizable.xcstrings`（`check_ic191.py` 的 `catalog blob unchanged` PASS）、协调器、扫描服务、数据源协议与桩、`Scripts/`、`.github/`、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）一字未动。
- 改法实施方式：`cp -r Tasks/decision-tools/ic191/stages/<子项>/. <repo>/`，每个子项拷入后对清单里该子项每个文件跑 `git hash-object`（读 `manifest.json` 与工作树的只读脚本），全部相等才逐个 `git add <路径>`（不用 `-A`）与提交；`git status --porcelain` 在 `add` 之前恰列该子项的文件（A 8 个 `M` + 1 个 `??`、B 4 个 `M` + 1 个 `??`、C 1 个 `M` + 1 个 `??`）。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `a9aa59a2d11fb72f4dc07c6b33dc29f451e2b5b0` | `cf627b9d7e3892b51ab5975474bd025ec4fc8678` | 体积接线与页头数据：状态机 `byteCountTableProvider`／`noteByteCountTableChanged()`／`headerSummary`、`S1RangeRow` 加 `byteCount`／`sharePercent`、新文件 `Core/S1HeaderSummary.swift`、App 在 `tabContainer` 的 `.onAppear` 接读口并在既有 `onSnapshotDidChange` 闭包末尾追加刷新；pbx 四行；五处既有钉子随改（9 个文件） |
| B | `0c6524a2c21787eb3b46cbac25b82acac9623055` | `87acbd4d7a93665d7d50b351d71e95bf05a7fb79` | 两页展开态：新文件 `Core/S1OpenCardState.swift`、状态机 `openCards`／`listCardRangeIDs`／`yearPageCardRangeIDs(of:)`／`openListCard`／`openYearPageCard`／`resolveOpenCards()`，`presentYearPage` 取初值、`dismissYearPage` 清年页、`ranges` 的 `didSet` 先核年页再回落；pbx 四行；两处既有钉子随改（5 个文件；依赖 A） |
| C | `6c1ab23716d09651e1e298849bba351bcabf97df` | `f6affd83e019aae69d2fc44200f5dfa31e0ca779` | 新测试 `IC191DeckDataTests.swift`（四条，逐字节拷入）+ pbx 四行（2 个文件；依赖 A、B） |
| 合并 | `78983887aeaee2a239d07a29bb9efc37f2472056` | `f6affd83e019aae69d2fc44200f5dfa31e0ca779` | `merge(IC-191): V1 卡片叠与页头的数据与接线——字节表读口与刷新、行体积与占比、页头派生、两页展开态` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-191/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --name-only 618f30e2387fc2618ec7c34b077007d46fcd3c43..6c1ab23716d09651e1e298849bba351bcabf97df` 恰 12 路径，全在白名单内（691 行增、15 行删）。分支推送一次成功（`git push -u origin feature/ic-191-v1-deck-data`，git 直连无需代理，无分类器拦截）；推 `main` 一次成功（`618f30e..7898388`）。

## 四、逐子项提交前对读与拷入文件 `git hash-object`

脚本 `scratchpad/ic191-exec/count_ab.py`：读工作树文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（`Tasks/decision-tools/strip.py` 只读导入），逐条数卡面「改后（剔注释）」段列出的计数。每个子项都是提交前跑、全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic191.py` 又用 `git rev-parse <tip>:<路径>` 核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `1a732088173928a5cbf918f626bde79081debe6e` | `1a732088173928a5cbf918f626bde79081debe6e` | 相等 |
| A | `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `b2e74f33f82b436ce5845c2d3ff7345ac080ed5b` | `b2e74f33f82b436ce5845c2d3ff7345ac080ed5b` | 相等 |
| A | `PhotoCleanupMVE/Core/S1HeaderSummary.swift` | `12b7cd928318bb7aa9af86376395dc15d91baeba` | `12b7cd928318bb7aa9af86376395dc15d91baeba` | 相等 |
| A | `PhotoCleanupMVE/Core/S1StateMachine.swift` | `075d0914ba4d1a2a8217767136364aba7f08f4ea` | `075d0914ba4d1a2a8217767136364aba7f08f4ea` | 相等 |
| A | `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `5d77efb866f5eb4537403c4265aeac0c85152c6f` | `5d77efb866f5eb4537403c4265aeac0c85152c6f` | 相等 |
| A | `PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift` | `2266a7e092d65f3b95cf26646796091ffe2d6f6d` | `2266a7e092d65f3b95cf26646796091ffe2d6f6d` | 相等 |
| A | `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `c3183deba33c2353c4955bf6287c3a5c09d59975` | `c3183deba33c2353c4955bf6287c3a5c09d59975` | 相等 |
| A | `PhotoCleanupMVETests/IC189NewCountTests.swift` | `124ce680013bb476bdc2aa5c50ab58c1fb2e3efb` | `124ce680013bb476bdc2aa5c50ab58c1fb2e3efb` | 相等 |
| A | `PhotoCleanupMVETests/IC190LegacyRetirementTests.swift` | `a09a31c97bde58899583dcbd5637c6eee4914011` | `a09a31c97bde58899583dcbd5637c6eee4914011` | 相等 |
| B | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `a474b9cfa44bdc8c619dc24661db3aff844a3516` | `a474b9cfa44bdc8c619dc24661db3aff844a3516` | 相等 |
| B | `PhotoCleanupMVE/Core/S1OpenCardState.swift` | `20dc6b0a5df240aeefeb4af69608f7e4c0b1dc92` | `20dc6b0a5df240aeefeb4af69608f7e4c0b1dc92` | 相等 |
| B | `PhotoCleanupMVE/Core/S1StateMachine.swift` | `756660c8ed29bea218c02a032c5ae3510501282f` | `756660c8ed29bea218c02a032c5ae3510501282f` | 相等 |
| B | `PhotoCleanupMVETests/IC178DeckListTests.swift` | `db7f7a63c6d54b1a04abb9043d99ef7dcc9326b0` | `db7f7a63c6d54b1a04abb9043d99ef7dcc9326b0` | 相等 |
| B | `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `36b8952e54cb0b1254f692134740f44d246b4db3` | `36b8952e54cb0b1254f692134740f44d246b4db3` | 相等 |
| C | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `ee6960429c947b7d0cd64bdca6cbb55af22c4ea7` | `ee6960429c947b7d0cd64bdca6cbb55af22c4ea7` | 相等 |
| C | `PhotoCleanupMVETests/IC191DeckDataTests.swift` | `14fe74ecf58a7f550628c4488113619e70377bd3` | `14fe74ecf58a7f550628c4488113619e70377bd3` | 相等 |

**子项 A「改后」计数（卡面 vs 工作树实测，提交前）**——28 条检查全相等（末行把五个并列的 0 计数合为一行）：

| 对象 | 计数项 | 卡面 | 实测 |
|---|---|---|---|
| 状态机（剔注释） | `var byteCountTableProvider: (() -> S1AssetByteCountTable?)?` | 1 | 1 |
| 同上 | `byteCountTableProvider?()` | 2 | 2 |
| 同上 | `func noteByteCountTableChanged() {` | 1 | 1 |
| 同上 | `objectWillChange.send()` | 1 | 1 |
| 同上 | `var headerSummary: S1HeaderSummary {` | 1 | 1 |
| 同上 | `table?.volume(of: range)` | 1 | 1 |
| 同上 | `rangeRows` 切片内 `byteCountTableProvider?()` | 1 | 1 |
| 同上 | `S1RangeRow` 切片 `let ` | 10 | 10 |
| 同上 | `seenAssetIDsProvider?() ?? []` | 4 | 4 |
| 同上 | `publishSnapshotIfChanged()` | 6（不变） | 6 |
| 同上 | `didSet` | 4（不变） | 4 |
| 同上 | `setMarked(` | 3（不变） | 3 |
| 同上 | `applyPendingDeletionDiff(` | 3（不变） | 3 |
| 同上 | `presentedYearRangeID` | 5（不变） | 5 |
| App（剔注释） | `s1Machine.byteCountTableProvider = {` | 1 | 1 |
| 同上 | `provider?.assetByteCountTable()` | 1 | 1 |
| 同上 | `noteByteCountTableChanged()` | 2 | 2 |
| 同上 | `assetByteCountTable` | 1 | 1 |
| 同上 | `S1AssetByteCountTable` | 0 | 0 |
| 同上 | `onSnapshotDidChange` | 1（不变） | 1 |
| 同上 | `advanceScan()` | 2（不变） | 2 |
| 同上 | `S0ScanOutcomeTransition.events(` | 1（不变） | 1 |
| `S1HeaderSummary.swift` | 原文 `import ` | 1 | 1 |
| 同上 | 剔注释 `Photos`／`PHAsset`／`S0`／`L10n.`／`@MainActor` | 各 0 | 各 0 |

**子项 B「改后」计数（卡面 vs 工作树实测，提交前）**——25 条检查全相等（末行把「产品里调两个写方法的文件」合为一行；`S1OpenCardState.swift` 的五个 0 计数合为一行）：

| 对象 | 计数项 | 卡面 | 实测 |
|---|---|---|---|
| 状态机（剔注释） | `let openCards = S1OpenCardState()` | 1 | 1 |
| 同上 | `openCards.setListRangeID(` | 2 | 2 |
| 同上 | `openCards.setYearPageRangeID(` | 5 | 5 |
| 同上 | `func openListCard(_ rangeID: String) -> Bool {` | 1 | 1 |
| 同上 | `func openYearPageCard(_ rangeID: String) -> Bool {` | 1 | 1 |
| 同上 | `private func resolveOpenCards() {` | 1 | 1 |
| 同上 | `resolveOpenCards()` | 2 | 2 |
| 同上 | `pruneYearPageIfNeeded()` | 2 | 2 |
| 同上 | `ranges` 的 `didSet` 里 `pruneYearPageIfNeeded()` 先于 `resolveOpenCards()` | 是 | 是 |
| 同上 | `didSet { pruneYearPageIfNeeded() }` | 0 | 0 |
| 同上 | `presentedYearRangeID` | 7 | 7 |
| 同上 | `didSet` | 4（不变） | 4 |
| 同上 | `publishSnapshotIfChanged()` | 6（不变） | 6 |
| 同上 | `setMarked(` | 3（不变） | 3 |
| 同上 | `applyPendingDeletionDiff(` | 3（不变） | 3 |
| 同上 | `seenAssetIDsProvider?() ?? []` | 4（A 后不变） | 4 |
| 同上 | `byteCountTableProvider?()` | 2（A 后不变） | 2 |
| `S1OpenCardState.swift` | 原文 `import ` | 2 | 2 |
| 同上 | 剔注释 `@Published private(set) var` | 2 | 2 |
| 同上 | 剔注释 `Photos`／`PHAsset`／`S0`／`L10n.`／`@MainActor` | 各 0 | 各 0 |
| 产品全部 `.swift`（剔注释） | 含 `setListRangeID(` 或 `setYearPageRangeID(` 的文件 | 恰 `S1OpenCardState.swift`、`S1StateMachine.swift` | 相同 |

子项 C 没有「改后」计数段；提交前核了拷入 blob（上表）、`git diff --cached --check`（退出码 0）、pbx 撞号扫描（第十二节）与本地门禁（第六节）。

## 五、`check_ic191.py` 三段 SUMMARY（提交后、进入下一子项之前对刚提交的 tip 跑；基线取脚本默认值 `618f30e`；FAIL 行：无）

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `a9aa59a2d11fb72f4dc07c6b33dc29f451e2b5b0` | `SUMMARY 12 pass / 12`（blob 9 + `changed paths == whitelist (9)` + `base is ancestor` + `catalog blob unchanged`） | 0 |
| B | `0c6524a2c21787eb3b46cbac25b82acac9623055` | `SUMMARY 14 pass / 14`（blob 11 + `whitelist (11)` + 2） | 0 |
| C | `6c1ab23716d09651e1e298849bba351bcabf97df` | `SUMMARY 15 pass / 15`（blob 12 + `whitelist (12)` + 2） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

## 六、本地门禁（三个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 用 `powershell -NoProfile -ExecutionPolicy Bypass -File …`（Windows PowerShell 5.1）在仓库根跑；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0（「结构自验通过」，扫描 68 个测试源文件） | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致」） | 0 |
| B | 0 | 0 | 0 |
| C | 0（扫描 69 个测试源文件，含新测试文件） | 0 | 0 |

## 七、验收门禁逐条（G1050～G1054）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1050 行为与落位 | 满足 | 第五节：`check_ic191.py` A／B／C 三个 tip 全 PASS |
| G1051 新断言与随改断言 | 满足 | CI #386 与 #387 的整包日志按唯一 Test Case 行数出 970 passed／0 failed；四条 `testIC191*` 与 `IC178DeckListTests`（5 条）、`IC184RetireCaliberEnumsTests`（3 条）、`IC186RangeVolumeInterfaceTests`（3 条）、`IC188SeenSwitchTests`（6 条）、`IC189NewCountTests`（5 条）、`IC190LegacyRetirementTests`（5 条）、`S1StateMachineTests`、`IC157LongPressIntoS2Tests`（8 条）、`IC153ScanServiceTests`（13 条）全部 passed |
| G1052 不回退 | 满足 | `IC178DeckListTests.testIC178B_YearPageIdentityLivesInMachineWithGuards`、`IC189NewCountTests.testIC189D_CoordinatorFeedsLeaveTimesFromSeenArchive`、`FullFlowRoutingTests.testIC048_006S5ExitEndsSessionAndRebuildsS1Session` 在 #386（0.002 s／0.003 s／0.020 s）与 #387（0.001 s／0.003 s／0.043 s）均 passed |
| G1053 合并前置 | 满足 | G1050～G1052 + CI #386 绿（见第八节：真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 1998911 字节与 SHA-256、分段耗时 notice；摘要 970 与 xcodebuild 小计 970 一致，无需按第 217 条第四节另核）+ 36 条被保护分支 tip 未变（第十一节）+ pbxproj 撞号扫描（第十二节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote origin refs/heads/main` = `618f30e2387fc2618ec7c34b077007d46fcd3c43`） |
| G1054 合并后 | 满足 | 合并后 `main` CI #387 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #386 | 合并后 `main` 运行 #387 |
|---|---|---|
| run id | `37918785462` | `37920144916` |
| 被测提交 | `6c1ab23716d09651e1e298849bba351bcabf97df` | `78983887aeaee2a239d07a29bb9efc37f2472056` |
| 触发 | push 到 `feature/ic-191-v1-deck-data`（2026-10-09T10:37:59Z 创建） | push 到 `main`（2026-10-09T10:51:22Z 创建） |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 970 项，0 失败（xcodebuild `Executed 970 tests, with 0 failures (0 unexpected) in 53.124 (55.401) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 970 passed／0 failed） | 970 项，0 失败（`Executed 970 tests, with 0 failures (0 unexpected) in 55.217 (66.186) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 970 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 970 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 970 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`；日志 `XCTest 已全部通过。`） | 0（同） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（`-destination "platform=iOS Simulator,id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8"`；日志另有 xcodebuild 警告 `Using the first of multiple matching destinations`，目的地已按 id 钉死） | 同一行 |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 1998911 字节，SHA-256 `2800c198383c2b51c487d740efba730350e7b18a553459a8a6b6d7b0d6080436` | 1998911 字节，SHA-256 `82ec2ec506416befbe6fc7b04fe9e010f5670ff369da0dee2b5d5c623750ede6`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 94 s；xcodebuild test 374 s；总 469 s` | `模拟器启动 106 s；xcodebuild test 561 s；总 669 s` |
| artifact | `PhotoCleanupMVE-unsigned-6c1ab23716d0`，id `11611391727`，1999081 字节，有效期至 2027-01-07T10:37:59Z | `PhotoCleanupMVE-unsigned-78983887aeae`，id `11611583395`，1999081 字节，有效期至 2027-01-07T10:51:22Z |
| 四条 `testIC191*` 用例耗时（日志 `Test Case … passed (N seconds)`） | A `testIC191A_RowVolumesFollowTheScanTable` 0.009 s；B `testIC191B_HeaderSummaryDerivesTotalSeenAndCounts` 0.001 s；C `testIC191C_OpenCardsFollowTheOpenRule` 0.001 s；D `testIC191D_SourceWiring` 0.223 s | A 0.008 s；B 0.001 s；C 0.006 s；D 0.214 s |

- `testIC063` 两次均未红（红因清单 (6) 未触发）。#387 的 xcodebuild 段（561 s）比 #386（374 s）长 187 s，两次的唯一 Test Case 行都是 970 passed，属 runner 耗时波动，未归因（③：同一代码树两次运行的差异，没有对应的测试内证据）。
- CI 预算 3 次，用了 1 次（#386）；#387 为合并后 `main` 运行，不计入试错预算。

## 九、四条新断言与随改的既有断言

**四条新断言（`PhotoCleanupMVETests/IC191DeckDataTests.swift`，逐字节拷入，blob `14fe74ecf58a7f550628c4488113619e70377bd3`）**

| 断言 | 函数名 | 内容 |
|---|---|---|
| 1 行体积与占比 | `testIC191A_RowVolumesFollowTheScanTable` | 树夹具五行：未注入读口全部未知；整表体积 `[600, 100, 500, 400, 400]`、占比 `[60, 10, 50, 40, 40]`；表里缺 a3a 时 3 月与 2026 年未知、其余照常（占比 `[nil, 17, nil, 50, 50]`）；读口给 nil 全部未知；刷新信号让状态机发布恰一次、不写快照 |
| 2 页头派生 | `testIC191B_HeaderSummaryDerivesTotalSeenAndCounts` | `S1HeaderSummary.make` 六种情形（按日期就绪、无表、未就绪、无范围、相册有表、相册无表）、`percent` 四例；状态机：看过集合与字节表从注入读口来、翻转排序不变、切相册维度 `U` 取表的键集、撤表后未知 |
| 3 展开态 | `testIC191C_OpenCardsFollowTheOpenRule` | 初值第一张、翻转排序不动、点卡改展开（状态机不发布、展开态对象发布恰一次、不写快照）、年页初值与点月卡、遮挡期间不收、对账后所指的卡仍在不变／月消失回落、返回清年页、下次推入按当时排序取初值、列表所指的年消失回落、切维度清空后取第一张相册、纯规则四例 |
| 4 源码落位 | `testIC191D_SourceWiring` | 子项 A、B「改后」计数与先后、行结构两列、`rangeRows` 只取一次表、`didSet` 先核年页、推入年页先写身份再取初值、App 接线与回调末尾刷新、协调器 `installS1Session(` 恰 6 与 `s1Machine = machine` 恰 1、两个 Core 新文件纪律、展开态写入方只有状态机 |

**随改的既有断言（均由 A、B 的拷入文件带入，未手改）**

| 文件 | 断言 | 旧 → 新 | 子项 |
|---|---|---|---|
| `IC184RetireCaliberEnumsTests` | `testIC184C` `S1RangeRow` 切片 `let ` | 8 → 10 | A |
| `IC184RetireCaliberEnumsTests` | `testIC184C` `presentedYearRangeID` | 5 → 7 | B |
| `IC186RangeVolumeInterfaceTests` | `testIC186C` App 一项 | 协议／桩／App 三路径 `assetByteCountTable`／`S1AssetByteCountTable` 各 0 → 协议与桩仍各 0；App `assetByteCountTable` 1、`S1AssetByteCountTable` 0 | A |
| `IC188SeenSwitchTests` | `testIC188F` `seenAssetIDsProvider?() ?? []` | 3 → 4 | A |
| `IC189NewCountTests` | `testIC189E` 同上 | 3 → 4 | A |
| `IC190LegacyRetirementTests` | `testIC190E` 同上 | 3 → 4 | A |
| `IC178DeckListTests` | `testIC178D` `presentedYearRangeID` | 5 → 7 | B |
| `IC178DeckListTests` | `testIC178D` `didSet { pruneYearPageIfNeeded() }` | 1 → 0，改为 `pruneYearPageIfNeeded()` 2、`resolveOpenCards()` 2 | B |

项数对账：`966 + 4 = 970`（CI 的 `Executed 970 tests`，唯一 Test Case 行 970）。

## 十、摘取关系实测

克隆：`git clone --no-hardlinks D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE <scratchpad>/ic191-exec/clone`，克隆成功（退出码 0）后才开始；所有命令带 `git -C <克隆>`；克隆里每个单元先 `checkout -B pick-* 618f30e2387fc2618ec7c34b077007d46fcd3c43` 再 `cherry-pick -x`，原仓没有建任何其它分支。克隆沿用全局提交身份配置，未动原仓配置。

| 单元 | 命令 | 退出码 | 结果树 |
|---|---|---|---|
| A 单独 | `cherry-pick -x A` | 0 | `cf627b9d7e3892b51ab5975474bd025ec4fc8678`（= A 提交的树，改动 9 路径） |
| A→B 连续 | `cherry-pick -x A`、`cherry-pick -x B` | 0、0 | `87acbd4d7a93665d7d50b351d71e95bf05a7fb79`（= B 提交的树，改动 11 路径） |
| A→B→C 连续 | `cherry-pick -x A`、`B`、`C` | 0、0、0 | `f6affd83e019aae69d2fc44200f5dfa31e0ca779`（= C 提交的树 = 合并提交的树，改动 12 路径） |
| B 单独（卡面声明会冲突，只作对照） | `cherry-pick -x B` | 1（冲突，随即 `--abort`） | — |

克隆实测只证文本无冲突，与卡「摘取关系」节一致（A 单独可摘、只能 A→B、C 依赖 A 与 B）；绿由 CI 证（#386 是 A→B→C 连续序列的绿，A 单独与 A→B 的绿未单独跑 CI）。

## 十一、G1053 被保护分支核对

`Tasks/decision-tools/ic191_protected_branches.txt`（36 行 `分支名 SHA`、无注释行，只读）对 `git ls-remote --heads origin` 逐条比对，比对脚本在 scratchpad（读清单、读 ls-remote 输出，不写清单）：

- 推送分支之前第一次核：checked 36、mismatch 0（远端 109 个分支）。
- 合并前再核（分支 CI 绿之后）：checked 36、mismatch 0（`main` 仍为 `618f30e2387fc2618ec7c34b077007d46fcd3c43`，本卡分支为 `6c1ab23716d09651e1e298849bba351bcabf97df`）。
- 合并推送之后又核：checked 36、mismatch 0（`main` 为 `78983887aeaee2a239d07a29bb9efc37f2472056`，本卡分支仍为 `6c1ab23716d09651e1e298849bba351bcabf97df`）。

三条冻结分支与其余被保护分支 tip 均未变。

## 十二、pbxproj 撞号扫描与六个新 id

- 对象定义行（`24 位 id /* … */ = {`）去重扫描（C 提交后的 `project.pbxproj`）：定义 310、唯一 310，重复 0。
- 六个新 id 出现次数：fileRef `100000000000000000000090`（`S1HeaderSummary.swift`）3、`100000000000000000000091`（`S1OpenCardState.swift`）3、`100000000000000000000092`（`IC191DeckDataTests.swift`）3（定义 + 组 children + buildFile 引用）；buildFile `20000000000000000000008D`、`20000000000000000000008E`、`20000000000000000000008F` 各 2（定义 + 源码阶段）。与卡面一致：基线最大号 fileRef `10000000000000000000008F`／buildFile `20000000000000000000008C`，本卡之后最大号为 `100000000000000000000092`／`20000000000000000000008F`。
- `git diff --cached --check` 三个提交均 0。

## 十三、规格欠账（卡面六条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S1 修订）

1. `页头已看` 的 `U` 取法：按日期维度就绪取年范围资产之并（规格定义原样），其余维度取字节表键集（规格「形成方式由实装定」），两者都取不到为「未知」（规格未写此时显示什么；显示归 ③b，裁定 G4 按「统计中」同式）。
2. `总占用` 取字节表内之和（IC-186 欠账照旧）。
3. 刷新频率：扫描服务每次快照通知（≤4 Hz，含扫描中表一直为 nil 的阶段）都让 S1 重读一次，S1 在前时整页重算一次 `rangeRows` 与 `headerSummary`；本卡界面不读新字段，成本先到、收益随 ③b／③c 到；真机若觉卡顿，在 App 侧收窄（不放进 `noteByteCountTableChanged()` 本体），并要求 ③b／③c 视图一次 `body` 只取一次 `rangeRows`／`headerSummary`（③）。
4. `占比(r)`：规格 `:261` 只写「`总占用` 未知时不显示」，本卡在 `总占用` 已知但范围里有表外资产使 `体积(r)` 未知时占比位也不显示（裁定 2）。
5. `open`：`R(T)` 归空（切 `T`、重试、读取失败）也算一次替换：期间为 nil，读到新范围取第一张，切走再切回旧值不复活（裁定 4）。
6. `页头已看` 在按日期维度加载中为「未知」，即使字节表已就绪也不改取表的键集。

## 十四、人工判定项

无（不做界面；S1 视图一字未动）。

## 十五、docs 提交与最终核验

- docs 提交只含 `Reports/IC-191/self-check.md` 与 `Reports/IC-191/change-list.md`（惯例 44：合并与合并后 `main` 运行之后追加，纯 `Reports/**` 提交不触发 CI，预期行为）。
- docs 提交前已对本报告与 `change-list.md` 出现的全部 40 位 SHA 跑 `git cat-file -e <sha>^{<类型>}`，结果见 `change-list.md` 末节「核验结果」；docs 提交之后补跑 `check_ic191.py <docs 提交> docs`，结果在回传的回报里给出（docs 提交自身的 SHA 不写进报告）。

## 十六、发现但未处理的问题（按纪律只报告不修）

1. **成本先到、收益后到（卡首已登记，规格欠账 (3)）**：本卡之后每次扫描快照通知都会让 S1 重算 `rangeRows`（表就绪后每次多 2N 次字典查找）与 `headerSummary`，界面还没有读这些字段；这是欠账而非缺陷，③b／③c 接界面时要求视图一次 `body` 只取一次。
2. `noteByteCountTableChanged()` 在 App `.onAppear` 内发布 `objectWillChange`（接上即刷新一次）：卡面已说明依据（容器出现之前已完成的那一遍不会再通知）；CI 两次全绿，没有观察到问题，真机观感未覆盖（本卡无界面，也无人工判定项）。
3. 本机 `core.autocrlf` 为 `true`，`.gitattributes` 对 `*.swift`／`*.pbxproj` 设 `eol=lf`；拷入文件 `git hash-object`（经清洗过滤）与清单逐一相等，未出现行尾转换问题。
4. #387 的 xcodebuild 段比 #386 长 187 s（见第八节），未归因；两次均未触发 `testIC063` 红因。
5. 分支推送、合并、合并推送均一次成功，未遇分类器拦截，也未遇 `schannel` 握手失败；合并用 Bash 的 `git merge --no-ff`，未换工具。
6. `sim_ic191.py` 未跑（允许但非必需）；`IC191_GATES=1`／`IC191_CLONE=1` 两个选项的等价检查由执行端自己完成（本地门禁第六节、克隆摘取第十节）。
