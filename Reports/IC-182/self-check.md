# IC-182 自验报告

## 一、结论（先行）

- **四个子项全部按卡面原文完成，已合并入 `main` 并推送。** 分支 `feature/ic-182-tutorial-round-two`：A `b65e53efdf07f613e50709f283919321a3b554fb` → B `6450f20b639e1ad238bb087d845e103e812619ce` → C `9aa95ba8aa5e5927b32f356485e5f66f37fc42af` → D `1dbf0136d07c16f1566790b17be7be91d1541098`。
- 分支 CI **#368**（run `36360830704`）一次绿：**940 项 0 失败**，真实退出码 0，`OS:26.2, name:iPhone 16`；五条新断言全部 passed。CI 预算 3 次只用 1 次（另加合并后 `main` 一次）。
- 合并提交 `69ccec5d5797f73076a51ed35b7f2d434bfa6ee2`（`--no-ff`，双亲 `1d73bac…`／`1dbf013…`，树 `5e70319a117256cd3777b9bb7e4909ad5ca3aa5c` 与 D 提交树相同），合并与推送都一次通过、未被分类器拦。合并后 `main` 运行 **#369（run `36361617159`）一次绿 940／0**。
- **分支推送一度被拦**：执行端第一次 `git push -u origin feature/ic-182-tutorial-round-two` 被 auto mode 分类器以 `[Out-of-Place Publication]` 拒绝；拒绝文本禁止换工具重试，执行端未重试、先回报。随后经 Lynn 授权，由决策会话用 `git -c http.proxy=http://127.0.0.1:7890 push` 推送成功（远端分支 = `1dbf013…`），执行端从「等 CI」接着做。四个提交未重做。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面 30 处锚句（A1～A2、B1～B15、C1～C9、D1～D4）替换时各恰 1 处；卡面「改后」计数 115 条逐条相等（第六节）；拷入文件 hash 相符；七个基线 blob 相符；`sim_ic182.py`（只对基线跑）`FAILURES 0`；`check_ic182.py` 在四个提交上 A 107／107、B 107／107、C 107／107、D 108／108 全 PASS（修正后的版本，见第十七节第 1 条）。**没有与卡面矛盾之处，没有停下的项（推送被拦除外）。**
- 人工判定项（H97 十一条）全部保留给 Lynn 真机判，执行端不代为下结论。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡：`<top>/Tasks/IC-20260927-182-tutorial-round-two.md`（1087 行）；调研 `Tasks/RESEARCH-H94-H93-facts.md`（Q1、Q2、S5 两条）；复核 `Tasks/REVIEW-IC-182-findings.md`（两轮 + 两节处置，以卡为准）。
- 基线：`main` = `1d73bac47d12a307fe34f503b7085db84173dea0`。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor d90ebb32ad3f7b07617f659cfcad30c3098d9fe8 main` 退出码 0；`git ls-remote origin refs/heads/main` = `1d73bac47d12a307fe34f503b7085db84173dea0`（与本地一致）；七个文件 blob 与卡面表逐条相等（下表）；**先 `git switch -c feature/ic-182-tutorial-round-two` 再改文件**。

| 路径 | 卡面 blob | 实测 `git rev-parse HEAD:<路径>` |
|---|---|---|
| `Core/S2StateMachine.swift` | `3af1ca0b5f040cd5cb80a77793a21973834849bd` | `3af1ca0b5f040cd5cb80a77793a21973834849bd` |
| `Features/S2/S2InlineHints.swift` | `3cf6195bb0dc6f731ebaabd31f9288f7342509b4` | `3cf6195bb0dc6f731ebaabd31f9288f7342509b4` |
| `Features/S2/S2View.swift` | `71b209a6c059c72329e2d87bf5a0374b4be937df` | `71b209a6c059c72329e2d87bf5a0374b4be937df` |
| `Features/Shared/S5GuideStepsView.swift` | `dd0c32358a5b6d49e379e5c3bb8e0039b28af595` | `dd0c32358a5b6d49e379e5c3bb8e0039b28af595` |
| `PhotoCleanupMVETests/IC179InlineHintsTests.swift` | `cf1956472d752810e8b689d50bfdea24e863298a` | `cf1956472d752810e8b689d50bfdea24e863298a` |
| `PhotoCleanupMVETests/IC180GuideStepsTests.swift` | `5ef2eec6827ed367c860f6c5931778747da932a2` | `5ef2eec6827ed367c860f6c5931778747da932a2` |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `b46d683f0052f941fd133e59ae2da0d5e42c1765` | `b46d683f0052f941fd133e59ae2da0d5e42c1765` |

- 范围边界：只做卡「本卡边界」五项。三句文案、协调器（除只读判据 `holdsPageOnNextMark`）、气泡本体、六步教程、IC-181、S0／S1 维护、`S2NativePhotoPager`、目录、SPEC 与 Decision_log 均未触碰。
- 改法实施方式：卡面代码块由脚本从卡文件原文逐块取出（不手抄，`scratchpad/ic182-exec/apply_card.py`），每处替换前断言锚句在当时文本恰 1 处；B5（整个 `S2InlineHintMetrics` 枚举）与 B6（`S2InlineHintLayer` 起到文件末尾）是整段 old 恰 1 次匹配，即中间逐字一致。30 处全部恰 1，无一处停下。独立对照：各阶段七个文件的结果 blob 与 `check_ic182.py` 按替换表 `ic182_edits.py` 套用得出的 blob 逐个相同（卡面与替换表两条路径同一结果）。

## 三、提交列表

| 子项 | 提交 | 树 | 可摘性 |
|---|---|---|---|
| A 停留开关 | `b65e53efdf07f613e50709f283919321a3b554fb` | `12a483a72e5a502f9bb4aa4f922f432683aeb89c` | 单独可摘（实测见第十三节） |
| B 三句落位 + 手势示意 + 闪烁根因 + 判据与接线 + IC179 期望 | `6450f20b639e1ad238bb087d845e103e812619ce` | `ee41963ee0f16d6df6dde7e89ad2bf742f71bfc6` | 依赖 A |
| C S5 两条 + IC180 期望 | `9aa95ba8aa5e5927b32f356485e5f66f37fc42af` | `be0454f4e1265f5841208fcd71b59fadabd468ed` | 单独可摘（实测见第十三节） |
| D 新测试 + pbx 测试登记 | `1dbf0136d07c16f1566790b17be7be91d1541098` | `5e70319a117256cd3777b9bb7e4909ad5ca3aa5c` | 依赖 A、B、C |
| 合并 | `69ccec5d5797f73076a51ed35b7f2d434bfa6ee2` | `5e70319a117256cd3777b9bb7e4909ad5ca3aa5c` | 双亲 `1d73bac47d12a307fe34f503b7085db84173dea0`／`1dbf0136d07c16f1566790b17be7be91d1541098` |

## 四、CI

| 项 | 分支运行 #368 | 合并后 `main` 运行 #369 |
|---|---|---|
| run id | `36360830704`（attempt 1） | `36361617159`（attempt 1） |
| 被测提交 | `1dbf0136d07c16f1566790b17be7be91d1541098` | `69ccec5d5797f73076a51ed35b7f2d434bfa6ee2` |
| 结论 | completed／success，作业十二步全部 success | completed／success，作业十二步全部 success |
| XCTest | 唯一 Test Case 行 940 条：940 passed／0 failed；`Executed 940 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC182TutorialRoundTwoTests` 5／5；`testIC063` 族 10 条全 passed | 唯一 Test Case 行 940 条：940 passed／0 failed；`Executed 940 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC182TutorialRoundTwoTests` 5／5；`testIC063` 族 10 条全 passed |
| 执行摘要 notice | `Executed 940 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 940 tests / 0 failures` | `Executed 940 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 940 tests / 0 failures` |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（另一行同 id 的 `arch:x86_64`） | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（另一行同 id 的 `arch:x86_64`） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1971424，SHA-256 `7c7bba3c39a0e264b757b53411aa41e836ebd18f1ac51afb6d58007a052d9d51` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1971424，SHA-256 `99c9744b8c174d69c21427dd7c43bdeb7744deb33de757780bcd76f7892fafb7` |
| 分段耗时 notice | `模拟器启动 63 s；xcodebuild test 261 s；总 325 s` | `模拟器启动 101 s；xcodebuild test 349 s；总 450 s` |
| artifact | `PhotoCleanupMVE-unsigned-1dbf0136d07c`（id 10945861690，1971594 字节，有效期至 2026-12-27T00:04:46Z） | `PhotoCleanupMVE-unsigned-69ccec5d5797`（id 10946400921，1971594 字节，有效期至 2026-12-27T00:16:36Z） |

数据来源：`actions/runs/<id>`、`…/attempts/1/jobs`、`check-runs/<id>/annotations`（各自运行现取的 check-run id：#368 = `108737561050`、#369 = `108739761003`）、`…/artifacts`，以及整包日志 zip 中「9_运行 XCTest.txt」单文件（剔 `##[error]` 与 ANSI 回显行后按唯一 Test Case 行计数）。

