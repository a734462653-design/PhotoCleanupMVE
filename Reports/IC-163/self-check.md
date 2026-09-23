# IC-163 自验报告（「卡片叠」首页与新类别页 · 真机预览第二轮，探针分支不合并）

## 一、结论（先行）

卡内四个子项全部实装，按 A → D → B → C 顺序各自独立 commit，落在 `probe/ic-163-deck-home-preview-r2` 上。**分支不合并进 `main`**。CI 一次绿（预算 3 次用 1 次）：**#327**（`0b3dd0321ff8e347519b5572943587810de3aac8`）**865 项 0 失败、真实退出码 0、IPA 已上传**，artifact **`PhotoCleanupMVE-unsigned-0b3dd0321ff8`**（id **`10733187205`**，有效期至 **2026-12-22T04:54:56Z**）。

- **子项 A（S2 写回不抹类别篮，裁定 一）**：`SessionStore.applyS2Return` 改为「写回前集合 − 交接列表 ∪ 返回集」；`applyPendingDeletionDiff` 加 `scope`，取消标记只落在交接列表内。真实范围行为逐位不变。三条测试全过。**克隆里单独 cherry-pick 到 `main` 无冲突**。
- **子项 D（「视频」类取代「大视频」，裁定 五）**：删门槛常量；`hits` 里视频与录屏改互斥；目录值 `大视频` → `视频`。IC153／IC155 两份测试只改期望值、字面量与注释，函数数不变。**克隆里单独 cherry-pick 到 `main` 无冲突，A→D 连续也无冲突**。
- **子项 B（首页两修一删，裁定 二、三）**：封面与卡的命中区收回框内；展开卡内容层加淡入上浮、收起条加淡入淡出；「建议先清」角标整套删除。
- **子项 C（类别页三改，裁定 三、四）**：「最大的 N 个」「其余 M 个」两节删除；四处玻璃改走 S1 系统玻璃 helper；排序钮（系统 `Menu` 三项）+ 新文件 `S0DeckAssetDates` + 按月分节。
- **闸门**：G916～G920 全部通过（第三节）。
- **根因假设**：bug 4（S3 空白）的机制在 CI 上以夹具证实为「修后篮内项保留」；bug 1／2（展开卡打不开、总条段不切）的命中区归因与「勾选不见了」的同源推测，**模拟器都验不了**，标「未覆盖」，留给 H82 第 1、7 条（第四节）。
- **本报告不代 Lynn 判定任何观感项**：H82 九条原样列在第九节。

> 报告提交方式（纪律 7）：本报告引用的 CI 数据来自推送后才产生的 #327，故采用「同一张卡、同一分支追加一个 docs 提交」的方式；该提交只含 `Reports/IC-163/` 两个文件，按 `paths-ignore` 不触发 CI，不为它追加 CI 闭环。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260922-163-deck-home-preview-r2.md` |
| 继承提交 | `probe/ic-162-deck-home-preview` = `180b052edf24f168712c6e58754c60b88b342175`（本机与 `origin` `git ls-remote` 一致）；`main` = `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a`（同上） |
| 目标分支 | `probe/ic-163-deck-home-preview-r2`（从 `180b052` 切，**不合并**；推送前远端无此分支） |
| 范围边界 | 白名单 16 个路径（逐条见 `change-list.md` 第二节）；`S0CleanupFlowView.swift`／`S0View.swift`／`S0CategoryPageView.swift`／`S0CleanupFlowModel.swift`／`App/`／`Services/` 除 D 两个文件外／`Features/S1`～`S5`／`ThumbnailView.swift`／白名单外的全部既有测试文件／`.github/`／`Scripts/` 一字未动 |
| 开工四步 | `git status --porcelain` 空（退出码 0）→ `git merge-base --is-ancestor main probe/ic-162-deck-home-preview` 退出码 0 → `git ls-remote origin` 两个分支都与本机一致、`probe/ic-163-…` 远端不存在 → **先切分支再改文件**（`git switch -c probe/ic-163-deck-home-preview-r2 180b052…`，确认 `git branch --show-current` 后才动第一个文件） |

