# IC-168 自验报告：S2 → S3 回落的可见提示与可复制诊断、在途虚拟范围撤销、类别页进入失败提示

> 任务卡：`<top>/Tasks/IC-20260923-168-s2-exit-diagnostics-and-fallback-toast.md`（S0／协调器维护卡，可合并）
> 执行会话：2026-09-23。证据分级按 CLAUDE.md 第四节：①已验证事实、②样本观察、③合理推测、④项目判断。

## 一、结论（先行）

**交付完成，已合并入 `main`。** 六个子项各自独立提交、顺序 A → B → C → D → E → F；CI 预算 3 次只用 2 次，两次都一次绿：

| 子项 | 提交 | CI | 结果 |
|---|---|---|---|
| A 在途登记撤销 | `3445ef54baf2d56fdec478ecc68208c069f8d4d6` | 与 B、C 同推 | — |
| B 守卫命名与诊断文本 | `9fbc22b99b42126582f8e48071cff00c83456ab5` | 与 A、C 同推 | — |
| C 面板显示 | `9a2f992d72af3966e5f5121971e95d0ca003852d` | **#340**（run 35928927533） | 一次绿，**876 项 0 失败**，真实退出码 0 |
| D 清理 tab toast | `0fe9de0902274ec9643b571d72a3f958a9ffd045` | 与 E、F 同推 | — |
| E 类别页进入失败提示 | `5dd36d3f908a7f76abd0bb5dfd3099eb80c947d3` | 与 D、F 同推 | — |
| F 新断言 | `e7c1be085102b5d9685b0863f29feb6bfa006a38` | **#341**（run 35929951103） | 一次绿，**882 项 0 失败**，真实退出码 0 |
| 合并 | `8dba3fdde4bee6763cd4d5cc6443107b8c55dd82`（`--no-ff`，父 `c80a1dd` + `e7c1be0`，树 = F 的树） | **合并后 `main` 运行 #342（run 35931047422）** | 一次绿，**882 项 0 失败**，真实退出码 0 |

