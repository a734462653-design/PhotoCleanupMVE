# IC-158 变更清单

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260917-158-diagnostic-progress-clamp.md` |
| 基线 `main` | `15bf53f042a30a1ace0dfea2cf289973f019c67d` |
| 分支 | `feature/ic-158-diagnostic-progress-clamp` |
| 子项 A 提交 | `c3cc047ecd8b616a84941aa07a23371b2e987bd4` `feat(IC-158 A): 诊断双击过渡加每回调线性进度上限——宿主停顿后分步走完，阈值一个不漏` |
| 子项 B 提交 | `96acc6c47890ae77211a6944af80ae51670a07cf` `feat(IC-158 B): 报告加「步长上限触发」一行，testIC063 加一条 contains` |
| 报告 | 本文件与 `self-check.md`，另一个 docs 提交（同一分支，纪律 7） |
| CI | **#317 一次红，停卡上报、未合并**（`self-check.md` 第四、九节）：`testIC063…` 属 G900 的（乙）形态（报告为空、期限被吃掉），本卡断言 3 的期望被实测推翻 |
| 出厂值与登记数 | **无变更**：`schemaVersion` 7、`cacheSchemaVersion` 1、`hardFloor` 2、`secondsPerThreshold` 0.2、`S0HomeMetrics` 52、`S0CategoryPageMetrics` 42；本卡不加登记常量、不加文案 key |

## 二、文件清单（`git diff --numstat 15bf53f 96acc6c`，全部在白名单内）

| 文件 | 增／删 | 白名单条目 | 所属提交 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | +69／−2 | A1～A6、B1～B3 | A +41／−2；B +28／−0 |
| `PhotoCleanupMVETests/IC158DiagnosticProgressClampTests.swift`（新） | +744／−0 | 本卡断言 | A 建 662 行；B +82 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4／−0 | 一个新文件登记 | A |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | +1／−0 | 仅 B4 一行 | B |

合计 4 个路径，+818／−2。

## 三、逐项变更

### 子项 A（裁定 一、二）

| 处 | 改后行 | 变更 |
|---|---|---|
| A1 | `S2NativePhotoPager.swift:1404-1414` | `S2DiagnosticDoubleTapTiming` 内新增 `static func maximumLinearProgressStep(minimumMiddleFrames: Int) -> CGFloat`，返回 `1 / CGFloat(4 * (max(1, n) + 1))`（`:1412` 为声明行）。既有 `secondsPerThreshold`、`durationSeconds(minimumMiddleFrames:)` 逐字不动（G897 awk 切块） |
| A2 | `:1545-1553` | `doubleTapTransitionDuration` 之后新增三个状态量：`private var doubleTapMaximumLinearProgressStep: CGFloat?`、`private var doubleTapLastLinearProgress: CGFloat = 0`、`private(set) var doubleTapClampedCallbackCount = 0`（第三个须 `private(set)`：运行类与测试要读） |
| A3 | `:1896` | `startDoubleTapTransition` 加第六参 `maximumLinearProgressStep: CGFloat? = nil`，声明在 `durationOverrideSeconds` 之后；既有 3 个产品调用点与 8 个测试调用点不改即编译 |
| A4 | `:1977-1980` | 起飞清零段（`doubleTapTransitionProgressSamples = []` 同段）加三行：上限赋值、`doubleTapLastLinearProgress = 0`、`doubleTapClampedCallbackCount = 0`。取消路径**不加行** |
| A5 | `:2241-2253` | `advanceDoubleTapTransition` 里 `let linearProgress` 改 `var`，在墙钟线性进度之后、`easedProgress` 之前夹紧：`if let step = doubleTapMaximumLinearProgressStep, linearProgress > doubleTapLastLinearProgress + step { linearProgress = doubleTapLastLinearProgress + step; doubleTapClampedCallbackCount += 1 }`，随后 `doubleTapLastLinearProgress = linearProgress`。`>= 1` 收口判断用夹紧后的值 |
| A6 | `:3436-3443` | `beginDiagnosticDoubleTap` 在 `durationOverrideSeconds:` 之后传 `maximumLinearProgressStep: S2DiagnosticDoubleTapTiming.maximumLinearProgressStep(minimumMiddleFrames: minimumMiddleFrames)` |
| A7 | `:3468`、`:3595` | 另两个调用点**未动**（产品双击与 `normalizeDiagnosticState` 都不传上限 ⟹ nil ⟹ 与改前同一条代码路径） |

### 子项 B（裁定 三、四）

| 处 | 改后行 | 变更 |
|---|---|---|
| B1 | `:5083-5094` | `S2DiagnosticMiddleFrameGate` 加 `static func clampLine(entryClampedCallbacks:exitClampedCallbacks:) -> String`，返回 `步长上限触发：进入段 N 次，退出段 M 次`。既有四个静态函数（`evaluate`／`cadenceDescription`／`progressSampleText`／`gateLines`）签名与文字一字不动 |
| B2 | `:4335-4336`、`:4566-4573` | 运行类加 `entryClampedCallbacks`／`exitClampedCallbacks` 两个初值 0 的 `Int`（声明在 `softTargetLines` 之后）；`.completed` 分支在既有两句接线之后加**唯一读点** `let clamped = controller.diagnosticCurrentPage?.doubleTapClampedCallbackCount ?? 0`，再按 `middlePrefix` 是否为进入段赋给两者之一。**不加 `errors.append(`** |
| B3 | `:4771-4775` | `makeReport()` 在 `gateLines` 之后、第一个样本之前追加 `clampLine(...)` 一行 |
| B4 | `S2CalibrationHarnessTests.swift:4147` | `report.contains("中间帧门禁：通过")` 之后插入一行 `XCTAssertTrue(report.contains("步长上限触发："))`。该文件 diff 恰 **+1／−0**，其余逐字不变 |

## 四、既有断言改口径

**无。** IC-152 六个源码 needle 的计数在改后逐个复算不变（`self-check.md` 第八节）；`testIC063…` 既有断言一条未改，只增一条 `contains`。

## 五、新增测试（`IC158DiagnosticProgressClampTests`，5 项）

文件内布局：A 建文件（断言 1～4 与全部夹具），B 把断言 5 插在断言 4 之后、`// MARK: - 夹具` 之前。

| 断言 | 函数名 | 子项 | 行 |
|---|---|---|---|
| 1 | `testIC158A_StepIsQuarterSpacingAndEasedIncrementStaysUnderOneSpacing` | A | `:37` |
| 2 | `testIC158A_ClampedTransitionWalksThroughAMainThreadStall` | A | `:106` |
| 3 | `testIC158A_UnclampedPathStillJumpsToCompletionAfterAStall` | A | `:197` |
| 4 | `testIC158A_OnlyTheDiagnosticsEntryPassesTheStepAndIC152PinsHold` | A | `:272` |
| 5 | `testIC158B_ReportCarriesClampLineAndItStaysOutOfSampleTitles` | B | `:386` |

夹具照 `IC152DiagnosticPathTests` 的私有 helper 逐份照抄（`physicalSize`／`screenAspectRatio`／`offCenterFocusPoint`／`startEntryTransition`（多带一个 `maximumLinearProgressStep` 形参透传）／`makeStateMachine`／`makePagerController`／`applyPager`／`attachWindow`／`repoRoot`／`sourceText`／`sourceWithoutComments`／`occurrences`／`slice`／`tryUnwrap`／`pagerPath`／`memberClose`），另加一个按产品同规则重算阈值消费的 `consumedThresholds(in:minimumMiddleFrames:)`。

## 六、pbxproj 登记

登记前重扫：文件引用最大 `100000000000000000000060`、构建文件最大 `20000000000000000000005D`（与卡内事实一致）。

| 文件 | 文件引用 | 构建文件 | 组 | 构建阶段 | 提交 |
|---|---|---|---|---|---|
| `IC158DiagnosticProgressClampTests.swift` | `100000000000000000000061` | `20000000000000000000005E` | 测试组（`IC157LongPressIntoS2Tests.swift` 之后） | 测试 Sources（同上之后） | A |

撞号扫描：全文件 24 位对象 id 的定义行无重复；两个新 id 的出现次数为文件引用 3、构建文件 2。

## 七、摘取关系（克隆仓库实测，见 `self-check.md` 第十节）

| 单元 | 结果 |
|---|---|
| A 单独（`15bf53f` + `c3cc047`） | 无冲突 |
| A→B | 无冲突，树与 `96acc6c` 相同 |
| 负对照：B 单独 | 冲突（`DU IC158DiagnosticProgressClampTests.swift`；产品两处改动与 `S2CalibrationHarnessTests.swift` 那一行干净应用） |

## 八、占位值登记

本卡无出厂值变更、无新增登记常量、无新增文案 key。新增的两个报告文字（`步长上限触发：` 前缀与其整行）属几何诊断报告文本，与 IC-152 的 `中间帧软目标未达：` 同类，落在 `S2GeometryDiagnosticsRun` 之后的扫描器豁免区内（`Scripts/scan-hardcoded-user-visible-strings.ps1:113`），本机扫描退出码 0。
