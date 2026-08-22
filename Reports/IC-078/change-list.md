# IC-078 变更清单

分支 `feature/ic-078-dynamic-pinch-max-scale`，自 `feature/ic-077-image-loading-states` 尖 `253212e` 切出（产品代码 = CI #125 被测 `03bd062`）。最终被测提交 `503380ceea65938aedb4502482d6f39c9b62c961`（CI #127；CI #126 被测 `01c3a20` 因 G134 测试引用了不存在的 `S2State.visibleOneX` 编译失败，产品代码未变）。**R4 未执行**（卡内冲突，见自验报告）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `aabd2e9` | R1 | `S2Calibration.swift`、`Core/S2StateMachine.swift`、`S2NativePhotoPager.swift`（仅两处过渡改引 `pinchMaxScaleFloor`）、`S2CalibrationHarnessTests.swift`、`S2StateMachineTests.swift`、`S2ImageLoadingStateTests.swift` | 删字段 `pinchMaxScale`，新增 `pinchMaxScaleFloor = 4`、`pinchMaxScaleCeiling = 10`（decided / effective）；纯函数 `S2PinchMaxScaleRule.pinchMaxScale(assetPixelSize:fitSize:displayScale:floor:ceiling:)` 与 `aspectFitSize(assetPixelSize:in:)`；`S2ResolvedParameters` 改持 floor/ceiling，校验 `floor > 1`、`ceiling ≥ floor`、`zoomSnapBackThreshold ≤ floor`，扩展 `pinchMaxScale(assetPixelSize:fitSize:displayScale:)`；状态机新增 `pinchMaxScale(for:)`（R1 阶段返回 floor）并把 5 处钳制改用该入口；导出 41 行、登记表 37 条；解码对两个新键 `decodeIfPresent` 回退出厂值（旧持久化数据中的 `pinchMaxScale` 键被忽略）；G132 新增，L7/G96/G97/G124/N1/持久化往返/状态机 `parameters` 夹具适配 |
| `2de49ce` | R2 | `Core/S2StateMachine.swift`、`S2StateMachineTests.swift` | `S2AssetZoomGeometry`（像素尺寸、`s > 1` 基准显示尺寸、屏幕倍率）；状态机非发布字典 `assetZoomGeometries`，`updateAssetZoomGeometry(_:for:)`（值不变时不写）、`assetZoomGeometry(for:)`；`pinchMaxScale(for:)` 按登记几何经 `S2ResolvedParameters.pinchMaxScale(...)` 求值，未登记取 floor；G134 新增 |
| `01c3a20` | R3 | `S2NativePhotoPager.swift`、`S2View.swift`、`S2CalibrationHarnessTests.swift` | `S2NativePageContent.zoomGeometry: S2AssetZoomGeometry?`（默认 nil）；`S2NativePagerViewController.apply` 先登记页几何再以 `machine.pinchMaxScale(for:)` 传入 `update(page:configuration:maximumZoomScale:…)`；页控制器持 `latestMaximumZoomScale`，两处 `zoomScrollView.configure` 改写该值；`S2View` 读 `@Environment(\.displayScale)`，按页传 `S2AssetZoomGeometry(assetPixelSize:fitSize: nativeZoomBaseSize, displayScale:)`；夹具 `applyNativePagerController` 增可选 `zoomGeometry` 闭包；G135 新增 |

| `503380c` | R2 修正 | `S2StateMachineTests.swift` | G134 的状态用例名改为 `S2State.visibleOneXIdle`（仅测试） |

`pbxproj` 未改（无新文件）。

## 产品行为变化

