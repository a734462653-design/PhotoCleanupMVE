# IC-104 变更清单（A + B + C v2 已交付；C v3 摆放勘查后停线）

## C v3：零代码改动

**C v3 在卡内规定的「摆放勘查」一步停线，未产生任何代码提交。**

| 项 | 值 |
|---|---|
| 开工时分支 tip | `d9dd55a770002f42fe19e9f395d3342a563c397f`（与下发单 v5 规定值相符） |
| 产品侧 diff | **零** |
| 测试侧 diff | **零** |
| CI 预算 | **0 / 2 次已用**（未推送） |
| 时间闸门 | 11:59:00Z 开工 / 14:59:00Z 到期，**未到期**（停线非超时） |
| `g ≤ 0` 停线条件 | **不触发**（全部被支持输入下 `g > 0`，最小值 20.8 @ 393×852） |
| 本次唯一改动 | `Reports/IC-104/self-check.md`、`Reports/IC-104/change-list.md`（报告） |

**停线原因**：摆放勘查（卡内明文要求「先于一切改动」）查实 C v2 实际是**视口居中**而非带锚定，据此改摆放会与卡内另两条条款正面冲突——「过渡断言零改动」与「过渡属范围外」。三者不可兼得，且两条化解路分别触犯范围外与纪律 5。完整证据、数值核算与待裁定选项见 `self-check.md`「子项 C v3」。

**勘查产出（可直接用于续做）**：
- `s = 1` 显示态几何写入单一入口 = `S2NativeZoomScrollView.enforceOneXContentGeometry`（`S2NativePhotoPager.swift:761`，落笔 `:805`）
- 带几何数值已核算：夹具 300×600/`.zero` → 带顶缘 90、`g = 42`、带高 360.3、中心偏移 29.85；393×852/顶 59 → 带顶缘 127.8、`g = 20.8`、带高 561.7、**中心偏移 17.35**
- 过渡无位置分量：`addPresentationLayerAnimations`（`:1744`）只构造 `transform.scale` + `cornerRadius`；`S2ImmersiveTransition`（`:36`）只建模锚点/尺寸/圆角
- 冲突断言：`testIC064G13ToG18PresentationSamplesMeetGeometryContract` 逐采样 `XCTAssertEqual(sample.frame.midY, physicalSize.height / 2, accuracy: 0.5)`

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
