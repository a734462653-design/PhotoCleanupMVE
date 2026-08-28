# IC-104 变更清单（single-build-batch，A/B 交付，C 停线）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 首轮继承提交 | `0fd97c71b227d99365e64673ae02977f04d5c8a8`（IC-105 报告提交） |
| 恢复时分支 tip（下发单规定值） | `65596b92c80132c3c9e441ebbb8d561130e6094e` |
| 分支 | `feature/ic-104-single-build-batch`（**未重切、全程未合并进 `main`**） |
| **最后绿 tip（Lynn 的可测版本）** | **`1e77e6af8dc4839b825d61b0f714fb465000c3bd`（子项 B，CI #181）** |
| 分支当前 tip | `3fbe8cb318908a08cf7338c64474db29fdbf6048`（子项 C，CI #182 红，停线保留） |
| 报告提交 | 只含 `Reports/IC-104/`，命中 `paths-ignore`，**不触发 CI** |

代码提交（4 个，各自可单独 cherry-pick）：

| # | 子项 | 完整 SHA | 提交信息首行 | CI |
|---|---|---|---|---|
| 1 | A | `209e2d552c1b4871ab6eea3b3e794099c3203780` | `feat(s2): 占用空间改取原始资源字节数（IC-104 子项 A，第 133 条）` | #178 红（范围外抖动） |
| 2 | A | `addae570b823ee8903aaa719eaa01e33ac75c7d1` | `merge: main (IC-106) into ic-104` | **#180 绿** |
| 3 | B | `1e77e6af8dc4839b825d61b0f714fb465000c3bd` | `feat(s2): 隐藏态竖向手势反转（IC-104 子项 B，第 132 条）` | **#181 绿** |
| 4 | C | `3fbe8cb318908a08cf7338c64474db29fdbf6048` | `feat(s2): 截图内缩改锚 chrome 三等距（IC-104 子项 C）` | #182 红（规格冲突） |

### 授权的 merge 提交

| 项 | 值 |
|---|---|
| SHA | `addae570b823ee8903aaa719eaa01e33ac75c7d1` |
| 第一父 | `65596b92c80132c3c9e441ebbb8d561130e6094e` |
| 第二父 | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（IC-106 报告提交） |
| merge-base | `0fd97c71b227d99365e64673ae02977f04d5c8a8` |
| 冲突 | **无**（`git merge-tree` 只读预演 + 实际合并均无冲突） |
| 方式 | `git merge main --no-ff`，**未 rebase** |

## 文件变化

### 子项 A（`git diff --numstat 65596b9..209e2d5`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2TopBarInfoPresentation.swift` | 16 | 11 |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | 12 | 10 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 30 | 10 |

合计 **3 files, 58 insertions(+), 31 deletions(-)**。

### 子项 B（`git diff --numstat addae57..1e77e6a`）

| 文件 | 增 | 删 | 归属 |
|---|---|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | 54 | 11 | 迁移表两行按 V 拆分、`gestureRule` 加 `visibility:`、`S2GestureEffect` 加 `.revealInterface`、两个 handler 加隐藏态守卫 |
| `PhotoCleanupMVETests/S2StateMachineTests.swift` | 107 | 7 | `IC047_006/007/026/027` + `assertGestureRow` 加 V 形参 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 3 | 1 | `testIC075G107…` 的 `consumedNoticeCount` |

合计 **3 files, 164 insertions(+), 19 deletions(-)**。
**`S2Calibration.swift` 零 diff——未新增任何可调参数。**

### 子项 C（`git diff --numstat 1e77e6a..3fbe8cb`）— 未交付

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 54 | 23 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 6 | 9 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 254 | 108 |
| `PhotoCleanupMVETests/S2ImageLoadingStateTests.swift` | 2 | 2 |

合计 **4 files, 316 insertions(+), 142 deletions(-)**。

全程未触碰：`ci.yml`、`Scripts/`、`.xcodeproj`、`Localizable.xcstrings`、SPEC、Decision_log。

## 子项 A 关键差异

```diff
-/// 路线分派器。四行全覆盖，纯函数。
+/// 路线分派器。六行全覆盖（三类型 × 是否已编辑），纯函数。
 enum S2AssetVolumeRouter {
     static func route(mediaKind:isEdited:) -> S2AssetVolumeRoute {
-        if mediaKind == .video { return .videoAssetURL }
-        return isEdited ? .fullSizePhotoResource : .contentEditingInputURL
+        if isEdited { return .originalPrimaryResource }
+        return mediaKind == .video ? .videoAssetURL : .contentEditingInputURL
     }
 }
```

