# IC-066 未定项实际生效值盘点

## 盘点口径

- 被盘点提交：`5a603f915351791addd91c87d41bb3a5c7e04c38`（IC-064 最终交付头）。
- S2 规格：`SPEC-S2-20260816_v14.md`，SHA-256 `CEAE2A0FA830C26E3C6E2B70C2308081C8336720B20770E776E3F3091F80AD45`。
- S1 规格：`SPEC-S1-20260816_v7.md`，SHA-256 `92F770B7DA8DAE7DC73620DF67A07F85746BC3A541C1B5158BAF7317D88C386C`。
- 代码中是否已有实现以生产入口 `PhotoCleanupMVEApp` 可达路径为最终口径。只有状态机或预览夹具存在、生产入口不可达时记“部分”，并明确两层差异。
- “debug 面板可调”只指长按主图打开的 `S2View.calibrationPanel` 中真实存在的控件；仅可从 Keychain 解码、仅可导出、仅测试可注入都不算可调。
- debug／诊断工具自身的入口长按时长、面板布局和采样轮询值不属于产品规格实际值，不纳入第 157 行产品违规统计。
- “来源性质”严格使用任务卡规定的三种枚举；S1 行中的“实现自行填值（违反第 157 行）”同时对应 S1 v7 第 136 行的同类禁令。
- 规格第九节中已经明确标为“已定案”的 S2 1、2、3、4c、6 和 S1 3、4 不混入未定违规主表，另设关闭项核对，确保编号覆盖完整。
- 占位文案、系统默认手势参数和“无反馈”都是当前实际行为。只要实现已经选择了其中一种行为，就不能按“尚无实现”隐藏。

## SPEC-S2 v14 第九节仍未定项

### 缩放与手势

| 所属规格 | 未定项编号 | 规格原文 | 代码中是否已有实现 | 实际生效值 | 定义位置 | 来源性质 | 是否可由 debug 面板调节 |
|---|---|---|---|---|---|---|---|
| S2 v14 | 4a | “捏合的缩放上限 `pinchMaxScale` 是多少？” | 是 | `4.000000` | `PhotoCleanupMVE/Features/S2/S2Calibration.swift`；`S2CalibrationConfiguration.factoryPlaceholder.pinchMaxScale` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 4b | “捏合结束时归位到 `1x` 的吸附阈值 `zoomSnapBackThreshold` 是多少？” | 是 | `1.100000`；结束倍率严格小于该值时归 `1.000000` | 同上；`zoomSnapBackThreshold` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 4d | “双击进入 `Nx` 时的锚点策略是什么？” | 是 | 触点锚定；生产原生页把双击位置传给 `startDoubleTapTransition(at:)` | `PhotoCleanupMVE/Core/S2StateMachine.swift`；`S2DoubleTapAnchorStrategy.touchPoint`；`PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`；`handleDoubleTap` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 4e | “贴边翻页的触发距离与速度参数是什么？” | 是 | 溢出距离不小于 `40.000000 pt` 且横向速度不小于 `300.000000 pt/s` | `S2CalibrationConfiguration.factoryPlaceholder.edgePagingTriggerDistance`、`edgePagingTriggerVelocity` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 5-单击 | “单击、双击、上滑、下滑、左右滑、拖动与双指捏合之间的识别距离、速度、时间与触点数判定参数是什么？” | 部分 | 单击为 `1.000000` 次点击、`1.000000` 个触点；App 未设置有效移动距离和最长时长，实际采用 UIKit 默认；单击显式等待双击识别失败。配置中的 `singleTapMaximumMovement=12.000000`、`singleTapMaximumDurationMilliseconds=280.000000` 不参与生产识别 | `S2NativePhotoPager.swift`；`singleTapRecognizer`；`S2CalibrationConfiguration.factoryPlaceholder.singleTap*` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 5-双击 | 同上 | 部分 | 双击为 `2.000000` 次点击、`1.000000` 个触点；时间与移动阈值采用 UIKit 默认。第十一节 `200.000000 ms` 只用于延迟诊断目标，不控制识别器 | `S2NativePhotoPager.swift`；`doubleTapRecognizer`、`S2TapDecisionDiagnosticPolicy` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 5-上下滑 | 同上 | 是 | 最终方向与竖直轴夹角不大于已锁定的 `35.000000°`，竖向距离不小于 `40.000000 pt`，速度不小于 `100.000000 pt/s`，`1.000000` 个触点；无最长时长限制 | `S2LockedValues.verticalDirectionBoundaryAngleDegrees`；`factoryPlaceholder.verticalSwipeDistance`、`verticalSwipeVelocity`；`completeMainDrag` | 实现自行填值（违反第 157 行） | 是；仅距离、速度可调 |
| S2 v14 | 5-1x 左右滑 | 同上 | 是 | 生产路径由外层 `UIScrollView` 原生分页识别，App 未设置距离、速度或时长阈值；配置中的 `horizontalSwipeDistance=40.000000`、`horizontalSwipeVelocity=100.000000`、`horizontalSwipeMaximumDurationMilliseconds=0.000000` 未进入生产外层分页判定 | `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`；`S2NativePagingScrollView`；`S2CalibrationConfiguration.factoryPlaceholder.horizontalSwipe*` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 5-捏合 | 同上 | 是 | `2.000000` 个触点；结束过滤为最小速度 `0.000000 /s`、最长时长 `0.000000 ms`（代码语义为无限制）。`pinchMinimumScaleDelta=0.010000` 已定义但未参与生产原生捏合识别 | `factoryPlaceholder.pinchTouchCount`、`pinchMinimumVelocityPerSecond`、`pinchMaximumDurationMilliseconds`、`pinchMinimumScaleDelta`；`finishNativePinch` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 5-拖动 | 同上 | 部分 | 主图拖动由 `UIScrollView.panGestureRecognizer` 识别；`mainDragMinimumDistance=8.000000`、最小速度 `0.000000`、最长时长 `0.000000 ms` 未参与生产原生拖动起始判定 | `factoryPlaceholder.mainDrag*`；`S2NativeZoomScrollView` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 5-独占切换 | “捏合与单指拖动在同一触摸序列内的独占切换判定条件是什么？” | 部分 | 生产路径依赖同一 `UIScrollView` 的原生捏合／平移识别器仲裁；状态机在捏合开始后以 `touchSequenceOwner=.pinch` 拦截其他语义。配置值 `gestureExclusivityPolicy=pinchBeforeSingleDrag` 未被生产代码读取 | `S2StateMachine.beginPinch`、`receivesUnobscuredInput`；`factoryPlaceholder.gestureExclusivityPolicy` | 实现自行填值（违反第 157 行） | 否 |

