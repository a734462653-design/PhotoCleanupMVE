# IC-175 自验报告

## 一、结论（先行）

**已合并、已推送、合并后运行绿。** 分支 `feature/ic-175-similar-recognizer` 三个子项各自独立提交 A→B→C。三个提交一次推送后 CI **#358 绿 913／0**；G983 全部满足后 `--no-ff` 合并入 `main`（合并提交 `ba2f8b3bb69e874252349ce7434f74b805b22772`）并推送；合并后 `main` 自动运行 **#359 绿 913／0**。CI 预算 1／3（分支一次绿，未用可选的 A 后中间推送）。

- 两个新文件逐字节拷入：产品文件 `git hash-object` = `f423d8bdb549bcb467b598d03c50e30de3b6eb09`、测试文件 = `e389348624a1ce9f30711c3616a75a85a8d74c0d`，均与卡面相等，未改一行。
- 子项 A（扫描服务八处）、子项 B（S2View 五处 + App 一处 + 目录三条）的全部改法逐字取自任务卡代码块（执行端脚本从卡面 28 个 ```swift 块取原文，与 `Tasks/decision-tools/ic175_edits.py` 逐对比较相等），每个锚句恰命中 1 处。
- 每个子项提交前的计数实测与卡面「改后（预演值）」**逐条相等**（第六节，A 36 行、B 31 行，0 处不符）；决策会话验收脚本 `check_ic175.py` 对 A／B／C 三个提交分别 66／66、66／66、69／69 通过。
- 8 条新断言在 #358 **全部 passed**；其中 `testIC175C_ObservationArchiveRoundTripKeepsDistanceZero` **passed 而非 skipped**（4.764 s）——CI 模拟器上 Vision 可跑，`NSKeyedArchiver` 往返后 `computeDistance` = 0 成立，**裁定 三的 ③ 在 CI 模拟器上转 ①**（真机仍由 H92 第 2 条判）。
- 既有断言零改动、零翻红（913 = 905 + 8，全部 passed）；「不得打红」段对象两侧逐项相同（第九节）。
- **全部新断言都是夹具驱动（向量印象），真机距离分布、耗时、缓存复用与观感只有 H92 能判**（陷阱 1）。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260926-175-similar-recognizer.md` |
| 前置阅读 | `<top>/CLAUDE.md`；SPEC-S0 v4 第七节 `:340-390`；`Tasks/RESEARCH-similar-photos-facts.md`（A、B、E 节）；`Tasks/RESEARCH-IC-175-facts.md`（全文）；`Tasks/REVIEW-IC-175-findings.md`（两轮，实质 0／行文 13 + 2） |
| 基线 `main`（开工时） | `24cc29fe767bc2bd1bcb40011aa3db96315a77ab` |
| 开工核对 1 | `git status --porcelain` 空 |
| 开工核对 2 | `git merge-base --is-ancestor 3cad2e2e47d1a13249f5370a0e47f283b9967c69 main` 退出码 0 |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `24cc29fe767bc2bd1bcb40011aa3db96315a77ab`，与本地一致 |
| 开工核对 4 | `main:` 服务 `d81ef375e0d682f4e5649797a9b8a395cc0407c4`、S2View `bea3bf09887428db76827877408a27b09ecf0bb3`、App `fdc8b8a797e5e8cd5538b5a28ebec2f467ca08fa`，与卡面相等；两份待拷入源文件 hash-object 也与卡面相等 |
| 分支 | `feature/ic-175-similar-recognizer`，改任何文件前先 `git switch -c` 自基线切出 |
| `schemaVersion` | 7（未动；`S2Calibration.swift` 对象两侧相同） |
| `cacheSchemaVersion` | 1（未动；`S0ScanRules.swift` 对象两侧相同） |
| 会话档格式 | 不变（`Core/` 整树对象两侧相同） |
| 文案目录 | 259 → **262**（`s2.` 125 → 128、`s2.calibration.` 73 → 76） |
| 合并 | `--no-ff`，合并提交 `ba2f8b3bb69e874252349ce7434f74b805b22772`，父 `24cc29fe767bc2bd1bcb40011aa3db96315a77ab`（合并前 main）与 `8d5bc7b84cf19336f1329913d2f3b61058c25696`（分支 tip = C）；合并树 `1fd4a3503691ce75f92680e4063e868591f1ea61` = C 提交的树 |
| docs 提交（惯例 44） | 合并与合并后运行 #359 之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`） |
| CI 预算 | 1／3（分支）+ 合并后 `main` 自动运行 1 次 |

