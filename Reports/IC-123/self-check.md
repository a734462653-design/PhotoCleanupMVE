# IC-123 自验报告：S2 两处缺陷修复（指示器切换模式滞后、横屏截图双击比例畸变）——**两子项全绿**

## 结论（先行）

**A、B 两子项交付并绿；CI 用 3/4（A 1/2，B 2/2），串行。** 最终绿 tip（代码）=
`15ddb1f093fa1ce7e5d96e391e7a8adcf300273b`（B 的测试编译修正提交；产品代码最后一次改动在 `9b04eb6`）。

- 子项 A：CI **#233**（run 33580323252），被测提交 `01219d1`，**XCTest 588 项 0 失败**，
  真实退出码 0，IPA 1060237 字节，SHA-256 `25676e0619e2e6e71a1ef92821bd764eaf278351de8556c3d22d0b6d25eeab11`。
- 子项 B：CI **#234**（run 33581124891）**红**——被测提交 `9b04eb6`，`Scripts/test-xcode.sh` 真实退出码 **65**
  （xcodebuild 编译错误，**测试代码**：新用例中比例数组字面量被推断为 `[Any]`，三处 `cannot convert value of type 'Any'`，
  产品代码无错）；修正提交 `15ddb1f` 后 CI **#235**（run 33581402136）**绿**，**XCTest 591 项 0 失败**，
  真实退出码 0，IPA 1060009 字节，SHA-256 `e696ab9c70faee04be4b59c8698ad83d3f4eb9e4eb82d358eb709a2413224a8b`。

`schemaVersion == 7`、登记值、冻结三链、`ci.yml`、`Scripts/` 零改动（**G315**）。**G316** 未触发
（#234 的红是本卡自身测试代码的编译错误，不是无关测试失败；子项 B 的③候选被实测确认而非推翻，见下）。
时间闸门未超。**未合并 `main`，执行完即停。**

- **G313 通过**：开工 `git status --porcelain` 为空，`main` = `f71faae`（`f71faaed34a146b536a284c9066406234554cf77`，
  IC-119 报告提交，短 SHA + 身份比对一致；`git ls-remote` 远端 `main` 同值）。
- **G314 达成**：A（#233）、B（#235）均 success、0 失败、退出码 0、IPA 已登记。

## 输入与范围

- 输入：`IC-20260831-123-s2-two-fixes.md`（两项均 H 实测报障，① Lynn 2026-08-31）。
- 目标分支：`feature/ic-123-s2-fixes`，自 `main`（`f71faae`）切出；继承提交 `f71faae`。
- 范围边界遵守：`main` 未动；SPEC / Decision_log 未动；玻璃材质与布局几何零改动；未 rebase / amend / force push；IC-122 未触碰。

## 子项 A：中央指示切换外观模式滞后（commit `01219d1`）

### 探查结论

卡内要求「结论①写报告」。本机无 iOS 26 真机，CI 模拟器为 iOS 18.5（不走 `glassEffect` 分支），
故**能落到①的只有代码结构与已实测的层序事实；运行时机制本身只能给到③**，如实分级如下。

**①（源码可核）**

1. 撤回钮与其余内容（图标、「已加入「名」」文字、短提示文字）此前用的是**同一个**前景值
   `S2ChromeForeground.onGlassPrimary`（= `Color.primary`，IC-121 A 定案的具体动态色）。颜色取值上没有分叉。
2. 两者唯一的结构差异：撤回钮以 `.overlay(alignment: .trailing)` 挂在 `content.allowsHitTesting(false)` **之外**、
   不在任何 `s2ChromeGlassBackground` 内；图标位于 `glassCircle`（`glassEffect(in: Circle())`）内，
   文字位于胶囊（`glassEffect(in: Capsule())`）内——即**滞后的全部在玻璃子树内，即时的那个在玻璃子树外**。
3. 「翻到别张再翻回来才全部变黑」的代码路径：翻页时 `refreshCenterIndicator(animated: false)` 先把
   `centerIndicatorState` 置 `nil` 再复算，`centerIndicatorOverlay` 的 `if let state` 令
   `S2CenterIndicatorView` **整块移除再插入**——玻璃层随之重建，动态色在新层上重新解析。
