# IC-20260815-055-s2-system-parity 自验报告

## 1. 结论

IC-055 系统对齐卡已完成。功能提交
`cc82ec493c21aba7d2b162270f697dc63c39a8b5` 在 CI #38 通过结构自验、
用户可见硬编码扫描、304 项 XCTest、未签名 Release 应用构建及 IPA artifact 上传，
结论为 `completed/success`。

CI 全量测试结果为：

```text
Executed 304 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

数量构成为：IC-054 上游 288 项 + 本卡要求的 15 项 + 统一动画策略附加测试 1 项
= 304 项，满足“不少于 288 + 15”的门槛。L1～L7、P1～P3、R1～R2、
T1～T3 与 V1～V8 均在 CI 日志中逐项显示为 `passed`。

## 2. L1～L7 布局与面板测试

| 编号 | XCTest 方法 | CI #38 状态 |
|---|---|---|
| L1 | `testL1TopOverlayFramesRespectSafeAreaTop` | 通过 |
| L2 | `testL2BottomOverlayFramesRespectHomeIndicator` | 通过 |
| L3 | `testL3TopOverlayFramesDoNotIntersect` | 通过 |
| L4 | `testL4ClickableOverlayControlsMeetMinimumTouchTarget` | 通过 |
| L5 | `testL5CalibrationPanelsDoNotChangeViewportSize` | 通过 |
| L6 | `testL6CalibrationPanelsStartHiddenWithoutVisibleEntry` | 通过 |
| L7 | `testL7FactoryDefaultsMatchSystemParityDecision` | 通过 |

布局实现继续保持全屏物理边界视口，主图不因安全区或面板内缩。顶部浮层从系统顶部
安全区下沿开始，底部浮层截止于 home indicator 上沿；顶部四元素使用明确帧计算与
最小 8 pt 间距，全部可点击浮层控件至少为 44 × 44 pt。两个后台面板首次启动关闭，
主界面无入口占位，长按主图才显示后台控制条；面板开关不参与视口尺寸计算。

## 3. P1～P3 Nx 平移测试与根因

| 编号 | XCTest 方法 | CI #38 状态 |
|---|---|---|
| P1 | `testP1NxSingleFingerDragProducesNonzeroPan` | 通过 |
| P2 | `testP2NxPanStopsAtContentBoundaryWithoutExtraMargin` | 通过 |
| P3 | `testP3OneXSingleFingerDragDoesNotPanPhoto` | 通过 |

### 根因

根因是手势识别被拦截，不是 `panLimits` 算错或边界公式退化。旧实现的
`S2MainGestureModifier` 在默认 `pinchBeforeSingleDrag` 下使用：

```swift
pinchGesture.exclusively(before: singleDragGesture)
```

单指序列开始后，排在前面的 `MagnifyGesture` 不会及时失败，排在后面的
`DragGesture` 因而拿不到连续 `onChanged`。状态机的 `updateMainPan` 与
`S2Geometry.clampedOffset` 本身可以产生正确位移，但真机输入没有抵达该路径，表现为
“Nx 放大后无法平移”。

修复后捏合与单拖识别器同时接收事件，再由 `S2MainGestureArbitration` 和状态机既有
触摸所有权显式仲裁；捏合已占用序列时单拖不更新，普通单指序列可实时进入 Nx 平移。
`panLimits` 仍严格使用 v13 锁定公式：

```text
max(0, (缩放后内容尺寸 - 视口尺寸) / 2)
```

未增加余量，未改动共同不变量。P2 在两个轴到达内容边界后继续施加位移，结果保持在
精确边界；P3 确认 s = 1 时仍不产生主图平移。

## 4. R1～R2 图像请求测试

| 编号 | XCTest 方法 | CI #38 状态 |
|---|---|---|
| R1 | `testR1PinchRequestsExactlyOnceAfterPinchEnded` | 通过 |
| R2 | `testR2PinchDoesNotReplaceWithDegradedPreview` | 通过 |

出厂请求策略已改为 `pinchEnded`，降质预览策略为 `finalImageOnly`。捏合过程中的每次
比例变化只变换已加载图像，`scaleChange` 请求判定全部为 false；捏合结束后仅为当前
素材增加一次请求修订并发出一次请求。请求修订与素材 ID 绑定，切页造成的旧修订回退
不会触发请求。PhotoKit 即使返回降质回调也只记录、不替换显示图，最终图返回后才一次
性替换。两个策略枚举与调参面板 Picker 均保留，可在后台面板切换。

## 5. T1～T3 系统式跟手分页测试

| 编号 | XCTest 方法 | CI #38 状态 |
|---|---|---|
| T1 | `testT1AdjacentPageTracksFingerWithSameSignAndMonotonicOffset` | 通过 |
| T2 | `testT2BelowSnapThresholdReturnsToCurrentPage` | 通过 |
| T3 | `testT3PagingKeepsPhotoSizeAndResetsScaleAfterSwitch` | 通过 |

主图容器同时保留前一页、当前页和后一页。水平拖动期间三页只叠加同一个手指横向位移，
相邻照片与手指同号、等量、单调移动；不使用淡入淡出、缩放弹出或任意方向飞入。
松手后按原水平或 Nx 边缘分页距离与速度阈值吸附：达标时滑到相邻页，未达标时回到
当前页且索引不变。分页跟手和吸附过程中当前主图的缩放尺寸不变；切页提交仍复用既有
`resetZoomAfterPhotoChange`，新照片的 s = 1、偏移为零。

## 6. V1～V8 回归

| 编号 | XCTest 方法 | CI #38 状态 |
|---|---|---|
| V1 | `testV1InterfaceVisibilityKeepsViewportSizeEqual` | 通过 |
| V2 | `testV2BottomStripStatesKeepViewportSizeAndHeightEqual` | 通过 |
| V3 | `testV3SheetPresentationKeepsViewportSizeEqual` | 通过 |
| V4 | `testV4AllPresentationStatesShareFitAndDoubleTapMultiplier` | 通过 |
| V5 | `testV5ParametersSurviveProcessModelRestart` | 通过 |
| V6 | `testV6AllFourImageRequestStrategiesTakeEffectImmediately` | 通过 |
| V7 | `testV7MissingAspectCategoryReturnsExplicitEmptyResult` | 通过 |
| V8 | `testV8FitInsetRatioGeometryAndScopeAreCorrect` | 通过 |

附加测试 `testA1AnimationPolicyDisablesCalibratedAnimations` 也在 CI #38 通过。

## 7. 动效来源审计

| 来源位置 | 触发条件 | 修复前是否受 `animationsEnabled` 控制 | 当前状态 |
|---|---|---|---|
| `S2View.performCalibratedAnimation` | 单击界面显隐、双击缩放、捏合结束回正；返回、确认及相册操作状态变化 | 手势结束受控；返回、确认和相册状态变化未全部经此入口 | 已统一接入；false 时使用禁用动画的 Transaction |
| `S2View.animatePageTranslation` | 水平拖动松手后的目标页吸附或当前页回弹 | 原实现没有跟手分页 | 受 `S2AnimationPolicy` 控制；false 时立即结算，无吸附动画 |
| SwiftUI `.sheet` | 点击“添加到相册”展示，取消或选择后退场 | 未受控；这是确认的遗漏来源 | 展示、关闭、选择均经统一动画入口；false 时根事务禁用动画，并禁用交互式拖拽退场 |
| S2 根视图隐式动画事务 | 条件浮层、状态文本或系统容器继承到动画事务时 | 没有统一兜底 | 根 `.transaction` 在 false 时清空动画并设置 `disablesAnimations = true` |

源码中实际显式 `withAnimation` 只有两处：统一校准动画与分页吸附，二者都读取同一个
`S2AnimationPolicy`。以下可见变化不属于动画源：捏合、Nx 平移、分页跟手和底部横栏
拖动是手指直接驱动；单击延时是单双击判定窗口；最终图片替换没有 transition；收藏、
相册写入后的文字或图标是瞬时状态更新。关闭动画不会阻断这些直接手势输入，但会移除
松手后的补间、系统 sheet 展退场和继承到的隐式动效。

## 8. 参数导出样例

```text
schemaVersion=1
taskID=IC-20260815-055-s2-system-parity
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
scaleChangeRequestPolicy=pinchEnded
degradedPreviewPolicy=finalImageOnly
animationsEnabled=true
animationDurationMilliseconds=180.000000
fitInsetRatio=0.080000
fitInsetScope=screenAspectOnly
bottomStripCurrentItemSize=72.000000
bottomStripNeighborItemWidth=52.000000
bottomStripNeighborItemHeight=44.000000
bottomStripItemSpacing=8.000000
bottomStripEdgeFadeWidth=24.000000
bottomStripDragMinimumDistance=4.000000
bottomStripSwitchDistance=44.000000
```

第 12～15 条逐项结果：`fitInsetRatio=0.08`、
`fitInsetScope=screenAspectOnly`、`animationDurationMilliseconds=180`、
`animationsEnabled=true`、`verticalSwipeDistance=40`、
`verticalSwipeVelocity=100`；其余字段保持 IC-054 数值，状态标签统一为
“④项目判断默认值，可修订”。

## 9. CI 与 IPA

- CI run：[iOS 构建与自验 #38](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31893421517)
- CI job：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31893421517/job/95032977308)
- CI 结论：`completed/success`
- CI 被测提交：`cc82ec493c21aba7d2b162270f697dc63c39a8b5`
- XCTest：`Executed 304 tests, with 0 failures (0 unexpected)`
- IPA artifact：[PhotoCleanupMVE-unsigned-cc82ec493c21](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31893421517/artifacts/9249172230)
- artifact ID：`9249172230`
- artifact 外层归档字节数：`570449`
- artifact 外层归档摘要：`sha256:9fb35bb9b90e6563881f93bbac7636becae8a3fc77475251983a73cf2d065c23`
- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`
- IPA 字节数：`570279`
- IPA SHA-256：`0785aa0e29a62deb935882b7296ab13e454ed9e7799dcc4ea2f92efccfd70030`
- artifact 到期时间：`2026-11-13T15:41:17Z`

