# IC-146 自验报告 · S2 chrome 二轮（底排改组、氛围底、「已标记 · 撤销」、退后台停用音频会话）

## 结论（先行）

- **四个子项全部实装并合并。** CI **#290**（run id `34834044476`，attempt 1）绿，被测提交 `f72a7f4bc542ba7162c5c11b2ce586fc2d1626d6`，**XCTest 761 项 0 失败**，真实退出码 **0**，目的地 `OS:26.2, name:iPhone 16`，Xcode 26.3。基数 741 + 本卡新增 **20** = 761。
- **断言 1～17 全部落地并在 CI 日志逐条 `passed`**（函数名与日志读数见第五节）。
- **G839 / G840 / G841 全过**，已按卡内授权 `--no-ff` 合并入 `main`：合并提交 `d753fc5a31f5e7e2760b88d1ab842949de5a80bc`。
- **CI 预算 3 次，实用 2 次**（#289 红 → 修 → #290 绿），另有合并后 `main` 上的自动运行（G842，见第三节）。
- **#289 的 5 项失败里有一项是实现缺陷，不是测试问题**：氛围底的颗粒层原用 `.ultraThinMaterial`，系统材质随 trait 变，与决策 61「恒为深色配方、不随系统外观切换」直接相悖。已改为确定性噪点贴图（第七节）。
- **一处越界已获补充授权**：`S2NativePhotoPager.swift` 的 `bottomCapsuleCenter`。卡内白名单原漏列该文件，执行端停下发问后由决策会话裁定补授，**不是执行端自行扩权**（第六节单列）。
- **H69 六项真机判定留给 Lynn**，执行端不代为下结论（第十节原样列出）。

---

## 一、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260914-146-s2-chrome-round-two.md` |
| 规格依据 | SPEC-S2 v20（SHA-256 `08B4B874…6403`，本机实测一致）回写决策 60／61／62；SPEC-S0 v1（SHA-256 `F5D64365…2282`，本机实测一致）第十四节 `S0Ambient`；Decision_log 第 161 条 ③、第 166 条 |
| 继承提交（`main` tip） | `98e76c90e42d52817e1f59f818412a5f0688127b` |
| 开工核对 1 | `git log --oneline -1 main` → `98e76c9 docs: IC-144 回填 G834/G835（…）`，标题以 `docs: IC-144` 开头 ✅ |
| 开工核对 2 | `git merge-base --is-ancestor ff7885b6fe5c381395d79217c29243b8e8ac8bf9 main` → 退出码 **0** ✅ |
| 开工核对 3（纪律 8） | `git status --porcelain` → **空输出** ✅ |
| 目标分支 | `feature/ic-146-s2-chrome-round-two` |
| 分支 tip（被测） | `f72a7f4bc542ba7162c5c11b2ce586fc2d1626d6` |
| 合并提交 | `d753fc5a31f5e7e2760b88d1ab842949de5a80bc` |
| 现状基数 | `main` 上 XCTest 741 项（IC-144 #287）。探针分支 `probe/ic-145-scan-service` 的 755 项**不是**本卡基数，该分支不合并 |

提交清单见 `change-list.md` 第一节（含两处与「四项各自独立 commit」的偏差登记）。

---

## 二、CI（预算 3 次，实用 2 次）

### 2.1 #290（绿，被合并的那一次）

