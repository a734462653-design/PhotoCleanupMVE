# IC-092 变更清单 v2（阶段一 + 阶段二完整替换）

分支 `feature/ic-092-nx-window-follow`，自 `feature/ic-091-nx-midgesture-handoff` = `6736f1e` 切出。阶段二在阶段一交付 tip `b933142` 之上继续，未重切、未 rebase。最终被测提交 `67bf057da5a07d2cb6801b752236d35fc99ddf79`（CI #165）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `9ed826d` | 一 · R3 | `S2NativePhotoPager.swift`、`export-format.md` | 纯类型与规则（`S2NxWindowFollowReading` / `S2NxWindowSettlement` / `S2NxWindowFollowRule`）、三个记录入口、两个关闭原因。**194 增 0 删，不接线，零行为变化** |
| `e9dfbd9` | 一 · R1 | `S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift` | 跟随基准状态、唯一写入口 `followNxHandoffWindow`、竖向抑制、让位保险、页控制器 `.changed` 驱动 |
| `4fc2522` | 一 · R2 | 同上 + `S2Calibration.swift` | 松手结算 `settleNxHandoffWindow`、结算动画期间的窗口守护、`finishNativePaging` 参数化、外层 `scrollViewDidEndScrollingAnimation`、`edgePagingTriggerVelocity` 复接线、B1～B7 |
| `c6708d0` | 一 · 测试修正 | `S2CalibrationHarnessTests.swift` | B3 的竖向偏差判据改用 `contentOffset` 读回值（CI #159 暴露的像素吸附），**产品代码零改动** |
| `b933142` | 一 · 报告 | `Reports/IC-092/` | 阶段一自验与变更清单 |
| `fdf1c79` | 二 · R4 | `S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift` | 结算动画保护：唯一写入口拦非动画写、关窗误触发忽略、几何兜底收口；E1 / E2 |
| `6aca6a8` | 二 · R5 | 五个文件 | 动量到边露出回弹、两个占位参数、`schemaVersion` 5、`export-format.md` 追加一节；E3 / E4 与计数重算 |
| `89e2cbe` | 二 · 修正 | `S2NativePhotoPager.swift`、`S2CalibrationHarnessTests.swift` | L7 期望配置补两个新实参（CI #163 编译失败单点）；**动量采样不随减速结束清除**（产品修正）；E4 判据改用读回值；一处注释的 ASCII 引号改「」 |
| `67bf057` | 二 · 修正 | `S2ImageLoadingStateTests.swift` | placeholder 计数 9 → 11（CI #164 单点失败） |

阶段二两个产品提交由「先取最终态快照 → `git stash` 回到 `b933142` → 分两步重建 → 逐字节比对回最终态」产出；比对结果五个文件全 `cmp` OK。

## 阶段二新增产品符号

| 符号 | 位置 | 说明 |
|---|---|---|
| `struct S2NxMomentumBounceReading` | 文件顶部 | 到边速度 / 峰值 / 时长 / 方向 |
| `enum S2NxMomentumBounceRule` | 同上 | `peakOffset(edgeVelocityX:pageStride:peakVelocityFactor:)` |
| `S2NxHandoffWindowReason.momentumEdge` | 导出词表段 | 新增打开原因 `动量到边` |
| `S2NativePagerViewController.noteInnerMomentumEdgeIfNeeded(on:isDecelerating:isDragActive:timestamp:)` | 外层控制器 | 动量到边判据；只读几何，触发时才写 |
| `S2NativePagerViewController.beginNxMomentumBounce(on:edgeVelocityX:movingLeft:)` | 外层控制器 | 露出回弹动作 |
| `S2NativePagerViewController.openNxHandoffWindow(on:reason:)` | 外层控制器（私有） | 手指路径与动量路径共用的开窗入口 |
| `S2NativePagerViewController.noteNxSettlementProgress()` | 外层控制器（私有） | 结算动画的几何兜底收口 |
| `isNxMomentumBounceActive` / `lastNxMomentumBounceReading` | 外层控制器 | `private(set)`，夹具与诊断读取 |
| `nxSettlementTargetOffsetX` / `hasObservedNxSettlementProgress` | 外层控制器（私有） | 几何兜底的状态 |
| `nxMomentumLastInnerOffsetX` / `nxMomentumLastSampleTimestamp` / `hasTriggeredNxMomentumBounceForDeceleration` | 外层控制器（私有） | 动量采样与防抖 |
| 记录入口 ×3 | 诊断协调器 | `recordPagingContentOffsetWriteSuppressed` / `recordNxSettlementCloseSuppressed` / `recordNxMomentumBounce` |

## 阶段二修改的既有产品代码

