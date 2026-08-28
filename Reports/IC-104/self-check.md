# IC-104 自验报告（single-build-batch，A/B 完成，C 触发规格冲突停线）

覆盖 IC-104 全程：首轮停线（CI #178）、恢复后子项 A 收官（#180）、子项 B 收官（#181）、子项 C 停线（#182）。

## 结论（先行）

**子项 A、B 完成并各自 CI 绿；子项 C 停线——卡内 C1/C2 与 SPEC-S2 v16 存在实质冲突，按 CLAUDE.md 第七节「确有冲突则停下报告」停止，未动用 C 的最后一次 CI 预算。**

- **子项 A 收官**①：CI **#180 success**，被测 `addae570b823ee8903aaa719eaa01e33ac75c7d1`，真实退出码 0，`Executed 519 tests, with 0 failures (0 unexpected) in 34.561 (44.947) seconds`，IPA **836587 字节**、SHA-256 `db4103af99fd41805dc7294f9b9e43cd6ba65f20ede543279bff34f484af3a03`。**闸门 A1 未触发**。
- **子项 B 收官**①：CI **#181 success**，被测 `1e77e6af8dc4839b825d61b0f714fb465000c3bd`，真实退出码 0，`Executed 519 tests, with 0 failures (0 unexpected) in 47.759 (93.661) seconds`，IPA **836633 字节**、SHA-256 `778a9f8f669ad4fdde3a57d429f6680624547a5c2f7b5bea828f63a66d0d5f28`。**闸门 B1 未触发**。
- **子项 C 停线**：实装已完成并提交（`3fbe8cb318908a08cf7338c64474db29fdbf6048`），CI **#182 failure**，`Executed 519 tests, with **37 failures**`。失败不是实现缺陷，而是**卡内要求与规格基线正面冲突**的实测显影——详见「子项 C：规格冲突停线」。**闸门 C1、C2 均未触发**（两者都是"无既有推导可引用/有非截图消费方"才触发，实测都不成立）。
- **CI 预算**：总 6 次，**已用 5 次**（A 2/2、B 1/2、C 1/2）。**剩余 B 1 + C 1 未用。**
- **时间闸门**：恢复开工 2026-08-28T01:49:26Z，到期 07:49:26Z，**未到期**（停线不是超时）。

**Lynn 的可测版本 = CI #181**（详见「Lynn 下载什么」）。**H45 可执行 8 项中的 1–4、6、7（含 3b）**；第 5 项（截图三等距）因 C 未交付而**不可测**。

## 输入与边界

| 项 | 值 |
|---|---|
| 恢复开工时 `git status --porcelain` | 空（纪律 8 检查通过） |
| 前置核对 | IC-106 fix `844b40b840f2b292990f159e31686299b392eb6b`，CI **#179 success**，519/0，退出码 0 ✓ |
| 恢复开工时分支 tip | `65596b92c80132c3c9e441ebbb8d561130e6094e`（与下发单规定值相符，**未重切分支**） |
| 分支 | `feature/ic-104-single-build-batch`（**全程未合并进 `main`**） |
| 分支当前 tip | `3fbe8cb318908a08cf7338c64474db29fdbf6048`（子项 C，红） |
| **最后绿 tip** | **`1e77e6af8dc4839b825d61b0f714fb465000c3bd`（子项 B，CI #181）** |
| 恢复开工时刻 / 时间闸门 | 2026-08-28T01:49:26Z / 07:49:26Z |

## 授权的一次 merge（子项 A 第 2 次预算）

按下发单授权在分支上执行 `git merge main --no-ff`，**未 rebase**：

| 项 | 值 |
|---|---|
| merge 提交 | `addae570b823ee8903aaa719eaa01e33ac75c7d1` |
| 提交信息 | `merge: main (IC-106) into ic-104` |
| 第一父 | `65596b92c80132c3c9e441ebbb8d561130e6094e` |
| 第二父 | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（IC-106 报告提交） |
| merge-base | `0fd97c71b227d99365e64673ae02977f04d5c8a8` |
| 冲突 | **无**（推送前已用只读 `git merge-tree --write-tree --name-only` 预演，只输出一个 tree 哈希、无 `CONFLICT` 行） |

合并后复核①：子项 A 的 `originalPrimaryResource` 与 IC-106 的 `.sorted()` 同时在位，测试计数 519，本地三项门禁退出码全 0。

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

