# IC-130 自验报告

> 报告提交方式说明（执行纪律第 7 条）：本卡为合并卡，报告必须引用推送后才产生的
> 合并提交 SHA 与 G701 运行编号／IPA 校验，故采用「同一张卡、同一分支内追加一个
> docs 提交」的方式，随合并一并留在 `main` 上，不跨卡回填。

## 结论（先行）

**交付合格，合并完成，G701 绿。** `feature/ic-128-s1-visual` 已以 `--no-ff` 合入
`main`，合并提交 **`0bf5ebd`**（完整 SHA `0bf5ebda6418a7ea456c9ee1f6fb5aff6bc45d52`）。
如卡内预判，结构为快进式，**零冲突**，合并未引入任何自身改动。合并后 `main` 自动
触发运行 **#253** 一次通过：XCTest **640 项 0 失败**，真实退出码 0，
「XCTest 执行摘要」notice 在位，目的地 `OS:26.2, name:iPhone 16`。
四道闸门 G701～G704 全部通过。本地三条门禁退出码均为 0。
CI 预算 2 次用 1 次，rerun 预算未动用。人工判定项：无（H57 已由 Lynn 在合并前完成）。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260904-130-merge-128.md`
- 继承提交：`main` = `ded235b7e07c8c8d7d2bf4624eeb984425185bf6` ①
  提交标题逐字比对一致：
  `docs: IC-129 自验与变更清单 v2 完整替换版（#248 绿 625 项，合并入 main f0acdf4，#249 绿）`
- 待合并分支：`feature/ic-128-s1-visual`，tip = `e13842fc53b48862661c7616a357ae0b4b155c84` ①
  提交标题逐字比对一致：
  `docs: IC-128 自验报告与变更清单（#252 绿 640 项，停在报告等 H57）`
- 代码 tip：`f58b5c48f808fdab7c0c93d4767f2821aef4c73c` ①
  （`git log -1` 身份比对，非短前缀补全，纪律陷阱 15）
- 范围边界：只做合并与登记，**零产品代码与测试改动**

## 范围内逐项结果

### 1. 开工检查：全部相符 ①

| 检查项 | 实测 | 判定 |
|---|---|---|
| `git status --porcelain` | 空输出 | 工作树净，无他会话改动 |
| `main` tip | `ded235b7e07c8c8d7d2bf4624eeb984425185bf6` | 与卡逐字相符 |
| `main` tip 标题 | 见上，逐字比对 | 相符 |
| 分支 tip | `e13842fc53b48862661c7616a357ae0b4b155c84` | 与卡逐字相符 |
| 分支 tip 标题 | 见上，逐字比对 | 相符 |
| 代码 tip | `f58b5c48f808fdab7c0c93d4767f2821aef4c73c` | 与卡逐字相符 |
| `git fetch` 后 `origin/main` | `ded235b7e07c8c8d7d2bf4624eeb984425185bf6` | 未被他人推进 |

`git fetch origin --prune` 真实退出码 0（清空代理环境变量走直连）。

### 2. 结构预判核对：确认为快进式，零冲突 ①

- `git merge-base main feature/ic-128-s1-visual` = `ded235b7e07c8c8d7d2bf4624eeb984425185bf6`，
  即 merge-base 等于 `main` tip 本身
- `git merge-base --is-ancestor ded235b feature/ic-128-s1-visual` → 真
- 分支自 `ded235b` 切出后 `main` 未被推进，**卡内预判成立**
- 实际合并输出 `Merge made by the 'ort' strategy.`，**零冲突**，未触发任何冲突解决

### 3. 合并与推送 ①

- 命令：`git merge --no-ff feature/ic-128-s1-visual`（在 `main` 上执行）
- 合并提交：**`0bf5ebd`** / `0bf5ebda6418a7ea456c9ee1f6fb5aff6bc45d52`
  - parent1 = `ded235b7e07c8c8d7d2bf4624eeb984425185bf6`（原 `main`）
  - parent2 = `e13842fc53b48862661c7616a357ae0b4b155c84`（分支 tip）
  - 提交标题：`merge: IC-128 S1 视觉层（#252 绿 640 项 0 失败，iOS 26.2 / iPhone 16）`
- 推送：`git push origin main` 真实退出码 0，
  远端报文 `ded235b..0bf5ebd  main -> main`（两点记法即非强推，无 `+` 前缀）
