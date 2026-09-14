# IC-145 变更清单 · 扫描服务探针

- **卡**：`IC-20260914-145-scan-service-probe.md`
- **分支**：`probe/ic-145-scan-service`（**不合并进 `main`**，与 `probe/ic-137-media-playback` 同例）
- **基线**：`main` = `98e76c90e42d52817e1f59f818412a5f0688127b`（标题 `docs: IC-144 回填 G834/G835（合并 ff7885b，main #287 绿 741 项 0 失败）`）
- **分支 tip**：`46085bd0af21a1ae3ccf4ad63f25b0d310663663`

---

## 一、提交清单

| # | 完整 SHA | 子项 | 标题 |
|---|---|---|---|
| 1 | `cebee9b5f195b75f85d963a7f6ca662dc3d897d2` | A | `feat(IC-145 A): 屏幕录制识别启发式探针（只出数，零产品行为）` |
| 2 | `df95b7388c16256957ffdd2b8d17c83715103058` | B | `feat(IC-145 B): 字节数取数途径对比与耗时基准（三途径，含 ③ 资源属性途径）` |
| 3 | `1e0f322f8b7d803fc42b526cad97d36df5d0c6ce` | C | `feat(IC-145 C): 类别元数据可得性与批量读取耗时（两遍分开计时）` |
| 4 | `46085bd0af21a1ae3ccf4ad63f25b0d310663663` | A 修正 | `fix(IC-145 A): 补 ProbeFormat 改名残留，并降两处编译面风险` |

### 与「各项各自独立 commit、每个可单独 cherry-pick」的两处偏差（如实登记）

1. **提交 4 是计划外的第四个提交。** 它修的是提交 1 引入的一处编译错误（`ProbeFormat` 的 `none` 改名为 `absentText` 时，漏了 `optionalCount` 里的 `?? none`；`none` 不带前导点不会解析成 `Optional.none`，`ProbeFormat` 也已无同名成员，编译报 `cannot find 'none' in scope`）。发现时提交 1～3 已落地，CLAUDE.md 第三节禁止 `amend` / `rebase` / 改写历史，故不回填而另起一个修正提交。**后果：提交 1 单独 cherry-pick 不能编译，须连同提交 4 一起取。**
2. **提交 3 含一处跨子项的无输出变化重构**：把子项 A、B 报告文本里的长串 `+` 拼接改成数组 `joined`（长拼接链是 Swift 表达式类型检查超时的经典成因）。输出逐字节不变，由断言 2、4 钉住。同样因禁止 amend 而落在提交 3。
3. 三个子项共用 `ProbeFormat` / `ProbeStatistics` 等基础设施（均在提交 1 引入），因此 B、C 单独 cherry-pick 亦依赖 A。这是「三个子项写在同一个新文件里」的必然结果，白名单即如此规定。

---

## 二、文件变更

| 文件 | 动作 | 涉及提交 | 说明 |
|---|---|---|---|
| `PhotoCleanupMVE/Services/ScanServiceProbe.swift` | **新增** | 1、2、3、4 | 三个探针的取数实现 + 纯函数报告文本 + 三个协调器 + 共用格式化 |
| `PhotoCleanupMVETests/IC145ScanProbeTests.swift` | **新增** | 1、2、3、4 | 14 个纯函数测试，覆盖断言 1～7 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 修改 | 1、2、3 | 仅：3 个探针协议注入 + 3 个 `@StateObject` 协调器 + 3 个面板段，挂在既有 `doubleTapProbeSection` 之后 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 修改 | 1、2、3 | 仅：3 个 `private let` 探针实现 + `s2Screen(machine:)` builder 内 3 个实参 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 修改 | 1、2、3 | 仅新增 9 个 key，既有条目零改动（逐提交 diff 均为纯插入） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 修改 | 1 | 两个新文件各 4 处登记 |

`git diff --name-only main...HEAD` 的完整结果就是上表这 6 个文件，无第七个。

---

## 三、新增公开符号（同模块 internal）

### 子项 A

| 符号 | 种类 | 用途 |
|---|---|---|
| `ScreenRecordingRule` | `enum: String, CaseIterable` | 四种判据：`filename-only` / `resolution-only` / `filename-or-resolution` / `filename-and-resolution` |
| `ScreenRecordingHeuristic` | `enum`（命名空间） | `filenamePrefix`、`matchesFilename(_:caseSensitive:)`、`matchesResolution(pixelSize:screenSize:)`、`isScreenRecording(filename:pixelSize:screenSize:rule:)` |
| `ScreenRecordingMeasurement` | `struct` | 单条视频的测量 + `verdict(for:)` |
| `ScreenRecordingProbePreparation` | `struct` | 全库视频标识、全库资产总数、屏幕像素 |
| `ScreenRecordingProbing` | `protocol` | `prepare()` / `measure(assetID:screenPixelSize:)` |
| `ScreenRecordingProbeText` | `enum` | `formatVersion`、`columns`、`identifierPrefix`、`row`、`header`、`summary`、`report`、`progress` |
| `ScreenRecordingHeuristicProbeService` | `final class` | PhotoKit 实现 |
| `ScreenRecordingProbeCoordinator` | `final class: ObservableObject` | 运行协调器 |

