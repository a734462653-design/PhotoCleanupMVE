# IC-100 自验报告（bottom-layout-swap，v2）

> v1（`fe5b891`）在实装前触发闸门 B 并停下报告；技术负责人裁定方案 A 后下发 v2。本报告**覆盖 v1**，v1 的算术冲突证据保留在「v1 闸门 B 的处置」一节。

## 结论（先行）

R1（互换 + 三常量）、R2（toast 上移）、R3（双真相同步）全部交付。

**CI 结果：CI #172 success**，被测提交 `6edc9c5ff2cf7c8ca753ca2d5200876636f67182`，XCTest **502 项、0 失败**，9 步全 success，被测命令真实退出码 **0**；IPA **794415 字节**、SHA-256 `43eac148216f4271f7471818b69cf24486b3283f30ca10db60e741a280107688`，本地重下复核逐字节一致。**CI 只用了 1 次**（上限 3）。

计数算式：**497 + 5 − 0 = 502**。本地三项门禁真实退出码全为 **0**。

**L2 / L4 判据一行未改**，既有门禁全过。三道闸门（A 主图几何 / 手势 / 横栏运动学 / 图片请求，B 既有门禁，C 标定参数与 `schemaVersion`）**均未触发**。

**H44 保留给 Lynn 真机判定，本报告不代为下结论。**

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空 |
| 继承提交 | `fe5b891169814df896b749e32e80265b9bbb7ced`（v1 R0 报告，基于 `main` = `ef9d46a`） |
| 目标分支 | `feature/ic-100-bottom-layout-swap`（未重切） |
| 分支 tip（代码部分） | `6edc9c5ff2cf7c8ca753ca2d5200876636f67182` |
| CI | **#172 success（1/3）** |
| 合并动作 | 无 |

范围边界：只动了 `S2Calibration.swift`（`S2OverlayLayout` 的三个占位常量、七个推导式、`snapshot` 的底部两帧）、`S2View.swift`（`interfaceOverlay` 底部重排、`feedbackToastOverlay` 落位入参、两处调用点）、`S2CalibrationHarnessTests.swift`（新增 5 项断言）。**横栏几何/运动参数、操作条按钮语义、顶部信息区、标记、手势、图片请求、L2/L4 判据、SPEC、Decision_log、`Scripts/`、`ci.yml` 一字未动。**

## v1 闸门 B 的处置

v1 的算术冲突（执行端①）已由技术负责人裁定为**方案 A**：保 L2 门禁，触控带中心改锚安全区。本卡按裁定实装，v1 的 52.7 不再使用。

| v1 冲突 | v2 处置 |
|---|---|
| 触控带中心距视口底 52.7 ⇒ `maxY` = 821.3 > L2 上限 818，差 3.3 pt | 中心改为 `safeAreaInsets.bottom + minimumTouchTarget / 2`，常规机型 = **56.0**，`maxY` = **818.0** 恰好相切，L2 与 L4 同时成立 |
| 与系统 52.7 的 3.3 pt 观感差 | **有意为之**（④ 裁定），H44 只报「偏高/偏低/可接受」方向，B 案（改门禁判据）留视觉稿阶段 |
| 执行端另报：toast 42 pt 落位会与新操作条重叠 | 就地纳入本卡 **R2**，toast 底缘改为横栏顶缘 + 8 |
| 执行端另报：`S2OverlayLayout.snapshot` 与 `S2View` 双几何真相 | 就地纳入本卡 **R3**，两侧改为共用同一组推导式 |

## R1：竖向排布互换与三个占位常量

### 推导式（`S2Calibration.swift` 的 `S2OverlayLayout`）

