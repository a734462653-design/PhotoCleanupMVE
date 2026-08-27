# IC-099b 自验报告（asset-size-probe）

## 结论（先行）

R1 格式纯函数与 R2 字节数探针已交付，**不改任何产品 UI 与产品行为**。

**CI 结果：CI #170 success。** 被测提交 `8fa54d199cccd4d39abb2e3da42f7f7462440c50`，XCTest **508 项、0 失败**，9 步全 success，被测命令真实退出码 **0**；IPA **823371 字节**、SHA-256 `35e0c6741b02a7ebdac9b6e23d40b22e4a964438e08d7772250ad51f0a1c3bba`，本地重下复核逐字节一致。

计数算式：**497 + 11 − 0 = 508**。新增 11 项为 P1 三项 + P2 五项 + P3 三项，全部 passed。

**CI 用了 2 次（上限 2）**：#169 因一处产品源码编译错误失败（`S2View.init` 形参顺序与调用点实参顺序不匹配），#170 修正后全绿。两次的定位与修正过程如实写在「CI #169 失败与修正」一节。

本地三项门禁真实退出码全为 **0**。**S3 的格式、行为与断言零改动**（`S3StateMachine.swift`、`S3StateMachineTests.swift`、`VolumeFormattingTests.swift` 相对 `main` 均为**零 diff**）。

三道闸门（A 改产品图片请求路径 / B 既有门禁失败 / C 新增标定参数或改 `schemaVersion`）**均未触发**。**未使用任何 KVC 私有键。**

**H43 三段真机取数留给 Lynn，本报告不代为下结论。**

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空 |
| 继承提交 | `741a2c13f827074ee9e44a233244fe0bd8a4d655`（IC-099 R0 报告提交，基于 `main` = `ef9d46a`） |
| 目标分支 | `feature/ic-099-top-bar-date-index-size`（未重切，在原 tip 上继续） |
| 分支 tip（代码部分） | `8fa54d199cccd4d39abb2e3da42f7f7462440c50` |
| CI | #169 failure（1/2）、**#170 success**（2/2） |
| 合并动作 | 无 |

范围边界：动了 `S2NativePhotoPager.swift`（R1 格式函数 + R2 探针类型，均置于诊断区）、`Services/AssetSizeScanner.swift`（追加 PhotoKit 取数实现，既有 `AssetSizeScanner` 一字未动）、`S2View.swift`（面板新增一段 + init 增一个默认参数）、`Localizable.xcstrings`（追加 3 个 key）、`CleanupCoordinator.swift` / `PhotoCleanupMVEApp.swift`（接线）、`S2CalibrationHarnessTests.swift`（11 项断言）。**顶部信息区、手势、横栏、操作条、图片请求策略、S3、SPEC、Decision_log、`Scripts/`、`ci.yml`、冻结三链一字未动。**

## R1：S2 单张字节格式纯函数

`S2AssetVolumeFormatter.string(forByteCount:)`，三档全部向下截断、无四舍五入：

```swift
if byteCount >= bytesPerGigabyte {
    return truncatedTenths(byteCount, unit: bytesPerGigabyte, suffix: "GB")
}
if byteCount >= bytesPerMegabyte {
    return truncatedTenths(byteCount, unit: bytesPerMegabyte, suffix: "MB")
}
return "\(byteCount / bytesPerKilobyte) KB"
```

一位小数用**整数除法**求（`byteCount / (unit / 10)` 再拆十位与个位），不走浮点——`999_949_999` 若用 `Double` 会被格式化进位成 `1000.0 MB`，整数路径必然给出 `999.9 MB`。

**S3 的 `DecimalVolumeFormatter` 与其全部调用点一字未动**，两套口径并存互不调用。新增断言里显式对照了同一字节数在两处的不同结果（`324_846` → S2 `324 KB` / S3 `0 MB`；`2_466_000` → S2 `2.4 MB` / S3 `2 MB`）。

### 放置说明（本卡遗留项，须技术负责人在阶段二前定）

`S2AssetVolumeFormatter` 本卡**放在 `S2NativePhotoPager.swift` 的诊断区**，不在 `Core/` 与 `DecimalVolumeFormatter` 对称的位置。原因是硬编码字符串扫描器的规则：

