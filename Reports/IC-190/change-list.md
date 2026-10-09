# IC-190 变更清单

任务卡：`Tasks/IC-20261008-190-retire-legacy.md`（S1 重设计批第四张 ②d——退役 `p_范围`／`O_记录`／`farthestAssetID`：A 会话层退役；B 返回契约；C 两个旧测试改名；D 五条新测试 + pbx 登记；纯重构，无界面变化）。
基线：`main` = `e2bee969a368ce6caf4eeefe0dd4be4664539264`。分支：`feature/ic-190-retire-legacy`。合并提交 `8ce8c48a11f6ac9ad249eece4d5ac77833e71218`。

## 一、提交（各自独立、按卡顺序 A → B → C → D）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `e1b69bdb22bd3f9132cd8b66de40f2c90cc01e9a` | `73926352eb64055b40e70b7a703e5cb7ac6b67b5` | `SessionStore`／`SessionPersistence`／`S1StateMachine`／`S1LegacyProgressMigration`／`CleanupCoordinator` + 10 个测试文件；可单独摘 |
| B | `e74b883cb8fbbcf888284c96a904f2a94c2134e9` | `7d5e26ab07bb6708490fa50808fca1e86e28b351` | `SessionStore`／`S2StateMachine`／`CleanupCoordinator` + 13 个测试文件；只能 A→B |
| C | `a988ab9b846fa9c3f71b45398722c66826067572` | `24811d502eb1fc3cabd4f25db698d23507522832` | `S1StateMachineTests` 两个函数名；可单独摘 |
| D | `78134e11462732e075b89b29c0478d4900453712` | `b726ce9604187fd661206fa3b7cd8c06ff0769e8` | 新文件 `IC190LegacyRetirementTests.swift`（逐字节拷入）+ pbx 四行；依赖 A、B |

合并提交树 `b726ce9604187fd661206fa3b7cd8c06ff0769e8` = D 提交的树，双亲 `e2bee969a368ce6caf4eeefe0dd4be4664539264`／`78134e11462732e075b89b29c0478d4900453712`。

## 二、逐文件（白名单 23 路径，`git diff --name-only e2bee969a368ce6caf4eeefe0dd4be4664539264..78134e11462732e075b89b29c0478d4900453712` 恰 23 行；增删行取自 `git diff --numstat`）

