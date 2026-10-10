# IC-200 自验报告

## 一、结论（先行）

- **三个子项全部按卡面完成（逐字节拷入 `ic200/stages/`，未手改一行），G1095～G1099 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-200-scroll-restore`：A `aa58a8abec8c6f51e9e50f047b59c830ffe8a2bd` → B `1b77034d91492b35e0cabb42a33a6ff761e6bb0f` → C `d763ce5105612f72bfc6ffab31d3a35c025ee330`。
- 分支 CI **#404**（run `38012680912`，被测提交 C `d763ce5105612f72bfc6ffab31d3a35c025ee330`）一次绿：**995 项 0 失败**（991 + 4），`xcodebuild` 输出 `Executed 995 tests, with 0 failures` 与 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0；日志 `XCTest 已全部通过。`），目的地 `OS:26.2, name:iPhone 16`。IPA 2101127 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `c889ca64239b3b9e720765060453c856865be569`（双亲 `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec`／`d763ce5105612f72bfc6ffab31d3a35c025ee330`，树 `9297cd1b6f3258e16919c18afa5f868d28306c25` 与 C 提交的树相同）。合并后 `main` CI **#405**（run `38013766152`）绿：995 项 0 失败，artifact `PhotoCleanupMVE-unsigned-c889ca64239b`（id `11655559241`，有效期至 2027-01-08T01:35:31Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 5 个、B 5 个、C 5 个），卡面测试 C（`testIC200C_SourceWiring`）及三个随改既有测试涉及的计数与工作树实测逐条相等（A 提交前 43 项、B 提交前累计 84 项、C 提交前累计 88 项，0 处不符）；提交后 `check_ic200.py` A／B／C 三个 tip 全 PASS（7／7、12／12、16／16）。
- **有界面变化，人工判定项 H105 十六条保留给 Lynn 真机判定（第十一节原样转录），执行端没有做任何真机或观感判断。**
- **需要决策会话读一下的一件事（第十四节发现 1，不是红）：`testIC200D` 窗口宿主探针在 CI 模拟器上两行读数都停在静止位置**——`contentOffsetY=-54.0`，既没有看到「新建后按记下的 600 恢复」，也没有看到外层 `ScrollViewReader` 穿过容器内层 reader 滚到第 30 格（期望约 600 与 1500）。两行原文见第九节。按卡面「只打印、不据此判红绿」，我没有因此停卡或改任何东西，合并照卡执行；但这两行读数既没有证实也没有证伪卡的机制（复核 N1／N2），建议在 Lynn 花时间做 H105 之前先看一眼。
- 本次没有停卡项，没有执行端偏离卡面的改动，**分支推送与 `main` 推送都没有被分类器拦截**（均 git 直连、第一次即成功），没有任何一次 CI 红。红因清单 (1)(2)(3) 点名的编译风险（容器的泛型 `@ViewBuilder` 构造、`State(initialValue:)` 播种、`.background(alignment:)`／`.overlay(alignment:)`、`.onChange(of:initial:)` 两参闭包写类属性、首页 `init` 给 `_openedCardID` 赋值、类别页容器闭包、流程容器闭包、测试里 `S1OpenCardState()`／`S0CleanupFlowModel()` 无参构造与 `objectWillChange.sink`）一项都没触发：两次整包日志里 swift error 行 0 条，`warning:` 行共 48 条、指向本卡改动文件的 0 条。
- 脚本：`materialize_ic200.py`、`gen_ic200_card.py` 未跑（明令不跑）；`sim_ic200.py` 未跑（我的对读用自己写的脚本直接在工作树上做，口径与测试 `stripped()` 一致，见第四节）。`Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（脚本一律 `python -B`，`__pycache__` 不存在）；我的临时脚本、克隆与日志全部在 scratchpad `ic200-exec/`。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-200-scroll-restore.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-200.md`；取定 `Tasks/PLAN-NAVR-scroll-restore-rulings-20261009.md`（第二节是本卡）；复核结论 `Tasks/REVIEW-IC-200-findings.md`（已读第五节「决策会话处置」；复核员的「建议改法」不作指令，改法以卡与 `stages/` 为准）。`CLAUDE.md` 随会话上下文完整载入。
- 继承提交 / 基线：`main` = `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec`（IC-199 报告补记；merge `71a58366f2225759133a327cff2e0f4405f9c010`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 71a58366f2225759133a327cff2e0f4405f9c010 main` 退出码 0；`git ls-remote origin refs/heads/main` = `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec`；11 个被改文件基线 blob 与卡面表逐个相等（`git rev-parse HEAD:<路径>` 与 `git hash-object <路径>` 两者一致）：

