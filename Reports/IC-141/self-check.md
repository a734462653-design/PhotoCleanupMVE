# IC-20260908-141 自验报告：视频播放——自动静音循环、浮框接线、快照取封面帧

## 结论（先行）

六个子项全部交付，十四条断言逐条落地并在 CI 日志核到 `passed`。

- **CI #280（run id `34308687961`）绿**：被测提交 `8920c97fa00f92f15493b5cc407b9fd43f5bfffa`，
  **XCTest 723 项 0 失败**，真实退出码 **0**，`** TEST SUCCEEDED **`，
  iOS 26.2 / iPhone 16，Xcode 26.3 / iPhoneOS 26.2 SDK，未签名 IPA 已登记。
- CI 预算 3 次，**用掉 2 次**（#279 主跑红——3 处失败全在本卡新写的夹具预期上，
  产品代码一次编过；#280 修完即绿）。
- G821／G822／G823 满足；G824 满足后已 `--no-ff` 合并入 `main`（合并 SHA 与 G825 见末节）。
- H62b 的「放大后回首帧」③根因**未在本卡实装路径上复现**（断言 9 实测），见第五节。
- 人工判定项 H65 十条原样列在第八节，**执行端不代为下结论**。

## 一、输入、继承与范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260908-141-video-playback.md` |
| 基线 `main` | `395325df57244406a3f59d5b13b4c4e3676f0c21`（`docs: IC-140 …`，标题前缀核对 ✅） |
| 祖先核对 | `git merge-base --is-ancestor 6503e35c4fa3243871a185b5b4f6cc6c8dd707aa main` 为真 ✅ |
| 开工工作树 | `git status --porcelain` 空 ✅（纪律 8） |
| 分支 | `feature/ic-141-video-playback` |
| 现状基数 | `main` 上 707 项 → 本卡 723 项（+16） |

范围边界：只做视频。`S2LivePhotoPlayback.swift` 零改动，实况页行为与 IC-140 相同。

## 二、CI 实证

| 项 | 值 |
|---|---|
| 运行编号 | **#280**（run id `34308687961`，attempt 1） |
| 被测提交 | `8920c97fa00f92f15493b5cc407b9fd43f5bfffa` |
| 结论 | `success`（10 个步骤全 `success`） |
| XCTest 项数 / 失败数 | **723 / 0**（notice：`Executed 723 tests, with 0 failures (0 unexpected) in 45.651 (55.540) seconds`） |
| 真实退出码 | **0**——工作流以 `exit "$test_status"` 原样退出；日志有 `** TEST SUCCEEDED **`，**无** `Process completed with exit code N` 行（#279 红时该行为 `exit code 65`，是负对照） |
| 摘要 notice | 有（陷阱 20 的哨兵条件满足：`Executed N tests` 且 N>0） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=EADC2067-4553-4FDB-8780-62A3666009F5, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| 工具链 | `Xcode_26.3.app`，`iPhoneSimulator26.2.sdk`（测试）／`iPhoneOS26.2.sdk`（打包） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 **1368397**，SHA-256 `078a1e0d9745f2b2f51ba25e024c792c09f4e95283dd4fd4d0d278aaae2f3e95` |

### 前一次运行（预算记账）

| 项 | 值 |
|---|---|
| 运行编号 | #279（run id `34307054312`），被测提交 `5ce9fbc0fa1c4d99ced269b7fea6f7df2a5cea3a` |
| 结论 | `failure`，退出码 65 |
| 实测 | `Executed 723 tests, with 3 failures` —— **产品代码一次编过**，3 处失败全在本卡新写的夹具预期上 |

两处修法（提交 `8920c97`），均为夹具侧订正，未动产品代码：

1. **断言 6 的正对照扫错了串。** 页变更闭包里调的是夹具
   `notifyVideoPlaybackOfCurrentPage()`，不含小写开头的 `videoPlayback`，故计数为 0。
   改为正对照扫夹具名；负对照两种大小写各扫一遍，并补钉「实况侧未被本卡挤掉」。
