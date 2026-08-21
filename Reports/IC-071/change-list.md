# IC-071 变更清单（merge-to-main）

## 分支与 ref 变更

| 对象 | 之前 | 之后 | 操作 |
|---|---|---|---|
| `main`（本地与 origin） | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | `143cd32ca3c17715d4a1d2f493685b9c2890ec39` | fast-forward 合并并推送 |
| `merge/ic-054-to-069` | （不存在） | `143cd32ca3c17715d4a1d2f493685b9c2890ec39` | 从 `2804837` 新建 + 五个 cherry-pick,已推送 |
| `origin/feature/ic-066-preclose-audit` | （不存在） | `e2972754585599b4507c43d9522545c4b5dba0d3` | 首次推送既有本地分支 |

另：本报告自身作为一个 docs 提交落在 `main` 上（Lynn 按 B 方案授权的追加提交），仅含 `Reports/IC-071/` 两个文件。

## 新增提交（五个 cherry-pick，均仅含 Reports/ 文档）

| 新 SHA | cherry-pick 自 | 提交信息 | 文件 |
|---|---|---|---|
| `cfcbed5208df8522b9467c0c3b440168f8de30a5` | `7b17ea0` | docs: 回填 IC-063 v2 CI 与诊断证据 [skip ci] | Reports/IC-063/diagnostics-sample.md、self-check.md（+456/−25） |
| `3ff829f4f0cd5e885ccbe2a1b9293e5fc20585bf` | `dff349f` | docs: 完成 IC-065 自验报告 | Reports/IC-065/change-list.md、self-check.md（+128） |
| `0767de7d26719ce2ec1132a795abb7d5f9a543ef` | `e297275` | docs: 完成 IC-066 收口前盘点与 CI 路径过滤 | Reports/IC-066/ 四文件（+652）；**ci.yml 零 diff**（原提交该部分已被链内 `b84b3b9` 覆盖） |
| `f756e87d4b4f15dea9b88f2d1e7f204cef4e3942` | `ab51ed1` | docs: 完成 IC-067 自验与变更清单 | Reports/IC-067/change-list.md、self-check.md（+204） |
| `143cd32ca3c17715d4a1d2f493685b9c2890ec39` | `0a44a3e` | docs: 补齐 IC-067 路径过滤实证 | Reports/IC-067/self-check.md（+8/−2） |

## 未变更（范围外确认)

- 产品代码、测试代码、`.github/workflows/ci.yml`、规格文件：`git diff 2804837 main` 排除 `Reports/` 后为 0 行
- `probe/ic-067-screenshot-subtype`：27 个独有提交,0 个进入 main
- 所有既有 feature 分支与 worktree：未删除、未移动
- 历史：未改写,无 force push,无 rebase,无新增 merge 提交

## CI

- `main` 推送触发 **CI #115**（id `32446357243`）：success,414 项 XCTest、0 失败,IPA 696344 字节,SHA-256 `99c2488350b1b006394bc115b63ebccafe54c4b94f9d0954da3b81d2e3b3b20b`
- `feature/ic-066-preclose-audit` 推送附带触发 CI #114（id `32446229659`,含 ci.yml 改动故未被 paths-ignore 过滤),与本卡门禁无关
- `merge/ic-054-to-069` 推送未触发 CI（五个新提交均为 Reports/md,被 paths-ignore 过滤,预期行为）
