# IC-179 自验报告

## 一、结论（先行）

**已合并、已推送、合并后运行绿。** 分支 `feature/ic-179-inline-hints` 三个子项各自独立提交 A→B→C，一次推送后 CI **#362 绿 925／0**；G993 全部满足后 `--no-ff` 合并入 `main`（合并提交 `ae26e20cdda6b09a8ea57eb4e53742374560cf0d`）并推送，合并与推送各一次通过、未被分类器拦；合并后 `main` 自动运行 **#363 绿 925／0**。CI 预算 1／3（分支一次绿）。

- 子项 A～C 的全部改法逐字取自任务卡代码块：执行端脚本从卡面取出 35 个代码块（A 八个 text + 一个 json、B 十八个 swift、C 八个 text），与 `Tasks/decision-tools/ic179_edits.py` 的 `EDITS` 逐对比较，18 处全部相同；每个锚句在当时工作树上恰 1 处，数对后才替换（单点替换，逐个在内存中顺序套用）。
- 两个拷入文件逐字节拷入（`cp`），`git hash-object` 实测等于卡面：`S2InlineHints.swift` = `3cf6195bb0dc6f731ebaabd31f9288f7342509b4`，`IC179InlineHintsTests.swift` = `cf1956472d752810e8b689d50bfdea24e863298a`；未改任何一行。
- 每个子项提交前，改后计数与卡面「改后」逐条对读：A 41 行、B 113 行、C 113 行，**0 处不符**（第六节）。决策会话验收脚本 `check_ic179.py` 在三个提交上 A 113／113、B 113／113、C 114／114 全过。
- 九条新断言在 #362、#363 均 passed；卡面点名的八个既有测试类（含 `S2ActionBarWiringTests` 65 条，其中 20 条旧教程测试）全部 passed；「不得打红」段两侧对象全部相同；`schemaVersion` 7、`S0DeckMetrics` 195、`s2.tutorial.` 10 条未变，目录 262 → 269。
- **新断言 1～7 是协调器夹具驱动**（陷阱 1）：三句的出现时机、6 s 限时收起、× 与随 chrome 显隐的观感、气泡落位是否避开中央指示，只能由 Lynn 在 H94 真机判定（第十六节），执行端不代为下结论。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260926-179-inline-hints.md` |
| 前置阅读 | `<top>/CLAUDE.md`；`Tasks/RESEARCH-IC-179-facts.md`（A、B、D 节）；`Tasks/REVIEW-IC-179-findings.md`（两轮：第一轮实质 3／行文 8，第二轮实质 1／行文 4，均已改入卡面） |
| 基线 `main`（开工时） | `c1003ea93b5bacda7b2dd6037bfc01a2d0e2e119` |
| 开工核对 1 | `git status --porcelain` 空 |
| 开工核对 2 | `git merge-base --is-ancestor 9bb803525f8186625322fecce02dc67d070409e7 main` 退出码 0 |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `c1003ea93b5bacda7b2dd6037bfc01a2d0e2e119`，与本地一致 |
| 开工核对 4 | 三个被改文件 blob 与卡面表逐个相等：`S2View.swift` `f18e7c0a5e0c79bf2137c17d57b680d1625a8dcd`、`Localizable.xcstrings` `3b37ae13fd2388501add289622277e449c2ad5e5`、`project.pbxproj` `8564645ba61b1732a9aee996ec866ff31cf33143` |
| 开工核对 5 | 两个待拷入源文件 `git hash-object` 与卡面相等（`3cf6195b…`／`cf195647…`） |
| 分支 | `feature/ic-179-inline-hints`，改任何文件前先 `git switch -c` 自基线切出 |
| 基线预演 | `python sim_ic179.py c1003ea…`（只对基线）退出码 0，`FAILURES 0 []`（该脚本会确定性重写 `Tasks/decision-tools/sim179/` 三个文件，见第十七节） |
| `schemaVersion` | 7（`S2Calibration.swift:118`，文件对象两侧相同） |
| `S0DeckMetrics` | 195（`S0DeckMetrics.swift` 对象两侧相同，只引用） |
| 文案目录 | 262 → 269（`s2.hint.` 0 → 7，`s2.tutorial.` 仍 10） |
| 合并 | `--no-ff`，合并提交 `ae26e20cdda6b09a8ea57eb4e53742374560cf0d`，父 `c1003ea93b5bacda7b2dd6037bfc01a2d0e2e119`（合并前 main）与 `3de160993edf5e3479de325d4d996735ea27743b`（分支 tip = C）；合并树 `5d484ae698ee400b088273604b1265f8c2828d55` = C 提交的树 |
| docs 提交（惯例 44） | 合并与合并后运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`） |
| 范围边界 | 只做卡内三项：新文件 + 七条 key + pbx 产品登记；`S2View.swift` 九处接线；新测试 + pbx 测试登记。旧六步教程的类型、`tutorialOverlay`、5 处事件调用、相簿 sheet 提示条、步骤 ⑥ 白底、`S2TutorialCompletionStore.swift`、十条 `s2.tutorial.*`、`S2ActionBarWiringTests` 一字未动；S1／S3／S4／S5／S0／App／Core／Services 未动 |

