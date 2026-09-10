# IC-144 变更清单

被测提交：`3a857f7e0448fcbe68245c0543b1a018565fd437`
分支：`feature/ic-144-video-exit-transition`（自 `main` = `e55937b` 切出）
基线：`main` = `e55937b docs: IC-143 回填 G829/G830`，`e498a28`（IC-143 merge）为其祖先 ✅

---

## 一、提交清单（两子项各自独立 commit，A→B）

| # | SHA | 标题 | 子项 |
|---|---|---|---|
| 1 | `801d0ce` | `fix(s2): IC-144 A 借出的播放层不改尺寸（双击回 1x 画面连续）` | A |
| 2 | `3a857f7` | `fix(s2): IC-144 B park 对 .ready 态补静音` | B |

两者互不依赖：A 只碰借层的摆放方式，B 只碰 reducer 的 `park`；**各可单独
cherry-pick**（卡内要求）。为此在提交前把 B 的两处改动（`park` 分支 + 断言 6
测试函数）临时摘出，A 提交后再放回——两个提交因此都是自洽的。

---

## 二、文件级变更

| 文件 | 增/删 | 子项 | 说明 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | +14 / −1 | A | `attachPlaybackLayer` 改摆位置与缩放 |
| `PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift` | +28 / −2 | A・B | 借出期布局守卫、变换复位、三个断言入口；`park` 的 `.ready` 分支 |
| `PhotoCleanupMVETests/IC144VideoExitTransitionTests.swift` | +542（新文件） | 全部 | 5 个测试函数 |
| `PhotoCleanupMVETests/IC143VideoPolishTests.swift` | +18 / −5 | A | 借出期帧断言改容差（见第四节） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4 / −0 | 登记 | 新测试文件登记 |

`S2View.swift`、`S2StateMachine.swift`、`S2Calibration.swift`、
`Localizable.xcstrings` **均未改**（G832 已核）。

---

## 三、A 采用的手段与理由

**手段**：`attachPlaybackLayer` 不再写 `frame`／`bounds`，改摆
`position`（过渡视图 bounds 中心）与 `transform`（均匀缩放 = 过渡视图 bounds 宽
÷ 借出层 bounds 宽）；`layoutSubviews` 加借出期守卫，收回后**先复位变换再写帧**。
即卡内「手段提示」那条，未另辟蹊径。

**理由**：

1. 过渡靠 `transform` 推进、过渡视图 `bounds` 全程不变，所以借出层只需摆一次，
   不必逐帧跟随——不触碰陷阱 5／6 的任何禁止项。
2. 不改 `bounds` 就不会让 `AVPlayerLayer` 重建渲染表面，这正是缺陷的根。
3. 复位与写帧都留在 `layoutSubviews` 那一处，**写入点零新增**：
   `S2VideoPlayback.swift` 内 `.frame = ` 与 `CATransaction.setDisableActions(true)`
   仍各 1 次，IC-141 断言 5 原样通过（卡内「其余测试不动」的硬约束）。
4. 借出期守卫是必需的：不加的话，退出路径上刚摆好的 Nx 落位会被任何一次
   布局回调改回 1x，等于把「不改尺寸」的收益抵消掉（断言 3 钉这一条）。

**为什么不写 `frame`**：带非恒等 `transform` 时写 `frame` 是未定义行为
（Apple 明载），故复位顺序是「先 `transform = identity`，再 `frame = bounds`」。

---

## 四、既有测试改口径（旧 → 新）

### 4.1 `IC143VideoPolishTests.testIC143C_PlaybackLayerRidesTheDoubleTapTransitionAndComesBack`

| 原断言 | 新断言 | 理由 |
|---|---|---|
| `XCTAssertEqual(diagnosticPlaybackLayerFrame, transitionView.bounds)`（`CGRect` **逐位相等**） | 四个分量（minX／minY／width／height）各按 **0.5 pt 容差**比对 | A 起借出层的落位由「浮点缩放比 × 层尺寸」得出，逐位相等不再成立；0.5 pt 是卡内规格第 1 条给的容差 |

同函数内其余断言（承载者身份、收口后帧 == 宿主 bounds、层序、借出标志）
**一字未动**，且都在 #286 绿。

**这一条是开工时主动改的，不是被 CI 逼出来的**——按陷阱 23，动既有函数的断言
前先读了同族测试，发现它对 `CGRect` 用的是逐位相等，据此预判浮点除法会让它失效。

### 4.2 未改动的既有测试（卡内断言 5、7 点名的七条，逐条在 #286 核到 `passed`）

`testIC143C_EarlyCollapsedTransitionAlsoReturnsThePlaybackLayer`、
`testIC143C_TheTransitionNeverTouchesPlaybackState`、
`testIC143C_PhotoPageTransitionAndAfterimageSnapshotAreUnchanged`、
`testIC141B_PlaybackLayerWritesNoGeometryAndDrivesPlaybackFromOnePlace`、
`testIC141A_LeavingAPageParksItAndReturningPlaysFromTheStart`、
`testIC141C_UnmutingAppliesToTheCurrentPageAndResetsOnPageChange`
——全部**原样通过**，B 未改到任何一条的效果序列预期（卡内「预期至多一处」实测为 **0 处**）。

`IC140LivePhotoPlaybackTests` 在 #286 日志内 passed 36 条、failed 0 条。

---

## 五、pbxproj 登记

加登记**前**重扫各族最大号（陷阱：撞号不报错、文件会静默掉出编译列表）：

| 族 | 加登记前最大号 | 本卡取号 |
|---|---|---|
| 1（`PBXFileReference`） | `100000000000000000000043`（IC-143） | `100000000000000000000044` |
| 2（`PBXBuildFile`） | `200000000000000000000040`（IC-143） | `200000000000000000000041` |
| 3 / 4 / 5 / 6 / 7 | `3000…0D` / `4000…06` / `5100…03` / `6000…02` / `7000…03` | 未取号 |

取号前实测两个新号命中数均为 **0**；加登记后唯一 id 数由 **163 → 165**（+2，无撞号）。

四处登记行：

```
45:  200000000000000000000041 /* IC144VideoExitTransitionTests.swift（测试源码） */ = {isa = PBXBuildFile; fileRef = 100000000000000000000044 /* IC144VideoExitTransitionTests.swift */; };
125: 100000000000000000000044 /* IC144VideoExitTransitionTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IC144VideoExitTransitionTests.swift; sourceTree = "<group>"; };
328:     100000000000000000000044 /* IC144VideoExitTransitionTests.swift */,          ← 测试组 children
512:     200000000000000000000041 /* IC144VideoExitTransitionTests.swift（测试源码） */,  ← 测试目标源码阶段 files = (
```

**目标归属实测**：应用目标源码阶段（`400000000000000000000001`，正文止于第 483 行）
内 `IC144` 命中数 = **0**；测试文件只进测试目标源码阶段（`400000000000000000000004`）。

### 占位值登记

**`S2CalibrationConfiguration.schemaVersion` 仍为 7，未递增。** 本卡未新增或改动
任何出厂值与登记常量——`S2MediaMetrics` 一字未动，`S2Calibration.swift` 不在 diff 内。
