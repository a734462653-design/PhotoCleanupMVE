# IC-121 变更清单：chrome 蓝色泄漏修复 + 角标通知徽标样式

## 结论

**两子项全绿。** 最终绿 tip（代码）= `a51a6ca`（CI **#231**，586 / 0，真实退出码 0）。
**未合并 `main`，执行完即停。** 登记值/出厂值零改动，`schemaVersion` 仍为 **7**。CI 用 1/2。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `e8ce2ef` | fix | ✅ #231 | A：chrome 前景改具体动态色 `Color.primary/.secondary`，堵住按钮 tint 层级解析泄漏 + 防回退断言 |
| 2 | `a51a6ca` | feat | ✅ #231 | B：角标改通知徽标样式（红底白字 + 1.5pt 协调描边）+ 样式断言 |
| 3 | 本次 docs 提交 | docs | — | `Reports/IC-121/` |

## 文件变更

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A：`S2ChromeForeground` 由 `AnyShapeStyle(.primary/.secondary)`（层级样式）改为具体动态色 `Color.primary/.secondary`（含真因注释）；「新建相簿…」行裸 `.primary` 收编。B：新增 `S2ConfirmationBadgeStyle`（fontSize 12 / minDiameter 18 / hPadding 5 / ringWidth 1.5 / 红底白字 / 描边系统底色）；`confirmationBadge` 改红底白字胶囊 + 描边，锚点/滚动/不吃点击不变 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A：`testIC121AChromeForegroundIsConcreteAdaptiveColor`；B：`testIC121BBadgeMatchesNotificationStyle` |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| 玻璃材质配方与布局几何 | 零改动（范围外遵守；角标锚点沿用 IC-120 既有值） |
| 自适应配色规则（IC-120 ④）语义 | 不变（只换载体：层级样式 → 具体动态色） |
| 教程步 6 高亮态、缩略栏待删标记 | 仍保留定值（IC-120 登记项，留决策会话） |
| `S2Calibration.swift`、`.github/`、`Scripts/` | 零 diff；`schemaVersion` 仍为 7 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 7）。新增取定（登记）：
角标描边色 = 系统底色（深浅自适应）；徽标尺寸/字号/描边宽为视图字面常量
（非标定参数），已由测试钉住。

## 报告提交

`Reports/IC-121/` 随本 docs 提交推送（同卡同分支追加，需引用推送后才产生的 #231 编号
与 IPA 哈希）。命中 `paths-ignore` 不触发 CI，属预期；验证产品代码的运行为 **#231**
（H55 包，被测提交 `a51a6ca`）。
