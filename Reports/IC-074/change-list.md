# IC-074 变更清单

分支 `feature/ic-074-parameter-layer`，自 `main`（`8acf43d`）切出。最终被测提交 `7a8a8fa75ecf6122d897a34c955e4960dd05a3bf`（CI #121，422 项 0 失败）。

## 提交

| SHA | 类型 | 文件 | 说明 |
|---|---|---|---|
| `9cbe77a` | R2 refactor | `Core/S2StateMachine.swift`、`Features/S2/S2NativePhotoPager.swift`、`Features/S2/S2Calibration.swift`（仅 `resolvedParameters` 映射）、`S2StateMachineTests.swift` | `S2ResolvedParameters` 去掉 4 项；`completeMainDrag` 1x 水平分支 → `return false`（唯一有意行为变化）；`finishNativePinch` 去掉捏合速度/时长过滤与 `durationIsAllowed`；新增 2 个正反断言测试 |
| `7a8a8fa` | R1 refactor | `Features/S2/S2Calibration.swift`、`Features/S2/S2View.swift`、`Features/S2/S2NativePhotoPager.swift`（注释措辞）、`Localizable.xcstrings`、`S2CalibrationHarnessTests.swift` | 删除 15 字段、2 枚举、`insetApplies(scope:)`；登记表双维度 33 条；`schemaVersion=2`、`taskID`、`specBaseline`；面板删 2 控件、登记列表两列；本地化 −2/+2 键；测试 −2/+2 并迁移 |

## 删除的参数（15）

`fitInsetScope`、`screenshotImmersiveOnHide`、`verticalSwipeMaximumDurationMilliseconds`、`horizontalSwipeDistance`、`horizontalSwipeVelocity`、`horizontalSwipeMaximumDurationMilliseconds`、`pinchMinimumScaleDelta`、`pinchMinimumVelocityPerSecond`、`pinchMaximumDurationMilliseconds`、`mainDragMinimumDistance`、`mainDragMinimumVelocity`、`mainDragMaximumDurationMilliseconds`、`singleTapMaximumMovement`、`singleTapMaximumDurationMilliseconds`、`gestureExclusivityPolicy`。附属一并删除：`S2FitInsetScope`、`S2GestureExclusivityPolicy`、`S2ViewportLayout.insetApplies(scope:)`、面板 Picker/Toggle/`fitInsetScopeTitle`、本地化键 `s2.calibration.option.fit_scope.all_photos` / `.screen_aspect`。

## 行为变化（仅一处，④ Lynn 接受）

1x 下竖向起手、中途转横向并以 ≥40pt、≥100pt/s 松手的主图拖动，此前由状态机 `switchPhoto` 无动画切页；现在 `completeMainDrag` 返回 `false`，不切页（1x 左右滑只由外层原生分页承担）。其余路径——Nx 贴边翻页阈值、竖向上滑/下滑、捏合结束归位——行为不变（捏合过滤因出厂值 0 恒通过）。

## 登记表（33 条，specStatus × wiringStatus）

decided / effective：`zoomSnapBackThreshold`、`minDoubleTapScale`、`edgePagingTriggerDistance`、`edgePagingTriggerVelocity`、`verticalSwipeDistance`、`verticalSwipeVelocity`、`presentationToggleDuration`、`presentationToggleDamping`、`fitInsetRatio`、`fitCornerRadius`、`fitBorderWidth`、`fitBorderDarkAlpha`、`fitBorderLightAlpha`、`pageSpacing`、`hapticOnPhotoSwitch`（15）
decided / unwired：`doubleTapDecisionWindowMilliseconds`（仅诊断目标，不控制识别器）（1）
placeholder / effective：`pinchMaxScale`、`doubleTapAnchorStrategy`、`singleTapTouchCount`、`doubleTapTouchCount`、`singleDragTouchCount`、`pinchTouchCount`、`scaleChangeRequestPolicy`、`degradedPreviewPolicy`、`animationsEnabled`、`animationDurationMilliseconds`、`bottomStripCurrentItemSize`、`bottomStripNeighborItemWidth`、`bottomStripNeighborItemHeight`、`bottomStripItemSpacing`、`bottomStripDragMinimumDistance`、`bottomStripSwitchDistance`（16）
placeholder / unwired：`bottomStripEdgeFadeWidth`（生产视图未使用）（1）

## 导出文本

头部 4 行：`schemaVersion=2`、`taskID=IC-20260821-074-parameter-layer-v15-alignment`、`valueStatus=…`、`specBaseline=SPEC-S2-20260821_v15`；随后 33 个字段行。

