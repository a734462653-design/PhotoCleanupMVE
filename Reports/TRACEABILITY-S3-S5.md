# SPEC-S3-S5 XCTest 可追溯矩阵

## 一、范围与判定口径

- 任务：`IC-20260812-021-traceability-rerun`；当前产品与测试证据基线：`c7ed4b18c579fd6d2904ea856dcac404906e2ec0`；上游受验实现提交：`01ebf8263d20a58340aedd78be98cadd06d30eb0`。
- 输入规格：`SPEC-S3-S4-20260812.v6.md` 与 `SPEC-S5-20260812.v5.md`；沿用 IC-20260812-011 的机械提取范围、七个正向字段和四个反向字段。
- 状态迁移表仍按数据单元格编号；单元格坐标与可达/不可达标记保留在判定理由开头，供 `TransitionTableGuardTests` 在运行时读取。
- 方法列只列直接相关的 XCTest 断言。若方法只覆盖复合条款的一部分，仍记录方法，但覆盖判定保守取“未覆盖”。
- `不适用` 理由共五类：`MVE 范围外`、`该条款为未定项阻断`、`该条款为纯文案`、`该条款为纯视觉`、`实现约束比规格更强，该路径在当前实现下不可达`。
- MVE 范围外的机械口径：条款依赖本工程尚未实现的 S1、S2、上游整理页、清理入口页或照片列表页时，判为“不适用：MVE 范围外”，不判“未覆盖”。
- 一致性闸门：候选矩阵写入前，先与 `c7ed4b18c579fd6d2904ea856dcac404906e2ec0` 中的旧矩阵比较 115 个迁移坐标集合及不可达标记集合；任一集合不同均停止且不覆盖现有矩阵。

## 二、汇总

| 指标 | 数量 |
|---|---:|
| 条款总数 | 376 |
| 已覆盖 | 265 |
| 未覆盖 | 72 |
| 不适用 | 39 |
| 第五类不适用 | 2 |
| XCTest 方法总数 | 179 |
| 未命中测试 | 8 |

## 三、正向矩阵

以下为制表符分隔表；每条条款严格占一行。

