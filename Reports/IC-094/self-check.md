# IC-094 自验报告（merge-090-093）

## 结论（先行）

090 + 093 链已按卡内固定顺序两次 `--no-ff` 合并进 `main` 并推送。**两步均零冲突**，没有手工解冲突、没有任何内容改写。

`main`：`bf7bab1f8b9fea1194b57151f0beae34fa03756f` → `3b838f08bf1fa927c6885cc69b1bd8cc622eccad`。

**CI 结果：CI #166 success。** 被测 `3b838f08bf1fa927c6885cc69b1bd8cc622eccad`，XCTest **492 项、0 失败**，9 步全 success，真实退出码 `test_status=0`；IPA 786812 字节、SHA-256 `a52bceea…c4b6`，本地重下复核一致。CI 只用了 **1 次**（上限 2 次）。

四条预期核对值全部相符：XCTest **492 项 0 失败**、`schemaVersion == 4`、合并后树与 093 tip **零 diff**、两源分支 tip 未动。闸门（冲突即停）未触发。

## 开工前核对

| 项 | 值 | 与卡内一致 |
|---|---|---|
| `git status --porcelain` | 空 | ✅ |
| 检出 `main` | `bf7bab1f8b9fea1194b57151f0beae34fa03756f` | ✅ |
| `git fetch origin --prune` | 退出码 0 | — |
| `origin/main` | `bf7bab1f8b9fea1194b57151f0beae34fa03756f` | ✅ |
| `origin/feature/ic-090-strip-corner-pinch-end` | `420e72a249dc6fba654f521cdd7f1f1d94585365` | ✅ 与卡内表格逐字符相同 |
| `origin/feature/ic-093-image-upgrade-mark-style` | `7525fcbe3add1dac96bc94ecdb4d0768f9929526` | ✅ 卡内写 `7525fcb…`，此为完整 SHA |

本地三个分支引用与对应 `origin/` 引用逐一相等，无本地领先 / 落后。

## 合并执行

| 步 | 命令 | 结果 |
|---|---|---|
| 1 | `git merge --no-ff feature/ic-090-strip-corner-pinch-end -m "merge: IC-090 into main (IC-094)"` | 退出码 **0**，13 文件 1728 增 52 删，**无冲突** |
| 2 | `git merge --no-ff feature/ic-093-image-upgrade-mark-style -m "merge: IC-093 into main (IC-094)"` | 退出码 **0**，9 文件 979 增 12 删，**无冲突** |

两步之间与两步之后 `git status --porcelain` 均为空——没有残留的冲突标记、没有未跟踪文件、没有需要人工处置的中间态。

### 两个 merge 提交

| 步 | merge 提交 | 第一父 | 第二父 | 提交信息 |
|---|---|---|---|---|
| 1 | `78bd059dd82a8d6eca4bc8c950991865e2245f47` | `bf7bab1f8b9fea1194b57151f0beae34fa03756f` | `420e72a249dc6fba654f521cdd7f1f1d94585365` | `merge: IC-090 into main (IC-094)` |
| 2 | `3b838f08bf1fa927c6885cc69b1bd8cc622eccad` | `78bd059dd82a8d6eca4bc8c950991865e2245f47` | `7525fcbe3add1dac96bc94ecdb4d0768f9929526` | `merge: IC-093 into main (IC-094)` |

第二父分别就是卡内表格给的两个 tip，未被任何中间提交替换。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G203** 两个 merge 提交存在、顺序与信息如表；`git log --first-parent --no-merges bf7bab1..main`（报告提交前）为空 | 满足① | `git log --merges --format='%h %s' bf7bab1..main` 输出恰两行，逆序为 `3b838f0 merge: IC-093 into main (IC-094)`、`78bd059 merge: IC-090 into main (IC-094)`；`git log --first-parent --no-merges bf7bab1..main` **无输出** |
| **G204** 合并后 `main` 树与 093 tip 树零 diff | 满足① | `git diff --stat 7525fcbe3add1dac96bc94ecdb4d0768f9929526 main` **无输出**。这同时证明两次合并没有引入任何自动或手工的内容改写 |
| **G205** CI success / 真实退出码 0 / XCTest 492 · 0 / IPA 重下一致 | 满足① | 见「CI 与本地门禁」 |
| **G206** 本地三项门禁退出码 0；两源分支 tip 未被改动 | 满足① | `selfcheck.ps1` **0**、`scan-hardcoded-user-visible-strings.ps1` **0**（目录 171 / 引用 171、残留 0）、`git diff --check` **0**；分支 tip 见下表 |

### 预期核对值

| 项 | 卡内预期 | 实测 | 相符 |
|---|---|---|---|
| XCTest | 492 项、0 失败（= 477 + 5 + 10） | **492 项、0 失败** | ✅ |
| `S2CalibrationConfiguration.schemaVersion` | 4 | **4**（`S2Calibration.swift:118`） | ✅ |
| 两源分支保留、tip 不变 | 是 | 见下表 | ✅ |

### 分支 tip 核对（合并推送后）

| 分支 | 本地 | 远端 | 状态 |
|---|---|---|---|
| `feature/ic-090-strip-corner-pinch-end` | `420e72a249dc` | `420e72a249dc` | 未动、未删 |
| `feature/ic-093-image-upgrade-mark-style` | `7525fcbe3add` | `7525fcbe3add` | 未动、未删 |
| `feature/ic-089-nx-edge-bounce` | `b368a6caee84` | `b368a6caee84` | **冻结，未触碰** |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2` | `6736f1e3ebf2` | **冻结，未触碰** |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3` | `a7cc1ec727a3` | **冻结，未触碰** |