项数对账：基线 935（IC-178 合并后 #367）+ 本卡新增 5 条（D 子项；A、B、C 不增删测试）= **940**，与 #368 唯一 Test Case 行数、`Executed` 行、执行摘要 notice 三者一致。

闸门相关测试类（#368 唯一 Test Case 行）：`S2StateMachineTests` 52／52、`S2ImageLoadingStateTests` 13／13、`FullFlowRoutingTests` 6／6、`IC179InlineHintsTests` 9／9、`IC180GuideStepsTests` 5／5、`IC182TutorialRoundTwoTests` 5／5、`IC146ChromeRoundTwoTests` 19／19、`IC152DiagnosticPathTests` 6／6、`IC172GlassAlwaysDarkTests` 7／7、`IC168FallbackDiagnosticsTests` 6／6、`IC177UnifiedBackgroundTests` 3／3，全部 passed。

## 五、本地门禁（四个提交各一份，真实退出码；提交前在暂存态上跑）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A `b65e53e` | 0 | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） | 0 |
| B `6450f20` | 0 | 0 | 0 |
| C `9aa95ba` | 0 | 0 | 0 |
| D `1dbf013` | 0（「结构自验通过…不少于 189 项测试的数量门禁均符合要求」；结构检查 116 个 .swift、needle 变体审计 59 个测试源文件） | 0 | 0 |

