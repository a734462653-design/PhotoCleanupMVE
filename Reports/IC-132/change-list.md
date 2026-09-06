# IC-132 变更清单

分支：`feature/ic-132-s3-submission-dead-end`（自 `main` = `9d1e842` 切出）
被测提交：`93b13c7bb223a0a82e74e99bd407210741dee43d`（分支 tip）
合并提交：**`a1cafed`**（`a1cafedc13b29cee47cef579a25a6bc11d5a73ad`，`--no-ff` 入 `main`）
报告提交：本卡 docs 提交（`Reports/IC-132/` 两份），随合并留在 `main`

## 提交链

| 提交 | 内容 |
|---|---|
| `f916f31` | **A**：范围显示名随会话档持久化（根因）+ 断言 1／2／3 |
| `6a1ddb4` | **B**：提交形成失败不再卡死、不再静默 + 断言 5～9 |
| `93b13c7` | fix（B）：断言 9 的路由例名 `.confirmation`（#256 编译红归因，仅改测试一行） |
| `a1cafed` | 合并提交（`--no-ff`） |

**cherry-pick 单位**：A = `f916f31` 可单独取；B = `6a1ddb4` + `93b13c7` 两个一起取
（沿用 IC-128 的既定做法：修复提交独立留痕，cherry-pick 单位 = 整组）。

## 文件级变更（`9d1e842..93b13c7`，8 文件 +846 −13）

| 文件 | +/− | 子项 | 变更 |
|---|---|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | +46 −3 | A | `S1SessionSnapshot` 加 `rangeNamesByID` 与带默认值的逐成员构造；`sessionSnapshot` 填入名字表；`restore(from:)` 灌回；`adoptRanges` 名字表改为一次性合并赋值，末尾补一次 `publishSnapshotIfChanged()` |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | +44 −1 | A | `PersistedS1Session` 加 `rangeNamesByID` + 显式 `CodingKeys` + 手写 `init(from:)`（该字段 `decodeIfPresent ?? [:]`，其余仍 `decode`）；`init(_:)` 与 `snapshot` 各带上新字段 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | +36 −4 | B | 见下「协调器改动清单」 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | +47 −5 | B | `S1FeedbackEventKind` 加 `.submissionUnavailable` 与文案映射；新增可测的 `S1TrashButtonAction.perform`；`trashButton` 改走它；新增 `presentLocalFeedback(_:)` 与 `localFeedbackEventCount` |
| `PhotoCleanupMVE/Localizable.xcstrings` | +11 −0 | B | 新增 1 个 key（见下） |
| `PhotoCleanupMVETests/IC132S1RangeNamePersistenceTests.swift` | +226 −0 | A | 新文件：断言 1（拆两条）、2、3 共 4 项 |
| `PhotoCleanupMVETests/IC132SubmissionDeadEndTests.swift` | +428 −0 | B | 新文件：断言 5～9 共 5 项 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +8 −0 | A + B | 两个新测试文件各四处登记（buildFile `…0036`／`…0037`，fileRef `…0039`／`…003A`） |

**断言 4 要求的两条 IC-127 B 回归测试源码一字未动**——`S1SessionSnapshot` 的逐成员
构造给新字段配了默认空表，既有构造点无须改写即可编译。

## 协调器改动清单（G721 要求逐一列出）

**新增函数（2，均 private）**

| 函数 | 说明 |
|---|---|
| `returnToS1AfterUnavailableSubmission()` | 写回**已生效**但提交形成不了时的收场：`route = .s1`、`message = nil`、发一条 `.submissionUnavailable`。与 IC-131 的 `returnToS1AfterFailedWriteBack()` 的区别只在写回结果是否保留 |
| `publishS1FeedbackEvent(_:)` | 事件发布的共用出口；IC-131 内联的事件构造抽到此处 |

**改动函数（3，均只改失败分支或等价重构）**

| 函数 | 改动 |
|---|---|
| `enterConfirmationFromS2(with:)` | 写回成功后：`makeS3Submission()` 为 nil → `returnToS1AfterUnavailableSubmission()`；委派 `enterConfirmationFromS1` 返回 false → 只补 `route = .s1`／`message = nil`，**不重复发第二条事件**。成功路径与 `applyS2ExitPayload` 分支未动 |
| `enterConfirmationFromS1(_:)` | 两条失败路径（前置 guard、`enterConfirmation` 返回 false）各发一条 `.submissionUnavailable`；**不改 route**（该方法也可能在 `.upstream`／`.finished` 下被调用）。成功路径未动 |
| `returnToS1AfterFailedWriteBack()` | 仅把内联的事件构造换成 `publishS1FeedbackEvent(.writeBackFailed)`，行为不变 |

**零改动（diff 内无这些符号）**：`applyS2ExitPayload` 的校验条件、所有 `s2*` 成员、
S3／S4／S5 路由、`reconcileS1WithPhotoLibrary`、`installS1Session`、
`enterConfirmation(from:...)` 本体。

