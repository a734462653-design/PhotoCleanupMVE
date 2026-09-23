# IC-166 自验报告：「其余照片」升为可进入类别 `rest`、`LIB` 排除待删篮与账本、S0-3 判据改「无成员」、空态副句

> 任务卡：`<top>/Tasks/IC-20260923-166-rest-category-and-lib.md`（SPEC-S0 v3 实装第二张，可合并）
> 执行会话：2026-09-23。证据分级按 CLAUDE.md 第四节：①已验证事实、②样本观察、③合理推测、④项目判断。

## 一、结论（先行）

**交付完成，已合并入 `main`。** 三个子项各自独立提交、顺序 A → B → C，CI 预算 3 次只用 2 次，两次都一次绿：

| 子项 | 提交 | CI | 结果 |
|---|---|---|---|
| A 数据层 | `dc74fe5633bc763f535ef9e2b9073c0dacce0749` | **#334**（run 35854026444） | 一次绿，**865 项 0 失败**，真实退出码 0 |
| B 卡片叠层 | `83dd99b5a2881e79cac91060cda209f2b222ff65` | 与 C 同推 | — |
| C 新断言 | `2734ccd0ef2f12fa4ce115f0136777321a96c548` | **#335**（run 35855377983） | 一次绿，**871 项 0 失败**，真实退出码 0 |
| 合并 | `a6018ad990c80fe01445ffdfa4ed890735eb9589`（`--no-ff`，父 `6bc51be` + `2734ccd`） | **合并后 `main` 运行 #336（run 35856602067）** | 一次绿，**871 项 0 失败**，真实退出码 0 |

