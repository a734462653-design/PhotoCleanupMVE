# IC-147 自验报告 · S0 行为层（两 tab 容器、四态状态机与迁移、数据源协议与桩）

## 结论（先行）

**四个子项全部交付，十三条断言逐条在 CI 绿灯中核过 `passed`，闸门 G843／G844 满足。**

CI 运行 **#292**（id `34871287047`），被测提交 `f41add9cdd16b9402e6cb2a7df7b5f96f9b45713`，**iPhone 16 / iOS 26.2 模拟器**：**Executed 777 tests, with 0 failures**（= `main` 基线 761 + 本卡新增 16），真实退出码 **0**。本地两条门禁退出码均为 **0**。

**CI 用了 2 次（预算 3 次），其中第 2 次是不改一行代码的同提交复跑，不是修。** 首跑（attempt 1）判红，红在**既有用例** `S2CalibrationHarnessTests.testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`；本卡新增的 16 项在那一次也全部 `passed`。对同一提交原样复跑（attempt 2）即全绿，且该用例本身 `passed`。据此判定首跑是该用例的**计时脆弱性**所致，与本卡改动无因果——论证与证据见第五节第 2 部分，**该结论是②样本观察（n=2），不是①**。

人工判定项 H70 五条一律保留给 Lynn 真机判定，执行端不代为下结论。判定第 3 条前请先读第九节末两行与第十节的已知骨架限制。

---

## 一、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260914-147-s0-behavior-layer.md` |
| 规格依据 | `SPEC-S0-20260913_v1.md`，实读 SHA-256 `F5D643653403746590EE1133EBB90A89469E14E73D5CB50974D346CCCF852282`（与任务卡登记值一致）第二／三／四／五／十／十四节 |
| 同层引用 | `SPEC-S1-20260913_v9.md` 第二节（会话层数据唯一定义处） |
| 继承提交 | `main` = `dc1d0f0f9f7d59f5617b2b857f52520a2a43e98a` |
| 开工核对 | `git log --oneline -1 main` = `dc1d0f0 docs(IC-146): 自验报告与变更清单（#290 绿 761 项 0 失败，已合并 d753fc5）`，标题以 `docs(IC-146)` 开头 ✅；`git merge-base --is-ancestor d753fc5a31f5e7e2760b88d1ab842949de5a80bc main` 退出码 **0** ✅ |
| 工作树 | 开工前 `git status --porcelain` 空 ✅（纪律 8） |
| 目标分支 | `feature/ic-147-s0-behavior-layer`，自上述 `main` 切出 |
| 四个提交 | A `de9de132e521c7d4c6dbe8c96ec5d61f316fad7f`／B `31d91bc32018d72bb41095b3b0d70312c805a744`／C `2c7e6ad8bbfc498d22e0c3e96423de34706448c4`／D `f41add9cdd16b9402e6cb2a7df7b5f96f9b45713` |
| 被测提交 | `f41add9cdd16b9402e6cb2a7df7b5f96f9b45713`（分支 tip） |
| 现状基数 | `main` 上 XCTest 761 项（IC-146 #291） |

**范围边界（本卡只做行为层）**：不做氛围底、玻璃卡、分段条、类别行版式、hero 大字——全部属 IC-148 S0 视觉层。不做类别页与组视图、真实扫描服务（批次 5.1，等 H68）、结果闭环核对流程本体（批次 5.3）、升级页与额度弹窗。**S1 一行未改**（顶排换装归 IC-149）。

---

## 二、十三条断言与测试函数名

测试文件 `PhotoCleanupMVETests/IC147S0BehaviorTests.swift`，共 **16 个测试函数**：十三条断言各一，另加三条补充断言（见下表末三行）。

