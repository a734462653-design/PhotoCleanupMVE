# IC-081 自验报告（pinch-max-multiplier）

## 结论（先行）

R1、R2 完成，CI 第三次通过（3/3，用尽上限）。分支 `feature/ic-081-pinch-max-multiplier` 自 `main` = `origin/main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出，四个提交（R1、R2、两个测试修正），最终被测 `d71e0381a24fbebe926379ae965e1283f6d09a53`。CI #134 success：XCTest **456 项、0 失败**（= 455 + 1 新增 − 0 删除），9 步 success（`test_status=0`），IPA 753945 字节。规则改为 `min(ceiling, max(floor, multiplier × s_1to1))`；新参数 `pinchMaxScaleOneToOneMultiplier` 出厂 2.0、placeholder/effective；面板滑杆 1.0…4.0、步进 0.1，调节后经既有 `applyCalibration → apply` 链路即时重写各页 `maximumZoomScale`，零几何写入。floor/ceiling 未动。闸门 A、B 未触发。

两次 CI 失败均为测试自身问题，产品代码在 R1/R2 后未再改动：#132 G149 误用 `private` 的 `hostingController`（编译失败）；#133 G134 的双击目标 9 低于新上限 10 被原样保留而非钳到 10（两条断言）。

H30 标定留给 Lynn。

## 输入、继承与范围

- 任务卡 IC-20260822-081；Decision_log 第 122、123 条；IC-078 报告。
- 开工前 `git status --porcelain` 为空；`git rev-parse main origin/main` 均为 `072d82c…`，一致。
- 范围边界：改动 `S2Calibration.swift`、`Core/S2StateMachine.swift`（仅 `S2ResolvedParameters` 字段与校验）、`S2View.swift`（仅面板一行滑杆）与三个测试文件。未改 floor/ceiling 与其他任何出厂值；未改 Nx 贴边翻页、横栏、图片请求、操作条、标记；未改捏合接管/居中（闸门 A）；未新增 XCUITest；未改 SPEC、Decision_log、`Scripts/`、`ci.yml`；未合并主干。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `e03dbbf` | R1 | 规则乘数；参数字段/出厂/导出/登记/编码；`S2ResolvedParameters` 增字段（默认 2）并校验 `> 0`；G132 表重算与两条边界；计数 38/42/38、placeholder 15；G134/G135/L7/G96/G97/G124/持久化/接线测试适配；G149 测试（为避免拆分同一文件，随 R1 入库） |
| `8672dbf` | R2 | 面板滑杆一行 |
| `cacc1b6` | 测试修正 | G149 照片 frame 访问器 |
| `d71e038` | 测试修正 | G134 目标倍率 9 → 12 |

## 被删除 / 被修改的测试

- 删除 0 个。新增 1 个：`testIC081G149MultiplierChangeUpdatesMaximumZoomScaleWithoutGeometryWrites`。
- 修改 10 个（列于变更清单）。计数 455 + 1 = **456**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G148 | 满足① | `testIC078G132PinchMaxScaleRuleTable`（CI #134 passed）：1206×2622 → 4、4032×3024 → 6.69、3024×4032 → 5.01、8000×6000 → 10、12000×9000 → 10、0×0 → 4（±0.01；另保留 16000×12000 → 10），`S2ResolvedParameters.pinchMaxScale(…)` 与纯函数逐行相等；乘数 1 还原 8000/1206 ≈ 6.63、乘数 0 取 floor；`factoryPlaceholder.pinchMaxScaleOneToOneMultiplier == 2`、登记 placeholder（`testIC074G97…`）/effective（接线状态测试）；`fieldNames.count == 38`、导出 42 行（`testIC074G96…`）、登记表 38、decided 23、placeholder 15（`testIC074G97…`、`testIC077G124…`）；导出含 `pinchMaxScaleOneToOneMultiplier=2` |
| G149 | 满足①（夹具驱动，真机未覆盖） | `testIC081G149…`：4032×3024 页在乘数 2 下 `maximumZoomScale` = 规则值（8.96）、相邻小图页 4；`applyCalibration(乘数 1)` + 重新 `apply` 后当前页 4.48、`machine.pinchMaxScale(for:)` 同值、相邻页仍 4；乘数 3 后按新值（钳 10）；两页 `contentOffset`/`contentSize`/`contentInset`/照片 frame 快照前后相等；`photoGeometryWriteCount` 增量 0 且总数 0；`zoomScale`、`machine.scale` 均为 1 |
| G150 | 满足① | CI #134 所有 `testIC0…` 0 失败；本地 `selfcheck.ps1` 0、`scan-hardcoded-user-visible-strings.ps1` 0、`git diff --check` 0 |
| G151 | 满足① | CI #134（id `32583128962`）success，9 步 success；被测 `d71e0381a24fbebe926379ae965e1283f6d09a53`；`Executed 456 tests, with 0 failures (0 unexpected) in 59.289 (76.755) seconds`；`test_status=0`；IPA `PhotoCleanupMVE-unsigned.ipa` 753945 字节，SHA-256 `49e088cf1f48b0227ad039ee1ef63b17076303c88c282d393b2f1c08bbe29035`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-d71e0381a24f` 本地 `sha256sum` 一致；被删测试 0。#132（`8672dbf`）编译失败；#133（`cacc1b6`）456 项 2 失败（G134 两条） |
| 闸门 A | 未触发① | `git diff main HEAD -- S2NativePhotoPager.swift` 为空；即时生效走既有 `apply → update(maximumZoomScale:)` |
| 闸门 B | 未触发① | IC-063～IC-079 既有门禁在 #134 全过 |
| H30 | 保留给 Lynn | 滑杆在面板 `minDoubleTapScale` 之后，标题 `pinchMaxScaleOneToOneMultiplier` |

## 定案落实与取定值

- 规则：`S2PinchMaxScaleRule.pinchMaxScale(assetPixelSize:fitSize:displayScale:floor:ceiling:multiplier:)`；`multiplier ≤ 0` 与既有无效输入一样取 floor（④ 实现取定，面板范围 1…4 不会触及）。
- 参数：`pinchMaxScaleOneToOneMultiplier = 2.0`（④ 技术负责人取定）；旧持久化数据缺该键时解码为 2。
- `S2ResolvedParameters.init` 的该参数带默认值 2（便于既有测试构造），校验 `> 0`。

## 报告提交方式

拿到 CI #134 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-081/`，不触发 CI）。

## 发现但未处理

1. 三次 CI 用尽：两次均为测试编写错误（私有成员访问、目标倍率低于新上限），非产品问题。
2. 标定面板滑杆标题沿用参数名英文（与既有各滑杆一致），无本地化键。
3. `pinchMaxScale(for:)` 的初始呈现校验仍用 floor（IC-078 已报告），乘数不影响。
