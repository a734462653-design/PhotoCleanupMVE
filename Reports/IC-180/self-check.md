# IC-180 自验报告

## 一、结论（先行）

**已合并、已推送、合并后运行绿。** 分支 `feature/ic-180-s5-guide-steps` 三个子项各自独立提交 A→B→C，一次推送后 CI **#364 绿 930／0**；G998 全部满足后 `--no-ff` 合并入 `main`（合并提交 `496835aa998b98e03951d7c039830103689dec98`）并推送，合并与推送各一次通过、未被分类器拦；合并后 `main` 自动运行 **#365 绿 930／0**。CI 预算 1／3（分支一次绿）。

- 子项 A～C 的全部改法逐字取自任务卡代码块：执行端脚本 `scratchpad/ic180-exec/apply.py` 从卡面按顺序取出 20 个代码块（A 八个 text + 两个 json、B 两个 swift、C 八个 text），每处锚句在当时工作树上**恰 1 处**、数对后才替换（单点替换，十处全部 1／1）。
- 两个拷入文件逐字节拷入（`cp`），`git hash-object` 实测等于卡面：`S5GuideStepsView.swift` = `dd0c32358a5b6d49e379e5c3bb8e0039b28af595`，`IC180GuideStepsTests.swift` = `5ef2eec6827ed367c860f6c5931778747da932a2`；未改任何一行。
- 每个子项提交前，改后计数与卡面「改后」逐条对读：A 50 行、B 83 行、C 92 行，**0 处不符**（第六节）。决策会话验收脚本 `check_ic180.py` 在三个提交上 A 95／95、B 95／95、C 96／96 全过。C 提交的三个被改文件与 `sim_ic180.py` 在基线上预演写出的 `decision-tools/sim180/` 三个文件逐字节相同（`cmp`）。
- 五条新断言在 #364、#365 均 passed；卡面闸门点名的既有测试类全部 passed；「不得打红」段两侧对象全部相同；`schemaVersion` 7、`S0DeckMetrics` 195、`S0DeckSymbol` 8、`S2InlineHintMetrics` 30（所在目录对象不变）、`s2.tutorial.` 10 条、`s0.` 41 条未变，目录 269 → 274（`s5.` 28 → 33）。
- **`testIC180B_SymbolsExistOnHost` passed：五个 SF Symbol 名在 iOS 26.2 模拟器宿主上 `UIImage(systemName:)` 非空，③ 转 ①**（仅限该模拟器运行时；真机 iOS 版本未覆盖）。
- 断言 1、3、5 是登记值与目录断言（夹具驱动，陷阱 1）；五行的视觉效果、行高、编号圆式样、首屏遮挡与折行只能由 Lynn 在 H95 真机判定（第十六节），执行端不代为下结论。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260926-180-s5-guide-steps.md` |
| 前置阅读 | `<top>/CLAUDE.md`；`Tasks/RESEARCH-IC-180-facts.md`（A、E、F 节）；`Tasks/REVIEW-IC-180-findings.md`（两轮：第一轮实质 0／行文 10，第二轮实质 0／行文 4） |
| 基线 `main`（开工时） | `1419065a1a10191d6b223f893d9ecdf8d4a49fc6` |
| 开工核对 1 | `git status --porcelain` 空（退出码 0，无输出） |
| 开工核对 2 | `git merge-base --is-ancestor ae26e20cdda6b09a8ea57eb4e53742374560cf0d main` 退出码 0 |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `1419065a1a10191d6b223f893d9ecdf8d4a49fc6`，与本地一致 |
| 开工核对 4 | 三个被改文件 blob 与卡面表逐个相等：`S5View.swift` `ebaa06e21e058eda239953dabd2f950aa7816787`、`Localizable.xcstrings` `8974a1db6077befc22864ba346c2d1bb55284590`、`project.pbxproj` `b72c57ba486ca46c3b016a1b5a89b4de79552315` |
| 开工核对 5 | 两个待拷入源文件 `git hash-object` 与卡面相等（`dd0c3235…`／`5ef2eec6…`） |
| 分支 | `feature/ic-180-s5-guide-steps`，改任何文件前先 `git switch -c` 自基线切出 |
| 基线预演 | `python -B sim_ic180.py 1419065…`（只对基线）退出码 0，`FAILURES 0 []`；重写的 `decision-tools/sim180/` 三个文件前后 md5 相同（无实际改动）；`decision-tools/` 下未生成 `__pycache__` |
| `schemaVersion` | 7（`S2Calibration.swift:118`，`Features/S2` 目录对象两侧相同） |
| 文案目录 | 269 → 274（`s5.` 28 → 33、`s5.guide.` 0 → 5、`实用工具` 0） |
| 合并 | `--no-ff`，合并提交 `496835aa998b98e03951d7c039830103689dec98`，父 `1419065a1a10191d6b223f893d9ecdf8d4a49fc6`（合并前 main）与 `219be48914b70e13b48941dab5b053028bdcebaf`（分支 tip = C）；合并树 `bad2c7817d7b6c3959875d9dcdf6c99d638e0558` = C 提交的树 |
| docs 提交（惯例 44） | 合并与合并后运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`） |
| 范围边界 | 只做卡内三项：新文件 `Features/Shared/S5GuideStepsView.swift` + 目录（`boundary_notice` 改值 + 五条 `s5.guide.step*`）+ pbx 产品登记；`S5View.swift` 一处（`guidanceCard`）；新测试 + pbx 测试登记。操作说明卡与任何入口、「打开系统「照片」」次要操作、S5 卡容器样式、首页「未通过」接线、`S5CardMetrics`／`S5StateElement`／四态 `elements`、App 路由均未动 |