2. **断言 7 断言了「快照非 nil」，夹具做不到。** 离屏夹具里
   `snapshotView(afterScreenUpdates:)` 取不到已渲染内容，**有无播放层都返回 nil**
   ——与本卡改动无关。改为钉**不变性**（带播放层与不带播放层的结果一致）；
   「快照非 nil」那一半按纪律 5 标**未覆盖**，留给 H65 第 6 项真机判定。
   断言 7 的实质（退场、恢复原值、对已隐藏层零多余写入）在 #279 就已经绿。

本机在推 #280 前把测试里的**全部 29 条源码扫描断言逐条复算过一遍**（脚本
`verify_scans.py`，0 失败），没有再拿 CI 当语法检查器。

## 三、本地门禁

| 门禁 | 退出码 | 关键读数 |
|---|---|---|
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 目录条目 213，产品源码引用 key 213，用户可见硬编码残留 **0** |
| `Scripts/selfcheck.ps1` | **0** | 结构、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描、测试数量门禁全通过 |
| `git diff --check` | **0** | 无空白错误 |

## 四、闸门

### G821：diff 限于白名单

`git diff main --name-only` 共 8 个文件，逐个在白名单内：

```
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift        (新增)
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/IC139MediaBadgesTests.swift
PhotoCleanupMVETests/IC141VideoPlaybackTests.swift       (新增)
```

`App/PhotoCleanupMVEApp.swift` **未改动**——卡内预期「不需要新实参」得到证实。

**分页器 diff hunk 清单（5 个，逐个对号）**：

| hunk | 对号 | 内容 |
|---|---|---|
| `@@ -754,8 +754,16 @@` | (b) | `S2NativeZoomScrollView.isPanSuspended` + `updatePanAvailability()` 加「挂起中一律禁」守卫 |
| `@@ -2057,9 +2065,14 @@` | (a) | `makeMarkAfterimageSnapshot` 经 `S2SnapshotExclusion.capturing` 捕获 |
| `@@ -2070,19 +2083,22 @@` | (a) | `makeDoubleTapSnapshot` 同上；`private` 放开为 internal，供断言 7 直接驱动 |
| `@@ -3779,7 +3795,10 @@` | (b) | `beginLongPressSuspensionIfNeeded` 置位挂起标志（改前是直写 `isEnabled = false`） |
| `@@ -3795,6 +3814,7 @@` | (b) | `endLongPressSuspension` 清除挂起标志 |

后两个 hunk 是 (b) 的组成部分——卡内原文即「挂起标志由 IC-140 (c) 的挂起／恢复路径置位与清除」。
(c) 明写「无其他」，实装也确实没有第三处。

**`S2LivePhotoPlayback.swift` 两侧 SHA-256 相同**：

```
main (395325d):  3092c28208f4e6d316787e92f9f895cf34a10ebe849c8c1dce3ec212d4fd1e12
分支 tip:        3092c28208f4e6d316787e92f9f895cf34a10ebe849c8c1dce3ec212d4fd1e12
```

该文件不在 `git diff main --name-only` 内（①双重证据）。

**计数**：

| 串 | 文件 | 计数 | 要求 |
|---|---|---|---|
| `writePhotoGeometry` | `S2NativePhotoPager.swift` | **5** | 5 ✅ |
| `player.play()` | `S2VideoPlayback.swift` | **1** | 1 ✅ |
| `player.pause()` | `S2VideoPlayback.swift` | **1** | 1 ✅ |
| `player.seek(` | `S2VideoPlayback.swift` | **1** | 1 ✅ |
| `.frame = ` | `S2VideoPlayback.swift` | **1**（即 `playerLayer.frame = bounds`） | 1 ✅ |
| `CATransaction.setDisableActions(true)` | 同上（且在 `layoutSubviews` 体内） | **1** | 1 ✅ |
| `"bounds"` / `"position"` / `"frame"` | 同上（`layer.actions` 三键） | **1 / 1 / 1** | 各 1 ✅ |
| `translatesAutoresizingMaskIntoConstraints` / `NSLayoutConstraint` | 同上 | **0 / 0** | 0 ✅ |

