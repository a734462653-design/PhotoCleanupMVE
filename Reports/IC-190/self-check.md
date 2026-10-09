# IC-190 自验报告

## 一、结论（先行）

- **四个子项全部按卡面完成（逐字节拷入 `ic190/stages/`，未手改一行），G1045～G1049 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-190-retire-legacy`：A `e1b69bdb22bd3f9132cd8b66de40f2c90cc01e9a` → B `e74b883cb8fbbcf888284c96a904f2a94c2134e9` → C `a988ab9b846fa9c3f71b45398722c66826067572` → D `78134e11462732e075b89b29c0478d4900453712`。
- 分支 CI **#384**（run `37891189446`）一次绿：**966 项 0 失败**（963 − 2 + 5），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 1994392 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `8ce8c48a11f6ac9ad249eece4d5ac77833e71218`（双亲 `e2bee969a368ce6caf4eeefe0dd4be4664539264`／`78134e11462732e075b89b29c0478d4900453712`，树 `b726ce9604187fd661206fa3b7cd8c06ff0769e8` 与 D 提交的树相同）。合并后 `main` CI **#385**（run `37892239657`）绿：966 项 0 失败，artifact `PhotoCleanupMVE-unsigned-8ce8c48a11f6`（id `11599446263`，有效期至 2027-01-07T06:11:19Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（共 15 + 16 + 1 + 2 个）、卡面 A、B「改后」计数与工作树实测逐条相等（A 段 21 条加产品残留文件扫描 2 条；B 段 7 条加残留扫描 3 条，同时重数 A 段 21 条；0 处不符）；提交后 `check_ic190.py` A／B／C／D 四个 tip 全 PASS。
- 本次没有停卡项，没有执行端偏离卡面的改动，没有被分类器拦截，没有中途中断。`sim_ic190.py` 与 `materialize_ic190.py` 都没有跑（前者卡面允许对基线跑、非必需；后者明令不跑），`Tasks/decision-tools/` 内未新增或覆盖任何文件。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261008-190-retire-legacy.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-190.md`；调研 `Tasks/RESEARCH-S1R-2d-retire-legacy-facts.md`（全文）；九条裁定 `Tasks/PLAN-S1R-2d-rulings-20261008.md`；复核 `Tasks/REVIEW-IC-190-findings.md` 第三、四节（两轮处置）。
- 基线 `main` = `e2bee969a368ce6caf4eeefe0dd4be4664539264`（IC-189 合并后的 `main`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 3bf92f22822ccc4850a996ae5a87bbb639c24d38 main` 退出码 0；`git ls-remote origin refs/heads/main` = `e2bee969a368ce6caf4eeefe0dd4be4664539264`（与本地一致）；被改 22 个文件基线 blob 与卡面表逐一相等（下表）；**先切分支再改文件**（`git switch -c feature/ic-190-retire-legacy`）。

| 路径 | 卡面基线 blob | 实测（HEAD 与工作树 `git hash-object`） |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `1fc842b8290b65c6886f9f3b5e40ba97231e7650` | 相等 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `9274c11c821de5fcaa483cc89c5532e73f142645` | 相等 |
| `PhotoCleanupMVE/Core/S1LegacyProgressMigration.swift` | `10839f915450a1798a5d03424d51c6b86c56acbf` | 相等 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `94c5cee676af7e84e38dbc12b2d76f2569436fda` | 相等 |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | `2ecdc5c8e8e0110f3d8afbd5a8fe17d73274656e` | 相等 |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | `9464a81223faef9c1eea31cd7d2b4a73544d6ad5` | 相等 |
| `PhotoCleanupMVE/Core/SessionStore.swift` | `c902447ce8422a7f65e6a36c92e1827eeca42e9a` | 相等 |
| `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | `e7d9ac06d578b322ef8f07353f695d82f7ff91f4` | 相等 |
| `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | `719fcfe4f07417302376d59b616610bc04802bdc` | 相等 |
| `PhotoCleanupMVETests/IC131S1WriteBackToastTests.swift` | `2b60a876094c6b799759321e2a6dcfdf4bab7aea` | 相等 |
| `PhotoCleanupMVETests/IC132S1RangeNamePersistenceTests.swift` | `8b0ac681cb707ad01828fbd4bde27ccca772cf5f` | 相等 |
| `PhotoCleanupMVETests/IC132SubmissionDeadEndTests.swift` | `4df363615b9bdad8a1dfabfaae7505d39ec19ded` | 相等 |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | `6c314da0aaf76b4fd23f9103f4b22e82e93650c6` | 相等 |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | `ccbe0a3bf99e0e351494414f908c5997e87e8886` | 相等 |
| `PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift` | `adaa2e10700afc84ec6c6d0c986c17908769f804` | 相等 |
| `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | `144d4d96341a3a27f4ef80eb6e6d76e8c386f9c8` | 相等 |
| `PhotoCleanupMVETests/IC169MarkedStateFollowsBasketTests.swift` | `fc353710400e256b57f0d3ea81667c267cb30174` | 相等 |
| `PhotoCleanupMVETests/IC187SeenArchiveTests.swift` | `30c0dfb20fbb17adcda0499654ce2abdc997b8f5` | 相等 |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `95a0eee8af2750c17a30fd043cbdfae229dac514` | 相等 |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | `ff0b511873d35cfa004dcb5f16aa201ea84c2853` | 相等 |
| `PhotoCleanupMVETests/S2StateMachineTests.swift` | `b6290bfb2eec5be8d2086c4a9cf358e4b12d447a` | 相等 |
| `PhotoCleanupMVETests/SessionStoreTests.swift` | `7bb23d64b61a5c4b962d182f45cb26732126f571` | 相等 |