| 路径 | 子项 | 基线 blob | 合并后 blob | 增／删行 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | D | `1fc842b8290b65c6886f9f3b5e40ba97231e7650` | `13feab7d6d13d2e855ebeb590af209b32326ac66` | +4／−0 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | A／B | `9274c11c821de5fcaa483cc89c5532e73f142645` | `55f599914c2096fa614b5a7ae78e9f7b22452f26` | +10／−9 |
| `PhotoCleanupMVE/Core/S1LegacyProgressMigration.swift` | A | `10839f915450a1798a5d03424d51c6b86c56acbf` | `c6773ca5082b1f09e02da1282bcbbb7402191e01` | +21／−16 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | A | `94c5cee676af7e84e38dbc12b2d76f2569436fda` | `f0ddd930adcaf1f99b0af1808c925309622be9e4` | +23／−11 |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | B | `2ecdc5c8e8e0110f3d8afbd5a8fe17d73274656e` | `93885fb9ee540e9595fe701630f009dd1b724d89` | +1／−10 |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | A | `9464a81223faef9c1eea31cd7d2b4a73544d6ad5` | `2e89af947060ea5c0461a2d96afd41fee34fdddc` | +30／−16 |
| `PhotoCleanupMVE/Core/SessionStore.swift` | A／B | `c902447ce8422a7f65e6a36c92e1827eeca42e9a` | `671a4630146b2f6cbce6123c6d6bf34149c6eabe` | +10／−56 |
| `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | A／B | `e7d9ac06d578b322ef8f07353f695d82f7ff91f4` | `710209ce6e2c1916db024c44e2fd813b523de264` | +20／−41 |
| `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | A／B | `719fcfe4f07417302376d59b616610bc04802bdc` | `a3f4cb8d1fd56a81d7dee2d1988c2c1b10d5c86b` | +4／−6 |
| `PhotoCleanupMVETests/IC131S1WriteBackToastTests.swift` | A／B | `2b60a876094c6b799759321e2a6dcfdf4bab7aea` | `bb967927c1bcfd6a0e53f02267670f1f90d93649` | +2／−4 |
| `PhotoCleanupMVETests/IC132S1RangeNamePersistenceTests.swift` | A | `8b0ac681cb707ad01828fbd4bde27ccca772cf5f` | `a4cde66fc93146d00931415bc00eba6f45a0f658` | +6／−3 |
| `PhotoCleanupMVETests/IC132SubmissionDeadEndTests.swift` | A／B | `4df363615b9bdad8a1dfabfaae7505d39ec19ded` | `d56a8b05d498757fa4595ca16a8be82e4192dfdf` | +2／−4 |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | A | `6c314da0aaf76b4fd23f9103f4b22e82e93650c6` | `a93b3efa5aba00727a33bdf5c24af8ba1f855855` | +1／−3 |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | A／B | `ccbe0a3bf99e0e351494414f908c5997e87e8886` | `497dfbf2a890eb0a2498d00a29dd4e944d048031` | +4／−6 |
| `PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift` | B | `adaa2e10700afc84ec6c6d0c986c17908769f804` | `7cb0301ceb2b99624964f4e6af061f9049009f7d` | +4／−4 |
| `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | B | `144d4d96341a3a27f4ef80eb6e6d76e8c386f9c8` | `53fd4c93ad4c563ba9444bf79e378276f68e1886` | +1／−1 |
| `PhotoCleanupMVETests/IC169MarkedStateFollowsBasketTests.swift` | B | `fc353710400e256b57f0d3ea81667c267cb30174` | `813cb6ceeca46a2914cc81a40b932eeff7df9543` | +1／−1 |
| `PhotoCleanupMVETests/IC187SeenArchiveTests.swift` | B | `30c0dfb20fbb17adcda0499654ce2abdc997b8f5` | `2ce334504252c34b47cdff6cbeefe9e241a4074e` | +1／−1 |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | A／B | `95a0eee8af2750c17a30fd043cbdfae229dac514` | `9023acfd2c5a40d1d813a23d4d7fd358140fa0d5` | +25／−29 |
| `PhotoCleanupMVETests/IC190LegacyRetirementTests.swift` | D | —（新建） | `6fb64711861ba5d09310e0f11d252b41e21d42fd` | +329／−0 |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | A／B／C | `ff0b511873d35cfa004dcb5f16aa201ea84c2853` | `a692c1ebbe35a2b89296ae68c7b24037ef4a0560` | +9／−23 |
| `PhotoCleanupMVETests/S2StateMachineTests.swift` | B | `b6290bfb2eec5be8d2086c4a9cf358e4b12d447a` | `0255924a3aefdb7b37268f37075ede4538462c31` | +1／−1 |
| `PhotoCleanupMVETests/SessionStoreTests.swift` | A／B | `7bb23d64b61a5c4b962d182f45cb26732126f571` | `053016b1762742319369b7d8779f912c57c1ead6` | +9／−46 |

增删合计：+518／−291（23 个文件）。

## 三、新增符号与行为变化

| 符号／行为 | 位置 | 说明 |
|---|---|---|
| `S1LegacyProgress { farthestAssetID, recordedSortOrder }`（`Equatable, Sendable`） | `Core/S1LegacyProgressMigration.swift` | v11 旧进度值类型；只在会话档恢复到第一次采用范围之间存在 |
| `SessionStore.Continuation` 只留 `currentAssetID` | `Core/SessionStore.swift` | `K` 缩为 `{c_范围}`；`init?` 不再校最远 |
| `SessionStore.reconcileRange` 删 `K` 钳制 | 同上 | 只收敛 `M`（经 `setMarked(false)` 维护 `F`）；`K` 不钳 |
| `SessionStore.processedAssetIDs(for:orderedAssetIDs:currentSortOrder:)` 删除 | 同上 | 前缀逻辑内联进迁移 `migratedAssetIDs` |
| `SessionStore.S2Return.seenAssetIDs: Set<AssetID>`（取代 `farthestAssetID`） | 同上 | 同位置、合成逐成员构造、无默认值；`applyS2Return` 校验为 `seenAssetIDs ⊆ A`（失败即整份写回失败），写回只记 `c` |
| `PersistedS1Session.Continuation` 两个旧键改可选 | `Core/SessionPersistence.swift` | 读旧档照常；写新档不带键；两键同在才是旧进度，只有一个、排序非法、最远为空 → 坏档 |
| `S1SessionSnapshot.legacyProgressByRangeID`（带默认值 `[:]`） | `Core/S1StateMachine.swift` | 快照单独携带旧进度 |
| 状态机私有 `legacyProgressByRangeID`；`restore(from:)` 带入、`sessionSnapshot` 带出 | 同上 | 迁移之前的写盘照样带旧进度；`adoptRanges` 交给迁移入口后立即清空，此后快照不带、下一次写盘丢旧键 |
| `legacyProgressMigration` 第三形参 `SessionStore` → `[String: S1LegacyProgress]` | 同上与 `App/CleanupCoordinator.swift` | `migrateLegacyProgressIfNeeded(adopting:groupedBy:from:)` 形参随改；迁移输入 `dimensionsToRead(for:)`／`migratedAssetIDs(from:)` 改收旧进度表 |
| S2 `farthestIndex`（4 处写入）／`farthestAssetID` 删除；载荷交 `visitSeenAssetIDs` | `Core/S2StateMachine.swift` | 每次前进换页少一次 `objectWillChange`，无测试钉 |
| 协调器写回成功后 `recordSeenAssets(payload.upstreamReturn.seenAssetIDs)` | `App/CleanupCoordinator.swift` | 取自返回契约，不再直接读 S2 状态机；`recordSeenAssets(` 仍 4、`flushSeenArchive()` 仍 4 |

## 四、没有改动的东西（范围外，逐项核过）

`Core/S1SeenArchive.swift`、任何视图、App 入口、目录 `Localizable.xcstrings`、`Scripts/`（含两个已作废 verify 脚本）、`.github/`、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）、`S1StateMachine.processedAssetIDs(for:)`／`S1RangeRow.processedAssetCount`（保名）、SPEC 与 Decision_log。

## 五、占位值登记

无（无出厂值变更，`schemaVersion` 仍 7）。

## 六、摘取关系

可摘单元：A；A→B；C；全部（A→B→C→D）。B 用到 A 收窄后的 `Continuation` 与测试文件里 A 改过的块，只能 A→B；D 依赖 A、B。克隆实测（`--no-hardlinks`）A 单独、A→B 连续、C 单独、A→B→C→D 连续 `cherry-pick -x` 退出码均 0；结果树 A 单独 `73926352eb64055b40e70b7a703e5cb7ac6b67b5`、A→B `7d5e26ab07bb6708490fa50808fca1e86e28b351`、C 单独 `00d6b70bf8790345452acc791881687b915d1c72`（仅克隆内）、全部 `b726ce9604187fd661206fa3b7cd8c06ff0769e8`。

## 七、CI 与产物

| 运行 | run id | 被测提交 | 结果 |
|---|---|---|---|
| 分支 #384 | `37891189446` | `78134e11462732e075b89b29c0478d4900453712` | success，966／0，IPA 1994392 字节，SHA-256 `95498afdd150a71fd07c774a50edd08b60fe56bc72e306058d3f159004acbfdd`；artifact `PhotoCleanupMVE-unsigned-78134e114627`（id `11598414479`） |
| 合并后 `main` #385 | `37892239657` | `8ce8c48a11f6ac9ad249eece4d5ac77833e71218` | success，966／0，IPA 1994392 字节，SHA-256 `37bb2cbc0faee42181386ebccf8246e9d1678775e8cca02f0e14c97bd6569e8a`；artifact `PhotoCleanupMVE-unsigned-8ce8c48a11f6`（id `11599446263`，有效期至 2027-01-07T06:11:19Z） |

项数对账：`963 − 2 + 5 = 966`。

## 八、拷入文件 blob 与清单对读（提交内 blob = 清单值，逐文件）

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

## 九、新测试 id

pbx：`10000000000000000000008F`（fileRef）、`20000000000000000000008C`（buildFile），改前最大号 `…8E`／`…8B`。

## 核验结果

报告内全部 40 位 SHA 对 `git cat-file -e <sha>^{<类型>}` 的核验（类型取自 `git cat-file -t`；「克隆」指仅存在于 `--no-hardlinks` 克隆里的对象，即 C 单独摘取的结果树）：共 68 个，失败 0 个。

| SHA | 类型 | 所在 | 退出码 |
|---|---|---|---|
| `00d6b70bf8790345452acc791881687b915d1c72` | tree | 克隆 | 0 |
| `0255924a3aefdb7b37268f37075ede4538462c31` | blob | 原仓 | 0 |
| `053016b1762742319369b7d8779f912c57c1ead6` | blob | 原仓 | 0 |
| `0dc62335d4930deb850fff2a4a75827929dde7ef` | blob | 原仓 | 0 |
| `10839f915450a1798a5d03424d51c6b86c56acbf` | blob | 原仓 | 0 |
| `13feab7d6d13d2e855ebeb590af209b32326ac66` | blob | 原仓 | 0 |
| `144d4d96341a3a27f4ef80eb6e6d76e8c386f9c8` | blob | 原仓 | 0 |
| `1fc842b8290b65c6886f9f3b5e40ba97231e7650` | blob | 原仓 | 0 |
| `24811d502eb1fc3cabd4f25db698d23507522832` | tree | 原仓 | 0 |
| `27e510918771009daebfca5e649ef27ec80a816c` | blob | 原仓 | 0 |
| `2b60a876094c6b799759321e2a6dcfdf4bab7aea` | blob | 原仓 | 0 |
| `2ce334504252c34b47cdff6cbeefe9e241a4074e` | blob | 原仓 | 0 |
| `2e89af947060ea5c0461a2d96afd41fee34fdddc` | blob | 原仓 | 0 |
| `2ecdc5c8e8e0110f3d8afbd5a8fe17d73274656e` | blob | 原仓 | 0 |
| `30c0dfb20fbb17adcda0499654ce2abdc997b8f5` | blob | 原仓 | 0 |
| `3bf92f22822ccc4850a996ae5a87bbb639c24d38` | commit | 原仓 | 0 |
| `497dfbf2a890eb0a2498d00a29dd4e944d048031` | blob | 原仓 | 0 |
| `4df363615b9bdad8a1dfabfaae7505d39ec19ded` | blob | 原仓 | 0 |
| `53fd4c93ad4c563ba9444bf79e378276f68e1886` | blob | 原仓 | 0 |
| `55f599914c2096fa614b5a7ae78e9f7b22452f26` | blob | 原仓 | 0 |
| `5df456b3c9044ee69d518f694ae58d212b3322fe` | blob | 原仓 | 0 |
| `671a4630146b2f6cbce6123c6d6bf34149c6eabe` | blob | 原仓 | 0 |
| `6c314da0aaf76b4fd23f9103f4b22e82e93650c6` | blob | 原仓 | 0 |
| `6fb64711861ba5d09310e0f11d252b41e21d42fd` | blob | 原仓 | 0 |
| `710209ce6e2c1916db024c44e2fd813b523de264` | blob | 原仓 | 0 |
| `719fcfe4f07417302376d59b616610bc04802bdc` | blob | 原仓 | 0 |
| `73926352eb64055b40e70b7a703e5cb7ac6b67b5` | tree | 原仓 | 0 |
| `7651fa4205187e15bbeab0193206500dd70c9167` | blob | 原仓 | 0 |
| `77f410ab53d209b6da096738afa808c6d79dff98` | blob | 原仓 | 0 |
| `78134e11462732e075b89b29c0478d4900453712` | commit | 原仓 | 0 |
| `7bb23d64b61a5c4b962d182f45cb26732126f571` | blob | 原仓 | 0 |
| `7cb0301ceb2b99624964f4e6af061f9049009f7d` | blob | 原仓 | 0 |
| `7d5e26ab07bb6708490fa50808fca1e86e28b351` | tree | 原仓 | 0 |
| `813cb6ceeca46a2914cc81a40b932eeff7df9543` | blob | 原仓 | 0 |
| `8b0ac681cb707ad01828fbd4bde27ccca772cf5f` | blob | 原仓 | 0 |
| `8ce8c48a11f6ac9ad249eece4d5ac77833e71218` | commit | 原仓 | 0 |
| `9023acfd2c5a40d1d813a23d4d7fd358140fa0d5` | blob | 原仓 | 0 |
| `9274c11c821de5fcaa483cc89c5532e73f142645` | blob | 原仓 | 0 |
| `93885fb9ee540e9595fe701630f009dd1b724d89` | blob | 原仓 | 0 |
| `9464a81223faef9c1eea31cd7d2b4a73544d6ad5` | blob | 原仓 | 0 |
| `94c5cee676af7e84e38dbc12b2d76f2569436fda` | blob | 原仓 | 0 |
| `95a0eee8af2750c17a30fd043cbdfae229dac514` | blob | 原仓 | 0 |
| `9b2b70016eed4e7b05cd0e59f5d9a26d0a6bda50` | blob | 原仓 | 0 |
| `9bde740098f0924bda8c34cf4fae08302e8ae7fd` | blob | 原仓 | 0 |
| `9e34f6b16e0d440b642798340f4c881793fae533` | blob | 原仓 | 0 |
| `a22d33256f6eb9bfb43a6b856a447bb14a124c5b` | blob | 原仓 | 0 |
| `a3f4cb8d1fd56a81d7dee2d1988c2c1b10d5c86b` | blob | 原仓 | 0 |
| `a4cde66fc93146d00931415bc00eba6f45a0f658` | blob | 原仓 | 0 |
| `a692c1ebbe35a2b89296ae68c7b24037ef4a0560` | blob | 原仓 | 0 |
| `a93b3efa5aba00727a33bdf5c24af8ba1f855855` | blob | 原仓 | 0 |
| `a988ab9b846fa9c3f71b45398722c66826067572` | commit | 原仓 | 0 |
| `adaa2e10700afc84ec6c6d0c986c17908769f804` | blob | 原仓 | 0 |
| `b6290bfb2eec5be8d2086c4a9cf358e4b12d447a` | blob | 原仓 | 0 |
| `b67c940465510d28a75d98c934c67dbea07c264f` | blob | 原仓 | 0 |
| `b726ce9604187fd661206fa3b7cd8c06ff0769e8` | tree | 原仓 | 0 |
| `bb967927c1bcfd6a0e53f02267670f1f90d93649` | blob | 原仓 | 0 |
| `c6773ca5082b1f09e02da1282bcbbb7402191e01` | blob | 原仓 | 0 |
| `c902447ce8422a7f65e6a36c92e1827eeca42e9a` | blob | 原仓 | 0 |
| `ccbe0a3bf99e0e351494414f908c5997e87e8886` | blob | 原仓 | 0 |
| `d56a8b05d498757fa4595ca16a8be82e4192dfdf` | blob | 原仓 | 0 |
| `e1b69bdb22bd3f9132cd8b66de40f2c90cc01e9a` | commit | 原仓 | 0 |
| `e2bee969a368ce6caf4eeefe0dd4be4664539264` | commit | 原仓 | 0 |
| `e74b883cb8fbbcf888284c96a904f2a94c2134e9` | commit | 原仓 | 0 |
| `e7d9ac06d578b322ef8f07353f695d82f7ff91f4` | blob | 原仓 | 0 |
| `efaef5dda5dbb179d36fce5e897bfb91fbe30789` | blob | 原仓 | 0 |
| `f0ddd930adcaf1f99b0af1808c925309622be9e4` | blob | 原仓 | 0 |
| `fc353710400e256b57f0d3ea81667c267cb30174` | blob | 原仓 | 0 |
| `ff0b511873d35cfa004dcb5f16aa201ea84c2853` | blob | 原仓 | 0 |
