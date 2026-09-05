# IC-127 变更清单（v2 完整替换版）：S1 数据与行为层

## 结论

**已合并入 `main`。** 合并提交 `14476b9`（`14476b9131352f9bea9485f093d16f9f87aec4ba`），G505 运行 **#247** 绿（619/0，退出码 0）。修复运行 #246 在 iOS 26.2 / iPhone 16 上 619/0、退出码 0（主跑 #245 红为测试代码编译错误，1 行修复）。六个子项各自独立提交（A～D 按 hunk 归类，需整组挑取）；`schemaVersion` 仍为 7；S2 零改动。CI 预算用 2/3。

## 提交清单（feature/ic-127-s1-behavior，自 `main` `da44e59`）

| # | 提交 | 子项 | 类型 | 说明 |
|---|---|---|---|---|
| 1 | `de1831c` | E | feat | 提交排序 = 范围在 `R(T)` 中的顺序 × 当前 `O`（`SessionStore.makeS3Submission` 新重载；旧重载保留） |
| 2 | `df53edf` | F | chore | `S1UndecidedItems` 删 11 项登记 |
| 3 | `d63c056` | — | docs | 停卡回报（v1，保留在链上） |
| 4 | `895bdca` | A | feat | 三类维度；`S1Range.parentRangeID`；`PhotoLibraryService.dateRanges` 两级树；`visibleRanges` 树形 + `O` 双级翻转；展开／收起；读取校验年=月并集；`S1View` 最小适配；`s1.dimension.date` key |
| 5 | `721d211` | D | feat | `S1AuthorizationState` / `S1AuthorizationDispatch` / `S1FailureCategory` / `S1RangeReadResponse`；服务层先分派后读取，受限带标志；`isLimitedAuthorization`；`Reason.category`；删 `limitedAuthorizationPolicyUndecided` |
| 6 | `193b2c5` | C | feat | `SessionStore.reconcileRange`；`S1StateMachine.adoptRanges / reconcile(with:)`；协调器 `reconcileS1WithPhotoLibrary()` 接到 `leaveS2` / `enterConfirmationFromS2`；兜底计数 `s3SubmissionOrderingFallback` |
| 7 | `84e610e` | B | feat | `PersistedS1Session` + `s1-session.json`（save/load/clear）；`S1SessionSnapshot`；`persistenceSink` 单一写出口；`SessionStore` 失败式恢复初始化器；`S1StateMachine.restore(from:)`；协调器启动恢复、`finishSession` 清档、默认 `T=date` |
| 8 | `7aa9088` | — | test | 修 #245 编译错误：`AlbumScopeWiringTests` T7 `readS1Ranges(...).result.get()`（1 行） |
| 9 | `14476b9` | — | merge | `--no-ff` 合并 feature 入 `main` |
| 10 | 本次 docs 提交 | docs | `Reports/IC-127/` v2 完整替换版（沿 IC-124～126 先例，合并后落在 `main`，因需引用合并 SHA 与 G505 的 #247 编号） |

A～D 按 hunk 内容归类拆分，四者需整组 cherry-pick（详见自验报告「提交拆分说明」）。

