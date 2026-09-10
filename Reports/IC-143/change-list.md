# IC-143 变更清单

被测提交：`ded93288b6e2fb1d467c2e7b99722a88fac8d268`
分支：`feature/ic-143-video-bar-polish`（自 `main` = `68f9422` 切出）
基线：`main` = `68f9422 docs: IC-141 回填 G824/G825`，`985fcfb`（IC-141 merge）为其祖先 ✅

---

## 一、提交清单（四子项各自独立 commit，A→B→C→D）

| # | SHA | 标题 | 子项 |
|---|---|---|---|
| 1 | `044fe95` | `feat(s2): IC-143 A 浮框几何与两键命中区` | A |
| 2 | `5fa7c48` | `fix(s2): IC-143 B 拖动异常终止兜底` | B |
| 3 | `ea21b22` | `fix(s2): IC-143 C 双击过渡画面连续（手段 i：借出活的播放层）` | C |
| 4 | `b510498` | `feat(s2): IC-143 D 「有声」接音频会话` | D |
| 5 | `ded9328` | `fix(s2): IC-143 收口两处实装细节` | 收尾 |

四个子项互不消费对方的类型，**可单独 cherry-pick**（卡内要求）。第 5 个提交是
推 CI 前对 D 的生产实现与两条断言写法的收口，不改行为。

---

## 二、文件级变更

| 文件 | 增/删 | 子项 | 说明 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | +66 / −7 | A・B・C | 登记值、两键命中区、异常终止接线 |
| `PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift` | +151 / −3 | B・C・D | `scrubCancelled`、借层协议与实现、音频会话 |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | +32 / −0 | C | 双击过渡借层／交还（纯新增，无删除） |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | +16 / −0 | B | `cancelTransientInterfaceHide()`（纯新增） |
| `PhotoCleanupMVETests/IC143VideoPolishTests.swift` | +1003（新文件） | 全部 | 13 个测试函数 |
| `PhotoCleanupMVETests/IC139MediaBadgesTests.swift` | +6 / −3 | A | 三条值断言改新值（见第四节） |
| `PhotoCleanupMVETests/IC141VideoPlaybackTests.swift` | +10 / −0 | B | 增断收口点恰一处（见第四节） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4 / −0 | 登记 | 新测试文件登记 |

`Localizable.xcstrings` **未改**——A 没有改动任何无障碍文案，卡内「预期无新键」成立。

---

## 三、取值表逐条落实

| 常量 | 卡内要求 | 实装 | 位置 |
|---|---|---|---|
| `videoBarHorizontalMargin` | `chromeHorizontalMargin * 2`（32），仍引用登记值 | `S2OverlayLayout.chromeHorizontalMargin * 2` | `S2View.swift:2836-2838` |
| `videoBarButtonIconPointSize` | 18 → 20 | `20` | `S2View.swift:2845` |
| `videoBarMuteIconPointSize` | 20 → 22 | `22` | `S2View.swift:2847` |
| `videoBarButtonHitWidth`（新） | `S2OverlayLayout.minimumTouchTarget`（44），引用非复制 | `S2OverlayLayout.minimumTouchTarget` | `S2View.swift:2853` |

**卡内点名不变的量，逐条实测未变**：`videoBarHeight` 44、`videoBarCornerRadius` 22、
`videoBarBottomToStripTop`、`videoBarHorizontalPadding` 14、`videoBarItemSpacing` 12、
`videoBarTrackHeight` 4、`videoBarTrackCornerRadius` 2、`videoBarKnobDiameter` 12、
`videoBarTimeFontSize` 13、`videoBarTrackOpacity` 0.28、四个符号名、
`videoBarTimeTrailingOpacity` 0.72、`videoBarScrubMinimumDistance` 2。

### 占位值登记

**`S2CalibrationConfiguration.schemaVersion` 仍为 7，未递增。**

理由（与卡内一致）：本卡改的四个量全部落在 `S2MediaMetrics`，那是**登记制常量**，
不进 `S2CalibrationConfiguration`、不上标定面板、不写 Keychain，因此不存在
「旧值覆盖新出厂值」的风险。`S2Calibration.swift` 不在本卡 diff 内（G827 已核）。

`minimumTouchTarget`（44）与 `chromeHorizontalMargin`（16）只被**引用**，两者的
定义一字未动。

---

## 四、既有测试改口径（旧 → 新，逐条）