```
触控带中心距视口底 = safeAreaBottom + minimumTouchTarget / 2      = 34 + 22 = 56.0
触控带顶缘距视口底 = 中心 + minimumTouchTarget / 2                = 56.0 + 22 = 78.0
触控带底缘距视口底 = 中心 − minimumTouchTarget / 2                = 56.0 − 22 = 34.0（= 安全区底）
可见图标带顶缘距底 = 中心 + actionBarVisibleBandHeight / 2        = 56.0 + 11 = 67.0
横栏底缘距视口底   = 可见带顶缘 + stripToActionVisibleBandSpacing = 67.0 + 30.7 = 97.7
横栏顶缘距视口底   = 横栏底缘 + max(44, bottomStripHeight)        = 97.7 + 72 = 169.7
toast 底缘距视口底 = 横栏顶缘 + toastToStripSpacing               = 169.7 + 8 = 177.7
```

**可见图标带高 22.0 的推导（卡内要求写入报告）**：现行操作条三个按钮是 `Label(标题, systemImage:)`（`S2View.swift` 的 `actionBar`，未设自定义字体），字体走 SwiftUI 默认 `.body`；可见带高由该文本样式的行高决定，默认动态字体（Large）下 `UIFont.preferredFont(forTextStyle: .body).lineHeight == 22`。`S2Calibration.swift` 不引入 UIKit（现有 import 为 Combine / CoreGraphics / Foundation / Security），故取该值为常量而非运行时读取。**与系统工具条的纯图标带 24.3 pt 不同**——我们的按钮是图标 + 文字，带高由行高而非字形高决定；观感差由 H44 判。

### 净空实测（卡内要求 ≥ 15 pt）

触控带顶缘 78.0，横栏底缘 97.7 ⇒ **净空 19.7 pt** ≥ 15 ✅。断言 B1 里以 `actionFrames[0].minY - stripFrame.maxY >= 15` 落实。

### 测试视口（393×852、安全区底 34、横栏高 72）下的落值

| 元素 | 距视口底（底缘 / 顶缘） | frame minY / maxY | L2 上限 818 |
|---|---|---|---|
| 操作条触控带 | 34.0 / 78.0 | 774.0 / **818.0** | ✅ 恰好相切 |
| 底部横栏 | 97.7 / 169.7 | 682.3 / 754.3 | ✅ |
| toast 底缘 | 177.7 | — | — |

## R2：toast 上移

`feedbackToastOverlay` 的落位由「安全区底 + minimumSpacing」改为**由调用方给出的 `bottomInset`**：

| 调用点 | 改前 | 改后 | 结果 |
|---|---|---|---|
| 主屏幕（`S2View.swift` 主 `ZStack`） | `safeAreaInsets.bottom + 8` = 42 | `toastBottomFromViewportBottom(safeAreaBottom:bottomStripHeight:)` = **177.7** | 移到横栏上方 8 pt，与操作条、横栏均无纵向重叠 |
| sheet 内（`.overlay(alignment: .bottom)`） | 传 `.zero` 安全区 ⇒ `0 + 8` = 8 | `S2OverlayLayout.minimumSpacing` = **8** | **与改前逐字相同** |

toast 的「底部短 toast」语义、时长参数、随 `V` 的规则、不接收点击、不遮挡手势一律未动。

**R1 与 R2 同一提交**：只上移横栏而不动 toast，会让两者纵向重叠——正是 R2 要修的缺陷。拆成两个提交会留一个已知有缺陷的中间态，故合并为一个提交并在提交信息里写明。

## R3：双真相同步

**改前的事实（①）**：`S2OverlayLayout.snapshot` 在产品代码里**没有任何消费方**（`grep` 全仓库，只有定义与测试引用），它是纯粹给门禁看的几何镜像；`S2View.interfaceOverlay` 另写一套 `VStack` 排布。两套几何靠人工保持一致，改一处不改另一处，**既有门禁照样全绿却与实际渲染不符**。

**改后**：两侧调用同一组推导式，位置不再各算各的。

