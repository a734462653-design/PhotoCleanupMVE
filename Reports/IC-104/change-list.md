# IC-104 变更清单（A + B + C v4 全部交付，CI #189 绿）

## C v4：带底缘改锚横栏视觉顶缘（收官，CI #189 绿）

| 项 | 值 |
|---|---|
| **最终绿 tip** | **`7295ed674bfee98cd6ef745854cae31c99ade7a8`** |
| **最终 CI** | **#189 success**（`33187668094`），9/9 步全绿，退出码 0，`Executed 520 tests, with 0 failures` |
| **IPA** | **837917 字节**，SHA-256 **`95009f48990e0dc5d22541a6e4e726474700a53f36697e7a12e603f3d472b643`**；artifact `PhotoCleanupMVE-unsigned-7295ed674bfe`（id `9692840064`，zip 838087） |
| CI 预算（v8+v9） | 2 次，**已用 2 次**（#188、#189） |
| 时间闸门 | v9 15:55:31Z 开工 / 17:25:31Z 到期，**完成于 16:12:08Z** |

### C v4 的两个提交

| # | 完整 SHA | 提交信息首行 | CI |
|---|---|---|---|
| 1 | `4996873e8e102096e5de07913b035bab34a450d1` | `fix(s2): 带底缘改锚横栏视觉顶缘（IC-104 C v4）` | #188 红（520 / 8，全在 `testIC070G77...`） |
| 2 | **`7295ed674bfee98cd6ef745854cae31c99ade7a8`** | `fix(test): 描边探针背景阈值避开 AA 死区（IC-104 C v4）` | **#189 绿（520 / 0）** |

### 文件变化（`0d461cc..7295ed6`，即相对 C v3 绿 tip）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 22 | 4 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 22 | 3 |

**Cv4-2 通过**：产品侧仅一个文件；`stripTopFromViewportBottom` / `resolvedStripHeight` 本体、渲染层、`S2View.swift`、`S2NativePhotoPager.swift`、chrome 布局零 diff；`schemaVersion == 6`；冻结三链未动；`main` 未触碰。

### 关键差异

```diff
+    /// IC-104 C v4：底部横栏的**视觉**顶缘距视口底。
+    /// `stripTopFromViewportBottom` 内含 `resolvedStripHeight = max(44, 横栏高)`
+    /// 的触控带下限，是给手指的**触控锚**；渲染容器用**原始横栏高**，
+    /// 是给眼睛的**视觉锚**。出厂值下两者差 44 - 30 = 14 pt。
+    static func stripVisualTopFromViewportBottom(
+        safeAreaBottom: CGFloat,
+        bottomStripHeight: CGFloat
+    ) -> CGFloat {
+        S2OverlayLayout.stripBottomFromViewportBottom(
+            safeAreaBottom: safeAreaBottom
+        ) + bottomStripHeight
+    }
```

```diff
         let stripTop = physicalSize.height -
-            S2OverlayLayout.stripTopFromViewportBottom(
+            stripVisualTopFromViewportBottom(
                 safeAreaBottom: safeAreaInsets.bottom,
                 bottomStripHeight: bottomStripHeight
             )
```

```diff
         for gray in grays {
-            if gray >= 250 {
+            if gray >= 238 {          // 避开 234-249 的 AA 死区；照片判定不变
```

### 判别实验（#188 -> #189）

#188 的 8 项失败全在 `testIC070G77FitBorderIsConcentricAtCornersBeforeAndAfterToggle` 的**底部两角**，`first = 241`。两种互斥读法：**A** 白与描边的低覆盖 AA 混合（探针死区）；**B** 白与照片 237 的混合（真实亚像素露边）。

判别方法：抬背景阈值、**原样保留照片判定**（`first >= 234` 即 `break`）。若为 B，跳过薄边后下一采样即 237，`first = 237` 仍不满足 `< 234` -> 必然照旧红。**#189 全绿 => 读法 A 实证成立**①，产品描边渲染无误。

