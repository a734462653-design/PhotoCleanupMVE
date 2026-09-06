# IC-132 自验报告

> 报告提交方式说明（执行纪律第 7 条）：报告须引用推送后才产生的 CI 运行编号、
> IPA 校验、合并提交 SHA 与 G725 结果，故采用「同一张卡、同一分支内追加一个
> docs 提交」的方式，随合并留在 `main` 上，不跨卡回填。

## 结论（先行）

**交付合格，全绿，已合并入 `main`。** 两个子项各自独立 commit：
A（`f916f31`）把范围显示名并入会话档，修掉「跨启动恢复后提交恒为 nil」的根因；
B（`6a1ddb4`）让提交形成失败不再卡死、不再静默。CI 主跑 #256 因**测试文件里的
一处枚举例名写错**编译红（卡内断言 9 写作 `route == .s3`，实际例名为
`.confirmation`），修复后 **#257 绿**：XCTest **656 项 0 失败**（较基数 647 增 9 项），
真实退出码 0，「XCTest 执行摘要」notice 在位，目的地 `OS:26.2, name:iPhone 16`。
九条断言逐条落实、逐条 passed。G721～G724 全部满足，`--no-ff` 合并提交
**`a1cafed`**；G725 合并后 `main` 自动运行 **#258 绿**（同为 656 项 0 失败）。
本地三条门禁退出码均为 0。CI 预算 3 次**用 2 次**，剩 1 次未动用。

人工判定项 **H59 两项保留给 Lynn 真机验证，本报告不代为下结论**。

**一处与卡内断言字面不符，已按纪律第 3 条停下说明、未硬套**——见「断言 1 的
字面要求不成立」一节。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260906-132-s3-submission-dead-end.md`
- 起因：IC-131 报告「发现但未处理」第 1 条；依据 SPEC-S1 v8 第二节与决策 28、
  第七节第 3 部分；Decision_log 第 143 条
- 继承提交：`main` = `9d1e842b71d586f4c330e4f494611d4cbc91e534` ①
  标题逐字比对一致：
  `docs: IC-131 自验与变更清单（#254 绿 647 项，合并入 main 652cc09，#255 绿）`
- 开工检查：`git status --porcelain` 空；`git fetch` 后 `origin/main` 同为 `9d1e842` ①
- 目标分支：`feature/ic-132-s3-submission-dead-end`
- **被测提交（完整 SHA）**：`93b13c7bb223a0a82e74e99bd407210741dee43d`（分支 tip）
- 现状基数：647 项（CI #255）→ 本卡后 **656 项**（+9）

## 缺陷链条核对：**确认属实，无矛盾** ①

卡内三步链条逐条对照源码核实：

1. `knownRangeNamesByID` 原为 `private var`（`S1StateMachine.swift:278`），只在
   `adoptRanges` 内由本次 `R(T)` 填充；`S1SessionSnapshot` 与 `PersistedS1Session`
   均无该字段；`restore(from:)` 恢复出的名字表为空。**属实。**
2. `makeS3Submission()` 要求 `M` 中每个已标记范围都有已知名字，否则返回 nil。
   **属实。**
3. 两处后果——S1 垃圾桶 `guard ... else { return }` 静默；
   S2 垃圾桶 `route` 停在 `.s2` 而 `s2Machine` 已 nil，App `case .s2` 落到
   `else { ProgressView() }`。**属实**（后者即 IC-131 报告所报，本卡实测复现于
   `testIC132B_SubmissionUnavailableAfterSuccessfulWriteBackReturnsToS1` 的
   修复前行为推理与修复后断言）。

**未发现与卡内归因矛盾的实测数据。**

## 断言 1 的字面要求不成立（纪律第 3 条，停下说明，未硬套）

卡内断言 1 要求：恢复出的新状态机「**在读取任何 `R(T)` 之前**调用
`makeS3Submission()` 返回非 nil」。

**实测不成立，且与本卡的修复无关**（①源码可核验）：
`makeS3Submission()` 的第一条守卫是 `state != .loading`
（`S1StateMachine.swift`，本卡未改），而 `restore(from:)` 恢复出的状态机以
`.loading` 起步（该行为由 IC-127 B 定案并在注释中写明：「状态机以 `loading` 起步，
首次 `completeRangeRead` 内必经对账后才到达就绪态」）。因此**无论名字表是否已灌回**，
此刻都必然返回 nil。放宽这条守卫属本卡**范围外**（卡内「不改 `makeS3Submission()`
的 nil 条件」，且范围外章节再次点名）。

