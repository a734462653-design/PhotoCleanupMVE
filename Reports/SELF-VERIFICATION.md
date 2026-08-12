# IC-20260810-007R 自验报告（IC-20260811-001 证据同步）

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
| S3 数量规则 | 已被新基线替代 | 当前结论见 `IC-20260812-010-SELF-VERIFICATION.md` |
| 禁止能力静态门禁 | 已被新基线替代 | 当前结论见 `IC-20260812-010-SELF-VERIFICATION.md` |
| 可达单元格静态映射 | 已被新基线替代 | 当前结论见 `IC-20260812-010-SELF-VERIFICATION.md` |
| XCTest 方法数量 | 已被新基线替代 | 当前结论见 `IC-20260812-010-SELF-VERIFICATION.md` |
| macOS 编译 | 通过 | CI #4 使用 Xcode 16.4；模拟器测试构建与 Release iPhoneOS 构建均成功，日志出现 `BUILD SUCCEEDED` |
| XCTest 执行 | 历史结果 | CI #4 的旧基线结果；当前结果见新基线报告 |
| 未签名 IPA | 通过 | CI #4 生成 210,393 字节的未签名 IPA，验证无代码签名、签名目录或描述文件，并上传为可下载制品 |

下表中的状态同时基于测试方法与断言映射审计，以及 CI #4 的实际 XCTest 结果。

## 3. S3 可达单元格（旧基线记录中已移除的路径不再列出）

| 单元格 | 事件与起始状态 | 测试方法 | 状态 |
|---:|---|---|---|
| 01 | 页面外进入，覆盖空集、未完成、缓存完成三条守卫 | `testCell01EnterFromOutsideWithEmptySetRoutesToS3_4`；`testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted`；`testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan` | 历史结果 |
| 02 | S3-1 扫描完成 → S3-2 | `testCell02ScanCompletionFromS3_1RoutesToS3_2` | 通过（CI #4） |
| 03 | S3-1 扫描中移除，覆盖空集、就绪、仍扫描 | `testCell03RemoveDuringScanLastItemRoutesToS3_4`；`testCell03RemoveDuringScanLastIncompleteItemRoutesToS3_2`；`testCell03RemoveDuringScanWhileIncompleteItemRemainsStaysInS3_1` | 通过（CI #4） |
| 04 | S3-1 移除单项，直接覆盖空集、就绪、仍扫描三条守卫 | `testCell04RemoveOneFromS3_1LastItemRoutesToS3_4`；`testCell04RemoveOneFromS3_1LastIncompleteItemRoutesToS3_2`；`testCell04RemoveOneFromS3_1WhileIncompleteItemRemainsStaysInS3_1` | 通过（CI #4） |
| 05 | S3-2 移除单项，覆盖仍非空与最后一项 | `testCell05RemoveOneFromS3_2WhileNonEmptyStaysInS3_2`；`testCell05RemoveLastItemFromS3_2RoutesToS3_4` | 通过（CI #4） |
| 07 | S3-1 全部取消 → S3-4 | `testCell07CancelAllFromS3_1RoutesToS3_4AndKeepsCache` | 通过（CI #4） |
| 08 | S3-2 全部取消 → S3-4 | `testCell08CancelAllFromS3_2RoutesToS3_4AndKeepsCache` | 通过（CI #4） |
| 11 | S3-1 集合变为空 → S3-4 | `testCell11CollectionBecameEmptyFromS3_1RoutesToS3_4` | 通过（CI #4） |
| 12 | S3-2 集合变为空 → S3-4 | `testCell12CollectionBecameEmptyFromS3_2RoutesToS3_4` | 通过（CI #4） |
| 14 | S3-2 提交并冻结 → S4-1 | `testCell14SubmitFromS3_2FreezesSnapshotForS4_1` | 通过（CI #4） |

