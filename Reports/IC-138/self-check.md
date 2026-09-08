# IC-138 自验报告

> 报告提交方式说明（执行纪律第 7 条）：本卡含合并授权，报告需引用推送后才产生的
> CI 运行编号、IPA 校验与合并 SHA，故采用「同一张卡、同一分支内追加一个 docs 提交」
> 的方式，随合并一并留在 `main` 上，不跨卡回填。

## 结论（先行）

**四个子项全部交付，零产品行为改动，已合并入 `main`。CI 预算 2 次用满 2 次
（第 1 次红，红在本卡新增的断言自身，不在被同步的数据上）。**

- 基线：`main` = `f8ae50af039e5b890be75a76cbe040db0bc422a6`
  （`docs: IC-136 …`，`main~1` = `ad4150488ed38a617192ffa237dc986470f77a75`，与卡逐字相符）
- 分支 `feature/ic-138-housekeeping`，代码 tip `113384a709f143dceba905710e7c0a9156ba322e`
- CI **#269** 绿：XCTest **677 项 0 失败**，真实退出码 0，摘要 notice 在位，
  目的地 `OS:26.2, name:iPhone 16`
- 合并提交 **`6b1adea`** / `6b1adeadf371e17fe7805f95928dfba2d0fbaefa`，零冲突
- **G785**：合并后 `main` 自动运行 **#270** 同为 677 项 0 失败
- G781 ✓ G782 ✓ G783 ✓ G784 ✓ G785 ✓
- 本地三条门禁退出码均为 0；人工判定项：**无**

**必须先看的四件事：**

1. **卡内两处计数与实际不符，均按「以你全表 grep 为准」处理**：
   已删测试名卡列 12 个，全表 grep 实为 **16** 个；
   「我已清空最近删除」事件卡说 4 个单元格，实为 **5** 个
   （第 5 个 C5-107 是**可达**单元格，不在强度表的 63 个不可达坐标内）。
2. **矩阵里的死引用不是一类而是两类**，卡只描述了第一类。除「条款随 L3 撤销」外，
   还有 **10 行条款存续、却引用了已删测试**。我按机械规则分四类处置，
   逐行列在 change-list，请决策会话核 R3／R4 两组的判定保留是否妥当。
3. **#268 那次红的根因是 Swift `throws` 方法的 ObjC 选择子带 `AndReturnError:` 后缀**，
   与被同步的数据无关。详见「CI 预算与那次红」——那一节也解释了为什么两条
   「> 100」的下界断言没能拦住它，以及补了什么才拦得住。
4. **R4 五行条款的「不新增磁盘读取」半句现已落空**（`FreeDiskSpaceReader` 随
   IC-134 F 删除）。判断该半句是否随之作废属规格事项（S5 v6），
   我只删死引用、未重判覆盖，登记在「发现但未处理」第 1 条。

---

## 子项 A：追溯矩阵同步（提交 `31dc851`、`113384a`）

### 处置规则（机械，可复核）

卡给的处置是「L3 条款行改 `—` + 条款已撤销」。全表 grep 后发现受影响的行不止
这一类，故按下述四条规则分派，规则本身不含个案判断：

| 规则 | 条件 | 处置 | 行数 |
|---|---|---|---|
| **R1** | 条款原文含 `L3`／`freeDisk`／`我已清空最近删除`，且所列方法**全部**已删 | 方法列 `—`、判定 `条款已撤销（Decision_log 147，随 S5 v6 落文）` | 15 |
| **R2** | 「我已清空最近删除」事件的迁移单元格 | 同 R1，另在判定理由**末尾**追加 `；事件已撤销（…）`，**坐标前缀原样保留** | 5 |
| **R3** | 条款属 L3 层但**尚有存续方法**覆盖其存续半句 | 只删死引用，判定保留 | 3 |
| **R4** | 条款**不属** L3 层，只是引用了已删方法 | 只删死引用，判定保留 | 7 |