- 范围边界：只做卡「本卡边界」四项（A 会话层退役、B 返回契约、C 两个旧测试改名、D 新测试 + pbx）。`Core/S1SeenArchive.swift`、任何视图、App 入口、目录 `Localizable.xcstrings`（blob 与基线相等，`check_ic190.py` 的 `catalog blob unchanged` PASS）、`Scripts/`（含两个已作废的 verify 脚本）、`.github/`、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）一字未动。
- 改法实施方式：`cp -r Tasks/decision-tools/ic190/stages/<子项>/. <repo>/`，每个子项拷入后对清单里该子项每个文件跑 `git hash-object`（脚本 `scratchpad/ic190-exec/stage_check.py`，读清单与工作树，只读），全部相等才 `git add` 与提交。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `e1b69bdb22bd3f9132cd8b66de40f2c90cc01e9a` | `73926352eb64055b40e70b7a703e5cb7ac6b67b5` | 会话层退役：`Continuation` 只留 `currentAssetID`、`K` 不钳制、旧进度由快照 `legacyProgressByRangeID` 单独携带到第一次采用范围、`SessionStore.processedAssetIDs` 删除并内联进迁移、磁盘旧键改可选；钳制两条测试重写、`testIC043_006`／`_007` 整删（15 个文件） |
| B | `e74b883cb8fbbcf888284c96a904f2a94c2134e9` | `7d5e26ab07bb6708490fa50808fca1e86e28b351` | 返回契约：`S2Return.farthestAssetID` → `seenAssetIDs: Set<AssetID>`（写回校验为 `A` 的子集）、S2 状态机删 `farthestIndex`／`farthestAssetID`、载荷交 `visitSeenAssetIDs`、协调器写回成功后从载荷取（16 个文件；依赖 A） |
| C | `a988ab9b846fa9c3f71b45398722c66826067572` | `24811d502eb1fc3cabd4f25db698d23507522832` | `S1StateMachineTests` 两个旧测试改名（1 个文件） |
| D | `78134e11462732e075b89b29c0478d4900453712` | `b726ce9604187fd661206fa3b7cd8c06ff0769e8` | 新测试 `IC190LegacyRetirementTests.swift`（五条，逐字节拷入）+ pbx 四行（2 个文件；依赖 A、B） |
| 合并 | `8ce8c48a11f6ac9ad249eece4d5ac77833e71218` | `b726ce9604187fd661206fa3b7cd8c06ff0769e8` | `merge(IC-190): 退役 p_范围／O_记录／farthestAssetID——K 只留 c、旧进度单独带到第一次采用范围、返回契约改本次看过集合、K 不钳制` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-190/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --name-only e2bee969a368ce6caf4eeefe0dd4be4664539264..78134e11462732e075b89b29c0478d4900453712` 恰 23 路径，全在白名单内。分支推送一次成功（无分类器拦截，git 直连无需代理）；推 `main` 一次成功（`e2bee96..8ce8c48`）。

## 四、逐子项提交前对读与拷入文件 `git hash-object`

脚本 `scratchpad/ic190-exec/stage_check.py`：读工作树文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（`Tasks/decision-tools/strip.py` 的算法，脚本内联一份拷贝，未向 `decision-tools/` 写入任何东西），逐条数卡面「改后」段列出的计数。每个子项都是提交前跑、全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后用 `git rev-parse <提交>:<路径>` 再核一遍，结果同表）：

| 子项 | 仓库路径 | 清单／卡面 blob | 提交内 blob（`rev-parse <提交>:<路径>`） | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `7651fa4205187e15bbeab0193206500dd70c9167` | `7651fa4205187e15bbeab0193206500dd70c9167` | 相等 |
| A | `PhotoCleanupMVE/Core/S1LegacyProgressMigration.swift` | `c6773ca5082b1f09e02da1282bcbbb7402191e01` | `c6773ca5082b1f09e02da1282bcbbb7402191e01` | 相等 |
| A | `PhotoCleanupMVE/Core/S1StateMachine.swift` | `f0ddd930adcaf1f99b0af1808c925309622be9e4` | `f0ddd930adcaf1f99b0af1808c925309622be9e4` | 相等 |
| A | `PhotoCleanupMVE/Core/SessionPersistence.swift` | `2e89af947060ea5c0461a2d96afd41fee34fdddc` | `2e89af947060ea5c0461a2d96afd41fee34fdddc` | 相等 |
| A | `PhotoCleanupMVE/Core/SessionStore.swift` | `efaef5dda5dbb179d36fce5e897bfb91fbe30789` | `efaef5dda5dbb179d36fce5e897bfb91fbe30789` | 相等 |
| A | `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | `9e34f6b16e0d440b642798340f4c881793fae533` | `9e34f6b16e0d440b642798340f4c881793fae533` | 相等 |
| A | `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | `5df456b3c9044ee69d518f694ae58d212b3322fe` | `5df456b3c9044ee69d518f694ae58d212b3322fe` | 相等 |
| A | `PhotoCleanupMVETests/IC131S1WriteBackToastTests.swift` | `77f410ab53d209b6da096738afa808c6d79dff98` | `77f410ab53d209b6da096738afa808c6d79dff98` | 相等 |
| A | `PhotoCleanupMVETests/IC132S1RangeNamePersistenceTests.swift` | `a4cde66fc93146d00931415bc00eba6f45a0f658` | `a4cde66fc93146d00931415bc00eba6f45a0f658` | 相等 |
| A | `PhotoCleanupMVETests/IC132SubmissionDeadEndTests.swift` | `9bde740098f0924bda8c34cf4fae08302e8ae7fd` | `9bde740098f0924bda8c34cf4fae08302e8ae7fd` | 相等 |
| A | `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | `a93b3efa5aba00727a33bdf5c24af8ba1f855855` | `a93b3efa5aba00727a33bdf5c24af8ba1f855855` | 相等 |
| A | `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | `a22d33256f6eb9bfb43a6b856a447bb14a124c5b` | `a22d33256f6eb9bfb43a6b856a447bb14a124c5b` | 相等 |
| A | `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `0dc62335d4930deb850fff2a4a75827929dde7ef` | `0dc62335d4930deb850fff2a4a75827929dde7ef` | 相等 |
| A | `PhotoCleanupMVETests/S1StateMachineTests.swift` | `27e510918771009daebfca5e649ef27ec80a816c` | `27e510918771009daebfca5e649ef27ec80a816c` | 相等 |
| A | `PhotoCleanupMVETests/SessionStoreTests.swift` | `9b2b70016eed4e7b05cd0e59f5d9a26d0a6bda50` | `9b2b70016eed4e7b05cd0e59f5d9a26d0a6bda50` | 相等 |
| B | `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `55f599914c2096fa614b5a7ae78e9f7b22452f26` | `55f599914c2096fa614b5a7ae78e9f7b22452f26` | 相等 |
| B | `PhotoCleanupMVE/Core/S2StateMachine.swift` | `93885fb9ee540e9595fe701630f009dd1b724d89` | `93885fb9ee540e9595fe701630f009dd1b724d89` | 相等 |
| B | `PhotoCleanupMVE/Core/SessionStore.swift` | `671a4630146b2f6cbce6123c6d6bf34149c6eabe` | `671a4630146b2f6cbce6123c6d6bf34149c6eabe` | 相等 |
| B | `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | `710209ce6e2c1916db024c44e2fd813b523de264` | `710209ce6e2c1916db024c44e2fd813b523de264` | 相等 |
| B | `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | `a3f4cb8d1fd56a81d7dee2d1988c2c1b10d5c86b` | `a3f4cb8d1fd56a81d7dee2d1988c2c1b10d5c86b` | 相等 |
| B | `PhotoCleanupMVETests/IC131S1WriteBackToastTests.swift` | `bb967927c1bcfd6a0e53f02267670f1f90d93649` | `bb967927c1bcfd6a0e53f02267670f1f90d93649` | 相等 |
| B | `PhotoCleanupMVETests/IC132SubmissionDeadEndTests.swift` | `d56a8b05d498757fa4595ca16a8be82e4192dfdf` | `d56a8b05d498757fa4595ca16a8be82e4192dfdf` | 相等 |
| B | `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | `497dfbf2a890eb0a2498d00a29dd4e944d048031` | `497dfbf2a890eb0a2498d00a29dd4e944d048031` | 相等 |
| B | `PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift` | `7cb0301ceb2b99624964f4e6af061f9049009f7d` | `7cb0301ceb2b99624964f4e6af061f9049009f7d` | 相等 |
| B | `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | `53fd4c93ad4c563ba9444bf79e378276f68e1886` | `53fd4c93ad4c563ba9444bf79e378276f68e1886` | 相等 |
| B | `PhotoCleanupMVETests/IC169MarkedStateFollowsBasketTests.swift` | `813cb6ceeca46a2914cc81a40b932eeff7df9543` | `813cb6ceeca46a2914cc81a40b932eeff7df9543` | 相等 |
| B | `PhotoCleanupMVETests/IC187SeenArchiveTests.swift` | `2ce334504252c34b47cdff6cbeefe9e241a4074e` | `2ce334504252c34b47cdff6cbeefe9e241a4074e` | 相等 |
| B | `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `9023acfd2c5a40d1d813a23d4d7fd358140fa0d5` | `9023acfd2c5a40d1d813a23d4d7fd358140fa0d5` | 相等 |
| B | `PhotoCleanupMVETests/S1StateMachineTests.swift` | `b67c940465510d28a75d98c934c67dbea07c264f` | `b67c940465510d28a75d98c934c67dbea07c264f` | 相等 |
| B | `PhotoCleanupMVETests/S2StateMachineTests.swift` | `0255924a3aefdb7b37268f37075ede4538462c31` | `0255924a3aefdb7b37268f37075ede4538462c31` | 相等 |
| B | `PhotoCleanupMVETests/SessionStoreTests.swift` | `053016b1762742319369b7d8779f912c57c1ead6` | `053016b1762742319369b7d8779f912c57c1ead6` | 相等 |
| C | `PhotoCleanupMVETests/S1StateMachineTests.swift` | `a692c1ebbe35a2b89296ae68c7b24037ef4a0560` | `a692c1ebbe35a2b89296ae68c7b24037ef4a0560` | 相等 |
| D | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `13feab7d6d13d2e855ebeb590af209b32326ac66` | `13feab7d6d13d2e855ebeb590af209b32326ac66` | 相等 |
| D | `PhotoCleanupMVETests/IC190LegacyRetirementTests.swift` | `6fb64711861ba5d09310e0f11d252b41e21d42fd` | `6fb64711861ba5d09310e0f11d252b41e21d42fd` | 相等 |

