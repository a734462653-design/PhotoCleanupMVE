# IC-071 自验报告（merge-to-main）

## 结论（先行）

合并完成。`main` 已从 `bccc2d2` 快进至 `143cd32ca3c17715d4a1d2f493685b9c2890ec39`（= `merge/ic-054-to-069` tip），包含 IC-054 至 IC-069 全部代码提交与五个链外 docs 提交的 cherry-pick 副本。推送触发 CI #115，结论 success：XCTest 414 项、0 失败，全部步骤 success（真实退出码 0），IPA 696344 字节。八条验收门禁中六条满足；**G70 存在既有缺口**（`Reports/IC-063/change-list.md` 在仓库全部历史中从未存在，非本次引入，未代写）；**G71 字面不成立但意图满足**（本次合并为纯 fast-forward、未新增 merge 提交，但继承链内部原有一个 merge 提交 `e768f1b`，任何包含 `2804837` 的合并方案都无法避开它）。两项细节见下文，判定权留给技术负责人。

## 输入与范围

- 任务卡：IC-20260819-071-merge-to-main（短执行卡，三次尝试上限，实际一次完成）
- 继承提交：`main` = `bccc2d2deadf37da470b9270f25ecb0312e6d4de`；链 tip = `280483788b13dbfb7678c5e430b8b706bbb9baa0`（feature/ic-069-transition-rootcause）
- 目标分支：`merge/ic-054-to-069`（新建）、`main`
- 范围边界：未触碰产品代码、测试代码、`ci.yml`、规格文件；未引入 probe 分支提交；未删除任何分支或 worktree；未解决任何冲突（未发生冲突）；未开始 IC-070

## 执行记录（五步）

1. **对齐远端**：`git fetch origin --prune` 成功，唯一变化为过期的 `origin/feature/ic-067-screenshot-detection` 从 `b84b3b9` 对齐到 `0a44a3e`。第一节全部事实逐条重验成立（main 与 origin/main 同为 `bccc2d2`；ic-069 本地与 origin 同为 `2804837`；五个 docs 提交 SHA、所属分支、在/不在 origin 均与卡一致；`e297275` 的 ci.yml blob 与 `b84b3b9`、`2804837` 同为 `9e2176d`，逐字节相同）。①
2. **推送 ic-066**：`origin/feature/ic-066-preclose-audit` 创建成功，tip = `e2972754585599b4507c43d9522545c4b5dba0d3`。①
3. **cherry-pick**：五个提交按卡内顺序全部干净落下，零冲突。`e297275` 行为与预期完全一致：仅落下 `Reports/IC-066/` 四个文件（652 行新增），ci.yml 零 diff。①
4. **快进合并**：`git merge --ff-only` 输出 `Updating bccc2d2..143cd32 Fast-forward`，未产生 merge 提交。①
5. **推送 main**：`bccc2d2..143cd32` 推送成功，触发 CI #115。`merge/ic-054-to-069` 分支也已推送（其五个新提交均为 Reports/md，被 `paths-ignore` 过滤未触发 CI，符合预期）。①

## cherry-pick 对照表

| 原提交 | 新提交（在 main 上） | 内容 |
|---|---|---|
| `7b17ea0b5b6f2989e02853f8d5fc7f93c11e8b9b` | `cfcbed5208df8522b9467c0c3b440168f8de30a5` | Reports/IC-063/ 两文件 |
| `dff349f1a3dc1c9c69980c167b611f1dd881dee2` | `3ff829f4f0cd5e885ccbe2a1b9293e5fc20585bf` | Reports/IC-065/ 两文件 |
| `e2972754585599b4507c43d9522545c4b5dba0d3` | `0767de7d26719ce2ec1132a795abb7d5f9a543ef` | Reports/IC-066/ 四文件（ci.yml 零 diff） |
| `ab51ed1f309b9b87c610717823f6ee15b81d913a` | `f756e87d4b4f15dea9b88f2d1e7f204cef4e3942` | Reports/IC-067/ 两文件 |
| `0a44a3ebcf97a2039bac82fe528178fccf53ceb6` | `143cd32ca3c17715d4a1d2f493685b9c2890ec39` | Reports/IC-067/self-check.md |

