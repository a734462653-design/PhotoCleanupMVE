# IC-144 自验报告

## 一、结论（先行）

两个子项全部交付，CI **#286 绿（一次过）**：XCTest **741 项 0 失败**，真实退出码
**0**，iOS 26.2 / iPhone 16。G831～G833 全部满足，**CI 预算 3 次只用 1 次**。

- **A** 借出的播放层不改尺寸：`attachPlaybackLayer` 由写 `frame` 改为摆
  `position` + `transform`，`layoutSubviews` 加借出期守卫并在收回后先复位变换
  再写帧。卡内 ③ 与源码逐点吻合（第五节）。
- **B** `park` 对 `.ready` 态补静音：结清 IC-143 报告第十一节第 2 条的不对称。

H67 四项真机判定**留给 Lynn**，本报告不代为下结论。**A 的真机效果（用户眼里
是否连续）夹具钉不到**，只钉得住「尺寸没被改过、落位仍重合、收口复位」这组
几何事实——如实标注于第六节。

---

## 二、输入与边界

| 项 | 值 |
|---|---|
| 任务卡 | `Tasks/IC-20260910-144-video-exit-transition.md` |
| 基线 `main` | `e55937b7bc87b3f535a46b06038372ccbe90a07f`（`git rev-parse main` 实读，标题 `docs: IC-143` 开头 ✅） |
| 祖先核对 | `git merge-base --is-ancestor e498a28… main` → **真** ✅ |
| 开工工作树 | `git status --porcelain` 空 ✅（纪律 8） |
| 分支 | `feature/ic-144-video-exit-transition` |
| 被测提交 | **`3a857f7e0448fcbe68245c0543b1a018565fd437`** |
| 现状基数 | 736 项（IC-143 #285）→ 本卡 741 项（+5） |

**惯例 13（开工前逐个 grep 卡内点名符号）**：P1～P4、K1～K4、T1、T2、X1 共 20 余个
符号全部命中；`S2VideoPlayback.swift` 内基线 `.frame = ` 与
`CATransaction.setDisableActions(true)` 各 1 次（与 K2 的 ① 一致）。

---

## 三、CI 与本地门禁

### G833：CI #286

| 项 | 值 |
|---|---|
| 运行编号 | **#286**（run id `34487785643`，attempt 1） |
| 被测提交 | `3a857f7e0448fcbe68245c0543b1a018565fd437` |
| 结论 | `success`，全部步骤 `success`，无失败步骤 |
| XCTest | **`Executed 741 tests, with 0 failures (0 unexpected) in 102.766 (144.500) seconds`** |
| 真实退出码 | **0**（工作流 `set -o pipefail` + `exit "$test_status"`；日志 `test_status=0`） |
| 摘要 notice | 有（陷阱 20 的哨兵前提满足） |
| 目的地实证 | `-destination "platform=iOS Simulator,id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8"`；同份日志内该 UDID 为 **`OS:26.2, name:iPhone 16`** |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 **1379237**，SHA-256 `0034862cb116a559546123754caa2f816ed69709b59c6a7d0baf3eb6015d2c02` |
| 全局失败计数 | 日志内 `' failed (` 命中 **0** |

**CI 预算 3 次，实用 1 次**（#286 一次绿）。

### 本地门禁（最终 tip 实跑）

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** |
| `git diff --check` | **0** |
| `git status --porcelain` | 空 |

---

## 四、闸门逐条

### G831

| 条件 | 实测 |
|---|---|
| diff 限于白名单 | 5 个文件，全部在白名单内 ✅ |
| 分页器 hunk 只落在 P1～P3 | 4 个 hunk，**全部落在 `S2DoubleTapTransitionView`（1418～1436）即 P1** ✅ |
| `writePhotoGeometry` 计数 5 | **5** ✅ |
| `S2LivePhotoPlayback.swift` 两侧 SHA-256 相同 | `3092c28208f4e6d316787e92f9f895cf34a10ebe849c8c1dce3ec212d4fd1e12` ✅ |
| 残影快照函数体两侧字节相同 | `f45d761810f17be9b70f3d1bb29cf04437f4eb5b95654610007d27947c5cc4c8` ✅ |

**分页器 diff hunk 清单与对号**：

