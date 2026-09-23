# IC-164 变更清单（把 IC-163 的子项 A、D 原样摘回 `main`，两次 `cherry-pick -x`，零手写改动）

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260922-164-pick-ic163-a-d-into-main.md` |
| 基线 `main` | `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a`（IC-160 报告补记；`dff2e79…` 是其祖先，`is-ancestor` 退出码 0） |
| 分支 | `feature/ic-164-pick-ic163-a-d`，自该 `main` 切出 |
| 子项 A 摘取提交 | `b905155e1d569af2330e2c0f2d43a08c39f15888`（源 `105ada3f4acc9b5ad5ae9efb6cfb22b503ee1f0e`），提交信息末行 `(cherry picked from commit 105ada3f4acc9b5ad5ae9efb6cfb22b503ee1f0e)` |
| 子项 D 摘取提交 | `cc85fa4a7cfa272092a3acfade432d13de7e4e0b`（源 `088e4b1deb7b38bd7fb333d149d9561a9b23a171`），提交信息末行 `(cherry picked from commit 088e4b1deb7b38bd7fb333d149d9561a9b23a171)` |
| 合并提交 | `243e3ad666bea8471ddb6c032e188dc34cc9c374` `merge(IC-164): 摘回 IC-163 子项 A（S2 写回不抹类别篮）与 D（「视频」类取代「大视频」）`（`--no-ff`） |
| 报告 | 本文件与 `self-check.md`，**恰一个 docs 提交，合并与合并后 `main` 运行之后直接落在 `main` 上**（见 `self-check.md` 第一节「报告提交方式」） |
| 手写改动 | **零**。两个提交都是 `git cherry-pick -x` 的产物，退出码 0、无冲突 |
| 项数 | 856 + 3 = **859**（D 只改期望值，不加不减用例） |
| 摘取关系 | A、D 各自独立、互不依赖；本卡按 A → D 落 |

## 二、文件清单（`git diff --numstat 091b60e cc85fa4`）

| 文件 | 增／删 | 随哪个提交 |
|---|---|---|
| `PhotoCleanupMVE/Core/SessionStore.swift` | +3／−1 | A |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | +9／−4 | A |
| `PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift`（新，250 行） | +250／−0 | A |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4／−0 | A |
| `PhotoCleanupMVE/Services/S0ScanRules.swift` | +1／−6 | D |
| `PhotoCleanupMVE/Services/S0ScanClassifier.swift` | +2／−2 | D |
| `PhotoCleanupMVE/Localizable.xcstrings` | +1／−1 | D |
| `PhotoCleanupMVETests/IC153ScanServiceTests.swift` | +32／−34 | D |
| `PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift` | +10／−9 | D |

合计 **9 个路径**（A 4 + D 5），+312／−57，与白名单逐条对应。

## 三、逐项变更（内容与源提交逐字相同，这里只复述）

### 子项 A · S2 写回不抹类别篮（源 `105ada3`，IC-163 裁定 一）

- `SessionStore.applyS2Return`：该范围集合由「整个覆盖为返回集」改为「写回前集合 − 交接列表 ∪ 返回集」（先取 `previous`，`assetIDSet` 用 guard 上方既有的那个）。
- `S1StateMachine.applyPendingDeletionDiff`：加形参 `scope: Set<String>`，取消循环只对 `previous.intersection(scope).subtracting(new)`；两处调用各加实参 `scope: Set(entryContext.orderedAssetIDs)`。真实范围的交接列表恒为整个范围，行为逐位不变。
- 新测试文件三条：`testIC163A_RealRangeReturnUnchanged`、`testIC163A_VirtualRangeReturnKeepsBasketOutsideHandoff`、`testIC163A_VirtualRangeUnmarkInsideHandoffStillWorks`；只 import `Foundation`／`XCTest`／`@testable PhotoCleanupMVE`，不引用任何 `S0Deck*` 符号。**这是 A 版本（250 行）第一次单独编译**，#328 编过且三条全过。
- pbxproj 四行（见第四节）。

### 子项 D · 「视频」类取代「大视频」（源 `088e4b1`，IC-163 裁定 五）

- `S0ScanRules` 删 `bigVideoMinimumByteCount` 登记与注释，类型文档「恰七个常量」→「恰六个」。
- `S0ScanClassifier.hits` 视频段改 `if 录屏证据命中 { .screenRecording } else { .bigVideo }`；`attributionPriority` 不动；未解析仍归空集。
- 目录 `s0.category.bigVideo` 的值 `大视频` → `视频`（key、枚举 case、`cat:bigVideo` 不改名）。
- `IC153ScanServiceTests`／`IC155CategoryDataAndCoverTests` 只改期望值、字面量与注释，`func test` 13／9 不变；旧→新逐行表见探针分支 `git show 562f8b7:Reports/IC-163/change-list.md` 第四节（本卡未改一字，故不重抄）。

## 四、`project.pbxproj`

| 项 | 值 |
|---|---|
| 摘入的四行 | `200000000000000000000065 /* IC163DeckPreviewRoundTwoTests.swift（测试源码） */ = {isa = PBXBuildFile; fileRef = 100000000000000000000068 …}`；`100000000000000000000068 /* IC163DeckPreviewRoundTwoTests.swift */ = {isa = PBXFileReference; …}`；tests 组 `100000000000000000000068 …,`；tests Sources `200000000000000000000065 …,` |
| 与源提交的四行 | `git diff main cc85fa4 -- project.pbxproj` 的 `+` 行与 `git show 105ada3 -- project.pbxproj` 的 `+` 行**逐字相同**（`diff` 空） |
| 出现次数 | `…68` 3 处、`…65` 2 处；按行计 4 |
| 定义行 | 两 id 各恰 1 条 `= {isa =`；全表 189 条定义行、同 id 重复定义 0 |
| 最大号 | 摘后 fileRef `…68`、buildFile `…65`；`…62`～`…67`／`…5F`～`…64` 空洞是探针分支上 IC-162 的登记号，按裁定 一不重编 |

## 五、目录

`Localizable.xcstrings` 相对 `main` 恰 +1／−1（`s0.category.bigVideo` 的值，U+89C6 U+9891 = `视频`）；条目 253 不变；`s0.` 38、`deck.` 0。

## 六、占位值登记

**本卡无出厂值变更**，`S2CalibrationConfiguration.schemaVersion` 仍 **7**；扫描缓存 `S0ScanRules.cacheSchemaVersion` 仍 **1**（缓存只存原始证据，分类读缓存时现算）；**目录只改一个值、不改 key**。无新登记值。

## 七、规格口径声明（裁定 二）

SPEC-S0 v2 第二节第 2 部分仍写「大视频 ≥ 100 MB」（第 180 条 ④ 默认值）。本卡 D **实装先于规格**，依据 Decision_log 第 187 条 ④（Lynn 2026-09-19 取消 100 MB 门槛、类目改「视频」）、第 189 条裁定 五（「视频」类 = 全部已解析视频、录屏互斥）、第 190 条（A、D 可原样摘回 `main`）；规格随 SPEC-S0 v3 补写。这不是未定项。
