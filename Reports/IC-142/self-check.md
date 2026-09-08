# IC-142 自验报告

> 报告提交方式说明（执行纪律第 7 条）：本卡含合并授权，报告需引用推送后才产生的
> CI 运行编号、IPA 校验与合并 SHA，故采用「同一张卡、同一分支内追加一个 docs 提交」
> 的方式，随合并一并留在 `main` 上，不跨卡回填。

## 结论（先行）

**IC-139 子项 C 已完整撤销，CI 一次通过，已合并入 `main`。**
这是**改判**不是 IC-139 不合格（惯例 20）——决策 57 由 ④ Lynn 在 H63a 第 2 项
真机判定后作废，理由是「切换隐藏模式时主图会往下跳动」。

- 基线：`main` = `1abecae3ef5b54fa93b3103207a4f376d43dda1e`
  （标题以 `docs: IC-139` 开头；`fd7c983` 是其祖先——`git merge-base --is-ancestor` 为真）
- 分支 `feature/ic-142-revert-video-page-fit`，代码 tip `f69db075acd24250bce520375bca8311e3318ca8`
- CI **#273** 一次绿：XCTest **690 项 0 失败**（= 694 − 5 + 1，与卡内预测逐字相符），
  真实退出码 0，摘要 notice 在位，目的地 `OS:26.2, name:iPhone 16`；**预算 2 次用 1 次**
- 合并提交 **`b19f155`** / `b19f1553ec28842301a318a7bfbf905f81084d01`，零冲突
- **G805**：合并后 `main` 自动运行 **#274** 同为 690 项 0 失败
- G801 ✓ G802 ✓ G803 ✓ G804 ✓ G805 ✓
- 人工判定项：H64a 两项，原样留给 Lynn

**几件值得记的事：**

1. **撤销是逐字回到基线，不是「大致还原」**。三处赋值改后与 IC-139 之前的
   `db318fc` **逐字相同**，且新断言用的正是那个基线的计数（2 + 1）作正对照。
2. **只断言「符号消失」会漏掉一类错误**：把赋值一并误删也能让符号归零。
   故断言两侧一起钉——撤销侧钉三个符号在产品源码全目录归零，
   正对照侧钉三处赋值恰为 2 + 1（惯例 17）。
3. **A／B／D 一行未改**，`S2View.swift` 的 6 个 hunk 逐条对上卡内点名的处 1～6，
   没有第 7 个。浮框的两个常量另有断言守住，防止日后清理时被连坐。
4. **一个计数口径的坑**：本机 `grep -rh "func test[A-Za-z0-9_]*(" PhotoCleanupMVETests/ | wc -l`
   得 **691**，比 CI 的 690 多一个。第 691 个不是测试，是 IC-138 我自己写在
   `TransitionTableGuardTests.swift:125` 的**注释**——那行为了解释 `AndReturnError:`
   后缀，在文档注释里写出了 `func testFoo() throws` 的样子。
   **本机这条 grep 从此不可当项数用**，已登记。

---

## 撤销范围（卡内处 1～6 逐条）

| 处 | 位置 | 处置 | hunk |
|---|---|---|---|
| 1 | `pageContent` 内 `mediaFit` 与两个局部量（含 5 行注释） | 整段删除（14 行） | `@@ -941,14 +940,0 @@` |
| 2 | `S2ImageContentContext(fittedSize:)` | 回退 `pageMetrics.oneXDisplaySize` | `@@ -961 +947 @@` |
| 3 | `S2NativePageContent` 的 `fittedSize` / `fittedCenterY` | 两行回退 | `@@ -1027,2 +1013,2 @@` |
| 4 | `S2MediaMetrics` 内 MARK 与 `videoPageFitBottomInset` | 整体删除（7 行） | `@@ -2728,7 +2713,0 @@` |
| 5 | `struct S2MediaPageFit` | 整体删除（6 行） | `@@ -2806,6 +2784,0 @@` |
| 6 | `enum S2MediaPageGeometry` | 整体删除（29 行） | `@@ -2841,29 +2813,0 @@` |

`S2View.swift` 共 **6 个 hunk**，与上表一一对应，**没有第 7 个**——
即胶囊（A）、浮框（B）、长按分派（D）的构造件与常量一行未改。

开工前按卡内要求核对过基线原文：
`git show db318fc:…/S2View.swift | grep -n "pageMetrics.oneXDisplaySize\|pageMetrics.oneXDisplayCenterY"`
得 937、1003（`oneXDisplaySize`）与 1004（`oneXDisplayCenterY`），即 **2 + 1**，
与本卡改后的计数一致。

---

## 断言 1 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 1 | 撤销钉住 + 正对照 | `testIC142_VideoPageSharesPhotoPageGeometryInBothVisibilityStates` | **passed** ①（CI #273 日志 `passed` 行实证） |

断言内容三段：

1. **正对照**：`S2View.swift` 内 `fittedSize: pageMetrics.oneXDisplaySize` 恰 **2** 次、
   `fittedCenterY: pageMetrics.oneXDisplayCenterY` 恰 **1** 次——与 `db318fc` 相同。
