# IC-130 变更清单

本卡为合并卡：**零产品代码改动、零测试改动**，只做 `--no-ff` 合并、推送、CI 登记与报告。

- 继承提交：`main` = `ded235b7e07c8c8d7d2bf4624eeb984425185bf6`
- 待合并分支：`feature/ic-128-s1-visual`，tip `e13842fc53b48862661c7616a357ae0b4b155c84`，
  代码 tip `f58b5c48f808fdab7c0c93d4767f2821aef4c73c`
- **合并提交：`0bf5ebd` / `0bf5ebda6418a7ea456c9ee1f6fb5aff6bc45d52`**
  - parent1 `ded235b7e07c8c8d7d2bf4624eeb984425185bf6`（原 `main`）
  - parent2 `e13842fc53b48862661c7616a357ae0b4b155c84`（分支 tip）
  - 标题 `merge: IC-128 S1 视觉层（#252 绿 640 项 0 失败，iOS 26.2 / iPhone 16）`
  - 结构：快进式，`Merge made by the 'ort' strategy.`，**零冲突**
- 报告提交：本卡 docs 提交（`Reports/IC-130/` 两份），随合并留在 `main`，不跨卡回填

## 并入的提交链（7 个，均原样带入，未 rebase／未 amend）

| 提交 | 内容 |
|---|---|
| `00e32f8` | A：视觉常量容器 + 顶排 chrome 三件（含徽标与禁用态）+ 测试文件登记 |
| `655fe70` | B：范围卡（封面缩略图、进度线、待删红点、两级树、年垫卡） |
| `9022fc1` | C：两个互斥菜单 + 受限提示条 |
| `f2b86c0` | D：四态版式 + 文案落 String Catalog + 清登记项 |
| `2fb504e` | fix（C）：补 `import PhotosUI` |
| `f58b5c4` | fix（D）：清除说明注释避开占位 key 字面量（**代码 tip**） |
| `e13842f` | docs：IC-128 自验报告与变更清单（**分支 tip**） |
| `0bf5ebd` | **本卡合并提交**（`--no-ff`） |

## 文件级变更（`ded235b..0bf5ebd`，7 文件 +2413 −215）

全部内容来自 IC-128 分支，本卡未增删任何一行。

| 文件 | +/− | 归属 |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4 −0 | IC-128（测试文件登记） |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | +3 −42 | IC-128 D（清视觉／文案登记项） |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | +1539 −149 | IC-128 A～D（视觉层） |
| `PhotoCleanupMVE/Localizable.xcstrings` | +101 −24 | IC-128 D（S1 文案，键全为 `s1.` 前缀） |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | +554 −0 | IC-128（15 项测试） |
| `Reports/IC-128/change-list.md` | +90 −0 | IC-128 报告 |
| `Reports/IC-128/self-check.md` | +122 −0 | IC-128 报告 |

**文件集合与 `ded235b..e13842f` 逐行相同**（G702 要求的五个产品／测试文件外加
`Reports/IC-128/` 两份）。合并提交树对象 `c253a8150127b3423283b7bc6899dd68fab02b84`
与 `e13842f` 树对象相同——合并未引入任何自身内容。

本卡自身新增文件（不在上表，属报告提交）：

| 文件 | 说明 |
|---|---|
| `Reports/IC-130/self-check.md` | 本卡自验报告 |
| `Reports/IC-130/change-list.md` | 本文件 |

## 占位值登记

**无变更。** 出厂值集合未动，`S2CalibrationConfiguration.schemaVersion` 保持 **7**
（`Features/S2/S2Calibration.swift:118`，该文件不在 diff 文件集合内）；
`factoryPlaceholder` 登记制不变。S1 视觉常量走 `S1View.swift` 的登记制容器，
不进标定配置、不上标定面板，因此不构成出厂值集合变更、无需递增版本号。

## 分支与冻结链状态（合并前后两次实测，本地＝远端）

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `0bf5ebd` | 本卡推进（合并提交） |
| `feature/ic-128-s1-visual` | `e13842f` | 保留在原 tip，未删除 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |
| `feature/ic-122-ios26-simulator` | `e7c02ab` | 未动 |

## CI

- **G701：合并触发的 `main` 自动运行 #253**（run id `33982673249`，attempt 1）——**绿**
  - 被测提交 `0bf5ebda6418a7ea456c9ee1f6fb5aff6bc45d52`
  - **Executed 640 tests, with 0 failures (0 unexpected)**；`** TEST SUCCEEDED **`
  - 「XCTest 执行摘要」notice 在位（IC-125 哨兵通过）；`##[error]` 0 条、`##[warning]` 0 条
  - 真实退出码 **0**（job `101350580366` conclusion=success）
  - 目的地 `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`
  - IPA `PhotoCleanupMVE-unsigned.ipa`，**1199412 字节**，
    SHA-256 `f52371f04fcfeea45fa154272fab563448a3707f30b004003f4b00d85733a65e`
  - 产物 `PhotoCleanupMVE-unsigned-0bf5ebda6418`，zip 1199582 字节
- 预算 2 次 **用 1 次**；rerun 预算（runner 偶发签名失败）未动用
- 参照：分支侧 #252（run id `33978995850`，被测 `f58b5c4…`）同为 640 项 0 失败，
  IPA 亦为 1199412 字节、SHA-256 `49fce55d…`（字节数同、哈希异，符合 IPA 不可复现的既往结论）
- 本报告提交命中 `ci.yml` 的 `paths-ignore`（`Reports/**`、`**.md`），**不触发 CI**，为预期行为

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（`ded235b..0bf5ebd`） | 0 |