### G822：冻结面

| 项 | 实测 |
|---|---|
| `S2Calibration.swift` 在 diff 内？ | 否 ✅ |
| `schemaVersion` | **7**（`S2Calibration.swift:118`）✅ |
| `S2StateMachine.swift` diff | **纯新增 45 行、零删除**：两个私有存储量 + 那一对方法 + 两个测试可见读数。无新状态枚举；`handleSingleTap` 与 `setScale` 的放大自动隐藏一字未动 ✅ |
| `Services/AssetSizeScanner.swift` | 零改动（不在 diff）✅ |
| S1／S3～S5 | 零改动（不在 diff）✅ |
| 冻结三链 | `feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec` —— 与 CLAUDE.md 登记值一致，未动 ✅ |
| 探针分支 | `probe/ic-137-media-playback` `486bcb7`、`probe/ic-067-screenshot-subtype` `9db02b9` —— 未动、未合并、未 cherry-pick ✅ |

### G823：绿 + 断言逐条

见第二节与第六节。全部 XCTest 通过、退出码 0、摘要 notice、iOS 26.2 / iPhone 16、IPA 登记齐备。

## 五、H62b 三条结论的落地与③根因的实测

| H62b 结论 | 本卡落地 | 证据 |
|---|---|---|
| 探针把「单击」同时接成「切 `V` + 停／播」，Lynn 判**错** | 单击落点里不出现视频协调器 | 断言 6：`.onChange(of: machine.interfaceVisibility)` 闭包体内 `videoPlayback`／`VideoPlayback` 计数各为 0；正对照 `.onChange(of: machine.currentAssetID)` 体内 `notifyVideoPlaybackOfCurrentPage()` 恰 1 次 |
| 双击瞬间与标记残影真机未见黑块，但决策 56 仍要求取封面帧 | 两个快照都经 `S2SnapshotExclusion.capturing` | 断言 7 |
| 「放大后回首帧暂停」③根因未定（疑为探针 `configure(kind:)` 在类别异步解析后重建播放层） | **本卡实装路径上未复现** | 断言 9（两条测试） |

**③根因的实测结论（先量后改，陷阱 7）**：断言 9 用两条互补的测试量了两侧——

- `testIC141B_RepeatedContentMountDoesNotRebindThePlaybackLayer`：同一资产重挂内容树
  （`applyPhotoContent` 在缩放路径上做的正是这件事）后，`updateUIView` 走同资产分支，
  登记数仍为 1、注销数 0、`rebindCount` 0、surface 对象身份 `===` 不变。
- `testIC141B_ZoomAndDoubleTapTransitionKeepThePlaybackLayerAlive`：夹具驱动
  `applyNativeState(scale: 2, …)` 与一次双击过渡的起飞＋收口后，同样四项全部不变，
  且 `playbackState(for:)` 仍为 `.idle`（缩放路径根本不进状态机，故不可能产生
  `pause`／`unload`）。

**故卡内「若实测触发重绑或产生 `unload`，停下报告」的条件未触发**——夹具层未复现探针缺陷。
两点必须讲清楚：①产品侧类别是同步的（`assetMediaKind`），不存在探针那条「类别异步解析后
重建」的路径；②夹具驱动的是 `applyNativeState` 与 `startDoubleTapTransition`，
**不是真机捏合手势序列**（陷阱 1），真机落点由 H65 第 6 项兜底。

## 六、十四条断言与测试函数名

日志中 `Test Suite 'IC141VideoPlaybackTests' passed`，下列 16 个函数均核到 `passed`。

