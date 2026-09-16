# IC-154 自验报告

## 一、结论（先行）

- **三个子项都已交付**，顺序 A → B → C，各自独立 commit：A `0a6b514`（作业时限 30、XCTest 步骤时限 25）、B `f07b9b1`（失败行提取脚本 + 新夹具 + 自测步骤 + 接线）、C `4b483fd`（模拟器启动与 xcodebuild 分段计时）；另有 B 的一个修正 `42b18d0`（自测 OK 行不再原样引用失败行文本，见第 6.2 条）。**零产品改动**（G877）。A、C 各自可单独摘取，B 是「`f07b9b1`→`42b18d0`」连续序列，临时克隆里逐个 cherry-pick 实证（`change-list.md` 第一节）。
- **CI #309（run id `35123856312`，attempt 1，被测 `42b18d0024fc4580727988673e12720cf14015e0`）绿**：作业页 12 个步骤全 success（`ci.yml` 定义的 10 步 + Set up job／Complete job）、真实退出码 **0**、**824 项 0 失败、1 个 launch**、目的地 `OS:26.2, name:iPhone 16`、IPA **1618776 字节**、SHA-256 `771b41292118ea52882f428adc14eb38295a9b5d21229d21baaa69499b3857e9`。**自测步骤 12 行 OK +「失败行提取自测通过。」**（组一六项、组二、组三、负对照，另三份输出不含 `Executed`）；**分段耗时 notice「模拟器启动 94 s；xcodebuild test 412 s；总 508 s」**（94 + 412 = 506 ≤ 步骤 510 s）；作业 721 s，在 30 分钟时限内。
- **CI 预算 3 次用 2 次**：#308（被测 `4b483fd`）同样全绿、824 项 0 失败、分段耗时「80 s；363 s；总 445 s」，但解析整包日志时发现自测步骤一条 OK 行原样打出了夹具里的 `Test Case '…' failed (…)` 行——按「唯一 Test Case 行」核项数会数出 824 passed + **1 failed**（本项目核对项数的常用手法，见 IC-149 报告第 4.1 节、IC-153 报告第 4.2 节）。修正后 #309 复核为 824 passed、**0 failed**。
- **未自行合并。** 卡内有三处条文按字面**不可能同时满足**（第三节）：B2 要求 `ci.yml` 内 `tail -n 50` 0 处、提取脚本恰 1 处调用，而卡内同时要求在 `ci.yml` 新增的自测步骤里跑「改前口径 `… | tail -n 50`」负对照、并对三份夹具调用脚本；B1 组二要求 `xctest-restarted.log` 的输出含「那只失败用例的 `Test Case … failed` 行」，而该既有夹具里根本没有这一行（崩溃的用例打不出结论行），夹具又在不得触碰之列。三处都按结果落实并如实给出字面计数；G880 以 B1／B2 为前置，照第 178 条先例（「G867 未被字面满足，执行端未自行合并，处置正确」）把合并交回，三条命令在第十一节。**G881 随合并待办。**
- **卡内两条事实与实测不符（第四节，不影响交付，但影响对效果的预期）**：① 「#292a1 一只用例 22 条断言各印两遍共 44 行」——现取整包日志实测，第二遍是**工作流自己发的 `::error` 在下载日志里的回显**（`##[error]` 前缀），runner 上 tee 出来、交给提取逻辑的日志里每条只有一遍，那次也并没有被 `tail -n 50` 丢行；② 注解上限（卡内标③）已实证为①，且 **runner 自己那条 `Process completed with exit code N` 与 `::error` 同占每步 10 条额度**——注解发满 10 条时它会被挤掉。
- **未覆盖（纪律 5）**：两次 CI 都全绿，「运行 XCTest」的**失败路径接线**（逐行 `::error` + 作业摘要）、`test-xcode.sh` 的**已启动／启动失败／xcodebuild 失败**三条路径、**步骤级 25 分钟与作业级 30 分钟时限**都没有在 runner 上被触发——前两者只有本机模拟（第 9.5、9.6 条，②），时限只有静态核对。提取脚本本身在 runner 上（bash 3.2 + macOS awk）由自测步骤实跑过。
- **人工判定项：无**（卡内如此）。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260916-154-ci-maintenance.md` |
| 基线 `main` | `6dec2b18f04ad9c76c232aeadff81cdef116d721` |
| 开工核对 1 | `git merge-base --is-ancestor 9b4daa5 main` 退出码 **0** ✔ |
| 开工核对 2 | `git ls-remote origin refs/heads/main` = `6dec2b18f04ad9c76c232aeadff81cdef116d721` = 本地 ✔ |
| 开工核对 3 | `git status --porcelain` **空** ✔（纪律 8） |
| 定位坐标复核（`6dec2b1` 实读） | Y1 `ci.yml:21` `timeout-minutes: 15`；Y2 `:134` 步骤名、`:151-165` 摘要、`:167-180` 失败行段、`:182-191` 哨兵、`:192` `exit "$test_status"`；Y3 `:67-132`；Y4 `:5-7`；Y5 `:13-15`；T1 `test-xcode.sh:21-55`；T2 `:57-65`；S2 三份夹具 24／35／7 行——全部一致。S3（卡 `selfcheck.ps1:328-340`）实为注释 `:326` 起、两条门禁 `:328-334`／`:336-342`，该文件本卡不动，不影响 |
| 分支 | `feature/ic-154-ci-maintenance`（自 `6dec2b1` 切出） |
| 分支 tip（代码） | `42b18d0024fc4580727988673e12720cf14015e0` |
| 现状基数 | 824 项（CI #307）；本卡不增不减 |
| `schemaVersion` | **7，未动** |

范围边界：四个路径（`ci.yml`、`test-xcode.sh`、两个新文件）全在白名单内；`ci.yml` 的 diff 只落在 Y1、Y2 两段与新增自测步骤；`test-xcode.sh` 只动 T2。不得触碰清单逐项核过（第八节 G877／G878）。

---

## 三、卡内条文冲突与按结果落实（三处，请决策会话裁定）

### 3.1 B2「`ci.yml` 内 `tail -n 50` 0 处」与自测负对照

- 卡内自测表「负对照」一行要求：「改前口径 `grep -E '…' 夹具 | tail -n 50` 在 `xctest-failures-many.log` 上取到的行数 = 50 且不含第一条断言失败行」；白名单只给了 `ci.yml` 里新增一个自测步骤，没有给独立的自测脚本。负对照因此只能写在 `ci.yml` 里。
- 落实：负对照照卡内原样写 `… | tail -n 50`（自测步骤内 **1** 处）；「运行 XCTest」步骤内 **0** 处；整个文件 **1** 处。没有改写成 `tail -n "${n}"` 之类去躲 B2 的 grep——那是凑计数。
- 按结果读 B2：**生产路径（运行 XCTest 步骤）不再用 `tail -n 50`** ——成立。

### 3.2 B2「`extract-xctest-failures.sh` 恰 1 处调用」与自测步骤

- 自测步骤要对三份夹具跑脚本，这本身就是 `ci.yml` 里的调用。
- 落实：自测步骤里只有**一个**调用点（一个循环跑三份夹具）；「运行 XCTest」步骤里恰 **1** 处；整个文件 **2** 处。
- 按结果读 B2：**生产路径的失败行提取恰 1 处调用脚本** ——成立。

### 3.3 B1 组二「`xctest-restarted.log` … 含那只失败用例的 `Test Case … failed` 行」——夹具里没有这一行

- ①实读 IC-149 夹具（35 行）：`testCrashyOne` 在 `:15` 起跑，`:16`／`:17` 两条 `error:`，`:18` 独占访问冲突，`:19` `Fatal access conflict detected.`，`:21` 宿主重启标记——**没有**它的 `Test Case … failed` 行（`grep -c -E 'Test Case .* failed'` = **0**）。这与 #292a1 真实形态一致：崩溃在半途的用例打不出结论行（IC-149 报告第 4.1 节已记）。该夹具在「不得触碰」清单里。
- 字面要求因此不可满足，除非脚本凭空造一行——不做。
- 落实（组二按结果核三件事）：`unique_count` ≥ 1（卡内原条件）；all 段含该用例的断言失败行（`-[PhotoCleanupMVETests.CrashyTests testCrashyOne]` 2 条）；输出里的 Test Case 失败行数与夹具自身相同（0 = 0），即不造行。

### 3.4 合并决定

G880 以「断言 A／B1／B2／C1／C2 逐条实证」为前置；B1（组二）与 B2（两个计数）的字面在任何满足卡内其余要求的实现下都不成立。执行端不定合并策略；照第 178 条先例不自行合并，交回决策会话。若决策会话接受 3.1～3.3 的读法，合并只需第十一节三条命令；若不接受，请给出新的口径（例如给负对照单开一个自测脚本的白名单、把 B2 的两个计数限定在「运行 XCTest」步骤、或改写组二的期望），执行端按新口径另改。

---

## 四、卡内事实与实测的出入（不影响交付，登记）

### 4.1 「#292a1 一只用例 22 条断言各印两遍共 44 行」——第二遍是注解回显

①本会话现取 #292a1 整包日志（run `34871287047` attempt 1，`actions/runs/…/attempts/1/logs`，与旧会话副本逐字节相同）：改前 grep 模式命中 **45** 行 =

| 行号 | 条数 | 是什么 |
|---|---|---|
| 761 | 1 | 步骤脚本源码回显（ANSI `[36;1m` 前缀，即 grep 模式串本身） |
| 2720～2741 | 22 | xcodebuild 原始输出，**22 种文本各 1 条** |
| 3828～3849 | 22 | **`##[error]` 前缀**——紧跟在 `##[notice]`（3827，执行摘要 notice 的回显）之后，是该步 `echo "::error title=XCTest 失败::…"` 的回显；去掉前缀后 22／22 与原始行逐字相同 |

runner 上 `tee` 出来、交给提取逻辑的 `$test_log` 不含工作流自己的回显，**每条断言失败只有一遍**。对照另一次红跑 #298a1 的整包日志副本（旧会话下载，注解本会话现取核过）：原始候选行 2 条、同文本重复 0 条，另有 2 条 `##[error]` 回显与 1 条脚本源码回显（②样本，连同 #292a1 共两次）。

影响：裁定 二的「同一行文本只算一次」在 runner 日志的已知形态上**不起作用**（第二类按文件:行去重仍有意义：同一断言行在循环里以不同消息多次失败）；新夹具的「每条印两遍」照卡内写法做，模拟的是下载日志的形态。**卡内「tail -n 50 丢了前面的行」对 #292a1 也不成立**：runner 侧候选只有 22 行，全在 50 行之内；那次真正丢行的是注解上限（4.2）。

### 4.2 注解上限：卡内③ → ①；且退出码注解同占额度

①本会话 gh 现取：

| 运行 | check-run | 该步发出的 `::error` | 注解列表里的 failure 注解 |
|---|---|---|---|
| #292 attempt 1 | `104067515411` | 22 条（日志 3828～3849） | **10 条**，恰是最先发出的 10 条（`:4145`～`:4160`）；runner 的 `Process completed with exit code 65.`（日志 3850）**不在列表里** |
| #298 attempt 1 | `104348820945` | 2 条 | **3 条**：那 2 条 + runner 的 `Process completed with exit code 65.` |

结论：每步 error 注解至多保留 10 条、超出的静默丢弃、保留的是**先发出的**——优先序「先取先发」的设计与之相符。**但 runner 的退出码注解与 `::error` 同占这 10 条**：本卡按裁定 二发满 10 条时，退出码那条必被挤掉（#292a1 即此形态）。若要保住它，只需把脚本顶部 `annotation_limit=10` 改 9、自测组一期望同改——卡内定的是 10，执行端未改，交决策会话定。

### 4.3 #292a1 形态下，注解列表与改前相同（②）

把 #292a1 下载日志里的工作流回显行（`##[` 前缀与 ANSI 脚本回显）剔掉、近似 runner 侧日志后跑新脚本：`candidate_count=26`、`unique_count=26`（22 条断言 + 两条 `Fatal access conflict detected.`（一条原始、一条带系统日志前缀）+ 重启标记 + `** TEST FAILED **`），注解 10 条 = 最先的 10 条断言行——**与改前 GitHub 实际保留的 10 条相同**。这一形态下本卡的收益全在作业摘要（26 条全量，含崩溃结论行），不在注解列表。②：近似做法，非 runner 实跑。

### 4.4 作业摘要的大小上限（③）

卡内写「作业摘要没有这个上限」。按 GitHub 文档口径（③，本卡未在 CI 上实证），`$GITHUB_STEP_SUMMARY` 每步有 1 MiB 上限，超出时摘要不上传并另生一条错误注解。按单行约 250 字节估，去重后约 4000 行才会触到；本卡未设截断（卡内要求「不限条数」）。

---

## 五、实现要点

### 5.1 子项 A

作业级 `timeout-minutes: 30`；「运行 XCTest」步骤 `timeout-minutes: 25`（写在 `name` 与 `run` 之间）；其余步骤不加。本子项 diff 恰两处 hunk（`@@ -18,7 +18,7 @@`、`@@ -132,6 +132,7 @@`）。

### 5.2 子项 B

- **脚本**：整份日志逐行规整（去行尾 CR——`.gitattributes` 对 `.log` 无 eol 规则、Windows 检出带 CR；去行首 GitHub 日志时间戳——下载日志与夹具带、runner 侧日志不带）；四类优先序与去重口径同裁定 二，一行只归最靠前的一类；四类匹配范围包含改前 grep 的三种模式，改前取得到的行改后一行不少。输出三个 `key=value` 与两段；`Executed` 一律改写为 `executed`（契约「输出内不得出现 `Executed` 字样」对任意输入成立，而不只对三份夹具成立；新夹具 `:131` 的断言消息里故意带了两处，是这条的负对照）。bash 3.2：shell 侧只做参数校验；awk 侧不用 gawk 扩展、不用正则区间，函数形参不与全局变量同名。
- **新夹具**构成见 `change-list.md` 第三节：候选 70、去重 36（文件:行 32 + Test Case 失败行 1 + 结论行 3；若按整行文本去重会得 37）、注解 10；改前 grep 命中 67 行，取尾 50 行丢掉前 17 行。
- **自测步骤**：卡内四组 + 负对照之外加了两项同源检查——每份输出不含 `Executed`、组一 all 段优先序「1 → 32 → 3」。组二按第 3.3 条落实。OK／失败提示一律不原样带失败行文本（修正 `42b18d0`，第 6.2 条）。
- **接线**：`test_status -ne 0` 时调脚本；annotations 段逐行 `::error title=XCTest 失败::`；一条都没有时照旧发「未找到具体错误行。」；作业摘要标题「XCTest 失败行（全量）」+ 候选行总数／去重后条数／已发注解条数 + all 段全文。「已发注解条数」取实际发出的条数。

### 5.3 子项 C

目的地选定后显式启动（已 `Booted` 视为成功，其余失败打印 simctl 原输出并 `exit 1`）→ 等待就绪（失败 `exit 1`）→ 计 `boot_seconds`；`if xcodebuild … then … else xcodebuild_status=$? fi` 计 `xcodebuild_seconds`；两条路径都打印分段耗时行与 notice，notice 按裁定 三带「总 T s」（T = bash 的 `SECONDS`，脚本自启动起的秒数——白名单只许动 T2，不能在文件头另记起点，`SECONDS` 不需要）；xcodebuild 非 0 原样 `exit`。注释与提示文字里不出现 `simctl boot`／`bootstatus` 字样，C2 的计数只数到真正的调用。

---

## 六、CI 的完整事实

### 6.1 主跑 #309（tip `42b18d0`）

| 项 | 值 |
|---|---|
| 运行编号 | **#309** |
| run id | `35123856312`，`run_attempt` **1**，事件 `push`，分支 `feature/ic-154-ci-maintenance` |
| check-run id | `104887973841`（从本次运行的 jobs 现取） |
| 被测提交 | `42b18d0024fc4580727988673e12720cf14015e0`（分支 tip，含全部代码提交） |
| 结论 | **success**；作业页 12 个步骤全 success（`ci.yml` 定义的 10 步 + Set up job／Complete job） |
| 作业时长 | 16:45:02Z → 16:57:03Z（**721 s**，时限 30 分钟之内） |
| 自测失败行提取（IC-154 子项 B） | 16:45:34Z → 16:45:34Z，success |
| 运行 XCTest | 16:45:34Z → 16:54:04Z（**510 s**）；步骤以 `exit "$test_status"` 原样退出，结论 success ⟹ 真实退出码 **0** |
| 构建未签名应用 | 16:54:04Z → 16:56:29Z（145 s） |
| 注解 | **3 条，全是 notice**（error 0、warning 0） |
| 执行摘要 notice | `Executed 824 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 824 tests / 0 failures` |
| **分段耗时 notice** | `模拟器启动 94 s；xcodebuild test 412 s；总 508 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1618776，SHA-256=771b41292118ea52882f428adc14eb38295a9b5d21229d21baaa69499b3857e9` |
| artifact | `PhotoCleanupMVE-unsigned-42b18d0024fc`，id `10458676855`，zip 1618946 字节，2026-12-15 前有效 |

**实证行**（整包日志 zip，`unzip -tq` 校验通过后解析；行号为该 zip 内作业日志行号）：

- runner bash：`GNU bash, version 3.2.57(1)-release (arm64-apple-darwin24)`（1107）
- 目的地：`使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`（1108）；`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（1360）
- `Executed 824 tests, with 0 failures (0 unexpected) in 40.498 (42.203) seconds`；`** TEST SUCCEEDED **`（4871）
- `Test Suite 'All tests' started` 出现 **1** 次；唯一 `Test Case '…' passed` **824**、`failed` **0**
- 日志内工作流回显以外的 `error:` 行 **0**；`##[error]`／`##[warning]` **0**；无超时字样
- `XCTest 分段耗时：模拟器启动 94 s；xcodebuild test 412 s；总 508 s`（4874）；`XCTest 已全部通过。`（4876）

**计时线（②：日志行时间戳是 runner 收到该行的时刻，管道缓冲可能让行晚到）**：

| 时刻（UTC） | 距上一行 | 事件 |
|---|---|---|
| 16:45:35.5 | — | simctl 实证列表末行（其后即启动段起点） |
| 16:45:59.2 | +23.6 s | 等待就绪的首行 `Monitoring boot status for iPhone 16 (…)`，设备自报 `Elapsed=00:22` |
| 16:47:08.0 | +68.8 s | `Finished`（设备自报 `Elapsed=01:30`）；其间逐秒打印 `Waiting on Data Migration`（LaunchServicesMigrator、MobileSafari.migrator 等插件）与 `Waiting on System App`，共 47 行 |
| 16:49:00.7 | +112.7 s | xcodebuild 首行输出 `Command line invocation:` |
| 16:49:10.2 | +9.5 s | 目的地实证行 |
| 16:52:24.9 | +194.7 s | `Test Suite 'All tests' started`（其间为构建） |
| 16:53:08.9 | +44.0 s | `Test Suite 'All tests' passed` |
| 16:54:02.0 | +53.1 s | `** TEST SUCCEEDED **` |
| 16:54:02.9 | +0.9 s | 分段耗时行 |

### 6.2 首跑 #308（`4b483fd`）与修正

| 项 | 值 |
|---|---|
| run id | `35121371909`，attempt 1；check-run `104879714287` |
| 被测提交 | `4b483fda188cbabf679ba40b128d1f07de8c388b` |
| 结论 | **success**；作业 628 s（16:21:37Z → 16:32:05Z），运行 XCTest 448 s，构建 146 s |
| 执行摘要 notice | `Executed 824 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 824 tests / 0 failures` |
| **分段耗时 notice** | `模拟器启动 80 s；xcodebuild test 363 s；总 445 s`（80 + 363 = 443 ≤ 448） |
| IPA 校验 notice | 字节数 1618776，SHA-256 `0123acc1fe3203de37cb03e655b441785261438f9b00dc8cefb939146421db96`；artifact `PhotoCleanupMVE-unsigned-4b483fda188c`（id `10457742634`） |
| 计时线（②） | 启动段首行 +31.9 s、`Finished` 再 +46.1 s（设备自报 `Elapsed=01:15`，同样是 Data Migration 与 System App 等待）；xcodebuild 首行输出 +103.7 s；`All tests` started → passed 42.2 s |
| **发现的缺陷** | 自测步骤第 1001 行：`OK 组一 annotations 段第 1 行是 Test Case … failed 行：Test Case '-[PhotoCleanupMVETests.StormTests testStormManyAssertions]' failed (4.321 seconds).`——按 `Test Case '(-[…])' (passed\|failed) (` 数整包日志得 824 passed + **1 failed**（`StormTests` 不在 824 个真实用例里）。同步还有两条 OK 行原样带了 `Restarting after unexpected exit`、`** TEST FAILED **`、`Test Case … failed` 字样 |
| 处置 | 修正 `42b18d0`：三条 OK 提示与三条失败提示改为描述性文字（组一首条注解那条失败提示仍在失败时带出该行，便于排查）、两段注释同改、另加两行注释说明缘由；检查逻辑与期望值不变；本机自测重跑 12 行 OK、8 种变异仍全部判红（第 9.4 条）；#309 复核唯一 `failed` **0** |

IPA 两次字节数相同（1618776）、哈希不同——IPA 归档不可复现的既有结论。**两次分段耗时是 G881 之前的两个数据点**（②）：启动段 80／94 s，其中设备自报的启动耗时 75／90 s、主要在首次启动的数据迁移与系统应用等待；xcodebuild 段 363／412 s，其中测试本身约 42～44 s；两次在「就绪」与 xcodebuild 首行输出之间都有 104／113 s 无输出（是 xcodebuild 启动慢还是输出缓冲，本卡数据分不出，③）。

---

## 七、逐条断言

### 断言 A（静态核对；卡内口径：jobs API 无此字段）

```
$ grep -n 'timeout-minutes' .github/workflows/ci.yml
21:    timeout-minutes: 30
294:        timeout-minutes: 25
```

恰两行，值 30（作业级，`jobs.build-test-package`）与 25（`运行 XCTest` 步骤；PyYAML 解析确认挂在该步上）。A 提交 diff 恰两处 hunk。两次 CI 作业 628／721 s，均未触及任一时限——时限本身的生效未在 runner 上被触发（未覆盖）。

### 断言 B1（#309 自测步骤 OK 行原文，日志 997～1009）

```
OK xctest-failures-many.log 退出码 0，输出不含 Executed 字样
OK xctest-restarted.log 退出码 0，输出不含 Executed 字样
OK xctest-single-chunk.log 退出码 0，输出不含 Executed 字样
OK 组一 candidate_count=70（> 50）
OK 组一 unique_count=36
OK 组一 annotation_count=10，annotations 段 10 行
OK 组一 annotations 段第 1 行是 Test Case 失败行
OK 组一 all 段含宿主重启标记行 1 条、测试失败结论行 1 条
OK 组一 all 段优先序：Test Case 失败行 1 → 测试目标 error 行 32 → 结论行 3（共 36 行）
OK 组二 unique_count=4（≥ 1），all 段含 testCrashyOne 的断言失败行 2 条；Test Case 失败行：夹具 0，输出 0
OK 组三 xctest-single-chunk.log candidate_count=0，annotation_count=0
OK 负对照：改前口径取到 50 行，不含第一条断言失败行（PhotoCleanupMVETests/StormTests.swift:101）；新口径 all 段含该行 1 条
失败行提取自测通过。
```

对照卡内四组：组一（新夹具）`candidate_count > 50` ✔、`unique_count` = 写死期望 36 ✔、`annotation_count = 10` ✔、annotations 第 1 行是 Test Case 失败行 ✔、all 段含重启标记与 TEST FAILED 行 ✔；组二**按第 3.3 条的结果读法** ✔（字面不可满足）；组三 `candidate_count = 0`、`annotation_count = 0` ✔；负对照 ✔。IC-149 的项数统计自测（日志 825～835）同时 10 行 OK、「统计逻辑自测通过。」，未受影响。

### 断言 B2（源码，`42b18d0`）

| 项 | 卡内要求 | 实测 | 判定 |
|---|---|---|---|
| `ci.yml` 内 `tail -n 50` | 0 处 | 整文件 **1**（自测负对照）；「运行 XCTest」步骤 **0** | 字面不满足，按结果满足（第 3.1 条） |
| `extract-xctest-failures.sh` 调用 | 恰 1 处 | 整文件 **2**；「运行 XCTest」步骤 **1**、自测步骤 **1** | 字面不满足，按结果满足（第 3.2 条） |
| `::error title=XCTest 失败::` | 仍存在 | 「运行 XCTest」步骤 **2** 行（逐行发注解、回落一条） | ✔ |
| `summarize-xctest-log.sh` 两侧 SHA-256 | 相同 | `35f933e9…d4b9` 两侧相同 | ✔ |
| 三份既有夹具两侧 SHA-256 | 相同 | `9ffe8045…d983`／`319d5be6…684f`／`c63d3e94…6141` 两侧相同（全值见 `change-list.md` 第二节） | ✔ |

（计数用 PyYAML 逐步取 `run` 文本 `.count()`，整文件用 `grep -c`。）

### 断言 C1（#309 主跑）

- 日志第 4874 行：`XCTest 分段耗时：模拟器启动 94 s；xcodebuild test 412 s；总 508 s` ✔（含卡内要求的 `XCTest 分段耗时：模拟器启动 N s；xcodebuild test M s` 前缀）
- N = 94、M = 412，均为非负整数 ✔；N + M = **506 ≤ 510**（运行 XCTest 步骤 16:45:34Z → 16:54:04Z）✔
- 注解列表有该 notice：`[notice] XCTest 分段耗时：模拟器启动 94 s；xcodebuild test 412 s；总 508 s` ✔
- 首跑 #308 同样成立：80 + 363 = 443 ≤ 448 ✔

### 断言 C2（源码，awk 切块 diff）

- `test-xcode.sh:21-55` 两侧逐字相同：见第八节 G878 表最后一行（`6dec2b1` 的 21～55 行在 `42b18d0` 里仍是 21～55 行，`diff` 空）✔
- `xcodebuild` 调用块六个参数行（改前 58～63 行：`test`／`-project`／`-scheme`／`-configuration Debug`／`-destination`／`-derivedDataPath`）与改后 `if xcodebuild \`（第 86 行）之后六行逐字相同 ✔；本机假工具记录的 argv 也与改前一致（第 9.6 条）
- `grep -c 'simctl boot "'` = **1**、`grep -c 'bootstatus'` = **1** ✔

---

## 八、闸门

### G877（零产品改动）—— 满足

`git diff --name-only 6dec2b1..42b18d0`：`.github/workflows/ci.yml`、`Scripts/extract-xctest-failures.sh`、`Scripts/fixtures/xctest-failures-many.log`、`Scripts/test-xcode.sh`。`PhotoCleanupMVE/`、`PhotoCleanupMVETests/`、`PhotoCleanupMVE.xcodeproj/` 各 **0** 命中。`summarize-xctest-log.sh`、`selfcheck.ps1`、`scan-hardcoded-user-visible-strings.ps1`、两条 IC-149 门禁、三份既有夹具两侧 SHA-256 相同（八个全值见 `change-list.md` 第二节）。项数 824 不变（#307 → #309）。

### G878（`ci.yml` 与 `test-xcode.sh` 逐字未动段）—— 满足

hunk 头见 `change-list.md` 第二节。awk 切块 diff（`awk 'NR>=a && NR<=b'` 分别切出 `6dec2b1` 与 `42b18d0` 的对应段，`diff` 比对；新文件中的位置由逐行滑窗比对确定）：

| 段 | `6dec2b1` 行 | `42b18d0` 行 | `diff` | 两侧 SHA-256（前 16 位） |
|---|---|---|---|---|
| 检出 → 环境 → 结构自验 → 硬编码扫描 | 24～65（42 行） | 24～65 | 空 | `ca051939631efb7e` |
| IC-149 项数统计自测 | 67～132（66 行） | 67～132 | 空 | `6cffdf148cee3a35` |
| 摘要 notice | 151～165（15 行） | 311～325 | 空 | `5e2d3fee2dbb096d` |
| IC-125 哨兵 + `exit "$test_status"` | 182～192（11 行） | 375～385 | 空 | `a8a5e952c2a59cad` |
| 构建未签名应用 + 上传 | 194～263（70 行） | 387～456 | 空 | `32fbcd50a75f3858` |
| `test-xcode.sh` T1 目的地选择 | 21～55（35 行） | 21～55 | 空 | `dba6b0f854a5fe9c` |

### G879 —— 满足

- 主跑 #309 日志：自测步骤四组 OK + 负对照 OK（第七节 B1 原文，组二按第 3.3 条）；分段耗时 notice 存在（C1）。
- XCTest 步骤 `timeout-minutes: 25`：静态核（断言 A）。
- 冻结三链与四条探针远端 tip（`git ls-remote origin`，直连，本会话两次读取一致）：

| 分支 | 期望 | 实读 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | `b368a6caee846e664391b0620350395bfe6fbc7f` ✔ |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` ✔ |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` ✔ |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | `9db02b93eccbb87d126602901807e70823535111` ✔ |
| `probe/ic-125-sentinel-negative` | `402cb6e` | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` ✔ |
| `probe/ic-137-media-playback` | `486bcb7` | `486bcb769b59eb1146c5a231c7998847206777cc` ✔ |
| `probe/ic-145-scan-service` | `d373afc` | `d373afc7125104c01acfc296829229090e6871ce` ✔ |

- `schemaVersion`：`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118` `static let schemaVersion = 7` ✔

### G880（合并前置）—— **字面未满足，未合并**

| 条件 | 状态 |
|---|---|
| G877～G879 | 满足 |
| 绿：824 项 0 失败、真实退出码 0 | #309 ✔ |
| 执行摘要 notice | ✔ |
| `OS:26.2, name:iPhone 16` 目的地实证行 | ✔ |
| IPA 字节数与 SHA-256 | 1618776 ／ `771b4129…57e9` ✔ |
| 断言 A | 静态 ✔ |
| **断言 B1** | 组一、组三、负对照 ✔；**组二字面不可满足**，按结果 ✔（第 3.3 条） |
| **断言 B2** | **两个计数字面不满足**，按结果 ✔（第 3.1、3.2 条）；其余三项 ✔ |
| 断言 C1、C2 | ✔ |
| 工作树净 | 报告提交后 `git status --porcelain` 空（第十一节） |
| `main` 未被他人推进 | 报告提交前 `git ls-remote origin refs/heads/main` = `6dec2b18f04ad9c76c232aeadff81cdef116d721` ✔ |

### G881（合并后 `main` 运行）—— 待合并后登记

---

## 九、本机预验证（②：Git Bash 5.3.9 + GNU awk 5.4.0 + GNU grep／sed；不构成 runner 上会通过的证据，权威结论只取 CI #309）

### 9.1 脚本在四份夹具上的输出

工作树里三份既有夹具是 CRLF（`core.autocrlf=true` 检出），另用 `git show HEAD:<夹具>` 取 LF 版各跑一遍：**两种行尾的输出逐字节相同**，输出里 CR 字节 0。参数错误两例：无参数、文件不存在，均退出码 **2**。

`xctest-restarted.log`（退出码 0）：

```
candidate_count=4
unique_count=4
annotation_count=4
--- annotations ---
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/CrashyTests.swift:42: error: -[PhotoCleanupMVETests.CrashyTests testCrashyOne] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/CrashyTests.swift:43: error: -[PhotoCleanupMVETests.CrashyTests testCrashyOne] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
Fatal access conflict detected.
Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.
--- all ---
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/CrashyTests.swift:42: error: -[PhotoCleanupMVETests.CrashyTests testCrashyOne] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/CrashyTests.swift:43: error: -[PhotoCleanupMVETests.CrashyTests testCrashyOne] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
Fatal access conflict detected.
Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.
```

`xctest-single-chunk.log` 与 `xctest-zero.log`（退出码均 0，输出相同）：

```
candidate_count=0
unique_count=0
annotation_count=0
--- annotations ---
--- all ---
```

`xctest-failures-many.log`（退出码 0；共 51 行：3 个计数 + 段头 + annotations 10 行 + 段头 + all 36 行）：

```
candidate_count=70
unique_count=36
annotation_count=10
--- annotations ---
Test Case '-[PhotoCleanupMVETests.StormTests testStormManyAssertions]' failed (4.321 seconds).
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:101: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("0") is not equal to ("1")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:104: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:107: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:110: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:113: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertNotNil failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:116: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("0") is not equal to ("1")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:119: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:122: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:125: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
--- all ---
Test Case '-[PhotoCleanupMVETests.StormTests testStormManyAssertions]' failed (4.321 seconds).
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:101: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("0") is not equal to ("1")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:104: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:107: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:110: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:113: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertNotNil failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:116: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("0") is not equal to ("1")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:119: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:122: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:125: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:128: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertNotNil failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:131: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("executed 0 tests") is not equal to ("executed 32 tests")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:134: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:137: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:140: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:143: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertNotNil failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:146: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("0") is not equal to ("1")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:149: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:152: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:155: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:158: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertNotNil failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:161: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("1") is not equal to ("2") - loop iteration 1
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:164: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:167: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:170: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:173: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertNotNil failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:176: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("0") is not equal to ("1")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:179: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:182: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertGreaterThanOrEqual failed: ("0") is less than ("3")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:185: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:188: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertNotNil failed
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:191: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertEqual failed: ("0") is not equal to ("1")
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:194: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertTrue failed
Fatal access conflict detected.
Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.
** TEST FAILED **
```

（上面三个代码块与脚本实际输出逐字节比对一致。新夹具：98 行，`PhotoCleanupMVETests/…error:` 66 行、32 个文件:行、33 种文本，`Test Case … failed` 1 行，含 `Executed` 的行 6 行；提交内 SHA-256 `1b883975ba40d546d3e34b619ebdb1288c6f92d2ea67ade81850bcbdb4f52492`。）

### 9.2 严格 awk 口径

同一脚本经 PATH 前置的 `gawk --posix` 与 `gawk --traditional` 各跑四份夹具：8／8 退出码 0、stderr 空、输出与默认 gawk **逐字节相同**；把 awk 程序抽出来 `gawk --posix --lint` 跑三份夹具，警告 **0**（初稿有一条「函数形参 `category` 与全局变量同名」，已改名 `kind`，改名前后四份输出逐字节相同）。runner 上是 macOS 自带 awk，本机无此实现——由 CI 自测步骤实跑兜底（#308、#309 均 OK）。

### 9.3 负对照原文（本机）

```
$ grep -E 'PhotoCleanupMVE/.*error:|PhotoCleanupMVETests/.*error:|Test Case .* failed' Scripts/fixtures/xctest-failures-many.log | wc -l
67
$ … | tail -n 50 | wc -l
50
$ … | tail -n 50 | head -n 1
2026-09-16T03:00:00.2600000Z /Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVETests/StormTests.swift:125: error: -[PhotoCleanupMVETests.StormTests testStormManyAssertions] : XCTAssertFalse failed
$ … | tail -n 50 | grep -c "StormTests.swift:101:"
0
```

### 9.4 自测步骤本机整段跑 + 变异测试

把 `ci.yml` 里该步的 `run` 原文取出（PyYAML），按 GitHub 未指定 `shell` 时的默认 `bash -e` 在仓库根跑：**12 行 OK** +「失败行提取自测通过。」、退出码 0（修正后行文与第七节 #309 原文逐行相同）。

另在草稿区镜像 `Scripts/` 后把提取脚本逐一改坏，确认自测**判红**（证明这些检查不是空转）。修正 `42b18d0` 前后各跑一轮，结果相同：

| 变异 | 自测退出码 | 抓住它的检查 |
|---|---|---|
| 不改（对照） | 0 | — |
| 去掉去重 | 1 | 组一 unique 70≠36、优先序、负对照 |
| 第二类改按整行文本去重 | 1 | 组一 unique 37≠36、优先序 |
| 取消优先序（全归一类） | 1 | 组一首条注解、优先序 |
| 去掉 `Executed` 改写 | 1 | 新夹具输出含 `Executed` |
| 取消注解封顶 | 1 | 组一 annotation_count 36≠10 |
| 只看最后 50 条候选行 | 1 | 组一 candidate／unique、优先序、负对照 |
| 去掉时间戳规整 | 1 | 组一首条注解、优先序 |
| 丢弃结论行 | 1 | 组一 unique、结论行、优先序 |

修正后另扫：自测步骤的输出不含 `Test Case '…' (passed|failed) (` 形状、不含 `Restarting after unexpected exit`、`** TEST FAILED **`、`Test Case … failed` 字样；各步骤的 `run` 源码里都没有 `Test Case '-[…]' passed/failed (` 形状（源码回显只剩检查必需的两处字面量：`'Restarting after unexpected exit'`、`'** TEST FAILED **'`，均在 ANSI 回显行里）。

### 9.5 「运行 XCTest」步骤接线模拟（失败路径在 CI 上未覆盖，此为唯一证据）

取该步 `run` 原文、只把 `bash Scripts/test-xcode.sh 2>&1 | tee "$test_log"` 那一行换成「把夹具拷进 `$test_log` 并给定退出码」，`GITHUB_STEP_SUMMARY` 指向临时文件，`bash -e` 跑：

| 喂入 | 给定退出码 | 步骤退出码 | `::error` | `::notice` | 作业摘要 |
|---|---|---|---|---|---|
| `xctest-failures-many.log` | 65 | **65** | 10（首条 Test Case 失败行，其后 `:101`～`:125`） | 执行摘要 + 宿主重启 | 标题 + 70／36／10 + 36 行 |
| `xctest-restarted.log` | 65 | **65** | 4 | 执行摘要 + 宿主重启 | 4／4／4 + 4 行 |
| `xctest-single-chunk.log` | 0 | **0** | 0 | 执行摘要（6 项） | 空 |
| `xctest-zero.log` | 0 | **1** | 1（IC-125 哨兵） | 执行摘要（0 项） | 空 |
| 一行无关文本 | 1 | **1** | 1（「未找到具体错误行。」） | 执行摘要（0 项） | 0／0／1、无代码块 |

（初跑时我的模拟脚本对 YAML 去缩进后的行匹配写错，两个 65 被模拟成 1；修正模拟脚本后如上表，`ci.yml` 未因此改动。该步在修正 `42b18d0` 中未改。）

### 9.6 `test-xcode.sh` 假工具四路径（后三条在 CI 上未覆盖）

PATH 前置假 `xcrun`／`jq`／`xcodebuild`（记录调用与实参）跑真实脚本：

| 路径 | 退出码 | 输出要点 | 调用记录 |
|---|---|---|---|
| 启动 0、就绪 0、xcodebuild 0 | **0** | `XCTest 分段耗时：模拟器启动 2 s；xcodebuild test 1 s；总 3 s` + 同文 notice + 「XCTest 已全部通过。」 | boot → bootstatus `-b` → xcodebuild |
| 启动报 `Unable to boot device in current state: Booted`、就绪 0、xcodebuild 65 | **65** | 「已处于启动状态，继续。」+ 分段耗时行与 notice，无「已全部通过」 | boot → bootstatus → xcodebuild |
| 启动报其他错误（code=164） | **1** | 「启动失败（不回落到其他设备或版本）。输出如下：」+ simctl 原输出 | 仅 boot |
| 启动 0、就绪失败 | **1** | 「未能进入就绪状态。」 | boot → bootstatus |

xcodebuild 实参两次记录均为 11 个 argv：`test`、`-project <仓库>/PhotoCleanupMVE.xcodeproj`、`-scheme PhotoCleanupMVE`、`-configuration Debug`、`-destination platform=iOS Simulator,id=<udid>`、`-derivedDataPath <临时目录>/DerivedData`——与改前一致。

### 9.7 真实红跑日志上的试跑

| 输入 | candidate | unique | annotation | 说明 |
|---|---|---|---|---|
| #292a1 整包日志（原样） | 50 | 28 | 10 | 含工作流回显：ANSI 脚本回显 1 行占了第二类第 1 条；22 条 `##[error]` 回显按文件:行并入原始行；`##[error]Process completed with exit code 65.` 进结论行 |
| #292a1 剔除工作流回显（近似 runner 侧） | 26 | 26 | 10 | 见第 4.3 条 |
| #298a1 整包日志（原样） | 7 | 6 | 6 | Test Case 失败行与其 `##[error]` 回显按文本是两条 |
| #298a1 剔除工作流回显 | 3 | 3 | 3 | 1 条断言 + Test Case 失败行 + `** TEST FAILED **` |

CI 上的输入永远是 runner 侧 `$test_log`，不含工作流回显；上表前一类只说明「拿下载日志手工跑脚本时会多出回显行」（第十二节第 3 条）。

### 9.8 摘取实测

见 `change-list.md` 第一节：临时克隆里 A 单独、B→修正、C 单独均无冲突；修正单独摘取冲突（依赖 B）；两种全序叠完的树等于 tip 树。

---

## 十、本地门禁（真实退出码，分支 tip `42b18d0`，工作树只有未跟踪的报告目录）

| 门禁 | 命令 | 退出码 | 读数 |
|---|---|---|---|
| 结构自验 | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Scripts/selfcheck.ps1` | **0** | 「结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。」（含 IC-125 的 shell 变量紧邻非 ASCII 扫描，覆盖 `Scripts/*.sh` 与 `ci.yml`，新脚本在内） |
| 硬编码扫描 | `…-File Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 目录条目 247、产品源码引用 key 247、「用户可见硬编码残留为 0」 |
| IC-149 门禁一 | `…-File Scripts/check-swift-string-structure.ps1 -SelfTest` | **0** | 「扫描 81 个 .swift，无未闭合字符串、无括号失衡。」 |
| IC-149 门禁二 | `…-File Scripts/check-scan-needle-variant.ps1 -SelfTest` | **0** | 「扫描 39 个测试源文件，无 needle 喂错源码变体。」 |
| 空白 | `git diff --check 6dec2b1 42b18d0` | **0** | — |
| 语法 | `bash -n` 两个脚本；`bash --posix -n` 提取脚本 | **0** | — |
| 陷阱 21 | `\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]` 扫 `ci.yml`、`test-xcode.sh`、提取脚本 | — | **0** 命中 |

CI 上 #309 的「运行结构自验」「扫描用户可见硬编码字符串」两步同样 success。

---

## 十一、合并（未执行）

理由见第 3.4 条。报告提交（纯 `Reports/**`，按 `paths-ignore` 不触发 CI）推送后，决策会话若接受第三节的读法，执行：

```bash
git switch main
git merge --no-ff feature/ic-154-ci-maintenance -m "Merge IC-154：CI 维护——作业时限 30／XCTest 步骤 25、失败行全量去重提取、模拟器启动分段计时"
git push origin main
```

合并前核对：`git ls-remote origin refs/heads/main` 仍为 `6dec2b18f04ad9c76c232aeadff81cdef116d721`、工作树净。合并后 `main` 的自动运行即 G881 的数据点：登记运行编号、结论、分段耗时 notice 原文（模拟器启动／xcodebuild test／总）与作业总秒数（#308、#309 两个分支样本见第 6.2 条末段）。

---

## 十二、发现但未处理的问题（按纪律只报告不修）

1. **注解发满 10 条会挤掉 runner 的退出码注解**（第 4.2 条①）。改 9 只动一个常量与一条自测期望。
2. **作业摘要 1 MiB 上限**（第 4.4 条③）未设截断。
3. **拿下载的整包日志手工跑脚本会多出工作流回显**：ANSI 脚本源码回显（本卡之后是自测步骤负对照那条 grep 模式串）会占第二类的位置，`##[error]` 回显在第一、四类里按文本算另一条（第 9.7 条）。CI 输入不受影响；若要让脚本也适合分析下载日志，需另定规整规则（卡外）。
4. **自测步骤的源码回显仍带两处失败字面量**（`'Restarting after unexpected exit'`、`'** TEST FAILED **'`，检查必需）：之后按字面 grep 整包日志找宿主重启或 TEST FAILED 时，要先剔掉 ANSI 回显行（`[36;1m` 前缀）。按「唯一 Test Case 行」核项数不受影响（修正后 #309 实证 824／0）。
5. **启动失败的两条路径不打印分段耗时**：卡内 C2 只要求成功与 xcodebuild 失败两条路径；启动失败直接 `exit 1`。
6. **`::error` 消息未做 `%`／CR／LF 转义**：与改前相同；行内含 `%0A` 一类字面时注解会被改写。
7. **`.gitattributes` 对 `*.log` 仍无 eol 规则**（IC-149 报告第十一节第 4 条已记）：新夹具以 LF 入库，Windows 检出为 CRLF；脚本自带去 CR，本机两种行尾输出逐字节相同。
8. **第一类只认 `Test Case '…' failed`**：若日后开并行测试（`Test case '…' failed on 'Clone 1 of …'`，小写 case）或 Swift Testing 的输出格式，第一类会漏；现行 CI 两者都没用。
9. **结论行只列了卡内四种**：xcodebuild 另有 `Testing failed:`、`… encountered an error (…)`、`Early unexpected exit` 一类结论输出；在本会话看过的 #292a1／#298a1 日志里都没有出现，未加。
10. **就绪与 xcodebuild 首行输出之间 104／113 s 无输出**（第 6.2 条末段，②）：分段计时把它算进 xcodebuild 段；是 xcodebuild 启动慢还是管道缓冲，本卡数据分不出（③，要分清需另加时间戳前缀或 xcodebuild 自带计时，卡外）。

---

## 十三、人工判定项

**无。** 本卡不改产品；H72～H75 四组照旧装 #307 产物，不受本卡影响。

---

## 十四、报告内 40 位 SHA 的实读核验

报告写完后，对 `self-check.md` 与 `change-list.md` 内全部 40 位十六进制串（正则 `\b[0-9a-f]{40}\b` 去重，共 **13** 个）逐个执行 `git cat-file -e <sha>^{commit}`，**13／13 退出码 0**：

| SHA | 提交标题（节选） |
|---|---|
| `0a6b51495aa4d6b4a799f850238a527e48db158d` | ci(IC-154 A): 作业时限 15 → 30 分钟，「运行 XCTest」加步骤级时限 25 分钟 |
| `f07b9b14e4d3433cac48534dddd2a90d39c775c6` | ci(IC-154 B): 失败行提取改全量扫描 + 去重 + 注解封顶 10 条 + 全量写作业摘要 |
| `4b483fda188cbabf679ba40b128d1f07de8c388b` | ci(IC-154 C): 模拟器启动与 xcodebuild test 分段计时并发 notice（#308 被测） |
| `42b18d0024fc4580727988673e12720cf14015e0` | fix(IC-154 B): 自测步骤的 OK 行不再原样引用夹具里的失败行文本（#309 被测，分支代码 tip） |
| `6dec2b18f04ad9c76c232aeadff81cdef116d721` | docs(IC-153): 回填合并提交与 G876（基线 `main`） |
| `9b4daa5b07db92eaaaa81ae7be0e0b30a8828afc` | Merge IC-153 |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | docs: 完成 IC-089（冻结链 tip） |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | docs: 完成 IC-091 阶段一（冻结链 tip） |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | docs: IC-092 自验报告与变更清单 v2（冻结链 tip） |
| `9db02b93eccbb87d126602901807e70823535111` | test: 等待首个真实捏合完整结束（`probe/ic-067` tip） |
| `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | probe: IC-125 负对照（`probe/ic-125` tip） |
| `486bcb769b59eb1146c5a231c7998847206777cc` | probe: IC-137 媒体播放探针（`probe/ic-137` tip） |
| `d373afc7125104c01acfc296829229090e6871ce` | docs(IC-145): 自验报告与变更清单（`probe/ic-145` tip） |

报告提交本身的 SHA 在提交之后才产生，不写进报告（纪律 7：本卡未合并，没有需要回填的合并提交；若决策会话合并后要回填 G881，照 IC-150～IC-153 的做法记在 `main` 上）。报告中的 64 位串是文件 SHA-256，不是提交，`^{commit}` 核验对它们不适用。
