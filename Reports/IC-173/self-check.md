# IC-173 自验报告

## 一、结论（先行）

**闸门 G975 满足，一次 CI 即绿，探针数据已完整取得。** 分支 `probe/ic-173-material-dark-env`，唯一子项 A 提交 `833e74cea6524ac5c5f860ae50d71656f54ec457`，push 后 CI **#352 一次绿（898／0）**。子项 A 的判定测试 `testIC173A_HarnessSeesMaterialAppearance` 通过（未见于任何失败列表），其余五条无断言测试（B～F）均正常执行完毕。整包日志里的全部 **27 行 `IC173_PROBE`** 原文已按出现顺序完整摘录于第六节，一行不漏。**本卡不做归因、不下结论**，数据交决策会话判读。

- **不合并、不动 `main`、不动 IC-172 分支**：`main` 仍为 `467fe74a0323c98e938142a2107f16843d21cc96`，`feature/ic-172-glass-always-dark` 仍为 `3cf48335bdf1153f5f349e985fce3f5c2abefa29`，均未变动（第九节核对）。
- CI 预算：1／3 已用（预期只用 1，未再推）。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260924-173-material-dark-env-probe.md` |
| 前置阅读 | IC-172 停卡报告（`git show 3cf4833:Reports/IC-172/self-check.md`）、`<top>/Tasks/REVIEW-IC-173-findings.md`（复核结论：可以下发） |
| 基线 `main` | `467fe74a0323c98e938142a2107f16843d21cc96`（全程未变） |
| 开工核对 1 | `git status --porcelain` 空 |
| 开工核对 2 | `git merge-base --is-ancestor e356aeda17da53a064892e04f39bea1032f5bf8d main` 退出码 0（IC-171 merge 是 main 祖先）；另核 `git merge-base --is-ancestor 3cf48335bdf1153f5f349e985fce3f5c2abefa29 main` 退出码 1（IC-172 分支确未合并进 main） |
| 开工核对 3 | `git ls-remote origin refs/heads/main` = `467fe74a0323c98e938142a2107f16843d21cc96`，与本地一致 |
| 分支 | `probe/ic-173-material-dark-env`，自上述基线 `git switch -c` 切出 |
| 分支 tip | `833e74cea6524ac5c5f860ae50d71656f54ec457`（子项 A，唯一提交） |
| `schemaVersion` | 7（未动） |
| `S0DeckMetrics` 登记值 | 195（未动，本卡不改产品文件） |
| 文案目录 | 259（未动） |
| **是否合并** | **否——探针卡，本卡不授权合并** |
| **CI 预算** | 1／3（预期只用 1，实际只用 1） |
| **范围边界** | 只新增一个测试文件 + pbxproj 登记 + 本报告目录；不动任何产品文件、IC-172 分支、SPEC、Decision_log |

---

## 三、提交列表

| 序 | 提交 SHA | 内容 |
|---|---|---|
| A | `833e74cea6524ac5c5f860ae50d71656f54ec457` | 新增 `PhotoCleanupMVETests/IC173MaterialDarkEnvironmentProbeTests.swift`（决策会话写，逐字节拷入）+ pbxproj 登记一个测试文件 |

`git cat-file -e` 核验存在，见第十二节。

---

## 四、子项 A 校验（可核计数逐条对读）

### 测试文件拷入校验

| 核对项 | 卡面要求值 | 实测值 | 结果 |
|---|---|---|---|
| 源文件 `git hash-object`（`<top>/Tasks/decision-tools/IC173MaterialDarkEnvironmentProbeTests.swift`） | `a7154bbe866d2d79d3d0533f2a72562cd7cc174a` | `a7154bbe866d2d79d3d0533f2a72562cd7cc174a` | 一致 |
| 拷入后 `git hash-object`（`PhotoCleanupMVETests/IC173MaterialDarkEnvironmentProbeTests.swift`） | `a7154bbe866d2d79d3d0533f2a72562cd7cc174a` | `a7154bbe866d2d79d3d0533f2a72562cd7cc174a` | 一致（用 `cp` 逐字节拷入，未手工改动任何一行） |
| `func test` 数量 | 6 | 6 | 一致 |
| 文件行数 | — | 314 | 记录备查 |

### pbxproj 登记校验

采用与 IC-171/IC-172 相同的四行登记写法（`PBXBuildFile` 定义、`PBXFileReference` 定义、`PBXGroup`（文件引用组）成员、`PBXSourcesBuildPhase`（测试目标编译清单）成员），紧接在 IC-171 已登记的最后一条测试文件（`IC171CategoryPageTrioTests.swift`，`074`／`071`）之后插入。

| 核对项 | 卡面要求值 | 实测值 | 结果 |
|---|---|---|---|
| `main` 上 `100000000000000000000090` 命中数 | 0 | 0 | 一致（登记前重扫，无撞号） |
| `main` 上 `200000000000000000000090` 命中数 | 0 | 0 | 一致（登记前重扫，无撞号） |
| 登记后 `100000000000000000000090`（fileRef）总命中数 | 恰 3 处 | 3 处（定义 1 + 文件引用组 1 + Sources 编译清单内以 fileRef 形式出现 1，具体见下） | 一致 |
| 登记后 `200000000000000000000090`（buildFile）总命中数 | 恰 2 处 | 2 处（定义 1 + Sources 编译清单 1） | 一致 |
| 定义行 `uniq -d`（`isa = PBXFileReference`／`PBXBuildFile` 定义行按 id 去重） | 空 | 空 | 一致，无撞号 |
| `git diff --name-only 467fe74a..833e74c` | 恰 2 路径 | 恰 2 路径（`PhotoCleanupMVE.xcodeproj/project.pbxproj`、`PhotoCleanupMVETests/IC173MaterialDarkEnvironmentProbeTests.swift`） | 一致 |

**结论：子项 A 全部可核计数与卡面值逐一相符，无一处偏离。测试文件逐字节未改动任何一行（编译通过，无需贴编译错误）。**

---

## 五、CI 结果

### 运行：#352（run id `35995966216`），commit `833e74cea6524ac5c5f860ae50d71656f54ec457`

- 结论：`completed` / `success`，全部 12 步骤 `success`（含步骤 9「运行 XCTest」`success`）
- 真实退出码：**0**（步骤 9 结论 `success`；日志末尾 `** TEST SUCCEEDED **` / `XCTest 已全部通过。`；未出现 `Process completed with exit code` 类失败标记；工作流 `set -o pipefail` 且 `exit "$test_status"` 原样退出）
- **XCTest 执行摘要**：`##[notice]Executed 898 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 898 tests / 0 failures`
- **XCTest 分段耗时**：`XCTest 分段耗时：模拟器启动 99 s；xcodebuild test 453 s；总 553 s`
- **目的地实证行**：`--- xcodebuild: WARNING: Using the first of multiple matching destinations:` 后 `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`；另 `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`
- **未签名 IPA 校验**：`##[notice]文件=PhotoCleanupMVE-unsigned.ipa，字节数=1835465，SHA-256=f1c9ec758ad58fe4eca7925cb835f811ca823f42baec413a47d753e4bd4c317f`
- **上传的 artifact**：名称 `PhotoCleanupMVE-unsigned-833e74cea652`，id `10807050700`，大小 `1835635` 字节（上传时压缩包体积，非 IPA 本体字节数），`digest=sha256:412538a467ad46adb0060a8bda5a53ac434b3c344b627936b6486f15270f793f`，`expires_at=2026-12-23T11:56:24Z`，`expired=false`
- **失败注解**：无（`gh api .../jobs` 各步骤 `conclusion` 均为 `success`；日志中出现的 `[36;1m ... ::error ...` 三行是工作流步骤脚本源码的语法高亮回显（陷阱 25：`##[group]Run ...` 展示 shell 脚本本体), 不是实际触发的错误信号——对应的判红条件（`test_status -ne 0` 或哨兵 `executed_count<=0`）在本次运行中均未成立，故这三行只是脚本文本，未产生真正的 `::error` 输出）

