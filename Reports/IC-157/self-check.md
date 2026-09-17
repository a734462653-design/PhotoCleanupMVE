# IC-157 自验报告

## 一、结论（先行）

- **三个子项都已交付**，顺序 A → B → C，各自独立 commit：
  - A `5517548`：`S1StateMachine` 虚拟范围三入口——交接构造、逐张镜像、整体写回。
  - B `ad6dfd7`：类别页长按手势、常驻行右侧提示，文案一条；既有断言按裁定六改口径五处。
  - C `0a6c953`：新建 `S0CleanupFlowModel`，App 持有；流程容器改为观察它，返回类别页时重算；App 闭包经虚拟范围交接调协调器 `enterS2(from:)`；IC-156 断言 10 改口径三处。
  - 摘取单元在克隆仓库实测：A 单独、A→B、A→B→C 均无冲突，A→B→C 的树与分支 tip 相同；负对照「B 单独」冲突（第十节）。
- **CI #315 一次绿**（run id `35236339929`，attempt 1，被测提交 `0a6c953c52a4ee857d427d4589ce7bfb94f62582`）：
  - 12 个步骤全 success，真实退出码 **0**。
  - **852 项 0 失败，1 个 launch**，没有宿主重启。
  - 目的地 `OS:26.2, name:iPhone 16`。
  - IPA **1687402 字节**，SHA-256 `7c6098aef9ebebb1a6e9d0c5576450b1ff97d83233b4b22805c4e3142274358e`。
  - 分段耗时「模拟器启动 84 s；xcodebuild test 462 s；总 546 s」。
  - 项数对账 **844 + 8 = 852** ✔。分支 CI 预算 3 次，用了 **1** 次。
- **断言 1～8 全部 `passed`**（第五节逐条给函数名与耗时）。以下既有用例逐条 `passed`：
  - IC-147 16／16、IC-148 14／14、IC-156 11／11；
  - `S1StateMachineTests` 20／20、`SessionStoreTests` 14／14；
  - IC-131 7／7（`IC131S1WriteBackToastTests` 5 + `IC131S1TrashBadgeTests` 2）、IC-132 9／9、IC-127 26／26、IC-129 6／6；
  - IC-153 13／13、IC-155 9／9、IC-151 8／8；
  - `testIC063…` passed（4.190 s）。
- **G892～G894 满足，G895 满足**（第九节），已按卡内授权 `--no-ff` 合并入 `main`。
  - **合并提交** `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b`：父提交 `e97f394` 与报告提交 `e8700ab3770cf66c77871aa1237354df3670fae4`；合并树与 `e8700ab` 的树是同一对象（`fcb68d13…`）。
  - **G896**：合并后 `main` 的自动运行 **#316**（run id `35238730601`）attempt 1 **一次绿**——852 项 0 失败、1 个 launch、真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 1687402 字节、分段耗时「模拟器启动 54 s；xcodebuild test 264 s；总 319 s」（第九节 G896）。
  - 本段与 G896 由 `main` 上的 docs 提交回填，照 IC-156 先例（`e97f394`）。
- **卡内有三处条文与正确实现冲突或自相矛盾**（第 7.1～7.3 条），**另有七处实现取舍或卡面留白**（第 7.4～7.10 条），都按卡的意图落实，**请决策会话追认**。影响测试写法的只有第 7.1 条：
  - 断言 1 卡面说交接构造「名字表变了」所以写出恰 1 次；但断言前置的 `markPendingDeletion` 已把同名登记进名字表，出口若一开始就接上，构造时实际写出 **0** 次，必红。
  - 实装改为进篮之后再接出口，另加一段「从未登记过名字的范围」对照，把名字单独变化也写出这件事钉住。
