# IC-156 变更清单

- 任务卡：`<top>/Tasks/IC-20260916-156-category-page.md`（本机 `sha256sum` = `e7453fe880d8cbf472f8d3577f7e8b759ef85ec30e7734e0a60a1864cf6051ef`）
- 分支：`feature/ic-156-category-page`
- 基线：`main` = `cc686d92d29ba4adcc41607983ae47a199179be7`（IC-155 报告回填；IC-155 合并提交 `07b7f76acb146690477b00c7500de0412851aaf1`）
- 分支 tip（代码）：`c92c641dae3da60d020af1ee20be67dd9d4b9b0e`（CI #313 被测提交：attempt 1 红于已知计时脆弱用例 `testIC063…`、同一提交原样复跑 attempt 2 绿 844 项 0 失败，`self-check.md` 第四节）
- 分支 tip（含报告）：`8504a7d75c8bfad4b08b8f1e5fa3745f1eebfc02`
- 合并提交（`main`，`--no-ff`，执行端按卡内授权执行）：`c42edd1ded6ccd1e7ec0d17b2e3745560cdbfa78`（父 `cc686d92d29ba4adcc41607983ae47a199179be7` 与 `8504a7d75c8bfad4b08b8f1e5fa3745f1eebfc02`）；合并后 `main` 运行 #314 attempt 1 一次绿 844 项 0 失败（G891，`self-check.md` 第九节）
- 提交数：4 个代码提交（子项 A／B／C／D 各一）+ 1 个报告提交（分支）+ 合并提交 + 回填提交（`main`，本清单所在提交）
- `S2CalibrationConfiguration.schemaVersion`：**7，未动**；`S0ScanRules.cacheSchemaVersion`：**1，未动**；`S0HomeMetrics`：**52，未动**

---

## 一、提交清单

| # | SHA | 子项 | 标题 | 树对象 |
|---|---|---|---|---|
| 1 | `55f2819415c633f9ea8d2f2b7a920b7e7f6672cd` | A | 类别页登记表 S0CategoryPageMetrics（42 个常量）与符号、虚拟范围前缀 | `5d5f977ce1b509c67f78332d2f38d1e197313cff` |
| 2 | `bf271092cb3800660f5552b1bf8255cb328dc4b8` | B | S1StateMachine.markPendingDeletion——类别页进篮的会话层原子写入口 | `d5957c364a94d490a825a5e3b9ce1d11de0b12cb` |
| 3 | `0fb15af71803e8fe3554b53e3ed5d217d80f6574` | C | 类别页视图、选择模型、toast 与五条文案（S0CategoryPageView） | `8db48585e9a45400fcac981714b664b6ed52e4b5` |
| 4 | `c92c641dae3da60d020af1ee20be67dd9d4b9b0e` | D | 承载容器 S0CleanupFlowView 与 App 接线——类别页可进可回、进篮写会话层并重算 | `34d577200c9d729be3415b77d359fe02584a5244` |
| 5 | `8504a7d75c8bfad4b08b8f1e5fa3745f1eebfc02` | — | docs：自验报告与变更清单（#313 a1 红于 testIC063、原样复跑 a2 绿 844 项 0 失败） | `5327beb601f0f422fc299f012b27e1ec54c72ffc` |
| 合并 | `c42edd1ded6ccd1e7ec0d17b2e3745560cdbfa78` | — | Merge IC-156（父 `cc686d9` 与 `8504a7d`） | `5327beb601f0f422fc299f012b27e1ec54c72ffc`（= `8504a7d` 的树） |
| 回填 | 本提交（`main`） | — | docs：回填合并提交与 G891 | — |

### 可摘取单元（惯例 40，①实测）

草稿区另有一份克隆（`core.autocrlf=false`），`git fetch` 本地分支后从 `cc686d9` 分离检出、逐个 `cherry-pick`（`<scratchpad>/ic156/pickcheck.sh`）；A→C 与 B 单独两项另在主仓库用 `git merge-tree --write-tree` 复核（只写对象、不动任何 ref）：

