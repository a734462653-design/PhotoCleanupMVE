# IC-153 变更清单

- 任务卡：`<top>/Tasks/IC-20260916-153-scan-service.md`
- 分支：`feature/ic-153-scan-service`
- 基线：`main` = `681cf0699163bfd84a042ea907988680be09a599`（IC-152 报告回填；IC-152 合并提交 `1e603d73c201c5313b0179dd3765ae4fe87f8306`）
- 分支 tip（代码）：`3e84b211e9db17656900c2b429e60643c28f8a4c`
- 提交数：5 个代码提交（子项 A／B／C／D 各一 + 子项 B 的一个推 CI 前降险修正）+ 报告提交
- `schemaVersion`：**7，未动**（`S2Calibration.swift` 不在 diff 内；本卡的门槛与缓存版本号是扫描规则登记值，不进标定配置）

---

## 一、提交清单

| # | SHA | 子项 | 标题 |
|---|---|---|---|
| 1 | `13af137e3602df4beefcdd5ce4f1db7a07f51bb3` | A | 扫描规则登记表、单资产分类与三类别聚合的纯逻辑 |
| 2 | `cec92cea4864a6a622628f4009c0ef292db99a28` | B | 扫描缓存与增量续扫引擎（零 PhotoKit） |
| 3 | `cf76fe9c6f8edc6257433a61ea8643858ad79178` | C | PhotoKit 扫描源、数据源协议实现与 App 接线 |
| 4 | `7c718626d6052f36bac115ca804f3cbb603861d6` | D | 桩补协议钩子属性，断言 13 |
| 5 | `3e84b211e9db17656900c2b429e60643c28f8a4c` | B（修正） | 缓存仓库构造里改用具名类型取静态常量，降编译面风险 |

**实际可摘取单元（惯例 40；与卡内声明有一处出入，见 `self-check.md` 第六节第 6 条）**：

| 摘取 | 能否编译 | 说明 |
|---|---|---|
| 1 单独 | 能 | A 的三个文件（两个产品文件 + 测试文件）在本提交内登记 pbxproj，只依赖 `Core/` 既有类型 |
| 2 单独 | **不能** | B 用到 A 的 `S0ScanRules.cacheSchemaVersion`／`persistEveryAssets`（白名单把这两个常量放在 A 的文件里）、聚合调 A 的 `S0ScanAggregator`，且往 A 新建的测试文件里追加断言——卡内「A、B 各自可单独摘取」对 B 不成立 |
| 1→2（→5） | 能 | 5 只改 B 的一个文件两行，建议与 2 一起摘 |
| 1→2→3 | **不能** | 3 给协议加了属性要求，桩的属性按 D1 放在 4——与卡内「C、D 只能作为 A→B→C→D 连续序列摘取」一致 |
| 1→2→3→4（→5） | 能 | 即本分支 tip |

---

## 二、文件变更全量（`git diff --name-status 681cf06..3e84b21`）

```
M	PhotoCleanupMVE.xcodeproj/project.pbxproj
M	PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
M	PhotoCleanupMVE/Features/S0/S0View.swift
M	PhotoCleanupMVE/Services/AssetSizeScanner.swift
M	PhotoCleanupMVE/Services/S0CleanupDataStub.swift
A	PhotoCleanupMVE/Services/S0LibraryScanService.swift
A	PhotoCleanupMVE/Services/S0ScanCache.swift
A	PhotoCleanupMVE/Services/S0ScanClassifier.swift
A	PhotoCleanupMVE/Services/S0ScanRules.swift
A	PhotoCleanupMVETests/IC153ScanServiceTests.swift
```

十个路径全部落在卡内白名单表内。

### 行数（`git diff --numstat 681cf06..3e84b21`）

| 文件 | 增 | 删 | 子项 |
|---|---|---|---|
| `Services/S0ScanRules.swift`（新） | 40 | 0 | A |
| `Services/S0ScanClassifier.swift`（新） | 233 | 0 | A |
| `Services/S0ScanCache.swift`（新） | 193 | 0 | B（含修正 2 行） |
| `Services/S0LibraryScanService.swift`（新） | 728 | 0 | B 494 行 + C 236 增 2 删 |
| `Services/AssetSizeScanner.swift` | 57 | 0 | C（文件末尾纯追加） |
| `Services/S0CleanupDataStub.swift` | 3 | 0 | D |
| `Features/S0/S0View.swift` | 3 | 0 | C（协议一个属性要求） |
| `App/PhotoCleanupMVEApp.swift` | 29 | 6 | C（A1～A4） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 20 | 0 | A 12 行 + B 8 行 |
| `PhotoCleanupMVETests/IC153ScanServiceTests.swift`（新） | 1589 | 0 | A 577 + B 566 + C 386 + D 60 |