| 路径 | 基线 blob（实测，与卡面一致） |
|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `7cef47ff0c3a43fed291aa119b677925b012ead5` |
| `PhotoCleanupMVE/Core/S1OpenCardState.swift` | `20dc6b0a5df240aeefeb4af69608f7e4c0b1dc92` |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift` | `ae239996a8af870a036174e9c15fee2f2aebb0c8` |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | `b96943cd095bde7bd813f81ca609118660528783` |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | `e5c9f912b328f263756d0ef3baeb95d1d8941a07` |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | `8f11c1559205c9f0e247438c2ad27b1ed41da1ea` |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | `414f05a9bb883551185f2da78cd0b2569f8992c1` |
| `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | `0402ea5fb043101a9ca38f296293399827a6422a` |
| `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift` | `2990af15cfceb883086baede9e58f633c5c065cc` |
| `PhotoCleanupMVETests/IC171CategoryPageTrioTests.swift` | `f38038aaa717f23254c6b808d5954810942be9fb` |
| `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | `a5ffe00d94eb1dc7c28581679a82774e3ebd0ba4` |

  先切分支再改文件（`git checkout -b feature/ic-200-scroll-restore` 之后才拷入第一个文件）。仓库里两个更早就存在的 stash（挂在 `feature/ic-067-screenshot-detection`）按提示词没有动。
- 目标分支：`feature/ic-200-scroll-restore`，合并入 `main`。
- 范围边界：白名单 14 路径，`git diff --name-only 320f9e92e1d3adef2b0fee6ab96beff52b44a8ec..d763ce5105612f72bfc6ffab31d3a35c025ee330` 恰这 14 行。状态机、协调器、App、S2／S3、`S1DeckCards.swift`、`S0BasketEntryView.swift`、`Localizable.xcstrings`（目录条数不变）、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）、`Scripts/`、`.github/` 一字未动。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `aa58a8abec8c6f51e9e50f047b59c830ffe8a2bd` | `9e61bd31431549de0789ab95bbe2c660a2027838` | 新文件 `Core/ScrollOffsetMemory.swift`（16 行）、`Features/Shared/OffsetRestoringScrollView.swift`（87 行）；`S1OpenCardState.swift`（+7）、`S0CleanupFlowModel.swift`（+6）、`project.pbxproj`（+8）。5 个路径，+124／−0 |
| B | `1b77034d91492b35e0cabb42a33a6ff761e6bb0f` | `1025367d85be66c4497051f346a0d7c14fb29016` | `S0CleanupFlowView.swift`（+13／−2）、`S0DeckCategoryPageView.swift`（+10／−1）、`S0DeckHomeView.swift`（+13／−2）、`S1View.swift`（+4／−1）、`S1YearPageView.swift`（+2／−1）。5 个路径，+42／−7 |
| C | `d763ce5105612f72bfc6ffab31d3a35c025ee330` | `9297cd1b6f3258e16919c18afa5f868d28306c25` | 新测试 `IC200ScrollRestoreTests.swift`（+380，四条）、`IC167BasketEntryAndTailTests.swift`（+2／−1）、`IC171CategoryPageTrioTests.swift`（+6／−4）、`IC192PageHeaderTests.swift`（+3／−1）、`project.pbxproj`（+4）。5 个路径，+395／−6 |
| 合并 | `c889ca64239b3b9e720765060453c856865be569` | `9297cd1b6f3258e16919c18afa5f868d28306c25` | `merge(IC-200): 路由往返后的滚动位置与展开卡恢复——四处滚动容器按记下的偏移回到原位、首页展开卡跨往返保留` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-200/` 两个文件） | — | 本报告与 `change-list.md` |

基线..C 合计 561 增 13 删（`git diff --numstat`：`project.pbxproj` 12／0、`S1OpenCardState.swift` 7／0、`ScrollOffsetMemory.swift` 16／0、`S0CleanupFlowModel.swift` 6／0、`S0CleanupFlowView.swift` 13／2、`S0DeckCategoryPageView.swift` 10／1、`S0DeckHomeView.swift` 13／2、`S1View.swift` 4／1、`S1YearPageView.swift` 2／1、`OffsetRestoringScrollView.swift` 87／0、`IC167…Tests.swift` 2／1、`IC171…Tests.swift` 6／4、`IC192…Tests.swift` 3／1、`IC200ScrollRestoreTests.swift` 380／0）。

## 四、逐子项提交前对读、拷入文件 `git hash-object`

脚本（scratchpad `ic200-exec/verify_counts.py`）：读**工作树**文件，用与测试 `stripped()` 同口径的剔注释、剔字符串字面量函数（直接 `import` 了 `Tasks/decision-tools/strip.py` 的 `strip_text`，只读），把 `testIC200C_SourceWiring` 的全部断言（含 `slice`／`assertOrder`、产品全局的文件集合两组）与三个随改既有测试（IC167B、IC171C×2、IC192D）的新期望原样移植，在拷入之后、提交之前逐条数；A 只跑 A 作用域，B 累计加页面接线与随改既有测试的流程容器／页面计数，C 累计加产品全局文件集合与 IC192D。全部相符才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic200.py` 又用 git 对象核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `3b0ba9465f524c855688b995c0209ddc2728832a` | `3b0ba9465f524c855688b995c0209ddc2728832a` | 相等 |
| A | `PhotoCleanupMVE/Core/S1OpenCardState.swift` | `d97a4ae7c3431b70fb173f5ca859814a06a3e37b` | `d97a4ae7c3431b70fb173f5ca859814a06a3e37b` | 相等 |
| A | `PhotoCleanupMVE/Core/ScrollOffsetMemory.swift` | `52b72ecabd5e61131d28ab2b80dd3705b2728816` | `52b72ecabd5e61131d28ab2b80dd3705b2728816` | 相等 |
| A | `PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift` | `39cc33f77db2b72f3d6545f689078c5b842e10c6` | `39cc33f77db2b72f3d6545f689078c5b842e10c6` | 相等 |
| A | `PhotoCleanupMVE/Features/Shared/OffsetRestoringScrollView.swift` | `73318c907fbdce4a2159afcf4462c1b41d0d1f6c` | `73318c907fbdce4a2159afcf4462c1b41d0d1f6c` | 相等 |
| B | `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | `a6de5cfa2cb16692f6d802d836f428de60763e34` | `a6de5cfa2cb16692f6d802d836f428de60763e34` | 相等 |
| B | `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | `3d166890ac0a231f52b8a0317054dd46ee131073` | `3d166890ac0a231f52b8a0317054dd46ee131073` | 相等 |
| B | `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | `348b177f5e1c3215bc940f737f557fc68044076d` | `348b177f5e1c3215bc940f737f557fc68044076d` | 相等 |
| B | `PhotoCleanupMVE/Features/S1/S1View.swift` | `e15a06d2528316222ac902fa3f170e97f5424b58` | `e15a06d2528316222ac902fa3f170e97f5424b58` | 相等 |
| B | `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | `dc66cf445841447595a83d4ac52ac4f7b4c87912` | `dc66cf445841447595a83d4ac52ac4f7b4c87912` | 相等 |
| C | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `6d7fdc4ed99a2522938656f60cc4aa4ee842ce20` | `6d7fdc4ed99a2522938656f60cc4aa4ee842ce20` | 相等 |
| C | `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift` | `5a8335d52f9e016c0a06f2a3536722c884401926` | `5a8335d52f9e016c0a06f2a3536722c884401926` | 相等 |
| C | `PhotoCleanupMVETests/IC171CategoryPageTrioTests.swift` | `90e6123e4e1c6ed9e3cf3be2357ded7e830b7ae7` | `90e6123e4e1c6ed9e3cf3be2357ded7e830b7ae7` | 相等 |
| C | `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | `3d03499fccc887229e8d68dc1a6d8c33f232a85e` | `3d03499fccc887229e8d68dc1a6d8c33f232a85e` | 相等 |
| C | `PhotoCleanupMVETests/IC200ScrollRestoreTests.swift` | `e7cd9252c6c7283d5ca867252c1c90f53efa86b8` | `e7cd9252c6c7283d5ca867252c1c90f53efa86b8` | 相等 |

