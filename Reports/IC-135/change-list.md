# IC-135 变更清单

本卡为合并卡：**零产品代码改动、零测试改动**，只做 `--no-ff` 合并、推送、CI 登记与报告。

- 继承提交：`main` = `39bade77dea68dd8b7b09b6a309d39ad54ae050f`
- 待合并分支：`feature/ic-134-s345-visual`，tip `54ac69e10d38c65092cc08ba8b32790b1e53dbf7`，
  代码 tip `af4e55793b9e648f275fa4115205998e04cdf5f5`
- **合并提交：`17736e3` / `17736e37d682911b3e69a993b8a0e97069de692d`**
  - parent1 `39bade77dea68dd8b7b09b6a309d39ad54ae050f`（原 `main`）
  - parent2 `54ac69e10d38c65092cc08ba8b32790b1e53dbf7`（分支 tip）
  - 标题 `merge: IC-134 S3／S4／S5 视觉层（#263 绿 674 项 0 失败，iOS 26.2 / iPhone 16）`
  - 结构：`merge-base` = 原 `main` tip，快进式，`Merge made by the 'ort' strategy.`，**零冲突**
- 推送报文：`39bade7..17736e3  main -> main`（两点记法，非强推），退出码 0
- 报告提交：本卡 docs 提交（`Reports/IC-135/` 两份），随合并留在 `main`，不跨卡回填

## 并入的提交链（12 个，均原样带入，未 rebase／未 amend）

| 提交 | 内容 |
|---|---|
| `d3775c7` | 前置：S1 玻璃 helper `private extension View` → `extension View`（④ Lynn 授权，白名单就此一行） |
| `0af8f39` | A：S3 顶排 chrome、提示句、三态骨架与空态 |
| `2370eba` | B：S3 分组网格、格子三件角标与移除 |
| `4ea4ea1` | C：S3 体积明细——扫描侧通道与跨三列展开行 |
| `a732d8d` | D：S3 底部操作条、全部取消接线与文案收口 |
| `874fede` | E：S4 执行中页整层重写 |
| `ce1758e` | F：L3「设备可用空间变化」整层撤销（④ Lynn 2026-09-06） |
| `5187bda` | G：S5 完成页四态视觉 |
| `47ea220` | test：二十四条断言（S3 十四条、S4／S5 十条） |
| `af4e557` | fix：`IC134S3VisualTests` 的 pbxproj id 与 IC-133 撞号（#262 漏编译归因）（**代码 tip**） |
| `54ac69e` | docs：IC-134 自验与变更清单（**分支 tip**） |
| `17736e3` | **本卡合并提交**（`--no-ff`） |

## 文件级变更（`39bade7..17736e3`，22 文件 +3407 −1130）

全部内容来自 IC-134 分支，本卡未增删任何一行。

| 文件 | +/− | 归属 |
|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +8 −4 | IC-134（两个测试文件登记；`af4e557` 改号） |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | +25 −34 | IC-134 F（L3 撤销）／E |
| `PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/Contents.json` | +0 −24 | IC-134 F（占位图资源删除） |
| `PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/RECENTLY_DELETED_PLACEHOLDER.png` | 二进制删除 | IC-134 F |
| `PhotoCleanupMVE/Core/S5StateMachine.swift` | +10 −115 | IC-134 F（L3 整层撤销） |
| `PhotoCleanupMVE/Core/SessionPersistence.swift` | +3 −12 | IC-134 F |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | +5 −1 | IC-134 前置（**语义改动恰一行**：可见性放宽；另 4 行为理由注释） |
| `PhotoCleanupMVE/Features/S3/S3View.swift` | +888 −130 | IC-134 A～D（S3 视觉层） |
| `PhotoCleanupMVE/Features/S4/S4View.swift` | +127 −68 | IC-134 E（S4 单态） |
| `PhotoCleanupMVE/Features/S5/S5View.swift` | +588 −108 | IC-134 G（S5 四态视觉） |
| `PhotoCleanupMVE/Features/Shared/ThumbnailView.swift` | +23 −2 | IC-134 B（封面请求 2×／3×） |
| `PhotoCleanupMVE/Localizable.xcstrings` | +105 −105 | IC-134 A～G（键全为 `s3.`／`s4.`／`s5.` 前缀，另删 `submission.asset_count` 1 条） |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | +55 −4 | IC-134 C（体积明细侧通道） |
| `PhotoCleanupMVE/Services/FreeDiskSpaceReader.swift` | +0 −13 | IC-134 F（整文件删除） |
| `PhotoCleanupMVETests/CoverageGapTests.swift` | +15 −185 | IC-134 F（L3 相关用例清理） |
| `PhotoCleanupMVETests/IC134S3VisualTests.swift` | +495 −0 | IC-134（S3 十四条断言，新增） |
| `PhotoCleanupMVETests/IC134S4S5VisualTests.swift` | +497 −0 | IC-134（S4／S5 十条断言，新增） |
| `PhotoCleanupMVETests/S5StateMachineTests.swift` | +1 −241 | IC-134 F |
| `PhotoCleanupMVETests/TransitionTableGuardTests.swift` | +4 −4 | IC-134 F |
| `Reports/IC-134/change-list.md` | +237 −0 | IC-134 报告 |
| `Reports/IC-134/self-check.md` | +320 −0 | IC-134 报告 |
| `Scripts/selfcheck.ps1` | +1 −80 | IC-134（删 L3 专项门禁与占位图校验，④ Lynn 两次授权） |

