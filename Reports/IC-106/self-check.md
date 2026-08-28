# IC-106 自验报告（顺序无关断言修复，main 抗抖）

## 结论（先行）

**本卡通过。`main` 恢复绿并消除了最后一处时序抖动源。CI 只用了 1 次（上限 1）。**

- **G248 通过**①：开工 `git status --porcelain` 空；`main` tip = `0fd97c71b227d99365e64673ae02977f04d5c8a8`，与卡规定值相符。
- **G249 通过**①：代码 commit 恰一个文件 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`，`git diff --numstat` = **1 增 / 1 删**；`git diff --name-only -- PhotoCleanupMVE/`（产品目录）**空**。
- **G250 通过**①：CI **#179 success**，被测 `844b40b840f2b292990f159e31686299b392eb6b`，9 步全 success，**真实退出码 0**，`Executed 519 tests, with 0 failures (0 unexpected) in 25.098 (26.240) seconds`；IPA **836638 字节**、SHA-256 `cefe142b5af6100ab62fadf9b351102ffc43387c519e7127dbd763e7d31ec2a2`。
- **G251 未触发**：CI 未失败。
- **G252 通过**①：`schemaVersion == 4` 未变；冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` 引用未动；`<top>/CLAUDE.md` 仅第七节基线行一处 hunk。

**上游归因经实测确认**①：卡内判定「`:7903` 属测试过度规定，产品无顺序承诺」成立——仅把该行改为 `.sorted()` 比较（产品代码、helper 本体、其余断言一字未动），519 项全绿，无任何新失败。

**人工判定：无。** 本卡改动全部位于 `PhotoCleanupMVETests/`，产品目录零 diff，不产生真机判定项。

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空（纪律 8 检查通过） |
| 继承提交 | `0fd97c71b227d99365e64673ae02977f04d5c8a8`（IC-105 报告提交），实测相符 |
| 目标分支 | `main` |
| **fix 提交** | **`844b40b840f2b292990f159e31686299b392eb6b`** |
| CI 预算 | 1 次，**已用 1 次** |
| 范围边界 | 只改 `S2CalibrationHarnessTests.swift:7903` 一行 + 本目录报告 + CLAUDE.md 基线行 |

## 唯一代码改动

```diff
@@ -7900,7 +7900,7 @@ final class S2CalibrationHarnessTests: XCTestCase {
         XCTAssertEqual(store.byteCount(for: "asset-1"), 2_466_000)
         XCTAssertNil(store.byteCount(for: "asset-2"))
         XCTAssertTrue(store.isResolved("asset-2"))
-        XCTAssertEqual(provider.requestedAssetIDs, ["asset-1", "asset-2"])
+        XCTAssertEqual(provider.requestedAssetIDs.sorted(), ["asset-1", "asset-2"])
 
         // 已解析（成功与失败各一）后再请求，都不再发起
         store.requestIfNeeded(assetID: "asset-1", using: provider)
```

期望值 `["asset-1", "asset-2"]` 已按字典序，未改动。`:7909` 的 `XCTAssertEqual(provider.requestCount, 2)` 与该测试其余断言、`CountingAssetVolumeProvider`（NSLock 版）本体、`CountingAssetSizeProber` 均**一字未改**。

**未触碰 `:7753`**：`XCTAssertEqual(prober.requestedAssetIDs, assetIDs)` 是探针的顺序断言，由单 Task 串行 `await` 驱动，顺序确定，按卡「不动」。

## 断言语义变更登记（唯一一条）

| 项 | 旧语义 | 新语义 | 性质 |
|---|---|---|---|
| `S2CalibrationHarnessTests.swift:7903` | `requestedAssetIDs` **按请求顺序**恰为 `["asset-1", "asset-2"]` | `requestedAssetIDs` **排序后**恰为 `["asset-1", "asset-2"]`（即：集合与重数不变，不再约束顺序） | **去除过度规定**，不是削弱：元素集合、元素个数、无重复三项约束全部保留；「每资产至多取一次」的产品不变量另由同函数 `:7909` 的 `requestCount == 2` 独立断言，未受影响 |

