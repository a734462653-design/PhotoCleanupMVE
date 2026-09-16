# IC-151 变更清单

- 任务卡：`<top>/Tasks/IC-20260915-151-ambient-fixed-color-and-s0-layout.md`
- 分支：`feature/ic-151-ambient-fixed-color-and-s0-layout`
- 基线：`main` = `1fd6ed0525fde06ce710da4daa2f383d75d2d818`（IC-150 报告回填提交）
- 分支 tip（代码）：`35f4e29476d3cec60df40a19e3a2bcdd2aef0ab2`
- 提交数：4 个代码提交 + 1 个报告提交（本文件所在提交）
- `schemaVersion`：**7，未动**（本卡不进 `S2CalibrationConfiguration`、不上标定面板）

---

## 一、提交清单

| # | SHA | 子项 | 标题 | 可单独 cherry-pick |
|---|---|---|---|---|
| 1 | `8a3f6572e7cc5cce07bee440588c478fd549299f` | A | H71 版式塌陷的归因——无框 `scaledToFill` 的溢出机制测试 | 是 |
| 2 | `0659e3ac0aab1c322cb1c2db077ff84c12c46b9a` | B | 氛围底改固定色——12 个 v2 登记值与四层固定色视图 | 见下 |
| 3 | `b5474fa759e52eb07dcbf7e510b7c1b56be5a150` | C | S2 侧删取图链、氛围底视图改无参 | 见下 |
| 4 | `35f4e29476d3cec60df40a19e3a2bcdd2aef0ab2` | D | S0 侧删图源链、玻璃卡改半透明填充、登记表换两个值 | 见下 |

**关于「可单独 cherry-pick」的实话**（纪律 6 要求给完整事实，不粉饰）：

- 提交 1（子项 A）**可以**单独 cherry-pick——它只增一个测试文件与四行 pbxproj 登记，不依赖任何后续改动，断言 1 在 `main` 上也成立（它测的是 SwiftUI 的布局机制，不是本仓的某一版代码）。
- 提交 2～4 **只能作为 A→B→C→D 这一段连续序列**一起摘。原因是结构性的、由任务卡的子项划分决定：子项 B 的白名单只含 `S2AmbientBackdrop.swift`，删掉的 `S2AmbientImageLoading`／`S2AmbientBackdropStore`／`S2AmbientBackdropReadout` 的调用点分别落在子项 C（`S2View.swift`）与子项 D（`S0View.swift`）的白名单里。单独摘 2 或 3，编译期必然缺符号。
- 本卡不是「一个改动被拆成四个可独立回滚的小改动」，而是**一次同层替换被按受影响文件分成四段**。CI 跑的是分支 tip，四段合起来才是一个可编译状态。这一点在此声明，不在报告里假装满足。

---

## 二、文件变更全量（`git diff --name-status 1fd6ed0..HEAD`，代码提交部分）

```
M	PhotoCleanupMVE.xcodeproj/project.pbxproj
M	PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
M	PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift
M	PhotoCleanupMVE/Features/S0/S0View.swift
M	PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift
M	PhotoCleanupMVE/Features/S2/S2View.swift
D	PhotoCleanupMVE/Services/S0RecentPhotoAmbientLoader.swift
M	PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift
M	PhotoCleanupMVETests/IC148S0VisualTests.swift
A	PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift
```

十个路径逐个落在任务卡「本卡显式授权（白名单）」表内，无一例外。

零改动实证（`git diff --name-only 1fd6ed0..HEAD -- <前缀> | wc -l`）：

