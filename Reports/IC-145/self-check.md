# IC-145 自验报告 · 扫描服务探针（屏幕录制识别 / 字节数取数途径 / 类别元数据）

## 结论（先行）

- **三个子项已实装并全绿。** CI **#288**（run id `34820917263`，attempt 1）一次绿，被测提交 `46085bd0af21a1ae3ccf4ad63f25b0d310663663`，**XCTest 755 项 0 失败**，真实退出码 **0**，目的地 `OS:26.2, name:iPhone 16`，Xcode 26.3（Build 17C529）。基数 741 + 本卡新增 **14** = 755，与预期一致。
- **断言 1～7 全部落地并在 CI 日志逐条 `passed`**（函数名与日志行见第五节）。
- **本卡不出结论。** 屏幕录制的**准确率**、三条途径的**耗时与一致性**、元数据遍历的**实际耗时**，三者都要 Lynn 在真机跑 H68 后才有数；模拟器上没有真实照片库，任何「模拟器绿」都冒充不了真机结论（纪律 5、陷阱 1）。本卡交付的是**取数装置与报告格式**，不是数。
- **途径 3 的键探测结果目前为「代码已就位、值未实测」。** 键名 `fileSize` 属 `PHAssetResource` 的**非公开**运行时属性，报告里 `public-interface=no` 并在头部标 `PROBE ONLY, NOT PUBLIC API, MUST NOT SHIP`；断言 5 以源码扫描钉死它不出探针文件。**是否可用、能否进产品，由决策会话裁定，执行端不代为判断。**
- **一处与卡内假设的偏差已如实记录**（第九节第 1 条）：卡内子项 C 字段表写 `PHAsset.canPerform(.content)` 作「已编辑判定」，实测语义是**可编辑性**判定而非**已编辑**判定，两者不是同一件事。本卡按卡内括号里的「或等价的已编辑判定」补了第二遍 `adjustmentData` 枚举，两遍分开计时、报告分列。
- **本卡不产生可合并成果**，分支 `probe/ic-145-scan-service` **不合并进 `main`**，与 `probe/ic-137-media-playback` 同例。

---

## 一、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260914-145-scan-service-probe.md` |
| 规格依据 | SPEC-S0 v1 第二节 `SZ(a)` / `CAT`、第十二节未定项 4；Decision_log 第 159、167 条 |
| 继承提交（`main` tip） | `98e76c90e42d52817e1f59f818412a5f0688127b` |
| 开工核对 1 | `git log --oneline -1 main` → `98e76c9 docs: IC-144 回填 G834/G835（合并 ff7885b，main #287 绿 741 项 0 失败）`，标题以 `docs: IC-144` 开头 ✅ |
| 开工核对 2 | `git merge-base --is-ancestor ff7885b6fe5c381395d79217c29243b8e8ac8bf9 main` → 退出码 **0**（为真）✅ |
| 开工核对 3（纪律 8） | `git status --porcelain` → **空输出** ✅ |
| 目标分支 | `probe/ic-145-scan-service`，自上述 `main` 切出，**不合并** |
| 分支 tip | `46085bd0af21a1ae3ccf4ad63f25b0d310663663` |
| 现状基数 | `main` 上 XCTest 741 项（IC-144 #287） |

### 提交清单（各子项独立 commit）

| # | 完整 SHA | 子项 | 标题 |
|---|---|---|---|
| 1 | `cebee9b5f195b75f85d963a7f6ca662dc3d897d2` | A | `feat(IC-145 A): 屏幕录制识别启发式探针（只出数，零产品行为）` |
| 2 | `df95b7388c16256957ffdd2b8d17c83715103058` | B | `feat(IC-145 B): 字节数取数途径对比与耗时基准（三途径，含 ③ 资源属性途径）` |
| 3 | `1e0f322f8b7d803fc42b526cad97d36df5d0c6ce` | C | `feat(IC-145 C): 类别元数据可得性与批量读取耗时（两遍分开计时）` |
| 4 | `46085bd0af21a1ae3ccf4ad63f25b0d310663663` | A 修正 | `fix(IC-145 A): 补 ProbeFormat 改名残留，并降两处编译面风险` |

**第 4 个提交是计划外的**，详见第九节第 3 条。

---

