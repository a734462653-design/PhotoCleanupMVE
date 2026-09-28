# IC-184 变更清单

任务卡：`Tasks/IC-20260928-184-retire-caliber-enums.md`（纯重构退役卡（二）：口径枚举 + 同页展开／收起 API 退役；零产品行为改动；整删六个只测退役符号的测试函数，裁定 一 ④ Lynn 2026-09-28 聊天追认）。
基线：`main` = `e82d050d35f1f71ec07524fee692226afb4e9fb9`。分支：`feature/ic-184-retire-caliber-enums`。

## 一、提交（各自独立、按卡顺序 B → C → D）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| B | `96322c958fe02a774fc54945d006843aa07a35fd` | `3ebaebacca988a8ee922f3f98541293c5c2e6610` | `S1View.swift` 十处（B1～B10）+ IC177 三处（B11～B13）+ IC178 一处期望（B14）+ IC128 四处（B15～B18）+ IC183 两处（B19～B20） |
| C | `06fbbd35c5d8136222b3a269338de8430c78e050` | `cf7fa4c9a0237a96969bb85cedc51c50e5acc2bb` | `S1StateMachine.swift` 七处（C1～C6、C11）+ `S1View.swift` 一处注释（C7）+ S1StateMachineTests 整删两段（C8～C9）+ IC178B 删行（C10） |
| D | `427ade499a7dff7e4384d2a77a66fbe5feba6fbd` | `77ebc40363ce98ee860fc0caffa0d8932fdd1c01` | 新测试文件（逐字节拷入）+ pbx 测试登记四行（D1～D4） |

合并提交与 docs 提交见 `self-check.md` 第一节与第四节。

## 二、逐文件（白名单 9 路径，`git diff --name-only e82d050..427ade4` 恰 9 行）