分派由「类型优先」改为「编辑态优先」；已编辑分支的资源选择**直接复用**探针既有规则 `AssetSizeProbeService.primaryResource(in:mediaKind:)`，未新写选择逻辑。枚举 case 随语义由 `fullSizePhotoResource` 改名为 `originalPrimaryResource`（`allCases.count` 仍为 3）。

### 闸门 A1：未触发

A1 的触发条件是「某类型的『原始主资源』选择在探针代码中**无既有规则可复用**」。实测①：`primaryResource(in:mediaKind:)` 三个 `mediaKind` 全覆盖，且明确回答了卡内点名的 LivePhoto 歧义——`.livePhoto` 走照片分支，只在 `.photo` / `.fullSizePhoto` 中选，**`.pairedVideo` / `.fullSizePairedVideo` 不参与、不计入**。前提不成立，故未触发，本卡未自行取定任何资源选择语义。

**由此产生的口径须 Lynn 核**：LivePhoto 的占用空间只含静态图部分。已按下发单增补为 **H45 第 3b 项**（若与系统「信息」页不符，只记差值、不改码）。

### 不变项核对（零语义变化）

| 项 | 结果 |
|---|---|
| 缺失/失败降级只显序号 | 未改（`byteCount` 失败仍返回 `nil`，`subtitleText` 一字未动） |
| 会话级缓存每资产至多取一次 | 未改（`S2AssetVolumeStore` 一字未动） |
| S2 单张 KB/MB/GB 向下截断口径 | 未改（`S2AssetVolumeFormatter` 一字未动） |
| 副行格式 | 未改 |
| 未用任何私有 KVC（G237） | ✓ 只用 `PHAssetResource.type` 公开属性 |
| 禁网络 | ✓ 沿用 `isNetworkAccessAllowed = false` |

### 未覆盖项（如实标注）

`primaryResource(in:mediaKind:)` 的资源选择规则**无单元测试覆盖**：入参与返回值均为 `PHAssetResource`，PhotoKit 不允许在单测中构造；为可测而抽取产品函数属「为测试改产品结构」，纪律 4 禁止。正确性留给 **H45 第 1/2/3/3b 项**真机判定。

## 子项 B：隐藏态竖向手势反转（第 132 条）— 完成

### 行为变更

`V=隐藏` 且 `1x`：
- **上滑完全无效果**——不标记、不改 `D`、不翻页、**不发提示**。守卫置于 `handleSwipeUp` 的 `.alreadyMarked` 语义提示**之前**，否则隐藏态仍会发提示。
- **下滑迁 `V=显示`**，缩放 / 页索引 / `D` / 徽标一律不变。守卫置于 `D` 判断**之前**，迁显示与当前资产是否已标记无关。

`V=显示` 与 `Nx` 分层零变化。「最后一张标记轻提示」（`pendingUndecidedItem`）与 `alreadyMarked` 脉冲因此**只在显示态可达**。

### 闸门 B1：未触发

竖向手势是**单一入口、经状态机统一分派**，无旁路①：

```
S2NativePhotoPager.swift:2938（主图拖动结算）        ─┐
S2NativePhotoPager.swift:3171（handleOneXVerticalGestureIfNeeded）─┴→ machine.completeMainDrag(...)
                                                          └→ handleSwipeUp() / handleSwipeDown()
```

产品目录内 `handleSwipeUp` / `handleSwipeDown` 只有 `completeMainDrag`（`S2StateMachine.swift:1414`、`:1417`）两处调用，其余全在测试目录。未发现绕过状态机直接改 `pendingDeletionAssetIDs` 或 `interfaceVisibility` 的竖向路径。

### B3 卡内取定：过渡动画复用单击同款

**实现代价为零，未改视图层、未新增任何可调参数**（`S2Calibration.swift` 在子项 B 中零 diff）。依据①：显隐过渡由 `S2NativePhotoPager.updatePage` 依 published `interfaceVisibility` 变化触发——

```swift
let presentationChanged = sameAsset &&
    interfaceVisibility != page.interfaceVisibility &&
    isFramedPhoto && page.isFramedPhoto &&
    (fittedSize != page.fittedSize || cornerRadius != page.cornerRadius)
```

`handleSingleTap(on:)` 里的 `pendingPresentationTapPageIndex` / `presentationTapStartTimestamp` **只喂诊断埋点，不参与动画门控**。故状态机在下滑时置 `interfaceVisibility = .visible`，自动走同一条 `startPresentationTransition`（时长仍取 `configuration.presentationToggleDuration`）。