## 逐条验收门禁

- **G68 满足①**：`merge-base --is-ancestor` 验证 `2804837` 及五个 cherry-pick 新 SHA 均为 `main` 祖先。注：五个**原始** SHA 因 cherry-pick 复制而非合并，按构造不是 main 祖先；内容等价性已逐目录验证——`git diff <原提交> main -- Reports/IC-0XX/` 四组全部为 0 行差异。
- **G69 满足①**：`git diff 2804837 main -- . ':(exclude)Reports/'` 为 0 行。main 与 `2804837` 的全部差异是 `Reports/` 下 10 个 Markdown 文件（IC-063 两文件修改，IC-065/066/067 八文件新增）。
- **G70 除既有缺口外满足①**：IC-063 至 IC-067 的 10 个报告文件中 9 个在位；`Reports/IC-063/change-list.md` 缺失——已搜索全部本地与远端 ref 及 `git log --all` 全历史，该文件**从未存在**，属 IC-063 交付时的既有缺口,非本次合并引入。按"发现问题写进报告、不代写"的纪律未补作，是否补交由技术负责人决定。
- **G71 意图满足、字面不成立①**：本次合并为纯 fast-forward，未新增任何 merge 提交。但 `bccc2d2..main` 范围内存在一个**继承链原有**的 merge 提交 `e768f1b`（"test: 合并 IC-064 改造前曲线证据"，2026-08-17，父提交 `abb7302`+`2dda2ff`，是 `2804837` 的祖先）。任务卡目标要求 main 包含 `2804837`，因此"main 历史中无 merge 提交"在任何不改写历史的方案下都不可能字面成立。这同时修正此前"代码提交构成线性链"的描述：链内含一个 merge 提交。
- **G72 满足①**：`probe/ic-067-screenshot-subtype` 相对 main 有 27 个独有提交（修正：前轮报告误计为 25 个），逐一比对,0 个进入 main。
- **G73 满足①**：见下节 CI 证据。CI 由 push 正常触发,无需 workflow_dispatch。
- **G74 满足①**：`git ls-remote` 确认 `origin/feature/ic-066-preclose-audit` = `e2972754585599b4507c43d9522545c4b5dba0d3`。

## CI 证据（①）

- 运行编号：**#115**（id `32446357243`），事件 push，创建于 2026-08-21T04:16:31Z
- 被测提交：`143cd32ca3c17715d4a1d2f493685b9c2890ec39`（= 合并后 main tip）
- XCTest：`Executed 414 tests, with 0 failures (0 unexpected) in 13.838 (28.230) seconds`，`** TEST SUCCEEDED **`
- 真实退出码：0——工作流以 `set -o pipefail` + `exit "$test_status"` 原样退出,"运行 XCTest"步骤及全部 9 个步骤 conclusion 均为 success
- IPA：`PhotoCleanupMVE-unsigned.ipa`，696344 字节，SHA-256 `99c2488350b1b006394bc115b63ebccafe54c4b94f9d0954da3b81d2e3b3b20b`
- 附带说明：推送 `feature/ic-066-preclose-audit` 触发了 CI #114（id `32446229659`，因 `e297275` 含 ci.yml 改动,不在 paths-ignore 范围）。该 run 与本卡门禁无关（G74 只要求分支上远端），撰写本报告时仍 in_progress，结果不影响本卡结论。

## 本地门禁（①，均在合并后的 main 工作树执行）

- `Scripts/selfcheck.ps1`：通过，退出码 0（含"不少于 189 项测试的数量门禁"）
- `Scripts/scan-hardcoded-user-visible-strings.ps1`：通过，退出码 0（用户可见硬编码残留 0）
- `git diff --check`:通过,退出码 0

## 人工判定项

本卡无真机人工观感项。留给技术负责人判定的两项均为流程判定：G70 既有缺口的处理方式、G71 字面表述与继承历史的取舍。
