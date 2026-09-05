# IC-127 自验报告：S1 数据与行为层——**停卡回报（范围冲突）**，子项 E、F 已交付于分支、未推送

## 结论（先行）

**停卡回报。** 本卡 G501 把 diff 限定在 `Core/` 三个文件、`Features/S1/S1View.swift` 与 `PhotoCleanupMVETests/`，但子项 A、C、D 以及子项 B 的会话生命周期接线，都**必须**改动白名单之外的 `PhotoCleanupMVE/Services/PhotoLibraryService.swift` 与 `PhotoCleanupMVE/App/CleanupCoordinator.swift`（逐行清单见下）。在白名单内无法让工程编译通过，更谈不上 G503。按 CLAUDE.md 第一节「任务卡没写的事情不要做」、第三节「修改范围外文件默认禁止」与第七节「确有冲突则停下报告」，**未触碰白名单外任何文件，未硬套**。

已完成并各自独立提交在 `feature/ic-127-s1-behavior`（自 `main` `da44e59` 切出）的部分：

| 子项 | 提交 | 状态 |
|---|---|---|
| E · 提交排序（未定项 8） | `de1831c` | 代码 + 2 条新断言 + 1 处既有期望值更新；本地门禁全过；**未推送、未跑 CI** |
| F · 清理过期占位登记（漂移 B） | `df53edf` | 删除 11 个登记项；本地门禁全过；**未推送、未跑 CI** |
| A · 两级树 | — | **未开工**（见冲突清单 1） |
| B · 跨启动持久化 | — | **未开工**（见冲突清单 4；档的 Core 部分可做，但恢复入口、`sessionID` 结束清档两处接线在 coordinator） |
| C · 外部变更对账 | — | **未开工**（对账函数可落 Core，但两处调用点在 coordinator，见冲突清单 3） |
| D · 授权分派与失败分类 | — | **未开工**（受限授权「按已授权处理」须改 `PhotoLibraryService.s1AuthorizationFailure`，见冲突清单 2） |

未推送的理由：CI 预算 3 次是给「六个子项一起验」的；只推 E、F 会白耗一次且不能满足 G503。E、F 的 Swift 编译正确性因此**尚未由 CI 验证**（本机无 Swift 编译器），如实标注。

CI 未跑，G501～G505 均未判定。`main` 未动；工作树除本报告外干净。

## 基线与前置（①）

- `git status --porcelain` 开工时为空；`git log --oneline -1 main` = `da44e59 docs: IC-126 自验与变更清单（iOS 26.2 / iPhone 16 主跑 #243 绿，合并入 main，#244 绿，593 项 0 失败）`，与卡内逐字一致；`git fetch` 后 `origin/main` 同值。
- `grep -c "^## 140 ·" Decision_log.md` = **1**，第 140 条在档，已通读。
- 分支 `feature/ic-127-s1-behavior` 已自 `main` 切出（本地）。

## 范围冲突清单（①，逐行）

白名单 = `Core/S1StateMachine.swift`、`Core/SessionStore.swift`、`Core/SessionPersistence.swift`、`Features/S1/S1View.swift`、`PhotoCleanupMVETests/`。以下每一条都是**不改就编译不过或子项无法成立**的白名单外改动：

1. **子项 A（枚举回到三类）** —— `S1GroupingDimension` 删去 `.month`／`.year` 后：
   - `Services/PhotoLibraryService.swift:128-148`、`:161-183`：两处 `switch groupingDimension` 含 `case .month:` / `case .year:`，穷举失败即编译错误；且两级树的 `R(T)` 生成（年节点 + 月节点、父子关系）本就应在此处形成——`s1Ranges(groupedBy:)` 是 `R(T)` 的唯一产地。
   - `Services/PhotoLibraryService.swift:441`、`:460`：`groupingDimension == .month ? … : …`。
   - `App/CleanupCoordinator.swift:23`：`initialGroupingDimension: .month`（路由夹具）。
   - 白名单外测试无；`PhotoCleanupMVETests/AlbumScopeWiringTests.swift:160-161` 调 `.s1Ranges(groupedBy: .month/.year)`（在白名单内，可改）。
