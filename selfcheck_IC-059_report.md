# IC-20260815-059 回归修复与手机框效果自验报告

## 1. 结论

IC-059 已完成。macOS CI #48 使用 Xcode 16.4 实际执行 341 个 XCTest，0 失败；随后
Release 真机构建、未签名 IPA 生成与 artifact 上传全部成功。G1～G4、M1～M2、F1～F4、
B1～B3、H1～H2 与 N1～N8、E1～E6、D1～D8 全部通过；最终 artifact 已下载并独立复核，
自动验收 A～H 满足。

## 2. 两处回归的根因与修复

### 2.1 上滑标记回归

IC-058 将主图改成内层缩放 `UIScrollView` 与外层分页 `UIScrollView` 后，竖向完成逻辑仍只
挂在外层分页滚动的结束回调，并且视图层与状态机都把该路径限制为 1x。真机上，Nx 的触点
先由内层缩放滚动接收；1x 的纯竖向拖动也可能因为外层只有横向分页内容而不进入原先预期的
结束路径。两层原生滚动与竖向语义之间没有显式失败依赖，实际结果依赖 UIKit 默认竞争，因而
出现 1x 与 Nx 都无法稳定到达标记入口的回归。

修复后，每页使用独立原生 `UIPanGestureRecognizer` 识别竖向拖动，并显式令内层缩放 pan 与
外层分页 pan 都 `require(toFail:)` 该竖向识别器；竖向识别器仅在纵向速度绝对值大于横向时
开始。状态机先裁决合格的竖向手势，再进入 Nx 横向平移分支，且 `handleSwipeUp` 不再限制
1x。`verticalSwipeDistance=40` 与 `verticalSwipeVelocity=100` 均未改变。

### 2.2 双击被识别为两次单击回归

IC-058 只安装了一个单击 `UITapGestureRecognizer`，再由 `S2TapSequenceCoordinator` 根据
两个已经完成的单击回调的时间与位置推断双击。也就是说，UIKit 在识别器层已经把两击分别
送入单击路径，自建协调器才事后重建双击语义；首击引起的 SwiftUI 显隐更新又会触发原生承载
层更新，使这种跨回调状态更脆弱，第二击因而可能再次完成一次单击切换。

修复后，单击与双击分别由原生一击、两击 `UITapGestureRecognizer` 裁决，两者的同时识别
关系由 `UIGestureRecognizerDelegate` 明确返回。首击仍在单击回调中立即切换显隐；单击
识别器只接收 `UITouch.tapCount == 1` 的触点，所以第二击不会再次进入单击回调；原生双击
回调随后撤销首击已应用的显隐切换并执行缩放。`S2TapSequenceCoordinator` 与自定义到达时间
识别器已删除，不再使用自建计时或位置协调器。

## 3. 实现摘要

- 屏幕比例判断继续使用 IC-056 的方向归一与 1% 容差，并提取为唯一共享函数。命中
  `fitInsetScope` 时双击目标为 `minDoubleTapScale`；未命中时只取填满视口倍数。活动原生
  路径与状态机保留入口都已移除 `max(填满倍数, minDoubleTapScale)` 一刀切规则。
- `fitInsetRatio` 出厂值改为 0.30；新增 `fitCornerRadius=28`，只对命中内缩的照片应用
  连续圆角与裁切，未命中时半径为 0。原生承载层在 1x 更新时强制恢复既定内容 frame，避免
  隐藏界面后的 SwiftUI 更新把照片重新铺满。
- 内缩只用于 `oneXDisplaySize`；物理视口与 `aspectFillMultiplier` 仍以原视口计算，不受
  内缩或界面显隐影响。
- Nx 内层横移在到达内容边界后，将继续拖动的溢出距离映射到外层分页偏移；松手继续使用
  既有方向、距离和速度阈值决定换页或回弹。换页成功后状态机按 v13 决策 6 把新照片
  `s=1`、偏移归零。
- 新增 `hapticOnPhotoSwitch=true`。底部缩略图成功换片、左右分页成功换片分别调用一次
  `UISelectionFeedbackGenerator.selectionChanged()`；重复落页回调与失败换片不调用。