**处置**：把断言 1 拆成两条，覆盖其真实意图而不动 nil 条件——

- `testIC132A_RangeNamesSurviveArchiveRoundTrip`：名字表确实跨
  「快照 → 编码 → 解码 → `restore`」存活并可见；同时**如实钉住**此刻
  `state == .loading` 且 `makeS3Submission()` 为 nil，把「nil 的原因是加载态
  而非名字缺失」写进断言，避免日后被误读成修复没生效。
- `testIC132A_SubmissionUsesArchivedNamesWhenReadSuppliesNone`：读到**空 `R(T)`**
  （本次读取一个名字都没提供）之后，`makeS3Submission()` 非 nil，且分组名与原
  范围显示名**逐字相等**。这一条才是「隔天回来、切了维度、点垃圾桶」的现场，
  也正是断言 1 想证明的东西。

如决策会话认为应当放宽 `.loading` 守卫（例如恢复态也允许提交），需另开一卡。

## 子项 A · 范围显示名随会话档持久化

- `S1SessionSnapshot` 新增 `rangeNamesByID: [String: String]`；`sessionSnapshot`
  填入 `knownRangeNamesByID`；`restore(from:)` 灌回。
- `PersistedS1Session` 新增同名字段。**旧档兼容**：手写 `init(from:)`，
  该字段走 `decodeIfPresent(...) ?? [:]`，其余字段仍 `decode`（缺失照旧抛错，
  坏档语义不变）；编码沿用合成实现。
- **写出口保持唯一**：`adoptRanges` 内名字表改为「先合并到局部变量、再一次性赋值」
  （逐键赋值会让末尾的出口按中间态多写几次），并在函数末尾调用**既有的**
  `publishSnapshotIfChanged()` 一次。`knownRangeNamesByID` 不是 `@Published`、
  没有 `didSet`，名字单独变化时 `sessionStore` 赋值不发生、快照会漏写，故必须补这一次；
  该出口自身按 `lastPublishedSnapshot` 去重，store 同时变化的情况不会多写。
  **没有新开第二个写出口**（陷阱 19、v8 第二节）。
- 名字表只增不删；对账剔除范围时不删名字。
- `makeS3Submission()` 的 nil 条件**未动**。
- `S1SessionSnapshot` 的逐成员构造给 `rangeNamesByID` 默认空表，使既有构造点
  （含断言 4 点名的两条回归测试）**无须改写即可编译**。

## 子项 B · 提交形成失败不再卡死、不再静默

- 协调器新增私有 `returnToS1AfterUnavailableSubmission()`：`route = .s1`、
  `message = nil`、发一条 `.submissionUnavailable`。与 IC-131 的
  `returnToS1AfterFailedWriteBack()` 的区别是**写回结果保留**（`M`、`K` 已更新）。
- `enterConfirmationFromS2`：写回成功后 `makeS3Submission()` 为 nil → 走上述收场；
  委派 `enterConfirmationFromS1` 返回 false → 只补路由收口（`route = .s1`、
  `message = nil`），**不重复发第二条事件**。
- `enterConfirmationFromS1`：两条失败路径（前置 guard、`enterConfirmation` 返回 false）
  各发一条事件，不再静默 `return false`；**不改 route**（该方法也可能在
  `.upstream`／`.finished` 下被调用，改 route 会越界）。
- `S1View.trashButton`：动作抽成可测的 `S1TrashButtonAction.perform(machine:
  onS3Submission:onSubmissionUnavailable:)`；nil 提交时不再静默。
- 事件呈现**复用** IC-131 的 `S1FeedbackToastPresenter`，只加一个 kind → 文案映射，
  未新造视图。
- 文案：新增 key `s1.toast.submission_unavailable`，值逐字取卡内登记原文。

### 卡内二选一的选择与理由（卡要求报告说明）

