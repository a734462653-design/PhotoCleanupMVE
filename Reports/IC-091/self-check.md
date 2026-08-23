# IC-091 自验报告（nx-midgesture-handoff，阶段一）

## 结论（先行）

R1（探针）、R2（机制，**手段 M1**）、R3（交接窗口写入守卫）已实装。分支 `feature/ic-091-nx-midgesture-handoff` 自 `main` = `bf7bab1f8b9fea1194b57151f0beae34fa03756f` 切出，四个提交，最终被测 `bfb2b8b8973bfef85b35f7fa271f4ad437927d0a`。

**CI 用了 2 次，超出卡内给阶段一的 1 次分配（总额 3 次仍未超，剩 1 次给阶段二）。** 见下节「CI 预算」——这是需要技术负责人知情的一处偏离。

**CI 结果：CI #158 success。** 被测 `bfb2b8b8973bfef85b35f7fa271f4ad437927d0a`，XCTest **485 项、0 失败**（= 477 + 8 − 0），9 步全 success，真实退出码 `test_status=0`；IPA 780528 字节、SHA-256 `59d666e6…af03`，本地重下复核一致。

**阶段一到此停下，等 Lynn 的场景 E 三段真机录制。** 本卡的核心命题——「内层在拖动方向完全不可滚动后，UIKit 会在同一手势内把拖动交给外层分页容器」——**在模拟器夹具里无法验证**（CLAUDE.md 陷阱 1、2：夹具无法产生真实触摸序列，XCUITest 模拟手势已被明令禁止）。因此：

- G185、G186（A1～A6）、G187、G188 是**夹具与工具链层面**的结论，已在 CI 内取到。
- **M1 在真机上是否成立、交接点后 ≤ 3 帧外层是否接管（闸门 C）、交接窗口内是否仍有 `apply` 来源的外层写入（闸门 E）——全部未覆盖**，判据只能来自 H37 的三段录制。
- 闸门 A、B、D 未触发；C、E 未判定。

## CI 预算（须技术负责人知情）

卡写「三次 CI（阶段一 1 次，阶段二 2 次）」。阶段一实际用了 **2 次**：

| 运行 | 被测提交 | 结论 |
|---|---|---|
| **#157**（id `32656316578`） | `8871307e0daf9bce7fdb748c24a5f5417679be24` | failure。**485 项 1 失败**，失败点唯一：A2 里那条断言「程序驱动内层越界写入后 `contentOffset.x == maxX`」。其余 7 个新增测试与 IC-063～IC-088 既有门禁全过；结构自验与硬编码扫描两步在 CI 内亦 success |
| **#158**（id `32656803126`） | `bfb2b8b8973bfef85b35f7fa271f4ad437927d0a` | **success**。`Executed 485 tests, with 0 failures (0 unexpected)`，9 步全 success，IPA 已产出 |

失败的那一条正是卡内 A2 原文给出的前提，而实测把它推翻了（见下节）。之所以没有就此停下，是因为阶段一的交付物是**一个可安装的 CI 包**——`构建未签名应用` 与 `上传 IPA` 两步在 #157 里被 skip，没有包，H37 无从做起，卡也就推进不下去。修的是一行测试断言、产品代码零改动、原因已是①级明确，故用第 2 次跑通。**是否把剩下的 1 次留给阶段二、还是重新分配，请技术负责人定。**

## 一处被实测推翻的卡内前提（①）

卡内 A2 写：「起始距边 30 pt、程序驱动内层向边界滚动 80 pt：内层 `contentOffset.x == maxX`（**不越界**）」。

**实测（① CI #157）：不成立。** 写入 `maxX + 50` 后，内层 `contentOffset.x` 仍是 `maxX + 50`，`overshoot = 50.0`；此前已跑过一回合 `layoutIfNeeded()` 与 50 ms runloop。

归因（我自己的，不套卡内假设）：`UIScrollView.bounces` 约束的是**拖动期**的橡皮筋与减速回弹，与 `setContentOffset(_:animated:)` 的**程序写入**无关；程序写入不做范围钳制。本项目内层唯一的偏移钳制是 `bounds.didSet` 与 `applyJointCentering`，而这两处按 IC-070 R5 的设计**只钳制「内容小于视口」的那个轴**——横向内容在 Nx 下大于视口，所以横向不钳。两者叠加的结果就是 `overshoot = 50`。