每个子项拷入之后 `git status --porcelain` 只列该子项的文件（A：` M project.pbxproj`、` M …/S1OpenCardState.swift`、` M …/S0CleanupFlowModel.swift`、`?? …/ScrollOffsetMemory.swift`、`?? …/OffsetRestoringScrollView.swift`；B：五个 ` M` 页面文件；C：` M project.pbxproj`、三个 ` M` 测试、`?? …/IC200ScrollRestoreTests.swift`），按清单逐个 `git add <路径>`（未用 `-A`）。

**子项 A 提交前计数实测**（`ScrollOffsetMemory.swift`、`OffsetRestoringScrollView.swift`、`S1OpenCardState.swift`、`S0CleanupFlowModel.swift`，剔注释与字符串；每行「实测／卡面（测试 C）」，43 项 0 处不符）

| 检查 | 实测／卡面 |
|---|---|
| 容器剔注释：`struct OffsetRestoringScrollView<Content: View>: View {`、`ScrollViewReader { proxy in`、`ScrollView {`、`.coordinateSpace(.named(OffsetRestoringScrollMetrics.coordinateSpaceName))`、`geometry.frame(in: .named(OffsetRestoringScrollMetrics.coordinateSpaceName)).minY`、`memory.offset = ScrollOffsetMemory.offset(forContentMinY: minY)`、`_restoreTarget = State(initialValue: restores ? memory.offset : 0)`、`.task {`、`guard restoreTarget > 0 else {`、`@State private var hasRestored = false`、`guard !hasRestored else {`、`hasRestored = true`、`initial: true`、`proxy.scrollTo(OffsetRestoringScrollMetrics.anchorID, anchor: .top)`、`.padding(.top, restoreTarget)`、`.id(OffsetRestoringScrollMetrics.anchorID)` | 各 1／1（16 项） |
| 同文件：`@Published`、`@MainActor`、`L10n.` | 各 0／0 |
| 容器次序：锚点切片 `.frame(height: …anchorHeight)` < `.id(…anchorID)` < `.padding(.top, restoreTarget)`；`.task {` < `guard !hasRestored else {` < `hasRestored = true` < `guard restoreTarget > 0 else {` < `proxy.scrollTo(…)` | 成立／成立 |
| 容器原文：`import `；`Text("`；`return "` | 1／1；0／0；0／0 |
| 记忆剔注释：`final class ScrollOffsetMemory {`；`var offset: CGFloat = 0`；原文 `import `、`import CoreGraphics`、`import Foundation`；`ObservableObject`、`@Published`、`SwiftUI`、`@MainActor`、`L10n.` | 1／1；1／1；2／2、1／1、1／1；各 0／0 |
| `S1OpenCardState`：`let listScroll = ScrollOffsetMemory()`；`let yearPageScroll = ScrollOffsetMemory()`；`yearPageScroll.offset = 0`；`@Published private(set) var`；`setYearPageRangeID` 切片次序 `guard yearPageRangeID != rangeID else {` < `yearPageRangeID = rangeID` < `if rangeID == nil {` < `yearPageScroll.offset = 0` | 1／1；1／1；1／1；2／2；成立 |
| `S0CleanupFlowModel`：`let homeScroll = ScrollOffsetMemory()`；`let categoryScroll = ScrollOffsetMemory()`；`var preservedOpenCardID: String? = nil`；`@Published` | 1／1；1／1；1／1；1／1 |

pbx（A 提交前）：对象定义 297 条、重复 id 0；最大号 fileRef `10000000000000000000009F`、buildFile `20000000000000000000009C`；`10000000000000000000009E`／`20000000000000000000009B`／`10000000000000000000009F`／`20000000000000000000009C` 各已定义，出现行数 3／2／3／2。

**子项 B 提交前计数实测**（A 的 43 项同样复核仍相符，累计 84 项 `PASS`、0 项 `FAIL`；下列为 B 新增的 41 项）：

