# IC-20260815-056-doubletap-scale-and-anchor 自验报告

## 1. 结论

IC-056 功能、D1～D8 XCTest 与专卡自验脚本已实现。本地结构门禁、用户可见硬编码
扫描及静态检查已通过；完整 312 项 XCTest、Release IPA 与 SHA-256 须由 macOS CI
生成，当前等待首次推送后的 CI 结果回填。

测试数量构成为：IC-055 交付 304 项 + 本卡 D1～D8 共 8 项 = 312 项，满足“不少于
IC-055 交付总数 + 8”的门槛。

## 2. fitInsetRatio 根因与修复

根因类别：**`fitInsetScope` 的屏幕比例判定未命中**。

参数已经接到渲染层：`S2ViewportLayout.metrics` 生成的 `oneXDisplaySize` 直接作为主图
宽高传入 `.frame`，之后没有布局把该尺寸覆盖。问题发生在更早的作用域判断：旧实现
直接比较带方向的 `assetAspectRatio` 与 `viewportAspectRatio`。例如同一屏幕比例的
竖向视口为 `0.5`，照片旋转后为 `2.0`，旧判断会把它当作非屏幕比例照片，令
`insetScale = 1`，所以 `fitInsetRatio=0.08` 不会进入实际显示尺寸。

修复后，照片和视口都先归一为“短边 / 长边”比例，再沿用原 1% 判定容差。因此本次
不是通过放宽容差掩盖问题；方向相反但物理比例相同的照片会命中，真正不同的宽高比
仍不受 `screenAspectOnly` 内缩影响。

同时按本卡 D1 明确语义，把 `fitInsetRatio=0.08` 解释为整体 1x 显示比例减少 8%，即
`oneXDisplaySize = aspectFitSize × 0.92`，而不是旧实现的“两侧各 8%”所导致的
`× 0.84`。屏幕比例照片的 1x 短边因此等于视口短边 `× 0.92`。

## 3. 双击倍率与锚点

- 删除 `aspectFillDegenerateTolerancePercent` 与
  `aspectFillDegenerateTargetScale` 的配置、解析、导出和决策分支。
- 新增可在后台面板调整的 `minDoubleTapScale`，出厂值为 `2.5`。
- 双击进入统一使用
  `max(S2Geometry.aspectFillMultiplier(...), parameters.minDoubleTapScale)`。
- 填满倍数只由照片宽高比和完整物理视口计算，不读取内缩后的 1x 显示尺寸；
  `fitInsetRatio` 因而不会改变目标倍数。
- `doubleTapAnchorStrategy` 只剩 `touchPoint` 一个选项。缩放前后保持触点对应同一照片
  位置，再用实际内容尺寸和零余量 `panLimits` 逐轴钳制。
- 双击退出继续把 `s` 严格归一，并把平移偏移清零。

### 与 v13 第 107 条的冲突记录

v13 第 107 条锁定“通常取实时填满倍数，仅在退化容差成立时取退化目标倍数”。本卡
第 2～4 条明确废除该容差分支，并改为对所有照片取“实时填满倍数与
`minDoubleTapScale` 的较大值”。两者存在文本冲突；实现按本卡执行，未修改任何规格
文件或 `Decision_log.md`。

## 4. D1～D8

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| D1 | `testD1ScreenAspectFitInsetRatioShrinksShortEdgeToNinetyTwoPercent` | 等待 CI |
| D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | 等待 CI |
| D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | 等待 CI |
| D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | 等待 CI |
| D5 | `testD5DoubleTapUsesLargerAspectFillScale` | 等待 CI |
| D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | 等待 CI |
| D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | 等待 CI |
| D8 | `testD8DoubleTapExitResetsScaleAndOffset` | 等待 CI |

D6 在距左边 1 pt 处双击，直接计算缩放后内容帧并断言 `minX = 0`。D7 分别在距右、
上、下边 1 pt 处双击，断言 `maxX = viewport.width`、`minY = 0`、
`maxY = viewport.height`，容差均为 `0.000001 pt`，没有额外边界余量。

## 5. IC-054 与 IC-055 指定回归

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| V1 | `testV1InterfaceVisibilityKeepsViewportSizeEqual` | 等待 CI |
| V2 | `testV2BottomStripStatesKeepViewportSizeAndHeightEqual` | 等待 CI |
| V3 | `testV3SheetPresentationKeepsViewportSizeEqual` | 等待 CI |
| V4 | `testV4AllPresentationStatesShareFitAndDoubleTapMultiplier` | 等待 CI |
| V5 | `testV5ParametersSurviveProcessModelRestart` | 等待 CI |
| V6 | `testV6AllFourImageRequestStrategiesTakeEffectImmediately` | 等待 CI |
| V7 | `testV7MissingAspectCategoryReturnsExplicitEmptyResult` | 等待 CI |
| V8 | `testV8FitInsetRatioGeometryAndScopeAreCorrect` | 等待 CI |
| L1 | `testL1TopOverlayFramesRespectSafeAreaTop` | 等待 CI |
| L2 | `testL2BottomOverlayFramesRespectHomeIndicator` | 等待 CI |
| L3 | `testL3TopOverlayFramesDoNotIntersect` | 等待 CI |
| L4 | `testL4ClickableOverlayControlsMeetMinimumTouchTarget` | 等待 CI |
| L5 | `testL5CalibrationPanelsDoNotChangeViewportSize` | 等待 CI |
| L6 | `testL6CalibrationPanelsStartHiddenWithoutVisibleEntry` | 等待 CI |
| L7 | `testL7FactoryDefaultsMatchSystemParityDecision` | 等待 CI |
| P1 | `testP1NxSingleFingerDragProducesNonzeroPan` | 等待 CI |
| P2 | `testP2NxPanStopsAtContentBoundaryWithoutExtraMargin` | 等待 CI |
| P3 | `testP3OneXSingleFingerDragDoesNotPanPhoto` | 等待 CI |
| R1 | `testR1PinchRequestsExactlyOnceAfterPinchEnded` | 等待 CI |
| R2 | `testR2PinchDoesNotReplaceWithDegradedPreview` | 等待 CI |
| T1 | `testT1AdjacentPageTracksFingerWithSameSignAndMonotonicOffset` | 等待 CI |
| T2 | `testT2BelowSnapThresholdReturnsToCurrentPage` | 等待 CI |
| T3 | `testT3PagingKeepsPhotoSizeAndResetsScaleAfterSwitch` | 等待 CI |