另：每个子项提交前，先把暂存区写成一个不挂分支的临时提交（`git write-tree` + `git commit-tree`），在其上跑本卡计数脚本与 `IC182_BASE=1d73bac… python -B check_ic182.py <临时提交> <段>`，blob 比对全 PASS、计数与卡面全相等后才正式提交。正式提交后在四个真实提交上复跑（`check_ic182.py` 已由决策会话修正后的版本）：A 107／107、B 107／107、C 107／107、D 108／108 PASS。

## 六、子项计数实测表（卡面值 / 实测值；剔注释口径 = 测试 `strippedSource` 的 Python 移植 `decision-tools/strip.py`，切片口径同测试 `slice`；脚本 `scratchpad/ic182-exec/counts.py` 在 D 提交 `1dbf013` 对象上读，A／B／C 各自提交上分段复跑同为全相等：A 110／110、B 115／115、C 115／115、D 115／115）

**A machine**

| needle／项 | 卡面 | 实测 | 判 |
|---|---|---|---|
| `holdsPageAfterNextMark` | 3 | 3 | 相等 |
| `var holdsPageAfterNextMark = false` | 1 | 1 | 相等 |
| `handleSwipeUp: if holdsPageAfterNextMark && zoomState == .oneX {` | 1 | 1 | 相等 |
| `handleSwipeUp: holdsPageAfterNextMark = false` | 1 | 1 | 相等 |
| `handleSwipeUp: resetZoomAfterPhotoChange()` | 0 | 0 | 相等 |
| `handleSwipeUp: switchPhoto(by: 1)` | 1 | 1 | 相等 |
| `handleSwipeUp: pendingUndecidedItem = .item02` | 1 | 1 | 相等 |
| `order write D < hold check < switchPhoto` | True | True | 相等 |
| `func handleSwipeDown() (stripped)` | 1 | 1 | 相等 |
| `? handleSwipeDown() (raw, IC146)` | 1 | 1 | 相等 |
| `func handleSwipeDown() (raw, IC146)` | 1 | 1 | 相等 |
| `func reportNativeViewport( (stripped)` | 1 | 1 | 相等 |
| `func reportNativeViewport( (raw)` | 1 | 1 | 相等 |

**B hints**

| needle／项 | 卡面 | 实测 | 判 |
|---|---|---|---|
| `struct S2InlineHintGestureView: View {` | 1 | 1 | 相等 |
| `S2InlineHintGestureView(direction:` | 1 | 1 | 相等 |
| `S2TutorialGestureHint(direction:` | 0 | 0 | 相等 |
| `centeredMaxWidth` | 0 | 0 | 相等 |
| `gestureHintSpacing` | 0 | 0 | 相等 |
| `pointsAtConfirmEntry` | 2 | 2 | 相等 |
| `holdsPageOnNextMark` | 1 | 1 | 相等 |
| `.id(direction) (whole file)` | 1 | 1 | 相等 |
| `.id(direction) (S2InlineHintLayer slice)` | 1 | 1 | 相等 |
| `repeatForever` | 1 | 1 | 相等 |
| `strokeBorder(` | 1 | 1 | 相等 |
| `.shadow(` | 2 | 2 | 相等 |
| `alignment: .topTrailing` | 1 | 1 | 相等 |
| `alignment: .trailing` | 2 | 2 | 相等 |
| `.accessibilityHidden(true)` | 1 | 1 | 相等 |
| `Button {` | 1 | 1 | 相等 |
| `.allowsHitTesting(false)` | 5 | 5 | 相等 |
| `S0DeckMetrics.` | 10 | 10 | 相等 |
| `.frame(` | 8 | 8 | 相等 |
| `Metrics static let` | 39 | 39 | 相等 |
| `Symbol static let` | 6 | 6 | 相等 |
| `Material` | 0 | 0 | 相等 |
| `colorScheme` | 0 | 0 | 相等 |
| `Color(uiColor:` | 0 | 0 | 相等 |
| `@MainActor` | 0 | 0 | 相等 |
| `S2TutorialHintAnchor` | 0 | 0 | 相等 |
| `raw Text("` | 0 | 0 | 相等 |
| `raw return "` | 0 | 0 | 相等 |
| `import ` | 1 | 1 | 相等 |
| `key "s2.hint.confirm"` | 1 | 1 | 相等 |
| `key "s2.hint.confirm.sub"` | 1 | 1 | 相等 |
| `key "s2.hint.dismiss"` | 1 | 1 | 相等 |
| `key "s2.hint.marked"` | 1 | 1 | 相等 |
| `key "s2.hint.marked.sub"` | 1 | 1 | 相等 |
| `key "s2.hint.swipe_up"` | 1 | 1 | 相等 |
| `key "s2.hint.swipe_up.sub"` | 1 | 1 | 相等 |
| `every Metrics name referenced (hints file or S2View)` | [] | [] | 相等 |
| `coordinator == base except holdsPageOnNextMark` | True | True | 相等 |
| `bubble == base` | True | True | 相等 |