<!-- 正向矩阵开始 -->
```
条款编号	规格文件	行号	条款原文（逐字，不改写）	对应 XCTest 方法名（可多个，无则留空）	覆盖判定	判定理由
C34-001	SPEC-S3-S4-20260812.v6.md	17	设当前待删集合为 `D`，其去重后的资产数量为 `n`。S3 共三个状态，只允许存在一个当前状态，并按以下优先级归一化：	testCell01EnterFromOutsideWithEmptySetRoutesToS3_4, testCell01EnterFromOutsideWithLargeSetRoutesToS3_1AndQueuesEveryAsset, testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted, testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan	已覆盖	所列方法直接断言该条款。
C34-002	SPEC-S3-S4-20260812.v6.md	19	1. `n = 0`：S3-4 空集。	testCell01EnterFromOutsideWithEmptySetRoutesToS3_4	已覆盖	所列方法直接断言该条款。
C34-003	SPEC-S3-S4-20260812.v6.md	20	2. `n ≥ 1` 且 `D` 中存在结论为“未开始”或“进行中”的项：S3-1 扫描中。	testCell01EnterFromOutsideWithLargeSetRoutesToS3_1AndQueuesEveryAsset, testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted	已覆盖	所列方法直接断言该条款。
C34-004	SPEC-S3-S4-20260812.v6.md	21	3. `n ≥ 1` 且 `D` 中不存在结论为“未开始”或“进行中”的项：S3-2 就绪。	testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan	已覆盖	所列方法直接断言该条款。
C34-005	SPEC-S3-S4-20260812.v6.md	25	- S3 页面从上到下分为三个层级：页面头部导航层、头部信息条、资产内容区。		不适用	该条款为纯视觉
C34-006	SPEC-S3-S4-20260812.v6.md	26	- “返回上游整理页”入口位于页面头部导航层，高于头部信息条与资产内容区；三个 S3 状态均显示该入口。触发后迁出 S3，目标为上游整理页；本文不定义上游整理页的内部目标状态。		不适用	MVE 范围外
C34-007	SPEC-S3-S4-20260812.v6.md	27	- 头部信息条显示当前待删总数，并新增具名占位 `{当前范围说明：显示本轮整理范围的来源}`。该占位只规定必须说明本轮整理范围来自何处，不规定最终文案。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-008	SPEC-S3-S4-20260812.v6.md	28	- 确认页展示 `D` 中的全部资产，不得因收藏标记或体积不可用而隐藏其中任何一项。	testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder	未覆盖	该方法只断言状态机保留完整去重集合，未断言确认页逐项显示。
C34-009	SPEC-S3-S4-20260812.v6.md	29	- 每项至少展示缩略图、稳定资产标识对应的可辨认内容和收藏标记；收藏标记叠加在缩略图左下角，并采用系统“照片”App 的官方样式。收藏标记只作提示，不改变提交资格。	testFavoriteAssetsUseSameScanRulesAndRemainSubmittable	未覆盖	该方法只断言收藏项不影响扫描与提交，未断言缩略图、标识内容和收藏标记的页面呈现。
C34-010	SPEC-S3-S4-20260812.v6.md	30	- 确认页单张缩略图的信息叠加只显示体积，不显示拍摄日期，采用 2a 方案。多资源资产的可展开体积明细遵循“体积扫描规格”中的信息结构。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-011	SPEC-S3-S4-20260812.v6.md	31	- 页面只允许从 `D` 移除待删项，不在 S3 内改变收藏、隐藏或相册归类状态。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-012	SPEC-S3-S4-20260812.v6.md	32	- S3 内的 `D` 只减不增；集合变大只能先返回上游整理页，再以新的 `D` 重新进入确认页。		不适用	MVE 范围外
C34-013	SPEC-S3-S4-20260812.v6.md	33	- 每个资产标识在资产级结论缓存中持有唯一结论，取值为“未开始”“进行中”“已知字节”或“不可用”。结论不绑定集合；资产移出 `D` 时保留其结论，不清除缓存。	testRemovingAssetRetainsItsOnlyCachedConclusion, testUnknownOrNegativeScanResultIsRejectedWithoutChangingCache	已覆盖	所列方法直接断言该条款。
C34-014	SPEC-S3-S4-20260812.v6.md	34	- `已知总字节数` 等于当前 `D` 中结论为“已知字节”的项之和；`unavailableCount` 等于当前 `D` 中结论为“不可用”的项数。两者均为对当前 `D` 的即时求和结果，不通过加减维护。	testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD	已覆盖	所列方法直接断言该条款。
C34-015	SPEC-S3-S4-20260812.v6.md	35	- 移除单项时，只从 `D` 移除该项，保留其缓存结论，并按当前 `D` 重新求和；不重扫、不作废、不减算。	testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD, testRemovingAssetRetainsItsOnlyCachedConclusion, testRemovingQueuedAssetDoesNotInvalidateItsQueuedWork	已覆盖	所列方法直接断言该条款。
C34-016	SPEC-S3-S4-20260812.v6.md	36	- `n ≥ 1` 时，`D` 中结论为“未开始”的项进入扫描队列。	testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted, testLargeSelectionQueuesEveryDeduplicatedAssetWithoutTruncation, testTakingQueueDoesNotQueueInProgressAssetsAgain	已覆盖	所列方法直接断言该条款。
C34-017	SPEC-S3-S4-20260812.v6.md	37	- 晚到的成功或失败结果写入对应资产的结论缓存。该资产仍在 `D` 中时自动进入当前统计；已经移出时不影响当前统计。不设置丢弃规则。	testLateSuccessForCurrentAssetImmediatelyUpdatesCurrentStatistics, testLateFailureForCurrentAssetImmediatelyUpdatesCurrentStatistics, testLateResultForRemovedAssetUpdatesCacheButNotCurrentStatistics	已覆盖	所列方法直接断言该条款。
C34-018	SPEC-S3-S4-20260812.v6.md	38	- 重新进入页面时直接复用各资产已有的缓存结论，不因重新进入而重扫。	testReentryReusesCompletedCacheWithoutQueueingAgain	已覆盖	所列方法直接断言该条款。
C34-019	SPEC-S3-S4-20260812.v6.md	39	- 扫描完成是指当前 `D` 中不存在结论为“未开始”或“进行中”的项。扫描尚未完成时，提交操作必须禁用。	testCell02ScanCompletionFromS3_1RoutesToS3_2, testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot, testOneUnavailableConclusionDoesNotStopOtherScans	已覆盖	所列方法直接断言该条款。
C34-020	SPEC-S3-S4-20260812.v6.md	40	- 任何提交都必须来自 S3-2，并在发起删除请求之前冻结提交集合快照。	testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot, testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot, testC34_020DeletionStartsOnlyAfterSnapshotFreeze	已覆盖	所列专项方法直接断言该条款。
C34-021	SPEC-S3-S4-20260812.v6.md	46	- 页面头部导航层：页面标题、“确认删除”语义说明和“返回上游整理页”入口。		不适用	MVE 范围外
C34-022	SPEC-S3-S4-20260812.v6.md	47	- 头部信息条：当前待删总数 `n` 与 `{当前范围说明：显示本轮整理范围的来源}`。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-023	SPEC-S3-S4-20260812.v6.md	48	- `D` 的完整资产清单；每项显示缩略图、位于左下角且采用系统“照片”App 官方样式的收藏标记、仅含体积的信息叠加和移除入口，不显示拍摄日期。	testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder, testFavoriteAssetsUseSameScanRulesAndRemainSubmittable	未覆盖	方法只断言状态机资产集合和收藏项提交资格，未断言扫描中页面完整呈现。
C34-024	SPEC-S3-S4-20260812.v6.md	49	- L2 体积区域显示“正在计算”，可同时显示当前已知字节总量和当前 `unavailableCount`；这些数值必须标为未完成结果。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-025	SPEC-S3-S4-20260812.v6.md	50	- 不确定活动指示，不显示完成比例。		不适用	该条款为纯视觉
C34-026	SPEC-S3-S4-20260812.v6.md	54	- 浏览待删清单。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-027	SPEC-S3-S4-20260812.v6.md	55	- 移除单项。	testCell03RemoveDuringScanLastItemRoutesToS3_4, testCell03RemoveDuringScanLastIncompleteItemRoutesToS3_2, testCell03RemoveDuringScanWhileIncompleteItemRemainsStaysInS3_1	已覆盖	所列方法直接断言该条款。
C34-028	SPEC-S3-S4-20260812.v6.md	56	- 全部取消。	testCell07CancelAllFromS3_1RoutesToS3_4AndKeepsCache, testCell08CancelAllFromS3_2RoutesToS3_4AndKeepsCache	已覆盖	所列方法直接断言该条款。
C34-029	SPEC-S3-S4-20260812.v6.md	57	- 使用页面头部导航层的入口返回上游整理页；该操作迁出 S3，目标为上游整理页。		不适用	MVE 范围外
C34-030	SPEC-S3-S4-20260812.v6.md	61	- 提交删除。	testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot	已覆盖	所列方法直接断言该条款。
C34-031	SPEC-S3-S4-20260812.v6.md	62	- 对当前扫描结果执行确认或冻结。	testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot	已覆盖	所列方法直接断言该条款。
C34-032	SPEC-S3-S4-20260812.v6.md	63	- 在确认页内改变收藏、隐藏或相册归类状态。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-033	SPEC-S3-S4-20260812.v6.md	67	- 结论更新后 `D` 中已无“未开始”或“进行中”项：迁至 S3-2。	testCell02ScanCompletionFromS3_1RoutesToS3_2	已覆盖	所列方法直接断言该条款。
C34-034	SPEC-S3-S4-20260812.v6.md	68	- 移除单项后 `n = 0`：迁至 S3-4；该项的缓存结论保留。	testCell03RemoveDuringScanLastItemRoutesToS3_4	已覆盖	所列方法直接断言该条款。
C34-035	SPEC-S3-S4-20260812.v6.md	69	- 移除单项后仍为非空，且 `D` 中已无“未开始”或“进行中”项：迁至 S3-2；按当前 `D` 重新求和。	testCell03RemoveDuringScanLastIncompleteItemRoutesToS3_2	已覆盖	所列方法直接断言该条款。
C34-036	SPEC-S3-S4-20260812.v6.md	70	- 移除单项后仍为非空，且 `D` 中仍有“未开始”或“进行中”项：留在 S3-1；按当前 `D` 重新求和，不重扫。	testCell03RemoveDuringScanWhileIncompleteItemRemainsStaysInS3_1	已覆盖	所列方法直接断言该条款。
C34-037	SPEC-S3-S4-20260812.v6.md	71	- 返回上游整理页：迁出 S3，目标为上游整理页；不定义其内部目标状态。		不适用	MVE 范围外
C34-038	SPEC-S3-S4-20260812.v6.md	77	- 页面头部导航层：页面标题、最终确认说明和“返回上游整理页”入口。		不适用	MVE 范围外
C34-039	SPEC-S3-S4-20260812.v6.md	78	- 头部信息条：当前待删总数 `n` 与 `{当前范围说明：显示本轮整理范围的来源}`。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-040	SPEC-S3-S4-20260812.v6.md	79	- `D` 的完整资产清单；每项显示缩略图、位于左下角且采用系统“照片”App 官方样式的收藏标记、仅含体积的信息叠加和移除入口，不显示拍摄日期。	testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder, testFavoriteAssetsUseSameScanRulesAndRemainSubmittable	未覆盖	方法只断言状态机资产集合和收藏项提交资格，未断言就绪页面完整呈现。
C34-041	SPEC-S3-S4-20260812.v6.md	80	- L2 体积结果：`unavailableCount = 0` 时显示精确已知总量；`unavailableCount > 0` 时显示“≥ 已知总量”，并同时显示 `unavailableCount`。	testSnapshotUsesExactModeWhenEveryAssetHasKnownBytes, testSnapshotUsesLowerBoundModeWhenAnyAssetIsUnavailable	未覆盖	方法只断言冻结快照的体积模式，未断言就绪页面的 L2 显示。
C34-042	SPEC-S3-S4-20260812.v6.md	84	- 浏览待删清单。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-043	SPEC-S3-S4-20260812.v6.md	85	- 移除单项。	testCell05RemoveOneFromS3_2WhileNonEmptyStaysInS3_2, testCell05RemoveLastItemFromS3_2RoutesToS3_4	已覆盖	所列方法直接断言该条款。
C34-044	SPEC-S3-S4-20260812.v6.md	86	- 全部取消。	testCell08CancelAllFromS3_2RoutesToS3_4AndKeepsCache	已覆盖	所列方法直接断言该条款。
C34-045	SPEC-S3-S4-20260812.v6.md	87	- 提交删除。集合中存在收藏项时，此操作仍保持可用。	testFavoriteAssetsUseSameScanRulesAndRemainSubmittable, testCell14SubmitFromS3_2FreezesSnapshotForS4_1	已覆盖	所列方法直接断言该条款。
C34-046	SPEC-S3-S4-20260812.v6.md	88	- 使用页面头部导航层的入口返回上游整理页；该操作迁出 S3，目标为上游整理页。		不适用	MVE 范围外
C34-047	SPEC-S3-S4-20260812.v6.md	92	- 跳过快照冻结直接发起删除。	testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testC34_047UnfrozenSnapshotCannotReachDeletionService	已覆盖	所列专项方法直接断言该条款。
C34-048	SPEC-S3-S4-20260812.v6.md	93	- 在确认页内改变收藏、隐藏或相册归类状态。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-049	SPEC-S3-S4-20260812.v6.md	97	- 移除单项后仍为非空：留在 S3-2；保留该项的缓存结论，并按当前 `D` 重新求和，不重扫。	testCell05RemoveOneFromS3_2WhileNonEmptyStaysInS3_2	已覆盖	所列方法直接断言该条款。
C34-050	SPEC-S3-S4-20260812.v6.md	98	- 移除单项后 `n = 0`：迁至 S3-4；保留该项的缓存结论。	testCell05RemoveLastItemFromS3_2RoutesToS3_4	已覆盖	所列方法直接断言该条款。
C34-051	SPEC-S3-S4-20260812.v6.md	99	- 点击提交且快照冻结校验成功：迁至 S4-1。	testCell14SubmitFromS3_2FreezesSnapshotForS4_1	已覆盖	所列方法直接断言该条款。
C34-052	SPEC-S3-S4-20260812.v6.md	100	- 点击提交时快照冻结校验失败：不得发起删除；按共同状态判定规则迁至相应 S3 状态。	testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot, testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot	不适用	实现约束比规格更强，该路径在当前实现下不可达
C34-053	SPEC-S3-S4-20260812.v6.md	101	- 返回上游整理页：迁出 S3，目标为上游整理页；不定义其内部目标状态。		不适用	MVE 范围外
C34-054	SPEC-S3-S4-20260812.v6.md	107	- 页面头部导航层：页面标题和“返回上游整理页”入口。		不适用	MVE 范围外
C34-055	SPEC-S3-S4-20260812.v6.md	108	- 头部信息条：待删总数 0 与 `{当前范围说明：显示本轮整理范围的来源}`。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-056	SPEC-S3-S4-20260812.v6.md	109	- “没有待删除照片”的空状态说明。		不适用	该条款为纯文案
C34-057	SPEC-S3-S4-20260812.v6.md	113	- 使用页面头部导航层的入口返回上游整理页；该操作迁出 S3，目标为上游整理页。		不适用	MVE 范围外
C34-058	SPEC-S3-S4-20260812.v6.md	117	- 提交删除。	testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot	已覆盖	所列方法直接断言该条款。
C34-059	SPEC-S3-S4-20260812.v6.md	118	- 移除单项。	testDisabledOperationsInS3_4HaveNoEffect	已覆盖	所列方法直接断言该条款。
C34-060	SPEC-S3-S4-20260812.v6.md	119	- 全部取消。	testDisabledOperationsInS3_4HaveNoEffect	已覆盖	所列方法直接断言该条款。
C34-061	SPEC-S3-S4-20260812.v6.md	120	- 启动体积扫描。	testCell01EnterFromOutsideWithEmptySetRoutesToS3_4	已覆盖	所列方法直接断言该条款。
C34-062	SPEC-S3-S4-20260812.v6.md	124	- 返回上游整理页：迁出 S3，目标为上游整理页；不定义其内部目标状态。		不适用	MVE 范围外
C34-063	SPEC-S3-S4-20260812.v6.md	125	- 返回上游整理页后以新的非空 `D` 再次进入确认页：存在“未开始”或“进行中”项时进入 S3-1，只将“未开始”项入队；不存在上述两种结论时复用缓存并进入 S3-2。	testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted, testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan, testReentryReusesCompletedCacheWithoutQueueingAgain	不适用	MVE 范围外
C34-064	SPEC-S3-S4-20260812.v6.md	133	| 进入页面 | `n = 0` → S3-4；`n ≥ 1` 且有“未开始”或“进行中”项 → S3-1，只将“未开始”项入队；`n ≥ 1` 且无上述两种结论 → S3-2，直接复用缓存 | 不可达：S3-1 已表示页面完成进入 | 不可达：S3-2 已表示页面完成进入 | 不可达：S3-4 已表示页面完成进入 |	testCell01EnterFromOutsideWithEmptySetRoutesToS3_4, testCell01EnterFromOutsideWithLargeSetRoutesToS3_1AndQueuesEveryAsset, testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted, testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan	已覆盖	可达单元格（事件“进入页面” × 起始状态“页面外”）：所列方法直接断言该单元格。
C34-065	SPEC-S3-S4-20260812.v6.md	133	| 进入页面 | `n = 0` → S3-4；`n ≥ 1` 且有“未开始”或“进行中”项 → S3-1，只将“未开始”项入队；`n ≥ 1` 且无上述两种结论 → S3-2，直接复用缓存 | 不可达：S3-1 已表示页面完成进入 | 不可达：S3-2 已表示页面完成进入 | 不可达：S3-4 已表示页面完成进入 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“进入页面” × 起始状态“S3-1 扫描中”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-066	SPEC-S3-S4-20260812.v6.md	133	| 进入页面 | `n = 0` → S3-4；`n ≥ 1` 且有“未开始”或“进行中”项 → S3-1，只将“未开始”项入队；`n ≥ 1` 且无上述两种结论 → S3-2，直接复用缓存 | 不可达：S3-1 已表示页面完成进入 | 不可达：S3-2 已表示页面完成进入 | 不可达：S3-4 已表示页面完成进入 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“进入页面” × 起始状态“S3-2 就绪”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-067	SPEC-S3-S4-20260812.v6.md	133	| 进入页面 | `n = 0` → S3-4；`n ≥ 1` 且有“未开始”或“进行中”项 → S3-1，只将“未开始”项入队；`n ≥ 1` 且无上述两种结论 → S3-2，直接复用缓存 | 不可达：S3-1 已表示页面完成进入 | 不可达：S3-2 已表示页面完成进入 | 不可达：S3-4 已表示页面完成进入 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“进入页面” × 起始状态“S3-4 空集”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-068	SPEC-S3-S4-20260812.v6.md	134	| 扫描完成 | 不可达：页面外没有 S3 扫描 | `D` 中已无“未开始”或“进行中”项 → S3-2 | 不可达：S3-2 的 `D` 已无未完成项 | 不可达：空集不启动扫描 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“扫描完成” × 起始状态“页面外”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-069	SPEC-S3-S4-20260812.v6.md	134	| 扫描完成 | 不可达：页面外没有 S3 扫描 | `D` 中已无“未开始”或“进行中”项 → S3-2 | 不可达：S3-2 的 `D` 已无未完成项 | 不可达：空集不启动扫描 |	testCell02ScanCompletionFromS3_1RoutesToS3_2	已覆盖	可达单元格（事件“扫描完成” × 起始状态“S3-1 扫描中”）：所列方法直接断言该单元格。
C34-070	SPEC-S3-S4-20260812.v6.md	134	| 扫描完成 | 不可达：页面外没有 S3 扫描 | `D` 中已无“未开始”或“进行中”项 → S3-2 | 不可达：S3-2 的 `D` 已无未完成项 | 不可达：空集不启动扫描 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“扫描完成” × 起始状态“S3-2 就绪”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-071	SPEC-S3-S4-20260812.v6.md	134	| 扫描完成 | 不可达：页面外没有 S3 扫描 | `D` 中已无“未开始”或“进行中”项 → S3-2 | 不可达：S3-2 的 `D` 已无未完成项 | 不可达：空集不启动扫描 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“扫描完成” × 起始状态“S3-4 空集”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-072	SPEC-S3-S4-20260812.v6.md	135	| 扫描中移除项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 不可达：S3-2 没有进行中的扫描 | 不可达：空集没有进行中的扫描 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“扫描中移除项” × 起始状态“页面外”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-073	SPEC-S3-S4-20260812.v6.md	135	| 扫描中移除项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 不可达：S3-2 没有进行中的扫描 | 不可达：空集没有进行中的扫描 |	testCell03RemoveDuringScanLastItemRoutesToS3_4, testCell03RemoveDuringScanLastIncompleteItemRoutesToS3_2, testCell03RemoveDuringScanWhileIncompleteItemRemainsStaysInS3_1	已覆盖	可达单元格（事件“扫描中移除项” × 起始状态“S3-1 扫描中”）：所列方法直接断言该单元格。
C34-074	SPEC-S3-S4-20260812.v6.md	135	| 扫描中移除项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 不可达：S3-2 没有进行中的扫描 | 不可达：空集没有进行中的扫描 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“扫描中移除项” × 起始状态“S3-2 就绪”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-075	SPEC-S3-S4-20260812.v6.md	135	| 扫描中移除项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 不可达：S3-2 没有进行中的扫描 | 不可达：空集没有进行中的扫描 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“扫描中移除项” × 起始状态“S3-4 空集”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-076	SPEC-S3-S4-20260812.v6.md	136	| 移除单项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 移除后仍非空 → S3-2；移除最后一项 → S3-4；均保留该项缓存并按当前 `D` 重新求和 | 不可达：空集没有可移除项且操作禁用 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“移除单项” × 起始状态“页面外”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-077	SPEC-S3-S4-20260812.v6.md	136	| 移除单项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 移除后仍非空 → S3-2；移除最后一项 → S3-4；均保留该项缓存并按当前 `D` 重新求和 | 不可达：空集没有可移除项且操作禁用 |	testCell04RemoveOneFromS3_1LastItemRoutesToS3_4, testCell04RemoveOneFromS3_1LastIncompleteItemRoutesToS3_2, testCell04RemoveOneFromS3_1WhileIncompleteItemRemainsStaysInS3_1	已覆盖	可达单元格（事件“移除单项” × 起始状态“S3-1 扫描中”）：所列方法直接断言该单元格。
C34-078	SPEC-S3-S4-20260812.v6.md	136	| 移除单项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 移除后仍非空 → S3-2；移除最后一项 → S3-4；均保留该项缓存并按当前 `D` 重新求和 | 不可达：空集没有可移除项且操作禁用 |	testCell05RemoveOneFromS3_2WhileNonEmptyStaysInS3_2, testCell05RemoveLastItemFromS3_2RoutesToS3_4	已覆盖	可达单元格（事件“移除单项” × 起始状态“S3-2 就绪”）：所列方法直接断言该单元格。
C34-079	SPEC-S3-S4-20260812.v6.md	136	| 移除单项 | 不可达：页面外没有移除入口 | 移除后 `n = 0` → S3-4；仍非空且 `D` 已无未完成项 → S3-2；否则 → S3-1；均保留该项缓存并按当前 `D` 重新求和 | 移除后仍非空 → S3-2；移除最后一项 → S3-4；均保留该项缓存并按当前 `D` 重新求和 | 不可达：空集没有可移除项且操作禁用 |	testDisabledOperationsInS3_4HaveNoEffect, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“移除单项” × 起始状态“S3-4 空集”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-080	SPEC-S3-S4-20260812.v6.md	137	| 全部取消 | 不可达：页面外没有全部取消入口 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：空集的全部取消操作禁用 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“全部取消” × 起始状态“页面外”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-081	SPEC-S3-S4-20260812.v6.md	137	| 全部取消 | 不可达：页面外没有全部取消入口 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：空集的全部取消操作禁用 |	testCell07CancelAllFromS3_1RoutesToS3_4AndKeepsCache	已覆盖	可达单元格（事件“全部取消” × 起始状态“S3-1 扫描中”）：所列方法直接断言该单元格。
C34-082	SPEC-S3-S4-20260812.v6.md	137	| 全部取消 | 不可达：页面外没有全部取消入口 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：空集的全部取消操作禁用 |	testCell08CancelAllFromS3_2RoutesToS3_4AndKeepsCache	已覆盖	可达单元格（事件“全部取消” × 起始状态“S3-2 就绪”）：所列方法直接断言该单元格。
C34-083	SPEC-S3-S4-20260812.v6.md	137	| 全部取消 | 不可达：页面外没有全部取消入口 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：空集的全部取消操作禁用 |	testDisabledOperationsInS3_4HaveNoEffect, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“全部取消” × 起始状态“S3-4 空集”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-084	SPEC-S3-S4-20260812.v6.md	138	| 集合变为空 | 不可达：首次进入空集由“进入页面”事件路由 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：S3-4 的集合已经为空 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“集合变为空” × 起始状态“页面外”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-085	SPEC-S3-S4-20260812.v6.md	138	| 集合变为空 | 不可达：首次进入空集由“进入页面”事件路由 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：S3-4 的集合已经为空 |	testCell11CollectionBecameEmptyFromS3_1RoutesToS3_4	已覆盖	可达单元格（事件“集合变为空” × 起始状态“S3-1 扫描中”）：所列方法直接断言该单元格。
C34-086	SPEC-S3-S4-20260812.v6.md	138	| 集合变为空 | 不可达：首次进入空集由“进入页面”事件路由 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：S3-4 的集合已经为空 |	testCell12CollectionBecameEmptyFromS3_2RoutesToS3_4	已覆盖	可达单元格（事件“集合变为空” × 起始状态“S3-2 就绪”）：所列方法直接断言该单元格。
C34-087	SPEC-S3-S4-20260812.v6.md	138	| 集合变为空 | 不可达：首次进入空集由“进入页面”事件路由 | → S3-4；所有资产的缓存结论保留 | → S3-4；所有资产的缓存结论保留 | 不可达：S3-4 的集合已经为空 |	testDisabledOperationsInS3_4HaveNoEffect, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“集合变为空” × 起始状态“S3-4 空集”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-088	SPEC-S3-S4-20260812.v6.md	139	| 点击提交 | 不可达：页面外没有提交入口 | 不可达：提交操作禁用，原因是扫描未完成 | 两项校验与原子冻结成功 → S4-1；校验失败则按共同状态判定规则回到相应 S3 状态 | 不可达：提交操作禁用，原因是集合为空 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“点击提交” × 起始状态“页面外”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-089	SPEC-S3-S4-20260812.v6.md	139	| 点击提交 | 不可达：页面外没有提交入口 | 不可达：提交操作禁用，原因是扫描未完成 | 两项校验与原子冻结成功 → S4-1；校验失败则按共同状态判定规则回到相应 S3 状态 | 不可达：提交操作禁用，原因是集合为空 |	testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“点击提交” × 起始状态“S3-1 扫描中”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-090	SPEC-S3-S4-20260812.v6.md	139	| 点击提交 | 不可达：页面外没有提交入口 | 不可达：提交操作禁用，原因是扫描未完成 | 两项校验与原子冻结成功 → S4-1；校验失败则按共同状态判定规则回到相应 S3 状态 | 不可达：提交操作禁用，原因是集合为空 |	testCell14SubmitFromS3_2FreezesSnapshotForS4_1	不适用	可达单元格（事件“点击提交” × 起始状态“S3-2 就绪”）：实现约束比规格更强，该路径在当前实现下不可达
C34-091	SPEC-S3-S4-20260812.v6.md	139	| 点击提交 | 不可达：页面外没有提交入口 | 不可达：提交操作禁用，原因是扫描未完成 | 两项校验与原子冻结成功 → S4-1；校验失败则按共同状态判定规则回到相应 S3 状态 | 不可达：提交操作禁用，原因是集合为空 |	testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“点击提交” × 起始状态“S3-4 空集”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-092	SPEC-S3-S4-20260812.v6.md	143	提交集合快照是不可变记录。它只在 S3-2 的提交操作中产生，不允许在 S4 中增删或替换资产。	testSnapshotRemainsImmutableAfterCacheReceivesAnotherResult, testFrozenSnapshotPreventsLaterMutationOfD, testSecondFreezeIsRejectedAndOriginalSnapshotIsKept, testSnapshotNeverChangesInsideExecutionState	已覆盖	所列方法直接断言该条款。
C34-093	SPEC-S3-S4-20260812.v6.md	147	| `提交标识` | 全局唯一字符串 | 点击提交后、删除请求发起前生成 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testSecondStartWithSameSubmissionIdentifierIsRejected	未覆盖	方法断言提交标识被写入并拒绝重复使用，但未直接证明生成值全局唯一，也未断言字段在目标 S5 接收时结束。
C34-094	SPEC-S3-S4-20260812.v6.md	148	| `资产标识集合` | 有序字符串数组；元素唯一；长度至少为 1 | 原子读取当前 `D` 时冻结 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder, testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testLargeCompletedSelectionCanBeFrozenWithoutTruncation	未覆盖	方法断言有序、唯一、非空及冻结值，但未直接断言字段在目标 S5 接收时结束。
C34-095	SPEC-S3-S4-20260812.v6.md	149	| `资产数量` | 非负整数；必须等于资产标识集合长度 | 与资产标识集合同时冻结 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testLargeCompletedSelectionCanBeFrozenWithoutTruncation	未覆盖	方法断言资产数量与集合长度相等，但未直接断言字段在目标 S5 接收时结束。
C34-096	SPEC-S3-S4-20260812.v6.md	150	| `已知总字节数` | 非负整数；等于当前资产标识集合中结论为“已知字节”的项之和 | 校验通过后对当前 `D` 即时求和，并与全部快照字段一并原子冻结 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD, testSnapshotUsesExactModeWhenEveryAssetHasKnownBytes, testSnapshotUsesLowerBoundModeWhenAnyAssetIsUnavailable, testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testUnknownOrNegativeScanResultIsRejectedWithoutChangingCache	未覆盖	方法断言非负即时求和值及冻结值，但未直接断言字段在目标 S5 接收时结束。
C34-097	SPEC-S3-S4-20260812.v6.md	151	| `unavailableCount` | 非负整数；必须等于当前资产标识集合中结论为“不可用”的项数，且不得大于资产数量 | 校验通过后对当前 `D` 即时求和，并与全部快照字段一并原子冻结 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD, testSnapshotUsesLowerBoundModeWhenAnyAssetIsUnavailable, testCell14SubmitFromS3_2FreezesSnapshotForS4_1	未覆盖	方法断言不可用项计数及冻结值，但未直接断言字段在目标 S5 接收时结束。
C34-098	SPEC-S3-S4-20260812.v6.md	152	| `体积显示模式` | 枚举：`精确` 或 `下界`；前者要求 `unavailableCount = 0`，后者要求 `unavailableCount > 0` | 由对当前 `D` 的即时求和结果派生，并与全部快照字段一并原子冻结 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testSnapshotUsesExactModeWhenEveryAssetHasKnownBytes, testSnapshotUsesLowerBoundModeWhenAnyAssetIsUnavailable, testCell14SubmitFromS3_2FreezesSnapshotForS4_1	未覆盖	方法断言两种枚举及派生条件，但未直接断言字段在目标 S5 接收时结束。
C34-099	SPEC-S3-S4-20260812.v6.md	153	| `收藏资产标识集合` | 字符串集合；必须是资产标识集合的子集 | 提交时按页面已知收藏标记冻结；不参与提交资格判定 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testFavoriteAssetsUseSameScanRulesAndRemainSubmittable, testCell14SubmitFromS3_2FreezesSnapshotForS4_1	未覆盖	方法断言收藏集合冻结且不阻断提交，但未直接断言字段在目标 S5 接收时结束。
C34-100	SPEC-S3-S4-20260812.v6.md	154	| `冻结时间` | 带时区的时间戳 | 与全部快照字段一并原子冻结 | 对应 S4 终态数据被目标 S5 状态接收时结束 |	testCell14SubmitFromS3_2FreezesSnapshotForS4_1	未覆盖	方法断言冻结时间值，但未直接断言字段在目标 S5 接收时结束。
C34-101	SPEC-S3-S4-20260812.v6.md	156	冻结校验只包括以下两条：	testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot, testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot, testFavoriteAssetsUseSameScanRulesAndRemainSubmittable, testLargeCompletedSelectionCanBeFrozenWithoutTruncation	未覆盖	方法直接断言两条冻结守卫并覆盖部分合法输入，但无法穷尽证明不存在第三类冻结校验。
C34-102	SPEC-S3-S4-20260812.v6.md	158	1. `n ≥ 1`。	testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot	已覆盖	所列方法直接断言该条款。
C34-103	SPEC-S3-S4-20260812.v6.md	159	2. `D` 中不存在结论为“未开始”或“进行中”的项。	testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot	已覆盖	所列方法直接断言该条款。
C34-104	SPEC-S3-S4-20260812.v6.md	161	两条均通过后，对同一个当前 `D` 即时求出 `已知总字节数` 与 `unavailableCount`，并一次性原子冻结表中的全部快照字段；最后才允许发起删除请求。任一校验失败都不得形成可提交快照，也不得发起删除。	testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot, testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot, testC34_104FreezeFailureDoesNotCallDeletionService	已覆盖	所列专项方法直接断言该条款。
C34-105	SPEC-S3-S4-20260812.v6.md	189	- S4 使用 S3 冻结的提交集合快照；S4 内不允许修改该快照。	testSnapshotNeverChangesInsideExecutionState, testSnapshotRemainsImmutableAfterCacheReceivesAnotherResult	已覆盖	所列方法直接断言该条款。
C34-106	SPEC-S3-S4-20260812.v6.md	190	- 同一提交标识只能发起一次批次请求，重复提交必须被阻止。	testDuplicateSubmissionIsRejected, testSecondStartWithSameSubmissionIdentifierIsRejected	已覆盖	所列方法直接断言该条款。
C34-107	SPEC-S3-S4-20260812.v6.md	191	- S4-1 与 S4-2 只显示不确定活动指示。不得按单个资产依次刷新处理进展，不得显示任何完成比例数值，也不得给出预计完成时间。	testReachable01SubmissionFromExternalSource, testReachable07ActiveFromSubmitted	未覆盖	方法只断言计时状态，未断言执行页的不确定活动指示、无单项进度、无比例及无预计时间。
C34-108	SPEC-S3-S4-20260812.v6.md	192	- 收到回调时必须先持久化回调与终态，再更新界面或向目标状态交接，避免界面已显示终态而结果尚未保存。	testPersistenceFailureLeavesCallbackStateUnchanged, testUserCancellationWritesCancelledTargetBeforeHandoff	已覆盖	所列方法直接断言该条款。
C34-109	SPEC-S3-S4-20260812.v6.md	193	- 第一个有效终态一经持久化即封闭该提交；其后的迟到回调不得改写 S4 终态。	testLateFailureCannotOverwriteSuccess, testLateSuccessCannotOverwriteFailure, testLateCallbackCannotOverwriteUnknown, testRestoreKeepsClosedTerminalState	已覆盖	所列方法直接断言该条款。
C34-110	SPEC-S3-S4-20260812.v6.md	199	- “删除请求已提交”的状态标题。		不适用	该条款为纯文案
C34-111	SPEC-S3-S4-20260812.v6.md	200	- 不确定活动指示。		不适用	该条款为纯视觉
C34-112	SPEC-S3-S4-20260812.v6.md	201	- 本次提交的资产总数。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-113	SPEC-S3-S4-20260812.v6.md	202	- “正在等待系统返回结果”的说明；不得宣称资产已删除或空间已释放。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-114	SPEC-S3-S4-20260812.v6.md	206	- 无会改变提交结果的应用内操作；系统级返回桌面或切换应用不属于应用内操作。	testDuplicateSubmissionIsRejected, testC34_114SubmittedStateRejectsEveryFullPartialAndModifiedResubmission	已覆盖	所列专项方法直接断言该条款。
C34-115	SPEC-S3-S4-20260812.v6.md	210	- 再次提交同一快照。	testDuplicateSubmissionIsRejected, testSecondStartWithSameSubmissionIdentifierIsRejected	已覆盖	所列方法直接断言该条款。
C34-116	SPEC-S3-S4-20260812.v6.md	211	- 修改、取消或拆分已提交快照。	testSnapshotNeverChangesInsideExecutionState, testC34_116SubmittedSnapshotCannotBeModifiedCancelledOrSplit	已覆盖	所列专项方法直接断言该条款。
C34-117	SPEC-S3-S4-20260812.v6.md	212	- 展示按单项更新的处理情况或完成比例。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-118	SPEC-S3-S4-20260812.v6.md	216	- 收到成功回调：迁至 S4-E1，并取消超时计时。	testReachable12SuccessCallbackFromSubmitted	已覆盖	所列方法直接断言该条款。
C34-119	SPEC-S3-S4-20260812.v6.md	217	- 收到失败回调：迁至 S4-E2，并取消超时计时。	testReachable14FailureCallbackFromSubmitted	已覆盖	所列方法直接断言该条款。
C34-120	SPEC-S3-S4-20260812.v6.md	218	- active 累计等待达到 60 秒且仍无有效回调：迁至 S4-E3。	testReachable16TimeoutFromSubmitted, testElapsedTimeBelowLimitKeepsPendingState	已覆盖	所列方法直接断言该条款。
C34-121	SPEC-S3-S4-20260812.v6.md	219	- 应用进入非 active：留在 S4-1，暂停并保存已累计的 active 时长。	testReachable02InactiveFromSubmitted, testInactiveDurationDoesNotAccumulate	已覆盖	所列方法直接断言该条款。
C34-122	SPEC-S3-S4-20260812.v6.md	220	- 应用由非 active 恢复为 active 且尚无终态：迁至 S4-2，并从剩余时长继续累计。	testReachable07ActiveFromSubmitted, testResumeContinuesRemainingActiveTime	已覆盖	所列方法直接断言该条款。
C34-123	SPEC-S3-S4-20260812.v6.md	221	- 应用在尚无持久化终态时被系统终止：下次启动检测到未闭合提交后迁至 S4-E3。	testReachable18TerminationFromSubmitted, testRestoreConvertsSubmittedStateToUnknown	已覆盖	所列方法直接断言该条款。
C34-124	SPEC-S3-S4-20260812.v6.md	232	- “正在确认删除结果”的状态标题。		不适用	该条款为纯文案
C34-125	SPEC-S3-S4-20260812.v6.md	233	- 不确定活动指示。		不适用	该条款为纯视觉
C34-126	SPEC-S3-S4-20260812.v6.md	234	- 本次提交的资产总数。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-127	SPEC-S3-S4-20260812.v6.md	235	- “等待系统返回结果”的说明；不得宣称资产已删除或空间已释放。		不适用	该条款为纯文案
C34-128	SPEC-S3-S4-20260812.v6.md	239	- 无会改变提交结果的应用内操作。	testDuplicateSubmissionIsRejected, testSnapshotNeverChangesInsideExecutionState, testC34_128ResumedStateRejectsEveryResultChangingAppOperation	已覆盖	所列专项方法直接断言该条款。
C34-129	SPEC-S3-S4-20260812.v6.md	243	- 再次提交同一快照。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-130	SPEC-S3-S4-20260812.v6.md	244	- 修改、取消或拆分已提交快照。	testSnapshotNeverChangesInsideExecutionState, testC34_130ResumedSnapshotCannotBeModifiedCancelledOrSplit	已覆盖	所列专项方法直接断言该条款。
C34-131	SPEC-S3-S4-20260812.v6.md	245	- 展示按单项更新的处理情况或完成比例。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-132	SPEC-S3-S4-20260812.v6.md	246	- 手动把等待状态判为成功或失败。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-133	SPEC-S3-S4-20260812.v6.md	250	- 收到成功回调：迁至 S4-E1，并取消超时计时。	testReachable13SuccessCallbackFromResumedInteraction	已覆盖	所列方法直接断言该条款。
C34-134	SPEC-S3-S4-20260812.v6.md	251	- 收到失败回调：迁至 S4-E2，并取消超时计时。	testReachable15FailureCallbackFromResumedInteraction	已覆盖	所列方法直接断言该条款。
C34-135	SPEC-S3-S4-20260812.v6.md	252	- active 累计等待达到 60 秒且仍无有效回调：迁至 S4-E3。	testReachable17TimeoutFromResumedInteraction	已覆盖	所列方法直接断言该条款。
C34-136	SPEC-S3-S4-20260812.v6.md	253	- 应用进入非 active：留在 S4-2 并暂停计时；应用由非 active 恢复为 active 后从剩余时长继续，不重置已累计的 active 时长。	testReachable03InactiveFromResumedInteraction, testReachable08ActiveFromResumedInteraction, testInactiveDurationDoesNotAccumulate, testResumeContinuesRemainingActiveTime	已覆盖	所列方法直接断言该条款。
C34-137	SPEC-S3-S4-20260812.v6.md	254	- 应用在尚无持久化终态时被系统终止：下次启动检测到未闭合提交后迁至 S4-E3。	testReachable19TerminationFromResumedInteraction, testRestoreConvertsResumedStateToUnknown	已覆盖	所列方法直接断言该条款。
C34-138	SPEC-S3-S4-20260812.v6.md	260	- 批次成功的终态标识。	testReachable12SuccessCallbackFromSubmitted, testReachable13SuccessCallbackFromResumedInteraction	未覆盖	方法断言成功终态模型，未断言执行页呈现终态标识。
C34-139	SPEC-S3-S4-20260812.v6.md	261	- 提交资产数量与成功资产数量；两者必须相等。	testSuccessResultClassifiesEverySubmittedAssetAsSuccessful	未覆盖	方法断言成功集合等于提交集合，未断言页面显示的两个数量。
C34-140	SPEC-S3-S4-20260812.v6.md	262	- 已停止的活动指示区域，不再显示进行中状态。		不适用	该条款为纯视觉
C34-141	SPEC-S3-S4-20260812.v6.md	266	- 无；完成终态持久化后自动交接。	testReachable12SuccessCallbackFromSubmitted, testReachable09ActiveFromSuccessTerminal	已覆盖	所列方法直接断言该条款。
C34-142	SPEC-S3-S4-20260812.v6.md	270	- 修改终态集合。	testLateFailureCannotOverwriteSuccess, testReachable20TerminationFromSuccessTerminal	已覆盖	所列方法直接断言该条款。
C34-143	SPEC-S3-S4-20260812.v6.md	271	- 再次提交同一快照。	testSecondStartWithSameSubmissionIdentifierIsRejected	已覆盖	所列方法直接断言该条款。
C34-144	SPEC-S3-S4-20260812.v6.md	272	- 恢复 S4 计时。	testReachable12SuccessCallbackFromSubmitted, testReachable04InactiveFromSuccessTerminal	已覆盖	所列方法直接断言该条款。
C34-145	SPEC-S3-S4-20260812.v6.md	276	- 终态及快照引用持久化完成，且可以进行页面交接：迁至 S5-T0。	testReachable12SuccessCallbackFromSubmitted, testReachable09ActiveFromSuccessTerminal	已覆盖	所列方法直接断言该条款。
C34-146	SPEC-S3-S4-20260812.v6.md	277	- 若交接前应用处于非 active 或被终止：保持已持久化的 S4-E1；下次应用恢复 active 后继续迁至 S5-T0。	testReachable04InactiveFromSuccessTerminal, testReachable09ActiveFromSuccessTerminal, testReachable20TerminationFromSuccessTerminal, testC34_146SuccessTerminalWaitsWhileInactiveAndContinuesAfterRestart	已覆盖	所列专项方法直接断言该条款。
C34-147	SPEC-S3-S4-20260812.v6.md	283	- 批次失败的终态标识。	testReachable14FailureCallbackFromSubmitted, testReachable15FailureCallbackFromResumedInteraction	未覆盖	方法断言失败终态模型，未断言执行页呈现终态标识。
C34-148	SPEC-S3-S4-20260812.v6.md	284	- 成功集合、失败集合、未处理集合各自的数量。	testDisjointCompleteClassificationIsAccepted	未覆盖	方法断言三个集合被保存，未断言页面显示各集合数量。
C34-149	SPEC-S3-S4-20260812.v6.md	285	- 非空失败原因。	testEmptyFailureReasonIsRejected	未覆盖	方法断言空失败原因被拒绝，未断言页面呈现非空失败原因。
C34-150	SPEC-S3-S4-20260812.v6.md	286	- 已停止的活动指示区域，不再显示进行中状态。		不适用	该条款为纯视觉
C34-151	SPEC-S3-S4-20260812.v6.md	290	- 无；完成终态持久化后自动交接。	testReachable14FailureCallbackFromSubmitted, testReachable10ActiveFromFailureTerminal	已覆盖	所列方法直接断言该条款。
C34-152	SPEC-S3-S4-20260812.v6.md	294	- 修改三个结果集合。	testDisjointCompleteClassificationIsAccepted, testC34_152FailureTerminalResultSetsRemainImmutableForEveryLaterEvent	已覆盖	所列专项方法直接断言该条款。
C34-153	SPEC-S3-S4-20260812.v6.md	295	- 在 S4 内再次提交全部或部分资产。	testSecondStartWithSameSubmissionIdentifierIsRejected, testC34_153FailureTerminalRejectsWholeAndPartialResubmission	已覆盖	所列专项方法直接断言该条款。
C34-154	SPEC-S3-S4-20260812.v6.md	296	- 把失败结果显示为成功。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-155	SPEC-S3-S4-20260812.v6.md	297	- 恢复 S4 计时。	testReachable14FailureCallbackFromSubmitted, testReachable05InactiveFromFailureTerminal	已覆盖	所列方法直接断言该条款。
C34-156	SPEC-S3-S4-20260812.v6.md	301	- 失败回调、三个结果集合及快照引用持久化完成后，S4 按 `失败原因.类别码` 计算并写入 `下游目标状态`：`用户取消` → `S5-C`；`权限不足` / `资产不可删除` / `未知` → `S5-F`；可以进行页面交接时迁至该状态。	testUserCancellationWritesCancelledTargetBeforeHandoff, testOtherFailureCategoriesWriteFailureTarget, testReachable14FailureCallbackFromSubmitted	已覆盖	所列方法直接断言该条款。
C34-157	SPEC-S3-S4-20260812.v6.md	302	- 若交接前应用处于非 active 或被终止：保持已持久化的 S4-E2；下次应用恢复 active 后按已写入的 `下游目标状态` 继续迁至 `S5-C` 或 `S5-F`，不重新分流。	testReachable05InactiveFromFailureTerminal, testReachable10ActiveFromFailureTerminal, testUserCancellationWritesCancelledTargetBeforeHandoff, testOtherFailureCategoriesWriteFailureTarget, testC34_157FailureTargetSurvivesTerminationWithoutReclassification	已覆盖	所列专项方法直接断言该条款。
C34-158	SPEC-S3-S4-20260812.v6.md	308	- “结果未知”的终态标识。		不适用	该条款为纯文案
C34-159	SPEC-S3-S4-20260812.v6.md	309	- 本次提交的资产总数。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C34-160	SPEC-S3-S4-20260812.v6.md	310	- 触发原因：active 累计等待超时，或应用在未取得持久化终态期间被系统终止。	testReachable16TimeoutFromSubmitted, testReachable18TerminationFromSubmitted	未覆盖	方法断言两种未知原因状态，未断言页面显示触发原因。
C34-161	SPEC-S3-S4-20260812.v6.md	311	- 已停止的活动指示区域，不得把未知状态表达为成功或失败。	testReachable16TimeoutFromSubmitted, testReachable18TerminationFromSubmitted	未覆盖	方法断言未知终态与计时停止，未断言活动指示区域及页面措辞。
C34-162	SPEC-S3-S4-20260812.v6.md	315	- 无；完成终态持久化后自动交接。	testReachable11ActiveFromUnknownTerminal	已覆盖	所列方法直接断言该条款。
C34-163	SPEC-S3-S4-20260812.v6.md	319	- 推断任一资产成功或失败。	testUnknownEntryDoesNotConstructClassificationSets, testC34_163UnknownTerminalRejectsSuccessAndFailureInference	已覆盖	所列专项方法直接断言该条款。
C34-164	SPEC-S3-S4-20260812.v6.md	320	- 修改提交集合快照。	testSnapshotNeverChangesInsideExecutionState	已覆盖	所列方法直接断言该条款。
C34-165	SPEC-S3-S4-20260812.v6.md	321	- 在 S4 内再次提交全部或部分资产。	testSecondStartWithSameSubmissionIdentifierIsRejected, testC34_165UnknownTerminalRejectsWholeAndPartialResubmission	已覆盖	所列专项方法直接断言该条款。
C34-166	SPEC-S3-S4-20260812.v6.md	322	- 接受迟到回调改写已封闭终态。	testLateCallbackCannotOverwriteUnknown, testC34_166LateFailureCannotOverwriteUnknownTerminal	已覆盖	所列专项方法直接断言该条款。
C34-167	SPEC-S3-S4-20260812.v6.md	326	- 未知终态、触发原因及快照引用持久化完成，且可以进行页面交接：迁至 S5-U。	testReachable11ActiveFromUnknownTerminal	已覆盖	所列方法直接断言该条款。
C34-168	SPEC-S3-S4-20260812.v6.md	327	- 若交接前应用处于非 active 或被终止：保持已持久化的 S4-E3；下次应用恢复 active 后继续迁至 S5-U。	testReachable22TerminationFromUnknownTerminal, testReachable11ActiveFromUnknownTerminal	未覆盖	方法分别断言未知终态被终止时保留及未闭合提交终止后可交接，但未直接覆盖已持久化 S4-E3 在重启后继续交接。
C34-169	SPEC-S3-S4-20260812.v6.md	331	页面交接前，S4 必须计算并写入字段 `下游目标状态`。其取值域为 {`S5-T0`, `S5-F`, `S5-C`, `S5-U`}：`S4-E1` → `S5-T0`；`S4-E2` 按 `失败原因.类别码` 分流，`用户取消` → `S5-C`，`权限不足` / `资产不可删除` / `未知` → `S5-F`；`S4-E3` → `S5-U`。	testDownstreamTargetStateValueDomainIsComplete, testReachable12SuccessCallbackFromSubmitted, testUserCancellationWritesCancelledTargetBeforeHandoff, testOtherFailureCategoriesWriteFailureTarget, testReachable16TimeoutFromSubmitted, testPersistedSessionCarriesDownstreamTargetState	已覆盖	所列方法直接断言该条款。
C34-170	SPEC-S3-S4-20260812.v6.md	337	| 提交发起 | 快照冻结成功并发起批次请求 → S4-1，立即开始累计 60 秒 | 不可达：同一提交标识禁止重复发起 | 不可达：恢复期间禁止重复发起 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 |	testReachable01SubmissionFromExternalSource	已覆盖	可达单元格（事件“提交发起” × 起始状态“S3-2 外部源”）：所列方法直接断言该单元格。
C34-171	SPEC-S3-S4-20260812.v6.md	337	| 提交发起 | 快照冻结成功并发起批次请求 → S4-1，立即开始累计 60 秒 | 不可达：同一提交标识禁止重复发起 | 不可达：恢复期间禁止重复发起 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 |	testDuplicateSubmissionIsRejected, testSecondStartWithSameSubmissionIdentifierIsRejected, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“提交发起” × 起始状态“S4-1 已提交”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-172	SPEC-S3-S4-20260812.v6.md	337	| 提交发起 | 快照冻结成功并发起批次请求 → S4-1，立即开始累计 60 秒 | 不可达：同一提交标识禁止重复发起 | 不可达：恢复期间禁止重复发起 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“提交发起” × 起始状态“S4-2 已恢复交互”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-173	SPEC-S3-S4-20260812.v6.md	337	| 提交发起 | 快照冻结成功并发起批次请求 → S4-1，立即开始累计 60 秒 | 不可达：同一提交标识禁止重复发起 | 不可达：恢复期间禁止重复发起 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“提交发起” × 起始状态“S4-E1 全批成功”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-174	SPEC-S3-S4-20260812.v6.md	337	| 提交发起 | 快照冻结成功并发起批次请求 → S4-1，立即开始累计 60 秒 | 不可达：同一提交标识禁止重复发起 | 不可达：恢复期间禁止重复发起 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“提交发起” × 起始状态“S4-E2 整批失败”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-175	SPEC-S3-S4-20260812.v6.md	337	| 提交发起 | 快照冻结成功并发起批次请求 → S4-1，立即开始累计 60 秒 | 不可达：同一提交标识禁止重复发起 | 不可达：恢复期间禁止重复发起 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 | 不可达：终态已经封闭提交 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“提交发起” × 起始状态“S4-E3 结果未知”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-176	SPEC-S3-S4-20260812.v6.md	338	| 应用进入非 active | 不可达：S4 尚未开始 | → S4-1；暂停并保存已累计的 active 时长 | → S4-2；暂停并保存已累计的 active 时长 | → S4-E1；终态已持久化，等待应用恢复 active 后交接 | → S4-E2；终态已持久化，等待应用恢复 active 后交接 | → S4-E3；终态已持久化，等待应用恢复 active 后交接 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“应用进入非 active” × 起始状态“S3-2 外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-177	SPEC-S3-S4-20260812.v6.md	338	| 应用进入非 active | 不可达：S4 尚未开始 | → S4-1；暂停并保存已累计的 active 时长 | → S4-2；暂停并保存已累计的 active 时长 | → S4-E1；终态已持久化，等待应用恢复 active 后交接 | → S4-E2；终态已持久化，等待应用恢复 active 后交接 | → S4-E3；终态已持久化，等待应用恢复 active 后交接 |	testReachable02InactiveFromSubmitted, testInactiveDurationDoesNotAccumulate	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S4-1 已提交”）：所列方法直接断言该单元格。
C34-178	SPEC-S3-S4-20260812.v6.md	338	| 应用进入非 active | 不可达：S4 尚未开始 | → S4-1；暂停并保存已累计的 active 时长 | → S4-2；暂停并保存已累计的 active 时长 | → S4-E1；终态已持久化，等待应用恢复 active 后交接 | → S4-E2；终态已持久化，等待应用恢复 active 后交接 | → S4-E3；终态已持久化，等待应用恢复 active 后交接 |	testReachable03InactiveFromResumedInteraction	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S4-2 已恢复交互”）：所列方法直接断言该单元格。
C34-179	SPEC-S3-S4-20260812.v6.md	338	| 应用进入非 active | 不可达：S4 尚未开始 | → S4-1；暂停并保存已累计的 active 时长 | → S4-2；暂停并保存已累计的 active 时长 | → S4-E1；终态已持久化，等待应用恢复 active 后交接 | → S4-E2；终态已持久化，等待应用恢复 active 后交接 | → S4-E3；终态已持久化，等待应用恢复 active 后交接 |	testReachable04InactiveFromSuccessTerminal, testReachable09ActiveFromSuccessTerminal	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S4-E1 全批成功”）：所列方法直接断言该单元格。
C34-180	SPEC-S3-S4-20260812.v6.md	338	| 应用进入非 active | 不可达：S4 尚未开始 | → S4-1；暂停并保存已累计的 active 时长 | → S4-2；暂停并保存已累计的 active 时长 | → S4-E1；终态已持久化，等待应用恢复 active 后交接 | → S4-E2；终态已持久化，等待应用恢复 active 后交接 | → S4-E3；终态已持久化，等待应用恢复 active 后交接 |	testReachable05InactiveFromFailureTerminal, testReachable10ActiveFromFailureTerminal	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S4-E2 整批失败”）：所列方法直接断言该单元格。
C34-181	SPEC-S3-S4-20260812.v6.md	338	| 应用进入非 active | 不可达：S4 尚未开始 | → S4-1；暂停并保存已累计的 active 时长 | → S4-2；暂停并保存已累计的 active 时长 | → S4-E1；终态已持久化，等待应用恢复 active 后交接 | → S4-E2；终态已持久化，等待应用恢复 active 后交接 | → S4-E3；终态已持久化，等待应用恢复 active 后交接 |	testReachable06InactiveFromUnknownTerminal, testReachable11ActiveFromUnknownTerminal	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S4-E3 结果未知”）：所列方法直接断言该单元格。
C34-182	SPEC-S3-S4-20260812.v6.md	339	| 应用恢复 active | 不可达：S4 尚未开始 | → S4-2；从剩余时长继续累计 | → S4-2；从剩余时长继续累计 | → S4-E1，随后交接 S5-T0 | → S4-E2，随后按 `失败原因.类别码` 分流：`用户取消` → S5-C；`权限不足` / `资产不可删除` / `未知` → S5-F | → S4-E3，随后交接 S5-U |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“应用恢复 active” × 起始状态“S3-2 外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-183	SPEC-S3-S4-20260812.v6.md	339	| 应用恢复 active | 不可达：S4 尚未开始 | → S4-2；从剩余时长继续累计 | → S4-2；从剩余时长继续累计 | → S4-E1，随后交接 S5-T0 | → S4-E2，随后按 `失败原因.类别码` 分流：`用户取消` → S5-C；`权限不足` / `资产不可删除` / `未知` → S5-F | → S4-E3，随后交接 S5-U |	testReachable07ActiveFromSubmitted	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S4-1 已提交”）：所列方法直接断言该单元格。
C34-184	SPEC-S3-S4-20260812.v6.md	339	| 应用恢复 active | 不可达：S4 尚未开始 | → S4-2；从剩余时长继续累计 | → S4-2；从剩余时长继续累计 | → S4-E1，随后交接 S5-T0 | → S4-E2，随后按 `失败原因.类别码` 分流：`用户取消` → S5-C；`权限不足` / `资产不可删除` / `未知` → S5-F | → S4-E3，随后交接 S5-U |	testReachable08ActiveFromResumedInteraction	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S4-2 已恢复交互”）：所列方法直接断言该单元格。
C34-185	SPEC-S3-S4-20260812.v6.md	339	| 应用恢复 active | 不可达：S4 尚未开始 | → S4-2；从剩余时长继续累计 | → S4-2；从剩余时长继续累计 | → S4-E1，随后交接 S5-T0 | → S4-E2，随后按 `失败原因.类别码` 分流：`用户取消` → S5-C；`权限不足` / `资产不可删除` / `未知` → S5-F | → S4-E3，随后交接 S5-U |	testReachable09ActiveFromSuccessTerminal	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S4-E1 全批成功”）：所列方法直接断言该单元格。
C34-186	SPEC-S3-S4-20260812.v6.md	339	| 应用恢复 active | 不可达：S4 尚未开始 | → S4-2；从剩余时长继续累计 | → S4-2；从剩余时长继续累计 | → S4-E1，随后交接 S5-T0 | → S4-E2，随后按 `失败原因.类别码` 分流：`用户取消` → S5-C；`权限不足` / `资产不可删除` / `未知` → S5-F | → S4-E3，随后交接 S5-U |	testReachable10ActiveFromFailureTerminal, testUserCancellationWritesCancelledTargetBeforeHandoff, testOtherFailureCategoriesWriteFailureTarget, testC34_186RestoredCancellationTerminalUsesPersistedTargetOnActive	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S4-E2 整批失败”）：所列专项方法直接断言该条款。
C34-187	SPEC-S3-S4-20260812.v6.md	339	| 应用恢复 active | 不可达：S4 尚未开始 | → S4-2；从剩余时长继续累计 | → S4-2；从剩余时长继续累计 | → S4-E1，随后交接 S5-T0 | → S4-E2，随后按 `失败原因.类别码` 分流：`用户取消` → S5-C；`权限不足` / `资产不可删除` / `未知` → S5-F | → S4-E3，随后交接 S5-U |	testReachable11ActiveFromUnknownTerminal	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S4-E3 结果未知”）：所列方法直接断言该单元格。
C34-188	SPEC-S3-S4-20260812.v6.md	340	| 收到成功回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E1，并取消计时 | → S4-E1，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到成功回调” × 起始状态“S3-2 外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-189	SPEC-S3-S4-20260812.v6.md	340	| 收到成功回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E1，并取消计时 | → S4-E1，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testReachable12SuccessCallbackFromSubmitted	已覆盖	可达单元格（事件“收到成功回调” × 起始状态“S4-1 已提交”）：所列方法直接断言该单元格。
C34-190	SPEC-S3-S4-20260812.v6.md	340	| 收到成功回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E1，并取消计时 | → S4-E1，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testReachable13SuccessCallbackFromResumedInteraction	已覆盖	可达单元格（事件“收到成功回调” × 起始状态“S4-2 已恢复交互”）：所列方法直接断言该单元格。
C34-191	SPEC-S3-S4-20260812.v6.md	340	| 收到成功回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E1，并取消计时 | → S4-E1，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到成功回调” × 起始状态“S4-E1 全批成功”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-192	SPEC-S3-S4-20260812.v6.md	340	| 收到成功回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E1，并取消计时 | → S4-E1，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testLateSuccessCannotOverwriteFailure, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到成功回调” × 起始状态“S4-E2 整批失败”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-193	SPEC-S3-S4-20260812.v6.md	340	| 收到成功回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E1，并取消计时 | → S4-E1，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testLateCallbackCannotOverwriteUnknown, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到成功回调” × 起始状态“S4-E3 结果未知”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-194	SPEC-S3-S4-20260812.v6.md	341	| 收到失败回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E2，并取消计时 | → S4-E2，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，重复回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到失败回调” × 起始状态“S3-2 外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-195	SPEC-S3-S4-20260812.v6.md	341	| 收到失败回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E2，并取消计时 | → S4-E2，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，重复回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testReachable14FailureCallbackFromSubmitted	已覆盖	可达单元格（事件“收到失败回调” × 起始状态“S4-1 已提交”）：所列方法直接断言该单元格。
C34-196	SPEC-S3-S4-20260812.v6.md	341	| 收到失败回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E2，并取消计时 | → S4-E2，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，重复回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testReachable15FailureCallbackFromResumedInteraction	已覆盖	可达单元格（事件“收到失败回调” × 起始状态“S4-2 已恢复交互”）：所列方法直接断言该单元格。
C34-197	SPEC-S3-S4-20260812.v6.md	341	| 收到失败回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E2，并取消计时 | → S4-E2，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，重复回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testLateFailureCannotOverwriteSuccess, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到失败回调” × 起始状态“S4-E1 全批成功”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-198	SPEC-S3-S4-20260812.v6.md	341	| 收到失败回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E2，并取消计时 | → S4-E2，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，重复回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到失败回调” × 起始状态“S4-E2 整批失败”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-199	SPEC-S3-S4-20260812.v6.md	341	| 收到失败回调 | 不可达：S4 尚未开始且没有本次提交 | → S4-E2，并取消计时 | → S4-E2，并取消计时 | 不可达：首个终态已经持久化，迟到回调不得改写 | 不可达：首个终态已经持久化，重复回调不得改写 | 不可达：首个终态已经持久化，迟到回调不得改写 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“收到失败回调” × 起始状态“S4-E3 结果未知”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-200	SPEC-S3-S4-20260812.v6.md	342	| 超时触发 | 不可达：S4 尚未开始 | active 累计达到 60 秒且无有效回调 → S4-E3 | active 累计达到 60 秒且无有效回调 → S4-E3 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“超时触发” × 起始状态“S3-2 外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-201	SPEC-S3-S4-20260812.v6.md	342	| 超时触发 | 不可达：S4 尚未开始 | active 累计达到 60 秒且无有效回调 → S4-E3 | active 累计达到 60 秒且无有效回调 → S4-E3 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 |	testReachable16TimeoutFromSubmitted, testElapsedTimeBelowLimitKeepsPendingState	已覆盖	可达单元格（事件“超时触发” × 起始状态“S4-1 已提交”）：所列方法直接断言该单元格。
C34-202	SPEC-S3-S4-20260812.v6.md	342	| 超时触发 | 不可达：S4 尚未开始 | active 累计达到 60 秒且无有效回调 → S4-E3 | active 累计达到 60 秒且无有效回调 → S4-E3 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 |	testReachable17TimeoutFromResumedInteraction	已覆盖	可达单元格（事件“超时触发” × 起始状态“S4-2 已恢复交互”）：所列方法直接断言该单元格。
C34-203	SPEC-S3-S4-20260812.v6.md	342	| 超时触发 | 不可达：S4 尚未开始 | active 累计达到 60 秒且无有效回调 → S4-E3 | active 累计达到 60 秒且无有效回调 → S4-E3 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“超时触发” × 起始状态“S4-E1 全批成功”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-204	SPEC-S3-S4-20260812.v6.md	342	| 超时触发 | 不可达：S4 尚未开始 | active 累计达到 60 秒且无有效回调 → S4-E3 | active 累计达到 60 秒且无有效回调 → S4-E3 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“超时触发” × 起始状态“S4-E2 整批失败”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-205	SPEC-S3-S4-20260812.v6.md	342	| 超时触发 | 不可达：S4 尚未开始 | active 累计达到 60 秒且无有效回调 → S4-E3 | active 累计达到 60 秒且无有效回调 → S4-E3 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 | 不可达：终态已形成且计时器已取消 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“超时触发” × 起始状态“S4-E3 结果未知”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-206	SPEC-S3-S4-20260812.v6.md	343	| 应用在此期间被系统终止 | 不可达：S4 尚未开始 | 若尚无持久化终态，下次启动 → S4-E3 | 若尚无持久化终态，下次启动 → S4-E3 | → S4-E1；持久化终态不丢失，下次启动继续交接 | → S4-E2；持久化终态不丢失，下次启动继续交接 | → S4-E3；持久化终态不丢失，下次启动继续交接 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“应用在此期间被系统终止” × 起始状态“S3-2 外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C34-207	SPEC-S3-S4-20260812.v6.md	343	| 应用在此期间被系统终止 | 不可达：S4 尚未开始 | 若尚无持久化终态，下次启动 → S4-E3 | 若尚无持久化终态，下次启动 → S4-E3 | → S4-E1；持久化终态不丢失，下次启动继续交接 | → S4-E2；持久化终态不丢失，下次启动继续交接 | → S4-E3；持久化终态不丢失，下次启动继续交接 |	testReachable18TerminationFromSubmitted, testRestoreConvertsSubmittedStateToUnknown	已覆盖	可达单元格（事件“应用在此期间被系统终止” × 起始状态“S4-1 已提交”）：所列方法直接断言该单元格。
C34-208	SPEC-S3-S4-20260812.v6.md	343	| 应用在此期间被系统终止 | 不可达：S4 尚未开始 | 若尚无持久化终态，下次启动 → S4-E3 | 若尚无持久化终态，下次启动 → S4-E3 | → S4-E1；持久化终态不丢失，下次启动继续交接 | → S4-E2；持久化终态不丢失，下次启动继续交接 | → S4-E3；持久化终态不丢失，下次启动继续交接 |	testReachable19TerminationFromResumedInteraction, testRestoreConvertsResumedStateToUnknown	已覆盖	可达单元格（事件“应用在此期间被系统终止” × 起始状态“S4-2 已恢复交互”）：所列方法直接断言该单元格。
C34-209	SPEC-S3-S4-20260812.v6.md	343	| 应用在此期间被系统终止 | 不可达：S4 尚未开始 | 若尚无持久化终态，下次启动 → S4-E3 | 若尚无持久化终态，下次启动 → S4-E3 | → S4-E1；持久化终态不丢失，下次启动继续交接 | → S4-E2；持久化终态不丢失，下次启动继续交接 | → S4-E3；持久化终态不丢失，下次启动继续交接 |	testReachable20TerminationFromSuccessTerminal, testC34_209SuccessTerminalContinuesHandoffAfterTerminationAndRestart	已覆盖	可达单元格（事件“应用在此期间被系统终止” × 起始状态“S4-E1 全批成功”）：所列专项方法直接断言该条款。
C34-210	SPEC-S3-S4-20260812.v6.md	343	| 应用在此期间被系统终止 | 不可达：S4 尚未开始 | 若尚无持久化终态，下次启动 → S4-E3 | 若尚无持久化终态，下次启动 → S4-E3 | → S4-E1；持久化终态不丢失，下次启动继续交接 | → S4-E2；持久化终态不丢失，下次启动继续交接 | → S4-E3；持久化终态不丢失，下次启动继续交接 |	testReachable21TerminationFromFailureTerminal, testC34_210FailureTerminalContinuesHandoffAfterTerminationAndRestart	已覆盖	可达单元格（事件“应用在此期间被系统终止” × 起始状态“S4-E2 整批失败”）：所列专项方法直接断言该条款。
C34-211	SPEC-S3-S4-20260812.v6.md	343	| 应用在此期间被系统终止 | 不可达：S4 尚未开始 | 若尚无持久化终态，下次启动 → S4-E3 | 若尚无持久化终态，下次启动 → S4-E3 | → S4-E1；持久化终态不丢失，下次启动继续交接 | → S4-E2；持久化终态不丢失，下次启动继续交接 | → S4-E3；持久化终态不丢失，下次启动继续交接 |	testReachable22TerminationFromUnknownTerminal, testC34_211UnknownTerminalContinuesHandoffAfterTerminationAndRestart	已覆盖	可达单元格（事件“应用在此期间被系统终止” × 起始状态“S4-E3 结果未知”）：所列专项方法直接断言该条款。
C34-212	SPEC-S3-S4-20260812.v6.md	359	| `提交标识` | 字符串；必须匹配提交集合快照 | 关联唯一一次批次提交 |	testMismatchedSuccessCallbackIsRejected, testMismatchedFailureCallbackIsRejected	已覆盖	所列方法直接断言该条款。
C34-213	SPEC-S3-S4-20260812.v6.md	360	| `成功集合` | 唯一字符串集合 | 回调已明确确认成功的资产标识 |	testDisjointCompleteClassificationIsAccepted, testSuccessResultClassifiesEverySubmittedAssetAsSuccessful	已覆盖	所列方法直接断言该条款。
C34-214	SPEC-S3-S4-20260812.v6.md	361	| `失败集合` | 唯一字符串集合 | 回调已明确确认失败的资产标识 |	testDisjointCompleteClassificationIsAccepted, testBatchLevelFailureUsesWholeSubmittedSetAsFailure	已覆盖	所列方法直接断言该条款。
C34-215	SPEC-S3-S4-20260812.v6.md	362	| `未处理集合` | 唯一字符串集合 | 批次未被系统接受或尚未进入处理的资产标识 |	testDisjointCompleteClassificationIsAccepted, testFailureBeforeSystemAcceptanceUsesWholeSubmittedSetAsUnprocessed	已覆盖	所列方法直接断言该条款。
C34-216	SPEC-S3-S4-20260812.v6.md	363	| `失败原因.类别码` | 枚举：`权限不足` / `资产不可删除` / `用户取消` / `未知` | 稳定的失败分类标识 |	testDownstreamTargetStateValueDomainIsComplete, testUserCancellationWritesCancelledTargetBeforeHandoff, testOtherFailureCategoriesWriteFailureTarget, testS4UserCancellationClassifierRequiresExactDomainAndCode	已覆盖	所列方法直接断言该条款。
C34-217	SPEC-S3-S4-20260812.v6.md	364	| `失败原因.说明` | 非空字符串 | 可供界面呈现或日志记录的原因说明 |	testEmptyFailureReasonIsRejected	已覆盖	所列方法直接断言该条款。
C34-218	SPEC-S3-S4-20260812.v6.md	365	| `失败原因.系统域` | 可空字符串 | 底层错误存在错误域时保留原值，不做映射 |	testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed, testPhotoKitBatchFailureClassifiesWholeSetAsFailed	已覆盖	所列方法直接断言该条款。
C34-219	SPEC-S3-S4-20260812.v6.md	366	| `失败原因.系统码` | 可空整数 | 底层错误存在错误码时保留原值，不做映射 |	testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed, testPhotoKitBatchFailureClassifiesWholeSetAsFailed	已覆盖	所列方法直接断言该条款。
C34-220	SPEC-S3-S4-20260812.v6.md	367	| `回调接收时间` | 带时区的时间戳 | 应用接收本次失败回调的时间 |	testDisjointCompleteClassificationIsAccepted, testReachable14FailureCallbackFromSubmitted	已覆盖	所列方法直接断言该条款。
C34-221	SPEC-S3-S4-20260812.v6.md	369	判定规则：`失败原因.系统域` 为 `PHPhotosErrorDomain` 且 `失败原因.系统码` 为 `3072` 时，`失败原因.类别码` 判定为 `用户取消`。	testS4UserCancellationClassifierRequiresExactDomainAndCode	已覆盖	所列方法直接断言该条款。
C34-222	SPEC-S3-S4-20260812.v6.md	373	- 成功集合、失败集合与未处理集合两两不相交。	testSuccessAndFailureOverlapIsRejected, testSuccessAndUnprocessedOverlapIsRejected, testFailureAndUnprocessedOverlapIsRejected	已覆盖	所列方法直接断言该条款。
C34-223	SPEC-S3-S4-20260812.v6.md	374	- 三个集合的并集必须严格等于提交集合快照中的资产标识集合。	testForeignAssetIsRejected, testOmittedAssetIsRejected, testDisjointCompleteClassificationIsAccepted	已覆盖	所列方法直接断言该条款。
C34-224	SPEC-S3-S4-20260812.v6.md	375	- 三个集合均不得包含快照外资产，也不得静默漏项。	testForeignAssetIsRejected, testOmittedAssetIsRejected	已覆盖	所列方法直接断言该条款。
C34-225	SPEC-S3-S4-20260812.v6.md	376	- 系统只给出批次级失败且明确表示整批未成功时，不虚构单项差异：失败集合取完整提交集合，成功集合与未处理集合为空。	testBatchLevelFailureUsesWholeSubmittedSetAsFailure	已覆盖	所列方法直接断言该条款。
C34-226	SPEC-S3-S4-20260812.v6.md	377	- 请求在系统接受批次前失败时，未处理集合取完整提交集合，成功集合与失败集合为空。	testFailureBeforeSystemAcceptanceUsesWholeSubmittedSetAsUnprocessed	已覆盖	所列方法直接断言该条款。
C34-227	SPEC-S3-S4-20260812.v6.md	378	- 失败原因必须非空；不能只用空集合或界面无变化表达失败。	testEmptyFailureReasonIsRejected	已覆盖	所列方法直接断言该条款。
C34-228	SPEC-S3-S4-20260812.v6.md	379	- `失败原因.类别码` 是不完整枚举；未覆盖情形一律归入 `未知`。	testS4UserCancellationClassifierRequiresExactDomainAndCode, testPhotoKitBatchFailureClassifiesWholeSetAsFailed	已覆盖	所列方法直接断言该条款。
C34-229	SPEC-S3-S4-20260812.v6.md	380	- `失败原因.系统域` 与 `失败原因.系统码` 保留底层原值，不做映射。	testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed, testPhotoKitBatchFailureClassifiesWholeSetAsFailed	已覆盖	所列方法直接断言该条款。
C34-230	SPEC-S3-S4-20260812.v6.md	381	- 回调结构只记录批次最终分类，不要求系统提供按单项连续通知的能力。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-001	SPEC-S5-20260812.v5.md	16	S5 仅有以下四个状态：	testCell01SuccessEntry, testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory, testCell02FailureEntry, testCell03UnknownEntry	已覆盖	所列方法直接断言该条款。
C5-002	SPEC-S5-20260812.v5.md	18	1. `S5-T0` 已移入最近删除。	testCell01SuccessEntry	已覆盖	所列方法直接断言该条款。
C5-003	SPEC-S5-20260812.v5.md	19	2. `S5-C` 已取消删除。	testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory	已覆盖	所列方法直接断言该条款。
C5-004	SPEC-S5-20260812.v5.md	20	3. `S5-F` 整批失败。	testCell02FailureEntry	已覆盖	所列方法直接断言该条款。
C5-005	SPEC-S5-20260812.v5.md	21	4. `S5-U` 结果未知。	testCell03UnknownEntry	已覆盖	所列方法直接断言该条款。
C5-006	SPEC-S5-20260812.v5.md	23	定义外部出口 `S5-EXIT` 为“应用的清理入口页”。它不是 S5 状态，本文不定义其内部行为。用户从 `S5-T0` 或 `S5-U` 离开本页时，结束本次清理会话并迁至 `S5-EXIT`。该出口不自动发起新提交，也不自动开始新扫描。`S5-C` 与 `S5-F` 只提供“返回确认页”，其跨页目标见第七节。	testCell04LeaveFromSuccess, testCell06LeaveFromUnknown, testCancellationCannotLeaveThroughCompletionAction, testFailurePageCannotLeaveThroughCompletionAction, testCancellationReturnWithCacheCarriesOriginalSubmission, testCell05AReturnFromFailureWithCache, testC5_006SuccessAndUnknownExitDoNotSubmitOrStartScanning	不适用	MVE 范围外
C5-007	SPEC-S5-20260812.v5.md	25	设 S3 冻结快照中的资产标识集合为 `P`，资产数量为 `N`。删除回调中的成功集合、失败集合与未处理集合分别记为 `A`、`B`、`C`。共同不变量如下：	testCell01SuccessEntry, testDisjointCompleteClassificationIsAccepted	已覆盖	所列方法直接断言该条款。
C5-008	SPEC-S5-20260812.v5.md	27	- `A`、`B`、`C` 两两不相交，且 `A ∪ B ∪ C = P`。	testSuccessAndFailureOverlapIsRejected, testSuccessAndUnprocessedOverlapIsRejected, testFailureAndUnprocessedOverlapIsRejected, testOmittedAssetIsRejected, testFailureEntryRejectsInvalidClassification	已覆盖	所列方法直接断言该条款。
C5-009	SPEC-S5-20260812.v5.md	28	- 三个集合都不得包含 `P` 之外的资产，不得静默漏项。	testForeignAssetIsRejected, testOmittedAssetIsRejected	已覆盖	所列方法直接断言该条款。
C5-010	SPEC-S5-20260812.v5.md	29	- 从 `S4-E1` 进入时，`A = P`，`B` 与 `C` 为空。	testCell01SuccessEntry, testSuccessResultClassifiesEverySubmittedAssetAsSuccessful	已覆盖	所列方法直接断言该条款。
C5-011	SPEC-S5-20260812.v5.md	30	- 从 `S4-E2` 进入时，直接使用已持久化回调中的三个集合与失败原因，不推测或改写任一资产的结论。	testFailureEntryReusesPersistedClassificationWithoutModification, testCell02FailureEntry	已覆盖	所列方法直接断言该条款。
C5-012	SPEC-S5-20260812.v5.md	31	- S5 按 S4 传入的 `下游目标状态` 直接落位，不得二次判定；落位 `S5-C` 时沿用 S4 交接的现行分类 `A = ∅`、`B = ∅`、`C = P`，只改变呈现，不改变集合分类。	testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory, testFailureEntryUsesDownstreamTargetWithoutReadingFailureCategory, testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed	已覆盖	所列方法直接断言该条款。
C5-013	SPEC-S5-20260812.v5.md	32	- 从 `S4-E3` 进入时没有可用的删除回调集合；不得用 `P` 推导 `A`、`B` 或 `C`。	testUnknownEntryDoesNotConstructClassificationSets, testCell03UnknownEntry	已覆盖	所列方法直接断言该条款。
C5-014	SPEC-S5-20260812.v5.md	33	- 收到 S4 交接数据后，S5 必须先持久化当前状态及其输入，再呈现页面。	testCell01SuccessEntry, testEntryPersistenceFailurePreventsListInvalidation	已覆盖	所列方法直接断言该条款。
C5-015	SPEC-S5-20260812.v5.md	34	- S5 不修改 S3 冻结快照，不在本页增加、移除或替换 `P` 中的资产。	testCancellationReturnWithCacheCarriesOriginalSubmission, testCancellationReturnWithoutCacheCarriesOriginalSubmission, testCell05AReturnFromFailureWithCache, testCell05BReturnFromFailureWithoutCache	已覆盖	所列方法直接断言该条款。
C5-016	SPEC-S5-20260812.v5.md	35	- 进入 `S5-T0` 时，应用内所有仍引用 `A` 的旧照片列表必须失效；后续重新进入照片列表时从照片库重新取得数据，不得用旧内存列表把这些资产重新显示在原位置。	testCell01SuccessEntry	不适用	MVE 范围外
C5-017	SPEC-S5-20260812.v5.md	36	- S5 不读取也不清空系统「最近删除」。该边界只通过文字、截图与人工回归说明。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-018	SPEC-S5-20260812.v5.md	146	- 状态标题“已移入最近删除”。		不适用	该条款为纯文案
C5-019	SPEC-S5-20260812.v5.md	147	- L1：“处理结果：成功 N 张，失败 0 张，未处理 0 张”。	testCell01SuccessEntry	未覆盖	方法断言成功集合等于原提交集合，未断言页面 L1 文案和三个计数的呈现。
C5-020	SPEC-S5-20260812.v5.md	148	- 按第二节规则显示 L2。	testCell01SuccessEntry, testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime	未覆盖	方法证明快照随成功上下文持久化，未断言页面按第二节显示 L2。
C5-021	SPEC-S5-20260812.v5.md	149	- 第三节规定的边界文字与标注截图。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-022	SPEC-S5-20260812.v5.md	150	- 用户点击前显示“设备可用空间仍在等待你的系统操作”的说明，不显示 L3 数值。	testL3DisplayRemainsBlockedForEveryState	未覆盖	方法断言用户点击前不显示 L3，但未断言等待系统操作说明的页面文案。
C5-023	SPEC-S5-20260812.v5.md	151	- 首次进入时取得一次 `L3基线读数`；只显示其取得状态，不显示读数本身。	testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt	未覆盖	方法断言首次进入只读取并持久化一次基线，未断言页面只显示取得状态且隐藏读数本身。
C5-024	SPEC-S5-20260812.v5.md	152	- 用户点击后按第二节与第五节规则显示 L3 数值或不含数字的说明。	testL3DisplayRemainsBlockedForEveryState	不适用	该条款为未定项阻断
C5-025	SPEC-S5-20260812.v5.md	153	- 用户点击前显示主操作“我已清空最近删除”；完成该操作后隐藏。	testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation, testRepeatedConfirmationDoesNotReadAgain	已覆盖	所列方法直接断言该条款。
C5-026	SPEC-S5-20260812.v5.md	154	- “离开”操作。	testCell04LeaveFromSuccess	未覆盖	方法断言离开事件可用，未断言页面显示离开操作。
C5-027	SPEC-S5-20260812.v5.md	158	- 浏览结果、边界文字与标注截图。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-028	SPEC-S5-20260812.v5.md	159	- 点击“我已清空最近删除”；该操作读取一次 `L3完成读数`、形成展示结论并留在 `S5-T0`。	testConfirmationReadsCompletionExactlyOnceAndPersistsDelta, testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation, testUnavailableReadingsArePersistedWithoutDeltaOrRetry	未覆盖	方法断言单次读取、状态留存与按钮状态，但未直接断言形成页面展示结论。
C5-029	SPEC-S5-20260812.v5.md	160	- 点击“离开”。	testCell04LeaveFromSuccess	已覆盖	所列方法直接断言该条款。
C5-030	SPEC-S5-20260812.v5.md	164	- 重复点击“我已清空最近删除”。	testRepeatedConfirmationDoesNotReadAgain	已覆盖	所列方法直接断言该条款。
C5-031	SPEC-S5-20260812.v5.md	165	- 定时或重复读取 `freeDiskStrictGB`。	testRepeatedConfirmationDoesNotReadAgain, testLifecycleEventsDoNotReadFreeDiskAgain, testUnavailableReadingsArePersistedWithoutDeltaOrRetry, testC5_031RepeatedLifecycleTicksNeverPollFreeDisk	已覆盖	所列专项方法直接断言该条款。
C5-032	SPEC-S5-20260812.v5.md	166	- 用户点击前显示 L3、0 或估算值。	testL3DisplayRemainsBlockedForEveryState	已覆盖	所列方法直接断言该条款。
C5-033	SPEC-S5-20260812.v5.md	167	- 由应用打开、读取或清空系统「最近删除」。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-034	SPEC-S5-20260812.v5.md	168	- 再次提交、修改提交集合，或通过“离开”以外的方式结束本次结果页。	testSuccessPageCannotReturnToConfirmation, testC5_034SuccessOnlyLeavesThroughExitAndCannotModifySubmission	已覆盖	所列专项方法直接断言该条款。
C5-035	SPEC-S5-20260812.v5.md	172	- 用户点击“我已清空最近删除”：持久化用户声明时间，读取一次 `L3完成读数`，计算并持久化展示结论；留在 `S5-T0`。	testConfirmationReadsCompletionExactlyOnceAndPersistsDelta, testUnavailableReadingsArePersistedWithoutDeltaOrRetry, testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime	未覆盖	方法断言声明时间、完成读数和差值持久化并留在原状态，但未直接断言形成页面展示结论。
C5-036	SPEC-S5-20260812.v5.md	173	- 用户点击“离开”：结束本次清理会话并迁至 `S5-EXIT`。	testCell04LeaveFromSuccess	已覆盖	所列方法直接断言该条款。
C5-037	SPEC-S5-20260812.v5.md	174	- 应用进入非 active：留在 `S5-T0`，不新增磁盘读取。	testCell07InactiveFromSuccess, testLifecycleEventsDoNotReadFreeDiskAgain	已覆盖	所列方法直接断言该条款。
C5-038	SPEC-S5-20260812.v5.md	175	- 应用恢复 active：留在 `S5-T0`，不新增磁盘读取。	testCell10ActiveFromSuccess, testLifecycleEventsDoNotReadFreeDiskAgain	已覆盖	所列方法直接断言该条款。
C5-039	SPEC-S5-20260812.v5.md	176	- 应用被系统终止：持久化状态、两次读取的完成情况、已有读数、`Y` 与展示结论；下次启动恢复 `S5-T0`，不新增磁盘读取。	testCell13TerminationFromSuccess, testLifecycleEventsDoNotReadFreeDiskAgain, testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime, testRestoreKeepsPersistedSuccessState, testC5_039CompletedReadingsSurviveTerminationAndRestoreWithoutNewRead	已覆盖	所列专项方法直接断言该条款。
C5-040	SPEC-S5-20260812.v5.md	182	- 状态标题“已取消删除”。		不适用	该条款为纯文案
C5-041	SPEC-S5-20260812.v5.md	183	- 说明“照片都还在”。		不适用	该条款为纯文案
C5-042	SPEC-S5-20260812.v5.md	184	- L1：“本次提交 N 张，全部未处理”，对应 `A = ∅`、`B = ∅`、`C = P`。	testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory, testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed	未覆盖	方法断言取消分类为 A、B 空且 C 等于 P，未断言页面 L1 文案呈现。
C5-043	SPEC-S5-20260812.v5.md	185	- 按第二节规则显示 L2，并显示其只描述原提交集合的旁注。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-044	SPEC-S5-20260812.v5.md	186	- 主操作“返回确认页”。	testCancellationReturnWithCacheCarriesOriginalSubmission, testCancellationReturnWithoutCacheCarriesOriginalSubmission	未覆盖	方法断言返回确认页事件可用，未断言页面显示主操作。
C5-045	SPEC-S5-20260812.v5.md	187	- 不显示底层错误域或错误码。	testCancellationDoesNotShowSystemErrorDomainOrCode	已覆盖	所列方法直接断言该条款。
C5-046	SPEC-S5-20260812.v5.md	188	- 不显示 L3。	testCancellationDoesNotShowL3	已覆盖	所列方法直接断言该条款。
C5-047	SPEC-S5-20260812.v5.md	192	- 浏览取消结果与原提交集合的数量、体积说明。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-048	SPEC-S5-20260812.v5.md	193	- 点击“返回确认页”。	testCancellationReturnWithCacheCarriesOriginalSubmission, testCancellationReturnWithoutCacheCarriesOriginalSubmission	已覆盖	所列方法直接断言该条款。
C5-049	SPEC-S5-20260812.v5.md	197	- 在 S5 内再次提交全部或部分资产。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-050	SPEC-S5-20260812.v5.md	198	- 修改 `A`、`B`、`C`，或把未处理项目计入其他集合。	testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory, testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed	已覆盖	所列方法直接断言该条款。
C5-051	SPEC-S5-20260812.v5.md	199	- 读取 `freeDiskStrictGB` 或显示 L3。	testCancellationDoesNotReadFreeDiskStrictGB, testCancellationDoesNotShowL3	已覆盖	所列方法直接断言该条款。
C5-052	SPEC-S5-20260812.v5.md	200	- 显示“我已清空最近删除”或结束本次结果页。	testCancellationDoesNotShowRecentlyDeletedConfirmationAction, testCancellationCannotLeaveThroughCompletionAction	已覆盖	所列方法直接断言该条款。
C5-053	SPEC-S5-20260812.v5.md	201	- 不得在用户可见文案中使用“失败”“未完成”等措辞。	testCancellationVisibleCopyAvoidsFailureAndIncompleteWording	已覆盖	所列方法直接断言该条款。
C5-054	SPEC-S5-20260812.v5.md	205	- 用户点击“返回确认页”，且本会话的资产级结论缓存仍存在：携带原提交集合 `P` 迁至 `S3-2`。资产级结论缓存不绑定集合，返回后直接复用，不重扫。	testCancellationReturnWithCacheCarriesOriginalSubmission	已覆盖	所列方法直接断言该条款。
C5-055	SPEC-S5-20260812.v5.md	206	- 用户点击“返回确认页”，但缓存已因会话结束而清空：携带原提交集合 `P` 迁至 `S3-1`，按 S3 扫描规则重新取得结论。	testCancellationReturnWithoutCacheCarriesOriginalSubmission	已覆盖	所列方法直接断言该条款。
C5-056	SPEC-S5-20260812.v5.md	207	- 应用进入非 active 或恢复 active：留在 `S5-C`。	testCancellationLifecycleAndTerminationKeepState	已覆盖	所列方法直接断言该条款。
C5-057	SPEC-S5-20260812.v5.md	208	- 应用被系统终止：持久化取消结果、`P` 与三集合；下次启动恢复 `S5-C`。	testCancellationLifecycleAndTerminationKeepState, testRestoreKeepsPersistedCancellationStateWithoutDiskRead	已覆盖	所列方法直接断言该条款。
C5-058	SPEC-S5-20260812.v5.md	214	- 状态标题“本次删除未完成”。		不适用	该条款为纯文案
C5-059	SPEC-S5-20260812.v5.md	215	- L1：“处理结果：成功 A 张，失败 B 张，未处理 C 张”。	testFailureEntryReusesPersistedClassificationWithoutModification	未覆盖	方法断言三个集合原样进入失败上下文，未断言页面 L1 文案与计数呈现。
C5-060	SPEC-S5-20260812.v5.md	216	- 非空失败原因；存在底层错误域或错误码时可在详情中显示原值。	testEmptyFailureReasonIsRejected, testCell02FailureEntry	未覆盖	方法断言失败原因非空且保留底层字段，未断言页面详情呈现。
C5-061	SPEC-S5-20260812.v5.md	217	- 按第二节规则显示 L2，并显示其只描述原提交集合的旁注。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-062	SPEC-S5-20260812.v5.md	218	- “已保留原提交集合，可返回确认页再次尝试”的说明。		不适用	该条款为纯文案
C5-063	SPEC-S5-20260812.v5.md	219	- 主操作“返回确认页”。	testCell05AReturnFromFailureWithCache, testCell05BReturnFromFailureWithoutCache	未覆盖	方法断言返回确认页事件可用，未断言页面显示主操作。
C5-064	SPEC-S5-20260812.v5.md	220	- 不显示 L3。	testL3DisplayRemainsBlockedForEveryState	已覆盖	所列方法直接断言该条款。
C5-065	SPEC-S5-20260812.v5.md	224	- 浏览三个集合的数量与失败原因。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-066	SPEC-S5-20260812.v5.md	225	- 点击“返回确认页”。	testCell05AReturnFromFailureWithCache, testCell05BReturnFromFailureWithoutCache	已覆盖	所列方法直接断言该条款。
C5-067	SPEC-S5-20260812.v5.md	229	- 在 S5 内再次提交全部或部分资产。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-068	SPEC-S5-20260812.v5.md	230	- 修改 `A`、`B`、`C`，或把失败、未处理项目计入成功。	testFailureEntryReusesPersistedClassificationWithoutModification	已覆盖	所列方法直接断言该条款。
C5-069	SPEC-S5-20260812.v5.md	231	- 读取 `freeDiskStrictGB` 或显示 L3。	testL3DisplayRemainsBlockedForEveryState, testC5_069FailureNeverReadsFreeDiskOrDisplaysL3	已覆盖	所列专项方法直接断言该条款。
C5-070	SPEC-S5-20260812.v5.md	232	- 显示“我已清空最近删除”或结束本次结果页。	testFailurePageCannotLeaveThroughCompletionAction, testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation	已覆盖	所列方法直接断言该条款。
C5-071	SPEC-S5-20260812.v5.md	236	- 用户点击“返回确认页”，且本会话的资产级结论缓存仍存在：携带原提交集合 `P` 迁至 `S3-2`。资产级结论缓存不绑定集合，返回后直接复用，不重扫。	testCell05AReturnFromFailureWithCache	已覆盖	所列方法直接断言该条款。
C5-072	SPEC-S5-20260812.v5.md	237	- 用户点击“返回确认页”，但缓存已因会话结束而清空：携带原提交集合 `P` 迁至 `S3-1`，按 S3 扫描规则重新取得结论。	testCell05BReturnFromFailureWithoutCache	已覆盖	所列方法直接断言该条款。
C5-073	SPEC-S5-20260812.v5.md	238	- 应用进入非 active 或恢复 active：留在 `S5-F`。	testCell08InactiveFromFailure, testCell11ActiveFromFailure	已覆盖	所列方法直接断言该条款。
C5-074	SPEC-S5-20260812.v5.md	239	- 应用被系统终止：持久化失败结果、失败原因与 `P`；下次启动恢复 `S5-F`。	testCell14TerminationFromFailure, testRestoreKeepsPersistedFailureState	已覆盖	所列方法直接断言该条款。
C5-075	SPEC-S5-20260812.v5.md	245	- 状态标题“本次删除结果未知”。		不适用	该条款为纯文案
C5-076	SPEC-S5-20260812.v5.md	246	- 本次提交数量 `N`。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-077	SPEC-S5-20260812.v5.md	247	- 触发原因：active 累计等待超时，或 S4 尚未形成持久化终态时应用被系统终止。	testCell03UnknownEntry, testReachable16TimeoutFromSubmitted, testReachable18TerminationFromSubmitted	未覆盖	方法断言未知原因模型，未断言页面显示触发原因。
C5-078	SPEC-S5-20260812.v5.md	248	- L1 显示“处理结果未知”，不显示三个集合的数值。	testUnknownEntryDoesNotConstructClassificationSets	未覆盖	方法断言未知状态不构造三个集合，未断言页面 L1 文案与数值隐藏。
C5-079	SPEC-S5-20260812.v5.md	249	- 按第二节规则显示 L2，并显示其只描述原提交集合的旁注。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-080	SPEC-S5-20260812.v5.md	250	- 第三节规定的边界文字与标注截图，用于人工核对原位置与系统「最近删除」。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-081	SPEC-S5-20260812.v5.md	251	- “完成”操作。		不适用	该条款为纯文案
C5-082	SPEC-S5-20260812.v5.md	252	- 不显示 L3。	testL3DisplayRemainsBlockedForEveryState	已覆盖	所列方法直接断言该条款。
C5-083	SPEC-S5-20260812.v5.md	256	- 浏览提交上下文、未知原因与人工核对引导。		未覆盖	未发现直接断言该条款的 XCTest 方法。
C5-084	SPEC-S5-20260812.v5.md	257	- 点击“完成”或使用页面提供的离开操作。	testCell06LeaveFromUnknown	已覆盖	所列方法直接断言该条款。
C5-085	SPEC-S5-20260812.v5.md	261	- 推断或显示任一资产成功、失败或未处理。	testUnknownEntryDoesNotConstructClassificationSets	已覆盖	所列方法直接断言该条款。
C5-086	SPEC-S5-20260812.v5.md	262	- 读取 `freeDiskStrictGB`，显示“我已清空最近删除”，或把人工核对结果写回为删除回调。	testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation, testL3DisplayRemainsBlockedForEveryState, testC5_086UnknownCannotReadConfirmOrWriteBackManualResult	已覆盖	所列专项方法直接断言该条款。
C5-087	SPEC-S5-20260812.v5.md	263	- 在 S5 内再次提交、修改 `P` 或返回确认页。	testUnknownPageCannotReturnToConfirmation, testC5_087UnknownCannotResubmitModifyPOrReturnToConfirmation	已覆盖	所列专项方法直接断言该条款。
C5-088	SPEC-S5-20260812.v5.md	267	- 用户离开本页：结束本次清理会话并迁至 `S5-EXIT`。	testCell06LeaveFromUnknown	已覆盖	所列方法直接断言该条款。
C5-089	SPEC-S5-20260812.v5.md	268	- 应用进入非 active 或恢复 active：留在 `S5-U`。	testCell09InactiveFromUnknown, testCell12ActiveFromUnknown	已覆盖	所列方法直接断言该条款。
C5-090	SPEC-S5-20260812.v5.md	269	- 应用被系统终止：持久化终态；下次启动恢复 `S5-U`。	testCell15TerminationFromUnknown, testRestoreKeepsPersistedUnknownState	已覆盖	所列方法直接断言该条款。
C5-091	SPEC-S5-20260812.v5.md	300	| 从 S4-E1 进入 | 成功终态与快照已持久化 → S5-T0；首次入场读取一次基线 | 不可达：S5-T0 已完成入场 | 不可达：取消页不接收成功终态 | 不可达：S4-E1 不是失败终态 | 不可达：S4-E1 不是未知终态 |	testCell01SuccessEntry, testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt	已覆盖	可达单元格（事件“从 S4-E1 进入” × 起始状态“外部源”）：所列方法直接断言该单元格。
C5-092	SPEC-S5-20260812.v5.md	300	| 从 S4-E1 进入 | 成功终态与快照已持久化 → S5-T0；首次入场读取一次基线 | 不可达：S5-T0 已完成入场 | 不可达：取消页不接收成功终态 | 不可达：S4-E1 不是失败终态 | 不可达：S4-E1 不是未知终态 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E1 进入” × 起始状态“S5-T0”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-093	SPEC-S5-20260812.v5.md	300	| 从 S4-E1 进入 | 成功终态与快照已持久化 → S5-T0；首次入场读取一次基线 | 不可达：S5-T0 已完成入场 | 不可达：取消页不接收成功终态 | 不可达：S4-E1 不是失败终态 | 不可达：S4-E1 不是未知终态 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E1 进入” × 起始状态“S5-C”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-094	SPEC-S5-20260812.v5.md	300	| 从 S4-E1 进入 | 成功终态与快照已持久化 → S5-T0；首次入场读取一次基线 | 不可达：S5-T0 已完成入场 | 不可达：取消页不接收成功终态 | 不可达：S4-E1 不是失败终态 | 不可达：S4-E1 不是未知终态 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E1 进入” × 起始状态“S5-F”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-095	SPEC-S5-20260812.v5.md	300	| 从 S4-E1 进入 | 成功终态与快照已持久化 → S5-T0；首次入场读取一次基线 | 不可达：S5-T0 已完成入场 | 不可达：取消页不接收成功终态 | 不可达：S4-E1 不是失败终态 | 不可达：S4-E1 不是未知终态 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E1 进入” × 起始状态“S5-U”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-096	SPEC-S5-20260812.v5.md	301	| 从 S4-E2 进入 | 按 S4 传入的 `下游目标状态` 直接落位，不得二次判定：`S5-C` → S5-C；`S5-F` → S5-F | 不可达：S4-E2 不进入成功路径 | 不可达：S5-C 已完成入场 | 不可达：S5-F 已完成入场 | 不可达：S4-E2 已有失败回调结论 |	testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory, testFailureEntryUsesDownstreamTargetWithoutReadingFailureCategory, testCell02FailureEntry	已覆盖	可达单元格（事件“从 S4-E2 进入” × 起始状态“外部源”）：所列方法直接断言该单元格。
C5-097	SPEC-S5-20260812.v5.md	301	| 从 S4-E2 进入 | 按 S4 传入的 `下游目标状态` 直接落位，不得二次判定：`S5-C` → S5-C；`S5-F` → S5-F | 不可达：S4-E2 不进入成功路径 | 不可达：S5-C 已完成入场 | 不可达：S5-F 已完成入场 | 不可达：S4-E2 已有失败回调结论 |	testMismatchedHandoffPayloadAndTargetIsRejected, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E2 进入” × 起始状态“S5-T0”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-098	SPEC-S5-20260812.v5.md	301	| 从 S4-E2 进入 | 按 S4 传入的 `下游目标状态` 直接落位，不得二次判定：`S5-C` → S5-C；`S5-F` → S5-F | 不可达：S4-E2 不进入成功路径 | 不可达：S5-C 已完成入场 | 不可达：S5-F 已完成入场 | 不可达：S4-E2 已有失败回调结论 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E2 进入” × 起始状态“S5-C”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-099	SPEC-S5-20260812.v5.md	301	| 从 S4-E2 进入 | 按 S4 传入的 `下游目标状态` 直接落位，不得二次判定：`S5-C` → S5-C；`S5-F` → S5-F | 不可达：S4-E2 不进入成功路径 | 不可达：S5-C 已完成入场 | 不可达：S5-F 已完成入场 | 不可达：S4-E2 已有失败回调结论 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E2 进入” × 起始状态“S5-F”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-100	SPEC-S5-20260812.v5.md	301	| 从 S4-E2 进入 | 按 S4 传入的 `下游目标状态` 直接落位，不得二次判定：`S5-C` → S5-C；`S5-F` → S5-F | 不可达：S4-E2 不进入成功路径 | 不可达：S5-C 已完成入场 | 不可达：S5-F 已完成入场 | 不可达：S4-E2 已有失败回调结论 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E2 进入” × 起始状态“S5-U”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-101	SPEC-S5-20260812.v5.md	302	| 从 S4-E3 进入 | 未知终态、触发原因与快照已持久化 → S5-U | 不可达：S4-E3 没有成功回调 | 不可达：S4-E3 没有取消回调 | 不可达：S4-E3 没有失败回调 | 不可达：S5-U 已完成入场 |	testCell03UnknownEntry, testC5_101UnknownEntryPersistsReasonAndSnapshotBeforeReturning	已覆盖	可达单元格（事件“从 S4-E3 进入” × 起始状态“外部源”）：所列专项方法直接断言该条款。
C5-102	SPEC-S5-20260812.v5.md	302	| 从 S4-E3 进入 | 未知终态、触发原因与快照已持久化 → S5-U | 不可达：S4-E3 没有成功回调 | 不可达：S4-E3 没有取消回调 | 不可达：S4-E3 没有失败回调 | 不可达：S5-U 已完成入场 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E3 进入” × 起始状态“S5-T0”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-103	SPEC-S5-20260812.v5.md	302	| 从 S4-E3 进入 | 未知终态、触发原因与快照已持久化 → S5-U | 不可达：S4-E3 没有成功回调 | 不可达：S4-E3 没有取消回调 | 不可达：S4-E3 没有失败回调 | 不可达：S5-U 已完成入场 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E3 进入” × 起始状态“S5-C”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-104	SPEC-S5-20260812.v5.md	302	| 从 S4-E3 进入 | 未知终态、触发原因与快照已持久化 → S5-U | 不可达：S4-E3 没有成功回调 | 不可达：S4-E3 没有取消回调 | 不可达：S4-E3 没有失败回调 | 不可达：S5-U 已完成入场 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E3 进入” × 起始状态“S5-F”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-105	SPEC-S5-20260812.v5.md	302	| 从 S4-E3 进入 | 未知终态、触发原因与快照已持久化 → S5-U | 不可达：S4-E3 没有成功回调 | 不可达：S4-E3 没有取消回调 | 不可达：S4-E3 没有失败回调 | 不可达：S5-U 已完成入场 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“从 S4-E3 进入” × 起始状态“S5-U”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-106	SPEC-S5-20260812.v5.md	303	| 用户点击“我已清空最近删除” | 不可达：外部源没有该操作 | 读取一次完成读数、持久化展示结论 → S5-T0 | 不可达：取消页没有该操作 | 不可达：失败页没有该操作 | 不可达：未知页没有该操作 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户点击“我已清空最近删除”” × 起始状态“外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-107	SPEC-S5-20260812.v5.md	303	| 用户点击“我已清空最近删除” | 不可达：外部源没有该操作 | 读取一次完成读数、持久化展示结论 → S5-T0 | 不可达：取消页没有该操作 | 不可达：失败页没有该操作 | 不可达：未知页没有该操作 |	testConfirmationReadsCompletionExactlyOnceAndPersistsDelta	已覆盖	可达单元格（事件“用户点击“我已清空最近删除”” × 起始状态“S5-T0”）：所列方法直接断言该单元格。
C5-108	SPEC-S5-20260812.v5.md	303	| 用户点击“我已清空最近删除” | 不可达：外部源没有该操作 | 读取一次完成读数、持久化展示结论 → S5-T0 | 不可达：取消页没有该操作 | 不可达：失败页没有该操作 | 不可达：未知页没有该操作 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户点击“我已清空最近删除”” × 起始状态“S5-C”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-109	SPEC-S5-20260812.v5.md	303	| 用户点击“我已清空最近删除” | 不可达：外部源没有该操作 | 读取一次完成读数、持久化展示结论 → S5-T0 | 不可达：取消页没有该操作 | 不可达：失败页没有该操作 | 不可达：未知页没有该操作 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户点击“我已清空最近删除”” × 起始状态“S5-F”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-110	SPEC-S5-20260812.v5.md	303	| 用户点击“我已清空最近删除” | 不可达：外部源没有该操作 | 读取一次完成读数、持久化展示结论 → S5-T0 | 不可达：取消页没有该操作 | 不可达：失败页没有该操作 | 不可达：未知页没有该操作 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户点击“我已清空最近删除”” × 起始状态“S5-U”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-111	SPEC-S5-20260812.v5.md	304	| 用户点击“返回确认页” | 不可达：外部源没有该操作 | 不可达：S5-T0 没有该操作 | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 不可达：S5-U 没有该操作 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户点击“返回确认页”” × 起始状态“外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-112	SPEC-S5-20260812.v5.md	304	| 用户点击“返回确认页” | 不可达：外部源没有该操作 | 不可达：S5-T0 没有该操作 | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 不可达：S5-U 没有该操作 |	testSuccessPageCannotReturnToConfirmation, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户点击“返回确认页”” × 起始状态“S5-T0”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-113	SPEC-S5-20260812.v5.md	304	| 用户点击“返回确认页” | 不可达：外部源没有该操作 | 不可达：S5-T0 没有该操作 | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 不可达：S5-U 没有该操作 |	testCancellationReturnWithCacheCarriesOriginalSubmission, testCancellationReturnWithoutCacheCarriesOriginalSubmission	已覆盖	可达单元格（事件“用户点击“返回确认页”” × 起始状态“S5-C”）：所列方法直接断言该单元格。
C5-114	SPEC-S5-20260812.v5.md	304	| 用户点击“返回确认页” | 不可达：外部源没有该操作 | 不可达：S5-T0 没有该操作 | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 不可达：S5-U 没有该操作 |	testCell05AReturnFromFailureWithCache, testCell05BReturnFromFailureWithoutCache	已覆盖	可达单元格（事件“用户点击“返回确认页”” × 起始状态“S5-F”）：所列方法直接断言该单元格。
C5-115	SPEC-S5-20260812.v5.md	304	| 用户点击“返回确认页” | 不可达：外部源没有该操作 | 不可达：S5-T0 没有该操作 | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 缓存存在 → S3-2；缓存已随会话清空 → S3-1；两条路径均携带 P | 不可达：S5-U 没有该操作 |	testUnknownPageCannotReturnToConfirmation, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户点击“返回确认页”” × 起始状态“S5-U”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-116	SPEC-S5-20260812.v5.md	305	| 用户离开页面 | 不可达：外部源尚无 S5 页面 | 结束本次清理会话 → S5-EXIT | 不可达：取消页只提供返回确认页 | 不可达：失败页只提供返回确认页 | 结束会话 → S5-EXIT |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户离开页面” × 起始状态“外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-117	SPEC-S5-20260812.v5.md	305	| 用户离开页面 | 不可达：外部源尚无 S5 页面 | 结束本次清理会话 → S5-EXIT | 不可达：取消页只提供返回确认页 | 不可达：失败页只提供返回确认页 | 结束会话 → S5-EXIT |	testCell04LeaveFromSuccess	不适用	可达单元格（事件“用户离开页面” × 起始状态“S5-T0”）：MVE 范围外
C5-118	SPEC-S5-20260812.v5.md	305	| 用户离开页面 | 不可达：外部源尚无 S5 页面 | 结束本次清理会话 → S5-EXIT | 不可达：取消页只提供返回确认页 | 不可达：失败页只提供返回确认页 | 结束会话 → S5-EXIT |	testCancellationCannotLeaveThroughCompletionAction, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户离开页面” × 起始状态“S5-C”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-119	SPEC-S5-20260812.v5.md	305	| 用户离开页面 | 不可达：外部源尚无 S5 页面 | 结束本次清理会话 → S5-EXIT | 不可达：取消页只提供返回确认页 | 不可达：失败页只提供返回确认页 | 结束会话 → S5-EXIT |	testFailurePageCannotLeaveThroughCompletionAction, testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“用户离开页面” × 起始状态“S5-F”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-120	SPEC-S5-20260812.v5.md	305	| 用户离开页面 | 不可达：外部源尚无 S5 页面 | 结束本次清理会话 → S5-EXIT | 不可达：取消页只提供返回确认页 | 不可达：失败页只提供返回确认页 | 结束会话 → S5-EXIT |	testCell06LeaveFromUnknown	不适用	可达单元格（事件“用户离开页面” × 起始状态“S5-U”）：MVE 范围外
C5-121	SPEC-S5-20260812.v5.md	306	| 应用进入非 active | 不可达：尚未进入 S5 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“应用进入非 active” × 起始状态“外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-122	SPEC-S5-20260812.v5.md	306	| 应用进入非 active | 不可达：尚未进入 S5 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCell07InactiveFromSuccess, testLifecycleEventsDoNotReadFreeDiskAgain	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S5-T0”）：所列方法直接断言该单元格。
C5-123	SPEC-S5-20260812.v5.md	306	| 应用进入非 active | 不可达：尚未进入 S5 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCancellationLifecycleAndTerminationKeepState	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S5-C”）：所列方法直接断言该单元格。
C5-124	SPEC-S5-20260812.v5.md	306	| 应用进入非 active | 不可达：尚未进入 S5 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCell08InactiveFromFailure	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S5-F”）：所列方法直接断言该单元格。
C5-125	SPEC-S5-20260812.v5.md	306	| 应用进入非 active | 不可达：尚未进入 S5 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCell09InactiveFromUnknown	已覆盖	可达单元格（事件“应用进入非 active” × 起始状态“S5-U”）：所列方法直接断言该单元格。
C5-126	SPEC-S5-20260812.v5.md	307	| 应用恢复 active | 不可达：尚未进入 S5；S4 的恢复交接由上游处理 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“应用恢复 active” × 起始状态“外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-127	SPEC-S5-20260812.v5.md	307	| 应用恢复 active | 不可达：尚未进入 S5；S4 的恢复交接由上游处理 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCell10ActiveFromSuccess, testLifecycleEventsDoNotReadFreeDiskAgain	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S5-T0”）：所列方法直接断言该单元格。
C5-128	SPEC-S5-20260812.v5.md	307	| 应用恢复 active | 不可达：尚未进入 S5；S4 的恢复交接由上游处理 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCancellationLifecycleAndTerminationKeepState	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S5-C”）：所列方法直接断言该单元格。
C5-129	SPEC-S5-20260812.v5.md	307	| 应用恢复 active | 不可达：尚未进入 S5；S4 的恢复交接由上游处理 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCell11ActiveFromFailure	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S5-F”）：所列方法直接断言该单元格。
C5-130	SPEC-S5-20260812.v5.md	307	| 应用恢复 active | 不可达：尚未进入 S5；S4 的恢复交接由上游处理 | → S5-T0；不新增磁盘读取 | → S5-C；保留取消上下文 | → S5-F；保留失败上下文 | → S5-U；保留未知上下文 |	testCell12ActiveFromUnknown	已覆盖	可达单元格（事件“应用恢复 active” × 起始状态“S5-U”）：所列方法直接断言该单元格。
C5-131	SPEC-S5-20260812.v5.md	308	| 应用被系统终止 | 不可达：S5 尚未建立；若终止发生在 S4 则由 S4 规则处理 | 持久化 S5-T0 上下文；下次启动恢复 S5-T0 | 持久化 S5-C；下次启动恢复 S5-C | 持久化 S5-F；下次启动恢复 S5-F | 持久化 S5-U；下次启动恢复 S5-U |	testAll115TransitionCellsAndEveryUnreachableCombination	已覆盖	断言型条款（事件“应用被系统终止” × 起始状态“外部源”）：守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。
C5-132	SPEC-S5-20260812.v5.md	308	| 应用被系统终止 | 不可达：S5 尚未建立；若终止发生在 S4 则由 S4 规则处理 | 持久化 S5-T0 上下文；下次启动恢复 S5-T0 | 持久化 S5-C；下次启动恢复 S5-C | 持久化 S5-F；下次启动恢复 S5-F | 持久化 S5-U；下次启动恢复 S5-U |	testCell13TerminationFromSuccess, testRestoreKeepsPersistedSuccessState	已覆盖	可达单元格（事件“应用被系统终止” × 起始状态“S5-T0”）：所列方法直接断言该单元格。
C5-133	SPEC-S5-20260812.v5.md	308	| 应用被系统终止 | 不可达：S5 尚未建立；若终止发生在 S4 则由 S4 规则处理 | 持久化 S5-T0 上下文；下次启动恢复 S5-T0 | 持久化 S5-C；下次启动恢复 S5-C | 持久化 S5-F；下次启动恢复 S5-F | 持久化 S5-U；下次启动恢复 S5-U |	testCancellationLifecycleAndTerminationKeepState, testRestoreKeepsPersistedCancellationStateWithoutDiskRead	已覆盖	可达单元格（事件“应用被系统终止” × 起始状态“S5-C”）：所列方法直接断言该单元格。
C5-134	SPEC-S5-20260812.v5.md	308	| 应用被系统终止 | 不可达：S5 尚未建立；若终止发生在 S4 则由 S4 规则处理 | 持久化 S5-T0 上下文；下次启动恢复 S5-T0 | 持久化 S5-C；下次启动恢复 S5-C | 持久化 S5-F；下次启动恢复 S5-F | 持久化 S5-U；下次启动恢复 S5-U |	testCell14TerminationFromFailure, testRestoreKeepsPersistedFailureState	已覆盖	可达单元格（事件“应用被系统终止” × 起始状态“S5-F”）：所列方法直接断言该单元格。
C5-135	SPEC-S5-20260812.v5.md	308	| 应用被系统终止 | 不可达：S5 尚未建立；若终止发生在 S4 则由 S4 规则处理 | 持久化 S5-T0 上下文；下次启动恢复 S5-T0 | 持久化 S5-C；下次启动恢复 S5-C | 持久化 S5-F；下次启动恢复 S5-F | 持久化 S5-U；下次启动恢复 S5-U |	testCell15TerminationFromUnknown, testRestoreKeepsPersistedUnknownState	已覆盖	可达单元格（事件“应用被系统终止” × 起始状态“S5-U”）：所列方法直接断言该单元格。
C5-136	SPEC-S5-20260812.v5.md	316	| S4-E1 | 提交标识、`P`、`N`、成功终态、S3 冻结的 L2 三字段、`下游目标状态` | `S5-T0` |	testReachable12SuccessCallbackFromSubmitted, testReachable09ActiveFromSuccessTerminal, testCell01SuccessEntry, testPersistedSessionCarriesDownstreamTargetState	已覆盖	所列方法直接断言该条款。
C5-137	SPEC-S5-20260812.v5.md	317	| S4-E2 | 提交标识、`P`、`N`、`A`、`B`、`C`、非空失败原因、底层系统域与系统码、S3 冻结的 L2 三字段、`下游目标状态` | `S5-C` 或 `S5-F` |	testReachable14FailureCallbackFromSubmitted, testReachable10ActiveFromFailureTerminal, testUserCancellationWritesCancelledTargetBeforeHandoff, testOtherFailureCategoriesWriteFailureTarget, testCell02FailureEntry, testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory	已覆盖	所列方法直接断言该条款。
C5-138	SPEC-S5-20260812.v5.md	318	| S4-E3 | 提交标识、`P`、`N`、未知触发原因、S3 冻结的 L2 三字段、`下游目标状态` | `S5-U` |	testReachable11ActiveFromUnknownTerminal, testCell03UnknownEntry	已覆盖	所列方法直接断言该条款。
C5-139	SPEC-S5-20260812.v5.md	320	`下游目标状态` 的取值域为 {`S5-T0`, `S5-F`, `S5-C`, `S5-U`}，与 S4 定义完全一致。S5 接收后按 S4 传入的 `下游目标状态` 直接落位，不得二次判定，并拥有完成页所需数据的持久化副本；页面恢复不依赖 S4 仍驻留内存。该字段为 `S5-C` 时只选择取消呈现状态，不改写 S4 交接的三个集合。	testDownstreamTargetStateValueDomainIsComplete, testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory, testFailureEntryUsesDownstreamTargetWithoutReadingFailureCategory, testMismatchedHandoffPayloadAndTargetIsRejected, testRestoreKeepsPersistedSuccessState, testRestoreKeepsPersistedFailureState, testRestoreKeepsPersistedCancellationStateWithoutDiskRead, testRestoreKeepsPersistedUnknownState	已覆盖	所列方法直接断言该条款。
C5-140	SPEC-S5-20260812.v5.md	324	- “返回确认页”始终携带原提交集合 `P`，不得只携带 `B` 或 `C`。	testCancellationReturnWithCacheCarriesOriginalSubmission, testCancellationReturnWithoutCacheCarriesOriginalSubmission, testCell05AReturnFromFailureWithCache, testCell05BReturnFromFailureWithoutCache	已覆盖	所列方法直接断言该条款。
C5-141	SPEC-S5-20260812.v5.md	325	- 本会话内，资产级结论缓存不因集合变化而失效；缓存仍存在时直接进入 `S3-2`，无需重扫。	testCancellationReturnWithCacheCarriesOriginalSubmission, testCell05AReturnFromFailureWithCache	已覆盖	所列方法直接断言该条款。
C5-142	SPEC-S5-20260812.v5.md	326	- 缓存已因会话结束清空时进入 `S3-1`，由 S3 对 `P` 重新扫描。	testCancellationReturnWithoutCacheCarriesOriginalSubmission, testCell05BReturnFromFailureWithoutCache	已覆盖	所列方法直接断言该条款。
C5-143	SPEC-S5-20260812.v5.md	327	- S5 本身不发起再次删除；后续提交仍须经过确认页冻结新的提交快照。	testSuccessPageCannotReturnToConfirmation, testUnknownPageCannotReturnToConfirmation, testCell14SubmitFromS3_2FreezesSnapshotForS4_1, testC5_143NewDeletionMustReturnToS3AndFreezeNewSnapshot	已覆盖	所列专项方法直接断言该条款。
C5-144	SPEC-S5-20260812.v5.md	333	| S5-T0 | `S5-EXIT`，即应用的清理入口页 | 结束本次清理会话，清除本批 L3 读数与展示结论 |	testCell04LeaveFromSuccess, testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime, testC5_144SuccessExitClearsPersistedL3Session	不适用	MVE 范围外
C5-145	SPEC-S5-20260812.v5.md	334	| S5-U | `S5-EXIT`，即应用的清理入口页 | 结束本次清理会话，不推断删除结果，不自动再次提交 |	testCell06LeaveFromUnknown, testUnknownEntryDoesNotConstructClassificationSets, testC5_145UnknownExitDoesNotInferResultOrResubmit	不适用	MVE 范围外
C5-146	SPEC-S5-20260812.v5.md	336	`S5-C` 与 `S5-F` 不使用 `S5-EXIT`；二者只按本节第二部分返回确认页。	testCancellationCannotLeaveThroughCompletionAction, testFailurePageCannotLeaveThroughCompletionAction, testCancellationReturnWithCacheCarriesOriginalSubmission, testCell05AReturnFromFailureWithCache	已覆盖	所列方法直接断言该条款。
```
<!-- 正向矩阵结束 -->