冻结失败守卫由空集与扫描未完成测试直接验证。状态机调用为同步原子操作，合法的 S3-2 状态已蕴含两条冻结校验成立，因此没有伪造不稳定的“调用中竞态”测试。

## 4. S4 可达单元格：22/22

| 单元格 | 事件与起始状态 | 测试方法 | 状态 |
|---:|---|---|---|
| 01 | S3-2 外部提交 → S4-1 | `testReachable01SubmissionFromExternalSource` | 通过（CI #4） |
| 02 | S4-1 进入非 active | `testReachable02InactiveFromSubmitted` | 通过（CI #4） |
| 03 | S4-2 进入非 active | `testReachable03InactiveFromResumedInteraction` | 通过（CI #4） |
| 04 | S4-E1 进入非 active | `testReachable04InactiveFromSuccessTerminal` | 通过（CI #4） |
| 05 | S4-E2 进入非 active | `testReachable05InactiveFromFailureTerminal` | 通过（CI #4） |
| 06 | S4-E3 进入非 active | `testReachable06InactiveFromUnknownTerminal` | 通过（CI #4） |
| 07 | S4-1 恢复 active → S4-2 | `testReachable07ActiveFromSubmitted` | 通过（CI #4） |
| 08 | S4-2 恢复 active并续计 | `testReachable08ActiveFromResumedInteraction` | 通过（CI #4） |
| 09 | S4-E1 恢复 active并交接成功 | `testReachable09ActiveFromSuccessTerminal` | 通过（CI #4） |
| 10 | S4-E2 恢复 active并交接失败 | `testReachable10ActiveFromFailureTerminal` | 通过（CI #4） |
| 11 | S4-E3 恢复 active并交接未知 | `testReachable11ActiveFromUnknownTerminal` | 通过（CI #4） |
| 12 | S4-1 收到成功回调 → S4-E1 | `testReachable12SuccessCallbackFromSubmitted` | 通过（CI #4） |
| 13 | S4-2 收到成功回调 → S4-E1 | `testReachable13SuccessCallbackFromResumedInteraction` | 通过（CI #4） |
| 14 | S4-1 收到失败回调 → S4-E2 | `testReachable14FailureCallbackFromSubmitted` | 通过（CI #4） |
| 15 | S4-2 收到失败回调 → S4-E2 | `testReachable15FailureCallbackFromResumedInteraction` | 通过（CI #4） |
| 16 | S4-1 active 累计满 60 秒 → S4-E3 | `testReachable16TimeoutFromSubmitted` | 通过（CI #4） |
| 17 | S4-2 active 累计满 60 秒 → S4-E3 | `testReachable17TimeoutFromResumedInteraction` | 通过（CI #4） |
| 18 | S4-1 进程终止 → 下次恢复为 S4-E3 | `testReachable18TerminationFromSubmitted` | 通过（CI #4） |
| 19 | S4-2 进程终止 → 下次恢复为 S4-E3 | `testReachable19TerminationFromResumedInteraction` | 通过（CI #4） |
| 20 | S4-E1 终止后保持成功终态 | `testReachable20TerminationFromSuccessTerminal` | 通过（CI #4） |
| 21 | S4-E2 终止后保持失败终态 | `testReachable21TerminationFromFailureTerminal` | 通过（CI #4） |
| 22 | S4-E3 终止后保持未知终态 | `testReachable22TerminationFromUnknownTerminal` | 通过（CI #4） |

## 5. 限定 S5 可达单元格：15/15