## 三、提交列表

| 子项 | 提交 SHA | 改动 |
|---|---|---|
| A | `ecef724f9fd5d4cb7085826df5dcfefb0d0633ce` | 新文件 `Features/Shared/S5GuideStepsView.swift`（逐字节拷入）+ 目录 `boundary_notice` 改值与五条 `s5.guide.step*` + pbx 产品登记四行 |
| B | `6c3c9f5ed67bcac727ae3778e9a2b0a4d4710cee` | `S5View.swift` 一处（B1 `guidanceCard` 改两部分） |
| C | `219be48914b70e13b48941dab5b053028bdcebaf` | 新测试文件（逐字节拷入）+ pbx 测试登记四行 |
| 合并 | `496835aa998b98e03951d7c039830103689dec98` | `merge(IC-180): 教程替换第二张——S5 引导卡改文字说明 + 五步竖排，五步视图入 Shared 供首页复用` |

`git diff --name-only 1419065..219be48` 恰 5 路径：`PhotoCleanupMVE.xcodeproj/project.pbxproj`、`PhotoCleanupMVE/Features/S5/S5View.swift`、`PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift`、`PhotoCleanupMVE/Localizable.xcstrings`、`PhotoCleanupMVETests/IC180GuideStepsTests.swift`。

## 四、CI

| 项 | 分支运行 #364 | 合并后 `main` 运行 #365 |
|---|---|---|
| run id | `36286381010`（attempt 1） | `36287064667`（attempt 1） |
| 被测提交 | `219be48914b70e13b48941dab5b053028bdcebaf` | `496835aa998b98e03951d7c039830103689dec98` |
| 结论 | completed／success，作业十二步全部 success | completed／success，作业十二步全部 success |
| XCTest | 唯一 Test Case 行 930 条：930 passed／0 failed；`Executed 930 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **` | 唯一 Test Case 行 930 条：930 passed／0 failed；`Executed 930 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`；`IC180GuideStepsTests` 5／5 |
| 执行摘要 notice | `Executed 930 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 930 tests / 0 failures` | `Executed 930 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 930 tests / 0 failures` |
| 真实退出码 | 0（「运行 XCTest」步骤 success，日志末「XCTest 已全部通过。」；工作流 `set -o pipefail` + `exit "$test_status"`） | 0（「运行 XCTest」步骤 success） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，字节数 1959543，SHA-256 `66bc706cddd3a86461333d28a507af6b73577925cdc996bb546cab689299b4e9` | `PhotoCleanupMVE-unsigned.ipa`，字节数 1959543，SHA-256 `5bd4a7d021808053af36a767ac3ad343c7c35d7c8af429f31932d058f67ecb04` |
| 分段耗时 notice | `模拟器启动 92 s；xcodebuild test 388 s；总 483 s` | `模拟器启动 96 s；xcodebuild test 484 s；总 581 s` |
| artifact | `PhotoCleanupMVE-unsigned-219be48914b7`（id 10919989371，1959713 字节，有效期至 2026-12-26T01:43:07Z） | `PhotoCleanupMVE-unsigned-496835aa998b`（id 10921695513，1959713 字节，有效期至 2026-12-26T01:57:03Z） |