### 子项 B

| 符号 | 种类 | 用途 |
|---|---|---|
| `ByteRoute` | `enum: String, CaseIterable` | `data` / `url` / `resource-property` |
| `ResourcePropertyRoute` | `enum`（命名空间） | `candidateKey`、`publicControlKey`、`probedKeys`、`isPublicInterface(_:)`、`respondsToKey(_:key:)`、`byteCount(of:)`、`valueTypeName(of:key:)` |
| `ResourceKeyProbeResult` | `struct` | 单键探测结果 |
| `ByteRouteMeasurement` | `struct` | 单条资产的三途径读数 + `byteCount(for:)` / `elapsedMilliseconds(for:)` / `byteDelta(_:_:)` / `hasByteMismatch` |
| `ByteRoutePair` | `struct` | 途径两两配对（3 对） |
| `ProbeStatistics` | `enum` | `percentile(_:_:)`（最近秩法） |
| `ByteRouteSampling` | `enum` | `sampleLimit = 200`、`perKindLimit = 70`、`stratifiedSample(photo:livePhoto:video:limit:perKindLimit:)` |
| `ByteRouteProbePreparation` | `struct` | 样本标识、全库总数、键探测结果 |
| `ByteRouteProbing` | `protocol` | `prepare()` / `measure(assetID:)` |
| `ByteRouteProbeText` | `enum` | `formatVersion`、`columns`、`row`、`keyProbeLine`、`header`、`routeSummary`、`mismatchLines`、`extrapolationLines`、`summary`、`report`、`progress` |
| `ByteRouteBenchmarkProbeService` | `final class` | PhotoKit 实现；途径 1、2 复用 `AssetSizeProbeService` |
| `ByteRouteProbeCoordinator` | `final class: ObservableObject` | 运行协调器；额外暴露 `measurements` 与 `dataRouteP50Milliseconds` 供子项 C 取参照值 |

### 子项 C

| 符号 | 种类 | 用途 |
|---|---|---|
| `VideoDurationBucket` | `enum: String, CaseIterable` | `lt-30s` / `30s-2min` / `2min-10min` / `gte-10min` + `bucket(forSeconds:)` |
| `VideoPixelBucket` | `enum: String, CaseIterable` | `lt-1280` / `1280-1919` / `1920-2559` / `gte-2560` + `bucket(forLongEdge:)` |
| `CategoryMetadataPass` | `struct` | 第一遍读数 + `averageMicrosecondsPerAsset` |
| `CategoryMetadataEditedPass` | `struct` | 第二遍读数 |
| `CategoryMetadataProbing` | `protocol` | `runMetadataPass()` / `runEditedPass()` |
| `CategoryMetadataProbeText` | `enum` | `formatVersion`、`header`、`distributionLines`、`editedLine`、`feasibilityLine`、`report`、`progress` |
| `CategoryMetadataProbeService` | `final class` | PhotoKit 实现 |
| `CategoryMetadataProbeCoordinator` | `final class: ObservableObject` | 运行协调器 |

### 三子项共用

| 符号 | 种类 | 用途 |
|---|---|---|
| `ProbeFormat` | `enum` | `fieldSeparator`、`absentText`、`summaryTag`、`yesNo`、`optionalCount`、`seconds`、`milliseconds`、`optionalMilliseconds`、`microseconds`、`ratio`、`percentage`、`date` |
| `ProbeDeviceMetrics` | `enum` | `@MainActor nativeScreenPixelSize()` |

---

## 四、占位值登记

**本卡不新增、不修改任何出厂值。**

