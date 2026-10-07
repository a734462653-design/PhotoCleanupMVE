# IC-187 变更清单

任务卡：`Tasks/IC-20261007-187-seen-archive.md`（S1 重设计批第二张（上）——看过档与「看过」记录：A 看过档类型 + 持久层；B S2 记「看过」；C 协调器持有看过档；D 四条新测试 + pbx 登记；只记与存，不改任何派生量与界面）。
基线：`main` = `f25af4fb386485fe562e1650c7d4a386d3a4b40f`。分支：`feature/ic-187-seen-archive`。合并提交 `e4bf9f89d1a71ae99bc4ddb8c6b5e8105548ff56`。

## 一、提交（各自独立、按卡顺序 A → B → C → D）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `504d98dd97231d5c20f434ecfc3dd1f72330349f` | `3373962341afc7579425e05f4f7d31f80dcdb3b0` | 新文件 `Core/S1SeenArchive.swift`（逐字节拷入）+ `Core/SessionPersistence.swift` 三处插入（A1 存储属性、A2 init 文件地址、A3 读写两个方法）+ pbx 四行（Core 组，A4～A7）；单独可摘 |
| B | `80174cbc727fd133a5b53fed043ae26c3ba3e167` | `f6a47aa381ae26248661bbb088d76c78149fa8fd` | `Core/S2StateMachine.swift` 五处（B1 存储属性、B2 init 形参、B3 init 末尾、B4 `endBottomStripDrag`、B5 `switchPhoto` + 两个新方法）+ `Features/S2/S2View.swift` 一处（B6 翻页停稳回调）；单独可摘 |
| C | `dfd88950d65b22f0523878ed933ebaff450cee12` | `29562fbadc8dfb8781dd6f921545e0a7ecd22e9a` | `App/CleanupCoordinator.swift` 五处（C1 两个状态、C2 `enterS2` 接回报、C3 `setApplicationActive`、C4 `applyS2ExitPayload` 开头 `defer`、C5 成功收尾 + 看过档四个函数）；依赖 A、B，只能 A→B→C 连续摘取 |
| D | `a94ab09ebc1e17667397b9c53db148cd2c6e4761` | `f04c27fa69042e39dcebb5c892a6b361196c388d` | 新测试文件（逐字节拷入）+ pbx 测试登记四行（D1～D4）；依赖 A、B、C |

合并提交与 docs 提交见 `self-check.md` 第一节与第三节。

## 二、逐文件（白名单 7 路径，`git diff --name-only f25af4f..a94ab09` 恰 7 行）