项数对账：基线 925（IC-179 合并后 #363）+ 本卡新增 5 条（C 子项，A、B 不增删测试）= 930，与 #364 唯一 Test Case 行数与执行摘要一致。`testIC063` 族（十一条）#364 全部 passed。

## 五、本地门禁（三个提交各一份，真实退出码）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A（提交前工作树） | 0（交叉审计 56 个测试源文件无喂错；末行「结构自验通过：……均符合要求。」） | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） | 0 |
| B（提交前工作树） | 0（56 个测试源文件） | 0 | 0 |
| C（提交前工作树） | 0（57 个测试源文件） | 0 | 0 |

## 六、子项计数实测表（卡面值 / 实测值；剔注释口径 = 测试 `strippedSource` 的 Python 移植 `decision-tools/scan.py` `stripped`，切片口径同测试 `slice`）

脚本 `scratchpad/ic180-exec/count180.py`（只读 import `decision-tools/scan.py`，`-B` 运行），按提交对象计数：A 提交 50 行 0 不符，B 提交 83 行 0 不符，C 提交 92 行 0 不符。下表为 C 提交上的全表（A 行 = 目录、pbx 产品行、新文件各行；B 行 = `S5View`／`slice` 各行；C 行 = pbx 测试行与测试文件行）。

| needle | 卡面 | 实测 | |
|---|---|---|---|
| `catalog total` | 274 | 274 | OK |
| `catalog s5.` | 33 | 33 | OK |
| `catalog s5.guide.` | 5 | 5 | OK |
| `catalog s0.` | 41 | 41 | OK |
| `catalog s2.tutorial.` | 10 | 10 | OK |
| `catalog raw 实用工具` | 0 | 0 | OK |
| `pbx 10…07C`（产品 fileRef） | 3 | 3 | OK |
| `pbx 20…079`（产品 buildFile） | 2 | 2 | OK |
| `pbx S5GuideStepsView.swift` 次数 = `ThumbnailView.swift` 次数 | 6 | 6 | OK |
| `pbx 10…07D`（测试 fileRef） | 3 | 3 | OK |
| `pbx 20…07A`（测试 buildFile） | 2 | 2 | OK |
| `pbx IC180GuideStepsTests.swift` 次数 = `IC179InlineHintsTests.swift` 次数 | 6 | 6 | OK |
| 新文件 `S1ChromeForeground.` | 6 | 6 | OK |
| 新文件 `S0DeckMetrics.` | 0 | 0 | OK |
| 新文件 `enum S5GuideMetrics {` 切片内 `static let ` | 12 | 12 | OK |
| 新文件 `enum S5GuideSymbol {` 切片内 `static let ` | 5 | 5 | OK |
| 新文件 `ForEach(S5GuideStep.allCases, id: \.rawValue)` | 1 | 1 | OK |
| 新文件 `strokeBorder(` | 1 | 1 | OK |
| 新文件 `in: Circle())` | 1 | 1 | OK |
| 新文件 `.accessibilityHidden(true)` | 1 | 1 | OK |
| 新文件 `.accessibilityElement(children: .combine)` | 1 | 1 | OK |
| 新文件 `Material`／`colorScheme`／`Color(uiColor:`／`@MainActor`／`Button`／`onTapGesture`／`Link(`／`openURL`／`preferredColorScheme` | 各 0 | 各 0 | OK（九行） |
| 新文件 IC177 十五个动态色 needle（`systemGroupedBackground`、`secondarySystemGroupedBackground`、`secondarySystemFill`、`tertiaryLabel`、`accentColor`、`systemRed`、`systemGreen`、`systemOrange`、`Color.primary`、`Color.secondary`、`uiColor: .separator`、`Color(uiColor:`、`systemBackground`、`userInterfaceStyle`、`dynamicColor(`） | 各 0 | 各 0 | OK（十五行） |
| 新文件原文 `Text("` | 0 | 0 | OK |
| 新文件原文 `return "` | 0 | 0 | OK |
| 新文件原文 `import ` | 1 | 1 | OK |
| 新文件原文 `s5.guide.step1`～`step5` | 各 1 | 各 1 | OK（五行） |
| `S5View` `S1ChromeForeground.` | 19 | 19 | OK |
| `S5View` `S0DeckMetrics.` | 1 | 1 | OK |
| `S5View` `ProgressView()` | 1 | 1 | OK |
| `S5View` `ProgressView().tint(S1ChromeForeground.secondary)` | 1 | 1 | OK |
| `S5View` IC177 十五个动态色 needle | 各 0 | 各 0 | OK（十五行） |
| `S5View` `S5GuideStepsView()` | 1 | 1 | OK |
| `S5View` `S5GuideMetrics.introBottomSpacing` | 1 | 1 | OK |
| `S5View` `if presentation.showsGuidanceCard {` | 1 | 1 | OK |
| `S5View` `DecimalVolumeFormatter.string(`（剔注释／原文） | 1／1 | 1／1 | OK |
| `guidanceCard` 切片 `S5GuideStepsView()` | 1 | 1 | OK |
| `guidanceCard` 切片 `L10n.text(` | 1 | 1 | OK |
| `guidanceCard` 切片 `S5CardMetrics.guidanceFontSize` | 2 | 2 | OK |
| `guidanceCard` 切片 `cardBackground(cornerRadius: S5CardMetrics.cornerRadius)` | 1 | 1 | OK |
| `guidanceCard` 切片 `VStack(alignment: .leading, spacing: S5GuideMetrics.introBottomSpacing)` | 1 | 1 | OK |
| `S5View` 原文 `"s5.recently_deleted.boundary_notice"` | 1 | 1 | OK |
| `S5View` 原文 ` MB"`／` GB"`／`1_000_000` | 各 0 | 各 0 | OK |
| 测试文件 `func test` 行数 | 5 | 5 | OK |
| 测试文件五个函数名各 1 | 各 1 | 各 1 | OK（五行） |

