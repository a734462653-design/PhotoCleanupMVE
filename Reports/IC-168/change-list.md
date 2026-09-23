# IC-168 变更清单

> 任务卡：`<top>/Tasks/IC-20260923-168-s2-exit-diagnostics-and-fallback-toast.md`。本清单与 `self-check.md` 同在合并后 `main` 上的恰一个 docs 提交里（惯例 44）。

## 一、分支、提交与合并

| 项 | 值 |
|---|---|
| 基线 | `main` = `c80a1ddc684aa2acff59084ba7b151825584d65b`（IC-167 报告补记；IC-167 merge `81effe7c388e6b18560ee284d4cab7d575eca2b1` 是其祖先） |
| 分支 | `feature/ic-168-s2-exit-diagnostics`（自基线切出，已推送，保留不删） |
| 子项 A | `3445ef54baf2d56fdec478ecc68208c069f8d4d6` `feat(IC-168): 子项 A 在途虚拟范围撤销——…`（3 个文件，+21／−1） |
| 子项 B | `9fbc22b99b42126582f8e48071cff00c83456ab5` `feat(IC-168): 子项 B 守卫命名与离开 S2 的诊断文本——…`（1 个文件，+312／−42） |
| 子项 C | `9a2f992d72af3966e5f5121971e95d0ca003852d` `feat(IC-168): 子项 C S2 标定面板末段显示退出诊断——…`（3 个文件，+62／−2） |
| 子项 D | `0fe9de0902274ec9643b571d72a3f958a9ffd045` `feat(IC-168): 子项 D 清理 tab 回落 toast——…`（3 个文件，+76／−15） |
| 子项 E | `5dd36d3f908a7f76abd0bb5dfd3099eb80c947d3` `feat(IC-168): 子项 E 类别页进入 S2 失败提示——…`（9 个文件，+44／−21） |
| 子项 F | `e7c1be085102b5d9685b0863f29feb6bfa006a38` `test(IC-168): 子项 F 新断言六条——…`（2 个文件，+647） |
| 合并 | `8dba3fdde4bee6763cd4d5cc6443107b8c55dd82` `merge(IC-168): S2 → S3 回落在清理 tab 可见并可复制诊断、在途虚拟范围撤销、类别页进入失败提示`，`--no-ff`，父 `c80a1dd` + `e7c1be0`，树 `9803e9a1e6a32ff8cf80b4d950c223458d1130dd`（= F 的树） |
| 报告 | 本 docs 提交（合并后 `main` 运行之后，直接落在 `main` 上） |

`git diff --stat c80a1dd e7c1be0`：15 个文件，+1162／−81，恰为卡面白名单 15 个路径（产品 6、目录 1、工程 1、测试 7）。

## 二、子项 A · 在途登记撤销（裁定 二）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `makeS2Handoff(virtualRangeID:…)` 之后、`makeS3Submission()` 之前加 `func cancelS2Handoff(virtualRangeID: String) { activeVirtualRangeIDs.remove(virtualRangeID) }`（`:724`，带文档：只删内存态登记、名字表不动、不走写出口、真实范围标识无操作） |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `returnToS1AfterFailedWriteBack()` 首行（`clearS2RouteState()` 之前）加 `if let entryContext = s2EntryContext { s1Machine?.cancelS2Handoff(virtualRangeID: entryContext.rangeID) }`，文档补两行 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `onEnterS2` 闭包末句 `return coordinator.enterS2(from: handoff)` 改为 `guard coordinator.enterS2(from: handoff) else { s1Machine.cancelS2Handoff(virtualRangeID: virtualRangeID); return false }; return true`（分行写，上方一行注释） |

## 三、子项 B · 守卫命名与诊断文本（裁定 一）

只动 `PhotoCleanupMVE/App/CleanupCoordinator.swift`：

