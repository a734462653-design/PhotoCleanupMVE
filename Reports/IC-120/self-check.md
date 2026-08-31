# IC-120 自验报告：chrome 前景自适应配色 + 角标 z 序修复——**两子项全绿**

## 结论（先行）

**A、B 两子项交付并绿，一次 CI 通过。** 最终绿 tip（代码）= `b7690670781aa71f5d2c678567fd79c1bce75d35`
（子项 B；子项 A = `ad49af7`，两 commit 各自独立可 cherry-pick），CI **#230**（run 33322920657），
**XCTest 584 项 0 失败**，真实退出码 0，IPA 1057086 字节，
SHA-256 `7dcb8434075ca1a8d1fba1285109c785767ff2ce1459550cf925b36f9f19a485`。
CI 用 **1/2**，时间闸门未超。`schemaVersion == 7`、登记值、冻结三链、`ci.yml`、`Scripts/`
零改动（G304）。G305 未触发。**未合并 `main`，执行完即停。**

- **G302 通过**：开工工作树净，tip = `46f567d`（IC-118 报告提交，短 SHA + 身份比对）。
- **G303 达成**：#230 success、0 失败、退出码 0、IPA 已登记。

## 输入与范围

- 输入：`IC-20260830-120-adaptive-chrome-colors.md`（H53 第 3 项返工 + 配色规则 ④ 全文）。
- 目标分支：`feature/ic-110-visual-batch`；继承提交 `46f567d`。
- 范围边界遵守：玻璃材质配方与布局几何零改动（`S2ChromeGlass`、`s2ChromeGlassBackground`、
  `S2OverlayLayout` 全部未动）；曲线时长未动；SPEC/Decision_log 未动。

## 子项 A：chrome 前景自适应配色（commit `ad49af7`）

**规则落地**：`S2ChromeForeground` 收敛为**两分支同一取值**——`onGlassPrimary = .primary`、
`onGlassSecondary = .secondary`（SwiftUI 语义色，浅色全黑/深色全白自适应；iOS 26 玻璃分支
同时获得 vibrancy，17–25 回落分支同样自适应）。**IC-117 的回落定值（纯白/白 62%）与
IC-118 C 的一刀切黑口径随本卡废止。**

逐件清单（④ 点名六件 + 延展件）：

| 件 | 改动 |
|---|---|
| 左上返回图标 | 显式 `.primary`（原无显式样式，默认吃按钮 tint） |
| 中上日期主行 | 已是 `.primary`，未动 |
| 中上序号·大小副行 | 系统次级色 `.secondary`（**卡内取定登记**：与主行区分层次）；白 62% 定值废止，`subtitleOpacity` 常量删除、对应断言随删 |
| 右上垃圾桶图标 | 118 C 写死黑 → `.primary`（教程/非教程共用） |
| 左下爱心 | 显式 `.primary` |
| 中下最近相簿胶囊（图标+文字） | 整体显式 `.primary` |
| 右下加入相簿图标 | 显式 `.primary` |
| 中央指示图标/文字 | 经 `onGlassPrimary` 自动随规则（已接线） |
| 中央指示撤回钮 | **H53 纠偏**：118 C 写死黑 → `.primary`（深色即白） |
| 中央指示分隔线 | 写死白 35% 去除 → 系统自适应分隔色（登记） |
| 「已加入」提示文字 | **H53 纠偏**：经 `onGlassPrimary` 回自适应 |
| 教程提示卡文字/跳过 | 已是 `.primary`/`.secondary`，未动 |
| 教程「完成」钮 | 写死黑底白字废止 → **反相配对**：底 `Color.primary`、字 `Color(uiColor: .systemBackground)`（浅色黑底白字/深色白底黑字，**卡内取定登记**） |
| 教程 sheet 提示条 | 写死白 → `.primary`（材质上自适应） |
| 相簿 sheet「新建相簿…」行 | 118 C 写死黑 → `.primary` |
| 相簿 sheet 行文字/数量 | 已是默认/`.secondary`，未动 |
| sheet `tint` | `.tint(Color.black)` → `.tint(Color.primary)`（取消钮、行按钮、命名弹窗按钮随 tint） |

**唯一例外（卡内条款）**：垃圾桶角标数字 `Color.red` 恒红，两种模式同（见子项 B）。