| 位置 | 改动 | 是否改变行为 |
|---|---|---|
| `writePagingContentOffset(_:animated:source:)` | 新增 `duringSettlementAnimation` 参数（默认 false）；结算态下的非动画写一律拦下并记事件 | 是（R4 核心） |
| `scrollViewDidEndDragging(_:willDecelerate:)` | 结算态下整段忽略并记 `nxSettlementCloseSuppressed` | 是（R4） |
| `scrollViewDidEndDecelerating(_:)` | 同上 | 是（R4） |
| `scrollViewDidScroll(_:)`（外层） | 插入 `noteNxSettlementProgress()` | 是（R4 兜底收口） |
| `settleNxHandoffWindow(on:panVelocity:)` | 进入动画态时装载几何兜底目标 | 是（R4） |
| `finishNxWindowSettlementIfNeeded()` | 清兜底状态与动量态 | 是 |
| `closeNxHandoffWindow(reason:from:)` | 同上 | 是 |
| `noteInnerHandoffIfNeeded(...)` | 开窗动作抽出为 `openNxHandoffWindow(on:reason:)` | 否（同一段代码换了位置） |
| `S2NativeZoomPageController.scrollViewDidScroll(_:)` | 追加 `noteInnerMomentumEdgeIfNeeded` 调用 | 是（R5 判据；只读，不触发时零写入） |
| `S2Calibration.swift` | 两个新字段、出厂值、`isValid`、`exportText`、登记表、`CodingKeys`、`init(from:)`、`encode`；`schemaVersion` 3 → 5 | 是（R5 参数层） |

## 占位值登记

| 参数 | 出厂值 | 规格状态 | 接线状态 | 说明 |
|---|---|---|---|---|
| `nxMomentumBouncePeakVelocityFactor` | 0.05（秒） | placeholder | effective | 峰值露出 = min(到边速度 × 本值, 0.5 × 页步距) |
| `nxMomentumBounceDurationMilliseconds` | 350 | placeholder | effective | 露出 + 弹回总时长，出回各半 |

**`schemaVersion` 由 3 递增为 5。** 卡内写「4 → 5」，本分支实际继承值是 3（4 在未并入的 IC-090 链上）；取 5 而不是 4，是为了避开 IC-090 链已用掉的 4——同版本号承载不同出厂值集合会让 Keychain 旧值跨包存活，正是 IC-087 版本门控要拦的情形。理由详见自验报告。

除这两项外，`factoryPlaceholder` 其余 43 项**零 diff**；`edgePagingTriggerVelocity`（阶段一复接线）出厂值 300 未改。两参数不上标定面板。

## 测试

- 阶段一新增 6 个：`testIC092B1SettlementRuleAndClamp`、`…B2WindowFollowMapsAndClampsOuterOffset`、`…B3WindowSuppressesVerticalDrift`、`…B4SettlementPagesOrSnapsBack`、`…B5NativeTakeoverStopsFollow`、`…B7EdgePagingVelocityIsWiredAgain`。
- 阶段二新增 5 个：`testIC092E1SettlementAnimationSurvivesSpuriousDeceleratingEnd`、`…E2PagingSettlementAnimationIsProtected`、`…E3MomentumBouncePeakRule`、`…E4MomentumEdgeOpensBounceWindow`、`…E4MomentumEdgeDoesNotTriggerAtOneX`。
- 阶段二新增测试基础设施：私有辅助 `ic092OuterWrites(_:animated:)`。
- **修改的既有断言（8 处，全部是「数字跟着事实走」，无一放宽）**：
  - `testIC074G96…`：字段 43 → 45、导出行 47 → 49、`schemaVersion` 3 → 5。
  - `testIC074G97…`：登记表 43 → 45、placeholder 9 → 11（decided 34 不变）。
  - `testIC087G171…`：版本门控的「相等」用例由 3 改为 5，保存后顶层版本 3 → 5；「不相等」用例（2、缺失）不动。
  - `testIC092B7…`：`schemaVersion` 3 → 5。
  - `testL7FactoryDefaultsMatchSystemParityDecision`：期望配置补两个新实参。
  - `S2ImageLoadingStateTests`：登记表 43 → 45、placeholder 9 → 11（decided 34 不变）。
- 删除 0 个。计数算式：阶段一 485 + 6 = 491；阶段二 **491 + 5 − 0 = 496**。
- **阶段二 CI 用了 3 次（卡内上限 2 次）**：#163 因 L7 逐字段构造漏实参编译失败、#164 因上面最后一条计数漏改失败、#165 success。两次都是「加参数后没扫全所有构造点与计数断言」，详见自验报告「CI 预算超支」一节。

## 未变更

内层 `bounces`（全程 false）、`alwaysBounce*`、`bouncesZoom`、`decelerationRate`、内层 pan 配置、`bounds.didSet` 钳制、捏合接管、双击 / 显隐过渡、页窗口（IC-079）、1x 翻页、贴边起手路径、图片请求、横栏、操作条、标记、`pinchMaxScale*`、`edgePagingTriggerDistance`（仍 unwired）、除两个新占位值外的全部出厂值；`S2StateMachine.swift`、`S2View.swift`、`Localizable.xcstrings`、`Scripts/`、`ci.yml`、`<top>/SPEC-*.md`、`<top>/Decision_log.md` 均无 diff。未新增 XCUITest。未合并主干，未 force push，未改写历史，未动 `feature/ic-089/090/091/093` 分支本体。
