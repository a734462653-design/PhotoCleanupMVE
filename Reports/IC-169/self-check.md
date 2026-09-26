# IC-169 自验报告

## 一、结论（先行）

**已合并、已推送、合并后运行绿。** 分支 `feature/ic-169-marked-state-follows-basket` 五个子项各自独立提交 A→B→C→D→E。A～D 推送后 CI **#355 绿 899／0**；E 推送后 CI **#356 绿 905／0**；G973 全部满足后 `--no-ff` 合并入 `main`（合并提交 `3cad2e2e47d1a13249f5370a0e47f283b9967c69`）并推送；合并后 `main` 自动运行 **#357 绿 905／0**。CI 预算 2／3（两次都一次绿）。

- 子项 A～D 的全部改法逐字取自任务卡代码块（执行端脚本从卡面 26 个 ```swift 块取原文，并与 `Tasks/decision-tools/ic169_edits.py` 逐对比较相等），每个锚句在当时工作树上恰命中 1 处。
- 每个子项提交前的计数实测与卡面「改后（预演值）」**逐条相等**（第六节），IC157 逐字切片在每个阶段都 35 行且与源码逐字相等。
- 子项 E 测试文件逐字节拷入，`git hash-object` = `fc353710400e256b57f0d3ea81667c267cb30174`（与卡面相等），六条在 #356、#357 均 passed。
- 卡面「会被触到的既有断言共 3 处」全部按卡改写，改后在两次 CI 中 passed；卡面点名的其余闸门用例全部 passed（第八节）。
- 按卡「本卡不做」：`S1View.swift`、`SessionStore.pendingDeletionCount(for:)`、`markPendingDeletion`、S2、协调器与 App 一字未动（第九节对象比对）。
- **全部新断言与既有断言都是夹具驱动，真机未覆盖**（陷阱 1）；S2 里篮内照片的标记态、类别篮随之消失、角标与分组观感保留给 Lynn 在 H86 真机判定。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260924-169-marked-state-follows-basket.md` |
| 前置阅读 | `<top>/CLAUDE.md`；SPEC-S1 v10 `:189-204`／`:442`／`:505-526`；SPEC-S2 v22 `:193`／`:722`／`:750`；`Tasks/RESEARCH-IC-169-facts.md`、`RESEARCH-IC-169-addendum.md`、`RESEARCH-IC-169-b-rule.md`；`Tasks/REVIEW-IC-169-findings.md`（两轮，实质 0） |
| 基线 `main`（开工时） | `f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830` |
| 开工核对 1 | `git status --porcelain` 空 |
| 开工核对 2 | `git merge-base --is-ancestor 39dc8d0be448ea051f37fdb99be8dbae3d35ca35 main` 退出码 0 |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830`，与本地一致 |
| 开工核对 4 | `main:PhotoCleanupMVE/Core/S1StateMachine.swift` = `98432dde8103944a7910c8a67cee268895eb6e53`，`main:PhotoCleanupMVE/Core/SessionStore.swift` = `43cf1ffec2e9cc3b619b178ff3ba3a0f060d1962`，与卡面相等 |
| 分支 | `feature/ic-169-marked-state-follows-basket`，改任何文件前先 `git switch -c` 自基线切出 |
| `schemaVersion` | 7（未动；`S2Calibration.swift:118`） |
| 会话档格式 | 不变（`SessionPersistence.swift` 对象两侧相同） |
| 文案目录 | 259（`Localizable.xcstrings` 对象两侧相同） |
| 合并 | `--no-ff`，合并提交 `3cad2e2e47d1a13249f5370a0e47f283b9967c69`，父 `f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830`（合并前 main）与 `bf9551eb4b45633ca78ab124360e959e6cbb49a2`（分支 tip = E）；合并树 `df294efcd4a8c00f1a32bd3b4d6241eebb8c81c7` = E 提交的树 |
| docs 提交（惯例 44） | 合并与合并后运行 #357 之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`） |
| CI 预算 | 2／3 |

