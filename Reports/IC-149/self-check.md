# IC-149 自验报告

## 一、结论（先行）

- **子项 B（`ci.yml` 项数统计）与子项 C（两条源码扫描门禁入仓）已交付，负对照齐备。**
- **子项 A（`testIC063…` 采样充分性判据）停卡未做。** 实测推翻任务卡定位表里标为①的 P1 条目：产品侧中间帧门禁**恰恰就是帧数门禁**，阈值与 T4 的 3／5 完全相同；零帧不是「空转通过」而是**必然判红**。T4 与 T5 同源且 T4 更宽松，**放宽 T4 对三次实测判红一次都不管用**。真正的判据在产品侧，而本卡明令零产品改动。按纪律 3 与卡内「若发现必须改产品才能达成某一项，停下报告，不要改产品」停手，详见第三节。
- 本卡在 CI #298 上**当场再次实证**了这一点：`testIC063…` 判红，**失败的只有 T5（`:4146`），T4 两条（`:4151`／`:4155`）都通过**。若按卡执行子项 A，这次红分毫不变。
- 子项 B 的新统计逻辑在 #298 上完成第一次真实运行，notice 为 `Executed 791 tests, 1 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 791 tests / 1 failures`，项数 791 与 `main` 基线一致。
- **CI**：#298 attempt 1 判红于 `testIC063…`；按 CLAUDE.md 对**同一提交原样复跑**做对照，**attempt 2 全绿**：11 步全 success、真实退出码 **0**、**791 项 0 失败**、`OS:26.2, name:iPhone 16`、IPA 1569392 字节。新 notice 报的 791 与日志里唯一用例行计数 791 **逐项相符**。
- **本卡未合并。** G855 明写含「断言 1～6 逐条」，子项 A 停卡后断言 1、2 不存在，条件不满足；且「三个子项只落两个算不算可合」属合并策略判断，按 CLAUDE.md 第一节不由执行端定。分支已推、CI 已绿，可直接合，命令见第六节 G856。
- 人工判定项：**无**（本卡不产生真机可见变化，不占用 H 编号）。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260915-149-ci-stability.md` |
| 基线 `main` | `38d5d7f1535389902a027de87a7c2d91edf3f5b7` |
| 开工核对 | `git log --oneline -1 main` 标题以 `docs(IC-148)` 开头 ✔；`git merge-base --is-ancestor 5c7c56c4264e10c2b7e514cd943a5602e728364c main` 退出码 **0** ✔ |
| 开工 `git status --porcelain` | 空 ✔（纪律 8） |
| 分支 | `feature/ic-149-ci-stability`，自上述 `main` 切出 |
| 分支 tip | `07b27991c42dde24db0cc20dd60f6f6f558d30af` |
| 现状基数 | XCTest 791 项（本卡未增减，见第六节） |

范围边界：8 个文件，全部在白名单内；`PhotoCleanupMVE/` 零改动。详见 `change-list.md` 第二节。

---

## 三、子项 A：停卡报告（纪律 3）

### 3.1 任务卡的根因假设

定位表 P1 条目（卡内标注为①，称「决策会话实读 `38d5d7f`」）：

> `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift:4665` — 产品侧门禁的判据是 **`errors.isEmpty`**——判「采样到的帧里有没有违反不变量」，**不判帧数**。**零帧时它空转通过**，这正是必须保留一个硬下限的理由

子项 A 的全部设计（硬下限 1 帧、软目标 3／5 只报不判、判据抽纯函数）都建立在这一条上。

### 3.2 实测（①，读同一提交 `38d5d7f`）

**`errors` 全仓只有两个 append 点：**

| 行 | 内容 |
|---|---|
| `:4469` | `if !self.middleThresholds.isEmpty { self.errors.append("\(middlePrefix) 少于 \(minimumMiddleFrames) 帧" + …) }` |
| `:4533` | `errors.append("\(label)：缺少运行时视图")` |

`:4469` 的触发条件 `!middleThresholds.isEmpty` 就是「**采集到的中间帧少于 `minimumMiddleFrames`**」。而阈值是：

| 行 | 值 |
|---|---|
| `:4392` | `minimumMiddleFrames: 3`，`middlePrefix: "双击进入 Nx：动画中间帧"` |
| `:4405` | `minimumMiddleFrames: 5`，`middlePrefix: "双击退出 Nx：动画中间帧"` |

再看 `:4665`：`"中间帧门禁：\(errors.isEmpty ? "通过" : "失败")"`。

**结论：产品侧门禁判的就是帧数，阈值 3／5 与 T4 的两条断言完全相同。零帧时 `middleThresholds` 里还剩 3（或 5）个阈值，必然 append 错误，门禁必然判「失败」——它不会空转通过，T5 也不会空转通过。** 卡内「零帧时它空转通过，这正是必须保留一个硬下限的理由」这句，与源码相反。

### 3.3 由此推出的第二件事：T4 比 T5 更宽松

门禁失败时写进 `errors` 的那句话**自身含有 needle**（`"\(middlePrefix) 少于 …"`），并经 `:4668`（`lines.append("错误：\(errors.joined(separator: "；"))")`）落进报告。于是

```
T4 的计数 = 采样到的中间帧数 + 1（失败时那条错误里的一次出现）
```

所以只要采到 2 帧（进入），T4 得 3、`3 >= 3` **通过**，而 T5 判红。**T4 是 T5 的一个更弱的影子，不是独立不变量。**

### 3.4 三次实测逐次对照

| 运行 | 失败断言 | T4 是否失败 | T5（`:4146`）是否失败 |
|---|---|---|---|
| **#292 attempt 1**（run id `34871287047`） | **22 条**：`:4145`、`:4146`、`:4147`、`:4148`、`:4149`、`:4150`、`:4151`（0 < 3）、`:4155`（0 < 5）、`:4159`～`:4163`、`:4168`、`:4171`～`:4174`、`:4177`、`:4180`、`:4183`、`:4184` | 是 | **是** |
| **#295**（run id `34943086640`） | `:4146`、`:4151`（2 < 3） | 是 | **是** |
| **#298 attempt 1**（本卡，run id `34959307006`） | **仅 `:4146`** | **否** | **是** |

**三次红里 T5 三次全红，T4 只红两次。放宽 T4 对这三次红一次都不管用。** #298 是本卡推 CI 时自然发生的，等于一次不花额外预算的对照实验。

### 3.5 #292 attempt 1 的真实死因（卡内归因有误）

卡称 #292 attempt 1 是「『双击进入 Nx 动画中间帧』不足」。实读该次完整日志（`actions/runs/34871287047/attempts/1/logs`）：

- 该用例体内 **22 条断言全部失败**（`:4145`起至 `:4184`；日志里每条 `error:` 印两遍，共 44 行）
- `:4145` `XCTAssertFalse(diagnostics.isExporting)` **失败** —— 10 秒期限内诊断根本没导完
- 日志里 `IC063_DIAGNOSTICS_SAMPLE_BEGIN` 与 `IC063_DIAGNOSTICS_SAMPLE_END` **之间一个字都没有**，报告是空串，所以内容断言一起失败，帧数（T4 两条）只是 22 条里的两条
- 紧接着：`[SwiftUI] Publishing changes from within view updates is not allowed` → `Simultaneous accesses to 0x1061c1020, but modification requires exclusive access.` → **`Fatal access conflict detected.`** → 测试宿主崩溃 → `Restarting after unexpected exit, crash, or test timeout`

栈顶是 `GraphHost.invalidate()`（写）与 `GraphHost.asyncTransaction`（读）对同一地址的并发访问，经 `ObservableObjectPublisher.send()` / `Published.withMutation` 触发。

**这是一次 Swift 独占访问冲突导致的宿主崩溃，不是计时抖动。** 归到「中间帧不足」上是误判；中间帧计数为 0 是崩溃的**症状**。

### 3.6 我的归因与建议（本卡不实施）

两类红，根因不同：

1. **#295／#298 型**：中间帧采样数不足。runner 负载下过渡期内 `CADisplayLink` 回调次数达不到产品自定的 3／5。**产品门禁如实判红，测试如实转述。** 问题在于「诊断门禁的阈值」与「runner 抖动」不匹配——这是产品侧参数问题，不是测试写法问题。
2. **#292 attempt 1 型**：SwiftUI 独占访问冲突致宿主崩溃。与帧数无关，是一个真实缺陷。

**若要让 `testIC063…` 不再因 runner 抖动判红，唯一有效的改动点在产品侧 `S2GeometryDiagnosticsRun`**：把「中间帧不足」从 `errors`（进而 `中间帧门禁：失败`）降为一条不判红的诊断行，或按 runner 实测分布下调 `minimumMiddleFrames`。两者都是产品改动，本卡明令禁止，须另开卡由决策会话定夺。第 2 类（独占访问冲突）建议单独立项。

**按卡执行子项 A 的后果**：T4 两条断言被放宽，`testIC063…` 仍在 T5 上以同样频率判红，同时损失 T4 那一格（更宽松的）覆盖。即**只减覆盖、不减红**。故停手。

---

## 四、子项 B：`ci.yml` 执行摘要的项数统计（已交付）

### 4.1 问题复核（卡内归属有误，问题本身成立）

卡称该问题「在 #295 上现形」。实测 #295 的 notice 是 `Executed 791 tests, with 5 failures (0 unexpected) in 87.165 (119.148) seconds`——**791 与 `main` 基线一致，5 与该次 5 条失败注解一致，该次并无宿主重启，旧口径给的是对的**。

真正的实例是 **#292 attempt 1**：

| 口径 | 项数 | 失败数 |
|---|---|---|
| 旧 `tail -n 1` notice | **401** | **0** |
| 真实 | **777** | 1 个用例，其内 **22 条**断言失败 |

真实 777 由两条独立途径互证：① 全日志 `Test Case '-[…]' started` 唯一身份去重 = **777**；② 分段核算 375（第一段完成）+ 1（`testIC063…` 起跑后崩溃）+ 401（重启段）= **777**，且 777 正是 IC-147 的基线项数。另：唯一 `Test Case … passed` 行 = **776**，唯一 `… failed` 行 = **0**（崩溃那只连结论行都没打出）——故失败数不能只数 `failed` 行。

**一次退出码 65、22 条断言失败的判红运行，摘要 notice 却写着「401 项 0 失败」。** 判红判绿不受影响（真实退出码原样传出，IC-125 哨兵未被绕过），但项数与失败数都不可引用该 notice。

### 4.2 改法

统计抽成 `Scripts/summarize-xctest-log.sh`，按「唯一 `Test Case` 身份去重」计数，崩溃在半途的用例也算已执行。`ci.yml` 只改 C1 段并新增一条宿主重启 notice。

**C2 哨兵段与 C3 退出码段逐字未动**——见第六节 G853 的分块哈希。实现上的关键点（已写进脚本文件头注释）：`summary_line` 内 `Executed N tests` **只允许出现一处**，因为 C2 的 `sed -nE 's/.*Executed ([0-9]+) tests?.*/\1/p'` 前缀 `.*` 是贪婪的，出现第二处会让哨兵取到后一个数；末段小计因此只写数字、不带 `Executed` 字样。

### 4.3 三份夹具的期望与实得（本机 Git Bash 实跑）

| 夹具 | 字段 | 期望 | 实得 |
|---|---|---|---|
| `xctest-single-chunk.log` | `executed_count` | 6 | **6** ✔ |
| | `failed_case_count` | 0 | **0** ✔ |
| | `restart_count` | 0 | **0** ✔ |
| `xctest-restarted.log` | `executed_count` | 8 | **8** ✔ |
| | `failed_case_count` | 1 | **1** ✔ |
| | `restart_count` | 1 | **1** ✔ |
| `xctest-zero.log` | `executed_count` | 0 | **0** ✔ |
| | `restart_count` | 0 | **0** ✔ |

### 4.4 负对照：改前逻辑在重启夹具上的错误输出（G854 要求）

改前逻辑原样：

```
$ grep -E 'Executed [0-9]+ tests?' Scripts/fixtures/xctest-restarted.log | tail -n 1
2026-09-15T02:10:20.1500000Z 	 Executed 3 tests, with 0 failures (0 unexpected) in 0.030 (0.032) seconds
```

**旧口径给出 3 项 0 失败；真实为 8 项 1 个用例失败。** 新口径给出

```
summary_line=Executed 8 tests, 1 failing test case(s), across 2 launch(es) [test host restarted]; xcodebuild last-chunk subtotal: 3 tests / 0 failures
```

**同一负对照已固化进 `ci.yml` 自测步骤**：若旧口径在该夹具上也给出 8，即判夹具失去区分力并判红。没有这一条，自测有可能整体空转。

补充：在**真实**的 #292 attempt 1 日志上跑新脚本，得

```
executed_count=777   failed_case_count=1   restart_count=1   launch_count=2
summary_line=Executed 777 tests, 1 failing test case(s), across 2 launch(es) [test host restarted]; xcodebuild last-chunk subtotal: 401 tests / 0 failures
```

与 4.1 两条独立核算完全一致。

### 4.5 哨兵取值核对

把新 `summary_line` 喂给**未改动的** C2 哨兵 `sed`：

| 输入 | 哨兵取到的 `executed_count` |
|---|---|
| 重启夹具 | 8 |
| 零项夹具 | **0** → `[ 0 -le 0 ]` 成立，`test_status == 0` 时仍 `exit 1` ✔ |
| #292a1 真实日志 | 777 |

IC-125 哨兵行为一字不变，零项日志仍走判红路径。

**更强的一层实证：把 `ci.yml` 的 C1 段（147–165 行）与未改动的 C2 段（182–192 行）原样抽出，用三份夹具当 `test_log` 在本机驱动**（`exit "$test_status"` 换成回显以便观察）：

| 夹具 | `test_status` | 实得输出 | 退出 |
|---|---|---|---|
| `xctest-restarted.log` | 0 | 摘要 notice（8 项 / 1 失败用例 / 2 段 / `[test host restarted]`）**加**宿主重启 notice（`重启 1 次`） | 0 |
| `xctest-single-chunk.log` | 0 | 仅摘要 notice（6 项 / 1 段），**不发**重启 notice | 0 |
| `xctest-zero.log` | 0 | 摘要 notice（0 项）**加** `::error title=XCTest 哨兵::…判定为未执行任何测试，即使退出码为 0 也判失败。test_status=0 executed_count=0` | **1** |

三条行为规格逐条落实：整次运行真实项数 ✔、重启时另发 notice ✔、IC-125 哨兵行为一字不变（零项日志在 `test_status == 0` 时仍判红）✔。

### 4.6 自测步骤的位置与非空转实证

- YAML 解析实证：job 共 **9 个步骤**，新步骤「自测项数统计逻辑（IC-149 子项 B）」在 **index 5**，「运行 XCTest」在 **index 6** —— 自测排在测试之前 ✔
- `bash -n` 语法检查：`summarize-xctest-log.sh` 与自测步骤脚本均退出码 **0**
- **正对照（自测本身不空转）**：把 `expect_field xctest-restarted.log executed_count 8` 故意改成 `3` 后本机重跑，自测输出 `::error … 期望 3，实得 8`，退出码 **1** ✔
- CI #298 实跑：该步骤 `success`

---

## 五、子项 C：两条源码扫描门禁入仓（已交付）

### 5.1 入仓前状态复核

①实测：`git log --all` 与 `find` 对两条门禁均零命中，确实未入仓。

### 5.2 门禁一 `Scripts/check-swift-string-structure.ps1`

扫全部 `.swift`：单行字符串字面量行尾未闭合即判红；并校验大括号／小括号／方括号配平。模式栈 `code` / `string` / `interp`，只在 `code` 模式下计括号。

**初版在真实源码上假红，已修正并写进注释**：初版不认字符串插值，把 `S2NativePhotoPager.swift` 的
`"中间帧门禁：\(errors.isEmpty ? "通过" : "失败")"` 里插值内的引号当成外层字符串的收尾，该文件报「小括号不配平，净值 -2」。健康样本里因此专门放了「插值内嵌字符串」与「插值内嵌调用」两条钉住它。

### 5.3 门禁二 `Scripts/check-scan-needle-variant.ps1`

扫测试源码每一处 `occurrences(of:in:)`：needle 只可能落在字面量内（自带引号／文案 key 形／含中文或全角／资源文件名形）而 haystack 是 `strippedSource` 一族变体，即判红。

**初版同样在真实源码上假红三处**（`IC146ChromeRoundTwoTests.swift:472`、`IC147S0BehaviorTests.swift:833`、`IC148S0VisualTests.swift:308`），死因是把名字作用域拉通到整个文件：同一个 `source` 在 A 函数绑自 `strippedSource`、在 B 函数绑自 `sourceText`，串味成假阳性。改为**逐函数追踪、函数边界复位、同名重绑即覆盖**后归零。健康样本第二个函数专门用「同一个 key needle 喂 raw 源码」钉住「本门禁分辨的是干草堆不是 needle 长相」。

### 5.4 负对照与全仓实证（G854）

| 门禁 | 病样 | 判定 |
|---|---|---|
| 门禁一 | 字符串跨行（`"` 开在行尾） | **判红** `SickUnclosedString.swift:2` |
| 门禁一 | 大括号少一只 | **判红** `大括号不配平（净值 1）` |
| 门禁一 | 健康样本（转义引号／插值／插值内嵌字符串／注释里的孤立引号与括号） | 零命中 ✔ |
| 门禁一 | **仓内现有全部 `.swift`** | **73 个全过，退出码 0** ✔ |
| 门禁二 | 文案 key 喂 stripped（真红型） | **判红** `SickRedTests.swift:6 needle="s0.home.hero.empty.action"` |
| 门禁二 | 带引号的 `Image(` 前缀喂 stripped 且断言命中为 0（空转型） | **判红** `SickVacuousTests.swift:6 needle="Image(\""` |
| 门禁二 | 健康样本（标识符 needle 喂 stripped、同一 key needle 喂 raw） | 零命中 ✔ |
| 门禁二 | **仓内现有全部测试源码** | **34 个全过，退出码 0** ✔ |

