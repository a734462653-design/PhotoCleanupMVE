# IC-123 变更清单：S2 两处缺陷修复（指示器切换模式滞后、横屏截图双击比例畸变）＋附录分隔线

> 本件为 v2 附录完成后的**完整替换版**。

## 结论

**两子项与附录全绿。** 最终绿 tip（代码）= `1f3a992`（CI **#236**，593 / 0，真实退出码 0）；
子项 A 单独绿于 CI **#233**（`01219d1`，588 / 0）；B 终绿于 **#235**（`15ddb1f`，591 / 0），其第 1 次 CI **#234**
红（测试代码编译错误，退出码 65）。**未合并 `main`，执行完即停。** 登记值/出厂值零改动，
`schemaVersion` 仍为 **7**。CI 用 4/4。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `01219d1` | fix | ✅ #233 | A：中央指示玻璃内前景按 colorScheme 显式解析为定值色（`resolvedForeground(for:)` + `@Environment(\.colorScheme)`），外观切换与撤回钮同拍；撤回钮不改 + 2 条测试。可单独 cherry-pick |
| 2 | `9b04eb6` | fix | ❌ #234（测试编译错误 65） | B：`nativeZoomBaseSize` 截图分支删除，恒为全视口 aspectFit（决策 20）；一处过时注释随改 + 3 条测试 |
| 3 | `15ddb1f` | test | ✅ #235 | B：新用例比例数组显式标注 `[CGFloat]`（修 #234 的 `[Any]` 推断）。B 须以 2+3 为一组挑取 |
| 4 | `883b89a` | docs | — | `Reports/IC-123/`（A / B 那一版） |
| 5 | `1f3a992` | fix | ✅ #236 | **附录**：指示 S3 态分隔线按 colorScheme 显式解析为定值分隔色（`resolvedSeparator(for:)` + `separator(color:)`），与 A 同拍；几何零改动 + 2 条测试。可单独 cherry-pick（建立在 A 的 `@Environment(\.colorScheme)` 之上，需跟在 `01219d1` 之后） |
| 6 | 本次 docs 提交 | docs | — | `Reports/IC-123/` 完整替换版（含附录） |

## 文件变更

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 附录：`S2CenterIndicatorView` 新增 `static func resolvedSeparator(for: ColorScheme) -> Color`（`UIColor.separator.resolvedColor(with:)` 定值色）、私有 `glassContentSeparator`、`static func separator(color:) -> some View`（`Divider().frame(height: 22).hidden().overlay(color)`）；已加入相簿态一处 `Divider()` 改调 `Self.separator(color:)`。其余 —— A：`S2CenterIndicatorView` 新增 `@Environment(\.colorScheme)`、`static func resolvedForeground(for: ColorScheme) -> Color`（`UIColor.label.resolvedColor(with:)` 定值色）与私有 `glassContentForeground`；`glassCircle` 图标、「已加入「名」」文字、「已从「名」移除」文字三处 `.foregroundStyle` 由 `S2ChromeForeground.onGlassPrimary` 改为该定值色；撤回钮 `Button` 不动（仍 `onGlassPrimary`）。含归因注释（③标注） |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | B：`S2ViewportLayout.metrics` 的 `nativeZoomBaseSize: isScreenshot ? physicalSize : fitSize` → `nativeZoomBaseSize: fitSize`，含成因注释（a056126 沿用旧分支） |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | B：仅 `oneXPhotoCenterYInZoomContent` 文档注释更新（「截图的基准即视口」→ 同为全视口 aspectFit、公式通用）；无代码改动 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A：`testIC123AIndicatorForegroundIsResolvedPerColorScheme`、`testIC123AIndicatorGlassContentFollowsInPlaceAppearanceSwitch`（@2x 截屏数近黑像素）+ 私有 helper `ic123NearBlackPixelCount`。附录：`testIC123AppendixIndicatorSeparatorIsResolvedPerColorScheme`、`testIC123AppendixIndicatorSeparatorLineDrawsWithGivenColor`；同一 helper 新增 `luminanceBelow` 参数（默认 24 不变，既有调用点零影响） |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | B：`testIC123BNonScreenAspectScreenshotZoomBaseIsFullViewportAspectFit`、`testIC123BScreenAspectScreenshotAndOrdinaryPhotoZoomBaseUnchanged`（等价断言）、`testIC123BLandscapeScreenshotDoubleTapKeepsAspectRatioThroughout`（进入 / 21 点采样 / 落地 / 退出）；`15ddb1f` 把首个用例的 `ratios` 显式标注 `[CGFloat]` |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `f71faaed34a146b536a284c9066406234554cf77` |
| 规格 v17 决策 20 语义 | 零改动（实现修回规格：基准 = aspectFit 于全视口） |
| 玻璃材质配方、布局几何、等距带公式、双击过渡曲线/时长 | 零改动（范围外遵守） |
| `S2ChromeForeground` 取值（IC-121 A） | 不变；撤回钮与顶/底排 chrome 仍走 `Color.primary/.secondary` |
| 其余三处 `Divider()`（`S2View.swift` 行 1931 / 2012 / 2047） | 未动（不在指示器内，超出附录授权范围） |
| 分隔线几何（粗细、高 22pt）与 IC-120 A 登记语义（交系统自适应分隔色） | 零改动；附录只把该自适应色**何时解析**从动态改为按 colorScheme 当拍解析 |
| `S2CalibrationConfiguration` 字段与出厂值 | 零 diff；`schemaVersion` 仍为 7 |
| `.github/`、`Scripts/` | 零 diff |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| IC-122 | 未触碰（另卡） |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 / stash 操作 | 未执行（#234 修正以新 commit 追加；仓内两条 IC-067 旧 stash 原样保留） |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 **7**）。本卡无新增取定项：A 的定值色与
`Color.primary` 同源（`UIColor.label` 两态），非新配色；B 为回归规格既有定义；附录的定值分隔色与
系统自适应分隔色同源（`UIColor.separator` 两态），IC-120 A 的登记条目语义不变，也非新配色。

## 报告提交

上一版 `Reports/IC-123/`（A / B）随 `883b89a` 推送，引用 #233 / #234 / #235；本完整替换版（含附录）
随新的 docs 提交推送，同卡同分支追加，因需引用推送后才产生的 **#236** 编号与 IPA 哈希。

两次 docs 提交均命中 `paths-ignore`、不触发 CI，属预期。验证产品代码的运行：
**#233**（A，`01219d1`）、**#235**（B，`15ddb1f`）、**#236**（附录，最终 tip `1f3a992`）。
