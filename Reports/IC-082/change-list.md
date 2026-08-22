# IC-082 变更清单（阶段一：R1 + R2）

分支 `feature/ic-082-nx-edge-paging`，自 `main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出。阶段被测提交 `60cc1f6f6cc853131f317102ffac2e48b7c16f73`（CI #137，458 项 0 失败）。R3 未开始。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `e8fe8c1` | R1 | `S2NativePhotoPager.swift`、`S2View.swift`、`Localizable.xcstrings`、`Reports/IC-068/export-format.md`、`S2CalibrationHarnessTests.swift` | 场景 E；逐帧 +3 字段；事件 +3；诊断读取口；文档追加；G139 头部更新；G152；探针 |
| `079e825` | R2 | `S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift` | `S2NxEdgePagingInteraction.startedAtPagingEdge(for:)`（`edgeTolerance = 0.5`）；`finishNXEdgePaging` 改用它；G153 |
| `ace3146` | 修正 | `S2NativePhotoPager.swift` | 注释引号 |
| `60cc1f6` | 修正 | `S2CalibrationHarnessTests.swift` | 恢复 UTF-8 编码 |

## 产品行为变化

- Nx 贴边翻页起始条件：拖动开始时缩放内容在拖动方向的边界与视口边界距离 ≤ 0.5pt 才进入贴边翻页判定；否则本次拖动只平移，无论溢出多少都不翻页。`edgePagingTriggerDistance/Velocity` 阈值不变。
- 诊断录制新增场景 E（格式版本仍 1，文档只追加）。

## 测试

新增 3、修改 1（G139 头部）、删除 0；计数 455 → 458。

## 未变更

阈值出厂值与参数集合；1x 翻页、页窗口、图片请求、横栏、操作条、标记、`pinchMaxScale`；捏合接管、居中、过渡；`Scripts/`、`ci.yml`、SPEC、Decision_log；XCUITest。