4. Decision_log 第 3545 行族（IC-120 已实测①）：iOS 26 `glassEffect` 将玻璃与其内容提升到独立的容器合成层。
5. Lynn 真机 = iPhone18,3 / iOS 26.5.2（Decision_log 第 1582 行，①），故真机走的是 `glassEffect` 分支。

**③归因（由上述①推得；如何验证：H56 第 1 项）**：三个候选中，「内容视图未随 environment 失效」可排除——
文字与撤回钮同在一个 `body` 里，environment 变化对二者一视同仁；「玻璃容器合成缓存」与
「经合成层渲染时动态色解析固化」实为同一件事的两种说法：`Color.primary` 是**动态色**，其最终色值由
承载它的层按 trait 解析；玻璃子树内的内容被提升到独立合成层后，该层对外观切换的 trait 重解析不即时发生
（重建层才刷新），而玻璃外的撤回钮走常规层，即时重解析。

**未排除项（如实）**：无法在本机区分「合成层不接收 trait 变化」与「接收了但缓存了已解析的 CGColor」两种
子机制；两者对本卡修法的响应相同（见下），差异只影响解释，不影响修复。

### 修复（落在成因上）

`S2CenterIndicatorView` 新增 `@Environment(\.colorScheme)` 依赖，并新增
`static func resolvedForeground(for: ColorScheme) -> Color`：按当前 colorScheme 把前景**显式解析为非动态定值色**
（`UIColor.label.resolvedColor(with:)`，浅色黑 / 深色白，与 `Color.primary` 同源、深浅语义不变、
仍不参与 tint 解析）。玻璃子树内的图标与两处文字改用该定值色；外观切换瞬间 `body` 因 colorScheme 变化重算，
新色值作为**内容变更**推入玻璃层，与撤回钮同一拍。撤回钮本就即时跟随，**不改**。
不用翻页刷新、不用定时器、不重建视图身份。

| 验收点 | 测试函数 | 覆盖级别 |
|---|---|---|
| 前景按 colorScheme 显式解析：浅=label 黑、深=label 白、与 `UIColor.label` 两态同值；撤回钮仍为 `Color.primary` | `testIC123AIndicatorForegroundIsResolvedPerColorScheme`（`S2ActionBarWiringTests`） | 夹具事实 |
| **同一实例、不重建、不翻页**：宿主 `overrideUserInterfaceStyle` 深→浅→深原位切换，玻璃内图标/文字随之改色（浅色出现近黑像素、深色为 0） | `testIC123AIndicatorGlassContentFollowsInPlaceAppearanceSwitch` | 夹具驱动，**iOS 18.5 回落配方**；iOS 26 `glassEffect` 合成层真机未覆盖 |

**证据分级**：该渲染测试在 CI（iOS 18.5 模拟器、`.ultraThinMaterial` 回落配方）上**不会复现 H 报障**（③预期：
回落配方不走合成层），它钉住的是「原位切换时内容前景随 colorScheme 重算」这条接线契约。
真机 iOS 26 上修复是否生效，**保留给 H56 第 1 项判定**。若 H56 仍见滞后，下一步候选（③，未实施）是把
玻璃子树的身份绑定 colorScheme（`.id`）令合成层随外观重建——本卡未做，因它是重建而非重解析。

## 子项 B：横屏截图双击放大比例畸变（commit `9b04eb6` + 测试编译修正 `15ddb1f`）

### 探查结论：卡内③候选**确认**（①）

1. **基准写入点唯一**（①）：`S2ViewportLayout.metrics` 中 `nativeZoomBaseSize: isScreenshot ? physicalSize : fitSize`
   （`S2Calibration.swift`），是全项目对该字段的唯一构造点；`S2View` 两处、`S2NativePageContent`、
   `S2NativeZoomScrollView.configure` 都只是搬运。
2. **历史成因**（①，`git log -S`）：提交 `a056126`（2026-08-17「以截图资产元数据驱动 S2 内缩」）把
   `applies ? physicalSize : fitSize` 机械改为 `isScreenshot ? physicalSize : fitSize`。改前 `applies` = 屏幕同比例判定，
   同比例下 `fitSize == physicalSize`，整视口基准无害；改后触发条件是截图元数据，横屏 / 裁切 / iPad 类等
   与视口不同比例的截图从此以**视口比例**为 `s > 1` 基准——与规格 v17 决策 20「基准 = aspectFit 于全视口」不符。
