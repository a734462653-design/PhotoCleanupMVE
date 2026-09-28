# IC-183 自验报告

## 一、结论（先行）

- **四个子项全部按卡面原文完成，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-183-retire-render-chain`：A `732bbaf99499ffe65a38cf2f262ebd85fb6c8a3c` → D `d7aa2b13833e40180f652faa6a8fb7a23e4578f9` → E `28d3c4d96bfe27da9bfdf461219e7f26d8a96705` → F `fe96fce8bab6cbcba821262b680c70c37336ddbe`。
- 分支 CI **#370**（run `36371517409`）一次绿：**943 项 0 失败**（940 既有 + 3 新），真实退出码 0，`OS:26.2, name:iPhone 16`；三条新断言全部 passed。CI 预算 3 次只用 1 次（另加合并后 `main` 一次）。
- 合并提交 `cb83ef537117de4db28857a23435ee586db47a3f`（双亲 `c0f5258c693684a65b1d8d6f77bcf499911986e2`／`fe96fce8bab6cbcba821262b680c70c37336ddbe`，树 `a76f206d07e56e1737ce2ae6fc699373956be183` 与 F 提交树相同）；分支推送、合并、推 `main` 都一次通过，未被分类器拦。合并后 `main` 运行 **#371（run `36372326884`）一次绿 943／0**。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 卡面 28 处锚句（A1～A11、D1～D4、E1～E9、F1～F4）替换时各恰 1 处；卡面「改后」计数逐条相等（第六节，四段累计 39／53／84／90 项全等）；十六个基线 blob 相符；拷入文件 hash 相符；`sim_ic183.py`（只对基线跑）`FAILURES 0`；`check_ic183.py` 在四个 tip 上 A 118／118、D 118／118、E 118／118、F 119／119 全 PASS、FAIL 0、退出码 0。**没有与卡面矛盾之处，没有停下的项。**
- 零产品行为改动；人工判定项：无（卡「人工判定项」节）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡：`<top>/Tasks/IC-20260927-183-retire-render-chain.md`；调研 `Tasks/RESEARCH-IC-183-retire-facts.md`（〇、A.1、A.4、A.5、B、C、D）；复核 `Tasks/REVIEW-IC-183-findings.md`（两轮 + 两节处置，以卡为准）。
- 基线：`main` = `c0f5258c693684a65b1d8d6f77bcf499911986e2`。开工四步：`git status --porcelain` 空（退出码 0、零输出）；`git merge-base --is-ancestor 69ccec5d5797f73076a51ed35b7f2d434bfa6ee2 main` 退出码 0；`git ls-remote origin refs/heads/main` = `c0f5258c693684a65b1d8d6f77bcf499911986e2`（与本地一致）；十六个文件 blob 与卡面表逐条相等（下表，`git rev-parse c0f5258:<路径>` 与工作树 `git hash-object` 两列都等于卡面）；**先 `git checkout -b feature/ic-183-retire-render-chain` 再改文件**。

| 路径 | 卡面 blob | 实测 |
|---|---|---|
| `Features/S1/S1View.swift` | `117f4c56ee953262ca22ad59c8569de6a1c1e7fb` | 相等 |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | `f9e490435c98eef99b180aa5482982d3aab37708` | 相等 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | `41acce5c9bab74e780f779ae5162841e32035c6e` | 相等 |
| `PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift` | `33228171fd50039483e10e1665b7ff9b2f51b737` | 相等 |
| `Services/S0LibraryScanService.swift` | `66daa12f121101180a506205557b425beec3b87d` | 相等 |
| `Features/S0/S0DeckHomeModel.swift` | `156ed9c74a3ca9633607db1109fc0d3330ff0930` | 相等 |
| `Features/S0/S0DeckHomeView.swift` | `8b2168801c41ffcfe51e13dd0ec9620bf1e60136` | 相等 |
| `Features/S0/S0CategoryPageSelection.swift` | `d114ac601f1131babd290fa39ab3b59f03e42af2` | 相等 |
| `PhotoCleanupMVETests/IC153ScanServiceTests.swift` | `0c613e17aae6a08ed4abe8835b4979fd0b4933bc` | 相等 |
| `PhotoCleanupMVETests/IC162DeckPreviewTests.swift` | `cd04f5f0fba29b35d389b243ae9eefe926d6fd19` | 相等 |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | `822fbf5d5792a09762a54ecb2cc5bab39bea97ec` | 相等 |
| `PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift` | `d53b67bc3878beada4b204d24487bd18b04ebb7c` | 相等 |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | `c545a5a1dffb2c81651c30ba7f6355917d9eabb9` | 相等 |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | `b675939192d08301e43059eafc46ce8d80a5bbc8` | 相等 |
| `App/PhotoCleanupMVEApp.swift` | `89bbd814d3571cf3788eee4a572b9ff9f7c8f359` | 相等 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `22a969715e66977f63926c1b7abe7e52490160bf` | 相等 |

- 范围边界：只做卡「本卡边界」四项。IC-184 范围（`S1ProgressLinePresentation.isVisible`、`S1PendingBadgePresentation`、`S1RangeCardPresentation`、`S1YearStackStyle`、`S1RangeCoverPolicy.targetPixelSize`、`S1CoverImagePhase`、`S1NotificationBadgeStyle.cardRing`、状态机展开 API）、`S2AmbientMetrics` 正名、`S1PreviewData`、IC-178 前就零调用的四个成员、目录、`Core/`、`Features/S2～S5`、`Features/Shared`、`.github`、`Scripts`、SPEC 与 Decision_log 均未触碰。未删除任何测试函数。
- 改法实施方式：执行端脚本 `scratchpad/ic183-exec/apply.py` 先从卡文件原文逐块取出 28 个「把／改为」代码块，与替换表 `decision-tools/ic183_edits.py` 的 OLD／NEW 逐字节比对（28／28 相同；A2／A3／A4／E6 四个整段删除块按卡文「含末尾自带的那一个空行」补一个 `\n` 后相同，A5～A7 三个单行删除块不补），再在工作树当时文本上断言每个 OLD 恰 1 处后替换、按 LF 字节写回。28 处全部恰 1，无一处停下。另：每段改后文件与 `sim_ic183.py` 在基线上确定性生成的 `decision-tools/sim183/` 对应文件 `cmp` 逐字节相同（十六个文件）。
- 空行口径：A2／A3／A4 删后 `S1View.swift` 与 E6 删后 `IC146ChromeRoundTwoTests.swift` 的连续两空行数（`\n\n\n`）均与基线相同（0）；A5～A7 只删那一行、未新增空行。

## 三、提交列表

| 子项 | 提交 | 树 | 可摘性 |
|---|---|---|---|
| A 渲染链退役 + 三条既有期望 | `732bbaf99499ffe65a38cf2f262ebd85fb6c8a3c` | `9c49457b76373f669a7e980cbfad1288209a52f6` | 单独可摘（实测见第十二节） |
| D 四处过时注释 | `d7aa2b13833e40180f652faa6a8fb7a23e4578f9` | `986a6a0b11e2f4a04b410bc3081201fcb5fa5185` | 单独可摘（只改注释） |
| E 测试卫生七个文件 | `28d3c4d96bfe27da9bfdf461219e7f26d8a96705` | `9b5f2ff06b2697a2d56008b97d6e095aa9d4e1b3` | 单独可摘（实测见第十二节） |
| F 新测试 + pbx 测试登记 | `fe96fce8bab6cbcba821262b680c70c37336ddbe` | `a76f206d07e56e1737ce2ae6fc699373956be183` | 依赖 A、D、E |
| 合并 | `cb83ef537117de4db28857a23435ee586db47a3f` | `a76f206d07e56e1737ce2ae6fc699373956be183` | 双亲 `c0f5258c693684a65b1d8d6f77bcf499911986e2`／`fe96fce8bab6cbcba821262b680c70c37336ddbe`；首行 `merge(IC-183): 纯重构（一）——IC-178 旧列表层渲染链退役、过时注释订正、测试卫生；零行为改动` |

## 四、CI

| 项 | 分支运行 #370 | 合并后 `main` 运行 #371 |
|---|---|---|
| run id | `36371517409`（attempt 1） | `36372326884`（attempt 1） |
| 被测提交 | `fe96fce8bab6cbcba821262b680c70c37336ddbe` | `cb83ef537117de4db28857a23435ee586db47a3f` |
| 结论 | completed／success，作业（job `108768713126`）全部步骤 success | completed／success，作业（job `108771055578`）全部步骤 success |
| XCTest | 唯一 Test Case 行 943 条：943 passed／0 failed、0 skipped；`Executed 943 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC183RetireRenderChainTests` 3／3 | 唯一 Test Case 行 943 条：943 passed／0 failed、0 skipped；`Executed 943 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC183RetireRenderChainTests` 3／3 |
| 执行摘要 notice | `Executed 943 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 943 tests / 0 failures` | `Executed 943 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 943 tests / 0 failures` |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（同左） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左（同一 id、`OS:26.2, name:iPhone 16`） |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1971005，SHA-256 `0768941a0679481f1943e3dd8701fccfba298824b7c6204cd6e04734e4830e7d` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1971005，SHA-256 `c48ad9d5bd8cbbcd1412ed413c6ea5d0046726a995cfd917b0e78d30e19c9309` |
| 分段耗时 notice | `模拟器启动 91 s；xcodebuild test 295 s；总 386 s` | `模拟器启动 114 s；xcodebuild test 462 s；总 577 s` |
| artifact | `PhotoCleanupMVE-unsigned-fe96fce8bab6`（id 10950025868，1971175 字节，有效期至 2026-12-27T02:53:04Z） | `PhotoCleanupMVE-unsigned-cb83ef537117`（id 10950475164，1971175 字节，有效期至 2026-12-27T03:05:35Z） |

数据来源：`gh run view <id> --json …`、`check-runs/<job id>/annotations`、`actions/runs/<id>/artifacts`，以及整包日志 zip 中逐步日志（剔 `##[error]` 与 ANSI 回显行后按唯一 Test Case 行计数；「9_运行 XCTest.txt」单文件取目的地行与结尾行）。