### 手势矩阵的 V 维度（下发单补授权）

`gestureRule(for:context:)` 原本**没有 V 维度**（`S2GestureContext` 仅 `.oneX` / `.nX` / `.albumSheetPresented`）。按下发单补授权新增 `visibility:` 形参（默认 `.visible`，使既有 11 行矩阵断言零改动，符合卡内「`V=显示` 全部手势语义不变」）。该函数**只有测试一个调用方**（`S2StateMachineTests.swift:1299`），产品代码不调用它，风险极低。

`S2GestureEffect` 新增 `.revealInterface`：复用 `.toggleInterface` 会错误暗示对称切换（显示态下滑是取消标记，不是隐藏），故单列。该枚举非 `CaseIterable`，无 `.count` 断言需同步。

### 断言改造（5 处，逐条「旧语义 → 新语义」）

| # | 位置 | 旧语义 | 新语义 |
|---|---|---|---|
| 1 | `IC047_006` 迁移表上滑行第 4 格（`hiddenOneX`） | `conditionalSame` | `ignoredSame`（完全无效果） |
| 2 | `IC047_007` 迁移表下滑行第 4 格 | `conditionalSame` | `availableState(.visibleOneXIdle)`（迁 V） |
| 3 | `IC047_007` 行为断言 | 用 `.hiddenOneX` 验证取消标记 | 移到 `.visibleOneXIdle` 验证取消标记；隐藏态另加「迁 V + 其余状态量不变」断言 |
| 4 | `IC047_026` / `IC047_027` 手势矩阵 | 单行（无 V） | 每行按 `.visible` / `.hidden` 各断言一次；显示态取值一字未改 |
| 5 | `testIC075G107HostedPrimaryMarkPulsesWithoutPhotoGeometryWrites`（`:6753`/`:6756`） | 隐藏态上滑发提示，`consumedNoticeCount == 2` | 隐藏态上滑不发提示，`consumedNoticeCount == 1` |

第 5 处是本卡首轮报告未列出的、在恢复后的只读复核中新发现的：全仓 17 处 `handleSwipeUp`/`handleSwipeDown` 测试调用点中**只有这一处**处于隐藏态，其余均 `.visible`（已逐点核实①）。

**B、C 属行为变更，非削弱**：改造后的断言覆盖面不小于改造前，且新增了「隐藏态上滑不改 D / 不翻页 / 不发提示」「隐藏态下滑只迁 V、其余状态量不变」「Nx 分层不变」三组此前不存在的断言。

## 子项 C：规格冲突停线

### 已完成的实装（提交 `3fbe8cb`，CI #182 红）

- **C1 几何**：截图 1x 适配框改由上下 chrome 推导——顶缘 = 安全区顶 + `S2OverlayLayout.topBarHeight` + 30.7；底缘 = `S2OverlayLayout.stripTopFromViewportBottom(...)` − 30.7。新增纯推导式 `S2ViewportLayout.screenshotBandHeight(physicalSize:safeAreaInsets:bottomStripHeight:)`。`metrics` 新增末位形参 `safeAreaInsets`（默认 `.zero`，30 个既有调用点语义不变），产品两处调用点补传真实安全区。
- **C2**：删除 `fitInsetRatio` 全部 9 个产品点（字段、出厂值、校验、export 行、登记表、CodingKey、decode、encode、标定面板行）。
- **C3**：`schemaVersion` 4 → **6**（跳过被冻结 092 链占用的 5）。
- 断言：计数 44 → 43、decided 35 → 34、`schemaVersion` 断言 4 → 6；六个截图几何测试按新口径改写。
- 本地三项门禁退出码全 **0**。

### 闸门 C1、C2：均未触发①

- **C1**（顶部栏底缘 / 横栏顶缘无既有推导可引用 → 停）：**不成立**。顶部栏底缘有 `S2OverlayLayout.snapshot` 内既有的 `topBounds`（`y = safeFrame.minY`，`height = topBarHeight`）；横栏顶缘有 IC-100 v2 既有推导式 `stripTopFromViewportBottom(safeAreaBottom:bottomStripHeight:)`。本卡未做任何新测量。
- **C2**（`fitInsetRatio` 尚有非截图消费方 → 停）：**不成立**。全仓唯一产品消费点是 `S2ViewportLayout.metrics` 的 `insetScale`，由 `keepsFrame = isScreenshot && …` 门控，无非截图消费方。

