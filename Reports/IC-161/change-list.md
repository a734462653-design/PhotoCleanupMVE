# IC-161 变更清单（探针，不合并）

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260919-161-similar-photos-probe.md` |
| 基线 `main` | `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a` |
| 分支 | `probe/ic-161-similar-photos`（**不合并进 `main`**，与 `probe/ic-137-media-playback`、`probe/ic-145-scan-service` 同例） |
| 子项 A 提交 | `fa068b80e86532d7c9a8692f1a028a6afc28a554` `probe(IC-161 A): 相似照片特征提取基准——耗时、环境量、特征体积` |
| 子项 B 提交 | `c63aa3e9eb0b36f1c18dc163550c821da797d8db` `probe(IC-161 B): 相邻距离分布、并查集分组与肉眼核对列表` |
| 子项 C 提交 | `302e375e245fa0ad33a63f37491c738624148928` `probe(IC-161 C): 画质评分探针（iOS 18+）与工具性图片占比` |
| 修复提交 | `c46c4b43ad309dcc325963962cceb683c24bbb21` `fix(IC-161 B): 补齐特征报告夹具的三个新字段（#322 唯一编译错误）` |
| 位置调整提交 | `db30e1b504968e4fa3b275561e690ae3e5c564e0` `refactor(IC-161): 三个新段的定义移到 doubleTapProbeSection 之后（G909 切块锚点）` |
| 报告 | 本文件与 `self-check.md`，另一个 docs 提交（同一分支，纪律 7） |
| 出厂值 | **无变更**。`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S2Calibration.swift` 不在 diff 里；探针常量全在新文件的 `SimilarPhotosProbeLimits` 里，不进配置、不落盘 |
| 项数 | 856 + 6 = **862**（CI #324 实证） |

## 二、文件清单（`git diff --numstat 091b60e db30e1b`，全部在白名单内）

| 文件 | 增／删 | 白名单条目 | 所属提交 |
|---|---|---|---|
| `PhotoCleanupMVE/Services/SimilarPhotosProbe.swift`（新，1 389 行） | +1389／−0 | N1 | A 建 755 行；B +341／−1；C +294／−0 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | +266／−0 | V1、V2 与三个新段（含惰性缩略图行子视图） | A +97；B +103；C +66；位置调整 +29／−29 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | +7／−0 | 仅 P1 两处（头部存储属性区、`assetSizeProber:` 之后的实参区） | A +4；C +3 |
| `PhotoCleanupMVE/Localizable.xcstrings` | +198／−0 | 仅 X1 的 **18 条** key | A 七条；B 四条；C 七条 |
| `PhotoCleanupMVETests/IC161SimilarPhotosProbeTests.swift`（新，581 行） | +581／−0 | 本卡断言 | A 建 338 行（断言 1～3）；B +144（断言 4～5）；C +95（断言 6）；修复 +5／−1 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +8／−0 | 两个新文件登记 | A |

合计 6 个路径。报告两份另计（docs 提交，`Reports/IC-161/`）。

**既有测试文件一个未改**：`git diff --name-only 091b60e db30e1b -- PhotoCleanupMVETests/` 只输出新文件那一行。

## 三、逐项变更

### 子项 A（特征提取基准）

| 处 | 位置 | 变更 |
|---|---|---|
| N1-A | `Services/SimilarPhotosProbe.swift`（新） | `SimilarPhotosSampleLimit`（500／2000／全部）、`SimilarPhotosEnvironmentSample`（热态／电量／可用内存，全在主线程读）、`SimilarPhotosFeatureOutcome`／`SimilarPhotosFeatureMeasurement`／`SimilarPhotosFeatureProbeResult`、纯函数 `SimilarPhotosProbeMath`（最近秩分位数取**整数百分比**、均值、串行上界外推、实测吞吐外推）、`SimilarPhotosProbeFormat`（ASCII 零件）、`SimilarPhotosFeatureProbeText`、`SimilarPhotosProbeLimits`、协议 `SimilarPhotosFeatureProbing`、`SimilarPhotosCancellationToken`（NSLock）、`SimilarPhotosFeatureProbeCoordinator`（无显式 init、不加 `@MainActor`、`@Published isRunning/progressText/reportText`）、`SimilarPhotosMeasurementCollector`（NSLock，顺序无关汇总）、`SimilarPhotosFeatureProbeService`（私有并发队列 + `DispatchSemaphore` 限流、块内并发、同步取图禁网络、Vision 特征） |
| V1-A | `S2View.swift` 存储属性／`@StateObject`／init 形参／赋值 | `similarPhotosProber`（默认 `nil`）、`similarPhotosProbe` 协调器、两个选择器的 `@State` |
| V2-A | `S2View.swift` 面板挂载点 | `doubleTapProbeSection` 之后加 `similarPhotosProbeSection` |
| P1-A | `App/PhotoCleanupMVEApp.swift` | 头部 `private let similarPhotosProber = SimilarPhotosFeatureProbeService()`；`assetSizeProber:` 之后加实参行 |
| X1-A | `Localizable.xcstrings` | `s2.calibration.similar_probe.` 七条 |
| X2 | `project.pbxproj` | 两个新文件四处登记：`SimilarPhotosProbe.swift`（fileRef `100000000000000000000062`、buildFile `20000000000000000000005F`，App target）、`IC161SimilarPhotosProbeTests.swift`（fileRef `100000000000000000000063`、buildFile `200000000000000000000060`，测试 target） |