2. **撤销**：`S2MediaPageGeometry`、`videoPageFit(`、`videoPageFitBottomInset`
   三个串在**四个产品源码文件**（`S2View.swift`、`S2NativePhotoPager.swift`、
   `PhotoCleanupMVEApp.swift`、`CleanupCoordinator.swift`）各为 **0** 次。
   名字在测试里**拼接构造**，避免断言抓到自己。
3. **保留**：`S2MediaMetrics.videoBarHeight == 44`、
   `videoBarBottomToStripTop == S2OverlayLayout.stripToBottomRowSpacing`——
   浮框本身没撤，只撤几何；这两条防止后续清理把浮框常量当作 C 的残留一起删掉。

扫描方式照该文件既有 `sourceText(_:)` helper（`#filePath` 上溯两级取仓库根），
与 IC-136／IC-139 的源码扫描断言同一套。

**夹具边界（如实标注）**：这是**源码扫描断言**，证明的是代码里不再有那套几何；
**不证明**真机上主图不再跳动。后者是 H64a 第 1 项，留给 Lynn。

---

## 删除清单

### 5 条 C 类测试（CI 日志中零出现，逐个核实）

| 函数名 | 删除理由 |
|---|---|
| `testIC139C_VideoPageFitInsetIsDerivedNotIndependent` | 被断言对象已删 |
| `testIC139C_VisibleVideoPageRenderFrameLiftsBottomEdgeBy68` | 上移行为已撤 |
| `testIC139C_WidthBoundVideoPageRecentersInsideShortenedRegion` | 同上 |
| `testIC139C_HiddenVideoPageGeometryMatchesPhotoPage` | 撤销后成为恒真式（卡内点名不留） |
| `testIC139C_PhotoAndLivePagesKeepBaselineGeometry` | 同上 |

后两条值得说明：撤销后视频页与照片页走的本来就是同一行代码，
断言「两者相等」不再有信息量——它恒真，且恒真的断言会给人虚假的安全感。
卡内点名不留，我照办。

### 7 个随之无消费者的夹具与常量

`renderedOneXFrame`、`baselineOneXFrame`、`renderedFrame`、`baselineMetrics`、
`viewport`、`heightBoundRatio`、`widthBoundRatio`。

每个删除前都做过引用计数、确认归零才删；删后再次核验全部为 0
（这也是卡内提示的编译红高发点——夹具残留无消费者会告警）。
`sourceText(_:)` 与 `mediaMetricsBlock(in:)` **保留**：A／B／D 与新断言仍在用。

---

## 闸门逐条结论

### G801（diff 限于白名单；分页器不变；A／B／D 零改动）：**通过** ①

`1abecae..b19f155` 共 **2 个文件**，正是白名单两文件：

| 文件 | +/− |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | +5 −57 |
| `PhotoCleanupMVETests/IC139MediaBadgesTests.swift` | +56 −187 |

- **`S2NativePhotoPager.swift` 两侧 SHA-256 相同**：
  `1abecae` 侧与 `b19f155` 侧同为
  `344cfcd525ad58d7ff3e80c923c37621d08833b9122116695305cb95caeb54c4`
- `S2Calibration.swift` **不在 diff 中**；`schemaVersion` 仍 **7**（:118）
- `project.pbxproj` **不在 diff 中**（无新文件）
- `Localizable.xcstrings` **不在 diff 中**（无文案变化，目录仍 210 键）
- A／B／D 构造件零改动：6 个 hunk 全部落在处 1～6，见上表；
  `S2LivePillPresentation`／`S2VideoBarPresentation`／`videoBarHeight`／
  `videoBarBottomToStripTop`／`S2MainPhotoLongPressAction`／
  `S2LivePhotoLongPressRecorder` 在 `S2View.swift` 内出现次数分别为
  5／5／3／2／4／2，与本卡前相同

### G802（绿 + 690 项 + 断言 1）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#273**（run id `34238005445`，attempt 1） |
| 被测提交 | `f69db075acd24250bce520375bca8311e3318ca8` |
| 触发 | `push`，分支 `feature/ic-142-revert-video-page-fit` |
| job | `102100631325`，conclusion=**success**，14:24:10Z→14:31:23Z，10 个 step 全 success |
| XCTest | **Executed 690 tests, with 0 failures (0 unexpected) in 39.476 (103.754) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 摘要 notice | 在位（IC-125 哨兵通过，690 > 0）；`##[error]` 0 条、`##[warning]` 0 条 |
| 真实退出码 | **0**（全日志无「Process completed with exit code」非零行） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| IPA | **1304616 字节**，SHA-256 `f143d9d98862a884620c4f6be549dd9d1d6c767e992281727f765d3d56632ca9` |
| 产物 | `PhotoCleanupMVE-unsigned-f69db075acd2`，zip 1304786 字节 |
| 断言 1 | `testIC142_VideoPageSharesPhotoPageGeometryInBothVisibilityStates` 的 `passed` 行在位 |