---

## 六、全部 `IC173_PROBE` 行原文（27 行，按出现顺序，一行不漏）

方法：下载运行 #352 的整包日志 zip（Python `zipfile` 读取，含重试；`gh api .../logs` 经代理 `HTTPS_PROXY=http://127.0.0.1:7890`，`NO_PROXY=blob.core.windows.net`），只取步骤文件 `构建、XCTest 与未签名产物/9_运行 XCTest.txt`（未使用根目录整作业日志 `0_构建、XCTest 与未签名产物.txt`，避免重复计数）。

```
2026-09-24T12:04:55.9158020Z IC173_PROBE arm=M01_bareUltraThin light=169 dark=99
2026-09-24T12:04:56.4427370Z IC173_PROBE arm=M02_bareUltraThin_envDarkOutside light=99 dark=99
2026-09-24T12:04:56.9484990Z IC173_PROBE arm=M03_bareUltraThin_envLightOutside light=169 dark=169
2026-09-24T12:04:57.4230290Z IC173_PROBE arm=M04_fillUltraThin light=169 dark=99
2026-09-24T12:04:57.9296780Z IC173_PROBE arm=M05_fillUltraThin_envDarkOutside light=99 dark=99
2026-09-24T12:04:58.4305120Z IC173_PROBE arm=M06_fillUltraThin_envDarkInsideBackground light=99 dark=99
2026-09-24T12:04:58.9141310Z IC173_PROBE arm=M07_bareRegular light=224 dark=64
2026-09-24T12:04:59.4214670Z IC173_PROBE arm=M08_bareRegular_envDarkOutside light=64 dark=64
2026-09-24T12:04:59.9092420Z IC173_PROBE arm=M09_productLegacyRecipe light=197 dark=149
2026-09-24T12:05:00.4737010Z IC173_PROBE arm=M10_menuRecipe light=249 dark=7
2026-09-24T12:05:00.9898960Z IC173_PROBE arm=M11_menuRecipe_envDarkOutside light=7 dark=7
2026-09-24T12:05:01.4772610Z IC173_PROBE arm=C01_systemBackground light=255 dark=0
2026-09-24T12:05:01.9867270Z IC173_PROBE arm=C02_systemBackground_envDark light=0 dark=0
2026-09-24T12:05:02.4984980Z IC173_PROBE arm=C03_primary light=0 dark=255
2026-09-24T12:05:02.9411340Z IC173_PROBE arm=C04_primary_envDark light=255 dark=255
2026-09-24T12:05:03.5313620Z IC173_PROBE arm=B_black_bareUltraThin light=87 dark=30
2026-09-24T12:05:03.9590310Z IC173_PROBE arm=B_black_bareUltraThin_envDark light=30 dark=30
2026-09-24T12:05:04.4486630Z IC173_PROBE arm=B_black_uikitUltraThinDark light=30 dark=30
2026-09-24T12:05:04.9779660Z IC173_PROBE arm=B_white_bareUltraThin light=244 dark=176
2026-09-24T12:05:05.4600540Z IC173_PROBE arm=B_white_bareUltraThin_envDark light=176 dark=176
2026-09-24T12:05:05.8938490Z IC173_PROBE arm=B_white_uikitUltraThinDark light=176 dark=176
2026-09-24T12:05:06.4365830Z IC173_PROBE arm=R01_bareUltraThin_envDarkAtRoot light=99 dark=99
2026-09-24T12:05:06.8966290Z IC173_PROBE arm=R02_bareRegular_envDarkAtRoot light=64 dark=64
2026-09-24T12:05:07.4028060Z IC173_PROBE arm=U01_uikitUltraThinDark light=99 dark=99
2026-09-24T12:05:07.8661790Z IC173_PROBE arm=U02_uikitUltraThinAdaptive light=169 dark=99
2026-09-24T12:05:08.3668910Z IC173_PROBE arm=U03_uikitMaterialDark light=64 dark=64
2026-09-24T12:05:08.8383240Z IC173_PROBE arm=U04_uikitMaterialAdaptive light=224 dark=64
```

