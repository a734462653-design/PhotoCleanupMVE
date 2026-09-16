# IC-152 自验报告

## 一、结论（先行）

- **两个子项都已交付**，A 先于 B 各自独立 commit：A `ae2ae42`（拆除期状态机零次发布）、B `2655b24`（中间帧门禁硬下限 2、软目标 3／5、导出进度样本）。
- **CI #304（run id `35080037007`）attempt 2 全绿**：十一步全 success、真实退出码 **0**、**811 项 0 失败、1 个 launch**、目的地 `OS:26.2, name:iPhone 16`、IPA 1557377 字节。项数对账 805 + 6 = **811** ✔。
- **attempt 1 被 GitHub 以「超过 15 分钟作业时限」取消，但 811 项同样 0 失败**：测试本身只跑了 75 s，时间耗在构建完成到测试宿主启动之间一段 **10 分 38 秒**的静默（模拟器启动与装载）。attempt 2 对同一提交原样复跑，XCTest 步骤 356 s（attempt 1 为 804 s）。**一行代码没改。**
- **子项 A 修法选「取消」而非「抑制报告」**：收尾通往状态机的路有三条（完成回调、`scrollViewDidScroll`、`scrollViewDidZoom`），抑制只堵得住一条；取消不落几何，三条结构性地一起消失。R1～R5 逐条有断言（第四节）。
- **子项 A 的改前复现是读码结论加正对照实测，不是改前夹具的直接实测**：本机无 Xcode，任务卡又明令不单独推「改前复现」的 CI。依据与证据等级见第三节 3.1。
- **⚠ 未合并。** G870 以 G867 为前置，而 G867 未被字面满足：`S2NativePhotoPager.swift` 有**一处 hunk**落在白名单之外的 `makeReport()`（G9 所在函数）。这一处是 B2「报告里增加一行」的唯一落点——卡内白名单与 B2 自相矛盾。偏离已声明并说明理由；**是否接受由决策会话定**，执行端不在前置不满足时自行合并。合并所需三条命令见第十一节。
- **人工判定项 H74 四条原样保留给 Lynn**，执行端不代为下结论。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260915-152-diagnostic-path-dismantle-and-midframe-gate.md` |
| 基线 `main` | `0bedaea8d85ec4f7c40bfe8b4c9d6dd95cb9d462` |
| 开工核对 1 | `git merge-base --is-ancestor f319a22 main` 退出码 **0** ✔ |
| 开工核对 2 | `git ls-remote origin refs/heads/main` = `0bedaea8…` = 本地 ✔ |
| 开工核对 3 | `git status --porcelain` **空** ✔（纪律 8） |
| 惯例 13 复核 | 卡内点名的 D1～D7、K1／K2、G1～G10、T1～T4 逐个 grep，行号与卡内一致 ✔ |
| 分支 | `feature/ic-152-diagnostic-path` |
| 分支 tip（代码） | `2655b24ef128514e0d789ac59b155980814ffbd0` |
| 现状基数 | 805 项（CI #303）→ 本卡 **811** 项 |
| `schemaVersion` | **7，未动** |

范围边界：4 个路径；`Core/`、`Services/`、`App/`、`Features/S0／S1／S3／S4／S5`、`Features/S2/` 除分页器外、`.github/`、`Scripts/`、`Localizable.xcstrings`、`S2Calibration.swift` 各 **0** 命中。`Core/S2StateMachine.swift` 两侧 SHA-256 相同。详见 `change-list.md` 第二、三节。

---

## 三、子项 A：拆除期发布冲突

### 3.1 改前复现结论（G869）

**结论：改前拆除窗口内状态机发布 ≥ 1 次。** 证据分三层，等级分开标：

| 层 | 内容 | 等级 |
|---|---|---|
| 1 | 改前 `resetInteractionState()` 对每页调 `finishActiveDoubleTapTransition()`，与显示链接自然跑完时调的是**同一个函数**。该函数内没有任何分支依赖调用方；两个守卫 `page.index == machine.currentIndex`、`machine.scale > 1` 在夹具里均成立（断言 1 另有前置断言 `machine.scale > 1`） | ①（源码） |
| 2 | 同一夹具、同一起飞方式下，自然收口向状态机发布 **≥ 1** 次 | ②（断言 2 在 CI #304 两次 attempt 均 `passed`） |
| 3 | 由 1、2 ⟹ 改前拆除窗口发布 ≥ 1 | ③（逻辑推出；**改前夹具未在 CI 上直接跑过**，任务卡明令不推改前 CI，本机无 Xcode） |

**夹具确实触到了 D3 → D4 → D5 → K2 这条链**（卡内第 4 步要求先确认）：由第 2 层的正对照证明——若计数器或链条是死的，断言 2 必红。

读码时发现的一个夹具陷阱（已规避，见 3.2）：`beginDiagnosticDoubleTap` 把落点写死在视口正中。夹具几何是满视口的屏幕同比例截图，正中落点放大后内容恰好居中，`reportedViewportOffset()` 回报 `.zero`，与 `handleNativeDoubleTap` 写入的 `.zero` 相等，IC-095 R4「等值不发布」会把那次报告吞掉——**照卡用 `beginDiagnosticDoubleTap` 的夹具会触不到 K2 的写入点**，断言 1 的「0」将是空转。③ 推算：视口 300×600、基准 300×600、倍率 2、落点 (150, 300) ⟹ 目标偏移 (150, 300)，放大后内容中点 (300, 600)，回报 = (300 − 150 − 150, 600 − 300 − 300) = (0, 0)。

### 3.2 夹具取舍（声明式偏离，三处）

1. **落点换到左上区域** (30, 60)，照 `beginDiagnosticDoubleTap` 的同一套调用（`handleNativeDoubleTap` + `startDoubleTapTransition(durationOverrideSeconds:)`）自行起飞。左上落点放大后偏移被钳到内容边缘，回报偏移必不为零；这也是真机上随手双击最常见的情形。
2. **断言 1 的过渡时长取 3 s**：只需停在飞行中，越长越不怕 runner 卡顿让过渡在拆除前自然跑完。断言 2 照卡取诊断时长 1.0 s。
3. **拆除直调 `S2NativePhotoPager.dismantleUIViewController(_:coordinator:)`**，不经 SwiftUI（见 3.3）。

### 3.3 为什么不让 SwiftUI 来拆

卡内第 3 步写「让 SwiftUI 拆除分页器」。直调的是**同一个产品入口**——#292a1 崩溃栈第 22 帧 `static S2NativePhotoPager.dismantleUIViewController(_:coordinator:)`，D1 → D2 → D3 的代码路径完全相同。差别只在「谁来调」，而这正是夹具本就复现不了的部分（陷阱 1：致命退出要撞上 SwiftUI 视图图失效的时机）。直调的两点好处：

- **计数窗口精确对齐到拆除调用本身**。经 SwiftUI 拆除要把宿主换根视图，窗口里会混进 `S2View` 的 `onDisappear` 等无关收尾，「0」的含义就不干净了。
- **修复若不完整，直调给出的是一条干净的断言失败；SwiftUI 驱动的拆除则会在视图图失效期间发布，把整个测试宿主打崩**（#292a1 即如此），同一次 CI 里其余用例分段重跑、日志分段，还白费一次预算。

### 3.4 修法：取消，不是抑制（裁定 一由执行端选）

**选「取消」。** 读 D3 发现，收尾通往状态机的路不止卡内点名的完成回调一条：

| 路径 | 触发点 | 经过 |
|---|---|---|
| ① 完成回调 | `:2109` `owner?.doubleTapTransitionDidComplete(on: self)` | D4 → D5 → K2（卡内点名的那条） |
| ② 滚动回调 | 进入段落几何后 `:2077` `zoomScrollView.setContentOffset(…)` 校正（在 `isApplyingNativeState` 之外） | `scrollViewDidScroll` → `owner?.reportNativeViewport(from:)` → K2 |
| ③ 缩放回调 | `applyDoubleTapTarget` 的 `setZoomScale` | `scrollViewDidZoom` → `owner?.reportNativeViewport(from:)`（本次被 `isApplyingNativeState` 守卫挡住，但与 ② 同属「落几何即可能报告」） |

「抑制报告」只能在所有者一侧加标志堵 ①，② 与 ③ 仍要逐条确认；「取消」不落几何，三条路结构性地一起消失。拆除时这些几何也没有消费者：离开 S2 时协调器随即丢弃这只状态机（卡内 ①：`CleanupCoordinator.swift:878`／`:926`），下次进入另建一只。

**改动**：
- 新增 `cancelActiveDoubleTapTransition()`：只清每一层，与收尾逐层对应、同序（先交还播放层、再放开页内容、最后移走过渡视图）；不落几何、不回调所有者、不发事件。
- `resetInteractionState()` 顺序改为「诊断先退场 → 摘观察者 → 取消」。该函数全仓只有 `dismantleUIViewController` 一个调用点。
- `finishActiveDoubleTapTransition()` **一字未动**（本机逐字节比对与 `main` 相同），自然收口、零时长早收口、归一诊断态三处既有调用不受影响。

**有意没做的一件事**：取消不调丝滑度探针的 `recordDoubleTapEnded`。拆除不是一次完成的双击，记一个「结束」会把未落地的倍率写进探针统计；探针协调器由 `S2View` 持有，离开 S2 时一并释放。

### 3.5 R1～R5 与断言的对应

| 要求 | 断言 | 怎么钉 |
|---|---|---|
| **R1** 拆除路径 `objectWillChange` 0 次 | 断言 1 | 订阅只包住 `dismantleUIViewController` 调用与其后 0.3 s，计数 == 0 |
| **R2** 每一层清干净 | 断言 1 | ① 显示链接：丝滑度探针在每次显示链接回调里记一帧，取消不记「结束」、事件保持在途——拆除后 0.3 s 帧数不变；② 过渡视图：`superview == nil` 且页视图子视图集合回到起飞前；③ 页内容 `isHidden == false`；④ 播放层：真实 `S2VideoHostView` 的 `isLendingPlaybackLayer == false` 且播放层挂回宿主；⑤ `isDoubleTapTransitionActive == false`；⑥ `zoomScrollView.isUserInteractionEnabled == true`。**六项各有拆除前的在途态前置断言**（借出中、隐藏中、挂着、交互关着、探针帧数 > 0），保证拆除后的「清了」不是空转 |
| **R3** 正常收口不变 | 断言 2 + 43 条既有双击用例 | 同夹具不拆除，计数 ≥ 1、`.completed` 恰 1、`lastDoubleTapSynchronization` 非空；`finishActiveDoubleTapTransition()` 逐字节未动 |
| **R4** K2 仍是唯一入口 | 断言 3 + IC-118 A 三条 | 分页器内 `machine.reportNativeViewport(` 恰 1（改前实读 1）；状态机 `func reportNativeViewport(` 恰 1；`Core/S2StateMachine.swift` 两侧 SHA-256 相同（git 实证，XCTest 读不到 git 历史）；`testIC118A…` 三条 `passed` |
| **R5** 拆除时诊断收不到 `.completed` | 断言 1 + 断言 3 | 行为：诊断观察者在拆除窗口内 `.completed` 计数 == 0；结构：拆除入口不再收尾，且 `diagnosticsRun?.cancel()` 与摘观察者都在取消之前 |

---

## 四、CI 与项数对账

### 4.1 两次 attempt 的完整事实

| 项 | attempt 1 | attempt 2 |
|---|---|---|
| 运行编号 | #304 | #304 |
| run id | `35080037007` | `35080037007`（`run_attempt` 由 1 变 2） |
| 被测提交 | `2655b24ef128514e0d789ac59b155980814ffbd0` | **同一提交，代码一字未改** |
| 结论 | **cancelled** | **success** |
| 取消原因 | 注解 `The job has exceeded the maximum execution time of 15m0s`（作业 09:33:00 → 09:48:02） | — |
| 步骤 | 十一步各自 success，作业整体超时 | 十一步全 success |
| 作业时长 | 902 s | 469 s |
| XCTest 步骤时长 | 804 s | 356 s |
| 执行摘要 notice | `Executed 811 tests, 0 failing test case(s), across 1 launch(es)` | `Executed 811 tests, 0 failing test case(s), across 1 launch(es)` |
| xcodebuild 摘要 | `Executed 811 tests, with 0 failures (0 unexpected) in 46.090 (75.419) seconds` | `Executed 811 tests, with 0 failures (0 unexpected) in 39.015 (43.193) seconds` |
| 唯一用例身份去重 | 811 | **811** |
| 日志内 `' failed (` | 0 | **0** |
| IPA | 1557377 字节，SHA-256 `eb3e97edcc22af22031082cebeccb4fed6061fef64c75b94b9918eaf44ccfd1d` | **1557377 字节，SHA-256 `733b42642ff0b5b1cc7bd8215207aff176c444c9ddd78087c3753c7e479244a5`** |
| check-run id | `104741566822` | `104747064665`（现取，未沿用 attempt 1） |

**attempt 1 超时归因（①，日志时间戳）**：测试包链接结束于 `09:34:22.886`，此后日志**静默 10 分 38 秒**，直到测试宿主启动日志 `09:45:00.913`；`Test Suite 'All tests' started` 于 09:45:03，全部通过于 09:46:18。xcodebuild 自报 `IDETestOperationsObserverDebug: 746.068 elapsed -- Testing started completed.`——746 s 里测试执行约 75 s，其余是模拟器启动与装载。本卡六条新用例合计约 1.6 s。**与本卡代码无关**；两次 IPA 字节数相同、哈希不同是既有结论（IPA 归档不可复现）。

### 4.2 attempt 2 的实证行

- 目的地实证：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- 机型钉死实证：`使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`
- `** TEST SUCCEEDED **`；`XCTest 已全部通过`
- IC-125 哨兵：执行摘要 notice 存在且 N = 811 > 0 ✔
- artifact：`PhotoCleanupMVE-unsigned-2655b24ef128`，id `10441295377`，zip 1557547 字节

### 4.3 项数对账

```
805   main，CI #303 执行摘要
 + 6   本卡新增（断言 1～6 各一条；断言 7 沿用 testIC063… 不另计）
= 811  ← #304 attempt 2 执行摘要 811，唯一用例身份去重亦为 811
```

### 4.4 CI 预算

卡内预算 3 次，**实际用 2 次**：attempt 1（被超时取消，811 项 0 失败）+ attempt 2（同提交原样复跑，全绿）。复跑不是「修」——一行代码没改；处置与 `testIC063` 抖动时的既有约定同理：先对同一提交原样复跑做对照。

---

## 五、逐条验收门禁与测试函数名

| 断言 | 测试函数名 | 所在文件 | attempt 2 日志 |
|---|---|---|---|
| 1 | `testIC152A_DismantleMidTransitionPublishesNothing` | `IC152DiagnosticPathTests.swift` | `passed (0.373 s)` |
| 2 | `testIC152A_NormalCompletionStillReportsViewport` | 同上 | `passed (1.115 s)` |
| 3 | `testIC152A_ViewportReportEntryUnchanged` | 同上 | `passed (0.032 s)` |
| 4 | `testIC152B_GateFloorIsTwoAndTargetsAreSoft` | 同上 | `passed (0.015 s)` |
| 5 | `testIC152B_CadenceDescriptionCarriesProgressSamples` | 同上 | `passed (0.002 s)` |
| 6 | `testIC152B_ErrorWritePointsUnchanged` | 同上 | `passed (0.060 s)` |
| 7 | `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`（T1 不动、T2 改口径） | `S2CalibrationHarnessTests.swift` | `passed (3.243 s)` |

attempt 1 中七条同样全部 `passed`。

---

## 六、子项 B：中间帧门禁

### 6.1 T2 两条断言原文（旧 → 新）

旧：

```swift
XCTAssertGreaterThanOrEqual(
    report.components(separatedBy: "双击进入 Nx：动画中间帧").count - 1,
    3
)
XCTAssertGreaterThanOrEqual(
    report.components(separatedBy: "双击退出 Nx：动画中间帧").count - 1,
    5
)
```

新：

```swift
// IC-152 B：needle 改为样本标题（带「## 」与「 #」）——改前的裸段名也会把
// 门禁失败那句错误数进去，计数 = 样本数 + 1；阈值改与产品硬下限同值 2，
// 3／5 已降为软目标（未达只记一行诊断、不判红）。
XCTAssertGreaterThanOrEqual(
    report.components(separatedBy: "## 双击进入 Nx：动画中间帧 #").count - 1,
    2
)
XCTAssertGreaterThanOrEqual(
    report.components(separatedBy: "## 双击退出 Nx：动画中间帧 #").count - 1,
    2
)
```

T1 `XCTAssertTrue(report.contains("中间帧门禁：通过"))` 一字未改。

### 6.2 `errors.append(` 计数实证（惯例 38）

| 变体 | 改前（`0bedaea`） | 改后（`2655b24`） |
|---|---|---|
| 只剔注释、保留字面量 | 2 | **2** |
| 连字面量一并剔掉 | 2 | 2 |

两个写入点：G6 中间帧不足（改后为 `self.errors.append(error)`，只在命中 < 2 时）、G7 `capture` 缺运行时视图（未动）。断言 6 钉住。

同一断言的正对照 `中间帧软目标未达：`：只剔注释的变体命中 **1**，连字面量一并剔掉的变体命中 **0**——若用后者，这条正对照恒红（IC-149 门禁二要抓的 #295 那类病），故本卡新测试文件自带一只只剔注释的 `sourceWithoutComments`。

### 6.3 B1～B5 的落实

| 要求 | 落实 | 断言 |
|---|---|---|
| B1 硬下限 2，仍走 G6，错误以「段名 少于 2 帧」开头并带归因 | `S2DiagnosticMiddleFrameGate.evaluate` 命中 < `hardFloor` 才给 `error` | 4 |
| B2 2 ≤ 命中 < 3／5 写一行 `中间帧软目标未达：`，不进 `errors`，门禁照常通过 | `softTargetLine` 进 `softTargetLines`，经 `gateLines` 接在门禁两行之后 | 4 |
| B3 归因文字带进度样本，硬红与软未达都带 | `cadenceDescription` 末尾「；进度样本：…」，两位小数、逗号分隔、固定 `en_US_POSIX` | 5 |
| B4 软目标行不含样本标题串、不以段名开头 | 以固定前缀开头；段名只出现在前缀之后，不带「## 」与「 #」 | 4 |
| B5 G1、G3、G4、G5 全部不动 | 本机逐字节比对与 `main` 相同 | 6（G4 公式与 G5 `removeFirst` 各恰 1、`minimumMiddleFrames: 3／5` 各恰 1、`secondsPerThreshold` 0.2 恰 1） |

### 6.4 端到端覆盖的实话（②）

两次 attempt 的 `testIC063` 报告里：`中间帧门禁：通过`，进入段样本 **3**（#1～#3）、退出段样本 **5**（#1～#5），`采样总数：15`——**软目标两段都达标，报告里没有出现 `中间帧软目标未达：` 行**。因此软目标行的实际渲染只由断言 4（门禁真正用来拼报告头部的 `gateLines`）覆盖，**端到端未覆盖**；等 runner 下次跑出 2 帧的一段时，日志里才会第一次看到它与进度样本。

---

## 七、既有双击相关测试逐条（G869，attempt 2）

按名称含 `DoubleTap／doubleTap／IC108B／IC118／IC143C` 从测试目标全量列出，**43 条全部 `passed`**，缺失 0；attempt 1 同样 43／43：

| 测试类 | 用例 |
|---|---|
| `S2CalibrationHarnessTests` | `testD4ScreenAspectDoubleTapUsesMinimumScale`、`testD5ReplacementNonScreenDoubleTapUsesAspectFillScale`、`testD6LeftEdgeDoubleTapAlignsLeftContentBoundary`、`testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary`、`testD8DoubleTapExitResetsScaleAndOffset`、`testE1ReplacementSingleTapRunsAfterDoubleTapFailure`、`testE2ReplacementDoubleTapSuppressesSingleTapAction`、`testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap`、`testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale`、`testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap`、`testIC063G3DoubleTapTargetStillUsesScreenAspectClassification`、`testIC063G4DoubleTapSynchronizationPreservesWindowFrameBothWays`、`testIC077G127RequestThrottlingAcrossPinchDoubleTapPagingAndViewport`、**`testIC108BProbeCapturesDoubleTapThroughPager`**、**`testIC108BProbeRecordsAllRequiredFieldsWhenRecording`**、**`testIC108BProbeRecordsNothingWhenDisabled`**、`testIC110ADoubleTapDurationIsThreeHundredMillisecondConstant`、**`testIC118BDoubleTapExitTargetsRestoredVisibilityGeometry`**、`testIC118BPinchReturnDropsStaleDeferredTarget`、`testIC118BReconcileKeepsMatchingDropsStaleDeferredTarget`、`testIC123BLandscapeScreenshotDoubleTapKeepsAspectRatioThroughout`、`testK1SingleTapRequiresDoubleTapRecognizerToFail`、`testK2DoubleTapAutoHidesOnEnterAndRestoresOnExit`、`testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce`、`testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds`、`testM1ScreenAspectDoubleTapUsesMinimumScale`、`testM2NonScreenPhotoDoubleTapUsesAspectFillScale`、`testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale`、`testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget`、`testY4DoubleTapExitUsesSingleNativeMinimumZoomAnimationWithoutOffsetWrite` |
| `S2StateMachineTests` | `testIC047_004TransitionRowDoubleTap`、`testIC047_024GestureMatrixDoubleTapRow`、`testIC047_037DoubleTapEnterAndExitRestoresVisibility` |
| `S2ImageLoadingStateTests` | `testIC077R3DoubleTapBumpsImageRequestRevisionOncePerSettle` |
| `S2ActionBarWiringTests` | `testIC114DDoubleTapZoomAutoHidesAndRestores`、**`testIC118AFinishNativePinchSnapBackRestoresVisibility`**、**`testIC118ANativePinchViewportReportAutoHidesAndRestores`**、**`testIC118AViewportEchoWithoutPinchDoesNotTouchVisibility`** |
| `IC141VideoPlaybackTests` | `testIC141B_ZoomAndDoubleTapTransitionKeepThePlaybackLayerAlive` |
| `IC143VideoPolishTests` | **`testIC143C_EarlyCollapsedTransitionAlsoReturnsThePlaybackLayer`**、**`testIC143C_PhotoPageTransitionAndAfterimageSnapshotAreUnchanged`**、**`testIC143C_PlaybackLayerRidesTheDoubleTapTransitionAndComesBack`**、**`testIC143C_TheTransitionNeverTouchesPlaybackState`** |

加粗者为卡内点名的 IC-108 B、IC-118 A（卡内 R4 的三条）、IC-118 B 退出采样、IC-143 C 播放层出借。卡内点名的「IC-115」在测试目标内无以 `IC115` 命名的用例，其双击自动隐藏的改写落在 `testK2DoubleTapAutoHidesOnEnterAndRestoresOnExit` 与 `testG3Replacement…`（两者注释写明 IC-115），已含在上表。

---

## 八、闸门核对

### G867：diff 限于白名单 —— **不完全满足（一处声明式偏离）**

- 四个路径全在白名单内；零改动目录全部为 0（`change-list.md` 第二节）。
- 分页器八个 hunk 头见 `change-list.md` 第三节。**七个**落在 D2、D3、G2、G6、G8 所在函数，或卡内断言 4 明许的「放在产品文件内、只被门禁调用的纯函数」。
- **第 7 个 hunk `@@ -4661,12 +4710,14 @@` 落在 `makeReport()`——G9 所在函数，不在「D1～D3 与 G2～G8」之内。** 理由：B2 要求「报告里增加一行」，报告只在 `makeReport()` 一处拼装，卡内白名单与 B2 无法同时字面满足（惯例 39／40 所指的写卡缺陷同类）。改动最小化：门禁结论行与错误行交由 `gateLines` 拼装、**两行文字与改前逐字相同**，软目标行接在其后。

### G868：标定与冻结链 —— 满足

- `S2Calibration.swift` 不在 diff；`static let schemaVersion = 7` 未动 ✔
- 远端 tip（`git ls-remote origin`，直连）：

| 分支 | 期望 | 实读 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | `b368a6caee846e664391b0620350395bfe6fbc7f` ✔ |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` ✔ |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` ✔ |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | `9db02b93eccbb87d126602901807e70823535111` ✔ |
| `probe/ic-125-sentinel-negative` | `402cb6e` | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` ✔ |
| `probe/ic-137-media-playback` | `486bcb7` | `486bcb769b59eb1146c5a231c7998847206777cc` ✔ |
| `probe/ic-145-scan-service` | `d373afc` | `d373afc7125104c01acfc296829229090e6871ce` ✔ |

### G869：改前复现结论、R1～R5 对应、既有双击测试 —— 满足

第三节 3.1（改前复现结论与证据等级）、3.5（R1～R5 → 断言）、第七节（43 条逐条 `passed`）。

### G870：合并前置 —— **不满足（仅 G867 一处）**

| 条件 | 状态 |
|---|---|
| G867 | **一处声明式偏离**（上文） |
| G868、G869 | 满足 |
| 全部 XCTest 通过、真实退出码 0 | #304 attempt 2：811 项 0 失败，步骤全 success ✔ |
| 执行摘要 notice | `Executed 811 tests, 0 failing test case(s), across 1 launch(es)` ✔ |
| `OS:26.2, name:iPhone 16` 目的地实证行 | ✔ |
| IPA 字节数与 SHA-256 | 1557377 / `733b4264…44a5` ✔ |
| 断言 1～7 函数名 + 日志核 `passed` | 第五节 ✔ |
| 项数对账 | 第 4.3 节 ✔ |
| T2 旧→新 | 第 6.1 节 ✔ |
| pbxproj 撞号扫描 | 第九节 ✔ |
| 工作树净 | 报告提交后 `git status --porcelain` 空 ✔ |
| `main` 未被他人推进 | `git ls-remote origin refs/heads/main` = `0bedaea8…` ✔ |

**因 G867 未被字面满足，执行端未执行合并**（纪律：执行端不定合并策略；卡内合并授权以 G870 满足为前提）。

### G871 —— 合并后 `main` 自动运行（决策会话回填，见第十一节）

| 项 | 值 |
|---|---|
| 运行编号 | **#305** |
| run id | `35095855030`，`run_attempt` **1** |
| check-run id | `104792889069`（现取） |
| 被测提交 | `1e603d73c201c5313b0179dd3765ae4fe87f8306`（合并提交） |
| 结论 | **success**，11 个步骤全 success |
| 执行摘要 notice | `Executed 811 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 811 tests / 0 failures` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1557377，SHA-256=9284595f47cf97739393045574ba9759edcd3b35cd3457d47d9145b295873b4e` |
| artifact | `PhotoCleanupMVE-unsigned-1e603d73c201`，id `10446356944`，zip 1557547 字节，2026-12-15 前有效 |

IPA 字节数与 #304 两次 attempt 相同（1557377）、哈希不同——IPA 归档不可复现的既有结论。**G871 满足。**

---

## 九、pbxproj 撞号扫描

加登记前**重扫当前最大号**（`grep -o` 实读全文件）：

| 类别 | 现有最大号 | 本卡新号 |
|---|---|---|
| `PBXFileReference` | `100000000000000000000053` | `100000000000000000000054` |
| `PBXBuildFile` | `200000000000000000000050` | `200000000000000000000051` |

登记脚本内置：新号不得已存在于文件内、必须严格大于现有最大号；四个插入锚点各恰一处命中。事后核对：`IC152DiagnosticPathTests` 的 6 个用例在 CI 日志里逐条有 `Test Case … passed` 行，证明该文件确实进了编译列表（IC-134 #262 撞号陷阱不适用）。

---

## 十、本地门禁（真实退出码）

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** |
| `Scripts/check-swift-string-structure.ps1 -SelfTest`（IC-149 门禁一） | **0** |
| `Scripts/check-scan-needle-variant.ps1 -SelfTest`（IC-149 门禁二） | **0**（扫描 38 个测试源文件） |
| `git diff --check` | **0** |

**本机预验证**：把 `strippedSource`／只剔注释的变体／`occurrences`／`slice` 移植成 Python，对改后源码重算断言 3、6 的全部命中数，并逐字节比对 G1、G3 两段、G4 块、G5 分支、G10、D1、D3 收尾、D4、D5 与 `main` 相同——两轮共 50 条，全部吻合。

---

## 十一、合并（决策会话裁定并执行，2026-09-16 回填）

执行端交回时附了三条合并命令与两种候选处置（① 追认白名单补上 `makeReport()`；② B2 改写进日志）。**决策会话裁定取 ①**：B2「报告里增加一行」与 G867 的函数清单自相矛盾，是写卡缺陷（Decision_log 第 178 条），不是交付缺口；执行端改到最小、两行原文逐字不动、不自行合并，处置正确。G870 按实际交付重述后满足。

| 项 | 值 |
|---|---|
| 合并前 `main` | `0bedaea8d85ec4f7c40bfe8b4c9d6dd95cb9d462` |
| 被合并分支 tip | `1c72df3135ac03e52d6d742032a45f02bdc6c59d`（代码 tip `2655b24ef128514e0d789ac59b155980814ffbd0` + 报告提交） |
| 合并方式 | `git merge --no-ff feature/ic-152-diagnostic-path`（Bash 侧 `git switch`／`git merge` 均被本机分类器以 `[Merge Without Review]` 拒绝，换 PowerShell 同一条命令通过——第 170 条惯例） |
| **合并提交** | **`1e603d73c201c5313b0179dd3765ae4fe87f8306`** |
| 合并后 `main` | 同上，已推送 `0bedaea..1e603d7 main -> main` |
| 合并统计 | 6 个文件，+1507 / −35；新增 3 个文件 |

决策会话独立复核（合并前）：`Core/S2StateMachine.swift`、`.github/workflows/ci.yml`、`S2Calibration.swift`、`S2AmbientBackdrop.swift` 两侧同一 blob；`finishActiveDoubleTapTransition()` 97 行两侧逐字相同；#304 attempt 2 十一步 success；分页器八个 hunk 头与第三节一致。

---

## 十二、发现但未处理的问题（按纪律只报告不修）

1. **CI 作业时限 15 分钟几乎没有余量**（`.github/workflows/ci.yml` 第 21 行 `timeout-minutes: 15`，本卡不得触碰 `.github/`）。#304 attempt 1 在 811 项全部通过、IPA 已构建上传之后，于 15 分 02 秒被判超时取消；耗时的是测试宿主启动前 10 分 38 秒的模拟器启动与装载，同一提交的 attempt 2 这一段只用了几分钟。runner 侧的这段抖动今后还会把全绿的运行判成 cancelled。
2. **软目标行端到端未覆盖**（第 6.4 节）：两次 attempt 的 `testIC063` 都跑满 3／5 帧，报告里没出现软目标行与进度样本。
3. **`waitForDiagnosticStableState` 以强引用捕获 `self` 轮询**（`DispatchQueue.main.asyncAfter`，最多 200 × 20 ms = 4 s）。拆除时若诊断正停在某个等待里，分页器控制器最长会被多留 4 s，回调里靠 `!cancelled` 守卫空转返回——不发布、不崩，只是延迟释放。既有行为，不在 D1～D3。
4. **取消路径不结束丝滑度探针的在途事件**（第 3.4 节末）。只在标定面板开着探针录制时离开 S2 才会出现；探针协调器随 `S2View` 释放。执行端取舍，列此备查。

---

## 十三、人工判定项（H74，留给 Lynn 真机，执行端不代为下结论）

1. **崩溃路径**：进 S2 → 双击放大 → 在放大动画**还没停住**那一瞬立刻返回或切 tab，掐时机反复 10 次——不崩、不卡死、不留半张放大的残影。（注意：装的 IPA 是 Release，`Fatal access conflict` 那道运行时检查可能本就不触发；**「没崩」记「未复现」，不记「没问题」**；判「过」的依据是 10 次都干净。）
2. **再进 S2**：上一条之后再进 S2，页面是 1x、chrome 显示、当前张正确，没有沿用上次离开时的放大状态。
3. **双击进出不回归**：正常双击进入／退出放大各 5 次，观感与 IC-126 判定时一致（H65 第 6 项那条播放页也各一次）。
4. **视频页双击后立刻离开**：与第 1 条同路径但在视频页做——回到列表后视频无残留声音、无残留播放层。

说明：已合并。H74 装**合并后 `main`**（`1e603d7`）的产物——#305 的 artifact `PhotoCleanupMVE-unsigned-1e603d73c201`（第八节 G871）；该包同时可判 H72、H73。

---

## 十四、报告内 40 位 SHA 的实读核验

陷阱 15：报告内每个 40 位 SHA 必须来自实读命令的输出，不得凭短前缀补全。
核验命令：`grep -ohE '\b[0-9a-f]{40}\b' Reports/IC-152/*.md | sort -u`，逐个 `git cat-file -e <sha>^{commit}`。

| SHA | 存在 | 提交标题（首行截断） |
|---|---|---|
| `0bedaea8d85ec4f7c40bfe8b4c9d6dd95cb9d462` | ✔ | `docs(IC-151): 回填合并提交与 G866…` |
| `2655b24ef128514e0d789ac59b155980814ffbd0` | ✔ | `fix(IC-152 B): 中间帧门禁硬下限改每段 2 帧…` |
| `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | ✔ | `probe: IC-125 负对照…` |
| `486bcb769b59eb1146c5a231c7998847206777cc` | ✔ | `probe: IC-137 媒体播放探针…` |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | ✔ | `docs: 完成 IC-091 阶段一…` |
| `9db02b93eccbb87d126602901807e70823535111` | ✔ | `test: 等待首个真实捏合完整结束` |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | ✔ | `docs: IC-092 自验报告与变更清单 v2 完整替换…` |
| `ae2ae42331ab94dd7ff36a385c2fb5acaa84649f` | ✔ | `fix(IC-152 A): 拆除期取消在飞的双击过渡…` |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | ✔ | `docs: 完成 IC-089（IC-082 v3 R4）贴边回弹…` |
| `d373afc7125104c01acfc296829229090e6871ce` | ✔ | `docs(IC-145): 自验报告与变更清单…` |
| `f319a22471fa73cb742159bdd5ab177c7ee3a8e5` | ✔ | `Merge IC-151：氛围底改固定色…` |
| `1c72df3135ac03e52d6d742032a45f02bdc6c59d` | ✔（回填时补） | `docs(IC-152): 自验报告与变更清单…` |
| `1e603d73c201c5313b0179dd3765ae4fe87f8306` | ✔（回填时补） | `Merge IC-152：拆除期状态机零次发布 + 中间帧门禁硬下限 2` |

**13 个 40 位 SHA 全部 `git cat-file -e` 通过**（两份报告合计去重；后两个由回填方在 `main` 上实读 `git log` 取得）。报告内 64 位十六进制串是 SHA-256（文件与 IPA 哈希），不是 git 对象，不在本节核验范围。

**回填方式说明（纪律 7）**：本报告随分支上的报告提交（`1c72df3`）一起推送。合并提交 SHA 与 G871 是合并后才产生的信息，由执行合并的决策会话在 `main` 上追加一个 docs 提交回填（与 IC-150 的 `1fd6ed0`、IC-151 的 `0bedaea` 同一做法），不跨卡回填。纯报告提交不触发 CI，是预期行为。