| 项 | 值 | 来源 |
|---|---|---|
| 运行编号 | **#290** | `actions/runs/34834044476` → `run_number` |
| run id | `34834044476` | 同上 |
| run_attempt | `1` | 同上（无重跑） |
| 被测提交完整 SHA | `f72a7f4bc542ba7162c5c11b2ce586fc2d1626d6` | 同上 → `head_sha` |
| 结论 | `success`（10 个步骤全 `success`） | `actions/runs/34834044476/jobs` |
| XCTest 项数 / 失败数 | **761 项 / 0 失败（0 unexpected）**，59.934 (122.984) 秒 | check-run `103943689246` 的 `notice`；日志同行 |
| 摘要 notice 存在（陷阱 20） | ✅ `##[notice]	 Executed 761 tests, with 0 failures (0 unexpected)` | 日志 `10:43:30.0092630Z` |
| 真实退出码 | **0** | `ci.yml` 的「运行 XCTest」步骤以 `exit "$test_status"` 原样退出，该步骤 `conclusion = success`；日志另有 `XCTest 已全部通过。`（`10:43:27.9132290Z`） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` | 日志 `10:37:12.5351130Z` |
| 目的地 xcodebuild 回显 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-…, OS:26.2, name:iPhone 16 }` | 日志 `10:37:16.1284450Z` |
| 工具链 | `已选择工具链：/Applications/Xcode_26.3.0.app` | 日志 `10:36:56.1161840Z` |
| IPA 字节数 | **1423853** | `notice`「未签名 IPA 校验」；日志 `10:44:55.9008180Z` 同值 |
| IPA SHA-256 | `a83a93311104d892fdf354884e44ff752043297b9af4421b7b05fdf6ed5e9bde` | 同上 |
| 上传产物 | `PhotoCleanupMVE-unsigned-f72a7f4bc542`，1424023 字节（zip 外壳） | `actions/runs/34834044476/artifacts` |

**项数口径（陷阱 22）**：761 取自 CI 日志的 `Executed N tests` 执行摘要，不是本机 grep。741 + 20 = 761，与摘要一致。

### 2.2 #289（红，第一次主跑）

| 项 | 值 |
|---|---|
| 运行编号 / run id | **#289** / `34832076119` |
| 被测提交 | `2ccd595e6ba0c38ab8363324be47ff8c0b35f0f3` |
| 结论 | `failure`（步骤 7「运行 XCTest」failure，8／9 skipped） |
| 执行摘要 | `Executed 761 tests, with 7 failures (0 unexpected)` |

**编译通过**（761 项跑完），7 次失败事件来自 **5 个用例**。全部失败用例由日志逐条枚举（`Test Case … failed` 去重），不是只看被截断的 annotation 列表：

```
IC141VideoPlaybackTests   testIC141B_OnlyVideoPagesCarryALayerAndSingleTapNeverTouchesPlayback
IC143VideoPolishTests     testIC143B_EveryAbnormalScrubExitGoesThroughOneCollector
IC146ChromeRoundTwoTests  testIC146B_AmbientAddsNoGeometryWrite
IC146ChromeRoundTwoTests  testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes
S2CalibrationHarnessTests testIC067G39ViewportBackgroundTracksInterfaceStyle
```

四处根因与修法见第七节。

---

## 三、G842 · 合并后 `main` 的自动运行

| 项 | 值 | 来源 |
|---|---|---|
| 运行编号 | **#291** | `actions/runs/34835158571` → `run_number` |
| run id | `34835158571` | 同上 |
| run_attempt | `1` | 同上 |
| 被测提交 | `d753fc5a31f5e7e2760b88d1ab842949de5a80bc`（合并提交） | 同上 → `head_sha` |
| 结论 | **`success`**（10 个步骤全 `success`） | `actions/runs/34835158571/jobs` |
| XCTest 项数 / 失败数 | **761 项 / 0 失败（0 unexpected）**，48.304 (96.523) 秒 | check-run `103947199497` 的 `notice` |
| IPA 字节数 | **1423853** | 同上「未签名 IPA 校验」 |
| IPA SHA-256 | `2b3c36e2f2ac394df08c24edfd120311be0087a325de66273f859f295699457c` | 同上 |
| 上传产物 | `PhotoCleanupMVE-unsigned-d753fc5a31f5`，1424023 字节 | `actions/runs/34835158571/artifacts` |

**G842 通过**：合并后 `main` 上的自动运行 #291 绿，项数与 #290 一致（761 项 0 失败）。

> **两条注记**：
> ① #291 的 IPA **字节数与 #290 相同（1423853）但 SHA-256 不同**——IPA 归档不可复现是本仓既有结论（IC-094／097 实证），**不得拿 IPA 哈希做跨运行的同一性判定**，同一性应看 tree diff。
> ② 取 #291 的注解时必须用它**自己**的 check-run id（`103947199497`）。沿用上一次运行的 id 会取回 #290 的注解——本次首取就撞上了这个坑，是靠「两次 IPA SHA-256 完全相同」这条与既有结论相悖的读数发现的，已改为逐运行重取 `jobs` 再取注解。

