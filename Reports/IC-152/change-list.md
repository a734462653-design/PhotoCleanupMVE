# IC-152 变更清单

- 任务卡：`<top>/Tasks/IC-20260915-152-diagnostic-path-dismantle-and-midframe-gate.md`
- 分支：`feature/ic-152-diagnostic-path`
- 基线：`main` = `0bedaea8d85ec4f7c40bfe8b4c9d6dd95cb9d462`（IC-151 报告回填；IC-151 合并提交 `f319a22471fa73cb742159bdd5ab177c7ee3a8e5`）
- 分支 tip（代码）：`2655b24ef128514e0d789ac59b155980814ffbd0`
- 提交数：2 个代码提交 + 1 个报告提交（本文件所在提交）
- `schemaVersion`：**7，未动**（`S2Calibration.swift` 不在 diff 内）

---

## 一、提交清单

| # | SHA | 子项 | 标题 | 可单独 cherry-pick |
|---|---|---|---|---|
| 1 | `ae2ae42331ab94dd7ff36a385c2fb5acaa84649f` | A | 拆除期取消在飞的双击过渡，状态机零次发布 | **是** |
| 2 | `2655b24ef128514e0d789ac59b155980814ffbd0` | B | 中间帧门禁硬下限改每段 2 帧，3／5 降为软目标，导出进度样本 | **否，须在 1 之后** |

**依赖关系（惯例 40，事先写明）**：提交 2 往提交 1 新建的 `IC152DiagnosticPathTests.swift` 里追加断言 4～6，卡内白名单只给了这一个新测试文件，故 B 不能脱离 A 单独摘取。A 自身不依赖 B：它的三个文件（分页器、新测试文件、pbxproj）在 A 提交时即自洽可编译。

---

## 二、文件变更全量（`git diff --name-status 0bedaea..2655b24`）

```
M	PhotoCleanupMVE.xcodeproj/project.pbxproj
M	PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
A	PhotoCleanupMVETests/IC152DiagnosticPathTests.swift
M	PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
```

四个路径全部落在卡内白名单表内。

零改动实证（`git diff --name-only 0bedaea..HEAD -- <前缀> | wc -l`）：

| 前缀／文件 | 命中 |
|---|---|
| `PhotoCleanupMVE/Core/` | **0** |
| `PhotoCleanupMVE/Services/` | **0** |
| `PhotoCleanupMVE/App/` | **0** |
| `PhotoCleanupMVE/Features/S0/`、`S1/`、`S3/`、`S4/`、`S5/` | **0**、**0**、**0**、**0**、**0** |
| `PhotoCleanupMVE/Features/S2/`（除 `S2NativePhotoPager.swift`） | **0** |
| `.github/` | **0** |
| `Scripts/` | **0** |
| `PhotoCleanupMVE/Localizable.xcstrings` | **0** |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | **0** |

`Core/S2StateMachine.swift` 两侧 SHA-256 相同：`90ddffad6ab737bbe00ea1c1cb1cb402503949c45cb5080e55b483a248dfe032`（K2 只读，一行未改）。

---

## 三、`S2NativePhotoPager.swift` 的 hunk（G867 要求贴出）

`git diff 0bedaea..HEAD -- PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift | grep '^@@'`：