## 三、逐条验收门禁

### G916：`S1StateMachine.swift` 四条计数、`Core/` 只动两个文件、A 可摘到 `main`

口径同 `IC157LongPressIntoS2Tests` 断言 3 的 `strippedSource`（剔 `//` 注释与字符串内容后计数）；本机用 Python 逐字符移植后跑出下表，CI 上由 `testIC157A_RealRangePathsByteIdentical` 自己再验一次（#327 passed）。

| needle | 卡面 | 实测 | 判定 |
|---|---|---|---|
| `publishSnapshotIfChanged()` | 6 | 6 | OK |
| `setMarked(` | 3 | 3 | OK |
| `applyPendingDeletionDiff(` | 3 | 3 | OK |
| `private func applyPendingDeletionDiff(` | 1 | 1 | OK |
| `makeS2Handoff(for:)` 函数体 35 行与 `main` 逐字相同 | — | 相同（`git diff main -- Core/S1StateMachine.swift` 只落在 `applyPendingDeletionDiff` 的签名、文档注释、取消循环与两处调用实参；IC157 断言 3 的逐字比对 passed） | OK |

`git diff --stat main -- PhotoCleanupMVE/Core/`：`S1StateMachine.swift` +9／−4、`SessionStore.swift` +3／−1，**只两个文件、变更行 17 ≤ 30**。克隆 cherry-pick 实证见第七节（A 单独退出码 0）。

### G917：白名单外零改动

`git diff --stat 180b052..0b3dd03` 只含 16 个白名单路径（逐条对应见 `change-list.md` 第二节）；docs 提交另加 `Reports/IC-163/` 两个文件。

| 文件 | `180b052` 侧 blob | 当前 blob | 判定 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | `f1d49b69bf8d019578a92e5204c4714c08cf6dfa` | `f1d49b69bf8d019578a92e5204c4714c08cf6dfa` | 同 |
| `PhotoCleanupMVE/Features/S0/S0View.swift` | `9eeb8168bd6397c31717747bd1686011cd157b14` | `9eeb8168bd6397c31717747bd1686011cd157b14` | 同 |
| `PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift` | `a32f4e5fe8fe0fcf1ed21e36bd587e760215e7a0` | `a32f4e5fe8fe0fcf1ed21e36bd587e760215e7a0` | 同 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `3d9fe61c5ad1d5be0f9e7f53baf58e3f02d45135` | `3d9fe61c5ad1d5be0f9e7f53baf58e3f02d45135` | 同 |

`S0CleanupFlowView.swift` 零改动，IC-162 的 G912 计数自然保持（`IC156`／`IC157`／`IC160` 三族在 #327 全过）。

### G918：新建与改动的 Deck 产品源文件的扫描纪律

口径与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 一致——**对原始行计数，不剔注释**。

| 文件 | `return "` | `Text("` | `Button("` | `Label("` | `accessibilityLabel("` | 含汉字字面量（含注释） | `import Photos` | `Material` | `ultraThin` |
|---|---|---|---|---|---|---|---|---|---|
| `S0DeckAssetDates.swift`（新） | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 |
| `S0DeckCategoryPageView.swift` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `S0DeckCoverView.swift` | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 |
| `S0DeckHomeModel.swift` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `S0DeckHomeView.swift` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `S0DeckMetrics.swift` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

`import Photos` 只在 `S0DeckCoverView.swift` 与 `S0DeckAssetDates.swift`；玻璃全经 S1 helper（Deck 文件里 `Material`／`ultraThin`／`glassEffect` 皆 0）。

| 必须为 0 的符号 | 产品源码 | 目录 |
|---|---|---|
| `S0DeckGlassPanel` | 0 | 0 |
| `glassFill` | 0 | 0 |
| `dockFill` | 0 | 0 |
| `topSectionLimit` | 0 | 0 |
| `topSum` | 0 | 0 |
| `sections(` | 0 | 0 |
| `deck.home.suggest` | 0 | 0 |
| `deck.page.top` | 0 | 0 |
| `deck.page.rest.title` | 0 | 0 |

