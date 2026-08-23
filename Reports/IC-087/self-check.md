# IC-087 自验报告（calibration-schema-migration）

## 结论（先行）

R1、R2、R3 完成，CI 一次通过（1/3）。分支 `feature/ic-087-calibration-schema-migration` 自 `feature/ic-086-pinch-max-retune` 尖 `43500bf` 切出，两个提交（R1、R2），最终被测 `43c5f4d53d3a565268df65cdd317cf5e532636df`。CI #147 success：XCTest **458 项、0 失败**（= 456 + 2 新增 − 0 删除），9 步 success（`test_status=0`），IPA 755957 字节，SHA-256 本地复核一致。

`S2CalibrationConfiguration.schemaVersion` 2 → **3** 并写入持久化顶层；加载时存储版本（缺失视为 0）≠ 代码版本 → 整套丢弃、取出厂值、**删除** Keychain 条目（`SecItemDelete`，不是覆盖）；相等 → 现行逐字段解码。面板「恢复出厂值」按钮：重置为出厂、删除条目、经既有 `onChange(of: calibration.configuration) → applyCalibration → apply` 即时生效，静止态零几何写入。`<top>/CLAUDE.md` 第六节末追加一行（`grep -c schemaVersion` = 1）。出厂值、规则函数、`pinchMaxScale` 接线、`SessionPersistence` 一个未动。闸门 A 未触发（夹具层面；真机 Keychain 删除留 H35）。

**卡内前提与源码的一处出入**：面板**已有**「恢复出厂值」按钮（键 `s2.calibration.restore_factory`，原文案"恢复项目判断默认值"，IC-074 前即存在，行为是覆盖写入出厂值）。卡写"新增按钮"。按结果理解：不做第二个按钮，把既有按钮改造为卡规格（删除条目 + 占位前缀文案），键沿用、值更新。见"发现但未处理"第 1 条。

H35 标定留给 Lynn。

## 输入、继承与范围

- 任务卡 IC-20260823-087；Lynn 2026-08-23 真机（装 CI #144 包并删 App 重装后 `当前 s` 仍止于 10，①）；技术负责人源码核查（Keychain 条目不随卸载清除、`decodeIfPresent ?? 出厂值` 让旧值永久覆盖）——本卡实测印证：`S2KeychainCalibrationPersistence` 只有 `load/save`，`S2CalibrationModel.init` 对任何可解码数据直接采用（①，改造前源码）。
- 开工前 `git status --porcelain` 为空；HEAD 在 `feature/ic-085-bottom-strip-parity`@`510b324`（另一会话已交付），按下发语从 `43500bf` 切分支。
- 范围边界：改动 `S2Calibration.swift`（版本常量、CodingKeys、`init(from:)`、`encode`、协议 `delete()`、Keychain/Discarding 实现、错误枚举、`S2CalibrationModel.init` 与 `restoreFactoryPlaceholder()`）、`S2View.swift`（按钮处两行注释）、`Localizable.xcstrings`（一个值）、一个测试文件、`<top>/CLAUDE.md` 一行。未改任何出厂值（`factoryPlaceholder` 无 diff）、规则函数、`pinchMaxScale` 接线、`SessionPersistence`；未新增 XCUITest；未改 SPEC、Decision_log、`Scripts/`、`ci.yml`；未合并主干。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `c790b7e` | R1 | `schemaVersion = 3`；`CodingKeys.schemaVersion`；`encode` 写顶层 `schemaVersion`；`init(from:)` 先读版本（缺失 0），不等抛 `S2CalibrationPersistenceError.schemaVersionMismatch(stored:expected:)`；协议 `delete()`；Keychain `SecItemDelete`（`errSecItemNotFound` 视为成功）；Discarding 空操作；`S2CalibrationModel.init` 捕获不匹配 → 出厂 + `delete()`（删除失败置 `persistenceFailed`）；`restoreFactoryPlaceholder()` 改为 `delete()`。测试：G96 `schemaVersion=3`、UserDefaults 假存储补 `delete()`、新增 G171 与 `InMemoryCalibrationPersistence` |
| `43c5f4d` | R2 | `s2.calibration.restore_factory` 值 → 「【未定项 21 占位】恢复出厂值」；`S2View` 按钮处注释；新增 G172 |
| （无） | R3 | `<top>/CLAUDE.md` 第六节末追加一行，不产生仓库提交 |

## 被删除 / 被修改的测试

