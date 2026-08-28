# IC-104 自验报告（single-build-batch，A + B + C v2 全部交付）

覆盖 IC-104 全程：首轮停线（CI #178）、恢复后子项 A 收官（#180）、子项 B 收官（#181）、子项 C v1 规格冲突停线（#182）、子项 C v2 交付（#183 → #184）。

## 结论（先行）

**三个子项全部交付，最终 CI 绿。Lynn 的可测包 = CI #184，含 A + B + C。**

- **最终绿 tip**①：`2d3d7894e4b2f1c66e889974a8ad5997f4870463`
- **最终 CI**①：**#184 success**，9/9 步全绿，**真实退出码 0**，`Executed 519 tests, with 0 failures (0 unexpected) in 44.805 (71.379) seconds`
- **IPA**①：**836375 字节**，SHA-256 **`495d93b79f1df4520ce35aa7c52edfb7ddb885da2e819288637d3f94d4bde2f1`**
- **闸门 A1、B1、C1、C2 全部评估后未触发；Cv2-1、Cv2-2 通过；Cv2-3 的停线信号（`testIC100B2`）未触发**
- **CI 预算**：总 6 + C v2 追加 2 = 8 次，**已用 8 次**（A 2 / B 1 / C v1 1 / C v2 2，另首轮 #178 计入 A）
- **时间闸门**：C v2 开工 2026-08-28T03:34:51Z，到期 06:34:51Z，**完成于 04:01:17Z，未到期**
- **`main` 全程未被触碰**，分支独立；`schemaVersion == 6`；冻结三链未动

**H45 人工判定 8 项全部可测**（第 5 项按下发单 v4 改读）。

## 输入与边界

| 项 | 值 |
|---|---|
| C v2 开工 `git status --porcelain` | 空（纪律 8 检查通过） |
| C v2 开工时分支 tip | `44ca59f4c0dfced6b96a3b2cb67d3427d7136301`（与下发单 v4 规定值相符） |
| 分支 | `feature/ic-104-single-build-batch`（**全程未合并进 `main`**） |
| 分支当前 tip | `2d3d7894e4b2f1c66e889974a8ad5997f4870463` |
| `main` | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（本卡全程未改） |
| C v2 开工时刻 / 时间闸门 | 2026-08-28T03:34:51Z / 06:34:51Z |

## 子项 C v2：三等距限显示态，保留隐藏态沉浸

### 裁定的落实

决策会话废除卡 C1「几何与 `V` 无关（隐藏态尺寸不变）」一句。本卡按修订语义实装：**唯一行为差**是截图资产在 `V=显示` 且 `s=1` 的适配框改为 chrome 锚定带；隐藏态填满、显隐过渡、圆角描边、非截图资产、`s>1` 基准与绿 tip `1e77e6a` 逐条一致。

### 产品侧（相对 `1e77e6a`，逐条对照）

| 项 | `1e77e6a`（绿） | `3fbe8cb`（C v1，红） | **`2d3d789`（C v2）** |
|---|---|---|---|
| 尺寸门控 | `keepsFrame = isScreenshot && V==.visible` | **无门控**（恒用带） | **`keepsFrame` 原样恢复** |
| 门内尺寸 | `fitSize × (1 − fitInsetRatio)` | 带内等比适配 | **带内等比适配** |
| 门外尺寸 | `fitSize`（填满视口） | — | **`fitSize`（填满视口）** |
| 圆角 | `keepsFrame ? fitCornerRadius : 0` | 同条件展开式 | **`keepsFrame ? fitCornerRadius : 0`** |
| `fitInsetRatio` | 在位 | 已删 | **维持已删** |
| `schemaVersion` | 4 | 6 | **维持 6** |

**`S2NativePhotoPager.swift` 全程零 diff**①。显隐过渡与 `Nx` 推迟应用路径由 `metrics` 的 `V` 依赖驱动——`updatePage` 的门控条件是

```swift
let presentationChanged = sameAsset &&
    interfaceVisibility != page.interfaceVisibility &&
    isFramedPhoto && page.isFramedPhoto &&
    (fittedSize != page.fittedSize || cornerRadius != page.cornerRadius)
```

C v1 令几何与 `V` 无关 ⇒ `fittedSize` 与 `cornerRadius` 均不随 `V` 变 ⇒ 过渡不再触发（#182 中多项关键帧断言因此拿到空数组）。恢复 `keepsFrame` 即恢复过渡，**无需改动过渡代码**。

