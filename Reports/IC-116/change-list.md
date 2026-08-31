# IC-116 变更清单：CI 工具链切换 Xcode 26

## 结论

**绿。** 分支 tip = `d81c6a6`（CI **#224**，575 / 0，真实退出码 0）。**未合并 `main`**。
零产品改动；登记值/出厂值零改动，`schemaVersion` 仍为 **7**。CI 预算用 1/2。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `d81c6a6` | ci | ✅ #224 | `ci.yml` 新增「选择 Xcode 26 工具链」一步（+17 行，唯一改动） |
| 2 | 本次 docs 提交 | docs | — | `Reports/IC-116/` |

## 文件变更

| 文件 | 变更 |
|---|---|
| `.github/workflows/ci.yml` | 检出后新增一步：`ls /Applications` 实证打印 → 按 `^Xcode_26(\.[0-9]+)*\.app$` 过滤 `sort -V` 取最高稳定版 → `DEVELOPER_DIR` 写入 `$GITHUB_ENV` 作用全 job → 无 26.x 稳定版则显式失败。其余步骤零 diff |

实际选中（#224 ①）：`/Applications/Xcode_26.3.0.app`，Xcode 26.3（Build 17C529），
SDK iPhoneSimulator26.2 / iPhoneOS26.2，XCTest 模拟器 iPhone 16（iOS 18.5）。

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| 产品源码、测试、`Scripts/` | 零 diff |
| `schemaVersion` | 仍为 7；登记值/出厂值零改动 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 7）。

## 报告提交

`Reports/IC-116/` 随本 docs 提交推送（同卡同分支追加，报告需引用推送后才产生的 CI #224 编号与 IPA 哈希）。
命中 `paths-ignore` 不触发 CI，属预期；验证 `ci.yml` 变更的运行为 **#224**（被测提交 `d81c6a6`）。
