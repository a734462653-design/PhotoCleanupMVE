# IC-135 自验报告

> 报告提交方式说明（执行纪律第 7 条）：本卡为合并卡，报告必须引用推送后才产生的
> 合并提交 SHA 与 G751 运行编号／IPA 校验，故采用「同一张卡、同一分支内追加一个
> docs 提交」的方式，随合并一并留在 `main` 上，不跨卡回填。

## 结论（先行）

**交付合格，合并完成，G751 绿。** `feature/ic-134-s345-visual` 已以 `--no-ff` 合入
`main`，合并提交 **`17736e3`**（完整 SHA `17736e37d682911b3e69a993b8a0e97069de692d`）。
如卡内预判，`merge-base` 等于 `main` tip，结构为快进式，**零冲突**，合并未引入任何
自身内容（树对象与分支 tip 逐字节相同）。合并后 `main` 自动触发运行 **#264** 一次
通过：XCTest **674 项 0 失败**，真实退出码 0，「XCTest 执行摘要」notice 在位，
目的地 `OS:26.2, name:iPhone 16`。四道闸门 G751～G754 全部通过。本地三条门禁退出码
均为 0。人工判定项：无（H60 已由 Lynn 在合并前完成）。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260907-135-merge-134.md`
- 继承提交：`main` = `39bade77dea68dd8b7b09b6a309d39ad54ae050f` ①
  提交标题逐字比对一致：
  `docs: IC-133 自验与变更清单（#260 绿 665 项，合并入 main be77fd0，#261 绿）`
- 待合并分支：`feature/ic-134-s345-visual`，tip = `54ac69e10d38c65092cc08ba8b32790b1e53dbf7` ①
  `git rev-parse --short` = `54ac69e`，与卡相符；提交标题以 `docs: IC-134` 开头：
  `docs: IC-134 自验与变更清单（#263 绿 674 项，不合并等 H60）`
- 代码 tip：`af4e55793b9e648f275fa4115205998e04cdf5f5` ①
  （`git log -1` 身份比对，非短前缀补全，纪律陷阱 15）
- 前置：H60 真机判定六项全部通过（④ Lynn，Lynn 贴卡即成立；本卡不自行判定）
- 范围边界：只做合并与登记，**零产品代码与测试改动**

## 范围内逐项结果

### 1. 开工检查：全部相符 ①

| 检查项 | 实测 | 判定 |
|---|---|---|
| `git status --porcelain` | 空输出 | 工作树净，无他会话改动 |
| `main` tip | `39bade77dea68dd8b7b09b6a309d39ad54ae050f` | 与卡逐字相符 |
| `main` tip 标题 | 见上，逐字比对 | 相符 |
| 分支 tip | `54ac69e10d38c65092cc08ba8b32790b1e53dbf7` | 与卡逐字相符 |
| 分支 tip 短 SHA | `54ac69e` | 与卡相符 |
| 分支 tip 标题 | 以 `docs: IC-134` 开头 | 相符 |
| 代码 tip | `af4e55793b9e648f275fa4115205998e04cdf5f5` | 与卡逐字相符 |
| `git fetch` 后 `origin/main` | `39bade77dea68dd8b7b09b6a309d39ad54ae050f` | 未被他人推进 |

`git fetch origin --prune` 真实退出码 0。**注记**：首次以「清空全部代理环境变量走
直连」的方式 fetch 失败（`schannel: failed to receive handshake`），改用
`git -c http.proxy=… -c https.proxy=…` 的显式配置形式后一次成功——与本机既往
实测一致（本机 git 网络的两种走法偶有互换，见 CLAUDE.md 第五节注记）。

### 2. 结构预判核对：确认为快进式，零冲突 ①

- `git merge-base main feature/ic-134-s345-visual` = `39bade77dea68dd8b7b09b6a309d39ad54ae050f`，
  即 merge-base 等于 `main` tip 本身
- 分支自 `39bade7` 切出后 `main` 未被推进（`origin/main` 实测同为 `39bade7`），
  **卡内预判成立**