带高推导（`S2ViewportLayout.screenshotBandHeight`）：顶缘 = `safeAreaInsets.top + S2OverlayLayout.topBarHeight + 30.7`；底缘 = `physicalSize.height − stripTopFromViewportBottom(...) − 30.7`。两处 chrome 边缘都引用 IC-100 v2 既有推导式，**本卡未新增任何测量值**。

### 文案（卡内授权）

`Localizable.xcstrings` 的 `s2.calibration.reading.display_size`：「fitInsetRatio 生效后的实际显示尺寸：{width} × {height}」→「三等距适配框生效后的实际显示尺寸：{width} × {height}」。**1 增 1 删，其余字节不动**；扫描确认目录 177 条、产品引用 177、用户可见硬编码残留 0。

### 测试侧：两轮

**第一轮（`b7acd84` → CI #183，519 项 3 失败）**

卡预期「#182 失败的既有测试零改动恢复通过」对一部分测试不成立——我在推 CI 前用全量扫描（`210` / `420` / `0.70`）找出 **7 个硬编码显示态旧口径**的测试并逐个判定：

| 测试 | 判定 | 处理 |
|---|---|---|
| `testIC064G13ToG18PresentationSamplesMeetGeometryContract` | 过渡端点，**同时**含要保留的隐藏态 `physicalSize` 与要改的显示态 210/420 | 端点改由 `metrics(visibility:)` 派生 |
| `testIC069G53PresentationLayerFinishesWhileMainThreadIsBlocked` | 把 `210` 当源宽换算绝对宽度 | 同上 |
| `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | 0.70 短边 | 改名 `testF1FactoryFitBoxMatchesChromeBandHeight`，改带高推导式 |
| `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | 同上 | 改名 `testS1FramedPhotoVisibleStateFitsChromeBandAndRadiusTwentyEight` |
| `testIC065G32BothDirectionsUseSameSpringCurveAndDuration` | **纯数学恒等式** `(210+90v)+(300−90v)≡510`，不调 `metrics` | **零改动**，恒成立 |
| `testIC067G42BothDirectionsAnimateWithoutOuterLayoutPhotoWrites` | `×210` 只是取整粒度，断言「关键帧 distinct 数 > 3」 | **零改动**，恢复门控即自愈 |
| `testIC063NativeBaseResizeIssuesNoImageRequestBeforePinchEnd:2632` | `CGSize(210,420)` 是**宿主视图尺寸输入**，非几何期望 | **零改动** |

同轮把 C v1 的两处「几何与 `V` 无关」断言回改为规格现行行为：`testIC104C…` 与 `testIC067G36…` 均改为 `hidden.oneXDisplaySize == hidden.aspectFitSize`（填满）+ `hidden.oneXCornerRadius == 0` + `NotEqual(hidden, visible)`。

**第二轮（`2d3d789` → CI #184，519 项 0 失败）**

#183 的 3 项失败**均未含 `testIC100B2GeometryIsIndependentOfInterfaceVisibility`**，Cv2-3 停线信号未触发，三项全部落在截图几何/沉浸/本卡改写的测试内，符合「允许用剩余预算修一次」：

| 失败项 | 实测数据 | 归因 | 处理 |
|---|---|---|---|
| `testIC065G31…` `:4985-4986` | `382.9000000000001` vs `382.90000000000003` | **浮点噪声**（差 ~1e-13） | 加 `accuracy: 0.000_001` |
| `testIC064G20…` `:5423` | `(191.45000000000005, 382.9000000000001)` vs `(191.45000000000002, 382.90000000000003)` | 同上 | 同上，**仅改渲染帧一处** |
| `testIC064G13ToG18…` `:5333` | `XCTAssertGreaterThanOrEqual failed: ("1") is less than ("2")` | **辅助函数潜在缺陷** | 加切片长度守卫 |

前两项的成因是口径变化本身：旧口径 `fitSize × 0.70` 是**单次乘法**，两侧位级相同；新带高是**多项加减**推导，经渲染层往返后产生末位噪声。**关键佐证**①：同一测试内 `XCTAssertEqual(page.fittedSize, value.oneXDisplaySize)`（`:5422`）**未失败**，只有走过 CALayer 的 `frame.size` 带噪声——确认是渲染回环伪影而非逻辑差异，故只对后者加容差，`fittedSize` 的精确断言原样保留。