- `pinchMaxScale` 不再是固定 4：按当前资产 `s_1to1 = 像素宽 ÷ (F.width × displayScale)`（`F` = 全视口 aspectFit 显示尺寸，即 `nativeZoomBaseSize`）钳在 `[4, 10]`；像素尺寸未解析（任一维 ≤ 0）、基准尺寸为零或倍率非法时取 4。
- 双击目标、原生视口回报、捏合结果、`applyCalibration` 的钳制均按**当前资产**取值；初始呈现校验 `initialPresentation.scale ≤ pinchMaxScaleFloor`（入口时尚无资产几何，floor 为此时的当前资产值）。翻页后 `s` 仍重置为 1，上限按新资产重算。
- 原生页 `maximumZoomScale`：页面绑定资产时按该资产取值；像素尺寸未解析时为 floor，解析后随下一次 `apply` 更新一次；写入只改 `maximumZoomScale`，不触发照片几何写入（G135：四个几何量不变、写入事件 0）。
- 登记资产几何不改写当前 `s`，也不发布状态（静止态零写入，CLAUDE.md 陷阱 5）；上限只在下一次钳制时生效。
- 标定面板的参数导出（`ShareLink(item: calibration.exportText())`）：`pinchMaxScale=` 一行消失，改为 `pinchMaxScaleFloor=4`、`pinchMaxScaleCeiling=10` 两行；面板不逐项编辑参数，无新增文案键。

## 参数层

字段 36 → 37，导出 40 → 41 行，登记表 36 → 37 条；decided 21 → 23、placeholder 15 → 14。除 `pinchMaxScale → pinchMaxScaleFloor/pinchMaxScaleCeiling` 替换外，其余 35 个出厂值与 `03bd062` 逐项相等（`git diff 03bd062 HEAD -- S2Calibration.swift` 的非注释改动只含该替换、导出两行、登记表两行、编码键与解码/编码各两行及新增类型）。

## 测试

- 新增 3 个：`testIC078G132PinchMaxScaleRuleTable`（`S2CalibrationHarnessTests`）、`testIC078G134PinchMaxScaleClampsPerAssetAndRecomputesAfterPaging`（`S2StateMachineTests`）、`testIC078G135PerPageMaximumZoomScaleFollowsAssetWithoutGeometryWrites`（`S2CalibrationHarnessTests`）。
- 修改 8 个：`testL7FactoryDefaultsMatchSystemParityDecision`（期望构造改 floor/ceiling）、`testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`（37 / 41）、`testIC074G97ParameterRegistryDecidedSetMatchesV15`（37、decided 集合 +2 = 23、placeholder 14、出厂 4/10 断言）、`testIC077G124FactoryImageStrategyAndRegistry`（37 / 23 / 14）、`testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale`（`pinchMaxScaleFloor`）、标定持久化往返测试（`$0.pinchMaxScaleFloor = 5.5`、`$0.pinchMaxScaleCeiling = 12`）、`makeNativeZoomScrollView` 夹具（`pinchMaxScaleFloor`）、`S2StateMachineTests` 的 `parameters` 夹具与 IC047 捏合封顶断言（`pinchMaxScaleFloor`）。
- 删除 0 个。计数 449 + 3 = 452。

## 未变更

`debugAssetLimit`（R4 未执行，见自验报告）；图片请求策略、`S2TemporaryPhotoImageStrategy.swift`、加载态；操作条、toast、`H`、sheet；顶部信息区、徽标、标记；吸附阈值、双击目标倍率规则与锚点；捏合接管（`prepareNativeZoomGeometry`、`applyJointCentering`、`bounds.didSet` 均未动）、居中、描边、过渡动画、截图判定、Nx 贴边翻页；缓存/预取/请求尺寸；其余 35 个出厂值；S1、S3～S5、`SessionStore`、交接契约；`Scripts/`、`ci.yml`、SPEC、Decision_log；分支与 worktree；未新增 XCUITest、未新增本卡定案之外的参数。

## 占位值登记（本卡新增或变更的占位值）

> 格式沿用 IC-074～077：项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡。decided 23、placeholder 14。

| 项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| `pinchMaxScaleFloor`（新增，decided） | 4 | effective | v15 回写决策 26、第十一节第 1 部分 | IC-078 |
| `pinchMaxScaleCeiling`（新增，decided） | 10 | effective | v15 回写决策 26、第十一节第 1 部分 | IC-078 |
| `pinchMaxScale`（placeholder，删除） | — | — | 由上两项与取值规则替代 | IC-078 |
| 初始呈现校验上限 | `pinchMaxScaleFloor` | effective | 实现取定（入口时无资产几何；见自验报告） | IC-078 |