## 文件变更（对 `main`）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | 全文重写级改动：`S1GroupingDimension` 三类（String rawValue）；`S1SortOrder` String rawValue；`S1Range` 加 `parentRangeID`；新增 `S1FailureCategory` / `S1AuthorizationState` / `S1AuthorizationDispatch` / `S1RangeReadResponse` / `S1SessionSnapshot`；`S1RangeReadFailure.Reason` 删 `limitedAuthorizationPolicyUndecided`、加 `category`；`S1RangeRow` 加 `parentRangeID` / `childCount` / `isExpanded`；`S1UndecidedItems` 删 11 项；状态机新增 `collapsedYearRangeIDs` / `isLimitedAuthorization` / `reconciliationCount` / `persistenceSink` / `restore(from:)` / `sessionSnapshot` / `topLevelRanges` / `childRanges(of:)` / `isYearExpanded` / `toggleYearExpansion` / `reconcile(with:)` / `s3SubmissionOrderingFallback()`；`visibleRanges` 树形；`completeRangeRead` 加 `isLimitedAuthorization:` 并经对账；`makeS3Submission` 走 E 重载；`areValid` 加树约束 |
| `PhotoCleanupMVE/Core/SessionStore.swift` | `SortOrder` String rawValue；新增失败式恢复 `init?(sessionID:pendingDeletionAssetIDsByRangeID:continuationsByRangeID:firstMarkedRangeIDByAssetID:)`、`reconcileRange(_:availableAssetIDsNewestFirst:)`、`S3SubmissionOrderingFallback` + `s3SubmissionOrderingFallback(...)`、`makeS3Submission(rangeOrder:...)` 重载（共用私有 `orderedGroups`）；既有 API 零改动 |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | 新增 `PersistedS1Session`（Codable）与 `SessionPersistence.saveS1Session / loadS1Session / clearS1Session`（独立文件 `s1-session.json`）；既有 `save / claim / load / clear` 零改动 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | `RangeReader` 返回 `S1RangeReadResponse`；Picker 遍历三类（`.date` 标题取 `s1.dimension.date`）；年节点行拆为展开按钮 + 进入按钮，月节点行内缩；读取回调传受限标志；预览夹具改两级树 |
| `PhotoCleanupMVE/Services/PhotoLibraryService.swift` | 仅 v2 点名区域：`s1Ranges` 族改为经 `s1RangeRead` 分派；授权映射改 `S1AuthorizationState` → `S1AuthorizationDispatch`（受限 = proceed）；`dateRanges` 两级树替代 `chronologicalRanges`；`chronologicalRangeID / DisplayName` 参数改层级 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 点名区域：夹具默认 `.date`；`readS1Ranges` 返回回应；`leaveS2` / `enterConfirmationFromS2` 加对账；新增 `enterS1(restoring:)` / `enterS1ResumingPersistedSessionOrStartNew()` / `reconcileS1WithPhotoLibrary()` / `installS1Session(_ machine:route:)`。区域外一行级接线：`prepareS1AfterAuthorizationRequest`（调恢复入口）、`installS1Session(_ store:route:)`（转调 machine 版）、`finishSession`（清 S1 档） |
| `PhotoCleanupMVE/Localizable.xcstrings` | **白名单外**：+`s1.dimension.date`（按日期），−`s1.dimension.month`、−`s1.dimension.year`（扫描门禁要求 key 与源码引用一致） |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | `.month`→`.date`、`.year`→`.album`；IC046-014 后半段改断言对账结果；+`testIC127E_*` ×2（v1）；+`S1DateTreeTests` 类（7 条） |
| `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | T5 改断言 date 树；+共享夹具 `IC127LibraryBox`；+`S1AuthorizationDispatchTests`（5 条）；+`S1ReconciliationTests`（6 条） |
| `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | `assertS3Contract` 期望顺序（v1）；+`S1SessionPersistenceTests`（6 条） |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift`、`S2ImageLoadingStateTests.swift` | 各 1 行：`readS1Ranges(groupedBy: .date).result.get()` |

新增测试 26 条（E 2、A 7、B 6、C 6、D 5）；总数 593 → 619。

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| S2 全部代码（`S2StateMachine`、`S2NativePhotoPager`、S2 视图、协调器 `s2*` 成员）、S3／S4／S5 路由与动作接线 | 零改动 |
| `S2CalibrationConfiguration` 字段与出厂值 | 零 diff；`schemaVersion` 仍为 **7** |
| `session.json` 的 `save / claim / load / clear` 语义 | 零改动（新档分文件） |
| `.github/workflows/ci.yml`、`Scripts/` | 零 diff |
| `project.pbxproj` | 零 diff（新测试并入既有文件） |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| `probe/*`、其余 `feature/ic-0xx-*` | 未触碰 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 / stash 操作 | 未执行（v1 的三个提交原样保留在链上） |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增。`S1UndecidedItems` 登记项减少 11 项（F）。新档默认值 `T=date`、`O=newestFirst` 为未定项 1 定案值，写在 `CleanupRouteConfiguration.ic048TemporaryWiringFixture`（非 `S2CalibrationConfiguration` 登记制）。

## CI 运行登记

| 运行 | 分支 | 被测提交 | 结论 | 真实退出码 | XCTest |
|---|---|---|---|---|---|
| #245（run 33965281120） | feature | `84e610e51f5347aabccb3f73a1cdbea78ffb46b6` | failure（测试代码编译错误） | 65 | 未执行 |
| #246（run 33965470925） | feature | `7aa9088bf6265967b433290e664e8be102a76a4e` | success | 0（步骤 success） | 619 项 0 失败（`Executed 619 tests, with 0 failures (0 unexpected) in 49.416 (90.649) seconds`） |
| #247（run 33965802644，合并后自动触发） | main | `14476b9131352f9bea9485f093d16f9f87aec4ba` | success（IPA 1100546 字节，SHA-256 `86347f8086c00179cce9dce9926f67284721c7a77021eb2836805865f97828a4`） | 0 | 619 项 0 失败 |
