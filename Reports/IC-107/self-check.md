# IC-107 自验报告：IC-104 批量交付（A+B+C v4）合并入 main

## 结论（先行）

**合并完成，CI 绿，三道闸门全部通过。`main` 已推进到 IC-104 全量交付基线。**

- **merge 提交**①：`8f598f219065fc9b20b7d0d15be11c120fce1c6b`
- **`main` 新基线**①：`8f598f219065fc9b20b7d0d15be11c120fce1c6b`（本报告提交后见「报告提交」节）
- **CI**①：**#190 success**，9/9 步全绿，**真实退出码 0**，`Executed 520 tests, with 0 failures (0 unexpected) in 31.076 (54.472) seconds`
- **IPA**①：**837917 字节**，SHA-256 **`3557fca5a7e71dc3012ac380b8730bbc76d40f471cf358618dfa9ab109d27dca`**
- **闸门**：**G253、G254、G255 全部通过**
- **CI 预算**：1 次，**已用 1 次**
- 分支 `feature/ic-104-single-build-batch` **保留不删**

## 下发条件核对

卡首行：「Lynn 对 C v4 复测（第 ② 点底距 = 顶距为主，顺带 ⑤ 显隐过渡与 ⑥ 捏合双击跳变观感）真机判定通过后方可下发。复测未通过时本卡作废，不得执行。」

**执行前已就该条件向产品侧确认，答复为「已通过，执行合并」**，据此启动。（前一版 IC-107 卡曾因同一条件未满足而作废、未执行——见 `Reports/IC-104/self-check.md` 相应登记。）

## 输入与边界

| 项 | 值 |
|---|---|
| 开工 `git status --porcelain` | 空（纪律 8 检查通过） |
| 开工时 `main` | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（与卡内规定值相符 ✓） |
| 开工时分支 tip | `fa9593688faa26ecf590aea0b9d83fe55b933bc7`（与卡内规定值相符 ✓） |
| merge-base | `e6bd5aa890bff15b18c4569da4ae73c75f622578` = `main` tip ⟹ **`main` 是分支祖先，零冲突是结构必然** |
| 代码 tip | `7295ed674bfee98cd6ef745854cae31c99ade7a8`（由 CI **#189** 验证：520 项 0 失败、退出码 0、IPA 837917 字节） |

**合并前只读预演**①：`git merge-tree --write-tree --name-only main feature/ic-104-single-build-batch` → exit 0、**CONFLICT 0 行**、预演合并树 `87ecca71169fb612ee3ce565c1a958db7dbf0ffe` **等于**分支树，故 G253 的树同一性在动手前即已可预判成立。

**CI 覆盖性预判**①：`git diff 7295ed6 fa95936 -- PhotoCleanupMVE/ PhotoCleanupMVETests/` 为空，即 #189 被测树与分支 docs tip 的代码树完全相同，故合并树的测试结论由 #189 直接覆盖，#190 为同树复验。

## 合并

| 项 | 值 |
|---|---|
| 命令 | `git merge --no-ff feature/ic-104-single-build-batch`（**未 rebase、未 force**） |
| 提交信息 | `merge: IC-104 single-build batch (A+B+C v4) into main (IC-107)` |
| merge 提交 | `8f598f219065fc9b20b7d0d15be11c120fce1c6b` |
| 第一父 | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（`main`） |
| 第二父 | `fa9593688faa26ecf590aea0b9d83fe55b933bc7`（分支） |
| 冲突 | **无**（exit 0） |
| 合并统计 | 12 files changed, 2005 insertions(+), 255 deletions(-)，含新建 `Reports/IC-104/{self-check,change-list}.md` |
| 推送 | 17:03:54Z，`e6bd5aa..8f598f2  main -> main` |

## 逐条闸门结果

### G253：合并零冲突 + 树同一性 — **通过**①

- 合并 exit 0，无冲突
- `git diff 8f598f219065fc9b20b7d0d15be11c120fce1c6b fa95936` **输出为空** ⟹ 合并后 `main` 的树与分支 tip 的树完全相同

### G254：CI success + 520/0 + 退出码 0 + IPA 登记 — **通过**①

