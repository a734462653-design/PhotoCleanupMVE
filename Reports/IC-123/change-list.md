# IC-123 变更清单：S2 两处缺陷修复（指示器切换模式滞后、横屏截图双击比例畸变）

## 结论

**两子项全绿。** 最终绿 tip（代码）= `15ddb1f`（CI **#235**，591 / 0，真实退出码 0）；
子项 A 单独绿于 CI **#233**（`01219d1`，588 / 0）；B 的第 1 次 CI **#234** 红（测试代码编译错误，退出码 65），
修正提交后绿。**未合并 `main`，执行完即停。** 登记值/出厂值零改动，`schemaVersion` 仍为 **7**。CI 用 3/4。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `01219d1` | fix | ✅ #233 | A：中央指示玻璃内前景按 colorScheme 显式解析为定值色（`resolvedForeground(for:)` + `@Environment(\.colorScheme)`），外观切换与撤回钮同拍；撤回钮不改 + 2 条测试。可单独 cherry-pick |
| 2 | `9b04eb6` | fix | ❌ #234（测试编译错误 65） | B：`nativeZoomBaseSize` 截图分支删除，恒为全视口 aspectFit（决策 20）；一处过时注释随改 + 3 条测试 |
| 3 | `15ddb1f` | test | ✅ #235 | B：新用例比例数组显式标注 `[CGFloat]`（修 #234 的 `[Any]` 推断）。B 须以 2+3 为一组挑取 |
| 4 | 本次 docs 提交 | docs | — | `Reports/IC-123/` |

## 文件变更

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A：`S2CenterIndicatorView` 新增 `@Environment(\.colorScheme)`、`static func resolvedForeground(for: ColorScheme) -> Color`（`UIColor.label.resolvedColor(with:)` 定值色）与私有 `glassContentForeground`；`glassCircle` 图标、「已加入「名」」文字、「已从「名」移除」文字三处 `.foregroundStyle` 由 `S2ChromeForeground.onGlassPrimary` 改为该定值色；撤回钮 `Button` 不动（仍 `onGlassPrimary`）。含归因注释（③标注） |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | B：`S2ViewportLayout.metrics` 的 `nativeZoomBaseSize: isScreenshot ? physicalSize : fitSize` → `nativeZoomBaseSize: fitSize`，含成因注释（a056126 沿用旧分支） |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | B：仅 `oneXPhotoCenterYInZoomContent` 文档注释更新（「截图的基准即视口」→ 同为全视口 aspectFit、公式通用）；无代码改动 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A：`testIC123AIndicatorForegroundIsResolvedPerColorScheme`、`testIC123AIndicatorGlassContentFollowsInPlaceAppearanceSwitch`（@2x 截屏数近黑像素）+ 私有 helper `ic123NearBlackPixelCount` |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | B：`testIC123BNonScreenAspectScreenshotZoomBaseIsFullViewportAspectFit`、`testIC123BScreenAspectScreenshotAndOrdinaryPhotoZoomBaseUnchanged`（等价断言）、`testIC123BLandscapeScreenshotDoubleTapKeepsAspectRatioThroughout`（进入 / 21 点采样 / 落地 / 退出）；`15ddb1f` 把首个用例的 `ratios` 显式标注 `[CGFloat]` |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `f71faaed34a146b536a284c9066406234554cf77` |
| 规格 v17 决策 20 语义 | 零改动（实现修回规格：基准 = aspectFit 于全视口） |
| 玻璃材质配方、布局几何、等距带公式、双击过渡曲线/时长 | 零改动（范围外遵守） |
| `S2ChromeForeground` 取值（IC-121 A） | 不变；撤回钮与顶/底排 chrome 仍走 `Color.primary/.secondary` |
| `S2CalibrationConfiguration` 字段与出厂值 | 零 diff；`schemaVersion` 仍为 7 |
| `.github/`、`Scripts/` | 零 diff |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| IC-122 | 未触碰（另卡） |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 / stash 操作 | 未执行（#234 修正以新 commit 追加；仓内两条 IC-067 旧 stash 原样保留） |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 7）。本卡无新增取定项：A 的定值色与 `Color.primary`
同源（`UIColor.label` 两态），非新配色；B 为回归规格既有定义。

## 报告提交

`Reports/IC-123/` 随本 docs 提交推送（同卡同分支追加，需引用推送后才产生的 #233 / #234 / #235 编号
与 IPA 哈希）。命中 `paths-ignore` 不触发 CI，属预期；验证产品代码的运行为 **#235**（最终 tip `15ddb1f`）
与 **#233**（子项 A 单独）。