| 摘取 | 结果 | 叠完的树对象 |
|---|---|---|
| A 单独 | 无冲突 | `5d5f977ce1b509c67f78332d2f38d1e197313cff` = 提交 `55f2819` 自身的树 |
| A→B | 无冲突 | `d5957c364a94d490a825a5e3b9ce1d11de0b12cb` = 提交 `bf27109` 自身的树 |
| A→C | 无冲突 | `361bef2ebc3772ada2a3c386c95aabd0475db4e2`（克隆内 cherry-pick 与主仓库 `git merge-tree --write-tree --merge-base=bf27109 55f2819 0fb15af` 同一对象，退出码 0） |
| A→B→C→D | 无冲突 | `34d577200c9d729be3415b77d359fe02584a5244` = 分支 tip `c92c641` 的树 |
| **B 单独** | **冲突** | `CONFLICT (modify/delete): PhotoCleanupMVETests/IC156CategoryPageTests.swift`——B 往 A 新建的测试文件末尾追加断言 3～4，基线上没有这个文件；B 的产品改动 `Core/S1StateMachine.swift` 本身干净应用（克隆内暂存为 `M`） |
| **B→A→C→D** | **冲突**（停在第一步 B，原因同上） | — |

**卡内声明的五个可摘取单元里，A 单独、A→C、A→B→C→D 三个成立；「B 单独」「B→A→C→D」两个不成立**（`self-check.md` 第 7.4 条）：卡内摘取关系同一段又要求「新测试文件在 A 创建，B、C、D 各自追加」，B 的提交因此整体只能排在 A 之后。B 的**产品改动**（`markPendingDeletion` 一个方法）不依赖 A，按「只取 `Core/S1StateMachine.swift`」摘取时成立。

为让 A→C 不经 B，**子项 C 的断言 5～9 与其 helper 插在测试类最前面**（断言 1 之前），D 的断言 10～11 紧接在 C 段之后；B 追加在类末尾。

---

## 二、文件变更全量（`git diff --name-status cc686d9 c92c641`）

```
M	PhotoCleanupMVE.xcodeproj/project.pbxproj
M	PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
M	PhotoCleanupMVE/Core/S1StateMachine.swift
A	PhotoCleanupMVE/Features/S0/S0CategoryPageMetrics.swift
A	PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift
A	PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift
M	PhotoCleanupMVE/Localizable.xcstrings
M	PhotoCleanupMVETests/IC147S0BehaviorTests.swift
M	PhotoCleanupMVETests/IC148S0VisualTests.swift
A	PhotoCleanupMVETests/IC156CategoryPageTests.swift
```

10 个路径逐一对照卡内白名单表：M1、B1、C1、C2、C3（两个文件）、D1、D2、本卡测试文件、pbxproj——全部在表内，且各自只落在表内写明的范围（下文 hunk 头）。`Reports/IC-156/` 在报告提交里。

### 行数（`git show --numstat`，逐提交）

| 文件 | A 增／删 | B 增／删 | C 增／删 | D 增／删 | 合计 |
|---|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 8／0 | — | 4／0 | 4／0 | 16／0 |
| `Features/S0/S0CategoryPageMetrics.swift`（新） | 220／0 | — | — | — | 220／0 |
| `Core/S1StateMachine.swift` | — | 31／0 | — | — | 31／0 |
| `Features/S0/S0CategoryPageView.swift`（新） | — | — | 521／0 | — | 521／0 |
| `Localizable.xcstrings` | — | — | 55／0 | — | 55／0 |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | — | — | 7／3 | — | 7／3 |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | — | — | 5／2 | — | 5／2 |
| `Features/S0/S0CleanupFlowView.swift`（新） | — | — | — | 105／0 | 105／0 |
| `App/PhotoCleanupMVEApp.swift` | — | — | — | 19／4 | 19／4 |
| `PhotoCleanupMVETests/IC156CategoryPageTests.swift`（新） | 253／0 | 139／0 | 453／0 | 94／1 | 938／0（文件终稿 938 行） |

**新 Swift 行数与文件清单**（卡内估 500～700 行）：新建产品文件 3 个共 **846** 行（登记表 220、类别页 521、流程容器 105）；既有产品文件增 **50** 行、删 **4** 行（`S1StateMachine.swift` +31／−0、App 入口 +19／−4）；新建测试文件 1 个 **938** 行；既有测试文件增 12 行、删 5 行（C3 五处）。Swift 合计增 **1846** 行、删 **9** 行。另：pbxproj +16、xcstrings +55。

### hunk 头（`git show -U3`，逐提交）

