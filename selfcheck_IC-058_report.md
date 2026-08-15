# IC-20260815-058 原生缩放与分页自验报告

## 1. 结论

IC-058 已完成。macOS CI #43 使用 Xcode 16.4 实际执行 326 个 XCTest，0 失败；随后
Release 真机构建、未签名 IPA 生成与 artifact 上传全部成功。N1～N8、IC-057 E1～E6、
IC-056 D1～D8 及本报告列出的全部指定回归均通过，自动验收 A～G 满足。原生动画与手感
仍按任务边界留给产品负责人真机验收。

## 2. 实现摘要

- S2 主图改由每页独立的 `UIScrollView` 承载，`minimumZoomScale=1`，
  `maximumZoomScale=pinchMaxScale`；缩放、触点锚定、平移及边界钳制均由原生容器完成。
- 双击进入 Nx 时按 `max(aspectFillMultiplier, minDoubleTapScale)` 构造触点中心目标矩形，
  直接调用 `zoom(to:animated:)`；状态机只接收原生结果，不参与活动视图的锚点或钳制。
- 外层分页也是 `UIScrollView`，开启 `isPagingEnabled`。分页步长为物理视口宽度加
  `pageSpacing`，分页单元本身始终保持物理视口尺寸，间隙显示既有黑色背景。内层到达
  水平边界后的继续拖动由 UIKit 原生嵌套滚动转交父容器，不含手写边界公式或偏移锁定。
- `pageSpacing` 新增为可持久化、可导出、面板可调参数，出厂值 20 pt；旧持久化数据
  缺少该字段时兼容回填 20，其余字段继续严格解码。
- 1x 与 Nx 单击均切换界面显隐。Nx 单击路径只改显隐，不改 `zoomScale`、
  `contentOffset`、状态机 `scale` 或 `viewportOffset`。
- 原生捏合期间使用稳定的图像请求倍率，不触发图像请求；结束时再按既有策略产生一次
  `scaleChange` 或 `pinchEnded` 请求。
- S2 六状态定义及 `s / c / D / K` 语义未改；上滑标记、下滑取消、底部横栏、相册与
  收藏行为未改。

## 3. N1～N8

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | 通过（CI #43） |
| N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | 通过（CI #43） |
| N3 | `testN3NativePagingUsesConfiguredPageSpacing` | 通过（CI #43） |
| N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | 通过（CI #43） |
| N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | 通过（CI #43） |
| N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | 通过（CI #43） |
| N7 | `testN7NativePageChangeResetsZoomToOne` | 通过（CI #43） |
| N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | 通过（CI #43） |

## 4. IC-057 E1～E6

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| E1 | `testE1FirstTapProducesImmediateSingleTapAction` | 通过（CI #43） |
| E2 | `testE2SecondTapWithinDecisionWindowRevertsAppliedSingleTap` | 通过（CI #43） |
| E3 | `testE3TapAfterDecisionWindowStartsNewImmediateSingleTap` | 通过（CI #43） |
| E4 | `testE4RevertedSingleTapThenDoubleTapMatchesDirectDoubleTap` | 通过（CI #43）；改接原生双击状态入口 |
| E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | 通过（CI #43） |
| E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | 通过（CI #43） |

## 5. IC-056 D1～D8

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| D1 | `testD1ScreenAspectFitInsetRatioShrinksShortEdgeToNinetyTwoPercent` | 通过（CI #43） |
| D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | 通过（CI #43） |
| D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | 通过（CI #43） |
| D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | 通过（CI #43）；替代为原生目标矩形断言 |
| D5 | `testD5DoubleTapUsesLargerAspectFillScale` | 通过（CI #43）；替代为原生目标矩形断言 |
| D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | 通过（CI #43）；替代为原生边界结果断言 |
| D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | 通过（CI #43）；替代为原生边界结果断言 |
| D8 | `testD8DoubleTapExitResetsScaleAndOffset` | 通过（CI #43）；替代为原生容器与状态机同步归一断言 |