- 未修改图片请求策略出厂值，也未改变 `S2StateMachine` 的对外方法签名。

## 4. IC-059 十五项专项 XCTest

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| G1 | `testG1OneXSwipeUpMarksCurrentAsset` | 通过（CI #48） |
| G2 | `testG2NxSwipeUpMarksCurrentAsset` | 通过（CI #48） |
| G3 | `testG3NativeSecondTapRevertsSingleAndMatchesDirectDoubleTap` | 通过（CI #48） |
| G4 | `testG4TwoNativeSingleTapsOutsideWindowToggleTwiceWithoutZoom` | 通过（CI #48） |
| M1 | `testM1ScreenAspectDoubleTapUsesMinimumScale` | 通过（CI #48） |
| M2 | `testM2NonScreenPhotoDoubleTapUsesAspectFillScale` | 通过（CI #48） |
| F1 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | 通过（CI #48） |
| F2 | `testF2CornerRadiusAppliesOnlyToInsetPhotos` | 通过（CI #48） |
| F3 | `testF3InterfaceVisibilityKeepsOneXFrameAndCornerRadiusEqual` | 通过（CI #48） |
| F4 | `testF4InsetDoesNotChangeViewportOrAspectFillMultiplier` | 通过（CI #48） |
| B1 | `testB1NxBoundaryContinuationProducesPagingDisplacement` | 通过（CI #48） |
| B2 | `testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex` | 通过（CI #48） |
| B3 | `testB3NxBoundaryPagingCompletionResetsNewPhotoScale` | 通过（CI #48） |
| H1 | `testH1EnabledPhotoSwitchHapticFiresOncePerSuccessfulSwitch` | 通过（CI #48） |
| H2 | `testH2DisabledPhotoSwitchHapticDoesNotFire` | 通过（CI #48） |

## 5. 指定回归

### 5.1 IC-058 N1～N8

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| N1 | `testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale` | 通过（CI #48） |
| N2 | `testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale` | 通过（CI #48）；本卡替代断言 |
| N3 | `testN3NativePagingUsesConfiguredPageSpacing` | 通过（CI #48） |
| N4 | `testN4PageSpacingFactoryDefaultIsTwentyPoints` | 通过（CI #48） |
| N5 | `testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport` | 通过（CI #48） |
| N6 | `testN6OneXSingleTapTogglesInterfaceVisibility` | 通过（CI #48） |
| N7 | `testN7NativePageChangeResetsZoomToOne` | 通过（CI #48） |
| N8 | `testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd` | 通过（CI #48） |

### 5.2 IC-057 E1～E6

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| E1 | `testE1FirstTapProducesImmediateSingleTapAction` | 通过（CI #48）；本卡替代断言 |
| E2 | `testE2SecondTapWithinDecisionWindowRevertsAppliedSingleTap` | 通过（CI #48）；本卡替代断言 |
| E3 | `testE3TapAfterDecisionWindowStartsNewImmediateSingleTap` | 通过（CI #48）；本卡替代断言 |
| E4 | `testE4RevertedSingleTapThenDoubleTapMatchesDirectDoubleTap` | 通过（CI #48）；本卡替代断言 |
| E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | 通过（CI #48） |
| E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | 通过（CI #48） |

### 5.3 IC-056 D1～D8

| 编号 | XCTest 方法 | 状态 |
|---|---|---|
| D1 | `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | 通过（CI #48）；本卡替代断言 |
| D2 | `testD2ZeroFitInsetMatchesPureAspectFit` | 通过（CI #48） |
| D3 | `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | 通过（CI #48） |
| D4 | `testD4ScreenAspectDoubleTapUsesMinimumScale` | 通过（CI #48） |
| D5 | `testD5ReplacementNonScreenDoubleTapUsesAspectFillScale` | 通过（CI #48）；本卡替代断言 |
| D6 | `testD6LeftEdgeDoubleTapAlignsLeftContentBoundary` | 通过（CI #48） |
| D7 | `testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary` | 通过（CI #48） |
| D8 | `testD8DoubleTapExitResetsScaleAndOffset` | 通过（CI #48） |

