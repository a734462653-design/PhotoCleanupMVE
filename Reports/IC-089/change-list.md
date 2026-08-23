# IC-089 变更清单（IC-082 v3 R4）

分支 `feature/ic-089-nx-edge-bounce`，自 `main` = `bf7bab1`（IC-088 合并后）切出。被测提交 `7178de44ece5d1d802d5be7ab3deea1e15a1cef7`（CI #150，479 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `7178de4` | R4 | `Features/S2/S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift`、`Reports/IC-068/export-format.md` | 见下 |

## 产品变更

- 新增 `S2NxInnerPanDecision`（Equatable：`innerShouldBegin` / `horizontalDominant` / `atEdgeInDragDirection` / `distanceToEdgeInDragDirection`）与 `S2NxEdgeHandoffRule.innerPanDecision(zoomScale:minimumZoomScale:contentOffset:contentSize:viewportSize:contentInset:translation:velocity:)`：容差 `edgeTolerance = 0.5`；1x 不介入；水平主导（`|x| > |y|`）且拖动方向边界距离 ≤ 容差 → 内层不开始；向量优先 `translation`，零时退回 `velocity`。
- `S2NativeZoomScrollView`：
  - `updatePanAvailability()`：`bounces = (zoomScale > minimumZoomScale)`；`alwaysBounceHorizontal/Vertical`、`bouncesZoom` 保持 false。
  - `override gestureRecognizerShouldBegin(_:)`：先 `super`，仅对 `panGestureRecognizer` 按判定返回；记录 `lastInnerPanDecision` 与诊断事件。
  - `innerPanDecision(translation:velocity:)`：按当前几何求判定（夹具入口）。
- `S2OnDeviceTransitionDiagnosticsCoordinator.recordNxInnerPanDecision(...)`：事件 `nxInnerPanDecision`（仅录制时产生，零副作用）。
- 未改：`bounds.didSet` / `applyJointCentering`、捏合接管、双击/显隐过渡、1x 翻页、页窗口、图片请求、横栏、操作条、标记、`pinchMaxScale`、任何出厂值与参数。

## 产品行为变化

- Nx 下起始不贴边的横向拖动：内层平移到边界后原生橡皮筋越界、松手回弹、不翻页；竖向照常。
- Nx 下起始贴边且水平主导的拖动：内层 pan 不开始，外层分页容器接管整个手势，竖向分量丢弃；未翻页时内层保持接管前偏移。
- 1x：`bounces=false`、pan 禁用，与之前相同。

## 测试

- 新增 2 个：`testIC089G156bNxEdgeBounceAndHandoffVerticalLock`（夹具驱动）、`testIC089G156bHandoffRuleBoundaries`。
- 修改 2 个：`testP2NxPanStopsAtContentBoundaryWithoutExtraMargin`、`testIC082G154NxPagingHandsOffToOuterNativeScrollWithoutCustomWrites`——Nx `bounces` 断言 false → true（按 v3 定案），补 `alwaysBounce*` false。
- 删除 0 个。计数 477 + 2 = 479。

## 文档

- `Reports/IC-068/export-format.md` 末尾追加「自 IC-089 起的事件追加」一节（8 行），只增不删，格式版本仍为 1。

## 未变更

`edgePagingTriggerDistance/Velocity` 出厂值与登记（仍 decided / unwired）；`Scripts/`、`ci.yml`、SPEC、Decision_log；未新增 XCUITest；未合并主干。

## 占位值登记（本卡）

本卡不新增参数；`schemaVersion` 仍为 3。实现取定常量：贴边容差 0.5 pt（④ 卡内定案，代码常量 `S2NxEdgeHandoffRule.edgeTolerance`，非标定参数）。
