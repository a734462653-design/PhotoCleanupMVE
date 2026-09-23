# IC-167 变更清单

> 任务卡：`<top>/Tasks/IC-20260923-167-s0-basket-entry-tail-sort.md`。本清单与 `self-check.md` 同在合并后 `main` 上的恰一个 docs 提交里（惯例 44）。

## 一、分支、提交与合并

| 项 | 值 |
|---|---|
| 基线 | `main` = `e6cdabee804899c474eed3a3b9532f75838904c9` |
| 分支 | `feature/ic-167-s0-basket-entry-tail-sort`（自基线切出，已推送，保留不删） |
| 子项 A | `e82f2a5f5a7ebd9332bff7f8919f5ffc6f83e9e8` `feat(IC-167): 子项 A 展开末卡延伸到底——…`（1 个文件，+19／−8） |
| 子项 B | `edea245f96bae51ac7d4589b7587b01c19df5b48` `feat(IC-167): 子项 B 首页待删篮入口改圆钮 + 徽标并接 S3、…`（10 个文件，+160／−64） |
| 子项 C | `bddcb07a72c689fa6536452156d509f592263575` `feat(IC-167): 子项 C 类别页排序加「从小到大」——…`（6 个文件，+38／−9） |
| 子项 D | `92b0b9234442e6a330c78545fd219fb811e692b5` `feat(IC-167): 子项 D 类别页页头与收起导航条各加一只待删篮入口（裁定 五）`（2 个文件，+16／−2） |
| 子项 E | `fc6dd1436fa25b8298caca2f3d2266024859df4e` `test(IC-167): 子项 E 新断言五条——…`（2 个文件，+482） |
| 合并 | `81effe7c388e6b18560ee284d4cab7d575eca2b1` `merge(IC-167): 首页待删篮入口改圆钮 + 徽标并接 S3、展开末卡延伸到底、类别页排序加「从小到大」、类别页顶排待删篮入口（SPEC-S0 v4）`，`--no-ff`，父 `e6cdabe` + `fc6dd14`，树 `e82c54c9f47de0f78ce61de8be9d9af78e5c602e`（= E 的树） |
| 报告 | 本 docs 提交（合并后 `main` 运行之后，直接落在 `main` 上） |

`git diff --stat e6cdabe fc6dd14`：15 个文件，+715／−83，恰为卡面白名单 15 个路径（产品 7、目录 1、工程 1、测试 6）。

## 二、子项 A · 展开末卡（裁定 一）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | 新增 `static func cardExtension(index:count:) -> CGFloat`（末张取 `lastCardTailHeight`、其余 `cardOverhang`，带文档）；`cardButton` 删 `isTail`、高度改 `visible + Self.cardExtension(index: index, count: cards.count)`；`cardContent` 文字块与「去清理」底距改 `(height - visibleHeight) + openText／openActionBottomInset`，并在既有压暗层之后加一层 `Color.black.opacity(openShadeBottomOpacity).frame(height: height - visibleHeight)`（`.overlay(alignment: .bottom)`，仅展开态）；两处 `IC-167 A` 注释 |

## 三、子项 B · 首页入口 + 接 S3 + S0-4 对齐（裁定 二、三）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0BasketEntryView.swift`（新建） | `struct S0BasketEntryView: View`：`enum Style { glass, flat }`、`style`／`count`／`action`；按钮 + `.disabled(count == 0)` + 无障碍标签（借 `s1.trash.accessibility`）+ 右上徽标（`count > 0`，`S1NotificationBadgeStyle` 七处、描边 `S0DeckMetrics.background`、不接收点击）；只 `import SwiftUI`，零 PhotoKit，裸数只有 `0` |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记产品文件：fileRef `100000000000000000000070`、buildFile `20000000000000000000006D`（`S0` 组与 App Sources 阶段，紧跟 `S0DeckHomeView.swift`；+4 行） |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | 顶排胶囊换成 `S0BasketEntryView(style: .glass, count: machine.mergedPendingDeletionCount, action: onEnterConfirmation)`；删 `basketCapsule`；`content` 的 `.empty`／`.failed` 两支各包 `VStack(alignment: .leading, spacing: 0) { topRow; … }`；头部文档「顶排的圆钮与胶囊」→「顶排的圆钮」；两处 `IC-167 B` 注释 |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | 存储属性 `onEnterConfirmation`（带文档）、init 末位形参 `onEnterConfirmation: @escaping () -> Void = {}` 与赋值；首页构造插 `onEnterConfirmation: onEnterConfirmation,` |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `S0CleanupFlowView(...)` 末位实参 `onEnterConfirmation: { reconcileS1WithPhotoLibrary(); guard let submission = makeS3Submission() else { return }; enterConfirmationFromS1(submission) }`（三句各一行）；`s0Screen` 文档一句按卡改写 |
| `PhotoCleanupMVE/Core/S0StateMachine.swift` | `accepts` 的 `.basketCapsule` 一支 `return mergedPendingDeletionCount > 0`（去 `currentState != .failed`），加两行注释 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 删 `s0.basket.capsule`（11 行外科删除；255 → 254） |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | 矩阵行 3 注释改写、`failedExpectation: false` → `true`；断言 11 名单加 `S0BasketEntryView.swift`（上方一行注释）、借用集 `Set([...])` 加 `s1.trash.accessibility`（上方注释补一行） |
| `PhotoCleanupMVETests/IC165DeckFormalTests.swift` | 断言 6 借用集加 `s1.trash.accessibility`（上方注释补一行） |
| `PhotoCleanupMVETests/IC166RestCategoryTests.swift` | 删 App 入口 blob 断言四行；`:358` 注释改为「协议文件与 `6bc51be` 逐字节相同（git blob 标识相同）；App 入口的 blob 钉自 IC-167 起按惯例 46 撤下」 |