## 三、提交列表

| 子项 | 提交 SHA | 改动 |
|---|---|---|
| A | `50ae2dbe6a6cf80929b6aa55f3f727034ba21d81` | 两处交接 `D` 初值 = `allPendingDeletionAssetIDs.intersection(assetIDSet)` + 两处文档注释；`S1StateMachineTests` 三处、`IC157LongPressIntoS2Tests` 两处同步 |
| B | `99b39f25cebf14582aa2ed6dad1c828a83fd1b2d` | `applyPendingDeletionDiff` 函数体：此刻篮为基准、撤标全局（逐范围 `setMarked(false…)`，范围升序）、加标只写此刻不在篮的；`IC129ExistenceReconciliationTests` 一处同步 |
| C | `77cd14b65aa81a41a06a341553ac6019424ca3ee` | `SessionStore.applyS2Return` 一处：列表内不在 `D` 的从全部范围移除，`D` 里写回前不在篮的并入本范围；`F` 过滤与守卫一字未动 |
| D | `71d03fa00efb88d2d62ab6c128b2a2933d5a9c3b` | `rangeRows`：`pendingDeletionCount = basket.intersection(range.assetIDsNewestFirst).count` |
| E | `bf9551eb4b45633ca78ab124360e959e6cbb49a2` | 新测试文件（逐字节拷入）+ pbxproj 四行登记 |
| merge | `3cad2e2e47d1a13249f5370a0e47f283b9967c69` | 首行 `merge(IC-169): S2 标记态按合并待删集合显示、写回只写本次会话新标且撤标全局、S1 范围角标按篮与本范围交集` |

## 四、CI

| 项 | #355（A～D） | #356（E） | #357（合并后 `main`） |
|---|---|---|---|
| run id | `36258913964` | `36259740896` | `36260502037` |
| 被测提交 | `71d03fa00efb88d2d62ab6c128b2a2933d5a9c3b` | `bf9551eb4b45633ca78ab124360e959e6cbb49a2` | `3cad2e2e47d1a13249f5370a0e47f283b9967c69` |
| 结论 | success（12 步全 success） | success（12 步全 success） | success（12 步全 success） |
| 执行摘要 notice | `Executed 899 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 899 tests / 0 failures` | `Executed 905 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 905 tests / 0 failures` | `Executed 905 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 905 tests / 0 failures` |
| 整包日志唯一 Test Case 行 | 899 passed／0 failed | 905 passed／0 failed | 905 passed／0 failed |
| 真实退出码 | 0（「运行 XCTest」步骤 success；工作流 `set -o pipefail` + `exit "$test_status"`；日志 `** TEST SUCCEEDED **`、`XCTest 已全部通过。`） | 0（同左） | 0（同左） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左 | 同左 |
| 分段耗时 notice | `模拟器启动 78 s；xcodebuild test 425 s；总 505 s` | `模拟器启动 85 s；xcodebuild test 341 s；总 427 s` | `模拟器启动 81 s；xcodebuild test 448 s；总 530 s` |
| IPA 字节数 | 1863993 | 1863993 | 1863993 |
| IPA SHA-256 | `3183854092ddf2d2400872666a1998a816415af42bc2057611ed3f8415797f46` | `1bd79e2bb066cf6961dfb3291ef194140917d1bc9b287d3a69e1a7c5f86318cf` | `8e18be0f03fdad851cf7b6559fb9dccc0b05c507ed8154e425ef20ca9a9fe99a` |
| artifact | `PhotoCleanupMVE-unsigned-71d03fa00efb`，id 10911947100，1864163 字节，2026-12-25T17:24:29Z 到期 | `PhotoCleanupMVE-unsigned-bf9551eb4b45`，id 10911888386，1864163 字节，2026-12-25T17:38:26Z 到期 | `PhotoCleanupMVE-unsigned-3cad2e2e47d1`，id 10912301344，1864163 字节，2026-12-25T17:51:21Z 到期 |
| `testIC063` build 行 | 该用例块内**无** `building pipeline` 行（`IC063_WARMUP_GATE_BEGIN`／`END` 在块内先后出现）；全日志唯一一条 build 行 `primitive_coverage… took 0.644286 seconds` 在之后的 `testIC085R3RenderedStripHasNoBackgroundInsideItemFrames` 块内，位于 `IC063_WARMUP_GATE_END` 之后 | 同左形态，build 行 0.600192 s，在 `testIC085R3…` 块内 | 同左形态，build 行 1.238066 s，在 `testIC085R3…` 块内 |