这不是产品缺陷：定案要的「内层只平移到内容边界，不越界」是**拖动期**属性，由 `bounces = false` 保证；夹具产生不了真实拖动，这一条本来就落在真机侧。

处置（`bfb2b8b`，只改测试，产品代码零改动）：

1. 保留越界写入作为**探针**，断言 `contentOffset.x == maxX + 50` 且 `bounces == false`，把 UIKit 的实际行为钉进门禁——若某版 iOS 改为钳制，这一条会立刻暴露，而不是悄悄变成"一直如此"。
2. 补上本卡**真正拥有**的不变量：把内层置于 `maxX` 再跑一回合布局，断言 `contentOffset.x == maxX`——即产品的 `bounds.didSet` / `applyJointCentering` 不会把横向边界偏移改掉。
3. 「不越界」的真机判定由 A1 的 `bounces == false` 加 H37 兜底，不在夹具里冒充。

## 手段选择与理由（M1）

**选 M1：内层 pan 起手判定为水平主导时，为本次手势启用方向锁（`isDirectionalLockEnabled`），手势结束恢复。**

理由，按证据强度排列：

1. （①，卡内第一节第 3 条 / `082.txt` / E1）内层 `bounces = false` 时 UIKit **确实**会把同一手势交给外层，条件是内层「在运动方向上完全不可滚动」；实测失败的原因是手指稍斜时内层仍在竖向消耗位移，外层迟迟不接管（0.3 s / 0.8 s）。方向锁把这个条件从「取决于手指角度」变成确定量——水平主导起手的手势内，内层的竖向通道被关掉，到横向边界即完全不可滚动。**M1 直接消除已被实测定位的那一个变量，不引入新机制。**
2. （④ 定案）「接管后直到手势结束，内层 `contentOffset` 不再变化（竖向分量丢弃）」是定案原文。方向锁正是「丢弃竖向分量」的原生实现，不需要 App 拦截或改写任何几何。
3. M2（内层到边时取消本次内层 pan）要赌「外层 pan 还能接住剩余触摸并从当前位置续上」。项目里没有任何一条实测支持这一点；取消识别器后外层 pan 的位移基准也可能跳变，与「外层偏移逐帧单调跟随、无 > 2 pt 反向跳变」的定案直接冲突。**在只有三次 CI、且真机才是唯一判据的前提下，选证据链更短的那条。**
4. M1 的实现面积小：一个 `UIScrollView` 布尔属性 + 手势级置位 / 清零，不触及捏合接管、双击、`bounds.didSet`、页窗口（闸门 A 未触发），也不需要新增标定参数或改出厂值（闸门 D 未触发）。

**禁止项未触碰**：内层 `bounces` 全程 false；`isDirectionalLockEnabled` **只在本次手势内**为真（静止态、竖向主导起手、1x 下恒为 false），不是被禁止的「全局方向锁」；IC-082 R3 删除的自定义投影未恢复。

**M1 成立与否是③，本卡不能自证。** 验证方法即 H37 的三段录制：交接点（事件 `nxHandoffPoint`）之后 ≤ 3 帧内外层 `pagingIsTracking` 或 `pagingIsDragging` 是否变真、`pagingContentOffsetX` 是否随手指单调变化；逐帧字段 `zoomDirectionalLock` 直接给出方向锁在该帧的实际取值。

## 对卡内第一节第 2 条的处理

卡内第一节第 2 条把「两段录制均无 `nxInnerPanDecision` 事件」解读为「拒绝内层 pan 的是 UIKit 自身的 `gestureRecognizerShouldBegin`」（Decision_log 第 125 条把这条归因标为③）。

我不采用这个归因，也不与它对着干，而是把它当成一个更强的事实来用：**在 IC-089 的两段录制里，`S2NativeZoomScrollView.gestureRecognizerShouldBegin` 这个钩子一次都没有产出事件——包括起始不贴边、内层确实平移了的那些拖动。** 起始不贴边时 IC-089 的规则一定会返回 `innerShouldBegin = true` 并记录一条事件，可录制里没有。所以更保守的读法是：**这个钩子在真机上未必被调用**，不能把 M1 的方向锁只挂在它上面。

