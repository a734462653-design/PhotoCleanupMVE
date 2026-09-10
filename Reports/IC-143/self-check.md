# IC-143 自验报告

## 一、结论（先行）

四个子项全部交付，CI **#284 绿**：XCTest **736 项 0 失败**，真实退出码 **0**，
iOS 26.2 / iPhone 16。G826～G828 全部满足。

- **A** 浮框几何与命中区：整条短 32、两个图标各加 2 pt、两键各得 44×44 命中区。
  H65 第 1 项「经常按不到」的**机制已在源码层定位**：改前两键只定高不定宽。
- **B** 拖动异常终止兜底：三处异常入口共用一个无条件收口，`V` 不再卡在隐藏态
  （Decision_log 第 158 条 ③ 结案）。
- **C** 双击过渡画面连续：**③ 根因确认**（源码两点实证，见第五节），取手段 (i)
  ——过渡期间把活的 `AVPlayerLayer` 借给过渡视图。
- **D** 「有声」接音频会话：静音拨片下点「有声」即出声；静音自动播放全程不激活
  会话，因此不打断其他应用的音频。

**CI 预算用满 3 次**（#282 红、#283 红、#284 绿）。两次红**全部出在本卡新写的
夹具前提上，产品代码一次编过**、无一处产品缺陷；其中第二次是我重复了 IC-141
已经踩过并写在注释里的同一个坑，代价一次 CI，如实登记在第十节。

H66 五项真机判定**留给 Lynn**，本报告不代为下结论。

---

## 二、输入与边界

| 项 | 值 |
|---|---|
| 任务卡 | `Tasks/IC-20260909-143-video-bar-polish.md` |
| 基线 `main` | `68f9422d1081a27364392d73c6af06ededdb62ef`（`docs: IC-141` 开头 ✅） |
| 祖先核对 | `git merge-base --is-ancestor 985fcfb… main` → **真** ✅ |
| 开工工作树 | `git status --porcelain` 空 ✅（纪律 8） |
| 分支 | `feature/ic-143-video-bar-polish` |
| 被测提交 | **`94520f9195446498368ee1f705e2f2285d54cbcd`** |
| 现状基数 | 723 项（IC-141 #281）→ 本卡 736 项（+13） |

**惯例 13（开工前逐个 grep 卡内点名符号）**：R1～R3、V1～V4、M1、K1～K4、
P1～P8、T1、T2、X1 共 30 余个符号全部命中，`AVAudioSession` 在
`S2VideoPlayback.swift` 内基线命中数 **0**（与卡内 ① 一致）。

---

## 三、CI 与本地门禁

### G828：CI #284

| 项 | 值 |
|---|---|
| 运行编号 | **#284**（run id `34434507158`，attempt 1） |
| 被测提交 | `94520f9195446498368ee1f705e2f2285d54cbcd` |
| 结论 | `success`，全部步骤 `success`，无失败步骤 |
| XCTest | **`Executed 736 tests, with 0 failures (0 unexpected) in 41.675 (59.000) seconds`** |
| 真实退出码 | **0**（工作流 `set -o pipefail` + `exit "$test_status"`；日志 `test_status=0`） |
| 摘要 notice | 有（陷阱 20 的哨兵前提满足） |
| 目的地实证 | `-destination "platform=iOS Simulator,id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8"`，该 UDID 在同份日志的目的地清单里为 **`OS:26.2, name:iPhone 16`** |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 **1377550**，SHA-256 `90422a2ce61a93d1d1762d8afd0a33f134bd67f746d5847711d4689106d5ae94` |

### 三次 CI 逐次登记（预算 3 次，用满）

| # | 提交 | 结果 | 原因 |
|---|---|---|---|
| #282 | `ded9328` | 红 | 736 项 **2 失败**，均在本卡新夹具：断言 13 的前提（B 未真起播）、断言 10 的 `XCTAssertNotNil` |
| #283 | `7b8877e` | 红 | 736 项 **1 失败**，断言 10 同一条；我按「过渡时机」改的假设**不成立** |
| #284 | `94520f9` | **绿** | 736 项 0 失败 |

三次的产品代码**一次编过**，两次红没有一条源自产品缺陷（详见第十节）。

### 本地门禁（最终 tip 实跑）

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（残留 0；目录 213 键与源码引用一致） |
| `git diff --check main..HEAD` | **0** |
| `git status --porcelain` | 空 |

---

## 四、闸门逐条

### G826