项数对账：899（基线 #354）+ 0（A～D 不增删测试）= 899（#355）；899 + 6（E 新文件六条）= 905（#356、#357）。

## 五、本地门禁（五个提交各一份，真实退出码）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A 提交前 | 0 | 0 | 0 |
| B 提交前 | 0 | 0 | 0 |
| C 提交前 | 0 | 0 | 0 |
| D 提交前 | 0 | 0 | 0 |
| E 提交前 | 0 | 0 | 0（新文件先 `git add -N` 纳入检查） |

selfcheck 末行均为「结构自验通过…」；E 时交叉审计扫描测试源文件数 52 → 53。

## 六、子项 A～D 计数实测表（卡面值 / 实测值）

口径：与测试 `strippedSource` 同口径（剔 `//` 注释与字符串字面量内容），执行端脚本 `scratchpad/ic169-exec/count.py` 读工作树文件、调用 `Tasks/decision-tools/strip.py` 的 `strip_text`（只读使用）。IC157 逐字切片为 `testIC157A_RealRangePathsByteIdentical` 的移植。

### 子项 A（`S1StateMachine.swift`）

| 项 | 卡面 | 实测 |
|---|---|---|
| IC157 逐字切片 | 35 行、逐字相等 | 35 行、`verbatim=True` |
| `allPendingDeletionAssetIDs` | 2 → 4 | 2 → 4 |
| `pendingDeletionAssetIDsByRangeID[` | 3 → 1 | 3 → 1 |
| `.intersection(` | 3 → 4 | 3 → 4 |
| `setMarked(` | 3 不变 | 3 |
| `publishSnapshotIfChanged()` | 6 不变 | 6 |
| `applyPendingDeletionDiff(` | 3 不变 | 3 |
| `private func applyPendingDeletionDiff(` | 1 不变 | 1 |
| `func makeS2Handoff(virtualRangeID:` | 1 不变 | 1 |
| `private(set) var activeVirtualRangeIDs: Set<String> = []` | 1 不变 | 1 |
| `func cancelS2Handoff(virtualRangeID: String)` | 1 不变 | 1 |
| `activeVirtualRangeIDs.remove(` | 2 不变 | 2 |
| 原文 `.retry()`／`Timer.scheduledTimer`／`return "` | 0／0／0 | 0／0／0 |
| 原文 `item16RecommendedCleanupArea`／`item17FileSizeSort`（IC128 存在性） | 存在 | 1／1 |

### 子项 B（`S1StateMachine.swift`）

| 项 | 卡面 | 实测 |
|---|---|---|
| `setMarked(` | 3（不变） | 3 |
| `allPendingDeletionAssetIDs` | 4 → 5 | 4 → 5 |
| `pendingDeletionAssetIDsByRangeID[` | 1 → 0 | 1 → 0 |
| 其余钉子（A 表同列各项） | 不变 | 全部同 A 表，逐字切片 35 行 `verbatim=True` |

### 子项 C（`SessionStore.swift`）

