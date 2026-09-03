# IC-122 自验报告：XCTest 切 iOS 26 模拟器——**目的地选型生效，暴露真实运行时行为差异，红，停卡**

## 结论（先行）

**覆盖缺口按卡内定义已关闭：CI 现在真正跑在 iOS 26.2 模拟器上。** `Scripts/test-xcode.sh`
新目的地选择逻辑生效（①实证）：脚本自打印
`使用 iPhone 模拟器：iPhone 16 (id=1556EED5-50E7-4F02-96D3-13F8A52A4EE5)`；
`xcrun simctl list devices available` 该次运行日志中，该 UDID 精确落在
`-- iOS 26.2 --` 区块内（该 runner 同时装有 iOS 26.0 / 26.1 / 26.2 三个运行时，
脚本按「最高 26.x」规则选中了 26.2，符合卡内要求）。

**但该运行时下暴露了 2 项真实断言失败**（1 个测试函数），**593 项执行、2 失败
（0 unexpected）、真实退出码 65**。按卡内第 5 条纪律：**一项都不修**，
分类见下，写全报告停卡——**处置留给决策会话**。这正是卡内前言所说
「发现差异是本卡的成功，不是失败」的情形。

**预算 2 次 CI 已用尽，不再发起第 3 次**：

- 第 1 次（CI #238，run 33659126364）：**假绿**，非有效验证——见下「意外发现」，
  本卡自身新增诊断行触发 runner 系统 bash 的一个解析缺陷，XCTest 实际一次都没跑，
  但该步骤仍以 exit 0 收场，job 整体绿并构建上传了 IPA。已确认根因、在本卡授权
  文件内修正（新 commit，非 amend），未消耗到「网络/runner 偶发重试」的名义，
  但确实占用了卡内 2 次预算中的第 1 次。
- 第 2 次（CI #239，run 33660839328）：**真实结果**，见上面结论与下面分类。

- **G310 通过**：两次 commit 的 diff 均只碰 `Scripts/test-xcode.sh` 一个文件
  （①，`git diff --stat main feature/ic-122-ios26-simulator` 仅列出该文件）。
- **G311**：红时要求「分类报告完整、零修复」——达成，见「失败分类」节；
  未做任何一处修复性改动（本报告写作本身不算修复）。
- **G312 通过**：产品代码、测试代码、`ci.yml`、登记值、冻结三链均零改动
  （①，`git diff main feature/ic-122-ios26-simulator` 只含 `Scripts/test-xcode.sh`）；
  冻结三链 tip 逐一 `git rev-parse` 核对未变（`b368a6c` / `6736f1e` / `a7cc1ec`）；
  `S2CalibrationConfiguration.schemaVersion` 仍为唯一定义、值 **7**（①grep 实测）。

## 输入与范围

- 输入：`IC-20260831-122-ios26-simulator.md`。
- 基线（如实核对）：卡内写「`main` = `f71faae`（IC-119 报告提交）」；开工时 `main`
  实际已前移到 `2018dd5`（IC-124 合并 IC-123 入 main 的 docs 提交，`f71faae` 仍是
  其祖先，`git merge-base --is-ancestor f71faae main` 为真，①实测）——纯属卡内
  编写时点与执行时点之间 `main` 被 IC-124 正常推进所致，非任何人异常操作。
  按 CLAUDE.md 第七节「新卡一律从 `main` 当前基线切分支，除非任务卡另有说明」的
  一般规则，从**当前** `main`（`2018dd5`）切出分支，如实记为偏差（见下）。
- 目标分支：`feature/ic-122-ios26-simulator`，自 `main`（`2018dd5`）切出；未合并。
- 范围边界遵守：只改 `Scripts/test-xcode.sh`；未改产品代码、测试代码、`ci.yml`、
  探针阈值；未 rebase / amend / force push；`main` 未合并、未推进。

## 执行记录（顺序按卡）

1. 开工检查：工作树净；确认 `main` 基线偏差（上节），按通用规则从当前 `main` 切分支。
2. 修改 `Scripts/test-xcode.sh` 目的地选择逻辑：改用 `xcrun simctl list devices
   available -j` 的实存设备列表（不再用 `xcodebuild -showdestinations` 的第一条
   iPhone 命中，那恰好稳定落在 iOS 18.5）；用 `jq` 按 SimRuntime 标识
   （`com.apple.CoreSimulator.SimRuntime.iOS-26-<minor>`）筛出 iOS 26.x 运行时，
   取其中 minor 数值最高的一个，在该运行时下选一台 `isAvailable` 且名称含
   「iPhone」的设备的 UDID 作为目的地；找不到则显式打印完整可用列表并 `exit 1`，
   不静默回落。提交 `97ff440`。
