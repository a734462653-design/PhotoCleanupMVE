# IC-193 自验报告

## 一、结论（先行）

- **两个子项全部按卡面完成（逐字节拷入 `ic193/stages/`，未手改一行），G1060～G1064 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-193-v1-deck`：A `eef0a70dcd64ee48febab156ba5a3ee94ac4ca19` → B `01aa3e618b62415689ca22f9ca8efc44dc0bf49a`。
- 分支 CI **#390**（run `37950521036`，被测提交 B `01aa3e618b62415689ca22f9ca8efc44dc0bf49a`）一次绿：**972 项 0 失败**（971 − 3 + 4），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 2030459 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76`（双亲 `387efda74c0873333186094905bafc3e07b24018`／`01aa3e618b62415689ca22f9ca8efc44dc0bf49a`，树 `05103758f075e9aafcf7a9272fd729534b790166` 与 B 提交的树相同）。合并后 `main` CI **#391**（run `37952568535`）绿：972 项 0 失败，artifact `PhotoCleanupMVE-unsigned-52e977e1af5c`（id `11627960149`，有效期至 2027-01-07T15:33:02Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 6 个、B 2 个）、卡面 A「改后」计数与工作树实测逐条相等（41 条检查，0 处不符）；提交后 `check_ic193.py` A／B 两个 tip 全 PASS（8／8、10／10）。
- **有界面变化**：「逐张整理」tab 的列表页年卡叠（与相册卡）与年页标题区、月卡叠整体换成 V1，人工判定项 H101 九条保留给 Lynn（第十四节），本报告不对观感下结论。
- 本次没有停卡项，没有执行端偏离卡面的改动，没有被分类器拦截，没有中途中断，没有任何一次 CI 红。红因清单 (1) 点名的编译风险（`Circle().inset(by:).trim(...)`、result builder 里的 `if`、`@ObservedObject` 成员、类型检查超时）一项都没触发：两次整包日志里没有任何一条 warning 或 error 指向 `S1DeckCards.swift`／`S1YearPageView.swift`／`S1View.swift` 或本卡改动的测试文件。
- 网络波动（均非权限拒绝）：`git push origin main` 第一次报 `schannel: failed to receive handshake`（`main` 未变），原命令重试一次即成功（`387efda..52e977e`）；合并后核对被保护分支时 `git ls-remote --heads origin` 前两次同样 `schannel` 失败、第三次返回 112 行才做比对（空列表没有当作比对）。
- `materialize_ic193.py` 未跑（明令不跑）；`sim_ic193.py` 对基线跑了一次（加了 `IC193_GATES=1` `IC193_CLONE=1`，`FAILURES 0 []`，见第五节），它按约定重写了 `decision-tools/sim193/`（明令的唯一例外）；除此之外 `Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（`check_ic193.py`、`sim_ic193.py`、本卡的 `strip.py` 导入一律 `python -B` 或 `sys.dont_write_bytecode`，无 `__pycache__`）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-193-v1-deck.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-193.md`；调研 `Tasks/RESEARCH-S1R-3c-deck-facts.md`；裁定 `Tasks/PLAN-S1R-3-rulings-20261009.md`（第三、六节）；复核结论 `Tasks/REVIEW-IC-193-findings.md` 第四、五节（处置与第二轮；复核员的「建议改法」不是执行指令，改法以卡与 `stages/` 为准）。
- 基线 `main` = `387efda74c0873333186094905bafc3e07b24018`（IC-192 报告补记；合并提交 `d8c10e312f700ac35defb5c8d7efecc363b2785b`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor d8c10e312f700ac35defb5c8d7efecc363b2785b main` 退出码 0；`git ls-remote origin refs/heads/main` = `387efda74c0873333186094905bafc3e07b24018`（与本地一致）；被改 7 个文件基线 blob 与卡面表逐一相等（下表，`git hash-object` 读法）；**先切分支再改文件**（`git checkout -b feature/ic-193-v1-deck`，此前本卡分支在本地与远端均不存在）。

| 路径 | 卡面基线 blob | 实测 |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `45f115fe4bb6fd4a5398f9def3c89e7bfde7cca2` | 相等 |
| `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | `09caecb79813ae1bafa9ac2608bb353d4575aaa0` | 相等 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | `b8261fa8d28014290f4852aa6ae3155debc3917c` | 相等 |
| `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | `4d0cc41734542555bfbb0171c43eb338c72db093` | 相等 |
| `PhotoCleanupMVE/Localizable.xcstrings` | `855e9d34764d1465f242d68a6a5cae7b1825c4b2` | 相等 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | `ba9ac874cd5f89ee4481271731151a1120c7ca76` | 相等 |
| `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | `c26011857d2c7788a2300dc12754fe61cc8bf0e4` | 相等 |

