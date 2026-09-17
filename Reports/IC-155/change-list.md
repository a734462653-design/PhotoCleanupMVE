# IC-155 变更清单

- 任务卡：`<top>/Tasks/IC-20260916-155-category-data-and-cover.md`
- 分支：`feature/ic-155-category-data-and-cover`
- 基线：`main` = `51b4b9564bc5e7f0bb371bda5c2946b7efd6283f`（IC-154 报告回填；IC-154 合并提交 `20a19df6827f98f42e62911cdadd714dd33d2f0f`）
- 分支 tip（代码）：`4e3e6c8b22f2321cd43cc425df139756d63fe3b7`（CI #311 被测提交，一次绿 833 项 0 失败）
- 分支 tip（含报告）：报告提交（报告提交自身的 SHA 无法写进自身）
- 合并提交：合并后回填
- 提交数：3 个代码提交（子项 A／B／C 各一）+ 1 个报告提交
- `S2CalibrationConfiguration.schemaVersion`：**7，未动**；`S0ScanRules.cacheSchemaVersion`：**1，未动**

---

## 一、提交清单

| # | SHA | 子项 | 标题 |
|---|---|---|---|
| 1 | `966149402b0bb422eee72cba1a8c91bcb1da5eab` | A | coverAssetID 进模型、S0CategoryAsset 进 Core、聚合器产出封面 |
| 2 | `115263a33e232408b8c6b46034122d81b239009e` | B | 数据源协议加 categoryAssets(_:)，服务与桩各自实现 |
| 3 | `4e3e6c8b22f2321cd43cc425df139756d63fe3b7` | C | 首页类别行接真封面（ThumbnailView 加 showsPlaceholderGlyph） |
| 4 | 报告提交 | — | docs：自验报告与变更清单（#311 一次绿 833 项 0 失败） |

**可摘取单元（惯例 40，①实测）**：在草稿区另克隆一份仓库（`core.autocrlf=false`），从 `51b4b95` 分离检出后逐个 `cherry-pick`：

| 摘取 | 结果 | 叠完的树对象 |
|---|---|---|
| A 单独 | 无冲突，改 7 个路径 | `119a340536924894c39ce3c30e650ae74f0e16d0` = 提交 `9661494` 自身的树 |
| A→B | 无冲突，改 9 个路径 | `7048b3d026b72d36922d92bacc5ab2505637a0ed` = 提交 `115263a` 自身的树 |
| A→C | 无冲突，改 10 个路径 | `e516a993cf549fbfeca742555113f8689bdb2552`（与主仓库 `git merge-tree --write-tree --merge-base=115263a 9661494 4e3e6c8` 的输出同一对象） |
| A→B→C | 无冲突 | `83365e5f82b59998e961fd251a997b1b569f6b7e` = 分支 tip `4e3e6c8` 的树 |
| A→C→B | 无冲突 | `83365e5f82b59998e961fd251a997b1b569f6b7e`（同上） |
| B 单独、C 单独 | **冲突** | 预期内：两者都往 A 新建的测试文件里追加 |

卡内声明的四个可摘取单元（A 单独、A→B、A→C、A→B→C）全部成立。为让 A→C 不经 B，**子项 C 的两条断言放在测试类的最前面**（B 追加在断言 3 之后与文件末尾，C 若也追加在那附近，三方合并会判冲突）。

---

## 二、文件变更全量（`git diff --name-status 51b4b95..4e3e6c8`）

```
M	PhotoCleanupMVE.xcodeproj/project.pbxproj
M	PhotoCleanupMVE/Core/S0StateMachine.swift
M	PhotoCleanupMVE/Features/S0/S0CategoryRow.swift
M	PhotoCleanupMVE/Features/S0/S0View.swift
M	PhotoCleanupMVE/Features/Shared/ThumbnailView.swift
M	PhotoCleanupMVE/Services/S0CleanupDataStub.swift
M	PhotoCleanupMVE/Services/S0LibraryScanService.swift
M	PhotoCleanupMVE/Services/S0ScanClassifier.swift
M	PhotoCleanupMVETests/IC148S0VisualTests.swift
M	PhotoCleanupMVETests/IC153ScanServiceTests.swift
A	PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift
```