| 前缀／文件 | 命中 |
|---|---|
| `PhotoCleanupMVE/Features/S1/` | **0** |
| `PhotoCleanupMVE/Features/S3/` | **0** |
| `PhotoCleanupMVE/Features/S4/` | **0** |
| `PhotoCleanupMVE/Features/S5/` | **0** |
| `PhotoCleanupMVE/Core/` | **0** |
| `PhotoCleanupMVE/Services/`（除被删的那一个） | **0** |
| `PhotoCleanupMVE/Features/S2/`（除 `S2AmbientBackdrop.swift`／`S2View.swift`） | **0** |
| `.github/` | **0** |
| `Scripts/` | **0** |
| `PhotoCleanupMVE/Localizable.xcstrings` | **0** |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | **0** |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift`、`IC150*Tests.swift` | **0** |

`Features/S2/` 两个未动文件的两侧 SHA-256（`git show <ref>:<path> | sha256sum`）：

| 文件 | `main` = 分支 |
|---|---|
| `S2VideoPlayback.swift` | `e014292d33f67acf1dd49277fae41e2558d639df4634e1315659cdd4df25039c` |
| `S2NativePhotoPager.swift` | `17be1265994d1e4dcfcf8600e7e78db68fdafb451f0e897975077d4d22dce4f9` |

---

## 三、逐文件说明

### 1. `PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift`（子项 B）

| 处 | 动作 |
|---|---|
| M1 `enum S2AmbientMetrics` | **整块替换**。v1 的十个值 + `veilMidLocation`／`tintHue`／`sourceTargetEdge` 全部删除，换成 v2 的十二个（见第四节登记表） |
| M2 `protocol S2AmbientImageLoading` | **删除** |
| M3 `final class S2PhotoKitAmbientImageLoader` | **删除**（`import Photos` 的唯一用户） |
| M4 `private final class S2AmbientContinuationResumer` | **删除** |
| M5 `final class S2AmbientBackdropReadout` | **删除**（文件内唯一的 `@Published`） |
| M6 `final class S2AmbientBackdropStore` | **删除** |
| M7 `enum S2AmbientGrain` | **一行未改**。逐字节核对：`main` 与分支两侧该块（55 行）`diff` 无差异 |
| M8 `struct S2AmbientBackdropView` | 改成**无参**视图：删 `@ObservedObject var readout`、删 `.animation(…, value: readout.image)`，`body` 直接是那四层 |
| M9 `content(image:)` | 折进 `body`。层次由 `底色 → 模糊图 → veil → tint → grain` 换成 `底色 → wash → glow → grain`；`.allowsHitTesting(false)`／`.accessibilityHidden(true)` 两条修饰符**保留**；`GeometryReader` 外层 `.frame` + `.clipped()` **保留** |
| M10 `veil`／`tint`／`tintColor`／`grain` | `veil` → `wash`、`tint` → `glow`、`tintColor(opacity:)` 删除（改用 `S2AmbientMetrics.tintColor.opacity(…)`）、`grain` 一字未改 |
| 首行 | `import Photos` **删除**；`import SwiftUI`／`import UIKit` 保留（`UIImage` 仍由 `S2AmbientGrain` 用） |

光晕的实现换算（要达成的几何结果由卡给，手段由实现选）：`EllipticalGradient` 的中心与半径定义在**单位正方形**里再拉伸填满自己的框，半值即触到框边。故框取「半径占比 × 视口边长」的**两倍**、`endRadiusFraction` 取 `glowFadeStop` 的**一半**——两处折半是同一条换算，不是新取值，视图体内因此只出现 `0`／`1`／`2` 三个裸数。

### 2. `PhotoCleanupMVE/Features/S2/S2View.swift`（子项 C）

| 处 | 行（改前） | 动作 |
|---|---|---|
| V1 | `:783-784` | 删成员 `ambientImageLoader` 及其文档注释 |
| V2 | `:821-823` | 删 `@StateObject ambientBackdrop` 及其文档注释 |
| V3 | `:843-844` | 删 `init` 形参 `ambientImageLoader:` |
| V4 | `:891` | 删赋值 |
| V5 | `:917-923` | 构造点改 `S2AmbientBackdropView()`；**ZStack 层次位置一字未动**；注释里已被本卡证伪的「当前照片的强模糊氛围底」改写为「固定色氛围底」 |
| V6 | `:980-984` | 删 `.onAppear` 内的一次取图与其注释；`.onAppear` 其余各行不动 |
| V7 | `:1108-1112` | 删 `.onChange(of: machine.currentAssetID)` 回调体内的取图那一行与**只解释它**的四行注释；**不另起 `.onChange`** |

**一处声明式处置**：卡内 V7 写「只删这一行……不得改其余行」。实际删了「那一行 + 只解释那一行的四行注释」。理由是留下一段解释「氛围底为什么并进这条回调」的注释而代码已不在，属陷阱 12 的同类（死引用）。#289 关心的是**回调体的结构**——本卡未另起 `.onChange`，回调体其余五句（`tutorial.currentAssetDidChange`、`centerIndicatorState = nil`、`refreshCenterIndicator`、`cancelVideoScrub`、`notifyLivePlaybackOfCurrentPage`）一字未动，IC-141／IC-143 三条既有断言的命中数在改后源码上重算与改前相同（见自验报告第六节）。V1／V2／V6 三处的注释随其所解释的语句一并删除，同理。

### 3. `PhotoCleanupMVE/Features/S0/S0View.swift`（子项 D）

| 处 | 动作 |
|---|---|
| S1 | 删 `protocol S0AmbientImageProviding`（含五行文档注释） |
| S2 | 删 `@StateObject private var ambientReadout` |
| S3 | 删 `@State private var hasRequestedAmbient` |
| S4 | 删成员 `ambientImageProvider`、`init` 形参、赋值三处 |
| S5 | 构造点改 `S2AmbientBackdropView()`，位置不动 |
| S6 | `.onAppear` 只删 `requestAmbientImageIfNeeded()`；`bootstrapIfNeeded()` 不动 |
| S7 | 删 `requestAmbientImageIfNeeded()` |
| S8 | 三处 `.s0GlassSurface(cornerRadius:ambientImage:)` 去掉 `ambientImage:` 实参 |
| S9 | `S0GlassSurface` 背景由 `ZStack { shape.fill(baseColor); frost }` 改为**单层** `shape.fill(LinearGradient(白 0.10 → 白 0.045, 上→下))`；两层描边与投影原样保留 |
| S10 | `frost`（那五个修饰符）**整个删除**——它正是子项 A 验证的溢出源 |
| S11 | `s0GlassSurface(cornerRadius:)` 去掉 `ambientImage` 形参 |
| 结构体文档注释 | IC-148 裁定 乙「氛围底图源取照片库中最近一张」标为**随 IC-151 作废**；裁定 甲／丙 沿用并补记「2026-09-15 一度撤销后同日恢复」 |

`S0View` 的**行为一行未改**：`machine.handle(` 4、`machine.beginVerification` 1、`machine.ingest` 1，三个数在改前改后相同（断言 14 钉住）。

### 4. `PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift`（子项 D）

| 处 | 动作 |
|---|---|
| R1 | 文件注释「`S0Ambient` 的**十个**值不在此登记」→「**十二个**」，并补一句 IC-151 把该族由 v1 十个换成 v2 十二个、落点不变 |
| R2 | 删 `cardBlurRadius = 30`、`cardSaturation = 1.70` |
| R3 | 加 `cardFillTopOpacity = 0.10`、`cardFillBottomOpacity = 0.045`；MARK 段标题由「玻璃卡（8）：三层高光 + 投影」改为「玻璃卡（8）：半透明填充 + 三层高光 + 投影」 |

段内仍 **8** 个、全表仍恰 **52** 个（断言 10 钉住）。

### 5. `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`（子项 D）

| 处 | 动作 |
|---|---|
| E1 | 删成员 `s0AmbientImageProvider`（含三行文档注释） |
| E2 | 删 `s0Screen()` 内的 `ambientImageProvider: s0AmbientImageProvider,` 一行 |

`S0View` 与 `S2View` 两处构造点的**其余实参顺序一字未动**（陷阱 16）。

### 6. `PhotoCleanupMVE/Services/S0RecentPhotoAmbientLoader.swift`（子项 D）

`git rm`，88 行整文件删除。裁定 五：**整条删除不是停用**，不保留「以后可能用」的接口；日后若要恢复取图，从 git 历史拿。

### 7. `PhotoCleanupMVE.xcodeproj/project.pbxproj`

- 子项 A：**新增**四行，登记 `PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift`
- 子项 D：**删除**四行（P1 `PBXBuildFile`、P2 `PBXFileReference`、P3 组成员、P4 `Sources` 构建阶段），全仓 `S0RecentPhotoAmbientLoader` 零命中

---

## 四、占位值登记（登记制常量）

### 4.1 `S2AmbientMetrics`：v1 十值 **整体作废**，换 v2 十二值

| 登记名 | 常量名 | 取值 | 出处注释 |
|---|---|---|---|
| `ambientBaseColor` | `baseColor` | `#0B1A13` = rgb(11, 26, 19) | Decision_log 第 175／176 条、IC-151 卡 |
| `ambientTintColor` | `tintColor` | `#7AC49E` = rgb(122, 196, 158) | 同上 |
| `ambientWashTopOpacity` | `washTopOpacity` | `0.07` | 同上 |
| `ambientWashFadeLocation` | `washFadeLocation` | `0.42` | 同上 |
| `ambientWashBottomOpacity` | `washBottomOpacity` | `0.22` | 同上 |
| `ambientGlowCenterX` | `glowCenterX` | `0.50` | 同上 |
| `ambientGlowCenterY` | `glowCenterY` | `0.34` | 同上 |
| `ambientGlowRadiusX` | `glowRadiusX` | `0.92` | 同上 |
| `ambientGlowRadiusY` | `glowRadiusY` | `0.42` | 同上 |
| `ambientGlowOpacity` | `glowOpacity` | `0.10`（④ 第 176 条取中档） | 同上 |
| `ambientGlowFadeStop` | `glowFadeStop` | `0.72` | 同上 |
| `ambientGrainOpacity` | `grainOpacity` | `0.90`（沿用 v1 同值） | 同上 |

作废并删除的 v1 量名：`blurRadius`、`saturation`、`opacity`、`veilTopOpacity`、`veilMidOpacity`、`veilBottomOpacity`、`tintRadius`、`tintOpacity`、`veilMidLocation`、`tintHue`、`sourceTargetEdge`（`grainOpacity` 与 `baseColor` 两个名字留用，`baseColor` 的**取值**由 `#050507` 改为 `#0B1A13`）。

**出处按裁定 四 写法**：十二处一律写「取值出处：Decision_log 第 175／176 条、IC-151 卡（SPEC-S0 v2 晋级后改指第十四节第 2 部分）」。该文件内 `取值出处：SPEC-S0 v1 第十四节` 现为 **0** 处——SPEC-S0 v2 尚未晋级，新值不得冒充 v1 的登记值。

### 4.2 `S0HomeMetrics`：两个磨砂值换两个填充值，**52 不变**

| 动作 | 登记名 | 取值 | 出处注释 |
|---|---|---|---|
| 删 | `cardBlurRadius` | 30 | — |
| 删 | `cardSaturation` | 1.70 | — |
| 加 | `cardFillTopOpacity` | `0.10` | Decision_log 第 175／176 条、IC-151 卡 |
| 加 | `cardFillBottomOpacity` | `0.045` | 同上 |

实测计数（`S0HomeMetrics` 体内）：`static let` 恰 **52**；`取值出处：` **52**；`取值出处：SPEC-S0 v1 第十四节` **50**；`取值出处：Decision_log 第 175／176 条` **2**；`cardBlurRadius`／`cardSaturation` 各 **0**。

### 4.3 裁定 二：三处 ≤0.04 的画布差异**一律保留已登记值**

| 常量 | 已登记（保留） | 画布 | 处置 |
|---|---|---|---|
| `cardInnerTopOpacity` | **0.42** | 0.40 | 不动 |
| `cardShadowOpacity` | **0.42** | 0.46 | 不动 |
| `segmentRestOpacity` | **0.22** | 0.20 | 不动 |

### 4.4 `schemaVersion`

**7，未动。** 本卡的登记常量与 IC-146／IC-148 同制——不进 `S2CalibrationConfiguration`、不上标定面板，`S2Calibration.swift` 不在 diff 内。

---

## 五、既有断言的改动（逐条旧 → 新）

### 5.1 `PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift`（五条）

| # | 函数 | 旧 | 新 |
|---|---|---|---|
| 1 | `testIC146B_AmbientSitsBelowPhotoAndTakesNoTouches` | 锚点 `view.range(of: "S2AmbientBackdropView(readout:")` | 锚点 `view.range(of: "S2AmbientBackdropView()")`。**其余四个数一字未改**：层次次序两条、`S2ViewportBackground.color` 0、氛围底文件内 `.allowsHitTesting(false)` 恰 1、分页器 `backgroundColor = .clear` 7 与 `.clear` 8 |
| 2 | `testIC146B_AmbientAddsNoGeometryWrite` | `occurrences("@Published", ambient) == 1` | `== 0`（M5 读数类型已删）。**改后更严不是放宽**：固定色视图没有任何发布源。分页器 `writePhotoGeometry` 5、氛围底内 `writePhotoGeometry`／`S2NativePager` 0 三条**未改** |
| 3 | `testIC146B_AmbientMetricsMatchS0AmbientRegistry` | 钉 v1 九个 Double + `baseColor` = `#050507`；出处 `取值出处：SPEC-S0 v1 第十四节` ≥ 10；裸数名单 `["34","1.15","0.62","0.66","0.94","0.70","0.90"]` | 钉 v2 十个 Double + `baseColor` = `#0B1A13` + `tintColor` = `#7AC49E`；出处 `取值出处：Decision_log 第 175／176 条` ≥ 12 **且** `取值出处：SPEC-S0 v1 第十四节` 恰 0；裸数名单 `["0.07","0.42","0.22","0.92","0.34","0.10","0.72","0.90"]` |
| 4 | `testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes` | — | **一字未改**。禁用词名单（`colorScheme`／`systemBackground`／`UIColor.label`／`.primary`／`S2ChromeForeground`／`Material`／`ultraThin`）一项不减，`baseColor` 两种 trait 解析同值照旧 |
| 5 | `testIC146B_AmbientFallsBackToBaseColorWhenLoadFails` | 整条测「取图失败回落到纯色」 | **删除**（项数 −1）。被测机制本身已不存在。同删 `private final class S2AmbientLoaderStub`（它遵循已删除的 `S2AmbientImageLoading`） |

### 5.2 `PhotoCleanupMVETests/IC148S0VisualTests.swift`（五处）

| # | 位置 | 旧 | 新 |
|---|---|---|---|
| 1 | `newProductFiles`（`:23-28`） | 四个文件，含 `Services/S0RecentPhotoAmbientLoader.swift` | **三个**。文件已删，`strippedSource` 解不开会让断言 2 与断言 7 的循环直接失败 |
| 2 | 断言 1 `testIC148AAssertion01RegistryMatchesSpecSection14` 玻璃卡段 | `cardBlurRadius == 30`、`cardSaturation == 1.70` | `cardFillTopOpacity == 0.10`、`cardFillBottomOpacity == 0.045` |
| 3 | 断言 1 出处与计数段 | `取值出处：SPEC-S0 v1 第十四节` ≥ 52 | `取值出处：` ≥ 52、`取值出处：SPEC-S0 v1 第十四节` **恰 50**、`取值出处：Decision_log 第 175／176 条` **恰 2**；**新增**两条 `cardBlurRadius`／`cardSaturation` 在登记表体内各 0。`static let` 恰 52、`ambientBlurRadius`／`ambientBaseColor`／`gridColumns`／`groupCardCornerRadius` 零命中四条**未改** |
| 4 | 断言 2 `testIC148AAssertion02AlwaysDarkRecipe` | — | **一字未改**（禁用词名单不减）。扫描面因 `newProductFiles` 少一个文件而由 5 个变 4 个 |
| 5 | 断言 4 `testIC148AAssertion04ReusesAmbientWithoutCopyingOrTouchingPhotoKit` | 正对照读 `Services/S0RecentPhotoAmbientLoader.swift`；锚点 `S2AmbientBackdropView(readout:` ≥1、`S2AmbientBackdropReadout()` ≥1、`S2AmbientMetrics.` ≥1、`S2AmbientBackdropStore` ==0 | 正对照改读 `Services/AssetSizeScanner.swift`（`PHAsset` 26 行、`import Photos` 1 行）；锚点改 `S2AmbientBackdropView()` ≥1、`S2AmbientBackdropReadout` **==0**、`S2AmbientBackdropStore` ==0；**`S2AmbientMetrics.` ≥1 一条删除**——子项 D 删掉 `shape.fill(S2AmbientMetrics.baseColor)` 后该计数必然为 0，留着必红（惯例 37：「某计数不变」类断言先核在正确实现后会不会必然失效） |

断言 3 `testIC148AAssertion03NoBareNumbersInViewBodies` **未改**：它扫的正是 `S0GlassSurface` 视图体，子项 D 的实现里除 `lineWidth: 1` 的两个 `1` 之外一个裸数不写，改后仍绿。

### 5.3 未改的既有文件

`IC147S0BehaviorTests.swift`（16 项）、`IC150ShareTests.swift`／`IC150AudioSessionTests.swift`（7 项）、`IC141VideoPlaybackTests.swift`、`IC143VideoPolishTests.swift` **一字未改**，均在 diff 之外。

---

## 六、新增测试（`PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift`，8 项）

| 断言 | 函数名 | 子项 | 落在哪个提交 |
|---|---|---|---|
| 1 | `testIC151A_UnframedScaledToFillOverflowsItsProposal` | A | 提交 1 |
| 2 | `testIC151A_S0GlassSurfaceHasNoImageLayer` | A → D | 提交 1 以 `XCTSkip` 落地，**提交 4 转为正式断言** |
| 3 | `testIC151B_AmbientRegistryMatchesDecision175And176` | B | 提交 2 |
| 4 | `testIC151B_AmbientChainHasNoPhotoKitAndNoPublisher` | B | 提交 2 |
| 9 | `testIC151C_S2ViewNoLongerLoadsAmbientImages` | C | 提交 3 |
| 11 | `testIC151D_S0DropsAmbientImageSourceEntirely` | D | 提交 4 |
| 12 | `testIC151D_GlassSurfaceIsTranslucentFillWithoutBaseColor` | D | 提交 4 |
| 14 | `testIC151D_S0BehaviorCallSitesUnchanged` | D | 提交 4 |

断言 5～8、10、13 是 IC-146／IC-148 两个既有文件内被改写的断言，不在本文件（对应见第五节）。

**断言 2 的落地方式**（卡内允许二选一，此处记明）：子项 A 的提交里以 `throw XCTSkip(...)` 落地——那时产品侧那一层还在，正式断言必红；子项 D 的提交把函数体换成正式断言并补三条针对 needle 自身的正对照。

**pbxproj 撞号扫描**：加登记前重扫当前最大号——文件引用 `100000000000000000000052`、构建文件 `20000000000000000000004F`；新号取 `100000000000000000000053`／`200000000000000000000050`，登记脚本内断言「新号严格大于现有最大号且尚未出现在文件里」，否则直接中止。撞号不报错、文件会静默掉出编译列表、CI 照绿（IC-134 #262）。

---

## 七、项数对账

```
798（main，CI #301 执行摘要）
 − 1（删 testIC146B_AmbientFallsBackToBaseColorWhenLoadFails）
 + 8（本卡新增，见第六节）
= 805
```

**实测吻合**：CI #302 attempt 2（run id `35066348388`，被测提交 `35f4e29476d3cec60df40a19e3a2bcdd2aef0ab2`）执行摘要 `Executed 805 tests, 0 failing test case(s), across 1 launch(es)`；日志内唯一 `Test Case` 身份行去重计数亦为 **805**。详见 `self-check.md` 第四节。
