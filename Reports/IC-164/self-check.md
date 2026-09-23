# IC-164 自验报告（把 IC-163 的子项 A、D 原样摘回 `main`）

## 一、结论（先行）

两次 `git cherry-pick -x` 都退出码 0、无冲突，**零手写改动**。

- 子项 A → `b905155e1d569af2330e2c0f2d43a08c39f15888`（源 `105ada3`）
- 子项 D → `cc85fa4a7cfa272092a3acfade432d13de7e4e0b`（源 `088e4b1`）

CI 情况：
- 分支运行 **#328** 一次绿，**859 项 0 失败**、真实退出码 0（预算 2 次用 1 次）。
- G924 满足后 `--no-ff` 合并进 `main`，合并提交 **`243e3ad666bea8471ddb6c032e188dc34cc9c374`**，已推送。
- 合并后 `main` 运行 **#329** 一次绿，**859 项 0 失败**（G925）。

- **G921（摘取保真）通过**：A 的 Core 两文件与测试文件同源提交逐字相同，pbxproj 四行逐字相同；D 的 patch-id 与源提交相同（`708ffd58…`）；两个提交信息都带 `(cherry picked from commit <40 位>)`。
- **G922（白名单外零改动）通过**：`main..cc85fa4` 恰 9 个路径；`App/`／`Features/`／`.github/`／`Scripts/` 四棵树两侧对象相同；十一条被保护分支的 tip 未变。
- **G923（CI）通过**：#328 859／0，A 带来的三条与 IC153／IC155 两族全过；A 版本测试文件（250 行）第一次单独编译即过，卡面唯一的 ③ 风险未兑现。
- **G924（合并前置）通过**、**G925 通过**。
- **裁定 二声明**：D 实装先于规格（SPEC-S0 v2 仍写「大视频 ≥ 100 MB」），依据 Decision_log 第 187／189／190 条，规格随 v3 补写。
- 本卡不新增人工判定组。A、D 的真机效果由 H82 第 6、7、8 条在 #327 产物上判；可顺带看的 H83 两条列在第八节。

**报告提交方式（纪律 7，经 Lynn 定）**：卡面同时要求三件事，三者不能同时成立：
- 报告含合并提交 SHA 与 G925；
- 「恰一个 docs 提交、同一分支、CI 之后追加、不分两次」；
- 合并前置（G924）不含 docs。

执行前我向 Lynn 提问，她选「**合并与合并后 `main` 运行之后，直接在 `main` 上追加恰一个 docs 提交**」（与 IC-157／159／160 的补记提交同位置）。因此：
- 本卡提交形态 = A 摘取 → D 摘取 → `--no-ff` 合并 `243e3ad` → 本 docs 提交（落在 `main` 上）；
- docs 提交只含 `Reports/IC-164/` 两个文件，按 `paths-ignore` 不触发 CI，不为它追加 CI 闭环。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260922-164-pick-ic163-a-d-into-main.md` |
| 继承提交 | `main` = `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a` |
| 来源提交 | A `105ada3f4acc9b5ad5ae9efb6cfb22b503ee1f0e`、D `088e4b1deb7b38bd7fb333d149d9561a9b23a171`（探针分支 `probe/ic-163-deck-home-preview-r2` tip `562f8b7afa14508e3efebbd57e980e275946ab95`）；`git fetch origin probe/ic-163-deck-home-preview-r2` 直连首试 schannel 握手失败、代理形式成功（退出码 0），三个对象 `git cat-file -e <sha>^{commit}` 退出码均 0 |
| 目标分支 | `feature/ic-164-pick-ic163-a-d`（自 `091b60e` 切出） |
| 范围边界 | 白名单 9 个路径 + `Reports/IC-164/`；IC-163 的 B／C 与全部 `S0Deck*` 文件、SPEC、Decision_log、探针与冻结分支一律未动 |

开工四步：
1. 工作树停在上一卡留下的 `probe/ic-163-deck-home-preview-r2` 上，`git status --porcelain` 为空。
2. `git switch main` 后再核 `status`，仍为空。
3. `git merge-base --is-ancestor dff2e7946d6297672eba1a001952cbe737a183e1 main` 退出码 0。
4. `git ls-remote origin refs/heads/main` = `091b60e…3a0a`，与本地一致。
5. **先切分支再摘取**：`git switch -c feature/ic-164-pick-ic163-a-d main`，此时 HEAD = `091b60e`、`status` 空。

## 三、两次 cherry-pick 的命令、退出码与 `git show --stat`

### 子项 A

```
$ git cherry-pick -x 105ada3f4acc9b5ad5ae9efb6cfb22b503ee1f0e
Auto-merging PhotoCleanupMVE.xcodeproj/project.pbxproj
[feature/ic-164-pick-ic163-a-d b905155] fix(IC-163): 子项 A S2 写回只覆盖交接列表内的标记，类别篮不被抹（裁定 一，可摘到 main）
 Date: Tue Sep 22 21:25:59 2026 -0700
 4 files changed, 266 insertions(+), 5 deletions(-)
 create mode 100644 PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift
cherry-pick A rc=0
```

`git show --stat HEAD`：

```
 PhotoCleanupMVE.xcodeproj/project.pbxproj          |   4 +
 PhotoCleanupMVE/Core/S1StateMachine.swift          |  13 +-
 PhotoCleanupMVE/Core/SessionStore.swift            |   4 +-
 .../IC163DeckPreviewRoundTwoTests.swift            | 250 +++++++++++++++++++++
 4 files changed, 266 insertions(+), 5 deletions(-)
```

提交信息末行：`(cherry picked from commit 105ada3f4acc9b5ad5ae9efb6cfb22b503ee1f0e)`。

### 子项 D

```
$ git cherry-pick -x 088e4b1deb7b38bd7fb333d149d9561a9b23a171
Auto-merging PhotoCleanupMVE/Localizable.xcstrings
[feature/ic-164-pick-ic163-a-d cc85fa4] feat(IC-163): 子项 D「视频」类取代「大视频」——全部已解析视频，录屏优先归录屏（裁定 五，可摘到 main）
 Date: Tue Sep 22 21:31:31 2026 -0700
 5 files changed, 46 insertions(+), 52 deletions(-)
cherry-pick D rc=0
```

`git show --stat HEAD`：

```
 PhotoCleanupMVE/Localizable.xcstrings              |  2 +-
 PhotoCleanupMVE/Services/S0ScanClassifier.swift    |  4 +-
 PhotoCleanupMVE/Services/S0ScanRules.swift         |  7 +--
 PhotoCleanupMVETests/IC153ScanServiceTests.swift   | 66 +++++++++++-----------
 .../IC155CategoryDataAndCoverTests.swift           | 19 ++++---
 5 files changed, 46 insertions(+), 52 deletions(-)