**新 Swift 行数**：产品侧新文件 1194 行（40 + 233 + 193 + 728），既有产品文件净增 86 行（57 + 3 + 3 + 29 − 6）；测试 1589 行。任务卡估的 800～1200 行是产品侧口径，落在区间上沿。

### 零改动实证（`git diff --name-only 681cf06..3e84b21 -- <前缀> | wc -l`）

| 前缀／文件 | 命中 |
|---|---|
| `PhotoCleanupMVE/Core/` | **0** |
| `PhotoCleanupMVE/Features/S1/`、`S2/`、`S3/`、`S4/`、`S5/`、`Shared/` | **0**、**0**、**0**、**0**、**0**、**0** |
| `Features/S0/` 其余四个文件（`S0TabContainer`／`S0HomeMetrics`／`S0SegmentBar`／`S0CategoryRow`） | **0** |
| `Services/PhotoLibraryService.swift`、`PhotoAssetActionService.swift`、`PhotoDeletionService.swift`、`S2RecentAlbumStore.swift`、`S2TutorialCompletionStore.swift` | **0**（逐个） |
| `App/CleanupCoordinator.swift` | **0** |
| `.github/`、`Scripts/` | **0**、**0** |
| `Localizable.xcstrings` | **0** |
| `Features/S2/S2Calibration.swift` | **0** |

---

## 三、逐文件说明

### 子项 A

- **`Services/S0ScanRules.swift`（新）**：七个登记常量，每个定义处有「出处：」注释——`bigVideoMinimumByteCount = 100_000_000`（裁定 一，Decision_log 第 180 条 ④）、`screenRecordingFilenamePrefix = "ScreenRecording_"`（SPEC-S0 v2 第十二节第 4 条）、`screenRecordingPixelSize = 1206×2622`（同上，横竖不限）、`cacheSchemaVersion = 1`（裁定 四）、`persistEveryAssets = 200`（裁定 四）、`byteFetchConcurrency = 4`（裁定 六）、`snapshotThrottleHz = 4`（裁定 五）。
- **`Services/S0ScanClassifier.swift`（新）**：输入模型 `S0ScannedAsset`（卡内所列十一个字段）、`S0ScannedMediaType`（照片／视频）、`S0ScanPixelSize`（登记值的承载类型）、`S0ScreenRecordingEvidence`（两个布尔）、`S0ClassifiedAsset`；`S0ScanClassifier`——A1 命中、A2 归属优先序 `[bigVideo, screenRecording, screenshot]`、A3 排除（`D_全部`／账本／未解析）；`S0ScanAggregationContext` 与 `S0ScanAggregator`——A4 聚合（类别全量、hero 去重、`LIB`、待删篮体积，`categories` 恒三条）。文件内剔注释后的数值字面量只有 `0`、`1`。
- **`PhotoCleanupMVETests/IC153ScanServiceTests.swift`（新）**：断言 1～3 与源码扫描 helper（口径同 IC-147／IC-148）。
- **pbxproj**：文件引用 `100000000000000000000055`／`…56`／`…57`，构建文件 `200000000000000000000052`／`…53`／`…54`。

### 子项 B

- **`Services/S0ScanCache.swift`（新）**：`S0ScanCacheEntry`（裁定 四所列字段，按 `localIdentifier` 键）、`S0ScanCacheFile`、`S0ScanCacheStore`（`Application Support/PhotoCleanupMVE/s0-scan-cache.json`，`.atomic` 写、`NSLock`，构造不建目录不读文件，读不到／解不开／版本不符一律空缓存）、`S0ScanResumePlan`（B2 续扫判定纯函数，四个集合）。日期用 `JSONEncoder` 默认策略，不用 `SessionPersistence` 的 iso8601（理由见 `self-check.md` 第六节第 8 条）。
- **`Services/S0LibraryScanService.swift`（新，本子项部分零 PhotoKit）**：`S0AssetMetadata`、闭包式源 `S0LibraryScanSource`（结构体本身）、扫描引擎 `S0LibraryScanService`——`advanceScan()`／`cancelScan()`／`isScanInFlight`／`persistenceFailureCount`／`currentScanOutcome()`／`currentSnapshot()`／`newestFirst(_:metadataByID:)`；一遍扫描的六步、每 200 项与一遍结束（含取消）各落盘一次、并发 ≤ 4 的任务组取字节、按修订号去重的变化回报。
- **测试**：断言 4～7 与夹具源 `ScanFixture`（记三类调用的次数与线程、可延时、可在第 N 次之后挂起）。
- **pbxproj**：文件引用 `…58`／`…59`，构建文件 `…55`／`…56`。
- **修正提交 5**：`S0ScanCacheStore` 两处 `Self.xxx` 改 `S0ScanCacheStore.xxx`（类为 `final`，语义不变）。