---

## 四、本地门禁

| 门禁 | 退出码 | 关键输出 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | `结构自验通过：…及不少于 189 项测试的数量门禁均符合要求。` |
| `Scripts/scan-hardcoded-user-visible-strings.ps1`（selfcheck 内联调用，CI 另单独跑一遍） | **0** | `目录条目：215`／`产品源码引用 key：215`／`用户可见硬编码残留：0` |
| `git diff --check` | **0** | 无输出 |

本机是 Windows、无 Xcode（CLAUDE.md 第五节），**不能在本地跑 XCTest 或构建 IPA**；第二、三节所有模拟器读数均来自 GitHub Actions。

---

## 五、逐条验收门禁

### G839 · diff 限于白名单，三处零改动

`git diff --name-only main...HEAD`（合并前）的**完整**结果，9 个文件，白名单外 **0** 个：

```
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift
PhotoCleanupMVETests/S2ActionBarWiringTests.swift
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
```

**顶排三件零改动**——按符号块做花括号配平提取后取 SHA-256（`main` 侧 vs 分支侧）：

| 符号 | `main` SHA-256 | 分支 SHA-256 | 相同 |
|---|---|---|---|
| `topBar` | `6E69951E462B87540C9D6F619542C56D1F028CB76F441B0A4E2A4BD064F9AA0B` | 同左 | ✅ |
| `topBarRow` | `D7B9000934470C9DF19DB78788BADF1850550796D860A551F69FA02920D3EEBF` | 同左 | ✅ |

**`S2LivePhotoPlayback.swift` 两侧 SHA-256**（整文件）：

| 侧 | SHA-256 |
|---|---|
| `main` | `3092C28208F4E6D316787E92F9F895CF34A10EBE849C8C1DCE3EC212D4FD1E12` |
| 分支 | `3092C28208F4E6D316787E92F9F895CF34A10EBE849C8C1DCE3EC212D4FD1E12` |
| 相同 | ✅ |

**`S2NativePhotoPager.swift` 的三项计数与 hunk 归属**：

| 项 | `main` | 分支 | 相同 |
|---|---|---|---|
| `writePhotoGeometry` | 5 | 5 | ✅ |
| `backgroundColor = .clear` | 7 | 7 | ✅ |
| `.clear` | 8 | 8 | ✅ |

该文件的 diff hunk 共两个，hunk header 均为 `enum S2AlbumAfterimageFlight`，即全部落在那一个 enum 内（卡内 G839 收紧项）：

```
@@ -1187,3 +1187,12 @@ enum S2AlbumAfterimageFlight {
@@ -1207 +1216,2 @@ enum S2AlbumAfterimageFlight {
```

**G839 通过。**

---

### G840 · 边界与既有取值

| 项 | 结果 | 实证 |
|---|---|---|
| `S2Calibration.swift` 在 diff？ | **否** | diff 文件清单中无该文件 |
| `schemaVersion` | **仍 7** | `PhotoCleanupMVE/Features/S2/S2Calibration.swift` → `static let schemaVersion = 7` |
| `Services/` | **零改动** | diff 文件清单中无 `PhotoCleanupMVE/Services/` 路径 |
| S1 / S3 / S4 / S5 | **零改动** | diff 文件清单中无 `Features/S1`、`Features/S3`、`Features/S4`、`Features/S5` 路径 |
| 冻结三链与探针分支 | **远端 tip 未变** | `git ls-remote` 实读（见下） |

```
b368a6caee846e664391b0620350395bfe6fbc7f  refs/heads/feature/ic-089-nx-edge-bounce
6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d  refs/heads/feature/ic-091-nx-midgesture-handoff
a7cc1ec727a3a493f5263e688a316cbf4c743562  refs/heads/feature/ic-092-nx-window-follow
486bcb769b59eb1146c5a231c7998847206777cc  refs/heads/probe/ic-137-media-playback
d373afc7125104c01acfc296829229090e6871ce  refs/heads/probe/ic-145-scan-service
```

