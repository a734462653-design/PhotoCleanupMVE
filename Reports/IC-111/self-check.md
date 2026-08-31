# IC-111 自验报告：视觉批次 v2（按 v18 画布基准返工）

## 结论（先行）

**A、B、C、D 四项全部交付，最终绿 tip `eea617a3482dec47a28e5226851871ebb52dd5e3`。**

- **G271 通过（附一处偏差，已获 ④ 确认）**：工作树净、分支 `feature/ic-110-visual-batch`。**卡内 tip SHA `8450c2812f34c96e2f0b52ab1e33bd07fdfd4a24` 在仓库中不存在**（`git cat-file` 报 could not get object info）；实际 tip 为 `8450c28e2bec414f4aa71139637e5f225721a6f4`，前 7 位一致、正是 IC-110 报告提交。就地停下询问，**④ 2026-08-30 确认按实际 tip 继续**。
- **G272 通过**：四项各自 CI success、按实计数 0 失败、真实退出码 0。最终绿 tip CI **#204**，**`Executed 554 tests, with 0 failures (0 unexpected)`**，IPA **926083 字节**、SHA-256 **`264e3518c38cc3d4dfd2a00cdac828fed44878e0b5caaf25237d39a11d973b52`**。
- **G273 通过**：`schemaVersion == 7` 全仓唯一（随 A 由 6 升 7）；冻结三链未触碰；`ci.yml`、`Scripts/`、`export-format.md` 零改动。
- **G274 通过**：全卡 diff 中**无任何**手势识别器相关改动（`GestureRecognizer` / `addGestureRecognizer` / `numberOfTapsRequired` / `require(toFail:)` 逐条 grep 为空）；产品手势语义未动；测试未为动画降门槛。
- **G275 未触发**：唯一一次红（#200）的失败项是本卡自己改动的底部几何断言，不是与本卡无关的测试。
- **CI 预算 5/8**（A 2、B 1、C 1、D 1），**未超**。开工 2026-08-29 03:38，收口 05:2x，**用时约 1 小时 50 分**，6 小时闸门未超。
- **全程未合并 `main`**（`main` 仍为 `a013098…`）。

---

## H48 包

| 项 | 值 |
|---|---|
| **run 编号** | **#204** |
| 被测提交 | `eea617a3482dec47a28e5226851871ebb52dd5e3` |
| XCTest | **554 项 0 失败**（0 unexpected） |
| 真实退出码 | 0（`ci.yml` 以 `exit "$test_status"` 原样退出） |
| IPA 字节数 | **926083** |
| IPA SHA-256 | `264e3518c38cc3d4dfd2a00cdac828fed44878e0b5caaf25237d39a11d973b52` |

---

## 各子项 CI

| 子项 | 提交 | CI | 结论 | XCTest | IPA 字节 |
|---|---|---|---|---|---|
| A chrome 几何 | `9fd9d5432aa9df5134895ce02d0f31a8ac4bd815` | #200 | **failure** | 546 / 6 | — |
| A 补改硬编码 | `12cf289158b692169a02ce019ad644ef4d84609a` | **#201** | success | **546 / 0** | 900520 |
| B 标记残影 | `86b46eb22dc582e32cc5164d42bb1d84bb7a8f7d` | **#202** | success | **545 / 0** | 904671 |
| C 相簿残影 | `a9399343e473971ecfc11eab841ab7c9f95076e4` | **#203** | success | **550 / 0** | 913974 |
| D 教程动效 | `eea617a3482dec47a28e5226851871ebb52dd5e3` | **#204** | success | **554 / 0** | 926083 |

B 的测试数比 A 少 1：IC-110 C 的 5 项随其实现一并删除，B 新增 4 项，净 −1。

---

## 子项 A：chrome 几何对齐画布（含出厂值变更）

**新常量**（`S2OverlayLayout`）：`chromeRowHeight` 44 / `topRowTopInset` 3 / `bottomRowBottomInset` 8 / `chromeHorizontalMargin` 16 / `stripToBottomRowSpacing` 24；`topBarHeight` 由裸 48 改为**推导** `topRowTopInset + chromeRowHeight = 47`（名称沿用——消费方与截图等距带公式都按「顶部栏底缘」语义读它）。

