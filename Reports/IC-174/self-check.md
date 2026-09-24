# IC-174 自验报告

## 一、结论（先行）

**已合并、已推送、合并后运行绿。** 分支 `feature/ic-174-glass-always-dark-reissue` 四个子项提交 A→B→C→D 一起推送，CI **#353 一次绿（899／0）**；`--no-ff` 合并入 `main`（合并提交 `39dc8d0be448ea051f37fdb99be8dbae3d35ca35`）并推送；合并后 `main` 自动运行 **#354 绿（899／0）**。CI 预算 1／3（一次即绿，未再用）。

- **本卡是 IC-172 的重发**：IC-172 的产品改动 A／B／C（`6308693`／`e89b95a`／`df10428`）经决策会话逐阶段验收、blob 恰等于卡面改法，`feature/ic-172-glass-always-dark` 分支 CI #349 绿 892／0；但该分支子项 D 的旧版测试（v1 `b49a40de…`）与追加的 D′（v2 `2c119e17…`）分别在 #350、#351 两次红在同一条断言 `testIC172A_S1LegacyRecipeIsDarkInBothStyles`（先后两种"参照"写法都与产品实际渲染不同构），三次 CI 预算用尽，IC-172 停卡未合并（`git show 3cf4833:Reports/IC-172/self-check.md`）。IC-173 探针（分支 `probe/ic-173-material-dark-env`，唯一测试提交 `833e74cea6524ac5c5f860ae50d71656f54ec457`，CI **#352 绿 898／0**）用 27 行 `IC173_PROBE` 数据证实：`.environment(\.colorScheme, .dark)` 对系统材质（`Material`）与对 iOS 26 `glassEffect` 一样，逐像素等于系统深色（裸 `.ultraThinMaterial` 169／99 → 加覆盖后两侧恒 99；`.regularMaterial` 224／64 → 64／64；S1 菜单配方 249／7 → 7／7）；且产品回落配方 `s1LegacyChromeGlassBackground` 在未加覆盖的 `main` 基线上，其系统深色渲染值本就是 **149**（IC-173 M09：197／149），IC-172 加覆盖后两侧也都是 149——**两侧相同且恰好落在这个"深色"值上**，此前两次红只是决策会话选错了参照对象（拿裸材质或手写中心层拷贝当参照，而这两种写法与 `s1LegacyChromeGlassBackground` 本体的实际渲染并不同构），并非产品代码或覆盖机制有问题。
- **本卡的 v3 测试文件（`c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2`，7 条测试）** 把那条有问题的断言改名为 `testIC172A_S1LegacyRecipeIgnoresInterfaceStyle`，只断言"两侧相同"（不再拿任何独立写法的参照去核对具体数值是否为"深色"），并新增 `testIC172C_MaterialRecipesUnderOverrideAreSystemDark` 用 toast／教程提示条／S1 菜单三组"同一棵树、只差一个覆盖修饰符"的正确参照，逐一验证材质覆盖恒等于同棵树的系统深色渲染。**本卡 CI 一次即绿，验证了这一改法成立。**
- **A、B、C 三个提交与 IC-172 对应提交（`6308693`／`e89b95a`／`df10428`）逐字节 cherry-pick、blob 完全相等**；D 用 `cherry-pick -n a01ffe6` 摘取 pbxproj 登记与占位测试文件后，用 `cp` 以 v3 覆盖测试文件，`git hash-object` 核验后再提交。
- 产品代码结论范围**扩大到系统材质路径**：iOS 26 `glassEffect()` 路径（`s1Helper`／`s1GlassBadgeOverlay`，恒 78／78）与 iOS 17-25 回落材质路径（`s1Legacy`／toast／教程提示条／S1 菜单，均恒等于同棵树系统深色值）**在本次 CI 中均证实**候选 (a)（只包玻璃自身、覆盖写在链尾）对两条路径都成立，可信度①。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 本卡任务卡 | `<top>/Tasks/IC-20260924-174-glass-always-dark-reissue.md` |
| 前置阅读 | `<top>/CLAUDE.md`；IC-172 卡 `<top>/Tasks/IC-20260924-172-glass-always-dark.md`；IC-172 停卡报告 `git show 3cf4833:Reports/IC-172/self-check.md`；IC-173 探针报告 `git show probe/ic-173-material-dark-env:Reports/IC-173/self-check.md`；复核 `<top>/Tasks/REVIEW-IC-174-findings.md`（结论：可以下发） |
| 基线 `main`（开工时） | `467fe74a0323c98e938142a2107f16843d21cc96` |
| 开工核对 1 | `git status --porcelain` 空 |
| 开工核对 2 | `git ls-remote origin refs/heads/main` = `467fe74a0323c98e938142a2107f16843d21cc96`，与本地一致 |
| 开工核对 3 | 四个源提交 `git cat-file -e` 均存在：`6308693920a4e180f74559549c2606b8539d1ba0`、`e89b95a248e6bc47224c4c7c3929b196b3219794`、`df10428b74d3e0547dcbe4a30a8623dd14cc236b`、`a01ffe616396750a091c8d22dd8497d9f4983922` |
| 分支 | `feature/ic-174-glass-always-dark-reissue`，`git switch -c` 自上述基线切出（先切分支，再做任何 cherry-pick） |
| `schemaVersion` | 7（未动） |
| `cacheSchemaVersion` | 1（未动） |
| `S0DeckMetrics` 登记值 | 195（未动） |
| 文案目录 | 259（未动） |
| **是否合并** | **是** —— `--no-ff` 合并提交 `39dc8d0be448ea051f37fdb99be8dbae3d35ca35`，父提交 `467fe74a0323c98e938142a2107f16843d21cc96`（合并前 main）与 `bd4e213d22d5bcd0723347b27aa2e4a89c97c46f`（分支 tip，即 D 提交） |
| 合并后 `main` | `39dc8d0be448ea051f37fdb99be8dbae3d35ca35`（已推送） |
| **docs 提交（惯例 44）** | 本报告与 `change-list.md` 在合并与合并后运行之后，直接在 `main` 上追加恰一个 docs 提交（见第十节） |
| **CI 预算** | 1／3（A→B→C→D 一起推一次即绿，未再用） |