前三条与 CLAUDE.md 第七节登记的短 SHA（`b368a6c` / `6736f1e` / `a7cc1ec`）逐一相符；`probe/ic-137` 与登记的 `486bcb7` 相符；`probe/ic-145` 为 IC-145 收口时的 tip，本卡未触碰。

**决策 46／53 的六项既有取值原样**（`Features/S2/S2View.swift` 实读行）：

```
4919:    static let transitionSeconds: TimeInterval = 0.2
4920:    static let hiddenScale: CGFloat = 0.9
4923:    static let removedNoticeSeconds: TimeInterval = 1.2
4927:    static let albumIndicatorDelaySeconds: TimeInterval = 0.42
4761:    static let containerHeight: CGFloat = 46
4762:    static let horizontalPadding: CGFloat = 12
4758:    static let separatorColor = Color.white.opacity(0.3)
4754:    static let backgroundColor = S2PendingDeletionMark.circleColor
4755:    static let foregroundColor = S2PendingDeletionMark.symbolColor
```

**G840 通过。**

---

### G841 · 合并前置

| 条件 | 结果 |
|---|---|
| G839 / G840 | ✅ 见上 |
| 绿（全部 XCTest 通过、退出码 0、摘要 notice、iOS 26.2 / iPhone 16、IPA 登记） | ✅ 见第二节 |
| 断言 1～17 逐条给函数名并在日志核 `passed` | ✅ 见下 |
| 工作树净 | ✅ `git status --porcelain` 空输出 |
| `main` 未被他人推进 | ✅ `git ls-remote origin refs/heads/main` = `98e76c90e42d52817e1f59f818412a5f0688127b`，与本地 `main` 一致 |

**G841 满足 → 已 `--no-ff` 合并并推送**，合并提交 `d753fc5a31f5e7e2760b88d1ab842949de5a80bc`；推送后 `git ls-remote origin refs/heads/main` = `d753fc5a31f5e7e2760b88d1ab842949de5a80bc`。

---

## 六、断言 1～17 逐条对账

全部取自 #290 日志的 `IC146ChromeRoundTwoTests` 区间，20 个函数**全部 `passed`，无 `failed`、无 skipped**。