**A 子项「改后」**（卡面值 / 实测值；0 处不符）：

| 计数 | 卡面 | 实测 |
|---|---|---|
| `SessionStore` `Continuation` 切片 `let ` | 1 | 1 |
| `SessionStore` `func processedAssetIDs(` | 0 | 0 |
| `SessionStore` `reconcileRange` 切片 `continuationsByRangeID` | 0 | 0 |
| 状态机 `var legacyProgressMigration: ((_ ranges: [S1Range], _ groupingDimension: S1GroupingDimension, _ legacyProgress: [String: S1LegacyProgress]) -> Void)?` | 1 | 1 |
| 状态机 `legacyProgressMigration?(newRanges, groupingDimension, legacyProgressByRangeID)` | 1 | 1 |
| 状态机 `legacyProgressByRangeID = [:]` | 1 | 1 |
| `adoptRanges` 切片内先后：交出调用 < 清空 < `Self.reconciledStore(sessionStore, against: newRanges)` | 成立 | 成立 |
| 状态机 `machine.legacyProgressByRangeID = snapshot.legacyProgressByRangeID` | 1 | 1 |
| 状态机 `publishSnapshotIfChanged()`／`didSet`／`setMarked(`／`seenAssetIDsProvider?() ?? []` | 6／4／3／3 | 6／4／3／3 |
| 协调器 `from legacyProgress: [String: S1LegacyProgress]` | 1 | 1 |
| 协调器 `if !migrated.isEmpty {`（IC-188 原写法不变） | 1 | 1 |
| 协调器 `migrateLegacyProgressIfNeeded(`／`adoptedDimension: groupingDimension`／`flushSeenArchive()` | 2／1／4 | 2／1／4 |
| 迁移文件 `import ` | 1 | 1 |
| 迁移文件剔注释 `S0`／`farthestIndex`／`processedAssetIDs(` | 0／0／0 | 0／0／0 |
| 产品剔注释 `recordedSortOrder` 所在文件 | 迁移文件、会话档 | 迁移文件、会话档 |