## 三、提交列表

| 子项 | 提交 SHA | 改动 |
|---|---|---|
| A | `4384300f4317767387678f52720ff4efabaae684` | 新文件 `Services/S0SimilarPhotosRecognizer.swift`（拷入）+ 服务八处（A0～A7）+ pbxproj 产品文件四行 |
| B | `1f9359631d17c428fe5e9bb910b423aa11c7774c` | S2View 五处（B1～B5）+ App 一处（B6）+ 目录三条 key |
| C | `8d5bc7b84cf19336f1329913d2f3b61058c25696` | 新测试文件（拷入）+ pbxproj 测试文件四行 |
| merge | `ba2f8b3bb69e874252349ce7434f74b805b22772` | 首行 `merge(IC-175): 相似照片识别引擎——特征提取、特征缓存、时间窗单链接分组挂在扫描末尾，S2 面板加可复制诊断` |

## 四、CI

| 项 | #358（A→B→C，分支） | #359（合并后 `main`） |
|---|---|---|
| run id | `36266142365` | `36266893764` |
| 被测提交 | `8d5bc7b84cf19336f1329913d2f3b61058c25696` | `ba2f8b3bb69e874252349ce7434f74b805b22772` |
| 结论 | success（12 步全 success，attempt 1） | success（12 步全 success，attempt 1） |
| 执行摘要 notice | `Executed 913 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 913 tests / 0 failures` | `Executed 913 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 913 tests / 0 failures` |
| 整包日志唯一 Test Case 行（「运行 XCTest」步骤文件，剔 `##[` 与 ANSI 回显） | 913 passed／0 failed／0 skipped | 913 passed／0 failed／0 skipped |
| 真实退出码 | 0（「运行 XCTest」步骤 success；工作流 `set -o pipefail` + `exit "$test_status"`；日志 `** TEST SUCCEEDED **`、`XCTest 已全部通过。`） | 0（同左） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左 |
| 分段耗时 notice | `模拟器启动 87 s；xcodebuild test 369 s；总 458 s` | `模拟器启动 120 s；xcodebuild test 381 s；总 501 s` |
| IPA 字节数 | 1914037 | 1914037 |
| IPA SHA-256 | `fe01e2ba0188a3e9c5f98df6db2fdeeff9076fed7126fc7c7397608ca4184409` | `1abfe23bc079eb14bf372e98c4c5d0a9853adf81aec9e52c83eea0ededd8d4f4` |
| artifact | `PhotoCleanupMVE-unsigned-8d5bc7b84cf1`，id 10913923744，1914207 字节，2026-12-25T19:27:53Z 到期 | `PhotoCleanupMVE-unsigned-ba2f8b3bb69e`，id 10914239572，1914207 字节，2026-12-25T19:40:59Z 到期 |
| `testIC063` | passed；`IC063_WARMUP_GATE_BEGIN`／`END` 在块内先后出现，全日志**无** `building pipeline` 行 | 同左（passed；块内门禁头先后出现；全日志无 `building pipeline` 行） |

项数对账：905（基线 #357）+ 0（A、B 不增删测试）+ 8（C 新文件八条）= **913**（#358、#359）。

新文件编译诊断：整包日志里与本卡文件相关的只有一条**警告** `IC175SimilarRecognizerTests.swift:296:63: warning: conditional downcast from 'VNFeaturePrintObservation?' to 'VNFeaturePrintObservation' does nothing`——即复核 R8 预言的那条；工程无 warnings-as-errors，不影响结果。产品新文件与服务文件零警告行。

## 五、本地门禁（三个提交各一份，真实退出码）