| 项 | 卡面 | 实测 |
|---|---|---|
| `setMarked(` | 3 不变 | 3 |
| `formIntersection(` | 1 不变 | 1 |
| `firstMarkedRangeIDByAssetID[$0] != nil` | 1 不变 | 1 |
| `.union(` | 1 → 0 | 1 → 0 |
| `formUnion(` | 1 → 2 | 1 → 2 |
| `subtract(` | 0 → 1 | 0 → 1 |
| `allPendingDeletionAssetIDs(in: nextState)` | 2 → 3 | 2 → 3 |
| `S1StateMachine.swift` 全部计数 | 不变 | 与 B 后逐行相同 |

（参考，未在卡面：`subtracting(` 4 → 5。）

### 子项 D（`S1StateMachine.swift`）

| 项 | 卡面 | 实测 |
|---|---|---|
| `pendingDeletionCount(` | 1 → 0 | 1 → 0 |
| `allPendingDeletionAssetIDs` | 5 → 6 | 5 → 6 |
| `.intersection(` | 4 → 5 | 4 → 5 |
| 其余钉子 | 不变 | `setMarked(` 3、`publishSnapshotIfChanged()` 6、`applyPendingDeletionDiff(` 3、`private func applyPendingDeletionDiff(` 1、`func makeS2Handoff(virtualRangeID:` 1、`activeVirtualRangeIDs` 声明 1、`cancelS2Handoff` 1、`.remove(` 2、原文三项 0；逐字切片 35 行 `verbatim=True` |

**全部逐条相符，无一处偏差。**

## 七、3 处既有断言旧 → 新（全部在白名单内，按卡原文）

| 文件:行（基线） | 测试函数 | 旧 | 新 | 子项 |
|---|---|---|---|---|
| `S1StateMachineTests.swift:723-726` | `S1DateTreeTests.testIC127A_YearAndMonthNodesEachFormValidS2Handoff` | `makeS2Handoff(for: "m2026-03")?.pendingDeletionAssetIDs` == `[]` | == `Set(["a3a"])`（同函数 `:693`／`:708` 两行注释同改） | A |
| `IC157LongPressIntoS2Tests.swift:650` | `testIC157A_RealRangePathsByteIdentical`（`realHandoffBodyLines` 第 11 个元素） | `"            sessionStore.pendingDeletionAssetIDsByRangeID[range.id] ?? []",` | `"            sessionStore.allPendingDeletionAssetIDs.intersection(assetIDSet)",`（`:638` 文档注释同改） | A |
| `IC129ExistenceReconciliationTests.swift:131-133` | `testIC129B_AssetMarkedInTwoDimensionsIsPrunedFromBothRanges` | `pendingDeletionAssetIDsByRangeID["相册-1"]` == `["资产-1"]` | `… ["相册-1"] ?? []` == `[]`（上方加一行注释） | B |

三条在 #355、#356、#357 均 passed。

## 八、闸门 G969～G974

