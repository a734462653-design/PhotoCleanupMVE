# IC-118 自验报告：H52 修复批次——**四子项全绿**（含总执行结果包）

## 结论（先行）

**A、B、C、D 四子项全部交付并绿，各自独立 commit、独立 CI。**
最终绿 tip（代码）= `cc5530d49b46132ff61de67ac516464644b7d5b1`（子项 D），CI **#229**，
**XCTest 583 项 0 失败**，真实退出码 0，IPA 1052640 字节，
SHA-256 `0ac2c833a424ac60ef4708338d3238d053062808c5cc4fec92ca70c23067768e`。
CI 用量 **4/7**（A 1/2、B 1/2、C 1/1、D 1/2），时间闸门未超。
`schemaVersion == 7`、登记值、冻结三链、`ci.yml`、`Scripts/` 零改动（G296；
探针基建改动按卡内豁免登记于下）。**未合并 `main`，执行完即停。**

- **G294 通过**：开工工作树净，tip = `60b378b`（IC-117 报告提交，短 SHA + 身份比对）。
- **G295 达成**：四子项各自绿、0 失败、退出码 0、IPA 逐项登记（见总表）。
- **G297 通过**：A/B 经状态机与既有分派路径，无视图层旁路（B 的清算是视图层
  推迟缓存对机器已发布 V 的对账，V/scale 决策仍全在状态机）；D 无新增删除路径。
- **G298 未触发**：全程无无关测试失败。

## 输入与范围

- 输入：`IC-20260830-118-h52-fixes.md`。
- 目标分支：`feature/ic-110-visual-batch`；继承提交 `60b378b`。
- 范围边界逐条遵守：SPEC/Decision_log 未动；决策 20/40 契约语义未动；
  曲线时长常量未动；历史相簿成员关系未查询；rebase/amend/force push 未执行。

## 子项 A：捏合进入放大未自动隐藏（绿，#226）

### 探查结论（卡内要求，①）

真机捏合的 `s` 越过 1 的实际路径：`scrollViewWillBeginZooming → machine.beginPinch()`，
随后 **`scrollViewDidZoom` 逐帧 → `machine.reportNativeViewport`**，结束时
**`scrollViewDidEndZooming → machine.finishNativePinch`**。其中 `reportNativeViewport`
（`self.scale = nextScale`）与 `finishNativePinch`（`self.scale = 1`）两处**直写绕过了
`setScale` 汇集口**——⑤a 的自动隐藏判定只在 `setScale` 里。夹具驱动的
`updatePinch / endPinch` 恰好都经 `setScale`，故夹具全绿、真机不隐藏（陷阱 1 显影的
准确机制）。IC-114 D 报告中「改道后全文件只剩两处直写」的声称漏了这两处。

### 修复（commit `5c21f18`，仍经状态机统一分派）

- 两处直写改道 `setScale`；`setScale` 增加 `appliesZoomVisibilityRule` 形参（默认 true，
  行为与既有调用方完全一致）。
- **回声防抖**：无捏合在途（`touchSequenceOwner != .pinch`）的视口回报（捏合结束后
  `setZoomScale(animated:)` 回弹动画帧同样逐帧回报）只写倍率、不触碰 V——否则
  恢复 V 后会被瞬时重隐藏一次形成闪烁。等值不发布守卫（IC-095 R4）原样保留。

| 验收点 | 测试函数 |
|---|---|
| 真机调用序列（beginPinch → 逐帧回报 → finishNativePinch）自动隐藏并恢复 | `testIC118ANativePinchViewportReportAutoHidesAndRestores` |
| 松手低于回弹阈值（出厂 1.1）归位同样恢复 | `testIC118AFinishNativePinchSnapBackRestoresVisibility` |
| 无捏合在途的回声不触 V、不改记录 | `testIC118AViewportEchoWithoutPinchDoesNotTouchVisibility` |

**证据分级**：三条均为状态机层按真机调用序列复刻；scroll view 委托接线本身夹具
无法覆盖（陷阱 1），**真机未覆盖**，由 H53 第 1 项兜底。既有调用点逐一核过：
`reportNativeViewport` 的 6 处测试调用均无 V 断言冲突（多数在捏合语境下今后会隐藏 V，
但断言只涉 imageRequest/几何字段）。

## 子项 B：截图双击退出在 1x 卡顿（绿，#227）

### 夹具复现与根因（②→修复后由测试钉住；比卡内 ③ 更具体）

卡内 ③ 猜测「V 恢复动画与推迟应用几何落地串行排队」。夹具追帧后的准确机制：
**退出过渡的 `targetFrame` 取自 `pendingPresentationPage`**——⑤a 下这是**进入时**被
推迟的隐藏态全幅几何（IC-115 v2 已确立：截图进入 Nx 时隐藏态页面侧不落地、推迟在案），
而机器侧 V 已在退出瞬间恢复为记录值（显示）。于是退出动画飞向**全幅基准位**落地，
显示态等距带几何由完成回调另行落一步——即「在 1 倍位置卡一下，然后才回到显示态画面」。

### 修复（commit `3310315`，行为目标达成，契约零改动）