因此 M1 接了两个钩子：`gestureRecognizerShouldBegin`（最早时机）与内层 pan 识别器的 `.began` 回调（一定会到，且 `.began` 时的位移是本次手势的权威起始向量）。两者调用同一个判定入口，事件 `source` 字段区分实际由哪个发出。**这条本身也是阶段二要读的数据**：三段录制里 `nxInnerPanDecision` 的 `source` 分布，直接给出「该钩子在真机上是否被调用」的①级结论。

## 输入、继承与范围

- 任务卡 `IC-20260823-091-nx-midgesture-handoff`；上游证据 Lynn 2026-08-23 真机 H31 v3（CI #150 包）、场景 E 录制 `6.txt` / `Q2.txt`、Lynn Q1 定案、Decision_log 第 124/125 条、`Reports/IC-089/self-check.md`（分支上，未合并）。
- 开工前 `git status --porcelain` 为空；HEAD 在 `feature/ic-090-strip-corner-pinch-end`，按下发语从 `bf7bab1` 切新分支。
- **未基于 `feature/ic-089-nx-edge-bounce`**：`S2NxEdgeHandoffRule` / `S2NxInnerPanDecision` / `recordNxInnerPanDecision` 以新提交复制，未 cherry-pick 任何提交（`git log bf7bab1..HEAD` 四个提交全部为本卡新作）。
- 范围边界：只改 `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`、`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`、`Reports/IC-068/export-format.md`。`S2Calibration.swift`、`S2StateMachine.swift`、`S2View.swift`、`Localizable.xcstrings`、`Scripts/`、`ci.yml`、SPEC、Decision_log 一个未动。未新增 XCUITest，未合并主干，未 force push，未改写历史，未动 `feature/ic-089-nx-edge-bounce`。

## 提交清单

| 提交 | 归属 | 内容 |
|---|---|---|
| `9897b74` | R1 | 逐帧五字段（`pagingIsTracking` / `zoomIsTracking` / `zoomIsDragging` / `zoomPanState` / `zoomDirectionalLock`）、四类事件入口、`外层setContentOffset` details 追加两项、外层 `scrollViewWillBeginDragging` 埋点；纯判定类型与规则（不接线）；`export-format.md` 追加一节。零行为变化 |
| `3a450fb` | R2+R3 | M1 方向锁与五处清零、交接点判据与交接窗口、`apply` / `layoutNativePages` 窗口内跳过外层偏移写入；A1～A6 断言 |
| `8871307` | R2 稳健性 | `.began` 无条件重算判定，删除「本次手势已判定」标志（见下） |
| `bfb2b8b` | 测试修正 | A2 被推翻前提的处置（见上文「一处被实测推翻的卡内前提」），产品代码零改动 |

R3 与 R2 同提交：R3 的守卫读 R2 的 `isNxHandoffWindowOpen`，单独 cherry-pick 不能编译。卡允许 R1+R2+R3 分 2～3 个提交。

`8871307` 修的是我自己在 `3a450fb` 里留的一个残留风险：原设计用一个「本次手势已判定」标志让 `.began` 只在 `shouldBegin` 未判定时补一次。若 `shouldBegin` 判定后手势最终未 `began`（识别器直接转 `.failed`，UIKit 不发 action），标志与方向锁都会残留；下一次手势若恰好走不到 `shouldBegin`，补判定又被标志挡住，陈旧的方向锁就会落到竖向主导的手势上，违反「竖向主导起手：内层二维自由平移」。改为 `.began` 无条件重算后，跨手势残留不再可能，手势级状态只剩方向锁一项。

## 逐条验收门禁