**B 子项「改后」**（含 A 段全部仍成立项重数；0 处不符）：

| 计数 | 卡面 | 实测 |
|---|---|---|
| `SessionStore` `let seenAssetIDs: Set<AssetID>` | 1 | 1 |
| `SessionStore` `returned.seenAssetIDs.isSubset(of: assetIDSet)` | 1 | 1 |
| S2 状态机 `seenAssetIDs: visitSeenAssetIDs` | 1 | 1 |
| S2 状态机 `farthestIndex` | 0 | 0 |
| 协调器 `recordSeenAssets(payload.upstreamReturn.seenAssetIDs)` | 1 | 1 |
| 协调器 `recordSeenAssets(`／`flushSeenArchive()` | 4／4 | 4／4 |
| 产品剔注释 `farthestAssetID`／`recordedSortOrder` 所在文件 | 只在 `SessionPersistence.swift` 与 `S1LegacyProgressMigration.swift` | 同（全产品 `.swift` 递归扫描）；`farthestIndex` 全产品合计 0 |

**C 子项**：拷入文件 blob 与清单相等，`git diff --cached` 仅两个函数名与各自上方注释共 5 行增／5 行删；**D 子项**：新测试 blob 与清单相等，`func test` 恰 5 条（`testIC190A`～`E`），pbx 新增 4 行（见第十二节）。

