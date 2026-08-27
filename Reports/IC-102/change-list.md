# IC-102 变更清单（merge-099-100 + v2 收口修复）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| IC-102 阶段基线 | `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff`（IC-097 报告提交，CI #168、497/0） |
| 合并 1 | `8741a43af23ef952930bd863497c064475ce77f3` |
| 合并 2（= 本卡继承提交） | `6d721462fbe1992181cb3f9c484d7358598cc3a9` |
| 本卡 fix 提交（CI #175 被测提交） | `33d639ade886eb6e5933a5f425ca363f87355747` |
| 报告提交 | 只含 `Reports/IC-102/`，命中 `paths-ignore`，**不触发 CI** |
| 目标分支 | `main` |

### IC-102 两次合并

| # | 完整 SHA | 提交信息 | 第一父 | 第二父 |
|---|---|---|---|---|
| 1 | `8741a43af23ef952930bd863497c064475ce77f3` | `merge: IC-099 chain (099b+101+099v2) into main (IC-102)` | `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff` | `2334072f39c3e60d9ae708694e7ee5351415a0dd` |
| 2 | `6d721462fbe1992181cb3f9c484d7358598cc3a9` | `merge: IC-100 into main (IC-102)` | `8741a43af23ef952930bd863497c064475ce77f3` | `d855484319b6d490297764c39c43b7db5a070358` |

两次合并的 merge-base 均为 `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff`。

### 本卡新增提交（1 个，可单独 cherry-pick）

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `33d639ade886eb6e5933a5f425ca363f87355747` | `fix(test): 补齐 IC-102 冲突解缺失的函数收口括号（IC-102 v2）` |

## 文件变化

### 本卡（`git diff --numstat 6d72146..33d639a`）

| 文件 | 增 | 删 | 归属 |
|---|---|---|---|
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | **1** | **0** | 卡内第 2 步唯一改动 |

**合计 1 file changed, 1 insertion(+), 0 deletions.** 无其他文件变化。

改动内容（第 8059 行后插入一行，四个空格 + 右花括号）：

```diff
@@ -8056,6 +8056,7 @@
                 expected
             )
         }
+    }
     // MARK: - IC-100 v2：底部竖向排布互换（安全区 → 操作条 → 横栏）
```

### IC-102 合并 2 引入的文件变化（`6d72146` 相对第一父 `8741a43`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 101 | — |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 105 | 40（与第一父合计） |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 209 | — |
| `Reports/IC-100/change-list.md` | 120 | — |
| `Reports/IC-100/self-check.md` | 190 | — |

合计 685 insertions, 40 deletions（相对第一父）。

### IC-102 合并 2 相对第二父 `d855484`

18 个文件，2731 insertions, 10 deletions（即 IC-099 链带入 IC-100 侧的全部内容），含 `PhotoCleanupMVE/Services/AssetSizeScanner.swift`（420 增）、`PhotoCleanupMVE/Features/S2/S2TopBarInfoPresentation.swift`（150 增）、`Scripts/scan-hardcoded-user-visible-strings.ps1`（10 增）等。

## blob 逐字节登记（闸门 B / G233）

| 阶段 | `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` blob |
|---|---|
| IC-102 交付的冲突解（`6d72146` 内） | `7df93fcd2673bc7daab00ea8dca43bbaed8ef3ca` |
| 本卡改动后（工作区） | `c15cf4a6ee236a72125e18b29b1fed672eefb97f` |
| 本卡提交后（`33d639a` 内） | `c15cf4a6ee236a72125e18b29b1fed672eefb97f` |
| **卡规定值** | `c15cf4a6ee236a72125e18b29b1fed672eefb97f` |
| 判定 | **相等** |

## 冲突留痕（只读复算，未改动任何引用）

`git merge-tree --write-tree --name-only`：