11 个路径全部落在卡内白名单表内（`Reports/IC-155/` 在报告提交里）。

### 行数（`git show --numstat`，逐提交）

| 文件 | A 增／删 | B 增／删 | C 增／删 | 合计 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 4／0 | — | — | 4／0 |
| `Core/S0StateMachine.swift` | 17／1 | — | — | 17／1 |
| `Services/S0ScanClassifier.swift` | 13／1 | — | — | 13／1 |
| `Services/S0CleanupDataStub.swift` | 42／10 | 48／0 | — | 90／10 |
| `Services/S0LibraryScanService.swift` | — | 43／0 | — | 43／0 |
| `Features/S0/S0View.swift` | — | 3／0 | 3／1 | 6／1 |
| `Features/S0/S0CategoryRow.swift` | — | — | 30／12 | 30／12 |
| `Features/Shared/ThumbnailView.swift` | — | — | 6／1 | 6／1 |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | 6／2 | — | — | 6／2 |
| `PhotoCleanupMVETests/IC153ScanServiceTests.swift` | 6／3 | — | — | 6／3 |
| `PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift`（新） | 445／0 | 504／0 | 123／0 | 1072／0 |

### hunk 头

```
[9661494 子项 A]
PhotoCleanupMVE.xcodeproj/project.pbxproj
@@ -63,6 +63,7 @@        ← PBXBuildFile      200000000000000000000057
@@ -163,6 +164,7 @@      ← PBXFileReference  10000000000000000000005A
@@ -394,6 +396,7 @@      ← 测试组 children
@@ -598,6 +601,7 @@      ← 测试目标 Sources 阶段
Core/S0StateMachine.swift
@@ -86,17 +86,23 @@ struct S0CategorySnapshot   ← M1
@@ -105,6 +111,16 @@ struct S0CategorySnapshot    ← M2（S0CategoryAsset，位于 S0CategorySnapshot 之后、S0LedgerEntry 之前）
Services/S0CleanupDataStub.swift
@@ -93,31 +93,36 @@   ← 扫描剧本五处构造加 coverAssetID:
@@ -143,31 +148,36 @@  ← 就绪剧本五处构造加 coverAssetID:
@@ -215,4 +225,26 @@   ← 两个私有静态 helper
Services/S0ScanClassifier.swift（三个 hunk 全在 S0ScanAggregator.snapshot 函数体内）
@@ -190,6 +190,10 @@ enum S0ScanAggregator
@@ -208,6 +212,13 @@ enum S0ScanAggregator
@@ -216,7 +227,8 @@ enum S0ScanAggregator
PhotoCleanupMVETests/IC148S0VisualTests.swift
@@ -1028,11 +1028,15 @@   ← K1
PhotoCleanupMVETests/IC153ScanServiceTests.swift
@@ -268,19 +268,22 @@    ← K2
[115263a 子项 B]
Features/S0/S0View.swift
@@ -14,6 +14,9 @@ protocol S0CleanupDataProviding: AnyObject {   ← P1
Services/S0CleanupDataStub.swift
@@ -81,6 +81,16 @@    ← categoryAssets(_:)
@@ -247,4 +257,42 @@   ← 合成列表 helper
Services/S0LibraryScanService.swift
@@ -144,6 +144,49 @@ final class S0LibraryScanService {   ← V1（只增：43 行 +，0 行 -）
PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift
@@ -315,6 +315,219 @@   ← 断言 4～7
@@ -363,10 +576,232 @@   ← 夹具 helper
@@ -443,3 +878,72 @@    ← 夹具源类型
[4e3e6c8 子项 C]
Features/S0/S0CategoryRow.swift
@@ -93,15 +93,21 @@ enum S0ByteCountSplit {       ← R1／R3
@@ -121,15 +127,27 @@ struct S0CategoryRowView    ← R2
Features/S0/S0View.swift
@@ -499,8 +499,10 @@ struct S0View: View {        ← P2
Features/Shared/ThumbnailView.swift
@@ -10,6 +10,9 @@ struct ThumbnailView: View {   ← T1 属性
@@ -31,11 +34,13 @@ struct ThumbnailView: View {  ← T1 无图分支
PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift
@@ -16,6 +16,129 @@ import XCTest   ← 断言 8～9（类首）
```