项数对账：基线 940（IC-182 合并后 #369）+ 本卡新增 3 条（F 子项；A、D、E 不增删测试，E 的四个改名不改项数）= **943**，与 #370 唯一 Test Case 行数（943 passed／0 failed）、`Executed 943 tests` 行、执行摘要 notice 三者一致。本机锚定 `^\s*func\s+test` 计数：A／D／E 提交前 940，F 提交前 943。

闸门 G1011 相关测试类（#370 唯一 Test Case 行，全部 passed）：`IC183RetireRenderChainTests` 3／3、`IC177UnifiedBackgroundTests` 3／3、`IC178DeckListTests` 5／5、`IC151AmbientFixedColorTests` 7／7、`IC172GlassAlwaysDarkTests` 7／7、`IC171CategoryPageTrioTests` 4／4、`IC156CategoryPageTests` 9／9、`IC148S0VisualTests` 12／12、`IC128S1VisualTests` 15／15、`IC153ScanServiceTests` 13／13、`IC162DeckPreviewTests` 3／3、`IC146ChromeRoundTwoTests` 19／19、`IC147S0BehaviorTests` 16／16、`IC157LongPressIntoS2Tests` 8／8、`IC165DeckFormalTests` 6／6。四个改名后的函数 `testIC153A_AggregationDedupesHeroAndCategoriesByAttribution`、`testIC162A_CardsKeepOrderDropEmptyAndIncludeRest`、`testIC162A_RestCardOmittedWhenNoRestRow`、`testIC148CAssertion10CatalogS0KeysCountAndCrossReference` 均以新名出现且 passed。

