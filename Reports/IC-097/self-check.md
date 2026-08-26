# IC-097 自验报告（merge-095）

## 结论（先行）

IC-095 链已按卡内要求一次 `--no-ff` 合并进 `main` 并推送。**零冲突**，没有手工解冲突、没有任何内容改写。

`main`：`3cc1e227d17b80f2fd44fa8478cda698652d275d` → `8e000fc48f305de929a34ef7d301483461a3b509`。

**CI 结果：CI #168 success。** 被测 `8e000fc48f305de929a34ef7d301483461a3b509`，XCTest **497 项、0 失败**，9 步全 success，被测命令真实退出码 **0**；IPA **793993 字节**、SHA-256 `dde04410843a7856878f7ce288930041ddf65c2f5ef184eeea6fe3a894696a41`，本地重下复核逐字节一致。**CI 只用了 1 次**（上限 2 次）。

三条预期核对值全部相符：XCTest **497 项 0 失败**（= 492 + 5）、`schemaVersion == 4`、三条冻结分支引用逐字符未动。四条门禁 G211～G214 全部满足。**冲突即停的闸门未触发。**

**人工判定项：无新增**（H41 已由 Lynn 于 2026-08-26 判定通过）。

## 开工前核对

| 项 | 值 | 与卡内一致 |
|---|---|---|
| `git status --porcelain` | 空 | ✅ |
| 检出 `main` | `3cc1e227d17b80f2fd44fa8478cda698652d275d` | ✅ |
| `git fetch origin --prune` | 退出码 **0** | — |
| `origin/main` | `3cc1e227d17b80f2fd44fa8478cda698652d275d` | ✅ 与本地相等 |
| `feature/ic-095-apply-idempotent-writes`（本地 = 远端） | `dae29026ddb7051566f52d62bcc832735445e939` | ✅ 卡内写 `dae2902`，此为完整 SHA |

三条冻结分支与探针分支在开工前的引用（本地与 `origin/` 逐一相等，无本地领先 / 落后）：

| 分支 | SHA |
|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` |
| `probe/ic-067-screenshot-subtype` | `9db02b93eccbb87d126602901807e70823535111` |

## 合并执行

| 命令 | 结果 |
|---|---|
| `git merge --no-ff feature/ic-095-apply-idempotent-writes -m "merge: IC-095 into main (IC-097)"` | 退出码 **0**，`Merge made by the 'ort' strategy`，6 文件 1092 增 40 删，**无冲突** |

合并前后 `git status --porcelain` 均为空——没有残留的冲突标记、没有未跟踪文件、没有需要人工处置的中间态。

### merge 提交

| 项 | 值 |
|---|---|
| merge 提交 | `8e000fc48f305de929a34ef7d301483461a3b509` |
| 第一父 | `3cc1e227d17b80f2fd44fa8478cda698652d275d`（合并前 `main`） |
| 第二父 | `dae29026ddb7051566f52d62bcc832735445e939`（`feature/ic-095-apply-idempotent-writes` tip） |
| 提交信息 | `merge: IC-095 into main (IC-097)` |

第二父就是卡内表格给的分支 tip，未被任何中间提交替换。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G211** merge 提交存在且唯一；`git log --first-parent --no-merges 3cc1e22..main`（报告提交前）为空 | 满足① | `git log --merges --format='%h %s' 3cc1e22..main` 输出**恰一行** `8e000fc merge: IC-095 into main (IC-097)`；`git log --first-parent --no-merges 3cc1e22..main` **无输出** |
| **G212** 合并后 `main` 树与 `dae2902` 树零 diff | 满足① | `git diff --stat dae29026ddb7051566f52d62bcc832735445e939 main` **无输出，退出码 0**。这同时证明合并没有引入任何自动或手工的内容改写 |
| **G213** CI success、真实退出码 0、XCTest 497/0、IPA 重下校验一致 | 满足① | 见「CI 与本地门禁」 |
| **G214** 本地三项门禁 0；冻结分支未动 | 满足① | `selfcheck.ps1` **0**、`scan-hardcoded-user-visible-strings.ps1` **0**（目录 171 / 引用 171、残留 0）、`git diff --check` **0**；冻结分支见下表 |

### 预期核对值

| 项 | 卡内预期 | 实测 | 相符 |
|---|---|---|---|
| XCTest | 497 项、0 失败（= 492 + 5） | **497 项、0 失败** | ✅ |
| `S2CalibrationConfiguration.schemaVersion` | 4 | **4**（合并后工作树 `S2Calibration.swift:118`） | ✅ |
| 三条冻结分支引用不变 | 是 | 见下表 | ✅ |

### 分支引用核对（合并推送后）

| 分支 | 合并前 | 合并后 | 状态 |
|---|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee84` | `b368a6caee84` | **冻结，未触碰** |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2` | `6736f1e3ebf2` | **冻结，未触碰** |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3` | `a7cc1ec727a3` | **冻结，未触碰** |
| `probe/ic-067-screenshot-subtype` | `9db02b93eccb` | `9db02b93eccb` | 未动、未删 |
| `feature/ic-095-apply-idempotent-writes` | `dae29026ddb7` | `dae29026ddb7` | 源分支保留、tip 未动 |

### CI 与本地门禁