---

## 三、提交列表（全部 40 位 SHA 均来自实读命令输出，见第十四节核验）

| 序 | 提交 SHA | 摘取来源 | 内容 |
|---|---|---|---|
| A | `32a7a2c03bf00cd51e9b304a34c94f413776c4f2` | `git cherry-pick -x 6308693920a4e180f74559549c2606b8539d1ba0` | 两个玻璃 helper（`s1/s2ChromeGlassBackground` 与 `s1/s2LegacyChromeGlassBackground`）各在返回子树链尾追加 `.environment(\.colorScheme, .dark)` |
| B | `1d88203a1fc37389c745f3aa8e434cce738ef04b` | `git cherry-pick -x e89b95a248e6bc47224c4c7c3929b196b3219794` | 五个玻璃容器（S1 `chromeBar`／`s1GlassBadgeOverlay`／`s1GlassBadgeHost`，S2 `topBar`／`actionBar`）容器链尾各加同一覆盖 |
| C | `bc9552277c072eb5d7aafcdd0d37af347009e269` | `git cherry-pick -x df10428b74d3e0547dcbe4a30a8623dd14cc236b` | 四处系统材质（S1 写回失败 toast、S1 排序／分组菜单 `menuContainer`；S2 写回失败 toast、S2 相簿 sheet 教程提示条）材质之后加同一覆盖 |
| D | `bd4e213d22d5bcd0723347b27aa2e4a89c97c46f` | `git cherry-pick -n a01ffe616396750a091c8d22dd8497d9f4983922`（摘取 pbxproj 登记与 v1 占位测试文件）+ `cp` 以 v3（`<top>/Tasks/decision-tools/IC172GlassAlwaysDarkTests.swift`）覆盖测试文件后提交 | 新增 `IC172GlassAlwaysDarkTests.swift`（v3，`c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2`，7 条测试）+ pbxproj 登记（fileRef `…075`、buildFile `…072`） |
| merge | `39dc8d0be448ea051f37fdb99be8dbae3d35ca35` | `git merge --no-ff feature/ic-174-glass-always-dark-reissue` | 首行 `merge(IC-174): 玻璃一律按系统深色模式的效果（IC-172 重发：两个 helper、五个容器、四处系统材质）` |

A、B、C 三个提交均带 `(cherry picked from commit …)` 尾注（`-x` 自动生成）。D 提交信息首行 `test(IC-174 D): 像素探针与源码落位断言（v3：参照一律只差覆盖一个修饰符）`，正文注明 `(cherry picked from commit a01ffe616396750a091c8d22dd8497d9f4983922)`。

---

## 四、G976（摘取）—— `check_ic172.py` 分阶段结果，S1View／S2View blob 与 IC-172 对应提交逐一相等

方法：`IC_REPO="D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE" python check_ic172.py <本卡提交> <阶段>`（只读，脚本已预置 `TEST_BLOB=c8cb6d6e…`／`REPORT_DIR=Reports/IC-174/`，即已经是为本卡更新过的版本）。