```diff
-    case .fullSizePhotoResource:
-        guard let resource = resources.first(
-            where: { $0.type == .fullSizePhoto }
-        ) else { return nil }
+    case .originalPrimaryResource:
+        guard let resource = AssetSizeProbeService.primaryResource(
+            in: resources, mediaKind: mediaKind
+        ) else { return nil }
         return await streamedByteCount(of: resource)
```

## 子项 B 关键差异

```diff
 case .swipeUpMainImage:
-    case .state(.visibleOneXIdle), .state(.hiddenOneX):
-        return .conditional(.sameState)
+    case .state(.visibleOneXIdle):
+        return .conditional(.sameState)
+    case .state(.hiddenOneX):
+        return .ignored(.sameState)

 case .swipeDownMainImage:
-    case .state(_):
-        return .conditional(.sameState)
+    case .state(.hiddenOneX):
+        return .available(.state(.visibleOneXIdle))
+    case .state(.visibleOneXIdle), .state(.visibleNxIdle), .state(.hiddenNx):
+        return .conditional(.sameState)
```

```diff
 func handleSwipeUp() -> Bool {
     guard receivesUnobscuredInput else { return false }
+    if interfaceVisibility == .hidden, zoomState == .oneX { return false }
     let assetID = currentAssetID

 func handleSwipeDown() -> Bool {
-    guard receivesUnobscuredInput, zoomState == .oneX,
-          pendingDeletionAssetIDs.contains(currentAssetID) else { return false }
+    guard receivesUnobscuredInput, zoomState == .oneX else { return false }
+    if interfaceVisibility == .hidden {
+        interfaceVisibility = .visible
+        return true
+    }
+    guard pendingDeletionAssetIDs.contains(currentAssetID) else { return false }
```

```diff
 static func gestureRule(
     for input: S2GestureInput,
-    context: S2GestureContext
+    context: S2GestureContext,
+    visibility: S2InterfaceVisibility = .visible
 ) -> S2GestureRule {
```

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 |
|---|---|---|---|
| A | 0 | **1** | 0 |
| B | 0 | **5** | 0 |
| C（未交付） | 0 | 6 | 0 |

| 提交 | 本机计数 | CI Executed |
|---|---|---|
| 继承 `65596b9` | 519 | — |
| `addae57`（A） | 519 | **519 / 0 失败** |
| `1e77e6a`（B） | 519 | **519 / 0 失败** |
| `3fbe8cb`（C） | 519 | 519 / 37 失败 |

校验：519 + 0 − 0 = **519** ✓。**无静默删除。**

### 被改造断言逐条（旧语义 → 新语义）

**子项 A**

| # | 断言 | 旧 | 新 | 性质 |
|---|---|---|---|---|
| 1 | `route(.video, isEdited: true)` | `.videoAssetURL` | `.originalPrimaryResource` | 行为变更（第 133 条） |
| 2 | `route(.photo, isEdited: true)` | `.fullSizePhotoResource`（当前版本） | `.originalPrimaryResource`（原始） | 语义变更 |
| 3 | `route(.livePhoto, isEdited: true)` | 同 2 | 同 2 | 语义变更 |
| 4 | 三条未编辑行 | — | 不变 | 零变化 |
| 5 | `S2AssetVolumeRoute.allCases.count == 3` | 3 | 3 | 零变化 |
| 6 | 新增：三类型 × 两编辑态全覆盖循环 | — | — | 新增覆盖 |

**子项 B**

| # | 断言 | 旧 | 新 | 性质 |
|---|---|---|---|---|
| 1 | `IC047_006` 第 4 格（`hiddenOneX`） | `conditionalSame` | `ignoredSame` | 行为变更 |
| 2 | `IC047_007` 第 4 格 | `conditionalSame` | `availableState(.visibleOneXIdle)` | 行为变更 |
| 3 | `IC047_007` 行为断言 | 用 `.hiddenOneX` 验证取消标记 | 移到 `.visibleOneXIdle`；隐藏态另加迁 V + 状态量不变断言 | 行为变更 |
| 4 | `IC047_026` / `IC047_027` | 单行无 V | 按 `.visible` / `.hidden` 各断言一次；显示态取值一字未改 | 覆盖扩充 |
| 5 | `testIC075G107…` `consumedNoticeCount` | `2` | `1` | 行为变更（隐藏态上滑不再发提示） |

**均为行为变更，非削弱**：新增了「隐藏态上滑不改 D / 不翻页 / 不发提示」「隐藏态下滑只迁 V、其余状态量不变」「Nx 分层不变」三组此前不存在的断言。

## CI 记录