第三项**不是本卡引入的错误**，而是暴露了 `assertSpringOvershootAndConvergence` 的既有缺陷：调用方已显式传 `requiresMeasuredOvershoot: false`（承认可能测不到过冲），函数却仍无条件对 `values[极值下标...]` 做单调检查；无过冲时极值即末样本，切片只剩 1 个元素，而 `assertMonotonic`（`:8549`）要求至少 2 个。**单元素本就平凡单调**，故加长度守卫，两个分支对称处理。端点断言（首 ≈0 / 末 ≈28）一字未动，**未放宽任何产品语义**。

### 零改动恢复通过的既有测试（断言的正是要保留的行为）①

`testIC063G1HiddenScreenAspectScreenshotMatchesScreenBounds`、`testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius`、`testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget`、`testY2CroppedScreenshotHiddenDisplayUsesFullViewportAspectFit`、`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`、`testIC100B2GeometryIsIndependentOfInterfaceVisibility`（该测试针对**浮层**几何，与截图主图几何无关，故 C v2 前后均通过）。

其中 `testS4…` 断言 `XCTAssertNotEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)`——**要求 `V` 依赖**，C v1 下必失败、C v2 恢复后重新成立，与修订语义自洽。

## 子项 A：占用空间改原始资源字节数（第 133 条）— 完成

### 分派表变更

| mediaKind | isEdited | 改前（IC-099） | 改后（IC-104 A） |
|---|---|---|---|
| photo | false | `contentEditingInputURL` | 不变 |
| livePhoto | false | `contentEditingInputURL` | 不变 |
| video | false | `videoAssetURL` | 不变 |
| photo | true | `fullSizePhotoResource`（`.fullSizePhoto` = **当前版本**） | `originalPrimaryResource`（**原始**主资源） |
| livePhoto | true | 同上 | `originalPrimaryResource` |
| **video** | **true** | **`videoAssetURL`（URL = 当前版本）** | **`originalPrimaryResource`** |

分派由「类型优先」改为「编辑态优先」；已编辑分支的资源选择**直接复用**探针既有规则 `AssetSizeProbeService.primaryResource(in:mediaKind:)`，未新写选择逻辑。

### 闸门 A1：未触发

触发条件是「某类型的『原始主资源』选择在探针代码中无既有规则可复用」。实测①：`primaryResource(in:mediaKind:)` 三个 `mediaKind` 全覆盖，且明确回答了卡内点名的 LivePhoto 歧义——`.livePhoto` 走照片分支，只在 `.photo` / `.fullSizePhoto` 中选，**`.pairedVideo` / `.fullSizePairedVideo` 不参与、不计入**。前提不成立，本卡未自行取定任何资源选择语义。

**由此产生的口径须 Lynn 核**：LivePhoto 的占用空间只含静态图部分。已列为 **H45 第 3b 项**（若与系统「信息」页不符，只记差值、不改码）。

### 不变项核对

| 项 | 结果 |
|---|---|
| 缺失/失败降级只显序号 | 未改（`byteCount` 失败仍返回 `nil`，`subtitleText` 一字未动） |
| 会话级缓存每资产至多取一次 | 未改（`S2AssetVolumeStore` 一字未动） |
| S2 单张 KB/MB/GB 向下截断口径 | 未改（`S2AssetVolumeFormatter` 一字未动） |
| 未用任何私有 KVC（G237） | ✓ 只用 `PHAssetResource.type` 公开属性 |
| 禁网络 | ✓ 沿用 `isNetworkAccessAllowed = false` |

### 未覆盖项（如实标注）

`primaryResource(in:mediaKind:)` 的资源选择规则**无单元测试覆盖**：入参与返回值均为 `PHAssetResource`，PhotoKit 不允许在单测中构造；为可测而抽取产品函数属「为测试改产品结构」，纪律 4 禁止。正确性留给 **H45 第 1/2/3/3b 项**真机判定。

## 子项 B：隐藏态竖向手势反转（第 132 条）— 完成

### 行为变更

`V=隐藏` 且 `1x`：
- **上滑完全无效果**——不标记、不改 `D`、不翻页、**不发提示**。守卫置于 `handleSwipeUp` 的 `.alreadyMarked` 语义提示**之前**。
- **下滑迁 `V=显示`**，缩放 / 页索引 / `D` / 徽标一律不变。守卫置于 `D` 判断**之前**，迁显示与当前资产是否已标记无关。

`V=显示` 与 `Nx` 分层零变化。

### 闸门 B1：未触发

