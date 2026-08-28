# IC-107 变更清单：IC-104 批量交付（A+B+C v4）合并入 main

## 提交

| 项 | 完整 SHA |
|---|---|
| 合并前 `main` | `e6bd5aa890bff15b18c4569da4ae73c75f622578` |
| 被合并分支 tip | `fa9593688faa26ecf590aea0b9d83fe55b933bc7` |
| 分支代码 tip（#189 被测） | `7295ed674bfee98cd6ef745854cae31c99ade7a8` |
| **merge 提交** | **`8f598f219065fc9b20b7d0d15be11c120fce1c6b`** |
| 报告提交 | 只含 `Reports/IC-107/`，命中 `paths-ignore`，**不触发 CI** |

### merge 提交细节

| 项 | 值 |
|---|---|
| 提交信息 | `merge: IC-104 single-build batch (A+B+C v4) into main (IC-107)` |
| 方式 | `git merge --no-ff`（**未 rebase、未 force push**） |
| 第一父 | `e6bd5aa890bff15b18c4569da4ae73c75f622578` |
| 第二父 | `fa9593688faa26ecf590aea0b9d83fe55b933bc7` |
| merge-base | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（= `main` tip，故 `main` 是分支祖先） |
| 冲突 | **无**（exit 0；合并前 `git merge-tree` 只读预演亦为 0 冲突） |

## 文件变化（`e6bd5aa..8f598f2`）

合计 **12 files changed, 2005 insertions(+), 255 deletions(-)**。

带入 `main` 的内容按子项归类：

| 子项 | 内容 |
|---|---|
| **A** | 占用空间改取原始资源字节数（第 133 条）——`S2TopBarInfoPresentation.swift`、`AssetSizeScanner.swift` |
| **B** | 隐藏态竖向手势反转（第 132 条）——`S2StateMachine.swift`、`S2StateMachineTests.swift` |
| **C v4** | 截图等距带旧位锚定 + 带底缘视觉锚——`S2Calibration.swift`、`S2View.swift`、`S2NativePhotoPager.swift`、`Localizable.xcstrings` |
| 报告 | 新建 `Reports/IC-104/self-check.md`、`Reports/IC-104/change-list.md` |

链内新增 merge 提交：`addae57`（IC-104 子项 A 期间继承 IC-106）+ 本次 `8f598f2`。

## 树同一性（G253）

```
git diff 8f598f219065fc9b20b7d0d15be11c120fce1c6b fa95936
→ （空）
```

预演阶段亦已确认：`git merge-tree --write-tree` 得到的合并树 `87ecca71169fb612ee3ce565c1a958db7dbf0ffe` **等于**分支树。

## CI（G254）

| 项 | 值 |
|---|---|
| run 编号 / id | **#190** / `33192930916` |
| 被测提交 | `8f598f219065fc9b20b7d0d15be11c120fce1c6b` |
| 起止 | 2026-08-28T17:03:55Z → 17:08:06Z |
| 结论 | **success**，9/9 步全绿 |
| XCTest | **520 项 0 失败**，`in 31.076 (54.472) seconds` |
| 真实退出码 | **0** |
| **IPA 字节数** | **837917** |
| **IPA SHA-256** | **`3557fca5a7e71dc3012ac380b8730bbc76d40f471cf358618dfa9ab109d27dca`** |
| artifact | `PhotoCleanupMVE-unsigned-8f598f219065`（id `9694637119`，zip 838087 字节） |

字节数与 #189 相同、SHA-256 不同，属 IPA 归档不可复现的既有结论（IC-094 / IC-097①）；同一性由 G253 树同一性把关。

## 占位值登记

| 项 | 值 |
|---|---|
| 合并后 `main` 上 `schemaVersion` | **6**（`S2Calibration.swift:118`，全仓唯一定义） |
| 版本号沿革 | 4 → 6 随 IC-104 子项 C（5 为冻结 `feature/ic-092-nx-window-follow` 链占用） |

## CLAUDE.md 更新（卡内授权，按附录 A）

| 项 | 内容 |
|---|---|
| A1 | 第七节「当前阶段」整节替换；占位符填入 `<MERGE_SHA>` = `8f598f2…1c6b`、`<CI_RUN>` = `190`、`<REPORT_SHA>` = 本报告提交 SHA。第七节「未定项」小节原文不动 |
| A2 | 第八节末尾追加第 10～14 条陷阱（五条） |

CLAUDE.md 位于 `<top>/`，不在仓库内，故不产生仓库提交。

## 范围核对

| 项 | 结果 |
|---|---|
| 任何代码改动 | **无**（仅合并 + 报告） |
| rebase / force push / 删分支 | **否**；分支 `feature/ic-104-single-build-batch` 保留不删 |
| SPEC / Decision_log / `ci.yml` / `Scripts/` | **未触碰** |
| 冻结三链 | **未触碰**（`b368a6c` / `6736f1e` / `a7cc1ec` 引用不变） |
| CI 预算 | 1 次，**已用 1 次** |

## 卡内笔误登记

1. **G254** 写「同树代码 **#187** 已绿」——按 C v4 应为 **#189**（#187 是 C v3 的 run）。
2. **「本卡显式授权」** 写「追加第八节**四条**陷阱」，附录 A2 标题写「**五条**」并列出 10～14。以附录正文为准，已追加五条。