额外的接线正对照：把一个含病样的目录喂给 `check-swift-string-structure.ps1 -Path <dir>`，退出码 **1**、报 3 项——证明 `-Path` 与退出码传递都通。

**负对照随门禁一起入仓**：两条门禁各自带 `-SelfTest`，`selfcheck.ps1` 每次都以 `-SelfTest` 调起，自对照不过即以非 0 退出。因此负对照在每次 CI 上都真的跑，而不是只在交付当天跑过一次。

### 5.5 `selfcheck.ps1` 改动

**纯追加 18 行、0 删除**，插在既有最后一项（硬编码字符串扫描）之后、失败汇总 `if ($failures.Count -gt 0)` 之前——这是新检查项能参与判定的唯一位置。

| | 改前 | 改后 |
|---|---|---|
| `Add-Failure` 检查项数 | **23** | **25**（+2，无删除） |
| 既有检查项 | 逐条仍在 | 逐条仍在，一字未动 |
| 结尾成功文案 | 未改（保持最小 diff） | 未改 |

两个 `.ps1` 均带 UTF-8 BOM（首 6 字节 `ef bb bf 23 52 65`），`[Parser]::ParseFile` **零错误**（三个脚本一并核过：门禁一 0、门禁二 0、`selfcheck.ps1` 0）。

