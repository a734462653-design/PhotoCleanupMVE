# IC-104 自验报告（single-build-batch，停线收口）

## 结论（先行）

**本卡未完成，停在子项 A。触发停线：子项 A 的 CI 无法在本卡授权范围内转绿——唯一失败点是范围外的既存测试缺陷，本卡无权修改。子项 B、C 未实装。**

- **子项 A：已实装并提交**（`209e2d552c1b4871ab6eea3b3e794099c3203780`），本地三项门禁真实退出码全 **0**。
- **CI #178 = failure**，但**失败与子项 A 无关**①：`Executed 519 tests, with **1 failure** (0 unexpected) in 58.412 (105.178) seconds`，唯一失败是
  `S2CalibrationHarnessTests.swift:7923` 的
  `testIC099v2C2StoreFetchesEachAssetAtMostOnce`——
  `XCTAssertEqual failed: ("["asset-2", "asset-1"]") is not equal to ("["asset-1", "asset-2"]")`。
  **子项 A 的全部新断言均通过**（519 项中除该 1 项外全绿，产品与测试完整编译）。
- **闸门 A1：评估后未触发**①——099b 探针的 `AssetSizeProbeService.primaryResource(in:mediaKind:)` 是既有可复用规则，且对 LivePhoto 给出明确答案（只取 `.photo`，**配对视频不计入**）。详见「闸门 A1 评估」。
- **子项 B：未实装**。卡内「绿了才开下一子项」未满足。B 的**只读勘查**已完成并记录在案（**闸门 B1 评估后未触发**），未产生任何代码改动。
- **子项 C：未勘查、未实装。**
- **CI 预算**：总 6 次，**已用 1 次**（A 1 / B 0 / C 0）。**时间闸门**：开工 2026-08-28T00:57:03Z，到期 06:57:03Z，**未到期**。
- **G240 不满足**：分支上**没有绿 tip**，**没有 IPA**。**H45 无可测版本**——见「Lynn 可下载什么」。

**人工判定：H45 七项原样列于第「H45 人工判定清单」节，本卡不代 Lynn 下任何结论；但当前无包可测。**

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空（纪律 8 检查通过） |
| 前置核对 | IC-105 fix `46f7174b2475c3cbd06bb9af73b9af1f109bfde4`，CI **#177 success**，XCTest **519 项 0 失败**，真实退出码 0 ✓ |
| 继承提交（IC-105 后的 `main` tip） | `0fd97c71b227d99365e64673ae02977f04d5c8a8` |
| 分支 | `feature/ic-104-single-build-batch`（自继承提交切出，全程未合并进 `main`） |
| 分支 tip | `209e2d552c1b4871ab6eea3b3e794099c3203780`（子项 A） |
| 开工时刻 / 时间闸门 | 2026-08-28T00:57:03Z / 06:57:03Z |
| CI 预算 | 6 次（A 2 / B 2 / C 2），**已用 1 次** |

## 子项 A：占用空间改原始资源字节数（第 133 条）

### 分派表变更

| mediaKind | isEdited | 改前（IC-099） | 改后（IC-104 A） |
|---|---|---|---|
| photo | false | `contentEditingInputURL` | `contentEditingInputURL`（不变） |
| livePhoto | false | `contentEditingInputURL` | `contentEditingInputURL`（不变） |
| video | false | `videoAssetURL` | `videoAssetURL`（不变） |
| photo | true | `fullSizePhotoResource`（`.fullSizePhoto` = **当前版本**） | `originalPrimaryResource`（**原始**主资源） |
| livePhoto | true | `fullSizePhotoResource`（当前版本） | `originalPrimaryResource`（原始主资源） |
| **video** | **true** | **`videoAssetURL`（URL = 当前版本）** | **`originalPrimaryResource`（原始主资源）** |

分派逻辑由「类型优先」改为「编辑态优先」：

```swift
static func route(mediaKind:isEdited:) -> S2AssetVolumeRoute {
    if isEdited { return .originalPrimaryResource }
    return mediaKind == .video ? .videoAssetURL : .contentEditingInputURL
}
```

已编辑分支的资源选择**直接复用**探针既有规则
`AssetSizeProbeService.primaryResource(in:mediaKind:)`，未新写选择逻辑：