### 阶段 A（`32a7a2c`）：**26 / 26 PASS**

- `blob S1View.swift == card edits applied`：got `82a688a03b3a364cefb55b305bbc778b625b3027` want 同值
- `blob S2View.swift == card edits applied`：got `900380bbb6387bc3059ca31b0501904b03ff201d` want 同值
- 与 IC-172 `6308693` 处 blob 逐一核对：`git rev-parse 32a7a2c:PhotoCleanupMVE/Features/S1/S1View.swift` = `82a688a03b3a364cefb55b305bbc778b625b3027` = `git rev-parse 6308693:同路径`；S2View 同理 `900380bbb6387bc3059ca31b0501904b03ff201d` 两侧相等。
- 其余 24 项（`colorScheme, .dark)` 计数、`GlassEffectContainer {`／`#available`／`Material`／`ultraThin`／`.primary`／`glassEffect(`／`s1ChromeGlassBackground(`／`s2ChromeGlassBackground(`／`.background(.regularMaterial)`／`preferredColorScheme`／`overrideUserInterfaceStyle`、白名单外零改动、改动路径数）全部 PASS。

### 阶段 B（`1d88203`）：**26 / 26 PASS**

- 两处 blob（`349ab69d6832e05311b060830dcc1f1757faeeb3`／`540c3b3a49d8dd01eaff29293d6c353fdc8e8160`）与 IC-172 `e89b95a` 处逐一相等。
- 其余 24 项全部 PASS（`colorScheme, .dark)` S1 5、S2 4，其余计数不变）。

### 阶段 C（`bc95522`）：**26 / 26 PASS**

- 两处 blob（`99dd6a9ba1170c3b3dcedc26fec2e22850912eb3`／`bea3bf09887428db76827877408a27b09ecf0bb3`）与 IC-172 `df10428` 处逐一相等。
- 其余 24 项全部 PASS（`colorScheme, .dark)` S1 7、S2 6，其余计数不变）。

**记录性观察（非缺陷）**：`REVIEW-IC-174-findings.md` 第五节记录的独立复核克隆中，阶段 C／D 的 `SUMMARY` 数字写的是 30/30；本次在实际工作分支上重跑同一脚本，阶段 A／B／C 均为 26/26（D 才是 30/30，见下）——这是因为脚本对 A／B／C 三个阶段的枚举检查项数量相同（D 专属的测试 blob／pbxproj 撞号检查只在 `stage=D` 时才会追加）。**两次运行的关键结论一致：三个阶段全部 0 FAIL**，数字口径差异不影响 G976 判定，如实记录。

**结论：A、B、C 三个提交的产品文件与 IC-172 对应提交逐字节相等，无一处偏离。G976 满足。**

---

## 五、G977（测试）—— D 上 `check_ic172.py` 全过

`check_ic172.py bd4e213 D`：**30 / 30 PASS**

- `IC172 test exists` got `True` want `True`
- `IC172 test blob` got `c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2` want 同值——**与卡面要求的 v3 blob 完全一致**
- `pbx fileRef 75` got `3` want `3`；`pbx buildFile 72` got `2` want `2`
- `pbx duplicate definition ids` got `[]` want `[]`（定义行 `uniq -d` 空，无撞号）
- `changed paths outside whitelist` got `[]` want `[]`
- `changed product/test/pbx path count` got `4` want `4`

**测试文件覆盖校验**：`git cherry-pick -n a01ffe6` 摘取后、`cp` 覆盖前，暂存区测试文件 `git hash-object` = `b49a40de20a2790da747428bce3ae423d316e20d`（v1，与 IC-172 D 提交一致）；`cp` 覆盖后 `git hash-object` = `c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2`（v3，与卡面要求值完全一致）。**未手工改动任何一行**（用 `cp` 逐字节覆盖）。

**新文件 7 个 `func test`**（`grep -n "func test"` 实测，全部函数名）：

1. `testIC172A_MaterialControlFollowsInterfaceStyle`（正对照）
2. `testIC172A_RawGlassControlFollowsInterfaceStyle`（正对照）
3. `testIC172A_S1GlassHelperIsDarkInBothStyles`
4. `testIC172A_S1LegacyRecipeIgnoresInterfaceStyle`（v3 改名，唯一断言"两侧相同"）
5. `testIC172B_GlassContainerPathIsDarkInBothStyles`
6. `testIC172C_MaterialRecipesUnderOverrideAreSystemDark`（v3 新增，toast／教程提示条／S1 菜单三组）
7. `testIC172ABC_SourceWiring`（十三处源码落位）