```
[55f2819 子项 A]
PhotoCleanupMVE.xcodeproj/project.pbxproj
@@ -64,6 +64,8 @@     ← PBXBuildFile      200000000000000000000058（登记表）／200000000000000000000059（测试）
@@ -165,6 +167,8 @@   ← PBXFileReference  10000000000000000000005B／10000000000000000000005C
@@ -301,6 +305,7 @@   ← S0 组 children（紧跟 S0CategoryRow.swift）
@@ -397,6 +402,7 @@   ← 测试组 children（紧跟 IC155CategoryDataAndCoverTests.swift）
@@ -530,6 +536,7 @@   ← 应用目标 Sources 阶段
@@ -602,6 +609,7 @@   ← 测试目标 Sources 阶段
PhotoCleanupMVE/Features/S0/S0CategoryPageMetrics.swift   @@ -0,0 +1,220 @@
PhotoCleanupMVETests/IC156CategoryPageTests.swift          @@ -0,0 +1,253 @@
[bf27109 子项 B]
PhotoCleanupMVE/Core/S1StateMachine.swift
@@ -780,6 +780,37 @@ final class S1StateMachine: ObservableObject {   ← B1（只增：31 行 +，0 行 -）
PhotoCleanupMVETests/IC156CategoryPageTests.swift
@@ -250,4 +250,143 @@ final class IC156CategoryPageTests: XCTestCase {   ← 断言 3～4（类末尾）
[0fb15af 子项 C]
PhotoCleanupMVE.xcodeproj/project.pbxproj
@@ -66,6 +66,7 @@ ／ @@ -169,6 +170,7 @@ ／ @@ -306,6 +308,7 @@ ／ @@ -537,6 +540,7 @@   ← 20000000000000000000005A／10000000000000000000005D 四行
PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift       @@ -0,0 +1,521 @@
PhotoCleanupMVE/Localizable.xcstrings
@@ -221,6 +221,61 @@   ← 五条 s0.categoryPage.*（插在 s0.home.category.counting 之前，只增）
PhotoCleanupMVETests/IC147S0BehaviorTests.swift
@@ -794,7 +794,8 @@ final class IC147S0BehaviorTests: XCTestCase {    ← 断言 10：32 → 37
@@ -824,7 +825,9 @@ final class IC147S0BehaviorTests: XCTestCase {    ← 断言 11：文件名单加类别页
@@ -840,7 +843,8 @@ final class IC147S0BehaviorTests: XCTestCase {    ← 断言 11：32 → 37
PhotoCleanupMVETests/IC148S0VisualTests.swift
@@ -837,11 +837,14 @@ final class IC148S0VisualTests: XCTestCase {     ← 断言 10：32 → 37 与文件名单加类别页
PhotoCleanupMVETests/IC156CategoryPageTests.swift
@@ -17,6 +17,459 @@ import XCTest   ← 断言 5～9 与 C 的 helper（类首）
[c92c641 子项 D]
PhotoCleanupMVE.xcodeproj/project.pbxproj
@@ -67,6 +67,7 @@ ／ @@ -171,6 +172,7 @@ ／ @@ -309,6 +311,7 @@ ／ @@ -541,6 +544,7 @@   ← 20000000000000000000005B／10000000000000000000005E 四行
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
@@ -46,7 +46,7 @@ struct PhotoCleanupMVEApp: App {    ← cleanupContent 那一行
@@ -84,13 +84,28 @@ struct PhotoCleanupMVEApp: App {   ← s0Screen（文档注释加一段 + 函数体）
PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift        @@ -0,0 +1,105 @@
PhotoCleanupMVETests/IC156CategoryPageTests.swift
@@ -333,7 +333,9 @@ final class IC156CategoryPageTests: XCTestCase {   ← 断言 6 的逐文件名单加流程文件
@@ -470,6 +472,97 @@ final class IC156CategoryPageTests: XCTestCase {   ← 断言 10～11（紧接 C 段）
```

App 入口相对 `cc686d9` 删掉的 4 行恰为：`s0Screen()`（`cleanupContent` 闭包内）、`private func s0Screen() -> some View {`、`S0View(`、构造闭包收尾的 `}`（其后补了逗号与两个新实参）。`.onAppear` 块、四个路由分支、`s1Screen`／`s2Screen`、`restoreS0Foreground` 均在 hunk 之外。

### `Core/S1StateMachine.swift` 的 diff（只增不删的实证）

`git diff --numstat cc686d9 c92c641 -- PhotoCleanupMVE/Core/S1StateMachine.swift` = `31	0`；一个 hunk `@@ -780,6 +780,37 @@`，位于既有 `applyS3Return` 之后、`private func publishSnapshotIfChanged()` 之前；`^-` 行 **0**。新增内容（空行 1 + 文档注释 11 + 代码 19）：

```swift
    @discardableResult
    func markPendingDeletion(
        assetIDs: Set<String>,
        virtualRangeID: String,
        displayName: String
    ) -> Bool {
        guard !assetIDs.isEmpty,
              !virtualRangeID.isEmpty,
              !displayName.isEmpty else {
            return false
        }
        var nextStore = sessionStore
        for assetID in assetIDs.sorted() {
            nextStore.setMarked(true, assetID: assetID, rangeID: virtualRangeID)
        }
        knownRangeNamesByID[virtualRangeID] = displayName
        sessionStore = nextStore
        return true
    }
```

