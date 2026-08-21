# IC-070 变更清单

分支 `feature/ic-070-centering-handoff`，自 `main`（`1643c4e`，产品代码等同继承提交 `143cd32`）切出。最终被测提交 `9bffcd31399bcd47bbada60f59f655b9f2138246`（CI #119）。

## 提交

| SHA | 类型 | 文件 | 说明 |
|---|---|---|---|
| `029e97736ebedc250db0dbcc2b6c2ff71c66df8f` | R7 diag | `S2NativePhotoPager.swift`（+15/−1）、`S2CalibrationHarnessTests.swift`（+48） | `S2OnDeviceTransitionFrameSample` 新增 `contentInset`、`adjustedContentInset`；`captureFrame` 采集；导出头部字段声明与 frame 行新增两个字段，新增 `optionalInsets` 格式化；G49 样本构造同步；新增 G79 |
| `78dda0c6ff0b1d174760f71264113edec18441f1` | test 探针 | `S2CalibrationHarnessTests.swift`（+239） | `testIC070R5TakeoverCenteringProbe`、`testIC070R6BorderConcentricityProbe`（仅打印）及像素扫描夹具 |
| `3273bb1c7f201b288cc46ace7af9a3cb028c35c6` | R5 fix | `S2NativePhotoPager.swift`（+25）、`S2CalibrationHarnessTests.swift`（+80） | `S2NativeZoomScrollView.applyJointCentering()`：inset 与内容小于视口方向的 offset 一并写入，`layoutSubviews` 与 `prepareNativeZoomGeometry` 调用；新增 G75/G76 |
| `c45ac2f77232f4275991cb1e6ac7e249d2d60837` | R6 fix | `S2NativePhotoPager.swift`（+26）、`S2CalibrationHarnessTests.swift`（+323/−17） | `S2NativeZoomPageController.removeFitBorderAnimations(source:)`，在 `applyPageImmediately` 与非过渡期 `applyCornerMask` 调用并记诊断事件；夹具重构为 `BorderScanScene`/`renderBorderScan`/`borderScanReading`；新增 G77/G78 |
| `9bffcd31399bcd47bbada60f59f655b9f2138246` | R5 fix 补充 | `S2NativePhotoPager.swift`（+29）、`S2CalibrationHarnessTests.swift`（+4） | `S2NativeZoomScrollView.bounds` 的 `didSet`：内容小于视口方向的偏移在写入瞬间钳回 `-contentInset`（带重入保护）；G75 增加写入后立即断言与 `setContentOffset` 路径 |

## 产品行为变化

- **捏合接管**：接管提交内 `contentSize`、`contentInset`、`contentOffset` 同时就位；任何来源对内容小于视口方向的偏移写入都在写入瞬间被钳回 `-inset`，接管帧与后续每帧的照片几何中心与视口中心重合。内容大于视口的方向偏移不受影响，`s > 1` 平移边界语义不变。
- **内缩态描边**：显隐过渡收口时描边层残留动画与照片层动画一并清除；非过渡期的几何提交也做同样清理。描边层圆角与线宽回到当前页目标值，与照片圆角同心。
- **诊断导出**：逐帧记录新增 `contentInset=(top=…,left=…,bottom=…,right=…)` 与 `adjustedContentInset=(…)`；新增事件 `照片动画调用 operation=removeAllAnimations；key=fitBorderLayer.*`（仅在录制开启时记录，关闭时零副作用）。

## 未变更（范围外确认）

- 出厂值：`fitBorderWidth=1`、`fitBorderDarkAlpha=0.09`、`fitBorderLightAlpha=0.055`、`fitCornerRadius=28` 等全部未动（测试中的不透明描边为测试专用配置）
- `S2TemporaryPhotoImageStrategy.swift`、图片请求策略、`debugAssetLimit`、分页复用结构、页面生命周期、Nx 手势分层门控、截图元数据判定、明暗背景、双击倍率：未改
- IC-069 `hasResolvedAssetGeometry` 门禁、CA 动画驱动、首帧基准：未回退
- SPEC、Decision_log、S1、S3～S5、`ci.yml`、`Scripts/`：未改
- 未新增 XCUITest；未合并 main；未删改任何 feature 分支与 worktree

## 测试数量

414（继承）→ 420：新增 G75/76（1 项）、G77、G78、G79、两个探针。