```swift
case .originalPrimaryResource:
    guard let resource = AssetSizeProbeService.primaryResource(
        in: resources, mediaKind: mediaKind
    ) else { return nil }
    return await streamedByteCount(of: resource)
```

枚举 case `fullSizePhotoResource` 随语义改名为 `originalPrimaryResource`（原名只指「照片当前版本」，改后覆盖三类型的原始资源，原名已不实）。`S2AssetVolumeRoute.allCases.count` 仍为 **3**。

### 不变项（零语义变化）核对

| 不变项 | 核对结果 |
|---|---|
| 缺失/失败降级只显序号 | 未改。`byteCount` 失败仍返回 `nil`；`S2TopBarInfoPresentation.subtitleText` 一字未动；`testIC099v2C1FailureDegradesToPositionOnly` 未改且通过 |
| 会话级缓存每资产至多取一次 | 未改。`S2AssetVolumeStore` 一字未动 |
| S2 单张 KB/MB/GB 向下截断口径 | 未改。`S2AssetVolumeFormatter` 一字未动 |
| 副行格式 | 未改 |
| 未用任何私有 KVC（G237） | ✓ 复用的探针规则只用 `PHAssetResource.type` 公开属性；本卡未新增任何 KVC |
| 禁网络 | ✓ `streamedByteCount` 沿用 `options.isNetworkAccessAllowed = false` |

### 闸门 A1 评估：**未触发**

A1 的判据是「某类型的『原始主资源』选择在探针代码中**无既有规则可复用**（语义歧义，如 LivePhoto 配对视频是否计入）」。实测①：

```swift
/// 主资源：优先取**原始**类型，取不到再退回全尺寸（当前版本）类型。
static func primaryResource(
    in resources: [PHAssetResource],
    mediaKind: S2AssetSizeProbeMediaKind
) -> PHAssetResource? {
    if mediaKind == .video {
        return resources.first { $0.type == .video }
            ?? resources.first { $0.type == .fullSizeVideo }
    }
    return resources.first { $0.type == .photo }
        ?? resources.first { $0.type == .fullSizePhoto }
}
```

三个 `mediaKind` 全部有既有规则覆盖，且 LivePhoto 的歧义点被该规则明确回答：`mediaKind == .livePhoto` 走照片分支，只在 `.photo` / `.fullSizePhoto` 中选，**`.pairedVideo` / `.fullSizePairedVideo` 不参与选择、不计入字节数**。故「无既有规则可复用」的前提不成立，A1 不触发，本卡未自行取定任何资源选择语义。

**须提请注意（不是自行取定，是复用既有规则的直接后果）**：LivePhoto 的占用空间因此**只含静态图部分**。若 Lynn 期望与系统「信息」页一致而系统把配对视频计入，H45 第 1/3 项会暴露该差异。本卡按卡复用探针规则，未改动它。

### 断言改造

| 项 | 内容 |
|---|---|
| 改造 | `testIC099v2C1VolumeRouteDispatchCoversAllFourRows` → `testIC104AVolumeRouteDispatchCoversAllSixRows`（改名 + 按新表改断言） |
| 旧语义 → 新语义（逐条） | ① `route(.video, isEdited: true) == .videoAssetURL` → `== .originalPrimaryResource`（**行为变更**，第 133 条）<br>② `route(.photo, isEdited: true) == .fullSizePhotoResource` → `== .originalPrimaryResource`（**语义变更**：当前版本 → 原始资源；常量改名同时改语义）<br>③ `route(.livePhoto, isEdited: true)` 同 ②<br>④ 三条未编辑行（photo / livePhoto / video）**零变化**<br>⑤ `S2AssetVolumeRoute.allCases.count == 3` **零变化** |
| 新增断言（同一函数内） | 三类型 × 两编辑态的全覆盖循环：`route == .originalPrimaryResource` 当且仅当 `isEdited`；`S2AssetSizeProbeMediaKind.allCases.count == 3` |
| 缓存 / 降级 / 格式断言 | **零变化**（`testIC099v2C2` / `C3` / `C4` / `C1FailureDegradesToPositionOnly` 一字未改） |