### 呈现、加载与会话行为

| 所属规格 | 未定项编号 | 规格原文 | 代码中是否已有实现 | 实际生效值 | 定义位置 | 来源性质 | 是否可由 debug 面板调节 |
|---|---|---|---|---|---|---|---|
| S2 v14 | 7 | “当前范围、当前照片状态、待确认选择、确认页入口和照片元数据的具体文案、位置、层级与视觉样式是什么？” | 部分 | 顶部浮层依次为返回、单行范围摘要、单行状态、垃圾桶纯数字；范围文案为“【未定项 7 占位】{range} · {current}/{total}”，状态为“【未定项 7 占位】当前照片：待删／未标记”，确认入口无障碍文案为“【未定项 7 占位】查看待确认照片，会话待删总数 {count}”。未显示照片元数据。顶部高度 `48.000000 pt`、横向内边距 `8.000000 pt`、元素最小间隔 `8.000000 pt`、返回区域宽 `88.000000 pt`、两行文本行高各 `22.000000 pt`，状态行相对范围行另下移 `4.000000 pt` | `PhotoCleanupMVE/Features/S2/S2View.swift`；`topBar`；`PhotoCleanupMVE/Features/S2/S2Calibration.swift`；`S2OverlayLayout`、`topElementFrames(in:)`；`Localizable.xcstrings` 对应键 | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 8-状态与恢复 | “资产内容加载中、加载失败、资产失效以及交接数据校验失败时分别进入什么状态，显示什么恢复操作？” | 部分 | 图片请求期间显示纯黑底；无图、请求失败或资产失效时保持空白黑底，无产品级错误文案与恢复入口。交接校验失败时构造器返回 `nil` 或退出动作返回 `false`，页面不迁移且不显示原因 | `S2TemporaryPhotoImageView.body`、`requestImage`；`S2StateMachine.init?`；`CleanupCoordinator.applyS2ExitPayload` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 8-首次隐藏提示 | “界面隐藏态首次进入时是否需要一次性手势提示？” | 否 | 没有提示状态、文案或展示路径 | 无定义 | 尚无实现 | 否 |
| S2 v14 | 8-高分辨率请求 | “`s` 连续变化时，按 `s` 请求更高分辨率图像的触发条件是什么：是否对每次 `s` 变化都发起请求，还是按阈值或时机节流？” | 是 | `scaleChangeRequestPolicy=pinchEnded`：连续变化不请求，捏合结束请求一次；双击直接更新 `imageRequestScale` 并随视图键变化请求 | `S2CalibrationConfiguration.factoryPlaceholder.scaleChangeRequestPolicy`；`S2ImageRequestDecision.shouldRequest` | 实现自行填值（违反第 157 行） | 是 |
| S2 v14 | 8-降质预览 | “返回的降质预览图是否显示，还是只在最终图返回后一次性替换？” | 是 | `degradedPreviewPolicy=finalImageOnly`；PhotoKit 使用异步、高质量、快速缩放、禁止网络，降质图不显示，只接受最终图 | `factoryPlaceholder.degradedPreviewPolicy`；`S2TemporaryPhotoKitImageStrategy.requestImage` | 实现自行填值（违反第 157 行） | 是 |
| S2 v14 | 9 | “最后一项标记被取消、`D` 变为空时，待确认选择区域和确认页入口如何呈现？” | 是 | 顶部垃圾桶按钮保持显示、可点击并显示数字 `0.000000`；没有独立待确认区域。点击后会形成空集合并进入 S3 路径 | `S2View.topBar`；`S2StateMachine.sessionMergedPendingDeletionCount`；`CleanupCoordinator.enterConfirmationFromS2` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 10 | “S2 续接快照的保存时机、保存介质、保留期限，以及恢复时是否恢复界面与视口状态是什么？” | 部分 | `D` 变化时实时回写 S1 内存；点击返回或确认时生成 `{A,c,D,范围信息}` 与最远位置并原子写回 `SessionStore`。S1/S2 状态不写磁盘，应用重启不恢复；新进 S2 固定显示、`s=1.000000`、偏移零，不恢复显隐或视口 | `S2StateMachine.makeExitPayload`；`CleanupCoordinator.receiveS2PendingDeletionChange`、`applyS2ExitPayload`；`SessionStore` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 11 | “收藏切换或写入相册失败时采用什么反馈方式？相簿选择 sheet 在写入失败后如何呈现，何时关闭，如何恢复或重试？” | 部分 | 状态机失败时只返回 `false` 或写 `pendingUndecidedItem=.item11`，无可见反馈；sheet 失败时保持打开。生产入口没有接入收藏和最近相册完成回调，相簿 sheet 只有“取消”，因此生产中不存在成功写入或失败重试路径 | `S2StateMachine.completeFavoriteToggle`、`completeRecentAlbumAddition`、`reportAlbumPickerFailure`；`PhotoCleanupMVEApp` 的 `S2View` 构造 | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 12 | “当前照片因成功加入相册而从 `D` 移除时，一次性轻提示采用什么呈现形式，持续多长时间？” | 部分 | 状态机记录 `semanticNotice=.albumAdditionRemovedPendingDeletion`，但生产视图没有消费或显示；实际无可见形式、无持续时长 | `S2StateMachine.removeFromPendingAfterAlbumAddition`、`consumeSemanticNotice`；生产 `S2View` 无调用 | 尚无实现 | 否 |
| S2 v14 | 13 | ““最近一次使用过的相册”的历史记录只保留一个还是保留多个？” | 部分 | 状态机 `recentAlbum` 只保留 `1.000000` 个最近相册；每资产 `G(a)` 可保留多个去重记录。生产每次进入传入 `initialRecentAlbum=nil`，且 sheet 不能选择，因此生产实际始终没有历史按钮 | `S2StateMachine.recentAlbum`、`recordAlbum`；`CleanupCoordinator.enterS2` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 14 | “历史相册记录在什么范围内保留，何时持久化，何时检查并清理已经不存在的引用？” | 部分 | 仅存于单个 `S2StateMachine` 生命周期，不持久化；最近相册写入返回 `albumUnavailable` 时才从 `recentAlbum` 和全部 `G` 剔除，没有主动检查 | `S2StateMachine.invalidateAlbum`；`CleanupCoordinator.enterS2(initialRecentAlbum:nil)` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 15 | “写入请求尚未返回时，三个操作条按钮是否接收重复点击，彼此是否临时禁用，其他浏览操作是否继续可用？” | 部分 | 没有 in-flight 状态或互斥门控，按钮可重复点击且浏览继续可用；sheet 呈现时按已锁定规则遮挡底层。生产收藏／最近相册回调为空操作，sheet 只有取消 | `S2StateMachine.controlsCanReceiveInput`；`S2View.actionBar`；`PhotoCleanupMVEApp` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 16 | “目标相册已经包含当前照片时，成功提示的措辞与首次加入的措辞应当如何区分，是否需要区分？” | 部分 | 内部结果带 `alreadyContained`，但状态机忽略该布尔值；两种成功不区分，也没有成功文案。生产无可达选择成功路径 | `S2AlbumAdditionOutcome.success(alreadyContained:)`；`completeRecentAlbumAddition` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 17 | “`G(c)` 相册角标的视觉形式、尺寸、位置，以及相册名过长时的截断规则分别是什么？” | 部分 | 若内部有记录，单相册显示相册名，多相册显示“{最近相册} +{其余数量}”；位于顶部信息区下方左侧，单行截断并使用 `regularMaterial`。没有独立字号或尺寸常量；生产没有形成 `G` 的可达路径 | `S2View.albumBadgeText`、`interfaceOverlay`；本地化键 `s2.album.badge.*` | 实现自行填值（违反第 157 行） | 否 |
| S2 v14 | 18 | “底部横栏待删标记（第六节第 1 部分）的视觉形式与尺寸是什么？” | 部分 | `isMarked` 已传给内容闭包并设置无障碍值“待删／未标记”，但生产内容闭包忽略 `isMarked`，没有可见标记，也没有标记尺寸 | `S2BottomStripItemPresentation.isMarked`；`S2BottomStripView`；`PhotoCleanupMVEApp.stripItemContent` | 尚无实现 | 否 |
| S2 v14 | 19 | “当前照片已在 `D` 中时再次上滑，给出的“已标记”提示采用什么形式、显示多长时间、出现在什么位置？” | 部分 | 状态机记录 `semanticNotice=.alreadyMarked` 和 `pendingUndecidedItem=.item19`，视图不消费；生产实际无提示、无时长、无位置 | `S2StateMachine.handleSwipeUp`、`consumeSemanticNotice`；生产 `S2View` 无调用 | 尚无实现 | 否 |

