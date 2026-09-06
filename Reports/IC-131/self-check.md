# IC-131 自验报告

> 报告提交方式说明（执行纪律第 7 条）：报告须引用推送后才产生的 CI 运行编号、
> IPA 校验、合并提交 SHA 与 G715 结果，故采用「同一张卡、同一分支内追加一个
> docs 提交」的方式，随合并留在 `main` 上，不跨卡回填。

## 结论（先行）

**交付合格，全绿，已合并入 `main`。** 两个子项各自独立 commit：
A（`ead287c`）把空态垃圾桶与徽标口径改回四态统一，B（`ffc254b`）让写回校验失败
不再阻断返回、改为回到 S1 并发一条底部短 toast。CI 主跑 **#254** 一次通过：
XCTest **647 项 0 失败**（较基数 640 增 7 项），真实退出码 0，
「XCTest 执行摘要」notice 在位，目的地 `OS:26.2, name:iPhone 16`。
八条必增断言逐条落实、逐条 passed。G711～G714 全部满足，
`--no-ff` 合并提交 **`652cc09`**；G715 合并后 `main` 自动运行 **#255 绿**
（同为 647 项 0 失败）。本地三条门禁退出码均为 0。
CI 预算 3 次**只用 1 次**，两次修复预算未动用。

人工判定项 **H58 两项保留给 Lynn 真机观察，本报告不代为下结论**。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260906-131-s1-trash-toast-fix.md`
- 依据：`<top>/SPEC-S1-20260905_v8.md` 文首「实装状态标注」两处；Decision_log 第 141 条
- 继承提交：`main` = `937ed7655b80d47fa992a90c144c73f5ab28e7bd` ①
  标题逐字比对一致：
  `docs: IC-130 自验与变更清单（合并 IC-128 入 main 0bf5ebd，#253 绿 640 项）`
- 开工检查：`git status --porcelain` 空；`git fetch` 后 `origin/main` 同为 `937ed76` ①
- 目标分支：`feature/ic-131-s1-trash-toast-fix`，自该 `main` 切出
- **被测提交（完整 SHA）**：`ffc254b81f0a0bf9bb89beb0fa1148f4644835a6`（分支 tip，含 A、B 两个 commit）
- 现状基数：`main` 上 640 项（CI #253）→ 本卡后 **647 项**（+7）

## 子项 A · 空态垃圾桶口径对齐决策 8 / 24

实现：`S1ChromeBarModel.make` 去掉两处 `state != .empty`——
`trashEnabled = !isLoading && badgeCount > 0`，
`badgeText` 只看 `badgeCount > 0`，与状态无关。
`controlsEnabled` / `controlsOpacity` 口径不变（只有 `.loading` 降 40% 并禁用）。
第 86～87 行的错误口径注释一并改为四态统一口径并注明修正理由。
视图结构、S1-3 中央空态版式、副行「0 张 · 0 个范围」均未动。

### 卡内根因陈述核对：**确认**，无矛盾 ①

卡内指出现行实装在 `state == .empty` 时一律禁用垃圾桶且不显示徽标。
源码可核验：原 `make` 中 `badgeVisible = badgeCount > 0 && state != .empty`、
`trashEnabled: !isLoading && state != .empty && badgeCount > 0`，与陈述逐字相符。
`testIC131A_EmptyDimensionKeepsBadgeAndSubmissionPath` 反向证明：空态下
`badgeCount` 仍为 2、`makeS3Submission()` 仍能形成含两张的提交——即数据层从来
畅通，缺口只在展示口径这一层。**未发现与卡内陈述矛盾的实测数据。**

## 子项 B · 写回校验失败：不阻断返回 + 底部 toast

- 协调器新增私有 `returnToS1AfterFailedWriteBack()`：**不写回**（`M`、`K`、`F`
  保持上一次有效值）、照常 `clearS2RouteState()`、照常对账一次、`route = .s1`、
  `message = nil`，再发一条一次性「写回失败」事件。
- `leaveS2(with:)` 与 `enterConfirmationFromS2(with:)` 的失败分支都改走它；
  垃圾桶路径失败**不进入 S3**、不形成提交。两个函数的**成功路径零改动**。
- 事件通道与持久型 `message` 分开：`s1FeedbackEvent` 一次性、可等待，
  S1 视图 `onAppear`／`onChange` 取走后经 `consumeS1FeedbackEvent()` 清空——
  失败恰好发生在 S1 尚未挂载的那一刻，事件必须能等到视图出现。
