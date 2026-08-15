# IC-20260815-054 自验报告

## 1. 当前结论

本地静态自验已通过；Xcode 编译、全量 XCTest、CI run 与 IPA artifact 信息待首次推送后回填。

## 2. V1～V8

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| V1 | `testV1InterfaceVisibilityKeepsViewportSizeEqual` | 本地静态检查通过，CI 待回填 |
| V2 | `testV2BottomStripStatesKeepViewportSizeAndHeightEqual` | 本地静态检查通过，CI 待回填 |
| V3 | `testV3SheetPresentationKeepsViewportSizeEqual` | 本地静态检查通过，CI 待回填 |
| V4 | `testV4AllPresentationStatesShareFitAndDoubleTapMultiplier` | 本地静态检查通过，CI 待回填 |
| V5 | `testV5ParametersSurviveProcessModelRestart` | 本地静态检查通过，CI 待回填 |
| V6 | `testV6AllFourImageRequestStrategiesTakeEffectImmediately` | 本地静态检查通过，CI 待回填 |
| V7 | `testV7MissingAspectCategoryReturnsExplicitEmptyResult` | 本地静态检查通过，CI 待回填 |
| V8 | `testV8FitInsetRatioGeometryAndScopeAreCorrect` | 本地静态检查通过，CI 待回填 |

- 上游基线 XCTest：280
- 本卡新增 XCTest：8
- 当前静态 XCTest 总数：288

## 3. 参数导出格式

导出结果是 UTF-8 纯文本。首三行依次给出格式版本、任务标识和值状态，其余各行均为
`字段名=值`；字段顺序固定，浮点数固定保留六位小数，便于人工记录及逐次比较。

出厂占位值样例：

```text
schemaVersion=1
taskID=IC-20260815-054-s2-calibration-harness
valueStatus=未标定：以下值均为出厂占位值或人工调参值，不是推荐默认值
pinchMaxScale=4.000000
zoomSnapBackThreshold=1.100000
aspectFillDegenerateTolerancePercent=1.000000
aspectFillDegenerateTargetScale=2.000000
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
scaleChangeRequestPolicy=everyScaleChange
degradedPreviewPolicy=finalImageOnly
animationsEnabled=false
animationDurationMilliseconds=0.000000
fitInsetRatio=0.000000
fitInsetScope=screenAspectOnly
bottomStripCurrentItemSize=72.000000
bottomStripNeighborItemWidth=52.000000
bottomStripNeighborItemHeight=44.000000
bottomStripItemSpacing=8.000000
bottomStripEdgeFadeWidth=24.000000
bottomStripDragMinimumDistance=4.000000
bottomStripSwitchDistance=44.000000
```

## 4. 变更文件清单

- `PhotoCleanupMVE.xcodeproj/project.pbxproj`
- `PhotoCleanupMVE/App/CleanupCoordinator.swift`
- `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`
- `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift`
- `PhotoCleanupMVE/Features/S2/S2View.swift`
- `PhotoCleanupMVE/Localizable.xcstrings`
- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
- `Scripts/verify-IC-20260815-054.ps1`
- `selfcheck_IC-054_report.md`

清单不含任何 `SPEC-*.md` 或 `Decision_log.md`，也不含 S1、S3、S4、S5 的视觉或行为文件。

## 5. CI 与 IPA

- CI run：待回填
- CI 结论：待回填
- XCTest：待回填
- IPA artifact：待回填
- IPA SHA-256：待回填

## 6. 执行边界

- 开发基线：`bccc2d2deadf37da470b9270f25ecb0312e6d4de`
- 开发分支：`feature/ic-054-calibration-harness`
- IC-054 commit 数：待最终回填
- push 次数：待最终回填
- push 目标：仅 `origin/feature/ic-054-calibration-harness`
- 合并 `main`：未执行
- force push：未执行
- 账号操作：未执行
- `debugAssetLimit`：保持 `300`，未清理、未接回流程