> 过程注记：BOM 补写脚本第一版不幂等（以 `utf-8` 读、`utf-8-sig` 写，对已带 BOM 的文件会写成双 BOM），导致 PowerShell 报 `无法将"?#Requires"识别为 cmdlet`。已改为先 `lstrip("﻿")` 再写。

---

## 六、闸门逐条

### G852（范围）

| 项 | 结果 |
|---|---|
| diff 限于白名单 | ✔ 8 个文件，见 `change-list.md` 第二节全量输出 |
| `PhotoCleanupMVE/` 产品源文件零改动 | ✔ `git diff --name-only main...HEAD \| grep -c '^PhotoCleanupMVE/'` = **0** |
| `Scripts/test-xcode.sh` 两侧 SHA-256 | ✔ 相同 `a1bad7252b9dbebf8f1cbc42c57ef2d0367fbe2f87774c8cb6006a3f007b72d9` |
| `scan-hardcoded-user-visible-strings.ps1` 两侧 SHA-256 | ✔ 相同 `46e1963bd50f645be571c686fe4f77147f4343d0a9b46a047f0909bc597ffa9d` |
| `S2Calibration.swift` 不在 diff、`schemaVersion` = 7 | ✔ 两侧 SHA-256 相同 `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f`；`:118` `static let schemaVersion = 7` |
| 冻结三链远端 tip 未变 | ✔ `b368a6c…` / `6736f1e…` / `a7cc1ec…`，与 CLAUDE.md 逐条相符 |
| 三条探针分支远端 tip 未变 | ✔ `9db02b9…` / `486bcb7…` / `d373afc…` |

