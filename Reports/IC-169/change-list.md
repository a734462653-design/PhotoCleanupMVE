# IC-169 变更清单

## 一、概要

- 任务卡：`<top>/Tasks/IC-20260924-169-marked-state-follows-basket.md`
- 基线 `main`：`f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830`
- 分支：`feature/ic-169-marked-state-follows-basket`（tip `bf9551eb4b45633ca78ab124360e959e6cbb49a2`）
- 合并提交：`3cad2e2e47d1a13249f5370a0e47f283b9967c69`（`--no-ff`，已推送）
- CI：#355 绿 899／0（`71d03fa00efb88d2d62ab6c128b2a2933d5a9c3b`）；#356 绿 905／0（`bf9551eb4b45633ca78ab124360e959e6cbb49a2`）；合并后 `main` #357 绿 905／0（`3cad2e2e47d1a13249f5370a0e47f283b9967c69`）
- 报告落点：合并与 #357 之后在 `main` 上追加恰一个 docs 提交（惯例 44）

## 二、逐提交变更

### A `50ae2dbe6a6cf80929b6aa55f3f727034ba21d81` — 交接初值（裁定 一）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `makeS2Handoff(for:)` 声明行上方加两行文档注释；真实范围初值 `sessionStore.pendingDeletionAssetIDsByRangeID[range.id] ?? []` → `sessionStore.allPendingDeletionAssetIDs.intersection(assetIDSet)`（函数体仍 35 行，子集守卫保留）；虚拟范围文档注释「`M[virtualRangeID]` 与列表的交集」→「合并待删集合与列表的交集（IC-169，决策 42／63）」；虚拟范围初值三行 → 同样两行 |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | `S1DateTreeTests.testIC127A_YearAndMonthNodesEachFormValidS2Handoff`：两行注释改写；月范围交接 `D` 期望 `[]` → `Set(["a3a"])` |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | `realHandoffBodyLines` 第 11 个元素换成新初值行；其文档注释末尾加「IC-169 只换了 `D` 初值一行」 |

### B `99b39f25cebf14582aa2ed6dad1c828a83fd1b2d` — 逐张镜像（裁定 二、三）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `applyPendingDeletionDiff` 函数体：基准由 `M[r]` 改为此刻的 `nextStore.allPendingDeletionAssetIDs`（每次现取）；撤标对 `basket ∩ scope − D` 逐个资产、对含它的每个范围（键升序）`setMarked(false…)`；加标对 `D − basket` 只写本范围；仍在副本 `nextStore` 上改完、一次赋值 `sessionStore`。`setMarked(` 文本仍 3 处 |
| `PhotoCleanupMVETests/IC129ExistenceReconciliationTests.swift` | `testIC129B_…`：加一行注释；`M["相册-1"]` 期望 `["资产-1"]` → `?? []` 与 `[]` |

### C `77cd14b65aa81a41a06a341553ac6019424ca3ee` — 返回写回（裁定 二、三）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/SessionStore.swift` | `applyS2Return`：IC-163 A 单范围公式 `M[r] := (M[r] − A) ∪ D` 换成逐资产两条规则——`basket = Self.allPendingDeletionAssetIDs(in: nextState)`；`unmarked = A − D` 从全部范围 `subtract`；本范围 `[r, default: []].formUnion(D − basket)`。其后 `F` 过滤、「每个剩余资产都已有 `F`」守卫与续接写入一字未动；写回不补写 `F` |

### D `71d03fa00efb88d2d62ab6c128b2a2933d5a9c3b` — 范围角标（裁定 四）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `rangeRows` 上方加两行文档注释；`let basket = sessionStore.allPendingDeletionAssetIDs` 在 `map` 外取一次；`pendingDeletionCount:` 由 `sessionStore.pendingDeletionCount(for: range.id)` 改为 `basket.intersection(range.assetIDsNewestFirst).count`；`processedAssetCount:` 起一字未动 |

### E `bf9551eb4b45633ca78ab124360e959e6cbb49a2` — 新断言

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/IC169MarkedStateFollowsBasketTests.swift`（新建） | 逐字节拷自 `<top>/Tasks/decision-tools/`，blob `fc353710400e256b57f0d3ea81667c267cb30174`；六条测试 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记一个测试文件四行：PBXBuildFile `200000000000000000000073`、PBXFileReference `100000000000000000000076`、测试组子项、测试目标 Sources 构建阶段项 |

### merge `3cad2e2e47d1a13249f5370a0e47f283b9967c69`

父 `f4db22b0a6d1473d8fe1cbbd69d6936d80e5f830` 与 `bf9551eb4b45633ca78ab124360e959e6cbb49a2`；树 `df294efcd4a8c00f1a32bd3b4d6241eebb8c81c7` 与 E 的树相同。

## 三、路径汇总（`git diff --name-only f4db22b..bf9551e`，恰 7 个）

| 路径 | 类别 | 子项 |
|---|---|---|
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | 产品 | A、B、D |
| `PhotoCleanupMVE/Core/SessionStore.swift` | 产品 | C |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 工程 | E |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | 测试 | A |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | 测试 | A |
| `PhotoCleanupMVETests/IC129ExistenceReconciliationTests.swift` | 测试 | B |
| `PhotoCleanupMVETests/IC169MarkedStateFollowsBasketTests.swift` | 测试（新建） | E |

docs 提交另加 `Reports/IC-169/self-check.md`、`Reports/IC-169/change-list.md`。

## 四、占位值登记

无。`S2CalibrationConfiguration.schemaVersion` 仍 **7**（未增删标定字段、未改出厂值）；会话档格式不变；文案目录仍 259；不新增文案 key。

## 五、未改动（对象与基线相同）

`App/`、`Services/`、`Features/`（含 `S1View.swift`、全部 S0、S2）、`Core/` 除两个白名单文件外全部（含 `S2StateMachine.swift`、`SessionPersistence.swift`）、`Localizable.xcstrings`、`.github/`、`Scripts/`、其余 49 个既有测试文件。`SessionStore.pendingDeletionCount(for:)` 与 `markPendingDeletion` 未动。

## 六、项数

899（基线）→ 899（A～D）→ 905（E，+6）。