**项数对账**：694 − 5 + 1 = **690**，与 CI 读数逐字相符；
`IC139MediaBadgesTests` 单套 17 → **13**（日志实证）。

### G803（本地门禁）：**通过** ①

| 门禁 | 退出码 |
|---|---|
| `git diff --check`（工作树） | **0** |
| `git diff --check 1abecae..b19f155` | **0** |
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** |

### G804（合并前置）：**通过** ①

- G801～G803 全满足；工作树净；`git fetch` 后 `origin/main` 仍为 `1abecae`
- `git merge --no-ff`，输出 `Merge made by the 'ort' strategy.`，**零冲突**
- 合并提交 **`b19f155`** / `b19f1553ec28842301a318a7bfbf905f81084d01`
  - parent1 `1abecae3ef5b54fa93b3103207a4f376d43dda1e`（原 `main`）
  - parent2 `f69db075acd24250bce520375bca8311e3318ca8`（分支 tip）
  - 合并树对象 `751db4523b5be05f220b00cc86934ae51faebcdc` 与分支 tip 树对象**相同**
- 推送：退出码 0，报文 **`1abecae..b19f155  main -> main`**（两点记法，非强推）
- 未 rebase、未 amend、未强推：`git reflog main` 顶部为 merge 条目，
  其下 `1abecae` 原样保留

### G805（合并后 `main` 自动运行）：**通过（绿）** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#274**（run id `34239807239`，attempt 1） |
| 被测提交 | `b19f1553ec28842301a318a7bfbf905f81084d01`（合并提交） |
| 触发 | `push`，分支 `main` |
| job | `102106761494`，conclusion=**success**，14:40:51Z→14:48:09Z，10 个 step 全 success |
| XCTest | **Executed 690 tests, with 0 failures (0 unexpected) in 71.067 (144.308) seconds** |
| 摘要 notice | 在位；真实退出码 **0** |
| IPA | **1304616 字节**，SHA-256 `be3bc1839de837faa3d1139776857a902f236df0b001e430bbf0e2a6b342cd88` |
| 产物 | `PhotoCleanupMVE-unsigned-b19f1553ec28`，zip 1304786 字节 |

IPA 字节数与 #273 完全相同（同为 1304616），SHA-256 不同——与「IPA 归档不可复现」
的既往实证一致，同时反向印证合并未改变任何产品代码。

---

## 人工判定项（H64a，留给 Lynn 合并后真机，**执行端不代为下结论**）

1. 视频页单击切换隐藏／显示，主图**不再上下跳动**；显示态浮框压在主图下缘之上
   （与横栏压主图同理）。
2. 照片页、实况页两态摆放与 IC-139 前相同（对照 H63a 第 1、3 项通过时的观感）。

**装机包**：CI #273 产物 `PhotoCleanupMVE-unsigned-f69db075acd2`
（IPA 1304616 字节，SHA-256 见 G802 表）；合并后 `main` 的产物见 G805 节。

---

## 发现但未处理的问题（按纪律只报告不修）

1. **本机的测试项数 grep 会多算一个**（①，本卡实测）。
   `grep -rh "func test[A-Za-z0-9_]*(" PhotoCleanupMVETests/ | wc -l` 得 691，
   而 CI 实跑 690。多出来的那个是 IC-138 我自己写在
   `TransitionTableGuardTests.swift:125` 的文档注释——为解释
   `throws` 方法的 ObjC 选择子后缀，注释里写出了 `func testFoo() throws` 的样子。
   **该注释无害且有用，不改**；但本机这条 grep 从此不能当项数用，
   项数一律以 CI 的「XCTest 执行摘要」为准。已在此登记，免得下一张卡再被绊一次。
2. **`videoBarTimeFontSize` 仍是登记未使用的常量**（①，IC-139 已登记，本卡未处置）。
   卡内取值表注明 IC-141 用。本卡是撤销 C，未触及 B 的常量，故照旧保留。
   若 IC-141 最终不用它，届时应一并清理。
3. **v19 决策 57 已作废但规格文本未改**（①）。
   `<top>/SPEC-S2-20260908_v19.md` 第 155 行仍写「视频页几何（2026-09-08）：
   `m=视频` 且 `V=显示` 时，主图适配区下缘上移 68」，第 382、498 行的显示元素清单
   亦沿用该表述。SPEC 与 Decision_log 均在本卡范围外、也不在白名单，故未动。
   **代码与规格现在不一致**，请决策会话在 v20（或 v19 修订）里落文，
   否则下一个读规格的人会照 155 行重新实装一遍。
4. **`CLAUDE.md` 第七节仍落后仓库多张卡**（①）。文中 `main` 写 IC-130 的
   `0bf5ebda`、规格基线行写 v18；实际 `main` 已到 `b19f155`、规格已出 v19。
   `<top>/Tasks/` 下 `update-claude-ic135.ps1`、`update-claude-ic136.ps1`
   两个脚本仍待执行，现还要再加 IC-137／138／139／142 四笔。
   执行端无权改该文件，仅登记。
