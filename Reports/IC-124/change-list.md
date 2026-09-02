# IC-124 变更清单：IC-123 合并入 main

## 结论

**合并完成。** `main` = merge 提交 `0287e9cd8347f8ebdcb7447358de6326eeb53d7c` + 本 docs 提交；
CI **#237**（attempt 1）success，593 / 0，真实退出码 0，Xcode 26.3。
零冲突、零代码改动。预算实用 CI 1 / rerun 0。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `0287e9c` | merge | ✅ #237 | `--no-ff` 合并 `feature/ic-123-s2-fixes`（tip `cd89b59`）入 `main`；树 == 分支树（`git diff 0287e9c cd89b59` 为空） |
| 2 | 本次 docs 提交 | docs | — | `Reports/IC-124/` |

## 文件变更

本卡自身零代码改动。merge 带入 IC-123 全部提交（已在 `Reports/IC-123/` 各卡登记，此处不重复）；
要点：`S2CenterIndicatorView` 新增 `resolvedForeground(for:)` / `resolvedSeparator(for:)` /
`separator(color:)`（指示器前景与分隔线按 colorScheme 显式重解析、同拍随 `body` 落笔）、
`S2ViewportLayout.metrics` 的 `nativeZoomBaseSize` 截图与非截图统一为 `fitSize`
（截图缩放基准改回 aspectFit 适配尺寸，修回规格 v17 决策 20）、新增测试 7 条
（586 → 593）、`Reports/IC-123/` 两组报告。

## 顶层文件变更（非仓库）

| 文件 | 变更 |
|---|---|
| `<top>/CLAUDE.md` | 第七节「当前阶段」首行替换：`main` = merge 提交 `0287e9c`、CI #237、593 项、Xcode 26.3；合并内容登记追加 IC-123（指示器外观切换同拍重解析、截图缩放基准改 aspectFit 适配尺寸）；`schemaVersion` 行不变（仍 7） |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰（G319） |
| `feature/ic-123-s2-fixes` | 保留未删，tip 仍 `cd89b59` |
| 其余 `feature/ic-0xx-*` 分支 | 保留不删 |
| SPEC、Decision_log、`Scripts/`、`ci.yml` | 未修改 |
| rebase / force push / 删分支 / amend | 未执行 |

## 占位值登记

无出厂值/登记值变更；`schemaVersion` 合并后在 `main` 上唯一定义、值 7（G319 grep 实证，
IC-123 未涉及出厂值集合变更，版本号沿用不动）。

## 报告提交

`Reports/IC-124/` 随本 docs 提交追加推送（同卡同分支 `main`，报告需引用推送后才产生的
#237 编号、merge SHA 与 IPA 哈希，采用 CLAUDE.md 第二节第 7 条的追加 docs 提交方式）。
命中 `paths-ignore` 不触发 CI，属预期；验证产品代码的运行为 **#237**（被测提交 `0287e9c`）。