## 四、反向映射

<!-- 反向映射开始 -->
```
XCTest 方法名	测试文件	行号	命中条款编号
testDisjointCompleteClassificationIsAccepted	PhotoCleanupMVETests/CollectionInvariantTests.swift	9	C34-148, C34-152, C34-213, C34-214, C34-215, C34-220, C34-223, C5-007
testSuccessAndFailureOverlapIsRejected	PhotoCleanupMVETests/CollectionInvariantTests.swift	25	C34-222, C5-008
testSuccessAndUnprocessedOverlapIsRejected	PhotoCleanupMVETests/CollectionInvariantTests.swift	38	C34-222, C5-008
testFailureAndUnprocessedOverlapIsRejected	PhotoCleanupMVETests/CollectionInvariantTests.swift	50	C34-222, C5-008
testForeignAssetIsRejected	PhotoCleanupMVETests/CollectionInvariantTests.swift	62	C34-223, C34-224, C5-009
testOmittedAssetIsRejected	PhotoCleanupMVETests/CollectionInvariantTests.swift	74	C34-223, C34-224, C5-008, C5-009
testEmptyFailureReasonIsRejected	PhotoCleanupMVETests/CollectionInvariantTests.swift	86	C34-149, C34-217, C34-227, C5-060
testSuccessResultClassifiesEverySubmittedAssetAsSuccessful	PhotoCleanupMVETests/CollectionInvariantTests.swift	99	C34-139, C34-213, C5-010
testBatchLevelFailureUsesWholeSubmittedSetAsFailure	PhotoCleanupMVETests/CollectionInvariantTests.swift	112	C34-214, C34-225
testFailureBeforeSystemAcceptanceUsesWholeSubmittedSetAsUnprocessed	PhotoCleanupMVETests/CollectionInvariantTests.swift	130	C34-215, C34-226
testFailureEntryReusesPersistedClassificationWithoutModification	PhotoCleanupMVETests/CollectionInvariantTests.swift	148	C5-011, C5-059, C5-068
testUnknownEntryDoesNotConstructClassificationSets	PhotoCleanupMVETests/CollectionInvariantTests.swift	172	C34-163, C5-013, C5-078, C5-085, C5-145
testFailureEntryRejectsInvalidClassification	PhotoCleanupMVETests/CollectionInvariantTests.swift	190	C5-008
testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed	PhotoCleanupMVETests/CollectionInvariantTests.swift	212	C34-218, C34-219, C34-229, C5-012, C5-042, C5-050
testS4UserCancellationClassifierRequiresExactDomainAndCode	PhotoCleanupMVETests/CollectionInvariantTests.swift	233	C34-216, C34-221, C34-228
testPhotoKitBatchFailureClassifiesWholeSetAsFailed	PhotoCleanupMVETests/CollectionInvariantTests.swift	257	C34-218, C34-219, C34-228, C34-229
testC34_114SubmittedStateRejectsEveryFullPartialAndModifiedResubmission	PhotoCleanupMVETests/CoverageGapTests.swift	36	C34-114
testC34_116SubmittedSnapshotCannotBeModifiedCancelledOrSplit	PhotoCleanupMVETests/CoverageGapTests.swift	46	C34-116
testC34_128ResumedStateRejectsEveryResultChangingAppOperation	PhotoCleanupMVETests/CoverageGapTests.swift	63	C34-128
testC34_130ResumedSnapshotCannotBeModifiedCancelledOrSplit	PhotoCleanupMVETests/CoverageGapTests.swift	81	C34-130
testC34_146SuccessTerminalWaitsWhileInactiveAndContinuesAfterRestart	PhotoCleanupMVETests/CoverageGapTests.swift	97	C34-146
testC34_152FailureTerminalResultSetsRemainImmutableForEveryLaterEvent	PhotoCleanupMVETests/CoverageGapTests.swift	130	C34-152
testC34_153FailureTerminalRejectsWholeAndPartialResubmission	PhotoCleanupMVETests/CoverageGapTests.swift	159	C34-153
testC34_157FailureTargetSurvivesTerminationWithoutReclassification	PhotoCleanupMVETests/CoverageGapTests.swift	178	C34-157
testC34_163UnknownTerminalRejectsSuccessAndFailureInference	PhotoCleanupMVETests/CoverageGapTests.swift	211	C34-163
testC34_165UnknownTerminalRejectsWholeAndPartialResubmission	PhotoCleanupMVETests/CoverageGapTests.swift	233	C34-165
testC34_166LateFailureCannotOverwriteUnknownTerminal	PhotoCleanupMVETests/CoverageGapTests.swift	253	C34-166
testC34_186RestoredCancellationTerminalUsesPersistedTargetOnActive	PhotoCleanupMVETests/CoverageGapTests.swift	268	C34-186
testC34_209SuccessTerminalContinuesHandoffAfterTerminationAndRestart	PhotoCleanupMVETests/CoverageGapTests.swift	291	C34-209
testC34_210FailureTerminalContinuesHandoffAfterTerminationAndRestart	PhotoCleanupMVETests/CoverageGapTests.swift	300	C34-210
testC34_211UnknownTerminalContinuesHandoffAfterTerminationAndRestart	PhotoCleanupMVETests/CoverageGapTests.swift	309	C34-211
testC5_006SuccessAndUnknownExitDoNotSubmitOrStartScanning	PhotoCleanupMVETests/CoverageGapTests.swift	318	C5-006
testC5_031RepeatedLifecycleTicksNeverPollFreeDisk	PhotoCleanupMVETests/CoverageGapTests.swift	351	C5-031
testC5_034SuccessOnlyLeavesThroughExitAndCannotModifySubmission	PhotoCleanupMVETests/CoverageGapTests.swift	381	C5-034
testC5_039CompletedReadingsSurviveTerminationAndRestoreWithoutNewRead	PhotoCleanupMVETests/CoverageGapTests.swift	397	C5-039
testC5_069FailureNeverReadsFreeDiskOrDisplaysL3	PhotoCleanupMVETests/CoverageGapTests.swift	428	C5-069
testC5_086UnknownCannotReadConfirmOrWriteBackManualResult	PhotoCleanupMVETests/CoverageGapTests.swift	463	C5-086
testC5_087UnknownCannotResubmitModifyPOrReturnToConfirmation	PhotoCleanupMVETests/CoverageGapTests.swift	492	C5-087
testC5_101UnknownEntryPersistsReasonAndSnapshotBeforeReturning	PhotoCleanupMVETests/CoverageGapTests.swift	510	C5-101
testC5_143NewDeletionMustReturnToS3AndFreezeNewSnapshot	PhotoCleanupMVETests/CoverageGapTests.swift	527	C5-143
testC5_144SuccessExitClearsPersistedL3Session	PhotoCleanupMVETests/CoverageGapTests.swift	561	C5-144
testC5_145UnknownExitDoesNotInferResultOrResubmit	PhotoCleanupMVETests/CoverageGapTests.swift	591	C5-145
testCell01EnterFromOutsideWithEmptySetRoutesToS3_4	PhotoCleanupMVETests/S3StateMachineTests.swift	7	C34-001, C34-002, C34-061, C34-064
testCell01EnterFromOutsideWithLargeSetRoutesToS3_1AndQueuesEveryAsset	PhotoCleanupMVETests/S3StateMachineTests.swift	15	C34-001, C34-003, C34-064
testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted	PhotoCleanupMVETests/S3StateMachineTests.swift	24	C34-001, C34-003, C34-016, C34-063, C34-064
testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan	PhotoCleanupMVETests/S3StateMachineTests.swift	41	C34-001, C34-004, C34-063, C34-064
testCell02ScanCompletionFromS3_1RoutesToS3_2	PhotoCleanupMVETests/S3StateMachineTests.swift	57	C34-019, C34-033, C34-069
testCell03RemoveDuringScanLastItemRoutesToS3_4	PhotoCleanupMVETests/S3StateMachineTests.swift	70	C34-027, C34-034, C34-073
testCell03RemoveDuringScanLastIncompleteItemRoutesToS3_2	PhotoCleanupMVETests/S3StateMachineTests.swift	79	C34-027, C34-035, C34-073
testCell03RemoveDuringScanWhileIncompleteItemRemainsStaysInS3_1	PhotoCleanupMVETests/S3StateMachineTests.swift	92	C34-027, C34-036, C34-073
testCell04RemoveOneFromS3_1LastItemRoutesToS3_4	PhotoCleanupMVETests/S3StateMachineTests.swift	106	C34-077
testCell04RemoveOneFromS3_1LastIncompleteItemRoutesToS3_2	PhotoCleanupMVETests/S3StateMachineTests.swift	117	C34-077
testCell04RemoveOneFromS3_1WhileIncompleteItemRemainsStaysInS3_1	PhotoCleanupMVETests/S3StateMachineTests.swift	132	C34-077
testCell05RemoveOneFromS3_2WhileNonEmptyStaysInS3_2	PhotoCleanupMVETests/S3StateMachineTests.swift	152	C34-043, C34-049, C34-078
testCell05RemoveLastItemFromS3_2RoutesToS3_4	PhotoCleanupMVETests/S3StateMachineTests.swift	166	C34-043, C34-050, C34-078
testCell07CancelAllFromS3_1RoutesToS3_4AndKeepsCache	PhotoCleanupMVETests/S3StateMachineTests.swift	179	C34-028, C34-081
testCell08CancelAllFromS3_2RoutesToS3_4AndKeepsCache	PhotoCleanupMVETests/S3StateMachineTests.swift	188	C34-028, C34-044, C34-082
testCell11CollectionBecameEmptyFromS3_1RoutesToS3_4	PhotoCleanupMVETests/S3StateMachineTests.swift	201	C34-085
testCell12CollectionBecameEmptyFromS3_2RoutesToS3_4	PhotoCleanupMVETests/S3StateMachineTests.swift	210	C34-086
testCell14SubmitFromS3_2FreezesSnapshotForS4_1	PhotoCleanupMVETests/S3StateMachineTests.swift	223	C34-020, C34-045, C34-047, C34-051, C34-090, C34-093, C34-094, C34-095, C34-096, C34-097, C34-098, C34-099, C34-100, C34-104, C5-143
testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot	PhotoCleanupMVETests/S3StateMachineTests.swift	248	C34-020, C34-052, C34-058, C34-091, C34-101, C34-102, C34-104
testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot	PhotoCleanupMVETests/S3StateMachineTests.swift	258	C34-019, C34-020, C34-030, C34-031, C34-052, C34-089, C34-101, C34-103, C34-104
testDisabledOperationsInS3_4HaveNoEffect	PhotoCleanupMVETests/S3StateMachineTests.swift	268	C34-059, C34-060, C34-079, C34-083, C34-087
testUnknownOrNegativeScanResultIsRejectedWithoutChangingCache	PhotoCleanupMVETests/S3StateMachineTests.swift	277	C34-013, C34-096
testReachable01SubmissionFromExternalSource	PhotoCleanupMVETests/S4StateMachineTests.swift	13	C34-107, C34-170
testReachable02InactiveFromSubmitted	PhotoCleanupMVETests/S4StateMachineTests.swift	27	C34-121, C34-177
testReachable03InactiveFromResumedInteraction	PhotoCleanupMVETests/S4StateMachineTests.swift	37	C34-136, C34-178
testReachable04InactiveFromSuccessTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	47	C34-144, C34-146, C34-179
testReachable05InactiveFromFailureTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	57	C34-155, C34-157, C34-180
testReachable06InactiveFromUnknownTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	67	C34-181
testReachable07ActiveFromSubmitted	PhotoCleanupMVETests/S4StateMachineTests.swift	77	C34-107, C34-122, C34-183
testReachable08ActiveFromResumedInteraction	PhotoCleanupMVETests/S4StateMachineTests.swift	88	C34-136, C34-184
testReachable09ActiveFromSuccessTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	98	C34-141, C34-145, C34-146, C34-179, C34-185, C5-136
testReachable10ActiveFromFailureTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	116	C34-151, C34-157, C34-180, C34-186, C5-137
testReachable11ActiveFromUnknownTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	131	C34-162, C34-167, C34-168, C34-181, C34-187, C5-138
testReachable12SuccessCallbackFromSubmitted	PhotoCleanupMVETests/S4StateMachineTests.swift	145	C34-118, C34-138, C34-141, C34-144, C34-145, C34-169, C34-189, C5-136
testReachable13SuccessCallbackFromResumedInteraction	PhotoCleanupMVETests/S4StateMachineTests.swift	161	C34-133, C34-138, C34-190
testReachable14FailureCallbackFromSubmitted	PhotoCleanupMVETests/S4StateMachineTests.swift	173	C34-119, C34-147, C34-151, C34-155, C34-156, C34-195, C34-220, C5-137
testReachable15FailureCallbackFromResumedInteraction	PhotoCleanupMVETests/S4StateMachineTests.swift	189	C34-134, C34-147, C34-196
testReachable16TimeoutFromSubmitted	PhotoCleanupMVETests/S4StateMachineTests.swift	201	C34-120, C34-160, C34-161, C34-169, C34-201, C5-077
testReachable17TimeoutFromResumedInteraction	PhotoCleanupMVETests/S4StateMachineTests.swift	215	C34-135, C34-202
testReachable18TerminationFromSubmitted	PhotoCleanupMVETests/S4StateMachineTests.swift	227	C34-123, C34-160, C34-161, C34-207, C5-077
testReachable19TerminationFromResumedInteraction	PhotoCleanupMVETests/S4StateMachineTests.swift	240	C34-137, C34-208
testReachable20TerminationFromSuccessTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	251	C34-142, C34-146, C34-209
testReachable21TerminationFromFailureTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	261	C34-210
testReachable22TerminationFromUnknownTerminal	PhotoCleanupMVETests/S4StateMachineTests.swift	271	C34-168, C34-211
testDuplicateSubmissionIsRejected	PhotoCleanupMVETests/S4StateMachineTests.swift	279	C34-106, C34-114, C34-115, C34-128, C34-171
testElapsedTimeBelowLimitKeepsPendingState	PhotoCleanupMVETests/S4StateMachineTests.swift	287	C34-120, C34-201
testInactiveDurationDoesNotAccumulate	PhotoCleanupMVETests/S4StateMachineTests.swift	296	C34-121, C34-136, C34-177
testResumeContinuesRemainingActiveTime	PhotoCleanupMVETests/S4StateMachineTests.swift	307	C34-122, C34-136
testMismatchedSuccessCallbackIsRejected	PhotoCleanupMVETests/S4StateMachineTests.swift	318	C34-212
testMismatchedFailureCallbackIsRejected	PhotoCleanupMVETests/S4StateMachineTests.swift	329	C34-212
testLateFailureCannotOverwriteSuccess	PhotoCleanupMVETests/S4StateMachineTests.swift	338	C34-109, C34-142, C34-197
testLateSuccessCannotOverwriteFailure	PhotoCleanupMVETests/S4StateMachineTests.swift	350	C34-109, C34-192
testLateCallbackCannotOverwriteUnknown	PhotoCleanupMVETests/S4StateMachineTests.swift	362	C34-109, C34-166, C34-193
testPersistenceFailureLeavesCallbackStateUnchanged	PhotoCleanupMVETests/S4StateMachineTests.swift	373	C34-108
testSnapshotNeverChangesInsideExecutionState	PhotoCleanupMVETests/S4StateMachineTests.swift	386	C34-092, C34-105, C34-116, C34-128, C34-130, C34-164
testRestoreConvertsSubmittedStateToUnknown	PhotoCleanupMVETests/S4StateMachineTests.swift	400	C34-123, C34-207
testRestoreConvertsResumedStateToUnknown	PhotoCleanupMVETests/S4StateMachineTests.swift	415	C34-137, C34-208
testRestoreKeepsClosedTerminalState	PhotoCleanupMVETests/S4StateMachineTests.swift	428	C34-109
testStartPersistenceFailurePreventsMachineCreation	PhotoCleanupMVETests/S4StateMachineTests.swift	439	—
testSecondStartWithSameSubmissionIdentifierIsRejected	PhotoCleanupMVETests/S4StateMachineTests.swift	448	C34-093, C34-106, C34-115, C34-143, C34-153, C34-165, C34-171
testDownstreamTargetStateValueDomainIsComplete	PhotoCleanupMVETests/S4StateMachineTests.swift	468	C34-169, C34-216, C5-139
testUserCancellationWritesCancelledTargetBeforeHandoff	PhotoCleanupMVETests/S4StateMachineTests.swift	475	C34-108, C34-156, C34-157, C34-169, C34-186, C34-216, C5-137
testOtherFailureCategoriesWriteFailureTarget	PhotoCleanupMVETests/S4StateMachineTests.swift	496	C34-156, C34-157, C34-169, C34-186, C34-216, C5-137
testPersistedSessionCarriesDownstreamTargetState	PhotoCleanupMVETests/S4StateMachineTests.swift	517	C34-169, C5-136
testC34_020DeletionStartsOnlyAfterSnapshotFreeze	PhotoCleanupMVETests/S4StateMachineTests.swift	533	C34-020
testC34_047UnfrozenSnapshotCannotReachDeletionService	PhotoCleanupMVETests/S4StateMachineTests.swift	573	C34-047
testC34_104FreezeFailureDoesNotCallDeletionService	PhotoCleanupMVETests/S4StateMachineTests.swift	586	C34-104
testCell01SuccessEntry	PhotoCleanupMVETests/S5StateMachineTests.swift	13	C5-001, C5-002, C5-007, C5-010, C5-014, C5-016, C5-019, C5-020, C5-091, C5-136
testCell02FailureEntry	PhotoCleanupMVETests/S5StateMachineTests.swift	39	C5-001, C5-004, C5-011, C5-060, C5-096, C5-137
testCell03UnknownEntry	PhotoCleanupMVETests/S5StateMachineTests.swift	54	C5-001, C5-005, C5-013, C5-077, C5-101, C5-138
testCell04LeaveFromSuccess	PhotoCleanupMVETests/S5StateMachineTests.swift	69	C5-006, C5-026, C5-029, C5-036, C5-117, C5-144
testCell05AReturnFromFailureWithCache	PhotoCleanupMVETests/S5StateMachineTests.swift	78	C5-006, C5-015, C5-063, C5-066, C5-071, C5-114, C5-140, C5-141, C5-146
testCell05BReturnFromFailureWithoutCache	PhotoCleanupMVETests/S5StateMachineTests.swift	92	C5-015, C5-063, C5-066, C5-072, C5-114, C5-140, C5-142
testCell06LeaveFromUnknown	PhotoCleanupMVETests/S5StateMachineTests.swift	106	C5-006, C5-084, C5-088, C5-120, C5-145
testCell07InactiveFromSuccess	PhotoCleanupMVETests/S5StateMachineTests.swift	115	C5-037, C5-122
testCell08InactiveFromFailure	PhotoCleanupMVETests/S5StateMachineTests.swift	125	C5-073, C5-124
testCell09InactiveFromUnknown	PhotoCleanupMVETests/S5StateMachineTests.swift	135	C5-089, C5-125
testCell10ActiveFromSuccess	PhotoCleanupMVETests/S5StateMachineTests.swift	145	C5-038, C5-127
testCell11ActiveFromFailure	PhotoCleanupMVETests/S5StateMachineTests.swift	157	C5-073, C5-129
testCell12ActiveFromUnknown	PhotoCleanupMVETests/S5StateMachineTests.swift	169	C5-089, C5-130
testCell13TerminationFromSuccess	PhotoCleanupMVETests/S5StateMachineTests.swift	181	C5-039, C5-132
testCell14TerminationFromFailure	PhotoCleanupMVETests/S5StateMachineTests.swift	195	C5-074, C5-134
testCell15TerminationFromUnknown	PhotoCleanupMVETests/S5StateMachineTests.swift	205	C5-090, C5-135
testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation	PhotoCleanupMVETests/S5StateMachineTests.swift	214	C5-025, C5-028, C5-070, C5-086
testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory	PhotoCleanupMVETests/S5StateMachineTests.swift	229	C5-001, C5-003, C5-012, C5-042, C5-050, C5-096, C5-137, C5-139
testFailureEntryUsesDownstreamTargetWithoutReadingFailureCategory	PhotoCleanupMVETests/S5StateMachineTests.swift	248	C5-012, C5-096, C5-139
testCancellationReturnWithCacheCarriesOriginalSubmission	PhotoCleanupMVETests/S5StateMachineTests.swift	265	C5-006, C5-015, C5-044, C5-048, C5-054, C5-113, C5-140, C5-141, C5-146
testCancellationReturnWithoutCacheCarriesOriginalSubmission	PhotoCleanupMVETests/S5StateMachineTests.swift	278	C5-015, C5-044, C5-048, C5-055, C5-113, C5-140, C5-142
testCancellationLifecycleAndTerminationKeepState	PhotoCleanupMVETests/S5StateMachineTests.swift	291	C5-056, C5-057, C5-123, C5-128, C5-133
testCancellationCannotLeaveThroughCompletionAction	PhotoCleanupMVETests/S5StateMachineTests.swift	305	C5-006, C5-052, C5-118, C5-146
testCancellationDoesNotReadFreeDiskStrictGB	PhotoCleanupMVETests/S5StateMachineTests.swift	313	C5-051
testCancellationDoesNotShowL3	PhotoCleanupMVETests/S5StateMachineTests.swift	338	C5-046, C5-051
testCancellationDoesNotShowSystemErrorDomainOrCode	PhotoCleanupMVETests/S5StateMachineTests.swift	344	C5-045
testCancellationDoesNotShowRecentlyDeletedConfirmationAction	PhotoCleanupMVETests/S5StateMachineTests.swift	350	C5-052
testCancellationVisibleCopyAvoidsFailureAndIncompleteWording	PhotoCleanupMVETests/S5StateMachineTests.swift	359	C5-053
testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt	PhotoCleanupMVETests/S5StateMachineTests.swift	374	C5-023, C5-091
testConfirmationReadsCompletionExactlyOnceAndPersistsDelta	PhotoCleanupMVETests/S5StateMachineTests.swift	394	C5-028, C5-035, C5-107
testRepeatedConfirmationDoesNotReadAgain	PhotoCleanupMVETests/S5StateMachineTests.swift	425	C5-025, C5-030, C5-031
testLifecycleEventsDoNotReadFreeDiskAgain	PhotoCleanupMVETests/S5StateMachineTests.swift	459	C5-031, C5-037, C5-038, C5-039, C5-122, C5-127
testUnavailableReadingsArePersistedWithoutDeltaOrRetry	PhotoCleanupMVETests/S5StateMachineTests.swift	494	C5-028, C5-031, C5-035
testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime	PhotoCleanupMVETests/S5StateMachineTests.swift	520	C5-020, C5-035, C5-039, C5-144
testL3DisplayRemainsBlockedForEveryState	PhotoCleanupMVETests/S5StateMachineTests.swift	543	C5-022, C5-024, C5-032, C5-064, C5-069, C5-082, C5-086
testMismatchedHandoffPayloadAndTargetIsRejected	PhotoCleanupMVETests/S5StateMachineTests.swift	551	C5-097, C5-139
testFailurePageCannotLeaveThroughCompletionAction	PhotoCleanupMVETests/S5StateMachineTests.swift	572	C5-006, C5-070, C5-119, C5-146
testSuccessPageCannotReturnToConfirmation	PhotoCleanupMVETests/S5StateMachineTests.swift	580	C5-034, C5-112, C5-143
testUnknownPageCannotReturnToConfirmation	PhotoCleanupMVETests/S5StateMachineTests.swift	590	C5-087, C5-115, C5-143
testEntryPersistenceFailurePreventsListInvalidation	PhotoCleanupMVETests/S5StateMachineTests.swift	600	C5-014
testLifecyclePersistenceFailureLeavesStateUnchanged	PhotoCleanupMVETests/S5StateMachineTests.swift	613	—
testRestoreKeepsPersistedSuccessState	PhotoCleanupMVETests/S5StateMachineTests.swift	626	C5-039, C5-132, C5-139
testRestoreKeepsPersistedFailureState	PhotoCleanupMVETests/S5StateMachineTests.swift	637	C5-074, C5-134, C5-139
testRestoreKeepsPersistedCancellationStateWithoutDiskRead	PhotoCleanupMVETests/S5StateMachineTests.swift	648	C5-057, C5-133, C5-139
testRestoreKeepsPersistedUnknownState	PhotoCleanupMVETests/S5StateMachineTests.swift	661	C5-090, C5-135, C5-139
testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder	PhotoCleanupMVETests/SnapshotInvariantTests.swift	6	C34-008, C34-023, C34-040, C34-094
testLargeSelectionQueuesEveryDeduplicatedAssetWithoutTruncation	PhotoCleanupMVETests/SnapshotInvariantTests.swift	26	C34-016
testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD	PhotoCleanupMVETests/SnapshotInvariantTests.swift	38	C34-014, C34-015, C34-096, C34-097
testRemovingAssetRetainsItsOnlyCachedConclusion	PhotoCleanupMVETests/SnapshotInvariantTests.swift	58	C34-013, C34-015
testRemovingQueuedAssetDoesNotInvalidateItsQueuedWork	PhotoCleanupMVETests/SnapshotInvariantTests.swift	70	C34-015
testLateSuccessForCurrentAssetImmediatelyUpdatesCurrentStatistics	PhotoCleanupMVETests/SnapshotInvariantTests.swift	79	C34-017
testLateFailureForCurrentAssetImmediatelyUpdatesCurrentStatistics	PhotoCleanupMVETests/SnapshotInvariantTests.swift	89	C34-017
testLateResultForRemovedAssetUpdatesCacheButNotCurrentStatistics	PhotoCleanupMVETests/SnapshotInvariantTests.swift	99	C34-017
testReentryReusesCompletedCacheWithoutQueueingAgain	PhotoCleanupMVETests/SnapshotInvariantTests.swift	110	C34-018, C34-063
testTakingQueueDoesNotQueueInProgressAssetsAgain	PhotoCleanupMVETests/SnapshotInvariantTests.swift	126	C34-016
testOneUnavailableConclusionDoesNotStopOtherScans	PhotoCleanupMVETests/SnapshotInvariantTests.swift	136	C34-019
testFavoriteAssetsUseSameScanRulesAndRemainSubmittable	PhotoCleanupMVETests/SnapshotInvariantTests.swift	147	C34-009, C34-023, C34-040, C34-045, C34-099, C34-101
testSnapshotUsesExactModeWhenEveryAssetHasKnownBytes	PhotoCleanupMVETests/SnapshotInvariantTests.swift	160	C34-041, C34-096, C34-098
testSnapshotUsesLowerBoundModeWhenAnyAssetIsUnavailable	PhotoCleanupMVETests/SnapshotInvariantTests.swift	175	C34-041, C34-096, C34-097, C34-098
testSnapshotRemainsImmutableAfterCacheReceivesAnotherResult	PhotoCleanupMVETests/SnapshotInvariantTests.swift	190	C34-092, C34-105
testFrozenSnapshotPreventsLaterMutationOfD	PhotoCleanupMVETests/SnapshotInvariantTests.swift	206	C34-092
testSecondFreezeIsRejectedAndOriginalSnapshotIsKept	PhotoCleanupMVETests/SnapshotInvariantTests.swift	221	C34-092
testLargeCompletedSelectionCanBeFrozenWithoutTruncation	PhotoCleanupMVETests/SnapshotInvariantTests.swift	234	C34-094, C34-095, C34-101
testAll115TransitionCellsAndEveryUnreachableCombination	PhotoCleanupMVETests/TransitionTableGuardTests.swift	24	C34-065, C34-066, C34-067, C34-068, C34-070, C34-071, C34-072, C34-074, C34-075, C34-076, C34-079, C34-080, C34-083, C34-084, C34-087, C34-088, C34-089, C34-091, C34-171, C34-172, C34-173, C34-174, C34-175, C34-176, C34-182, C34-188, C34-191, C34-192, C34-193, C34-194, C34-197, C34-198, C34-199, C34-200, C34-203, C34-204, C34-205, C34-206, C5-092, C5-093, C5-094, C5-095, C5-097, C5-098, C5-099, C5-100, C5-102, C5-103, C5-104, C5-105, C5-106, C5-108, C5-109, C5-110, C5-111, C5-112, C5-115, C5-116, C5-118, C5-119, C5-121, C5-126, C5-131
testZeroBytesDisplaysAsZeroDecimalMegabytes	PhotoCleanupMVETests/VolumeFormattingTests.swift	5	—
testBelowOneGigabyteUsesWholeDecimalMegabytes	PhotoCleanupMVETests/VolumeFormattingTests.swift	9	—
testMegabytesAlwaysTruncateInsteadOfRoundingUp	PhotoCleanupMVETests/VolumeFormattingTests.swift	16	—
testExactlyOneGigabyteUsesOneDecimalPlace	PhotoCleanupMVETests/VolumeFormattingTests.swift	23	—
testGigabytesAlwaysTruncateAtOneDecimalPlace	PhotoCleanupMVETests/VolumeFormattingTests.swift	30	—
testLargeGigabyteValueKeepsOneTruncatedDecimalPlace	PhotoCleanupMVETests/VolumeFormattingTests.swift	37	—
```
<!-- 反向映射结束 -->