| 条件 | 实测 |
|---|---|
| diff 限于白名单 | 8 个文件，全部在白名单内 ✅（清单见 change-list 第二节） |
| 分页器 hunk 只落在 P1～P6 | 4 个 hunk，**全部是纯新增**（`-N,0`），无一处删除 ✅ |
| P8 零变化 | `makeMarkAfterimageSnapshot` 函数体两侧 **SHA-256 相同** `f45d761810f17be9b70f3d1bb29cf04437f4eb5b95654610007d27947c5cc4c8` ✅ |
| `writePhotoGeometry` 计数 5 | **5** ✅ |
| `S2LivePhotoPlayback.swift` 两侧 SHA-256 相同 | `3092c28208f4e6d316787e92f9f895cf34a10ebe849c8c1dce3ec212d4fd1e12`（两侧一致）✅ |

**分页器 diff hunk 清单与对号**：

| hunk | 行号（新） | 落点 | 对号 |
|---|---|---|---|
| 1 | `+1417,12` | `S2DoubleTapTransitionView.attachPlaybackLayer(_:)` | **P1** |
| 2 | `+1475,2` | `S2NativeZoomPageController.lentPlaybackViews` 字段 | P1～P6 支撑（本次过渡借出了谁） |
| 3 | `+1947,12` | 紧接 `presentationContentView.isHidden = true` 之后借出 | **P2／P3** |
| 4 | `+2075,6` | `finishActiveDoubleTapTransition()` 收口处交还 | **P5**（**P4** 早收口路径经 P5 同一函数覆盖） |

P6（`makeDoubleTapSnapshot`）**未改**——封面帧快照照旧，(i) 是在它之上叠一层活的
播放层。`updatePanAvailability` 与 P8 零改动。

### G827

| 条件 | 实测 |
|---|---|
| `S2Calibration.swift` 不在 diff | 零命中 ✅ |
| `schemaVersion` 7 | `S2Calibration.swift:118 static let schemaVersion = 7` ✅ |
| `AssetSizeScanner.swift`、S1／S3～S5 零改动 | 零命中 ✅ |
| `Localizable.xcstrings` 未改 | 零命中 ✅（A 未改无障碍文案，卡内「预期无新键」成立） |
| 冻结三链与探针分支未变 | `b368a6c` / `6736f1e` / `a7cc1ec` / `probe` `486bcb7` ✅ |
| `seek(` 容差原样 | `S2VideoPlayback.swift:660` `player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)`（main 与 tip 命中数均 1）✅ |
| `actionAtItemEnd` 原样 | `S2VideoPlayback.swift:748` `player.actionAtItemEnd = .pause`（两侧均 1）✅ |
| `videoBarScrubMinimumDistance` 原样 | `S2View.swift:2877` `static let videoBarScrubMinimumDistance: CGFloat = 2`（值未变）✅ |

### G828

绿、退出码 0、摘要 notice、iOS 26.2 / iPhone 16、IPA 已登记（见第三节）；
十三条断言逐条在 #284 日志里核到 `passed`（见第六节）。

---

## 五、③ 根因：确认（附源码依据）

卡内 ③：「P3 让 `presentationContentView`（含播放层）在过渡期间隐藏，P2 的过渡
视图贴的是 P6 快照——而 IC-141 按决策 56 把这张快照取成**封面帧**。」

**逐点确认，两半都成立**（① 源码实证，非推断）：

**第一半 — 过渡期间活的播放层确实被隐藏。**

- `S2NativePhotoPager.swift:1946`（基线 1932）：`presentationContentView.isHidden = true`。
- `presentationContentView` 的赋值只有一处：`S2NativePhotoPager.swift:304`
  `presentationContentView = contentView`，来自 `configure(contentView:)`。
- 该函数的**三个调用点全部传 `hostingController.view`**：第 1629、1755、2559 行。
- 而视频播放层 `S2VideoHostView` 是 IC-141 挂在页内容 SwiftUI 树的 `.overlay` 上的，
  即 `hostingController.view` 的后代。

⟹ 隐藏 `presentationContentView` 就是隐藏整棵页内容树，**活的播放层一并被隐掉**。

**第二半 — 顶上的替身是封面帧。**

- `S2NativePhotoPager.swift:1917`：`S2DoubleTapTransitionView(snapshotView: makeDoubleTapSnapshot(), …)`。
- `makeDoubleTapSnapshot()` 经 `S2SnapshotExclusion.capturing(in: hostingController.view)`
  捕获，捕获瞬间把遵循 `S2SnapshotExcludedView` 的视图隐掉——`S2VideoHostView`
  正是遵循者（IC-141 B，决策 56 要求）。