**未覆盖项（如实标注）**：`primaryResource(in:mediaKind:)` 的资源选择规则**无单元测试覆盖**。原因：其入参与返回值均为 `PHAssetResource`，PhotoKit 不允许在单测中构造该类型；为使其可测而把选择顺序抽成纯函数属「为测试改产品结构」，纪律 4 明令禁止。该规则的正确性留给 **H45 第 1/2/3 项**真机判定。

### 测试计数账本（子项 A）

| 项 | 数 |
|---|---|
| 继承态（`0fd97c7`） | 519 |
| 新增 | **0** |
| 改造 | **1**（`testIC099v2C1VolumeRouteDispatchCoversAllFourRows` → `testIC104AVolumeRouteDispatchCoversAllSixRows`，改名 + 断言按新表改写并扩充） |
| 删除 | **0** |
| 本机计数（`209e2d5`） | **519** |
| CI #178 实测 Executed | **519** |

校验：519 + 0 − 0 = **519** ✓。**无静默删除**：改造项是同一测试的重命名 + 断言扩充，原有六格分派断言全部保留并按新表更新，另加一层全覆盖循环。

## CI #178

| 项 | 值 |
|---|---|
| run 编号 | **#178** |
| run id | `33131726380` |
| 被测提交 | `209e2d552c1b4871ab6eea3b3e794099c3203780` |
| 分支 | `feature/ic-104-single-build-batch` |
| 起止 | 2026-08-28T01:04:40Z → 01:11:09Z |
| 结论 | **failure** |
| 失败步骤 | 步骤 6「运行 XCTest」（步骤 1–5 全 success） |
| **真实退出码** | **65**（注解原文 `Process completed with exit code 65.`） |
| XCTest | `Executed 519 tests, with **1 failure** (0 unexpected) in 58.412 (105.178) seconds` |
| 步骤 7/8 | skipped；run artifacts `total_count = 0`，**无 IPA** |

唯一失败①：

```
S2CalibrationHarnessTests.swift:7923: error:
  -[PhotoCleanupMVETests.S2CalibrationHarnessTests testIC099v2C2StoreFetchesEachAssetAtMostOnce]
  : XCTAssertEqual failed: ("["asset-2", "asset-1"]") is not equal to ("["asset-1", "asset-2"]")

Test Case '-[... testIC099v2C2StoreFetchesEachAssetAtMostOnce]' failed (0.818 seconds).
```

## 停线：失败点在范围外，本卡无权处置

### 失败与子项 A 无关（①）

1. 失败函数 `testIC099v2C2StoreFetchesEachAssetAtMostOnce` 属 IC-099 阶段二，断言的是 `S2AssetVolumeStore` 的会话级缓存与 `CountingAssetVolumeProvider` 的记录，**与本卡改动的分派表、`AssetVolumeService.byteCount` 的已编辑分支毫无调用关系**。
2. 本卡未触碰该测试、未触碰 `S2TopBarInfoPresentation.swift` 的 `S2AssetVolumeStore`、未触碰该 helper。
3. `Executed 519 tests` 且只有这 1 项失败——**子项 A 的全部新断言（六行分派表 + 全覆盖循环）均通过**，产品与测试完整编译。
4. 行号由 `:7903`（CI #175 / #178 之前）位移到 `:7923`，恰等于本卡在其之前净增的 20 行（30 增 − 10 删），断言正文一字未改。

### 与 IC-105 的关系：锁生效了，但该测试仍非确定性

同一测试的三次 CI 表现①：

| CI | 被测 | 现象 | `requestCount`（`:7929`） |
|---|---|---|---|
| #175 | `33d639a`（IC-102 v2） | `["asset-2"]` vs `["asset-1","asset-2"]`，**且** `1` vs `2` | **失败**（丢更新） |
| #177 | `46f7174`（IC-105 NSLock） | 通过 | 通过 |
| #178 | `209e2d5`（IC-104 A） | `["asset-2","asset-1"]` vs `["asset-1","asset-2"]` | **通过** |

**结论**①：IC-105 的 NSLock **确实消除了丢更新**（#178 中 `requestCount == 2` 通过，两条记录都在），残留的是**完成顺序不确定**。

