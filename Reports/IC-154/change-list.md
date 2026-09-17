# IC-154 变更清单

- 任务卡：`<top>/Tasks/IC-20260916-154-ci-maintenance.md`
- 分支：`feature/ic-154-ci-maintenance`
- 基线：`main` = `6dec2b18f04ad9c76c232aeadff81cdef116d721`（IC-153 报告回填；IC-153 合并提交 `9b4daa5b07db92eaaaa81ae7be0e0b30a8828afc`）
- 分支 tip（代码）：`42b18d0024fc4580727988673e12720cf14015e0`
- 分支 tip（含报告）：`7e350bd994aa0c18c7ccc98c7dd04fcb8bd97eae`
- 合并提交（`main`，`--no-ff`，Lynn 手工执行）：`20a19df6827f98f42e62911cdadd714dd33d2f0f`；合并后 `main` 运行 #310 attempt 1 红于 `testIC063…` 计时脆弱用例、原样复跑 attempt 2 绿 824 项 0 失败（G881，`self-check.md` 第八节）
- 提交数：4 个代码提交（子项 A／B／C 各一 + 子项 B 的一个修正）+ 1 个报告提交（分支）+ 合并提交 + 本回填提交（`main`）
- **已合并（回填）**：报告提交时 G880 有三处条文按字面不可能满足（`self-check.md` 第三节），照第 178 条先例把合并交回决策会话；决策会话裁定接受三处读法（Decision_log 第 181 条）后合并
- 零产品改动：`PhotoCleanupMVE/`、`PhotoCleanupMVETests/`、`PhotoCleanupMVE.xcodeproj/` 各 **0** 命中；XCTest 项数不变
- `schemaVersion`：**7，未动**

---

## 一、提交清单

| # | SHA | 子项 | 标题 |
|---|---|---|---|
| 1 | `0a6b51495aa4d6b4a799f850238a527e48db158d` | A | 作业时限 15 → 30 分钟，「运行 XCTest」加步骤级时限 25 分钟 |
| 2 | `f07b9b14e4d3433cac48534dddd2a90d39c775c6` | B | 失败行提取改全量扫描 + 去重 + 注解封顶 10 条 + 全量写作业摘要 |
| 3 | `4b483fda188cbabf679ba40b128d1f07de8c388b` | C | 模拟器启动与 xcodebuild test 分段计时并发 notice |
| 4 | `42b18d0024fc4580727988673e12720cf14015e0` | B（修正） | 自测步骤的 OK 行不再原样引用夹具里的失败行文本 |
| 5 | `7e350bd994aa0c18c7ccc98c7dd04fcb8bd97eae` | — | docs：自验报告与变更清单（#309 绿 824 项 0 失败） |
| 合并 | `20a19df6827f98f42e62911cdadd714dd33d2f0f` | — | Merge IC-154（父提交 `6dec2b1` 与 `7e350bd`） |

提交 4 的来由：提交 3 为 tip 的 CI #308 全绿，但解析整包日志时发现自测步骤的一条 OK 行把夹具里的 `Test Case '-[PhotoCleanupMVETests.StormTests testStormManyAssertions]' failed (4.321 seconds).` 原样打进了作业日志，按「唯一 Test Case 行」核项数会数成 824 passed + **1 failed**（`self-check.md` 第 6.2 条）。提交 4 只改该步里的提示文字与注释（三条 OK 提示、三条失败提示、两段注释，另加两行注释说明缘由），检查逻辑与期望值一字未动。

**可摘取单元（惯例 40，①实测）**：在草稿区另克隆一份仓库（`core.autocrlf=false`），从 `6dec2b1` 分离检出后 `cherry-pick`：

| 摘取 | 结果 | 说明 |
|---|---|---|
| 1 单独 | 无冲突，只改 `ci.yml` | 摘取后作业时限 30、XCTest 步骤时限 25、9 步 |
| 2 单独 | 无冲突 | `ci.yml` + 两个新文件；作业时限 15、10 步 |
| 2→4 | 无冲突 | B 的完整交付 |
| 3 单独 | 无冲突，只改 `test-xcode.sh` | — |
| **4 单独** | **冲突** | 4 改的是 2 新增的自测步骤，只能随 2 连续摘取 |
| 3→2→4→1、1→2→3→4 | 无冲突 | 两种顺序叠完的树对象都等于分支 tip `42b18d0` 的树对象 |