- 推送后 `git rev-parse main origin/main` 两者同为 `0bf5ebda…`
- 并入提交共 7 个（分支 6 个 + 合并提交本身），提交链见 change-list

## 闸门逐条结论

### G701（合并后 `main` 自动运行）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#253**（run id `33982673249`，attempt 1） |
| 被测提交 | `0bf5ebda6418a7ea456c9ee1f6fb5aff6bc45d52`（合并提交） |
| 触发事件 | `push`（合并推送自动触发） |
| job | `101350580366`，conclusion=**success**，18:00:10Z→18:04:24Z |
| XCTest 项数与失败数 | **Executed 640 tests, with 0 failures (0 unexpected) in 46.382 (68.111) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 「XCTest 执行摘要」notice | **在位**（IC-125 哨兵通过，640 > 0；纪律陷阱 20 已核） |
| 真实退出码 | **0**（工作流 `set -o pipefail` 且以 `exit "$test_status"` 原样退出；job conclusion=success） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| 选定日志行 | `使用 iPhone 模拟器：iPhone 16 (id=EADC2067-4553-4FDB-8780-62A3666009F5, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| IPA 登记 | `PhotoCleanupMVE-unsigned.ipa`，**1199412 字节**，SHA-256 `f52371f04fcfeea45fa154272fab563448a3707f30b004003f4b00d85733a65e` |
| 产物 | `PhotoCleanupMVE-unsigned-0bf5ebda6418`，zip 1199582 字节（外层压缩包，内含上述 IPA） |
| 实际发出的注解 | `##[notice]` 2 条（执行摘要、IPA 校验）；`##[error]` **0** 条；`##[warning]` **0** 条 |

读数口径说明：日志中出现的 `::error title=XCTest 哨兵…` 等字样均为 step 脚本清单的
回显行（带 `[36;1m` 前缀），**不是实际发出的注解**；实际发出者以 `##[error]` 计，为 0。

IPA 字节数与 IC-128 分支 #252 完全相同（同为 1199412），SHA-256 不同
（#252 为 `49fce55d…`）——与「IPA 归档不可复现」的既往实证结论一致（②既往样本），
同时反向印证合并未改变任何产品代码（产品树与 `f58b5c4` 一致）。

CI 预算：主跑 1 次即绿；rerun 预算（runner 偶发签名失败）**未动用**。

### G702（合并零冲突、零产品代码改动）：**通过** ①

- 零冲突：合并输出为 `Merge made by the 'ort' strategy.`，无冲突文件
- `git diff --name-only ded235b..0bf5ebd` 与 `git diff --name-only ded235b..e13842f`
  **文件集合逐行相同**（`diff` 比对无差异），即卡内列举的五个文件外加
  `Reports/IC-128/` 两份，共 7 个：

| 文件 | +/− |
|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4 −0 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | +3 −42 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | +1539 −149 |
| `PhotoCleanupMVE/Localizable.xcstrings` | +101 −24 |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | +554 −0 |
| `Reports/IC-128/change-list.md` | +90 −0 |
| `Reports/IC-128/self-check.md` | +122 −0 |

  合计 7 文件 +2413 −215，与 `ded235b..e13842f` 数值一致。
- **更强的证据**：合并提交的树对象与分支 tip 的树对象**完全相同**——
  `git rev-parse 0bf5ebd^{tree}` 与 `git rev-parse e13842f^{tree}` 同为
  `c253a8150127b3423283b7bc6899dd68fab02b84`。即合并**没有引入任何自身内容**，
  「本卡零产品代码改动」为字节级可证，不只是 diff 观察。

### G703（版本号、S2～S5、冻结链与探针分支）：**通过** ①

- `S2CalibrationConfiguration.schemaVersion` 仍为 **7**
  （`Features/S2/S2Calibration.swift:118`；该文件根本不在 diff 文件集合内，
  出厂值集合未变，无需递增）
- S2～S5 产品代码零改动：diff 文件集合中不含任何 `S2`／`S3`／`S4`／`S5` 路径；
  改动的产品文件仅 `Core/S1StateMachine.swift`、`Features/S1/S1View.swift`
  与共享的 `Localizable.xcstrings`。xcstrings 的增删键**全部为 `s1.` 前缀**
  （新增 19 键、删除 12 键，逐键核对），未触及 S2～S5 文案。