**B S2View**

| needle／项 | 卡面 | 实测 | 判 |
|---|---|---|---|
| `machine.holdsPageAfterNextMark` | 4 | 4 | 相等 |
| `machine.holdsPageAfterNextMark = hints.holdsPageOnNextMark` | 4 | 4 | 相等 |
| `machine.holdsPageAfterNextMark = true` | 0 | 0 | 相等 |
| `machine.holdsPageAfterNextMark = false` | 0 | 0 | 相等 |
| `.onChange(of: hints.activeHint) {` | 1 | 1 | 相等 |
| `sync right after hints.startIfNeeded(...)` | True | True | 相等 |
| `sync right after if !removed.isEmpty { hints.assetDidBecomeUnmarked() }` | True | True | 相等 |
| `sync inside .onChange(of: hints.activeHint) body` | 1 | 1 | 相等 |
| `sync right after hints.reset()` | True | True | 相等 |
| `overlay slice: topLeading frame` | 1 | 1 | 相等 |
| `overlay slice: frame before .animation(` | True | True | 相等 |
| `overlay slice: s2ChromeVisibilityTransition( (== base)` | 1 | 1 | 相等 |
| `overlay slice: S2InlineHintLayer( (== base)` | 1 | 1 | 相等 |
| `overlay slice: S2OverlayLayout.topBarHeight (== base)` | 1 | 1 | 相等 |
| `overlay slice: hints.dismiss() (== base)` | 1 | 1 | 相等 |
| `overlay slice: mergedCount: displayedPendingCount (== base)` | 1 | 1 | 相等 |
| `overlay slice: hints.hintDidTimeOut(.markedOnce) (== base)` | 1 | 1 | 相等 |
| `overlay slice: S2InlineHintCoordinator.markedOnceAutoDismissSeconds (== base)` | 1 | 1 | 相等 |
| `overlay slice: Task.isCancelled (== base)` | 1 | 1 | 相等 |
| `overlay slice: .task(id: hint) (== base)` | 1 | 1 | 相等 |
| `overlay slice: .animation( (== base)` | 1 | 1 | 相等 |
| `hints.assetDidBecomeMarked( (== base)` | 1 | 1 | 相等 |
| `hints.assetDidBecomeUnmarked( (== base)` | 1 | 1 | 相等 |
| `hints.confirmEntryTapped( (== base)` | 1 | 1 | 相等 |
| `hints.dismiss( (== base)` | 1 | 1 | 相等 |
| `hints.hintDidTimeOut( (== base)` | 1 | 1 | 相等 |
| `hints.leaveScreen( (== base)` | 1 | 1 | 相等 |
| `hints.mergedCountDidChange( (== base)` | 1 | 1 | 相等 |
| `hints.reset( (== base)` | 1 | 1 | 相等 |
| `hints.startIfNeeded( (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.currentAssetID) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.currentIndex) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.feedbackEvent) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.imageRequestScale) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.interfaceVisibility) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.lastAlbumAddition) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.pendingDeletionAssetIDs) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.semanticNotice) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.sessionMergedPendingDeletionCount) { (== base)` | 1 | 1 | 相等 |
| `.onChange(of: machine.sheetState) { (== base)` | 1 | 1 | 相等 |
| `raw colorScheme, .dark)` | 6 | 6 | 相等 |
| `.background(.regularMaterial)` | 3 | 3 | 相等 |
| `raw "s2.tutorial.replay"` | 1 | 1 | 相等 |

**C S5**

