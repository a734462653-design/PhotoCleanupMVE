# IC-166 变更清单

> 任务卡：`<top>/Tasks/IC-20260923-166-rest-category-and-lib.md`。本清单与 `self-check.md` 同在合并后 `main` 上的恰一个 docs 提交里（惯例 44）。

## 一、分支、提交与合并

| 项 | 值 |
|---|---|
| 基线 | `main` = `6bc51bed5cd5997323ad52261aedcf21123b4b6a` |
| 分支 | `feature/ic-166-rest-category-and-lib`（自基线切出，已推送，保留不删） |
| 子项 A | `dc74fe5633bc763f535ef9e2b9073c0dacce0749` `feat(IC-166): 子项 A 数据层——…`（8 个文件） |
| 子项 B | `83dd99b5a2881e79cac91060cda209f2b222ff65` `feat(IC-166): 子项 B 卡片叠层——…`（12 个文件，其中 `S0DeckMetrics.swift` 与 A 共用） |
| 子项 C | `2734ccd0ef2f12fa4ce115f0136777321a96c548` `test(IC-166): 子项 C 新断言六条——…`（2 个文件） |
| 合并 | `a6018ad990c80fe01445ffdfa4ed890735eb9589` `merge(IC-166): 「其余照片」升为可进入类别、LIB 排除待删篮与账本、S0-3 判据改无成员（SPEC-S0 v3）`，`--no-ff`，父 `6bc51be` + `2734ccd`，树 `615e6da745a429f1e4b3fd79f07b8ce0a13c275f`（= C 的树） |
| 报告 | 本 docs 提交（合并后 `main` 运行 #336（run 35856602067） 之后，直接落在 `main` 上） |

`git diff --stat 6bc51be 2734ccd`：21 个文件，+1007／−216，恰为卡面白名单 21 个路径。

## 二、子项 A · 数据层（裁定 一、二、三的数据部分）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Core/S0StateMachine.swift` | `S0CategoryIdentifier` 末尾加 `case rest`（带一行文档）；`reorderCategories()` 比较器首键「`.rest` 恒排末」、方法文档补一句；`S0CategorySnapshot` 头文档与 `cleanableAssetCount`／`cleanableByteCount` 文档改 v3 口径（`N_成员`、`= LIB`）。字段名、判据式、其余代码不动 |
| `PhotoCleanupMVE/Services/S0ScanClassifier.swift` | 新增 `snapshotOrder`（= `attributionPriority + [.rest]`）与 `attributedCategory(for:)`（= `primaryCategory ?? .rest`）；`attributionPriority` 声明不动，其文档把「快照给出顺序」一句改指 `snapshotOrder`；聚合器：`LIB` 移到排除判定之后、守卫只留排除集、按归属类别只累加一次、`categories` 按 `snapshotOrder`；聚合器文档改 v3 口径 |
| `PhotoCleanupMVE/Services/S0LibraryScanService.swift` | 仅 `categoryAssets(_:)` 守卫两句合并为 `attributedCategory(for: asset.hits) == id`（+1／−2） |
| `PhotoCleanupMVE/Services/S0CleanupDataStub.swift` | 扫描剧本加 `rest` 行（`.counting`，每步 250 项、10.18 GB）；就绪剧本加 `rest` 行（`.settled`，有项目 731 项、38.84 GB，无项目 0）；两剧本 `cleanableAssetCount`／`cleanableByteCount`／`libraryTotalByteCount` 改取全部类别之和（新增私有 `memberCount(of:)`、`byteCount(of:)`）；两剧本文档补口径 |
| `PhotoCleanupMVE/Features/S0/S0Text.swift` | `displayName(for:)` 加 `case .rest: return L10n.text("s0.category.rest")` |
| `PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift` | `categoryColor(for:)` 加 `case .rest: return colorRest` |
| `PhotoCleanupMVETests/IC153ScanServiceTests.swift` | 只改期望值、字面量与注释：断言 2 期望类别四条、成员 3、hero 157 MB、`LIB` 157 MB（加 `categorySum == libraryTotalByteCount` 一行）、unfiltered `[1,1,2,1]`／5／359 MB／四个 `.settled`／ids + `.rest`；断言 7 前置四个真；**断言 8 两处识别阶段数组三条 → 四条（卡面漏列）**；断言 13 桩就绪 5 → 6。`func test` 13 不变 |
| `PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift` | 只改期望值、字面量与注释：断言 1 ids + `.rest`（加 `rest` 封面 `"plain-photo"` 一行）、`empty` 3 → 4；断言 2 封面序列 + `"plain-photo"`；断言 3 `readyEmpty` 5 → 6；断言 4 ids + `.rest`、`expectedOrders` 加 `.rest: ["photo-plain"]`；断言 6 `nonEmptyListCount` 37 → 46；helper 3 → 4。`func test` 8 不变 |

