# IC-153 自验报告

## 一、结论（先行）

- **四个子项都已交付**，顺序 A → B → C → D，各自独立 commit：A `13af137`（规则登记表、分类、聚合）、B `cec92ce`（缓存与增量续扫引擎）、C `cf76fe9`（PhotoKit 源、协议实现、App 接线）、D `7c71862`（桩补钩子属性）；另有 B 的一个推 CI 前降险修正 `3e84b21`（两处 `Self.xxx` 改具名类型）。
- **CI #306（run id `35109386439`，attempt 1）一次绿**：十一步全 success、真实退出码 **0**、**824 项 0 失败、1 个 launch**、目的地 `OS:26.2, name:iPhone 16`、IPA **1618776 字节**、SHA-256 `dac6f9374755318facb3d3e7c787b81bcd7662434b827b14c978d9d67200d5b5`。项数对账 **811 + 13 = 824** ✔。CI 预算 3 次只用 1 次。
- **断言 1～13 全部 `passed`**（第五节逐条给函数名与耗时）；IC-147 的 16 项、IC-148 的 14 项、IC-151 的 8 项、IC-152 的 6 项逐条 `passed`。
- **G872～G874 满足，G875 满足**（第八节）。按卡内合并授权执行 `--no-ff` 合并；合并提交与 G876 由合并后的回填提交补记（第十一节）。
- **有六处按「结果」而非字面落实的地方（第 6.1～6.6 条，另有四条不改行为口径的实现取舍在第 6.7 条），都是卡内条文互相够不着或与规格结果冲突，请决策会话追认**。其中影响行为的只有一处：**回到扫描中的方向另需一个迁移事件**（第 6.2 条）——卡内裁定 五只点名 `.scanCompleted`／`.scanFailed`，照字面接线，前台恢复发现新增资产时 `SC` 不会回到扫描中（违 SPEC-S0 v2 第四节与 H75 第 5 条），授权刚通过时整个扫描期间停在失败页（违第三节第 4 部分迁出条件）。
- **人工判定项 H75 七条原样保留给 Lynn**（第十三节），执行端不代为下结论。**夹具源不是 PhotoKit**：首扫耗时、iCloud 未解析比例、录屏漏认率、前台恢复观感一律未覆盖（陷阱 1）。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260916-153-scan-service.md` |
| 规格 | SPEC-S0 v2（`SPEC-S0-20260916_v2.md`，本机 `sha256sum` = `8a8e222a…6f44`，与 CLAUDE.md 基线行一致） |
| 基线 `main` | `681cf0699163bfd84a042ea907988680be09a599` |
| 开工核对 1 | `git merge-base --is-ancestor 1e603d7 main` 退出码 **0** ✔ |
| 开工核对 2 | `git ls-remote origin refs/heads/main` = `681cf0699163bfd84a042ea907988680be09a599` = 本地 ✔ |
| 开工核对 3 | `git status --porcelain` **空** ✔（纪律 8） |
| 惯例 13／37 复核 | 卡内定位表逐项在 `681cf06` 上 grep：P1 `S0View.swift:10`、P3 `S0StateMachine.swift:55`、P4 `:65／:72／:84／:118／:176`、P5 `:333`、P6 `:471`、S1 `S0CleanupDataStub.swift:20`、S2 `AssetSizeScanner.swift:6-8／:27／:48`、S3 `PhotoLibraryService.swift:18／:48`、S4 `:112／:161／:202`、A1 `PhotoCleanupMVEApp.swift:15`、A2 `:59`、K1 `SessionPersistence.swift:308-344`、`S1StateMachine.swift:284`（`@Published private(set) var sessionStore`）与 `:375`、`SessionStore.swift:90`（`var allPendingDeletionAssetIDs: Set<AssetID>`）全部一致；P2（卡 `:606-621`，函数头实在 `:607`）、A3（卡 `:229-232`，实为 `:229-233`）、A4（卡 `:250-261`，文档注释 `:248-251`、函数 `:252-262`）差 1～2 行，不影响落点 |
| 分支 | `feature/ic-153-scan-service` |
| 分支 tip（代码） | `3e84b211e9db17656900c2b429e60643c28f8a4c` |
| 现状基数 | 811 项（CI #305）→ 本卡 **824** 项 |
| `schemaVersion` | **7，未动** |

范围边界：10 个路径全在白名单内；`Core/`、`Features/S1／S2／S3／S4／S5／Shared`、`Features/S0/` 其余四个文件、`Services/` 其余五个文件、`App/CleanupCoordinator.swift`、`.github/`、`Scripts/`、`Localizable.xcstrings`、`S2Calibration.swift` 各 **0** 命中。详见 `change-list.md` 第二节。

---

## 三、实现要点

### 3.1 子项 A：规则、分类、聚合（零 PhotoKit）

- 七个登记常量全在 `S0ScanRules`，分类与聚合文件剔注释后数值字面量只有 `0`、`1`。
- 录屏证据只对视频成立：本机截屏的像素恰好也是 1206×2622，照片若也算「分辨率命中」会把截图的证据写进缓存。
- 聚合：`c.count`／`c.bytes` 全量；`cleanable*` 按归属优先序去重；`LIB` 含 `D_全部` 内与不属任何类别的已解析资产；未解析一律不计；`categories` 恒三条、顺序 `bigVideo, screenRecording, screenshot`。

### 3.2 子项 B：缓存与引擎（零 PhotoKit）

一遍扫描六步（`S0LibraryScanService.runPass()`）：

1. 授权经 `S1AuthorizationDispatch.dispatch(for:)` 分派，非 `.proceed` 一律 `.failed(.authorization)`（含未决定：服务不弹系统授权窗）；
2. 本进程第一遍才读缓存文件；
3. 一遍元数据，抛错即 `.failed(.read)`；
4. 续扫判定：**新增与改动**回报 `.scanning`、计入进度；
5. 处理完回报 `.completed`；
6. **上次未解析的**静默重试：不回扫描中、不动进度，解出来的随快照更新（第 6.4 条）。

落盘：每处理 200 项一次，一遍结束、被取消各一次；写失败只累加 `persistenceFailureCount`，不中断、不改回报。并发 ≤ 4 的任务组取字节，按拍摄时间新→旧；被取消后在途结果一律丢弃。快照按「修订号 + `D_全部`」缓存，主线程读取只在两者之一变了时重算。

### 3.3 子项 C：PhotoKit 源、协议实现、接线

- `.production`：`PHAsset.fetchAssets(with: nil)` 一遍元数据（不设取数选项、不取任何相簿）；每资产**一次** `PHAssetResource.assetResources(for:)`，同时取视频 `.video` 资源的 `originalFilename` 与字节；字节走 `AssetSizeScanner.scan(resources:options:)`，选项 `isNetworkAccessAllowed = false` 在调用点上设。
- `onSnapshotDidChange`：后台修订号变了才发信号 → 主队列 → `S0SnapshotChangeThrottle`（相邻两次送达间隔 ≥ 250 ms，间隔从上一次回调返回后起算；间隔内的信号排到期满送出，**不丢**）。
- App 接线见第 6.1、6.2 条。

### 3.4 子项 D

桩加 `var onSnapshotDidChange: (() -> Void)?`，从不调用；IC-147 三条桩断言在 #306 `passed`。

---

## 四、CI 与项数对账

### 4.1 #306 的完整事实

| 项 | 值 |
|---|---|
| 运行编号 | **#306** |
| run id | `35109386439`，`run_attempt` **1** |
| check-run id | `104838817365`（从本次运行的 jobs 现取） |
| 被测提交 | `3e84b211e9db17656900c2b429e60643c28f8a4c`（分支 tip，含全部代码提交） |
| 结论 | **success**；11 个步骤全 success |
| 作业时长 | 14:34:04Z → 14:45:03Z（10 分 59 秒，`timeout-minutes: 15` 之内） |
| XCTest 步骤 | 14:35:09Z → 14:43:43Z（8 分 34 秒）；步骤以 `exit "$test_status"` 原样退出，结论 success ⟹ 真实退出码 **0** |
| 工具链 | `Xcode 26.3`，`Build version 17C529` |
| 执行摘要 notice | `Executed 824 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 824 tests / 0 failures` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1618776，SHA-256=dac6f9374755318facb3d3e7c787b81bcd7662434b827b14c978d9d67200d5b5` |
| artifact | `PhotoCleanupMVE-unsigned-3e84b211e9db`，id `10452430829`，zip 1618946 字节，2026-12-15 前有效 |