**项数对账式：892（IC-171 合并后基线）+ 7（v3 新增测试）= 899**，与 CI 实测 `Executed 899 tests` 完全一致。

**结论：G977 满足。**

---

## 六、本地门禁（四个提交各一次，均为工作树内真实执行，退出码均为 0）

| 子项 | `Scripts/selfcheck.ps1` | `Scripts/scan-hardcoded-user-visible-strings.ps1` | `git diff --check` |
|---|---|---|---|
| A（`32a7a2c`） | 0 | 0 | 0 |
| B（`1d88203`） | 0 | 0 | 0 |
| C（`bc95522`） | 0 | 0 | 0 |
| D（`bd4e213`） | 0 | 0 | 0 |

`selfcheck.ps1` 各次均输出「结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。」；`scan-hardcoded-user-visible-strings.ps1` 各次均输出「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」（目录条目 259，产品源码引用 key 259，全程未变）；`git diff --check` 各次均无输出（无空白符冲突）。

---

## 七、CI 结果

### 运行一：#353（run id `36002043854`），commit `bd4e213d22d5bcd0723347b27aa2e4a89c97c46f`（A→B→C→D，分支上第一次也是唯一一次 CI）

- 结论：`completed` / `success`，全部 12 步骤 `success`（含步骤 9「运行 XCTest」`success`）
- 真实退出码：**0**（步骤 9 结论 `success`；日志内出现 `** TEST SUCCEEDED **`、`XCTest 已全部通过。`；未出现任何 `Process completed with exit code` 类失败标记；工作流 `set -o pipefail` 且 `exit "$test_status"` 原样退出）
- **XCTest 执行摘要**：`##[notice]Executed 899 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 899 tests / 0 failures`
- **XCTest 分段耗时**：`XCTest 分段耗时：模拟器启动 88 s；xcodebuild test 375 s；总 464 s`
- **目的地实证行**：`--- xcodebuild: WARNING: Using the first of multiple matching destinations:` 后 `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`；另 `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`
- **未签名 IPA 校验**：`##[notice]文件=PhotoCleanupMVE-unsigned.ipa，字节数=1862103，SHA-256=2cc9ffd5e58d5a499b18fca5810080282f45e3e1263adfc1cbcb1b505954e546`
- **上传的 artifact**：名称 `PhotoCleanupMVE-unsigned-bd4e213d22d5`，id `10809410472`，大小 `1862273` 字节，`expires_at=2026-12-23T12:54:11Z`，`expired=false`
- **`testIC063` 陷阱 26 核对**：`IC063_WARMUP_GATE_BEGIN`（13:01:29.603933）→`IC063_WARMUP_GATE_END`（13:01:29.629399，间隔约 26ms）；`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 于 13:01:26.312581 开始、13:01:33.692451 通过（耗时 6.279 s），全程未出现任何 `building pipeline`／`Invalidating cache` 行。日志中唯一一处 `[error] building pipeline primitive_coverage-… took 0.588963 seconds`（13:01:44.548922）出现在 `testIC063` 通过之后约 15 秒、隶属于另一条测试 `testIC085R3RenderedStripHasNoBackgroundInsideItemFrames`，**与 `testIC063` 无关，`testIC063` 本次未触发陷阱 26**。

### 运行二（合并后 `main` 自动运行）：#354（run id `36005930189`），commit `39dc8d0be448ea051f37fdb99be8dbae3d35ca35`（merge）

- 结论：`completed` / `success`，全部 12 步骤 `success`
- 真实退出码：**0**（同上判据，`** TEST SUCCEEDED **`）
- **XCTest 执行摘要**：`##[notice]Executed 899 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 899 tests / 0 failures`
- **XCTest 分段耗时**：`XCTest 分段耗时：模拟器启动 84 s；xcodebuild test 472 s；总 556 s`
- **目的地实证行**：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- **未签名 IPA 校验**：`##[notice]文件=PhotoCleanupMVE-unsigned.ipa，字节数=1862103，SHA-256=b70593b9fddac09a43c3d022bae5a76394622381da0b48944b03eb93b6ee199d`
- **上传的 artifact**：名称 `PhotoCleanupMVE-unsigned-39dc8d0be448`，id `10810742199`，大小 `1862273` 字节，`expires_at=2026-12-23T13:28:43Z`，`expired=false`
- **`testIC063` 陷阱 26 核对**：`IC063_WARMUP_GATE_BEGIN`（13:37:16.815632）→`IC063_WARMUP_GATE_END`（13:37:16.923685）；本次运行的唯一一处 `building pipeline` 行（13:37:31.589171，耗时 0.640498 s）同样落在 `IC063_WARMUP_GATE_END` 之后约 15 秒，与另一条测试相关，`testIC063` 未触发陷阱 26。