`trashButton` 的反馈走**直接驱动本地呈现器**，不经协调器回调。理由：用户点的是
S1 自己的按钮，此刻 S1 必然已挂载，协调器通道的「事件等到视图出现」机制在这条
路径上不产生任何差别；而走协调器需要再向 App 层穿一个回调参数。视图自发事件的
`id` 取负数，与协调器发来的正序号分处两个命名空间。

## 九条断言逐条结果（#257 全部 passed）①

| # | 断言 | 测试函数 | 结果 |
|---|---|---|---|
| 1 | 名字表跨编解码往返存活；读到空 `R(T)` 后仍能形成提交且分组名逐字相等 | `testIC132A_RangeNamesSurviveArchiveRoundTrip`、`testIC132A_SubmissionUsesArchivedNamesWhenReadSuppliesNone` | passed（**字面要求不成立，已拆分，见上节**） |
| 2 | 旧档（无该字段）解码成功、名字表为空、其余字段正确 | `testIC132A_LegacyArchiveWithoutRangeNamesDecodesAsEmptyTable` | passed |
| 3 | 引入新范围名写出恰增 1；同一批范围再读一次不写 | `testIC132A_NewRangeNamesPublishExactlyOnceThroughSingleSink` | passed |
| 4 | IC-127 B 两条回归原样通过、未改写 | `testIC127B_ArchiveRoundTripRestoresMKFTAndO`、`testIC127B_CoordinatorRestoresArchivedSessionAndReconcilesBeforeReady` | passed（**源码一字未动**） |
| 5 | 写回成功但名字表为空 → 返回 false、`route == .s1`、`s2Machine == nil`、`M`／`K` **已**写回、恰一条 `.submissionUnavailable` | `testIC132B_SubmissionUnavailableAfterSuccessfulWriteBackReturnsToS1` | passed |
| 6 | 8 种组合下不变量 `!(route == .s2 && s2Machine == nil)` | `testIC132B_NoEntryPointLeavesRouteInS2WithoutMachine` | passed |
| 7 | 名字表空 → 出反馈且 `onS3Submission` 未被调用；名字齐全 → 恰调用一次、无反馈 | `testIC132B_TrashButtonActionFallsBackToFeedbackWhenSubmissionUnavailable` | passed |
| 8 | 两种 kind 文案各自经目录取得、互不相同 | `testIC132B_BothFeedbackKindsResolveDistinctCatalogText` | passed |
| 9 | 端到端：恢复 → 切维度读取 → 提交成功进确认页 | `testIC132B_RestoredSessionEntersS3WithoutFallbackAfterDimensionSwitch` | passed |

断言 8 中「源码不存在这两条中文字面量」由
`Scripts/scan-hardcoded-user-visible-strings.ps1` 覆盖（扫描范围是
`PhotoCleanupMVE/` 产品源码，退出码 0、残留 0）。
断言 9 中卡写作 `route == .s3`，实际枚举例名为 `.confirmation`（#256 编译红即此，
已在测试内注明）。

### 对既有「写出计数」测试的影响（主动核查，未被要求）①

子项 A 在 `adoptRanges` 末尾新增了一次经既有出口的推送，会改变写出时序，故逐条核对：

- `testIC127B_SnapshotIsPublishedThroughSingleSinkOnEveryChange`：其 sink 在
  `makeMachine` 完成读取**之后**才安装，计数期间 `adoptRanges` 不再运行——不受影响。
- `testIC129D_ReconciliationIsIdempotentAndSecondPassWritesNothing`：sink 装在首次
  读取之前，故首读多出 1 次写；但该测试的两处断言都相对于
  `writesBeforeReconciliation` 基线（在多出的那次之后取），`+1` 与「第二次不写」
  仍成立。
- 两处 `XCTAssertNil(persistence.loadS1Session())`：新推送只在 `adoptRanges` 内发生，
  那两处当时都没有驱动读取——仍为 nil。

三条推理均由 #257 的 656 项 0 失败实证。

## 闸门逐条结论

### G721（diff 限于白名单）：**通过** ①

diff 共 8 文件，全部在卡内白名单内。

`CleanupCoordinator.swift` **改动的函数与新增成员逐一列出**：

