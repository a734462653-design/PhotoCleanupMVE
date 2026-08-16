# IC-20260815-060 点击裁决、截图沉浸与触觉反馈自验报告

## 1. 当前结论

IC-060 的代码、13 项新增 XCTest、自验脚本与回归替代断言已经完成。Windows 本地静态
门禁通过，XCTest 静态总数由 IC-059 的 341 项增加为 354 项。当前报告随首次实现提交
进入 macOS CI；CI 日志、最终运行链接、IPA artifact 与 SHA-256 将以最终验证结果更新。

## 2. 实现摘要

### 2.1 单击延后裁决

主图为单击和双击分别使用 `UITapGestureRecognizer`，并显式执行
`singleTapRecognizer.require(toFail: doubleTapRecognizer)`。单击识别器只有在 UIKit 将
双击识别器判为失败后才会离开 `possible` 并执行一次显隐切换；双击成功时单击识别器
失败，不产生任何显隐变化。

本卡删除了 `immediateSingleTapWasApplied`、`revertingImmediateSingleTap`、
`visibilityBeforeDoubleTapZoom`、单击/双击
同时识别回调、第二击 `tapCount` 排除和全部“首击立即生效、双击再撤销”路径。没有新增
`Timer`、`DispatchQueue.main.asyncAfter`、位置缓存或点击协调器。

### 2.2 `doubleTapDecisionWindowMilliseconds` 的实际作用

出厂值由 `320` 改为 `200`，参数面板可在 `0...600` 毫秒内以 10 毫秒步长调整，并继续
持久化和导出。