## 五、`check_ic190.py` 四段 SUMMARY（提交后、进入下一子项之前对刚提交的 tip 跑，退出码 0；FAIL 行：无）

基线用脚本默认值（`e2bee96`），在 `Tasks/decision-tools/` 下 `python -B check_ic190.py <tip> <段>` 对原仓读 git 对象（tip 取自 `git rev-parse HEAD` 经 `tr -d '\r'`）。

| 段 | tip | SUMMARY |
|---|---|---|
| A | `e1b69bdb22bd3f9132cd8b66de40f2c90cc01e9a` | 18 pass / 18（15 个 blob + 路径集合 + ancestor + catalog） |
| B | `e74b883cb8fbbcf888284c96a904f2a94c2134e9` | 24 pass / 24（21 + 3） |
| C | `a988ab9b846fa9c3f71b45398722c66826067572` | 24 pass / 24（21 + 3） |
| D | `78134e11462732e075b89b29c0478d4900453712` | 26 pass / 26（23 + 3） |

`docs` 段在 docs 提交后补跑（docs 提交的 SHA 无法写进自己，结果在回传给决策会话的回报里给出）。

## 六、本地门禁（四个提交各跑一次，贴真实退出码）

| 提交 | `git diff --cached --check` | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` |
|---|---|---|---|
| A | 0 | 0 | 0 |
| B | 0 | 0 | 0 |
| C | 0 | 0 | 0 |
| D | 0 | 0 | 0 |

（`git diff --cached --check` 在 `git add` 之后、提交之前跑；两个 `.ps1` 经 PowerShell 工具 `powershell -NoProfile -ExecutionPolicy Bypass -File` 调用、读 `$LASTEXITCODE`；四次的末行都是：selfcheck「结构自验通过」、扫描器「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致」。）

## 七、验收门禁逐条（G1045～G1049）

| 门禁 | 结果 |
|---|---|
| **G1045**（`check_ic190.py` 在 A～D 四个 tip 上全 PASS） | 满足，见第五节 |
| **G1046**（五条 `testIC190*` passed；十六个点名测试类全部 passed） | 满足，见第九节 |
| **G1047**（`IC188SeenSwitchTests.testIC188D_CoordinatorMigratesOnceBeforeClamp` 与 `FullFlowRoutingTests.testIC048_006S5ExitEndsSessionAndRebuildsS1Session` passed） | 满足（#384、#385 的唯一 Test Case 行均 passed，耗时 0.003 s／0.013 s 与 0.003 s／0.016 s） |
| **G1048**（合并前置） | 满足：G1045～G1047 + CI 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice；摘要 notice 与 xcodebuild 小计一致，均为 966，无需按第 217 条第四节另核）+ 三十五条被保护分支 tip 未变（第十一节）+ pbxproj 撞号扫描（第十二节）+ 工作树净 + 合并前远端 `main` 仍为 `e2bee969a368ce6caf4eeefe0dd4be4664539264`（未被他人推进）。合并首行与卡面一致 |
| **G1049**（合并后 `main` 运行绿，报告记 artifact 名称／id／有效期） | 满足，见第八节 |

## 八、CI

| 项 | 分支 #384 | 合并后 `main` #385 |
|---|---|---|
| run id | `37891189446` | `37892239657` |
| 被测提交 | `78134e11462732e075b89b29c0478d4900453712` | `8ce8c48a11f6ac9ad249eece4d5ac77833e71218` |
| 结论 | success（作业 12 步全 success，第 9 步「运行 XCTest」success） | success（12 步全 success） |
| XCTest | 966 项、0 失败（整包日志「运行 XCTest」步骤唯一 Test Case 行 966 passed／0 failed；xcodebuild 小计 `Executed 966 tests, with 0 failures (0 unexpected) in 47.310 (49.308) seconds`） | 966 项、0 失败（唯一 Test Case 行 966 passed／0 failed；小计 `Executed 966 tests, with 0 failures (0 unexpected) in 45.535 (46.431) seconds`） |
| 摘要 notice | `Executed 966 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 966 tests / 0 failures`（与小计一致） | 同 |
| 真实退出码 | 「运行 XCTest」步骤 success、日志 `** TEST SUCCEEDED **`（脚本 `exit "$test_status"` 原样退出 = 0） | 同 |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一 id、`OS:26.2, name:iPhone 16` |
| IPA | 文件 `PhotoCleanupMVE-unsigned.ipa`，字节数 1994392，SHA-256 `95498afdd150a71fd07c774a50edd08b60fe56bc72e306058d3f159004acbfdd` | 字节数 1994392，SHA-256 `37bb2cbc0faee42181386ebccf8246e9d1678775e8cca02f0e14c97bd6569e8a`（IPA 不可复现，同树两次 SHA 不同属预期） |
| 分段耗时 notice 原文 | `模拟器启动 82 s；xcodebuild test 303 s；总 387 s` | `模拟器启动 67 s；xcodebuild test 301 s；总 368 s` |
| artifact（G1049） | `PhotoCleanupMVE-unsigned-78134e114627`，id `11598414479`，size 1994562，有效期至 2027-01-07T05:59:10Z | **`PhotoCleanupMVE-unsigned-8ce8c48a11f6`，id `11599446263`，size 1994562，未过期，有效期至 2027-01-07T06:11:19Z** |

- 两次日志里各有两行 `Errors found! Invalidating cache...`（陷阱 26 的模拟器着色器缓存失效行），都紧跟在 `IC175SimilarRecognizerTests.testIC175C_ObservationArchiveRoundTripKeepsDistanceZero`（Vision 观测归档用例）开始之后（#384：06:05:18；#385：06:16:32），**早于**第一条 `testIC063…` 用例的开始行（步骤日志里先后次序已核），整包日志里 `building pipeline` 0 条；`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 两次都 passed（6.205 s／6.180 s）。本卡未红。
- 日志取得方式：`gh api repos/…/actions/runs/<id>/logs` 整包 zip，`zipfile` 读取并 `testzip` 校验，各一次成功；唯一 Test Case 行按「运行 XCTest」步骤日志（`9_运行 XCTest.txt`）去重统计，两次都是 966 条 passed、0 条 failed。

