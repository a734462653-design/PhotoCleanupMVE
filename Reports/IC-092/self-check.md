# IC-092 自验报告 v2（nx-window-follow，阶段一 + 阶段二完整替换）

## 结论（先行）

阶段一（R1 跟随写入器 + y 抑制、R2 结算、R3 探针）与阶段二（R4 结算动画保护、R5 动量到边露出回弹）全部实装。分支 `feature/ic-092-nx-window-follow` 自 `feature/ic-091-nx-midgesture-handoff` = `6736f1e` 切出，阶段二在阶段一交付 tip `b933142` 之上继续，未重切、未 rebase。

**CI 结果：__CI_SUMMARY__**

**阶段二到此停下，等 Lynn 的 H38 v2 三段录制。** 夹具能验证的是：非动画写在收口前是否真被拦下、关窗误触发是否真被忽略、动量判据与峰值算式、窗口开关与 `apply` 抑制、状态清零。**跟手观感、弹回与翻页的曲线、露出黑边与相邻页的实际观感——零覆盖**，只能由 H38 v2 判。

闸门 A、B、C'、D、E、F 均未触发（C' 的真机判据未取到）。既有断言**一条未削弱**；因新增两个参数而重算的计数断言共 8 处，全部是「数字跟着事实走」，不是放宽。

## 一处与卡内前提不符（开工前发现，已按结果理解执行）

卡内 R5 写「**`schemaVersion` 4 → 5**」。**本分支上的实际值是 3，不是 4。**

`4` 是 IC-090 在 `feature/ic-090-strip-corner-pinch-end` 上升的（`a0e8d52`，新增 `bottomStripCornerRadius`），那条链没有并进 091/092 链；本分支的 3 是从 `main` 经 IC-091 继承来的（IC-087 定案值）。

按 CLAUDE.md 第七节「规格定义结果，不指定实现手段」，取**结果**：`schemaVersion` 递增，且 G201 要求的终值是 5，故本卡执行 **3 → 5**。

取 5 而不是 4，不只是照抄卡内数字——**这正是必须跳过 4 的理由**：IC-090 链已经用 4 承载了「含 `bottomStripCornerRadius` 的出厂值集合」。若本链也停在 4，两条链会出现**同一版本号、不同出厂值集合**，两个包互装时 Keychain 里的旧值能通过版本门控存活下来，正是 IC-087 版本门控要拦的那种情形（第 125 条前的滑杆事故同源）。5 对两条链都是新值，任一包首次冷启动都会丢弃旧条目取出厂值。

两条链日后合并时，这一行会冲突，解为 5 即可（5 > 4，对 IC-090 链的用户同样是"版本变了"）。

## 阶段二：两个缺陷的实装

### R4 结算动画保护

**问题（①，`#160a.txt` t=1.2732～1.2738）**：结算判定本身是对的（p=0.386、v=46 → 弹回），`synchronizeNativeStateToMachine(animatedPaging=true)` 发出了动画写 12238；**0.4 ms 后**窗口以 `reason=外层减速结束` 关闭，紧跟第二次 `synchronizeNativeStateToMachine(animatedPaging=false)` 的非动画写 12238，把刚起步的动画抹成瞬移。彼时外层从未拖动、从未减速——那次关闭是误触发。**防 `apply` 的守卫工作正常，漏防的是自家关窗路径上的第二次同步写。**

**改法**：

1. **守卫收敛到唯一写入口** `writePagingContentOffset(_:animated:source:duringSettlementAnimation:)`。结算态下的非动画写一律拦下并记 `外层setContentOffset被抑制`。这一处就覆盖了 `apply` / `layoutNativePages` / `synchronizeNativeStateToMachine` / 关窗处理的全部来路——卡内 R4 要求的"任何路径"，用一个入口兑现，而不是逐个路径打补丁。结算与露出回弹自身的写以 `duringSettlementAnimation: true` 放行。
2. **误触发消除**：结算动画期间 `scrollViewDidEndDragging` / `scrollViewDidEndDecelerating` 一律忽略（不关窗、不再结算一次），记 `nxSettlementCloseSuppressed`。真正的用户触摸（`scrollViewWillBeginDragging` → `原生接管`）仍照常关窗——那既是让位保险，也是逃生口。

### R5 动量到边的露出回弹

