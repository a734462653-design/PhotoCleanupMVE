# IC-109 自验报告：IC-108 合并入 main

## 结论（先行）

**本卡未完成，按 G262 停在 CI 红。**

- **G261 通过**：合并零冲突，合并提交与分支 tip 树同一（tree SHA 均为 `077fbf49bd93b1c28085db9858599af01b81683d`）。
- **G262 失败**：CI #194 结论 `failure`，真实退出码 **1**，**未产生任何 XCTest 项数**，未产生 IPA（打包与上传步骤 `skipped`）。按卡内明令「若红即停——不得自行修复」，**未做任何修复尝试，未重跑 CI**（预算 CI 1 次已用尽）。
- **G263 通过**：冻结三链 SHA 未变；合并后 `main` 上 `schemaVersion == 6` 唯一。
- **范围内第 4 项（CLAUDE.md 基线行）未执行**，理由见「未执行项」一节——授权文本要求登记「CI 编号、XCTest 525 项 0 失败」，该事实本次未发生，按纪律第 5 条不伪造通过。

**关键矛盾（须决策会话裁定）**：本次被测产品代码树与 CI #193（`f450566`，**525 项 0 失败**，绿）**逐字节相同**（①，证据见下），同一代码在 #193 绿、在 #194 红。故 #194 的红**不指向本次合并引入的任何代码变化**。

---

## 输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260830-109-merge-108-into-main.md` |
| 合并前 `main` | `e08f7de665d51cfdb5be029865a691c7c4152c6b`（①核对一致） |
| 被合并分支 tip | `feature/ic-108-follow-and-zoom-probe` = `be8179e46da298a03c861e8f6c4f0cff707b77c0`（①核对一致） |
| merge-base | `e08f7de665d51cfdb5be029865a691c7c4152c6b`（= `main` tip，①） |
| 合并提交 | `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e` |
| 目标分支 | `main`（已推送，`origin/main` = `43a89a4…`，①） |
| 范围边界 | 无任何代码改动；未碰 SPEC、Decision_log、`ci.yml`、`Scripts/`；未 rebase / force push / 删分支 |

开工检查（纪律第 8 条）：`git status --porcelain` 空，工作树净（①）。

---

## 逐条验收门禁

### G261 合并零冲突 + 树同一性 —— **通过**（①）

- `git merge --no-ff feature/ic-108-follow-and-zoom-probe -m "merge: IC-108 follow + zoom probe into main (IC-109)"`
  → `Merge made by the 'ort' strategy.`，**退出码 0**，无冲突。
- 变更规模：8 files changed, 1294 insertions(+), 6 deletions(-)。
- 合并提交双亲：`e08f7de665d51cfdb5be029865a691c7c4152c6b` + `be8179e46da298a03c861e8f6c4f0cff707b77c0`（①）。
- `git diff 43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e be8179e46da298a03c861e8f6c4f0cff707b77c0` → **输出为空**，`--stat` 行数 0（①）。
- 两侧 tree SHA 均为 `077fbf49bd93b1c28085db9858599af01b81683d`（①，比空 diff 更强的同一性证据）。

### G262 CI success / 525 项 0 失败 / 退出码 0 / IPA 登记 —— **失败**（①）

| 项 | 卡内预期 | 实测 |
|---|---|---|
| 运行编号 | — | **#194**（run id `33236538218`） |
| 被测提交 | `43a89a4…` | `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e`（一致） |
| 结论 | success | **failure** |
| 真实退出码 | 0 | **1** |
| XCTest 项数 | 525 | **未产生**（无 `Executed N tests` 摘要 notice） |
| 失败数 | 0 | **不适用**（测试未执行到） |
| IPA 字节数 / SHA-256 | 登记 | **无产物**，无法登记 |

- 创建时间 `2026-08-29T05:35:54Z`，运行时长 **50 s**；作业本身 `2026-08-29T05:35:58Z → 05:36:44Z`（46 s）。
- 步骤结果（①，来自 `actions/runs/33236538218/jobs`）：

| 步骤 | 名称 | 结论 |
|---|---|---|
| 1 | Set up job | success |
| 2 | 检出源码 | success |
| 3 | 显示 Xcode 环境 | success |
| 4 | 运行结构自验 | success |
| 5 | 扫描用户可见硬编码字符串 | success |
| 6 | **运行 XCTest** | **failure** |
| 7 | 构建未签名应用 | skipped |
| 8 | 上传构建的未签名 IPA | skipped |
| 9 | Complete job | success |

- 失败注解（①，来自 `check-runs/99058387535/annotations`）：
  - `XCTest 失败` → **`未找到具体错误行。`**
  - `Process completed with exit code 1.`

**按卡内 G262「若红即停」，就地停止。未修改任何文件以试图转绿，未重跑 CI。**

### G263 冻结链不动 + `schemaVersion` 唯一 —— **通过**（①）

- `feature/ic-089-nx-edge-bounce` = `b368a6caee846e664391b0620350395bfe6fbc7f`（未变）
- `feature/ic-091-nx-midgesture-handoff` = `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`（未变）
- `feature/ic-092-nx-window-follow` = `a7cc1ec727a3a493f5263e688a316cbf4c743562`（未变）
- 远端同 SHA（`fetch` 后核对 `origin/feature/ic-089…`、`…091…`、`…092…`，①）
- 合并后 `main` 上 `static let schemaVersion` 仅一处：`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118` = `6`（①）。本卡无出厂值变更，版本号不递增。

---

## 根因分析：#194 为何红

### 已排除项（①）

**不是本次合并引入的代码差异。** 排除 `Reports/**`（不参与编译）后，合并提交与 CI #193 被测提交 `f450566` 的产品代码树**无任何差异**：

