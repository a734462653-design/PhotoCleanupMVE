# IC-105 变更清单（测试辅助类并发保护，回退方案 NSLock）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交 | `7e786f420aba3650b05f3058d943dedec3fe0b0a`（IC-102 报告提交） |
| 首选方案 commit（CI #176 被测，failure） | `44ca58ca19c1ecd04c52a2de057b64214da8ae9e` |
| **最终 fix commit（CI #177 被测，success）** | **`46f7174b2475c3cbd06bb9af73b9af1f109bfde4`** |
| 报告提交 | 只含 `Reports/IC-105/`，命中 `paths-ignore`，**不触发 CI** |
| 目标分支 | `main`（直接提交，本卡显式授权） |

两个代码提交各自可单独 cherry-pick：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `44ca58ca19c1ecd04c52a2de057b64214da8ae9e` | `fix(test): 测试辅助记录并发保护（IC-105，修 #175 竞态）` |
| 2 | `46f7174b2475c3cbd06bb9af73b9af1f109bfde4` | `fix(test): 测试辅助记录并发保护（IC-105，修 #175 竞态）— 回退方案 NSLock` |

> 提交 2 不是提交 1 的增量补丁：它先撤回提交 1 的两行 `@MainActor`（文件 blob 途中回到 `c15cf4a6ee236a72125e18b29b1fed672eefb97f` = IC-102 v2 交付态，本机复核相符），再施加 NSLock。因此 `44ca58c..46f7174` 的净效果 = 继承态 + NSLock 保护。单独 revert `46f7174` 即回到 `44ca58c`（红态）。

## 文件变化

### 净变化（`git diff --numstat 7e786f4..46f7174`）

| 文件 | 增 | 删 | 归属 |
|---|---|---|---|
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 25 | 6 | 卡内第 2 步回退方案 |

**产品目录 `PhotoCleanupMVE/` 零 diff**（`git diff --name-only -- PhotoCleanupMVE/` 空）。`ci.yml`、`Scripts/`、`.xcodeproj`、`Localizable.xcstrings` 均未触碰。

### 提交 1（首选方案，`7e786f4..44ca58c`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 2 | 0 |

```diff
 /// IC-099b P3：计数用的假取数实现。只记录被问过哪些资产，不做任何 IO。
 /// IC-099 阶段二 C2/C3：计数用的假取数实现。记录被问过哪些资产，不做任何 IO。
+@MainActor
 private final class CountingAssetVolumeProvider: S2AssetVolumeProviding {
@@
+@MainActor
 private final class CountingAssetSizeProber: S2AssetSizeProbing {
```

CI #176 编译不过（10 条 `main actor-isolated … nonisolated context`），被提交 2 撤回。

### 提交 2（回退方案，`44ca58c..46f7174`）全文

```diff
 /// IC-099b P3：计数用的假取数实现。只记录被问过哪些资产，不做任何 IO。
 /// IC-099 阶段二 C2/C3：计数用的假取数实现。记录被问过哪些资产，不做任何 IO。
-@MainActor
 private final class CountingAssetVolumeProvider: S2AssetVolumeProviding {
     private let byteCounts: [String: Int64?]
-    private(set) var requestedAssetIDs: [String] = []
+    /// `byteCount(assetID:)` 是非隔离 `async`，多个在途资产会在并发执行器上同时
+    /// 进入该方法，记录数组必须过锁；读取一并过锁，避免读到半个写入。
+    private let recordLock = NSLock()
+    private var recordedAssetIDs: [String] = []
+
+    var requestedAssetIDs: [String] {
+        recordLock.lock()
+        defer { recordLock.unlock() }
+        return recordedAssetIDs
+    }
 
     var requestCount: Int {
         requestedAssetIDs.count
@@
     func byteCount(assetID: String) async -> Int64? {
-        requestedAssetIDs.append(assetID)
+        recordLock.lock()
+        recordedAssetIDs.append(assetID)
+        recordLock.unlock()
         guard let value = byteCounts[assetID] else {
             return nil
         }
@@
-@MainActor
 private final class CountingAssetSizeProber: S2AssetSizeProbing {
-    private(set) var requestedAssetIDs: [String] = []
+    /// 同 `CountingAssetVolumeProvider`：`measure(assetID:)` 非隔离且可并发进入。
+    private let recordLock = NSLock()
+    private var recordedAssetIDs: [String] = []
+
+    var requestedAssetIDs: [String] {
+        recordLock.lock()
+        defer { recordLock.unlock() }
+        return recordedAssetIDs
+    }
 
     var measureCount: Int {
         requestedAssetIDs.count
     }
 
     func measure(assetID: String) async -> S2AssetSizeProbeMeasurement {
-        requestedAssetIDs.append(assetID)
+        recordLock.lock()
+        recordedAssetIDs.append(assetID)
+        recordLock.unlock()
         return S2AssetSizeProbeMeasurement(
```

`NSLock` 无需新增 import（`XCTest` / `UIKit` 已再导出 Foundation；文件 import 行未改动）。

## 公开接口核对（零变化）