## 断言 → 测试函数对照（九条，#257 逐条 passed）

1. 名字表跨往返存活 + 空 `R(T)` 后仍能提交且组名逐字相等 →
   `testIC132A_RangeNamesSurviveArchiveRoundTrip`、
   `testIC132A_SubmissionUsesArchivedNamesWhenReadSuppliesNone`
   （**卡内字面要求「读取前非 nil」不成立，已拆分，见自验报告**）
2. 旧档无该字段仍解码 → `testIC132A_LegacyArchiveWithoutRangeNamesDecodesAsEmptyTable`
3. 单一写出口、恰增 1、无变化不写 → `testIC132A_NewRangeNamesPublishExactlyOnceThroughSingleSink`
4. IC-127 B 两条回归 → `testIC127B_ArchiveRoundTripRestoresMKFTAndO`、
   `testIC127B_CoordinatorRestoresArchivedSessionAndReconcilesBeforeReady`（源码未动）
5. 写回保留 + 回 S1 + 恰一条事件 → `testIC132B_SubmissionUnavailableAfterSuccessfulWriteBackReturnsToS1`
6. 8 组合不变量 → `testIC132B_NoEntryPointLeavesRouteInS2WithoutMachine`
7. 垃圾桶动作口径 → `testIC132B_TrashButtonActionFallsBackToFeedbackWhenSubmissionUnavailable`
8. 两种 kind 文案 → `testIC132B_BothFeedbackKindsResolveDistinctCatalogText`
9. 端到端进确认页 → `testIC132B_RestoredSessionEntersS3WithoutFallbackAfterDimensionSwitch`

测试项数 647 → **656**（+9：两个新文件 4 项 + 5 项）。

## 会话档新字段

| 字段 | 类型 | 位置 | 旧档缺失时 |
|---|---|---|---|
| `rangeNamesByID` | `[String: String]` | `S1SessionSnapshot`、`PersistedS1Session`（`s1-session.json`） | **按空表解码，不判坏档** |

其余六个字段仍 `decode`，缺失照旧抛错——坏档语义（未知维度／排序、重复资产）未改。
编码沿用合成实现，新档必带该键。

## 文案登记

| key | 值 | 来源 |
|---|---|---|
| `s1.toast.submission_unavailable` | 暂时无法打开确认页，请重试。 | 卡内登记原文，逐字转录 |

String Catalog 由 207 → **208** 条目，源码引用同为 208（`selfcheck.ps1` 实测一致）。

## 占位值登记

**无变更。** `S2Calibration.swift` 完全未改，`S2CalibrationConfiguration` 字段集合
零改动，`schemaVersion` 保持 **7**；`factoryPlaceholder` 登记制不变。
本卡改的是 S1 会话档格式，不是标定出厂值，不构成出厂值集合变更。
toast 呈现复用 IC-131 的 `S1FeedbackToastPresenter` 与 S2 既有常量，未新造登记项。

## 分支与冻结链状态（本地＝远端）

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `a1cafed` | 本卡推进（合并提交） |
| `feature/ic-132-s3-submission-dead-end` | `93b13c7` | 保留在原 tip，未删除 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |

## CI（预算 3 次，用 2 次）

- **#256 红**（run id `34042997989`，job `101512988001`）：`运行 XCTest` 步骤失败，
  退出码 **65**，注解 `IC132SubmissionDeadEndTests.swift:239:43: error: type
  'CleanupRoute' has no member 's3'`。归因：测试里的枚举例名写错
  （卡内断言 9 的 `.s3` 是页面口径简写，实际为 `.confirmation`），产品代码无关。
- **#257 绿**（run id `34043352496`，job `101513938241`）：被测提交
  `93b13c7bb223a0a82e74e99bd407210741dee43d`，**656 项 0 失败**、退出码 0、
  `** TEST SUCCEEDED **`、摘要 notice 在位、`##[error]` 0 条，
  目的地 `OS:26.2, name:iPhone 16`（id `EADC2067-…`），
  IPA **1211235 字节**，SHA-256
  `8c308ac50ededb94c6e11018078bdfc3a8ed26af1cd08e828e4f55cbe71724f5`
- 剩 1 次修复预算未动用
- **G725 #258 绿**（run id `34043724228`，job `101514936849`）：被测提交
  `a1cafedc13b29cee47cef579a25a6bc11d5a73ad`（合并提交），**656 项 0 失败**、
  退出码 0、摘要 notice 在位、`##[error]` 0 条，目的地同上，
  IPA 1211235 字节，SHA-256
  `48d59943dfd08d236c028ee2f7715f4bd785c1d201143c9428ca38ce6e283412`；
  产物 `PhotoCleanupMVE-unsigned-a1cafedc13b2`，zip 1211405 字节
- 本报告提交命中 `ci.yml` 的 `paths-ignore`（`Reports/**`、`**.md`），
  **不触发 CI**，为预期行为

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（`9d1e842..a1cafed`） | 0 |
