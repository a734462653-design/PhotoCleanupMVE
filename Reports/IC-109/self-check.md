# IC-109 自验报告：IC-108 合并入 main（含 v2 重跑）

> 本文为**完整替换版**，覆盖 IC-109 原卡（合并）与 IC-109 v2（重跑 CI #194）两段工作。

## 结论（先行）

**本卡全部通过。**

- **G261 通过**：合并零冲突，合并提交与分支 tip 树同一（tree SHA 均为 `077fbf49bd93b1c28085db9858599af01b81683d`）。
- **G262 / G265 通过（经 attempt 2）**：CI **#194 attempt 2** `success`，**`Executed 525 tests, with 0 failures (0 unexpected)`**，**真实退出码 0**，9/9 步全绿，IPA **854930 字节**、SHA-256 **`76e46e89ee073ddc557aab621c111517d9672d1d6bca4b0c2fc47e50c446724e`**。
- **G263 通过**：冻结三链 SHA 未变；`main` 上 `schemaVersion == 6` 唯一。
- **G264 通过**：rerun 用 1 次（预算 1 次）。
- **G266 不适用**：attempt 2 未落入分叉（既非同签名红，亦非新签名红）。

**attempt 1 的红已定性为 runner 侧偶发（①）**：同一提交 `43a89a4`、同一代码树，attempt 1 红、attempt 2 绿，零代码改动。判定依据不再依赖推测。**具体机制**（`test-xcode.sh:41` 无可用 iPhone 模拟器）**仍为③**——日志端点不可用，未取得实证。

CLAUDE.md 第七节基线行已按 attempt 2 实值更新（见「基线行更新」一节）。

---

## 输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260830-109-merge-108-into-main.md` + `<top>/Tasks/IC-20260830-109-v2-rerun.md` |
| 合并前 `main` | `e08f7de665d51cfdb5be029865a691c7c4152c6b`（①核对一致） |
| 被合并分支 tip | `feature/ic-108-follow-and-zoom-probe` = `be8179e46da298a03c861e8f6c4f0cff707b77c0`（①核对一致） |
| merge-base | `e08f7de665d51cfdb5be029865a691c7c4152c6b`（= `main` tip，①） |
| 合并提交 | `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e` |
| v2 开工时 `main` | `bf29deecaf36ebacc2a8dd6e4ac77b0de6b2fe34`（①核对一致） |
| 范围边界 | **零代码改动**；未碰 SPEC、Decision_log、`ci.yml`、`Scripts/`、`test-xcode.sh`；未 rebase / force push / 删分支；rerun 之外无任何 gh 写操作；未再次合并或 revert |

开工检查（纪律第 8 条）：两段工作开工前 `git status --porcelain` 均为空，工作树净（①）。

---

## 逐条验收门禁

### G261 合并零冲突 + 树同一性 —— **通过**（①）

- `git merge --no-ff feature/ic-108-follow-and-zoom-probe -m "merge: IC-108 follow + zoom probe into main (IC-109)"`
  → `Merge made by the 'ort' strategy.`，**退出码 0**，无冲突。
- 变更规模：8 files changed, 1294 insertions(+), 6 deletions(-)。
- 合并提交双亲：`e08f7de665d51cfdb5be029865a691c7c4152c6b` + `be8179e46da298a03c861e8f6c4f0cff707b77c0`（①）。
- `git diff 43a89a4… be8179e…` → **输出为空**，`--stat` 行数 0（①）。
- 两侧 tree SHA 均为 `077fbf49bd93b1c28085db9858599af01b81683d`（①，强于空 diff 的同一性证据）。

### G262 / G265 CI 绿 —— **通过（attempt 2）**（①）

| 项 | 要求 | attempt 2 实测 |
|---|---|---|
| run id / 编号 | 登记 | **`33236538218`，#194，run_attempt = 2** |
| 被测提交 | `43a89a4…` | `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e`（一致） |
| 结论 | success | **success** |
| 真实退出码 | 0 | **0**（`ci.yml` 以 `exit "$test_status"` 原样退出，步骤 6 `success`） |
| XCTest | 525 项 0 失败 | **`Executed 525 tests, with 0 failures (0 unexpected) in 24.504 (37.557) seconds`** |
| IPA 字节数 | 登记 | **854930** |
| IPA SHA-256 | 登记 | **`76e46e89ee073ddc557aab621c111517d9672d1d6bca4b0c2fc47e50c446724e`** |

