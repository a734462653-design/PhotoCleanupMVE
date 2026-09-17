# IC-155 自验报告

## 一、结论（先行）

- **三个子项都已交付**，顺序 A → B → C，各自独立 commit：A `9661494`（`coverAssetID` 进模型、`S0CategoryAsset` 进 `Core/`、聚合器产出封面）、B `115263a`（协议加 `categoryAssets(_:)`，真实服务与桩各自实现）、C `4e3e6c8`（首页类别行接真封面，`ThumbnailView` 加 `showsPlaceholderGlyph`）。卡内声明的四个可摘取单元（A、A→B、A→C、A→B→C）在克隆仓库里逐个 `cherry-pick` 实证无冲突（`change-list.md` 第一节）。
- **CI #311（run id `35175217168`，attempt 1）一次绿**：12 个步骤（含 Set up job／Complete job）全 success、真实退出码 **0**、**833 项 0 失败、1 个 launch**（`Test Suite 'All tests' started` 1 次、无宿主重启）、目的地 `OS:26.2, name:iPhone 16`、IPA **1623099 字节**、SHA-256 `6022ca47139cdd57d97e8cb9e53df1ebcea600dcf160955b2091206624f684a8`、分段耗时「模拟器启动 100 s；xcodebuild test 438 s；总 540 s」。项数对账 **824 + 9 = 833** ✔。CI 预算 3 次只用 1 次。
- **断言 1～9 全部 `passed`**（第五节逐条给函数名与耗时）。断言 9 的探针在 CI 上实测 `probeAppeared=false`，**带封面一态已装载**，两态 `sizeThatFits` 均为 361×78——该项已覆盖，不标「未覆盖」。IC-147 的 16 项、IC-148 的 14 项（含 K1 改口径的断言 14）、IC-151 的 8 项、IC-153 的 13 项（含 K2 改口径的断言 2 与未改的断言 6、7）逐条 `passed`。
- **G882～G884 满足，G885 满足**（第九节）。合并提交与合并后 `main` 运行（G886）在合并后回填（第十二节）。
- **卡内有五处条文冲突、前提不成立或 needle 空转（第 7.1～7.5 条），另有三处实现取舍（第 7.6～7.8 条），都已按更具体的条款或卡内兜底条款落实，请决策会话追认**。**没有一处改变卡外的产品行为**；影响交付形态的是两处：桩的合成列表不是严格等差（第 7.3 条，整数等差在 17 行剧本数据中的 8 行上凑不出精确总和），断言 9 的「带封面一态」改为先用探针实测离屏量尺寸会不会触发 `onAppear` 再决定装不装载（第 7.4 条，卡内引为先例的 `testIC069R1b…` 实际没有装载过 `ThumbnailView`）。
- **人工判定项 H76 六条原样保留给 Lynn**（第十三节），执行端不代为下结论。封面是不是真机上最大的那一张、iCloud 优化储存时的空槽、滚动与切 tab 时不闪不串，**模拟器上一律未覆盖**（测试宿主与 CI 相册都取不到图，陷阱 1、24）。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260916-155-category-data-and-cover.md` |
| 规格 | SPEC-S0 v2（`SPEC-S0-20260916_v2.md`，本机 `sha256sum` = `8a8e222a7f203c6c92dc8e755338cded8673f7de76c7b6290da696d4058d6f44`，与 CLAUDE.md 基线行一致） |
| 基线 `main` | `51b4b9564bc5e7f0bb371bda5c2946b7efd6283f` |
| 开工核对 1 | `git merge-base --is-ancestor 20a19df main` 退出码 **0** ✔ |
| 开工核对 2 | `git ls-remote origin refs/heads/main` = `51b4b9564bc5e7f0bb371bda5c2946b7efd6283f` = 本地 ✔ |
| 开工核对 3 | `git status --porcelain` **空** ✔（纪律 8） |
| 分支 | `feature/ic-155-category-data-and-cover`（自 `51b4b95` 切出） |
| 分支 tip（代码） | `4e3e6c8b22f2321cd43cc425df139756d63fe3b7` |
| 现状基数 | 824 项（CI #310 attempt 2）→ 本卡 **833** 项 |
| `schemaVersion` | **7，未动**；`S0ScanRules.cacheSchemaVersion` **1，未动** |

**惯例 13／37 复核**（卡内「事实基础」与「定位坐标」两表逐项在 `51b4b95` 上实读）：`S0CategorySnapshot` `S0StateMachine.swift:84-106`、显式 init `:90-100`；产品侧构造点 11 处（`S0ScanClassifier.swift:215` + 桩 `:92,98,104,110,116,142,148,154,160,166`）；测试侧 21 处（IC-147 的 15 处行号、IC-148 `:1062,1071,1080`、IC-153 `:267,273,279`）逐行一致、全部只用四个标签；聚合器 `:183-232`、循环 `:194`、排除 `:199-203`；服务 `records` `:70`、`libraryIdentifiers` `:71`、`revision` `:78`、`MemoizedSnapshot` `:85`、`withState` `:472`、空扩展 `:519`；协议 `S0View.swift:10-20`、四个要求 `:12／14／16／19`；类别行 `S0CategoryRow.swift:100-104`、`cover` `:125-138`、注释 `:96-99`；构造点 `S0View.swift:497-500`；`ThumbnailView.swift` 88 行、`isNetworkAccessAllowed = false` 在 `:62`、唯一调用者 `S3View.swift:792`；`S0HomeMetrics` 52 个、`categoryCoverSide` `:134`、`categoryCoverCornerRadius` `:137`；`categoryCoverPlaceholderRingOpacity` 在 `PhotoCleanupMVE/`、`PhotoCleanupMVETests/` 内 **0** 命中；`s0.` key 32；pbxproj 最大 id `…059`／`…056`——**全部一致**。两处出入：`isExcludedFromCategories` 声明行实在 `:152`（卡写 `:153`，不影响落点）；**断言 9 引为先例的 `S2CalibrationHarnessTests.testIC069R1bPresentationToggleKeepsThumbnailViewsAlive` 并未装载 `ThumbnailView`**——它给缩略条传的是 `stripItemContent: { _ in AnyView(Color.clear.onAppear { … }) }`（`:8213-8217`），`ThumbnailView` 在 `51b4b95` 上唯一的构造点就是 `S3View.swift:792`，从未进过测试宿主（第 7.4 条）。

**范围边界**：11 个路径全在白名单内（`change-list.md` 第二节）；不得触碰清单内的文件两侧 SHA-256 相同（第九节 G882）；`App/`、`Scripts/`、`.github/`、`Features/S1～S5` 目录 diff 为空。

---

## 三、实现要点

### 3.1 子项 A：模型字段与封面生产

- `S0CategorySnapshot` 加 `let coverAssetID: String?`，显式 init 末尾 `coverAssetID: String? = nil`（裁定 一）。`S0CategoryAsset`（`id`／`byteCount`／`isVideo`／`duration`，`Equatable, Sendable, Identifiable`）放在 `S0CategorySnapshot` 之后、`S0LedgerEntry` 之前（M2）。状态机类一字未动（M3）。
- 聚合器在既有 `for identifier in asset.hits` 循环里、计数与字节累加之后跟踪封面：「体积更大，或同体积且标识更小」即替换。候选集与 `candidateCount` 出自同一循环，排除条件（未解析、`D_全部`、账本、无归属）天然同源；输入顺序无关。零新规则常量、零新数值字面量。
- 桩十处构造加 `coverAssetID:`，取值在 A 内定死：计数 > 0 给 `stub.<rawValue>.1`，否则 nil（A3）。

### 3.2 子项 B：读接口

- 协议要求 `func categoryAssets(_ id: S0CategoryIdentifier) -> [S0CategoryAsset]` 插在 `advanceScan()` 与 IC-153 钩子之间（P1）。
- 真实服务（V1，只增不删）：`D_全部` 锁外先取；`withState` 内一次遍历 `records`——`libraryIdentifiers` 过滤、条目 `classified(id:)`、与聚合器同一组条件（`!isUnresolved`、`!isExcludedFromCategories(_, pending, ledger: [])`、`primaryCategory != nil`、`hits.contains(id)`）、投影四字段；锁外排序（体积降序、同体积标识升序）。首项因此恒等于聚合器给的 `coverAssetID`，项数恒等于 `candidateCount`。不发源请求、不记忆化。
- 桩：取当前剧本快照里的该类别给确定性合成列表（第 7.3 条）；失败剧本与无项目类别给空列表。

### 3.3 子项 C：封面接线

- `ThumbnailView` 加 `var showsPlaceholderGlyph: Bool = true`；无图分支 `else if showsPlaceholderGlyph { 原样 } else { Color.clear }`（第 7.7 条）。取图逻辑一字未动，禁网络不变。
- `S0CategoryRowView` 加 `let coverAssetID: String?` 与 `@Environment(\.displayScale) private var displayScale`；`cover` 改 `ZStack { 描边空槽; if let coverAssetID { ThumbnailView(…, showsPlaceholderGlyph: false) } }`，外层框与无障碍隐藏保留。有图时同边长同圆角的图盖住描边；nil 或取不到图时只剩描边空槽。
- `S0View` 只改构造点：传 `coverAssetID: category.coverAssetID` 并加 `.id(category.coverAssetID)`（P2，陷阱 17）。

---

## 四、CI 与项数对账

### 4.1 #311 的完整事实

| 项 | 值 |
|---|---|
| 运行编号 | **#311** |
| run id | `35175217168`，`run_attempt` **1**，事件 `push` |
| check-run id | `105055327938`（从本次运行的 jobs 现取） |
| 被测提交 | `4e3e6c8b22f2321cd43cc425df139756d63fe3b7`（分支 tip，含全部三个代码提交） |
| 结论 | **success**；12 个步骤（含 Set up job／Complete job）全 success |
| 作业时长 | 02:39:10Z → 02:52:31Z（13 分 21 秒，作业级时限 30 分钟之内） |
| XCTest 步骤 | 02:39:56Z → 02:48:58Z（9 分 2 秒，步骤级时限 25 分钟之内）；步骤以 `exit "$test_status"` 原样退出、结论 success，且日志有 `XCTest 已全部通过。`（`test-xcode.sh` 只在 xcodebuild 退出码为 0 时打印）⟹ 真实退出码 **0** |
| 工具链 | `Xcode 26.3`，`Build version 17C529` |
| 模拟器 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| 执行摘要 notice | `Executed 833 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 833 tests / 0 failures` |
| 分段耗时 notice | `模拟器启动 100 s；xcodebuild test 438 s；总 540 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1623099，SHA-256=6022ca47139cdd57d97e8cb9e53df1ebcea600dcf160955b2091206624f684a8` |
| artifact | `PhotoCleanupMVE-unsigned-4e3e6c8b22f2`，id `10478263786`，zip 1623269 字节 |
| 注解 | 仅上述 3 条 notice；error／warning **0** 条 |

### 4.2 实证行（整包日志 zip 241 678 字节，`unzip -tq` 校验通过后解析「运行 XCTest」步骤日志；先剔 `##[` 注解回显与 `[36;1m` 脚本源码回显，陷阱 25）