| 门禁 | 结果 | 对应测试函数与证据 |
|---|---|---|
| **G185** R1 字段与事件逐条存在 | 满足① | `testIC091G185SceneEHandoffProbeFieldsAndEvents`：头部字段声明行 = 既有 22 项原序 + `pagingIsTracking,zoomIsTracking,zoomIsDragging,zoomPanState,zoomDirectionalLock`；真实采样行含五个新字段且逐项等于当次内 / 外层滚动视图的真实读数（`XCTAssertEqual(last.pagingIsTracking, paging.isTracking)` 等，非常量）；四类事件 details 原文断言（`nxInnerPanDecision` 含 `engagesDirectionalLock`、`nxHandoffPoint`、`nxHandoffWindow` open/close 各一、外层 `scrollViewWillBeginDragging` 含 `层级=外层`）；`外层setContentOffset` details = `x=…；animated=false；outerIsTracking=false；outerIsDragging=false`；停止录制后四个入口零副作用（记录数不变）。`export-format.md` 只增不删：`git diff bf7bab1..HEAD -- Reports/IC-068/export-format.md` 为 33 增 0 删（`8871307` 改的那 1 行是本卡自己新增的行），格式版本仍为 1 |
| **G186** A1～A6 | 满足①（A1～A6 全过） | 见下表 |
| **G187** 既有门禁 + 本地三项 | 满足① | CI 内 IC-063～IC-088 既有测试全部通过（#157 与 #158 两次均只有 A2 那一条差异）；P2（`testP2NxPanStopsAtContentBoundaryWithoutExtraMargin`）与 G154（`testIC082G154NxPagingHandsOffToOuterNativeScrollWithoutCustomWrites`）的 `XCTAssertFalse(scrollView.bounces)` / `XCTAssertFalse(inner.bounces)` **一字未改**。本地：`Scripts/selfcheck.ps1` 退出码 **0**；`Scripts/scan-hardcoded-user-visible-strings.ps1` 退出码 **0**（目录 171 / 引用 171、用户可见硬编码残留 0）；`git diff --check` 退出码 **0** |
| **G188** CI success / 计数算式 | 满足① | 计数算式：**477 + 8 − 0 = 485**（新增 8 个测试函数，删除 0 个，修改 1 行既有断言 + 1 个本卡自己的断言块） |
| **G189** 阶段二逐帧表 | 未开始 | 阶段二，需 Lynn 三段录制 |

### A1～A6

| 断言 | 结果 | 测试函数与要点 |
|---|---|---|
| **A1** Nx 内层 `bounces` / `alwaysBounce*` / `bouncesZoom` 全 false | 满足① | `testIC091G186A1NxInnerBounceFlagsRemainFalse`：`zoomScale == 2` 下四项全 false；`isDirectionalLockEnabled` 静止态 false；内层 pan 已启用。另断言外层 `pagingScrollView.isDirectionalLockEnabled == true`——那是 IC-054 起的**外层**既有配置，与本卡禁止的「内层全局方向锁」不是一回事，写进断言以免后人混淆。既有 P2/G154 未改 |
| **A2** 距边 30 pt → 驱动 80 pt → 交接点一次、窗口 open 一次；窗口内 `apply` 无写入；关窗后 `apply` 写一次 | 满足①（含修正后的探针与不变量） | `testIC091G186A2HandoffPointOpensWindowAndSuppressesApplyWrite`：起手判定 `innerShouldBegin=true`、`horizontalDominant=true`、`atEdge=false`、`distanceToEdge=30`、`engagesDirectionalLock=true`、`isDirectionalLockEnabled=true`；越界写入探针（见上文推翻节）+ 边界不变量；`noteInnerHandoffIfNeeded` 首次返回 true、再次返回 false，`nxHandoffPoint` 计 **1**、`nxHandoffWindow state=open` 计 **1**，details 含 `direction=left`、`distanceToEdge=0.000000`、`zoomDirectionalLock=true`、`outerIsTracking=false`、`outerIsDragging=false`；窗口开时 `applyNativePagerController` 后 `apply` / `layoutNativePages` 两个来源的 `外层setContentOffset` 增量 **0**；`closeNxHandoffWindow(.outerDeceleratingEnded)` 后再 `apply`，`apply` 来源写入增量 **1**。**注：这些结论在 #157 里就已经全部取到**（XCTAssert 不中断用例，只有越界那一条报错） |
| **A3** 竖向主导起手 (10, 80) 不产生交接点、内层属性同静止态 | 满足① | `testIC091G186A3VerticalDominantStartProducesNoHandoff`：判定 `horizontalDominant=false`、`distanceToEdge=nil`、`engagesDirectionalLock=false`、锁为 false；即便内层横向已在 `maxX`，`noteInnerHandoffIfNeeded` 仍返回 false、窗口未开、`nxHandoffPoint` 计 0；内层属性逐项等于新建同配置实例 |
| **A4** 五个收口点清零、内层属性同 `main` 静止态 | 满足① | `testIC091G186A4GestureScopedStateIsClearedAtEveryBoundary`，五个独立子夹具：(1) 手势结束（调 `.ended` 分支所调的同一清零入口）；(2) 翻页结算——真实路径 `scrollViewWillBeginDragging` → 外层偏移 → `scrollViewDidEndDecelerating`，断言 `currentIndex + 1`、窗口已关、新旧两页内层属性均同静止态；(3) 双击——真实路径 `handleDoubleTap(on:at:)`；(4) 捏合开始——真实路径 `scrollViewWillBeginZooming(_:with:)`；(5) 复位 1x——`applyNativeState(scale: 1, …)` 经 `updatePanAvailability`。「同 `main` 静止态」的实现方式：与**新建的同配置 `S2NativeZoomScrollView`** 逐项比对（`bounces` / `alwaysBounce*` / `bouncesZoom` / `isDirectionalLockEnabled` / `isPagingEnabled` / `delaysContentTouches` / `contentInsetAdjustmentBehavior` / 两个指示器 / `minimumZoomScale`）——参照实例走的是与产品同一条 `configureNativeZoom`，本卡对该函数只加了一个 target、未改任何属性值，故等价于 `main` 的静止态取值 |
| **A5** M1 方向锁只作用于本次手势 | 满足① | `testIC091G186A5DirectionalLockIsScopedToOneGesture`：水平主导起手（不贴边）→ 锁为真；清零 → 假；竖向主导起手 → 始终为假 |
| **A6** 贴边起手 (−80, 40) 判定与 IC-089 相同、不进新路径 | 满足① | `testIC091G186A6EdgeStartKeepsIC089Decision`：`innerShouldBegin=false`、`horizontalDominant=true`、`atEdgeInDragDirection=true`、`distanceToEdge=0`；`engagesDirectionalLock=false`、`isDirectionalLockEnabled` 保持 false；事件 details 前缀 `innerShouldBegin=false；horizontalDominant=true；atEdgeInDragDirection=true；distanceToEdge=0.000000；` 与 IC-089 逐字一致（新增项只追加在末尾）；不产生 `nxHandoffPoint` |
| 纯函数边界 | 满足① | `testIC091G185HandoffRuleBoundaries`：容差 0.5 pt 两侧（499.5 贴边 / 499.4 不贴边）、零位移退回速度、水平 == 竖向不算主导、内容窄于视口时两侧皆贴边、1x 不介入且不启用锁、`engagesDirectionalLock` 三种情形、`handoffReading` 在非拖动 / 1x / 非水平主导 / 零向量时返回 nil |

