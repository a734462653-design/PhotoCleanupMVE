# IC-092 变更清单（阶段一）

分支 `feature/ic-092-nx-window-follow`，自 `feature/ic-091-nx-midgesture-handoff` = `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`（被测 `bfb2b8b`，CI #158，XCTest 485/0）切出。IC-091 的探针、判定函数、方向锁、交接窗口与 `apply` 写入守卫全部保留沿用。阶段一最终被测提交 `c6708d0d7b2df9a244c56f9755a4718f76716df7`（CI #160）。首次推送的 `4fc2522` 走 CI #159，491 项 2 失败（单点：B3 里两条假设「写入的 contentOffset 会被原样保留」的断言），见自验报告。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `9ed826d` | R3 | `Features/S2/S2NativePhotoPager.swift`、`Reports/IC-068/export-format.md` | 纯类型 `S2NxWindowFollowReading` / `S2NxWindowSettlement` 与规则 `S2NxWindowFollowRule`；三个记录入口；`S2NxHandoffWindowReason` 新增两个取值；`export-format.md` 追加一节（22 增 0 删）。**不接线，零行为变化**（194 增 0 删，纯追加） |
| `e9dfbd9` | R1 | `Features/S2/S2NativePhotoPager.swift` | 跟随基准状态、唯一写入口 `followNxHandoffWindow`、竖向抑制、让位保险、页控制器 `.changed` 驱动 |
| `4fc2522` | R2 | `Features/S2/S2NativePhotoPager.swift`、`Features/S2/S2Calibration.swift`、`S2CalibrationHarnessTests.swift` | 松手结算、结算动画期间的窗口守护、`finishNativePaging` 参数化、外层 `scrollViewDidEndScrollingAnimation`、登记表复接线、B1～B7 断言 |
| `c6708d0` | 测试修正 | `S2CalibrationHarnessTests.swift` | B3 的竖向偏差判据改用 `contentOffset` 读回值——CI #159 实测 `UIScrollView` 把偏移吸附到设备像素网格（scale=3 → 1/3 pt）。**产品代码零改动** |

R1、R2、R3 各自独立提交，按 R3 → R1 → R2 排列，依赖方向单向（R1 调 R3 的记录入口；R2 复用 R1 的窗口状态），每个提交自身可编译是③（源码推断；本机无 Xcode，只有 tip 提交经 CI 实测）。`c6708d0` 是 CI #159 暴露的测试自身错误的修正，产品代码零改动。

## 跟随写入的单一入口

**`S2NativePagerViewController.followNxHandoffWindow(on:translation:)`**（`S2NativePhotoPager.swift`）。

交接窗口内**所有**几何写入都在这一个方法里，且都在同一个 `CATransaction`（`setDisableActions(true)`）提交边界内：

1. 外层偏移：经既有 `writePagingContentOffset(_:animated:source:)` 写入，`animated: false`，来源 `S2NativePagerViewController.nxWindowFollow`。
2. 内层竖向回写：`inner.setContentOffset(…, animated: false)`，仅当 `|y − 交接点 y| ≥ 1 pt`。

两次写入各自记录事件，都带页索引与资产标识（陷阱 4）。守卫顺序：窗口开 → 跟随未让位 → 是窗口页 → 外层未自行拖动。任一不满足即原样返回、不写。

**驱动源**是内层 `panGestureRecognizer` 的 `.changed` 回调（页控制器 `handleInnerPanForHandoff`），**不是** `scrollViewDidScroll`——内层到边后不再滚动，`didScroll` 在交接点之后立刻断流。

## 结算规则数值

| 量 | 取值 |
|---|---|
| 步距 | `pagingScrollView.pageStride` = 页宽 + 页间距 |
| 进度 p | `\|外层偏移 − 静止偏移\| / 步距` |
| 速度 v | 内层 pan `velocity(in:).x`，按翻页方向取正（翻下一张时手指左移，取 `-velocity.x`） |
| 翻页判据 | `p > 0.5` **或** `v ≥ edgePagingTriggerVelocity`；否则弹回 |
| `edgePagingTriggerVelocity` | 出厂 **300 pt/s**（未改），本卡由 `unwired` 复接线为 `effective` |
| 进度阈值 | `S2NxWindowFollowRule.pagingProgressThreshold = 0.5`，**严格大于**才翻页 |
| 竖向死区 | `S2NxWindowFollowRule.verticalSuppressionDeadband = 1 pt` |
| 跟随钳制 | `[静止偏移 − 步距, 静止偏移 + 步距]` |
| 目标索引 | `currentIndex + direction.indexOffset`，钳在 `orderedAssetIDs.indices` 内；越界即退化为弹回 |

边界严格：`(p=0.5, v=299)` 弹回，`(p=0.5, v=300)` 翻页，`(p=0.6, v=0)` 翻页，`(p=0.4, v=350)` 翻页，`(p=0.4, v=200)` 弹回。

## 新增产品符号