`testIC063`（陷阱 26）：#370 日志 `building pipeline` 0 行，`IC063_WARMUP_GATE_END` 1 行，用例 passed。

## 五、本地门禁（四个提交各一份，真实退出码；提交前在工作树改后态上跑）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A `732bbaf` | 0（「结构自验通过」；字符串结构扫 116 个 `.swift`、needle 变体审计扫 59 个测试文件） | 0（残留 0，目录 key 与产品源码引用一致） | 0 |
| D `d7aa2b1` | 0 | 0 | 0 |
| E `28d3c4d` | 0 | 0 | 0 |
| F `fe96fce` | 0（字符串结构扫 117 个 `.swift`、needle 变体审计扫 60 个测试文件，含新测试） | 0 | 0 |

## 六、子项计数实测表（卡面值 / 实测值）

剔注释口径 = 测试 `strippedSource` 的 Python 移植 `decision-tools/strip.py`（只读调用），不重叠计数；切片口径同测试。脚本 `scratchpad/ic183-exec/counts.py` 在各段提交前的工作树上累计跑（后段复跑前段全部项）：A 39／39、D 53／53、E 84／84、F 90／90 全相等，退出码 0。

**A 提交前（工作树，累计口径 `counts.py A`：39 ok / 39；下表只列本段新增项）**