- 实际合并输出 `Merge made by the 'ort' strategy.`，**零冲突**，未触发任何冲突解决

### 3. 合并与推送 ①

- 命令：`git merge --no-ff feature/ic-134-s345-visual`（在 `main` 上执行）
- 合并提交：**`17736e3`** / `17736e37d682911b3e69a993b8a0e97069de692d`
  - parent1 = `39bade77dea68dd8b7b09b6a309d39ad54ae050f`（原 `main`）
  - parent2 = `54ac69e10d38c65092cc08ba8b32790b1e53dbf7`（分支 tip）
  - 提交标题：`merge: IC-134 S3／S4／S5 视觉层（#263 绿 674 项 0 失败，iOS 26.2 / iPhone 16）`
    ——照 IC-133 合并提交 `be77fd0` 的样式，逐字按卡内给定文本
- 推送：`git push origin main` 真实退出码 0，
  远端报文 `39bade7..17736e3  main -> main`（两点记法即非强推，无 `+` 前缀）
- 推送后 `git rev-parse main origin/main` 两者同为 `17736e37d682911b3e69a993b8a0e97069de692d`
- 并入提交共 12 个（分支 11 个 + 合并提交本身），提交链见 change-list
- **注记**：push 首次尝试同样以 `schannel` 握手失败告终，第 2 次尝试成功；
  同一条命令、未改任何参数（既往 IC-109 亦为第 3 次才成功，属本机网络抖动）

## 闸门逐条结论

### G751（合并推送后 `main` 自动运行）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#264**（run id `34145608586`，attempt 1） |
| 被测提交 | `17736e37d682911b3e69a993b8a0e97069de692d`（合并提交） |
| 触发事件 | `push`，分支 `main`（合并推送自动触发） |
| job | `101816883407`，conclusion=**success**，16:58:20Z→17:05:39Z |
| step 结果 | 10 个 step 全部 `success`，无 skipped、无 failure |
| XCTest 项数与失败数 | **Executed 674 tests, with 0 failures (0 unexpected) in 70.145 (86.839) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 「XCTest 执行摘要」notice | **在位**（IC-125 哨兵通过，674 > 0；纪律陷阱 20 已核） |
| 真实退出码 | **0**（工作流 `set -o pipefail` 且以 `exit "$test_status"` 原样退出；job conclusion=success；全日志无「Process completed with exit code」非零行） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| 选定日志行 | `使用 iPhone 模拟器：iPhone 16 (id=EADC2067-4553-4FDB-8780-62A3666009F5, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| 工具链 | `/Applications/Xcode_26.3.app/Contents/Developer/usr/bin/xcodebuild`（Xcode 26.3） |
| IPA 登记 | `PhotoCleanupMVE-unsigned.ipa`，**1293853 字节**，SHA-256 `efdc4e5ff7b7c9b97ed9186bc6f2a23fc52c82508c71c1a5d639b11c993c79b2` |
| 产物 | `PhotoCleanupMVE-unsigned-17736e37d682`，zip **1294023 字节**（外层压缩包，内含上述 IPA） |
| 实际发出的注解 | `##[notice]` **2** 条（执行摘要、IPA 校验）；`##[error]` **0** 条；`##[warning]` **0** 条 |

读数口径说明：日志中 `##[notice]` 每条各出现两次，是因为整包日志同时含根目录
`0_*.txt` 与分步 `7_*.txt`／`9_*.txt` 两份副本；去重后为 2 条。带 `[36;1m` 前缀的
`exit 1`、`::error title=…` 等字样均为 step 脚本清单的回显行，**不是实际发出的注解**。

IPA 字节数与 IC-134 分支侧 #263 完全相同（同为 **1293853**），SHA-256 不同
（#263 为 `9d8a05f9d7ab3d50a37e4c25b78178377997afbe0a53c8bafaad48e573d01241`）——
与「IPA 归档不可复现」的既往实证结论一致（②既往样本），同时反向印证合并未改变
任何产品代码（产品树与 `af4e557`／`54ac69e` 一致）。