**阈值取值更正**：v9 卡内的 `243` 源自我上一份报告写反的比较方向。背景判定是 `gray >= 阈值`（偏白算背景），故须 `阈值 <= 241` 才吞掉 AA 像素、须 `> 237` 才不吞掉照片，**有效窗口 `238...241`**；243 无效（行为等同 250）。实装取 **238**，CI #189 印证。

### 带常量硬编码全量扫描：**0 处**

`382.9` / `191.45` / `289.9` / `270.15` / `29.85` / `450.3` / `561.7` / `17.35`（另 `360.3` / `127.8` / `20.8`）全部 0 处——C v3 已一律写成推导式。

### 卡内数值笔误登记

v8 卡写「夹具带高 382.9 -> 396.9」，但 382.9 是 **C v2** 的值；C v3 为 **360.3**，+14 应为 **374.3**。卡内其余数字（带底缘 464.3、带中心 277.15、跳变量 22.85、393x852 的 575.7）与推导逐个吻合。测试走推导式，不受影响。

**测试函数 520 不变。**

## C v3：等距带改旧位锚定（收官，CI #187 绿）

| 项 | 值 |
|---|---|
| **最终绿 tip** | **`0d461ccd6a7aa54a869d6494e9265785cb2a51b9`** |
| **最终 CI** | **#187 success**（`33178302985`），9/9 步全绿，退出码 0，`Executed 520 tests, with 0 failures` |
| **IPA** | **837925 字节**，SHA-256 **`747a8b6e15ff7443632d6afebb6863bec63b58ba850d8f7d3ed55eabe9c41991`**；artifact `PhotoCleanupMVE-unsigned-0d461ccd6a7a`（id `9688814042`，zip 838095） |
| CI 预算（v7） | 2 次，**已用 2 次**（#186、#187） |
| 时间闸门 | 13:50:56Z 开工 / 16:50:56Z 到期，**完成于 14:11:11Z** |
| `g ≤ 0` / Cv3-3 | 均**未触发**（`testIC100B2` 全程未失败） |

### C v3 的三个提交

| # | 完整 SHA | 提交信息首行 | CI |
|---|---|---|---|
| 1 | `efca05012b1aca63e11c8ee7e6f74c99cc6242ca` | `fix(s2): 等距带改旧位锚定，第三段间距不参与（IC-104 C v3）` | #185 红（520 / 12） |
| 2 | `eb28f223aa92163817327c9d46d4db118b7bf7a6` | `fix(test): 按新契约改写摆放与边界连续性断言（IC-104 C v3 收官）` | #186 红（520 / 1） |
| 3 | **`0d461ccd6a7aa54a869d6494e9265785cb2a51b9`** | `fix(test): X1 反向过渡终点改带中心（IC-104 C v3）` | **#187 绿（520 / 0）** |

### 文件变化（`2d3d789..0d461cc`，即相对 C v2 绿 tip）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 53 | 21 |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 93 | 9 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 1 | 0 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 332 | 52 |

**产品侧仅 3 个文件**，限于截图适配带推导与显示态摆放（含过渡 position 分量），满足 Cv3-2。chrome 布局函数（`actionBandCenterFromViewportBottom`、`stripBottomFromViewportBottom`、`stripTopFromViewportBottom`、`toastBottomFromViewportBottom`）与 `stripToActionVisibleBandSpacing` 的定义与取值**零 diff**；`schemaVersion == 6` 未动；冻结三链未动；`main` 未触碰。

### 关键差异

