# IC-201 自验报告

## 一、结论（先行）

- **唯一子项 A 按卡面完成（逐字节拷入 `ic201/stages/A/` 的成品，未手改一行），G1105～G1109 全部满足，已 `--no-ff` 合并入 `main` 并推送。** 分支 `feature/ic-201-probe-host`，提交 A `a1e903ae5189ab3e37a1af33f27ad5050bd6a833`；合并提交 `f78dc7a5e4b8fd7284daa0a62ce152f4bc645645`（双亲 `50aec33642ed8c1e733a154fd1cd3467862bacef`／`a1e903ae5189ab3e37a1af33f27ad5050bd6a833`，树 `d2744e97747baebde2889db36c6a8d4e03b5f0de` 与 A 提交的树相同）。
- 分支 CI **#406**（run `38016225089`，被测提交 A）一次绿：**995 项 0 失败**（项数不变），`xcodebuild` 输出 `Executed 995 tests, with 0 failures` 与 `** TEST SUCCEEDED **`，「运行 XCTest」步骤 success（真实退出码 0，日志 `XCTest 已全部通过。`），目的地 `OS:26.2, name:iPhone 16`，IPA 2101127 字节。合并后 `main` CI **#407**（run `38017249393`，被测提交为合并提交）同样一次绿，995 项 0 失败。CI 预算 3 次，用了 1 次（#407 为合并后 `main` 运行，不计入试错预算）。
- **本卡唯一产出——`testIC200D` 打印的四行 `IC200_PROBE`——两次运行读数逐字相同，原文见第九节。** 四行都是 `scene=true key=true`（取到了窗口场景、窗口是 key window）。按卡面「读法」节，我只抄原文、不据此判红绿、不改任何东西；读法表的判定留给决策会话。我只附一句观察：四行里 `control-task` 的 `before` 偏移 1441、`control-outer` 的 `after` 偏移 1441、`nested-reader` 的 `after` 偏移 1441，`restore-600` 的 `before` 偏移 541，内距都是 59（1500 − 59 = 1441，600 − 59 = 541）。
- 报告采用**惯例 44**：合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交（本报告与 `change-list.md`）。
- **无界面变化，无人工判定项。** 产品零改动、pbxproj 不动、项数不变；`testIC200A`～`C` 一字不动。
- 执行端没有偏离卡面；停下没做的事：无。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 内容 |
|---|---|
| 任务卡 | `D:\IPHONE PHOTO MANAGEMENT\Tasks\IC-20261009-201-probe-host.md`；执行提示词 `Tasks/EXECUTOR-PROMPT-IC-201.md` |
| 基线 | `main` = `50aec33642ed8c1e733a154fd1cd3467862bacef`（IC-200 报告补记；其 merge `c889ca64239b3b9e720765060453c856865be569`） |
| 目标分支 | `feature/ic-201-probe-host`（自基线切出，先切分支再改文件） |
| 白名单 | 恰 1 个路径：`PhotoCleanupMVETests/IC200ScrollRestoreTests.swift`（不含报告） |
| 范围边界 | 只改测试 D（`testIC200D_ProbeRestoreAndNestedReaderInWindow`）、它的两个 helper 和文件末的探针视图；不动产品、pbx、目录、其它测试、SPEC、Decision_log |
| 改法 | 决策会话预置的成品 `Tasks/decision-tools/ic201/stages/A/PhotoCleanupMVETests/IC200ScrollRestoreTests.swift`（清单 `ic201/stages/manifest.json`），逐字节拷入；未跑 `materialize_ic201.py`、`gen_ic201_card.py` |
| 开工检查 | `git status --porcelain` 空；`git merge-base --is-ancestor c889ca64239b3b9e720765060453c856865be569 main` 退出码 0；`git ls-remote origin refs/heads/main` = 本地 `50aec33642ed8c1e733a154fd1cd3467862bacef`；基线 blob `git rev-parse HEAD:PhotoCleanupMVETests/IC200ScrollRestoreTests.swift` = `e7cd9252c6c7283d5ca867252c1c90f53efa86b8`（与卡面相等）；远端无同名分支；两个更早的 stash（挂在 `feature/ic-067-screenshot-detection`）与两个外部 worktree 未动 |