3. 推送首次，CI **#238**（run 33659126364）——见「意外发现」，假绿，未构成有效
   验证。修正脚本内一处诊断行的字符邻接问题，提交 `51deb3a`。
4. 再次推送，CI **#239**（run 33660839328）——真实结果：593/2，退出码 65。
5. 预算 2 次已用尽，按卡内纪律停卡，写本报告与 change-list，**不合并 `main`**，
   分支保留。

## 意外发现：第 1 次 CI（#238）为假绿，XCTest 实际未执行（①实测）

**现象**：`运行 XCTest` 步骤 conclusion = `success`，耗时 < 1 秒（正常需 4～8 分钟），
后续「构建未签名应用」「上传可下载的未签名 IPA」两步均正常执行并成功；
但该次 check-run 的 annotations 中**没有**「XCTest 执行摘要」这条 notice
（对照：#237、#239 均有该 notice），job 日志里也找不到任何
`Executed N tests` 行——即 **XCTest 一次都没有被执行**。

**根因（①，日志实证 + 源码核对）**：
1. 脚本 `line 50` 原文：`echo "使用 iPhone 模拟器：$destination_name（id=$destination_id）"`。
   `$destination_name` 后紧跟全角左括号「（」（UTF-8 字节 `EF BC 88`）。
2. Runner 日志精确显示：`Scripts/test-xcode.sh: line 50: destination_name<损坏字节>:
   unbound variable`——即该 runner 上执行该脚本的系统 `bash`（`DEVELOPER_DIR` 指向
   `Xcode_26.3.0.app`，但脚本本身走的是系统 `/bin/bash`，macOS 上这是不随 Xcode
   升级的旧版 bash）在 `set -u` 下，把「（」的某个字节误判成了合法的标识符延续
   字节，将 `destination_name（` 当成了**一个不存在的变量名**整体去引用，触发
   「unbound variable」，脚本随即崩溃退出（在真正打印出选中的模拟器、执行
   `xcodebuild test` 之前）。
3. 对照：同一文件里旧有的 `echo "使用 iPhone 模拟器：$destination_id"`
   （`$destination_id` 后直接是英文双引号 `"`，无歧义字符紧邻）在此前所有历史
   CI 运行（含 #237）中从未出现过这个问题——问题字符是「（」而非中文标点本身
   （旧代码里的全角冒号「：」在变量前，不在变量后紧邻，不构成同类风险）。
4. **未查明的部分（如实，未硬套）**：崩溃发生在 `if bash Scripts/test-xcode.sh
   2>&1 | tee "$test_log"; then ... else test_status=$?; fi` 的管道条件内部；
   `ci.yml` 该步骤显式 `set -o pipefail`，按常规语义管道状态应取非零，
   `test_status` 应为非零，`exit "$test_status"` 应让该步骤失败。但实测该步骤
   最终仍以 0 退出。哪一层（`pipefail` 在该 runner 系统 bash 版本下的具体行为、
   还是 `tee` 与子 shell 退出码传递的其他细节）导致非零状态未被 `test_status`
   捕获到，**本卡未查明具体机制**，只确认了触发条件与后果。这意味着
   `ci.yml` 现有的「靠 `test_status` 判定真实退出码」这套机制，在「XCTest 脚本
   自身在产出任何测试输出之前就异常崩溃」这一特定路径下，**存在使 CI 误报绿的
   可能**，具备一般性影响（不止本卡这一次诱因）。已记入「发现但未处理」，
   建议决策会话评估是否需要在该步骤加一道独立哨兵（比如显式校验
   `test_log` 中确实出现过 `Executed [0-9]+ tests` 行，否则即便 `test_status`
   为 0 也判失败）。
5. **修正**（在本卡授权范围内，仅改 `Scripts/test-xcode.sh` 目的地选择相关的这
   一行诊断输出）：把该行改为
   `echo "使用 iPhone 模拟器：${destination_name} (id=${destination_id})"`——
   用 `${}` 花括号显式界定变量名边界，并把两个全角括号换成 ASCII 半角括号，
   彻底消除边界歧义；未改选型算法本身。提交 `51deb3a`，CI #239 验证该问题不再
   出现（该次「XCTest 执行摘要」notice 正常出现，593 项确实被执行）。

