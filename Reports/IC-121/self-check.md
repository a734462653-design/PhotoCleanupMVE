# IC-121 自验报告：chrome 蓝色泄漏修复 + 角标通知徽标样式——**两子项全绿**

## 结论（先行）

**A、B 两子项交付并绿，一次 CI 通过。** 最终绿 tip（代码）= `a51a6caa9f213ef710f70fcb173c3c7dced22ec3`
（子项 B；子项 A = `e8ce2ef`，两 commit 各自独立可 cherry-pick），CI **#231**（run 33325967028），
**XCTest 586 项 0 失败**，真实退出码 0，IPA 1057426 字节，
SHA-256 `a15d786ebd470f31d07d0e152dd2afc7443f2a80552d68a61ee3c30cd0fc78d6`。
CI 用 **1/2**，时间闸门未超。`schemaVersion == 7`、登记值、冻结三链、`ci.yml`、`Scripts/`
零改动（G308）。G309 未触发。**未合并 `main`，执行完即停。**

- **G306 通过**：开工工作树净，tip = `eb65786`（IC-120 报告提交，短 SHA + 身份比对）。
- **G307 达成**：#231 success、0 失败、退出码 0、IPA 已登记。

## 输入与范围

- 输入：`IC-20260830-121-tint-leak-and-badge.md`（H54 返工）。
- 目标分支：`feature/ic-110-visual-batch`；继承提交 `eb65786`。
- 范围边界遵守：玻璃材质与布局几何零改动；SPEC/Decision_log 未动。

## 子项 A：蓝色泄漏（commit `e8ce2ef`）

### 探查结论（卡内要求：先探查出机制再修）

**代码层面（①）**：IC-120 写的 `AnyShapeStyle(.primary)`——`.primary` 经 SE-0299 静态成员
推断落到**层级样式** `HierarchicalShapeStyle.primary`（相对**当前前景层级**解析的样式），
而非具体动态色 `Color.primary`。这是两条渲染路径的分叉点。

**运行时行为（③，SwiftUI 未文档化细节；与 H54 两张截图①逐点吻合）**：

1. **启用态** Button 的标签环境里，按钮样式已把前景层级设为 tint（默认 accent 蓝），
   层级 `.primary` 解析为该层级的第一级 = **蓝** → 静止时蓝；
2. **禁用态** Button 的前景层级被换成禁用前景（深色模式下白/浅灰），层级 `.primary`
   随之解析为**白** → 拖横栏时 `touchSequenceOwner != .none` 使顶排
   （`topBar.disabled(machine.touchSequenceOwner != .none)`）与底排
   （`S2ActionBarPresentation.barEnabled = touchSequenceOwner == .none`，①代码可核）
   **全部按钮禁用**，故拖动期间变白；
3. 旁证三条：受影响四件（返回/爱心/中胶囊/加相簿）**全在 Button 标签内**；
   中上日期主行不在按钮内，层级 `.primary` 正确解析为 label 色，故截图中不蓝；
   垃圾桶在无标记时 `canEnterConfirmation == false` **恒禁用恒白**——与 Lynn 未点名它吻合。

候选归因排除：非 iOS 26 玻璃交互变体的内容 tint、非 `GlassEffectContainer` 合成态切换
——泄漏与玻璃无关，机制完全落在 SwiftUI Button 前景层级语义上（sheet 内「新建相簿…」行
同属此陷阱，一并修复）。

### 修复（落在成因上，非表观盖色）

`S2ChromeForeground` 从层级样式改为**具体动态色**：`onGlassPrimary = Color.primary`、
`onGlassSecondary = Color.secondary`。具体色不参与 tint/层级解析，启用/禁用/交互全部
状态下恒定为系统自适应黑/白；深浅自适应与玻璃 vibrancy 语义不变（IC-120 规则原样满足）。
「新建相簿…」行的裸 `.foregroundStyle(.primary)` 一并收编。未叠加任何覆盖层。

| 验收点 | 测试函数 |
|---|---|
| chrome 前景为具体动态色（防回退层级样式） | `testIC121AChromeForegroundIsConcreteAdaptiveColor`（`Color` 可比较，钉住取值） |

**证据分级**：机制的代码侧为 ①；启用/禁用态下层级样式的运行时解析行为 CI（iOS 18.5
模拟器、无真机截图比对）无法复现验证，为 ③ 标注，**真机未覆盖**，H55 第 1 项兜底
（重点：静止 30 秒以上再看 + 交互后回静止）。

## 子项 B：角标通知徽标样式（commit `a51a6ca`）

红底白字圆形徽标：单个数字为正圆（最小径 **18**）、两位以上由 `Capsule` 自然变胶囊；
数字白色 12pt semibold（观感对齐系统通知角标）；外圈 **1.5pt** 描边取
`Color(uiColor: .systemBackground)`（浅色白圈/深色黑圈——「与所处背景协调」的
**取定并登记**）。深浅模式同款（红底白字恒定），**IC-120「裸红数字」口径由此取代**。
锚点（圆钮 topTrailing、`S2OverlayLayout` 顶排几何同源）、玻璃合成层之外、
`allowsHitTesting(false)`、IC-111 B 数字滚动全部保持。取值集中在
`S2ConfirmationBadgeStyle`。

| 验收点 | 测试函数 |
|---|---|
| 红底/白字/1.5pt 描边/正圆最小径容得下数字 | `testIC121BBadgeMatchesNotificationStyle` |
| 锚点几何与圆钮同源（IC-120 既有） | `testIC120BBadgeAnchorMatchesTrailingCircleTopCorner`（未动仍绿） |

**证据分级**：样式取值为夹具事实；渲染观感（与系统通知角标同族）真机未覆盖，H55 第 2 项判。

## CI 与本地门禁（①）

- **CI #231**（run 33325967028）success：被测提交 `a51a6ca`（含 `e8ce2ef`），
  **Executed 586 tests, with 0 failures**（#230 的 584 + A/B 各一条新测试），
  `exit "$test_status"` ⇒ 真实退出码 0。IPA 1057426 字节，SHA-256 `a15d786e…78d6`。
- 本地门禁：两次提交前均退出码 0（`git diff --check`、`selfcheck.ps1`、扫描器）。

## H55 人工判定清单（保留给 Lynn，不代为下结论）

1. 深色模式静止状态：全部 chrome 前景白色（重点：静止 30 秒以上再看）；
   拖横栏、点按、翻页后回到静止仍白；浅色模式同理全黑。
2. 角标：红底白字圆形徽标，在圆钮之上，观感与系统通知角标同族
   （单数字正圆、多位胶囊、描边圈与环境协调）。
3. 抽查：玻璃质感、按压反馈、中央指示、教程。

## 停线 / 偏差 / 待补核（逐条）

### 停线
- 未触发。CI 用 1/2。

### 偏差
1. **IC-120 A 的实现缺陷由本卡确认并修复**：IC-120 报告中「两分支同一取值」的结论在
   取值层面成立，但载体（层级样式）在按钮内的解析行为未被识别——夹具无法覆盖该行为，
   H54 真机显影。本卡改具体色并加了防回退断言。
2. 描边色「与所处背景协调」落为系统底色（深浅自适应），为卡内授权范围内取定，已登记。

### 待补核
1. H55 三项；alert 按钮随 tint 与否（IC-120 遗留）在 H55 第 3 项顺带看。
2. IC-120 保留定值两处（教程步 6 高亮态、缩略栏待删标记）是否随自适应规则，仍留决策会话。