另：目录 `json.load` 可解析、274 条；`\uXXXX` 转义行改前 6、改后 6；`check_ic180.py` 核对「除 `boundary_notice` 外 A 目录 blob = 基线套卡面改法」逐字节相等。既有断言旧 → 新：**无**（卡面 B 节）。

## 七、两个拷入文件

| 文件 | 来源 | 仓内路径 | `git hash-object` 实测 | 卡面 |
|---|---|---|---|---|
| 产品 | `<top>/Tasks/decision-tools/S5GuideStepsView.swift` | `PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift` | `dd0c32358a5b6d49e379e5c3bb8e0039b28af595` | 相等 |
| 测试 | `<top>/Tasks/decision-tools/IC180GuideStepsTests.swift` | `PhotoCleanupMVETests/IC180GuideStepsTests.swift` | `5ef2eec6827ed367c860f6c5931778747da932a2` | 相等 |

## 八、闸门 G995～G999

| 闸门 | 结论 | 依据 |
|---|---|---|
| G995 五步登记与文案 | 满足 | `testIC180A_FiveStepsInSpecOrderWithSpecSentences`、`testIC180E_CatalogGainsFiveKeysAndIntroIsSpecSentence` passed；`IC134S4S5VisualTests` 10／10 passed（#364） |
| G996 符号与登记值 | 满足 | `testIC180B_SymbolsExistOnHost`、`testIC180C_MetricsMatchCanvas` passed（#364） |
| G997 源码落位 | 满足 | `testIC180D_SourceWiringAndDiscipline` passed；B 计数与卡面「改后」逐条相等（第六节）；`IC177UnifiedBackgroundTests` 3／3、`VolumeFormattingTests` 8／8、`IC147S0BehaviorTests` 16／16、`IC165DeckFormalTests` 6／6、`IC179InlineHintsTests` 9／9 全部 passed（#364） |
| G998 合并前置 | 满足 | G995～G997；`git diff --name-only 1419065..219be48` 恰 5 路径；「不得打红」段对象相同（第九节）；二十五条被保护分支 tip 未变（第十节）；#364 绿（退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice）；pbxproj 撞号扫描无撞号（第十一节）；工作树净；合并前 `ls-remote` 中 `main` 仍 `1419065…`、全部 100 行远端 ref 与开工时逐行相同（未被他人推进） |
| G999 合并后 | 满足 | #365（第四节） |

