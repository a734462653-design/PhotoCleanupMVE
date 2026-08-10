# IC-20260810-007R 自验报告

生成日期：2026-08-11

## 1. 验证基线

- `SPEC-S3-S4-20260809.v3.md`：`F5B3E7864041875954E10C6CE25ED626685F9A612FF5B78BAAADA117597C970D`
- `SPEC-S5-20260810.v3.md`：`35104505CD2351433E2FD064EFB8BF39A93B9BFCE0D391251D4E903762FA7BE5`
- 本卡限定 S5 只实现已移入最近删除、整批失败、结果未知三种状态；轮询相关状态与 L3 读取均不在本卡范围。

## 2. 当前结论

| 项目 | 结果 | 证据 |
|---|---|---|
| Windows 结构自验 | 通过 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\selfcheck.ps1` 返回 0 |
| 工程文件引用审计 | 通过 | 20 个 Swift 文件均只进入应属目标；工程对象无重复或悬空引用 |
| Bundle ID 隔离 | 通过 | 产品为 `com.iphonephotomanagement.PhotoCleanupMVE`，不等于探针标识 |
| 调试入口 | 通过 | 源码常量为 20，启动后直接以 PhotoKit 返回的前 N 个图片资产建立 D，不实现 S1、S2 |
| S3 上限 | 通过 | 源码常量为 200；超限保留完整 D 且不入扫描队列 |
| 禁止能力静态门禁 | 通过 | 产品 Swift 源码未发现联网、账号、收藏修改、隐藏、归相册、S5 轮询或磁盘空间读取实现 |
| 可达单元格静态映射 | 通过 | S3 14/14、S4 22/22、限定 S5 15/15 |
| XCTest 方法数量 | 136 | 最低门槛为 51；其中 64 个具体迁移路径测试覆盖 51 个不同单元格 |
| macOS 编译 | 通过 | CI #2 使用 Xcode 16.4；模拟器测试构建与 Release iPhoneOS 构建均成功 |
| XCTest 执行 | 通过 | CI #2 共执行 136 项，0 失败、0 unexpected；日志出现 `TEST SUCCEEDED` |
| 未签名 IPA | 通过 | CI #2 生成 210,393 字节的未签名 IPA，并验证无代码签名、签名目录或描述文件 |

下表中的状态同时基于测试方法与断言映射审计，以及 CI #2 的实际 XCTest 结果。

## 3. S3 可达单元格：14/14

| 单元格 | 事件与起始状态 | 测试方法 | 状态 |
|---:|---|---|---|
| 01 | 页面外进入，覆盖空集、超限、未完成、缓存完成四条守卫 | `testCell01EnterFromOutsideWithEmptySetRoutesToS3_4`；`testCell01EnterFromOutsideOverLimitRoutesToS3_3WithoutQueueing`；`testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted`；`testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan` | 通过（CI #2） |
| 02 | S3-1 扫描完成 → S3-2 | `testCell02ScanCompletionFromS3_1RoutesToS3_2` | 通过（CI #2） |
| 03 | S3-1 扫描中移除，覆盖空集、就绪、仍扫描 | `testCell03RemoveDuringScanLastItemRoutesToS3_4`；`testCell03RemoveDuringScanLastIncompleteItemRoutesToS3_2`；`testCell03RemoveDuringScanWhileIncompleteItemRemainsStaysInS3_1` | 通过（CI #2） |
| 04 | S3-1 移除单项，直接覆盖空集、就绪、仍扫描三条守卫 | `testCell04RemoveOneFromS3_1LastItemRoutesToS3_4`；`testCell04RemoveOneFromS3_1LastIncompleteItemRoutesToS3_2`；`testCell04RemoveOneFromS3_1WhileIncompleteItemRemainsStaysInS3_1` | 通过（CI #2） |
| 05 | S3-2 移除单项，覆盖仍非空与最后一项 | `testCell05RemoveOneFromS3_2WhileNonEmptyStaysInS3_2`；`testCell05RemoveLastItemFromS3_2RoutesToS3_4` | 通过（CI #2） |
| 06 | S3-3 移除单项，覆盖仍超限、回落扫描、回落就绪 | `testCell06RemoveOneFromS3_3WhileStillOverLimitStaysInS3_3`；`testCell06RemoveOneFromS3_3ToLimitWithIncompleteItemsRoutesToS3_1`；`testCell06RemoveOneFromS3_3ToLimitWithCompletedCacheRoutesToS3_2` | 通过（CI #2） |
| 07 | S3-1 全部取消 → S3-4 | `testCell07CancelAllFromS3_1RoutesToS3_4AndKeepsCache` | 通过（CI #2） |
| 08 | S3-2 全部取消 → S3-4 | `testCell08CancelAllFromS3_2RoutesToS3_4AndKeepsCache` | 通过（CI #2） |
| 09 | S3-3 全部取消 → S3-4 | `testCell09CancelAllFromS3_3RoutesToS3_4AndKeepsCache` | 通过（CI #2） |
| 10 | S3-3 选择数回落，覆盖扫描、就绪、空集 | `testCell10FallToLimitWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted`；`testCell10FallToLimitWithCompletedCacheRoutesToS3_2`；`testCell10FallToZeroUsesEmptySetRule` | 通过（CI #2） |
| 11 | S3-1 集合变为空 → S3-4 | `testCell11CollectionBecameEmptyFromS3_1RoutesToS3_4` | 通过（CI #2） |
| 12 | S3-2 集合变为空 → S3-4 | `testCell12CollectionBecameEmptyFromS3_2RoutesToS3_4` | 通过（CI #2） |
| 13 | S3-3 集合变为空 → S3-4 | `testCell13CollectionBecameEmptyFromS3_3RoutesToS3_4` | 通过（CI #2） |
| 14 | S3-2 提交并冻结 → S4-1 | `testCell14SubmitFromS3_2FreezesSnapshotForS4_1` | 通过（CI #2） |

冻结失败守卫另由 `testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot`、`testFreezeCountGuardRejectsOverLimitSetAndFormsNoSnapshot`、`testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot` 直接验证。状态机调用为同步原子操作，合法的 S3-2 状态已蕴含两条冻结校验成立，因此没有伪造不稳定的“调用中竞态”测试。

## 4. S4 可达单元格：22/22

| 单元格 | 事件与起始状态 | 测试方法 | 状态 |
|---:|---|---|---|
| 01 | S3-2 外部提交 → S4-1 | `testReachable01SubmissionFromExternalSource` | 通过（CI #2） |
| 02 | S4-1 进入非 active | `testReachable02InactiveFromSubmitted` | 通过（CI #2） |
| 03 | S4-2 进入非 active | `testReachable03InactiveFromResumedInteraction` | 通过（CI #2） |
| 04 | S4-E1 进入非 active | `testReachable04InactiveFromSuccessTerminal` | 通过（CI #2） |
| 05 | S4-E2 进入非 active | `testReachable05InactiveFromFailureTerminal` | 通过（CI #2） |
| 06 | S4-E3 进入非 active | `testReachable06InactiveFromUnknownTerminal` | 通过（CI #2） |
| 07 | S4-1 恢复 active → S4-2 | `testReachable07ActiveFromSubmitted` | 通过（CI #2） |
| 08 | S4-2 恢复 active并续计 | `testReachable08ActiveFromResumedInteraction` | 通过（CI #2） |
| 09 | S4-E1 恢复 active并交接成功 | `testReachable09ActiveFromSuccessTerminal` | 通过（CI #2） |
| 10 | S4-E2 恢复 active并交接失败 | `testReachable10ActiveFromFailureTerminal` | 通过（CI #2） |
| 11 | S4-E3 恢复 active并交接未知 | `testReachable11ActiveFromUnknownTerminal` | 通过（CI #2） |
| 12 | S4-1 收到成功回调 → S4-E1 | `testReachable12SuccessCallbackFromSubmitted` | 通过（CI #2） |
| 13 | S4-2 收到成功回调 → S4-E1 | `testReachable13SuccessCallbackFromResumedInteraction` | 通过（CI #2） |
| 14 | S4-1 收到失败回调 → S4-E2 | `testReachable14FailureCallbackFromSubmitted` | 通过（CI #2） |
| 15 | S4-2 收到失败回调 → S4-E2 | `testReachable15FailureCallbackFromResumedInteraction` | 通过（CI #2） |
| 16 | S4-1 active 累计满 60 秒 → S4-E3 | `testReachable16TimeoutFromSubmitted` | 通过（CI #2） |
| 17 | S4-2 active 累计满 60 秒 → S4-E3 | `testReachable17TimeoutFromResumedInteraction` | 通过（CI #2） |
| 18 | S4-1 进程终止 → 下次恢复为 S4-E3 | `testReachable18TerminationFromSubmitted` | 通过（CI #2） |
| 19 | S4-2 进程终止 → 下次恢复为 S4-E3 | `testReachable19TerminationFromResumedInteraction` | 通过（CI #2） |
| 20 | S4-E1 终止后保持成功终态 | `testReachable20TerminationFromSuccessTerminal` | 通过（CI #2） |
| 21 | S4-E2 终止后保持失败终态 | `testReachable21TerminationFromFailureTerminal` | 通过（CI #2） |
| 22 | S4-E3 终止后保持未知终态 | `testReachable22TerminationFromUnknownTerminal` | 通过（CI #2） |

## 5. 限定 S5 可达单元格：15/15

| 单元格 | 事件与起始状态 | 测试方法 | 状态 |
|---:|---|---|---|
| 01 | S4-E1 → 已移入最近删除 | `testCell01SuccessEntry` | 通过（CI #2） |
| 02 | S4-E2 → 整批失败 | `testCell02FailureEntry` | 通过（CI #2） |
| 03 | S4-E3 → 结果未知 | `testCell03UnknownEntry` | 通过（CI #2） |
| 04 | 成功页离开 → 外部出口 | `testCell04LeaveFromSuccess` | 通过（CI #2） |
| 05 | 失败页返回确认页，覆盖缓存存在与不存在 | `testCell05AReturnFromFailureWithCache`；`testCell05BReturnFromFailureWithoutCache` | 通过（CI #2） |
| 06 | 未知页离开 → 外部出口 | `testCell06LeaveFromUnknown` | 通过（CI #2） |
| 07 | 成功状态进入非 active | `testCell07InactiveFromSuccess` | 通过（CI #2） |
| 08 | 失败状态进入非 active | `testCell08InactiveFromFailure` | 通过（CI #2） |
| 09 | 未知状态进入非 active | `testCell09InactiveFromUnknown` | 通过（CI #2） |
| 10 | 成功状态恢复 active | `testCell10ActiveFromSuccess` | 通过（CI #2） |
| 11 | 失败状态恢复 active | `testCell11ActiveFromFailure` | 通过（CI #2） |
| 12 | 未知状态恢复 active | `testCell12ActiveFromUnknown` | 通过（CI #2） |
| 13 | 成功状态被终止并恢复 | `testCell13TerminationFromSuccess` | 通过（CI #2） |
| 14 | 失败状态被终止并恢复 | `testCell14TerminationFromFailure` | 通过（CI #2） |
| 15 | 未知状态被终止并恢复 | `testCell15TerminationFromUnknown` | 通过（CI #2） |

“我已清空最近删除”没有迁移事件，UI 恒为禁用；由 `testConfirmationButtonIsAlwaysDisabled` 验证。失败页不能经离开动作结束、成功或未知页不能返回确认页，也分别有拒绝测试。

## 6. 共同不变量与集合不变量

| 不变量组 | 主要测试证据 | 当前状态 |
|---|---|---|
| D 去重、保持首现顺序、只减不增、超限不截断 | `testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder`、`testOverLimitKeepsEveryDeduplicatedAssetInsteadOfTruncatingAt200`、`testReductionOnlyRemovesAndPreservesOriginalDOrder`、`testSelectionFallbackRejectsAdditionAndMoreThanLimit` | 通过（CI #2） |
| 资产级缓存不绑定集合，移除仍保留，晚到结果照常入缓存 | `testRemovingAssetRetainsItsOnlyCachedConclusion`、`testLateResultForRemovedAssetUpdatesCacheButNotCurrentStatistics`、`testReentryReusesCompletedCacheWithoutQueueingAgain` | 通过（CI #2） |
| 已知总字节与不可用数量按当前 D 即时求和 | `testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD`、精确/下界快照测试 | 通过（CI #2） |
| 仅 1 至 200 项入扫描队列；只入队未开始项 | 超限、回落边界、进行中不重复入队及 200 边界测试 | 通过（CI #2） |
| 快照一次冻结、字段一致、冻结后 D 不可变 | `SnapshotInvariantTests` 中 20 个测试及 S3 Cell14 | 通过（CI #2） |
| 十进制 MB/GB 且向下截断 | `VolumeFormattingTests` 中 6 个边界测试 | 通过（CI #2） |
| 同一提交标识只允许原子认领一次 | `testSecondStartWithSameSubmissionIdentifierIsRejected` | 通过（CI #2） |
| 持久化失败时不先更新终态或失效列表 | `testPersistenceFailureLeavesCallbackStateUnchanged`、`testStartPersistenceFailurePreventsMachineCreation`、`testEntryPersistenceFailurePreventsListInvalidation`、`testLifecyclePersistenceFailureLeavesStateUnchanged` | 通过（CI #2） |
| 首个有效 S4 终态封闭，迟到回调不能改写 | 三个 `testLate...CannotOverwrite...` 测试 | 通过（CI #2） |
| A、B、C 两两不交且并集严格等于 P | `testDisjointCompleteClassificationIsAccepted`；三种重叠拒绝；越界拒绝；漏项拒绝 | 通过（CI #2） |
| 整批系统失败取 B=P；系统接受前失败取 C=P | `testBatchLevelFailureUsesWholeSubmittedSetAsFailure`、`testFailureBeforeSystemAcceptanceUsesWholeSubmittedSetAsUnprocessed` | 通过（CI #2） |
| 失败原因非空；失败交接不推测或改写三集合 | `testEmptyFailureReasonIsRejected`、`testFailureEntryReusesPersistedClassificationWithoutModification`、`testFailureEntryRejectsInvalidClassification` | 通过（CI #2） |
| 成功交接 A=P；未知交接不构造 A/B/C | `testSuccessResultClassifiesEverySubmittedAssetAsSuccessful`、`testUnknownEntryDoesNotConstructClassificationSets` | 通过（CI #2） |
| 成功进入完成页时先持久化，再失效所有 A 的旧列表 | S5 成功入场测试记录调用顺序及失效集合 | 通过（CI #2） |

`CollectionInvariantTests.swift` 共 15 个方法，逐项覆盖接受、三种两两重叠、越界、漏项、空原因、全成功、整批失败、系统接受前失败、失败交接原样复用、未知不造集合、非法交接拒绝，以及 PhotoKit 用户取消映射为 C=P、普通整批失败映射为 B=P。

## 7. 静态门禁结果

- 产品 Swift 源码中没有 `URLSession`、网络框架、第三方网络库或账号框架。
- 产品 Swift 源码中没有限定范围外的 S5 轮询状态标记、磁盘读取 API、L3 参数或基线实现。
- S5 完成按钮对应属性恒为禁用，状态机没有相应点击事件。
- S4 页面只显示不确定活动指示，不显示逐资产进度、百分比或预计时间。
- PhotoKit 缩略图与资源读取均显式禁止网络取回。
- CI 不引用外部 GitHub Action；只用系统 Git 从本工程仓库读取本次提交。模拟器 XCTest 允许 Xcode 所需的本地临时签名，Release 真机 SDK 产物仍强制无签名且不安装真机。

## 8. 占位截图

`PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/RECENTLY_DELETED_PLACEHOLDER.png` 是 1 × 1 纯黑 PNG，文件名包含 `PLACEHOLDER`。它只保证工程引用可构建，不视为“实用工具 → 最近删除”正式标注截图，也不计入正式素材交付。

## 9. CI 实跑证据

- 产品仓库：`https://github.com/a734462653-design/PhotoCleanupMVE`
- 验证提交：`dee9c08358dc4de2df3ffb8901c609da7afe89ee`
- 成功运行：`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31414159593`
- 成功任务：`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31414159593/job/93539062041`
- 环境：Xcode 16.4、iPhone 16 模拟器、iOS 18.5。
- XCTest：六个测试类分别执行 15、32、38、25、20、6 项；合计 136 项，0 失败、0 unexpected。日志出现 `TEST SUCCEEDED`。
- Release：iPhoneOS 无签名构建成功，日志出现 `BUILD SUCCEEDED`。
- IPA：`PhotoCleanupMVE-unsigned.ipa`，210,393 字节，SHA-256 为 `7aebf4962750b35383f341d36b258564225043afc9a42aa79a2c1520c856dc12`。
- 工作流不上传制品；IPA 只在本次运行器内生成，运行摘要保留其大小与 SHA-256 作为证据。

CI #1 在默认参数表达式中构造主 actor 隔离服务，Xcode 16.4 报编译错误；提交 `dee9c08` 将构造移入 `@MainActor` 初始化器主体。CI #2 随后完整通过。