```diff
+    /// 旧版（v15 比例内缩）显示态截图 = `fitSize × 0.70` 后全视口垂直居中，
+    /// 与视口同比例的截图顶缘恒为 `(1 − 0.70) / 2 = 0.15` 倍视口高。
+    /// **不是可调参数，不进登记表。**
+    static let legacyVisibleFitTopRatio: CGFloat = 0.15
+
+    static func screenshotBandTop(physicalSize: CGSize) -> CGFloat {
+        physicalSize.height * legacyVisibleFitTopRatio
+    }
+
+    static func screenshotBandTopSpacing(
+        physicalSize: CGSize,
+        safeAreaInsets: S2OverlaySafeAreaInsets
+    ) -> CGFloat {
+        screenshotBandTop(physicalSize: physicalSize) -
+            (safeAreaInsets.top + S2OverlayLayout.topBarHeight)
+    }
```

```diff
     let targetPhotoCenter = CGPoint(
         x: targetZoomBounds.midX,
-        y: targetZoomBounds.midY
+        y: oneXPhotoCenterYInZoomContent   // 带中心（显示态截图）／视口中心（其余）
     )
```

```diff
     let photoGroup = presentationAnimationGroup(
-        animations: [scaleAnimation, cornerAnimation],
+        animations: [scaleAnimation, cornerAnimation, positionAnimation],
         duration: duration
     )
```

`fitBorderLayer` **不加** position 分量——它是照片层的子层（`hostingController.view.layer.addSublayer`，帧 = 父层 bounds），随父层平移；再加一份会双重平移。收口沿用既有 `removeAllAnimations()`，两层均清净。

### 测试改造

**新增 1 个**：`testIC104CScreenshotRenderedFrameSitsAtLegacyTopAnchor`——渲染帧摆放断言（补 C v2 缺口）。

**按新契约改写 9 处**（全部精确断言，未放宽容差、未删断言）：

| 类 | 测试 | 新契约 |
|---|---|---|
| (i) | `testIC065G27…SitsAtBandCenter`（改名） | `midY == 带中心`、`minY == 0.15×H`、`视口中心 − 帧中心 == 跳变量` |
| (i) | `testIC063G2…` | `minY == 带顶缘`、`midY == 带中心`（横向对称原样保留） |
| (i) | `testIC065G31…` / `testIC067G41…` | `midY == expected.oneXDisplayCenterY`（覆盖 `.visible` / `.hidden` 两轮） |
| (i) | `testIC067G36…` | `midY == 带中心` |
| (ii) | `testIC065G28ToG29…CentersPerZoomState`（改名） | 每帧中心 == 其所处 `s` 态的规定中心；跳变量写成精确契约；接管后无跳变、横向无跳变原样保留 |
| — | `testIC104C…AnchorsLegacyTopWithEqualGaps`（改名） | 真实配对 393×852；带顶缘 = 0.15×H、`g > 0`、底距 = 顶距、30.7 不参与等距 |
| — | `testIC064G13ToG18…` | 逐采样 `midY` 区间断言 + 两端点精确断言 + position 关键帧断言；曲线/时长不动 |
| — | `testX1…` | `reverseAnchor.y == 带中心`、`viewportAnchor.y − reverseAnchor.y == 跳变量`；`viewportAnchor` / `anchorPoint` / `targetScale` 原样保留且通过 |
| — | `testD1` / `testD2` / `testF4` | 改用 `.zero` 安全区（`g = 42 > 0`）；D2 改核「带顶缘只随视口高变」 |

**新增夹具**：`expectedScreenshotBandCenterY`、`expectedOneXToNxCenterJump`（另有 C v2 遗留的 `expectedScreenshotBandHeight`）。**隐藏态与圆角断言零改动。**

**测试函数 519 → 520**（新增 1，零删除）。

### 行为变更登记（须 Lynn 真机判定）