## 失败分类（#239，593/2，退出码 65；卡内第 5 条要求，一项都不修）

**唯一失败测试**：`S2CalibrationHarnessTests.testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`
（3.069 秒，2 处断言失败，均在同一测试函数内）。

| 分类 | 判定 | 依据 |
|---|---|---|
| 编译 | **排除** | 591/593 项在同一次构建产物上全部通过；本测试文件其余用例、其余 22 个测试套件（`AlbumScopeWiringTests` 起至 `VolumeFormattingTests` 止）全部 0 失败；无编译期错误行，`xcodebuild` 未报 `error:`（Swift 编译层面）。 |
| 基建 | **排除** | 目的地选择、模拟器启动、593 项全量执行、总耗时（40.991 (127.557) 秒）均在合理范围，无超时、无 runner 级错误；iOS 26.2 运行时确认存在且被正确选中。 |
| 像素探针渲染差异 | **不适用** | 该测试断言的是导出的诊断**文本报告**中特定子串出现的次数/是否存在，不涉及任何像素截屏或颜色采样比较。 |
| **iOS 26 行为差异（运行时动画帧节奏）** | **最符合** | 见下「实测细节」——两处断言均与「双击进入 Nx 缩放过渡期间捕获到的动画中间帧数量」直接相关，是运行时真实产生的采样数量差异，不是产品几何计算错误。 |

**实测细节（①，日志原文）**：

1. `S2CalibrationHarnessTests.swift:4140`：`XCTAssertTrue(report.contains("中间帧门禁：通过"))`
   失败——导出报告文本中未出现「中间帧门禁：通过」这一标记（③推测：门禁判定
   逻辑本身就是「中间帧数量达标与否」的产物，此条大概率与下一条同因，未单独
   验证是否为独立成因，如实标注未排除）。
2. `S2CalibrationHarnessTests.swift:4145`：
   `XCTAssertGreaterThanOrEqual(report.components(separatedBy: "双击进入 Nx：动画中间帧").count - 1, 3)`
   失败，实测值 `1 < 3`——即「双击进入 Nx」这段缩放过渡动画期间，诊断协调器
   只捕获到 **1** 个中间帧样本，而门禁要求至少 **3** 个。
3. **非对称信号**（①）：紧接着第 4149～4152 行「双击退出 Nx：动画中间帧」的
   同类断言（要求 ≥ 5）**没有出现在失败列表中**，即退出方向的中间帧采样数量
   达标，只有进入方向不足。这排除了「diagnostics 协调器整体失效」这类粗粒度
   假设，指向更细的时序差异（③推测，未继续深挖机制——按纪律不修不深究，
   留给决策会话判断是否值得立探针复测）。
4. 该测试通过 `RunLoop.main.run(until:)` 反复推进主 run loop、
   `diagnostics.export()` 主动轮询的方式驱动整个流程（非用 `sleep`），采样本身
   依赖真实的动画回调节奏（③推测，未读 `S2GeometryDiagnosticsCoordinator` /
   过渡驱动的具体实现细节以确认是否为 `CADisplayLink`——按纪律停在分类，
   不做代码追查）。iOS 26.2 与此前 iOS 18.5 之间，模拟器本身的宿主机调度、
   渲染合成层行为、或该次 CI 运行的 runner 负载差异，均可能是「同一段固定
   等待窗口内实际捕获到的帧数变少」的候选原因（③，均未验证，如实并列，
   不做取舍）。

## CI 与本地门禁数据（①）

| 项 | 第 1 次（#238，假绿） | 第 2 次（#239，真实结果） |
|---|---|---|
| Run | 33659126364 | 33660839328 |
| 被测提交 | `97ff440d1c4805771811f2d3861e481d4f054759` | `51deb3a192b7d25e4a189427c8c292084c91d063` |
| Job 结论 | success（**假绿，见上**） | **failure** |
| 「运行 XCTest」步骤 | success，< 1 秒，**0 项被执行** | failure，7 分 11 秒，593 项执行 |
| XCTest | 无「执行摘要」notice（未执行） | **593 项，2 失败，0 unexpected**，`in 40.991 (127.557) seconds` |
| 真实退出码 | 0（异常，见上） | **65**（`Process completed with exit code 65`） |
| 选中模拟器 | 未打印成功（崩溃于打印前） | `iPhone 16`，UDID `1556EED5-50E7-4F02-96D3-13F8A52A4EE5`，**iOS 26.2**（①，`simctl list` 该 UDID 精确落在 `-- iOS 26.2 --` 区块） |
| IPA | 构建并上传（1060791 字节，异常，见上——**不应视为有效产物**，因测试实际未跑） | 未构建（`构建未签名应用`/`上传可下载的未签名 IPA` 两步均 `skipped`，因前置步骤失败，符合预期） |