### 零改动实证（`<scratchpad>/ic156/g887_889.py c92c641`：`git show cc686d9:<path>` 与 `git show c92c641:<path>` 两侧 blob 的 SHA-256）

| 文件 | SHA-256（两侧相同） |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0View.swift` | `4a81d3fa72ccf6f522265c202608e967ad8e7102712cfb37d165fdef6fcd558f` |
| `PhotoCleanupMVE/Features/S0/S0TabContainer.swift` | `2f914cfaa30bab29b3f3a5fcfa9b3262914597976994ef0fd11409ee2ffd2f34` |
| `PhotoCleanupMVE/Features/S0/S0CategoryRow.swift` | `df67a0fcafa50c009acee6a0ee6884cc2019e86f48efdacdb7839fae301fb1fb` |
| `PhotoCleanupMVE/Features/S0/S0SegmentBar.swift` | `b1261c79714ceb3bd4363ce78b1cd59012f439fb69698599b1f8e92f26b4d1ef` |
| `PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift` | `2d88a10213b067ee5f62865f2968eca2f0f207b884bf01bb8efd28ca52b5a267` |
| `PhotoCleanupMVE/Core/AssetModels.swift` | `7f9e570b485af163a56e145843bcc4c134b0833b92c1bfaffd12d96a097fc818` |
| `PhotoCleanupMVE/Core/L10n.swift` | `9d72be86d70f31972c7dff31b172c4f8c5cb9af9a1716aec2cefe188ba203826` |
| `PhotoCleanupMVE/Core/S0StateMachine.swift` | `29e1a38485a2f0305abeb62c9e8607494aa47c83895369687ad5994dd32b0425` |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | `90ddffad6ab737bbe00ea1c1cb1cb402503949c45cb5080e55b483a248dfe032` |
| `PhotoCleanupMVE/Core/S3StateMachine.swift` | `d8e01383d1c00961298e95f225220b3a601ad18354d993ad4d5b9a3a5f57fb07` |
| `PhotoCleanupMVE/Core/S4StateMachine.swift` | `25626d2a9fd7f017789eccf69b5ad0ccd5f04a8b77458371e8fcb8e60b808d6a` |
| `PhotoCleanupMVE/Core/S5StateMachine.swift` | `bb9270ea08ea47c5bca174a6691c8c4cd47d773e5b4af1140dfcd49035b763b2` |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | `be8379a3542c9d8ea193ce3acacc50530fc6a61a60fe7664ddb6fd4dd1db9a83` |
| `PhotoCleanupMVE/Core/SessionStore.swift` | `04095174d021739258498364d607c6229b10e3d8c1487cb8eb6da2ee1214ed7f` |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | `006fba2859bba23b6534b723cd0d5299ab9b16b7fc374be609aa19937768f7a9` |
| `PhotoCleanupMVE/Services/PhotoAssetActionService.swift` | `805b94e844d33336a5365c16187e246d7ab6db9fcb1245a02c338e382886cf18` |
| `PhotoCleanupMVE/Services/PhotoDeletionService.swift` | `ec89e66d04c9f468f3a6f4adb8fbc7f00ae1bc72ab840f76d1e649d047a4d0bb` |
| `PhotoCleanupMVE/Services/PhotoLibraryService.swift` | `3087ac9f05fe7cb1b79012bf5ace154ebeda3e8186b745e2443c20449f76ac17` |
| `PhotoCleanupMVE/Services/S0CleanupDataStub.swift` | `090532abc3a401e839cb350386500d34e73bcfe3ae3fc0502e04aaf4e275a5c4` |
| `PhotoCleanupMVE/Services/S0LibraryScanService.swift` | `5c66acc28ec0bd1ed9d49757dac4b6b474f0525d0c5401a65f66c1d30d8d5031` |
| `PhotoCleanupMVE/Services/S0ScanCache.swift` | `5def952b36b82f90c3da2db4ee9e9a855025a3350f155e2b37205e657119d9c7` |
| `PhotoCleanupMVE/Services/S0ScanClassifier.swift` | `bd87647e6e2b247b01e99b6b6c1a05629de83adcd9636bd8045df71e0d87e88b` |
| `PhotoCleanupMVE/Services/S0ScanRules.swift` | `b37b0a0c6866c3f6abf4b988ccfd962c7bc78cf84a9b95e22322fce5cc3e663d` |
| `PhotoCleanupMVE/Services/S2RecentAlbumStore.swift` | `6653accfc54624cfd9f903dc9bcc2af6ac6dd77ff734031c54fc319dbad63d9e` |
| `PhotoCleanupMVE/Services/S2TutorialCompletionStore.swift` | `489b8409a1c8a2eb9df1dfd692f0b35abadec4b8c102013ecc1c479f97009ad1` |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | `7a5913e45528ae2fa910667848fdc183033b531ac3b1ec0f76e909ae08172c7a` |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f` |
| `PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift` | `a0300f86afac7877021a2d421d3f7acdc21fd8d36bf16704bf16783b5876662d` |
| `PhotoCleanupMVE/Features/S3/S3View.swift` | `881d1c74472f3019d9cc2177e2c61d57668d30ebe0863395012cecd9e57b87ff` |
| `PhotoCleanupMVE/Features/S4/S4View.swift` | `91edeef270e6fd47f6b30ce53b7704471fb8170c35abf9d6f4e518c2ee12df37` |
| `PhotoCleanupMVE/Features/S5/S5View.swift` | `c37f6795d3e86644a4b555d7dcd2709b86e48ccd858eca3cac23c6abc15f4acf` |
| `PhotoCleanupMVE/Features/Shared/ThumbnailView.swift` | `be251cc8ec79f61c06f66ded323e18e6bb30682529a9445f3d604d3ff0af9677` |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `c8b4b852fc19fcac809bd2ec4e5943d541c8ced41e5c7f8ea6b099e0e36da53a` |
| `.github/workflows/ci.yml` | `ff4bbb0c32bc2b58d024e00f69a6195dccc2cbaa404dc28f76a2cb10c103ccdc` |