R2 之所以只能追加而不能改写判定理由：守卫测试正是靠
`可达单元格（事件“…` / `断言型条款（事件“…` 这个前缀解析坐标的，
改写会让 115 个单元格解析不出来。逐行清单见 change-list。

### 守卫测试：删特判、改读表

- 删除 `assertS5Unreachable` 里按事件名写死的
  `case "用户点击“我已清空最近删除”": return`。
- 新增 `TransitionCell.isRetiredEvent`，取值来自判定理由中的 `事件已撤销` 标记；
  常量 `retiredEventMark` 单独登记，**日后任何事件撤销都走同一条通道，
  不必再改代码**——这正是卡要求的「改为读表判定」。
- 遍历时对已撤销事件 `continue`，不进入行为分派。

### 断言 1、2 结果

| # | 断言 | 测试函数名 / 证据 | 结果 |
|---|---|---|---|
| 1 | 守卫测试通过且不含任何「已删除」字样的特判 | `testAll115TransitionCellsAndEveryUnreachableCombination`；`grep 已删除 TransitionTableGuardTests.swift` 零命中；`grep 我已清空最近删除` 零命中 | **passed** ① |
| 2 | 矩阵中不再出现任何已删测试名 | `testIC138EveryTraceabilityMethodNameStillExists`（运行时断言）＋ 本机全表 grep 复核：改前 16 个缺失名 → 改后 **0** | **passed** ① |

计数断言（读表得出，非硬编码猜测）：单元格总数 **115 不变**、
已撤销事件 **5**、存续不可达 **59**、存续可达 **51**（59 + 51 + 5 = 115）。
不可达总数仍为 **63**（其中 4 个属已撤销事件），与强度表的 63 坐标口径一致。

---

## 子项 B：断言强度表同步（提交 `101b88f`）

四个不可达单元格 C5-106（原弱）、C5-108／109／110（原强）改列**已撤销**。
改「强」的理由是**旧依据已不成立**：那三条的判定依据原文是「调用 `handle`
清空确认事件，并断言当前状态拒绝且无副作用」，而该分支已随 IC-134 F 删除，
本卡又把残留的特判也删了——再挂「强」就是虚报。

结论表与完整性摘要同步：强 26 → **23**、弱 37 → **36**、新增**已撤销 4**，
**合计 63 不变**（矩阵的断言型条款一行未删，编号稳定）。
另把判定口径两条按行号引用守卫测试的说法改成按符号名引用——行号已随 A 移位，
且行号引用会被后续任何编辑悄悄作废。逐单元格表内的行号引用**保留原样**，
作为分级当时的证据快照。

### 断言 3 结果

**本表引用的 XCTest 方法名数量为 0**（全表 grep 实测：`\btest[A-Za-z0-9_]{3,}`
零命中；表内出现的 `TransitionTableGuardTests` 是**类名／文件名**，不是方法名）。
故断言 3 在本表侧没有对象，无需也无法写运行时断言。

卡给的是「写一条测试**或**脚本断言，二选一」，**我选测试**，落在矩阵侧：
`testIC138EveryTraceabilityMethodNameStillExists` 全文扫描
`TRACEABILITY-S3-S5.md`，凡以 `test` 开头的标识符 token 一律要求在测试包里
真实存在（覆盖正向矩阵、反向映射、未命中测试清单与散文引用）。

**为什么没有把断言也覆盖到强度表**：`TRACEABILITY-S3-S5.md` 已登记为测试包资源，
运行时可读；`GUARD-ASSERTION-STRENGTH.md` 没有登记，要让测试读到它必须改
`project.pbxproj`——**pbxproj 不在本卡白名单**。故本表侧以 grep 证据 + 上述
「引用数为 0」的事实交代，不越界加资源登记。

---

## 子项 C：S3 常量归并（提交 `e6aaa03`）

`pairSpacing`（= 4）迁入 `S3ActionBarMetrics` 并改名 `scanningPairSpacing`
（它的消费者是操作条扫描行的「转圈 ↔ 文案」间距，与体积明细无关），
空壳 `S3VolumeDetailMetrics` 删除；`volumeCornerRadius`（= 9，IC-134 引入起
零引用，角标底走 `Capsule()`）删除。