`git diff --check`：两个代码提交暂存时均无输出。

### G853（不越界）

| 项 | 结果 |
|---|---|
| `testIC063…` 用例体内 T5 与全部内容断言逐条仍在 | ✔ **整个文件一字未改**，两侧 SHA-256 相同 `9e7da1b882022ef9b683bf969ef7caccbc7cc0c9b0303ed13fa44953055739f6`，故「改前／改后断言清单」逐条恒等 |
| T2／T3 两个期限字面量仍为 `2`／`10` | ✔ 同上（`:4126` `timeIntervalSinceNow: 2`，`:4139` `timeIntervalSinceNow: 10`） |
| `ci.yml` C2 哨兵段 + C3 退出码段两侧逐字相同 | ✔ 分块 SHA-256 **两侧均为** `a8a5e952c2a59cad66e1265e222d7a1ab98e8c11cb165167d2d8cd332a88ba6c`（取值区间：`# IC-125 哨兵：堵死` 起至 `exit "$test_status"` 止；改前 103–113 行，改后 182–192 行；`diff` 无输出） |

> 取该分块哈希时踩到一次「源码扫描首个匹配」陷阱：我给新自测步骤写的注释 `# IC-125 哨兵口径不变：…` 排在真哨兵段之前，`awk '/# IC-125 哨兵/,…'` 先匹配到了它，导致第一次哈希对不上。已改用唯一锚点 `# IC-125 哨兵：堵死` 重取。