**以上全部标注「夹具驱动，真机未覆盖」。** 夹具用 `noteInnerHandoffIfNeeded(on:dragVector:isDragActive:)` 与 `innerPanDecision(translation:velocity:)` 两个以向量为参数的入口驱动，绕过了真实手势识别器的时序——这正是 CLAUDE.md 陷阱 1 点名的那类断言，只能由 H37 兜底。

## 闸门

| 闸门 | 状态 | 说明 |
|---|---|---|
| A 触及捏合接管 / 双击、显隐过渡 / `bounds.didSet` / 页窗口 | **未触发** | 捏合接管逻辑（`beginNativePinch` / `finishNativePinch` / `prepareForNativeZoom`）未改；`scrollViewWillBeginZooming` 只把原复合 guard 的第一项拆出以插入一行清零，判定条件逐项不变；双击 / 显隐过渡动画未改（`handleDoubleTap` 只多一行清零，在 `handleNativeDoubleTap` 之前）；`bounds.didSet` 与 `applyJointCentering` 未改；页窗口 / `retainedPageRadius` 未改 |
| B 既有几何门禁失败 | **未触发** | CI #158 里 IC-063～IC-088 的既有几何门禁 0 失败（485 项 0 失败，全量通过）。CI #157 的唯一失败是本卡自己新增的 A2 断言，不是既有门禁 |
| C 真机交接点后 ≤ 3 帧外层未接管 | **未判定** | 判据全在真机录制里，阶段一取不到。阶段二按 H37 三段数据判。若触发则停下报告，不换第三种手段 |
| D 需新增标定参数 / 改出厂值或 `schemaVersion` | **未触发** | `S2Calibration.swift` 整体 `git diff` 为空，`schemaVersion` 保持 3；`edgeTolerance = 0.5 pt` 是浮点比较容差，不进配置、不进面板、不承载任何规格语义 |
| E 交接窗口内仍有 `apply` 来源外层写入 | **未判定** | 夹具层面 A2 已断言增量为 0；真机层面要看三段录制里 `nxHandoffWindow state=open` 与 `state=close` 之间是否出现来源为 `apply` / `layoutNativePages` 的 `外层setContentOffset` |

## CI 与本地门禁