### 断言 4 结果

| # | 断言 | 证据 | 结果 |
|---|---|---|---|
| 4 | `S3View.swift` 不再含两个符号；既有 S3 断言原样通过、数值未变 | 全仓 grep `S3VolumeDetailMetrics|volumeCornerRadius` **零命中**（含注释——注释里也未写出旧名，免得日后按名 grep 时误报）；`IC134S3VisualTests` **14 项**、`IC133S3BehaviorTests` **9 项**、`S3StateMachineTests` **22 项** 全绿且项数与基线相同 | **passed** ① |

**数值零改动的 diff 证明**（G781 要求）：`S3View.swift` 的数值型 diff 只有三行——
`+ static let scanningPairSpacing: CGFloat = 4`（迁入）、
`- static let pairSpacing: CGFloat = 4`（迁出）、
`- static let volumeCornerRadius: CGFloat = 9`（删除，本就无人引用）。
4 进 4 出，渲染零改动。

---

## 子项 D：扫描器豁免文案（提交 `ae81a30`）

两条 Reason 原写「向下截断由规格锁定」，而 IC-136 B 之后 `< 1 MB` 已改为
一位小数四舍五入，文案与实现不符。改为写明三档口径并各自点名 formatter，
第二条另注明 S2 单张与 S3 合计是两套口径、互不影响。
**扫描逻辑一字未动**（四个 pattern、豁免匹配条件、目录一致性检查全部未改）。

### 断言 5 结果

| # | 断言 | 证据 | 结果 |
|---|---|---|---|
| 5 | 退出码 0 且豁免计数与改前相同 | 改前改后各跑一次（改前用 `git stash` 取回基线版本）：**豁免与边界条目 221 条 → 221 条**；`file:line` 集合 `diff` **逐条相同**；其中规格锁定两类共 **8 条**（`S3StateMachine.swift` 5 条 + `S2AssetVolumeFormatter.swift` 3 条）改前改后一致。两次退出码均 **0** | **passed** ① |

**BOM 与可解析性**（本机既有教训：含中文的 `.ps1` 必须带 BOM，否则 PS 5.1 按 GBK
读会乱码解析失败）：改后 `head -c 3` = `ef bb bf`，BOM 在位；
`[Parser]::ParseFile` 返回 **PARSE OK**，零语法错误。

---

## CI 预算与那次红（#268）

**卡给 2 次预算，用满 2 次。第 1 次红，红的是本卡新增的断言自身。**

### 现象

`Executed 677 tests, with 1 failure`，退出码 65，唯一失败是
`testIC138EveryTraceabilityMethodNameStillExists` 第 99 行的差集断言，
`missing` 里几乎是全部被引用的方法名——**包括同一个类里那条主测试的名字**。

### 根因（①，本机复核确认）

Swift 的 `func testFoo() throws` 暴露给 ObjC 运行时的选择子是
**`testFooAndReturnError:`**（`async` 则是 `…WithCompletionHandler:`）。
我用 `class_copyMethodList` 枚举选择子后直接当 Swift 方法名用，
带后缀的名字自然一个都对不上。本机实测：矩阵引用的 **168 个方法里 108 个是
`throws`**，与「差集整片飘红」的现象吻合。

### 为什么两条下界断言没拦住

我原本写了 `referenced.count > 100` 与 `registered.count > 100` 两条防空转断言，
它们**都通过了**——枚举确实拿到了 100+ 个名字，只是**名字形态错了**。
下界断言只能防「集合为空」，防不了「集合非空但整体错位」。

### 修复（提交 `113384a`）

1. 选择子按 `:` 截断，再剥掉 `AndReturnError` / `WithCompletionHandler` 后缀；
2. **补一条自校验**：一个已知的 `throws` 方法
   （`testAll115TransitionCellsAndEveryUnreachableCombination`）必须以 **Swift 名**
   出现在枚举结果里。这条才是真正能拦住 #268 的断言——还原逻辑一旦失效，
   它当场变红，而不是让差集断言给出一份看起来像「矩阵全错」的假结论。

