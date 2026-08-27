# IC-100 自验报告（bottom-layout-swap）— **闸门 B 触发，停在实装前**

## 结论（先行）

**闸门 B 触发，本卡未写一行产品代码，未推 CI（消耗 0 / 3）。**

卡内定案的占位常量「操作条按钮带中心距屏幕底 **52.7 pt**」与既有门禁 **L2**（`testL2BottomOverlayFramesRespectHomeIndicator`：底部操作与照片横栏都不进入主屏幕指示条区域）**在算术上不可同时成立**，且冲突与实现写法无关——无论怎么写布局公式都差 **3.3 pt**。

这不是「绝对纵坐标按新顺序重算」可以化解的情形（B3 允许重算但**明令不得放宽阈值**），因此按闸门 B 原文停下报告。

**互换本身（自下而上：安全区 → 操作条 → 横栏）没有任何障碍**，几何模型与视图层的改法都已探明并写在下文；卡住的只有 52.7 这一个值。技术负责人裁定后可立即续做。

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空 |
| 继承提交 | `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff`（IC-097，CI #168，XCTest 497/0） |
| 目标分支 | `feature/ic-100-bottom-layout-swap`（已从 `ef9d46a` 创建） |
| 产品代码变更 | **无**。仅本目录两份报告 |
| CI | **未推送、未运行**（0 / 3） |
| 与其他会话并行 | 无。本会话未同时运行 IC-101/099 |

## 冲突的算术证明（①）

三条参数全部有据可查，不是推测：

| 量 | 值 | 出处（①） |
|---|---|---|
| 测试视口高 | 852 pt | `S2CalibrationHarnessTests.swift:7468` `overlayPhysicalSize = CGSize(width: 393, height: 852)` |
| 底部安全区 | 34 pt | `S2CalibrationHarnessTests.swift:7469-7474` `overlaySafeAreaInsets.bottom = 34`；卡内系统表亦写「安全区按系统常量」 |
| 最小触控边长 | 44 pt | `S2Calibration.swift:881` `S2OverlayLayout.minimumTouchTarget = 44`（v14 回写决策 14） |

既有门禁：

- **L2**（`S2CalibrationHarnessTests.swift:701`）：`snapshot.bottomElementFrames` 的**每一帧**都要 `maxY ≤ 852 − 34 = 818`。`bottomElementFrames = actionFrames + [stripFrame]`（`S2Calibration.swift:945`），**操作条三帧在内**。
- **L4**（`S2CalibrationHarnessTests.swift:770`）：`clickableControlFrames` 的每一帧宽高都要 `≥ 44`。该集合同样包含 `actionFrames`（`S2Calibration.swift:947`）。

推导：

```
B1 要求：操作条按钮带中心距视口底 = 52.7 pt
      ⇒ 带中心 Y = 852 − 52.7 = 799.3

L4 要求：带高 ≥ 44
      ⇒ 带 maxY ≥ 799.3 + 44/2 = 821.3

L2 要求：带 maxY ≤ 818

821.3 > 818        ⇒ 冲突 3.3 pt
```

**同时满足 L2 与 L4 的最小「距视口底」= 34 + 44/2 = 56.0 pt**，比卡内的 52.7 大 **3.3 pt**。B1 的容差是 ±0.5 pt，覆盖不了。

**与写法无关**：上式只用到「带中心距视口底」「带高 ≥ 44」「带底不越安全区」三个约束，没有引入任何布局实现细节。无论用 `padding`、`offset`、`alignmentGuide` 还是直接改 `S2OverlayLayout.snapshot`，结论相同。

**根因**：系统 Photos 的工具条**图标带**高 24.3 pt（卡内系统表），中心在 52.7 时上下沿是 40.55 / 64.85，整条都在 34 pt 安全区之上；系统的**触控区**同样越过安全区，只是不体现在可见图标上。我们的 `actionFrames` 是 **44 pt 的触控带**，比系统图标带高 19.7 pt，中心放在 52.7 就必然有 3.3 pt 落进指示条区域。**卡内把系统的「图标带中心」直接套到了我们的「触控带中心」上。**

## 已探明但未落地的实装方案（供裁定后直接续做）

### 现状（`main` = `ef9d46a`）

几何模型 `S2OverlayLayout.snapshot`（`S2Calibration.swift:888`）与视图层 `S2View.interfaceOverlay`（`S2View.swift:696`）**两处都写死了「横栏在下、操作条在上」**：