**为什么不是削弱覆盖**①：
- `requestedAssetIDs.sorted() == ["asset-1", "asset-2"]` 蕴含 `count == 2`、两元素恰为这两个 ID、无重复、无第三者。
- 唯一被放弃的约束是**元素次序**——而产品从未承诺它：`S2AssetVolumeStore.requestIfNeeded`（`S2TopBarInfoPresentation.swift:69`）对每个未解析资产各起一个 `Task { @MainActor }`，其中 `await provider.byteCount(assetID:)` 因协议方法非隔离而跳到并发执行器，两次调用的完成顺序不受语言保证。
- 该类注释与实现只承诺「每个资产至多取一次数：已解析（成功或失败）与在途中的都不再重复发起（C2）」，不含顺序承诺。

## CI #179

| 项 | 值 |
|---|---|
| run 编号 | **#179** |
| run id | `33133239957` |
| html_url | `https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/33133239957` |
| 被测提交 | `844b40b840f2b292990f159e31686299b392eb6b` |
| 分支 / 事件 | `main` / push |
| 起止 | 2026-08-28T01:33:50Z → 01:42:25Z |
| 结论 | **success** |
| **真实退出码** | **0**（`ci.yml:52` `set -o pipefail`、`:82` `exit "$test_status"`；步骤 6 success ⇒ `test_status == 0`） |
| **XCTest** | **`Executed 519 tests, with 0 failures (0 unexpected) in 25.098 (26.240) seconds`** |
| **IPA 字节数** | **836638** |
| **IPA SHA-256** | **`cefe142b5af6100ab62fadf9b351102ffc43387c519e7127dbd763e7d31ec2a2`** |
| artifact | `PhotoCleanupMVE-unsigned-844b40b840f2`（id `9671194790`，zip 包 836808 字节） |

步骤逐条：

```
step 1 [success] Set up job
step 2 [success] 检出源码
step 3 [success] 显示 Xcode 环境
step 4 [success] 运行结构自验
step 5 [success] 扫描用户可见硬编码字符串
step 6 [success] 运行 XCTest
step 7 [success] 构建未签名应用
step 8 [success] 上传可下载的未签名 IPA
step 9 [success] Complete job
```

**与 #177 的 IPA 对照（②，样本内观察）**：字节数**同为 836638**，SHA-256 不同（#177 `e5cfb0d1…4b2c` vs #179 `cefe142b…c2a2`）。字节数相同是合理的——本卡改动只在 `PhotoCleanupMVETests/`，测试代码不进 IPA，产品二进制的输入完全一致；SHA-256 不同则与既有结论一致：IPA 归档不可复现（IC-094/097 证据①）。因此**不得用 IPA 哈希做跨运行同一性判据**。

**IPA 复核说明**：上表两值取自 CI 内「未签名 IPA 校验」步骤注解（CI 侧实算，①）。本机**未重下复核**——卡内 G250 只要求「登记」，且本机 blob 下载在本轮网络下反复失败；加之归档不可复现，重下哈希本就不能用作同一性判据。

## 测试计数账本

| 项 | 数 |
|---|---|
| 继承态（`0fd97c7`） | 519 |
| 新增 | **0** |
| 改造 | **1**（`testIC099v2C2StoreFetchesEachAssetAtMostOnce` 的 `:7903` 一行，测试函数数不变） |
| 删除 | **0** |
| 本机计数（`844b40b`） | **519** |
| CI #179 实测 Executed | **519**，0 失败 |

校验：519 + 0 − 0 = **519** ✓。**无静默删除。**

## 抗抖效果（跨四次 CI 的证据链）

同一测试函数 `testIC099v2C2StoreFetchesEachAssetAtMostOnce` 的历次表现①：