| 项 | 值 |
|---|---|
| 目录 `deck.` 前缀 key | **11**：`deck.home.bar.caption`／`hero.label`／`open.action`／`open.subtitle`／`released`／`share`、`deck.page.month.count`／`selected`／`sort.size`／`submit`／`undated`，每条都有 `L10n.text` 字面量引用（按扫描器同一条正则 `L10n\.text\(\s*"([^"]+)"` 核对，多行调用计入） |
| 目录 `s0.` 前缀 key | **38**（未动） |
| 目录条目合计 | 265（A、D 后）→ 264（B、C 后）；扫描器每次都报「目录条目 = 产品源码引用 key」 |

### G919：CI

见第五节：#327 一次绿，**865 项 0 失败**，真实退出码 0，IPA 已上传，artifact 名称、id、有效期已写明。

### G920（子项 D）

| 项 | 结果 |
|---|---|
| `bigVideoMinimumByteCount` 在 `PhotoCleanupMVE/` 与 `PhotoCleanupMVETests/` | **0 处**（仅 `Reports/IC-153/` 两份历史报告里各有 2 处文字提及，属存档，未动） |
| `attributionPriority` 与 `main` 逐字相同 | 相同（`[.bigVideo, .screenRecording, .screenshot]`，逐行 diff 为空） |
| 分类器 `hits` 视频段 | `if evidence.filenamePrefixMatched \|\| evidence.resolutionMatched { hits.insert(.screenRecording) } else { hits.insert(.bigVideo) }`——if／else 互斥 |
| 目录 `s0.category.bigVideo` | 值 `视频`；`s0.` 仍 38 |
| `cacheSchemaVersion` | 仍 **1** |
| `git diff main -- PhotoCleanupMVE/Services/` | 只含 `S0ScanRules.swift`（+1／−6）与 `S0ScanClassifier.swift`（+2／−2），变更行 10 ≤ 20 |
| 两份测试的 `func test` 数 | `IC153ScanServiceTests` 13 → 13；`IC155CategoryDataAndCoverTests` 9 → 9（diff 里无一行增删 `func test`） |
| cherry-pick D 到 `main` | 无冲突（第七节） |

## 四、根因假设：确认或推翻

| 卡面假设 | 等级 | 本卡能拿到的证据 | 结论 |
|---|---|---|---|
| bug 4「类别页进篮 → 长按进 S2 → 点垃圾桶 → S3 空白」= S2 写回整个覆盖该虚拟范围的标记集 | ①（卡面） | 源码逐行读到旧赋值即整个覆盖（`SessionStore.swift` 旧 `:278-279`）；`applyPendingDeletionDiff` 旧取消循环对 `previous − new` 全量取消。**修后**夹具：`testIC163A_VirtualRangeReturnKeepsBasketOutsideHandoff` 走「进篮 {p,q} → 交接列表 [x,y,z] → S2 标 y → 写回 {y}」，集合为 {p,q,y}、`makeS3Submission()` 非 nil 且该组三项——#327 passed | 与卡面机制一致。**夹具驱动，真机未覆盖**：S2 垃圾桶 → S3 的真实路由、组头与张数，由 H82 第 6 条判 |
| 「S2 回来勾选不见了」极可能同一机制（进篮项被抹掉后回到网格、未勾） | ③（卡面） | 模拟器上无法复现「回到网格」这一视觉结果；修后逻辑上篮内项不再被抹 | **未覆盖**，留 H82 第 7 条单独复判 |
| bug 1／2「展开卡打不开、点总条段不切换」= 封面 `scaledToFill` 溢出的**命中区**被 `clipped`／`clipShape` 保留，后面的卡盖住展开卡与总条 | ③（卡面，高把握） | CI 与测试宿主取不到图，`S0DeckCoverView` 一帧都没画过（陷阱 24 同源）；XCUITest 模拟手势被明令禁止（陷阱 2） | **未覆盖**。按裁定 二加了两处 `contentShape`，是否修好由 H82 第 1 条判 |

## 五、CI（G919）

**一次运行一次绿，预算 3 次用了 1 次。**