- 目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- `Executed 833 tests, with 0 failures (0 unexpected) in 40.307 (43.485) seconds`；`** TEST SUCCEEDED **`
- `Test Suite 'All tests' started` **1** 次；`Restarting after unexpected exit` **0** 次（无宿主崩溃重启）
- 唯一 `Test Case … passed` **833**、`failed` **0**，无重复身份
- `.swift:<行>: error` 形状的行 **0**
- `IC155C-SIZING probeAppeared=false coveredHosted=true placeholder=361.00x78.00 covered=361.00x78.00`（02:47:17Z）
- 计时脆弱用例 `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` passed（5.099 s）

### 4.3 项数对账

| 来源 | 项数 |
|---|---|
| `main` 基数（CI #310 attempt 2） | 824 |
| 本卡新增（`IC155CategoryDataAndCoverTests`，9 个 `func test`；本机 `grep -n "func test"` 9 行，无注释行干扰） | +9 |
| 期望 | **833** |
| #311 唯一 passed 行 ∪ failed 行 | **833**（833 ／ 0） |

### 4.4 CI 预算

3 次预算用 **1** 次。推 CI 前的本机预验证见第八节（Python 移植 370 项，首轮抓到一处我自己写的必红——断言 7 的正对照，第 7.5 条）；另请一个只看「会不会编译失败、有没有必红断言」的独立会话读了三次提交的全部 diff，结论**无阻断项**，只标出两类低风险：`S0ScanClassifier.swift:215-218` 与测试 helper `zip(...).allSatisfy` 的类型检查耗时（操作数类型都已确定），以及断言 9 若探针被触发则带封面一态会跳过装载（须核日志标记，见第五节断言 9 行）。