- 范围边界：只做卡「本卡边界」两项（A 两只 S1 文件整文件重写 + `S1View.swift` 列表与年页两处接线 + 目录 +6／−1 + 两个既有测试随改；B 新测试 + pbx 测试登记）。状态机、协调器、App 入口、页头 `S1PageHeader.swift`、S0 各页与 `S0DeckCoverView`、`S1View.swift` 其余段、`Scripts/`、`.github/`、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）一字未动；`git diff --name-only 387efda74c0873333186094905bafc3e07b24018..01aa3e618b62415689ca22f9ca8efc44dc0bf49a` 恰 8 路径，全在白名单内。
- 改法实施方式：`cp -r Tasks/decision-tools/ic193/stages/<子项>/. <repo>/`，每个子项拷入后对清单里该子项每个文件跑 `git hash-object`（读 `manifest.json` 与工作树的只读脚本），全部相等才逐个 `git add <路径>`（不用 `-A`）与提交；`git status --porcelain` 在 `add` 之前恰列该子项的文件（A 6 个 `M`；B 1 个 `M` + 1 个 `??`）。`ic193/whole/`、`ic193/*.py`、`ic193/*.swift` 源料没有拷、没有跑。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `eef0a70dcd64ee48febab156ba5a3ee94ac4ca19` | `6107e11aeb6d297e21a783cc35d957c1b23e02f4` | V1 卡片叠与年页标题区：`S1DeckCards.swift` 整文件重写（V1 登记值 98 个、已看小圆环、收起一行／展开卡、观察展开态的卡叠 `S1DeckListView`）、`S1YearPageView.swift` 整文件重写（V1 标题区、月卡叠走同一只卡叠视图）、`S1View.swift` 列表与年页两处接线、目录 +6／−1、`IC178DeckListTests`（整删三条、精简一条）与 `IC192PageHeaderTests`（两个 needle）随改（6 个文件，不动 pbx） |
| B | `01aa3e618b62415689ca22f9ca8efc44dc0bf49a` | `05103758f075e9aafcf7a9272fd729534b790166` | 新测试 `IC193V1DeckTests.swift`（四条，逐字节拷入，479 行）+ pbx 四行（2 个文件；依赖 A） |
| 合并 | `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76` | `05103758f075e9aafcf7a9272fd729534b790166` | `merge(IC-193): 「逐张整理」V1 卡片叠（年卡、相册卡、年页月卡同一套）与年页标题区——收起一行／恰一张展开、首页同一 spring、一只封面不重取；旧卡口径退役` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-193/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --numstat` 基线..B 恰 8 路径（1281 行增、536 行删）。分支推送一次成功（`git push -u origin feature/ic-193-v1-deck`，git 直连无需代理，无分类器拦截）；推 `main` 第二次尝试成功（第一次 `schannel` 握手失败，见第一节）。

## 四、逐子项提交前对读与拷入文件 `git hash-object`

脚本 `scratchpad/ic193-exec/count_a.py`：读工作树文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（`Tasks/decision-tools/strip.py` 只读导入），逐条数卡面「改后（剔注释）」段列出的计数，并解析目录 JSON 核键集；blob 对读用读 `manifest.json` 与 `git hash-object` 的只读脚本。每个子项都是提交前跑、全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic193.py` 又用 `git rev-parse <tip>:<路径>` 核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | `5eb8dccd513ca3e1f8318b06b68e6f5b0de22280` | `5eb8dccd513ca3e1f8318b06b68e6f5b0de22280` | 相等 |
| A | `PhotoCleanupMVE/Features/S1/S1View.swift` | `414f05a9bb883551185f2da78cd0b2569f8992c1` | `414f05a9bb883551185f2da78cd0b2569f8992c1` | 相等 |
| A | `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | `0402ea5fb043101a9ca38f296293399827a6422a` | `0402ea5fb043101a9ca38f296293399827a6422a` | 相等 |
| A | `PhotoCleanupMVE/Localizable.xcstrings` | `dad2c343364f5e89a32851c10408352aee3b4606` | `dad2c343364f5e89a32851c10408352aee3b4606` | 相等 |
| A | `PhotoCleanupMVETests/IC178DeckListTests.swift` | `bcc865086086041815dbfca19a2117b0d93cf32e` | `bcc865086086041815dbfca19a2117b0d93cf32e` | 相等 |
| A | `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | `a5ffe00d94eb1dc7c28581679a82774e3ebd0ba4` | `a5ffe00d94eb1dc7c28581679a82774e3ebd0ba4` | 相等 |
| B | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `0cdb6c0df6eda43e2ff4f4d91cc63ebcd4bf6d1b` | `0cdb6c0df6eda43e2ff4f4d91cc63ebcd4bf6d1b` | 相等 |
| B | `PhotoCleanupMVETests/IC193V1DeckTests.swift` | `00f117f0189155b81bc10d1683e3a014d0b55dfb` | `00f117f0189155b81bc10d1683e3a014d0b55dfb` | 相等 |

