# IC-178 变更清单

任务卡：`Tasks/IC-20260927-178-year-deck-and-page.md`（「逐张整理」范围列表改 (i) 年卡叠 → 年页；页头不动）。
基线：`main` = `fcde23316c8ee4c4bca152515f7de18aa8192cd2`。分支：`feature/ic-178-year-deck-and-page`。

## 一、提交（各自独立、按卡顺序）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `33014925c99302015c4976e55d856fc5a3d0190a` | `a37707d035b6949aae6fd80406a375b2eddf0d23` | 两个新产品文件（逐字节拷入）+ 目录七条 key + pbx 产品登记八行 |
| B | `80ec98560d7f21f8bfc3943d0b30f8aca7f03fb5` | `d640ab07e2b60a0bad59c460a70a0147370938b0` | `S1StateMachine.swift` 三处（年页身份） |
| C | `96766ed97943720cc381a7a7c8c07cdc2df427d2` | `25f7d2583af98d717a9e34724f0f90b9b3879641` | `S1View.swift` 两处（`body` 包 `NavigationStack` + `rootPage`／年页绑定；列表层整段换年卡叠 + 年页构造 + 封面取法）+ IC177C 期望值一行 |
| D | `ed8c9bf7a6dfeeb453cc8377f9a6c2eecb6cf313` | `1252482f239458ef5bd3354d2aaad087b04661de` | 新测试文件（逐字节拷入）+ pbx 测试登记四行 |

合并提交与 docs 提交见 `self-check.md` 第一节与第四节。

## 二、逐文件（白名单 8 路径，`git diff --name-only fcde233..ed8c9bf` 恰 8 行）

| 路径 | 子项 | 基线 blob | D 提交 blob | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | A（新建） | — | `d275cd75204107cb4fdbf65a5441078be79b5aea` | 逐字节拷自 `Tasks/decision-tools/S1DeckCards.swift`：`S1DeckMetrics` 五十值、`S1DeckSymbol` 三名、`S1DeckCardKind`、`S1DeckCardPresentation`、`S1DeckProgressBar`、`S1DeckCardView`、`S1DeckStack`、`S1DeckListView` |
| `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | A（新建） | — | `4d0cc41734542555bfbb0171c43eb338c72db093` | 逐字节拷自 `Tasks/decision-tools/S1YearPageView.swift`：年页（返回圆钮 + 待删篮入口、年标题 +「整理整年」、汇总行、年进度条、月卡叠，隐藏导航栏与 tab bar） |
| `PhotoCleanupMVE/Localizable.xcstrings` | A | `9ec88f562791dadf4d4b1eed865b344f7f1333ab` | `911848e37193b1491b60274549db5ec1c0425a33` | 文本插入：`"s1.trash.accessibility"` 条目之后接七条（`s1.deck.year.subtitle`／`s1.deck.pending`／`s1.deck.seen`／`s1.deck.done`／`s1.yearPage.summary`／`s1.yearPage.organizeAll`／`s1.yearPage.back`），其余逐字节不变；274 → 281，`s1.` 26 → 33 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A + D | `3026fadfbe82a93e580af70354bceda7b0f0421f` | `b46d683f0052f941fd133e59ae2da0d5e42c1765` | A：PBXBuildFile 2 行、PBXFileReference 2 行、S1 组 children 2 行、Sources 2 行；D：测试 PBXBuildFile 1、PBXFileReference 1、测试组 children 1、测试 Sources 1。十二行照卡面原文 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | B | `702e599df88bef73712eaa05a83490e97b5f7d3b` | `bc80d95fc0b5e99c0be203823686c91e204e6f77` | B1 `ranges` 加 `didSet { pruneYearPageIfNeeded() }`；B2 `presentedYearRangeID` 声明（接 `collapsedYearRangeIDs` 之后）；B3 `presentYearPage`／`dismissYearPage`／`pruneYearPageIfNeeded`（接 `toggleYearExpansion` 之后）。只加不改 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | C | `9f0de919e7ef82671279de0e41867c2b0734e175` | `117f4c56ee953262ca22ad59c8569de6a1c1e7fb` | C1 `body` → `NavigationStack { rootPage … .navigationDestination(item: presentedYearRangeBinding) }` + 栈外 `.allowsHitTesting`／toast `.overlay`／`.onAppear`／`.onChange`；`rootPage` 为原根 `ZStack` 原样外提；`presentedYearRangeBinding`。C2 旧列表层（`// MARK: - IC-128 B：范围卡列表` 起 263 行）整段换成 `rangeList`（`S1DeckListView`）、`yearPage(_:)`（`S1YearPageView`）、`coverAssetID(for:)`；`enterRange` 与其后一字不动 |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | C | `844572b4973615ec681278c3f59a345a13d2b21c` | `f9e490435c98eef99b180aa5482982d3aab37708` | 一行期望值 `(Self.s1Path, 37, 7, 1),` → `(Self.s1Path, 31, 7, 1),` |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | D（新建） | — | `41acce5c9bab74e780f779ae5162841e32035c6e` | 逐字节拷自 `Tasks/decision-tools/IC178DeckListTests.swift`，五条测试 |

## 三、既有断言旧 → 新

- `IC177UnifiedBackgroundTests.testIC177C_PagesCarryNoDynamicColorsAndPositiveControlsHold`：`(Self.s1Path, 37, 7, 1)` → `(Self.s1Path, 31, 7, 1)`（C3；列表层六处 `S1ChromeForeground.` 随旧代码删除）。
- 其余既有测试文件一字未动（`check_ic178.py` D 段逐文件 blob 相等）。

## 四、新增测试（5 条，930 → 935）

1. `testIC178A_StackAndCardPresentationRules`
2. `testIC178B_YearPageIdentityLivesInMachineWithGuards`
3. `testIC178C_MetricsAndSymbolsMatchCanvas`
4. `testIC178D_SourceWiringAndDiscipline`
5. `testIC178E_CatalogGainsSevenKeys`

## 五、占位值登记

- `S2CalibrationConfiguration.schemaVersion` 仍 **7**（本卡不动出厂值）。
- 新登记族卡内暂登（SPEC-S1 v11 回填）：`S1DeckMetrics` 五十值、`S1DeckSymbol` 三名（`chevron.left`／`rectangle.stack`／`checkmark`）、七条 `s1.deck.*`／`s1.yearPage.*` key。
- `S0DeckMetrics` 仍 195、`S0DeckSymbol` 仍 8（只引用，未加值）；`s0.` 41、`s2.tutorial.` 10 不变。

## 六、pbxproj 新 id

| 文件 | fileRef | buildFile |
|---|---|---|
| `S1DeckCards.swift` | `10000000000000000000007E` | `20000000000000000000007B` |
| `S1YearPageView.swift` | `10000000000000000000007F` | `20000000000000000000007C` |
| `IC178DeckListTests.swift` | `100000000000000000000080` | `20000000000000000000007D` |

登记前重扫：fileRef 最大 `10000000000000000000007D`、buildFile 最大 `20000000000000000000007A`，六个新 id 在基线 pbx 中出现 0 次；D 态定义 id 重复 0。

## 七、未改动（「不得打红」段）

`Core/` 除 `S1StateMachine.swift` 外 8 个文件、`Services/`、`App/`、`Features/S0|S2|S3|S4|S5|Shared/`、`.github/`、`Scripts/`、除 IC177 与新测试外的全部测试文件：基线与 D 提交对象逐一相同（见 `self-check.md` 第九节）。
