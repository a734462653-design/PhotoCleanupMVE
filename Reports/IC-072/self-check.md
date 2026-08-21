# IC-072 自验报告（merge-ic070-to-main）

## 结论（先行）

R1、R2 完成。`main` 已从 `1643c4e245125f9b9d135e91205e2ffc5aa7fdcb` **fast-forward** 至 `9a2b083c2b9902b9000442a8163a003bf3692802`（= `origin/feature/ic-070-centering-handoff` tip），推送触发 CI #120 success：被测 SHA `9a2b083`，XCTest 420 项、0 失败，9 步全部 success（真实退出码 0），IPA 697297 字节。随后在 `main` 上追加一个 docs 提交，把 `Reports/IC-068/export-format.md` 的字段清单与 IC-070 之后的导出格式对齐，并携带本报告与变更清单。四处闸门均未触发，一次尝试完成。G82～G89 全部满足（G86/G88 在 docs 提交推送后复核，见下）。

## 输入、继承与范围

- 任务卡 IC-20260821-072；参照 `Reports/IC-071/self-check.md` 流程
- 继承提交三组 SHA 在 `git fetch origin --prune` 后逐条重验一致（①）：`main`=`origin/main`=`1643c4e2…fdcb`；`origin/feature/ic-070-centering-handoff`=`9a2b083c…2802`，其父=`9bffcd31…8246`；`main..9a2b083` 恰 6 个提交 `029e977 78dda0c 3273bb1 c45ac2f 9bffcd3 9a2b083`
- `git status --porcelain` 为空（①）
- 范围边界：未改产品代码、测试代码、`ci.yml`、`Scripts/`；未递增格式版本；未 cherry-pick / rebase / 普通 merge / force push / amend；未删改任何分支与 worktree；未改 `Reports/IC-070/**`、`Reports/IC-068/simulator-sample.txt`、SPEC、Decision_log、CLAUDE.md；probe 提交 0 个进入 main

## R1 执行记录（①）

1. `git merge --ff-only origin/feature/ic-070-centering-handoff`：`1643c4e..9a2b083` Fast-forward，4 files changed, 882 insertions(+), 1 deletion(-)；未产生 merge 提交。
2. `git push origin main`：`1643c4e..9a2b083`。
3. 触发 CI **#120**（id `32496602474`，event push，创建于 2026-08-21T15:15:19Z），conclusion success。

## R2 执行记录（①）

在 `Reports/IC-068/export-format.md`「文本结构」一节末尾（"## 模拟器样例边界"之前）追加小节 `### 自 IC-070 起的字段追加（格式版本仍为 1）`，含卡内三点事实；`git diff 9a2b083 -- Reports/IC-068/export-format.md` 仅新增行、0 删除行。与 `Reports/IC-072/self-check.md`、`change-list.md` 一起作为一个 docs 提交推送到 `main`（只含 `Reports/**`，被 `paths-ignore` 过滤，未触发 CI，预期）。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G82 | 满足① | 快进后 `git rev-parse main` = `9a2b083c2b9902b9000442a8163a003bf3692802`；`git log --merges 1643c4e..main` 为 0 条 |
| G83 | 满足① | `git diff 9bffcd3 main -- . ':(exclude)Reports/'` 为 0 行（快进后与 docs 提交后均成立——docs 提交只含 `Reports/**`） |
| G84 | 满足① | CI #120（id `32496602474`），被测 SHA `9a2b083c2b9902b9000442a8163a003bf3692802`，success；`Executed 420 tests, with 0 failures (0 unexpected) in 33.242 (43.736) seconds`，`** TEST SUCCEEDED **`；「运行 XCTest」及全部 9 步 success，真实退出码 0；IPA `PhotoCleanupMVE-unsigned.ipa` 697297 字节，SHA-256 `b6614dde571a1afa78d53275cf8665a2aef0948d8f6cc945afa4621986cc9003`（与 CI #119 的哈希不同，构建非可重现，字节数相同） |
| G85 | 满足① | `merge-base --is-ancestor 78dda0c main`、`--is-ancestor 9bffcd3 main` 均为真 |
| G86 | 满足① | `git rev-list --count main ^9a2b083` = 1；该提交 `--stat` 仅 `Reports/IC-068/export-format.md`、`Reports/IC-072/self-check.md`、`Reports/IC-072/change-list.md`（推送后复核，见 change-list 的 SHA） |
| G87 | 满足① | `grep -c adjustedContentInset` = 2、`grep -c fitBorderLayer` = 1、`grep -c "格式版本仍为 1"` = 1；diff 只增不删 |
| G88 | 满足① | `git ls-remote --heads origin`：`main` = 本地 `main`；`feature/ic-070-centering-handoff` = `9a2b083`；`probe/ic-067-screenshot-subtype` 27 个独有提交 0 个进入 `main` |
| G89 | 满足① | 最终 `main` 工作树：`Scripts/selfcheck.ps1` 退出码 0；`scan-hardcoded-user-visible-strings.ps1` 退出码 0；`git diff --check` 退出码 0 |

须人工判定：无。

## 发现但未处理

无新增。IC-070 报告中已列的"格式版本未递增"按本卡定案（④）保留。
