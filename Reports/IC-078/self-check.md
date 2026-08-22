# IC-078 自验报告（dynamic-pinch-max-scale）

## 结论（先行）

R1～R3 完成，CI 两次通过（2/3）；**R4 未执行，卡内冲突，停下报告**（见下）。分支 `feature/ic-078-dynamic-pinch-max-scale` 自 `feature/ic-077-image-loading-states` 尖 `253212e`（产品代码 = CI #125 被测 `03bd062`）切出，四个代码提交（R1、R2、R3、R2 测试修正），最终被测 `503380ceea65938aedb4502482d6f39c9b62c961`。CI #127 success：XCTest **452 项、0 失败**（= 449 + 3 新增 − 0 删除），9 步全部 success（`test_status=0`，真实退出码 0），IPA 742519 字节。`pinchMaxScale` 已按当前资产像素尺寸动态取值（下限 4、上限 10、1:1 像素倍率），状态机四处钳制与初始呈现校验、原生页 `maximumZoomScale` 均按资产取值；登记几何与写入上限不触发几何写入（G135 实测写入事件 0）。参数层 36 → 37，decided 23 / placeholder 14，其余 35 个出厂值不变。闸门 A、B 均未触发。

**R4 冲突（①）**：`Scripts/selfcheck.ps1` 第 306～311 行要求产品源码中 `static let debugAssetLimit = <n>` 的定义数**恰为 1**，否则记失败；CI 的"运行结构自验"步骤执行该脚本。卡 R4 要求删除该行，同时第四节禁止修改 `Scripts/`，第七节 G137 要求本地三项门禁退出码 0、G138 要求 CI success。三者不能同时满足，按 CLAUDE.md 纪律 3/"卡内自相矛盾即停"，R4 未执行、`debugAssetLimit` 保持 `300` 未动；G136 未满足（定义仍为 1 处，引用 0 处）。需决策会话裁定：是否在本卡或后续卡显式授权同步修改 `selfcheck.ps1` 第 306～311 行（把"定义数必须为 1"改为"必须为 0"）。

**两处④实现取定，需技术负责人确认**：(a) 初始呈现校验 `initialPresentation.scale ≤ pinchMaxScaleFloor`——进入 S2 时尚无任何资产几何登记，`pinchMaxScale(for: currentAssetID)` 此时恒等于 floor，故两者等价；(b) 登记资产几何不改写当前 `s`（静止态零写入），若几何在 `s > 1` 时才到达且新上限低于当前 `s`，只在下一次钳制事件（双击、捏合、视口回报、`applyCalibration`）时生效；原生层 `configure` 的既有逻辑 `zoomScale > maximumZoomScale → setZoomScale` 会立即把滚动容器钳回（该行为为既有代码，未改）。

H28 留给 Lynn 真机判定；H24～H27 顺延。

## 输入、继承与范围

- 任务卡 IC-20260822-078；SPEC-S2 v15 回写决策 26、第十一节第 1 部分；Decision_log 第 121、122 条；IC-077 change-list 占位值登记格式。
- 开工前 `git status --porcelain` 为空；`git rev-parse origin/feature/ic-077-image-loading-states` = `253212e5c7fb1ce110876e3e746ad76d63fe77f7`，与卡一致。
- 范围边界：改动 `S2Calibration.swift`、`Core/S2StateMachine.swift`、`S2NativePhotoPager.swift`、`S2View.swift` 与三个既有测试文件；`CleanupCoordinator.swift` 未改（R4 未执行）；`pbxproj` 未改。未改图片请求策略、`S2TemporaryPhotoImageStrategy.swift`、加载态；操作条/toast/`H`/sheet；顶部信息区/徽标/标记；吸附阈值、双击目标倍率规则与锚点；捏合接管（`prepareNativeZoomGeometry`、`applyJointCentering`、`bounds.didSet` 未动）、居中、描边、过渡动画、截图判定、Nx 贴边翻页；未引入缓存/预取/请求尺寸改动；其余 35 个出厂值；S1、S3～S5、`SessionStore`、交接契约；`Scripts/`、`ci.yml`、SPEC、Decision_log；分支与 worktree；未新增 XCUITest、未新增定案之外的参数。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `aabd2e9` | R1 | 删 `pinchMaxScale`，增 `pinchMaxScaleFloor = 4`、`pinchMaxScaleCeiling = 10`（decided/effective）；`S2PinchMaxScaleRule`（纯函数 + aspectFit 辅助）；`S2ResolvedParameters` 持 floor/ceiling，校验 `floor > 1`、`ceiling ≥ floor`、`zoomSnapBackThreshold ≤ floor`；状态机 `pinchMaxScale(for:)` 入口（本阶段返回 floor）并替换 5 处钳制；导出 41 行、登记表 37；解码 `decodeIfPresent` 回退；G132 与计数适配 |
| `2de49ce` | R2 | `S2AssetZoomGeometry`；状态机非发布字典登记、`updateAssetZoomGeometry(_:for:)`、`assetZoomGeometry(for:)`；`pinchMaxScale(for:)` 按登记几何求值；G134 |
| `01c3a20` | R3 | `S2NativePageContent.zoomGeometry`；`apply` 登记几何并以 `machine.pinchMaxScale(for:)` 传入 `update(... maximumZoomScale:)`；页控制器 `latestMaximumZoomScale` 写入两处 `configure`；`S2View` 读 `displayScale` 并按页传几何；夹具 `zoomGeometry` 闭包；G135 |
| `503380c` | R2 修正 | G134 状态用例名 `.visibleOneX` → `.visibleOneXIdle`（仅测试；CI #126 编译失败） |

