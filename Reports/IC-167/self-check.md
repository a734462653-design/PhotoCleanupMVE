# IC-167 自验报告：首页待删篮入口改「垃圾桶圆钮 + 徽标」并接 S3、展开末卡延伸到底、类别页排序加「从小到大」、类别页顶排待删篮入口

> 任务卡：`<top>/Tasks/IC-20260923-167-s0-basket-entry-tail-sort.md`（SPEC-S0 v4 实装第一张，可合并）
> 执行会话：2026-09-23。证据分级按 CLAUDE.md 第四节：①已验证事实、②样本观察、③合理推测、④项目判断。

## 一、结论（先行）

**交付完成，已合并入 `main`。** 五个子项各自独立提交、顺序 A → B → C → D → E；CI 预算 3 次只用 2 次，两次都一次绿：

| 子项 | 提交 | CI | 结果 |
|---|---|---|---|
| A 展开末卡 | `e82f2a5f5a7ebd9332bff7f8919f5ffc6f83e9e8` | 与 B、C 同推 | — |
| B 首页入口 + 接 S3 | `edea245f96bae51ac7d4589b7587b01c19df5b48` | 与 A、C 同推（卡定：B 单独必红，不单独取 CI） | — |
| C 排序四项 | `bddcb07a72c689fa6536452156d509f592263575` | **#337**（run 35920418182） | 一次绿，**871 项 0 失败**，真实退出码 0 |
| D 类别页入口 | `92b0b9234442e6a330c78545fd219fb811e692b5` | 与 E 同推 | — |
| E 新断言 | `fc6dd1436fa25b8298caca2f3d2266024859df4e` | **#338**（run 35922356087） | 一次绿，**876 项 0 失败**，真实退出码 0 |
| 合并 | `81effe7c388e6b18560ee284d4cab7d575eca2b1`（`--no-ff`，父 `e6cdabe` + `fc6dd14`，树 = E 的树） | **合并后 `main` 运行 #339（run 35924716225）** | 一次绿，**876 项 0 失败**，真实退出码 0 |

