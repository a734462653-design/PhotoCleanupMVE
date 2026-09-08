# IC-140 自验报告：实况播放——到页短动效、长按全段、手势挂起（不含视频）

## 一、结论（先行）

**卡内 A～E 五个子项全部实装，断言 1～13 全部落实并在 CI 绿跑中逐条 `passed`。**

- CI **#277**（run id `34251772462`），被测提交 `4ca8770e5c9250ec23445994240cc9de1df106e4`，**XCTest 707 项 0 失败**，真实退出码 **0**，`XCTest 执行摘要` notice 在位，**iOS 26.2 模拟器 / iPhone 16**，Xcode 26.3。
- CI 预算 3 次用满：#275 编译红（②→已定位并修）、#276 夹具红（本卡夹具对预取的假定被实测推翻，**产品代码未改**）、#277 绿。
- 本地门禁 `Scripts/selfcheck.ps1` 退出码 **0**、硬编码扫描退出码 **0**、`git diff --check` 干净。
- `S2CalibrationConfiguration.schemaVersion` 仍为 **7**（本卡不动出厂值集合）。
- **人工判定项 H64b 八条全部保留给 Lynn 真机判定，本报告不代为下结论。**
- 实装中有 **3 处需要决策会话拍板的取舍**与 **4 条发现但未处理的问题**，见第十节、第十一节。其中「长按按住不放时是否循环播放」一条，卡内断言 5 与 H64b 第 3 项的措辞可作两解，**本卡按断言 5 实装（一次按压播一遍，不循环）**。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260908-140-live-photo-playback.md` |
| 规格依据 | SPEC-S2 v19 第 151 行（决策 55）、第 157 行（决策 58）、第 637 行、第 365 行 |
| 决策依据 | Decision_log 第 155 条（未定项 26／27a 结案） |
| 探针只读参照 | `origin/probe/ic-137-media-playback` 的 `S2MediaPlaybackProbe.swift`（455-505、724-818）与 `<top>/Reports/IC-137/self-check.md` 第二节 |
| 基线（继承提交） | `8eebac1280cb9d697a88a5c7b62368c36bb864e1` |
| 目标分支 | `feature/ic-140-live-photo-playback` |
| 分支 tip | `4ca8770e5c9250ec23445994240cc9de1df106e4` |

**开工核对（①实测）**：`git status --porcelain` 空；`git log --oneline -1 main` = `8eebac1 docs: IC-142 …`，标题以 `docs: IC-142` 开头 ✓；`git merge-base --is-ancestor fd7c9831… main` 为真 ✓。现状基数 690 项，与卡内预期一致。

**未 cherry-pick、未合并 IC-137 探针分支**：探针代码只以 `git show` 只读参照。

---

## 三、逐条验收门禁

### 断言 1～13 与测试函数名（全部在 #277 日志中 `passed`）

| 断言 | 测试函数名 | 结果 |
|---|---|---|
| 1 入口那张不自动播 | `testIC140A_EntryAssetDoesNotAutoPlayUntilThePageHasChangedOnce` | passed |
| 2 未就绪停稳补播 | `testIC140A_SettlingBeforeReadyDefersTheHintUntilTheResourceArrives` | passed |
| 2 迟到旧代次无效 | `testIC140A_LateSucceededCallbackOfARetiredPageHasNoEffect` | passed |
| 3 半径与持有上限 | `testIC140A_HeldResourcesStayWithinTheRadiusAndTheInstanceCap` | passed |
| 3 保留集合口径 | `testIC140A_RetentionSetKeepsCurrentPageAndBothNeighbours` | passed |
| 4 翻走停播、至多一页在播 | `testIC140A_FlippingAwayStopsPlaybackAndAtMostOnePageEverPlays` | passed |
| 5 第二次长按能再播（探针缺陷回归线） | `testIC140B_SecondLongPressPlaysAgainAfterPlaybackEnded` | passed |
| 5 短动效播完回就绪 | `testIC140B_PlaybackEndedDuringHintReturnsToReady` | passed |
| 5 短动效中长按转全段 | `testIC140B_LongPressDuringHintSwitchesToFullImmediately` | passed |
| 5 未就绪长按、就绪即播全段 | `testIC140B_LongPressBeforeReadyPlaysFullAsSoonAsTheResourceArrives` | passed |
| 5 已松手后就绪只放短动效 | `testIC140B_ReleasingBeforeReadyFallsBackToTheHintOnly` | passed |
| 6 几何纪律（带正对照） | `testIC140B_PlaybackLayerWritesNoGeometryOfItsOwn` | passed |
| 7 挂载口径与静音口径 | `testIC140B_OnlyLivePagesCarryAPlaybackLayer` | passed |
| 8 挂起与恢复（含 P7 两种缩放正对照） | `testIC140C_LongPressSuspendsPagingVerticalSwipeAndZoomPan` | passed |
| 8 返回 false 时三者不变 | `testIC140C_LongPressOnANonLivePageChangesNoGestureSwitch` | passed |
| 9 长按时长常量归一 | `testIC140C_LongPressDurationIsRegisteredOnceAndSharedByBothRecognizers` | passed |
| 10 停稳钩子恰一次、初始布局不触发 | `testIC140C_PagingSettledFiresOncePerSettleAndNotOnInitialLayout` | passed |
| 11 P8 两快照函数逐字不变 | **报告核，无测试**（卡内明写） | 见第五节 |
| 12 S2View 接线扫描（带正对照） | `testIC140D_ViewWiringReplacesTheRecorderAndKeepsTheDispatchInPlace` | passed |
| 13 照片路径零回归 | 全量 707 项 0 失败；`IC139MediaBadgesTests` 除删记录器一条外原样 | passed |

新增测试函数 **18 个**（卡内预期 13，按实测登记）。项数核对：690 − 1（删记录器测试）+ 18 = **707**，与 CI `Executed 707 tests` 一致。本机 `grep -rh "^\s*func test" PhotoCleanupMVETests/*.swift | wc -l` 也是 707——该 grep 排除了行首非 `func` 的注释行，绕开了陷阱 22 的多数 1。

### 断言 10 的「初始布局不触发」是①实测

卡内要求「若实测初始布局会触发，停下报告」。**未触发**：`makePagerController` + `applyPager` + 挂窗口 + `layoutIfNeeded` + 一轮 runloop 之后计数为 0，随后驱动一次 `scrollViewDidEndDecelerating` 计数为 1。源码上也成立：`finishNativePaging()` 只有两个调用点，都是滚动结束回调。

### 断言 6／9／12 的源码扫描读数（①实测，本机）

| 扫描项 | 文件 | 期望 | 实测 |
|---|---|---|---|
| `startPlayback(` | `S2LivePhotoPlayback.swift` | 1 | **1** |
| `.frame = ` | 同上 | 1 | **1** |
| `.frame = bounds` | 同上 | 与上等 | **1** |
| `CATransaction.setDisableActions(true)` | 同上 | 1 | **1** |
| `translatesAutoresizingMaskIntoConstraints` | 同上 | 0 | **0** |
| `NSLayoutConstraint` | 同上 | 0 | **0** |
| `autoresizingMask` | 同上 | 0 | **0** |
| `writePhotoGeometry` | `S2NativePhotoPager.swift` | 5 | **5** |
| `minimumPressDuration = S2MediaMetrics.longPressMinimumDuration` | 同上 | 1 | **1** |
| `minimumPressDuration = 0.8` | 同上 | 0 | **0** |
| `S2LivePhotoLongPressRecorder` | `S2View.swift` | 0 | **0** |
| `livePhotoLongPress.record(` | 同上 | 0 | **0** |
| `onLongPressBegan:` / `onLongPressEnded:` / `onPagingSettled:` | 同上 | 各 1 | **各 1** |
| `handleMainPhotoLongPress()` | 同上 | 在位 | **2**（声明 + 调用点） |
| `assetMediaKind(assetID) == .live` | 同上 | 1 | **1** |
| `livePlayback.` | 同上 | 6（清单穷举） | **6** |

`livePlayback.` 的六处：`enter(`、`leave()`、`longPressBegan()`、`longPressEnded()`、`pagingSettled()`、`pageBecameCurrent(`。**规格第 4 条「上滑标记、下滑取消不向协调器发任何事件」由这条穷举断言钉住**——标记与取消路径上没有任何一处协调器调用。

---

## 四、根因假设：探针缺陷的确认（①实测 + 源码可核验）

卡内 H62b 归因（③）：**探针未设 `PHLivePhotoViewDelegate`，播放自然结束后状态停在 `.playing`，长按只在 `.ready`／`.stopped` 放行，因此长按恒为空操作。**

**确认，未推翻。** 两侧证据：

1. **探针源码①**：`git show origin/probe/ic-137-media-playback:…/S2MediaPlaybackProbe.swift` 中 `S2ProbeMediaHostView` 不声明 `PHLivePhotoViewDelegate`、不设 `delegate`；`S2ProbePlaybackMachine.handle` 的 `userRequestedPlay` 分支只在 `.ready`／`.stopped` 放行，`.playing` 落到「返回 []」。两者叠加即恒空操作。
2. **本卡回归线①**：`testIC140B_SecondLongPressPlaysAgainAfterPlaybackEnded` 在 #277 `passed`——`longPressBegan → playFull`、`longPressEnded → stop`、`playbackEnded → 状态回 ready`、**再次** `longPressBegan → 再次 playFull`。缺 `playbackEnded` 这一步，第四步就会退化成探针那样的空操作。

修复点落在 `S2LivePhotoHostView`（做 `PHLivePhotoViewDelegate`，`livePhotoView(_:didEndPlaybackWith:)` 把事件回给协调器）与状态机的 `playbackEnded` 分支。

**注**：#275 的编译错正是这条链上的类型名——`PlaybackStyle` 在 PhotosUI 里是顶层枚举 `PHLivePhotoViewPlaybackStyle`，不是 `PHLivePhotoView` 的嵌套类型。改前编译器还给出「nearly matches optional requirement」的警告，改后精确匹配、警告消失。

---

## 五、断言 11：P8 两个快照函数逐字不变（①实测）

以基线 `8eebac1…` 与分支 tip 各取一份 `S2NativePhotoPager.swift`，按同一函数体切分规则取正文（自 `func` 起至同缩进收尾大括号止）计 SHA-256：

| 函数 | 侧 | 字节数 | SHA-256 |
|---|---|---|---|
| `makeMarkAfterimageSnapshot` | base `8eebac1` | 523 | `F844DE14CB7AEBD0BEE647DFDA6F4ED05AB212D8132E7E5B1A994E52D96892E5` |
| `makeMarkAfterimageSnapshot` | tip `4ca8770` | 523 | `F844DE14CB7AEBD0BEE647DFDA6F4ED05AB212D8132E7E5B1A994E52D96892E5` |
| `makeDoubleTapSnapshot` | base `8eebac1` | 483 | `82E5137D187AFCA340850A0545C01ABA905EB6ED6C68AD3DDF38AEFD652F9BBC` |
| `makeDoubleTapSnapshot` | tip `4ca8770` | 483 | `82E5137D187AFCA340850A0545C01ABA905EB6ED6C68AD3DDF38AEFD652F9BBC` |

**两侧逐字相同。**

---

## 六、CI 与本地门禁

### CI

| 项 | 值 |
|---|---|
| 运行编号 | **#277**（run id `34251772462`） |
| 被测提交完整 SHA | `4ca8770e5c9250ec23445994240cc9de1df106e4` |
| 结论 | success |
| XCTest 项数 / 失败数 | **707 / 0**（notice：`Executed 707 tests, with 0 failures (0 unexpected) in 36.785 (54.962) seconds`） |
| XCTest 执行摘要 notice | **在位**（哨兵满足，非陷阱 20 的假绿） |
| 真实退出码 | **0**（工作流 `set -o pipefail` + `exit "$test_status"`，job 结论 success，日志中无 `Process completed with exit code` 的失败行） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=EADC2067-4553-4FDB-8780-62A3666009F5, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；`{ platform:iOS Simulator, arch:arm64, id:EADC2067-…, OS:26.2, name:iPhone 16 }` |
| 工具链 | `/Applications/Xcode_26.3.app`，最低部署目标 17.0 |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，**字节数 1324858**，**SHA-256 `dfcde04036fdcbd1091eb8eaa79dffb0fe25c04f134a67ab4c90741897237ec2`** |

### 三次 CI 的完整交代（预算用满）

| 次 | 运行 | 被测提交 | 结果 | 归因 |
|---|---|---|---|---|
| 1 | #275（`34247527552`） | `12268a4191dc109b3c71f7ea7e577a45e8ab3fa9` | 红，退出码 **65** | 编译错 2 处：`S2LivePhotoPlayback.swift:577/:665` `'PlaybackStyle' is not a member type of class 'PhotosUI.PHLivePhotoView'`。全量日志里仅此 2 条 error，`S2View.swift` 与 `S2NativePhotoPager.swift` 无错；测试目标未编译。 |
| 2 | #276（`34250463945`） | `5bfdd913c6949f0812fe5a78e4e44daeb3146b5c` | 红，**707 项 2 失败** | 编译已净。两条失败同属 `testIC140A_EntryAssetDoesNotAutoPlayUntilThePageHasChangedOnce`（第 52、56 行）。**是夹具假定被实测推翻，不是产品缺陷**，详见下。 |
| 3 | #277（`34251772462`） | `4ca8770e5c9250ec23445994240cc9de1df106e4` | **绿，707 项 0 失败** | — |

**#276 的假设推翻（③→①，如实登记）**：夹具原先假定「翻回入口那张会重新发一次请求」。实测不会——A 在 `becameCurrent(B, neighbours: ["A"])` 那一批里就已作为**半径内邻居被预取**，翻回时它的请求仍在飞，reducer 按 `needsRequest` 守卫**不重发**。这恰是规格第 2 条要的行为（重发会让上一批的回调变成旧代次而被丢弃，正是断言 2 钉住的机制）。修法是把 A 的代次改从预取那一批里取，并补一条正对照断言「翻回时不重复发起」。**第 7 个提交只改测试，产品代码未动。**

### 本地门禁（①实测）

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0**（「结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。」） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（用户可见硬编码残留 0，目录 key 210 与产品源码引用 210 一致） |
| `git diff --check` | **0**（无输出） |

新文件里只有两个字符串字面量，均为 ASCII、非用户可见：调度队列标签与 `fatalError("init(coder:) is not used")`。注释一律用「」而非直引号（陷阱 18）。

---

## 七、pbxproj 登记（G811 附证）

**加登记前重扫最大对象 id**（IC-134 撞号教训）：`PBXFileReference`（前缀 `1…`）最大 `10000000000000000000003E`；`PBXBuildFile`（前缀 `2…`）最大 `20000000000000000000003B`。四个候选新号在登记前于全文件出现次数**均为 0**：

```
10000000000000000000003F -> 0
100000000000000000000040 -> 0
20000000000000000000003C -> 0
20000000000000000000003D -> 0
```

两段 `files = (` 的命中行（原文）：

**应用源码阶段**（`400000000000000000000001 /* 应用源码阶段 */`，`files = (` 在第 440 行）：

```
				20000000000000000000003C /* S2LivePhotoPlayback.swift（源码） */,
```

**测试源码阶段**（`400000000000000000000004 /* 测试源码阶段 */`，`files = (` 在第 476 行）：

```
				20000000000000000000003D /* IC140LivePhotoPlaybackTests.swift（测试源码） */,
```

产品文件进应用目标、测试文件进测试目标，未串阶段。#277 里 18 个新测试全部执行，反证测试文件确实进了编译列表（IC-134 那次静默掉出编译列表的失败模式未复现）。

---

## 八、分页器 diff hunk 清单（G811）

`git diff -U0 8eebac1… HEAD -- …/S2NativePhotoPager.swift` 共 **10 个 hunk**，逐个对号卡内 (a)～(d)：

| hunk | 新行范围 | 对号 | 内容 |
|---|---|---|---|
| 1 | `+92,7` | (b)(d) | P3 声明：三个闭包取代 `onLongPress` |
| 2 | `+137,3` | (b)(d) | P3 透传 |
| 3 | `+2879,7` | (b)(c)(d) | P3 存储 + `isLongPressSuspending` |
| 4 | `+2939,2` | **(a)** | P1 `minimumPressDuration` 改引用登记常量 |
| 5 | `+2995,3` | (b)(d) | P3 `apply(...)` 形参 |
| 6 | `+3004,3` | (b)(d) | P3 赋值 |
| 7 | `+3213,3` | (b)(d) | P3 释放 |
| 8 | `+3755,37` | (b)**(c)** | P2 `handleLongPress` 三态分派 + `beginLongPressSuspensionIfNeeded()` |
| 9 | `+3794,13` | **(c)** | `endLongPressSuspension()` + `currentPageController` |
| 10 | `+4024,3` | **(d)** | P4 `finishNativePaging()` 末尾 `onPagingSettled?()` |

全部落在 P1～P4 与挂起／恢复处。**P8 两个快照函数、几何链、`hostingController` 一字未动。**

---

## 九、取值表逐条落实

| 常量 | 卡内值 | 实装 | 落位 |
|---|---|---|---|
| `livePhotoPrefetchRadius` | 1 | **1** | `S2MediaMetrics`（`S2View.swift`），`testIC140A_HeldResourcesStayWithinTheRadiusAndTheInstanceCap` 断言 |
| `livePhotoInstanceCap` | 3 | **3** | 同上；reducer `retentionSet` 用它截断 |
| `longPressMinimumDuration` | 0.8（既有） | **0.8，值未变** | 分页器识别器改引用它，两处 0.8 归一（IC-139 挂账 (a) 结清） |

**`schemaVersion` 仍为 7**：三个常量都在视觉登记制容器 `S2MediaMetrics` 里，不进 `S2CalibrationConfiguration`、不上标定面板，不构成出厂值集合变更。

---

## 十、需要决策会话拍板的三处取舍（实装选择，非规格判定）

1. **长按按住不放时是否循环播放。** 卡内断言 5 的序列是「按下 → 松手 → 播放结束 → 再按 → 再播」，未定义「按住期间播放自然结束」的行为；H64b 第 3 项写「按住不放持续播」，可读作「持续播下去（循环）」或「这一遍播完不被打断」。**本卡按断言 5 实装：一次按压播一遍，`PHLivePhotoView` 全段结束后回静态帧，即使手指仍按住。**若 Lynn 真机判定期望循环，改法是在 `playbackEnded` 分支加「仍在按住则重新 `playFull`」，属一行改动。
2. **不播时整层隐藏。** `PHLivePhotoView` 在 `livePhoto` 到手后会显示它自己的静止帧，若常驻可见就会盖住主图那条既有链路的出图；在 Nx 放大态下，它是按 1x 目标尺寸取的资源，会用一张较软的图盖住主图刚重取的高清图。**故实装为：不播时 `isHidden = true`，只有起播那一刻才露出。**收益是静止态完全不改变今天的呈现；代价是每次播放的起止各有一次图层切换。规格只要求「松手回到静态帧」，未指定静止态由哪一层出图。H64b 第 1、3 项能直接看到这个取舍的效果。
3. **取资源的目标尺寸取「任一播放层登记时上报的基准内容尺寸 × displayScale」，无登记时退化为 `PHImageManagerMaximumSize`。** 各页都在同一视口内，量级相同；这样避免了对每页单独维护一份尺寸。若 H64b 第 7 项（连翻 20 页无发热）出现内存压力，这里是第一个调参点（连同 `livePhotoInstanceCap`）。

---

## 十一、发现但未处理的问题（按纪律只报告不修）

1. **挂起期间 `updatePanAvailability()` 可被其他路径重新打开 Nx 平移。** 恢复口按卡内要求走 P7 的 `updatePanAvailability()`，但 P7 本身没有「挂起中一律禁」的守卫；`applyNativeState`／`prepareForNativeZoom`／`restoreOneXGeometry` 等路径都会调它。长按期间理论上不发生缩放，故实际风险低；加守卫会构成分页器的第 5 处改动，超出卡内「限定四处」，**未做**。
2. **协调器与两个视图类未被 XCTest 覆盖。** `S2LivePhotoPlaybackCoordinator` 的效果执行与 `PHImageManager` 接线、`S2LivePhotoHostView`、`S2LivePhotoPlaybackContentView` 都依赖真实 PhotoKit／SwiftUI 宿主，夹具层未实例化。断言 6 只以源码扫描钉住「起播点唯一、几何零写入」。**这三处标注为「夹具驱动不到，真机未覆盖」，由 H64b 兜底（陷阱 1）。**
3. **照片页视图树多了一层布局透明的包裹。** `photoContentWithPlaybackLayer` 是 `@ViewBuilder` 的 if/else，非实况页返回的是 `AnyView(_ConditionalContent.falseContent(AnyView(content)))` 而不是原来的 `AnyView(content)`。两层都是布局透明容器，707 项全绿也没有几何回归，但源码注释里那句「那两条路径的视图树因此一字未动」措辞偏强，**准确说法是「不构造任何播放视图，多一层布局透明包裹」**。改注释会触发一次 CI，本卡预算已用满，故留待后续卡顺手订正。
4. **`longPressBegan()` 的返回值与 S2View 的媒体类别判定可能短暂不一致。** S2View 先按 `currentMediaKind` 分派，协调器再按自己的 `currentAssetID` 决定是否挂起；若 `.onChange(of: machine.currentAssetID)` 尚未送达（换页与长按同帧的极端时序），会出现「S2View 认为是实况、协调器认为当前页为空」而不挂起、不播的情形。挂起期间翻不了页，故实际难以触发，**未加额外同步**。

**IC-139 报告中挂账的「两处 0.8 各写各的」一条，由本卡 (a) 结清。**

---

## 十二、人工判定项（H64b，原样列出，留给 Lynn 合并后真机；执行端不代为下结论）

1. 翻到实况页：只播很短一段、**无震动**、不完整播放；照片页与视频页无任何播放。
2. 进入 S2 的第一张实况不自动播；翻走再翻回它，播短动效。
3. 长按实况页主图 0.8 s：完整播放**带声音**；松手回静态帧；按住不放持续播；连续两次长按都能播；捏合放大后长按仍能播。
4. 长按按住期间：上滑、下滑、左右滑都不响应；松手后恢复。
5. 短动效播放中直接上滑标记：动效不被打断，标记照常。
6. 静音拨片打开时长按是否出声（**只记录**）。
7. 连翻 20 页（含多张实况）：无卡顿、无发热、无崩溃；翻页中不起播。
8. 长按顶部中胶囊仍能开标定面板；照片页长按主图无反应。

> 判定第 3 项时请一并留意第十节第 1 条（按住不放播完一遍后是否应循环）与第 2 条（起播／收播时的图层切换是否可感）。

---

## 十三、G811～G815

| 闸门 | 结论 | 依据 |
|---|---|---|
| **G811** | **满足** | diff 限于白名单（第十四节）；分页器 10 个 hunk 全部落在 P1～P4 与挂起／恢复处并逐个对号（第八节）；P8 两函数体两侧 SHA-256 相同（第五节）；`writePhotoGeometry` 计数 5（第三节） |
| **G812** | **满足** | `S2Calibration.swift` 不在 diff，`schemaVersion` 7；`S2StateMachine.swift`、`AssetSizeScanner.swift`、S1／S3～S5、`Localizable.xcstrings`、`PhotoCleanupMVEApp.swift`、`CleanupCoordinator.swift` 全部零改动；冻结三链与探针分支 tip 未变（`b368a6c` / `6736f1e` / `a7cc1ec` / `9db02b9`） |
| **G813** | **满足** | #277 绿、707 项 0 失败、退出码 0、摘要 notice 在位、iOS 26.2 / iPhone 16、IPA 已登记；断言 1～13 逐条给出函数名并在日志核到 `passed`（第三节） |
| **G814** | 见第十五节 | G811～G813 满足 + 工作树净 + `main` 未被他人推进 |
| **G815** | 见第十五节 | 合并后 `main` 自动运行的编号与结果 |

---

## 十四、白名单核对（G811）

`8eebac1…HEAD` 触及文件共 7 个，全部在卡内白名单内：

| 文件 | 白名单条目 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2LivePhotoPlayback.swift`（新） | ✓ 卡内第 1 行 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | ✓ 卡内第 2 行 |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | ✓ 卡内第 3 行（限定四处，已逐个对号） |
| `PhotoCleanupMVETests/IC140LivePhotoPlaybackTests.swift`（新） | ✓ 卡内第 5 行 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | ✓ 卡内第 5 行（T1 四处） |
| `PhotoCleanupMVETests/IC139MediaBadgesTests.swift` | ✓ 卡内第 5 行（T2） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | ✓ 卡内第 6 行 |

`App/PhotoCleanupMVEApp.swift` **未改**，印证卡内预期（播放层挂在 `S2View.pageContent` 内，App 侧 `photoContent:` 闭包不需要新实参）。

---

## 十五、合并（G814／G815）

本节在合并动作完成后回填，见同目录 `change-list.md` 第一节的提交表与本节末尾。

- **G814 前置**：G811～G813 已满足（上表）；合并前复核工作树净与 `main` 未被他人推进的结果记于下。
- **G815**：合并提交 SHA 与 `main` 上自动运行的编号、结论记于下。

| 项 | 值 |
|---|---|
| 合并前 `main` tip | 待回填 |
| 合并提交 SHA（`--no-ff`） | 待回填 |
| 合并后 `main` 运行编号 / 结论 | 待回填 |