| 断言 | 卡内要求 | 测试函数名 | CI 日志 |
|---|---|---|---|
| **1** | 底排三件的呈现模型对四种情形正确；无最近相簿时中位为单一「+」圆钮且不含分隔线（正对照：有最近相簿时含分隔线恰 1 条） | `testIC146A_AlbumTrackPresentationCoversFourCases`<br>`testIC146A_TrackFormFollowsActionBarPresentationAuthority` | `passed (0.001 seconds)`<br>`passed (0.002 seconds)` |
| **2** | 跑道圆两半与分享各带独立点击目标与 ≥ `minimumTouchTarget` 命中区；`actionBarRow` 内 `Button` 数 4 | `testIC146A_TrackHalvesAndShareCarryTouchTargets` | `passed (0.036 seconds)` |
| **3** | 改前后底排的行高、左右边距、底缘锚、`minimumSpacing` 逐个相等 | `testIC146A_ActionBandGeometryUnchanged` | `passed (0.003 seconds)` |
| **4** | 触发分享入口后 `V`、`s`、`c`、`D` 与播放状态逐个不变；两台 reducer 无任何效果产生 | `testIC146A_ShareLeavesEveryStateUntouched`<br>`testIC146A_ShareDiscardsFailedAndStaleResolutions` | `passed (0.001 seconds)`<br>`passed (0.003 seconds)` |
| **5** | 残影落点 = 跑道圆左半中心（正对照：≠ 整只中心）；**并加不变量**：同一视口下相簿名极短与极长两种，落点 x 相同 | `testIC146A_AfterimageLandsOnTrackRecentHalfCenter` | `passed (0.002 seconds)` |
| **6** | 氛围底在主图之下、`interfaceOverlay` 之上的次序不变；`allowsHitTesting == false`；分页器各层仍 `.clear` | `testIC146B_AmbientSitsBelowPhotoAndTakesNoTouches` | `passed (0.033 seconds)` |
| **7** | `writePhotoGeometry` 计数仍 5，静止状态无新增写入 | `testIC146B_AmbientAddsNoGeometryWrite` | `passed (0.011 seconds)` |
| **8** | `S2AmbientMetrics` 十个常量与 SPEC-S0 v1 `S0Ambient` 逐个相等；定义行含出处注释（正对照：任一常量写成裸数即失败） | `testIC146B_AmbientMetricsMatchS0AmbientRegistry` | `passed (0.004 seconds)` |
| **9** | 深色与浅色两种 `colorScheme` 下氛围底配方取值相同 | `testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes` | `passed (0.005 seconds)` |
| **10** | 取图失败时氛围底为 `ambientBaseColor` 纯色，主图呈现不被延迟 | `testIC146B_AmbientFallsBackToBaseColorWhenLoadFails` | `passed (0.005 seconds)` |
| **11** | `showsUndoControl(for: .marked) == true`；`.marked` 含四件、与 `.addedToAlbum` 同构（正对照：`.removed` 仍单段文本、无撤销钮） | `testIC146C_MarkedBecomesCapsuleWithUndo` | `passed (0.041 seconds)` |
| **12** | `.marked` 的撤销闭包与下滑取消调同一个函数（各 1 次）；`undoAlbumAdditionFromCenterIndicator` 不出现在 `.marked` 路径内 | `testIC146C_MarkedUndoCallsTheSameSwipeDownEntry` | `passed (0.010 seconds)` |
| **13** | 撤销后整块消失、不产生 `.removed`（正对照：相簿撤回仍产生）；`D` 减一 | `testIC146C_MarkedUndoClearsMarkAndProducesNoRemovedNotice` | `passed (0.614 seconds)` |
| **14** | 六项既有取值逐个不变 | `testIC146C_ExistingIndicatorValuesAreUntouched` | `passed (0.003 seconds)` |
| **15** | 失活且会话激活时 `setActive(false)` 恰 1 次；未激活时 0 次 | `testIC146D_ResignActiveDeactivatesTheSessionExactlyOnce` | `passed (0.004 seconds)` |
| **16** | 回 active 未收到 `setActive(true)`；再点「有声」才收到 | `testIC146D_ReturningToActiveDoesNotReactivateUntilUserTapsUnmute`<br>`testIC146D_ResignActiveClearsUnmuteIntentInTheReducer` | `passed (0.001 seconds)`<br>`passed (0.001 seconds)` |
| **17** | `AVAudioSession` 在 `S2VideoPlayback.swift` 内只在生产实现处；另三个文件零命中 | `testIC146D_AVAudioSessionStaysInsideTheProductionImplementation` | `passed (0.019 seconds)` |

### C6 定位到的下滑取消入口函数（卡内未给名，须自行定位并写明）

**`S2StateMachine.handleSwipeDown()`**，`PhotoCleanupMVE/Core/S2StateMachine.swift:1423`。

- 全仓**唯一**一个该名函数（`func handleSwipeDown()` 计数 1）。
- 手势侧唯一调用点在同文件 `handleDrag(...)` 内：`? handleSwipeDown()`，计数 1。
- 子项 C 的撤销路径 `S2View.undoMarkFromCenterIndicator()` 调的就是它（`machine.handleSwipeDown()` 计数 1），**不另写一份取消逻辑**（陷阱 19）。

### 断言 3 的口径说明（陷阱 13）

断言对象是**布局模型** `S2OverlayLayoutSnapshot` 算出的**帧**（`bottomElementFrames`），不是常量本身。未走渲染帧逐像素比对：那需要给产品视图加测试专用探针，属「不为测试改产品」禁止项——该边界由 IC-100 B7 的 `testIC100B7SnapshotMatchesRenderDerivations` 注释立下并登记在案，本卡沿用同一口径。

### 断言 5 的不变量推导（①，决策会话验算，执行端复算一致）

跑道圆水平居中于「两圆钮之间的可用区间」，故

```
左半中心 = 可用区间中点 − (分隔线宽 + 右半宽) / 2
```

