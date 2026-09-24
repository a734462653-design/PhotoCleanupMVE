# IC-172 自验报告

## 一、结论（先行）

- **停卡上报，未合并，CI 预算三次用尽。** 分支 `feature/ic-172-glass-always-dark`：子项 A→B→C 推送 CI **#349 一次绿（892／0）**；子项 D 推送 CI **#350 一次红（898／1）**；追加子项 D′（决策会话下发，改用与产品代码同构的参照写法）推送 CI **#351 一次红（898／1，同一用例）**。三次 CI 已用尽（纪律 2），按 D′ 节第 5 条与模型阶梯补偿条款，**执行端不再推、不合并、不自行修改代码或测试**，就此停卡上报。
- **五个提交交付到分支**：A `6308693920a4e180f74559549c2606b8539d1ba0`、B `e89b95a248e6bc47224c4c7c3929b196b3219794`、C `df10428b74d3e0547dcbe4a30a8623dd14cc236b`、D `a01ffe616396750a091c8d22dd8497d9f4983922`、D′ `c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3`。另有一份中途停卡报告提交 `5d581608e94e313230020f959ed172f8f792db51`（已被本次完整版报告替换，纪律 6）。
- **A、B、C 的产品改动逐字节核验与卡面代码块一致**（详见第四节），**未受本次 D′ 事件影响**——两次红均落在测试断言本身，产品代码（`S1View.swift`／`S2View.swift`）自子项 C 提交后再未改动。
- **D′ 的新发现比"写法不同"假说更复杂，如实记录，不代为下结论**：
  - #350 用裸 `.background(.ultraThinMaterial, in: Capsule())` 做参照（无覆盖），测得 `light=169 dark=99`；`s1Legacy`（fill 写法 + `.environment(.dark)` 覆盖）两侧恒为 `149`。决策会话的假说是"两种写法（`.background(_:in:)` vs `.background{fill}`）本身渲染不同，不能拿前者当参照"。
  - D′ 把参照换成与产品 `s1LegacyChromeGlassBackground` **同构的 `.background{ Capsule().fill(...) }` 写法、不加覆盖**（`legacyCenterReference`），实测 `light=172 dark=104`。
  - **这组新数据没有支持"写法不同导致数值差异"的假说，反而推翻了它**：`legacyCenterReference`（fill 写法，无覆盖，真实深色 trait）= **104**，与 `material`（`.background(_:in:)` 写法，无覆盖，真实深色 trait）= **99** 非常接近（差 5）——**两种写法在真实深浅色 trait 驱动下渲染结果几乎相同**，并不存在假说所说的"两种写法渲染不同"。真正的差异在别处：`s1Legacy`（fill 写法 + `.environment(\.colorScheme, .dark)` 覆盖）= **149**，既不接近 `material.dark`(99) 也不接近 `legacyCenterReference.dark`(104)，而是明显偏向浅色一侧（`material.light=169`、`legacyCenterReference.light=172`）。
  - 换言之：**`.environment(\.colorScheme, .dark)` 确实让 legacy 组合视图的渲染在两种 `overrideUserInterfaceStyle` 下变得一致（149/149，不再随外层 trait 变化），但这个一致后的取值并不等于"真实深色 trait 下同一份 fill 写法"应有的取值（104）**，反而更接近"真实浅色 trait"的取值。第二条断言 `abs(legacy.light - reference.dark) ≤ 3` 因此仍然判红（`|149-104|=45`）。
  - **本卡截至预算用尽，未能确定这一差距（149 vs 104，约 45 个灰度单位）的根因**——可能候选包括（③，均未验证）：`.environment(\.colorScheme, .dark)` 对 `Material`/`UIVisualEffectView` 桥接只起到部分作用（例如只影响 SwiftUI 侧颜色解析，不完全等价于让底层 `UITraitCollection` 认为自己处于 dark）；或该覆盖对 `Material` 根本不生效、149/149 的"恒定"只是巧合或测试时序artefact；或 legacy recipe 里 `Color.white.opacity(S1ChromeGlass.tintOpacity)` 等叠层与 Material 合成的方式在"环境覆盖下的深色"与"真实深色 trait"之间存在非线性差异。**执行端不具备进一步验证手段（本机无 Xcode、CI 预算已尽），如实登记为③，留给决策会队判断。**