## 五、未覆盖清单

<!-- 未覆盖清单开始 -->
| 条款编号 | 规格位置 | 判定理由 |
|---|---|---|
| C34-007 | `SPEC-S3-S4-20260812.v6.md:27` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-008 | `SPEC-S3-S4-20260812.v6.md:28` | 该方法只断言状态机保留完整去重集合，未断言确认页逐项显示。 |
| C34-009 | `SPEC-S3-S4-20260812.v6.md:29` | 该方法只断言收藏项不影响扫描与提交，未断言缩略图、标识内容和收藏标记的页面呈现。 |
| C34-010 | `SPEC-S3-S4-20260812.v6.md:30` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-011 | `SPEC-S3-S4-20260812.v6.md:31` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-022 | `SPEC-S3-S4-20260812.v6.md:47` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-023 | `SPEC-S3-S4-20260812.v6.md:48` | 方法只断言状态机资产集合和收藏项提交资格，未断言扫描中页面完整呈现。 |
| C34-024 | `SPEC-S3-S4-20260812.v6.md:49` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-026 | `SPEC-S3-S4-20260812.v6.md:54` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-032 | `SPEC-S3-S4-20260812.v6.md:63` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-039 | `SPEC-S3-S4-20260812.v6.md:78` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-040 | `SPEC-S3-S4-20260812.v6.md:79` | 方法只断言状态机资产集合和收藏项提交资格，未断言就绪页面完整呈现。 |
| C34-041 | `SPEC-S3-S4-20260812.v6.md:80` | 方法只断言冻结快照的体积模式，未断言就绪页面的 L2 显示。 |
| C34-042 | `SPEC-S3-S4-20260812.v6.md:84` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-048 | `SPEC-S3-S4-20260812.v6.md:93` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-055 | `SPEC-S3-S4-20260812.v6.md:108` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-093 | `SPEC-S3-S4-20260812.v6.md:147` | 方法断言提交标识被写入并拒绝重复使用，但未直接证明生成值全局唯一，也未断言字段在目标 S5 接收时结束。 |
| C34-094 | `SPEC-S3-S4-20260812.v6.md:148` | 方法断言有序、唯一、非空及冻结值，但未直接断言字段在目标 S5 接收时结束。 |
| C34-095 | `SPEC-S3-S4-20260812.v6.md:149` | 方法断言资产数量与集合长度相等，但未直接断言字段在目标 S5 接收时结束。 |
| C34-096 | `SPEC-S3-S4-20260812.v6.md:150` | 方法断言非负即时求和值及冻结值，但未直接断言字段在目标 S5 接收时结束。 |
| C34-097 | `SPEC-S3-S4-20260812.v6.md:151` | 方法断言不可用项计数及冻结值，但未直接断言字段在目标 S5 接收时结束。 |
| C34-098 | `SPEC-S3-S4-20260812.v6.md:152` | 方法断言两种枚举及派生条件，但未直接断言字段在目标 S5 接收时结束。 |
| C34-099 | `SPEC-S3-S4-20260812.v6.md:153` | 方法断言收藏集合冻结且不阻断提交，但未直接断言字段在目标 S5 接收时结束。 |
| C34-100 | `SPEC-S3-S4-20260812.v6.md:154` | 方法断言冻结时间值，但未直接断言字段在目标 S5 接收时结束。 |
| C34-101 | `SPEC-S3-S4-20260812.v6.md:156` | 方法直接断言两条冻结守卫并覆盖部分合法输入，但无法穷尽证明不存在第三类冻结校验。 |
| C34-107 | `SPEC-S3-S4-20260812.v6.md:191` | 方法只断言计时状态，未断言执行页的不确定活动指示、无单项进度、无比例及无预计时间。 |
| C34-112 | `SPEC-S3-S4-20260812.v6.md:201` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-113 | `SPEC-S3-S4-20260812.v6.md:202` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-117 | `SPEC-S3-S4-20260812.v6.md:212` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-126 | `SPEC-S3-S4-20260812.v6.md:234` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-129 | `SPEC-S3-S4-20260812.v6.md:243` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-131 | `SPEC-S3-S4-20260812.v6.md:245` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-132 | `SPEC-S3-S4-20260812.v6.md:246` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-138 | `SPEC-S3-S4-20260812.v6.md:260` | 方法断言成功终态模型，未断言执行页呈现终态标识。 |
| C34-139 | `SPEC-S3-S4-20260812.v6.md:261` | 方法断言成功集合等于提交集合，未断言页面显示的两个数量。 |
| C34-147 | `SPEC-S3-S4-20260812.v6.md:283` | 方法断言失败终态模型，未断言执行页呈现终态标识。 |
| C34-148 | `SPEC-S3-S4-20260812.v6.md:284` | 方法断言三个集合被保存，未断言页面显示各集合数量。 |
| C34-149 | `SPEC-S3-S4-20260812.v6.md:285` | 方法断言空失败原因被拒绝，未断言页面呈现非空失败原因。 |
| C34-154 | `SPEC-S3-S4-20260812.v6.md:296` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-159 | `SPEC-S3-S4-20260812.v6.md:309` | 未发现直接断言该条款的 XCTest 方法。 |
| C34-160 | `SPEC-S3-S4-20260812.v6.md:310` | 方法断言两种未知原因状态，未断言页面显示触发原因。 |
| C34-161 | `SPEC-S3-S4-20260812.v6.md:311` | 方法断言未知终态与计时停止，未断言活动指示区域及页面措辞。 |
| C34-168 | `SPEC-S3-S4-20260812.v6.md:327` | 方法分别断言未知终态被终止时保留及未闭合提交终止后可交接，但未直接覆盖已持久化 S4-E3 在重启后继续交接。 |
| C34-230 | `SPEC-S3-S4-20260812.v6.md:381` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-017 | `SPEC-S5-20260812.v5.md:36` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-019 | `SPEC-S5-20260812.v5.md:147` | 方法断言成功集合等于原提交集合，未断言页面 L1 文案和三个计数的呈现。 |
| C5-020 | `SPEC-S5-20260812.v5.md:148` | 方法证明快照随成功上下文持久化，未断言页面按第二节显示 L2。 |
| C5-021 | `SPEC-S5-20260812.v5.md:149` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-022 | `SPEC-S5-20260812.v5.md:150` | 方法断言用户点击前不显示 L3，但未断言等待系统操作说明的页面文案。 |
| C5-023 | `SPEC-S5-20260812.v5.md:151` | 方法断言首次进入只读取并持久化一次基线，未断言页面只显示取得状态且隐藏读数本身。 |
| C5-026 | `SPEC-S5-20260812.v5.md:154` | 方法断言离开事件可用，未断言页面显示离开操作。 |
| C5-027 | `SPEC-S5-20260812.v5.md:158` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-028 | `SPEC-S5-20260812.v5.md:159` | 方法断言单次读取、状态留存与按钮状态，但未直接断言形成页面展示结论。 |
| C5-033 | `SPEC-S5-20260812.v5.md:167` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-035 | `SPEC-S5-20260812.v5.md:172` | 方法断言声明时间、完成读数和差值持久化并留在原状态，但未直接断言形成页面展示结论。 |
| C5-042 | `SPEC-S5-20260812.v5.md:184` | 方法断言取消分类为 A、B 空且 C 等于 P，未断言页面 L1 文案呈现。 |
| C5-043 | `SPEC-S5-20260812.v5.md:185` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-044 | `SPEC-S5-20260812.v5.md:186` | 方法断言返回确认页事件可用，未断言页面显示主操作。 |
| C5-047 | `SPEC-S5-20260812.v5.md:192` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-049 | `SPEC-S5-20260812.v5.md:197` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-059 | `SPEC-S5-20260812.v5.md:215` | 方法断言三个集合原样进入失败上下文，未断言页面 L1 文案与计数呈现。 |
| C5-060 | `SPEC-S5-20260812.v5.md:216` | 方法断言失败原因非空且保留底层字段，未断言页面详情呈现。 |
| C5-061 | `SPEC-S5-20260812.v5.md:217` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-063 | `SPEC-S5-20260812.v5.md:219` | 方法断言返回确认页事件可用，未断言页面显示主操作。 |
| C5-065 | `SPEC-S5-20260812.v5.md:224` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-067 | `SPEC-S5-20260812.v5.md:229` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-076 | `SPEC-S5-20260812.v5.md:246` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-077 | `SPEC-S5-20260812.v5.md:247` | 方法断言未知原因模型，未断言页面显示触发原因。 |
| C5-078 | `SPEC-S5-20260812.v5.md:248` | 方法断言未知状态不构造三个集合，未断言页面 L1 文案与数值隐藏。 |
| C5-079 | `SPEC-S5-20260812.v5.md:249` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-080 | `SPEC-S5-20260812.v5.md:250` | 未发现直接断言该条款的 XCTest 方法。 |
| C5-083 | `SPEC-S5-20260812.v5.md:256` | 未发现直接断言该条款的 XCTest 方法。 |
<!-- 未覆盖清单结束 -->