内容驱动的左半宽在推导中约去——这正是落点与相簿名长短无关的原因。测试以 `S2MediaMetrics.albumTrackRecentHalfCenterX(slotMinX:slotMaxX:recentHalfWidth:)` 对左半宽取 44 与 300 两种极端值复算，两者相等；并与 `bottomCapsuleCenter` 的实际返回值对上，且与整只中心不等（正对照）。

---

## 七、#289 的四处根因与修法

| # | 失败用例 | 根因 | 性质 | 修法 |
|---|---|---|---|---|
| 1 | `testIC141B_OnlyVideoPages…`、`testIC143B_EveryAbnormalScrubExit…` | 子项 B 另起了一条 `.onChange(of: machine.currentAssetID)`。IC-141 与 IC-143 都用 `onChangeBody(of: "machine.currentAssetID")` 截取回调体，而该 helper 取**第一处**匹配——新加的那条排在前面，两条断言截到的是氛围底的回调体 | **本卡实现的接线问题** | 把氛围底取图**并进既有那条页变更回调**，不为同一个信号挂两个观察点 |
| 2 | `testIC067G39…` | 氛围底颗粒层用了 `.ultraThinMaterial`——系统材质随 trait 变，与决策 61「恒为深色配方、不随系统外观切换」**直接相悖** | **实现缺陷，不是测试问题** | 改为平铺**确定性噪点贴图**（固定种子线性同余，中灰均值 128±24，`overlay` 下中灰近似恒等元，只加颗粒不改明度）；顺带去掉原先私造的 `grainOpacity * 0.06` 系数，改用登记值。断言 9 的禁用名单补进 `Material` / `ultraThin` 把这条锁死 |
| 3 | `testIC067G39…`（同上用例） | 该既有测试的口径随决策 61 作废——它测的是已被氛围底取代的 `systemBackground` 那一层 | **既有测试改口径** | 改测同一机制下的新不变量并改名，旧→新见 `change-list.md` 第三节 |
| 4 | `testIC146B_AmbientAddsNoGeometryWrite`、`testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes` | 本卡这两条断言的源码扫描**没剔注释**，被本文件自己的说明性注释命中（注释里就写着 `@Published` 与 `colorScheme`） | **本卡测试的扫描口径问题** | 新增 `strippedSource` 夹具，扫描前剔掉 `//` 注释与字符串字面量内容；换行照留，不把上下两行的记号粘成一个 |

**#289 的价值**：第 2 条是真机上会被 H69 第 3 项抓到的实现缺陷，靠一条既有的像素级测试先在 CI 上显影。

---

## 八、氛围底的取图手段与失败回落（卡内点名要写）

- **取图手段**：`PHImageManager.requestImage(for:targetSize:contentMode:options:)`，目标边长 **160**（`S2AmbientMetrics.sourceTargetEdge`）、`contentMode = .aspectFill`、`deliveryMode = .fastFormat`、`resizeMode = .fast`、`isNetworkAccessAllowed = false`、`isSynchronous = false`。模糊半径 34 之后分辨率没有意义，故只取缩略级。
- **不延迟主图呈现**（规格第 14 条）：`S2AmbientBackdropStore.load(assetID:using:)` **同步返回**，取图在独立 `Task` 里做；读数初值为 nil，氛围底此时即 `ambientBaseColor` 纯色。主图那一层与取图任务无任何时序耦合。
- **失败回落**：取不到图（资产不存在、只在 iCloud 未下载、请求失败）一律回 nil ⟹ 氛围底为 `ambientBaseColor` 纯色，并把 `failureCount` 加一（测试用）。**不重试、不阻塞、不弹提示**——规格未定失败提示，本卡不自造。
- **翻页时序**：切换瞬间先把读数置 nil（回落纯色），**不留上一张的图**——否则翻页瞬间会闪上一张的颜色；期间又翻了页的迟到结果一律按资产标识丢弃。
- **零几何写入的结构性保证**（陷阱 5）：取图协调器 `S2AmbientBackdropStore` **自身不发布任何变更**，发布的是单列出来的 `S2AmbientBackdropReadout`，且只有氛围底视图观察它。换图不会让 `S2View.body` 重算，也就不会经 `updateUIViewController` 重进分页器。同一手法见 IC-141 的 `S2VideoPlaybackReadout`。

