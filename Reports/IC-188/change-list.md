# IC-188 变更清单

任务卡：`Tasks/IC-20261007-188-seen-switch.md`（S1 重设计批第二张（下）——S1 改用看过集合：A 测试隔离；B 已看派生量；C 进入位置；D 旧档迁移；E 新测试）。
基线：`main` = `0d46d371b1047919397c73cd8d06067d7dcb2b90`。分支：`feature/ic-188-seen-switch`。合并提交 `c3ae531e685904664e64f54e1ffe895108318204`。

## 一、提交（各自独立、按卡顺序 A → B → C → D → E）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `41758c8897d5f70abbb0c2405884f7d06d3da04f` | `af3bf19251a0a0664ec3ddb8923e3074d5668467` | 新文件 `TestPersistenceIsolation.swift`（逐字节拷入）+ 七个测试文件九处构造点 + pbx 四行（A10～A13）；可单独摘 |
| B | `f1c8aeb06dba114d48176737c02c6dbc097bef51` | `a471c3340493f8a1c3430110ef965ce93765ccec` | `S1StateMachine.swift` B1／B2、`CleanupCoordinator.swift` B3、`S1StateMachineTests.swift` B4～B6；可单独摘 |
| C | `42ae1af18a44394e0c1c9eaa8c442b1c16daf935` | `afec05aed253c9c3b92db02d7eea93a842a2596f` | `S1StateMachine.swift` C1／C2、`IC157LongPressIntoS2Tests.swift` C3／C4、`S1StateMachineTests.swift` C5、`IC187SeenArchiveTests.swift` C6；只能 A→B→C |
| D | `a5b49de5c36d1158734e2416dff964b0626f19e3` | `5371c1586aa09dea181beb6972a19b5872f9042f` | 新文件 `S1LegacyProgressMigration.swift`（逐字节拷入）+ `S1StateMachine.swift` D1／D2 + `CleanupCoordinator.swift` D3／D4 + `IC187SeenArchiveTests.swift` D5／D6 + pbx 四行（D7～D10）；按 A→B→C→D 摘 |
| E | `24b3cbd0c31cd7019be7f089523091dc61a8be5c` | `947e4b108f381495ea077d8a994efeab076a8130` | 新文件 `IC188SeenSwitchTests.swift`（逐字节拷入）+ pbx 四行（E1～E4）；依赖 A～D |

合并提交树 `947e4b108f381495ea077d8a994efeab076a8130` = E 提交的树，双亲 `0d46d371b1047919397c73cd8d06067d7dcb2b90`／`24b3cbd0c31cd7019be7f089523091dc61a8be5c`。

## 二、逐文件（白名单 15 路径，`git diff --name-only 0d46d37..24b3cbd` 恰 15 行；增删行取自 `git diff --numstat`）

