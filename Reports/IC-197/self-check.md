# IC-197 自验报告

## 一、结论（先行）

- **两个子项全部按卡面完成（逐字节拷入 `ic197/stages/`，未手改一行），G1080～G1084 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-197-s2-guide-d-wiring`：A `0fbe51ab7d30e9c553e7a0e01e00f45425020dd7` → B `1f079fcf7bb2a892d783ec14be997b475a4fb89c`。
- 分支 CI **#398**（run `37991128426`，被测提交 B `1f079fcf7bb2a892d783ec14be997b475a4fb89c`）一次绿：**983 项 0 失败**（991 − 9 − 2 + 3），`xcodebuild` 输出 `Executed 983 tests, with 0 failures` 与 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 2074930 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `e754fcd3b457025534b311ddd0006acf5fa84aa8`（双亲 `d6d7e2413358003af717636e7ec09c317fa1d80d`／`1f079fcf7bb2a892d783ec14be997b475a4fb89c`，树 `458e307c5f01b6a2ef254953ad209e27f3266c45` 与 B 提交的树相同）。合并后 `main` CI **#399**（run `37992939159`）绿：983 项 0 失败，artifact `PhotoCleanupMVE-unsigned-e754fcd3b457`（id `11647005582`，有效期至 2027-01-07T21:21:19Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 3 个、B 4 个）、两个删除项 `git rm` 记录在案、卡面子项 A「改后」计数与工作树实测逐条相等（46 项检查 0 处不符）、B 的 `func test` 差值与 pbx 增删核对相符；提交后 `check_ic197.py` A／B 两个 tip 全 PASS（6／6、10／10）。
- **有界面变化，人工判定项 H103（十二条）保留给 Lynn 真机判定**，本报告不代为下结论（第十一节原样转录）。
- 本次没有停卡项，没有执行端偏离卡面的改动，**分支推送没有被分类器拦截**，没有任何一次 CI 红。红因清单 (1)(2) 点名的编译风险（三个 builder、`.task(id: guide.display)`、`??` 隐式成员、调 IC-196 视图的实参、镜像类与内存存储协议一致性、IC182 删函数后的残留引用、IC195F 改写）一项都没触发：两次整包日志里 swift error 行 0 条，`warning:` 行各 50 条（两次相同），没有任何一条指向 `S2View.swift`、`IC197GuideDWiringTests.swift`、`IC182TutorialRoundTwoTests.swift`、`IC195GuideDLogicTests.swift` 或目录；扫描器与目录双向检查在 XCTest 之前没有红。`testIC063`（陷阱 26）两次均未红。
- 网络与分类器：`git push -u origin feature/ic-197-s2-guide-d-wiring` 第一次即成功（git 直连、无代理）；`git merge --no-ff -F <消息文件>` 第一次即成功（Bash）；`git push origin main` 第一次即成功（Bash，`d6d7e24..e754fcd`）；有一条后台启动轮询的 Bash 命令被分类器返回一次「no verdict (error)」的瞬时失败，按提示原样重试一次即通过，没有换写法。
- 脚本：`materialize_ic197.py`、`gen_ic197_card.py` 未跑（明令不跑）；`sim_ic197.py` 未再跑（决策会话已在基线上预演；本地门禁与摘取实测我用自己的命令在真实提交上做了，第五、六节）。`Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（脚本一律 `python -B`，`ls | grep -ci pycache` 为 0）；我的临时脚本与日志全部在 scratchpad `ic197-exec/`。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-197-s2-guide-d-wiring.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-197.md`；拆卡与取定 `Tasks/PLAN-S2D-guide-rulings-20261009.md`（第三节接线备忘 W3～W5、第六节是本卡）；复核结论 `Tasks/REVIEW-IC-197-findings.md` 第五节「决策会话处置」（已读；复核员的「建议改法」不作指令，改法以卡与 `stages/` 为准）。`CLAUDE.md` 随会话上下文完整载入。
- 继承提交 / 基线：`main` = `d6d7e2413358003af717636e7ec09c317fa1d80d`（IC-196 报告补记；merge `33ce39f6838925a52050168c3d5c349f1f458ba5`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 33ce39f6838925a52050168c3d5c349f1f458ba5 main` 退出码 0；`git ls-remote origin refs/heads/main` = `d6d7e2413358003af717636e7ec09c317fa1d80d`；七个被改或被删文件基线 blob 与卡面表逐个相等（`project.pbxproj` `f823358d93dd781e30310c5f2b443c681ede0444`、`S2View.swift` `39acc0052234d23b811bf2c332bafe6a0b688fc1`、`Localizable.xcstrings` `f4fed78a7381caea6c512384b300c5885f8505d1`、`IC182TutorialRoundTwoTests.swift` `0136baf20cc763a1cdedb69b1ed11968837bf327`、`IC195GuideDLogicTests.swift` `018b4606cefa3b043acb2445d6c79d68b701cf6e`、`S2InlineHints.swift` `45fcebccd42048ab680c34bddf18f9bbb5a2d16c`、`IC179InlineHintsTests.swift` `d814f599df69211e7bbc0aed013839e3722367d2`）；本地与远端均无同名分支；先 `git switch -c feature/ic-197-s2-guide-d-wiring`（自 `d6d7e24`）再拷文件。仓库里两个更早就存在的 stash（挂在 `feature/ic-067-screenshot-detection`）未动，结束时仍是 2 个。
- 目标分支：`feature/ic-197-s2-guide-d-wiring`，合并入 `main`。
- 范围边界：白名单 8 路径（含两个删除项），`git diff --name-only d6d7e2413358003af717636e7ec09c317fa1d80d..1f079fcf7bb2a892d783ec14be997b475a4fb89c` 恰这 8 行。`S2GuideD.swift`、`S2GuideDViews.swift`、`S2StateMachine.swift`、六步教程的类型与接线、`IC196GuideDViewsTests`、协调器、App、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）、`Scripts/`、`.github/`、`S5GuideStepsView.swift` 一字未动。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `0fbe51ab7d30e9c553e7a0e01e00f45425020dd7` | `bba274b7cb2c2a74ae4421d65abd36d5ed23f06c` | `S2View.swift` 换接引导 D（+136／−71）+ 删 `S2InlineHints.swift`（−592）+ `Localizable.xcstrings` 删七条 `s2.hint.*`（−77，300 → 293）+ pbx 删四行。4 个路径 |
| B | `1f079fcf7bb2a892d783ec14be997b475a4fb89c` | `458e307c5f01b6a2ef254953ad209e27f3266c45` | 删 `IC179InlineHintsTests.swift`（−528）+ `IC182TutorialRoundTwoTests.swift` 改写（+25／−170）+ `IC195GuideDLogicTests.swift` 改写（+17／−14）+ 新测试 `IC197GuideDWiringTests.swift`（+570）+ pbx（+4／−4）。5 个路径 |
| 合并 | `e754fcd3b457025534b311ddd0006acf5fa84aa8` | `458e307c5f01b6a2ef254953ad209e27f3266c45` | `merge(IC-197): S2 教学引导 D 接线——S2View 换接引导 D 的协调器与三层视图、v23 三句与七条 s2.hint.* 退役` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-197/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --numstat` 基线..B：`project.pbxproj` +4／−8、`S2InlineHints.swift` +0／−592、`S2View.swift` +136／−71、`Localizable.xcstrings` +0／−77、`IC179InlineHintsTests.swift` +0／−528、`IC182TutorialRoundTwoTests.swift` +25／−170、`IC195GuideDLogicTests.swift` +17／−14、`IC197GuideDWiringTests.swift` +570／−0（合计 752 增 1460 删）。`S2View.swift` 现 6189 行。

## 四、逐子项提交前对读、拷入文件 `git hash-object` 与删除记录

脚本（scratchpad `ic197-exec/count_a.py`、`count_b.py`）：读工作树文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（直接 `import` 了 `Tasks/decision-tools/strip.py` 的 `strip_text`，只读），逐条数卡面子项 A／B「改后」涉及的计数；提交前跑，全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic197.py` 又用 `git rev-parse <tip>:<路径>` 核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `7ad9645e433cb8ececa1fcc21ed338a6c7091a9d` | `7ad9645e433cb8ececa1fcc21ed338a6c7091a9d` | 相等 |
| A | `PhotoCleanupMVE/Features/S2/S2View.swift` | `703d1c63fe6d44f4078863ab7635ffbfcf7e42a5` | `703d1c63fe6d44f4078863ab7635ffbfcf7e42a5` | 相等 |
| A | `PhotoCleanupMVE/Localizable.xcstrings` | `7d240456737d081d167aa7bbc0b4eb2bb778d6a8` | `7d240456737d081d167aa7bbc0b4eb2bb778d6a8` | 相等 |
| A | `PhotoCleanupMVE/Features/S2/S2InlineHints.swift` | 删除 | `git rm`：`rm 'PhotoCleanupMVE/Features/S2/S2InlineHints.swift'`（A 提交里 `delete mode 100644`；`check_ic197.py A` 的 `deleted` 项 PASS） | — |
| B | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `cc4a9d8cfb2f9c0dc195b75e094972375207b5f9` | `cc4a9d8cfb2f9c0dc195b75e094972375207b5f9` | 相等 |
| B | `PhotoCleanupMVETests/IC182TutorialRoundTwoTests.swift` | `5afcd25899c4c8258b8701633e7be3b4392658d5` | `5afcd25899c4c8258b8701633e7be3b4392658d5` | 相等 |
| B | `PhotoCleanupMVETests/IC195GuideDLogicTests.swift` | `a086d90ea4762c5ae58aeaf3c405a9af521f995e` | `a086d90ea4762c5ae58aeaf3c405a9af521f995e` | 相等 |
| B | `PhotoCleanupMVETests/IC197GuideDWiringTests.swift` | `057b3653dd180cc9348f746a05c645ece4032a58` | `057b3653dd180cc9348f746a05c645ece4032a58` | 相等 |
| B | `PhotoCleanupMVETests/IC179InlineHintsTests.swift` | 删除 | `git rm`：`rm 'PhotoCleanupMVETests/IC179InlineHintsTests.swift'`（B 提交里 `delete mode 100644`；`check_ic197.py B` 的 `deleted` 项 PASS） | — |