**子项 A「改后」计数（卡面 vs 工作树实测，提交前）**——41 条检查全相等（`count_a.py` 输出 `SUMMARY: 41 checks, 0 FAIL`，退出码 0）：

| 对象 | 计数项 | 卡面 | 实测 |
|---|---|---|---|
| `S1DeckCards.swift`（剔注释） | `S1DeckMetrics` 切片 `static let ` | 98 | 98 |
| 同上 | `S1DeckSymbol` 切片 `static let ` | 2 | 2 |
| 同上 | `S0DeckCoverView(` | 1 | 1 |
| 同上 | `height: S1DeckMetrics.openCardHeight` | 1 | 1 |
| 同上 | `.id(coverAssetID)` | 1 | 1 |
| 同上 | `.id(isOpen)` | 0 | 0 |
| 同上 | `@ObservedObject var openCards: S1OpenCardState` | 1 | 1 |
| 同上 | `withAnimation(S1DeckCardPresentation.expandAnimation)` | 1 | 1 |
| 同上 | `.offset(y: S1DeckCardPresentation.coverOffset(isOpen: isOpen))` | 1 | 1 |
| 同上 | `.transition(S1DeckCardPresentation.openContentTransition)` | 3 | 3 |
| 同上 | `S1ProgressLinePresentation.fillFraction(` | 2 | 2 |
| 同上 | `ScrollView`／`stackBottomPadding`／`S1DeckSymbol.done` | 各 0 | 各 0 |
| 同上（原文） | `Text("`／`return "` | 各 0 | 各 0 |
| 同上（原文） | `import ` | 1 | 1 |
| `S1YearPageView.swift`（剔注释） | `S1DeckListView(` | 1 | 1 |
| 同上 | `slot: .yearPage` | 1 | 1 |
| 同上 | `S1DeckStack(`／`GeometryReader` | 各 0 | 各 0 |
| 同上 | `S1DeckProgressBar(` | 1 | 1 |
| 同上 | `S1PageHeaderMetrics.chip` | 3 | 3 |
| `S1View.swift`（剔注释） | `openCards: machine.openCards` | 2 | 2 |
| 同上 | `slot: .list` | 1 | 1 |
| 同上 | `_ = machine.openListCard(row.id)` | 1 | 1 |
| 同上 | `_ = machine.openYearPageCard(row.id)` | 1 | 1 |
| 同上 | `onTap:` | 0 | 0 |
| 同上 | `enterRange(` | 4 | 4 |
| 同上 | `S1ChromeForeground.` | 17 | 17 |
| 同上 | `S0DeckMetrics.` | 7 | 7 |
| 全产品（剔注释，递归） | `@ObservedObject var openCards` | 1 | 1 |
| 目录 | 键数 | 289 | 289 |
| 同上 | 六条新 key 在（`s1.deck.new`／`s1.deck.new.open`／`s1.deck.share`／`s1.deck.action.yearPage`／`s1.deck.action.organize`／`s1.yearPage.share`） | 是 | 是 |
| 同上 | `s1.yearPage.summary` 不在 | 是 | 是 |
| 同上 | `s0.` 键数 | 41 | 41 |