- S1 视图新增 `S1FeedbackToastPresenter`（形状同 S2 侧：同一时刻只一条、新事件
  替换旧的、旧事件到期不清除新事件、计时经 `scheduler` 注入）与底部 overlay。
  样式取 S2 既有常量（`.subheadline`、`S2OverlayLayout.minimumSpacing` 的
  2×／1× 内边距、`.regularMaterial` + `Capsule()`），不新造。
  时长读 `S2CalibrationConfiguration.feedbackToastDurationMilliseconds`（未写死 2000）。
  位置只锚安全区底 + `S2OverlayLayout.bottomRowBottomInset`（8），
  **未套 `toastBottomFromViewportBottom` 的横栏推导式**（陷阱 14：S1 没有横栏，
  那是给 S2 触控带的几何）。`.allowsHitTesting(false)`，不接收点击。
- 文案：新增 key `s1.toast.writeback_failed`，值逐字取 v8 第十一节第 3 部分
  登记原文。
- `applyS2Return`（状态机侧与 SessionStore 侧）的**校验条件一字未改**——
  本卡只处理「失败之后发生什么」。

## 八条必增断言逐条结果（#254 全部 passed）①

| # | 断言 | 测试函数 | 结果 |
|---|---|---|---|
| 1 | 改 `empty` 段：`badgeCount 2` → `trashEnabled == true`、`badgeText == "2"`；新增 `empty` 且 `badgeCount 0` → `false` / `nil` | `testIC128A_ChromeBarStatesFollowLoadingEmptyReady` | passed |
| 2 | 维度 A 标记两张 → 切到 `R(T)` 为空的维度 → `.empty` 且 `badgeCount == 2`，`makeS3Submission()` 仍含这两张 | `testIC131A_EmptyDimensionKeepsBadgeAndSubmissionPath` | passed |
| 3 | 四态穷举（`.loading`/`.ready`/`.empty`/`.failed` × `badgeCount ∈ {0,3}`，八个用例）钉住 `trashEnabled == (state != .loading && badgeCount > 0)`、`badgeText == (badgeCount > 0 ? "3" : nil)` | `testIC131A_ChromeBarTrashAndBadgeFollowOnlyLoadingAndBadgeCount` | passed |
| 4 | 坏 payload 走 `leaveS2` → 返回 false、`route == .s1`、`s2Machine == nil`、`sessionStore` 逐字节相等、事件通道恰好一条 | `testIC131B_FailedWriteBackOnLeaveReturnsToS1AndEmitsOneEvent` | passed |
| 5 | 同样坏 payload 走 `enterConfirmationFromS2` → 返回 false、`route == .s1`（不是 `.s3`）、未形成提交、一条事件 | `testIC131B_FailedWriteBackOnTrashPathDoesNotEnterS3` | passed |
| 6 | 成功路径回归：返回 true、`route == .s1`、`M`／`K` 已写回、**事件通道为空** | `testIC131B_SuccessfulWriteBackEmitsNoEvent` | passed |
| 7 | 呈现器：连发两条只留后者；旧事件到期不清新事件；新事件到期才清。注入调度器驱动，不真等 2 秒、不依赖主线程逐帧推进 | `testIC131B_ToastPresenterKeepsLatestEventAndExpiresOnSchedule` | passed |
| 8 | 文案经目录取得、逐字等于 v8 登记原文；呈现器不自带字面量 | `testIC131B_ToastTextComesFromStringCatalog` | passed |

断言 4 的「逐字节相等」以 `SessionStore: Equatable` 的整体 `XCTAssertEqual` 实现
（`M`、`K`、`F` 三者都在 `State` 内）。断言 8 中「源码中不存在该中文字面量」
一半由 `Scripts/scan-hardcoded-user-visible-strings.ps1` 覆盖（扫描范围是
`PhotoCleanupMVE/` 产品源码，退出码 0、残留 0），测试侧钉的是「目录里确实有这条」
与「呈现器经目录取值」。

## 闸门逐条结论

### G711（diff 限于白名单）：**通过** ①

diff 共 8 文件，全部在卡内白名单内。

`CleanupCoordinator.swift` **改动的函数与新增成员逐一列出**：