3. **畸变的完整链路**（①，源码）：
   - 双击进入：`S2NativeZoomScrollView.doubleTapTarget` 以 `nativeZoomBaseSize × scale` 算 `presentationFrame`
     → `startDoubleTapTransition` 以之为 `S2DoubleTapTransition.targetFrame`
     → 每帧 `transitionView.transform = transition.transform(at:)`，其中 `a = w(t)/源宽`、`d = h(t)/源高`，
     源帧为 1x 的等比适配帧、目标帧为视口比例，**a ≠ d 即纵向拉伸**（这就是「先把上下填满」）。
   - 落地：`finishActiveDoubleTapTransition` 提交真实几何，宿主视图 bounds = 基准 × scale（视口比例），
     但其内 SwiftUI 图像为 `.resizable().aspectRatio(contentMode: .fit)`，在拉伸的 bounds 内**按比例居中留白**
     ——视觉上「再缩回正常放大态」。过渡层与落地层比例不一致，即用户看到的两段式。
4. **数值（①，按夹具几何 300×600、16:9 截图由代码公式算出）**：fit = 300×168.75，填满倍数 3.5556；
   改前目标帧 1066.67×2133.33（比例 0.5），改后 1066.67×600（比例 1.778）；改前过渡终点 `d/a = 3.556`。

### 修复

`nativeZoomBaseSize: fitSize`——截图与非截图同式，两种 V 相同。**决策 20 语义零改动**（实现修回规格）。
`S2NativePhotoPager.swift` 仅更新一处注释（原注释写着「截图的基准即视口」，随实现改正；`photoCenterYInZoomContent`
公式本就通用，非零顶偏移直接成立，代码未动）。

| 验收点 | 测试函数 | 覆盖级别 |
|---|---|---|
| 异比例截图（16:9、4:3、0.1823）两种 V 下基准 = 全视口 aspectFit，比例 = 资产比，≠ 视口 | `testIC123BNonScreenAspectScreenshotZoomBaseIsFullViewportAspectFit` | 夹具事实 |
| **等价断言**：屏幕同比例截图基准仍 = 视口（fitSize 逐值等于视口）、页基准 = 视口、1x contentSize = 视口、双击目标帧 = 视口 × `minDoubleTapScale`；非截图仍 = aspectFit | `testIC123BScreenAspectScreenshotAndOrdinaryPhotoZoomBaseUnchanged` | 夹具事实 |
| 横屏截图双击：进入源帧 / 目标帧 / 21 点逐进度采样帧宽高比 = 资产比、`transform.a == d`；落地 contentSize 与呈现帧比例 = 资产比、高与视口齐；退出反向同样等比、回到当前 V 的 1x 几何（尺寸 + 带中心） | `testIC123BLandscapeScreenshotDoubleTapKeepsAspectRatioThroughout` | 夹具驱动（`applyRecognizedDoubleTap` + `finishActiveDoubleTapTransition`），真机手势与 CADisplayLink 逐帧未覆盖 |
| 既有：同比例截图双击两向同步帧（IC-063 G4）、⑤a 退出落点（IC-118 B）、裁切截图带内适配（IC-063 G2 / IC-067 G36 / Y2） | 未动仍绿 | — |

**证据分级**：基准公式与过渡帧断言为夹具事实；采样断言针对的是每帧写入过渡层 transform 的同一函数
（`S2DoubleTapTransition.transform(at:)`），真机逐帧观感由 H56 第 2 项判。

## CI 与本地门禁（①）

| 子项 | 运行 | 被测提交 | 结果 | XCTest | 真实退出码 | IPA |
|---|---|---|---|---|---|---|
| A | #233（run 33580323252） | `01219d1d2e8dfb0a1f95ec346441e4be29b752fa` | success | 588 项 0 失败 | 0（`exit "$test_status"`） | 1060237 字节，`25676e0619e2e6e71a1ef92821bd764eaf278351de8556c3d22d0b6d25eeab11` |
| B（第 1 次） | #234（run 33581124891） | `9b04eb67c36b0e5c0871f155646295c075a4dc64` | **failure** | 未执行（编译失败） | **65**（xcodebuild：`S2CalibrationHarnessTests.swift:3656/3662/3679` `cannot convert value of type 'Any'`） | 未产出 |
| B（第 2 次） | #235（run 33581402136） | `15ddb1f093fa1ce7e5d96e391e7a8adcf300273b` | success | 591 项 0 失败 | 0 | 1060009 字节，`e696ab9c70faee04be4b59c8698ad83d3f4eb9e4eb82d358eb709a2413224a8b` |

