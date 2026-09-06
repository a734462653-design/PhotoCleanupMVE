# IC-131 变更清单

分支：`feature/ic-131-s1-trash-toast-fix`（自 `main` = `937ed76` 切出）
被测提交：`ffc254b81f0a0bf9bb89beb0fa1148f4644835a6`（分支 tip）
合并提交：**`652cc09`**（`652cc098529214bd09b04383c2eb1ed3835e1eb1`，`--no-ff` 入 `main`）
报告提交：本卡 docs 提交（`Reports/IC-131/` 两份），随合并留在 `main`

## 提交链（两个子项各自独立 commit，各自可单独 cherry-pick）

| 提交 | 内容 |
|---|---|
| `ead287c` | **A**：空态垃圾桶与徽标对齐锁定决策 8（四态统一口径）+ 断言 1/2/3 |
| `ffc254b` | **B**：写回校验失败不阻断返回 + S1 底部短 toast + 断言 4～8 |
| `652cc09` | 合并提交（`--no-ff`） |

两个 commit 各自携带自己的新测试文件与 `project.pbxproj` 登记，互不依赖。

## 文件级变更（`937ed76..ffc254b`，8 文件 +546 −23）

| 文件 | +/− | 子项 | 变更 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | +132 −7 | A + B | A：`S1ChromeBarModel.make` 去掉两处 `state != .empty`，第 86～87 行错误口径注释改写。B：新增 `S1FeedbackEventKind`／`S1FeedbackEvent`／`S1FeedbackToastPresenter`；`S1View` 加三个构造参数与 `@StateObject` 呈现器、底部 `feedbackToastOverlay`、`presentPendingFeedbackEventIfNeeded()`、`onAppear`／`onChange` 两个取事件时机 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | +31 −0 | B | 见下「协调器改动清单」 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | +24 −12 | B | S1 视图构造点外提为私有 `s1Screen(machine:)` builder（陷阱 16），补三个实参：`feedbackEvent`、`feedbackToastDurationMilliseconds`（取自 `coordinator.s2Calibration.configuration`）、`onFeedbackEventConsumed`。S2～S5 各分支未动 |
| `PhotoCleanupMVE/Localizable.xcstrings` | +11 −0 | B | 新增 1 个 key（见下） |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | +12 −4 | A | 断言 1：`empty` 段改为 `trashEnabled == true`／`badgeText == "2"`，新增 `empty` + `badgeCount 0` 段；第 10～12 行注释同步改 |
| `PhotoCleanupMVETests/IC131S1TrashBadgeTests.swift` | +119 −0 | A | 新文件：断言 3（四态穷举八用例）、断言 2（空维度仍可提交） |
| `PhotoCleanupMVETests/IC131S1WriteBackToastTests.swift` | +209 −0 | B | 新文件：断言 4～8 共 5 项 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +8 −0 | A + B | 两个新测试文件各四处登记（buildFile `…0034`／`…0035`，fileRef `…0037`／`…0038`） |

## 协调器改动清单（G711 要求逐一列出）

**新增成员（2）**

| 成员 | 类型 |
|---|---|
| `s1FeedbackEvent` | `@Published private(set) var S1FeedbackEvent?` —— 一次性写回失败事件通道 |
| `s1FeedbackEventCount` | `private(set) var Int` —— 已发事件总数；事件 `id` 取此序号 |

**新增函数（2）**

| 函数 | 说明 |
|---|---|
| `consumeS1FeedbackEvent()` | S1 视图取走事件后清空通道 |
| `returnToS1AfterFailedWriteBack()`（private） | 失败收场：不写回、`clearS2RouteState()`、对账一次、`route = .s1`、`message = nil`、发一条事件 |

**改动函数（2，均只改失败分支，签名与成功路径零改动）**

| 函数 | 改动 |
|---|---|
| `leaveS2(with:)` | `guard applyS2ExitPayload(payload) else { … }` 的 else 内加 `returnToS1AfterFailedWriteBack()` |
| `enterConfirmationFromS2(with:)` | 同上一处 else；失败即回 S1，不进 S3、不形成提交 |

