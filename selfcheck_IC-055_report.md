# IC-20260815-055 自验报告

## 1. 结论

IC-055 已完成。功能提交 `28b33ea3dd30cb482edbc75207d4a8af15581586` 在 CI #37
通过结构自验、用户可见硬编码扫描、295 项 XCTest、未签名 Release 应用构建和 IPA
artifact 上传，结论为 `completed/success`。

本卡新增 L1～L7 共 7 项 XCTest，上游 IC-054 的 V1～V8 全部继续通过。CI 日志的
全量结果为 `Executed 295 tests, with 0 failures (0 unexpected)`，满足不少于
`288 + 7` 项的数量门槛。

## 2. L1～L7

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| L1 | `testL1TopOverlayFramesRespectSafeAreaTop` | CI #37 通过 |
| L2 | `testL2BottomOverlayFramesRespectHomeIndicator` | CI #37 通过 |
| L3 | `testL3TopOverlayFramesDoNotIntersect` | CI #37 通过 |
| L4 | `testL4ClickableOverlayControlsMeetMinimumTouchTarget` | CI #37 通过 |
| L5 | `testL5CalibrationPanelsDoNotChangeViewportSize` | CI #37 通过 |
| L6 | `testL6CalibrationPanelsStartHiddenWithoutVisibleEntry` | CI #37 通过 |
| L7 | `testL7FactoryDefaultsMatchUsableBuildDecision` | CI #37 通过 |

## 3. V1～V8 回归

| 编号 | XCTest 方法 | 当前状态 |
|---|---|---|
| V1 | `testV1InterfaceVisibilityKeepsViewportSizeEqual` | CI #37 通过 |
| V2 | `testV2BottomStripStatesKeepViewportSizeAndHeightEqual` | CI #37 通过 |
| V3 | `testV3SheetPresentationKeepsViewportSizeEqual` | CI #37 通过 |
| V4 | `testV4AllPresentationStatesShareFitAndDoubleTapMultiplier` | CI #37 通过 |
| V5 | `testV5ParametersSurviveProcessModelRestart` | CI #37 通过 |
| V6 | `testV6AllFourImageRequestStrategiesTakeEffectImmediately` | CI #37 通过 |
| V7 | `testV7MissingAspectCategoryReturnsExplicitEmptyResult` | CI #37 通过 |
| V8 | `testV8FitInsetRatioGeometryAndScopeAreCorrect` | CI #37 通过 |

- IC-054 上游 XCTest：288
- 本卡新增 XCTest：7
- CI 实际执行 XCTest：295
- 失败：0
- 意外失败：0

## 4. 实现与布局自验

- 主图继续以全屏物理边界作为视口，根视图的 `ignoresSafeArea` 保持不变。
- 浮层从系统窗口读取实际安全区；顶部元素从顶部安全区下沿开始，底部操作区与照片横栏
  截止于主屏幕指示条上沿。
- 返回、范围信息、当前照片状态、确认入口使用同一套明确帧计算；最小间距为 8 pt。
- 产品按钮、照片横栏和后台控制条的触控区域不小于 44 × 44 pt。
- 参数面板与实时读数面板首次进入均关闭；主界面没有入口帧或可见入口，长按主图区域后
  才显示后台控制条，再分别打开两个面板。
- 两个后台面板只覆盖视口，不参与视口尺寸计算；分别开关和同时打开均由 L5 覆盖。
- `.regularMaterial` 使用数量与 IC-054 基线一致，没有新增配色、字体、图标、圆角或阴影。

## 5. 参数导出文本样例

导出格式仍为 UTF-8 纯文本，字段顺序固定，浮点数固定保留六位小数。值状态统一改为
“④项目判断默认值，可修订”。竖滑距离和速度位于后台面板最上方，并显示“核心手感参数，
优先调整”。第 8 条列出的系统惯例字段不再出现在调参范围中，但继续完整导出。

```text
schemaVersion=1
taskID=IC-20260815-055-s2-usable-build
valueStatus=④项目判断默认值，可修订
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
animationsEnabled=true
animationDurationMilliseconds=220.000000
fitInsetRatio=0.050000
fitInsetScope=screenAspectOnly
bottomStripCurrentItemSize=72.000000
bottomStripNeighborItemWidth=52.000000
bottomStripNeighborItemHeight=44.000000
bottomStripItemSpacing=8.000000
bottomStripEdgeFadeWidth=24.000000
bottomStripDragMinimumDistance=4.000000
bottomStripSwitchDistance=44.000000
```

