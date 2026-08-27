# IC-101 自验报告（ci-and-scanner-infra）

## 结论（先行）

R1、R2、R3 全部交付。**CI 结果：CI #171 success**，被测提交 `c7547072edaa3ac5c607e0780be2ea5ccd095780`，XCTest **508 项、0 失败**（计数不变，符合 G222 预期），9 步全 success，被测命令真实退出码 **0**；IPA **823371 字节**、SHA-256 `88ecadac55b5c69bb523e98583b9a4cfa2045355620c42d3c842ad7e8455582a`，本地重下复核逐字节一致。**CI 只用了 1 次**（上限 2）。

本地三项门禁真实退出码全为 **0**。IC-099b 的 11 项断言**一字未改、全部原样通过**。

`ci.yml` 改动 **1 增 1 删**（仅 grep 模式一行），扫描器改动 **10 增 0 删**（仅新增一个 `elseif` 分支）——**两文件均未越出卡内两点**。三道闸门（A 判定语义 / B 既有门禁 / C 标定参数与产品行为）**均未触发**。

**一处必须报告的偏离**：卡内 R2 的豁免判据（值以 ` KB`/` MB`/` GB` 结尾）与 R3 的「纯移动」在 `S2AssetVolumeFormatter` 的一行上**不能同时按字面满足**——原实现把单位抽成插值参数，该行不以字面单位结尾。已实测取证并按「行为零变化」的最小改法解决，详见「与任务卡的偏离」一节。

**人工判定：无**（基础设施卡）。

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空 |
| 继承提交 | `251a9a849f71a1e6eae4646ba4a97192905f87d4`（IC-099b 交付，CI #170、508/0） |
| 目标分支 | `feature/ic-099-top-bar-date-index-size`（未重切） |
| 分支 tip（代码部分） | `c7547072edaa3ac5c607e0780be2ea5ccd095780` |
| CI | **#171 success（1/2）** |
| 合并动作 | 无 |

## R1：`ci.yml` 错误摘录扩展

`git diff` 全文（**1 增 1 删，只有 grep 模式那一行**）：

```diff
@@ -68,7 +68,7 @@ jobs:
           if [ "$test_status" -ne 0 ]; then
             failure_lines="$(
               /usr/bin/grep -E \
-                'PhotoCleanupMVETests/.*error:|Test Case .* failed' \
+                'PhotoCleanupMVE/.*error:|PhotoCleanupMVETests/.*error:|Test Case .* failed' \
                 "$test_log" | tail -n 50 || true
             )"
             if [ -n "$failure_lines" ]; then
```

**判定语义逐条核对未动**：

| 判定要素 | 状态 |
|---|---|
| `set -o pipefail`（第 52 行） | 未动 |
| `test_status=0` / `test_status=$?`（第 55、57 行） | 未动 |
| `exit "$test_status"`（第 82 行） | 未动 |
| `if [ "$test_status" -ne 0 ]` 分支结构 | 未动 |
| `executed_line` 摘要 grep（第 61～63 行） | 未动 |
| 9 个步骤的名称、顺序、`run` 体其余各行 | 未动 |
| `on.push.paths-ignore`（`Reports/**`、`**.md`） | 未动 |

新模式保留了原有的两支（`PhotoCleanupMVETests/.*error:`、`Test Case .* failed`），只在前面并上 `PhotoCleanupMVE/.*error:`。**闸门 A 未触发。**

**如实标注未覆盖**：本卡**没有**、也不允许为验证而故意推一个编译失败的提交，因此「产品源码编译错误能被摘录出具体行」这一点在本卡内**未经真实命中验证**。CI #171 是 success，`if [ "$test_status" -ne 0 ]` 分支根本没有进入。**待下一次真实产品编译错误自证。**

可作为旁证的是 IC-099b 的实测反面案例：CI #169 的唯一产品源码错误行是

```
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift:12:13: error: generic parameter 'R' could not be inferred
```

该行含 `PhotoCleanupMVE/` 且含 `error:`，**新模式在文本上能匹配它，旧模式不能**——这是对模式的静态核对（③），不是对 CI 行为的实测。