- **G969（交接）通过**：断言 1 `testIC169A_HandoffPendingSetIsBasketIntersectedWithList` passed（#356／#357）；子项 A 计数相符（第六节）；IC157 断言 3 `testIC157A_RealRangePathsByteIdentical` 与 `S1DateTreeTests.testIC127A_YearAndMonthNodesEachFormValidS2Handoff` passed（#355／#356／#357）。
- **G970（镜像）通过**：断言 2 `testIC169B_UnmarkInAnotherRangeRemovesFromBasketEverywhere`、断言 3 `testIC169B_UnmarkThenRemarkWritesCurrentRangeAndMovesFirstMark` passed；子项 B 计数相符；`testIC129B_AssetMarkedInTwoDimensionsIsPrunedFromBothRanges`、IC157 断言 1 `testIC157A_VirtualHandoffBuildsInAnyStateAndRegistersName`／断言 2 `testIC157A_VirtualRangeLiveMirrorAndReturnBypassRangeGates`、IC163 A 三条（`testIC163A_RealRangeReturnUnchanged`、`testIC163A_VirtualRangeReturnKeepsBasketOutsideHandoff`、`testIC163A_VirtualRangeUnmarkInsideHandoffStillWorks`）、`IC132SubmissionDeadEndTests` 五条与 `IC132S1RangeNamePersistenceTests` 四条 passed。
- **G971（写回）通过**：断言 4 `testIC169C_LookOnlyRoundTripWritesNothingIntoRange`、断言 5 `testIC169C_ReturnAppliesBothRulesAndKeepsFirstMarkGuard` passed；子项 C 计数相符；`SessionStoreTests.testIC043_011InvalidS2ReturnLeavesWholeStoreUnchanged`／`testIC043_012ValidS2ReturnAtomicallyWritesPendingSetAndContinuation`、FullFlow `testIC048_001`～`006` 六条、`S1SessionPersistenceTests` 六条、`IC131S1WriteBackToastTests` 五条 passed。
- **G972（角标）通过**：断言 6 `testIC169D_RangeBadgeCountsBasketWithinRange` passed；子项 D 计数相符；`S1StateMachineTests.testIC046_018RangeRowContainsAllFourRequiredValues`（`:404`）与 AlbumScope `:575` 所在的 `S1ReconciliationTests.testIC127C_ExternallyDeletedAssetIsPrunedFromMAndF` passed。
- **G973（合并前置）通过**：
  - G969～G972 如上；
  - `git diff --name-only f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830 bf9551eb4b45633ca78ab124360e959e6cbb49a2` 恰 **7** 路径：`PhotoCleanupMVE.xcodeproj/project.pbxproj`、`PhotoCleanupMVE/Core/S1StateMachine.swift`、`PhotoCleanupMVE/Core/SessionStore.swift`、`PhotoCleanupMVETests/IC129ExistenceReconciliationTests.swift`、`PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift`、`PhotoCleanupMVETests/IC169MarkedStateFollowsBasketTests.swift`、`PhotoCleanupMVETests/S1StateMachineTests.swift`；
  - 「不得打红」段两侧对象（第九节表）全部相同；
  - 二十一条被保护分支 tip 开工时与合并前两次 `ls-remote` 全部与卡面短 SHA 相符（第十节）；合并前除本分支与 `main` 外全部 93 条远端分支头与开工时逐条相同；
  - 两次 CI 绿（第四节）；
  - pbxproj 撞号扫描通过（第十一节）；
  - 工作树净；`main` 未被他人推进（合并前 `ls-remote` 仍为 `f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830`）。
  - 合并：Bash 工具 `git switch main` + `git merge --no-ff feature/ic-169-marked-state-follows-basket -m …` 一次通过、未被拒；`git push origin main` 一次通过（`f4db22b..3cad2e2`）。
- **G974 通过**：合并后 `main` 自动运行 **#357**（run id `36260502037`），success，905／0，分段耗时 `模拟器启动 81 s；xcodebuild test 448 s；总 530 s`，artifact `PhotoCleanupMVE-unsigned-3cad2e2e47d1`（id 10912301344，2026-12-25T17:51:21Z 到期）。

## 九、「不得打红」段对象比对（基线 `f4db22b` vs E `bf9551e`）

