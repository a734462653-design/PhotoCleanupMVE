# IC-198 变更清单

- 任务标识：`IC-20261009-198-s2-sort-order-logic`（S2 排序系统 `Menu` 的逻辑层 E1：A 看图页状态机 `reorderAssets`——当前照片不变、下标改成新位置、复位 1x、版本号 +1；B 协调器 `changeS2SortOrder(to:)`——只对真实范围、先核成员再改 S1 的 `O` 再让看图页重排、失败改回、换在途交接副本；C 新测试五条 + pbx；**不接视图、无界面变化、无人工判定项**）
- 基线：`main` = `ab8f5612e4f2eececcc5f4f89e85e678206e7b2d`；分支 `feature/ic-198-s2-sort-order-logic`；合并提交 `d78102252ba8ceee4d6a9f603bd540f619576b5e`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `d433c6f51f425cf5a82ee5e076222e404bc3f999` | `S2StateMachine.swift`（1 个路径）：新 API 无产品调用 | 可单独摘取 |
| B | `4bea46263e5b49d2f65595a314968e9e86308744` | `CleanupCoordinator.swift`（1 个路径）：调 A 的 `reorderAssets(_:)` | 只能接在 A 之后（A→B） |
| C | `b0e2a8b6304071eebbe1ecd7c7fdb9ccd22eca84` | 新测试 `IC198S2SortOrderLogicTests.swift` + `project.pbxproj`（2 个路径）：测试用 A 与 B 的新 API | 只能 A→B→C |
| 合并 | `d78102252ba8ceee4d6a9f603bd540f619576b5e` | `merge(IC-198): S2 排序逻辑层——看图页按新顺序重排（当前照片不变）、协调器改会话级排序并换在途交接副本` | — |

可摘单元：A；A→B；A→B→C（克隆里 `cherry-pick -x` 三种都干净，结果树分别等于分支上 A、B、C 的树，见 `self-check.md` 第五节）。

## 二、逐文件（白名单 4 路径，`git diff --name-only ab8f5612e4f2eececcc5f4f89e85e678206e7b2d..b0e2a8b6304071eebbe1ecd7c7fdb9ccd22eca84` 恰 4 行；增删行取自 `git diff --numstat`，合计 611 增 1 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | A | 36 | 1 | `let entry` → `private(set) var entry`（读口不变）；`S2EntryContext.reordered(_:currentAssetID:)`（只换顺序与当前张，会话、范围信息、进入时的待删集合、合并计数读口原样）；`@Published private(set) var orderedListRevision = 0`；`reorderAssets(_:) -> Bool`（`@discardableResult`；门槛 `controlsCanReceiveInput`、成员同且顺序真变；当前照片不变、下标改为新位置、`resetZoomAfterPhotoChange()`、版本号 +1；不记看过、不改两个一次性信号、不发待删回调）；放在 `makeExitPayload()` 之前；逐字节拷入 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | B | 35 | 0 | `changeS2SortOrder(to:) -> Bool`（`@discardableResult`，放在 `leaveS2(with:)` 之前）：守卫（`.s2`、两台机器与交接副本在、非虚拟范围、新值 ≠ 现值、范围仍在）→ 取 `range.orderedAssetIDs(for: newValue)` 并核同数同成员 → S1 `switchSortOrder(to:)`（写会话快照）→ 看图页 `reorderAssets(_:)`，失败把 S1 的 `O` 改回 → 换 `s2EntryContext`（同 `rangeID`、新列表、新 `sortOrder.sessionSortOrder`）→ `sessionStore = s1Machine.sessionStore`；逐字节拷入 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | C | 4 | 0 | 加 `IC198S2SortOrderLogicTests.swift` 四行（fileRef `10000000000000000000009C`／buildFile `200000000000000000000099`，接在 `IC197GuideDWiringTests.swift` 之后）；逐字节拷入 |
| `PhotoCleanupMVETests/IC198S2SortOrderLogicTests.swift` | C | 536 | 0 | 新文件，五条 `testIC198A`～`E`（A 状态机重排 / B 状态机拒绝 / C 协调器真实范围 / D 协调器拒绝 / E 源码落位），逐字节拷入 |

## 三、测试

- XCTest 983 → **988**（+5 `IC198S2SortOrderLogicTests`）。
- 随改的既有断言：无（决策会话预演 69 对字面量差分均不在既有测试的作用域内，CI 全绿印证）；其余既有测试未改。
- CI：分支 #400（run `37998187404`）绿 988／0；合并后 `main` #401（run `38000875504`）绿 988／0；artifact `PhotoCleanupMVE-unsigned-d78102252ba8`（id `11649763300`，有效期至 2027-01-07T22:45:00Z）。

## 四、占位值登记

无。本卡不改 `S2CalibrationConfiguration`（`schemaVersion` 仍 7）、不加字段、不改出厂值。

## 五、范围外（本卡未动）

`S1StateMachine.swift`（`switchSortOrder(to:)` 原样调用）、`SessionStore.swift`、`S2View.swift` 与全部视图、App 入口；全部既有测试；`Localizable.xcstrings`（目录条数不变）；`S2CalibrationConfiguration`；`Scripts/`、`.github/`；SPEC 与 Decision_log。

## 六、人工判定项

无（不接视图，安装包里没有可见变化；菜单与重排后的画面——当前照片不动、横栏格位、返回 S1 范围列表按新 `O`、类别页进来没有菜单、长按仍进标定面板、深浅色系统菜单观感——归 E2 的 H）。执行端没有做任何真机或观感判断。

## 七、E2 接视图时必须随改的钉子

`IC198S2SortOrderLogicTests.testIC198E_SourcePlacement` 末段三条「产品里只有谁提到」——只有协调器提到 `changeS2SortOrder(`、只有状态机提到 `orderedListRevision`、只有状态机与协调器提到 `reorderAssets(`——E2 让 `S2View` / App 引用这些符号时必然红，卡须预写旧 → 新。