## S2 第十一节已定案出厂值核对

这些是第 157 行允许的“已定案出厂值”。数值与非数值均与规格逐项一致。

| 参数 | 规格值 | 代码实际生效值 | 定义位置 | 来源性质 | debug 面板可调 | 备注 |
|---|---|---|---|---|---|---|
| `doubleTapDecisionWindowMilliseconds` | `200.000000` | `200.000000` | `S2CalibrationConfiguration.factoryPlaceholder` | 已定案出厂值（第十一节有记录） | 是 | 只控制诊断目标，不控制 UIKit 双击识别窗口 |
| `fitInsetRatio` | `0.300000` | `0.300000` | 同上 | 已定案出厂值（第十一节有记录） | 是 | 命中屏幕比例且显示态时生效 |
| `fitCornerRadius` | `28.000000` | `28.000000 pt` | 同上 | 已定案出厂值（第十一节有记录） | 是 | 命中屏幕比例且显示态 `s=1.000000` 时生效 |
| `fitInsetScope` | `screenAspectOnly` | 只对屏幕比例命中照片 | 同上 | 已定案出厂值（第十一节有记录） | 是 | 行为一致 |
| `screenshotImmersiveOnHide` | `true` | 开启 | 同上 | 已定案出厂值（第十一节有记录） | 是 | 行为一致 |
| `pageSpacing` | `20.000000` | `20.000000 pt` | 同上；`S2NativePagingScrollView` | 已定案出厂值（第十一节有记录） | 是 | 行为一致 |
| `hapticOnPhotoSwitch` | `true` | 只在底部横栏切片时发选择触觉 | 同上；`S2PhotoSwitchHapticFeedback` | 已定案出厂值（第十一节有记录） | 是 | 行为一致 |