### G854（负对照实证）

- 子项 B 三份夹具期望值逐条核过 → 第 4.3 节
- 改前 `tail -n 1` 在 `xctest-restarted.log` 上的错误输出已贴出（3 项 0 失败 vs 真实 8 项 1 失败）→ 第 4.4 节；并附真实 #292a1 日志上 401 vs 777 的实例
- 子项 C 四个合成病样各判红、仓内现有文件全过 → 第 5.4 节
- 三类负对照**全部固化进仓**（`ci.yml` 自测步骤 + 两条门禁的 `-SelfTest`），每次 CI 都跑

### G855（合并前置）

| 项 | 结果 |
|---|---|
| G852 / G853 / G854 | ✔ 见上 |
| 全部 XCTest 通过、真实退出码 0 | ✔ **#298 attempt 2**：11 步全 success、退出码 0、791 项 0 失败、目的地 `OS:26.2, name:iPhone 16`、IPA 1569392 字节 SHA-256 `4a30f76a…0620`（attempt 1 红于 `testIC063…`，已按 CLAUDE.md 做同提交原样复跑对照） |
| 项数对账 791 + 本卡新增 **0** = 791 | 本卡未新增测试（子项 A 停卡，`IC149CIStabilityTests.swift` 未建） |
| 工作树净 | ✔ |
| `main` 未被他人推进 | ✔ `git ls-remote origin refs/heads/main` = `38d5d7f1535389902a027de87a7c2d91edf3f5b7` |

