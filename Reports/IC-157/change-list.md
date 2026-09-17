# IC-157 变更清单

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260917-157-long-press-into-s2.md` |
| 基线 `main` | `e97f39499347888f0ae50f6d44ee2985b6ece68b` |
| 分支 | `feature/ic-157-long-press-into-s2` |
| 子项 A 提交 | `551754841a57507b602e2227ef4fe5871e20dea5` `feat(IC-157 A): S1StateMachine 虚拟范围三入口——交接构造、逐张镜像与整体写回放行在途 cat: 范围` |
| 子项 B 提交 | `ad6dfd71fb946ccab484ea2bf22154024919b27a` `feat(IC-157 B): 类别页长按任一格进 S2 的手势与常驻行右侧提示「长按任一格逐张看」` |
| 子项 C 提交 | `0a6c953c52a4ee857d427d4589ce7bfb94f62582` `feat(IC-157 C): 类别页身份上提到 App 持有的 S0CleanupFlowModel，长按接线进 S2，从 S2 回到类别页时重算` |
| 报告 | 本文件与 `self-check.md`，另一个 docs 提交（同一分支，纪律 7：CI 编号推送后才产生） |
| 报告提交 | `e8700ab3770cf66c77871aa1237354df3670fae4`（分支） |
| 合并提交 | `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b`（`--no-ff`，父 `e97f394` 与 `e8700ab`）；合并后 `main` #316 一次绿 852 项 0 失败；G896 由 `main` 上的 docs 提交回填 |
| 出厂值 | **无变更**。`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S0ScanRules.cacheSchemaVersion` 仍 **1**；`S0HomeMetrics` 仍 **52**；`S0CategoryPageMetrics` 仍 **42**（本卡不加常量） |

## 二、文件清单（`git diff --numstat e97f394 0a6c953`，全部在白名单内）

| 文件 | 增／删 | 白名单条目 | 所属提交 |
|---|---|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | +84／−5 | A1～A4 | A |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift`（新） | +834／−0 | 本卡断言 | A 建 462 行；B +160；C +212 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +8／−0 | 两个新文件登记 | A +4；C +4 |
| `PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift` | +27／−8 | B1～B3 | B |
| `PhotoCleanupMVE/Localizable.xcstrings` | +11／−0 | 仅 B4 一条 | B |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | +2／−2 | 仅 `:798`、`:847` | B |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | +1／−1 | 仅 `:841` | B |
| `PhotoCleanupMVETests/IC156CategoryPageTests.swift` | +14／−8 | 裁定 六七处 | B +7／−5；C +7／−3 |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift`（新） | +10／−0 | C1 | C |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | +32／−7 | C2 | C |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | +17／−0 | 仅 C3、C4 | C |

合计 11 个路径，+1040／−31。

## 三、逐项变更

### 子项 A（`Core/S1StateMachine.swift`）

| 处 | 改后行 | 变更 |
|---|---|---|
| A1 | `:309` | `knownRangeNamesByID` 之后加 `private(set) var activeVirtualRangeIDs: Set<String> = []`（内存态，不入会话档；两行文档注释） |
| A2 | `:638-672` 不动；`:674-717` 新增（含文档注释） | `makeS2Handoff(for:)` 函数体逐字不变。新增 `makeS2Handoff(virtualRangeID:displayName:orderedAssetIDs:currentAssetID:)`：校验范围标识与显示名非空、列表非空且唯一、起点在列表内，否则 nil 零副作用；成功时 `knownRangeNamesByID[virtualRangeID] = displayName` → **显式 `publishSnapshotIfChanged()`** → 登记在途 → 返回交接（`totalAssetCount` 取列表长度、`pendingDeletionAssetIDs` = `M[virtualRangeID]` ∩ 列表、`sessionMergedPendingDeletionCountProvider: { self.badgeCount }`）。不设 `state`／`isObscured` 门槛 |
| A3 | `:761-782` | `applyS2Return` 守卫由 `!isObscured, state == .ready` 改为 `activeVirtualRangeIDs.contains(entryContext.rangeID) \|\| (!isObscured && state == .ready)`；写回成功（`sessionStore = nextStore` 之后）`activeVirtualRangeIDs.remove(entryContext.rangeID)`；其余行不动 |
| A4 | `:784-847`（helper 在 `:822-847`） | `applyS2PendingDeletionChange` 在既有守卫**之前**加虚拟分支（在途范围只校验待删集合 ⊆ 交接列表，然后调 helper）；既有守卫逐字不变；原 diff 循环整段搬进 `private func applyPendingDeletionDiff(_:rangeID:)`（`:824`），两路各调用一次。`M` 仍只经 `setMarked` 写（全文件 `setMarked(` 仍 3 处） |

`makeS3Submission`、`markPendingDeletion`、`publishSnapshotIfChanged`、`reconcile` 等其余方法一字未动。

### 子项 B

| 处 | 文件:改后行 | 变更 |
|---|---|---|
| B1 | `S0CategoryPageView.swift:276`、`:287`、`:293` | 存储属性 `private let onLongPress: ([String], String) -> Void`；init 形参 `onLongPress: @escaping ([String], String) -> Void = { _, _ in }`，声明在 `onBack` 之后、`toastDurationMilliseconds` 之前（带默认值，A→B 下流程文件唯一构造点不改即可编译） |
| B2 | `:436-440` | 格的 `Button { toggle } label: { … }.buttonStyle(.plain)` 之后加 `.simultaneousGesture(LongPressGesture().onEnded { _ in onLongPress(selection.items.map(\.id), item.id) })`；`LongPressGesture()` 不传时长与距离。**未走回退写法** |
| B3 | `:373-394` | 常驻行由单个 `Text` 改为 `HStack { 左文 Spacer(minLength: 0) 右文 }`；右文 `Text(L10n.text("s0.categoryPage.longPressHint"))`，字号与明度写法照左文逐字（`.font(.system(size: S0CategoryPageMetrics.pinnedRowFontSize))` + `.foregroundStyle(S0HomePalette.dimmedText(opacity: S0CategoryPageMetrics.pinnedRowOpacity))`），不加常量；外层 `.frame(maxWidth: .infinity, alignment: .leading)` 与两条 padding 保留；MARK 注释「右侧留空：长按入口归 IC-157」改为「右侧长按提示，与左文同一字号与明度：IC-157」 |
| B4 | `Localizable.xcstrings` | 只增一条 `s0.categoryPage.longPressHint` = `长按任一格逐张看`（zh-Hans，`extractionState: manual`，`state: translated`，与 IC-156 五条同格式，按字母序排在 `selectAll` 之前） |
| B5 | 见第四节 | IC-147 两处、IC-148 一处、IC-156 四处（`:170`、`:215`、`:216`、期望表与集合注释） |

### 子项 C

| 处 | 文件:改后行 | 变更 |
|---|---|---|
| C1 | `Features/S0/S0CleanupFlowModel.swift`（新，10 行） | `import Combine`；`final class S0CleanupFlowModel: ObservableObject { @Published var presentedCategory: S0CategoryIdentifier? = nil }`（显式 `= nil`，避开「包装属性可选值隐式 nil」的编译面不确定性） |
| C2 | `S0CleanupFlowView.swift` | 形参 `flowModel: S0CleanupFlowModel`（`dataProvider` 之后）、`onEnterS2: @escaping (S0CategoryIdentifier, [String], String) -> Bool`（`onMoveToBasket` 之后）；`@State private var presentedCategory` 删除，改 `@ObservedObject var flowModel`（`:35`）；`navigationDestination(item: $flowModel.presentedCategory)`（`:65`）；`onChange(of: flowModel.presentedCategory)`（`:69`）；新增 `static func shouldRecomputeOnAppear(presentedCategory:) -> Bool`（`:57`，非 nil 即 true）与 `.onAppear { if Self.shouldRecomputeOnAppear(…) { machine.ingest(dataProvider.currentSnapshot()) } }`（`:76-80`，第三处 `machine.ingest(`）；首页 `onEnterCategoryPage` 与类别页 `onBack` 改写模型属性；`page(for:)` 传 `onLongPress: { orderedAssetIDs, currentAssetID in _ = onEnterS2(identifier, orderedAssetIDs, currentAssetID) }`（`:109-111`）。文件头文档注释补一条 IC-157 重算点说明，「两处重算点」改「重算点」、「进篮写入经…闭包」改「进篮写入与进 S2 都经…闭包」 |
| C3 | `App/PhotoCleanupMVEApp.swift:11-13` | `s0TabSelection` 之后加 `@StateObject private var s0FlowModel = S0CleanupFlowModel()`（两行文档注释） |
| C4 | `:94-127` | `s0Screen(s1Machine:)` 构造点传 `flowModel: s0FlowModel` 与 `onEnterS2:` 闭包：`let virtualRangeID = S0CategoryPageRange.prefix + identifier.rawValue`；`guard let handoff = s1Machine.makeS2Handoff(virtualRangeID:displayName: S0CategoryText.displayName(for: identifier), orderedAssetIDs:currentAssetID:) else { return false }`；`return coordinator.enterS2(from: handoff)`。builder 文档注释末尾补三行。`body`（`case .s2:` 分支）与 `tabContainer` 的 `.onAppear` 一字不动 |
| C5 | 见第四节 | IC-156 断言 10 三处 |

## 四、既有断言改口径（裁定 六）

| 断言 | 文件:改后行 | 旧 | 新 | 同处注释 |
|---|---|---|---|---|
| IC-147 断言 10 | `IC147S0BehaviorTests.swift:798` | `s0Values.count, 37)` | `38)` | 同一行尾注 `// IC-157 B：长按提示一条，37 → 38。`（上方历史注释不动） |
| IC-147 断言 11 | `:847` | `catalogS0Keys.count, 37)` | `38)` | 同上，同一行尾注 |
| IC-148 断言 10 | `IC148S0VisualTests.swift:841` | `catalogS0Keys.count, 37)` | `38)` | 同上，同一行尾注 |
| IC-156 断言 6 | `IC156CategoryPageTests.swift:171`（原 `:170`） | `S0CategoryPageMetrics.` 57 | **59** | 上方注释原「按实装数写死（57）」会失真，改为两行「IC-156 为 57；IC-157 常驻行右侧提示与左文同一字号与明度，加两处 → 59」 |
| IC-156 断言 7 | `:216`（原 `:215`） | `s0.` 37 | **38** | — |
| IC-156 断言 7 | `:217`（原 `:216`） | `s0.categoryPage.` 5 | **6** | — |
| IC-156 断言 7 | `:219-226` 期望表、`:236` 注释 | 五条 | 加 `"s0.categoryPage.longPressHint": "长按任一格逐张看"`（无占位符，占位符循环按 0 处理） | `:236` 注释「页面只引用这五条…（`longPressHint` 归 IC-157）」→「这六条…（`longPressHint` IC-157 已登记）」 |
| IC-156 断言 10 | `:487`（原 `:484`） | 流程 `machine.ingest(` 2 | **3** | 上方注释补「从 S2 回到类别页一处（IC-157 裁定 一）」并折成两行 |
| IC-156 断言 10 | `:502`（原 `:499`） | App `S0CategoryPageRange.prefix` 1 | **2** | 同一行尾注 `// IC-157：进 S2 闭包一处` |
| IC-156 断言 10 | `:516-524`（原 `:512-518`） | 五实参 | 七实参：`machine:`、`dataProvider:`、`flowModel: S0CleanupFlowModel()`、`onSwitchToOrganizeTab:`、`onMoveToBasket:`、`onEnterS2: { _, _, _ in false }`、`toastDurationMilliseconds:` | 上方加一行注释「IC-157 C：加 `flowModel:` 与 `onEnterS2:`，顺序照其声明顺序（陷阱 16）」 |

