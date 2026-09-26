# IC-177 变更清单

## 一、概要

- 任务卡：`<top>/Tasks/IC-20260926-177-unified-background.md`
- 基线 `main`：`3b49e4a8bdea5fc3331dfb170689b265115f255b`
- 分支：`feature/ic-177-unified-background`（tip `3cdae926a1af29ac5a19f97885737420e56a0df4`）
- 合并提交：`9bb803525f8186625322fecce02dc67d070409e7`（`--no-ff`，已推送）
- CI：#360 绿 916／0（`3cdae926a1af29ac5a19f97885737420e56a0df4`）；合并后 `main` #361 绿 916／0（`9bb803525f8186625322fecce02dc67d070409e7`）
- 报告落点：合并与合并后运行之后在 `main` 上追加恰一个 docs 提交（惯例 44）

## 二、逐提交变更

### A `aede7dedd2c1d0adfe4b13c9c2f52e1a81b9386e` — S1（裁定 一、二、四、五）

| 处 | `PhotoCleanupMVE/Features/S1/S1View.swift` 变更 |
|---|---|
| A1 | `S1ChromeForeground`：`primary` = `S0DeckMetrics.text`、`secondary` = `text.opacity(secondaryOpacity)`；新增 `tertiary`、`separator`、`accent`、`pageBackground`、`cardBackground` 与 `secondaryOpacity` 0.62／`tertiaryOpacity` 0.45／`separatorOpacity` 0.14；文档注释改写 |
| A2 | `S1NotificationBadgeStyle.chromeRing` → `S1ChromeForeground.pageBackground`，`cardRing` → `S1ChromeForeground.cardBackground`；注释一处 |
| A3 | `S1YearStackStyle.layerOneColor`／`layerTwoColor` 由 `static var` + `dynamicColor(light:dark:)` 改为 `static let` 恒定 sRGB #3A3A3C／#2F2F31；`dynamicColor` 删除 |
| A4 | 封面占位底 `.secondarySystemFill` → `S1ChromeForeground.cardBackground` |
| A5 | 根背景 `.systemGroupedBackground` → `S1ChromeForeground.pageBackground` |
| A6 | `Color.accentColor` 全部 5 处 → `S1ChromeForeground.accent` |
| A7 | 菜单底颜色源 `Color(uiColor: .systemBackground)` → `S1ChromeForeground.cardBackground`（`.opacity(S1MenuStyle.backgroundOpacity)` 与 `.ultraThinMaterial` 不动） |
| A8 | `.fill(Color(uiColor: .separator))` 全部 2 处 → `.fill(S1ChromeForeground.separator)` |
| A9 | `.foregroundStyle(Color(uiColor: .tertiaryLabel))` 全部 3 处 → `.foregroundStyle(S1ChromeForeground.tertiary)` |
| A10 | 范围卡底 `.secondarySystemGroupedBackground` → `S1ChromeForeground.cardBackground` |
| A11 | 加载 `ProgressView()` → `ProgressView().tint(S1ChromeForeground.secondary)` |

### B `b00dc63e691cd1c682e0921209e5f02300c4e854` — S3／S4

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S3/S3View.swift` | B1 根背景 → `pageBackground`；B2 提交按钮底 `.systemRed` → `accent`；B3 分组卡底 → `cardBackground`；B4 空态图标 → `tertiary`；B6 两个 `ProgressView()` 加 `.tint(S1ChromeForeground.secondary)` |
| `PhotoCleanupMVE/Features/S4/S4View.swift` | B5 根背景 → `pageBackground`；B7 两个 `ProgressView()` 加 `.tint(S1ChromeForeground.secondary)` |

### C `4d16c74d94c3623cc251fd4212ba9eb605231523` — S5

| 处 | `PhotoCleanupMVE/Features/S5/S5View.swift` 变更 |
|---|---|
| C1 | `S5HeroPalette`：`success` = `S0DeckMetrics.mint`、`warning` = 恒定 sRGB #FF9F0A、`neutral` = `S1ChromeForeground.tertiary`（三者由 `static var` 改 `static let`）；文档注释改写 |
| C2 | `primaryButtonForeground` `.leaveCompletion` → `S1ChromeForeground.pageBackground` |
| C3 | `primaryButtonFill` `.returnToConfirmation` → `S1ChromeForeground.accent`；注释两行 |
| C4 | 根背景 → `pageBackground` |
| C5 | 失败数 `.systemRed` → `S1ChromeForeground.accent` |
| C6 | 卡底 → `cardBackground` |
| C7 | 加载 `ProgressView()` 加 `.tint(S1ChromeForeground.secondary)` |

### D `47b656c54621eb75f009ea999ee5c48cedfd1427` — S2 幕底（裁定 三）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift` | `S2AmbientMetrics.baseColor` 分量 11／26／19 → 11／15／13（#0B0F0D）；上方注释改写（「取值出处：Decision_log 第 175／176 条」保留，全文仍 12 处） |
| `PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift` | `:473` 注释改写；`:481-482` 期望 26／19 → 15／13 |
| `PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift` | `:180` 注释改写；`:181` 期望 26／19 → 15／13 |

### E `3cdae926a1af29ac5a19f97885737420e56a0df4` — 新断言

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift`（新建） | 逐字节拷自 `<top>/Tasks/decision-tools/`，blob `844572b4973615ec681278c3f59a345a13d2b21c`；三条测试 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记一个测试文件四行：PBXBuildFile `200000000000000000000076`、PBXFileReference `100000000000000000000079`、测试组子项、测试目标 Sources 构建阶段项 |

### merge `9bb803525f8186625322fecce02dc67d070409e7`

父 `3b49e4a8bdea5fc3331dfb170689b265115f255b` 与 `3cdae926a1af29ac5a19f97885737420e56a0df4`；树 `7a49b7a405ad5d125ffe51ad7fec731262fad8fc` 与 E 的树相同。

## 三、路径汇总（`git diff --name-only 3b49e4a..3cdae92`，恰 9 个）

| 路径 | 类别 | 子项 |
|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | 产品 | A |
| `PhotoCleanupMVE/Features/S3/S3View.swift` | 产品 | B |
| `PhotoCleanupMVE/Features/S4/S4View.swift` | 产品 | B |
| `PhotoCleanupMVE/Features/S5/S5View.swift` | 产品 | C |
| `PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift` | 产品 | D |
| `PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift` | 测试 | D |
| `PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift` | 测试 | D |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | 测试（新建） | E |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 工程 | E |

另 docs 提交（合并后落 `main`）：`Reports/IC-177/self-check.md`、`Reports/IC-177/change-list.md`。

## 四、占位值登记

- 本卡不改 `S2CalibrationConfiguration` 出厂值，`schemaVersion` 仍 **7**。
- 卡内暂登三个不透明度（`S1ChromeForeground.secondaryOpacity` 0.62、`tertiaryOpacity` 0.45、`separatorOpacity` 0.14，取自 R2 画布 `.dim`／`.dim2`／`.edge`），待 SPEC-S1 v11 第十一节登记。
- `S0DeckMetrics` 未加常量（仍 195）；文案目录未加 key（仍 262）。

## 五、测试项数

913（基线）+ 3（`IC177UnifiedBackgroundTests`）= 916；A～D 不增删测试。