子项 B 的卡面「改后」只有「XCTest 971 → 972；`git diff --name-only <基线>..<B>` 恰 8 路径」；提交前核了拷入 blob（上表）、pbx 撞号扫描（第十二节）、本地门禁（第六节）、`IC193V1DeckTests.swift` 恰 4 个 `func test`（`testIC193A_…`／`B_…`／`C_…`／`D_…`），以及 `IC178DeckListTests.swift` 的 `func testIC` 数基线 5 → 2（−3：A、C、E 整删，B、D 留）、`IC192PageHeaderTests.swift` 基线 4 → 4。

## 五、`check_ic193.py` 两段 SUMMARY 与 `sim_ic193.py`

`check_ic193.py` 在刚提交的 tip 上跑（基线取脚本默认值 `387efda`；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `eef0a70dcd64ee48febab156ba5a3ee94ac4ca19` | `SUMMARY 8 pass / 8`（blob 6 + `changed paths == whitelist (6)` + `base is ancestor`） | 0 |
| B | `01aa3e618b62415689ca22f9ca8efc44dc0bf49a` | `SUMMARY 10 pass / 10`（blob 8 + `changed paths == whitelist (8)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

另：我在 B 提交后顺手对 B tip 用 `docs` 段名跑过一次，得到 `SUMMARY 9 pass / 10`，唯一的 FAIL 是 `changed paths == whitelist (10)`（此刻还没有 `Reports/IC-193/` 两个文件）——这是预期，不是卡面 FAIL，也没有算进上表。

`python -B sim_ic193.py`（只对基线跑；`IC193_GATES=1 IC193_CLONE=1`）：`FAILURES 0 []`，331 条 `ok`；其中 `XCTest count base 971 after 972`、`pbx lines added 4`、`pbx duplicate ids []`、目录与产品源码引用键双向一致（`scanner: referenced keys exist []`、`keys referenced []`）、两个本地门禁脚本退出码 0、`cherry-pick A alone True`、`cherry-pick A B True`、`cherry-pick B alone (text-clean; compiles only after A) True`。输出存 `scratchpad/ic193-exec/sim193_exec.txt`。

## 六、本地门禁（两个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 用 `powershell -NoProfile -ExecutionPolicy Bypass -File …`（Windows PowerShell 5.1）在仓库根跑；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0（「结构自验通过」，扫描 135 个 .swift、70 个测试源文件） | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致」） | 0 |
| B | 0（扫描 71 个测试源文件，含新测试文件） | 0 | 0 |

## 七、验收门禁逐条（G1060～G1064）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1060 行为与落位 | 满足 | 第五节：`check_ic193.py` A、B 两个 tip 全 PASS |
| G1061 新断言与随改断言 | 满足 | CI #390 与 #391 的整包日志按唯一 Test Case 行数出 972 passed／0 failed；四条 `testIC193*` 全部 passed；`IC193V1DeckTests`、`IC178DeckListTests`、`IC192PageHeaderTests`、`IC177UnifiedBackgroundTests`、`IC183RetireRenderChainTests`、`IC184RetireCaliberEnumsTests`、`IC191DeckDataTests`、`IC165DeckFormalTests`、`IC148S0VisualTests`、`IC156CategoryPageTests`、`IC171CategoryPageTrioTests`、`IC172GlassAlwaysDarkTests` 十二个测试类在两次日志里各出现 `Test Suite '…' passed` |
| G1062 不回退 | 满足 | `IC178DeckListTests.testIC178B_YearPageIdentityLivesInMachineWithGuards`（#390 0.003 s）、`IC191DeckDataTests.testIC191C_OpenCardsFollowTheOpenRule`（0.002 s）、`FullFlowRoutingTests.testIC048_006S5ExitEndsSessionAndRebuildsS1Session`（0.019 s）在 #390 均 passed（#391 同） |
| G1063 合并前置 | 满足 | G1060～G1062 + CI #390 绿（见第八节：真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 2030459 字节与 SHA-256、分段耗时 notice；摘要 972 与 xcodebuild 小计 972 一致，无需按第 217 条第四节另核）+ 38 条被保护分支 tip 未变（第十一节）+ pbxproj 撞号扫描（第十二节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote origin refs/heads/main` 仍为 `387efda74c0873333186094905bafc3e07b24018`） |
| G1064 合并后 | 满足 | 合并后 `main` CI #391 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #390 | 合并后 `main` 运行 #391 |
|---|---|---|
| run id | `37950521036` | `37952568535` |
| 被测提交 | `01aa3e618b62415689ca22f9ca8efc44dc0bf49a` | `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76` |
| 触发 | push 到 `feature/ic-193-v1-deck` | push 到 `main` |
| 作业起止 | 2026-10-09T15:16:50Z～15:31:04Z | 2026-10-09T15:33:10Z～15:46:02Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 972 项，0 失败（xcodebuild `Executed 972 tests, with 0 failures (0 unexpected) in 52.282 (55.611) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 972 passed／0 failed） | 972 项，0 失败（`Executed 972 tests, with 0 failures (0 unexpected) in 52.168 (55.159) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 972 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 972 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 972 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`） | 0（同） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（`xcodebuild test … -destination "platform=iOS Simulator,id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8"`，按 id 钉死） | 同一行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2030459 字节，SHA-256 `1bfbec8c6926c1bfe319ca4ea8ea5759a79710dbe08a027637c29d83ee781780` | 2030459 字节，SHA-256 `33299dd5a2cf6765ddfc9ce9164c1dc988432d7d852dc589b7fc457274513f17`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 97 s；xcodebuild test 399 s；总 497 s` | `模拟器启动 104 s；xcodebuild test 425 s；总 531 s` |
| artifact | `PhotoCleanupMVE-unsigned-01aa3e618b62`，id `11626520907`，2030629 字节，有效期至 2027-01-07T15:16:43Z | `PhotoCleanupMVE-unsigned-52e977e1af5c`，id `11627960149`，2030629 字节，有效期至 2027-01-07T15:33:02Z |
| 四条 `testIC193*` 用例耗时（日志 `Test Case … passed (N seconds)`） | A `testIC193A_DeckPresentationRules` 0.002 s；B `testIC193B_MetricsMatchSpec2d` 0.015 s；C `testIC193C_CatalogAddsSixKeysAndRetiresSummary` 0.002 s；D `testIC193D_SourceWiring` 0.218 s | A 0.002 s；B 0.013 s；C 0.003 s；D 0.217 s |