| 类别 | 名称 | 说明 |
|---|---|---|
| 新增函数 | `returnToS1AfterUnavailableSubmission()`（private） | 写回已生效但提交形成不了时的收场 |
| 新增函数 | `publishS1FeedbackEvent(_:)`（private） | 事件发布的共用出口（IC-131 的发布逻辑抽到此处） |
| 改动函数 | `enterConfirmationFromS2(with:)` | **仅**写回成功后的两条失败分支；成功路径与 `applyS2ExitPayload` 分支未动 |
| 改动函数 | `enterConfirmationFromS1(_:)` | **仅**两条失败分支各加一次事件发布；成功路径未动，不改 route |
| 改动函数 | `returnToS1AfterFailedWriteBack()`（IC-131 引入） | 仅把内联的事件构造换成调用 `publishS1FeedbackEvent(.writeBackFailed)`，行为不变 |

`applyS2ExitPayload` 的校验条件、所有 `s2*` 成员、S3／S4／S5 路由**零改动**。

### G722（S2～S5、标定与冻结链）：**通过** ①

- S2～S5 产品代码零改动：diff 中不含任何 `Features/S2`～`S5`、`Core/S2`～`S5` 路径
- `S2Calibration.swift` **完全未改**（`git diff --stat` 对该文件为空）→
  `S2CalibrationConfiguration` 字段集合零改动、`schemaVersion` 仍为 **7**。
  本卡改的是 S1 会话档格式（`s1-session.json`），不是标定出厂值；
  旧档兼容由断言 2 钉住。
- 冻结三链 tip 未变（本地＝远端）：`b368a6c` / `6736f1e` / `a7cc1ec`

### G723（CI 绿）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#257**（run id `34043352496`，attempt 1） |
| 被测提交 | `93b13c7bb223a0a82e74e99bd407210741dee43d` |
| job | `101513938241`，conclusion=**success**，15:46:26Z→15:51:35Z |
| XCTest | **Executed 656 tests, with 0 failures (0 unexpected) in 81.241 (95.035) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 「XCTest 执行摘要」notice | **在位**（IC-125 哨兵通过，656 > 0；陷阱 20 已核） |
| 真实退出码 | **0**（`set -o pipefail` + `exit "$test_status"`；job success） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| 选定日志行 | `使用 iPhone 模拟器：iPhone 16 (id=EADC2067-…, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| IPA 登记 | `PhotoCleanupMVE-unsigned.ipa`，**1211235 字节**，SHA-256 `8c308ac50ededb94c6e11018078bdfc3a8ed26af1cd08e828e4f55cbe71724f5` |
| 实际发出的注解 | `##[notice]` 2 条；`##[error]` **0** 条；`##[warning]` **0** 条 |

**CI 预算 3 次，用 2 次，剩 1 次未动用：**

- **#256 红**（run id `34042997989`）：`运行 XCTest` 步骤失败，退出码 **65**，
  注解 `IC132SubmissionDeadEndTests.swift:239:43: error: type 'CleanupRoute'
  has no member 's3'`。归因：**测试文件里的枚举例名写错**，卡内断言 9 的
  `route == .s3` 是页面口径的简写，实际例名为 `.confirmation`。产品代码无关。
- 修复提交 `93b13c7`（仅改测试一行 + 注释）→ **#257 绿**。
- 推第二次前对两个新测试文件用到的**全部产品成员逐个 grep 核存在性**，
  并逐条推演两个「写出计数」既有测试，避免再烧一次预算。

### G724（合并前置 + 合并）：**通过** ①

- 前置逐项：G721～G723 全满足；工作树净；`origin/main` 仍为 `9d1e842`；
  `merge-base` = `9d1e842`（快进式结构，零冲突）
- 合并：`--no-ff` 合并提交 **`a1cafed`**
  （完整 SHA `a1cafedc13b29cee47cef579a25a6bc11d5a73ad`），
  parent1 `9d1e842`、parent2 `93b13c7`，已推送
  （远端报文 `9d1e842..a1cafed`，两点记法即非强推）
- 合并零自身内容：合并提交树对象与分支 tip 树对象同为
  `60d17a67c2b75371d3db115d9e3ca0c558aefc85`
- 未 rebase、未 amend、未强推