## 九、「不得打红」段对象比对（基线 `1419065` vs C `219be48`，`check_ic180.py` C 段输出）

| 路径 | 基线对象 | C 对象 |
|---|---|---|
| `PhotoCleanupMVE/Core` | `796859519b61fd2894ecbc13a4399e4398037f7c` | 相同 |
| `PhotoCleanupMVE/Services` | `ae83298b1925e1defabbcf8a762a6ecd3032ba78` | 相同 |
| `PhotoCleanupMVE/App` | `ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e` | 相同 |
| `PhotoCleanupMVE/Features/S0` | `498da0346fdb9a6a59db517425d4d97047bda033` | 相同 |
| `PhotoCleanupMVE/Features/S1` | `51f4c848fb59c821db3db0aa671fd898784ad2b4` | 相同 |
| `PhotoCleanupMVE/Features/S2` | `fa575d3bfcb682397ade667578785b27c0350b0e` | 相同 |
| `PhotoCleanupMVE/Features/S3` | `be64dc867250a9edea24145b473b6bb8d25752a2` | 相同 |
| `PhotoCleanupMVE/Features/S4` | `0d1c3618b0d435fad79067210205a0b8014d60cc` | 相同 |
| `.github` | `74088388c62a10eb277921ecf74e766a2d407e80` | 相同 |
| `Scripts` | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 相同 |
| `Features/Shared/S0DeckAssetDates.swift` | `bea428d8974ad233476f6cb8ceedb315449ec5db` | 相同 |
| `Features/Shared/S0DeckCoverView.swift` | `6a5c321e06e5b1b33908b19623e11294f05174a1` | 相同 |
| `Features/Shared/ThumbnailView.swift` | `f506bf53dbfc8190ec052bde9a35a4a99f574657` | 相同 |
| `Features/Shared` 新增文件集合 | — | 恰 `S5GuideStepsView.swift` |
| `Features/S5` 文件集合 | `S5View.swift` | 不变 |
| 测试目录既有 56 个文件 | 逐个 blob | 逐个相同；新增文件集合恰 `IC180GuideStepsTests.swift` |

`schemaVersion` 7、`S0DeckMetrics` 195、`S0DeckSymbol` 8（`Features/S0` 对象相同）、`S2InlineHintMetrics` 30（`Features/S2` 对象相同）、`s2.tutorial.` 10、`s0.` 41（第六节）。

## 十、被保护分支（25 条，开工推送后与合并前各 `ls-remote` 一次）