- 两次构建日志里没有任何一条 warning／error 指向 `S1DeckCards.swift`、`S1YearPageView.swift`、`S1View.swift`、`Localizable.xcstrings` 或本卡改动的三个测试文件（整包日志逐行扫描：「运行 XCTest」步骤全部 swift warning 43 条、「构建未签名应用」步骤 4 条，均不在这些文件）；没有出现类型检查超时、result builder 报错或扫描器红。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）；两次日志里 `building pipeline` 均 0 次。两次日志各有两行 `Errors found! Invalidating cache...`（紧跟 `fopen failed for data file: errno = 2`），都落在 `IC175SimilarRecognizerTests.testIC175C_ObservationArchiveRoundTripKeepsDistanceZero` 用例块内（#390 1.579 s、#391 1.351 s，均 passed），与本卡无关，没有对应的失败或计时红。
- CI 预算 3 次，用了 1 次（#390）；#391 为合并后 `main` 运行，不计入试错预算。

## 九、四条新断言与随改、删除的既有断言

**四条新断言（`PhotoCleanupMVETests/IC193V1DeckTests.swift`，逐字节拷入，blob `00f117f0189155b81bc10d1683e3a014d0b55dfb`）**

| 断言 | 函数名 | 内容（据卡面 B 节） |
|---|---|---|
| 1 展示口径 | `testIC193A_DeckPresentationRules` | 可见高、卡高、上偏移、叠高随展开态（R3 七年第一张展开 966）；收起压暗中间档位置；封面收起上移 −78、展开 0；已看百分比（含整数运算哨兵 `29/100 = 29`）、看完（含 `11/10`）、进年页、待删／新增胶囊显隐（由 IC178A 移入）；展开卡副文、按钮名与年页汇总行的拼接（零段不显示） |
| 2 登记值 | `testIC193B_MetricsMatchSpec2d` | 2d 卡片叠与年页段逐值、两条推导恒等式、两处字面色分量、两个符号名与 `UIImage(systemName:)` |
| 3 目录 | `testIC193C_CatalogAddsSixKeysAndRetiresSummary` | 六条新 key 的值与 `L10n.text`、仍在用的六条旧 key（由 IC178E 移入）、`s1.yearPage.summary` 不在、`s0.` 41、三条格式串 |
| 4 源码落位 | `testIC193D_SourceWiring` | 新卡（一只封面、不挂 `.id(isOpen)`、卡叠观察展开态、首页同一 spring）、年页（走同一只卡叠视图、标题区借胶囊值）、S1View 两处接线、各文件 key 引用数（由 IC178D 移入）、全产品只有卡叠观察展开态 |