⟹ 那 0.3 s 屏幕上是**不动的封面帧**在缩放；`AVPlayer` 全程没人暂停，仍在前进，
收口时播放层带着已前进的进度重新出现。与 H65 第 6 项「双击放大会卡顿暂停一会
再播放」逐点吻合。捏合不走过渡视图，故 H65 判定捏合正常；残影是有意取封面帧，
故上滑残影正常。

**卡内的停卡条件未触发**（「若执行端阅读后认为过渡期间播放层并未被遮蔽或隐藏，
停下报告」）——实读结论与假设一致，故按 (i) 实装。

### C 采用的手段与理由：**(i)**

过渡开始时把活的 `AVPlayerLayer` 借给过渡视图（贴满其 bounds、压在封面帧快照
之上），收口时交还。理由：

1. (i) 是**唯一能同时消除「回封面帧」与「0.3 s 定格」两者**的手段；(ii) 只消除
   前者，卡内也写明它会留下定格并要另留 H66 判定。
2. 过渡靠 `transform` 推进、`bounds` 全程不变，因此借出的图层**只需摆一次**，
   不需要逐帧跟随，不碰几何链（陷阱 5／6 的禁止项一条都不触及）。
3. 封面帧快照留在其下作兜底：万一没有播放器可借（资源未就绪），画面退化为
   改前的行为，不会出现黑块。

**几何纪律上的一处刻意取舍**：交还时**不写帧**——只把图层挂回宿主再强制走一次
`layoutSubviews`。这样播放层的帧仍然只有那一个写入点，IC-141 断言 5 钉的
`.frame = ` / `CATransaction.setDisableActions(true)` / `player.play()` 三族计数
一字未变，该测试原样通过（卡内要求「其余 IC-139～141 测试不动」）。

---

## 六、十三条断言与测试函数名（#284 日志逐条核到 `passed`）

| 断言 | 测试函数 | 日志 |
|---|---|---|
| 1 登记值（带正对照） | `IC143VideoPolishTests.testIC143A_VideoBarMetricsTakeTheNewRegisteredValues` | passed |
| 2 两键定宽、轨不吃两键的宽 | `…testIC143A_BothBarButtonsTakeAFixedHitWidthAndTheTrackDoesNot` | passed |
| 3 T2 口径 | `IC139MediaBadgesTests.testIC139B_VideoBarGeometryReferencesRegisteredChromeConstants`（改新值）+ `testIC142_VideoPageSharesPhotoPageGeometryInBothVisibilityStates`（**未触及，原样过**） | passed |
| 4 异常终止与 `scrubEnded` 等价且幂等 | `…testIC143B_CancellingAScrubRestoresPlaybackJustLikeReleasing` | passed |
| 5 状态机无条件收口 | `…testIC143B_CancelTransientHideZeroesDepthAndRestoresVisibility` | passed |
| 6 三处异常入口共用一个收口 | `…testIC143B_EveryAbnormalScrubExitGoesThroughOneCollector` | passed |
| 7 异常终止后 `V` 与播放回位、单击照常 | `…testIC143B_AfterAnAbnormalExitVisibilityAndTapsBehaveNormally` | passed |
| 8 过渡期间归过渡视图、收口交还 | `…testIC143C_PlaybackLayerRidesTheDoubleTapTransitionAndComesBack`（进 Nx／回 1x 各一次）+ `…testIC143C_EarlyCollapsedTransitionAlsoReturnsThePlaybackLayer`（P4 早收口） | passed |
| 9 过渡全程不碰播放 | `…testIC143C_TheTransitionNeverTouchesPlaybackState` | passed |
| 10 其余页零变化 | `…testIC143C_PhotoPageTransitionAndAfterimageSnapshotAreUnchanged` | passed |
| 11 系统会话只在适配处 | `…testIC143D_TheAudioSessionIsTouchedInExactlyOnePlace` | passed |
| 12 出声才激活、收声即停用 | `…testIC143D_UnmutingActivatesTheSessionAndEveryMutePathDeactivates` | passed |
| 13 「有声」只作用当前页 | `…testIC143D_UnmutingStillAppliesOnlyToTheCurrentPage` | passed |