### 推第 2 次之前做的本机预演

用 Python 复刻两个集合的构造口径（测试源码里的 `func test…` 声明 vs 矩阵全文
token 扫描）：`referenced = 168`、`registered = 678`、自校验名存在、
`missing = 0`，**预测 PASS**。#269 实测与预测一致。

---

## 闸门逐条结论

### G781（diff 限于白名单；产品源码只有 S3 常量归并）：**通过** ①

`f8ae50a..6b1adea` 共 **5 个文件**，逐个对照白名单：

| 文件 | 白名单条目 | 落点核对 |
|---|---|---|
| `Reports/TRACEABILITY-S3-S5.md` | A（只改与 L3 撤销相关的行） | 30 行条款行 + 16 行反向映射 + 5 条清单行 + 汇总，逐行列在 change-list |
| `Reports/GUARD-ASSERTION-STRENGTH.md` | B（同上） | 4 行分类 + 两张统计表 + 两条口径说明 |
| `PhotoCleanupMVETests/TransitionTableGuardTests.swift` | A（硬计数重算、删特判） | 计数改读表、删特判、加断言 |
| `PhotoCleanupMVE/Features/S3/S3View.swift` | C（常量归并，不改数值） | 三行数值 diff，见断言 4 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | D（仅两条 Reason） | diff 恰为 2 行改 2 行 |

**产品源码只有 `S3View.swift`**，且只是常量搬家 + 删死常量。
`project.pbxproj` 未改（本卡未新增文件）。

### G782（`schemaVersion`；S1／S2／S4／S5 产品零改动；冻结三链）：**通过** ①

- diff 文件集合中**无任何** `Features/S1`／`Features/S2`／`Features/S4`／
  `Features/S5`／`Core/` 路径（实测 grep 命中 0）
- `S2Calibration.swift` 不在 diff 中，`schemaVersion` 仍为 **7**（:118）
- 冻结三链与探针分支（本卡前后两次实测未变）：
  `feature/ic-089-nx-edge-bounce` `b368a6c`、
  `feature/ic-091-nx-midgesture-handoff` `6736f1e`、
  `feature/ic-092-nx-window-follow` `a7cc1ec`、
  `probe/ic-067-screenshot-subtype` `9db02b9`、
  `probe/ic-125-sentinel-negative` `402cb6e`、
  `probe/ic-137-media-playback` `486bcb7`（IC-137 探针，本卡未触碰）

### G783（绿 + 五条断言逐条落实）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#269**（run id `34216125904`，attempt 1） |
| 被测提交 | `113384a709f143dceba905710e7c0a9156ba322e` |
| 触发 | `push`，分支 `feature/ic-138-housekeeping` |
| job | `102028162514`，conclusion=**success**，10 个 step 全 success |
| XCTest | **Executed 677 tests, with 0 failures (0 unexpected) in 61.346 (76.501) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 摘要 notice | 在位（IC-125 哨兵通过，677 > 0）；`##[error]` 0 条、`##[warning]` 0 条 |
| 真实退出码 | **0**（全日志无「Process completed with exit code」非零行） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| IPA | **1272446 字节**，SHA-256 `cf97d41dc4bce2965b09da1580d5bfcc7c641d5dfbd594b27413e7c66d22c90e` |

**五条断言 → 函数名／脚本名**：

| 断言 | 落实方式 | 结果 |
|---|---|---|
| 1 守卫通过且无「已删除」特判 | `testAll115TransitionCellsAndEveryUnreachableCombination` + 源码 grep 零命中 | ✓ |
| 2 矩阵无已删测试名 | `testIC138EveryTraceabilityMethodNameStillExists` + 全表 grep（16 → 0） | ✓ |
| 3 文档引用的测试名都能 grep 到 | 同上（**选「测试」一项**）；强度表侧引用数为 0，见子项 B | ✓ |
| 4 S3 两符号消失、既有断言原样过 | 全仓 grep 零命中；`IC134S3VisualTests` 14 / `IC133S3BehaviorTests` 9 / `S3StateMachineTests` 22 项数与基线相同且全绿 | ✓ |
| 5 扫描器退出码 0 且豁免计数不变 | `Scripts/scan-hardcoded-user-visible-strings.ps1`：221 → 221，`file:line` 集合逐条相同，两次退出码 0 | ✓ |