**删除与精简（`IC178DeckListTests`，由 A 的拷入文件带入，未手改）**

| 动作 | 函数名 | 说明 |
|---|---|---|
| 整删 | `testIC178A_StackAndCardPresentationRules` | 只测退役口径（旧步长、旧卡高、旧叠高、`titleFontSize`／`showsMonthCount`）；仍成立的已看百分比、看完、进年页、待删胶囊、填充比例断言移入 `testIC193A` |
| 整删 | `testIC178C_MetricsAndSymbolsMatchCanvas` | 只测旧五十个登记值与三个旧符号名（含 `S1DeckSymbol.done`） |
| 整删 | `testIC178E_CatalogGainsSevenKeys` | 七条 key 中一条（`s1.yearPage.summary`）退役；仍在的移入 `testIC193C` |
| 精简 | `testIC178D_SourceWiringAndDiscipline` | 删两张新文件计数表（`S1DeckCards.swift` 20 项、`S1YearPageView.swift` 14 项）、`S1DeckMetrics` 五十个与 `S1DeckSymbol` 三个的 `static let` 切片计数、两处 key 引用检查，改为一行注释指向 `IC193V1DeckTests.testIC193D_SourceWiring`；S1View 与状态机两段、`s1.trash.accessibility` 为 0 的检查保留；删 `catalogPath`、`newKeyValues` 两个常量；头注释改写 |

**随改的既有断言（`IC192PageHeaderTests.testIC192D_SourceWiring`，由 A 的拷入文件带入）**

| 断言 | 旧 → 新 |
|---|---|
| `S1DeckListView` 切片叠高调用 | `.frame(height: S1DeckCardPresentation.stackHeight(count: rows.count, kind: kind))` 1 → `.frame(height: S1DeckCardPresentation.stackHeight(count: rows.count, openIndex: openIndex))` 1 |
| `S1DeckListView` 切片底部留白 | `.padding(.bottom, S1DeckMetrics.stackBottomPadding)` 1 → `stackBottomPadding` 0 |

项数对账：`971 − 3 + 4 = 972`（CI 的 `Executed 972 tests`，唯一 Test Case 行 972）。

## 十、摘取关系实测

克隆：`git clone --no-hardlinks D:/IPHONE PHOTO MANAGEMENT/PhotoCleanupMVE <scratchpad>/ic193-exec/clone1`，克隆成功（退出码 0）、确认 `clone1/.git` 存在后才开始；所有命令带 `git -C <克隆>`；克隆里每个单元先 `checkout -b pick* 387efda74c0873333186094905bafc3e07b24018` 再 `cherry-pick -x`，原仓没有建任何其它分支。