- 触发方式：`gh run rerun 33236538218`（本卡授权的唯一账号写操作），本机 2026-08-28 23:29:25 触发，首次尝试即成功（真实退出码 0）。
- 作业时间：`2026-08-29T06:29:32Z → 06:39:11Z`（约 579 s），与 #193 的 616 s 同量级。
- 九步全绿（①，来自 `actions/runs/33236538218/attempts/2/jobs`）：

| 步骤 | 名称 | attempt 1 | attempt 2 |
|---|---|---|---|
| 1 | Set up job | success | success |
| 2 | 检出源码 | success | success |
| 3 | 显示 Xcode 环境 | success | success |
| 4 | 运行结构自验 | success | success |
| 5 | 扫描用户可见硬编码字符串 | success | success |
| 6 | 运行 XCTest | **failure** | **success** |
| 7 | 构建未签名应用 | skipped | **success** |
| 8 | 上传可下载的未签名 IPA | skipped | **success** |
| 9 | Complete job | success | success |

- artifact：`PhotoCleanupMVE-unsigned-43a89a4bf387`（id `9710774363`，zip **855100** 字节，未过期，创建于 `2026-08-29T06:39:08Z`）。
- **IPA 复核说明**：字节数与 SHA-256 取自 CI 内「未签名 IPA 校验」步骤 notice 注解（CI 侧实算，①），与 IC-108 报告同口径。本机未重下复核——IPA 归档不可复现（IC-094/097 证据①），本次亦复证：字节数 854930 与 #193 **完全一致**，SHA-256 则不同（#193 为 `3555045749d8…`，本次为 `76e46e89ee07…`）。

### G263 冻结链不动 + `schemaVersion` 唯一 —— **通过**（①）

- `feature/ic-089-nx-edge-bounce` = `b368a6caee846e664391b0620350395bfe6fbc7f`（未变，本地与远端一致）
- `feature/ic-091-nx-midgesture-handoff` = `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`（未变）
- `feature/ic-092-nx-window-follow` = `a7cc1ec727a3a493f5263e688a316cbf4c743562`（未变）
- 合并后 `main` 上 `static let schemaVersion` 仅一处：`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118` = `6`（①）。本卡无出厂值变更，版本号不递增。

### G264 rerun 预算 —— **通过**（①）

`gh run rerun 33236538218` 执行 **1 次**（预算 1 次），首次即成功触发。

### G266 分叉处置 —— **不适用**

attempt 2 为 success，未落入 (a) 同签名红或 (b) 新签名红任一分支。

---

## attempt 1 红的归因（结论已升级）

### attempt 1 实测（①）

- 结论 `failure`，**真实退出码 1**，时长 50 s（作业 `05:35:58Z → 05:36:44Z`，46 s）。
- 步骤 6「运行 XCTest」失败；步骤 7、8 `skipped`，**未产生 IPA**；**未产生 `Executed N tests` 摘要**。
- 失败注解：「XCTest 失败 / **未找到具体错误行。**」与「Process completed with exit code 1.」。

### 已升级为①的部分

**attempt 1 的红是 runner 侧偶发，与代码无关。** 依据不再是推测：**同一提交、同一代码树、零改动**，attempt 1 红、attempt 2 绿（525/0）。非确定性因素只能在运行环境侧。

另有两条独立佐证（均①）：

1. 排除 `Reports/**`（不参与编译）后，被测产品代码树与 CI #193（`f450566`，525 项 0 失败，绿）**逐字节相同**：`git diff --name-only f450566 43a89a4 | grep -v '^Reports/'` 为空。
2. 编译失败的证据形态不同：同分支 #192（`3aea742`，61 s，红）退出码为 **65**，注解含具体行 `…/S2View.swift:668:61: error: extra arguments at positions #12, #13 in call`；attempt 1 退出码为 **1** 且「未找到具体错误行。」。

### 仍为③的部分

**具体失败机制未实证。** `Scripts/test-xcode.sh` 全脚本只有两处以 `exit 1` 结束且都不产生 `error:` 行：第 10–13 行（环境无 `xcodebuild`）与第 38–42 行（`xcodebuild -showdestinations` 未解析出 `platform:iOS Simulator` 且 `name:iPhone` 的目标 → 打印「错误：没有可用的 iPhone 模拟器。」）。步骤 3 成功说明 `xcodebuild` 存在，故③推测落在第 41 行。