每个子项拷入并 `git rm` 之后 `git status --porcelain` 只列该子项的文件（A：` M project.pbxproj`、`D  S2InlineHints.swift`、` M S2View.swift`、` M Localizable.xcstrings`；B：` M project.pbxproj`、`D  IC179InlineHintsTests.swift`、` M IC182…`、` M IC195…`、`?? IC197GuideDWiringTests.swift`），按清单逐个 `git add <路径>`（未用 `-A`）。

**子项 A「改后」计数实测**（`S2View.swift`，剔注释与字符串；每行「实测／卡面」，0 处不符）

| 检查 | 实测／卡面 |
|---|---|
| `S2GuideCoordinator()`、`@State private var guideStarted = false`、`guide.start(mergedCount: machine.sessionMergedPendingDeletionCount)`、`guide.leaveScreen()`、`guide.confirmEntryTapped()`、`guide.reset()`、`guide.skip()`、`guide.completionDidTimeOut()`、`guide.mergedCountDidChange(count)` | 各 1／1 |
| `guide.isInterfaceVisible = machine.interfaceVisibility == .visible` | 4／4 |
| `guide.isInterfaceVisible = visibility == .visible` | 1／1 |
| `stayedOnMarkedAsset: inserted.contains(machine.currentAssetID)`、`source: machine.lastPendingDeletionChangeSource ?? .undo`、`cause: machine.lastCurrentAssetChangeCause ?? .browse` | 各 1／1 |
| `machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark` | 6／6 |
| `machine.holdsPageAfterNextMark`（IC182C 改写）／`= true`／`= false` | 6／6；0／0；0／0 |
| `.onChange(of: guide.display) {` | 1／1 |
| `guideIntroScrimOverlay(`、`guideGestureOverlay(`、`guideCardOverlay(` | 各 2／2 |
| `hints.`、`S2InlineHint`、`inlineHintOverlay`、`tutorial.startIfNeeded()`、`tutorial.replay()` | 各 0／0 |
| `tutorial.leaveScreen()`、`tutorial.assetDidBecomeMarked(assetID: assetID)`、`tutorial.assetDidBecomeUnmarked(assetID: assetID)`、`tutorial.assetDidJoinAlbum(assetID: record.assetID)`、`tutorial.albumPickerVisibilityDidChange(`、`final class S2TutorialCoordinator: ObservableObject {`、`if tutorial.activeStep == .albumGuide {` | 各 1／1 |
| `tutorialOverlay(` | 2／2 |
| `.background(.regularMaterial)` | 3／3 |
| 原文 `colorScheme, .dark)`；原文 `"s2.tutorial.replay"` | 6／6；1／1 |
| IC195H 改写：`S2GuideCoordinator()`、`machine.lastPendingDeletionChangeSource`、`machine.lastCurrentAssetChangeCause`、`S2UserDefaultsGuideStore` | 1／1；1／1；1／1；0／0 |
| IC182C 改写：`guide.start(mergedCount:`、`guide.assetDidBecomeUnmarked(`、`guide.currentAssetDidChange(` | 各 1／1 |
| 产品源码递归剔注释 `S2InlineHint`；`S2View.swift` 原文（含注释）`S2InlineHint`、`"s2.hint.` | 0／0；0、0／0 |
| 目录 JSON：总条数；`s2.hint.` 前缀；`s2.guide.` 前缀；`s2.tutorial.` 前缀 | 293／293（300 − 7）；0／0；11／11；10／10 |
| pbx：`S2InlineHints` 出现；`IC179InlineHintsTests` 出现行数（A 之后、B 之前） | 0／0；4 行／4 行（B 删除） |