## 六、不适用清单

<!-- 不适用清单开始 -->
| 条款编号 | 规格位置 | 判定理由 |
|---|---|---|
| C34-005 | `SPEC-S3-S4-20260812.v6.md:25` | 该条款为纯视觉 |
| C34-006 | `SPEC-S3-S4-20260812.v6.md:26` | MVE 范围外 |
| C34-012 | `SPEC-S3-S4-20260812.v6.md:32` | MVE 范围外 |
| C34-021 | `SPEC-S3-S4-20260812.v6.md:46` | MVE 范围外 |
| C34-025 | `SPEC-S3-S4-20260812.v6.md:50` | 该条款为纯视觉 |
| C34-029 | `SPEC-S3-S4-20260812.v6.md:57` | MVE 范围外 |
| C34-037 | `SPEC-S3-S4-20260812.v6.md:71` | MVE 范围外 |
| C34-038 | `SPEC-S3-S4-20260812.v6.md:77` | MVE 范围外 |
| C34-046 | `SPEC-S3-S4-20260812.v6.md:88` | MVE 范围外 |
| C34-052 | `SPEC-S3-S4-20260812.v6.md:100` | 实现约束比规格更强，该路径在当前实现下不可达 |
| C34-053 | `SPEC-S3-S4-20260812.v6.md:101` | MVE 范围外 |
| C34-054 | `SPEC-S3-S4-20260812.v6.md:107` | MVE 范围外 |
| C34-056 | `SPEC-S3-S4-20260812.v6.md:109` | 该条款为纯文案 |
| C34-057 | `SPEC-S3-S4-20260812.v6.md:113` | MVE 范围外 |
| C34-062 | `SPEC-S3-S4-20260812.v6.md:124` | MVE 范围外 |
| C34-063 | `SPEC-S3-S4-20260812.v6.md:125` | MVE 范围外 |
| C34-090 | `SPEC-S3-S4-20260812.v6.md:139` | 可达单元格（事件“点击提交” × 起始状态“S3-2 就绪”）：实现约束比规格更强，该路径在当前实现下不可达 |
| C34-110 | `SPEC-S3-S4-20260812.v6.md:199` | 该条款为纯文案 |
| C34-111 | `SPEC-S3-S4-20260812.v6.md:200` | 该条款为纯视觉 |
| C34-124 | `SPEC-S3-S4-20260812.v6.md:232` | 该条款为纯文案 |
| C34-125 | `SPEC-S3-S4-20260812.v6.md:233` | 该条款为纯视觉 |
| C34-127 | `SPEC-S3-S4-20260812.v6.md:235` | 该条款为纯文案 |
| C34-140 | `SPEC-S3-S4-20260812.v6.md:262` | 该条款为纯视觉 |
| C34-150 | `SPEC-S3-S4-20260812.v6.md:286` | 该条款为纯视觉 |
| C34-158 | `SPEC-S3-S4-20260812.v6.md:308` | 该条款为纯文案 |
| C5-006 | `SPEC-S5-20260812.v5.md:23` | MVE 范围外 |
| C5-016 | `SPEC-S5-20260812.v5.md:35` | MVE 范围外 |
| C5-018 | `SPEC-S5-20260812.v5.md:146` | 该条款为纯文案 |
| C5-024 | `SPEC-S5-20260812.v5.md:152` | 该条款为未定项阻断 |
| C5-040 | `SPEC-S5-20260812.v5.md:182` | 该条款为纯文案 |
| C5-041 | `SPEC-S5-20260812.v5.md:183` | 该条款为纯文案 |
| C5-058 | `SPEC-S5-20260812.v5.md:214` | 该条款为纯文案 |
| C5-062 | `SPEC-S5-20260812.v5.md:218` | 该条款为纯文案 |
| C5-075 | `SPEC-S5-20260812.v5.md:245` | 该条款为纯文案 |
| C5-081 | `SPEC-S5-20260812.v5.md:251` | 该条款为纯文案 |
| C5-117 | `SPEC-S5-20260812.v5.md:305` | 可达单元格（事件“用户离开页面” × 起始状态“S5-T0”）：MVE 范围外 |
| C5-120 | `SPEC-S5-20260812.v5.md:305` | 可达单元格（事件“用户离开页面” × 起始状态“S5-U”）：MVE 范围外 |
| C5-144 | `SPEC-S5-20260812.v5.md:333` | MVE 范围外 |
| C5-145 | `SPEC-S5-20260812.v5.md:334` | MVE 范围外 |
<!-- 不适用清单结束 -->

