# IC-102 自验报告（merge-099-100 + v2 收口修复）

覆盖 IC-102 全程：两次合并（CI #174 失败）+ IC-102 v2 一行修复（CI #175 失败）。

## 结论（先行）

**本卡未通过。闸门 G234 不过，按卡「CI 1 次上限、失败即停」与下发单停止规则停在此处，未开始 IC-104。**

- **G233 通过**①：一行插入后 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` 的 blob = `c15cf4a6ee236a72125e18b29b1fed672eefb97f`，与卡规定值逐字节相等；`git diff 6d72146..33d639a --name-only` 恰为该一个文件（1 file changed, **1 insertion(+), 0 deletions**）。
- **G234 不过**①：CI **#175 failure**，被测 `33d639ade886eb6e5933a5f425ca363f87355747`，真实退出码 **65**，`Executed 519 tests, with 2 failures (0 unexpected) in 23.767 (26.878) seconds`。构建 IPA 与上传两步 **skipped**，run artifacts `total_count = 0`——**本次无 IPA 可校验**。
- **G235 通过**①：本地三项门禁真实退出码全 **0**；冻结三链引用不变；`schemaVersion == 4`。
- **G236 部分**：`Reports/IC-102/` 两件齐且含 CI #174 失败与根因记录 ✓；**`<top>/CLAUDE.md` 第七节基线行未更新** ✗（理由见「未执行项」一节，属主动上报，不是遗漏）。

**卡内根因假设（③）已被本卡实测确认为①**：#174 的 `attribute 'private' can only be used in a non-local scope` 错误类别在 #175 中**完全消失**，测试 target 完整编译并执行了全部 519 项。收口括号确实是 #174 的唯一编译障碍。

**#175 的 2 条失败是另一处独立缺陷，与本卡改动无关**（证据见「#175 失败归因」一节）：两条断言集中在同一个测试函数 `testIC099v2C2StoreFetchesEachAssetAtMostOnce`，该函数与其 helper 在 IC-099 分支 tip 与本卡 tip 之间**逐字节相同**，而同一份代码在 CI **#173 中通过**（`Executed 514 tests, with 0 failures`）。

**人工判定：无新增项**（合并与本卡修复均零行为变更；H42/H44 此前已判）。

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空（纪律 8 检查通过） |
| 继承提交 | `6d721462fbe1992181cb3f9c484d7358598cc3a9`（merge: IC-100 into main (IC-102)），开工时 `git rev-parse main` 实测相符 |
| 目标分支 | `main` |
| 本卡 fix 提交 | `33d639ade886eb6e5933a5f425ca363f87355747` |
| CI 预算 | 1 次，**已用 1 次**（#175） |
| 范围边界 | 仅第 8059 行后一行插入 + 本目录报告；未改任何其他文件 |

## IC-102 全程：两次合并留痕

IC-102 阶段基线为 `main` = `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff`（IC-097 报告提交）。两次合并的 merge-base 均为该提交。

| 合并 | 完整 SHA | 提交信息 | 第一父 | 第二父 |
|---|---|---|---|---|
| 1 | `8741a43af23ef952930bd863497c064475ce77f3` | `merge: IC-099 chain (099b+101+099v2) into main (IC-102)` | `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff` | `2334072f39c3e60d9ae708694e7ee5351415a0dd`（IC-099 链 tip） |
| 2 | `6d721462fbe1992181cb3f9c484d7358598cc3a9` | `merge: IC-100 into main (IC-102)` | `8741a43af23ef952930bd863497c064475ce77f3` | `d855484319b6d490297764c39c43b7db5a070358`（IC-100 tip） |

**冲突留痕**（本机只读复算，`git merge-tree --write-tree --name-only`，未改动任何引用）①：

- 合并 1：**无冲突**，clean 三方合并。
- 合并 2：**唯一冲突文件** `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`（`CONFLICT (content)`）；`PhotoCleanupMVE/Features/S2/S2View.swift` auto-merge 成功，无冲突。

IC-102 交付的冲突解 blob 本机 `git hash-object` 复核 = `7df93fcd2673bc7daab00ea8dca43bbaed8ef3ca`，与任务卡上游证据所述一致①。冲突解法为**两侧全保留**（099 侧断言块与 100 侧断言块并列，测试名并集 207 条无重复）。

## CI #174：失败与根因（如实记录）

| 项 | 值 |
|---|---|
| run 编号 | **#174** |
| run id | `33094622985` |
| 被测提交 | `6d721462fbe1992181cb3f9c484d7358598cc3a9` |
| 创建时间 | 2026-08-27T16:42:35Z |
| 结论 | **failure** |
| 失败步骤 | 步骤 6「运行 XCTest」（步骤 1–5 全 success） |
| 步骤 7/8 | skipped（未构建、未上传 IPA） |

check-run 注解（节选，同类错误多条）①：

```
S2CalibrationHarnessTests.swift:8605:5: error: attribute 'private' can only be used in a non-local scope
S2CalibrationHarnessTests.swift:8581:5: error: attribute 'private' can only be used in a non-local scope
S2CalibrationHarnessTests.swift:8557:5: error: attribute 'private' can only be used in a non-local scope
S2CalibrationHarnessTests.swift:8510:5: error: attribute 'private' can only be used in a non-local scope
S2CalibrationHarnessTests.swift:8502:5: error: attribute 'private' can only be used in a non-local scope
S2CalibrationHarnessTests.swift:8434:5: error: attribute 'private' can only be used in a non-local scope
S2CalibrationHarnessTests.swift:8373:5: error: attribute 'private' can only be used in a non-local scope
S2CalibrationHarnessTests.swift:8346:5: error: attribute 'private' can only be used in a non-local scope
```

报错行全部位于冲突块之后的基线尾部。

**根因**（任务卡列为③，本卡确认为①）：git 在生成冲突块时把两侧共享的函数收口 `    }` 提到了冲突块之外。「两侧全保留」后，099 侧末尾的测试函数 `testIC099v2C4SubtitleTextUsesSlashAndMiddleDot` 未收口，100 侧 5 个测试函数全部嵌入其函数体，基线尾部的 `private` 类型声明随之落入局部作用域，触发上述编译错误。

**确认依据**①：本卡仅补一行收口括号（零其他改动），#175 中该错误类别完全消失，519 项测试全部执行完毕——说明测试 target 已完整编译，收口括号是 #174 的唯一编译障碍。

## 本卡改动：唯一一行

`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` 第 8059 行（内容 `        }`，`testIC099v2C4SubtitleTextUsesSlashAndMiddleDot` 内 forEach 闭包的收口）之后插入一行，内容为四个空格 + 右花括号：

```diff
@@ -8056,6 +8056,7 @@
                 expected
             )
         }