## 三、子项 B · 卡片叠层（裁定 三副句、四、五）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift` | 删 `restCardID` 与其文档；`Card.category` 改非可选、文档改写；`cards(categories:libraryTotalByteCount:)` 去 `restByteCount` 形参、追加分支与相关文档句 |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | S0-3 `centeredBlock` 传 `subtitle`（新 key，取 `machine.snapshot.progress.scannedAssetCount`）；`centeredBlock` 加 `subtitle: String? = nil` 形参与条件渲染（借 `pendingRowFontSize`／`pendingRowOpacity`）；两处 `cardColor` → `categoryColor`；删 `restByteCount` 计算属性与调用实参；`coverAssetID`／`candidateCount`／`handleTap`／`name(for:)` 去可选拆包；`cardID(for:)` 的 `.rest` 返回 nil；收起条右箭头旁的旧注释改写 |
| `PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift` | 删 `static func cardColor(for:)` 与其文档（`static let` 仍 198） |
| `PhotoCleanupMVE/Features/S0/S0SegmentBarModel.swift` | `make` 改 v3 张数进度缩放：段宽 `c.bytes / LIB × p`、未扫 `1 − p`；删预算夹断、填充段、`restByteCount`；`Kind.rest` 文档改「`LIB ≤ 0` 兜底段」；`totalWidthFraction` 与 `make` 文档改写 |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | 仅 `sharePercentText` 删 `restByteCount: 0,` 一行（`:909`） |
| `PhotoCleanupMVE/Localizable.xcstrings` | 新增 `s0.home.hero.empty.subtitle`（zh-Hans「已扫描 {count} 项」，11 行外科插入） |
| `PhotoCleanupMVETests/IC162DeckPreviewTests.swift` | 新夹具 `fixtureCategoriesWithRest`；A1／A2／`noneEnterable` 三条改期望；去全部 `restByteCount:` 与 `category == nil`。函数名不改 |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | 断言 8 (a) `LIB` → 0、(c) 加 `rest` 行并改期望为 `share × 0.3`、(e) 改缩放用例；`:520` 39 → 40 |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | 仅 `:816`、`:864` 39 → 40（前者上方加一行注释，后者原注释补一句） |
| `PhotoCleanupMVETests/IC156CategoryPageTests.swift` | 仅 `:235` 39 → 40（注释补一句） |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | 仅 `:64` 39 → 40 与四条 needle `39)` → `40)`（注释补一句） |
| `PhotoCleanupMVETests/IC165DeckFormalTests.swift` | 仅 `:223` 39 → 40（加一行注释） |

## 四、子项 C · 新断言

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVETests/IC166RestCategoryTests.swift`（新建） | 六个 `func test`：`testIC166A_LibraryExcludesPendingAndLedgerAndSumsToCategories`、`testIC166A_RestIsAttributionOfNoHitAndCategoriesArePairwiseDisjoint`、`testIC166A_RestCoverIsLargestAndRestSinksToBottom`、`testIC166A_EmptyStateFollowsMemberCount`、`testIC166B_DeckCardsTreatRestAsOrdinaryCategory`、`testIC166B_SourceDiscipline`；源码扫描 helper 口径同 IC-165；git blob 标识用 CryptoKit `Insecure.SHA1` 求 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记一个测试文件：fileRef `10000000000000000000006F`、buildFile `20000000000000000000006C`（+4 行，文件引用／构建文件／测试组／Sources 阶段各一） |

## 五、占位值与登记

| 项 | 值 |
|---|---|
| `S2CalibrationConfiguration.schemaVersion` | **7，未变**（本卡无出厂值变更） |
| `S0ScanRules.cacheSchemaVersion` | **1，未变**（缓存只存元数据与证据，读时重算归属） |
| `S0DeckMetrics` 登记值 | 198，未变（副句借 `pendingRowFontSize`／`pendingRowOpacity`） |
| `S0DeckSymbol` | 8，未变 |
| String Catalog | 254 → **255**；`s0.` 39 → **40**；`s0.categoryPage.` 9 不变；新增 key `s0.home.hero.empty.subtitle` = `已扫描 {count} 项`（**SPEC-S0 v3 第十四节第 3 部分未登记，v3 欠账**） |
| `S0CategoryIdentifier` | 五 case → 六 case（末尾 `rest`） |
| 快照 `categories` | 真实服务 3 → 4 条（`snapshotOrder`）；桩 5 → 6 条 |

## 六、项数

865 →（A）865 →（B）865 →（C）**871**。CI：#334 865／0、#335 871／0、合并后 #336（run 35856602067） 871／0。

## 七、摘取关系（惯例 40，克隆实测）

- A 单独：无冲突，结果树 = 分支 A 的树 `1b92272f0417962cb5b95e89ed0bc8292ad0b933`；#334 实证可编译、全绿。
- A → B：无冲突，结果树 = 分支 B 的树 `47248b2fc561a9a79208ed12c15fc17e7915470d`。
- A → B → C：无冲突，结果树 = `615e6da745a429f1e4b3fd79f07b8ce0a13c275f`（= 合并树）。
- B 单独、C 单独、A → C：文本无冲突但不可编译（B 的测试依赖 A 的 `.rest`；C 依赖 A 的 `attributedCategory`／`snapshotOrder` 与 B 的两参 `cards`）。可摘单元 = A（只作证据）、A → B、A → B → C。

## 八、未改动（「不得打红」）

`App/`、`Core/` 除 `S0StateMachine.swift`、`Services/` 除三份、`Features/S0/` 的 `S0CleanupFlowView`／`S0CleanupDataProviding`／`S0CategoryPageSelection`／`S0DeckZoomTransition`／`S0TabContainer`、`Features/Shared/`、`Features/S1`～`S5`、`.github/`、`Scripts/`、九份以外的全部测试文件：与 `6bc51be` 对象相同（`self-check.md` 第十一节）。SPEC 与 Decision_log 未触碰。