- G938～G943 全部满足（第六节逐条）。项数对账：871 →（A）871 →（B）871 →（C）871 →（D）871 →（E）876，与卡面一致①。
- 卡面「事实基础」表与「会红的既有断言」的旧 → 新值，执行端先用本机 Python 移植（源码扫描 helper 逐字符移植）独立复算，**全部相符**（惯例 43；第九节）。卡面唯一对不上的是一处行号：`S1StateMachine.reconcile` 的 `loadingState == .ready` 守卫在 `:524`，卡面写 `:530`（内容一致，不影响实装）。
- 合并在 Bash 工具一次通过，未被 `[Merge Without Review]` 拒绝。
- **报告落点（惯例 44）**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md` 同在其中）。报告引用的合并后运行编号与 artifact 都是该 docs 提交之前已产生的信息，不存在跨卡回填。
- 人工判定项 H87 八条保留给 Lynn 真机判，执行端不代为下结论（第十二节）。

## 二、输入、继承与范围

- 输入：`<top>/CLAUDE.md` 全文；`<top>/SPEC-S0-20260923_v4.md` 第三节第 1～4 部分、第四节、第六节、第十节第 3 部分、第十四节第 2／3 部分；`<top>/SPEC-S1-20260923_v10.md` 第一节决策 43 与第六节第 3 部分；任务卡全文。
- 继承：`main` = `e6cdabee804899c474eed3a3b9532f75838904c9`（IC-166 报告补记）。
- 目标分支：`feature/ic-167-s0-basket-entry-tail-sort`（自上述 `main` 切出，已推送，保留不删）。
- 范围边界：只做卡内五条裁定。未做（卡「本卡不做」与「范围外」）：S2 → S3 回落提示与诊断（IC-168）、S2 标记态按 `D_全部`（IC-169）、S1 现行入口的决策 30 对账、未定项 12 落点、人像圆钮改 40、S1 机器 `.loading` 根因修法、`S0DeckMetrics` 登记值增删、`S1View.swift` 任何改动、SPEC 与 Decision_log。

### 开工四步

1. `git status --porcelain` 输出为空，退出码 0。
2. `git merge-base --is-ancestor a6018ad990c80fe01445ffdfa4ed890735eb9589 main` 退出码 0；本地 `main` = `e6cdabee804899c474eed3a3b9532f75838904c9`。
3. `git ls-remote origin refs/heads/main` = `e6cdabee804899c474eed3a3b9532f75838904c9`，与本地一致。
4. 改任何文件之前 `git switch -c feature/ic-167-s0-basket-entry-tail-sort`。

## 三、五条裁定的落实

### 裁定 一：展开末卡延伸到底（子项 A）

- `S0DeckHomeView` 加 `static func cardExtension(index: Int, count: Int) -> CGFloat`（`:1030`）：`index == count - 1 ? lastCardTailHeight : cardOverhang`，裸数只有 `1`。
- `cardButton`（`:524`）：删 `isTail`，`let height = visible + Self.cardExtension(index: index, count: cards.count)`。
- `cardContent`：文字块与「去清理」底距改 `(height - visibleHeight) + openTextBottomInset`／`+ openActionBottomInset`（`:651`／`:666`，非末卡 `height - visibleHeight = cardOverhang`，数值与改前逐位相同）；既有 `S0DeckShade.open.frame(height: visibleHeight)` 不动，其后另加一层 `.overlay(alignment: .bottom) { if isOpen { Color.black.opacity(S0DeckMetrics.openShadeBottomOpacity).frame(height: height - visibleHeight) } }`（`:632-637`）。`deckHeight`／`offset(forIndex:)` 未动；不加登记值、不加动画。

### 裁定 二：共享入口 `S0BasketEntryView`（子项 B）

- 新文件 `Features/S0/S0BasketEntryView.swift`（只 `import SwiftUI`），`struct S0BasketEntryView: View`，形参 `style: Style`（`.glass`／`.flat`）、`count: Int`、`action: () -> Void`。body = `Button(action: action) { icon }.disabled(count == 0).accessibilityLabel(L10n.text("s1.trash.accessibility", replacing: ["count": String(count)])).overlay(alignment: .topTrailing) { if count > 0 { badge } }`。
- `icon`：`.glass` = 符号 + `S0DeckMetrics.text` + `s1ChromeCircleGlass()`；`.flat` = 符号 + `circleIconPointSize` 字号 + `compactNavBackSide` 方框 + `text.opacity(compactNavActionFillOpacity)` 圆底（与 `compactNavSort` 同写法）。
- `badge`：照 S1 `trashBadge` 逐行搬，七处 `S1NotificationBadgeStyle.`，描边色改 `S0DeckMetrics.background`；`Text(String(count))`；不用 `offset`、不登记新值。
- 首页 `topRow`：`if machine.accepts(.basketCapsule) { basketCapsule }` 换成 `S0BasketEntryView(style: .glass, count: machine.mergedPendingDeletionCount, action: onEnterConfirmation)`（`:134-136`）；删 `basketCapsule`。点击直接调 `onEnterConfirmation`，**不经** `machine.handle(.basketCapsuleTapped)`（首页 `machine.handle(` 仍 4）。
- 目录删 `s0.basket.capsule`（11 行外科删除）。IC147 断言 11 名单加新文件、借用集五条（`Set([...])`）；IC165 借用集五条。

### 裁定 三：接 S3、S0-4 对齐（子项 B）

- 流程容器：存储属性 `private let onEnterConfirmation: () -> Void`（`toastDurationMilliseconds` 之后）、init 末位形参 `onEnterConfirmation: @escaping () -> Void = {}`（带默认值，IC156 `:553-561` 七实参构造仍编译①，#337／#338）、赋值；首页构造在 `onEnterCategoryPage:` 与 `onSwitchToOrganizeTab:` 之间传入（`:102`）。
- App `s0Screen(s1Machine:)`（`:126-130`）末位实参：
  ```
  onEnterConfirmation: {
      coordinator.reconcileS1WithPhotoLibrary()
      guard let submission = s1Machine.makeS3Submission() else { return }
      _ = coordinator.enterConfirmationFromS1(submission)
  }
  ```
  三句各占一行（卡面原话），先对账后提交；协调器一字未动（`App/CleanupCoordinator.swift` blob 与 `e6cdabe` 同①）。App 文档注释 `:93` 的「首页待删篮胶囊 → S3 仍不接线（批次 5.3）」改为「IC-167 B：首页与类别页待删篮入口 → S3 经本闭包接线（先对账再提交）」。
- 状态机 `accepts` 的 `.basketCapsule` 一支改 `return mergedPendingDeletionCount > 0`（`:384-387`，加两行注释）；IC147 `:551` 注释与 `:557` `failedExpectation: true`。
- 首页 `content`：`.empty`／`.failed` 两支各包 `VStack(alignment: .leading, spacing: 0) { topRow; <既有块> }`（`:78`／`:95`）；三条 `case` 行逐字未动、未复制（IC147 `:510-511`、IC165 `:110-111` 两次 CI passed①）。
- IC166 `:363-366` App blob 断言整段删除，`:358` 注释改为卡面给的文句；`:359-362` 协议文件 blob 断言未动。

### 裁定 四：排序四项（子项 C）

- `S0DeckHomeModel.SortOrder` 加 `case sizeAscending`（`size` 之后）；`sorted(_:by:dates:)` 在 `guard order != .size` 之前加 `if order == .sizeAscending { return items.sorted { lhs, rhs in lhs.byteCount != rhs.byteCount ? lhs.byteCount < rhs.byteCount : lhs.id < rhs.id } }`。
- 页面：`gridContent` `case .size, .sizeAscending:`（`:522`）；`sortOrderName` 加 `case .sizeAscending:`（`:903-904`）；Picker 在「从大到小」之后加一项（`:471-472`）；`.disabled(dates == nil)` 未动。
- 目录加 `s0.categoryPage.sort.sizeAscending` = `从小到大`（外科插入在 `s0.categoryPage.sort.size` 之后，`extractionState = manual`）。
- IC156 `:236` 9 → 10、`:238-248` 映射加一条；IC157 `:66`、IC165 `:225` 9 → 10。

### 裁定 五：类别页两处入口（子项 D）

- 页头 `topRow`：`Spacer(minLength: 0)` 与 `sortMenu {` 之间插 `S0BasketEntryView(style: .glass, …)`（`:196-198`）。
- 收起导航条：内层 `HStack` 首位插 `S0BasketEntryView(style: .flat, …)`（`:373-375`）。
- init 末位形参 `onEnterConfirmation: @escaping () -> Void = {}`（`transitionNamespace` 之后）、存储属性、赋值；流程容器类别页构造末位传入（`:146`）。页面被钉死的计数全部不变（第九节表）。

## 四、断言与测试函数（子项 E，新文件 `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift`）

| 断言 | 函数 | #338 |
|---|---|---|
| 1 展开末卡延伸 tail 高 | `testIC167A_OpenTailCardExtendsToTailHeight`（`@MainActor`） | passed |
| 2 入口圆钮 + 徽标、首页四态顶排 | `testIC167B_BasketEntryIsCircleWithBadge` | passed |
| 3 S0-4 可达 S3、App 先对账 | `testIC167B_BasketEntryReachesConfirmationAndFailedStateAccepts` | passed |
| 4 从小到大排序 | `testIC167C_SizeAscendingSortsByBytesThenID` | passed |
| 5 类别页两处入口在排序钮左侧 | `testIC167D_CategoryPageHasTwoBasketEntriesLeftOfSort` | passed |

- 源码扫描 helper 口径同 IC-165／166；集合期望一律 `Set([...])`（惯例 45）；不重复钉 198／`s0.` 40／`s0.categoryPage.` 10，不钉任何 blob（惯例 46）。
- 断言 4 夹具按卡面给：字节 `[9, 3, 3, 1, 9]`、id `["e","c","b","a","d"]` → 期望 `["a","b","c","d","e"]`；执行端先按裁定 四的比较器手算（Python `sorted(key=(bytes, id))`）得同值②。
- 卡面之外多写的三处正对照（都不钉新计数）：断言 1 加 `XCTAssertNotEqual(cardOverhang, lastCardTailHeight)`（否则三条相等断言分不出末张）；断言 3 负对照循环里对 `{ 0 }` 同时断言 `handle(.basketCapsuleTapped) == .home(state)`，并加一条「四只夹具机器恰覆盖四态」；断言 4 夹具 `d` 一项取 `isVideo: true`（与排序无关）。

## 五、CI

### #337（A → B → C，第一次取 CI）

- run `35920418182`，attempt 1，被测提交 `bddcb07a72c689fa6536452156d509f592263575`，`completed / success`。
- 执行摘要 notice：`Executed 871 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 871 tests / 0 failures`；整包日志按唯一 Test Case 行去重（剔 `##[` 与 ANSI 回显）871 条、passed 871、failed 0①。
- 真实退出码 0：「运行 XCTest」步骤 `success`，工作流以 `exit "$test_status"` 原样退出；日志 `** TEST SUCCEEDED **` 与 `Scripts/test-xcode.sh:108` 的「XCTest 已全部通过。」都在①。
- 目的地实证行：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`。
- 分段耗时 notice 原文：`模拟器启动 63 s；xcodebuild test 258 s；总 322 s`。
- IPA 校验 notice：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1803156，SHA-256=7d6f3c5ddd6218a6d8ba1b83ff225bdec7f3d9cdddf350ddc37c22552769231d`；artifact `PhotoCleanupMVE-unsigned-bddcb07a72c6`（id 10777456202，zip 1803326 字节，有效期至 2026-12-22T21:07:12Z）。
- `testIC063`：用例块内 `building pipeline path_exterior-… took 0.523421 seconds`（整包日志 `9_运行 XCTest.txt` L2657）落在 `IC063_WARMUP_GATE_END`（L2661）之前，计时导出不受影响①（陷阱 26）。

### #338（A～E）

- run `35922356087`，attempt 1，被测提交 `fc6dd1436fa25b8298caca2f3d2266024859df4e`，`completed / success`。
- 执行摘要 notice：`Executed 876 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 876 tests / 0 failures`；唯一 Test Case 行 876、passed 876、failed 0；IC167 五条全 passed①。
- 真实退出码 0（同上两处证据）。目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`。
- 分段耗时 notice 原文：`模拟器启动 98 s；xcodebuild test 343 s；总 441 s`。
- IPA 校验 notice：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1804033，SHA-256=0f6c8d5a70a5f3f744142c3db57e7761386f47f207e62a41a177b724fd16425c`；artifact `PhotoCleanupMVE-unsigned-fc6dd1436fa2`（id 10778177131，zip 1804203 字节，有效期至 2026-12-22T21:25:36Z）。
- `testIC063`：`building pipeline … took 1.429461 seconds`（L2807）在 `IC063_WARMUP_GATE_END`（L2812）之前①。
- 相关族在 #338 的唯一用例计数（全 passed）：IC147 16、IC148 12、IC151 7、IC153 13、IC156 9、IC157 8、IC160 4、IC162 3、IC163 6、IC165 6、IC166 6、IC167 5。

### 合并后 `main` 运行 #339（G943）

- run `35924716225`，attempt 1，被测提交 = 合并提交 `81effe7c388e6b18560ee284d4cab7d575eca2b1`（分支 `main`，push 触发），`completed / success`。
- 执行摘要 notice：`Executed 876 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 876 tests / 0 failures`；唯一 Test Case 行 876、passed 876、failed 0；IC167 五条全 passed①。
- 真实退出码 0（「运行 XCTest」步骤 `success`、`** TEST SUCCEEDED **`）。目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`。
- 分段耗时 notice 原文：`模拟器启动 96 s；xcodebuild test 313 s；总 409 s`。
- IPA 校验 notice：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1804033，SHA-256=db84e2122250b6248de6f9c55f4f88ccc494ffe4ee40bb8b0eec218645fc5438`（与 #338 同字节数、不同哈希——IPA 不可复现，既有结论）。
- artifact：`PhotoCleanupMVE-unsigned-81effe7c388e`，id **10779077084**，zip 1804203 字节，有效期至 **2026-12-22T21:48:49Z**。
- `testIC063`：`building pipeline … took 0.556966 seconds`（L2619）在 `IC063_WARMUP_GATE_END`（L2624）之前①。

## 六、闸门

- **G938**：断言 1 passed（#338）；IC162 3、IC163 6、IC165 6、IC166 6 全 passed（#337／#338）；首页计数（子项 A 第 1 条）实测相符（第九节 A 表）。**满足**。
- **G939**：断言 2／3 passed；IC147 16（含改后的 `:557`、`:870-878`）、IC148 12、IC151 7、IC153 13、IC165 6 passed；新文件与首页、流程、App、状态机计数（子项 B 第 1～5 条）实测相符（第九节 B 表）；`S1View.swift` `16496cab01001aae731b1edc2be2bf478e7d2d40`、`S0DeckMetrics.swift` `7b380078b857dac0ad20d44912a084e2015cb0d7`、`S0Text.swift` `5425b262b4a6b66928c39ebea5d8d5f1439ee687` 三个 blob 在 `e6cdabe` 与 `fc6dd14` 两侧相同（报告级一次性证据，不进测试，惯例 46）；**子项 D**：断言 5 passed，页面计数（子项 D 第 1 条）实测相符，IC156 断言 6、IC157 断言 4、IC160 `:137`、IC165 断言 5 所在族全 passed。**满足**。
- **G940**：断言 4 passed；IC156／IC157／IC165 三处 `s0.categoryPage.` 10 与 IC156 映射十条 passed；IC163 六条 passed。**满足**。
- **G941**：`git diff --name-only e6cdabe fc6dd14` 恰 15 路径（= 白名单 15 个，见 `change-list.md`）；「不得打红」对象两侧相同（第十一节表）；十四条被保护分支 tip 未变（第十一节）。**满足**。
- **G942**：G938～G941 + 两次 CI 绿（871／0、876／0，真实退出码 0，`OS:26.2, name:iPhone 16`，IPA 字节数与 SHA-256、分段耗时 notice、`testIC063` build 行先后见第五节）+ pbxproj 撞号扫描（第八节）+ 合并前工作树净（`git status --porcelain` 空）+ `git ls-remote origin refs/heads/main` 仍 `e6cdabee804899c474eed3a3b9532f75838904c9`。**满足**，已 `--no-ff` 合并推送（首行照卡）。
- **G943**：合并后 `main` 运行 #339（run 35924716225）一次绿，876／0，分段耗时 `模拟器启动 96 s；xcodebuild test 313 s；总 409 s`，artifact `PhotoCleanupMVE-unsigned-81effe7c388e`（id 10779077084，有效期至 2026-12-22T21:48:49Z）。**满足**。

## 七、本地门禁（五个提交各一份，Git Bash 下 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File …`）

| 提交时状态 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --check` | 扫描器「目录 = 引用」 |
|---|---|---|---|---|
| A | 0 | 0 | 0 | 255 = 255 |
| B | 0 | 0 | 0 | **254 = 254**（卡面预期） |
| C | 0 | 0 | 0 | 255 = 255 |
| D | 0 | 0 | 0 | 255 = 255（E 的两个文件暂移出工作树后单独跑） |
| E | 0 | 0 | 0 | 255 = 255；结构自验扫 100 个 `.swift`、needle 变体审计扫 48 个测试文件，均通过 |

各次硬编码残留均为 0。

## 八、pbxproj 撞号扫描

- 登记前重扫最大号：fileRef `10000000000000000000006F`、buildFile `20000000000000000000006C`（B 前）；`100000000000000000000070`、`20000000000000000000006D`（E 前）。
- 四个新 id 出现次数（E 后全文件）：`100000000000000000000070` 3、`20000000000000000000006D` 2、`100000000000000000000071` 3、`20000000000000000000006E` 2（产品文件进 `S0` 组与 App 的 Sources 阶段，紧跟 `S0DeckHomeView.swift`；测试文件进测试组与测试 Sources 阶段，紧跟 `IC166RestCategoryTests.swift`）。
- 定义行（`<24 位 id> /* … */ = {`）`sort | uniq -d` 输出为空（244 行定义）。

## 九、计数实测（本机 Python 移植的源码扫描 helper，②；权威结论取 CI）

移植 `strippedSource`／`occurrences`／`slice`／`numericLiterals`／`localizationKeys` 与目录读取，逐条对卡面值。改前（`e6cdabe`）卡面事实基础表所列计数 60 余项全部复算相符。

**子项 A 首页（剔注释）**：`static func cardExtension(index: Int, count: Int) -> CGFloat` 1、`index == count - 1` 1、`isTail` 0、`Self.cardExtension(index: index, count: cards.count)` 1、`height - visibleHeight` 3、`S0DeckMetrics.cardOverhang + S0DeckMetrics.openTextBottomInset` 0、`… + S0DeckMetrics.openActionBottomInset` 0、`S0DeckMetrics.openShadeBottomOpacity` 2、`Color.black.opacity(S0DeckMetrics.openShadeBottomOpacity)` 1、`.frame(height: visibleHeight)` 2、`private func centeredBlock(` 1、`switch machine.state {` 1、`withAnimation(` 1、`machine.handle(` 4；裸数 ⊆ {0, 1, 2}（视图体与文件级）。全部相符。

**子项 B 新文件（剔注释）**：`Image(systemName: S0DeckSymbol.trash)` 2、`S1NotificationBadgeStyle.` 7、`S0DeckMetrics.` 7（`text` 3、`compactNavBackSide` 2、`compactNavActionFillOpacity` 1、`background` 1）、`S1ChromeTypography.circleIconPointSize` 1、`s1ChromeCircleGlass()` 1、`Button(action: action)` 1、`.disabled(count == 0)` 1、`count > 0` 1、`.allowsHitTesting(false)` 1、`.monospacedDigit()` 1、`overlay(alignment: .topTrailing)` 1、`offset(` 0、PhotoKit 七 needle 0、动态外观七 needle 0、`#available` 0；原文 `s1.trash.accessibility` 1、`Text("` 0；裸数 = {0}。
**首页**：`S0BasketEntryView(style: .glass` 1、`basketCapsule` 0、`machine.accepts(.basketCapsule` 0、`machine.accepts(` 1、`pendingDeletionByteCount` 0、`machine.mergedPendingDeletionCount` 1、`s1ChromeGlassBackground(` 2、`s1ChromeCircleGlass()` 1、`S1ChromeTypography.` 3、`Button(action:` 2、`machine.handle(` 4、`machine.ingest` 1、`withAnimation(` 1；`content` 切片内 `topRow` 2、`case .scanning, .ready:` 1、`case .empty:` 1、`case .failed:` 1、`progress.scannedAssetCount` 1；三个声明行各 1；原文 `s0.basket.capsule` 0、`s1.trash.accessibility` 0。
**流程（B 后）**：`onEnterConfirmation: @escaping () -> Void = {}` 1、`onEnterConfirmation: onEnterConfirmation` 1、`@State ` 0、`@ObservedObject` 1、`machine.ingest(` 3、`navigationDestination(item:` 1、`flowModel.preservedSelection` 2。
**App**：`onEnterConfirmation: {` 1、`reconcileS1WithPhotoLibrary()` 1、`makeS3Submission()` 1、`enterConfirmationFromS1(` 2、`advanceScan()` 2、`enterS2(from:` 2、`makeS2Handoff(virtualRangeID:` 1、`feedbackToastDurationMilliseconds` 3、`S0CategoryPageRange.prefix` 2、`S0CleanupFlowView(` 1、`S0TabContainer(` 1；`case .s2:` 六行块逐字 1、`.onAppear` 启动守卫三行逐字 1（原文）。
**目录（B 后）**：255 → 254、`s0.` 39、`s0.basket.capsule` 不存在、`s1.trash.accessibility` = `会话待删总数 {count}`。IC147 断言 11 五文件名单下 `s0.` 引用集 = 目录 `s0.` 集、借用集 = 五条；IC165 目录级借用集 = 五条。

**子项 C 页面（剔注释）**：`.tag(S0DeckHomeModel.SortOrder.sizeAscending)` 1、`case .size, .sizeAscending:` 1、`case .sizeAscending:` 1、`Button {` 3、`Image(systemName: ` 7、`S0DeckMetrics.` 153、`S1ChromeTypography.titleFontSize` 1；原文 `s0.categoryPage.sort.sizeAscending` 2。**模型**：`case sizeAscending` 1、`order == .sizeAscending` 1、`lhs.byteCount < rhs.byteCount` 1、`guard order != .size` 1。**目录**：255、`s0.` 40、`s0.categoryPage.` 10；IC156 映射十条的取值与占位符规则、页面 key 集（十条 + 借用四条）全部成立；IC157 断言 5 四条整句 needle 各 1。

**子项 D 页面（剔注释）**：`S0BasketEntryView(style: .glass` 1、`S0BasketEntryView(style: .flat` 1、`machine.mergedPendingDeletionCount` 2、`Button {` 3、`Image(systemName: ` 7、`Image(systemName: S0DeckSymbol.` 7、`S0DeckMetrics.` 153、`s1ChromeGlassBackground(` 5、`S1ChromeLayout.rowHeight` 2、`accessibilityLabel(` 3、`.onAppear` 1、`machine.handle(` 0；`topRow` 切片内 `.glass` 上界 < `sortMenu {` 下界、`sortMenu {` 上界 < `selectAllButton` 下界；`compactNav` 切片内 `.flat` 上界 < `compactNavSort` 下界；裸数 ⊆ {0, 1, 2}。**流程**：`onEnterConfirmation: onEnterConfirmation` 2、`S0DeckCategoryPageView(` 1。

### 陷阱 9：`SortOrder` 穷尽 switch 命中表（推第一次 CI 前，`e6cdabe` 行号）

| 位置 | 形态 | 处理 |
|---|---|---|
| `S0DeckCategoryPageView.swift:505-508` `gridContent` | `switch sortOrder`（穷尽） | `case .size:` → `case .size, .sizeAscending:` |
| `S0DeckCategoryPageView.swift:883-892` `sortOrderName` | `switch sortOrder`（穷尽） | 加 `case .sizeAscending:` |
| `S0DeckCategoryPageView.swift:453-461` Picker | 三个 `.tag` | 加一项 |
| `S0DeckHomeModel.swift:94`、`:110` `sorted` | `guard order != .size`、`order == .newestFirst ? … : …`（非 switch） | 前置 `if order == .sizeAscending` 分支 |
| 测试目录 | `switch sortOrder`／`case .size` 0 命中；IC163 只调用 `.size`／`.newestFirst`／`.oldestFirst` | 不动 |

## 十、摘取关系（惯例 40，本机克隆实测）

- A 单独（`e6cdabe` 上 `cherry-pick -x e82f2a5`）：无冲突，结果树 = 分支 A 的树 `15a9013897e3d0c5ff448dc323cb64c7ea7afca3`①；本地门禁 0（第七节）。未单独取 CI（卡定 A→B→C 一起推）。
- A → B → C：无冲突，结果树 = `2dc7c4281dc4a81dbf25f30fd0350833fd366c7e`（= 分支 C 的树）①；#337 实证绿。
- A → C（跳过 B）：文本无冲突（与卡面「C 文本上可单独摘」一致①），按卡面 `s0.` = 41 必红，未取 CI。
- A → B → C → D → E：即分支本身，#338 实证绿。可摘单元 = A；A→B→C；A→B→C→D；A→B→C→D→E（与卡面一致）。

## 十一、白名单外零改动（G941）

| 对象 | `e6cdabe` | `fc6dd14` |
|---|---|---|
| `PhotoCleanupMVE/Services`（树） | `82320c200eea1ecd13c3c1e54acf1e0670b70f8b` | 同 |
| `PhotoCleanupMVE/Features/Shared`（树） | `ca567d006a536e637c0330f8af07bf8b4c0734d3` | 同 |
| `PhotoCleanupMVE/Features/S1`（树） | `5bb26f016d35fb1327fccef002da4e7c1921eec1` | 同 |
| `PhotoCleanupMVE/Features/S2`（树） | `f43aa47cafbecac163209e90c38a7adfd0b4fafe` | 同 |
| `PhotoCleanupMVE/Features/S3`（树） | `175b165b22c7a7e7c70dd6fdcb28e9afd58fca55` | 同 |
| `PhotoCleanupMVE/Features/S4`（树） | `d6bce474b5e07285a379ad4dcebe59c1bde69d81` | 同 |
| `PhotoCleanupMVE/Features/S5`（树） | `d738ec8e91342012ab2e9b415e76949b8bc33f05` | 同 |
| `.github`（树） | `74088388c62a10eb277921ecf74e766a2d407e80` | 同 |
| `Scripts`（树） | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同 |
| `App/CleanupCoordinator.swift` | `88ba3abb40d259984619711acdf67a10e7c5338b` | 同 |
| `Features/S0/S0CleanupDataProviding.swift` | `b9e4a57c3133bf189ed3db21b1ff995547faa40f` | 同 |
| `Features/S0/S0CategoryPageSelection.swift` | `d114ac601f1131babd290fa39ab3b59f03e42af2` | 同 |
| `Features/S0/S0DeckZoomTransition.swift` | `c1424f9166525d4b5d72f60f745df38a5ee340c3` | 同 |
| `Features/S0/S0TabContainer.swift` | `9a80395451f031f86e30873917f003c63c10c6c3` | 同 |
| `Features/S0/S0Text.swift` | `5425b262b4a6b66928c39ebea5d8d5f1439ee687` | 同 |
| `Features/S0/S0SegmentBarModel.swift` | `8878b8fbcfb7cdec883ae04e45c974e53ae56edf` | 同 |
| `Features/S0/S0DeckMetrics.swift` | `7b380078b857dac0ad20d44912a084e2015cb0d7` | 同 |
| `Features/S0/S0CleanupFlowModel.swift` | `28a1115e183a9cf67f7f0118bf97c50bb37173e0` | 同 |
| `Features/S1/S1View.swift` | `16496cab01001aae731b1edc2be2bf478e7d2d40` | 同 |
| `Core/` 除 `S0StateMachine.swift` 的 9 个文件 | 逐个 blob 比对 | 全同 |
| 测试目录除白名单 6 份外的 42 个文件 | 逐个 blob 比对 | 全同 |

- `schemaVersion` 仍 7（`Features/S2/S2Calibration.swift:118`）、`cacheSchemaVersion` 仍 1（`Services/S0ScanRules.swift:22`）、`S0DeckMetrics` 198 与 `S0DeckSymbol` 8（登记表文件 blob 不变）。
- 十四条被保护分支 tip（`git rev-parse --short`，开工时与合并前各核一次，未变）：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`。
- SPEC 与 Decision_log 未触碰。

## 十二、人工判定项（H87 八条，保留给 Lynn 装合并后 `main` 产物真机判，执行端不代为下结论）

装包：合并后 `main` 运行 #339 的产物 `PhotoCleanupMVE-unsigned-81effe7c388e`（id 10779077084，有效期至 2026-12-22T21:48:49Z）。

1. 首页右上：垃圾桶圆钮 + 红徽标，篮空时无徽标、钮不可点；点进 S3 组头与张数对；从 S3 返回落回首页（现行路由）。
2. 类别页页头与收起导航条两处都有同一只入口，在排序钮左边；点进 S3；从 S3 返回落在哪一页（记下来，归未定项 12）。
3. 展开末卡「其余照片」：文字下面没有黑边，卡一直延伸到屏幕底；展开别的卡时它收起正常、总条与卡片叠联动不变。
4. 排序菜单四项；「从小到大」下最小在前、副行「N 项 · 从小到大」；在这个排序下长按进 S2，翻页顺序也是从小到大。
5. 徽标在圆钮右上有没有被玻璃盖住或被裁掉；收起导航条多了一只 42 圆钮后，类别名标题会不会被挤截断。
6. 冷启动不切「逐张整理」tab，直接点首页／类别页垃圾桶：进不进 S3（③ 预期静默无反应——把现象记下来给 IC-168）；切过一次「逐张整理」再回来点，应能进。
7. 全库进篮后的首页空态（S0-3）与读取失败态（S0-4，拒授权可复现）仍有顶排：垃圾桶圆钮 + 徽标、人像圆钮都在；点垃圾桶进 S3。
8. 一两句总评。

**真机未覆盖**（陷阱 1）：上面八条对应的观感与路径，CI 上只有源码扫描与状态机夹具，没有任何渲染或手势证据。

## 十三、登记

### v4 欠账（规格待改，本卡按卡面裁定实装）

1. SPEC-S0 v4 第五节 `:277`「点击待删篮入口」一行 S0-4 列仍写「失效」，与第三节第 4 部分 `:228`／`:234`／`:238`、第四节 `:258` 矛盾；按第三、四节实装（裁定 三）。
2. 第六节 `:298` `SORT=体积升序` 括注「数据源已排好，页面不重排」与实装不符：数据源只给降序，升序在页面侧经 `S0DeckHomeModel.sorted` 重排（裁定 四）。
3. 第十四节第 2 部分 `:639` 只引了 `badge*` 四项，未登记徽标描边色；S0 实装取 `S0DeckMetrics.background`（S0 恒深色），待第十四节补登（裁定 二）。

### 实装欠账

- 「逐张整理」tab 的现行入口（`S1TrashButtonAction.perform`，`S1View.swift:768-780`）进 S3 前**没有**做决策 30 对账；规格（SPEC-S1 v10 第七节第 3 部分）本身没错。本卡 S0 两处入口经 App 闭包先 `reconcileS1WithPhotoLibrary()` 再提交；S1 侧按卡不动。

### ③ 登记（高把握，待真机证实，归 IC-168）

- S1 状态机开屏后停在 `.loading`，直到「逐张整理」tab 出现：`loadingState` 初值 `.loading`（`S1StateMachine.swift:274`，`state` 由它派生 `:357`），变 `.ready` 的唯一写点在 `completeRangeRead`（`:494`），只由 `S1View.onAppear` → `readCurrentRequestIfPossible()` 触发（`S1View.swift:851-852`、`:1781-1791`）；开屏落在「空间清理」tab（`S0TabContainer.swift:18`）；`makeS3Submission()` 有 `guard !isObscured, state != .loading`（`S1StateMachine.swift:720`）；对账 `reconcile` 的守卫是 `loadingState == .ready`（`:524`，卡面写 `:530`）。故冷启动不切 tab 直接点 S0 入口，闭包在 `guard let submission … else { return }` 静默返回。S0 入口没有 S1 那道加载中禁用（`S1View.swift:106`／`:1048`）。SwiftUI 未选中 tab 会不会触发 `.onAppear` 未验证。本卡不修（H87 第 6 条取现象）。

### 一次性证据登记（惯例 46）

- `S1View.swift`／`S0DeckMetrics.swift`／`S0Text.swift` 三个 blob 与 `e6cdabe` 相同（第十一节），只作报告级证据，不进测试。
- IC166 `:363-366` 的 App 入口 blob 断言已按惯例 46 撤下（`:358` 注释同改）；协议文件 blob 断言 `:359-362` 保留。

## 十四、发现但未处理的问题（按纪律只报告不修）

1. 首页人像圆钮实装走 `s1ChromeCircleGlass()`（44，`S0DeckHomeView.swift` `accountButton`），`accountCircleSide`（40）产品侧零引用；v4 `:640` 的「不等径 ③」前提不成立，是否统一待 Lynn 定。
2. IC148 `:547` 注释「与 IC-147 断言 11 同一份四文件名单」随 IC147 名单加第五个文件而失真（IC148 不在白名单，未改）。
3. `S0StateMachine.pendingDeletionByteCount`（`:316-318`）与快照同名字段失去产品读者（首页胶囊退役后）。
4. `S0Input.basketCapsule`／`S0Event.basketCapsuleTapped` 产品侧零调用（首页入口直接调回调，不经状态机）；只剩矩阵语义与测试引用。
5. `S0StateMachine.showsCategoryRows` 的文档注释（`:328-332`）仍写「S0-4 的显示元素清单只有大标题、人像圆钮与中央失败说明」，v4 起 S0-4 顶排还有待删篮入口（显隐判据本身不受影响）。
6. `S0CleanupFlowView` 头部文档「本容器只做三件事」未提待删篮入口回调的转交（本卡只加形参与转交）。
7. `IC156CategoryPageTests.testIC156C_CatalogGainsFiveKeysAndBothGatesAreUpdated` 等函数名的数字已过时（同 IC-166 登记的「待开纯重构卡」类）。
8. `IC166RestCategoryTests.appPath` 在删掉 App blob 断言后无引用（私有静态常量，不报警告；卡只要求删断言四行，未删声明）。
9. 首页入口的徽标以 `.overlay` 叠在按钮上，而 S1 在 iOS 26 分支把徽标叠在 `GlassEffectContainer` 之外（`S1View.swift` `chromeBar` 注释：玻璃容器会把普通 overlay 盖进合成层）。S0 顶排不在 `GlassEffectContainer` 里，③ 不受该问题影响，归 H87 第 5 条看。

## 十五、注释改动登记（卡面未逐条列出、为与本卡代码一致而改的注释）

改动都只在白名单文件内、只动注释，不影响任何计数（测试 helper 剔注释；文案 key 未写进注释）：首页头部文档「顶排的圆钮与胶囊」→「顶排的圆钮」；类别页头部文档两句（排序四项、两处入口）与 `sortMenu`／`sortOrderName` 文档；模型 `SortOrder`／`sorted` 文档；IC147 断言 11 名单与借用集上方各一行（`:551` 那一行是卡面要求的），IC156、IC157、IC165 计数断言上方的变更历史注释各一行；新增代码处的 `IC-167` 说明注释。明细见 `change-list.md`。

## 十六、40 位 SHA 核验

两份报告写完后，按正则 `(?<![0-9a-fA-F])[0-9a-f]{40}(?![0-9a-fA-F])` 抽出全部 40 位十六进制串（IPA／artifact 的 64 位 SHA-256 不在其列），逐个 `git cat-file -t` 取类型后跑 `git cat-file -e <sha>^{<类型>}`：**30 个，全部存在、类型相符**①。

- commit（8）：`e6cdabee804899c474eed3a3b9532f75838904c9`、`a6018ad990c80fe01445ffdfa4ed890735eb9589`、`e82f2a5f5a7ebd9332bff7f8919f5ffc6f83e9e8`、`edea245f96bae51ac7d4589b7587b01c19df5b48`、`bddcb07a72c689fa6536452156d509f592263575`、`92b0b9234442e6a330c78545fd219fb811e692b5`、`fc6dd1436fa25b8298caca2f3d2266024859df4e`、`81effe7c388e6b18560ee284d4cab7d575eca2b1`。
- tree（12）：`15a9013897e3d0c5ff448dc323cb64c7ea7afca3`、`2dc7c4281dc4a81dbf25f30fd0350833fd366c7e`、`e82c54c9f47de0f78ce61de8be9d9af78e5c602e`、`82320c200eea1ecd13c3c1e54acf1e0670b70f8b`、`ca567d006a536e637c0330f8af07bf8b4c0734d3`、`5bb26f016d35fb1327fccef002da4e7c1921eec1`、`f43aa47cafbecac163209e90c38a7adfd0b4fafe`、`175b165b22c7a7e7c70dd6fdcb28e9afd58fca55`、`d6bce474b5e07285a379ad4dcebe59c1bde69d81`、`d738ec8e91342012ab2e9b415e76949b8bc33f05`、`74088388c62a10eb277921ecf74e766a2d407e80`、`514886dc0afc4083237c976c0f7be6ce597c50a8`。
- blob（10）：`16496cab01001aae731b1edc2be2bf478e7d2d40`、`7b380078b857dac0ad20d44912a084e2015cb0d7`、`5425b262b4a6b66928c39ebea5d8d5f1439ee687`、`88ba3abb40d259984619711acdf67a10e7c5338b`、`b9e4a57c3133bf189ed3db21b1ff995547faa40f`、`d114ac601f1131babd290fa39ab3b59f03e42af2`、`c1424f9166525d4b5d72f60f745df38a5ee340c3`、`9a80395451f031f86e30873917f003c63c10c6c3`、`8878b8fbcfb7cdec883ae04e45c974e53ae56edf`、`28a1115e183a9cf67f7f0118bf97c50bb37173e0`。

报告内全部 40 位 SHA 都取自本会话实读命令（`git rev-parse`／`git log`／`gh api`）的输出，未凭短前缀补全（陷阱 15）。本 docs 提交自身的 SHA 在提交之后才产生，不写入报告。