竖向手势是**单一入口、经状态机统一分派**，无旁路①：`S2NativePhotoPager.swift:2938`（主图拖动结算）与 `:3171`（`handleOneXVerticalGestureIfNeeded`）均经 `machine.completeMainDrag(...)` → `handleSwipeUp()` / `handleSwipeDown()`。产品目录内两个 handler 只有 `completeMainDrag`（`S2StateMachine.swift:1414`、`:1417`）两处调用，其余全在测试目录。

### B3 卡内取定：过渡动画复用单击同款

**实现代价为零，未改视图层、未新增任何可调参数**（`S2Calibration.swift` 在子项 B 中零 diff）。依据同上：显隐过渡由 published `interfaceVisibility` 变化驱动，状态机在下滑时置 `.visible` 即自动走同一条 `startPresentationTransition`。

### 手势矩阵的 V 维度（下发单 v3 补授权）

`gestureRule(for:context:)` 原本无 V 维度，新增 `visibility:` 形参（默认 `.visible`，使既有 11 行矩阵断言零改动）。该函数**只有测试一个调用方**（`S2StateMachineTests.swift:1299`），产品代码不调用。`S2GestureEffect` 新增 `.revealInterface`（复用 `.toggleInterface` 会错误暗示对称切换；该枚举非 `CaseIterable`，无 `.count` 断言需同步）。

## 逐条闸门结果

| 闸门 | 判定 | 依据 |
|---|---|---|
| 恢复开工闸门（v3） | **通过** | 工作树净；tip = `65596b9`；IC-106 `844b40b` CI #179 success 519/0 |
| C v2 开工闸门（v4） | **通过** | 工作树净；tip = `44ca59f` |
| **A1** | **未触发** | 探针 `primaryResource` 三类型全覆盖，LivePhoto 歧义被明确回答 |
| **G237**（A） | **通过** | 新分派表断言齐备；缓存/降级/格式断言零语义变化；未用私有 KVC |
| **B1** | **未触发** | 两处产品调用点均经 `completeMainDrag` 统一分派 |
| **G238**（B） | **通过** | 1x 上滑/下滑按 `V` 拆分的迁移表与矩阵断言齐备；`V=显示` 与 `Nx` 零语义变化 |
| **C1 / C2**（v1） | **均未触发** | chrome 两缘均有 IC-100 v2 既有推导式；`fitInsetRatio` 无非截图消费方 |
| **Cv2-1** | **通过** | #184 success、519/0、真实退出码 0、IPA 已登记 |
| **Cv2-2** | **通过** | 产品 diff 仅 `S2Calibration.swift` / `S2View.swift` / xcstrings 一条；`schemaVersion == 6` 唯一；冻结三链未动 |
| **Cv2-3** | **未触发停线** | #183 三项失败均不含 `testIC100B2`，全部落在截图几何/沉浸/改写测试内；用剩余预算修一次后转绿 |
| **G239**（C） | **达成** | `fitInsetRatio` 产品零残留、`schemaVersion == 6`、四条扫描已记入报告、几何断言 CI 绿 |
| **G240** | **通过** | 三子项**全部落在同一包内**（#184），IPA 已登记 |
| **G241** | **通过** | 每子项独立 commit；A（#180）、B（#181）、C（#184）各自 CI 绿有据；本地三项门禁全 0 |
| **G242** | **通过** | 本报告两件齐，含测试计数账本与卡内取定登记 |
| 时间闸门（C v2，3h） | **未到期** | 03:34:51Z 开工，04:01:17Z 完成，到期 06:34:51Z |

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 |
|---|---|---|---|
| A | 0 | **1** | 0 |
| B | 0 | **5** | 0 |
| C v1（`3fbe8cb`） | 0 | 6 | 0 |
| C v2 | 0 | **8**（+2 处夹具/辅助） | 0 |

C v2 改造的 8 个测试：`testIC104C…`、`testIC067G36…`（隐藏态回改沉浸）、`testF1…`、`testS1…`（改名 + 带高推导）、`testIC064G13ToG18…`、`testIC069G53…`（端点改派生）、`testIC065G31…`、`testIC064G20…`（浮点容差）。另新增私有夹具 `expectedScreenshotBandHeight()`，并给 `assertSpringOvershootAndConvergence` 的两个分支各加一处切片长度守卫。