| 单元格 | 事件与起始状态 | 测试方法 | 状态 |
|---:|---|---|---|
| 01 | S4-E1 → 已移入最近删除 | `testCell01SuccessEntry` | 通过（CI #4） |
| 02 | S4-E2 → 整批失败 | `testCell02FailureEntry` | 通过（CI #4） |
| 03 | S4-E3 → 结果未知 | `testCell03UnknownEntry` | 通过（CI #4） |
| 04 | 成功页离开 → 外部出口 | `testCell04LeaveFromSuccess` | 通过（CI #4） |
| 05 | 失败页返回确认页，覆盖缓存存在与不存在 | `testCell05AReturnFromFailureWithCache`；`testCell05BReturnFromFailureWithoutCache` | 通过（CI #4） |
| 06 | 未知页离开 → 外部出口 | `testCell06LeaveFromUnknown` | 通过（CI #4） |
| 07 | 成功状态进入非 active | `testCell07InactiveFromSuccess` | 通过（CI #4） |
| 08 | 失败状态进入非 active | `testCell08InactiveFromFailure` | 通过（CI #4） |
| 09 | 未知状态进入非 active | `testCell09InactiveFromUnknown` | 通过（CI #4） |
| 10 | 成功状态恢复 active | `testCell10ActiveFromSuccess` | 通过（CI #4） |
| 11 | 失败状态恢复 active | `testCell11ActiveFromFailure` | 通过（CI #4） |
| 12 | 未知状态恢复 active | `testCell12ActiveFromUnknown` | 通过（CI #4） |
| 13 | 成功状态被终止并恢复 | `testCell13TerminationFromSuccess` | 通过（CI #4） |
| 14 | 失败状态被终止并恢复 | `testCell14TerminationFromFailure` | 通过（CI #4） |
| 15 | 未知状态被终止并恢复 | `testCell15TerminationFromUnknown` | 通过（CI #4） |

该节为旧基线记录；按钮与取消页的当前结论见 `IC-20260812-010-SELF-VERIFICATION.md`。

## 6. 共同不变量与集合不变量

| 不变量组 | 主要测试证据 | 当前状态 |
|---|---|---|
| D 去重、保持首现顺序、只减不增、大集合不截断 | `testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder`、`testLargeSelectionQueuesEveryDeduplicatedAssetWithoutTruncation` | 当前测试覆盖 |
| 资产级缓存不绑定集合，移除仍保留，晚到结果照常入缓存 | `testRemovingAssetRetainsItsOnlyCachedConclusion`、`testLateResultForRemovedAssetUpdatesCacheButNotCurrentStatistics`、`testReentryReusesCompletedCacheWithoutQueueingAgain` | 通过（CI #4） |
| 已知总字节与不可用数量按当前 D 即时求和 | `testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD`、精确/下界快照测试 | 通过（CI #4） |
| 非空集合中的未开始项入扫描队列 | 大集合、进行中不重复入队测试 | 当前测试覆盖 |
| 快照一次冻结、字段一致、冻结后 D 不可变 | `SnapshotInvariantTests` 中 20 个测试及 S3 Cell14 | 通过（CI #4） |
| 十进制 MB/GB 且向下截断 | `VolumeFormattingTests` 中 6 个边界测试 | 通过（CI #4） |
| 同一提交标识只允许原子认领一次 | `testSecondStartWithSameSubmissionIdentifierIsRejected` | 通过（CI #4） |
| 持久化失败时不先更新终态或失效列表 | `testPersistenceFailureLeavesCallbackStateUnchanged`、`testStartPersistenceFailurePreventsMachineCreation`、`testEntryPersistenceFailurePreventsListInvalidation`、`testLifecyclePersistenceFailureLeavesStateUnchanged` | 通过（CI #4） |
| 首个有效 S4 终态封闭，迟到回调不能改写 | 三个 `testLate...CannotOverwrite...` 测试 | 通过（CI #4） |
| A、B、C 两两不交且并集严格等于 P | `testDisjointCompleteClassificationIsAccepted`；三种重叠拒绝；越界拒绝；漏项拒绝 | 通过（CI #4） |
| 整批系统失败取 B=P；系统接受前失败取 C=P | `testBatchLevelFailureUsesWholeSubmittedSetAsFailure`、`testFailureBeforeSystemAcceptanceUsesWholeSubmittedSetAsUnprocessed` | 通过（CI #4） |
| 失败原因非空；失败交接不推测或改写三集合 | `testEmptyFailureReasonIsRejected`、`testFailureEntryReusesPersistedClassificationWithoutModification`、`testFailureEntryRejectsInvalidClassification` | 通过（CI #4） |
| 成功交接 A=P；未知交接不构造 A/B/C | `testSuccessResultClassifiesEverySubmittedAssetAsSuccessful`、`testUnknownEntryDoesNotConstructClassificationSets` | 通过（CI #4） |
| 成功进入完成页时先持久化，再失效所有 A 的旧列表 | S5 成功入场测试记录调用顺序及失效集合 | 通过（CI #4） |

