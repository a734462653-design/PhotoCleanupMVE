# IC-20260816-063 全屏沉浸与原生缩放退出自验报告

## 1. 当前结论

IC-063 已完成并推送到独立分支。最终验收运行 [CI #62](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31949114411)
在 macOS 15、Xcode 16.4、iPhone 模拟器上实际执行 369 项 XCTest，零失败；Y1～Y6、
IC-061 X1～X8 与全部更早指定回归均通过。Release 真机目标构建成功，未签名 IPA artifact
已上传并可下载，包内 IPA 的 SHA-256 为
`2ba22f9902acd1cc10f365304eda17cb17f9df75fd8dea5218c59bc5d53b26b8`。

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
| Y1 | `testY1StatusBarTracksHiddenAndVisibleInterfaceStates` | CI #62 通过 |
| Y2 | `testY2MatchedPhotoHiddenDisplayStrictlyEqualsViewportAndHasZeroRadius` | CI #62 通过 |
| Y3 | `testY3NonMatchingPhotoGeometryRemainsUnchangedInBothVisibilityStates` | CI #62 通过 |
| Y4 | `testY4DoubleTapExitUsesSingleNativeMinimumZoomAnimationWithoutOffsetWrite` | CI #62 通过 |
| Y5 | `testY5PinchSnapBackUsesSameSingleNativeMinimumZoomAnimationPath` | CI #62 通过 |
| Y6 | `testY6ZoomExitCompletionNormalizesStateAndAppliesCurrentPresentation` | CI #62 通过 |

## 5. IC-061 X1～X8 回归

X1～X8 均未失效，测试方法未删除、未改名；严格全视口 fixture 由 Y2 增补，原有完全等比
fixture 的中心锚点、布局延迟提交与圆角连续断言仍成立。

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| X1 | `testX1ImmersiveTransitionUsesViewportCenterAnchoredScaleTransform` | CI #62 通过 |
| X2 | `testX2ImmersiveTransitionKeepsLayoutSizeAndUsesTransform` | CI #62 通过 |
| X3 | `testX3CornerRadiusInterpolatesContinuouslyInBothDirections` | CI #62 通过 |
| X4 | `testX4DisabledAnimationsReachEndpointWithoutTransition` | CI #62 通过 |
| X5 | `testX5NxVisibilityTogglePreservesAllNativeGeometry` | CI #62 通过 |
| X6 | `testX6NxDeferredPresentationAppliesOnceAfterReturningToOneX` | CI #62 通过 |
| X7 | `testX7NxExitWithoutVisibilityToggleKeepsExistingBehavior` | CI #62 通过 |
| X8 | `testX8ImmersiveAnimationIssuesZeroImageRequests` | CI #62 通过 |
| 补充 | `testIC061NxPinchEndedStillUpdatesImageRequestWithoutPresentationChange` | CI #62 通过 |

## 6. IC-060 指定回归

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| K1 | `testK1SingleTapRequiresDoubleTapRecognizerToFail` | CI #62 通过 |
| K2 | `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | CI #62 通过 |
| K3 | `testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce` | CI #62 通过 |
| K4 | `testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds` | CI #62 通过 |
| S1 | `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | CI #62 通过 |
| S2 | `testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius` | CI #62 通过（替代断言） |
| S3 | `testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates` | CI #62 通过 |
| S4 | `testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget` | CI #62 通过 |
| S5 | `testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden` | CI #62 通过 |
| S6 | `testS6ScreenshotImmersiveFactoryDefaultIsTrue` | CI #62 通过 |
| A1 | `testA1NativePagingPhotoSwitchProducesNoHaptic` | CI #62 通过 |
| A2 | `testA2BottomStripCurrentItemChangesProduceExactlyNHaptics` | CI #62 通过 |
| A3 | `testA3DisabledPhotoSwitchHapticProducesNoHaptic` | CI #62 通过 |

## 7. 更早指定回归

| 来源 | XCTest 方法 | 状态 |
|---|---|---|
| IC-059 G1 | `testG1OneXSwipeUpMarksCurrentAsset` | CI #62 通过 |
| IC-059 G2 | `testG2NxSwipeUpMarksCurrentAsset` | CI #62 通过 |
| IC-059 G3 | `testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap` | CI #62 通过 |
| IC-059 G4 | `testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom` | CI #62 通过 |
| IC-059 M1 | `testM1ScreenAspectDoubleTapUsesMinimumScale` | CI #62 通过 |
| IC-059 M2 | `testM2NonScreenPhotoDoubleTapUsesAspectFillScale` | CI #62 通过 |
| IC-059 F1 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | CI #62 通过 |
| IC-059 F2 | `testF2CornerRadiusAppliesOnlyToInsetPhotos` | CI #62 通过 |
| IC-059 F3 | `testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility` | CI #62 通过 |
| IC-059 F4 | `testF4InsetDoesNotChangeViewportOrAspectFillMultiplier` | CI #62 通过 |
| IC-059 B1 | `testB1NxBoundaryContinuationProducesPagingDisplacement` | CI #62 通过 |
| IC-059 B2 | `testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex` | CI #62 通过 |
| IC-059 B3 | `testB3NxBoundaryPagingCompletionResetsNewPhotoScale` | CI #62 通过 |
| IC-059 H1 | `testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges` | CI #62 通过 |
| IC-059 H2 | `testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire` | CI #62 通过 |
| IC-058 N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | CI #62 通过 |
| IC-058 N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | CI #62 通过 |
| IC-058 N3 | `testN3NativePagingUsesConfiguredPageSpacing` | CI #62 通过 |
| IC-058 N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | CI #62 通过 |
| IC-058 N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | CI #62 通过 |
| IC-058 N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | CI #62 通过 |
| IC-058 N7 | `testN7NativePageChangeResetsZoomToOne` | CI #62 通过 |
| IC-058 N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | CI #62 通过 |
| IC-057 E1 | `testE1ReplacementSingleTapRunsAfterDoubleTapFailure` | CI #62 通过 |
| IC-057 E2 | `testE2ReplacementDoubleTapSuppressesSingleTapAction` | CI #62 通过 |
| IC-057 E3 | `testE3ReplacementTwoResolvedSingleTapsToggleTwice` | CI #62 通过 |
| IC-057 E4 | `testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap` | CI #62 通过 |
| IC-057 E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | CI #62 通过 |
| IC-057 E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | CI #62 通过 |
| IC-056 D1 | `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | CI #62 通过 |
| IC-056 D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | CI #62 通过 |
| IC-056 D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | CI #62 通过 |
| IC-056 D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | CI #62 通过 |
| IC-056 D5 | `testD5ReplacementNonScreenDoubleTapUsesAspectFillScale` | CI #62 通过 |
| IC-056 D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | CI #62 通过 |
| IC-056 D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | CI #62 通过 |
| IC-056 D8 | `testD8DoubleTapExitResetsScaleAndOffset` | CI #62 通过 |
| 既有 V4 | `testV4ReplacementPresentationStatesPreserveViewportAndZoomBaselines` | CI #62 通过 |

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
.\Scripts\verify-IC-20260816-063.ps1
```

Windows 本地专项脚本 111 项检查全部通过，静态 XCTest 总数 369；仓库结构门禁、String
Catalog 扫描、用户可见硬编码扫描和 `git diff --check` 均通过，硬编码残留为 0。

Windows 环境没有 Xcode，因此本地不声称执行了 XCTest；XCTest 只以 CI 的真实日志为准。

## 11. CI、XCTest 与 IPA

- 工作流：[CI #62](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31949114411)
- 作业：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31949114411/job/95169700409)
- 被测提交：`b5a6811a8e63a936ff56e54d7097a324f192c31e`
- 环境：macOS 15、Xcode 16.4、iPhone 模拟器、iOS SDK 18.5
- 结论：9 个 CI 步骤全部成功；结构门禁、硬编码门禁、369 项 XCTest、Release 真机目标
  构建、IPA 校验与 artifact 上传均通过。

原始作业日志：

```text
2026-08-16T13:14:04.0074900Z 	 Executed 369 tests, with 0 failures (0 unexpected) in 13.744 (36.064) seconds
2026-08-16T13:14:04.0880900Z ** TEST SUCCEEDED **
2026-08-16T13:14:35.4155910Z ** BUILD SUCCEEDED **
```

IPA artifact：

- 下载：[PhotoCleanupMVE-unsigned-b5a6811a8e63](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31949114411/artifacts/9264165613)
- artifact ID：`9264165613`
- artifact ZIP 字节数：583611
- artifact ZIP SHA-256：`7a0dd7e5c016528af0922425341e19f0e74eb26d3531bdd72a211b937256c22b`
- 包内文件：`PhotoCleanupMVE-unsigned.ipa`
- IPA 字节数：583441
- IPA SHA-256：`2ba22f9902acd1cc10f365304eda17cb17f9df75fd8dea5218c59bc5d53b26b8`
- 结构校验：通过。IPA 共 8 个 ZIP 条目，包含 `Payload/PhotoCleanupMVE.app/Info.plist`
  和应用可执行文件；没有绝对路径、路径穿越、反斜线、符号链接、签名目录或描述文件。

已把 artifact 下载到本地并独立复算 ZIP 与 IPA 两层哈希；结果与 CI 公布的 IPA 字节数和
SHA-256 完全一致。由于本卡禁止操作账号，产物沿用 IC-061 的未签名约定，可交给既有
签名／侧载流程安装，不能在未签名状态下直接安装到普通真机。

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
- CI #62 实际测试的业务与测试提交为 `b5a6811a8e63a936ff56e54d7097a324f192c31e`；
  此后的报告回填提交只修改本报告并使用 `[skip ci]`，不改变验收源码。
- `main` 与 `origin/main` 均保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- 未修改规格、决策日志、S1/S3/S4/S5、上滑标记、下滑取消、翻页、触觉语义与阈值、任何
  参数出厂值、视频或 Live Photo 行为、账号或 `debugAssetLimit`。
- 未合并主干、未 force push、未操作账号。
- 网络只用于已授权的独立分支推送、同一仓库 CI 查询与 artifact 下载；不会发送照片、
  Cookie、Token 或其他用户数据，凭证不会输出或落盘。
