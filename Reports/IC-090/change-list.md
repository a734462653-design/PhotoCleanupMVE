# IC-20260823-090 变更清单

分支 `feature/ic-090-strip-corner-pinch-end`，自 `main` = `bf7bab1f8b9fea1194b57151f0beae34fa03756f` 切出。

## 一、提交链（各项独立 commit）

| # | SHA | 类型 | 内容 |
|---|---|---|---|
| 1 | `a0e8d52` | feat | R1-2 参数：新增 `bottomStripCornerRadius`（decided / effective，出厂 2.5 pt），`schemaVersion` 3 → 4 |
| 2 | `323936d` | feat | R1-3 实装：横栏项目内容与待删标记叠层按该半径裁切 |
| 3 | `e9f70db` | test | R1-4 断言：G180、G181（四角 45° 对角线 + 直线扫描、标记叠层）；IC-085 R3 像素门禁按新行为更新 |
| 4 | `3132a4b` | feat | R2-1 探针：场景 C 逐帧五字段 + 五类事件（只加埋点，不改行为） |
| 5 | `64d6bba` | test | R2-1 断言：G182 两项；`Reports/IC-068/export-format.md` 追加 IC-090 节 |
| 6 | `278d382` | fix | CI #32649018232 编译失败修正 + 长字符串拼接拆为局部常量 |
| 7 | `0ab6fa9` | fix | CI #32650455085 两项测试失败修正（IC-085 G162 计数 12→13；G181 标记门禁改用非黑内容与「纯白背景」判据） |

提交 1–5 各自可单独 cherry-pick；6、7 是对 3／5 的定点修正，须随其一起取。

**本报告采用「随代码提交一起推送 + 同分支追加一个 docs 提交」的方式**：报告需要引用推送后才产生的 CI 运行编号与失败明细，故报告本身作为同一张卡、同一分支上的独立 docs 提交追加（纪律第 7 条允许的第二种方式）。纯报告提交不触发 CI（`paths-ignore` 覆盖 `Reports/**` 与 `**.md`），这是预期行为。

## 二、产品代码变更

### `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `S2BottomStripMetrics` 新增 `let cornerRadius: CGFloat`；`isValid` 增加 `cornerRadius >= 0`。

### `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `S2CalibrationConfiguration.schemaVersion`：**3 → 4**。
- 新增存储属性 `bottomStripCornerRadius: Double`，位置在 `bottomStripFlickVelocityThreshold` 与 `bottomStripMarkSize` 之间。
- `factoryPlaceholder` 增加 `bottomStripCornerRadius: 2.5`。
- `resolvedParameters` 把它接进 `S2BottomStripMetrics.cornerRadius`。
- `isValid` 增加 `bottomStripCornerRadius >= 0`。
- `exportText()` 增加一行 `bottomStripCornerRadius=…`。
- `parameterConnections` 增加 `.init(name: "bottomStripCornerRadius", specStatus: .decided, wiringStatus: .effective)`。
- `CodingKeys` / `init(from:)` / `encode(to:)` 三处同步；旧持久化缺该键按 **2.5** 补齐。

### `PhotoCleanupMVE/Features/S2/S2View.swift`
- `S2BottomStripView`：项目在 `.clipped()` 与 `.overlay(alignment: .topTrailing) { stripMark }` **之后**追加 `.clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .circular))`，故内容与标记叠层受同一圆角约束。半径取常量，展开／收缩过程中不随项目尺寸变化。
- `S2ImageContentContext` 新增两个带默认空实现的回调 `onRequestResult` / `onImageReplaced`（IC-090 R2）。
- `pageContent(index:viewportSize:)` 把两个回调接到 `S2ImageLoadStateRegistry` 与诊断协调器：请求结果登记为逐帧字段；图片替换同时登记并追加事件。
- 增加 `import QuartzCore`（`CACurrentMediaTime()`）。

### `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift`
- `S2TemporaryPhotoImageView` 新增两个带默认空实现的回调：`onRequestResult`（在生成号校验之后、对每个返回结果调用一次，含 `cancelled`）、`onImageReplaced`（在 `image = nextImage` 之后调用）。行为不变。