| 断言 | 内容 | 测试函数名 | CI 日志 `passed` |
|---|---|---|---|
| 1 | 容器口径：tab 项恰 2 个、标识与顺序正确、初始选中「空间清理」 | `testIC147AAssertion01TabContainerHasExactlyTwoTabsInOrder` | ✅ 0.004s |
| 2 | 切 tab 无副作用（夹具驱动）：会话层五项 + S1 的 `T`／`O` 逐个不变 | `testIC147AAssertion02TabSwitchingLeavesSessionDataAndS1SortUntouched` | ✅ 1.608s |
| 3 | 路由边界：tab 容器只在 `.s1, .upstream, .finished` 分支内，其余四分支逐字相同 | `testIC147AAssertion03RouteBranchesOtherThanS1AreByteIdentical` | ✅ 0.010s |
| 4 | 四态判定（纯函数）：`SC`×可清理量×`cat` 共 27 组合 | `testIC147BAssertion04StateResolverCoversEveryInputCombination` | ✅ 0.004s |
| 5 | 迁移表逐行：第四节 13 行全覆盖，`coveredRows == Set(1...13)` | `testIC147BAssertion05TransitionTableEveryRowIsCovered` | ✅ 0.003s |
| 6 | 点击有效性矩阵逐格（7 行 × 4 列） | `testIC147BAssertion06ClickMatrixEveryCell` | ✅ 0.011s |
| 6 | `Q=呈现` 时全部输入不接收，关闭后恢复覆盖前状态且数据不变 | `testIC147BAssertion06ObscuringRejectsEveryInputAndRestoresState` | ✅ 0.002s |
| 7 | 汇集口：`SC`／`LG`／`VF` 直写点各恰 1（源码扫描带正对照） | `testIC147BAssertion07EachStateVariableHasExactlyOneDirectWrite` | ✅ 0.019s |
| 8 | 扫描中不重排，转已完成恰重排一次 | `testIC147BAssertion08OrderFreezesWhileScanningAndReordersOnceOnCompletion` | ✅ 0.449s |
| 9 | 协议边界：`Features/S0/` 与桩内 PhotoKit 命中 0（带真实现正对照） | `testIC147CAssertion09NoPhotoKitSymbolInS0` | ✅ 0.011s |
| 10 | 六个数字的措辞隔离：三条禁用措辞零命中（带已登记措辞正对照） | `testIC147CAssertion10ForbiddenWordingNeverAppears` | ✅ 0.009s |
| 11 | 文案登记：引用 key 集合恰等于目录 `s0.` 集合，30 条不多不少 | `testIC147CAssertion11EveryS0StringGoesThroughTheCatalog` | ✅ 0.003s |
| 12 | 桩的确定性：同输入连续两次逐字段相等 | `testIC147DAssertion12StubIsDeterministic` | ✅ 0.001s |
| 13 | 桩能驱动四个态与两种 `cat` | `testIC147DAssertion13StubDrivesEveryStateAndBothFailureCategories` | ✅ 0.001s |
| 补充 | 第三节 S0-2 迁出：前台恢复**无**新增资产留在原态并一次性重排；扫描中前台恢复**不**重排 | `testIC147BForegroundRestorationWithoutNewAssetsStaysAndReordersOnce` | ✅ 0.008s |
| 补充 | 第三节第 4 部分：S0-4 不显示类别行与等待清空行，数据保留、重试后恢复 | `testIC147CFailedStateHidesCategoryRowsAndPendingRow` | ✅ 0.002s |

> 补充断言是审查中发现规格条款未被十三条覆盖后加的，不替代任何一条卡内断言。

### 本机预验证（①，不替代 CI）

本机无 Xcode，无法跑 XCTest。为不把三次 CI 预算耗在可本地发现的错误上，另写了两个**独立模拟器**，对断言逐条求值：

| 模拟器 | 覆盖 | 结果 |
|---|---|---|
| `simulate_scans.py`：按测试内 `strippedSource`／`occurrences`／`localizationKeys` 的实现逐字符移植 | 断言 1、2、3、7、9、10、11 + 两条补充断言的源码扫描部分 | 全通过 |
| `simulate_behaviour.py`：按 `S0StateMachine` 与 `S0CleanupDataStub` 逐分支手工移植 | 断言 4、5、6、8、12、13 + 两条补充断言的行为部分 | 全通过 |

②样本观察，非①：模拟器是手工移植，与 Swift 实现的任何分歧都是移植偏差，**不构成「测试会通过」的证据**；权威结论只取 CI。但它已实际抓到一处会导致 CI 红的缺陷：断言 11 的 key 提取器原按 `L10n.text("` 整串匹配，漏掉六个带 `replacing:` 的多行调用点（实测 24／30），已按硬编码扫描器同一口径（`L10n\.text\(\s*"`，允许换行缩进）改正。

---

## 三、迁移表行数与断言数对账

SPEC-S0 v1 第四节共 **13 行**；`testIC147BAssertion05TransitionTableEveryRowIsCovered` 内以 `coveredRows: Set<Int>` 逐行登记，末尾断言 `coveredRows == Set(1...13)` 且 `count == 13`，**行数与断言数 13 : 13 对账一致**。

| 行 | 起点 | 事件 | 终点 | 落点已断言 | 附带效果 |
|---|---|---|---|---|---|
| 1 | 页面外 | 打开应用 | S0-1 | ✅ | 缓存完整即随后到 S0-2／S0-3：✅ 同一块内断言 |
| 2 | S0-1 | 扫描完成，可清理 > 0 | S0-2 | ✅ | 一次性降序重排：✅ `categoryReorderCount` 0→1 |
| 3 | S0-1 | 扫描完成，可清理 = 0 | S0-3 | ✅ | — |
| 4 | S0-1 | 扫描失败 | S0-4 | ✅ | 记 `cat`：✅ 两种类别各断言 |
| 5 | S0-1／S0-2 | 点击类别行 | 类别页 | ✅ | 传类别标识：✅ `.categoryPage(identifier)` |
| 6 | S0-1／S0-2／S0-3 | 点击待删篮胶囊 | S3 | ✅ 三态各断言 | **先执行 SPEC-S1 v9 决策 30 对账：未接线／未覆盖** |
| 7 | 类别页 | 返回 | 原状态 | ✅ | 重算 `c.*`、hero、分段条：✅ 以「先 `ingest` 再 `handle`」覆盖，含降为零转 S0-3 |
| 8 | S3 | 返回 | 原状态 | ✅ | **交集更新 `M`、清理 `F`：未接线／未覆盖** |
| 9 | S0-2 | 核对通过 | S0-2 | ✅ | `Z += Y`：✅；账本清零、`LG=空`：✅（条目真清零 + 总量归零）；虚线段转实属视觉层 IC-148 |
| 10 | S0-2 | 核对未通过 | S0-2 | ✅ | 账本不变：✅；未清空提示与五步引导属 SPEC-S5 v6／视觉层 |
| 11 | 任一 | 前台恢复且有新增资产 | S0-1 | ✅ 四态各断言 | 增量续扫：`SC` 回扫描中已断言，续扫本体属批次 5.1 |
| 12 | 任一 | 切换到「逐张整理」 | SPEC-S1 v9 | ✅ 四态各断言 | 会话层数据不变：✅（断言 2 在容器层另证） |
| 13 | S0-4 | 重试成功 | S0-1 | ✅ | — |