| 侧 | 调用点 | 用的函数 |
|---|---|---|
| 门禁侧 | `S2Calibration.swift` `snapshot(...)` 的 `stripFrame.y` | `stripBottomFromViewportBottom(safeAreaBottom:)` |
| 门禁侧 | 同上 `actionY` | `actionBandTopFromViewportBottom(safeAreaBottom:)` |
| 渲染侧 | `S2View.swift` `interfaceOverlay` 横栏的 `.padding(.bottom, …)` | `stripBottomFromViewportBottom(safeAreaBottom:)` |
| 渲染侧 | 同上 操作条的 `.padding(.bottom, …)` | `actionBandBottomFromViewportBottom(safeAreaBottom:)` |
| 渲染侧 | `S2View.swift` 主 `ZStack` 的 toast | `toastBottomFromViewportBottom(safeAreaBottom:bottomStripHeight:)` |

B7 逐值核对「快照帧距视口底」等于渲染侧 padding 所用的同名函数返回值。

**如实标注的局限**：**逐像素比对渲染出来的 SwiftUI 帧未做。** 要做需要给产品视图插入测试专用的 frame 读取探针，属 CLAUDE.md 纪律 4「不为测试改产品」的禁止项。因此 B7 证明的是「两侧共用同一组推导式，且模型帧与渲染侧的 padding 输入逐值相等」，**不是**「渲染结果与模型逐像素相同」。**收敛卡挂账**：把 `S2OverlayLayout` 提升为渲染侧真正的唯一布局入口（而非只提供两个 padding 数），或引入一套不侵入产品的布局快照机制。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G223（v2）** B1～B7 通过；占位值登记节列出三常量与推导式 | 满足① | 五项测试函数名与 CI 通过行见下表；三常量见「占位值登记」 |
| **G224** CI success、真实退出码 0、XCTest 0 失败、计数算式、IPA 重下一致、本地三项门禁 0 | 满足① | 见「CI 与本地门禁」 |

### B1～B7 逐项

| 项 | 落实方式 | CI 结果 |
|---|---|---|
| **B1** 触控带中心 = 安全区底 + 22（±0.5）；操作条满足 L2 与 L4；横栏在其上方、间距按推导式（±1） | `testIC100B1BottomOverlayOrderAndAnchors` | **passed** |
| **B1 续** 安全区 60 时整组上移（中心 82）、L2 仍成立、两间距语义不变 | `testIC100B1LayoutFollowsLargerBottomSafeArea` | **passed** |
| **B2** `V` 显隐不改几何，隐藏再恢复后逐值相同 | `testIC100B2GeometryIsIndependentOfInterfaceVisibility` | **passed** |
| **B3** 横栏既有几何/运动门禁全过 | 既有断言一字未改，CI 502/0 全过；本卡未触碰任何横栏参数 | **全过** |
| **B4** 44×44 可触达、拖横栏期间不接收点击 | 既有 L4 与拖动门禁一字未改；B1 内另按 L4 判据复核了操作条三帧 | **全过** |
| **B5** 主图视口与主图几何零变化 | `S2ViewportLayout.metrics` 一字未动，浮层不参与视口计算；IC-063～IC-070 既有门禁全过 | **全过** |
| **B6** toast 底缘 = 横栏顶缘 + 8（±0.5），与操作条、横栏无纵向重叠 | `testIC100B6ToastSitsAboveStripWithoutOverlap` | **passed** |
| **B7** 门禁侧与渲染侧几何一致 | `testIC100B7SnapshotMatchesRenderDerivations`（局限见 R3 节） | **passed** |

### CI 与本地门禁