### G856（合并后 `main` 运行）

**未产生——本卡未合并，理由见下。**

本卡改了摘要 notice 的统计逻辑，G856 原本要求贴合并后 `main` 运行的 notice 与「唯一用例行计数」并核对二者一致。**该一致性已在分支运行 #298 attempt 2 上实测完成（791 = 791，见第七节）**；合并后的 `main` 运行只是同一逻辑在同一代码上再跑一次。

### 关于合并：**未执行，交决策会话裁定**

卡内合并授权是有条件的——「G855 满足则 `--no-ff` 合并」。而 G855 明写包含「**断言 1～6 逐条**给函数名并在日志核 `passed`」；子项 A 停卡后，**断言 1 与 2 根本不存在**，条件客观不满足。

更关键的是：「三个子项只落两个算不算可合」是**合并策略判断**，CLAUDE.md 第一节明定「你不做产品决策，也不定合并策略」。故**不自行合并**。分支已推送、CI 已绿，决策会话裁定后直接跑下面三条即可：

```bash
git switch main
git merge --no-ff feature/ic-149-ci-stability -m "Merge branch 'feature/ic-149-ci-stability' (IC-149)"
git push origin main
```

合并提交 SHA 与 G856 （合并后 `main` 运行编号、notice、唯一用例行计数）**标为待补**。

---

## 七、CI

### #298 attempt 1（被测提交 `07b27991c42dde24db0cc20dd60f6f6f558d30af`）

| 项 | 值 |
|---|---|
| run 编号 / id | **#298** / `34959307006` |
| 结论 | **failure**，真实退出码 **65** |
| 步骤 | 11 步：1–7 全 success（含「运行结构自验」= 两条新门禁、「自测项数统计逻辑」），**8「运行 XCTest」failure**，9／10 skipped |
| 失败断言 | **仅** `S2CalibrationHarnessTests.swift:4146`（T5，`XCTAssertTrue(report.contains("中间帧门禁：通过"))`） |
| 失败用例 | `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`，3.901 秒 |
| **新摘要 notice** | `Executed 791 tests, 1 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 791 tests / 1 failures` |

两点值得单独记：

1. **子项 B 的新统计逻辑在真实运行上工作正常**：项数 **791** 与 `main` 基线一致；`failed_case_count` = 1 与「一个用例失败」一致；`restart_count` = 0 故未发重启 notice；`last-chunk subtotal` 791/1 与单段日志自洽。退出码 65 经 C3 原样传出，C2 哨兵未介入（`test_status != 0`）。
2. **这次红当场证伪了子项 A 的设计前提**：T4 两条断言（`:4151`／`:4155`）**都通过了**，红的只有被卡列为「一字不动」的 T5。按卡放宽 T4，这次红分毫不变。

