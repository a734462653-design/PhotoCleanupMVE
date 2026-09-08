# IC-138 变更清单

- 继承提交：`main` = `f8ae50af039e5b890be75a76cbe040db0bc422a6`
- 分支：`feature/ic-138-housekeeping`，代码 tip `113384a709f143dceba905710e7c0a9156ba322e`
- **合并提交：`6b1adea` / `6b1adeadf371e17fe7805f95928dfba2d0fbaefa`**
  - parent1 `f8ae50af039e5b890be75a76cbe040db0bc422a6`（原 `main`）
  - parent2 `113384a709f143dceba905710e7c0a9156ba322e`（分支 tip）
  - `Merge made by the 'ort' strategy.`，**零冲突**；合并树对象
    `a66ef08be3f7f57d9744b58fe02720f69d2bc622` 与分支 tip 树对象相同
- 推送报文：`f8ae50a..6b1adea  main -> main`（两点记法，非强推），退出码 0

## 提交链（6 个，未 rebase／未 amend）

| 提交 | 子项 | 内容 | 可单独 cherry-pick |
|---|---|---|---|
| `31dc851` | A | 追溯矩阵同步 L3 撤销 + 守卫测试改读表判定 | 是 |
| `101b88f` | B | 断言强度表同步 | 是 |
| `e6aaa03` | C | S3 常量归并 | 是 |
| `ae81a30` | D | 扫描器豁免理由文案 | 是 |
| `113384a` | A | 方法名存在性断言还原 throws 选择子（#268 红的修复） | 否——依赖 `31dc851` 引入的断言 |
| `6b1adea` | — | **本卡合并提交**（`--no-ff`） | — |

## 文件级变更（`f8ae50a..6b1adea`，5 文件 +194 −83）

| 文件 | +/− | 子项 |
|---|---|---|
| `Reports/TRACEABILITY-S3-S5.md` | +35 −55 | A |
| `PhotoCleanupMVETests/TransitionTableGuardTests.swift` | +132 −8 | A |
| `Reports/GUARD-ASSERTION-STRENGTH.md` | +20 −10 | B |
| `PhotoCleanupMVE/Features/S3/S3View.swift` | +5 −8 | C |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | +2 −2 | D |

**`PhotoCleanupMVE.xcodeproj/project.pbxproj` 未改**：本卡未新增文件，
新断言落进已登记的 `TransitionTableGuardTests.swift`，不触发 pbxproj 登记。

## A · 追溯矩阵被改行号清单

### R1 — 条款已撤销（15 行）

条款原文属 L3 层且所列方法**全部**已删 → 方法列改 `—`、覆盖判定改
`条款已撤销（Decision_log 147，随 S5 v6 落文）`。

| 行号 | 条款 | 原判定 | 被清除的方法名 |
|---|---|---|---|
| 285 | C5-022 | 未覆盖 | `testL3DisplayRemainsBlockedForEveryState` |
| 286 | C5-023 | 未覆盖 | `testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt` |
| 287 | C5-024 | 不适用 | `testL3DisplayRemainsBlockedForEveryState` |
| 288 | C5-025 | 已覆盖 | `testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation`、`testRepeatedConfirmationDoesNotReadAgain` |
| 291 | C5-028 | 未覆盖 | `testConfirmationReadsCompletionExactlyOnceAndPersistsDelta`、`testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation`、`testUnavailableReadingsArePersistedWithoutDeltaOrRetry` |
| 293 | C5-030 | 已覆盖 | `testRepeatedConfirmationDoesNotReadAgain` |
| 294 | C5-031 | 已覆盖 | `testRepeatedConfirmationDoesNotReadAgain`、`testLifecycleEventsDoNotReadFreeDiskAgain`、`testUnavailableReadingsArePersistedWithoutDeltaOrRetry`、`testC5_031RepeatedLifecycleTicksNeverPollFreeDisk` |
| 295 | C5-032 | 已覆盖 | `testL3DisplayRemainsBlockedForEveryState` |
| 298 | C5-035 | 未覆盖 | `testConfirmationReadsCompletionExactlyOnceAndPersistsDelta`、`testUnavailableReadingsArePersistedWithoutDeltaOrRetry`、`testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime` |
| 309 | C5-046 | 已覆盖 | `testCancellationDoesNotShowL3` |
| 314 | C5-051 | 已覆盖 | `testCancellationDoesNotReadFreeDiskStrictGB`、`testCancellationDoesNotShowL3` |
| 327 | C5-064 | 已覆盖 | `testL3DisplayRemainsBlockedForEveryState` |
| 332 | C5-069 | 已覆盖 | `testL3DisplayRemainsBlockedForEveryState`、`testC5_069FailureNeverReadsFreeDiskOrDisplaysL3` |
| 345 | C5-082 | 已覆盖 | `testL3DisplayRemainsBlockedForEveryState` |
| 349 | C5-086 | 已覆盖 | `testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation`、`testL3DisplayRemainsBlockedForEveryState`、`testC5_086UnknownCannotReadConfirmOrWriteBackManualResult` |