| 断言 | 测试函数 |
|---|---|
| 1 入口不自动播、停稳才播且先静音 | `testIC141A_EntryAssetDoesNotAutoPlayAndSettleMutesBeforePlaying` |
| 2 代次守卫、半径与持有上限 | `testIC141A_LateCallbackIsDroppedAndRadiusHoldsAtMostThreePlayers` |
| 3 翻走回起点、翻回重播、至多一段在播 | `testIC141A_LeavingAPageParksItAndReturningPlaysFromTheStart` |
| 4 循环 | `testIC141A_ReachingTheEndLoopsOnlyWhilePlaying` |
| 5 几何纪律与播放动作单一写入点 | `testIC141B_PlaybackLayerWritesNoGeometryAndDrivesPlaybackFromOnePlace` |
| 6 挂载口径 + 单击不碰播放 | `testIC141B_OnlyVideoPagesCarryALayerAndSingleTapNeverTouchesPlayback` |
| 7 两个快照都取封面帧 | `testIC141B_SnapshotsHideExcludedLayersAndRestoreTheirOriginalValue` |
| 8 挂起中一律禁 Nx 平移 | `testIC141B_PanStaysDisabledWhileSuspendedEvenWhenZoomedIn` |
| 9 缩放与双击过渡不重建播放层 | `testIC141B_RepeatedContentMountDoesNotRebindThePlaybackLayer`、`testIC141B_ZoomAndDoubleTapTransitionKeepThePlaybackLayerAlive` |
| 10 浮框状态驱动口径 | `testIC141C_VideoBarModelFollowsPlaybackStateOnVideoPagesOnly`；T1 改口径后为 `IC139MediaBadgesTests.testIC139B_VideoBarExistsOnlyOnVisibleVideoPage` |
| 11 拖动态 | `testIC141C_ScrubbingHidesChromeTransientlyAndRestoresOnRelease`、`testIC141C_ScrubHandlersAreTheOnlyTransientHideCallSites` |
| 12 读数格式 | `testIC141C_TimeFormatterUsesMinuteSecondAndHourWhenNeeded` |
| 13 有声只作用于当前页 | `testIC141C_UnmutingAppliesToTheCurrentPageAndResetsOnPageChange` |
| 14 S2View 接线 | `testIC141D_VideoWiringSitsBesideTheLivePhotoWiring` |

断言 14 的「`S2LivePhotoPlayback.swift` 两侧 SHA-256 相同」按卡内要求**在报告里核**
（第四节 G821），测试侧另加了一条更强的钉子：实况文件内 `S2Video` 计数为 0。

**项数对账**：707（`main`）+ 16（本卡新增）= **723**，与 CI 日志的 `Executed 723 tests` 一致。
卡内预期 14 个函数，实测 16 个（断言 9 与断言 11 各拆成两条），按实测登记。
IC-139 的 T1 是改口径不是新增，故不计入增量；**IC-140 测试零改动**
（`Test Suite 'IC140LivePhotoPlaybackTests' passed`）。

## 七、取值表逐条落实

| 常量 | 卡内值 | 实装值 | 消费点 |
|---|---|---|---|
| `videoPrefetchRadius` | 1 | 1 | `S2View.videoCurrentAssetAndNeighbours()` |
| `videoInstanceCap` | 3 | 3 | `S2VideoPlaybackMachine.retentionSet`（断言 2 钉住 ≤ 3） |
| `videoProgressTickSeconds` | 0.1 | 0.1 | `S2VideoPlaybackCoordinator.observeTime(of:)` |
| `videoBarTimeFontSize` | 13（既有，本卡消费） | 13 | `S2VideoScrubPresentation.fontSize`（断言 11）——**IC-139 挂账 (b) 结清** |
| `videoBarTimeTrailingOpacity` | 0.72（卡内正文登记） | 0.72 | `S2VideoScrubPresentation.trailingOpacity`（断言 11） |

视觉量全部沿用 IC-139 登记值，本卡一个都没改：`videoBarHeight` 44、`videoBarKnobDiameter` 12、
`videoBarTrackHeight` 4、`videoBarTrackOpacity` 0.28、四个符号名。

## 八、人工判定项（H65，留给 Lynn 合并后真机；执行端不代为下结论）

