# IC-093 变更清单

分支 `feature/ic-093-image-upgrade-mark-style`，自 `feature/ic-090-strip-corner-pinch-end` = `420e72a`（被测 `1325c7d`，CI #156，XCTest 482/0）切出。两项互不依赖，各自独立提交。最终被测 `c2be235dad092e3819dc8fbcccadf076f5eab893`。首推的 `0bc8401` 走 CI #161，492 项 2 失败（两条都是本卡自己新增的测试写错，见自验报告）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `b3e4f7e` | R1 | `S2TemporaryPhotoImageStrategy.swift`、`S2View.swift`、`PhotoCleanupMVEApp.swift`、`S2NativePhotoPager.swift`、`S2ImageLoadingStateTests.swift`、`S2CalibrationHarnessTests.swift`、`Reports/IC-068/export-format.md` | 图像替换只升不降 + `图片替换被抑制` 事件 + C0～C6 断言 |
| `0bc8401` | R2 | `S2View.swift`、`S2CalibrationHarnessTests.swift` | 待删标记双色化 + D1～D3 断言 |
| `c2be235` | 测试修正 | `S2ImageLoadingStateTests.swift` | C0 的「更大」用例数据算错、C6 用错了加载态判据（CI #161 定位）。**产品代码零改动** |

两个提交互不依赖：R1 只碰图像请求结果的上屏判定与诊断，R2 只碰标记渲染；共同触及的 `S2View.swift` 是两处互不重叠的区域（R1 改 `S2ImageContentContext` 与页内容构造，R2 改标记视图与两个调用点）。

## R1：图像替换只升不降

### 新增

| 符号 | 位置 | 说明 |
|---|---|---|
| `enum S2ImageUpgradeDecision` | `S2TemporaryPhotoImageStrategy.swift` | 纯函数。`pixelSize(of:)` = 点尺寸 × `scale`；`shouldReplaceDisplayedImage(displayedPixelSize:candidatePixelSize:)`：`displayedPixelSize == nil`（无同资产已显示图）一律放行，否则按像素**面积**比较，候选不低于在显示的才放行 |
| `struct S2ImageReplacementSuppressionReading` | 同上 | 被抑制的一次替换的度量（`result` / `displayedPixelSize` / `candidatePixelSize`），仅供诊断埋点；`assetID` 由上层补 |
| `S2TemporaryPhotoImageView.onImageReplacementSuppressed` | 同上 | 新回调，默认空实现 |
| `S2ImageContentContext.onImageReplacementSuppressed` | `S2View.swift` | 上下文透传属性，默认空实现 |
| `recordImageReplacementSuppressed(assetID:resultName:displayedPixelSize:candidatePixelSize:)` | `S2NativePhotoPager.swift` | 事件 `图片替换被抑制` |

### 修改

| 位置 | 改动 | 是否改变行为 |
|---|---|---|
| `S2TemporaryPhotoImageView.requestImage(for:trigger:)` 结果处理 | 在既有 `S2ImageRequestDecision.shouldDisplay` 之后、`image = nextImage` 之前插入只升不降判定 | 是（R1 的全部行为变化都在这一处） |
| `S2View.pageContent(index:viewportSize:)` | 构造 `S2ImageContentContext` 时接线 `onImageReplacementSuppressed` → `transitionDiagnostics` | 否（只记事件） |
| `PhotoCleanupMVEApp` 主图内容闭包 | 把上下文的新回调透传给 `S2TemporaryPhotoImageView` | 否 |

**抑制判定的单一入口**：`S2TemporaryPhotoImageView.requestImage(for:trigger:)` 结果处理闭包内，`guard S2ImageRequestDecision.shouldDisplay(…)` 之后那一段 `if let displayedImage { … }`。这是产品里唯一一处把 `image` 换掉的位置，因此判定只需挂在这里。

### 未改

请求尺寸算法（`requestKey(for:)`）、请求触发策略（`S2ImageRequestDecision.shouldRequest`）、节流、`S2ImageRequestStrategy` 结构、`degradedPreviewPolicy` 出厂值 `.display`、`scaleChangePolicy`、`cancelled` 与失败分支的既有取定。