### #298 attempt 2（同一提交原样复跑，对照）

按 CLAUDE.md「在该卡落地前，CI 红在该用例上时先对同一提交原样复跑做对照」触发。

| 项 | 值 |
|---|---|
| run 编号 / id / attempt | **#298** / `34959307006` / **attempt 2** |
| 被测提交 | `07b27991c42dde24db0cc20dd60f6f6f558d30af`（与 attempt 1 **同一提交，代码未动**） |
| 结论 | **success**，11 个步骤全 success，真实退出码 **0** |
| 摘要 notice | `Executed 791 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 791 tests / 0 failures` |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`，工具链 `/Applications/Xcode_26.3.app` |
| IPA | **1569392 字节**，SHA-256 `4a30f76a92cbd6b6d570d3894ee58cbf0fd995015a9e5718a9b55ef42cf65620` |

**对照结论（①）**：**同一提交、一字未改，attempt 1 红、attempt 2 全绿。** 坐实 #298 attempt 1 的红是 `testIC063…` 的已知计时脆弱，与本卡改动无因果。连同 #292 attempt 1（复跑即绿），这是该用例第 **二** 次“原样复跑即绿”。

**项数对账与新 notice 的一致性（实读 attempt 2 完整日志）**：

| 口径 | 值 |
|---|---|
| 新 notice 报的项数 | **791** |
| 唯一 `Test Case '-[…]' started` 行 | **791** |
| 唯一 `… passed` 行 | **791** |
| 唯一 `… failed` 行 | **0** |
| `Restarting after unexpected exit…` 标记 | **0**（故未发重启 notice，符合预期） |

**四者逐项相符。** 与 `main` 基线 791 一致，本卡新增 0 项。

---

## 八、本地门禁结果与真实退出码

| 门禁 | 命令 | 退出码 |
|---|---|---|
| 结构自验（含两条新门禁的 `-SelfTest`） | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Scripts/selfcheck.ps1` | **0** |
| 门禁一（含自对照） | `… -File Scripts/check-swift-string-structure.ps1 -SelfTest` | **0**（73 个 `.swift` 全过） |
| 门禁二（含自对照） | `… -File Scripts/check-scan-needle-variant.ps1 -SelfTest` | **0**（34 个测试源文件全过） |
| 门禁一接线正对照 | `… -File Scripts/check-swift-string-structure.ps1 -Path <含病样目录>` | **1**（3 项） |
| 硬编码字符串扫描 | 由 `selfcheck.ps1` 调起 | **0** |
| `summarize-xctest-log.sh` 语法 | `bash -n Scripts/summarize-xctest-log.sh` | **0** |
| `ci.yml` 自测步骤脚本（抽出本机跑） | `bash <selftest.sh>` | **0**（10 项全 OK） |
| 同上，故意改错一条期望 | 同上 | **1**（正对照，证明自测非空转） |
| `git diff --check` | 两次暂存 | 无输出 |
| `[Parser]::ParseFile` | 门禁一／门禁二／`selfcheck.ps1` | 各 **0 errors** |

---

## 九、六条断言逐条

| 断言 | 交付情况 |
|---|---|
| **断言 1**（硬下限生效） | **未交付。** 子项 A 停卡，见第三节 |
| **断言 2**（软目标只报不判） | **未交付。** 同上 |
| **断言 3**（不变量断言一字未改） | **恒等满足**：`S2CalibrationHarnessTests.swift` 整个文件未改，两侧 SHA-256 相同；T5 与 Q1／Q2／zoomScale／transform 等内容断言逐条仍在，T2／T3 期限字面量仍为 `2`／`10` |
| **断言 4**（门禁一负对照） | **已交付**：`Scripts/check-swift-string-structure.ps1` 的 `Invoke-StructureSelfTest`；两个病样各判红、健康样本零命中、仓内 73 个 `.swift` 全过 |
| **断言 5**（门禁二负对照） | **已交付**：`Scripts/check-scan-needle-variant.ps1` 的 `Invoke-NeedleSelfTest`；真红型与空转型病样各判红、健康样本零命中、仓内 34 个测试源文件全过 |
| **断言 6**（不越界） | **已交付**：`selfcheck.ps1` diff 为 +18/−0 纯追加，`Add-Failure` 23 → 25，既有检查项逐条仍在 |