| 项 | 卡面值 | 实测值 | 对读 |
|---|---|---|---|
| A S1View 剔 `S1RangeCoverThumbnail` | 0 | 0 | 相等 |
| A S1View 剔 `S1CoverImageLoading` | 0 | 0 | 相等 |
| A S1View 剔 `S1PhotoKitCoverImageLoader` | 0 | 0 | 相等 |
| A S1View 剔 `coverImageLoader` | 0 | 0 | 相等 |
| A S1View 剔 `S1ProgressLineStyle` | 0 | 0 | 相等 |
| A S1View 剔 `PHImageManager` | 0 | 0 | 相等 |
| A S1View 剔 `PHAsset.fetchAssets` | 0 | 0 | 相等 |
| A S1View 剔 `scaledToFill` | 0 | 0 | 相等 |
| A S1View 剔 `Image(uiImage:` | 0 | 0 | 相等 |
| A S1View 剔 `S1RangeCardMetrics.` | 3 | 3 | 相等 |
| A 枚举切片 `static let ` | 3 | 3 | 相等 |
| A 枚举切片 `static let thumbnailSide:` | 1 | 1 | 相等 |
| A 枚举切片 `static let monthLeadingInset:` | 1 | 1 | 相等 |
| A 枚举切片 `static let contentSpacing:` | 1 | 1 | 相等 |
| A S1View 剔 `S1ChromeForeground.` | 29 | 29 | 相等 |
| A S1View 剔 `S0DeckMetrics.` | 7 | 7 | 相等 |
| A S1View 剔 `ProgressView()` | 1 | 1 | 相等 |
| A S1View 剔 `s1ChromeGlassBackground(` | 4 | 4 | 相等 |
| A S1View 剔 `enterRange(` | 4 | 4 | 相等 |
| A S1View 剔 `S1RangeCoverPolicy.coverAssetID(` | 1 | 1 | 相等 |
| A S1View 剔 `S1DeckListView(` | 1 | 1 | 相等 |
| A S1View 剔 `S1YearPageView(` | 1 | 1 | 相等 |
| A S1View 原文 `colorScheme, .dark)` | 7 | 7 | 相等 |
| A S1View 原文 `.retry()` | 1 | 1 | 相等 |
| A S1View 剔 `UIApplication` | > 0 | 3 | 满足 |
| A S1View 剔 `PHPhotoLibrary` | > 0 | 1 | 满足 |
| A S1View 剔 `.primary` | > 0 | 10 | 满足 |
| A S1View 剔 `Material` | > 0 | 3 | 满足 |
| A S1View 剔 `ultraThin` | > 0 | 2 | 满足 |
| A ThumbnailView 剔 `scaledToFill` | 1 | 1 | 相等 |
| A ThumbnailView 剔 `Image(uiImage:` | 1 | 1 | 相等 |
| A S1View 连续两空行 `\n\n\n`（基线值） | 0 | 0 | 相等 |
| A IC177 `(Self.s1Path, 29, 7, 1)` | 1 | 1 | 相等 |
| A IC177 `(Self.s1Path, 31, 7, 1)` | 0 | 0 | 相等 |
| A IC178 `("S1ChromeForeground.", 29)` | 1 | 1 | 相等 |
| A IC178 `("S1ChromeForeground.", 31)` | 0 | 0 | 相等 |
| A IC151 `Features/Shared/ThumbnailView.swift` | 1 | 1 | 相等 |
| A IC151 `strippedSource(...S1View.swift)` | 0 | 0 | 相等 |
| XCTest 锚定 `^\s*func\s+test` 计数 | 940 | 940 | 相等 |

**D 提交前（工作树，累计口径 `counts.py D`：53 ok / 53；下表只列本段新增项）**

| 项 | 卡面值 | 实测值 | 对读 |
|---|---|---|---|
| D 扫描服务原文 `同一个命中判定` | 0 | 0 | 相等 |
| D 扫描服务原文 `同一个归属判定` | 1 | 1 | 相等 |
| D HomeModel 原文 `showsDisclosure` | 0 | 0 | 相等 |
| D HomeView 原文 `showsDisclosure` | 0 | 0 | 相等 |
| D Selection 原文 `不预勾任何项` | 0 | 0 | 相等 |
| D Selection 原文 `保留集 ∩ 当前列表` | 1 | 1 | 相等 |
| D S0LibraryScanService.swift 剔注释与基线逐字节相同 | True | True | 相等 |
| D S0LibraryScanService.swift 行数与基线相同 | 856 | 856 | 相等 |
| D S0DeckHomeModel.swift 剔注释与基线逐字节相同 | True | True | 相等 |
| D S0DeckHomeModel.swift 行数与基线相同 | 172 | 172 | 相等 |
| D S0DeckHomeView.swift 剔注释与基线逐字节相同 | True | True | 相等 |
| D S0DeckHomeView.swift 行数与基线相同 | 1156 | 1156 | 相等 |
| D S0CategoryPageSelection.swift 剔注释与基线逐字节相同 | True | True | 相等 |
| D S0CategoryPageSelection.swift 行数与基线相同 | 133 | 133 | 相等 |
| XCTest 锚定 `^\s*func\s+test` 计数 | 940 | 940 | 相等 |

**E 提交前（工作树，累计口径 `counts.py E`：84 ok / 84；下表只列本段新增项）**

