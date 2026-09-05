# IC-127 变更清单：S1 数据与行为层——停卡回报（E、F 已落地于分支，未推送）

## 结论

**停卡回报，未合并、未推送、未跑 CI。** 子项 E（提交排序）与 F（清理占位登记）已各自独立提交在本地分支 `feature/ic-127-s1-behavior`；子项 A、B、C、D 因必须改动 G501 白名单外的 `Services/PhotoLibraryService.swift` 与 `App/CleanupCoordinator.swift` 而**未开工**，等待决策会话裁定授权范围（逐行清单见 `self-check.md`「范围冲突清单」）。`schemaVersion` 仍为 7；S2 相关代码零改动。

## 提交清单（feature/ic-127-s1-behavior，自 `main` `da44e59`，本地）

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `de1831c` | feat | E：`SessionStore.makeS3Submission(rangeOrder:orderedAssetIDsForRangeID:groupNameForRangeID:)` 新重载（按 `R(T)` 顺序 × 当前 `O`，稳定回退）；`S1StateMachine.makeS3Submission()` 改走该重载；`S1StateMachineTests` +2 条；`FullFlowRoutingTests.assertS3Contract` 期望顺序按定案更新 |
| 2 | `df53edf` | chore | F：`S1UndecidedItems` 删除 item01/02/03/04/08/09/11/13/14/14b/14c 共 11 项登记 |
| 3 | 本次 docs 提交 | docs | `Reports/IC-127/`（停卡回报） |

## 文件变更（对 `main`）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/SessionStore.swift` | +52：新增 `makeS3Submission(rangeOrder:orderedAssetIDsForRangeID:groupNameForRangeID:)`；既有 `makeS3Submission(groupNameForRangeID:)` 原样保留 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `makeS3Submission()` 改走新重载（`rangeOrder = visibleRanges.map(\.id)`，组内 `orderedAssetIDs(for: sortOrder)`）；`S1UndecidedItems` 删 11 项并加注释 |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | +2 测试：`testIC127E_SubmissionFollowsRangeOrderInRTAndCurrentSortOrder`、`testIC127E_GroupCountsStillSumToMergedDeletionCount` |
| `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | `assertS3Contract` 两处期望值：S3 资产顺序 `[资产-S, 资产-A, 资产-B]`、范围-1 组 `[资产-S, 资产-A]` |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `Services/PhotoLibraryService.swift`、`App/CleanupCoordinator.swift` | **零改动**（白名单外；A/C/D 与 B 接线的必经之地，见自验报告） |
| `Core/SessionPersistence.swift`、`Features/S1/S1View.swift` | 零改动（B/A 未开工） |
| `S1GroupingDimension`（仍四值）、`S1Range`（仍扁平） | 未动 |
| S2 全部代码、`S2CalibrationConfiguration`、`schemaVersion`（7） | 零改动 |
| 冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` | 未触碰 |
| `main`、远端任何分支 | 未推送、未合并 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / stash 操作 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增。`S1UndecidedItems` 登记项减少 11 项（F）。

## CI 运行登记

无（未推送）。