**注**：步骤 3 执行的 `xcrun simctl list devices available` 即使设备列表为空也退出 0，故步骤 3 成功**不能**反证模拟器可用。

**未覆盖项**：验证需读 attempt 1 作业日志确认是否出现「错误：没有可用的 iPhone 模拟器。」。本机 `gh api repos/…/actions/jobs/99058387535/logs` 累计约 60 次尝试（gh 与 curl、代理与直连交替）全部返回 `EOF`，日志未取到。**如实标注未覆盖，不以推断冒充实测。**

---

## 本地门禁（本机 Windows，①）

v2 收尾时复跑，工作树为合并后状态：

| 门禁 | 真实退出码 | 结果 |
|---|---|---|
| `git diff --check` | 0 | 通过 |
| `Scripts/selfcheck.ps1` | 0 | 通过（目录条目 181；源码引用 key 181；用户可见硬编码残留 0；测试数量门禁符合） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 通过（同上口径） |

CI 侧步骤 4、5 为同两个脚本，attempt 1 与 attempt 2 均 `success`。

---

## 基线行更新

`<top>/CLAUDE.md` 第七节「当前阶段」首行按 IC-107 卡附录 A1 格式更新，数值取 attempt 2 实值：报告提交 SHA、merge 提交 `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e`、**CI #194（attempt 2）**、**XCTest 525 项 0 失败**；交付列表追加「IC-108（A 跟随即时化 / B 双击诊断探针）、IC-109」，链内 merge 提交清单追加 IC-109 的 1 个（`43a89a4…`）。

**措辞偏离说明**：A1 原格式为「CI #<CI_RUN>」，本次写作「CI #194（attempt 2）」。attempt 1 为红，只写「CI #194」会指向一个不成立的通过结论，故补注 attempt 编号。此为**准确性所需的最小偏离**，其余措辞一字未改。

第七节其余小节（`schemaVersion` 行、冻结分支行、分支保留行、规格行、下一阶段行）与「未定项」小节**未动**。

---

## 人工判定项（保留给 Lynn / 决策会话，不代为下结论）

1. **IC-108 的真机行为**（子项 A 跟随即时化、子项 B 探针读数）已由 Lynn 于 2026-08-30 判定通过（「其他没问题」），本卡不重复判定。第 2 项连带发现的 Nx 贴边回弹诉求另行立项，不在本卡范围。
2. **runner 模拟器解析加固**是否立卡：attempt 1 已证 runner 侧存在偶发失败。`ci.yml` / `test-xcode.sh` 的目标选择加固属本卡范围外，未改，留决策会话排期。

---

## 发现但未处理的问题（按纪律只报告不修）

1. **本机 gh 对 `actions/jobs/<id>/logs` 端点持续不可用**：累计约 60 次尝试全部 `EOF`；同期 `actions/runs`、`actions/runs/<id>/attempts/<n>/jobs`、`commits/<sha>/check-runs`、`check-runs/<id>/annotations`、`actions/runs/<id>/artifacts` 均在 1–10 次重试内成功。**结论：红了读不到日志时，改读 `check-runs/<id>/annotations`**——本卡的 XCTest 摘要与 IPA 校验值即全部取自该端点。
2. **git 代理需求与 CLAUDE.md 第五节记载不符**：该节记「`git fetch`/`push` 走直连，设 `HTTPS_PROXY` 反而失败」。本次**环境变量形式两向皆失败**（均报 `schannel: failed to receive handshake`；注意 `ALL_PROXY` 也被 git 读取，需一并清除才算真直连），最终成功形式为**显式配置**：`git -c http.proxy=http://127.0.0.1:7890 -c https.proxy=… fetch/push`。`push` 亦需重试（首次推送第 3 次才成功）。
3. **`ci.yml` 失败注解信息量不足**：步骤 6 失败时若日志无 `error:` / `Test Case … failed` 行，注解仅有「未找到具体错误行。」，不回显脚本 stderr（如「错误：没有可用的 iPhone 模拟器。」）。在日志端点不可用时，这直接导致根因无法实证。属 `ci.yml` 范围外，未改。
