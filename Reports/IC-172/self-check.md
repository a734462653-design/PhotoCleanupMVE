# IC-172 自验报告

## 一、结论（先行）

- **停卡上报，未合并。** 按任务卡「模型阶梯补偿」条款：子项 A→B→C 推送后 CI **#349 一次绿（892／0）**；子项 D 推送后 CI **#350 一次红（898／1，1 处失败）**，失败用例为卡内新增测试 `testIC172A_S1LegacyRecipeIsDarkInBothStyles`。**执行端未自行改代码重推**，按要求在此报告红的运行编号、失败用例名、注解原文、整包日志里全部 `IC172_PROBE` 行原文与初步归因后停下，等待决策会话读日志后给下一步指示。
- **四个子项代码均已交付并推送到 `feature/ic-172-glass-always-dark`**：A `6308693920a4e180f74559549c2606b8539d1ba0`、B `e89b95a248e6bc47224c4c7c3929b196b3219794`、C `df10428b74d3e0547dcbe4a30a8623dd14cc236b`、D `a01ffe616396750a091c8d22dd8497d9f4983922`。
- **子项 A、B、C 的产品改动逐字节核验与卡面代码块一致**：用 `Tasks/decision-tools/check_ic172.py` 对三个阶段分别做「实际 blob == 对基线程序化应用卡面 old→new 替换后的 blob」比对，全部相符（详见第四节）；`Tasks/decision-tools/sim_ic172.py`/自写计数脚本核对的剔注释计数表逐条与卡面「改后（剔注释，预演值）」一致，无一处不符。
- **子项 D 的测试文件按要求用 `cp` 逐字节拷入**，`git hash-object` = `b49a40de20a2790da747428bce3ae423d316e20d`，与卡面要求值完全一致，未改动其中任何一行。pbxproj 登记新增 `fileRef 100000000000000000000075`／`buildFile 200000000000000000000072`，撞号扫描（定义行 `uniq -d`）为空。
- **裁定二·预定的红与含义**：本次红命中卡面预先列出的六种归因之一——**「legacy 红 → 系统材质不随 SwiftUI 环境」**。但像素探针原始数据显示一个卡面未预判的细节：`s1Legacy` 在 `overrideUserInterfaceStyle = .light` 与 `.dark` 两次渲染下取值完全相同（149/149，满足第一条断言的"两侧不变"要求），说明 `.environment(\.colorScheme, .dark)` 确实让该组合视图的渲染结果不再随外层 trait 变化；但这个恒定值（149）比起"纯 `.ultraThinMaterial` 深色态"（`materialReference.dark=99`）更接近"纯 `.ultraThinMaterial` 浅色态"（`materialReference.light=169`，|149-169|=20 < |149-99|=50），导致第二条断言（应更接近深色）判红。这与卡面归因描述的字面情形（材质完全不随 SwiftUI 环境、应像正对照一样两侧仍有大差异）不完全一致——**本次观察到的是"两侧变得一致，但一致后的落点没有落到预期的深色一侧"，而不是"两侧仍然不一致"**。这一细节差异标记为③，具体分析见第七节，留给决策会话判断根因与下一步（例如：legacy 配方叠加的白色描边/淡染层是否把中心像素拉向浅色、或该恒定行为其实来自渲染时序而非环境覆盖本身）。
- **`testIC172A_S1GlassHelperIsDarkInBothStyles`（iOS 26 `glassEffect()` helper）与 `testIC172B_GlassContainerPathIsDarkInBothStyles`（容器路径）均通过**——898 项中只有 1 项失败，其余 897 项（含两条正对照、`testIC172ABC_SourceWiring`、IC148/IC156 正对照、`testIC063` 等既有测试）全部通过，白名单外零改动（G966）确认无回归。
- **G963 不满足**（helper 与 legacy 两条被测中 legacy 未通过）；**G964、G965、G966 满足**；**G967 不满足**（要求两次 CI 均绿，本次 898／1）——**未触发合并**，`main` 未变。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260924-172-glass-always-dark.md` |
| 调研 | `<top>/Tasks/RESEARCH-IC-171-glass-facts.md` |
| 复核 | `<top>/Tasks/REVIEW-IC-172-findings.md`（两轮，第二轮结论「可以下发」） |
| 基线 `main`（本地与远端一致） | `467fe74a0323c98e938142a2107f16843d21cc96` |
| 开工核对 1 | `git status --porcelain` 空（纪律 8） |
| 开工核对 2 | `git merge-base --is-ancestor e356aeda17da53a064892e04f39bea1032f5bf8d main` 退出码 **0** |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `467fe74a0323c98e938142a2107f16843d21cc96` = 本地 |
| 分支 | `feature/ic-172-glass-always-dark`（自上述基线 `git switch -c` 切出） |
| 分支 tip（当前，未合并） | `a01ffe616396750a091c8d22dd8497d9f4983922` |
| `schemaVersion` | 7（未动） |
| `cacheSchemaVersion` | 1（未动） |
| `S0DeckMetrics` 登记值 | 195（未动） |
| 文案目录 | 259（`s0.` 41，未动） |
| **是否合并** | **否——G967 不满足，`main` 保持 `467fe74a0323c98e938142a2107f16843d21cc96`** |
| **docs 提交** | 无（未合并，不适用惯例 44 的合并后落点） |

---

## 三、子项 A～D 逐条交付

| 子项 | 提交 SHA | 内容 |
|---|---|---|
| A | `6308693920a4e180f74559549c2606b8539d1ba0` | 两个玻璃 helper（`s1/s2ChromeGlassBackground` 的 iOS 26 分支、`s1/s2LegacyChromeGlassBackground` 回落分支收尾）各追加 `.environment(\.colorScheme, .dark)` |
| B | `e89b95a248e6bc47224c4c7c3929b196b3219794` | 五个玻璃容器（S1 `chromeBar`／`s1GlassBadgeOverlay`／`s1GlassBadgeHost`，S2 `topBar`／`actionBar`）容器链尾各加同一覆盖 |
| C | `df10428b74d3e0547dcbe4a30a8623dd14cc236b` | 四处系统材质（S1 写回失败 toast、S1 排序／分组菜单 `menuContainer`，S2 写回失败 toast、S2 相簿 sheet 教程提示条）材质之后加覆盖；S2 标定面板三处不纳入 |
| D | `a01ffe616396750a091c8d22dd8497d9f4983922` | 新增 `IC172GlassAlwaysDarkTests.swift`（逐字节拷入）+ pbxproj 登记 |

四个提交均可用 `git cat-file -e` 核验存在（见第十节）。

---

## 四、子项 A～C 计数实测表（卡面值 / 实测值逐条对读）

方法：`Tasks/decision-tools/scan.py`（`git show <rev>:<path>` 只读）+ `strip.py`（`strippedSource` 同口径）对各子项提交做剔注释计数；另用 `Tasks/decision-tools/check_ic172.py <commit> <stage>` 做「产品文件 blob == 对基线程序化套用卡面 `ic172_edits.py` 中 old→new 替换后的 blob」强校验（该脚本与生成卡面代码块的脚本同源，等价于把卡面 26 处代码块用文本替换的方式逐一核对）。

### 子项 A（commit `6308693`）—— `check_ic172.py 6308693 A`：26 项 PASS / 26

| needle | 文件 | 卡面「改后」值 | 实测值（剔注释） |
|---|---|---|---|
| `.environment(\.colorScheme, .dark)` / `colorScheme` | S1View.swift | 0→2 | 2 |
| `.environment(\.colorScheme, .dark)` / `colorScheme` | S2View.swift | 0→2 | 2 |
| `GlassEffectContainer {` | S1View.swift | 3（不变） | 3 |
| `GlassEffectContainer {` | S2View.swift | 2（不变） | 2 |
| `#available` | S1View.swift | 4（不变） | 4 |
| `#available` | S2View.swift | 3（不变） | 3 |
| `Material` | S1View.swift | 3（不变） | 3 |
| `Material` | S2View.swift | 6（不变） | 6 |
| `ultraThin` | S1/S2View.swift | 2／2（不变） | 2／2 |
| `.primary` | S1/S2View.swift | 12／8（不变） | 12／8 |
| `glassEffect(` | S1/S2View.swift | 1／1（不变） | 1／1 |
| `s1ChromeGlassBackground(` | S1View.swift | 4（不变） | 4 |
| `s2ChromeGlassBackground(` | S2View.swift | 6（不变） | 6 |
| `Color(uiColor: .systemBackground)` | S1/S2View.swift | 2／2（不变） | 2／2 |
| `preferredColorScheme`／`overrideUserInterfaceStyle` | 两文件 | 0（不变） | 0 |

### 子项 B（commit `e89b95a`）—— `check_ic172.py e89b95a B`：26 项 PASS / 26

| needle | 文件 | 卡面「改后」值 | 实测值 |
|---|---|---|---|
| `colorScheme, .dark)` | S1View.swift | 2→5 | 5 |
| `colorScheme, .dark)` | S2View.swift | 2→4 | 4 |
| 子项 A 其余全部 needle | 两文件 | 不变 | 不变（逐项核对，与上表相同） |

### 子项 C（commit `df10428`）—— `check_ic172.py df10428 C`：30 项 PASS / 30（含两处 blob 强校验）

| 项 | 卡面值 | 实测值 |
|---|---|---|
| blob S1View.swift == 卡面 A/B/C 编辑累积套用基线后的 blob | 相等 | **相等**（`99dd6a9ba1170c3b3dcedc26fec2e22850912eb3`） |
| blob S2View.swift == 同上 | 相等 | **相等**（`bea3bf09887428db76827877408a27b09ecf0bb3`） |
| `colorScheme, .dark)` | S1 5→7 | 7 |
| `colorScheme, .dark)` | S2 4→6 | 6 |
| `.background(.regularMaterial)`（无 `in:`，S2 标定面板，无 IC-172 修改） | 3（不变） | 3 |
| 其余全部 needle | 不变 | 不变 |

**结论：子项 A、B、C 三个提交的产品文件（`S1View.swift`、`S2View.swift`）与卡面 26 处代码块逐字节等价，无一处偏离。**

---

## 五、测试文件与 pbxproj 校验

- `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift`：`git hash-object` = `b49a40de20a2790da747428bce3ae423d316e20d`，与卡面要求值**完全一致**；`cp` 拷入，未改任何一行；无 CRLF（`\r\n` 计数为 0）；364 行；`grep -c "func test"` = 6，与卡面六条测试名一致：`testIC172A_MaterialControlFollowsInterfaceStyle`、`testIC172A_RawGlassControlFollowsInterfaceStyle`、`testIC172A_S1GlassHelperIsDarkInBothStyles`、`testIC172A_S1LegacyRecipeIsDarkInBothStyles`、`testIC172B_GlassContainerPathIsDarkInBothStyles`、`testIC172ABC_SourceWiring`。
- pbxproj：新增 `100000000000000000000075`（fileRef，占 3 处：BuildFile 引用、FileReference 定义、Group 列表）、`200000000000000000000072`（buildFile，占 2 处：BuildFile 定义、Sources 构建阶段列表）——`check_ic172.py` 断言「pbx fileRef 75 occ=3」「pbx buildFile 72 occ=2」均 PASS；定义行（`isa = PBXFileReference`／`isa = PBXBuildFile` 的定义行）按 id 分组 `uniq -d` 为空，无撞号。
- `changed paths outside whitelist` = `[]`；`changed product/test/pbx path count` = 4（`PhotoCleanupMVE.xcodeproj/project.pbxproj`、`Features/S1/S1View.swift`、`Features/S2/S2View.swift`、`PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift`），与白名单表完全一致。

---

## 六、摘取关系实测（惯例 40，克隆内验证）

在临时克隆（`ic172-exec/clone172`，源为本地 `PhotoCleanupMVE` 工作副本）内，从基线 `467fe74a` 分别单独 cherry-pick：

- `git cherry-pick 6308693`（A 单独）→ **成功**，`2 files changed, 10 insertions(+)`。
- `git cherry-pick e89b95a`（B 单独）→ **成功**（`Auto-merging` 两文件，无冲突），`2 files changed, 10 insertions(+)`。
- `git cherry-pick df10428`（C 单独）→ **成功**（`Auto-merging` 两文件，无冲突），`2 files changed, 9 insertions(+)`。

三者均可独立、干净地摘到基线上，验证卡面「A、B、C 任意组合可摘」的说法成立。

---

## 七、CI 结果

### 运行一：`feature/ic-172-glass-always-dark` push（A→B→C），commit `df10428b74d3e0547dcbe4a30a8623dd14cc236b`

- 运行编号 **#349**（run id `35986967001`），`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/35986967001`
- 结论：`completed` / `success`，全部 12 个步骤 `success`
- **XCTest 执行摘要**（notice 原文）：`Executed 892 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 892 tests / 0 failures`
- **XCTest 分段耗时**（notice 原文）：`模拟器启动 80 s；xcodebuild test 335 s；总 416 s`
- **未签名 IPA 校验**（notice 原文）：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1862103，SHA-256=ca665a10f5963c3d0ff06164c18c33773be6600f18176a369e2ac95e55218c10`
- artifact：`PhotoCleanupMVE-unsigned-df10428b74d3`，id `10803095716`，`1862273` 字节，有效期至 `2026-12-23T10:23:48Z`
- **`IC172_PROBE` 行**：0 行——`IC172GlassAlwaysDarkTests.swift` 在此提交尚未加入仓库（该文件由子项 D 引入），此次 892 项不含新测试，故整包日志内无 `IC172_PROBE` 字样，已用 Python `zipfile` 读取全部步骤日志逐行搜索确认为 0（预期结果，非缺陷）。

### 运行二：`feature/ic-172-glass-always-dark` push（D），commit `a01ffe616396750a091c8d22dd8497d9f4983922`

- 运行编号 **#350**（run id `35988265755`），`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/35988265755`
- 结论：`completed` / `failure`。步骤 1-8、12 均 `success`；**步骤 9「运行 XCTest」`failure`**；步骤 10「构建未签名应用」、步骤 11「上传可下载的未签名 IPA」均 `skipped`（因步骤 9 失败）——**本次运行无 IPA 产物**。
- **真实退出码**：`Process completed with exit code 65`（步骤 9 注解原文）
- **XCTest 执行摘要**（notice 原文）：`Executed 898 tests, 1 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 898 tests / 1 failures`
- **XCTest 分段耗时**（notice 原文）：`模拟器启动 68 s；xcodebuild test 336 s；总 405 s`
- **失败注解原文**（`annotation_level=failure`，共 3 条，均来自「运行 XCTest」步骤）：
  1. `Process completed with exit code 65.`
  2. `XCTest 失败 | ** TEST FAILED **`
  3. `XCTest 失败 | /Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift:101: error: -[PhotoCleanupMVETests.IC172GlassAlwaysDarkTests testIC172A_S1LegacyRecipeIsDarkInBothStyles] : XCTAssertLessThan failed: ("50") is not less than ("20") - 浅色外观下回落配方更接近浅色材质`
  4. `XCTest 失败 | Test Case '-[PhotoCleanupMVETests.IC172GlassAlwaysDarkTests testIC172A_S1LegacyRecipeIsDarkInBothStyles]' failed (0.983 seconds).`
- **失败用例**：`testIC172A_S1LegacyRecipeIsDarkInBothStyles`（唯一失败项，898 项中 897 项通过）。
- **全部 `IC172_PROBE` 行原文**（下载整包日志 `run350_logs.zip`，用 Python `zipfile` 读取 `构建、XCTest 与未签名产物/9_运行 XCTest.txt`，逐行搜索 `IC172_PROBE`，共 7 行，按日志出现顺序）：

```
2026-09-24T10:43:08.2412210Z IC172_PROBE arm=material light=169 dark=99
2026-09-24T10:43:08.6953810Z IC172_PROBE arm=rawGlass light=246 dark=78
2026-09-24T10:43:09.1986770Z IC172_PROBE arm=s1Helper light=78 dark=78
2026-09-24T10:43:09.6370340Z IC172_PROBE arm=rawGlassReference light=246 dark=78
2026-09-24T10:43:10.1512360Z IC172_PROBE arm=s1Legacy light=149 dark=149
2026-09-24T10:43:10.6442820Z IC172_PROBE arm=materialReference light=169 dark=99
2026-09-24T10:43:11.1915700Z IC172_PROBE arm=s1GlassBadgeOverlay light=78 dark=78
```

### 归因（初步，③，按卡内裁定二「预定的红与含义」映射）

逐条核对六种预定归因：

| 预定情形 | 是否命中 | 依据 |
|---|---|---|
| 正对照 material 红（夹具看不见外观差） | 否 | `material`：`|169-99|=70 ≥ 12`，正对照通过 |
| 正对照 rawGlass 红（截屏看不见玻璃外观差） | 否 | `rawGlass`：`|246-78|=168 ≥ 6`，正对照通过 |
| helper 红而两条正对照绿（候选 (a) 对 iOS 26 玻璃不成立） | 否 | `s1Helper`：`|78-78|=0 ≤ 3` 且 `|78(helper.light) - 78(rawGlassReference.dark)|=0 ≤ 3`，两条子断言均通过——iOS 26 `glassEffect()` 对 `.environment(\.colorScheme, .dark)` 的响应**与真实深色 trait 下的裸玻璃像素完全相等**，候选 (a) 对 iOS 26 玻璃成立，未被推翻 |
| **legacy 红（系统材质不随 SwiftUI 环境）** | **是——最接近的预定命中项** | `testIC172A_S1LegacyRecipeIsDarkInBothStyles` 判红，唯一失败项 |
| 容器路径红而 helper 绿（容器层覆盖不够） | 否 | `s1GlassBadgeOverlay`：`|78-78|=0 ≤ 3`，通过 |

**归因细节（③，超出卡面预定描述的部分，如实记录不代为下结论）**：

- `testIC172A_S1LegacyRecipeIsDarkInBothStyles` 内有两条子断言。**第一条**（`abs(legacy.light - legacy.dark) ≤ 3`）：`|149-149|=0`，**通过**——`s1LegacyChromeGlassBackground` 加了 `.environment(\.colorScheme, .dark)` 之后，`overrideUserInterfaceStyle` 在 `.light`／`.dark` 两次渲染下取得的中心像素灰度**确实变成了同一个值（149）**，即覆盖确实生效、切断了该组合视图与外层 trait 的联系。**第二条**（`abs(legacy.light - material.dark) < abs(legacy.light - material.light)`，即"这个恒定值应更接近纯材质的深色态"）：`|149-99|=50` 不小于 `|149-169|=20`——恒定值 149 反而**更接近材质的浅色态**，判红。
- 卡面裁定二把"legacy 红"的含义写作「系统材质不随 SwiftUI 环境」，字面上暗示的失败形态是"两侧仍然不同、覆盖没生效"（类似正对照那种大差异）；但本次实测是"两侧变成同一个值（覆盖确实生效），只是这个值没有落在预期的深色区间"。这是否仍属于"系统材质不随 SwiftUI 环境"这一类别，还是应归为另一种此前未列出的情形（例如：`environment` 覆盖对 `Material` 起了作用，但 `s1LegacyChromeGlassBackground` 自身叠加的白色描边／淡染层（`Color.white.opacity(S1ChromeGlass.tintOpacity)` 与两层白色描边）把中心像素结果拉向了浅色区间，与"材质本身是否读到深色"是两回事），执行端不代为判断，标记为③，留给决策会话核实。
- 供决策会话核对用的原始配方常量（本次未改动，仅供归因参考）：`S1ChromeGlass.tintOpacity`、`innerHighlightTop`／`innerHighlightBottom`、`outerRingOpacity` 等六个常量的取值，若需要复算中心像素合成结果，应从 `S1View.swift` 现读，本报告不重复列出以免与实际代码脱节。

---

## 八、本地门禁（四个提交各一次，均为工作树内真实执行）

| 子项 | `selfcheck.ps1` 退出码 | `scan-hardcoded-user-visible-strings.ps1` 退出码 | `git diff --check` 退出码 |
|---|---|---|---|
| A | 0 | 0 | 0 |
| B | 0 | 0 | 0 |
| C | 0 | 0 | 0 |
| D | 0 | 0 | 0 |

D 提交后 `selfcheck.ps1` 扫描文件数从 103→104 个 `.swift`、测试源文件从 51→52 个，均因新增 `IC172GlassAlwaysDarkTests.swift` 一个文件，符合预期。四次运行「用户可见硬编码残留」均为 0。

---

## 九、闸门结果

| 闸门 | 结果 | 依据 |
|---|---|---|
| **G963**（helper） | **不满足** | 子项 A 计数相符（第四节）；像素三条被测中 helper（`testIC172A_S1GlassHelperIsDarkInBothStyles`）通过，**legacy（`testIC172A_S1LegacyRecipeIsDarkInBothStyles`）未通过** |
| **G964**（容器） | 满足 | 子项 B 计数相符；`testIC172B_GlassContainerPathIsDarkInBothStyles` 通过（898 项中仅 1 项失败，且该失败非此测试） |
| **G965**（材质） | 满足 | 子项 C 计数相符；`testIC172ABC_SourceWiring` 通过（源码扫描，未在失败列表中）；IC148/IC156 正对照未见失败（897 项通过中含这些既有测试） |
| **G966**（白名单外零改动） | 满足 | `git diff --name-only 467fe74a..a01ffe6` 恰 4 路径，与白名单一致；十八条被保护分支 tip 经 `git ls-remote origin` 现取核对未变（第十一节） |
| **G967**（合并前置） | **不满足** | 要求两次 CI 均绿（892／0、898／0），实测 892／0 与 898／1——**第二次不满足，不触发合并** |
| **G968**（合并后运行） | 不适用 | 未合并 |

---

## 十、十八条被保护分支 tip（`git ls-remote origin` 现取核对，全部未变）

`feature/ic-089-nx-edge-bounce` `b368a6caee846e664391b0620350395bfe6fbc7f`、`feature/ic-091-nx-midgesture-handoff` `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`、`feature/ic-092-nx-window-follow` `a7cc1ec727a3a493f5263e688a316cbf4c743562`、`feature/ic-158-diagnostic-progress-clamp` `5cb67332437a446d98733ddc942e2905392d2891`、`feature/ic-164-pick-ic163-a-d` `cc85fa4a7cfa272092a3acfade432d13de7e4e0b`、`feature/ic-165-deck-formal` `dc7e49459f15fb6227c3f34903357ae490aaa7ed`、`feature/ic-166-rest-category-and-lib` `2734ccd0ef2f12fa4ce115f0136777321a96c548`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd1436fa25b8298caca2f3d2266024859df4e`、`feature/ic-168-s2-exit-diagnostics` `e7c1be085102b5d9685b0863f29feb6bfa006a38`、`feature/ic-170-s1-first-read` `800791020a8923e44043fea49c9d766a7edcd307`、`feature/ic-171-category-page-trio` `0134c84cb52aea523410ee2f9e05ddd0f54f5d14`、`probe/ic-067-screenshot-subtype` `9db02b93eccbb87d126602901807e70823535111`、`probe/ic-125-sentinel-negative` `402cb6e52a11dc89ce2a8351b47314a5fe9185b8`、`probe/ic-137-media-playback` `486bcb769b59eb1146c5a231c7998847206777cc`、`probe/ic-145-scan-service` `d373afc7125104c01acfc296829229090e6871ce`、`probe/ic-161-similar-photos` `1f8ff9248e312cd4a04faec559ea9f34540b1379`、`probe/ic-162-deck-home-preview` `180b052edf24f168712c6e58754c60b88b342175`、`probe/ic-163-deck-home-preview-r2` `562f8b7afa14508e3efebbd57e980e275946ab95`。

---

## 十一、规格欠账（四条，按卡面第二节照抄，未处理，等决策会话核可后回填 SPEC-S2 v23／S1 v11／S0 v5）

1. SPEC-S2 v22 决策 24（`:81`）与第二节 `:283`——玻璃恒深是新例外，v23 仿决策 61 句式补一条。
2. SPEC-S2 v22 决策 42（`:129`）——改为「玻璃及其前景恒取深色分支（白）」，`:415` 指针随之。
3. SPEC-S1 v10 `:709`——排序／分组菜单改恒深，v11 改注释口径（取值 0.93 不变）。
4. SPEC-S0 v4 `:118`／`:336`——改为「玻璃恒深」。

---

## 十二、③ 登记

- **iOS 26 玻璃（`glassEffect()`）读 SwiftUI 环境还是 UIKit trait**：本次实测**可改记为①**——`s1Helper`（加了 `.environment(\.colorScheme,.dark)` 的 `glassEffect()`）在 `overrideUserInterfaceStyle=.light` 下取得的像素值（78）与真实 `.dark` trait 下裸 `glassEffect(.regular)` 的像素值（`rawGlassReference.dark=78`）**完全相等**，且 `s1Helper` 自身 light/dark 两次也完全相等（78/78）。这是干净的一致证据：**iOS 26 `glassEffect()` 确实读取 SwiftUI 的 `colorScheme` 环境值**（至少在这个最小夹具下如此），候选 (a) 对 iOS 26 玻璃成立。
- **容器层覆盖是否必要**：`s1GlassBadgeOverlay`（容器路径）测得 78/78，与 helper 单独测得的结果一致，本次夹具未设置"不加容器覆盖"的对照，因此仍只能证明"加了之后恒深"，不能排除"不加容器覆盖、只加 helper 覆盖"是否已经够用——**仍为③**，待决策会话判断是否需要额外探针。
- **系统材质（`.ultraThinMaterial`）在 legacy 配方中的行为**：**新增③**（本次红的核心）——`.environment(\.colorScheme, .dark)` 确实让 `s1LegacyChromeGlassBackground` 的渲染结果不再随 `overrideUserInterfaceStyle` 变化（149/149 一致），但该恒定值没有落在"接近深色材质"一侧，而是更接近浅色材质参照值。是否属于"材质不响应 SwiftUI 环境"、还是"材质响应了但被同一视图内的白色叠层层拉偏"，未定，见第七节归因细节。
- **深色玻璃在浅色页面上的观感**：待 H91（本卡未产出可装的 IPA 产物——运行 #350 因 XCTest 红导致构建未签名应用与上传均被跳过；运行 #349 虽有 IPA，但那次提交里新玻璃恒深逻辑尚未包含测试验证且四个子项均已推送完毕，工程上不建议单独拿 #349 的 IPA 做人工判定，是否使用由决策会话定）。

---

## 十三、发现但未处理的问题（按纪律只报告不修）

1. 卡面裁定二的"legacy 红"归因描述与本次实测的具体失败形态（"两侧变一致但落点偏"而非"两侧仍不一致"）有出入，已在第七节详细记录原始数据，未擅自扩展或改写归因结论。
2. `s1LegacyChromeGlassBackground` 内除 `.ultraThinMaterial` 外还叠加了 `Color.white.opacity(S1ChromeGlass.tintOpacity)` 填充与两层白色描边（`innerHighlightTop/Bottom`、`outerRingOpacity`）——这些叠层是否会在任何"材质已读到深色"的情形下仍把中心像素拉向浅色区间，本卡未做拆分验证（例如单独测"裸 `.ultraThinMaterial` + `.environment(.dark)`，不叠加白色层"这一路径），发现但未处理，留待决策会话决定是否需要更细粒度的探针。

---

## 十四、人工判定项（H91 七条，原样列出，留给 Lynn；本卡未产出可装产物，暂无法组织真机判定）

1. 「空间清理」首页与类别页：垃圾桶、账户、返回、排序、「全选」等圆钮与底栏、收起导航条的玻璃，浅色模式下和深色模式下看起来一样（深色玻璃），不再发白。
2. 「逐张整理」页：顶上排序钮、中间分组胶囊、垃圾桶钮是深色玻璃、图标与文字是白色，放在浅色页面上看得清；受限授权提示条、加载／失败态按钮同样。
3. 看图页（S2）：顶排、底排、中央指示、教程提示卡都是深色玻璃；相簿 sheet 里教程第 5 步的提示条是深色。
4. 「逐张整理」点排序钮、点分组胶囊：两只下拉菜单都是深色底白字，选中项仍是强调色；菜单边缘在浅色页面上是否清楚（描边为黑，深底上几乎看不见）。
5. 写回失败 toast（S1、S2 各一处，能触发就看）：深色底白字。
6. 确认页、结果页（S3／S4／S5）顶排玻璃同为深色。
7. 一两句总评：深色玻璃放在浅色页面上的观感能不能接受——不能接受的话，下一步是 5.4 画布轮里连页面一起定。

---

## 十五、40 位 SHA 核验（`git cat-file -e <sha>^{<类型>}`）

| SHA | 类型 | 核验结果 |
|---|---|---|
| `467fe74a0323c98e938142a2107f16843d21cc96` | commit | 见下方命令输出 |
| `e356aeda17da53a064892e04f39bea1032f5bf8d` | commit | 同上 |
| `6308693920a4e180f74559549c2606b8539d1ba0` | commit | 同上 |
| `e89b95a248e6bc47224c4c7c3929b196b3219794` | commit | 同上 |
| `df10428b74d3e0547dcbe4a30a8623dd14cc236b` | commit | 同上 |
| `a01ffe616396750a091c8d22dd8497d9f4983922` | commit | 同上 |
| `b49a40de20a2790da747428bce3ae423d316e20d` | blob | 同上 |
| `99dd6a9ba1170c3b3dcedc26fec2e22850912eb3` | blob | 同上 |
| `bea3bf09887428db76827877408a27b09ecf0bb3` | blob | 同上 |

（命令输出见 `change-list.md` 末尾附録；本报告写完后已逐一执行 `git cat-file -e`，全部返回退出码 0。）
