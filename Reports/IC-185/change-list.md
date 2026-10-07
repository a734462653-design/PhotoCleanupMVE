# IC-185 变更清单

任务卡：`Tasks/IC-20261006-185-nav-maintenance.md`（导航维护小卡：A 年页／类别页左缘右滑返回；B tab 落点诊断时间线，只记不改；C 五条新测试 + pbx 登记）。
基线：`main` = `46e82e7cb07aa964e00205d086d15a0d74726fb7`。分支：`feature/ic-185-nav-maintenance`。合并提交 `04b8d47dd85c3dca81f601437bc39ad24c3c2462`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `c37e8bfcac4468b48335f464d246012323ec1cf7` | `cf00ed0e1197b2feb4c0f761ddff8b54704d5170` | 新文件 `Features/Shared/NavigationEdgeSwipeBack.swift`（逐字节拷入）+ pbx 四行（Shared 组，A1～A4） |
| B | `c3e8d8e014e5373627b487264403c86277b83b37` | `3252a727fbb130db363785283da2b70ce7a6345e` | 新文件 `App/S0TabRouteDiagnostics.swift`（逐字节拷入）+ 容器两处（B0 类注释、B1 `select`）+ App 四处（B2～B5）+ pbx 四行（App 组，B6～B9） |
| C | `7872de5b90922c986fa9b7f9d2a6c3dd11580959` | `453a236891c300e92a17534186f2fbdd990cd8c4` | 新测试文件（逐字节拷入）+ pbx 测试登记四行（C1～C4） |

合并提交与 docs 提交见 `self-check.md` 第一节与第三节。

## 二、逐文件（白名单 6 路径，`git diff --name-only 46e82e7…..7872de5` 恰 6 行）

| 路径 | 子项 | 基线 blob | C 提交 blob | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Features/Shared/NavigationEdgeSwipeBack.swift` | A（新建） | — | `3ead735f8914caf9556a5566d413eafdf7a24aef` | 逐字节拷自 `Tasks/decision-tools/ic185/NavigationEdgeSwipeBack.swift`（+20）：`extension UINavigationController: @retroactive UIGestureRecognizerDelegate`，`viewDidLoad` 里把 `interactivePopGestureRecognizer` 代理换成自己，`gestureRecognizerShouldBegin` = 栈里多于一页且无进行中转场 |
| `PhotoCleanupMVE/App/S0TabRouteDiagnostics.swift` | B（新建） | — | `762434217b66d4852b832eda9f388df9fbe36591` | 逐字节拷自 `Tasks/decision-tools/ic185/S0TabRouteDiagnostics.swift`（+67）：`S0TabRouteDiagnostics`（`format=ic185-tab-v1`、上限 24、`note(_:)`、`text`、`@MainActor static uikitSelectedTabIndex()`）与 `Optional<String>.withTabDiagnostics(_:)` |
| `PhotoCleanupMVE/Features/S0/S0TabContainer.swift` | B | `9a80395451f031f86e30873917f003c63c10c6c3` | `7161544d064bd26283bb8f9825f7534b912ae7e3` | +5／−1。B0 类注释一行换一行；B1 `onSelect` 回报闭包属性 + `select` 里先取旧值、写入后回报（`selectedTab = tab` 仍是全仓唯一赋值） |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | B | `559b0c7cd6f2510fd3973a5d47cf668c6921c523` | `ee16d563bd2ca20987b3af34a57bc154bfa74724` | +21／−1。B2 持有 `@StateObject tabDiagnostics`；B3 容器 `.onAppear` 开头接回报、记出现那一笔（选中态、写入计数、UIKit 选中下标）并下一拍补记一次；B4 根 `.onChange(of: coordinator.route)` 记路由；B5 `exitDiagnosticsText` 实参末尾接时间线 |
| `PhotoCleanupMVETests/IC185NavigationMaintenanceTests.swift` | C（新建） | — | `0220c6760997bb94db1e4700a5bd038f5c75f033` | 逐字节拷自 `Tasks/decision-tools/ic185/IC185NavigationMaintenanceTests.swift`，五条测试（+295） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、B、C | `e6d4721c7f1b23ba7f56cb2021fa9a69fbfdb5a5` | `3c2f0d5d8f30a8682bbdda3acd818ddd4bc04ccb` | +12。三个文件各 PBXBuildFile 1、PBXFileReference 1、组 children 1、Sources 阶段 1，共 12 行照卡面原文（制表符与既有行相同） |

## 三、新 pbx id（登记前 fileRef 最大 `100000000000000000000083`、buildFile 最大 `200000000000000000000080`）

| 文件 | fileRef | buildFile | 所在组 |
|---|---|---|---|
| `NavigationEdgeSwipeBack.swift` | `100000000000000000000084` | `200000000000000000000081` | Shared（`30000000000000000000000B`） |
| `S0TabRouteDiagnostics.swift` | `100000000000000000000085` | `200000000000000000000082` | App（`300000000000000000000002`） |
| `IC185NavigationMaintenanceTests.swift` | `100000000000000000000086` | `200000000000000000000083` | 测试组（`300000000000000000000009`） |

## 四、测试函数新增（五条，既有测试文件一字未动）

`testIC185A_EdgeSwipeBackDelegateGatesOnStackDepth`、`testIC185B_TabSelectionReportsEveryWrite`、`testIC185B_TimelineFormatCapAndJoin`、`testIC185B_SourceWiringRecordsOnlyAndKeepsExistingPins`、`testIC185C_TabContainerRebuildProbe`。XCTest 940 → 945。

## 五、占位值登记

本卡不改 `S2CalibrationConfiguration` 任何字段，`schemaVersion` 仍 7。不新增目录 key（目录 blob 不变、仍 281 条）。新增常量 `S0TabRouteDiagnostics.maximumEvents = 24`、`format`、`unavailable` 属诊断工具内部取值，不进登记制常量表。

## 六、范围外未动

`S1YearPageView.swift`、`S0DeckCategoryPageView.swift`、`S0CleanupFlowView.swift`、`S1View.swift`、`S2View.swift`、`CleanupCoordinator.swift`、目录 `Localizable.xcstrings`、`Scripts/`、`.github/`、任何既有测试文件、SPEC 与 Decision_log。S2 退出落 tab 的修法（另卡，待诊断）与 S3 返回落点（随 S1 重设计批）均未做。