卡内授权改两处，实测需要改的是**三条断言 + 一条新增**：

### 4.1 `IC139MediaBadgesTests.testIC139B_VideoBarGeometryReferencesRegisteredChromeConstants`

| # | 原断言 | 新断言 | 理由 |
|---|---|---|---|
| 1 | `videoBarHorizontalMargin == S2OverlayLayout.chromeHorizontalMargin` | `== S2OverlayLayout.chromeHorizontalMargin * 2` | 取值表第 1 行 |
| 2 | `videoBarButtonIconPointSize == 18` | `== 20` | 取值表第 2 行 |
| 3 | `videoBarMuteIconPointSize == 20` | `== 22` | 取值表第 3 行 |

该测试的**原意未变**（浮框几何引用登记值、不自造数），只是引用的倍数与两个字号
换了新登记值；同函数内其余 9 条断言一字未动。

> **卡内 ① 的一处偏差（登记）**：卡内 T2 写「对 `S2MediaMetrics` 的既有断言只有
> `videoBarHeight == 44` 与 `videoBarBottomToStripTop`（① 实读第 347～352 行）」。
> 实读发现 `IC139MediaBadgesTests` 有**两个**块碰 `S2MediaMetrics`：第 347～352 行
> 那个（`testIC142_...`，只断言那两条，本卡确实未触及、原样通过）；以及第 151～170 行
> 的 `testIC139B_VideoBarGeometryReferencesRegisteredChromeConstants`，它逐条钉了
> 12 个量，其中 3 个正是本卡改的。卡内已留出口子（「若另有对本卡改动值的断言，
> 改为新值并在报告列出旧→新」），故按该口子处理并在此登记。

### 4.2 `IC141VideoPlaybackTests.testIC141C_ScrubHandlersAreTheOnlyTransientHideCallSites`

| 原 | 新 |
|---|---|
| `begin…()` 恰 1 次；`end…()` 恰 1 次 | 两条**原样保留**，另加 `cancelTransientInterfaceHide()` 恰 1 次 |

B 给临时隐藏加了第三个写入点（无条件收口）。原断言的意图是「只有拖动路径碰临时
隐藏」，加上第三条后该意图仍然成立且更严——三个写入点各恰一处。

### 4.3 未改动的既有测试

`IC140LivePhotoPlaybackTests`（16 项）、`IC141VideoPlaybackTests` 其余 15 项、
`IC139MediaBadgesTests` 其余项、`S2CalibrationHarnessTests` 全部——一字未动。
特别地 `testIC141B_PlaybackLayerWritesNoGeometryAndDrivesPlaybackFromOnePlace`
（钉 `.frame = ` / `CATransaction` / `player.play()` 三族计数）**原样通过**，
C 的交还路径因此刻意不写帧（见自验报告第五节）。

---

## 五、pbxproj 登记

加登记**前**重扫各族最大号（陷阱：撞号不报错、文件会静默掉出编译列表）：

| 族 | 加登记前最大号 | 本卡取号 |
|---|---|---|
| 1（`PBXFileReference`） | `100000000000000000000042` | `100000000000000000000043` |
| 2（`PBXBuildFile`） | `20000000000000000000003F` | `200000000000000000000040` |
| 3 / 4 / 5 / 6 / 7 | `3000…0D` / `4000…06` / `5100…03` / `6000…02` / `7000…03` | 未取号 |

取号前实测两个新号在文件中命中数均为 **0**；加登记后唯一 id 数由 **161 → 163**（+2，
与新增两个 id 一致，无撞号）。

四处登记行：

```
44:  200000000000000000000040 /* IC143VideoPolishTests.swift（测试源码） */ = {isa = PBXBuildFile; fileRef = 100000000000000000000043 /* IC143VideoPolishTests.swift */; };
123: 100000000000000000000043 /* IC143VideoPolishTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IC143VideoPolishTests.swift; sourceTree = "<group>"; };
325:     100000000000000000000043 /* IC143VideoPolishTests.swift */,          ← 测试组 children
508:     200000000000000000000040 /* IC143VideoPolishTests.swift（测试源码） */,  ← 测试目标源码阶段 files = (
```

**目标归属实测**：应用目标源码阶段（`400000000000000000000001`）内 `IC143` 命中数 = **0**；
测试文件只进测试目标源码阶段（`400000000000000000000004`）。