| 提交 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check`（暂存后 `--cached`，含新文件） |
|---|---|---|---|
| A 提交前 | 0 | 0 | 0 |
| B 提交前 | 0 | 0 | 0 |
| C 提交前 | 0 | 0 | 0 |

selfcheck 末行均为「结构自验通过…」；扫描器末行均为「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」。C 时交叉审计「扫描 54 个测试源文件」（53 → 54）、字符串结构检查「扫描 107 个 .swift」。

## 六、子项 A／B 计数实测表（卡面值 / 实测值）

口径：与测试 `strippedSource` 同口径（剔 `//` 注释与字符串字面量内容），执行端脚本 `scratchpad/ic175-exec/counts.py` 读工作树文件、调用 `Tasks/decision-tools/strip.py` 的 `strip_text`（只读使用）。「原文」= 不剔。

### 子项 A（提交前实测）

| 文件 | 口径 | needle | 卡面 | 实测 |
|---|---|---|---|---|
| `S0LibraryScanService.swift` | 剔注释 | `extractFeaturePrint` | 4 | 4 |
| 同上 | 剔注释 | `withCheckedContinuation` | 1 | 1 |
| 同上 | 剔注释 | `withTaskCancellationHandler` | 1 | 1 |
| 同上 | 剔注释 | `func similarDiagnosticsReport() -> String` | 1 | 1 |
| 同上 | 剔注释 | `func cachedAsset(for identifier: String) -> PHAsset?` | 1 | 1 |
| 同上 | 剔注释 | `private func cachedAsset` | 0 | 0 |
| 同上 | 剔注释 | `Task.detached(` | 1 | 1 |
| 同上 | 剔注释 | `withTaskGroup(` | 1 | 1 |
| 同上 | 剔注释 | `DispatchQueue` | 2 | 2 |
| 同上 | 剔注释 | `notifyChange()` | 7 | 7 |
| 同上 | 剔注释 | `persistPendingChanges()` | 5 | 5 |
| 同上 | 剔注释 | `revision += 1` | 3 | 3 |
| 同上 | 原文 | `import Vision` | 0 | 0 |
| 同上 | 原文 | `PHAsset.fetchAssets(with: nil)` | 1 | 1 |
| 同上 | 原文 | `withLocalIdentifiers` | 0 | 0 |
| 同上 | 原文 | `includeHiddenAssets` | 0 | 0 |
| 同上 | 原文 | `isNetworkAccessAllowed = true` | 0 | 0 |
| 同上 | 原文 | `fetchAssets(in:` | 0 | 0 |
| 同上 | 原文 | `hits.contains(` | 0 | 0 |
| 同上 | 原文 | `attributedCategory(` | 1 | 1 |
| 同上 | 原文 | `PHAssetResource.assetResources(for:`（事实表钉子） | 1 | 1 |
| `S0SimilarPhotosRecognizer.swift` | 原文 | `import Vision` | 1 | 1 |
| 同上 | 原文 | `isNetworkAccessAllowed = false` | 1 | 1 |
| 同上 | 原文 | `isSynchronous = true` | 1 | 1 |
| 同上 | 原文 | `fetchAssets` | 0 | 0 |
| 同上 | 原文 | `Task.detached` | 0 | 0 |
| 同上 | 原文 | `withTaskGroup` | 0 | 0 |
| 同上 | 原文 | `DispatchSemaphore(` | 1 | 1 |
| 同上 | 原文 | `computeDistance(` | 1 | 1 |
| 同上 | 剔注释 | `static let ` | 11 | 11 |
| 同上 | 剔注释·规则切片（`enum S0SimilarPhotosRules {` 到首个 `\n}\n`） | `static let ` | 7 | 7 |
| 同上 | 原文 | `出处：` | 7 | 7 |
| 同上 | 原文 | `return "` | 0 | 0 |
| 同上 | 原文 | `print(` | 0 | 0 |
| 同上 | 原文 | `os_log` | 0 | 0 |
| `S0ScanRules.swift` | 剔注释 | `static let `（IC153 `:374`） | 6 | 6 |

### 子项 B（提交前实测；A 表各项在 B 后复测不变）