**文件集合与 `39bade7..54ac69e` 逐行相同**（各 22 个文件，排序后 `diff` 无差异）。
合并提交树对象 `c77280f41e330c60ebc29dc751132917827f89de` 与 `54ac69e` 树对象相同，
`git diff 17736e3 54ac69e` 输出为空——合并未引入任何自身内容。

本卡自身新增文件（不在上表，属报告提交）：

| 文件 | 说明 |
|---|---|
| `Reports/IC-135/self-check.md` | 本卡自验报告 |
| `Reports/IC-135/change-list.md` | 本文件 |

## 占位值登记

**无变更。** 出厂值集合未动，`S2CalibrationConfiguration.schemaVersion` 保持 **7**
（`Features/S2/S2Calibration.swift:118`，该文件不在 diff 文件集合内）；
`factoryPlaceholder` 登记制不变。S3／S4／S5 视觉常量走各自 `S3View.swift`／
`S4View.swift`／`S5View.swift` 的登记制容器，chrome 取值引用 `S1View.swift` 的登记
常量与两个玻璃 helper，均不进标定配置、不上标定面板，因此不构成出厂值集合变更、
无需递增版本号。

## 分支与冻结链状态（合并前后两次实测，本地＝远端）

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `17736e3` | 本卡推进（合并提交） |
| `feature/ic-134-s345-visual` | `54ac69e` | 保留在原 tip，未删除 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |
| `feature/ic-122-ios26-simulator` | `e7c02ab` | 未动 |

## CI

- **G751：合并触发的 `main` 自动运行 #264**（run id `34145608586`，attempt 1）——**绿**
  - 被测提交 `17736e37d682911b3e69a993b8a0e97069de692d`，事件 `push`，分支 `main`
  - **Executed 674 tests, with 0 failures (0 unexpected) in 70.145 (86.839) seconds**；
    `** TEST SUCCEEDED **` 在位
  - 「XCTest 执行摘要」notice 在位（IC-125 哨兵通过，674 > 0）；
    实际发出 `##[notice]` 2 条、`##[error]` 0 条、`##[warning]` 0 条
  - 真实退出码 **0**（job `101816883407` conclusion=success，10 个 step 全 success；
    工作流 `set -o pipefail` 且以 `exit "$test_status"` 原样退出）
  - 目的地 `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`；
    工具链 Xcode 26.3
  - IPA `PhotoCleanupMVE-unsigned.ipa`，**1293853 字节**，
    SHA-256 `efdc4e5ff7b7c9b97ed9186bc6f2a23fc52c82508c71c1a5d639b11c993c79b2`
  - 产物 `PhotoCleanupMVE-unsigned-17736e37d682`，zip 1294023 字节
- `main` 侧 1 次即绿；本卡不授权分支侧 CI，IC-134 分支预算（4 次用 2 次）未动
- 参照：分支侧 #263（run id `34079402643`，被测 `af4e557…`）同为 674 项 0 失败，
  IPA 亦为 1293853 字节、SHA-256 `9d8a05f9…`（字节数同、哈希异，符合 IPA 不可复现的既往结论）
- 本报告提交命中 `ci.yml` 的 `paths-ignore`（`Reports/**`、`**.md`），**不触发 CI**，为预期行为

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（工作树） | 0 |
| `git diff --check 39bade7..17736e3` | 0 |
