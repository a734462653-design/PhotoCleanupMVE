# IC-20260908-141 变更清单：视频播放

- 分支：`feature/ic-141-video-playback`，自 `main` = `395325df57244406a3f59d5b13b4c4e3676f0c21` 切出
- 基线核对：`git log --oneline -1 main` = `395325d docs: IC-140 …`（标题以 `docs: IC-140` 开头 ✅）；
  `git merge-base --is-ancestor 6503e35c4fa3243871a185b5b4f6cc6c8dd707aa main` 为真 ✅
- 开工工作树：`git status --porcelain` 空 ✅

## 一、提交清单

| 序 | 提交 | 子项 | 内容 |
|---|---|---|---|
| 1 | `bdd8952` | A | 视频播放 reducer 与协调器骨架（新文件）+ `S2MediaMetrics` 三个登记常量 |
| 2 | `488a9ce` | B | 宿主视图、页内包装、快照排除协议；分页器 (a)(b) |
| 3 | `7d5b53c` | C | 浮框接线、拖动态临时隐藏、口径模型与读数格式化；T1 改口径 |
| 4 | `1b8586c` | D | S2View 接线（S1／S3／S4／S5）与 IC-140 上报 (c) 注释订正 |
| 5 | `ac25a03` | E | xcstrings 三键 + pbxproj 登记 + 本地门禁 |
| 6 | `db6ca13` | F | 收尾：两处实装缺陷（隐式解包退化、拖动态读数丢失） |
| 7 | `5ce9fbc` | F | 收尾：浮框两侧视图身份按位区分（陷阱 17） |
| 8 | `8920c97` | F | 修 #279 的两处夹具断言 |

> 子项落点与卡内编排的两处偏离，均为编译依赖所迫，已在自验报告「与卡内编排的偏离」节说明：
> A 顺带加了它自己消费的三个 `S2MediaMetrics` 常量；C 顺带加了 `@StateObject videoPlayback`（S1）。

## 二、按文件

### `PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift`（新增，1038 行）

| 类型 | 角色 |
|---|---|
| `S2VideoPlaybackState` | 单段视频播放态：`idle`／`requesting`／`ready`／`playing`／`paused`／`failed` |
| `S2VideoPlaybackEvent` | 事件：`entered`／`becameCurrent`／`pagingSettled`／`requestSucceeded`／`requestFailed`／`userToggledPlayPause`／`userToggledMute`／`scrubBegan`／`scrubMoved`／`scrubEnded`／`reachedEnd` |
| `S2VideoPlaybackEffect` | 效果：`request`／`cancelRequest`／`play`／`pause`／`seek`／`setMuted`／`unload` |
| `S2VideoPlaybackMachine` | 纯值 reducer，按 assetID 记键 |
| `S2VideoPlaybackSnapshot` | 浮框读数快照（是否在播／是否静音／是否拖动／当前秒／总秒；`progress` 派生） |
| `S2VideoPlaybackReadout` | 逐 tick 读数的 `ObservableObject`，**独立于协调器** |
| `S2VideoPlaybackSurface` | 协调器与播放层之间的唯一接口（`attach(player:)`／`detachPlayer()`） |
| `S2VideoPlaybackCoordinator` | 效果执行与 `PHImageManager`／`AVPlayer` 接线 |
| `S2SnapshotExcludedView` | 快照排除协议（类约束到 `UIView`） |
| `S2SnapshotExclusion` | `capturing(in:_:)`：捕获期间隐藏遵循者，捕获后恢复原值 |
| `S2VideoHostView` | 承载 `AVPlayerLayer`；遵循上面两个协议 |
| `S2VideoPlaybackContentView` | `UIViewRepresentable`，登记／改绑／拆卸口径照 IC-140 |
| `S2VideoLayerPresentation` | 挂载口径，仅 `.video` 非 nil |
| `S2VideoTimeFormatter` | `m:ss`，超 1 小时 `h:mm:ss`，秒向下取整 |
| `S2VideoBarPresentation` | **自 `S2View.swift` 迁入**，改为状态驱动 |
| `S2VideoScrubPresentation` | 拖动态口径，不看 `V` |

### `PhotoCleanupMVE/Features/S2/S2View.swift`

- S1：新增 `@StateObject private var videoPlayback = S2VideoPlaybackCoordinator()`。
- S3：`.onChange(of: machine.currentAssetID)` 增调 `notifyVideoPlaybackOfCurrentPage()`。
- S4：`onPagingSettled` 闭包增调 `videoPlayback.pagingSettled()`。
- S5：`photoContentWithPlaybackLayer` 增 `.video` 分支，包 `S2VideoPlaybackContentView` 并带 `.id(assetID)`；
  文档注释按 IC-140 上报 (c) 订正。
- S6：视频浮框**迁出** `mediaChromeLayer`（该函数随之只剩实况胶囊，形参 `bottomStripHeight` 删除）。
- S7／S8：旧 `videoBar(_:)`、`videoBarTrack(progress:)`、`S2VideoBarPresentation` 删除，
  由新的 file-scope `private struct S2VideoBarOverlay` 取代（常态三件 + 拖动态两端读数 + 共用进度轨）。
- body：`interfaceOverlay` 之后新增兄弟层 `videoBarOverlay(bottomStripHeight:safeAreaInsets:)`。
- 新增私有夹具 `videoCurrentAssetAndNeighbours()`、`notifyVideoPlaybackOfCurrentPage()`。
- 进场／离场：`videoPlayback.enter(assetID:)`／`leave()`。
- `S2MediaMetrics` 新增 5 个登记常量（见取值表节）。

