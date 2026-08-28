# IC-104 变更清单（single-build-batch，停在子项 A）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交（IC-105 后的 `main` tip） | `0fd97c71b227d99365e64673ae02977f04d5c8a8` |
| 分支 | `feature/ic-104-single-build-batch`（自继承提交切出，**全程未合并进 `main`**） |
| **分支 tip** | **`209e2d552c1b4871ab6eea3b3e794099c3203780`**（子项 A，CI #178 failure） |
| 报告提交 | 只含 `Reports/IC-104/`，命中 `paths-ignore`，**不触发 CI** |

代码提交（1 个，可单独 cherry-pick）：

| # | 子项 | 完整 SHA | 提交信息首行 | CI |
|---|---|---|---|---|
| 1 | A | `209e2d552c1b4871ab6eea3b3e794099c3203780` | `feat(s2): 占用空间改取原始资源字节数（IC-104 子项 A，第 133 条）` | **#178 failure**（失败点在范围外的既存测试，非本提交） |

子项 B、C **无提交**。

## 文件变化（`git diff --numstat 0fd97c7..209e2d5`）

| 文件 | 增 | 删 | 归属 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2TopBarInfoPresentation.swift` | 16 | 11 | A：路线枚举与分派器 |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | 12 | 10 | A：`AssetVolumeService` 已编辑分支改走原始主资源 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 30 | 10 | A：C1 分派表断言按新表改造 |

合计 **3 files changed, 58 insertions(+), 31 deletions(-)**。

未触碰：`ci.yml`、`Scripts/`、`.xcodeproj`、`Localizable.xcstrings`、`S2Calibration.swift`、`S2StateMachine.swift`、`S2View.swift`、`S2NativePhotoPager.swift`。

## 子项 A 变更明细

### `S2TopBarInfoPresentation.swift`

```diff
-/// 取数路线。按资产类型分派，**无数值阈值**（④ 技术负责人 2026-08-28，依 H43 真机 `099.txt`①）。
+/// 取数路线。按「是否已编辑」先分派，未编辑再按类型分派，**无数值阈值**
+/// （④ Decision_log 第 133 条：「占用空间」= **原始资源字节数**）。
 enum S2AssetVolumeRoute: String, CaseIterable, Sendable {
-    /// 视频（含已编辑）：`requestAVAsset` → `AVURLAsset.url` 文件属性。H43 14/14 逐字节精确。
+    /// 未编辑视频：`requestAVAsset` → `AVURLAsset.url` 文件属性。H43 14/14 逐字节精确。
     case videoAssetURL
     /// 未编辑照片 / LivePhoto：`requestContentEditingInput` → `fullSizeImageURL` 文件属性。
     /// H43 35/35 精确。
     case contentEditingInputURL
-    /// 已编辑照片 / 已编辑 LivePhoto：`.fullSizePhoto` 资源 `requestData` 流式累加。
-    case fullSizePhotoResource
+    /// 已编辑资产（照片 / LivePhoto / 视频）：**原始**主资源 `requestData` 流式累加。
+    /// 资源选择复用 `AssetSizeProbeService.primaryResource(in:mediaKind:)`；
+    /// **LivePhoto 的配对视频不计入**。
+    case originalPrimaryResource
 }

-/// 路线分派器。四行全覆盖，纯函数。
+/// 路线分派器。六行全覆盖（三类型 × 是否已编辑），纯函数。
 enum S2AssetVolumeRouter {
     static func route(mediaKind:isEdited:) -> S2AssetVolumeRoute {
-        if mediaKind == .video {
-            return .videoAssetURL
-        }
-        return isEdited ? .fullSizePhotoResource : .contentEditingInputURL
+        if isEdited {
+            return .originalPrimaryResource
+        }
+        return mediaKind == .video ? .videoAssetURL : .contentEditingInputURL
     }
 }
```

### `AssetSizeScanner.swift`

```diff
     let resources = PHAssetResource.assetResources(for: asset)