## 6. 参数导出样例

```text
schemaVersion=1
taskID=IC-20260815-056-doubletap-scale-and-anchor
valueStatus=④项目判断默认值，可修订
pinchMaxScale=4.000000
zoomSnapBackThreshold=1.100000
minDoubleTapScale=2.500000
doubleTapAnchorStrategy=touchPoint
edgePagingTriggerDistance=40.000000
edgePagingTriggerVelocity=300.000000
verticalSwipeDistance=40.000000
verticalSwipeVelocity=100.000000
verticalSwipeMaximumDurationMilliseconds=0.000000
horizontalSwipeDistance=40.000000
horizontalSwipeVelocity=100.000000
horizontalSwipeMaximumDurationMilliseconds=0.000000
pinchMinimumScaleDelta=0.010000
pinchMinimumVelocityPerSecond=0.000000
pinchMaximumDurationMilliseconds=0.000000
mainDragMinimumDistance=8.000000
mainDragMinimumVelocity=0.000000
mainDragMaximumDurationMilliseconds=0.000000
singleTapMaximumMovement=12.000000
singleTapMaximumDurationMilliseconds=280.000000
singleTapDecisionWindowMilliseconds=280.000000
doubleTapDecisionWindowMilliseconds=320.000000
singleTapTouchCount=1
doubleTapTouchCount=1
singleDragTouchCount=1
pinchTouchCount=2
gestureExclusivityPolicy=pinchBeforeSingleDrag
scaleChangeRequestPolicy=pinchEnded
degradedPreviewPolicy=finalImageOnly
animationsEnabled=true
animationDurationMilliseconds=180.000000
fitInsetRatio=0.080000
fitInsetScope=screenAspectOnly
bottomStripCurrentItemSize=72.000000
bottomStripNeighborItemWidth=52.000000
bottomStripNeighborItemHeight=44.000000
bottomStripItemSpacing=8.000000
bottomStripEdgeFadeWidth=24.000000
bottomStripDragMinimumDistance=4.000000
bottomStripSwitchDistance=44.000000
```

样例不含 `aspectFillDegenerateTolerancePercent` 与
`aspectFillDegenerateTargetScale`，并含 `minDoubleTapScale=2.500000`。

## 7. CI 与 IPA

- CI run：等待首次推送
- CI 结论：等待首次推送
- CI 被测提交：等待首次推送
- XCTest：静态总数 312；执行结果等待 CI
- IPA artifact：等待首次推送
- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`
- IPA SHA-256：等待首次推送

CI workflow 未改动。既有流程只检出本仓库、执行仓库内结构自验与 XCTest、构建
不含账号签名的 Release 应用，并用固定提交哈希的 GitHub 官方 artifact 动作上传。
本卡没有新增外部依赖、网络地址、数据传输代码或账号操作。

## 8. 变更文件清单

- `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `PhotoCleanupMVE/Features/S2/S2View.swift`
- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
- `PhotoCleanupMVETests/S2StateMachineTests.swift`
- `Scripts/verify-IC-20260815-056.ps1`
- `selfcheck_IC-056_report.md`

清单不含任何 `SPEC-*.md` 或 `Decision_log.md`。

## 9. 自验脚本

执行：

```powershell
./Scripts/verify-IC-20260815-056.ps1
```

脚本验证 IC-055 基线、独立分支、主干未动、静态测试总数、D1～D8 与全部指定回归
测试名、参数增删、倍率公式、唯一锚点分支、方向归一、渲染接线、零余量钳制、视觉
样式边界、变更文件白名单、禁止文件、`debugAssetLimit`、`git diff --check` 与仓库
结构门禁。最终本地结果：63 项检查通过；静态 XCTest 总数 312；D1～D8 与全部指定
回归测试均存在；用户可见硬编码残留 0；String Catalog 产品 key 与源码引用均为
148；`git diff --check` 通过。

## 10. 执行边界声明

- 开发基线：`d562f1a0248b110ed5da031618a36cd3a4331c50`
- 开发分支：`feature/ic-056-doubletap-scale`
- push 目标：仅 `origin/feature/ic-056-doubletap-scale`
- 合并 `main`：未执行
- force push：未执行
- PR：未创建
- 账号设置、授权、签名或其他账号操作：未执行
- `SPEC-*.md` 与 `Decision_log.md`：未修改
- S1、S3、S4、S5：未修改
- 翻页转场、上滑标记、下滑取消的行为与阈值：未修改
- 图像请求策略出厂值：未修改
- `debugAssetLimit`：保持 `300`，未清理
- 配色、字体、图标、圆角、阴影及既有间距：未修改
- 产品负责人真机手感验收：不冒充自动自验结论，仍由负责人真机验收