### 4.2 实证行（整包日志 zip，`unzip -tq` 校验通过后解析）

- 目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- `Executed 824 tests, with 0 failures (0 unexpected) in 39.464 (51.997) seconds`；`** TEST SUCCEEDED **`
- `Test Suite 'All tests' started` 出现 **1** 次（无宿主崩溃重启）
- 唯一 `Test Case … passed` **824**、`failed` **0**
- 日志内 `error:` 字样 1 行，是工作流脚本回显的 grep 模式串本身，不是编译或测试错误

### 4.3 项数对账

| 来源 | 项数 |
|---|---|
| `main` 基数（CI #305） | 811 |
| 本卡新增（`IC153ScanServiceTests`，13 个 `func test`） | +13 |
| 期望 | **824** |
| #306 唯一 passed 行 ∪ failed 行 | **824**（824 ／ 0） |

本机 `grep -c "^    func test" PhotoCleanupMVETests/IC153ScanServiceTests.swift` = 13（陷阱 22：本机 grep 只作差值预估，总数以 CI 为准）。

### 4.4 CI 预算

3 次预算用 **1** 次。推 CI 前的本机预验证见第七节；另请一个只看「会不会编译失败」的独立复核读了全部新代码，结论无阻断项，只标出一处「不确定、低风险」——便利构造器在委托 `self.init` 之前读 `Self.directoryName`，改成具名类型即提交 5（`3e84b21`）。

---

## 五、逐条验收门禁与测试函数名（#306，均 `passed`）