CI 预算：`main` 侧自动运行 1 次即绿；分支侧本卡未再触发（卡内不授权），
IC-134 分支预算 4 次用 2 次的状态未变。

### G752（零冲突、文件集合相同、树对象相同）：**通过** ①

- 零冲突：合并输出为 `Merge made by the 'ort' strategy.`，无冲突文件
- `git diff --name-only 39bade7..17736e3` 与 `git diff --name-only 39bade7..54ac69e`
  **文件集合逐行相同**（两份排序后 `diff` 无差异，各 **22** 个文件）
- **树对象逐字节相同**：`git rev-parse 17736e3^{tree}` 与 `git rev-parse 54ac69e^{tree}`
  同为 **`c77280f41e330c60ebc29dc751132917827f89de`**。
  `git diff 17736e3 54ac69e` 输出为空。即合并**没有引入任何自身内容**，
  「本卡零产品代码改动」为字节级可证，不只是 diff 观察。
- 规模：22 文件 **+3407 −1130**（含二进制删除 1 个），逐文件明细见 change-list

### G753（版本号、S1／S2、冻结链与探针分支）：**通过** ①

- `S2CalibrationConfiguration.schemaVersion` 仍为 **7**
  （`Features/S2/S2Calibration.swift:118`；该文件不在 diff 文件集合内，
  出厂值集合未变，无需递增）
- **S2 零改动**：diff 文件集合中无任何 `Features/S2/` 路径文件（实测 `grep -i S2` 命中 0）
- **S1 只有 IC-134 已登记的那一处可见性变更**：`Features/S1/S1View.swift` 差异为
  **+5 −1**，其中语义改动**恰为一行**——第 536 行
  `private extension View` → `extension View`；另 4 行为解释该放宽理由的新增注释
  （原文写明「取值与行为一字未动」）。除此之外 S1 无任何改动。
  该处即 IC-134 报告「白名单外改动一」，经 ④ Lynn 显式授权。
- **共享文案文件未触及 S1／S2 键**：`Localizable.xcstrings` 有增删（+105 −105），
  逐键前缀统计为 `s5.` 增 27 删 21、`s3.` 增 21 删 19、`s4.` 增 5 删 12、
  `submission.` 删 1；**`s1.` 与 `s2.` 前缀的键一条未增、一条未删**（实测 grep 命中 0）
- 冻结三链与探针／其他分支 tip（合并前、合并后两次实测，均未变）：

| 分支 | tip | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 未变，与卡相符 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 未变，与卡相符 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 未变，与卡相符 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |
| `feature/ic-122-ios26-simulator` | `e7c02ab` | 未动 |
| `feature/ic-134-s345-visual` | `54ac69e` | 合并后仍在原 tip，未删除、未推进 |

### G754（未 rebase、未 amend、未强推）：**通过** ①

- `git reflog main` 顶部条目为
  `17736e3 main@{0}: merge feature/ic-134-s345-visual: Merge made by the 'ort' strategy.`，
  其下 `39bade7 main@{1}: commit: docs: IC-133 …` 原样保留——
  **无 rebase／amend／reset 记录**
- `git merge-base --is-ancestor 39bade7 main` → 真；
  `git merge-base --is-ancestor 54ac69e main` → 真。
  两个父提交均为新 `main` 的祖先，历史为线性追加，未改写
- 推送报文 **`39bade7..17736e3`**（两点，非 `+` 强推记法），退出码 0
- 全程未执行 `rebase`／`commit --amend`／`push --force`／`reset --hard`／删分支

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | 扫描通过：用户可见硬编码 0；目录 key 与产品源一致；结构门禁通过（文件、工程配置、String Catalog、PNG）；测试数量下界 189 项满足 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0 |
| `git diff --check`（工作树） | **0** | 无空白错误 |
| `git diff --check 39bade7..17736e3` | **0** | 合并范围内无空白错误 |
| `git status --porcelain`（合并后） | 空输出 | 工作树净 |