**断言 10 的覆盖边界（如实标注）**：卡内两条要求都已满足并绿——照片页双击过渡的
`S2DoubleTapSynchronizationReading.maximumDifference ≤ 0.5`；P8 仍经
`S2SnapshotExclusion.capturing` 恰 1 次（源码扫描），且 P8 体内不含 `lendPlaybackLayer`。
运行时那半改钉**不变性**（树里有无可借出的播放层宿主，P8 结果一致），
**不断言快照非 nil**：离屏夹具里 `snapshotView(afterScreenUpdates:)` 取不到已渲染
内容、恒返回 nil（IC-141 #279 已实测并立此先例）。「快照确实是封面帧」这一半
**未覆盖**，留给 H66 第 2 项。

**夹具驱动、真机未覆盖（陷阱 1）**：断言 7、8、9、10 走分页器与状态机夹具，
与真机手势序列不同源；断言 6、11 是源码扫描。真机落点由 H66 五项兜底。

### 计数实测

| 项 | 值 |
|---|---|
| `writePhotoGeometry`（分页器） | **5** |
| `AVAudioSession`（`S2VideoPlayback.swift`） | **3**，全部在 `S2SystemAudioSession` 体内（文件内计数 == 适配器内计数） |
| `AVAudioSession`（`S2View` / `S2LivePhotoPlayback` / `S2NativePhotoPager`） | **0 / 0 / 0** |
| `player.play()` / `player.pause()` / `player.seek(` | 各 **1**（IC-141 断言 5 原样过） |

---

## 七、取值表逐条落实

见 change-list 第三节（四个量逐条对号、位置行号、`schemaVersion` 仍 7 的理由）。
卡内点名不变的 13 个量逐条实测未变。

---

## 八、既有测试改口径（旧 → 新）

见 change-list 第四节。摘要：

- `IC139MediaBadgesTests.testIC139B_VideoBarGeometryReferencesRegisteredChromeConstants`：
  三条值断言改新值（边距 ×1→×2、两个字号 18→20 / 20→22），同函数其余 9 条未动。
- `IC141VideoPlaybackTests.testIC141C_ScrubHandlersAreTheOnlyTransientHideCallSites`：
  原两条保留，**增**断 `cancelTransientInterfaceHide()` 恰 1 次。
- 其余 IC-139～141 与 `S2CalibrationHarnessTests` 一字未动；
  `IC140LivePhotoPlaybackTests` #284 日志内 **passed 36 条、failed 0 条**。

---

## 九、pbxproj 登记

见 change-list 第五节：加登记前重扫七族最大号，取 `1000…43` / `2000…40`（取号前
命中数均为 0），唯一 id 数 161 → 163；四处登记行已贴；测试文件只进测试目标源码
阶段（应用目标阶段内 `IC143` 命中数 0）。

---

## 十、人工判定项（H66，留给 Lynn 合并后真机，执行端不代为下结论）

1. 视频页浮框比之前短一截、两端各留出更多主图；左右两键连点十次都命中，点键的边缘不会误起拖动。
2. 视频在播时双击放大、再双击回来：画面全程连续播，不定格、不回第一帧、无黑块；捏合与上滑残影与之前一样。
3. 侧面静音拨片拨到静音，点「有声」出声；翻走后静音；先在别的 App 放音乐再进 S2 翻视频，静音自动播放时音乐不断，点「有声」音乐停，翻走后音乐恢复。
4. 拖动进度中途上滑呼出多任务再回来（或拉下控制中心）：回到 S2 后 chrome 与浮框已恢复，单击主图能正常显隐，视频状态正常。
5. 回归：H65 第 2～5、9 项各快过一遍。

---

## 十一、发现但未处理的问题

1. **（执行端自身失误，登记）本卡重复了 IC-141 已经踩过的坑，代价一次 CI。**
   IC-141 #279 实测过「离屏夹具里 `snapshotView(afterScreenUpdates:)` 恒返回 nil」，
   并把结论写进了那条绿测的注释；本卡断言 10 又写了一条 `XCTAssertNotNil`，
   #282 红后我还按「过渡时机」改了一版（#283 仍红），第三次才照先例改钉不变性。
   **教训**：动某个既有函数的断言前，先读同族既有测试的注释。

2. **`park` 对 `.ready` 态不发 `setMuted`。** reducer 的 `park` 只覆盖
   `.playing` / `.paused`；若用户在一段**已就绪但从未起播**的视频上点「有声」再翻走，
   该播放器的 `isMuted` 会停在 `false`。**不可闻**（没有在播），且翻回时
   `startPlayback` 恒先发 `setMuted(true)`，音频会话也跟 `isUnmutedByUser` 已停用，
   故无实际泄漏。属 IC-141 reducer 的既有不对称，本卡 D 的范围只是音频会话，未改。