- **iOS 26 `glassEffect()`（helper 与容器路径）两次红都未受影响、持续通过**：`s1Helper`／`s1GlassBadgeOverlay` 在 #350、#351 两次运行中均为 `78/78`，与真实深色 trait 下裸 `glassEffect(.regular)`（`rawGlassReference.dark=78`）逐像素相等。**这部分结论保持稳固：候选 (a) 对 iOS 26 Liquid Glass 成立，可信度①**。存疑的只是候选 (a) 对 iOS 17-25 回落材质（`Material`/`.ultraThinMaterial`）路径是否真正达到「渲染上等价于深色」，而不只是「不再随外层 trait 变化」。
- **G967 两次均不满足**（#350 898／1、#351 898／1）——**未触发合并**，`main` 保持 `467fe74a0323c98e938142a2107f16843d21cc96` 不变。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260924-172-glass-always-dark.md`（含决策会话追加的「## 追加 · 子项 D′」一节） |
| 调研 | `<top>/Tasks/RESEARCH-IC-171-glass-facts.md` |
| 复核 | `<top>/Tasks/REVIEW-IC-172-findings.md`（主卡，两轮）、`<top>/Tasks/REVIEW-IC-172-dprime.md`（D′，一轮，结论「可以下发」） |
| 基线 `main`（本地与远端一致，全程未变） | `467fe74a0323c98e938142a2107f16843d21cc96` |
| 开工核对 1 | `git status --porcelain` 空（纪律 8） |
| 开工核对 2 | `git merge-base --is-ancestor e356aeda17da53a064892e04f39bea1032f5bf8d main` 退出码 0 |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `467fe74a0323c98e938142a2107f16843d21cc96` = 本地 |
| 分支 | `feature/ic-172-glass-always-dark`（自上述基线 `git switch -c` 切出） |
| 分支 tip（当前，未合并） | `c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3` |
| `schemaVersion` | 7（未动） |
| `cacheSchemaVersion` | 1（未动） |
| `S0DeckMetrics` 登记值 | 195（未动） |
| 文案目录 | 259（`s0.` 41，未动） |
| **是否合并** | **否——G967 两次均不满足，`main` 保持 `467fe74a…` 不变** |
| **docs 提交（合并后惯例 44）** | 不适用（未合并） |
| **CI 预算** | 3／3 已用尽（#349、#350、#351） |

---

## 三、提交列表

| 序 | 提交 SHA | 内容 |
|---|---|---|
| A | `6308693920a4e180f74559549c2606b8539d1ba0` | 两个玻璃 helper（`s1/s2ChromeGlassBackground` 与 `s1/s2LegacyChromeGlassBackground`）各在返回子树链尾追加 `.environment(\.colorScheme, .dark)` |
| B | `e89b95a248e6bc47224c4c7c3929b196b3219794` | 五个玻璃容器（S1 `chromeBar`／`s1GlassBadgeOverlay`／`s1GlassBadgeHost`，S2 `topBar`／`actionBar`）容器链尾各加同一覆盖 |
| C | `df10428b74d3e0547dcbe4a30a8623dd14cc236b` | 四处系统材质（S1 写回失败 toast、S1 排序／分组菜单 `menuContainer`；S2 写回失败 toast、S2 相簿 sheet 教程提示条）材质之后加同一覆盖 |
| D | `a01ffe616396750a091c8d22dd8497d9f4983922` | 新增 `IC172GlassAlwaysDarkTests.swift`（决策会话生成，逐字节拷入，旧版 hash `b49a40de20a2790da747428bce3ae423d316e20d`）+ pbxproj 登记 |
| D′ | `c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3` | `testIC172A_S1LegacyRecipeIsDarkInBothStyles` 参照改为与产品代码同构的 `.background{ Capsule().fill(...) }` 写法（新版 hash `2c119e174af05d1da15b234720ebbc6e8f205586`）；产品代码、pbxproj、其余五条测试一字不动 |
| （已作废） | `5d581608e94e313230020f959ed172f8f792db51` | 中途停卡报告提交（#350 红后所写），内容已被本报告完整替换 |

四个产品/测试子项提交与 D′ 均已用 `git cat-file -e` 核验存在（第十四节）。

---

