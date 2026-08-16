# IC-20260815-061 沉浸过渡与 Nx 稳定自验报告

## 1. 当前结论

IC-061 的代码、X1～X8、新增自验脚本和回归替代断言已完成。Windows 本地可执行的
静态门禁通过，XCTest 静态总数由 IC-060 的 354 项增加为 362 项；当前环境没有 Xcode，
因此实际编译、XCTest、Release 真机构建、IPA 和哈希结论须以首次推送后的 macOS CI 为准。

## 2. 实现摘要

### 2.1 视口中心缩放过渡

原生缩放视图新增外层缩放内容容器与内层照片呈现视图。`UIScrollView` 只缩放外层容器，
沉浸切换只对内层照片设置等比 `CGAffineTransform`。内层图层锚点固定为 `(0.5, 0.5)`，
其实际视口坐标由 `presentationAnchorInViewport()` 校验为物理视口中心。

动画区间内 `fittedSize`、`contentSize`、照片 `bounds` 和外层布局均保持源端点值；动画完成
后才在无动画事务中一次性提交目标 1x 尺寸并把呈现变换归一，因此没有布局尺寸或 `frame`
动画。圆角和缩放使用同一线性动画区间，圆角端点为 `fitCornerRadius` 与 0。

动画开关和时长继续由 `S2AnimationPolicy` 从 `animationsEnabled` 与
`animationDurationMilliseconds` 读取。关闭动画时直接提交目标端点，不创建活动过渡。

### 2.2 Nx 几何稳定与延迟提交

页面收到显隐目标时同时检查状态机倍率与原生 `zoomScale`。任一仍大于 1 时，只保存最新
目标 `pendingPresentationPage`，不替换照片内容、不调用几何配置，也不修改原生倍率、偏移、
内容尺寸、视口或照片可见框。

原生倍率实际回到 1 后，页面才按最新显隐状态启动一次同样的中心缩放过渡；完成时通过单一
提交入口写入目标 1x 几何。`presentationTransitionCount` 与
`presentationGeometryCommitCount` 用于 XCTest 断言没有中间提交或二次重排。Nx 期间没有
显隐变化时不存在延迟目标，退出路径继续只执行既有倍率和偏移归一。

### 2.3 动画期间图像请求

`hostingController.rootView` 只有一个写入点，且位于直接端点／动画完成的几何提交入口。
动画开始和动画区间内都不替换 SwiftUI 照片内容。X8 使用真实
`S2TemporaryPhotoImageView` 与计数型 `S2PhotoImageRequesting`：先证明夹具会产生初始请求，
再清零，并断言沉浸动画未结束前请求数严格为 0。

## 3. IC-061 专项测试

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| X1 | `testX1ImmersiveTransitionUsesViewportCenterAnchoredScaleTransform` | 静态就绪，待 CI 实跑 |
| X2 | `testX2ImmersiveTransitionKeepsLayoutSizeAndUsesTransform` | 静态就绪，待 CI 实跑 |
| X3 | `testX3CornerRadiusInterpolatesContinuouslyInBothDirections` | 静态就绪，待 CI 实跑 |
| X4 | `testX4DisabledAnimationsReachEndpointWithoutTransition` | 静态就绪，待 CI 实跑 |
| X5 | `testX5NxVisibilityTogglePreservesAllNativeGeometry` | 静态就绪，待 CI 实跑 |
| X6 | `testX6NxDeferredPresentationAppliesOnceAfterReturningToOneX` | 静态就绪，待 CI 实跑 |
| X7 | `testX7NxExitWithoutVisibilityToggleKeepsExistingBehavior` | 静态就绪，待 CI 实跑 |
| X8 | `testX8ImmersiveAnimationIssuesZeroImageRequests` | 静态就绪，待 CI 实跑 |

## 4. IC-060 指定回归

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| K1 | `testK1SingleTapRequiresDoubleTapRecognizerToFail` | 静态保留，待 CI 实跑 |
| K2 | `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | 静态保留，待 CI 实跑 |
| K3 | `testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce` | 静态保留，待 CI 实跑 |
| K4 | `testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds` | 静态保留，待 CI 实跑 |
| S1 | `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | 静态保留，待 CI 实跑 |
| S2 | `testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius` | 已替换失效子断言，待 CI 实跑 |
| S3 | `testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates` | 静态保留，待 CI 实跑 |
| S4 | `testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget` | 静态保留，待 CI 实跑 |
| S5 | `testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden` | 静态保留，待 CI 实跑 |
| S6 | `testS6ScreenshotImmersiveFactoryDefaultIsTrue` | 静态保留，待 CI 实跑 |
| A1 | `testA1NativePagingPhotoSwitchProducesNoHaptic` | 静态保留，待 CI 实跑 |
| A2 | `testA2BottomStripCurrentItemChangesProduceExactlyNHaptics` | 静态保留，待 CI 实跑 |
| A3 | `testA3DisabledPhotoSwitchHapticProducesNoHaptic` | 静态保留，待 CI 实跑 |