**第 6、8 行的附带效果本卡不接线**：对账（决策 30）与 `M`／`F` 的交集更新在 `S1StateMachine`／`CleanupCoordinator`，本卡列为不得触碰；SPEC-S0 v1 第十节第 3 部分要求 S0 → S3 的交接「与 SPEC-S1 v9 第七节第 3 部分完全相同、S0 不另造一份提交路径」，故本层只判定落点、不自建提交路径。两行的附带效果归批次 5.3，**在此显式登记为未覆盖，不按落点打勾充作整行已验**。

---

## 四、点击有效性矩阵对账（SPEC-S0 v1 第五节，7 行 × 4 列）

`testIC147BAssertion06ClickMatrixEveryCell` 以 `assertMatrixRow` 逐行驱动四态，共 11 次调用 × 4 格 = **44 格断言**（七行中三行各有两种条件取值，故多于 28）。

| 行 | 操作 | S0-1 | S0-2 | S0-3 | S0-4 | 实现取值 |
|---|---|---|---|---|---|---|
| 1 | 点击有项目的类别行 | 已完成统计的可点 | 有效 | 无此项 | 失效 | `.counting` → 真/假/假/假；`.settled` → 真/真/假/假 |
| 2 | 点击无项目／未识别的类别行 | 失效 | 失效 | 失效 | 失效 | `hasItems=false` 与 `.awaitingScanCompletion` 两种取值均全假 |
| 3 | 点击待删篮胶囊 | `D_全部` 非空时有效 | 同左 | 同左 | 失效 | 非空 → 真/真/真/假；空 → 全假 |
| 4 | 点击人像圆钮 | 有效 | 有效 | 有效 | 有效 | 全真 |
| 5 | 点击「我已清空」 | `LG=非空` 时有效 | 同左 | 同左 | 失效 | 非空 → 真/真/真/假；空 → 全假 |
| 6 | 切换 tab | 有效 | 有效 | 有效 | 有效 | 全真 |
| 7 | 「打开系统设置」／「重试」 | 无此项 | 无此项 | 无此项 | 有效 | 假/假/假/真 |

「无此项」与「失效」在实现上同为 `accepts` 返回假，二者只在测试注释里区分——本层不承载「控件是否存在」，那属视觉层。

`Q=呈现` 由 `testIC147BAssertion06ObscuringRejectsEveryInputAndRestoresState` 单列：遮挡前先断言「至少一个输入被接收」作正对照，遮挡中七个输入逐个为假且 `beginVerification()` 为假、两个 `handle` 落点仍为覆盖前基础状态，关闭后 `state`／`snapshot`／`ledgerState`／`orderedCategoryIDs`／`verificationState` 逐个不变。

---

## 五、CI

### 1. 绿灯读数（#292 attempt 2）

