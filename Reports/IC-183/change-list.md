# IC-183 变更清单

任务卡：`Tasks/IC-20260927-183-retire-render-chain.md`（纯重构退役卡（一）：IC-178 旧列表层渲染链退役 + 过时注释订正 + 测试卫生；零产品行为改动）。
基线：`main` = `c0f5258c693684a65b1d8d6f77bcf499911986e2`。分支：`feature/ic-183-retire-render-chain`。

## 一、提交（各自独立、按卡顺序 A → D → E → F）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `732bbaf99499ffe65a38cf2f262ebd85fb6c8a3c` | `9c49457b76373f669a7e980cbfad1288209a52f6` | `S1View.swift` 八处（A1～A8）+ IC177／IC178／IC151 各一处期望（A9～A11） |
| D | `d7aa2b13833e40180f652faa6a8fb7a23e4578f9` | `986a6a0b11e2f4a04b410bc3081201fcb5fa5185` | 四个产品文件各一处注释（D1～D4） |
| E | `28d3c4d96bfe27da9bfdf461219e7f26d8a96705` | `9b5f2ff06b2697a2d56008b97d6e095aa9d4e1b3` | 七个文件的测试卫生（E1～E9），含 App 纯空白重排与 IC157 needle 同一提交 |
| F | `fe96fce8bab6cbcba821262b680c70c37336ddbe` | `a76f206d07e56e1737ce2ae6fc699373956be183` | 新测试文件（逐字节拷入）+ pbx 测试登记四行（F1～F4） |

合并提交与 docs 提交见 `self-check.md` 第一节与第四节。

## 二、逐文件（白名单 17 路径，`git diff --name-only c0f5258..fe96fce` 恰 17 行）