---

## 五、逐条验收门禁与测试函数名（#311，均 `passed`）

| 断言 | 子项 | 测试函数 | 耗时（s） | 钉住的结果 |
|---|---|---|---|---|
| 1 | A | `testIC155A_CoverIsLargestCandidateWithDeterministicTie` | 0.003 | IC-153 断言 2 同型夹具 + 两条同为 5 MB 的截图（b 先到）：封面 大视频／录屏 = `recording`、截图 = `shot-a`（并列取标识升序）；截图计数 3、字节 13 MB；`shot-a` 进 `D_全部` → 截图封面 `shot-b`、计数 2；账本清空的正对照 → 大视频封面变 200 MB 的 `ledger-video`；四条候选全改未解析 → 三类计数 0、封面 nil |
| 2 | A | `testIC155A_CoverIsOrderIndependent` | 0.002 | 九条资产、三类各有并列且标识最小者不在原序首位；五种两两不同的顺序喂聚合器，封面恒为 `big-a`／`rec-y`／`shot-a`，快照逐字段相等 |
| 3 | A | `testIC155A_DefaultedFieldKeepsExistingConstructionsUntouched` | 0.024 | 剔注释 `S0StateMachine.swift`：声明行 1、默认值形参 1；剔注释 IC-147／IC-148 测试文件 `coverAssetID:` 各 0、`S0CategorySnapshot(` 15／3（正对照）；不带标签构造得 nil、与带标签者不相等；桩就绪剧本五类封面 = `stub.<rawValue>.1`，无项目剧本与扫描第 0 步全 nil |
| 4 | B | `testIC155B_CategoryAssetsMatchSnapshotAndOrder` | 0.022 | 夹具源十二条跑完整遍：三类列表逐条等于期望顺序（`v-big-1, v-big-2, v-big-3, rec-big`／`rec-big, rec-a, rec-b`／`shot-1, shot-2, shot-3`）；条数 = `candidateCount`、总字节 = `candidateByteCount`、首项 = `coverAssetID`、有序；`isVideo` 与媒体类型一致、`duration` 与夹具一致；并列存在、四个视频时长互异的前置 |
| 5 | B | `testIC155B_CategoryAssetsExcludePendingAndUnresolvedAndTrackRevision` | 0.028 | 未解析截图不在任何列表、截图计数 3；`v-big-1` 进 `D_全部` → 从列表消失、快照计数 4 → 3、封面与首项顺延到 `v-big-2`；同属两类的 `rec-big` 进篮 → 两个列表一起少它；移出 → 回到首位；`duplicate`／`similar` 空；库内删 `shot-2` 再扫一遍 → 列表 `[shot-1, shot-3]`、计数 2；每一步三类「条数 = 计数、总字节相等、首项 = 封面、有序」 |
| 6 | B | `testIC155B_StubListsAreDeterministicAndConsistent` | 0.057 | 五剧本 × 步数 0～4 × 五类：两台同参桩逐项相等、同一台连取相等；37 个非空列表各「条数 = 计数、总和 = 字节、首项 = 封面、有序、标识不重、`isVideo` 与类别一致」；其余为空；钩子计数 0；读取失败剧本五类全空 |
| 7 | B | `testIC155B_ProtocolGainsOneRequirementAndKeepsHookLine` | 0.015 | 剔注释 `S0View.swift`：要求签名 1、`onSnapshotDidChange` 1、钩子行 1、协议行 1；剔注释服务文件：`PHAsset.fetchAssets(with: nil)` 1、`fetchAssets(withLocalIdentifiers` 0、`withLocalIdentifiers` 0（第 7.5 条）、要求签名 1；桩要求签名 1；缩略图视图 `withLocalIdentifiers` > 0（needle 正对照） |
| 8 | C | `testIC155C_CoverSlotDelegatesToThumbnailViewWithoutPhotoKit` | 0.011 | 剔注释 `S0CategoryRow.swift`：`ThumbnailView(` 1、`showsPlaceholderGlyph: false` 1、`categoryCoverSide` 3、`categoryCoverCornerRadius` 2、`displayScale` ≥ 2、`import Photos` 0、`PHImageManager` 0；`cover` 切片 `if let coverAssetID` 1、`strokeBorder` ≥ 1、`.fill(` 0；剔注释 `S0View.swift`：传参 1、`.id` 1；剔注释缩略图视图：默认值声明 1、禁网络 1、`Color.clear` ≥ 1、`import Photos`／`PHImageManager` > 0（needle 正对照）；剔注释 `S3View.swift`：`ThumbnailView(` 1、`showsPlaceholderGlyph` 0 |
| 9 | C | `testIC155C_RowBuildsForAllCoverStates` | 0.150 | 探针实测离屏 `sizeThatFits` 路径不触发 `onAppear`（`probeAppeared=false`）；无封面与带封面两态都离屏装载，`sizeThatFits` 高度 = `categoryRowHeight` 78、两态相等（日志 `placeholder=361.00x78.00 covered=361.00x78.00`）；不断言像素（陷阱 23） |

**既有相关用例（#311 逐条 `passed`）**：`IC147S0BehaviorTests` 16／16（含 `testIC147CAssertion09NoPhotoKitSymbolInS0`、`testIC147DAssertion12StubIsDeterministic`、`testIC147AAssertion03RouteBranchesOtherThanS1AreByteIdentical`）、`IC148S0VisualTests` 14／14（含 K1 所在的 `testIC148DAssertion14CoverSlotIsEmptyNotFaked`、零裸数的 `testIC148AAssertion03NoBareNumbersInViewBodies`、PhotoKit 零命中的 `testIC148AAssertion04ReusesAmbientWithoutCopyingOrTouchingPhotoKit`）、`IC151AmbientFixedColorTests` 8／8（含 `testIC151D_S0BehaviorCallSitesUnchanged`、`testIC151A_S0GlassSurfaceHasNoImageLayer`）、`IC153ScanServiceTests` 13／13（含 K2 所在的 `testIC153A_AggregationDedupesHeroButNotCategories`，未改的 `testIC153B_CancelMidwayThenResumeDoesNotRefetch`、`testIC153B_CompleteCacheWithoutChangesSkipsByteFetch`、`testIC153D_StubConformsAndNeverFiresHook`）；另 `testIC134B_CoverRequestPixelSizeFollowsDisplayScale`（`ThumbnailView.targetPixelSize`）与 `testIC069R1bPresentationToggleKeepsThumbnailViewsAlive`（0.167 s）passed。