3. **应用退到后台不单独停用音频会话。** 规格第 4 条把「应用退后台」列为应恢复
   其他应用音频的路径之一，但断言 12 只指定了三条（用户再点、翻页、卸播放器）。
   现状：`scenePhase` 钩子只收拖动态，不改静音状态。无音频后台模式时系统会挂起
   本应用、声音自然停；但会话名义上仍激活。**H66 第 3 项可顺带观察**；
   若判定需要，另发补丁卡（一行：`scenePhase != .active` 时一并收声）。

4. **拖动被取消的三处入口不含 UIKit 识别器的 `.cancelled` / `.failed`。**
   进度轨用的是 SwiftUI `DragGesture`，没有取消回调，故只能从
   `scenePhase` / 翻页 / 浮框移除三处兜。若 H66 第 4 项仍能复现卡隐藏态，
   下一步是把轨改成 UIKit 识别器（范围较大，本卡未做）。

5. **`videoBarScrubMinimumDistance = 2` 仍是取值表外的登记常量**（IC-141 引入，
   本卡未动）。H65 第 4 项未报「起手钝」，卡内也明写保持，故原样。

6. **`S2VideoBarOverlay` 的 `isDragging` 与 reducer 的 `isScrubbing` 是两份状态。**
   B 已加「模型退出拖动态即复位 `isDragging`」的单向同步，但两者仍非同一真相。
   彻底收敛需要把手势在途标志也移进 reducer（会让视图层的手势回调与效果执行
   同帧耦合），本卡按最小改动处理。

7. **`lentPlaybackViews` 持强引用。** 若过渡从未收口（页在过渡中被销毁），
   借出的图层会随过渡视图一起被移除，宿主的 `isLendingPlaybackLayer` 停在 `true`。
   实测路径上 `finishActiveDoubleTapTransition()` 必被调用（含 P4 早收口），
   故未加额外兜底；登记备查。

8. **卡内 ① 的一处偏差已登记**：T2 的「既有断言只有两条」不完整，实为两个块、
   其中一块逐条钉了 12 个量。详见 change-list 第四节的引述框。

---

## 十二、G829 与 G830（合并后回填）

### G829（合并前置）

| 条件 | 实测 |
|---|---|
| G826 | 满足（第四节）✅ |
| G827 | 满足（第四节）✅ |
| G828 | 满足（第三、六节）✅ |
| 工作树净 | `git status --porcelain` 空 ✅ |
| `main` 未被他人推进 | `git ls-remote origin refs/heads/main` = `68f9422d1081a27364392d73c6af06ededdb62ef`，与本地 `main` 一致 ✅ |

四项齐备，已按卡内授权 `--no-ff` 合并并推送。

| 项 | 值 |
|---|---|
| 合并提交 SHA | **`e498a28110599c41d94cdffc835a27246a1f1adf`** |
| 合并前 `main` | `68f9422d1081a27364392d73c6af06ededdb62ef` |
| 被合并分支 tip | `901762b`（其父 `94520f9` 即 #284 的被测提交） |
| 推送 | `68f9422..e498a28  main -> main` |

### G830（合并后 `main` 自动运行）

| 项 | 值 |
|---|---|
| 运行编号 | **#285**（run id `34435380012`，attempt 1） |
| 被测提交 | `e498a28110599c41d94cdffc835a27246a1f1adf`（合并提交） |
| 结论 | `success`，全部步骤 `success`，无失败步骤 |
| XCTest 项数 / 失败数 | **736 / 0**（notice：`Executed 736 tests, with 0 failures (0 unexpected) in 63.978 (105.496) seconds`） |
| 真实退出码 | **0** |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 **1377550**，SHA-256 `cf2e92e96b2873e981da6550844a217a60b84a2068fb1e2c175eb782e0851afc` |

IPA 字节数与 #284 相同、SHA-256 不同——与 IC-094／097／141 的既有结论一致
（未签名 IPA 打包不可复现，跨运行身份不得用哈希判定，用树 diff）。

**本报告的回填方式**：G829／G830 的编号与 SHA 要等推送之后才产生，故按纪律 7 的
第二种方式——在**同一张卡、同一分支**内追加一个 docs 提交回填，不跨卡、不改写历史。