| 文件 | 口径 | needle | 卡面 | 实测 |
|---|---|---|---|---|
| `S2View.swift` | 剔注释 | `similarDiagnosticsSection` | 2 | 2 |
| 同上 | 剔注释 | `similarDiagnosticsText: String? = nil` | 1 | 1 |
| 同上 | 剔注释 | `exitDiagnosticsSection` | 2 | 2 |
| 同上 | 剔注释 | `exitDiagnosticsText` | 7 | 7 |
| 同上 | 剔注释 | `ShareLink(item:` | 7 | 7 |
| 同上 | 剔注释 | `.s2MinimumTouchTarget()` | 18 | 18 |
| 同上 | 剔注释 | `Text(verbatim:` | 35 | 35 |
| 同上 | 剔注释 | `Divider()` | 6 | 6 |
| 同上 | 原文 | `s2.calibration.similar_diagnostics.` | 3 | 3 |
| 同上 | 原文 | `s2.calibration.exit_diagnostics.` | 3 | 3 |
| 同上 | 原文 | `colorScheme, .dark)` | 6 | 6 |
| 同上 | 剔注释 | `Material` | 6 | 6 |
| 同上 | 剔注释 | `.background(.regularMaterial)` | 3 | 3 |
| 同上 | 剔注释 | `GlassEffectContainer {` | 2 | 2 |
| 同上 | 剔注释 | `#available` | 3 | 3 |
| 同上 | 剔注释 | `.primary` | 8 | 8 |
| 同上 | 剔注释 | `glassEffect(` | 1 | 1 |
| 同上 | 剔注释 | `s2ChromeGlassBackground(` | 6 | 6 |
| `PhotoCleanupMVEApp.swift` | 原文 | `similarDiagnosticsText: s0DataProvider.similarDiagnosticsReport()` | 1 | 1 |
| 同上 | 原文 | `advanceScan()` | 2 | 2 |
| 同上 | 原文 | `onSnapshotDidChange` | 1 | 1 |
| 同上 | 原文 | `exitDiagnosticsText:` | 1 | 1 |
| 同上 | 原文 | `S0ScanOutcomeTransition.events(` | 1 | 1 |
| 同上 | 原文 | `enterS2(from:` | 2 | 2 |
| 同上 | 原文 | `makeS2Handoff(virtualRangeID:` | 1 | 1 |
| 同上 | 原文 | `presentCleanupFeedbackEvent(` | 3 | 3 |
| 同上 | 原文 | `coordinator.enterConfirmationFromS0()` | 1 | 1 |
| `Localizable.xcstrings` | `json.load` | 目录总数 | 262 | 262 |
| 同上 | 同上 | `s2.` 前缀 | 128 | 128 |
| 同上 | 同上 | `s2.calibration.` 前缀 | 76 | 76 |

**全部逐条相符，0 处不符。** 既有断言旧 → 新：无（卡面「无」，实际亦无）。

## 七、两个拷入文件

| 文件 | 卡面 blob | 拷入后 `git hash-object` | 暂存区 blob |
|---|---|---|---|
| `PhotoCleanupMVE/Services/S0SimilarPhotosRecognizer.swift` | `f423d8bdb549bcb467b598d03c50e30de3b6eb09` | 同左 | 同左 |
| `PhotoCleanupMVETests/IC175SimilarRecognizerTests.swift` | `e389348624a1ce9f30711c3616a75a85a8d74c0d` | 同左 | 同左 |

两文件与被改的全部文件均为 LF、无 BOM（执行端 Python 逐字节计 CR 为 0）；仓库 `.gitattributes` 对 `*.swift`／`*.pbxproj`／`*.xcstrings` 定 `eol=lf`，`core.autocrlf=true` 未改写。

## 八、8 条新断言与闸门 G980～G984

| # | 函数 | #358 |
|---|---|---|
| 1 | `testIC175A_RulesAreRegisteredAndScanRulesUntouched` | passed |
| 2 | `testIC175B_NeighborPairsAndGroupsFollowProbeSemantics` | passed |
| 3 | `testIC175C_VectorPrintArchiveRoundTripAndDistances` | passed |
| 4 | `testIC175C_FeatureCacheStoreRoundTripAndSchemaMismatch` | passed |
| 5 | `testIC175D_RecognizerReusesCacheAndRegroups` | passed |
| 6 | `testIC175E_ScanServiceRunsRecognitionAfterPassAndReportsDiagnostics` | passed |
| 7 | `testIC175C_ObservationArchiveRoundTripKeepsDistanceZero` | **passed**（4.764 s，未走 `XCTSkip`） |
| 8 | `testIC175F_SourceDisciplineAndWiring` | passed |