| 路径 | 子项 | 基线 blob | E 提交 blob | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A／D／E | `c92d2568cb2be3cf4203e3a4f73f88f0335c2d69` | `5c911bc5306162a64e26b1ac9df960ea90e56f97` | +12／−0：三个新文件各四行（PBXBuildFile、PBXFileReference、组 children、源码阶段） |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | B／D | `47894556c4495a03b2b3364e7f67cf0527dcd116` | `458bc570b4ce9cbe21564d3d076b8ec9637c25b0` | +54／−0：`installS1Session` 注入 `seenAssetIDsProvider` 与 `legacyProgressMigration` 两个闭包；`migrateLegacyProgressIfNeeded(adopting:groupedBy:from:)` |
| `PhotoCleanupMVE/Core/S1LegacyProgressMigration.swift` | D（新建） | — | `10839f915450a1798a5d03424d51c6b86c56acbf` | +67：纯计算 `enum S1LegacyProgressMigration`，逐字节拷自 `Tasks/decision-tools/ic188/` |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | B／C／D | `3b343d30528909f5233d6a82a4974a90844d5164` | `957d2b198e114f58f920211ff3371a3695696aed` | +16／−7：`seenAssetIDsProvider`；`processedAssetIDs(for:)` 改 `W ∩ A(r)`；`makeS2Handoff(for:)` 起点改第一张没看过的；`legacyProgressMigration` 与 `adoptRanges` 钳制前调用 |
| `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | A | `a56f0972057d8c090d9e22ac8d772917c655e1b8` | `e7d9ac06d578b322ef8f07353f695d82f7ff91f4` | +3／−1：A1 |
| `PhotoCleanupMVETests/FullFlowRoutingTests.swift` | A | `774f3c0cc1a3e7e00bba6cec21a277038cf2363a` | `719fcfe4f07417302376d59b616610bc04802bdc` | +2／−1：A2 |
| `PhotoCleanupMVETests/IC131S1WriteBackToastTests.swift` | A | `26765ee9b48a030e530f4e57a6559329e92019ee` | `2b60a876094c6b799759321e2a6dcfdf4bab7aea` | +2／−1：A3 |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | A／C | `4dddc8fdb3568c0235a636d8243c418160b9fb16` | `ccbe0a3bf99e0e351494414f908c5997e87e8886` | +6／−4：A4、C3 说明注释、C4 逐字块起点三行 |
| `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | A | `fdb22e65205b1c2ebb180258b883dc1542ada016` | `144d4d96341a3a27f4ef80eb6e6d76e8c386f9c8` | +7／−3：A5～A7 |
| `PhotoCleanupMVETests/IC170S1FirstReadTests.swift` | A | `4a632c7b4ed2d5478c6af4ef40d1fd6ef28c5ded` | `7f17962231c9670f8f7172519e709faa42597c23` | +3／−1：A8 |
| `PhotoCleanupMVETests/IC187SeenArchiveTests.swift` | C／D | `4cbb36576c2e4568fac6e3757a3bed4a52768c3f` | `30c0dfb20fbb17adcda0499654ce2abdc997b8f5` | +6／−4：C6 最终集合；D5 迁移标记；D6 写出口计数 3 → 4 |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | E（新建） | — | `96f157a7a6d4dbdf1ec15bea1b02f7dbf097ed77` | +354：六条测试，逐字节拷自 `Tasks/decision-tools/ic188/` |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | B／C | `b755a6bd85b3b247a69dd477bae3e6c2c4818352` | `ff0b511873d35cfa004dcb5f16aa201ea84c2853` | +13／−5：B4～B6（`testIC046_010／_011／_018`）、C5（`_013`） |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A | `e933151a14a5bd771471e21347dd504541195209` | `31881a7178b151fe301c7b9a53ee26810c0dff51` | +3／−1：A9 |
| `PhotoCleanupMVETests/TestPersistenceIsolation.swift` | A（新建） | — | `64b6a04b2d9ffde79a0ce89b9bc90a629bba8af4` | +37：隔离持久层 helper，逐字节拷自 `Tasks/decision-tools/ic188/` |

## 三、新增符号与行为变化

| 符号 | 位置 | 说明 |
|---|---|---|
| `S1StateMachine.seenAssetIDsProvider: (() -> Set<String>)?` | `Core/S1StateMachine.swift` | 看过集合 `W` 的读口；协调器 `installS1Session` 注入，未注入的夹具按空集 |
| `S1StateMachine.processedAssetIDs(for:)` | 同上 | 改为 `W ∩ A(r)`，与排序、与 `K` 无关；`S1RangeRow.processedAssetCount` 字段名保留，卡片读它的视图一字未动 |
| `S1StateMachine.makeS2Handoff(for:)` | 同上 | 起点 = 当前 `O` 下第一张没看过的，全部看过取第一张；不再读 `K` |
| `S1StateMachine.legacyProgressMigration` | 同上 | 旧档迁移入口，`adoptRanges` 在 `Self.reconciledStore(…)`（`K` 钳制）之前调用，并带本次采用的维度 |
| `S1LegacyProgressMigration` | `Core/S1LegacyProgressMigration.swift` | `virtualRangePrefix`、`unclassifiedRangeID`、`dimension(ofRangeID:)`、`dimensionsToRead(for:adoptedDimension:)`、`migratedAssetIDs(from:sequencesNewestFirst:)` |
| `CleanupCoordinator.migrateLegacyProgressIfNeeded(adopting:groupedBy:from:)` | `App/CleanupCoordinator.swift`（private） | 看过档标记已置即返回；否则对 `K` 里本次维度之外的真实范围按所属维度同步读一遍；并入内容则立即 `flushSeenArchive()`，没有可迁内容只置标记不写盘 |
| `TestPersistenceIsolation.makePersistence()` | `PhotoCleanupMVETests/` | 每次一个临时根目录的隔离 `SessionPersistence` |

