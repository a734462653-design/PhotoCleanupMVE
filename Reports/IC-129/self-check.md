# IC-129 自验报告（v2 完整替换版）

> 报告提交方式说明（执行纪律第 7 条）：报告须引用推送后才产生的 CI 运行编号、
> IPA 校验、合并提交 SHA 与 G605 结果，故采用「同一张卡内追加 docs 提交」的方式：
> v1 随分支在合并前提交（`9857c36`），本 v2 在合并与 G605 核验后完整替换补记，
> 不跨卡回填。

## 结论（先行）

**交付合格，全绿，已合并入 `main`。** 对账依据已由「当前维度本次读到的范围集合」
改为资产存在性（叠加于既有按范围收敛之上，不替换）。CI 主跑 #248 一次通过：
XCTest **625 项 0 失败**（较基数 619 增 6 项，即本卡六个新测试），真实退出码 0，
目的地 iOS 26.2 / iPhone 16，「XCTest 执行摘要」notice 在位。IC-127 两条回归断言
原样保留并通过。本地三条门禁退出码均为 0。G604 `--no-ff` 合并提交 **`f0acdf4`**；
G605 合并触发的 `main` 运行 **#249 绿**（625 项 0 失败，含执行摘要 notice）。
CI 预算用 1 次主跑，修复预算未动用。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260904-129-reconcile-by-existence.md`
- 继承提交：`main` = `a3cc9eba0cfc94f476e00777efc1138e4f103b77`，
  `git log --oneline -1 main` 与卡内标题逐字比对一致
  （`docs: IC-127 自验与变更清单 v2 完整替换版（六子项交付，#246 绿 619 项，合并入 main，#247 绿）`）①
- 目标分支：`feature/ic-129-reconcile-by-existence`，自该 `main` 切出
- 被测提交（完整 SHA）：`c7bf5da2c193edd128aa6983ea13ee0d95a2f4ea`（单子项一个 commit）
- 范围边界：白名单六文件（见 change-list），S1View 等界面层零改动

## 根因假设核对

卡内假设（③）：缺口出自 `S1StateMachine.adoptRanges` →
`reconciledStore(_:against: newRanges)` 只按本次读到的 `R(T)` 收敛。
**确认**（①源码可核验）：`S1StateMachine.swift` 原 549 行确为该收敛点，
`reconciledStore` 只遍历 `newRanges`，当前维度之外范围的 `M` 条目无任何剔除路径；
`testIC129A`／`testIC129D` 构造的「范围不在本次 `R(T)` 中」场景在新实现下由存在性
收敛剔除，反证旧实现下无收敛入口。无与假设矛盾的实测数据。

## 实现摘要

- `SessionStore.reconcileMarkedAssets(existingAssetIDs:)`：按存在性收敛 `M` 全部
  范围，经 `setMarked(false)` 同步删 `F` 键；幂等；`K` 钳制仍只由按范围收敛负责
  （钳制需要序列，存在性给不出序列）。
- `S1StateMachine.assetExistenceProbe`（注入式）：`adoptRanges` 在按范围收敛之上
  叠加存在性收敛——以 `M` 全范围并集**一次**批量查询，`M` 为空不查询；探针为
  nil（未注入的夹具）时退回旧行为。进入 S1（`completeRangeRead`）与 S2 返回
  （`reconcile(with:)`）两条路径共用此收敛点，**调用时机不变**。
- `PhotoLibraryService.existingAssetIdentifiers(among:)`：一次批量取回
  （生产实现 `PHAsset.fetchAssets(withLocalIdentifiers:)` 单次调用），返回入参中
  仍存在的子集；`S1PhotoLibrarySource` 新增 `fetchExistingAssetIdentifiers` 闭包
  作为可注入缝，夹具默认值「入参全部仍存在」等价旧行为，既有测试构造点零改动。
- `CleanupCoordinator.installS1Session(_:route:)`：安装状态机时注入探针。注入点
  选在安装处而非 `reconcileS1WithPhotoLibrary` 内，因进入 S1 的对账走
  S1View → `completeRangeRead`（S1View 不在白名单），安装点注入是覆盖两个既有
  时机的唯一合规位置；`reconcileS1WithPhotoLibrary` 本身零改动。

## 验收门禁逐条结果

### 卡内六条必增断言（全部落实，#248 全过）①

| # | 断言 | 测试函数 | 结果 |
|---|---|---|---|
| 1 | 跨维度场景：相册维度标记 → 切按日期 → 资产被删 → `D_全部`／徽标收敛、`F` 键已删 | `testIC129A_CrossDimensionStaleAssetIsPrunedByExistence` | passed |
| 2 | 同一资产落在两个维度的范围内，一次对账两侧都剔除、`D_全部` 无残留 | `testIC129B_AssetMarkedInTwoDimensionsIsPrunedFromBothRanges` | passed |
| 3 | 范围失效（整本相册被删）与资产失效同时发生都被正确收敛；仍存在的资产保持标记（既有逻辑保留、两者叠加） | `testIC129C_RangeAndAssetInvalidationConvergeTogether` | passed |
| 4 | 幂等：连调两次结果相同，第二次零写入（持久化写入计数钉住）；每次对账单次批量查询、`M` 空不查询 | `testIC129D_ReconciliationIsIdempotentAndSecondPassWritesNothing` | passed |
| 5 | 静默：加载态不变、`readFailure` 不写、协调器 `message` 为空 | `testIC129E_ExistenceReconciliationIsSilent` | passed |
| 6 | 回归：IC-127 两断言未改写未删除，原样通过 | `testIC127C_EntryAndS2ReturnEachReconcileOnceAndSubmissionUsesNoFallback`、`testIC127C_FallbackCounterDetectsStaleAssetsBeforeReconciliation` | passed |