---

## 九、发现但未处理的问题（按纪律只报告不修）

### 1.（①，**需决策**）Nx 下点「撤销」无效

- **事实**：中央指示的解析规则（`S2CenterIndicatorResolver.state`）**只按 `V` 门控，不按缩放门控**——`V=显示` 且当前张已标记时，即便 `s > 1`（Nx）也显示「已标记 · 撤销」胶囊。而 C6 那个入口 `handleSwipeDown()` 带 `zoomState == .oneX` 守卫，Nx 下直接返回 false。
- **后果**：Nx 下胶囊上的「撤销」按下去**什么都不会发生**。改前 `.marked` 是不可点的正圆，不存在这个问题；本卡把它变成可点元素后才显影。
- **本卡为何不改**：决策 62 明写「点撤销 = 取消当前张的标记，与下滑取消**完全等价**（同一个入口函数）」。按字面执行，Nx 下两者确实等价（都不动）。放宽 `handleSwipeDown` 的缩放守卫或给指示加缩放门控，两者都是**产品决策**，且 `Core/S2StateMachine.swift` 不在本卡白名单。
- **两条候选修法**（供决策会话裁定）：① 指示在 `s > 1` 时不显示（改解析规则，决策 46 的范畴）；② 撤销走一条不带缩放守卫的取消入口（改决策 62 的「同一入口函数」措辞）。
- **H69 第 4 项可能撞到**：若 Lynn 在放大态试撤销会发现无反应。

### 2.（①）主图加载中的不透明底仍是 `systemBackground`，会压在氛围底之上

- `S2TemporaryPhotoImageStrategy.swift:204` 在 `showsOpaqueLoadingBackground` 为真时铺 `S2ViewportBackground.color`（即 `systemBackground`）。氛围底换上之后，主图尚未解码那一瞬间这层不透明底会盖住氛围底，浅色外观下是一块白。
- **未处理**：该文件不在本卡白名单。
- **H69 第 3 项可能撞到**：「翻页时氛围底跟着换、不闪不卡」——若 Lynn 报告翻页时闪一下白/黑，多半是这里。

### 3.（①）分享的 URL 解析逻辑与 `AssetSizeProbeService` 重复

- `S2PhotoKitShareItemResolver` 的取 URL 语义（照片 `fullSizeImageURL`、视频 `AVURLAsset.url`、禁网络）与 `Services/AssetSizeScanner.swift` 内 `AssetSizeProbeService` 的 URL 途径同源，但后者只回字节数不回 URL，且 `Services/` 在本卡不可触碰，故另写了一份。
- **后果**：两处口径必须同步改。**未处理**：合并成一处要动 `Services/`。

### 4.（③）分享取项失败时没有任何用户反馈

- 取不到 URL（如资产只在 iCloud 未下载）时不呈现面板、也不提示，用户会以为按钮没反应。规格第 4 条未定失败行为，本卡不自造。
- **验证办法**：H69 第 2 项若在未下载的 iCloud 资产上试分享。

### 5.（②）跑道圆左半的入场与回弹动画只作用于左半，玻璃底不跟随

- A3／A6 要求入场动画与落点锚一并迁到左半，故 `opacity`／`offset`／`keyframeAnimator` 都挂在左半按钮上；跑道圆的玻璃底在外层 `HStack` 上，不跟着缩放。
- 观感是否合意**属视觉判定**，留给 H69 第 1 项。

### 6.（①）`S2AmbientMetrics.tintHue` 是执行端取定项

- SPEC-S0 v1 只登记了顶部冷色光晕的半径与不透明度，**未登记色相**。本卡取一枚偏冷的浅蓝灰 `(0.42, 0.52, 0.72)` 并登记于 `S2AmbientMetrics.tintHue`，注释写明「规格未登记、执行端取定」。
- 决策会话若要定案，改这一处即可。

---

## 十、人工判定项（H69）——原样列出，执行端不代为下结论