| needle／项 | 卡面 | 实测 | 判 |
|---|---|---|---|
| `isLeadStep` | 0 | 0 | 相等 |
| `in: Circle())` | 0 | 0 | 相等 |
| `strokeBorder(` | 1 | 1 | 相等 |
| `.lineLimit(1)` | 1 | 1 | 相等 |
| `.minimumScaleFactor(S5GuideMetrics.textMinimumScaleFactor)` | 1 | 1 | 相等 |
| `S1ChromeForeground.` | 4 | 4 | 相等 |
| `@ViewBuilder` | 0 | 0 | 相等 |
| `.accessibilityHidden(true)` | 1 | 1 | 相等 |
| `.accessibilityElement(children: .combine)` | 1 | 1 | 相等 |
| `ForEach(S5GuideStep.allCases, id: \.rawValue)` | 1 | 1 | 相等 |
| `Metrics static let` | 13 | 13 | 相等 |
| `Symbol static let` | 5 | 5 | 相等 |
| `raw Text("` | 0 | 0 | 相等 |
| `raw return "` | 0 | 0 | 相等 |
| `import ` | 1 | 1 | 相等 |
| `key "s5.guide.step1"` | 1 | 1 | 相等 |
| `key "s5.guide.step2"` | 1 | 1 | 相等 |
| `key "s5.guide.step3"` | 1 | 1 | 相等 |
| `key "s5.guide.step4"` | 1 | 1 | 相等 |
| `key "s5.guide.step5"` | 1 | 1 | 相等 |

说明：「每个登记值都被引用」一项按「提示文件内或 `S2View.swift` 内 `S2InlineHintMetrics.<名>`」口径判；`transitionSeconds` 在基线与改后都只被 `S2View.swift` 引用（见第十七节第 2 条）。

## 七、拷入文件

- `PhotoCleanupMVETests/IC182TutorialRoundTwoTests.swift`：`cp` 自 `<top>/Tasks/decision-tools/IC182TutorialRoundTwoTests.swift`，`git hash-object` = `0136baf20cc763a1cdedb69b1ed11968837bf327`（与卡面相等），`cmp` 与源文件逐字节相同；未改动任何一行。

## 八、闸门 G1005～G1009

| 闸门 | 结论 | 依据 |
|---|---|---|
| G1005 停留开关 | 过 | #368：`testIC182A_HoldAfterFirstMarkOnlyOnce`、`testIC182A2_CoordinatorDecidesHoldExactlyWhenMarkedOnceWouldAppear` passed；`S2StateMachineTests` 52／52（含 `testIC047_006TransitionRowSwipeUp`、`testIC059NxSwipeUpMarksAndResetsAfterPhotoChange`）、`S2ImageLoadingStateTests` 13／13、`FullFlowRoutingTests` 6／6 passed |
| G1006 落位、示意、S5 | 过 | #368：`testIC182B_PlacementRulesGestureMetricsAndSymbols`（含三个 SF 名 `hand.point.up.left`／`arrow.down`／`arrow.right` 在宿主 `UIImage(systemName:)` 非空——③ → ①）、`testIC182D_CatalogUntouched` passed；`IC179InlineHintsTests` 9／9、`IC180GuideStepsTests` 5／5 passed |
| G1007 源码落位 | 过 | #368：`testIC182C_SourceWiring` passed；A／B／C 计数与卡面「改后」逐条相等（第六节）；`IC146ChromeRoundTwoTests` 19／19、`IC152DiagnosticPathTests` 6／6、`IC172GlassAlwaysDarkTests` 7／7、`IC168FallbackDiagnosticsTests` 6／6、`IC177UnifiedBackgroundTests` 3／3 passed |
| G1008 合并前置 | 过 | G1005～G1007；`git diff --name-only 1d73bac..1dbf013` 恰 8 路径；「不得打红」段两侧对象相同（第九节）；27 条被保护分支 tip 未变（第十节）；CI 绿（第四节）；pbx 撞号 0（第十一节）；合并前工作树净；合并前 `ls-remote`（102 行）与推送后快照逐行相同，`main` 未被他人推进（仍 `1d73bac`） |
| G1009 合并后 | 过 | 合并后 `main` 运行 #369（run `36361617159`）一次绿 940／0；artifact `PhotoCleanupMVE-unsigned-69ccec5d5797`（id 10946400921，1971594 字节，有效期至 2026-12-27T00:16:36Z） |

## 九、「不得打红」段对象比对（基线 `1d73bac` vs D `1dbf013`，`check_ic182.py` D 段输出，85 项全 PASS）

| 范围 | 结果 |
|---|---|
| 目录对象 `PhotoCleanupMVE/Services`、`PhotoCleanupMVE/App`、`Features/S0`、`Features/S1`、`Features/S3`、`Features/S4`、`Features/S5`、`.github`、`Scripts`（9 个树对象） | 两侧 tree id 逐个相同 |
| `Core/` 除 `S2StateMachine.swift` 外 9 个文件 | blob 逐个相同 |
| `Features/S2/` 除 `S2View.swift`／`S2InlineHints.swift` 外 9 个文件（含 `S2NativePhotoPager.swift`） | blob 逐个相同 |
| `Features/Shared/` 除 `S5GuideStepsView.swift` 外 3 个文件 | blob 逐个相同 |
| 测试目录除 `IC179InlineHintsTests.swift`／`IC180GuideStepsTests.swift` 外 55 个既有文件 | blob 逐个相同；新增文件集合恰 `IC182TutorialRoundTwoTests.swift` |
| `Localizable.xcstrings` | blob `911848e37193b1491b60274549db5ec1c0425a33` 两侧相同 |
| `S2InlineHintCoordinator` 除 `holdsPageOnNextMark` 外文本、`S2InlineHintBubble` 文本 | 与基线逐字相同（计数脚本切片比对） |
| `S2View.swift` 原文 `colorScheme, .dark)` 6、`.background(.regularMaterial)` 3 | 6、3 |
| `schemaVersion` | 7（`S2Calibration.swift` blob 未变） |