+    }
     // MARK: - IC-100 v2：底部竖向排布互换（安全区 → 操作条 → 横栏）
```

**闸门 B / G233 逐字节断言**①：

| 项 | 值 |
|---|---|
| 改动前 blob（= IC-102 交付值） | `7df93fcd2673bc7daab00ea8dca43bbaed8ef3ca` |
| 改动后 blob（工作区 `git hash-object`） | `c15cf4a6ee236a72125e18b29b1fed672eefb97f` |
| 提交后 blob（`git rev-parse HEAD:<file>`） | `c15cf4a6ee236a72125e18b29b1fed672eefb97f` |
| 卡规定值 | `c15cf4a6ee236a72125e18b29b1fed672eefb97f` |
| 判定 | **相等，闸门 B 通过** |

`git diff 6d721462fbe1992181cb3f9c484d7358598cc3a9..33d639ade886eb6e5933a5f425ca363f87355747 --name-only` 输出恰为 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` 一行；`--stat` = `1 file changed, 1 insertion(+)`。

**对两个父版本纯插入零删除**（本卡复核，含本卡新增的一行）①：

| 基准 | 增 | 删 |
|---|---|---|
| `2334072f39c3e60d9ae708694e7ee5351415a0dd`（IC-099 tip）→ `33d639a` | 210 | **0** |
| `d855484319b6d490297764c39c43b7db5a070358`（IC-100 tip）→ `33d639a` | 640 | **0** |

## 测试计数账本

| 提交 | 测试函数数（本机 `grep -cE "^\s+func test"`） | CI 实测 Executed |
|---|---|---|
| `ef9d46a`（IC-102 前 `main` 基线） | — | 497（CI #168，CLAUDE.md 第七节） |
| `2334072`（IC-099 链 tip） | 514 | 514（CI #173） |
| `d855484`（IC-100 tip） | 502 | 502（CI #172 success） |
| `33d639a`（本卡 tip） | **519** | **519**（CI #175） |

并集校验：497 + (514 − 497) + (502 − 497) = 497 + 17 + 5 = **519** ✓，与 CI #175 的 `Executed 519 tests` 吻合。**无静默删除**（对两父纯插入零删除已在上一节佐证）。

## CI #175：本卡取的唯一一次 CI