**归因（③，标注为推测）**：`S2AssetVolumeStore.requestIfNeeded` 对 asset-1 与 asset-2 各起一个 `Task { @MainActor }`，其中 `await provider.byteCount(assetID:)` 因协议方法非隔离而跳到并发执行器；两个 Task 的完成顺序不受语言保证，因此 `requestedAssetIDs` 的**元素顺序**本就不确定。`XCTAssertEqual(provider.requestedAssetIDs, ["asset-1", "asset-2"])` 对并发填充的数组做**顺序敏感**断言，属**过度规定**。

**这是测试设计缺陷，不是产品缺陷**：产品侧的不变量是「每资产至多取一次」（由 `requestCount == 2` 断言，本次通过），并不包含「取数顺序等于请求顺序」；要让产品保证顺序须串行化取数，那才是行为变更。

**验证方式**（本卡不实施）：把 `:7923` 改为顺序无关断言（`Set(provider.requestedAssetIDs) == ["asset-1","asset-2"]`，配合已有的 `requestCount == 2`），或改为逐资产 `contains` 断言。

### 为什么停在这里，而不是用掉 A 的第二次预算

A 的预算是 2 次，已用 1 次，**未用尽**。但第二次预算在本卡授权内**无法合法使用**：

1. **不能修那个测试**。它属 IC-099/IC-105 范围；CLAUDE.md 纪律「发现问题写进报告，**不要顺手修**」；IC-105 卡还明确要求该测试「公开接口与断言不变」。
2. **不能重跑 CI**。本卡的 gh 授权是「gh **读取** CI 结果与 artifact」，`rerun` 是写操作，不在授权内；「取 CI」的授权机制是**推送**。
3. **没有可推的合法提交**。子项 A 已完整交付，无遗留内容；报告提交命中 `paths-ignore` 不触发 CI；空推不产生新运行。

因此子项 A 的 CI 在本卡授权内**不可能转绿**，而卡内「绿（真实退出码 0）→ 才开下一子项」是硬闸门，子项 B 不得开工。这是**卡未预见的停线条件**：阻塞点位于本卡范围之外且本卡无权处置。按下发单「所有闸门触发时的正确动作都是把报告写全后停止」收口。

**补充判断**：即使越过该闸门继续做 B、C，最终交付闸门 G240（「最终 tip CI success、真实退出码 0」）同样卡在这个测试上。该测试在 #175/#177/#178 三次中失败 2 次，本卡剩余 5 次 CI 全部依赖它连续通过，成功率不足以支撑交付。阻塞点必须由决策会话先行处置。

## 子项 B：未实装（只读勘查结果）

**未做任何代码改动。** 以下是等待 CI #178 期间完成的只读勘查，供决策会话下次下发时直接使用：

### 闸门 B1 评估：**未触发**①

竖向手势的产品调用链是**单一入口、经状态机统一分派**，无旁路：

```
S2NativePhotoPager.swift:2938  （主图拖动结算）  ─┐
S2NativePhotoPager.swift:3171  （handleOneXVerticalGestureIfNeeded）─┴→ machine.completeMainDrag(...)
                                                        └→ handleSwipeUp() / handleSwipeDown()
```

`grep -rn "handleSwipeUp\|handleSwipeDown"` 在产品目录内只有 `completeMainDrag`（`S2StateMachine.swift:1414`、`:1417`）两处调用，其余全在测试目录。未发现绕过状态机直接改 `pendingDeletionAssetIDs` 或 `interfaceVisibility` 的竖向手势路径。

### B3 过渡动画：可零成本复用（勘查结论，未实施）

显隐过渡由 `S2NativePhotoPager` 的 `updatePage` 依据 published `interfaceVisibility` 变化触发：

```swift
let presentationChanged = sameAsset &&
    interfaceVisibility != page.interfaceVisibility &&
    isFramedPhoto && page.isFramedPhoto &&
    (fittedSize != page.fittedSize || cornerRadius != page.cornerRadius)
```

`handleSingleTap(on:)` 里的 `pendingPresentationTapPageIndex` / `presentationTapStartTimestamp` 只喂诊断埋点，**不参与动画门控**。因此状态机在下滑时置 `interfaceVisibility = .visible`，即自动走**同一条** `startPresentationTransition`（时长仍取 `configuration.presentationToggleDuration`）——**无需改视图层、无需新增任何可调参数**，满足 B3「复用现行单击显隐切换的同款过渡」。

