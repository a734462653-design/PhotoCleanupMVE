# IC-20260823-090 变更清单 v2

> 本文件是 **v2 完整版**，覆盖 v1。含阶段一（R1／R2）与阶段二（R3／R4）全部变更。

分支 `feature/ic-090-strip-corner-pinch-end`，自 `main` = `bf7bab1f8b9fea1194b57151f0beae34fa03756f` 切出，未重切、未 rebase、未合并主干、未改写历史。

- 产品 tip：`1325c7dca3d8626ff768f2cc469b649fb293e0ef`（CI **#156** success）
- IPA：`782141` 字节，SHA-256 `cbeb7bef63460a2566191c88556f2a6951c4bb91bf446f0b31310e005b9e4933`（本地重下校验一致）

## 一、提交链

| # | SHA | 阶段 | 类型 | 内容 |
|---|---|---|---|---|
| 1 | `a0e8d52` | 一 | feat | R1-2 参数：新增 `bottomStripCornerRadius`（decided / effective），`schemaVersion` 3 → 4 |
| 2 | `323936d` | 一 | feat | R1-3 实装：横栏项目内容与待删标记叠层按该半径裁切 |
| 3 | `e9f70db` | 一 | test | R1-4 断言：G180、G181 两支；IC-085 R3 像素门禁按新行为更新 |
| 4 | `3132a4b` | 一 | feat | R2-1 探针：场景 C 逐帧五字段 + 五类事件（只加埋点，不改行为） |
| 5 | `64d6bba` | 一 | test | R2-1 断言：G182 两项；`Reports/IC-068/export-format.md` 追加 IC-090 节 |
| 6 | `278d382` | 一 | fix | CI #151 编译失败修正 + 长字符串拼接拆为局部常量 |
| 7 | `0ab6fa9` | 一 | fix | CI #153 两项测试失败修正 |
| 8 | `6912982` | 一 | docs | 阶段一自验与变更清单（v1） |
| 9 | `df2b3ae` | **二** | **feat** | **R3：出厂值改定为 `8.0 / 3.0` pt，G181 几何阈值按 r = 8 px 重算** |
| 10 | `7bb7b50` | **二** | **test** | **R4：G181 标记断言改为只在右上 `markSize × markSize` 框内取证** |
| 11 | `1325c7d` | **二** | **fix** | **`S2StripBitmap` 的 y 方向修正为自上而下（CI #155 定位）** |

阶段二三个提交各自可 cherry-pick（`1325c7d` 是 `7bb7b50` 的定点修正，须随其一起取）。

**报告提交方式**：报告需引用推送后才产生的 CI 运行编号、失败明细与 IPA 校验值，故作为同一张卡、同一分支上的独立 docs 提交追加（纪律第 7 条允许的第二种方式）。纯报告提交不触发 CI（`paths-ignore` 覆盖 `Reports/**` 与 `**.md`），这是预期行为。

## 二、产品代码变更

### `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `S2BottomStripMetrics` 新增 `let cornerRadius: CGFloat`；`isValid` 增加 `cornerRadius >= 0`。

### `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `S2CalibrationConfiguration.schemaVersion`：**3 → 4**（阶段二保持 4，理由见自验报告第十一节）。
- 新增存储属性 `bottomStripCornerRadius: Double`，位置在 `bottomStripFlickVelocityThreshold` 与 `bottomStripMarkSize` 之间。
- `factoryPlaceholder` 与 `init(from:)` 的解码缺省值：阶段一 `2.5` → **阶段二 `8.0 / 3.0`**（两处同一表达式书写，逐位相等）。
- `resolvedParameters` 把它接进 `S2BottomStripMetrics.cornerRadius`；`isValid` 增加 `>= 0`。
- `exportText()` 增加一行 `bottomStripCornerRadius=2.666667`。
- `parameterConnections` 增加 `.init(name: "bottomStripCornerRadius", specStatus: .decided, wiringStatus: .effective)`。
- `CodingKeys` / `encode(to:)` 同步。

### `PhotoCleanupMVE/Features/S2/S2View.swift`
- `S2BottomStripView`：项目在 `.clipped()` 与 `.overlay(alignment: .topTrailing) { stripMark }` **之后**追加 `.clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .circular))`，故内容与标记叠层受同一圆角约束。半径取常量。
- `S2ImageContentContext` 新增两个带默认空实现的回调 `onRequestResult` / `onImageReplaced`。
- `pageContent(index:viewportSize:)` 把两个回调接到 `S2ImageLoadStateRegistry` 与诊断协调器。
- 增加 `import QuartzCore`。
- **阶段二未动本文件一行**（R4 禁止为让断言通过而改产品代码）。

### `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift`
- `S2TemporaryPhotoImageView` 新增两个带默认空实现的回调：`onRequestResult`（生成号校验之后，对每个返回结果调用一次，含 `cancelled`）、`onImageReplaced`（`image = nextImage` 之后）。行为不变。