**废止三个 v17 量**：`actionBarVisibleBandHeight` 22（按卡内「废止或改实」二选一取**废止**——换装后可见带即 44 触控带本身，与 `chromeRowHeight` 重合，留着必然再次过时；这同时消掉 IC-110 报告登记的「可见带高语义过时」那条背离）、`stripToActionVisibleBandSpacing` 30.7（由 24 取代，锚点从「可见图标带顶缘」改为「底排上缘」）、`topLeadingControlWidth` 88（左右已是 Ø44 圆钮，宽即行高）。

**竖向落值**（常规机型，安全区底 34）：底排下缘距视口底 **42**（画布 852 − 766 − 44 = 42，减安全区 34 得内缩 8）、上缘 **86**（画布 y=766）、中心 64；横栏底缘 **110**（画布 y=742）。锚安全区而非视口底，沿用 IC-100 v2 的选择，安全区变化时自适应。门禁 L2 由「贴安全区上沿」变为高出 8 pt，更宽松地满足。

**截图等距带公式一字未动**，`g` 随新顶缘自动重推：常规机型 `g` 由 20.8 变 **21.8**，带高 **562.4**，顶距 = 底距 = `g`，视觉锚与触控锚差仍为 `max(44,30) − 30 = 14`；「横栏—底排」24 **不参与等距**（④ 选定不变）。

**快照模型同步修正**：顶排与底排都改为「左 Ø44 圆钮 + 中胶囊 + 右 Ø44 圆钮、边距 16」，v17 的**等宽三列**假设废止——这消掉 IC-110 报告登记的第二条背离。胶囊模型给的是**可用跨度**、渲染宽随内容且居中（两侧边距对称故居中于屏），渲染只会更窄不会更宽，重叠类门禁仍成立；该边界已写进代码注释。

**视图层**：材质由 `.regularMaterial` 改 `.ultraThinMaterial`（画布指定系统深色毛玻璃，非半透明色块），横栏一并同款；图标 `chevron.backward` / `trash` / `heart(.fill)` / `clock` / `plus.rectangle.on.rectangle`；顶部胶囊主行 15pt semibold、副行 11.5pt 白 62%（用 `Color.white.opacity` 而非 `.secondary`——后者随环境浮动，对不上画布定值）；底部胶囊时钟 17pt + 文字 15pt，被两侧 `Spacer` 夹住实现宽随内容且水平居中。

**闸门 A1 未触发**：底排下缘 8 pt 由画布 42 − 安全区 34 推出，**无需新测量**；既有几何测试全部按推导式跟随，硬编码旧值逐条改写。

| 验收点 | 测试函数 |
|---|---|
| 画布常量落值与 `topBarHeight` 推导自洽 | `testIC111ALayoutAnchorsMatchCanvas` |
| 底排竖向落值对画布坐标（42 / 86 / 64 / 110、y=766、y=742、间距 24） | `testIC111ABottomRowMatchesCanvasVerticalPositions` |
| 随安全区自适应且 L2 更严 | `testIC111ABottomRowFollowsSafeArea` |
| 药丸与 chrome 行同源、画布字号 | `testIC111AChromePillMetricsEqualChromeRow` |
| 顶排三槽含居中 | `testIC111ATopElementFramesMatchCanvas` |
| 等距带在新常量下仍三段相等 | `testIC104CScreenshotFitBoxAnchorsLegacyTopWithEqualGaps`（按推导式改写后原样绿） |
| 底部排布与 L2 / 净空 | `testIC100B1BottomOverlayOrderAndAnchors`、`testIC100B1LayoutFollowsLargerBottomSafeArea`、`testIC100B7SnapshotMatchesRenderDerivations` |

### schemaVersion 说明（须决策会话知悉）