---

## 六、既有断言改口径（裁定 五）

| 断言 | 旧 | 新 | 结果 |
|---|---|---|---|
| IC-148 断言 14（K1） | `occurrences(of: "coverAssetID", in: strippedSource(S0StateMachine)) == 0` | `occurrences(of: "let coverAssetID: String?", in: 同) == 1`，注释改「生产者已在（IC-155 裁定 一）」 | #311 `testIC148DAssertion14CoverSlotIsEmptyNotFaked` passed |
| IC-148 断言 14 的七个 needle 与 `cover` 切片三条 | 不变 | 不变 | 三个视图文件原文（含注释）七个 needle 各 0；`cover` 切片内 `categoryCoverSide` 3、`categoryCoverCornerRadius` 2、`strokeBorder` 1、`.fill(` 0（Python 预验证） |
| IC-153 断言 2（K2） | 三条期望不带 `coverAssetID` | `.bigVideo` → `"recording"`、`.screenRecording` → `"recording"`、`.screenshot` → `"screenshot"` | #311 `testIC153A_AggregationDedupesHeroButNotCategories` passed |
| IC-153 断言 2 其余（`:318` 等）、断言 6（`:570`）、断言 7（`:608`、`:624`） | 快照相等比较 | **未改** | **照绿**：#311 `testIC153A_AggregationDedupesHeroButNotCategories`、`testIC153B_CancelMidwayThenResumeDoesNotRefetch`、`testIC153B_CompleteCacheWithoutChangesSkipsByteFetch` 均 passed。理由：两侧都经同一聚合器、同一并列规则。样本库（`sampleLibrary`）里截图（各 2 MB）与小录屏（各 20 MB）两类有同体积并列，大视频（120／124／128 MB）无并列；Python 对 10 条与 12 条两个样本各取 400 个排列 + 200 次随机打乱喂聚合器，快照逐字段恒等。封面：大视频 `asset-8/L0/001`；录屏 `asset-2/L0/001`（10 条）或 `asset-10/L0/001`（12 条，字典序 `asset-10…` < `asset-2…`）；截图 `asset-1/L0/001` |
| IC-147／IC-148／IC-153 其余 | — | **一条未改** | IC-147 文件两侧 SHA-256 相同；IC-148 文件 diff 只有 K1 一个 hunk（`@@ -1028,11 +1028,15 @@`）；IC-153 文件 diff 只有 K2 一个 hunk（`@@ -268,19 +268,22 @@`） |

---

## 七、卡内问题与按结果落实的地方（逐条写明，请决策会话追认）

### 7.1 裁定 一「21 处测试构造点与 10 处桩构造点一行不动」与 A3／S1、K2 字面冲突 → 照 A3／S1／K2 做

- 裁定 一的句子是为「init 末尾带默认值」给理由：加字段后既有构造**不必**改就能编译。但同一张卡的 A3／S1 明文要求「桩十处构造加 `coverAssetID:`」，K2 明文要求 IC-153 断言 2 的三处构造加 `coverAssetID:`，断言 6（首元素 id == 该行 `coverAssetID`）只有桩构造点真改了才能成立。
- 落实：桩十处与 IC-153 三处照 A3／K2 加；IC-147 的 15 处与 IC-148 的 3 处一行未动（断言 3 源码扫描 + 两侧 SHA／单 hunk 实证）。

### 7.2 断言 3「`IC147S0BehaviorTests.swift`、`IC148S0VisualTests.swift` 两个文件与 `51b4b95` 逐字节相同」与 K1 冲突 → 按意图实证

- K1 改的正是 `IC148S0VisualTests.swift:1031-1035`，该文件按字面不可能逐字节相同；卡内同一句括号里「IC-148 那处是字符串字面量」指的也正是 K1 新写的 needle——卡本身预期了 K1 的改动。
- 落实（①）：`IC147S0BehaviorTests.swift` 两侧 SHA-256 **相同**（`6ec277fc…850e`）；`IC148S0VisualTests.swift` 相对 `51b4b95` **只有 K1 一个 hunk**（`@@ -1028,11 +1028,15 @@`，6 行 +、2 行 -），三处构造点 `:1062／1071／1080` 在 hunk 之外、原文未动。测试层照卡：剔注释与字面量后两文件 `coverAssetID:` 各 0，另加正对照 `S0CategorySnapshot(` 15 与 3。

### 7.3 裁定 二「字节按 `candidateByteCount` 等差递减且总和等于 `candidateByteCount`」在整数上不总能成立 → 等差 + 余数前置

- ①（Python 按同余条件逐行判定）：n 项、公差 d、总和 B 的整数等差数列存在，当且仅当存在 d ≥ 1 使 `(B + d × n(n−1)/2) ≡ 0 (mod n)`。17 行有项目的剧本数据中 **8 行不存在**：

  | 剧本行 | n | B |
  |---|---|---|
  | 就绪 截图 | 84 | 560 000 000 |
  | 就绪 录屏 | 9 | 1 920 000 000 |
  | 就绪 重复 | 46 | 730 000 000 |
  | 就绪 相似 | 118 | 1 150 000 000 |
  | 扫描第 1／2／3／4 步 截图 | 21／42／63／84 | 140 000 000 × 步数 |

- 落实：公差 `d = B ÷ n²`（整除），`base = (B − d × n(n−1)/2) ÷ n`，余数 `r < n` 逐一加到最大的 r 条上。相邻差为 d 或 d + 1，**严格递减、总和恰为 B**；各行 d 最小为 79 365（> 0），不出现同体积并列，序号 1 即最大的一条、等于 A 定死的封面标识。例：就绪截图首条 9 960 315、末条 3 373 019 字节，相邻差 {79 365, 79 366}；就绪大视频首条 583 333 332、末条 216 666 668 字节。
- 视频类（大视频、录屏）的合成时长取「字节 ÷ 10 000 000」（桩内私有常量，就绪大视频 58 s → 21 s），只为 5.2b 的时长角标有数可画；不是产品登记值。

### 7.4 断言 9 引用的先例不成立 → 用探针在 CI 上实测，再决定带封面一态装不装载（卡内兜底条款）