| # | 变更 | 幅度（393×852） | 依据 |
|---|---|---|---|
| 1 | 显示态截图顶缘回到 `0.15 × 视口高` | 127.8（旧位） | ④ Lynn |
| 2 | 底距 = 顶距 = `g` | 20.8 | ④ Lynn |
| 3 | 显隐切换照片随缩放**竖向平移** | ≈ 17.35 pt，同一 spring 曲线与时长 | 决策会话 v6 选项 A |
| 4 | 捏合/双击进入 `s > 1` 的**瞬时位置跳变** | ≈ 17.35 pt，无过渡 | 决策会话 v7 选项 A |

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 首轮继承提交 | `0fd97c71b227d99365e64673ae02977f04d5c8a8`（IC-105 报告提交） |
| v3 恢复时分支 tip | `65596b92c80132c3c9e441ebbb8d561130e6094e` |
| v4（C v2）开工时分支 tip | `44ca59f4c0dfced6b96a3b2cb67d3427d7136301` |
| 分支 | `feature/ic-104-single-build-batch`（**未重切、全程未合并进 `main`**） |
| **最终绿 tip** | **`2d3d7894e4b2f1c66e889974a8ad5997f4870463`（CI #184）** |
| `main` | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（本卡全程未改） |
| 报告提交 | 只含 `Reports/IC-104/`，命中 `paths-ignore`，**不触发 CI** |

代码提交（6 个，各自可单独 cherry-pick）：

| # | 子项 | 完整 SHA | 提交信息首行 | CI |
|---|---|---|---|---|
| 1 | A | `209e2d552c1b4871ab6eea3b3e794099c3203780` | `feat(s2): 占用空间改取原始资源字节数（IC-104 子项 A，第 133 条）` | #178 红（范围外抖动） |
| 2 | A | `addae570b823ee8903aaa719eaa01e33ac75c7d1` | `merge: main (IC-106) into ic-104` | **#180 绿** |
| 3 | B | `1e77e6af8dc4839b825d61b0f714fb465000c3bd` | `feat(s2): 隐藏态竖向手势反转（IC-104 子项 B，第 132 条）` | **#181 绿** |
| 4 | C v1 | `3fbe8cb318908a08cf7338c64474db29fdbf6048` | `feat(s2): 截图内缩改锚 chrome 三等距（IC-104 子项 C）` | #182 红（规格冲突，已裁定） |
| 5 | C v2 | `b7acd846c7ce609643b8aab16e29210f7b259788` | `fix(s2): 三等距限显示态，保留隐藏态沉浸（IC-104 C v2）` | #183 红（3 项） |
| 6 | **C v2** | **`2d3d7894e4b2f1c66e889974a8ad5997f4870463`** | `fix(test): 修 #183 三项残留（IC-104 C v2，测试侧）` | **#184 绿** |

### 授权的 merge 提交（子项 A 第 2 次预算）

| 项 | 值 |
|---|---|
| SHA | `addae570b823ee8903aaa719eaa01e33ac75c7d1` |
| 第一父 / 第二父 | `65596b92c80132c3c9e441ebbb8d561130e6094e` / `e6bd5aa890bff15b18c4569da4ae73c75f622578` |
| merge-base | `0fd97c71b227d99365e64673ae02977f04d5c8a8` |
| 冲突 | **无**（`git merge-tree` 只读预演 + 实际合并均无冲突） |
| 方式 | `git merge main --no-ff`，**未 rebase** |

## 文件变化

### 子项 A（`65596b9..209e2d5`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2TopBarInfoPresentation.swift` | 16 | 11 |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | 12 | 10 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 30 | 10 |

合计 **3 files, 58 insertions(+), 31 deletions(-)**。

### 子项 B（`addae57..1e77e6a`）

| 文件 | 增 | 删 | 归属 |
|---|---|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | 54 | 11 | 迁移表两行按 V 拆分、`gestureRule` 加 `visibility:`、`S2GestureEffect` 加 `.revealInterface`、两个 handler 加隐藏态守卫 |
| `PhotoCleanupMVETests/S2StateMachineTests.swift` | 107 | 7 | `IC047_006/007/026/027` + `assertGestureRow` 加 V 形参 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 3 | 1 | `testIC075G107…` 的 `consumedNoticeCount` |

合计 **3 files, 164 insertions(+), 19 deletions(-)**。**`S2Calibration.swift` 零 diff——未新增任何可调参数。**