| 路径 | 基线对象 | E 对象 | 结论 |
|---|---|---|---|
| `PhotoCleanupMVE/App` | `4f313aea6f6c6a3800b5cec5a2472359421343ff` | 同左 | 相同 |
| `PhotoCleanupMVE/Services` | `82320c200eea1ecd13c3c1e54acf1e0670b70f8b` | 同左 | 相同 |
| `PhotoCleanupMVE/Features` | `40e1710fd685cbe8718707556a9f50d52000f1cd` | 同左 | 相同（含 `S1View.swift` `99dd6a9ba1170c3b3dcedc26fec2e22850912eb3`、`S2Calibration.swift` `992816e511291a547d43d5baee4eeefdb5f2a858`） |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | `3af1ca0b5f040cd5cb80a77793a21973834849bd` | 同左 | 相同 |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | `0d8371c60f90c5334b3c50215042ea8e296fbcd9` | 同左 | 相同 |
| `Core/` 其余（`AssetModels`、`L10n`、`S0／S3／S4／S5StateMachine`） | — | — | 逐文件相同 |
| `PhotoCleanupMVE/Localizable.xcstrings` | `80dcb2cf21e0a177b2a3f6b867626eb8e34d29f9` | 同左 | 相同（目录 259） |
| `.github` | `74088388c62a10eb277921ecf74e766a2d407e80` | 同左 | 相同 |
| `Scripts` | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同左 | 相同 |
| `PhotoCleanupMVETests/` 既有 52 个文件 | — | — | 只有白名单内 3 个不同（`IC129…`、`IC157…`、`S1StateMachineTests`），其余 49 个逐文件相同 |
| `schemaVersion` | 7 | 7 | 相同 |

## 十、被保护分支（21 条，开工时与合并前各 `ls-remote` 一次）

`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`——**21／21 与远端头前缀相符**，合并前复查未变。

## 十一、子项 E：测试文件与 pbxproj

- 拷入：`cp <top>/Tasks/decision-tools/IC169MarkedStateFollowsBasketTests.swift PhotoCleanupMVETests/`；`cmp` 与源文件逐字节相同；`git hash-object` 实测 = **`fc353710400e256b57f0d3ea81667c267cb30174`**（与卡面相等）；提交后 `git rev-parse bf9551e:PhotoCleanupMVETests/IC169MarkedStateFollowsBasketTests.swift` 同值。未改任何一行。
- 六条新断言与函数名（#356、#357 均 passed）：
  1. `testIC169A_HandoffPendingSetIsBasketIntersectedWithList`
  2. `testIC169B_UnmarkInAnotherRangeRemovesFromBasketEverywhere`
  3. `testIC169B_UnmarkThenRemarkWritesCurrentRangeAndMovesFirstMark`
  4. `testIC169C_LookOnlyRoundTripWritesNothingIntoRange`
  5. `testIC169C_ReturnAppliesBothRulesAndKeepsFirstMarkGuard`
  6. `testIC169D_RangeBadgeCountsBasketWithinRange`
- pbxproj 撞号扫描（登记前重扫，含十六进制号段）：`main` 上 1 号段最大 `100000000000000000000075`、2 号段最大 `200000000000000000000072`；新 id `100000000000000000000076`／`200000000000000000000073` 登记前出现 0 次。照 IC172 测试文件四行写法各复制一行：登记后 `…076` 恰 3 处、`…073` 恰 2 处；对象定义行（254 行）`uniq -d` 为空。

## 十二、摘取关系实测（本机克隆 `scratchpad/ic169-exec/pickclone`，自 `f4db22b` 起 `cherry-pick -x`）

| 摘取单元 | 结果 | 与分支对应提交树 |
|---|---|---|
| A 单独 | 无冲突 | 树 `883821e697a7944c7b3b3fba17206d9a933296a1` = `50ae2db` 的树 |
| D 单独 | 无冲突（只改 `S1StateMachine.swift`） | — |
| A→B→C | 无冲突 | 树 `efe6f0975e642a1aef4975593fdae0922a8fc369` = `77cd14b` 的树 |
| （附）B 单独、C 单独 | 文本上均无冲突 | 卡面按语义链只允许连续序列摘取，这两种只作记录，不构成可摘单元 |

## 十三、根因假设

本卡不含根因假设（行为变更卡）。卡内唯一的「③」是裁定五、六的残留与观感后果，见第十五节。

## 十四、规格欠账（按本卡实装，不算规格冲突；待 SPEC-S1 v11／S2 v23／S0 v5 回填）