| 单元 | 命令 | 退出码 | 结果树 |
|---|---|---|---|
| A 单独 | `cherry-pick -x A` | 0 | `6107e11aeb6d297e21a783cc35d957c1b23e02f4`（= A 提交的树，改动 6 路径） |
| A→B 连续 | `cherry-pick -x A B` | 0 | `05103758f075e9aafcf7a9272fd729534b790166`（= B 提交的树 = 合并提交的树，改动 8 路径） |

没有手工测 B 单独（卡面声明 B 单独文本可摘但编译依赖 A 的类型，不作可摘单元；`sim_ic193.py` 的 `IC193_CLONE=1` 已测 B 单独文本干净）。克隆实测只证文本无冲突，绿由 CI 证（#390 是 A→B 连续序列的绿，A 单独的绿未单独跑 CI）。

## 十一、G1063 被保护分支核对

`Tasks/decision-tools/ic193_protected_branches.txt`（38 行 `分支名 SHA`、无注释行，只读）对 `git ls-remote --heads origin` 逐条比对（每次返回 112 行，非空；空列表不算比对）：

- 推送分支之后、等 CI 期间第一次核：checked 38、mismatch 0（`main` 仍为 `387efda74c0873333186094905bafc3e07b24018`，本卡分支为 `01aa3e618b62415689ca22f9ca8efc44dc0bf49a`）。
- 合并前再核（分支 CI 绿之后）：checked 38、mismatch 0（`main` 仍为 `387efda74c0873333186094905bafc3e07b24018`）。
- 合并推送之后又核：checked 38、mismatch 0（`main` 为 `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76`，本卡分支仍为 `01aa3e618b62415689ca22f9ca8efc44dc0bf49a`；前两次 `ls-remote` 因 `schannel` 失败返回空，第三次才取得 112 行）。

三条冻结分支与其余被保护分支 tip 均未变。

## 十二、pbxproj 撞号扫描与两个新 id

- 对象定义行（`24 位 id /* … */ = {isa = …`）去重扫描：B 提交后单行定义 281 个、全部唯一；含多行对象定义共 316 个、全部唯一；重复 0。
- 两个新 id 出现次数：fileRef `100000000000000000000095`（`IC193V1DeckTests.swift`）3（定义 + 组 children + buildFile 引用），buildFile `200000000000000000000092` 2（定义 + 测试阶段）。与卡面一致（基线最大号 fileRef `100000000000000000000094`、buildFile `200000000000000000000091`）。pbx diff 恰 4 行新增。
- `git diff --cached --check` 两个提交均 0。

## 十三、规格欠账与已知遗留（卡面十条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S1 修订）

1. 「统计中」字号——收起行取单位字号 13、展开卡取大号 GB 字号 40、年页体积行 15，字重 600（照 IC-192 欠账 (3) 同位单位字号）。
2. 年页体积行按画布两段「X GB」+「占全部 N%」、两段之间无「·」，规格文案登记写成一条 `{size} · 占全部 {percent}%`。
3. 展开卡副文与年页汇总行实装为既有 key 拼接（分隔「 · 」），规格文案登记写成整条格式串。
4. 六条新 key 的名字（规格登记为「—（规格先行）」）回填。
5. 年页标题「行高 44」未实装（四段按距顶排底缘的绝对上距落位，同 IC-192）。
6. 旧 `stackBottomPadding` 24 退役，列表与月卡叠以末卡延伸 320 作底部留白（2d 无此值）。
7. 封面取图恒为卡宽 × `openCardHeight`（G5），末卡延伸超出 260 的部分是卡底色 + 压暗、不是封面。
8. 年页顶排钉在页面上方、正文在其下滚动（v11 现状，规格无条文）。
9. 卡按钮无专门读屏标签（照首页卡片叠），待删胶囊沿用 `s1.range.pending_count`。
10. 张数不带千分位（规格 `{count} 张` 与 v11 起各串同；画布示意「2,375 张」带）。

## 十四、人工判定项（保留给 Lynn 真机判定，执行端不代为下结论）

H101 九条（装合并后 `main` 运行 #391 的包，artifact `PhotoCleanupMVE-unsigned-52e977e1af5c`，id `11627960149`）：