- ①：卡写「`S2CalibrationHarnessTests.testIC069R1b…` 已在宿主内装载过 `ThumbnailView`，预期不会」。实读 `51b4b95`：该用例的缩略条内容是 `Color.clear`，`ThumbnailView` 从未在测试宿主里构造过。带封面的 `S0CategoryRowView` 一旦真被渲染，`ThumbnailView.onAppear` 就会在测试宿主里 `PHAsset.fetchAssets(withLocalIdentifiers:)`（①，`ThumbnailView.swift:44`、`:52-55`）。③ 推测（未取证）：CI 上新启动的模拟器照片授权为「未决定」，这次取数可能弹系统授权询问并让测试宿主失去活跃态，波及后面的计时敏感用例（`testIC063…` 取 `connectedScenes.first` 挂窗口，`S2CalibrationHarnessTests.swift:4112`）。
- 落实：断言 9 先让一个 `Color.clear.frame(10×10).onAppear { probeAppeared = true }` 走**同一条**离屏 `UIHostingController.sizeThatFits(in:)` 路径并转 0.05 s run loop；再装载无封面一态核行高；**探针未被触发才装载带封面一态**核行高并与无封面相等，被触发则该态只构造不装载，日志打 `IC155C-SIZING probeAppeared=true coveredHosted=false`，本报告标「未覆盖」（卡内原文「该态只构造不装载、在报告标「未覆盖」，不为它改产品」）。
- 实测（#311 日志，02:47:17Z）：`IC155C-SIZING probeAppeared=false coveredHosted=true placeholder=361.00x78.00 covered=361.00x78.00`。即在 iOS 26.2 模拟器上，离屏 `UIHostingController.sizeThatFits(in:)` 加 0.05 s run loop **不触发** `onAppear`（②，本次样本）；带封面一态因此已装载、行高 78，**该项已覆盖，不标「未覆盖」**。同一次运行里 `testIC063…` passed（5.099 s）。

### 7.5 断言 7 的 needle `fetchAssets(withLocalIdentifiers` 在仓内真实写法上会空转 → 另扫实参标签

- ①：仓内唯一按标识取数的写法（`ThumbnailView.swift:52-55`）是 `PHAsset.fetchAssets(` 换行缩进再写 `withLocalIdentifiers:`，连写 needle 在它上面命中 **0**。拿它做「服务文件 == 0」永远成立，钉不住任何东西（惯例 41 的同类：引用 needle 前先 grep 它确实存在）。我给这条写的正对照（同 needle 在缩略图视图里 > 0）被本机 Python 模拟当场判红，没有烧 CI。
- 落实：卡给的 needle 原样保留（== 0），另加 `withLocalIdentifiers` == 0，正对照改为 `withLocalIdentifiers` 在缩略图视图里 > 0（实测 1）。

### 7.6 子项 C 的断言放在测试类最前 → 让 A→C 真能不经 B 摘取

卡内摘取关系写 A→C 可摘取，又要求「新测试文件在 A 创建、B 与 C 各自追加」。B 追加在断言 3 之后与文件末尾；C 若也追加在这两处附近，三方合并会判冲突，A→C 就只在「语义依赖」上成立。故 C 的两条断言与 `coverSlice(_:)` helper 放在类首，文件内路径用局部常量（不依赖 B 加的静态路径）。克隆仓库实测 A→C 无冲突，树对象 `e516a993…2552`（`change-list.md` 第一节）。测试执行顺序与文件内位置无关。

### 7.7 T1 写法

卡面是「无图分支 `if showsPlaceholderGlyph { 原样 } else { Color.clear }`」，实现为 `} else if showsPlaceholderGlyph { 原样 } else { Color.clear }`，逻辑等价，系统图标四行不必改缩进。

### 7.8 V1 多带一个条件

V1 列的是 `isExcludedFromCategories` + `isUnresolved` + `hits.contains(id)`；实现另带聚合器同位置的 `primaryCategory(for:) != nil`，使两处条件逐项同形。对三个识别类别，`hits.contains(id)` 已蕴含该条件，结果不变。

---

## 八、Python 预验证比对清单（推 CI 前，本机）

`<scratchpad>/simbehavior.py`、`simscan.py`、`sim_checks.py`（+ `_b`、`_c`）手工移植：分类命中、去重归属、排除规则、聚合器（含封面跟踪）、服务 `categoryAssets` 的过滤与排序、桩合成列表，以及 `strippedSource`／`occurrences`／`numericLiterals`／`localizationKeys`／切片五个扫描 helper。**移植与 Swift 实现的任何分歧都是移植偏差，下表是②样本观察，不构成测试会通过的证据；权威结论只取 CI。** 三个阶段分别跑：A 244 项、A+B 338 项、A+B+C **370 项，0 失败**（B 首轮 337／338，唯一一条红即第 7.5 条）。

### 8.1 断言 1（夹具 → Python → Swift 期望 → CI）

夹具：`recording`（视频 886×1920、`ScreenRecording_…`、150 MB）、`screenshot`（截屏 3 MB）、`plain-photo`（4 MB）、`pending-screenshot`（截屏 2 MB，在 `D_全部`）、`ledger-video`（视频 200 MB，在账本）、`unresolved-video`（未解析）、`shot-b`／`shot-a`（截屏各 5 MB，b 先到）。

| 情形 | Python | Swift 期望 | CI |
|---|---|---|---|
| 类别顺序 | bigVideo, screenRecording, screenshot | 同 | passed |
| 封面 大视频／录屏／截图 | recording／recording／**shot-a** | 同 | passed |
| 截图 `candidateCount`／`candidateByteCount` | 3／13 000 000 | 同 | passed |
| `shot-a` 进 `D_全部` | 截图封面 **shot-b**、计数 2；大视频封面仍 recording | 同 | passed |
| 账本清空（正对照） | 大视频封面 **ledger-video**；录屏封面 recording | 同 | passed |
| 四条候选全改未解析 | 三类计数 [0,0,0]、封面 [nil,nil,nil] | 同 | passed |

### 8.2 断言 2

夹具九条：`big-c`／`big-a`／`big-b`（视频各 300 MB）、`rec-z`（前缀命中 40 MB）／`rec-y`（分辨率 2622×1206 命中 40 MB）、`shot-b`／`shot-a`（各 5 MB）、`small-shot`（1 MB）、`plain-photo`。五种顺序：原序、倒序、左旋 2、左旋 5、偶位在前奇位在后。