| 位置 | 改动 |
|---|---|
| 属性区 `:51-54` | `@Published private(set) var s2ExitDiagnosticsText: String?`（带文档） |
| 属性区 `:69-70` | `private var lastS3EntryGuardFailure: S2ExitDiagnosticGuard?`（带文档） |
| `leaveS2(with:)` `:228` | 首句 `let sample = sampleS2Exit(payload)`；E1 失败：`let failure = sample.writeBackFailure` → `let reconciled = returnToS1AfterFailedWriteBack()` → `recordS2ExitDiagnostics(entry: "back", …, outcome: "writeBackFailed", failure: failure)` → `return false`；成功：`clearS2RouteState()` → `let reconciled = reconcileS1WithPhotoLibrary()` → `route = .s1; message = nil` → 记录 `outcome: "ok", failure: nil` → `return true` |
| `returnToS1AfterFailedWriteBack()` `:276` | 改 `private func returnToS1AfterFailedWriteBack() -> Bool`（不加 `@discardableResult`），`let reconciled = reconcileS1WithPhotoLibrary()`，末尾 `return reconciled`；步骤与先后不变 |
| `enterConfirmationFromS2(with:)` `:308` | 首句取样；E1 同上（`entry: "trash"`）；成功路径 `let reconciled = reconcileS1WithPhotoLibrary()`；E2 else 块先记录（`outcome: "submissionUnavailable", failure: sample.submissionFailure`）再 `returnToS1AfterUnavailableSubmission()`；E3 else 块先记录（`outcome: "confirmationRejected", failure: lastS3EntryGuardFailure`）再 `route = .s1; message = nil`；全过记录 `outcome: "ok"` 后 `return true` |
| `enterConfirmationFromS1(_:)` `:372` | C2 不成立写 `lastS3EntryGuardFailure = .C2`；C3 不成立写 `Self.s3EntryGuardFailure(submission:sessionStore:descriptors:)` 的返回值；成功写 `nil`；事件与收场不变 |
| `enterConfirmation(from:…)` `:683` | 九子句 `guard` 与三个局部量换成 `guard Self.s3EntryGuardFailure(submission:sessionStore:descriptors:) == nil else { return false }`；守卫后的写入段一字未动 |
| `applyS2ExitPayload(_:)` `:968` | 八子句 `guard` 换成 `guard s2ExitGuardFailure(payload) == nil, let s1Machine, let entryContext = s2EntryContext else { return false }` + `guard s1Machine.applyS2Return(payload.upstreamReturn, entryContext: entryContext) else { return false }`；其后两行不变 |
| `clearS2RouteState()` 之后 `:993-` 新增（`// MARK: - IC-168 B`） | `private enum S2ExitDiagnosticGuard: String`（23 个 case，隐式原始值）；`private struct S2ExitSample`（16 个存储字段 + 计算属性 `writeBackFailure`（E1 定名）与 `submissionFailure`（E2 定名），两者只读样本字段）；`private func sampleS2Exit(_:) -> S2ExitSample`；`private func s2ExitGuardFailure(_:) -> S2ExitDiagnosticGuard?`；`private static func s3EntryGuardFailure(submission:sessionStore:descriptors:) -> S2ExitDiagnosticGuard?`；`private func recordS2ExitDiagnostics(entry:sample:payload:reconciled:outcome:failure:)` |

## 四、子项 C · 面板显示（裁定 五）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 存储属性 `private let exitDiagnosticsText: String?`（`:785`，`shareItemResolver` 之后，带文档）；init 末位形参 `exitDiagnosticsText: String? = nil`（`:865`，`feedbackToastPresenter:` 之后）与赋值（`:888`）；面板段序 `doubleTapProbeSection` 之后加一行 `exitDiagnosticsSection`（`:2785`）；`doubleTapProbeSection` 定义之后新增 `@ViewBuilder private var exitDiagnosticsSection: some View`（`:2873`，`Divider()` → 标题 → `if let` 则 `ShareLink` + `.s2MinimumTouchTarget()` + `Text(verbatim:)` 等宽可选，`else` 空态一句；不包 `VStack`） |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `s2Screen` 的 `S2View(...)` 在 `onAlbumPickerSelection:` 之后追加 `exitDiagnosticsText: coordinator.s2ExitDiagnosticsText`（`:309`，上方一行注释） |
| `PhotoCleanupMVE/Localizable.xcstrings` | 加三条（`extractionState = manual`，插在 `s2.calibration.transition_diagnostics.title` 之后）：`s2.calibration.exit_diagnostics.title` = `S2 退出诊断（IC-168）`、`.share` = `复制或分享退出诊断`、`.empty` = `本次启动尚未从 S2 退出`；255 → 258 |