### G725（合并后 `main` 自动运行）：**绿** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#258**（run id `34043724228`，attempt 1） |
| 被测提交 | `a1cafedc13b29cee47cef579a25a6bc11d5a73ad`（合并提交） |
| job | `101514936849`，conclusion=**success**，15:53:43Z→15:59:50Z |
| XCTest | **Executed 656 tests, with 0 failures (0 unexpected) in 65.593 (75.359) seconds** |
| 摘要 notice / `** TEST SUCCEEDED **` | 均在位；`##[error]` 0 条、`##[warning]` 0 条 |
| 目的地 | 同 #257 |
| IPA | 1211235 字节，SHA-256 `48d59943dfd08d236c028ee2f7715f4bd785c1d201143c9428ca38ce6e283412` |
| 产物 | `PhotoCleanupMVE-unsigned-a1cafedc13b2`，zip 1211405 字节 |

IPA 字节数与 #257 相同、SHA-256 不同——IPA 归档不可复现为既往实证结论（②既往样本），
同时反向印证合并未改变任何产品代码。

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | String Catalog **208 条目 ↔ 208 源码引用**一致（新增 1 条并被引用） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0；两条 toast 文案均未在产品源码留下中文字面量 |
| `git diff --check` | **0** | 三个 commit 与合并 diff 均无空白错误 |

## 会话档新字段与旧档兼容（卡要求必含）

- **新字段名**：`rangeNamesByID`，类型 `[String: String]`，位于
  `S1SessionSnapshot` 与 `PersistedS1Session`（档文件 `s1-session.json`）。
- **旧档兼容口径**：`PersistedS1Session` 改为手写 `init(from:)`，
  `rangeNamesByID` 走 `decodeIfPresent(...) ?? [:]`——**旧档缺该键时按空表解码，
  不判坏档**，已装机用户的档不因升级失效。其余六个字段仍用 `decode`，缺失照旧抛错，
  坏档语义（未知维度／排序、重复资产）一字未改。编码沿用合成实现，新档必带该键。
- 旧档恢复出的会话名字表为空，此时若 `M` 非空，提交仍形成不了——**由子项 B 兜底**
  （出 toast，不再静默、不再卡死），并会在用户切回那个维度读到该范围时自动补齐名字。

## 人工判定项（H59，留给 Lynn 真机验证，执行端不代为下结论）

1. 相册维度标记 2～3 张 → 杀应用 → 重开 → 徽标数仍在 → 点垃圾桶能进 S3，
   分组名是相册名。
2. 同场景从某范围进 S2 → 点 S2 垃圾桶 → 进 S3，不转圈。

**执行端只能说明**：断言 9 已在夹具层走通「恢复 → 切维度 → 提交进确认页」，
断言 5／6 已钉住不再卡死；但**真机的档是上一版应用写的旧档**（无
`rangeNamesByID`），这一层只有 H59 能覆盖——旧档首次重开时名字表仍为空，
预期行为是「点垃圾桶出 toast 而非无反应」，切回相册维度读一次之后才恢复正常。
这一点请在真机上一并观察。

## 发现但未处理的问题（按纪律只报告不修）

1. **旧档用户的首次体验仍是「点不动 + toast」，而非直接可提交**（①推理，
   ③真机未验）。子项 A 只让**新写入**的档带名字；升级前写下的档没有该键，
   恢复后名字表为空。用户需切到标记所在的维度读一次，名字才补齐。
   本卡范围内无法更好——名字只能从 `R(T)` 读到。若要更进一步（例如恢复后
   后台补读一次标记所在维度），需另开卡。
2. **`makeS3Submission()` 的 `.loading` 守卫使「恢复后立刻提交」不可能**（①）。
   见「断言 1 的字面要求不成立」。当前不构成缺陷（进入 S1 必然伴随一次读取），
   仅在断言字面上与卡不符，登记备查。
3. **`enterConfirmation(from:...)` 是 internal 且可被直接调用**（①）。本卡只在
   `enterConfirmationFromS1` 的调用点加了失败反馈；若日后有别的调用方直接用它，
   失败仍然静默。当前仓库内只有 `enterConfirmationFromS1` 一个调用点，故未扩大改动。
4. **修复提交 `93b13c7` 独立于子项 B 的 commit**（沿用 IC-128 的既定做法：
   cherry-pick 单位 = 整组）。单独 cherry-pick `6a1ddb4` 会带着那处编译错误，
   需连同 `93b13c7` 一起取。
