# IC-177 自验报告

## 一、结论（先行）

**已合并、已推送、合并后运行绿。** 分支 `feature/ic-177-unified-background` 五个子项各自独立提交 A→B→C→D→E，一次推送后 CI **#360 绿 916／0**；G988 全部满足后 `--no-ff` 合并入 `main`（合并提交 `9bb803525f8186625322fecce02dc67d070409e7`）并推送，合并一次通过、未被分类器拦；合并后 `main` 自动运行 **#361 绿 916／0**。CI 预算 1／3（分支一次绿）。

- 子项 A～D 的全部改法逐字取自任务卡代码块：执行端脚本从卡面取出 56 个 ```swift 块（28 对），与 `Tasks/decision-tools/ic177_edits.py` 逐对比较 0 处不符；每个锚句在当时工作树上的命中数与卡面相等（单点 1；A6 恰 5、A8 恰 2、A9 恰 3、B6 恰 2、B7 恰 2），数对后才整体替换。
- 每个子项提交前的计数实测与卡面「改后」**逐条相等**（第六节，共 90 行对照，0 处不符）。
- 子项 E 测试文件逐字节拷入，`git hash-object` = `844572b4973615ec681278c3f59a345a13d2b21c`（与卡面相等），三条在 #360 均 passed。
- 卡面「两处必红」的既有断言（IC146 `:473-482`、IC151 `:180-181`）按卡改写，改后在 #360 passed；卡面点名的正对照与闸门用例全部 passed（第八节）。
- 「不得打红」段两侧对象全部相同（第九节）；`schemaVersion` 7、`S0DeckMetrics` 195、目录 262 未变。
- **新断言是夹具驱动：颜色在两种 trait 下解析同值，只证明取值恒定，不证明浅色模式真机观感**（陷阱 1）；浅色模式下四页与 S2 的实际观感、转圈是否认 `.tint`、覆盖内文字前景保留给 Lynn 在 H93 真机判定（第十六节）。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260926-177-unified-background.md` |
| 前置阅读 | `<top>/CLAUDE.md`；`Tasks/RESEARCH-IC-177-facts.md`（全文）；`Tasks/REVIEW-IC-177-findings.md`（两轮：第一轮实质 2／行文 6，第二轮实质 0／行文 2） |
| 基线 `main`（开工时） | `3b49e4a8bdea5fc3331dfb170689b265115f255b` |
| 开工核对 1 | `git status --porcelain` 空 |
| 开工核对 2 | `git merge-base --is-ancestor ba2f8b3bb69e874252349ce7434f74b805b22772 main` 退出码 0 |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `3b49e4a8bdea5fc3331dfb170689b265115f255b`，与本地一致 |
| 开工核对 4 | 七个文件 blob 与卡面表逐个相等：`S1View.swift` `99dd6a9ba1170c3b3dcedc26fec2e22850912eb3`、`S3View.swift` `1728293e2f5c77a79407e15b71a89fa96e8a8a62`、`S4View.swift` `358c1dca4acbb44cfbda659bfd85340e1df0ee72`、`S5View.swift` `76b06d742e42dc187518cd15aed26f74ed7a8c33`、`S2AmbientBackdrop.swift` `9fedf558d033acde95bd902f116f13904acbef29`、`IC146ChromeRoundTwoTests.swift` `4a9a3970f80447f01d0645775e62c78dbe72e1d9`、`IC151AmbientFixedColorTests.swift` `b4b908325f5d4f21586124c40aff8d48499003f0` |
| 分支 | `feature/ic-177-unified-background`，改任何文件前先 `git switch -c` 自基线切出 |
| `schemaVersion` | 7（未动；`S2Calibration.swift:118`，文件对象两侧相同） |
| `S0DeckMetrics` | 195（`S0DeckMetrics.swift` 对象两侧相同，本卡只引用不加） |
| 文案目录 | 262（`Localizable.xcstrings` 对象两侧相同） |
| 合并 | `--no-ff`，合并提交 `9bb803525f8186625322fecce02dc67d070409e7`，父 `3b49e4a8bdea5fc3331dfb170689b265115f255b`（合并前 main）与 `3cdae926a1af29ac5a19f97885737420e56a0df4`（分支 tip = E）；合并树 `7a49b7a405ad5d125ffe51ad7fec731262fad8fc` = E 提交的树 |
| docs 提交（惯例 44） | 合并与合并后运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`） |
| 范围边界 | 只换颜色取值；玻璃 helper、`GlassEffectContainer`、菜单材质与不透明度、toast、徽标几何、布局、字号、`S2View.swift`、`Features/S0/`、`App/` 一字未动 |

## 三、提交列表

| 子项 | 提交 SHA | 改动 |
|---|---|---|
| A | `aede7dedd2c1d0adfe4b13c9c2f52e1a81b9386e` | `S1View.swift` 十一处（A1～A11） |
| B | `b00dc63e691cd1c682e0921209e5f02300c4e854` | `S3View.swift` 五处（B1～B4、B6）、`S4View.swift` 两处（B5、B7） |
| C | `4d16c74d94c3623cc251fd4212ba9eb605231523` | `S5View.swift` 七处（C1～C7） |
| D | `47b656c54621eb75f009ea999ee5c48cedfd1427` | `S2AmbientBackdrop.swift` 幕底分量；IC146／IC151 两处期望 |
| E | `3cdae926a1af29ac5a19f97885737420e56a0df4` | 新测试文件（逐字节拷入）+ pbxproj 四行登记 |
| merge | `9bb803525f8186625322fecce02dc67d070409e7` | 首行 `merge(IC-177): 全屏背景统一——S1／S3／S4／S5 页面体改空间清理恒定色板、S2 幕底同步 #0B0F0D` |