### CI #182

| 项 | 值 |
|---|---|
| run 编号 / id | **#182** / `33137588575` |
| 被测提交 | `3fbe8cb318908a08cf7338c64474db29fdbf6048` |
| 起止 | 2026-08-28T03:00:05Z → 03:03:36Z |
| 结论 | **failure**，失败步骤 6「运行 XCTest」（步骤 1–5 全 success） |
| XCTest | `Executed 519 tests, with **37 failures** (0 unexpected) in 30.910 (44.770) seconds` |
| 步骤 7/8 | skipped；artifacts `total_count = 0`，**无 IPA** |
| 真实退出码 | 非 0。**具体数值未取到**：check-run 注解 10 条上限被失败行占满，未含 `Process completed with exit code` 行；job 日志端点（`actions/jobs/{id}/logs`）在本轮网络下经 8 次以上重试仍全部失败。按纪律不复述未取到的数字。 |

**37 项失败未能逐条枚举**（日志端点取不到，注解上限 10 条）。注解可见的三个失败函数①：

```
S2CalibrationHarnessTests.swift:2811–2814
  testIC063G1HiddenScreenAspectScreenshotMatchesScreenBounds
  期望 (0.0, 0.0, 393.0, 852.0)，实得 (50.07, 108.55, 292.86, 634.90)

S2CalibrationHarnessTests.swift:5205 / :5211 / :5260
  testIC064G13ToG18PresentationSamplesMeetGeometryContract
  期望 (210.0, 420.0)，实得 (191.45, 382.90)

S2CalibrationHarnessTests.swift:3150
  testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages
```

### 停线理由：卡内 C1/C2 与 SPEC-S2 v16 正面冲突

失败集中在**规格明文规定的两项行为**上，不是实现缺陷。`<top>/SPEC-S2-20260827_v16.md`（基线 SHA-256 `DD1BD615…434E`）原文①：

| 规格位置 | 原文要点 | 与卡的冲突 |
|---|---|---|
| 第 66 行（回写决策 19） | 「截图资产**在显示态**于 `(1 − fitInsetRatio) × 视口` 框内 aspectFit、居中、带圆角与描边」 | ① 规格**以 `fitInsetRatio` 定义适配框**，卡 C2 要求删除该参数；② 规格的框是「视口的比例缩放」，卡 C1 的框是「chrome 锚定带」，两者是不同的几何结果 |
| 第 121 行 | 「其余条款（显示态内缩带圆角、**隐藏态填满**、`s > 1` 不改变几何、`Nx` 期间推迟应用）**继续有效**」 | 卡 C1「几何与 `V` 显隐无关（隐藏态尺寸不变）」要求隐藏态**不再填满** |
| 第 177 行 | 「界面显隐控制全部浮层是否显示，并**仅按前述截图沉浸规则改变截图资产在 `s = 1` 的尺寸与圆角**」 | 规格明确**要求**尺寸随 `V` 变化；卡要求**不随** `V` 变化 |
| 第 180 行 | 「截图沉浸尺寸与圆角的目标变化**推迟到 `s` 回到 `1` 时应用**」 | 该条以「截图沉浸尺寸变化存在」为前提 |
| 第 743 行 | 废止清单只列 `fitInsetScope`、`screenshotImmersiveOnHide`，**`fitInsetRatio` 不在其中** | 卡 C2 要删的参数在规格中仍是活参数 |
| 第 671 行 | 追溯表把决策 19 映射到第二节数据定义、第三节 S2-1/S2-3、第十一节 | 该行为是规格追溯项，非实现细节 |

**CLAUDE.md 第七节**：「规格定义**行为与几何结果**，不指定实现手段。若任务卡看起来在规定实现方式，按结果理解；**确有冲突则停下报告**。」本冲突恰在「行为与几何结果」层面，不是实现手段之争，故适用停止条款。**修改 SPEC 属第三节默认禁止项**，本卡无权以改规格化解。