UIKit 的公开 `UITapGestureRecognizer` 接口提供点击次数和触点数等配置，但不提供可设置的
双击间隔；失败依赖的实际等待时长由 UIKit 决定。Apple 对
[`require(toFail:)`](https://developer.apple.com/documentation/uikit/uigesturerecognizer/require%28tofail%3A%29)
的说明也明确该关系会让单击保持 `possible`，直到双击失败或成功。

因此本参数不伪装成 UIKit 的系统超时。它的实际作用是“单击裁决延迟诊断目标”：页面记录
第一击的 UIKit `UITouch.timestamp`，在 UIKit 最终调用单击动作时计算实际延迟，再用当前
参数判断 `metConfiguredTarget`，将延迟、目标和结果写入实时读数面板。该诊断只观察 UIKit
裁决结果，不参与裁决，不创建计时器，也不记录位置。K4 同时断言参数值改变会改变诊断
达标结果，避免保留无作用参数。

### 2.3 决策 18：截图沉浸态

布局继续通过 `S2ViewportLayout.insetApplies` 调用
`S2Geometry.isScreenAspectMatch`，因此框显照片集合与手机框完全相同，继续使用方向归一和
1% 容差。

- 界面显示：框显照片按 `fitInsetRatio=0.30` 显示为视口短边的 70%，圆角为 28。
- 界面隐藏且 `screenshotImmersiveOnHide=true`：显示尺寸恢复为完整 `aspectFitSize`，
  至少一边贴合视口边界，宽高均不超过视口，图像仍使用 `scaledToFit`，圆角为 0。
- 非框显照片：显隐两态的尺寸和圆角完全相同。
- 开关关闭：框显照片隐藏后仍保持 70% 手机框和 28 点圆角。

原生页控制器只在同一框显照片发生显隐且尺寸或圆角确有变化时执行过渡。过渡使用
`S2AnimationPolicy`，时长来自 `animationDurationMilliseconds`；关闭 `animationsEnabled`
或时长为 0 时通过 `UIView.performWithoutAnimation` 直接切换。布局仍返回相同的视口、
`aspectFillMultiplier` 和分类后的双击目标倍数。

### 2.4 触觉反馈

分页控制器已删除照片切换触觉回调，普通左右分页和 Nx 边缘分页均不能触发触觉。触觉策略
仅接受 `.bottomStripDrag` 来源；底部缩略图拖动每次令当前项变化时，既有逐阈值循环都会
立即调用一次 `UISelectionFeedbackGenerator.selectionChanged()`，没有落页/结束依赖、节流
或合并。`hapticOnPhotoSwitch=false` 会在统一入口拒绝全部触觉。

## 3. IC-060 十三项专项测试

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| K1 | `testK1SingleTapRequiresDoubleTapRecognizerToFail` | 静态存在；待 CI |
| K2 | `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | 静态存在；待 CI |
| K3 | `testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce` | 静态存在；待 CI |
| K4 | `testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds` | 静态存在；待 CI |
| S1 | `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | 静态存在；待 CI |
| S2 | `testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius` | 静态存在；待 CI |
| S3 | `testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates` | 静态存在；待 CI |
| S4 | `testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget` | 静态存在；待 CI |
| S5 | `testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden` | 静态存在；待 CI |
| S6 | `testS6ScreenshotImmersiveFactoryDefaultIsTrue` | 静态存在；待 CI |
| A1 | `testA1NativePagingPhotoSwitchProducesNoHaptic` | 静态存在；待 CI |
| A2 | `testA2BottomStripCurrentItemChangesProduceExactlyNHaptics` | 静态存在；待 CI |
| A3 | `testA3DisabledPhotoSwitchHapticProducesNoHaptic` | 静态存在；待 CI |

S2 还在同一测试内断言：开启动画时显隐过渡时长为出厂值 0.18 秒；关闭动画时记录时长为
0 并直接切换。

## 4. 指定回归测试

### 4.1 IC-059 G1～G4、M1～M2、F1～F4、B1～B3、H1～H2

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| G1 | `testG1OneXSwipeUpMarksCurrentAsset` | 静态存在；待 CI |
| G2 | `testG2NxSwipeUpMarksCurrentAsset` | 静态存在；待 CI |
| G3 | `testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap` | 替代断言；待 CI |
| G4 | `testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom` | 替代断言；待 CI |
| M1 | `testM1ScreenAspectDoubleTapUsesMinimumScale` | 静态存在；待 CI |
| M2 | `testM2NonScreenPhotoDoubleTapUsesAspectFillScale` | 静态存在；待 CI |
| F1 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | 静态存在；待 CI |
| F2 | `testF2CornerRadiusAppliesOnlyToInsetPhotos` | 静态存在；待 CI |
| F3 | `testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility` | 替代断言；待 CI |
| F4 | `testF4InsetDoesNotChangeViewportOrAspectFillMultiplier` | 静态存在；待 CI |
| B1 | `testB1NxBoundaryContinuationProducesPagingDisplacement` | 静态存在；待 CI |
| B2 | `testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex` | 静态存在；待 CI |
| B3 | `testB3NxBoundaryPagingCompletionResetsNewPhotoScale` | 静态存在；待 CI |
| H1 | `testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges` | 替代断言；待 CI |
| H2 | `testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire` | 替代断言；待 CI |

### 4.2 IC-058 N1～N8

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | 静态存在；待 CI |
| N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | 静态存在；待 CI |
| N3 | `testN3NativePagingUsesConfiguredPageSpacing` | 静态存在；待 CI |
| N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | 静态存在；待 CI |
| N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | 静态存在；待 CI |
| N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | 静态存在；待 CI |
| N7 | `testN7NativePageChangeResetsZoomToOne` | 静态存在；待 CI |
| N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | 静态存在；待 CI |

### 4.3 IC-057 E1～E6

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| E1 | `testE1ReplacementSingleTapRunsAfterDoubleTapFailure` | 替代断言；待 CI |
| E2 | `testE2ReplacementDoubleTapSuppressesSingleTapAction` | 替代断言；待 CI |
| E3 | `testE3ReplacementTwoResolvedSingleTapsToggleTwice` | 替代断言；待 CI |
| E4 | `testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap` | 替代断言；待 CI |
| E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | 静态存在；待 CI |
| E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | 静态存在；待 CI |

### 4.4 IC-056 D1～D8

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| D1 | `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | 静态存在；待 CI |
| D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | 静态存在；待 CI |
| D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | 静态存在；待 CI |
| D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | 静态存在；待 CI |
| D5 | `testD5ReplacementNonScreenDoubleTapUsesAspectFillScale` | 静态存在；待 CI |
| D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | 静态存在；待 CI |
| D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | 静态存在；待 CI |
| D8 | `testD8DoubleTapExitResetsScaleAndOffset` | 静态存在；待 CI |

## 5. 失效项清单与替代断言

| 失效项 | 失效原因 | 替代断言 |
|---|---|---|
| IC-057 E1 | “第一击立即生效”被本卡明确删除 | 断言显式失败依赖存在，UIKit 宣告双击失败后才执行一次单击 |
| IC-057 E2 | “双击撤销首击”逻辑被删除 | 断言双击不产生单击显隐变化且直接到达目标倍率 |
| IC-057 E3 | 旧断言依赖自建毫秒窗口区分两击 | 断言两次分别由 UIKit 裁决的单击各切换一次，不自行判断窗口 |
| IC-057 E4 | 旧断言比较“立即单击后撤销”与直接双击 | 比较原生双击路径的最终显隐、倍率、偏移和状态，不先调用单击 |
| IC-059 G3 | 旧断言验证第二击撤销首击 | 断言双击不应用也不撤销单击，显隐保持初值 |
| IC-059 G4 | 方法名和语义依赖“窗口外”自建判断 | 断言两个独立 UIKit 单击回调各执行一次且不缩放 |
| IC-059 F3 | “框显照片显隐态尺寸和圆角相等”被决策 18 取代 | 仅对非框显照片断言显隐态尺寸和圆角严格相等；S1、S2、S4 断言框显照片差异与不变量 |
| IC-059 H1 | 旧规则要求缩略图与左右分页都触觉一次 | 断言缩略图变化触觉一次，普通分页多次成功换片仍为零次 |
| IC-059 H2 | 旧测试向分页控制器注入触觉回调，该入口已删除 | 断言关闭参数后缩略图变化为零，并由 A1 覆盖分页恒为零 |
| 既有 V4 | 旧断言要求所有界面状态共享相同 1x 尺寸 | 改为 `testV4ReplacementPresentationStatesPreserveViewportAndZoomBaselines`，断言视口、aspect-fit、填满倍数和双击目标不变 |
| 既有 L7 部分默认值 | 旧完整配置锁定 `doubleTapDecisionWindowMilliseconds=320` 且无截图沉浸字段 | 更新为 200 和 `screenshotImmersiveOnHide=true`，其余既有默认值保持不变 |

原 `testA1AnimationPolicyDisablesCalibratedAnimations` 的断言并未失效，但为了给本卡 A1
保留准确编号，重命名为 `testIC055AnimationPolicyDisablesCalibratedAnimations`；断言内容不变。

未失效并继续保留的指定项目：G1～G2、M1～M2、F1～F2、F4、B1～B3、N1～N8、
E5～E6、D1～D8。上滑标记、下滑取消、图像请求策略、分页间距和倍率基准均未改动。

## 6. 参数导出样例

```text
taskID=IC-20260815-060-tap-arbitration-and-screenshot-immersive
doubleTapDecisionWindowMilliseconds=200.000000
fitInsetRatio=0.300000
fitCornerRadius=28.000000
fitInsetScope=screenAspectOnly
screenshotImmersiveOnHide=true
pageSpacing=20.000000
hapticOnPhotoSwitch=true
```

## 7. 自验脚本与本地结果

执行命令：

```powershell
.\Scripts\verify-IC-20260815-060.ps1
```

脚本检查独立分支与继承提交、`main` 固定点、354 项静态测试门槛、K/S/A 十三项、全部
指定回归、UIKit 失败依赖、旧撤销路径清除、参数实际诊断接线、截图集合/尺寸/圆角/动画、
触觉来源、出厂值、参数导出、变更白名单、禁止文件、`debugAssetLimit`、
`git diff --check`、String Catalog 与仓库结构门禁。

当前 Windows 本地结果：专项脚本 106 项检查全部通过，静态 XCTest 总数 354；String
Catalog 扫描通过，用户可见硬编码残留 0；`git diff --check` 与仓库结构门禁通过。当前
Windows 环境没有 Xcode，因此没有伪称本地执行 XCTest；实际 XCTest 交由 macOS CI。

## 8. CI、XCTest 与 IPA

- CI run：首次实现提交推送后更新。
- 被测提交：首次实现提交推送后更新。
- 测试总数：静态 354；CI 实际执行数待更新。
- CI 结论：待 macOS CI 实际执行。
- XCTest 日志原文：尚未产生。
- IPA artifact：待 CI 生成。
- IPA SHA-256：待 artifact 下载后独立复核。

## 9. 变更文件清单

1. `PhotoCleanupMVE/Core/S2StateMachine.swift`
2. `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
3. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
4. `PhotoCleanupMVE/Features/S2/S2View.swift`
5. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
6. `Scripts/verify-IC-20260815-060.ps1`
7. `selfcheck_IC-060_report.md`

清单不含任何 `SPEC-*.md`、`Decision_log.md`、S1、S3、S4、S5 或
`CleanupCoordinator.swift`。

## 10. 执行边界声明

- 基线：`b58cb2be94953ab58cb07ea06ab34cbcc238eb46`（IC-059 交付分支头）。
- 独立分支：`feature/ic-060-tap-and-immersive`。
- `main` 与 `origin/main` 保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- 未修改任何规格、决策日志、S1/S3/S4/S5、上滑/下滑阈值和语义、图像请求策略默认值、
  `fitInsetRatio`、`fitCornerRadius`、`minDoubleTapScale`、`pageSpacing` 或
  `debugAssetLimit`。
- 未合并主干、未 force push、未操作账号。
- 网络仅用于 Apple 官方 API 文档核验、推送、CI 查询和最终 artifact 下载；未向第三方
  地址传输照片、凭证、Cookie、Token 或其他用户数据。