**子项 B「改后」实测**

| 检查 | 实测／卡面 |
|---|---|
| `IC179InlineHintsTests` 删除的 `func test*`（剔注释） | 9／9 |
| `IC182` 删除的 `func test*`（基线 5 条：A、A2、B、C、D；改后 A、C、D） | 2／2 |
| `IC195` 的 `func test*` 基线 8 条、改后 8 条 | 差值 0／0 |
| 新测试文件 `func test*` | 3／3（`testIC197A`～`C`） |
| 对账式 | 991 − 9 − 2 + 3 = **983**／983 |
| pbx：`IC179InlineHintsTests`、`S2InlineHints` 出现 | 0／0 |
| pbx：`IC197GuideDWiringTests` 行数 | 4／4 |
| pbx：新 id `10000000000000000000009B`／`200000000000000000000098` 全文行数 | 3／2（定义 + buildFile 引用 + 组 children；定义 + Sources 阶段） |
| IC182 改后剔注释 `S2InlineHint`、`IC182InMemoryHintStore`、`hintsPath`、`S2InlineHintCoordinator` | 各 0／0 |
| 全部测试源码递归剔注释 `S2InlineHint`、`S2UserDefaultsInlineHintStore`、`S2InlineHintCoordinator`、`S2InlineHintStoring` | 0／0 |