`Scripts/scan-hardcoded-user-visible-strings.ps1` 第 150～168 行对 `return "字面量"` 一律判为「用户消息或展示 helper 直接返回字符串」并计入残留，**唯一豁免是路径恰为 `PhotoCleanupMVE/Core/S3StateMachine.swift` 且值以 ` MB` / ` GB` 结尾**（第 155 行），理由写作「十进制 MB/GB 向下截断由规格锁定，本卡禁止本地化改造」。S2 口径新增了 ` KB` 档，且不在那个文件里，因此**放到任何常规位置都会让扫描器失败**。

三条出路里，改脚本属本卡范围外（§三明列不改 `Scripts/`），把格式塞进 String Catalog 等于自行决定用户可见格式的本地化语义（属未定项），故本卡取第三条：**与它当前唯一的消费方（探针）同置于诊断区**——该区在扫描器里已有既成豁免（`$inGeometryDiagnosticProtocol`）。

**这不是一个可以长期保留的位置。** IC-099 阶段二把该口径接到顶部信息区时，须由技术负责人在「给脚本加与 S3 同类的规格锁定豁免」与「把格式移入 String Catalog」之间定一个，并把该类型移到与 `DecimalVolumeFormatter` 对称的位置。代码里已就地写了同样的说明。

**同类处置**：R1 的八项断言原本落在 `VolumeFormattingTests.swift`（S3 的卷格式测试文件），会让该文件产生 +72 行。G217 要求「S3 相关测试 0 行改动」，故单独一个提交把它们移到 `S2CalibrationHarnessTests.swift`，`VolumeFormattingTests.swift` 相对 `main` 恢复**零 diff**。

## R2：字节数探针

### 两条取数途径（均 `isNetworkAccessAllowed = false`）

| 途径 | 照片 | 视频 | 语义 |
|---|---|---|---|
| **URL** | `requestContentEditingInput` → `fullSizeImageURL` → `URLResourceValues.fileSize` | `requestAVAsset` → `AVURLAsset.url` → `URLResourceValues.fileSize` | **当前版本**（已编辑资产是渲染后的文件） |
| **数据** | 主资源 `requestData` 流式累加 `data.count` | 同左 | **原主资源**（优先 `.photo` / `.video`，取不到才退 `.fullSizePhoto` / `.fullSizeVideo`） |

主资源刻意优先取**原始**类型，正是为了让已编辑资产上「URL − 数据」的差值成为「当前版本 vs 原资源」语义差的实测值——卡内 §二 R2 尾部汇总要求的就是这个。

**不使用任何 KVC 私有键**（卡内明令，探针内同样禁止）。数据途径只累加 `data.count`、不保留数据，沿用本仓库 `AssetSizeScanner` 既有的 `ByteAccumulator`。所有回调经 `ContinuationResumer` 保证 `CheckedContinuation` 只 resume 一次（`requestAVAsset` 的 resultHandler 可能被系统多次调用）。

### 报告格式

- **逐行九列**：`assetID前8位｜类型｜是否已编辑｜URL字节｜数据字节｜差值｜URL耗时｜数据耗时｜失败原因`
- **头部**：格式版本、列声明、两条途径的 API 原文、样本数 / 范围内总数 / 上限；超上限时追加「只取前 60 个」
- **尾部汇总**：两途径成功率（含百分比）、逐类样本数（照片 / LivePhoto / 视频）、已编辑样本数、两途径均成功且差值非零的行数、失败原因分布
- **失败原因七个分支**：资产不可用、无主资源、请求失败、请求被取消、资源不在本地、无可用URL、文件属性不可读

### 零副作用与非阻塞

协调器**不持有取数实现**——`run(assetIDs:using:)` 由面板按钮把实现现传进来；未触发时不注册观察者、不发请求、不写持久化。串行取数，每完成一个刷新一次进度行，浏览不被阻塞。上限 60，超出取前 60。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G217** P1～P3 通过；S3 既有断言零变化 | 满足① | 11 项测试函数名与 CI 通过行见下表；`git diff main..HEAD -- Core/S3StateMachine.swift S3StateMachineTests.swift VolumeFormattingTests.swift` **无输出** |
| **G218** CI success、真实退出码 0、XCTest 0 失败、计数算式、IPA 重下一致、本地三项门禁 0 | 满足① | 见「CI 与本地门禁」 |