④ Lynn 选 C 的「089/091/092 冻结不合并」已落实：三条链一个提交未进 `main`，三个分支引用在本卡前后逐字节未变。

## CI 与本地门禁

| 项 | 值 |
|---|---|
| 运行编号 | **CI #166**（id `32919881426`），工作流「iOS 构建与自验」，分支 `main` |
| 结论 | **success**，9 步全部 success |
| 被测提交（完整 SHA） | `3b838f08bf1fa927c6885cc69b1bd8cc622eccad`（第二个 merge 提交） |
| XCTest 项数 / 失败数 | `Executed 492 tests, with 0 failures (0 unexpected) in 26.001 (32.476) seconds`；`** TEST SUCCEEDED **` |
| 真实退出码 | `test_status=0`；工作流以 `set -o pipefail` 采集并 `exit "$test_status"` 原样退出 |
| IPA 字节数 | **786812** |
| IPA SHA-256 | `a52bceea2b83f746eadbdf966ed82aa444df3f63a1e7dc0c5a685b7f73fac4b6`（CI 报告值） |
| IPA 本地复核 | artifact `PhotoCleanupMVE-unsigned-3b838f08bf1f` 下载解出 786812 字节，本地 `sha256sum` 与 CI 报告值**一致** |

**CI 只用了 1 次**（卡内上限 2 次），一次通过。

**一处值得记下的旁证**：本次 IPA 与 IC-093 的 CI #162 包**字节数完全相同（786812），SHA-256 不同**（`a52bceea…` vs `f561d1ad…`）。字节数相同印证 G204 的树零 diff（同一份源码产出同样大小的产物）；哈希不同是 Xcode 构建不可复现的常态（时间戳、UUID），不是内容差异。

本地门禁（Windows，本机无 Xcode，无法执行 XCTest 或构建 IPA）：

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0**（"结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求"） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（目录条目 171 / 产品源码引用 key 171、用户可见硬编码残留 **0**） |
| `git diff --check` | **0** |

三项均在**合并完成后、推送之前**于合并结果上执行。

## `main` 新基线得到了什么

全部为真机已判定通过的交付，本卡不引入任何未验收内容：

1. **横栏项目圆角**（IC-090 R1/R3，H36 通过）：`bottomStripCornerRadius` 出厂 8/3 pt，项目内容与待删标记叠层同受裁切。
2. **`schemaVersion` 3 → 4**（IC-090，出厂值集合新增一项）：旧包写入的 Keychain 条目在本包首次冷启动时整套丢弃取出厂值。
3. **图像替换只升不降**（IC-093 R1，H39 通过）：消除捏合 / 双击后的「清晰 → 糊 → 清晰」闪替。
4. **待删标记双色化**（IC-093 R2，H40 通过）：白符号 + 黑底 0.55，固定色值。
5. **诊断埋点**：场景 C 的五个逐帧字段与五类事件（IC-090）、`图片替换被抑制` 事件（IC-093）；关闭录制时零副作用。

## 人工判定项

**本卡无新增人工判定项。** H36（IC-090）、H39 / H40（IC-093）均已由 Lynn 在各自卡的 CI 包上判定通过；本卡合并的正是那两个包对应的提交，产品树与 093 tip 零 diff。

Lynn 可选装合并包抽查无回归（不阻塞收口）：CI #166 的 artifact `PhotoCleanupMVE-unsigned-3b838f08bf1f`。

## 真机未覆盖项

本卡是纯合并，不产生新的产品行为，但**合并本身有一件事没有任何一张前卡覆盖过**：

1. **090 链与 093 链的产品代码首次与 `bf7bab1` 之外的东西共存**——实际上没有：093 本就是 090 tip 的后代，两条链在分支上已经是线性叠加，合并进 `main` 时 `main` 自 `bf7bab1` 未动，因此合并后的树与 093 tip 逐字节相同（G204 已证）。**Lynn 判 H39 / H40 用的 CI #162 包，其产品树与本次合并结果一致**，故那两项判定可直接转移到 `main`。这是本卡唯一需要说清的传递性论证。
2. **`schemaVersion` 4 的 Keychain 迁移在真机上只由 IC-090 的包验证过**（H36 期间）。合并未改这条路径。

## 发现但未处理的问题（按纪律只报告不修）

1. **`main` 上的 `schemaVersion` 是 4，092 链上是 5。** 092 链（冻结）为了避开 090 链已用掉的 4 而跳到 5，理由见 `Reports/IC-092/self-check.md`。日后解冻合并 092 时，这一行会与 `main` 的 4 冲突，**解为 5**——5 对两条链都是新值，任一包首次冷启动都会丢弃旧条目取出厂值。这是已知的、有意为之的冲突点，不是遗留缺陷。
2. **091 / 092 的探针与机制代码不在 `main` 上**：`S2NxEdgeHandoffRule`、交接窗口、跟随写入器、动量回弹，以及 `export-format.md` 里 IC-091 / IC-092 的两节，全部随分支冻结。`main` 上的 `export-format.md` 只含到 IC-090 与 IC-093 两节。若日后解冻，这两节的追加位置需要重新对齐（它们当时是追加在含 091 内容的版本之后）。
3. **本次推送 `main` 前三次失败于本机 TLS / 代理（`rc=128`），第四次成功**，与产物无关。这是本机网络的既有形态（IC-087 报告亦记过一次）。
4. **`Reports/` 下现在同时存在 090、093 的报告与 091、092 分支上的报告**，后两者不在 `main` 上。技术负责人日后按第 127 条记录 `main` 新基线时，若要在 `main` 上留下 091/092 的分析结论，需要单独安排——它们目前只存在于冻结分支。