| 路径 | 子项 | 基线 blob | D 提交 blob | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Core/S1SeenArchive.swift` | A（新建） | — | `4573c8d697e3fe63f8166f9ac7e96ad0aaa88065` | 逐字节拷自 `Tasks/decision-tools/ic187/S1SeenArchive.swift`（+46）：`S1SeenArchive`（`seenAssetIDs`、`leaveTimeByRangeID`、`hasMigratedLegacyProgress`，三个带默认值的存储属性）；`PersistedS1SeenArchive: Codable`（`currentSchemaVersion = 1`、升序标识、秒数；`init(_:)` 与可选的 `archive`——版本不符、标识重复或为空即 nil）；只 `import Foundation` |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | A | `0d8371c60f90c5334b3c50215042ea8e296fbcd9` | `9464a81223faef9c1eea31cd7d2b4a73544d6ad5` | +23／−0，三处纯插入：`private let s1SeenFileURL: URL`；init 里 `s1SeenFileURL = directory.appendingPathComponent("s1-seen.json")`；`saveS1SeenArchive(_:)`／`loadS1SeenArchive()`（`NSLock` 保护、`.atomic` 整份重写、读失败返回 nil；**没有清档方法**） |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | B | `548a4c8d6be8e83724a40effb6421c8b968cfdc4` | `2ecdc5c8e8e0110f3d8afbd5a8fe17d73274656e` | +31／−1（净增 30；−1 是给既有 `recentAlbumDidChange` 形参行补逗号）：`seenAssetDidSettle` 回报闭包与 `visitSeenAssetIDs`（`private(set)`，不发布不入档）；init 形参 `seenAssetDidSettle`（带默认值）；init 末尾 `visitSeenAssetIDs = [entry.currentAssetID]`；`endBottomStripDrag` 与 `switchPhoto` 各接一次 `markCurrentSeen()`；新方法 `notePagingSettled()`／`markCurrentSeen()`（横栏非 `.idle` 时不记） |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | B | `ea216665a203b60b2900d4bc4cc21ab44386e38b` | `39acc0052234d23b811bf2c332bafe6a0b688fc1` | +2／−0：`onPagingSettled` 闭包里加注释一行与 `machine.notePagingSettled()` |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | C | `6baae5aa127873f7aa4077ad2b7af5a6ee022780` | `47894556c4495a03b2b3364e7f67cf0527dcd116` | +57／−0：`seenArchiveCache`／`writtenSeenArchive`；`enterS2` 里 `seenAssetDidSettle: { [weak self] assetID in self?.recordSeenAssets([assetID]) }` 并入进入时的第一张；`setApplicationActive(false)` 先 `flushSeenArchive()`；`applyS2ExitPayload` 开头 `defer { flushSeenArchive() }`、成功收尾 `recordSeenAssets(s2Machine?.visitSeenAssetIDs ?? [])` 与 `recordS2Leave(rangeID:at:)`；`currentSeenArchive()`（第一次用到时读持久层，读不到即空档）、`recordSeenAssets(_:)`、`recordS2Leave(rangeID:at:)`、`flushSeenArchive()`（单一写出口，快照无变化不写、写盘失败静默） |
| `PhotoCleanupMVETests/IC187SeenArchiveTests.swift` | D（新建） | — | `4cbb36576c2e4568fac6e3757a3bed4a52768c3f` | 逐字节拷自 `Tasks/decision-tools/ic187/IC187SeenArchiveTests.swift`，四条测试（+415） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、D | `6f4bc1cb79af06526219a4b32e9a00056a4b1f28` | `c92d2568cb2be3cf4203e3a4f73f88f0335c2d69` | +8／−0。产品文件与测试文件各 PBXBuildFile 1、PBXFileReference 1、组 children 1、Sources 阶段 1，共 8 行照卡面原文（制表符与既有行相同） |

## 三、新 pbx id（登记前 fileRef 最大 `100000000000000000000088`、buildFile 最大 `200000000000000000000085`）

| 文件 | fileRef | buildFile | 所在组 |
|---|---|---|---|
| `S1SeenArchive.swift` | `100000000000000000000089` | `200000000000000000000086` | Core |
| `IC187SeenArchiveTests.swift` | `10000000000000000000008A` | `200000000000000000000087` | 测试组 |

## 四、测试函数新增（四条，既有测试文件一字未动）

`testIC187A_ArchiveRoundTripAndCorruption`、`testIC187B_S2RecordsOnlySettledPhotos`、`testIC187C_CoordinatorRecordsLeaveTimesAndPersists`、`testIC187D_SourceWiring`。XCTest 948 → 952。

## 五、占位值登记

本卡不改 `S2CalibrationConfiguration` 任何字段，`schemaVersion` 仍 7。不新增目录 key（目录 blob `911848e37193b1491b60274549db5ec1c0425a33` 不变、仍 281 条）。无新增登记制常量；`PersistedS1SeenArchive.currentSchemaVersion = 1` 是看过档文件自己的格式版本，与 `S2CalibrationConfiguration.schemaVersion` 无关。

## 六、范围外未动

S1 已看进度与进入位置、旧档 `p_范围` 迁移（②b）；「新增 N 张」（②c）；`p_范围`／`O_记录`／`farthestAssetID` 退役与返回契约字段（②d）；V1 视图（③）；`navigateToNextAsset`（标定面板专用）；看过档的存在性收敛（规格未定项 29）；`Core/S1StateMachine.swift`、`Core/SessionStore.swift`、App 入口、`S2NativePhotoPager.swift`、任何 S1／S0 视图；目录；`Scripts/`、`.github/`；任何既有测试文件；SPEC 与 Decision_log。`finishSession()` 一字未动——看过档不随 S5 清。
