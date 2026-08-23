# IC-089 自验报告（IC-082 v3 R4：nx-edge-bounce）

## 结论（先行）

R4 完成，CI 一次通过（1/2）。分支 `feature/ic-089-nx-edge-bounce` 自 `main` = `bf7bab1`（IC-088 合并后）切出，一个产品提交，被测 `7178de44ece5d1d802d5be7ab3deea1e15a1cef7`。CI #150 success：XCTest **479 项、0 失败**（= 477 + 2 新增 − 0 删除），9 步 success（`test_status=0`），IPA 774263 字节，SHA-256 本地复核一致。

实现（结果层）：
- **起始不贴边**：内层 `bounces` 在 Nx 下为 true（1x 仍 false；`alwaysBounce*`、`bouncesZoom` 始终 false），内层平移到内容边界后继续拖动由 UIKit 原生橡皮筋越界、松手回弹；因内层在回弹而非"不可滚动"，外层不接管、不翻页；竖向分量照常平移（竖向内容大于视口时同样原生回弹）。
- **起始贴边**：内层 pan 的起始判定走新增纯函数 `S2NxEdgeHandoffRule.innerPanDecision`——水平分量占主导且缩放后内容在拖动方向的边界与视口边界距离 ≤ 0.5 pt → `gestureRecognizerShouldBegin` 对内层 `panGestureRecognizer` 返回 false，内层全程不跟踪该手势，外层分页容器立即接管，竖向分量因此被丢弃；手势结束未翻页时内层偏移自然保持接管前值。
- 捏合接管、双击、`bounds.didSet` 钳制、1x 行为未改（闸门 D 未触发）；IC-070 G75/G76 与 IC-069 G53～G58 在 #150 全过（闸门 E 未触发）。

两条既有断言按 v3 定案更新：`testP2Nx…` 与 `testIC082G154…` 原断言 Nx 下 `bounces == false`（R3 时的实现细节），现改为 true 并补 `alwaysBounce*`/`bouncesZoom` 为 false。

H31（v3 复测）留 Lynn；回弹曲线、接管时机与"手指斜滑不竖向漂移"为真机判定项。

## 输入、继承与范围

- 任务卡 IC-20260822-082 v3 R4；Lynn 2026-08-23 真机 H31 数据（`082.txt`：贴边后 x 固定 320.67、y 367→284 漂移 0.3 s 外层才接管）；E1/E2 数据（R3 已用）。
- 开工前 `git status --porcelain` 空，HEAD = `main`@`bf7bab1`。
- 范围边界：改动 `S2NativePhotoPager.swift`（新增 `S2NxInnerPanDecision`/`S2NxEdgeHandoffRule`；`S2NativeZoomScrollView` 增 `lastInnerPanDecision`、`updatePanAvailability` 同步 `bounces`、`gestureRecognizerShouldBegin` 覆写、`innerPanDecision(translation:velocity:)`；诊断协调器增 `recordNxInnerPanDecision`）、一个测试文件、`Reports/IC-068/export-format.md` 只追加一节。未改 `edgePaging*` 出厂值、未新增参数；未改 1x 翻页、页窗口、图片请求、横栏、操作条、标记、`pinchMaxScale`；未改 `bounds.didSet`、捏合接管、双击/显隐过渡；未新增 XCUITest；未改 SPEC、Decision_log、`Scripts/`、`ci.yml`；未合并主干。

## 根因归因与实测

卡内对 H31 ② 的描述（贴边后内层竖向跟动、外层迟迟不接管）与源码一致（①）：R3 后内层 `bounces=false` 但 pan 在 Nx 下启用且无方向锁，斜向拖动时内层仍能竖向滚动，UIKit 只在内层在手势方向完全不可滚动时才交接给外层——`082.txt` 中 y 漂移到 284 后外层才接管，正是内层竖向到界的时刻（②，单样本）。R4 以"起始贴边且水平主导时内层 pan 不开始"消除这一窗口；该行为在夹具中只能验证判定函数与 `bounces` 状态，UIKit 真实交接时机留 H31。

## 提交清单

| 提交 | 归属 | 内容 |
|---|---|---|
| `7178de4` | R4 | 产品实现 + 新增 2 个测试 + P2/G154 断言更新 + `export-format.md` 追加 |

## 被删除 / 被修改的测试