- G932～G937 全部满足（第五节逐条）。项数对账：865 →（A）865 →（B）865 →（C）871，与卡面一致①。
- 卡面「事实基础」表的 ② 值全部由本机 Python 移植独立复算，**逐项相符**；另发现卡面漏列两处必改期望（IC153 断言 8 的两处识别阶段数组 `:679`／`:688`，三条 → 四条），在白名单文件内按「只改期望值」同口径改掉，CI 实测通过（第八节）。
- **报告落点（惯例 44）**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md` 同在其中）。报告内引用的合并后运行编号与 artifact 是该 docs 提交之前已产生的信息，不存在跨卡回填。
- 人工判定项 H85 六条保留给 Lynn 真机判，执行端不代为下结论（第十四节）。装合并后 `main` 运行的产物 `PhotoCleanupMVE-unsigned-a6018ad990c8`（id 10747902455，有效期至 2026-12-22T11:47:39Z）。

## 二、输入、继承与范围

- 输入：任务卡全文；`<top>/CLAUDE.md`；`<top>/SPEC-S0-20260922_v3.md` 第二节第 2、3 部分、第三节、第四节。
- 继承：`main` = `6bc51bed5cd5997323ad52261aedcf21123b4b6a`（IC-165 报告补记）。
- 目标分支：`feature/ic-166-rest-category-and-lib`（自上述 `main` 切出）。
- 范围边界：只做卡内五条裁定。未做：相似／重复照片、账本与核对流程（5.3）、`bigVideo` 正名、首页与类别页版式、`S0DeckMetrics` 登记值增删、SPEC 与 Decision_log。

### 开工四步（纪律 8 + 惯例「先切分支再改文件」）

1. `git status --porcelain` 输出为空，退出码 0。
2. `git merge-base --is-ancestor 096fb08695972acafed660a9fc1423e3006d4245 main` 退出码 0；本地 `main` = `6bc51bed5cd5997323ad52261aedcf21123b4b6a`。
3. `git ls-remote origin refs/heads/main` = `6bc51bed5cd5997323ad52261aedcf21123b4b6a`，与本地一致。
4. 改任何文件之前 `git switch -c feature/ic-166-rest-category-and-lib`。

## 三、五条裁定的落实

### 裁定 一：`rest` 是「无命中的归属」

- `Core/S0StateMachine.swift`：`S0CategoryIdentifier` 末尾加 `case rest`；`reorderCategories()` 排序比较器首键「`.rest` 恒排末」，其余三键（有项目降 → `c.bytes` 降 → `rawValue` 升）不变；文档注释两处（`S0CategorySnapshot` 头、`cleanableAssetCount`／`cleanableByteCount`）改 v3 口径。
- `Services/S0ScanClassifier.swift`：新增 `static let snapshotOrder = attributionPriority + [.rest]` 与 `static func attributedCategory(for:) -> S0CategoryIdentifier { primaryCategory(for: hits) ?? .rest }`；`hits(...)` 与 `attributionPriority` 声明**一字未动**（IC153 断言 1 的三处期望原样通过，#334／#335 ①）。
- 聚合器：排除判定（未解析在循环条件、待删篮、账本）→ `continue`；其余一律 `attributedCategory` 归属、**只对归属类别累加一次**；封面规则原样套到 `rest`；`categories` 按 `snapshotOrder` 恒四条；文档注释改 v3 口径。裸数仍 ⊆ {0, 1}（IC153 断言 3、IC166 断言 6 ①）。
- 服务 `categoryAssets(_:)`：两句守卫合并为 `attributedCategory(for: asset.hits) == id`，协议文件未动（git blob `b9e4a57c3133bf189ed3db21b1ff995547faa40f` 与 `6bc51be` 同，IC166 断言 6 ①）。
- `S0Text.displayName` 加 `case .rest:`（取既有 key `s0.category.rest`）；`S0DeckMetrics.categoryColor` 加 `case .rest: colorRest`。

### 裁定 二：`LIB` 排除待删篮与账本

- 聚合器 `libraryByteCount +=` 移到排除判定之后；`pendingDeletionByteCount` 累加留在排除判定之前。IC153 断言 2 的 `pendingDeletionByteCount` 仍 2 MB（①）。改后 `Σ c.bytes = cleanableByteCount = libraryTotalByteCount`（IC166 断言 1、IC153 断言 2 ①）。hero 取数点未改。

### 裁定 三：S0-3 判据与副句

- `S0StateResolver` 与 `S0StateInput.cleanableAssetCount` 字段名、判据式均未改；生产者计入 `rest` 后它即 `N_成员`。IC147 断言 4／5 原样通过（①，#335 IC147 16 项全过）。
- 首页 `centeredBlock` 加 `subtitle: String? = nil`（插在 `title:` 之后，`.failed` 两处调用点不动、取默认 nil）；`.empty` 传 `L10n.text("s0.home.hero.empty.subtitle", replacing: ["count": String(machine.snapshot.progress.scannedAssetCount)])`。副句字号借 `pendingRowFontSize`、压暗借 `pendingRowOpacity`，**不加登记值**（`S0DeckMetrics` 仍 198 ①）。
- 目录新增 `s0.home.hero.empty.subtitle` = `已扫描 {count} 项`（按目录既有格式外科插入 11 行，排在 `s0.home.hero.empty.title` 之前）。目录 254 → 255、`s0.` 39 → 40。同步点：六处断言（IC147 `:816`／`:864` 原位、IC148 `:520`、IC156 `:235`、IC157 `:64`、IC165 `:223`）+ IC157 四条 needle（`39)` → `40)`）——五份文件，与卡面一致。
- 桩（`Services/S0CleanupDataStub.swift`，随子项 A 提交）：两剧本各加 `rest` 行；`LIB`、`cleanableByteCount`、`cleanableAssetCount` 一律取当步全部类别之和（新增两个私有静态 helper）。就绪有项目：`rest` 731 项 38.84 GB，`LIB` = hero = 48 GB，成员 1000；就绪无项目：全零、`LIB` 0；扫描中：`rest` 每步 250 项 10.18 GB，第 4 步 `LIB` 恰 48 GB。**改前 grep 贴证**（卡要求）：四份测试对桩就绪无项目剧本的 `LIB` 零处钉住——`libraryTotalByteCount` 在 IC147 只出现在手工快照夹具 `:1059`／`:1104`／`:1149`／`:1177`／`:1198`（不经桩），IC155／IC156／IC157 零处（①）。

### 裁定 四：Deck 层收敛

- `S0DeckHomeModel`：删 `restCardID` 及其文档；`Card.category` 改非可选；`cards(categories:libraryTotalByteCount:)` 去 `restByteCount` 形参与追加分支；`:31` 提到 `restByteCount` 的文档句一并删；`isEnterable` 规则不变。
- `S0DeckHomeView`：调用去 `restByteCount:`；`restByteCount` 计算属性删；两处 `cardColor(for:)` 改 `categoryColor(for: card.category)`；四处 `guard let identifier = card.category` 改直接用；`name(for:)` 一律 `S0CategoryText.displayName(for:)`；`cardID(for:)` 的 `.rest` 分支改返回 nil（与 `.unscanned` 合并为一支）；`segmentColor(for:)` 的 `.rest` 分支保留。收起条右箭头处的旧注释（「其余照片不可点」）改为现口径。
- `S0DeckMetrics.cardColor(for:)`（`static func`）删；`static let` 仍 198、`S0DeckSymbol` 仍 8（IC165 断言 6、IC166 断言 6 ①）。
- `S0DeckCategoryPageView.swift` 只在 `:909` 删 `restByteCount: 0,` 一行（`git diff -U0` 唯一 hunk `@@ -909 +908,0 @@` ①）。

### 裁定 五：段模型按 v3「张数进度缩放」

- `S0SegmentBarModel.make`：零 `LIB` 分支保留（整条 `.rest` 兜底段）；`p` = 扫描中 `clamp(已扫/总数)`、否则 1；每个 `c.bytes > 0` 的类别出段，宽 = `c.bytes / LIB × p`；`p < 1` 时末尾未扫段 `1 − p`。删 `budget`、`min(raw, budget)` 与 `break`、`restByteCount` 减法与 `.rest` 填充段；原「宽 ≤ 0 跳过」守卫保留（只在 `p = 0` 的退化输入上起作用，见第十五节第 4 条）。`Kind.rest` 文档与 `totalWidthFraction` 文档改写。斜纹宽口径不变（第十五节第 2 条）。
- IC148 断言 8 旧 → 新（实读 `:387-460` 后改，#335 该项 passed ①）：

| 用例 | 旧 | 新 |
|---|---|---|
| (a) `zero` | 一类 0 字节，`LIB` 48 GB；靠填充段和为 1 | `LIB` 改 **0**，走零 LIB 分支；期望「恰一段 `.rest`、和为 1」不变 |
| (b) `full` | 不变 | 不变 |
| (c) `mixed` | 4.8 + 0.56 GB 对 48 GB、扫 3／10；`bigVideo` 宽 0.1 | 加 `rest` 42.64 GB 使 Σ = LIB；`bigVideo` **0.03**、`screenshot` **0.0035**、`rest` **0.2665**、未扫 0.7、和 1 |
| (d) `noLibrary` | 不变 | 不变 |
| (e) `overflow` | 40 + 40 GB 对 48 GB，夹到 1 | 改缩放用例 `scaled`：`bigVideo` 40 + `similar` 8 = 48 GB、扫 3／10 → **0.25／0.05／未扫 0.7**、和 1、`.rest` 段 0 条、各段 ≥ 0（旧预算式在此输入上只剩首段 0.3 + 未扫 0.7） |

## 四、子项与测试函数

- **子项 A** 只改期望值、字面量与注释：`IC153ScanServiceTests` `func test` 13（不变）、`IC155CategoryDataAndCoverTests` 8（不变）。
- **子项 B**：`IC162DeckPreviewTests` 三条改期望（A1 改用新夹具 `fixtureCategoriesWithRest`：三类 + `rest` 580，Σ = LIB = 1000；ids `[bigVideo, screenRecording, rest]`、`category` `[.bigVideo, .screenRecording, .rest]`、占比 30／12／58、`isEnterable` 全真、`withoutLibrary` 三张占比全 0；A2 改「快照不含 rest 行 → 卡里无 `category == .rest`」、count 2；`noneEnterable` 改两条 `.awaitingScanCompletion` 类别 → count 2、`defaultOpenID` nil），全部去掉 `restByteCount:` 实参与 `category == nil` 断言；IC148 断言 8（上表）；`s0.` 39 → 40 六处 + 四 needle。
- **子项 C** 新文件 `IC166RestCategoryTests.swift` 六条（第七节）。

## 五、验收门禁

| 门禁 | 结论 | 依据 |
|---|---|---|
| **G932 数据层口径** | 通过 | IC166 断言 1～4 passed（#335）；IC153 全族 13／13、IC155 全族 8／8 passed（#334 与 #335 各一次）；本机 Python 复算表与 CI 逐项相符（第八节）；`attributionPriority` 声明与 `6bc51be` 逐字相同（`git diff` 无该行改动，IC153 断言 1 与 IC166 断言 2 的顺序断言 passed）；`cacheSchemaVersion` 1（`git grep` 两端同为 `S0ScanRules.swift:22: static let cacheSchemaVersion = 1`）；分类器文件裸数 ⊆ {0, 1}（IC153 断言 3、IC166 断言 6 passed） |
| **G933 Deck 层收敛** | 通过 | 子项 B 第 2 条全部计数本机实测相符（第十节）；IC166 断言 5／6 passed；IC162 三条、IC148 断言 08、IC165 六条 passed（#335） |
| **G934 白名单外零改动** | 通过 | `git diff --name-only 6bc51be 2734ccd` 恰 21 个路径，与卡面白名单逐个比对 `comm` 两侧差集皆空；「不得打红」对象表见第十一节；十三条被保护分支 tip 未变（第十一节） |
| **G935 CI** | 通过 | #335：绿，**871 项 0 失败**，真实退出码 0，执行摘要 notice、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice 齐（第六节）；`testIC063` passed，build 行在 `IC063_WARMUP_GATE_END` 之前 |
| **G936 合并前置** | 通过 | G932～G935 + pbxproj 撞号扫描（定义行 `uniq -d` 空；新 fileRef `10000000000000000000006F` 恰 3 处、新 buildFile `20000000000000000000006C` 恰 2 处）+ `git status --porcelain` 空 + 本地与远端 `main` 仍 `6bc51bed5cd5997323ad52261aedcf21123b4b6a` → `git switch main` 后 `git merge --no-ff feature/ic-166-rest-category-and-lib -F <消息文件>` 退出码 0（ort，无冲突），首行照卡；合并提交树 `615e6da745a429f1e4b3fd79f07b8ce0a13c275f` 与 C 提交树相同；`git push origin main` 第一次即成功（`6bc51be..a6018ad`） |
| **G937 合并后 `main` 运行** | 通过 | #336（run 35856602067，event push，被测 `a6018ad990c80fe01445ffdfa4ed890735eb9589`）：一次绿，871 项 0 失败，真实退出码 0；分段耗时 notice `模拟器启动 100 s；xcodebuild test 347 s；总 448 s`；artifact `PhotoCleanupMVE-unsigned-a6018ad990c8`，id 10747902455，有效期至 2026-12-22T11:47:39Z |

## 六、CI 运行（两次分支运行 + 合并后运行）

| 项 | A：#334 | C：#335 | 合并后 `main`：#336（run 35856602067） |
|---|---|---|---|
| run id | 35854026444（attempt 1） | 35855377983（attempt 1） | 35856602067（attempt 1，event push） |
| 被测提交 | `dc74fe5633bc763f535ef9e2b9073c0dacce0749` | `2734ccd0ef2f12fa4ce115f0136777321a96c548` | `a6018ad990c80fe01445ffdfa4ed890735eb9589` |
| 结论 | success，12 步全 success | success，12 步全 success | success，12 步全 success |
| XCTest 执行摘要 notice | `Executed 865 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 865 tests / 0 failures` | `Executed 871 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 871 tests / 0 failures` | `Executed 871 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 871 tests / 0 failures` |
| 整包日志唯一 Test Case 行 | 865 passed ／ 0 failed | 871 passed ／ 0 failed | 871 passed ／ 0 failed |
| 真实退出码 | 0（`** TEST SUCCEEDED **`；「运行 XCTest」步骤 success，工作流 `exit "$test_status"`） | 0（同左） | 0（`** TEST SUCCEEDED **`） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；`{ platform:iOS Simulator, arch:arm64, id:2911FD29-…, OS:26.2, name:iPhone 16 }` | 同左（同一模拟器 id） | 同左（同一模拟器 id `2911FD29-…`，runtime `iOS-26-2`） |
| 分段耗时 notice | `模拟器启动 90 s；xcodebuild test 376 s；总 467 s` | `模拟器启动 74 s；xcodebuild test 335 s；总 409 s` | `模拟器启动 100 s；xcodebuild test 347 s；总 448 s` |
| 未签名 IPA 校验 notice | 字节数 1790282，SHA-256 `d480a72af9a083c90ca5aca135e6168101e2c95713f975b984c8f9ed8070ef9b` | 字节数 1790882，SHA-256 `5f3b225c9ec2e29dbb5732ae222b7829030abb46e4427f6082d94f3f6a45bd91` | 字节数 1790882，SHA-256 `33ffb196e576d42aab0d300d20d2036d9bac1220f31ffe6a117b7cfd80464b15` |
| artifact | `PhotoCleanupMVE-unsigned-dc74fe5633bc`，id 10747365416，有效期至 2026-12-22T11:21:09Z | `PhotoCleanupMVE-unsigned-2734ccd0ef2f`，id 10747523022，有效期至 2026-12-22T11:35:03Z | `PhotoCleanupMVE-unsigned-a6018ad990c8`，id 10747902455，有效期至 2026-12-22T11:47:39Z |
| `testIC063` | passed（6.698 s）；`building pipeline path_exterior-… took 0.652395 seconds` 在日志行 3569，`IC063_WARMUP_GATE_END` 在 3573——**build 行在前** | passed（7.214 s）；build 行 0.736433 s 在 3693，`GATE_END` 在 3697——**在前** | passed（6.641 s）；build 行 0.868611 s 在 3657，`GATE_END` 在 3662——**在前** |

取数方式：`gh api`（带代理）取 `actions/runs?head_sha=`、`runs/<id>/jobs`、`check-runs/<该次自己的 check-run id>/annotations`、`runs/<id>/artifacts` 与整包日志 zip；整包日志用 Python `zipfile` 读，只取整作业日志一份（不与逐步日志重复计数），剔 `[36;1m` 脚本回显行后按唯一 Test Case 行计数。IPA 不可复现，SHA-256 只作本次产物的校验、不作跨运行身份（既有结论）。

## 七、子项 C 六条断言

| 断言 | 测试函数 | #335 |
|---|---|---|
| 1 `LIB` 排除待删篮与账本且 = 类别和 | `testIC166A_LibraryExcludesPendingAndLedgerAndSumsToCategories` | passed |
| 2 `rest` 是无命中的归属、各类两两不交 | `testIC166A_RestIsAttributionOfNoHitAndCategoriesArePairwiseDisjoint` | passed |
| 3 `rest` 封面同口径、扫描完成后恒垫底 | `testIC166A_RestCoverIsLargestAndRestSinksToBottom` | passed |
| 4 S0-3 随 `N_成员`、桩守 `N_成员 = 0 ⟺ LIB = 0` | `testIC166A_EmptyStateFollowsMemberCount` | passed |
| 5 卡片叠与总条把 `rest` 当普通类别 | `testIC166B_DeckCardsTreatRestAsOrdinaryCategory` | passed |
| 6 源码纪律 | `testIC166B_SourceDiscipline` | passed |

写法与卡面的差异（均为在卡面要求之上**加严**，无放宽）：

- 断言 1 夹具照卡（三类各一 + 两张普通照片 + 篮内普通照片 2 MB + 账本视频 200 MB + 未解析一张）：`LIB` = 192 MB、成员 5、`pendingDeletionByteCount` 2 MB、ids 四条；另加正对照「两个排除集清空后 `LIB` = 394 MB、成员 7」。
- 断言 2 另加 `attributedCategory([.screenshot, .screenRecording]) == .screenRecording` 与「普通照片 `hits` 为空集」；数据源侧照卡用桩就绪剧本，集合运算一律 `Set`（惯例 45）。
- 断言 3 的排序夹具在四类之外加一条**无项目**的 `.duplicate`，钉住「`rest` 垫在无项目类别之下」（v3「恒垫底」），期望 `[.bigVideo, .screenRecording, .screenshot, .duplicate, .rest]`；并钉扫描中不重排（到达序 `[.rest, …]`、重排次数 0 → 1）。
- 断言 4 另加两条行为对照：只有普通照片的库在 v3 下落 S0-2；全库都在待删篮时成员与 `LIB` 同为 0、落 S0-3。
- 断言 5 的「四类快照」取断言 1 的真实聚合结果（不手搓）；卡面写「宽之和 == 1」，因浮点求和（本机复算 0.9999999999999999）一律按精度 1e-9 断言。
- 断言 6：「与 `6bc51be` 相同」按 **git blob 标识**实现——测试内用 CryptoKit `Insecure.SHA1` 对 `"blob <字节数>" + NUL + 内容` 求值，与 `git rev-parse 6bc51be:<路径>` 同值（`.gitattributes` 把 `*.swift` 钉为 LF，检出即仓库内容）；期望值 `b9e4a57c3133bf189ed3db21b1ff995547faa40f`（协议文件）、`3d9fe61c5ad1d5be0f9e7f53baf58e3f02d45135`（App 入口）取自 `git rev-parse 6bc51be:<路径>` 与 `git hash-object`，本机 Python 同式复算相符。另加一条：首页四态分派段内 `progress.scannedAssetCount` 恰 1（钉裁定 三的取数点）。`CryptoKit` 是本仓测试侧首次引入的系统框架（第十五节第 7 条）。

## 八、本机 Python 复算（惯例 43）与 CI 对账

把 `hits`／`attributedCategory`／新旧两版聚合器／服务 `categoryAssets`／桩剧本与合成列表移植成 Python（`ic166_port.py`，会话 scratchpad），对 IC153 断言 2 夹具、`sampleLibrary(8／9／10／12／50)`、IC155 断言 1 与 2 的夹具、`coverLibrary()` 各跑一遍。**手工移植，② 样本观察，不构成测试会通过的证据；权威结论取 CI。**

### IC153（`IC153ScanServiceTests.swift`）

| 位置 | 旧 | 新（复算） | 卡面 ② | CI |
|---|---|---|---|---|
| 断言 2 `expectedCategories` | 3 条 | 4 条：追加 `rest` 1 项、4 MB、封面 `"plain-photo"`、`.counting` | 相符 | #334／#335 passed |
| 断言 2 `cleanableAssetCount` | 2 | **3** | 相符 | passed |
| 断言 2 `cleanableByteCount` | 153 MB | **157 MB** | 相符 | passed |
| 断言 2 `categorySum` | 153 MB | **157 MB**，且 = `cleanableByteCount` = `libraryTotalByteCount`（加一行 `XCTAssertEqual(categorySum, snapshot.libraryTotalByteCount)`） | 相符 | passed |
| 断言 2 `libraryTotalByteCount` | 359 MB | **157 MB**（150 + 3 + 4；剔 2 MB 篮内与 200 MB 账本） | 相符 | passed |
| 断言 2 `pendingDeletionByteCount` | 2 MB | 2 MB（不变） | 相符 | passed |
| 断言 2 unfiltered `candidateCount` | `[1, 1, 2]` | `[1, 1, 2, 1]` | 相符 | passed |
| 断言 2 unfiltered 成员／hero／LIB | 4／355 MB／359 MB | **5／359 MB／359 MB** | 相符 | passed |
| 断言 2 unfiltered 识别阶段 | 三个 `.settled` | 四个 | 相符 | passed |
| 断言 2 unfiltered ids | 三条 | + `.rest` | 相符 | passed |
| 断言 7 `:593` 前置 | `[true, true, true]` | `[true, true, true, true]`（`sampleLibrary(12)`：`rest` 3 项 9 MB、封面 `asset-11/L0/001`） | 相符 | passed |
| **断言 8 `:679`** | `[.counting, .counting, .counting]` | **`[.counting × 4]`**（`sampleLibrary(8)`，`rest` 与其余同取 `context.recognition`） | **卡面漏列** | passed |
| **断言 8 `:688`** | `[.settled, .settled, .settled]` | **`[.settled × 4]`** | **卡面漏列** | passed |
| 断言 13 `:1017` | 桩就绪 5 类 | **6** | 相符 | passed |

注释「类别全量」改为「类别按归属」；函数名 `testIC153A_AggregationDedupesHeroButNotCategories` 照卡不改。

### IC155（`IC155CategoryDataAndCoverTests.swift`）

| 位置 | 旧 | 新（复算） | 卡面 ② | CI |
|---|---|---|---|---|
| 断言 1 ids | 三条 | + `.rest`；`rest` 封面 `"plain-photo"`（加一行断言）；复算该夹具 `LIB` 167 MB、成员 5 | 相符 | passed |
| 断言 1 `empty.categories.count` | 3 | **4** | 相符 | passed |
| 断言 2 封面序列 | `["big-a", "rec-y", "shot-a"]` | + `"plain-photo"`（五种输入顺序复算结果全等） | 相符 | passed |
| 断言 3 `readyEmpty.categories.count` | 5 | **6** | 相符 | passed |
| 断言 4 服务 ids | 三条 | + `.rest`；`expectedOrders` 加 `.rest: ["photo-plain"]`（`coverLibrary` 复算 `LIB` 923 MB、成员 11） | 相符 | passed |
| 断言 6 `nonEmptyListCount` | 37 | **46**（就绪 6 类 × 5 步 = 30 + 扫描第 1～4 步各 4 类 = 16；复算合成列表严格递减、无并列、标识不重） | 相符 | passed |
| helper `assertListsMatchSnapshot` | 3 | **4** | 相符 | passed |
| `:421-424`／`:452-453` | — | 不变（`duplicate`／`similar` 列表恒空，复算相符） | 相符 | passed |

另：`coverLibrary` 在断言 5 的四个篮内状态下，复算四条列表与快照项数／封面全部一致（`rest` 恒 `["photo-plain"]`）。

## 九、本地门禁（三个提交各一份）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A `dc74fe5` | 退出码 0 | 退出码 0；目录条目 254 = 产品源码引用 key 254；残留 0 | 退出码 0（`6bc51be..dc74fe5`） |
| B `83dd99b` | 退出码 0 | 退出码 0；255 = 255；残留 0 | 退出码 0（`dc74fe5..83dd99b`） |
| C `2734ccd` | 退出码 0 | 退出码 0；255 = 255；残留 0 | 退出码 0（`83dd99b..2734ccd`） |

口径：A 的两道脚本门禁在工作树恰为 A 时跑（B 的编辑尚未开始）；B 提交时工作树里还有 C 的两份未提交文件，故 B 的两道脚本门禁在 `git archive 83dd99b` 解出的独立目录里跑，结果只反映 B 本身；C 在工作树净时跑。selfcheck 内含的 Swift 结构检查、扫描 needle 与源码变体交叉审计同在上列退出码之内。

推 CI 前另做本机模拟（② 样本观察）：A 阶段源码扫描 29 项、B 阶段 95 项、段模型与卡片行为 33 项、C 六条断言的行为与扫描 73 项，全部与期望相符。

## 十、子项 B 第 2 条计数（改后，剔注释口径；key 类扫原文）

| 文件 | needle | 期望 | 实测 |
|---|---|---|---|
| `S0DeckHomeView.swift` | `restCardID` | 0 | 0 |
|  | `card.category == nil`／`guard let identifier = card.category` | 0／0 | 0／0 |
|  | `cardColor(` | 0 | 0 |
|  | `categoryColor(for:` | ≥ 2 | 2 |
|  | `private func centeredBlock(`／裸 `centeredBlock(` | 1／4 | 1／4 |
|  | `switch machine.state {`／`libraryTotalByteCount == 0`／`cleanableByteCount`／`withAnimation(` | 1／1／0／1 | 1／1／0／1 |
|  | 原文 `s0.home.hero.empty.subtitle`／`s0.category.rest` | 1／0 | 1／0 |
| `S0Text.swift` | 原文 `s0.category.rest` | 1 | 1 |
| `S0DeckHomeModel.swift` | `restCardID`／`category: S0CategoryIdentifier?`／`restByteCount`（剔注释；原文 `restByteCount` 亦 0） | 0／0／0 | 0／0／0 |
| `S0SegmentBarModel.swift` | `kind: .rest`／`restByteCount`／`budget` | 1／0／0 | 1／0／0 |
| `S0DeckMetrics.swift` | `enum S0DeckMetrics` 切片 `static let`／`func cardColor` | 198／0 | 198／0 |

## 十一、G934 明细

### 「不得打红」对象同一性（`6bc51be` 对 `2734ccd`，`git rev-parse <提交>:<路径>` 两侧相同）

| 路径 | 对象（前 12 位） |
|---|---|
| `PhotoCleanupMVE/App`（树） | `a8ae7e545b8b` |
| `PhotoCleanupMVE/Features/Shared`（树） | `ca567d006a53` |
| `PhotoCleanupMVE/Features/S1`～`S5`（树） | `5bb26f016d35`／`f43aa47cafbe`／`175b165b22c7`／`d6bce474b5e0`／`d738ec8e9134` |
| `.github`／`Scripts`（树） | `74088388c62a`／`514886dc0afc` |
| `S0CleanupFlowView.swift` | `d20617b40c5c` |
| `S0CleanupDataProviding.swift` | `b9e4a57c3133` |
| `S0CategoryPageSelection.swift` | `d114ac601f11` |
| `S0DeckZoomTransition.swift` | `c1424f916652` |
| `S0TabContainer.swift` | `9a80395451f0` |

`Core/`、`Services/`、`Features/S0/` 与测试目录内的改动文件恰为白名单所列（`Core/` 只 `S0StateMachine.swift`；`Services/` 只三份；测试只九份），`S0DeckCategoryPageView.swift` 的 diff 只落在 `:909`。`schemaVersion` 7、`cacheSchemaVersion` 1 两端相同。

### 十三条被保护分支 tip（`git ls-remote` 与本地 `for-each-ref` 两侧一致，均未变）

`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`；冻结三链 `feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`；`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`。

## 十二、陷阱 9 四条全量扫描（对 `6bc51be`，推第一次 CI 前）

| 扫描 | 命中 |
|---|---|
| (1) `S0CategoryIdentifier` 穷举 `switch`（产品侧） | 2 处：`Features/S0/S0DeckMetrics.swift:765`（`categoryColor`）、`Features/S0/S0Text.swift:27`（`displayName`）——两处都加了 `case .rest` |
| (2) `S0CategoryIdentifier.allCases` | 3 处，全在测试：`IC155:493`、`IC155:525`、`IC157:327`——对 `.rest` 自动成立（IC155 断言 6 的 `nonEmptyListCount` 随之 37 → 46；IC157 `shouldRecomputeOnAppear(.rest)` 为真） |
| (3) 类别清单的字面计数与列表 | IC153 `:22`（优先序，不改）、`:327`、`:331`、`:593`、**`:680`、`:689`**、`:1017`；IC155 `:129`、`:190`、`:341`、`:364`、`:521`、`:762`——除 `:22` 外全部按复算改 |
| (4) `rawValue` 派生串（产品侧） | 8 处：`App/PhotoCleanupMVEApp.swift:108`／`:113`（`cat:rest`）、`Core/S0StateMachine.swift:557`（排序末键）、`S0DeckCategoryPageView.swift:88`／`:335`、`S0DeckHomeModel.swift:42`、`S0DeckHomeView.swift:1036`、`Services/S0CleanupDataStub.swift:258`（`stub.rest.<n>`）——均对 `"rest"` 自然成立、无需改；`S0CategoryIdentifier(rawValue` 0 处 |

## 十三、pbxproj、项数与摘取关系

- **pbxproj**：登记前重扫，最大 fileRef `10000000000000000000006E`、最大 buildFile `20000000000000000000006B`；新登记 fileRef `10000000000000000000006F`、buildFile `20000000000000000000006C`，各在文件引用、构建文件、测试组、Sources 阶段落位；登记后定义行 `uniq -d` 为空，新 fileRef 恰 3 处、新 buildFile 恰 2 处；#335 唯一 Test Case 行里 `IC166RestCategoryTests` 恰 6 项（文件确实进了编译列表，陷阱 IC-134 #262 型静默掉出未发生）。
- **项数对账**：865（`6bc51be`，IC-165 #333）→ A 865（#334 ①）→ B 865（本地 `func test` 增减 0）→ C 871（#335 ①，+6 = `IC166RestCategoryTests` 六项）。
- **摘取关系实测**（本地 `git clone --no-hardlinks` 的独立克隆，自 `6bc51be` 起 `cherry-pick -x`）：

| 序列 | 结果 | 结果树 |
|---|---|---|
| A 单独 | 无冲突 | `1b92272f0417962cb5b95e89ed0bc8292ad0b933` = 分支上 A 的树；#334 实证 A 单独编译且全绿 |
| A → B | 无冲突 | `47248b2fc561a9a79208ed12c15fc17e7915470d` = 分支上 B 的树 |
| A → B → C | 无冲突 | `615e6da745a429f1e4b3fd79f07b8ce0a13c275f` = 分支上 C 的树 = 合并提交的树 |
| B 单独／C 单独／A → C | 文本上无冲突，但**不可编译** | B 的测试引用 A 才有的 `S0CategoryIdentifier.rest`（IC162 `fixtureCategoriesWithRest`、IC148 `settledCategory(id: .rest, …)`）；C 引用 A 的 `attributedCategory`／`snapshotOrder` 与 B 的两参 `cards(categories:libraryTotalByteCount:)` |

结论与卡面一致：可摘单元为 A（只作证据）、A → B、A → B → C。卡面「A 单独可编译、全绿」由 #334 证实①；「不宜单独合并」的理由（首页同时出现 `id: "rest"` 类别卡与旧 `__rest__` 卡）是对 A 后首页行为的推断，本卡未在真机或模拟器 UI 上观测，仍为③。

## 十四、人工判定项（H85 六条，原样列出，保留给 Lynn 真机判定）

装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-a6018ad990c8`（id 10747902455，有效期至 2026-12-22T11:47:39Z）。

1. 首页「其余照片」卡在**最底**、可点、可展开、有「去清理」；点进去是全部不属于视频／截图／录屏的照片，按大小从大到小；勾选进篮、长按进 S2、S3 里组头叫「其余照片」——都和其他类别一样。
2. 大数字 = 各卡 GB 之和；把几张进篮后大数字**同步减**，回首页后总条各段宽度重新分配、没有多出来的灰段。
3. 总条：就绪后只有四段（视频、录屏、截图、其余），没有额外的「其余」灰段；**扫描中**四段都在、随进度一起变宽，右侧「未扫描」段随进度收缩到没有（不再出现「后面几段被吃掉只剩一段」）。
4. 空库或全库已在待删篮：首页空态，副句「已扫描 N 项」，没有总条与卡片叠。
5. H84 第 1～5 条快过一遍（同一份首页代码，本卡只改数据层与卡片数据）。
6. 一两句总评。

执行端对以上六条不下结论。模拟器上 CI 只覆盖纯函数、夹具与源码扫描（陷阱 1）；「其余照片」卡的观感、zoom 过渡、真实相册下的扫描进度缩放、空态版式均**未覆盖**。

## 十五、发现但未处理的问题（按纪律只报告）

1. **卡面漏列两处必改期望（写卡缺陷）**：IC153 断言 8 `testIC153C_ServiceOutcomeMapping` 的 `:679`／`:688` 钉「识别阶段三条」，`rest` 进快照后必为四条。卡面事实基础表列了 IC153 的 `:325-327`（同形态），漏了这两处；陷阱 9 第 (3) 条扫描一并显影。处理：属白名单文件、只改期望值，同口径改掉，#334 实证通过。
2. **斜纹口径与 v3 `LIB` 口径不自洽（③）**：`S0SegmentBarModel` 的斜纹宽 = `等待清空(c) / LIB`，画在类别段内；v3 起账本内资产已不计入任何 `c.bytes` 与 `LIB`，「类别段内的等待清空部分」在语义上不再成立，斜纹也未随 `p` 缩放。当前 `ledgerEntries` 恒空（5.3 前），无可见影响。卡面裁定 五只改段宽、未涉及斜纹，故斜纹口径原样保留；建议随 5.3 账本写入一并定口径。
3. **`S0LibraryScanService.categoryAssets(_:)` 文档注释 `:147-154`**仍写「与聚合同一个命中判定」，实际已是「同一个归属判定」；卡限定该文件只改 `:170-171`，未动。
4. **段模型的「宽 ≤ 0 跳过」守卫**沿用旧代码：扫描中且 `总张数 = 0` 而 `LIB > 0`（退化输入，真实服务不会给出）时，`p = 0`，全部类别段被跳过、只剩宽 1 的未扫段。与卡面「每个 `c.bytes > 0` 的类别出段」在该退化点上字面不同，此处取「不出零宽段」以免段间隙空转，报告登记。
5. **扫描首帧 `LIB = 0` 时总条是整条兜底段（中性色 `colorRest`）而非整条「未扫描」段**：零 LIB 分支按卡保留，行为与 IC-165 相同；v3 第三节 S0-1「总条：已扫出的各类别段 + 未扫描段」在首帧上的呈现未单独规定（首帧 hero 显示「正在扫描…」）。留 H85 第 3 条观感判，③。
6. **v3 两条欠账**（卡要求登记）：(a) `s0.home.hero.empty.subtitle` = `已扫描 {count} 项` 在 SPEC-S0 v3 第十四节第 3 部分**未登记**，随下一版 v3 补登；(b) S0-3 副句口径「已扫描 N 项」取 `progress.scannedAssetCount`，扫描完成时 = `library.count`，**含未解析与篮内资产**；桩的空态剧本进度为 12000／12000，桩上会显示「已扫描 12000 项」而 `LIB` 为 0；真空库显示「已扫描 0 项」——v3 措辞订正候选③。
7. **测试侧首次引入 `CryptoKit`**：IC166 断言 6 用 `Insecure.SHA1` 求 git blob 标识以落实「blob 与 `6bc51be` 相同」。仅测试目标，产品零依赖；#335 编译并通过①。
8. 函数名语义过时（照卡不改）：`testIC153A_AggregationDedupesHeroButNotCategories`（类别也已按归属去重）、`testIC162A_CardsKeepOrderDropEmptyAndAppendRest`／`testIC162A_RestCardOmittedWhenZero`（不再有追加卡）。留纯重构卡。
9. `S0DeckHomeModel.Card.isEnterable` 的文档仍引用已退役的 `S0CategoryRowPresentation.showsDisclosure`（IC-165 前遗留，非本卡引入）。

## 十六、40 位 SHA 核验

对两份报告全文用正则 `(?<![0-9A-Za-z])[0-9a-f]{40}(?![0-9A-Za-z])` 提取全部 40 位十六进制串（64 位的 IPA SHA-256 不被匹配），去重得 **11 个**。对每个先 `git cat-file -t <sha>` 取类型，再跑 `git cat-file -e <sha>^{<类型>}`。**11 个退出码全部 0，失败 0**（commit 6、tree 3、blob 2）：

| 40 位 SHA | 类型 | `cat-file -e` 退出码 |
|---|---|---|
| `dc74fe5633bc763f535ef9e2b9073c0dacce0749` | commit（子项 A） | 0 |
| `83dd99b5a2881e79cac91060cda209f2b222ff65` | commit（子项 B） | 0 |
| `2734ccd0ef2f12fa4ce115f0136777321a96c548` | commit（子项 C） | 0 |
| `a6018ad990c80fe01445ffdfa4ed890735eb9589` | commit（合并） | 0 |
| `6bc51bed5cd5997323ad52261aedcf21123b4b6a` | commit（基线） | 0 |
| `096fb08695972acafed660a9fc1423e3006d4245` | commit（开工 `is-ancestor` 实参，IC-165 合并） | 0 |
| `1b92272f0417962cb5b95e89ed0bc8292ad0b933` | tree（A） | 0 |
| `47248b2fc561a9a79208ed12c15fc17e7915470d` | tree（B） | 0 |
| `615e6da745a429f1e4b3fd79f07b8ce0a13c275f` | tree（C = 合并） | 0 |
| `b9e4a57c3133bf189ed3db21b1ff995547faa40f` | blob（协议文件） | 0 |
| `3d9fe61c5ad1d5be0f9e7f53baf58e3f02d45135` | blob（App 入口） | 0 |

每个都出自本会话实读命令的输出（`git rev-parse`、`git log --format=%H`、`git ls-remote`、`git hash-object`、克隆内 `git rev-parse HEAD^{tree}`）；克隆里 B 单独／C 单独／A → C 的结果树只存在于临时克隆，报告不写其 40 位标识。本报告所在的 docs 提交自身的 SHA 不在报告内。