`S0View.swift` 相对 `51b4b95` 的整体 diff **恰两个 hunk**：`@@ -14,6 +14,9 @@ protocol S0CleanupDataProviding: AnyObject {`（P1）与 `@@ -496,8 +499,10 @@ struct S0View: View {`（P2）。

### 零改动实证（两侧 SHA-256：`git show 51b4b95:<path> | sha256sum` 与分支工作树 `sha256sum <path>`）

| 文件 | SHA-256（两侧相同） |
|---|---|
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `9ab1b363101b635d827e113e88bc931fa3cf93439026f915e29a3d0fc0a046c9` |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `c8b4b852fc19fcac809bd2ec4e5943d541c8ced41e5c7f8ea6b099e0e36da53a` |
| `PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift` | `2d88a10213b067ee5f62865f2968eca2f0f207b884bf01bb8efd28ca52b5a267` |
| `PhotoCleanupMVE/Features/S0/S0SegmentBar.swift` | `b1261c79714ceb3bd4363ce78b1cd59012f439fb69698599b1f8e92f26b4d1ef` |
| `PhotoCleanupMVE/Features/S0/S0TabContainer.swift` | `2f914cfaa30bab29b3f3a5fcfa9b3262914597976994ef0fd11409ee2ffd2f34` |
| `PhotoCleanupMVE/Services/S0ScanRules.swift` | `b37b0a0c6866c3f6abf4b988ccfd962c7bc78cf84a9b95e22322fce5cc3e663d` |
| `PhotoCleanupMVE/Services/S0ScanCache.swift` | `5def952b36b82f90c3da2db4ee9e9a855025a3350f155e2b37205e657119d9c7` |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | `006fba2859bba23b6534b723cd0d5299ab9b16b7fc374be609aa19937768f7a9` |
| `PhotoCleanupMVE/Services/PhotoLibraryService.swift` | `3087ac9f05fe7cb1b79012bf5ace154ebeda3e8186b745e2443c20449f76ac17` |
| `PhotoCleanupMVE/Localizable.xcstrings` | `398b27e1739cc7d64f501663e19573940789a6523be4d0d1517ba00352b0ae73` |
| `PhotoCleanupMVE/Features/S3/S3View.swift` | `881d1c74472f3019d9cc2177e2c61d57668d30ebe0863395012cecd9e57b87ff` |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f` |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `b6c747919c10e91b6032b3d41556f9875f26a0fad9562b68fd53a91cec7e6cd3` |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | `90ddffad6ab737bbe00ea1c1cb1cb402503949c45cb5080e55b483a248dfe032` |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | `be8379a3542c9d8ea193ce3acacc50530fc6a61a60fe7664ddb6fd4dd1db9a83` |
| `PhotoCleanupMVE/Core/SessionStore.swift` | `04095174d021739258498364d607c6229b10e3d8c1487cb8eb6da2ee1214ed7f` |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | `6ec277fcc7b9e59bb6e89ca9d575942c45376b06d18858c0410032f9aa35850e` |
| `PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift` | `4d1a095df5dc66187fcce0950b4df7f7c209c37169cc14b0313aa3c6d7abc72f` |
| `.github/workflows/ci.yml` | `ff4bbb0c32bc2b58d024e00f69a6195dccc2cbaa404dc28f76a2cb10c103ccdc` |

`git diff --stat 51b4b95 4e3e6c8 -- PhotoCleanupMVE/App Scripts .github PhotoCleanupMVE/Features/S1 PhotoCleanupMVE/Features/S2 PhotoCleanupMVE/Features/S3 PhotoCleanupMVE/Features/S4 PhotoCleanupMVE/Features/S5` 输出为空。

---

## 三、逐文件说明

### 子项 A

- **`Core/S0StateMachine.swift`**（M1、M2；状态机类一字未动）
  - `S0CategorySnapshot` 在 `recognition` 之后加 `let coverAssetID: String?`（带文档注释）；显式 init 末尾加形参 `coverAssetID: String? = nil`，赋值不夹断。既有 21 处测试构造点、IC-147 的 15 处与 IC-148 的 3 处**一行未动**，靠默认值照常编译。
  - 新增 `struct S0CategoryAsset: Equatable, Sendable, Identifiable`：`id: String`、`byteCount: Int64`、`isVideo: Bool`、`duration: TimeInterval`，memberwise 顺序即声明顺序，无显式 init。
- **`Services/S0ScanClassifier.swift`**（G1；只动 `S0ScanAggregator.snapshot` 函数体）
  - 加局部 `var coverAssets: [S0CategoryIdentifier: S0ClassifiedAsset]`；在既有 `for identifier in asset.hits` 循环里，候选计数与字节累加之后判「体积更大，或同体积且标识更小」即替换——候选集与 `candidateCount` 出自同一循环、同一组排除条件。
  - 类别构造加 `coverAssetID: coverAssets[identifier]?.id`。零新规则常量；剔注释后数值字面量仍只有 `0`、`1`（IC-153 断言 3）。
- **`Services/S0CleanupDataStub.swift`**（S1 的构造点部分）
  - 十处 `S0CategorySnapshot(` 各加 `coverAssetID: Self.coverAssetID(for: <类别>, candidateCount: <同一计数表达式>)`。
  - 新增两个私有静态 helper：`coverAssetID(for:candidateCount:)`（计数 > 0 给 `stub.<rawValue>.1`，否则 nil）与 `syntheticAssetID(for:ordinal:)`（`"stub." + rawValue + "." + String(ordinal)`，单表达式、无 `return "…"` 形状）。
  - 声明行 `final class S0CleanupDataStub: S0CleanupDataProviding {` 与钩子属性未动。
- **`PhotoCleanupMVETests/IC148S0VisualTests.swift`**（K1）：断言 14 的 `occurrences(of: "coverAssetID", …) == 0` 改为 `occurrences(of: "let coverAssetID: String?", …) == 1`，注释改为「生产者已在（IC-155 裁定 一）」并说明按声明行计数的理由。断言 14 其余部分（七个 needle、正对照、cover 切片三条）一字未动。
- **`PhotoCleanupMVETests/IC153ScanServiceTests.swift`**（K2）：断言 2 的三条期望各加 `coverAssetID:`——`.bigVideo` → `"recording"`、`.screenRecording` → `"recording"`、`.screenshot` → `"screenshot"`。其余一字未动。
- **`PhotoCleanupMVETests/IC155CategoryDataAndCoverTests.swift`（新）**：断言 1～3 与源码扫描 helper（`strippedSource`／`occurrences`，与 IC-147／148／153 同口径逐字照抄）。
- **`project.pbxproj`**：登记前全文件重扫——24 位十六进制对象定义 206 条无重复，文件引用最大 `100000000000000000000059`、构建文件最大 `200000000000000000000056`，候选 `10000000000000000000005A`／`200000000000000000000057` 全文件 0 命中。四行分别进 PBXBuildFile、PBXFileReference、测试组 children（紧跟 `IC153ScanServiceTests.swift`）、测试目标 Sources 阶段（同上）。

### 子项 B

- **`Features/S0/S0View.swift`**（P1）：协议在 `func advanceScan()` 与 IC-153 钩子的文档注释之间加两行文档注释与要求 `func categoryAssets(_ id: S0CategoryIdentifier) -> [S0CategoryAsset]`。注释与签名不含 `onSnapshotDidChange` 字样；钩子那一行原文未动（基线第 19 行，本卡后第 22 行）。
- **`Services/S0LibraryScanService.swift`**（V1；只增不删，43 行 +、0 行 -）：在 `currentSnapshot()` 之后新增 `func categoryAssets(_ id:)`——
  1. `pendingDeletionAssetIDs()` 在锁外先取（与 `currentSnapshot()` 同法）；
  2. `withState` 内一次遍历 `records`：`libraryIdentifiers` 过滤 → 条目 `classified(id:)` → `!isUnresolved`、`!S0ScanClassifier.isExcludedFromCategories(_, pendingDeletionAssetIDs:, ledgerAssetIDs: [])`、`primaryCategory(for:) != nil`、`hits.contains(id)` → 投影四字段（`isVideo = mediaType == .video`、`duration` 取条目）；
  3. 锁外按「体积降序、同体积标识升序」排序后返回。不发源请求、不记忆化、不改任何既有状态。
- **`Services/S0CleanupDataStub.swift`**（S1 的列表本体）
  - `categoryAssets(_:)`：取 `currentSnapshot().categories` 中该类别，交 `syntheticAssets(for:)`；没有该类别（失败剧本、真实服务不产出的类别）给空列表。
  - `syntheticAssets(for:)`：`n = candidateCount`、`B = candidateByteCount`；公差 `d = B / n²`（整除）、`spread = d × n(n−1)/2`、最小项 `base = (B − spread) / n`、余数 `r = B − spread − base × n`（0 ≤ r < n）；第 i 条（i 从 0 起）= `base + d × (n − 1 − i) + (i < r ? 1 : 0)`，id `stub.<rawValue>.<i+1>`；`bigVideo`／`screenRecording` 为视频，`duration = 字节 ÷ 10 000 000`（私有常量 `syntheticVideoBytesPerSecond`，只为类别页角标有数可画），其余为照片、时长 0。
- **测试文件**：断言 4～7；夹具 helper（`coverLibrary()`、`makeService(_:)`、`snapshotCategory(_:of:)`、`assertListsMatchSnapshot(_:)`、`isOrderedBySizeThenIdentifier(_:)`、临时目录与 `tearDown`、`waitUntil`）；文件级私有类型 `IC155Reading` 与 `IC155LibraryFixture`（`NSLock` 保护、库内元数据可在两遍扫描之间删减）。

### 子项 C

- **`Features/Shared/ThumbnailView.swift`**（T1）：`cornerRadius` 之后加 `var showsPlaceholderGlyph: Bool = true`；无图分支 `} else {` 改 `} else if showsPlaceholderGlyph {`（系统图标四行原样），再补 `} else { Color.clear }`。与卡面「`if showsPlaceholderGlyph { 原样 } else { Color.clear }`」等价，改动行更少。`load()`／`cancel()` 与 `.frame`／`.clipped`／`.clipShape`／`onAppear`／`onDisappear` 一字未动。
- **`Features/S0/S0CategoryRow.swift`**（R1～R3）
  - R1：`subtitle` 之后加 `let coverAssetID: String?`；加 `@Environment(\.displayScale) private var displayScale`（不进 memberwise init，访问级别先例 `S3View`）。
  - R2：`cover` 声明行保留，函数体改 `ZStack { 描边空槽; if let coverAssetID { ThumbnailView(assetIdentifier:sideLength:displayScale:cornerRadius:showsPlaceholderGlyph: false) } }`，外层 `.frame(categoryCoverSide²)` 与 `.accessibilityHidden(true)` 保留。
  - R3：结构体文档注释改为本卡口径；不含 IC-148 断言 14 的七个 needle。
- **`Features/S0/S0View.swift`**（P2）：构造点加 `coverAssetID: category.coverAssetID`，并对 `S0CategoryRowView(…)` 加 `.id(category.coverAssetID)`。
- **测试文件**：类首追加断言 8～9 与 `coverSlice(_:)` helper。

---

## 四、占位值登记

本卡**无**标定出厂值变更：`S2CalibrationConfiguration.schemaVersion` 保持 **7**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`，文件不在 diff 内）；`S0ScanRules.cacheSchemaVersion` 保持 **1**（`S0ScanRules.swift:27`，文件不在 diff 内）。零新登记常量（`S0HomeMetrics` 仍 52、`S0ScanRules` 仍 7）、零新文案（`s0.` key 仍 32）。

桩内新增的 `syntheticVideoBytesPerSecond = 10_000_000` 只用于合成桩数据的时长，不是产品登记值、不进任何登记表。