| hunk | 行号（新） | 落点 | 对号 |
|---|---|---|---|
| 1 | `1418` | `attachPlaybackLayer` 文档注释首行改写 | **P1** |
| 2 | `+1422,8` | 同上，补 IC-144 的根因说明 | **P1** |
| 3 | `+1431,2` | 函数体：算缩放比（`layerWidth`／`scale`） | **P1** |
| 4 | `1435,2` | 函数体：`transform` + `position` 取代 `frame` | **P1** |

**P2／P3／P4 零改动**——比卡内允许的范围更紧：`attachPlaybackLayer` 自己从
`playbackLayer.bounds` 取尺寸，不需要调用方传宿主 bounds 或缩放因子，
故 P2／P3 无需加实参。

**视频文件 hunk**：`328`（B 的 `park` 分支）、`+1003,2`（`.ready` 注释）、
`+1027,13`（三个断言入口）、`+1044,6`（借出期守卫）、`+1052,2`（变换复位）。

### G832

| 条件 | 实测 |
|---|---|
| `S2Calibration.swift`／`S2View.swift`／`S2StateMachine.swift` 不在 diff | 零命中 ✅ |
| `schemaVersion` 7 | `S2Calibration.swift:118 static let schemaVersion = 7` ✅ |
| 圆角／遮罩逻辑零改动 | 分页器 diff 内 `masksToBounds`／`cornerRadius` 命中 **0** ✅ |
| 冻结三链与探针分支未变 | `b368a6c` / `6736f1e` / `a7cc1ec` / `probe` `486bcb7` ✅ |
| `S2MediaMetrics` 登记值、过渡时长、音频会话、残影快照 | 均不在 diff ✅ |

### G833

绿、退出码 0、摘要 notice、iOS 26.2 / iPhone 16、IPA 已登记（第三节）；
七条断言逐条在 #286 日志里核到 `passed`（第六节）。

---

## 五、③ 根因：确认（探针数据 + 源码）

卡内 ③（唯一剩下的候选）：「借层时改了 `AVPlayerLayer` 的尺寸」。

**源码实证，进出两条路径的不对称成立**：

- 借层的摆放点 `attachPlaybackLayer` 改前写的是
  `playbackLayer.frame = bounds`（`S2NativePhotoPager.swift`，IC-143 C 引入）。
- 过渡视图的 `bounds` 来自 `sourceFrame`：
  `sourceFrame = presentationContentView.convert(presentationContentView.bounds, to: view)`
  （`S2NativePhotoPager.swift:1863-1866`）。
- **进 Nx**：此时 `zoomScale == 1`，`sourceFrame.size == presentationContentView.bounds.size`
  == 宿主 bounds 尺寸 ⟹ `frame = bounds` 对尺寸是**空转**，只重摆位置。
- **回 1x**：此时 `zoomScale > 1`，`convert` 把缩放算进去，`sourceFrame.size`
  是**放大后**的尺寸 ⟹ `frame = bounds` 把借出层的 `bounds` 从 1x 尺寸改成
  Nx 尺寸；收口 `reclaim` → `layoutSubviews` 又写回 1x 尺寸。**一次过渡两次改尺寸**，
  `AVPlayerLayer` 重建渲染表面，画面定格。

**与 ① 探针数据一致**：退出每次只丢 1 帧（最大间隔约 30 ms），与进入同量级
⟹ 过渡视图自身的 `CADisplayLink` 没停摆，卡的不是动画而是**图层内容**；
「退出带圆角遮罩致离屏渲染」的候选已被数据推翻（1x 提交圆角 = 0）。

**结论：卡内 ③ 确认，未被推翻。** 卡内没有为本项设停卡条件，按手段提示实装。

---

## 六、七条断言与测试函数名（#286 日志逐条核到 `passed`）