即：A、C 各自可单独摘取；B 是「2→4」连续序列。卡内「三个子项各自可单独摘取」在子项层面成立。A 与 B 在 `ci.yml` 上相邻（B 的自测步骤插在「运行 XCTest」这一行之前，A 的步骤级时限插在它之后），中间隔着这一行未改动的行，三方合并不判冲突——上表即实证。

---

## 二、文件变更全量（`git diff --name-status 6dec2b1..42b18d0`）

```
M	.github/workflows/ci.yml
A	Scripts/extract-xctest-failures.sh
A	Scripts/fixtures/xctest-failures-many.log
M	Scripts/test-xcode.sh
```

四个路径全部落在卡内白名单表内（`Reports/IC-154/` 在报告提交里）。

### 行数（`git diff --numstat 6dec2b1..42b18d0`）

| 文件 | 增 | 删 | 子项 |
|---|---|---|---|
| `.github/workflows/ci.yml` | 201 | 8 | A 2／1 + B 197／7 + B 修正 12／10 |
| `Scripts/extract-xctest-failures.sh`（新） | 154 | 0 | B |
| `Scripts/fixtures/xctest-failures-many.log`（新） | 98 | 0 | B |
| `Scripts/test-xcode.sh` | 44 | 1 | C |

`ci.yml` 263 → 456 行；`test-xcode.sh` 65 → 108 行。

### hunk 头（G878）

整体 diff（`git diff 6dec2b1 42b18d0 -- .github/workflows/ci.yml`）：

```
@@ -18,7 +18,7 @@ jobs:
@@ -131,7 +131,167 @@ jobs:
@@ -164,19 +324,52 @@ jobs:
```

分提交：

```
[0a6b514 子项 A]
@@ -18,7 +18,7 @@ jobs:            ← Y1 作业级 timeout-minutes 15 → 30
@@ -132,6 +132,7 @@ jobs:          ← Y2 「运行 XCTest」步骤加 timeout-minutes: 25
[f07b9b1 子项 B]
@@ -131,6 +131,163 @@ jobs:        ← 新增「自测失败行提取（IC-154 子项 B）」步骤（Y3 之后、运行 XCTest 之前）
@@ -165,19 +322,52 @@ jobs:       ← Y2 失败行提取段（原 :167-180）
@@ -0,0 +1,154 @@                ← Scripts/extract-xctest-failures.sh
@@ -0,0 +1,98 @@                 ← Scripts/fixtures/xctest-failures-many.log
[4b483fd 子项 C]
@@ -54,12 +54,55 @@ echo "使用 iPhone 模拟器：${destination_name} (id=${destination_id}, runti   ← T2
[42b18d0 子项 B 修正]（五个 hunk 全在提交 2 新增的自测步骤内）
@@ -161,6 +161,8 @@ jobs:
@@ -178,8 +180,8 @@ jobs:
@@ -206,18 +208,18 @@ jobs:
@@ -235,8 +237,8 @@ jobs:
@@ -246,9 +248,9 @@ jobs:
```

整体 diff 的第二个 hunk 是 A 的步骤级时限与 B 的自测步骤因相邻而合并显示。A 恰两处 hunk（A2）。

### 零改动实证