| 检查 | 实测／卡面 |
|---|---|
| `S1View`：`OffsetRestoringScrollView(memory: machine.openCards.listScroll) {`；`ScrollView {`；`ScrollViewReader`；`machine.openCards.listScroll.offset = 0` | 1／1；0／0；0／0；1／1；`selectDimension` 切片次序 `guard machine.switchGroupingDimension(to: dimension) else {` < `machine.openCards.listScroll.offset = 0` 成立 |
| `S1YearPageView`：`OffsetRestoringScrollView(memory: openCards.yearPageScroll) {`；`ScrollView {` | 1／1；0／0 |
| `S0DeckHomeView`：`OffsetRestoringScrollView(memory: scrollMemory) {`、`@State private var openedCardID: String?`、`_openedCardID = State(initialValue: initialOpenedCardID)`、`initialOpenedCardID: String? = nil`、`onOpenedCardChange: @escaping (String?) -> Void = { _ in }`、`scrollMemory: ScrollOffsetMemory = ScrollOffsetMemory()`、`onOpenedCardChange(identifier)`、`openedCardID = identifier`；`ScrollView {` | 各 1／1；0／0；次序 `openedCardID = identifier` < `onOpenedCardChange(identifier)` 成立 |
| `S0DeckCategoryPageView`：`memory: flowModel.categoryScroll,`、`restores: flowModel.preservedScrollAnchor == nil`、`ScrollViewReader { proxy in`、`restoreScrollAnchor(using: proxy)`、`flowModel.categoryScroll.offset = 0`；`ScrollView {` | 各 1／1；0／0；长按次序 `flowModel.preservedScrollAnchor = isHeaderCollapsed ? item.id : nil` < `if !isHeaderCollapsed {` < `flowModel.categoryScroll.offset = 0` 成立；`scrollContent` 切片次序 `OffsetRestoringScrollView(` < `scrollOffsetReader` < `header(width: width)` < `gridContent(width: width)` 成立 |
| `S0CleanupFlowView`：`initialOpenedCardID: flowModel.preservedOpenCardID`；`flowModel.preservedOpenCardID = identifier`；`scrollMemory: flowModel.homeScroll`；`flowModel.categoryScroll.offset = 0`；`flowModel.preservedScrollAnchor = nil`；`onEnterConfirmation()` | 1／1；1／1；1／1；2／2；3／3；1／1；`enterCategory` 与 `leaveCategory` 两个切片内 `flowModel.categoryScroll.offset = 0` 各 1／1 |
| IC167B（随改）：流程容器 `onEnterConfirmation: onEnterConfirmation` | **2 → 1**（基线实测 2，B 后实测 1，新期望 1） |
| IC171C（随改）：流程容器 `flowModel.preservedScrollAnchor = nil`；`enterCategory` 切片内；`leaveCategory` 切片内；流程容器 `preservedScrollAnchor`；页面 `flowModel.preservedScrollAnchor`；页面 `scrollPosition`；页面 `proxy.scrollTo(anchor, anchor: .center)` | **2 → 3**；1／1；1／1；**2 → 3**；**2 → 3**；0／0；1／1（基线实测 2／2／2，B 后实测 3／3／3） |

pbx 与测试计数此时尚未改（C 才改）：本阶段不计。**A→B 时 IC167B／IC171C×2／IC192D 按卡面必红，我没有推 CI。**

**子项 C 提交前计数实测**（累计 88 项，0 处不符；下列为 C 新增的 4 项，B 的全部项同样复核仍相符）：

| 检查 | 实测／卡面 |
|---|---|
| 产品全局（剔注释与字符串）含 `ScrollOffsetMemory()` 的文件 | `S1OpenCardState.swift`、`S0CleanupFlowModel.swift`、`S0DeckHomeView.swift`（恰这三个，对卡面） |
| 产品全局含 `OffsetRestoringScrollView(` 的文件 | `S1View.swift`、`S1YearPageView.swift`、`S0DeckHomeView.swift`、`S0DeckCategoryPageView.swift`（恰这四个） |
| IC192D（随改）：`S1View.swift` `OffsetRestoringScrollView(memory: machine.openCards.listScroll) {`；`ScrollView {` | 1／1；0／0（基线 `ScrollView {` 实测 1） |
| pbx（C 提交前，见第十节） | 对象定义 299 条、重复 id 0 |
| 新文件 `func test*`；测试目录 `func test` 行（grep 口径，含注释行） | 4 条；基线 1000 → C 后 1004（差值 +4，陷阱 22：本机 grep 只作差值预估，CI 以 `Executed N tests` 为准） |

`git diff --cached --check` 三个提交各自提交前退出码 0。

## 五、`check_ic200.py` 三段 SUMMARY 与摘取实测