| 断言 | 子项 | 测试函数 | 耗时（s） | 钉住的结果 |
|---|---|---|---|---|
| 1 | A | `testIC153A_ClassifierHitsAndPriority` | 0.019 | 七种构造资产 + 小写前缀 + 门槛相等／差一字节，逐条命中集合与去重归属；录屏两条证据分开；照片不产生录屏证据；重复／相似不参与归属 |
| 2 | A | `testIC153A_AggregationDedupesHeroButNotCategories` | 0.002 | 录屏同计两个类别、hero 只计一次（153 MB vs 类别和 303 MB）；`LIB` 359 MB 含普通照片与 `D_全部`、账本内资产；待删篮 2 MB；未解析不进；排除集合清空后的正对照 |
| 3 | A | `testIC153A_RulesAreRegisteredNotBare` | 0.003 | 分类与聚合文件数值字面量 ⊆ {0, 1}；登记表恰 7 个 `static let`、每个有「出处：」；数字扫描器正对照；七个取值逐个钉住（含 `bigVideoMinimumByteCount == 100_000_000`） |
| 4 | B | `testIC153B_CacheRoundTripAndSchemaVersion` | 0.011 | 写入临时目录再读回逐字段相等（含小数秒日期、nil 日期、未解析条目）；文件内版本号 +1 读回空缓存；改回即可读的正对照；读不建目录 |
| 5 | B | `testIC153B_ResumeReusesUnchangedAndRefetchesChanged` | 0.001 | 未变／改动／新增 + 缓存有库内无 + 未解析，四个集合逐条相等；nil 修改时间两种情形；四集合不相交且覆盖全库；空缓存全新增 |
| 6 | B | `testIC153B_CancelMidwayThenResumeDoesNotRefetch` | 0.062 | 夹具源第 3 次之后挂起 → 停在已处理 3 项时取消 → 回报仍扫描中、落盘 3 条 → 放行再推进，取字节调用 = 10 − 3 且与已落盘集合不相交 → 快照（含 `LIB`）与不中断跑一遍相等 |
| 7 | B | `testIC153B_CompleteCacheWithoutChangesSkipsByteFetch` | 0.037 | 新实例读完整缓存、同元数据：取字节 0 次、枚举 1 次、`.completed`、快照与前一实例相等且等于缓存直接聚合；再推进一遍仍 0 次 |
| 8 | C | `testIC153C_ServiceOutcomeMapping` | 0.152 | 未推进回报扫描中；`.denied`／`.restricted`／`.notDetermined`／`.unknown` ⟹ `.failed(.authorization)`、不枚举不取字节；`.limited` ⟹ 扫描中且 `lim == true`、`.authorized` ⟹ 扫描中且 `lim == false`，放行后 `.completed`、识别阶段 `.counting` → `.settled`；枚举抛错 ⟹ `.failed(.read)`；授权变化后再推进即续扫 |
| 9 | C | `testIC153C_SnapshotCallbackIsThrottledButTerminalIsDelivered` | 1.732 | 节流间隔 = 250 000 000 ns；50 条资产每次取字节 20 ms：回调 ≥ 2 次、全在主线程、相邻两次间隔 ≥ 250 ms、最后一次回调时回报 `.completed` 且之后 0.6 s 无迟到回调；失败夹具最后一次为 `.failed(.read)` |
| 10 | C | `testIC153C_NoPhotoKitOnMainThreadAndIdleUntilAdvance` | 0.442 | 构造后不推进：夹具源零调用、缓存文件与目录都不存在、回调 0 次；推进（在飞时再推进一次无副作用）后授权 1、枚举 1、取字节 9、总调用 11、**主线程调用 0**；取字节顺序新→旧 |
| 11 | C | `testIC153C_AppWiringAndS0ViewUntouched` | 0.010 | 剔注释 App：`S0CleanupDataStub(` 0、`S0LibraryScanService(` ≥ 1、`advanceScan()` 恰 2、`allPendingDeletionAssetIDs` ≥ 1、`onSnapshotDidChange` 1、`S0ScanOutcomeTransition.events(` 1；剔注释 `S0View`：`machine.handle(` 4、`machine.ingest` 1、`onSnapshotDidChange` 恰 1（即协议声明）、`PHAsset` 0；迁移映射 4×4 组合喂真实状态机逐个落到对应 `SC`、一致时不给事件；失败→已完成重排恰 1 次 |
| 12 | C | `testIC153C_ProductionSourceFetchOptionsExcludeHiddenAndDeleted` | 0.026 | 剔注释服务文件：`includeHiddenAssets` 0（含 `= true`）、`smartAlbumAllHidden` 0、`smartAlbumRecentlyDeleted` 0、`fetchAssets(in:` 0、`fetchAssetCollections` 0、`isNetworkAccessAllowed = false` ≥ 1、`= true` 0、`value(forKey:` 0；正对照 `PHAsset.fetchAssets(with: nil)` 1、`PHAssetResource.assetResources(for:` 恰 1；六个新增／改动产品文件 `value(forKey:` 0、原文 `"fileSize"` 0；`AssetSizeScanner` 原入口仍在 |
| 13 | D | `testIC153D_StubConformsAndNeverFiresHook` | 0.265 | 五种剧本的桩经协议可见钩子、走完全程并多推一步计数恒 0；同一台连取相等、同参数两台逐字段相等（IC-147 断言 12 口径）；就绪剧本仍给五个类别 |

**既有相关用例（#306 逐条 `passed`）**：`IC147S0BehaviorTests` 16／16（含卡内 T1 点名的断言 9、12、13 与路由逐字相同的断言 3）、`IC148S0VisualTests` 14／14、`IC151AmbientFixedColorTests` 8／8（含卡内 T2 点名的 `testIC151D_S0BehaviorCallSitesUnchanged`）、`IC152DiagnosticPathTests` 6／6；另，源码扫描涉及本卡改动文件的 `IC134S3VisualTests` 14／14（`AssetSizeScanner.swift` 已删符号）、`IC139MediaBadgesTests` 12／12（App 入口已删符号）、`IC150ShareTests` 3／3。

---

## 六、按结果落实的地方与卡内缺口（逐条写明，请决策会话追认）

### 6.1 A3「同闸内加」与 IC-147 断言 3 的逐字钉冲突 → 在同一个 `.onAppear` 里另起一个同条件的 `if`

- ① `IC147S0BehaviorTests.swift:174-182` 对**原文**钉 `if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {` + 换行 + `coordinator.start()` + 换行 + `}` 恰 1 处。把 `advanceScan()` 塞进这个 `if`（前或后）都会打断该串；卡内 T1 又写该文件「不改」，陷阱 23 的提醒只点到「`.onAppear` 以外的路由行」，没点到 `.onAppear` 守卫本身也被钉住。
- 落实：原 `if` 一字不动，紧接其后另起 `if … == nil { s0DataProvider.advanceScan() }`，两个 `if` 读同一个环境变量、在同一次 `.onAppear` 里先后执行，E4 口径不变。#306 `testIC147AAssertion03RouteBranchesOtherThanS1AreByteIdentical` `passed`。