| 断言 | 测试函数 | 日志 |
|---|---|---|
| 1 退出路径借出层尺寸不变 | `IC144VideoExitTransitionTests.testIC144A_ExitTransitionKeepsTheBorrowedLayerSize` | passed |
| 2 进入路径同一组量 | `…testIC144A_EnterTransitionKeepsTheBorrowedLayerSize` | passed |
| 3 借出期间布局无副作用 | `…testIC144A_LayoutDuringLendingLeavesTheBorrowedLayerAlone` | passed |
| 4 源码扫描（带正对照） | `…testIC144A_AttachPlacesTheLayerWithoutResizingIt` | passed |
| 5 T1 四条与 IC-143 断言 9 原样通过 | `IC143VideoPolishTests` 的 `testIC143C_PlaybackLayerRidesTheDoubleTapTransitionAndComesBack`（**改容差**，见 change-list 第四节）、`…EarlyCollapsedTransitionAlsoReturnsThePlaybackLayer`、`…TheTransitionNeverTouchesPlaybackState`、`…PhotoPageTransitionAndAfterimageSnapshotAreUnchanged` | 四条全 passed |
| 6 `park` 对 `.ready` 发静音 | `…testIC144B_ParkingAReadyPageMutesItWithoutPausingOrSeeking` | passed |
| 7 T2 两条原样通过 | `IC141VideoPlaybackTests.testIC141A_LeavingAPageParksItAndReturningPlaysFromTheStart`、`…testIC141C_UnmutingAppliesToTheCurrentPageAndResetsOnPageChange` | 两条全 passed（**未改口径**，卡内「预期至多一处」实测 0 处） |

另：`testIC141B_PlaybackLayerWritesNoGeometryAndDrivesPlaybackFromOnePlace`
（钉 `.frame = ` / `CATransaction` 两族计数）**原样通过**——A 的收回路径刻意不
新增写入点，正是为它让路。

### 覆盖边界（如实标注，陷阱 1）

断言 1～3 是**夹具驱动，真机未覆盖**。夹具钉得住的是几何事实：借出期间
`playerLayer.bounds.size` 与借出前逐位相同（容差 1e-6）、落位与过渡视图 bounds
在 0.5 pt 内重合、收口后 `transform` 恒等且帧回宿主 bounds、层序不变、
借出期间的布局回调对三个量零影响。**钉不到**「用户眼里画面是否连续」——
那取决于 `AVPlayerLayer` 是否重建渲染表面，模拟器夹具里既无真 `AVPlayer`
也无真视频轨。**H67 第 1 项是这条修复的唯一验收**。

断言 1 带正对照：退出路径上实测 `transitionView.bounds.width >
借出前宽 + 0.5`，确认起始帧确实放大了，否则该断言测不到东西。

### 计数实测

| 项 | 值 |
|---|---|
| `writePhotoGeometry`（分页器） | **5** |
| `.frame = `（`S2VideoPlayback.swift`） | **1**（仍在 `layoutSubviews` 内） |
| `CATransaction.setDisableActions(true)`（同上） | **1** |
| `attachPlaybackLayer` 函数体内 `.frame =`／`.bounds =` | **0 / 0** |
| 同函数体内 `transform`／`position` | **各 ≥ 1**（正对照） |

---

## 七、人工判定项（H67，留给 Lynn 合并后真机，执行端不代为下结论）

1. 视频在播时双击放大、再双击回来，各做三次：**回 1x 全程画面连续**，不定格、不回第一帧、无黑块。
2. 双击进 Nx 仍连续；捏合与上滑残影与之前一样。
3. 进 S2 时第一张就是视频（此时不自动播）：点「有声」，翻走再翻回——翻回后自动播是**静音**的。
4. 回归：H66 第 1、4 项快过一遍。

---

## 八、发现但未处理的问题

1. **（执行端操作失误，登记）中途误用 `git checkout -q HEAD -- .`。**
   本意只是想看一眼已暂存的 diff，却在 `git stash push` 了单个文件之后执行了
   这条命令，把两处**未暂存**的改动一并回退（`IC143VideoPolishTests.swift` 的
   容差改动、`project.pbxproj` 的四处登记）。当即发现并逐项核对了损失范围，
   两处均已重做，产品代码未受影响，也未推送任何错误状态。
   **教训**：看 diff 用 `git diff --cached`，不要在有未暂存改动时碰 `checkout -- .`。

2. **A 的真机效果无法在 CI 侧证实。** 见第六节「覆盖边界」。若 H67 第 1 项仍报
   卡顿，下一步应量的是「`AVPlayerLayer` 在 `transform` 变化时是否仍重建渲染
   表面」——那需要真机探针，夹具无解。

