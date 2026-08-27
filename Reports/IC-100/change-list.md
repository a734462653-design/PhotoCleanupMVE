# IC-100 变更清单（v2：底部竖向排布互换 + toast 上移 + 双真相同步）

> v1 在实装前触发闸门 B、零代码变更；本清单覆盖 v1，记录 v2 的实际改动。

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交 | `fe5b891169814df896b749e32e80265b9bbb7ced`（v1 R0 报告，基于 `main` = `ef9d46a`） |
| 分支 | `feature/ic-100-bottom-layout-swap`（未重切） |
| 分支 tip（代码部分，CI #172 被测提交） | `6edc9c5ff2cf7c8ca753ca2d5200876636f67182` |
| 报告提交 | 只含 `Reports/IC-100/`，命中 `paths-ignore`，**不触发 CI** |

两个提交：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `7b5e57d…` | `feat(s2): 底部竖向排布互换为 安全区 → 操作条 → 横栏，toast 随之上移（IC-100 v2 R1+R2+R3）` |
| 2 | `6edc9c5ff2cf7c8ca753ca2d5200876636f67182` | `test(s2): IC-100 B1/B2/B6/B7 底部排布断言（IC-100 v2）` |

**R1 与 R2 合并在提交 1**：只上移横栏而不动 toast 会让两者纵向重叠，正是 R2 要修的缺陷；拆开会留一个已知有缺陷的中间态提交。

## 文件变化（`git diff --numstat fe5b891..HEAD`，报告提交前）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 98 | 3 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 68 | 37 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 211 | 0 |

测试文件**零删除**——既有断言一行未改、未删。

## 逐项改动

### R1（提交 1）——`S2OverlayLayout`：三常量 + 七推导式 + `snapshot` 底部两帧

新增三个登记制占位常量：`actionBarVisibleBandHeight = 22`、`stripToActionVisibleBandSpacing = 30.7`、`toastToStripSpacing = 8`。

新增七个推导式（静态函数）：

| 函数 | 语义 | 常规机型落值 |
|---|---|---|
| `actionBandCenterFromViewportBottom(safeAreaBottom:)` | 触控带中心距视口底 = 安全区底 + 22 | 56.0 |
| `actionBandTopFromViewportBottom(safeAreaBottom:)` | 触控带顶缘距视口底 | 78.0 |
| `actionBandBottomFromViewportBottom(safeAreaBottom:)` | 触控带底缘距视口底（= 安全区底） | 34.0 |
| `actionVisibleBandTopFromViewportBottom(safeAreaBottom:)` | 可见图标带顶缘距视口底 | 67.0 |
| `stripBottomFromViewportBottom(safeAreaBottom:)` | 横栏底缘距视口底 = 可见带顶缘 + 30.7 | 97.7 |
| `stripTopFromViewportBottom(safeAreaBottom:bottomStripHeight:)` | 横栏顶缘距视口底 | 169.7 |
| `toastBottomFromViewportBottom(safeAreaBottom:bottomStripHeight:)` | toast 底缘距视口底 = 横栏顶缘 + 8 | 177.7 |

另把既有的 `max(minimumTouchTarget, bottomStripHeight)` 抽为 `resolvedStripHeight(_:)`，供推导式与 `snapshot` 共用（语义不变）。

`snapshot(...)` 的底部两帧改为按推导式锚定**视口**底缘（改前是横栏贴安全区底、操作条在其上方 8 pt）：

```
stripFrame.y = physicalSize.height − stripBottomFromViewportBottom(...) − stripHeight
actionY      = physicalSize.height − actionBandTopFromViewportBottom(...)
```

### R1 + R2（提交 1）——`S2View`

- `interfaceOverlay` 由「一个 `VStack` 吃四边安全区、底部两件套在内层 `VStack`」改为 `ZStack(alignment: .bottom)` 的三层：顶部信息区（只吃 `.padding(.top, safeAreaInsets.top)`，几何与改前逐字相同）、底部横栏、常驻操作条，后两者各自按推导式 `.padding(.bottom, …)` 独立锚定。左右安全区仍由外层统一给。
- `feedbackToastOverlay(safeAreaInsets:)` → `feedbackToastOverlay(bottomInset:)`。主屏幕传 `toastBottomFromViewportBottom(...)`（177.7）；sheet 内传 `S2OverlayLayout.minimumSpacing`（8，**与改前逐字相同**）。

### R3（提交 1）——双真相同步