1. 翻到视频页：自动静音循环播放，播完从头再来不停在末帧；进入 S2 的第一张视频不自动播，翻走再翻回才播。
2. 单击主图：只有 chrome 与浮框一起显隐，**视频继续播、不暂停不回首帧**；再单击回来，进度是连续的。
3. 浮框左键：点一下暂停、再点播放，符号跟着换；暂停时翻走再翻回，从头自动播。
4. 进度拖动：按住圆点拖，chrome 隐去、浮框只剩两端时间读数与圆点，画面跟手；松手后 chrome 与浮框回到拖动前的样子，在播的继续播、暂停的保持暂停。
5. 右键有声：点一下出声，翻到下一页再翻回，又是静音。
6. 双击放大与捏合放大：视频继续播；放大瞬间与松手瞬间画面无黑块、无跳回首帧；标记上滑时残影是封面帧不是黑块。
7. 视频页长按主图无反应；实况页与照片页行为与 IC-140 后相同。
8. 静音拨片打开时点「有声」是否出声（**只记录**）。
9. 连翻 20 页（含多段视频）：无卡顿、发热、崩溃、串音；翻页拖动中不起播。
10. 浮框三件在横栏上方、压在主图下缘之上，主图不上移（IC-142 后口径）。

## 九、与卡内编排的偏离（两处，均为编译依赖所迫）

1. **子项 A 顺带加了三个 `S2MediaMetrics` 常量**（`videoPrefetchRadius`／`videoInstanceCap`／
   `videoProgressTickSeconds`）。reducer 直接消费它们，不一起加则 A 不能编译。
2. **子项 C 顺带加了 `@StateObject videoPlayback`（卡内归 D 的 S1）**。C 的浮框层要引用协调器，
   同理不能拆。

两处都在白名单文件内、都属卡内明列的改动内容，只是落在了前一个提交里。

## 十、实装决策（结果符合规格，手段由执行端定，逐条备查）

1. **视频浮框迁出 `mediaChromeLayer`，独立成兄弟层。** 规格第 6 条要求拖动态浮框在
   `V=隐藏` 期间可见，而 `interfaceOverlay` 整层挂着 `.s2ChromeVisibilityTransition`，
   隐藏态下不透明度为 0 且 `allowsHitTesting(false)`——留在原处则拖动态既看不见也点不到。
   迁出后横向边距、底缘锚（`videoBarBottomFromViewportBottom`）与 `maxWidth/maxHeight + .bottom`
   对齐**逐字照搬**，几何零变化（陷阱 13／14）。H65 第 10 项复核视觉落点。
2. **常态与拖动态共用同一条进度轨。** 两态若各建一条轨，切态瞬间视图身份变化会把正在进行的
   拖动手势掐断——`onEnded` 不来，`V` 就卡在隐藏态回不来。现在只有两侧的件换身份
   （四个 `.id`：leading/trailing × control/readout，陷阱 17），轨的结构位置不变。
3. **逐 tick 读数单独成 `S2VideoPlaybackReadout`。** 协调器自身不发布任何变更（同 IC-140），
   否则 0.1 s 一次的进度 tick 会重算整棵 `S2View.body`，连带 `updateUIViewController`
   逐 tick 重进分页器（陷阱 5）。只有 `S2VideoBarOverlay` 观察它。
4. **视频宿主视图不做「不播时整层隐藏」**（与 IC-140 的实况层相反）。视频要求暂停时留在当前帧、
   缩放期间继续播（规格第 9 条、H65 第 2／3／6 项），隐藏会直接违背。
5. **循环走 `AVPlayerItemDidPlayToEndTime` + `actionAtItemEnd = .pause`**，由 reducer 的
   `reachedEnd` 统一回 0 续播——循环只有这一条路径，且暂停态收到尾事件不动（断言 4）。
6. **`unload` 不调 `pause()`**：状态机在 `unload` 之前已经发过 `pause` 效果，
   播放动作因此只有效果执行处那一个写入点（陷阱 19、断言 5）；卸载改用
   `replaceCurrentItem(with: nil)`。

## 十一、发现但未处理的问题（按纪律只报告不修）

1. **`videoBarScrubMinimumDistance` 是取值表之外新增的一个登记常量（值 2）。**
   进度轨需要一个起手位移阈值：取 0 会让轻点轨道触发一次「隐去 chrome 再复原」的闪动，
   取手势默认的 10 又让第一次 seek 跳得太远。非视觉量，H65 第 4 项后可调。