### `PhotoCleanupMVE/Core/S2StateMachine.swift`（+45 行，**纯新增，零删除**）

- 私有存储：`visibilityBeforeTransientHide`、`transientHideDepth`。
- `beginTransientInterfaceHide()`／`endTransientInterfaceHide()`（按深度计数）。
- 测试可见读数：`recordedVisibilityBeforeTransientHide`、`transientInterfaceHideDepth`。
- **未加状态枚举**；`handleSingleTap`、`V`／`s`／`c` 语义与 `setScale` 的放大自动隐藏一字未动。

### `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`（5 个 hunk）

| hunk（新行号） | 对号 | 内容 |
|---|---|---|
| `@@ -754,8 +754,16 @@` | (b) | `S2NativeZoomScrollView.isPanSuspended` + `updatePanAvailability()` 加「挂起中一律禁」守卫 |
| `@@ -2057,9 +2065,14 @@` | (a) | `makeMarkAfterimageSnapshot` 经 `S2SnapshotExclusion.capturing` 捕获 |
| `@@ -2070,19 +2083,22 @@` | (a) | `makeDoubleTapSnapshot` 同上；`private` 放开为 internal 供断言 7 驱动 |
| `@@ -3779,7 +3795,10 @@` | (b) | `beginLongPressSuspensionIfNeeded` 改经挂起标志置位 |
| `@@ -3795,6 +3814,7 @@` | (b) | `endLongPressSuspension` 清除挂起标志 |

后两个 hunk 是卡内 (b) 的组成部分——卡内原文「挂起标志由 IC-140 (c) 的挂起／恢复路径置位与清除」。

`writePhotoGeometry` 计数仍为 **5**；几何链与 `hostingController` 一字未动。

### `PhotoCleanupMVE/Localizable.xcstrings`（+33 行，纯插入）

| key | 值 | 引用点 |
|---|---|---|
| `s2.media.video_pause` | 暂停 | `S2VideoBarOverlay.playPauseButton`（在播时） |
| `s2.media.video_unmute` | 有声 | `S2VideoBarOverlay.muteButton`（静音时） |
| `s2.media.video_progress` | 进度 | `S2VideoBarOverlay.progressTrack` |

三键按既有键序逐条插入，未重排全表。目录 213 条 = 源码引用 213 条。

### `PhotoCleanupMVE.xcodeproj/project.pbxproj`（+8 行）

加登记前重扫最大对象 id（IC-134 撞号教训）：fileRef 上界 `100000000000000000000040`、
buildFile 上界 `20000000000000000000003D`。新号：

| 对象 | id |
|---|---|
| `S2VideoPlayback.swift` fileRef | `100000000000000000000041` |
| `IC141VideoPlaybackTests.swift` fileRef | `100000000000000000000042` |
| `S2VideoPlayback.swift` buildFile | `20000000000000000000003E` |
| `IC141VideoPlaybackTests.swift` buildFile | `20000000000000000000003F` |

161 个对象定义，无重号。

### 测试

- `PhotoCleanupMVETests/IC141VideoPlaybackTests.swift`（新增，1099 行，16 个测试函数）。
- `PhotoCleanupMVETests/IC139MediaBadgesTests.swift`：T1 改口径
  （`testIC139B_VideoBarExistsOnlyOnVisibleVideoPageAndTakesNoHits`
  → `testIC139B_VideoBarExistsOnlyOnVisibleVideoPage`，改断状态驱动口径），
  隐藏态那条补 `playback: .idle` 实参。**IC-140 测试零改动。**

## 三、取值表落实

| 常量 | 卡内值 | 实装 | 消费点 |
|---|---|---|---|
| `videoPrefetchRadius` | 1 | 1 | `S2View.videoCurrentAssetAndNeighbours()` |
| `videoInstanceCap` | 3 | 3 | `S2VideoPlaybackMachine.retentionSet` |
| `videoProgressTickSeconds` | 0.1 | 0.1 | `S2VideoPlaybackCoordinator.observeTime(of:)` |
| `videoBarTimeFontSize` | 13（既有） | 13 | `S2VideoScrubPresentation.fontSize` —— IC-139 挂账 (b) 结清 |
| `videoBarTimeTrailingOpacity` | 0.72（卡内正文） | 0.72 | `S2VideoScrubPresentation.trailingOpacity` |
| `videoBarScrubMinimumDistance` | 卡内未列 | 2 | `S2VideoBarOverlay.progressTrack` 的 `DragGesture` |

`videoBarScrubMinimumDistance` 是取值表之外新增的一个登记常量：进度轨需要一个起手位移阈值，
取 0 会让轻点轨道触发一次「隐去 chrome 再复原」的闪动，取手势默认的 10 又让第一次 seek 跳得太远。
**非视觉量，H65 后可调**，已在自验报告「发现但未处理」节登记。

视觉量全部沿用 IC-139 登记值：`videoBarHeight` 44、`videoBarKnobDiameter` 12、
`videoBarTrackHeight` 4、`videoBarTrackOpacity` 0.28、四个符号名——本卡一个都没改。

## 四、占位值登记

`S2CalibrationConfiguration.schemaVersion` 仍为 **7**，本卡未改任何出厂值，
`S2Calibration.swift` 不在 diff 内。