## R2：待删标记双色化

### 新增

| 符号 | 位置 | 说明 |
|---|---|---|
| `struct S2PendingDeletionMark: View` | `S2View.swift` | 两处标记的统一渲染：`trash.circle.fill` + `symbolRenderingMode(.palette)` + `foregroundStyle(Color.white, Color.black.opacity(0.55))`。暴露 `symbolName` / `symbolColor` / `circleOpacity` / `circleColor` 四个常量 |

### 修改

| 位置 | 改动 | 是否改变行为 |
|---|---|---|
| `S2BottomStripView.stripMark(for:)` | `Image(systemName:).resizable().scaledToFit().frame(…)` → `S2PendingDeletionMark(size: mark.size)`；`.accessibilityHidden(true)` 保留 | 是（仅颜色） |
| `S2View.primaryMarkOverlay(safeAreaInsets:)` | 同上换成 `S2PendingDeletionMark(size: size)`；其后的 `keyframeAnimator` / `accessibilityLabel` / 两处 `padding` / `frame` / `allowsHitTesting` 一行未动 | 是（仅颜色） |

### 未改

`S2BottomStripMarkPresentation.symbolName` 与 `S2PrimaryMarkPresenter.symbolName`（既有断言直接比对这两个常量，保持 `"trash.circle.fill"`）、`markSize` 派生式、`showsMark` 条件、脉冲动画与 `markPulseDurationMilliseconds`、圆角裁切关系、横栏几何。

## 测试

- 新增 10 个：
  `testIC093C0UpgradeDecisionComparesPixelArea`、`testIC093C1LowerResolutionResultIsSuppressedForSameAsset`、
  `testIC093C2FirstDegradedPreviewStillDisplays`、`testIC093C3AssetChangeAllowsLowerResolutionPreview`、
  `testIC093C4EqualOrHigherResolutionReplaces`、`testIC093C5FailureWithDisplayedImageKeepsDisplayedState`、
  `testIC093C6FinalImageOnlyPolicyIsUnaffected`、`testIC093SuppressedReplacementEventDetails`、
  `testIC093D1StripMarkIsFixedTwoToneAcrossColorSchemes`、`testIC093D2PrimaryMarkIsFixedTwoToneAcrossColorSchemes`。
- **删除 0 个，既有断言一条未削弱**（闸门 C 未触发）。`git diff 420e72a..HEAD -- PhotoCleanupMVETests/` 的删除行只有 `renderStrip` 的形参声明与其上两行注释，替换为含 `colorScheme` 形参的新签名（默认 `.light`，既有调用点行为不变）。
- 新增测试基础设施：`UpgradeAssetModel` / `UpgradeRecorder` / `UpgradeHostView` / `UpgradeHost` / `makeUpgradeHost` / `makeSizedImage`（`S2ImageLoadingStateTests`）、`IC093MarkBox` / `ic093StripMarkBox` / `ic093PrimaryMarkLuminances`（`S2CalibrationHarnessTests`）。
- 计数算式：**482 + 10 − 0 = 492**（CI #161 与 #162 报告的 `Executed` 数一致）。`c2be235` 只改断言内容，不增删测试函数，计数不变。

## 占位值登记

本卡**未新增任何标定参数，未改任何出厂值**。`S2Calibration.swift` 整体 `git diff` 为空，`schemaVersion` 保持 **4**（IC-090 值，未递增）。

R2 的两个色值（`Color.white`、`Color.black.opacity(0.55)`）是④技术负责人取定的固定渲染常量，**不是标定参数**：不进 `S2CalibrationConfiguration`、不进面板、不进登记表、不参与任何几何或时长语义。Lynn 真机可修订（H40 只反馈「偏深 / 偏浅」）。

## 未变更

`S2Calibration.swift`、`S2StateMachine.swift`、`Localizable.xcstrings`（无新增文案）、`Scripts/`、`ci.yml`、`<top>/SPEC-*.md`、`<top>/Decision_log.md` 均无 diff。未新增 XCUITest。未合并主干，未 force push，未改写历史，未动 `feature/ic-089-*` / `feature/ic-091-*` / `feature/ic-092-*`。