`CollectionInvariantTests.swift` 共 15 个方法，逐项覆盖接受、三种两两重叠、越界、漏项、空原因、全成功、整批失败、系统接受前失败、失败交接原样复用、未知不造集合、非法交接拒绝，以及 PhotoKit 用户取消映射为 C=P、普通整批失败映射为 B=P。

## 7. 静态门禁结果

- 产品 Swift 源码中没有 `URLSession`、网络框架、第三方网络库或账号框架。
- 产品 Swift 源码中没有限定范围外的 S5 轮询状态标记、磁盘读取 API、L3 参数或基线实现。
- S5 完成按钮对应属性恒为禁用，状态机没有相应点击事件。
- S4 页面只显示不确定活动指示，不显示逐资产进度、百分比或预计时间。
- PhotoKit 缩略图与资源读取均显式禁止网络取回。
- CI 只引用经安全审查并锁定 40 位提交哈希的官方 `actions/upload-artifact`；上传前验证 IPA 是普通文件且不是符号链接，只传输精确路径的未签名 IPA。源码检出仍只用系统 Git。模拟器 XCTest 允许 Xcode 所需的本地临时签名，Release 真机 SDK 产物仍强制无签名且不安装真机。

## 8. 占位截图

`PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/RECENTLY_DELETED_PLACEHOLDER.png` 是 1 × 1 纯黑 PNG，文件名包含 `PLACEHOLDER`。它只保证工程引用可构建，不视为“实用工具 → 最近删除”正式标注截图，也不计入正式素材交付。

## 9. CI 实跑证据

- 产品仓库：`https://github.com/a734462653-design/PhotoCleanupMVE`
- 验证提交：`986f277f4dc5fe0482912d224e91fc98f46c2acb`
- 成功运行：`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31417173654`（CI #4，状态 `Success`，总时长 5 分 44 秒）
- 成功任务：`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31417173654/job/93548829587`（任务时长 5 分 36 秒）
- 环境：Xcode 16.4、iPhone 16 模拟器、iOS 18.5。
- XCTest：六个测试类分别执行 15、32、38、25、20、6 项；合计 136 项，0 失败、0 unexpected。日志出现 `TEST SUCCEEDED`。
- Release：iPhoneOS 无签名构建成功，日志出现 `BUILD SUCCEEDED`。
- IPA：`PhotoCleanupMVE-unsigned.ipa`，210,393 字节，SHA-256 为 `ab13968fb1c44fcdbf30c08115347902d437fee156bf547a49de9d0e01098c53`。
- Actions 制品：`PhotoCleanupMVE-unsigned-986f277f4dc5`，制品 ID `9074030319`，页面显示 206 KB，制品摘要为 `469d906f5f999c067154b069c3dd02093314e1ff9644e0eb463079d3cdd8d6ba`。
- 制品下载：`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31417173654/artifacts/9074030319`；Actions 页面提供已认证下载控件，上传输入为精确单文件路径 `BuildArtifacts/PhotoCleanupMVE-unsigned.ipa`。

首次运行因默认参数表达式构造主 actor 隔离服务而在 Xcode 16.4 编译失败；修复将构造移入 `@MainActor` 初始化器主体，后续运行首次全绿。本轮 CI #4 在当前交付提交上再次完整通过并上传未签名制品。
