# IC-106 变更清单（顺序无关断言修复）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交 | `0fd97c71b227d99365e64673ae02977f04d5c8a8`（IC-105 报告提交） |
| **fix 提交（CI #179 被测）** | **`844b40b840f2b292990f159e31686299b392eb6b`** |
| 报告提交 | 只含 `Reports/IC-106/`，命中 `paths-ignore`，**不触发 CI** |
| 目标分支 | `main`（直接提交，本卡显式授权） |

代码提交（1 个，可单独 cherry-pick）：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `844b40b840f2b292990f159e31686299b392eb6b` | `fix(test): 并发取数记录改顺序无关断言（IC-106，修 #178 顺序抖动）` |

## 文件变化（`git diff --numstat 0fd97c7..844b40b`）

| 文件 | 增 | 删 | 归属 |
|---|---|---|---|
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | **1** | **1** | 卡内第 2 步唯一改动 |

**合计 1 file changed, 1 insertion(+), 1 deletion(-)。产品目录 `PhotoCleanupMVE/` 零 diff。**
未触碰：`ci.yml`、`Scripts/`、`.xcodeproj`、`Localizable.xcstrings`、任何产品源文件、任何其他测试文件。

## 改动全文

```diff
diff --git a/PhotoCleanupMVETests/S2CalibrationHarnessTests.swift b/PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
@@ -7900,7 +7900,7 @@ final class S2CalibrationHarnessTests: XCTestCase {
         XCTAssertEqual(store.byteCount(for: "asset-1"), 2_466_000)
         XCTAssertNil(store.byteCount(for: "asset-2"))
         XCTAssertTrue(store.isResolved("asset-2"))
-        XCTAssertEqual(provider.requestedAssetIDs, ["asset-1", "asset-2"])
+        XCTAssertEqual(provider.requestedAssetIDs.sorted(), ["asset-1", "asset-2"])
 
         // 已解析（成功与失败各一）后再请求，都不再发起
         store.requestIfNeeded(assetID: "asset-1", using: provider)
```

## 未改动项核对（卡内点名）

| 项 | 位置 | 状态 |
|---|---|---|
| `requestCount` 断言 | `S2CalibrationHarnessTests.swift:7909` | **一字未改** |
| 同函数其余断言（`:7900` `:7901` `:7902`） | 同上 | **一字未改** |
| `CountingAssetVolumeProvider` 本体（NSLock 版） | `:8979` 起 | **一字未改** |
| `CountingAssetSizeProber` 本体 | `:9011` 起 | **一字未改** |
| 探针顺序断言 `prober.requestedAssetIDs` | `:7753` | **未触碰**（单 Task 串行 await 驱动，顺序确定，按卡不动） |
| 产品代码 | `PhotoCleanupMVE/` | **零 diff** |

## 测试计数账本

| 项 | 数 |
|---|---|
| 继承态（`0fd97c7`） | 519 |
| 新增 | **0** |
| 改造 | **1**（同一测试函数内的一行断言，函数数不变） |
| 删除 | **0** |
| 本机计数（`844b40b`） | **519** |
| CI #179 实测 Executed | **519**，0 失败 ✓ |

校验：519 + 0 − 0 = **519** ✓。**无静默删除。**

### 被改造断言（旧语义 → 新语义）

| 位置 | 旧语义 | 新语义 | 性质 |
|---|---|---|---|
| `:7903` | `provider.requestedAssetIDs` 按**请求顺序**恰为 `["asset-1", "asset-2"]` | `provider.requestedAssetIDs.sorted()` 恰为 `["asset-1", "asset-2"]` | **去除过度规定**。保留：元素集合、元素个数、无重复、无第三者。放弃：元素次序——产品对此无承诺（取数由两个 `Task { @MainActor }` 并发发起，完成顺序不受语言保证）。「每资产至多取一次」另由 `:7909` 独立断言，未受影响 |

## CI 记录

| run | id | 被测提交 | 结论 | 真实退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|
| **#179** | `33133239957` | `844b40b840f2b292990f159e31686299b392eb6b` | **success** | **0** | `Executed 519 tests, with 0 failures (0 unexpected) in 25.098 (26.240) seconds` | **836638 字节**，SHA-256 `cefe142b5af6100ab62fadf9b351102ffc43387c519e7127dbd763e7d31ec2a2`；artifact `PhotoCleanupMVE-unsigned-844b40b840f2`（id `9671194790`） |

**CI 预算**：卡内上限 1 次，**已用 1 次**，未超。

## 占位值登记

**本卡无占位值变更，无出厂值变更。** `S2CalibrationConfiguration.schemaVersion` 保持 **4**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`），未递增。

## 卡内取定登记

**无。** 本卡按卡内给定的改法逐字执行（`.sorted()` 比较，期望值不变），无任何卡内取定。

## CLAUDE.md 基线行 hunk（`<top>/CLAUDE.md` 第七节）

**一处 hunk，仅该行语义**：

```diff
-- `main` = `0fd97c71b227d99365e64673ae02977f04d5c8a8`（IC-105 报告提交；被测 `46f7174b2475c3cbd06bb9af73b9af1f109bfde4`，CI #177，XCTest 519 项 0 失败），含 IC-054～IC-088、IC-090、IC-093、IC-095、IC-099 链（099b / 101 / 099v2）、IC-100、IC-102、IC-105 全部交付。链内 merge 提交：… + IC-102 的 2 个（`8741a43`、`6d72146`）；更早的 `bccc2d2`、`bb39f71` 是 IC-045 / IC-051 时期的继承 merge，早于本阶段基线。
+- `main` = `<报告提交 SHA>`（IC-106 报告提交；被测 `844b40b840f2b292990f159e31686299b392eb6b`，CI #179，XCTest 519 项 0 失败），含 IC-054～IC-088、IC-090、IC-093、IC-095、IC-099 链（099b / 101 / 099v2）、IC-100、IC-102、IC-105、IC-106 全部交付。链内 merge 提交：… + IC-102 的 2 个（`8741a43`、`6d72146`）；更早的 `bccc2d2`、`bb39f71` 是 IC-045 / IC-051 时期的继承 merge，早于本阶段基线。
```

（实际写入的 `<报告提交 SHA>` 为本目录报告 docs 提交的完整 SHA，见 `self-check.md` 结论栏与本文件顶部表格。）

## 范围核对

| 项 | 结果 |
|---|---|
| 是否改动产品代码 | **否**（零 diff） |
| 是否改动 helper 本体 | **否** |
| 是否改动其他任何测试 | **否**（只动 `:7903` 一行） |
| 是否触碰 IC-104 各子项 | **否** |
| 是否 revert / rebase / amend / force push / 删分支 | **否** |
| 是否修改 SPEC / Decision_log / `ci.yml` / `Scripts/` | **否** |
| 是否触碰冻结三链 | **否** |
