# IC-086 自验报告（pinch-max-retune）

## 结论（先行）

R1 完成，CI 第二次通过（2/3）。分支 `feature/ic-086-pinch-max-retune` 自 `feature/ic-081-pinch-max-multiplier` 尖 `a294254`（= CI #134 被测 `d71e038` + IC-081 docs 提交）切出，两个提交（R1、一个测试适配），最终被测 `d156d955232a040ee857d03325c0a19e7b9bcf55`。CI #144 success：XCTest **456 项、0 失败**（新增 0、删除 0，与 IC-081 一致），9 步 success（`test_status=0`），IPA 753904 字节，SHA-256 本地复核一致。

出厂值 `pinchMaxScaleOneToOneMultiplier` 2.0 → **6.0**、`pinchMaxScaleCeiling` 10 → **40**，`pinchMaxScaleFloor` 保持 4；面板滑杆 1.0…4.0 → **2.0…10.0**，步进 0.1 不变。规则函数、登记状态（乘数 placeholder、floor/ceiling decided，均 effective）、其余 36 个出厂值与 `d71e038` 逐项相等（①，`git diff d71e038 HEAD -- PhotoCleanupMVE/` 仅 4 处产品行）。闸门 A、B 未触发。

CI #143 的 2 项失败均为测试自身未同步新出厂值（G97 出厂值断言、`S2StateMachineTests.parameters` 夹具仍为 10/2），产品代码在 R1 后未再改动。

H34 标定留给 Lynn。

## 开工前异常（已按纪律处理）

首次开工时 `git status --porcelain` 为空，我从 `a294254` 创建分支后，HEAD 在下一条命令前被另一会话切到 `feature/ic-085-bottom-strip-parity`（reflog 可证）。按 CLAUDE.md 二-8 停下报告，未改任何文件。Lynn 确认 IC-085 已交付、工作树空闲后，重新 `git checkout feature/ic-086-pinch-max-retune`（仍在 `a294254`，未重建）继续。

## 输入、继承与范围

- 任务卡 IC-20260823-086；IC-081 报告（CI #134）；Lynn 2026-08-23 真机 H30 读数（`s = 10.000`、`maximumZoomScale = 10`，撞天花板）；技术负责人截图比对（③）。
- 继承提交 `a294254`；`feature/ic-081-pinch-max-multiplier` 与 `feature/ic-086-pinch-max-retune` 起点一致（`git rev-parse` 均为 `a294254`）。
- 范围边界：改动 `S2Calibration.swift`（`factoryPlaceholder` 两行 + 旧版持久化解码回退两处）、`S2View.swift`（滑杆一行 + 注释）与两个测试文件。未改规则函数 `S2PinchMaxScaleRule`、floor、图片请求策略、捏合接管、居中、任何其他参数；未新增 XCUITest；未改 SPEC、Decision_log、`Scripts/`、`ci.yml`；未合并主干。
- `S2ResolvedParameters.init` 的乘数默认参数值（`= 2`，IC-081 为便于测试构造而加）**未动**：它不是 `factoryPlaceholder`，产品侧唯一调用方 `S2CalibrationConfiguration.resolvedParameters` 总是显式传值，故不影响行为。列入"发现但未处理"。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `49c413e` | R1 | 出厂值 6.0 / 40（含解码回退 6 / 40）；滑杆 2…10；L7、G132/G148 断言表（七行）、导出字符串、G134、G135、G149 按新值适配 |
| `d156d95` | R1 测试适配 | G97 出厂值断言 2 / 10 → 6 / 40；`S2StateMachineTests.parameters` 夹具 ceiling/乘数 10 / 2 → 40 / 6（CI #143 两项失败） |

## 被删除 / 被修改的测试

