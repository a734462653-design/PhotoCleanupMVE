# IC-175 变更清单

## 一、概要

- 任务卡：`<top>/Tasks/IC-20260926-175-similar-recognizer.md`
- 基线 `main`：`24cc29fe767bc2bd1bcb40011aa3db96315a77ab`
- 分支：`feature/ic-175-similar-recognizer`（tip `8d5bc7b84cf19336f1329913d2f3b61058c25696`）
- 合并提交：`ba2f8b3bb69e874252349ce7434f74b805b22772`（`--no-ff`，已推送）
- CI：#358 绿 913／0（`8d5bc7b84cf19336f1329913d2f3b61058c25696`）；合并后 `main` #359 绿 913／0（`ba2f8b3bb69e874252349ce7434f74b805b22772`，artifact `PhotoCleanupMVE-unsigned-ba2f8b3bb69e` id 10914239572，2026-12-25T19:40:59Z 到期）
- 报告落点：合并与合并后运行之后在 `main` 上追加恰一个 docs 提交（惯例 44）

## 二、逐提交变更

### A `4384300f4317767387678f52720ff4efabaae684` — 识别引擎（裁定 二～五）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Services/S0SimilarPhotosRecognizer.swift`（新建） | 逐字节拷自 `<top>/Tasks/decision-tools/`，blob `f423d8bdb549bcb467b598d03c50e30de3b6eb09`：`S0SimilarPhotosRules`（七常量）、`S0FeaturePrint`、`S0FeaturePrintOutcome`、`S0SimilarCandidate`、特征缓存条目／文件／存储（`s0-similar-features.plist`）、`S0SimilarPhotosGrouping`、`S0SimilarCancellationToken`、识别状态与结果、`S0SimilarPhotosRecognizer`（GCD 并发队列 + 信号量）、`S0SimilarDiagnosticsText`（`format=ic175-similar-v1` 六行全 ASCII）、`S0PhotoKitScanLibrary.extractFeaturePrint(for:)` 扩展 |
| `PhotoCleanupMVE/Services/S0LibraryScanService.swift` | A0 源文档注释「三个闭包」→「四个闭包…」；A1 `S0LibraryScanSource` 末尾加 `var extractFeaturePrint: (String) -> S0FeaturePrintOutcome = { _ in .failed }`；A2 私有状态 `similarRecognitionState`／`similarRecognition`／`similarRecognizer`；A3 指定构造加默认形参 `similarRecognizer:`（默认不持久化），`convenience init()` 给带 `S0SimilarFeatureCacheStore()` 的识别器；A4 `similarRecognitionResult` 读数、`similarDiagnosticsReport()`、私有 `recognizeSimilarPhotos()`（候选取自缓存条目：库内、照片、非截图、已解析；`withTaskCancellationHandler` + `withCheckedContinuation` 桥到识别器回调）；A5 `runPass()` 末尾（未解析重试、落盘、通知之后）`guard !Task.isCancelled` 再 `await recognizeSimilarPhotos()`；A6 `.production` 源加 `extractFeaturePrint:` 闭包；A7 `S0PhotoKitScanLibrary.cachedAsset(for:)` 由 `private` 改 internal（加两行文档注释） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记产品文件四行：PBXBuildFile `200000000000000000000074`、PBXFileReference `100000000000000000000077`、`Services` 组子项、应用源码阶段项（照 `S0ScanRules.swift`） |

### B `1f9359631d17c428fe5e9bb910b423aa11c7774c` — 诊断段（裁定 六）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | B1 `private let similarDiagnosticsText: String?`；B2 init 末位形参 `similarDiagnosticsText: String? = nil`；B3 赋值；B4 `calibrationPanel` 内 `exitDiagnosticsSection` 之后挂 `similarDiagnosticsSection`；B5 段体（`Divider` + 标题 + `ShareLink` + `.s2MinimumTouchTarget()` + 等宽 `Text(verbatim:)` + 空态），形状照 IC-168 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | B6 `s2Screen` 末位实参 `exitDiagnosticsText:` 行尾加逗号，新增注释一行与 `similarDiagnosticsText: s0DataProvider.similarDiagnosticsReport()` |
| `PhotoCleanupMVE/Localizable.xcstrings` | 在 `s2.calibration.exit_diagnostics.empty` 条目之后插入三条（`manual`、`zh-Hans` `translated`）：`.empty`「尚无相似识别数据」、`.share`「复制或分享相似识别诊断」、`.title`「相似识别诊断（IC-175）」；目录 259 → 262 |

### C `8d5bc7b84cf19336f1329913d2f3b61058c25696` — 新断言

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/IC175SimilarRecognizerTests.swift`（新建） | 逐字节拷自 `<top>/Tasks/decision-tools/`，blob `e389348624a1ce9f30711c3616a75a85a8d74c0d`；八条测试 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记测试文件四行：PBXBuildFile `200000000000000000000075`、PBXFileReference `100000000000000000000078`、测试组子项、测试源码阶段项（照 `IC169MarkedStateFollowsBasketTests.swift`） |

### merge `ba2f8b3bb69e874252349ce7434f74b805b22772`

父 `24cc29fe767bc2bd1bcb40011aa3db96315a77ab` 与 `8d5bc7b84cf19336f1329913d2f3b61058c25696`；树 `1fd4a3503691ce75f92680e4063e868591f1ea61` 与 C 的树相同。

## 三、路径汇总（`git diff --name-only 24cc29f..8d5bc7b`，恰 7 个）

| 路径 | 类别 | 子项 |
|---|---|---|
| `PhotoCleanupMVE/Services/S0SimilarPhotosRecognizer.swift` | 产品（新建） | A |
| `PhotoCleanupMVE/Services/S0LibraryScanService.swift` | 产品 | A |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 产品 | B |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 产品 | B |
| `PhotoCleanupMVE/Localizable.xcstrings` | 文案目录 | B |
| `PhotoCleanupMVETests/IC175SimilarRecognizerTests.swift` | 测试（新建） | C |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 工程 | A、C |

另：docs 提交新增 `Reports/IC-175/self-check.md`、`Reports/IC-175/change-list.md`（落合并后 `main`）。

## 四、占位值登记

- `S2CalibrationConfiguration.schemaVersion`：**未变，仍 7**（本卡不动任何出厂值）。
- `S0ScanRules.cacheSchemaVersion`：**未变，仍 1**（特征缓存另开文件，文件内有自己的 `schemaVersion`，在新文件 `S0SimilarPhotosRules` 里）。
- 新登记常量：`S0SimilarPhotosRules` 七个（各注出处，数值见新文件，决策会话生成），`S0ScanRules` 仍恰六个。

## 五、测试项数

905（基线）+ 8（`IC175SimilarRecognizerTests`）= **913**；既有断言改期望 0 处。

## 六、摘取单元

A 单独（克隆实测无冲突，树与分支 A 相同）；A→B；全部。