### 6.2 裁定 五／C3 只列 `.scanCompleted`／`.scanFailed` → 回到扫描中的方向补一个事件

- **卡内缺口（①）**：C2 要求源的每次调用都在非主线程（断言 10 钉住），所以 `advanceScan()` 只能**异步**发现新增或改动；A4 在 `advanceScan()` 之后**同步**读 `currentScanOutcome()`，读到的是上一遍的回报。于是「发现新增 → 回报 `.scanning`」（裁定 四）只能经 `onSnapshotDidChange` 到达，而回调里照字面只许发两种事件，都不能把 `SC` 从已完成或失败带回扫描中。
- **照字面接线的后果（③，逻辑推出；真机由 H75 第 1、5 条判）**：
  1. 就绪态拍一张新照片回到 App：服务扫到了、数字也更新了，但 `SC` 一直是已完成——不满足 SPEC-S0 v2 第三节第 2 部分「有新增资产时 `SC` 回到扫描中（迁至 S0-1）」、第四节「任一／前台恢复且有新增资产／S0-1」，也不满足卡内 H75 第 5 条「短暂回到扫描中」。
  2. 首次安装在系统授权窗里点「允许」：若首页先按上一遍的 `.failed(.authorization)` 落到 S0-4，之后整遍扫描（H68 外推约 18 秒）页面停在「需要照片访问权限」，直到 `.scanCompleted` 才离开——不满足第三节第 4 部分「授权变更后返回：迁至 S0-1」。
- **落实**：`S0ScanOutcomeTransition.events(for:scanState:failureCategory:)`（服务文件内的纯函数，App 回调逐个 `handle`）——回报扫描中而 `SC` 不是扫描中 ⟹ `.foregroundRestored(hasNewAssets: true)`（规格第四节那一行本身）；回报已完成而 `SC` 是失败 ⟹ 先 `.foregroundRestored(hasNewAssets: true)` 再 `.scanCompleted`，扫描完成那一次重排才会发生；其余与卡内两种事件相同；`SC` 已经一致则不给事件，扫描中每次进度不发迁移。断言 11 把 4×4 组合喂给真实状态机逐个钉住。
- **与卡内其余要求不冲突**：`restoreS0Foreground()` 照 A4 原样发 `.foregroundRestored(hasNewAssets: outcome == .scanning)`；重扫若没发现新增，回报保持已完成、修订号不变、**不发回调**，H75 第 5 条后半「直接就绪、无闪动」不受影响。
- **未取的另一种做法**：让 `advanceScan()` 同步先把回报置为扫描中，A4 那次同步读就能读到扫描中、不必补事件——但那样**每次**回前台（有无新增都一样）都会先迁到 S0-1、约 200 ms 后再回 S0-2，正好违 H75 第 5 条后半「直接就绪、无闪动」；拒绝授权的用户每次回前台还会 S0-4 → S0-1 → S0-4 闪一下。故回报保持「上一遍确定的结果」，直到新一遍确定为止。
- **这是本卡唯一一处改变了 App 层行为而卡内没写的地方**，若决策会话不接受，回退只需把 `events` 的两处 `.foregroundRestored(hasNewAssets: true)` 去掉（断言 11 同步改期望）。

### 6.3「完成与失败那一次不节流（必达）」与断言 9「任意 250 ms 窗口内 ≤ 1 次」字面冲突 → 推迟不丢

两句字面同时成立的唯一读法：终态信号**不被节流丢掉**，但仍守 250 ms 的最小间隔。节流器在间隔内收到的信号排到期满时送出，回调读的是送达那一刻的最新状态，所以最后一次回调必然看到终态；代价是终态最多晚 250 ms。断言 9 两部分（间隔 ≥ 250 ms、最后一次回调为终态）#306 均 `passed`。

### 6.4 未解析资产的重试不回报扫描中 → B2 的「需重取集合」拆成两个

- 裁定 四只让「新条目或改动条目」回报 `.scanning`；B2 又要求未解析条目「重取（下次机会）」。若重试也回扫描中，开了 iCloud 优化储存、本机有大量未下载原件的库，每次打开、每次回前台都会重新出现「正在扫描…」——H75 第 2 条「秒进就绪态」与第 5 条「直接就绪、无闪动」必不过（③）。
- 落实：`S0ScanResumePlan` 给四个互不相交的集合——复用、新增与改动（计入进度、回报扫描中）、未解析重试（在「已完成」之后静默跑，解出来的随快照更新）、丢弃。断言 5 的「四个集合」即此。

### 6.5 授权映射在 `.production` 里复写了一份

卡内写「由 `PhotoLibraryService.s1AuthorizationState()` 经 `S1AuthorizationDispatch.dispatch(for:)` 取」。①：`PhotoLibraryService` 整类 `@MainActor`（`PhotoLibraryService.swift:108`），`PHAuthorizationStatus → S1AuthorizationState` 的映射是 `private static`（`:244`），而 C2 与断言 10 要求源的每次调用都在非主线程，且卡内不许改 `PhotoLibraryService.swift`。故 `S0PhotoKitScanLibrary.authorizationState()` 按同一映射逐 case 复写（六个分支与原函数逐一对应），分派仍一律经 `S1AuthorizationDispatch.dispatch(for:)`。

