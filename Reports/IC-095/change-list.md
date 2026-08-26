# IC-095 变更清单（apply 重进的根因修复 / 写入条件化与幂等）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交（开工时 `main`） | `3cc1e227d17b80f2fd44fa8478cda698652d275d` |
| 分支 | `feature/ic-095-apply-idempotent-writes` |
| 分支 tip（代码部分，CI #167 被测提交） | `47858f47805460e4155a721843bf5bb6a545bfba` |
| 报告提交 | 承载本目录两份报告的 docs 提交（只含 `Reports/IC-095/`，命中 `paths-ignore`，**不触发 CI**，属规则七允许的同卡同分支追加） |

六个提交，各自可单独 cherry-pick：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `f173d52d0b15d51e1924bd5e094c1773b7985bf3` | `feat(diag): updateUIView 事件追加 wroteAnyGeometry 字段与两类几何写入埋点（IC-095 R1）` |
| 2 | `e43d00d2b2d35b7f60fe752bd55a131b409053f4` | `fix(s2): apply 外层写回与 layoutNativePages 重排条件化（IC-095 R2）` |
| 3 | `7496ad983003e1f90a52d4f2fc31948340c85ace` | `fix(s2): applyPage 下游写入条件化——applyNativeState 幂等、页输入未变不重建（IC-095 R3）` |
| 4 | `013ceeb9b8f5615d8e3d622be98fcf376b2c4225` | `fix(s2): reportNativeViewport 等值不发布（IC-095 R4）` |
| 5 | `685666c5808e2aeb256d6d0f797879c697ea7776` | `feat(diag): 联合居中写入补埋点并计入几何写入总数（IC-095 R1 补）` |
| 6 | `47858f47805460e4155a721843bf5bb6a545bfba` | `test(s2): IC-095 G207 F1~F4 写入条件化断言（夹具驱动）` |

## 文件变化（`git diff --numstat main..HEAD`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | 12 | 2 |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 301 | 36 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 392 | 2 |
| `Reports/IC-068/export-format.md` | 30 | 0 |

测试文件的 2 处删除是 `recordUpdateUIView` 两处调用因新增参数改为多行写法，**没有任何既有断言被删除或弱化**。`export-format.md` **只增不删**。

## 逐项改动

### R1 诊断埋点（提交 1、5）

**新增计数**（`S2OnDeviceTransitionDiagnosticsCoordinator`，均只在 `isRecording` 为真时累加，`start()` 时清零）：

- `geometryWriteCount`：录制窗口内**确有落笔**的几何写入总数。
- `pagingContentOffsetWriteCount`：外层分页容器 `setContentOffset` 的实际写入次数。

计入 `geometryWriteCount` 的**七类**埋点（空转不计）：`外层setContentOffset`、`页frame写入`、`内层setContentOffset`、`联合居中写入`、`setZoomScale`、`吸附归位写入`（四个布尔任一为真时）、`照片几何写入`。

**新增事件三类**：

| 事件名 | 来源 | 记录条件 |
|---|---|---|
| `页frame写入` | `S2NativePagerViewController.layoutNativePages` | 页控制器 `view.frame` 与目标 frame 不等、确实赋值时 |
| `内层setContentOffset` | `S2NativeZoomScrollView.applyNativeState` | 目标偏移与当前偏移之差超过 `0.000001`、确实写入时 |
| `联合居中写入` | `S2NativeZoomScrollView.applyJointCentering` | `contentInset` 或 `contentOffset` 确有改动时（**此路径改前完全无埋点**） |

**既有事件字段追加一处**：`updateUIView` 的 `details` 由 `写入照片几何=…` 变为 `写入照片几何=…；写入任意几何=…`。前一字段语义与口径不变；后者取本次 `apply(...)` 期间 `geometryWriteCount` 的差值。

**函数签名变化一处**：`recordUpdateUIView(wrotePhotoGeometry:)` → `recordUpdateUIView(wrotePhotoGeometry:wroteAnyGeometry:)`。两处既有测试调用同步改为具名多行写法。

**文本工具**：`S2OnDeviceTransitionText.point(_:)` 由内部新增（与既有逐帧 `contentOffset` 同格式）。

### R2 外层写回与重排条件化（提交 2）