**保留定值并登记（非常规 chrome 前景）**：
1. 教程步 6 垃圾桶高亮态（白底 + 黑图标 + 白外发光，IC-112 C ④ 强调态视觉）；
2. 缩略栏待删标记 `S2PendingDeletionMark`（白桶/黑圈，叠在缩略图上的内容标记）。
若决策会话认为二者也应随规则，另卡处理。

**两分支取值/断言分别核（卡内第 5 条）**：两分支现为同一常量表达式（`.primary`/`.secondary`
无分支），编译期即同一取值；固定值断言仅有 `subtitleOpacity == 0.62` 一条，已随常量删除。
渲染观感（vibrancy 下的黑/白呈现）为真机项，H54 第 1 项判。

## 子项 B：角标 z 序真修（commit `b769067`）

**真因（③，机制与 H53 实测逐点吻合；CI 模拟器为 iOS 18.5、无玻璃渲染，无法在 CI 实证）**：
iOS 26 的 `glassEffect` 把「玻璃 + 其内容」提升到 `GlassEffectContainer` 的合成层，
**晚于容器子树内普通视图内容绘制**。IC-118 C 把角标移到按钮标签链最外层，但该 overlay
仍属容器子树 → 仍被提升后的玻璃层盖住——这正是 H53 看到「移出回弹链没解决」的原因。
非 zIndex、非容器裁剪（回落分支材质背景下同一 overlay 是正常层序，H52 前的历史包无此问题）。

**修复**：角标以 overlay 叠在 **`GlassEffectContainer` 之外**（`topBar` 层级；17–25 回落
分支同一实现），按兄弟层序恒在玻璃之上。锚点 = 顶排右上圆钮 topTrailing 角，内边距直接
取 `S2OverlayLayout.topRowTopInset` / `chromeHorizontalMargin`（与圆钮几何同源，非拍值）；
数字恒红（A 例外条款）；`allowsHitTesting(false)`——命中仍全落在垃圾桶按钮上。

| 验收点 | 测试函数 |
|---|---|
| 角标锚点内边距与右上圆钮 topTrailing 角几何同源 | `testIC120BBadgeAnchorMatchesTrailingCircleTopCorner` |

**证据分级**：渲染层序（容器外 overlay 恒在玻璃之上）SwiftUI 夹具无法断言，
**真机未覆盖**，H54 第 1 项兜底；锚点几何为夹具事实。

## CI 与本地门禁（①）

- **CI #230**（run 33322920657）success：被测提交 `b769067`（含 `ad49af7`），
  **Executed 584 tests, with 0 failures**（IC-118 #229 的 583 + B 新增 1 − A 删除 0；
  A 删除的是断言行非独立用例），`exit "$test_status"` ⇒ 真实退出码 0。
  IPA 1057086 字节，SHA-256 `7dcb8434…a485`。
- 本地门禁：两次提交前均退出码 0（`git diff --check`、`selfcheck.ps1`、扫描器）。

## H54 人工判定清单（保留给 Lynn，不代为下结论）

1. 深色模式：chrome 前景全白 + 角标红数字在圆钮之上；浅色模式：全黑 + 红数字
   （切换系统外观各过一遍）。
2. 撤回钮与加入提示文字恢复自适应（深色下白）。
3. 抽查回归：玻璃质感、中央指示、教程、残影。
   （另请顺带看：命名弹窗按钮是否随 `.tint(.primary)`；教程完成钮反相配对观感。）

## 停线 / 偏差 / 待补核（逐条）

### 停线
- 未触发。CI 用 1/2。

### 偏差
1. **B 真因为 ③ 而非 ①**：机制归因（玻璃合成层提升）与 H53 实测及两分支历史表现逐点
   吻合，但 CI 无 iOS 26 运行时、本机无 Xcode，无法拿到渲染层序实测；修复方案对任何
   层级机制都成立（容器外兄弟层序）。若 H54 仍见角标被盖，则该归因被推翻，须另查。
2. 教程「完成」钮的反相配对与副行次级色为卡内授权范围内的取定，均已登记。

### 待补核
1. H54 三项（含 alert 按钮随 tint 与否——系统行为，IC-118 遗留项在自适应下继续有效）。
2. 保留定值两处（教程步 6 高亮态、缩略栏待删标记）是否也应随自适应规则，留决策会话。