## 三、提交列表

| 提交 | 内容 | SHA |
|---|---|---|
| A | `IC-201 A：IC-200 探针宿主补强——测试 D 改用窗口场景宿主 + 两个正对照（只改测试、只打印）` | `a1e903ae5189ab3e37a1af33f27ad5050bd6a833` |
| 合并 | `merge(IC-201): IC-200 探针宿主补强——窗口场景宿主 + 两个正对照（只改测试）`（`--no-ff -F <消息文件>`） | `f78dc7a5e4b8fd7284daa0a62ce152f4bc645645` |
| docs | 本报告与 `change-list.md`（合并与合并后运行之后落在 `main` 上，惯例 44） | 提交后见 `git log`（自身 SHA 不入报告） |

## 四、拷入文件 `git hash-object` 与清单对读

| 文件 | 清单值（`manifest.json`） | 拷入后 `git hash-object` | 提交后 `git rev-parse HEAD:<路径>` | 合并后 `git rev-parse main:<路径>` |
|---|---|---|---|---|
| `PhotoCleanupMVETests/IC200ScrollRestoreTests.swift` | `6e7ee80d0646d03621b0d6a22c0934b362171c7f` | `6e7ee80d0646d03621b0d6a22c0934b362171c7f` | `6e7ee80d0646d03621b0d6a22c0934b362171c7f` | `6e7ee80d0646d03621b0d6a22c0934b362171c7f` |

- 拷入后 `git status --porcelain` 只列该文件（` M`）；`git add` 单一路径；`git diff --stat` 为 1 个文件、105 增 29 删，与卡面差分逐块对读一致（测试 D 函数体换为四次 `runProbe` 调用、新增 `runProbe`／`describe`／`scrollView(in:)` 三个 `@MainActor` helper、文件末新增 `IC200ProbeCells`／`IC200ControlView`／`IC200RestoreProbeView`、`IC200ProbeView` 内格子抽成 `IC200ProbeCells()`）。
- 基线 blob `e7cd9252c6c7283d5ca867252c1c90f53efa86b8` → 新 blob `6e7ee80d0646d03621b0d6a22c0934b362171c7f`；文件现 456 行。

## 五、`check_ic201.py`、`sim_ic201.py` 与摘取实测

- `python -B check_ic201.py a1e903ae5189ab3e37a1af33f27ad5050bd6a833 A`（`IC_REPO` 指向仓库）：

```
PASS blob PhotoCleanupMVETests/IC200ScrollRestoreTests.swift
PASS changed paths == whitelist (1)
PASS base is ancestor
SUMMARY 3 pass / 3
```

  退出码 0。（卡面事实基础写的「`check_ic201.py` 对照（`ctl_ic201.py`）4／4」是决策会话对照脚本的计数，不是该脚本本身的 SUMMARY；本脚本 SUMMARY 为 3／3，无不符。）
- `python -B sim_ic201.py`（只对基线跑，`IC201_GATES=1`、`IC201_CLONE=1`）：全部 `ok`，末行 `FAILURES 0 []`，退出码 0。含：替换逐字命中；A／B／C 三个测试函数体逐字不变；文件里测试函数 4 个；D 四个探针、零 `XCTAssert`／`XCTUnwrap`；三个 helper 都 `@MainActor`；新视图名在测试目标里不重；先例宿主四行在 `S2CalibrationHarnessTests` 原文存在；基线加改后全树上两个本地门禁脚本退出码 0；克隆里 `cherry-pick -x` 退出码 0。
- **摘取关系实测（我自己的克隆，非 sim 的）**：`git -c core.autocrlf=false clone --no-hardlinks -q <仓库> <scratchpad>/ic201-exec/clone`（退出码 0；克隆目录存在才继续）；克隆里 `checkout -b pick 50aec33642ed8c1e733a154fd1cd3467862bacef`（退出码 0）→ `git -C <克隆> cherry-pick -x a1e903ae5189ab3e37a1af33f27ad5050bd6a833`，**退出码 0**，新提交 `233c2e5`（仅存在于克隆）；摘取后克隆内该文件 blob = `6e7ee80d0646d03621b0d6a22c0934b362171c7f`。所有命令带 `git -C <克隆>`，没有落到原仓。