### `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
- 新增 `struct S2ImageReplacementRecord`（assetID / resultName / pixelSize / timestamp）。
- `S2ImageLoadStateRegistry` 增加 `updateRequestResult(_:for:)`、`requestResult(for:)`、`recordImageReplacement(_:)`、`lastImageReplacement`；与录制开关无关，始终登记。
- 新增 `extension S2ImageRequestResult { var diagnosticName: String }`，放在诊断协议段落内（符合硬编码扫描器的既有豁免边界）。
- `S2NativeZoomScrollView`：重写 `setZoomScale(_:animated:)`（记录后原样调 `super`）；新增 `diagnosticPresentationZoomScale`；`enforceOneXContentGeometry` 增加带默认值的 `diagnosticSource:` 形参并累计四个布尔，末尾发「吸附归位写入」事件；`restoreOneXGeometry()` 传入对应来源。
- `S2NativeZoomPageController.scrollViewDidEndZooming`：追加 `scrollViewDidEndZooming` 事件；判定与分支不变。
- `S2NativePagerViewController.finishNativePinch`：拆为「取值 → 分支判定（纯计算）→ 事件记录 → `guard let`」；状态机仍只调用一次，写入顺序与条件逐字不变。
- 新增 `diagnosticCurrentImageRequestResult`、`diagnosticLastImageReplacement`。
- `S2OnDeviceTransitionFrameSample` 新增五个带默认 `nil` 的字段。
- `captureFrame()` 填充上述五个字段。
- 协调器新增五个记录方法，全部只在 `isRecording` 为真时追加。
- `S2OnDeviceTransitionText`：头部「逐帧字段」声明行追加五项；逐帧行按 IC-068 / IC-079 / IC-082 / IC-090 拆为四段局部常量后拼接（字段顺序与输出一字不变）；新增 `imageReplacement(_:)`；`number(_:)` 由 `private static` 放开为 `static`。

### `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`
- 主图 `S2TemporaryPhotoImageView` 的构造增加 `onRequestResult:` / `onImageReplaced:` 两个透传实参。横栏缩略图那一处不接。

## 三、测试变更

### 新增（`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`，共 5 项，删除 0 项）
- `S2BottomStripSystemReference.cornerRadius`：阶段一 `2.5` → **阶段二 `8.0 / 3.0`**；注释记录帧号（30 fps 帧 97–136 / 218–236 / 325–341）、样本量（执行端 901 个邻居实例 × 4 角、技术负责人 759 个实例）与取值依据。
- 夹具 `renderStrip(markedAssetIDs:markSize:contentWhite:)` + `StripRender`：以 `ImageRenderer` scale = 3 渲染横栏（1 pt = 3 px，与真机 @3x 一致）。
- `S2StripBitmap` 增加 `luminance(x:y:)`；`isBackground(x:y:)` 改为基于它（阈值 > 128 不变）。
- `testIC090G180FactoryCornerRadiusMatchesSystemReference`
- `testIC090G181RenderedStripCornersAreClippedByCornerRadius`
- `testIC090G181StripMarkOverlayIsClippedByTheSameCornerRadius`
- `testIC090G182PinchEndScenarioExportsNewFieldsAndEvents`
- `testIC090G182ImageRequestResultRegistryTracksLatestResultAndReplacement`

### 阶段二对测试的修改
- **`S2StripBitmap.luminance(x:y:)` 的 y 方向修正**：去掉多余的 `(height - 1 - y)` 翻转，改为按 `y` 直接索引。`CGBitmapContext` 的内存首行即图像顶行，原式反而把 y 变成自下而上，与其文档注释相反。该缺陷自 IC-085 引入后一直被既有断言的上下对称性掩盖，由本卡右上角标记断言首次暴露（CI #155 的自诊断输出直接定位）。全仓仅本文件使用该结构，17 个调用点逐一核对后确认无回归，CI #156 实测 482 项 0 失败。
- **`testIC090G181RenderedStripCornersAreClippedByCornerRadius`**：直线（首行／末行、首列／末列）背景区间由偏移 0…2 **收紧**为 0…3——r = 8 px 下偏移 3 的覆盖率为精确 0.000（r = 7.5 px 时为 0.016）。对角线阈值（0/1 背景、3…7 内容）覆盖率仍为 0.000 / 1.000，不变。只按几何重算，未放宽任何一项。
- **`testIC090G181StripMarkOverlayIsClippedByTheSameCornerRadius`**：整支重写。删除 v1 的整帧逐像素比较（其「两项目除标记外逐像素相同」的前提在渲染位图里不成立），改为只在已标记项目右上 `markSize × markSize` 框内取证：(a) 该角 45° 对角线偏移 0/1 为背景；(b) 框内存在明显暗于内容色（≥ 8 级）的像素；(c) 框外不做逐像素比较。内容色沿用非黑 `Color(white: 0.1)`。失败时打印框边界、内容色、框内最暗／最亮读数与降采样位图（闸门 C 所需证据）。
- **`testIC090G180FactoryCornerRadiusMatchesSystemReference`（= G190）**：出厂值以 `accuracy: 1e-9` 比对 `8.0 / 3.0` 与参考表；导出断言改为 `bottomStripCornerRadius=2.666667`；新增「@3x 下正好 8 个设备像素」断言。

