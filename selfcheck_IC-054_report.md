# IC-20260815-054 自验报告

## 1. 当前结论

IC-054 已完成。最终功能提交 `90b61c067b1a3e3cb93874cf6078e0438c3719ab` 在 CI #36
完成全量编译、288 项 XCTest、未签名 Release 应用构建与 IPA artifact 上传，结论为
`completed/success`。V1～V8 均在 CI 日志中逐项通过；IPA 已下载到内存核验结构并独立复算
SHA-256，结果与 CI 输出一致。

## 2. V1～V8

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| V1 | `testV1InterfaceVisibilityKeepsViewportSizeEqual` | CI #36 通过 |
| V2 | `testV2BottomStripStatesKeepViewportSizeAndHeightEqual` | CI #36 通过 |
| V3 | `testV3SheetPresentationKeepsViewportSizeEqual` | CI #36 通过 |
| V4 | `testV4AllPresentationStatesShareFitAndDoubleTapMultiplier` | CI #36 通过 |
| V5 | `testV5ParametersSurviveProcessModelRestart` | CI #36 通过 |
| V6 | `testV6AllFourImageRequestStrategiesTakeEffectImmediately` | CI #36 通过 |
| V7 | `testV7MissingAspectCategoryReturnsExplicitEmptyResult` | CI #36 通过 |
| V8 | `testV8FitInsetRatioGeometryAndScopeAreCorrect` | CI #36 通过 |

- 上游基线 XCTest：280
- 本卡新增 XCTest：8
- CI 实际执行 XCTest 总数：288，失败 0，意外失败 0

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

- CI run：[iOS 构建与自验 #36](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31880857763)
- CI job：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31880857763/job/95003106144)
- CI 结论：`completed/success`
- CI 被测提交：`90b61c067b1a3e3cb93874cf6078e0438c3719ab`
- XCTest 日志：`Executed 288 tests, with 0 failures (0 unexpected)`
- IPA artifact：[PhotoCleanupMVE-unsigned-90b61c067b1a](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31880857763/artifacts/9246005472)
- artifact ID：`9246005472`
- artifact 外层归档字节数：`537471`
- artifact 外层归档摘要：`sha256:0a8331d9e0dd4e270c5274e7ec1d21c810d1c9a752e635d95e485668a853ed8b`
- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`
- IPA 字节数：`537301`
- IPA SHA-256：`000f38c49dc2dbf389f370a0a2e117059be2bc939039349eef5b3f2c4287caf4`
- artifact 到期时间：`2026-11-13T10:58:18Z`

核验方式：认证只用于向 GitHub 官方 API 请求本次 run 的日志与 artifact；重定向下载不携带
认证头。外层 ZIP 与内层 IPA 均仅在内存中读取，先拒绝绝对路径及 `..` 路径，再确认存在
`Payload/PhotoCleanupMVE.app/` 载荷；未执行任何下载内容。独立复算的 IPA 字节数与 SHA-256
均和 CI 构建日志一致。该产物为可供侧载工具签名安装的未签名 IPA。

追溯说明：首次实现提交触发的 [CI #35](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31880698419)
因中文显示映射漏掉既有枚举 `.touchPointToCenter` 而在编译阶段失败；修复提交 `90b61c0`
补齐该分支后触发独立 CI #36 并全绿，没有重跑同一份失败代码。

## 6. 执行边界

- 开发基线：`bccc2d2deadf37da470b9270f25ecb0312e6d4de`
- 开发分支：`feature/ic-054-calibration-harness`
- IC-054 commit 数：3（实现提交、编译修复提交、报告回填提交）
- 成功 push 次数：3，均为普通 push
- 无远端写入的失败 push 尝试：4（沙箱内 TLS／凭据不可用）；不计入成功 push 次数
- push 目标：仅 `origin/feature/ic-054-calibration-harness`
- 合并 `main`：未执行
- force push：未执行
- 账号操作：未执行
- `debugAssetLimit`：保持 `300`，未清理、未接回流程
- 报告回填提交只修改本报告并带 `[skip ci]`；最终功能证据仍认 CI #36 的被测提交
  `90b61c067b1a3e3cb93874cf6078e0438c3719ab`