## 四、CI

| 项 | #360（分支 tip E） | #361（合并后 `main`） |
|---|---|---|
| run id | `36274776527` | `36275580475` |
| 被测提交 | `3cdae926a1af29ac5a19f97885737420e56a0df4` | `9bb803525f8186625322fecce02dc67d070409e7` |
| 结论 | success（12 步全 success，attempt 1） | success（12 步全 success，attempt 1） |
| 执行摘要 notice | `Executed 916 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 916 tests / 0 failures` | `Executed 916 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 916 tests / 0 failures` |
| 整包日志唯一 Test Case 行 | 916 passed／0 failed（剔 `##[error]` 与 ANSI 回显后按单个整作业日志文件计） | 916 passed／0 failed（同口径） |
| 真实退出码 | 0（「运行 XCTest」步骤 success；工作流 `set -o pipefail` + `exit "$test_status"`；日志 `** TEST SUCCEEDED **`、`XCTest 已全部通过。`） | 0（同左） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左（同一模拟器 id `2911FD29-…`） |
| 分段耗时 notice | `模拟器启动 92 s；xcodebuild test 359 s；总 451 s` | `模拟器启动 92 s；xcodebuild test 321 s；总 415 s` |
| IPA 字节数 | 1919768 | 1919768 |
| IPA SHA-256 | `fbcdaa7d385f4056aca6ce979e7058f90de6b361e40e87bcf3fa90ae290636f6` | `f3fd29bacded7a1cc27832e8c5494a3660ff8b7f2ef15c8a394728b11f48c397` |
| artifact | `PhotoCleanupMVE-unsigned-3cdae926a1af`，id 10916632211，1919938 字节，2026-12-25T21:59:28Z 到期 | `PhotoCleanupMVE-unsigned-9bb803525f81`，id 10917402448，1919938 字节，2026-12-25T22:13:42Z 到期 |
| `testIC063` build 行 | 全日志 `building pipeline` 0 行；`IC063_WARMUP_GATE_END` 1 行 | 同左（`building pipeline` 0 行；`IC063_WARMUP_GATE_END` 1 行） |

项数对账：913（基线 #359）+ 0（A～D 不增删测试）+ 3（E 新文件三条）= 916（#360、#361）。