1. SPEC-S1 v10 `:522`（及 `:848-850` 修订项 4）「`a ∈ D` ⟹ `M[r.id] := M[r.id] ∪ {a}`」——按 ④ 第 201 条 (b) 实装为「`a ∈ D` 且写入前不在 `D_全部` ⟹ 写本范围；已在篮的不写」；`:202`「在各自的 S2 里加标各写一次」随之收紧（同一资产新数据下只在一个 `M[g]` 里）。
2. SPEC-S1 v10 `:189`「`D_范围` 的语义 = 该范围的 S2 会话确认过的集合」——实装语义为「该范围 S2 会话里新标的集合」。
3. SPEC-S1 v10 `:195`「`待删计数(r)`：`M` 中 `r.id` 对应集合的元素数」、`:218`、`:442`——按 ④ (c) 实装为 `|D_全部 ∩ A(r)|`。**按结果实装、非字面实装**：Decision_log 第 200 条第五节字面写「改 `pendingDeletionCount(for:)` 的取数」，本卡按裁定四只改唯一生产调用点 `rangeRows`，`SessionStore.pendingDeletionCount(for:)` 本体不动（改本体需加 `A(r)` 形参，4 处直调测试会编译失败）。
4. SPEC-S2 v22 `:750` 与 SPEC-S0 v4 `:463`／`:327` 的写回口径随第 1 条改指向。
5. Decision_log 第 196 条第二节第 4 条「S1 列表不受影响」已被第 200 条 (c) 取代。

## 十五、③ 登记（待 H86）

- **裁定五残留 1**：IC-169 之前的老会话档里若已有「同一资产在两个 `M[g]` 里」，从首标范围对账移出后仍会判坏档（`F[a]` 停在不含它的范围，`SessionStore.init?` 拒绝）。新数据经断言 4 证实不再走到这条路径（夹具驱动）。
- **裁定五残留 2**：`markPendingDeletion` 没有「已在篮」守卫，靠分类器把篮内项排除在类别页之外，模型层可被夹具绕过。
- 两者要不要修（迁移 `F` 或补守卫）归下一张维护卡（牵涉 `SessionStoreTests` IC043-004、FullFlow IC127B 的期望与 v10 `:200`／`:204`）。
- **裁定六观感 1**：在另一范围的 S2 里先取消、再标回一张类别篮里的照片，它的首标范围改为当前范围，S3 里换组（断言 3 在夹具上钉住这一结果）。
- **裁定六观感 2**：S2 里把一张篮内照片加入相簿，它从 `D` 移出，按撤标全局它也从类别篮消失。

## 十六、人工判定项（H86 八条，保留给 Lynn 装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-3cad2e2e47d1`（#357）真机判，执行端不代为下结论）

1. 类别页把几张照片进篮 → 去「逐张整理」，进一个包含这些照片的月份：这几张在看图页里都显示**已标记**（中间「已标记｜撤销」、底部横栏有标记），顶上垃圾桶徽标数不变。
2. 在那里下滑取消其中一张 → 回「空间清理」进同一个类别页：那张回到网格、不在篮里，徽标减一。
3. 在类别页长按一张进看图页、上滑标记 → 去「逐张整理」相应月份：同一张显示已标记。
4. 「逐张整理」范围列表：各月份封面右上的红角标 = 该月在篮里的张数（类别页进篮的也算），没进过的月份也显示。
5. 进一个月份看图、什么都不做就返回：角标不变；进 S3 看分组，那几张仍在原类别组里。
6. 在月份看图页里先取消一张类别篮里的照片、再标回来：进 S3 看它现在在哪一组（按规则会换到该月份的组——能不能接受）。
7. 看图页里把一张篮内照片加入相簿：它从篮里消失，回类别页它回到网格（按规则如此——能不能接受）。
8. 一两句总评。

## 十七、发现但未处理（按纪律只报告不修）