+    let mediaKind = AssetSizeProbeService.mediaKind(of: asset)
     let route = S2AssetVolumeRouter.route(
-        mediaKind: AssetSizeProbeService.mediaKind(of: asset),
+        mediaKind: mediaKind,
         isEdited: resources.contains { $0.type == .adjustmentData }
     )
     switch route {
     case .videoAssetURL:
         return await videoURLByteCount(for: asset)
     case .contentEditingInputURL:
         return await contentEditingInputByteCount(for: asset)
-    case .fullSizePhotoResource:
-        guard let resource = resources.first(
-            where: { $0.type == .fullSizePhoto }
-        ) else {
+    case .originalPrimaryResource:
+        guard let resource = AssetSizeProbeService.primaryResource(
+            in: resources,
+            mediaKind: mediaKind
+        ) else {
             return nil
         }
         return await streamedByteCount(of: resource)
     }
```

另更新该类型的文档注释：原文称「探针取原始主资源，本类型取 `.fullSizePhoto`（当前版本），语义相反」，改后两者资源选择已一致，注释随之改写为「复用同一规则，返回契约仍不同」。

### 分派表新旧对照

| mediaKind | isEdited | 改前 | 改后 | 变化 |
|---|---|---|---|---|
| photo | false | `contentEditingInputURL` | `contentEditingInputURL` | — |
| livePhoto | false | `contentEditingInputURL` | `contentEditingInputURL` | — |
| video | false | `videoAssetURL` | `videoAssetURL` | — |
| photo | true | `fullSizePhotoResource`（`.fullSizePhoto`，当前版本） | `originalPrimaryResource`（`.photo` → 退 `.fullSizePhoto`） | **语义变更** |
| livePhoto | true | 同上 | 同上 | **语义变更** |
| video | true | `videoAssetURL`（URL，当前版本） | `originalPrimaryResource`（`.video` → 退 `.fullSizeVideo`） | **路线 + 语义变更** |

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 | 理由 |
|---|---|---|---|---|
| A | 0 | **1** | 0 | `testIC099v2C1VolumeRouteDispatchCoversAllFourRows` → `testIC104AVolumeRouteDispatchCoversAllSixRows`：改名（旧名「FourRows」已不实）+ 断言按新表改写 + 增加三类型 × 两编辑态全覆盖循环 |
| B | — | — | — | 未实装 |
| C | — | — | — | 未实装 |

| 项 | 数 |
|---|---|
| 继承态（`0fd97c7`） | 519 |
| Σ新增 − Σ删除 | 0 |
| 应得 | **519** |
| 本机计数（`209e2d5`） | **519** |
| CI #178 实测 Executed | **519** ✓ |

**无静默删除。**

### 被改造断言逐条（旧语义 → 新语义）

| # | 断言 | 旧语义 | 新语义 | 性质 |
|---|---|---|---|---|
| 1 | `route(.video, isEdited: true)` | `== .videoAssetURL` | `== .originalPrimaryResource` | **行为变更**（第 133 条，非削弱） |
| 2 | `route(.photo, isEdited: true)` | `== .fullSizePhotoResource`（当前版本资源） | `== .originalPrimaryResource`（原始资源） | **语义变更**（常量改名 + 语义改口径） |
| 3 | `route(.livePhoto, isEdited: true)` | 同 2 | 同 2 | **语义变更** |
| 4 | `route(.photo/.livePhoto/.video, isEdited: false)` | 三条 URL 路线 | 不变 | 零变化 |
| 5 | `S2AssetVolumeRoute.allCases.count == 3` | 3 | 3 | 零变化 |
| 6 | 新增：三类型 × 两编辑态循环，`route == .originalPrimaryResource` ⟺ `isEdited`；`S2AssetSizeProbeMediaKind.allCases.count == 3` | — | — | 新增覆盖（同一测试函数内） |

**未改造**（零语义变化）：`testIC099v2C1FailureDegradesToPositionOnly`、`testIC099v2C2StoreFetchesEachAssetAtMostOnce`、`testIC099v2C3SubtitleReflectsPendingFailureAndAssetSwitch`、`testIC099v2C4SubtitleTextUsesSlashAndMiddleDot` 及全部 IC-099b 探针断言。

## CI 记录

| run | id | 被测提交 | 结论 | 真实退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|
| **#178** | `33131726380` | `209e2d552c1b4871ab6eea3b3e794099c3203780` | **failure** | **65** | `Executed 519 tests, with 1 failure (0 unexpected) in 58.412 (105.178) seconds` | **无**（步骤 7/8 skipped，artifacts 0） |

唯一失败：`S2CalibrationHarnessTests.swift:7923`
`testIC099v2C2StoreFetchesEachAssetAtMostOnce`——
`XCTAssertEqual failed: ("["asset-2", "asset-1"]") is not equal to ("["asset-1", "asset-2"]")`。
**与本提交无关**，属 IC-099 时期该测试对并发填充数组做顺序敏感断言，详见 `self-check.md`「停线」节。

**CI 预算**：总 6 次（A 2 / B 2 / C 2），**已用 1 次**（A 1）。

## 占位值登记

**本卡无出厂值变更。** `S2CalibrationConfiguration.schemaVersion` 保持 **4**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`）。

> 卡内 C3 要求 `schemaVersion` 4 → **6**（跳过 5，因 5 已被冻结的 `feature/ic-092-nx-window-follow` 链占用）。**因子项 C 未实装，该递增未执行。** 下次下发子项 C 时仍须按「所有链已用值 + 1」取 6，并同步跑陷阱 9 的四条全量扫描。

## 卡内取定登记

| # | 子项 | 取定 | 说明 |
|---|---|---|---|
| 1 | A | `fullSizePhotoResource` → `originalPrimaryResource` | 纯改名，随语义扩展（原名只指照片当前版本）。全仓 5 处引用已全部更新，`allCases.count` 仍为 3 |
| 2 | A | 已编辑分支的资源选择直接调用 `AssetSizeProbeService.primaryResource(in:mediaKind:)` | 卡内明文「与 099b 探针同一资源选择规则」，未新写逻辑，不构成新语义取定 |

B3（过渡动画复用单击同款）、C1（锚 chrome 三等距）的卡内取定 **未产生**（B、C 未实装）。

## 范围核对

| 项 | 结果 |
|---|---|
| 是否合并进 `main` | **否** |
| 是否 rebase / amend / force push / 删分支 | **否** |
| 是否修改 SPEC / Decision_log / `ci.yml` / `Scripts/` | **否** |
| 是否触碰冻结三链 | **否**（`b368a6c` / `6736f1e` / `a7cc1ec` 引用未变） |
| 是否新增可调参数或占位值 | **否** |
| 是否触碰相簿 sheet 系统化 / Nx 冻结三链 / 双击丝滑度 / 视觉稿阶段各项 | **否** |
| 是否修改范围外的 `testIC099v2C2…`（CI #178 的失败点） | **否**（纪律：发现问题只报告不修） |
| 子项 B / C | **未实装**（卡内「绿了才开下一子项」未满足） |