- **G980（引擎）通过**：1～5 passed；7 passed（非 skipped）；A 计数与卡面逐条相等（第六节）；`IC153ScanServiceTests`、`IC155CategoryDataAndCoverTests`、`IC166RestCategoryTests` 全部 passed（#358 913／0，无失败行）。
- **G981（诊断段）通过**：8 passed；`IC168FallbackDiagnosticsTests`、`IC172GlassAlwaysDarkTests`、`IC146ChromeRoundTwoTests`、`IC150ShareTests` 全部 passed。四个上升计数实测：`ShareLink(item:` 6 → 7、`.s2MinimumTouchTarget()` 17 → 18、`Text(verbatim:` 34 → 35、`Divider()` 5 → 6（无测试钉）。
- **G982（服务集成）通过**：6 passed（夹具服务一遍结束后 `groups` 等于预期、诊断文本含 `groups=`、`categories.count` 仍 4、`.similar` 不在其中）。
- **G983（合并前置）通过**：
  - G980～G982 如上；
  - `git diff --name-only 24cc29fe767bc2bd1bcb40011aa3db96315a77ab 8d5bc7b84cf19336f1329913d2f3b61058c25696` 恰 **7** 路径：`PhotoCleanupMVE.xcodeproj/project.pbxproj`、`PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`、`PhotoCleanupMVE/Features/S2/S2View.swift`、`PhotoCleanupMVE/Localizable.xcstrings`、`PhotoCleanupMVE/Services/S0LibraryScanService.swift`、`PhotoCleanupMVE/Services/S0SimilarPhotosRecognizer.swift`、`PhotoCleanupMVETests/IC175SimilarRecognizerTests.swift`；
  - 「不得打红」段两侧对象全部相同（第九节）；
  - 二十二条被保护分支 tip 在推送前与合并前两次 `ls-remote` 全部与卡面短 SHA 相符（第十节）；合并前除本分支外全部远端分支头与第一次逐条相同；
  - CI 绿（第四节）；pbxproj 撞号扫描通过（第十一节）；工作树净；`main` 未被他人推进（合并前 `ls-remote` 仍为 `24cc29fe767bc2bd1bcb40011aa3db96315a77ab`）。
  - 合并：Bash 工具 `git switch main` + `git merge --no-ff feature/ic-175-similar-recognizer -m …` 一次通过、未被拒；`git push origin main` 一次通过（`24cc29f..ba2f8b3`）。
- **G984**：**通过**：合并后 `main` 自动运行 **#359**（run id `36266893764`），success，913／0（八条新断言全 passed，观测归档往返仍 passed 未跳过），分段耗时 `模拟器启动 120 s；xcodebuild test 381 s；总 501 s`，artifact `PhotoCleanupMVE-unsigned-ba2f8b3bb69e`（id 10914239572，2026-12-25T19:40:59Z 到期）。

## 九、「不得打红」段对象比对（基线 `24cc29f` vs C `8d5bc7b`）

| 路径 | 基线对象 | C 对象 | 结论 |
|---|---|---|---|
| `PhotoCleanupMVE/Core`（树） | `796859519b61fd2894ecbc13a4399e4398037f7c` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S0`（树，含协议文件 `S0CleanupDataProviding.swift` blob `b9e4a57c3133bf189ed3db21b1ff995547faa40f`） | `498da0346fdb9a6a59db517425d4d97047bda033` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/S1`（树） | `27e49576da79576db56da765e2388a3c6a95c138` | 同左 | 相同 |
| `PhotoCleanupMVE/Features/Shared`（树） | `ca567d006a536e637c0330f8af07bf8b4c0734d3` | 同左 | 相同 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | `6baae5aa127873f7aa4077ad2b7af5a6ee022780` | 同左 | 相同 |
| `PhotoCleanupMVE/Services/S0ScanRules.swift` | `d81a5fdce4db0dc502fde2430d2caa4d0d0ffcd0` | 同左 | 相同（`cacheSchemaVersion = 1`） |
| `PhotoCleanupMVE/Services/S0ScanClassifier.swift` | `3d7fb0f1a6d465e19cc866a5b026f8013d74650b` | 同左 | 相同 |
| `PhotoCleanupMVE/Services/S0ScanCache.swift` | `27da1b17aef6adf8db54c4af8fefdff0f8ad9a6b` | 同左 | 相同 |
| `PhotoCleanupMVE/Services/S0CleanupDataStub.swift` | `7e6da9d5a7c6c198c7b387b5e5895626e5ce9322` | 同左 | 相同 |
| `Services/` 其余 | — | — | `git diff --name-only` 在 `Services/` 下只列服务文件与新文件 |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `992816e511291a547d43d5baee4eeefdb5f2a858` | 同左 | 相同（`schemaVersion = 7`） |
| `.github`（树） | `74088388c62a10eb277921ecf74e766a2d407e80` | 同左 | 相同 |
| `Scripts`（树） | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同左 | 相同 |
| `PhotoCleanupMVETests/` 既有 53 个文件 | — | — | `git diff --name-status` 只有新增 `IC175SimilarRecognizerTests.swift`（A），既有 53 个逐文件相同 |