| 成员 | 改动前 | 改动后 | 外部契约 |
|---|---|---|---|
| `CountingAssetVolumeProvider.requestedAssetIDs` | `private(set) var`（存储属性） | `var`（只读计算属性，过锁） | 外部只读 `[String]`，**不变** |
| `CountingAssetVolumeProvider.requestCount` | `requestedAssetIDs.count` | 同左 | **不变** |
| `CountingAssetVolumeProvider.init(byteCounts:)` | 显式 | 签名未改 | **不变** |
| `CountingAssetVolumeProvider.byteCount(assetID:) async` | 协议要求 | 签名未改 | **不变** |
| `CountingAssetSizeProber.requestedAssetIDs` | `private(set) var`（存储属性） | `var`（只读计算属性，过锁） | 外部只读 `[String]`，**不变** |
| `CountingAssetSizeProber.measureCount` | `requestedAssetIDs.count` | 同左 | **不变** |
| `CountingAssetSizeProber()` | 隐式默认 init | 仍为隐式默认 init | **不变** |
| `CountingAssetSizeProber.measure(assetID:) async` | 协议要求 | 签名未改 | **不变** |

## 测试计数账本

| 项 | 数 |
|---|---|
| 继承态测试函数数（`7e786f4`） | 519 |
| 本卡新增 | **0** |
| 本卡改造 | **0** |
| 本卡删除 | **0** |
| 本卡 tip 测试函数数（`46f7174`，本机计数） | **519** |
| CI #177 实测 Executed | **519**，0 失败 |

校验：519 + 0 − 0 = **519** ✓，与 CI #177 吻合。**无静默删除。**

**断言改造逐条**：无。7 处消费点（`:7729` `:7736` `:7752` `:7753` `:7792` `:7903` `:7909`）与 5 处构造点（`:7721` `:7741` `:7780` `:7885` `:7914`）**一字未改**。

## CI 记录

| run | id | 被测提交 | 结论 | 真实退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|
| **#176** | `33129797517` | `44ca58ca19c1ecd04c52a2de057b64214da8ae9e` | **failure** | 非 0（数值未取到，见 self-check） | 未执行（10 条编译错误） | 无（步骤 7/8 skipped，artifacts 0） |
| **#177** | `33130464724` | `46f7174b2475c3cbd06bb9af73b9af1f109bfde4` | **success** | **0** | `Executed 519 tests, with 0 failures (0 unexpected) in 25.808 (34.994) seconds` | **836638 字节**，SHA-256 `e5cfb0d183b83820c74ac41a72bc8e41bfa0ecfd522c030a8b96673c540a4b2c`；artifact `PhotoCleanupMVE-unsigned-46f7174b2475`（id `9670136752`） |

**CI 预算**：卡内上限 2 次（首选 1 + 回退 1），**已用 2 次**，未超。

## 占位值登记

**本卡无占位值变更，无出厂值变更。** `S2CalibrationConfiguration.schemaVersion` 保持 **4**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`），未递增。

## 卡内取定登记

**一项，须决策会话复核**：CI #176 的编译失败同时命中「范围内第 2 步（首选编译不过 → 用回退）」与「G246(b)（编译错误 → 停）」两条相反条款。本卡取定按**第 2 步**执行回退，理由三条见 `self-check.md`「G246 条款冲突与取舍」。该取定不是产品决策，是对卡内文本冲突的执行取舍，**已完整上报，不代为定论**。

## CLAUDE.md 基线行 hunk（`<top>/CLAUDE.md` 第七节）

**一处 hunk，仅该行语义**：

```diff
-- `main` = `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff`（IC-097 报告提交；被测 `8e000fc`，CI #168，XCTest 497 项 0 失败），含 IC-054～IC-088、IC-090、IC-093、IC-095 全部交付。链内 merge 提交：`e768f1b`（继承，IC-064 改造前曲线证据）+ IC-088 的 4 个（`b042167`、`38eb487`、`931748a`、`0530aa1`）+ IC-094 的 2 个（`78bd059`、`3b838f0`）+ IC-097 的 1 个（`8e000fc`）；更早的 `bccc2d2`、`bb39f71` 是 IC-045 / IC-051 时期的继承 merge，早于本阶段基线。
+- `main` = `<报告提交 SHA>`（IC-105 报告提交；被测 `46f7174b2475c3cbd06bb9af73b9af1f109bfde4`，CI #177，XCTest 519 项 0 失败），含 IC-054～IC-088、IC-090、IC-093、IC-095、IC-099 链（099b/101/099v2）、IC-100、IC-102、IC-105 全部交付。链内 merge 提交：`e768f1b`（继承，IC-064 改造前曲线证据）+ IC-088 的 4 个（`b042167`、`38eb487`、`931748a`、`0530aa1`）+ IC-094 的 2 个（`78bd059`、`3b838f0`）+ IC-097 的 1 个（`8e000fc`）+ IC-102 的 2 个（`8741a43`、`6d72146`）；更早的 `bccc2d2`、`bb39f71` 是 IC-045 / IC-051 时期的继承 merge，早于本阶段基线。
```

（实际写入的 `<报告提交 SHA>` 为本目录报告 docs 提交的完整 SHA，见 `self-check.md` 结论栏与本文件顶部表格。）

## 范围核对

| 项 | 结果 |
|---|---|
| 是否改动产品代码（`PhotoCleanupMVE/`） | **否**（零 diff） |
| 是否触碰 IC-104 任何子项（改原始分派 / 隐藏态反转 / 截图内缩） | **否** |
| 是否重构其他测试、给未列名类型加并发标注、"顺手"整理 | **否**（只动卡内列名的两个 helper 类） |
| 是否 revert / rebase / amend / force push / 删分支 | **否**（提交 2 是正向提交，不是 `git revert`） |
| 是否修改 SPEC / Decision_log / `ci.yml` / `Scripts/` | **否** |
| 是否触碰冻结三链 | **否** |
