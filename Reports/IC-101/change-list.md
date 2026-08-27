# IC-101 变更清单（CI 错误摘录 + 扫描器豁免 + 格式器独立成文件）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交 | `251a9a849f71a1e6eae4646ba4a97192905f87d4`（IC-099b 交付，CI #170、508/0） |
| 分支 | `feature/ic-099-top-bar-date-index-size`（未重切） |
| 分支 tip（代码部分，CI #171 被测提交） | `c7547072edaa3ac5c607e0780be2ea5ccd095780` |
| 报告提交 | 只含 `Reports/IC-101/`，命中 `paths-ignore`，**不触发 CI** |

三个提交，各自可单独 cherry-pick：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `d877ec8…` | `ci: XCTest 失败后的错误行摘录扩展到产品目录（IC-101 R1）` |
| 2 | `73d527c…` | `build: 扫描器新增第二条逐行规格锁定豁免（IC-101 R2）` |
| 3 | `c7547072edaa3ac5c607e0780be2ea5ccd095780` | `refactor(s2): S2AssetVolumeFormatter 移入独立文件并对齐豁免规则（IC-101 R3）` |

## 文件变化（`git diff --numstat 251a9a8..HEAD`）

| 文件 | 增 | 删 | 归属 |
|---|---|---|---|
| `.github/workflows/ci.yml` | 1 | 1 | R1 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 10 | 0 | R2 |
| `PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift` | 47 | 0 | R3（新文件） |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 0 | 47 | R3（移出） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 4 | 0 | R3（注册） |

**测试文件零改动**（`git diff 251a9a8..HEAD -- PhotoCleanupMVETests/` 无输出）。

## 逐项改动

### R1（提交 1）——`ci.yml` 一行

`失败后摘录错误行` 的 grep 模式：

```
- 'PhotoCleanupMVETests/.*error:|Test Case .* failed'
+ 'PhotoCleanupMVE/.*error:|PhotoCleanupMVETests/.*error:|Test Case .* failed'
```

原有两支保留，只在前面并上产品目录一支。`set -o pipefail`、`test_status=0`、`test_status=$?`、`exit "$test_status"`、`if [ "$test_status" -ne 0 ]` 分支、`executed_line` 摘要 grep、9 个步骤的名称与顺序、`on.push.paths-ignore` **全部未动**。

### R2（提交 2）——扫描器一个 `elseif`

新增变量 `$isLockedAssetVolumeFormat`（路径恰为 `PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift` 且值以 ` KB` / ` MB` / ` GB` 结尾），并在既有 S3 豁免分支与残留分支之间插入一个 `elseif` 分支，把命中行计入 `$specExemptions`，理由 `S2 单张 KB/MB/GB 向下截断由规格锁定，禁止本地化改造`。

**既有 S3 豁免分支、诊断区豁免（`$inGeometryDiagnosticProtocol`）、`Add-Residual` 逻辑、目录 key 双向校验、Info.plist 边界、其余全部规则一行未改。**

### R3（提交 3）——格式器独立成文件

**新文件** `PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift`：`import Foundation` + `enum S2AssetVolumeFormatter`（三档口径与公开签名不变）。

**`project.pbxproj` 注册四处**（新对象 id 取各段最大值 +1，写入前已断言唯一）：

| 注册点 | id |
|---|---|
| `PBXBuildFile` | `20000000000000000000002F` |
| `PBXFileReference` | `100000000000000000000032` |
| `S2` 组 `children` | 引用 `…0032` |
| `Sources` 构建阶段 | 引用 `…002F` |

**`S2NativePhotoPager.swift`** 删去该 enum 与其文档注释共 47 行，其余一字未动。

**两处偏离「纯移动」**（详见 `self-check.md`「与任务卡的偏离」）：

1. 私有助手 `truncatedTenths` 返回类型 `String` → `Int64`，单位改在各分支返回字面量里写死。原写法以 `\(suffix)` 结尾，不满足 R2 豁免判据，移出诊断区后**实测被判残留**（扫描器退出码 1）。算术与输出逐字节不变，由 P1 八用例 + 六个边界用例背书。
2. 类顶部「放置说明」7 行注释由「临时安置、待定」改写为 IC-101 的定案结论，并补一句「单位不得再抽成插值参数」的约束。其余注释一字未动。

## 未改动清单

| 项 | 状态 |
|---|---|
| `Scripts/selfcheck.ps1` | **未动** |
| 扫描器的诊断区豁免（收窄挂账另卡） | **未动** |
| `ci.yml` 除 grep 模式外的任何行 | **未动** |
| 全部测试文件 | **零 diff** |
| 顶部信息区、探针、S3、手势、横栏、操作条、图片请求策略 | 未动 |
| `Localizable.xcstrings` | 未动 |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md` | 未动 |
| `feature/ic-089/091/092` 冻结三链 | 未触碰 |

未合并 `main`；未 rebase / amend / force push / 改写历史 / 删分支。

## 占位值登记

**本卡未新增、未修改、未删除任何 `factoryPlaceholder` 占位值；未新增标定参数。**

`S2CalibrationConfiguration.schemaVersion` **仍为 4**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`），一字未动——闸门 C 未触发。

R3 移动的三个进制常量（1e3 / 1e6 / 1e9）随类型整体搬家，取值未变，非标定参数、非规格量、不入登记表。

## 产品行为净变化

**零。**

- R1、R2 只影响 CI 诊断输出与本地扫描门禁，不进产品二进制。
- R3 行为零变化：公开签名 `S2AssetVolumeFormatter.string(forByteCount:)` 与三档口径未变，八个卡内用例与六个边界用例输出逐字不变（CI #171 全过）。
- 旁证：IPA 字节数 **823371**，与 IC-099b 的 CI #170 **完全相同**。