## 五、本地门禁（五个提交各一份，真实退出码）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A 提交前 | 0 | 0 | 0 |
| B 提交前 | 0 | 0 | 0 |
| C 提交前 | 0 | 0 | 0 |
| D 提交前 | 0 | 0 | 0 |
| E 提交前 | 0 | 0 | 0（`git add -A` 后 `git diff --cached --check`，新文件纳入） |

selfcheck 末行均为「结构自验通过…」；E 时 needle 交叉审计扫描测试源文件数 54 → 55。

另：决策会话验收脚本 `Tasks/decision-tools/check_ic177.py`（只读调用，`IC177_BASE=3b49e4a…`）在五个提交上各跑一次：A 60／60、B 90／90、C 105／105、D 105／105、E 108／108，全过（七个文件 blob = 卡面改法作用于基线对象的结果、测试文件 blob、pbx 登记、白名单 9 路径、未触碰路径）。

## 六、子项 A～D 计数实测表（卡面值 / 实测值，剔注释口径 = 测试 `strippedSource` 的 Python 移植）

### A（`S1View.swift`，提交前实测）

| needle | 卡面 | 实测 |
|---|---|---|
| `S1ChromeForeground.` | 37 | 37 |
| `S0DeckMetrics.` | 7 | 7 |
| `.primary` | 11 | 11 |
| `Material` | 3 | 3 |
| `ultraThin` | 2 | 2 |
| `static let ` | 99 | 99 |
| `s1ChromeGlassBackground(` | 4 | 4 |
| `GlassEffectContainer {` | 3 | 3 |
| `ProgressView()` | 1 | 1 |
| `ProgressView().tint(S1ChromeForeground.secondary)` | 1 | 1 |
| `systemGroupedBackground`／`secondarySystemGroupedBackground`／`secondarySystemFill`／`tertiaryLabel`／`accentColor`／`systemRed`／`systemGreen`／`systemOrange`／`Color.primary`／`Color.secondary`／`uiColor: .separator`／`Color(uiColor:`／`systemBackground`／`userInterfaceStyle`／`dynamicColor(`（15 项逐项） | 各 0 | 各 0 |
| 原文 `colorScheme, .dark)` | 7 | 7 |

### B（`S3View.swift`／`S4View.swift`，提交前实测）

| needle | 卡面 S3 | 实测 S3 | 卡面 S4 | 实测 S4 |
|---|---|---|---|---|
| `S1ChromeForeground.` | 18 | 18 | 7 | 7 |
| `ProgressView()` | 2 | 2 | 2 | 2 |
| `ProgressView().tint(S1ChromeForeground.secondary)` | 2 | 2 | 2 | 2 |
| 上表 15 项动态色 needle（逐项） | 各 0 | 各 0 | 各 0 | 各 0 |

### C（`S5View.swift`，提交前实测）

| needle | 卡面 | 实测 |
|---|---|---|
| `S1ChromeForeground.` | 19 | 19 |
| `S0DeckMetrics.` | 1 | 1 |
| `static let ` | 39 | 39 |
| `ProgressView()` | 1 | 1 |
| `ProgressView().tint(S1ChromeForeground.secondary)` | 1 | 1 |
| 15 项动态色 needle（逐项） | 各 0 | 各 0 |

### D（原文口径，提交前实测）

| needle | 卡面 | 实测 |
|---|---|---|
| 氛围底 `green: 15.0 / 255` | 1 | 1 |
| 氛围底 `blue: 13.0 / 255` | 1 | 1 |
| 氛围底 `green: 26.0 / 255` | 0 | 0 |
| 氛围底「取值出处：Decision_log 第 175／176 条」 | 12 | 12 |
| IC146 `XCTAssertEqual(red * 255, 11, accuracy: 0.6)`／`green * 255, 15`／`blue * 255, 13` | 各 1 | 各 1 |
| IC151 `assertColor(S2AmbientMetrics.baseColor, red: 11, green: 15, blue: 13)` | 1 | 1 |

合计 90 行对照（A 26、B 36、C 20、D 8），0 处不符。