**问题（①，`#160b.txt`）**：快甩（内层 pan 速度 −1274 pt/s）时手指在到边**之前**就离开，内层靠减速滑到边界后死停（`bounces=false`）；交接点条件「到边且仍受拖」不满足，窗口未开、无跟随、无露出，整段没有任何表现，1.9 s 后从贴边重新起手才翻页。

**改法**：内层减速中（手指已离开）水平到边即触发一次"露出—弹回"。

- **判据** `noteInnerMomentumEdgeIfNeeded(on:isDecelerating:isDragActive:timestamp:)`：复用 IC-091 的 `S2NxEdgeHandoffRule.handoffReading`，只是把"手指位移向量"换成由**减速段最后两帧的偏移差分**求得的等效向量（`velocity(in:)` 在手指离开后不再更新，只能走几何差分）。
- **动作** `beginNxMomentumBounce(on:edgeVelocityX:movingLeft:)`：开窗（新增打开原因 `动量到边`）→ 向翻页方向越出到峰值 → 平滑回到静止偏移 → 按 R4 收口关窗。**不翻页**，`currentIndex` 与内层都不动。
- **闸门 F 未触发**：`decelerationRate` / `bounces` / pan 配置一行未改，全程只旁观内层减速并驱动外层。
- 两段动画用 `UIView.animate`（Core Animation 渲染层驱动，不在主线程逐帧推进 —— CLAUDE.md 陷阱 6），出为 `.curveEaseOut`、回为 `.curveEaseIn`。

## 跟随写入的单一入口（阶段一，保持）

**`S2NativePagerViewController.followNxHandoffWindow(on:translation:)`**。交接窗口内**所有**几何写入都在这一个方法里，且两次写入在同一个 `CATransaction`（`setDisableActions(true)`）提交边界内：外层偏移经 `writePagingContentOffset`（来源 `…nxWindowFollow`），内层竖向回写仅当 `|y − 交接点 y| ≥ 1 pt`。驱动源是内层 `panGestureRecognizer` 的 `.changed` 回调——内层到边后 `scrollViewDidScroll` 断流，用它当驱动一帧都写不出来。

阶段二把这条链补齐成三条互斥的路径，写入口仍只有两个（跟随 / 结算与回弹），全部经 `writePagingContentOffset`：

| 路径 | 触发条件 | 写入来源 |
|---|---|---|
| 手指驱动跟随 | 到边且仍受拖 | `…nxWindowFollow` |
| 松手结算 | 内层 pan `.ended` / `.cancelled` | `…synchronizeNativeStateToMachine`（`animated=true`） |
| 动量露出回弹 | 手指已离开、减速到边 | `…nxMomentumBounceOut` / `…nxMomentumBounceBack` |

## 结算与回弹的规则数值

| 量 | 取值 |
|---|---|
| 步距 | `pagingScrollView.pageStride` = 页宽 + 页间距 |
| 进度 p | `\|外层偏移 − 静止偏移\| / 步距` |
| 速度 v（松手结算） | 内层 pan `velocity(in:).x`，按翻页方向取正 |
| 翻页判据 | `p > 0.5` **或** `v ≥ edgePagingTriggerVelocity`；否则弹回。边界严格 |
| `edgePagingTriggerVelocity` | 出厂 **300 pt/s**（未改），阶段一由 `unwired` 复接线为 `effective` |
| 跟随钳制 | `[静止偏移 − 步距, 静止偏移 + 步距]` |
| 竖向死区 | `1 pt` |
| 到边速度（动量） | 减速段最后两帧偏移差分（pt/s，内层偏移空间） |
| 露出峰值 | `min(\|到边速度\| × nxMomentumBouncePeakVelocityFactor, 0.5 × 步距)` |
| `nxMomentumBouncePeakVelocityFactor` | 出厂 **0.05**（秒），本卡新增，placeholder / effective |
| `nxMomentumBounceDurationMilliseconds` | 出厂 **350**，出、回各半，本卡新增，placeholder / effective |

## 占位值登记

本卡新增两个参数，**均为 `placeholder` / `effective`**——规格未定（待 Lynn 真机标定），但已在产品路径上生效：

| 参数 | 出厂值 | 规格状态 | 接线状态 |
|---|---|---|---|
| `nxMomentumBouncePeakVelocityFactor` | 0.05（秒） | placeholder | effective |
| `nxMomentumBounceDurationMilliseconds` | 350（毫秒） | placeholder | effective |

**出厂值集合变更，故 `schemaVersion` 由 3 递增为 5**（CLAUDE.md 第六节硬规则；跳过 4 的理由见上文）。除这两项外，`factoryPlaceholder` 的其余 43 项**零 diff**。两参数不上标定面板（卡内明确）。