- 删除 0 个。新增 2 个：`testIC089G156bNxEdgeBounceAndHandoffVerticalLock`（夹具驱动）、`testIC089G156bHandoffRuleBoundaries`（纯函数）。
- 修改 2 个：`testP2NxPanStopsAtContentBoundaryWithoutExtraMargin`、`testIC082G154NxPagingHandsOffToOuterNativeScrollWithoutCustomWrites`（Nx `bounces` false → true）。计数 477 + 2 = **479**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G156b-1（起始距边界 30 pt、拖 80 pt） | 满足①（夹具驱动，真机未覆盖回弹曲线） | `testIC089G156b…VerticalLock`：Nx（s=2）内层 `bounces==true`、`alwaysBounce*==false`、`bouncesZoom==false`、pan 启用；偏移置于距右边界 30 pt，判定 `innerShouldBegin=true / horizontalDominant=true / atEdge=false / distance=30`；程序写入越界 50 pt 后 `contentOffset.x − maxX > 0`（大于视口的轴不被钳回），外层 `contentOffset` 等于静止值、`currentIndex` 不变、外层 `isDragging=false`；回到边界后 x == maxX。**松手回弹到边界由 UIKit 原生曲线完成，夹具无法驱动，留 H31** |
| G156b-2（起始贴边、向量 (80,40)） | 满足①（夹具驱动，真机未覆盖接管时机） | 同测试：贴右边界时向量 (−80, 40) 判定 `innerShouldBegin=false / horizontalDominant=true / atEdge=true / distance=0`；竖向主导 (−40, 80) → 内层开始；反向 (80, 0) → 不贴边、距离 = 内容可平移总量；外层以 `scrollViewWillBeginDragging` + 4 步偏移驱动期间内层 `contentOffset.y` 与起始相等，`setContentOffset(下一页)` + `scrollViewDidEndDecelerating` 后 `currentIndex+1`、`machine.scale==1`、旧页 `zoomScale==1` |
| G156b-3（竖向内容小于视口仍钳到 −inset） | 满足① | 同测试：翻页后新页（1x）`contentOffset.y + 40` 写入后读回 `−contentInset.top`；`testIC070G75AndG76TakeoverKeepsJointCenteringEveryFrame` passed |
| G156b-4（1x `bounces` 不变） | 满足① | 同测试：旧页复位到 1x 后 pan 禁用、`bounces==false`；新页 1x `bounces==false`；判定函数 1x 不介入（`distance==nil`）。既有 1x 断言 `testIC0…` 全过 |
| 纯函数边界 | 满足① | `testIC089G156bHandoffRuleBoundaries`：容差 0.5（499.5 贴边 / 499.4 不贴边）、左边界对称、贴右边界向右拖不贴边、水平 == 竖向不算主导、零位移退回速度、零向量内层开始、内容窄于视口（含 inset）两侧皆贴边、1x 不介入 |
| 场景 E 事件 | 满足① | 同夹具测试：`nxInnerPanDecision` 事件来源 `S2NativeZoomScrollView.gestureRecognizerShouldBegin`，两类结果的 `details` 前缀均出现；`export-format.md` 只追加一节（8 行），格式版本未递增 |
| 闸门 D | 未触发① | `git diff bf7bab1 HEAD` 中 `bounds.didSet`、`applyJointCentering`、捏合相关（`scrollViewDidZoom`/`pinch*`）无改动；竖向锁由 pan 起始拒绝实现 |
| 闸门 E | 未触发① | CI #150：`testIC070G75AndG76…`、`testIC069G53…G58` 全 passed（IC-069 门禁 G53～G60 对应这 5 个测试函数） |
| G155 | 满足① | CI #150 所有 `testIC0…` 0 失败；本地 `selfcheck.ps1` 0、字符串扫描 0、`git diff --check` 0（首跑扫描命中 1 处：新注释中带 ASCII 引号的「已平移贴边」被当作含汉字产品字符串，改为书名号后 0） |
| G156 | 满足① | CI #150（id `32634961685`）success，9 步 success；被测 `7178de44ece5d1d802d5be7ab3deea1e15a1cef7`；`Executed 479 tests, with 0 failures (0 unexpected) in 24.160 (38.965) seconds`；`test_status=0`；IPA `PhotoCleanupMVE-unsigned.ipa` 774263 字节，SHA-256 `37447cd5f8ef6f4f5727838422e31d5efa37f8bd35fa5abe5efeb64aa1864e7c`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-7178de44ece5` 本地 `sha256sum` 一致 |
| H31（v3） | 保留给 Lynn | 放大后平移撞边继续拖有回弹、松手弹回、不切页；松手后再从边界滑：外层接管切页，斜滑不竖向漂移；无闪烁；1x 翻页、捏合接管无回归。建议同时录一遍场景 E，`nxInnerPanDecision` 事件可直接看到每次拖动的判定 |

## 定案落实与取定值

- 贴边容差 0.5 pt（④ 卡内定案）。水平主导 = `|x| > |y|`（相等不算，④ 实现取定）；判定向量优先 `translation`，为零时退回 `velocity`（④ 实现取定）。
- 内容宽度 ≤ 视口时两侧皆视为贴边：水平拖动直接交外层（与决策 4 一致，④ 实现取定）。
- `bounces` 与 pan 启用状态同源（`updatePanAvailability`），随 `scrollViewDidZoom` / `configure` / 双击 / 复位路径更新。

## 报告提交方式

拿到 CI #150 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-089/`，不触发 CI）。

## 发现但未处理

1. **真机未覆盖项（③）**：(a) `gestureRecognizerShouldBegin` 拒绝内层 pan 后外层是否**立即**接管（UIKit 内部交接）；(b) Nx 下 `bounces=true` 时捏合过程中大于视口轴可能出现短暂越界（UIKit 默认），与 IC-070 钳制轴互斥，但视觉上是否可接受需真机看；(c) 起始不贴边的拖动越界后，若手指继续横向拉到很远，内层橡皮筋阻尼由 UIKit 决定。H31 兜底。
2. 判定只在 pan **开始**时做一次：起始不贴边的拖动即便中途到边再横拉也不交接（按定案"不翻页"），用户须松手后再拖——与卡定案一致，但若 Lynn 希望"到边后继续拉即可翻页"则属新定案。
3. `S2NativeZoomScrollView.gestureRecognizerShouldBegin` 覆写先调 `super`，再只对 `panGestureRecognizer` 介入；捏合与其他识别器走原逻辑。
4. 夹具中"接管期间内层 y 不变"的断言在夹具里由"无人写入"天然成立，真正的竖向锁来自内层 pan 未开始，只能真机验证。