### 6.6 摘取关系与卡内惯例 40 声明有一处出入；pbxproj 分提交登记

- 卡内写「A、B 各自可单独摘取」。①：B 用到白名单放在 A 文件里的 `S0ScanRules.cacheSchemaVersion`／`persistEveryAssets`、引擎聚合调 A 的 `S0ScanAggregator`、且往 A 新建的测试文件里追加断言——**B 不能脱离 A 单独摘取**。实际可摘取单元：A；A→B（→修正 5）；A→B→C→D。C 单独不能编译（协议属性在 C、桩属性按 D1 在 D），与卡内「C、D 只能作为连续序列摘取」一致。
- D3 写「pbxproj 登记四个新产品文件 + 一个测试文件」。照 IC-147／IC-151／IC-152 的既有做法，**每个新文件在引入它的那个提交里登记**（A 登三个、B 登两个），否则 A 摘出去也只是三个不进编译的文件；D 无新文件、未改 pbxproj。D3 要求的「重扫最大 id」与撞号扫描照做，见第九节。
- 与此相关：B 的引擎要跑断言 6、7 的闭包式夹具，**`S0LibraryScanSource` 结构体随 B 落地**（零 PhotoKit），`.production` 在 C。四个新产品文件与卡内一致，没有另拆文件。

### 6.7 其余几处实现取舍（不改行为口径，列出备查）

1. **缓存日期不照 `SessionPersistence` 用 iso8601**（K1 `SessionPersistence.swift:334-335`）：iso8601 只到整秒，带小数秒的 `modificationDate` 往返一次就不相等，每次启动都会被判为「已改动」而全量重取（③：真机修改时间带小数秒是常态，未在本卡实测）。改用 `JSONEncoder` 默认策略（浮点秒）；断言 4 以小数秒日期钉逐位往返（② #306 模拟器样本）。落点、`.atomic`、`NSLock` 照样板。
2. **`AssetSizeScanner` 新入口带调用方给的选项**：断言 12 要求 `isNetworkAccessAllowed = false` 出现在**服务文件**里，而现行私有 `bytes(of:)` 把选项建在 `AssetSizeScanner.swift` 内部。新增 `scan(resources:options:)` 与私有 `bytes(of:options:)`，途径与 `scan(_:)` 相同（逐资源 `requestData` 流式累加、任一资源取不到即不可得、溢出即不可得），完成回调另加一次性 resume 保护（照同文件探针的 `ContinuationResumer`）。纯追加在文件末尾，四块逐字节与 `main` 相同（第八节 G872）。
3. **卡外新增的内部 API**：`cancelScan()`（B4 可取消）、`isScanInFlight`（测试观察一遍是否结束）、`persistenceFailureCount`（B3「记一次错误」的承载）、`newestFirst(_:metadataByID:)`（C2 顺序的纯函数，断言 10 钉）。App 均不调用。
4. **断言 1 卡内写「五种构造资产」、括号里列了七种**：七种全测，另加门槛相等／差一字节与小写前缀三个边界。

---

## 七、Python 预验证比对清单（推 CI 前，本机）

`<scratchpad>/ic153_sim.py` 手工移植：分类、去重、聚合、续扫判定四个纯函数，一个顺序执行的引擎（并发 1），以及 `strippedSource`／`occurrences`／`numericLiterals` 三个扫描 helper。**移植与 Swift 实现的任何分歧都是移植偏差，下表是②样本观察，不构成测试会通过的证据；权威结论只取 CI #306。**

### 7.1 断言 1（夹具 → Python → Swift 期望 → #306）

| 夹具 | Python 命中／归属 | Swift 期望 | #306 |
|---|---|---|---|
| `plain-photo` 照片 4 MB | ∅／nil | ∅／nil | passed |
| `screenshot` 照片、截屏、1206×2622、2 MB | {screenshot}／screenshot | 同 | passed |
| `small-video` 1920×1080、`IMG_0001.MOV`、20 MB | ∅／nil | 同 | passed |
| `big-video` 3840×2160、`IMG_0002.MOV`、150 MB | {bigVideo}／bigVideo | 同 | passed |
| `prefix-recording` 886×1920、`ScreenRecording_10-13-2025 15-42-39_1.mp4`、120 MB | {bigVideo, screenRecording}／bigVideo | 同 | passed |
| `resolution-recording` 2622×1206、`IMG_0003.MP4`、30 MB | {screenRecording}／screenRecording | 同 | passed |
| `unresolved-video` 1206×2622、前缀命中、100 MB、未解析 | ∅／nil | 同 | passed |
| `lowercase-prefix` 886×1920、`screenrecording_…`、10 MB | ∅／nil | 同 | passed |
| `at-threshold` 100 000 000 字节 | {bigVideo}／bigVideo | 同 | passed |
| `below-threshold` 99 999 999 字节 | ∅／nil | 同 | passed |
| 证据：视频+前缀、视频+分辨率、照片+两者 | (真,假)、(假,真)、(假,假) | 同 | passed |
| 归属：三者、录屏+截图、空、重复+相似 | bigVideo、screenRecording、nil、nil | 同 | passed |

### 7.2 断言 2

| 量 | Python | Swift 期望 | #306 |
|---|---|---|---|
| 三类别（数／字节） | bigVideo 1／150 MB、screenRecording 1／150 MB、screenshot 1／3 MB | 同 | passed |
| 可清理（数／字节） | 2／153 MB | 同 | passed |
| 类别字节和 | 303 MB | 同 | passed |
| `LIB` | 359 MB | 同 | passed |
| 待删篮体积 | 2 MB | 同 | passed |
| 清空排除后：各类别数、可清理数／字节、`LIB`、待删篮 | [2, 1, 2]、4／355 MB、359 MB、0 | 同 | passed |