| # | hunk 头 | 落点 | 子项 | 在卡内定位表的哪一处 |
|---|---|---|---|---|
| 1 | `@@ -2110,6 +2110,37 @@ final class S2NativeZoomPageController` | `finishActiveDoubleTapTransition()` 之后新增 `cancelActiveDoubleTapTransition()` | A | D3（拆除与收尾） |
| 2 | `@@ -3270,10 +3301,18 @@ final class S2NativePagerViewController` | `resetInteractionState()` 前半 | A | D2 |
| 3 | `@@ -3282,8 +3321,6 @@ final class S2NativePagerViewController` | `resetInteractionState()` 尾部 | A | D2 |
| 4 | `@@ -4253,6 +4290,8 @@ final class S2GeometryDiagnosticsRun` | 新增 `softTargetLines` 存储 | B | G2 |
| 5 | `@@ -4463,17 +4502,24 @@ final class S2GeometryDiagnosticsRun` | `.completed` 分支的判定 | B | G6 |
| 6 | `@@ -4503,26 +4549,29 @@ final class S2GeometryDiagnosticsRun` | `doubleTapCadenceDescription` | B | G8 |
| 7 | `@@ -4661,12 +4710,14 @@ final class S2GeometryDiagnosticsRun` | `makeReport()` 头部 | B | **G9 所在函数——白名单外，见第四节第 1 条** |
| 8 | `@@ -4876,6 +4927,106 @@ final class S2GeometryDiagnosticsRun` | 运行类之后新增 `enum S2DiagnosticMiddleFrameGate` | B | 卡内断言 4 明许「把判据抽成产品内可独立求值的纯函数，放在产品文件内、只被门禁调用」 |

**本机逐字节比对与 `main` 相同的块**（B5 与 R3）：G1 `S2DiagnosticDoubleTapTiming`、G3 `startDoubleTapEntry`／`startDoubleTapExit`（段名与 `minimumMiddleFrames: 3／5`）、G4 阈值公式所在块、G5 `.progressed` 分支（每次回调最多消费一个阈值）、G10 `questionAnswers()`、D1 `dismantleUIViewController`、D3 `finishActiveDoubleTapTransition()`、D4 `doubleTapTransitionDidComplete`、D5 `reportNativeViewport(from:)`。

---

## 四、声明式偏离（逐条写明理由，不在报告里替卡含糊）

1. **`makeReport()` 在白名单之外被改了一处**（hunk 7）。卡内白名单为「D1～D3 与 G2～G8」，而 B2 要求「报告里增加一行」——报告只在 `makeReport()` 一处拼装，G9（`:4665` 门禁结论行、`:4668` 错误行）就在这个函数里。改法：把这两行交给 `S2DiagnosticMiddleFrameGate.gateLines(errors:softTargetLines:)` 拼装，**两行文字与改前逐字相同**，软目标行接在其后、样本之前。拼装外移而不是就地追加一行，是为了让断言 4 能断言**门禁真正用来拼报告头部的那段代码**，而不是测试里的复刻。
2. **子项 A 夹具的拆除不经 SwiftUI，直调 `S2NativePhotoPager.dismantleUIViewController(_:coordinator:)`**（卡内第 3 步写的是「让 SwiftUI 拆除分页器」）。理由见 `self-check.md` 第三节 3.3。
3. **子项 A 夹具不经 `beginDiagnosticDoubleTap`**，照它的同一套调用（`handleNativeDoubleTap` + `startDoubleTapTransition(durationOverrideSeconds:)`）自行起飞，只把落点从视口正中换到左上区域。理由见 `self-check.md` 第三节 3.2。
4. **断言 1 的过渡时长取 3 s**（卡内写「走诊断时长，进入段 1.0 s」）。只需停在飞行中，越长越不怕 runner 卡顿让过渡在拆除前自然跑完；该参数只存在于诊断路径，产品双击时长不经此处。断言 2（自然收口正对照）照卡取 `S2DiagnosticDoubleTapTiming.durationSeconds(minimumMiddleFrames: 3)` = 1.0 s。
5. **断言 3、断言 6 比卡内列的多钉了几条**：断言 3 另钉「取消函数体内不含任何落几何／回调所有者／发事件的调用」「拆除入口不再收尾，且诊断退场与摘观察者都在取消之前」；断言 6 另钉 G4 阈值公式与 G5 `self.middleThresholds.removeFirst()` 各恰 1（落实 B5 的「全部不动」）。都是本卡结果要求的结构性佐证，不改任何既有断言。

---

## 五、逐文件说明

### 1. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`

#### 子项 A（提交 1）