- **新增** `S2NativeZoomPageController.isInteractionOrTransitionActive`（内部只读计算属性）：本页是否有捏合、双击过渡、呈现过渡、内层 tracking / dragging / decelerating / zooming 之一在途。
- **新增** `S2NativePagerViewController.pendingSettledPagingOffset() -> CGPoint?`：外层静止偏移写回的唯一判定入口（判定条件原文见 `self-check.md` 第三节一）。`apply` 与 `layoutNativePages` 两个写入点共用它，各自保留原来的写入方式与来源字符串（`apply` 用 `writePagingContentOffset(animated:false)`，`layoutNativePages` 用 `contentOffset` 直接赋值）。
- **新增** `S2NativePagerLayoutInputs`（私有 `Equatable` 结构）与 `lastLayoutInputs` / `currentLayoutInputs()`：`layoutNativePages` 的重排输入比较。
- **拆分** `layoutNativePages()` 的循环体到 `layoutNativePagesUnconditionally()`；`isApplyingSnapshot` 的括起范围与改前逐字相同。
- 页 frame 的实际写入补记 `页frame写入` 事件。

### R3 `applyPage` 下游条件化（提交 3）

- `enforceOneXContentGeometry(diagnosticSource:)` 改为 `@discardableResult … -> Bool`，返回本次是否确有落笔；**逐项 `!=` 守卫与 `吸附归位写入` 事件一字未动**。
- `applyNativeState(scale:viewportOffset:)`：无条件的 `setNeedsLayout(); layoutIfNeeded()` 改为「确有落笔才 `setNeedsLayout()`，`layoutIfNeeded()` 保留」。独立 `contentOffset` 写入补记 `内层setContentOffset` 事件，`independentContentOffsetWriteCount` 口径不变。
- `S2NativeZoomPageController.update(...)`：1x 尾段新增 `pageInputsAreUnchanged` 判定（原文见 `self-check.md` 第三节三(a)），成立时跳过 `applyPageImmediately`；`applyNativeState` 与 `applyCornerMask` 照常下发。
- **新增私有字段** `hasAppliedPageImmediately`，在 `applyPageImmediately` 末尾置真。

### R4 状态机等值不发布（提交 4）

`S2StateMachine.reportNativeViewport(scale:viewportOffset:)`：钳制表达式逐字不变，改为「与当前值不等才赋值」。**`@Published` 属性集合未变**，发布出去的值序列与时序不变。

### 测试（提交 6）

`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` 新增 **5** 项，全部为夹具驱动、真机未覆盖：

| 测试函数 | 覆盖 |
|---|---|
| `testIC095G207F1IdleApplyWritesNoGeometry` | F1 静止态连调 `apply` 10 次零几何写入 |
| `testIC095G207F1HostedUpdateUIViewReportsNoGeometryWrite` | F1b 宿主 `S2View` 下 `updateUIView` 的 `写入任意几何=false` |
| `testIC095G207F2NxViewportPanKeepsPagingOffsetWritesAtZero` | F2 Nx 平移期间外层写入 0 |
| `testIC095G207F3DeviatedPagingOffsetIsRealignedExactlyOnce` | F3 带偏 5 pt 恰归位一次 / 动画在途不写 |
| `testIC095G207F4PageSetAndViewportChangesStillRelayout` | F4 页集合与视口尺寸变化仍正常重排 |

### 文档（提交 1、5）

`Reports/IC-068/export-format.md` 追加「自 IC-095 起的字段与事件追加（格式版本仍为 1）」一节：`updateUIView` 的字段追加、三类新事件、静止态导出的判读口径。**上文任何既有约定一字未改**，逐帧字段一个未加，头部「格式版本=1」未递增。

## 占位值登记

**本卡未新增、未修改、未删除任何 `factoryPlaceholder` 占位值。**

- `S2CalibrationConfiguration` **未加任何字段**（卡内明列的禁止项）。
- 出厂值一个未改。
- `S2CalibrationConfiguration.schemaVersion` **仍为 4**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`），按 IC-087 定案无需递增。
- 唯一新增的常量是 `ε = 0.000_001`，沿用文件内既有的精度惯例（`applyNativeState` / `applyJointCentering` / `enforceOneXContentGeometry` 已在用同一个值），不是规格量、不是未定项。
- 未定项（含未定项 8 图像加载态与请求策略）一项未触碰。

## 产品行为净变化（相对 `3cc1e22`）

**用户可见行为与几何结果：零变化。** 所有改动的形式都是「条件不成立时写入的值与现值完全相同，因此不写」。写入的值、写入的时机（条件成立时）、最终几何全部与改前一致。

不可见的变化三项：

1. 静止态与「输入未变」的重进不再产生几何写入、不再强制布局，因此 `layoutSubviews` 回调次数大幅下降。
2. 内层手势 / 缩放 / 减速 / 过渡动画在途时，外层偏移不再被逐帧写回静止值——UIKit 自己的嵌套滚动交接行为不再被掩盖（`Q2.txt` 现象的直接对应）。
3. `reportNativeViewport` 收到与当前值相同的视口时不再触发一次 `objectWillChange`，SwiftUI 重进次数随之下降。

## 未合并

**本卡不合并 `main`，不 force push，不改写历史。** 089 / 091 / 092 冻结分支未触碰。