2. **子项 D（受限授权按已授权处理、不落失败态）** —— 现行 `Services/PhotoLibraryService.swift:191-224` `s1AuthorizationFailure(for:)` 把 `.limited` 映射为失败 `.limitedAuthorizationPolicyUndecided`，`s1Ranges` 一进门就 `return .failure(...)`。「受限进 S1-2 并暴露受限标志」必须改这里（读取继续、另带标志）。分派与分类的**纯映射**（五种授权原因 → 请求授权／授权类失败／读取类失败／受限继续）可以落在 Core，但没有 Services 的配合，「受限授权进 S1-2 而非 S1-4」这条必须新增的断言无法成立。
3. **子项 C（对账单一入口的两处调用点）** —— 「进入 S1 时」= `App/CleanupCoordinator.swift:107-116` `enterS1(sessionID:)` / `:730-757` `installS1Session`；「从 S2 返回时」= `:774-793` `applyS2ExitPayload`。对账函数本体可以放进 `S1StateMachine`，但两处调用不接线，「恢复路径调用了对账入口」「进入 S1／返回时各调用一次」都只能是死代码上的断言。S1View 的 `onAppear` 只能覆盖首次读取，覆盖不了「从 S2 返回」（返回后 S1 不重新进入 loading，IC046-017 钉死 `state == .ready`）。
4. **子项 B（`sessionID` 生命周期与恢复入口）** —— 新会话在 `App/CleanupCoordinator.swift:994-1002`（S4／S5 结束后 `installS1Session(SessionStore(sessionID: nextSessionID))`）与 `:727` 处创建；「S4 完成或 S5 离开后结束并清档」「重启后恢复 `M`／`K`／`F`／`T`／`O`」的接线都在这里，`routeConfiguration.initialGroupingDimension` 也在这里读。档的读写（`SessionPersistence` 新档）与 `SessionStore` 的可编解码形态在白名单内可做，但整条「写入—重启—恢复」链路不经 coordinator 无法闭环；`FullFlowRoutingTests` 里现有的重启恢复测试（`IsolatedFileManager` + `CleanupCoordinator(persistence:)`）也都是从 coordinator 入口驱动的。

**建议的最小授权扩展**（供决策会话裁定，非本会话决定）：`Services/PhotoLibraryService.swift` 限 `s1Ranges` 族、`s1AuthorizationFailure`、`chronologicalRanges` / `chronologicalRangeID` / `chronologicalDisplayName`；`App/CleanupCoordinator.swift` 限 `CleanupRouteConfiguration` 默认值、`enterS1` / `installS1Session`、`applyS2ExitPayload`、S4／S5 结束处的新会话创建；其余（S2 相关、`S2CalibrationConfiguration`、`schemaVersion`）维持零改动。

## 子项 E · 提交排序（commit `de1831c`，已落地）

依据未定项 8 定案：`makeS3Submission` 的顺序 = 分组按范围在 `R(T)` 中的顺序、组内按当前 `O`。

- `SessionStore` 新增重载 `makeS3Submission(rangeOrder:orderedAssetIDsForRangeID:groupNameForRangeID:)`：分组按 `rangeOrder` 排位；组内按传入的 `A(r, O)` 过滤出待删成员；总表 = 各组顺序拼接。两条**稳定回退**：不在 `rangeOrder` 中的范围（例如在另一维度下标记、当前 `R(T)` 不含）按范围标识升序排在其后；`A` 未覆盖的成员按标识升序补在该组末尾。回退只保证顺序稳定可重算，不改变「各组之和 = `D_全部`」。
- 既有 `makeS3Submission(groupNameForRangeID:)`（字典序）**原样保留**，`SessionStoreTests` IC043-013 等既有断言不动。
- `S1StateMachine.makeS3Submission()` 改走新重载：`rangeOrder = visibleRanges.map(\.id)`（含 `O` 对日期维度的翻转），组内取 `range.orderedAssetIDs(for: sortOrder)`。
- 既有期望值更新 1 处：`FullFlowRoutingTests.assertS3Contract` 的 S3 资产顺序由字典序 `[资产-A, 资产-B, 资产-S]` 改为 `R(T) × O` 的 `[资产-S, 资产-A, 资产-B]`，范围-1 组由 `[资产-A, 资产-S]` 改为 `[资产-S, 资产-A]`（该夹具 `范围-1` 的 `A` 为 `["资产-S", "资产-A"]`，新到旧）。这是未定项 8 定案带来的预期变化，非回归。