| 路径 | 子项 | 基线 blob | D 提交 blob | 改动（+/− 行） |
|---|---|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | B、C | `96ab5dce0a2f56ad94399dc3f818bfb68b4383b4` | `be813c91c3e471e7997e27be1be24f60cf4b919b` | +5／−94。B1 徽标注释改写（一行换一行）；B2 删 `S1NotificationBadgeStyle.cardRing`；B3 IC-128 B 的 MARK 改写；B4 删 `S1RangeCardMetrics` 整族（余三值）；B5 `S1ProgressLinePresentation` 文档改写（两行换两行）+ 删 `isVisible`；B6 删 `S1PendingBadgePresentation`；B7 删 `S1RangeCardPresentation`；B8 删 `S1YearStackStyle`；B9 删 `S1RangeCoverPolicy.targetPixelSize`；B10 删 `S1CoverImagePhase`；C7 年卡叠注释改写（一行换一行） |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | C | `bc80d95fc0b5e99c0be203823686c91e204e6f77` | `3b343d30528909f5233d6a82a4974a90844d5164` | +7／−40。C1 `S1RangeRow` 文档改写 + 删 `isExpanded` 字段；C2 删 `collapsedYearRangeIDs` 声明与文档 + 年页身份注释改写；C3 删 `isYearExpanded` 与 `toggleYearExpansion` + 进年页注释首行改写；C4 `visibleRanges` 文档改写 + 删收起守卫；C5 `rangeRows` 删 `isExpanded:` 实参；C6 `adoptRanges` 删求交两行；C11 `S1SessionSnapshot` 文档改写 |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | B | `9705c71d0d5a2e5864bdd34f959bafcb688c8434` | `13a6c6fe0a2c69ed59124e11a146b1d8ddaf8960` | +2／−133。B15 整删两函数；B16 注释改写 + 改名 `testIC128B_ProgressLineFraction`；B17 删 `isVisible` 两条断言；B18 整删两函数 |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | B | `eeccb6f99f48959ff160bec075cc0193fff3c9d8` | `9e6055f6ed325f31d3721aff9c62c5a5b3667606` | +4／−7。B11 IC177A 注释改写 + 删 `cardRing` 一条；B12 IC177B MARK 改写 + 改名 + 删 `S1YearStackStyle` 两条；B13 IC177C `29` → `28` |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | B、C | `959a9e602b8e23961df5334db6440488f636487d` | `fab23ebaf50bf22c12207ca739b285efbe1a405c` | +2／−6。B14 IC178D `29` → `28`；C10 IC178B 删注释 + `toggleYearExpansion` 两调用 + 两断言，留 `presentYearPage("y2026")`（六行换两行） |
| `PhotoCleanupMVETests/IC183RetireRenderChainTests.swift` | B | `69541cdca734fc08798b1a0ed47ac5b63405b369` | `c3534e4febc66e8ef17fd8e5f0fec17df1c45d7f` | +5／−12。B19 文件头注释改写；B20 IC183A 三值切片段改「`S1RangeCardMetrics` 0」+ `29` → `28` |
| `PhotoCleanupMVETests/S1StateMachineTests.swift` | C | `64114ed919a4858aa0db4364781886e88692c0ee` | `b755a6bd85b3b247a69dd477bae3e6c2c4818352` | +0／−57。C8、C9 整删两函数（含注释与其后空行） |
| `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | D（新建） | — | `e4d76bff90b5d3ab44b13e53d80ed482065afb07` | 逐字节拷自 `Tasks/decision-tools/IC184RetireCaliberEnumsTests.swift`，三条测试（+335） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | D | `09a692b65b7ef4690cafe28fc47c22142cb93167` | `e6d4721c7f1b23ba7f56cb2021fa9a69fbfdb5a5` | 测试 PBXBuildFile 1、PBXFileReference 1、测试组 children 1、测试 Sources 1，四行照卡面原文（+4） |

## 三、测试函数增删改（十三处 + 三条新测试）

**整删六个（裁定 一名单，未删名单外任何测试函数）**

| 文件 | 函数 | 子项 |
|---|---|---|
| `IC128S1VisualTests.swift` | `testIC128B_CoverTargetPixelSizeFollowsDisplayScale` | B15 |
| `IC128S1VisualTests.swift` | `testIC128B_CoverReplacementNeverDowngrades` | B15 |
| `IC128S1VisualTests.swift` | `testIC128B_PendingBadgeHiddenAtZero` | B18 |
| `IC128S1VisualTests.swift` | `testIC128B_YearRowHasSeparateExpandAndEnterTargets` | B18 |
| `S1StateMachineTests.swift` | `testIC127A_CollapsingYearHidesMonthRowsButKeepsRangeData` | C8 |
| `S1StateMachineTests.swift` | `testIC127A_ExpandAndEnterAreDistinctTargets` | C9 |

**删部分断言四个（其中两个改名）**

| 文件 | 函数（改后名） | 删去 | 子项 |
|---|---|---|---|
| `IC177UnifiedBackgroundTests.swift` | `testIC177A_ForegroundTableIsFixedPaletteInBothAppearances`（不改名） | `S1NotificationBadgeStyle.cardRing` 一条（注释改写、`chromeRing` 留） | B11 |
| `IC177UnifiedBackgroundTests.swift` | `testIC177B_YearStackHeroPaletteAndAmbientBaseAreFixed` → `testIC177B_HeroPaletteAndAmbientBaseAreFixed` | `S1YearStackStyle.layerOneColor`／`layerTwoColor` 两条（MARK 改写） | B12 |
| `IC128S1VisualTests.swift` | `testIC128B_ProgressLineFractionAndVisibility` → `testIC128B_ProgressLineFraction` | `isVisible` 两条（`fillFraction` 五条留、注释两行并一行） | B16、B17 |
| `IC178DeckListTests.swift` | `testIC178B_YearPageIdentityLivesInMachineWithGuards`（不改名） | 注释 1 行 + `toggleYearExpansion` 两调用 + 两断言（留 `presentYearPage("y2026")`，注释改写一行） | C10 |

**改期望三处**

| 文件 | 位置 | 旧 | 新 |
|---|---|---|---|
| `IC177UnifiedBackgroundTests.swift` `testIC177C_…` | B13 | `(Self.s1Path, 29, 7, 1)` | `(Self.s1Path, 28, 7, 1)` |
| `IC178DeckListTests.swift` `testIC178D_SourceWiringAndDiscipline` | B14 | `("S1ChromeForeground.", 29)` | `("S1ChromeForeground.", 28)` |
| `IC183RetireRenderChainTests.swift` `testIC183A_RenderChainRetired` | B20 | `S1RangeCardMetrics.` 3 + 三值切片（`static let ` 3、三名各 1）+ `S1ChromeForeground.` 29 | `S1RangeCardMetrics` 0 + `S1ChromeForeground.` 28 |

**新增三条**：`testIC184B_CaliberEnumsRetired`、`testIC184C_ExpandAPIRetiredAndVisibleOrderUnchanged`、`testIC184D_TestHygiene`。

项数对账：943 − 4（B 整删）− 2（C 整删）+ 3（D 新增）= **940**。

## 四、占位值登记

- 无。本卡不改任何出厂值与登记值，`S2CalibrationConfiguration.schemaVersion` 仍 7；目录 `Localizable.xcstrings` 不动（281 key，blob 与基线相同）；`Features/S1/S1DeckCards.swift`／`S1YearPageView.swift` 与 `Core/` 其余文件不动。

## 五、pbxproj 新 id

- fileRef `100000000000000000000083`（出现 3 处：PBXBuildFile 引用 1、PBXFileReference 定义 1、测试组 children 1）；buildFile `200000000000000000000080`（出现 2 处：定义 1、测试 Sources 1）。登记前（C 提交后工作树）重扫最大号 fileRef `100000000000000000000082`、buildFile `20000000000000000000007F`，与卡面一致；两个新 id 登记前出现 0 次，无撞号。