## 九、五条新断言与随改的既有断言

**五条新断言**（`IC190LegacyRetirementTests`，`Test Case` 行耗时）：

| 函数 | 内容 | #384 | #385 |
|---|---|---|---|
| `testIC190A_ArchiveCarriesLegacyProgressSeparately` | 旧档两键同在 → `K` 只留 `c`、旧进度单独带出；只有 `c` 的新档无旧进度；只有一个旧键、排序值非法、最远为空 → 坏档；无旧进度的快照写出不带两个旧键；有旧进度往返相等 | 0.005 s | 0.003 s |
| `testIC190B_MachineCarriesLegacyUntilFirstAdopt` | 恢复后、第一次采用之前（含切排序）快照带旧进度、迁移入口未被调；第一次采用：入口恰收到旧进度、之后快照为空、`K` 只留 `c`；再对账：入口收到空表 | 0.001 s | 0.001 s |
| `testIC190C_PersistedArchiveDropsLegacyKeysAfterFirstAdopt`（`@MainActor`） | 隔离持久层预存旧档；协调器恢复后切排序、类别页进篮两个入口写出的档仍带旧进度；采用之后迁移得 `{a4, a3}`、置标记，写出的档不带旧进度 | 0.004 s | 0.004 s |
| `testIC190D_ReturnContractValidatesSeenSetAndKeepsOnlyCurrent` | 看过集合含范围外资产 → 写回失败、`K` 未写；空集合合法 → `K` 只记 `c`；对账不钳 `K`、不算改动 | 0.001 s | 0.001 s |
| `testIC190E_SourceWiring` | 子项 A、B「改后」的计数与先后（含既有钉子），产品里旧字段只剩两个文件 | 0.188 s | 0.193 s |

**G1046 点名的十六个既有测试类**（#384 与 #385 的唯一 Test Case 行 passed／failed，两次相同）：`SessionStoreTests` 12／0、`S1StateMachineTests` 20／0、`AlbumScopeWiringTests` 7／0、`FullFlowRoutingTests` 6／0、`IC131S1WriteBackToastTests` 5／0、`IC132S1RangeNamePersistenceTests` 4／0、`IC132SubmissionDeadEndTests` 5／0、`IC147S0BehaviorTests` 16／0、`IC157LongPressIntoS2Tests` 8／0、`IC163DeckPreviewRoundTwoTests` 6／0、`IC168FallbackDiagnosticsTests` 6／0、`IC169MarkedStateFollowsBasketTests` 6／0、`IC187SeenArchiveTests` 4／0、`IC188SeenSwitchTests` 6／0、`IC189NewCountTests` 5／0、`S2StateMachineTests` 52／0。

**整删、改写改名、改名的既有测试**（`git diff e2bee96..78134e1` 的 `func test` 增删行实证）：