| 项 | 值 |
|---|---|
| 运行编号 | **CI #158**（id `32656803126`），工作流「iOS 构建与自验」 |
| 结论 | **success**，9 步全部 success |
| 被测提交（完整 SHA） | `bfb2b8b8973bfef85b35f7fa271f4ad437927d0a` |
| XCTest 项数 / 失败数 | `Executed 485 tests, with 0 failures (0 unexpected) in 31.290 (41.306) seconds`；`** TEST SUCCEEDED **` |
| 真实退出码 | `test_status=0`；工作流以 `set -o pipefail` 采集并 `exit "$test_status"` 原样退出，未被日志管道吞掉 |
| IPA 字节数 | **780528** |
| IPA SHA-256 | `59d666e61fa2d8c9069074813899dad75e877bd5b28732e3f06ffb7b0c85af03`（CI 报告值） |
| IPA 本地复核 | artifact `PhotoCleanupMVE-unsigned-bfb2b8b8973b`（zip 780698 字节）下载解出 `PhotoCleanupMVE-unsigned.ipa` 780528 字节，本地 `sha256sum` = `59d666e61fa2d8c9069074813899dad75e877bd5b28732e3f06ffb7b0c85af03`，**与 CI 报告值一致** |

前一次 **CI #157**（id `32656316578`）：failure，`Executed 485 tests, with 1 failure (0 unexpected)`，`构建未签名应用` 与 `上传 IPA` 两步 skipped，无产物。唯一失败点见「一处被实测推翻的卡内前提」。

本地门禁（Windows，本机无 Xcode，无法执行 XCTest 或构建 IPA）：

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0**（"结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求"） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（目录条目 171 / 产品源码引用 key 171、用户可见硬编码残留 **0**） |
| `git diff --check` | **0** |

## 人工判定项（保留给 Lynn，本报告不代为下结论）

**H37**：装阶段一 CI 包（CI #158 的 artifact `PhotoCleanupMVE-unsigned-bfb2b8b8973b`），开场景 E 录三段，每段 5 s 内完成，先开录再出手。

- (a) 放大 2～3 倍，从画面中部横拖到边**继续拉约 1/4 屏后松手**：下一张露出后弹回，不翻页，照片停在边界。
- (b) 同上但拉过半屏或快甩：翻页，新页 1x，无闪烁。
- (c) 贴边起手斜滑：立即切页、不竖向漂移（对照 IC-089 包 H31-2，不得退化）。
- (d) 双击放大 / 缩小、捏合松手：与 IC-088 包对照不得更抖（抖动根因归 IC-090）。
- (e) 1x 翻页、竖向主导拖动、上滑 / 下滑语义无回归。

三段导出文本发技术负责人。**(a)～(e) 全部未由本卡验证**；模拟器绿不代表真机成立（CLAUDE.md 陷阱 1）。

## 真机未覆盖项清单

1. **M1 是否在真机上产生同手势交接**——本卡的全部价值所在，零覆盖。判据：`nxHandoffPoint` 之后 ≤ 3 帧内 `pagingIsTracking` / `pagingIsDragging` 变真且 `pagingContentOffsetX` 随手指变化。
2. **`isDirectionalLockEnabled` 在 `gestureRecognizerShouldBegin` / `.began` 时机写入是否被 UIKit 采纳**（`UIScrollView` 何时锁定方向轴向未文档化）。判据：逐帧 `zoomDirectionalLock` 与接管期间内层 `contentOffset.y` 是否恒定。
3. **`gestureRecognizerShouldBegin` 在真机上是否被调用**。判据：`nxInnerPanDecision` 事件的 `source` 分布。
4. **交接窗口内是否真的没有 `apply` 来源的外层写入**（闸门 E）。判据：两条 `nxHandoffWindow` 之间的 `外层setContentOffset` 事件来源。
5. **「内层不越界」**——`bounces = false` 的拖动期行为。夹具已证实它管不了程序写入（见推翻节），拖动期只能真机判。
6. **松手结算的观感**（露出、弹回、翻页、无闪烁）——H37 (a)(b)。
7. **贴边起手路径未退化**——H37 (c)。本卡对该路径的改动只有「判定规则从 IC-089 复制过来」；IC-089 的数据说明真机上这条规则可能根本没被调用，因此这条路径的行为很可能与 `main` 完全一致，但这是③。
8. **双击 / 捏合不更抖**——H37 (d)。本卡在双击与捏合开始各插入一行清零（只写一个布尔），未碰动画，③认为无影响。
9. **1x 翻页、竖向主导拖动、上滑 / 下滑无回归**——H37 (e)。