### 子项 C v2（`1e77e6a..2d3d789`，即相对 B 的绿 tip）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 54 | 21 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 6 | 9 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 1 | 1 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | — | — |
| `PhotoCleanupMVETests/S2ImageLoadingStateTests.swift` | 2 | 2 |

**产品侧仅 3 个文件**（`S2Calibration.swift`、`S2View.swift`、xcstrings 一条），满足 Cv2-2。

全程未触碰：`ci.yml`、`Scripts/`、`.xcodeproj`、`S2NativePhotoPager.swift`、SPEC、Decision_log。

## 子项 C v2 关键差异（相对绿 tip `1e77e6a`）

```diff
     ) -> S2ViewportMetrics {
+        let stripHeight = max(
+            CGFloat(configuration.bottomStripCurrentItemSize),
+            CGFloat(configuration.bottomStripNeighborItemHeight)
+        )
+        // IC-104 C v2：截图适配框的上下缘由 chrome 推导，但**仅限 V=显示**。
+        // 隐藏态仍按规格 v16 第 121/177 行填满视口（截图沉浸，行为恒开）。
         let keepsFrame = isScreenshot &&
             presentationState.interfaceVisibility == .visible
-        let insetScale = keepsFrame
-            ? max(0, 1 - CGFloat(configuration.fitInsetRatio))
-            : 1
-        let displaySize = CGSize(
-            width: fitSize.width * insetScale,
-            height: fitSize.height * insetScale
-        )
+        let displaySize = keepsFrame
+            ? S2Geometry.aspectFitSize(
+                viewportSize: CGSize(
+                    width: physicalSize.width,
+                    height: screenshotBandHeight(
+                        physicalSize: physicalSize,
+                        safeAreaInsets: safeAreaInsets,
+                        bottomStripHeight: stripHeight
+                    )
+                ),
+                assetAspectRatio: assetAspectRatio
+            )
+            : fitSize
```

`oneXCornerRadius: keepsFrame ? CGFloat(configuration.fitCornerRadius) : 0` —— **与 `1e77e6a` 逐字相同**，圆角规则一字未改。

新增纯推导式：

```swift
static func screenshotBandHeight(
    physicalSize: CGSize,
    safeAreaInsets: S2OverlaySafeAreaInsets,
    bottomStripHeight: CGFloat
) -> CGFloat {
    let spacing = S2OverlayLayout.stripToActionVisibleBandSpacing
    let bandTop = safeAreaInsets.top + S2OverlayLayout.topBarHeight + spacing
    let bandBottom = physicalSize.height -
        S2OverlayLayout.stripTopFromViewportBottom(
            safeAreaBottom: safeAreaInsets.bottom,
            bottomStripHeight: bottomStripHeight
        ) - spacing
    return max(0, bandBottom - bandTop)
}
```

`metrics` 新增末位形参 `safeAreaInsets: S2OverlaySafeAreaInsets = .zero`（30 个既有调用点语义不变），产品两处调用点（`S2View.swift:464`、`:643`）补传真实安全区。`S2Calibration.swift` 另删除 `fitInsetRatio` 的 9 个产品点（字段、出厂值、校验、export 行、登记表、CodingKey、decode、encode）与 `S2View.swift` 的标定面板滑块行。

## 文案

| 项 | 值 |
|---|---|
| key | `s2.calibration.reading.display_size` |
| 改前 | `fitInsetRatio 生效后的实际显示尺寸：{width} × {height}` |
| 改后 | `三等距适配框生效后的实际显示尺寸：{width} × {height}` |
| diff | **1 增 1 删**，其余字节不动 |
| 扫描确认 | 目录 177 条、产品源码引用 177、用户可见硬编码残留 **0** |

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 |
|---|---|---|---|
| A | 0 | **1** | 0 |
| B | 0 | **5** | 0 |
| C v1 | 0 | 6 | 0 |
| C v2 | 0 | **8**（+2 处夹具/辅助） | 0 |