## 6. 失效项清单与替代断言

以下项目因本卡明确改变规则或删除自建协调器而失效，均按原编号保留或以带
`Replacement` 的方法名替换，并未静默删除。

| 失效项 | 失效原因 | 替代断言 |
|---|---|---|
| N2 | IC-058 的目标倍数来自一刀切规则，不能再代表分类后的目标 | 断言原生 `zoom(to:)` 只接收布局模型按照片类别解析出的目标倍数 |
| E1 | 原断言直接验证已删除的 `S2TapSequenceCoordinator.singleTap` | 断言原生一击识别器回调立即切换显隐，且 `tapCount=1` 可进入单击路径 |
| E2 | 原断言由自建时间窗口返回 `doubleTap(revert=true)` | 断言原生双击可与首击同时裁决、`tapCount=2` 不进入单击路径，双击回调撤销首击 |
| E3 | 原断言依赖自建 `Date` 窗口判定窗口外第二击 | 以两次分别被 UIKit 识别的一击回调替代，断言显隐切换两次且倍率不变 |
| E4 | 原断言比较自建协调器结果，且无触点锚定基准 | 用相同触点分别执行原生直接双击、首击后原生双击，比较显隐、倍率、偏移与状态完全一致 |
| D1 | 旧断言锁定 `fitInsetRatio=0.08` 与短边 92%，与新出厂值冲突 | 替换为 `fitInsetRatio=0.30`、短边为视口短边 70%（容差 1 pt） |
| D5 | 旧断言要求 `max(填满倍数, minDoubleTapScale)`，本卡已废除 | 使用填满倍数 2.0、小于最小倍数 2.5 的非屏幕比例样本，断言布局、原生目标与状态机都严格等于 2.0 |

未失效并继续保留原断言的项目：N1、N3～N8、E5～E6、D2～D4、D6～D8。

补充失效项不在用户指定的 N/E/D 清单中：历史
`testIC047_039NxVerticalMarkingSemanticsAreDisabled` 与本卡“Nx 上滑可标记”冲突，已替换为
`testIC059NxSwipeUpMarksAndResetsAfterPhotoChange`，断言当前资产进入 D、切到下一张且
`s=1`、偏移归零。

## 7. 参数导出样例

```text
schemaVersion=1
taskID=IC-20260815-059-s2-regression-and-framing
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
fitInsetRatio=0.300000
fitCornerRadius=28.000000
fitInsetScope=screenAspectOnly
pageSpacing=20.000000
hapticOnPhotoSwitch=true
bottomStripCurrentItemSize=72.000000
bottomStripNeighborItemWidth=52.000000
bottomStripNeighborItemHeight=44.000000
bottomStripItemSpacing=8.000000
bottomStripEdgeFadeWidth=24.000000
bottomStripDragMinimumDistance=4.000000
bottomStripSwitchDistance=44.000000
```

样例包含验收指定的 `fitInsetRatio=0.300000`、`fitCornerRadius=28.000000`、
`minDoubleTapScale=2.500000` 与 `hapticOnPhotoSwitch=true`。

## 8. 测试总数与 CI

- XCTest 总数：341。
- CI run：[iOS 构建与自验 #48](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31907738124)。
- CI job：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31907738124/job/95068076232)。
- CI 被测提交：`91cf17ed851725dd5cf739219d425f4f3b9045b8`。
- CI 环境：`macos-15`、Xcode 16.4、iPhone 模拟器。
- CI 结论：`success`；结构自验、硬编码扫描、341 项 XCTest、Release 真机构建与 IPA
  artifact 上传均成功。
- XCTest 日志原文：

```text
Executed 341 tests, with 0 failures (0 unexpected) in 26.546 (44.088) seconds
** TEST SUCCEEDED **
```

