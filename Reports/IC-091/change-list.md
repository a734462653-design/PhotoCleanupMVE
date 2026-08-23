# IC-091 变更清单（阶段一）

分支 `feature/ic-091-nx-midgesture-handoff`，自 `main` = `bf7bab1f8b9fea1194b57151f0beae34fa03756f`（IC-088，CI #149，XCTest 477/0）切出。**未基于 `feature/ic-089-nx-edge-bounce`**；该分支的判定函数与诊断事件代码以新提交复制，未 cherry-pick 任何提交。阶段一最终被测提交 `bfb2b8b8973bfef85b35f7fa271f4ad437927d0a`（CI #158）。首次推送的 `8871307` 走 CI #157，485 项 1 失败（单点：A2 内一条前提被实测推翻的断言），见自验报告。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `9897b74` | R1 | `Features/S2/S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift`、`Reports/IC-068/export-format.md` | 逐帧五个新字段 + 四类新事件入口 + `外层setContentOffset` details 扩充 + 外层 `scrollViewWillBeginDragging` 埋点接线；纯判定类型 `S2NxInnerPanDecision` / `S2NxHandoffReading` / `S2NxEdgeHandoffRule`（本提交不接线）。零行为变化 |
| `3a450fb` | R2+R3 | `Features/S2/S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift` | 手段 M1：内层 pan 起始判定接线 + 本次手势方向锁 + 五处清零；交接点判据与交接窗口；`apply` / `layoutNativePages` 在窗口内跳过外层偏移写入 |
| `8871307` | R2 稳健性 | 同上 + `Reports/IC-068/export-format.md` | 内层 pan `.began` 无条件重算起始判定；删除「本次手势已判定」标志（残留风险，见自验报告） |
| `bfb2b8b` | 测试修正 | `S2CalibrationHarnessTests.swift` | A2 的「程序写入越界偏移会被钳回边界」前提被 CI #157 实测推翻（`overshoot=50.0`）：改为「探针断言 UIKit 实际行为 + 断言产品钳制层不改横向边界偏移」。**产品代码零改动** |

R3 与 R2 合并为一个提交：R3 的守卫条件直接读 R2 引入的 `isNxHandoffWindowOpen`，单独 cherry-pick R3 无法编译；卡允许 R1+R2+R3 分 2～3 个提交。

## 手段选择

**M1（内层 pan 起手判定为水平主导时，为本次手势启用方向锁）。** 理由见自验报告「手段选择与理由」节。M2 未采用。

## 新增产品类型与成员

| 符号 | 位置 | 说明 |
|---|---|---|
| `struct S2NxInnerPanDecision` | 文件顶部（`S2NativeZoomScrollView` 之前） | 复制自 IC-089 `7178de4`，四个字段原样，追加 `engagesDirectionalLock: Bool` |
| `struct S2NxHandoffReading` | 同上 | 新增：`reachedEdge` / `distanceToEdge` / `movingLeft` |
| `enum S2NxEdgeHandoffRule` | 同上 | `edgeTolerance = 0.5`（复制）；`innerPanDecision(...)`（复制 + 新字段）；新增 `handoffReading(...)`；私有 `distanceToEdge(...)`（两个入口共用，行为与 IC-089 内联算法逐字等价） |
| `enum S2NxHandoffWindowReason: String` | 与 `S2OnDeviceTransitionScenario` 同段 | 六个交接窗口开 / 关原因；只进导出文本 `reason=` 字段 |
| `S2NativeZoomScrollView.lastInnerPanDecision` | 内层视图 | `private(set)`，诊断留痕 |
| `S2NativeZoomScrollView.gestureRecognizerShouldBegin(_:)` | 内层视图 | `override`；只对 `panGestureRecognizer` 介入 |
| `S2NativeZoomScrollView.innerPanDecision(translation:velocity:source:)` | 内层视图 | 判定 + 设方向锁 + 记事件；夹具可直接以向量调用 |
| `S2NativeZoomScrollView.clearGestureScopedInteractionState()` | 内层视图 | 手势级状态清零（当前只有方向锁一项） |
| `S2NativeZoomScrollView.resolveInnerPanDecision(source:)` | 内层视图（私有） | 从识别器取向量后调上一项 |
| `S2NativeZoomScrollView.setGestureDirectionalLock(_:)` | 内层视图（私有） | 写 `isDirectionalLockEnabled`，值相同则不写 |
| `S2NativeZoomScrollView.handleInnerPanStateChange(_:)` | 内层视图（私有 `@objc`） | pan 识别器 target：`.began` 重算判定；`.ended/.cancelled/.failed` 清零 |
| `S2NativeZoomPageController.handleInnerPanForHandoff(_:)` | 页控制器（私有 `@objc`） | pan 识别器 target：手势结束 / 取消 / 失败时关闭交接窗口 |
| `S2NativePagerViewController.isNxHandoffWindowOpen` | 外层控制器 | `private(set)`，R3 守卫读它 |
| `S2NativePagerViewController.nxHandoffPageIndex` | 外层控制器（私有） | 打开窗口的页索引 |
| `S2NativePagerViewController.noteInnerHandoffIfNeeded(on:dragVector:isDragActive:)` | 外层控制器 | 交接点判据 + 开窗；只读几何 |
| `S2NativePagerViewController.closeNxHandoffWindow(reason:from:)` | 外层控制器 | 关窗；未开时零副作用 |
| 逐帧字段 ×5 | `S2OnDeviceTransitionFrameSample` | `pagingIsTracking` / `zoomIsTracking` / `zoomIsDragging` / `zoomPanState` / `zoomDirectionalLock`，均带默认值 `nil`，既有构造点不变 |
| 记录入口 ×4 | `S2OnDeviceTransitionDiagnosticsCoordinator` | `recordNxInnerPanDecision` / `recordNxHandoffPoint` / `recordNxHandoffWindow` / `recordOuterWillBeginDragging` |