| 类别 | 名称 | 说明 |
|---|---|---|
| 新增成员 | `s1FeedbackEvent`（`@Published private(set) var S1FeedbackEvent?`） | 一次性写回失败事件通道 |
| 新增成员 | `s1FeedbackEventCount`（`private(set) var Int`） | 已发事件总数，`id` 取此序号（测试用） |
| 新增函数 | `consumeS1FeedbackEvent()` | 视图取走后清空通道 |
| 新增函数 | `returnToS1AfterFailedWriteBack()`（private） | 失败后的统一收场 |
| 改动函数 | `leaveS2(with:)` | **仅** `guard applyS2ExitPayload` 的 else 分支加一行调用；签名与成功路径未动 |
| 改动函数 | `enterConfirmationFromS2(with:)` | **仅** 同一处 else 分支；签名与成功路径未动 |

`applyS2ExitPayload` 的校验条件、所有 `s2*` 成员、S3／S4／S5 路由**零改动**
（diff 内无这些符号）。

`PhotoCleanupMVEApp.swift` 的改动限于 S1 视图构造处：把原地内联的 `S1View(...)`
外提为私有 `s1Screen(machine:)` builder 并补三个实参。**这一步比「纯加参数」多做了
一次外提**，理由见「发现但未处理的问题」第 3 条。

### G712（S2～S5、标定与冻结链）：**通过** ①

- S2～S5 产品代码零改动：diff 文件集合中不含任何 `Features/S2`～`S5`、
  `Core/S2`～`S5` 路径；`S2View.swift` 未改（只参照其 toast 形状与常量）
- `S2Calibration.swift` **完全未改**（`git diff --stat` 对该文件为空）——
  故 `S2CalibrationConfiguration` 字段集合零改动、
  `schemaVersion` 仍为 **7**（`S2Calibration.swift:118`）。本卡只**读取**既有参数
  `feedbackToastDurationMilliseconds`，不构成出厂值集合变更，无需递增版本号。
- 冻结三链 tip 未变（本地＝远端）：`b368a6c` / `6736f1e` / `a7cc1ec`

### G713（CI 绿）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#254**（run id `34028015334`，attempt 1） |
| 被测提交 | `ffc254b81f0a0bf9bb89beb0fa1148f4644835a6` |
| job | `101472350058`，conclusion=**success**，10:39:13Z→10:46:37Z |
| XCTest | **Executed 647 tests, with 0 failures (0 unexpected) in 92.401 (140.700) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 「XCTest 执行摘要」notice | **在位**（IC-125 哨兵通过，647 > 0；陷阱 20 已核） |
| 真实退出码 | **0**（`set -o pipefail` + `exit "$test_status"` 原样退出；job success） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| 选定日志行 | `使用 iPhone 模拟器：iPhone 16 (id=EADC2067-…, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| IPA 登记 | `PhotoCleanupMVE-unsigned.ipa`，**1207559 字节**，SHA-256 `5d1b48aa3095f0877f4ddefaf9c86ca1cac16830845896da236b9d3977acd241` |
| 实际发出的注解 | `##[notice]` 2 条；`##[error]` **0** 条；`##[warning]` **0** 条 |

八条断言对应的测试函数在日志中逐条 `passed`（已按函数名逐个核对，见上表）。
测试项数 640 → 647，增量 7 = 新文件 2 项 + 5 项；断言 1 落在既有函数内故不增项。

CI 预算：3 次**用 1 次**，两次修复预算未动用。

### G714（合并前置 + 合并）：**通过** ①

- 前置逐项：G711～G713 全满足；`git status --porcelain` 空；
  `git fetch` 后 `origin/main` 仍为 `937ed76`（未被他人推进）；
  `git merge-base main <分支>` = `937ed76`，快进式结构、零冲突
- 合并：`--no-ff` 合并提交 **`652cc09`**
  （完整 SHA `652cc098529214bd09b04383c2eb1ed3835e1eb1`），
  parent1 `937ed76`、parent2 `ffc254b`，已推送
  （远端报文 `937ed76..652cc09`，两点记法即非强推）
- 合并零自身内容：合并提交树对象与分支 tip 树对象同为
  `ba7fe7b243f5b81df57046a94200021579ac2bae`
- 未 rebase、未 amend、未强推