- 冻结三链与探针／其他分支 tip（本地与远端一致，合并前后两次实测均未变）：

| 分支 | tip | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 未变，与卡相符 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 未变，与卡相符 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 未变，与卡相符 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |
| `feature/ic-122-ios26-simulator` | `e7c02ab` | 未动 |
| `feature/ic-128-s1-visual` | `e13842f` | 合并后仍在原 tip，未删除、未推进 |

### G704（未 rebase、未 amend、未强推）：**通过** ①

- `git reflog main` 顶部条目为
  `0bf5ebd main@{0}: merge feature/ic-128-s1-visual: Merge made by the 'ort' strategy.`，
  其下 `ded235b main@{1}` 原样保留——无 rebase／amend／reset 记录
- `git merge-base --is-ancestor ded235b main` → 真；
  `git merge-base --is-ancestor e13842f main` → 真。
  两个父提交均为新 `main` 的祖先，历史为线性追加，未改写
- 推送报文 `ded235b..0bf5ebd`（两点，非 `+` 强推记法），退出码 0
- 全程未执行 `rebase`／`commit --amend`／`push --force`／`reset --hard`

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | String Catalog 206 条目 ↔ 206 源码引用一致；用户可见硬编码残留 0；禁联网门禁、不少于 189 项测试的数量门禁、PNG 与工程配置均通过 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0；非用户界面断言诊断 213、规格锁定格式豁免 5、Info.plist 边界 2，均为既有登记 |
| `git diff --check` | **0** | `ded235b..0bf5ebd` 无空白错误 |

## 人工判定项

**无。** H57 五项真机判定已由 Lynn 在合并前完成（④，卡内前置声明），
本卡不代为下结论、不重复判定。

## 发现但未处理的问题（按纪律只报告不修）

1. **`Reports/IC-128/change-list.md` 末行「G514：未合并，分支停在 `f58b5c4` 等 H57」
   在本卡之后已成为历史陈述**（①可核验）。该句在 IC-128 交付时点准确；合并事实
   记录在本报告与本卡 change-list 中。按纪律第 7 条「报告提交不得跨卡回填」，
   **未回填修改 IC-128 的报告**，仅在此登记。
2. **CI 产物 zip 尺寸（1199582）与 IPA 尺寸（1199412）不是同一个数**（①）。
   本报告按卡要求登记的是 IPA 本身的字节数与 SHA-256（取自「未签名 IPA 校验」
   notice），产物行另列以免两数混用。既往报告惯例相同，非缺陷，仅提示读数口径。
3. **`Reports/` 与 Markdown 命中 `ci.yml` 的 `paths-ignore`**（①，
   `.github/workflows/ci.yml` 第 4～7 行），故本报告提交**不会触发 CI**，
   这是预期行为（CLAUDE.md 第五节）。G701 指向的 #253 验证的是产品代码所在的
   合并提交 `0bf5ebd`，不需要也不应为报告提交追加 CI 闭环。

## 附录：CLAUDE.md 第七节更新（交 Lynn 执行，占位符已按实测填入）

> 本卡无权修改 `<top>/CLAUDE.md`，以下为按卡内模板填好实测值的成品文本，
> 供 Lynn 直接替换／追加。

「当前阶段」首行替换为：

```
- `main` = `0bf5ebda6418a7ea456c9ee1f6fb5aff6bc45d52`（IC-130 merge 提交，CI #253，XCTest 640 项 0 失败，**iOS 26.2 模拟器 / iPhone 16**，Xcode 26.3 工具链），含 IC-054～IC-130 全部交付。S 阶段批次 1（S1 范围列表）已收口：IC-127 数据与行为层（分组维度收三类、按日期改年→月两级树、会话跨启动持久化、外部变更对账、授权分派与失败分类、提交排序）、IC-129 对账改按资产存在性、IC-128 视觉层（chrome 三件与 S2 同语汇、缩略图承载已处理进度与待删计数、两个互斥菜单、受限授权提示条、四态版式与文案落 String Catalog），H57 五项真机判定通过。
```

同节末尾追加一行：

```
- S1 视觉登记制常量在 `S1View.swift`，取值全部源自 SPEC-S2 v18 第十一节第 2 部分；S1 不自造 chrome 语汇。范围封面取「该范围按当前 `O` 排序的第一张」，年节点递归取首个子范围的封面。
```