2. **常态浮框在 `V` 由显示转隐藏时是「整条从树上摘掉」而不是淡出。** 这是 IC-139 起就有的
   既有行为（`make` 在隐藏态返回 nil），本卡迁层未改变它；只是迁出后容器的淡出不再顺带
   作用到它身上。若 H65 觉得突兀，需另卡处理。
3. **拖动手势被系统级取消时（来电、多任务切换）没有兜底。** `onEnded` 不来则
   `isDragging` 留在 true、`V` 卡在隐藏态。最常见的一条取消路径（切态重建视图）已由
   共用进度轨堵掉，系统级取消未处理。
4. **`player.seek` 用零容差**（`toleranceBefore/After: .zero`）。循环回 0 要精确，
   但拖动跟手性可能受影响，本机无从量。若 H65 第 4 项报「不跟手」，放宽拖动时的容差是首选改法。
5. **`actionAtItemEnd = .pause` 会让末帧停一瞬**，再由 `reachedEnd` 回 0 续播。
   若 H65 第 1 项看到可感顿挫，改 `.none` 是首选。
6. **断言 7 的「快照结果非 nil」在离屏夹具里不可复现**（有无播放层都取不到），
   已按纪律 5 标未覆盖，留给 H65 第 6 项。
7. **提交 `db6ca13` 漏了 `Co-Authored-By` 尾行。** 卡内「范围外」明列 amend，
   权限层也拦截 amend，故未改写历史；其余 7 个提交尾行齐备。
8. **`updatePanAvailability()` 的挂起守卫只覆盖长按挂起**（IC-140 上报 (a) 的原范围）。
   本卡的进度拖动不经这条路径——拖动期间手指在浮框上，横向翻页与 Nx 平移未被显式挂起。
   规格第 6 条只要求 chrome 隐去与 seek 跟手，未要求挂起手势，故未扩大范围；登记备查。

## 十二、G824 与 G825（合并后回填）

### G824（合并前置）

| 条件 | 实测 |
|---|---|
| G821 | 满足（第四节）✅ |
| G822 | 满足（第四节）✅ |
| G823 | 满足（第二、六节）✅ |
| 工作树净 | `git status --porcelain` 空 ✅ |
| `main` 未被他人推进 | `git ls-remote origin refs/heads/main` = `395325df57244406a3f59d5b13b4c4e3676f0c21`，与本地 `main` 一致 ✅ |

四项齐备，已按卡内授权 `--no-ff` 合并并推送。

| 项 | 值 |
|---|---|
| 合并提交 SHA | **`985fcfbeae634133c056ff2655f9c1e4ff6bd3a0`** |
| 合并前 `main` | `395325df57244406a3f59d5b13b4c4e3676f0c21` |
| 被合并分支 tip | `56f1978`（其父 `8920c97` 即 #280 的被测提交） |
| 推送 | `395325d..985fcfb  main -> main` |

### G825（合并后 `main` 自动运行）

| 项 | 值 |
|---|---|
| 运行编号 | **#281**（run id `34310584344`，attempt 1） |
| 被测提交 | `985fcfbeae634133c056ff2655f9c1e4ff6bd3a0`（合并提交） |
| 结论 | `success`，10 个步骤全 `success`，无失败步骤 |
| XCTest 项数 / 失败数 | **723 / 0**（notice：`Executed 723 tests, with 0 failures (0 unexpected) in 40.884 (70.859) seconds`） |
| 真实退出码 | **0** |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 **1368397**，SHA-256 `a30a726084b4c6bf4f496f0b13293b77c81d17f1577f6aeffb8f6224c87999cf` |

IPA 字节数与 #280 相同、SHA-256 不同——与 IC-094／097 的既有结论一致
（未签名 IPA 打包不可复现，跨运行身份不得用哈希判定，用树 diff）。

**本报告的回填方式**：G824／G825 的编号与 SHA 要等推送之后才产生，故按纪律 7 的第二种方式
——在**同一张卡、同一分支**内追加一个 docs 提交回填，不跨卡、不改写历史。