### R2 — 已撤销事件的迁移单元格（5 行，坐标全部保留）

判定理由**保留原坐标前缀**（守卫测试靠它解析），末尾追加
`；事件已撤销（Decision_log 147，随 S5 v6 落文）`；方法列改 `—`、判定改条款已撤销。

| 行号 | 条款 | 起始状态 | 原可达性 | 被清除的方法名 |
|---|---|---|---|---|
| 369 | C5-106 | 外部源 | 不可达 | （无死引用） |
| 370 | C5-107 | S5-T0 | **可达** | `testConfirmationReadsCompletionExactlyOnceAndPersistsDelta` |
| 371 | C5-108 | S5-C | 不可达 | （无死引用） |
| 372 | C5-109 | S5-F | 不可达 | （无死引用） |
| 373 | C5-110 | S5-U | 不可达 | （无死引用） |

**卡内写「4 个单元格」，实为 5 个**——C5-107 是同一事件的**可达**单元格，
不在强度表的 63 个不可达坐标内，卡未点到。详见 self-check。

### R3 — 条款半退役，只删死引用、保留判定（3 行）

| 行号 | 条款 | 判定 | 删除 | 保留 |
|---|---|---|---|---|
| 315 | C5-052 | 已覆盖 | `testCancellationDoesNotShowRecentlyDeletedConfirmationAction` | `testCancellationCannotLeaveThroughCompletionAction` |
| 333 | C5-070 | 已覆盖 | `testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation` | `testFailurePageCannotLeaveThroughCompletionAction` |
| 407 | C5-144 | 不适用 | `testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime`、`testC5_144SuccessExitClearsPersistedL3Session` | `testCell04LeaveFromSuccess` |

### R4 — 条款存续，只删死引用、保留判定（7 行）

| 行号 | 条款 | 判定 | 删除 | 保留 |
|---|---|---|---|---|
| 283 | C5-020 | 未覆盖 | `testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime` | `testCell01SuccessEntry` |
| 300 | C5-037 | 已覆盖 | `testLifecycleEventsDoNotReadFreeDiskAgain` | `testCell07InactiveFromSuccess` |
| 301 | C5-038 | 已覆盖 | `testLifecycleEventsDoNotReadFreeDiskAgain` | `testCell10ActiveFromSuccess` |
| 302 | C5-039 | 已覆盖 | `testLifecycleEventsDoNotReadFreeDiskAgain`、`testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime`、`testC5_039CompletedReadingsSurviveTerminationAndRestoreWithoutNewRead` | `testCell13TerminationFromSuccess`、`testRestoreKeepsPersistedSuccessState` |
| 354 | C5-091 | 已覆盖 | `testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt` | `testCell01SuccessEntry` |
| 385 | C5-122 | 已覆盖 | `testLifecycleEventsDoNotReadFreeDiskAgain` | `testCell07InactiveFromSuccess` |
| 390 | C5-127 | 已覆盖 | `testLifecycleEventsDoNotReadFreeDiskAgain` | `testCell10ActiveFromSuccess` |

### 反向映射删除行（16 行）