| 项 | 值 |
|---|---|
| 运行编号 | **#292**，run id `34871287047`，**attempt 2**（job id `104070760408`） |
| 被测提交 | `f41add9cdd16b9402e6cb2a7df7b5f96f9b45713`（完整 40 位；`git cat-file -e` 存在性核验见第十一节） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| XCTest 项数与失败数 | **Executed 777 tests, with 0 failures (0 unexpected) in 59.180 (90.961) seconds** |
| 项数对账 | 777 = `main` 基线 **761**（#291）+ 本卡新增 **16**；日志内唯一 `Test Case … passed` 计数 **777**、唯一 `Test Case … failed` 计数 **0**，与执行摘要一致 |
| 摘要 notice | 有（`::notice title=XCTest 执行摘要`），且 `Test Suite 'All tests' started` 只出现 **1** 次（单段运行，摘要即总数） |
| 真实退出码 | 步骤「运行 XCTest」`conclusion=success`；日志末尾打出 `XCTest 已全部通过`，无 `Process completed with exit code` 错误行 |
| 十个步骤 | 全部 `success`（含「运行结构自验」「扫描用户可见硬编码字符串」「构建未签名应用」「上传可下载的未签名 IPA」） |
| IPA 校验 | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1494114，SHA-256=665a8849a422f7acca975fdab13ab54bfb72a846c6a8901306bcf68445a883c9` |

本卡 16 项在该次的逐条 `passed` 耗时已列入第二节表格右列。

### 2. 首跑判红的归因（attempt 1）——**红在既有用例，不在本卡**

attempt 1 同一提交判红，**exit 65**。证据与论证：

| 观测 | attempt 1（红） | #291 绿基线（`main`） | attempt 2（同提交复跑，绿） |
|---|---|---|---|
| 失败用例 | 仅 `S2CalibrationHarnessTests.testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` | 无 | 无 |
| 该用例结论行 | **没有** `passed`／`failed` 行，只有 22 条 `error:`——用例未走完 | `passed (3.923 seconds)` | `passed` |
| `Test Suite 'All tests' started` | **2 次**（测试宿主中途被杀后重启） | 1 次 | 1 次 |
| 唯一 `Test Case … passed` | 776（= 777 − 停摆的那一只） | 761 | 777 |
| 唯一 `Test Case … failed` | **0** | 0 | 0 |
| 本卡 16 项 | **全部 `passed`** | 不适用 | 全部 `passed` |

**为什么判定与本卡无因果（③推测 + ②样本观察，非①）**：

1. 该用例**自建** `S2View`（自带 `machine`／`calibration`／`diagnostics`），把自己的 `UIWindow` 挂到 `UIApplication.shared.connectedScenes`，再驱动 `RunLoop.main` 等真实动画中间帧，**不读取应用根视图**。
2. 测试宿主下 `.onAppear` 的 `XCTestConfigurationFilePath` 守卫使 `coordinator.start()` 不执行，`route` 停在 `.loading`，**应用根视图改前改后同为 `ProgressView`**——本卡新增的 tab 容器所在的 `.s1, .upstream, .finished` 分支在测试宿主下根本不渲染。
3. 本卡在 App 入口新增的只有两个 `@StateObject` 与一个纯算术的桩实例；`restoreS0Foreground()` 同样被上述守卫挡住。
4. 该用例本身计时脆弱：2 秒挂载期限 + 10 秒导出期限，且要求双击进出 Nx 的动画中间帧各 ≥3／≥5；#291 上耗时 3.923 秒，attempt 1 上超过 10 秒仍在导出。

**证据强度**：复跑样本 n=1（attempt 2），②样本观察。**不能据此断言该用例此后必绿**；它是 runner 负载敏感的既有脆弱点，已在第十节挂账。

### 3. 本次运行暴露的 CI 读数缺陷（与本卡改动无关，报告备查）

attempt 1 的 `::notice title=XCTest 执行摘要` 内容是 **`Executed 401 tests, with 0 failures`**——**一条看起来全绿的摘要挂在一次判红的运行上**。成因：`ci.yml` 取 `grep -E 'Executed [0-9]+ tests?' | tail -n 1`，而测试宿主崩溃重启后日志里有两段运行，`tail -n 1` 拿到的是**第二段的小计**，不是总数；停摆的用例又没打出 `Test Case … failed` 行，所以按失败行计数也会得到 0。

对项目的影响：CLAUDE.md 陷阱 22「项数一律以 CI 日志的 `Executed N tests` 执行摘要为准」在**崩溃重启的运行**上会给出偏绿的数字。**补正口径**：先数 `Test Suite 'All tests' started` 的次数，>1 即摘要不可用作总数，改按唯一 `Test Case … passed`／`failed` 行统计，并扫 `error:` 行找「只报错、无结论」的停摆用例。本卡第五节第 1 部分的 777 已按该口径复核过。**判红判绿本身不受影响**——`exit "$test_status"` 原样传出了 65，IC-125 的哨兵也未被绕过。

---

## 六、本地门禁

| 门禁 | 命令 | 真实退出码 | 结果 |
|---|---|---|---|
| 结构自验 | `.\Scripts\selfcheck.ps1` | **0** | 通过（文件、工程配置、String Catalog、禁联网门禁、≥189 项测试数量门禁均符合） |
| 硬编码扫描 | `.\Scripts\scan-hardcoded-user-visible-strings.ps1` | **0** | 通过：目录条目 **245**、产品源码引用 key **245**、用户可见硬编码残留 **0** |
| 空白检查 | `git diff --check` | **0** | 无输出 |

> 两条 ps1 在打完全部修正后**重跑过一次**，上表是重跑后的读数。

**行尾与 BOM**：本卡新增与修改的七个文件在 `HEAD` 中均为 LF、无 BOM（逐文件字节计数 `CR=0`）。①本机注记：Bash 工具下 `grep -c $'\r' <file>` **不按转义解释**，会退化成匹配字母 `r` 并给出与行数相同的假读数；行尾核验一律以字节计数为准。

---

## 七、文案 key 与 SPEC-S0 v1 第十四节第 3 部分逐条对账

新增 **30** 条，全部出自第十四节第 3 部分，**无自造 key**（脚本核验「本卡有而 SPEC 无」为空集）。23 条取值与规格逐字相同；7 条仅因本工程 `L10n.text(_:replacing:)` 用 `{name}` 而非 `%N$@` 作占位符而写法不同，渲染文本一致（既有 `s1.chrome.subtitle_format = {count} 张 · {ranges} 个范围` 即同制）。

| # | key | SPEC §14.3 取值 | 本卡登记值 | 一致 |
|---|---|---|---|---|
| 1 | `s0.account.title` | 你的空间 | 你的空间 | 同 |
| 2 | `s0.basket.capsule` | `%1$@ · %2$@` | `{count} · {volume}` | 占位符译写 |
| 3 | `s0.category.bigVideo` | 大视频 | 大视频 | 同 |
| 4 | `s0.category.duplicate` | 重复照片 | 重复照片 | 同 |
| 5 | `s0.category.screenRecording` | 屏幕录制 | 屏幕录制 | 同 |
| 6 | `s0.category.screenshot` | 屏幕截图 | 屏幕截图 | 同 |
| 7 | `s0.category.similar` | 相似照片 | 相似照片 | 同 |
| 8 | `s0.home.category.counting` | `统计中 · %1$@ / %2$@` | `统计中 · {scanned} / {total}` | 占位符译写 |
| 9 | `s0.home.category.empty` | 无项目 | 无项目 | 同 |
| 10 | `s0.home.category.waiting` | 扫描完成后开始识别 | 扫描完成后开始识别 | 同 |
| 11 | `s0.home.failed.auth.action` | 打开系统设置 | 打开系统设置 | 同 |
| 12 | `s0.home.failed.auth.title` | 需要照片访问权限才能统计空间 | 需要照片访问权限才能统计空间 | 同 |
| 13 | `s0.home.failed.read.action` | 重试 | 重试 | 同 |
| 14 | `s0.home.failed.read.title` | 读取照片库失败 | 读取照片库失败 | 同 |
| 15 | `s0.home.hero.empty.action` | 去逐张整理 | 去逐张整理 | 同 |
| 16 | `s0.home.hero.empty.title` | 没有可清理的项目 | 没有可清理的项目 | 同 |
| 17 | `s0.home.hero.growing` | 数字会继续增长 | 数字会继续增长 | 同 |
| 18 | `s0.home.hero.label` | 可清理约 | 可清理约 | 同 |
| 19 | `s0.home.hero.library` | `照片库共 %@` | `照片库共 {total}` | 占位符译写 |
| 20 | `s0.home.hero.overlap` | 部分项目同属多个类别 | 部分项目同属多个类别 | 同 |
| 21 | `s0.home.hero.progress` | `已扫描 %1$@ / %2$@` | `已扫描 {scanned} / {total}` | 占位符译写 |
| 22 | `s0.home.hero.scanning` | 正在扫描… | 正在扫描… | 同 |
| 23 | `s0.home.pending.action` | 我已清空 | 我已清空 | 同 |
| 24 | `s0.home.pending.checking` | 正在核对… | 正在核对… | 同 |
| 25 | `s0.home.pending.failed` | 设备空间没有变化，看起来还没清空最近删除 | 同 | 同 |
| 26 | `s0.home.pending.label` | `在「最近删除」中等待清空 %@` | `在「最近删除」中等待清空 {total}` | 占位符译写 |
| 27 | `s0.home.pending.passed` | `设备可用空间 +%@` | `设备可用空间 +{released}` | 占位符译写 |
| 28 | `s0.home.title` | 空间清理 | 空间清理 | 同 |
| 29 | `s0.tab.cleanup` | 空间清理 | 空间清理 | 同 |
| 30 | `s0.tab.organize` | 逐张整理 | 逐张整理 | 同 |

第十四节第 3 部分共登记 **82** 条 `s0.` key；本卡只登记骨架实际引用的 30 条。**不是漏登记**：`scan-hardcoded-user-visible-strings.ps1` 的 key 门禁是**双向** bijection，「目录存在未被产品源码引用的 key」同样判失败，故未用到的 52 条必须留给用到它们的那张卡（IC-148 及之后）。

**两处规格缺口（本卡按已登记文案处理，未自造）**：

1. SPEC-S0 v1 第三节第 3 部分要求 S0-3 有「副句说明已扫描的资产总数」，但第十四节第 3 部分**没有该副句的 key**。本卡复用已登记的 `s0.home.hero.progress`（「已扫描 N / M」），语义正是已扫描资产数，不自造措辞。
2. 第三节各态要求 `lim=真` 时显示受限提示条，第十四节第 3 部分**没有 `s0.` 受限提示条 key**（SPEC-S1 v9 有 `s1.limited.banner`）。骨架不画该提示条；`lim` 已作为状态变量承载（`S0StateMachine.isLimitedAuthorization`）。任务卡子项 C 的入口清单未含受限提示条，故不属本卡欠交。

---

## 八、G843／G844 闸门

### G843：diff 限于白名单

`git diff --stat main..f41add9` 仅三个既有文件 + 五个新增文件，无一越界：

```
PhotoCleanupMVE.xcodeproj/project.pbxproj    |  28 +
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift |  66 +-  (65 增 1 删)
PhotoCleanupMVE/Localizable.xcstrings        | 330 +
```

**九个不得触碰文件两侧 SHA-256 完全相同（零改动）**：

| 文件 | `main` 与 tip 的 SHA-256（同值） |
|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | `7a5913e45528ae2fa910667848fdc183033b531ac3b1ec0f76e909ae08172c7a` |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | `12bc93f1d3271ce7899bcef664f06e9c314fdaebbb850e1aac325e3291edbe91` |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f` |
| `PhotoCleanupMVE/Features/S3/S3View.swift` | `881d1c74472f3019d9cc2177e2c61d57668d30ebe0863395012cecd9e57b87ff` |
| `PhotoCleanupMVE/Features/S4/S4View.swift` | `91edeef270e6fd47f6b30ce53b7704471fb8170c35abf9d6f4e518c2ee12df37` |
| `PhotoCleanupMVE/Features/S5/S5View.swift` | `c37f6795d3e86644a4b555d7dcd2709b86e48ccd858eca3cac23c6abc15f4acf` |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | `9eca40ff4915761097307f58182ee654bcb5ddd02e6e45cf990448b6b557999d` |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | `b6c747919c10e91b6032b3d41556f9875f26a0fad9562b68fd53a91cec7e6cd3` |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | `90ddffad6ab737bbe00ea1c1cb1cb402503949c45cb5080e55b483a248dfe032` |