卡内指定「随 A 一次性升 7」，已照办，`schemaVersion == 7` 全仓唯一。**但按 CLAUDE.md 第六节字面，本次并非必需**：陷阱 9 四条全量扫描已先跑，结论是**本卡未增删任何 `S2CalibrationConfiguration` 字段**（`fieldNames.count` 仍 43），改的全是 `S2OverlayLayout` 的**登记制占位常量**，配置字段值集合未变。照卡升版的实际效果是让 Keychain 中的旧标定整套失效、回落出厂值——chrome 整体改版后这是想要的效果，故执行无碍；但**它会一并清掉 Lynn 已调过的参数**，这一点请决策会话确认是否为预期。

---

## 子项 B：标记残影 → 右上角垃圾桶

**替换** IC-110 C 的「飞缩略栏 + SwiftUI `keyframeAnimator`」实现。H47 判为「跟卡机了一样」，根因是逐帧推进走主线程；本版整段位移/缩放/淡出交给 **CAAnimation 族**（路径走 `CAKeyframeAnimation`，缩放与淡出各一条 `CABasicAnimation`），**主线程只在起飞与收口各参与一次**（陷阱 6）。

**参数**：总时长 **0.32 s**（卡内 300–340 ms 取中位）、scale 1 → **0.18**、opacity **0.85 → 0**；位移 easeIn、淡出 linear（卡内分别指定）。路径为二次贝塞尔，控制点 x 推到 `max(落点, 主图右缘) + 28`、y 取**起点**高度 ⟹ 离开起点时近乎水平向右甩出、再上扬收进落点，外鼓点落在主图右上外侧。

**落点** = 右上垃圾桶圆钮中心，由 `S2OverlayLayout.topElementFrames` 复算，**与 chrome 渲染同一套推导式**——A 项改了 chrome 几何，落点自动跟着走。画布落值 **(355, 84)**。

**残影 = 当前已解码图快照**：对 `presentationContentView` 取 `snapshotView(afterScreenUpdates: false)`，取渲染层现成内容，**不同步重读图**、不触发重新解码（卡内明令）。取不到就跳过残影，绝不为出动画回退到同步读图。

快照必须拍在状态变更**之前**——标记成功会立刻翻到下一张。故只在「上滑且当前张尚未标记」时预拍，结算后确有新增才起飞，没标记成功就丢弃；其余手势零开销。

**收口（陷阱 8）**：动画只挂在快照这一层；先把模型值落到终态再叠动画，故无需 `isRemovedOnCompletion = false` 撑末帧，也就没有残留层要清；完成块里 `removeAllAnimations` + `removeFromSuperview` 整层摘掉。

**主图本体不参与位移**（飞的是独立快照视图），标记后立刻可翻页。连续标记允许多枚并发，**不设上限**——IC-110 C 的 3 枚上限随该版实现一并废止，本卡未要求。

**落点同帧**：垃圾桶 spring 回弹 1 → 1.15 → 1 与角标数字滚动 +1 都由 `landedTick` 触发。为此角标**显示值**压到落点才跟上模型值；按钮启用与无障碍标签仍直读模型值、一律不滞后（`confirmationEntry` 与 `displayedBadgeText` 因此拆开）。

| 验收点 | 测试函数 |
|---|---|
| 飞行参数落在卡内区间 | `testIC111BFlightParametersMatchCard` |
| 落点与 chrome 共用推导式、合画布落值 | `testIC111BTrashCenterSharesChromeDerivation` |
| 弧线端点恒等、控制点在右外侧起点高度、「先横后纵」与右鼓、越界钳制 | `testIC111BFlightIsRightSideQuadraticWithExactEndpoints` |
| 并发计数与落点通知（含多余通知不压负） | `testIC111BCoordinatorTracksConcurrentFlightsAndLandings` |

---

## 子项 C：加入相簿残影 → 底部中胶囊

与 B **同一套机制**：`S2MarkAfterimagePresenter` 已泛化为接受路径与参数，两种残影共用同一条 CAAnimation 通道。

**参数**：总时长 **0.30 s**（卡内 280–320 ms 取中位）、scale 1 → **0.15**、opacity 0.85 → 0、位移 easeIn、淡出 linear。路径为**向下弧线**：控制点自弦中点向屏幕下方推弦长 × 0.28，与 B 的右鼓弧线方向相反。