| 项 | 卡面值 | 实测值 | 对读 |
|---|---|---|---|
| E 新名 `func testIC153A_AggregationDedupesHeroAndCategoriesByAttribution(` 全测试 | 1 | 1 | 相等 |
| E 新名 `testIC153A_AggregationDedupesHeroAndCategoriesByAttribution` 全测试（不含 IC183 新测试） | 1 | 1 | 相等 |
| E 旧名 `testIC153A_AggregationDedupesHeroButNotCategories` 全测试（不含 IC183 新测试） | 0 | 0 | 相等 |
| E 旧名 `testIC153A_AggregationDedupesHeroButNotCategories` selfcheck.ps1 | 0 | 0 | 相等 |
| E 新名 `func testIC162A_CardsKeepOrderDropEmptyAndIncludeRest(` 全测试 | 1 | 1 | 相等 |
| E 新名 `testIC162A_CardsKeepOrderDropEmptyAndIncludeRest` 全测试（不含 IC183 新测试） | 1 | 1 | 相等 |
| E 旧名 `testIC162A_CardsKeepOrderDropEmptyAndAppendRest` 全测试（不含 IC183 新测试） | 0 | 0 | 相等 |
| E 旧名 `testIC162A_CardsKeepOrderDropEmptyAndAppendRest` selfcheck.ps1 | 0 | 0 | 相等 |
| E 新名 `func testIC162A_RestCardOmittedWhenNoRestRow(` 全测试 | 1 | 1 | 相等 |
| E 新名 `testIC162A_RestCardOmittedWhenNoRestRow` 全测试（不含 IC183 新测试） | 1 | 1 | 相等 |
| E 旧名 `testIC162A_RestCardOmittedWhenZero` 全测试（不含 IC183 新测试） | 0 | 0 | 相等 |
| E 旧名 `testIC162A_RestCardOmittedWhenZero` selfcheck.ps1 | 0 | 0 | 相等 |
| E 新名 `func testIC148CAssertion10CatalogS0KeysCountAndCrossReference(` 全测试 | 1 | 1 | 相等 |
| E 新名 `testIC148CAssertion10CatalogS0KeysCountAndCrossReference` 全测试（不含 IC183 新测试） | 1 | 1 | 相等 |
| E 旧名 `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` 全测试（不含 IC183 新测试） | 0 | 0 | 相等 |
| E 旧名 `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` selfcheck.ps1 | 0 | 0 | 相等 |
| E IC146 原文 `waitUntil(` | 0 | 0 | 相等 |
| E IC146 连续两空行 `\n\n\n`（基线值） | 0 | 0 | 相等 |
| E IC147 名单切片 `"PhotoCleanupMVE/` | 7 | 7 | 相等 |
| E IC157 原文 `"makeS2Handoff(virtualRangeID:"` | 0 | 0 | 相等 |
| E IC157 原文 `"makeS2Handoff("` | 1 | 1 | 相等 |
| E App 剔 `'makeS2Handoff('` | 1 | 1 | 相等 |
| E App 剔 `'makeS2Handoff(\n'` | 1 | 1 | 相等 |
| E App 剔 `'virtualRangeID:'` | 3 | 3 | 相等 |
| E App 剔 `'enterS2(from:'` | 2 | 2 | 相等 |
| E App 剔 `'S0CategoryPageRange.prefix'` | 2 | 2 | 相等 |
| E App 剔 `'S0CleanupFlowModel()'` | 1 | 1 | 相等 |
| E App 剔 `'flowModel: s0FlowModel'` | 1 | 1 | 相等 |
| E App 剔 `'coordinator.enterConfirmationFromS0()'` | 1 | 1 | 相等 |
| E App 剔 `'advanceScan()'` | 2 | 2 | 相等 |
| E App 剔注释去全部空白与基线相同 | True | True | 相等 |
| XCTest 锚定 `^\s*func\s+test` 计数 | 940 | 940 | 相等 |

**F 提交前（工作树，累计口径 `counts.py F`：90 ok / 90；下表只列本段新增项）**

| 项 | 卡面值 | 实测值 | 对读 |
|---|---|---|---|
| XCTest 锚定 `^\s*func\s+test` 计数 | 943 | 943 | 相等 |
| F pbx `100000000000000000000082` | 3 | 3 | 相等 |
| F pbx `20000000000000000000007F` | 2 | 2 | 相等 |
| F pbx 重复定义 id | [] | [] | 相等 |
| F pbx 最大 fileRef | 100000000000000000000082 | 100000000000000000000082 | 相等 |
| F pbx 最大 buildFile | 20000000000000000000007F | 20000000000000000000007F | 相等 |
| F 新测试 git hash-object | 69541cdca734fc08798b1a0ed47ac5b63405b369 | 69541cdca734fc08798b1a0ed47ac5b63405b369 | 相等 |

说明：E 段「新名全测试」计数排除了 F 才加入的 `IC183RetireRenderChainTests.swift`（它以字符串持有新旧名作 needle）；卡面「四个新函数名各在全部测试文件里恰 1、旧名 0」是 E 段口径，E 提交时该文件尚不存在，两种口径在 E 提交上结果相同。

## 七、零行为钉子与 `check_ic183.py` 输出（`IC183_BASE=c0f5258… python -B check_ic183.py <tip> <段>`）