| 提交 | 本机测试函数数 | CI Executed |
|---|---|---|
| 继承（`65596b9`） | 519 | — |
| `addae57`（A，merge） | 519 | **519 / 0 失败**（#180） |
| `1e77e6a`（B） | 519 | **519 / 0 失败**（#181） |
| `3fbe8cb`（C v1） | 519 | 519 / 37 失败（#182） |
| `b7acd84`（C v2 一轮） | 519 | 519 / 3 失败（#183） |
| **`2d3d789`（C v2 二轮）** | **519** | **519 / 0 失败**（#184） |

校验：519 + Σ新增 0 − Σ删除 0 = **519** ✓。**无静默删除**——全部改造都是同一测试函数内的重命名或断言改写，原有覆盖保留并有扩充（B、C 各新增了此前不存在的断言组）。

## CI 记录

| run | id | 被测提交 | 子项 | 结论 | 退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|---|
| #178 | `33131726380` | `209e2d5` | A（首轮） | failure | 65 | 519 / 1（范围外 `:7923`，IC-106 已修） | 无 |
| **#180** | `33134112220` | `addae57` | **A** | **success** | **0** | **519 / 0** | 836587 字节，`db4103af…3a03` |
| **#181** | `33135136401` | `1e77e6a` | **B** | **success** | **0** | **519 / 0** | 836633 字节，`778a9f8f…5f28` |
| #182 | `33137588575` | `3fbe8cb` | C v1 | failure | 非 0（数值未取到） | 519 / 37 | 无 |
| #183 | `33139876539` | `b7acd84` | C v2 | failure | **65** | 519 / 3 | 无 |
| **#184** | **`33140294919`** | **`2d3d789`** | **C v2** | **success** | **0** | **519 / 0**（44.805 / 71.379 秒） | **836375 字节，`495d93b79f1df4520ce35aa7c52edfb7ddb885da2e819288637d3f94d4bde2f1`** |

**CI 预算**：6 + C v2 追加 2 = 8 次，**已用 8 次**。

## 本地门禁（真实退出码）

每次提交前各跑满三项，全部 **0**：

| 门禁 | merge（A） | B | C v1 | C v2 一轮 | C v2 二轮 |
|---|---|---|---|---|---|
| `Scripts/selfcheck.ps1` | 0 | 0 | 0 | 0 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 0 | 0 | 0 | 0 |
| `git diff --check` | 0 | 0 | 0 | 0 | 0 |

## 陷阱 9 四条全量扫描（子项 C，推第一次 CI 前完成）

| 扫描 | 结果 |
|---|---|
| **1. 逐字段构造点**（排除 `factoryPlaceholder`） | **1 处**：`S2CalibrationHarnessTests.swift:835` |
| **2. 登记表使用点**（`parameterConnections`） | **10 处**：产品 2（`S2Calibration.swift:350`、`S2View.swift:1252`）+ 测试 8 |
| **3. 字段 / 登记 / 导出集合的字面 `.count` 断言** | **6 条需改**（44→43、44+4→43+4、connections 两文件、Set(names)、decided 两文件）+ 1 条相对式自动跟随 |
| **4. `specStatus` / `wiringStatus` 过滤计数** | **5 处**；`fitInsetRatio` 为 `decided`，故 decided 35→34、placeholder 9 不变 |

## 冻结三链与出厂值

| 项 | 值 | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 未触碰 |
| `schemaVersion`（最终绿 tip） | **6** | C 删除 `fitInsetRatio`，出厂值集合变更；按「所有链已用值 + 1」跳过被冻结 092 链占用的 5 |
| 合并进 `main` | **否** | 分支全程独立，`main` 停在 `e6bd5aa` |

## Lynn 下载什么

| 项 | 值 |
|---|---|
| **run 编号** | **#184**（`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/33140294919`） |
| 被测提交 | `2d3d7894e4b2f1c66e889974a8ad5997f4870463` |
| artifact | `PhotoCleanupMVE-unsigned-2d3d7894e4b2`（id `9673769485`，zip 836545 字节） |
| **IPA 字节数** | **836375** |
| **IPA SHA-256** | **`495d93b79f1df4520ce35aa7c52edfb7ddb885da2e819288637d3f94d4bde2f1`** |
| 内含 | 子项 **A** + 子项 **B** + 子项 **C**，以及 IC-105 / IC-106 的测试侧修复 |

**IPA 复核说明**：字节数与 SHA-256 取自 CI 内「未签名 IPA 校验」步骤注解（CI 侧实算，①）。本机未重下复核——G240 只要求登记，且 IPA 归档不可复现（IC-094/097 证据①），重下哈希不能作跨运行同一性判据。