`git diff --cached --check` 两个提交各自提交前退出码 0；B 的 `git diff --name-only d6d7e24..1f079fc` 恰 8 路径。

## 五、`check_ic197.py` 两段 SUMMARY 与摘取实测

`check_ic197.py` 在刚提交的 tip 上跑（基线取脚本默认值 `d6d7e24`，`IC_REPO=<仓库路径>`，`python -B`，在 `Tasks/decision-tools/` 里运行；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `0fbe51ab7d30e9c553e7a0e01e00f45425020dd7` | `SUMMARY 6 pass / 6`（blob 3 + `deleted` 1 + `changed paths == whitelist (4)` + `base is ancestor`） | 0 |
| B | `1f079fcf7bb2a892d783ec14be997b475a4fb89c` | `SUMMARY 10 pass / 10`（blob 6 + `deleted` 2 + `changed paths == whitelist (8)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

**摘取关系实测**（克隆 `git clone --no-hardlinks` 到 scratchpad `ic197-exec/clone`，克隆成功；命令全部在克隆目录内执行，从未落到原仓；克隆里自基线 `d6d7e2413358003af717636e7ec09c317fa1d80d` 起 `switch -c`，对我的真实两个提交 `cherry-pick -x`；只证文本无冲突，绿由 CI 证）：

| 组合 | 退出码 | 结果树 | 备注 |
|---|---|---|---|
| A 单独 | 0 | `bba274b7cb2c2a74ae4421d65abd36d5ed23f06c` | 与分支上 A 提交的树相同；`git status --porcelain` 空。**卡面已写明 A 单独时测试目标编译红**（IC179／IC182 引用被删类型），克隆实测只证文本无冲突，未推 CI |
| A → B | 0（两步各 0） | `458e307c5f01b6a2ef254953ad209e27f3266c45` | 与分支上 B 提交的树、合并提交的树相同；`git status --porcelain` 空 |
| B 单独（额外） | 0 | — | 自基线直接 `cherry-pick -x B` 文本上也无冲突（B 的 pbx 改动与 A 的互不相交）；但 B 的新测试与改写依赖 A 的 `S2View` 接线与文件删除，编译层面只能 A→B。已 `--abort` 复位克隆，未推 CI |

## 六、本地门禁（两个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File …`（Windows PowerShell 5.1，Bash 工具里调用）在仓库根跑；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0（结构自验通过，扫描 140 个 .swift 括号结构、74 个测试源文件交叉审计通过） | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） | 0 |
| B | 0（同样 140 个 .swift、74 个测试源文件，含新测试文件） | 0（同） | 0 |