## 六、本地门禁（真实退出码）

| 门禁 | 时机 | 真实退出码 |
|---|---|---|
| `Scripts/selfcheck.ps1` | A 暂存后、提交前 | 0（末行「结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。」） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 同上 | 0（「扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。」） |
| `git diff --cached --check` | 同上 | 0 |

## 七、验收门禁逐条（G1105～G1109）

| 门禁 | 内容 | 结果 |
|---|---|---|
| G1105 | `check_ic201.py <A 的 tip> A` 全 PASS | 满足（第五节，3／3，退出码 0） |
| G1106 | `testIC200A`～`D` passed；整包日志里抄出 `testIC200D` 四行 `IC200_PROBE`（分支与合并后各一份） | 满足：四条 `testIC200*` 两次运行均 passed（耗时见第八节）；四行原文见第九节（两份读数相同） |
| G1107 | XCTest 仍 995 项 0 失败 | 满足：#406 与 #407 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行（995 started／995 passed／0 failed／0 已开始未结束）三者一致 |
| G1108 | 合并前置：G1105～G1107 + CI 绿（退出码 0、目的地、IPA、分段耗时）+ 46 条被保护分支 tip 未变 + 工作树净 + `main` 未被他人推进 | 满足：合并前再核一次 `ls-remote`（120 个 head），46／46 相等、`main` 仍 `50aec33642ed8c1e733a154fd1cd3467862bacef`、工作树净 |
| G1109 | 合并后 `main` 运行绿，报告记 artifact 名称／id／有效期 | 满足：#407 绿；artifact `PhotoCleanupMVE-unsigned-f78dc7a5e4b8`，id `11657260317`，2101297 字节，有效期至 2027-01-08T02:31:00Z |

## 八、CI