## 6. CI 与 IPA

- CI run：[iOS 构建与自验 #37](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31882760952)
- CI job：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31882760952/job/95007520958)
- CI 结论：`completed/success`
- CI 被测提交：`28b33ea3dd30cb482edbc75207d4a8af15581586`
- XCTest 日志：`Executed 295 tests, with 0 failures (0 unexpected)`
- IPA artifact：[PhotoCleanupMVE-unsigned-28b33ea3dd30](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31882760952/artifacts/9246488406)
- artifact ID：`9246488406`
- artifact 外层归档字节数：`559200`
- artifact 外层归档摘要：`sha256:79b236dbe70d1acfced33b11d1ff7e1b279b700f531db63fa1638813a4884670`
- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`
- IPA 字节数：`559030`
- IPA SHA-256：`101f95b3b5a0a9e2aea9906f77eaf495d71bf04386561ac6d00110d57a74527b`
- artifact 到期时间：`2026-11-13T11:43:10Z`

核验过程只从 GitHub 官方 API 读取本次 run 的日志与 artifact。下载前已全文审阅 CI
workflow；下载后先拒绝绝对路径及 `..` 路径，再确认外层归档恰有一个 IPA，并确认 IPA
存在 `Payload/PhotoCleanupMVE.app/PhotoCleanupMVE` 主程序。未执行任何下载内容。外层归档
摘要与 GitHub 元数据一致，独立复算的 IPA 字节数和 SHA-256 与 CI 日志一致。

该产物不含开发者账号签名，可供侧载工具签名安装；本卡禁止账号操作，因此没有生成绑定
具体设备或账号的签名包。

## 7. 变更文件清单

- `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `PhotoCleanupMVE/Features/S2/S2View.swift`
- `PhotoCleanupMVE/Localizable.xcstrings`
- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
- `Scripts/verify-IC-20260815-055.ps1`
- `selfcheck_IC-055_report.md`

## 8. 自验脚本

执行：

```powershell
./Scripts/verify-IC-20260815-055.ps1
```

脚本检查指定分支与 IC-054 基线、295 项数量门槛、L1～L7、V1～V8、默认参数、面板范围、
安全区接线、44 pt 触达约束、后台入口、系统材质、禁止视觉样式、允许文件清单、
`debugAssetLimit`、`git diff --check`、仓库结构及用户可见硬编码扫描。

最终本地结果：73 项检查通过；静态 XCTest 总数 295；用户可见硬编码残留 0；String
Catalog 的产品 key 与源码引用均为 148。

## 9. 执行边界声明

- 开发基线：`16c03234f96f12af10843b1df2602214f2e71a74`（IC-054 分支最终提交）
- 开发分支：`feature/ic-055-usable-build`
- 功能提交：`28b33ea3dd30cb482edbc75207d4a8af15581586`
- 成功普通 push：2 次（功能提交与本报告回填提交）
- push 目标：仅 `origin/feature/ic-055-usable-build`
- 合并 `main`：未执行
- force push：未执行
- PR：未创建
- 账号设置、授权或其他账号操作：未执行
- `SPEC-*.md` 与 `Decision_log.md`：未修改
- S1、S3、S4、S5：未修改
- 视口几何、缩放逻辑、既有手势判定、图像请求实现：未修改；只增加本卡授权的后台长按入口
- `debugAssetLimit`：保持 `300`，未清理

任务卡第 8 条的文字称“38 项”，但其列出的字段名和通配模式按 IC-054 当前导出实际覆盖
30 项；另有 `aspectFillDegenerate*` 两项与 `verticalSwipeMaximumDurationMilliseconds` 未被
第 8～11 条直接点名。本实现以显式字段名和通配模式优先：这三项保持 IC-054 数值不变，
也不擅自加入可修订面板；L7 对全部 41 个出厂字段逐项锁定。

验收标准原文停在“C.”且没有后续内容。本报告只对已完整下发的 A、B 和三项交付物作结论，
没有猜测或扩展缺失的 C 条件。