### G715（合并后 `main` 自动运行）：**绿** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#255**（run id `34028477143`，attempt 1） |
| 被测提交 | `652cc098529214bd09b04383c2eb1ed3835e1eb1`（合并提交） |
| job | `101473599350`，conclusion=**success**，10:49:28Z→10:56:26Z |
| XCTest | **Executed 647 tests, with 0 failures (0 unexpected) in 34.357 (80.949) seconds** |
| 摘要 notice / `** TEST SUCCEEDED **` | 均在位；`##[error]` 0 条、`##[warning]` 0 条 |
| 目的地 | 同 #254（`OS:26.2, name:iPhone 16`，id `EADC2067-…`） |
| IPA | 1207559 字节，SHA-256 `17eb3bc649b806466a07514c760287d2b96c98d821f4e65fe35b93f72f5f0cf0` |
| 产物 | `PhotoCleanupMVE-unsigned-652cc0985292`，zip 1207729 字节 |

IPA 字节数与 #254 相同、SHA-256 不同——IPA 归档不可复现为既往实证结论（②既往样本），
同时反向印证合并未改变任何产品代码。

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | String Catalog **207 条目 ↔ 207 源码引用**一致（新增 1 条并被引用）；用户可见硬编码残留 0；禁联网门禁、不少于 189 项测试的数量门禁均通过 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 残留 0；新增 toast 文案未留下中文字面量 |
| `git diff --check` | **0** | 两个 commit 与合并 diff 均无空白错误 |

## 人工判定项（H58，留给 Lynn 真机观察，执行端不代为下结论）

1. 空态（切到一个没有范围的维度）下垃圾桶徽标仍显示、可点进 S3。
2. 写回失败 toast 的观感是否与 S2 的 toast 是同一套。

**执行端只能说明：** 断言 3 已把 A 的口径钉成表、断言 4～7 已把 B 的路由与
呈现器时序钉住；但**渲染观感与 toast 的实际落位没有任何自动化覆盖**——
夹具断言只到展示口径模型与呈现器状态为止，不驱动 SwiftUI 渲染（陷阱 1）。
两项均待真机判定。

## 发现但未处理的问题（按纪律只报告不修）

1. **`enterConfirmationFromS2` 还剩一条会把界面卡死的残留失败路径**（①源码可核验，
   **非本卡引入、本卡范围外**）。写回**成功**之后若
   `s1Machine?.makeS3Submission()` 返回 nil（或 `enterConfirmationFromS1` 返回
   false），该函数直接 `return false`，而此前已执行 `clearS2RouteState()`——
   于是 `route` 仍为 `.s2` 但 `s2Machine == nil`，App 的 `case .s2` 分支落到
   `else { ProgressView() }`，界面停在一个无法退出的转圈上。
   本卡授权范围是「写回**校验失败**」分支（`applyS2ExitPayload` 返回 false），
   这条属于校验通过之后的提交形成失败，故未改。建议单开一卡一并收口。
2. **toast 的实际落位没有夹具覆盖**（①）。断言 7 钉的是呈现器的事件替换与到期
   时序，`.padding(.bottom, S2OverlayLayout.bottomRowBottomInset)` 究竟渲染在
   哪一行像素上未被任何测试触及，只能由 H58 第 2 项兜底。
3. **App 层做了一次「构造点外提」，比「纯加实参」多一步**（①）。原
   `S1View(...)` 内联在 `WindowGroup → Group → switch` 的多层嵌套里，本卡要往
   它上面加三个实参；CLAUDE.md 陷阱 16 记录该模式已导致三次 CI 类型检查超时
   （IC-108 #192、IC-113 #214/#215）。故按陷阱的既定处置外提为私有
   `s1Screen(machine:)`，改动仍限在 S1 视图构造处，S2～S5 各分支一字未动。
   **登记在此供决策会话认定是否越界。**
4. **失败路径上 `message = nil` 属执行端取定**（④待确认）。卡只写了「不写回、
   清 S2 路由态、对账、`route = .s1`、发事件、返回 false」，没提 `message`。
   置空与成功路径一致，避免把上一条持久型错误文案带回 S1；若决策会话认为失败时
   应保留既有 `message`，此处需改一行。

## 附：两处实装状态标注可否结案

v8 文首「规格先行、实装待卡」两处的实装已按本卡完成并通过 CI（①），
但**是否据此把标注改为已实装、以及 SPEC 是否补写「失败后仍回 S1」「垃圾桶路径
失败不进 S3」两条**，属规格与决策日志的修改权限，本卡范围外，不代为处理。