## 七、验收门禁逐条（G1080～G1084）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1080 行为与落位 | 满足 | 第五节：`check_ic197.py` A、B 两个 tip 全 PASS（含两个删除项不在 tip） |
| G1081 新断言 | 满足 | 三条 `testIC197*`、改写后的 `testIC182A`／`C`／`D` 与 `testIC195H` 在 #398 与 #399 整包日志里全部 passed（第九节） |
| G1082 不回退 | 满足 | `IC196GuideDViewsTests`（5）、`IC195GuideDLogicTests`（8）、`IC141VideoPlaybackTests`（16）、`IC143VideoPolishTests`（13）、`IC151AmbientFixedColorTests`（7）、`IC172GlassAlwaysDarkTests`（7）、`IC146ChromeRoundTwoTests`（19）、`S2ActionBarWiringTests`（65）、`S2StateMachineTests`（52）、`IC187SeenArchiveTests`（4）在 #398 与 #399 的整包日志里按唯一 Test Case 行数全部 passed、0 failed（两次逐类相同） |
| G1083 合并前置 | 满足 | G1080～G1082 + CI #398 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice；摘要 983 与 xcodebuild 小计 983 一致，无需按第 217 条第四节另核，唯一 Test Case 行 983 passed／0 failed）+ 42 条被保护分支 tip 未变（第十一节）+ pbxproj 撞号扫描（第十节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote --heads origin` 里 `main` 仍为 `d6d7e2413358003af717636e7ec09c317fa1d80d`） |
| G1084 合并后 | 满足 | 合并后 `main` CI #399 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #398 | 合并后 `main` 运行 #399 |
|---|---|---|
| run id | `37991128426` | `37992939159` |
| 被测提交 | `1f079fcf7bb2a892d783ec14be997b475a4fb89c` | `e754fcd3b457025534b311ddd0006acf5fa84aa8` |
| 触发 | push 到 `feature/ic-197-s2-guide-d-wiring` | push 到 `main` |
| 作业起止 | 2026-10-09T21:04:13Z～21:19:10Z | 2026-10-09T21:21:28Z～21:37:06Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 983 项，0 失败（xcodebuild `Executed 983 tests, with 0 failures (0 unexpected) in 56.661 (61.599) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 983 passed／0 failed，无「已开始未结束」） | 983 项，0 失败（`Executed 983 tests, with 0 failures (0 unexpected) in 58.537 (63.482) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 983 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 983 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 983 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`） | 0（同） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；xcodebuild 匹配行 `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一两行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2074930 字节，SHA-256 `782126a47421415e97716ac8b8438197ebcae1925e04913642d79a1f3f1d7307` | 2074930 字节，SHA-256 `436faea5922f945cf666cede2e35cb6e2b56c2a2016eb657f473c7da91e8cd28`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 82 s；xcodebuild test 487 s；总 570 s` | `模拟器启动 101 s；xcodebuild test 452 s；总 557 s` |
| artifact | `PhotoCleanupMVE-unsigned-1f079fcf7bb2`，id `11646026137`，2075100 字节，有效期至 2027-01-07T21:04:04Z | `PhotoCleanupMVE-unsigned-e754fcd3b457`，id `11647005582`，2075100 字节，有效期至 2027-01-07T21:21:19Z |
| 三条 `testIC197*` 与改写后 `testIC182*`／`testIC195H` 用例耗时（日志 `Test Case … passed (N seconds)`） | `testIC197A_WiringMirrorWalksTheFourStepsOnTheRealStateMachine` 0.004 s；`testIC197B_ZoomedMarkDoesNotHoldAndSkipStopsTheVisit` 0.002 s；`testIC197C_SourceWiringLayersAndRetirement` 0.547 s；`testIC182A_HoldAfterFirstMarkOnlyOnce` 0.004 s；`testIC182C_SourceWiring` 0.114 s；`testIC182D_CatalogHintKeysRetired` 0.035 s；`testIC195H_SourceWiring` 0.089 s | A 0.001 s；B 0.001 s；C 0.382 s；`testIC182A` 0.002 s；`testIC182C` 0.190 s；`testIC182D` 0.031 s；`testIC195H` 0.069 s |

- 两次构建日志里 swift error 行 0 条；`warning:` 行各 50 条（两次相同），没有任何一条指向本卡改动的文件；没有类型检查超时、result builder 报错或扫描器红。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）：`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` #398 6.418 s、#399 6.349 s，均 passed；两次日志里 `building pipeline` 均 0 次，各有两行 `Invalidating cache`（既有，与本卡无关）。
- CI 预算 3 次，用了 1 次（#398）；#399 为合并后 `main` 运行，不计入试错预算。

## 九、新断言与改写后的既有断言

三条新断言（`PhotoCleanupMVETests/IC197GuideDWiringTests.swift`，逐字节拷入，blob `057b3653dd180cc9348f746a05c645ece4032a58`，570 行）：

| 断言 | 函数名 | 内容（据卡面 B 节） |
|---|---|---|
| A | `testIC197A_WiringMirrorWalksTheFourStepsOnTheRealStateMachine` | 接线镜像（S2View 五处回调体同一写法）+ 真实 `S2StateMachine`（七张）+ 内存存储：进门第 1 步与压暗、开关开 → 上滑停在刚标记那张出第 2 步、压暗落、开关关 → 下滑（`.undo`）出第 3 步 → 左右滑（`.browse`）学会第 3 步 → 连标到合并计数 5 出第 4 步 → 进确认页学会、完成留到下次 → 下一次进入出完成、到点收起 |
| B | `testIC197B_ZoomedMarkDoesNotHoldAndSkipStopsTheVisit` | 放大态上滑进下一张、不出第 2 步也不记收起、开关留给 1x，1x 那一下停住出第 2 步；跳过收起与压暗、关开关、本次不停，下一次进入第 1 步已会、第 2 步未会仍停 |
| C | `testIC197C_SourceWiringLayersAndRetirement` | S2View 计数表（含六步教程既有接线与 IC172／IC168 正对照）、只开一次的守卫、四个回调体的次序、确认入口在 guard 之后、层序、三个 builder、两个被删文件不在、产品零 `S2InlineHint`、目录 `s2.hint.` 0／`s2.guide.` 11／`s2.tutorial.` 10 |

**改写后的既有断言**（均逐字节来自 `stages/B/`）：`IC182TutorialRoundTwoTests` 保留 `testIC182A_HoldAfterFirstMarkOnlyOnce`，整删 A2（`testIC182A2_CoordinatorDecidesHoldExactlyWhenMarkedOnceWouldAppear`）与 B（`testIC182B_PlacementRulesGestureMetricsAndSymbols`），`testIC182C_SourceWiring` 的 S2View 段改钉六处同步、旧提示文件段整删、`S5GuideMetrics.textMinimumScaleFactor` 0.8 移入，`testIC182D_CatalogUntouched` 改名 `testIC182D_CatalogHintKeysRetired`，文件私有的 `IC182InMemoryHintStore` 删；`IC195GuideDLogicTests.testIC195F_UserDefaultsStoreReusesV23Keys` 改按字面前缀与后缀钉 v23 键、旧键直接 `defaults.set`、补「与旧六步教程完成标志互不相干」；`testIC195H_SourceWiring` 末段改钉「v23 文件已不在、`S2GuideCoordinator()` 1、两个信号各读 1、`S2UserDefaultsGuideStore` 0」；`IC179InlineHintsTests` 整文件删（九条）。

**项数对账**：991 − 9（IC179）− 2（IC182 A2、B）+ 3（IC197）= **983**；#398 与 #399 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行数三者都是 983；提交前本机剔注释后 `func test*` 差值 −8 与之相符（陷阱 22：本机 grep 只作差值预估）。

## 十、pbxproj 撞号扫描与两个新 id

- 推进前扫描：基线最大号 fileRef `10000000000000000000009A`、buildFile `200000000000000000000097`（IC-196；十六进制）。B 提交前对工作树 `project.pbxproj`：对象定义共 324 条（基线 326 条，−4 个被删定义 +2 个新增），重复 id 0；最大号 fileRef `10000000000000000000009B`、buildFile `200000000000000000000098`。
- 两个新 id 各自在全文的出现行数：`10000000000000000000009B` 3 行（定义 + buildFile 引用 + 测试组 children）、`200000000000000000000098` 2 行（定义 + 测试 Sources 阶段）；每个都只有 1 处定义。四个被删 id（`10000000000000000000007A`／`200000000000000000000077` 属 `S2InlineHints.swift`，`10000000000000000000007B`／`200000000000000000000078` 属 `IC179InlineHintsTests.swift`）在全文各 0 行（基线分别 3／2／3／2 行）。
- 两个新 id：测试 fileRef `10000000000000000000009B`／buildFile `200000000000000000000098`（`IC197GuideDWiringTests.swift`，接在 `IC196GuideDViewsTests.swift` 之后）。

## 十一、G1083 被保护分支核对与 H103

清单 `Tasks/decision-tools/ic197_protected_branches.txt` 恰 42 行（`分支名 SHA`，无注释行）。对 `git ls-remote --heads origin` 逐条比对三次：推送后 CI 期间（远端 116 个 head，含本分支）、合并前（116）、合并并推送 `main` 之后（116）——**不符 0 条（42／42 相等）**；比对脚本遇 `ls-remote` 返回空即重试，空列表不算比对（本次每次第一次返回即非空）。合并前 `main` = `d6d7e2413358003af717636e7ec09c317fa1d80d`，合并后 `main` = `e754fcd3b457025534b311ddd0006acf5fa84aa8`（单条 `git ls-remote origin refs/heads/main` 复核一致）。

### 人工判定项 H103（原样转录；**保留给 Lynn 真机判定，执行端不代为下结论，本次未做任何真机或模拟器观感判断**）

装合并后 `main` 产物；**先在 S2 标定面板点「重看教程」**（已学会 v23 三句的设备只有经它才能看到 D 的第 1、2 步；它本身就是被测行为——点了当场出第 1 步与压暗）。第 6～8 条各自**先再点一次「重看教程」**（第 1～5 条走完后四步都已会、完成也已出过）。
1. 进入「逐张整理」任一月的看图：照片区轻压暗、靠上一张深色教练卡（四点、「跳过教程」、上箭头圆、「上滑，放进待删篮」）、中央手势示范上下循环；压暗不挡上滑、左右滑、单击；点卡片正文等于单击照片（会切隐藏界面，属预期）；顶排与底栏照常可点。
2. 上滑标记：停在刚标记的那张（不翻页），压暗消失，卡换成「已放进待删篮」、示范改下滑；「已标记 · 撤销」胶囊照常出现，与示范的叠放观感（未定项 38）；停着不动十几秒，第 2 步不会自己消失（不限时）。
3. 下滑放回：卡换成「已撤回，照片回来了」、示范左右交替；左右滑翻到别张后卡收起。
4. 连续标到待删篮 5 张：卡换成「攒了 5 张」（出现瞬间数字可能先显示 4 再滚到 5，与右上角标同步——规格如此），卡上缘小三角对准右上垃圾桶、虚线连到圆钮、圆钮外一圈薄荷高亮（高亮与红色角标叠在一起的观感）。
5. 点右上垃圾桶进确认页再返回，或下次进入：出「都学会了」小卡，约 2 秒自己消失。
6. 「跳过教程」：卡与压暗立刻消失，这次进入不再出；退出再进入照规则出没学会的步。
7. 双指放大后上滑：照旧翻到下一张、不停；回到 1x 后的下一次上滑才停住。
8. 单击切换隐藏界面：引导随顶排、底栏一起隐去、再单击一起回来；完成小卡的 2 秒不因隐藏而停。
9. 教练卡与完成卡的位置、换步时是否在原地淡入淡出（不跳、不闪）；换张、放大、截图沉浸时卡的位置不变。
10. 翻页拖动中、放大平移中，中央手势示范是否卡顿。
11. iPhone SE 或小屏、英文系统（如可）：卡内文字是否放得下（未定项 37）；手势示范在任何时刻都不压住教练卡。
12. 总评一两句。

装包取合并后 `main` 的产物 `PhotoCleanupMVE-unsigned-e754fcd3b457`（id `11647005582`，有效期至 2027-01-07T21:21:19Z；分支产物 `PhotoCleanupMVE-unsigned-1f079fcf7bb2` 等价）。**降级注意**：本卡不改会话档或持久化格式，但 IC-190 起的「不要回装 #383 及更旧的包」仍然成立。

## 十二、规格欠账（卡面九条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S2 修订）

1. 七条 `s2.hint.*` 删除、文案改走 IC-196 的 `s2.guide.*`（规格 `:446`「七条 `s2.hint.*` 改值或改名由该卡定」的落实）。
2. 示范层在中央状态指示之下（未定项 38 的叠放取舍之一，③ 进 H）。
3. 第 4 步确认入口高亮环在卡层、盖在角标上（IC-196 复核 ③5，③ 进 H）。
4. 两个一次性信号读到 nil 时缺省 `.undo`／`.browse`（值变时状态机必已赋值，只是兜底）。
5. 每次进入只开一次引导（`@State guideStarted`，同身份重现不再开，宁可不重出也不清掉本次的跳过与收起）。
6. 四点指示的「已会」每次重画时现读存储。
7. 压暗随 chrome 显隐（计划裁定 4「放大时随 chrome 一起隐藏」）。
8. 完成提示只有标题（④ 第 223 条，沿 IC-196）。
9. 测试整删：IC179 九条与 IC182 两条只测退役符号（第 214 条放开、IC-184／192／193 先例）。

## 十三、docs 提交与最终核验

- 惯例 44：本报告与 `change-list.md` 随合并与合并后 `main` 运行之后的**恰一个 docs 提交**落在 `main` 上（仅 `Reports/IC-197/` 两个文件，`Reports/**` 命中 `ci.yml` 的 `paths-ignore`，该提交不触发 CI）。
- 报告写完后，对报告里出现的每个 40 位 SHA 跑了 `git cat-file -e <sha>^{<类型>}`：结果见本文末「报告内 SHA 核验」。

## 十四、发现但未处理的问题（按纪律只报告不修）

1. `PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift` 的文档注释里仍提到已删除的 `S2InlineHintSymbol`（卡「事实基础」与取定 5 已预告：只是注释，本卡不动）。产品源码剔注释后 `S2InlineHint` 为 0；该注释的措辞可在下一次动该文件的卡里顺手改。
2. 摘取关系补充：卡面写「B 的新测试与改写依赖 A 的 `S2View` 接线」，克隆实测 B 单独自基线 `cherry-pick -x` 在**文本**上也无冲突（pbx 的 A、B 改动互不相交），只是编译层面必红；所以「只能 A→B」要靠卡面纪律、不能靠冲突来拦（第五节）。
3. 卡面里 IC182 的函数名简称为 `testIC182A`／`C`／`D`，实际全名为 `testIC182A_HoldAfterFirstMarkOnlyOnce`／`testIC182C_SourceWiring`／`testIC182D_CatalogHintKeysRetired`（IC182C 名未改）。无影响，仅便于下一次对照。
4. 复核第五节「Q1～Q4 只记不定」四项（Q1 第 4 步数字先显示旧值、Q2 进入时 `V=隐藏` 则完成提示被静默用掉、Q3 压暗整条带、Q4 高亮环与角标叠放）与 ③3.5（同身份 `onDisappear`→`onAppear` 后第 2 步可能提前重出）本卡实装的就是卡面写法，没有新增偏离；它们的观感部分已落在 H103 第 4、1、8 条，其余保留给决策会话记入交接包。
5. 仓库里有两个先前就存在的 stash（`stash@{0}`、`stash@{1}`，均挂在 `feature/ic-067-screenshot-detection` 上），不是本卡产生的，未动。
6. 工具备注（非缺陷）：我第一次启动 CI 轮询时把 Python 以 `&` 放到了后台子 shell，收不到完成通知，随即 `Stop-Process` 结束该进程并改用 `run_in_background` 重启；两个 CI 轮询进程与该次误起的进程结束时均已退出（`python.exe` 进程数 0）。一次 Bash 调用被分类器返回「no verdict (error)」的瞬时失败，按提示原样重试一次即通过。无任何拒绝或绕过。
7. 无产品或卡面缺陷发现。执行中没有偏离卡面的改动。

## 报告内 SHA 核验

两份报告里出现的全部 40 位 SHA（去重后见下表，正则按前后非十六进制字符取，64 位的 SHA-256 不会被误取）逐个跑 `git cat-file -e <sha>^{<类型>}`，退出码全 0，缺失 0 个（IPA 的 SHA-256 `782126a4…`、`436faea5…` 不是 git 对象，不在此表）：

| SHA | 对象类型 | `cat-file -e` 退出码 |
|---|---|---|
| `0fbe51ab7d30e9c553e7a0e01e00f45425020dd7` | commit | 0 |
| `1f079fcf7bb2a892d783ec14be997b475a4fb89c` | commit | 0 |
| `e754fcd3b457025534b311ddd0006acf5fa84aa8` | commit | 0 |
| `d6d7e2413358003af717636e7ec09c317fa1d80d` | commit | 0 |
| `458e307c5f01b6a2ef254953ad209e27f3266c45` | tree | 0 |
| `33ce39f6838925a52050168c3d5c349f1f458ba5` | commit | 0 |
| `f823358d93dd781e30310c5f2b443c681ede0444` | blob | 0 |
| `39acc0052234d23b811bf2c332bafe6a0b688fc1` | blob | 0 |
| `f4fed78a7381caea6c512384b300c5885f8505d1` | blob | 0 |
| `0136baf20cc763a1cdedb69b1ed11968837bf327` | blob | 0 |
| `018b4606cefa3b043acb2445d6c79d68b701cf6e` | blob | 0 |
| `45fcebccd42048ab680c34bddf18f9bbb5a2d16c` | blob | 0 |
| `d814f599df69211e7bbc0aed013839e3722367d2` | blob | 0 |
| `bba274b7cb2c2a74ae4421d65abd36d5ed23f06c` | tree | 0 |
| `7ad9645e433cb8ececa1fcc21ed338a6c7091a9d` | blob | 0 |
| `703d1c63fe6d44f4078863ab7635ffbfcf7e42a5` | blob | 0 |
| `7d240456737d081d167aa7bbc0b4eb2bb778d6a8` | blob | 0 |
| `cc4a9d8cfb2f9c0dc195b75e094972375207b5f9` | blob | 0 |
| `5afcd25899c4c8258b8701633e7be3b4392658d5` | blob | 0 |
| `a086d90ea4762c5ae58aeaf3c405a9af521f995e` | blob | 0 |
| `057b3653dd180cc9348f746a05c645ece4032a58` | blob | 0 |

共 21 个，缺失／不通过 0 个。