### 7.3 断言 5

| 集合 | Python | Swift 期望 | #306 |
|---|---|---|---|
| 复用 | {unchanged, no-date-both} | 同 | passed |
| 新增与改动 | {modified, new, date-appeared} | 同 | passed |
| 未解析重试 | {unresolved} | 同 | passed |
| 丢弃 | {gone} | 同 | passed |
| 覆盖全库、不相交；空缓存全新增 | 成立 | 同 | passed |

### 7.4 断言 6、7（顺序引擎，并发 1）

断言 6：取消后进度 (3, 10)、回报扫描中、落盘 3；续扫取字节 7 次且与已落盘不相交；与不中断跑一遍快照相等（`LIB` 424 MB）——与 Swift 期望一致，#306 passed。**并发 4 下「第 3 项之后挂起」时在途的是第 4～7 次调用，移植版只有第 4 次；两者被丢弃的结果都会在续扫里重取，「续扫调用 = 10 − 3」在两种并发下都成立，差异不影响期望值。**
断言 7：首遍 12 次、次遍 0 次、快照相等（三类别 3／3／3，`LIB` 447 MB）、第三遍仍 0 次——一致，#306 passed。

### 7.5 源码扫描口径（断言 3、11、12 + 既有扫描回归）

对分支 tip 的真实源码重算 117 项计数，0 处不符（7.1～7.4 的纯逻辑与顺序引擎另计 62 项，0 处不符）：断言 3（分类器字面量 {0, 1}、`S0ScanRules.` 3 处、登记表 7 个常量 7 处出处）、断言 11（App 六项、`S0View` 五项）、断言 12（服务文件十三项、六个文件的 `value(forKey:` 与 `"fileSize"`、`AssetSizeScanner` 两项），以及 IC-147 断言 3（四个路由分支、`.onAppear` 守卫原文恰 1）／7（四个文件三种直写 0）／9（三个文件五个 PhotoKit 符号 0、两条声明原文各 1）／10（禁用措辞 0）、IC-148 断言 3（`S0View`／`S0SegmentBar` 文件级字面量 ⊆ {0, 1, 2}）、IC-151 行为调用点（4／1／1）与 App 已删符号、IC-134 与 IC-139 的已删符号。needle 全部经 `Scripts/check-scan-needle-variant.ps1` 审计（第十节）。

---

## 八、闸门核对

### G872：diff 限于白名单 —— 满足

- 10 个路径全在白名单内；零改动目录与文件逐项 0（`change-list.md` 第二节）。
- `Core/` 四个文件两侧 SHA-256（`git show 681cf06:<f> | sha256sum` 与 `git show HEAD:<f> | sha256sum`）：

| 文件 | `main` | 分支 tip |
|---|---|---|
| `Core/S0StateMachine.swift` | `45cec85bca12aa271fc1ef6db200c212d89207e04c2e9e1ac906b065d1c0b374` | 同 ✔ |
| `Core/S1StateMachine.swift` | `b6c747919c10e91b6032b3d41556f9875f26a0fad9562b68fd53a91cec7e6cd3` | 同 ✔ |
| `Core/S2StateMachine.swift` | `90ddffad6ab737bbe00ea1c1cb1cb402503949c45cb5080e55b483a248dfe032` | 同 ✔ |
| `Core/SessionPersistence.swift` | `be8379a3542c9d8ea193ce3acacc50530fc6a61a60fe7664ddb6fd4dd1db9a83` | 同 ✔ |

- `S0View.swift` 的 diff 只有一个 hunk：`@@ -14,6 +14,9 @@ protocol S0CleanupDataProviding: AnyObject {`（协议加一个属性要求与两行文档注释）。
- `AssetSizeScanner.swift`：唯一 hunk `@@ -487,3 +487,60 @@ final class AssetVolumeService: S2AssetVolumeProviding {`，纯追加；`main` 版全文（16 894 字符）是改后文件的逐字节前缀。四块按声明头与收尾切片、两侧逐字节比对：

| 块 | 行数 | 两侧 SHA-256（前 16 位） | 逐字节相同 |
|---|---|---|---|
| `scan(_:)` | 19 | `9a69b56b4d38ce66` | ✔ |
| `ByteAccumulator` | 22 | `fcc44a169094cf4a` | ✔ |
| `AssetSizeProbeService` | 231 | `8ad1330553a8976c` | ✔ |
| `AssetVolumeService` | 145 | `a318268ee8e5ce17` | ✔ |

### G873：标定、冻结链、探针隔离 —— 满足

- `S2Calibration.swift` 不在 diff（两侧 SHA-256 均为 `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f`）；`static let schemaVersion = 7`（`:118`）✔
- 远端 tip（`git ls-remote origin`，直连）：