| 项 | 值 |
|---|---|
| run 编号 / id | **#190** / `33192930916` |
| 被测提交 | `8f598f219065fc9b20b7d0d15be11c120fce1c6b` |
| 起止 | 2026-08-28T17:03:55Z → 17:08:06Z |
| 结论 | **success**，9/9 步全绿（含步骤 7「构建未签名应用」、步骤 8「上传 IPA」） |
| XCTest | `Executed 520 tests, with 0 failures (0 unexpected) in 31.076 (54.472) seconds` |
| **真实退出码** | **0**（工作流 `set -o pipefail` 且以 `exit "$test_status"` 原样退出；9/9 步 success） |
| **IPA 字节数** | **837917** |
| **IPA SHA-256** | **`3557fca5a7e71dc3012ac380b8730bbc76d40f471cf358618dfa9ab109d27dca`** |
| artifact | `PhotoCleanupMVE-unsigned-8f598f219065`（id `9694637119`，zip 838087 字节） |

**IPA 哈希与 #189 不同属预期**：字节数与 #189 一致（同为 837917），但 SHA-256 不同（#189 为 `95009f48…b643`）。IPA 归档不可复现是本项目既有结论（IC-094 / IC-097 证据①），跨运行哈希不能作同一性判据；同一性由 G253 的**树同一性**把关，已通过。

### G255：冻结三链不动 + `schemaVersion == 6` 唯一 — **通过**①

| 项 | 值 |
|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f`（未变） |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`（未变） |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562`（未变） |
| 合并后 `main` 上 `schemaVersion` | `S2Calibration.swift:118` `static let schemaVersion = 6`，**全仓唯一定义** |

## CLAUDE.md 更新（卡内授权，按附录 A）

- **A1**：第七节「当前阶段」整节按附录原文替换，三个占位符以实际值填入——`<REPORT_SHA>` = 本报告提交 SHA、`<MERGE_SHA>` = `8f598f2…1c6b`、`<CI_RUN>` = `190`。第七节其余小节「未定项」原文不动。
- **A2**：第八节末尾追加第 10～14 条陷阱（附录列出五条）。

**登记一处卡内不一致**：「本卡显式授权」写「追加第八节**四条**陷阱」，而附录 A2 标题写「追加**五条**」并实际列出 10～14 共五条。以附录正文为准，追加五条。

## 本地门禁

本卡**无任何代码改动**（范围外明文禁止），合并为纯结构操作、`main` 代码树与已由 #189 验证的 `7295ed6` 完全相同，故未重复执行本地三项门禁；正确性由 G253 树同一性 + G254 的 CI 实跑共同把关。`git status --porcelain` 全程为空。

## 范围核对

| 项 | 结果 |
|---|---|
| 是否有任何代码改动 | **否**（仅合并 + 报告） |
| 是否 rebase / force push / 删分支 | **否**（`--no-ff` 普通合并；分支保留不删） |
| 是否修改 SPEC / Decision_log / `ci.yml` / `Scripts/` | **否** |
| 是否触碰冻结三链 | **否** |
| CLAUDE.md | 已按卡内授权更新（附录 A） |

## 发现但未处理的问题（只报告不修）

1. **卡内 G254 有一处笔误**：写「同树代码 **#187** 已绿」，按 C v4 应为 **#189**（`#187` 是 C v3 的 run）。不影响判定与执行，登记时一律按 #189。
2. **「本卡显式授权」与附录 A2 的条数不一致**：授权行写「四条陷阱」，附录 A2 写「五条」并列出 10～14。已按附录正文追加五条。
3. **本机 `actions/jobs/{id}/logs` 端点全会话不可用**（代理与直连均失败）。本卡不依赖 job 日志——run/steps/annotations/artifacts 四类 API 均可用，G254 所需事实全部取到。
4. **`git push` 需在带代理与直连之间轮换重试**：本次推送 `main` 时代理连续三次 `schannel: failed to receive handshake`，第 2 轮直连成功。
5. **随 IC-104 带入 `main` 的既有未处理项**（详见 `Reports/IC-104/self-check.md`）：`S2CalibrationHarnessTests.swift:9909` 过期注释；`Scripts/verify-IC-20260815-05x.ps1` 引用已重命名测试；`primaryResource` 无单元覆盖；`borderScanReading` 判定死区仅收窄未根除；两处已由 Lynn 复测通过的行为变更（显隐平移、捏合/双击跳变，≈10.35 pt）。