## 四、子项 A～C 计数实测表（卡面值 / 实测值逐条对读）

方法：`Tasks/decision-tools/scan.py`（`git show <rev>:<path>` 只读）+ `strip.py`（`strippedSource` 同口径）对各子项提交做剔注释计数；另用 `Tasks/decision-tools/check_ic172.py <commit> <stage>` 做「产品文件 blob == 对基线程序化套用卡面 `ic172_edits.py` 中 old→new 替换后的 blob」强校验。**D′ 只改测试文件，不影响本节结果**（第四节数据在 D′ 之前已核验，产品代码自 C 之后未再改动）。

### 子项 A（commit `6308693`）—— `check_ic172.py 6308693 A`：26 项 PASS / 26

| needle | 文件 | 卡面「改后」值 | 实测值（剔注释） |
|---|---|---|---|
| `.environment(\.colorScheme, .dark)` / `colorScheme` | S1View.swift | 0→2 | 2 |
| `.environment(\.colorScheme, .dark)` / `colorScheme` | S2View.swift | 0→2 | 2 |
| `GlassEffectContainer {` | S1/S2View.swift | 3／2（不变） | 3／2 |
| `#available` | S1/S2View.swift | 4／3（不变） | 4／3 |
| `Material` | S1/S2View.swift | 3／6（不变） | 3／6 |
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
| 子项 A 其余全部 needle | 两文件 | 不变 | 不变 |

### 子项 C（commit `df10428`）—— `check_ic172.py df10428 C`：30 项 PASS / 30（含两处 blob 强校验）

| 项 | 卡面值 | 实测值 |
|---|---|---|
| blob S1View.swift == 卡面 A/B/C 编辑累积套用基线后的 blob | 相等 | **相等**（`99dd6a9ba1170c3b3dcedc26fec2e22850912eb3`） |
| blob S2View.swift == 同上 | 相等 | **相等**（`bea3bf09887428db76827877408a27b09ecf0bb3`） |
| `colorScheme, .dark)` | S1 5→7、S2 4→6 | 7／6 |
| `.background(.regularMaterial)`（无 `in:`，S2 标定面板，不纳入） | 3（不变） | 3 |
| 其余全部 needle | 不变 | 不变 |

**结论：子项 A、B、C 三个提交的产品文件与卡面 26 处代码块逐字节等价，无一处偏离；D、D′ 均未再改动产品代码。**

---

## 五、测试文件与 pbxproj 校验

- **D（旧版）**：`git hash-object` = `b49a40de20a2790da747428bce3ae423d316e20d`，与卡面要求值一致；`cp` 拷入未改任何一行；无 CRLF；364 行；6 个 `func test`。
- **D′（新版，覆盖同一文件）**：`git hash-object` = `2c119e174af05d1da15b234720ebbc6e8f205586`，与决策会话指定值一致；`cp` 覆盖未手工改动任何一行；`git diff --name-only 5d58160..c1ca74f` 恰 1 路径（仅测试文件）。diff 范围核对与 `REVIEW-IC-172-dprime.md` 第一节描述完全一致：只改 `testIC172A_S1LegacyRecipeIsDarkInBothStyles` 后半段（参照变量 `material`→`reference`、构造改为 fill 写法、断言从 1 条改 2 条），前半段与其余五条测试逐字节未动。
- pbxproj：新增 `fileRef 100000000000000000000075`（占 3 处）、`buildFile 200000000000000000000072`（占 2 处），定义行 `uniq -d` 为空，无撞号（D′ 未再改动 pbxproj）。
- 白名单路径核对：`git diff --name-only 467fe74a..c1ca74f` = `PhotoCleanupMVE.xcodeproj/project.pbxproj`、`PhotoCleanupMVE/Features/S1/S1View.swift`、`PhotoCleanupMVE/Features/S2/S2View.swift`、`PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift`、`Reports/IC-172/change-list.md`、`Reports/IC-172/self-check.md` —— 恰 4 产品/测试路径 + `Reports/IC-172/` 目录 2 个文件，与 D′ 节第 6 条改读的 G966 口径（「恰 4 路径 + `Reports/IC-172/`」）一致。

---

## 六、摘取关系实测（惯例 40，克隆内验证，A/B/C，D′ 前完成）