## 6. IC-054 与 IC-055 指定回归

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| V1 | `testV1InterfaceVisibilityKeepsViewportSizeEqual` | 通过（CI #43） |
| V2 | `testV2BottomStripStatesKeepViewportSizeAndHeightEqual` | 通过（CI #43） |
| V3 | `testV3SheetPresentationKeepsViewportSizeEqual` | 通过（CI #43） |
| V4 | `testV4AllPresentationStatesShareFitAndDoubleTapMultiplier` | 通过（CI #43） |
| V5 | `testV5ParametersSurviveProcessModelRestart` | 通过（CI #43）；增加 pageSpacing 持久化断言 |
| V6 | `testV6AllFourImageRequestStrategiesTakeEffectImmediately` | 通过（CI #43） |
| V7 | `testV7MissingAspectCategoryReturnsExplicitEmptyResult` | 通过（CI #43） |
| V8 | `testV8FitInsetRatioGeometryAndScopeAreCorrect` | 通过（CI #43） |
| L1 | `testL1TopOverlayFramesRespectSafeAreaTop` | 通过（CI #43） |
| L2 | `testL2BottomOverlayFramesRespectHomeIndicator` | 通过（CI #43） |
| L3 | `testL3TopOverlayFramesDoNotIntersect` | 通过（CI #43） |
| L4 | `testL4ClickableOverlayControlsMeetMinimumTouchTarget` | 通过（CI #43） |
| L5 | `testL5CalibrationPanelsDoNotChangeViewportSize` | 通过（CI #43） |
| L6 | `testL6CalibrationPanelsStartHiddenWithoutVisibleEntry` | 通过（CI #43） |
| L7 | `testL7FactoryDefaultsMatchSystemParityDecision` | 通过（CI #43）；增加 pageSpacing 出厂值与导出断言 |
| P1 | `testP1NxSingleFingerDragProducesNonzeroPan` | 通过（CI #43）；使用替代断言 |
| P2 | `testP2NxPanStopsAtContentBoundaryWithoutExtraMargin` | 通过（CI #43）；使用替代断言 |
| P3 | `testP3OneXSingleFingerDragDoesNotPanPhoto` | 通过（CI #43）；使用替代断言 |
| R1 | `testR1PinchRequestsExactlyOnceAfterPinchEnded` | 通过（CI #43）；使用替代断言 |
| R2 | `testR2PinchDoesNotReplaceWithDegradedPreview` | 通过（CI #43） |
| T1 | `testT1AdjacentPageTracksFingerWithSameSignAndMonotonicOffset` | 通过（CI #43）；使用替代断言 |
| T2 | `testT2BelowSnapThresholdReturnsToCurrentPage` | 通过（CI #43）；使用替代断言 |
| T3 | `testT3PagingKeepsPhotoSizeAndResetsScaleAfterSwitch` | 通过（CI #43）；使用替代断言 |

## 7. 失效项清单与替代断言

以下旧断言依赖已被本卡删除的自定义视图实现，继续运行会验证死代码而非产品路径，因此按
原测试编号替换，没有删除测试方法，也没有降低专项数量门槛。

| 失效项 | 失效原因 | 替代断言 |
|---|---|---|
| P1 | 旧断言调用 `S2MainGestureArbitration` 与 `updateMainPan`，活动视图已不再使用 | 断言 Nx 内层对象为原生滚动容器、pan 已启用且原生 `contentOffset`/上报偏移非零 |
| P2 | 旧断言直接验证手写 `panLimits` 与 `clampedOffset` | 在边缘执行原生 `zoom(to:)`，断言 UIKit 最终内容边界贴齐且关闭额外弹性余量 |
| P3 | 旧断言调用状态机自定义平移入口 | 断言 1x 内层原生 pan 关闭、`zoomScale=1`、上报偏移为零 |
| R1 | 旧断言调用自定义 `updatePinch` / `endPinch` | 连续上报原生倍率时请求修订保持 0、请求倍率保持 1；原生捏合结束后修订恰增 1 |
| T1 | 旧断言直接调用手写 `pageOffset` | 改变原生分页 `contentOffset`，断言当前页与相邻页等量、同向、单调跟手 |
| T2 | 旧断言直接调用手写 `snapDestination` | 断言 `isPagingEnabled=true`，未跨半页的原生落点仍解析为当前分页单元 |
| T3 | 旧断言以手写页位移循环模拟跟手 | 断言分页单元尺寸固定相等，并在原生落页上报后 `scale=1`、偏移归零 |

补充迁移：D4～D8 与 E4 的旧断言直接调用自定义双击锚点／钳制入口，虽然不属于第 19 条
指定的 V/L/P/R/T 清单，也已改为原生目标矩形、原生边界结果或原生双击状态入口断言，避免
用失活路径冒充视图层验证。

另有一项非视图重写失效项：历史 IC047-040
`testIC047_040NxSingleTapDoesNothing` 与本卡明确采用的决策 17 冲突，已替换为
`testIC058NxSingleTapTogglesVisibilityWithoutViewportOrDataChanges`，并由 N5 再次覆盖
Nx 显隐切换且缩放、视口、`c`、`D` 不变；未修改规格或决策日志。

未失效并继续保留原断言的项目：V1～V4、V6～V8、L1～L6、R2；V5 与 L7 只增加新参数
断言，不删除旧断言。

## 8. 参数导出样例

```text
schemaVersion=1
taskID=IC-20260815-058-s2-native-zoom-paging
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
pageSpacing=20.000000
bottomStripCurrentItemSize=72.000000
bottomStripNeighborItemWidth=52.000000
bottomStripNeighborItemHeight=44.000000
bottomStripItemSpacing=8.000000
bottomStripEdgeFadeWidth=24.000000
bottomStripDragMinimumDistance=4.000000
bottomStripSwitchDistance=44.000000
```

