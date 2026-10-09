# IC-195 变更清单

- 任务标识：`IC-20261009-195-s2-guide-d-logic`（S2 教学引导 D 的逻辑层 D1：状态机两个一次性信号 + 引导协调器；不接视图；无界面变化）
- 基线：`main` = `ae4776f846a70faaf9a05bb7cb445de56b2ad48c`；分支 `feature/ic-195-s2-guide-d-logic`；合并提交 `77246b7403586674da299165b5b2cc664eb3f306`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `1e0629c5b8e9c491456f452410c9538896c27985` | `S2StateMachine.swift`：两个枚举（`S2PendingDeletionChangeSource`、`S2CurrentAssetChangeCause`）、两个 `private(set) var` 可选存储、七个写入点赋值（1 个文件） | 可单独摘 |
| B | `e4fcb224c2f7f88e1cd44c01a5a1e46e9c4ba946` | 新文件 `S2GuideD.swift`（步骤、六标志存储、引导协调器）+ pbx 源码登记（2 个文件） | 只能 A→B（用到 A 的两个枚举） |
| C | `3415eac9ffd6e53532c0536f6434601a8a93cee3` | 新测试 `IC195GuideDLogicTests` 八条 + pbx 测试登记（2 个文件） | 只能 A→B→C |
| 合并 | `77246b7403586674da299165b5b2cc664eb3f306` | `merge(IC-195): S2 教学引导 D 的逻辑层——状态机两个一次性信号与引导协调器（四步 + 完成、跳过、进门压暗、六个已会标志）；不接视图` | — |

可摘单元：A；A→B；A→B→C（克隆里 `cherry-pick -x` 全部干净，结果树逐个等于分支上的树，见 `self-check.md` 第五节）。

## 二、逐文件（白名单 4 路径，`git diff --name-only ae4776f846a70faaf9a05bb7cb445de56b2ad48c..3415eac9ffd6e53532c0536f6434601a8a93cee3` 恰 4 行；增删行取自 `git diff --numstat`，合计 1008 增 0 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | A | 26 | 0 | 新增 `enum S2PendingDeletionChangeSource: Equatable`（`.mark`／`.undo`／`.albumRemoval`）与 `enum S2CurrentAssetChangeCause: Equatable`（`.markAdvance`／`.browse`）；`private(set) var lastPendingDeletionChangeSource` 与 `lastCurrentAssetChangeCause`（可选、不发布、不入档、不入标定）；赋值点七处——`handleSwipeUp`（来源 `.mark` 在 `replacePendingDeletionAssetIDs` 之前、原因 `.markAdvance` 在其后且在停留判据之前）、`handleSwipeDown`（`.undo`）、`removeFromPendingAfterAlbumAddition`（`.albumRemoval`）、`handleNativePageChange`／`handleHorizontalSwipe`／`changeCurrentPhotoDuringBottomStripDrag`／`navigateToNextAsset`（`.browse`）；`switchPhoto(by:)` 签名与本体、`handleSwipeUp` 停留判据一字不动 |
| `PhotoCleanupMVE/Features/S2/S2GuideD.swift` | B | 299 | 0 | 新文件（`import Combine` + `import Foundation`，无 `@MainActor`、零 `L10n`、零含汉字字面量）：`S2GuideStep`（四步，`rawValue` 是落盘键后缀）、`S2GuideDisplay`（`.step`／`.completion`）、`S2GuideStoring` + `S2UserDefaultsGuideStore`（键前缀沿用 v23，新三键 `undone`／`completed`／`introDimmed`）、`S2GuideCoordinator`（`start`／`assetDidBecomeMarked`／`assetDidBecomeUnmarked`／`currentAssetDidChange`／`mergedCountDidChange`／`confirmEntryTapped`／`skip`／`completionDidTimeOut`／`leaveScreen`／`reset`；读口 `holdsPageOnNextMark`、`isInterfaceVisible`；`confirmThreshold` 5、`completionAutoDismissSeconds` 2） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | B、C | 8 | 0 | B 四行（`S2GuideD.swift`：fileRef `100000000000000000000097`、buildFile `200000000000000000000094`、`S2` 组 children、源码 Sources 阶段）；C 四行（`IC195GuideDLogicTests.swift`：fileRef `100000000000000000000098`、buildFile `200000000000000000000095`、测试组 children、测试 Sources 阶段） |
| `PhotoCleanupMVETests/IC195GuideDLogicTests.swift` | C | 675 | 0 | 新文件，八条 `testIC195A`～`testIC195H`，逐字节拷入 |

## 三、测试

- XCTest 978 → **986**（+8，`IC195GuideDLogicTests`）。
- 随改的既有断言：无。
- CI：分支 #394（run `37973661392`）绿 986／0；合并后 `main` #395（run `37975469359`）绿 986／0；artifact `PhotoCleanupMVE-unsigned-77246b740358`（id `11638692677`，有效期至 2027-01-07T18:45:18Z）。

## 四、占位值登记

无。本卡不改 `S2CalibrationConfiguration`（`schemaVersion` 仍 7）、不加字段、不改出厂值；新增三个 `UserDefaults` 键后缀（`undone`／`completed`／`introDimmed`）只落在 `S2UserDefaultsGuideStore`，不入标定出厂值。

## 五、范围外（本卡未动）

`S2View.swift`、`S2InlineHints.swift`、`Localizable.xcstrings` 与全部视图；协调器（`CleanupCoordinator`）、App 入口；`S2CalibrationConfiguration`；`IC179`／`IC182` 两个既有测试文件；`Scripts/`、`.github/`；SPEC 与 Decision_log。D2（界面层）前置：`testIC195H_SourceWiring` 末段钉「`S2View.swift`／`S2InlineHints.swift` 里没有引导 D 的名字」，D2 接线后必改，D2 白名单须含 `IC195GuideDLogicTests.swift`。

## 六、人工判定项

无（本卡不接视图，运行中的引导仍是 v23 三句就地提示）。