## 七、两处既有断言旧 → 新（均在白名单内，按卡原文）

| 位置 | 旧 | 新 |
|---|---|---|
| `IC146ChromeRoundTwoTests.swift:473-482`（`testIC146B_AmbientMetricsMatchS0AmbientRegistry` 内） | 注释 `// ambientBaseColor = #0B1A13。`；`green * 255, 26`、`blue * 255, 19` | 注释 `// ambientBaseColor = #0B0F0D（IC-177 起，Decision_log 第 205 条；原 #0B1A13）。`；`green * 255, 15`、`blue * 255, 13`（`red` 11、alpha、tint 122／196／158 不动） |
| `IC151AmbientFixedColorTests.swift:180-181` | 注释 `#0B1A13`；`assertColor(S2AmbientMetrics.baseColor, red: 11, green: 26, blue: 19)` | 注释 `#0B0F0D（IC-177 起，Decision_log 第 205 条）`；`red: 11, green: 15, blue: 13`（tint 与十个不透明度不动） |

两处在 #360 passed（IC146 19／19、IC151 7／7）。

## 八、闸门 G985～G989

| 闸门 | 结果 |
|---|---|
| G985（四页零动态色） | `testIC177C_PagesCarryNoDynamicColorsAndPositiveControlsHold` passed；A／B／C 计数与卡面逐条相等（第六节）；`IC148S0VisualTests` 12／12（含 `testIC148AAssertion02AlwaysDarkRecipe`）、`IC172GlassAlwaysDarkTests` 7／7、`IC128S1VisualTests` 15／15、`IC134S3VisualTests` 14／14、`IC134S4S5VisualTests` 10／10 passed（#360）——**满足** |
| G986（色值恒定） | `testIC177A_ForegroundTableIsFixedPaletteInBothAppearances`、`testIC177B_YearStackHeroPaletteAndAmbientBaseAreFixed` passed——**满足** |
| G987（S2 幕底） | `IC146ChromeRoundTwoTests` 19／19、`IC151AmbientFixedColorTests` 7／7 passed（含改期望两处）；`S2CalibrationHarnessTests.testIC067G39ViewportBackgroundIsAmbientAndIgnoresInterfaceStyle` passed（该类 224／224）——**满足**；裁定三「幕底改暗后两侧仍 < 60」③ 由此在 CI 上成立① |
| G988（合并前置） | G985～G987 满足；`git diff --name-only 3b49e4a..3cdae92` 恰 9 路径（change-list 第三节）；「不得打红」两侧对象相同（第九节）；二十三条被保护分支 tip 未变（第十节）；CI 绿（退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice 见第四节）；pbx 撞号扫描通过（第十一节）；合并前工作树净；合并前 `ls-remote` 全部远端 ref（除本分支）与开工时逐行相同，`main` 仍 `3b49e4a`，未被他人推进——**满足**，已 `--no-ff` 合并并推送 |
| G989（合并后） | 合并后 `main` 运行 #361（run id `36275580475`，被测 `9bb803525f8186625322fecce02dc67d070409e7`）绿 916／0，12 步全 success；artifact `PhotoCleanupMVE-unsigned-9bb803525f81`，id 10917402448，1919938 字节，有效期至 2026-12-25T22:13:42Z——**满足** |

## 九、「不得打红」段对象比对（基线 `3b49e4a` vs E `3cdae92`）