| 必须新增的断言 | 测试函数 | 状态 |
|---|---|---|
| 多范围提交时顺序与 `R(T) × O` 一致（含 `O` 翻转后年序／组内序同时翻转） | `testIC127E_SubmissionFollowsRangeOrderInRTAndCurrentSortOrder`（`S1StateMachineTests`） | 已写，CI 未跑 |
| 各分组资产数之和 = `D_全部` 元素数（含跨范围重复标记 + 不在当前 `R(T)` 的范围回退） | `testIC127E_GroupCountsStillSumToMergedDeletionCount`（`S1StateMachineTests`） | 已写，CI 未跑 |

注：A 的两级树落地后，`visibleRanges` 的扁平化顺序（年、其下月……）即为 `R(T)` 顺序，E 不需再改。

## 子项 F · 清理过期占位登记（commit `df53edf`，已落地）

`S1UndecidedItems` 删除 `item01`、`item02`、`item03`、`item04`、`item08`、`item09`、`item11`、`item13`、`item14`、`item14b`、`item14c` 共 11 项；保留 `item05`、`item06`、`item07`、`item10`、`item12`、`item15`（留 IC-128）与 `item16`、`item17`（v1 候补）。产品与测试代码对被删项**零引用**（`grep` 实测）；仅 `Scripts/verify-IC-20260814-046.ps1`（IC-046 时期的一次性核验脚本，不在 CI 与 `selfcheck.ps1` 调用链内）仍列有 `item14b`／`item14c` 常量名，属白名单外历史脚本，未动，登记在「发现但未处理」。

## 本地门禁（①，E、F 落地后）

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0（用户可见硬编码残留 0，目录 key 与源码引用一致） |
| `git diff --check` | 0 |

本机无 Swift 编译器，E、F 的编译与测试结果**未覆盖**（未推送取 CI，理由见结论）。

## CI

未运行。预算 3/3 未动用。

## 闸门

- G501：截至目前 diff 仅 `Core/S1StateMachine.swift`、`Core/SessionStore.swift`、`PhotoCleanupMVETests/S1StateMachineTests.swift`、`PhotoCleanupMVETests/FullFlowRoutingTests.swift`——在白名单内；S2 相关代码、`S2CalibrationConfiguration`、`schemaVersion`（7）零改动。
- G502：冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` 未触碰。
- G503～G505：未判定（停卡）。

## 持久化档形态 / 展开收起入档

未实施（子项 B 未开工），无结论。

## 人工判定项

无。

## 发现但未处理（只报告不修）

1. **范围冲突**（本报告主体）：卡内 G501 白名单与子项 A、B、C、D 的实际落点不相容；已列逐行清单与最小授权建议。
2. `Scripts/verify-IC-20260814-046.ps1:94-95` 仍引用已删登记项 `item14bS3GroupOrderingAndPaging`、`item14cEmptyS3GroupPresentation`（该脚本按「常量 = unresolved」计数，若再被执行会报不一致）。历史一次性脚本、不在 CI 链内、在白名单外，未动。
3. 子项 E 的两条回退（范围不在当前 `R(T)`、资产不在 `A`）是实现为保证「顺序稳定可重算 + 计数守恒」自加的边界处理，未定项 8 定案文字未涉及；语义上不改变定案，但请决策会话知悉。
4. 仓库存在两条 IC-067 时期的 stash（`stash@{0}`、`stash@{1}`），非本卡产生，未触碰。

## 报告提交

本报告与 `change-list.md` 以 docs 提交追加在 `feature/ic-127-s1-behavior` 分支 E、F 提交之后（本地，未推送）。待决策会话裁定授权范围后，同分支续作 A～D，或按新卡重来。