## R2：扫描器第二条规格锁定豁免

`git diff` 全文（**10 增 0 删**）：

```diff
@@ -155,6 +155,8 @@ foreach ($file in $swiftFiles) {
             }
             $isLockedVolumeFormat = $relativePath -eq "PhotoCleanupMVE/Core/S3StateMachine.swift" -and
                 ($value.EndsWith(" GB") -or $value.EndsWith(" MB"))
+            $isLockedAssetVolumeFormat = $relativePath -eq "PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift" -and
+                ($value.EndsWith(" KB") -or $value.EndsWith(" MB") -or $value.EndsWith(" GB"))
             if ($isLockedVolumeFormat) {
                 $specExemptions.Add([PSCustomObject]@{
                     Path = $relativePath
@@ -163,6 +165,14 @@ foreach ($file in $swiftFiles) {
                     Reason = "十进制 MB/GB 向下截断由规格锁定，本卡禁止本地化改造"
                 })
             }
+            elseif ($isLockedAssetVolumeFormat) {
+                $specExemptions.Add([PSCustomObject]@{
+                    Path = $relativePath
+                    LineNumber = $lineNumber
+                    Value = $value
+                    Reason = "S2 单张 KB/MB/GB 向下截断由规格锁定，禁止本地化改造"
+                })
+            }
             elseif ($catalogKeys -notcontains $value) {
                 Add-Residual $relativePath $lineNumber $value "用户消息或展示 helper 直接返回字符串"
             }
```

- **逐行判定、按路径绑定**，不是区间豁免：判据是 `$relativePath -eq <精确路径>` 且 `$value.EndsWith(...)`，与 S3 那条同构。
- **既有 S3 豁免分支一行未改**；**诊断区豁免（`$inGeometryDiagnosticProtocol`）一行未改**——其「从某行到文件末尾」偏宽的收窄按卡内要求挂账另卡，本卡不做。
- 豁免理由文案与 S3 同格式：`S2 单张 KB/MB/GB 向下截断由规格锁定，禁止本地化改造`。

## R3：`S2AssetVolumeFormatter` 移入独立文件

新文件 `PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift`（47 行），并在 `project.pbxproj` 注册**四处**（4 增 0 删）：

| 注册点 | 新对象 id | 位置 |
|---|---|---|
| `PBXBuildFile` | `20000000000000000000002F` | 紧随 `S2TemporaryPhotoImageStrategy.swift（源码）` |
| `PBXFileReference` | `100000000000000000000032` | 紧随 `S2TemporaryPhotoImageStrategy.swift` |
| `S2` 组 `children`（`30000000000000000000000D`） | 引用 `…0032` | 组内末位 |
| `Sources` 构建阶段 | 引用 `…002F` | 紧随 `S2TemporaryPhotoImageStrategy.swift（源码）` |

两个新 id 取自各自区段的最大值 +1（`1000…` 段原最大 `31`、`2000…` 段原最大 `2E`），写入前已断言全文不含这两个 id。格式逐字符照抄同组既有条目。

`S2NativePhotoPager.swift` 相应减少 47 行（**0 增 47 删**），仅删除该 enum 与其文档注释，其余一字未动。

## 与任务卡的偏离（纪律 3：如实报告，不硬套）

### 偏离：卡内 R2 的豁免判据与 R3 的「纯移动」在一行上不相容

**实测取证**：把 enum 按字面原样移出诊断区后跑扫描器，结果是

```
- PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift:35 [S2 单张 KB/MB/GB 向下截断由规格锁定，禁止本地化改造] \(byteCount / bytesPerKilobyte) KB      ← 豁免命中
- PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift:46 [用户消息或展示 helper 直接返回字符串] \(tenths / 10).\(tenths % 10) \(suffix)               ← 判为残留
```

扫描器退出码 **1**。

