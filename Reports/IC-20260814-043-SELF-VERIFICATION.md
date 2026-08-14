# IC-20260814-043 自验报告

## 一、任务与当前结论

- 任务 ID：`IC-20260814-043-session-store-core`
- 任务基线：`cff06d109e8cf3d77c2238b1da3eb54bd009b3c0`
- 权威输入：`SPEC-S1-20260813.v3.md`
- 输入 SHA256：`F2565629CE6E9BD1ABB7C6841C73460C3E7E8F252A21A70D6E01893B87189238`

已新增纯逻辑的进程内会话层 `SessionStore`、独立测试文件和本卡自验脚本，并把两个 Swift 文件分别加入应用与单元测试源码阶段。实现未接入 `SessionPersistence`，未引入 PhotoKit、SwiftUI、UIKit、UI 类型、导航类型、第三方依赖或外部网络能力。

Windows 静态自验与 Git 范围检查已完成；当前机器没有 Swift 或 Xcode 工具链，运行态结果须由本次推送后的 macOS CI 取得。CI 结果待本次推送回填。

| 统计项 | 数量或结果 |
|---|---:|
| 基线 XCTest | 189 |
| 新增 XCTest | 14 |
| XCTest 总数 | 203 |
| 失败 | 待 CI |
| unexpected | 待 CI |

## 二、实现与规格对应

| 实现项 | 规格依据 | 实现证据 |
|---|---|---|
| `sessionID` | 第二节第 2 部分 | 构造时要求非空，存为只读稳定字符串。 |
| 范围级待删映射 `M` | 决策 1；第二节第 2 部分 | `pendingDeletionAssetIDsByRangeID`，值为范围内资产标识集合。 |
| 范围级续接映射 `K` | 第二节第 2 部分 | `continuationsByRangeID`，每项含 `currentAssetID`、`farthestAssetID`、`recordedSortOrder`。 |
| 跨范围归属映射 `F` | 决策 10；第二节第 2 部分 | `firstMarkedRangeIDByAssetID`，仅首次标记时写入，仍属于任一范围时不改写。 |
| `D_全部` | 第二节第 2、3 部分 | `allPendingDeletionAssetIDs` 每次由全部 `M[r]` 的并集实时派生，不持有分叉副本。 |
| 待删计数 | 第二节第 2 部分 | `pendingDeletionCount(for:)`；无键时为零。 |
| 已处理集合 | 决策 2；第二节第 2 部分 | `processedAssetIDs` 按当前排序是否等于记录排序分别取 `p` 及之前或 `p` 及之后。 |
| `分组(g)` | 决策 10；第二节第 2 部分 | `pendingDeletionGroupsByRangeID` 由当前 `D_全部` 与 `F` 派生，并断言组计数之和等于总数。 |
| 标记与取消标记 | 第二节共同不变量 | `setMarked` 在一个内部状态副本中同步更新 `M` 与 `F`，最后一次性替换状态。 |
| S2 返回写回 | SPEC-S1 v3 第七节第 2 部分五字段；任务 2b | `applyS2Return` 先校验会话、范围、`A`、`D`、`c`、`p` 与既有 `F`，失败不赋值；成功后一次性替换含 `M/K/F` 的状态。 |
| S3 返回交集更新 | 决策 11；第七节第 4 部分 | `applyS3Return` 校验会话与子集关系，对所有 `M[r]` 取交集并清理 `F`，最后一次性替换状态。 |
| S3 提交数据 | 决策 10；第七节第 3 部分 | `makeS3Submission` 形成稳定有序总表、来源范围分组、组名及各组资产数。 |

`M`、`K`、`F` 被封装在私有 `State` 值中。三类更新均先修改局部副本，全部校验通过后只执行一次 `state = nextState`，因此调用方不能观察到 `M` 已变而 `F` 或 `K` 尚未变的中间态。

规格未定项 8 尚未给出 S3 的产品排序依据。会话层仅按字符串标识符排序，以满足“稳定、可重算”的数据契约；这不定义任何 UI 排序含义。组名由调用方按范围标识提供，`SessionStore` 不持有或实现范围 UI。

## 三、编号专项 XCTest