| 项 | 值 |
|---|---|
| 工作流 | `iOS 构建与自验`，run **#172**（id 33069454124） |
| 被测提交 | `6edc9c5ff2cf7c8ca753ca2d5200876636f67182` |
| 结论 | **success**，9 步全 success |
| XCTest | **Executed 502 tests, with 0 failures (0 unexpected)** in 34.609 (67.079) seconds |
| 计数算式 | 497（`main` = `ef9d46a` 基数）+ 5（本卡新增）− 0 = **502** ✅ |
| 真实退出码 | **0**（`set -o pipefail` + `exit "$test_status"`，步骤 6 conclusion = success） |
| IPA 字节数 | **794415** |
| IPA SHA-256 | `43eac148216f4271f7471818b69cf24486b3283f30ca10db60e741a280107688` |
| 本地重下复核 | `gh run download` 取 `PhotoCleanupMVE-unsigned-6edc9c5ff2cf`（Artifact ID 9645280082），本地 `stat` = **794415**、`sha256sum` = `43eac148…7688`，**与 CI 报告值逐字符一致** ✅ |
| `Scripts/selfcheck.ps1` | 退出码 **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 退出码 **0** |
| `git diff --check` | 退出码 **0** |
| CI 使用次数 | **1 / 3** |

**注**：本分支从 `main` = `ef9d46a` 切出，早于 IC-101，因此 CI #172 用的仍是**旧版** `ci.yml`（错误行 grep 未含产品目录）。本次全绿，未受影响。

### 闸门核对

| 闸门 | 触发 | 说明 |
|---|---|---|
| **A** 须改主图几何 / 手势路径 / 横栏运动学 / 图片请求 | 否 | 只改了两个浮层的锚定方式与 toast 落位；`S2ViewportLayout.metrics`、`bottomStripMetrics`、手势与图片请求一字未动 |
| **B** 任一既有门禁失败且非「绝对纵坐标按新顺序重算」 | 否 | 502/0 全过；**L2/L4 判据一行未改**，操作条 `maxY` = 818.0 恰好落在 L2 上限内 |
| **C** 新增标定参数、改出厂值或 `schemaVersion` | 否 | 三个常量是 `S2OverlayLayout` 的代码常量，未进 `S2CalibrationConfiguration`、未上面板；`schemaVersion` 仍为 **4** |

## 占位值登记

三个**登记制占位常量**，均为 `S2OverlayLayout` 的代码常量，**不进 `S2CalibrationConfiguration`、不上参数面板、`schemaVersion` 不动**（同 IC-091 `edgeTolerance` 先例）。视觉稿前 ④ 可修订。

| 常量 | 值 | 出处 | 备注 |
|---|---|---|---|
| `actionBarVisibleBandHeight` | **22.0 pt** | `.body` 文本样式在默认动态字体下的行高（`UIFont.preferredFont(forTextStyle: .body).lineHeight`） | 现行按钮是图标 + 文字，带高由行高决定；与系统纯图标带 24.3 pt 不同 |
| `stripToActionVisibleBandSpacing` | **30.7 pt** | 技术负责人 2026-08-28 系统录屏实测表（`IMG_6743.MP4`，92 px @3x，三静止帧逐像素一致，①） | 横栏底缘 → 操作条可见图标带顶缘 |
| `toastToStripSpacing` | **8 pt** | IC-100 v2 卡内定案（④） | toast 底缘 → 横栏顶缘 |

**触控带中心不是常量而是推导式**：`actionBandCenterFromViewportBottom(safeAreaBottom:) = safeAreaBottom + minimumTouchTarget / 2`（常规机型 34 + 22 = **56.0**）。v2 定案（④）由 v1 的固定值 52.7 改为锚定安全区，理由见「v1 闸门 B 的处置」。`minimumTouchTarget = 44` 是既有常量（v14 回写决策 14），本卡未改。

## 人工判定项

**H44，保留给 Lynn 真机判定，本报告不代为下结论。** 装本卡 CI #172 的包（IPA 794415 字节、SHA-256 `43eac148…7688`）。