- 页面控制器新增 `reconcileDeferredPresentation(currentVisibility:)`：**只丢弃**与当前 V
  不一致（已被退出恢复取代）的推迟目标；与当前 V 一致的推迟照旧按决策 40 在回 1x 应用
  （IC-063 G6 场景语义逐字保留，该测试未动仍绿）。
- 三个退出入口先清算再起过渡：产品双击 `handleDoubleTap`、捏合归位 `finishNativePinch`
  （A 修复让捏合入口产生同族推迟记录，归位不清算会先提交过期几何再跳回）、诊断驱动
  `beginDiagnosticDoubleTap`（诊断过渡端点与真机同一套）。
- 清算后退出过渡落点回到本页已提交几何 = **当前 V 对应 1x 几何**（决策 20 的字面要求）。
- **闸门 B1 未触发**：`zoomScale ≤ 1` 守卫、推迟应用机制、决策 20/40 语义、
  `S2DoubleTapTransitionTiming` 曲线时长常量全部零改动。

| 验收点 | 测试函数 |
|---|---|
| 退出过渡落点 = 恢复后 V 的等距带几何、过期推迟被清算、无第二段过渡 | `testIC118BDoubleTapExitTargetsRestoredVisibilityGeometry` |
| 清算语义：一致保留（G6 族）/ 不一致丢弃 | `testIC118BReconcileKeepsMatchingDropsStaleDeferredTarget` |
| 捏合归位路径同一清算 | `testIC118BPinchReturnDropsStaleDeferredTarget` |

### 探针基建改动（卡内允许，登记）

IC-108 双击探针补**退出阶段采样**：`recordDoubleTapExitTarget`（过渡瞄准的落点帧 +
是否取自推迟目标）与 `recordDoubleTapExitCommit`（几何落地取值与时刻；与
`recordDoubleTapEnded` 的时间差即「过渡结束 → 落地」间隙）。报告文本增两条缩进子行
（`退出落点｜…`、`退出落地｜…`），列头与格式版本未动（既有格式断言仍绿）。探针默认
关闭、关闭时零开销的结构未变。新增中文字面量位于扫描器 `S2GeometryDiagnosticsRun`
豁免区之后，自动归入诊断协议字段，无需另行登记 key。
真机时间线核对方法：开探针 → 截图双击进出 → 报告中「距过渡结束ms」应接近 0 且
「落点来源=当前V已提交几何」。

## 子项 C：视觉调整两组 + 中央指示（绿，#228）

1. **角标**（④）：移到垃圾桶按钮标签链**最外层**（在玻璃与回弹动画之外，不再被
   `glassEffect(in: Circle())` 形状裁切），数字改**红色**。登记代价：IC-111 B 的落点
   回弹现在只弹圆钮、角标不随缩放（数字滚动 contentTransition 保留）。
2. **蓝改黑逐处列表**（④，全仓扫 `.accentColor` / `.blue` / `#0a84ff`，共 4 处显式命中 +
   系统 tint 一处；全仓无 `AccentColor` 资产、无其他命中；S3/S4/S5 零命中）：
   - `S2View.swift` 相簿选择器「新建相簿…」行（文字+图标）→ 黑；
   - 顶部垃圾桶图标（非教程态 accentColor；教程态本就黑）→ 恒黑；
   - 教程「完成」钮胶囊底 accentColor → 黑（白字不变）；
   - 中央指示「撤回」钮文字 accentColor → 黑；
   - 相簿选择器 `NavigationStack` 加 `.tint(.black)` 收编系统蓝（工具栏「取消」、
     行内按钮文字）。**alert（新建相簿命名框）按钮是否随 tint 由系统决定，留 H53 真机核。**
3. **中央指示**（④）：跑道胶囊 → **单层系统玻璃正圆**（直径 = `containerHeight` 46 沿用，
   教程步 4 避让锚点因此不变），内层小方块删除、垃圾桶图标直接落圆框内。
   **已加入态实际布局方案（卡内要求登记）**：左侧玻璃正圆承载图标，右侧同族玻璃胶囊
   旁挂文字与撤回钮；撤回短提示保持胶囊。`blockSize` / `blockCornerRadius` 常量随删，
   对应断言按 ④ 改写（`testIC113BTransitionParametersMatchCanvas`）。
   命中测试硬闸门语义一字未动（仅撤回钮可点，`testIC113BOnlyUndoControlIsHittable` 未改仍绿）。

**证据分级**：颜色与层级为声明式改动 + 既有文案/呈现断言，视觉效果真机未覆盖，H53 第 3 项判。

## 子项 D：相簿指示按张记忆（绿，#229）

- 状态机新增 `@Published sessionAlbumAdditionsByAsset: [String: S2AlbumReference]`
  （会话内存、不持久化）：写入收敛在 `publishAlbumAddition` **单一汇集口**（中胶囊与
  选择器两条加入路径都汇入，不可能漏登）；`completeAlbumRemoval` 成功只清**该张**；
  失败保留（沿用既有反馈通道）。