| 路径 | 基线对象 | E 对象 | 结论 |
|---|---|---|---|
| `PhotoCleanupMVE/Core` | `796859519b61fd2894ecbc13a4399e4398037f7c` | 同左 | 相同 |
| `PhotoCleanupMVE/Services` | `ae83298b1925e1defabbcf8a762a6ecd3032ba78` | 同左 | 相同 |
| `PhotoCleanupMVE/App` | `ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S0` | `498da0346fdb9a6a59db517425d4d97047bda033` | 同左 | 相同（含 `S0DeckMetrics.swift` `eb12a2e88190ab06546e7105bbb0a59d08d8ce99`） |
| `PhotoCleanupMVE/Features/Shared` | `ca567d006a536e637c0330f8af07bf8b4c0734d3` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | `f18e7c0a5e0c79bf2137c17d57b680d1625a8dcd` | 同左 | 相同；`Features/S2/` 下只有 `S2AmbientBackdrop.swift` 不同 |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `992816e511291a547d43d5baee4eeefdb5f2a858` | 同左 | 相同（`schemaVersion` 7） |
| `PhotoCleanupMVE/Localizable.xcstrings` | `3b37ae13fd2388501add289622277e449c2ad5e5` | 同左 | 相同（目录 262） |
| `.github` | `74088388c62a10eb277921ecf74e766a2d407e80` | 同左 | 相同 |
| `Scripts` | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同左 | 相同 |
| `PhotoCleanupMVETests/` 既有 54 个文件 | — | — | 只有白名单内 2 个不同（`IC146…`、`IC151…`），其余 52 个逐文件相同；另新增 1 个（`IC177…`） |

## 十、被保护分支（23 条，开工时与合并前各 `ls-remote` 一次）

`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`、`feature/ic-169-marked-state-follows-basket` `bf9551e`、`feature/ic-175-similar-recognizer` `8d5bc7b`——**23／23 与远端头前缀相符**；合并前复查：全部远端 ref（除本分支外）与开工时逐行相同。

## 十一、子项 E：测试文件与 pbxproj

- 拷入：`cp <top>/Tasks/decision-tools/IC177UnifiedBackgroundTests.swift PhotoCleanupMVETests/`；`git hash-object` 实测 = **`844572b4973615ec681278c3f59a345a13d2b21c`**（与卡面相等）；提交后 `git rev-parse 3cdae92:PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` 同值。未改任何一行。
- 三条新断言与函数名（#360 均 passed）：
  1. `testIC177A_ForegroundTableIsFixedPaletteInBothAppearances`
  2. `testIC177B_YearStackHeroPaletteAndAmbientBaseAreFixed`
  3. `testIC177C_PagesCarryNoDynamicColorsAndPositiveControlsHold`
- pbxproj 撞号扫描（登记前重扫，24 位十六进制 id 按数值比）：1 号段 113 个、最大 `100000000000000000000078`；2 号段 110 个、最大 `200000000000000000000075`；新 id `100000000000000000000079`／`200000000000000000000076` 登记前出现 0 次，无撞号、未换号。照 `IC175SimilarRecognizerTests.swift` 四行写法各复制一行（PBXBuildFile、PBXFileReference、测试组子项、测试目标 Sources 项）：登记后 `…079` 恰 3 处、`…076` 恰 2 处；对象定义 id 无重复（`check_ic177.py` 两项 PASS）。

## 十二、摘取关系实测（本机克隆 `scratchpad/ic177-exec/clone`，自 `3b49e4a` 起 `cherry-pick`，未推送）

| 摘取单元 | 结果 | 核对 |
|---|---|---|
| A 单独 | 无冲突，只改 `S1View.swift` | 克隆提交树 `8c8cdd5a8428f63ff4f1cb6c68be65550c367257` = 分支 `aede7de` 的树 |
| D 单独 | 无冲突，只改三文件（氛围底、IC146、IC151） | 三个文件 blob 与分支 `47b656c` 上逐个相同 |

编译层面（A 单独后 S3／S4／S5 仍只引用保留的 `primary`／`secondary`）按卡面与复核结论成立，本机无 Xcode，未单独编译验证。

## 十三、根因假设

本卡不含根因假设（纯取值替换）。卡内 ③ 两条的 CI 结果：裁定三 `testIC067G39…` 两侧 < 60 —— #360 passed（①）；红因清单 (1) `.opacity()` 派生色 alpha 解析 —— 断言 1／2 passed（①，精度 0.005）。

## 十四、规格欠账（按本卡实装，不算规格冲突；待 SPEC-S1 v11／S2 v23／S0 v5 回填）