**落点** = 底部中胶囊中心，用与 `S2OverlayLayout.snapshot` 底排**同一套表达式**复算；左右边距对称故落点水平居中。画布落值 **(196.5, 788)**。

**时序规则（④）**，`S2AlbumAfterimageGate` 纯状态机：直接点中胶囊 → **立即**起飞；**首次**经右侧选择器换新相簿 → 中胶囊先入场（淡入 + 上浮 **8 pt**、**120 ms**），**入场完成才放飞**推迟的那一枚；此后再加入**同一**相簿 → 立即路径。「首次」按相簿计，换到另一个新相簿会再入场一次。

**与 B 同屏并存、互不阻塞**：落点计数拆成 `landedTick`（垃圾桶回弹）与 `albumLandedTick`（中胶囊回弹）两条，有测试专盯互不串扰。落点回弹 1 → 1.12 → 1。

**收藏（♡）不做残影**——卡内标注未定，**未自行添加**。

| 验收点 | 测试函数 |
|---|---|
| 飞行与入场参数落在卡内区间 | `testIC111CAlbumFlightParametersMatchCard` |
| 向下弧线方向、端点恒等、零距离不产生 NaN、越界钳制 | `testIC111CAlbumFlightIsDownwardArc` |
| 落点与 chrome 底排共用推导式且居中 | `testIC111CBottomCapsuleCenterSharesChromeDerivation` |
| 入场闸门四条时序 | `testIC111CEntranceGateSequencing` |
| 两种残影落点计数互相独立 | `testIC111CAlbumAndMarkLandingsAreIndependent` |

---

## 子项 D：教程动效重做

**只重做表现层**：`S2TutorialCoordinator` 与 `S2TutorialCompletionStore` **一字未改**，有测试专门复核这条不变量。

遮罩 **55% 黑** + **聚光挖孔**：步 1/3/4 套主图、步 2 套横栏、步 5 套右上垃圾桶圆钮（④）。挖孔矩形下沉为纯函数 `S2TutorialSpotlight.targetRect`；横栏与圆钮分别取 `stripBottomFromViewportBottom` 与 `topElementFrames`，**与 chrome 同源**，A 项改了几何挖孔自动跟着走。步骤间以 **spring 移动变形**（`.animation(.spring, value: step)` 挂在遮罩上），不闪切。

**手势图示**：触点圆（**Ø26 环 + Ø14 实心**）+ 方向箭头，循环 **0.9 s/次**、沿方向位移 **40 pt** + 渐隐。用 `repeatForever` 的**属性动画**（offset / opacity），由渲染层持续推进，主线程不逐帧参与——与 B/C 取向一致，不再用 `keyframeAnimator` 步进。方向按步语义：步 1 上、步 4 下、步 3 右（标记会前进一张，故「回到刚才那张」是向右拖回）；观察/点击的步 2、步 5 无手势图示。

**提示卡**：玻璃底（`.ultraThinMaterial`）、文案沿用现行、**五点进度**、「跳过」常驻；步 5 主按钮换成蓝色「完成」，此时「跳过」移到卡片右上角仍然常驻。新增文案 key `s2.tutorial.done`（纯文本插入 xcstrings，未重排全文件）。

**教程态下确认删除不可真实触发**：垃圾桶按钮在 `tutorial.isRunning` 时禁用，故步 5 只指向入口、点不动。

**步进条件不变**：三处「等真实手势」仍由已发布状态判定，等手势的三步整层不参与命中测试，手势原样落到主图；步 2 停留 2 s 自动进。

| 验收点 | 测试函数 |
|---|---|
| 挖孔按步套目标、与 chrome 同源、三目标互不相同 | `testIC111DSpotlightTargetsPerStep` |
| 手势方向按步语义、位移向量合 40 pt | `testIC111DGestureDirectionPerStep` |
| 动效参数（55% / Ø26 / Ø14 / 0.9 s / 40 pt） | `testIC111DAnimationParametersMatchCard` |
| 步进逻辑未被表现层重做改动 | `testIC111DStepAdvanceLogicUnchanged` |

**证据分级**：D 与教程相关的断言均为**夹具驱动**，真机未覆盖（陷阱 1），由 H48 兜底。

