# IC-087 变更清单

分支 `feature/ic-087-calibration-schema-migration`，自 `feature/ic-086-pinch-max-retune` 尖 `43500bf`（产品代码 = CI #144 被测）切出，IC-086 的续卡，一起合并。最终被测提交 `43c5f4d53d3a565268df65cdd317cf5e532636df`（CI #147，458 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `c790b7e` | R1 | `Features/S2/S2Calibration.swift`、`S2CalibrationHarnessTests.swift` | `S2CalibrationConfiguration.schemaVersion` 2 → 3；`CodingKeys` 增 `schemaVersion`；`encode` 写顶层字段；`init(from:)` 先读 `schemaVersion`（缺失视为 0），≠ 代码版本抛 `S2CalibrationPersistenceError.schemaVersionMismatch(stored:expected:)`（枚举改为 `Equatable`）；`S2CalibrationPersisting` 新增 `delete()`；`S2KeychainCalibrationPersistence.delete()` = `SecItemDelete`（`errSecItemNotFound` 视为成功）；`S2DiscardingCalibrationPersistence.delete()` 空操作；`S2CalibrationModel.init` 捕获不匹配 → `factoryPlaceholder` + `delete()`，删除失败置 `persistenceFailed`，其他解码失败仍只回退出厂不删除；`restoreFactoryPlaceholder()` 改为 `delete()`（原 `persist()` 覆盖写入）。测试：G96 `schemaVersion=3`；`UserDefaultsCalibrationPersistence` 补 `delete()`；新增 G171、`InMemoryCalibrationPersistence` |
| `43c5f4d` | R2 | `Localizable.xcstrings`、`Features/S2/S2View.swift`、`S2CalibrationHarnessTests.swift` | `s2.calibration.restore_factory` 值「恢复项目判断默认值」→「【未定项 21 占位】恢复出厂值」（键沿用，目录 170 / 引用 170 不变）；按钮处两行注释说明即时生效链路（代码不变）；新增 G172 |
| （无提交） | R3 | `<top>/CLAUDE.md` | 第六节"回传给技术负责人的内容"之后追加一行："**出厂值变更必须递增 `S2CalibrationConfiguration.schemaVersion`**，否则 Keychain 中的旧值会覆盖新出厂值。（IC-087 定案；执行端在 change-list「占位值登记」节注明新版本号。）" |

## 产品行为变化

- 持久化 JSON 顶层新增 `"schemaVersion": 3`。冷启动构造 `S2CalibrationModel` 时：存储版本 ≠ 3（含 IC-081/086 包写入的无版本字段数据）→ 整套丢弃、采用出厂值、删除 Keychain 条目；= 3 → 逐字段解码（缺字段回退出厂值）不变。
- 「恢复出厂值」：配置重置为 `factoryPlaceholder`，Keychain 条目删除（不再覆盖写入出厂值）；经既有 `onChange(of: calibration.configuration) → machine.applyCalibration → pager.apply → update(maximumZoomScale:)` 即时生效。删除失败显示既有"持久化失败"文案。
- 面板按钮文案带未定项 21 占位前缀。
- 出厂值、规则函数、`pinchMaxScale` 接线、`SessionPersistence` 未动。

## 测试

- 新增 2 个：`testIC087G171SchemaVersionGateDiscardsStaleStoreAndDeletesEntry`、`testIC087G172RestoreFactoryResetsDeletesStoreAndAppliesToCurrentPage`。
- 修改 1 个：`testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`（版本 2 → 3）。
- 测试基础设施：`UserDefaultsCalibrationPersistence` 补 `delete()`；新增 `InMemoryCalibrationPersistence`；新增辅助 `makeStoredCalibration(schemaVersion:ceiling:)`。
- 删除 0 个。计数 456 + 2 = 458。

## 未变更

`factoryPlaceholder` 全部 38 项；`S2PinchMaxScaleRule`；`pinchMaxScale` 接线；`SessionPersistence`；`S2NativePhotoPager.swift`、`Core/S2StateMachine.swift`；`Scripts/`、`ci.yml`、SPEC、Decision_log；未新增 XCUITest；未合并主干。

## 占位值登记（本卡更新）

> 格式沿用 IC-074～086：项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡。

| 项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| `S2CalibrationConfiguration.schemaVersion` | **3**（④ 卡内定案；IC-086 出厂值变更对应的版本号） | effective | 非规格量；出厂值每次变更必须递增（CLAUDE.md 第六节纪律） | IC-087 |
| `s2.calibration.restore_factory` 文案 | 「【未定项 21 占位】恢复出厂值」 | effective | 未定项 21（文案）；定案后去前缀 | IC-087 |
