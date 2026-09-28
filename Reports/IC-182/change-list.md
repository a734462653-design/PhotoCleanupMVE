# IC-182 变更清单

任务卡：`Tasks/IC-20260927-182-tutorial-round-two.md`（教学引导二轮：学习那一下不翻页、三句统一右上、手势示意重画、浮层闪烁根因、S5 五步统一描边不分行）。
基线：`main` = `1d73bac47d12a307fe34f503b7085db84173dea0`。分支：`feature/ic-182-tutorial-round-two`。

## 一、提交（各自独立、按卡顺序）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `b65e53efdf07f613e50709f283919321a3b554fb` | `12a483a72e5a502f9bb4aa4f922f432683aeb89c` | `S2StateMachine.swift` 两处（A1 开关声明、A2 `handleSwipeUp` 标记后先判停留） |
| B | `6450f20b639e1ad238bb087d845e103e812619ce` | `ee41963ee0f16d6df6dde7e89ad2bf742f71bfc6` | `S2InlineHints.swift` 六处（B1～B6）、`S2View.swift` 六处（B7～B12）、IC179 三处期望（B13～B15） |
| C | `9aa95ba8aa5e5927b32f356485e5f66f37fc42af` | `be0454f4e1265f5841208fcd71b59fadabd468ed` | `S5GuideStepsView.swift` 五处（C1～C5）、IC180 四处期望（C6～C9） |
| D | `1dbf0136d07c16f1566790b17be7be91d1541098` | `5e70319a117256cd3777b9bb7e4909ad5ca3aa5c` | 新测试文件（逐字节拷入）+ pbx 测试登记四行（D1～D4） |

合并提交与 docs 提交见 `self-check.md` 第一节与第四节。

## 二、逐文件（白名单 8 路径，`git diff --name-only 1d73bac..1dbf013` 恰 8 行）

| 路径 | 子项 | 基线 blob | D 提交 blob | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | A | `3af1ca0b5f040cd5cb80a77793a21973834849bd` | `548a4c8d6be8e83724a40effb6421c8b968cfdc4` | A1 `pendingDeletionAssetIDs` 之后加 `var holdsPageAfterNextMark = false`（不发布、不入档、不入标定）；A2 `handleSwipeUp` 写 D 之后 `if holdsPageAfterNextMark && zoomState == .oneX { holdsPageAfterNextMark = false } else if !switchPhoto(by: 1) { pendingUndecidedItem = .item02 }` |
| `PhotoCleanupMVE/Features/S2/S2InlineHints.swift` | B | `3cf6195bb0dc6f731ebaabd31f9288f7342509b4` | `45fcebccd42048ab680c34bddf18f9bbb5a2d16c` | B1 示意文档注释；B2 `S2InlineHint.pointsAtConfirmEntry`；B3 `S2InlineHintSymbol` 加 `gestureHand`／`gestureArrowDown`／`gestureArrowRight`（3 → 6）；B4 协调器加只读 `holdsPageOnNextMark`；B5 `S2InlineHintMetrics` 整段（30 → 39：`centeredMaxWidth`／`gestureHintSpacing` 退役，手势示意九值 + 对比阴影两值入）；B6 `S2InlineHintLayer` 整段（三句气泡同一右上列、只有第 3 句带三角、示意在调用点 `.id(direction)`）+ 新视图 `S2InlineHintGestureView` |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | B | `71b209a6c059c72329e2d87bf5a0374b4be937df` | `ea216665a203b60b2900d4bc4cc21ab44386e38b` | B7 `inlineHintOverlay` 文档注释；B8 内层 `ZStack` 加 `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`（在 `.animation` 之前）；B9～B12 `machine.holdsPageAfterNextMark = hints.holdsPageOnNextMark` 四处（`hints.startIfNeeded(…)` 之后、待删集合回调末、新 `.onChange(of: hints.activeHint)`、「重看教程」`hints.reset()` 之后） |
| `PhotoCleanupMVETests/IC179InlineHintsTests.swift` | B | `cf1956472d752810e8b689d50bfdea24e863298a` | `d814f599df69211e7bbc0aed013839e3722367d2` | 断言 9 三处期望（见第三节） |
| `PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift` | C | `dd0c32358a5b6d49e379e5c3bb8e0039b28af595` | `f1fea670f5d192020c23f706354194d5e90f1d17` | C1 删 `isLeadStep`；C2 编号圆注释；C3 `S5GuideMetrics.textMinimumScaleFactor = 0.8`（12 → 13）；C4 正文 `.lineLimit(1)` + `.minimumScaleFactor(…)`；C5 `numberCircle` 统一描边（实心分支与 `@ViewBuilder` 退役） |
| `PhotoCleanupMVETests/IC180GuideStepsTests.swift` | C | `5ef2eec6827ed367c860f6c5931778747da932a2` | `28ff03e1b92f9e2acd36d5ed5593751f1b8f67ff` | 断言 1／3／4 四处期望（见第三节） |
| `PhotoCleanupMVETests/IC182TutorialRoundTwoTests.swift` | D（新建） | — | `0136baf20cc763a1cdedb69b1ed11968837bf327` | 逐字节拷自 `Tasks/decision-tools/IC182TutorialRoundTwoTests.swift`，五条测试 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | D | `b46d683f0052f941fd133e59ae2da0d5e42c1765` | `22a969715e66977f63926c1b7abe7e52490160bf` | 测试 PBXBuildFile 1、PBXFileReference 1、测试组 children 1、测试 Sources 1，四行照卡面原文 |