另外逐文件核过、未列入上表的：`Features/S2/` 其余 6 个文件与 `Scripts/` 全部 33 个文件两侧 blob 相同（`Scripts/` 清单哈希两侧同为 `7569794f0020c4f8088da118da117b62f60a8154bf058ae3c794523b2e15367a`）。`git diff --stat cc686d9 c92c641 -- Scripts .github PhotoCleanupMVE/Services PhotoCleanupMVE/Features/S1 … S5 PhotoCleanupMVE/Features/Shared PhotoCleanupMVE/App/CleanupCoordinator.swift` 与五个 S0 文件：输出为空。`Core/` 10 个文件里只有 `S1StateMachine.swift` 变（只增，见上）。

**口径注记（①）**：本机 `core.autocrlf=true` 且 `.gitattributes` 未给 `*.log` 定 eol，`Scripts/fixtures/` 下四个 `.log` 夹具在工作树里是 CRLF、在仓库里是 LF（`git ls-files --eol`：`i/lf w/crlf`），拿工作树文件直接 `sha256sum` 会与基线 blob 不等；`git diff cc686d9 -- Scripts` 为空。上表因此一律比较提交里的 blob。

---

## 三、逐文件说明

### 子项 A（`55f2819`）

- **`Features/S0/S0CategoryPageMetrics.swift`（新，M1）**：文件头照 `S0HomeMetrics.swift` 写总数与分组（42 = v2 已登记 5 + 本卡补登 37：页面边距 2 + 大标题 6 + 副行 3 + 常驻行 3 + 网格位置 2 + 体积标签 4 + 时长角标 4 + 勾 3 + 选中外圈 1 + 主按钮 8 + 渐隐 1）。`enum S0CategoryPageMetrics` 内 42 个 `static let`，每个上一行文档注释含 `取值出处：`——5 个为「SPEC-S0 v2 第十四节第 2 部分 `<名>`」，37 个为「画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）」；字重写在注释里、不另设常量；顶排与颜色不在此登记（文件头写明理由）。同文件 `enum S0CategoryPageSymbol { back = "chevron.left"; play = "play.fill"; check = "checkmark" }`、`enum S0CategoryPageRange { prefix = "cat:" }`（字符串登记，不计入 42）。
- **测试文件（新）**：断言 1～2 与源码扫描 helper（`repoRoot`／`sourceText`／`strippedSource`／`occurrences`／`slice`，与 IC-147／148／155 同口径）。
- **pbxproj**：登记前重扫——对象定义 208 条无重复，文件引用最大 `10000000000000000000005A`、构建文件最大 `200000000000000000000057`（与卡内①一致）；登记表 `10000000000000000000005B`／`200000000000000000000058`，测试文件 `10000000000000000000005C`／`200000000000000000000059`。

### 子项 B（`bf27109`）