| 提交 | 本机计数 | CI Executed |
|---|---|---|
| 继承 `65596b9` | 519 | — |
| `addae57`（A） | 519 | **519 / 0 失败** |
| `1e77e6a`（B） | 519 | **519 / 0 失败** |
| `3fbe8cb`（C v1） | 519 | 519 / 37 失败 |
| `b7acd84`（C v2 一轮） | 519 | 519 / 3 失败 |
| **`2d3d789`（C v2 二轮）** | **519** | **519 / 0 失败** |

校验：519 + 0 − 0 = **519** ✓。**无静默删除。**

### C v2 被改造的测试逐条（旧语义 → 新语义）

| # | 测试 | 旧 | 新 | 性质 |
|---|---|---|---|---|
| 1 | `testIC104CScreenshotFitBoxAnchorsChromeWithEqualSpacing` | `hidden.oneXDisplaySize == screenshot.oneXDisplaySize`（V 无关） | `hidden == hidden.aspectFitSize`（填满）+ 圆角 0 + `NotEqual(hidden, visible)` | 回到规格现行行为 |
| 2 | `testIC067G36CroppedScreenshotUsesMetadataDrivenAspectFitFrame` | `hidden == visible` | `hidden == hidden.aspectFitSize` + `NotEqual(hidden, visible)` | 同上 |
| 3 | `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | 短边 = 视口短边 × 0.70 | 改名 `testF1FactoryFitBoxMatchesChromeBandHeight`；高度 = 带高推导式 | 口径变更 |
| 4 | `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | 同上 + 圆角 28 | 改名 `testS1FramedPhotoVisibleStateFitsChromeBandAndRadiusTwentyEight`；圆角断言原样 | 口径变更 |
| 5 | `testIC064G13ToG18PresentationSamplesMeetGeometryContract` | 端点写死 `(210, 420)` / `210` / `300` | 端点由 `metrics(visibility:)` 派生（`visibleSize` / `physicalSize`） | 口径变更 |
| 6 | `testIC069G53PresentationLayerFinishesWhileMainThreadIsBlocked` | 源宽写死 `210` | 源宽由 `metrics(visibility: .visible)` 派生 | 口径变更 |
| 7 | `testIC065G31ScreenshotMetadataKeepsIC063Geometry` | 精确 `XCTAssertEqual` | 加 `accuracy: 0.000_001` | 浮点噪声容差 |
| 8 | `testIC064G20FitBorderKeepsPhotoGeometryUnchanged` | `frameWithBorder?.size` 精确比较 | 两轴按 `accuracy: 0.000_001`；**`page.fittedSize` 精确断言保留** | 同上 |
| 夹具 | 新增 `expectedScreenshotBandHeight(configuration:)` | — | `.zero` 安全区下的带高推导 | 新增 |
| 辅助 | `assertSpringOvershootAndConvergence` 两个分支 | 无条件对 `values[极值下标...]` 做单调检查 | 加 `values.count - index >= 2` 守卫 | 修正既有缺陷 |

**零改动恢复通过的既有测试**（断言的正是要保留的沉浸/过渡行为）：`testIC063G1HiddenScreenAspectScreenshotMatchesScreenBounds`、`testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius`、`testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget`、`testY2CroppedScreenshotHiddenDisplayUsesFullViewportAspectFit`、`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`、`testIC065G32BothDirectionsUseSameSpringCurveAndDuration`、`testIC067G42BothDirectionsAnimateWithoutOuterLayoutPhotoWrites`、`testIC100B2GeometryIsIndependentOfInterfaceVisibility`。

## CI 记录