```swift
// S2Calibration.swift:917-935（模型）
let stripFrame = CGRect(
    x: safeFrame.minX,
    y: safeFrame.maxY - stripHeight,      // 横栏贴安全区底
    width: safeFrame.width,
    height: stripHeight
)
...
let actionY = stripFrame.minY - minimumSpacing - minimumTouchTarget   // 操作条在横栏上方
```

```swift
// S2View.swift:707-733（视图）
VStack(spacing: S2OverlayLayout.minimumSpacing) {
    actionBar   ...
    S2BottomStripView(...)          // 横栏在后 = 在下
}
```

互换需要**同时**改这两处，缺一会让模型与实际渲染不一致（既有门禁读的是模型）。

### 裁定后的目标几何（以 `resolvedActionBandCenterFromViewportBottom` 记待定值）

```
bandCenterY = viewportHeight − resolvedActionBandCenterFromViewportBottom
actionFrames[i].y      = bandCenterY − minimumTouchTarget / 2
actionFrames[i].height = minimumTouchTarget
stripFrame.maxY        = actionFrames[0].minY − 30.7        // 卡内第二个常量
stripFrame.minY        = stripFrame.maxY − stripHeight
```

安全区语义（卡内「安全区高于常规时操作条随安全区上移，两间距语义保持」）落成：

```
resolved = max(卡内常量, safeAreaInsets.bottom + minimumTouchTarget / 2)
```

这条公式在**方案 A** 下自动成立且不需要额外常量（见下）。

### 取 56.0 时的完整落值（测试视口 393×852、安全区底 34、横栏高 72）

| 元素 | minY | maxY | L2 上限 818 | L4 ≥44 |
|---|---|---|---|---|
| 操作条按钮带 | 774.0 | **818.0** | ✅ 恰好相切 | ✅ 44 |
| 横栏 | 671.3 | **743.3** | ✅ | — |

B1 的另一半判据同样满足：`actionBar.minY (774.0) ≥ strip.maxY (743.3) + 30.7 − 0.5 = 773.5` ✅。

**即：只要那一个值从 52.7 改成 56.0，B1～B5 与 L2/L4 全部相容，本卡可一次做完。**

## 请技术负责人裁定（两案，执行端不自行选）

### 方案 A：保 L2，把常量改为 `safeAreaInsets.bottom + minimumTouchTarget / 2`（常规机型 = 56.0 pt）

- **改动**：只改卡内第一个占位常量的值与定义方式；L2、L4、44×44 语义一律不动。
- **代价**：与系统 Photos 的可见观感差 3.3 pt（我们的触控带贴着安全区上沿，系统的图标带比安全区高 6.55 pt）。H44 的「操作条偏高/偏低」正好可以让 Lynn 判这 3.3 pt 要不要补。
- **好处**：零门禁改动，语义自洽（「按钮带紧贴安全区上沿」），且天然满足「安全区更高时随之上移」——公式本身就是安全区的函数。
- **代价的量级**：3.3 pt ≈ 10 px @3x，肉眼可辨但不显眼。

### 方案 B：保 52.7，把 L2 的判据从「触控带」改为「可见带」

- **改动**：`S2OverlayLayoutSnapshot` 需要新增一组「可见带」frame（约 24 pt 高，居中于触控带），L2 改为只约束可见带，并显式允许触控带越过安全区——**这是改门禁语义**，B3 与闸门 B 都不允许执行端自行做。
- **好处**：与系统逐像素对齐（这正是 Apple 自己的做法）。
- **代价**：动既有门禁的判据；模型要多维护一套 frame；需要一张单独的卡。

**执行端不选。** 若选 A，本卡可直接续做，无需新卡；若选 B，需要先发一张门禁改造卡。

## 逐条验收门禁

| 门禁 | 结果 | 说明 |
|---|---|---|
| **G223** B1～B5 通过；占位值登记节列出两常量与出处 | **未达成（未实装）** | B1 的 52.7 与 L2 冲突，见上 |
| **G224** CI success / 退出码 0 / XCTest 497+新增−0 / IPA 重下一致 / 本地三项门禁 0 | **未达成（未运行）** | 无产品代码变更，未推送、未触发 CI |

两条**全部未达成，原因是闸门 B 在实装前触发、按卡内要求停工，不是失败**。

## 闸门核对