- G944～G949 全部满足（第六节逐条）。项数对账：876 →（A）876 →（B）876 →（C）876 →（D）876 →（E）876 →（F）882，与卡面一致①。
- **第 195 条第二节第 3 条 ③ 的 CI 复现（断言 4，单列）**：协调器 `enterS1` 后不做范围读取（S1 状态机停在加载态），经虚拟范围交接进 S2、上滑标一张、点右上垃圾桶——写回成功、对账静默返回假、提交形成为 nil，回落并发 `.submissionUnavailable`，诊断文本 `loadingState=loading … reconciled=false … guard=M2`（第五节原文）①。**这只证明机制在夹具里成立；真机回落是不是这一道，仍是 ③，待 H88 第 2 条的诊断文本证实。**
- 卡面「事实基础」行号与锚句、各子项计数，执行端先用本机 Python 移植（源码扫描 helper 逐字符移植）逐条复算，**全部相符**；E 的 15 处同步点改前 grep 命中数与卡面预期（11／5）一致（第九节）。卡面没有推不出的计数、没有不是恰一处的锚句，守卫顺序化重构逐位不变（第四节）——未触发停卡条件。
- 合并在 Bash 工具一次通过，未被 `[Merge Without Review]` 拒绝；推送 `main` 一次成功。
- **报告落点（惯例 44）**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md` 同在其中）。报告引用的合并后运行编号与 artifact 都是该 docs 提交之前已产生的信息，不存在跨卡回填。
- 人工判定项 H88 六条保留给 Lynn 真机判，执行端不代为下结论（第十二节）。

## 二、输入、继承与范围

- 输入：`<top>/CLAUDE.md` 全文（会话开始时磁盘上的版本，`main` = `c80a1dd`）；`<top>/SPEC-S1-20260923_v10.md` 第七节（第 1～3 部分）与决策 29／30 的依据与承接补充；`<top>/SPEC-S0-20260923_v4.md` 第六节（显示元素、可用操作清单、迁出条件与目标状态）、第十节全部、第十三节 `:598`、第十五节 `:981`；任务卡全文；`Tasks/RESEARCH-IC-168-facts.md`、`Tasks/REVIEW-IC-168-findings.md`、`Tasks/REVIEW-IC-168-round2-findings.md`（以卡为准）。
- 继承：`main` = `c80a1ddc684aa2acff59084ba7b151825584d65b`（IC-167 报告补记）；IC-167 merge `81effe7c388e6b18560ee284d4cab7d575eca2b1` 为其祖先。
- 目标分支：`feature/ic-168-s2-exit-diagnostics`（自上述 `main` 切出，已推送，保留不删）。
- 范围边界：只做卡内六条裁定。未做（卡「本卡不做」与「范围外」）：S1 机器 `.loading` 根因修法、`os_log`／`Logger`、S2 标记态按 `D_全部`（IC-169）、未定项 12、S1 现行入口决策 30 对账、`S1View.swift` 与 `S2View` 其余任何改动、SPEC 与 Decision_log。

### 开工四步

1. `git status --porcelain` 输出为空，退出码 0。
2. `git merge-base --is-ancestor 81effe7c388e6b18560ee284d4cab7d575eca2b1 main` 退出码 0；本地 `main` = `c80a1ddc684aa2acff59084ba7b151825584d65b`（与卡面基线一致）。
3. `git ls-remote origin refs/heads/main` = `c80a1ddc684aa2acff59084ba7b151825584d65b`，与本地一致。
4. 改任何文件之前 `git switch -c feature/ic-168-s2-exit-diagnostics`。同时记下十五条被保护分支的 tip（第十一节）。

## 三、六条裁定的落实

### 裁定 二：在途登记撤销（子项 A）

- `S1StateMachine.cancelS2Handoff(virtualRangeID:)`（`:724`）= `activeVirtualRangeIDs.remove(virtualRangeID)`，放在 `makeS2Handoff(virtualRangeID:…)` 之后、`makeS3Submission()` 之前（即交接构造之后、`applyS2Return` 之前）；不动名字表、不调 `publishSnapshotIfChanged()`（仍 6）。`makeS2Handoff(for:)` 的 35 行逐字块未动（IC157 断言 3 在 #340／#341 passed①）。
- 进 S2 失败：App `onEnterS2` 闭包 `guard coordinator.enterS2(from: handoff) else { s1Machine.cancelS2Handoff(virtualRangeID: virtualRangeID); return false }; return true`（`:124-128`）。
- 写回失败：协调器 `returnToS1AfterFailedWriteBack()` 首行（`clearS2RouteState()` 之前）`if let entryContext = s2EntryContext { s1Machine?.cancelS2Handoff(virtualRangeID: entryContext.rangeID) }`。E2／E3 不加（W8 已成功、`:780` 已移除）。

### 裁定 一：诊断文本与守卫命名（子项 B）

- `@Published private(set) var s2ExitDiagnosticsText: String?`；`leaveS2(with:)` 与 `enterConfirmationFromS2(with:)` 每次离开都覆写（成功也写）。
- 取样：两条入口第一句 `let sample = sampleS2Exit(payload)`，在 `applyS2ExitPayload` 之前；`S2ExitSample` 十六个字段（卡面十五个 + `preApplyFailure`），依赖 S1 状态机的项在它为 nil 时取 nil、打印 `na`；`sampleS2Exit` 只读不写（它调的 `s2ExitGuardFailure` 也是纯判定）。
- 定名：E1 = `sample.writeBackFailure`（`preApplyFailure` 非 nil 取它；否则按样本 `!(inflight ?? false) && !(!(isObscured ?? true) && (stateIsReady ?? false))` 判 `W8a`，否则 `W8b`）；E2 = `sample.submissionFailure`（`loadingState == nil` → `M0`、`isObscured == true` → `M1`、`loadingState == .loading` → `M2`、其余 `M3`）；E3 = `lastS3EntryGuardFailure`（`enterConfirmationFromS1` 的 C2 写 `.C2`、C3 写 `s3EntryGuardFailure` 的返回值、成功写 nil）。E1／E2 定名与文本组装只读 `sample`，不读活状态。
- **实装选择（卡未规定写法，登记如下）**：W8a／W8b 与 M0～M3 的判定写成 `S2ExitSample` 的两个计算属性 `writeBackFailure`／`submissionFailure`（结构体内，不是协调器的第五、六个函数；只读样本字段），两条入口共用，不重抄两遍。
- 每条路径的顺序照卡：取样 → `applyS2ExitPayload` → 失败：定名 → `reconciled = returnToS1AfterFailedWriteBack()` → 记录 → `return false`；成功：`clearS2RouteState()` → 对账（记返回值）→ E2／E3 定名 → 记录 → 原有收场（E2 的 `returnToS1AfterUnavailableSubmission()`、E3 的 `route = .s1; message = nil`）→ 返回。
- `returnToS1AfterFailedWriteBack()` 改 `-> Bool`（不加 `@discardableResult`），回传其内那次对账结果；两条入口都用返回值。`reconciled` 不再有 `skipped`。
- 文本格式（源码字面量全 ASCII；布尔 `String(Bool)`、枚举 `String(describing:)`、数字 `String(Int)`、nil 写 `optional.map { String($0) } ?? "na"`，`guard=` 写 `failure?.rawValue ?? "none"`；各行先拼 `[String]` 再 `joined(separator: " ")`，全文 `joined(separator: "\n")`）：
  ```
  format=ic168-s2-exit-v1
  entry=… route=… loadingState=… stateIsReady=… isObscured=…
  rangeID=… inflight=… inflightCount=…
  ordered=… currentInList=… snapshotPending=… returnedPending=…
  sessionMatch=… dAll=… f=… rangesWithPending=…
  reconciled=…
  outcome=… guard=…
  ```
- `private enum S2ExitDiagnosticGuard: String`（23 个 case，隐式原始值 = case 名）；新增枚举、结构与四个函数全部在 `clearS2RouteState()` 之后（`:993-`），不贴 `returnToS1AfterFailedWriteBack()`。`s3EntryGuardFailure` 为 `private static`（返回类内私有枚举）。协调器零汉字字面量、零 `return "…"`、无叫 `message` 的新变量（扫描器 0 残留，第七节）。
- `recordS2ExitDiagnostics(entry:sample:payload:reconciled:outcome:failure:)` 照卡面签名保留 `payload` 形参；文本各字段都已在样本里，函数体未用它（登记，不影响行为）。

### 裁定 五：S2 标定面板末段（子项 C）

- `S2View` init 末位 `exitDiagnosticsText: String? = nil`（`feedbackToastPresenter:` 之后）、存储属性与赋值；8 处既有构造（测试 7 + 预览 1）未动，#340／#341 编译通过①。
- 面板段序 `doubleTapProbeSection` 之后 `exitDiagnosticsSection`；定义照 `doubleTapProbeSection` 逐行（`@ViewBuilder`、不包 `VStack`、`Divider()` → 标题 → `if let` 则 `ShareLink`／`.s2MinimumTouchTarget()`／`Text(verbatim:)` 三行链 + 等宽 + 可选中，`else` 空态一句）。
- App `s2Screen` 在 `onAlbumPickerSelection:` 之后追加 `exitDiagnosticsText: coordinator.s2ExitDiagnosticsText`。目录加三条，255 → 258。

### 裁定 四：清理 tab 回落 toast（子项 D）

- 页面 `toastView` 的视图体原样抽成同文件 `struct S0FeedbackToastLabel: View`（文件末尾、`enum S0DeckPageShade` 之后），`toastView` 改调它；`S0DeckMetrics.` 153、`S0DeckMetrics.toast` 5、`s1ChromeGlassBackground(` 5 不变。页面 D 的 `git diff c80a1dd 0fe9de0` 只有两处 hunk：`@@ -760,14 +760 @@`（`toastView`）与 `@@ -989,0 +977,24 @@`（新 struct）①。
- App：`@StateObject private var cleanupFeedbackToast = S1FeedbackToastPresenter()`；`S0CleanupFlowView(...)` 之后三只修饰符（`.overlay(alignment: .bottom)`、`.onAppear` 读通道当前值、`.onChange(of: coordinator.s1FeedbackEvent)` 用 `newValue`）；三成员照卡（浮层只在清理 tab 选中时显示；底距首页 24、类别页 24 + 72 + 8 = 104，全是既有登记值；呈现函数在「逐张整理」选中时不呈现不消费）。**`S1View.swift` 一字未动**（blob 两侧同为 `16496cab01001aae731b1edc2be2bf478e7d2d40`①）；`tabContainer(s1Machine:)` 与其 `.onAppear` 块未动。
- IC156 断言 10 `feedbackToastDurationMilliseconds` 3 → 4（同提交改期望与注释）。

### 裁定 三：类别页进入失败提示（子项 E）

- 页面 `onLongPress` 属性与 init 形参改 `([String], String) -> Bool`（赋值行未动）；手势 `.onEnded { _ in if !onLongPress(…) { toast.present(text: L10n.text("s0.categoryPage.toast.enterFailed"), durationMilliseconds: toastDurationMilliseconds) } }`。流程容器闭包去掉 `_ =`。
- 目录加 `s0.categoryPage.toast.enterFailed` = `暂时无法逐张查看，请重试。`（紧跟 `s0.categoryPage.toast`）；`s0.` 40 → 41、`s0.categoryPage.` 10 → 11；不借 `s1.toast.*`（借用集仍五条）。15 处同步点见第九节。

### 裁定 六：不修 `.loading` 根因

- 未动 S1 状态机的加载路径与 `S1View`；断言 4 在 CI 上把机制复现一次（见第一节与第五节）。

## 四、守卫顺序化重构对照（行为逐位不变）

**`applyS2ExitPayload(_:)`（`c80a1dd` `:903-923` 一只八子句 `guard`）→ `s2ExitGuardFailure(_:)` + 原函数：**

| 原子句（顺序） | 名 | 新写法（`s2ExitGuardFailure`，顺序同） |
|---|---|---|
| `route == .s2` | W1 | `if route != .s2 { return .W1 }` |
| `let s1Machine` | W2 | `if s1Machine == nil { return .W2 }` |
| `let entryContext = s2EntryContext` | W3 | `guard let entryContext = s2EntryContext else { return .W3 }`（要绑定给 W4／W5 用，故写成 `guard let`，语义同「不成立即返回」） |
| `continuationSnapshot.orderedAssetIDs == entryContext.orderedAssetIDs` | W4 | `if … != … { return .W4 }` |
| `continuationSnapshot.rangeDisplayInformation.rangeID == entryContext.rangeID` | W5 | `if … != … { return .W5 }` |
| `continuationSnapshot.pendingDeletionAssetIDs == upstreamReturn.pendingDeletionAssetIDs` | W6 | `if … != … { return .W6 }` |
| `continuationSnapshot.currentAssetID == upstreamReturn.currentAssetID` | W7 | `if … != … { return .W7 }`；全过 `return nil` |
| `s1Machine.applyS2Return(upstreamReturn, entryContext:)` | W8（W8a／W8b） | 原函数：`guard s2ExitGuardFailure(payload) == nil, let s1Machine, let entryContext = s2EntryContext else { return false }`，再 `guard s1Machine.applyS2Return(…) else { return false }`；其后 `sessionStore = s1Machine.sessionStore; return true` 不变 |

- 逐位不变的依据①（代码实读）：W1～W7 只读 `route`／`s1Machine`／`s2EntryContext`／`payload`，无写；`!=` 对 `Equatable` 即 `!(==)`；W8 只在 W1～W7 全过后调用一次，与原 `guard` 的短路顺序相同；二次绑定 `s1Machine`／`entryContext` 在 W2／W3 已过时必然成功且与判定时同值（其间无写）。取样里对 `s2ExitGuardFailure` 的额外一次调用同样无副作用。
- W8 的子名只从样本判：`W8a` ⟺ `!(inflight ?? false) && !(!(isObscured ?? true) && (stateIsReady ?? false))`，与 `S1StateMachine.swift:767-768` 谓词的否定逐项对应（取样与 W8 之间只有纯判定，`?? false`／`?? true` 只在 `s1Machine` 为 nil 时生效，那时走不到 W8）。

**`enterConfirmation(from:sessionStore:descriptors:cachedConclusions:)`（`c80a1dd` `:612-630` 一只九子句 `guard`）→ `private static func s3EntryGuardFailure(submission:sessionStore:descriptors:)`：**

| 原子句（顺序） | 名 | 新写法（顺序同，三个局部量 `descriptorIDs`／`groupRangeIDs`／`groupedAssetIDs` 在函数内自算，算法与原 `:609-611` 相同） |
|---|---|---|
| `submission.sourceSessionID == sessionStore.sessionID` | V1 | `if … != … { return .V1 }` |
| `Set(submission.orderedAssetIDs).count == submission.orderedAssetIDs.count` | V2 | `if … != … { return .V2 }` |
| `Set(submission.orderedAssetIDs) == sessionStore.allPendingDeletionAssetIDs` | V3 | `if … != … { return .V3 }` |
| `Set(descriptorIDs).count == descriptorIDs.count` | V4 | `if … != … { return .V4 }` |
| `Set(descriptorIDs) == Set(submission.orderedAssetIDs)` | V5 | `if … != … { return .V5 }` |
| `Set(groupRangeIDs).count == groupRangeIDs.count` | V6 | `if … != … { return .V6 }` |
| `submission.groups.allSatisfy({ …四个 && … })` | V7 | `if !submission.groups.allSatisfy({ …原闭包逐字… }) { return .V7 }` |
| `groupedAssetIDs.count == submission.orderedAssetIDs.count` | V8 | `if … != … { return .V8 }` |
| `Set(groupedAssetIDs) == Set(submission.orderedAssetIDs)` | V9 | `if … != … { return .V9 }`；全过 `return nil` |

- 原函数改为 `guard Self.s3EntryGuardFailure(submission:sessionStore:descriptors:) == nil else { return false }`，守卫之后的写入段（`descriptorByID` 起到 `beginPendingScans()`）一字未动①。判定在一切写入之前、无副作用。`S3ReturnRouteTests` 族（`makeCoordinator` 在 `precondition` 里直调 `enterConfirmation`）#340／#341 全 passed①。

## 五、CI

### #340（A → B → C，第一次取 CI）

- run `35928927533`，attempt 1，被测提交 `9a2f992d72af3966e5f5121971e95d0ca003852d`，`completed / success`。
- 执行摘要 notice：`Executed 876 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 876 tests / 0 failures`；整包日志 `9_运行 XCTest.txt` 按唯一 Test Case 行去重（剔 `##[` 与 ANSI 回显）876 条、passed 876、failed 0①。
- 真实退出码 0：「运行 XCTest」步骤 `success`，工作流以 `exit "$test_status"` 原样退出；日志 `** TEST SUCCEEDED **`（L3966）与「XCTest 已全部通过。」（L3971）都在①。
- 目的地实证行：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`。
- 分段耗时 notice 原文：`模拟器启动 105 s；xcodebuild test 324 s；总 430 s`。
- IPA 校验 notice：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1814441，SHA-256=13f46fce2f335eb767b005c25cdc92357a389ed12d7137dc59306fc273df6604`；artifact `PhotoCleanupMVE-unsigned-9a2f992d72af`（id 10780896415，zip 1814611 字节，有效期至 2026-12-22T22:32:45Z）。
- `testIC063`：用例块内 `building pipeline path_exterior-jba6la8feba4 took 0.730226 seconds`（L2595）落在 `IC063_WARMUP_GATE_END`（L2600）之前①（陷阱 26）。
- 相关族（全 passed）：IC131 5、IC132 5、AlbumScopeWiring 7、FullFlowRouting 6、S2ActionBarWiring 65、IC129 6、S2ImageLoadingState 13、S3ReturnRoute 5、IC157 8、IC163 6、IC146 19、IC139 12、IC134S3 14、S1StateMachine 20。

### #341（A～F，第二次取 CI）

- run `35929951103`，attempt 1，被测提交 `e7c1be085102b5d9685b0863f29feb6bfa006a38`，`completed / success`。
- 执行摘要 notice：`Executed 882 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 882 tests / 0 failures`；整包日志唯一 Test Case 行 882、passed 882、failed 0；IC168 六条全 passed①。
- 真实退出码 0：「运行 XCTest」步骤 `success`；`** TEST SUCCEEDED **`（L4038）与「XCTest 已全部通过。」（L4043）①。
- 目的地实证行：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`。
- 分段耗时 notice 原文：`模拟器启动 95 s；xcodebuild test 369 s；总 467 s`。
- IPA 校验 notice：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1819361，SHA-256=19bc9f98235f1408af883a23601870dc83a0a56824ed3499f5ac12b6ed1bb0af`；artifact `PhotoCleanupMVE-unsigned-e7c1be085102`（id 10781291520，zip 1819531 字节，有效期至 2026-12-22T22:44:03Z）。
- `testIC063`：`building pipeline path_exterior-jba6la8feba4 took 0.644060 seconds`（L2667）在 `IC063_WARMUP_GATE_END`（L2672）之前①。
- 相关族（全 passed）：IC131 5、IC132 5、AlbumScopeWiring 7、FullFlowRouting 6、S2ActionBarWiring 65、IC129 6、S2ImageLoadingState 13、S3ReturnRoute 5、IC157 8、IC163 6、IC147 16、IC148 12、IC156 9、IC165 6、IC166 6、IC167 5、IC146 19、IC139 12、IC153 13、IC160 4、IC134S3 14、S1StateMachine 20、IC168 6。

**断言 2／3／4 的诊断文本原文**（#341 整包日志 `9_运行 XCTest.txt`，各 `print` 一次，首尾标记行照录）：

断言 2（L2310-2318，`testIC168A_FailedWriteBackClearsInflightRegistrationAndNamesW8b`）：

```
IC168_DIAGNOSTICS_A2_BEGIN
format=ic168-s2-exit-v1
entry=back route=s2 loadingState=ready stateIsReady=true isObscured=false
rangeID=cat:screenshot inflight=true inflightCount=1
ordered=3 currentInList=true snapshotPending=1 returnedPending=1
sessionMatch=false dAll=1 f=1 rangesWithPending=1
reconciled=false
outcome=writeBackFailed guard=W8b
IC168_DIAGNOSTICS_A2_END
```

断言 3（L2332-2340，`testIC168B_TrashPathSuccessRecordsOkDiagnostics`）：

```
IC168_DIAGNOSTICS_A3_BEGIN
format=ic168-s2-exit-v1
entry=trash route=s2 loadingState=ready stateIsReady=true isObscured=false
rangeID=范围-2 inflight=false inflightCount=0
ordered=2 currentInList=true snapshotPending=2 returnedPending=2
sessionMatch=true dAll=3 f=3 rangesWithPending=2
reconciled=false
outcome=ok guard=none
IC168_DIAGNOSTICS_A3_END
```

断言 4（L2321-2329，`testIC168B_ColdStartLoadingS1MakesTrashPathFallBackWithM2`——**第 195 条第二节第 3 条 ③ 的 CI 复现**）：

```
IC168_DIAGNOSTICS_A4_BEGIN
format=ic168-s2-exit-v1
entry=trash route=s2 loadingState=loading stateIsReady=false isObscured=false
rangeID=cat:screenshot inflight=true inflightCount=1
ordered=3 currentInList=true snapshotPending=1 returnedPending=1
sessionMatch=true dAll=1 f=1 rangesWithPending=1
reconciled=false
outcome=submissionUnavailable guard=M2
IC168_DIAGNOSTICS_A4_END
```

- 断言 3 的 `rangeID=范围-2` 是夹具数据（运行时字符串，含汉字无害）；源码字面量全 ASCII。三份文本的 `reconciled=false` 都是「测试宿主无相册授权 ⟹ 范围读取回失败 ⟹ 对账返回假」（断言 2／3 在就绪态，断言 4 另因加载态守卫），②样本观察；断言 2／3 只钉 `reconciled=` 存在，断言 4 按卡钉 `false`。

### 合并后 `main` 运行 #342（G949）

- run `35931047422`，attempt 1，被测提交 = 合并提交 `8dba3fdde4bee6763cd4d5cc6443107b8c55dd82`（分支 `main`，push 触发），`completed / success`。
- 执行摘要 notice：`Executed 882 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 882 tests / 0 failures`；唯一 Test Case 行 882、passed 882、failed 0；IC168 六条全 passed①。
- 真实退出码 0（「运行 XCTest」步骤 `success`、`** TEST SUCCEEDED **` L4002、「XCTest 已全部通过。」L4007）。目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`。
- 分段耗时 notice 原文：`模拟器启动 99 s；xcodebuild test 352 s；总 452 s`。
- IPA 校验 notice：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1819361，SHA-256=4ad01e9879429733f23a0a9df5a457844b314780d1767c179f4e7241a4757cfe`（与 #341 同字节数、不同哈希——IPA 不可复现，既有结论）。
- artifact：`PhotoCleanupMVE-unsigned-8dba3fdde4be`，id **10781541255**，zip 1819531 字节，有效期至 **2026-12-22T22:56:39Z**。
- `testIC063`：`building pipeline path_exterior-jba6la8feba4 took 0.853290 seconds`（L2632）在 `IC063_WARMUP_GATE_END`（L2636）之前①。

## 六、闸门

### 六条断言与测试函数（子项 F，新文件 `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift`）

| 断言 | 函数 | #341 |
|---|---|---|
| 1 撤销只删在途登记 | `testIC168A_CancelS2HandoffRemovesInflightRegistrationOnly` | passed |
| 2 写回失败撤销登记、定名 W8b | `testIC168A_FailedWriteBackClearsInflightRegistrationAndNamesW8b` | passed |
| 3 垃圾桶路径成功记 ok | `testIC168B_TrashPathSuccessRecordsOkDiagnostics` | passed |
| 4 冷启动 S1 加载态回落 M2（③ 的 CI 复现） | `testIC168B_ColdStartLoadingS1MakesTrashPathFallBackWithM2` | passed |
| 5 新增符号接线 | `testIC168BCD_NewSymbolsAreWired` | passed |
| 6 类别页进入失败提示 | `testIC168E_CategoryPageShowsToastWhenEnteringS2Fails` | passed |

- 行为断言（1～4）一律 `async` + `await MainActor.run { … }`；夹具照抄 IC131 `makeMismatchedSessionPayload`、FullFlowRouting `makeReadyCoordinator`／`completeRead`／`makeGroupedCoordinator`／`mark`／`openRange`、IC157 `makeMachine`／`makeRange`／`unwrapC`（改名 `unwrap`）为本文件私有 helper；断言 2 的「进 S2 已标一张」夹具照 IC157 断言 7 写成 `makeReadyCoordinatorInVirtualS2`。
- 断言 1 在卡面之外多钉一条「cancel 前后 `sessionStore` 相等」与「组名 = 屏幕截图」（都是本卡新增行为的正面描述，不钉既有计数）；断言 4 多钉 `s2Machine == nil`、`machine.state == .loading` 与 `entry=trash`；断言 6 多钉「调度器恰收一条、到期后清空」。其余与卡面逐条一致。**不进测试**的三类（逐字不动、比改前 +N、别处已钉）留在第九、十一节报告级证据里（惯例 46）。
- 集合断言期望写 `Set([...])`（惯例 45）；key 与字面量形 needle（`format=ic168-s2-exit-v1`、`return "`、三条 `s2.calibration.exit_diagnostics.*`）扫原文，其余扫剔注释与字符串的源码；`check-scan-needle-variant.ps1` 审计通过（第七节）。

### 闸门逐条

- **G944（撤销）**：断言 1／2 passed（#341）；IC157 断言 1（`testIC157A_VirtualHandoffBuildsInAnyStateAndRegistersName`）、断言 2（`testIC157A_VirtualRangeLiveMirrorAndReturnBypassRangeGates`）、断言 3（`testIC157A_RealRangePathsByteIdentical`）、断言 7（`testIC157C_RoundTripThroughCoordinatorLandsMarksAndKeepsPageIdentity`）、IC131 断言 4／5（`testIC131B_FailedWriteBackOnLeaveReturnsToS1AndEmitsOneEvent`／`…OnTrashPathDoesNotEnterS3`）、IC163 全族 6 条 passed（#340／#341）；子项 A 计数实测相符（第九节 A 表）。**满足**。
- **G945（诊断）**：断言 3／4 passed（断言 4 单列为 ③ 的 CI 复现，第一节、第五节）；IC131 5、IC132 5、AlbumScopeWiring 7、FullFlowRouting 6、S2ActionBarWiring 65、IC129 6、S2ImageLoadingState 13、S3ReturnRoute 5 全 passed（#340／#341）；协调器计数（子项 B 第 1 条）实测相符（第九节 B 表）；`selfcheck.ps1` 与扫描器退出码 0、协调器零残留（第七节）。**满足**。
- **G946（面板与清理 tab toast）**：断言 5 passed；IC146 19 条 passed，S2View 原文 `"s2.action.add_recent_album"`／`"s2.action.add_album"`／`"s2.action.share"` 各 1；8 处 `S2View(` 构造编译通过（#340／#341 构建成功）；IC156 断言 10（`testIC156D_FlowHostsHomeAndPageAndAppOnlySwapsBuilder`，改后 4）passed；`S1View.swift` blob 两侧同为 `16496cab01001aae731b1edc2be2bf478e7d2d40`；页面 D 的 `git diff c80a1dd 0fe9de0` 只落两处 hunk：`@@ -760,14 +760 @@`（`toastView`）与 `@@ -989,0 +977,24 @@`（文件末尾新 struct）。**满足**。
- **G947（类别页提示）**：断言 6 passed；IC147 16、IC148 12、IC156 9、IC157 8、IC165 6、IC166 6 全族 passed（#341）；15 处同步点表（改前 grep 命中 → 改后）见第九节。**满足**。
- **G948（白名单外零改动 + 合并前置）**：`git diff --name-only c80a1ddc684aa2acff59084ba7b151825584d65b..e7c1be085102b5d9685b0863f29feb6bfa006a38` 恰 15 路径；「不得打红」两侧对象相同（第十一节表）；十五条被保护分支 tip 未变（第十一节）；两次 CI 绿（876／0、882／0，真实退出码 0，`OS:26.2, name:iPhone 16`，IPA 字节数与 SHA-256、分段耗时 notice、`testIC063` build 行先后见第五节）；pbxproj 撞号扫描（第八节）；合并前工作树净（`git status --porcelain` 空）；合并前 `git ls-remote origin refs/heads/main` 仍 `c80a1ddc684aa2acff59084ba7b151825584d65b`。**满足**，已 `--no-ff` 合并推送（首行照卡）。
- **G949**：合并后 `main` 运行 #342（run 35931047422）一次绿，882／0，分段耗时 `模拟器启动 99 s；xcodebuild test 352 s；总 452 s`，artifact `PhotoCleanupMVE-unsigned-8dba3fdde4be`（id 10781541255，有效期至 2026-12-22T22:56:39Z）。**满足**。

## 七、本地门禁（六个提交各一份，PowerShell 下 `powershell -NoProfile -ExecutionPolicy Bypass -File …`）

| 提交时状态 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --check` | 扫描器「目录 = 引用」 |
|---|---|---|---|---|
| 开工前（基线） | 0 | 0 | 0 | 255 = 255 |
| A | 0 | 0 | 0 | 255 = 255 |
| B | 0 | 0 | 0 | 255 = 255（协调器零残留） |
| C | 0 | 0 | 0 | **258 = 258** |
| D | 0 | 0 | 0 | 258 = 258 |
| E | 0 | 0 | 0 | **259 = 259** |
| F | 0 | 0 | 0 | 259 = 259；结构自验扫 101 个 `.swift`、needle 变体审计扫 49 个测试文件，均通过 |

各次硬编码残留均为 0。

## 八、pbxproj 撞号扫描

- 登记前重扫最大号：fileRef `100000000000000000000071`、buildFile `20000000000000000000006E`（与卡面一致）；新 id `100000000000000000000072`／`20000000000000000000006F` 在基线全文件 0 命中（空闲）。
- 登记后出现次数：`100000000000000000000072` 3（定义、测试组、buildFile 的 fileRef）、`20000000000000000000006F` 2（定义、测试 Sources 阶段）；紧跟 `IC167BasketEntryAndTailTests.swift`。
- 定义行（`<24 位 id> /* … */ = {`）`sort | uniq -d` 输出为空（246 行定义）。

## 九、计数实测（本机 Python 移植的源码扫描 helper，②；权威结论取 CI）

移植 `strippedSource`／`occurrences`／`numericLiterals`／`localizationKeys` 与目录读取，逐条对卡面值（基线列 = `c80a1dd`，实测列 = `e7c1be0`）。另写一只「全测试 needle 差分」脚本：收集 49 份测试里全部字面量 needle，对六个产品文件逐提交比较改前改后的原文与剔注释计数；变化的 needle 逐一核过都不扫这些文件（仅卡面预告的 `feedbackToastDurationMilliseconds` 3 → 4 落在被扫文件上）。

#### 子项 A

| 文件 | 口径 | needle | 卡面值 | 基线 `c80a1dd` | 实测 |
|---|---|---|---|---|---|
| S1StateMachine | 剔 | `func cancelS2Handoff(virtualRangeID: String)` | 1 | 0 | 1 |
| S1StateMachine | 剔 | `activeVirtualRangeIDs.remove(` | 2 | 1 | 2 |
| S1StateMachine | 剔 | `private(set) var activeVirtualRangeIDs: Set<String> = []` | 1 | 1 | 1 |
| S1StateMachine | 剔 | `func makeS2Handoff(virtualRangeID:` | 1 | 1 | 1 |
| S1StateMachine | 剔 | `publishSnapshotIfChanged()` | 6 | 6 | 6 |
| S1StateMachine | 剔 | `setMarked(` | 3 | 3 | 3 |
| S1StateMachine | 剔 | `applyPendingDeletionDiff(` | 3 | 3 | 3 |
| S1StateMachine | 剔 | `private func applyPendingDeletionDiff(` | 1 | 1 | 1 |
| CleanupCoordinator | 剔 | `cancelS2Handoff(virtualRangeID:` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `clearS2RouteState()` | 不变 | 4 | 4 |
| PhotoCleanupMVEApp | 剔 | `cancelS2Handoff(virtualRangeID:` | 1 | 0 | 1 |
| PhotoCleanupMVEApp | 剔 | `enterS2(from:` | 2 | 2 | 2 |
| PhotoCleanupMVEApp | 剔 | `makeS2Handoff(virtualRangeID:` | 1 | 1 | 1 |

#### 子项 B

| 文件 | 口径 | needle | 卡面值 | 基线 `c80a1dd` | 实测 |
|---|---|---|---|---|---|
| CleanupCoordinator | 剔 | `@Published private(set) var s2ExitDiagnosticsText: String?` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `private enum S2ExitDiagnosticGuard: String` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `private struct S2ExitSample` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `private func sampleS2Exit(` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `private func s2ExitGuardFailure(` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `s2ExitGuardFailure(` | 3 | 0 | 3 |
| CleanupCoordinator | 剔 | `static func s3EntryGuardFailure(` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `private var lastS3EntryGuardFailure: S2ExitDiagnosticGuard?` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `private func recordS2ExitDiagnostics(` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `recordS2ExitDiagnostics(` | 7 | 0 | 7 |
| CleanupCoordinator | 剔 | `sampleS2Exit(` | 3 | 0 | 3 |
| CleanupCoordinator | 剔 | `private func returnToS1AfterFailedWriteBack() -> Bool` | 1 | 0 | 1 |
| CleanupCoordinator | 剔 | `pendingDeletionGroupsByRangeID` | 0 | 0 | 0 |
| CleanupCoordinator | 原 | `return "` | 0 | 0 | 0 |
| S3StateMachine | 原 | `return "` | ≥1（正对照） | 3 | 3 |
| CleanupCoordinator | 原 | `.retry()` | 0 | 0 | 0 |
| CleanupCoordinator | 原 | `Timer.scheduledTimer` | 0 | 0 | 0 |
| CleanupCoordinator | 原 | `AssetSizeProbeService.mediaKind(of:` | ≥1 | 2 | 2 |
| CleanupCoordinator | 原 | `mediaSubtypes.contains(.photoLive)` | 0 | 0 | 0 |
| CleanupCoordinator | 原 | `format=ic168-s2-exit-v1` | 1 | 0 | 1 |

#### 子项 C

| 文件 | 口径 | needle | 卡面值 | 基线 `c80a1dd` | 实测 |
|---|---|---|---|---|---|
| S2View | 剔 | `exitDiagnosticsText: String? = nil` | 1 | 0 | 1 |
| S2View | 剔 | `private let exitDiagnosticsText: String?` | 1 | 0 | 1 |
| S2View | 剔 | `self.exitDiagnosticsText = exitDiagnosticsText` | 1 | 0 | 1 |
| S2View | 剔 | `exitDiagnosticsSection` | 2 | 0 | 2 |
| S2View | 剔 | `ShareLink(item: exitDiagnosticsText)` | 1 | 0 | 1 |
| S2View | 剔 | `Text(verbatim: exitDiagnosticsText)` | 1 | 0 | 1 |
| S2View | 原 | `s2.calibration.exit_diagnostics.title` | 1 | 0 | 1 |
| S2View | 原 | `s2.calibration.exit_diagnostics.share` | 1 | 0 | 1 |
| S2View | 原 | `s2.calibration.exit_diagnostics.empty` | 1 | 0 | 1 |
| S2View | 原 | `"s2.action.add_recent_album"` | 1 | 1 | 1 |
| S2View | 原 | `"s2.action.add_album"` | 1 | 1 | 1 |
| S2View | 原 | `"s2.action.share"` | 1 | 1 | 1 |
| S2View | 剔 | `@ViewBuilder` | 20（报告级） | 19 | 20 |
| S2View | 剔 | `Divider()` | 5（报告级） | 4 | 5 |
| PhotoCleanupMVEApp | 剔 | `exitDiagnosticsText: coordinator.s2ExitDiagnosticsText` | 1 | 0 | 1 |

#### 子项 D

| 文件 | 口径 | needle | 卡面值 | 基线 `c80a1dd` | 实测 |
|---|---|---|---|---|---|
| S0DeckCategoryPageView | 剔 | `struct S0FeedbackToastLabel: View` | 1 | 0 | 1 |
| S0DeckCategoryPageView | 剔 | `S0FeedbackToastLabel(text: text)` | 1 | 0 | 1 |
| S0DeckCategoryPageView | 剔 | `S0DeckMetrics.toast` | ≥5 | 5 | 5 |
| S0DeckCategoryPageView | 剔 | `S0DeckMetrics.` | 153 | 153 | 153 |
| S0DeckCategoryPageView | 剔 | `s1ChromeGlassBackground(` | 5 | 5 | 5 |
| S0DeckCategoryPageView | 剔 | `.accessibilityAddTraits(.isStaticText)` | 1 | 1 | 1 |
| S0DeckCategoryPageView | 剔 | `Button {` | 3 | 3 | 3 |
| S0DeckCategoryPageView | 剔 | `Image(systemName: ` | 7 | 7 | 7 |
| S0DeckCategoryPageView | 剔 | `.onAppear` | 1 | 1 | 1 |
| PhotoCleanupMVEApp | 剔 | `S1FeedbackToastPresenter()` | 1 | 0 | 1 |
| PhotoCleanupMVEApp | 剔 | `S0FeedbackToastLabel(text: S1FeedbackToastPresenter.text(for: event.kind))` | 1 | 0 | 1 |
| PhotoCleanupMVEApp | 剔 | `presentCleanupFeedbackEvent(` | 3 | 0 | 3 |
| PhotoCleanupMVEApp | 剔 | `consumeS1FeedbackEvent()` | 2 | 1 | 2 |
| PhotoCleanupMVEApp | 剔 | `s0TabSelection.selectedTab == .cleanup` | 2 | 0 | 2 |
| PhotoCleanupMVEApp | 剔 | `s0FlowModel.presentedCategory == nil` | 1 | 0 | 1 |
| PhotoCleanupMVEApp | 剔 | `S0DeckMetrics.dockBottomInset` | 2 | 0 | 2 |
| PhotoCleanupMVEApp | 剔 | `S0DeckMetrics.dockHeight` | 1 | 0 | 1 |
| PhotoCleanupMVEApp | 剔 | `S0DeckMetrics.toastToDockSpacing` | 1 | 0 | 1 |
| PhotoCleanupMVEApp | 剔 | `feedbackToastDurationMilliseconds` | 4 | 3 | 4 |
| PhotoCleanupMVEApp | 剔 | `S0CleanupFlowView(` | 1 | 1 | 1 |
| PhotoCleanupMVEApp | 剔 | `s0Screen(s1Machine: s1Machine)` | 1 | 1 | 1 |
| PhotoCleanupMVEApp | 剔 | `tabContainer(s1Machine: machine)` | 1 | 1 | 1 |
| PhotoCleanupMVEApp | 剔 | `S0TabContainer(` | 1 | 1 | 1 |
| PhotoCleanupMVEApp | 剔 | `advanceScan()` | 2 | 2 | 2 |
| PhotoCleanupMVEApp | 剔 | `onSnapshotDidChange` | 1 | 1 | 1 |

#### 子项 E

| 文件 | 口径 | needle | 卡面值 | 基线 `c80a1dd` | 实测 |
|---|---|---|---|---|---|
| S0DeckCategoryPageView | 剔 | `([String], String) -> Bool` | 2 | 0 | 2 |
| S0DeckCategoryPageView | 剔 | `onLongPress(` | 1 | 1 | 1 |
| S0DeckCategoryPageView | 剔 | `toast.present(` | 2 | 1 | 2 |
| S0DeckCategoryPageView | 剔 | `LongPressGesture()` | 1 | 1 | 1 |
| S0DeckCategoryPageView | 剔 | `.simultaneousGesture(` | 1 | 1 | 1 |
| S0DeckCategoryPageView | 剔 | `Button {` | 3 | 3 | 3 |
| S0DeckCategoryPageView | 剔 | `Image(systemName: ` | 7 | 7 | 7 |
| S0DeckCategoryPageView | 剔 | `S0DeckMetrics.` | 153 | 153 | 153 |
| S0DeckCategoryPageView | 剔 | `.onAppear` | 1 | 1 | 1 |
| S0DeckCategoryPageView | 剔 | `machine.handle(` | 0 | 0 | 0 |
| S0DeckCategoryPageView | 原 | `s0.categoryPage.toast.enterFailed` | 1 | 0 | 1 |
| S0CleanupFlowView | 剔 | `_ = onEnterS2(` | 0 | 1 | 0 |
| S0CleanupFlowView | 剔 | `onEnterS2(identifier, orderedAssetIDs, currentAssetID)` | 1 | 1 | 1 |
| S0CleanupFlowView | 剔 | `onEnterS2` | ≥2 | 5 | 5 |
| S0CleanupFlowView | 剔 | `@State ` | 0 | 0 | 0 |
| S0CleanupFlowView | 剔 | `machine.ingest(` | 3 | 3 | 3 |

### 子项 E 的 15 处同步点（改前 grep → 改后）

改前对整个测试目录 `grep "count, 40)"` 命中 **11** 处、`grep "count, 10)"` 命中 **5** 处（与卡面预期一致）；后者 IC153 `:580`（缓存条目数）与 IC165 `:19`（目录文件数下限）不是 key 计数，未改。

| # | 文件 | 改前 | 改后 |
|---|---|---|---|
| 1 | IC147 `:817` | `XCTAssertEqual(s0Values.count, 40)` | `41)` |
| 2 | IC147 `:867` | `XCTAssertEqual(catalogS0Keys.count, 40)` | `41)` |
| 3 | IC148 `:545` | `XCTAssertEqual(catalogS0Keys.count, 40)` | `41)`（`:546`） |
| 4 | IC156 `:236` | `hasPrefix("s0.") }.count, 40)` | `41)`（`:237`） |
| 5 | IC156 `:237` | `hasPrefix("s0.categoryPage.") }.count, 10)` | `11)`（`:238`） |
| 6 | IC156 `expected` 映射 | 十条 | 加 `"s0.categoryPage.toast.enterFailed": "暂时无法逐张查看，请重试。"`（`.union` 名单未动） |
| 7 | IC157 `:65` | `hasPrefix("s0.") }.count, 40)` | `41)`（`:66`） |
| 8 | IC157 `:66` | `hasPrefix("s0.categoryPage.") }.count, 10)` | `11)`（`:67`） |
| 9 | IC157 `:82` | needle `"s0Values.count, 40)"` | `41)` |
| 10 | IC157 `:83` | needle `"catalogS0Keys.count, 40)"`（behavior） | `41)` |
| 11 | IC157 `:85` | needle `"catalogS0Keys.count, 40)"`（visual） | `41)` |
| 12 | IC157 `:90` | needle `"hasPrefix(\"s0.\") }.count, 40)"` | `41)` |
| 13 | IC165 `:225` | `hasPrefix("s0.") }.count, 40)` | `41)`（`:226`） |
| 14 | IC165 `:226` | `hasPrefix("s0.categoryPage.") }.count, 10)` | `11)`（`:227`） |
| 15 | IC166 `:365` | `hasPrefix("s0.") }.count, 40)` | `41)`（`:366`） |

改后测试目录 `count, 40)` 0 处、`count, 41)` 11 处、`count, 10)` 2 处（即上面两处非 key 计数）、`count, 11)` 3 处①。目录 259、`s0.` 41、`s0.categoryPage.` 11；页面引用的 `s0.categoryPage.*` 恰 11 条 = IC156 映射键集；IC147 断言 11 五文件名单下 `s0.` 引用集 = 目录 `s0.` 集、跨前缀借用集仍五条②（#341 实证①）。

## 十、摘取关系（惯例 40，本机克隆实测）

在 `c80a1dd` 上的临时克隆里逐组 `cherry-pick -x`：

| 组合 | 结果 | 结果树 |
|---|---|---|
| A 单独 | 无冲突 | `f281c20bfbdf42c2660f7c331312d3dd7b59866a` |
| A → B → C | 无冲突 | `fff6516fd37914164927d7c2fb8eda7c402b7bd7`（= 分支 C 的树）；#340 实证绿 |
| D 单独 | 无冲突 | `3e138267c6a669772d906935163920ab37e4036a`（只存在于临时克隆，主仓无此对象，见第十六节） |
| E 单独 | 无冲突 | `af2f5e0b36e1ef70c7055c11298dee3792d75e5e`（同上） |
| B 单独（对照） | **冲突**（同一函数 `returnToS1AfterFailedWriteBack`：A 加首行、B 改返回类型），与卡面「B 文本上不可单独摘」一致 | — |
| C 单独（对照） | 文本无冲突，但读 B 新增的 `s2ExitDiagnosticsText`，不可编译（卡面「C 依赖 B」） | — |
| A～F 全部 | 无冲突 | `9803e9a1e6a32ff8cf80b4d950c223458d1130dd`（= 分支 tip 的树）；#341 实证绿 |

D、E 单独只做了文本摘取与本地门禁意义上的核对，未单独取 CI（卡定 D→E→F 一起推）。可摘单元 = A；A→B；A→B→C；D；E；全部（与卡面一致）。

## 十一、白名单外零改动（G948）

`git diff --name-only c80a1dd e7c1be0` 恰 15 路径 = 白名单：`App/CleanupCoordinator.swift`、`App/PhotoCleanupMVEApp.swift`、`Core/S1StateMachine.swift`、`Features/S0/S0CleanupFlowView.swift`、`Features/S0/S0DeckCategoryPageView.swift`、`Features/S2/S2View.swift`、`Localizable.xcstrings`、`project.pbxproj`、测试 IC147／IC148／IC156／IC157／IC165／IC166／IC168①。

| 对象 | `c80a1dd` | `e7c1be0` |
|---|---|---|
| `PhotoCleanupMVE/Services`（树） | `82320c200eea1ecd13c3c1e54acf1e0670b70f8b` | 同 |
| `PhotoCleanupMVE/Features/Shared`（树） | `ca567d006a536e637c0330f8af07bf8b4c0734d3` | 同 |
| `PhotoCleanupMVE/Features/S1`（树，含 `S1View.swift` blob `16496cab01001aae731b1edc2be2bf478e7d2d40`） | `5bb26f016d35fb1327fccef002da4e7c1921eec1` | 同 |
| `PhotoCleanupMVE/Features/S3`（树） | `175b165b22c7a7e7c70dd6fdcb28e9afd58fca55` | 同 |
| `PhotoCleanupMVE/Features/S4`（树） | `d6bce474b5e07285a379ad4dcebe59c1bde69d81` | 同 |
| `PhotoCleanupMVE/Features/S5`（树） | `d738ec8e91342012ab2e9b415e76949b8bc33f05` | 同 |
| `.github`（树） | `74088388c62a10eb277921ecf74e766a2d407e80` | 同 |
| `Scripts`（树） | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同 |
| `Core/AssetModels.swift` | `eac7b0b084e21d8d018b8a110e54b154eb9f63b5` | 同 |
| `Core/L10n.swift` | `5b7918f7dfcafe60f4c19898345877c10b97b00d` | 同 |
| `Core/S0StateMachine.swift` | `c301317a1029d63bca98e82a7637a8ec26b9942e` | 同 |
| `Core/S2StateMachine.swift` | `3af1ca0b5f040cd5cb80a77793a21973834849bd` | 同 |
| `Core/S3StateMachine.swift` | `1b1385da740d88c2fe61d7b6e17f993b3d144780` | 同 |
| `Core/S4StateMachine.swift` | `38508e188d8efb022c2ec9082602e5358d9cd544` | 同 |
| `Core/S5StateMachine.swift` | `888012de064e86860a6597d0fa9deea3a617bcee` | 同 |
| `Core/SessionPersistence.swift` | `0d8371c60f90c5334b3c50215042ea8e296fbcd9` | 同 |
| `Core/SessionStore.swift` | `43cf1ffec2e9cc3b619b178ff3ba3a0f060d1962` | 同 |
| `Features/S0/S0BasketEntryView.swift` | `4349eb0a2a9402a7fe98042316b9b050fc0cf79b` | 同 |
| `Features/S0/S0CategoryPageSelection.swift` | `d114ac601f1131babd290fa39ab3b59f03e42af2` | 同 |
| `Features/S0/S0CleanupDataProviding.swift` | `b9e4a57c3133bf189ed3db21b1ff995547faa40f` | 同 |
| `Features/S0/S0CleanupFlowModel.swift` | `28a1115e183a9cf67f7f0118bf97c50bb37173e0` | 同 |
| `Features/S0/S0DeckHomeModel.swift` | `156ed9c74a3ca9633607db1109fc0d3330ff0930` | 同 |
| `Features/S0/S0DeckHomeView.swift` | `8b2168801c41ffcfe51e13dd0ec9620bf1e60136` | 同 |
| `Features/S0/S0DeckMetrics.swift` | `7b380078b857dac0ad20d44912a084e2015cb0d7` | 同 |
| `Features/S0/S0DeckZoomTransition.swift` | `c1424f9166525d4b5d72f60f745df38a5ee340c3` | 同 |
| `Features/S0/S0SegmentBarModel.swift` | `8878b8fbcfb7cdec883ae04e45c974e53ae56edf` | 同 |
| `Features/S0/S0TabContainer.swift` | `9a80395451f031f86e30873917f003c63c10c6c3` | 同 |
| `Features/S0/S0Text.swift` | `5425b262b4a6b66928c39ebea5d8d5f1439ee687` | 同 |
| `Features/S2/S2AmbientBackdrop.swift` | `9fedf558d033acde95bd902f116f13904acbef29` | 同 |
| `Features/S2/S2AssetVolumeFormatter.swift` | `9c9fb4c73425b6c0cc76f7015726e1e60cc32702` | 同 |
| `Features/S2/S2Calibration.swift`（`schemaVersion = 7`） | `992816e511291a547d43d5baee4eeefdb5f2a858` | 同 |
| `Features/S2/S2LivePhotoPlayback.swift` | `9f3426478bd7ffac6e7997b5c6a52dd5d1fcf354` | 同 |
| `Features/S2/S2NativePhotoPager.swift` | `9fb76733a23d6998c2b659196e2b4eac25aac83a` | 同 |
| `Features/S2/S2TemporaryPhotoImageStrategy.swift` | `1fef785c831dbcbd34dd1baf8a22dd1879b2b7f5` | 同 |
| `Features/S2/S2TopBarInfoPresentation.swift` | `9298d73bb6c10006e78ab85736b0a15ec0572017` | 同 |
| `Features/S2/S2VideoPlayback.swift` | `04fa6e03d7bd3cb10c050e29a4f400820644e696` | 同 |
| 白名单外测试 42 份 | 逐个 blob 相同 | 同 |

- `schemaVersion` 7、`S0ScanRules.cacheSchemaVersion` 1（`Services/` 树不变）、`S0DeckMetrics` 198、`S0DeckSymbol` 8①。
- **十五条被保护分支 tip 未变**（开工时与 合并推送后（2026-09-23 16:07 本机时间） 两次读 `refs/heads/*` 逐条相同①）：`probe/ic-067-screenshot-subtype` `9db02b9`、`probe/ic-125-sentinel-negative` `402cb6e`、`probe/ic-137-media-playback` `486bcb7`、`probe/ic-145-scan-service` `d373afc`、`probe/ic-161-similar-photos` `1f8ff92`、`probe/ic-162-deck-home-preview` `180b052`、`probe/ic-163-deck-home-preview-r2` `562f8b7`、`feature/ic-089-nx-edge-bounce` `b368a6c`、`feature/ic-091-nx-midgesture-handoff` `6736f1e`、`feature/ic-092-nx-window-follow` `a7cc1ec`、`feature/ic-158-diagnostic-progress-clamp` `5cb6733`、`feature/ic-164-pick-ic163-a-d` `cc85fa4`、`feature/ic-165-deck-formal` `dc7e494`、`feature/ic-166-rest-category-and-lib` `2734ccd`、`feature/ic-167-s0-basket-entry-tail-sort` `fc6dd14`（本地与远端一致）。
- **报告级一次性证据（不进测试，惯例 46）**：`S1View.swift` blob 两侧相同（上表）；App 的 WindowGroup `.onAppear` 启动守卫（11 行块）、`case .s2:` 块（7 行块，含下一 `case` 行）与 `tabContainer(s1Machine:)` 整个 builder 在 `c80a1dd` 与 `e7c1be0` 原文中各恰 1 处、逐字相同②（Python 切片比对）；S2View `@ViewBuilder` 19 → 20、`Divider()` 4 → 5（剔注释）。

## 十二、人工判定项（H88 六条，保留给 Lynn 装合并后 `main` 产物真机判，执行端不代为下结论）

装包：合并后 `main` 运行 #342 的产物 `PhotoCleanupMVE-unsigned-8dba3fdde4be`（artifact id 10781541255，2026-12-22 前有效）。

1. 复现 H85 那条：类别页长按进 S2 → 右上垃圾桶。若仍退回类别页，**类别页底栏上方应出现一条 S0 样式的短 toast**（「暂时无法打开确认页，请重试。」或「未能保存这次整理的进度。」，记下是哪句）。然后再长按进 S2 → 长按顶部中胶囊 → 面板拉到末尾「S2 退出诊断（IC-168）」→「复制或分享退出诊断」→ 把整段文本（以 `format=ic168-s2-exit-v1` 开头）发给决策会话。
2. 冷启动对照：杀掉 App 重开，**不切「逐张整理」**，直接做第 1 条——预期文本里 `loadingState=loading guard=M2`（③ 证实）；再切一次「逐张整理」回来做第 1 条——预期 `loadingState=ready`，并记下这次进没进 S3。
3. IC-167 的首页／类别页垃圾桶在冷启动下点击无反应时，切一次「逐张整理」再点：能进 S3 即与第 2 条互证；若首页入口点击时出现 toast，记下它在 tab bar 之上还是压在 tab bar 上。
4. toast 位置与观感：类别页上是否在底栏之上、不压底栏；首页上是否在 tab bar 之上；样式与类别页「已移入待删篮」那条是否同一只。
5. S2 返回键路径（左上返回）正常回类别页，不出 toast；若出现「未能保存这次整理的进度。」，记下并做第 1 条的复制步骤。（类别页「长按进入失败」toast 真机预期不可触发，报告标未覆盖。）
6. 一两句总评。

**执行端给判定者的两条事实提示（①代码实读，不是结论）**：
- 诊断文本只在内存（协调器 `@Published`），不落档：**复现与复制必须在同一次启动内**；杀掉 App 后面板显示「本次启动尚未从 S2 退出」。面板显示的是**上一次**离开 S2 时写下的文本（再次进 S2 不会覆写），之后若又从 S2 退出一次（返回或垃圾桶）会被覆写。
- IC-167 的首页／类别页入口闭包在 `makeS3Submission()` 为 nil 时直接 `return`（`PhotoCleanupMVEApp.swift` `onEnterConfirmation` 闭包的 `guard … else { return }`），**不发事件、不写诊断**——冷启动下点它「无反应」时预期不出 toast；只有 `enterConfirmationFromS1` 的 C2／C3 拒绝才会发 `.submissionUnavailable`（届时由本卡的清理 tab 浮层呈现）。H88 第 3 条「若出现 toast」对应的是后一种。

## 十三、v4 欠账（按本卡实装，不算规格冲突；下一版 SPEC-S0 补）

1. SPEC-S0 v4 第六节 `:325`「写回失败：类别页内不提示；提示走 S1 既有通道……在下次进「逐张整理」tab 时弹出」与 `:981`（第十五节「类别页写回失败提示与 S1 同一通道」）、`:598`（第十三节欠账结清对照第 9 项）三处同义句——本卡按裁定 四（依第 195 条第二节第 3 条）实装为：回落（`writeBackFailed`／`submissionUnavailable`）在清理 tab 当页同时呈现，S1 通道不变。下一版三处同改。
2. 第六节「可用操作清单」「迁出条件与目标状态」没有「长按进入 S2 失败 → 页内 toast」——本卡裁定 三新增，下一版补。
3. 第十四节第 3 部分未登记 `s0.categoryPage.toast.enterFailed`（`暂时无法逐张查看，请重试。`）——本卡卡内暂登（第 170 条惯例），下一版补。

## 十四、③ 登记

- **S1 状态机开屏停在加载态导致垃圾桶回落（第 195 条第二节第 3 条）**：机制在 CI 上由断言 4 复现（`guard=M2`、`reconciled=false`、写回已生效、在途登记已移除）①；**真机回落是否就是这一道仍为 ③**，验证方法 = H88 第 2 条冷启动对照取诊断文本。
- **未选中 tab 的 `S1View` 是否存活（裁定 四）**：未验证 ③。若存活，它的 `.onChange(of: feedbackEvent)` 也会取走同一条事件并在自己的（不可见的）呈现器上呈现、调 `consumeS1FeedbackEvent()`；App 侧 `.onChange` 用 `newValue` 呈现，不回读通道，故两边各自消费、无害（`consumeS1FeedbackEvent()` 幂等）。模拟器测试不装载视图，覆盖不到；H88 第 1／4 条间接覆盖。
- **iOS 26 浮动 tab bar 下类别页 toast 的底距基线**：App 侧浮层挂在承载容器上，按「类别页隐藏 tab bar 后与页面同一安全区」取 104；若 `NavigationStack` 这一层仍保留 tab bar 高度，App 的 toast 会比页面自己的 toast 高一个 tab bar（复核第二轮已指出）③，H88 第 4 条判。

## 十五、发现未处理（按纪律只报告不修）

1. `S0Input.basketCapsule`／`S0Event.basketCapsuleTapped` 仍零产品调用（IC-167 已登记）。
2. 类别页「长按进入 S2 失败」toast 真机不可触发（交接构造只在非法输入时为 nil、`enterS2` 只在路由／会话／标定异常时为假）：**真机未覆盖**；CI 只由断言 6 钉源码接线与呈现器（纪律 5）。
3. IC-167 首页／类别页入口在 `makeS3Submission()` 为 nil 时静默返回、不发事件也不写诊断（见第十二节提示）——冷启动下这条路径仍「无反应」，本卡未改（范围外，S1 `.loading` 根因另出卡）①。
4. `recordS2ExitDiagnostics` 的 `payload` 形参照卡面签名保留但函数体未用（文本字段全在样本里）；如后续卡要精简签名可去掉，本卡不动。
5. 诊断文本只在内存、每次离开 S2 覆写一次、不落档（设计如此，裁定 一）；若 Lynn 复现后又经 S1 进出过 S2，上一次回落的文本会被覆盖——H88 须按第十二节的次序操作。

## 十六、40 位 SHA 核验（陷阱 15）

报告与 `change-list.md` 里的每个 40 位 SHA 都取自实读命令的输出（`git rev-parse`、`git log`、`gh api` 的 `head_sha`）。写完后对两份报告抽出全部 40 位十六进制串（去重 51 个），逐个 `git cat-file -t` 取类型再 `git cat-file -e <sha>^{<类型>}`：

- 主仓内 **49 个通过**①：提交 9 个（`c80a1dd`、`81effe7`、六个子项提交、合并 `8dba3fd`）、树 11 个、blob 29 个。
- 另 2 个是摘取实测在临时克隆里产生的结果树（D 单独 `3e138267c6a669772d906935163920ab37e4036a`、E 单独 `af2f5e0b36e1ef70c7055c11298dee3792d75e5e`），主仓里本就没有这两个对象；在该克隆内 `git cat-file -e <sha>^{tree}` 均通过①。A 单独的结果树 `f281c20bfbdf42c2660f7c331312d3dd7b59866a` 恰等于子项 A 提交的树，故在主仓也存在。
- 64 位的 IPA SHA-256 与 24 位的 pbxproj 对象 id 不在此列（不是 git 对象）。