| 前缀／文件 | 结果 |
|---|---|
| `PhotoCleanupMVE/`、`PhotoCleanupMVETests/`、`PhotoCleanupMVE.xcodeproj/`（`git diff --name-only 6dec2b1..42b18d0 \| grep -c "^<前缀>"`） | **0**、**0**、**0** |
| `Scripts/summarize-xctest-log.sh` | 两侧 SHA-256 `35f933e9b4152bcfa18ed6ee2a5d1bf00354b67b2372e4e6dca86e7bd218d4b9`，相同 |
| `Scripts/selfcheck.ps1` | `89cd8c572f798a58d3181affffe27f34c2759869e23323e5d9b2f18efddb1ea4`，相同 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | `46e1963bd50f645be571c686fe4f77147f4343d0a9b46a047f0909bc597ffa9d`，相同 |
| `Scripts/check-swift-string-structure.ps1`（IC-149 门禁一） | `c8876784d243ddca8b149ba64ecb02d62f3267db01d90e9acdd2adf90d625d2e`，相同 |
| `Scripts/check-scan-needle-variant.ps1`（IC-149 门禁二） | `169b68c4234b0a87ebcfd16bcc2f164addef540b7ff8fd701f33dd71dd298608`，相同 |
| `Scripts/fixtures/xctest-single-chunk.log` | `9ffe804584c8ccb217729c061025a97ff7bd3b48add559e49d0c78d6d180d983`，相同 |
| `Scripts/fixtures/xctest-restarted.log` | `319d5be6d1a431cd7f767534d06fab0bdf28b598cb62b612b0c0f410a54c684f`，相同 |
| `Scripts/fixtures/xctest-zero.log` | `c63d3e94ec8a1c938d59777eb27ce12f2749bd97052e8b234816c2827ca86141`，相同 |

（SHA-256 取 `git show <rev>:<path> | sha256sum`，两侧分别为 `6dec2b1` 与 `42b18d0`。）

---

## 三、逐文件说明

### 子项 A：`.github/workflows/ci.yml`

- `:21` 作业级 `timeout-minutes: 15` → `30`。
- 「运行 XCTest」步骤在 `name` 与 `run` 之间加 `timeout-minutes: 25`。
- 其余步骤不加步骤级时限；`cancel-in-progress`、`paths-ignore`、xcodebuild 参数未动。

### 子项 B

- **`Scripts/extract-xctest-failures.sh`（新，154 行）**：用法 `extract-xctest-failures.sh <日志文件>`，退出码 0 正常、2 参数错误。整份日志逐行规整（去行尾 CR、去行首 GitHub 日志时间戳）后分四类：一 `Test Case .* failed`；二 `PhotoCleanupMVETests/.*error:`，去重键为 `PhotoCleanupMVETests/<文件>:<行>`（取不出时退回整行）；三 `PhotoCleanupMVE/.*error:`（第二类以外）；四 结论行（行首或非字母后的 `Fatal `、`Restarting after unexpected exit, crash, or test timeout`、`** TEST FAILED **`、`Process completed with exit code`）。一行只归最靠前的一类；第二类以外按整行文本去重；同类内按首次出现先后。输出三个 `key=value`（`candidate_count`／`unique_count`／`annotation_count`）与 `--- annotations ---`（前 `annotation_limit` 条，`annotation_limit=10` 为脚本顶部具名常量）、`--- all ---` 两段；输出中的 `Executed` 一律改写为 `executed`。四类匹配范围包含改前 grep 的三种模式。bash 侧只做参数校验；awk 程序不用 gawk 扩展与正则区间。
- **`Scripts/fixtures/xctest-failures-many.log`（新，98 行，LF）**：时间戳格式与既有夹具相同。第一段 `AlphaTests` 1 个通过用例；`StormTests.testStormManyAssertions` 在 32 个不同源码行（`StormTests.swift:101`～`:194`，步长 3）断言失败、每条印两遍，其中 `:161` 在循环里以两种消息各失败一次（按文件:行只算一条，按文本算两条），`:131` 的消息里带两处 `Executed`（输出改写的负对照）；该用例以 `Test Case … failed (4.321 seconds).` 收尾；随后 `testStormCrash` 起跑、`Simultaneous accesses…`、`Fatal access conflict detected.`、宿主重启标记；第二段 `BetaTests` 3 个通过用例、三级套件小计、`** TEST FAILED **`。**构成**：测试目标 error 行 66（32 个文件:行、33 种文本）+ `Test Case … failed` 1 + 结论行 3 ⟹ 候选 **70**（> 50）、去重 **36**、注解 **10**；改前 grep 模式命中 67 行，取尾 50 行丢掉前 17 行（含 `:101` 两遍）。
- **`ci.yml` 新步骤「自测失败行提取（IC-154 子项 B）」**（在「自测项数统计逻辑（IC-149 子项 B）」之后、「运行 XCTest」之前，照该步的样板写）：三份夹具各跑一遍脚本、输出落盘；逐项核——每份输出退出码 0 且不含 `Executed`；组一（新夹具）`candidate_count > 50`、`unique_count = 36`、`annotation_count = 10` 且 annotations 段恰 10 行、annotations 第 1 行是 Test Case 失败行、all 段含宿主重启标记与测试失败结论行各 1 条、all 段优先序「1 → 32 → 3，共 36」；组二（`xctest-restarted.log`）按结果核（见 `self-check.md` 第 3.3 条）；组三（`xctest-single-chunk.log`）`candidate_count = 0`、`annotation_count = 0`；负对照——改前 grep 取尾 50 行恰 50 行且不含第一条断言失败行（`StormTests.swift:101`），新口径 all 段含该行 1 条。任一不成立发 `::error title=失败行提取自测::…` 并以 1 退出。OK 行一律不原样带失败行文本（提交 4）。
- **`ci.yml`「运行 XCTest」失败行段（原 `:167-180`）**：`test_status -ne 0` 时调脚本（`|| true`），annotations 段逐行 `::error title=XCTest 失败::`，一条都没有时发 `::error title=XCTest 失败::未找到具体错误行。`；随后向 `$GITHUB_STEP_SUMMARY` 追加标题「XCTest 失败行（全量）」、候选行总数／去重后条数／已发注解条数三个数与 all 段全文（`text` 围栏）。「已发注解条数」取实际发出的条数（回落那一条也计 1）。摘要 notice（原 `:151-165`）与 IC-125 哨兵（原 `:182-192`）逐字未动。