补充（服务层）：`testIC129F_ServiceExistenceQueryIsSingleBatchAndReturnsSubset`——
单次批量调用、只返回入参子集、空入参不发起查询、夹具默认值语义钉住。passed。

### G601（diff 限于白名单）：通过

diff 共 6 文件，全部在卡内白名单。两个受限文件的改动函数清单：

- `Services/PhotoLibraryService.swift`（仅存在性 API 及其注入缝）：
  - 新增 `PhotoLibraryService.existingAssetIdentifiers(among:)`
  - `S1PhotoLibrarySource` 新增字段 `fetchExistingAssetIdentifiers`、新增显式
    `init(authorizationStatus:fetchAssets:fetchAssetCollections:fetchExistingAssetIdentifiers:)`
    （末参数带夹具默认值）、`static let production` 增加该闭包的生产实现
  - S2～S5 相关 API 零改动
- `App/CleanupCoordinator.swift`（仅接线）：
  - `installS1Session(_:route:)`（S1StateMachine 参数的重载）新增
    `machine.assetExistenceProbe` 注入（8 行）
  - 所有 `s2*` 成员与 S3／S4／S5 路由零改动

### G602：通过 ①

- S2～S5 产品代码零改动（diff 未触及 Features/S2～S5、S3～S5 StateMachine）
- `S2CalibrationConfiguration.schemaVersion == 7` 未变（出厂值集合无变更）
- 冻结三链 tip 未变：`b368a6c` / `6736f1e` / `a7cc1ec`（`git rev-parse` 实测）

### G603（CI 绿）：通过 ①

- 运行编号：**#248**（run id `33967595635`），触发提交
  `c7bf5da2c193edd128aa6983ea13ee0d95a2f4ea`
- XCTest：**Executed 625 tests, with 0 failures (0 unexpected)**（619 + 6）
- 「XCTest 执行摘要」notice：在位（IC-125 哨兵通过，625 > 0）
- 真实退出码：0（工作流 `set -o pipefail` + `exit "$test_status"` 原样退出，
  job「构建、XCTest 与未签名打包」conclusion=success）
- 目的地实证行：`{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`；
  选定日志行：`使用 iPhone 模拟器：iPhone 16 (id=EADC2067-…, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`
- IPA 登记：`PhotoCleanupMVE-unsigned.ipa`，**1100833 字节**，
  SHA-256 `90270d1c2e5b52877f8d752cc38c40ba59fd1aed27381c263aa0d172602aa1fc`
- CI 预算：1 次主跑即绿，修复预算未动用

### 本地门禁（真实退出码）①

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0（含 ≥189 项测试数量门禁、禁联网门禁、String Catalog 一致性） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0（用户可见硬编码残留 0；目录 199 key 与源码一致，本卡无文案增删，xcstrings 未动） |
| `git diff --check` | 0 |

### G604（合并前置 + 合并）：通过 ①

- 前置逐项：G601～G603 全满足；`git status --porcelain` 为空（工作树净）；
  `git ls-remote origin main` = `a3cc9eb…`（`main` 未被他人推进，与继承提交一致）
- 合并：`--no-ff` 合并提交 **`f0acdf4`**
  （完整 SHA `f0acdf48d3c34ea9a49f0fbe68538d986254f191`），已推送

### G605（合并后 `main` 自动运行）：绿 ①

- 运行编号：**#249**（run id `33972006648`），触发提交 `f0acdf4…`（合并提交）
- 结果：conclusion=success；**Executed 625 tests, with 0 failures (0 unexpected)**；
  「XCTest 执行摘要」notice 在位
- IPA：`PhotoCleanupMVE-unsigned.ipa`，1100833 字节，
  SHA-256 `1ffb237165918facfb64bee65bcd8d7649235cc093df59cf8215d14f92bbec05`
  （与 #248 字节数相同、哈希不同——IPA 构建不可复现为既往实证结论，非异常）

## 人工判定项

无（卡内明示）。

## 发现但未处理的问题（按纪律只报告不修）

1. **范围失效但资产仍存在时，`K` 续接的收敛缺口仍在**（①源码可核验）：整本相册
   被删后，其 `M` 中仍存在的资产保持标记（本卡规定的既有行为保留），但该范围的
   `K` 续接（`c_范围`／`p_范围`）永远等不到「该范围出现在 `R(T)` 中」的钳制机会。
   存在性收敛无法代劳——钳制需要序列。影响限于续接展示，不影响 `D_全部`。
2. **受限授权（limited）下的存在性口径**（③推测）：`PHAsset.fetchAssets(withLocalIdentifiers:)`
   在受限授权下预期只返回用户选中的可见资产；曾在完全授权下标记、之后被移出可见
   集的资产会被存在性收敛按「不存在」剔除。与 `R(T)` 读取的可见性口径一致，故未
   视为缺陷；验证需真机改授权实测，模拟器测试未覆盖该组合。
3. `setMarked(false)` 剔除后可能在 `M` 字典中留下空集合条目（既有
   `reconcileRange` 同样如此，非本卡引入）；`allPendingDeletionAssetIDs` 等消费
   端不受影响。