| 动作 | 测试 |
|---|---|
| 整删（2） | `SessionStoreTests.testIC043_006ProcessedAssetsUsePrefixWhenSortOrderMatchesRecord`、`SessionStoreTests.testIC043_007ProcessedAssetsUseSuffixWhenSortOrderFlips`（`SessionStoreTests` 14 → 12 条；日志里两名均不存在） |
| 改写并改名（1） | `AlbumScopeWiringTests.testIC127C_ContinuationIsClampedToLastAvailableAsset` → `testIC127C_ContinuationIsNotClampedByReconciliation`（对账 `reconcileRange` 返回 false、`K` 与整个 store 不变；`M` 里已不存在的资产照旧剔除并算改动） |
| 改名（2） | `S1StateMachineTests.testIC046_010ProcessedAssetsUsePrefixWhenOrdersMatch` → `testIC046_010ProcessedAssetsAreSeenSetIntersection`；`testIC046_011ProcessedAssetsUseSuffixWhenOrderFlips` → `testIC046_011ProcessedAssetsIgnoreSortOrder`（子项 C） |

**随改的既有断言**（均按卡面，没有卡外改动）：

| 位置 | 旧 → 新 |
|---|---|
| `SessionStoreTests.testIC043_010…`（末段） | 删 `processedAssetIDs(…).isEmpty` 一段，前三条断言保留 |
| `SessionStoreTests.testIC043_011…`（六个非法返回） | 第 5 个由 `farthestAssetID: "资产-范围外"` 改 `seenAssetIDs: ["资产-范围外"]`（仍非法，仍是 6 个） |
| `SessionStoreTests.testIC043_012…` 与 `FullFlowRoutingTests.testIC048_003`、`IC131…B_Successful…`、`IC132SubmissionDeadEndTests`、`IC147S0BehaviorTests`、`IC157LongPressIntoS2Tests`、`S1StateMachineTests.testIC046_017…` | `K` 期望由三参 `Continuation(c, p, O)` 收为 `Continuation(currentAssetID:)`；IC157 一处注释同改 |
| `AlbumScopeWiringTests.testIC127C_ReconciliationIsIdempotent` | `K` 期望 `(a3, a3, newestFirst)` → `Continuation(currentAssetID: "a2")`（`c` 不钳） |
| `S1StateMachineTests.testIC046_005…`／`_006…` | 删 `recordedSortOrder` 前后比对两段 |
| `IC132S1RangeNamePersistenceTests.testIC132A_LegacyArchive…` | `K` 期望收为一参，另加旧进度断言（`legacyProgressByRangeID == ["相册-1": S1LegacyProgress(farthestAssetID: "资产-A", recordedSortOrder: .oldestFirst)]`） |
| `IC188SeenSwitchTests` C／D／F | 迁移夹具由 `legacyStore`（`SessionStore`）换 `legacyProgress()`（旧进度表）；D 的快照构造带 `legacyProgressByRangeID`；F 的签名与调用原文 needle 随改 |
| 载荷断言（B，三处） | `FullFlowRoutingTests.testIC048_003`：`farthestAssetID == "资产-A"` → `seenAssetIDs == ["资产-A", "资产-B", "资产-C"]`；`testIC048_004`：`"资产-B"` → `["资产-B"]`；`S2StateMachineTests.testIC047_020`：`"asset-2"` → `["asset-2"]` |
| `S2Return(` 构造点（B） | 13 个测试文件里的 `farthestAssetID: x` → `seenAssetIDs: [x]`（含 IC131／IC132D／IC168／IC187 四个重构造 helper 改抄新字段） |

**项数对账式：`963 − 2 + 5 = 966`**（#384／#385 唯一 Test Case 行 966；摘要与小计 966；本机 `^\s*func\s+test` 基线 963、HEAD 966，仅作差值预估）。

## 十、摘取关系实测

克隆：`git clone --no-hardlinks D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE <scratchpad>/ic190-exec/clone`，克隆成功（退出码 0）后才开始；所有命令带 `git -C <克隆>`；克隆里每个单元先 `switch --detach e2bee969a368ce6caf4eeefe0dd4be4664539264` 再建 `pick-*` 分支，原仓没有建任何其它分支。克隆内为 `cherry-pick -x` 配了仅克隆可见的占位提交身份（`git -C <克隆> config`，未动原仓配置）。

| 单元 | 命令 | 退出码 | 结果树 |
|---|---|---|---|
| A 单独 | `cherry-pick -x A` | 0 | `73926352eb64055b40e70b7a703e5cb7ac6b67b5`（= A 提交的树，改动 15 路径） |
| A→B 连续 | `cherry-pick -x A B` | 0、0 | `7d5e26ab07bb6708490fa50808fca1e86e28b351`（= B 提交的树，改动 21 路径） |
| C 单独 | `cherry-pick -x C` | 0 | `00d6b70bf8790345452acc791881687b915d1c72`（仅克隆内存在；改动 1 路径，证明文本上不依赖 A、B） |
| A→B→C→D 连续 | `cherry-pick -x A B C D` | 0、0、0、0 | `b726ce9604187fd661206fa3b7cd8c06ff0769e8`（= D 提交的树 = 合并提交的树，改动 23 路径） |