四个提交各自可独立 cherry-pick（R1 含对 `S2NativePhotoPager.swift` 两处过渡改引 `pinchMaxScaleFloor`，以保证该提交自身可编译；R3 再改为按页值）。

## 被删除 / 被修改的测试

- **删除：0 个**。
- **修改 8 个**：`testL7FactoryDefaultsMatchSystemParityDecision`、`testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`（37/41）、`testIC074G97ParameterRegistryDecidedSetMatchesV15`（37、decided 23、placeholder 14）、`testIC077G124FactoryImageStrategyAndRegistry`（37/23/14）、`testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale`（`pinchMaxScaleFloor`）、标定持久化往返测试（floor 5.5 / ceiling 12）、`makeNativeZoomScrollView` 夹具、`S2StateMachineTests.parameters` 夹具与 IC047 捏合封顶断言。
- **新增 3 个**（CI #127 逐一 passed）：`testIC078G132PinchMaxScaleRuleTable`、`testIC078G134PinchMaxScaleClampsPerAssetAndRecomputesAfterPaging`、`testIC078G135PerPageMaximumZoomScaleFollowsAssetWithoutGeometryWrites`。
- 计数：449 + 3 = **452**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G132 | 满足① | `testIC078G132PinchMaxScaleRuleTable`：七行断言表（1206×2622 → 4；4032×3024 → 4；3024×4032 → 4；8000×6000 → 6.63；12000×9000 → 9.95；16000×12000 → 10；0×0 → 4，±0.01）；另断言基准为零/倍率为零/ceiling < floor 取 floor；`zoomSnapBackThreshold = 4.5` 与 `ceiling = 3` 时 `resolvedParameters` 为 nil；导出不含 `pinchMaxScale=`、登记表不含 `pinchMaxScale` |
| G133 | 满足① | `git grep -n "pinchMaxScale\b" -- PhotoCleanupMVE` 排除 `pinchMaxScale(for:)`/`S2PinchMaxScaleRule`/注释后命中 0；字段、`exportText`、登记表均无单一 `pinchMaxScale`；出厂 4 / 10（G97、G132 断言）；字段 37、导出 41、登记表 37、decided 23（G96/G97/G124）；`git diff 03bd062 HEAD -- S2Calibration.swift` 的非注释改动只含该替换（字段、出厂、解析、导出、登记、编码键、解码/编码）与新增 `S2PinchMaxScaleRule`/扩展，其余 35 个出厂值未动（L7 字面值断言通过） |
| G134 | 满足① | `testIC078G134…`：asset-1（8000×6000，fit 402）上限 6.63、asset-2（1206×2622）上限 4、未登记 asset-3 取 4；双击目标 9 → 6.63；翻页到 asset-2 后双击/视口回报钳到 4；翻回 asset-1 视口回报 → 6.63、捏合放大 100 倍 → 6.63；`applyCalibration(ceiling 5)` → 上限 5、`s` 钳回 5 |
| G135 | 满足①（夹具驱动） | `testIC078G135…`：未登记几何时两页 `maximumZoomScale` 均 4；登记后 asset-2 页 = 规则值（8000 ÷ (300×3) ≈ 8.89）、asset-1 页仍 4；`contentOffset`/`contentSize`/`contentInset`/照片 frame（`presentationContentView.frame`）四项前后相等；`S2OnDeviceTransitionDiagnosticsCoordinator.photoGeometryWriteCount` 前后相等且为 0；两页 `zoomScale` 仍为 1 |
| G136 | **未满足**① | `debugAssetLimit` 定义仍 1 处（`CleanupCoordinator.swift:36`）、引用 0 处。原因见"结论"的 R4 冲突 |
| G137 | 满足① | CI #127：`testIC063…` 10、`IC064` 6、`IC065` 7、`IC067` 8、`IC069` 6、`IC070` 6、`IC074` 4、`IC075` 6、`IC076` 14、`IC077` 7 均 passed、0 failed（日志双份已折半）；本地 `selfcheck.ps1` 0、`scan-hardcoded-user-visible-strings.ps1` 0、`git diff --check` 0 |
| G138 | 满足① | CI #127（id `32575355429`）success；被测 `503380ceea65938aedb4502482d6f39c9b62c961`；`Executed 452 tests, with 0 failures (0 unexpected) in 22.788 (29.440) seconds`；`test_status=0`，9 步 success；IPA `PhotoCleanupMVE-unsigned.ipa` 742519 字节，SHA-256 `f8845e4a60d52b47d172c8e6f4c45d3e148075d55b70d7ebcfa912269fc408db`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-503380ceea65` 经 `gh run download` 本地 `sha256sum` 一致；被删测试 0 个。CI #126（`01c3a20`）failure：XCTest 步骤编译错误 `S2StateMachineTests.swift:608 type 'S2State' has no member 'visibleOneX'`（仅测试文件，产品代码与 #127 相同的 R1～R3 提交） |
| 闸门 A | 未触发① | `prepareNativeZoomGeometry`、`applyJointCentering`、`bounds.didSet`、捏合接管路径均未改；`git diff 03bd062 HEAD -- S2NativePhotoPager.swift` 只含 `zoomGeometry` 字段、`apply` 登记与传参、`update` 签名与 `latestMaximumZoomScale`、两处 `configure` 的 `maximumZoomScale:` 实参 |
| 闸门 B | 未触发① | IC-063～IC-070 的 G1～G79 在 CI #127 全部通过 |
| H28 | 保留给 Lynn | — |