1. SPEC-S1 v10 `:738` 三条系统底色 → 恒定 `#0B0F0D`／`#161B18`／`#161B18`（封面占位底与卡底同色）。
2. SPEC-S1 v10 `:704-705` 年卡垫层浅／深两套 → 只留深色侧 `#3A3A3C`／`#2F2F31`。
3. SPEC-S2 v22 `:129` 决策 42「chrome 前景须用具体动态色」→「具体恒定色」（暖白 `#FFFBF5`，次要 62%、三级 45%、分隔线 14%——三个不透明度卡内暂登，v11 第十一节登记）。
4. SPEC-S2 v22 `:179` 决策 61 与 SPEC-S0 v4 `:861` `ambientBaseColor=#0B1A13` → `#0B0F0D`（光晕绿色相与十个不透明度不动）。
5. SPEC-S3-S4 v8／SPEC-S5 v6 补取色条款：引用 S1 前景表与 S0 色板；S5 hero 成功 `#6FD6BE`、警告 `#FF9F0A`、中性 = 三级前景。

## 十五、③ 登记（待 H93）

- 圆形不定进度转圈是否认 `.tint`（CI 只验编译）；浅色模式下转圈是否可见。
- 玻璃深色覆盖内的文字前景在渲染时是否解析为暖白（本卡后覆盖内外前景已是恒定色，理论上与覆盖无关；无像素证据）。
- 菜单底由系统深色背景（纯黑）× 不透明度改为 `#161B18` × 同一不透明度后的观感。

## 十六、人工判定项（H93 六条，保留给 Lynn 装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-9bb803525f81`（#361，id 10917402448，2026-12-25 前有效）、**iPhone 先设成浅色模式**判，执行端不代为下结论）

1. 「逐张整理」范围列表：整页深底（与「空间清理」首页同色）、范围卡深灰底、文字暖白、次要文字变淡；年卡两层垫卡还看得出「一摞」；封面占位方块与卡底同色。
2. 点排序钮／分组胶囊：菜单仍是深底白字（底由纯黑改成深灰，与卡底同色），选中项变成橙红（原系统蓝）；受限提示条的「管理」小胶囊橙红。
3. 确认页（S3）：整页深底、分组卡深灰底、组头暖白；底部「删除 N 张」按钮橙红底白字（原系统红）。执行中页（S4）深底、中间的大转圈在浅色模式下看得见（淡白）。
4. 结果页（S5）：深底；成功 hero 薄荷绿、警告橙、中性淡白；三格数字暖白、失败数橙红；「完成」暖白底深字，「返回确认页」橙红底白字。
5. 看图页（S2）：幕底与首页、列表页一色（原来偏绿的深色不见了），光晕仍在。
6. 一两句总评：切回深色模式再看一遍，四页除状态栏文字、滚动条、底部 tab bar、开屏一瞬的加载态外是否与浅色模式下一样。

## 十七、发现但未处理（按纪律只报告不修）