**两次运行 IPA 字节数相同（1862103）、SHA-256 不同**——属预期：xcodebuild 每次构建产物中含编译时间戳等非确定性元数据，字节数相同、内容 SHA 不同是本仓一贯现象（非本卡引入的问题）。

---

## 八、全部 `IC172_PROBE` 行原文（G978 要求，两次运行各一份，均为 12 行，按出现顺序）

### 运行 #353（分支，方法：下载运行 #353 的整包日志 zip，Python `zipfile` 只读步骤文件 `9_运行 XCTest.txt`）

```
2026-09-24T13:01:17.2439940Z IC172_PROBE arm=material light=169 dark=99
2026-09-24T13:01:17.8010280Z IC172_PROBE arm=rawGlass light=246 dark=78
2026-09-24T13:01:18.2401190Z IC172_PROBE arm=s1Helper light=78 dark=78
2026-09-24T13:01:18.7536690Z IC172_PROBE arm=rawGlassReference light=246 dark=78
2026-09-24T13:01:19.2702530Z IC172_PROBE arm=s1Legacy light=149 dark=149
2026-09-24T13:01:19.8823310Z IC172_PROBE arm=s1GlassBadgeOverlay light=78 dark=78
2026-09-24T13:01:20.5346480Z IC172_PROBE arm=toastReference light=224 dark=64
2026-09-24T13:01:21.0228950Z IC172_PROBE arm=toastOverride light=64 dark=64
2026-09-24T13:01:21.5762290Z IC172_PROBE arm=hintReference light=169 dark=99
2026-09-24T13:01:22.0672600Z IC172_PROBE arm=hintOverride light=99 dark=99
2026-09-24T13:01:22.5642250Z IC172_PROBE arm=menuReference light=249 dark=7
2026-09-24T13:01:23.0817930Z IC172_PROBE arm=menuOverride light=7 dark=7
```

### 运行 #354（合并后 `main`，方法同上，步骤文件同名）

```
2026-09-24T13:37:05.4930960Z IC172_PROBE arm=material light=169 dark=99
2026-09-24T13:37:05.5289740Z IC172_PROBE arm=rawGlass light=246 dark=78
2026-09-24T13:37:05.5625190Z IC172_PROBE arm=s1Helper light=78 dark=78
2026-09-24T13:37:05.7143580Z IC172_PROBE arm=rawGlassReference light=246 dark=78
2026-09-24T13:37:06.4360510Z IC172_PROBE arm=s1Legacy light=149 dark=149
2026-09-24T13:37:06.9015670Z IC172_PROBE arm=s1GlassBadgeOverlay light=78 dark=78
2026-09-24T13:37:07.3853870Z IC172_PROBE arm=toastReference light=224 dark=64
2026-09-24T13:37:07.8483010Z IC172_PROBE arm=toastOverride light=64 dark=64
2026-09-24T13:37:08.3448530Z IC172_PROBE arm=hintReference light=169 dark=99
2026-09-24T13:37:08.8601080Z IC172_PROBE arm=hintOverride light=99 dark=99
2026-09-24T13:37:09.3309580Z IC172_PROBE arm=menuReference light=249 dark=7
2026-09-24T13:37:09.8033030Z IC172_PROBE arm=menuOverride light=7 dark=7
```

**两次运行的 12 行数值逐一相同**（分支运行与合并后运行渲染结果一致，符合预期——两次运行测的是同一份产品代码）。全部数值与 G978 要求的判据核对：

| 组 | 参照（无覆盖） | 被测（有覆盖） | 判据 | 结果 |
|---|---|---|---|---|
| S1 玻璃 helper | `rawGlassReference` 246/78（差 168 ≥ 6，正对照有判别力） | `s1Helper` 78/78（差 0 ≤ 3，且浅色侧=参照深色侧 78） | 通过 |
| S1 回落配方 | — | `s1Legacy` 149/149（差 0 ≤ 3，唯一断言"两侧相同"） | 通过 |
| S1 容器路径 | 同 `rawGlassReference` | `s1GlassBadgeOverlay` 78/78（差 0 ≤ 3） | 通过 |
| toast（`.regularMaterial`） | `toastReference` 224/64（差 160 ≥ 12） | `toastOverride` 64/64（差 0 ≤ 3，浅色侧=参照深色侧 64） | 通过 |
| 教程提示条（`.ultraThinMaterial`） | `hintReference` 169/99（差 70 ≥ 12） | `hintOverride` 99/99（差 0 ≤ 3，浅色侧=参照深色侧 99） | 通过 |
| S1 菜单（材质+近白叠层） | `menuReference` 249/7（差 242 ≥ 12） | `menuOverride` 7/7（差 0 ≤ 3，浅色侧=参照深色侧 7） | 通过 |
| 裸 `glassEffect`（正对照） | `material` 169/99（差 70 ≥ 12） | — | 有判别力 |
| 裸 `glassEffect(.regular)`（正对照） | `rawGlass` 246/78（差 168 ≥ 6） | — | 有判别力 |

