# IC-199 自验报告

## 一、结论（先行）

- **三个子项全部按卡面完成（逐字节拷入 `ic199/stages/`，未手改一行），G1090～G1094 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-199-s2-sort-menu-ui`：A `53297b54fc7cf57310105dfa99c95e67bdeb14c7` → B `df1a5c5cff83181b86e9effd2d61329cc32b7538` → C `f574705bfca77b58d681c2668798683ea08dd7b9`。
- 分支 CI **#402**（run `38005645824`，被测提交 C `f574705bfca77b58d681c2668798683ea08dd7b9`）一次绿：**991 项 0 失败**（988 + 3），`xcodebuild` 输出 `Executed 991 tests, with 0 failures` 与 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0；日志 `XCTest 已全部通过。`），目的地 `OS:26.2, name:iPhone 16`。IPA 2091641 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `71a58366f2225759133a327cff2e0f4405f9c010`（双亲 `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5`／`f574705bfca77b58d681c2668798683ea08dd7b9`，树 `4e38e2312f518aa6ffb019dcfcb3b772592ce045` 与 C 提交的树相同）。合并后 `main` CI **#403**（run `38006618952`）绿：991 项 0 失败，artifact `PhotoCleanupMVE-unsigned-71a58366f222`（id `11652300415`，有效期至 2027-01-07T23:53:47Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 1 个、B 2 个、C 3 个），卡面测试 C／IC198E 涉及的计数与工作树实测逐条相等（A 提交前看图页作用域全部相符，B 提交前 57 项检查 0 处不符，C 提交前 21 项检查 0 处不符）；提交后 `check_ic199.py` A／B／C 三个 tip 全 PASS（3／3、5／5、8／8）。
- **有界面变化，人工判定项 H104 十五条保留给 Lynn 真机判定（第十一节原样转录），执行端没有做任何真机或观感判断。**
- 本次没有停卡项，没有执行端偏离卡面的改动，**分支推送与 `main` 推送都没有被分类器拦截**（均 git 直连、第一次即成功），没有任何一次 CI 红。红因清单 (1)(2)(3) 点名的编译风险（`Menu` 的 `label` 里放信息胶囊、`Picker` 的 `Binding(get:set:)`、`State(initialValue:)`、`S2TopBarLayout` 子视图数、协调器 `[weak self]` 闭包、测试的 `@MainActor` 与两个 internal 夹具）一项都没触发：两次整包日志里 swift error 行 0 条，`warning:` 行里指向本卡改动的三个产品文件与两个测试文件的只有 `S2View.swift:456`（既有的 `S2ShareContinuationResumer` 捕获告警，基线同一行 `guard resumer.claim() else {`，不在本卡改动行内）。
- 脚本：`materialize_ic199.py`、`gen_ic199_card.py` 未跑（明令不跑）；`sim_ic199.py` 只对基线跑了一次（默认模式，`FAILURES 0`，XCTest 988 → 991，pbx 新 id 十六进制下一个空号）；本地门禁与摘取实测我用自己的命令在真实提交上做了（第五、六节）。`Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（脚本一律 `python -B`，`find -name __pycache__` 为空）；我的临时脚本与日志全部在 scratchpad `ic199-exec/`。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-199-s2-sort-menu-ui.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-199.md`；拆卡与取定 `Tasks/PLAN-S2S-sort-menu-rulings-20261009.md`（第四之二节是本卡、第三节是已合并的 E1）；复核结论 `Tasks/REVIEW-IC-199-findings.md`（已读第五节「决策会话处置」；复核员的「建议改法」不作指令，改法以卡与 `stages/` 为准）。`CLAUDE.md` 随会话上下文完整载入。
- 继承提交 / 基线：`main` = `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5`（IC-198 报告补记；merge `d78102252ba8ceee4d6a9f603bd540f619576b5e`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor d78102252ba8ceee4d6a9f603bd540f619576b5e main` 退出码 0；`git ls-remote origin refs/heads/main` = `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5`；五个被改文件基线 blob 与卡面表逐个相等（`project.pbxproj` `95ae00e06df79d9570f813fdcf2cdb9f3030d4c3`、`CleanupCoordinator.swift` `073ff965e2aad6c6252c0d843494ecc54834c8eb`、`PhotoCleanupMVEApp.swift` `b2e74f33f82b436ce5845c2d3ff7345ac080ed5b`、`S2View.swift` `703d1c63fe6d44f4078863ab7635ffbfcf7e42a5`、`IC198S2SortOrderLogicTests.swift` `5b806744a7f5bc03dc8b6033e1f8549652c07871`）；先切分支再改文件（`git checkout -b` 之后才拷入第一个文件）。
- 目标分支：`feature/ic-199-s2-sort-menu-ui`，合并入 `main`。
- 范围边界：白名单 6 路径，`git diff --name-only 4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5..f574705bfca77b58d681c2668798683ea08dd7b9` 恰这 6 行。`S2StateMachine.swift`、`S2NativePhotoPager.swift`、`S1StateMachine.swift`、`S1PageHeader.swift`、`Localizable.xcstrings`（目录条数不变，仍 293）、全部其它既有测试、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）、`Scripts/`、`.github/` 一字未动。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `53297b54fc7cf57310105dfa99c95e67bdeb14c7` | `cfe01f4b65c6863285858bab5f985f1a8d981744` | `S2View.swift`（+86／−11）：`S2SortMenu`／`S2SortMenuMetrics`、末位形参 `sortMenu`、`topCenterCapsule`、主行日期改具体动态色并加下箭头、横栏 `stripSyncedRevision` 与新 `.onChange`。1 个路径 |
| B | `df1a5c5cff83181b86e9effd2d61329cc32b7538` | `425ca8db7c565871ced347e7fdde4c3eaab02c32` | `CleanupCoordinator.swift`（+19）：`makeS2SortMenu()`；`PhotoCleanupMVEApp.swift`（+3／−1）：`s2Screen` 末位实参。2 个路径 |
| C | `f574705bfca77b58d681c2668798683ea08dd7b9` | `4e38e2312f518aa6ffb019dcfcb3b772592ce045` | 新测试 `IC199S2SortMenuWiringTests.swift`（+436，三条）+ `IC198S2SortOrderLogicTests.swift`（+6／−2，测试 E 一处钉子）+ `project.pbxproj`（+4）。3 个路径 |
| 合并 | `71a58366f2225759133a327cff2e0f4405f9c010` | `4e38e2312f518aa6ffb019dcfcb3b772592ce045` | `merge(IC-199): S2 排序菜单界面层——中胶囊系统 Menu 与主行下箭头、横栏重排不滑行、协调器给菜单` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-199/` 两个文件） | — | 本报告与 `change-list.md` |

基线..C 合计 554 增 14 删（`git diff --numstat`：`project.pbxproj` 4／0、`CleanupCoordinator.swift` 19／0、`PhotoCleanupMVEApp.swift` 3／1、`S2View.swift` 86／11、`IC198S2SortOrderLogicTests.swift` 6／2、`IC199S2SortMenuWiringTests.swift` 436／0）。`S2View.swift` 现 6264 行，`CleanupCoordinator.swift` 现 1856 行。

## 四、逐子项提交前对读、拷入文件 `git hash-object`

脚本（scratchpad `ic199-exec/readback.py`、`readback_c.py`）：读工作树文件，用与测试 `stripped()` 同口径的剔注释、剔字符串字面量函数（直接 `import` 了 `Tasks/decision-tools/strip.py` 的 `strip_text`，只读）；`readback.py` 的计数表**从新测试文本里解析**（不手抄），按 `testIC199C_SourceWiring` 的六个作用域（看图页全文、`topBarRow`→`topCenterCapsule` 切片、`topCenterCapsule` 切片、`topInfoArea` 切片、`makeS2SortMenu` 切片、协调器／App 全文）逐条数，再数次序与「产品里只有谁提到」四组；`readback_c.py` 数 IC198E 的协调器计数表、`changeS2SortOrder` 切片、三组文件集合，并扫 pbx 十六进制 id。全部相符才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic199.py` 又用 git 对象核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE/Features/S2/S2View.swift` | `1f51e7e28419c12899ff1494420b400e0848e5f8` | `1f51e7e28419c12899ff1494420b400e0848e5f8` | 相等 |
| B | `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `83a88f01839b63352bfab97913d8e7ee909aa8d0` | `83a88f01839b63352bfab97913d8e7ee909aa8d0` | 相等 |
| B | `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `5e81a6de4a9270e00c39942aff5131f25a7e1629` | `5e81a6de4a9270e00c39942aff5131f25a7e1629` | 相等 |
| C | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `7cef47ff0c3a43fed291aa119b677925b012ead5` | `7cef47ff0c3a43fed291aa119b677925b012ead5` | 相等 |
| C | `PhotoCleanupMVETests/IC198S2SortOrderLogicTests.swift` | `e11760815007075500a2be375e610e6549aa2b56` | `e11760815007075500a2be375e610e6549aa2b56` | 相等 |
| C | `PhotoCleanupMVETests/IC199S2SortMenuWiringTests.swift` | `e1c5440635679a2ab3ac5bc6aff690610465743a` | `e1c5440635679a2ab3ac5bc6aff690610465743a` | 相等 |

每个子项拷入之后 `git status --porcelain` 只列该子项的文件（A：` M PhotoCleanupMVE/Features/S2/S2View.swift`；B：` M …/CleanupCoordinator.swift`、` M …/PhotoCleanupMVEApp.swift`；C：` M PhotoCleanupMVE.xcodeproj/project.pbxproj`、` M PhotoCleanupMVETests/IC198S2SortOrderLogicTests.swift`、`?? PhotoCleanupMVETests/IC199S2SortMenuWiringTests.swift`），按清单逐个 `git add <路径>`（未用 `-A`）。

**子项 A 提交前计数实测**（`S2View.swift`，剔注释与字符串；每行「实测／卡面」，0 处不符；作用域外的协调器与 App 项此时尚未改，按预期不计）

| 检查 | 实测／卡面 |
|---|---|
| 全文：`struct S2SortMenu {`、`let currentOrder: () -> S1SortOrder`、`let changeOrder: (S1SortOrder) -> Bool`、`enum S2SortMenuMetrics {`、`private let sortMenu: S2SortMenu?`、`sortMenu: S2SortMenu? = nil`、`self.sortMenu = sortMenu`、三个 `S2SortMenuMetrics.chevron*`、`@State private var stripSyncedRevision: Int`、`_stripSyncedRevision = State(initialValue: machine.orderedListRevision)`、`let reordered = machine.orderedListRevision != stripSyncedRevision`、`animated: !reordered`、`.onChange(of: machine.orderedListRevision) { _, revision in`、`.onChange(of: machine.currentIndex) {`、`.onChange(of: machine.orderedAssetIDs.count) {` | 各 1／1 |
| 全文：`topCenterCapsule`；`machine.orderedListRevision` | 2／2；4／4 |
| `topBarRow` 切片：`topCenterCapsule\n`；`topInfoArea`；`.onLongPressGesture(` | 1／1；0／0；1／1；次序 `topCenterCapsule` < `.frame(maxWidth: .infinity, maxHeight: .infinity)` < `.onLongPressGesture(` 成立 |
| `topCenterCapsule` 切片：`if let sortMenu {`、` Menu {`、`Picker(`、`get: { sortMenu.currentOrder() }`、`set: { _ = sortMenu.changeOrder($0) }`、`.tag(S1SortOrder.newestFirst)`、`.tag(S1SortOrder.oldestFirst)`、`.accessibilityHint(` | 各 1／1 |
| 同切片：`S1PageHeaderPresentation.sortTitle(`；`topInfoArea\n`；`.s2ChromeCapsuleGlass()`；`onLongPressGesture` | 2／2；2／2；2／2；0／0 |
| `topInfoArea` 切片：`if sortMenu != nil {`；`.foregroundStyle(S2ChromeForeground.onGlassPrimary)`；`.foregroundStyle(.primary)`；`HStack(spacing: S2SortMenuMetrics.chevronSpacing) {` | 1／1；1／1；0／0；1／1；次序 `Text(verbatim: dateText)` < `if sortMenu != nil {` < `Text(verbatim: S2TopBarInfoPresentation.subtitleText(` 成立 |
| 横栏两个回调体：`currentIndex` 回调内次序 `let reordered = ` < `stripSyncedRevision = machine.orderedListRevision` < `motion.synchronize(` < `animated: !reordered` | 成立 |
| `orderedListRevision` 回调体内：`stripSyncedRevision = revision`；`motion.synchronize(`；`animated:` | 1／1；1／1；0／0 |
| 产品全局：含 `orderedListRevision` 的文件；含 `changeS2SortOrder(` 的文件 | `S2StateMachine.swift`＋`S2View.swift`；仅 `CleanupCoordinator.swift`（**A 单独时 IC198E 的第二组期望只有 `S2StateMachine.swift`，A 之后必红——卡面已写明，C 才随改**） |

**子项 B 提交前计数实测**（A 的各项同样复核仍相符，`readback.py` 全量 57 项 `ok`、0 项 `DIFF`）：

| 检查 | 实测／卡面 |
|---|---|
| 协调器：`func makeS2SortMenu() -> S2SortMenu? {` | 1／1 |
| `makeS2SortMenu` 切片（`func makeS2SortMenu() -> S2SortMenu? {` → `func changeS2SortOrder(to newValue: S1SortOrder) -> Bool {`）内：`guard route == .s2,`；`!s1Machine.activeVirtualRangeIDs.contains(entryContext.rangeID)`；`[weak self]`；`self?.s1Machine?.sortOrder ?? .newestFirst`；`self?.changeS2SortOrder(to: newValue) ?? false` | 1／1；1／1；2／2；1／1；1／1 |
| App：`sortMenu: coordinator.makeS2SortMenu()`；`changeS2SortOrder(` | 1／1；0／0 |
| 产品全局：含 `return S2SortMenu(` 的文件；含 `makeS2SortMenu(` 的文件；含 `orderedListRevision` 的文件；含 `changeS2SortOrder(` 的文件 | 仅 `CleanupCoordinator.swift`；`CleanupCoordinator.swift`＋`PhotoCleanupMVEApp.swift`；`S2StateMachine.swift`＋`S2View.swift`；仅 `CleanupCoordinator.swift` |

**子项 C 提交前计数实测**（IC198E 作用域）：

| 检查 | 实测／卡面 |
|---|---|
| 协调器全文：`func changeS2SortOrder(to newValue: S1SortOrder) -> Bool {`；`switchSortOrder(`；`reorderAssets(`；`s2EntryContext = ` | 1／1；2／2；1／1；4／4（`makeS2SortMenu()` 插在 `enterS2` 与 `changeS2SortOrder` 之间，未改变这些计数） |
| `changeS2SortOrder` 切片（起点 `func changeS2SortOrder(` 全文唯一 1 处）内十二项（十条各 1、`recordSeenAssets(` 与 `flushSeenArchive()` 各 0） | 全部 1／1 与 0／0 |
| 产品全局：含 `changeS2SortOrder(` 的文件；含 `orderedListRevision` 的文件；含 `reorderAssets(` 的文件 | 仅协调器；`S2StateMachine.swift`＋`S2View.swift`（C 随改后的期望）；`S2StateMachine.swift`＋`CleanupCoordinator.swift` |
| pbx：对象定义行 328 条（IC-198 报告记 326，+2），重复 id 0；最大号 fileRef `10000000000000000000009D`、buildFile `20000000000000000000009A` | 见第十节 |
| 新文件 `func test*` 3 条；全部测试目录 `func test` 行（grep 口径）991 | 988 + 3 = 991 |

`git diff --cached --check` 三个提交各自提交前退出码 0。

## 五、`check_ic199.py` 三段 SUMMARY 与摘取实测

`check_ic199.py` 在刚提交的 tip 上跑（基线取脚本默认值 `4ceb27d`，`IC_REPO` 不需要——仓库在默认路径，`python -B`，在 `Tasks/decision-tools/` 里运行；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `53297b54fc7cf57310105dfa99c95e67bdeb14c7` | `SUMMARY 3 pass / 3`（blob 1 + `changed paths == whitelist (1)` + `base is ancestor`） | 0 |
| B | `df1a5c5cff83181b86e9effd2d61329cc32b7538` | `SUMMARY 5 pass / 5`（blob 3 + `changed paths == whitelist (3)` + `base is ancestor`） | 0 |
| C | `f574705bfca77b58d681c2668798683ea08dd7b9` | `SUMMARY 8 pass / 8`（blob 6 + `changed paths == whitelist (6)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

**摘取关系实测**（克隆 `git clone --no-hardlinks` 到 scratchpad `ic199-exec/clone`，克隆成功；命令全部带 `git -C <克隆>`，从未落到原仓；克隆里自基线 `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5` 起 `checkout -B`，对我的真实三个提交 `cherry-pick -x`；只证文本无冲突，绿由 CI 证；克隆里的新提交 SHA 不属于原仓，故不写入本报告）：

| 组合 | 退出码 | 结果树 | 备注 |
|---|---|---|---|
| A 单独 | 0 | `cfe01f4b65c6863285858bab5f985f1a8d981744` | 与分支上 A 提交的树相同；`git status --porcelain` 空；改动路径 1 个；**未推 CI（IC198E 此时必红，卡面已写明）** |
| A → B | 0 | `425ca8db7c565871ced347e7fdde4c3eaab02c32` | 与分支上 B 提交的树相同；`git status --porcelain` 空；改动路径 3 个；未推 CI（同上） |
| A → B → C | 0 | `4e38e2312f518aa6ffb019dcfcb3b772592ce045` | 与分支上 C 提交的树、合并提交的树相同；`git status --porcelain` 空；改动路径 6 个；该组合即推 CI 的 #402 |

## 六、本地门禁（三个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 在 PowerShell 工具里在仓库根跑（`& .\Scripts\….ps1`，取 `$LASTEXITCODE`）；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0 | 0（目录条目 293、产品源码引用 key 293、用户可见硬编码残留 0；「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） | 0 |
| B | 0 | 0（同） | 0 |
| C | 0（含新测试文件） | 0（同） | 0 |

## 七、验收门禁逐条（G1090～G1094）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1090 行为与落位 | 满足 | 第五节：`check_ic199.py` A、B、C 三个 tip 全 PASS |
| G1091 新断言 | 满足 | 三条 `testIC199*` 与 `testIC198E_SourcePlacement` 在 #402 与 #403 整包日志里全部 passed（第九节） |
| G1092 不回退 | 满足 | `IC198S2SortOrderLogicTests`（5）、`IC197GuideDWiringTests`（3）、`IC182TutorialRoundTwoTests`（3）、`IC172GlassAlwaysDarkTests`（7）、`IC141VideoPlaybackTests`（16）、`IC143VideoPolishTests`（13）、`IC151AmbientFixedColorTests`（7）、`IC168FallbackDiagnosticsTests`（6）、`IC185NavigationMaintenanceTests`（5）、`S2CalibrationHarnessTests`（224）、`S2ActionBarWiringTests`（65）在 #402 与 #403 的整包日志里按唯一 Test Case 行数全部 passed、0 failed（两次逐类相同） |
| G1093 合并前置 | 满足 | G1090～G1092 + CI #402 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice；摘要 991 与 xcodebuild 小计 991 一致，无需按第 217 条第四节另核，唯一 Test Case 行 991 passed／0 failed，已开始 991 = 已结束 991）+ 44 条被保护分支 tip 未变（第十二节）+ pbxproj 撞号扫描（第十节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote --heads origin` 里 `main` 仍为 `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5`） |
| G1094 合并后 | 满足 | 合并后 `main` CI #403 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #402 | 合并后 `main` 运行 #403 |
|---|---|---|
| run id | `38005645824` | `38006618952` |
| 被测提交 | `f574705bfca77b58d681c2668798683ea08dd7b9` | `71a58366f2225759133a327cff2e0f4405f9c010` |
| 触发 | push 到 `feature/ic-199-s2-sort-menu-ui` | push 到 `main` |
| 作业起止 | 2026-10-09T23:41:24Z～23:51:43Z | 2026-10-09T23:53:47Z～2026-10-10T00:07:32Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 991 项，0 失败（xcodebuild `Executed 991 tests, with 0 failures (0 unexpected) in 56.814 (62.403) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 991 passed／0 failed，无「已开始未结束」） | 991 项，0 失败（`Executed 991 tests, with 0 failures (0 unexpected) in 59.448 (63.065) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 991 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 991 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 991 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`；日志 `XCTest 已全部通过。`） | 0（同） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；xcodebuild 匹配行 `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一两行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2091641 字节，SHA-256 `125ff6d3150e8354b84b7a9693c3baa7b769ba06d2ab64eee25661ffc61a5c45` | 2091641 字节，SHA-256 `709892fc0888e1498bc31d84cde3855ef8f3dbc42daaf9a470a39e671b1b47ed`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 58 s；xcodebuild test 377 s；总 435 s` | `模拟器启动 73 s；xcodebuild test 462 s；总 536 s` |
| artifact | `PhotoCleanupMVE-unsigned-f574705bfca7`，id `11651696286`，2091811 字节，有效期至 2027-01-07T23:41:24Z | `PhotoCleanupMVE-unsigned-71a58366f222`，id `11652300415`，2091811 字节，有效期至 2027-01-07T23:53:47Z |
| 三条 `testIC199*` 与 `testIC198E` 用例耗时（日志 `Test Case … passed (N seconds)`） | `testIC199A_CoordinatorMenuOnlyForRealRangesAndRoutesTheChoice` 0.008 s；`testIC199B_StripJumpsOnReorderAndStillAnimatesPaging` 0.002 s；`testIC199C_SourceWiring` 0.507 s；`testIC198E_SourcePlacement` 0.241 s | A 0.007 s；B 0.004 s；C 0.352 s；IC198E 0.251 s |

- 两次构建日志里 swift error 行 0 条；`warning:` 行里指向本卡改动文件的只有一条既有告警 `S2View.swift:456`（`S2ShareContinuationResumer` 捕获告警，基线同一行，不在本卡改动行内），没有类型检查超时、result builder 报错或扫描器红。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）：`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` #402 6.440 s、#403 6.490 s，均 passed；两次日志里 `building pipeline` 均 0 次，各有两行 `Invalidating cache`（出现在 `IC172GlassAlwaysDarkTests testIC172A_MaterialControlFollowsInterfaceStyle` 用例块内，该类 7 条均 passed，既有，与本卡无关）。
- CI 预算 3 次，用了 1 次（#402）；#403 为合并后 `main` 运行，不计入试错预算。

## 九、新断言

三条新断言（`PhotoCleanupMVETests/IC199S2SortMenuWiringTests.swift`，逐字节拷入，blob `e1c5440635679a2ab3ac5bc6aff690610465743a`，436 行）：

| 断言 | 函数名 | 内容（据卡面 C 节） |
|---|---|---|
| A | `testIC199A_CoordinatorMenuOnlyForRealRangesAndRoutesTheChoice`（`@MainActor`，隔离持久层） | 没有会话、在 S1 时 `makeS2SortMenu()` 为 nil；真实范围给菜单、取值最新在前；选最旧在前 → S1 `O` 改了、看图页 `[A, B, C, D]`、当前 D、版本号 1、取值随之现读；再选当前项被拒；回到 S1 时 nil；类别范围 nil |
| B | `testIC199B_StripJumpsOnReorderAndStillAnimatesPaging` | 真实 `S2StateMachine`（七张）+ `S2BottomStripMotionController`（手动帧驱动与测试时钟）+ 两个回调体的镜像：先 `currentIndex` 后版本号、先版本号后 `currentIndex` 两种先后都直接跳到新格位（`.idle`、追踪下标 5、展开度 1、帧驱动未启动）；之后翻页照旧带动画；横栏重建按构造时的版本号起算、第一次翻页照旧带动画；对照：重排时一律带动画即进入 `.settling` 滑行 |
| C | `testIC199C_SourceWiring` | 看图页的类型、形参、builder 与下箭头、`topBarRow` 只经 builder 且长按仍挂外层、`topCenterCapsule` 切片、主行次序与动态色、横栏两个回调体次序与计数；协调器 `makeS2SortMenu` 切片；App 一处实参、零 `changeS2SortOrder(`；产品里只有协调器构造菜单、只有协调器与 App 提到 `makeS2SortMenu(`、只有状态机与看图页提到 `orderedListRevision`、只有协调器提到 `changeS2SortOrder(` |

随改的既有断言：`IC198S2SortOrderLogicTests.testIC198E_SourcePlacement` 末段第二组「只有状态机提到 `orderedListRevision`」→「状态机与看图页」（+ 注释补一句），blob `e11760815007075500a2be375e610e6549aa2b56`；其余既有测试未改。

**项数对账**：988 + 3 = **991**；#402 与 #403 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行数三者都是 991；提交前本机新文件 `func test*` 3 条、测试目录 `func test` 行 991，与之相符（陷阱 22：本机 grep 只作差值预估）。

## 十、pbxproj 撞号扫描与两个新 id

- 推进前扫描：基线最大号 fileRef `10000000000000000000009C`、buildFile `200000000000000000000099`（IC-198；十六进制）。C 提交前对工作树 `project.pbxproj`：对象定义共 328 条（IC-198 报告记 326 条，+2 个新增），重复 id 0；最大号 fileRef `10000000000000000000009D`、buildFile `20000000000000000000009A`。
- 两个新 id 各自在全文的出现行数：`10000000000000000000009D` 3 行（定义 + buildFile 引用 + 测试组 children）、`20000000000000000000009A` 2 行（定义 + 测试 Sources 阶段）；基线里两者各 0 行；每个都只有 1 处定义。`IC199S2SortMenuWiringTests.swift` 全文 6 行（基线 0 行）。
- 两个新 id：测试 fileRef `10000000000000000000009D`／buildFile `20000000000000000000009A`（`IC199S2SortMenuWiringTests.swift`，接在 `IC198S2SortOrderLogicTests.swift` 之后）。

## 十一、人工判定项 H104（**保留给 Lynn 真机判定；执行端不代为下结论**）

装合并后 `main` 产物（`PhotoCleanupMVE-unsigned-71a58366f222`，id `11652300415`）。以下十五条原样转录自任务卡：

1. 进「逐张整理」任一月的看图：顶部中胶囊日期后面有个小下箭头；单击中胶囊弹出系统菜单两项「最新在前」「最旧在前」、当前项打勾（iPhone 浅色、深色系统各看一次——未定项 28）。
2. 看到第 3 张左右时选另一项：当前照片不动（换到新位置时可能闪一下占位——记现象）、副行「序号/总数」变成它在新顺序里的位置；之后左右滑按新顺序翻。
3. 底部横栏：选完后直接对准当前张，不从旧位置一路滑过来；之后翻页，横栏照旧有跟随动画。
4. 双指放大后再点菜单换顺序：照片回到 1x（若放大前界面是隐藏的、放大后单击显示过，界面可能随回 1x 收起——记现象）。
5. 返回「逐张整理」：范围列表与卡片按新顺序；再进同一范围，从（新顺序下）第一张没看过的开始。
6. 「空间清理」类别页长按进来的看图：中胶囊没有下箭头、单击不弹菜单（类别范围不出菜单，③ 待 Lynn）。
7. 长按中胶囊约 0.8 秒：仍出标定面板（若与菜单冲突——长按只弹菜单、或什么都不出——记现象，面板入口另议）。
8. 读屏（VoiceOver）：中胶囊念日期与序号、并提示「排序方式」；菜单两项可读可选。
9. 换顺序后立刻上滑标记一张、再返回：已标记照常进待删篮、返回没有任何失败提示。
10. 主行日期是白色（不是蓝色），按下中胶囊时整只胶囊的按压反馈与菜单弹出观感。
11. 当前是视频或实况照片时换顺序：照常显示与播放（换到新位置的那一页会重新加载——记现象）。
12. 换顺序后点右上垃圾桶进确认页、再返回：回到的看图页仍按新顺序、仍停在离开时那张。
13. 只有 1 张照片的范围（如某个只有一张的月）：选另一项什么都不发生、勾选不变（逻辑如此——记现象，待 Lynn 定是否要隐藏菜单）。
14. 没有拍摄日期的照片：主行不显示，下箭头随之不显示，中胶囊仍可单击弹菜单。
15. 总评一两句。

夹具只证回调写法与控制器的配合（陷阱 1）；菜单弹出、系统勾选、长按与菜单共存、分页器换页与重新取图、真实回调时序均未覆盖，归 H104。

## 十二、G1093 被保护分支核对

清单 `Tasks/decision-tools/ic199_protected_branches.txt` 恰 44 行（`分支名 SHA`，无注释行）。对 `git ls-remote --heads origin` 逐条比对三次：推送分支后 CI 期间（远端 118 个 head，含本分支）、合并前（118）、合并并推送 `main` 之后（118）——**不符 0 条（44／44 相等）**；比对脚本（scratchpad `cmp_protected.py`）遇空列表即断言失败（空列表不算比对），本次每次第一次返回即非空。合并前 `main` = `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5`，合并后 `main` = `71a58366f2225759133a327cff2e0f4405f9c010`（`git ls-remote` 复核一致）。

## 十三、规格欠账（卡面八条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S2 修订）

1. 菜单文案借 `s1.sort.accessibility`／`s1.sort.newest_first`／`s1.sort.oldest_first`（与「逐张整理」页头同一组件，不另立 `s2.*` key）。
2. 主行下箭头 `S2SortMenuMetrics` 字号 10、间距 4 卡内暂登；没有拍摄日期的资产主行不显示、箭头随之不显示（③）。
3. `cat:` 类别范围不出菜单（③ 待 Lynn——类别页进来的列表顺序由类别页定、与 `O` 无关）。
4. 长按 0.8 s 标定面板与系统 `Menu` 共存待真机（决策 58、v24 ③；冲突则面板改位）。
5. 横栏重排那次直接跳到新格位、不滑行（规格「滚到可见处」未说动画）。
6. 当前照片换到新下标时由新的页控制器显示、会重新取一次图，可能闪占位（③ 进 H）。
7. 菜单取值由闭包现读 S1 的 `O`（App 不随 `O` 重求值）。
8. 读屏：中胶囊以 `accessibilityHint` 提示「排序方式」、信息照旧由两行文字念出。

## 十四、docs 提交与最终核验

- 惯例 44：本报告与 `change-list.md` 随合并与合并后 `main` 运行之后的**恰一个 docs 提交**落在 `main` 上（仅 `Reports/IC-199/` 两个文件，`Reports/**` 命中 `ci.yml` 的 `paths-ignore`，该提交不触发 CI）。
- 报告写完后，对两份报告里出现的每个 40 位 SHA 跑了 `git cat-file -e <sha>^{<类型>}`：结果见本文末「报告内 SHA 核验」。

## 十五、发现但未处理的问题（按纪律只报告不修）

1. 摘取关系补充：A 让 `S2View.swift` 提到 `orderedListRevision`，IC198E 的文件集合期望在 A 单独与 A→B 时必红（卡面已写明，C 才随改）；B 用 A 的 `S2SortMenu` 类型，C 的测试用 A 与 B。克隆实测里 A 单独、A→B 自基线 `cherry-pick -x` 文本无冲突，但「只能连续」要靠卡面纪律，不能靠冲突来拦（与 IC-198 同类）。
2. 仓库里有两个先前就存在的 stash（`stash@{0}`、`stash@{1}`，均挂在 `feature/ic-067-screenshot-detection` 上），不是本卡产生的，未动。
3. 卡面已登记的 ③ 项与「只记不定」的产品问题（类别范围不出菜单、1 张范围选另一项无反应、没有拍摄日期的资产箭头随主行不显示而胶囊仍可点、长按与菜单共存）本卡均未改动，留待 H104 现象与 Lynn 裁定；执行端未对其下结论。
4. 工具备注（非缺陷）：分支推送、`main` 推送与合并都没有被分类器拒绝，也没有换过工具；`ls-remote` 每次第一次返回即非空（无 `schannel` 失败）。我起的两个 CI 轮询进程（`run_in_background`，各带 45 分钟上限）结束时均已退出，一个事件监视器已用 `TaskStop` 停掉。
5. 无产品或卡面缺陷发现。执行中没有偏离卡面的改动。

## 报告内 SHA 核验

两份报告里出现的全部 40 位 SHA（去重后 20 个；正则按前后非十六进制字符取，64 位的 SHA-256 不会被误取）逐个跑 `git cat-file -e <sha>^{<类型>}`，退出码全 0 才算通过（IPA 的 SHA-256 不是 git 对象，不在此表）：

| SHA | 对象类型 | `cat-file -e` 退出码 |
|---|---|---|
| `53297b54fc7cf57310105dfa99c95e67bdeb14c7` | commit | 0 |
| `df1a5c5cff83181b86e9effd2d61329cc32b7538` | commit | 0 |
| `f574705bfca77b58d681c2668798683ea08dd7b9` | commit | 0 |
| `71a58366f2225759133a327cff2e0f4405f9c010` | commit | 0 |
| `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5` | commit | 0 |
| `4e38e2312f518aa6ffb019dcfcb3b772592ce045` | tree | 0 |
| `d78102252ba8ceee4d6a9f603bd540f619576b5e` | commit | 0 |
| `95ae00e06df79d9570f813fdcf2cdb9f3030d4c3` | blob | 0 |
| `073ff965e2aad6c6252c0d843494ecc54834c8eb` | blob | 0 |
| `b2e74f33f82b436ce5845c2d3ff7345ac080ed5b` | blob | 0 |
| `703d1c63fe6d44f4078863ab7635ffbfcf7e42a5` | blob | 0 |
| `5b806744a7f5bc03dc8b6033e1f8549652c07871` | blob | 0 |
| `cfe01f4b65c6863285858bab5f985f1a8d981744` | tree | 0 |
| `425ca8db7c565871ced347e7fdde4c3eaab02c32` | tree | 0 |
| `1f51e7e28419c12899ff1494420b400e0848e5f8` | blob | 0 |
| `83a88f01839b63352bfab97913d8e7ee909aa8d0` | blob | 0 |
| `5e81a6de4a9270e00c39942aff5131f25a7e1629` | blob | 0 |
| `7cef47ff0c3a43fed291aa119b677925b012ead5` | blob | 0 |
| `e11760815007075500a2be375e610e6549aa2b56` | blob | 0 |
| `e1c5440635679a2ab3ac5bc6aff690610465743a` | blob | 0 |

核验结果：20 个 SHA，不通过 0 个。