`check_ic200.py` 在刚提交的 tip 上跑（基线取脚本默认值 `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec`，`IC_REPO=D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE`，`python -B`，在 `Tasks/decision-tools/` 里运行，tip 先 `tr -d '\r'`；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `aa58a8abec8c6f51e9e50f047b59c830ffe8a2bd` | `SUMMARY 7 pass / 7`（blob 5 + `changed paths == whitelist (5)` + `base is ancestor`） | 0 |
| B | `1b77034d91492b35e0cabb42a33a6ff761e6bb0f` | `SUMMARY 12 pass / 12`（blob 10 + `changed paths == whitelist (10)` + `base is ancestor`） | 0 |
| C | `d763ce5105612f72bfc6ffab31d3a35c025ee330` | `SUMMARY 16 pass / 16`（blob 14 + `changed paths == whitelist (14)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

**摘取关系实测**（克隆 `git clone --no-hardlinks` 到 scratchpad `ic200-exec/clone`，克隆成功；命令全部带 `git -C <克隆>`，从未落到原仓；克隆里自基线 `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec` 起 `checkout -B`，对我的真实三个提交 `cherry-pick -x`；只证文本无冲突，绿由 CI 证；克隆里的新提交 SHA 不属于原仓，故不写入本报告）：

| 组合 | 退出码 | 结果树 | 备注 |
|---|---|---|---|
| A 单独 | 0 | `9e61bd31431549de0789ab95bbe2c660a2027838` | 与分支上 A 提交的树相同；`git status --porcelain` 空；改动路径 5 个；**未推 CI** |
| A → B | 0 | `1025367d85be66c4497051f346a0d7c14fb29016` | 与分支上 B 提交的树相同；`git status --porcelain` 空；改动路径 10 个；未推 CI（IC167B／IC171C×2／IC192D 此时按卡面必红） |
| A → B → C | 0 | `9297cd1b6f3258e16919c18afa5f868d28306c25` | 与分支上 C 提交的树、合并提交的树相同；`git status --porcelain` 空；改动路径 14 个；该组合即推 CI 的 #404 |

## 六、本地门禁（三个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 在 PowerShell 工具里在仓库根以 `powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\….ps1` 跑，取 `$LASTEXITCODE`（A 提交前的 `selfcheck.ps1` 那一次我是把输出接到 `Select-Object -Last 25` 之后读的 `$LASTEXITCODE`，B、C 两次先把输出存进变量再读；三次末行都是「结构自验通过」）；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0 | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） | 0 |
| B | 0 | 0（同） | 0 |
| C | 0（含新测试文件，「扫描 77 个测试源文件，无 needle 喂错源码变体」） | 0（同） | 0 |

## 七、验收门禁逐条（G1095～G1099）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1095 行为与落位 | 满足 | 第五节：`check_ic200.py` A、B、C 三个 tip 全 PASS |
| G1096 新断言 | 满足 | `testIC200A`～`C` 与改过的 `testIC167B_BasketEntryReachesConfirmationAndFailedStateAccepts`、`testIC171C_ScrollAnchorIsUnpublishedAndClearedOnCategoryChange`、`testIC171C_PageRestoresLongPressedCellOnce`、`testIC192D_SourceWiring` 在 #404 与 #405 整包日志里全部 passed（第八、九节）；`testIC200D` 也 passed（只打印、不断言） |
| G1097 不回退 | 满足 | `IC160SelectionSurvivesS2Tests`（4）、`IC165DeckFormalTests`（6）、`IC166RestCategoryTests`（6）、`IC178DeckListTests`（2）、`IC191DeckDataTests`（4）、`IC193V1DeckTests`（4）、`IC157LongPressIntoS2Tests`（8）、`IC156CategoryPageTests`（9）、`IC147S0BehaviorTests`（16）、`IC148S0VisualTests`（12）、`S1StateMachineTests`（20）在 #404 整包日志里按唯一 Test Case 行数全部 passed、0 failed；#405 整包唯一 Test Case 行 995 passed／0 failed 同样覆盖 |
| G1098 合并前置 | 满足 | G1095～G1097 + CI #404 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice；摘要 995 与 xcodebuild 小计 995 一致，无需按第 217 条第四节另核，唯一 Test Case 行 995 passed／0 failed，已开始 995 = 已结束 995）+ 45 条被保护分支 tip 未变（第十二节）+ pbxproj 撞号扫描（第十节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote --heads origin` 里 `main` 仍为 `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec`） |
| G1099 合并后 | 满足 | 合并后 `main` CI #405 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #404 | 合并后 `main` 运行 #405 |
|---|---|---|
| run id | `38012680912` | `38013766152` |
| 被测提交 | `d763ce5105612f72bfc6ffab31d3a35c025ee330` | `c889ca64239b3b9e720765060453c856865be569` |
| 触发 | push 到 `feature/ic-200-scroll-restore` | push 到 `main` |
| 作业起止 | 2026-10-10T01:18:49Z～01:32:55Z | 2026-10-10T01:35:39Z～01:51:09Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 995 项，0 失败（xcodebuild `Executed 995 tests, with 0 failures (0 unexpected) in 61.396 (68.084) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 995 passed／0 failed，无「已开始未结束」） | 995 项，0 失败（`Executed 995 tests, with 0 failures (0 unexpected) in 58.847 (65.172) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 995 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 995 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 995 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`；日志 `XCTest 已全部通过。`） | 0（同） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；xcodebuild 匹配行 `{ … OS:26.2, name:iPhone 16 }` | 同一两行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2101127 字节，SHA-256 `5ee686b134f5b4cb58ea8f9d1869668bff1c63368fe0f0feb37744b06b0f9eb8` | 2101127 字节，SHA-256 `4dd271f746d4c3588450dd91716b2bbf3f7355a78879ff953ae890885bceca63`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 100 s；xcodebuild test 426 s；总 529 s` | `模拟器启动 88 s；xcodebuild test 562 s；总 651 s` |
| artifact | `PhotoCleanupMVE-unsigned-d763ce510561`，id `11655427070`，2101297 字节，有效期至 2027-01-08T01:18:42Z | `PhotoCleanupMVE-unsigned-c889ca64239b`，id `11655559241`，2101297 字节，有效期至 2027-01-08T01:35:31Z |
| 四条 `testIC200*` 与三个随改既有用例耗时（日志 `Test Case … passed (N seconds)`） | `testIC200A` 0.001 s；`testIC200B` 0.001 s；`testIC200C` 0.228 s；`testIC200D` 1.041 s；`testIC167B_BasketEntryReachesConfirmationAndFailedStateAccepts` 0.008 s；`testIC171C_ScrollAnchorIsUnpublishedAndClearedOnCategoryChange` 0.003 s；`testIC171C_PageRestoresLongPressedCellOnce` 0.012 s；`testIC192D_SourceWiring` 0.366 s | `testIC200A` 0.002 s；`testIC200B` 0.001 s；`testIC200C` 0.245 s；`testIC200D` 1.063 s；IC167B 0.005 s；IC171C 滚动锚点 0.003 s；IC171C 页面恢复 0.016 s；IC192D 0.434 s |

- 两次构建日志里 swift error 行 0 条；`warning:` 行各 48 条，指向本卡改动文件（含新文件与三个随改测试）的 0 条，没有类型检查超时、result builder 报错或扫描器红。整包日志里出现一次 `** TEST FAILED **` 字样是工作流自测步骤脚本的源码回显（`many_test_failed_lines=… '** TEST FAILED **'`，陷阱 25 的 ANSI 回显），不是实跑输出；真实输出只有 `** TEST SUCCEEDED **`。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）：`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` #404 6.377 s passed；两次日志里 `building pipeline` 均 0 次，各有两处 `Invalidating cache`。
- CI 预算 3 次，用了 1 次（#404）；#405 为合并后 `main` 运行，不计入试错预算。

## 九、新断言与 `testIC200D` 探针读数

四条新断言（`PhotoCleanupMVETests/IC200ScrollRestoreTests.swift`，逐字节拷入，blob `e7cd9252c6c7283d5ca867252c1c90f53efa86b8`，380 行）：