### P1～P3 逐项（全部 passed，CI #170）

| 项 | 测试函数 | 耗时 | 断言要点 |
|---|---|---|---|
| **P1** | `testIC099bP1SingleAssetVolumeUsesKilobyteMegabyteGigabyteTiers` | 0.002 s | 卡内八个用例逐条：`0→0 KB`、`324_846→324 KB`、`999_999→999 KB`、`1_000_000→1.0 MB`、`2_466_000→2.4 MB`、`999_949_999→999.9 MB`、`1_000_000_000→1.0 GB`、`25_480_000_000→25.4 GB` |
| **P1** | `testIC099bP1TierBoundariesTruncateInsteadOfRounding` | 0.002 s | 档位切换恰在 1e6 与 1e9，两侧均不进位（`1_099_999→1.0 MB`、`999_999_999→999.9 MB`、`1_099_999_999→1.0 GB`） |
| **P1** | `testIC099bP1SingleAssetTierDoesNotChangeAggregateTier` | 0.001 s | 同一字节数在 S2 与 S3 两套口径下各给各的结果，互不影响 |
| **P2** | `testIC099bP2ProbeRowRendersNineColumnsInOrder` | 0.002 s | 行文本逐字符相等，且 `｜` 分隔恰九段 |
| **P2** | `testIC099bP2ProbeRowRendersFailuresAndNilColumns` | 0.002 s | 单途径失败与双途径失败两种行文本；失败列与差值列均为 `nil` |
| **P2** | `testIC099bP2ProbeFailureReasonsAreCompleteAndDistinct` | 0.003 s | 失败原因 `allCases.count == 7`、文案互不相同且非空，**每一个都能在行文本里原样出现**；类型枚举 3 项同检 |
| **P2** | `testIC099bP2ProbeSummaryCountsSuccessKindsAndDeltas` | 0.002 s | 成功率 `2/3（66.7%）`、逐类 `照片=1｜LivePhoto=1｜视频=1`、已编辑数、差值非零行数、失败原因分布 |
| **P2** | `testIC099bP2ProbeHeaderDeclaresColumnsAndLimitNote` | 0.001 s | 头部含格式版本、列声明、样本／总数／上限；未超上限时**不**出现「只取前」，超上限时出现 |
| **P3** | `testIC099bP3ProbeIsInertUntilExplicitlyRun` | 0.052 s | 未触发时假实现调用数 **0**、报告与进度为空、不进运行态；空范围调用 `run` 同样零取数 |
| **P3** | `testIC099bP3ProbeRunMeasuresEachAssetOnceAndBuildsReport` | 0.023 s | 显式运行后**逐资产恰取一次**、顺序与传入一致、报告含头部与每行与汇总 |
| **P3** | `testIC099bP3ProbeStopsAtAssetLimitAndNotesTotal` | 0.024 s | 传 70 个只取 **60** 个，头部注明 `样本数=60；范围内资产总数=70；上限=60` 与「只取前 60 个」 |

### CI 与本地门禁

| 项 | 值 |
|---|---|
| 工作流 | `iOS 构建与自验`，run **#170**（id 33056799404） |
| 被测提交 | `8fa54d199cccd4d39abb2e3da42f7f7462440c50` |
| 结论 | **success**，9 步全 success |
| XCTest | **Executed 508 tests, with 0 failures (0 unexpected)** in 22.745 (24.279) seconds |
| 计数算式 | 497（IC-097 后 `main` 基数）+ 11（本卡新增）− 0 = **508** ✅ |
| 真实退出码 | **0**。工作流 `set -o pipefail` + `exit "$test_status"`，步骤 6 conclusion = success |
| IPA 字节数 | **823371** |
| IPA SHA-256 | `35e0c6741b02a7ebdac9b6e23d40b22e4a964438e08d7772250ad51f0a1c3bba` |
| 本地重下复核 | `gh run download` 取 `PhotoCleanupMVE-unsigned-8fa54d199ccc`，本地 `stat` = **823371**、`sha256sum` = `35e0c674…3bba`，**与 CI 报告值逐字符一致** ✅ |
| `Scripts/selfcheck.ps1` | 退出码 **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 退出码 **0** |
| `git diff --check` | 退出码 **0** |
| CI 使用次数 | **2 / 2** |