## S2 第六节系统对齐项的代码现状

本节属于第 157 行明文豁免，不列入违规表；但为给合并卡提供实际值，仍记录代码现状。

| 行为 | 代码实际值或行为 | 定义位置 | debug 面板可调 |
|---|---|---|---|
| 横栏当前项尺寸 | `72.000000 × 72.000000 pt` | `factoryPlaceholder.bottomStripCurrentItemSize` | 否 |
| 横栏邻项尺寸 | `52.000000 × 44.000000 pt` | `bottomStripNeighborItemWidth`、`bottomStripNeighborItemHeight` | 否 |
| 横栏项目间隔 | `8.000000 pt` | `bottomStripItemSpacing` | 否 |
| 横栏拖动起始距离 | `4.000000 pt` | `bottomStripDragMinimumDistance` | 否 |
| 横栏逐项切换距离 | `44.000000 pt` | `bottomStripSwitchDistance` | 否 |
| 边缘渐隐 | 定义 `bottomStripEdgeFadeWidth=24.000000 pt`，但生产视图未使用该字段，实际没有渐隐 | `S2BottomStripMetrics.edgeFadeWidth`、`S2BottomStripView` | 否 |
| 惯性与吸附 | 自定义 `DragGesture` 无速度投影；按累计位移每跨 `44.000000 pt` 切一项，结束立即清零残余位移 | `S2BottomStripView.stripGesture`、`applyStripSwitches` | 否 |

