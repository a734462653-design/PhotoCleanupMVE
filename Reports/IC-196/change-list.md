# IC-196 变更清单

- 任务标识：`IC-20261009-196-s2-guide-d-views`（S2 教学引导 D 的界面层 D2a：登记值、符号、纯几何与运动、教练卡／四点指示／跳过钮／完成卡／第 4 步指向／手势示范／进门压暗与两只层视图 + 目录十一条 `s2.guide.*`；不接线，无界面变化）
- 基线：`main` = `0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c`；分支 `feature/ic-196-s2-guide-d-views`；合并提交 `33ce39f6838925a52050168c3d5c349f1f458ba5`。

## 一、提交（各自独立、按卡顺序 A → B）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `c83256ac28f8509880b1ce3fd7748371b97c3ce2` | 新文件 `S2GuideDViews.swift`（登记值、符号、几何与运动、全部视图）+ `Localizable.xcstrings` 新增十一条 `s2.guide.*` + pbx 源码登记（3 个文件） | 可单独摘 |
| B | `55ab4c01963999c0539465152d8955afbff4e3ef` | 新测试 `IC196GuideDViewsTests` 五条 + pbx 测试登记（2 个文件） | 只能 A→B（用到 A 的全部新符号与新 key） |
| 合并 | `33ce39f6838925a52050168c3d5c349f1f458ba5` | `merge(IC-196): S2 教学引导 D 的界面层——登记值、符号、几何与运动、教练卡与完成卡、第 4 步指向、手势示范、进门压暗与两只层视图 + 目录十一条；不接线` | — |

可摘单元：A；A→B（克隆里 `cherry-pick -x` 全部干净，结果树逐个等于分支上的树，见 `self-check.md` 第五节）。

## 二、逐文件（白名单 4 路径，`git diff --name-only 0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c..55ab4c01963999c0539465152d8955afbff4e3ef` 恰 4 行；增删行取自 `git diff --numstat`，合计 1702 增 0 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2GuideDViews.swift` | A | 1039 | 0 | 新文件（`import SwiftUI`，无 `@MainActor`、零 `Text("`／`return "`、零含汉字代码行）：`S2GuideDSymbol`（7）、`S2GuideDMetrics`（87）、`S2GuideGestureDirection`、`S2GuideGestureMotion`、`extension S2GuideStep`（序号／标题／副句／圆底符号／前置符号）、`S2GuideDLayout`（纯几何与运动）、视图 `S2GuideDSurface`／`S2GuideStepDots`／`S2GuideSkipButton`／`S2GuideCoachCard`／`S2GuideCoachPointer`／`S2GuideConfirmHighlight`／`S2GuideCompletionCard`／`S2GuideGestureDemo`／`S2GuideIntroScrim`／`S2GuideDCardLayer`／`S2GuideDGestureLayer`；逐字节拷入 |
| `PhotoCleanupMVE/Localizable.xcstrings` | A | 121 | 0 | 新增十一条 `s2.guide.*`（`completed`／`confirm`／`confirm.sub`／`marked`／`marked.sub`／`progress`／`skip`／`swipe_up`／`swipe_up.sub`／`undone`／`undone.sub`），插在 `s2.hint.confirm` 之前；其余条目逐字不动；289 → 300 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、B | 8 | 0 | A 四行（`S2GuideDViews.swift`：fileRef `100000000000000000000099`、buildFile `200000000000000000000096`、`S2` 组 children、源码 Sources 阶段）；B 四行（`IC196GuideDViewsTests.swift`：fileRef `10000000000000000000009A`、buildFile `200000000000000000000097`、测试组 children、测试 Sources 阶段） |
| `PhotoCleanupMVETests/IC196GuideDViewsTests.swift` | B | 534 | 0 | 新文件，五条 `testIC196A`～`testIC196E`，逐字节拷入 |

## 三、测试

- XCTest 986 → **991**（+5，`IC196GuideDViewsTests`）。
- 随改的既有断言：无。
- CI：分支 #396（run `37981100828`）绿 991／0；合并后 `main` #397（run `37983377590`）绿 991／0；artifact `PhotoCleanupMVE-unsigned-33ce39f68389`（id `11641474475`，有效期至 2027-01-07T19:54:13Z）。

## 四、占位值登记

无。本卡不改 `S2CalibrationConfiguration`（`schemaVersion` 仍 7）、不加字段、不改出厂值；`S2GuideDMetrics` 的 87 个登记值是视图层常量，不入标定出厂值、不上标定面板。

## 五、范围外（本卡未动）

`S2View.swift`、`S2InlineHints.swift`、`S2GuideD.swift`、`S2StateMachine.swift`；七条 `s2.hint.*` 与十条 `s2.tutorial.*`；`IC179`／`IC182`／`IC195` 三个既有测试文件；协调器、App 入口；`S2CalibrationConfiguration`；`Scripts/`、`.github/`；SPEC 与 Decision_log。接线（`S2View` 从 `hints` 切到 D1 协调器 + 本卡两只层与压暗）、旧三句退役、IC179／IC182 改写、`IC195GuideDLogicTests.testIC195H_SourceWiring` 末段改写归 D2b。

## 六、人工判定项

无（本卡不接线；观感、层级、命中、动画与未定项 37、38 的取舍归 D2b 的 H 判定）。