克隆实测只证文本无冲突；绿由 CI 证（#384 是 A→B→C→D 连续序列的绿，C 单独与 A 单独的绿未单独跑 CI）。

## 十一、G1048 被保护分支核对

`Tasks/decision-tools/ic190_protected_branches.txt`（35 行 `分支名 SHA`、无注释行，只读）对 `git ls-remote --heads origin` 逐条比对：**推送分支之后第一次核：checked 35、mismatch 0**（远端 109 个分支，含本卡分支，`main` 仍为 `e2bee969a368ce6caf4eeefe0dd4be4664539264`）；**合并前再核一次：checked 35、mismatch 0**（`main` 仍为 `e2bee969a368ce6caf4eeefe0dd4be4664539264`、本卡分支为 `78134e11462732e075b89b29c0478d4900453712`）。三条冻结分支与其余被保护分支 tip 均未变。

## 十二、pbxproj 撞号扫描与两个新 id

- 对象定义行（`24 位 id /* … */ = {isa`）去重扫描：重复 0。
- 两个新 id 出现次数：`10000000000000000000008F` 3（fileRef：定义 + 组 children + buildFile 引用）、`20000000000000000000008C` 2（buildFile：定义 + 源码阶段），与 IC-189 同构；基线上两个 id 出现 0 次；改前最大号分别为 `…8E`／`…8B`。
- `git diff --cached --check` 四个提交均 0。

## 十三、规格欠账（卡面六条，本卡不改任何规格）

1. SPEC-S1 v12 `:253` 末句「迁移完成后……下一次写出时丢弃」——落实为「第一次采用范围、旧进度交给迁移入口之后的那次写出丢弃」（迁移入口调过即算；迁移有内容立即写看过档、无内容只置内存标记，见裁定 三）。
2. 拆卡计划 S3 返回落点卡裁定 2「对账带来的 `K` 钳制照旧」改读为「`K` 不钳，`c` 不在 `A` 中由使用方回退」（裁定 一）。
3. `Scripts/verify-IC-20260814-043.ps1`／`-046.ps1` 已作废未删（裁定 七；本卡未动、未运行）。
4. `S1StateMachine.processedAssetIDs(for:)`／`S1RangeRow.processedAssetCount` 名字保留、含义自 IC-188 起为「已看」（裁定 八）。
5. SPEC-S1 v12 `:74` 同一条里括注「`K[r].c_范围` 不再钳制」与正文后半「`c_范围`／`p_范围` 钳到 `O_记录` 顺序下的末位」互相矛盾——正文后半句待删（`:248`／`:300`／未定项 18 与括注一致）。
6. IC-188 卡规格欠账 (4)「`K` 不再钳制与代码不符」与 (5)「坏档重迁把 `farthestAssetID` 当看过」由本卡结清，(3)「迁移之前就被清档的路径上的旧 `K` 不迁」仍开放（行为不变）。

## 十四、人工判定项

无（纯重构，无界面变化）。

## 十五、docs 提交与最终核验

- docs 提交只含 `Reports/IC-190/self-check.md` 与 `Reports/IC-190/change-list.md`（惯例 44：合并与合并后 `main` 运行之后追加，纯 `Reports/**` 提交不触发 CI，预期行为）。
- docs 提交前已对本报告与 `change-list.md` 出现的全部 40 位 SHA 跑 `git cat-file -e <sha>^{<类型>}`，结果见 `change-list.md` 末节「核验结果」；docs 提交之后补跑 `check_ic190.py <docs 提交> docs`，结果在回传的回报里给出（docs 提交自身的 SHA 不写进报告）。

## 十六、发现但未处理的问题（按纪律只报告不修）

1. **降级注意（卡首已登记，复核 W4）**：本卡之后写出的会话档不带 `farthestAssetID`／`recordedSortOrder` 两个旧键，旧构建（#383 及更早）读它会按坏档清掉、待删篮丢失——装过本卡之后的包就不要回装更旧的包；合并后应写进待判清单与交接包（本卡不改 `Tasks/`）。
2. 两次日志的 `Errors found! Invalidating cache...` 行出现在 `IC175SimilarRecognizerTests.testIC175C…` 用例块里，不在 `testIC063` 块内，`testIC063` 未红（见第八节），仅记录。
3. 本机 `core.autocrlf` 为 `true`，`.gitattributes` 对 `*.swift`／`*.pbxproj` 设 `eol=lf`；拷入文件 `git hash-object`（经清洗过滤）与清单逐一相等，未出现行尾转换问题。
4. 两个已作废 verify 脚本（`verify-IC-20260814-043.ps1`／`-046.ps1`）按卡面不动、不运行；它们在基线上本来就红（卡事实表）。
5. 分支推送、合并、合并推送均一次成功，未遇分类器拦截，也未遇 `schannel` 握手失败。