被改的五个文件：服务 `d81ef375e0d682f4e5649797a9b8a395cc0407c4` → `66daa12f121101180a506205557b425beec3b87d`、S2View `bea3bf09887428db76827877408a27b09ecf0bb3` → `f18e7c0a5e0c79bf2137c17d57b680d1625a8dcd`、App `fdc8b8a797e5e8cd5538b5a28ebec2f467ca08fa` → `89bbd814d3571cf3788eee4a572b9ff9f7c8f359`、目录 `80dcb2cf21e0a177b2a3f6b867626eb8e34d29f9` → `3b37ae13fd2388501add289622277e449c2ad5e5`、pbxproj `9323612fef9b8b4fbe6789ed2683882083258251` → `b5b6aaee812deabca7309db7fcc402be64064c02`。

## 十、被保护分支（22 条，推送后与合并前各 `ls-remote` 一次）

`Reports/IC-169/self-check.md` 第十节的 21 条：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`、`feature/ic-168-s2-exit-diagnostics` `e7c1be0`、`feature/ic-170-s1-first-read` `8007910`、`feature/ic-171-category-page-trio` `0134c84`、`feature/ic-172-glass-always-dark` `3cf4833`、`probe/ic-173-material-dark-env` `571a5ef`、`feature/ic-174-glass-always-dark-reissue` `bd4e213`；另加 `feature/ic-169-marked-state-follows-basket` `bf9551e`（全 SHA `bf9551eb4b45633ca78ab124360e959e6cbb49a2`）。**22／22 两次都与远端头前缀相符**；合并前远端共 96 条分支头，除 `feature/ic-175-similar-recognizer`（新建）外逐条与第一次相同。

## 十一、pbxproj 撞号扫描与四个新 id

登记前 Python 按 `\b[0-9A-F]{24}\b` 重扫全文件、按十六进制比较：1 号段 111 个不同 id、最大 `100000000000000000000076`；2 号段 108 个、最大 `200000000000000000000073`；四个拟用 id 全文件 0 命中，**无撞号，未换号**。

| 文件 | PBXFileReference | PBXBuildFile | 组 | 构建阶段 | 写法模板 |
|---|---|---|---|---|---|
| `S0SimilarPhotosRecognizer.swift` | `100000000000000000000077` | `200000000000000000000074`（`（源码）`） | `Services` | 应用源码阶段 | `S0ScanRules.swift` 四行，各插在模板行之后 |
| `IC175SimilarRecognizerTests.swift` | `100000000000000000000078` | `200000000000000000000075`（`（测试源码）`） | `PhotoCleanupMVETests` | 测试源码阶段 | `IC169MarkedStateFollowsBasketTests.swift` 四行，各插在模板行之后 |

登记后文件名各 6 次（每行注释 + path）、fileRef id 各 3 次、buildFile id 各 2 次。

## 十二、摘取关系实测（本机克隆 `scratchpad/ic175-exec/clone`，`git clone --no-hardlinks`）

| 摘取单元 | 结果 |
|---|---|
| A 单独（自 `24cc29f` 切 `pickA`，`git cherry-pick 4384300`） | 无冲突、退出码 0；改动路径恰 3 个（pbxproj、服务、新文件）；得到的树 `a4a8f43b34db3fa9d76e2b1ac01e012d4c38e3c9` = 分支上 A 提交的树 |

本机无 Xcode，A 单独可编译为 ③（依据：新文件只引用基线已有的 `S0ScanCacheStore.directoryName` 与 A 自己放宽的 `cachedAsset(for:)`；B、C 的符号都不在 A 里被引用）。A→B、全部两种单元即分支本身的链，#358 在 C 上编译通过 ①。

## 十三、根因假设

本卡不含根因假设（功能卡）。卡内 ③ 的处置：

- 裁定 三「`VNFeaturePrintObservation` 经 `NSKeyedArchiver` 往返后 `computeDistance` = 0」：**CI 模拟器上 ①**（`testIC175C_ObservationArchiveRoundTripKeepsDistanceZero` passed、未跳过）；真机缓存路径的距离一致性仍待 H92 第 2 条。
- 调研 ③「逐成员构造器对带初值 `var` 给默认形参」「跨文件扩展要求 internal」：#358 编译通过，**①**（IC153／IC155 的三参夹具未改而编译通过；新文件里 `S0PhotoKitScanLibrary` 扩展调用 `cachedAsset(for:)` 编译通过）。

## 十四、规格欠账（按本卡实装，不算规格冲突；SPEC-S0 v5 回填）

1. v4 `:386`「簇内最大距离约束随档位取同值」——④ 第 200 条第五节第 2 条改为未定项（单链接），本卡按 ④ 实装。
2. v4 `:384`「特征缓存键与扫描缓存同源」——实装另开文件 `s0-similar-features.plist`，键 `localIdentifier`、复用判据 `modificationDate` + 特征 revision（裁定 三）；v5 补「revision 变即作废」。
3. v4 第十二节未定项 3「重分簇耗时」——本卡诊断文本带 `extract_seconds`／`group_ms`，真机数回来后结案。
4. v4 `:346`「全库特征提取完成后出现在 `CAT`」——本卡只完成提取与分组，出卡归 IC-176；提取阶段不改 `outcome`／`recognition`，首页在本卡后行为不变。

## 十五、发现但未处理（按纪律只报告不修）

1. **（卡内预登记，裁定 二）识别期间回前台的 `advanceScan()` 被幂等吞掉**：识别段落在 `isScanInFlight` 期间，这段时间里回前台不会触发新一遍，新增照片要等下一次前台／冷启动（H92 第 5 条已按此改写）。③ 代码推断，夹具未覆盖。
2. **（卡内预登记，裁定 二）每一遍都整份读特征缓存并逐条解档**，耗时在 `extract_seconds` 之外、未单独计（H80 量级约 9 MB）；观感归 H92 第 3 条。
3. **测试文件 `:296` 一条编译警告**（复核 R8 预言）：`conditional downcast from 'VNFeaturePrintObservation?' to 'VNFeaturePrintObservation' does nothing`（#358 日志 ①）。文件逐字节锁定，按卡不改。
4. **`testIC175C_ObservationArchiveRoundTripKeepsDistanceZero` 在 CI 上实跑（未跳过）**，说明 iOS 26.2 模拟器上 `VNGenerateImageFeaturePrintRequest` 可用；该用例耗时 4.764 s（日志 `passed (4.764 seconds)` ①）。只作记录。
5. **`Tasks/decision-tools/__pycache__/ic175_edits.cpython-312.pyc` 可能被执行端刷新**：执行端脚本以只读方式 `import ic175_edits` 做卡面块比对，Python 会在源较新时重写字节码缓存（该文件 mtime 为本次会话时段）；源文件本身未动。之后的调用都加了 `-B`。
6. 本次整包日志内**无** `building pipeline` 行（`testIC063` 预热门禁头照常出现），与 IC-169 报告第十七节第 3 条形态不同，只作观察。

## 十六、人工判定项（H92 六条，保留给 Lynn 装合并后 `main` 产物 `PhotoCleanupMVE-unsigned-ba2f8b3bb69e`（#359，id 10914239572，2026-12-25 前有效） 真机判，执行端不代为下结论）

1. 打开 App、等首页扫描完成后约 10～20 s → 进任一看图页 → 长按顶部中胶囊 → 标定面板拉到末尾「相似识别诊断（IC-175）」→ 复制，整段发给决策会话。预期 `state=done`、`candidates=` 接近非截图照片数、`groups=` 与 H80 0.50 档同量级（H80：292 组、1327 张）。
2. 杀掉重开、再进一次面板复制：`reused=` ≈ 上次 `extracted=`、`extracted=0` 或只有新增照片数、`extract_seconds` 明显小于第一次；**且 `distance_failed=0`、`groups`／`grouped`／`largest` 与第一次完全相同**（不同即缓存路径的距离出了问题，整段发给决策会话）。
3. 第一次识别期间 App 有没有可感的卡顿、发热（探针实测无，正式路径在扫描末尾自动跑）；**杀掉重开、以及切后台再回来之后的前几秒**有没有可感的卡顿（这段是整份读特征缓存 + 逐条解档，不进 `extract_seconds`）。
4. 首扫期间「正在扫描」的时长与改动前比有没有变长（识别在扫描完成回报之后，预期不变）。
5. 等面板已显示 `state=done` 之后再拍一张新照片、回前台、再进面板：`candidates` +1、`extracted=1`（识别进行中回前台的 `advanceScan()` 会被幂等吞掉，那次不会重跑——是已知行为，不是缺陷）。
6. 一两句总评。

## 十七、40 位 SHA 核验（`git cat-file -e`）

报告写完后，对本报告与 `change-list.md` 中出现的全部 40 位 SHA（去重 34 个）先 `git cat-file -t` 取类型、再 `git cat-file -e <sha>^{<类型>}`，**全部存在**：

```
1f9359631d17c428fe5e9bb910b423aa11c7774c commit OK
1fd4a3503691ce75f92680e4063e868591f1ea61 tree OK
24cc29fe767bc2bd1bcb40011aa3db96315a77ab commit OK
27da1b17aef6adf8db54c4af8fefdff0f8ad9a6b blob OK
27e49576da79576db56da765e2388a3c6a95c138 tree OK
3b37ae13fd2388501add289622277e449c2ad5e5 blob OK
3cad2e2e47d1a13249f5370a0e47f283b9967c69 commit OK
3d7fb0f1a6d465e19cc866a5b026f8013d74650b blob OK
4384300f4317767387678f52720ff4efabaae684 commit OK
498da0346fdb9a6a59db517425d4d97047bda033 tree OK
514886dc0afc4083237c976c0f7be6ce597c50a8 tree OK
66daa12f121101180a506205557b425beec3b87d blob OK
6baae5aa127873f7aa4077ad2b7af5a6ee022780 blob OK
74088388c62a10eb277921ecf74e766a2d407e80 tree OK
796859519b61fd2894ecbc13a4399e4398037f7c tree OK
7e6da9d5a7c6c198c7b387b5e5895626e5ce9322 blob OK
80dcb2cf21e0a177b2a3f6b867626eb8e34d29f9 blob OK
89bbd814d3571cf3788eee4a572b9ff9f7c8f359 blob OK
8d5bc7b84cf19336f1329913d2f3b61058c25696 commit OK
9323612fef9b8b4fbe6789ed2683882083258251 blob OK
992816e511291a547d43d5baee4eeefdb5f2a858 blob OK
a4a8f43b34db3fa9d76e2b1ac01e012d4c38e3c9 tree OK
b5b6aaee812deabca7309db7fcc402be64064c02 blob OK
b9e4a57c3133bf189ed3db21b1ff995547faa40f blob OK
ba2f8b3bb69e874252349ce7434f74b805b22772 commit OK
bea3bf09887428db76827877408a27b09ecf0bb3 blob OK
bf9551eb4b45633ca78ab124360e959e6cbb49a2 commit OK
ca567d006a536e637c0330f8af07bf8b4c0734d3 tree OK
d81a5fdce4db0dc502fde2430d2caa4d0d0ffcd0 blob OK
d81ef375e0d682f4e5649797a9b8a395cc0407c4 blob OK
e389348624a1ce9f30711c3616a75a85a8d74c0d blob OK
f18e7c0a5e0c79bf2137c17d57b680d1625a8dcd blob OK
f423d8bdb549bcb467b598d03c50e30de3b6eb09 blob OK
fdc8b8a797e5e8cd5538b5a28ebec2f467ca08fa blob OK
```
