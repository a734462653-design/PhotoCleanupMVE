# IC-199 变更清单

- 任务标识：`IC-20261009-199-s2-sort-menu-ui`（S2 排序系统 `Menu` 的界面层 E2：A 看图页中胶囊系统 `Menu` + 主行下箭头 + 横栏重排不滑行；B 协调器 `makeS2SortMenu()`（类别范围不出）+ App 接线；C 新测试三条 + IC198E 一处钉子随改 + pbx；**有界面变化，人工判定项 H104 十五条保留给 Lynn**）
- 基线：`main` = `4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5`；分支 `feature/ic-199-s2-sort-menu-ui`；合并提交 `71a58366f2225759133a327cff2e0f4405f9c010`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `53297b54fc7cf57310105dfa99c95e67bdeb14c7` | `S2View.swift`（1 个路径）：`S2SortMenu`／`S2SortMenuMetrics`、`sortMenu` 形参（默认 nil）、`topCenterCapsule`、主行下箭头、横栏重排不滑行；无产品调用方 | 可单独摘取并编译，**但 IC198E 在 A 单独与 A→B 时必红**（C 才随改） |
| B | `df1a5c5cff83181b86e9effd2d61329cc32b7538` | `CleanupCoordinator.swift`、`PhotoCleanupMVEApp.swift`（2 个路径）：用 A 的 `S2SortMenu` 类型 | 只能接在 A 之后（A→B） |
| C | `f574705bfca77b58d681c2668798683ea08dd7b9` | 新测试 `IC199S2SortMenuWiringTests.swift` + `IC198S2SortOrderLogicTests.swift` 一处 + `project.pbxproj`（3 个路径）：测试用 A 与 B | 只能 A→B→C |
| 合并 | `71a58366f2225759133a327cff2e0f4405f9c010` | `merge(IC-199): S2 排序菜单界面层——中胶囊系统 Menu 与主行下箭头、横栏重排不滑行、协调器给菜单` | — |

可摘单元：A→B→C（A、A→B 只证文本无冲突，克隆里 `cherry-pick -x` 三种都干净，结果树分别等于分支上 A、B、C 的树，见 `self-check.md` 第五节）。

## 二、逐文件（白名单 6 路径，`git diff --name-only 4ceb27d75e8bf9f0f8faec6cd88ade13b64f25a5..f574705bfca77b58d681c2668798683ea08dd7b9` 恰 6 行；增删行取自 `git diff --numstat`，合计 554 增 14 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A | 86 | 11 | 新类型 `S2SortMenu`（`currentOrder`／`changeOrder` 两个闭包）与 `S2SortMenuMetrics`（`chevron.down`、字号 10、间距 4，卡内暂登），放在 `struct S2View` 之前；`S2View` 末位形参 `sortMenu: S2SortMenu? = nil` 与存储；`topBarRow` 中间一项改走新 builder `topCenterCapsule`（有菜单时系统 `Menu` + `Picker`、`label` 为原信息胶囊，没有时只画原信息胶囊；长按 0.8 s 标定面板手势仍挂外层）；`topInfoArea` 主行日期改具体动态色 `S2ChromeForeground.onGlassPrimary` 并在末尾加下箭头；横栏 `S2BottomStripView` 加 `@State stripSyncedRevision`（构造时取机器版本号）、`currentIndex` 回调重排那次 `animated: !reordered`、新增 `.onChange(of: machine.orderedListRevision)` |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | B | 19 | 0 | `makeS2SortMenu() -> S2SortMenu?`（在 `enterS2` 之后、`changeS2SortOrder` 之前）：`route == .s2`、S1 机器与在途副本在、非虚拟（`cat:`）范围才给；闭包 `[weak self]` 现读 S1 的 `O`，选择走 `changeS2SortOrder(to:)` |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | B | 3 | 1 | `s2Screen` 末位实参 `sortMenu: coordinator.makeS2SortMenu()`（前一实参行末补逗号） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | C | 4 | 0 | 加 `IC199S2SortMenuWiringTests.swift` 四行（fileRef `10000000000000000000009D`／buildFile `20000000000000000000009A`，接在 `IC198S2SortOrderLogicTests.swift` 之后）；逐字节拷入 |
| `PhotoCleanupMVETests/IC198S2SortOrderLogicTests.swift` | C | 6 | 2 | 测试 E 末段第二组：「只有状态机提到 `orderedListRevision`」→「状态机与看图页」（集合 `["S2StateMachine.swift", "S2View.swift"]`）+ 注释补一句；其余不动 |
| `PhotoCleanupMVETests/IC199S2SortMenuWiringTests.swift` | C | 436 | 0 | 新文件，三条 `testIC199A`～`C`（A 协调器菜单 / B 横栏重同步 / C 源码落位），逐字节拷入 |

## 三、测试

- XCTest 988 → **991**（+3 `IC199S2SortMenuWiringTests`）。
- 随改的既有断言：`IC198S2SortOrderLogicTests.testIC198E_SourcePlacement` 一处（见上）；其余既有测试未改（决策会话预演 119 对字面量差分均已逐类核过，CI 全绿印证）。
- CI：分支 #402（run `38005645824`）绿 991／0；合并后 `main` #403（run `38006618952`）绿 991／0；artifact `PhotoCleanupMVE-unsigned-71a58366f222`（id `11652300415`，有效期至 2027-01-07T23:53:47Z）。

## 四、占位值登记

`S2SortMenuMetrics`：`chevronSymbol = "chevron.down"`、`chevronPointSize = 10`、`chevronSpacing = 4`——**卡内暂登，下一次 S2 修订回填**（决策 59「主行加下箭头」未给字号与间距）。除此之外本卡不改 `S2CalibrationConfiguration`（`schemaVersion` 仍 7）、不加字段、不改出厂值，不加 `Localizable.xcstrings` 条目（借 `s1.sort.*` 三条，目录仍 293）。

## 五、范围外（本卡未动）

`S2StateMachine.swift`、`S2NativePhotoPager.swift`、`S1StateMachine.swift`、`S1PageHeader.swift`、`Localizable.xcstrings`；白名单之外的测试；`S2CalibrationConfiguration`；`Scripts/`、`.github/`；SPEC 与 Decision_log。

## 六、人工判定项

**H104 十五条保留给 Lynn 真机判定**（装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-71a58366f222`；原文逐条转录见 `self-check.md` 第十一节）：下箭头与系统菜单两项及勾选、换序后当前照片不动（可能闪占位）与副行序号变化、横栏直接对准当前张不滑行、Nx 下换序回 1x、返回「逐张整理」按新顺序、类别页长按进来没有菜单、长按 0.8 s 与菜单共存、读屏、换序后标记与返回、日期白色与按压观感、视频与实况照片、经确认页往返后顺序保持、单张范围、没有拍摄日期的照片、总评。执行端没有做任何真机或观感判断。

## 七、后续卡须知的钉子

`IC199S2SortMenuWiringTests.testIC199C_SourceWiring` 钉了看图页 `topCenterCapsule`／`topInfoArea` 的切片计数与次序、横栏两个回调体、协调器 `makeS2SortMenu` 切片、App 一处实参，以及「产品里只有谁提到」四组（`return S2SortMenu(`、`makeS2SortMenu(`、`orderedListRevision`、`changeS2SortOrder(`）；`IC198S2SortOrderLogicTests` 测试 E 钉了 `orderedListRevision` 的文件集合为状态机与看图页。后续动 `S2View.swift` 顶排／横栏回调、协调器 `enterS2`～`changeS2SortOrder` 之间或 App `s2Screen` 末位实参的卡，白名单须含这两个测试文件并预写旧 → 新。
