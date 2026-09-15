# IC-149 变更清单

- 分支：`feature/ic-149-ci-stability`
- 基线：`main` = `38d5d7f1535389902a027de87a7c2d91edf3f5b7`（IC-148 报告回填）
- 分支 tip：`07b27991c42dde24db0cc20dd60f6f6f558d30af`
- 提交数：2 个代码提交 + 1 个报告提交（本文件所在提交）

---

## 一、提交清单

| # | SHA | 类型 | 标题 | 可单独 cherry-pick |
|---|---|---|---|---|
| 1 | `012fb7183dc9c6bb3950bf2a4b44e8d2e349068e` | ci | 子项 B——执行摘要按唯一用例去重统计，附三夹具自测 | 是 |
| 2 | `07b27991c42dde24db0cc20dd60f6f6f558d30af` | chore | 子项 C——两条源码扫描门禁入仓并挂进 selfcheck | 是 |

两个提交互不依赖：子项 B 只动 `ci.yml` 与 `Scripts/summarize-xctest-log.sh` + `Scripts/fixtures/`，子项 C 只动两个新 `.ps1` 与 `Scripts/selfcheck.ps1`，无重叠文件。

**子项 A 无提交**——实测推翻任务卡的根因假设，按纪律 3 与卡内「若发现必须改产品才能达成某一项，停下报告，不要改产品」停卡。详见 `self-check.md` 第三节。

全量 40 位 SHA 见 `self-check.md` 末节「SHA 核验」。

---

## 二、文件变更全量（`git diff --name-only main...HEAD`）

```
.github/workflows/ci.yml
Scripts/check-scan-needle-variant.ps1
Scripts/check-swift-string-structure.ps1
Scripts/fixtures/xctest-restarted.log
Scripts/fixtures/xctest-single-chunk.log
Scripts/fixtures/xctest-zero.log
Scripts/selfcheck.ps1
Scripts/summarize-xctest-log.sh
```

8 个文件，全部落在任务卡白名单内。`PhotoCleanupMVE/` 前缀命中数 **0**（本卡零产品改动）。

白名单内**未动用**的三项，因子项 A 停卡：

- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`（授权改 T4 两条断言——未改，两侧 SHA-256 相同）
- `PhotoCleanupMVETests/IC149CIStabilityTests.swift`（授权新建——未建）
- `PhotoCleanupMVE.xcodeproj/project.pbxproj`（授权登记新测试文件——未动，两侧 SHA-256 相同）

因此本卡 **XCTest 项数不变，仍为 791**，pbxproj 不新增对象 id，陷阱「pbxproj 对象 id 撞号」本卡不适用。

---

## 三、逐文件说明

### 1. `.github/workflows/ci.yml`（改）

| 段 | 动作 |
|---|---|
| 新步骤「自测项数统计逻辑（IC-149 子项 B）」 | **新增**，插在「扫描用户可见硬编码字符串」之后、「运行 XCTest」**之前**（YAML 解析实证：9 个步骤，新步骤 index 5，XCTest index 6） |
| C1 统计段（原 80–86 行） | **改**：`grep … \| tail -n 1` 换成调用 `Scripts/summarize-xctest-log.sh`；新增一条「XCTest 宿主重启」notice |
| C2 IC-125 哨兵段 + C3 `exit "$test_status"` | **一字未动**。两侧分块 SHA-256 均为 `a8a5e952c2a59cad66e1265e222d7a1ab98e8c11cb165167d2d8cd332a88ba6c` |
| 其余步骤 | 未动 |

关键实现约束（写在文件注释里，改动前须先读）：`summary_line` 内 `Executed N tests` **只允许出现一处**。C2 哨兵用 `s/.*Executed ([0-9]+) tests?.*/\1/` 取值，前缀 `.*` 贪婪，出现第二处会让哨兵取到后一个数。末段小计因此只写数字、不带 `Executed` 字样。

### 2. `Scripts/summarize-xctest-log.sh`（新）

按「唯一 `Test Case` 身份去重」统计。输出 5 个 `key=value` 行：`executed_count`、`failed_case_count`、`restart_count`、`launch_count`、`summary_line`。

- 计数与去重全部在 `awk` 内完成——runner 是 GNU bash 3.2.57（IC-125 实证），未用关联数组、`mapfile`、`${var,,}`
- shell 侧变量一律 `${name}` 加半角括号（陷阱 21）
- 开头一条 `sub(/\r$/, "")`：`.log` 在 `.gitattributes` 里没有 eol 规则，统计口径不随检出设置漂移
- 退出码 0 正常产出 / 2 参数错误。**判红判绿仍由 ci.yml 的真实退出码与 IC-125 哨兵负责**，本脚本只报数

### 3. `Scripts/fixtures/`（新，3 份）

| 夹具 | 真实项数 | 失败用例 | 重启 | 旧 `tail -n 1` 口径 |
|---|---|---|---|---|
| `xctest-single-chunk.log` | 6 | 0 | 0 | 6（与新口径一致，不区分） |
| `xctest-restarted.log` | 8 | 1 | 1 | **3**（错） |
| `xctest-zero.log` | 0 | 0 | 0 | 0 |

### 4. `Scripts/check-swift-string-structure.ps1`（新，门禁一）

扫全部 `.swift`：单行字符串字面量行尾未闭合即判红；并校验大括号／小括号／方括号配平。模式栈 `code` / `string` / `interp`，只在 `code` 模式下计括号。

带 `-SelfTest`：两个合成病样各判红 + 一个健康样本零命中，自对照不过即以非 0 退出、不再扫真实源码。

### 5. `Scripts/check-scan-needle-variant.ps1`（新，门禁二）

扫测试源码里每一处 `occurrences(of:in:)`：needle 只可能落在字面量内（自带引号／文案 key 形／含中文或全角／资源文件名形）而 haystack 是 `strippedSource` 一族变体，即判红。逐函数追踪局部绑定，函数边界复位。

带 `-SelfTest`：真红型与空转型两个病样各判红 + 健康样本零命中。

两个 `.ps1` 均带 UTF-8 BOM（首 6 字节 `ef bb bf 23 52 65`），`Parser::ParseFile` 零错误。

### 6. `Scripts/selfcheck.ps1`（改）

**纯追加 18 行、0 删除**。插在既有最后一项（硬编码字符串扫描）之后、失败汇总 `if ($failures.Count -gt 0)` 之前——这是新检查项能参与判定的唯一位置。

`Add-Failure` 计数 **23 → 25**（+2，无删除）。既有检查项一条未动，结尾的成功文案亦未改（保持最小 diff）。

---

## 四、占位值登记

**本卡无出厂值变更。** `PhotoCleanupMVE/Features/S2/S2Calibration.swift` 不在 diff 内（两侧 SHA-256 均为 `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f`），`schemaVersion` 仍为 **7**（`:118`），无需递增。

---

## 五、不得触碰项两侧核验

| 文件 | 两侧 SHA-256 | 结论 |
|---|---|---|
| `Scripts/test-xcode.sh` | `a1bad7252b9dbebf8f1cbc42c57ef2d0367fbe2f87774c8cb6006a3f007b72d9` | 相同 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | `46e1963bd50f645be571c686fe4f77147f4343d0a9b46a047f0909bc597ffa9d` | 相同 |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f` | 相同 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | `9e7da1b882022ef9b683bf969ef7caccbc7cc0c9b0303ed13fa44953055739f6` | 相同（子项 A 停卡） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `3fbb1ed1c1e174e09f6b5b3dd4cb1ef261ab4fb738dd2afceb3440baee571bac` | 相同 |

冻结三链与探针分支远端 tip（`git ls-remote origin`，本卡未触碰）：

```
b368a6caee846e664391b0620350395bfe6fbc7f refs/heads/feature/ic-089-nx-edge-bounce
6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d refs/heads/feature/ic-091-nx-midgesture-handoff
a7cc1ec727a3a493f5263e688a316cbf4c743562 refs/heads/feature/ic-092-nx-window-follow
9db02b93eccbb87d126602901807e70823535111 refs/heads/probe/ic-067-screenshot-subtype
486bcb769b59eb1146c5a231c7998847206777cc refs/heads/probe/ic-137-media-playback
d373afc7125104c01acfc296829229090e6871ce refs/heads/probe/ic-145-scan-service
```

与 CLAUDE.md 所记短 SHA 逐条相符（`b368a6c` / `6736f1e` / `a7cc1ec` / `486bcb7` / `d373afc`）。