## 三、提交列表

| 子项 | 提交 SHA | 改动 |
|---|---|---|
| A | `831532bfc6dd62742743081506e980682575e737` | 新文件 `Features/S2/S2InlineHints.swift`（逐字节拷入）+ 目录七条 `s2.hint.*` + pbx 产品登记四行 |
| B | `09d83b1b5b4042747211d691f7118bedc58aa421` | `S2View.swift` 九处（B1～B9） |
| C | `3de160993edf5e3479de325d4d996735ea27743b` | 新测试文件（逐字节拷入）+ pbx 测试登记四行 |
| merge | `ae26e20cdda6b09a8ea57eb4e53742374560cf0d` | 首行 `merge(IC-179): 教程替换第一张——S2 三句就地提示各自记已会，六步教程停用不删` |

## 四、CI

| 项 | #362（分支 tip C） | #363（合并后 `main`） |
|---|---|---|
| run id | `36280860146` | `36281506459` |
| 被测提交 | `3de160993edf5e3479de325d4d996735ea27743b` | `ae26e20cdda6b09a8ea57eb4e53742374560cf0d` |
| 结论 | success（12 步全 success，attempt 1） | success（12 步全 success，attempt 1） |
| 执行摘要 notice | `Executed 925 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 925 tests / 0 failures` | 同左 |
| 整包日志唯一 Test Case 行 | 925 passed／0 failed（剔 `##[error]` 与 ANSI 回显后按单个整作业日志文件计） | 925 passed／0 failed（同口径） |
| 真实退出码 | 0（「运行 XCTest」步骤 success；工作流 `set -o pipefail` + `exit "$test_status"`；日志 `** TEST SUCCEEDED **`、`XCTest 已全部通过。`） | 0（同左） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左 |
| 分段耗时 notice | `模拟器启动 78 s；xcodebuild test 397 s；总 476 s` | `模拟器启动 74 s；xcodebuild test 294 s；总 370 s` |
| IPA 字节数 | 1949836 | 1949836 |
| IPA SHA-256 | `671c77b1eb7460023e97873cd900a7c0a86ae2e26e96a3272aa28da41c7ca5b2` | `b7cacb38cd9ed56ea68d70e77ad2968692c64591fd9527fbe6eaf06bff4929d3` |
| artifact | `PhotoCleanupMVE-unsigned-3de160993edf`，id 10919146149，1950006 字节，2026-12-25T23:54:09Z 到期 | `PhotoCleanupMVE-unsigned-ae26e20cdda6`，id 10918339086，1950006 字节，2026-12-26T00:06:49Z 到期 |
| `testIC063` | passed（6.207 s）；`building pipeline` 全日志 0 行；`IC063_WARMUP_GATE_END` 1 行；两行 `Invalidating cache` 落在该用例 `started` 之前 6 s（不在用例块内） | passed（6.188 s）；`building pipeline` 0 行；`IC063_WARMUP_GATE_END` 1 行；两行 `Invalidating cache` 同样在用例开始之前 |
| `testIC067G39` | passed（0.426 s） | passed（0.228 s） |

项数对账：916（基线合并后运行 #361）+ 0（A）+ 0（B）+ 9（C 新文件九条）= **925**（#362、#363）。

## 五、本地门禁（三个提交各一份，真实退出码）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A 提交前 | 0 | 0 | 0（新文件 `git add -N` 纳入） |
| B 提交前 | 0 | 0 | 0 |
| C 提交前 | 0 | 0 | 0（新文件 `git add -N` 纳入） |

selfcheck 末行均为「结构自验通过：……不少于 189 项测试的数量门禁均符合要求。」；needle 交叉审计扫描测试源文件数 A／B 55、C 56。扫描器末行均为「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」。

决策会话验收脚本 `check_ic179.py`（只读调用，`IC179_BASE=c1003ea…`）：提交前以临时索引构造的未挂引用提交各跑一次、提交后在真实提交上再跑一次，A 113／113、B 113／113、C 114／114，全过；C 段 changed paths 5。