**结论（①，两次独立 CI 运行交叉验证）**：候选 (a)（覆盖只包玻璃呈现物自身、写在链尾）对 iOS 26 `glassEffect()` 路径与 iOS 17-25 回落材质路径**均成立**——`.environment(\.colorScheme, .dark)` 使玻璃 helper／容器／四处系统材质在两种 `overrideUserInterfaceStyle` 下渲染完全一致，且这个一致值恰好等于同一棵树（或同构写法）在真实深色 trait 下的渲染值。IC-172 两次红只是决策会话为 legacy 组挑错了"参照"对象，产品代码与覆盖机制本身没有问题。

---

## 九、G978（合并前置）逐项核对

| 子项 | 结果 |
|---|---|
| G976（摘取，A/B/C 全过 + blob 与 IC-172 相等 + 提交信息带 cherry-pick 尾注） | 满足（第四节） |
| G977（测试，D 全过 + 测试 blob = v3 + pbx 计数 + 7 个 `func test`） | 满足（第五节） |
| CI 绿 899／0（真实退出码 0，`OS:26.2, name:iPhone 16`，IPA 字节数与 SHA-256，分段耗时 notice，`testIC063` build 行相对 `IC063_WARMUP_GATE_END` 的先后） | 满足（第七节，#353） |
| 整包日志全部 `IC172_PROBE` 行原文贴进报告（应 12 行） | 满足（第八节，12 行，顺序与卡面一致） |
| 工作树净 | 满足（合并前 `git status --porcelain` 空；合并、推送后同样为空） |
| `main` 未被他人推进 | 满足（合并前 `main` 仍为 `467fe74a0323c98e938142a2107f16843d21cc96`，与开工时一致） |
| 二十条被保护分支 tip 未变 | 满足（第十一节，合并前实测） |

**G978 满足，已按卡面指令 `--no-ff` 合并推送。**

---

## 十、G979（合并后运行）

合并后 `main`（`39dc8d0be448ea051f37fdb99be8dbae3d35ca35`）自动触发运行 **#354**（run id `36005930189`），结果 `success`，**899／0**，分段耗时 notice「模拟器启动 84 s；xcodebuild test 472 s；总 556 s」，artifact 名称 `PhotoCleanupMVE-unsigned-39dc8d0be448`、id `10810742199`、有效期至 `2026-12-23T13:28:43Z`。**G979 满足。**

本报告与 `change-list.md` 在本次合并与合并后运行之后，按惯例 44 在 `main` 上追加**恰一个** docs 提交完成回填（提交信息与 SHA 见执行完成后的最终回报）。

---

## 十一、二十条被保护分支 tip（`git -c http.proxy=http://127.0.0.1:7890 ls-remote --heads origin` 现取核对，合并前实测，全部未变）

IC-172 报告第十一节的十八条：