在临时克隆内，从基线 `467fe74a` 分别单独 cherry-pick：`6308693`（A 单独，成功，`2 files changed, 10 insertions(+)`）、`e89b95a`（B 单独，成功，`Auto-merging` 无冲突）、`df10428`（C 单独，成功，`Auto-merging` 无冲突）。三者均可独立、干净地摘到基线上。

---

## 七、CI 结果（三次，预算用尽）

### 运行一：#349（run id `35986967001`），commit `df10428b74d3e0547dcbe4a30a8623dd14cc236b`（A→B→C）

- 结论：`completed` / `success`，全部 12 步骤 `success`
- **XCTest 执行摘要**：`Executed 892 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 892 tests / 0 failures`
- **XCTest 分段耗时**：`模拟器启动 80 s；xcodebuild test 335 s；总 416 s`
- **未签名 IPA 校验**：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1862103，SHA-256=ca665a10f5963c3d0ff06164c18c33773be6600f18176a369e2ac95e55218c10`
- artifact：`PhotoCleanupMVE-unsigned-df10428b74d3`，id `10803095716`，`1862273` 字节，有效期至 `2026-12-23T10:23:48Z`
- `IC172_PROBE` 行：0（该提交尚未含新测试文件，预期结果）

### 运行二：#350（run id `35988265755`），commit `a01ffe616396750a091c8d22dd8497d9f4983922`（D，旧版测试）

- 结论：`completed` / `failure`；步骤 9「运行 XCTest」`failure`，步骤 10/11 `skipped`（无 IPA）
- 真实退出码：`Process completed with exit code 65`
- **XCTest 执行摘要**：`Executed 898 tests, 1 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 898 tests / 1 failures`
- **XCTest 分段耗时**：`模拟器启动 68 s；xcodebuild test 336 s；总 405 s`
- **失败注解原文**：
  1. `Process completed with exit code 65.`
  2. `XCTest 失败 | ** TEST FAILED **`
  3. `XCTest 失败 | /Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift:101: error: -[PhotoCleanupMVETests.IC172GlassAlwaysDarkTests testIC172A_S1LegacyRecipeIsDarkInBothStyles] : XCTAssertLessThan failed: ("50") is not less than ("20") - 浅色外观下回落配方更接近浅色材质`
  4. `XCTest 失败 | Test Case '-[PhotoCleanupMVETests.IC172GlassAlwaysDarkTests testIC172A_S1LegacyRecipeIsDarkInBothStyles]' failed (0.983 seconds).`
- **全部 `IC172_PROBE` 行原文**（下载整包日志、Python `zipfile` 读取 `9_运行 XCTest.txt`，共 7 行）：

```
2026-09-24T10:43:08.2412210Z IC172_PROBE arm=material light=169 dark=99
2026-09-24T10:43:08.6953810Z IC172_PROBE arm=rawGlass light=246 dark=78
2026-09-24T10:43:09.1986770Z IC172_PROBE arm=s1Helper light=78 dark=78
2026-09-24T10:43:09.6370340Z IC172_PROBE arm=rawGlassReference light=246 dark=78
2026-09-24T10:43:10.1512360Z IC172_PROBE arm=s1Legacy light=149 dark=149
2026-09-24T10:43:10.6442820Z IC172_PROBE arm=materialReference light=169 dark=99
2026-09-24T10:43:11.1915700Z IC172_PROBE arm=s1GlassBadgeOverlay light=78 dark=78
```

### 运行三：#351（run id `35991746708`），commit `c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3`（D′，新版测试，本卡第 3 次也是最后一次 CI）

- 结论：`completed` / `failure`；步骤 9「运行 XCTest」`failure`，步骤 10/11 `skipped`（无 IPA）
- 真实退出码：`Process completed with exit code 65`
- **XCTest 执行摘要**：`Executed 898 tests, 1 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 898 tests / 1 failures`
- **XCTest 分段耗时**：`模拟器启动 91 s；xcodebuild test 341 s；总 433 s`
- **失败注解原文**：
  1. `Process completed with exit code 65.`
  2. `XCTest 失败 | ** TEST FAILED **`
  3. `XCTest 失败 | /Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift:112: error: -[PhotoCleanupMVETests.IC172GlassAlwaysDarkTests testIC172A_S1LegacyRecipeIsDarkInBothStyles] : XCTAssertLessThanOrEqual failed: ("45") is greater than ("3") - 浅色外观下回落配方不是深色模式的效果`
  4. `XCTest 失败 | Test Case '-[PhotoCleanupMVETests.IC172GlassAlwaysDarkTests testIC172A_S1LegacyRecipeIsDarkInBothStyles]' failed (1.020 seconds).`
- **全部 `IC172_PROBE` 行原文**（同上方法，共 7 行，含新增 `legacyCenterReference`）：

```
2026-09-24T11:20:31.6568170Z IC172_PROBE arm=material light=169 dark=99
2026-09-24T11:20:32.2172720Z IC172_PROBE arm=rawGlass light=246 dark=78
2026-09-24T11:20:32.6901990Z IC172_PROBE arm=s1Helper light=78 dark=78
2026-09-24T11:20:33.2014730Z IC172_PROBE arm=rawGlassReference light=246 dark=78
2026-09-24T11:20:33.7072720Z IC172_PROBE arm=s1Legacy light=149 dark=149
2026-09-24T11:20:34.2257460Z IC172_PROBE arm=legacyCenterReference light=172 dark=104
2026-09-24T11:20:34.7850840Z IC172_PROBE arm=s1GlassBadgeOverlay light=78 dark=78
```

---

## 八、归因（③，三次运行数据合并对读，不代为下结论）

| 探针 | #350 值 | #351 值 | 说明 |
|---|---|---|---|
| `material`（`.background(_:in:)`，无覆盖） | light=169 dark=99 | light=169 dark=99 | 正对照，两次一致 |
| `rawGlass`／`rawGlassReference`（裸 `glassEffect`，无覆盖） | light=246 dark=78 | light=246 dark=78 | 正对照，两次一致 |
| `s1Helper`（`glassEffect` + `.environment(.dark)`） | light=78 dark=78 | light=78 dark=78 | **稳定通过**：与 `rawGlassReference.dark` 逐像素相等 |
| `s1GlassBadgeOverlay`（容器路径，含 `glassEffect`） | light=78 dark=78 | light=78 dark=78 | **稳定通过**：与 helper 单独测得的结果一致 |
| `s1Legacy`（fill 写法 + `.environment(.dark)`） | light=149 dark=149 | light=149 dark=149 | 两次一致：覆盖使其不再随 `overrideUserInterfaceStyle` 变化，但取值恒为 149 |
| `materialReference`（#350，`.background(_:in:)`，无覆盖，与 `material` 同构写法） | light=169 dark=99 | — | 用于 #350 判断"legacy 更接近浅色/深色材质" |
| `legacyCenterReference`（#351，fill 写法，无覆盖） | — | light=172 dark=104 | 用于 #351 判断"legacy 是否落在深色 fill 写法附近" |

**关键结论（①，两轮数据交叉验证）**：

1. **`material`（169/99）与 `legacyCenterReference`（172/104）高度接近**（差 3、差 5）——证明**"两种写法（`.background(_:in:)` vs `.background{fill}`）本身渲染不同"这一假说不成立**，在真实系统 trait 驱动、不加任何 SwiftUI 环境覆盖的前提下，两种写法的中心像素值几乎一样。D′ 节给出的"唯一的红是参照写法不同"这一归因，**被本次实测数据推翻**。
2. **`s1Legacy`（恒 149）既不接近 `material.dark`(99)，也不接近 `legacyCenterReference.dark`(104)，而是介于两者的浅色端与深色端之间、更偏向浅色一侧**（`material.light=169`、`legacyCenterReference.light=172`，与 149 的差距 20/23，小于与深色端的差距 50/45）。
3. iOS 26 `glassEffect()` 路径（`s1Helper`、`s1GlassBadgeOverlay`）在两次运行中都精确复现「与真实深色 trait 完全相等」，候选 (a) 对该路径**成立，可信度①**。
4. iOS 17-25 回落路径（`Material`/`.ultraThinMaterial`）的行为**仍是③、未闭合**：`.environment(\.colorScheme, .dark)` 确实让其渲染不再随外层 `overrideUserInterfaceStyle` 变化（两次都验证到 149/149 恒定），但恒定后的取值既不是"真实深色 trait 下同一份代码"的取值（104），也不是"真实浅色 trait 下同一份代码"的取值（172），而是介于两者之间、偏浅色一侧的第三个值。**执行端未能在预算内确定这第三个值的成因**——候选解释（均未验证，仅供决策会话参考）：
   - `.environment(\.colorScheme, .dark)` 对 SwiftUI `Material` 类型的桥接可能只部分生效（例如影响某些子组件的颜色解析，但 `UIVisualEffectView` 自身的模糊/色调仍部分依赖独立的 trait 解析路径，产生一个"半深半浅"的混合渲染）；
   - 149 这个值也可能和 `Color.white.opacity(S1ChromeGlass.tintOpacity)`（legacy 配方在 material 之上叠加的白色调层）与"部分生效的深色材质"混合后的合成结果有关，但两次探针都没有单独测试"仅 `.ultraThinMaterial` + `.environment(.dark)`、不叠加白色调层"这一隔离变量，无法证实或证伪；
   - 也可能与 SwiftUI 对 `.environment()` 覆盖在 `background{ }` 多层闭包内的传播时序、或本测试夹具（`UIHostingController` + `RunLoop.main.run(until:)` 等待 0.2 秒）与实际渲染管线的同步问题有关。
5. **本卡的产品结论（写在第一节）保持有效范围仅限于 iOS 26 `glassEffect()` 路径**；iOS 17-25 回落路径（`Material`）「是否真正达到深色效果、还是只是不再变化」尚待确认，是否影响卡内裁定 一/二/三/四的产品判断（例如是否需要给 legacy 路径换一种实现方式，而非仅追加 `.environment()`），留给决策会话判断。

---

## 九、本地门禁（五个提交各一次，均为工作树内真实执行，退出码均为 0）

| 子项 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A | 0 | 0 | 0 |
| B | 0 | 0 | 0 |
| C | 0 | 0 | 0 |
| D | 0 | 0 | 0 |
| D′ | 0 | 0 | 0 |

---

## 十、闸门结果

| 闸门 | 结果 | 依据 |
|---|---|---|
| **G963**（helper） | **不满足** | helper（`testIC172A_S1GlassHelperIsDarkInBothStyles`）两次运行均通过；legacy（`testIC172A_S1LegacyRecipeIsDarkInBothStyles`）两次运行均未通过（#350 旧参照红、#351 新参照仍红） |
| **G964**（容器） | 满足 | `testIC172B_GlassContainerPathIsDarkInBothStyles` 两次运行均通过 |
| **G965**（材质） | 满足 | `testIC172ABC_SourceWiring` 两次运行均未在失败列表中；IC148/IC156 正对照未见失败 |
| **G966**（白名单外零改动） | 满足 | `git diff --name-only 467fe74a..c1ca74f` 恰 4 产品/测试路径 + `Reports/IC-172/` 2 文件，与 D′ 节改读口径一致；十八条被保护分支 tip 未变（第十一节） |
| **G967**（合并前置，D′ 节改读） | **不满足** | 要求「#349 绿 892／0 + D′ 那次绿 898／0」，实测 D′ 那次（#351）为 898／1——不满足 |
| **G968**（合并后运行） | 不适用 | 未合并 |

---

## 十一、十八条被保护分支 tip（`git ls-remote origin` 现取核对，全部未变）

`feature/ic-089-nx-edge-bounce` `b368a6caee846e664391b0620350395bfe6fbc7f`、`feature/ic-091-nx-midgesture-handoff` `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`、`feature/ic-092-nx-window-follow` `a7cc1ec727a3a493f5263e688a316cbf4c743562`、`feature/ic-158-diagnostic-progress-clamp` `5cb67332437a446d98733ddc942e2905392d2891`、`feature/ic-164-pick-ic163-a-d` `cc85fa4a7cfa272092a3acfade432d13de7e4e0b`、`feature/ic-165-deck-formal` `dc7e49459f15fb6227c3f34903357ae490aaa7ed`、`feature/ic-166-rest-category-and-lib` `2734ccd0ef2f12fa4ce115f0136777321a96c548`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd1436fa25b8298caca2f3d2266024859df4e`、`feature/ic-168-s2-exit-diagnostics` `e7c1be085102b5d9685b0863f29feb6bfa006a38`、`feature/ic-170-s1-first-read` `800791020a8923e44043fea49c9d766a7edcd307`、`feature/ic-171-category-page-trio` `0134c84cb52aea523410ee2f9e05ddd0f54f5d14`、`probe/ic-067-screenshot-subtype` `9db02b93eccbb87d126602901807e70823535111`、`probe/ic-125-sentinel-negative` `402cb6e52a11dc89ce2a8351b47314a5fe9185b8`、`probe/ic-137-media-playback` `486bcb769b59eb1146c5a231c7998847206777cc`、`probe/ic-145-scan-service` `d373afc7125104c01acfc296829229090e6871ce`、`probe/ic-161-similar-photos` `1f8ff9248e312cd4a04faec559ea9f34540b1379`、`probe/ic-162-deck-home-preview` `180b052edf24f168712c6e58754c60b88b342175`、`probe/ic-163-deck-home-preview-r2` `562f8b7afa14508e3efebbd57e980e275946ab95`。