| 项 | Python | Swift 期望 | CI |
|---|---|---|---|
| 五种顺序两两不同 | 5 | 5 | passed |
| 封面 | big-a, rec-y, shot-a | 同 | passed |
| 五种顺序快照逐字段相等 | 是（另随机打乱 200 次恒等） | 是 | passed |

### 8.3 断言 4（夹具源跑完整遍）

夹具十二条：`v-big-2`（250 MB、61.5 s）、`v-big-1`（250 MB、42.25 s）、`v-big-3`（180 MB、30 s）、`rec-big`（前缀命中 120 MB、95.5 s，同属大视频与录屏）、`rec-b`（分辨率命中 30 MB、20 s）、`rec-a`（前缀命中 30 MB、21.75 s）、`shot-2`／`shot-1`（截屏各 4 MB）、`shot-3`（2 MB）、`photo-plain`（3 MB）、`shot-unresolved`（字节取不到）、`video-small`（50 MB、不属任何类别）。

| 类别 | Python 列表 | 计数／总字节／封面 | Swift 期望 | CI |
|---|---|---|---|---|
| bigVideo | v-big-1, v-big-2, v-big-3, rec-big | 4／800 000 000／v-big-1 | 同 | passed |
| screenRecording | rec-big, rec-a, rec-b | 3／180 000 000／rec-big | 同 | passed |
| screenshot | shot-1, shot-2, shot-3 | 3／10 000 000／shot-1 | 同 | passed |
| 投影 | `isVideo` 与媒体类型一致、`duration` 与夹具一致；大视频前两条均 250 MB；四个时长互不相同 | — | 同 | passed |

### 8.4 断言 5

| 步骤 | Python | Swift 期望 | CI |
|---|---|---|---|
| 未解析截图 | 不在任何列表；截图计数 3 | 同 | passed |
| `v-big-1` 进 `D_全部` | 大视频计数 3、封面 v-big-2、列表首项 v-big-2；三类「计数 = 列表长、总字节相等、首项 = 封面、有序」 | 同 | passed |
| 再加 `rec-big` | 大视频 [v-big-2, v-big-3]、录屏 [rec-a, rec-b]；三类一致性同上 | 同 | passed |
| 移出 `v-big-1` | 大视频首项 v-big-1；一致性同上 | 同 | passed |
| `.duplicate`／`.similar` | 空、空 | 同 | passed |
| 库内删 `shot-2` 后再扫一遍 | 截图 [shot-1, shot-3]、计数 2；一致性同上 | 同 | passed |

### 8.5 断言 6（桩）

五个剧本 × 步数 0～4 × 五个类别：两台同参桩逐项相等；有项目的列表 37 个（就绪 5 类 × 5 步 + 扫描第 1～4 步各 3 类），每个「条数 = 计数、总和 = 字节、首项 = 封面、严格递减、标识不重、`isVideo` 与类别一致」；其余为空。Python 与 Swift 期望一致；#311 `testIC155B_StubListsAreDeterministicAndConsistent` passed。

### 8.6 源码扫描口径（断言 3、7、8 与既有断言）

| 口径 | Python 实测 |
|---|---|
| 断言 3：剔注释 `S0StateMachine.swift` 内 `let coverAssetID: String?`／`coverAssetID: String? = nil` | 1／1 |
| 断言 3：剔注释 IC-147／IC-148 测试文件内 `coverAssetID:`；`S0CategorySnapshot(` | 0、0；15、3 |
| 断言 7：剔注释 `S0View.swift` 内要求签名／`onSnapshotDidChange`／钩子行／协议行 | 1／1／1／1 |
| 断言 7：剔注释服务文件 `PHAsset.fetchAssets(with: nil)`／`fetchAssets(withLocalIdentifiers`／`withLocalIdentifiers`／要求签名；桩要求签名；缩略图 `withLocalIdentifiers` | 1／0／0／1；1；1 |
| 断言 8：剔注释 `S0CategoryRow.swift` 内 `ThumbnailView(`／`showsPlaceholderGlyph: false`／`categoryCoverSide`／`categoryCoverCornerRadius`／`displayScale`／`import Photos`／`PHImageManager` | 1／1／3／2／4／0／0 |
| 断言 8：`cover` 切片内 `if let coverAssetID`／`strokeBorder`／`.fill(` | 1／1／0 |
| 断言 8：剔注释 `S0View.swift` 内 `coverAssetID: category.coverAssetID`／`.id(category.coverAssetID)`（该文件裸 `coverAssetID` 共 3 次，惯例 41） | 1／1 |
| 断言 8：剔注释缩略图 `showsPlaceholderGlyph: Bool = true`／`isNetworkAccessAllowed = false`／`Color.clear`／`import Photos`／`PHImageManager`；剔注释 `S3View.swift` `ThumbnailView(`／`showsPlaceholderGlyph` | 1／1／1／1／2；1／0 |
| IC-148 断言 3：六个视图体数值字面量 ⊆ {0,1,2}；`S0CategoryRow.swift` 文件级 − {0,1,2} | 全部 ∅；{0.55} |
| IC-153 断言 3：剔注释 `S0ScanClassifier.swift` 数值字面量 − {0,1}；`S0ScanRules.` 引用 | ∅；≥ 3 |
| IC-147 断言 11／IC-148 断言 10：S0 视图文件引用的 `s0.` key；跨前缀 key | 32；仅 `s1.limited.banner` |

`Scripts/check-scan-needle-variant.ps1` 对新测试文件的全部 needle 过审（第十节）。

---

## 九、闸门

### G882（diff 与零改动）

- diff 限于白名单：11 个路径全在表内 ✔。
- 不得触碰清单零改动：`change-list.md` 第二节「零改动实证」表 19 个文件两侧 SHA-256 全部相同 ✔；`App/`、`Scripts/`、`.github/`、`Features/S1～S5` 目录 diff 为空 ✔；其余既有测试文件只有 `IC148S0VisualTests.swift`（K1）与 `IC153ScanServiceTests.swift`（K2）在 diff 内 ✔。
- `S0View.swift` 相对 `51b4b95` 恰两个 hunk ✔：`@@ -14,6 +14,9 @@ protocol S0CleanupDataProviding: AnyObject {`（P1）、`@@ -496,8 +499,10 @@ struct S0View: View {`（P2）。
- `S0LibraryScanService.swift` 只增不删 ✔：`git diff 51b4b95 4e3e6c8 -- PhotoCleanupMVE/Services/S0LibraryScanService.swift` 一个 hunk `@@ -144,6 +144,49 @@ final class S0LibraryScanService {`，`^+` 行 43、`^-` 行 **0**；新增内容即 `categoryAssets(_:)` 一个方法（1 个空行 + 8 行文档注释 + 34 行代码）。
- `App/PhotoCleanupMVEApp.swift`、`S0HomeMetrics.swift`、`S0ScanRules.swift`、`Localizable.xcstrings`、`S3View.swift` 两侧 SHA-256 相同 ✔（值见 `change-list.md`）。