**关于「隐藏态尺寸不变」的读法**：本卡先按「与 `V` 无关」实装，依据是卡内自注「同 IC-100 B2 不变量」，而 `testIC100B2GeometryIsIndependentOfInterfaceVisibility`（`S2CalibrationHarnessTests.swift:8328`）断言的正是「几何与界面可见性无关」①，加之 H45 第 5 项写「隐藏态下截图尺寸不变」。该读法与规格第 121/177 行冲突；另一种读法（「隐藏态维持现状即填满」）则与卡内「几何与 `V` 显隐无关」的字面冲突。**两种读法都无法同时满足卡与规格**，故不属于选错读法，而是卡与规格的实质冲突。

**未动用 C 的最后一次 CI 预算**：修复方向取决于上述冲突如何裁定（改规格 / 改卡 / 二者折中），在裁定前任何修法都是猜测；且 37 项失败无法枚举，一次修全的把握不足。按停线条款收口。

## 逐条闸门结果

| 闸门 | 判定 | 依据 |
|---|---|---|
| 恢复开工闸门 | **通过** | 工作树净；分支 tip = `65596b9`；IC-106 `844b40b` CI #179 success 519/0 |
| **A1** | **未触发** | 探针 `primaryResource` 三类型全覆盖，LivePhoto 歧义被明确回答 |
| **G237**（A） | **通过** | 新分派表断言齐备；缓存/降级/格式断言零语义变化；未用私有 KVC。（依赖的资源选择规则无单元覆盖，原因见上，已如实标注） |
| **B1** | **未触发** | 两处产品调用点均经 `completeMainDrag` 统一分派 |
| **G238**（B） | **通过** | 1x 上滑/下滑按 `V` 拆分的迁移表与矩阵断言齐备；`V=显示` 与 `Nx` 相关断言零语义变化 |
| **C1 / C2** | **均未触发** | 见「子项 C」 |
| **G239**（C） | **未达成** | C 停线；`fitInsetRatio` 已全仓清零、`schemaVersion == 6`、四条扫描已记入报告，但几何断言未能通过 CI |
| **G240** | **部分**：最终绿 tip = 子项 B（`1e77e6a`，CI #181 success、退出码 0、519/0、IPA 已登记）；但**三子项未全部落在同一包内** | CI #181 |
| **G241** | **通过** | 每子项独立 commit；A（#180）、B（#181）各自 CI 绿有据；本地三项门禁全 0；冻结三链引用不变 |
| **G242** | **通过** | 本报告两件齐，含测试计数账本与卡内取定登记 |
| 时间闸门（6h） | **未到期** | 恢复开工 01:49:26Z，到期 07:49:26Z |

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 | 理由 |
|---|---|---|---|---|
| A | 0 | **1** | 0 | `testIC099v2C1VolumeRouteDispatchCoversAllFourRows` → `testIC104AVolumeRouteDispatchCoversAllSixRows`：改名（旧名「FourRows」已不实）+ 断言按新表改写 + 增加三类型 × 两编辑态全覆盖循环 |
| B | 0 | **5** | 0 | `IC047_006`、`IC047_007`、`IC047_026`、`IC047_027`、`testIC075G107…`（逐条「旧语义 → 新语义」见上表） |
| C | 0 | 6（**未交付**） | 0 | `testV8…` → `testIC104CScreenshotFitBoxAnchorsChromeWithEqualSpacing`、`D1`、`D2`、`F4`、`IC063G2`、`IC067G36`。C 停线，这 6 处随 `3fbe8cb` 留在分支上但未通过 CI |

| 提交 | 本机测试函数数 | CI Executed |
|---|---|---|
| 继承（`65596b9`） | 519 | — |
| `addae57`（A，merge） | 519 | **519 / 0 失败**（#180） |
| `1e77e6a`（B） | 519 | **519 / 0 失败**（#181） |
| `3fbe8cb`（C） | 519 | 519 / **37 失败**（#182） |

校验：519 + Σ新增 0 − Σ删除 0 = **519** ✓，与 #180、#181 实测吻合。**无静默删除**——A 与 B 的 6 处改造全部是同一测试函数内的重命名或断言改写，原有覆盖全部保留并有扩充。

## CI 记录