| run | id | 被测提交 | 子项 | 结论 | 退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|---|
| #178 | `33131726380` | `209e2d5` | A | failure | 65 | 519 / 1（范围外 `:7923`，IC-106 已修） | 无 |
| **#180** | `33134112220` | `addae57` | **A** | **success** | **0** | **519 / 0** | 836587 字节，`db4103af99fd41805dc7294f9b9e43cd6ba65f20ede543279bff34f484af3a03` |
| **#181** | `33135136401` | `1e77e6a` | **B** | **success** | **0** | **519 / 0** | **836633 字节，`778a9f8f669ad4fdde3a57d429f6680624547a5c2f7b5bea828f63a66d0d5f28`**；artifact `PhotoCleanupMVE-unsigned-1e77e6af8dc4`（id `9671834388`） |
| #182 | `33137588575` | `3fbe8cb` | C | failure | 非 0（未取到） | 519 / **37** | 无 |

**CI 预算**：6 次，已用 **5**（A 2 / B 1 / C 1，另 #178 计入 A）。剩余 B 1 + C 1 未用。

## 占位值登记

| tip | `schemaVersion` | 说明 |
|---|---|---|
| `1e77e6a`（绿，A + B） | **4** | A、B 零出厂值变更，未递增 |
| `3fbe8cb`（红，C） | **6** | C 删除 `fitInsetRatio`，出厂值集合变更；按「所有链已用值 + 1」跳过被冻结 `feature/ic-092-nx-window-follow` 链占用的 5 |

**Lynn 将下载的 #181 包内 `schemaVersion == 4`。**

## 卡内取定登记

| # | 子项 | 取定 | 状态 |
|---|---|---|---|
| 1 | A | `fullSizePhotoResource` → `originalPrimaryResource`（纯改名随语义扩展） | 已交付 |
| 2 | A | 已编辑分支复用 `AssetSizeProbeService.primaryResource(in:mediaKind:)` | 已交付 |
| 3 | B | **B3**：过渡动画复用现行单击显隐同款（零视图层改动、零新增可调参数） | 已交付 |
| 4 | B | `S2GestureEffect` 新增 `.revealInterface` | 已交付 |
| 5 | B | `gestureRule` 的 `visibility:` 取默认值 `.visible` | 已交付 |
| 6 | C | 圆角规则维持既有（截图且 `V=显示`），本卡只改尺寸口径 | **未交付**，随 C 待裁定 |

## 陷阱 9 四条全量扫描（子项 C）

| 扫描 | 结果 |
|---|---|
| 1. 逐字段构造点 | 1 处（`S2CalibrationHarnessTests.swift:835`） |
| 2. 登记表使用点 | 10 处（产品 2 + 测试 8） |
| 3. 字面 `.count` 断言 | 6 条需改 + 1 条相对式自动跟随 |
| 4. `specStatus` / `wiringStatus` 过滤计数 | 5 处；decided 35→34，placeholder 9 不变 |

## 停线登记

**子项 C 停线，原因：卡内 C1/C2 与 SPEC-S2 v16 存在行为与几何结果层面的实质冲突。**

| 规格位置 | 与卡的冲突 |
|---|---|
| v16 第 66 行（决策 19） | 规格以 `(1 − fitInsetRatio) × 视口` 定义适配框，且限定「**显示态**」；卡 C1 改为 chrome 锚定带，卡 C2 要删除该参数 |
| v16 第 121 行 | 「**隐藏态填满**」继续有效；卡 C1 要求几何与 `V` 无关 |
| v16 第 177 行 | 「界面显隐…**改变截图资产在 `s = 1` 的尺寸与圆角**」；卡要求不随 `V` 变化 |
| v16 第 180 行 | 以「截图沉浸尺寸变化存在」为前提 |
| v16 第 743 行 | 废止清单不含 `fitInsetRatio`，该参数在规格中仍活 |

依 CLAUDE.md 第七节「确有冲突则停下报告」；修改 SPEC 属第三节默认禁止项。**未动用 C 的最后一次 CI 预算**——修复方向取决于冲突如何裁定，裁定前任何修法都是猜测。

## 范围核对

| 项 | 结果 |
|---|---|
| 是否合并进 `main` | **否** |
| 是否 rebase / amend / force push / 删分支 | **否**（授权的 merge 是 `--no-ff` 普通合并） |
| 是否修改 SPEC / Decision_log / `ci.yml` / `Scripts/` | **否** |
| 是否触碰冻结三链 | **否**（`b368a6c` / `6736f1e` / `a7cc1ec` 引用未变） |
| 是否新增可调参数或占位值 | **否**（B 的 `S2Calibration.swift` 零 diff；C 删了一个参数，未加） |
| 是否触碰相簿 sheet 系统化 / Nx 冻结三链 / 双击丝滑度 / 视觉稿阶段各项 | **否** |
| 是否 revert 子项 C 的红提交 | **否**（禁止 revert；保留在分支上供决策会话评估） |