### G883（出厂值与冻结链）

- `S2Calibration.swift` 不在 diff ✔；`schemaVersion` = **7**（`S2Calibration.swift:118`）✔；`S0ScanRules.cacheSchemaVersion` = **1**（`:27`）✔。
- 远端 tip（推送前 `git ls-remote origin`）：`feature/ic-089-nx-edge-bounce` `b368a6caee846e664391b0620350395bfe6fbc7f`、`feature/ic-091-nx-midgesture-handoff` `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`、`feature/ic-092-nx-window-follow` `a7cc1ec727a3a493f5263e688a316cbf4c743562`、`probe/ic-067-screenshot-subtype` `9db02b93eccbb87d126602901807e70823535111`、`probe/ic-125-sentinel-negative` `402cb6e52a11dc89ce2a8351b47314a5fe9185b8`、`probe/ic-137-media-playback` `486bcb769b59eb1146c5a231c7998847206777cc`、`probe/ic-145-scan-service` `d373afc7125104c01acfc296829229090e6871ce`——与卡内七个短 SHA 一一对应 ✔。CI 绿后、合并前（02:55:40Z）再取一次 `git ls-remote origin`：七条 tip 与推送前逐字相同 ✔，远端 `main` 仍为 `51b4b9564bc5e7f0bb371bda5c2946b7efd6283f` ✔。

### G884（「不得打红」清单逐项实测，`<scratchpad>/g884.py`，56 项 0 不符）

| 项 | 实测 | 期望 |
|---|---|---|
| 剔注释 `S0View.swift`：`machine.handle(`／`machine.ingest`／`machine.beginVerification`／`onSnapshotDidChange` | 4／1／1／1 | 4／1／1／1 |
| 同上：`PHAsset`／`hasBootstrapped`／`machine.showsCategoryRows`／`S2AmbientBackdropView()` | 0／3／1／1 | 0／3／1／1 |
| 同上：`scaledToFill`／`Image(uiImage:`／`.blur(`／`Timer`／`asyncAfter`／`sleep(`／`withAnimation(` | 各 0 | 各 0 |
| `S0View.swift` 钩子行 `    var onSnapshotDidChange: (() -> Void)? { get set }` 原文 | 1 处；基线第 19 行 → 本卡后第 22 行（P1 在其上方插了三行） | 逐字不变 |
| `App/PhotoCleanupMVEApp.swift` | 两侧 SHA-256 相同；剔注释 `advanceScan()` 2、`onSnapshotDidChange` 1；`.onAppear` 守卫原文 1；四个路由分支逐字各 1 | 一字不动 |
| `S0HomeMetrics.swift` | 两侧 SHA-256 相同；`\n    static let ` 52 | 52 |
| `S0ScanRules.swift` | 两侧 SHA-256 相同；`static let` 行 7 | 7 |
| `Localizable.xcstrings` | 两侧 SHA-256 相同；`s0.` key 32 | 32 |
| `S0CleanupDataStub.swift` | 声明行 `final class S0CleanupDataStub: S0CleanupDataProviding {` 原文 1；就绪剧本构造 5；剔注释 `onSnapshotDidChange` 只在属性声明 1 处、`onSnapshotDidChange?(` 调用 0 | 行不变、五类、从不触发 |
| 四个 S0 文件（`S0View`／`S0SegmentBar`／`S0CategoryRow`／`S0HomeMetrics`）剔注释：`colorScheme`／`systemBackground`／`UIColor.label`／`.primary`／`Material`／`ultraThin` | 24 格各 0 | 各 0 |

### G885（合并前置）

| 条件 | 实证 | 结果 |
|---|---|---|
| G882～G884 | 本节上文 | ✔ |
| 绿：833 项 0 失败 | #311 执行摘要 notice `Executed 833 tests, 0 failing test case(s), across 1 launch(es)`；步骤日志唯一 passed 833、failed 0 | ✔ |
| 真实退出码 0 | 「运行 XCTest」步骤 success（`exit "$test_status"` 原样退出）+ 日志 `XCTest 已全部通过。` | ✔ |
| 执行摘要 notice | 见上 | ✔ |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | ✔ |
| IPA 字节数与 SHA-256 | 1623099 字节，`6022ca47139cdd57d97e8cb9e53df1ebcea600dcf160955b2091206624f684a8` | ✔ |
| 分段耗时 notice | `模拟器启动 100 s；xcodebuild test 438 s；总 540 s` | ✔ |
| 断言 1～9 逐条函数名 + 日志 `passed` | 第五节 9／9 | ✔ |
| IC-147 16 项、IC-148 14 项、IC-151 与 IC-153 相关用例逐条 `passed` | 16／16、14／14、8／8、13／13（第五节表后） | ✔ |
| pbxproj 撞号扫描 | 登记前（第十一节）与分支 tip 复扫：带注释的对象定义 208 条（206 + 本卡 2）、重复 **0**；`10000000000000000000005A` 全文件 3 次（自身定义、构建文件的 `fileRef`、测试组 children）、`200000000000000000000057` 2 次（自身定义、测试目标 Sources 阶段） | ✔ |
| 工作树净 | 报告提交后 `git status --porcelain` 为空（第十二节） | ✔ |
| `main` 未被他人推进 | 合并前 `git ls-remote origin refs/heads/main` = `51b4b9564bc5e7f0bb371bda5c2946b7efd6283f`（02:55:40Z） | ✔ |

### G886（合并后 `main`）

合并后回填。

---

## 十、本地门禁与真实退出码

均在 `4e3e6c8` 工作树上、以 `powershell.exe -NoProfile -ExecutionPolicy Bypass` 运行（A、B 两个提交前各跑过一轮，结果相同）：