| 处 | 动作 |
|---|---|
| D3 旁 | **新增** `S2NativeZoomPageController.cancelActiveDoubleTapTransition()`：守卫 `isDoubleTapTransitionActive`；显示链接 invalidate 并置 nil；借出的播放层逐个 `reclaimPlaybackLayer()` 并清空；页内容 `isHidden = false`；过渡视图 `removeFromSuperview()` 并置 nil；`doubleTapTargetPage`／`doubleTapLatestPage` 置 nil；`isDoubleTapTransitionActive = false`；滚动视图 `isUserInteractionEnabled = true`。**不落几何、不回调所有者、不发事件。** 清理顺序与收尾一致（先交还播放层、再放开页内容、最后移走过渡视图） |
| D2 `resetInteractionState()` | 顺序由「收尾 → 摘观察者 → …… → 诊断退场」改为「**诊断退场 → 摘观察者 → 取消**」；其余清理（外层拖动、呈现点击、长按闭包、翻页停稳闭包）照旧。该函数全仓只有 `dismantleUIViewController` 一个调用点 |
| D3 `finishActiveDoubleTapTransition()` | **一字未动**（自然收口、零时长早收口、归一诊断态三处既有调用不受影响） |
| D1、D4、D5 | **未动** |

#### 子项 B（提交 2）

| 处 | 动作 |
|---|---|
| G2 | 新增 `private var softTargetLines: [String] = []` |
| G6 | `if !middleThresholds.isEmpty { errors.append("…少于 \(minimumMiddleFrames) 帧"…) }` → 计算 `hits` 后调 `S2DiagnosticMiddleFrameGate.evaluate(...)`，结果按「有错进 `errors`、有软目标行进 `softTargetLines`」接线。`errors` 的写入点仍是这一处加 `capture` 那一处 |
| G8 | `doubleTapCadenceDescription(hits:minimumMiddleFrames:)` 签名不变，函数体改为委托 `S2DiagnosticMiddleFrameGate.cadenceDescription(...)`，并传入 `controller?.diagnosticCurrentPage?.doubleTapTransitionProgressSamples ?? []` |
| G9 所在的 `makeReport()` | 头部门禁两行改由 `gateLines(...)` 拼装（见第四节第 1 条） |
| 运行类之后 | 新增 `enum S2DiagnosticMiddleFrameGate`（下表） |

`S2DiagnosticMiddleFrameGate` 成员：

| 成员 | 说明 |
|---|---|
| `static let hardFloor = 2` | 裁定 二 的硬下限 |
| `static let softTargetMissedPrefix = "中间帧软目标未达："` | B2 的固定前缀 |
| `struct Outcome: Equatable { error: String?; softTargetLine: String? }` | 一段收口的判定结果 |
| `static func evaluate(middlePrefix:hits:softTarget:cadence:) -> Outcome` | 命中 < 2 ⟹ `error = "段名 少于 2 帧" + 归因`；2 ≤ 命中 < 软目标 ⟹ `softTargetLine = 前缀 + "段名 软目标 N 帧" + 归因`；否则两者皆 nil |
| `static func cadenceDescription(hits:progressCallbackCount:partialProgressCallbackCount:firstProgressDelayMilliseconds:durationMilliseconds:progressSamples:) -> String` | 改前五项归因数据原文照搬，末尾追加「；进度样本：…」 |
| `static func progressSampleText(_:) -> String` | 两位小数、逗号分隔、固定 `en_US_POSIX` 区域（小数点不会随系统变成逗号，与分隔符撞车）；空 ⟹ 「无」 |
| `static func gateLines(errors:softTargetLines:) -> [String]` | 结论行、错误行（有错才有）、软目标行（逐条） |

**放置位置的约束（①）**：`Scripts/scan-hardcoded-user-visible-strings.ps1` 只对 `S2NativePhotoPager.swift` 里 `final class S2GeometryDiagnosticsRun` 声明行**之后**的汉字字面量按「几何诊断导出协议字段」豁免；该枚举含汉字字面量，故放在运行类之后。子项 A 的新代码位于该行之前，其注释一律用「」而不用直引号（陷阱 18）。

### 2. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`（子项 B，仅 T2 两条）

