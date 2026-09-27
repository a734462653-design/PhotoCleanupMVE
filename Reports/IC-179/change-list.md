# IC-179 变更清单

- 任务卡：`<top>/Tasks/IC-20260926-179-inline-hints.md`
- 基线：`main` = `c1003ea93b5bacda7b2dd6037bfc01a2d0e2e119`
- 分支：`feature/ic-179-inline-hints`（tip `3de160993edf5e3479de325d4d996735ea27743b`）
- 合并：`ae26e20cdda6b09a8ea57eb4e53742374560cf0d`（`--no-ff`，合并树 = C 的树）
- CI：分支 #362（run `36280860146`）绿 925／0；合并后 `main` #363（run `36281506459`）绿 925／0
- 白名单路径 5 个（`git diff --name-only c1003ea..3de1609` 恰此 5 个）；报告两份按惯例 44 落合并后 `main` 的单个 docs 提交

## 提交与文件

| 子项 | 提交 | 文件 | 变更 |
|---|---|---|---|
| A | `831532bfc6dd62742743081506e980682575e737` | `PhotoCleanupMVE/Features/S2/S2InlineHints.swift` | 新建，自 `<top>/Tasks/decision-tools/S2InlineHints.swift` 逐字节拷入（blob `3cf6195bb0dc6f731ebaabd31f9288f7342509b4`，473 行）：`S2InlineHint`（三 case）、`S2InlineHintSymbol`、`S2InlineHintStoring` + `S2UserDefaultsInlineHintStore`（键前缀 `com.iphonephotomanagement.PhotoCleanupMVE.s2.hint.`）、`S2InlineHintCoordinator`（`confirmThreshold` 5、`markedOnceAutoDismissSeconds` 6）、`S2InlineHintMetrics`（30 值）、`S2InlineHintBubble`、`S2InlineHintLayer` |
| A | 同上 | `PhotoCleanupMVE/Localizable.xcstrings` | `s2.feedback.favorite_failed` 之后插入七条：`s2.hint.confirm`、`.confirm.sub`、`.dismiss`、`.marked`、`.marked.sub`、`.swipe_up`、`.swipe_up.sub`（262 → 269） |
| A | 同上 | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 产品文件登记四行：PBXBuildFile `200000000000000000000077`、PBXFileReference `10000000000000000000007A`、S2 组 children、Sources 阶段 |
| B | `09d83b1b5b4042747211d691f7118bedc58aa421` | `PhotoCleanupMVE/Features/S2/S2View.swift` | 九处单点替换：B1 新增 `@StateObject hints`（教程实例注释补「停用不删」）；B2 `.onAppear` 的 `tutorial.startIfNeeded()` → `hints.startIfNeeded(mergedCount:)`；B3 `.onDisappear` 追加 `hints.leaveScreen()`；B4 标记集合回调体尾追加新增／移除两个 `if`；B5 计数回调体首句 `hints.mergedCountDidChange(count)`（残影守卫之前）；B6 `inlineHintOverlay(...)` 挂在 `tutorialOverlay` 之后、`S2SafeAreaInsetsReader` 之前；B7 新 builder `inlineHintOverlay`（`.task(id: hint)` 限时、`.animation`、`s2ChromeVisibilityTransition`）；B8 右上入口 guard 之后 `hints.confirmEntryTapped()`；B9 「重看教程」`tutorial.replay()` → `hints.reset()`（+83／−4 行） |
| C | `3de160993edf5e3479de325d4d996735ea27743b` | `PhotoCleanupMVETests/IC179InlineHintsTests.swift` | 新建，自 `<top>/Tasks/decision-tools/IC179InlineHintsTests.swift` 逐字节拷入（blob `cf1956472d752810e8b689d50bfdea24e863298a`，526 行，九条测试） |
| C | 同上 | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 测试文件登记四行：PBXBuildFile `200000000000000000000078`、PBXFileReference `10000000000000000000007B`、测试组 children、测试 Sources 阶段 |

## 最终文件 blob（C 提交 = 合并后 `main`）

| 路径 | blob |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | `71b209a6c059c72329e2d87bf5a0374b4be937df` |
| `PhotoCleanupMVE/Localizable.xcstrings` | `8974a1db6077befc22864ba346c2d1bb55284590` |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `b72c57ba486ca46c3b016a1b5a89b4de79552315` |
| `PhotoCleanupMVE/Features/S2/S2InlineHints.swift` | `3cf6195bb0dc6f731ebaabd31f9288f7342509b4` |
| `PhotoCleanupMVETests/IC179InlineHintsTests.swift` | `cf1956472d752810e8b689d50bfdea24e863298a` |

## 占位值登记

- `S2CalibrationConfiguration.schemaVersion` 仍 **7**：三个「已会」走 `UserDefaults`，不入标定出厂值，出厂值集合未变。
- 新增登记值（卡内暂登，待 SPEC-S2 v23 第十一节回填）：`S2InlineHintMetrics` 三十个 `static let`；协调器 `confirmThreshold` 5、`markedOnceAutoDismissSeconds` 6（④ 决策会话卡内取定）。色只引用 `S0DeckMetrics.text`／`background`／`accent`，`S0DeckMetrics` 仍 195。

## 未改动（按卡保留）

旧六步教程的全部类型、`tutorialOverlay` builder、4 个 `.onChange` 里的 5 处 `tutorial.*` 调用、`tutorial.leaveScreen()`、相簿 sheet 提示条、步骤 ⑥ 白底强调态、`.disabled(... || tutorial.isRunning)`、`Services/S2TutorialCompletionStore.swift`、十条 `s2.tutorial.*` key、`S2ActionBarWiringTests.swift`；S0／S1／S3／S4／S5／Shared／App／Core／Services、`.github`、`Scripts` 全部对象与基线相同。