| 行号 | 方法名 |
|---|---|
| 450 | `testC5_031RepeatedLifecycleTicksNeverPollFreeDisk` |
| 452 | `testC5_039CompletedReadingsSurviveTerminationAndRestoreWithoutNewRead` |
| 453 | `testC5_069FailureNeverReadsFreeDiskOrDisplaysL3` |
| 454 | `testC5_086UnknownCannotReadConfirmOrWriteBackManualResult` |
| 458 | `testC5_144SuccessExitClearsPersistedL3Session` |
| 548 | `testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation` |
| 555 | `testCancellationDoesNotReadFreeDiskStrictGB` |
| 556 | `testCancellationDoesNotShowL3` |
| 558 | `testCancellationDoesNotShowRecentlyDeletedConfirmationAction` |
| 560 | `testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt` |
| 561 | `testConfirmationReadsCompletionExactlyOnceAndPersistsDelta` |
| 562 | `testRepeatedConfirmationDoesNotReadAgain` |
| 563 | `testLifecycleEventsDoNotReadFreeDiskAgain` |
| 564 | `testUnavailableReadingsArePersistedWithoutDeltaOrRetry` |
| 565 | `testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime` |
| 566 | `testL3DisplayRemainsBlockedForEveryState` |

### 未覆盖／不适用清单删除条款（5 条）

判定不再是「未覆盖」或「不适用」，故从两张清单移除：
C5-022、C5-023、C5-028、C5-035（原未覆盖）、C5-024（原不适用）。

### 汇总重算

| 指标 | 改前 | 改后 |
|---|---:|---:|
| 条款总数 | 377 | **377** |
| 已覆盖 | 266 | **251** |
| 未覆盖 | 72 | **68** |
| 不适用 | 39 | **38** |
| 条款已撤销 | —（新增行） | **20** |
| XCTest 方法总数 | 184 | **168** |
| 未命中测试 | 8 | **8** |

251 + 68 + 38 + 20 = 377，与条款总数自洽；168 = 184 − 16。

### 守卫测试改动

| 处置 | 内容 |
|---|---|
| 新增 | `TransitionCell.isRetiredEvent`，由判定理由里的 `事件已撤销` 标记解析 |
| 新增 | `retiredEventMark` 常量（读表用，不按事件名写死） |
| 删除 | `assertS5Unreachable` 中 `case "用户点击“我已清空最近删除”": return` 特判 |
| 新增 | 主测试三条计数断言：已撤销 5、存续不可达 59、存续可达 51 |
| 新增 | 遍历时 `guard !cell.isRetiredEvent else { continue }` |
| 新增 | `testIC138EveryTraceabilityMethodNameStillExists` 与三个 helper |
| 重构 | `loadTransitionCells` 改用抽出的 `loadTraceabilityText()` |

## B · 断言强度表被改行号清单

| 行号（改前） | 内容 |
|---|---|
| 7–9 | 结论表：强 26 → **23**、弱 37 → **36**、新增「已撤销 4」行、合计 63 不变 |
| 9 后 | 新增一段 IC-138 B 说明（含 C5-107 不在本表 63 坐标内的提示） |
| 13–14 | 判定口径两条按行号引用守卫测试改为按符号名引用 |
| 73 | C5-106 弱 → **已撤销** |
| 74 | C5-108 强 → **已撤销** |
| 75 | C5-109 强 → **已撤销** |
| 76 | C5-110 强 → **已撤销** |
| 94–95 | 完整性摘要：强 26 → **23**、弱 37 → **36**、新增「已撤销 4」 |

**本表引用的 XCTest 方法名数量为 0**（全表 grep 实测），故断言 3 在本表侧
无对象；断言由矩阵侧的运行时断言承担，见 self-check。

## C · S3 常量归并

| 处置 | 成员 | 位置 |
|---|---|---|
| 删除 | `S3CellBadgeMetrics.volumeCornerRadius`（= 9，IC-134 引入起零引用） | 原 :223 |
| 删除 | `enum S3VolumeDetailMetrics`（空壳容器） | 原 :299–301 |
| 新增 | `S3ActionBarMetrics.scanningPairSpacing`（= 4） | :177 |
| 改引用 | 扫描行 `HStack(spacing:)` 改指新常量 | 原 :537 |