| 段 | tip | SUMMARY | FAIL 行 | 退出码 |
|---|---|---|---|---|
| A | `732bbaf99499ffe65a38cf2f262ebd85fb6c8a3c` | 118 pass / 118 | 0 | 0 |
| D | `d7aa2b13833e40180f652faa6a8fb7a23e4578f9` | 118 pass / 118 | 0 | 0 |
| E | `28d3c4d96bfe27da9bfdf461219e7f26d8a96705` | 118 pass / 118 | 0 | 0 |
| F | `fe96fce8bab6cbcba821262b680c70c37336ddbe` | 119 pass / 119 | 0 | 0 |

F 段两条零行为钉子原样输出：

```
PASS App stripped text unchanged except whitespace (sha of joined) got e546a46af1edd67dc9fd38c6b14b67544029c4fe want e546a46af1edd67dc9fd38c6b14b67544029c4fe
PASS stripped unchanged (comments only, sha) S0LibraryScanService.swift got d9b3edd42049b54fc53ae5d5175fa3baac2204e7 want d9b3edd42049b54fc53ae5d5175fa3baac2204e7
PASS stripped unchanged (comments only, sha) S0DeckHomeModel.swift got 3c3bfa9f4938b6778b0055a8508c81c7dc69a8d2 want 3c3bfa9f4938b6778b0055a8508c81c7dc69a8d2
PASS stripped unchanged (comments only, sha) S0DeckHomeView.swift got 15ab887be1133a2774155a136e65d435e0ae8089 want 15ab887be1133a2774155a136e65d435e0ae8089
PASS stripped unchanged (comments only, sha) S0CategoryPageSelection.swift got f04276289ad344d84bcf5617f373b370d40dc593 want f04276289ad344d84bcf5617f373b370d40dc593
```

`sim_ic183.py c0f5258…`（只对基线跑一次）：`anchors OK; edited: 16 files`，XCTest 940 → 943，`FAILURES 0 []`，退出码 0。

## 八、拷入文件

- `cp Tasks/decision-tools/IC183RetireRenderChainTests.swift PhotoCleanupMVETests/`；`cmp` 逐字节相同；`git hash-object PhotoCleanupMVETests/IC183RetireRenderChainTests.swift` = `69541cdca734fc08798b1a0ed47ac5b63405b369`，与卡面相等；F 提交中该路径 blob 同值。文件未改动任何一行。

## 九、闸门 G1010～G1013

- **G1010（零行为）**：满足。`check_ic183.py` 在 A／D／E／F 四个 tip 上全 PASS（含「D 四文件剔注释逐字节不变」与「App 剔注释去空白不变」两条，见第七节）；#370 绿，940 项既有测试全 passed（943 − 3 新）、0 失败。skip 变化：#370 日志无 `skipped` 的 Test Case 行（与基线口径同）。
- **G1011（新断言）**：满足。`testIC183A_RenderChainRetired`、`testIC183D_StaleCommentsRewritten`、`testIC183E_TestHygiene` passed；卡列十四个测试类全部 passed（第四节）。
- **G1012（合并前置）**：满足。G1010～G1011；`git diff --name-only c0f5258..fe96fce` 恰 **17** 路径；`check_ic183.py` F 段全部 `untouched …` 项与 `catalog blob unchanged` 项 PASS（SUMMARY 119／119、FAIL 0）；二十八条被保护分支 tip 未变（第十节）；CI 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice，第四节）；pbxproj 撞号扫描通过（第十一节）；合并前工作树净；合并前 `git ls-remote origin refs/heads/main` = `c0f5258c693684a65b1d8d6f77bcf499911986e2`（未被他人推进）。
- **G1013（合并后）**：满足。合并后 `main` 运行 #371（run `36372326884`）绿，943／0，真实退出码 0；artifact `PhotoCleanupMVE-unsigned-cb83ef537117`（id 10950475164，1971175 字节，有效期至 2026-12-27T03:05:35Z）。

## 十、被保护分支（28 条，合并前 `ls-remote` 一次）

