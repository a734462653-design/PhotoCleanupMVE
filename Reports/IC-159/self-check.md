# IC-159 自验报告

## 一、结论（先行）

1. **子项 T 达成，CI 一次绿。** 分支运行 **#318**（id `35309928089`，attempt 1），被测提交 `b7b1b738224f54d563e09bb352743257f2741a1e`，十二步全 success，XCTest **852 项 0 失败**（单次 launch），真实退出码 **0**。
2. **裁定 一（本卡命题）在 CI 上成立①**：`testIC063…` 块内唯一一条 `[error] building pipeline path_exterior-jba6la8feba4 took 0.832387 seconds`（设备 `os_log` 时刻 `05:19:23.560466`）落在 `IC063_WARMUP_GATE_END`（`05:19:25.318`）**之前**——Metal 管线编译发生在**预热导出**里；计时导出全程无 build 行。
3. `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` **passed (6.920 seconds)**；计时导出报告 `采样总数：15`、`中间帧门禁：通过`、进入中间帧 3 帧、退出中间帧 5 帧、**零**软目标未达行。
4. **预热里确实"吃掉"了一帧**②：预热报告 `采样总数：14`、`中间帧门禁：通过`、带一行 `中间帧软目标未达：…软目标 3 帧（实际命中 2 帧…）`。这正是四次「零相关改动单独红」的机制在预热段显影——本卡把它挪出了计时段。
5. 产品零改动：`PhotoCleanupMVE/` 全部 **49** 个文件两侧 SHA-256 相同（聚合 `27348CE8…6523`），`.github/`／`Scripts/`／`project.pbxproj` 两侧同一 git 对象；`S2CalibrationHarnessTests.swift` diff 恰 **+28／−0**，其余测试文件未动。`schemaVersion` 仍 **7**。
6. **人工判定项：无**（纯测试侧改动）。
7. G902、G903 满足；G904 见第十一节（合并后运行）。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260917-159-testic063-pipeline-warmup.md` |
| 基线 `main` | `15bf53f042a30a1ace0dfea2cf289973f019c67d` |
| 继承（IC-157 合并提交） | `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b`，`git merge-base --is-ancestor ab3eed1 main` 退出码 **0** |
| 远端核对 | `git ls-remote origin refs/heads/main` → `15bf53f042a30a1ace0dfea2cf289973f019c67d`，与本地一致（IC-158 未合并，符合卡内预期） |
| 分支 | `feature/ic-159-testic063-pipeline-warmup`，自 `main` 切出 |
| 子项 T 提交 | `b7b1b738224f54d563e09bb352743257f2741a1e` |
| 范围边界 | 白名单只有 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` 的 T2 插入块与 `Reports/IC-159/`；产品目录、`project.pbxproj`、`.github/`、`Scripts/`、其余测试文件、`feature/ic-158-*`、SPEC 与 Decision_log 全未触碰 |

### 开工四步（纪律 8 + 卡首口径）

| 步 | 命令 | 结果 |
|---|---|---|
| 1 | `git status --porcelain` | **空**（无输出，退出码 0） |
| 2 | `git merge-base --is-ancestor ab3eed1 main` | 退出码 **0** |
| 3 | `git ls-remote origin refs/heads/main` | `15bf53f…`，与本地 `main` 相同 |
| 4 | `git switch -c feature/ic-159-testic063-pipeline-warmup main` | **先切分支再改文件**（开工时 HEAD 在 `feature/ic-158-diagnostic-progress-clamp` tip `5cb6733`，未在其上做任何改动；IC-158 漏第四步的问题未重演） |

## 三、逐条验收门禁