本地门禁：本卡产品/测试代码零改动，未跑构建类门禁；`git diff --check` 干净
（退出码 0）；`bash -n Scripts/test-xcode.sh` 两次改动后均语法通过。

## 人工判定项

无——本卡未产生任何面向真机的行为变更，`main` 未合并，无需要 Lynn 真机判定的项。

## 停线 / 偏差

### 停线
**触发**：卡内预算 2 次 CI 已用尽（第 1 次因本卡自身脚本 bug 未获得有效验证，
第 2 次为真实红）。按卡内第 5 条与「三次尝试上限」的通用纪律，停止在此，
不发起第 3 次运行，不做任何修复性改动。

### 偏差（如实）
1. 卡内「基线」一节写 `main` = `f71faae`，开工时 `main` 实际已被 IC-124 推进到
   `2018dd5`（`f71faae` 仍是其祖先）。按 CLAUDE.md 通用规则从当前 `main` 切出，
   已在「输入与范围」节说明；这不改变本卡的任何验收内容（本卡不合并
   `main`、`main` 上的内容对本卡范围无影响）。
2. 卡内「结论」预期给的历史基数是「586 项」，实际当前 `main`（含 IC-110～124）
   基线已是 **593 项**（IC-119 合并时 586 → IC-123/124 合并后 593，均已在各自
   报告登记）。本报告按实际值 593 记录，非篡改或凑数。
3. 目的地选择在同一 iOS 26.2 运行时下，实际选中的是 `iPhone 16`，而非该运行时
   设备列表中排序更靠前的 `iPhone 17 Pro` 等新机型——卡内只要求「优先 iOS 26.x
   运行时」，未规定运行时内部的机型优先级，脚本按 `simctl` JSON 原始设备顺序取
   第一个可用的「iPhone」即可满足卡面字义，如实记录，未按可能更优的「最新机型」
   语义自行加码（这属于产品/方法学判断，非本卡范围）。

### 发现但未处理的问题（按纪律只报告不修）
1. **`ci.yml` 「运行 XCTest」步骤在脚本崩溃于测试执行之前发生时，退出码判定路径
   可能不可靠**——见「意外发现」一节完整描述。这是超出本卡「仅动目的地选择
   逻辑」授权范围的 `ci.yml` 层面问题，具备一般性（不局限于本卡引入的 bug），
   建议决策会话另立卡处理（例如在该步骤追加「必须能在 `test_log` 中找到
   `Executed [0-9]+ tests` 行，否则即使退出码为 0 也判失败」的哨兵校验）。
2. **`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 在 iOS 26.2
   模拟器下两处断言失败**——本报告「失败分类」一节完整登记，分类为运行时动画
   中间帧采样数量差异（③推测），具体是否要调整探针容差、还是产品动画时序需要
   适配 iOS 26、还是这套采样断言本身需要改造得对时序更鲁棒，均属决策会话裁定
   范围，本卡未做任何取舍或修复。
3. 本卡两次 CI（#238 假绿、#239 真实红）均未产出可用于 H 类判定的 IPA
   （#238 的 IPA 因测试未真正执行而不具备验证意义；#239 未构建 IPA）——
   本卡不产出可交付的 H56 类判定包，属预期（红卡本就停在报告）。

## 报告提交

`Reports/IC-122/` 以 docs 提交追加在同卡同分支 `feature/ic-122-ios26-simulator`
（报告需引用推送后才产生的 #238/#239 运行编号，属 CLAUDE.md 第二节第 7 条允许
的追加 docs 提交方式）。`main` 未合并、未推进，命中 `paths-ignore` 的这次 docs
提交本身不触发新的 CI，属预期；验证产品代码变更的运行为 **#238**（假绿，见上，
不构成有效验证）与 **#239**（真实结果，593/2，退出码 65）。分支保留不删。