- `makeAlbumRemovalRequest` 改按**当前张**出请求（原全局最近一次口径下，翻页后
  撤回请求会错发到别张——新增测试钉住）。撤回仍走既有 `removeAssets` 路径，
  **无新增删除路径**（G297）；未查询历史相簿成员关系（范围外遵守）。
- 视图侧「最近一次动作」改 `[assetID: action]` 按张记忆（全局 `centerIndicatorLastAction`
  废止）：标记/取消记到被操作那几张、加入记到加入那张（延时后按 record.assetID 落账，
  不受期间翻页影响）、翻页不再清动作、新页按自己的记录重算。
  `S2CenterIndicatorResolver` 解析规则零改动（按张值从调用点传入）。

| 验收点 | 测试函数 |
|---|---|
| 每张各自记住、翻页来回不丢、撤回请求跟随当前张 | `testIC118DSessionAlbumAdditionsRememberPerAsset` |
| 没加过的张取不到撤回请求；撤回成功只清该张 | `testIC118DRemovalFollowsCurrentAssetAndClearsOnlyIt` |
| 撤回失败保留按张记录 | `testIC113BFailedRemovalKeepsRecord`（追加断言） |

**证据分级**：机器级为夹具事实；SwiftUI onChange 接线（翻回显示、按张互斥的实际观感）
真机未覆盖，H53 第 4 项判。

---

# 总执行结果包

| 子项 | 提交 | CI | XCTest | 退出码 | IPA 字节 | IPA SHA-256 |
|---|---|---|---|---|---|---|
| A 捏合自动隐藏 | `5c21f18` | **#226**（33317223102） | 578 / 0 | 0 | 1038084 | `a9a73c25e67c2c758ca263a652b2ef8eaac6722763a138b1b4c05b64630bccef` |
| B 双击退出卡顿 | `3310315` | **#227**（33318027927） | 581 / 0 | 0 | 1041734 | `173998b5a5061050f9b9850a5b834a9e5ec798211e8d47baf58b86f028376163` |
| C 视觉三组 | `3bc22d9` | **#228**（33319149482） | 581 / 0 | 0 | 1048434 | `17fbee7117850cac72b0cfa2e56760b8a59db4f3991343dd18e17fb40b6ec857` |
| D 按张相簿指示 | `cc5530d` | **#229**（33319988976） | 583 / 0 | 0 | 1052640 | `0ac2c833a424ac60ef4708338d3238d053062808c5cc4fec92ca70c23067768e` |

- **H53 包 = `cc5530d`（run #229）**，Xcode 26.3 工具链，XCTest 于 iPhone 16 / iOS 18.5 模拟器。
- 测试计数走向：575（#225 基线）→ 578（A +3）→ 581（B +3）→ 581（C ±0）→ 583（D +2 新测试，
  另有一条追加断言不增计数）。
- 分支最终 tip = 本报告 docs 提交；未合并 `main`（仍 `a013098…`）；冻结三链未触碰。
- 本地门禁：每次提交前 `git diff --check` / `selfcheck.ps1` / 扫描器均退出码 0。

## H53 人工判定清单（保留给 Lynn，不代为下结论）

1. 捏合进入放大：自动隐藏生效（带动画），退出恢复。
2. 截图双击进出：退出一气呵成无卡顿（重点）；连做 5 次无劣化。
   （可开 IC-108 探针核时间线：「距过渡结束ms」≈0、「落点来源=当前V已提交几何」。）
3. 角标在圆钮之上、数字红色；蓝色图标全黑（含选择器取消钮与行按钮；
   **alert 按钮颜色请一并看**）；中央指示为单层玻璃正圆。
4. 相簿指示：加过相簿的每张翻回都显示、可撤回；与标记态按张互斥。
5. 回归：教程、选择器、残影、132 条、等距带。

## 停线 / 偏差 / 待补核（逐条）

### 停线
- 未触发（A/B/C/D 各一次 CI 全绿；B1、G293/G298 均未触发）。

### 偏差
1. **IC-114 D「只剩两处直写」声称被推翻**（A 探查①）：漏了 `reportNativeViewport` 与
   `finishNativePinch`。已改道并在 `setScale` 注释中更正。
2. **B 的根因与卡内 ③ 不同**：不是动画串行排队，而是退出过渡瞄准了过期的推迟目标；
   修复按行为目标达成、契约未动。
3. **C 角标回弹解耦**：角标移出回弹动画链（为置于玻璃之上），落点回弹不再带角标缩放。
4. **B 复现顺序**：本机无 Xcode，「先测再改」以同一 commit 内的夹具测试承载
  （该测试在改动前语义下必红——targetFrame 断言直指旧行为取值），未单独推一次红 CI 验证旧行为。

### 待补核
1. A/B 的 scroll view 委托接线、C 的视觉效果、D 的 SwiftUI 接线均为真机未覆盖项，H53 兜底。
2. alert 按钮是否随 `.tint(.black)`（系统行为），H53 第 3 项看。
3. 发现未处理（按纪律只报告不修）：翻页场景下旧页残留的推迟呈现记录仍可能经
  `resetZoom → applyDeferredPresentationIfPossible` 提交到离屏旧页（⑤a 之前即存在，
  翻回时会被新页重算覆盖，无用户可见影响的证据，仅登记）。