**行数核对**：共 **27 行**，与卡面「共 27 行（A 1 + B 10 + C 4 + D 6 + E 2 + F 4）」一致（第一行 `M01_bareUltraThin` 对应 A 组的自检打印；`M02`～`M11` 共 10 行对应 B 组；`C01`～`C04` 共 4 行对应 C 组；`B_black_*` 三行 + `B_white_*` 三行共 6 行对应 D 组；`R01`／`R02` 共 2 行对应 E 组；`U01`～`U04` 共 4 行对应 F 组；1+10+4+6+2+4=27）。**只贴数据，不做归因，数据怎么读由决策会话定。**

---

## 七、本地门禁（提交前，工作树内真实执行）

| 门禁 | 退出码 | 关键输出 |
|---|---|---|
| `Scripts/selfcheck.ps1` | 0 | `结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。` |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | `扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。`（目录条目 259，产品源码引用 key 259，与本卡「零产品改动」声明一致） |
| `git diff --check` | 0 | 无输出（无空白符冲突） |

---

## 八、闸门结果

| 闸门 | 结果 | 依据 |
|---|---|---|
| **G975** | **满足** | A passed（未见于任何失败列表）；CI 绿 898／0（真实退出码 0，`OS:26.2, name:iPhone 16`）；`IC173_PROBE` 行共 27 行且全部贴入第六节；`git diff --name-only 467fe74a..833e74c` 恰 2 路径；`main` 未动（仍 `467fe74a0323c98e938142a2107f16843d21cc96`）；十九条被保护分支 tip 未变（第九节） |

---