`Reports/IC-182/self-check.md` 第十节列名的 27 条 + `feature/ic-182-tutorial-round-two` `1dbf0136d07c16f1566790b17be7be91d1541098`：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`、`feature/ic-169-marked-state-follows-basket` `bf9551e`、`feature/ic-175-similar-recognizer` `8d5bc7b`、`feature/ic-177-unified-background` `3cdae92`、`feature/ic-179-inline-hints` `3de1609`、`feature/ic-180-s5-guide-steps` `219be48`、`feature/ic-178-year-deck-and-page` `ed8c9bf`、`feature/ic-182-tutorial-round-two` `1dbf013`——**28／28 与远端头相符**。合并前全部远端 ref 共 103 行（= IC-182 报告的 102 行 + 本分支一行）。

## 十一、pbxproj 撞号扫描与新 id

- 登记前重扫（工作树 = E 提交态）：最大 fileRef `100000000000000000000081`、最大 buildFile `20000000000000000000007E`，与卡面一致；`100000000000000000000082`／`20000000000000000000007F` 在登记前出现 0 次——无撞号。
- 登记后：`100000000000000000000082` 3 处、`20000000000000000000007F` 2 处；`= {isa = ` 定义行无重复 id；最大号即两个新 id。

## 十二、摘取关系实测（本机克隆 `scratchpad/ic183-exec/clone`，`git clone --no-hardlinks` 原仓，自 `c0f5258` 起，未推送）

| 摘取 | 命令 | 退出码 | 结果树 | 对照 |
|---|---|---|---|---|
| A 单独 | `git cherry-pick -x 732bbaf99499ffe65a38cf2f262ebd85fb6c8a3c` | 0 | `9c49457b76373f669a7e980cbfad1288209a52f6` | 与 A 提交树 `9c49457b76373f669a7e980cbfad1288209a52f6` 相同 |
| E 单独 | `git cherry-pick -x 28d3c4d96bfe27da9bfdf461219e7f26d8a96705` | 0 | `75087f4e6e19d15b0bc371446d059f20f55e3473` | 改动路径集合 = E 提交的七个路径；七个文件 blob 逐个等于 E 提交中对应 blob；其余路径同基线 |

注：克隆继承了本机全局 `core.autocrlf=true`，检出后再设 `false`，克隆工作树因此有 7 个与本卡无关的文件显示换行差异（`.gitattributes`、`Scripts/fixtures/*.log` 等）；上表比对的是提交对象的树与 blob，不受工作树换行影响。

## 十三、三条新断言与函数名（#370 均 passed）

1. `testIC183A_RenderChainRetired`——渲染链已从 `S1View` 与整个产品源码退役、`S1RangeCardMetrics` 只剩三值、页头／菜单／玻璃 helper 计数不动（含正对照）。
2. `testIC183D_StaleCommentsRewritten`——六处过时注释（D 四处 + A8 + E3）旧说法 0、两处新说法 1（读原文）。
3. `testIC183E_TestHygiene`——IC146 `func waitUntil(` 0、IC147 名单切片、IC157 新旧 needle、App `makeS2Handoff(` 与换行、四个改名新 1 旧 0。

## 十四、根因假设

- 本卡不含根因假设（纯重构）。卡面「事实基础」表各条在执行中均与实测一致（计数见第六节）。

## 十五、规格欠账

- 无（卡「规格欠账」节原样）。

## 十六、人工判定项

- 无。零行为改动，真机不需要判；合并后 `main` 产物与 #369 功能等价。若 Lynn 装包，装最新 `main` 产物即可。

## 十七、发现但未处理（按纪律只报告不修）

1. IC-184 范围的口径枚举与展开 API 仍在：`S1ProgressLinePresentation.isVisible`、`S1PendingBadgePresentation`、`S1RangeCardPresentation`、`S1YearStackStyle`、`S1RangeCoverPolicy.targetPixelSize`、`S1CoverImagePhase`、`S1NotificationBadgeStyle.cardRing`、`collapsedYearRangeIDs`／`isYearExpanded`／`toggleYearExpansion`／`S1RangeRow.isExpanded`（卡预登记）。
2. `S1View.swift` 的 `import UIKit`／`Photos`／`PhotosUI` 保留；`UIImage`／`PHAsset`／`PHImageManager` 剔注释后已无使用者（`UIApplication` 3、`PHPhotoLibrary` 1 仍在，import 仍需）。#370 编译无错（卡红因清单 (3) 未使用告警不红，未查告警文本）。
3. `S1RangeCardMetrics` 留三值（`thumbnailSide`／`monthLeadingInset`／`contentSpacing`），仍被 IC128 经 `targetPixelSize`／`leadingInset` 间接调用，归 IC-184。
4. `S2AmbientMetrics` 正名代价（5 文件 46 处 + 规格与日志 16 处），本卡不做。
5. `S1ChromeForeground` 注释 `:80-81`「范围卡待删红点描边取卡片底色」仍指 IC-184 范围的 `cardRing`；`S1View.swift` 原 `:1621`「展开集合恒空」注释归 IC-184。

## 十八、40 位 SHA 核验（`git cat-file -e`）

对两份报告里出现的全部 40 位十六进制串逐个跑 `git cat-file -t <sha>` 取类型、再跑 `git cat-file -e <sha>^{<类型>}`（本机原仓）。`check_ic183.py` 输出里的五个剔注释文本哈希（`hash-object --stdin` 现算、不写入对象库）不是仓库对象，单列不核。

| SHA | 类型 | `cat-file -e` 退出码 |
|---|---|---|
| `09a692b65b7ef4690cafe28fc47c22142cb93167` | blob | 0 |
| `0c613e17aae6a08ed4abe8835b4979fd0b4933bc` | blob | 0 |
| `117f4c56ee953262ca22ad59c8569de6a1c1e7fb` | blob | 0 |
| `156ed9c74a3ca9633607db1109fc0d3330ff0930` | blob | 0 |
| `1dbf0136d07c16f1566790b17be7be91d1541098` | commit | 0 |
| `22a969715e66977f63926c1b7abe7e52490160bf` | blob | 0 |
| `28d3c4d96bfe27da9bfdf461219e7f26d8a96705` | commit | 0 |
| `33228171fd50039483e10e1665b7ff9b2f51b737` | blob | 0 |
| `3e2f45029d54a0748cf00d1c2476c1c10188975b` | blob | 0 |
| `41acce5c9bab74e780f779ae5162841e32035c6e` | blob | 0 |
| `4dddc8fdb3568c0235a636d8243c418160b9fb16` | blob | 0 |
| `52a82fd03cb778c88f6d7ea3018f22502d0eeed7` | blob | 0 |
| `559b0c7cd6f2510fd3973a5d47cf668c6921c523` | blob | 0 |
| `5e550bb7c385871f12ef97ce26f7344f7782e53f` | blob | 0 |
| `66daa12f121101180a506205557b425beec3b87d` | blob | 0 |
| `69541cdca734fc08798b1a0ed47ac5b63405b369` | blob | 0 |
| `69ccec5d5797f73076a51ed35b7f2d434bfa6ee2` | commit | 0 |
| `6c314da0aaf76b4fd23f9103f4b22e82e93650c6` | blob | 0 |
| `732bbaf99499ffe65a38cf2f262ebd85fb6c8a3c` | commit | 0 |
| `75087f4e6e19d15b0bc371446d059f20f55e3473` | tree（只在克隆里） | 原仓 128（预期：第十二节 E 单独摘取的结果树只存在于 scratchpad 克隆、未推送）；克隆里 `git -C clone cat-file -e 75087f4e6e19d15b0bc371446d059f20f55e3473^{tree}` 0 |
| `822fbf5d5792a09762a54ecb2cc5bab39bea97ec` | blob | 0 |
| `89bbd814d3571cf3788eee4a572b9ff9f7c8f359` | blob | 0 |
| `8b2168801c41ffcfe51e13dd0ec9620bf1e60136` | blob | 0 |
| `8f11c1559205c9f0e247438c2ad27b1ed41da1ea` | blob | 0 |
| `91c89d8258a92d9869001a5c2a9bf39b92110090` | blob | 0 |
| `959a9e602b8e23961df5334db6440488f636487d` | blob | 0 |
| `96ab5dce0a2f56ad94399dc3f818bfb68b4383b4` | blob | 0 |
| `986a6a0b11e2f4a04b410bc3081201fcb5fa5185` | tree | 0 |
| `9a4987df8bee3d615eaea689c57f5bb773091d53` | blob | 0 |
| `9b5f2ff06b2697a2d56008b97d6e095aa9d4e1b3` | tree | 0 |
| `9c49457b76373f669a7e980cbfad1288209a52f6` | tree | 0 |
| `a76f206d07e56e1737ce2ae6fc699373956be183` | tree | 0 |
| `ac56360426a28414e2437ef0791e6ba9aa088ec3` | blob | 0 |
| `b675939192d08301e43059eafc46ce8d80a5bbc8` | blob | 0 |
| `b699fd18fa035520368f73f7d7fddef779b4362c` | blob | 0 |
| `c0f5258c693684a65b1d8d6f77bcf499911986e2` | commit | 0 |
| `c545a5a1dffb2c81651c30ba7f6355917d9eabb9` | blob | 0 |
| `cb83ef537117de4db28857a23435ee586db47a3f` | commit | 0 |
| `cd04f5f0fba29b35d389b243ae9eefe926d6fd19` | blob | 0 |
| `d114ac601f1131babd290fa39ab3b59f03e42af2` | blob | 0 |
| `d53b67bc3878beada4b204d24487bd18b04ebb7c` | blob | 0 |
| `d7aa2b13833e40180f652faa6a8fb7a23e4578f9` | commit | 0 |
| `e40100309d9703f709527b001a690daaa4f564db` | blob | 0 |
| `eeccb6f99f48959ff160bec075cc0193fff3c9d8` | blob | 0 |
| `f9e490435c98eef99b180aa5482982d3aab37708` | blob | 0 |
| `fe96fce8bab6cbcba821262b680c70c37336ddbe` | commit | 0 |

共 46 个对象：45 个在原仓 `cat-file -e` 退出码 0；1 个（E 单独摘取的结果树）只在克隆里、克隆内退出码 0。不核的剔注释文本哈希 5 个：`15ab887be1133a2774155a136e65d435e0ae8089`、`3c3bfa9f4938b6778b0055a8508c81c7dc69a8d2`、`d9b3edd42049b54fc53ae5d5175fa3baac2204e7`、`e546a46af1edd67dc9fd38c6b14b67544029c4fe`、`f04276289ad344d84bcf5617f373b370d40dc593`。
