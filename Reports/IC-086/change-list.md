# IC-086 变更清单

分支 `feature/ic-086-pinch-max-retune`，自 `feature/ic-081-pinch-max-multiplier` 尖 `a294254`（产品代码 = CI #134 被测 `d71e038`）切出，IC-081 的续卡，两者一起合并。最终被测提交 `d156d955232a040ee857d03325c0a19e7b9bcf55`（CI #144，456 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `49c413e` | R1 | `Features/S2/S2Calibration.swift`、`Features/S2/S2View.swift`、`S2CalibrationHarnessTests.swift`、`S2StateMachineTests.swift` | `factoryPlaceholder`：`pinchMaxScaleOneToOneMultiplier` 2 → 6、`pinchMaxScaleCeiling` 10 → 40（floor 4 不动）；旧版持久化解码回退值同步 2 → 6、10 → 40；面板乘数滑杆 `1…4` → `2…10`（步进 0.1 不变）。测试：L7 出厂配置；G132/G148 断言表重算为七行（6 / 20.06 / 15.04 / 23.24 / 39.80 / 40 / 4，去掉 16000×12000 行、加入 4672×7008 行）；导出字符串 `pinchMaxScaleCeiling=40`、`…Multiplier=6`；G134（`large` = 6×8000/1206 ≈ 39.80、截图页上限 6、双击/视口目标 12 → 50、ceiling 降 5 时 asset-2 亦钳到 5）；G135、G149 的期望值计算 ceiling/乘数 10/2 → 40/6 |
| `d156d95` | R1 测试适配 | `S2CalibrationHarnessTests.swift`、`S2StateMachineTests.swift` | G97 出厂值断言 2 / 10 → 6 / 40；`S2StateMachineTests.parameters` 夹具 ceiling/乘数 10 / 2 → 40 / 6（CI #143 两项失败，见自验报告） |

## 产品行为变化

- `pinchMaxScale = min(40, max(4, 6.0 × s_1to1))`。出厂乘数 6.0 下（视口 402×874、displayScale 3）：屏幕像素截图 1206×2622 → 6，12MP 横拍 4032×3024 → 20.06，竖拍 3024×4032 → 15.04，48MP 横拍 8000×6000 → 39.80，12000×9000 及以上 → 40（天花板）。
- 标定面板乘数滑杆可拖 2.0…10.0；调节后经既有 `applyCalibration → apply` 链路即时重写各页 `maximumZoomScale`（IC-081 G149，本卡仅更新期望值）。
- `pinchMaxScaleFloor = 4` 未动；其余 36 个出厂值与 `d71e038` 逐项相等。规则函数、登记状态（乘数 placeholder / effective，floor、ceiling decided / effective）未动。

## 测试

- 新增 0 个，删除 0 个。计数 456。
- 修改 7 处：`testL7FactoryDefaultsMatchSystemParityDecision`、`testIC078G132PinchMaxScaleRuleTable`、`testIC078G134PinchMaxScaleClampsPerAssetAndRecomputesAfterPaging`、`testIC078G135PerPageMaximumZoomScaleFollowsAssetWithoutGeometryWrites`、`testIC081G149MultiplierChangeUpdatesMaximumZoomScaleWithoutGeometryWrites`、`testIC074G97ParameterRegistryDecidedSetMatchesV15`、`S2StateMachineTests.parameters`（私有夹具）。

## 未变更

规则函数 `S2PinchMaxScaleRule`；floor；图片请求策略；捏合接管、居中；`S2NativePhotoPager.swift`、`Core/S2StateMachine.swift`（含 `S2ResolvedParameters.init` 乘数默认参数值 2）；`Scripts/`、`ci.yml`、SPEC、Decision_log；未新增 XCUITest；未合并主干。

## 占位值登记（本卡更新）

> 格式沿用 IC-074～081：项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡。

| 项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| `pinchMaxScaleOneToOneMultiplier`（placeholder） | `6.0`（④ 技术负责人取定，原 2.0） | effective | 第十一节第 1 部分 `pinchMaxScale` 规则（Decision_log 第 123 条）；定案值待 H34 真机标定后由 Decision_log 记录 | IC-081 → IC-086 |
| `pinchMaxScaleCeiling`（decided） | `40`（④ 防御值，原 10） | effective | 同上；6 × 1:1 对 48MP 横拍 ≈ 32，留余量 | IC-078 → IC-086 |
| 面板滑杆范围 / 步进 | `2.0…10.0` / `0.1`（原 `1.0…4.0`） | effective | 卡内定案，非规格量 | IC-081 → IC-086 |