## 修改的既有产品代码

| 位置 | 改动 | 是否改变行为 |
|---|---|---|
| `S2NativeZoomScrollView.configureNativeZoom()` | 给 `panGestureRecognizer` 加一个 target | 否（不改识别器任何属性） |
| `S2NativeZoomScrollView.updatePanAvailability()` | `shouldEnable == false` 时调 `clearGestureScopedInteractionState()` | 是（复位 1x 清方向锁） |
| `S2NativeZoomPageController.viewDidLoad()` | 给 `zoomScrollView.panGestureRecognizer` 加一个 target | 否 |
| `S2NativeZoomPageController.scrollViewDidScroll(_:)` | 在 `reportNativeViewport` **之前**插入 `noteInnerHandoffIfNeeded` | 是（新增交接点判据；只读，不写偏移） |
| `S2NativeZoomPageController.scrollViewWillBeginZooming(_:with:)` | 原复合 guard 的第一项拆出，插入清零 | 是（捏合开始清方向锁）；判定条件逐项不变 |
| `S2NativePagerViewController.apply(...)` | 外层偏移写入守卫增加 `!isNxHandoffWindowOpen` | 是（R3） |
| `S2NativePagerViewController.layoutNativePages()` | 同上 | 是（R3） |
| `S2NativePagerViewController.scrollViewWillBeginDragging(_:)` | 插入 `recordOuterWillBeginDragging` | 否（只记录） |
| `S2NativePagerViewController.scrollViewDidEndDragging(_:willDecelerate:)` | `!decelerate` 分支内关窗 | 是（R3） |
| `S2NativePagerViewController.scrollViewDidEndDecelerating(_:)` | 关窗 | 是（R3） |
| `S2NativePagerViewController.finishNativePaging()` | 关窗 + 各页清零 | 是（R2/R3） |
| `S2NativePagerViewController.resetInteractionState()` | 关窗 + 各页清零 | 是（R2/R3） |
| `S2NativePagerViewController.handleDoubleTap(on:at:)` | 该页清零 | 是（双击清方向锁） |
| `S2OnDeviceTransitionDiagnosticsCoordinator.captureFrame()` | 填五个新字段 | 否 |
| `S2OnDeviceTransitionDiagnosticsCoordinator.recordPagingContentOffsetWrite(...)` | details 追加两项，取自 `controller?.pagingScrollView`；**签名未变** | 否（只改导出文本） |
| `S2OnDeviceTransitionText.export(...)` | 头部字段声明行追加五项；逐帧行拆成 base/paging/nx/handoff 四段拼接 | 否（既有 22 列顺序与取值一字不变） |

## 测试

- 新增 8 个：
  `testIC091G185SceneEHandoffProbeFieldsAndEvents`、`testIC091G185HandoffRuleBoundaries`、
  `testIC091G186A1NxInnerBounceFlagsRemainFalse`、`testIC091G186A2HandoffPointOpensWindowAndSuppressesApplyWrite`、
  `testIC091G186A3VerticalDominantStartProducesNoHandoff`、`testIC091G186A4GestureScopedStateIsClearedAtEveryBoundary`、
  `testIC091G186A5DirectionalLockIsScopedToOneGesture`、`testIC091G186A6EdgeStartKeepsIC089Decision`。
- 修改 1 行（IC-079 G141 内）：`details.hasSuffix("animated=false")` → `details.contains("；animated=false；")`。R1 按卡把 `外层setContentOffset` 的 details 在 `animated=` 之后追加了两项，原后缀判据不再成立；改后的判据与原判据在计数语义上等价（只统计非动画写入）。**这是测试适配产品，不是为测试改产品。**
- 删除 0 个。新增测试基础设施：私有辅助 `makeIC091NxFixture`、`ic091EngageDirectionalLock`、`assertIC091InnerRestingProperties`、`ic091EventDetails`、`ic091EventCount`、`ic091OuterWriteSources`。
- 计数算式：477 + 8 − 0 = **485**（CI #157 与 #158 报告的 `Executed` 数一致）。
- `bfb2b8b` 只改 A2 内部断言，不增删测试函数，计数不变。

## 占位值登记

本卡**未新增任何标定参数，未改任何出厂值**。`S2CalibrationConfiguration.factoryPlaceholder` 与 `S2Calibration.swift` 整体 `git diff` 为空，`schemaVersion` 保持 **3**（IC-087 定案值，未递增）。

`S2NxEdgeHandoffRule.edgeTolerance = 0.5 pt` 不是标定参数，也不是规格量：它是「内层是否已到内容边界」的**浮点比较容差**，复制自 IC-089 `7178de4` 原值，不进 `S2CalibrationConfiguration`、不进面板、不参与任何距离 / 速度 / 倍数语义。

## 未变更

内层 `bounces`（全程 false）、`alwaysBounce*`、`bouncesZoom`、`bounds.didSet` 钳制、捏合接管、双击 / 显隐过渡、页窗口（IC-079）、1x 翻页、贴边起手路径、图片请求、横栏、操作条、标记、`pinchMaxScale*`、`edgePaging*`、全部出厂值与 `schemaVersion`；`S2StateMachine.swift`、`S2Calibration.swift`、`S2View.swift`、`Localizable.xcstrings`、`Scripts/`、`ci.yml`、`<top>/SPEC-*.md`、`<top>/Decision_log.md` 均无 diff。未新增 XCUITest。未合并主干，未 force push，未改写历史，未动 `feature/ic-089-nx-edge-bounce`。