---

## 本地门禁（本机 Windows，①）

每次提交前均跑满三门禁，**全部退出码 0**：`git diff --check` / `Scripts/selfcheck.ps1` / `Scripts/scan-hardcoded-user-visible-strings.ps1`。

---

## H48 人工判定清单（原样列出，保留给 Lynn，不代为下结论）

1. 顶/底 chrome 与系统 Photos 并排对照：圆钮/胶囊大小、位置、毛玻璃质感。
2. 截图等距带在新 chrome 下仍三段观感正确；隐藏态填满与过渡照旧。
3. 标记残影：单张与连续 5 张快标，飞垃圾桶流畅无卡顿、回弹与角标同帧。
4. 加入相簿残影：直点中胶囊立即飞；首次换新相簿等胶囊就位再飞。
5. 教程五步：聚光移动、手势循环动效、跳过与重看、步 5 只指向不真删。

---

## 停线 / 偏差 / 待补核（逐条）

### 停线

- **A1（画布未覆盖、需新测量的几何）**：**未触发**。底排下缘 8 pt 由画布 42 − 安全区 34 推出。
- **G275（失败含与本卡无关测试）**：**未触发**。#200 唯一失败项是本卡改动的底部几何断言。
- 本卡无 B/C/D 停线条款；G274（手势识别器）、G273（冻结链 / `ci.yml` / `Scripts/` / `export-format.md`）均逐条核过为零改动。

### 偏差

1. **G271 的 tip SHA 对不上**（①）：卡内 `8450c2812f34…` 在仓库中不存在，实际 `8450c28e2bec…`，前 7 位一致且身份吻合（IC-110 报告提交）。已就地停下询问，**④ 确认按实际 tip 继续**。推测成因：IC-110 收尾只回传过短 SHA `8450c28`，写卡时补全的后 33 位是臆造的。**建议后续写卡的 tip SHA 从仓库实取，或只写短 SHA。**

2. **`schemaVersion` 升 7 并非 CLAUDE.md 字面所必需**（详见 A 节「schemaVersion 说明」）：本卡未增删任何配置字段，改的是登记制常量。照卡执行，但**会清掉 Lynn 已调过的标定参数**，请确认是否为预期。

3. **残影浮层位于 chrome 之下**：两种残影都挂在 pager 的 UIKit 视图里（那里才有页面快照与 CAAnimation 的原生环境），故飞行末段会从毛玻璃 chrome **下方**掠过。因落点处不透明度已到 0，实际遮挡极短。若 H48 觉得该处观感不对，需要把残影容器提到 chrome 之上，属另一张卡的改动。

4. **`S2ChromePillMetrics` / 两个 Flight / `S2TutorialSpotlight` 等视觉常量仍散落在视图层**，不进标定登记制。若日后要纳入参数面板或规格，需要一次统一归置。本卡按「禁止新增可调参数」保持常量形态。

### 待补核

1. **卡内称上游「落文入 Decision_log 138 待记」**——本卡执行时 `Decision_log.md` 仍止于第 **136** 条，SPEC 最高仍为 **v17**（无 v18）。IC-110 报告已登记过同类问题（当时称 137 与 v18）。**卡内 ④ 内容已全文转录，执行以卡内文字为准；上游落文与本卡实装的一致性需决策会话复核。**

2. **硬编码扫描器的第三个陷阱**（本卡新踩）：**返回字符串的展示 helper 会被判为用户可见文案**。方向箭头的 SF Symbol 名原本从 `var symbolName: String` 返回，被抓成 3 条残留；改为在 `Image(systemName:)` 调用点逐个内联后通过。连同 IC-110 登记的两条（key 不能插值拼、注释里写出取文案调用的样子会被抓成真 key），**建议一并补进 CLAUDE.md 第八节**。

3. **#200 失败成因**：`testIC100B1BottomOverlayOrderAndAnchors` 里有一处旧中心值 56.0 未随推导式改写（新值 64.0），6 处报错同源一处断言。补改后 #201 全绿。教训是「按推导式改写」要连**同一测试内的多处**一起扫，不能只改报错行族。
