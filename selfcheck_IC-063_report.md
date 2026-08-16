# IC-20260816-063 全屏沉浸与原生缩放退出自验报告

## 1. 当前结论

IC-063 已在独立分支 `feature/ic-063-immersive-fullscreen` 完成代码与 6 项专项 XCTest。
Windows 本地静态门禁已通过；XCTest、Release 真机目标构建、可下载 IPA 与哈希等待 CI
实际执行后回填。本报告当前测试总数目标为 369 项，最终结论以无占位符版本为准。

## 2. 第 2 条根因诊断

根因分类是：**填满计算基准取错**。

屏幕比例判定本身已经命中，且判定允许照片与视口方向归一后的宽高比存在 1% 容差；旧实现
命中后在隐藏态去掉 30% 内缩，却仍以 `aspectFitSize` 作为 `oneXDisplaySize`。只要照片比例
位于容差内但不与视口完全相等，等比适配就只会让一个轴贴边，另一个轴仍小于视口，因此
“命中”并不等于“两轴显示尺寸都等于视口”。这不是 safe area 参与计算，也不是判定未命中，
更不是动画完成提交了错误端点。

修复后，命中且 `V=隐藏`、`screenshotImmersiveOnHide=true` 时直接以全屏物理视口尺寸作为
目标显示尺寸；过渡按横纵两个目标倍率完成，动画结束仍沿用 IC-061 的无动画一次性提交入口。

## 3. 实现摘要

- `V=隐藏` 时状态栏隐藏，`V=显示` 时恢复；状态栏状态使用与截图沉浸相同的
  `S2AnimationPolicy` 线性时长更新，不会先跳变后再启动照片动画。
- 命中屏幕比例判定的照片在隐藏态直接使用视口宽高，圆角为 0；未命中照片的两态尺寸与
  圆角路径未改。
- 容差内但比例不完全相同的命中照片使用 `scaleX`、`scaleY` 到达严格视口终点，避免动画完成
  时补写未到达的另一轴。
- 双击退出 Nx 与捏合低于吸附阈值归位共同进入一个原生调用：
  `setZoomScale(minimumZoomScale, animated: true)`。该入口不写 `contentOffset`，原生滚动视图
  同时收敛倍率与偏移。
- 原生动画结束后的 IC-061 延迟呈现提交顺序保持不变。

## 4. IC-063 专项测试

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| Y1 | `testY1StatusBarTracksHiddenAndVisibleInterfaceStates` | __CI_STATUS__ |
| Y2 | `testY2MatchedPhotoHiddenDisplayStrictlyEqualsViewportAndHasZeroRadius` | __CI_STATUS__ |
| Y3 | `testY3NonMatchingPhotoGeometryRemainsUnchangedInBothVisibilityStates` | __CI_STATUS__ |
| Y4 | `testY4DoubleTapExitUsesSingleNativeMinimumZoomAnimationWithoutOffsetWrite` | __CI_STATUS__ |
| Y5 | `testY5PinchSnapBackUsesSameSingleNativeMinimumZoomAnimationPath` | __CI_STATUS__ |
| Y6 | `testY6ZoomExitCompletionNormalizesStateAndAppliesCurrentPresentation` | __CI_STATUS__ |

## 5. IC-061 X1～X8 回归

X1～X8 均未失效，测试方法未删除、未改名；严格全视口 fixture 由 Y2 增补，原有完全等比
fixture 的中心锚点、布局延迟提交与圆角连续断言仍成立。

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| X1 | `testX1ImmersiveTransitionUsesViewportCenterAnchoredScaleTransform` | __CI_STATUS__ |
| X2 | `testX2ImmersiveTransitionKeepsLayoutSizeAndUsesTransform` | __CI_STATUS__ |
| X3 | `testX3CornerRadiusInterpolatesContinuouslyInBothDirections` | __CI_STATUS__ |
| X4 | `testX4DisabledAnimationsReachEndpointWithoutTransition` | __CI_STATUS__ |
| X5 | `testX5NxVisibilityTogglePreservesAllNativeGeometry` | __CI_STATUS__ |
| X6 | `testX6NxDeferredPresentationAppliesOnceAfterReturningToOneX` | __CI_STATUS__ |
| X7 | `testX7NxExitWithoutVisibilityToggleKeepsExistingBehavior` | __CI_STATUS__ |
| X8 | `testX8ImmersiveAnimationIssuesZeroImageRequests` | __CI_STATUS__ |
| 补充 | `testIC061NxPinchEndedStillUpdatesImageRequestWithoutPresentationChange` | __CI_STATUS__ |