渲染侧的两个 `.padding(.bottom, …)` 与门禁侧 `snapshot` 的两帧 y 坐标，改为调用同一组推导式。调用点对照表见 `self-check.md` R3 节。**局限**：逐像素比对渲染结果需给产品视图加测试专用探针（禁止项），未做，已挂账收敛卡。

### 断言（提交 2）——新增 5 项

| 测试函数 | 覆盖 |
|---|---|
| `testIC100B1BottomOverlayOrderAndAnchors` | B1 顺序、锚点、L2/L4 复核、间距推导式、净空 ≥ 15 |
| `testIC100B1LayoutFollowsLargerBottomSafeArea` | B1 续：安全区 60 时整组上移、L2 仍成立、间距语义不变 |
| `testIC100B2GeometryIsIndependentOfInterfaceVisibility` | B2 隐藏再恢复几何逐值相同 |
| `testIC100B6ToastSitsAboveStripWithoutOverlap` | B6 toast 落位与三者纵向次序 |
| `testIC100B7SnapshotMatchesRenderDerivations` | B7 模型帧 ↔ 渲染侧 padding 逐值相等、推导式自洽 |

B3/B4/B5 由既有门禁背书（本卡未新增，也未改动）。

## 未改动清单

| 项 | 状态 |
|---|---|
| **L2 / L4 门禁判据** | **一行未改** |
| 横栏几何 / 运动参数（`bottomStripMetrics`、项目尺寸、间距、圆角、惯性、吸附、跟随） | 未动 |
| 操作条三按钮的显示 / 可用 / 禁用规则与 44×44 | 未动 |
| `S2ViewportLayout.metrics`（主图视口与主图几何） | 未动 |
| 顶部信息区、主图待删标记 | 未动（顶部信息区的 `.padding(.top, safeAreaInsets.top)` 语义与改前相同） |
| toast 的语义、时长参数、随 `V` 规则、不接收点击 | 未动 |
| 手势、图片请求策略、sheet 规则 | 未动 |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md`、`Scripts/`、`ci.yml` | 未动 |
| `feature/ic-089/091/092` 冻结三链 | 未触碰 |

未新增 XCUITest；未合并 `main`；未 rebase / amend / force push / 改写历史 / 删分支。

## 占位值登记

三个登记制占位常量，全部是 `S2OverlayLayout` 的代码常量，**不进 `S2CalibrationConfiguration`、不上参数面板**（同 IC-091 `edgeTolerance` 先例），视觉稿前 ④ 可修订：

| 常量 | 值 | 出处 |
|---|---|---|
| `actionBarVisibleBandHeight` | 22.0 pt | `.body` 行高（`UIFont.preferredFont(forTextStyle: .body).lineHeight`），推导写入 self-check |
| `stripToActionVisibleBandSpacing` | 30.7 pt | 技术负责人 2026-08-28 系统录屏实测表（92 px @3x，三静止帧一致，①） |
| `toastToStripSpacing` | 8 pt | IC-100 v2 卡内定案（④） |

触控带中心不是常量而是推导式 `safeAreaBottom + minimumTouchTarget / 2`（常规 56.0）；`minimumTouchTarget = 44` 是既有常量，未改。

**`S2CalibrationConfiguration.schemaVersion` 仍为 4**，未加字段、未改出厂值（闸门 C 未触发）。

## 产品行为净变化（相对 `ef9d46a`）

1. **底部竖向顺序互换**：自下而上由「安全区 → 横栏 → 操作条」改为「安全区 → 操作条 → 横栏」。
2. **横栏离开屏幕底缘**：底缘由「贴安全区上沿」（距视口底 34 pt）上移到**距视口底 97.7 pt**，与系统底缘手势区拉开距离（本卡的产品动机）。
3. **操作条贴近底缘**：触控带底缘恰在安全区上沿（距视口底 34 pt），中心距视口底 56.0 pt。
4. **toast 上移**：主屏幕上 toast 底缘由距视口底 42 pt 改为 **177.7 pt**（横栏顶缘 + 8），与操作条、横栏均无纵向重叠。sheet 内的 toast 落位不变。

主图视口、主图几何、顶部信息区、横栏自身的几何与运动、操作条按钮语义、手势与图片请求**零变化**。

与系统 Photos 的已知偏差：可见带中心 56.0 vs 系统 52.7，**差 3.3 pt，④ 有意为之**（保 L2 门禁），H44 只报方向。