- 删除 0 个，新增 0 个。计数 456，与 CI 一致。
- 修改 7 个（列于变更清单）：`testL7FactoryDefaultsMatchSystemParityDecision`、`testIC078G132PinchMaxScaleRuleTable`、`testIC078G134PinchMaxScaleClampsPerAssetAndRecomputesAfterPaging`、`testIC078G135PerPageMaximumZoomScaleFollowsAssetWithoutGeometryWrites`、`testIC081G149MultiplierChangeUpdatesMaximumZoomScaleWithoutGeometryWrites`、`testIC074G97ParameterRegistryDecidedSetMatchesV15`，以及 `S2StateMachineTests` 的私有 `parameters` 夹具。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G167 | 满足① | `factoryPlaceholder.pinchMaxScaleOneToOneMultiplier == 6`、`pinchMaxScaleCeiling == 40`、`pinchMaxScaleFloor == 4`（`testIC074G97…` 三条断言、`testIC078G132…` 三条断言、`testL7…` 全量出厂配置相等，CI #144 passed）；`git diff d71e038 HEAD -- PhotoCleanupMVE/` 仅含 `factoryPlaceholder` 两行、解码回退两行、滑杆 `range` 一行与一行注释 |
| G168 | 满足① | `testIC078G132PinchMaxScaleRuleTable`（视口 402×874、@3x、乘数 6、天花板 40，±0.01）：1206×2622 → 6、4032×3024 → 20.06、3024×4032 → 15.04、4672×7008 → 23.24、8000×6000 → 39.80、12000×9000 → 40、0×0 → 4。卡内表为一位小数（6.0 / 20.1 / 15.0 / 23.2 / 39.8 / 40 / 4），测试断言精度 0.01，故按规则函数精确到两位；两位值四舍五入后与卡内七行逐行一致。`S2ResolvedParameters.pinchMaxScale(…)` 与纯函数逐行相等；乘数 1 / 0 两条边界与 ceiling < floor 边界保留 |
| G169 | 满足① | CI #144 所有 `testIC0…` 0 失败（IC-063～IC-081 既有门禁全过）；本地 `selfcheck.ps1` 退出码 0、`scan-hardcoded-user-visible-strings.ps1` 退出码 0（硬编码残留 0）、`git diff --check` 退出码 0 |
| G170 | 满足① | CI #144（id `32622802357`）success，9 步 success；被测 `d156d955232a040ee857d03325c0a19e7b9bcf55`；`Executed 456 tests, with 0 failures (0 unexpected) in 17.727 (27.253) seconds`；`test_status=0`，工作流以 `exit "$test_status"` 原样退出；IPA `PhotoCleanupMVE-unsigned.ipa` 753904 字节，SHA-256 `eea8c4e6f62f19279c04ae39e012261e6d125f87e9ac48ae4df04c872c8536f1`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-d156d955232a` 本地 `sha256sum` 一致。#143（`49c413e`，id `32622424165`）failure：456 项 2 失败（G97、G134），见下 |
| 闸门 A | 未触发① | 天花板提到 40 后，G134（大倍率 39.80 钳制、翻页重算、ceiling 降 5 钳回）、G135、G149、捏合接管 / 居中相关既有门禁在 #144 全过；`S2NativePhotoPager.swift`、`Core/S2StateMachine.swift` 未改 |
| 闸门 B | 未触发① | IC-077 请求策略相关门禁（`S2ImageLoadingStateTests` 等）在 #144 全过；请求策略代码未改 |
| H34 | 保留给 Lynn | 滑杆仍在面板 `minDoubleTapScale` 之后，标题 `pinchMaxScaleOneToOneMultiplier`，范围 2…10。出厂 6.0 下 12MP 横拍上限 ≈ 20、截图 6；若 6.0 已与系统一致则定案 6.0。最高倍率平移卡顿 / 白块需真机观察 |

## CI #143 失败归因（①）

- `testIC074G97…` :829 / :837：断言 `factoryPlaceholder` 乘数 == 2、天花板 == 10。R1 漏改这条登记表测试。
- `testIC078G134…` 六条：`makeMachine` 使用 `S2StateMachineTests` 私有 `parameters` 夹具（IC-081 写死 ceiling 10、乘数 2），不是 `factoryPlaceholder`，故机器仍按旧值钳制（实测 asset-1 = 10、asset-2 = 4）。夹具同步为 40 / 6 后通过；该夹具在本文件内只被 G134 的登记几何路径用到上限值，其余测试不受影响（#144 0 失败）。

## 定案落实与取定值

- `pinchMaxScaleOneToOneMultiplier = 6.0`（④ 技术负责人取定，仍 placeholder，待 H34 定案）；旧持久化数据缺该键时解码为 6。
- `pinchMaxScaleCeiling = 40`（④ 防御值，decided）；旧持久化缺键解码为 40。
- 面板滑杆 `2.0…10.0`、步进 `0.1`（④ 卡内定案）。

## 报告提交方式

拿到 CI #144 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-086/`，不触发 CI）。

## 发现但未处理

1. `S2ResolvedParameters.init(pinchMaxScaleOneToOneMultiplier: CGFloat = 2)` 的默认参数值仍为 2（IC-081 引入）。产品侧不经此默认值，行为无影响；是否随出厂值同步属技术负责人决定。
2. **真机标定前置条件（③）**：IC-081 的 `encode` 已把乘数与天花板写入持久化，若 Lynn 真机上已有 IC-081 保存的标定配置（含 `pinchMaxScaleCeiling=10`、乘数 2），安装新包后**读到的仍是持久化旧值而非新出厂值**，H34 需先复位标定或手动把滑杆拖到 6.0 / 确认天花板为 40（面板读数 `maximumZoomScale` 可核）。本卡未改持久化迁移逻辑（范围外）。
3. 卡内断言表为一位小数、测试精度 0.01，本卡按规则函数取两位值；若技术负责人希望表值本身落为一位小数需改断言精度（未动）。
4. 面板滑杆下限提到 2.0 后，IC-081 G149 仍通过 `applyCalibration` 直接设乘数 1（绕过面板范围）验证 1:1 还原，属夹具驱动，与面板可达范围不一致但不影响产品。