| run | id | 被测提交 | 子项 | 结论 | 退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|---|
| #178 | `33131726380` | `209e2d5` | A（首轮） | failure | 65 | 519 / 1 失败（范围外的 `:7923` 顺序抖动，IC-106 已修） | 无 |
| **#180** | `33134112220` | `addae570b823ee8903aaa719eaa01e33ac75c7d1` | **A** | **success** | **0** | **519 / 0** | 836587 字节，`db4103af…3a03` |
| **#181** | `33135136401` | `1e77e6af8dc4839b825d61b0f714fb465000c3bd` | **B** | **success** | **0** | **519 / 0** | **836633 字节，`778a9f8f669ad4fdde3a57d429f6680624547a5c2f7b5bea828f63a66d0d5f28`**；artifact `PhotoCleanupMVE-unsigned-1e77e6af8dc4`（id `9671834388`） |
| #182 | `33137588575` | `3fbe8cb` | C | failure | 非 0（数值未取到） | 519 / **37 失败** | 无 |

**CI 预算**：6 次，已用 **5** 次（A 2 / B 1 / C 1 + 首轮 A 的 #178 计入 A）。剩余 B 1 + C 1 未用。

## 本地门禁（真实退出码）

每子项提交前各跑满三项，全部 **0**：

| 门禁 | merge（A） | B | C |
|---|---|---|---|
| `Scripts/selfcheck.ps1` | 0 | 0 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 0 | 0 |
| `git diff --check` | 0 | 0 | 0 |

## 陷阱 9 四条全量扫描（子项 C，推第一次 CI 前完成）

| 扫描 | 结果 |
|---|---|
| **1. 逐字段构造点**（`grep "S2CalibrationConfiguration("`，排除 `factoryPlaceholder`） | **1 处**：`S2CalibrationHarnessTests.swift:835` 的 `let expected = S2CalibrationConfiguration(`（含 `fitInsetRatio: 0.30,` 一行，已删） |
| **2. 登记表使用点**（`parameterConnections`） | **10 处**：产品 2（`S2Calibration.swift:350` 定义、`S2View.swift:1252` 面板 `ForEach`）+ 测试 8（`S2CalibrationHarnessTests.swift:941 / 1007 / 1357 / 9260 / 9282 / 9345 / 9730`、`S2ImageLoadingStateTests.swift:635`） |
| **3. 字段 / 登记 / 导出集合的字面 `.count` 断言** | **6 条需改**：`fieldNames.count 44→43`、`lines.count 44+4→43+4`、`connections.count 44→43`（两文件各一）、`Set(connections.map(\.name)).count 44→43`、`decided.count 35→34`（两文件各一）。另 1 条为相对式 `exportedNames.count == fieldNames.count + 4`，自动跟随，无需改 |
| **4. `specStatus` / `wiringStatus` 过滤计数** | **5 处**：`S2CalibrationHarnessTests.swift:1012 / 1015 / 9284`、`S2ImageLoadingStateTests.swift:646 / 647`。`fitInsetRatio` 为 `decided`，故 decided 35→34、placeholder 9 不变 |

四条扫描的结论全部落实到 `3fbe8cb` 中。

## 冻结三链与出厂值

| 项 | 值 | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 未触碰 |
| `schemaVersion`（绿 tip `1e77e6a` 上） | **4** | A、B 零出厂值变更，未递增 |
| `schemaVersion`（红 tip `3fbe8cb` 上） | **6** | C 的出厂值集合变更（删 `fitInsetRatio`），按「所有链已用值 + 1」跳过被冻结 092 链占用的 5 |
| 合并进 `main` | **否** | 分支全程独立 |

## Lynn 下载什么

**可测版本 = CI #181**：

| 项 | 值 |
|---|---|
| **run 编号** | **#181**（`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/33135136401`） |
| 被测提交 | `1e77e6af8dc4839b825d61b0f714fb465000c3bd` |
| artifact | `PhotoCleanupMVE-unsigned-1e77e6af8dc4`（id `9671834388`，zip 836803 字节） |
| **IPA 字节数** | **836633** |
| **IPA SHA-256** | **`778a9f8f669ad4fdde3a57d429f6680624547a5c2f7b5bea828f63a66d0d5f28`** |
| 内含 | 子项 **A**（占用空间改原始）+ 子项 **B**（隐藏态手势反转）+ IC-105 / IC-106 的测试侧修复 |
| **不含** | 子项 **C**（截图三等距）——`fitInsetRatio` 与「显示态内缩 0.70 / 隐藏态填满」在该包内**维持规格现状** |

**IPA 复核说明**：字节数与 SHA-256 取自 CI 内「未签名 IPA 校验」步骤注解（CI 侧实算，①）。本机未重下复核——G240 只要求登记，且 IPA 归档不可复现（IC-094/097 证据①），重下哈希不能作跨运行同一性判据。