- `git diff --name-only f450566 be8179e` → 仅 `Reports/IC-108/change-list.md`、`Reports/IC-108/self-check.md`
- `git diff --name-only f450566 43a89a4 | grep -v '^Reports/'` → **空**

即 #194 编译的源码与 #193（**525 项 0 失败**，绿，时长 616 s）编译的源码逐字节相同。

**不是编译错误。** 同分支 #192（`3aea742`，61 s，红）是编译失败，其证据形态为：真实退出码 **65**，注解含具体行 `…/S2View.swift:668:61: error: extra arguments at positions #12, #13 in call`。本次 #194 退出码为 **1**，且注解为「未找到具体错误行。」，两者形态不同。

**不是测试失败。** `ci.yml` 第 65–79 行仅在日志中既无 `PhotoCleanupMVE/.*error:` / `PhotoCleanupMVETests/.*error:`、又无 `Test Case .* failed` 时才输出「未找到具体错误行。」。故日志中不存在失败的测试用例行。

### 归因（③推测，附验证方法）

`Scripts/test-xcode.sh` 全脚本只有两处以 **exit 1** 结束，且两处都不产生任何 `error:` 行：

- 第 10–13 行：环境无 `xcodebuild`；
- 第 38–42 行：`xcodebuild -showdestinations` 的输出中未解析出 `platform:iOS Simulator` 且 `name:iPhone` 的目标 → 打印「错误：没有可用的 iPhone 模拟器。」并 `exit 1`。

其余失败路径（`set -euo pipefail` 下 `xcodebuild` 自身失败）会带出 xcodebuild 的退出码（#192 实证为 65），与本次的 1 不符。

步骤 3「显示 Xcode 环境」成功，说明 `xcodebuild` 存在，故**③推测：GitHub `macos-15` runner 镜像上未解析出可用 iPhone 模拟器目标，脚本在第 41 行退出 1**——属运行环境侧问题，与本卡合并的代码无关。

**注**：步骤 3 执行的 `xcrun simctl list devices available` 即使设备列表为空也退出 0，因此步骤 3 成功**不能**反证模拟器可用。

**验证方法**：读取 #194 作业日志，确认是否出现「错误：没有可用的 iPhone 模拟器。」及其后的 destinations 转储。本机本次**未能取到该日志**——`gh api repos/…/actions/jobs/99058387535/logs` 连续 20 余次返回 `EOF`（代理与直连、两种模式交替均失败），而同期 `actions/runs`、`check-runs`、`annotations` 端点间歇可用。该项**未覆盖**，不以推断冒充实测。

---

## 本地门禁（本机 Windows，①）

| 门禁 | 真实退出码 | 结果 |
|---|---|---|
| `git diff --check` | 0 | 通过 |
| `Scripts/selfcheck.ps1` | 0 | 通过（目录条目 181；源码引用 key 181；用户可见硬编码残留 0） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 通过（同上口径） |

CI 侧步骤 4、5 为同两个脚本，亦均 `success`——即结构自验与文案扫描在 runner 上同样通过，失败点确在步骤 6。

---

## 未执行项

**范围内第 4 项「更新 `<top>/CLAUDE.md` 第七节基线行」——未执行。**

卡内授权的写入内容为「新报告提交 SHA、merge 提交 SHA、**CI 编号、XCTest 525 项 0 失败**」。本次 CI 为红，既无 525 项、也无 0 失败、无 IPA 可登记。写入该行将把未发生的通过结论固化进项目基线文件，违反纪律第 5 条（不伪造通过）。

故基线行保持 IC-107 原状不动，**留待决策会话裁定**：是重跑 CI 后由后续卡补写，还是另行处置。

---

## 人工判定项（保留给 Lynn / 决策会话，不代为下结论）

1. **`main` 当前 tip 的 CI 为红**（代码树已由 #193 证绿）。是否重跑 #194、是否接受当前 `main` 状态，属决策范围；回退 / revert 属本卡范围外，未做。
2. **CI 预算已用尽**（卡内「预算：CI 1 次」）。重跑需新授权。
3. 若确认为 runner 模拟器可用性问题，`Scripts/test-xcode.sh` 的目标选择逻辑是否需要加固，属范围外，未改。

---

## 发现但未处理的问题（按纪律只报告不修）

1. **本机 gh 对 `actions/jobs/<id>/logs` 端点持续不可用**：约 20 余次尝试（代理 / 直连交替、间隔 8–12 s）全部 `EOF`；同期 `actions/runs`、`commits/<sha>/check-runs`、`check-runs/<id>/annotations` 端点在 1–7 次重试内可成功。CLAUDE.md 第五节与 memory 的代理配方未记载这一端点级差异，导致「红了却读不到日志」。
2. **git 代理需求与既有记载不符**：CLAUDE.md 第五节记「`git fetch`/`push` 走直连，设 `HTTPS_PROXY` 反而失败」。本次**环境变量形式两向皆失败**（直连与设代理均报 `schannel: failed to receive handshake`；注意 `ALL_PROXY` 也被 git 读取，需一并清除才算真直连），最终成功形式是**显式配置**：`git -c http.proxy=http://127.0.0.1:7890 -c https.proxy=… fetch/push`。`push` 亦需重试（第 3 次成功）。
3. **`ci.yml` 失败注解信息量不足**：步骤 6 失败时若日志无 `error:` / `Test Case … failed` 行，注解仅有「未找到具体错误行。」，不回显脚本 stderr（如「错误：没有可用的 iPhone 模拟器。」），使得在无法下载日志时无法定位根因。属 `ci.yml` 范围外，未改。
