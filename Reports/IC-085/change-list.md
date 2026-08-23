# IC-085 变更清单（v3 卡，R1 + R2 + R3）

分支 `feature/ic-085-bottom-strip-parity`，自 `main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出。最终被测提交 `64f06a0dc7f886ed658367d6933bf18a29bf1af1`（CI #146，471 项 0 失败，IPA 769 095 字节 / `1ab37cec…9ddb`）。R2 被测 `c659087`（CI #142，467/0）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `10dd8b4` | R1 docs | `Reports/IC-085/` | 测量报告初版（闸门 A 触发） |
| `e8a2d72` | R2-1 | `S2StateMachine.swift`、`S2Calibration.swift`、`S2View.swift`（1 行）、`S2CalibrationHarnessTests.swift`、`S2ImageLoadingStateTests.swift`、`S2StateMachineTests.swift` | `S2BottomStripMetrics` 字段重定义；六项横栏参数重设出厂值并改 decided、`edgeFadeWidth` 改 effective；新增 5 项；废止 `bottomStripDragMinimumDistance`（`DragGesture()` 改原生默认）；导出、登记表、CodingKeys、解码默认、编码；IC-074 G96/G97、IC-067 C5、ImageLoading 计数断言 37→41、23→34、14→7；测试中的配置/指标字面量 |
| `19f7acc` | R2-2 | `S2View.swift` | 新增 `S2BottomStripLayout`、`S2BottomStripInertia`、`S2BottomStripFrameDriving`/`S2BottomStripDisplayLinkFrameDriver`、`S2BottomStripMotionController`（含 `hooks(machine:onPhotoSwitch:)`）；`S2BottomStripView` 重写（接口不变） |
| `995fe6e` | R2-3 | `S2CalibrationHarnessTests.swift` | `S2BottomStripSystemReference`、`S2BottomStripManualFrameDriver`、`S2StripTestClock`、12 条 IC-085 测试 |
| `c659087` | R2-3 修正 | `S2CalibrationHarnessTests.swift` | G164 减速测试：dragging 断言限定在减速进行中（CI #141 失败原因） |
| `23a5ba5` | R2 docs | `Reports/IC-085/` | R2 报告 |
| `4f97999` | R3-2 参数 | `S2StateMachine.swift`、`S2Calibration.swift`、`S2CalibrationHarnessTests.swift`、`S2ImageLoadingStateTests.swift`、`S2StateMachineTests.swift` | `bottomStripFlickVelocityThreshold = 300`（placeholder/effective）；`S2BottomStripMetrics.flickVelocityThreshold`；导出、登记、CodingKeys、解码默认；计数 41→42、placeholder 7→8；测试字面量 |
| `e7d00f5` | R3-1/2/3 | `S2View.swift` | `S2BottomStripLayout.fillContentSize`；视图内容框 aspectFill + 帧裁切、`assetAspectRatio` 参数、首帧同步；`endDrag` 阈值；`synchronize(animated:)` 翻页跟随动画 |
| `282f129` / `64f06a0` | R3-4 | `S2CalibrationHarnessTests.swift` | 4 条 R3 测试 + `S2StripBitmap` 位图夹具；期望值修正 |
| 本提交 | docs | `Reports/IC-085/` | 自验报告与变更清单完整版（v3） |

## 产品行为变化

- 横栏几何：邻居 20×30 pt、间距 3；静止态当前张 30×30 方形放大、两侧间隙 13；滑动态全部 20×30 等距 3；内容带高 30（两态相同）；两侧 20.3 pt 内不可见，随后 18.7 pt 线性渐隐。
- 横栏运动：拖动开始 100 ms 收缩；跟手拖动中跨节距中点即切主图（触感不变）；松手按 k = 0.998 指数减速并持续切图；停止后 600 ms ease-out 吸附到最近项并展开当前张；减速中触下直接接管。
- 状态机：`bottomStripState` 取值与转换函数不变；`.dragging` 现覆盖拖动 + 惯性减速两段，吸附展开在 `.idle` 下完成。
- 只为视口附近索引创建缩略图内容视图（原实现对全部资产布局）。
- **R3**：缩略图内容按资产宽高比 aspectFill 放大后以固定项目帧居中裁切（横竖图等大）；松手手指速度 < 300 pt/s 无惯性直接吸附展开；主图翻页引起的定位项变化横栏以 600 ms ease-out 滚到新张并展开（横栏拖动引起的不触发）；首帧即居中。

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
| `bottomStripFlickVelocityThreshold` | — | 300 | **R3 新增 placeholder / effective**（④技术负责人取定） |

`bottomStripMarkSize` 及其他全部参数出厂值不变。字段 42、导出 46 行、登记表 42（decided 34 / placeholder 8）、schemaVersion 仍为 2。

## 测试

新增 16（R2：G162×2、G163×3、G164×5、主图随横栏、惯性闭式解；R3：固定帧与填满、慢拖无惯性、翻页跟随、像素门禁）；修改 4（IC-067 C5、IC-074 G96、IC-074 G97、ImageLoading 登记计数，R2/R3 各改一次）+ 字面量更新；删除 0。计数 455 → 467 → 471。

## 未变更

主图手势、1x/Nx 翻页、捏合、居中、描边、过渡动画、图片请求；顶部信息区、操作条、主图标记；横栏标记符号与尺寸；`PhotoCleanupMVEApp.swift`、`S2TemporaryPhotoImageView`（闸门 D）；`Scripts/`、`ci.yml`、SPEC、Decision_log；XCUITest；`project.pbxproj`（未新增源文件）。

## 占位值登记

R3 新增 placeholder 1 项：`bottomStripFlickVelocityThreshold = 300`（④）。三个③实现常量未登记：`S2BottomStripInertia.stopSpeed = 20 pt/s`、`settleTimeConstant = 125 ms`、收缩二次 ease-out。