| 合并 | 冲突文件 | 备注 |
|---|---|---|
| 1（`ef9d46a` ← `2334072`） | 无 | clean 三方合并 |
| 2（`8741a43` ← `d855484`） | `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | `CONFLICT (content)`；`S2View.swift` auto-merge 成功 |

冲突解法：**两侧全保留**（099 侧断言块与 100 侧断言块并列，测试名并集 207 条无重复）。缺陷在于 git 把两侧共享的函数收口 `    }` 提到了冲突块之外，导致「全保留」后该函数未收口——本卡补的就是这一行。

## 测试计数账本

| 提交 | 本机测试函数数 | CI Executed | CI |
|---|---|---|---|
| `ef9d46a`（阶段基线） | — | 497 | #168 success |
| `2334072`（IC-099 链 tip） | 514 | 514 | #173 success（被测 `9689985793…7114`） |
| `d855484`（IC-100 tip） | 502 | 502 | #172 success |
| `6d72146`（合并 2） | 519 | — | #174 **failure**（编译不过，未执行） |
| `33d639a`（本卡 tip） | **519** | **519** | #175 **failure**（2 项失败） |

并集校验：497 + 17（IC-099 链）+ 5（IC-100）= **519** ✓。

**新增 / 改造 / 删除**（本卡）：新增 0、改造 0、删除 **0**。本卡零测试变更，仅补一个语法收口括号。对两个父版本的纯插入零删除已复核：vs `2334072` = 210 增 / **0** 删；vs `d855484` = 640 增 / **0** 删。

## CI 记录

| run | id | 被测提交 | 结论 | 真实退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|
| **#174** | `33094622985` | `6d721462fbe1992181cb3f9c484d7358598cc3a9` | **failure** | 非 0（步骤 6「运行 XCTest」失败） | 未执行（编译错误：`attribute 'private' can only be used in a non-local scope`，多处） | 无（步骤 7/8 skipped） |
| **#175** | `33101881151` | `33d639ade886eb6e5933a5f425ca363f87355747` | **failure** | **65** | `Executed 519 tests, with 2 failures (0 unexpected) in 23.767 (26.878) seconds` | **无**（步骤 7/8 skipped，artifacts `total_count = 0`） |

#175 的 2 条失败均在 `testIC099v2C2StoreFetchesEachAssetAtMostOnce`（`S2CalibrationHarnessTests.swift:7903` 与 `:7909`），属既存缺陷，详见 self-check「#175 失败归因」。

**CI 预算**：卡内上限 1 次，**已用 1 次**。按卡「失败即停，不得再改第二处」停卡。

## 占位值登记

**本卡无占位值变更，无出厂值变更。** `S2CalibrationConfiguration.schemaVersion` 保持 **4**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`），未递增（第六节纪律：仅出厂值变更时才递增，本卡零出厂值变更）。

## 卡内取定登记

**无。** 本卡无任何卡内取定项。

## 未执行项

| 卡内条目 | 状态 | 理由 |
|---|---|---|
| 第 5 步：更新 `<top>/CLAUDE.md` 第七节 `main` 基线行 | **未执行** | 授权文本把该行内容绑定为「被测 = fix 提交 SHA、CI 编号、XCTest **519/0**」。实测 CI #175 failure、519/**2**、退出码 65，按该文本写入即为不实基线（纪律 5）；改写成红态基线又超出被授权的语义范围。故不动该行，交决策会话处置。**副作用**：CLAUDE.md 第七节现载 `main = ef9d46a…`，真实 tip 已是 `33d639a…`，两者不一致。 |

## 范围核对

| 项 | 结果 |
|---|---|
| 除第 2 步一行插入 + `Reports/IC-102/` 外是否改动其他文件 | **否**（`git diff 6d72146..33d639a --name-only` 恰一个文件） |
| 是否 revert / rebase / amend / force push / 改写历史 / 删分支 | **否** |
| 是否触碰冻结三链 | **否**（`b368a6c` / `6736f1e` / `a7cc1ec` 引用未变） |
| 是否实施第 133 条「改原始」取数分派变更 | **否**（属 IC-103 / IC-104 子项 A，本卡零行为变更） |
| 是否修改 SPEC / Decision_log | **否** |
| 是否开始 IC-104 | **否**（下发单停止规则：IC-102 v2 闸门不过即停，不得开始 104） |