**数值零改动**：`S3View.swift` 的数值型 diff 只有三行——
`+ scanningPairSpacing: CGFloat = 4`、`- volumeCornerRadius: CGFloat = 9`（删）、
`- pairSpacing: CGFloat = 4`（搬走）。渲染零改动。

## D · 扫描器豁免理由

| 行 | 改前 | 改后 |
|---|---|---|
| 165 | 十进制 MB/GB **向下截断**由规格锁定，本卡禁止本地化改造 | 十进制换算由规格锁定（≥ 1 MB 整数截断、< 1 MB 一位小数四舍五入、≥ 1 GB 一位小数截断，见 `DecimalVolumeFormatter`），禁止本地化改造 |
| 173 | S2 单张 KB/MB/GB **向下截断**由规格锁定，禁止本地化改造 | S2 单张 KB/MB/GB 换算由规格锁定（见 `S2AssetVolumeFormatter`；与 `DecimalVolumeFormatter` 是两套口径，互不影响），禁止本地化改造 |

扫描逻辑（`$literalPattern`／`$hanPattern`／`$uiLiteralPattern`／
`$dataLiteralPattern`／豁免匹配条件）一字未动。

## 占位值登记

**无变更。** `S2CalibrationConfiguration.schemaVersion` 保持 **7**
（`Features/S2/S2Calibration.swift:118`，该文件不在 diff 内）。
C 的常量搬家不进标定配置、不上标定面板，取值 4 未变，不构成出厂值集合变更。

## 测试项数

| 来源 | 数量 |
|---|---|
| 基线（`main`，CI #266） | 676 |
| 本卡新增 | +1（`testIC138EveryTraceabilityMethodNameStillExists`） |
| **合计（CI #269）** | **677** |

既有用例零增删。`TransitionTableGuardTests` 单套 2 项；
`S3StateMachineTests` 22、`IC133S3BehaviorTests` 9、`IC134S3VisualTests` 14、
`VolumeFormattingTests` 8，均与基线相同。

## CI

- **#268**（run id `34215204671`）——**红**，`Executed 677 tests, with 1 failure`，
  退出码 65。唯一失败是本卡新增的断言自身（选择子未还原），矩阵数据未被牵连。
  根因与修复见 self-check「CI 预算与那次红」。
- **#269**（run id `34216125904`，attempt 1）——**绿**
  - 被测提交 `113384a709f143dceba905710e7c0a9156ba322e`，事件 `push`
  - **Executed 677 tests, with 0 failures (0 unexpected) in 61.346 (76.501) seconds**
  - `** TEST SUCCEEDED **` 在位；`##[error]` 0 条、`##[warning]` 0 条
  - 真实退出码 **0**（job `102028162514` success，10 个 step 全 success）
  - 目的地 `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`
  - IPA `PhotoCleanupMVE-unsigned.ipa`，**1272446 字节**，
    SHA-256 `cf97d41dc4bce2965b09da1580d5bfcc7c641d5dfbd594b27413e7c66d22c90e`
  - 产物 `PhotoCleanupMVE-unsigned-113384a709f1`，zip 1272616 字节
- **CI 预算 2 次用满 2 次。**
- **G785：合并后 `main` 自动运行 #270**（run id `34217330343`，attempt 1）——**绿**
  - 被测提交 `6b1adeadf371e17fe7805f95928dfba2d0fbaefa`，事件 `push`，分支 `main`
  - **Executed 677 tests, with 0 failures (0 unexpected) in 26.938 (34.005) seconds**
  - 真实退出码 **0**（job `102032074353` success，10 个 step 全 success）
  - IPA **1272446 字节**，
    SHA-256 `c32ba352f4b673654f3faae2d883f674f1654da8941658a801362c52fc9e60c9`
  - 产物 `PhotoCleanupMVE-unsigned-6b1adeadf371`，zip 1272616 字节

## 分支与冻结链状态

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `6b1adea` | 本卡推进（合并提交） |
| `feature/ic-138-housekeeping` | `113384a` | 保留，未删除 |
| `probe/ic-137-media-playback` | `486bcb7` | 未动（IC-137 探针，不合并） |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（工作树） | 0 |
| `git diff --check f8ae50a..6b1adea` | 0 |