## 四、子项 C · 排序四项（裁定 四）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift` | `SortOrder` 加 `case sizeAscending`；`sorted(_:by:dates:)` 前置升序分支（字节升序、同体积按标识升序）；两段文档补 `sizeAscending` |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | Picker 加「从小到大」项；`gridContent` `case .size, .sizeAscending:`；`sortOrderName` 加一支；头部文档与 `sortMenu`／`sortOrderName` 文档补「四项」 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 加 `s0.categoryPage.sort.sizeAscending` = `从小到大`（插在 `s0.categoryPage.sort.size` 之后；254 → 255） |
| `PhotoCleanupMVETests/IC156CategoryPageTests.swift` | `s0.categoryPage.` 9 → 10；`expected` 映射加一条；注释补一行 |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | 仅 `s0.categoryPage.` 9 → 10（注释补一句） |
| `PhotoCleanupMVETests/IC165DeckFormalTests.swift` | 仅 `s0.categoryPage.` 9 → 10（上方加一行注释） |

## 五、子项 D · 类别页两处入口（裁定 五）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | 页头 `topRow` 在 `Spacer` 与排序钮之间插 `S0BasketEntryView(style: .glass, …)`；收起导航条内层 `HStack` 首位插 `S0BasketEntryView(style: .flat, …)`；存储属性（带文档）、init 末位形参 `onEnterConfirmation: @escaping () -> Void = {}`（`transitionNamespace` 之后）与赋值；头部文档补一行 |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | 类别页构造末位加 `onEnterConfirmation: onEnterConfirmation` |

## 六、子项 E · 新断言

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift`（新建） | 五个 `func test`：`testIC167A_OpenTailCardExtendsToTailHeight`（`@MainActor`）、`testIC167B_BasketEntryIsCircleWithBadge`、`testIC167B_BasketEntryReachesConfirmationAndFailedStateAccepts`、`testIC167C_SizeAscendingSortsByBytesThenID`、`testIC167D_CategoryPageHasTwoBasketEntriesLeftOfSort`；源码扫描 helper 口径同 IC-165／166 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记测试文件：fileRef `100000000000000000000071`、buildFile `20000000000000000000006E`（测试组与测试 Sources 阶段，紧跟 `IC166RestCategoryTests.swift`；+4 行） |

## 七、占位值与登记

| 项 | 值 |
|---|---|
| `S2CalibrationConfiguration.schemaVersion` | **7，未变**（本卡无出厂值变更） |
| `S0ScanRules.cacheSchemaVersion` | **1，未变** |
| `S0DeckMetrics` 登记值 | 198，未变（登记表文件 blob 不变；入口与徽标全借既有常量） |
| `S0DeckSymbol` | 8，未变（入口复用 `trash`） |
| String Catalog | 255 →（B）254 →（C）**255**；`s0.` 40 →（B）39 →（C）**40**；`s0.categoryPage.` 9 → **10**；删 `s0.basket.capsule`、加 `s0.categoryPage.sort.sizeAscending` = `从小到大`（v4 `:913` 已登记） |
| S0 跨前缀借用 | 四条 → **五条**（加 `s1.trash.accessibility`，v4 第十四节第 3 部分已登记） |
| `S0DeckHomeModel.SortOrder` | 三 case → 四 case（`size` 之后加 `sizeAscending`） |
| 徽标描边色 | `S0DeckMetrics.background`（**v4 第十四节未登记，v4 欠账**） |

## 八、项数

871 →（A）871 →（B）871 →（C）871 →（D）871 →（E）**876**。CI：#337（A→B→C）871／0、#338（A～E）876／0、合并后 `main` #339（run 35924716225）876／0。

## 九、摘取关系（惯例 40，克隆实测）

- A 单独：无冲突，结果树 = 分支 A 的树 `15a9013897e3d0c5ff448dc323cb64c7ea7afca3`。
- A → B → C：无冲突，结果树 = 分支 C 的树 `2dc7c4281dc4a81dbf25f30fd0350833fd366c7e`；#337 绿。
- A → C（跳过 B）：文本无冲突，按卡面 `s0.` = 41 必红，未取 CI。
- 可摘单元 = A；A→B→C；A→B→C→D；A→B→C→D→E。B 单独（`s0.` 39）必红，D 编译依赖 B、变绿依赖 C，E 依赖 A～D。

## 十、未改动（「不得打红」）

`Core/` 除 `S0StateMachine.swift`（只改 `accepts` 的 `.basketCapsule` 一支）、`Services/` 全部、`Features/S0/` 的 `S0CleanupDataProviding`／`S0CategoryPageSelection`／`S0DeckZoomTransition`／`S0TabContainer`／`S0Text`／`S0SegmentBarModel`／`S0DeckMetrics`／`S0CleanupFlowModel` 八个、`Features/Shared/`、`Features/S1`～`S5`（`S1View.swift` 一字未动）、`App/CleanupCoordinator.swift`、`.github/`、`Scripts/`、白名单六份以外的全部测试文件：与 `e6cdabe` 对象相同（`self-check.md` 第十一节）。SPEC 与 Decision_log 未触碰。
