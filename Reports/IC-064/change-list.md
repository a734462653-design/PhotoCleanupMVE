# IC-20260817-064 变更清单

## 产品代码

1. `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
   - 新增 `presentationToggleDuration` 与三项描边参数，补齐默认值、校验、兼容解码、持久化和导出。
   - 保留既有双击动画参数与静止态几何参数。
2. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
   - 将 s=1 显隐改为终态预提交后的中心等比 transform 动画。
   - 动画圆角与描边，消除完成后的二次几何提交。
   - 按屏幕比例、倍率与 trait 应用描边。
3. `PhotoCleanupMVE/Features/S2/S2View.swift`
   - 在 debug 面板接入显隐时长和三项描边参数。

## 测试与报告

4. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
   - 新增 60Hz `layer.presentation()` 测量夹具。
   - 新增 G13～G22、独立显隐时长及三场景 @3x 描边像素断言。
   - 更新原有显隐测试以匹配动画开始前提交终态几何的时序。
5. `Reports/IC-064/self-check.md`
   - 记录静态结果、待补的模拟器/CI 证据及 IC-063 两项遗留说明。
6. `Reports/IC-064/change-list.md`
   - 本变更清单。

未修改规格、决策日志、`S2StateMachine.swift`、`S2TemporaryPhotoImageStrategy.swift`、`CleanupCoordinator.swift`、双击过渡或 Nx 手势实现。