## 十、被保护分支（27 条，推送后与合并前各 `ls-remote` 一次）

`Reports/IC-178/self-check.md` 第十节列名的 26 条 + `feature/ic-178-year-deck-and-page` `ed8c9bf`（= IC-178 合并提交 `d90ebb3` 的第二亲）：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`、`feature/ic-169-marked-state-follows-basket` `bf9551e`、`feature/ic-175-similar-recognizer` `8d5bc7b`、`feature/ic-177-unified-background` `3cdae92`、`feature/ic-179-inline-hints` `3de1609`、`feature/ic-180-s5-guide-steps` `219be48`、`feature/ic-178-year-deck-and-page` `ed8c9bf`——**27／27 与远端头相符**；合并前复查：全部远端 ref 与推送后快照（102 行 = IC-178 报告的 101 行 + 本分支一行）逐行相同。

## 十一、pbxproj 撞号扫描与新 id

- 登记前重扫：fileRef 最大 `100000000000000000000080`、buildFile 最大 `20000000000000000000007D`（与卡面相符）；两个新 id 在基线 pbx 中各出现 0 次。
- 新 id（照卡面、未改号）：`IC182TutorialRoundTwoTests.swift` fileRef `100000000000000000000081`／buildFile `20000000000000000000007E`，四行各接在 IC178 测试行之后（制表符与既有行相同）。
- D 态：测试 fileRef 3 处、buildFile 2 处；定义 id 重复 0。

## 十二、五条新断言与函数名（#368 均 passed）

1. `testIC182A_HoldAfterFirstMarkOnlyOnce` — 开关行为：默认翻页；开时停在刚标记这张、吃掉开关、不发未决项，随后下滑撤标、再上滑翻页；已标记与隐藏态不吃开关；最后一张开／关对照；Nx 照旧翻页、开关留待 1x（夹具驱动，真机未覆盖）
2. `testIC182A2_CoordinatorDecidesHoldExactlyWhenMarkedOnceWouldAppear` — 协调器判据全序列（内存 store）
3. `testIC182B_PlacementRulesGestureMetricsAndSymbols` — 三句落位口径、手势示意十一值、三个 SF 名在宿主存在、S5 缩放值
4. `testIC182C_SourceWiring` — 源码落位（状态机顺序与只在 1x、S2View 四处同步与新 `.onChange`、提示文件新视图／退役名／`.id` 落位、S5 统一描边与缩放）
5. `testIC182D_CatalogUntouched` — 目录未动

## 十三、摘取关系实测（本机克隆 `scratchpad/ic182-exec/clone`，自 `1d73bac` 起，未推送）

| 操作 | 退出码 | 结果树 | 对照 |
|---|---|---|---|
| `cherry-pick -x b65e53e`（A 单独） | 0 | `12a483a72e5a502f9bb4aa4f922f432683aeb89c` | 与 A 提交树相同 |
| 回到 `1d73bac`，`cherry-pick -x 9aa95ba`（C 单独） | 0 | `2f085a2925281e586d83a0c3c5444b5e73b3d874` | 只改两条路径；`S5GuideStepsView.swift` blob `f1fea670f5d192020c23f706354194d5e90f1d17`、`IC180GuideStepsTests.swift` blob `28ff03e1b92f9e2acd36d5ed5593751f1b8f67ff` 与 C 提交中的相同 |

B 依赖 A（`machine.holdsPageAfterNextMark`），D 依赖 A、B、C，按卡只作连续序列摘取。编译自洽性实证是 #368（A～D 全部叠上）；A 单独、C 单独的编译未在 CI 上单独验证（③，按符号依赖推断：A 只加一个属性与一个分支、无调用者；C 只改 S5 文件与 IC180 期望）。

## 十四、根因假设

- **右下闪烁（H94 第 3／4 条）**：卡面机制为③——内层 `ZStack` 无框，句子消失时塌成零尺寸落到视口中心，淡出层随之平移到右下象限。本卡按卡面加 `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`。CI 只能钉源码落位（`testIC182C`），**机制既未被证实也未被推翻**，由 H97 第 3 条真机判定。
- **第 2 句落在下一张（H94 脱节）**：事实表①（写 D 与翻页同步完成）已由代码读证；修法「第 2 句将要出现的那一次不翻页」的行为只在夹具上验证（`testIC182A`／`A2`），真机观感待 H97 第 2、8 条。

## 十五、规格欠账（按本卡实装，不算规格冲突；原样照卡）

1. **SPEC-S2 v23**：决策 48 六步教程改写为三句就地提示（第 208 条欠账）之上，补「学习例外」——第 2 句将要出现的那一次上滑标记不自动进入下一张、停在刚标记的照片（归 1x，第 2 句在其上），其余标记照旧「原子标记、自动进入下一张」（`:309`／`:427`／`:456`／`:646` 加例外注记；每次进门至多一次、第 2 句学会后永不再停——④ 第 211 条原话是「首次标记」，此处按第一轮复核 F2 收窄为「第 2 句出现的那一次」，待 Lynn 追认）；三句位置改「都在顶排之下右侧（右上）、右对齐，第 3 句带小三角」（第 208 条裁定的居中锚作废）；补手势示意登记十一值（含对比阴影两值）与三个 SF 名；补浮层容器「全屏框 + 左上对齐」实装约束。
2. **SPEC-S5 v7**：五步编号圆统一描边（第 209 条裁定 三「第 1 步实心」作废）、正文单行按需缩放 `textMinimumScaleFactor` 0.8 入视觉登记节。
3. 未定项：第 2 句 6 s 限时收起与第 1 句 × 收起是否也曾在右下闪（调研推论③，H97 第 3 条看）；相册维度非惰性叠等与本卡无关。

## 十六、人工判定项（H97 十一条，保留给 Lynn 装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-69ccec5d5797`（id 10946400921，1971594 字节，有效期至 2026-12-27T00:16:36Z） 判，执行端不代为下结论）

