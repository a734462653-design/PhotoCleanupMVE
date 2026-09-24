# IC-170 变更清单

> 任务卡：`<top>/Tasks/IC-20260924-170-s1-first-read-in-coordinator.md`。本清单与 `self-check.md` 作为本卡唯一的 docs 提交（惯例 44）落在合并后的 `main` 上；合并推送与 G955 由决策会话——15 补记（见 `self-check.md` 第一、七、十节）。

## 一、分支、提交与合并

| 项 | 值 |
|---|---|
| 基线 | `main` = `5347cfd56ca0242a389170c99234a31341c97cd8`（IC-168 报告补记；IC-168 merge `8dba3fdde4bee6763cd4d5cc6443107b8c55dd82` 是其祖先） |
| 分支 | `feature/ic-170-s1-first-read`（自基线切出，已推送） |
| 子项 A | `e7209484da8a9b10d1cca09baaeaa29950704af4` `IC-170 A: reconcileS1WithPhotoLibrary completes first read when it hasn't happened yet`（2 个文件，+53／−23） |
| 子项 B | `a2a10071c89b3cc454581cdc74b1ed3a7f756235` `IC-170 B: cleanup tab basket entries submit through coordinator.enterConfirmationFromS0()`（3 个文件，+20／−7） |
| 子项 C | `800791020a8923e44043fea49c9d766a7edcd307` `test(IC-170): sub-item C — six new assertions for first-read-in-coordinator and cleanup-tab entry`（2 个文件，+373） |
| 合并（已推送） | `ba65163db17b541e9a46ec0e82a7aab7b336e2eb`，`--no-ff`，父 `5347cfd56ca0242a389170c99234a31341c97cd8` + `800791020a8923e44043fea49c9d766a7edcd307`；合并后 `main` 运行 #345 绿 888／0，artifact `PhotoCleanupMVE-unsigned-ba65163db17b`（id `10798246070`，2026-12-23 前有效） |
| 报告 | 合并与 #345 之后作为唯一 docs 提交落 `main`（惯例 44） |

`git diff --name-only 5347cfd..8007910`：6 个文件，恰为卡面白名单 6 个路径（产品 2、工程 1、测试 3）。