**零改动（diff 内无这些符号）**：`applyS2ExitPayload` 的校验条件、所有 `s2*` 成员、
S3／S4／S5 路由、`reconcileS1WithPhotoLibrary` 本身、`installS1Session`。

## 断言 → 测试函数对照（八条，#254 逐条 passed）

1. `empty` 段口径修正 → `testIC128A_ChromeBarStatesFollowLoadingEmptyReady`
2. 空维度仍保留徽标且提交路径畅通 → `testIC131A_EmptyDimensionKeepsBadgeAndSubmissionPath`
3. 四态穷举八用例 → `testIC131A_ChromeBarTrashAndBadgeFollowOnlyLoadingAndBadgeCount`
4. `leaveS2` 失败：回 S1、store 未变、恰一条事件 → `testIC131B_FailedWriteBackOnLeaveReturnsToS1AndEmitsOneEvent`
5. 垃圾桶路径失败不进 S3 → `testIC131B_FailedWriteBackOnTrashPathDoesNotEnterS3`
6. 成功路径回归、事件通道为空 → `testIC131B_SuccessfulWriteBackEmitsNoEvent`
7. 呈现器只留最新一条、按注入调度器到期 → `testIC131B_ToastPresenterKeepsLatestEventAndExpiresOnSchedule`
8. 文案取自目录、逐字等于 v8 登记原文 → `testIC131B_ToastTextComesFromStringCatalog`

测试项数 640 → **647**（+7：新文件 2 项 + 5 项；断言 1 落在既有函数内不增项）。

## 文案登记

| key | 值 | 来源 |
|---|---|---|
| `s1.toast.writeback_failed` | 未能保存这次整理的进度。 | v8 第十一节第 3 部分登记原文，逐字转录 |

String Catalog 由 206 → **207** 条目，源码引用同为 207（`selfcheck.ps1` 实测一致）。

## 占位值登记

**无变更。** `S2Calibration.swift` 完全未改，`S2CalibrationConfiguration` 字段集合
零改动，`schemaVersion` 保持 **7**；`factoryPlaceholder` 登记制不变。
本卡只**读取**既有参数 `feedbackToastDurationMilliseconds`（出厂 2000）作为 toast
时长，不加字段、不构成出厂值集合变更，故无需递增版本号。

toast 样式沿用 S2 既有常量，未新造登记项：`S2OverlayLayout.minimumSpacing`
（内边距 2× / 1×）、`S2OverlayLayout.bottomRowBottomInset`（底距 8）、
`.subheadline`、`.regularMaterial` + `Capsule()`。

## 分支与冻结链状态（本地＝远端）

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `652cc09` | 本卡推进（合并提交） |
| `feature/ic-131-s1-trash-toast-fix` | `ffc254b` | 保留在原 tip，未删除 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |

## CI

- **主跑 #254**（run id `34028015334`，job `101472350058`）：被测提交
  `ffc254b81f0a0bf9bb89beb0fa1148f4644835a6`，**647 项 0 失败**、退出码 0、
  `** TEST SUCCEEDED **`、摘要 notice 在位、`##[error]` 0 条，
  目的地 `OS:26.2, name:iPhone 16`（id `EADC2067-…`），
  IPA **1207559 字节**，SHA-256
  `5d1b48aa3095f0877f4ddefaf9c86ca1cac16830845896da236b9d3977acd241`
- 预算 3 次 **用 1 次**；两次修复预算未动用
- **G715 #255**（run id `34028477143`，job `101473599350`）：被测提交
  `652cc098529214bd09b04383c2eb1ed3835e1eb1`（合并提交），**647 项 0 失败**、
  退出码 0、摘要 notice 在位、`##[error]` 0 条，目的地同上，
  IPA 1207559 字节，SHA-256
  `17eb3bc649b806466a07514c760287d2b96c98d821f4e65fe35b93f72f5f0cf0`
- 本报告提交命中 `ci.yml` 的 `paths-ignore`（`Reports/**`、`**.md`），
  **不触发 CI**，为预期行为

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check` | 0 |