| run | id | 被测提交 | 子项 | 结论 | 退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|---|
| #178 | `33131726380` | `209e2d5` | A | failure | 65 | 519 / 1 | 无 |
| **#180** | `33134112220` | `addae57` | **A** | **success** | **0** | **519 / 0** | 836587 字节，`db4103af…3a03` |
| **#181** | `33135136401` | `1e77e6a` | **B** | **success** | **0** | **519 / 0** | 836633 字节，`778a9f8f…5f28` |
| #182 | `33137588575` | `3fbe8cb` | C v1 | failure | 非 0（未取到） | 519 / 37 | 无 |
| #183 | `33139876539` | `b7acd84` | C v2 | failure | **65** | 519 / 3 | 无 |
| **#184** | **`33140294919`** | **`2d3d789`** | **C v2** | **success** | **0** | **519 / 0** | **836375 字节，`495d93b79f1df4520ce35aa7c52edfb7ddb885da2e819288637d3f94d4bde2f1`** |

**CI 预算**：6 + C v2 追加 2 = **8 次，已用 8 次**。

## 占位值登记

| tip | `schemaVersion` | 说明 |
|---|---|---|
| `1e77e6a`（B） | 4 | A、B 零出厂值变更 |
| **`2d3d789`（最终绿 tip）** | **6** | C 删除 `fitInsetRatio`，出厂值集合变更；按「所有链已用值 + 1」跳过被冻结 `feature/ic-092-nx-window-follow` 链占用的 5 |

全仓 `schemaVersion` 产品定义唯一（`S2Calibration.swift:118`）。**Lynn 将下载的 #184 包内 `schemaVersion == 6`。**

## 卡内取定登记

| # | 子项 | 取定 | 状态 |
|---|---|---|---|
| 1 | A | `fullSizePhotoResource` → `originalPrimaryResource`（纯改名随语义扩展） | 已交付 |
| 2 | A | 已编辑分支复用 `AssetSizeProbeService.primaryResource(in:mediaKind:)` | 已交付 |
| 3 | B | **B3**：过渡动画复用现行单击显隐同款（零视图层改动、零新增可调参数） | 已交付 |
| 4 | B | `S2GestureEffect` 新增 `.revealInterface` | 已交付 |
| 5 | B | `gestureRule` 的 `visibility:` 取默认值 `.visible` | 已交付 |
| 6 | C | 圆角规则维持既有（截图且 `V=显示`），与尺寸同一门控 | 已交付 |
| 7 | C v2 | 两处浮点噪声按 `accuracy: 0.000_001` 比较（仅渲染帧，`fittedSize` 精确断言保留） | 已交付 |
| 8 | C v2 | `assertSpringOvershootAndConvergence` 加切片长度守卫（修正既有缺陷） | 已交付 |

## 陷阱 9 四条全量扫描（子项 C）

| 扫描 | 结果 |
|---|---|
| 1. 逐字段构造点 | 1 处（`S2CalibrationHarnessTests.swift:835`） |
| 2. 登记表使用点 | 10 处（产品 2 + 测试 8） |
| 3. 字面 `.count` 断言 | 6 条需改 + 1 条相对式自动跟随 |
| 4. `specStatus` / `wiringStatus` 过滤计数 | 5 处；decided 35→34，placeholder 9 不变 |

## 范围核对

| 项 | 结果 |
|---|---|
| 是否合并进 `main` | **否**（`main` 停在 `e6bd5aa`） |
| 是否 rebase / amend / force push / 删分支 | **否**（授权的 merge 是 `--no-ff` 普通合并） |
| 是否 revert C v1 的红提交 | **否**（在其基础上前进修复，符合卡内「不 revert」） |
| 是否修改 SPEC / Decision_log / `ci.yml` / `Scripts/` | **否** |
| 是否触碰冻结三链 | **否**（`b368a6c` / `6736f1e` / `a7cc1ec` 引用未变） |
| 是否改动隐藏态填满 / 过渡 / 圆角语义 | **否**（三者均与 `1e77e6a` 逐条一致） |
| 是否新增可调参数 | **否**（C 删了一个参数，未加） |
| 是否触碰 `S2NativePhotoPager.swift` | **否**（全程零 diff） |