**项数对账**：基线 676 → **677**，差 **+1**，即本卡新增的一条断言，
既有用例零增删；`TransitionTableGuardTests` 单套由 1 项增至 2 项。

### G784（合并前置）：**通过** ①

- G781～G783 全满足；工作树净；`git fetch` 后 `origin/main` 仍为 `f8ae50a`
- `git merge --no-ff`，输出 `Merge made by the 'ort' strategy.`，**零冲突**
- 合并提交 **`6b1adea`** / `6b1adeadf371e17fe7805f95928dfba2d0fbaefa`
  - parent1 `f8ae50af039e5b890be75a76cbe040db0bc422a6`（原 `main`）
  - parent2 `113384a709f143dceba905710e7c0a9156ba322e`（分支 tip）
  - 合并树对象 `a66ef08be3f7f57d9744b58fe02720f69d2bc622` 与分支 tip 树对象**相同**，
    `git diff` 为空——合并未引入任何自身内容
- 推送：退出码 0，报文 **`f8ae50a..6b1adea  main -> main`**（两点记法，非强推）
- 未 rebase、未 amend、未强推：`git reflog main` 顶部为 merge 条目，
  其下 `f8ae50a` 原样保留

### G785（合并后 `main` 自动运行）：**通过（绿）** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#270**（run id `34217330343`，attempt 1） |
| 被测提交 | `6b1adeadf371e17fe7805f95928dfba2d0fbaefa`（合并提交） |
| 触发 | `push`，分支 `main` |
| job | `102032074353`，conclusion=**success**，10:47:59Z→10:55:23Z，10 个 step 全 success |
| XCTest | **Executed 677 tests, with 0 failures (0 unexpected) in 26.938 (34.005) seconds** |
| 摘要 notice | 在位；真实退出码 **0** |
| IPA | **1272446 字节**，SHA-256 `c32ba352f4b673654f3faae2d883f674f1654da8941658a801362c52fc9e60c9` |
| 产物 | `PhotoCleanupMVE-unsigned-6b1adeadf371`，zip 1272616 字节 |

IPA 字节数与 #269 完全相同（同为 1272446），SHA-256 不同——与「IPA 归档不可复现」
的既往实证一致，同时反向印证合并未改变任何产品代码。

---

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | 在合并后的 `main` 上跑；结构、工程配置、String Catalog、目录一致性与测试数量门禁全过 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0；豁免条目 221 条与改前逐条相同 |
| `git diff --check`（工作树） | **0** | — |
| `git diff --check f8ae50a..6b1adea` | **0** | 合并范围内无空白错误 |

---

## 卡内前提与实测的出入（纪律第 3 条：不硬套、不凑逻辑）

### 一、已删测试名卡列 12 个，实为 16 个（①）

卡已预留「**以你全表 grep 为准**，可能不止这些」。全表 grep 实得 16 个，
卡未列出的 4 个是：

- `testC5_039CompletedReadingsSurviveTerminationAndRestoreWithoutNewRead`
- `testC5_069FailureNeverReadsFreeDiskOrDisplaysL3`
- `testC5_086UnknownCannotReadConfirmOrWriteBackManualResult`
- `testC5_144SuccessExitClearsPersistedL3Session`

四个都在 `CoverageGapTests.swift`，随 IC-134 F 一并删除。

### 二、「我已清空最近删除」事件是 5 个单元格，不是 4 个（①）

卡写「4 个单元格」。矩阵实有 **5** 个：C5-106（外部源）、**C5-107（S5-T0）**、
C5-108（S5-C）、C5-109（S5-F）、C5-110（S5-U）。
其中 **C5-107 标的是「可达单元格」**，因此不在断言强度表的 63 个不可达坐标里
——卡的「4 个」应是照着强度表的口径数的。