| 断言 | 函数名 | 内容（据卡面 C 节） |
|---|---|---|
| A | `testIC200A_OffsetMathAndYearPageResetRule` | `minY` 0／−120／35 → 偏移 0／120／0；两只记忆不同对象；点月卡换展开不归 0、同值不写、置 nil 归 0、已 nil 再置 nil 不写；列表页记忆与列表页展开卡都不受影响 |
| B | `testIC200B_FlowModelMemoriesAreUnpublished` | 三项新字段初值 0／0／nil、两只记忆不同对象；写它们不发 `objectWillChange`；正对照 `presentedCategory` 照发 1 次 |
| C | `testIC200C_SourceWiring` | 容器（读写器 `initial: true`、恢复目标按新建时播种、`.task` 以 `hasRestored` 闸住只滚一次且偏移 0 不滚、锚点 `.id` 在 1 pt 那一层、`padding` 在外、纪律）；`S1View` 换维度归 0 的次序；类别页长按页头未收起归 0 的次序；记忆文件纪律；`S1OpenCardState` 两只记忆与 `setYearPageRangeID` 次序；四处调用点各 1 且原 `ScrollView {` 0；首页三个新形参、播种、写入后回报的次序；类别页 `restores:` 条件、外层 `ScrollViewReader` 照旧、滚动内容次序；流程容器传值、两处归 0、`preservedScrollAnchor = nil` 3；流程模型字段与 `@Published` 1；产品里构造记忆的恰三个文件、用容器的恰四个页面 |
| D | `testIC200D_ProbeRestoreAndNestedReaderInWindow`（`@MainActor`，**只打印、不断言**） | `UIHostingController` + `UIWindow`（390×844）里，外层 `ScrollViewReader` 包本卡容器、容器里 60 格 × 50 pt、记忆偏移 600；打印新建后 `contentOffset.y`，再由外层 reader `scrollTo("probe-cell-30", anchor: .top)` 后再打印一次（卡面期望约 600 与 1500） |

**`testIC200D` 打印的两行 `IC200_PROBE` 原文**（#404 与 #405 完全相同；下为 #404 整包日志原行，含时间戳前缀）：

```
2026-10-10T01:26:18.0071280Z IC200_PROBE restore target=600 contentOffsetY=-54.0 memory=-0.0
2026-10-10T01:26:18.5296460Z IC200_PROBE nested-reader cell30Top=1500 contentOffsetY=-54.0 memory=-0.0 proxy=true
```

#405 对应两行为 `IC200_PROBE restore target=600 contentOffsetY=-54.0 memory=-0.0` 与 `IC200_PROBE nested-reader cell30Top=1500 contentOffsetY=-54.0 memory=-0.0 proxy=true`。**按卡面「执行端在报告里原样抄这两行，不据此判红绿」，我不据此判断；解读见第十四节发现 1。**

随改的既有断言：`IC167BasketEntryAndTailTests` 测试 B（第二个 B）`onEnterConfirmation: onEnterConfirmation` 2 → 1，blob `5a8335d52f9e016c0a06f2a3536722c884401926`；`IC171CategoryPageTrioTests` 测试 C（两个 C）流程容器 `flowModel.preservedScrollAnchor = nil` 2 → 3、`preservedScrollAnchor` 2 → 3、页面 `flowModel.preservedScrollAnchor` 2 → 3，blob `90e6123e4e1c6ed9e3cf3be2357ded7e830b7ae7`；`IC192PageHeaderTests` 测试 D `("ScrollView {", 1)` → `OffsetRestoringScrollView(memory: machine.openCards.listScroll) {` 1 + `ScrollView {` 0，blob `3d03499fccc887229e8d68dc1a6d8c33f232a85e`；其余既有测试未改。

**项数对账**：991 + 4 = **995**；#404 与 #405 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行数三者都是 995；提交前本机新文件 `func test*` 4 条、测试目录 `func test` 行（grep 口径）1000 → 1004，与之相符。

## 十、pbxproj 撞号扫描与六个新 id

- 推进前扫描（脚本 `ic200-exec/pbx_scan.py` 读工作树，正则取 `\t\t<24 位十六进制> /* … */ = {isa = PBXBuildFile|PBXFileReference;` 定义行，**十六进制**比较）：基线最大号 fileRef `10000000000000000000009D`、buildFile `20000000000000000000009A`（IC-199）。对象定义条数：基线 293 条（`git show` 基线文件实测）→ A 拷入后 297 条（+4：两个新产品文件各一条 fileRef 与一条 buildFile）→ C 拷入后 299 条（+2：新测试一条 fileRef 与一条 buildFile）；C 提交前：重复 id 0，「被引用但无顶层定义」的 id 0；最大号 fileRef `1000000000000000000000A0`、buildFile `20000000000000000000009D`。
- 六个新 id 各自在全文的出现行数（C 提交前）：`10000000000000000000009E`（`ScrollOffsetMemory.swift` fileRef）3 行、`20000000000000000000009B`（buildFile）2 行；`10000000000000000000009F`（`OffsetRestoringScrollView.swift` fileRef）3 行、`20000000000000000000009C`（buildFile）2 行；`1000000000000000000000A0`（`IC200ScrollRestoreTests.swift` fileRef）3 行、`20000000000000000000009D`（buildFile）2 行；每个都只有 1 处定义，基线里六者各 0 行。
- 接在谁后面：`ScrollOffsetMemory.swift` 接在 `S1OpenCardState.swift` 之后、`OffsetRestoringScrollView.swift` 接在 `NavigationEdgeSwipeBack.swift` 之后、`IC200ScrollRestoreTests.swift` 接在 `IC199S2SortMenuWiringTests.swift` 之后（与卡面一致，逐字节拷入）。

## 十一、人工判定项 H105（**保留给 Lynn 真机判定；执行端不代为下结论**）

装合并后 `main` 产物（`PhotoCleanupMVE-unsigned-c889ca64239b`，id `11655559241`）。以下十六条原样转录自任务卡：