1. 全新安装（或标定面板「重看教程」后）进任一看图页：第 1 句气泡在**右上**顶排下方（无小三角），主图中央上方是新的手势示意——手在半透明圆里、圆外一圈光晕环、箭头在手之上、整体循环上移淡出；**白色／亮色照片上示意是否看得清**（有黑影）；手形是 SF 的食指指向左上，与 R2 张开的手不同——可不可以。
2. 第一次上滑标记：**照片不翻页**、停在刚标记这张，中央出「已标记 · 撤销」胶囊，残影仍飞向右上垃圾桶、角标 +1；第 1 句换成第 2 句（右上，气泡上缘与第 1 句同高），示意换成箭头在手之下的下滑循环——**看它在动**（不是停在透明终点）；下滑示意与中央「已标记」胶囊不重叠；此时**下滑当场撤标**、第 2 句消失；残影穿过右上气泡时的观感。之后再上滑标记，照旧自动翻到下一张。放大（Nx）状态下第一次标记：**不停留**、照旧翻页并回到 1x，回到 1x 后的下一次标记才停。
3. 第 2 句消失（下滑撤标、点 ×、或 6 秒自动收起）时，**右下角不再闪任何东西**；第 1 句点 × 时同样不闪。
4. 攒到 5 张出第 3 句：仍在右上、带小三角指向垃圾桶圆钮，与第 1／2 句同一列同一右缘。
5. 「重看教程」：第 1 句当场重出，且下一次标记再停留一次。
6. 单击隐藏 chrome：气泡与示意随 chrome 一起隐去、再出现。
7. S5「清理结果」页：五步编号圆全部描边（无实心），五句各一行不折行（第 2 步字略小可接受吗）；375 宽机型（若有）同看。
8. 已经学会过第 1 句但没撤标过（比如第一次没理第 2 句、让它 6 秒自己收起）：**再进门**第一次标记仍停一次、第 2 句落在刚标记那张；撤标过一次之后再进门，标记照旧翻页、没有停留。进门时篮里已有 4 张、第一次标记恰好到 5：会停在原张但只见第 3 句（第 2 句被顶掉）——看这种情形会不会让人以为没标上。
9. 小屏（若有 375 宽或 SE）：第 1／2 句气泡（右上、最大宽 300）会不会折成两行并与下滑示意重叠；截图与超高／超宽照片看示意是否越过顶排（H94 原有观察点）。
10. 第 2 句 → 第 3 句切换时气泡下跳约 6 pt（第 3 句多一个三角）——可不可以。
11. 一两句总评：气泡都在右上是否顺眼、手势示意的新样式与 R2 画布是否一致、停留那一下会不会让人误以为没标上。

## 十七、发现但未处理（按纪律只报告不修）

