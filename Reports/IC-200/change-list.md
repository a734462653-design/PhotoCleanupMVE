# IC-200 变更清单

- 任务标识：`IC-20261009-200-scroll-restore`（路由往返后的滚动位置与展开卡恢复：A 偏移记忆与可恢复的滚动容器（两个新文件）+ 两个持有者 + pbx；B 四处滚动容器换接、首页展开卡播种与回报、流程容器两处归 0；C 新测试四条（含一条只打印的窗口宿主探针）+ IC167B／IC171C／IC192D 期望随改 + pbx；**有界面变化，人工判定项 H105 十六条保留给 Lynn**）
- 基线：`main` = `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec`；分支 `feature/ic-200-scroll-restore`；合并提交 `c889ca64239b3b9e720765060453c856865be569`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `aa58a8abec8c6f51e9e50f047b59c830ffe8a2bd` | 新文件 `ScrollOffsetMemory.swift`、`OffsetRestoringScrollView.swift`；`S1OpenCardState.swift`、`S0CleanupFlowModel.swift`、`project.pbxproj`（5 个路径）：只加不用，暂无调用方 | 可单独摘取并编译，既有测试照绿 |
| B | `1b77034d91492b35e0cabb42a33a6ff761e6bb0f` | `S0CleanupFlowView.swift`、`S0DeckCategoryPageView.swift`、`S0DeckHomeView.swift`、`S1View.swift`、`S1YearPageView.swift`（5 个路径）：用 A 的容器与记忆 | 只能接在 A 之后（A→B）；**A→B 时 IC167B／IC171C×2／IC192D 必红**（C 才随改） |
| C | `d763ce5105612f72bfc6ffab31d3a35c025ee330` | 新测试 `IC200ScrollRestoreTests.swift` + `IC167BasketEntryAndTailTests.swift`／`IC171CategoryPageTrioTests.swift`／`IC192PageHeaderTests.swift` 各一处 + `project.pbxproj`（5 个路径）：测试用 A 与 B | 只能 A→B→C |
| 合并 | `c889ca64239b3b9e720765060453c856865be569` | `merge(IC-200): 路由往返后的滚动位置与展开卡恢复——四处滚动容器按记下的偏移回到原位、首页展开卡跨往返保留` | — |

可摘单元：A；A→B→C（A→B 只证文本无冲突，克隆里 `cherry-pick -x` 三种都干净，结果树分别等于分支上 A、B、C 的树，见 `self-check.md` 第五节）。