1. 前置：先让待删篮里有几张（任意一页上滑标记几张），否则页头／顶排的待删篮入口不可点、走不了「进确认页再返回」那几条。
2. 「逐张整理」列表页往下滚到中下部、点开一张年卡（或相册卡）后点「去清理」进年页、在年页再滚下去、点一张月卡「去整理」进看图，左上返回：回到年页、年页滚动位置与展开的月卡不变；再返回列表：列表滚动位置与展开的那张卡不变。
3. 列表页往下滚、点开一张相册卡（或「未分类」）「去整理」进看图再返回：列表回到原位置、那张卡仍展开。
4. 列表页（或年页）往下滚、点页头右上待删篮进确认页再返回：位置不变。
5. 从年页返回列表后，再进同一年（或另一年）：年页从顶部开始、第一张月卡展开。
6. 「空间清理」首页点开某一张卡（不是第一张）并往下滚，点右上待删篮进确认页再返回：同一张卡仍展开、位置不变。
7. 首页点开某张卡进类别页、类别页往下滚过页头（页头收起），点顶排待删篮进确认页再返回：回到类别页原位置（Lynn H93 第 7 条报的缺陷）。
8. 类别页往下滚、长按一格进看图再返回：仍是那一格居中（IC-171 不回退）；接着再点顶排待删篮进确认页再返回：回到点待删篮时的位置（不是长按那一格）。
9. 类别页返回首页、再进同一类别：从顶部开始。
10. 两个 tab 之间来回切：各自位置不变；**做过一次进看图再返回之后**，再往下滚一段、切到另一个 tab 再切回（或进年页／类别页再返回）：停在刚滚到的位置，不会被拽回「刚回来那一刻」的位置。
11. 「逐张整理」换分组维度（日期／相册／未分类）：新列表从顶部开始。
12. 连续做几次「往下滚 → 进看图 → 返回」：每次都回到当次的位置，不累积漂移。
13. 类别页页头还没收起时长按一格进看图再返回：从顶部开始（与改前一致）。
14. 恢复的那一下：是直接出现在原位置、还是先在顶部闪一下再跳过去（记现象）；页面很长（相册很多）时是否准确。
15. 杀掉重开：两个 tab 都从顶部开始、首页第一张卡展开。
16. 总评一两句。

夹具只证记忆换算、`S1OpenCardState` 年页归 0 规则、流程模型字段不发布与源码落位（陷阱 1）；真实滚动、`scrollTo` 的时机、嵌套 reader 穿透、坐标原点与安全区、切 tab 与弹回根页不重复恢复、恢复后的观感均未覆盖（陷阱 2，模拟器无法驱动真实滚动），归 H105。

## 十二、G1098 被保护分支核对

清单 `Tasks/decision-tools/ic200_protected_branches.txt` 恰 45 行（`分支名 SHA`，无注释行）。对 `git ls-remote --heads origin` 逐条比对三次：推送分支之前（远端 118 个 head）、推送分支后合并之前（119，含本分支）、合并并推送 `main` 之后（119）——**不符 0 条（45／45 相等）**；比对脚本（scratchpad `protected_cmp.py`）遇空列表即断言失败（空列表不算比对），本次每次第一次返回即非空。合并前 `main` = `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec`，合并后 `main` = `c889ca64239b3b9e720765060453c856865be569`（`git ls-remote` 复核一致）。

## 十三、规格欠账（卡面「规格欠账」节，本卡不改任何规格；归下一次 S1／S0 修订）

卡面该节写的是**九条**（卡末「报告」节写「七条（见上）」是笔误，见第十四节发现 2）：

1. S1 列表页「路由往返（进 S2／S3 再回来）后保留滚动位置」写进第二节呈现态（v12 只写了年页在前时与离开年页时）。
2. S1 年页同样保留，离开年页后再推入从顶部开始。
3. S0 首页 `OPEN` 跨路由往返保留（`:202` 只写了打开 App 时重取）、首页滚动位置同样保留。
4. S0 类别页经顶排待删篮进 S3 往返回到原位置（第十二节第 12 条结案）、长按锚点路径优先（`:362`）、长按时页头未收起照 `:362` 回来从顶部（偏移记忆归 0）、经待删篮进 S3 时清掉上一次的长按锚点。
5. 恢复按「内容顶部到视口顶部」的距离、不按卡——往返期间叠高变了（扫描结果变化）则未必是同一张卡（③）。
6. 记忆不入档，打开 App 从顶部开始。
7. 恢复时机为容器实例第一次出现时一次（`.task` + `hasRestored` 闸），真机若先在顶部闪一下再跳过去记入 H（③）。
8. S1 换分组维度后列表从顶部开始（v12 未写）。
9. 类别页排序态是页面 `@State`、往返后回到默认排序，而滚动按距离恢复——同一距离可能对着别的格子（③，待 Lynn 看是否要连排序一起保留）。

## 十四、发现但未处理的问题（按纪律只报告不修）