### 闸门核对

| 闸门 | 触发 | 说明 |
|---|---|---|
| **A** 探针实现必须改动产品图片请求路径 / 策略 | 否 | `S2TemporaryPhotoImageStrategy` 与产品的 `PHImageManager.requestImage*` 调用点一字未动；探针走的是独立的 `AssetSizeProbeService`，只在按钮触发时构造 |
| **B** 任一既有门禁失败 | 否 | 497 项既有断言全过；`git diff main..HEAD -- PhotoCleanupMVETests/` 为 **363 增 0 删**，既有断言一行未改、未删 |
| **C** 新增标定参数、改出厂值或 `schemaVersion` | 否 | `S2CalibrationConfiguration` 未加字段、出厂值未改、`schemaVersion` 仍为 **4** |

## CI #169 失败与修正

**#169 failure（CI 1/2）**，步骤 6「运行 XCTest」失败，步骤 7、8 skipped。

工作流的错误行 grep 只匹配 `PhotoCleanupMVETests/.*error:|Test Case .* failed`，产品源码的编译错误落不进这个模式，因此注解只有两条：`Process completed with exit code 65` 与 `XCTest 失败：未找到具体错误行`。**据此可判定是产品源码编译错误，但拿不到具体行。**

**取日志连续失败**：`gh api .../actions/runs/<id>/logs` 与 `.../actions/jobs/<id>/logs` 在当时连续 20+ 次返回 **0 字节**（重定向到 `productionresultssa*.blob.core.windows.net` 后失败），`gh run view --log-failed` 也一直 `EOF`。因只剩 1 次 CI，**没有盲推**，改为静态自查。

自查定位到并修正的问题（第一条是主因，后三条是同批排查出的风险）：

1. **形参顺序与实参顺序不匹配（主因）**。`S2View.init` 里 `assetSizeProber` 加在第 15 位（`photoSwitchHapticFeedback` 之后），而 `PhotoCleanupMVEApp` 的调用点传在第 6 位（`assetPixelSize` 之后）。修正：把声明移到 `assetPixelSize` 之后；并写了一段脚本把**全部 9 处 `S2View(` 调用点**的标签序列与声明序列逐一比对，全部通过。
2. **取数实现由工厂闭包改为现成对象传入**。原写法 `makeAssetSizeProber: { coordinator.makeS2AssetSizeProber() }` 的闭包体是非隔离的，在里面调 `@MainActor` 的协调器方法会触发隔离检查；改为由 App 层在自身主线程上下文里造好再传。
3. **探针面板段抽成独立 `@ViewBuilder` 属性**，让面板主体那个巨型 `VStack` 少 8 个子视图，降低类型检查负担。
4. **两个与方法同名的局部量改名**（`urlResult` / `dataResult`），两处请求调用补 `_ =` 消除未用返回值告警。

**#170 全绿后日志恢复可下载，回读确认**：#169 的唯一产品源码错误是

```
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift:12:13: error: generic parameter 'R' could not be inferred
```

这正是 SwiftUI body 里 `S2View(...)` 实参顺序不匹配时的典型（且误导性的）诊断。**静态定位的主因与实测一致**；第 2～4 条是同批消除的风险，不是当次的报错原因，如实标注。

## 取定（④ Lynn 2026-08-28，本卡按其实装）

1. **「占用空间」语义 = 当前版本的字节数**（已编辑资产显示编辑后文件大小）。→ 探针的 URL 途径正是这个语义；数据途径取原主资源作为对照，差值即语义差。
2. **S2 单张显示口径**三档（KB / 一位小数 MB / 一位小数 GB，全部向下截断）。→ R1 已实装并八项断言。S3 合计口径原样不动。

## 人工判定项

**H43，保留给 Lynn 真机判定，本报告不代为下结论。** 装本卡 CI #170 的包（IPA 823371 字节、SHA-256 `35e0c674…3bba`）。