| 项 | 值 |
|---|---|
| 工作流 | `iOS 构建与自验`，run **#168**（`id` 32992546502），event `push`，branch `main` |
| 被测提交 | `8e000fc48f305de929a34ef7d301483461a3b509`（完整 SHA，即 merge 提交本身） |
| 结论 | **success**，9 步全 success |
| XCTest | **Executed 497 tests, with 0 failures (0 unexpected)** in 26.052 (33.923) seconds |
| 计数算式 | 492（IC-094 基线）+ 5（IC-095 新增 F1/F1b/F2/F3/F4）− 0 = **497** ✅ |
| 被测命令真实退出码 | **0**。工作流 `set -o pipefail` + `exit "$test_status"`，日志管道不吞退出码；步骤 6「运行 XCTest」conclusion = success |
| IPA 字节数 | **793993** |
| IPA SHA-256 | `dde04410843a7856878f7ce288930041ddf65c2f5ef184eeea6fe3a894696a41` |
| 本地重下复核 | `gh run download` 取 `PhotoCleanupMVE-unsigned-8e000fc48f30`（Artifact ID 9615642942），本地 `stat` = **793993** 字节、`sha256sum` = `dde04410…6a41`，**与 CI 报告值逐字符一致** ✅ |
| `Scripts/selfcheck.ps1` | 退出码 **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 退出码 **0** |
| `git diff --check` | 退出码 **0** |
| CI 使用次数 | **1 / 2** |

## 带入 `main` 的内容

`git log --no-merges 3cc1e22..main` 共 **7** 个提交，即 IC-095 分支的全部提交（6 个代码/文档提交 + 1 个报告 docs 提交）：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `f173d52d0b15d51e1924bd5e094c1773b7985bf3` | `feat(diag): updateUIView 事件追加 wroteAnyGeometry 字段与两类几何写入埋点（IC-095 R1）` |
| 2 | `e43d00d2b2d35b7f60fe752bd55a131b409053f4` | `fix(s2): apply 外层写回与 layoutNativePages 重排条件化（IC-095 R2）` |
| 3 | `7496ad983003e1f90a52d4f2fc31948340c85ace` | `fix(s2): applyPage 下游写入条件化——applyNativeState 幂等、页输入未变不重建（IC-095 R3）` |
| 4 | `013ceeb9b8f5615d8e3d622be98fcf376b2c4225` | `fix(s2): reportNativeViewport 等值不发布（IC-095 R4）` |
| 5 | `685666c5808e2aeb256d6d0f797879c697ea7776` | `feat(diag): 联合居中写入补埋点并计入几何写入总数（IC-095 R1 补）` |
| 6 | `47858f47805460e4155a721843bf5bb6a545bfba` | `test(s2): IC-095 G207 F1~F4 写入条件化断言（夹具驱动）` |
| 7 | `dae29026ddb7051566f52d62bcc832735445e939` | `docs: 完成 IC-095（apply 重进根因修复：写入条件化与幂等）自验与变更清单` |

累计内容变化（`git diff 3cc1e22 main`）：6 文件、1092 增 40 删。逐文件见 `change-list.md`。

## 根因假设的确认与推翻

**本卡无根因假设。** 纯合并卡，不含任何代码改动；IC-095 的根因确认与修正已写在 `Reports/IC-095/self-check.md`「根因假设的确认与推翻」一节，本卡不重复也不覆盖。

## 人工判定项

**无新增项。** 卡内明列「H41 已判」——H41 三段定量取证与全功能抽查 8 项由 Lynn 于 2026-08-26 判定通过（上游证据：`#167 E1/E3/C2.txt`，Nx 平移外层写入 181→0、静止写入 2→0、捏合零几何写入）。

本卡合并后的树与 `dae2902` **零 diff**（G212），即真机判定所针对的产品代码逐字节转移到 `main`，H41 结论直接适用，**不产生新的人工判定项**。

## 发现但未处理的问题（按纪律只报告不修）

1. **CI 运行创建有明显延迟**。推送 `main` 后约 4～5 分钟内，`gh api .../actions/runs?head_sha=8e000fc…` 一直返回 `total_count = 0`，随后才出现 run #168。若按「推完立刻查一次，查不到就判定未触发」的做法操作，会误判成 `paths-ignore` 把合并提交滤掉了。**建议后续合并卡把「等待运行出现」的轮询下限定为 5 分钟以上**，不要以单次查询为准。本卡未改任何流程文件。
2. **`git fetch` / `git push` 在设置了 `HTTPS_PROXY=http://127.0.0.1:7890` 时全部失败**（`schannel: failed to receive handshake, SSL/TLS connection failed`，连续 3 次），去掉该环境变量后第一次即成功。gh CLI 则相反——必须带 `HTTPS_PROXY` 才能访问 api.github.com。即**git 与 gh 的代理需求相反**：git 走系统层直连/TUN，gh 走显式代理。CLAUDE.md 第五节只写了 gh 的代理要求，没写 git 不能带这个变量。属本机环境说明，不在本卡范围内，未改 CLAUDE.md。
3. **IPA 的 SHA-256 与 CI #167 不同，字节数相同**。#167（被测 `47858f4`）为 793993 字节 / `e2b39571…0d04`，本卡 #168（被测 `8e000fc`）为 793993 字节 / `dde04410…6a41`。两者源码树**完全相同**（G212 零 diff），字节数一致即旁证；SHA 不同是 IPA 归档非确定性构建（时间戳、条目顺序）的正常结果，**不是内容差异**。若日后要用 IPA 哈希做跨运行的同一性判据，需要先让归档可复现——属工程决策，本卡不做。
4. **`Reports/IC-095/` 的两份报告随合并进入 `main`**（116 + 241 行）。这是 IC-095 报告提交 `dae2902` 被一并合并的结果，符合卡内「一次 `--no-ff` 合并」的要求，此处仅作登记。

## 完成后动作

**完成即停。** `main` 新基线 `8e000fc48f305de929a34ef7d301483461a3b509` 由技术负责人记入 Decision_log 第 128 条。本卡不再做任何操作。
