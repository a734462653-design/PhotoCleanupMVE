# IC-133 变更清单

分支：`feature/ic-133-s3-behavior`（自 `main` = `018fbeb` 切出）
被测提交：`7074f06f5f998f353a14d5b050f457d17915fedc`（分支 tip）
合并提交：**`be77fd0`**（`be77fd0b9df31b8fab19d6eed9ae5c2ef189b226`，`--no-ff` 入 `main`）
报告提交：本卡 docs 提交（`Reports/IC-133/` 两份），随合并留在 `main`

## 提交链

| 提交 | 内容 |
|---|---|
| `0bb3245` | **A**：`S3GroupPresentation` 空组即时消失、总数归零转空态 + 断言 1～4 + pbxproj 登记 |
| `6f022b3` | **B**：`S3HeaderSubtitle` 信息条口径、提示句改值 + 断言 5、6 |
| `74023c2` | **C**：`S3CancelAllAction` 全部取消二次确认 + 断言 7～9 |
| `7074f06` | fix（A）：断言 3 夹具名字改为码点降序（#259 唯一失败归因，仅改测试） |
| `be77fd0` | 合并提交（`--no-ff`） |

**cherry-pick 单位**：决策会话预先声明本卡以整组为单位，即 `0bb3245..7074f06` 四个提交一起取。

## 文件级变更（`018fbeb..7074f06`，4 文件 +580 −38）

| 文件 | +/− | 子项 | 变更 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S3/S3View.swift` | +195 −38 | A/B/C | 顶部新增三个展示口径类型；`ForEach` 改遍历 `presentation.groups`；`currentAssets(in:machine:)` 删除（并入 `S3GroupPresentation.make`）；`groupTitle` 改收 `S3GroupPresentation.Group`；信息条改 `S3HeaderSubtitle.text`；「全部取消」改 `request` + `.confirmationDialog`；其余 body（状态 Section、资产行、提交、返回、体积文案）未动 |
| `PhotoCleanupMVE/Localizable.xcstrings` | +42 −10 | B/C | −1 +3 改 1，见下 |
| `PhotoCleanupMVETests/IC133S3BehaviorTests.swift` | +377 | A/B/C | 新文件，9 项 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4 | A | 新测试文件四处登记（buildFile `…0038`，fileRef `…003B`） |

**零改动**（`git diff --stat` 为空）：`App/CleanupCoordinator.swift`、`Core/S3StateMachine.swift`、
`Features/S1`、`Features/S2`、`Features/S4`、`Features/S5`、`PhotoCleanupMVETests/S3StateMachineTests.swift`。

## 新增展示口径类型（IC-134 重写视图时保留）

| 类型 | 形状 |
|---|---|
| `S3GroupPresentation` | `struct`，`groups: [Group]`、`nonEmptyRangeCount`、`assetCount`；`static make(groups: [SessionStore.S3Submission.Group], currentAssets: [AssetDescriptor])`；`Group { sourceRangeID, name, orderedAssets: [AssetDescriptor], assetCount }` |
| `S3HeaderSubtitle` | `enum`，`static text(assetCount: Int, rangeCount: Int) -> String` |
| `S3CancelAllAction` | `struct`，`phase: Phase (.idle / .awaitingConfirmation)`、`isAwaitingConfirmation`；`static isAvailable(assetCount:isFrozen:)`；`mutating request(assetCount:isFrozen:) -> Bool`、`mutating dismiss()`、`mutating confirm(cancelAll: () -> Void) -> Bool` |

## 断言 → 测试函数对照（九条，#260 逐条 passed）

1. `testIC133A_RemovingWholeSecondGroupDropsItAndKeepsOthersInPlace`
2. `testIC133A_RemovingDownToLastAssetThenEmptyYieldsEmptyPresentation`
3. `testIC133A_OutputOrderFollowsInputOrderNotName`
4. `testIC133A_GroupCountsSumEqualsMachineAssetCountAtEveryStep`
5. `testIC133B_HeaderSubtitleTracksAssetCountAndNonEmptyRangeCount`
6. `testIC133B_HeaderSubtitleAndNoticeComeFromStringCatalog`（+ 扫描器）
7. `testIC133C_RequestEntersAwaitingConfirmationWithoutClearingAndDismissReturnsToIdle`
8. `testIC133C_ConfirmClearsExactlyOnceAndMachineBecomesEmpty`
9. `testIC133C_RequestIsRejectedWhenEmptyOrFrozen`

测试项数 656 → **665**（+9，全部在新文件）。

## xcstrings 增删改 key 清单

| 操作 | key | 值 |
|---|---|---|
| 删 | `s3.scope.source_summary.placeholder` | （原「本轮来自 {count} 个整理范围（当前范围说明文案待定）」） |
| 增 | `s3.chrome.subtitle_format` | `{count} 张 · 来自 {ranges} 个范围` |
| 增 | `s3.cancel_all.confirm.title` | `取消全部 {count} 张的待删标记？` |
| 增 | `s3.cancel_all.confirm.action` | 全部取消 |
| 改 | `s3.confirmation.recently_deleted_notice` | 「请最终确认以下照片将被移入系统「最近删除」」→「删除后会移入系统「最近删除」，30 天内可恢复。」 |

对话框的取消项用系统默认「取消」，未新增 key。String Catalog 由 208 → **210** 条目，
源码引用同为 210（扫描器实测一致）。

## 占位值登记

**无变更。** `S2Calibration.swift` 未改，`schemaVersion` 保持 **7**；`factoryPlaceholder` 登记制不变。

## 分支与冻结链状态（本地＝远端）

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `be77fd0` | 本卡推进（合并提交） |
| `feature/ic-133-s3-behavior` | `7074f06` | 保留在原 tip，未删除 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |

## CI（预算 2 次，用 2 次）

- **#259 红**（run id `34068853475`）：被测 `74023c2a6651c5a2447d1a4d06eac978b2f2061d`，退出码 65，
  665 项 1 失败（`testIC133A_OutputOrderFollowsInputOrderNotName`，夹具码点顺序错，产品无关）
- **#260 绿**（run id `34069301461`）：被测 `7074f06f5f998f353a14d5b050f457d17915fedc`，
  665 项 0 失败、退出码 0、摘要 notice 在位、目的地 `OS:26.2, name:iPhone 16`（`EADC2067-…`），
  IPA 1215198 字节，SHA-256 `5b861a625a77cf1bf6de50027637f56690ba34c293da169cacf85753a654e6f5`
- **G735 #261 绿**（run id `34070089413`）：被测 `be77fd0b9df31b8fab19d6eed9ae5c2ef189b226`，
  665 项 0 失败、退出码 0，IPA 1215198 字节，SHA-256
  `adfb52ee6b63c0f42bd8555d7aec97f139cecc6e814aad00c4cc4a44ee28916e`
- 本报告提交命中 `paths-ignore`，不触发 CI（预期）

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（`018fbeb..be77fd0`） | 0 |