| CI | 被测 | `:7903`（记录内容） | `:7909`（`requestCount`） | 结论 |
|---|---|---|---|---|
| #175 | `33d639a`（IC-102 v2） | **失败** `["asset-2"]` | **失败** `1` | 丢更新（无并发保护） |
| #177 | `46f7174`（IC-105 NSLock） | 通过 | 通过 | 侥幸顺序正确 |
| #178 | `209e2d5`（IC-104 A） | **失败** `["asset-2","asset-1"]` | 通过 | 锁生效，残留顺序不确定 |
| **#179** | **`844b40b`（本卡）** | **通过**（`.sorted()`） | 通过 | 顺序约束移除，抖动源消除 |

**须如实标注（②，不是①）**：#179 只是**一次**绿。本卡的修复是**确定性**的——`.sorted()` 后结果不再依赖两个 Task 的完成顺序，因此在该断言上不存在残留随机性；但「`main` 从此不再抖」是对整个 519 项测试集的判断，本卡只有一次运行的证据，**不足以断言全集无其他抖动源**。卡内上游证据称「决策会话已全量扫描，并发填充数组的顺序断言仅 `:7923` 一处」（决策会话①），**本卡未复核该扫描**。

## 逐条闸门结果

| 闸门 | 判定 | 依据 | 对应命令/测试 |
|---|---|---|---|
| **G248** | 通过 | 工作树空；`main` = `0fd97c7…8a8` | `git status --porcelain`、`git rev-parse main` |
| **G249** | 通过 | 恰一个文件，`--numstat` = `1 1`；产品目录零 diff | `git diff --numstat`、`git diff --name-only -- PhotoCleanupMVE/` |
| **G250** | 通过 | CI #179 success、退出码 0、**519/0**、IPA 836638 / `cefe142b…c2a2` 已登记 | CI #179；`testIC099v2C2StoreFetchesEachAssetAtMostOnce` |
| **G251** | 未触发 | CI 未失败 | — |
| **G252** | 通过 | `schemaVersion == 4`；冻结三链引用不变；CLAUDE.md 仅基线行一处 hunk | `S2Calibration.swift:118`、`git rev-parse feature/ic-089/091/092` |

## 本地门禁（真实退出码）

| 门禁 | 退出码 | 要点 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | 目录条目 177 / 产品源码引用 key 177 / 用户可见硬编码残留 0；「不少于 189 项测试的数量门禁」符合 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0 |
| `git diff --check` | **0** | 无空白错误 |

## 冻结三链与出厂值

| 项 | 值 | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 未触碰 |
| `S2CalibrationConfiguration.schemaVersion` | `4`（`S2Calibration.swift:118`） | 未变更（本卡零出厂值变更） |

## CLAUDE.md 基线行

已按卡第 5 步更新 `<top>/CLAUDE.md` 第七节基线行，**仅该行语义、一处 hunk**：新基线 = 本卡报告提交后的 tip，被测 = `844b40b840f2b292990f159e31686299b392eb6b`，CI #179，XCTest 519 项 0 失败。hunk 原文见 `change-list.md`。

## 人工判定项

**无。** 本卡改动全部位于 `PhotoCleanupMVETests/`，产品目录零 diff，无用户可见行为、几何或手势语义变化。本卡**不代 Lynn 下任何真机结论**。

## 发现但未处理的问题（只报告不修）

1. **「`main` 不再抖」只有一次绿的证据**（②，见「抗抖效果」节）。本卡未复核决策会话所称的全量扫描结论。
2. **本机网络**：`git push` 本轮连续 4 次 `schannel: failed to receive handshake` 后第 5 次带 `-c http.proxy=http://127.0.0.1:7890` 才成功；`gh api` 的 check-run annotations 端点需 2 次重试才返回。与 CLAUDE.md 第五节「两者偶有互换」的记载一致。
3. **本卡未复核 `:7753` 的顺序确定性**：按卡「不动」，其「由单 Task 串行 await 驱动」的判断来自卡内上游证据（决策会话①），本卡未独立验证。