## 发现但未处理的问题（按纪律只报告不修）

1. **硬编码字符串扫描脚本的豁免是按文件位置的。** `Scripts/scan-hardcoded-user-visible-strings.ps1` 在遇到 `^final class S2GeometryDiagnosticsRun` 后把标志置真且**在本文件内不再复位**，于是该行之后的所有含汉字字符串一律记为「几何诊断导出协议字段」而放行。本卡的六个交接窗口原因字符串最初写在页控制器与外层控制器里（该行之前），立刻被判为「用户可见硬编码残留」，本地门禁退出码非 0。处理方式是把它们收敛成 `enum S2NxHandoffWindowReason: String`，声明在与 `S2OnDeviceTransitionScenario` 同一段（豁免区内）——这在语义上也更对（它就是导出词表的一部分）。**但这条豁免机制本身是个陷阱**：任何新增的诊断文案只要落在那一行之前就会误报，而落在之后就无条件放行（包括真正用户可见的文案）。`Scripts/` 在本卡范围外，未修改，交技术负责人定。
2. **`apply` 每帧重进的根治仍挂账。** 本卡只做到「交接窗口内不写外层偏移」。内层每帧 `scrollViewDidScroll` → `reportNativeViewport` → `@Published` → `updateUIViewController` → `apply()` → `layoutNativePages()` 这条链一帧不少地照跑（`6.txt` 5 s 内 `updateUIView` 149 次）。Decision_log 第 125 条已挂账，另开卡。
3. **交接窗口内仍存在一条内层几何写入路径。** `layoutNativePages` 的 `canApplyNativeState` 只看内层 `isTracking / isDragging / isDecelerating / isZooming`。UIKit 交接后内层 pan 若已结束，这三个标志会变假，`applyNativeState(scale:viewportOffset:)` 就会在窗口内对内层写 `contentOffset`。因为 `reportNativeViewport` 每帧同步、写入值与当前值相同，`applyNativeState` 内的 ε 比较会跳过实际写入，**当前不产生副作用**；但这是一条窗口内未被守卫覆盖的写入路径。卡只要求「不写外层偏移」，故未处理。真机若出现接管期间内层跳动，先查这里。
4. **方向锁在一种边角情形下会跨手势残留。** 若 `gestureRecognizerShouldBegin` 判定为「内层应开始」（置锁）后手势最终未 `began` 而直接转 `.failed`，UIKit 不发 action，`.ended` 清零就不会到。`8871307` 让 `.began` 无条件重算后，下一次手势起手即被覆盖；且 Nx 下内层 pan 没有竞争识别器（`verticalSwipeRecognizer` 只在 `machine.scale == 1` 才允许开始，而 1x 下内层 pan 本就禁用），这条路径在 Nx 下应不可达（③，源码推断，未实测）。
5. **`UIScrollView` 的程序写入不受 `bounces` 钳制**——见上文推翻节。这条已升为①（CI #157 实测），并以探针形式固化在 A2 里。它同时说明：**任何"用 `setContentOffset` 模拟拖动到边界"的夹具都不能用来证明"不越界"**，IC-089 的 G156b 也在同一个坑位上（它靠 `bounces=true` 解释越界留存，但实测表明与 `bounces` 无关）。IC-089 不合并，不影响主干，只作提醒。
6. **外层 `S2NativePagingScrollView.isDirectionalLockEnabled` 自 IC-054 起就是 `true`。** 那是外层分页容器的既有配置，与本卡范围外条款「禁止全局 `isDirectionalLockEnabled`」所指的**内层** Nx 平移不是同一件事。A1 里显式断言了这一点以免后续误改。
7. **`nxInnerPanDecision` 一次手势现在最多两条。** 两个钩子各一条，`source` 区分。这是有意的——它把「真机上到底哪个钩子被调用」变成导出文本里可直接读出的事实。`export-format.md` 已写明。

## 报告提交方式

阶段一的产品与测试提交已推送并触发 CI；本报告与变更清单在拿到 CI #158 结论后，以**同一分支的一个 docs 提交**追加（只含 `Reports/IC-091/`，命中 `paths-ignore`，不触发 CI）。不跨卡回填。