| 门禁 | 退出码 | 摘要 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | 「结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。」 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 目录条目 247、产品源码引用 key 247、用户可见硬编码残留 **0** |
| `Scripts/check-swift-string-structure.ps1 -SelfTest`（IC-149 门禁一） | **0** | 自对照三条 OK；扫描 82 个 .swift，无未闭合字符串、无括号失衡 |
| `Scripts/check-scan-needle-variant.ps1 -SelfTest`（IC-149 门禁二） | **0** | 自对照三条 OK；扫描 40 个测试源文件，无 needle 喂错源码变体 |
| `git diff --check`（及每次提交前 `git diff --cached --check`） | **0** | — |

---

## 十一、pbxproj 撞号扫描与新登记

- 登记前（`9661494` 之前的工作树）：带注释的对象定义 206 条，24 位 id 去重后 0 重复；另有两条无注释的 `700000000000000000000002／3 = {` 是 `TargetAttributes` 里以目标 id 为键的字典，不是新对象。文件引用最大 `100000000000000000000059`、构建文件最大 `200000000000000000000056`；候选 `10000000000000000000005A`、`200000000000000000000057` 全文件 **0** 命中。
- 新登记：`200000000000000000000057 /* IC155CategoryDataAndCoverTests.swift（测试源码） */` → `fileRef = 10000000000000000000005A`；文件引用在测试组 children（紧跟 `IC153ScanServiceTests.swift`）；构建文件在测试目标 Sources 阶段（紧跟 IC-153 那一行）。独立复核另行核对：两个新 id 各自只在定义与一处引用出现，不在应用目标里。

---

## 十二、提交、合并与 SHA 核验

| # | SHA | 内容 |
|---|---|---|
| 1 | `966149402b0bb422eee72cba1a8c91bcb1da5eab` | 子项 A |
| 2 | `115263a33e232408b8c6b46034122d81b239009e` | 子项 B |
| 3 | `4e3e6c8b22f2321cd43cc425df139756d63fe3b7` | 子项 C（CI #311 被测提交） |
| 4 | 本报告提交 | docs：两份报告（报告提交无法写进自身 SHA） |

**报告提交方式（纪律 7）**：采用「同一张卡、同一分支内追加一个 docs 提交」——三个代码提交先推送以触发 CI，#311 的运行编号、IPA 校验与日志实证是推送后才产生的信息，由本报告提交补入；`Reports/**` 在 `paths-ignore` 内，本提交不触发 CI（预期行为）。合并提交 SHA 与 G886 在合并后于 `main` 回填（照 IC-153 `6dec2b18f04ad9c76c232aeadff81cdef116d721` 的先例）。

**40 位 SHA 核验**（报告写完、提交前，`<scratchpad>/verify_shas.py` 抽出两份报告里全部独立的 40 位十六进制串逐个 `git cat-file -e`）：共 **17** 个，**13** 个是提交（`git cat-file -e <sha>^{commit}` 退出码 0：`966149402b0b…`、`115263a33e23…`、`4e3e6c8b22f2…`、`51b4b9564bc5…`、`20a19df6827f…`、`6dec2b18f04a…` 与七条冻结／探针 tip），**4** 个是树对象（`^{commit}` 不适用，改 `git cat-file -e <sha>^{tree}` 退出码 0：`119a3405…`、`7048b3d0…`、`83365e5f…` 分别是 `9661494`／`115263a`／`4e3e6c8` 自身的树，`e516a993…` 是 `git merge-tree --write-tree` 写入主仓库的 A→C 合成树），**缺失 0**。

---

## 十三、人工判定项 H76（留给 Lynn 真机，执行端不代为下结论）

装合并后 `main` 的产物（同一包可连判 H72～H75）。

1. **封面出现**：首页三个类别行左侧各显示一张真缩略图；每张就是该类别里**最大**的那一个（进类别后在 5.2b 之前没有网格可对照，用「随手翻系统相册里最大的录屏／截图」对一下）。
2. **占位态**：`c.count = 0` 的灰行封面位是只描边的空槽，**没有**系统的照片图标、没有色块。
3. **iCloud 优化储存**：若最大的那张本机没有缩略图，封面位显示空槽而不是转圈或图标；App 不发起下载（观察系统「照片」里该项不会因此变成已下载）。
4. **封面随待删篮变**：在 S2 把某类别最大的那张标记进待删篮后回首页，该行封面换成第二大的；从 S3 移出后换回来。
5. **滚动与切 tab**：首页上下滚、切 tab 再回来，封面不闪、不错位、不串行（陷阱 17）。
6. **回归**：S3 的缩略图与改前一样（`ThumbnailView` 默认值路径）；H73／H75 快过一遍。

---

## 十四、发现但未处理的问题（按纪律只报告不修）

1. **扫描期间封面可能频繁换图（③，H76 第 5 条附带观察）**：S0-1 期间每发现一个更大的候选，该类别 `coverAssetID` 就变；`.id(category.coverAssetID)` 让整行重建、`ThumbnailView` 重新取图，取到之前是空槽。回调每秒至多 4 次，首扫时大视频行可能连续换几次图。卡内 H76 第 5 条只写了滚动与切 tab；若真机看着闪，可在 5.2b 或后续卡定「扫描中封面冻结到完成」之类的口径——属产品决策，本卡不动。
2. **`S0View.swift` 协议文档注释写「首页只认识这三个问题」**（`:8`）：IC-153 加钩子后已是四个要求，本卡后五个。P1 限定「`S0View.swift` 其余一字不动」，未改。
3. **`ThumbnailView.load()` 在主线程同步 `PHAsset.fetchAssets(withLocalIdentifiers:)`**（既有写法，`:52-58`）：首页只有三行、每行一次，量级可忽略；5.2b 的三列网格若复用它，一屏几十格的主线程取数值得先实测。
4. **卡内写卡缺陷五处**（第 7.1、7.2 条为条文字面冲突；第 7.3 条为要求在整数上不总能成立；第 7.4 条为引用的先例不成立；第 7.5 条为 needle 在仓内写法上空转，属惯例 41 同类）。
5. **H76 第 3 条的「不下载」只由 `isNetworkAccessAllowed = false` 保证**：`opportunistic` 投递在本机无缩略图时可能先回一张极低清的降质图再无下文，真机上若看到模糊小图而非空槽，属 `ThumbnailView` 现行投递策略（卡内范围外「`S1RangeCoverThumbnail` 的相位规则搬到 S0」一项），本卡未动。