`feature/ic-089-nx-edge-bounce` `b368a6caee846e664391b0620350395bfe6fbc7f`、`feature/ic-091-nx-midgesture-handoff` `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`、`feature/ic-092-nx-window-follow` `a7cc1ec727a3a493f5263e688a316cbf4c743562`、`feature/ic-158-diagnostic-progress-clamp` `5cb67332437a446d98733ddc942e2905392d2891`、`feature/ic-164-pick-ic163-a-d` `cc85fa4a7cfa272092a3acfade432d13de7e4e0b`、`feature/ic-165-deck-formal` `dc7e49459f15fb6227c3f34903357ae490aaa7ed`、`feature/ic-166-rest-category-and-lib` `2734ccd0ef2f12fa4ce115f0136777321a96c548`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd1436fa25b8298caca2f3d2266024859df4e`、`feature/ic-168-s2-exit-diagnostics` `e7c1be085102b5d9685b0863f29feb6bfa006a38`、`feature/ic-170-s1-first-read` `800791020a8923e44043fea49c9d766a7edcd307`、`feature/ic-171-category-page-trio` `0134c84cb52aea523410ee2f9e05ddd0f54f5d14`、`probe/ic-067-screenshot-subtype` `9db02b93eccbb87d126602901807e70823535111`、`probe/ic-125-sentinel-negative` `402cb6e52a11dc89ce2a8351b47314a5fe9185b8`、`probe/ic-137-media-playback` `486bcb769b59eb1146c5a231c7998847206777cc`、`probe/ic-145-scan-service` `d373afc7125104c01acfc296829229090e6871ce`、`probe/ic-161-similar-photos` `1f8ff9248e312cd4a04faec559ea9f34540b1379`、`probe/ic-162-deck-home-preview` `180b052edf24f168712c6e58754c60b88b342175`、`probe/ic-163-deck-home-preview-r2` `562f8b7afa14508e3efebbd57e980e275946ab95`。

加两条本卡新增保护对象：`feature/ic-172-glass-always-dark` `3cf48335bdf1153f5f349e985fce3f5c2abefa29`、`probe/ic-173-material-dark-env` `571a5efa4b51a82d859d415e397dec0628b772e5`（该分支现 tip 是测试提交 `833e74cea6524ac5c5f860ae50d71656f54ec457` 之后追加的一个纯 docs 报告提交，未改任何产品或测试代码，卡面写法"…的 tip"已预留此情况）。

**二十条与开工时、与合并前实测完全一致，`main` 全程未被他人推进。**

---

## 十二、规格欠账（四条，照 IC-172 卡第二节原样列出，本卡未处理，未回填 SPEC）

1. SPEC-S2 v22 决策 24（`:81`）「App 跟随系统明暗模式……全部颜色使用语义色」与第二节 `:283`——玻璃恒深是它的新例外，v23 仿决策 61 的句式补一条「玻璃恒按深色模式效果」。
2. SPEC-S2 v22 决策 42（`:129`）「chrome 前景一律系统自适应主色——浅色模式全黑、深色模式全白」——改为「玻璃及其前景恒取深色分支（白）」；`:415` 指针随之。
3. SPEC-S1 v10 `:709` `menuBackgroundOpacity=0.93 # 近白 + 模糊；深色随系统底色`——排序／分组菜单改恒深（④ 第 201 条），v11 改注释口径（取值 0.93 不变，解析到深色底色）。
4. SPEC-S0 v4 `:118`「借用的 S1 玻璃 helper 走系统材质、随外观变，其前景在 S0 内恒为米白」与 `:336`——改为「玻璃恒深」。

**已合并，以上四条待决策会话回填 SPEC（本卡不授权修改 SPEC）。**

---

## 十三、③ 登记（不代为下结论）

1. **回落配方（`s1LegacyChromeGlassBackground`）手写拷贝与函数本体渲染差异的原因未查，不影响本卡**：IC-172 停卡报告记录了 `s1Legacy`（恒 149）与用手写 `Capsule().fill(...)` 拷贝同一配方、不加覆盖测得的 `legacyCenterReference`（172/104）之间约 23～45 个灰度单位的差距，根因未查明（候选：`.environment(.dark)` 对 `Material`/`UIVisualEffectView` 桥接的部分生效、`Color.white.opacity(...)` 叠层与材质合成的非线性、或测试夹具时序问题）。**本卡的 v3 测试不再依赖这一比较**（`testIC172A_S1LegacyRecipeIgnoresInterfaceStyle` 只断言两侧相同），因此这一差距不影响本卡的判定，但根因本身仍是③、未闭合，如实登记留给决策会话或未来卡处理。
2. **深色玻璃在浅色页面上的观感待 H91**：像素探针只证明"不随外观变、落在深色侧"这一结构事实，好不好看归真机判定。

---

## 十四、发现但未处理的问题（按纪律只报告不修）

1. `check_ic172.py` 在阶段 A／B／C 的 `SUMMARY` 输出为 26/26（本次在实际工作分支上重跑实测），而 `REVIEW-IC-174-findings.md` 第五节记录的独立复核克隆里阶段 C 输出的是 30/30——两次运行的核对项集合是否完全一致未逐项比对，但**两次运行的 FAIL 数均为 0**，不影响 G976 判定。可能是复核所用脚本版本与本次执行所用脚本版本存在细微差异（例如是否包含 D 阶段专属检查），已如实记录，供决策会话核查脚本版本一致性。
2. `git push origin main` 首次尝试因 `schannel: failed to receive handshake` 直连失败，改用 `git -c http.proxy=http://127.0.0.1:7890 push origin main` 后成功——与 CLAUDE.md 第五节"git 与 gh 的代理需求相反且偶有互换"的既有记录一致，非新发现，仅记录本次命中。
3. IC-172 停卡报告遗留的两处③（legacy 恒定值 149 与真实深浅色 trait 值 104/172 之间约 45～23 个灰度单位差距的根因、`.environment(\.colorScheme, .dark)` 对 `Material` 类型是否完全生效还是部分生效）**本卡未做进一步排查**（不在本卡范围内，卡面写明"本卡不做任何产品改动之外的新改动"），如需排查需另开新卡。