1. **（最重要，③）`testIC200D` 探针读数两行都停在静止位置。** 事实（①，#404 与 #405 各一次、读数相同）：窗口宿主里记忆偏移 600 的容器新建后 0.5 s，找到的 `UIScrollView` `contentOffset.y = -54.0`（等于静止时的顶部安全区内边距，即没有滚动），`memory` 被记录件改写成 `-0.0`；随后外层 `ScrollViewReader`（`proxy != nil`，已在 `onAppear` 里拿到）`scrollTo("probe-cell-30", anchor: .top)` 再等 0.5 s，`contentOffset.y` 仍是 `-54.0`。**解读（③，未经验证，只给决策会话参考）：** (a) 第一行说明在这个窗口宿主里，容器的「新建后第一次出现时 `.task` 里 `scrollTo(锚)`」没有把内容滚到记下的 600；(b) 第二行说明外层 reader 的 `scrollTo` 也没有滚动——但因为连最基础的内层 reader `scrollTo` 都没动，两行合起来**区分不了**「卡的机制（复核 N1 嵌套 reader／N2 overlay 里的 1 pt 锚）在 iOS 26 上真的不工作」与「这个宿主本身不驱动 `scrollTo`」（例如窗口只设了 `isHidden = false`，复核曾建议的是 `makeKeyAndVisible()`；0.5 s 的 runloop 内布局或 `.task` 还没到点也说得通）；(c) `memory=-0.0` 与 `contentOffsetY=-54.0` 同时出现，也与复核 N3 的担心相容——若容器的坐标空间原点在安全区之上，静止时内容顶部的 `minY` 就是 `+54` 而不是 `0`，记下的偏移会比真实偏移少一个安全区高度，往返会漂移（H105 第 12 条「连续几次不累积漂移」会兜住）。以上都是推测，我没有改任何东西、没有因此停卡（卡面明令不据此判红绿）。**建议**：决策会话读一眼这两行再决定 H105 要不要照卡面直接让 Lynn 做，或者先出一张只改探针宿主（`makeKeyAndVisible()`、拉长等待）的小卡拿到可信的模拟器读数。
2. **卡面内部笔误：** 卡「规格欠账」节写「九条」（并逐条列出 (1)～(9)），卡末「报告」节要求的却是「规格欠账**七条**（见上）」。我按九条转录（第十三节）。执行提示词第 29 行没提条数。
3. **`ScrollOffsetMemory.offset(forContentMinY:)` 对 `minY = 0` 返回 `-0.0`**（`max(0, -0.0)`），探针里 `memory=-0.0` 即此。无害：`testIC200A` 断言 `offset(0) == 0` 通过（`-0.0 == 0`），容器里 `restoreTarget > 0` 对 `-0.0` 为 false；只是显示上不好看。不修。
4. 其余：红因清单 (1)～(6) 一项都没触发；没有执行端偏离卡面；没有发现卡面与基线不符的事实（11 个基线 blob 全部相符、卡面 diff 与 stages 一致）。

## 十五、SHA 核验（陷阱 15）

本报告与 `change-list.md` 写完后，用脚本（scratchpad `ic200-exec/sha_verify.py`）取两份文件里出现的每一个 40 位十六进制串（排除属于更长十六进制串的片段，SHA-256 不在其内），先 `git cat-file -t` 取类型、再 `git cat-file -e <sha>^{类型}` 核存在；**共 35 个，全部退出码 0**（docs 提交自身的 SHA 不在报告里，故不核；其来源：提交与树取自 `git rev-parse`／`git log` 输出，blob 取自 `git hash-object`／`git rev-parse HEAD:<路径>` 输出，基线与 IC-199 合并提交取自卡面并经 `git rev-parse`／`is-ancestor` 核过）。

| SHA | 类型 | `git cat-file -e <sha>^{类型}` 退出码 |
|---|---|---|
| `0402ea5fb043101a9ca38f296293399827a6422a` | blob | 0 |
| `1025367d85be66c4497051f346a0d7c14fb29016` | tree | 0 |
| `1b77034d91492b35e0cabb42a33a6ff761e6bb0f` | commit | 0 |
| `20dc6b0a5df240aeefeb4af69608f7e4c0b1dc92` | blob | 0 |
| `2990af15cfceb883086baede9e58f633c5c065cc` | blob | 0 |
| `320f9e92e1d3adef2b0fee6ab96beff52b44a8ec` | commit | 0 |
| `348b177f5e1c3215bc940f737f557fc68044076d` | blob | 0 |
| `39cc33f77db2b72f3d6545f689078c5b842e10c6` | blob | 0 |
| `3b0ba9465f524c855688b995c0209ddc2728832a` | blob | 0 |
| `3d03499fccc887229e8d68dc1a6d8c33f232a85e` | blob | 0 |
| `3d166890ac0a231f52b8a0317054dd46ee131073` | blob | 0 |
| `414f05a9bb883551185f2da78cd0b2569f8992c1` | blob | 0 |
| `52b72ecabd5e61131d28ab2b80dd3705b2728816` | blob | 0 |
| `5a8335d52f9e016c0a06f2a3536722c884401926` | blob | 0 |
| `6d7fdc4ed99a2522938656f60cc4aa4ee842ce20` | blob | 0 |
| `71a58366f2225759133a327cff2e0f4405f9c010` | commit | 0 |
| `73318c907fbdce4a2159afcf4462c1b41d0d1f6c` | blob | 0 |
| `7cef47ff0c3a43fed291aa119b677925b012ead5` | blob | 0 |
| `8f11c1559205c9f0e247438c2ad27b1ed41da1ea` | blob | 0 |
| `90e6123e4e1c6ed9e3cf3be2357ded7e830b7ae7` | blob | 0 |
| `9297cd1b6f3258e16919c18afa5f868d28306c25` | tree | 0 |
| `9e61bd31431549de0789ab95bbe2c660a2027838` | tree | 0 |
| `a5ffe00d94eb1dc7c28581679a82774e3ebd0ba4` | blob | 0 |
| `a6de5cfa2cb16692f6d802d836f428de60763e34` | blob | 0 |
| `aa58a8abec8c6f51e9e50f047b59c830ffe8a2bd` | commit | 0 |
| `ae239996a8af870a036174e9c15fee2f2aebb0c8` | blob | 0 |
| `b96943cd095bde7bd813f81ca609118660528783` | blob | 0 |
| `c889ca64239b3b9e720765060453c856865be569` | commit | 0 |
| `d763ce5105612f72bfc6ffab31d3a35c025ee330` | commit | 0 |
| `d97a4ae7c3431b70fb173f5ca859814a06a3e37b` | blob | 0 |
| `dc66cf445841447595a83d4ac52ac4f7b4c87912` | blob | 0 |
| `e15a06d2528316222ac902fa3f170e97f5424b58` | blob | 0 |
| `e5c9f912b328f263756d0ef3baeb95d1d8941a07` | blob | 0 |
| `e7cd9252c6c7283d5ca867252c1c90f53efa86b8` | blob | 0 |
| `f38038aaa717f23254c6b808d5954810942be9fb` | blob | 0 |