其余既有断言**一条未改**。注释处理的取舍见 `self-check.md` 第 7.2 条。

## 五、新增测试（`IC157LongPressIntoS2Tests`，8 项）

文件内布局：B 段在类首（断言 4、5 + `numericLiterals`／`loadCatalogValues`），C 段紧接其后（断言 6、7、8 + `settledMachine`／`unwrapC`），A 段在类末尾（断言 1、2、3 + 夹具 `makeMachine(state:)`／`makeRange` + 源码扫描 helper）。

| 断言 | 函数名 | 子项 | 行 |
|---|---|---|---|
| 1 | `testIC157A_VirtualHandoffBuildsInAnyStateAndRegistersName` | A | `:392` |
| 2 | `testIC157A_VirtualRangeLiveMirrorAndReturnBypassRangeGates` | A | `:511` |
| 3 | `testIC157A_RealRangePathsByteIdentical` | A | `:612` |
| 4 | `testIC157B_LongPressGestureAndHintKeepDiscipline` | B | `:20` |
| 5 | `testIC157B_CatalogGainsLongPressHint` | B | `:81` |
| 6 | `testIC157C_FlowModelHoistedAndAppWiresEnterS2` | C | `:180` |
| 7 | `testIC157C_RoundTripThroughCoordinatorLandsMarksAndKeepsPageIdentity` | C | `:248` |
| 8 | `testIC157C_ReturnRecomputeIsGuardedByPresentedCategory` | C | `:335` |