## H45 人工判定清单（IC-104 卡第六节 + 下发单增补 3b，共 8 项，原样列出）

1. 已编辑照片：S2 占用空间 = 系统「信息」页原始大小（核心项）。
2. 已编辑视频：同上。
3. 未编辑照片/视频各抽一张：数值与此前一致。
3b. **已编辑 LivePhoto 一张，S2 占用空间 vs 系统「信息」页。现实装按探针既有规则只计静态图原始主资源（配对视频不计入）；若与系统口径不符，记录差值即可，不改码，回决策会话定夺。**
4. 隐藏态：1x 上滑无任何反应；下滑回显示态且缩放/页码/标记不变；显示态标记/取消照旧；Nx 照旧。
5. 截图：顶部栏—截图—横栏—操作条三段间距目测等距；非截图资产构图不变；隐藏态下截图尺寸不变。
6. 回归抽查：顶部信息区、底部布局、翻页、双击/捏合、标记→确认页流程。
7. 顺带核查（无代码，第 76 条挂账）：重启 App 观察徽标 88 跨会话残留是否复现。

**本轮可测：1、2、3、3b、4、6、7（七项）。第 5 项不可测**——子项 C 未交付，CI #181 的包里截图几何仍是规格现行口径（显示态 0.70 内缩、隐藏态填满）。

## 卡内取定登记

| # | 子项 | 取定 | 说明 |
|---|---|---|---|
| 1 | A | `fullSizePhotoResource` → `originalPrimaryResource` | 纯改名，随语义扩展（原名只指照片当前版本）。全仓 5 处引用已更新，`allCases.count` 仍为 3 |
| 2 | A | 已编辑分支资源选择直接调用 `AssetSizeProbeService.primaryResource(in:mediaKind:)` | 卡内明文「与 099b 探针同一资源选择规则」，未新写逻辑，不构成新语义取定 |
| 3 | B | 过渡动画复用现行单击显隐同款 | **卡内取定项**（B3）。实现代价为零：视图层由 published `interfaceVisibility` 驱动，未改视图层、未新增可调参数 |
| 4 | B | `S2GestureEffect` 新增 `.revealInterface` | 复用 `.toggleInterface` 会错误暗示对称切换，故单列。枚举非 `CaseIterable`，无计数断言需同步 |
| 5 | B | `gestureRule` 的 `visibility:` 形参取默认值 `.visible` | 使既有 11 行矩阵断言零改动，直接落实卡内「`V=显示` 全部手势语义不变」 |
| 6 | C | 圆角规则维持既有（截图且 `V=显示`），本卡只改尺寸口径 | **未交付**。卡 C1 只说「几何」与 `V` 无关并以「尺寸不变」注解，未提圆角；按「卡未写的不改」处理。该取定随 C 一并待裁定 |

## 发现但未处理的问题（只报告不修）

1. **卡 C1/C2 与 SPEC-S2 v16 的实质冲突**（详见「子项 C」）。这是 C 无法交付的唯一原因，需决策会话在「改规格 / 改卡 / 折中」之间裁定后才能续做。
2. **`Localizable.xcstrings` 有一条文案引用已删参数**：`"fitInsetRatio 生效后的实际显示尺寸：{width} × {height}"`（`:1011`）。属用户可见文案，本卡未授权改动，且该文案随 C 的裁定一并处置更合适。**注意：该文案只在红 tip `3fbe8cb` 上才与代码不一致；绿 tip `1e77e6a` 上参数仍在，文案有效。**
3. **CI #182 的真实退出码数值未取到**：注解 10 条上限被失败行占满；job 日志端点在本轮网络下经 8 次以上重试全部失败。已如实标注，未以推断值代替。
4. **37 项失败无法逐条枚举**（同上）。注解可见 3 个失败函数，其余 34 条无从获取。
5. **`primaryResource` 无单元覆盖**（PhotoKit 类型不可构造），正确性只能由 H45 第 1/2/3/3b 项兜底。
6. **LivePhoto 占用空间只含静态图部分**——复用探针既有规则的直接后果，已列为 H45 第 3b 项。
7. **本机网络**：`git push` 需在 `-c http.proxy=http://127.0.0.1:7890` 与直连之间轮换重试（本轮两种都出现过连续失败）；`gh api` 的 check-run annotations 端点需 2–6 次重试；**job 日志端点本轮完全不可用**。