1. **B 单独、C 单独在文本上也能无冲突摘取**（第十二节）。卡面按语义把 A→B→C 定为只能连续摘取，这一点不变；只记录「文本可摘 ≠ 语义可摘」，避免日后有人凭 `cherry-pick` 无冲突就单摘 B 或 C。
2. **决策会话预演脚本 `sim_ic169.py` 的全字面量差分**在基线上列出 9 条「产品文件计数变化、且该字面量出现在某测试文件里」的 needle（如 `'SessionStore'` 原文 15 → 16、`'value'` 0 → 1、`'count'` 16 → 17、`'pendingDeletionAssetIDsByRangeID'` 11 → 9 等），另 1 条是 IC157 逐字块元素本身（卡内已改）。这些字面量只是在测试文件里出现，执行端未逐一追查它们在测试里是否被当作针对这两个产品文件的计数 needle；两次 CI 905／0 全绿，说明没有测试因此翻红（①在 CI 上）。只作记录。
3. **`testIC063` 的 build 行不在该用例块内**：三次运行里 `IC063_WARMUP_GATE_BEGIN`／`END` 块内都没有 `building pipeline` 行；全日志唯一一条 build 行（`primitive_coverage-…`，0.60～1.24 s）落在稍后的 `testIC085R3RenderedStripHasNoBackgroundInsideItemFrames` 块内，该用例三次均 passed。与陷阱 26 的既有描述（build 行在 IC063 预热段内）形态不同，只作观察。
4. 本机仓库 `core.autocrlf=true`；本卡改动的全部文件与拷入的测试文件均为 LF（执行端脚本对每次读写断言无 CRLF），`git hash-object` 与 `--no-filters` 两种口径同值，未受影响。

## 十八、40 位 SHA 核验（`git cat-file -e`）

报告写完后，对本报告与 `change-list.md` 中出现的全部 40 位 SHA（去重 24 个）先 `git cat-file -t` 取类型、再 `git cat-file -e <sha>^{<类型>}`，**全部存在**：

```
0d8371c60f90c5334b3c50215042ea8e296fbcd9 blob OK
39dc8d0be448ea051f37fdb99be8dbae3d35ca35 commit OK
3af1ca0b5f040cd5cb80a77793a21973834849bd blob OK
3cad2e2e47d1a13249f5370a0e47f283b9967c69 commit OK
40e1710fd685cbe8718707556a9f50d52000f1cd tree OK
43cf1ffec2e9cc3b619b178ff3ba3a0f060d1962 blob OK
4f313aea6f6c6a3800b5cec5a2472359421343ff tree OK
50ae2dbe6a6cf80929b6aa55f3f727034ba21d81 commit OK
514886dc0afc4083237c976c0f7be6ce597c50a8 tree OK
71d03fa00efb88d2d62ab6c128b2a2933d5a9c3b commit OK
74088388c62a10eb277921ecf74e766a2d407e80 tree OK
77cd14b65aa81a41a06a341553ac6019424ca3ee commit OK
80dcb2cf21e0a177b2a3f6b867626eb8e34d29f9 blob OK
82320c200eea1ecd13c3c1e54acf1e0670b70f8b tree OK
883821e697a7944c7b3b3fba17206d9a933296a1 tree OK
98432dde8103944a7910c8a67cee268895eb6e53 blob OK
992816e511291a547d43d5baee4eeefdb5f2a858 blob OK
99b39f25cebf14582aa2ed6dad1c828a83fd1b2d commit OK
99dd6a9ba1170c3b3dcedc26fec2e22850912eb3 blob OK
bf9551eb4b45633ca78ab124360e959e6cbb49a2 commit OK
df294efcd4a8c00f1a32bd3b4d6241eebb8c81c7 tree OK
efe6f0975e642a1aef4975593fdae0922a8fc369 tree OK
f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830 commit OK
fc353710400e256b57f0d3ea81667c267cb30174 blob OK
```