### 子项 C

- **`Services/S0LibraryScanService.swift`**：`import Photos`；`onSnapshotDidChange` 与 `S0SnapshotChangeThrottle`（主线程、相邻两次不短于 250 ms、推迟不丢）；`convenience init()`（`.production` + 产品缓存落点）；`extension S0LibraryScanService: S0CleanupDataProviding {}`；`S0LibraryScanSource.production` 与 `S0PhotoKitScanLibrary`（`PHAsset.fetchAssets(with: nil)` 一遍元数据、每资产一次 `PHAssetResource.assetResources(for:)` 同取视频主资源原始文件名与字节、授权映射）；`S0ScanOutcomeTransition`（回报 → 迁移事件）。
- **`Services/AssetSizeScanner.swift`**：文件末尾追加 `extension AssetSizeScanner`——`scan(resources:options:)` 与私有 `bytes(of:options:)`，与 `scan(_:)` 同一途径，资源数组与请求选项由调用方给。hunk 头：`@@ -487,3 +487,60 @@ final class AssetVolumeService: S2AssetVolumeProviding {`（纯追加，`main` 版全文是改后文件的逐字节前缀）。
- **`Features/S0/S0View.swift`**：唯一 hunk `@@ -14,6 +14,9 @@ protocol S0CleanupDataProviding: AnyObject {`——协议加 `var onSnapshotDidChange: (() -> Void)? { get set }` 与两行文档注释。
- **`App/PhotoCleanupMVEApp.swift`**：A1 `s0DataProvider` 换成 `S0LibraryScanService()`；A2 `tabContainer` 的 `.onAppear` 接 `pendingDeletionAssetIDs = { s1Machine.sessionStore.allPendingDeletionAssetIDs }` 与 `onSnapshotDidChange`（摄入 + `S0ScanOutcomeTransition.events` 给出的事件）；A3 根 `.onAppear` 在既有 `if` 之后**另起一个同条件的 `if`** 调 `advanceScan()`；A4 `restoreS0Foreground()` 在守卫之后、摄入之前调 `advanceScan()`。
- **测试**：断言 8～12 与 `CallbackLog`。

### 子项 D

- **`Services/S0CleanupDataStub.swift`**：加 `var onSnapshotDidChange: (() -> Void)?` 与两行文档注释，其余一字未动。
- **测试**：断言 13。
- **pbxproj**：本子项无新文件，未改（新文件已在 A、B 各自提交里登记，见 `self-check.md` 第六节第 6 条）。

---

## 四、pbxproj 登记（D3，登记前重扫最大 id）

| 时点 | 文件引用最大 id | 构建文件最大 id |
|---|---|---|
| `main`（`681cf06`） | `100000000000000000000054` | `200000000000000000000051` |
| 本分支 tip | `100000000000000000000059` | `200000000000000000000056` |

| 文件 | 文件引用 | 构建文件 | 所在 Sources 阶段 |
|---|---|---|---|
| `S0ScanRules.swift` | `100000000000000000000055` | `200000000000000000000052` | 应用源码 |
| `S0ScanClassifier.swift` | `100000000000000000000056` | `200000000000000000000053` | 应用源码 |
| `IC153ScanServiceTests.swift` | `100000000000000000000057` | `200000000000000000000054` | 测试源码 |
| `S0ScanCache.swift` | `100000000000000000000058` | `200000000000000000000055` | 应用源码 |
| `S0LibraryScanService.swift` | `100000000000000000000059` | `200000000000000000000056` | 应用源码 |

撞号扫描：十个新 id 在 `main` 版 pbxproj 中**零出现**；本分支版全部对象定义 206 个、**重复定义 0**；每个文件引用 id 恰出现 3 次（定义、构建文件引用、组成员），每个构建文件 id 恰出现 2 次（定义、Sources 阶段）。

---

## 五、占位值登记

本卡**无**标定出厂值变更，`S2CalibrationConfiguration.schemaVersion` 保持 **7**。七个扫描规则常量是登记值（`S0ScanRules`），不是占位值；其中 `bigVideoMinimumByteCount` 为 ④ Lynn 2026-09-16 定案，执行端未改。
