# IC-20260815-060 点击裁决、截图沉浸与触觉反馈自验报告

## 1. 当前结论

IC-060 的代码、13 项新增 XCTest、自验脚本与回归替代断言均已完成。Windows 本地静态
门禁通过，XCTest 总数由 IC-059 的 341 项增加为 354 项。macOS CI #53 已实际执行全部
354 项 XCTest，结果为 0 failures、0 unexpected；Release 真机构建、未签名 IPA 生成和
artifact 上传也全部成功。最终 artifact 已下载并独立复核，IPA SHA-256 与 CI 原文一致。

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

| 编号 | XCTest 方法 | CI #53 状态 |
|---|---|---|
| K1 | `testK1SingleTapRequiresDoubleTapRecognizerToFail` | 通过 |
| K2 | `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | 通过 |
| K3 | `testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce` | 通过 |
| K4 | `testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds` | 通过 |
| S1 | `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | 通过 |
| S2 | `testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius` | 通过 |
| S3 | `testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates` | 通过 |
| S4 | `testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget` | 通过 |
| S5 | `testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden` | 通过 |
| S6 | `testS6ScreenshotImmersiveFactoryDefaultIsTrue` | 通过 |
| A1 | `testA1NativePagingPhotoSwitchProducesNoHaptic` | 通过 |
| A2 | `testA2BottomStripCurrentItemChangesProduceExactlyNHaptics` | 通过 |
| A3 | `testA3DisabledPhotoSwitchHapticProducesNoHaptic` | 通过 |

S2 还在同一测试内断言：开启动画时显隐过渡时长为出厂值 0.18 秒；关闭动画时记录时长为
0 并直接切换。

## 4. 指定回归测试

### 4.1 IC-059 G1～G4、M1～M2、F1～F4、B1～B3、H1～H2

| 编号 | XCTest 方法 | CI #53 状态 |
|---|---|---|
| G1 | `testG1OneXSwipeUpMarksCurrentAsset` | 通过 |
| G2 | `testG2NxSwipeUpMarksCurrentAsset` | 通过 |
| G3 | `testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap` | 通过（替代断言） |
| G4 | `testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom` | 通过（替代断言） |
| M1 | `testM1ScreenAspectDoubleTapUsesMinimumScale` | 通过 |
| M2 | `testM2NonScreenPhotoDoubleTapUsesAspectFillScale` | 通过 |
| F1 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | 通过 |
| F2 | `testF2CornerRadiusAppliesOnlyToInsetPhotos` | 通过 |
| F3 | `testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility` | 通过（替代断言） |
| F4 | `testF4InsetDoesNotChangeViewportOrAspectFillMultiplier` | 通过 |
| B1 | `testB1NxBoundaryContinuationProducesPagingDisplacement` | 通过 |
| B2 | `testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex` | 通过 |
| B3 | `testB3NxBoundaryPagingCompletionResetsNewPhotoScale` | 通过 |
| H1 | `testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges` | 通过（替代断言） |
| H2 | `testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire` | 通过（替代断言） |

### 4.2 IC-058 N1～N8

| 编号 | XCTest 方法 | CI #53 状态 |
|---|---|---|
| N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | 通过 |
| N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | 通过 |
| N3 | `testN3NativePagingUsesConfiguredPageSpacing` | 通过 |
| N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | 通过 |
| N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | 通过 |
| N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | 通过 |
| N7 | `testN7NativePageChangeResetsZoomToOne` | 通过 |
| N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | 通过 |

### 4.3 IC-057 E1～E6

| 编号 | XCTest 方法 | CI #53 状态 |
|---|---|---|
| E1 | `testE1ReplacementSingleTapRunsAfterDoubleTapFailure` | 通过（替代断言） |
| E2 | `testE2ReplacementDoubleTapSuppressesSingleTapAction` | 通过（替代断言） |
| E3 | `testE3ReplacementTwoResolvedSingleTapsToggleTwice` | 通过（替代断言） |
| E4 | `testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap` | 通过（替代断言） |
| E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | 通过 |
| E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | 通过 |

### 4.4 IC-056 D1～D8