1. **决策会话工具缺陷，已由决策会话修正**：`Tasks/decision-tools/check_ic182.py` 原有两条旧期望未随第二轮复核更新——`hints metrics static let` 写 37（卡面与 IC179 B14 为 39）、`S2View machine.holdsPageAfterNextMark` 写 2（卡面为 4），致 B／C／D 阶段固定报 2 条 FAIL（blob 比对全 PASS、实测等于卡面）。执行期间由决策会话改为 39／4，修正后四段全 PASS。
2. 卡面「三十九个登记值每个都被文件内引用」不严格成立：`transitionSeconds` 在基线与改后都只被 `S2View.swift` 引用，不被 `S2InlineHints.swift` 自身引用（②，无断言受影响）。
3. 右下闪烁机制 ③ 待真机（H97 第 3 条）；第 2 句 6 s 限时与第 1 句 × 是否曾闪未看。
4. `hand.point.up.left`／`arrow.down`／`arrow.right` 三名：③ → ①（#368 `testIC182B` 在宿主 `UIImage(systemName:)` 非空）。
5. 手形（食指指向左上）与 R2 张开的手不同（观感 H97 第 1 条）。
6. 停留判据从 ④ 第 211 条「首次标记」收窄为「第 2 句出现的那一次」（每次进门至多一次），待 Lynn 追认。
7. 放大态不停留（开关留待 1x）。
8. 进门篮已 4 张、首标到 5 时停留但只见第 3 句（③ 边界，H97 第 8 条）。
9. 小屏第 1／2 句气泡折行与下滑示意可能重叠（③，H97 第 9 条）。
10. 第 2 → 3 句气泡下跳约 6 pt（有意为之，H97 第 10 条）。
11. 六步教程仍停用不删。
12. IC-181 操作说明卡入口待 Lynn。

## 十八、40 位 SHA 核验（`git cat-file -e`）

两份报告中出现的全部 40 位十六进制串共 28 个，逐个 `git cat-file -e <sha>^{<类型>}`，退出码全 0（其中 1 个在本机摘取克隆内核验，见表）。（本表不含合并后才产生的 docs 提交自身；IPA／artifact 摘要是 SHA-256，不在此列。）

| SHA | 类型 | `git cat-file -e` |
|---|---|---|
| `0136baf20cc763a1cdedb69b1ed11968837bf327` | blob | 0（存在） |
| `12a483a72e5a502f9bb4aa4f922f432683aeb89c` | tree | 0（存在） |
| `1d73bac47d12a307fe34f503b7085db84173dea0` | commit | 0（存在） |
| `1dbf0136d07c16f1566790b17be7be91d1541098` | commit | 0（存在） |
| `22a969715e66977f63926c1b7abe7e52490160bf` | blob | 0（存在） |
| `28ff03e1b92f9e2acd36d5ed5593751f1b8f67ff` | blob | 0（存在） |
| `2f085a2925281e586d83a0c3c5444b5e73b3d874` | tree | 0（存在）（只在本机摘取克隆 `scratchpad/ic182-exec/clone` 内，C 单独摘取结果树，未推送） |
| `3af1ca0b5f040cd5cb80a77793a21973834849bd` | blob | 0（存在） |
| `3cf6195bb0dc6f731ebaabd31f9288f7342509b4` | blob | 0（存在） |
| `45fcebccd42048ab680c34bddf18f9bbb5a2d16c` | blob | 0（存在） |
| `548a4c8d6be8e83724a40effb6421c8b968cfdc4` | blob | 0（存在） |
| `5e70319a117256cd3777b9bb7e4909ad5ca3aa5c` | tree | 0（存在） |
| `5ef2eec6827ed367c860f6c5931778747da932a2` | blob | 0（存在） |
| `6450f20b639e1ad238bb087d845e103e812619ce` | commit | 0（存在） |
| `69ccec5d5797f73076a51ed35b7f2d434bfa6ee2` | commit | 0（存在） |
| `71b209a6c059c72329e2d87bf5a0374b4be937df` | blob | 0（存在） |
| `911848e37193b1491b60274549db5ec1c0425a33` | blob | 0（存在） |
| `9aa95ba8aa5e5927b32f356485e5f66f37fc42af` | commit | 0（存在） |
| `b46d683f0052f941fd133e59ae2da0d5e42c1765` | blob | 0（存在） |
| `b65e53efdf07f613e50709f283919321a3b554fb` | commit | 0（存在） |
| `be0454f4e1265f5841208fcd71b59fadabd468ed` | tree | 0（存在） |
| `cf1956472d752810e8b689d50bfdea24e863298a` | blob | 0（存在） |
| `d814f599df69211e7bbc0aed013839e3722367d2` | blob | 0（存在） |
| `d90ebb32ad3f7b07617f659cfcad30c3098d9fe8` | commit | 0（存在） |
| `dd0c32358a5b6d49e379e5c3bb8e0039b28af595` | blob | 0（存在） |
| `ea216665a203b60b2900d4bc4cc21ab44386e38b` | blob | 0（存在） |
| `ee41963ee0f16d6df6dde7e89ad2bf742f71bfc6` | tree | 0（存在） |
| `f1fea670f5d192020c23f706354194d5e90f1d17` | blob | 0（存在） |