`Reports/IC-179/self-check.md` 第十节列名的 24 条 + `feature/ic-179-inline-hints` `3de1609`：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`、`feature/ic-169-marked-state-follows-basket` `bf9551e`、`feature/ic-175-similar-recognizer` `8d5bc7b`、`feature/ic-177-unified-background` `3cdae92`、`feature/ic-179-inline-hints` `3de1609`——**25／25 与远端头前缀相符**；合并前复查：全部远端 ref（共 100 行，含本分支）与第一次快照逐行相同。

## 十一、pbxproj 撞号扫描与新 id

- 登记前重扫：最大 fileRef `10000000000000000000007B`、最大 buildFile `200000000000000000000078`（与卡面相符）；四个新 id 在基线 0 命中。
- 新 id：产品 fileRef `10000000000000000000007C`（3 处）／buildFile `200000000000000000000079`（2 处），测试 fileRef `10000000000000000000007D`（3 处）／buildFile `20000000000000000000007A`（2 处）；C 提交上无重复定义（`check_ic180.py` `pbx duplicate definition ids` = `[]`）。
- 产品文件在 Shared 组 `30000000000000000000000B` 接在 `S0DeckAssetDates.swift` 之后、产品 Sources 阶段接在 `S0DeckAssetDates.swift（源码）` 之后；测试文件接在 `IC179InlineHintsTests.swift` 各行之后。八行均为卡面原文，制表符与邻行相同。

## 十二、五条新断言与函数名（#364、#365 均 passed）

| 断言 | 函数 | 钉的内容 |
|---|---|---|
| 1 | `testIC180A_FiveStepsInSpecOrderWithSpecSentences` | 五步顺序与规格原句、第 1 步 lead、`boundary_notice` 新值（不含「截图」「实用工具」） |
| 2 | `testIC180B_SymbolsExistOnHost` | 五个 SF Symbol 在宿主 `UIImage(systemName:)` 非空与常量值 |
| 3 | `testIC180C_MetricsMatchCanvas` | `S5GuideMetrics` 十二个登记值 |
| 4 | `testIC180D_SourceWiringAndDiscipline` | S5View IC177 三计数不变、引导卡切片两部分、新文件纪律与计数 |
| 5 | `testIC180E_CatalogGainsFiveKeysAndIntroIsSpecSentence` | 目录五条 key、六个取值各恰一次、`实用工具` 0 |

## 十三、摘取关系实测（本机克隆 `scratchpad/ic180-exec/pickclone`，自 `1419065` 起，未推送）

| 分支 | 操作 | 退出码 | 结果树 | 对照 |
|---|---|---|---|---|
| `pick-a` | `cherry-pick -x ecef724` | 0 | `698528f22240ebd2d491e694a6b7cb0f9ab3a6cb` | = A 提交树 |
| `pick-ab` | `cherry-pick -x ecef724 6c3c9f5` | 0 | `0aa29d36dc67e20854c08b10ce7aaf14ee3df221` | = B 提交树 |

A 单独可摘（文本层；编译自洽由结构推断：新文件不被既有文件引用，③ 未单独跑 CI）；B 依赖 A、C 依赖 A、B，与卡面一致。

## 十四、根因假设

本卡不含根因假设。

## 十五、规格欠账（按本卡实装，不算规格冲突）

1. **SPEC-S5 v7**：补文案登记节——`s5.guide.step1`～`step5` 五条与取值（= 规格原句）、`boundary_notice` 取值改为第 1 部分原句；补视觉登记节——`S5GuideMetrics` 十二值、`S5GuideSymbol` 五个 SF 名（决策会话卡内取定，非 ④）、「第 1 步实心其余描边」的编号圆式样；`:127`「打开系统「照片」」次要操作记未定项（公开 URL scheme 无文档）。
2. **SPEC-S0 v5** `:404`：首页「未通过」的五步引导指明复用 `S5GuideStepsView`（5.3 实装）。

**Decision_log 记账（非规格欠账）**：第 208 条第五节的 IC-180 定义改为「S5 五步」，操作说明卡与入口改记 IC-181（待 Lynn）。

## 十六、人工判定项（H95 七条，保留给 Lynn 装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-496835aa998b`（#365，id 10921695513，2026-12-26 前有效） 判，执行端不代为下结论）

1. 走一次删除到「清理结果」页（T0）：引导卡先一句「照片仍由系统保留。清空「最近删除」后才真正释放空间。应用无法读取或清空该位置。」，其下五行——编号圆（第 1 步实心暖白配深字，2～5 描边）+ 一句 + 行尾小符号；五句与卡面逐字相同，第 2 步写「精选集」；五行都不可点。
2. 卡片仍是同页其余卡的样子（深灰底、圆角 14），首句与 hero 副句半句相近——看观感是否可接受。
3. 未知结果页（U）同样有这张卡；取消页（C）与失败页（F）没有——U 态真机不易走到，`testIC134G` 夹具已覆盖两态口径，可跳过。
4. 照着五步在系统「照片」里走一遍：iOS 26 上第 2 步「精选集」这个名字对不对（「最近删除」在其中的「实用工具」分组下③）、打开「最近删除」要不要面容 ID（若要，五步之外的一步，记规格欠账）、第 5 步「更多 (…)」→「全部删除」对不对（规格原句，若系统改版记规格欠账）。
5. 浅色模式再看一遍：卡与五行样式不变（暖白字、深灰底）。
6. 首屏：引导卡加五步后整卡约 250 pt 高，第 5 步在首屏是否被「离开」按钮压住（可上滑）；编号圆「第 1 步实心、其余描边」这个式样（画布「编号 + 符号」式）可不可以；第 2 步「进入「精选集」，向下找到「最近删除」」折成两行时行高是否协调。
7. 一两句总评（行高 44 是否偏松、符号是否多余）。

## 十七、发现但未处理（按纪律只报告不修）