## S2 第 157 行覆盖但未进入生产生效路径的配置值

这些值虽然在出厂配置、持久化与导出中存在，但生产代码不读取或不用于对应判定；来源按“尚无实现”处理，不能把导出字段误报成实际功能。

| 参数 | 配置值 | 实际状态 | 定义位置 | 来源性质 | debug 面板可调 |
|---|---:|---|---|---|---|
| `verticalSwipeMaximumDurationMilliseconds` | `0.000000` | 未用于竖滑结束判定 | `factoryPlaceholder` | 尚无实现 | 否 |
| `horizontalSwipeDistance` | `40.000000` | 未用于生产外层原生分页 | 同上 | 尚无实现 | 否 |
| `horizontalSwipeVelocity` | `100.000000` | 未用于生产外层原生分页 | 同上 | 尚无实现 | 否 |
| `horizontalSwipeMaximumDurationMilliseconds` | `0.000000` | 未用于生产外层原生分页 | 同上 | 尚无实现 | 否 |
| `pinchMinimumScaleDelta` | `0.010000` | 未用于生产原生捏合识别 | 同上 | 尚无实现 | 否 |
| `mainDragMinimumDistance` | `8.000000` | 未用于生产原生平移识别 | 同上 | 尚无实现 | 否 |
| `mainDragMinimumVelocity` | `0.000000` | 未用于生产原生平移识别 | 同上 | 尚无实现 | 否 |
| `mainDragMaximumDurationMilliseconds` | `0.000000` | 未用于生产原生平移识别 | 同上 | 尚无实现 | 否 |
| `singleTapMaximumMovement` | `12.000000` | 未用于 UIKit 单击识别器 | 同上 | 尚无实现 | 否 |
| `singleTapMaximumDurationMilliseconds` | `280.000000` | 未用于 UIKit 单击识别器 | 同上 | 尚无实现 | 否 |
| `gestureExclusivityPolicy` | `pinchBeforeSingleDrag` | 配置字段未被生产代码读取 | 同上 | 尚无实现 | 否 |

## SPEC-S1 v7 仍未定项