**`App/PhotoCleanupMVEApp.swift` 的 diff hunk 清单**（全部落在 E1 那一个分支与新增 builder／E3）：

| hunk | 内容 |
|---|---|
| `@@ -5,6 +5,16 @@` | 新增 `@StateObject s0Machine`、`@StateObject s0TabSelection`、`private let s0DataProvider` |
| `@@ -31,4 +41,41 @@` | 新增两个 builder `tabContainer(s1Machine:)`、`s0Screen()`（陷阱 16） |
| `@@ -162,5 +209,5 @@` | E1 的 `.s1, .upstream, .finished` 分支：`s1Screen(machine: machine)` → `tabContainer(s1Machine: machine)`（对路由 switch 的唯一改动行） |
| `@@ -189,4 +236,5 @@` | `.onChange(of: scenePhase)` 的 `.active` 追加 `restoreS0Foreground()`（E3） |
| `@@ -197,3 +245,19 @@` | 新增 `restoreS0Foreground()` |

`s2Screen(machine:)`、`s1Screen(machine:)`、`.onAppear` 启动守卫与 `.s2`／`.confirmation`／`.execution`／`.completion` 四个分支**一字未动**，由 `testIC147AAssertion03RouteBranchesOtherThanS1AreByteIdentical` 以逐字串源码扫描钉住（本机模拟实测各命中 1 次）。