### 子项 C：`Scripts/test-xcode.sh`（仅 T2）

- 目的地选定、simctl 实证输出之后：`boot_started="$(date +%s)"`；`xcrun simctl boot "${destination_id}"`（合并 stderr 捕获输出）——退出码 0 照常；非 0 时输出含 `Unable to boot device in current state: Booted` 视为已启动、打印一行说明后继续，其余情形打印错误与 simctl 原输出并 `exit 1`；随后 `xcrun simctl bootstatus "${destination_id}" -b`，失败打印错误并 `exit 1`；`boot_seconds=$(( $(date +%s) - boot_started ))`。
- `xcodebuild` 调用改为 `if xcodebuild \ … then xcodebuild_status=0 else xcodebuild_status=$? fi`，六个参数行逐字未动；`xcodebuild_seconds` 同法计秒。
- 两条路径都打印 `XCTest 分段耗时：模拟器启动 N s；xcodebuild test M s；总 T s` 并发 `::notice title=XCTest 分段耗时::模拟器启动 N s；xcodebuild test M s；总 T s`（T = bash 的 `SECONDS`，脚本自启动起的秒数；裁定 三要求的「总 T s」）；xcodebuild 非 0 时 `exit "${xcodebuild_status}"` 原样透传，0 时照旧打印「XCTest 已全部通过。」。
- `:21-55` 目的地选择逐字未动。

---

## 四、`ci.yml` 步骤表（`42b18d0`）

| # | 步骤 | 步骤级时限 | 本卡 |
|---|---|---|---|
| 1 | 检出源码 | — | 未动 |
| 2 | 选择 Xcode 26 工具链（IC-116） | — | 未动 |
| 3 | 显示 Xcode 环境 | — | 未动 |
| 4 | 运行结构自验 | — | 未动 |
| 5 | 扫描用户可见硬编码字符串 | — | 未动 |
| 6 | 自测项数统计逻辑（IC-149 子项 B） | — | 未动 |
| 7 | **自测失败行提取（IC-154 子项 B）** | — | **新增**（B、B 修正） |
| 8 | 运行 XCTest | **25** | 步骤级时限（A）、失败行段（B） |
| 9 | 构建未签名应用 | — | 未动 |
| 10 | 上传可下载的未签名 IPA | — | 未动 |

作业级时限 **30**。（GitHub 作业页的步骤序号另含首尾的 Set up job／Complete job，比本表各多 1。）

---

## 五、占位值登记

本卡**无**标定出厂值变更，`S2CalibrationConfiguration.schemaVersion` 保持 **7**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`，文件不在 diff 内）。脚本常量 `annotation_limit=10` 是 GitHub 每步 error 注解上限的登记值，不是出厂值。