## 6. IC-060 指定回归

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| K1 | `testK1SingleTapRequiresDoubleTapRecognizerToFail` | __CI_STATUS__ |
| K2 | `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | __CI_STATUS__ |
| K3 | `testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce` | __CI_STATUS__ |
| K4 | `testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds` | __CI_STATUS__ |
| S1 | `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | __CI_STATUS__ |
| S2 | `testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius` | __CI_STATUS__（替代断言） |
| S3 | `testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates` | __CI_STATUS__ |
| S4 | `testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget` | __CI_STATUS__ |
| S5 | `testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden` | __CI_STATUS__ |
| S6 | `testS6ScreenshotImmersiveFactoryDefaultIsTrue` | __CI_STATUS__ |
| A1 | `testA1NativePagingPhotoSwitchProducesNoHaptic` | __CI_STATUS__ |
| A2 | `testA2BottomStripCurrentItemChangesProduceExactlyNHaptics` | __CI_STATUS__ |
| A3 | `testA3DisabledPhotoSwitchHapticProducesNoHaptic` | __CI_STATUS__ |

## 7. 更早指定回归

| 来源 | XCTest 方法 | 状态 |
|---|---|---|
| IC-059 G1 | `testG1OneXSwipeUpMarksCurrentAsset` | __CI_STATUS__ |
| IC-059 G2 | `testG2NxSwipeUpMarksCurrentAsset` | __CI_STATUS__ |
| IC-059 G3 | `testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap` | __CI_STATUS__ |
| IC-059 G4 | `testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom` | __CI_STATUS__ |
| IC-059 M1 | `testM1ScreenAspectDoubleTapUsesMinimumScale` | __CI_STATUS__ |
| IC-059 M2 | `testM2NonScreenPhotoDoubleTapUsesAspectFillScale` | __CI_STATUS__ |
| IC-059 F1 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | __CI_STATUS__ |
| IC-059 F2 | `testF2CornerRadiusAppliesOnlyToInsetPhotos` | __CI_STATUS__ |
| IC-059 F3 | `testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility` | __CI_STATUS__ |
| IC-059 F4 | `testF4InsetDoesNotChangeViewportOrAspectFillMultiplier` | __CI_STATUS__ |
| IC-059 B1 | `testB1NxBoundaryContinuationProducesPagingDisplacement` | __CI_STATUS__ |
| IC-059 B2 | `testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex` | __CI_STATUS__ |
| IC-059 B3 | `testB3NxBoundaryPagingCompletionResetsNewPhotoScale` | __CI_STATUS__ |
| IC-059 H1 | `testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges` | __CI_STATUS__ |
| IC-059 H2 | `testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire` | __CI_STATUS__ |
| IC-058 N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | __CI_STATUS__ |
| IC-058 N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | __CI_STATUS__ |
| IC-058 N3 | `testN3NativePagingUsesConfiguredPageSpacing` | __CI_STATUS__ |
| IC-058 N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | __CI_STATUS__ |
| IC-058 N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | __CI_STATUS__ |
| IC-058 N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | __CI_STATUS__ |
| IC-058 N7 | `testN7NativePageChangeResetsZoomToOne` | __CI_STATUS__ |
| IC-058 N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | __CI_STATUS__ |
| IC-057 E1 | `testE1ReplacementSingleTapRunsAfterDoubleTapFailure` | __CI_STATUS__ |
| IC-057 E2 | `testE2ReplacementDoubleTapSuppressesSingleTapAction` | __CI_STATUS__ |
| IC-057 E3 | `testE3ReplacementTwoResolvedSingleTapsToggleTwice` | __CI_STATUS__ |
| IC-057 E4 | `testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap` | __CI_STATUS__ |
| IC-057 E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | __CI_STATUS__ |
| IC-057 E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | __CI_STATUS__ |
| IC-056 D1 | `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | __CI_STATUS__ |
| IC-056 D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | __CI_STATUS__ |
| IC-056 D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | __CI_STATUS__ |
| IC-056 D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | __CI_STATUS__ |
| IC-056 D5 | `testD5ReplacementNonScreenDoubleTapUsesAspectFillScale` | __CI_STATUS__ |
| IC-056 D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | __CI_STATUS__ |
| IC-056 D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | __CI_STATUS__ |
| IC-056 D8 | `testD8DoubleTapExitResetsScaleAndOffset` | __CI_STATUS__ |
| 既有 V4 | `testV4ReplacementPresentationStatesPreserveViewportAndZoomBaselines` | __CI_STATUS__ |

CI 将实际执行全部 369 项 XCTest，以覆盖其余既有回归。

## 8. 失效项清单与替代断言

| 失效项 | 失效原因 | 替代断言 |
|---|---|---|
| IC-060 S2 的 `hidden.oneXDisplaySize == hidden.aspectFitSize`、两轴不超过视口且至少一轴贴边 | 本卡要求命中照片隐藏态两轴都严格等于视口；旧断言只能保证等比适配单轴贴边，与新契约直接冲突 | 保留原测试方法名，替换为宽高分别在 1pt 容差内等于视口且圆角为 0；Y2 另用 0.8% 比例差 fixture 证明判定命中并覆盖控制器最终提交 |
| 既有 L7 任务标识字符串 | 参数导出追踪标识须从 IC-061 更新为 IC-063；它不是行为参数出厂值 | 完整配置对象相等断言原样保留，仅把 `taskID` 期望替换为 `IC-20260816-063-immersive-fullscreen-and-zoomout` |

没有删除 XCTest。IC-061 X1～X8 均未失效；IC-060 其余 K/S/A 与更早指定回归断言未改。

## 9. 参数出厂值核对

自验脚本直接提取 `factoryPlaceholder` 初始化块并与 IC-061 交付提交
`456c93d1ccc0e8a91b8188a9322614ea0205b156` 比较，要求字节级一致。仅导出追踪 `taskID`
更新；参数值、触觉阈值、手势阈值、图像请求策略均未改。

## 10. 自验脚本与本地结果

执行命令：

```powershell
.\Scripts\verify-IC-20260816-063.ps1 -允许待回填CI
```

Windows 本地专项脚本 107 项检查全部通过，静态 XCTest 总数 369；仓库结构门禁、String
Catalog 扫描、用户可见硬编码扫描和 `git diff --check` 均通过，硬编码残留为 0。

Windows 环境没有 Xcode，因此本地不声称执行了 XCTest；XCTest 只以 CI 的真实日志为准。

## 11. CI、XCTest 与 IPA

- 工作流：__CI_RUN_LINK__
- 作业：__CI_JOB_LINK__
- 被测提交：`__CI_COMMIT__`
- 环境：macOS 15、Xcode 16.4、iPhone 模拟器、iOS SDK 18.5
- 结论：__CI_CONCLUSION__

原始作业日志：

```text
__EXECUTED_LINE__
__TEST_SUCCEEDED_LINE__
__BUILD_SUCCEEDED_LINE__
```

IPA artifact：

- 下载：__IPA_ARTIFACT_LINK__
- artifact ID：`__IPA_ARTIFACT_ID__`
- artifact ZIP 字节数：__ARTIFACT_ZIP_SIZE__
- artifact ZIP SHA-256：`__ARTIFACT_ZIP_SHA256__`
- 包内文件：`PhotoCleanupMVE-unsigned.ipa`
- IPA 字节数：__IPA_SIZE__
- IPA SHA-256：`__IPA_SHA256__`
- 结构校验：__IPA_STRUCTURE_RESULT__

## 12. 变更文件清单

1. `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
2. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
3. `PhotoCleanupMVE/Features/S2/S2View.swift`
4. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
5. `Scripts/verify-IC-20260816-063.ps1`
6. `selfcheck_IC-063_report.md`

清单不含任何 `SPEC-*.md`、`Decision_log.md`、S1、S3、S4、S5、图像请求实现、CI 工作流或
`CleanupCoordinator.swift`。

## 13. v14 条款关系

v14 明确锁定“主图视口为含安全区在内的全屏物理边界”和“命中照片隐藏态完整填满视口”，
但没有锁定系统状态栏必须保持显示。因此本卡新增的状态栏随 V 显隐不与 v14 明文条款冲突，
并使 v14 的全屏物理视口观感成立；规格文件本身未修改。

## 14. 执行边界声明

- 基线：`456c93d1ccc0e8a91b8188a9322614ea0205b156`（IC-061 交付分支头）。
- 独立分支：`feature/ic-063-immersive-fullscreen`。
- `main` 与 `origin/main` 均保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- 未修改规格、决策日志、S1/S3/S4/S5、上滑标记、下滑取消、翻页、触觉语义与阈值、任何
  参数出厂值、视频或 Live Photo 行为、账号或 `debugAssetLimit`。
- 未合并主干、未 force push、未操作账号。
- 网络只用于已授权的独立分支推送、同一仓库 CI 查询与 artifact 下载；不会发送照片、
  Cookie、Token 或其他用户数据，凭证不会输出或落盘。