> 1. **底排**：左收藏、中相簿跑道圆（左半一键加最近相簿、右半「+」选相簿）、右分享，三件都好按；跑道圆左右两半各点十次都命中、不互相误触。没有最近相簿的范围里，中位是单个「+」圆钮。
> 2. **分享**：点分享出系统面板，分享的是当前这一张；关掉面板后 chrome 显隐、缩放、标记状态、视频播放状态都和点之前一样。视频页与实况页也各分享一次。
> 3. **氛围底**：主图之外不再是纯白／纯黑，而是当前照片的模糊色；翻页时氛围底跟着换、不闪不卡；**底排三件现在看起来和顶排一样有玻璃质感**（这是决策 61 的目的）。深色浅色两种系统外观下氛围底一样深。
> 4. **已标记撤销**：上滑标记后，画面中央出现「已标记 · 撤销」胶囊；点撤销即取消该张标记、胶囊消失；下滑取消仍照旧可用。连做五次不出错。
> 5. **退后台音频**：先在别的 App 放音乐 → 进 S2 翻到视频 → 点「有声」音乐停 → **按 Home 回桌面，音乐应恢复** → 再回 S2，视频是静音的，要再点「有声」才出声。
> 6. **回归**：H65 第 2～5、9 项与 H66 第 1、4 项各快过一遍。

**执行端补充的两条提示（不是判定项）：**

- 第 4 项请**在 1x 下试**。放大态（Nx）下撤销按钮目前无效，原因与两条候选修法见第九节第 1 条——那是已知的待决策边角，不是新缺陷。
- 第 3 项若看到翻页瞬间闪一下白或黑，多半是第九节第 2 条那层主图加载底色，不是氛围底本身。

---

## 十一、40 位 SHA 存在性核验

报告内每个 40 位 SHA 均来自实读命令输出（`git rev-parse`／`git log --format=%H`／`git ls-remote`／`actions/runs` 的 `head_sha`）。报告写完后对全部 40 位 SHA 跑 `git cat-file -e <sha>^{commit}`：

```
2ccd595e6ba0c38ab8363324be47ff8c0b35f0f3  EXISTS(commit)
4375e3e25263aec25244472122e3d1a9d1dd5df3  EXISTS(commit)
486bcb769b59eb1146c5a231c7998847206777cc  EXISTS(commit)
5326cb49b28c9204c50bcf5616a7bc279de3c740  EXISTS(commit)
6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d  EXISTS(commit)
92b061d6c14a5665fdae13d24ac003f857055655  EXISTS(commit)
98e76c90e42d52817e1f59f818412a5f0688127b  EXISTS(commit)
a7cc1ec727a3a493f5263e688a316cbf4c743562  EXISTS(commit)
b368a6caee846e664391b0620350395bfe6fbc7f  EXISTS(commit)
b46af86a6203a4337af5e474546ee5b7786879c7  EXISTS(commit)
d373afc7125104c01acfc296829229090e6871ce  EXISTS(commit)
d753fc5a31f5e7e2760b88d1ab842949de5a80bc  EXISTS(commit)
f72a7f4bc542ba7162c5c11b2ce586fc2d1626d6  EXISTS(commit)
ff7885b6fe5c381395d79217c29243b8e8ac8bf9  EXISTS(commit)
```

**14 个全部存在，0 个缺失**（含本卡 6 个提交、合并提交、两个基线提交，以及第五节 G840 贴出的冻结三链与两条探针分支的 tip）。

> **陷阱 15 当场命中一次**：初次核验时 `92b061d…` 的后 33 位是按短 SHA 补全的臆造值，`git cat-file -e` 报 MISSING；改取 `git log --format=%H` 的实读输出后为 `92b061d6c14a5665fdae13d24ac003f857055655`。本节的核验就是为抓这种事而设的，这次它抓到了。

第五节的分块 SHA-256（`topBar` / `topBarRow` / `S2LivePhotoPlayback.swift`）与 IPA SHA-256 不是 git 对象，不适用该核验；其来源分别为本机 `git show <rev>:<path>` 的逐符号哈希比对与 CI 的 `notice` 注解。