## 七、未命中测试清单

<!-- 未命中测试清单开始 -->
| XCTest 方法名 | 测试位置 |
|---|---|
| `testStartPersistenceFailurePreventsMachineCreation` | `PhotoCleanupMVETests/S4StateMachineTests.swift:439` |
| `testLifecyclePersistenceFailureLeavesStateUnchanged` | `PhotoCleanupMVETests/S5StateMachineTests.swift:613` |
| `testZeroBytesDisplaysAsZeroDecimalMegabytes` | `PhotoCleanupMVETests/VolumeFormattingTests.swift:5` |
| `testBelowOneGigabyteUsesWholeDecimalMegabytes` | `PhotoCleanupMVETests/VolumeFormattingTests.swift:9` |
| `testMegabytesAlwaysTruncateInsteadOfRoundingUp` | `PhotoCleanupMVETests/VolumeFormattingTests.swift:16` |
| `testExactlyOneGigabyteUsesOneDecimalPlace` | `PhotoCleanupMVETests/VolumeFormattingTests.swift:23` |
| `testGigabytesAlwaysTruncateAtOneDecimalPlace` | `PhotoCleanupMVETests/VolumeFormattingTests.swift:30` |
| `testLargeGigabyteValueKeepsOneTruncatedDecimalPlace` | `PhotoCleanupMVETests/VolumeFormattingTests.swift:37` |
<!-- 未命中测试清单结束 -->