| 符号 | 说明 |
|---|---|
| `struct S2NxWindowFollowReading` | `outerOffsetX` / `translationDeltaX` / `clampedToLimit` |
| `struct S2NxWindowSettlement` | `progress` / `directionalVelocity` / `triggerVelocity` / `shouldPage` / `direction` |
| `enum S2NxWindowFollowRule` | `verticalSuppressionDeadband`、`pagingProgressThreshold`、`follow(...)`、`settlement(...)` |
| `S2NxHandoffWindowReason.settlementCompleted` / `.nativeTakeover` | 「结算完成」/「原生接管」 |
| `S2NativePagerViewController.isNxWindowFollowActive` | `private(set)`，让位后置假 |
| `S2NativePagerViewController.isNxWindowSettling` | `private(set)`，结算动画进行中 |
| `S2NativePagerViewController.lastNxWindowFollowReading` / `.lastNxWindowSettlement` | `private(set)`，夹具与诊断读取 |
| `S2NativePagerViewController.nxWindowBaseOuterOffsetX` / `…InnerTranslationX` / `…InnerOffsetY` | 私有跟随基准 |
| `S2NativePagerViewController.followNxHandoffWindow(on:translation:)` | 唯一写入口 |
| `S2NativePagerViewController.settleNxHandoffWindow(on:panVelocity:)` | 松手结算 |
| `S2NativePagerViewController.finishNxWindowSettlementIfNeeded()` | 私有，结算动画收口 |
| `S2NativePagerViewController.scrollViewDidEndScrollingAnimation(_:)` | 外层动画结束回调（新增实现） |
| 记录入口 ×3 | `recordNxWindowFollow` / `recordNxWindowVerticalSuppression` / `recordNxWindowSettlement` |

## 修改的既有产品代码

| 位置 | 改动 | 是否改变行为 |
|---|---|---|
| `noteInnerHandoffIfNeeded` | 打开窗口时多取三个跟随基准并置 `isNxWindowFollowActive` | 否（只记状态，不写几何） |
| `closeNxHandoffWindow` | 一并清 `isNxWindowFollowActive` / `isNxWindowSettling` | 否 |
| `scrollViewWillBeginDragging`（外层） | 开头加 `closeNxHandoffWindow(reason: .nativeTakeover)` | 是（让位保险） |
| `scrollViewDidEndScrollingAnimation`（外层） | 新增实现，调 `finishNxWindowSettlementIfNeeded()` | 是（结算收口） |
| `finishNativePaging()` | 增加 `targetIndex` / `animatedPaging` 两个**带缺省值**的参数；`isNxWindowSettling` 时跳过内部关窗；`synchronizeNativeStateToMachine` 转发 `animatedPaging` | 既有两条调用路径用缺省值，**行为不变**；结算路径走新分支 |
| `apply()` 的外层写入守卫 | 只加注释（结算动画期间窗口仍开，守卫顺带护住动画） | 否 |
| `S2NativeZoomPageController.handleInnerPanForHandoff` | 新增 `.changed` 分支驱动跟随；`.ended/.cancelled/.failed` 先结算再按 IC-091 语义关窗 | 是（R1+R2 主路径） |
| `S2Calibration.swift` 登记表 | `edgePagingTriggerVelocity` 由 `.unwired` 改为 `.effective`；`edgePagingTriggerDistance` 不变 | 否（登记表本身不参与运行时判定；实际接线在结算里） |

## 测试

- 新增 6 个：`testIC092B1SettlementRuleAndClamp`、`testIC092B2WindowFollowMapsAndClampsOuterOffset`、`testIC092B3WindowSuppressesVerticalDrift`、`testIC092B4SettlementPagesOrSnapsBack`、`testIC092B5NativeTakeoverStopsFollow`、`testIC092B7EdgePagingVelocityIsWiredAgain`。
- **B6 不新增断言**：卡内 B6 是「IC-091 A1～A6 与既有门禁全部保持」，由那些测试函数本身继续通过来覆盖（CI 全量绿即成立）。
- 修改 1 行（IC-067 C5 内）：`XCTAssertEqual(statuses["edgePagingTriggerVelocity"], .unwired)` → `.effective`。这是卡内显式授权的登记状态变更，**测试适配产品**。
- 新增测试基础设施：私有辅助 `ic092OpenHandoffWindow`（把内层置于横向边界并以向量 (−80, 20) 打开交接窗口）。IC-091 的 `makeIC091NxFixture` / `ic091EventDetails` / `ic091EventCount` / `ic091OuterWriteSources` 沿用。
- 删除 0 个。计数算式：**485 + 6 − 0 = 491**（CI #159 与 #160 报告的 `Executed` 数一致）。
- `c6708d0` 只改 B3 内部断言，不增删测试函数，计数不变。

## 占位值登记

本卡**未新增任何标定参数，未改任何出厂值**。`S2CalibrationConfiguration.factoryPlaceholder` 与 `schemaVersion` 的 `git diff` 均为空，`schemaVersion` 保持 **3**。`S2Calibration.swift` 的全部改动是登记表一行的 `wiringStatus` 与三行注释。

复接线不新增参数：`edgePagingTriggerVelocity` 出厂 300、`edgePagingTriggerDistance` 出厂 40 均未动，后者仍 `unwired`。

`S2NxWindowFollowRule` 里的两个常量不是标定参数、不进 `S2CalibrationConfiguration`、不进面板：
- `pagingProgressThreshold = 0.5`——④ 技术负责人在卡内取定的结算判据，随 Decision_log 记录，Lynn 可改；
- `verticalSuppressionDeadband = 1 pt`——④ 卡内取定的竖向回写死区（「y 相对交接点值偏移 ≥ 1 pt」原文）。

## 未变更

内层 `bounces`（全程 false）、`alwaysBounce*`、`bouncesZoom`、`bounds.didSet` 钳制、`applyJointCentering`、捏合接管、双击 / 显隐过渡、页窗口（IC-079）、1x 翻页、贴边起手路径、IC-091 的方向锁与交接点判据、图片请求、横栏、操作条、标记、`pinchMaxScale*`、全部出厂值与 `schemaVersion`；`S2StateMachine.swift`、`S2View.swift`、`Localizable.xcstrings`、`Scripts/`、`ci.yml`、`<top>/SPEC-*.md`、`<top>/Decision_log.md` 均无 diff。未新增 XCUITest。未合并主干，未 force push，未改写历史，未动 `feature/ic-089-*`、`feature/ic-091-*` 分支本体。