---

## 十五、人工判定项（H91 七条，照 IC-172 卡原样列出，留给 Lynn 装本卡合并后 `main` 产物、**把 iPhone 设成浅色模式**后真机判，执行端不代为下结论）

1. 「空间清理」首页与类别页：垃圾桶、账户、返回、排序、「全选」等圆钮与底栏、收起导航条的玻璃，浅色模式下和深色模式下看起来一样（深色玻璃），不再发白。
2. 「逐张整理」页：顶上排序钮、中间分组胶囊、垃圾桶钮是深色玻璃、图标与文字是白色，放在浅色页面上**看得清**；受限授权提示条、加载／失败态按钮同样。
3. 看图页（S2）：顶排、底排、中央指示、教程提示卡都是深色玻璃；相簿 sheet 里教程第 5 步的提示条是深色。
4. 「逐张整理」点排序钮、点分组胶囊：两只下拉菜单都是**深色底白字**，选中项仍是强调色；菜单边缘在浅色页面上是否清楚（描边为黑，深底上几乎看不见）。
5. 写回失败 toast（S1、S2 各一处，能触发就看）：深色底白字。
6. 确认页、结果页（S3／S4／S5）顶排玻璃同为深色。
7. 一两句总评：深色玻璃放在浅色页面上的观感能不能接受——不能接受的话，下一步是 5.4 画布轮里连页面一起定。

---

## 十六、40 位 SHA 核验（`git cat-file -e <sha>^{<类型>}`，全部执行、全部退出码 0）

| SHA | 类型 |
|---|---|
| `467fe74a0323c98e938142a2107f16843d21cc96` | commit（基线 main） |
| `e356aeda17da53a064892e04f39bea1032f5bf8d` | commit（IC-171 merge） |
| `6308693920a4e180f74559549c2606b8539d1ba0` | commit（IC-172 A 源） |
| `e89b95a248e6bc47224c4c7c3929b196b3219794` | commit（IC-172 B 源） |
| `df10428b74d3e0547dcbe4a30a8623dd14cc236b` | commit（IC-172 C 源） |
| `a01ffe616396750a091c8d22dd8497d9f4983922` | commit（IC-172 D 源） |
| `32a7a2c03bf00cd51e9b304a34c94f413776c4f2` | commit（本卡 A） |
| `1d88203a1fc37389c745f3aa8e434cce738ef04b` | commit（本卡 B） |
| `bc9552277c072eb5d7aafcdd0d37af347009e269` | commit（本卡 C） |
| `bd4e213d22d5bcd0723347b27aa2e4a89c97c46f` | commit（本卡 D） |
| `39dc8d0be448ea051f37fdb99be8dbae3d35ca35` | commit（合并提交） |
| `3cf48335bdf1153f5f349e985fce3f5c2abefa29` | commit（`feature/ic-172-glass-always-dark` tip） |
| `571a5efa4b51a82d859d415e397dec0628b772e5` | commit（`probe/ic-173-material-dark-env` tip） |
| `833e74cea6524ac5c5f860ae50d71656f54ec457` | commit（IC-173 测试提交） |
| `c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2` | blob（v3 测试文件） |
| `b49a40de20a2790da747428bce3ae423d316e20d` | blob（v1 测试文件） |
| `82a688a03b3a364cefb55b305bbc778b625b3027` | blob（S1View，A 后） |
| `900380bbb6387bc3059ca31b0501904b03ff201d` | blob（S2View，A 后） |
| `349ab69d6832e05311b060830dcc1f1757faeeb3` | blob（S1View，B 后） |
| `540c3b3a49d8dd01eaff29293d6c353fdc8e8160` | blob（S2View，B 后） |
| `99dd6a9ba1170c3b3dcedc26fec2e22850912eb3` | blob（S1View，C 后） |
| `bea3bf09887428db76827877408a27b09ecf0bb3` | blob（S2View，C 后） |

命令与结果见 `change-list.md` 末尾。