### 阶段一对既有测试的修改
- `testIC085R3RenderedStripHasNoBackgroundInsideItemFrames`：帧内背景计数排除四角 `ceil(r) × ceil(r)` 方块；四角断言由「非背景」改为「为背景 + 沿对角线内移 `ceil(r)` 后为内容」。（`ceil(8/3) = ceil(2.5) = 3`，阶段二未再改。）
- `testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`：字段 43 → **44**，导出 47 → **48** 行，`schemaVersion` 3 → **4**。
- `testIC074G97ParameterRegistryDecidedSetMatchesV15`：登记 43 → **44**，decided 集合加入 `bottomStripCornerRadius`，decided 34 → **35**。
- `testIC085G162FactoryBottomStripValuesMatchSystemReference`：横栏 decided+effective 12 → **13**；`referenceMetrics` 增加 `cornerRadius`。
- `testIC087G171SchemaVersionGateDiscardsStaleStoreAndDeletesEntry`：期望版本 3 → **4**；过期样本由 `schemaVersion: 2` 改为 `3`（即 IC-087 旧版）。
- `testIC087G172RestoreFactoryResetsDeletesStoreAndAppliesToCurrentPage`：存储样本 `schemaVersion: 3` → **4**。
- `S2ImageLoadingStateTests`：登记 43 → **44**，decided 34 → **35**。
- `S2StateMachineTests`：`S2BottomStripMetrics(...)` 构造增加 `cornerRadius`（阶段二同步为 `8.0 / 3.0`）。

## 四、文档变更

- `Reports/IC-068/export-format.md`：**纯追加**一节「自 IC-090 起的字段追加（格式版本仍为 1）」，**20 行新增、0 行删除或修改**（`git diff bf7bab1..HEAD --numstat` = `20  0`）。头部「格式版本=1」未递增。

## 五、占位值登记

| 参数 | 规格状态 | 接线状态 | 出厂值 | 来源 |
|---|---|---|---|---|
| `bottomStripCornerRadius` | `decided` | `effective` | **`8.0 / 3.0`**（pt，= 8 px @3x，导出 `2.666667`） | 系统 Photos 录屏静止段四角实测：执行端 8.08–8.20 px、技术负责人 8.22–8.37 px；取最接近的 @3x 整像素值。④ Lynn 2026-08-23 定案（选 A） |

**`schemaVersion` 不递增的理由**：`schemaVersion` 在阶段一由 3 递增为 4；阶段二改动了 `bottomStripCornerRadius` 的出厂值但**保持 4**。理由：(1) schema 4 从未随任何可安装包发出——阶段一四次 CI 均在 XCTest 步骤失败，未走到打包步骤，CI #156 是第一个带 schema 4 的包；(2) 真机 Keychain 里仍是 schema 3 的数据，任何 schema 4 的包都会由版本门控整套丢弃并按当前出厂值重建，新出厂值不会被旧值覆盖；(3) 故这是同一未发布版本内的出厂值调整，不构成需要区分的持久化格式代际。IC-087 定案要求递增的目的（防旧值覆盖新出厂值）在此情形下不存在风险。**一旦 Lynn 装过带 schema 4 的包，再改出厂值就必须递增为 5。**

未新增任何 `factoryPlaceholder` 语义的未定项参数；未改动任何其他出厂值。**未新增 `bottomStripCurrentCornerRadius`**——实测邻居与当前张同半径。

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
| XCTest 项数 | 477（`main` 基线） | **482**（算式 477 + 5 − 0） |

## 七、CI 记录

| # | 运行编号 | 被测提交 | 结论 | 退出码 | 说明 |
|---|---|---|---|---|---|
| 151 | 32649018232 | `e9f70db…` | failure | 65 | 编译错误：G96 期望配置未跟上新参数 |
| 152 | 32649784298 | `64d6bba…` | failure | 65 | 同一处编译错误 |
| 153 | 32650455085 | `278d382…` | failure | 65 | 482 项 2 失败 |
| 154 | 32651137095 | `0ab6fa9…` | failure | 65 | 482 项 1 个测试失败（阶段一三次尝试用尽，停下报告） |
| 155 | 32653136006 | `7bb7b50…` | failure | 65 | 482 项 2 失败，自诊断输出定位到位图 y 方向缺陷 |
| **156** | **32653618003** | **`1325c7dca3d8626ff768f2cc469b649fb293e0ef`** | **success** | **0** | **482 项 0 失败；IPA 782141 字节，SHA-256 `cbeb7bef…4933`，本地重下一致** |

## 八、状态

- **CI 全绿**（#156），真实退出码 0，XCTest 482 项 0 失败，IPA 已产出并本地校验一致。
- 阶段二 CI 用满 2 次上限，以全绿收口；闸门 C、D 均未触发。
- 未合并 `main`，未 force push，未改写历史。分支保留。
- **完成即停**，等 Lynn 真机（H36 + 场景 C 录制）。