| 条 | 旧 | 新 |
|---|---|---|
| T2 进入段 | `report.components(separatedBy: "双击进入 Nx：动画中间帧").count - 1` **≥ 3** | `report.components(separatedBy: "## 双击进入 Nx：动画中间帧 #").count - 1` **≥ 2** |
| T2 退出段 | `report.components(separatedBy: "双击退出 Nx：动画中间帧").count - 1` **≥ 5** | `report.components(separatedBy: "## 双击退出 Nx：动画中间帧 #").count - 1` **≥ 2** |

needle 改为样本标题（报告以 `"## \(sample.label)"` 写标题，label 形如 `"段名 #n"`）后，门禁失败那句错误不再被数进去，计数 = 样本数；阈值与产品硬下限同值。上方加三行注释说明。**T1 `report.contains("中间帧门禁：通过")` 一字未改**，用例体其余断言一字未改。

### 3. `PhotoCleanupMVETests/IC152DiagnosticPathTests.swift`（新，6 项）

| 断言 | 函数名 | 子项 | 提交 |
|---|---|---|---|
| 1 | `testIC152A_DismantleMidTransitionPublishesNothing` | A | 1 |
| 2 | `testIC152A_NormalCompletionStillReportsViewport` | A | 1 |
| 3 | `testIC152A_ViewportReportEntryUnchanged` | A | 1 |
| 4 | `testIC152B_GateFloorIsTwoAndTargetsAreSoft` | B | 2 |
| 5 | `testIC152B_CadenceDescriptionCarriesProgressSamples` | B | 2 |
| 6 | `testIC152B_ErrorWritePointsUnchanged` | B | 2 |

断言 7 沿用改口径后的 `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`，不另计。

源码扫描 helper `sourceWithoutComments(_:)` **只剔 `//` 注释、保留字符串字面量**（跟踪字符串状态，字面量里的 `//` 不误判）。与 IC146／IC148 的 `strippedSource` 刻意不同：断言 6 的正对照 needle `中间帧软目标未达：` 只可能出现在字面量里，喂给连字面量一并剔掉的变体恒为 0——本机实测该变体命中 **0**、只剔注释的变体命中 **1**，正是 IC-149 门禁二要抓的 #295 那类病。

### 4. `PhotoCleanupMVE.xcodeproj/project.pbxproj`（子项 A）

新增四行登记 `IC152DiagnosticPathTests.swift`。加登记前**重扫当前最大号**：文件引用 `100000000000000000000053`、构建文件 `200000000000000000000050`；新号 `100000000000000000000054`／`200000000000000000000051`。登记脚本内置两道断言（新号不得已存在、必须严格大于现有最大号）与四个插入锚点各恰一处命中。

---

## 六、占位值登记

**无出厂值变更。** 本卡不进 `S2CalibrationConfiguration`、不上标定面板，`schemaVersion` 仍 **7**。`S2DiagnosticMiddleFrameGate.hardFloor = 2` 是诊断路径的门禁参数（裁定 二），不是产品出厂值。

---

## 七、项数对账

```
805（main，CI #303 执行摘要）
 + 6（本卡新增，断言 1～6 各一条；断言 7 沿用既有用例不另计）
= 811
```

**实测吻合**：CI #304 attempt 2（run id `35080037007`，被测提交 `2655b24ef128514e0d789ac59b155980814ffbd0`）执行摘要 `Executed 811 tests, 0 failing test case(s), across 1 launch(es)`；唯一 `Test Case` 身份行去重亦为 **811**。attempt 1 同为 811 项 0 失败，但作业超过 15 分钟时限被取消。详见 `self-check.md` 第四节。

---

## 八、合并状态

**已合并（决策会话裁定并执行，2026-09-16 回填）。** 执行端交付时未合并——G870 以 G867 为前置，而第三节 hunk 7（`makeReport()`）落在白名单之外。决策会话追认该处偏离（B2 与 G867 自相矛盾属写卡缺陷，Decision_log 第 178 条），`--no-ff` 合并 **`1e603d73c201c5313b0179dd3765ae4fe87f8306`**（`0bedaea..1e603d7`），合并后 `main` 自动运行 **#305**（run id `35095855030`）success，811 项 0 失败。详见 `self-check.md` 第八节 G871 与第十一节。