C5-107 同样必须处置：事件在类型层面已不存在，它既不可达也无法断言，
且它引用的 `testConfirmationReadsCompletionExactlyOnceAndPersistsDelta` 已删。
故 5 个一并标「事件已撤销」，守卫测试的已撤销计数按 **5** 钉。

### 三、受影响的行不止「L3 条款行」一类（①）

卡的处置只描述了「条款随 L3 撤销」这一类。全表 grep 后另有 **10 行**：
3 行条款属 L3 层但存续方法仍覆盖其存续半句（R3），
7 行条款根本不属 L3 层、只是顺带引用了已删方法（R4）。
这两组我**只删死引用、判定原样保留**，没有替决策会话重判覆盖状态——
判定变更属规格事项。逐行清单见 change-list，请核。

---

## 人工判定项

**无**（卡内明确）。

---

## 发现但未处理的问题（按纪律只报告不修）

1. **R4 五行条款的「不新增磁盘读取」半句已落空**（①）。
   C5-037、C5-038、C5-039、C5-122、C5-127 的条款原文都含
   「留在 `S5-T0`，**不新增磁盘读取**」，而 `FreeDiskSpaceReader` 随 IC-134 F 删除，
   该半句现在恒真且无可断言。我只删了死引用、判定保留「已覆盖」
   （存续方法确实覆盖了「留在 S5-T0」那半句）。**该半句是否随 L3 一并作废，
   属 SPEC-S5 v6 的事**，请决策会话在 v6 晋级时一并裁定。
2. **两个历史自验脚本会因本卡改动而失效**（①，均**未接入任何门禁**）。
   `Scripts/verify-IC-20260812-019.ps1:189` 把
   `TRACEABILITY-S3-S5.md` 的 SHA-256 钉成固定值；
   `Scripts/verify-IC-20260812-024.ps1:221` 断言「不得修改追踪矩阵」。
   实测 `selfcheck.ps1` 只检查 `verify-IC-20260812-010.ps1` 是否**存在**、并不运行它，
   `ci.yml` 与 `test-xcode.sh` 也都不调用这些脚本，故本卡不会因此变红。
   这两条在 IC-045 改矩阵时就已经失效，属既有欠账，**不在本卡白名单**，未动。
3. **未命中测试清单已落后两条**（①）。第七节列 8 条，其中
   `VolumeFormattingTests.swift` 的行号仍是 IC-021 时的快照；
   IC-136 B 给该文件新增的两条测试未进清单。
   该清单按其自身约定是「分级当时的快照」，且卡的授权范围是「只改与 L3 撤销
   相关的行」，故未动。
4. **`GUARD-ASSERTION-STRENGTH.md` 无法被运行时断言覆盖**（①）。
   它没有登记为测试包资源，测试在模拟器沙盒里读不到；要覆盖必须改
   `project.pbxproj`，**不在本卡白名单**。当前它引用的测试方法名数量为 0，
   风险为零；但若日后往里写方法名，就会重现本卡刚修掉的那类腐烂。
   建议阶段性把它一并登记为测试资源，或在断言里连同一起扫。
5. **矩阵表头「XCTest 方法总数」与实际测试总数不是一回事**（①）。
   该字段统计的是反向映射的行数（本卡后 168），而测试包实际有 677 项——
   矩阵只覆盖 S3／S4／S5 相关测试。字段名容易被误读为全量，
   但改名会动到卡外的表头，未动。
6. **`CLAUDE.md` 第七节的「当前阶段」仍落后仓库多张卡**（①）。
   文中 `main` 写的是 IC-130 的 `0bf5ebda`，而实际 `main` 已推进到 `6b1adea`。
   `<top>/Tasks/` 下已有 `update-claude-ic135.ps1`、`update-claude-ic136.ps1`
   两个待执行脚本。执行端无权改该文件，仅登记。
