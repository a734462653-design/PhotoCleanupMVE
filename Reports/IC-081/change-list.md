# IC-081 变更清单

分支 `feature/ic-081-pinch-max-multiplier`，自 `main` = `origin/main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13`（IC-080 合并后）切出。最终被测提交见自验报告。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `e03dbbf` | R1 | `S2Calibration.swift`、`Core/S2StateMachine.swift`、`S2CalibrationHarnessTests.swift`、`S2ImageLoadingStateTests.swift`、`S2StateMachineTests.swift` | `S2PinchMaxScaleRule.pinchMaxScale(…, multiplier:)`：`min(ceiling, max(floor, multiplier × s_1to1))`，乘数 ≤ 0 取 floor；新参数 `pinchMaxScaleOneToOneMultiplier`（出厂 2.0、placeholder/effective、解码缺省 2）；`S2ResolvedParameters` 增字段并校验 `> 0`；G132 断言表按乘数 2.0 重算；字段 38 / 导出 42 / 登记表 38（decided 23、placeholder 15）计数适配；G134、G135 期望值适配；G149 测试（随 R1 提交入库，见自验报告） |
| `8672dbf` | R2 | `S2View.swift` | 标定面板 `pinchMaxScaleOneToOneMultiplier` 滑杆（`1…4`、步进 `0.1`），置于 `minDoubleTapScale` 之后；即时生效走既有链路 `calibrationBinding → S2CalibrationModel.update → machine.applyCalibration → pager.apply → update(maximumZoomScale: machine.pinchMaxScale(for:))`，产品侧无新几何写入 |
| `cacc1b6` | R2 编译修正 | `S2CalibrationHarnessTests.swift` | G149 照片 frame 改读 `zoomScrollView.presentationContentView?.frame`（`hostingController` 为 private，CI #132 编译失败） |

## 产品行为变化

- `pinchMaxScale = min(10, max(4, 2.0 × s_1to1))`。出厂乘数 2.0 下（视口 402×874、displayScale 3）：12MP 横拍 4032×3024 → 6.69，竖拍 3024×4032 → 5.01，屏幕像素截图 1206×2622 → 4，8000×6000 及以上 → 10。
- 标定面板可拖乘数 1.0…4.0，松手后当前页与后续页的 `maximumZoomScale` 按新值重写（静止态零几何写入，G149）。
- `pinchMaxScaleFloor = 4`、`pinchMaxScaleCeiling = 10` 未动；其余 36 个出厂值未动。

## 测试

- 新增 1 个：`testIC081G149MultiplierChangeUpdatesMaximumZoomScaleWithoutGeometryWrites`。
- 修改 9 个：`testIC078G132PinchMaxScaleRuleTable`（表重算 + 乘数 1/0 两条边界 + 导出行）、`testIC078G134…`（`large` = 10；末段增乘数 1 → 6.63 断言）、`testIC078G135…`（期望值计算传乘数 2）、`testL7FactoryDefaultsMatchSystemParityDecision`（+乘数 2）、`testIC074G96…`（38 / 42）、`testIC074G97…`（38、placeholder 15、乘数在 placeholder 集）、`testIC077G124…`（38 / 15）、`S2StateMachineTests.parameters`（+乘数 2）、持久化往返测试（+乘数 3）、接线状态测试（+乘数 effective）。
- 删除 0 个。计数 455 + 1 = 456。

## 未变更

floor/ceiling 与其他参数出厂值；Nx 贴边翻页、横栏、图片请求、操作条、标记；捏合接管、居中路径（闸门 A 未触发）；`Scripts/`、`ci.yml`、SPEC、Decision_log；未新增 XCUITest。

## 占位值登记（本卡新增）

> 格式沿用 IC-074～079：项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡。

| 项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| `pinchMaxScaleOneToOneMultiplier`（placeholder） | `2.0`（④ 技术负责人取定） | effective | 第十一节第 1 部分 `pinchMaxScale` 规则（Decision_log 第 123 条更正）；定案值待 H30 真机标定后由 Decision_log 记录 | IC-081 |
| 面板滑杆范围 / 步进 | `1.0…4.0` / `0.1` | effective | 卡内定案，非规格量 | IC-081 |