**原因**：IC-099b 的实现把单位抽成了参数，私有助手的返回字面量是 `"\(tenths / 10).\(tenths % 10) \(suffix)"`，**以插值结尾，不以字面 ` KB`/` MB`/` GB` 结尾**，落不进 R2 的判据。S3 的对应实现是每个分支各自写死单位（`"… GB"`、`"… MB"`），所以它的豁免规则成立。卡内 R2 的判据是按 S3 的形状写的，与 IC-099b 的实际形状不匹配——**这是卡内两点之间的不相容，不是实现出错**。

**处置**：取「行为零变化的最小改法」，把私有助手的返回类型由 `String` 改为 `Int64`，单位改在各分支的返回字面量里写死：

```diff
         if byteCount >= bytesPerGigabyte {
-            return truncatedTenths(byteCount, unit: bytesPerGigabyte, suffix: "GB")
+            let tenths = truncatedTenths(byteCount, unit: bytesPerGigabyte)
+            return "\(tenths / 10).\(tenths % 10) GB"
         }
         if byteCount >= bytesPerMegabyte {
-            return truncatedTenths(byteCount, unit: bytesPerMegabyte, suffix: "MB")
+            let tenths = truncatedTenths(byteCount, unit: bytesPerMegabyte)
+            return "\(tenths / 10).\(tenths % 10) MB"
         }
         return "\(byteCount / bytesPerKilobyte) KB"
     }

     private static func truncatedTenths(
         _ byteCount: Int64,
-        unit: Int64,
-        suffix: String
-    ) -> String {
-        let tenths = byteCount / (unit / 10)
-        return "\(tenths / 10).\(tenths % 10) \(suffix)"
+        unit: Int64
+    ) -> Int64 {
+        byteCount / (unit / 10)
     }
```

**为什么这是最小且安全的**：

1. **算术逐字节相同**——`byteCount / (unit / 10)` 与拆十位个位的两步除法一字未改，只是搬了位置。
2. **公开签名 `string(forByteCount:)` 未变**，三档口径与阈值未变。
3. **由既有断言背书**：IC-099b P1 的八个卡内用例与六个边界用例（`999_999`、`1_000_000`、`1_099_999`、`999_999_999`、`1_000_000_000`、`1_099_999_999`）**一字未改**，CI #171 三项 P1 测试全部 passed。
4. **形状与 S3 对齐**——这正是卡内 R2「与 S3 同类的逐行规格锁定豁免」的前提。

**闸门 C 核对**：闸门 C 禁的是「改产品行为」，本改动行为零变化，故未触发。但它确实偏离了 R3 字面的「逻辑零改动」，因此在此显式登记，请技术负责人确认。

**另一处必要偏离**：类顶部的「放置说明」段（7 行注释）原文声明本类型**临时**置于诊断区、待技术负责人在「加豁免」与「入目录」之间定一个。本卡已定案（走豁免），该段若原样保留就是一条与事实相反、且会误导后续卡的说明。故改写为 IC-101 的结论，并补一句约束：**三处返回字面量必须以字面单位结尾，单位不得再抽成插值参数**（否则会被判残留）。其余注释、三档口径描述、`truncatedTenths` 的文档注释一字未动。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G221** Q1/Q2 满足；`ci.yml` 与扫描器改动逐行列入报告且不越两点 | 满足① | 两处 `git diff` 全文见上；`ci.yml` 1 增 1 删、扫描器 10 增 0 删 |
| **G222** CI success、真实退出码 0、XCTest **508/0**、IPA 重下一致、本地三项门禁 0 | 满足① | 见「CI 与本地门禁」 |

### Q1：既有断言原样通过

CI #171 里 IC-099b 的 **11 项断言全部 passed、0 失败**，测试文件一字未改（`git diff 251a9a8..HEAD -- PhotoCleanupMVETests/` **无输出**）：