| 编号 | XCTest 方法 | 直接断言与回指 |
|---|---|---|
| IC043-001 | `testIC043_001IntersectionReturnMakesUnionEqualReturnedSet` | 交集更新后 `D_全部` 恰等于 S3 返回集合；第七节第 4 部分。 |
| IC043-002 | `testIC043_002GroupCountsSumEqualsMergedDeletionCount` | 各分组资产数之和等于 `D_全部` 元素数；决策 10。 |
| IC043-003 | `testIC043_003FirstMarkedRangeRemainsSingleValued` | 同一资产后来被其他范围标记时，`F` 仍指向首次范围。 |
| IC043-004 | `testIC043_004FirstMarkedRangeKeyIsRemovedOnlyAfterEveryRangeUnmarks` | 资产仍在任一 `M[r]` 时保留 `F`，离开全部范围后删除键。 |
| IC043-005 | `testIC043_005DuplicateAcrossRangesCountsOnceGloballyAndOncePerRange` | 跨范围重复资产在全局只计一次，在两个范围各计一次。 |
| IC043-006 | `testIC043_006ProcessedAssetsUsePrefixWhenSortOrderMatchesRecord` | 当前 `O = O_记录` 时取 `p` 及之前。 |
| IC043-007 | `testIC043_007ProcessedAssetsUseSuffixWhenSortOrderFlips` | 当前 `O ≠ O_记录` 时取 `p` 及之后。 |
| IC043-008 | `testIC043_008EmptyS3ReturnClearsEveryPendingSetAndOwnershipKey` | S3 返回空集时，全部 `M[r]` 为空、`F` 与 `D_全部` 为空。 |
| IC043-009 | `testIC043_009AllEmptyRangeSetsProduceEmptyDerivedValues` | `M` 的值全为空集时，总集、分组和计数均为空。 |
| IC043-010 | `testIC043_010NeverEnteredRangeHasNoStoredStateAndEmptyDerivedValues` | 从未进入的范围无 `M/K` 键，待删计数为零、已处理集合为空。 |
| IC043-011 | `testIC043_011InvalidS2ReturnLeavesWholeStoreUnchanged` | 五字段或既有 `F` 校验失败时，完整会话状态保持原值。 |
| IC043-012 | `testIC043_012ValidS2ReturnAtomicallyWritesPendingSetAndContinuation` | 有效返回一次写回 `M`、`c`、`p`、`O_记录`，并清理失效 `F` 键。 |
| IC043-013 | `testIC043_013S3SubmissionContainsStablePartitionNamesAndCounts` | 提交包含稳定总表、组名、互斥分组及每组资产数。 |
| IC043-014 | `testIC043_014InvalidS3ReturnLeavesWholeStoreUnchanged` | 错误会话或非子集返回被拒绝，完整状态不变。 |

## 四、范围与保护证据

本卡允许改动路径被限定为以下五项：

1. `PhotoCleanupMVE.xcodeproj/project.pbxproj`
2. `PhotoCleanupMVE/Core/SessionStore.swift`
3. `PhotoCleanupMVETests/SessionStoreTests.swift`
4. `Scripts/verify-IC-20260814-043.ps1`
5. `Reports/IC-20260814-043-SELF-VERIFICATION.md`

工程文件只增加新源码和新测试的文件引用、分组引用及各一次源码阶段引用，没有改动 target、签名、权限、构建参数或依赖设置。

专项脚本逐个比较任务基线、当前 HEAD 和工作树中的下列受保护 Git blob：

- `CleanupCoordinator.swift`，其中包含 `CleanupRoute`；
- `S3StateMachine.swift`、`S4StateMachine.swift`、`S5StateMachine.swift`；
- 上述三个状态机的既有测试文件；
- `Features/` 下全部既有视图；
- `Info.plist`、`Localizable.xcstrings`；
- `.github/workflows/ci.yml`。

脚本还拒绝任何改动白名单外路径、第三方依赖声明、`PhotoCleanupGestureDemo` 路径、产品源码中的 PhotoKit、SwiftUI、UIKit、UI/导航类型和 `SessionPersistence` 引用。完成态会额外要求五个改动路径全部被 Git 追踪、工作树干净且无未跟踪条目。

## 五、自验脚本

提交前在 Windows 执行：

```powershell
& ./Scripts/verify-IC-20260814-043.ps1 -允许未提交交付物 -允许待回填CI
```

CI 回填后在干净工作树执行：

```powershell
& ./Scripts/verify-IC-20260814-043.ps1
```

在装有 Xcode 的 macOS 上，脚本会调用现有 `Scripts/test-xcode.sh` 运行全量 XCTest；Windows 无 Xcode 时，CI 前模式只执行静态、Git、规格与范围门禁，最终模式要求报告已经包含 CI 的全量 XCTest、Release 构建和未签名 IPA 证据。

## 六、执行结果与 CI 证据

| 项目 | 结果 |
|---|---|
| 规格摘要 | 已核对，实际值与任务卡一致。 |
| Windows 静态自验 | 通过；提交前模式执行 118 项检查，0 项失败，退出码 0。 |
| 全量 XCTest | CI 结果待本次推送回填。 |
| 失败 | 待 CI。 |
| unexpected | 待 CI。 |
| Release 构建 | CI 结果待本次推送回填。 |
| 未签名 IPA | CI 结果待本次推送回填。 |
| 受验提交 | CI 结果待本次推送回填。 |
| CI 运行 | CI 结果待本次推送回填。 |
| CI 链接 | CI 结果待本次推送回填。 |

## 七、阻塞与未定项

- 产品未定项 8 的 S3 排序依据未在本卡拍板；实现只提供稳定规范化顺序，不扩展到 UI。
- 产品未定项 11 的持久化范围未在本卡拍板；`SessionStore` 仅为进程内值，不接入任何持久化设施。
- 当前仓库的既有 CI 结构门禁仍固定在上一卡的 189 项测试与旧产品路径集合；本卡未修改受保护 CI 工作流。该兼容性需在首次 CI 结果中如实确认，不以绕过或删减新测试的方式处理。