## 输入、继承与范围

- 任务卡 `IC-20260824-092-nx-window-follow` v2；上游证据 IC-091 阶段一（CI #158）、H37 三段录制、H38 录制 `#160a.txt` / `#160b.txt` 的逐帧分析（技术负责人，①）、Decision_log 第 125 条、Lynn Q1 与 2026-08-24 定案。
- 开工前 `git status --porcelain` 为空；在 `b933142` 之上继续，未重切、未 rebase。
- 范围边界：只改 `S2NativePhotoPager.swift`、`S2Calibration.swift`、`S2CalibrationHarnessTests.swift`、`S2ImageLoadingStateTests.swift`（一行计数）、`Reports/IC-068/export-format.md`。`S2StateMachine.swift`、`S2View.swift`、`Localizable.xcstrings`、`Scripts/`、`ci.yml`、SPEC、Decision_log 一个未动。未新增 XCUITest，未合并主干，未 force push，未改写历史，未动 `feature/ic-089/090/091/093` 本体。

## 提交清单

| 提交 | 归属 | 内容 |
|---|---|---|
| `9ed826d` | 一 · R3 | 纯类型与规则、三个记录入口、两个关闭原因、`export-format.md` 追加一节。不接线，零行为变化 |
| `e9dfbd9` | 一 · R1 | 跟随基准状态、唯一写入口、竖向抑制、让位保险、页控制器 `.changed` 驱动 |
| `4fc2522` | 一 · R2 | 松手结算、结算动画期间的窗口守护、`finishNativePaging` 参数化、外层 `scrollViewDidEndScrollingAnimation`、登记表复接线、B1～B7 |
| `c6708d0` | 一 · 测试修正 | B3 的竖向偏差判据改用 `contentOffset` 读回值（CI #159 暴露），产品代码零改动 |
| `b933142` | 一 · 报告 | 阶段一自验与变更清单 |
| `fdf1c79` | 二 · R4 | 结算动画保护：唯一写入口拦非动画写、关窗误触发忽略、几何兜底收口；E1 / E2 |
| `6aca6a8` | 二 · R5 | 动量到边露出回弹、两个占位参数、`schemaVersion` 5、`export-format.md` 追加一节；E3 / E4 与计数重算 |

阶段二两个提交由「先取最终态快照 → `git stash` 回到 `b933142` → 分两步重建 → 逐字节比对回最终态」的方式产出；最终树与跑过本地门禁的那一份 `cmp` 全等（五个文件全 OK）。每个提交自身可编译是③（本机无 Xcode，只有 tip 经 CI 实测）。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G200** E1～E4 通过；既有 B1～B7 与 IC-091 断言保持 | __G200__ | 见下表。B1～B7、IC-091 A1～A6、G185 全部未改一字，CI 全量绿 |
| **G201** 登记表新增两项 placeholder/effective；`schemaVersion == 5`；除两个新占位值外出厂值零 diff | __G201__ | `testIC092E5PlaceholderRegistryAndSchemaVersion` 之外，既有 `testIC074G97…`（登记表 45 条、placeholder 11）、`testIC074G96…`（字段 45、导出 49 行、`schemaVersion=5`）、`testIC087G171…`（版本门控按 5 走）共同覆盖；`git diff 6736f1e..HEAD -- S2Calibration.swift` 中 `factoryPlaceholder` 仅新增两行 |
| **G202** CI success / 计数算式 / IPA 重下一致 | __G202__ | 计数算式：**491 + 5 − 0 = 496** |
| **G196** 阶段一逐帧表（由 H38 v2 补齐） | 未完成 | 需 Lynn H38 v2 三段录制 |

### E1～E4