## 出厂值对照（G98，33 项，`8acf43d` = HEAD，逐项从代码读取）

| 参数 | 出厂值 | 参数 | 出厂值 |
|---|---|---|---|
| pinchMaxScale | 4 | presentationToggleDamping | 0.86 |
| zoomSnapBackThreshold | 1.1 | fitInsetRatio | 0.30 |
| minDoubleTapScale | 2 | fitCornerRadius | 28 |
| doubleTapAnchorStrategy | .touchPoint | fitBorderWidth | 1 |
| edgePagingTriggerDistance | 40 | fitBorderDarkAlpha | 0.09 |
| edgePagingTriggerVelocity | 300 | fitBorderLightAlpha | 0.055 |
| verticalSwipeDistance | 40 | pageSpacing | 20 |
| verticalSwipeVelocity | 100 | hapticOnPhotoSwitch | true |
| doubleTapDecisionWindowMilliseconds | 200 | bottomStripCurrentItemSize | 72 |
| singleTapTouchCount | 1 | bottomStripNeighborItemWidth | 52 |
| doubleTapTouchCount | 1 | bottomStripNeighborItemHeight | 44 |
| singleDragTouchCount | 1 | bottomStripItemSpacing | 8 |
| pinchTouchCount | 2 | bottomStripEdgeFadeWidth | 24 |
| scaleChangeRequestPolicy | .pinchEnded | bottomStripDragMinimumDistance | 4 |
| degradedPreviewPolicy | .finalImageOnly | bottomStripSwitchDistance | 44 |
| animationsEnabled | true | presentationToggleDuration | 220 |
| animationDurationMilliseconds | 180 | | |

## 未变更

保留参数出厂值；`handleHorizontalSwipe`、`finishNXEdgePaging`；手势分层、居中、描边、过渡动画、截图判定、图片请求策略、`S2TemporaryPhotoImageStrategy.swift`；顶部信息区/操作条/横栏/角标；`debugAssetLimit`；`Scripts/`、`ci.yml`、历史报告、`selfcheck_IC-0xx_report.md`；SPEC、Decision_log、S1、S3～S5；分支与 worktree。

## 仓库外改动

`<top>/CLAUDE.md` 第七节规格基线一行改为 v15（SHA-256 `0051DF90…C9546E`），其余未动。

## 占位值登记（R1 后 specStatus = placeholder 的全部参数，逐项从 `factoryPlaceholder` 读取）

> 本节格式作为后续各卡「本卡新增或变更的占位值」的模板：参数名 | 当前出厂值 | 接线状态 | v15 对应条款/去向 | 登记来源卡。

| 参数 | 当前出厂值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| `pinchMaxScale` | 4 | effective | v15 定义为动态取值，固定值 4 为占位；实装留待后续卡 | IC-074 |
| `doubleTapAnchorStrategy` | `.touchPoint` | effective | 锚点策略未定案 | IC-074 |
| `singleTapTouchCount` | 1 | effective | 触点数由系统识别器决定，是否保留待定 | IC-074 |
| `doubleTapTouchCount` | 1 | effective | 同上 | IC-074 |
| `singleDragTouchCount` | 1 | effective | 同上 | IC-074 |
| `pinchTouchCount` | 2 | effective | 同上（`beginNativePinch` 要求 == 2） | IC-074 |
| `scaleChangeRequestPolicy` | `.pinchEnded` | effective | 未定项 8（高分辨率请求触发条件） | IC-074 |
| `degradedPreviewPolicy` | `.finalImageOnly` | effective | 未定项 8（降质预览） | IC-074 |
| `animationsEnabled` | true | effective | 全局动画开关未定案 | IC-074 |
| `animationDurationMilliseconds` | 180 | effective | 通用动画时长未定案 | IC-074 |
| `bottomStripCurrentItemSize` | 72 | effective | 第六节系统对齐项（横栏） | IC-074 |
| `bottomStripNeighborItemWidth` | 52 | effective | 同上 | IC-074 |
| `bottomStripNeighborItemHeight` | 44 | effective | 同上 | IC-074 |
| `bottomStripItemSpacing` | 8 | effective | 同上 | IC-074 |
| `bottomStripEdgeFadeWidth` | 24 | unwired | 同上；生产视图未使用，实际无渐隐 | IC-074 |
| `bottomStripDragMinimumDistance` | 4 | effective | 同上 | IC-074 |
| `bottomStripSwitchDistance` | 44 | effective | 同上 | IC-074 |