- 删除 0 个。新增 2 个：`testIC087G171SchemaVersionGateDiscardsStaleStoreAndDeletesEntry`、`testIC087G172RestoreFactoryResetsDeletesStoreAndAppliesToCurrentPage`。
- 修改 1 个：`testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`（`schemaVersion` 2 → 3）。另：测试私有假存储 `UserDefaultsCalibrationPersistence` 补协议方法 `delete()`；新增私有假存储 `InMemoryCalibrationPersistence`（记录保存/删除次数、可注入删除错误）。计数 456 + 2 = **458**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G171 | 满足① | `testIC087G171…`（CI #147 passed）：`schemaVersion == 3`；出厂导出含 `schemaVersion=3`（G96 亦断言）；假存储 `schemaVersion=2 & ceiling=10` → 配置 == 出厂、ceiling 40、`data == nil`、`deleteCount 1`、`saveCount 0`、`persistenceFailed false`；`schemaVersion=3 & ceiling=12` → 12、存储保留、`deleteCount 0`；无 `schemaVersion` 字段 → 出厂、存储删除。附加：保存后 JSON 顶层 `schemaVersion == 3` 且重载得同一配置；删除失败 → 配置仍出厂、`persistenceFailed true` |
| G172 | 满足①（夹具驱动，真机未覆盖） | `testIC087G172…`：`L10n.text("s2.calibration.restore_factory").hasPrefix("【未定项 21 占位】")`；假存储 ceiling 12（版本 3）生效后当前页（4032×3024，视口 300×600）`maximumZoomScale == 12`；`restoreFactoryPlaceholder()` 后配置 == 出厂、`data == nil`、`deleteCount 1`、`saveCount 0`；`applyCalibration` + 重新 `apply` 后 `maximumZoomScale` == 出厂规则值（6 × 4032/900 ≈ 26.88，> 12）、`machine.pinchMaxScale(for:)` 同值；`contentOffset`/`contentSize`/`contentInset`/照片 frame 快照前后相等；`photoGeometryWriteCount` 增量 0 且总数 0；`zoomScale`、`machine.scale` 均为 1 |
| G173 | 满足① | CI #147 所有 `testIC0…` 0 失败（IC-063～IC-086 既有门禁全过）；本地 `selfcheck.ps1` 退出码 0、`scan-hardcoded-user-visible-strings.ps1` 退出码 0（目录 170 / 引用 170、残留 0）、`git diff --check` 退出码 0；`grep -c "schemaVersion" <top>/CLAUDE.md` = 1 |
| G174 | 满足① | CI #147（id `32631224788`）success，9 步 success；被测 `43c5f4d53d3a565268df65cdd317cf5e532636df`；`Executed 458 tests, with 0 failures (0 unexpected) in 28.208 (39.910) seconds`；`test_status=0`，工作流以 `exit "$test_status"` 原样退出；IPA `PhotoCleanupMVE-unsigned.ipa` 755957 字节，SHA-256 `01bc75db249ecfb98bec266e59bde72f8a18673d24d0cc28d91451a95242280a`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-43c5f4d53d3a` 本地 `sha256sum` 一致 |
| 闸门 A | 未触发（夹具层面①；真机③） | 生产实现 `SecItemDelete(baseQuery)`，`errSecSuccess`/`errSecItemNotFound` 视为成功，其余状态抛错并由模型置 `persistenceFailed`（面板显示既有"持久化失败"文案）。本机无 Xcode、CI 模拟器测试走假存储，**真机 Keychain 删除是否返回错误未覆盖**，由 H35 兜底：若装包后 `当前 s` 仍止于 10 或面板出现持久化失败提示，即闸门 A 触发 |
| H35 | 保留给 Lynn | 不删 App 直接装 CI #147 包；预期首次进 S2 时旧条目（版本 2 或无版本）被删除、取出厂 6.0/40，4672×7008 捏到最大 ≈ 23.2；面板末尾按钮文案「【未定项 21 占位】恢复出厂值」；随后按 H34 对比记录滑杆值 |

## 定案落实与取定值

- `schemaVersion = 3`（④ 卡内定案）。存储缺该字段视为 0（④ 卡内定案）。
- 版本门控在 `init(from:)` 内以抛错实现，由 `S2CalibrationModel.init` 区分"版本不匹配 → 删除"与"其他解码失败 → 仅回退出厂、不删除"（④ 实现取定：损坏数据不自动删除，保持 IC-074 前行为）。
- 删除失败不回退为覆盖写入（闸门 A 要求），只置 `persistenceFailed`。
- 恢复出厂值后 `persistenceFailed` 随删除结果刷新（成功清零）。

## 报告提交方式

拿到 CI #147 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-087/`，不触发 CI）。

## 发现但未处理

1. **卡前提出入**：面板原本就有「恢复出厂值」按钮（`S2View.swift` 标定面板末尾，`restoreFactoryPlaceholder()`，文案"恢复项目判断默认值"，无占位前缀）。本卡沿用键 `s2.calibration.restore_factory` 改值与行为，未新增第二个按钮；是否需要独立新键由技术负责人定。
2. **升级路径只覆盖"版本不等"**：同版本内若未来新增字段，仍走 `decodeIfPresent ?? 出厂值`；同版本内改出厂值不会失效——这正是 CLAUDE.md 新增纪律要拦的情形。
3. 旧条目被删除的时机是 `S2CalibrationModel.init`（`CleanupCoordinator` 构造时），不是进 S2 时；若真机上 App 未冷启动（仅前台切换）不会触发，H35 请确保冷启动。
4. `S2ActionBarWiringTests` 与其他测试构造 `S2CalibrationModel(persistence: S2DiscardingCalibrationPersistence())`，不受版本门控影响（`load()` 返回 nil）。
5. 推送第一次因本机 TLS 握手失败（`schannel`），重试即过，与产物无关。