| 项 | **#327** |
|---|---|
| 运行 id | `35820264921`（`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/35820264921`） |
| run_attempt | 1 |
| 触发 | push `probe/ic-163-deck-home-preview-r2`，2026-09-23T04:54:56Z 建、05:05:21Z 完 |
| 结论 | `success`（作业 `构建、XCTest 与未签名产物` success；十二步全 `success`，「运行 XCTest」04:55:35→05:02:19） |
| 被测提交（完整 SHA） | `0b3dd0321ff8e347519b5572943587810de3aac8`（A + D + B + C） |
| XCTest 执行摘要 notice | `Executed 865 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 865 tests / 0 failures` |
| 整包日志按**唯一 Test Case 行**复核（陷阱 25：先剔 `##[` 回显与 ANSI 脚本回显；按单个步骤文件计） | **865 passed / 0 failed**；`Test Suite 'All tests' started` 1 次（无宿主重启）；`Restarting after` 0 |
| 真实退出码 | **0**——工作流 `set -o pipefail` 且末句 `exit "$test_status"`；日志 `** TEST SUCCEEDED **`、无 `** TEST FAILED **`；原始 `Executed 865 tests, with 0 failures (0 unexpected) in 38.089 (39.862) seconds`；无任何 failure 注解 |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 分段耗时 notice 原文 | `XCTest 分段耗时：模拟器启动 71 s；xcodebuild test 330 s；总 402 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1904145，SHA-256=2f01a4c5627b52a1122de1249242a26992990b761dcded10353bda47a0b67fba` |

### 产物（Lynn 要装的包）

| 项 | 值 |
|---|---|
| artifact 名称 | **`PhotoCleanupMVE-unsigned-0b3dd0321ff8`** |
| artifact id | **`10733187205`** |
| 大小 | 1 904 315 字节（zip；内含 IPA 1 904 145 字节） |
| digest | `sha256:849c52ef72371fb033a63ebc77f158c2891761b06a7a7b8dfc2f0a5e5b7409b1`（zip 的） |
| 生成时间 | 2026-09-23T05:05:06Z |
| **有效期至** | **2026-12-22T04:54:56Z**（`expired: false`） |
| 来自运行 | #327 |

### 项数对账

| 时点 | 项数 |
|---|---|
| `180b052`（#326） | 862 |
| 子项 A 后 | 862 + 3 = **865** |
| 子项 D 后 | 865（只改期望值，不加不减用例） |
| 子项 B 后 | 865 − 1 = **864** |
| 子项 C 后 | 864 − 2 + 3 = **865** |
| #327 实测 | **865**，0 失败 |

本机非注释 `func test` 计数 862 → 865 与之一致（仅作差值预估，陷阱 22）。

### 相关用例逐族点名（#327 按唯一 Test Case 行统计）

| 测试类 | 过 | 失败 | 与本卡的关系 |
|---|---|---|---|
| `IC163DeckPreviewRoundTwoTests`（本卡） | 6 | 0 | A 三条 + C 三条 |
| `IC162DeckPreviewTests` | 3 | 0 | B 删 1、C 删 2 后余 3 |
| `IC153ScanServiceTests` | 13 | 0 | D 改期望值 |
| `IC155CategoryDataAndCoverTests` | 9 | 0 | D 改期望值 |
| `IC157LongPressIntoS2Tests` | 8 | 0 | A 的被钉计数与逐字函数体 |
| `SessionStoreTests` | 14 | 0 | `applyS2Return` 既有语义（真实范围）不变 |
| `S1StateMachineTests` | 20 | 0 | 同上 |
| `AlbumScopeWiringTests` | 7 | 0 | 同上 |
| `FullFlowRoutingTests` | 6 | 0 | 同上 |
| `IC147S0BehaviorTests`／`IC148S0VisualTests`／`IC151AmbientFixedColorTests`／`IC152DiagnosticPathTests`／`IC156CategoryPageTests`／`IC160SelectionSurvivesS2Tests` | 16／14／8／6／11／4 | 0 | 旧首页、流程文件、旧类别页被钉的断言 |

### `testIC063`（陷阱 26 口径）