| 闸门 | 要求 | 结果 |
|---|---|---|
| **G902** | diff 只有 `S2CalibrationHarnessTests.swift`（+28／−0）与两份报告；产品目录两侧 SHA-256 相同；`project.pbxproj`、`.github/`、`Scripts/` 同一 blob／tree | **满足**，见第五节 |
| **G903** | G902 + 绿（852／0、退出码 0、执行摘要 notice、目的地实证行、IPA 校验、分段耗时 notice）+ `testIC063…` passed 并贴耗时 + 裁定 三五项材料 + `IC152DiagnosticPathTests` 6／6 + 函数名含 `DoubleTap` 的用例全 passed + 工作树净 + `main` 未被他人推进 | **满足**，见第六～九节 |
| **G904** | 合并后 `main` 运行编号、结果、分段耗时 notice、`testIC063…` 用时与裁定 三五项材料（第二份） | 见第十一节 |

本卡**不新增用例**，故无「断言 → 测试函数名」新条目；受影响的既有测试函数：

| 测试函数 | 结果（#318） |
|---|---|
| `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` | **passed (6.920 seconds)** |
| `IC152DiagnosticPathTests` 六个（`testIC152A_DismantleMidTransitionPublishesNothing`、`testIC152A_NormalCompletionStillReportsViewport`、`testIC152A_ViewportReportEntryUnchanged`、`testIC152B_CadenceDescriptionCarriesProgressSamples`、`testIC152B_ErrorWritePointsUnchanged`、`testIC152B_GateFloorIsTwoAndTargetsAreSoft`） | **6／6 passed**（0.379／1.120／0.046／0.008／0.084／0.003 s） |
| 函数名含 `DoubleTap` 的用例 | **33 个全部 passed，0 失败** |

## 四、本机预验证（三项，卡内「本机预验证」）

### ① Python 切函数体核 needle 与逐字比对