- **H78 八条原样保留给 Lynn**（第十一节，卡「报告」节写「七条」，实为八条），执行端不代为下结论。以下项目**模拟器上一律未覆盖**（夹具驱动，陷阱 1、23）：
  - 长按手感；
  - 松手是否连带点按；
  - 进出 S2 的过渡；
  - 回来是否确实落在类别页；
  - 网格消失与首页数字同步；
  - S3 分组。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260917-157-long-press-into-s2.md`（本机 `sha256sum` = `9bb9fc05d09d02cfef81104f8320c0bbdea1125d85c13c2e6970e4c2ca8745a6`） |
| 规格 | SPEC-S0 v2（`8a8e222a7f203c6c92dc8e755338cded8673f7de76c7b6290da696d4058d6f44`）、SPEC-S1 v9（`15272907c85731bae9c076a507582539dff1999191d1b19e3d275031ea23bbd6`）、SPEC-S2 v21（`b75d1fd8481f4192929cef35b86ff8bf378536a6be4a4239512039c23f2c5bf1`），均与 CLAUDE.md 基线行一致；卡引 SPEC-S0 v2 第 280／295／302 行、第 406～420 行、第 687 行逐行对读一致 |
| 基线 `main` | `e97f39499347888f0ae50f6d44ee2985b6ece68b` |
| 开工核对 1 | `git status --porcelain` **空**（纪律 8），分支 `main`、HEAD = `e97f394` |
| 开工核对 2 | `git merge-base --is-ancestor c42edd1 main` 退出码 **0** ✔ |
| 开工核对 3 | `git ls-remote origin refs/heads/main` 退出码 0，= `e97f39499347888f0ae50f6d44ee2985b6ece68b` = 本地 ✔ |
| 分支 | `feature/ic-157-long-press-into-s2`（自 `e97f394` 切出） |
| 分支 tip（代码） | `0a6c953c52a4ee857d427d4589ce7bfb94f62582` |
| 现状基数 | 844 项（CI #314）→ 本卡 **852** 项 |
| 常量 | `schemaVersion` **7**、`S0ScanRules.cacheSchemaVersion` **1**、`S0HomeMetrics` **52**、`S0CategoryPageMetrics` **42**，均未动 |

**卡内事实表复核（惯例 13／37）**：卡内「事实基础」「定位坐标」两表在 `e97f394` 上实读，逐项一致。

- **`S1StateMachine`**：
  - 行号：`:4-9`、`:176-205`／`:189-204`、`:306`、`:337`、`:354-363`、`:540-546`、`:567-572`、`:635-669`（`:638`）、`:678`、`:713-730`（`:718`）、`:732-768`（`:737-746`、`:748-766`）、`:783-812`（`:792`、`:809`）、`:814-824`。
  - 另外两点：`S1ToS2Handoff` 的 init 是 internal；`knownRangeNamesByID` 是 private，不带 `@Published`／`didSet`。
- **`SessionStore`**：`:5-8`、`:261-300`（`:266-275`、`:278-291`、`:287-291`、`:293-297`）。
- **`S2StateMachine` 入口守卫**：`:693-709`（`:696`、`:697-698`）。
- **协调器**：`enterS2` 声明 `:172`（卡写 `:171-219`，`:171` 是 `@discardableResult`）、`:173`、`:179-183`、`:203-205`、`:216`，`leaveS2` `:222`，`:229`、`:230`，`returnToS1AfterFailedWriteBack` `:244`，`receiveS2PendingDeletionChange` `:888`，`applyS2ExitPayload` `:903`。
- **App**：`:6-10`、`:55-79`、`:91-110`、`:235-283`、`:238-259`。
- **S0 页面与状态机**：
  - 流程文件：`:28`、`:52-58`、`:56`、`:76-92`、`:78`、`:80`、`:102`，共 105 行。
  - 页面：`:270-292`、`:276`、`:277`、`:290`、`:368`、`:370-380`（`:375-377`）、`:411-422`；`:75-78`（`remove(ids:)` 保序）。
  - `S0StateMachine.swift:349-353`（`ingest` 不重排）。
  - `S2View.swift:2000` `.onLongPressGesture(`。
  - `SessionPersistence.swift:284-294`（`SortOrder` 按 rawValue 读，未知值整档作废）。
- **测试**：
  - IC-147 `:160`、`:798`、`:847`；IC-148 `:841`；
  - IC-156 `:112-122`、`:155`、`:170`、`:198-202`、`:215`、`:216`、`:218-224`、`:235`、`:238-247`、`:484`、`:491-493`、`:499`、`:512-518`、`:577`；
  - `S1StateMachineTests.swift:152-158`、`:156`、`:275`、`:349`、`:547`；`IC131S1WriteBackToastTests.swift:13-33`、`:152`（`makeCoordinatorInS2`）、`:173`（`handleSwipeUp()`）。
  - 另确认：没有任何测试钉 `applyS2PendingDeletionChange` 返回 false。
- **数值**：
  - pbxproj 最大 id `…5E`／`…5B`；`s0.` 37、`s0.categoryPage.` 5；
  - `S0CategoryPageMetrics.` 57；`setMarked(` 3；`publishSnapshotIfChanged()` 5（含声明）；
  - 八个远端 tip 与卡一致。

**范围边界**：diff 限于白名单 11 个路径（`change-list.md` 第二节）；「不得触碰」清单两侧 SHA-256 相同（第九节 G892）。

---

## 三、实现要点

### 3.1 子项 A：虚拟范围三入口（裁定 二、三）

- **在途登记** `activeVirtualRangeIDs`：`private(set)`、内存态、不入档。
- **`makeS2Handoff(virtualRangeID:displayName:orderedAssetIDs:currentAssetID:)`**：
  - 校验：范围标识与显示名非空、列表非空且唯一、起点在列表内；不满足返回 nil，零副作用。
  - 成功时依次：登记名字 → **显式 `publishSnapshotIfChanged()`** → 登记在途 → 构造交接。交接里 `totalAssetCount` 取列表长度（S2 守卫 `:697-698` 的硬要求），`pendingDeletionAssetIDs` = `M[r]` ∩ 列表。
  - 不设加载态与遮挡门槛。
- **逐张镜像**：`applyS2PendingDeletionChange` 在既有守卫**之前**判断在途；在途范围只校验待删集合 ⊆ 交接列表。差分循环抽成 `applyPendingDeletionDiff(_:rangeID:)`，两路共用，`M` 仍只经 `setMarked` 写（陷阱 19）。
- **整体写回**：`applyS2Return` 守卫放行在途范围；写回成功后移除在途登记；`SessionStore.applyS2Return` 的六项校验照旧生效。
- **`O_记录`**：虚拟范围取协调器既有写法 `s1Machine.sortOrder.sessionSortOrder`（裁定 三）。协调器未改，这一条由 `enterS2(from:)` `:179-183` 自然满足；`SortOrder` 仍两个 case。

### 3.2 子项 B：长按与提示（裁定 五）

- 格仍是 `Button`，`.buttonStyle(.plain)` 之后挂 `.simultaneousGesture(LongPressGesture().onEnded { _ in onLongPress(selection.items.map(\.id), item.id) })`：
  - 时长与移动距离都取系统默认；
  - 不改 `SEL`、不进篮；
  - **未走回退写法**（③ 松手是否连带点按，H78 第 8 条）。
- 常驻行改为 `HStack { 左文 Spacer(minLength: 0) 右文 }`；右文取 `s0.categoryPage.longPressHint`，字号与明度写法照左文逐字，不加常量。
- 页面新参数带默认值 `{ _, _ in }`，A→B 下流程文件唯一构造点不改即可编译。

### 3.3 子项 C：身份上提与接线（裁定 一、四、五）

- **`S0CleanupFlowModel`**：只有一个属性 `@Published var presentedCategory: S0CategoryIdentifier? = nil`，`import Combine`。App 以 `@StateObject s0FlowModel` 持有，与 `s0TabSelection` 同层。
- **容器**：
  - `@ObservedObject var flowModel`；`navigationDestination(item: $flowModel.presentedCategory)`；`onChange(of: flowModel.presentedCategory)` 不变（非 nil → nil 时摄入并发返回事件）。
  - 新增 `static func shouldRecomputeOnAppear(presentedCategory:)`：非 nil 即 true。
  - 新增 `.onAppear { if 谓词 { machine.ingest(…) } }`：不发返回事件、不重排。
  - 类别页 `onLongPress` → `onEnterS2(identifier, 顺序, 被长按那张)`。
- **App 闭包**：`S0CategoryPageRange.prefix + rawValue` → `s1Machine.makeS2Handoff(virtualRangeID:…)` → `coordinator.enterS2(from:)`，返回布尔值。`CleanupCoordinator.swift` 两侧同一 blob；`body` 与 `tabContainer` 的 `.onAppear` 逐字不动。
- **进出 S2 时的机制**（③，H78 第 2 条兜底）：
  - 进 S2 时 tab 容器整棵销毁，模型不动。
  - 回 `.s1` 时容器重建，`NavigationStack` 以非 nil 绑定重建并推出类别页。
  - 类别页 `items` 从 `dataProvider.categoryAssets` 重取，已标记的资产已在 `D_全部` 里，不再出现；`SEL` 随重建清空（③ 取「清空」）。

---

## 四、CI 与项数对账

### 4.1 #315 的完整事实

| 项 | 值 |
|---|---|
| run id ／编号 | `35236339929` ／ **#315**，attempt 1，事件 `push`，分支 `feature/ic-157-long-press-into-s2` |
| 被测提交 | `0a6c953c52a4ee857d427d4589ce7bfb94f62582`（分支 tip，含三个代码提交） |
| check-run id | `105253111462`（本次运行现取） |
| 作业 | 14:51:15Z → 15:04:53Z，**success**（13 分 38 秒，作业级时限 30 分钟之内） |
| 步骤 | 12 个步骤（含 Set up job／Complete job）全 success。「运行 XCTest」（步骤 9）14:52:37Z → 15:01:47Z（9 分 10 秒，步骤级时限 25 分钟之内）：以 `exit "$test_status"` 原样退出、结论 success，日志有 `XCTest 已全部通过。`（`Scripts/test-xcode.sh:108`，仅 xcodebuild 退出码为 0 时打印）⟹ 真实退出码 **0**。「构建未签名应用」15:01:47Z → 15:04:34Z；「上传可下载的未签名 IPA」→ 15:04:37Z |
| 工具链 | `Xcode 26.3`，`Build version 17C529` |
| 模拟器 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| 执行摘要 notice | `Executed 852 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 852 tests / 0 failures` |
| 分段耗时 notice | `模拟器启动 84 s；xcodebuild test 462 s；总 546 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1687402，SHA-256=7c6098aef9ebebb1a6e9d0c5576450b1ff97d83233b4b22805c4e3142274358e`；artifact `PhotoCleanupMVE-unsigned-0a6c953c52a4`，id `10504425809`，zip 1687572 字节 |
| 注解 | 仅上述 3 条 notice；error／warning **0** 条 |

### 4.2 实证行

来源：整包日志 zip（249129 字节，`unzip -tq` 校验通过）中「9_运行 XCTest」单个步骤日志。先剔 `##[` 注解回显与 `[36;1m` 脚本源码回显（陷阱 25），计数只按这一个文件。

- 目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- `Executed 852 tests, with 0 failures (0 unexpected) in 39.015 (42.070) seconds`；`** TEST SUCCEEDED **`；`XCTest 已全部通过。`
- `Test Suite 'All tests' started` **1** 次；`Restarting after unexpected exit` **0** 次
- 唯一 `Test Case` 身份 **852**：passed **852**、failed **0**
- `.swift:<行>: error` 形状的行 **0**
- `未签名 IPA 已生成：1687402 字节，SHA-256=7c6098aef9ebebb1a6e9d0c5576450b1ff97d83233b4b22805c4e3142274358e`

### 4.3 项数对账

| 来源 | 项数 |
|---|---|
| `main` 基数（CI #314） | 844 |
| 本卡新增（`IC157LongPressIntoS2Tests`，8 个 `func test`；本机 `grep -n "func test"` 8 行，无注释行干扰） | +8 |
| 期望 | **852** |
| #315 唯一 Test Case 身份 | **852**（852 ／ 0） |

**预算（纪律 2）**：3 次用 1 次。推送前的本机预验证见第八节。

---

## 五、逐条验收门禁与测试函数名（#315 均 `passed`）

| 断言 | 子项 | 测试函数 | 耗时（s） | 钉住的结果 |
|---|---|---|---|---|
| 1 | A | `testIC157A_VirtualHandoffBuildsInAnyStateAndRegistersName` | 0.019 | 机器分别处于 `.loading`／`.empty`／`.ready`（`makeMachine(state:)` 照抄），先 `markPendingDeletion(["b"], "cat:bigVideo", "大视频")`，再接写出口（第 7.1 条）。交接三态都非 nil：显示信息 `("cat:bigVideo", "大视频", 3)`、会话标识、顺序、`pending == ["b"]`、`current == "b"`、合并计数 == `badgeCount`；在途含该 id；写出恰 1 次且快照带名；同参再构造不再写出；`makeS2Handoff(for: "cat:bigVideo")` 仍 nil；五种非法输入（空列表、重复、起点不在列表、空名、空范围标识）各 nil，在途不变、不写出、会话层不变、未登记名；`.ready` 上提交非 nil、组名「大视频」、成员 [b]。另加一段：从未登记过名字的 `cat:screenshot` 构造后恰多写出 1 次，快照带「屏幕截图」，`M` 无该键，会话层不变 |
| 2 | A | `testIC157A_VirtualRangeLiveMirrorAndReturnBypassRangeGates` | 0.002 | `.empty` 机器经上一条构造（交接带 [b]）。越界 `["a","z"]` → false，零写出。`["a","b"]` → true，`M` = [a,b]，`F[a]`／`F[b]` = `cat:bigVideo`，写出 1。`["a"]` → true，`M` = [a]，`F[b]` 已删，写出 2。`applyS2Return(…, ["a"], c, c)` → true，`M` = [a]，`K` = `Continuation("c","c",.newestFirst)`，在途已空，写出 3。负对照：同机真实范围 `range-month` 两个入口各 false；写回后同一虚拟范围再逐张写入落回既有守卫 → false；会话层不变、写出仍 3 |
| 3 | A | `testIC157A_RealRangePathsByteIdentical` | 0.011 | `makeS2Handoff(for:)` 声明行到闭合 `}` 与内嵌的 `e97f394` 原文（35 行）逐字相等。剔注释后：`private(set) var activeVirtualRangeIDs: Set<String> = []` 1、`func makeS2Handoff(virtualRangeID:` 1、`publishSnapshotIfChanged()` **6**（`e97f394` 为 5：三个 didSet、对账后补写一处、写出口声明本身）、`private func applyPendingDeletionDiff(` 1、`applyPendingDeletionDiff(` 3（声明 1 + 调用 2）、`setMarked(` 3 |
| 4 | B | `testIC157B_LongPressGestureAndHintKeepDiscipline` | 0.059 | 剔注释页面：`LongPressGesture()` 1、`.simultaneousGesture(` 1、`Button {` 2、`onTapGesture`／`onLongPressGesture`／`minimumDuration`／`maximumDistance` 各 0、`onLongPress(` 1、`onLongPress:` ≥ 1、`selection.items.map(` ≥ 1；原文 `L10n.text("s0.categoryPage.longPressHint"` 1；常驻行切片 `HStack` ≥ 1、`dimmedText(opacity: S0CategoryPageMetrics.pinnedRowOpacity)` 2、`S0CategoryPageMetrics.pinnedRowFontSize` 2；`S1ChromeTypography.titleFontSize` 1、`Image(systemName: ` 3、裸数 ⊆ {0,1,2}；正对照 `S2View.swift` 剔注释后 `onLongPressGesture` > 0 |
| 5 | B | `testIC157B_CatalogGainsLongPressHint` | 0.012 | 目录 `s0.` 38、`s0.categoryPage.` 6；`longPressHint` == `长按任一格逐张看`，无 `{`；原文整句 needle：IC-147 `s0Values.count, 38)` 1、`catalogS0Keys.count, 38)` 1，IC-148 `catalogS0Keys.count, 38)` 1，IC-156 `hasPrefix("s0.") }.count, 38)` 1 |
| 6 | C | `testIC157C_FlowModelHoistedAndAppWiresEnterS2` | 0.011 | 剔注释流程文件：`@State ` 0、`@StateObject` 0、`@ObservedObject` 1、`flowModel.presentedCategory` ≥ 3、`machine.ingest(` 3、`.onAppear` ≥ 1、`static func shouldRecomputeOnAppear(presentedCategory:` 1、`onEnterS2` ≥ 2、`.returnedFromCategoryPage` 1、`navigationDestination(item:` 1、`CleanupCoordinator`／`SessionStore`／`S1StateMachine` 各 0。模型文件：`@Published var presentedCategory: S0CategoryIdentifier?` 1、`ObservableObject` 1、`import` 行非空且 ⊆ {Combine, Foundation}。剔注释 App：`S0CleanupFlowModel()` 1、`flowModel: s0FlowModel` 1、`makeS2Handoff(virtualRangeID:` 1、`enterS2(from:` 2、`S0CategoryPageRange.prefix` 2、`markPendingDeletion(` 1、`advanceScan()` 2、`onSnapshotDidChange` 1；`case .s2:` 分支原文（IC-147 `:160` 字面量，含缩进）1 |
| 7 | C | `testIC157C_RoundTripThroughCoordinatorLandsMarksAndKeepsPageIdentity` | 0.026 | 照 IC-131 夹具起真实协调器，S1 读到一个范围、`.ready`；模型 `presentedCategory = .screenshot`。`makeS2Handoff(virtualRangeID: "cat:screenshot", 屏幕截图, 三张, 第二张)` → `enterS2(from:)` true、`route == .s2`；`entry.rangeDisplayInformation == ("cat:screenshot","屏幕截图",3)`、顺序与起点一致。`handleSwipeUp()` 后 `M[cat:screenshot]` = [第二张]、`F` = `cat:screenshot`。`leaveS2(with: makeExitPayload())` true、`route == .s1`、`s2Machine == nil`、`s1FeedbackEventCount == 0`、`M` 不变、`K` 非 nil、在途已空、提交非 nil 且组「屏幕截图」成员 [第二张]；模型同一对象、值仍 `.screenshot`。①依赖见第 7.9 条 |
| 8 | C | `testIC157C_ReturnRecomputeIsGuardedByPresentedCategory` | 0.001 | 谓词 nil → false，五个类别各 true；两台真实状态机各走「开屏 → 摄入 `.readyWithItems` → 扫描完成」（重排 1）。谓词 false 支不摄入，快照不变；谓词 true 支摄入 `.readyWithoutItems`，快照变为该桩快照；两支重排计数都仍 1。视图不装载（陷阱 23） |

**既有相关用例（#315 逐条 `passed`）**：

- **IC-147** `IC147S0BehaviorTests` 16／16。含改口径的 `testIC147CAssertion10ForbiddenWordingNeverAppears`、`testIC147CAssertion11EveryS0StringGoesThroughTheCatalog`，以及钉 App 路由分支的 `testIC147AAssertion03RouteBranchesOtherThanS1AreByteIdentical`。
- **IC-148** `IC148S0VisualTests` 14／14，含改口径的 `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys`。
- **IC-156** `IC156CategoryPageTests` 11／11。含改口径的 `testIC156C_PageFilesKeepS0Discipline`、`testIC156C_CatalogGainsFiveKeysAndBothGatesAreUpdated`、`testIC156D_FlowHostsHomeAndPageAndAppOnlySwapsBuilder`，以及 `testIC156B_*` 两项。
- **S1 状态机与会话层**：`S1StateMachineTests` 20／20（含 `:156`／`:275`／`:349` 三处 `makeS2Handoff(for:)` 拒绝断言所在用例）；`SessionStoreTests` 14／14。
- **IC-131** 7／7：`IC131S1WriteBackToastTests` 5，`IC131S1TrashBadgeTests` 2。
- **IC-132** 9／9：`IC132S1RangeNamePersistenceTests` 4，`IC132SubmissionDeadEndTests` 5。
- **IC-127** 全部 26 项；**IC-129** `IC129ExistenceReconciliationTests` 6／6。
- **IC-153** `IC153ScanServiceTests` 13／13；**IC-155** `IC155CategoryDataAndCoverTests` 9／9；**IC-151** `IC151AmbientFixedColorTests` 8／8。

---

## 六、既有断言改口径（裁定 六）

| 断言 | 文件:行（改后） | 旧 | 新 | #315 |
|---|---|---|---|---|
| IC-147 断言 10 | `IC147S0BehaviorTests.swift:798` | 37 | **38** | passed |
| IC-147 断言 11 | `:847` | 37 | **38** | passed |
| IC-148 断言 10 | `IC148S0VisualTests.swift:841` | 37 | **38** | passed |
| IC-156 断言 6 | `IC156CategoryPageTests.swift:171` | `S0CategoryPageMetrics.` 57 | **59**（实装数：常驻行右文 `pinnedRowFontSize`／`pinnedRowOpacity` 各一处；未走回退写法，故不是 60） | passed |
| IC-156 断言 7 | `:216`／`:217` | 37／5 | **38／6** | passed |
| IC-156 断言 7 | `:219-226`、`:236` | 五条 | 六条（加 `longPressHint`，无占位符） | passed |
| IC-156 断言 10 | `:487` | `machine.ingest(` 2 | **3** | passed |
| IC-156 断言 10 | `:502` | `S0CategoryPageRange.prefix` 1 | **2** | passed |
| IC-156 断言 10 | `:516-524` | 五实参构造 | 七实参，顺序 `machine:`／`dataProvider:`／`flowModel:`／`onSwitchToOrganizeTab:`／`onMoveToBasket:`／`onEnterS2:`／`toastDurationMilliseconds:` | passed（编译期核签名） |

「不得打红」清单的其余断言**一条未改**（第九节 G894 逐项实测值）。

---

## 七、卡内问题与实现取舍（请决策会话追认）

### 7.1 断言 1「构造成功那一次写出恰 1 次（名字表变了）」与自身前置矛盾

卡面前置是先 `markPendingDeletion(["b"], "cat:bigVideo", "大视频")`。

- 按 IC-156 实装，进篮在 `sessionStore` 赋值（`didSet` → 写出口）之前已把同名写进名字表。
- 随后 `makeS2Handoff(virtualRangeID: "cat:bigVideo", displayName: "大视频", …)` 写入的是**同一个值**，名字表不变，快照与上一次写出相等 → `publishSnapshotIfChanged()` 去重后**不写出**。
- 写出口若在断言开头就接上，这一次写出是 **0**，「恰 1」在正确实装下必红。

**处理**：在进篮**之后**才接写出口（上一次快照为 nil，交接构造里的显式写出必然触发一次）。这钉住的是「构造入口确实走了写出口」：去掉那行 `publishSnapshotIfChanged()` 即为 0、判红。卡面括号里的理由（名字表变化）另起一段钉住：先进篮 `cat:bigVideo` 让写出口有基准，再对**从未登记过名字、`M` 无键**的 `cat:screenshot` 构造交接，写出由 1 变 2，写出的快照带「屏幕截图」、`M` 无该键、会话层不变。本机行为模拟与 #315 均通过。

### 7.2 白名单是精确行号，相邻注释会失真

白名单写「仅 `:798`、`:847`」「仅 `:841`」「仅裁定 六七处」，有三处上方注释会与新值矛盾：

- IC-156 `:169`「按实装数写死（57）」；
- `:234`「页面只引用这五条…归 IC-157」；
- `:483`「进篮成功后一处、返回首页一处」。

**处理**：

- IC-147／IC-148 三处**只改那一行**，新说明写成同一行行尾注，上方历史注释本身仍真，不动。
- IC-156 三处注释随断言值同步改写；构造字面量上方加一行说明；`:499` 改用同一行行尾注。
- 逐行见 `change-list.md` 第四节。IC-156 文件的 diff 为 +14／−8，全部落在裁定 六七处及其紧邻注释。

### 7.3 测试文件段落「C 放 B 之后」与「各段互不相邻」自相矛盾

卡写「B 的追加放类首、C 的追加放 B 之后、A 在类末尾——只要各段互不相邻」：C 紧接 B，两段必然相邻。

- 卡声称的摘取单元只有 A、A→B、A→B→C，都按提交顺序摘，相邻不影响。
- 实测三个单元无冲突；C 跳过 B 直接接 A 会冲突，但卡未声称该单元，C 在产品上也依赖 B 的页面新参数（第十节）。
- **处理**：按「B 类首、C 紧接 B、A 类末尾」落位。

### 7.4 卡面断言之外的补强（不改变卡面任何一条的口径）

- **断言 2** 补「写回后同一虚拟范围再逐张写入被拒」，钉住裁定 二「一次 S2 会话一次登记」。
- **断言 4** 补两条：常驻行切片内 `pinnedRowFontSize` 恰 2，钉住「右文与左文同一写法」；`S2View.swift` 上 `onLongPressGesture` > 0 的正对照，防 0 计数空转。
- **断言 6** 的「import 只有 Combine／Foundation（零 SwiftUI 也可）」落为：`import` 行非空且模块集合 ⊆ {Combine, Foundation}。
- **断言 1** 的非法输入比卡面多一种「空范围标识」，卡在裁定 二的校验里列了它。

### 7.5 断言 7、8 在 `MainActor.run` 内执行

- 断言 7 调协调器（`@MainActor`），照 IC-131 `async` + `await MainActor.run { … }` 写法。
- 断言 8 调视图类型的静态谓词，同样放进 `MainActor.run`，避开视图类型隔离推断的编译面不确定性。
- 两者 #315 均编译通过、`passed`。

### 7.6 `makeS2Handoff(virtualRangeID:` needle 决定了声明与调用的换行写法

断言 3 与断言 6 的 needle 要求 `(` 后紧跟 `virtualRangeID:`，仓内惯常的「左括号后换行、逐参缩进」会让 needle 空转（记忆：源码扫描首匹配陷阱第 4 条）。

- **处理**：`S1StateMachine.swift:685` 声明与 App `:114` 调用都写成「首参同行、其余参数与首参对齐」。
- App 调用行因此较长，约 120 列。

### 7.7 文档注释改动落在卡面行号窗口之外（同文件、白名单内）

- **流程文件头注释**：「两处重算点」改「重算点」，补一条 IC-157 重算点说明，「进篮写入经…闭包」改「进篮写入与进 S2 都经…闭包」。不改的话，注释会与第三处摄入、`onEnterS2` 矛盾。
- **App `s0Screen` 文档注释**：末尾补三行。
- **页面**：MARK 注释「右侧留空：长按入口归 IC-157」改写。

### 7.8 `S0CleanupFlowModel` 的 `= nil`

卡写 `@Published var presentedCategory: S0CategoryIdentifier?`（无初值）。实装加了显式 `= nil`，避开「包装属性可选值隐式 nil 初始化」的编译面不确定性。断言 6 的 needle 是其子串，计数不受影响。

### 7.9 断言 7 的 ① 依赖（卡要求写明）

`leaveS2` 在 `CleanupCoordinator.swift:229` 调 `reconcileS1WithPhotoLibrary()`，其后链路：

1. 测试宿主相册授权为未决定，`PhotoLibraryService.s1RangeRead` 走 `.requestSystemAuthorization` 分支，返回 `.failure`（`Services/PhotoLibraryService.swift:201-219`，实读）；
2. `S1StateMachine.reconcile` 在守卫里的 `case let .success = result` 处提前返回，不碰 `M`／`K`，也不调存在性探针。

若日后测试宿主获得授权，探针会把虚构资产标识从 `M` 剔除，本断言与 IC-131 断言 4 会同时失效。

### 7.10 ③ 未经模拟器验证的行为（均留 H78）

- **重建后推出类别页**：`NavigationStack` 以**初始即非 nil** 的 `navigationDestination(item:)` 绑定重建时，是否直接推出类别页、有没有推入动画——H78 第 2 条。
- **长按松手连带点按**：长按松手时 `Button` 的点按是否连带触发——H78 第 8 条。
- **回来时 `SEL` 清空**：从 S2 回来类别页重建，`SEL` 清空（③ 取「清空」，规格未定）——H78 第 2 条。
- **切 tab 触发摄入**：切走再切回清理 tab、类别页在前时 `.onAppear` 也会摄入一次；`ingest` 幂等且不重排（断言 8 负对照），无行为影响。

---

## 八、本机预验证（Python 手工移植；②，不构成 XCTest 会通过的证据，权威结论只取 CI）

脚本在会话草稿区：`scan.py` 是 `strippedSource`／`occurrences`／`slice`／`numericLiterals`／`localizationKeys` 的逐字符移植；`check_swift_strings.py` 是 Swift 字符串与括号结构预检。

| 脚本 | 对象 | 检查数 | 失败 |
|---|---|---|---|
| `check_a.py` | 断言 3：`makeS2Handoff(for:)` 切片两侧逐字相等（35 行）；六个 needle 新旧计数（`activeVirtualRangeIDs` 声明 0→1、`func makeS2Handoff(virtualRangeID:` 0→1、`publishSnapshotIfChanged()` 5→6、helper 声明 0→1、helper 全部 0→3、`setMarked(` 3→3）；并生成断言 3 内嵌原文 | 7 | 0 |
| `sim_a.py` | 断言 1、2 的行为移植（`SessionStore.setMarked`／`applyS2Return` 修剪规则、写出口去重、三入口新守卫、提交组名），断言原样重跑 | 94 | 0 |
| `check_b.py` | 断言 4、5 全部 needle；IC-156 断言 6（两文件裸数、PhotoKit 七项、恒深色七项、原文 `Text("`、`S0CategoryPageMetrics.` 59、42 名逐个引用、`ThumbnailView(`、氛围底、符号三处）；IC-156 断言 7（六条取值与引用、页面 key 集合、占位符计数）；IC-147 断言 10 禁用措辞与断言 11、IC-148 断言 10 的「引用集合 = 目录集合」 | 92 | 0 |
| `check_c.py` | 断言 6 全部 needle（含 `case .s2:` 含缩进逐字）；IC-156 断言 10 全部计数与测试文件改后字面量；IC-147 断言 3（四个路由分支、`.onAppear` 守卫原文、两 builder）；IC-147 断言 7 App 零直写；IC-153 断言 11 App 部分；IC-151 退役符号；App `body` 与 `tabContainer` `.onAppear` 两侧切片逐字相等 | 77 | 0 |
| `check_swift_strings.py` | 改动与新建的 8 个 `.swift` 文件 | 8 | 0 |

**特别核**（卡「本机预验证」节点名）：

- `machine.ingest(` 恰 3 只扫流程文件；`S0CategoryPageRange.prefix` 恰 2 扫 App；`enterS2(from:` 恰 2；`case .s2:` 字面量含缩进逐字 1。
- `S0CategoryPageMetrics.` 实装数 59：B2 未走回退写法，故没有 `gridCellCornerRadius` 的新增一处。

---

## 九、闸门

### G892

- **diff 限于白名单**：`git diff --name-status e97f394 0a6c953` 共 11 个路径，全在白名单（`change-list.md` 第二节）。
- **不得触碰清单两侧 SHA-256**（`git show <rev>:<path>` 求值）：

| 文件 | `e97f394` | `0a6c953` |
|---|---|---|
| `Features/S0/S0View.swift` | `4A81D3FA72CCF6F522265C202608E967AD8E7102712CFB37D165FDEF6FCD558F` | 同左 |
| `Features/S0/S0TabContainer.swift` | `2F914CFAA30BAB29B3F3A5FCFA9B3262914597976994EF0FD11409EE2FFD2F34` | 同左 |
| `Features/S0/S0CategoryRow.swift` | `DF67A0FCAFA50C009ACEE6A0EE6884CC2019E86F48EFDACDB7839FAE301FB1FB` | 同左 |
| `Features/S0/S0SegmentBar.swift` | `B1261C79714CEB3BD4363CE78B1CD59012F439FB69698599B1F8E92F26B4D1EF` | 同左 |
| `Features/S0/S0HomeMetrics.swift` | `2D88A10213B067EE5F62865F2968ECA2F0F207B884BF01BB8EFD28CA52B5A267` | 同左 |
| `Features/S0/S0CategoryPageMetrics.swift` | `F7BB7BB65317BCDCB9811955E328E52779BF802E2D89A5949E95B60F9DD40BB2` | 同左 |
| `App/CleanupCoordinator.swift` | `C8B4B852FC19FCAC809BD2EC4E5943D541C8CED41E5C7F8EA6B099E0E36DA53A` | 同左 |
| `Core/SessionStore.swift` | `04095174D021739258498364D607C6229B10E3D8C1487CB8EB6DA2EE1214ED7F` | 同左 |
| `Core/S0StateMachine.swift` | `29E1A38485A2F0305ABEB62C9E8607494AA47C83895369687AD5994DD32B0425` | 同左 |
| `Core/S2StateMachine.swift` | `90DDFFAD6AB737BBE00EA1C1CB1CB402503949C45CB5080E55B483A248DFE032` | 同左 |
| `Core/SessionPersistence.swift` | `BE8379A3542C9D8EA193CE3ACACC50530FC6A61A60FE7664DDB6FD4DD1DB9A83` | 同左 |
| `Core/L10n.swift` | `9D72BE86D70F31972C7DFF31B172C4F8C5CB9AF9A1716AEC2CEFE188BA203826` | 同左 |
| `Features/S2/S2Calibration.swift` | `B06168A00987D70D17E9A41B2525A5FCE18A0F2CB081C1D70576E7382087410F` | 同左 |
| `Services/S0ScanRules.swift` | `B37B0A0C6866C3F6ABF4B988CCFD962C7BC78CF84A9B95E22322FCE5CC3E663D` | 同左 |

| 目录 | 文件数（两侧） | 逐文件两侧 SHA-256 全同 | 聚合（按路径拼接各文件 SHA-256 再哈希，前 16 位） |
|---|---|---|---|
| `Core/`（除 `S1StateMachine.swift`） | 9／9 | 是 | `CA3A6952327FF430` |
| `Services/` | 11／11 | 是 | `A6149DADFF5C81D2` |
| `Features/S1/` | 1／1 | 是 | `B0D9C6E9E789F9B6` |
| `Features/S2/` | 9／9 | 是 | `BB5354CC653ECF37` |
| `Features/S3/` | 1／1 | 是 | `4C756DF6152300D5` |
| `Features/S4/` | 1／1 | 是 | `79BBCFC2210CA838` |
| `Features/S5/` | 1／1 | 是 | `24B15569428A0D8C` |
| `Features/Shared/` | 1／1 | 是 | `E47B2834EF63695E` |
| `.github/` | 1／1 | 是 | `C632EEBCF1136833` |
| `Scripts/` | 33／33 | 是 | `302809A0BEEBB3F2` |

- **`makeS2Handoff(for:)` 的 awk 切块 diff**：

```
diff <(git show e97f394:PhotoCleanupMVE/Core/S1StateMachine.swift | awk '/^    func makeS2Handoff\(for rangeID: String\)/{f=1} f{print} f&&/^    }$/{exit}') \
     <(git show HEAD:PhotoCleanupMVE/Core/S1StateMachine.swift    | awk '/^    func makeS2Handoff\(for rangeID: String\)/{f=1} f{print} f&&/^    }$/{exit}')
```

  输出为空，退出码 **0**，切块 35 行。

- **`App/CleanupCoordinator.swift`**：两侧同一 blob（见上表）。
- **App 入口 hunk 头**（`git diff e97f394 0a6c953 -- PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`），IC-147 断言 3 的五段原文仍在（第八节 `check_c.py` + #315 passed）：
  - `@@ -8,6 +8,9 @@`：C3，`s0FlowModel`；
  - `@@ -88,10 +91,14 @@`：C4，builder 注释与 `flowModel:` 实参；
  - `@@ -102,6 +109,16 @@`：C4，`onEnterS2:` 闭包。
- **`Localizable.xcstrings`**：只增 11 行，即一条 `s0.categoryPage.longPressHint`，无删除。

### G893

- `Features/S2/S2Calibration.swift` 不在 diff（两侧 SHA-256 同上表）；`schemaVersion` = **7**（`:118`）；`S0ScanRules.cacheSchemaVersion` = **1**（`:27`）。
- 登记数：`S0HomeMetrics` 切片 `\n    static let ` = **52**，`S0CategoryPageMetrics` = **42**。
- `SessionStore.SortOrder` 仍两个 case（`:5-8`，文件两侧同一 blob）。
- **冻结三链与四条探针的远端 tip**（`git ls-remote origin`，合并前实读），全部与卡一致：

| 分支 | tip |
|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` |
| `probe/ic-067-screenshot-subtype` | `9db02b93eccbb87d126602901807e70823535111` |
| `probe/ic-125-sentinel-negative` | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` |
| `probe/ic-137-media-playback` | `486bcb769b59eb1146c5a231c7998847206777cc` |
| `probe/ic-145-scan-service` | `d373afc7125104c01acfc296829229090e6871ce` |

### G894：「不得打红」清单逐项实测值（`0a6c953`，剔注释口径同各断言）

| 项 | 实测 |
|---|---|
| App `advanceScan()` ／ `onSnapshotDidChange` ／ `S0ScanOutcomeTransition.events(` ／ `S0TabContainer(` ／ `tabContainer(s1Machine: machine)` | 2 ／ 1 ／ 1 ／ 1 ／ 1 |
| App `S0CleanupFlowView(` ／ `S0View(` ／ `markPendingDeletion(` ／ `feedbackToastDurationMilliseconds` | 1 ／ 0 ／ 1 ／ 3 |
| App 四个路由分支（`.s2`／`.confirmation`／`.execution`／`.completion`）与 `.onAppear` 启动守卫原文 | 各 1；`body` 切片两侧逐字相等 |
| 流程 `S0View(` ／ `navigationDestination(item:` ／ `.returnedFromCategoryPage` ／ `.toolbar(.hidden, for: .navigationBar)` ／ `S0CategoryPageView(` | 1 ／ 1 ／ 1 ／ 2 ／ 1 |
| 流程 `CleanupCoordinator` ／ `SessionStore` ／ `S1StateMachine` | 0 ／ 0 ／ 0 |
| 页面 `S1ChromeTypography.titleFontSize` ／ `ThumbnailView(` ／ `S2AmbientBackdropView()` ／ `Image(systemName: ` | 1 ／ 1 ／ 1 ／ 3 |
| 页面 42 个登记名逐个引用 ／ 裸数 | 42／42 ／ {0, 1, 2} 之内 |
| `makeS2Handoff(for:)` 函数体 | 逐字不变（G892 awk） |
| `S1StateMachineTests`、`SessionStoreTests`、IC-131／IC-132／IC-127／IC-129 | 全部 passed（第五节） |
| `s0.` 目录条数 | **38** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 退出码 **0**（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） |

### G895（合并前置）

| 条件 | 结果 |
|---|---|
| G892～G894 | 满足（上文） |
| 绿 | #315：852 项 0 失败、真实退出码 0、执行摘要 notice、`OS:26.2, name:iPhone 16` 实证行、IPA 1687402 字节 + SHA-256、分段耗时 notice（第四节） |
| 断言 1～8 逐条 `passed` | 是（第五节） |
| 相关既有用例逐条 `passed` | 是（第五节） |
| pbxproj 撞号扫描 | 定义行 24 位 id 无重复；新 id `10000000000000000000005F`／`20000000000000000000005C`（测试文件，A）、`100000000000000000000060`／`20000000000000000000005D`（流程模型，C）；出现次数 3／2／3／2 |
| 工作树净 | 合并前 `git status --porcelain` 只有本报告目录（随 docs 提交入库） |
| `main` 未被他人推进 | 合并前 `git ls-remote origin refs/heads/main` = `e97f39499347888f0ae50f6d44ee2985b6ece68b` |
| 本地门禁 | `Scripts/selfcheck.ps1` 退出码 **0**（末行「结构自验通过…」，含「扫描 needle 与源码变体交叉审计通过：扫描 42 个测试源文件」）；`scan-hardcoded-user-visible-strings.ps1` 退出码 **0**；`git diff --check e97f394 0a6c953` 退出码 **0** |

结论：满足，按授权 `--no-ff` 合并入 `main` 并推送。

### G896（合并后回填）

**合并**：第一次合并在 Bash 工具里被自动模式分类器以 `[Merge Without Review]` 拒绝。按第 170 条惯例换一次工具，在 PowerShell 工具里执行同一条单一用途命令 `git merge --no-ff feature/ic-157-long-press-into-s2 -m …`，一次通过（`ort` 策略，13 个文件）。

| 项 | 值 |
|---|---|
| 合并提交 | `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b` |
| 父提交 | `e97f39499347888f0ae50f6d44ee2985b6ece68b`（`main`）、`e8700ab3770cf66c77871aa1237354df3670fae4`（分支报告提交） |
| 树 | 合并提交与 `e8700ab` 同为 `fcb68d137065f3cea777227233bd5766721ef151` |
| 推送 | `git push origin main`：`e97f394..ab3eed1`，一次通过；`git ls-remote origin refs/heads/main` = `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b` |
| 自动运行 | **#316**，run id `35238730601`，attempt 1，事件 `push`，分支 `main`，被测提交 `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b` |
| check-run id | `105261331766`（本次运行现取） |
| 作业 | 15:12:49Z → 15:19:38Z，**success**。12 个步骤全 success；「运行 XCTest」15:13:01Z → 15:18:21Z，日志有 `XCTest 已全部通过。` ⟹ 真实退出码 **0** |
| 执行摘要 notice | `Executed 852 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 852 tests / 0 failures` |
| 分段耗时 notice | `模拟器启动 54 s；xcodebuild test 264 s；总 319 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1687402，SHA-256=13452ccabb1c8511bf589344c14013993765cd25e8dc59882b53078bcac9278d`；artifact `PhotoCleanupMVE-unsigned-ab3eed1f4926`，id `10504294204`，zip 1687572 字节（字节数与 #315 相同、哈希不同，IPA 不可复现，已知） |
| 注解 | 仅上述 3 条 notice，error／warning 0 条 |
| 实证行（整包日志 zip 247948 字节，「9_运行 XCTest」单文件，剔回显后） | 目的地 `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`；`Executed 852 tests, with 0 failures (0 unexpected) in 38.116 (44.790) seconds`；`** TEST SUCCEEDED **`；`Test Suite 'All tests' started` 1 次、`Restarting after unexpected exit` 0 次；唯一 Test Case 身份 852（passed 852 ／ failed 0）；`.swift:<行>: error` 0；`testIC063…` passed（4.152 s）；IC-157 八项 passed |

---

## 十、摘取单元实测（克隆仓库，草稿区 `pick/`）

基底 `e97f39499347888f0ae50f6d44ee2985b6ece68b`，逐个 `git cherry-pick`：

| 单元 | 命令序列 | 退出码 | 结果 |
|---|---|---|---|
| A 单独 | `5517548` | 0 | 无冲突 |
| A→B | `5517548`、`ad6dfd7` | 0、0 | 无冲突 |
| A→B→C | `5517548`、`ad6dfd7`、`0a6c953` | 0、0、0 | 无冲突；`git diff --stat unitABC 0a6c953` 为空（树相同） |
| 负对照：B 单独 | `ad6dfd7` | **1** | `DU PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift`；其余五个文件（页面、目录、三份既有测试）干净暂存——产品改动本身可单独应用 |
| 附：A→C（跳过 B） | `5517548`、`0a6c953` | 0、**1** | `UU PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift`；卡未声称该单元 |

---

## 十一、人工判定项 H78（原样列出，留给 Lynn 真机，执行端不代为下结论）

装合并后 `main` 的产物（同一包可连判 H72～H77）。

1. **长按进 S2**：类别页长按任一格 → 进 S2，顶部胶囊显示类别名（如「大视频」），当前张就是被长按那张；左右翻页的顺序与网格顺序一致（从大到小）。
2. **S2 内标记、回来落回类别页**：在 S2 上滑标记两张后返回 → 回到**类别页**（不是首页），被标记的两格已从网格消失、其余顺序不变、勾选清空；再返回首页，该类别行项数与体积、hero、分段条已减，待删篮胶囊增两张。
3. **S2 内撤销**：在 S2 标记一张再撤销，回来那格仍在网格里。
4. **S3 分组**：切「逐张整理」tab 进 S3——从 S2 标记的那两张在「大视频」组里（与类别页直接进篮的同一组）；S1 的范围组不受影响。
5. **续接**：再从同一类别长按另一张进 S2，起点是新长按的那张（不是上次离开的位置）。
6. **提示行**：常驻行右侧显示「长按任一格逐张看」，与左侧「已选 N 项」同一字号与明度。
7. **回归**：H77 七项快过（尤其第 1 条首页顶排位置与右滑返回）；S1 范围进 S2 的行为不变；写回失败 toast 若从未出现记「未触发」。
8. **点按不被长按连带**：长按松手后，那一格的勾选态**不变**（`Button` 的点按不应随长按一起触发）；VoiceOver 下格仍读作按钮。若长按后勾选态变了，回报——执行端有一行回退写法（裁定 五）。

（卡「报告」节要求「人工判定项七条原样列出」，H78 节实为八条，按 H78 节全部列出。）

---

## 十二、发现但未处理的问题（按纪律只报告不修）

1. **进 S2 失败时交接构造的副作用不回滚。**
   - 触发：`enterS2(from:)` 返回 false，例如标定参数解析为 nil，或资产标识里有空串（`S2StateMachine` 守卫拒、`makeS2Handoff(virtualRangeID:)` 按卡不拒）。
   - 后果：名字已登记并写出一次，在途登记残留；页面对 `false` 无任何反馈（卡 C2 写法 `_ = onEnterS2(…)`）。
   - 残留的影响：只在协调器 `route == .s2` 时才会被调用的逐张镜像入口上放宽了守卫，路由不在 `.s2` 时不可达，③ 无可见影响。
   - 建议：日后评估「进入失败时撤销在途登记」或「类别页提示进入失败」。
2. **写回失败时在途登记也不移除**（卡写「写回成功后移除」）。同一范围再次长按会重新登记，集合语义下无害；属同一类残留，与第 1 条一并评估。
3. **从类别页进 S2 后改走 S2 的待删篮路径**（`enterConfirmationFromS2`，进 S3）：模型里的类别仍在，之后回到清理 tab 会落在类别页而不是首页。③ 规格未写该路径的落点；本卡未测，H78 未列。
4. **写回失败的提示仍走 S1 通道**（裁定 四），用户在类别页看不到，下次进「逐张整理」tab 才弹出。卡已记 SPEC-S0 v3 欠账，此处复述。
5. **`K[cat:]` 的 `O_记录` 为占位**（裁定 三），类别页不消费续接，H78 第 5 条的「起点是新长按的那张」由交接构造的 `currentAssetID` 保证、与 `K` 无关。SPEC-S0 v3 未定项待登记。
6. **App `onEnterS2` 闭包的一行较长**（约 120 列，第 7.6 条），为 needle 口径所迫；日后若改 needle 为扫实参标签本身，可恢复逐参换行。

---

## 十三、报告提交方式与 SHA 核验

- **提交方式**：代码三个提交先推送取 CI；本报告与 `change-list.md` 在**同一分支**追加一个 docs 提交（纪律 7：CI 编号推送后才产生），纯报告提交按 `paths-ignore` 不触发 CI。合并后 G896 的回填照 IC-156 先例（`e97f394`）在 `main` 上追加 docs 提交。
- **40 位 SHA 核验**（两份报告里全部 40 位十六进制串，逐个 `git cat-file -e <sha>^{commit}`，合并前实跑）：

| SHA | 退出码 |
|---|---|
| `0a6c953c52a4ee857d427d4589ce7bfb94f62582` | 0 |
| `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | 0 |
| `486bcb769b59eb1146c5a231c7998847206777cc` | 0 |
| `551754841a57507b602e2227ef4fe5871e20dea5` | 0 |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 0 |
| `9db02b93eccbb87d126602901807e70823535111` | 0 |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 0 |
| `ad6dfd71fb946ccab484ea2bf22154024919b27a` | 0 |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | 0 |
| `d373afc7125104c01acfc296829229090e6871ce` | 0 |
| `e97f39499347888f0ae50f6d44ee2985b6ece68b` | 0 |

  G896 回填时新增的两个 SHA（合并后实跑）：

| SHA | 退出码 |
|---|---|
| `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b` | 0 |
| `e8700ab3770cf66c77871aa1237354df3670fae4` | 0 |
