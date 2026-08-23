# IC-082 变更清单（v2 卡，R1～R3）

分支 `feature/ic-082-nx-edge-paging`，自 `main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出。最终被测提交 `cfc08bb1500c94514bf0c0fbf3a7834b3f5d1b7f`（CI #140，457 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `e8fe8c1` | R1 | `S2NativePhotoPager.swift`、`S2View.swift`、`Localizable.xcstrings`、`Reports/IC-068/export-format.md`、`S2CalibrationHarnessTests.swift` | 场景 E；逐帧 +3 字段；事件 +3；文档追加；G139 头部更新；G152；探针 |
| `079e825` | R2 | `S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift` | `startedAtPagingEdge(for:)`；`finishNXEdgePaging` 改用；G153 |
| `ace3146` / `60cc1f6` | 修正 | 注释引号 / 测试文件编码 | 产品行为无变化 |
| `31172b3` | docs | `Reports/IC-082/` | 阶段一报告 |
| `ba2e0f2` | R3 | `S2NativePhotoPager.swift`（−232 行）、`S2Calibration.swift`、`Reports/IC-068/export-format.md`、`S2CalibrationHarnessTests.swift` | 删除 `S2NxEdgePagingInteraction`/`S2NxEdgePagingProjection`、`begin/update/finish/resetNXEdgePaging`、`handleNativePan` 与页控制器的 pan 目标注册、`recordNXEdgePagingBegin` 与两个诊断读取口；`recordHorizontalSwipe(…, source:)` 并在 `reportSequenceBoundaryAttemptIfNeeded` 记录；逐帧三字段恒 nil；`edgePagingTriggerDistance/Velocity` 登记 `unwired`；文档追加 R3 说明；G152/G153 改写、探针与 B1 删除、G154 新增 |
| `cfc08bb` | R3 测试 | `S2CalibrationHarnessTests.swift` | G154 来源断言改白名单，使全分支 grep 被删标识为 0 |

## 产品行为变化

- Nx 下左右拖动：内层缩放滚动视图在拖动方向仍可滚动时只平移；内层到达内容边界后，同一手势由 UIKit 嵌套滚动交接给外层分页容器，按原生分页判定翻页、原生橡皮筋回弹；不再有自定义投影写外层偏移。翻页结算沿用 `finishNativePaging`。
- `handleHorizontalSwipe` 的阈值判定在产品路径仅剩序列边界尝试记录；`edgePagingTriggerDistance/Velocity` 出厂值不变、规格状态 `decided`、接线 `unwired`。
- 诊断录制场景 E：三个 nx 字段保留列位恒 `nil`；`beginNXEdgePaging` 事件不再产生；`handleHorizontalSwipe` 事件来源改为 `reportSequenceBoundaryAttemptIfNeeded`。

## 测试

新增 3（G152、G153、G154）；修改 4（G139 头部、`testIC067C5ParameterConnectionStatusesCoverEveryFieldExactlyOnce` 两行 `.unwired`、R2 阶段的 G152/G153 在 R3 改写）；删除 2（`testB1NxBoundaryContinuationProducesPagingDisplacement`、`testIC082R1NxEdgePagingStartConditionProbe`）。计数 455 → 457。

## 未变更

阈值出厂值与参数集合；1x 翻页、页窗口（IC-079）、图片请求、横栏、操作条、标记、`pinchMaxScale`；捏合接管、居中、描边、过渡；内层 `bounces=false`；`Scripts/`、`ci.yml`、SPEC、Decision_log；XCUITest。

## 占位值登记

本卡无新增占位值。`edgePagingTriggerDistance = 40`、`edgePagingTriggerVelocity = 300`：decided / **unwired**（IC-082 R3 起），去留由 Decision_log 另记。