### 需要的改动清单（未实施，供下次下发核对）

产品侧 `PhotoCleanupMVE/Core/S2StateMachine.swift`：

1. `transitionRule(.swipeUpMainImage, from: .state(.hiddenOneX))`：`.conditional(.sameState)` → `.ignored(.sameState)`
2. `transitionRule(.swipeDownMainImage, from: .state(.hiddenOneX))`：`.conditional(.sameState)` → `.available(.state(.visibleOneXIdle))`（与 `singleTapMainImage` 同形）
3. `handleSwipeUp()`：`interfaceVisibility == .hidden && zoomState == .oneX` 时直接 `return false`，**置于 `.alreadyMarked` 语义提示之前**（卡要求「无提示」）
4. `handleSwipeDown()`：同条件下置 `interfaceVisibility = .visible` 并 `return true`，**置于 `pendingDeletionAssetIDs.contains` 判断之前**（迁显示与是否已标记无关）；缩放、页索引、`D`、徽标均不动
5. 手势矩阵：`gestureRule(for:context:)` 目前**没有 `V` 维度**（`S2GestureContext` 仅 `.oneX` / `.nX` / `.albumSheetPresented`），要按卡「手势矩阵的 1x 上滑/下滑行按 `V` 拆分」必须给该函数加 `visibility:` 形参。该函数**只有测试一个调用方**（`S2StateMachineTests.swift:1299`），产品代码不调用它，故加形参风险极低；建议带默认值 `.visible` 以保证其余 11 行手势矩阵断言零改动（卡要求「`V=显示` 全部手势语义不变」）
6. `S2GestureEffect` 需要一个表示「下滑迁显示」的 case。复用 `.toggleInterface` 会错误暗示对称切换（显示态下滑是取消标记，不是隐藏），建议新增 `.revealInterface`；该枚举非 `CaseIterable`，无 `.count` 断言需同步

断言侧受影响项（已定位，未改）：`IC047_006`（迁移表上滑行第 4 格）、`IC047_007`（迁移表下滑行第 4 格，**且其行为断言当前用 `makeMachine(state: .hiddenOneX)` 验证取消标记，必须改到 `.visibleOneXIdle`**）、`IC047_026` / `IC047_027`（手势矩阵行）。另需逐一复核 `handleSwipeUp` / `handleSwipeDown` 的 17 处测试调用点中处于隐藏态者。

## 子项 C：未勘查、未实装

未读取相关布局推导，未评估闸门 C1 / C2，未动 `fitInsetRatio`，`schemaVersion` 保持 **4**（未按 C3 升到 6）。

## 逐条闸门结果

| 闸门 | 判定 | 依据 |
|---|---|---|
| 开工闸门（`main` 绿 519/0） | **通过** | IC-105 fix `46f7174`，CI #177 success，519/0，退出码 0 |
| **A1** | **未触发** | 探针 `primaryResource(in:mediaKind:)` 三类型全覆盖，LivePhoto 歧义点被明确回答 |
| **G237**（A） | **部分**：新分派表断言齐备 ✓；缓存/降级/格式断言零语义变化 ✓；未用私有 KVC ✓。但依赖的资源选择规则无单元覆盖（PhotoKit 类型不可构造，见上） | CI #178 中 A 的全部断言通过 |
| **G238**（B） | **未达成**（B 未实装） | — |
| **G239**（C） | **未达成**（C 未实装） | — |
| **G240** | **不满足** | 分支无绿 tip、无 IPA、无最终 run 编号 |
| **G241** | **部分**：子项 A 独立 commit ✓，本地三项门禁 0 ✓，冻结三链引用不变 ✓；但「各自 CI 绿有据」未达成 | — |
| **G242** | 本报告两件齐 | — |
| **B1** | **未触发**（只读勘查，B 未实装） | 两处产品调用点均经 `completeMainDrag` |
| **C1 / C2** | **未评估**（C 未勘查） | — |
| 时间闸门（6h） | **未到期**（开工 00:57:03Z，到期 06:57:03Z） | — |

