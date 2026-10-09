# IC-197 变更清单

- 任务标识：`IC-20261009-197-s2-guide-d-wiring`（S2 教学引导 D 的接线与 v23 三句退役 D2b：`S2View` 换接引导 D 的协调器与三层视图；删 `S2InlineHints.swift` 与七条 `s2.hint.*`；IC179 整删、IC182／IC195 改写、新测试三条；**有界面变化，人工判定 H103 保留给 Lynn**）
- 基线：`main` = `d6d7e2413358003af717636e7ec09c317fa1d80d`；分支 `feature/ic-197-s2-guide-d-wiring`；合并提交 `e754fcd3b457025534b311ddd0006acf5fa84aa8`。

## 一、提交（各自独立、按卡顺序 A → B）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `0fbe51ab7d30e9c553e7a0e01e00f45425020dd7` | `S2View.swift` 换接引导 D + 删 `S2InlineHints.swift` + `Localizable.xcstrings` 删七条 `s2.hint.*` + pbx 删四行（4 个路径） | **单独摘取时测试目标编译红**（IC179／IC182 引用被删类型），只能与 B 连续 |
| B | `1f079fcf7bb2a892d783ec14be997b475a4fb89c` | 删 `IC179InlineHintsTests.swift` + 改写 `IC182TutorialRoundTwoTests`／`IC195GuideDLogicTests` + 新测试 `IC197GuideDWiringTests` 三条 + pbx（5 个路径） | 只能 A→B（依赖 A 的接线与文件删除） |
| 合并 | `e754fcd3b457025534b311ddd0006acf5fa84aa8` | `merge(IC-197): S2 教学引导 D 接线——S2View 换接引导 D 的协调器与三层视图、v23 三句与七条 s2.hint.* 退役` | — |

可摘单元：A→B（克隆里 `cherry-pick -x` 全部干净，结果树等于分支上 B 的树，见 `self-check.md` 第五节）。

## 二、逐文件（白名单 8 路径，`git diff --name-only d6d7e2413358003af717636e7ec09c317fa1d80d..1f079fcf7bb2a892d783ec14be997b475a4fb89c` 恰 8 行；增删行取自 `git diff --numstat`，合计 752 增 1460 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A | 136 | 71 | `@StateObject hints` → `guide = S2GuideCoordinator()` + `@State guideStarted`；`.onAppear` 只开一次引导并同步停留开关；`.onDisappear` `guide.leaveScreen()`；`.onChange(of: guide.display)` 同步开关；`V` 回调写 `guide.isInterfaceVisible`；待删集合、当前张、合并计数三个既有回调体内追加引导事件（先写可见、再调事件、末尾同步开关；两个一次性信号只在体内同步读）；确认入口 guard 之后 `guide.confirmEntryTapped()`；面板「重看教程」`guide.reset()`；挂三层（压暗在主图之后、chrome 之前；手势示范在中央状态指示之前；教练卡层取代旧三句层）与三个 builder `guideIntroScrimOverlay`／`guideGestureOverlay`／`guideCardOverlay`、`guideLearnedSteps`；完成提示 2 秒计时 `.task(id: guide.display)`；逐字节拷入 |
| `PhotoCleanupMVE/Features/S2/S2InlineHints.swift` | A | 0 | 592 | **整文件删**（v23 三句的协调器、存储、气泡、层、手势示意）；`git rm` |
| `PhotoCleanupMVE/Localizable.xcstrings` | A | 0 | 77 | 删 `s2.hint.confirm`／`confirm.sub`／`dismiss`／`marked`／`marked.sub`／`swipe_up`／`swipe_up.sub` 七条，其余逐字不动；300 → 293 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、B | 4 | 8 | A 删 `S2InlineHints.swift` 四行（fileRef `10000000000000000000007A`／buildFile `200000000000000000000077`）；B 删 `IC179InlineHintsTests.swift` 四行（`10000000000000000000007B`／`200000000000000000000078`）、加 `IC197GuideDWiringTests.swift` 四行（fileRef `10000000000000000000009B`／buildFile `200000000000000000000098`，接在 `IC196GuideDViewsTests.swift` 之后） |
| `PhotoCleanupMVETests/IC179InlineHintsTests.swift` | B | 0 | 528 | **整文件删**（九条全测退役符号；仍有效的六步教程接线钉子移入新测试 C，「与旧六步教程完成标志互不相干」移入 IC195F）；`git rm` |
| `PhotoCleanupMVETests/IC182TutorialRoundTwoTests.swift` | B | 25 | 170 | 保留 A；整删 A2 与 B；C 的 S2View 段改钉「六处同步」、旧提示文件段整删、`S5GuideMetrics.textMinimumScaleFactor` 0.8 移入；D 改名 `testIC182D_CatalogHintKeysRetired`；删文件私有的旧内存存储；逐字节拷入 |
| `PhotoCleanupMVETests/IC195GuideDLogicTests.swift` | B | 17 | 14 | 测试 F 不再用 `S2UserDefaultsInlineHintStore`（v23 键按字面前缀与后缀钉、旧键直接 `defaults.set`、补「与旧六步教程完成标志互不相干」）；测试 H 末段改钉「v23 文件已不在、S2View 构造协调器 1 与两个信号各读 1、不另构造存储」；逐字节拷入 |
| `PhotoCleanupMVETests/IC197GuideDWiringTests.swift` | B | 570 | 0 | 新文件，三条 `testIC197A`～`testIC197C`（A／B 接线镜像 + 真实 `S2StateMachine` + 内存存储；C 源码落位），逐字节拷入 |

## 三、测试

- XCTest 991 → **983**（−9 `IC179InlineHintsTests`、−2 `IC182`、+3 `IC197GuideDWiringTests`）。
- 随改的既有断言：`IC182TutorialRoundTwoTests`（A2、B 整删；C、D 改写；D 改名）、`IC195GuideDLogicTests`（F、H 末段）；其余既有测试未改。
- CI：分支 #398（run `37991128426`）绿 983／0；合并后 `main` #399（run `37992939159`）绿 983／0；artifact `PhotoCleanupMVE-unsigned-e754fcd3b457`（id `11647005582`，有效期至 2027-01-07T21:21:19Z）。

## 四、占位值登记

无。本卡不改 `S2CalibrationConfiguration`（`schemaVersion` 仍 7）、不加字段、不改出厂值。

## 五、范围外（本卡未动）

`S2GuideD.swift`、`S2GuideDViews.swift`、`S2StateMachine.swift`；六步教程的类型与接线（停用不删）；`IC196GuideDViewsTests` 与白名单之外的测试；`S5GuideStepsView.swift`（其文档注释提到 `S2InlineHintSymbol`，只是注释）；协调器、App 入口；`S2CalibrationConfiguration`；`Scripts/`、`.github/`；SPEC 与 Decision_log。

## 六、人工判定项

**H103（十二条，原文在 `self-check.md` 第十一节）保留给 Lynn 真机判定。** 装合并后 `main` 产物；先在 S2 标定面板点「重看教程」。执行端没有做任何真机或观感判断。