passed（6.499 s）。`Errors found! Invalidating cache...` 两行（05:01:04.25、05:01:04.83）→ `[error] building pipeline path_exterior-jba6la8feba4 took 0.620839 seconds`（05:01:04.88）→ `IC063_WARMUP_GATE_BEGIN` 05:01:06.49 → `IC063_WARMUP_GATE_END` 05:01:06.53 → `IC063_DIAGNOSTICS_SAMPLE_BEGIN` 05:01:09.72。Metal 管线编译落在预热门禁**之前**，计时段干净。本卡未触碰该用例。

## 六、六条断言与测试函数名

| # | 断言 | 测试函数 | 子项 |
|---|---|---|---|
| 1 | 真实范围：进 S2 前标 {a}，S2 里取消 a、标 b，逐张镜像后 = {b}；写回 {b} 后仍 = {b}，a 的首标记录清掉；会话层单独对照同结果（负对照：与改前一致） | `testIC163A_RealRangeReturnUnchanged` | A |
| 2 | 虚拟范围 `cat:bigVideo`：进篮 {p,q} → 交接列表 [x,y,z]（交接带入的待删集合为空、徽标 2）→ 逐张镜像 {y} 后 = {p,q,y}、三者首标都是 `cat:bigVideo` → 写回 {y} 后仍 {p,q,y}、徽标 3、在途登记清空 → `makeS3Submission()` 非 nil，该组名「视频」、三项 {p,q,y}（机器取 `.empty`，避开 `.loading` 守卫） | `testIC163A_VirtualRangeReturnKeepsBasketOutsideHandoff` | A |
| 3 | 同上，但 S2 里先标 y 再取消（逐张镜像 {} 与写回 {}）→ 集合 = {p,q}，y 的首标记录清掉，p、q 的首标记录保留，徽标 2 | `testIC163A_VirtualRangeUnmarkInsideHandoffStillWorks` | A |
| 4 | 五项、两项无日期：`.size` 原序；`.newestFirst` = d1(3/30)、d0(3/2)、d3(2/11)、d2、d4；`.oldestFirst` = d3、d0、d1、d2、d4；全无日期时时间排序 = 入参序；同日期两项两种方向都按 id 升序 | `testIC163C_SortedBySizeKeepsOrderAndTimeOrdersPutUndatedLast` | C |
| 5 | 日期 3/30、3/2、2/11、无、无（最新在前排好传入）→ 三节 [[m1,m2],[m3],[u1,u2]]；`monthStart` = 用同一 `Calendar` 反算的 2026-03-01 与 2026-02-01、末节 nil；3 月那节的 `monthStart` 日／时／分／秒 = 1／0／0／0 | `testIC163C_MonthSectionsGroupByYearMonthInInputOrder` | C |
| 6 | 空入参 → 空数组 | `testIC163C_MonthSectionsEmptyInputGivesNoSections` | C |

C 的三条**只测纯函数**：不构造视图、不碰 PhotoKit；夹具 `Calendar(identifier: .gregorian)` + `TimeZone(secondsFromGMT: 0)`、日期取正午，不用 `Calendar.current`。推 CI 前本机用 Python 移植 `sorted`／`monthSections` 复算，六组期望全部相符（②，权威结论只取 CI）。

**夹具驱动，真机未覆盖**（陷阱 1）：命中区、切换过渡、玻璃质感、排序菜单、月份节标题的写法、长按进 S2 → S3 的真实路径，全部由 H82 真机兜底。

## 七、本地门禁结果与真实退出码

| 门禁 | 子项 A 提交前 | 子项 D 提交前 | 子项 B 提交前 | 子项 C 提交前 |
|---|---|---|---|---|
| `Scripts/selfcheck.ps1` | 0 | 0 | 0 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 0 | 0 | 0 |
| `git diff --cached --check`（已 `git add -A` 后，含新文件） | 0 | 0 | 0 | 0 |