1. **`testIC180B` 五个符号 ③ → ① 的实证**：#364 在 iOS 26.2 模拟器（iPhone 16）宿主上 `UIImage(systemName:)` 五个均非空（断言 passed）；最低部署 iOS 17 的真机未覆盖。
2. **hero 副句与首句半句相近**：T0 页 `s5.t0.body`「照片仍由系统保留，去「最近删除」清空后才真正释放空间。」与新首句前半几乎重复，按规格两者都在（裁定 五），观感待 H95 第 2 条。
3. **「打开系统「照片」」次要操作未做**（裁定 六，规格 `:127`「可提供」，公开 URL scheme 无文档③）。
4. **首页「未通过」尚未接 `S5GuideStepsView`**（5.3）。
5. 复核 F11 登记：新文件 `:54` 注释写「决策会话卡内取定」，与卡面一致（第二轮后已改）；符号名选择本身待 Lynn 于 H95 确认，不属 ④。
6. 新文件注释 `:64` 引画布行号 `gen.py:414-426`，实际 `steps_list` 为 `:414-425`（复核 F4 行号小误差，hash 已锁定，未改）。
7. 新文件的「恒深色」只有断言 4 的源码 needle 守护（色全部来自 `S1ChromeForeground`），浅色模式下的实际渲染未做像素探针，归 H95 第 5 条。

## 十八、40 位 SHA 核验（`git cat-file -e`）

两份报告中出现的全部 40 位 SHA（去重 30 个）逐个 `git cat-file -t` 取类型后跑 `git cat-file -e <sha>^{<类型>}`：**30／30 退出码 0**。

| SHA | 类型 | 退出码 |
|---|---|---|
| `070ebe0107122acf07cd5dd506b6639dcd3e6e76` | blob | 0 |
| `0aa29d36dc67e20854c08b10ce7aaf14ee3df221` | tree | 0 |
| `0d1c3618b0d435fad79067210205a0b8014d60cc` | tree | 0 |
| `1419065a1a10191d6b223f893d9ecdf8d4a49fc6` | commit | 0 |
| `219be48914b70e13b48941dab5b053028bdcebaf` | commit | 0 |
| `3026fadfbe82a93e580af70354bceda7b0f0421f` | blob | 0 |
| `496835aa998b98e03951d7c039830103689dec98` | commit | 0 |
| `498da0346fdb9a6a59db517425d4d97047bda033` | tree | 0 |
| `514886dc0afc4083237c976c0f7be6ce597c50a8` | tree | 0 |
| `51f4c848fb59c821db3db0aa671fd898784ad2b4` | tree | 0 |
| `5ef2eec6827ed367c860f6c5931778747da932a2` | blob | 0 |
| `698528f22240ebd2d491e694a6b7cb0f9ab3a6cb` | tree | 0 |
| `6a5c321e06e5b1b33908b19623e11294f05174a1` | blob | 0 |
| `6c3c9f5ed67bcac727ae3778e9a2b0a4d4710cee` | commit | 0 |
| `74088388c62a10eb277921ecf74e766a2d407e80` | tree | 0 |
| `796859519b61fd2894ecbc13a4399e4398037f7c` | tree | 0 |
| `8974a1db6077befc22864ba346c2d1bb55284590` | blob | 0 |
| `9ec88f562791dadf4d4b1eed865b344f7f1333ab` | blob | 0 |
| `ae26e20cdda6b09a8ea57eb4e53742374560cf0d` | commit | 0 |
| `ae83298b1925e1defabbcf8a762a6ecd3032ba78` | tree | 0 |
| `b72c57ba486ca46c3b016a1b5a89b4de79552315` | blob | 0 |
| `bad2c7817d7b6c3959875d9dcdf6c99d638e0558` | tree | 0 |
| `be64dc867250a9edea24145b473b6bb8d25752a2` | tree | 0 |
| `bea428d8974ad233476f6cb8ceedb315449ec5db` | blob | 0 |
| `dd0c32358a5b6d49e379e5c3bb8e0039b28af595` | blob | 0 |
| `ebaa06e21e058eda239953dabd2f950aa7816787` | blob | 0 |
| `ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e` | tree | 0 |
| `ecef724f9fd5d4cb7085826df5dcfefb0d0633ce` | commit | 0 |
| `f506bf53dbfc8190ec052bde9a35a4a99f574657` | blob | 0 |
| `fa575d3bfcb682397ade667578785b27c0350b0e` | tree | 0 |