## 四、没有改动的东西（范围外，逐项核过）

`Core/SessionStore.swift`、`Core/SessionPersistence.swift`、`Core/S1SeenArchive.swift`、`Core/S2StateMachine.swift` 与 S2 全部文件、任何视图、App 入口、`Localizable.xcstrings`、`Scripts/`（含 `verify-IC-20260814-046.ps1`）、`.github/`、SPEC 与 Decision_log。`schemaVersion` 仍 7；没有出厂值变更。`testIC046_010`／`_011` 函数名未改（归 ②d）。

## 五、占位值登记

无（无出厂值变更）。

## 六、摘取关系

可摘单元：A；B；A→B→C；A→B→C→D；全部。C 起进入位置读 `W`，没有 A 的隔离时 `FullFlowRoutingTests` 004 起点会被真实目录里的看过档污染，所以 C、D 都必须带 A。克隆实测（`--no-hardlinks`，A 单独、B 单独、A→B→C→D 连续）`cherry-pick -x` 退出码均 0，结果树分别为 `af3bf19251a0a0664ec3ddb8923e3074d5668467`、`776ed0f42ae6961a8458445972f2cc01039169d5`（仅存在于克隆里）、`5371c1586aa09dea181beb6972a19b5872f9042f`（只证文本无冲突）。

## 七、CI 与产物

| 运行 | run id | 被测提交 | 结果 |
|---|---|---|---|
| 分支 #380 | `37877855901` | `24b3cbd0c31cd7019be7f089523091dc61a8be5c` | success，958／0，IPA 1989436 字节，SHA-256 `e600d07790ce4b0356642647ee509eb29f70ddd5922bcc8d4e845f45cb601be7` |
| 合并后 `main` #381 | `37879265210` | `c3ae531e685904664e64f54e1ffe895108318204` | success，958／0，IPA 1989436 字节，SHA-256 `a24879bc56e1db1a208a0ecc3ad22d3c6c7364b9c849ec3648c7dd41c9d91a22`；artifact `PhotoCleanupMVE-unsigned-c3ae531e6859`，id `11594250361`，2027-01-07T03:26:12Z 前有效 |

项数对账：`952 + 6 = 958`。

## 八、保留给 Lynn 的人工判定

H99 六条（原文见 `self-check.md` 第十四节），装合并后 `main` 的 artifact。

## 九、核验结果

docs 提交前对本清单与 `self-check.md` 中出现的全部 40 位 SHA（共 41 个）跑 `git cat-file -e <sha>^{<类型>}`：**40 个在原仓命中**——commit：`0d46d371…`、`24b3cbd0…`、`41758c88…`、`42ae1af1…`、`a5b49de5…`、`c3ae531e…`、`e4bf9f89…`、`f1c8aeb0…`；tree：`5371c158…`、`947e4b10…`、`a471c334…`、`af3bf192…`、`afec05ae…`；其余 27 个为 blob（基线与 E 提交的文件 blob、三个拷入文件 blob 及 pbxproj 等）。**1 个不在原仓**：`776ed0f4…`（B 单独 `cherry-pick` 在克隆里的结果树），已在克隆里 `git cat-file -e 776ed0f4…^{tree}` 命中（退出码 0）。docs 提交自身的 SHA 不在核验范围内。