扫描器四次分别报「目录条目：265／265／264／264，产品源码引用 key：同值，用户可见硬编码残留：0」。`selfcheck.ps1` 最后一次报：Swift 字符串与括号结构检查扫描 **97 个** `.swift`，无未闭合字符串、无括号失衡；扫描 needle 与源码变体交叉审计扫描 45 个测试源文件，无喂错。另在每次提交前用本机 Python 结构预检（逐行字符串状态 + 花括号／圆括号配平）过一遍本次改动的 Swift 文件，均通过。

推 CI 前另请一个只读子代理对 `180b052` 起的整份 diff 做编译与断言复核（删掉的符号零残留、SwiftUI 类型推断风险、六条新测试逐条走实现、IC153／IC155 全部依赖分类的期望按新规则重推、pbxproj 与目录），**报「会失败」0 条**；「可能的风险」三条（`cardContent` 的 overlay 链类型检查耗时、若干登记值变成无人使用、月份节标题每次新建 `DateFormatter`）都不影响编译与断言，#327 一次绿印证。

## 八、摘取关系实证（克隆 cherry-pick，只作证据，未推 `main`）

在会话草稿区克隆本仓，从 `origin/main`（`091b60e`）切临时分支后 cherry-pick：

| 序列 | 结果 |
|---|---|
| A 单独（`105ada3`） | 退出码 **0**，`Auto-merging project.pbxproj`，无冲突 |
| D 单独（`088e4b1`） | 退出码 **0**，`Auto-merging Localizable.xcstrings`，无冲突 |
| A → D 连续 | 退出码 **0**，无冲突 |

与卡面「A 与 D 各自单独可摘、且可摘到 `main`」一致。A 的 pbxproj 四行按卡面给的四个 `main` 侧锚行插入（`S0CleanupFlowModel` 两行、`S3StateMachineTests` 两行之后），未紧挨 IC-162 的登记块。B 依赖 IC-162 链、C 依赖 A 与 B，不是独立摘取单位。

## 九、人工判定项（H82 九条，原样列出，留给 Lynn 装 #327 产物后真机判）

**本报告不代 Lynn 下任何观感结论。** 装 **`PhotoCleanupMVE-unsigned-0b3dd0321ff8`**（id `10733187205`）。

1. 首页：展开的那张卡（大视频）点一下或点「去清理」能进类别页；点总条上截图／录屏那两段能切换展开卡。
2. 展开／收起的切换过渡比上一版好还是差。
3. 类别页：收起后的导航条、格子底部的标签条、底栏三处，是不是和 S2 收藏／标记那种系统玻璃一样的质感。
4. 排序钮在「全选」左边；三个选项切换正常；「最新在前」「最旧在前」下按月分节、节标题是「2026年3月」这种写法；没有日期的照片归在最后一节「未知日期」。
5. 「最大的 10 个」那一节已经没有了。
6. 进篮 → 长按进 S2 → 点右上垃圾桶 → S3 里能看到这个类别一组、张数与进篮的一致；从 S3 返回后这些照片仍在篮里（不回到网格）。
7. 不先进篮：勾选几张 → 长按某张进 S2 → 直接返回 → 勾选还在。
8. 类别叫「视频」，点进去能看到全部视频（含小于 100 MB 的），按大小排序时大视频自然在前；屏幕录制仍单独一类、不在「视频」里重复出现；首页总数与「视频」占比比上一版变大（小视频从「其余照片」挪过来了）。
9. 一两句总评。

> 注：H82 第 1 条原文写「展开的那张卡（大视频）」——本分支起该类别名已是「视频」（子项 D），指的是同一张卡。

## 十、实现中的取舍（卡面未写死、按意图处理，供决策会话核）