CI workflow 已全文审阅：只检出本仓库、运行仓库内自验/Xcode 命令、构建无账号签名的
Release 应用，并由固定提交的 GitHub 官方 artifact 动作上传。应用代码没有新增网络
地址、数据传输或第三方依赖。IPA 摘要与大小取自 CI 构建步骤生成的 job summary，外层
摘要与大小由 GitHub artifact 元数据确认。未执行下载内容。

产物不包含开发者账号签名，可由侧载工具签名安装；本卡禁止账号操作，因此未生成绑定
具体账号、设备或描述文件的签名包。

## 10. 变更文件清单

- `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift`
- `PhotoCleanupMVE/Features/S2/S2View.swift`
- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
- `Scripts/verify-IC-20260815-055.ps1`
- `selfcheck_IC-055_report.md`

清单不含任何 `SPEC-*.md` 或 `Decision_log.md`。

## 11. 自验脚本

执行：

```powershell
./Scripts/verify-IC-20260815-055.ps1
```

最终本地结果：99 项检查通过；静态 XCTest 总数 304；L1～L7、P1～P3、R1～R2、
T1～T3 与 V1～V8 全部存在；用户可见硬编码残留 0；String Catalog 产品 key 与源码
引用均为 148；`git diff --check` 通过。

## 12. 执行边界声明

- 开发基线：`3bfa5f53bb7742b9dff2a6fdb12ca03f755bee93`
- 开发分支：`feature/ic-055-system-parity`
- 功能提交：`cc82ec493c21aba7d2b162270f697dc63c39a8b5`
- push 目标：仅 `origin/feature/ic-055-system-parity`
- 合并 `main`：未执行
- force push：未执行
- PR：未创建
- 账号设置、授权、签名或其他账号操作：未执行
- `SPEC-*.md` 与 `Decision_log.md`：未修改
- S1、S3、S4、S5：未修改
- 上滑标记、下滑取消语义与阈值：未修改
- v13 `panLimits` 公式及零余量共同不变量：未修改
- `debugAssetLimit`：保持 `300`，未清理
- 配色、字体、图标、圆角、阴影：未修改；既有 `.regularMaterial` 数量不变
- 产品负责人手感验收：不冒充自动自验结论，仍由负责人真机验收
