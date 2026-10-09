# IC-196 自验报告

## 一、结论（先行）

- **两个子项全部按卡面完成（逐字节拷入 `ic196/stages/`，未手改一行），G1075～G1079 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-196-s2-guide-d-views`：A `c83256ac28f8509880b1ce3fd7748371b97c3ce2` → B `55ab4c01963999c0539465152d8955afbff4e3ef`。
- 分支 CI **#396**（run `37981100828`，被测提交 B `55ab4c01963999c0539465152d8955afbff4e3ef`）一次绿：**991 项 0 失败**（986 + 5），`xcodebuild` 输出 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（脚本以 `exit "$test_status"` 原样退出，真实退出码 0），目的地 `OS:26.2, name:iPhone 16`。IPA 2037941 字节。CI 预算 3 次，实际用 1 次（合并后 `main` 运行另计，不属于预算内的试错）。
- 合并提交 `33ce39f6838925a52050168c3d5c349f1f458ba5`（双亲 `0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c`／`55ab4c01963999c0539465152d8955afbff4e3ef`，树 `c5c3045c2e3ea80509188fbef0cae526c890c6ee` 与 B 提交的树相同）。合并后 `main` CI **#397**（run `37983377590`）绿：991 项 0 失败，artifact `PhotoCleanupMVE-unsigned-33ce39f68389`（id `11641474475`，有效期至 2027-01-07T19:54:13Z）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- 逐子项提交前：拷入文件 `git hash-object` 与清单全部相等（A 3 个、B 2 个）、卡面子项 A「改后」计数与工作树实测逐条相等（31 项检查，0 处不符）、B 的 `func test` 行数与 pbx 增行核对相符；提交后 `check_ic196.py` A／B 两个 tip 全 PASS（5／5、6／6）。
- **无界面变化，无人工判定项**：新视图只建不接，`S2View.swift`、`S2InlineHints.swift`、`S2GuideD.swift` 一字未动，运行中的引导仍是 v23 三句就地提示。
- 本次没有停卡项，没有执行端偏离卡面的改动，**分支推送没有被分类器拦截**，没有中途中断，没有任何一次 CI 红。红因清单 (1)(2) 点名的编译风险（`TimelineView(.animation)` 闭包调私有方法、`if case .step(let step)? = display`、`.background(_:in:)`、`StrokeStyle(lineWidth:dash:)`、`.overlay(alignment:)` 里 `.position`、`extension S2GuideStep` 与 D1 同名冲突、泛型 `fittedSize`、`[S2GuideDisplay?]`、元组数组）一项都没触发：两次整包日志里 swift error 行 0 条，没有任何 warning 指向 `S2GuideDViews.swift` 或 `IC196GuideDViewsTests.swift`；扫描器与目录双向检查在 XCTest 之前没有红。
- 网络与分类器：`git push -u origin feature/ic-196-s2-guide-d-views` 第一次即成功（git 直连、无代理）；推 `main` 第一次撞上一次 `schannel: failed to receive handshake`，同一条 `git push origin main` 再试第一次即成功（`0e3b1fd..33ce39f main -> main`）；推送之后我写的一条「ls-remote 带重试循环」的复合命令被分类器以 `[Merge Without Review]` 拒绝（命令本身只读、且 `main` 此时已推送完毕），我没有换写法绕过，改用单一用途 `git ls-remote origin refs/heads/main` 一条，通过并读到 `33ce39f6838925a52050168c3d5c349f1f458ba5`。
- 脚本：`materialize_ic196.py`、`gen_ic196_card.py` 未跑（明令不跑）；`sim_ic196.py` 在基线上跑了一次默认形态（`FAILURES 0 []`，XCTest 计数 986 → 991、新增函数名五条逐个对上），`IC196_GATES=1`／`IC196_CLONE=1` 两个开关没开——本地门禁与摘取实测我用自己的命令在真实提交上做了（第五、六节）。`Tasks/decision-tools/` 内未新增、覆盖或留下任何文件（脚本一律 `python -B`，`ls | grep -ci pycache` 为 0）。

## 二、输入、继承提交、目标分支、范围边界

- 任务卡 `<top>/Tasks/IC-20261009-196-s2-guide-d-views.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-196.md`；拆卡与取定 `Tasks/PLAN-S2D-guide-rulings-20261009.md`（第五节是本卡）；登记值对表 `Tasks/RESEARCH-S2-guideD-registry-table.md`（文首抽查注已读）；复核结论 `Tasks/REVIEW-IC-196-findings.md` 第四节「决策会话处置」（已读；复核员的「建议改法」不作指令，改法以卡与 `stages/` 为准）。
- 继承提交 / 基线：`main` = `0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c`（IC-195 报告补记；merge `77246b7403586674da299165b5b2cc664eb3f306`）。开工四步：`git status --porcelain` 空；`git merge-base --is-ancestor 77246b7403586674da299165b5b2cc664eb3f306 main` 退出码 0；`git ls-remote origin refs/heads/main` = `0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c`；两个被改文件基线 blob 与卡面表逐个相等（`project.pbxproj` `0cb33b6255d203de7a997de753a8206755e21377`、`Localizable.xcstrings` `dad2c343364f5e89a32851c10408352aee3b4606`）；本地与远端均无同名分支；先 `git switch -c feature/ic-196-s2-guide-d-views`（自 `0e3b1fd`）再拷文件。
- 目标分支：`feature/ic-196-s2-guide-d-views`，合并入 `main`。
- 范围边界：白名单 4 路径（`project.pbxproj`、新 `S2GuideDViews.swift`、`Localizable.xcstrings`、新 `IC196GuideDViewsTests.swift`），`git diff --name-only 0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c..55ab4c01963999c0539465152d8955afbff4e3ef` 恰这 4 行。`S2View.swift`、`S2InlineHints.swift`、`S2GuideD.swift`、`S2StateMachine.swift`、七条 `s2.hint.*` 与十条 `s2.tutorial.*`、`IC179`／`IC182`／`IC195` 三个既有测试文件、协调器、App、`S2CalibrationConfiguration`（`schemaVersion` 仍 7）、`Scripts/`、`.github/` 一字未动。

## 三、提交列表

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `c83256ac28f8509880b1ce3fd7748371b97c3ce2` | `a9324ee8718c695eeea33766d303d4fee2990c8a` | 新文件 `Features/S2/S2GuideDViews.swift`（1039 行）+ `Localizable.xcstrings` 新增十一条 `s2.guide.*`（289 → 300，+121 行）+ pbx 源码登记四行。3 个文件 |
| B | `55ab4c01963999c0539465152d8955afbff4e3ef` | `c5c3045c2e3ea80509188fbef0cae526c890c6ee` | 新测试 `IC196GuideDViewsTests.swift`（五条，534 行）+ pbx 测试登记四行。2 个文件 |
| 合并 | `33ce39f6838925a52050168c3d5c349f1f458ba5` | `c5c3045c2e3ea80509188fbef0cae526c890c6ee` | `merge(IC-196): S2 教学引导 D 的界面层——登记值、符号、几何与运动、教练卡与完成卡、第 4 步指向、手势示范、进门压暗与两只层视图 + 目录十一条；不接线` |
| docs | 见 `git log`（`main` 上合并之后的下一个提交，仅 `Reports/IC-196/` 两个文件） | — | 本报告与 `change-list.md` |

`git diff --numstat` 基线..B：`project.pbxproj` +8／−0、`S2GuideDViews.swift` +1039／−0、`Localizable.xcstrings` +121／−0、`IC196GuideDViewsTests.swift` +534／−0（合计 1702 增 0 删）。分支推送一次成功（git 直连，无分类器拦截）；推 `main` 一次 `schannel` 失败后第二次成功。

## 四、逐子项提交前对读与拷入文件 `git hash-object`

脚本（scratchpad `ic196-exec/count_A.py`）：读工作树文件，用与测试 `strippedSource` 同口径的剔注释、剔字符串字面量函数（直接 `import` 了 `Tasks/decision-tools/strip.py` 的 `strip_text`，只读），逐条数卡面子项 A「改后」段；提交前跑、全部相符后才提交。

**拷入文件 `git hash-object` 与清单对读**（提交后 `check_ic196.py` 又用 `git rev-parse <tip>:<路径>` 核了一遍，全 PASS）：

| 子项 | 仓库路径 | 清单／卡面 blob | 实测 `git hash-object` | 对读 |
|---|---|---|---|---|
| A | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `0f821fca03ac2bc664940885a79e1a7d4297381c` | `0f821fca03ac2bc664940885a79e1a7d4297381c` | 相等 |
| A | `PhotoCleanupMVE/Features/S2/S2GuideDViews.swift` | `4520fa20951d1bdd827ba4d8c532824a958e2d1d` | `4520fa20951d1bdd827ba4d8c532824a958e2d1d` | 相等 |
| A | `PhotoCleanupMVE/Localizable.xcstrings` | `f4fed78a7381caea6c512384b300c5885f8505d1` | `f4fed78a7381caea6c512384b300c5885f8505d1` | 相等 |
| B | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `f823358d93dd781e30310c5f2b443c681ede0444` | `f823358d93dd781e30310c5f2b443c681ede0444` | 相等 |
| B | `PhotoCleanupMVETests/IC196GuideDViewsTests.swift` | `2dca697954453536d0f45906435d57bda77447f9` | `2dca697954453536d0f45906435d57bda77447f9` | 相等 |

每个子项拷入后 `git status --porcelain` 只列该子项的文件（A：` M project.pbxproj`、` M Localizable.xcstrings`、`?? S2GuideDViews.swift`；B：` M project.pbxproj`、`?? IC196GuideDViewsTests.swift`），按清单逐个 `git add <路径>`（未用 `-A`）。A 提交前 `git diff` 与卡面统一 diff 对读：pbx 四处增行位置与内容逐行相同，`Localizable.xcstrings` 一个 hunk、+121／−0（卡面按两行上下文写成 `@@ -1190,4 +1190,125 @@`，仓库默认三行上下文显示为 `@@ -1189,6 +1189,127 @@`，增行内容相同），十一条 key 插在 `s2.hint.confirm` 之前。

**子项 A「改后」计数实测**（新文件 `S2GuideDViews.swift`；每行「实测／卡面」，0 处不符）

| 检查 | 实测／卡面 |
|---|---|
| 原文 `import ` | 1／1（`SwiftUI`） |
| 原文 `Text("` ／ `return "` | 0／0 ；0／0 |
| 含汉字的代码行（剔注释后） | 0／0（原文非注释行含汉字 0） |
| 剔注释 `@MainActor`、`Material`、`colorScheme`、`GlassEffectContainer`、`UIImage`、`PHAsset`、`UserDefaults`、`S2GuideCoordinator`、`repeatForever`、`withAnimation`、`stripTopFromViewportBottom` | 各 0／0 |
| `L10n.text(` | 11／11 |
| `Button {` | 1／1 |
| `TimelineView(.animation)` | 1／1 |
| `.allowsHitTesting(false)` | 9／9 |
| `.id(step)` | 2／2 |
| `.transition(.opacity)` | 4／4 |
| `.animation(` | 2／2 |
| `S2MarkAfterimageFlight.trashCenter(` | 1／1 |
| `S2OverlayLayout.stripBottomFromViewportBottom(` | 1／1 |
| `S2OverlayLayout.topBarHeight` | 2／2 |
| `S0DeckMetrics.` | 27／27 |
| `S2GuideDMetrics` 切片 `static let` | 87／87 |
| `S2GuideDSymbol` 切片 `static let` | 7／7 |
| 登记族之外的裸数 | 只有 0（17 处）、1（6 处）、2（16 处），无其它 |
| 目录条数 | 289 → 300；`s2.guide.` 恰 11 |

**子项 B「改后」实测**：新测试文件 `func test*` 恰 5 条（`testIC196A`～`E`）；本机剔注释后 `func test*` 行数基线 986、工作树 991（陷阱 22：仅作差值预估，以 CI 为准）；pbx 四处新增行与卡面统一 diff 逐行相同；`git diff --name-only 0e3b1fd..55ab4c0` 恰 4 路径。

## 五、`check_ic196.py` 两段 SUMMARY 与摘取实测

`check_ic196.py` 在刚提交的 tip 上跑（基线取脚本默认值 `0e3b1fd`，`python -B`，在 `Tasks/decision-tools/` 里运行；FAIL 行：无）：

| 段 | tip | SUMMARY | 退出码 |
|---|---|---|---|
| A | `c83256ac28f8509880b1ce3fd7748371b97c3ce2` | `SUMMARY 5 pass / 5`（blob 3 + `changed paths == whitelist (3)` + `base is ancestor`） | 0 |
| B | `55ab4c01963999c0539465152d8955afbff4e3ef` | `SUMMARY 6 pass / 6`（blob 4 + `changed paths == whitelist (4)` + `base is ancestor`） | 0 |
| docs | 见回报 | docs 提交之后补跑（docs 提交自身的 SHA 不写进报告），结果在回传的回报里给出 | — |

另按提示词在基线上跑了一次 `python -B sim_ic196.py`（不带开关）：`FAILURES 0 []`，XCTest 计数 `986 → 991`、`+5`。

**摘取关系实测**（克隆 `git clone --no-hardlinks` 到 scratchpad `ic196-exec/clone`，克隆成功；命令全部 `git -C <克隆>`，从未落到原仓；克隆里自基线 `0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c` 起 `checkout -b`，对我的真实两个提交 `cherry-pick -x`；只证文本无冲突，绿由 CI 证）：

| 组合 | 退出码 | 结果树 | 备注 |
|---|---|---|---|
| A 单独 | 0 | `a9324ee8718c695eeea33766d303d4fee2990c8a` | 与分支上 A 提交的树相同；`git status --porcelain` 空 |
| A → B | 0（两步各 0） | `c5c3045c2e3ea80509188fbef0cae526c890c6ee` | 与分支上 B 提交的树、合并提交的树相同；`git status --porcelain` 空 |

## 六、本地门禁（两个提交各跑一次，贴真实退出码）

`Scripts/selfcheck.ps1` 与 `Scripts/scan-hardcoded-user-visible-strings.ps1` 用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File …`（Windows PowerShell 5.1，在 PowerShell 工具里取 `$LASTEXITCODE`）在仓库根跑；`git diff --cached --check` 在 `git add` 之后、提交之前跑。

| 提交 | `selfcheck.ps1` | `scan-hardcoded-user-visible-strings.ps1` | `git diff --cached --check` |
|---|---|---|---|
| A | 0（「结构自验通过」，140 个 .swift 括号结构通过，扫描 73 个测试源文件交叉审计通过） | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致」） | 0 |
| B | 0（扫描 74 个测试源文件，含新测试文件） | 0（同） | 0 |

## 七、验收门禁逐条（G1075～G1079）

| 门禁 | 结果 | 依据 |
|---|---|---|
| G1075 行为与落位 | 满足 | 第五节：`check_ic196.py` A、B 两个 tip 全 PASS |
| G1076 新断言 | 满足 | 五条 `testIC196*` 在 #396 与 #397 整包日志里全部 passed（第九节）；`IC196_GEOMETRY`（6 行）、`IC196_TEXT`（8 行）、`IC196_DONE`（1 行）、`IC196_LAYER`（7 行）原文见第九节 |
| G1077 不回退 | 满足 | `IC195GuideDLogicTests`（8 条）、`IC182TutorialRoundTwoTests`（5 条）、`IC179InlineHintsTests`（9 条）、`IC146ChromeRoundTwoTests`（19 条）、`S2ActionBarWiringTests`（65 条）在 #396 与 #397 的整包日志里按唯一 Test Case 行数全部 passed、0 failed |
| G1078 合并前置 | 满足 | G1075～G1077 + CI #396 绿（真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 字节数与 SHA-256、分段耗时 notice；摘要 991 与 xcodebuild 小计 991 一致，无需按第 217 条第四节另核，唯一 Test Case 行 991 passed／0 failed）+ 41 条被保护分支 tip 未变（第十一节，推送前、合并前各核一次，合并后再核一次）+ pbxproj 撞号扫描（第十节）+ 工作树净 + `main` 未被他人推进（合并前 `git ls-remote --heads origin` 里 `main` 仍为 `0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c`） |
| G1079 合并后 | 满足 | 合并后 `main` CI #397 绿；artifact 名称／id／有效期见第八节 |

## 八、CI

| 项 | 分支运行 #396 | 合并后 `main` 运行 #397 |
|---|---|---|
| run id | `37981100828` | `37983377590` |
| 被测提交 | `55ab4c01963999c0539465152d8955afbff4e3ef` | `33ce39f6838925a52050168c3d5c349f1f458ba5` |
| 触发 | push 到 `feature/ic-196-s2-guide-d-views` | push 到 `main` |
| 作业起止 | 2026-10-09T19:34:10Z～19:42:18Z | 2026-10-09T19:54:21Z～20:09:53Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 991 项，0 失败（xcodebuild `Executed 991 tests, with 0 failures (0 unexpected) in 47.352 (50.256) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 991 passed／0 failed） | 991 项，0 失败（`Executed 991 tests, with 0 failures (0 unexpected) in 75.322 (79.513) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 991 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 991 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 991 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`） | 0（同） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2037941 字节，SHA-256 `1c55daf471d4c70dcdb66db9208b69ff75b3d2af052846107fbb2695818596a5` | 2037941 字节，SHA-256 `907ecd395f5c89a530679cd904e983b3f13efa5c929acd132796031f89d59a4c`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 61 s；xcodebuild test 288 s；总 349 s` | `模拟器启动 96 s；xcodebuild test 491 s；总 589 s` |
| artifact | `PhotoCleanupMVE-unsigned-55ab4c019639`，id `11641400494`，2038111 字节，有效期至 2027-01-07T19:34:04Z | `PhotoCleanupMVE-unsigned-33ce39f68389`，id `11641474475`，2038111 字节，有效期至 2027-01-07T19:54:13Z |
| 五条 `testIC196*` 用例耗时（日志 `Test Case … passed (N seconds)`） | A `testIC196A_RegistryValuesAndSymbols` 0.009 s；B `testIC196B_GeometryAndMotion` 0.007 s；C `testIC196C_CatalogAndStepPresentation` 0.002 s；D `testIC196D_RenderedSizes` 0.156 s；E `testIC196E_SourceDiscipline` 0.147 s | A 0.013 s；B 0.107 s；C 0.003 s；D 0.240 s；E 0.213 s |

- 两次构建日志里 swift error 行 0 条；warning 在「运行 XCTest」步与「构建未签名应用」步里各为 22 条与 4 条不同的 warning 文本（两次运行相同；我没有另取基线日志比对），没有任何一条指向 `S2GuideDViews.swift` 或 `IC196GuideDViewsTests.swift`；没有类型检查超时、result builder 报错或扫描器红。
- `testIC063`（陷阱 26）两次均未红（红因清单 (6) 未触发）：`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` #396 6.411 s、#397 6.880 s，均 passed；两次日志里 `building pipeline` 均 0 次，各有两行 `Invalidating cache`（既有，与本卡无关）。
- CI 预算 3 次，用了 1 次（#396）；#397 为合并后 `main` 运行，不计入试错预算。

## 九、五条新断言与四类打印原文

五条断言（`PhotoCleanupMVETests/IC196GuideDViewsTests.swift`，逐字节拷入，blob `2dca697954453536d0f45906435d57bda77447f9`，534 行）：

| 断言 | 函数名 | 内容（据卡面 B 节） |
|---|---|---|
| A | `testIC196A_RegistryValuesAndSymbols` | 登记族逐值（87 项，含三个推导量）；D1 协调器阈值 5 与完成秒数 2；七个符号名逐字且 CI 宿主 `UIImage(systemName:)` 非空 |
| B | `testIC196B_GeometryAndMotion` | 教练卡、完成卡、确认入口中心 (355, 84)、小三角、虚线、两圈高亮、压暗框、避让线、示范方向与圆径、箭头与拖尾偏移、圆心落位（含 375×667 第 1 步整体下移到 353）、八个运动采样；两档参考布局下打印 `IC196_GEOMETRY`，只断言包络上缘不高于教练卡下缘 |
| C | `testIC196C_CatalogAndStepPresentation` | 十一条 key 的目录值与 `L10n.text`、`s2.guide.` 恰 11、第 4 步标题带张数、读屏句替换、四步的序号／标题／副句／圆底符号／前置符号 |
| D | `testIC196D_RenderedSizes` | 离屏 `UIHostingController.sizeThatFits`：四步教练卡在 393、375 两档卡宽下高 108、宽不越出卡宽；四步标题与副句自然宽不超过文字区宽（打印 `IC196_TEXT`）；完成卡高 72（打印 `IC196_DONE`）；两只层视图与压暗在无项、完成、四步下构造且不越出提议（打印 `IC196_LAYER`） |
| E | `testIC196E_SourceDiscipline` | 子项 A「改后」计数；每条新 key 在源码里恰写一次；登记族 `static let` 恰为逐值表的名字、每个名字在声明之外被引用 |

**随改的既有断言**：无（卡面未要求）。

**项数对账**：986 + 5 = **991**；#396 与 #397 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行数三者都是 991；提交前本机 `func test*` 行数（剔注释后）986 → 991，IC196 文件 5。

以下四类打印行取自下载的整包 CI 日志（Python `zipfile` 读，「运行 XCTest」步骤文件），按唯一行去重；#396 与 #397 两次的打印行逐行相同（用 `diff` 核过）。

`IC196_GEOMETRY`（6 行）：

```
IC196_GEOMETRY 393x852 step=swipeUp coachBottom=276.0 avoidLine=387.0 discCenter=426.0 discTop=390.0 discBottom=462.0 envelopeTop=310.0 envelopeBottom=504.0 indicator=403.0...449.0 discOverlapsIndicator=true
IC196_GEOMETRY 393x852 step=markedOnce coachBottom=276.0 avoidLine=387.0 discCenter=426.0 discTop=396.0 discBottom=456.0 envelopeTop=354.0 envelopeBottom=536.0 indicator=403.0...449.0 discOverlapsIndicator=true
IC196_GEOMETRY 393x852 step=undone coachBottom=276.0 avoidLine=387.0 discCenter=426.0 discTop=396.0 discBottom=456.0 envelopeTop=360.0 envelopeBottom=466.0 indicator=403.0...449.0 discOverlapsIndicator=true
IC196_GEOMETRY 375x667 step=swipeUp coachBottom=237.0 avoidLine=294.5 discCenter=353.0 discTop=317.0 discBottom=389.0 envelopeTop=237.0 envelopeBottom=431.0 indicator=310.5...356.5 discOverlapsIndicator=true
IC196_GEOMETRY 375x667 step=markedOnce coachBottom=237.0 avoidLine=294.5 discCenter=333.5 discTop=303.5 discBottom=363.5 envelopeTop=261.5 envelopeBottom=443.5 indicator=310.5...356.5 discOverlapsIndicator=true
IC196_GEOMETRY 375x667 step=undone coachBottom=237.0 avoidLine=294.5 discCenter=333.5 discTop=303.5 discBottom=363.5 envelopeTop=267.5 envelopeBottom=373.5 indicator=310.5...356.5 discOverlapsIndicator=true
```

`IC196_TEXT`（8 行）：

```
IC196_TEXT width=393.0 step=swipeUp available=265.0 card=361.3333333333333x108.0 title=143.0 subtitle=214.33333333333331 subtitleHeight=16.333333333333332
IC196_TEXT width=393.0 step=markedOnce available=265.0 card=361.3333333333333x108.0 title=134.33333333333331 subtitle=134.0 subtitleHeight=16.333333333333332
IC196_TEXT width=393.0 step=undone available=265.0 card=361.3333333333333x108.0 title=188.66666666666666 subtitle=161.0 subtitleHeight=16.333333333333332
IC196_TEXT width=393.0 step=confirmEntry available=265.0 card=361.3333333333333x108.0 title=100.33333333333333 subtitle=214.33333333333331 subtitleHeight=16.333333333333332
IC196_TEXT width=375.0 step=swipeUp available=247.0 card=343.0x108.0 title=143.0 subtitle=214.33333333333331 subtitleHeight=16.333333333333332
IC196_TEXT width=375.0 step=markedOnce available=247.0 card=343.0x108.0 title=134.33333333333331 subtitle=134.0 subtitleHeight=16.333333333333332
IC196_TEXT width=375.0 step=undone available=247.0 card=343.0x108.0 title=188.66666666666666 subtitle=161.0 subtitleHeight=16.333333333333332
IC196_TEXT width=375.0 step=confirmEntry available=247.0 card=343.0x108.0 title=100.33333333333333 subtitle=214.33333333333331 subtitleHeight=16.333333333333332
```

`IC196_DONE`（1 行）：

```
IC196_DONE size=159.66666666666666x72.0
```

`IC196_LAYER`（7 行）：

```
IC196_LAYER display=nil cards=393.0x852.0 gesture=393.0x852.0
IC196_LAYER display=Optional(PhotoCleanupMVE.S2GuideDisplay.completion) cards=393.0x852.0 gesture=393.0x852.0
IC196_LAYER display=Optional(PhotoCleanupMVE.S2GuideDisplay.step(PhotoCleanupMVE.S2GuideStep.swipeUp)) cards=393.0x852.0 gesture=393.0x852.0
IC196_LAYER display=Optional(PhotoCleanupMVE.S2GuideDisplay.step(PhotoCleanupMVE.S2GuideStep.markedOnce)) cards=393.0x852.0 gesture=393.0x852.0
IC196_LAYER display=Optional(PhotoCleanupMVE.S2GuideDisplay.step(PhotoCleanupMVE.S2GuideStep.undone)) cards=393.0x852.0 gesture=393.0x852.0
IC196_LAYER display=Optional(PhotoCleanupMVE.S2GuideDisplay.step(PhotoCleanupMVE.S2GuideStep.confirmEntry)) cards=393.0x852.0 gesture=393.0x852.0
IC196_LAYER scrim=393.0x852.0
```

**打印读数（只转述，不判、不推翻卡面；两条未定项的取舍归 D2b）**：

- 未定项 38（示范与中央状态指示叠放）：六个参考布局档位 `discOverlapsIndicator` 全为 `true`——393×852 三步示范圆（上缘 390～396、下缘 456～462）都与中央指示竖向范围 403.0～449.0 重叠；375×667 同样三步全重叠（圆 303.5～389、指示 310.5～356.5）。即按本卡的落位（圆心取主图显示帧竖直中心）示范圆与中央指示在竖向上重叠；D2b 的 z 序预案（示范在中央指示之下）与观感判定见 `PLAN-S2D-guide-rulings-20261009.md` 第六节。
- 375×667 第 1 步：包络上缘 237.0 恰等于教练卡下缘 237.0，圆心 353.0（主图中心 333.5 被压到教练卡下缘 + 单元高出量）——整体下移规则生效；393×852 三步包络上缘（310／354／360）都在教练卡下缘 276 之下。
- 未定项 37（文字宽度）：中文四步标题最宽 188.67（`undone`）、副句最宽 214.33（`swipeUp`／`confirmEntry`），393 档文字区 265、375 档 247，余量分别不小于 50.7 与 32.7；副句单行高 16.33（小于行高 18 的框）。英文目录尚无，未测。
- 完成卡 159.67×72；两只层视图与压暗在无项、完成、四步下都构造成功并回报 393×852（弹性框吃满提议，卡面说明不判）。

## 十、pbxproj 撞号扫描与四个新 id

- 推进前扫描：基线最大号 fileRef `100000000000000000000098`、buildFile `200000000000000000000095`（IC-195；十六进制）。B 提交前对工作树 `project.pbxproj`：`PBXBuildFile`／`PBXFileReference` 等对象定义共 326 条，重复 id `[]`；最大号 fileRef `10000000000000000000009A`、buildFile `200000000000000000000097`。
- 四个新 id 各自在全文的出现次数：`100000000000000000000099` 3 次（定义 + buildFile 引用 + 组 children）、`10000000000000000000009A` 3 次、`200000000000000000000096` 2 次（定义 + Sources 阶段）、`200000000000000000000097` 2 次；每个都只有 1 处定义。`sim_ic196.py` 的「pbx ids next free (hex)」也相符。
- 四个新 id：源码 fileRef `100000000000000000000099`／buildFile `200000000000000000000096`（`S2GuideDViews.swift`，接在 `S2GuideD.swift` 之后）；测试 fileRef `10000000000000000000009A`／buildFile `200000000000000000000097`（`IC196GuideDViewsTests.swift`，接在 `IC195GuideDLogicTests.swift` 之后）。

## 十一、G1078 被保护分支核对

清单 `Tasks/decision-tools/ic196_protected_branches.txt` 恰 41 行（`分支名 SHA`，无注释行）。对 `git ls-remote --heads origin` 逐条比对：推送前（远端 114 个 head）、推送后 CI 期间与合并前（115 个 head，多出本分支）、合并并推送 `main` 之后（115 个 head）三次——**不符 0 条（41／41 相等）**；合并前相比推送前变化的 head 只有本分支，合并后相比合并前变化的 head 只有 `main`。比对脚本遇 `ls-remote` 返回空即重试，空列表不算比对（本次每次第一次返回即非空）。合并后 `main` = `33ce39f6838925a52050168c3d5c349f1f458ba5`。

## 十二、规格欠账（卡面九条，本卡不改任何规格；原文见任务卡「规格欠账」节，归下一次 S2 修订）

1. 目录十一条 `s2.guide.*`（键名由实装卡登记，规格 `:446`），其中 `s2.guide.progress`「第 {current} 步，共 {total} 步」是四点指示的读屏句（画布 `aria-label`），规格未登记。
2. 完成提示只有标题（④ 第 223 条），`doneSubtitleFontSize` 13 与上距 2 不实装、副句 key 不登记，IC-181 加回。
3. 规格注释里的数补名登记（内描边白 0.16／0.10、点圆角与两档点不透明度、跳过钮前景 0.62／留白 4／命中区 44、副句 0.66 与行高 18、小三角转角 45°、虚线距圆钮 8 与长 48、箭头圆阴影 4／14／0.45、拖尾起点 0.95 与外描 1.5／0.45）。
4. 画布线宽在 SF Symbol 上映射为字重（手 `.medium`、其余 `.bold`，③）。
5. 虚线段 6／隙 4（画布 CSS `dashed` 不给段长，③）。
6. 手势示范落位：圆心在主图显示帧竖直中心、运动中压到教练卡才整体下移（K3「由实装卡取定」的落实）。
7. 进门压暗框 = 顶排下缘到横栏视觉顶缘的整条带，不随显示帧移动（计划裁定 4 的落实；K4 主读法「只盖显示帧」改为备选）。
8. 示范运动用 `TimelineView(.animation)` + 纯函数逐帧求值（左右滑交替且每周期淡出，`repeatForever` 做不出；③，D2b 的 H 判定看卡顿）。
9. 副句行高 18 落为单行框高。

**D2b 前置（卡「范围外」与 PLAN 第六节，只转述）**：`S2View` 接线与旧三句退役、七条 `s2.hint.*` 删除、IC179／IC182 改写、`IC195GuideDLogicTests.testIC195H_SourceWiring` 末段改写归 D2b；确认入口高亮环与数字徽标叠放（复核 ③5）与教练卡上缘比画布稿低 4 pt（③7）记在 PLAN 第六节 6a。

## 十三、docs 提交与最终核验

- 惯例 44：本报告与 `change-list.md` 随合并与合并后 `main` 运行之后的**恰一个 docs 提交**落在 `main` 上（仅 `Reports/IC-196/` 两个文件，`Reports/**` 命中 `ci.yml` 的 `paths-ignore`，该提交不触发 CI）。
- 报告写完后，对报告里出现的每个 40 位 SHA 跑了 `git cat-file -e <sha>^{<类型>}`：结果见本文末「报告内 SHA 核验」。

## 十四、人工判定项

**无。** 本卡不接线，没有界面变化，运行中的引导仍是 v23 三句；夹具驱动的测试只验登记值、纯几何与运动、目录与离屏尺寸，视图观感、层级、命中、动画与两处未定项（37、38）的取舍归 D2b 的 H 判定。

## 十五、发现但未处理的问题（按纪律只报告不修）

1. 无产品或卡面缺陷发现。执行中没有偏离卡面的改动。
2. 第九节的两条读数（示范圆与中央状态指示在全部六个参考档位竖向重叠；375×667 第 1 步整体下移生效）是未定项 38 的实测数据，卡面明确只打印不判，交 D2b。
3. 工具备注（非缺陷）：`git merge -F -` 不支持从标准输入读消息，第一次合并命令因此以退出码 129 失败、未产生任何合并（`main` 与工作树未动）；改用 scratchpad 里的消息文件 `-F <文件>` 一次成功。
4. 推 `main` 后的一条复合只读命令被分类器 `[Merge Without Review]` 拒绝（见第一节），没有绕过，单一用途 `git ls-remote origin refs/heads/main` 通过；若决策会话想统计该分类器对「推送后核验命令」的误拦，这是一例。
5. 仓库里有两个先前就存在的 stash（`stash@{0}`、`stash@{1}`，均挂在 `feature/ic-067-screenshot-detection` 上），不是本卡产生的，未动。
6. 合并后 `main` 运行的前台等待我用了有上限的短轮询（每次不超过 9 分钟）；两次 run 都在推送后约 1 分钟内出现在 API 里；起的两个后台轮询进程都已自行退出（`DONE` 后 exit 0）。

## 报告内 SHA 核验

两份报告里出现的全部 40 位 SHA（去重后见下表，正则按前后非十六进制字符取，SHA-256 不会被误取）逐个跑 `git cat-file -e <sha>^{<类型>}`，退出码全 0，缺失 0 个（IPA 的 SHA-256 `1c55daf4…`、`907ecd39…` 不是 git 对象，不在此表）：

| SHA | 对象类型 | `cat-file -e` 退出码 |
|---|---|---|
| `c83256ac28f8509880b1ce3fd7748371b97c3ce2` | commit | 0 |
| `55ab4c01963999c0539465152d8955afbff4e3ef` | commit | 0 |
| `33ce39f6838925a52050168c3d5c349f1f458ba5` | commit | 0 |
| `0e3b1fdbe6c9ef402deae02ebcc6c9d9c080836c` | commit | 0 |
| `c5c3045c2e3ea80509188fbef0cae526c890c6ee` | tree | 0 |
| `77246b7403586674da299165b5b2cc664eb3f306` | commit | 0 |
| `0cb33b6255d203de7a997de753a8206755e21377` | blob | 0 |
| `dad2c343364f5e89a32851c10408352aee3b4606` | blob | 0 |
| `a9324ee8718c695eeea33766d303d4fee2990c8a` | tree | 0 |
| `0f821fca03ac2bc664940885a79e1a7d4297381c` | blob | 0 |
| `4520fa20951d1bdd827ba4d8c532824a958e2d1d` | blob | 0 |
| `f4fed78a7381caea6c512384b300c5885f8505d1` | blob | 0 |
| `f823358d93dd781e30310c5f2b443c681ede0444` | blob | 0 |
| `2dca697954453536d0f45906435d57bda77447f9` | blob | 0 |

共 14 个，缺失／不通过 0 个。