```

提交信息末行：`(cherry picked from commit 088e4b1deb7b38bd7fb333d149d9561a9b23a171)`。

两次都没有冲突，未做任何手工处理。

## 四、逐条验收门禁

### G921：摘取保真

**子项 A 第 2 条**（A 摘取提交 `b905155…`）：

| 核对 | 输出 | 判定 |
|---|---|---|
| `git diff 105ada3 b905155 -- PhotoCleanupMVE/Core PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift \| wc -l` | `0` | 空，OK |
| `git diff main b905155 -- project.pbxproj \| grep '^+' \| grep -v '^+++'` | 恰 4 行（见下） | OK |
| 同上与 `git show 105ada3 -- project.pbxproj \| grep '^+' \| grep -v '^+++'` 做 `diff` | 空（`pbxproj + lines IDENTICAL to 105ada3`） | 逐字相同，OK |
| `grep -c '100000000000000000000068\|200000000000000000000065' project.pbxproj` | `4` | OK |
| `grep -o 100000000000000000000068 … \| wc -l` | `3` | OK |
| `grep -o 200000000000000000000065 … \| wc -l` | `2` | OK |
| 两 id 的 `= {isa =` 定义行 | 各 `1` | OK |

四行原文：

```
+		200000000000000000000065 /* IC163DeckPreviewRoundTwoTests.swift（测试源码） */ = {isa = PBXBuildFile; fileRef = 100000000000000000000068 /* IC163DeckPreviewRoundTwoTests.swift */; };
+		100000000000000000000068 /* IC163DeckPreviewRoundTwoTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IC163DeckPreviewRoundTwoTests.swift; sourceTree = "<group>"; };
+				100000000000000000000068 /* IC163DeckPreviewRoundTwoTests.swift */,
+				200000000000000000000065 /* IC163DeckPreviewRoundTwoTests.swift（测试源码） */,
```

**子项 A 第 4 条**：本机用 Python 逐字符移植 `IC157LongPressIntoS2Tests` 的 `strippedSource`（剔 `//` 注释与字符串内容），对摘后 `S1StateMachine.swift` 计数：

| needle | 卡面 | 实测 |
|---|---|---|
| `publishSnapshotIfChanged()` | 6 | 6 |
| `setMarked(` | 3 | 3 |
| `applyPendingDeletionDiff(` | 3 | 3 |
| `private func applyPendingDeletionDiff(` | 1 | 1 |

**子项 D 第 2 条**（D 摘取提交 `cc85fa4…`）：

| 核对 | 输出 | 判定 |
|---|---|---|
| `git show cc85fa4 \| git patch-id --stable` | `708ffd58cb256a83128caebd1ade27559f2b94db cc85fa4a7cfa272092a3acfade432d13de7e4e0b` | 第一列 = 卡面值，OK |
| 同上对源提交 `088e4b1` | `708ffd58cb256a83128caebd1ade27559f2b94db 088e4b1deb7b38bd7fb333d149d9561a9b23a171` | 相同 |
| `grep -rn bigVideoMinimumByteCount PhotoCleanupMVE PhotoCleanupMVETests \| wc -l` | `0` | OK（`Reports/IC-153/` 的历史提及不计） |
| `attributionPriority` 与 `main` 逐行 `diff` | 空（`attributionPriority identical to main`） | OK |
| `hits` 视频段 | `if evidence.filenamePrefixMatched \|\| evidence.resolutionMatched { hits.insert(.screenRecording) } else { hits.insert(.bigVideo) }` | if／else 互斥，OK |
| `s0.category.bigVideo` 的值 | 码位 `['0x89c6', '0x9891']` = `视频` | OK |
| `git diff --numstat main -- Localizable.xcstrings` | `1	1	PhotoCleanupMVE/Localizable.xcstrings` | 恰 −1／+1，OK |
| `func test` 数 | `IC153ScanServiceTests` main=13 now=13；`IC155CategoryDataAndCoverTests` main=9 now=9 | OK |

**提交链**：`git log --format='%H %s' main..cc85fa4` 恰两行：

```
cc85fa4a7cfa272092a3acfade432d13de7e4e0b feat(IC-163): 子项 D「视频」类取代「大视频」——全部已解析视频，录屏优先归录屏（裁定 五，可摘到 main）
b905155e1d569af2330e2c0f2d43a08c39f15888 fix(IC-163): 子项 A S2 写回只覆盖交接列表内的标记，类别篮不被抹（裁定 一，可摘到 main）
```

之后恰有合并提交 `243e3ad` 与本 docs 提交各一个（第一节「报告提交方式」）。

### G922：白名单外零改动

`git diff --stat main..cc85fa4` 恰 **9 个路径**（A 4 + D 5），+312／−57，逐条见 `change-list.md` 第二节。

| 路径 | `main`（`091b60e`）侧树对象 | `cc85fa4` 侧树对象 | 判定 |
|---|---|---|---|
| `PhotoCleanupMVE/App` | `a8ae7e545b8b8809f300c5ba47081c16c84c51e0` | `a8ae7e545b8b8809f300c5ba47081c16c84c51e0` | 同 |
| `PhotoCleanupMVE/Features`（全部） | `d4d750b867aefedcc185c0b5ebb4d8a6969469a4` | `d4d750b867aefedcc185c0b5ebb4d8a6969469a4` | 同 |
| 　其中 `Features/S0` | `d9bc7be894cf714b2bcfcd31a53f623e2d9411e0` | `d9bc7be894cf714b2bcfcd31a53f623e2d9411e0` | 同 |
| 　其中 `Features/Shared` | `d7f158ff5c0768ee1ce25b488731d08cb2a7098c` | `d7f158ff5c0768ee1ce25b488731d08cb2a7098c` | 同 |
| `.github` | `74088388c62a10eb277921ecf74e766a2d407e80` | `74088388c62a10eb277921ecf74e766a2d407e80` | 同 |
| `Scripts` | `514886dc0afc4083237c976c0f7be6ce597c50a8` | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同 |
| `Services/S0LibraryScanService.swift`（blob） | `ffeb23aaee01d6a35fc3df9dce6c1ac8467d3a4f` | `ffeb23aaee01d6a35fc3df9dce6c1ac8467d3a4f` | 同 |
| `Services/S0ScanCache.swift`（blob） | `27da1b17aef6adf8db54c4af8fefdff0f8ad9a6b` | `27da1b17aef6adf8db54c4af8fefdff0f8ad9a6b` | 同 |

用的是 git 树／blob 对象 SHA-1（git 自身的内容寻址，两侧相同即逐字节相同），不是另算的 SHA-256。

- `git diff --name-only main cc85fa4 -- PhotoCleanupMVE/Core PhotoCleanupMVE/Services PhotoCleanupMVETests`，剔除白名单内的 7 个文件后输出为空。
- `S0ScanAggregator` 不是独立文件，定义在 `S0ScanClassifier.swift` 里。D 只改该文件 `hits` 的视频段，聚合器代码未动。

| 计数 | 值 |
|---|---|
| `S2CalibrationConfiguration.schemaVersion` | 7（`static let schemaVersion = 7`） |
| `S0ScanRules.cacheSchemaVersion` | 1 |
| `S0HomeMetrics` 登记值 | 52，由 `Features/` 树两侧相同蕴含 |
| `S0CategoryPageMetrics` 登记值 | 42，同上 |
| 目录 `s0.` | 38 |
| 目录 `deck.` | 0 |
| 目录条目 | 253 |

被保护分支 tip（`git for-each-ref` 实读）：

| 分支 | 卡面 | 实读 |
|---|---|---|
| `probe/ic-067-screenshot-subtype` | `9db02b9` | `9db02b9` |
| `probe/ic-125-sentinel-negative` | `402cb6e` | `402cb6e` |
| `probe/ic-137-media-playback` | `486bcb7` | `486bcb7` |
| `probe/ic-145-scan-service` | `d373afc` | `d373afc` |
| `probe/ic-161-similar-photos` | `1f8ff92` | `1f8ff92` |
| `probe/ic-162-deck-home-preview` | `180b052` | `180b052` |
| `probe/ic-163-deck-home-preview-r2` | `562f8b7` | `562f8b7` |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | `b368a6c` |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | `6736f1e` |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | `a7cc1ec` |
| `feature/ic-158-diagnostic-progress-clamp` | `5cb6733` | `5cb6733` |

### G923：CI（分支运行 #328）

| 项 | 值 |
|---|---|
| 运行 | **#328**，id `35829261269`，run_attempt 1，push `feature/ic-164-pick-ic163-a-d`，2026-09-23T06:57:55Z 建、07:09:33Z 完 |
| 结论 | `success`（作业 `107077849166` success，十二步全 `success`） |
| 被测提交 | `cc85fa4a7cfa272092a3acfade432d13de7e4e0b`（A + D） |
| XCTest 执行摘要 notice | `Executed 859 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 859 tests / 0 failures` |
| 唯一 Test Case 行复核（剔 `##[` 回显与 ANSI 回显，单个步骤文件） | **859 passed / 0 failed**；`Test Suite 'All tests' started` 1 次；`Restarting after` 0 |
| 真实退出码 | **0**。工作流 `set -o pipefail`，末句 `exit "$test_status"`；原始行 `Executed 859 tests, with 0 failures (0 unexpected) in 55.373 (57.401) seconds`；`** TEST SUCCEEDED **`；无 `** TEST FAILED **`；无 failure 注解 |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 分段耗时 notice 原文 | `XCTest 分段耗时：模拟器启动 103 s；xcodebuild test 394 s；总 498 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1690494，SHA-256=d475a80d8790a14543b6eddedde0398dc018333866cd97dcade0eb137dff093a` |
| artifact | `PhotoCleanupMVE-unsigned-cc85fa4a7cfa`（id `10735849838`，1 690 664 字节，有效期至 2026-12-22T06:57:55Z，`expired: false`） |

| 族 | 过／总 | 失败 |
|---|---|---|
| `IC163DeckPreviewRoundTwoTests` | 3／3 | 0 |
| `IC153ScanServiceTests` | 13／13 | 0 |
| `IC155CategoryDataAndCoverTests` | 9／9 | 0 |
| `IC157LongPressIntoS2Tests` | 8／8 | 0 |
| `IC156CategoryPageTests` | 11／11 | 0 |
| `SessionStoreTests` | 14／14 | 0 |
| `S1StateMachineTests` | 20／20 | 0 |
| `AlbumScopeWiringTests` | 7／7 | 0 |
| `FullFlowRoutingTests` | 6／6 | 0 |

**`testIC063`**（陷阱 26）：passed（22.684 s）。时间线如下：
1. `Errors found! Invalidating cache...` 两行。
2. `[error] building pipeline path_exterior-jba6la8feba4 took 16.734520 seconds`，进程内时间 07:05:19.53，日志时间 07:05:19.63。
3. `IC063_WARMUP_GATE_BEGIN` 07:05:21.21 → `IC063_WARMUP_GATE_END` 07:05:21.24 → `IC063_DIAGNOSTICS_SAMPLE_BEGIN` 07:05:24.32。

16.7 s 的 Metal 管线编译落在预热门禁**之前**，被挂载循环那次导出吸收，计时段干净。

### G924：合并前置

| 前置 | 结果 |
|---|---|
| G921～G923 | 全部通过（上文） |
| pbxproj 撞号扫描 | `…68` 3 处、`…65` 2 处；两 id 各恰 1 条定义行；Python 扫全表 189 条 `= {isa` 定义行，同 id 重复定义 **0**（卡面 `grep … \| sort \| uniq -d` 同义） |
| 工作树 | `git status --porcelain` 空 |
| `main` 未被他人推进 | `git ls-remote origin refs/heads/main` = `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a`（与本地一致） |

满足后执行：

```
$ git switch main
$ git merge --no-ff feature/ic-164-pick-ic163-a-d -m "merge(IC-164): 摘回 IC-163 子项 A（S2 写回不抹类别篮）与 D（「视频」类取代「大视频」）" -m "…"
Merge made by the 'ort' strategy.
 9 files changed, 312 insertions(+), 57 deletions(-)
merge rc=0
$ git push origin main
   091b60e..243e3ad  main -> main
```

- 合并提交 **`243e3ad666bea8471ddb6c032e188dc34cc9c374`**。
- 合并后树与 `cc85fa4` 相同（`git diff --quiet cc85fa4 243e3ad` 退出码 0）。
- 推送后 `git ls-remote origin refs/heads/main` = `243e3ad…c374`。
- Bash 侧一次通过，未触发 `[Merge Without Review]`。

### G925：合并后 `main` 自动运行

| 项 | 值 |
|---|---|
| 运行 | **#329**，id `35830832469`，run_attempt 1，push `main`，2026-09-23T07:16:12Z 建、07:24:48Z 完 |
| 结论 | `success`（作业 `107082779937` success，十二步全 `success`） |
| 被测提交 | `243e3ad666bea8471ddb6c032e188dc34cc9c374`（合并提交） |
| XCTest 执行摘要 notice | `Executed 859 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 859 tests / 0 failures` |
| 唯一 Test Case 行复核 | **859 passed / 0 failed**；`All tests` started 1 次；无宿主重启 |
| 真实退出码 | **0**。原始行 `Executed 859 tests, with 0 failures (0 unexpected) in 42.473 (44.191) seconds`；`** TEST SUCCEEDED **` |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 分段耗时 notice 原文 | `XCTest 分段耗时：模拟器启动 75 s；xcodebuild test 293 s；总 369 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1690494，SHA-256=25e09abd8b58412f33fdc9f510e7607de8d2325a8aa0a21437c90495073bb8f7` |
| artifact | `PhotoCleanupMVE-unsigned-243e3ad666be`（id `10737542190`，1 690 664 字节，有效期至 2026-12-22T07:16:12Z，`expired: false`） |
| `testIC063` | passed（6.456 s）；`building pipeline … took 0.587384 seconds`（07:22:09.46）在 `IC063_WARMUP_GATE_END`（07:22:11.12）之前 |

两次运行 IPA 字节数相同（1 690 494）、SHA-256 不同——与「IPA 不可复现」的既有结论一致，不作身份依据。

## 五、断言 1～5 与测试函数名

| # | 测试 | 来源 | #328 | #329 |
|---|---|---|---|---|
| 1 | `testIC163A_RealRangeReturnUnchanged` | 随 A 摘入 | passed | passed |
| 2 | `testIC163A_VirtualRangeReturnKeepsBasketOutsideHandoff` | 随 A 摘入 | passed | passed |
| 3 | `testIC163A_VirtualRangeUnmarkInsideHandoffStillWorks` | 随 A 摘入 | passed | passed |
| 4 | `IC153ScanServiceTests` 全族（13 条） | 随 D 改期望值 | 13／13 | 13／13 |
| 5 | `IC155CategoryDataAndCoverTests` 全族（9 条） | 随 D 改期望值 | 9／9 | 9／9 |

本卡不新写测试。**夹具驱动，真机未覆盖**（陷阱 1）。

## 六、本地门禁结果与真实退出码

| 门禁 | A 摘取后 | D 摘取后 |
|---|---|---|
| `Scripts/selfcheck.ps1` | 0 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 0 |
| `git diff --check`（工作树） | 0 | 0 |
| `git diff --check HEAD~1 HEAD`（该提交本身） | 0 | 0 |

- 扫描器两次都报「目录条目：253，产品源码引用 key：253，用户可见硬编码残留：0」。
- `selfcheck.ps1` 报 Swift 字符串与括号结构检查扫描 90 个 `.swift`，均通过。
- 扫描 needle 与源码变体交叉审计扫描 44 个测试源文件，均通过。
- 结构自验通过。

**项数对账**：`main` 856（#321）+ A 三条 = **859**；D 不加不减。#328、#329 实测都是 859。本机非注释 `func test` 计数 859 与之一致（只作差值，陷阱 22）。

## 七、裁定 二声明（实装先于规格）

SPEC-S0 v2 第二节第 2 部分写「大视频 ≥ 100 MB」（第 180 条 ④ 默认值）。

本卡子项 D 让 `main` 上的「视频」类 = 全部已解析视频、录屏互斥，属**实装先于规格**，依据：
- Decision_log 第 187 条 ④：Lynn 2026-09-19 取消门槛、类目改「视频」。
- 第 189 条裁定 五。
- 第 190 条。

规格随 SPEC-S0 v3 补写。这不是未定项，未触发「触及未定项须停下」。

## 八、人工判定项

本卡不新增判定组。A、D 与探针分支是同一份 Core／Services 改动，其真机效果由 **H82 第 6、7、8 条**在 #327 产物上判。

若 Lynn 日后装合并后 `main` 的产物 `PhotoCleanupMVE-unsigned-243e3ad666be`（id `10737542190`），可顺带看两条（记 **H83**，不阻塞任何事；执行端不代判）：
1. 旧类别页进篮 → 长按进 S2 → 垃圾桶 → S3 有该类别一组、张数与进篮一致。
2. 旧首页类别行叫「视频」、体积含小于 100 MB 的视频，录屏行不重复计入。

## 九、40 位 SHA 核验（陷阱 15）

报告写完后，对两份报告里出现的全部 40 位十六进制串（`grep -ohE '\b[0-9a-f]{40}\b' … | sort -u`，17 个）逐个取 `git cat-file -t` 类型，再按类型跑 `git cat-file -e <sha>^{<类型>}`：

- 提交 8 个，全部按 `^{commit}` 核，退出码 0；
- 树 6 个、blob 2 个（G922 的树／blob 对象表），按 `^{tree}`／`^{blob}` 核，退出码 0；
- `708ffd58cb256a83128caebd1ade27559f2b94db` 是 **patch-id**（`git patch-id --stable` 的输出），不是仓库对象，按定义不入对象库，不适用此核验。

| SHA | 类型 | 核验 |
|---|---|---|
| `088e4b1deb7b38bd7fb333d149d9561a9b23a171` | commit | `^{commit}` rc=0 |
| `091b60ed1bbc6b5c607bb5eca7732303a9ca3a0a` | commit | `^{commit}` rc=0 |
| `105ada3f4acc9b5ad5ae9efb6cfb22b503ee1f0e` | commit | `^{commit}` rc=0 |
| `243e3ad666bea8471ddb6c032e188dc34cc9c374` | commit | `^{commit}` rc=0 |
| `562f8b7afa14508e3efebbd57e980e275946ab95` | commit | `^{commit}` rc=0 |
| `b905155e1d569af2330e2c0f2d43a08c39f15888` | commit | `^{commit}` rc=0 |
| `cc85fa4a7cfa272092a3acfade432d13de7e4e0b` | commit | `^{commit}` rc=0 |
| `dff2e7946d6297672eba1a001952cbe737a183e1` | commit | `^{commit}` rc=0 |
| `514886dc0afc4083237c976c0f7be6ce597c50a8` | tree | `^{tree}` rc=0 |
| `74088388c62a10eb277921ecf74e766a2d407e80` | tree | `^{tree}` rc=0 |
| `a8ae7e545b8b8809f300c5ba47081c16c84c51e0` | tree | `^{tree}` rc=0 |
| `d4d750b867aefedcc185c0b5ebb4d8a6969469a4` | tree | `^{tree}` rc=0 |
| `d7f158ff5c0768ee1ce25b488731d08cb2a7098c` | tree | `^{tree}` rc=0 |
| `d9bc7be894cf714b2bcfcd31a53f623e2d9411e0` | tree | `^{tree}` rc=0 |
| `27da1b17aef6adf8db54c4af8fefdff0f8ad9a6b` | blob | `^{blob}` rc=0 |
| `ffeb23aaee01d6a35fc3df9dce6c1ac8467d3a4f` | blob | `^{blob}` rc=0 |
| `708ffd58cb256a83128caebd1ade27559f2b94db` | patch-id | 不是对象，不适用 |

IPA 与 artifact 的 64 位 SHA-256 取自 CI 注解与 artifacts API 原文，不是 git 对象。

## 十、发现但未处理的问题（按纪律只报告不修）

1. **卡面「报告提交方式」自相矛盾**：
   - 「恰一个 docs 提交、同一分支、CI 之后」与「报告必含合并提交 SHA 与 G925」不能同时成立。
   - 按 Lynn 的选择，docs 提交在合并与 #329 之后直接落在 `main` 上（第一节）。
   - 建议后续卡在这一节直接写明落点。
2. **`(cherry picked from commit …)` 行在 `Co-Authored-By` 之后**：`-x` 把它追加在提交信息末尾。卡面只要求「末尾各带」，满足；只是 trailer 顺序与手写提交不同。
3. **卡面把 `S0ScanAggregator` 当独立文件列进「不动」清单**：它其实定义在 `S0ScanClassifier.swift` 里（D 白名单内的文件）。D 只改 `hits` 视频段，聚合器代码一字未动。
4. **`S0HomeMetrics` 52／`S0CategoryPageMetrics` 42 由 `Features/` 树两侧相同蕴含**：对这两个文件裸 grep `static let` 会得 53／46，因为文件内另有登记族以外的静态量，不能拿裸 grep 数与 52／42 对账。
5. **#328 的 `testIC063` 出现一次 16.7 s 的 Metal 管线编译**（#329 为 0.59 s）。它落在 `IC063_WARMUP_GATE_END` 之前，预热导出吸收了它、用例照过。这是 IC-159 预热方案在长编译下仍有效的又一个数据点，不需要处理。
6. **`git fetch` 直连首试 schannel 握手失败**，改代理形式成功，与记忆中「两者偶有互换」一致。推送 `feature/ic-164-…` 与 `main` 都是直连首试成功。
