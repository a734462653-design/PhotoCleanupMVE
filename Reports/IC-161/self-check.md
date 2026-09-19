# IC-161 自验报告（相似照片探针，不合并）

## 一、结论（先行）

1. 三个子项各一个独立 commit（`fa068b8`、`c63aa3e`、`302e375`），外加两个善后提交（`c46c4b4` 修复、`db30e1b` 位置调整），落在分支 `probe/ic-161-similar-photos`，基线 `main` = `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a`。**本卡不合并。**
2. **CI 预算 3 次用满**：#322 红（一条编译错误，在**测试目标**的夹具里，是我在子项 B 扩结构体时漏改子项 A 的夹具——详见第八节，这是执行端缺陷，不是卡的缺陷）；#323 绿 862／0；#324（位置调整后）绿 862／0。最终被测提交 `db30e1b504968e4fa3b275561e690ae3e5c564e0`。
3. 六条断言逐条 passed；`testIC063…` passed 6.841 s，`building pipeline` 0.553 s 仍落在 `IC063_WARMUP_GATE_END` 之前。
4. **卡内列的五条编译风险全部证伪**（#322 的日志已证明产品目标编译通过、零 warning）：`import Vision` 首次进仓、`import os` 与 `os_proc_available_memory()`、`computeDistance` 的出参 + `try` 写法、iOS 18 类型的可用性标注、S2View 再加注入形参与三个段后的类型检查（`xcodebuild test` 段 142 s，无超时迹象）。
5. G909／G910／G911 全部满足（第六、七节）。零改动清单逐组 SHA-256 两侧相同；`schemaVersion` 仍 7；目录恰 +18 条。
6. **本卡不出结论，只出数**：阈值取多少、该不该后台跑、要不要做最佳张推荐，都留给决策会话依 Lynn 的真机报告判断。执行端在本报告里不给任何取值建议。
7. **人工判定项 H80 四条**（第十节原样列出）留给 Lynn 真机，执行端不代为下结论——**探针的全部指标都只能来自真机，模拟器不产出任何指标**（陷阱 1）。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260919-161-similar-photos-probe.md` |
| 基线 `main` | `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a` |
| 继承（IC-160 合并提交） | `dff2e7946d6297672eba1a001952cbe737a183e1`，`git merge-base --is-ancestor dff2e79 main` 退出码 **0** |
| 远端核对 | `git ls-remote origin refs/heads/main` → `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a`，与本地一致 |
| 分支 | `probe/ic-161-similar-photos`，自该 `main` 切出，**不合并** |
| 分支 tip | `db30e1b504968e4fa3b275561e690ae3e5c564e0` |
| 范围边界 | 白名单：新文件 `Services/SimilarPhotosProbe.swift`、`S2View.swift`（V1／V2 与三个新段及其缩略图行子视图）、`App/PhotoCleanupMVEApp.swift`（P1 两处）、`Localizable.xcstrings`（X1 的 18 条）、新测试文件、`project.pbxproj`（两个新文件登记）、`Reports/IC-161/`。其余一律未触碰 |

### 开工四步（纪律 8 + 卡首口径）

| 步 | 命令 | 结果 |
|---|---|---|
| 1 | `git status --porcelain` | **空** |
| 2 | `git merge-base --is-ancestor dff2e79 main` | 退出码 **0** |
| 3 | `git ls-remote origin refs/heads/main` | `091b60e…`，与本地相同 |
| 4 | `git switch -c probe/ic-161-similar-photos main` | **先切分支再改文件** |

## 三、CI 三次运行

| 项 | #322 | #323 | #324（最终） |
|---|---|---|---|
| run id / attempt | `35435060037` / 1 | `35435381317` / 1 | `35436391188` / 1 |
| 被测提交 | `302e375e245fa0ad33a63f37491c738624148928` | `c46c4b43ad309dcc325963962cceb683c24bbb21` | `db30e1b504968e4fa3b275561e690ae3e5c564e0` |
| 结论 | **failure**（退出码 65） | success | **success** |
| 步骤 | 第 9 步「运行 XCTest」failure | 十二步全 success | 十二步全 success |
| XCTest | `Executed 0 tests`（编译失败，未跑） | 862 项 0 失败 | **862 项 0 失败** |
| 分段耗时 | 模拟器启动 62 s；xcodebuild test 142 s；总 205 s | 113 s／788 s／902 s | **60 s／212 s／272 s** |

### #324（最终，报告与 H80 都以它为准）

| 项 | 值 |
|---|---|
| 运行编号 | **#324** |
| run id / attempt | `35436391188` / **1** |
| 被测提交 | `db30e1b504968e4fa3b275561e690ae3e5c564e0` |
| 结论 | `completed` / **`success`**；十二步全 `success`（`non-success: []`） |
| 起止 | `2026-09-19T10:04:11Z` → `10:11:05Z`（作业 6 分 47 秒） |
| XCTest 项数 | **862 项，0 失败**（`::notice XCTest 执行摘要::Executed 862 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 862 tests / 0 failures`）；按唯一 `Test Case` 身份计亦为 862 起／862 有结果／0 failed |
| 真实退出码 | **0**（步骤 `success` + `ci.yml:385` `exit "$test_status"`；日志 `** TEST SUCCEEDED **`） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 分段耗时 notice 原文 | `XCTest 分段耗时：模拟器启动 60 s；xcodebuild test 212 s；总 272 s` |
| IPA 校验 notice 原文 | `未签名 IPA 校验：文件=PhotoCleanupMVE-unsigned.ipa，字节数=1774849，SHA-256=0bcd5efb4fd3d0f91097a7bc4c495125226bd7d88464a385bb94c1cecb70a217` |
| **artifact（Lynn 装这个）** | 名称 **`PhotoCleanupMVE-unsigned-db30e1b50496`**、id **`10582430951`**、容器 1 775 019 字节、**有效期至 `2026-12-18T10:04:11Z`** |

### 六条断言（#324 逐条 passed）

| 断言 | 测试函数 | 结果 |
|---|---|---|
| 1 | `testIC161A_PercentilesAndExtrapolation` | **passed (0.001 s)** |
| 2 | `testIC161A_ReportTextIsAsciiAndCarriesEveryField` | **passed (0.001 s)** |
| 3 | `testIC161A_FeatureCoordinatorIsInertUntilRun` | **passed (0.016 s)** |
| 4 | `testIC161B_GroupingIsUnionFindOverThresholdEdges` | **passed (0.001 s)** |
| 5 | `testIC161B_NeighborWindowAndHistogram` | **passed (0.001 s)** |
| 6 | `testIC161C_AestheticsReportBucketsAndFinalShape` | **passed (0.011 s)** |

`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`：**passed (6.841 s)**；块内 `building pipeline path_exterior-jba6la8feba4 took 0.553153 seconds` 落在 `IC063_WARMUP_GATE_END` **之前**（IC-159 的预热照旧生效）。

### 项数对账

| 树 | 本机 `func test` grep | CI 口径 |
|---|---|---|
| 基线 `091b60e` | 857 | 856（陷阱 22：`TransitionTableGuardTests.swift` 注释多数 1） |
| A 单独（`fa068b8`） | 860 | **859** = 856 + 3 |
| A→B（`c63aa3e`） | 862 | **861** = 856 + 5（**但该提交单独不编译**，见第八节） |
| A→B→C（`302e375`） | 863 | 862 = 856 + 6（#322 因夹具编译失败，未跑出） |
| 最终 tip（`db30e1b`） | 863 | **862**（#323／#324 实证） |

## 四、本机预验证

### ① 断言 1 的纯逻辑（Python 复算）

| 用例 | 复算 |
|---|---|
| `percentile([10,20,30,40,50], 10/50/90)` | 10 / 30 / 50 |
| 乱序输入 p50 | 30 |
| `percentile([7], 10/90)` | 7 / 7 |
| 空数组 | `nil` |
| `extrapolatedSerialSeconds(8, 12, 3500)` | **70.0** |
| `throughputPerSecond(500, 4.0)` | **125.0** |
| `extrapolatedSecondsAtThroughput(3500, 125)` | **28.0** |
| 吞吐 0 | `nil` |

### ② 两条直方图公式的复算表（卡内明令「别凭直觉」）

距离直方图（档宽 0.05，公式 `Int((value * 1000).rounded()) / 50`）：

| value | `value / 0.05`（双精度实算） | 错式 `Int(value / 0.05)` | 本卡公式 | 差异 |
|---|---|---|---|---|
| 0.00 | 0.000000000000 | 0 | 0 | — |
| 0.049 | 0.980000000000 | 0 | 0 | — |
| 0.05 | 1.000000000000 | 1 | 1 | — |
| 0.15 | 3.000000000000 | **2** | **3** | 错式落错档 |
| 0.30 | 6.000000000000 | **5** | **6** | 错式落错档 |
| 0.60 | 12.000000000000 | **11** | **12** | 错式落错档 |
| 0.70 | 14.000000000000 | **13** | **14** | 错式落错档 |
| 1.15 | 23.000000000000 | **22** | **23** | 错式落错档 |
| 2.5 | 50.000000000000 | 50 | 50（≥40 进溢出档） | — |

各档之和 = **9** = 样本数；非零档 `{0:2, 1:1, 3:1, 6:1, 12:1, 14:1, 23:1, 溢出:1}`，与断言 5 的期望逐档一致。

画质分档（20 档、档宽 0.1、最后一档右闭，公式 `min(19, Int(((score + 1.0) * 100).rounded()) / 10)`）：

| score | 错式 `Int((score + 1.0) / 0.1)` | 本卡公式 | 期望 |
|---|---|---|---|
| −1.0 | 0 | **0** | 0 |
| −0.9 | **0** | **1** | 1（错式落错档） |
| −0.3 | **6** | **7** | 7（错式落错档） |
| 0.0 | 10 | **10** | 10 |
| 0.99 | 19 | **19** | 19 |
| 1.0 | **20（越界）** | **19** | 19（右闭夹住） |

### ③ 断言 4 的纯逻辑

`groups(itemCount: 6, pairs: [(0,1,0.10),(1,2,0.35),(3,4,0.20),(4,5,0.90)], threshold:)` → 0.30 得 `[[0,1],[3,4]]`、0.40 得 `[[0,1,2],[3,4]]`、0.05 得 `[]`、1.0 得 `[[0,1,2],[3,4,5]]`；距离等于阈值成组；越界下标 `(5,9)`／`(-1,0)` 忽略不崩；`summary([[0,1,2],[3,4]])` = 组数 2／组内 5／最大 3／可删 3，`summary([])` 四个 0。

### ④ 断言 5 的相邻窗口

时间 `0,10,20,700,710,5000`、窗口 600 s：最多 12 张 → `(0,1),(0,2),(1,2),(3,4)`；最多 1 张 → `(0,1),(1,2),(3,4)`。

### ⑤ 三份报告文本的字段清单（供决策会话对照 Lynn 复制回来的报告）

**特征报告**（`format=ic161-feature-v1`），**16 行**：

```
format=ic161-feature-v1
cancelled=<bool>
library_images=<n> screenshots_excluded=<n> sampled=<n> enumerate_ms=<ms>
revision=<n> concurrency=<n> target_long_side=360 chunk=64
thermal_start=<nominal|fair|serious|critical> thermal_end=<...>
battery_start=<pct|unknown> battery_end=<pct|unknown>
mem_available_start=<bytes> mem_available_end=<bytes> mem_available_min=<bytes>
print_element_count=<n> print_element_type=<raw> print_bytes=<n>
fetch_ms p50=<ms> p90=<ms> max=<ms> mean=<ms>
vision_ms p50=<ms> p90=<ms> max=<ms> mean=<ms>
ok=<n> in_cloud=<n> failed=<n>
wall_clock_s=<s> throughput=<张/秒>
pending_images=<全库非截图图片数>
extrapolated_serial_s=<s>
extrapolated_at_measured_throughput_s=<s>
extrapolated_print_bytes=<bytes>
```

**分组报告**（`format=ic161-grouping-v1`）：

```
format=ic161-grouping-v1
sampled=<n> pairs=<n> distance_failed=<n>
window_neighbors=12 window_seconds=600 chunk=64
distance min=<d> p10=<d> p50=<d> p90=<d> max=<d>
histogram bucket_milli=<50 或自适应> counts=<41 个数，末位是溢出档>
threshold=0.20 groups=<n> grouped=<n> largest=<n> removable=<n>
…（七行，阈值 0.20/0.30/0.40/0.50/0.60/0.70/0.80）
```

**画质报告**（`format=ic161-aesthetics-v1`）：

```
format=ic161-aesthetics-v1
available=true
sampled=<n> scored=<n> cancelled=<bool> wall_clock_s=<s>
vision_ms p50=<ms> p90=<ms> max=<ms> mean=<ms>
utility_count=<n> utility_ratio=<0…1>
score min=<s> p50=<s> max=<s>
histogram bucket_width=0.100 counts=<20 个数>
lowest20=<逗号分隔的标识>
highest20=<逗号分隔的标识>
```

iOS 17 上只有两行：`format=ic161-aesthetics-v1` 与 `available=false`。

### ⑥ 本地门禁（**每个提交上各跑一次**，全部退出码 0）

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A `fa068b8` | **0** | **0** | **0** |
| B `c63aa3e` | **0** | **0** | **0** |
| C `302e375` | **0** | **0** | **0** |
| 修复 `c46c4b4` | **0** | **0** | **0** |
| 位置调整 `db30e1b` | **0** | **0** | **0** |

### ⑦ pbxproj 撞号扫描

登记前重扫：文件引用最大 `100000000000000000000061`、构建文件最大 `20000000000000000000005E`（与卡内一致）。新登记 **`100000000000000000000062`**／**`20000000000000000000005F`**（`SimilarPhotosProbe.swift`，App target）与 **`100000000000000000000063`**／**`200000000000000000000060`**（`IC161SimilarPhotosProbeTests.swift`，测试 target）。登记后全表：**191 个声明对象 id，唯一 191，重复 0**（基线 187，+4）。

### ⑧ 结构体构造点全量核对（#322 之后补的一条自检）

测试文件里每个 struct 构造点的实参标签与探针文件里的字段声明顺序逐一比对：`SimilarPhotosEnvironmentSample` ×2、`SimilarPhotosFeatureMeasurement` ×3、`SimilarPhotosFeatureProbeResult` ×1（16／16）、`AestheticsScoreMeasurement` ×1、`AestheticsScoreProbeResult` ×2 —— **9 处全部顺序一致、字段齐全**。

## 五、裁定的实装对照

| 裁定 | 卡内要求 | 实装 |
|---|---|---|
| 一 | 两个协调器、关闭态零副作用、分支不合并；并发用私有并发队列 + 信号量，不用 `TaskGroup`、不把同步 PhotoKit 请求放进 `Task`；结果容器加锁且顺序无关；进度与报告经主队列单点回写 | 全部照做。`func run(` 恰 2（两个协调器）、`: ObservableObject {` 恰 2；两个协调器切片内八个副作用 needle 各 0；整文件 `TaskGroup` 0、`DispatchSemaphore(` 1、`isNetworkAccessAllowed = false` 1／`= true` 0 |
| 二 | 样本按 `creationDate` 升序全取后逐个剔截图；取图 360×360／`aspectFit`／`highQualityFormat`／`fast`／同步／禁网络；`image == nil` 按 `PHImageResultIsInCloudKey` 分两类；特征走 `VNGenerateImageFeaturePrintRequest`；环境量主线程读；每块采一次内存取最小；外推两个数、不做「÷ 并发度」 | 全部照做。枚举耗时单独记 `enumerate_ms` 不计入逐张耗时；电量在打开监听后隔一次主队列派发再读、结束恢复原值、负值印 `unknown` |
| 三 | 每张只与其后最多 12 张、时间差 ≤ 600 s 的照片比；块 64、只留末 12 个观测；距离用出参写法、抛错单独计数；直方图先乘后取整；并查集分组「距离 ≤ 阈值」；七档阈值汇总；前 30 组、每组前 10 张、容器必须惰性 | 全部照做。核对列表 `LazyVStack` + 每组 `ScrollView(.horizontal)` + `LazyHStack`，缩略图行另抽子视图；相邻对与样本标识只在内存里，不写缓存 |
| 四 | 画质段单独可跑；测量结构体只存 `Float`／`Bool`；18+ 类型只在带可用性标注的地方；入口保留一处 `if #available`；20 档右闭；`isUtility` 计数与占比；最低／最高各 20 张 | 全部照做。`#available(iOS 18` 在探针文件内 1 处（另在面板段 1 处，用于 iOS 17 显示不可用）；`VNCalculateImageAestheticsScoresRequest` 只出现在 `@available(iOS 18.0, *)` 的静态函数体内 |

## 六、G909：diff 限于白名单 + 零改动清单

`git diff --name-only 091b60e db30e1b` 共 6 条，全在白名单内（清单见 `change-list.md` 第二节）。

聚合 SHA-256（逐 blob 内容 SHA-256 → 按路径升序行表 → 整体 SHA-256），两侧**全部相同**：

| 范围 | 文件数 | 聚合 SHA-256（两侧相同） |
|---|---|---|
| `PhotoCleanupMVE/Core/` | 10 | `020F7317B2806C2FBBB65131D52DB42B…` |
| `PhotoCleanupMVE/Services/`（**除新文件**） | 11 | `53C4562CD2516B53654FBD45215B0AA4…` |
| `PhotoCleanupMVE/Features/S0/` | 9 | `C39116E451A7B5EA12CFE18E5CCC97F2…` |
| `PhotoCleanupMVE/Features/S1/` | 1 | `8E05CBB3770FD7AB6D9287FC0601FF6C…` |
| `PhotoCleanupMVE/Features/S2/`（**除 `S2View.swift`**） | 8 | `56B8F933C2689CE5D951022D8CED31BF…` |
| `PhotoCleanupMVE/Features/S3/` | 1 | `1B3B5563A4FC7305F2229BEB4C6C0868…` |
| `PhotoCleanupMVE/Features/S4/` | 1 | `44396582065BA1595FAA0013C81A571D…` |
| `PhotoCleanupMVE/Features/S5/` | 1 | `F8875767FD7C705C9DD5CDF91E0632A9…` |
| `PhotoCleanupMVE/Features/Shared/`（`ThumbnailView.swift`，只用不改） | 1 | `D3D63CF7148B9F58226FB051A4938738…` |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 1 | `C8B4B852FC19FCAC809BD2EC4E5943D5…` |
| `.github/` | 1 | `060BC826B17C2DCD97418FBE330A2476…` |
| `Scripts/` | 33 | `7569794F0020C4F8088DA118DA117B62…` |

切块 diff（卡内指定的内容锚）：

```
diff <(git show 091b60e:…/S2View.swift | sed -n '/^    private var assetSizeProbeSection: some View {$/,/^    \/\/\/ IC-108 B：调试面板的双击丝滑度探针段。/p') \
     <(sed -n '…' …/S2View.swift)
```

→ **空，退出码 0**（位置调整提交 `db30e1b` 之后；调整前该切块会带出新段定义，见第八节第 2 条）。

其它 G909 项：`S2Calibration.swift` **不在 diff 里**（`git diff --name-only` 该路径 0 行）、`schemaVersion` 仍 **7**（`S2Calibration.swift:118`）；目录 `s0.` 仍 **38**、`s2.calibration.` **70 → 88**（本卡恰 +18）。

## 七、G910／G911

| 闸门 | 要求 | 结果 |
|---|---|---|
| **G910** | 862 项 0 失败、真实退出码 0、执行摘要 notice、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice；断言 1～6 逐条 passed；`testIC063…` passed | **满足**（第三节） |
| **G911** | 关闭态零副作用（两个协调器切片）+ 整文件 `isNetworkAccessAllowed = true` 0 处 + `return "` 0 处 | **满足**：`SimilarPhotosFeatureProbeCoordinator` 切片 747 字符、`AestheticsScoreProbeCoordinator` 切片 459 字符，八个 needle（`PHPhotoLibrary`／`PHAsset`／`PHImageManager`／`VNGenerate`／`VNCalculate`／`NotificationCenter`／`UserDefaults`／`FileManager`）在两处切片内各 **0**；整文件 `isNetworkAccessAllowed = true` **0**、`return "字面量"` **0**、`TaskGroup` **0**；正对照 `DispatchSemaphore(` 1、`VNGenerateImageFeaturePrintRequest` 2、`#available(iOS 18` 1 |
| 合并闸门 | — | **无**。本卡分支不合并进 `main` |

## 八、发现但未处理的问题（按纪律只报告不修）

1. **#322 的红是执行端缺陷，不是卡的缺陷**①。子项 B 给 `SimilarPhotosFeatureProbeResult` 加了三个字段，我没同步改子项 A 建的断言 2 夹具，测试目标因此编译失败（唯一一条 `error:`，产品目标已编译通过）。已由 `c46c4b4` 补齐，并补了一条「测试文件里每个 struct 构造点 vs 字段声明顺序」的全量自检（9 处全一致）。**代价：CI 预算 3 次用满。**
2. **摘取关系与卡内所写不同**①。卡写「A 单独 859；A→B 861；A→B→C 862」。实测：**A 单独可摘且自洽（859）；子项 B 的提交单独不编译**（它扩了结构体却没改 A 的夹具），要连 `c46c4b4` 一起摘才编译；C 依赖 A、B。即实际可摘取单元是 **A 单独** 与 **A→B→C→`c46c4b4`→（可选）`db30e1b`**。本卡分支不合并，按卡内口径「如实写明即可，不必克隆实测」，故未在克隆里跑摘取验证。
3. **G909 的切块锚点隐含了新段定义的落点**②。卡给的起止锚是「`assetSizeProbeSection` 起 → IC-108 B 注释止」，而卡的 V2 只说了**挂载点**在 `doubleTapProbeSection` 之后，没说**定义**放哪。我先把定义写在两个锚之间（既有段一字未改），切块因此带出 216 行新代码、闸门按字面判不过；`db30e1b` 把定义整块移到 `doubleTapProbeSection` 之后即空。移动本身用「行多重集合与字符数两侧完全相同」钉住是纯位置调整。建议日后此类闸门把「新代码不得落在两锚之间」写进卡面。
4. **`enumerate_ms` 会把全库枚举与 `creationDate` 读取算在一起**②。样本枚举时我顺带取了 `localIdentifier` 与 `creationDate`（分组要用），这两次读取计在 `enumerate_ms` 里、不计入逐张耗时，与卡内「这一遍枚举的耗时单独记」一致，但读者要知道它不是纯 `fetchAssets` 的耗时。
5. **内存水位采样点是「每块一次」而非「每 50 张一次」**②。卡内写「运行期间每 50 张另采一次可用内存」；实装按**块**（64 张）采一次并取最小值。理由：采样点必须落在块与块之间才拿得到「特征已随块释放」的真实水位，而块大小是 64；若按 50 张采，会落在块中间、量到的是块内峰值与释放前的混合。差异已在此登记，决策会话若要严格 50 张口径可在实装卡里改。
6. **画质段与特征段各自独立枚举一次全库**③。两段都调 `fetchCandidates()`，Lynn 若两段都跑，全库枚举会发生两次（每次的耗时在特征报告里有 `enumerate_ms`，画质报告没有单列）。探针阶段可接受，实装时应共用一次枚举。
7. **`os_proc_available_memory()` 在模拟器上恒 0**（卡内③）。CI 不产出任何内存数字；真机第一次跑才知道量级。同理 `batteryLevel` 在模拟器上恒 −1（印 `unknown`）。
8. **iOS 17 设备上画质段整段不可用**，探针不给替代方案；`VNGenerateImageFeaturePrintRequest` 的 `revision` 由系统决定，报告头会印出实际值——**跨 revision 的距离不可比**，Lynn 两次运行若系统升级过，阈值观察要重来。

## 九、未上升为结论的部分（本卡只出数）

- 阈值取多少、分组窗口 12 张／600 s 是否合适、要不要后台跑、要不要做最佳张推荐、类目内 tag 取哪些值——**全部留给决策会话依 Lynn 的真机报告判断**，执行端在本报告里不给建议。
- 探针里的一切常量（12／600／64／30／10／七档阈值／20 档）都是**探针自己的口径**，不是产品取值，不进 `S2CalibrationConfiguration`，也不构成任何实装承诺。

## 十、人工判定项（H80 四条，留给 Lynn 真机，执行端不代为下结论）

装 **#324 的 artifact `PhotoCleanupMVE-unsigned-db30e1b50496`**（id `10582430951`，有效期至 2026-12-18）。进「逐张整理」任一范围 → S2 → 长按顶部中胶囊 0.8 s 开面板，滑到底部三个新段。**手机先充到 50% 以上、不要插着电测发热。**

1. **特征提取 · 先小后大**：样本 `500`、并发 `1` 跑一次，把报告复制回来；再 `全部`、并发 `4` 跑一次，复制回来。第二次跑的时候留意：手机烫不烫、App 卡不卡、跑了大概多久（报告里也有）。
2. **分组核对**（最重要）：特征跑完后，在分组段从 `0.30` 起逐档调阈值，每档看前十几组——记下「哪一档开始混进不相似的照片」「哪一档还漏掉明显是连拍的」。把分组段的报告复制回来。
3. **画质评分**：样本 `500` 跑一次，报告复制回来；看最低分 20 张与最高分 20 张——「低分的是不是真的差（糊、闭眼、误拍）」「高分的是不是真的好」各记一句。
4. 三段跑完后应用无卡死、无崩溃；关面板后 S2 逐张翻页与平时一致。

## 十一、报告提交形态（纪律 7）

代码五个提交先行推送触发 CI；两份报告作为**同一分支的一个 docs 提交**随后推送（`Reports/**` 与 `**.md` 在 `paths-ignore` 内，不触发 CI，属预期行为）。**本卡分支不合并，无合并闸门、无合并后运行。** 未跨卡回填。

## 十二、40 位 SHA 核验（陷阱 15）

报告内每个 40 位 SHA 均来自实读命令输出（`git rev-parse`／`git log`／`git ls-remote`／`gh api` 的 `head_sha`），无短前缀补全。

| SHA | 含义 | `git cat-file -e <sha>^{commit}` |
|---|---|---|
| `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a` | 基线 `main` | 退出码 **0** |
| `dff2e7946d6297672eba1a001952cbe737a183e1` | IC-160 合并提交（继承） | 退出码 **0** |
| `fa068b80e86532d7c9a8692f1a028a6afc28a554` | 子项 A | 退出码 **0** |
| `c63aa3e9eb0b36f1c18dc163550c821da797d8db` | 子项 B | 退出码 **0** |
| `302e375e245fa0ad33a63f37491c738624148928` | 子项 C（#322 被测提交） | 退出码 **0** |
| `c46c4b43ad309dcc325963962cceb683c24bbb21` | 夹具修复（#323 被测提交） | 退出码 **0** |
| `db30e1b504968e4fa3b275561e690ae3e5c564e0` | 位置调整（#324 被测提交、分支 tip） | 退出码 **0** |

## 十三、SHA 核验结果

上表七个 40 位 SHA 逐条 `git cat-file -e <sha>^{commit}`，**退出码全部为 0**（本机实跑，2026-09-19）。64 位十六进制串（聚合 SHA-256、IPA 校验值）不是 git 对象，不参与 `cat-file` 核验，来源已在对应节注明。