### G844

| 项 | 结果 |
|---|---|
| `S2Calibration.swift` 在 diff 中 | **否**（两侧 SHA-256 相同，见上表） |
| `S2CalibrationConfiguration.schemaVersion` | **7**（未改；本卡未新增任何标定字段） |
| `Features/S0/` 内 PhotoKit 符号命中 | **0**（`PHAsset`／`PHAssetResource`／`PHImageManager`／`PHPhotoLibrary`／`import Photos` 全为 0，剔注释后扫描；正对照 `AssetSizeScanner.swift` 命中 `PHAsset` 26 次、`import Photos` 1 次） |
| 冻结三链与两条探针分支 | 未触碰（本卡只新建并推送 `feature/ic-147-s0-behavior-layer` 一条分支） |

### pbxproj 登记核验

加登记前重扫的各族最大 id：fileRef `…046`、buildFile `…043`、group `…00D`；新占用 fileRef `…047`～`…04B`、buildFile `…044`～`…048`、group `…00E`。登记后：**五个新文件各恰 4 处命中**（`grep -c` 行计），**对象定义行无重复 id**。

```
S0StateMachine.swift             4
S0TabContainer.swift             4
S0View.swift                     4
S0CleanupDataStub.swift          4
IC147S0BehaviorTests.swift       4
```

---

## 九、人工判定项（H70，留给 Lynn 合并后真机，执行端不代为下结论）

1. 开屏后落在「空间清理」，底部两个 tab，名字是「空间清理」与「逐张整理」。
2. 两个 tab 来回切十次：S1 里已展开的年节点、当前排序、待删篮数字都不变；进过 S2 再回来也不变。
3. 「空间清理」里能看出当前是哪个态（骨架是纯文字，不好看是预期的），四个入口都点得到。
4. 从「逐张整理」进 S2、进 S3，行为与 IC-146 后完全一致；从 S3 返回仍回到「逐张整理」。
5. **S1 的顶排三件 chrome 与 tab bar 并存，观感不是最终态**——这是已知的临时状态，不是缺陷，下一张卡换装。只需确认功能不受影响。

**以上五条一律保留给 Lynn 真机判定，执行端不代为下结论。**

判定第 3 条时请注意两处已知的骨架限制（详见第十节）：**人像圆钮点了不会弹出账户 sheet**（账户页属后续批次，本卡只交按钮与状态位）；**待删篮胶囊的体积位会读出零**（真实体积要等批次 5.1 的扫描服务）。

---

## 十、发现但未处理的问题

按纪律只报告不修。前五条是审查中确认为真、但处理权不在本卡的；第 6～8 条是规格自身的矛盾或缺口，需决策会话裁定。