## 九、被保护分支 tip 核对（19 条，`git -c http.proxy=http://127.0.0.1:7890 ls-remote --heads origin` 现取，全部未变）

即「IC-172 报告第十一节的十八条」+ 本卡新增保护对象 `feature/ic-172-glass-always-dark`：

| 分支 | tip |
|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` |
| `feature/ic-158-diagnostic-progress-clamp` | `5cb67332437a446d98733ddc942e2905392d2891` |
| `feature/ic-164-pick-ic163-a-d` | `cc85fa4a7cfa272092a3acfade432d13de7e4e0b` |
| `feature/ic-165-deck-formal` | `dc7e49459f15fb6227c3f34903357ae490aaa7ed` |
| `feature/ic-166-rest-category-and-lib` | `2734ccd0ef2f12fa4ce115f0136777321a96c548` |
| `feature/ic-167-s0-basket-entry-tail-sort` | `fc6dd1436fa25b8298caca2f3d2266024859df4e` |
| `feature/ic-168-s2-exit-diagnostics` | `e7c1be085102b5d9685b0863f29feb6bfa006a38` |
| `feature/ic-170-s1-first-read` | `800791020a8923e44043fea49c9d766a7edcd307` |
| `feature/ic-171-category-page-trio` | `0134c84cb52aea523410ee2f9e05ddd0f54f5d14` |
| `probe/ic-067-screenshot-subtype` | `9db02b93eccbb87d126602901807e70823535111` |
| `probe/ic-125-sentinel-negative` | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` |
| `probe/ic-137-media-playback` | `486bcb769b59eb1146c5a231c7998847206777cc` |
| `probe/ic-145-scan-service` | `d373afc7125104c01acfc296829229090e6871ce` |
| `probe/ic-161-similar-photos` | `1f8ff9248e312cd4a04faec559ea9f34540b1379` |
| `probe/ic-162-deck-home-preview` | `180b052edf24f168712c6e58754c60b88b342175` |
| `probe/ic-163-deck-home-preview-r2` | `562f8b7afa14508e3efebbd57e980e275946ab95` |
| `feature/ic-172-glass-always-dark` | `3cf48335bdf1153f5f349e985fce3f5c2abefa29` |

另核 `main` = `467fe74a0323c98e938142a2107f16843d21cc96`，未变。

---

## 十、人工判定项

无（本卡只取 CI 数据，不产出可装机的产物变更；本卡不涉及产品行为，不组织真机判定）。

---

## 十一、发现但未处理的问题（按纪律只报告不修）

无发现需要报告的问题。测试文件按决策会话原文逐字节拷入、一次编译通过、一次 CI 即绿，pbxproj 计数与卡面完全相符，未发现执行过程中的偏离或矛盾。

---

## 十二、40 位 SHA 核验（`git cat-file -e <sha>^{<类型>}`，全部执行、全部退出码 0）

| SHA | 类型 |
|---|---|
| `467fe74a0323c98e938142a2107f16843d21cc96` | commit |
| `833e74cea6524ac5c5f860ae50d71656f54ec457` | commit |
| `3cf48335bdf1153f5f349e985fce3f5c2abefa29` | commit |
| `e356aeda17da53a064892e04f39bea1032f5bf8d` | commit |
| `0134c84cb52aea523410ee2f9e05ddd0f54f5d14` | commit |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | commit |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | commit |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | commit |
| `5cb67332437a446d98733ddc942e2905392d2891` | commit |
| `cc85fa4a7cfa272092a3acfade432d13de7e4e0b` | commit |
| `dc7e49459f15fb6227c3f34903357ae490aaa7ed` | commit |
| `2734ccd0ef2f12fa4ce115f0136777321a96c548` | commit |
| `fc6dd1436fa25b8298caca2f3d2266024859df4e` | commit |
| `e7c1be085102b5d9685b0863f29feb6bfa006a38` | commit |
| `800791020a8923e44043fea49c9d766a7edcd307` | commit |
| `9db02b93eccbb87d126602901807e70823535111` | commit |
| `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | commit |
| `486bcb769b59eb1146c5a231c7998847206777cc` | commit |
| `d373afc7125104c01acfc296829229090e6871ce` | commit |
| `1f8ff9248e312cd4a04faec559ea9f34540b1379` | commit |
| `180b052edf24f168712c6e58754c60b88b342175` | commit |
| `562f8b7afa14508e3efebbd57e980e275946ab95` | commit |
| `a7154bbe866d2d79d3d0533f2a72562cd7cc174a` | blob（测试文件） |

命令与结果见 `change-list.md` 末尾。