### `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
- 新增 `struct S2ImageReplacementRecord`（assetID / resultName / pixelSize / timestamp）。
- `S2ImageLoadStateRegistry` 增加 `updateRequestResult(_:for:)`、`requestResult(for:)`、`recordImageReplacement(_:)`、`lastImageReplacement`。与录制开关无关，始终登记。
- 新增 `extension S2ImageRequestResult { var diagnosticName: String }`，放在诊断协议段落内（与 `S2ImageLoadState.diagnosticName` 同处，以符合硬编码扫描器的既有豁免边界）。
- `S2NativeZoomScrollView`：
  - **重写 `setZoomScale(_:animated:)`**——记录后原样调 `super`，不改行为；
  - 新增 `diagnosticPresentationZoomScale`（被缩放视图图层 `presentation()` 的 `transform.a`）；
  - `enforceOneXContentGeometry` 增加带默认值的 `diagnosticSource:` 形参，并累计四个布尔（`contentInset` / `contentSize` / `contentOffset` / 照片几何是否真的写了），末尾发一条「吸附归位写入」事件；
  - `restoreOneXGeometry()` 以 `diagnosticSource: "…restoreOneXGeometry"` 调用。
- `S2NativeZoomPageController.scrollViewDidEndZooming`：在既有判定之后、既有分支之前追加一条 `scrollViewDidEndZooming` 事件。判定与分支不变。
- `S2NativePagerViewController.finishNativePinch`：把 `guard let targetScale = …` 拆为 `let targetScale = …` + 分支判定（纯计算）+ 事件记录 + `guard let targetScale else { return }`。状态机仍只调用一次，写入顺序与条件逐字不变。
- `S2NativePagerViewController` 新增 `diagnosticCurrentImageRequestResult`、`diagnosticLastImageReplacement`。
- `S2OnDeviceTransitionFrameSample` 新增五个带默认 `nil` 的字段：`presentationZoomScale`、`isZoomBouncing`、`isDecelerating`、`imageRequestResult`、`lastImageReplacement`。
- `captureFrame()` 填充上述五个字段。
- 协调器新增五个记录方法：`recordScrollViewDidEndZooming`、`recordFinishNativePinch`、`recordSetZoomScale`、`recordOneXSnapBackWrite`、`recordImageReplacement`。全部只在 `isRecording` 为真时追加。
- `S2OnDeviceTransitionText`：头部「逐帧字段」声明行追加五项；逐帧行按 IC-068 / IC-079 / IC-082 / IC-090 拆为四段局部常量后拼接（字段顺序与输出一字不变，只为降低单表达式的类型检查开销）；新增 `imageReplacement(_:)` 格式化；`number(_:)` 由 `private static` 放开为 `static`。

### `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`
- 主图 `S2TemporaryPhotoImageView` 的构造增加 `onRequestResult:` / `onImageReplaced:` 两个透传实参。横栏缩略图那一处不接（诊断只关心主图）。

## 三、测试变更

### 新增（`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`）
- `S2BottomStripSystemReference.cornerRadius = 2.5`，注释记录帧号（30 fps 帧 97–136 / 218–236 / 325–341）、样本量（901 个邻居项目实例 × 4 角）与测量方法。
- 夹具 `renderStrip(markedAssetIDs:markSize:contentWhite:)` + `StripRender`：以 `ImageRenderer` scale = 3 渲染横栏（1 pt = 3 px，与真机 @3x 一致），返回位图与五个项目帧。
- `S2StripBitmap` 增加 `luminance(x:y:)`；`isBackground(x:y:)` 改为基于它（阈值 > 128 不变）。
- `testIC090G180FactoryCornerRadiusMatchesSystemReference`
- `testIC090G181RenderedStripCornersAreClippedByCornerRadius`
- `testIC090G181StripMarkOverlayIsClippedByTheSameCornerRadius`（**当前失败**，见自验报告第五节）
- `testIC090G182PinchEndScenarioExportsNewFieldsAndEvents`
- `testIC090G182ImageRequestResultRegistryTracksLatestResultAndReplacement`