- **`Core/S1StateMachine.swift`（B1）**：新增 `markPendingDeletion(assetIDs:virtualRangeID:displayName:)`（上文全文）。三项输入任一为空返回 false、零副作用；否则在副本上按标识升序逐个 `setMarked(true, assetID:rangeID:)`（`F` 只在无首标时写入，`D_全部` 自然去重），登记 `knownRangeNamesByID[virtualRangeID] = displayName`，**最后一次**赋值 `sessionStore`——`didSet` 的持久化写出口只触发一次，发布的快照里名字表与 `M` 同步。无 `state`／`isObscured` 门槛。既有方法一字未动。
- **测试文件**：类末尾追加断言 3～4 与夹具（`makeReadyMachine(sessionID:)`、`fixtureRanges`）。

### 子项 C（`0fb15af`）

- **`Features/S0/S0CategoryPageView.swift`（新，C1）**，五个类型：
  - `struct S0CategoryPageSelection: Equatable`：`items`／`selected` 均 `private(set)`；`totalByteCount`、`selectedByteCount`、`isSubmitEnabled`（`!selected.isEmpty`）、`selectedTextReplacements`（常驻行与主按钮**共用**：`count` = `String(selected.count)`、`bytes` = `S0ByteCountText.string(forByteCount: selectedByteCount)`）、`subtitleTextReplacements`（全部项）；`toggle(_:)`（不在网格里的标识不理会）、`selectAllOrNone()`（一项未选 → 全选，否则全不选）、`remove(ids:)`（`removeAll` 保序删项 + `selected.subtract`）。
  - `enum S0CategoryPageDurationText`：每次现造 `DateComponentsFormatter`（`[.minute, .second]`、`.positional`、`.pad`），`max(0, duration)`，照 `S0ByteCountText` 的每次现造写法。
  - `final class S0FeedbackToastPresenter: ObservableObject`：照 `S1FeedbackToastPresenter`——`@Published private(set) var activeText: String?`、`presentedCount`、`lastScheduledDurationSeconds`、代际计数、注入 `scheduler`（默认 `DispatchQueue.main.asyncAfter`）；`present(text:durationMilliseconds:)` 毫秒换秒走 `Measurement(value:unit: UnitDuration.milliseconds).converted(to: .seconds)`（不写换算裸数，负值按 0）；旧代际到期不清新代际。
  - `struct S0CategoryGridCell: View`：`ThumbnailView(assetIdentifier: item.id, sideLength: side, displayScale:, cornerRadius: gridCellCornerRadius, showsPlaceholderGlyph: false)`（缩略图视图自己先框后裁，格内不再包 `scaledToFill`）+ 四层 overlay：右下体积标签（11 号半粗、白字、黑底 0.50、圆角 7、内距 6×2、距边 6）；`isVideo` 时左下播放符 + 时长（11 号半粗、间距 3、黑影 0.70 半径 4、距边 6）；右上勾（22 圆、距边 6；选中 = 白底 + `S2AmbientMetrics.baseColor` 对勾，未选 = 黑 0.25 底 + 白 0.90 描边 1.5）；选中格白外圈（描边 2、圆角 10）。
  - `struct S0CategoryPageView: View`：参数照卡 `category`、`items`、`onMoveToBasket`、`onBack`、`toastDurationMilliseconds`（显式 init，`_selection = State(initialValue:)`）；`@StateObject toast`。`body` = `ZStack(alignment: .bottom)`：`S2AmbientBackdropView().ignoresSafeArea()` → `VStack(spacing: 0)`【顶排（`HStack(spacing: S1ChromeLayout.itemSpacing)`：返回圆钮 `Image(systemName: S0CategoryPageSymbol.back).foregroundStyle(S0HomePalette.text).s1ChromeCircleGlass()` ｜ `Spacer` ｜「全选」胶囊 = 首页待删篮胶囊同款，字号 `S1ChromeTypography.titleFontSize`；行高 `rowHeight`、左右 `horizontalMargin`、顶 `topRowTopInset`）→ 大标题块（色点 `S0HomeMetrics.categoryColor(for:)` 10 圆 + 类别名 30 号粗体字距 −0.7，行高 34；副行 14 号白 0.55，上距 4；左右 24、顶 12）→ 常驻行（13 号白 0.60，左对齐，左右 24、顶 12，右侧留空）→ 网格（`GeometryReader` → `ScrollView` → `LazyVGrid` 三列 `.fixed(边长)`、间距 4；边长 = max(0, (宽 − 20×2 − (3−1)×4) ÷ 3)；左右 20、顶 12、底留 `ctaBottomInset + ctaHeight`；`ignoresSafeArea(edges: .bottom)`）】→ 底栏（`ZStack(alignment: .bottom)`：渐隐 `LinearGradient(baseColor 0 → baseColor)` 高 190、不接触控；`VStack(spacing: S2OverlayLayout.minimumSpacing)`【toast（`.subheadline`、白字、内距 16×8、`s1ChromeGlassBackground(in: Capsule())`、不接触控）+ 主按钮（`submit` key、17 号粗体 `baseColor` 字、高 52、白底圆角 26、黑影 0.45 半径 30 y 10；`.disabled(!isSubmitEnabled)` + 不透明度 1／0.35）】左右 20、底 42；`ignoresSafeArea(edges: .bottom)`）。`submit()`：已选为空或 `onMoveToBasket` 返回 false 则不动；成功则 `remove(ids:)`、toast `s0.categoryPage.toast`。