## 六、子项计数实测表（卡面值 / 实测值；剔注释口径 = 测试 `strippedSource` 的 Python 移植 `decision-tools/strip.py`，切片口径同测试 `slice`／`onChangeBody`）

执行端脚本 `scratchpad/ic179-exec/counts_ic179.py`。A 提交（`831532b`）上 41 行、B 提交（`09d83b1`）上 113 行、C 提交（`3de1609`）上 113 行，**全部相符**。下表为 C 提交上的全表（A 行在 A、B 提交上同值，pbx 测试三行在 A／B 提交上为 0／0／0，同样与卡面相符）：

| 节 | 项 | 卡面值 | 实测值 | 相符 |
|---|---|---|---|---|
| A | 目录总数 | 269 | 269 | 是 |
| A | 目录 s2.hint. | 7 | 7 | 是 |
| A | 目录 s2.tutorial. | 10 | 10 | 是 |
| A | 新文件 Metrics 切片 `static let ` | 30 | 30 | 是 |
| A | 新文件剔注释 `S0DeckMetrics.` | 7 | 7 | 是 |
| A | 新文件剔注释 `.allowsHitTesting(false)` | 4 | 4 | 是 |
| A | 新文件剔注释 `Button {` | 1 | 1 | 是 |
| A | 新文件剔注释 `.frame(` | 8 | 8 | 是 |
| A | 新文件剔注释 `alignment: .trailing` | 2 | 2 | 是 |
| A | 新文件剔注释 `S2TutorialGestureHint(direction:` | 1 | 1 | 是 |
| A | 新文件剔注释 `static let confirmThreshold = 5` | 1 | 1 | 是 |
| A | 新文件剔注释 `static let markedOnceAutoDismissSeconds: TimeInterval = 6` | 1 | 1 | 是 |
| A | 新文件剔注释 `Material` | 0 | 0 | 是 |
| A | 新文件剔注释 `colorScheme` | 0 | 0 | 是 |
| A | 新文件剔注释 `Color(uiColor:` | 0 | 0 | 是 |
| A | 新文件剔注释 `@MainActor` | 0 | 0 | 是 |
| A | 新文件剔注释 `@Published private(set) var activeHint` | 1 | 1 | 是 |
| A | 新文件原文 `Text("` | 0 | 0 | 是 |
| A | 新文件原文 `return "` | 0 | 0 | 是 |
| A | 新文件原文 `import ` | 1 | 1 | 是 |
| A | 新文件原文 `"s2.hint.confirm"` | 1 | 1 | 是 |
| A | 目录 `"s2.hint.confirm" : {` | 1 | 1 | 是 |
| A | 新文件原文 `"s2.hint.confirm.sub"` | 1 | 1 | 是 |
| A | 目录 `"s2.hint.confirm.sub" : {` | 1 | 1 | 是 |
| A | 新文件原文 `"s2.hint.dismiss"` | 1 | 1 | 是 |
| A | 目录 `"s2.hint.dismiss" : {` | 1 | 1 | 是 |
| A | 新文件原文 `"s2.hint.marked"` | 1 | 1 | 是 |
| A | 目录 `"s2.hint.marked" : {` | 1 | 1 | 是 |
| A | 新文件原文 `"s2.hint.marked.sub"` | 1 | 1 | 是 |
| A | 目录 `"s2.hint.marked.sub" : {` | 1 | 1 | 是 |
| A | 新文件原文 `"s2.hint.swipe_up"` | 1 | 1 | 是 |
| A | 目录 `"s2.hint.swipe_up" : {` | 1 | 1 | 是 |
| A | 新文件原文 `"s2.hint.swipe_up.sub"` | 1 | 1 | 是 |
| A | 目录 `"s2.hint.swipe_up.sub" : {` | 1 | 1 | 是 |
| A | pbx 产品 fileRef 10…07A | 3 | 3 | 是 |
| A | pbx 产品 buildFile 20…077 | 2 | 2 | 是 |
| C | pbx 测试 fileRef 10…07B | 3 | 3 | 是 |
| C | pbx 测试 buildFile 20…078 | 2 | 2 | 是 |
| C | pbx IC179InlineHintsTests.swift 次数 == IC177UnifiedBackgroundTests.swift | 6 | 6 | 是 |
| A | pbx S2InlineHints.swift 次数 | 6 | 6 | 是 |
| B | S2View 剔注释 `S2InlineHintCoordinator(` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `S2UserDefaultsInlineHintStore()` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.startIfNeeded(` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.leaveScreen()` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.assetDidBecomeMarked()` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.assetDidBecomeUnmarked()` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.mergedCountDidChange(count)` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.confirmEntryTapped()` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.dismiss()` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.reset()` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hints.hintDidTimeOut(.markedOnce)` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `S2InlineHintCoordinator.markedOnceAutoDismissSeconds` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `inlineHintOverlay(` (基线 0) | 2 | 2 | 是 |
| B | S2View 剔注释 `S2InlineHintLayer(` (基线 0) | 1 | 1 | 是 |
| B | S2View 剔注释 `hintStore` (基线 0) | 0 | 0 | 是 |
| B | S2View 剔注释 `tutorial.startIfNeeded()` (基线 1) | 0 | 0 | 是 |
| B | S2View 剔注释 `tutorial.replay()` (基线 1) | 0 | 0 | 是 |
| B | S2View 剔注释 `tutorial.leaveScreen()` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `tutorial.assetDidBecomeMarked(assetID: assetID)` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `tutorial.assetDidBecomeUnmarked(assetID: assetID)` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `tutorial.assetDidJoinAlbum(assetID: record.assetID)` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `tutorial.albumPickerVisibilityDidChange(` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `tutorial.currentAssetDidChange(to:` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `tutorialOverlay(` (基线 2) | 2 | 2 | 是 |
| B | S2View 剔注释 `if tutorial.activeStep == .albumGuide {` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `final class S2TutorialCoordinator: ObservableObject {` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `enum S2TutorialStep: Int, CaseIterable, Equatable {` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `.onChange(of: machine.pendingDeletionAssetIDs) {` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `.onChange(of: machine.sessionMergedPendingDeletionCount) {` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `.onChange(of: machine.currentAssetID) {` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `.onChange(of: machine.interfaceVisibility) {` (基线 1) | 1 | 1 | 是 |
| B | S2View 剔注释 `@StateObject` (基线 13) | 14 | 14 | 是 |
| B | S2View 剔注释 `s2ChromeVisibilityTransition(` (基线 3) | 4 | 4 | 是 |
| B | S2View 剔注释 `Button {` (基线 8) | 8 | 8 | 是 |
| B | S2View 剔注释 `.allowsHitTesting(false)` (基线 9) | 9 | 9 | 是 |
| B | S2View 剔注释 `L10n.text(` (基线 124) | 124 | 124 | 是 |
| B | S2View 剔注释 `Material` (基线 6) | 6 | 6 | 是 |
| B | S2View 剔注释 `.background(.regularMaterial)` (基线 3) | 3 | 3 | 是 |
| B | S2View 剔注释 `GlassEffectContainer {` (基线 2) | 2 | 2 | 是 |
| B | S2View 剔注释 `s2ChromeGlassBackground(` (基线 6) | 6 | 6 | 是 |
| B | S2View 剔注释 `#available` (基线 3) | 3 | 3 | 是 |
| B | S2View 剔注释 `similarDiagnosticsSection` (基线 2) | 2 | 2 | 是 |
| B | S2View 剔注释 `exitDiagnosticsSection` (基线 2) | 2 | 2 | 是 |
| B | S2View 剔注释 `S2AmbientBackdropView()` (基线 1) | 1 | 1 | 是 |
| B | S2View 原文 `colorScheme, .dark)` | 6 | 6 | 是 |
| B | S2View 原文 `"s2.tutorial.replay"` | 1 | 1 | 是 |
| B | S2View 原文 `s2.calibration.similar_diagnostics.` | 3 | 3 | 是 |
| B | inlineHintOverlay 切片 `mergedCount: displayedPendingCount` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `.task(id: hint)` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `Task.isCancelled` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `s2ChromeVisibilityTransition(` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `S2OverlayLayout.topBarHeight` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `S2InlineHintLayer(` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `hints.dismiss()` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `hints.hintDidTimeOut(.markedOnce)` | 1 | 1 | 是 |
| B | inlineHintOverlay 切片 `S2InlineHintCoordinator.markedOnceAutoDismissSeconds` | 1 | 1 | 是 |
| B | S2View 全文件剔注释 `mergedCount: displayedPendingCount` | 1 | 1 | 是 |
| B | S2View 全文件剔注释 `.task(id: hint)` | 1 | 1 | 是 |
| B | S2View 全文件剔注释 `Task.isCancelled` | 1 | 1 | 是 |
| B | 计数回调体：喂入在残影守卫之前 | True | True | 是 |
| B | 标记回调体 `hints.assetDidBecomeMarked()` | 1 | 1 | 是 |
| B | 标记回调体 `hints.assetDidBecomeUnmarked()` | 1 | 1 | 是 |
| B | 标记回调体 `tutorial.assetDidBecomeMarked(assetID: assetID)` | 1 | 1 | 是 |
| B | topBarRow 切片 `hints.confirmEntryTapped()` | 1 | 1 | 是 |
| B | topBarRow 切片 `Button {` | 2 | 2 | 是 |
| B | topBarRow 切片 `.disabled(... || tutorial.isRunning)` | 1 | 1 | 是 |
| B | 垃圾桶 action：guard 在已会之前 | True | True | 是 |
| B | `machine.currentAssetID` 回调体改前后逐字相同（剔注释） | True | True | 是 |
| B | `machine.currentAssetID` 回调体 `hints` 次数 | 0 | 0 | 是 |
| B | `machine.interfaceVisibility` 回调体改前后逐字相同（剔注释） | True | True | 是 |
| B | `machine.interfaceVisibility` 回调体 `hints` 次数 | 0 | 0 | 是 |
| B | `machine.currentAssetID` 回调体改前后逐字相同（原文） | True | True | 是 |
| B | `machine.interfaceVisibility` 回调体改前后逐字相同（原文） | True | True | 是 |

`machine.currentAssetID` 与 `machine.interfaceVisibility` 两个 `.onChange` 回调体（取法同 IC141 `onChangeBody`：第一处匹配到下一个 `.onChange(`）在剔注释与原文两种口径下都与基线**逐字相同**（表末四行）。

## 七、两个拷入文件

| 文件 | 来源 | `git hash-object` 实测 | 卡面值 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2InlineHints.swift` | `<top>/Tasks/decision-tools/S2InlineHints.swift`（`cp`，`cmp` 相同） | `3cf6195bb0dc6f731ebaabd31f9288f7342509b4` | 相等 |
| `PhotoCleanupMVETests/IC179InlineHintsTests.swift` | `<top>/Tasks/decision-tools/IC179InlineHintsTests.swift`（`cp`，`cmp` 相同） | `cf1956472d752810e8b689d50bfdea24e863298a` | 相等 |

提交后 `git rev-parse 3de1609:<路径>` 同值。

## 八、闸门 G990～G994

| 闸门 | 结果 | 依据 |
|---|---|---|
| G990 协调器语义 | 满足 | `testIC179A`～`testIC179G` 七条在 #362／#363 均 passed |
| G991 持久化与文案 | 满足 | `testIC179H_UserDefaultsStoreRoundTripUsesPrefixedKeys` 两次 passed |
| G992 源码落位 | 满足 | `testIC179I_SourceWiringAndCatalog` 两次 passed；B 计数与卡面逐条相等（第六节）；`S2ActionBarWiringTests` 65／65、`IC172GlassAlwaysDarkTests` 7／7、`IC151AmbientFixedColorTests` 7／7、`IC141VideoPlaybackTests` 16／16、`IC143VideoPolishTests` 13／13、`IC146ChromeRoundTwoTests` 19／19、`IC168FallbackDiagnosticsTests` 6／6、`IC175SimilarRecognizerTests` 8／8 全部 passed（两次运行同） |
| G993 合并前置 | 满足 | G990～G992；`git diff --name-only c1003ea..3de1609` 恰 5 路径；「不得打红」段对象相同（第九节）；二十四条被保护分支 tip 未变（第十节）；#362 绿（退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice）；pbxproj 撞号扫描无撞号（第十一节）；工作树净；合并前 `ls-remote` 中 `main` 仍 `c1003ea…`（未被他人推进） |
| G994 合并后 | 满足 | `main` 运行 #363 绿 925／0；artifact `PhotoCleanupMVE-unsigned-ae26e20cdda6`，id 10918339086，2026-12-26T00:06:49Z 到期 |

## 九、「不得打红」段对象比对（基线 `c1003ea` vs C `3de1609`）

| 路径 | 基线对象 | C 对象 | 结论 |
|---|---|---|---|
| `PhotoCleanupMVE/Core` | `796859519b61fd2894ecbc13a4399e4398037f7c` | 同左 | 相同 |
| `PhotoCleanupMVE/Services` | `ae83298b1925e1defabbcf8a762a6ecd3032ba78` | 同左 | 相同（含 `S2TutorialCompletionStore.swift` `62b9a3589d12e6501865a3565e406395d545c5ed`） |
| `PhotoCleanupMVE/App` | `ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S0` | `498da0346fdb9a6a59db517425d4d97047bda033` | 同左 | 相同（含 `S0DeckMetrics.swift` `eb12a2e88190ab06546e7105bbb0a59d08d8ce99`） |
| `PhotoCleanupMVE/Features/S1` | `51f4c848fb59c821db3db0aa671fd898784ad2b4` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S3` | `be64dc867250a9edea24145b473b6bb8d25752a2` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S4` | `0d1c3618b0d435fad79067210205a0b8014d60cc` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S5` | `04022d74cb6422ae08a6597cf0b5d81fc31f01a0` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/Shared` | `ca567d006a536e637c0330f8af07bf8b4c0734d3` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `992816e511291a547d43d5baee4eeefdb5f2a858` | 同左 | 相同（`schemaVersion` 7）；`Features/S2/` 下除 `S2View.swift` 与新文件外 8 个文件逐个相同 |
| `.github` | `74088388c62a10eb277921ecf74e766a2d407e80` | 同左 | 相同 |
| `Scripts` | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同左 | 相同 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | `e933151a14a5bd771471e21347dd504541195209` | 同左 | 相同 |
| `PhotoCleanupMVETests/` 既有 55 个文件 | — | — | 逐文件相同；另新增 1 个（`IC179InlineHintsTests.swift`） |

## 十、被保护分支（24 条，开工时与合并前各 `ls-remote` 一次）

`Reports/IC-177/self-check.md` 第十节列名的 23 条 + `feature/ic-177-unified-background` `3cdae92`：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`、`feature/ic-169-marked-state-follows-basket` `bf9551e`、`feature/ic-175-similar-recognizer` `8d5bc7b`、`feature/ic-177-unified-background` `3cdae92`——**24／24 与远端头前缀相符**；合并前复查：全部远端 ref（共 99 行，除本分支外）与开工时逐行相同。

## 十一、pbxproj 撞号扫描与新 id

- 登记前重扫（24 位十六进制 id 按数值比）：1 号段最大 `100000000000000000000079`、2 号段最大 `200000000000000000000076`，与卡面一致；四个新 id 登记前出现 0 次，无撞号、未换号。
- 四个新 id：产品 fileRef `10000000000000000000007A`（3 处）、产品 buildFile `200000000000000000000077`（2 处）、测试 fileRef `10000000000000000000007B`（3 处）、测试 buildFile `200000000000000000000078`（2 处）。八行照卡面原文（制表符与既有行相同，`card==EDITS` 逐字比对）。
- C 之后对象定义 id 无重复（`check_ic179.py` PASS）；`S2InlineHints.swift` 在 pbx 出现 6 次，`IC179InlineHintsTests.swift` 出现次数 = `IC177UnifiedBackgroundTests.swift` = 6。

## 十二、九条新断言与函数名（#362、#363 均 passed）

1. `testIC179A_EntryShowsSwipeUpUntilLearnedThenSilent`
2. `testIC179B_RealMarkLearnsSwipeUpAndShowsMarkedOnce`
3. `testIC179C_RealUnmarkLearnsMarkedOnceAndHides`
4. `testIC179D_ThresholdShowsConfirmEntryAndDisplacesActiveHint`
5. `testIC179E_DismissHidesForThisVisitWithoutLearning`
6. `testIC179F_ResetClearsAllAndReplaysFirstHint`
7. `testIC179G_MarkedOnceTimesOutAndConfirmEntryDisplacesInAnyOrder`
8. `testIC179H_UserDefaultsStoreRoundTripUsesPrefixedKeys`
9. `testIC179I_SourceWiringAndCatalog`

断言 1～7 为协调器夹具驱动（内存 store），8 为 `UserDefaults(suiteName:)` 往返，9 为源码落位与目录。夹具断言只证明协调器状态迁移，不证明真机上的出现时机与观感（陷阱 1）。

## 十三、摘取关系实测（本机克隆 `scratchpad/ic179-exec/pick`，自 `c1003ea` 起，未推送）

| 摘取单元 | 结果 | 核对 |
|---|---|---|
| A 单独 `cherry-pick 831532b` | 退出码 0，无冲突，改 3 路径（pbx、新文件、目录） | 克隆提交树 `b3387f4ca9767ed76eef0f146daf380ab32fa9d1` = 分支 `831532b` 的树 |

A→B、全部即分支本身（线性）。B 依赖 A 的类型、C 依赖 A／B，按卡面声明未单独摘。本机无 Xcode，A 单独编译自洽按卡面与复核结论（新文件不被任何既有文件引用），未单独编译验证。

## 十四、根因假设

本卡不含根因假设。卡内 ③ 两条的 CI 结果：`testIC063…`（红因清单 (3)，担心常驻 `repeatForever` 示意与随 chrome 模糊过渡的图层拖慢计时）——#362／#363 passed，`building pipeline` 0 行（①在 CI 上；真机观感不在其内）；`testIC067G39…`（红因清单 (4)）——两次 passed（①）。

## 十五、规格欠账（按本卡实装，不算规格冲突；SPEC-S2 v23 回填）

1. SPEC-S2 v22 决策 48 整条（六步首次引导教程、步骤 ⑥ 白底与红角标定值、`s2.tutorial.*` 十条）→ v23 改「三句就地提示 + 各自记已会 + × 与限时只管本次 + 第 3 句顶掉在显句」；旧六步条款标「停用，代码退役归维护卡」。
2. 第十一节登记 `S2InlineHintMetrics` 三十个值（卡内暂登，取自 R2 画布 `.bub`／`bubble()`，④ 偏离处见卡事实基础）与三个色引用（`S0DeckMetrics.text`／`background`／`accent`）；协调器两个常量 `confirmThreshold` 5、`markedOnceAutoDismissSeconds` 6。
3. 文案登记七条 `s2.hint.*`（第 7 条 `s2.hint.dismiss` = × 钮无障碍标签，设计要点六条之外）。
4. 未定项两条：「第一次点返回时出第 3 句」（现返回键无中间态）；旧六步教程代码与其 20 条测试的退役时机。
5. 提示层随 chrome 显隐（`V=隐藏` 时随 chrome 隐去）——第 4 部分显隐条款补一句。

## 十六、人工判定项（H94 十条，保留给 Lynn 装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-ae26e20cdda6`（#363，id 10918339086，2026-12-26 前有效）判，执行端不代为下结论）

1. 第一次进任一看图页（首页类别页长按、或整理 tab 进范围都算）：**立刻**出第 1 句暖白气泡「上滑，放进待删篮」+ 副句，气泡与下方循环上滑示意都在主图中心**上方**（不压在中央「已标记」胶囊上）；气泡不挡翻页、缩放、上滑；点 × 收起后本次不再出，退出再进又出。进门那张若已在篮里，上滑只触发已标记脉冲、第 1 句不消失——翻到未标记的照片再上滑。
2. 真实上滑标记一张：第 1 句消失、第 2 句「没有删除，只是放进了待删篮」+「标错了？下滑放回来。」出现，下方是下滑示意；**约 6 秒后自动收起**（本次进入不再出）；之后退出再进**不再出第 1 句**，再标记一张第 2 句再出一次。
3. 在第 2 句还在时翻回刚标记那张、下滑撤标：第 2 句立刻消失；之后再标记别的照片不再出第 2 句。中央「撤销」钮撤标同样算。
4. 篮内攒到 5 张（含进门前篮里已有的，与右上角标同一个数）：右上垃圾桶下方出第 3 句「攒了 N 张，点这里一起确认」带小三角（三角对准圆钮中心，气泡右缘贴边）、张数随角标一起滚（冒出的一瞬可能先写 4 再滚到 5）；若第 2 句正在显示会被第 3 句顶掉；点垃圾桶进确认页再回来、再进看图页不再出；只 × 不点入口，下次进入攒到 5 张时再出；撤标让张数掉回 4 再标回 5 不重出（本次已 × 过）。
5. 单击隐藏 chrome：提示随 chrome 一起隐去，再单击一起回来。点气泡正文（× 以外）会穿透到主图、单击切 chrome、提示随之隐去——属预期，不算缺陷。
6. 标定面板（长按顶部中胶囊）「重看教程」：三句已会清零、第 1 句当场重出（面板开着时气泡压在面板之上，关掉面板再看）。
7. 先浅色模式再深色模式各看一遍：气泡样式应完全一样（暖白底深字、橙红符号）；**旧六步教程绝不再出现**（无 55% 遮罩、无「跳过」按钮、无步骤点）。
8. 截图（有适配带的）与超高／超宽照片各进一次：第 1 句单元是否越过顶排或压到缩略栏。
9. × 钮好不好点（可见 26、命中 44）；气泡挡不挡照片。
10. 一两句总评。

## 十七、发现但未处理（按纪律只报告不修）

预登记（卡面）：

1. 旧教程类型（`S2TutorialStep`／`S2TutorialCoordinator`／`S2TutorialOverlay`／`S2TutorialSpotlight` 等）与 `S2ActionBarWiringTests` 的 20 条测试待退役（本卡后为死路径：`activeStep` 恒 nil，`tutorialOverlay` 恒空，`.disabled(... || tutorial.isRunning)` 恒假）。
2. `S2TutorialCompletionStore` 的旧键 `…s2.tutorial-completed` 留在用户设备上无人读。
3. 「重看教程」按钮文案仍是旧 key `s2.tutorial.replay`——语义已是「重出三句提示」，改 key 归 IC-180 或 v23。
4. 撤标来源不区分（加入相簿后的静默移除也记「撤标已会」）。
5. 点气泡正文穿透切 `V`。
6. 第 3 句张数读显示值 `displayedPendingCount`，冒出一瞬可能落后模型值一拍。
7. `testIC063` 若因提示层变慢的处置：本卡两次运行均 passed（6.2 s），`building pipeline` 0 行，未触发处置。

执行端新增：

8. 两次运行的整包日志各有两行 `Errors found! Invalidating cache...`，时间戳都在 `testIC063…` 的 `started` 之前约 4～6 s（不在该用例块内），之后未见 `building pipeline`。只作记录。
9. 决策会话预演脚本 `sim_ic179.py` 在基线上运行时会重写 `Tasks/decision-tools/sim179/` 三个模拟结果文件（复核第二轮已注明属确定性重写）；执行端按提示词只对基线跑了一次，除此之外未写 `Tasks/decision-tools/`。
10. 执行端首个 CI 轮询脚本因 Windows Python 不认 `/c/…` 路径空转，`TaskStop` 后其 bash 子进程仍在（与新轮询写同一日志），已按 PID 单独结束该进程与其 `sleep` 子进程，未碰其他会话的 `sleep`；本卡结束时执行端起的后台进程均已退出。

## 十八、40 位 SHA 核验（`git cat-file -e`）

报告写完后，对本报告与 `change-list.md` 中出现的全部 40 位 SHA（去重 31 个）先 `git cat-file -t` 取类型、再 `git cat-file -e <sha>^{<类型>}`，**全部存在**（IPA 的 64 位 SHA-256 不是 git 对象，不在此列）：

```
04022d74cb6422ae08a6597cf0b5d81fc31f01a0 tree OK
09d83b1b5b4042747211d691f7118bedc58aa421 commit OK
0d1c3618b0d435fad79067210205a0b8014d60cc tree OK
3b37ae13fd2388501add289622277e449c2ad5e5 blob OK
3cf6195bb0dc6f731ebaabd31f9288f7342509b4 blob OK
3de160993edf5e3479de325d4d996735ea27743b commit OK
498da0346fdb9a6a59db517425d4d97047bda033 tree OK
514886dc0afc4083237c976c0f7be6ce597c50a8 tree OK
51f4c848fb59c821db3db0aa671fd898784ad2b4 tree OK
5d484ae698ee400b088273604b1265f8c2828d55 tree OK
62b9a3589d12e6501865a3565e406395d545c5ed blob OK
71b209a6c059c72329e2d87bf5a0374b4be937df blob OK
74088388c62a10eb277921ecf74e766a2d407e80 tree OK
796859519b61fd2894ecbc13a4399e4398037f7c tree OK
831532bfc6dd62742743081506e980682575e737 commit OK
8564645ba61b1732a9aee996ec866ff31cf33143 blob OK
8974a1db6077befc22864ba346c2d1bb55284590 blob OK
992816e511291a547d43d5baee4eeefdb5f2a858 blob OK
9bb803525f8186625322fecce02dc67d070409e7 commit OK
ae26e20cdda6b09a8ea57eb4e53742374560cf0d commit OK
ae83298b1925e1defabbcf8a762a6ecd3032ba78 tree OK
b3387f4ca9767ed76eef0f146daf380ab32fa9d1 tree OK
b72c57ba486ca46c3b016a1b5a89b4de79552315 blob OK
be64dc867250a9edea24145b473b6bb8d25752a2 tree OK
c1003ea93b5bacda7b2dd6037bfc01a2d0e2e119 commit OK
ca567d006a536e637c0330f8af07bf8b4c0734d3 tree OK
cf1956472d752810e8b689d50bfdea24e863298a blob OK
e933151a14a5bd771471e21347dd504541195209 blob OK
eb12a2e88190ab06546e7105bbb0a59d08d8ce99 blob OK
ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e tree OK
f18e7c0a5e0c79bf2137c17d57b680d1625a8dcd blob OK
```