## 二、逐文件（白名单 14 路径，`git diff --name-only 320f9e92e1d3adef2b0fee6ab96beff52b44a8ec..d763ce5105612f72bfc6ffab31d3a35c025ee330` 恰 14 行；增删行取自 `git diff --numstat`，合计 561 增 13 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Core/ScrollOffsetMemory.swift` | A | 16 | 0 | 新文件：`final class ScrollOffsetMemory { var offset: CGFloat = 0 }`（普通类、不发布）+ 静态换算 `offset(forContentMinY:)` = `max(0, -minY)`；`import CoreGraphics`、`import Foundation` |
| `PhotoCleanupMVE/Features/Shared/OffsetRestoringScrollView.swift` | A | 87 | 0 | 新文件：`OffsetRestoringScrollMetrics`（坐标空间名／锚点 id／锚点高 1 pt 三个登记）+ 通用容器 `OffsetRestoringScrollView<Content: View>(memory:restores:content:)`——`ScrollViewReader { ScrollView { 内容 + 顶部记录件（`GeometryReader` 读内容顶部 `minY`，`.onChange(of:initial: true)` 写记忆）+ 顶部恢复锚（1 pt 透明视图，`.id` 在 1 pt 那一层、`.padding(.top, restoreTarget)` 在外） } }`，`.task` 里 `hasRestored` 闸住只在实例第一次出现时 `scrollTo(锚, anchor: .top)` 一次，偏移 0 不滚；恢复目标在新建那一刻以 `State(initialValue:)` 取一次 |
| `PhotoCleanupMVE/Core/S1OpenCardState.swift` | A | 7 | 0 | 加 `let listScroll`、`let yearPageScroll`（`ScrollOffsetMemory`）；`setYearPageRangeID` 在值变成 nil 时 `yearPageScroll.offset = 0`（点月卡换展开不归 0） |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift` | A | 6 | 0 | 加 `let homeScroll`、`let categoryScroll`（`ScrollOffsetMemory`）与 `var preservedOpenCardID: String? = nil`；都不发布（`@Published` 仍 1） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、C | 12 | 0 | A 加两个新产品文件各四行共 8 行（`ScrollOffsetMemory.swift` 10000000000000000000009E／20000000000000000000009B 接在 `S1OpenCardState.swift` 之后；`OffsetRestoringScrollView.swift` 10000000000000000000009F／20000000000000000000009C 接在 `NavigationEdgeSwipeBack.swift` 之后）；C 加 `IC200ScrollRestoreTests.swift` 四行（1000000000000000000000A0／20000000000000000000009D，接在 `IC199S2SortMenuWiringTests.swift` 之后）；逐字节拷入 |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | B | 13 | 2 | 首页构造点加 `initialOpenedCardID: flowModel.preservedOpenCardID`、`onOpenedCardChange`（写回 `flowModel.preservedOpenCardID`）、`scrollMemory: flowModel.homeScroll`；`enterCategory`／`leaveCategory` 各加 `flowModel.categoryScroll.offset = 0`；类别页 `onEnterConfirmation` 由原样转交改为闭包——先 `flowModel.preservedScrollAnchor = nil` 再 `onEnterConfirmation()` |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | B | 10 | 1 | `scrollContent` 的 `ScrollView {` 换成 `OffsetRestoringScrollView(memory: flowModel.categoryScroll, restores: flowModel.preservedScrollAnchor == nil)`（长按锚点那条路优先，外层 `ScrollViewReader` 照旧）；长按手势里页头未收起时 `flowModel.categoryScroll.offset = 0` |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | B | 13 | 2 | `deckScreen` 的 `ScrollView {` 换成 `OffsetRestoringScrollView(memory: scrollMemory)`；`init` 加末位三个带默认值的形参 `initialOpenedCardID`／`onOpenedCardChange`／`scrollMemory`，`_openedCardID = State(initialValue: initialOpenedCardID)` 播种；点卡写入 `openedCardID = identifier` 之后 `onOpenedCardChange(identifier)` 回报 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | B | 4 | 1 | `pageContainer` 就绪分支的 `ScrollView {` 换成 `OffsetRestoringScrollView(memory: machine.openCards.listScroll)`；`selectDimension` 在 `switchGroupingDimension` 成功后 `machine.openCards.listScroll.offset = 0`（换维度是一张新列表） |
| `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | B | 2 | 1 | `ScrollView {` 换成 `OffsetRestoringScrollView(memory: openCards.yearPageScroll)` |
| `PhotoCleanupMVETests/IC200ScrollRestoreTests.swift` | C | 380 | 0 | 新文件，四条 `testIC200A`～`D`（A 记忆换算与年页归 0 规则／B 流程模型字段不发布／C 源码落位／D 窗口宿主机制探针，只打印 `IC200_PROBE`、不断言），逐字节拷入 |
| `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift` | C | 2 | 1 | 测试 B（第二个）`onEnterConfirmation: onEnterConfirmation` 2 → 1 + 注释一行 |
| `PhotoCleanupMVETests/IC171CategoryPageTrioTests.swift` | C | 6 | 4 | 测试 C：流程容器 `flowModel.preservedScrollAnchor = nil` 2 → 3、`preservedScrollAnchor` 2 → 3；页面 `flowModel.preservedScrollAnchor` 2 → 3；各加一行注释 |
| `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | C | 3 | 1 | 测试 D：`("ScrollView {", 1)` → `("OffsetRestoringScrollView(memory: machine.openCards.listScroll) {", 1)` + `("ScrollView {", 0)` + 注释一行 |

## 三、测试

- XCTest 991 → **995**（+4 `IC200ScrollRestoreTests`）。
- 随改的既有断言：IC167B、IC171C（两个 C）、IC192D 共五处期望（见上表三行）；其余既有测试未改（决策会话预演 39 对字面量差分均已逐类核过，CI 全绿印证）。
- CI：分支 #404（run `38012680912`）绿 995／0；合并后 `main` #405（run `38013766152`）绿 995／0；artifact `PhotoCleanupMVE-unsigned-c889ca64239b`（id `11655559241`，有效期至 2027-01-08T01:35:31Z）。
- `testIC200D` 探针读数（只打印、不断言）：`IC200_PROBE restore target=600 contentOffsetY=-54.0 memory=-0.0` 与 `IC200_PROBE nested-reader cell30Top=1500 contentOffsetY=-54.0 memory=-0.0 proxy=true`——两行都停在静止位置，解读与建议见 `self-check.md` 第十四节发现 1。

## 四、占位值登记

`OffsetRestoringScrollMetrics`：`coordinateSpaceName = "offsetRestoringScroll"`、`anchorID = "offsetRestoringScroll.anchor"`、`anchorHeight = 1`——字符串登记与 1 pt 技术常量，非视觉值，**卡内暂登，下一次 S1／S0 修订不必回填**。本卡不改 `S2CalibrationConfiguration`（`schemaVersion` 仍 7）、不加字段、不改出厂值，不加 `Localizable.xcstrings` 条目（目录条数不变）。

## 五、范围外（本卡未动）

状态机（`S1StateMachine` 等）、协调器、App、S2／S3 全部；`S1DeckCards.swift`、`S0BasketEntryView.swift`；白名单之外的测试；`Localizable.xcstrings`；`S2CalibrationConfiguration`；`Scripts/`、`.github/`；SPEC 与 Decision_log。

## 六、人工判定项

**H105 十六条保留给 Lynn 真机判定**（装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-c889ca64239b`；原文逐条转录见 `self-check.md` 第十一节）：前置待删篮有几张；列表页／年页进看图再返回回到原位且展开卡不变；相册卡与「未分类」同样；页头待删篮进确认页再返回位置不变；年页返回列表后再进从顶部开始、第一张月卡展开；首页展开某张卡并滚下去、待删篮往返后同卡仍展开且位置不变；类别页滚过页头、待删篮往返回到原位（H93 第 7 条缺陷）；类别页长按往返仍是那一格居中且接着待删篮往返回到点待删篮时的位置；类别页返回首页再进从顶部开始；切 tab 来回位置不变且往返之后再滚一段切 tab 不被拽回；换分组维度从顶部开始；连续几次往返不累积漂移；类别页页头未收起时长按回来从顶部开始；恢复那一下是直接出现还是先闪顶部再跳（记现象）、页面很长时是否准确；杀掉重开两个 tab 都从顶部、首页第一张卡展开；总评。执行端没有做任何真机或观感判断。

## 七、后续卡须知的钉子

- `IC200ScrollRestoreTests.testIC200C_SourceWiring` 钉了：容器文件的计数与次序（读写器 `initial: true`、`_restoreTarget = State(initialValue: restores ? memory.offset : 0)`、`.task` → `guard !hasRestored` → `hasRestored = true` → `guard restoreTarget > 0` → `scrollTo` 的次序、锚点切片 `.frame` < `.id` < `.padding`、纪律 needle）、记忆文件纪律、`S1OpenCardState` 两只记忆与 `setYearPageRangeID` 次序、四处调用点各 1 且原 `ScrollView {` 0（`S1View` 另钉 `ScrollViewReader` 0 与 `selectDimension` 次序）、首页三个新形参与播种和「写入后回报」次序、类别页 `restores:` 条件与外层 `ScrollViewReader` 照旧与长按页头未收起归 0 次序、流程容器传值与两处归 0（`enterCategory`／`leaveCategory` 体内各 1）与 `preservedScrollAnchor = nil` 3、流程模型字段与 `@Published` 1，以及「产品里构造记忆的恰三个文件、用容器的恰四个页面」两组。后续动这四个页面的滚动容器、流程容器 `enterCategory`／`leaveCategory`／类别页回调、`S1OpenCardState.setYearPageRangeID`、`S0CleanupFlowModel` 字段的卡，白名单须含该测试文件。
- `IC167BasketEntryAndTailTests` 测试 B（第二个）：流程容器 `onEnterConfirmation: onEnterConfirmation` 恰 1（首页一处，类别页一处已是闭包）；`IC171CategoryPageTrioTests` 测试 C：流程容器 `flowModel.preservedScrollAnchor = nil` 3、`preservedScrollAnchor` 3、页面 `flowModel.preservedScrollAnchor` 3；`IC192PageHeaderTests` 测试 D：`S1View` 就绪滚动容器是 `OffsetRestoringScrollView(memory: machine.openCards.listScroll) {` 1、`ScrollView {` 0。
- `testIC200D` 是只打印的探针（不断言），决策会话若重写探针宿主（`makeKeyAndVisible()`、等待时长），只动该测试函数即可，不影响其余计数。