- **`Localizable.xcstrings`（C2）**：插在 `s0.home.category.counting` 之前五条（`extractionState` manual、单一 `zh-Hans` `stringUnit` translated，照既有条目）；目录条目 247 → 252，`s0.` 32 → 37；`sourceLanguage` 与其余条目逐字不变（第二节 g887 脚本解析两侧 JSON：新增恰为五条、删除 0、改动 0、顶层字段相同）。
- **`IC147S0BehaviorTests.swift`（C3，三处）**：断言 10 `s0Values.count` 32 → 37（加一行注释）；断言 11 文件名单加 `"PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift"`（注释写明 IC-156）；断言 11 `catalogS0Keys.count` 32 → 37（加一行注释）。
- **`IC148S0VisualTests.swift`（C3，两处，同一 hunk）**：断言 10 `catalogS0Keys.count` 32 → 37；文件名单 `Self.viewFiles + [容器]` 再加类别页文件（注释写明 IC-156）。函数名 `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` 未改（`self-check.md` 第十四节）。
- **测试文件**：类首插入断言 5～9 与 C 的夹具与 helper（`pagePath`／`s1ViewPath`／`thumbnailPath`、`disciplineFiles`、`photoKitNeedles`、`dynamicAppearanceNeedles`、`fixtureAssets`、`numericLiterals(in:)`、`localizationKeys(in:)`、`loadCatalogValues()`，后三者与 IC-147／IC-148 同口径）。
- **pbxproj**：重扫后 `10000000000000000000005D`／`20000000000000000000005A`（紧跟登记表文件）。

### 子项 D（`c92c641`）

- **`Features/S0/S0CleanupFlowView.swift`（新，D1）**：显式 init，形参照卡 `machine`、`dataProvider`、`onSwitchToOrganizeTab`、`onMoveToBasket`、`toastDurationMilliseconds`（均存为 `private let`）；`@State private var presentedCategory: S0CategoryIdentifier? = nil`。`body` = `NavigationStack { homeScreen.toolbar(.hidden, for: .navigationBar).navigationDestination(item: $presentedCategory) { page(for: $0) } }.onChange(of: presentedCategory) { 由非 nil 变 nil → machine.ingest(dataProvider.currentSnapshot()); machine.handle(.returnedFromCategoryPage) }`。`homeScreen` 原样构造 `S0View(machine:dataProvider:onEnterCategoryPage: { presentedCategory = $0 }, onSwitchToOrganizeTab:)`；`page(for:)` 在 `machine.category(identifier)` 非 nil 时造 `S0CategoryPageView(category:items: dataProvider.categoryAssets(identifier), onMoveToBasket:onBack: { presentedCategory = nil }, toastDurationMilliseconds:)` 并 `.toolbar(.hidden, for: .tabBar)`、`.toolbar(.hidden, for: .navigationBar)`；`moveToBasket` 在回调返回 true 后 `machine.ingest(dataProvider.currentSnapshot())`。不引用 `CleanupCoordinator`／`SessionStore`／`S1StateMachine`。根页也隐藏导航栏的理由见 `self-check.md` 第 7.2 条。
- **`App/PhotoCleanupMVEApp.swift`（D2）**：`s0Screen()` → `private func s0Screen(s1Machine: S1StateMachine) -> some View { S0CleanupFlowView(…) }`，`onMoveToBasket: { assetIDs, identifier in s1Machine.markPendingDeletion(assetIDs: assetIDs, virtualRangeID: S0CategoryPageRange.prefix + identifier.rawValue, displayName: S0CategoryText.displayName(for: identifier)) }`，`toastDurationMilliseconds` 与 S1 接线同一读法（`coordinator.s2Calibration.configuration.feedbackToastDurationMilliseconds`）；原 IC-147 C 的文档注释保留，其后加一段 IC-156 D 说明；`tabContainer(s1Machine:)` 内 `cleanupContent: { s0Screen(s1Machine: s1Machine) }`。其余一字不动。
- **测试文件**：断言 6 的 `disciplineFiles` 加 `flowPath`；C 段之后插入断言 10～11 与 D 的两个路径常量。
- **pbxproj**：重扫后 `10000000000000000000005E`／`20000000000000000000005B`（紧跟类别页文件）；分支 tip 对象定义 216 条（208 + 本卡 8）、重复 0。