| 闸门 | 触发 | 说明 |
|---|---|---|
| **A** 互换须改主图几何 / 手势路径 / 横栏运动学 / 图片请求 | **否** | 互换只涉及 `S2OverlayLayout.snapshot` 的两处 y 计算与 `interfaceOverlay` 的 `VStack` 子视图顺序；主图视口由 `S2ViewportLayout.metrics` 独立计算，浮层不参与（规格：浮层不内缩主图），横栏运动学参数在 `bottomStripMetrics`、本卡不碰 |
| **B** 任一既有门禁失败且非「绝对纵坐标按新顺序重算」情形 | **是** | L2 的失败是**值冲突**，不是坐标重算；化解它必须放宽阈值或改判据，两者 B3 与闸门 B 都禁止 |
| **C** 新增标定参数、改出厂值或 `schemaVersion` | 否 | 未改代码；`schemaVersion` 仍为 4 |

## 占位值登记

**本卡未落地任何占位值。** 卡内定案的两个登记制占位常量原样记录备查，**待裁定后随实装一并登记**：

| 常量 | 卡内值 | 出处 | 状态 |
|---|---|---|---|
| 操作条按钮带中心 → 屏幕底 | **52.7 pt**（158 px @3x） | 卡内系统实测表；`IMG_6743.MP4` 三静止帧逐像素一致（技术负责人 2026-08-28 实测，①） | **冲突，待裁定**（见「两案」） |
| 横栏底缘 → 操作条按钮带顶缘 | **30.7 pt**（92 px @3x） | 同上 | 无冲突，可原样落地 |

两者按卡内要求**不进 `S2CalibrationConfiguration`、不上面板、`schemaVersion` 不动**（同 IC-091 `edgeTolerance` 先例）。

`S2CalibrationConfiguration.schemaVersion` 仍为 **4**，未加字段、未改出厂值。

## 人工判定项

**H44 无法进行**——本卡没有产出可安装的包（无产品代码变更、无 CI 运行、无 IPA）。H44 保留到闸门 B 解除、实装完成并出包之后，由 Lynn 真机判定，本报告不代为下结论。

## 真机未覆盖项清单

1. **互换后的实际观感全部未覆盖**——顺序、量级、与系统相册并排的差异，只有真机能判。
2. **「横栏拖动不再误触系统底缘手势」未验证**——这是本卡的产品动机（Lynn 真机反馈），但横栏上移多少才够、上移后拖动手感是否变化，只有真机能判。
3. **方案 A 的 3.3 pt 差异是否可接受未验证**——正是 H44 要 Lynn 判的「操作条偏高/偏低」。
4. **横屏与特殊机型的安全区表现未覆盖**——卡内要求「安全区高于常规时操作条随安全区上移」，本机无法枚举机型。
5. **toast 位置**（H44 提到）与新排布的关系未验证——`S2FeedbackToastPresenter` 的落位依赖 `safeAreaInsets.bottom + minimumSpacing`（`S2View.swift:549`），互换后是否与操作条重叠需实测。**这一条本卡新发现，见下。**

## 发现但未处理的问题（按纪律只报告不修）

1. **toast 落位可能与互换后的操作条重叠**（本卡新发现）。`S2View.swift:549` 把反馈 toast 钉在 `safeAreaInsets.bottom + S2OverlayLayout.minimumSpacing`（= 34 + 8 = 42 pt 距视口底）。互换后操作条按钮带占据 30.7～74.7（方案 A 下 34～78），**两者在纵向上重叠**。互换前 toast 上方是横栏（更高），不冲突。实装时需要一并处理，否则 H44 的「toast 位置正常」会不过。卡内未提及，本卡不自行决定 toast 的新落位。
2. **`S2OverlayLayout.snapshot` 与 `S2View.interfaceOverlay` 是两套并行的几何真相**——模型给门禁看，视图给用户看，靠人工保持一致。本卡的互换必须同时改两处；若只改一处，既有门禁**照样全绿**却与实际渲染不符。这是结构性风险（CLAUDE.md 陷阱 4「几何写入要收敛到单一入口」的同类问题，只是发生在浮层布局上），值得单独立卡收敛。
3. **L2 的名字与实现范围不一致**：注释写「底部操作与照片横栏都不进入主屏幕指示条区域」，实现约束的是 44 pt **触控带**而非可见带。系统自身（含 Apple 的工具条）并不满足这条按触控带的解释。若日后要与系统对齐，这条门禁的判据迟早要重新定义——方案 B 就是在做这件事。
4. **卡内系统表的「工具条淡色背景底缘 → 屏幕底 ≈28.7 pt」未被两个常量覆盖**。若视觉稿阶段要求操作条带背景，还需要第三个占位常量；本卡未涉及。

## 完成后动作

**停在实装前，等技术负责人在方案 A / B 之间裁定。** 未合并主干，未推 CI，未改任何产品代码，未动冻结三链。