新增测试 5 条（A 2 / B 3）：#232 的 586 → A 588 → B 591。
本地门禁（三次提交前各跑一遍，均退出码 0）：`Scripts/selfcheck.ps1`、`Scripts/scan-hardcoded-user-visible-strings.ps1`
（用户可见硬编码残留 0）、`git diff --check`。**本机无 Swift 编译器**，#234 那类类型推断错误本地门禁抓不到（陷阱：
`[CGFloat(x), y, z]` 只标注首元素不会把整个字面量推成 `[CGFloat]`，须显式 `let ratios: [CGFloat] = […]`）。

## H56 人工判定清单（保留给 Lynn，不代为下结论）

1. 相簿加入指示显示时来回切深/浅模式：全部前景（图标、「已加入「名」」、撤回钮）即时跟随，不需翻页。
   若仍滞后，请顺带记录分隔线是否也滞后（本卡未动分隔线，见「发现但未处理」第 4 条）。
2. 横屏截图双击进/出各 3 次：全程无比例畸变；竖屏截图与普通照片行为不变。
3. 抽查：中央指示互斥、残影、⑤a 自动隐藏。

## 停线 / 偏差 / 发现但未处理

### 停线
- 未触发。CI 用 3/4（A 1/2，B 2/2）；B 第 1 次红为本卡测试代码编译错误，非产品代码问题、非无关测试失败。

### 偏差（如实）
1. 卡内要求子项 A 探查「结论①写报告」：本机无法产出运行时机制的①，只能给到源码结构① + 机制③（见上）。
   未硬套、未凑逻辑。
2. 子项 B 修复对**近似同比例**截图（比例差在 1% 容差内但不严格相等）会有可观测的微小变化：
   基准从整视口变为 aspectFit（例：402×874 视口、1179×2556 像素截图，基准高 874 → 871.51，差 2.49 pt，②按公式算出）。
   这是规格要求的正确几何（决策 20），非回归；卡内「屏幕同比例截图零变化」以**严格同比例**理解并由等价断言钉住。
3. **cherry-pick 粒度**：B 的产品修复与测试在 `9b04eb6`，测试编译修正在 `15ddb1f`——单独 cherry-pick `9b04eb6`
   会带入编译不过的测试，B 须以 `9b04eb6` + `15ddb1f` 两个 commit 为一组挑取（A 的 `01219d1` 可单独挑取）。
   未用 amend 合并，遵守禁止改写历史。

### 发现但未处理（按纪律只报告不修）
1. 子项 B 的基准变更连带影响两处**间接消费者**（均按规格方向变化，未另作处理）：
   `zoomGeometry.fitSize`（`pinchMaxScale` 的 1:1 基准，规格第十一节「以 s > 1 铺满基准为 1」——异比例截图的上限随之按真实显示宽计算）
   与 `requestBaseSize`（图像请求目标尺寸——PhotoKit 按 aspectFit 交付，宽受限截图交付像素不变，③）。
2. `assetAspectRatio` 未解析时的回退比例（Decision_log 第 3032 行提及的 4:3 fallback）此前对截图基准无影响
   （基准恒取视口），现在会在像素尺寸解析前短暂作用于截图基准；`hasResolvedAssetGeometry` 守卫与解析后
   `configure` 的 `geometryChanged` 重算路径未变（③，真机未观察）。
3. 仓库存在两条 IC-067 时期的 stash（`stash@{0}`、`stash@{1}`），非本卡产生，未触碰。
4. 中央指示的 `Divider()` 仍为系统动态分隔色、位于玻璃子树内；若 A 的③归因成立，它理论上也会滞后，
   但 H 报障未点名，本卡未改。
5. CI 模拟器仍为 iOS 18.5，`glassEffect` 分支（本卡 A 的真因所在）未被 CI 覆盖——IC-122 挂账事项。

## 报告提交

`Reports/IC-123/` 以 docs 提交追加在同卡同分支（需引用推送后才产生的 CI 编号与 IPA 哈希）。
命中 `paths-ignore` 不触发 CI，属预期；验证产品代码的运行为 **#233**（A）与 **#235**（B，最终 tip `15ddb1f`）。
