# IC-072 变更清单

## 分支与 ref

| 对象 | 之前 | 之后 | 操作 |
|---|---|---|---|
| `main` / `origin/main` | `1643c4e245125f9b9d135e91205e2ffc5aa7fdcb` | `9a2b083c2b9902b9000442a8163a003bf3692802`（快进）→ 之后再 +1 个 docs 提交（SHA 见回传消息；本文件在该提交内，无法自引） | `git merge --ff-only` + `git push origin main` 两次 |
| `feature/ic-070-centering-handoff` | `9a2b083` | `9a2b083`（未动） | — |
| 其他分支、worktree | — | 未动 | — |

## 随快进进入 `main` 的提交（来自 IC-070，未改写）

`029e977`（R7 diag）、`78dda0c`（实测探针，按 ④ 保留）、`3273bb1`（R5）、`c45ac2f`（R6）、`9bffcd3`（R5 补充，最终被测）、`9a2b083`（IC-070 报告）。`git diff 9bffcd3 main` 排除 `Reports/` 后为 0 行。

## 本卡新增的 docs 提交（仅三个文件）

| 文件 | 变更 |
|---|---|
| `Reports/IC-068/export-format.md` | 「文本结构」末尾追加 `### 自 IC-070 起的字段追加（格式版本仍为 1）`：两个 inset 字段与头部声明行；`fitBorderLayer.*` 新 key 及两个来源；格式版本未递增。只增不删，原文其余一字未改 |
| `Reports/IC-072/self-check.md` | 新增 |
| `Reports/IC-072/change-list.md` | 新增 |

## CI

- 快进推送触发 CI #120（id `32496602474`）：success，被测 `9a2b083c2b9902b9000442a8163a003bf3692802`，420 项 0 失败，IPA 697297 字节，SHA-256 `b6614dde571a1afa78d53275cf8665a2aef0948d8f6cc945afa4621986cc9003`
- docs 提交推送：`Reports/**` 被 `paths-ignore` 过滤，不触发 CI（预期）

## 未变更

产品代码、测试代码、`ci.yml`、`Scripts/`、`Reports/IC-070/**`、`Reports/IC-068/simulator-sample.txt`、SPEC、Decision_log、CLAUDE.md、导出「格式版本」。