## 二、CI（预算 2 次，实用 1 次）

| 项 | 值 | 来源 |
|---|---|---|
| 运行编号 | **#288** | `actions/runs/34820917263` → `run_number` |
| run id | `34820917263` | 同上 |
| run_attempt | `1` | 同上（无重跑） |
| 被测提交完整 SHA | `46085bd0af21a1ae3ccf4ad63f25b0d310663663` | 同上 → `head_sha` |
| 结论 | `success` | 同上 → `conclusion` |
| XCTest 项数 / 失败数 | **755 项 / 0 失败（0 unexpected）**，37.206 (50.570) 秒 | check-run `103902061177` 的 `notice` 标题「XCTest 执行摘要」；日志同行 |
| 摘要 notice 存在（陷阱 20） | ✅ `##[notice]	 Executed 755 tests, with 0 failures (0 unexpected)` | 日志 `08:13:25.7706620Z` |
| 真实退出码 | **0** | `ci.yml` 的「运行 XCTest」步骤以 `exit "$test_status"` 原样退出；该步骤 `conclusion = success`（`actions/runs/34820917263/jobs`，10 个步骤全 `success`），故 `test_status = 0`。日志另有 `** TEST SUCCEEDED **` 与 `XCTest 已全部通过。` |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` | 日志 `08:05:42.4511710Z` |
| 目的地 xcodebuild 回显 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 日志 `08:05:46.3612700Z` |
| 工具链 | `已选择工具链：/Applications/Xcode_26.3.0.app`；`Xcode 26.3` / `Build version 17C529` | 日志 `08:05:26.7424780Z`、`08:05:30.0304850Z` |
| IPA 字节数 | **1435603** | `notice`「未签名 IPA 校验」；日志 `08:15:01.1930080Z` 同值 |
| IPA SHA-256 | `35424d4a6cb338b89a32850e1c65a4f0841da16f943dfe0146737d5e0b7b3898` | 同上 |
| 上传产物 | `PhotoCleanupMVE-unsigned-46085bd0af21`，1435773 字节（zip 外壳） | `actions/runs/34820917263/artifacts` |

CI 上的结构自验与硬编码扫描两步均通过（日志 `08:05:40.9527720Z`、`08:05:40.9528050Z`）：
```
  - 目录条目：222
  - 产品源码引用 key：222
  - 用户可见硬编码残留：0
扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。
结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。
```

**项数口径（陷阱 22）**：755 取自 CI 日志的 `Executed N tests` 执行摘要，不是本机 grep。本机 `grep -c "^    func testIC145"` 为 14，与 741 + 14 = 755 一致。

---

## 三、本地门禁

| 门禁 | 退出码 | 关键输出 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | `结构自验通过：…及不少于 189 项测试的数量门禁均符合要求。` |
| `Scripts/scan-hardcoded-user-visible-strings.ps1`（由 selfcheck 内联调用，CI 另单独跑一遍） | **0** | `目录条目：222`／`产品源码引用 key：222`／`用户可见硬编码残留：0` |
| `git diff --check` | **0** | 无输出 |

本机是 Windows、无 Xcode（CLAUDE.md 第五节），**不能在本地跑 XCTest 或构建 IPA**；第二节所有模拟器读数均来自 GitHub Actions。

---

## 四、逐条验收门禁

### G836 · diff 限于白名单，三处零改动

`git diff --name-only main...HEAD` 的**完整**结果（无第七个文件）：

```
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVE/Services/ScanServiceProbe.swift
PhotoCleanupMVETests/IC145ScanProbeTests.swift
```

逐条对照白名单：6 个文件全部在卡内白名单内；白名单允许但未动的只有「无」。

**`Services/AssetSizeScanner.swift` 零改动实证**——按符号块做花括号配平提取后取 SHA-256（`main` 侧 vs `HEAD` 侧）：

| 符号 | 行数 | `main` SHA-256 | `HEAD` SHA-256 | 相同 |
|---|---|---|---|---|
| `struct AssetSizeScanner`（N1） | 42 | `57C98820643D2F36C314749FAAD2E479970830B91E7205C65A8B709CDB87574A` | `57C98820643D2F36C314749FAAD2E479970830B91E7205C65A8B709CDB87574A` | ✅ |
| `private final class ByteAccumulator`（N2） | 22 | `7ED8F9AB4A248DA9A162CF8410C2678AAD0295BDEFF5DB0BB18E38FB7193B905` | `7ED8F9AB4A248DA9A162CF8410C2678AAD0295BDEFF5DB0BB18E38FB7193B905` | ✅ |
| `final class AssetVolumeService`（N4） | 145 | `B07A7D8F9F98C8740CD2A1153E63FD5D447AED3B441981EF3E7D3905896F875D` | `B07A7D8F9F98C8740CD2A1153E63FD5D447AED3B441981EF3E7D3905896F875D` | ✅ |
| **整文件** | 489 | `9ECA40FF4915761097307F58182EE654BCB5DDD02E6E45CF990448B6B557999D` | `9ECA40FF4915761097307F58182EE654BCB5DDD02E6E45CF990448B6B557999D` | ✅ |

整文件哈希相同已强于「三处零改动」：`AssetSizeScanner.swift` **逐字节未改**，`AssetSizeProbeService`（N3）与 `ContinuationResumer` 也一并零改动。子项 B 对 N3 的复用是**调用**，不是修改。

**其余边界：**

| 项 | 结果 | 实证 |
|---|---|---|
| `S2Calibration.swift` 在 diff 内？ | **否** | `git diff --name-only main...HEAD \| grep -c S2Calibration` → `0` |
| `schemaVersion` | **仍 7** | `PhotoCleanupMVE/Features/S2/S2Calibration.swift:118` → `static let schemaVersion = 7` |
| S0 / S1 / S3 / S4 / S5 任何文件 | **零改动** | 上列 6 个文件中无 `Features/S1`、`Features/S3`、`Features/S4`、`Features/S5` 路径；S0 尚未实装，无对应文件 |
| S2 既有产品行为与取值 | **未触碰** | `S2View.swift` 的 diff 只有三类：3 处 `private let` 注入声明、3 处 `@StateObject` 协调器声明、3 个新 `…ProbeSection` 计算属性 + 3 行挂载。既有 section 一行未改 |

**G836 通过。**

---

### G837 · 绿

见第二节：全部 XCTest 通过、真实退出码 0、摘要 notice 存在、iOS 26.2 / iPhone 16、IPA 已登记。断言 1～7 的函数名与日志核对见第五节。

**G837 通过。**

---

### G838 · 三个探针段的关闭态零副作用

对 `ScanServiceProbe.swift` 做**按类声明体花括号配平**的提取后扫描（不是整文件 grep，避免把取数实现的命中算到协调器头上）：

| 协调器 | 有显式 `init`？ | `PHPhotoLibrary` / `PHAsset` / `PHAssetResource` / `NotificationCenter` / `UserDefaults` 命中数 |
|---|---|---|
| `ScreenRecordingProbeCoordinator` | **否** | **0** |
| `ByteRouteProbeCoordinator` | **否** | **0** |
| `CategoryMetadataProbeCoordinator` | **否** | **0** |

三个协调器都**没有显式 `init`**——只有 `@Published private(set) var isRunning = false` / `progressText = ""` / `reportText = ""`、`measurements = []`、`runTask: Task<Void, Never>?` 这类字面量初始化，编译器合成的默认 `init` 里不可能有副作用。这比卡内要求的「`init` 内无这些调用」更强：**整个协调器声明体内一次都没出现**上述五个符号，取数一律经 `run` 传入的 prober 发起。

**正对照（`run` 的下游确有 PhotoKit 调用）：**

| 取数实现 | `PHAsset.` 命中 | `PHAssetResource.` 命中 |
|---|---|---|
| `ScreenRecordingHeuristicProbeService` | 3 | 1 |
| `ByteRouteBenchmarkProbeService` | 2 | 2 |
| `CategoryMetadataProbeService` | 2 | 1 |

另外，`App/PhotoCleanupMVEApp.swift` 里三个 `private let …Prober = …Service()` 构造的都是**空对象**（三个 Service 都没有存储属性，也没有显式 `init`），应用启动构造它们不发起任何 PhotoKit 请求。

**G838 通过。**

---

### 无合并闸门

本卡分支不合并进 `main`，无 G8xx 合并闸门；最后一道是 CI 绿 + 本报告。**未执行任何合并操作。**

---

## 五、断言 1～7 逐条对账

每条给「断言 → 测试函数名 → CI 日志 `passed` 行」。全部来自 #288 日志中 `Test Suite 'IC145ScanProbeTests'`（`08:11:44.214` 起、`08:11:44.315` 通过）区间。

| 断言 | 卡内要求 | 测试函数名 | CI 日志 |
|---|---|---|---|
| **1** | 判据函数 `isScreenRecording(filename:pixelSize:screenSize:rule:)` 对四种 `rule` 的真值表逐条正确，含边界（文件名恰为 `RPReplay_Final`、宽高互换、屏幕尺寸为零时不得判真） | `testIC145A_FilenameRuleIsCaseSensitivePrefixOnly`<br>`testIC145A_ResolutionRuleAllowsSwapAndRejectsZeroScreen`<br>`testIC145A_CombinedRulesCoverTheFullTruthTable` | `passed (0.001 seconds)`<br>`passed (0.002 seconds)`<br>`passed (0.002 seconds)` |
| **2** | `ScreenRecordingProbeText.row/header/summary` 为纯函数，给定构造好的测量值产出预期字符串；`formatVersion` 恒为 1 | `testIC145A_ProbeTextRowHeaderAndSummaryAreDeterministic`<br>`testIC145A_ReportListsHitsAndResolutionOnlySuspectsSeparately` | `passed (0.002 seconds)`<br>`passed (0.002 seconds)` |
| **3** | 耗时分档统计 `percentile(_:_:)` 对已知数组给出正确的 p50／p95（含单元素、偶数长度、空数组返回 nil） | `testIC145B_PercentileUsesNearestRankAndHandlesEdgeCases` | `passed (0.002 seconds)` |
| **4** | `ByteRouteProbeText` 的行与汇总拼装正确；不一致明细只在确有差值时出现 | `testIC145B_ProbeTextRowAndRouteSummaryAreDeterministic`<br>`testIC145B_MismatchLinesAppearOnlyWhenBytesActuallyDiffer` | `passed (0.002 seconds)`<br>`passed (0.005 seconds)` |
| **5** | 途径 3 的键名字符串与 `value(forKey:)` 调用只出现在 `ScanServiceProbe.swift` 内；`AssetSizeScanner.swift`、`Features/**`、`App/**` 命中数为 0（正对照：探针文件内 ≥ 1） | `testIC145B_ResourcePropertyKeyAndKVCStayInsideTheProbeFile` | `passed (0.063 seconds)` |
| **6** | 分档函数对边界值归档正确（恰 30 s 归哪档须在报告中写明口径并与断言一致） | `testIC145C_DurationBucketBoundariesAreHalfOpen`<br>`testIC145C_PixelBucketBoundariesAreHalfOpenOnTheLongEdge` | `passed (0.001 seconds)`<br>`passed (0.001 seconds)` |
| **7** | `CategoryMetadataProbeText` 拼装正确 | `testIC145C_ProbeTextHeaderDistributionAndFeasibility`<br>`testIC145C_EmptyLibraryAndEmptyBucketsDegradeCleanly` | `passed (0.001 seconds)`<br>`passed (0.003 seconds)` |
| 附加 | 分层抽样（卡内子项 B 取数规则，未单列断言号） | `testIC145B_StratifiedSampleCapsPerKindAndTotal` | `passed (0.001 seconds)` |

**14 个测试函数全部 `passed`，无 `failed`、无 skipped。** 项数对账：741（`main` #287）+ 14 = 755，与 #288 的 `Executed 755 tests` 一致。

### 断言 5 的扫描口径（重要）

扫的是**带引号的键名字面量** `"fileSize"`，不是裸子串 `fileSize`。理由：`AssetSizeScanner.swift` 第 224、483 行有 `forKeys: [.fileSizeKey]`，`.fileSizeKey` 是 `URLResourceKey` 的成员、不带引号；用裸子串扫会把这两行误判成「键名外泄」。带引号的扫描既符合卡内「键名**字符串**」的措辞，也不产生假阳性。

本机开工前实测（`grep -rn` 于 `PhotoCleanupMVE/`，本卡改动之前）：`value(forKey:` 命中 **0** 处、`"fileSize"` 命中 **0** 处，故负对照不是「本来就有、被我忽略」。

### 断言 6 的分档口径（卡内点名要写明）

- **时长**：半开区间 `[下界, 上界)`。恰 **30 s 归 `30s-2min`**、恰 120 s 归 `2min-10min`、恰 600 s 归 `gte-10min`。报告头部 `duration-buckets=half-open [lower, upper): 30s goes to 30s-2min, 120s goes to 2min-10min, 600s goes to gte-10min` 写的就是这条，与断言同口径。
- **像素**：卡内未指定口径，本探针取**长边像素**、同样半开区间，边界 1280 / 1920 / 2560 对齐常见录制规格。报告头部 `pixel-buckets=half-open on the long edge in pixels`。**这是执行端选的口径，不是卡内规定**，决策会话若要改口径请在实装卡里指定。

---

## 六、根因假设的确认／推翻

**本卡的三处 ③ 都没有在本卡被确认或推翻——它们要真机数据才能判，本卡只交付量它们的装置。** 逐条说明现状：

| ③ | 卡内表述 | 本卡状态 |
|---|---|---|
| ③-1 | `RPReplay_Final` 文件名前缀 + 分辨率启发式（SPEC-S0 v1 未定项 4） | **未判**。四种判据已实装并各自计数，明细分「任一命中」与「分辨率命中但文件名未命中」两组。**准确率 = 命中 ∩ 真值，真值只有 Lynn 知道**，故本卡不给准确率，只给命中明细供人工核对（H68 第 2 项） |
| ③-2 | 数据途径对 5,000 张以上的库可能几分钟出不来首页 hero | **未判**。三条途径的 p50 / p95 / 最大耗时与全库外推已实装，外推逐行标注「假设串行、无缓存、无并发」是上界估计。实数待 H68 第 3 项 |
| ③-3 | `PHAssetResource` 上存在可直接读到字节数的属性或 KVC 键 | **代码就位，值未实测**。探测先 `responds(to:)` 再取值；候选键 `fileSize` 标 `public-interface=no`，另配公开属性 `originalFilename` 做正对照，以便区分「键不存在」与「探测方法不灵」。**responds 结果只有真机能出**（模拟器不测 PhotoKit，卡内明令）。见第八节的私有 API 标注 |

**另有一处卡内表述与实测语义不符，已按纪律 3 停下报告，见第九节第 1 条。**

---

## 七、三个探针的报告格式（供决策会话读 Lynn 回传的文本）

三份报告都是 `formatVersion = 1`，字段分隔符 `|`，**全 ASCII**（原因见第九节第 2 条）。

### 子项 A `IC-145 A screen-recording heuristic probe`

- 头部 7 行：标题、`format-version`、`columns`、`filename-rule`、`resolution-rule`、`screen-pixels=<W>x<H>`、`video-count=N|library-asset-count=M|unresolved=K`。
- `[hits] any-rule-matched=N` 段：**任一判据命中**的全部明细行。
- `[resolution-only] suspected-false-positive=N` 段：**分辨率命中但文件名未命中**的全部行（误认主要嫌疑，是第一组的子集，单列以便人工核对）。
- 明细列：`id8|filename|pixels|duration-s|created|name-cs|name-ci|resolution`。
- 汇总 8 行：四种判据各一行 `hits=x/y (z%)`，加大小写不敏感命中数、分辨率命中∧文件名未命中、文件名命中∧分辨率未命中、无视频资源文件名数。

`name-cs`／`name-ci` 是**两列**（大小写敏感与不敏感），四种 `rule` 的判据统一取**敏感**那一列；不敏感列单独计数，供决策会话看大小写是否真的构成差异。

### 子项 B `IC-145 B byte-route benchmark probe`

- 头部含三条途径各自的定义、`timing-note`、`percentile-note`、抽样参数，再跟每个探测键一行 `key-probe|key=…|public-interface=…|responds=…|value-type=…`。
- 明细列：`id8|kind|edited|enum-ms|data-bytes|data-ms|url-bytes|url-ms|prop-bytes|prop-ms`。
- `[mismatch] assets=N` 段**仅在确有差值时出现**，逐条给三个值与三个两两差值。
- 汇总：三途径各一行 p50／p95／max／成功率，资源枚举耗时一行，逐类样本数一行，不一致资产数一行，再加三行全库外推。

**计时口径（决策会话读数时必须知道）**：`PHAssetResource.assetResources(for:)` 的枚举耗时**单列为 `enum-ms`（冷）**，三条途径的计时都**不含**它，彼此才可比。途径 1、2 的计时沿用 IC-099b `AssetSizeProbeService` 的口径（它在自己内部另做一次枚举，那次是热的）；途径 3 的计时只围住 `responds(to:)` + `value(forKey:)`。

**分位数口径**：最近秩法（nearest-rank），升序后取第 `ceil(rank/100 × n)` 个、秩从 1 起、两端夹逼，**偶数长度不插值**。

**抽样口径**：三族（照片／实况／视频）各随机取至多 70 条后**轮转交错**，再截断到 200。三族满额是 210 > 200，直接拼接再截断会把最后一族削掉 10 条；轮转交错让削减均摊，实测满额时分布为 67／67／66。

### 子项 C `IC-145 C category-metadata probe`

- 头部 7 行：标题、`format-version`、两条分档口径、`predicate-note`、`resource-note`、`library-asset-count=N|pass1=…ms`。
- 分布 4 行 + 已编辑 1 行 + 可行性 1 行，共 13 行。
- 可行性行：`feasibility|metadata-per-asset=…us|metadata-pass-total=…ms|byte-route-data-p50=…|ratio-byte-route-over-metadata=…x`。**只给数与比值，不下结论**（卡内明令）。`byte-route-data-p50` 取的是**子项 B 本次会话运行**的途径 1 p50；子项 B 未跑过即写 `none`，**不拿旧数凑**。

因此 **H68 的运行顺序有讲究**：先跑子项 B、再跑子项 C，子项 C 的比值才有值。先跑 C 不会报错，只是比值列为 `none`。

---

## 八、途径 3 的键探测结果与私有 API 标注

| 项 | 内容 |
|---|---|
| 候选键名 | `fileSize` |
| 取值方式 | 先 `resource.responds(to: NSSelectorFromString("fileSize"))` 探测，**存在才** `resource.value(forKey:)`。未知键的 KVC 会抛 `NSUnknownKeyException`，Swift 接不住，故不能省探测这一步 |
| 是否公开 API | **否**。`PHAssetResource` 的公开接口里没有字节数属性；报告 `public-interface=no`，头部另有 `route-prop=PHAssetResource runtime property read, PROBE ONLY, NOT PUBLIC API, MUST NOT SHIP` |
| 正对照键 | `originalFilename`（公开属性，`public-interface=yes`）。用来验证探测方法本身有效——否则候选键探测为假时分不清是「键不存在」还是「`responds(to:)` 这条路不灵」 |
| `responds` 实测值 | **未实测**。本卡不测 PhotoKit 取数（卡内明令），模拟器上也没有真实照片库。该列的真值由 Lynn 跑 H68 第 3 项后从报告里读出 |
| 隔离实证 | 断言 5：带引号键名字面量与 `value(forKey:` 在 `Services/AssetSizeScanner.swift`、`Features/**`、`App/**` 的命中数为 **0**；探针文件内 ≥ 1 |
| 处置 | **不得接进任何产品路径。** 是否采用由决策会话裁定，执行端不代为判断 |

---

## 九、发现但未处理的问题（按纪律只报告不修）

### 1.（④ 需决策）卡内子项 C 字段表把 `canPerform(.content)` 当「已编辑判定」，语义不符

- **事实（①）**：`PHAsset.canPerform(_:)` 回答的是「这个资产**能不能**执行该编辑操作」，即**可编辑性**；它不回答「这个资产**是否已经**被编辑过」。真正的已编辑判定是看 `PHAssetResource.assetResources(for:)` 里有没有 `type == .adjustmentData` 的资源——`AssetVolumeService`（`AssetSizeScanner.swift:360`）与 `AssetSizeProbeService`（同文件 112 行）都是这么判的，仓内已有先例。
- **③ 推测**：`canPerform(.content)` 在绝大多数资产上都为真，拿它当「已编辑数」会给出一个接近全库总数的数字，对类别页的容量估算是误导。**验证办法**：看 H68 第 4 项回传报告里 `editable=` 与 `edited-adjustmentData=` 两个数的差距。
- **本卡处置**：按卡内括号里的「**或等价的已编辑判定**」，做成两遍——第一遍纯元数据（含 `canPerform(.content)`，记为 `editable`），第二遍单独枚举 `adjustmentData`（记为 `edited-adjustmentData`），**分开计时、报告分列**，头部 `predicate-note` 写明两者是不同判据。第一遍的「纯元数据遍历耗时」因此没有被资源枚举污染，仍是卡内要的那个读数。
- **未处理的部分**：卡内字段表的措辞本身没改（不在授权范围），规格侧是否要区分这两个判据也未动。

### 2.（①）探针报告文本被迫全用 ASCII，与 IC-099b 探针的中文报告不一致

- `Scripts/scan-hardcoded-user-visible-strings.ps1` 把产品源码（`App`／`Core`／`Services`／`Features`）里**任何含汉字的字符串字面量**判为「用户可见硬编码残留」。
- IC-099b 的 `S2AssetSizeProbeText` 能用中文，是因为扫描器有一处**只对 `Features/S2/S2NativePhotoPager.swift`** 生效的豁免：`$inGeometryDiagnosticProtocol` 在匹配到 `^final class S2GeometryDiagnosticsRun`（该文件第 4241 行）后置真且**在该文件内再不复位**，于是这一行之后的所有字面量（包括第 5934 行起的 `S2AssetSizeProbeText`）都被归入「几何诊断导出协议字段」而免检。
- 新建的 `Services/ScanServiceProbe.swift` 拿不到那份豁免，故本卡报告文本一律 ASCII，中文只留在注释里。**这不影响可读性判断，但决策会话读 Lynn 回传的三份报告时会看到英文字段名**，与 IC-099b 报告风格不同。
- **未处理**：扫描器的豁免机制（一个按文件名硬编码、且不复位的开关）是否该改成显式标记，超出本卡授权（`Scripts/` 不在白名单）。

### 3.（①）第 4 个提交是计划外的，提交 1 单独 cherry-pick 不能编译

- 提交 1 把 `ProbeFormat.none` 改名为 `absentText` 时漏了 `optionalCount` 里的 `?? none`。`none` 不带前导点不会解析成 `Optional.none`，`ProbeFormat` 也已无同名成员 → `cannot find 'none' in scope`。
- 发现时提交 1～3 已落地。CLAUDE.md 第三节禁止 `amend` / `rebase` / 改写历史，故另起提交 4 修正，**不回填**。
- **后果**：卡内「每个 commit 须可单独 cherry-pick」在提交 1 上不成立，须连提交 4 一起取。提交 3 另含一处跨子项的无输出变化重构（把 A、B 的长串 `+` 拼接改成数组 `joined`，防 Swift 表达式类型检查超时），同样因禁止 amend 落在提交 3。
- **根因（①）**：本机无 Xcode，编译错误只能靠静态复核发现；这次是逐个对账 `ProbeFormat` 成员引用时抓到的，不是工具抓到的。

### 4.（②）子项 A 与 B 的取数实现为保持无状态，每条资产多一次 `fetchAssets(withLocalIdentifiers:)`

- 两个 Service 都不持有跨调用的可变状态，`measure(assetID:)` 按标识重新取回资产。代价是每条多一次取回。
- 对子项 A 无影响（不是耗时基准）。对子项 B 也不影响**途径读数**（三条途径的计时各自只围住取数调用本身，取回开销在计时区外），但会让**整轮探针的墙钟时间**比理论值长。
- **未处理**：没做批量预取。若 H68 反馈子项 B 跑得过久，可在实装卡里改。

### 5.（③）子项 C 第二遍在超大库上可能较慢，且只有两段式进度

- 第二遍逐个 `assetResources(for:)`，对上万条的库可能要几十秒；进度只报「phase 2/2」，不报条数。
- **验证办法**：H68 第 5 项若报告「跑类别元数据探针时界面长时间无反馈」，即此处。
- **未处理**：没做分批进度回报（会把协议从两方法拆成分页取数，超出探针该有的复杂度）。

### 6.（①）`S2View` 的标定面板 `VStack` 直接子视图已相当多

- 本卡又加了 3 个。iOS 17+ / Swift 5.9 的 `ViewBuilder` 走参数包、无 10 个上限，故编译与 CI 均无问题（#288 绿即实证）。
- **风险仅在编译时长**：面板本身类型检查负担随之增长。本卡已把三个新段各自抽成独立 `@ViewBuilder` 计算属性（照 P2 样板），面板体只多 3 行标识符引用。
- **未处理**：面板整体未做拆分。

---

## 十、人工判定项（H68）——原样列出，执行端不代为下结论

以下五条**留给 Lynn 在真机上跑**。执行端无真机、模拟器无真实照片库，**不对其中任何一条给结论**。

> 1. 长按顶部中胶囊 0.8 s 开面板，三个新段都在，按钮可点、进度可见、报告可复制。
> 2. 跑「屏幕录制识别探针」，把报告复制回来。**并人工核对**：明细里被判为录屏的，有几个其实不是；你记得的录屏里，有几个没被认出来。
> 3. 跑「字节取数基准探针」，把报告复制回来。
> 4. 跑「类别元数据探针」，把报告复制回来。
> 5. 三个探针跑完后，应用无卡死、无崩溃、内存无明显上涨；退出面板后再进 S2 逐张翻页行为与 IC-144 后一致。

**执行端补充的两条操作提示（不是判定项）：**

- 三个新段在面板里的位置：既有「双击丝滑度探针（IC-108）」段**之后**，「恢复出厂值」按钮**之前**，顺序为 屏幕录制识别 → 字节取数途径基准 → 类别元数据。
- **第 4 项请排在第 3 项之后跑**：类别元数据报告的可行性行要拿字节取数探针本次运行的 p50 做比值；若先跑第 4 项，该列会写 `none`（如实标注，不是错误）。

---

## 十点五、报告提交方式（CLAUDE.md 第二节纪律 7）

本报告引用的 CI 运行编号 #288、被测提交 SHA、IPA 字节数与 SHA-256 都是**推送之后**才产生的信息，故采用纪律 7 允许的第二种方式：**在同一张卡、同一分支内追加一个 docs 提交**承载两份报告，不等下一张卡分叉后回填。

该 docs 提交只动 `Reports/IC-145/**`，落在 `ci.yml` 的 `paths-ignore`（`Reports/**`、`**.md`）内，**不触发 CI，这是预期行为**——报告不需要验证自身所在的提交，只需准确指向验证产品代码的那次运行（#288，被测提交 `46085bd0af21a1ae3ccf4ad63f25b0d310663663`）。

---

## 十一、40 位 SHA 存在性核验

报告内每个 40 位 SHA 均来自实读命令输出（`git rev-parse`／`git log --format=%H`／`actions/runs` 的 `head_sha`），无一位凭短前缀补全（陷阱 15）。报告写完后对全部 40 位 SHA 跑 `git cat-file -e <sha>^{commit}`，结果：

```
46085bd0af21a1ae3ccf4ad63f25b0d310663663  EXISTS(commit)
1e0f322f8b7d803fc42b526cad97d36df5d0c6ce  EXISTS(commit)
df95b7388c16256957ffdd2b8d17c83715103058  EXISTS(commit)
cebee9b5f195b75f85d963a7f6ca662dc3d897d2  EXISTS(commit)
98e76c90e42d52817e1f59f818412a5f0688127b  EXISTS(commit)
ff7885b6fe5c381395d79217c29243b8e8ac8bf9  EXISTS(commit)
```

**6 个全部存在，0 个缺失。** 另有两个非 commit 的 64 位哈希（IPA SHA-256、`AssetSizeScanner.swift` 各符号块 SHA-256）不是 git 对象，不适用该核验，其来源分别为 CI 的 `notice` 注解与本机 `git show main:<path>` / `git show HEAD:<path>` 的逐符号哈希比对。

---

## 十二、本卡不产生可合并成果

- 分支 `probe/ic-145-scan-service` **不合并进 `main`**，与 `probe/ic-137-media-playback` 同例。本卡无 G8xx 合并闸门。
- 报告的价值是给决策会话写**批次 5.1 实装卡**提供实测数据。**本报告不替决策会话下「该用哪条途径」的结论**，只给数与观察到的事实；真机数待 H68 回传。