## 定案落实与取定值

- 规则：`S2PinchMaxScaleRule.pinchMaxScale(assetPixelSize:fitSize:displayScale:floor:ceiling:)`，`F` 取 `nativeZoomBaseSize`（截图为全视口、照片为全视口 aspectFit），`displayScale` 取 SwiftUI `@Environment(\.displayScale)`。
- 状态机：`S2AssetZoomGeometry` 按资产登记（非 `@Published`，值不变不写）；`pinchMaxScale(for:)`；5 处钳制（双击、视口回报、捏合、`applyCalibration`、初始呈现校验）。
- 原生页：`apply` 先登记页几何再求值传入；`latestMaximumZoomScale` 写入两处 `configure`；像素尺寸未解析 → floor，解析后随下一次 `apply` 更新。
- 参数：`pinchMaxScaleFloor = 4`、`pinchMaxScaleCeiling = 10`，decided/effective；旧持久化数据的 `pinchMaxScale` 键被忽略、两新键缺省回落出厂值。

## 报告提交方式

拿到 CI #127 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-078/`，不触发 CI）。

## 发现但未处理

1. R4 与 `Scripts/selfcheck.ps1` 冲突（见结论），`debugAssetLimit` 未删。此外 `Scripts/verify-IC-20260814-048.ps1`、`verify-IC-20260815-051/054/055/056/058/059/060/061.ps1`、`verify-IC-20260816-063.ps1` 各含"`debugAssetLimit` 被改动"检查（历史单卡脚本，CI 不执行），删除后亦会失败。
2. CI 日志 zip 下载在本次出现 3 次 `results-receiver.actions.githubusercontent.com` EOF，第 4 次成功；与 IC-077 报告中的 `api.github.com` EOF 同属本机代理路径的瞬断。
3. `exportText()` 的 `taskID` 仍为 IC-074；`S2UndecidedItems` 中与缩放上限相关的占位常量本卡未清理（卡未要求）。
4. 两处④取定见"结论"。