1. 「逐张整理」列表页：每年一张卡，收起时一行（已看小圆环 · 年份 ·「待删 N」「新增 N」胶囊 · 占比 · GB · 箭头），恰一张展开（左上「占 N%」与胶囊、左下年份、大号 GB、「N 张 · M 个月 · 已看 N%」、已看条、右下「去清理 ›」）。整体与「空间清理」首页卡片叠是否一个语言。
2. 点收起的卡：它展开、原来展开的收起，一次弹簧动画；展开收起时封面不闪、不重新加载。
3. 点展开的年卡或「去清理」进年页；没有月份的年卡按钮是「去整理」、直接进看图；切到「相册」「未分类」：卡都是「去整理」，未分类只有一张、恒展开。
4. 扫描中 GB 位显示「统计中」、占比不显示；扫描完成后变成数字（不用离开页面）。
5. 年页：大号年份、其下「X GB」与「占全部 N%」、右侧「整理整年」；汇总行「N 张 · M 个月 · 已看 N% · 待删 N · 新增 N」（为零的段不显示）；年进度条；其下月卡叠同一套卡、第一张月卡展开。
6. 年页里点收起的月卡展开它；点展开月卡或「去整理」进看图；从看图回来仍在年页、展开的还是那张、已看与待删已更新。
7. 列表与年页都滚到底：末张卡一直延伸到屏底，没有空白断层；页头随列表滚走（年页顶排不动）。
8. 相册很多或相册名很长的账号（切到「相册」）：名字尾部省略、胶囊／占比／GB／箭头完整；滚动不卡、不发烫；翻转排序后展开的仍是原来那张卡（不跟着第一张跑）。
9. 一两句总评（字号、间距、压暗深浅、胶囊颜色、收起卡露出的是照片中间那一段）。

**覆盖说明**：夹具测试只验展示口径、登记值、目录与源码落位；卡片观感、展开动画、封面不重取、末卡延伸、滚动性能均属夹具驱动、真机未覆盖。

## 十五、docs 提交与最终核验

- docs 提交只含 `Reports/IC-193/self-check.md` 与 `Reports/IC-193/change-list.md`（惯例 44：合并与合并后 `main` 运行之后追加，纯 `Reports/**` 提交不触发 CI，预期行为）。
- docs 提交前已对本报告与 `change-list.md` 出现的全部 40 位 SHA 跑 `git cat-file -e <sha>^{<类型>}`，结果见 `change-list.md` 末节「核验结果」；docs 提交之后补跑 `check_ic193.py <docs 提交> docs`，结果在回传的回报里给出（docs 提交自身的 SHA 不写进报告）。

## 十六、发现但未处理的问题（按纪律只报告不修）

1. **卡叠非惰性**（卡面源码注释已写明）：`S1DeckStack` 的全部卡在出现时一起请求封面，相册很多的账号（切到「相册」维度）一次性请求的封面数 = 相册数。夹具与 CI 都测不到这一点，只能由 H101 第 8 条真机看滚动是否卡、是否发烫（③）；本卡不改。
2. 卡面 A 节说 `S1DeckCards.swift` 838 行、`S1YearPageView.swift` 163 行、新测试 479 行；拷入后实测分别为 838、163、479 行，与卡面一致，无偏差。
3. 红因清单 (1) 点名的编译风险（`Circle().inset(by:).trim(...)`、result builder 里的 `if`、`@ObservedObject` 逐成员构造、类型检查超时）在 CI 上均未出现；卡面 `layers`／`surface` 两段拆分已足以避开陷阱 16。
4. `sim_ic193.py` 按约定重写了 `Tasks/decision-tools/sim193/`（明令的唯一例外）；`Tasks/` 已有的其它文件未覆盖。
5. 本机 `core.autocrlf` 为 `true`；拷入文件 `git hash-object`（经清洗过滤）与清单逐一相等，未出现行尾转换问题。
6. 网络瞬断三次（`git push origin main` 一次、`git ls-remote --heads origin` 两次，均 `schannel: failed to receive handshake`），都是同一命令原样重试后成功，不是权限拒绝；没有被分类器拦截。