1. **IC172 菜单像素探针的配方副本随 A7 过时**（卡面预登记）：`IC172GlassAlwaysDarkTests` 的菜单参照与被测两棵树里手抄的仍是 `Color(uiColor: .systemBackground).opacity(S1MenuStyle.backgroundOpacity)`；A7 之后产品菜单底是 `S1ChromeForeground.cardBackground.opacity(…)`，探针自成一对仍绿（#360 7／7），但对新配方不再构成证据。归 IC-178 一并对齐。
2. **仍随系统外观的面**（卡面预登记，本卡范围外）：状态栏文字、`ScrollView` 滚动条、S3 系统 `confirmationDialog`、App 级加载态（`App/PhotoCleanupMVEApp.swift` `:319`／`:324`／`:330`：无根背景、默认转圈，浅色模式冷启动可能先闪白③）、系统 tab bar（`Features/S0/S0TabContainer.swift:66`）。
3. **`S2AmbientBackdrop.swift:9-11` 注释「仍是 S2 与 S0 两页的唯一落点」已过时**（调研 A.1 已指出：S0 首页用 `S0DeckMetrics.background`，不用氛围底）。D1 只改 `baseColor` 上方注释，未动该处。
4. **`S1View.swift` 的 `import UIKit` 在 A3 删掉 `dynamicColor` 后已无 `UIColor` 使用者**（剔注释 `UIColor` 0 处），无害，未动。
5. **决策会话预演脚本 `sim_ic177.py` 的全字面量差分**在基线上列出若干「产品文件计数变化、且该字面量出现在某测试文件里」的 needle（如 `'func '` S1 59 → 58，出现在 IC143／IC144）。执行端逐个核对了 `'func '`：IC143 `:604`、IC144 `:199` 只扫 `S2NativePhotoPager.swift`，不扫本卡文件；其余与复核结论一致。#360 916／0 全绿（①在 CI 上）。只作记录。
6. **CI 日志里另有一条 `OS:26.1, name:iPhone 16` 目的地行**（22:08:03，XCTest 结束之后，属构建未签名应用步骤的目的地枚举）；XCTest 实跑目的地是 `OS:26.2`（22:03:42）。只作记录。
7. 执行端首个 CI 轮询脚本因 Windows Python 不认 `/c/…` 路径空转两轮后被 `TaskStop` 停掉并修正重起；本卡结束时执行端起的后台进程均已退出。

## 十八、40 位 SHA 核验（`git cat-file -e`）

报告写完后，对本报告与 `change-list.md` 中出现的全部 40 位 SHA（去重 29 个）先 `git cat-file -t` 取类型、再 `git cat-file -e <sha>^{<类型>}`，**全部存在**（IPA 的 64 位 SHA-256 不是 git 对象，不在此列）：

```
1728293e2f5c77a79407e15b71a89fa96e8a8a62 blob OK
358c1dca4acbb44cfbda659bfd85340e1df0ee72 blob OK
3b37ae13fd2388501add289622277e449c2ad5e5 blob OK
3b49e4a8bdea5fc3331dfb170689b265115f255b commit OK
3cdae926a1af29ac5a19f97885737420e56a0df4 commit OK
47b656c54621eb75f009ea999ee5c48cedfd1427 commit OK
498da0346fdb9a6a59db517425d4d97047bda033 tree OK
4a9a3970f80447f01d0645775e62c78dbe72e1d9 blob OK
4d16c74d94c3623cc251fd4212ba9eb605231523 commit OK
514886dc0afc4083237c976c0f7be6ce597c50a8 tree OK
74088388c62a10eb277921ecf74e766a2d407e80 tree OK
76b06d742e42dc187518cd15aed26f74ed7a8c33 blob OK
796859519b61fd2894ecbc13a4399e4398037f7c tree OK
7a49b7a405ad5d125ffe51ad7fec731262fad8fc tree OK
844572b4973615ec681278c3f59a345a13d2b21c blob OK
8c8cdd5a8428f63ff4f1cb6c68be65550c367257 tree OK
992816e511291a547d43d5baee4eeefdb5f2a858 blob OK
99dd6a9ba1170c3b3dcedc26fec2e22850912eb3 blob OK
9bb803525f8186625322fecce02dc67d070409e7 commit OK
9fedf558d033acde95bd902f116f13904acbef29 blob OK
ae83298b1925e1defabbcf8a762a6ecd3032ba78 tree OK
aede7dedd2c1d0adfe4b13c9c2f52e1a81b9386e commit OK
b00dc63e691cd1c682e0921209e5f02300c4e854 commit OK
b4b908325f5d4f21586124c40aff8d48499003f0 blob OK
ba2f8b3bb69e874252349ce7434f74b805b22772 commit OK
ca567d006a536e637c0330f8af07bf8b4c0734d3 tree OK
eb12a2e88190ab06546e7105bbb0a59d08d8ce99 blob OK
ebf3dedd59b9c8d4e107bd9a2f6f8aae12c7e14e tree OK
f18e7c0a5e0c79bf2137c17d57b680d1625a8dcd blob OK
```