收敛记录：#45 首次实际执行 341 项，除 E4 在两种显隐初态下用无锚点基准比较原生锚点
偏移而产生 2 个断言失败外，其余测试通过；#46 修正基准后全绿；#47 增加 `tapCount`
第二击排除后全绿；#48 统一活动路径与状态机保留入口的分类规则并使用“填满倍数小于 2.5”
样本加强 M2/D5，作为最终验收运行。没有跳过测试、降低数量门槛或删除失败断言。

## 9. IPA artifact

- artifact：[PhotoCleanupMVE-unsigned-91cf17ed8517](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31907738124/artifacts/9252854680)。
- artifact ID：`9252854680`；归档字节数：569487；到期时间：2026-11-13 20:49:35 UTC。
- artifact 归档 SHA-256：`4dcf75690c0c0059747e3dac791e8a30bf7dc30a943c51d5d64a9aeb36aa380e`。
- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`。
- IPA 字节数：569317。
- IPA SHA-256：`b5b326a95c794d6f0d6924ea33fd79fb29f8dbaa0f94fe89265473d2fc9e5d14`。
- 独立复核：下载后的 artifact 归档只含唯一预期 IPA，归档 SHA-256 与 GitHub 元数据
  digest 一致；IPA 含 `Payload/PhotoCleanupMVE.app/Info.plist` 与主二进制，共 8 个条目，
  路径穿越条目为 0，签名目录或描述文件为 0；本地重算 IPA SHA-256 与 CI 构建日志一致。

CI 按仓库既有流程构建 Release 真机应用并封装为未签名 IPA，不包含开发者账号、设备绑定或
描述文件。任务禁止账号操作，因此不生成绑定具体账号的签名包；artifact 可下载且 IPA 结构
有效，在普通未越狱真机上安装前仍需由用户既有签名／侧载链路签名，本任务不冒充完成账号
签名。

## 10. 变更文件清单

IC-059 相对已审计的 IC-058 交付提交 `cc95139` 的变更文件：

- `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
- `PhotoCleanupMVE/Features/S2/S2View.swift`
- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
- `PhotoCleanupMVETests/S2StateMachineTests.swift`
- `Scripts/verify-IC-20260815-059.ps1`
- `selfcheck_IC-059_report.md`

清单不含任何 `SPEC-*.md` 或 `Decision_log.md`。

## 11. 自验脚本

Windows 或 macOS PowerShell 静态自验：

```powershell
./Scripts/verify-IC-20260815-059.ps1
```

安装 Xcode 且有可用 iPhone 模拟器的 macOS 完整自验：

```powershell
./Scripts/verify-IC-20260815-059.ps1 -执行XCTest
```

本次 Windows 本地结果：82 项专项静态检查全部通过；静态 XCTest 总数为 341；String
Catalog 条目与产品源码引用均为 149；用户可见硬编码残留为 0；仓库结构门禁与
`git diff --check` 通过。当前环境没有 Swift/Xcode 工具链，因此本地
未执行、也不冒充执行过 XCTest；实际编译与 XCTest 由第 8 节 macOS CI 执行。

## 12. 执行边界声明

- 开发基线：IC-058 交付提交 `cc95139`；未改写上游分支。
- 开发分支与唯一 push 目标：`feature/ic-059-regression-and-framing`。
- 代码验收提交：`91cf17ed851725dd5cf739219d425f4f3b9045b8`；其后仅回填本报告，并增加
  “报告不得含未替换占位标记”的自验门禁。
- `main` 与 `origin/main` 均保持 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`，未提交、未合并。
- 未执行 force push、PR、账号设置、授权或签名操作。
- 未修改 `SPEC-*.md`、`Decision_log.md`、S1、S3、S4、S5 或
  `S2StateMachine` 对外契约。
- 除本卡授权的命中照片圆角外，未修改配色、字体、图标、阴影或间距；`pageSpacing` 既有
  出厂值保持 20。
- 图片请求策略全部出厂值未改；`debugAssetLimit` 保持 300，未清理。
- CI/XCTest 可验证手势裁决结果、状态、尺寸、半径、分页位移与触觉调用次数；物理触觉强度
  与动画主观手感不冒充自动化结论。