作用域限定到 `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 函数体（改后 `:4089-4220`，以函数首行与首个 `    }` 定界）：

| needle | 期望 | 实测 |
|---|---|---|
| `diagnostics.export()` | 2（挂载循环 1 + 预热块 1） | **2** |
| `IC063_WARMUP_GATE_BEGIN` | 1 | **1** |
| `IC063_WARMUP_GATE_END` | 1 | **1** |
| `Date(timeIntervalSinceNow: 10)` | 1 | **1** |
| `Date(timeIntervalSinceNow: 60)` | 1 | **1** |
| `XCTFail(` | 1 | **1** |
| `IC063_DIAGNOSTICS_SAMPLE_BEGIN` | 1 | **1** |

逐字比对（对 `git show 15bf53f:PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`）：

- 改后 `:4089-4138` ≡ 基线 `:4089-4138`：**True**
- 改后 `:4167-4220` ≡ 基线 `:4139-4192`：**True**
- 从改后文件删去新增的 `:4139-4166` 这 28 行 ⟹ 逐字重现基线全文件（12 048 行）：**True**
- 插入块与任务卡裁定 二的 ```swift 代码块**逐字节相同**：**IDENTICAL**（29 行切片含末尾空行，28 行实体）

### ② diff 体量

`git diff --numstat 15bf53f b7b1b73` → `28	0	PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`，**唯一一行**；`git diff --check` 退出码 **0**。

### ③ 本地门禁

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1`（`powershell.exe -NoProfile -ExecutionPolicy Bypass -File`） | **0**（结构门禁通过；字符串／括号结构自对账三条 OK；needle 交叉门禁 OK） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（"扫描通过：用户可见硬编码残留为 0"）——新增汉字全在测试目录，扫描器只扫 `PhotoCleanupMVE/{App,Core,Services,Features}` |
| `git diff --check` | **0** |

## 五、G902 证据

`git diff --name-only 15bf53f b7b1b73` → 仅 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`。

| 对象 | `15bf53f` | `b7b1b73` |
|---|---|---|
| `PhotoCleanupMVE/` tree | `87aec05f066b973f9224282a8edb1795fb09c454` | 同 |
| `.github/` tree | `74088388c62a10eb277921ecf74e766a2d407e80` | 同 |
| `Scripts/` tree | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同 |
| `project.pbxproj` blob | `edda3f5252c6d29df6a0b892db82fe9788c36d46` | 同 |

产品目录聚合 SHA-256（逐 blob 取内容 SHA-256、按路径升序拼行表再整体取 SHA-256）：

| 范围 | 文件数 | 两侧聚合 SHA-256 |
|---|---|---|
| `PhotoCleanupMVE/` 全部 | 49 | `27348CE8BEFCBB9FFB9AD3211CD49626DA065E2E7C5993A725500556F6D26523` |
| `App/` | 2 | `AFC4F94933B1CC06FCE72BEF598EF9F3FE51DB3818F63B6E810583E70EE69F84` |
| `Core/` | 10 | `7405D80AB45961B1B1FB004B27145D364E398910EBFB54489461F7A57FDC42E6` |
| `Services/` | 11 | `6F113A974FAF25FA012B565772536C1BE631AB750B9A59654383FAAD24854892` |
| `Features/` | 23 | `E5DED6774DADBA903A318E8AF1C86BA5F4C6A0C5DC9B89AFFE4F441BC3142026` |
| `Localizable.xcstrings`（单文件） | 1 | `C58D4323265CD84820ED36EDB92FD7DFE6169140962CAEDF91B6469DA0C50406` |
| `Info.plist`（单文件） | 1 | `E7D657EB1BEB4D22A6F11DA5A8FA775D075DA6E8B98E5A1A9CFBB121445A65F0` |

脚本逐文件比对结论：`per-file identical: True`（49／49）。

## 六、CI 运行 #318（分支运行）

| 项 | 值 |
|---|---|
| 运行编号 | **#318** |
| run id / attempt | `35309928089` / **1**（无重跑） |
| 被测提交 | `b7b1b738224f54d563e09bb352743257f2741a1e` |
| 分支 | `feature/ic-159-testic063-pipeline-warmup` |
| 结论 | `completed` / **`success`**；十二步全 `success` |
| 起止 | `2026-09-18T05:12:58Z` → `05:23:11Z`（作业 `05:13:07Z`→`05:23:10Z`，约 10 分 03 秒；作业时限 30 分钟、步骤级 25 分钟均未逼近） |
| XCTest 项数 | **852 项，0 失败**（`::notice XCTest 执行摘要::Executed 852 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 852 tests / 0 failures`） |
| 唯一用例身份计数（陷阱 22／25 口径） | 下载整包日志，取步骤级成员 `9_运行 XCTest.txt`、剔 `##[` 与 `[36;1m` 回显后：`Test Case '…' started` 唯一身份 **852**、带结果 **852**、`failed` **0**；与 notice 一致 |
| 真实退出码 | **0**。`ci.yml:296` `set -o pipefail`、`:302-304` 取 `test_status`、`:381-382` 哨兵（`Executed N tests` N>0）、`:385` `exit "$test_status"`；步骤「运行 XCTest」结论 `success` ⟹ `test_status = 0`；日志内 `** TEST SUCCEEDED **`，无 `Process completed with exit code`、无 `Restarting after`、无 `Fatal`、无 `error:` 行 |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（另有同 id 的 `arch:x86_64` 行） |
| 分段耗时 notice 原文 | `XCTest 分段耗时：模拟器启动 87 s；xcodebuild test 320 s；总 409 s` |
| IPA 校验 notice 原文 | `未签名 IPA 校验：文件=PhotoCleanupMVE-unsigned.ipa，字节数=1687402，SHA-256=6e50693f5734764b359300bec5180756cf45bf740712d5547179da2e2964c5ad` |
| artifact | `PhotoCleanupMVE-unsigned-b7b1b738224f`，id `10532883541`，容器 1 687 572 字节 |
| CI 次数 | **1 次**（预算 3 次，用 1 次；无修复跑） |

## 七、裁定 三：五项材料（分支运行 #318）

口径：整包日志 zip → 步骤级成员 `测试与打包（XCTest 与未签名构建）/9_运行 XCTest.txt`，剔 `##[`／`[36;1m` 两类回显行（陷阱 25），按 `Test Case '…' started` 起、`passed` 止切出 `testIC063…` 块（430 行）。

### ① `IC063_WARMUP_GATE_BEGIN…END` 块原文（预热报告的门禁头）

```
2026-09-18T05:19:25.2433680Z IC063_WARMUP_GATE_BEGIN
2026-09-18T05:19:25.2617540Z 采样总数：14
2026-09-18T05:19:25.2675750Z 中间帧门禁：通过
2026-09-18T05:19:25.3183780Z 中间帧软目标未达：双击进入 Nx：动画中间帧 软目标 3 帧（实际命中 2 帧；进度回调 9 次，其中进度<1 的 7 次≈CADisplayLink 回调次数；首次进度回调相对过渡起始延迟 16.2 ms；诊断时长 1000 ms；进度样本：0.43,0.47,0.50,0.53,0.56,0.62）
2026-09-18T05:19:25.3184370Z IC063_WARMUP_GATE_END
```

预热报告 `采样总数：14`（比计时导出少 1）、门禁**通过**（硬下限每段 ≥2 满足）、进入段软目标 3 帧只命中 2 帧——**编译确实吃掉了预热段的一帧**②。

### ② `IC063_DIAGNOSTICS_SAMPLE_BEGIN` 之后的两行（计时导出）

```
2026-09-18T05:19:28.4010140Z IC063_DIAGNOSTICS_SAMPLE_BEGIN
2026-09-18T05:19:28.4150770Z # S2 几何诊断
2026-09-18T05:19:28.5013640Z 采样总数：15
2026-09-18T05:19:28.5391090Z 中间帧门禁：通过
```

计时报告内 `## 双击进入 Nx：动画中间帧 #` **3** 处、`## 双击退出 Nx：动画中间帧 #` **5** 处、`中间帧软目标未达：` **0** 处——进入 3／退出 5 全满，软目标亦达标。

### ③ `Invalidating cache` 行数

块内 **2** 条（与卡内七次运行的形态一致），各自前一行为 `fopen failed for data file: errno = 2`：

```
2026-09-18T05:19:23.0225140Z 2026-09-18 05:19:22.727233+0000 PhotoCleanupMVE[20623:64101] fopen failed for data file: errno = 2 (No such file or directory)
2026-09-18T05:19:23.0250200Z 2026-09-18 05:19:22.727463+0000 PhotoCleanupMVE[20623:64101] Errors found! Invalidating cache...
2026-09-18T05:19:23.5745800Z 2026-09-18 05:19:23.518739+0000 PhotoCleanupMVE[20623:64101] fopen failed for data file: errno = 2 (No such file or directory)
2026-09-18T05:19:23.6636540Z 2026-09-18 05:19:23.519124+0000 PhotoCleanupMVE[20623:64101] Errors found! Invalidating cache...
```

全步骤日志内 `Invalidating cache` 共 **2** 条、`building pipeline` 共 **1** 条，**全部落在 `testIC063…` 块内**，其余 851 个用例块零命中。

### ④ `building pipeline` 行与它相对 `IC063_WARMUP_GATE_END` 的位置

```
2026-09-18T05:19:23.6704610Z 2026-09-18 05:19:23.560466+0000 PhotoCleanupMVE[20623:64101] [error] building pipeline path_exterior-jba6la8feba4 took 0.832387 seconds
```

**落在 `IC063_WARMUP_GATE_END` 之前**（块内序号：build 行 idx 6，`IC063_WARMUP_GATE_BEGIN` idx 7、`END` idx 11）。两套时间戳同向：GitHub 写入时刻 `05:19:23.670` < `05:19:25.318`；设备 `os_log` 时刻 `05:19:23.560` < `IC063_WARMUP_GATE_BEGIN` 的写入时刻。**⟹ 编译落在预热里，本卡命题成立①。** 计时导出段（`IC063_WARMUP_GATE_END` 之后到用例结束）**零** build 行、零 invalidation 行。

### ⑤ 用例耗时

```
2026-09-18T05:19:21.5615060Z Test Case '…testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages]' started.
2026-09-18T05:19:28.9279120Z Test Case '…testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages]' passed (6.920 seconds).
```

**6.920 s**（绿基线 #315 4.19 s、#316 4.15 s；本卡多跑一次完整导出 + 0.832 s 编译，增量约 2.8 s）。段内时序：起始 `21.56` → 编译 `23.56`（设备时刻）→ 预热门禁打印 `25.24～25.32` → 计时导出报告 `28.40` → passed `28.93`。10 s 计时期限与 60 s 预热期限均未逼近（预热段约 3.7 s，计时段约 3.1 s）。

## 八、根因假设的确认／推翻（纪律 3）

卡内裁定 一把 `testIC063` 的红归因为「模拟器着色器缓存失效后、双击过渡首次渲染触发的 Metal 管线同步编译」（①），修法为测试侧预热。

**本次实测确认该归因，未发现矛盾点**：

1. `#318` 同样在 `testIC063…` 块内出现两条 `Invalidating cache` + 一条 `building pipeline path_exterior-jba6la8feba4`（0.832 s），管线名与卡内七次运行完全一致①。
2. 编译落在**预热导出**内，计时导出未再编译——「同一进程内同类型层第二次渲染不再编译」这条卡内②在本次运行里得到直接支持（计时段零 build 行）①。
3. 预热段因编译丢了一帧（进入中间帧 2／软目标 3），计时段满帧（3／5）——**编译与丢帧的因果在同一次运行内前后对照显影**②，与「四次零相关改动单独红」的机制吻合。
4. 未出现卡内担心的三条前置态分支（`预热导出未在 60 s 内完成`／`预热导出没有产出报告`／`计时导出没有起飞` 在日志内各 **0** 次）。

**未上升的部分**（保持②／③）：
- 「哪一层、哪一帧触发编译」本卡不核（卡内明示标②），本次亦未核。
- 「真机上着色器缓存跨启动持久，预热不会长期存在」属③推断，本卡不设人工判定项。
- 单次运行只能证明这一次；**编译时长不可控**（历史 0.57～30.8 s）。本次 0.832 s 落在预热的 60 s 期限内绰绰有余，但若某次编译再现 30 s 量级，预热期限 60 s 仍可容纳（最坏估算见卡内「时限」行：挂载 ≤2 s + 预热 ≤60 s + 计时 ≤10 s ≈ 72 s）。

## 九、G903 前置核对

| 项 | 结果 |
|---|---|
| G902 | 满足（第五节） |
| 绿：852／0、真实退出码 0、执行摘要 notice | 满足（第六节） |
| 目的地实证行 `OS:26.2, name:iPhone 16` | 满足（第六节） |
| IPA 字节数与 SHA-256 | 满足（第六节；1 687 402 字节 / `6e50693f…c5ad`） |
| 分段耗时 notice | 满足（`模拟器启动 87 s；xcodebuild test 320 s；总 409 s`） |
| `testIC063…` passed + 用例耗时 | 满足（6.920 s） |
| 裁定 三五项材料 | 满足（第七节） |
| `IC152DiagnosticPathTests` 6／6 | 满足（第三节表） |
| 函数名含 `DoubleTap` 的用例全 passed | 满足（33 个，0 失败） |
| 工作树净 | `git status --porcelain` 在提交与推送后为空（报告写入前后各核一次） |
| `main` 未被他人推进 | `git ls-remote origin refs/heads/main` 仍 `15bf53f…`（合并前再核一次，见第十一节） |

## 十、发现但未处理的问题（按纪律只报告不修）

1. **预热报告的软目标未达行会长期出现在日志里**②。编译在预热段发生时，进入中间帧命中 2／软目标 3，`IC063_WARMUP_GATE` 块因此常带一行 `中间帧软目标未达：…`。这是**预期证据**不是缺陷（卡内裁定 二明示"对预热报告不做门禁断言"），但读日志的人可能误读为红。若日后想消除，需在预热块里再加一句说明性打印——本卡不改。
2. **用例耗时从 4.15 s 涨到 6.920 s**（+约 2.8 s，其中编译 0.832 s、第二次完整导出约 2 s）①。当前步骤总耗时 320 s、作业 10 分 03 秒，距 25／30 分钟时限很远；仅登记趋势。
3. **本方案不覆盖「同一进程内首次编译发生在计时段」的其它入口**③。本卡只预热双击过渡这一条渲染路径（经 `export()` 的进入＋退出两段）。若日后 `testIC063` 的计时段引入别的首次渲染层（例如新的连续圆角遮罩），仍可能再现同类停顿；判据仍是块内 `building pipeline` 行落在 `IC063_WARMUP_GATE_END` 之后。
4. **`S2CalibrationHarnessTests.swift` 已 12 076 行**②，`testIC063…` 单函数 132 行。不属本卡范围，登记备查。
5. IC-158 分支 `feature/ic-158-diagnostic-progress-clamp`（tip `5cb6733`）按卡内要求**保留不合并、不删除、未 cherry-pick**；开工时 HEAD 恰在该分支上，已先 `git switch -c` 切出本卡分支，未在其上留下任何改动①。

## 十一、合并与 G904

（本节在合并与合并后运行完成后，由同一张卡、同一链上的 docs 提交补记——纪律 7 允许的第二种形态：报告已随分支 docs 提交推送，CI 编号等推送后才产生的信息在同卡内追加。）

### 报告提交形态说明（纪律 7）

代码提交 `b7b1b73` 先行推送以触发 CI；两份报告作为**同一分支的一个 docs 提交**随后推送（`Reports/**` 与 `**.md` 在 `paths-ignore` 内，不触发 CI，属预期行为，见 CLAUDE.md 第五节）。未跨卡回填。

### 合并

待填：合并提交 SHA、父提交、推送结果。

### G904：合并后 `main` 运行

待填：运行编号、结论、项数与失败数、真实退出码、分段耗时 notice、IPA 校验、`testIC063…` 用时与裁定 三的五项材料（第二份）。

## 十二、40 位 SHA 核验（陷阱 15）

报告内每个 40 位 SHA 均来自实读命令输出（`git rev-parse`／`git ls-remote`／`git log`／`gh api` 的 `head_sha`），无短前缀补全。逐条 `git cat-file -e` 核验：

| SHA | 类型 | 命令 | 退出码 |
|---|---|---|---|
| `15bf53f042a30a1ace0dfea2cf289973f019c67d` | commit（基线 `main`） | `git cat-file -e <sha>^{commit}` | **0** |
| `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b` | commit（IC-157 合并） | `git cat-file -e <sha>^{commit}` | **0** |
| `b7b1b738224f54d563e09bb352743257f2741a1e` | commit（子项 T） | `git cat-file -e <sha>^{commit}` | **0** |
| `5cb67332437a446d98733ddc942e2905392d2891` | commit（IC-158 分支 tip，未动） | `git cat-file -e <sha>^{commit}` | **0** |
| `87aec05f066b973f9224282a8edb1795fb09c454` | tree（`PhotoCleanupMVE/`） | `git cat-file -e <sha>^{tree}` | **0** |
| `74088388c62a10eb277921ecf74e766a2d407e80` | tree（`.github/`） | `git cat-file -e <sha>^{tree}` | **0** |
| `514886dc0afc4083237c976c0f7be6ce597c50a8` | tree（`Scripts/`） | `git cat-file -e <sha>^{tree}` | **0** |
| `edda3f5252c6d29df6a0b892db82fe9788c36d46` | blob（`project.pbxproj`，`git cat-file -t` = `blob`） | `git cat-file -e <sha>` | **0** |

非 git 对象的 64 位十六进制串（`27348CE8…`、`6e50693f…` 等）是文件内容 SHA-256 与 IPA 校验值，不参与 `cat-file` 核验，各自来源已在对应节注明。
