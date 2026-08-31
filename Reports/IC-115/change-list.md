# IC-115 变更清单（v2 终版）：放大自动隐藏续做——已转绿

## 结论

**绿。** 分支 tip = `d1fbad6`（CI **#223**，575 / 0，真实退出码 0）。**未合并 `main`**。
登记值/出厂值零改动，`schemaVersion` 仍为 **7**。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `ba3213b` | test | ✅（#223 下全绿） | v1：六条门禁按 ⑤a 新契约改写 + 修 D 两处（当时 #222 红，红因在判据非本提交） |
| 2 | `e3bbfc2` | docs | — | v1 停线报告（历史保留） |
| 3 | `d1fbad6` | test | ✅ #223 | v2 唯一改动：诊断 Nx 稳定判据按推迟应用时序分段 |
| 4 | 本次 docs 提交 | docs | — | `Reports/IC-115/` 完整替换为 v2 终版 |

## 文件变更（v2 增量）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | ① 新增诊断只读访问器 `diagnosticDeferredInterfaceVisibility`（暴露推迟记录的目标 V，产品不读）；② `waitForDiagnosticStableState` 稳定判据分段——`.nX` 窗口页面侧改为"即时一致或推迟记录携带目标态"，`.oneX` 判据一字未改；③ `stabilityDescription` 镜像分段逻辑并补印页面 V / 推迟目标 V |

v1 增量（`ba3213b`，见 v1 清单，git 历史 `e3bbfc2`）：转移表双击行、三条 IC047 用例、K2/E2/G3 改写、IC-114 D 用例修复、诊断进入稳定态期望 `(V=隐藏, Nx)`。

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| `applyDeferredPresentationIfPossible` 的 `zoomScale <= 1` 守卫 | **未动**（否决 1：动它＝改 IC-104 C / v17 决策 40） |
| 诊断判据机器侧条件 | **未弱化为半判据**（否决 2；页面侧仍必须给出推迟记录或即时一致其一） |
| ⑤a 契约 | **未修订**（否决 3） |
| `S2Calibration.swift`、`.github/`、`Scripts/` | 零 diff；`schemaVersion` 仍为 7 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| 132 条隐藏态手势断言、其他显隐断言、IC047-036 | 未改 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 7）。

## 报告提交

`Reports/IC-115/` 随本 docs 提交推送（同卡同分支追加，报告需引用推送后才产生的 CI #223 编号与 IPA 哈希）。
`Reports/**` 命中 `paths-ignore`，**本 docs 提交不触发 CI，属预期行为**；验证产品/测试代码的运行为 **#223**（被测提交 `d1fbad6`）。