| 项 | 值 |
|---|---|
| run 编号 | **#175** |
| run id | `33101881151` |
| html_url | `https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/33101881151` |
| 被测提交 | `33d639ade886eb6e5933a5f425ca363f87355747` |
| 分支 / 事件 | `main` / push |
| 起止 | 2026-08-27T18:07:15Z → 18:16:04Z（attempt 1） |
| 结论 | **failure** |
| 失败步骤 | 步骤 6「运行 XCTest」 |
| **真实退出码** | **65**（注解原文 `Process completed with exit code 65.`） |
| XCTest 执行摘要 | `Executed 519 tests, with 2 failures (0 unexpected) in 23.767 (26.878) seconds` |
| 步骤 7/8 | skipped |
| IPA | **无**（run artifacts `total_count = 0`；字节数与 SHA-256 **不适用**，非「待补核」——产物根本未生成） |

步骤逐条：

```
step 1 [success] Set up job
step 2 [success] 检出源码
step 3 [success] 显示 Xcode 环境
step 4 [success] 运行结构自验
step 5 [success] 扫描用户可见硬编码字符串
step 6 [failure] 运行 XCTest
step 7 [skipped] 构建未签名应用
step 8 [skipped] 上传可下载的未签名 IPA
step 9 [success] Complete job
```

两条失败断言原文①：

```
S2CalibrationHarnessTests.swift:7903: error: -[PhotoCleanupMVETests.S2CalibrationHarnessTests
  testIC099v2C2StoreFetchesEachAssetAtMostOnce] : XCTAssertEqual failed:
  ("["asset-2"]") is not equal to ("["asset-1", "asset-2"]")

S2CalibrationHarnessTests.swift:7909: error: -[PhotoCleanupMVETests.S2CalibrationHarnessTests
  testIC099v2C2StoreFetchesEachAssetAtMostOnce] : XCTAssertEqual failed:
  ("1") is not equal to ("2")

Test Case '-[PhotoCleanupMVETests.S2CalibrationHarnessTests
  testIC099v2C2StoreFetchesEachAssetAtMostOnce]' failed (0.707 seconds).
```

两条失败同属**一个**测试函数，`(0 unexpected)` 表示无崩溃、无超时。

## #175 失败归因

### 与本卡改动无关（①）

1. 失败测试函数 `testIC099v2C2StoreFetchesEachAssetAtMostOnce` 位于第 7884–7910 行，本卡插入点在第 8060 行，**不在同一区段**。
2. 该测试函数在 `2334072`（IC-099 tip）与 `33d639a`（本卡 tip）之间 **逐字节相同**（本机 `diff -q` 无差异）。
3. 其 helper `private final class CountingAssetVolumeProvider` 在两版之间同样 **逐字节相同**。
4. `2334072` 之上的提交 `968998579306fc1a4be861f783a49a3211987114` 在 CI **#173（run id 33081195895）success**，注解 `Executed 514 tests, with 0 failures (0 unexpected) in 31.047 (34.549) seconds` —— 同一份测试代码在该运行内通过。
5. 该文件对两个父版本均纯插入零删除，7875–7910 区段未被触碰。

**结论**：这是一处**与本卡、也与两次合并无关的既存缺陷**，表现为时序相关（#173 过、#175 不过）。

### 机制

**① 事实链**：同一次运行中，第 7900 行 `XCTAssertEqual(store.byteCount(for: "asset-1"), 2_466_000)` **通过**（未出现在失败注解中）。`2_466_000` 只可能来自 `CountingAssetVolumeProvider.byteCount(assetID:)` 函数体内对 `byteCounts["asset-1"]` 的查表返回值——即该函数**确实为 asset-1 执行过一次**。但同一次运行里 `requestedAssetIDs` 只记录了 `["asset-2"]`，`requestCount` 为 1。**函数执行了，其 `requestedAssetIDs.append(assetID)` 的写入丢失了。**

**③ 推测（标注为推测）**：`CountingAssetVolumeProvider` 是普通 `final class`，`func byteCount(assetID: String) async -> Int64?` 既未标 `@MainActor` 也非 actor 隔离。产品侧 `S2AssetVolumeStore.requestIfNeeded` 对每个未解析资产各起一个 `Task { @MainActor … }`，其中 `await provider.byteCount(assetID:)` 会从 MainActor 跳到并发执行器执行。测试连续请求 asset-1 与 asset-2（asset-1 的第二次被 `inFlightAssetIDs` 去重），两个 Task 的 provider 调用因而可真正并发，`requestedAssetIDs` 这个无同步保护的 `Array` 上发生写入竞争，丢失一次 append。这与「#173 过、#175 不过」的时序相关性一致。

**验证方式**（本卡不实施）：把该 helper 的存储标注 `@MainActor`（或改为 actor / 加串行队列保护 `requestedAssetIDs`）后重跑该测试；或在 CI 上对该测试开启 Thread Sanitizer。

