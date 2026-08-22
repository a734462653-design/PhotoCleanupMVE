# IC-085 变更清单（v2 卡，R1 + R2）

分支 `feature/ic-085-bottom-strip-parity`，自 `main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出。最终被测提交 `c659087aa553b5964be39896c6b4098bb527d715`（CI #142，467 项 0 失败，IPA 768 522 字节 / `b9fef811…9e2f`）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `10dd8b4` | R1 docs | `Reports/IC-085/` | 测量报告初版（闸门 A 触发） |
| `e8a2d72` | R2-1 | `S2StateMachine.swift`、`S2Calibration.swift`、`S2View.swift`（1 行）、`S2CalibrationHarnessTests.swift`、`S2ImageLoadingStateTests.swift`、`S2StateMachineTests.swift` | `S2BottomStripMetrics` 字段重定义；六项横栏参数重设出厂值并改 decided、`edgeFadeWidth` 改 effective；新增 5 项；废止 `bottomStripDragMinimumDistance`（`DragGesture()` 改原生默认）；导出、登记表、CodingKeys、解码默认、编码；IC-074 G96/G97、IC-067 C5、ImageLoading 计数断言 37→41、23→34、14→7；测试中的配置/指标字面量 |
| `19f7acc` | R2-2 | `S2View.swift` | 新增 `S2BottomStripLayout`、`S2BottomStripInertia`、`S2BottomStripFrameDriving`/`S2BottomStripDisplayLinkFrameDriver`、`S2BottomStripMotionController`（含 `hooks(machine:onPhotoSwitch:)`）；`S2BottomStripView` 重写（接口不变） |
| `995fe6e` | R2-3 | `S2CalibrationHarnessTests.swift` | `S2BottomStripSystemReference`、`S2BottomStripManualFrameDriver`、`S2StripTestClock`、12 条 IC-085 测试 |
| `c659087` | R2-3 修正 | `S2CalibrationHarnessTests.swift` | G164 减速测试：dragging 断言限定在减速进行中（CI #141 失败原因） |
| 本提交 | docs | `Reports/IC-085/` | 自验报告与变更清单完整版 |

## 产品行为变化

- 横栏几何：邻居 20×30 pt、间距 3；静止态当前张 30×30 方形放大、两侧间隙 13；滑动态全部 20×30 等距 3；内容带高 30（两态相同）；两侧 20.3 pt 内不可见，随后 18.7 pt 线性渐隐。
- 横栏运动：拖动开始 100 ms 收缩；跟手拖动中跨节距中点即切主图（触感不变）；松手按 k = 0.998 指数减速并持续切图；停止后 600 ms ease-out 吸附到最近项并展开当前张；减速中触下直接接管。
- 状态机：`bottomStripState` 取值与转换函数不变；`.dragging` 现覆盖拖动 + 惯性减速两段，吸附展开在 `.idle` 下完成。
- 只为视口附近索引创建缩略图内容视图（原实现对全部资产布局）。

## 参数

| 参数 | 旧 | 新 | 状态 |
|---|---|---|---|
| `bottomStripCurrentItemSize` | 72 placeholder | 30 | decided / effective |
| `bottomStripNeighborItemWidth` | 52 placeholder | 20 | decided / effective |
| `bottomStripNeighborItemHeight` | 44 placeholder | 30 | decided / effective |
| `bottomStripItemSpacing` | 8 placeholder | 3 | decided / effective |
| `bottomStripEdgeFadeWidth` | 24 placeholder/unwired | 18.7 | decided / effective |
| `bottomStripSwitchDistance` | 44 placeholder | 23 | decided / effective |
| `bottomStripDragMinimumDistance` | 4 | — | **废止** |
| `bottomStripCurrentItemGap` | — | 13 | 新增 decided / effective |
| `bottomStripLeadingInset` | — | 20.3 | 新增 decided / effective |
| `bottomStripDecelerationRate` | — | 0.998 | 新增 decided / effective |
| `bottomStripExpandDurationMilliseconds` | — | 600 | 新增 decided / effective |
| `bottomStripCollapseDurationMilliseconds` | — | 100 | 新增 decided / effective |

`bottomStripMarkSize` 及其他全部参数出厂值不变。字段 41、导出 45 行、登记表 41（decided 34 / placeholder 7）、schemaVersion 仍为 2。

## 测试

新增 12（IC-085 G162×2、G163×3、G164×5、主图随横栏、惯性闭式解）；修改 4（IC-067 C5、IC-074 G96、IC-074 G97、ImageLoading 登记计数）+ 字面量更新 2 处（`S2CalibrationHarnessTests` 出厂配置、`S2StateMachineTests` 指标）；删除 0。计数 455 → 467。

## 未变更

主图手势、1x/Nx 翻页、捏合、居中、描边、过渡动画、图片请求；顶部信息区、操作条、主图标记；横栏标记符号与尺寸；`Scripts/`、`ci.yml`、SPEC、Decision_log；XCUITest；`project.pbxproj`（未新增源文件）。

## 占位值登记

本卡无新增 placeholder 参数。三个③实现常量未登记：`S2BottomStripInertia.stopSpeed = 20 pt/s`、`settleTimeConstant = 125 ms`、收缩二次 ease-out。