| 所属规格 | 未定项编号 | 规格原文 | 代码中是否已有实现 | 实际生效值 | 定义位置 | 来源性质 | 是否可由 debug 面板调节 |
|---|---|---|---|---|---|---|---|
| S1 v7 | 1 | “首次进入 S1 时的初始 `T` 与初始 `O` 分别是什么？” | 是 | `T=按月`，`O=按拍摄时间从新到旧` | `PhotoCleanupMVE/App/CleanupCoordinator.swift`；`CleanupRouteConfiguration.ic048TemporaryWiringFixture` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 2 | “授权尚未获得、被拒绝或为受限授权时，S1 分别进入什么状态，显示什么恢复操作？受限授权下范围列表与资产总数如何呈现？” | 是 | 启动先请求授权，然后始终进入 S1；未决定、拒绝、受限、limited 都被范围服务映射为 S1-4 失败态；统一显示“【未定项 15 占位】失败态文案”和“【未定项 9 占位】重试入口”。limited 不显示范围或资产总数 | `PhotoLibraryService.s1AuthorizationFailure`；`S1View.stateContent`；本地化键 `s1.placeholder.failure/retry` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 5 | “范围项显示名过长时的截断规则是什么？” | 是 | `Text(row.displayName)` 未设置 `lineLimit` 或截断模式，按 SwiftUI 可用宽度自动换行，不截断 | `PhotoCleanupMVE/Features/S1/S1View.swift`；`rangeRow` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 6 | “待删计数为零时的呈现形式是什么？已处理进度呈现为进度条、比例还是计数？” | 是 | 零计数显示“【未定项 6 占位】待删计数为零”；进度显示“【未定项 6 占位】已处理原始值 {processed}/{total}”，是整数计数比例文本，无进度条 | `S1View.rangeRow`；本地化键 `s1.placeholder.pending_zero/processed_progress` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 7 | “`D_全部` 为空集时，两处垃圾桶入口如何呈现：隐藏、禁用、徽标显示 `0`，还是可点击后给出提示？两处的呈现是否必须一致？” | 是 | S1 显示非按钮垃圾桶加问号角标，不可点击；S2 显示可点击垃圾桶和数字 `0.000000`。两处不一致 | `S1View.trashEntry`；`S2View.topBar` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 8 | “`D_全部` 向 S3 提交时的排序依据是什么？” | 是 | 全部资产标识按字符串升序；组按 `sourceRangeID` 字符串升序；组内资产标识按字符串升序 | `PhotoCleanupMVE/Core/SessionStore.swift`；`makeS3Submission` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 9 | “范围列表读取的失败原因呈现到什么粒度？重试次数是否有上限，是否存在自动重试？” | 是 | 所有失败原因统一显示同一占位文案，不呈现粒度；手动重试无上限；无自动重试 | `S1RangeReadFailure.Reason`；`S1View.stateContent`；`S1StateMachine.retry` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 10 | “读取中的状态指示采用什么形式，是否需要显示进度或预计数量？” | 是 | 居中静态文本“【未定项 10 占位】读取中状态指示”；不显示进度或预计数量 | `S1View.placeholderState`；本地化键 `s1.placeholder.loading` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 11 | “`M` 与 `K` 的持久化范围是什么：仅进程内、跨应用启动，还是跨设备？`sessionID` 在什么条件下结束？” | 部分 | `M/K` 仅在 `SessionStore` 进程内保存，不跨启动、不同步设备；启动用 UUID 建立 sessionID；S5 完成页离开且持久化记录清除成功时结束并生成新 UUID | `SessionStore.State`；`CleanupCoordinator.prepareS1AfterAuthorizationRequest`、`finishSession` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 12 | “从 S2 返回时写回校验失败的呈现方式是什么？” | 是 | 写回函数返回 `false`，保持 S2 页面与旧会话数据，不显示错误文案或恢复入口 | `CleanupCoordinator.leaveS2`、`applyS2ExitPayload`；`S1StateMachine.applyS2Return` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 13 | “会话进行中，照片库发生外部变更（资产被系统删除、相册被删除、新照片导入）时，`R(T)`、`M`、`K` 分别如何处理？已在 `M` 中但已被系统删除的资产如何呈现与清理？” | 否 | 没有 PhotoKit 变更观察器，也没有针对 `R/M/K` 的外部变更清理策略 | 无定义 | 尚无实现 | 否 |
| S1 v7 | 14 | “同一资产出现在多个范围时，各范围的待删计数各自计入，用户可能对同一资产重复看到计数；而 S3 分组按决策 10 只归入首次标记范围。两处口径不同是否需要向用户提示，如何提示？” | 否 | 保持既定计数与首次标记分组语义，但没有提示 | 无提示定义 | 尚无实现 | 否 |
| S1 v7 | 14b | “S3 分组的排列顺序按什么依据？分组数很多时是否需要折叠或分页？” | 是 | 分组按 `sourceRangeID` 字符串升序；全部组平铺为 `List` 中连续 `Section`，不折叠、不分页 | `SessionStore.makeS3Submission`；`PhotoCleanupMVE/Features/S3/S3View.swift` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 14c | “用户在 S3 内移除某分组的全部资产、该分组变为空组时，分组本身是否立即消失？” | 是 | `s3Groups` 不随单资产移除更新；空组 `Section` 继续显示，标题计数变为 `0.000000`，直到离开 S3 | `S3View.currentAssets`、`ForEach(coordinator.s3Groups)`；`CleanupCoordinator.removeAsset` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 15 | “空态与失败态的具体文案是什么？” | 是 | 空态“【未定项 15 占位】空态文案”；失败态“【未定项 15 占位】失败态文案” | `Localizable.xcstrings`；`s1.placeholder.empty/failure` | 实现自行填值（违反第 157 行） | 否 |
| S1 v7 | 16 | “推荐整理区（截图、大体积视频、未整理视频）是否在后续版本引入，引入时占据什么位置？本项为决策 5 的候补留位，v1 不实现。” | 否 | S1 没有推荐整理区 | 无定义 | 尚无实现 | 否 |
| S1 v7 | 17 | “按文件体积排序是否在后续版本引入？本项为决策 6 的候补留位，v1 不实现。” | 否 | 只有拍摄时间从新到旧／从旧到新两种排序，没有体积排序 | `S1SortOrder`、`S1View.sortSelection` | 尚无实现 | 否 |

## 第九节已关闭项目核对

这些条目仍占据第九节编号，但规格已明确关闭，不进入“实现自行填值”违规统计。