## 5. 更早指定回归

| 来源 | XCTest 方法 | 当前状态 |
|---|---|---|
| IC-059 G1 | `testG1OneXSwipeUpMarksCurrentAsset` | 静态保留，待 CI 实跑 |
| IC-059 G2 | `testG2NxSwipeUpMarksCurrentAsset` | 静态保留，待 CI 实跑 |
| IC-059 G3 | `testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap` | 静态保留，待 CI 实跑 |
| IC-059 G4 | `testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom` | 静态保留，待 CI 实跑 |
| IC-059 M1 | `testM1ScreenAspectDoubleTapUsesMinimumScale` | 静态保留，待 CI 实跑 |
| IC-059 M2 | `testM2NonScreenPhotoDoubleTapUsesAspectFillScale` | 静态保留，待 CI 实跑 |
| IC-059 F1 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | 静态保留，待 CI 实跑 |
| IC-059 F2 | `testF2CornerRadiusAppliesOnlyToInsetPhotos` | 静态保留，待 CI 实跑 |
| IC-059 F3 | `testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility` | 静态保留，待 CI 实跑 |
| IC-059 F4 | `testF4InsetDoesNotChangeViewportOrAspectFillMultiplier` | 静态保留，待 CI 实跑 |
| IC-059 B1 | `testB1NxBoundaryContinuationProducesPagingDisplacement` | 静态保留，待 CI 实跑 |
| IC-059 B2 | `testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex` | 静态保留，待 CI 实跑 |
| IC-059 B3 | `testB3NxBoundaryPagingCompletionResetsNewPhotoScale` | 静态保留，待 CI 实跑 |
| IC-059 H1 | `testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges` | 静态保留，待 CI 实跑 |
| IC-059 H2 | `testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire` | 静态保留，待 CI 实跑 |
| IC-058 N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | 静态保留，待 CI 实跑 |
| IC-058 N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | 静态保留，待 CI 实跑 |
| IC-058 N3 | `testN3NativePagingUsesConfiguredPageSpacing` | 静态保留，待 CI 实跑 |
| IC-058 N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | 静态保留，待 CI 实跑 |
| IC-058 N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | 静态保留，待 CI 实跑 |
| IC-058 N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | 静态保留，待 CI 实跑 |
| IC-058 N7 | `testN7NativePageChangeResetsZoomToOne` | 静态保留，待 CI 实跑 |
| IC-058 N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | 静态保留，待 CI 实跑 |
| IC-057 E1 | `testE1ReplacementSingleTapRunsAfterDoubleTapFailure` | 静态保留，待 CI 实跑 |
| IC-057 E2 | `testE2ReplacementDoubleTapSuppressesSingleTapAction` | 静态保留，待 CI 实跑 |
| IC-057 E3 | `testE3ReplacementTwoResolvedSingleTapsToggleTwice` | 静态保留，待 CI 实跑 |
| IC-057 E4 | `testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap` | 静态保留，待 CI 实跑 |
| IC-057 E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | 静态保留，待 CI 实跑 |
| IC-057 E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | 静态保留，待 CI 实跑 |
| IC-056 D1 | `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | 静态保留，待 CI 实跑 |
| IC-056 D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | 静态保留，待 CI 实跑 |
| IC-056 D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | 静态保留，待 CI 实跑 |
| IC-056 D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | 静态保留，待 CI 实跑 |
| IC-056 D5 | `testD5ReplacementNonScreenDoubleTapUsesAspectFillScale` | 静态保留，待 CI 实跑 |
| IC-056 D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | 静态保留，待 CI 实跑 |
| IC-056 D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | 静态保留，待 CI 实跑 |
| IC-056 D8 | `testD8DoubleTapExitResetsScaleAndOffset` | 静态保留，待 CI 实跑 |
| 既有 V4 | `testV4ReplacementPresentationStatesPreserveViewportAndZoomBaselines` | 静态保留，待 CI 实跑 |

除上述逐项门禁外，CI 将实际运行全部 362 项 XCTest，以覆盖其余既有回归。

## 6. 失效项清单与替代断言

| 失效项 | 失效原因 | 替代断言 |
|---|---|---|
| IC-060 S2 控制器即时端点断言 | 旧断言要求开启动画后立即把 `fittedSize` 和 `cornerRadius` 写成隐藏端点；本卡明确要求动画区间布局尺寸不变并连续补间圆角 | S2 先断言动画区间仍为显示态布局，再显式完成过渡后断言隐藏端点；X2 断言尺寸差只由变换承担，X3 断言圆角两方向端点和中点 |
| 既有 L7 任务标识断言 | 参数导出的任务追踪标识应从 IC-060 更新为 IC-061；该字符串不是出厂参数值 | 保留完整配置对象相等断言，并把导出标识替换为 `IC-20260815-061-immersive-transition-and-nx-stability`；所有参数数值继续逐项锁定 |

没有删除 XCTest。IC-060 的 K1～K4、S1、S3～S6、A1～A3 与更早指定回归断言内容
保持不变；S2 只有上述与新动画规则冲突的即时端点子断言被替换。

## 7. 参数导出样例

```text
taskID=IC-20260815-061-immersive-transition-and-nx-stability
animationsEnabled=true
animationDurationMilliseconds=180.000000
fitInsetRatio=0.300000
fitCornerRadius=28.000000
minDoubleTapScale=2.500000
pageSpacing=20.000000
doubleTapDecisionWindowMilliseconds=200.000000
screenshotImmersiveOnHide=true
scaleChangeRequestPolicy=pinchEnded
degradedPreviewPolicy=finalImageOnly
```

与 IC-060 相比仅更新 `taskID`；所有出厂参数值和图像请求策略均未改动。

## 8. 自验脚本与本地结果

执行命令：

```powershell
.\Scripts\verify-IC-20260815-061.ps1
```

脚本检查 IC-060 继承点、独立分支、主干固定点、362 项测试、X1～X8、IC-060 K/S/A、
更早指定回归、零测试删除、过渡实现关键路径、参数默认值及差异、变更白名单、禁止文件、
`debugAssetLimit`、报告完整性、`git diff --check` 和仓库结构门禁。

Windows 本地专项脚本 96 项检查全部通过，静态 XCTest 总数 362；仓库结构门禁、
String Catalog 扫描和 `git diff --check` 通过，用户可见硬编码残留为 0。Windows 环境
没有 Xcode，因此不会把静态扫描冒充为 XCTest。

## 9. 外部动作安全审查

既有 CI 唯一外部动作固定到 GitHub 官方 `actions/upload-artifact` 的完整提交
`043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`。已审查该提交的动作清单、入口、输入解析、
文件搜索、上传实现和依赖声明：没有混淆、`eval`、系统命令执行或读取凭证文件的代码；
网络行为仅由 GitHub 官方 artifact 客户端把明确输入文件上传到当前工作流的 artifact
服务。仓库工作流把输入限定为普通文件 `BuildArtifacts/PhotoCleanupMVE-unsigned.ipa`，
预先拒绝符号链接，关闭隐藏文件，且不覆盖既有 artifact，因此不会扫描或传输工作区其他
文件。

## 10. CI、XCTest 与 IPA

首次实现提交尚未推送；本节将在 macOS CI 完成后回填真实运行链接、被测提交、
`Executed N tests` 日志原文、结论、artifact 下载链接、字节数和 SHA-256。当前不声称
XCTest、Release 构建或 IPA 已通过。

## 11. 变更文件清单

1. `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
2. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
3. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
4. `Scripts/verify-IC-20260815-061.ps1`
5. `selfcheck_IC-061_report.md`

清单不含任何 `SPEC-*.md`、`Decision_log.md`、S1、S3、S4、S5、图像请求实现、
`CleanupCoordinator.swift` 或 CI 工作流。

## 12. 执行边界声明

- 基线：`a340928ce2a088c7fe97c0c0467054eaf2f46724`（IC-060 交付分支头）。
- 独立分支：`feature/ic-061-immersive-transition`。
- `main` 与 `origin/main` 均保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- 未修改任何规格、决策日志、S1/S3/S4/S5、视觉样式、手势语义和阈值、触觉语义、图像
  请求策略出厂值、指定参数出厂值或 `debugAssetLimit`。
- 未合并主干、未 force push、未操作账号。
- 网络只用于审查 GitHub 官方固定动作；后续仅用于获授权的分支推送、CI 查询和 artifact
  下载，不发送照片、Cookie、Token 或其他用户数据。
