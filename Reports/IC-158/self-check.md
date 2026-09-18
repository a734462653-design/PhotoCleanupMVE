# IC-158 自验报告

## 一、结论（先行）

- **停卡上报，未合并。** CI #317 一次红，其中 `testIC063…` 的红**正是卡内 G900 写明的（乙）形态**：`:4145 XCTAssertFalse(diagnostics.isExporting)` 判红、`report` 为空串、该用例耗时 **31.319 s**（绿基线 4.15／4.19 s）。按 G900「停下报告、不复跑凑绿」与纪律 3 执行，**不自行改 `:4139` 的 10 s 期限**，不再推 CI。分支 CI 预算 3 次**用 1 次**。
- **两个子项的代码已交付并推送**（未合并）：A `c3cc047`（步长上限：纯函数 + 三个状态量 + 一处夹紧 + 诊断入口传参）、B `96acc6c`（报告「步长上限触发」行 + `testIC063` 一条 `contains`）。
- **裁定 一的③前提被实测推翻（纪律 3）**：卡面「正常帧率下每回调墙钟增量远小于上限，**从不触发**」在本 runner 上不成立到足以吃掉导出期限的程度——夹紧后每段至少需要 `4(n+1)` 次回调（进入 ≥16、退出 ≥24），与墙钟无关；`testIC063` 因此在 10 s 内导不完。**详见第七节的归因与边界**（我只能给到③：报告没产出，夹紧触发次数与节奏行都随之丢失）。
- **卡面断言 3 的期望也被实测推翻**：`testIC158A_UnclampedPathStillJumpsToCompletionAfterAStall` 判红——停顿后**第一次**回调带的是**陈旧时间戳**（实测缓动值 0.0021310788393515707 ⟹ 线性 0.033333 ⟹ 时长 1.0 s 下 elapsed = 33.3 ms ≈ 60 fps 的两帧），跳到终点发生在**下一次**回调。卡面写的是「停顿之后收到的**第一个**进度值 == 1」。**按 G900 未改测试、未复跑**。
- **其余四条断言全部 `passed`**：断言 1（0.006 s）、断言 2（1.568 s）、断言 4（0.146 s）、断言 5（0.083 s）。断言 2 证明「带上限时确实分步走完、阈值 3 个全采到」。
- **G897／G898 满足；G899 部分满足；G900 不满足**（第九节）。零改动清单逐项实证、四段 awk 切块 diff 为空、IC-152 六个 needle 计数不变、`S2CalibrationHarnessTests.swift` diff 恰 +1／−0；但 G899 要求的「`testIC063…` 报告块含两行」拿不到——报告块印出来是空的。
- **另有一处执行端流程失误如实登记**（第 7.4 条）：A、B 两个提交**先落在本地 `main` 上**（开工时漏建分支），发现后把分支建在该提交上、把本地 `main` 退回 `15bf53f`；**两者都未推送过**，远端 `main` 全程是 `15bf53f`。
- **H79 两条原样保留给 Lynn**（第十一节）；本卡未产出可装的产物（打包与上传两步因红而 skipped）。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260917-158-diagnostic-progress-clamp.md` |
| 基线 `main` | `15bf53f042a30a1ace0dfea2cf289973f019c67d` |
| 开工核对 1 | `git status --porcelain` **空**（纪律 8） |
| 开工核对 2 | `git merge-base --is-ancestor ab3eed1 main` 退出码 **0** ✔ |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `15bf53f042a30a1ace0dfea2cf289973f019c67d` = 本地 ✔ |
| 分支 | `feature/ic-158-diagnostic-progress-clamp`（见第 7.4 条的建立方式） |
| 分支 tip（代码） | `96acc6c47890ae77211a6944af80ae51670a07cf` |
| 现状基数 | 852 项（CI #316）→ 本卡 **857** 项（#317 实测唯一 Test Case 身份 857） |
| 常量 | `schemaVersion` 7、`cacheSchemaVersion` 1、`hardFloor` 2、`secondsPerThreshold` 0.2、`S0HomeMetrics` 52、`S0CategoryPageMetrics` 42，均未动 |

**卡内事实表复核（惯例 13／37）**：卡内「事实基础」「定位坐标」两表在 `15bf53f` 上实读，**逐项一致**——

- 缓动与时长：`S2DoubleTapTransitionTiming` `:968-1043`（`durationSeconds = 0.3` `:970`、`easedProgress` `:978-984`、系数与求解 `:986-1042`）；`S2DiagnosticDoubleTapTiming` `:1392-1403`（`secondsPerThreshold` `:1396`、`durationSeconds` `:1400-1402`）。
- 页控制器：私有状态量 `:1531-1533`；起飞 `:1869-1876`、清零段 `:1950`／`:1955`、时长 `:1962-1965`、早收口 `:2000-2005`、显示链接 `:2006-2012`；`applyDoubleTapTransitionProgress` `:2188-2200`；`advanceDoubleTapTransition` `:2202-2225`（线性进度 `:2216-2218`、收口 `:2222-2224`）。
- 调用点：`page.startDoubleTapTransition(` 恰 **3**（`:3428`／`:3468`／`:3595`，卡写 `:3393`／`:3429`／`:3556` 指的是 `return page.` 那一行所在语句的起始，逐条对读一致）；测试侧 8 处。
- 诊断运行类：`S2GeometryDiagnosticsRun` `:4288`、`startDoubleTap` `:4454-4550`（`.progressed` 三条件 `:4494-4496`、`removeFirst` `:4500`、`.completed` `:4502-4523`）、`doubleTapCadenceDescription` `:4557-4575`、`capture` 的 `errors.append` `:4582`、`makeReport()` `:4709-4720`；判据枚举 `:4941-5028`（`hardFloor` `:4943`、`gateLines` `:5017-5027`）。
- 测试：`testIC063…` `:4089-4192`（期限 `:4139-4142`、`:4146`、两段样本标题 `:4154-4161`、打印 `:4191`）；`IC152DiagnosticPathTests` 的夹具与断言 3／6 行号逐条对上。
- 数值：`errors.append(` 2、IC-152 六个 needle 各按卡面计数、pbxproj 最大 id `…60`／`…5D`、冻结三链与四条探针远端 tip 与卡一致。

**范围边界**：diff 限于白名单 4 个路径（`change-list.md` 第二节）；「不得触碰」清单两侧 SHA-256 相同（第九节 G897）。

---

## 三、实现要点

- **裁定 一**：`S2DiagnosticDoubleTapTiming.maximumLinearProgressStep(minimumMiddleFrames:) = 1 / (4 × (max(1, n) + 1))`；`advanceDoubleTapTransition` 在墙钟线性进度之后、`easedProgress` 之前夹紧到 `上次 + 上限`，并记一次触发；`>= 1` 收口判断用夹紧后的值。
- **裁定 二**：新参 `maximumLinearProgressStep: CGFloat? = nil` 只由 `beginDiagnosticDoubleTap` 传；三个状态量在起飞清零段与进度样本同处清零；取消路径不加行。
- **裁定 三**：`S2DiagnosticMiddleFrameGate.clampLine(entryClampedCallbacks:exitClampedCallbacks:)`；运行类在每段 `.completed` 经唯一读点取值；`makeReport()` 在门禁几行之后、第一个样本之前追加。
- **裁定 四**：`testIC063…` 只加一条 `contains`；IC-152 六个 needle 与四个既有判据函数一字不动。

---

## 四、CI 与项数对账

### 4.1 #317 的完整事实

| 项 | 值 |
|---|---|
| run id ／编号 | `35305148096` ／ **#317**，attempt 1，事件 `push`，分支 `feature/ic-158-diagnostic-progress-clamp` |
| 被测提交 | `96acc6c47890ae77211a6944af80ae51670a07cf` |
| check-run id | `105475706910`（本次运行现取） |
| 结论 | **failure**。作业 03:58:03Z → 04:09:04Z（11 分 1 秒，作业级时限 30 分钟之内） |
| 步骤 | 1～8 success；「运行 XCTest」（步骤 9）03:58:44Z → 04:08:47Z **failure**；「构建未签名应用」「上传可下载的未签名 IPA」**skipped**（zip 内无 `10_`／`11_` 步骤日志），故**本卡无 IPA、无 artifact** |
| 执行摘要 notice | `Executed 858 tests, 2 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 857 tests / 25 failures`（去重口径 858 与唯一身份 857 的差见 4.3） |
| 分段耗时 notice | `模拟器启动 74 s；xcodebuild test 526 s；总 600 s` |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 唯一 Test Case 身份 | **857**：passed 855、failed **2** |
| `Test Suite 'All tests' started` | 1 次；`Restarting after unexpected exit` 0 次（无宿主重启） |
| 失败用例 | `S2CalibrationHarnessTests.testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`（31.319 s）、`IC158DiagnosticProgressClampTests.testIC158A_UnclampedPathStillJumpsToCompletionAfterAStall`（1.326 s） |
| 注解 | failure 10 条（GitHub 每步上限 10，实际失败断言 25 条，全量取自整包日志）+ notice 2 条 |

### 4.2 两处红的原文

**（甲）`testIC063…`——G900 的（乙）形态**：23 条断言失败，行号 `:4145`、`:4146`、`:4147`、`:4148`、`:4149`、`:4150`、`:4151`、`:4155`、`:4159`、`:4163`～`:4167`、`:4172`、`:4175`～`:4178`、`:4181`、`:4184`、`:4187`、`:4188`。首条即 `:4145 XCTAssertFalse(diagnostics.isExporting)`，其后所有 `report.contains(...)` 连带判红——**报告是空串**：`:4191` 打印出来的块逐字为

```
IC063_DIAGNOSTICS_SAMPLE_BEGIN

IC063_DIAGNOSTICS_SAMPLE_END
```

故 G899 要求的 `中间帧门禁：通过` 与 `步长上限触发：` 两行**在本次运行里不存在**（日志中这两个串出现 0 次）。`:4147` 正是本卡 B4 新加的那条，它与既有的 `:4146` 同因空报告判红，**不是文字对不上**。

**（乙）断言 3**：

- `:251 XCTAssertEqualWithAccuracy failed: ("0.0021310788393515707") is not equal to ("1.0") +/- ("1e-09") - 停顿后的第一次回调没有一步跳到终点——停顿复现不成立`
- `:257 XCTAssertEqual failed: ("1") is not equal to ("0") - 停顿后不该再有进度<1 的回调`

同一用例内 `completedCount == 1`、`doubleTapClampedCallbackCount == 0`、`isDoubleTapTransitionActive == false` 三条**都通过**。

### 4.3 项数对账

| 来源 | 项数 |
|---|---|
| `main` 基数（CI #316） | 852 |
| 本卡新增（`IC158DiagnosticProgressClampTests`，5 个 `func test`） | +5 |
| 期望 | **857** |
| #317 唯一 Test Case 身份 | **857**（855 passed ／ 2 failed） |

执行摘要 notice 报 858，比唯一身份多 1：该 notice 的「去重」统计与整包日志的唯一 `Test Case` 身份在有失败用例时口径不同（失败用例的 `failed` 行与其重试/汇总行），项数以唯一身份 **857** 为准（陷阱 22 与记忆 `ci-test-count-chunked-runs` 的同一读法）。

---

## 五、逐条验收门禁与测试函数名

| 断言 | 子项 | 测试函数 | #317 | 钉住的结果 |
|---|---|---|---|---|
| 1 | A | `testIC158A_StepIsQuarterSpacingAndEasedIncrementStaysUnderOneSpacing` | **passed**（0.006 s） | `maximumLinearProgressStep(3) == 1/16`、`(5) == 1/24`、`(0) == 1/8`（`accuracy 1e-9`）；`durationSeconds(3) == 1.0`、`(5) == 1.4`（不动的正对照）；n ∈ {3,5} 在 x = 0…0.999（步 0.001）上 `easedProgress(min(1, x+step)) − easedProgress(x)` 逐点非负、最大值 < spacing 且 < spacing/2 |
| 2 | A | `testIC158A_ClampedTransitionWalksThroughAMainThreadStall` | **passed**（1.568 s） | 真页真显示链接、硬前置（样本 ≥ 1）后 `Thread.sleep(1.2)`：`.completed` 恰 1；`doubleTapClampedCallbackCount ≥ 1`；停顿后进度<1 的回调 ≥ 8；全序列非递减且相邻增量 ≤ 0.1075+1e-6；按产品三条件重算**命中 == 3**；末值 == 1；`lastDoubleTapSynchronization` 非 nil |
| 3 | A | `testIC158A_UnclampedPathStillJumpsToCompletionAfterAStall` | **failed**（1.326 s） | 见 4.2（乙）与第七节第 1 条 |
| 4 | A | `testIC158A_OnlyTheDiagnosticsEntryPassesTheStepAndIC152PinsHold` | **passed**（0.146 s） | 剔注释产品源码：`maximumLinearProgressStep: CGFloat? = nil` 1、`maximumLinearProgressStep:` 2、静态函数声明 1、`page.startDoubleTapTransition(` 3；诊断入口切片内步长调用 1、`durationOverrideSeconds:` 1；两个状态量各 ≥ 3；`advanceDoubleTapTransition` 切片内夹紧符号 ≥ 1、`easedProgress(` 1；取消路径三个新符号各 0（正对照 `reclaimPlaybackLayer()` 1）；IC-152 六个 needle 与 `durationSeconds: TimeInterval = 0.3`、`static let hardFloor = 2`、`machine.reportNativeViewport(` 逐条不变 |
| 5 | B | `testIC158B_ReportCarriesClampLineAndItStaysOutOfSampleTitles` | **passed**（0.083 s） | `clampLine(0,0) == "步长上限触发：进入段 0 次，退出段 0 次"`、`(7,12)` 含两段计数；该行 `hasPrefix("步长上限触发：")`、不含两个样本标题串、不以段名开头；`gateLines(errors: [], softTargetLines: []) == ["中间帧门禁：通过"]`；源码 `clampLine(` ≥ 2、`doubleTapClampedCallbackCount ?? 0` 恰 1；`makeReport` 切片内 `gateLines(`／`clampLine(`／`for sample in samples` 各 1 且位置严格递增；`S2CalibrationHarnessTests.swift` 内两条 `contains` 各 1 |

**既有相关用例**：`IC152DiagnosticPathTests` **6／6** `passed`（`testIC152*` 6 项）；`testIC141*` **16**、`testIC143*` **13**、`testIC144*` **5** 全部 `passed`；函数名含 `DoubleTap` 的用例 **33** 项全部 `passed`、0 失败；`S2CalibrationHarnessTests` **223 passed ／ 1 failed**（失败的唯一一项是 `testIC063…`，该套件 23 条失败断言全部属它）。**卡面点名的「IC-126 双击相关用例」在本仓没有 `testIC126*` 命名的用例**（实测 0 项）——IC-126 的覆盖落在 `S2CalibrationHarnessTests` 与工具链／运行时设定里，故按上面几组实证代之。

---

## 六、根因假设的确认与推翻（纪律 3）

### 6.1 卡内③假设「正常帧率下上限从不触发」——**在本 runner 上不成立到会吃掉导出期限的程度**

① 实测：

- `testIC063…` 本次 **31.319 s**；同一用例在 #315／#316（本卡改动之前）分别是 4.190 s／4.152 s。
- 10 s 期限（`:4139-4142`）内 `diagnostics.isExporting` 仍为真，`reportText` 为空串。
- 本分支唯一能影响诊断运行时长的产品改动就是夹紧（`change-list.md` 第二节：产品侧 diff 只有 `S2NativePhotoPager.swift`，且 A7 两个调用点未动）。

③ 我的归因（**与卡面假设矛盾，按纪律 3 写明**）：夹紧把每段所需的**回调次数**下限固定成 `4(n+1)`（进入 ≥16、退出 ≥24），与墙钟无关。只要 runner 在诊断段的有效回调节奏低于 16 fps（进入段）／24 fps（退出段），夹紧就会在**没有任何停顿**时也逐回调触发，把 1.0 s／1.4 s 的段拉长到 `16/节奏` 与 `24/节奏` 秒。产品源码 `:1393-1395` 自己记着 IC-122 时代的实测「进入段约 2 次回调 / 250 ms（≈8 fps 有效节奏）」——按 8 fps 算就是 2 s + 3 s，再叠上两段各自的 `waitForDiagnosticStableState` 与其余阶段，10 s 期限被吃掉是意料之中。

**边界（我拿不到的部分）**：本次报告没产出，`步长上限触发` 行与 `cadenceDescription` 的节奏数据一并丢失，因此**我无法给出本次运行里夹紧实际触发了几次、每段实际用了多少回调**。要把这条从③升到①，最小代价是让报告能印出来（例如只放宽 `:4139` 的导出期限）——**那是卡外的改动，按 G900 交决策会话定，执行端不自行改**。

### 6.2 卡内断言 3 的期望「停顿后第一个进度值 == 1」——**被实测推翻**

① 实测：停顿后第一次回调的缓动值 `0.0021310788393515707`，反解得线性进度 **0.033333**，在 1.0 s 时长下即 elapsed = **33.3 ms**（60 fps 的两帧）；该用例总耗时 1.326 s（其中 `Thread.sleep` 占 1.2 s），且 `.completed` 恰 1、收口正常。

② 观察（同一用例内自洽的解释）：主线程被 `Thread.sleep` 阻塞期间显示链接不投递；runloop 恢复后**第一次**投递的回调带的是阻塞前那一帧的陈旧 `timestamp`（故 elapsed 只长了两帧），**下一次**回调才带上当前时间、线性进度一步越过 1 并收口——这与断言 3 另外两条通过的断言（`completedCount == 1`、停顿后仅有 1 次进度<1 的回调）完全一致。

**这不改变裁定 一要治的现象**（停顿后墙钟进度跨过全部阈值），只说明「跳」落在停顿后的**第二次**回调上。按 G900 与纪律 2／3，我**没有**改这条断言、没有复跑；正确的期望口径（例如「停顿后前两次回调之内出现 1，且其后不再有进度<1 的回调」）留给决策会话定。

---

## 七、卡内问题、实现取舍与流程失误（请决策会话裁定）

### 7.1 断言 3 的期望与实测冲突

见 6.2。**未改动**，原样留红上报。

### 7.2 段别区分的写法

裁定 三允许「按 `middlePrefix` 或按调用顺序区分」。实装取前者：`.completed` 分支内 `if middlePrefix == "双击进入 Nx：动画中间帧"`。该字面量在产品文件内因此由 2 处变 3 处（另两处是两个段的 `middlePrefix:` 实参）；**无任何既有断言对它计数**（IC-152 断言 6 的六个 needle 不含它，`testIC063…` 数的是报告文本里的样本标题）。落在扫描器豁免区内（`S2GeometryDiagnosticsRun` 之后），本机扫描退出码 0。

### 7.3 `maximumLinearProgressStep:` 实参的换行写法

卡面允许不单行。实装在 `beginDiagnosticDoubleTap` 内照同处 `durationOverrideSeconds:` 的既有形状换行缩进；断言 4 的 needle 是 `maximumLinearProgressStep:`（带冒号、不含实参），计数 2 成立。

### 7.4 执行端流程失误：两个提交先落在本地 `main`

开工核对三条都做了，但**漏了「切分支」这一步**就开始改文件，A（`c3cc047`）与 B（`96acc6c`）因此先提交在本地 `main` 上。发现后的处置：

1. `git switch -c feature/ic-158-diagnostic-progress-clamp`（在该提交上建分支）；
2. `git branch -f main 15bf53f042a30a1ace0dfea2cf289973f019c67d`（把本地 `main` 退回基线）；
3. 核对：本地 `main` = 远端 `main` = `15bf53f042a30a1ace0dfea2cf289973f019c67d`，分支 tip = `96acc6c`，工作树净。

**全程未推送过 `main`**（远端 `main` 自 IC-157 收口起一直是 `15bf53f`），两个提交内容与落点最终与卡面要求一致；无历史改写（`git branch -f` 只移动本地分支指针，被移开的提交都在分支上）。如实登记，请决策会话确认这一处置可接受。

### 7.5 本机 Swift 结构预检的一处误报

`check_swift_strings.py` 对 `S2NativePhotoPager.swift:5933` 报「括号不配平」。该行是既有的 `animationKeys`（字符串插值里嵌套引号），`15bf53f` 上同一行为 `:5894`，**本卡 diff 不含它**（`git diff … | grep -c replacingOccurrences` = 0）。属我这只纯文本预检不支持插值嵌套，不是缺陷。

---

## 八、本机预验证（Python 手工移植；②，不构成 XCTest 会通过的证据）

| 脚本 | 对象 | 检查数 | 失败 |
|---|---|---|---|
| `eased.py` | `easedProgress` 逐字移植（系数、`curveX`／`curveXSlope`／`bezierValue`、牛顿 + 二分 `solveCurveTime`）；n ∈ {3,5,0} 的最大缓动增量 | 3 | 0 |
| `check_a158.py` | 断言 4 全部 needle；IC-152 六个 needle；`durationSeconds: TimeInterval = 0.3`／`hardFloor`／`reportNativeViewport`；IC-146 的 `.clear` 8 与 `backgroundColor = .clear` 7、IC-140 的 `writePhotoGeometry` 5；四段切片与 `15bf53f` 逐字相同；夹紧／不夹紧／正常 60 fps 三种回放 | 44 | 0 |
| `check_b158.py` | 断言 5 全部 needle 与位置顺序、`clampLine` 文本、`S2CalibrationHarnessTests` 两条 `contains` 与 +1 行差；A 的 needle 在 B 之后复算 | 19 | 0 |
| `check_swift_strings.py` | 改动与新建的 3 个 `.swift` | 3 | 1 误报（第 7.5 条） |

**断言 1 的两个上界实算值**（卡面给 0.1075／0.0718，复算对上）：

| n | step | spacing | 最大缓动增量 | 取最大处 x | < spacing | < spacing/2 |
|---|---|---|---|---|---|---|
| 3 | 0.062500 | 0.250000 | **0.107492** | 0.470 | 是 | 是（0.125） |
| 5 | 0.041667 | 0.166667 | **0.071761** | 0.479 | 是 | 是（0.0833） |
| 0 | 0.125000 | 0.500000 | 0.213389 | 0.437 | 是 | 是 |

**三种回放（②，按 60 fps 节奏 + 1.2 s 停顿）**：

| 情形 | 回调数 | 上限触发 | 停顿后进度<1 | 命中 | 末值 | 最大相邻增量 |
|---|---|---|---|---|---|---|
| 夹紧（步 1/16） | 19 | 16 | 15 | **3** | 1.0 | 0.107317 |
| 不夹紧 | 4 | 0 | 0 | 0 | 1.0 | 0.999471 |
| 正常 60 fps 无停顿 | 61 | **0** | — | — | 1.0 | — |

正常 60 fps 下夹紧与不夹紧的样本序列**逐值相同**——这条是「产品与正常运行报告不变」的本机依据；但它假设的就是 60 fps，**而 6.1 的实测说明 CI runner 的诊断段节奏远低于此**，回放因此没能预见 `testIC063` 的（乙）红。

**IC-152 六个 needle 改后计数**（G899 要求逐个贴）：`errors.append(` **2**、`secondsPerThreshold: TimeInterval = 0.2` **1**、`minimumMiddleFrames: 3` **1**、`minimumMiddleFrames: 5` **1**、`CGFloat($0) / CGFloat(minimumMiddleFrames + 1)` **1**、`self.middleThresholds.removeFirst()` **1**（正对照 `中间帧软目标未达：` ≥ 1 命中）。

---

## 九、闸门

### G897（满足）

- diff 限于白名单 4 个路径（`change-list.md` 第二节）。
- **零改动清单两侧 SHA-256**（`git show <rev>:<path>`）：

| 文件 | `15bf53f` | `96acc6c` |
|---|---|---|
| `Features/S2/S2Calibration.swift` | `B06168A00987D70D17E9A41B2525A5FCE18A0F2CB081C1D70576E7382087410F` | 同左 |
| `Features/S2/S2View.swift` | `FDF0398987E665C7E20A32834A225FCFD68888B965868422E35A251A46F20CC1` | 同左 |
| `Core/S2StateMachine.swift` | `90DDFFAD6AB737BBE00EA1C1CB1CB402503949C45CB5080E55B483A248DFE032` | 同左 |
| `Localizable.xcstrings` | `C58D4323265CD84820ED36EDB92FD7DFE6169140962CAEDF91B6469DA0C50406` | 同左 |

| 目录 | 文件数（两侧） | 逐文件两侧 SHA-256 全同 | 聚合（前 16 位） |
|---|---|---|---|
| `Features/S2/`（除 `S2NativePhotoPager.swift`） | 8／8 | 是 | `0F5C5ED430981316` |
| `Core/` | 10／10 | 是 | `5FBEC9F82D209B19` |
| `Services/` | 11／11 | 是 | `A6149DADFF5C81D2` |
| `App/` | 2／2 | 是 | `7549A019B2E5E065` |
| `Features/S0/` | 9／9 | 是 | `6FBA490FC3E48EE6` |
| `Features/S1/` | 1／1 | 是 | `B0D9C6E9E789F9B6` |
| `Features/S3/`／`S4/`／`S5/` | 各 1／1 | 是 | `4C756DF6152300D5`／`79BBCFC2210CA838`／`24B15569428A0D8C` |
| `Features/Shared/` | 1／1 | 是 | `E47B2834EF63695E` |
| `.github/` | 1／1 | 是 | `C632EEBCF1136833` |
| `Scripts/` | 33／33 | 是 | `302809A0BEEBB3F2` |

- **四段 awk 切块 diff 为空**（`diff <(git show 15bf53f:… | awk …) <(git show HEAD:… | awk …)`，退出码 0，切片非空）：

| 切块 | 行数 | diff 退出码 |
|---|---|---|
| `enum S2DoubleTapTransitionTiming {` → 顶层 `}` | 76 | 0 |
| `static func durationSeconds(minimumMiddleFrames: Int) -> TimeInterval {` → `    }` | 3 | 0 |
| `func cancelActiveDoubleTapTransition() {` → `    }` | 19 | 0 |
| `func resetInteractionState() {` → `    }` | 15 | 0 |

（首次跑这四条时，我用 `:` 切分参数把 `durationSeconds` 那条的 awk 正则截断了，两侧都报错、`diff` 比了两个空流给出假通过；改成显式逐条命令后才是上表的真结果。登记在此，避免决策会话按第一版命令复核。）

- `S2CalibrationHarnessTests.swift` diff 恰 **+1／−0**。

### G898（满足）

`S2Calibration.swift` 不在 diff（SHA 同上）；`schemaVersion` **7**（`:118`）、`cacheSchemaVersion` **1**（`S0ScanRules.swift:27`）、`hardFloor` **2**（`:4998`）、`secondsPerThreshold` **0.2**（`:1396`）。冻结三链与四条探针远端 tip 与卡面逐条相同：`b368a6ca…`／`6736f1e3…`／`a7cc1ec7…`／`9db02b93…`／`402cb6e5…`／`486bcb76…`／`d373afc7…`。

### G899（部分满足）

- 「不得打红」清单逐项实证：产品与测试的所有点名计数、四段切块、IC-152 六个 needle 均如第八节所示不变；`IC152DiagnosticPathTests` 6／6 与 IC-126／141／143／144 双击相关用例全部 `passed`。
- **不满足的一项**：`testIC063…` 日志里的报告块含 `中间帧门禁：通过` 与 `步长上限触发：` 两行——本次报告块为空，两行都不存在（4.2）。

### G900（不满足，停卡）

绿、真实退出码 0、IPA、断言 1～5 全 `passed` 四项都不成立（#317 failure、退出码非 0、打包步骤 skipped、断言 3 红）。按 G900「若 `testIC063…` 仍红…都停下报告、不复跑凑绿」：本次属**（乙）形态**——`:4145` 红且 `report` 为空。按要求提交的材料：

- 分段耗时 notice：`模拟器启动 74 s；xcodebuild test 526 s；总 600 s`。
- `IC063_DIAGNOSTICS_SAMPLE_BEGIN` 块：**存在但为空**（原文见 4.2）。
- 该用例耗时 31.319 s（绿基线 4.190／4.152 s）。

**未合并、未改期限、未复跑。** 是否把 `:4139` 的期限纳入白名单（或另选方案）请决策会话定。

### G901

未触发（无合并）。

---

## 十、摘取单元实测（克隆仓库）

基底 `15bf53f042a30a1ace0dfea2cf289973f019c67d`：

| 单元 | 命令序列 | 退出码 | 结果 |
|---|---|---|---|
| A 单独 | `c3cc047` | 0 | 无冲突 |
| A→B | `c3cc047`、`96acc6c` | 0、0 | 无冲突；`git diff --stat unitAB 96acc6c` 为空（树相同） |
| 负对照：B 单独 | `96acc6c` | **1** | `DU IC158DiagnosticProgressClampTests.swift`；`S2NativePhotoPager.swift` 与 `S2CalibrationHarnessTests.swift` 两处产品／测试改动干净暂存 |

---

## 十一、人工判定项 H79（原样列出，留给 Lynn 真机，执行端不代为下结论）

装合并后 `main` 的产物（同一包可连判 H72～H78）。**本卡未合并、#317 未产出 IPA，这两条暂无可装的包。**

1. **真机导出诊断仍完整**：标定面板 → 导出几何诊断，报告首部 `中间帧门禁：通过`，且 `步长上限触发：进入段 0 次，退出段 0 次`（真机不该停顿；若非 0，记下数字，属观察不属缺陷）。
2. **产品双击不变**：H74 第 3 条快过（正常双击进出各 5 次，观感与改前一致）——产品路径不传上限，理应一字不变。

---

## 十二、发现但未处理的问题（按纪律只报告不修）

1. **夹紧把「时长」变成了「回调数下限」**（6.1）。诊断段的实际耗时从此 = `max(墙钟时长, 4(n+1) / 有效回调节奏)`。若决策会话要保留本方案，配套要么放宽 `testIC063` 的导出期限，要么给夹紧加一条「墙钟已超时长 K 倍就放行」的兜底——两者都超出本卡白名单。
2. **停顿后的第一次回调带陈旧时间戳**（6.2，② iOS 26.2 模拟器）。任何「停顿后立刻跳到终点」的断言都要按「前两次回调之内」写，不能钉第一次。
3. **`testIC063` 的 23 条断言在报告为空时连带判红**，注解上限 10 条只露出前 6 条 + 2 条本卡的 + 2 条用例行（记忆 `github-annotation-cap-and-log-echoes`）。读这类红要去整包日志取全量，否则会误判「本卡新加的 `:4147` 是元凶」。
4. **执行摘要 notice 报 858、唯一身份 857**（4.3）。有失败用例时两者口径不同，报告一律以唯一身份为准。

---

## 十三、报告提交方式与 SHA 核验

- **提交方式**：代码两个提交先推送取 CI；本报告与 `change-list.md` 在**同一分支**追加一个 docs 提交（纪律 7），纯报告提交按 `paths-ignore` 不触发 CI。**不合并**，故无 G901 回填。
- **40 位 SHA 核验**（两份报告内全部 40 位十六进制串，逐个 `git cat-file -e <sha>^{commit}`）：

| SHA | 退出码 |
|---|---|
| `15bf53f042a30a1ace0dfea2cf289973f019c67d` | 0 |
| `96acc6c47890ae77211a6944af80ae51670a07cf` | 0 |
| `c3cc047ecd8b616a84941aa07a23371b2e987bd4` | 0 |
| `ab3eed1f49262b1c6fa49272ee65c1aeb4a8ea5b` | 0 |