---

## 四、文案登记（`Localizable.xcstrings`，zh-Hans，只增五条）

| key | 值 | 引用点（`S0CategoryPageView.swift`） |
|---|---|---|
| `s0.categoryPage.subtitle` | `{count} 个 · {bytes} · 按体积从大到小` | 副行，`subtitleTextReplacements` |
| `s0.categoryPage.selectAll` | `全选` | 顶排胶囊 |
| `s0.categoryPage.selected` | `已选 {count} 项 · {bytes}` | 常驻行，`selectedTextReplacements` |
| `s0.categoryPage.submit` | `移入待删篮 · {count} 项 {bytes}` | 主按钮，`selectedTextReplacements`（零选中时 `count` = `0`） |
| `s0.categoryPage.toast` | `已移入待删篮` | 进篮成功的 toast |

`s0.categoryPage.longPressHint` 未登记（归 IC-157）；返回圆钮无无障碍文案（SPEC-S0 v3 欠账，裁定 五）。

---

## 五、登记表 `S0CategoryPageMetrics`（42）

| 分组 | 常量 = 值 |
|---|---|
| 网格（v2 已登记 5，与 SPEC-S0 v2 第 633～637 行逐值相等） | `gridColumns: Int = 3`、`gridItemSpacing = 4`、`gridCellCornerRadius = 10`、`gridSizeLabelFontSize = 11`、`gridCheckSide = 22` |
| 页面边距 2 | `pageHorizontalInset = 20`、`textHorizontalInset = 24` |
| 大标题 6 | `titleTopSpacing = 12`、`titleFontSize = 30`、`titleLetterSpacing = -0.7`、`titleLineHeight = 34`、`titleDotSide = 10`、`titleDotSpacing = 10` |
| 副行 3 | `subtitleFontSize = 14`、`subtitleOpacity: Double = 0.55`、`subtitleTopSpacing = 4` |
| 常驻行 3 | `pinnedRowTopSpacing = 12`、`pinnedRowFontSize = 13`、`pinnedRowOpacity: Double = 0.60` |
| 网格位置 2 | `gridTopSpacing = 12`、`gridBadgeInset = 6` |
| 体积标签 4 | `gridSizeLabelBackgroundOpacity: Double = 0.50`、`gridSizeLabelCornerRadius = 7`、`gridSizeLabelPaddingHorizontal = 6`、`gridSizeLabelPaddingVertical = 2` |
| 时长角标 4 | `gridDurationFontSize = 11`、`gridDurationGlyphSpacing = 3`、`gridDurationShadowRadius = 4`、`gridDurationShadowOpacity: Double = 0.70` |
| 勾 3 | `gridCheckRingWidth = 1.5`、`gridCheckRingOpacity: Double = 0.90`、`gridCheckUnselectedFillOpacity: Double = 0.25` |
| 选中外圈 1 | `gridSelectedRingWidth = 2` |
| 主按钮 8 | `ctaBottomInset = 42`、`ctaHeight = 52`、`ctaCornerRadius = 26`、`ctaFontSize = 17`、`ctaShadowYOffset = 10`、`ctaShadowRadius = 30`、`ctaShadowOpacity: Double = 0.45`、`ctaDisabledOpacity: Double = 0.35` |
| 渐隐 1 | `fadeHeight = 190` |

未写类型的均为 `CGFloat`。42 个名字在类别页文件里各被引用 ≥ 1 次（断言 6 逐个核）。

---

## 六、占位值登记

本卡**无**标定出厂值变更：`S2CalibrationConfiguration.schemaVersion` 保持 **7**（`static let schemaVersion = 7`，`S2Calibration.swift` 不在 diff 内）；`S0ScanRules.cacheSchemaVersion` 保持 **1**（`S0ScanRules.swift` 不在 diff 内）；`S0HomeMetrics` 仍 52、`S0ScanRules` 仍 7 个常量行。新增的 42 个类别页登记值是视觉登记制常量，不进 `S2CalibrationConfiguration`、不上标定面板。