| 项 | 分支运行 #406 | 合并后 `main` 运行 #407 |
|---|---|---|
| run id | `38016225089` | `38017249393` |
| 被测提交 | `a1e903ae5189ab3e37a1af33f27ad5050bd6a833` | `f78dc7a5e4b8fd7284daa0a62ce152f4bc645645` |
| 触发 | push 到 `feature/ic-201-probe-host` | push 到 `main` |
| 作业起止 | 2026-10-10T02:14:31Z～02:28:54Z | 2026-10-10T02:31:07Z～02:41:40Z |
| 结论 | success，十二步全 success | success，十二步全 success |
| XCTest 项数 | 995 项，0 失败（xcodebuild `Executed 995 tests, with 0 failures (0 unexpected) in 74.579 (76.373) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 995 passed／0 failed／0 已开始未结束） | 995 项，0 失败（`Executed 995 tests, with 0 failures (0 unexpected) in 54.087 (58.229) seconds`，`** TEST SUCCEEDED **`；唯一 Test Case 行 995 passed／0 failed） |
| 执行摘要 notice 原文 | `Executed 995 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 995 tests / 0 failures`（与 xcodebuild 小计一致） | 同 |
| 真实退出码 | 0（第 9 步「运行 XCTest」success；脚本末 `exit "$test_status"`；日志 `XCTest 已全部通过。`） | 0（同） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`；xcodebuild 匹配行 `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同一两行、同一 id |
| IPA | `PhotoCleanupMVE-unsigned.ipa` 2101127 字节，SHA-256 `2c36427469bf961a155f2976876c0cd42647165103c0633fa40b43dd1e80ec8f` | 2101127 字节，SHA-256 `1f5d0dc8beafc50e7c3799814f8adfa4822b128befaeeed916559afc371ed90a`（IPA 不可复现，两次哈希不同是预期） |
| `XCTest 分段耗时` notice 原文 | `模拟器启动 102 s；xcodebuild test 471 s；总 575 s` | `模拟器启动 91 s；xcodebuild test 390 s；总 482 s` |
| artifact | `PhotoCleanupMVE-unsigned-a1e903ae5189`，id `11656662165`，2101297 字节，有效期至 2027-01-08T02:14:23Z | `PhotoCleanupMVE-unsigned-f78dc7a5e4b8`，id `11657260317`，2101297 字节，有效期至 2027-01-08T02:31:00Z |
| 四条 `testIC200*` 耗时（日志 `Test Case … passed (N seconds)`） | `testIC200A` 0.001 s；`testIC200B` 0.000 s；`testIC200C` 0.210 s；`testIC200D` 5.063 s | `testIC200A` 0.001 s；`testIC200B` 0.001 s；`testIC200C` 0.181 s；`testIC200D` 5.053 s |

- 两次构建日志里 swift error 行 0 条；`warning:` 行各 51 条（#406 日志按文件与信息归并为 15 种），指向 `IC200ScrollRestoreTests.swift` 的 0 条（均落在 `S2View`／`S2NativePhotoPager`／`S2CalibrationHarnessTests` 等既有文件与 AppIntents 提示），没有类型检查超时、result builder 报错或扫描器红。整包日志里出现一次 `** TEST FAILED **` 字样是工作流自测步骤脚本的源码回显（`many_test_failed_lines=…`，陷阱 25 的 ANSI 回显），不是实跑输出；真实输出只有 `** TEST SUCCEEDED **`。
- `testIC063`（陷阱 26）两次均未红（红因清单 (4) 未触发）：#406 6.299 s、#407 6.249 s passed；两次日志里 `building pipeline` 均 0 次，各有两处 `Invalidating cache`。红因清单 (1)～(3) 也都没触发。
- `testIC200D` 耗时约 5 s，来自 4 次 `runProbe` 里各 1.0 s 出现等待 + 有 `box` 的两次再等 0.5 s + 窗口创建；探针不断言，不影响判红绿。
- 项数对账：基线 995，本卡不增减测试函数（文件里 `func test` 仍 4 条，sim 已核）；#406、#407 的 xcodebuild 小计、摘要 notice、唯一 Test Case 行数三者都是 995。
- 摘要 notice 与 xcodebuild 小计一致，无需按卡面「不一致时以 xcodebuild 为准」的分支。

## 九、`testIC200D` 打印的四行 `IC200_PROBE` 原文（本卡唯一产出）

**分支运行 #406**（整包日志 `0_构建、XCTest 与未签名产物.txt` 里原行，含时间戳前缀；只取这一份作业日志，没有把逐步日志重复抄一遍）：

```
2026-10-10T02:24:55.5501650Z IC200_PROBE control-task scene=true key=true before=1441.0/59.0/3000.0
2026-10-10T02:24:57.1154870Z IC200_PROBE control-outer scene=true key=true before=-59.0/59.0/3000.0 after=1441.0/59.0/3000.0 proxy=true
2026-10-10T02:24:58.0700190Z IC200_PROBE restore-600 scene=true key=true before=541.0/59.0/3000.0 memory=600.0
2026-10-10T02:24:59.5903110Z IC200_PROBE nested-reader scene=true key=true before=-59.0/59.0/3000.0 after=1441.0/59.0/3000.0 proxy=true memory=1500.0
```

**合并后 `main` 运行 #407**（同上取法）：

```
2026-10-10T02:38:31.5954040Z IC200_PROBE control-task scene=true key=true before=1441.0/59.0/3000.0
2026-10-10T02:38:33.0871700Z IC200_PROBE control-outer scene=true key=true before=-59.0/59.0/3000.0 after=1441.0/59.0/3000.0 proxy=true
2026-10-10T02:38:34.0715140Z IC200_PROBE restore-600 scene=true key=true before=541.0/59.0/3000.0 memory=600.0
2026-10-10T02:38:35.5538310Z IC200_PROBE nested-reader scene=true key=true before=-59.0/59.0/3000.0 after=1441.0/59.0/3000.0 proxy=true memory=1500.0
```

两份读数除时间戳外逐字相同。字段含义（据卡面「读法」节）：`before`／`after` = `contentOffset.y`／`adjustedContentInset.top`／`contentSize.height`；第 30 格顶部在内容里的 y = 1500；`scene=true` 表示取到了已连接的窗口场景（没有退回旧宿主）。

**观察（一句，不据此判红绿）：** 四行都是 `scene=true key=true`，内距 59、内容高 3000；`control-task` 在 `.task` 里滚后读到 1441、`control-outer` 经 proxy 滚前 −59 滚后 1441、`restore-600` 恢复后读到 541、`nested-reader` 经外层 proxy 滚前 −59 滚后 1441——数字与卡面「读法」表第二行（动到第 30 格／restore ≈ 600 − 内距／nested ≈ 1500 − 内距）的算术形式相符；表的判定和是否出修正卡由决策会话下，我不下结论。

## 十、G1108 被保护分支核对

清单 `Tasks/decision-tools/ic201_protected_branches.txt` 恰 46 行（`分支名 SHA`）。对 `git ls-remote --heads origin` 逐条比对三次：推送分支之前（远端 119 个 head，不含本分支）、推送分支后合并之前（120，含本分支）、合并并推送 `main` 之后（120）——**不符 0 条（46／46 相等）**；比对脚本（scratchpad `ic201-exec/cmp_protected.py`）遇空列表即断言失败（空列表不算比对），本次三次第一次返回即非空。合并前 `main` = `50aec33642ed8c1e733a154fd1cd3467862bacef`，合并后 `main` = `f78dc7a5e4b8fd7284daa0a62ce152f4bc645645`（`git ls-remote origin refs/heads/main` 复核一致）。

## 十一、发现但未处理的问题（按纪律只报告不修）

1. （③，仅供决策会话参考，未改任何东西）四行里 `memory` 的值与 `contentOffset.y` 之差正好等于 `adjustedContentInset.top`：`restore-600` 记忆 600、读到 541；`nested-reader` 记忆 1500、滚后读到 1441；差都是 59。就是说容器记下的偏移与恢复所用的偏移在这个宿主里用的是同一个口径（含顶部内距），这与 IC-200 第十四节发现 1 里复核 N3「坐标原点可能差一个安全区高度」的担心方向一致，但本探针不做往返，也没有测第二次保存，所以**不证明也不证伪不漂移**；真机 H105 第 12 条仍是兜底。
2. 其余：红因清单 (1)～(4) 一项都没触发；没有执行端偏离卡面；没有发现卡面与基线不符的事实（基线 blob、拷入 blob、`check_ic201.py`、`sim_ic201.py` 全部相符）。唯一的小出入是卡面事实基础「`check_ic201.py` 对照 4／4」与脚本本身 SUMMARY 3／3 的口径差（第五节已说明，不是红）。
3. 工作树收尾：本卡结束时仓库在 `main`、工作树净；我起的轮询进程（`wait_run.py`、`wait_file.py`）都已退出（`tasklist` 查无 python／gh 进程）。

## 十二、SHA 核验（陷阱 15）

本报告与 `change-list.md` 写完后，用脚本（scratchpad `ic201-exec/sha_verify.py`）取两份文件里出现的每一个 40 位十六进制串（排除属于更长十六进制串的片段，SHA-256 不在其内），先 `git cat-file -t` 取类型、再 `git cat-file -e <sha>^{类型}` 核存在；结果见下表（docs 提交自身的 SHA 不在报告里，故不核；克隆里的摘取提交只写 7 位 `233c2e5`，不在 40 位核验范围）。

共 7 个，退出码非 0 的 0 个。

| SHA | 类型 | `git cat-file -e <sha>^{类型}` 退出码 |
|---|---|---|
| `50aec33642ed8c1e733a154fd1cd3467862bacef` | commit | 0 |
| `6e7ee80d0646d03621b0d6a22c0934b362171c7f` | blob | 0 |
| `a1e903ae5189ab3e37a1af33f27ad5050bd6a833` | commit | 0 |
| `c889ca64239b3b9e720765060453c856865be569` | commit | 0 |
| `d2744e97747baebde2889db36c6a8d4e03b5f0de` | tree | 0 |
| `e7cd9252c6c7283d5ca867252c1c90f53efa86b8` | blob | 0 |
| `f78dc7a5e4b8fd7284daa0a62ce152f4bc645645` | commit | 0 |