---

## 十二、规格欠账（四条，按卡面第二节照抄，未处理，未回填 SPEC）

1. SPEC-S2 v22 决策 24（`:81`）与第二节 `:283`——玻璃恒深是新例外，v23 仿决策 61 句式补一条。
2. SPEC-S2 v22 决策 42（`:129`）——改为「玻璃及其前景恒取深色分支（白）」，`:415` 指针随之。
3. SPEC-S1 v10 `:709`——排序／分组菜单改恒深，v11 改注释口径（取值 0.93 不变）。
4. SPEC-S0 v4 `:118`／`:336`——改为「玻璃恒深」。

**未合并，以上四条暂不回填（回填只在合并且决策会队核可产品结论闭合之后进行）。**

---

## 十三、发现但未处理的问题（按纪律只报告不修）

1. **D′ 节的产品结论（"覆盖对系统材质同样生效"）与 #351 实测数据不完全吻合**：D′ 节判断依据的两个数字（`s1Legacy=149` 恒定、旧参照 `material.dark=99`）只能说明"149 与 99 不同"，但不能反推"149 就是覆盖正确生效后的深色值"——需要一个"真实深色 trait + 同构写法"的第三方数据点（即 D′ 自己新增的 `legacyCenterReference`）才能验证，而这个数据点（104）恰恰显示 149 离深色更远、离浅色更近。这一点在 D′ 节下发时（依据 #350 单次数据做归因）尚不可见，**是本卡执行过程中随新证据出现而产生的新发现，不是决策会话或执行端任何一方在下发/执行当时能够预判的**，如实记录。
2. **legacy 恒定值（149）与真实深浅色 trait 值（104/172）之间约 45～23 个灰度单位差距的根因未查明**——需要进一步的隔离变量探针（例如单独测"裸 `.ultraThinMaterial` + `.environment(.dark)`，不叠加白色调层"）才能定位，本卡 CI 预算已尽，未做。
3. CI 预算用尽前的探索路径（先怀疑写法差异，验证后被推翻）已经消耗了全部三次 CI 机会；如果决策会队希望继续排查，需要开一张新卡而非在本卡内继续尝试（纪律 2）。

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

## 十五、40 位 SHA 核验（`git cat-file -e <sha>^{<类型>}`，全部执行、全部退出码 0）

| SHA | 类型 |
|---|---|
| `467fe74a0323c98e938142a2107f16843d21cc96` | commit |
| `e356aeda17da53a064892e04f39bea1032f5bf8d` | commit |
| `6308693920a4e180f74559549c2606b8539d1ba0` | commit |
| `e89b95a248e6bc47224c4c7c3929b196b3219794` | commit |
| `df10428b74d3e0547dcbe4a30a8623dd14cc236b` | commit |
| `a01ffe616396750a091c8d22dd8497d9f4983922` | commit |
| `5d581608e94e313230020f959ed172f8f792db51` | commit |
| `c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3` | commit |
| `b49a40de20a2790da747428bce3ae423d316e20d` | blob |
| `2c119e174af05d1da15b234720ebbc6e8f205586` | blob |
| `99dd6a9ba1170c3b3dcedc26fec2e22850912eb3` | blob |
| `bea3bf09887428db76827877408a27b09ecf0bb3` | blob |

命令与结果见 `change-list.md` 末尾。