3. **借出期守卫会让借出期间宿主 bounds 的真实变化被忽略。** 若过渡进行中宿主
   自身尺寸变了（如设备旋转），收回后才由 `layoutSubviews` 补上。横屏不纳入
   规格（v19），过渡仅 0.3 s，故未处理；登记备查。

4. **`attachPlaybackLayer` 取的是均匀缩放（按宽算）。** 借出层与过渡视图的宽高比
   在缩放容器里恒等（`zoomScale` 是均匀的），故按宽算与按高算等价；若日后引入
   非均匀缩放，这里需要改成分轴缩放。当前实测落位在 0.5 pt 内重合。

5. **`lentPlaybackViews` 持强引用**（IC-143 遗留，本卡未动）：若过渡从未收口，
   宿主的 `isLendingPlaybackLayer` 会停在 `true`，此后布局回调将一直跳过该层。
   实测路径上 `finishActiveDoubleTapTransition()` 必被调用（含 P4 早收口），
   且断言 3 覆盖了「收回后守卫不再挡正常路径」。登记备查。

6. **IC-143 报告第十一节其余六条仍未处理**（应用退后台不单独停用音频会话、
   拖动取消入口不含 UIKit 识别器 `.cancelled`、`isDragging` 与 `isScrubbing`
   两份状态等）。本卡只结清了第 2 条（`park` 不对称），其余按范围外处理。

7. **（执行端操作失误，登记）报告初稿写了一个臆造的 40 位 SHA。**
   第二节的基线 `main` 全 SHA 原是凭短前缀 `e55937b` 补全的 40 位串，仓库中
   不存在该对象——正是陷阱 15 明令禁止的做法。在跑 G834 前置时
   `git rev-parse main` 才发现不符，已订正为实读值，并对两份报告内所有 40 位
   SHA 逐个跑 `git cat-file -e` 存在性核验（全部 OK）。
   **教训**：报告里的每个 40 位 SHA 都必须来自实读命令的输出，写完即跑一遍
   存在性核验，不能等下一步偶然撞见。

---

## 九、G834 与 G835（合并后回填）

### G834（合并前置）

| 条件 | 实测 |
|---|---|
| G831 | 满足（第四节）✅ |
| G832 | 满足（第四节）✅ |
| G833 | 满足（第三、六节）✅ |
| 工作树净 | `git status --porcelain` 空 ✅ |
| `main` 未被他人推进 | `git ls-remote origin refs/heads/main` = `e55937b7bc87b3f535a46b06038372ccbe90a07f`，与本地 `main` 一致 ✅ |

四项齐备，已按卡内授权 `--no-ff` 合并并推送。

| 项 | 值 |
|---|---|
| 合并提交 SHA | **`ff7885b6fe5c381395d79217c29243b8e8ac8bf9`** |
| 合并前 `main` | `e55937b7bc87b3f535a46b06038372ccbe90a07f` |
| 被合并分支 tip | `e52e1f2`（其父 `94eae6a` 的父 `3a857f7` 即 #286 的被测提交） |
| 推送 | `e55937b..ff7885b  main -> main` |

### G835（合并后 `main` 自动运行）

| 项 | 值 |
|---|---|
| 运行编号 | **#287**（run id `34489655171`，attempt 1） |
| 被测提交 | `ff7885b6fe5c381395d79217c29243b8e8ac8bf9`（合并提交） |
| 结论 | `success`，全部步骤 `success`，无失败步骤 |
| XCTest 项数 / 失败数 | **741 / 0**（notice：`Executed 741 tests, with 0 failures (0 unexpected) in 39.295 (149.079) seconds`） |
| 真实退出码 | **0** |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 **1379237**，SHA-256 `102d1b7584f36bd0430d9b63729707798b095d3de28dda478c248a1814035e89` |

IPA 字节数与 #286 相同、SHA-256 不同——与 IC-094／097／141／143 的既有结论一致
（未签名 IPA 打包不可复现，跨运行身份不得用哈希判定，用树 diff）。

**本报告的回填方式**：G834／G835 的编号与 SHA 要等推送之后才产生，故按纪律 7 的
第二种方式——在**同一张卡、同一分支**内追加一个 docs 提交回填，不跨卡、不改写历史。