样例包含验收指定的 `pageSpacing=20.000000` 与 `minDoubleTapScale=2.500000`。

## 9. 测试总数与 CI

- XCTest 总数：326。
- CI run：[iOS 构建与自验 #43](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31901203696)。
- CI job：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31901203696/job/95052148456)。
- CI 被测提交：`df61898a06ee963ba1c0427d7607f325d3b41f1e`。
- CI 环境：`macos-15`、Xcode 16.4（Build 16F6）、iPhone 模拟器。
- CI 结论：`success`；结构自验、硬编码扫描、XCTest、Release 真机构建、IPA 上传均成功。
- XCTest 日志原文：

```text
Executed 326 tests, with 0 failures (0 unexpected) in 19.061 (41.538) seconds
** TEST SUCCEEDED **
```

收敛记录：#40 首次发现 2 处 UIKit 编译 API 问题；#41 首次实际跑完 326 项并暴露 7 个
迁移测试问题；#42 收敛至 D7 的 2 个坐标系断言；#43 全绿。所有失败均保留在 Actions
历史中，没有以跳过测试、降低数量门槛或静默删除断言规避。

## 10. IPA artifact

- artifact：
  [PhotoCleanupMVE-unsigned-df61898a06ee](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31901203696/artifacts/9251194712)。
- artifact ID：`9251194712`；归档字节数：565694；到期时间：2026-11-13 18:28:12 UTC。
- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`。
- IPA 字节数：565524。
- IPA SHA-256：`fcf7c4792651ecb4bd169aa7c51c20b0bc1db58f873024e1c7c3dedaf2f8eba5`。
- 独立复核：下载后的 artifact 只含唯一预期 IPA；IPA 含
  `Payload/PhotoCleanupMVE.app/Info.plist` 与主二进制，路径穿越条目为 0，签名目录或描述文件
  为 0；本地重算 SHA-256 与 CI 构建日志完全一致。

CI 产物按既有流程构建为未签名 IPA，不包含开发者账号、设备绑定或描述文件；任务禁止账号
操作，因此不会生成绑定具体账号的签名包。该 artifact 可下载且 IPA 结构有效；在普通未越狱
真机上安装前仍需由用户既有签名／侧载链路签名，本任务不冒充已完成账号签名。

## 11. 变更文件清单

IC-058 相对已审计的 IC-057 继承提交 `5980c0b` 的变更文件：

- `PhotoCleanupMVE.xcodeproj/project.pbxproj`
- `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
- `PhotoCleanupMVE/Features/S2/S2View.swift`
- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
- `PhotoCleanupMVETests/S2StateMachineTests.swift`
- `Scripts/verify-IC-20260815-058.ps1`
- `selfcheck_IC-058_report.md`

清单不含任何 `SPEC-*.md` 或 `Decision_log.md`。

## 12. 自验脚本

Windows 或 macOS PowerShell 静态自验：

```powershell
./Scripts/verify-IC-20260815-058.ps1
```

安装 Xcode 且有可用 iPhone 模拟器的 macOS 完整自验：

```powershell
./Scripts/verify-IC-20260815-058.ps1 -执行XCTest
```

本次 Windows 本地结果：87 项专项静态检查全部通过；静态 XCTest 总数为 326；
String Catalog 条目与产品源码引用均为 149；用户可见硬编码残留为 0；仓库结构门禁与
`git diff --check` 通过。当前环境没有 Swift/Xcode 工具链，因此本地未执行、也不冒充执行
过 XCTest；实际编译和 XCTest 已由第 9 节 macOS CI 执行并通过。

## 13. 执行边界声明

- 开发基线：当前工作区未提交的 IC-057 成果先经 62 项静态门禁审计，再在 IC-058 分支
  单独形成继承提交 `5980c0b`；原 IC-057 分支引用与远端均未改动。
- 开发分支：`feature/ic-058-native-zoom-paging`。
- push 目标：仅 `origin/feature/ic-058-native-zoom-paging`。
- 代码验收提交：`df61898a06ee963ba1c0427d7607f325d3b41f1e`；其后只回填本报告。
- `main`：保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`，不提交、不合并。
- force push、PR、账号设置、授权与签名：均不执行。
- `SPEC-*.md`、`Decision_log.md`、S1、S3、S4、S5：均不修改。
- 配色、字体、图标、圆角、阴影与浮层材质：均不修改。
- 上滑标记、下滑取消、底部横栏、相册与收藏语义及阈值：均不修改。
- `debugAssetLimit`：保持 300，不清理。
- 原生动画与手感只交产品负责人真机验收，本报告不冒充手感结论。