1. **SPEC-S0 v1 第十四节没有 tab 图标登记项，任务卡称其已登记——假设被实测推翻（纪律 3）。** 第十四节第 2 部分只登记 `S0Ambient`／`S0SegmentBar`／`S0CategoryRow` 三族，第 3 部分只有两个 tab 名。本卡按任务卡的语义描述（容量条／卡片上下滑）自填了两枚系统符号 `internaldrive`／`rectangle.stack`，集中在 `S0TabSymbol` 一个 enum 内，并在 change-list 的占位值登记节按登记制记明。**这违反「视觉取值不得由实现自行填值」**，但停整张卡去等一个图标登记与卡内其余十三条断言的产出不相称，故选择交付 + 显式挂账。`rectangle.stack` 与「卡片上下滑」的对应关系尤其弱。**请决策会话补登记，IC-148 视觉层按登记值替换。**

2. **人像圆钮与 `Q` 在产品路径上未接线。** SPEC-S0 v1 第三节四态的可用操作都写「点击人像圆钮：`Q=呈现`，打开账户 sheet」，但账户页本身属后续批次，任务卡的授权白名单内没有它。因此：`setObscuring(_:)` 的调用点只有测试两处，产品侧为零；App 入口的 `s0Screen()` 未传 `onOpenAccountSheet`，圆钮走默认空闭包。**后果**：第五节矩阵唯一跨全表的守卫（`accepts` 开头的 `guard obscuring == .closed`）在真机上恒真，断言 6 的遮挡部分**纯夹具驱动、真机零覆盖**；圆钮在骨架里是个可点但无动作的按钮（H70 第 3 条会看到）。

3. **待删篮胶囊的体积位无真实来源。** 胶囊显隐已按规格（`D_全部` 非空且非 S0-4），张数取会话层真值（`s1Machine.badgeCount`，与「逐张整理」同一个 `D_全部`）；但体积位来自数据源，而真实扫描服务排批次 5.1，本卡注入的桩回报零，真机上会读出「N · 零字节」。措辞口径没有越界（仍是「待删篮 N 项 · X GB」那一条），但**数字不可信**，不得据此判定六个数字口径已落实。

4. **待删篮胶囊点击不导航到 S3。** SPEC-S0 v1 第十节第 3 部分要求 S0 → S3 的交接与 SPEC-S1 v9 第七节第 3 部分**完全相同**、S0 不另造提交路径；而既有提交路径在 `CleanupCoordinator`（本卡列为不得触碰其路由语义）。故 `s0Screen()` 未传 `onEnterConfirmation`，状态机只判定落点为 `.confirmation` 并回报。迁移表第 6、8 行的附带效果（决策 30 对账、`M`／`F` 交集更新）同理未接线，已在第三节对账表逐格标注。

5. **胶囊张数不是可观察状态。** `mergedPendingDeletionCountProvider` 是普通存储闭包、不是 `@Published`，而 `S0View` 只观察 `S0StateMachine`。「逐张整理」侧改变 `D_全部` 不会让 S0 的 body 失效，胶囊张数可能读出陈旧值，直到别的发布顺带重绘。真正接线（批次 5.1+）时应改为会话层把 `D_全部` 计数推成 `@Published`，或让 S0View 一并观察 S1 状态机。

6. **第五节矩阵第 1 行的 S0-1 格与第三节第 1 部分两处清单措辞不自洽。** 矩阵写「已完成统计的可点」；第三节可用操作写「点击任一**已完成统计**的类别行：进入该类别页（**其内容为当前已扫出的子集**）」——括注暗示该类别仍在扫；禁用清单只列「尚未开始识别的类别行（重复、相似）」。三处合起来读不出唯一口径。本实现取「已开始统计即可点」（`recognition != .awaitingScanCompletion`），理由是它同时满足括注与禁用清单；断言 6 把该读法钉死了。**请决策会话裁定 `.counting` 在 S0-1 是否可点**，裁定后可能需要同步改断言 6 的期望值。

7. **`VF≠无` 的可达条件与核对通过的附带效果在规格内互相抵触。** 第二节第 1 部分写「`VF≠无` 只在 `LG=非空` 时可达」，第四节第 9 行又写核对通过「账本清零、`LG=空`」——通过之后即 `VF=已通过` 且 `LG=空`。本实现按「**进入** `VF≠无` 需要 `LG=非空`，通过后账本清零而已通过的读数仍要显示（文案 key `s0.home.pending.passed` 即为此）」落实，属③推测，已在 `S0VerificationState` 的注释内标注。**请决策会话确认该读法。**

8. **`VF` 没有回到 `无` 的路径（除「打开应用」）。** 核对通过或未通过后，`VF` 停在 `.passed`／`.failed`，第四节没有任何一行把它复位。若「已通过」读数应当在若干秒后或下次进入首页时消失，那条迁移尚未定义——归批次 5.3 的核对流程本体，在此挂账。