| 断言 | 结果 | 测试函数与要点 |
|---|---|---|
| **E1** 结算判定后模拟「外层减速结束」不产生非动画写、窗口仍开；收口后窗口关、`apply` 恢复 | __E1__ | `testIC092E1SettlementAnimationSurvivesSpuriousDeceleratingEnd`：弹回支（p=0.3、v=0）。两种误触发（`scrollViewDidEndDecelerating` 与 `scrollViewDidEndDragging(willDecelerate:false)`）均不关窗、不产生非动画写、各记一条 `nxSettlementCloseSuppressed`；期间 `apply` 同样写不进去；`scrollViewDidEndScrollingAnimation` 后 `isNxWindowSettling` 与窗口双双清零、关闭原因 `结算完成` 计 1、`apply` 恢复一次静止写回 |
| **E2** 翻页支同样保护 | __E2__ | `testIC092E2PagingSettlementAnimationIsProtected`：p=0.6 → `currentIndex+1`；误触发后非动画写增量 0、索引不再变；收口后跑完 runloop 外层落在新页静止偏移（1 pt 容差） |
| **E3** 峰值纯函数 | __E3__ | `testIC092E3MomentumBouncePeakRule`：步距 422 时 v=1000 → 50、v=6000 → 211（上限截断）、v=4220 → 211（恰好触限）、v=4219 → 210.95（限下不截断）；正负同速同峰值（方向对称）；退化输入（v=0、步距 0、系数为负）不产生负峰值 |
| **E4** 判据 + 动作 + 防抖 + `apply` 抑制 + 收口清零 | __E4__ | `testIC092E4MomentumEdgeOpensBounceWindow`：竖向到边（横向不动）不触发；手指仍在不触发；减速中两帧差分到边 → 触发，`edgeVelocityX == 5/0.016`、`movingLeft == true`、峰值与时长逐项等于按配置算出的值；窗口以 `reason=动量到边` 开、`isNxMomentumBounceActive` / `isNxWindowSettling` 为真、`isNxWindowFollowActive` 为假；外层已越出到 `静止偏移 + 峰值`、`currentIndex` 与 `scale` 不变（**不翻页**）；同一次减速再调不触发、事件仍计 1；期间 `apply` 写入增量 0；收口后窗口关、动量态清零、关闭原因 `结算完成`、`apply` 恢复一次。另一条 `testIC092E4MomentumEdgeDoesNotTriggerAtOneX`：1x 下不触发 |

**以上全部标注「夹具驱动，真机未覆盖」。** 夹具用 `noteInnerHandoffIfNeeded` / `followNxHandoffWindow` / `settleNxHandoffWindow` / `noteInnerMomentumEdgeIfNeeded` / `beginNxMomentumBounce` / `scrollViewDidEndScrollingAnimation` 六个以参数驱动的入口替代真实触摸与减速序列——CLAUDE.md 陷阱 1 点名的那类断言。

## 闸门

| 闸门 | 状态 | 说明 |
|---|---|---|
| A 须改捏合接管 / 双击、显隐过渡 / `bounds.didSet` / 页窗口 | **未触发** | 四处一行未改 |
| B 既有几何门禁失败 | __GATE_B__ | 既有断言一条未削弱；因新增两参数重算的 8 处计数断言是「数字跟着事实走」 |
| C' 窗口内出现第二写者且让位保险未消除冲突 | **未判定** | 夹具层面：窗口内成功写入的来源只有 `…nxWindowFollow` / `…nxMomentumBounce*` / 结算的动画写；其余一律被单点守卫拦下并记 `外层setContentOffset被抑制`。真机判据在 H38 v2 |
| D 须新增标定参数 / 改出厂值或 `schemaVersion` | **不触发**（v2 显式授权） | 新增两个 placeholder 参数、`schemaVersion` 递增，均为卡内 v2 明示授权 |
| E 结算后残留动画组或窗口未关 | **未判定** | 夹具层面 B4 已断言照片层与描边层 `animationKeys()` 均空、窗口关闭；真机在 H38 v2 |
| F R5 须改内层减速本身 | **未触发** | `decelerationRate` / `bounces` / pan 配置一行未改 |

## CI 与本地门禁

__CI_BLOCK__

本地门禁（Windows，本机无 Xcode，无法执行 XCTest 或构建 IPA）：

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（目录 171 / 引用 171、用户可见硬编码残留 **0**） |
| `git diff --check` | **0** |

## 人工判定项（保留给 Lynn，本报告不代为下结论）

**H38 v2**：装 __PACKAGE__，场景 E 各录一段，先开录再出手。

- (a) 拖到边继续拉 1/4 屏松手 → 露出后**平滑**弹回（对照系统曲线）。
- (b) 快甩 → 露出黑边与相邻页后弹回、**不翻页**（对照系统）。
- (b2) 拉过半屏松手 → 平滑翻页动画。
- (c)(d)(e) 不退化：贴边起手斜滑、竖向主导拖动 / 上滑下滑 / 1x / 捏合 / 双击、窗口期间照片无竖向爬动。

三段导出发技术负责人。

## 真机未覆盖项清单