**本卡不修的理由**：① 卡明确「CI 1 次上限，失败即停，**不得再改第二处**」；② 该 helper 属 IC-099 交付范围，不在本卡范围内（范围外条款：除第 2 步一行插入、报告、CLAUDE.md 基线行外禁止改动任何文件）。

## 逐条闸门结果

| 闸门 | 判定 | 依据 | 对应测试/命令 |
|---|---|---|---|
| **闸门 B**（逐字节断言） | **通过** | blob = `c15cf4a6ee236a72125e18b29b1fed672eefb97f`，与卡规定值相等 | `git hash-object PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` |
| **G233** | **通过** | 同上；`git diff 6d72146..HEAD --name-only` 恰一个文件，1 增 0 删 | `git diff --name-only` / `--stat` |
| **G234** | **不过** | CI #175 failure、真实退出码 **65**、`Executed 519 tests, with 2 failures`；步骤 7/8 skipped，artifacts 0，**无 IPA** | CI #175；失败函数 `testIC099v2C2StoreFetchesEachAssetAtMostOnce` |
| **G235** | **通过** | 本地三项门禁退出码全 0；冻结三链引用不变；`schemaVersion == 4` | `Scripts/selfcheck.ps1`、`Scripts/scan-hardcoded-user-visible-strings.ps1`、`git diff --check`、`git rev-parse feature/ic-089/091/092`、`S2Calibration.swift:118` |
| **G236** | **部分** | 报告两件齐、含 #174 失败与根因 ✓；CLAUDE.md 基线行 **未更新** ✗ | 见「未执行项」 |

## 本地门禁（真实退出码）

| 门禁 | 退出码 | 要点 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | 目录条目 177 / 产品源码引用 key 177 / 用户可见硬编码残留 0；「不少于 189 项测试的数量门禁」符合 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0，目录 key 与产品源码引用一致 |
| `git diff --check` | **0** | 无空白错误 |

## 冻结三链与出厂值

| 项 | 值 | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 与 CLAUDE.md 记载一致，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 同上 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 同上 |
| `S2CalibrationConfiguration.schemaVersion` | `4`（`S2Calibration.swift:118`） | 未变更（本卡零出厂值变更） |

## 未执行项：CLAUDE.md 第七节基线行

**未更新，主动上报，请决策会话处置。**

卡第 5 步的授权文本把该行内容绑定为「新基线 = 本卡报告提交后的 tip；被测 = fix 提交完整 SHA、CI 编号、XCTest **519/0**」。实测为 CI #175 **failure**、**519/2**、退出码 **65**。按此写入即构成不实基线（纪律 5：不伪造通过），而改写成「红态基线」又超出该行被授权的语义范围（纪律：任务卡没写的事情不做；`<top>/CLAUDE.md` 默认禁止修改，仅在卡内该条授权范围内可写）。故本卡**不动该行**。

**由此产生的一处不一致，须由决策会话处置**：`<top>/CLAUDE.md` 第七节现载 `main = ef9d46aaaf6c6f0e2bae29712e751d39994f59ff`，而 `main` 的真实 tip 已因本卡推送变为 `33d639ade886eb6e5933a5f425ca363f87355747`（红态，无 IPA）。下一张卡开工前若按 CLAUDE.md 核对基线会不符。

## 人工判定项

**无新增项。** 两次合并与本卡一行收口修复均为零行为变更，不改变任何用户可见行为、几何或手势语义；H42 / H44 已在此前卡判定。本卡**不代 Lynn 下任何真机结论**。

## 发现但未处理的问题（只报告不修）

1. **`CountingAssetVolumeProvider.requestedAssetIDs` 无并发保护**（③，机制见上）。这是 #175 两条失败的直接来源，属既存缺陷，与本卡与两次合并无关。同文件的 `private final class CountingAssetSizeProber`（`S2CalibrationHarnessTests.swift:9000`）结构相同——同为 `final class` + 非隔离 `async` 方法 + 无保护的 `requestedAssetIDs` 数组，疑似同类风险（③，本轮未观测到其失败）。
2. **`main` 现处红态**：tip `33d639a`，CI #175 failure，无 IPA 产物。
3. **本机网络配方与记载相反**：本轮 `git push` 直连失败（`schannel: failed to receive handshake`），必须带 `-c http.proxy=http://127.0.0.1:7890` 才成功；`gh api` 带代理与直连**均**间歇性 `EOF`，需 2–4 次重试才拿到结果。与 CLAUDE.md 第五节「git 直连 / gh 带代理」的记载在本轮是反的（该节已注明「两者偶有互换」，本轮即该情形）。