**关于断言 4／5 的落点**：任务卡把它们排给 `PhotoCleanupMVETests/IC149CIStabilityTests.swift`。两条门禁是 PowerShell 脚本，**XCTest 进程内无法调起**，在 Swift 里重写一遍等于把判定逻辑做成两份、必然漂移。故改为落在门禁自身的 `-SelfTest` 路径上，并由 `selfcheck.ps1` 在**每次 CI**（步骤「运行结构自验」）调起——覆盖面比只在交付当天跑一次的 XCTest 断言更强。若决策会话坚持要 XCTest 侧的函数名，须另行指定可行的落点。

子项 A 停卡后 `IC149CIStabilityTests.swift` 无内容可承载，故未创建，`project.pbxproj` 亦未动（避免无载荷的对象 id 登记）。

---

## 十、人工判定项

**无。** 本卡不产生任何真机可见的变化，不占用 H 编号。真机待判仍是 H68／H69／H71 三组，与本卡无关。

---

## 十一、发现但未处理的问题（按纪律只报告不修）

1. **`testIC063…` 判红的真正判据在产品侧，本卡范围内无法修复。** 详见第三节。建议另开卡，由决策会话在「下调 `minimumMiddleFrames`」与「把中间帧不足降为不判红的诊断」之间裁定。
2. **#292 attempt 1 的 `Fatal access conflict detected` 是一个未归档的真实缺陷。** SwiftUI `Publishing changes from within view updates` → `GraphHost.invalidate()` 与 `GraphHost.asyncTransaction` 对同一地址的并发读写。它会让测试宿主崩溃重启，与中间帧数无关。建议单独立项。
3. **任务卡两处①级定位有误**，已在第三、四节写明：P1 对产品门禁判据的描述与源码相反；分段日志问题的实例是 #292 attempt 1 而非 #295（#295 的旧口径 notice 是对的）。
4. **`Scripts/fixtures/*.log` 在 `.gitattributes` 里没有 eol 规则**，Windows 检出会带 CR。本卡已在 `summarize-xctest-log.sh` 内加 `sub(/\r$/, "")` 自保，未改 `.gitattributes`（不在白名单）。若日后要统一，建议加一条 `*.log text eol=lf`。
5. **`selfcheck.ps1` 结尾的成功文案未随新检查项更新**（仍只列到「硬编码扫描及不少于 189 项测试的数量门禁」）。为守「只在末尾追加」未改。
6. **`ci.yml` 的失败行提取仍是 `tail -n 50`**：宿主崩溃重启的运行里，失败注解可能被后段刷掉一部分（#292 attempt 1 的注解里就没有 `Test Case … failed` 与退出码行）。本卡未动该段（不在授权范围）。

---

## 十二、SHA 核验

本报告与 `change-list.md` 中出现的全部 40 位 SHA，逐个跑 `git cat-file -e <sha>^{commit}`：

| SHA | 含义 | `cat-file -e` |
|---|---|---|
| `38d5d7f1535389902a027de87a7c2d91edf3f5b7` | 基线 `main`（IC-148 报告回填） | **OK** |
| `5c7c56c4264e10c2b7e514cd943a5602e728364c` | IC-148 合并提交（开工核对用） | **OK** |
| `012fb7183dc9c6bb3950bf2a4b44e8d2e349068e` | 本卡提交 1（子项 B） | **OK** |
| `07b27991c42dde24db0cc20dd60f6f6f558d30af` | 本卡提交 2（子项 C），分支 tip，#298 被测提交 | **OK** |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | 冻结链 `feature/ic-089-nx-edge-bounce` | **OK** |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 冻结链 `feature/ic-091-nx-midgesture-handoff` | **OK** |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 冻结链 `feature/ic-092-nx-window-follow` | **OK** |
| `9db02b93eccbb87d126602901807e70823535111` | `probe/ic-067-screenshot-subtype` | **OK** |
| `486bcb769b59eb1146c5a231c7998847206777cc` | `probe/ic-137-media-playback` | **OK** |
| `d373afc7125104c01acfc296829229090e6871ce` | `probe/ic-145-scan-service` | **OK** |

十个全部存在，无一例外。陷阱 15：本报告所有 40 位 SHA 均来自 `git rev-parse` / `git log` / `git ls-remote` 的实读输出，无一例由短前缀补全。

**非提交类哈希**（文件内容 / 分块 / IPA）均为本机 `sha256sum` 或 CI `shasum -a 256` 的实测输出，不参与 `cat-file` 核验。