| 分支 | 期望 | 实读 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | `b368a6caee846e664391b0620350395bfe6fbc7f` ✔ |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` ✔ |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` ✔ |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | `9db02b93eccbb87d126602901807e70823535111` ✔ |
| `probe/ic-125-sentinel-negative` | `402cb6e` | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` ✔ |
| `probe/ic-137-media-playback` | `486bcb7` | `486bcb769b59eb1146c5a231c7998847206777cc` ✔ |
| `probe/ic-145-scan-service` | `d373afc` | `d373afc7125104c01acfc296829229090e6871ce` ✔ |

- 探针隔离：`git ls-files | grep -c ScanServiceProbe` = **0**；`grep -rn "value(forKey:" PhotoCleanupMVE --include=*.swift` = **0**；探针分支只读过一次（`git show probe/ic-145-scan-service:…` 查看它取视频文件名用的是 `.video` 资源），未 cherry-pick、未合并。

### G874：大视频门槛与三个类别 —— 满足

- `S0ScanRules.bigVideoMinimumByteCount == 100_000_000`，出处注「IC-153 裁定 一；Decision_log 第 180 条 ④（Lynn 2026-09-16 定案取默认值）」；断言 1 钉「恰好等于门槛命中、差一字节不命中」，断言 3 钉取值。执行端未改动。
- 三个类别的判据与 A1 逐字对应：`screenshot` ⟺ `isScreenshot`；`screenRecording` ⟺ 视频且（原始文件名以 `ScreenRecording_` 开头，大小写敏感，或像素 1206×2622／2622×1206）；`bigVideo` ⟺ 视频且 `byteCount ≥ 100_000_000`；未解析不命中任何类别。
- `categories` 恒三条、顺序 `bigVideo, screenRecording, screenshot`（断言 2、7、8 钉）；`duplicate`／`similar` 不出现（裁定 二），`S0CategoryIdentifier` 五个 case 未删（`Core/` 零改动）。

### G875：合并前置 —— 满足

| 条件 | 状态 |
|---|---|
| G872～G874 | 满足 |
| 全部 XCTest 通过、真实退出码 0 | #306：824 项 0 失败，XCTest 步骤 success ✔ |
| 执行摘要 notice | `Executed 824 tests, 0 failing test case(s), across 1 launch(es)` ✔ |
| `OS:26.2, name:iPhone 16` 目的地实证行 | ✔ |
| IPA 字节数与 SHA-256 | 1618776 ／ `dac6f937…d5b5` ✔ |
| 断言 1～13 函数名 + 日志核 `passed` | 第五节 ✔ |
| 项数对账 811 + 13 | = 824 ✔ |
| IC-147 16 项与 IC-148／IC-151／IC-152 相关用例逐条 `passed` | 第五节 ✔ |
| pbxproj 撞号扫描 | 第九节 ✔ |
| 工作树净 | 报告提交后 `git status --porcelain` 空 ✔ |
| `main` 未被他人推进 | 合并前再读 `git ls-remote origin refs/heads/main`（第十一节） |

### G876 —— 合并后 `main` 自动运行（合并后回填，见第十一节）

---

## 九、pbxproj 撞号扫描

- 登记前重扫（`main`）：文件引用最大 `100000000000000000000054`、构建文件最大 `200000000000000000000051`，与卡内 X1 一致。
- 新登记：文件引用 `…55`～`…59`、构建文件 `…52`～`…56`（逐文件对应见 `change-list.md` 第四节）；这十个 id 在 `main` 版 pbxproj 中零出现。
- 分支 tip：对象定义 206 个、**重复定义 0**；每个新文件引用 id 恰 3 处、每个新构建文件 id 恰 2 处；新文件全部进入对应 Sources 阶段（#306 编译并执行了 `IC153ScanServiceTests` 全部 13 项，即测试文件确在测试目标内；服务类型被 App 与测试引用而编译通过，即四个产品文件确在应用目标内）。

---

## 十、本地门禁（真实退出码，分支 tip `3e84b21`，工作树净）

| 门禁 | 命令 | 退出码 | 读数 |
|---|---|---|---|
| 结构自验 | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Scripts/selfcheck.ps1` | **0** | 「结构自验通过」 |
| 硬编码扫描 | `…-File Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 目录条目 247、产品源码引用 key 247、用户可见硬编码残留 0 |
| IC-149 门禁一 | `…-File Scripts/check-swift-string-structure.ps1 -SelfTest` | **0** | 两个负对照判红、正对照零命中；扫描 81 个 `.swift` 无未闭合字符串、无括号失衡 |
| IC-149 门禁二 | `…-File Scripts/check-scan-needle-variant.ps1 -SelfTest` | **0** | 两个负对照判红、正对照零命中；扫描 39 个测试源文件（含新文件）无 needle 喂错源码变体 |
| 空白 | `git diff --check 681cf06 HEAD` | **0** | — |

CI 上 #306 的「运行结构自验」「扫描用户可见硬编码字符串」两步同样 success。

---

## 十一、合并

G875 满足，按卡内授权执行：`git merge --no-ff feature/ic-153-scan-service` 入 `main` 并推送。**合并提交 SHA 与 G876（合并后 `main` 自动运行）由合并后的回填提交补记**（纪律 7：推送后才产生的信息，同卡追加 docs 提交；照 IC-150／IC-151／IC-152 的做法记在 `main` 上）。

---

## 十二、发现但未处理的问题（按纪律只报告不修）

1. **生产源的枚举没有抛错路径**：`PHAsset.fetchAssets(with:)` 本身没有错误通道，`.production` 的 `enumerateAssets` 从不抛出，S0-4 的读取类版式在真机上走不到（夹具可走到，断言 8 钉）。若要覆盖「照片库暂不可用」一类情形，需另定判据（卡外）。
2. **冷启动的两个时序窗口（③，H75 第 1、2 条观察）**：（a）首次安装授权窗点「允许」后，若首页在新一遍扫描确认授权之前就按上一遍的授权失败初始化，会先闪一下失败页，再由回调带到扫描中（第 6.2 条）；（b）缓存完整时，若首页在第一遍扫描（授权 + 读缓存文件 + 约 172 ms 元数据枚举）结束前就初始化，会短暂显示「正在扫描…」再转就绪。两者长短都取决于真机上首页出现与扫描完成的先后。
3. **一遍扫描在飞时再推进无副作用**（卡内要求）：若未解析重试那一段很长，期间新拍的照片要等这一遍结束后的下一次前台恢复才会被发现（③）。
4. **`D_全部` 变化不触发回调**：待删篮体积与类别排除在首页视图重建时（从 S2／S3 返回，路由切换会重建 tab 容器）或下一次快照变化时才更新（③，H75 第 7 条判）。
5. **每 200 项落盘会整份重编码缓存**：首扫 6339 项约写 32 次全量 JSON；真机开销未测（③，H75 第 1 条的耗时里包含它）。
6. **受限授权下看不见的资产会从缓存里丢弃**：之后改回完全授权，这部分要全量重取（规格「S0 不区分不可见与不存在」的直接后果）。
7. **首页类别行数量随数据源变化**：真实服务给三条（裁定 二），IC-147／IC-148 的视图与行为测试仍用给五条的桩剧本；桩已不在产品里使用。不是缺陷，H75 第 4 条判首页观感。
8. **终态回调最多晚 250 ms**（第 6.3 条的直接后果）。
9. **CI 作业时长余量**：#306 作业 10 分 59 秒（XCTest 步骤 8 分 34 秒），距 `timeout-minutes: 15` 约 4 分钟；即第 178 条记的待开 CI 维护卡所指风险，本卡未触发。

---

## 十三、人工判定项（H75，留给 Lynn 真机，执行端不代为下结论）

装合并后 `main` 的产物。**第一次打开前先把旧版本删掉**（缓存文件是本卡新建的，不存在迁移问题；删旧版本只为排除桩数据残留的观感）。

1. **首扫**：打开即进「空间清理」，hero 先显示「正在扫描…」，随后数字增长、副行「已扫描 N / M」变化；全库（约 6339 项）在**约 1 分钟内**扫完（H68 外推 ≈ 18 s 加聚合与节流；超过 3 分钟记「不过」并记实际时长）。扫描期间页面可滚动、可切 tab、可进 S2，不卡。
2. **续扫**：扫到一半杀掉 App 再打开——进度**不从零开始**；扫完后再杀再开——**秒进就绪态**（不再出现「正在扫描…」）。
3. **数字对得上**：屏幕截图项数与系统「相册 → 截屏」的张数**接近**（H68 为 2783）；屏幕录制项数与「屏幕录制」相册接近（H68 为 34）；大视频项数与门槛（裁定 一）的直觉相符——随手翻几个最大的视频看它们在不在。
4. **首页只有三个类别行**：大视频、屏幕录制、屏幕截图；**没有**重复／相似两行（裁定 二，规格「未实装不显示」）。类别行封面仍是占位（封面接线归 5.2，不是本卡缺陷）。
5. **前台恢复**：拍一张新照片（或截一张屏）再回到 App——短暂回到扫描中、数字更新；不拍任何东西回来——直接就绪、无闪动。
6. **iCloud 与受限授权**：若照片库开了「优化储存」，看 hero 数字是否明显偏小（未解析的资产计 0，见裁定 三）——记观察不记缺陷；把授权改成「受限」再打开，受限提示条出现、数字只覆盖选中的照片。
7. **回归**：切到「逐张整理」再回来 S1／S2／S3 行为不变；待删篮胶囊在 S2 标记几张后右半的体积**不再是零**（本卡新接的 `pendingDeletionByteCount`）；H73 六项快过一遍（氛围底与玻璃卡本卡不碰）。

---

## 十四、报告内 40 位 SHA 的实读核验

报告写完后，对 `self-check.md` 与 `change-list.md` 内全部 40 位十六进制串（`grep -ohE '\b[0-9a-f]{40}\b' … | sort -u`，共 14 个）逐个执行 `git cat-file -e <sha>^{commit}`，**14／14 退出码 0**：

| SHA | 提交标题（节选） |
|---|---|
| `13af137e3602df4beefcdd5ce4f1db7a07f51bb3` | feat(IC-153 A): 扫描规则登记表、单资产分类与三类别聚合的纯逻辑 |
| `cec92cea4864a6a622628f4009c0ef292db99a28` | feat(IC-153 B): 扫描缓存与增量续扫引擎（零 PhotoKit） |
| `cf76fe9c6f8edc6257433a61ea8643858ad79178` | feat(IC-153 C): PhotoKit 扫描源、数据源协议实现与 App 接线 |
| `7c718626d6052f36bac115ca804f3cbb603861d6` | feat(IC-153 D): 桩补协议钩子属性，断言 13 |
| `3e84b211e9db17656900c2b429e60643c28f8a4c` | fix(IC-153 B): 缓存仓库构造里改用具名类型取静态常量，降编译面风险 |
| `681cf0699163bfd84a042ea907988680be09a599` | docs(IC-152): 回填合并提交与 G871 |
| `1e603d73c201c5313b0179dd3765ae4fe87f8306` | Merge IC-152 |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | docs: 完成 IC-089（冻结链 tip） |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | docs: 完成 IC-091 阶段一（冻结链 tip） |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | docs: IC-092 自验报告与变更清单 v2（冻结链 tip） |
| `9db02b93eccbb87d126602901807e70823535111` | test: 等待首个真实捏合完整结束（`probe/ic-067` tip） |
| `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | probe: IC-125 负对照（`probe/ic-125` tip） |
| `486bcb769b59eb1146c5a231c7998847206777cc` | probe: IC-137 媒体播放探针（`probe/ic-137` tip） |
| `d373afc7125104c01acfc296829229090e6871ce` | docs(IC-145): 自验报告与变更清单（`probe/ic-145` tip） |

合并提交与 G876 运行产生后，回填提交里对新增的 40 位串再核一遍。