| 组 | 测试函数 | 结果 |
|---|---|---|
| P1 | `testIC099bP1SingleAssetVolumeUsesKilobyteMegabyteGigabyteTiers` | passed |
| P1 | `testIC099bP1TierBoundariesTruncateInsteadOfRounding` | passed |
| P1 | `testIC099bP1SingleAssetTierDoesNotChangeAggregateTier` | passed |
| P2 | `testIC099bP2ProbeRowRendersNineColumnsInOrder` | passed |
| P2 | `testIC099bP2ProbeRowRendersFailuresAndNilColumns` | passed |
| P2 | `testIC099bP2ProbeFailureReasonsAreCompleteAndDistinct` | passed |
| P2 | `testIC099bP2ProbeSummaryCountsSuccessKindsAndDeltas` | passed |
| P2 | `testIC099bP2ProbeHeaderDeclaresColumnsAndLimitNote` | passed |
| P3 | `testIC099bP3ProbeIsInertUntilExplicitlyRun` | passed |
| P3 | `testIC099bP3ProbeRunMeasuresEachAssetOnceAndBuildsReport` | passed |
| P3 | `testIC099bP3ProbeStopsAtAssetLimitAndNotesTotal` | passed |

探针（R2 消费方）的代码与断言均未触碰，行为不变。

### Q2：扫描器退出码 0 与负例自测

**正例**：本地 `scan-hardcoded-user-visible-strings.ps1` 退出码 **0**，`S2AssetVolumeFormatter.swift` 的三条字面量全部进入「规格锁定格式豁免」清单，与 S3 的两条并列：

```
- PhotoCleanupMVE/Core/S3StateMachine.swift:33 [十进制 MB/GB 向下截断由规格锁定，本卡禁止本地化改造] \(tenthsOfGigabyte / 10).\(tenthsOfGigabyte % 10) GB
- PhotoCleanupMVE/Core/S3StateMachine.swift:36 [十进制 MB/GB 向下截断由规格锁定，本卡禁止本地化改造] \(byteCount / bytesPerMegabyte) MB
- PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift:30 [S2 单张 KB/MB/GB 向下截断由规格锁定，禁止本地化改造] \(tenths / 10).\(tenths % 10) GB
- PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift:34 [S2 单张 KB/MB/GB 向下截断由规格锁定，禁止本地化改造] \(tenths / 10).\(tenths % 10) MB
- PhotoCleanupMVE/Features/S2/S2AssetVolumeFormatter.swift:36 [S2 单张 KB/MB/GB 向下截断由规格锁定，禁止本地化改造] \(byteCount / bytesPerKilobyte) KB
```

**负例自测（证明豁免按路径生效而非全局放行）**：

1. 把 `S2AssetVolumeFormatter.swift` **原样复制**为同目录下的 `ZZNegativeProbeTemp.swift`（内容逐字节相同，只有文件名不同）。
2. 跑扫描器：退出码 **1**，三条字面量全部被判残留：

```
- PhotoCleanupMVE/Features/S2/ZZNegativeProbeTemp.swift:30 [用户消息或展示 helper 直接返回字符串] \(tenths / 10).\(tenths % 10) GB
- PhotoCleanupMVE/Features/S2/ZZNegativeProbeTemp.swift:34 [用户消息或展示 helper 直接返回字符串] \(tenths / 10).\(tenths % 10) MB
- PhotoCleanupMVE/Features/S2/ZZNegativeProbeTemp.swift:36 [用户消息或展示 helper 直接返回字符串] \(byteCount / bytesPerKilobyte) KB
```

3. 删除临时文件，`git status --porcelain` 复核**无该文件残留**，未产生任何仓库改动（未 `git add`、未提交）。

**结论**：豁免绑定的是**精确路径**，同目录、同内容、仅文件名不同即不放行——不是目录级、更不是全局放行。

### CI 与本地门禁

| 项 | 值 |
|---|---|
| 工作流 | `iOS 构建与自验`，run **#171**（id 33063362137） |
| 被测提交 | `c7547072edaa3ac5c607e0780be2ea5ccd095780` |
| 结论 | **success**，9 步全 success |
| XCTest | **Executed 508 tests, with 0 failures (0 unexpected)** in 42.660 (61.564) seconds |
| 计数 | **508**，与 IC-099b 的 508 **相同**——R3 是纯移动、R1/R2 不涉测试，符合 G222「计数不变」 |
| 真实退出码 | **0**（`set -o pipefail` + `exit "$test_status"`，步骤 6 conclusion = success） |
| IPA 字节数 | **823371** |
| IPA SHA-256 | `88ecadac55b5c69bb523e98583b9a4cfa2045355620c42d3c842ad7e8455582a` |
| 本地重下复核 | `gh run download` 取 `PhotoCleanupMVE-unsigned-c7547072edaa`（Artifact ID 9642772682），本地 `stat` = **823371**、`sha256sum` = `88ecadac…582a`，**与 CI 报告值逐字符一致** ✅ |
| `Scripts/selfcheck.ps1` | 退出码 **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 退出码 **0** |
| `git diff --check` | 退出码 **0** |
| CI 使用次数 | **1 / 2** |