| 路径 | 子项 | 基线 blob | F 提交 blob | 改动（+/− 行） |
|---|---|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | A | `117f4c56ee953262ca22ad59c8569de6a1c1e7fb` | `96ab5dce0a2f56ad94399dc3f818bfb68b4383b4` | +4／−175。A1 `S1RangeCardMetrics` 16 → 3 值（留 `thumbnailSide`／`monthLeadingInset`／`contentSpacing`，文档注释改写保留理由）；A2 删 `S1ProgressLineStyle` 整族；A3 删 `S1CoverImageLoading` 协议与 `S1PhotoKitCoverImageLoader`；A4 删 `S1RangeCoverThumbnail`（含 MARK）；A5～A7 删 `coverImageLoader` 属性／`init` 形参／赋值；A8 `separator` 注释改「卡片叠外圈描边（`S1DeckCards`）、菜单行之间」 |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | A | `f9e490435c98eef99b180aa5482982d3aab37708` | `eeccb6f99f48959ff160bec075cc0193fff3c9d8` | A9 `(Self.s1Path, 31, 7, 1)` → `29` |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | A | `41acce5c9bab74e780f779ae5162841e32035c6e` | `959a9e602b8e23961df5334db6440488f636487d` | A10 `("S1ChromeForeground.", 31)` → `29` |
| `PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift` | A | `33228171fd50039483e10e1665b7ff9b2f51b737` | `5e550bb7c385871f12ef97ce26f7344f7782e53f` | A11 正对照 `S1View.swift` → `Features/Shared/ThumbnailView.swift`（加一行注释，变量名 `s1View` → `thumbnailView`） |
| `PhotoCleanupMVE/Services/S0LibraryScanService.swift` | D | `66daa12f121101180a506205557b425beec3b87d` | `e40100309d9703f709527b001a690daaa4f564db` | D1 `categoryAssets` 文档「同一个命中判定」→「同一个归属判定（`attributedCategory`，IC-166 起无命中归 `rest`）」，仍两行 |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift` | D | `156ed9c74a3ca9633607db1109fc0d3330ff0930` | `9a4987df8bee3d615eaea689c57f5bb773091d53` | D2 `Card.isEnterable` 文档不再引用 `showsDisclosure` |
| `PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift` | D | `8b2168801c41ffcfe51e13dd0ec9620bf1e60136` | `8f11c1559205c9f0e247438c2ad27b1ed41da1ea` | D3 右箭头注释「与 `showsDisclosure` 同口径」→「与 `Card.isEnterable` 同口径」 |
| `PhotoCleanupMVE/Features/S0/S0CategoryPageSelection.swift` | D | `d114ac601f1131babd290fa39ab3b59f03e42af2` | `3e2f45029d54a0748cf00d1c2476c1c10188975b` | D4 文档补 IC-160 播种路径 |
| `PhotoCleanupMVETests/IC153ScanServiceTests.swift` | E | `0c613e17aae6a08ed4abe8835b4979fd0b4933bc` | `b699fd18fa035520368f73f7d7fddef779b4362c` | E1 MARK 注记 + `testIC153A_AggregationDedupesHeroButNotCategories` → `testIC153A_AggregationDedupesHeroAndCategoriesByAttribution` |
| `PhotoCleanupMVETests/IC162DeckPreviewTests.swift` | E | `cd04f5f0fba29b35d389b243ae9eefe926d6fd19` | `52a82fd03cb778c88f6d7ea3018f22502d0eeed7` | E2 `…AndAppendRest` → `…AndIncludeRest`；E3 过时注释；E4 `…RestCardOmittedWhenZero` → `…RestCardOmittedWhenNoRestRow` |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | E | `822fbf5d5792a09762a54ecb2cc5bab39bea97ec` | `ac56360426a28414e2437ef0791e6ba9aa088ec3` | E5 `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` → `testIC148CAssertion10CatalogS0KeysCountAndCrossReference` |
| `PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift` | E | `d53b67bc3878beada4b204d24487bd18b04ebb7c` | `91c89d8258a92d9869001a5c2a9bf39b92110090` | E6 删无调用者的 `private func waitUntil`（含文档注释与其后空行，−15） |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | E | `c545a5a1dffb2c81651c30ba7f6355917d9eabb9` | `6c314da0aaf76b4fd23f9103f4b22e82e93650c6` | E7 断言 7 名单加 `S0DeckCategoryPageView.swift`／`S0CleanupFlowView.swift`／`S0CleanupFlowModel.swift`（4 → 7） |
| `PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift` | E | `b675939192d08301e43059eafc46ce8d80a5bbc8` | `4dddc8fdb3568c0235a636d8243c418160b9fb16` | E8 needle `makeS2Handoff(virtualRangeID:` → `makeS2Handoff(` |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | E | `89bbd814d3571cf3788eee4a572b9ff9f7c8f359` | `559b0c7cd6f2510fd3973a5d47cf668c6921c523` | E9 `onEnterS2` 交接调用恢复逐参换行（纯空白；剔注释去全部空白后与基线相同） |
| `PhotoCleanupMVETests/IC183RetireRenderChainTests.swift` | F（新建） | — | `69541cdca734fc08798b1a0ed47ac5b63405b369` | 逐字节拷自 `Tasks/decision-tools/IC183RetireRenderChainTests.swift`，三条测试 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | F | `22a969715e66977f63926c1b7abe7e52490160bf` | `09a692b65b7ef4690cafe28fc47c22142cb93167` | 测试 PBXBuildFile 1、PBXFileReference 1、测试组 children 1、测试 Sources 1，四行照卡面原文（+4） |

## 三、既有断言旧 → 新（只改期望，不删函数）

| 文件 | 位置 | 旧 | 新 |
|---|---|---|---|
| `IC177UnifiedBackgroundTests.swift` `testIC177C_…` | A9 | `(Self.s1Path, 31, 7, 1)` | `(Self.s1Path, 29, 7, 1)` |
| `IC178DeckListTests.swift` `testIC178D_SourceWiringAndDiscipline` | A10 | `("S1ChromeForeground.", 31)` | `("S1ChromeForeground.", 29)` |
| `IC151AmbientFixedColorTests.swift` `testIC151A_S0GlassSurfaceHasNoImageLayer` | A11 | 正对照 `strippedSource("PhotoCleanupMVE/Features/S1/S1View.swift")` 两词 > 0 | 正对照 `strippedSource("PhotoCleanupMVE/Features/Shared/ThumbnailView.swift")` 两词 > 0 |
| `IC147S0BehaviorTests.swift` 断言 7 | E7 | 名单 4 个文件 | 名单 7 个文件（needle 与期望 0 不变） |
| `IC157LongPressIntoS2Tests.swift` | E8 | `occurrences(of: "makeS2Handoff(virtualRangeID:", in: app) == 1` | `occurrences(of: "makeS2Handoff(", in: app) == 1` |

改名四个（E1、E2、E4、E5）不改断言内容；删除的 `waitUntil`（E6）不是测试函数。**未删除任何测试函数。**

## 四、占位值登记

- 无。本卡不改任何出厂值与登记值，`S2CalibrationConfiguration.schemaVersion` 仍 7；目录 `Localizable.xcstrings` 不动（281 key，blob 与基线相同）；`Core/` 不动。

## 五、pbxproj 新 id

- fileRef `100000000000000000000082`（出现 3 处：PBXBuildFile 引用 1、PBXFileReference 定义 1、测试组 children 1）；buildFile `20000000000000000000007F`（出现 2 处：定义 1、测试 Sources 1）。登记前重扫基线最大号 fileRef `100000000000000000000081`、buildFile `20000000000000000000007E`，与卡面一致；新 id 在基线出现 0 次；改后无重复定义 id。