### 修改
- `testIC085R3RenderedStripHasNoBackgroundInsideItemFrames`：帧内背景计数排除四角 `ceil(r) × ceil(r)` 方块；四角断言由「非背景」改为「为背景 + 沿对角线内移 `ceil(r)` 后为内容」。
- `testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`：字段 43 → **44**，导出 47 → **48** 行，`schemaVersion` 3 → **4**。
- `testIC074G97ParameterRegistryDecidedSetMatchesV15`：登记 43 → **44**，decided 集合加入 `bottomStripCornerRadius`，decided 34 → **35**。
- `testIC085G162FactoryBottomStripValuesMatchSystemReference`：横栏 decided+effective 12 → **13**；`referenceMetrics` 增加 `cornerRadius`。
- `testIC087G171SchemaVersionGateDiscardsStaleStoreAndDeletesEntry`：期望版本 3 → **4**；过期样本由 `schemaVersion: 2` 改为 `3`（即 IC-087 旧版）。
- `testIC087G172RestoreFactoryResetsDeletesStoreAndAppliesToCurrentPage`：存储样本 `schemaVersion: 3` → **4**。
- `S2ImageLoadingStateTests`：登记 43 → **44**，decided 34 → **35**。
- `S2StateMachineTests`：`S2BottomStripMetrics(...)` 构造增加 `cornerRadius: 2.5`。

## 四、文档变更

- `Reports/IC-068/export-format.md`：**纯追加**一节「自 IC-090 起的字段追加（格式版本仍为 1）」，20 行新增、0 行删除或修改。内容含场景 C 动作变更、五个逐帧字段的定义与 `nil` 语义、五类事件的来源与 `details` 格式、零副作用与登记表说明。头部「格式版本=1」未递增。

## 五、占位值登记

| 参数 | 规格状态 | 接线状态 | 出厂值 | 来源 |
|---|---|---|---|---|
| `bottomStripCornerRadius` | `decided` | `effective` | **2.5**（pt） | 系统 Photos 录屏 `IMG_6743.MP4` 静止段四角实测 8.08–8.20 px（= 2.69–2.73 pt），按任务卡规则四舍五入到 0.5 pt |

**`schemaVersion` 变更登记（IC-087 定案要求）**：出厂值集合新增 `bottomStripCornerRadius`，`S2CalibrationConfiguration.schemaVersion` 由 **3 递增为 4**。Keychain 中 IC-087 及更早版本的持久化数据会被版本门控整套丢弃并删除条目，新出厂值不会被旧值覆盖。

未新增任何 `factoryPlaceholder` 语义的未定项参数；未改动任何其他出厂值。**未新增 `bottomStripCurrentCornerRadius`**——实测邻居与当前张同半径（差 0.04 pt，小于四角测量极差 0.07 pt）。

## 六、字段与登记计数

| 项 | IC-088 | IC-090 |
|---|---|---|
| 配置字段数 | 43 | **44** |
| 导出行数 | 43 + 4 = 47 | **44 + 4 = 48** |
| 登记表条目 | 43 | **44** |
| 其中 decided | 34 | **35** |
| 其中 placeholder | 9 | 9 |
| 横栏 decided + effective | 12 | **13** |
| `schemaVersion` | 3 | **4** |
| XCTest 项数 | 480（IC-088 CI #149） | **482** |

## 七、状态

- **CI 未绿。** 最后一次运行 `32651137095`（`0ab6fa9`）：482 项测试、1 个测试失败、真实退出码 65。失败项为本卡新增的 `testIC090G181StripMarkOverlayIsClippedByTheSameCornerRadius`，原因在断言取证手法、不在产品行为（诊断见自验报告第五节第 2 小节）。三次修复尝试用尽，按纪律停止。
- **无 IPA 产物**：XCTest 步骤失败即中止作业，工作流未走到打包步骤。
- 未合并 `main`，未 force push，未改写历史。分支保留。