- `S2CalibrationConfiguration.schemaVersion` **仍为 7**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`，该文件不在本卡 diff 内）。
- 本卡引入的三个数值常量都是**探针运行参数**，不入 `S2CalibrationConfiguration`、不入 Keychain、不进 `export-format.md`，与 IC-099b 的 `S2AssetSizeProbeCoordinator.assetLimit`、IC-108 B 的运行态开关同例：

| 常量 | 值 | 出处 | 性质 |
|---|---|---|---|
| `ByteRouteSampling.sampleLimit` | `200` | 卡内子项 B「上限 `byteRouteSampleLimit = 200`」 | 探针抽样上限 |
| `ByteRouteSampling.perKindLimit` | `70` | 卡内子项 B「照片、视频、实况各至多 70」 | 探针分层上限 |
| `CategoryMetadataProbeService.recentWindowSeconds` | `30 × 24 × 60 × 60` | 卡内子项 C「最近 30 天虚拟范围」 | 探针统计窗口 |

`CategoryMetadataProbeCoordinator.phaseCount = 2` 是实现内部的阶段数，非取值。

---

## 五、新增目录 key（9 个）

| key | 值 |
|---|---|
| `s2.calibration.screen_recording_probe.title` | 屏幕录制识别探针（IC-145 A） |
| `s2.calibration.screen_recording_probe.start` | 运行屏幕录制识别探针 |
| `s2.calibration.screen_recording_probe.share` | 导出屏幕录制识别报告 |
| `s2.calibration.byte_route_probe.title` | 字节取数途径基准探针（IC-145 B） |
| `s2.calibration.byte_route_probe.start` | 运行字节取数基准探针 |
| `s2.calibration.byte_route_probe.share` | 导出字节取数基准报告 |
| `s2.calibration.category_metadata_probe.title` | 类别元数据探针（IC-145 C） |
| `s2.calibration.category_metadata_probe.start` | 运行类别元数据探针 |
| `s2.calibration.category_metadata_probe.share` | 导出类别元数据报告 |

目录条目数 213 → **222**；`scan-hardcoded-user-visible-strings.ps1` 报「产品源码引用 key = 222」，与目录条目数一致，无孤儿 key、无缺失 key。

---

## 六、pbxproj 登记

加登记前重扫各族最大对象 id（陷阱：撞号不报错，IC-134 #262 实例）：

```
100000 族最大 = 100000000000000000000044
200000 族最大 = 200000000000000000000041
300000 族最大 = 30000000000000000000000D
400000 族最大 = 400000000000000000000006
500000 族最大 = 500000000000000000000006
510000 族最大 = 510000000000000000000003
600000 族最大 = 600000000000000000000002
700000 族最大 = 700000000000000000000003
```

本卡取号与撞号核验（`grep -c` 全为 0 后才写入）：

| 对象 | id | 写入前命中数 |
|---|---|---|
| `ScanServiceProbe.swift` PBXFileReference | `100000000000000000000045` | 0 |
| `IC145ScanProbeTests.swift` PBXFileReference | `100000000000000000000046` | 0 |
| `ScanServiceProbe.swift` PBXBuildFile | `200000000000000000000042` | 0 |
| `IC145ScanProbeTests.swift` PBXBuildFile | `200000000000000000000043` | 0 |

登记落点（各文件 4 处）：

| 行 | 内容 |
|---|---|
| 19 | `200000000000000000000042 /* ScanServiceProbe.swift（源码） */ = {isa = PBXBuildFile; fileRef = 100000000000000000000045 …}` |
| 47 | `200000000000000000000043 /* IC145ScanProbeTests.swift（测试源码） */ = {isa = PBXBuildFile; fileRef = 100000000000000000000046 …}` |
| 98 | `100000000000000000000045 /* ScanServiceProbe.swift */ = {isa = PBXFileReference; …}` |
| 129 | `100000000000000000000046 /* IC145ScanProbeTests.swift */ = {isa = PBXFileReference; …}` |
| 235 | `Services` 组 children |
| 334 | `PhotoCleanupMVETests` 组 children |
| 471 | 应用 target Sources 构建阶段 |
| 520 | 测试 target Sources 构建阶段 |

`files = (` 命中行：164、171、438、447、458、496。其中 458 是应用 target 的 Sources 阶段（含第 471 行），496 是测试 target 的 Sources 阶段（含第 520 行）。

---

## 七、范围边界自查

| 项 | 结果 |
|---|---|
| `AssetSizeScanner.scan(_:)`（N1） | **零改动**（整文件逐字节相同，哈希见 self-check.md G836 节） |
| `ByteAccumulator`（N2） | **零改动** |
| `AssetVolumeService`（N4） | **零改动** |
| `AssetSizeProbeService` / `S2AssetSizeProbeCoordinator` / `S2AssetSizeProbeText`（N3、P1、P2） | **零改动**；子项 B 通过**调用** `AssetSizeProbeService` 复用途径 1、2，不改其源码 |
| `S2Calibration.swift` | 不在 diff；`schemaVersion` 仍 7 |
| S0 / S1 / S3 / S4 / S5 任何文件 | 不在 diff |
| S2 既有产品行为与取值 | 未触碰；`S2View.swift` 的改动只有注入点、`@StateObject` 声明、面板段三类，既有 section 一行未改 |
| SPEC / `Decision_log.md` | 未触碰 |
| `rebase` / `amend` / `force push` | 未执行 |
| 合并进 `main` | 未执行（本卡无合并闸门） |