## 三、既有断言旧 → 新

| 文件 | 位置 | 旧 | 新 |
|---|---|---|---|
| `IC179InlineHintsTests.swift` 断言 9 | B13 | `S2TutorialGestureHint(direction:` 1；`S0DeckMetrics.` 7 | `S2TutorialGestureHint(direction:` 0 + 新钉 `S2InlineHintGestureView(direction:` 1；`S0DeckMetrics.` 10 |
| 同上 | B14 | `.frame(` 8（无消息）；`static let ` 30 | `.frame(` 8（消息改）；`static let ` 39 |
| 同上 | B15 | `.allowsHitTesting(false)` 4 | 5 |
| `IC180GuideStepsTests.swift` 断言 1 | C6 | `map(\.isLeadStep) == [true, false, false, false, false]` | 删除该行 |
| 同上 断言 3 | C7 | — | 新增 `textMinimumScaleFactor == 0.8` |
| 同上 断言 4 | C8 | `S1ChromeForeground.` 6、`in: Circle())` 1 | `S1ChromeForeground.` 4、`in: Circle())` 0 + 新钉 `isLeadStep` 0／`.lineLimit(1)` 1／`.minimumScaleFactor(S5GuideMetrics.textMinimumScaleFactor)` 1 |
| 同上 | C9 | `static let ` 12 | 13 |

## 四、新增测试（5 条，935 → 940）

1. `testIC182A_HoldAfterFirstMarkOnlyOnce`
2. `testIC182A2_CoordinatorDecidesHoldExactlyWhenMarkedOnceWouldAppear`
3. `testIC182B_PlacementRulesGestureMetricsAndSymbols`
4. `testIC182C_SourceWiring`
5. `testIC182D_CatalogUntouched`

## 五、占位值登记

- 无出厂值变更，`S2CalibrationConfiguration.schemaVersion` 仍 **7**。
- 视觉登记（卡内暂登，SPEC-S2 v23／SPEC-S5 v7 回填）：`S2InlineHintMetrics` 39 值（新增 `gestureCircleSide` 56、`gestureCircleFillOpacity` 0.18、`gestureHaloWidth` 8、`gestureHaloOpacity` 0.08、`gestureHandPointSize` 28、`gestureArrowPointSize` 28、`gestureSpacing` 6、`gestureTravel` 40、`gestureCycleSeconds` 0.9、`gestureShadowOpacity` 0.35、`gestureShadowRadius` 3；退役 `centeredMaxWidth` 340、`gestureHintSpacing` 24）；`S2InlineHintSymbol` 6 名（新增 `hand.point.up.left`／`arrow.down`／`arrow.right`）；`S5GuideMetrics` 13 值（新增 `textMinimumScaleFactor` 0.8）。
- 目录 `Localizable.xcstrings` 未动（281 条，blob `911848e37193b1491b60274549db5ec1c0425a33`）。

## 六、pbxproj 新 id

| id | 类型 | 对象 |
|---|---|---|
| `100000000000000000000081` | PBXFileReference | `IC182TutorialRoundTwoTests.swift` |
| `20000000000000000000007E` | PBXBuildFile | `IC182TutorialRoundTwoTests.swift（测试源码）` |

## 七、未改动（「不得打红」段）

`Core/` 除 `S2StateMachine.swift` 外全部；`Services/`、`App/`；`Features/S0`、`S1`、`S3`、`S4`、`S5`；`Features/S2/` 除 `S2View.swift`／`S2InlineHints.swift` 外全部（含 `S2NativePhotoPager.swift`）；`Features/Shared/` 除 `S5GuideStepsView.swift` 外全部；`Localizable.xcstrings`；`.github/`、`Scripts/`；除 IC179／IC180 与新测试外全部测试文件——两侧对象逐一相同（`self-check.md` 第九节）。