| 所属规格 | 编号 | 第九节原文 | 代码现状 |
|---|---|---|---|
| S2 v14 | 1 | “（已定案，v14）首次进入与续接进入时，界面为显示态、`s = 1`、底部横栏为静止态。” | 已实现：`CleanupRouteConfiguration.s2InitialPresentation` 为显示、`1.000000`、零偏移；横栏初始 `.idle` |
| S2 v14 | 2 | “（已定案，v14）当前照片为 `A` 最后一张时，上滑成功标记后停留在当前张，保持已标记状态，给出一次轻提示，不自动退出 S2。” | 部分：停留、保持标记、不退出已实现；只写 `pendingUndecidedItem=.item02`，未显示轻提示 |
| S2 v14 | 3 | “（已定案，v14）左右滑位于 `A` 序列边界且无目标照片时，按原生分页橡皮筋回弹反馈，不额外提示。” | 已实现：生产外层原生分页保持当前索引，无额外提示 |
| S2 v14 | 4c | “（已定案，v14）见第二节。” | 已按第二节的实时填满倍数与 `minDoubleTapScale` 二选一落位；其中 `minDoubleTapScale` 的具体数值仍受第 157 行盘点 |
| S2 v14 | 6 | “（已定案，v14）底部横栏的拖动惯性、定位吸附、可见项目范围、边缘渐隐与切换判定一律对齐系统 Photos 胶片条行为，不单独定义参数值。” | 代码为自定义 `DragGesture` 与尺寸参数；实际值见“第六节系统对齐项”表，边缘渐隐字段未生效 |
| S1 v7 | 3 | “（已定案，v5）见第一节决策 12 与第二节 `R(T)`。” | 已实现用户自建普通相册过滤、PhotoKit 返回顺序与未分类补集 |
| S1 v7 | 4 | “（已定案，v7）见第一节决策 13。” | 已实现所有维度过滤 `r.total=0.000000` 的范围 |

## “实现自行填值”违规清单

本表只汇总前文来源性质为“实现自行填值”的项目；“尚无实现”和第十一节已定案值不在表内。S2 条目直接违反 v14 第 157 行；S1 条目是 v7 第九节仍未定却已形成生产行为，供同一 S2 gate 一并收口。