### 子项 B（相邻距离、分组与核对列表）

| 处 | 位置 | 变更 |
|---|---|---|
| N1-B | `SimilarPhotosProbe.swift` | 常量加 `windowNeighbors = 12`／`windowSeconds = 600`／`histogramBucketMilliWidth = 50`／`histogramBucketCount = 40`／`previewGroupLimit = 30`／`previewThumbnailLimit = 10`／`thresholdOptions`（七档）；结果加 `neighborPairs`／`distanceFailedCount`／`sampleAssetIDs`；新增纯函数 `SimilarPhotosGrouping`（相邻对、直方图、并查集分组、汇总、核对列表排序、档宽自适应）与 `SimilarPhotosGroupingProbeText`；收集器加按下标存观测／取对／裁剪／距离失败计数；取数循环块内并发算特征、块后**顺序**算该块相邻对距离、只留末 12 个观测 |
| V2-B | `S2View.swift` | 挂 `similarPhotosGroupSection`；阈值 `@State`；三个新计算属性（段、阈值选择器、核对列表）；文件末尾新增 `S2SimilarGroupThumbnailRow`（`ScrollView(.horizontal)` + `LazyHStack`） |
| X1-B | `Localizable.xcstrings` | `s2.calibration.similar_group.` 四条 |

### 子项 C（画质评分）

| 处 | 位置 | 变更 |
|---|---|---|
| N1-C | `SimilarPhotosProbe.swift` | 取图抽成共用 `SimilarPhotosImageFetch`（A 的 `measureOne` 改调它）；`AestheticsScoreMeasurement`（只存 `Float`／`Bool`）／`AestheticsScoreProbeResult`／`AestheticsScoreProbeText`（分档、20 档直方图、报告）／协议 `AestheticsScoreProbing`／`AestheticsScoreProbeCoordinator`／`AestheticsScoreProbeService`（串行队列、`@available(iOS 18.0, *)` 的两个函数、入口一处 `if #available`） |
| V1-C／V2-C | `S2View.swift` | `aestheticsProber` 形参与协调器、样本上限 `@State`；挂 `aestheticsProbeSection`（iOS 17 显示不可用）与 `aestheticsProbeBody`；缩略图行加 `limit` 形参 |
| P1-C | `App/PhotoCleanupMVEApp.swift` | 头部第二个 `private let aestheticsProber = AestheticsScoreProbeService()`；实参行 |
| X1-C | `Localizable.xcstrings` | `s2.calibration.aesthetics_probe.` 七条 |

### 修复与位置调整

| 提交 | 变更 |
|---|---|
| `c46c4b4` | 断言 2 的夹具 `sampleFeatureResult()` 补三个新字段（`neighborPairs: []`／`distanceFailedCount: 0`／`sampleAssetIDs: []`）。这是 B 扩结构体时漏改 A 的夹具，#322 因此在**测试目标**编译失败 |
| `db30e1b` | 三个新段的**定义**从 `assetSizeProbeSection` 与 IC-108 B 注释之间整块移到 `doubleTapProbeSection` 之后（G909 切块锚点要求）。纯位置移动：行多重集合与字符数两侧完全相同 |

## 四、断言与测试函数名

| 断言 | 测试函数 | 所属提交 |
|---|---|---|
| 1 分位数与外推 | `testIC161A_PercentilesAndExtrapolation` | A |
| 2 特征报告全 ASCII 且字段齐全 | `testIC161A_ReportTextIsAsciiAndCarriesEveryField` | A（夹具由 `c46c4b4` 补齐） |
| 3 特征协调器 run 之前零副作用 | `testIC161A_FeatureCoordinatorIsInertUntilRun` | A |
| 4 并查集分组 | `testIC161B_GroupingIsUnionFindOverThresholdEdges` | B |
| 5 相邻窗口、直方图分档与分组报告 | `testIC161B_NeighborWindowAndHistogram` | B |
| 6 画质分档、报告与产品文件终态 | `testIC161C_AestheticsReportBucketsAndFinalShape` | C |

## 五、目录（恰 18 条）

| 子项 | key |
|---|---|
| A（七条） | `s2.calibration.similar_probe.title`／`.start`／`.cancel`／`.share`／`.limit_label`／`.limit_all`／`.concurrency_label` |
| B（四条） | `s2.calibration.similar_group.title`／`.threshold_label`／`.share`／`.empty` |
| C（七条） | `s2.calibration.aesthetics_probe.title`／`.start`／`.cancel`／`.share`／`.unavailable`／`.lowest`／`.highest` |

目录总条数 253 → **271**；`s2.calibration.` 70 → **88**；`s0.` 仍 **38**。18 条每条在 `S2View.swift` 内都有至少一处字面量 `L10n.text("完整 key")` 引用（按扫描器自己的 Singleline 正则核，多行调用照样命中）；纯数字、阈值与 `+K` 一律走 `Text(verbatim:)`，不进目录。

## 六、CI 与人工判定

见 `self-check.md`（三次运行、862／0、真实退出码、目的地实证行、IPA 与 artifact 名称／id／有效期、分段耗时、六条断言、G909／G910／G911、H80 四条）。**本卡无合并闸门，分支不合并。**
