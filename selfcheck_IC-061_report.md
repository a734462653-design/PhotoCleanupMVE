# IC-20260815-061 沉浸过渡与 Nx 稳定自验报告

## 1. 当前结论

IC-061 已完成并推送到独立分支。最终验收运行 [CI #61](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31938432979)
在 macOS 15、Xcode 16.4、iPhone 模拟器上实际执行 363 项 XCTest，零失败；X1～X8、
IC-060 指定回归和更早回归全部通过。Release 真机目标构建成功，未签名 IPA artifact 已上传，
包内 IPA 的 SHA-256 为 `e0a0a09d0bedf10e9b9d58d16281965be23b356609825dff634f126aede8fb30`。

## 2. 实现摘要

### 2.1 视口中心缩放过渡

原生缩放视图新增外层缩放内容容器与内层照片呈现视图。`UIScrollView` 只缩放外层容器，
沉浸切换只对内层照片设置等比 `CGAffineTransform`。内层图层锚点固定为 `(0.5, 0.5)`，
其实际视口坐标由 `presentationAnchorInViewport()` 校验为物理视口中心。

动画区间内 `fittedSize`、`contentSize`、照片 `bounds` 和外层布局均保持源端点值；动画完成
后才在无动画事务中一次性提交目标 1x 尺寸并把呈现变换归一，因此没有布局尺寸或 `frame`
动画。圆角和缩放使用同一线性动画区间；呈现层圆角按当前缩放量反算，保证屏幕上观察到的
半径从 `fitCornerRadius` 连续补间到 0 或反向，完成提交时不跳变。

动画开关和时长继续由 `S2AnimationPolicy` 从 `animationsEnabled` 与
`animationDurationMilliseconds` 读取。关闭动画时直接提交目标端点，不创建活动过渡。

### 2.2 Nx 几何稳定与延迟提交

页面收到显隐目标时同时检查状态机倍率与原生 `zoomScale`。任一仍大于 1 时，只保存最新
目标 `pendingPresentationPage`，不调用沉浸几何配置，也不修改原生倍率、偏移、内容尺寸、
视口或照片可见框。内容版本同时区分请求倍率、请求策略与修订号：正常的捏合结束请求仍按
既有语义更新；沉浸延迟目标和活动动画期间不替换照片内容。

原生倍率实际回到 1 后，页面才按最新显隐状态启动一次同样的中心缩放过渡；完成时通过单一
提交入口写入目标 1x 几何。`presentationTransitionCount` 与
`presentationGeometryCommitCount` 用于 XCTest 断言没有中间提交或二次重排。Nx 期间没有
显隐变化时不存在延迟目标，退出路径继续只执行既有倍率和偏移归一。

### 2.3 动画期间图像请求

`hostingController.rootView` 只有一个集中写入入口；直接端点／动画完成才允许提交因沉浸
切换而延迟的照片内容。动画开始和动画区间内都不替换 SwiftUI 照片内容。X8 使用真实
`S2TemporaryPhotoImageView` 与计数型 `S2PhotoImageRequesting`：先证明夹具会产生初始请求，
再清零，并断言沉浸动画未结束前请求数严格为 0。

## 3. IC-061 专项测试

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| X1 | `testX1ImmersiveTransitionUsesViewportCenterAnchoredScaleTransform` | CI #61 通过 |
| X2 | `testX2ImmersiveTransitionKeepsLayoutSizeAndUsesTransform` | CI #61 通过 |
| X3 | `testX3CornerRadiusInterpolatesContinuouslyInBothDirections` | CI #61 通过 |
| X4 | `testX4DisabledAnimationsReachEndpointWithoutTransition` | CI #61 通过 |
| X5 | `testX5NxVisibilityTogglePreservesAllNativeGeometry` | CI #61 通过 |
| X6 | `testX6NxDeferredPresentationAppliesOnceAfterReturningToOneX` | CI #61 通过 |
| X7 | `testX7NxExitWithoutVisibilityToggleKeepsExistingBehavior` | CI #61 通过 |
| X8 | `testX8ImmersiveAnimationIssuesZeroImageRequests` | CI #61 通过 |

补充回归 `testIC061NxPinchEndedStillUpdatesImageRequestWithoutPresentationChange` 在 CI #61 通过，
用于锁定 Nx 期间没有沉浸几何变化时，既有捏合结束图像请求仍能正常更新。

## 4. IC-060 指定回归

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| K1 | `testK1SingleTapRequiresDoubleTapRecognizerToFail` | CI #61 通过 |
| K2 | `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | CI #61 通过 |
| K3 | `testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce` | CI #61 通过 |
| K4 | `testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds` | CI #61 通过 |
| S1 | `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | CI #61 通过 |
| S2 | `testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius` | CI #61 通过（替代断言） |
| S3 | `testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates` | CI #61 通过 |
| S4 | `testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget` | CI #61 通过 |
| S5 | `testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden` | CI #61 通过 |
| S6 | `testS6ScreenshotImmersiveFactoryDefaultIsTrue` | CI #61 通过 |
| A1 | `testA1NativePagingPhotoSwitchProducesNoHaptic` | CI #61 通过 |
| A2 | `testA2BottomStripCurrentItemChangesProduceExactlyNHaptics` | CI #61 通过 |
| A3 | `testA3DisabledPhotoSwitchHapticProducesNoHaptic` | CI #61 通过 |

## 5. 更早指定回归

| 来源 | XCTest 方法 | 当前状态 |
|---|---|---|
| IC-059 G1 | `testG1OneXSwipeUpMarksCurrentAsset` | CI #61 通过 |
| IC-059 G2 | `testG2NxSwipeUpMarksCurrentAsset` | CI #61 通过 |
| IC-059 G3 | `testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap` | CI #61 通过 |
| IC-059 G4 | `testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom` | CI #61 通过 |
| IC-059 M1 | `testM1ScreenAspectDoubleTapUsesMinimumScale` | CI #61 通过 |
| IC-059 M2 | `testM2NonScreenPhotoDoubleTapUsesAspectFillScale` | CI #61 通过 |
| IC-059 F1 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | CI #61 通过 |
| IC-059 F2 | `testF2CornerRadiusAppliesOnlyToInsetPhotos` | CI #61 通过 |
| IC-059 F3 | `testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility` | CI #61 通过 |
| IC-059 F4 | `testF4InsetDoesNotChangeViewportOrAspectFillMultiplier` | CI #61 通过 |
| IC-059 B1 | `testB1NxBoundaryContinuationProducesPagingDisplacement` | CI #61 通过 |
| IC-059 B2 | `testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex` | CI #61 通过 |
| IC-059 B3 | `testB3NxBoundaryPagingCompletionResetsNewPhotoScale` | CI #61 通过 |
| IC-059 H1 | `testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges` | CI #61 通过 |
| IC-059 H2 | `testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire` | CI #61 通过 |
| IC-058 N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | CI #61 通过 |
| IC-058 N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | CI #61 通过 |
| IC-058 N3 | `testN3NativePagingUsesConfiguredPageSpacing` | CI #61 通过 |
| IC-058 N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | CI #61 通过 |
| IC-058 N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | CI #61 通过 |
| IC-058 N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | CI #61 通过 |
| IC-058 N7 | `testN7NativePageChangeResetsZoomToOne` | CI #61 通过 |
| IC-058 N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | CI #61 通过 |
| IC-057 E1 | `testE1ReplacementSingleTapRunsAfterDoubleTapFailure` | CI #61 通过 |
| IC-057 E2 | `testE2ReplacementDoubleTapSuppressesSingleTapAction` | CI #61 通过 |
| IC-057 E3 | `testE3ReplacementTwoResolvedSingleTapsToggleTwice` | CI #61 通过 |
| IC-057 E4 | `testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap` | CI #61 通过 |
| IC-057 E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | CI #61 通过 |
| IC-057 E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | CI #61 通过 |
| IC-056 D1 | `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | CI #61 通过 |
| IC-056 D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | CI #61 通过 |
| IC-056 D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | CI #61 通过 |
| IC-056 D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | CI #61 通过 |
| IC-056 D5 | `testD5ReplacementNonScreenDoubleTapUsesAspectFillScale` | CI #61 通过 |
| IC-056 D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | CI #61 通过 |
| IC-056 D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | CI #61 通过 |
| IC-056 D8 | `testD8DoubleTapExitResetsScaleAndOffset` | CI #61 通过 |
| 既有 V4 | `testV4ReplacementPresentationStatesPreserveViewportAndZoomBaselines` | CI #61 通过 |

除上述逐项门禁外，CI #61 已实际运行全部 363 项 XCTest，以覆盖其余既有回归。

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

脚本检查 IC-060 继承点、独立分支、主干固定点、363 项测试、X1～X8、IC-060 K/S/A、
更早指定回归、零测试删除、过渡实现关键路径、参数默认值及差异、变更白名单、禁止文件、
`debugAssetLimit`、报告完整性、`git diff --check` 和仓库结构门禁。

Windows 本地专项脚本 101 项检查全部通过，静态 XCTest 总数 363；仓库结构门禁、
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

### 10.1 最终验收运行

- 工作流：[CI #61](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31938432979)
- 作业：[build-and-test](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31938432979/job/95143919414)
- 被测提交：`751c8bc0c4d9a4dba77ec6574f229d4bb5e410a7`
- 环境：`macos-15`、Xcode 16.4（Build 16F6）、iPhone 模拟器、iOS SDK 18.5
- 结论：结构门禁、硬编码门禁、全部 XCTest、Release 真机目标构建、IPA 校验和 artifact
  上传全部通过。

原始作业日志：

```text
2026-08-16T09:16:44.6214460Z 	 Executed 363 tests, with 0 failures (0 unexpected) in 40.246 (85.318) seconds
2026-08-16T09:16:49.8697490Z ** TEST SUCCEEDED **
2026-08-16T09:17:35.9016940Z ** BUILD SUCCEEDED **
```

### 10.2 收敛记录

- CI #58 在严格保留 `xcodebuild` 退出码后暴露 7 项真实失败：视口锚点使用了内容坐标，且
  测试夹具的初始 Nx 原生几何未与状态机同步。修复后 CI #59 的全部 XCTest 通过。
- 早期诊断运行 #55、#57 因日志管道缺少 `pipefail` 出现假绿，明确不作为验收依据；
  `57acc5c` 起已强制保留 `xcodebuild` 真实退出码。
- CI #60 的 XCTest 和 Release 构建通过，但最终 IPA notice 因 Bash 变量边界解析失败而红；
  `751c8bc` 修正后，CI #61 全流程严格通过。因此只以 #61 为最终验收运行。

### 10.3 IPA artifact

- 下载：[PhotoCleanupMVE-unsigned-751c8bc0c4d9](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31938432979/artifacts/9261385082)
- artifact ID：`9261385082`
- artifact ZIP：580392 字节
- artifact ZIP SHA-256：`835cb1c67e1ea6ed903948be4f9c62c3fcd245525b98dd9d7f28c40236188b55`
- 包内文件：`PhotoCleanupMVE-unsigned.ipa`
- IPA：580222 字节
- IPA SHA-256：`e0a0a09d0bedf10e9b9d58d16281965be23b356609825dff634f126aede8fb30`

已把 artifact 下载到本地并独立复算两层哈希；IPA 共 8 个 ZIP 条目，包含
`Payload/PhotoCleanupMVE.app/Info.plist` 和应用可执行文件，无绝对路径、路径穿越、反斜线或
符号链接条目，结构校验通过。由于本卡禁止操作账号，产物按既有 CI 约定为未签名 IPA；
可交给既有签名／侧载流程安装，不能在未签名状态下直接安装到普通真机。

## 11. 变更文件清单

1. `.github/workflows/ci.yml`
2. `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
3. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
4. `PhotoCleanupMVE/Features/S2/S2View.swift`
5. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
6. `Scripts/verify-IC-20260815-061.ps1`
7. `selfcheck_IC-061_report.md`

清单不含任何 `SPEC-*.md`、`Decision_log.md`、S1、S3、S4、S5、图像请求实现或
`CleanupCoordinator.swift`。CI 工作流的修改仅用于保留真实 XCTest 退出码、生成并校验
未签名 IPA、公开精确测试摘要与上传 artifact。

## 12. 执行边界声明

- 基线：`a340928ce2a088c7fe97c0c0467054eaf2f46724`（IC-060 交付分支头）。
- 独立分支：`feature/ic-061-immersive-transition`。
- `main` 与 `origin/main` 均保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- 未修改任何规格、决策日志、S1/S3/S4/S5、视觉样式、手势语义和阈值、触觉语义、图像
  请求策略出厂值、指定参数出厂值或 `debugAssetLimit`。
- 未合并主干、未 force push、未操作账号。
- 已推送的最终业务／测试提交为 `751c8bc0c4d9a4dba77ec6574f229d4bb5e410a7`；报告回填提交
  使用 `[skip ci]`，不改变该验收运行的被测源码。
- 网络只用于审查 GitHub 官方固定动作、获授权的独立分支推送、CI 查询以及同一仓库的
  作业日志和 artifact 下载；未发送照片、Cookie、Token 或其他用户数据，凭证未输出或落盘。