## 本地门禁（真实退出码）

子项 A 提交前：

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** |
| `git diff --check` | **0** |

## 冻结三链与出厂值

| 项 | 值 | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 未触碰 |
| `S2CalibrationConfiguration.schemaVersion` | **4** | 未变（C3 要求的 4 → 6 因 C 未实装而未执行） |
| 合并进 `main` | **否**（分支全程独立） | — |

## Lynn 可下载什么

**没有包含 IC-104 任何子项的可测版本。**

- IC-104 分支最后一次 CI（#178）**未产出 IPA**（步骤 7/8 skipped，artifacts 0）。
- 当前唯一的绿 CI 是 **#177**（`main` @ `46f7174b2475c3cbd06bb9af73b9af1f109bfde4`，IPA **836638 字节**，SHA-256 `e5cfb0d183b83820c74ac41a72bc8e41bfa0ecfd522c030a8b96673c540a4b2c`），但它**只含 IC-105 的测试辅助加锁**，不含子项 A/B/C 的任何功能。
- 因此 **H45 七项本轮无法执行**。

## H45 人工判定清单（IC-104 卡第六节，原样列出）

1. 已编辑照片：S2 占用空间 = 系统「信息」页原始大小（核心项）。
2. 已编辑视频：同上。
3. 未编辑照片/视频各抽一张：数值与此前一致。
4. 隐藏态：1x 上滑无任何反应；下滑回显示态且缩放/页码/标记不变；显示态标记/取消照旧；Nx 照旧。
5. 截图：顶部栏—截图—横栏—操作条三段间距目测等距；非截图资产构图不变；隐藏态下截图尺寸不变。
6. 回归抽查：顶部信息区、底部布局、翻页、双击/捏合、标记→确认页流程。
7. 顺带核查（无代码，第 76 条挂账）：重启 App 观察徽标 88 跨会话残留是否复现。

> **本轮无可测版本**，七项全部未执行，未代为下任何结论。

## 卡内取定登记

| # | 取定 | 依据与影响 |
|---|---|---|
| 1 | 枚举 case `fullSizePhotoResource` 改名为 `originalPrimaryResource` | 原名指「照片当前版本」，改后覆盖三类型的**原始**资源，原名已不实。纯改名，`allCases.count` 仍为 3，无外部消费方（全仓 5 处引用已全部更新） |
| 2 | 已编辑资产的资源选择直接调用 `AssetSizeProbeService.primaryResource(in:mediaKind:)` | 卡内明文「与 099b 探针同一资源选择规则」；未新写选择逻辑，故不构成新语义取定 |

B3、C1 的卡内取定**未产生**（B、C 未实装）。

## 发现但未处理的问题（只报告不修）

1. **`testIC099v2C2StoreFetchesEachAssetAtMostOnce` 的 `:7923` 断言顺序敏感**（详见「停线」节）。这是本卡与后续所有 IC-104 子项的**唯一阻塞点**，属 IC-099/IC-105 范围，本卡无权修改。建议由决策会话下发一张小卡改为顺序无关断言。
2. **IC-105 的结论需要一处限定**：其自验报告依 CI #177 单次绿判定「归因成立、未被推翻」。#178 表明锁只消除了丢更新，该测试的**顺序不确定性**依然存在。按纪律 7「报告提交不得跨卡回填」，本卡**未回改** IC-105 报告，在此登记。
3. **LivePhoto 占用空间只含静态图部分**（复用探针规则的直接后果，见「闸门 A1 评估」）。若与系统「信息」页口径不一致，需决策会话定夺是否把配对视频计入。
4. **`primaryResource` 无单元覆盖**（PhotoKit 类型不可构造），正确性只能由 H45 真机判定兜底。
5. **`gestureRule(for:context:)` 缺 `V` 维度**：子项 B 的卡内要求「手势矩阵按 `V` 拆分」无法只靠断言改造完成，必须给该产品函数加形参。下次下发时宜在卡内写明这一点。
6. **本机网络**：`git push` 需 `-c http.proxy=http://127.0.0.1:7890`（直连 schannel 握手失败），且本轮出现连续 6 次失败后重试才成功的情况；`gh api` 带代理与直连均间歇 EOF，需 2–4 次重试。