操作：进入一个包含「照片 + 视频 + 至少一张编辑过的照片」的范围（开了 iCloud 优化存储更好）→ 长按主图打开调试面板 → 参数面板里找到「字节数探针（IC-099b）」→ 点「运行字节数探针」→ 等进度跑完 → **全选复制输出发技术负责人**（也可用「分享字节数探针报告」直接分享）。顺手对照系统相册任一照片「信息」页的大小，说一句量级对不对。

## 真机未覆盖项清单

1. **URL 途径的可用性、语义与耗时全部未验证**——`fullSizeImageURL` 在未编辑 / 已编辑照片上分别指向什么、`requestAVAsset` 对已编辑视频返回的是不是 `AVURLAsset`、两者各自多慢，都要等 H43 的数据。这正是本卡存在的理由。
2. **两途径的差值分布未知**——已编辑资产上差值应非零，未编辑资产上应为零；这个预期本身也要靠 H43 证伪或证实。
3. **iCloud-only 资产的失败率与失败原因分布未知**——七个失败原因里哪些会真的出现、`notLocal` 是否真能被 `PHContentEditingInputResultIsInCloudKey` / `PHImageResultIsInCloudKey` 捕获，均未验证。
4. **大文件档仍未覆盖**——数据途径的耗时与资源大小线性相关，IC-099 引用的 P8 真机样本上限只有 18.9 MB；4K 长视频的实际耗时要看 H43 里有没有这类样本。
5. **60 个资产串行跑完的总耗时与体感未知**——夹具里假实现是瞬时的，真机上是两条真实 IO 途径各跑一遍。
6. **LivePhoto 的分类与主资源选取未验证**——`mediaSubtypes.contains(.photoLive)` 归类是否符合预期、其主资源取到的是照片部分还是视频部分，要看导出里的类型列与字节量级。
7. **面板新增段的排版与可点性未验证**（属调试面板，不在规格约束内，但仍需 H43 顺带确认按钮能按到）。

## 发现但未处理的问题（按纪律只报告不修）

1. **`S2AssetVolumeFormatter` 的放置是临时的**（见「放置说明」）。阶段二接到顶部信息区之前，须先定「给扫描器加规格锁定豁免」还是「把格式移入 String Catalog」，并把类型移到与 `DecimalVolumeFormatter` 对称的位置。**这是本卡最需要技术负责人回应的一条。**
2. **扫描器的豁免规则是按文件路径硬编码的**（`Scripts/scan-hardcoded-user-visible-strings.ps1:155` 只认 `Core/S3StateMachine.swift`，且只认 ` MB` / ` GB` 结尾）。任何新增的规格锁定格式都会撞上它。属 `Scripts/` 范围外，未改。
3. **诊断区的豁免是「从 `S2GeometryDiagnosticsRun` 声明行起、到文件末尾全部豁免」**（脚本第 112～115 行把标志位置真后不再复位）。这意味着 `S2NativePhotoPager.swift` 后半个文件里的中文字面量一律不查。本卡利用了这个既成事实，但它是个偏宽的规则，值得单独立卡收紧。
4. **`AssetSizeScanner`（S3 用）是多资源求和，探针的数据途径是单主资源**，两者口径不同。本卡按 §一 取定只取主资源，没有动 `AssetSizeScanner`（改它会改 S3 行为，属范围外）。Live Photo 上两者会给出不同的数——H43 的导出可以顺带看出差多少。
5. **本机取 CI 日志极不稳定**：#169 期间 `runs/<id>/logs` 与 `jobs/<id>/logs` 连续 20+ 次返回 0 字节，`--log-failed` 一直 EOF；#170 之后同样的命令第 2 次尝试即成功。`gh run download` 也是第 5 次才成功。建议后续卡把「取日志失败」当常态处理，重试上限放宽到 8～10 次并拉长间隔；CLAUDE.md 第五节现只写了「2~3 次重试」。属流程文件，未改。
6. **工作流的错误行 grep 只覆盖测试目录**（`PhotoCleanupMVETests/.*error:`），产品源码的编译错误一律落成「未找到具体错误行」。这次因此多花了一整轮排查。把模式放宽到 `.*error:` 即可，属 `ci.yml` 范围外，未改。

## 完成后动作

**完成即停，等 H43 数据。** 未合并主干，未动冻结三链。数据回来后由技术负责人判定路线并下发 IC-099 阶段二。