1. **B-2 切换过渡改了 `cardContent` 的结构**（③）：原来整支 `if isOpen { … } else { … }` 换掉，嵌在分支里的 `.transition` 不保证生效；改为一只封面 + 六个 overlay、各层在自己的 overlay 里条件插入，过渡才作用在被插入的视图上。封面挂 `.id(coverAssetID).id(isOpen)`，保留改前「展开态一变就按新尺寸重建封面、重取图」的效果。
2. **IC153 卡面「`:126-151` 两例合成一例」未照做**：白名单写「不删断言」，两例保留，门槛改字面量、期望都改 `.bigVideo`，覆盖面等价。只有两处因符号被删而删断言（`:20-22`、`:376`）。
3. **IC153 `:297` 的断言关系改了**：`XCTAssertGreaterThan(categorySum, cleanable)` → `XCTAssertEqual`。卡面预演未列，复算发现——裁定 五让「同一资产计入两类」在本夹具里不再发生，原断言必红。不改夹具、不增删断言。
4. **「从大到小」下整页那张网格距页头取 `monthSectionSpacing`（12）**：卡面只写「节间距 12，首节距页头 12」，整页网格的顶距没写；按「首块内容距页头 12」同口径处理（原先是节标题顶距 20 + 节到网格 6）。
5. **收起导航里的排序钮**：卡面「圆钮直径与页头返回钮相同（44）」与「玻璃容器里的钮用平涂」两条合起来，取 44 圆、`text.opacity(compactNavActionFillOpacity)` 平涂底。它比同一条里的返回钮（42）与「全选」胶囊（38 高）都大，观感留给 H82 第 3、4 条。
6. **月份节标题**：左节名、右计数（「右侧计数」按 `Spacer` 之后理解）；计数字号 12.5、压暗 0.55。
7. **`DateFormatter` 在每个节标题现建**（不做静态存储），避开非 Sendable 全局量的编译面风险；节数很少，开销可忽略。

## 十一、发现但未处理的问题（按纪律只报告不修）

1. **卡面对 IC153／IC155 的预演有四处与复算不符**（均以复算为准处理，第十节 2、3 与 `change-list.md` 第四节）：IC153 `:296-297` 未列（类别和 303→153 MB、`>` 必红）；IC155 `:226`、`:248` 未列（视频类封面 `"recording"` → `nil`）；IC155 `:489-490`（时长去重数）预言会变、复算 4 → 4 不变；IC155 `:524`（进篮后视频类候选数）预言会变、复算 3 → 3 不变。
2. **成了无人使用的登记值**（白名单只授权删 `glassFill`／`dockFill`／`topSectionLimit` 与六个角标值，其余未动）：`S0DeckSymbol.sparkle`、`sectionTopSpacing`、`sectionActionHeight`／`CornerRadius`／`HorizontalPadding`／`ItemSpacing`／`FontSize`／`RingWidth`／`RingOpacity` 七个；另有 IC-162 起就无人使用的 `cellLabelFill`、`compactNavTopInset`（后者 IC-162 报告第十一节第 2 条已记）。`sectionAction` 色值仍被 `colorSimilar` 引用。
3. **类别页页头副行在时间排序下仍写「从大到小」**：裁定 三明文保留 `deck.home.open.subtitle`（`{count} 项 · 从大到小`），它在页头标题列里恒显示，切到「最新在前」「最旧在前」后与网格实际顺序不符。
4. **每个格底标签条各挂一层系统玻璃**（裁定 四）：iOS 26 上是 `glassEffect`，大类别（几百上千格）懒加载网格里玻璃层数随可见格数增长，真机滚动性能未知（③），可在 H82 第 3 条顺带看。
5. **排序菜单在日期取回前整只禁用**：`S0DeckAssetDates` 一次同步取全类别的拍摄日期（后台），类别越大禁用时间越长；每次进篮后网格项变化会再取一次（期间旧字典可用、菜单不禁用）。
6. **`S0ScanClassifier.hits(...)` 的 `byteCount` 形参现在函数体内不用了**：签名保留（测试直调、`hits(for:)` 转发），留给日后的正名／重构卡。
7. **旧类别页 `S0CategoryPageView`（`main` 上那只）**：长按交接同样传「网格当前项」，A 在 `Core/` 层修复，对新旧两页一并生效；旧页文件一字未动。
8. **本机流程复盘**：Git Bash 的 `unzip` 把整包日志里的中文文件名解成乱码、`rm -rf` 删不掉临时目录（残留在草稿区，不在仓内）；改用 Python `zipfile` 按 `cp437→utf-8` 还原文件名后直接读条目。与记忆里「中文文件名用 Python 遍历」同一类。