**IPA 字节数与 #170 相同（均 823371）**，SHA 不同——与 IC-097 报告登记的现象同源（IPA 归档非确定性构建），字节数一致是「本卡行为零变化」的旁证。

### 闸门核对

| 闸门 | 触发 | 说明 |
|---|---|---|
| **A** R1 须改判定语义任何一行 | 否 | 只改 grep 模式一行，判定要素逐条核对未动（见 R1 表） |
| **B** 任一既有门禁失败 | 否 | 508/0 全过；本地三项门禁 0。**过程中扫描器曾短暂报 1**，那是移动后、对齐前的中间态，已在「与任务卡的偏离」如实登记，最终态为 0 |
| **C** 新增标定参数、改出厂值或 `schemaVersion`；改产品行为 | 否 | `S2CalibrationConfiguration` 未加字段、出厂值未改、`schemaVersion` 仍为 **4**；R3 行为零变化 |

## 人工判定项

**无。** 基础设施卡，不需要真机，不产出需要人工判定的行为变化。

## 真机未覆盖项清单

1. **R1 的 grep 扩展未经真实命中验证**（见 R1 节末）——待下一次真实产品编译错误自证。本卡不允许为验证故意推错误提交。
2. **R2 的豁免只在本机 PowerShell 上验证**；CI 里跑的是同一个脚本（步骤 5「扫描用户可见硬编码字符串」success），可视为同源验证，但 CI 上没有单独的负例。
3. **`S2AssetVolumeFormatter` 目前仍无产品消费方**——它只被 IC-099b 的探针断言覆盖，尚未接到顶部信息区。接上之后的真机显示效果属 IC-099 阶段二的 H42。

## 发现但未处理的问题（按纪律只报告不修）

1. **诊断区豁免仍然偏宽**：`$inGeometryDiagnosticProtocol` 从 `S2NativePhotoPager.swift` 里 `final class S2GeometryDiagnosticsRun` 那一行置真后**不再复位**，该文件其后全部内容（约 1500 行）的中文字面量与 `return "字面量"` 一律不查。卡内明写「收窄挂账另卡，本卡不做」，故未动。**本卡把 `S2AssetVolumeFormatter` 移出该区，等于把一个此前被这条宽规则遮住的类型暴露到了正常判定下**——这正说明该区确实遮了东西。
2. **两条规格锁定豁免的判据是硬编码路径**，每新增一个规格锁定数字格式都要改脚本。若这类格式还会增加（例如 S4/S5 的时长或速率格式），值得改成「按目录 + 文件名后缀约定」或在源码里用可识别标记（如统一的 `// spec-locked-format` 注释）来判定。属脚本设计，本卡只加了卡内指定的一条。
3. **`Scripts/` 与 `ci.yml` 现在有了修改先例**。本卡是历史上首次授权动这两个文件，改动范围严格限于卡内两点；建议后续在 CLAUDE.md 第三节的禁止项里补一句「除任务卡显式逐点授权外仍然禁止」，以免先例被泛化。属 CLAUDE.md，本卡范围外，未改。
4. **`project.pbxproj` 的对象 id 是人工递增的**（`1000…` / `2000…` / `3000…` 三段各自顺序编号）。本卡按最大值 +1 取号并断言了唯一性，但这套约定没有写进任何文档，下一个加文件的人得自己重新推断一遍。值得在 CLAUDE.md 或 `Scripts/` 里落一条说明。

## 完成后动作

**完成即停。** 未合并主干，未动冻结三链。IC-099 阶段二将在本卡之上继续。