## 五、子项 D · 清理 tab 回落 toast（裁定 四）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | `toastView` 的 `if let` 体八行原样抽成同文件 `struct S0FeedbackToastLabel: View { let text: String; var body: some View { … } }`（文件末尾、`enum S0DeckPageShade` 之后，`:987`，带文档）；`toastView` 改 `if let text = toast.activeText { S0FeedbackToastLabel(text: text) }`（`:766`）。hunk 只有这两处 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `@StateObject private var cleanupFeedbackToast = S1FeedbackToastPresenter()`（`:16`，`s0FlowModel` 之后）；`s0Screen` 的 `S0CleanupFlowView(...)` 之后挂 `.overlay(alignment: .bottom) { cleanupFeedbackToastOverlay }`、`.onAppear { presentCleanupFeedbackEvent(coordinator.s1FeedbackEvent) }`、`.onChange(of: coordinator.s1FeedbackEvent) { _, newValue in presentCleanupFeedbackEvent(newValue) }`（`:142-150`）；`s2Screen` 之前加三成员 `cleanupFeedbackToastOverlay`（`:156`）、`cleanupFeedbackToastBottomInset`（`:166`）、`presentCleanupFeedbackEvent(_:)`（`:174`） |
| `PhotoCleanupMVETests/IC156CategoryPageTests.swift` | 断言 10 App `feedbackToastDurationMilliseconds` 3 → 4（上方加一行注释） |

## 六、子项 E · 类别页进入失败提示（裁定 三）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | 属性 `private let onLongPress: ([String], String) -> Bool`（`:34`）、init 形参 `onLongPress: @escaping ([String], String) -> Bool`（`:56`）；赋值行未动；长按 `.onEnded` 改 `if !onLongPress(displayedItems.map(\.id), item.id) { toast.present(text: L10n.text("s0.categoryPage.toast.enterFailed"), durationMilliseconds: toastDurationMilliseconds) }`（上方一行注释） |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | 类别页构造 `onLongPress:` 闭包体 `_ = onEnterS2(…)` → `onEnterS2(identifier, orderedAssetIDs, currentAssetID)`（`:142`） |
| `PhotoCleanupMVE/Localizable.xcstrings` | 加 `s0.categoryPage.toast.enterFailed` = `暂时无法逐张查看，请重试。`（`extractionState = manual`，紧跟 `s0.categoryPage.toast`）；258 → 259 |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | `s0Values.count, 40)` → `41)`、`catalogS0Keys.count, 40)` → `41)`（两处注释各补一句） |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | `catalogS0Keys.count, 40)` → `41)`（上方加一行注释） |
| `PhotoCleanupMVETests/IC156CategoryPageTests.swift` | 断言 7 `s0.` 40 → 41、`s0.categoryPage.` 10 → 11、`expected` 映射加一条（`.union` 名单未动）、注释「恰这九条」改为「恰是上面映射里的这些条」，上方加一行注释 |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | 断言 5 `s0.` 41、`s0.categoryPage.` 11、四条 needle `40)` → `41)`（上方加一行注释） |
| `PhotoCleanupMVETests/IC165DeckFormalTests.swift` | `s0.` 41、`s0.categoryPage.` 11（上方加一行注释） |
| `PhotoCleanupMVETests/IC166RestCategoryTests.swift` | `s0.` 41（上方加一行注释） |

## 七、子项 F · 新断言

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift`（新建） | 六条：`testIC168A_CancelS2HandoffRemovesInflightRegistrationOnly`、`testIC168A_FailedWriteBackClearsInflightRegistrationAndNamesW8b`、`testIC168B_TrashPathSuccessRecordsOkDiagnostics`、`testIC168B_ColdStartLoadingS1MakesTrashPathFallBackWithM2`、`testIC168BCD_NewSymbolsAreWired`、`testIC168E_CategoryPageShowsToastWhenEnteringS2Fails`；文件私有夹具照抄 IC131／FullFlowRouting／IC157；源码扫描 helper 同 IC-167 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记测试文件：fileRef `100000000000000000000072`、buildFile `20000000000000000000006F`（测试组与测试 Sources 阶段，紧跟 IC167；+4 行） |

## 八、占位值登记

无出厂值变更：`S2CalibrationConfiguration.schemaVersion` 仍 **7**（`Features/S2/S2Calibration.swift:118`），`S0ScanRules.cacheSchemaVersion` 仍 **1**；`S0DeckMetrics` 仍 198、`S0DeckSymbol` 仍 8；不登记新视觉值（清理 tab 回落 toast 的底距 = 既有 `dockBottomInset` 24，类别页上 = `dockBottomInset` + `dockHeight` + `toastToDockSpacing` = 104）。

## 九、未改动（「不得打红」段）

`Core/` 除 `S1StateMachine.swift` 外全部、`Services/`、`Features/Shared/`、`Features/S1/`（含 `S1View.swift`，blob `16496cab01001aae731b1edc2be2bf478e7d2d40` 不变）、`Features/S3`～`S5`、`Features/S2/` 除 `S2View.swift` 外全部、`Features/S0/` 除页面与流程外十一个文件、`.github/`、`Scripts/`、白名单外 42 份测试——两侧对象逐个相同（`self-check.md` 第七节表）。