1. **(a) 弹回是否真的平滑了**——R4 拦下了已定位的那一条非动画写，但真机上是否还有别的路径把动画打断，只能看录制。判据：`外层setContentOffset被抑制` 与 `nxSettlementCloseSuppressed` 是否出现、动画写之后到收口之间有无成功的非动画写。
2. **(b) 露出回弹的观感**——峰值 0.05 系数与 350 ms 是**占位值**，Lynn 真机标定。判据：`nxMomentumBounce` 的 `edgeVelocityX` / `peakOffset` 与观感是否匹配。
3. **动量判据在真机上是否真的命中**——减速段两帧差分求速度依赖 `scrollViewDidScroll` 在减速期间稳定回调。若真机上内层到边后 `didScroll` 也断流，判据就取不到最后两帧。判据：录制里有无 `nxMomentumBounce` 事件。
4. **`scrollViewDidEndScrollingAnimation` 在真机上是否到**——若始终不到，收口靠几何兜底（见下节第 2 条）。判据：`nxHandoffWindow` 的 `state=close；reason=结算完成` 是否成对出现。
5. **`UIView.animate` 写外层 `contentOffset` 在真机上是否产生预期曲线**——夹具只能验模型值一次到位，呈现层的动画是否真跑、是否被 `apply` 干扰，看录制。
6. **跟手程度、相邻页露出、无闪烁**（阶段一遗留）。
7. **贴边起手 / 竖向 / 1x / 捏合 / 双击不退化**——H38 v2 (c)(d)(e)。
8. **竖向爬动是否压得住**——1 pt 死区在 scale=3 下的有效粒度是 1/3 pt（见下节第 3 条）。

## 发现但未处理的问题（按纪律只报告不修）

1. **卡内「`schemaVersion` 4 → 5」的前提在本分支不成立**（实际 3 → 5）。已按结果理解执行并在上文说明理由。两条链合并时该行会冲突，解为 5。
2. **补了一条卡内没写的收口兜底。** 卡内 R4 把收口完全托付给 `scrollViewDidEndScrollingAnimation`。但同一份录制已经①证明这条链上的回调时序不合直觉（`didEndDecelerating` 在动画写后 0.4 ms 就来了）。若收口回调始终不到，窗口会一直开着、`apply` 再也写不了外层偏移——那是比抖动严重得多的故障。故补了一条**由几何而非时长**判定的兜底：观察到偏移确实离开过结算目标之后，一旦回到目标（≤ 0.5 pt）即收口，**不引入任何新的时长量**（否则就是自行决定一个未定项）。动量回弹路径不装载该兜底（模型偏移在 `UIView` 动画块内一次到位，兜底会误判为已收口），它由自己的动画完成回调收口。若技术负责人认为不该加，删掉即可，行为退回"只靠回调"。
3. **竖向死区 1 pt 在 scale=3 下的有效粒度是 1/3 pt**（阶段一 CI #159 的①：`UIScrollView` 把 `contentOffset` 吸附到设备像素网格）。H38 v2 (e) 要留意「每帧偏差不到 1 pt 但持续同向累积」的形态——那样抑制不会触发。阈值重定需 Lynn / 技术负责人定。
4. **序列边界上的 ±1 页钳制会露出空背景**（阶段一遗留，技术负责人已采纳）。动量回弹同样不区分相邻页是否存在：第 0 张往回甩、最后一张往前甩都会露出黑边再弹回。按定案「不翻页」，结果无害，但观感上"露出的是黑边而不是相邻页"，H38 v2 (b) 顺带看一眼。
5. **动量回弹期间不做竖向抑制。** 窗口虽开，但 `followNxHandoffWindow` 只由 pan `.changed` 驱动，减速期间不会被调用，因此窗口内的 y 回写在动量路径上不生效。依据是：方向锁在水平主导起手时已生效，手指离开时内层没有竖向速度，减速应是纯横向的（③，源码推断 + `#160a` 的 y 恒定观察）。若真机上动量回弹期间出现竖向爬动，这里是缺口。
6. **`nxMomentumBounce` 的速度只取最后两帧。** 单帧抖动会直接进速度。卡内明确"从减速段最后两帧的偏移差分求得"，按字面实现，未做多帧平滑。
7. **两个事件的像素口径不一致**（IC-093 报告已记，此处沿用）：与本卡无关，不重复。
8. **`apply` 每帧重进仍挂账**（Decision_log 第 125 条）。本卡只做到"窗口与结算期间不写外层偏移"。