| 判定项 | 本卡可提供的对照 |
|---|---|
| 与系统并排看底部布局（顺序与量级） | **已知我们整体比系统高 3.3 pt**（56.0 vs 52.7，④ 有意为之），只报「偏高 / 偏低 / 可接受」方向 |
| 横栏拖动不再误触系统底缘手势 | 横栏底缘已从「贴安全区底」上移到距视口底 97.7 pt；实际是否够，只有真机能判 |
| 操作条三按钮可点 | 触控带仍是 44 pt，底缘恰在安全区上沿 |
| toast 位置 | 以 B6 断言为准；**真机不强求复现写入失败**（本机相册写入不受飞行模式影响，第 99 条第 20 项旧坑，勿用该法） |
| `V` 显隐、翻页、标记、横栏拖动、sheet 无回归 | 全部为人工判定，无夹具结论 |

## 真机未覆盖项清单

1. **渲染结果未逐像素验证**——B7 只证明了两侧共用同一组推导式与 padding 输入逐值相等（见 R3 节的局限说明）。SwiftUI 的实际排布（尤其 `ZStack(alignment: .bottom)` 下三个子视图各自的 `.padding(.bottom, …)`）是否与模型完全一致，只有真机/模拟器截图能判。**这是本卡最需要 H44 盯住的一条。**
2. **可见图标带高 22.0 未实测**——它是按 `.body` 行高取的常量，真机上按钮的实际可见带（含 SF Symbol 与文字）可能不等于 22.0，直接影响横栏底缘的 97.7。H44 的「间距偏大/偏小」正好覆盖。
3. **动态字体放大后的表现未覆盖**——按钮字体是 `.body`，用户调大字号会让可见带变高，但常量 22.0 不随之变化，横栏与操作条的间距会与设计意图偏离。本卡按卡内定案取固定常量，未做自适应。
4. **横屏与特殊机型的安全区未覆盖**——B1 续只在 `bottom = 60` 的构造值上验证了「随安全区上移」，没有真实机型数据。
5. **操作条材质背景（`.regularMaterial`）挪到最底后的观感未覆盖**——改前最底是横栏的材质，现在是操作条的；与系统工具条的淡色背景（实测底缘距屏底 ≈28.7 pt）能否对上，只有真机能看。
6. **toast 在新位置是否会被横栏遮挡/裁切未覆盖**——B6 只证明了纵向不重叠，层级与裁切要真机看。

## 发现但未处理的问题（按纪律只报告不修）

1. **`S2OverlayLayout.snapshot` 仍然只有测试消费方**。本卡让渲染侧用上了同一组推导式，但 `snapshot(...)` 这个函数本身在产品代码里依然零调用——它拼装的 frame 仍只给门禁看。**双真相收敛了位置公式，没收敛几何模型本身**。挂账收敛卡（R3 节已写）。
2. **系统实测表里的「工具条淡色背景底缘 → 屏幕底 ≈28.7 pt」本卡未落地**。现行操作条的 `.regularMaterial` 背景贴着触控带边界，没有独立的背景带高常量。若视觉稿要求，还需要第四个占位常量。
3. **`actionBarVisibleBandHeight` 是硬编码 22.0 而非从字体读取**，原因是 `S2Calibration.swift` 不引 UIKit。若日后要跟随动态字体，需要把该值改为运行时注入（会让 `S2OverlayLayout` 的纯函数性质变化，影响门禁的确定性）。属架构取舍，本卡未做。
4. **`interfaceOverlay` 改成 `ZStack(alignment: .bottom)` 后，三个子视图各自负责自己的安全区避让**，顶部信息区只吃 `.padding(.top, safeAreaInsets.top)`、底部两件各吃自己的 `.padding(.bottom, …)`，左右安全区仍由外层统一给。这比改前的「一个 VStack 吃四边」分散，好处是两件能独立锚定，代价是新增浮层时容易漏掉某一边。值得在该函数上方补一条约定说明——本卡已写了注释，但没有强制手段。

## 完成后动作

**完成即停，等 H44。** 未合并主干，未动冻结三链。