| 所属规格／编号 | 实际自行填值 | 文件路径与常量名或行为点 | debug 可调 |
|---|---|---|---|
| S2 4a | `pinchMaxScale=4.000000` | `PhotoCleanupMVE/Features/S2/S2Calibration.swift`；`factoryPlaceholder.pinchMaxScale` | 否 |
| S2 4b | `zoomSnapBackThreshold=1.100000` | 同上；`zoomSnapBackThreshold` | 否 |
| S2 4d | 触点锚定 | `PhotoCleanupMVE/Core/S2StateMachine.swift`；`S2DoubleTapAnchorStrategy.touchPoint` | 否 |
| S2 4e | `40.000000 pt`、`300.000000 pt/s` | `factoryPlaceholder.edgePagingTriggerDistance/Velocity` | 否 |
| S2 5 | 单击／双击 UIKit 默认阈值；触点数 `1.000000`；双击次数 `2.000000` | `S2NativePhotoPager.swift`；`singleTapRecognizer`、`doubleTapRecognizer`；`factoryPlaceholder.*TouchCount` | 否 |
| S2 5 | 竖滑 `40.000000 pt`、`100.000000 pt/s`、无最长时长 | `factoryPlaceholder.verticalSwipeDistance/Velocity`；`completeMainDrag` | 是；距离、速度 |
| S2 5 | 捏合结束最小速度 `0.000000 /s`、最长时长无限；原生仲裁 | `factoryPlaceholder.pinchMinimumVelocityPerSecond/pinchMaximumDurationMilliseconds`；`finishNativePinch` | 否 |
| S2 5 | 1x 左右滑与主图平移采用 UIKit/UIScrollView 默认识别阈值 | `S2NativePagingScrollView`、`S2NativeZoomScrollView` | 否 |
| S2 7 | 三条未定占位文案；顶部 `48.000000 pt`、内边距／间隔 `8.000000 pt`、返回宽 `88.000000 pt`、文本行高 `22.000000 pt`、状态行下移 `4.000000 pt` | `Localizable.xcstrings`；`s2.range.summary`、`s2.status.*`、`s2.confirm.accessibility`；`S2OverlayLayout.*`、`topElementFrames(in:)` | 否 |
| S2 8 | 黑底空白失败、无恢复入口 | `S2TemporaryPhotoImageStrategy.swift`；`S2TemporaryPhotoImageView.body/requestImage` | 否 |
| S2 8 | 捏合结束请求、只显示最终图 | `factoryPlaceholder.scaleChangeRequestPolicy/degradedPreviewPolicy` | 是 |
| S2 9 | 空集合仍显示可点击入口与 `0.000000` | `S2View.topBar` | 否 |
| S2 10 | S1/S2 仅内存，退出时快照，不恢复视口 | `S2StateMachine.makeExitPayload`；`SessionStore.State` | 否 |
| S2 11 | 失败无可见反馈；sheet 失败保持打开；生产未接完成回调 | `S2StateMachine.complete*`、`reportAlbumPickerFailure`；`PhotoCleanupMVEApp` | 否 |
| S2 13 | 最近相册深度 `1.000000`；生产初始为空 | `S2StateMachine.recentAlbum`；`CleanupCoordinator.enterS2` | 否 |
| S2 14 | 仅单个 S2 实例保留；只在 `albumUnavailable` 时清理 | `S2StateMachine.invalidateAlbum` | 否 |
| S2 15 | 无 in-flight 门控，重复点击与浏览继续可用 | `S2StateMachine.controlsCanReceiveInput`；`S2View.actionBar` | 否 |
| S2 16 | 忽略 `alreadyContained`，不区分成功 | `S2AlbumAdditionOutcome.success`；`completeRecentAlbumAddition` | 否 |
| S2 17 | “{album}”／“{album} +{count}”、单行、顶部左侧 | `S2View.albumBadgeText/interfaceOverlay`；`s2.album.badge.*` | 否 |
| S2 第 157 行 | `minDoubleTapScale=2.000000` | `factoryPlaceholder.minDoubleTapScale` | 是 |
| S2 第 157 行 | 动画开启；通用 `180.000000 ms`；显隐 `220.000000 ms` | `factoryPlaceholder.animationsEnabled/animationDurationMilliseconds/presentationToggleDuration` | 是 |
| S2 第 157 行 | 描边 `1.000000 pt`；深色白 `0.090000`；浅色黑 `0.055000` | `factoryPlaceholder.fitBorderWidth/fitBorderDarkAlpha/fitBorderLightAlpha` | 是 |
| S1 1 | 初始按月、拍摄时间从新到旧 | `CleanupRouteConfiguration.ic048TemporaryWiringFixture` | 否 |
| S1 2 | 多种非完整授权统一失败态与统一重试 | `PhotoLibraryService.s1AuthorizationFailure`；`S1View.stateContent` | 否 |
| S1 5 | 长名称自动换行、不截断 | `S1View.rangeRow` | 否 |
| S1 6 | 零计数占位文案；`processed/total` 计数文本 | `s1.placeholder.pending_zero/processed_progress` | 否 |
| S1 7 | S1 问号不可点；S2 数字 `0.000000` 可点 | `S1View.trashEntry`；`S2View.topBar` | 否 |
| S1 8 | 资产、组、组内资产均按标识字符串升序 | `SessionStore.makeS3Submission` | 否 |
| S1 9 | 失败原因统一；手动无限重试；无自动重试 | `S1View.stateContent`；`S1StateMachine.retry` | 否 |
| S1 10 | 静态读取中占位文案，无进度 | `s1.placeholder.loading`；`S1View.placeholderState` | 否 |
| S1 11 | `M/K` 进程内；S5 离开后换新 UUID | `SessionStore.State`；`CleanupCoordinator.finishSession` | 否 |
| S1 12 | 校验失败无呈现、停留 S2 | `CleanupCoordinator.leaveS2/applyS2ExitPayload` | 否 |
| S1 14b | 按范围标识升序，平铺，不折叠分页 | `SessionStore.makeS3Submission`；`S3View` | 否 |
| S1 14c | 空组继续显示，计数 `0.000000` | `S3View.currentAssets/ForEach` | 否 |
| S1 15 | 两条“未定项 15 占位”文案 | `Localizable.xcstrings`；`s1.placeholder.empty/failure` | 否 |

## 统计

- S2 v14 仍未定编号全部覆盖：4a、4b、4d、4e、5、7、8、9、10、11、12、13、14、15、16、17、18、19；复杂项按实际子行为拆行。
- S2 v14 第九节已关闭编号全部另表覆盖：1、2、3、4c、6。
- S2 第十一节七项出厂值全部核对。
- S1 v7 仍未定编号全部覆盖：1、2、5、6、7、8、9、10、11、12、13、14、14b、14c、15、16、17；已关闭 3、4 另表覆盖。
- 无“待补”“大致”“约”等占位结论。