| 编号 | XCTest 方法 | CI #53 状态 |
|---|---|---|
| D1 | `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | 通过 |
| D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | 通过 |
| D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | 通过 |
| D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | 通过 |
| D5 | `testD5ReplacementNonScreenDoubleTapUsesAspectFillScale` | 通过 |
| D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | 通过 |
| D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | 通过 |
| D8 | `testD8DoubleTapExitResetsScaleAndOffset` | 通过 |

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

Windows 本地结果：专项脚本 106 项检查全部通过，静态 XCTest 总数 354；String Catalog
扫描通过，用户可见硬编码残留 0；`git diff --check` 与仓库结构门禁通过。当前 Windows
环境没有 Xcode，因此没有伪称本地执行 XCTest；实际 XCTest 已由 macOS CI #53 完成。

## 8. CI、XCTest 与 IPA

- CI run：[iOS 构建与自验 #53](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31931934877)。
- CI job：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31931934877/job/95127995271)。
- 被测提交：`12b0b0b1d51961c64c69e559e396649a1046630d`。
- CI 环境：`macos-15`、Xcode 16.4、iPhone 模拟器。
- 测试总数：354；十三项专项测试逐项通过，指定 37 项回归逐项通过。
- CI 结论：`completed/success`；结构自验、硬编码扫描、XCTest、Release 真机构建和
  artifact 上传全部成功。
- XCTest 日志原文：

```text
2026-08-16T06:46:55.6453650Z 	 Executed 354 tests, with 0 failures (0 unexpected) in 10.168 (16.514) seconds
2026-08-16T06:46:59.5157200Z ** TEST SUCCEEDED **
```

收敛记录：CI #52 首次实际执行本卡测试时，A2 测试夹具提供 8 个资源标识却把
`totalAssetCount` 写死为 3，状态机前置条件令该测试初始化失败；产品实现和其他测试没有
触发该问题。提交 `12b0b0b` 仅把夹具总数改为 `orderedAssetIDs.count`。CI #53 随后完整
执行 354 项并全绿，没有删除测试、降低数量门槛或放宽触觉次数断言。

### 8.1 IPA artifact

- artifact：[PhotoCleanupMVE-unsigned-12b0b0b1d519](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31931934877/artifacts/9259634362)。
- artifact ID：`9259634362`；归档字节数：573820；到期时间：2026-11-14 06:39:22 UTC。
- artifact 归档 SHA-256：`13e7df5c560b6615c7b4eb7c9ef0dcf0b6eccf487e6938e9c5db52e8e1575277`。
- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`；字节数：573650。
- IPA SHA-256：`128916ddc7469d993a0199d791fac771bfce1039da653b7c6e820d4c59f01433`。
- 独立复核：下载后的 artifact 只含唯一预期 IPA，外层归档 SHA-256 与 GitHub 元数据
  digest 一致；IPA 含 `Payload/PhotoCleanupMVE.app/Info.plist` 与主二进制，共 8 个条目，
  路径穿越条目、签名目录和描述文件均为 0；本地重算 IPA SHA-256 与 CI 构建日志一致。

CI 按仓库既有流程构建 Release 真机应用并封装为未签名 IPA，不包含开发者账号、设备绑定或
描述文件。任务禁止账号操作，因此不生成绑定具体账号的签名包；artifact 可下载且 IPA 结构
有效，在普通未越狱真机上安装前仍需由用户既有签名／侧载链路签名，本任务不冒充完成账号
签名。

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
- 实现提交：`d1c3c3687f62d9eb4fde642a13325c9c1eb9ec0b`；A2 夹具修复提交：
  `12b0b0b1d51961c64c69e559e396649a1046630d`，CI #53 对后者实际验收。
- `main` 与 `origin/main` 保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- 未修改任何规格、决策日志、S1/S3/S4/S5、上滑/下滑阈值和语义、图像请求策略默认值、
  `fitInsetRatio`、`fitCornerRadius`、`minDoubleTapScale`、`pageSpacing` 或
  `debugAssetLimit`。
- 未合并主干、未 force push、未操作账号。
- 网络仅用于 Apple 官方 API 文档核验、推送、CI 查询和最终 artifact 下载；未向第三方
  地址传输照片、凭证、Cookie、Token 或其他用户数据。