`selfcheck.ps1` 自 IC-134 起已不含 L3 专项门禁与占位图校验（IC-134 子项 F 授权删除
`FreeDiskSpaceReader.swift` 与占位图资源所致），本卡沿用该版本，未再改动。

## 人工判定项

**无。** H60 六项真机判定已由 Lynn 在合并前完成（④，卡内前置声明），
本卡不代为下结论、不重复判定。

## 发现但未处理的问题（按纪律只报告不修）

1. **`Reports/IC-134/self-check.md` 与 `change-list.md` 中「本卡不合并（G745），
   报告写完即停，等 H60」等句，在本卡之后已成为历史陈述**（①可核验）。该句在
   IC-134 交付时点准确；合并事实记录在本报告与本卡 change-list 中。按纪律第 7 条
   「报告提交不得跨卡回填」，**未回填修改 IC-134 的报告**，仅在此登记。
2. **CI 产物 zip 尺寸（1294023）与 IPA 尺寸（1293853）不是同一个数**（①）。
   本报告按卡要求登记的是 IPA 本身的字节数与 SHA-256（取自「未签名 IPA 校验」
   notice），产物行另列以免两数混用。既往报告惯例相同，非缺陷，仅提示读数口径。
3. **`Reports/` 与 Markdown 命中 `ci.yml` 的 `paths-ignore`**（①，
   `.github/workflows/ci.yml` 第 4～7 行），故本报告提交**不会触发 CI**，
   这是预期行为（CLAUDE.md 第五节）。G751 指向的 #264 验证的是产品代码所在的
   合并提交 `17736e3`，不需要也不应为报告提交追加 CI 闭环。
4. **本机 git 网络两次首发失败**（①）：`fetch` 与 `push` 各有一次
   `schannel: failed to receive handshake`；`fetch` 改 `-c http.proxy=…` 配置形式后
   成功，`push` 同命令第 2 次成功。与 CLAUDE.md 第五节注记及既往 IC-109 观察一致，
   属本机网络环境抖动，不影响任何交付内容，仅登记以免日后误判为仓库问题。

## 附录：CLAUDE.md 第七节更新（交 Lynn 执行，占位符已按实测填入）

> 本卡无权修改 `<top>/CLAUDE.md`，以下为按卡内模板填好实测值的成品文本，
> 供 Lynn 直接替换／追加。

「当前阶段」首行替换为：

```
- `main` = `17736e37d682911b3e69a993b8a0e97069de692d`（IC-135 merge 提交，CI #264，XCTest 674 项 0 失败，**iOS 26.2 模拟器 / iPhone 16**，Xcode 26.3 工具链），含 IC-054～IC-135 全部交付。S 阶段批次 1（S1）与批次 2（S3／S4／S5）均已收口：IC-131／132 S1 两处修正（空态垃圾桶口径、写回失败 toast；范围名入会话档、提交形成失败兜底）、IC-133 S3 行为层（空组即时消失、信息条口径、全部取消二次确认）、IC-134 S3／S4／S5 视觉层（chrome 与 S1 同套、分组三列网格与三件角标、体积明细侧通道、底部操作条、S4 单态、**S5 L3 整层撤销**与四态视觉），H58／H59／H60 真机判定通过。
```

同节追加两行：

```
- S3／S4／S5 视觉登记制常量分别在 `S3View.swift`／`S4View.swift`／`S5View.swift`，chrome 取值引用 `S1View.swift` 的登记常量与两个玻璃 helper（IC-134 起为 internal）；三页不自造 chrome 语汇。S5 不再读取磁盘可用空间（`FreeDiskSpaceReader` 已删），成功页只显示本次移入最近删除的照片占用并引导用户前往系统「最近删除」。
- `Scripts/selfcheck.ps1` 自 IC-134 起不再含 L3 专项门禁与占位图校验；S5-C 必需测试名单只余 `testCancellationDoesNotShowSystemErrorDomainOrCode`。
```
