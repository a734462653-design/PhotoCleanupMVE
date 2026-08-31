# IC-117 变更清单：原生 Liquid Glass 实装

## 结论

**绿。** 被测提交 = `d679bc8`（CI **#225**，575 / 0，真实退出码 0，Xcode 26.3 构建）。
**未合并 `main`，执行完即停。** 登记值/出厂值零改动，`schemaVersion` 仍为 **7**。CI 预算用 1/2。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `d679bc8` | feat | ✅ #225 | iOS 26 原生 Liquid Glass + 17–25 回落（唯一代码改动） |
| 2 | 本次 docs 提交 | docs | — | `Reports/IC-117/`（含三卡总执行结果包） |

## 文件变更

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | ① `s2ChromeGlassBackground(in:interactive:)` 双分支：iOS 26+ `glassEffect`（按形状，`interactive` 加交互变体），17–25 回落 `s2LegacyChromeGlassBackground`（原配方零改动搬移）；② `s2ChromeCircleGlass` 传 `interactive: true`（四枚圆钮）；③ 顶排/底排拆出 `topBarRow` / `actionBarRow`，iOS 26 各包 `GlassEffectContainer`；④ 新增 `S2ChromeForeground`：iOS 26 副行 `.secondary`、中央指示文字/图标 `.primary`（vibrancy，不自设透明度），回落保留画布定值；⑤ A3 过渡、`S2ChromeGlass`/`S2ChromePillMetrics` 常量零 diff |

覆盖件：顶部三件（返回圆钮、信息胶囊、垃圾桶圆钮）、底部三件（心形圆钮、最近相簿胶囊、加相簿圆钮）、
中央指示容器（Capsule）；另教程提示卡（RoundedRectangle 20）因 IC-113 A"全族一套值"④ 随族同变（登记项）。

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| A3 显隐过渡（`s2ChromeVisibilityTransition` 族） | 零 diff |
| `S2ChromeGlass` 回落配方常量、`subtitleOpacity` | 零 diff（测试契约原样绿） |
| 像素探针及其阈值 | 未调（探针走 iOS 18.5 回落路径，逐值未变） |
| `S2Calibration.swift`、`.github/`（本卡）、`Scripts/` | 零 diff；`schemaVersion` 仍为 7 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 7）。iOS 26 分支未引入任何新数值常量
（形状、尺寸、时长全部沿用既有定义；玻璃质感参数由系统持有，不进标定）。

## 报告提交

`Reports/IC-117/` 随本 docs 提交推送（同卡同分支追加，需引用推送后才产生的 #225 编号与 IPA 哈希）。
命中 `paths-ignore` 不触发 CI，属预期；验证产品代码的运行为 **#225**（被测提交 `d679bc8`）。
三卡总执行结果包见 `Reports/IC-117/self-check.md` 末节。