## H45 人工判定清单（8 项，第 5 项按下发单 v4 改读，原样列出）

1. 已编辑照片：S2 占用空间 = 系统「信息」页原始大小（核心项）。
2. 已编辑视频：同上。
3. 未编辑照片/视频各抽一张：数值与此前一致。
3b. 已编辑 LivePhoto 一张，S2 占用空间 vs 系统「信息」页。现实装按探针既有规则只计静态图原始主资源（配对视频不计入）；若与系统口径不符，记录差值即可，不改码，回决策会话定夺。
4. 隐藏态：1x 上滑无任何反应；下滑回显示态且缩放/页码/标记不变；显示态标记/取消照旧；Nx 照旧。
5. 截图：显示态顶部栏—截图—横栏—操作条三段间距目测等距；**隐藏态截图仍填满屏幕（沉浸行为与现版一致）**；显隐切换时截图尺寸过渡正常；非截图资产构图不变。
6. 回归抽查：顶部信息区、底部布局、翻页、双击/捏合、标记→确认页流程。
7. 顺带核查（无代码，第 76 条挂账）：重启 App 观察徽标 88 跨会话残留是否复现。

**8 项全部可测。**

## 卡内取定登记

| # | 子项 | 取定 | 说明 |
|---|---|---|---|
| 1 | A | `fullSizePhotoResource` → `originalPrimaryResource` | 纯改名随语义扩展；全仓 5 处引用已更新，`allCases.count` 仍为 3 |
| 2 | A | 已编辑分支复用 `AssetSizeProbeService.primaryResource(in:mediaKind:)` | 卡内明文，未新写逻辑 |
| 3 | B | **B3**：过渡动画复用现行单击显隐同款 | 实现代价为零，未改视图层、未新增可调参数 |
| 4 | B | `S2GestureEffect` 新增 `.revealInterface` | 复用 `.toggleInterface` 会错误暗示对称切换 |
| 5 | B | `gestureRule` 的 `visibility:` 取默认值 `.visible` | 使既有 11 行矩阵断言零改动 |
| 6 | C | 圆角规则维持既有（截图且 `V=显示`），与尺寸同一门控 | 卡只改尺寸口径，未提圆角，按「卡未写的不改」处理 |
| 7 | C v2 | 两处浮点噪声按 `accuracy: 0.000_001` 比较 | 仅对经渲染层往返的 `frame`；`fittedSize` 精确断言保留 |
| 8 | C v2 | `assertSpringOvershootAndConvergence` 加切片长度守卫 | 修正既有缺陷（单元素平凡单调），未放宽任何产品语义 |

## 发现但未处理的问题（只报告不修）

1. **`S2CalibrationHarnessTests.swift:9909` 有一条过期注释**：IC-090 的历史叙述仍写「`schemaVersion == 4`（v2 保持不变）」，而同函数末尾的实际断言已是 `XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 6)`。**仅注释不一致，不影响断言**；该注释属 IC-090 测试，不在本卡范围内。
2. **`Scripts/verify-IC-20260815-05x.ps1` 系列引用已重命名的测试名**（如 `testV8FitInsetRatioGeometryAndScopeAreCorrect`、`testD2ZeroFitInsetMatchesPureAspectFit`、`testF1FactoryInsetShrinksShortEdgeToSeventyPercent`）。这些是各卡历史验证脚本，**不在 CI 门禁之列**（`ci.yml` 只跑 `selfcheck.ps1` 与硬编码扫描），且其中部分自 IC-067 起就已过期，非本卡引入。`Scripts/` 在本卡范围外，未动。
3. **`primaryResource` 无单元覆盖**（PhotoKit 类型不可构造），正确性只能由 H45 第 1/2/3/3b 项兜底。
4. **LivePhoto 占用空间只含静态图部分**——复用探针既有规则的直接后果，已列为 H45 第 3b 项。
5. **CI #182 的真实退出码数值未取到**：注解 10 条上限被失败行占满；job 日志端点在该轮网络下经 8 次以上重试全部失败，37 项失败无法逐条枚举。已如实标注，未以推断值代替。（#183 的退出码 65 取到了。）
6. **本机网络**：`git push` 需在带代理与直连之间轮换重试（本轮两种都出现过连续失败，最终一次是直连成功）；`gh api` 的 annotations 端点需 2～6 次重试；**job 日志端点本轮完全不可用**。