## 六、pbxproj 登记

登记前重扫：文件引用最大 `10000000000000000000005E`、构建文件最大 `20000000000000000000005B`（与卡内事实一致）。

| 文件 | 文件引用 | 构建文件 | 组 | 构建阶段 | 提交 |
|---|---|---|---|---|---|
| `IC157LongPressIntoS2Tests.swift` | `10000000000000000000005F` | `20000000000000000000005C` | 测试组（`IC156CategoryPageTests.swift` 之后） | 测试 Sources（同上之后） | A |
| `S0CleanupFlowModel.swift` | `100000000000000000000060` | `20000000000000000000005D` | `S0` 组（`S0CleanupFlowView.swift` 之后） | App Sources（同上之后） | C |

撞号扫描：全文件 24 位对象 id 的定义行（`<id> /* … */ = {`）无重复；四个新 id 出现次数为 文件引用 3（定义、构建文件引用、组）、构建文件 2（定义、构建阶段）。

## 七、摘取关系（克隆仓库实测，见 `self-check.md` 第十节）

| 单元 | 结果 |
|---|---|
| A 单独（`e97f394` + `5517548`） | 无冲突 |
| A→B | 无冲突 |
| A→B→C | 无冲突，树与 `0a6c953` 相同 |
| 负对照：B 单独 | 冲突（`DU IC157LongPressIntoS2Tests.swift`；产品改动本身干净应用） |
| 附：C 直接接 A（跳过 B） | 冲突（`UU IC157LongPressIntoS2Tests.swift`）；卡未声称该单元可摘，C 在产品上也依赖 B 的页面新参数 |

## 八、占位值登记

本卡无出厂值变更、无新增登记常量、无新增 `factoryPlaceholder`：`schemaVersion` 7、`cacheSchemaVersion` 1、`S0HomeMetrics` 52、`S0CategoryPageMetrics` 42。新文案 key 一条（`s0.categoryPage.longPressHint`，取值为 SPEC-S0 v2 第 687 行原文），`s0.` 37 → 38。