9. **tab 容器抬高了底部安全区，S1 的反馈 toast 随之上移。** S1 的 `feedbackToastOverlay` 以 `.padding(.bottom, S2OverlayLayout.bottomRowBottomInset)`（出厂 8）锚在安全区底缘；装进 `TabView` 后安全区底缘上移了一个 tab bar 高度，toast 的视觉落点因此整体上移同样距离。这是容器引入的**真实几何变化**，不是 S1 的缺陷；按纪律 1／4 未改 S1 一行，也未为观感调整容器。S1 的 `ScrollView` 同样会自动吃进 tab bar 的底部 inset，`LazyVStack` 上的 `.padding(.bottom, S1RangeCardMetrics.cardSpacing)` 不再是唯一的底部余量。**IC-149 顶排换装时请一并复核底部。**

10. **`Localizable.xcstrings` 的双向门禁决定了 `s0.` 文案只能分卡登记。** 第十四节第 3 部分的 82 条里本卡只登记 30 条，不是漏登；任何一张后续 S0 卡新增 key 时必须同时新增引用，否则 `scan-hardcoded-user-visible-strings.ps1` 会以「目录存在未被产品源码引用的 key」判失败。写卡时请按「该卡实际会引用的 key」开范围，不要整节一次性登记。

11. **既有用例 `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 计时脆弱，本次首跑被它判红。** 它自建 `UIWindow` 挂到真实 window scene、驱动 `RunLoop.main` 采真实动画中间帧，2 秒挂载期限 + 10 秒导出期限，要求双击进出 Nx 的中间帧各 ≥3／≥5。#291 上 3.923 秒走完，本卡 #292 attempt 1 上超过 10 秒仍在导出，并致测试宿主被杀、整段重启（详见第五节第 2 部分）。同提交复跑即绿。**本卡未改它一行，也不建议在本卡改**——放宽期限或改判据都会动到 IC-063／IC-104／IC-114／IC-115 四张卡共用的诊断靶。建议决策会话另开一张卡评估：要么把期限做成与 runner 负载无关的判据，要么把它标为已知脆弱点并约定「红了先复跑同一提交做对照」。

12. **`ci.yml` 的「XCTest 执行摘要」notice 在崩溃重启的运行上会偏绿。** 详见第五节第 3 部分：`tail -n 1` 取到的是重启后第二段的小计，attempt 1 因此挂了一条 `Executed 401 tests, with 0 failures` 的摘要在一次 exit 65 的红运行上。**判红判绿不受影响**（真实退出码原样传出，IC-125 哨兵未被绕过），但**项数与失败数不可直接引用该 notice**。本卡未改 `ci.yml`（不在白名单）。

---

## 十一、全部 40 位 SHA 的存在性核验

报告与 change-list 内出现的每个 40 位提交 SHA，逐个跑 `git cat-file -e <sha>^{commit}`（陷阱 15：40 位 SHA 不得凭短前缀补全）：

| SHA | 身份 | `git cat-file -e` |
|---|---|---|
| `dc1d0f0f9f7d59f5617b2b857f52520a2a43e98a` | 继承提交（`main`，IC-146 报告提交） | **exit 0**（存在） |
| `d753fc5a31f5e7e2760b88d1ab842949de5a80bc` | IC-146 merge 提交（祖先核对用） | **exit 0**（存在） |
| `de9de132e521c7d4c6dbe8c96ec5d61f316fad7f` | 本卡子项 A | **exit 0**（存在） |
| `31d91bc32018d72bb41095b3b0d70312c805a744` | 本卡子项 B | **exit 0**（存在） |
| `2c7e6ad8bbfc498d22e0c3e96423de34706448c4` | 本卡子项 C | **exit 0**（存在） |
| `f41add9cdd16b9402e6cb2a7df7b5f96f9b45713` | 本卡子项 D＝被测提交＝分支 tip | **exit 0**（存在） |

---

## 十二、G845 合并前置核对

| 条目 | 结果 |
|---|---|
| G843（diff 限白名单、九个文件零改动、App 入口 hunk 受限） | ✅ 见第八节 |
| G844（`S2Calibration.swift` 不在 diff、`schemaVersion` 7、`Features/S0/` PhotoKit 零命中、冻结链未动） | ✅ 见第八节 |
| 全部 XCTest 通过 | ✅ 777 项 0 失败 |
| 真实退出码 0 | ✅ 步骤 success + `XCTest 已全部通过` |
| 摘要 notice | ✅ `Executed 777 tests, with 0 failures` |
| iOS 26.2 / iPhone 16 | ✅ 目的地实证行见第五节 |
| IPA 登记 | ✅ 1494114 字节，SHA-256 `665a8849…a883c9` |
| 断言 1～13 逐条给函数名并在日志核 `passed` | ✅ 见第二节 |
| 迁移表行数与断言数对账 | ✅ 13 : 13，见第三节 |
| 工作树净 | ✅ `git status --porcelain` 仅有未跟踪的 `Reports/IC-147/`（本卡报告，随后以 docs 提交入库） |
| `main` 未被他人推进 | ✅ `git ls-remote origin refs/heads/main` = `dc1d0f0f9f7d59f5617b2b857f52520a2a43e98a`，与继承提交一致 |