## 二、子项 A · 对账兼任首读（裁定一、四、五）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `reconcileS1WithPhotoLibrary()` 文档注释追加三行（裁定一说明）；函数体把无条件 `reconcile(...)` 换成按 `s1Machine.currentReadRequest` 是否非 nil 分支——非 nil 时 `completeRangeRead(response.result, for: request, isLimitedAuthorization:) && s1Machine.loadingState == .ready`（裁定四返回值口径），nil 时照旧 `reconcile(...)` |
| `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | 断言 4 整段替换（基线 `:142-194`）：MARK、文档、函数体一并换；函数名 `testIC168B_ColdStartLoadingS1MakesTrashPathFallBackWithM2` → `testIC168B_ColdStartLoadingS1TrashPathCompletesFirstReadAndEntersConfirmation`；注入 `IC127LibraryBox` 授权桩（默认 `.authorized`）；断言翻转为「进入 S3、`reconciled=true`、`outcome=ok`、`guard=none`」 |

## 三、子项 B · 清理 tab 入口收进协调器（裁定二）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 在 `enterConfirmationFromS1(_:)` 收尾之后新增 `@discardableResult func enterConfirmationFromS0() -> Bool`：`reconcileS1WithPhotoLibrary()`（对账兼任首读）→ `guard let submission = s1Machine?.makeS3Submission() else { publishS1FeedbackEvent(.submissionUnavailable); return false }` → `return enterConfirmationFromS1(submission)` |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `s0Screen` 的 `onEnterConfirmation` 闭包体（基线 `:134-138`）整体换成 `_ = coordinator.enterConfirmationFromS0()`（单行 + 一行注释）；`s0Screen` 其余（`S0CleanupFlowView(` 实参顺序、`.overlay`／`.onAppear`／`.onChange` 三修饰符）未动 |
| `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift` | 断言 3（`:175-180`）三个期望值改：`reconcileS1WithPhotoLibrary()` 1→0、`makeS3Submission()` 1→0、`enterConfirmationFromS1(` 2→1；注释同步改为「只剩『逐张整理』tab 的既有一处」 |

## 四、子项 C · 新断言六条

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVETests/IC170S1FirstReadTests.swift`（新建，369 行） | `final class IC170S1FirstReadTests: XCTestCase`，六条：`testIC170A_CoordinatorReconcileCompletesFirstReadAndCarriesLimitedFlag`（受限标志与二次对账）、`testIC170A_FirstReadAuthorizationFailureLandsFailedAndIsNotReconciled`（授权失败落 `.failed`、不自动重读）、`testIC170A_ColdStartBackRouteCompletesFirstRead`（返回键路径完成首读，诊断文本 label `C3`）、`testIC170B_CleanupEntryReachesConfirmationFromColdStart`（清理 tab 入口冷启动进 S3）、`testIC170B_CleanupEntryPublishesEventWhenSubmissionUnavailable`（提交不可用发事件、不改路由，IC-132 式无名档快照）、`testIC170AB_SourceWiring`（源码接线计数）；文件私有源码扫描 helper（`repoRoot`／`sourceText`／`strippedSource`／`occurrences`／`unwrap`／`printDiagnostics`，路径常量 `coordinatorPath`／`appPath`）照抄 `IC168FallbackDiagnosticsTests.swift` 同名私有成员的算法与写法 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记新测试文件：PBXBuildFile `200000000000000000000070`（fileRef 指向 `100000000000000000000073`）；PBXFileReference `100000000000000000000073`；测试组文件列表插入 `100000000000000000000073`；Sources 构建阶段插入 `200000000000000000000070`。均紧跟 `IC168FallbackDiagnosticsTests.swift` 现有的四行登记之后。登记前重扫得最大号 fileRef `...0072`、buildFile `...006F`（均为 IC168 文件），新 id 登记前在全文件 0 命中 |

## 五、占位值登记

无出厂值变更：`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S0ScanRules.cacheSchemaVersion` 仍 **1**；`S0DeckMetrics` 仍 **198**；文案目录仍 **259**（本卡未加任何 String Catalog key，清理 tab 提示沿用既有 `s1.toast.submission_unavailable`）。

## 六、项数对账

882 → （A）882 → （B）882 → （C）888，与卡面「项数：882 + 6 = 888」一致；两次 CI（#343、#344）实测数字与本对账逐项相符（见 `self-check.md` 第七节）。

## 七、未改动（「不得打红」段，① 现取 blob/tree 比对）

`Core/` 全部（含 `S1StateMachine.swift`，blob `98432dde8103944a7910c8a67cee268895eb6e53` 两侧相同）、`Services/` 全部、`Features/` 全部（含 `Features/S1/S1View.swift`，blob `16496cab01001aae731b1edc2be2bf478e7d2d40` 两侧相同；`Features/S0/` 全目录树两侧逐文件 blob 相同；`Features/S2/S2View.swift` 未在白名单更未被触及）、`Localizable.xcstrings`（blob `80dcb2cf21e0a177b2a3f6b867626eb8e34d29f9` 两侧相同）、`.github/`、`Scripts/`、白名单外的全部测试文件（`git diff --name-only` 6 路径之外零改动）。

## 八、合并与推送状态

本地 `--no-ff` 合并 `ba65163db17b541e9a46ec0e82a7aab7b336e2eb`（父 `5347cfd` + `8007910`）。执行端 `git push origin main` 在 Bash、PowerShell 各一次均被拒绝（`Reason: [Merge Without Review]`），按纪律停下；Lynn 审阅决策会话的验收结论后指示推送，决策会话 PowerShell 一次推送成功（`5347cfd..ba65163`）。合并后 `main` 运行 #345（run `35974863853`）绿 888／0。
