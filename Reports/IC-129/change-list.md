# IC-129 变更清单（v1，合并前版本）

分支：`feature/ic-129-reconcile-by-existence`（自 `main` = `a3cc9eb` 切出）
提交：`c7bf5da2c193edd128aa6983ea13ee0d95a2f4ea`
`feat: IC-129 对账依据改为资产存在性（补 IC-127 跨维度缺口）`
（单子项，单 commit，可独立 cherry-pick；合并提交短 SHA 见 v2 补记）

## 文件级变更（6 文件，+538 −3）

| 文件 | 变更 | 白名单对应项 |
|---|---|---|
| `PhotoCleanupMVE/Services/PhotoLibraryService.swift` | +41：`S1PhotoLibrarySource` 新增 `fetchExistingAssetIdentifiers` 闭包字段与显式 init（末参带夹具默认值「入参全部仍存在」）；`production` 增加生产实现（`PHAsset.fetchAssets(withLocalIdentifiers:)` 单次批量取回）；新增 `PhotoLibraryService.existingAssetIdentifiers(among:)`（空入参不查询，返回入参子集） | 仅新增按资产标识批量查存在性的 API 及其注入缝；S2～S5 API 未动 |
| `PhotoCleanupMVE/Core/SessionStore.swift` | +18：新增 `reconcileMarkedAssets(existingAssetIDs:)`——`M` 全部范围剔除不在存在集合中的资产，经 `setMarked(false)` 同步删 `F` 键；幂等；返回是否有改动 | `M`／`F` 的收敛入口 |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | +20 −3：新增注入式 `assetExistenceProbe` 属性；`adoptRanges` 在按范围收敛之上叠加存在性收敛（`M` 并集一次批量查询，`M` 空不查询，探针 nil 时行为同旧）；`reconciledStore` 顶注释随语义更新 | 对账相关 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | +8：`installS1Session(_:route:)`（S1StateMachine 重载）注入 `assetExistenceProbe`（`MainActor.assumeIsolated` 包装对 @MainActor 服务的同步调用）。注入点选安装处：进入 S1 的对账经 S1View → `completeRangeRead`，S1View 不在白名单，安装点是覆盖「进入 S1」「S2 返回」两个既有时机的唯一合规位置 | 仅把新 API 接到既有对账入口；`s2*` 与 S3／S4／S5 路由未动 |
| `PhotoCleanupMVETests/IC129ExistenceReconciliationTests.swift` | 新文件 +447：`IC129LibraryBox` 夹具（可外部删资产／删整本相册，存在性=仍在照片库）；测试 A～F 对应卡内断言 1～5 与服务层补充；IC-127 两条回归断言所在文件零改动 | 测试 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4：新测试文件四处登记（PBXBuildFile `2000…0032`、PBXFileReference `1000…0035`、测试组 children、测试源码阶段） | 新增测试文件的文件登记 |

## 断言 → 测试函数对照

1. 跨维度剔除 → `testIC129A_CrossDimensionStaleAssetIsPrunedByExistence`
2. 双维度同资产两侧剔除 → `testIC129B_AssetMarkedInTwoDimensionsIsPrunedFromBothRanges`
3. 范围失效＋资产失效同时收敛 → `testIC129C_RangeAndAssetInvalidationConvergeTogether`
4. 幂等＋第二次零写入＋单次批量查询 → `testIC129D_ReconciliationIsIdempotentAndSecondPassWritesNothing`
5. 静默 → `testIC129E_ExistenceReconciliationIsSilent`
6. IC-127 回归（未改写未删除）→ `testIC127C_EntryAndS2ReturnEachReconcileOnceAndSubmissionUsesNoFallback`、`testIC127C_FallbackCounterDetectsStaleAssetsBeforeReconciliation`
补充 → `testIC129F_ServiceExistenceQueryIsSingleBatchAndReturnsSubset`

## 占位值登记

无变更。出厂值集合未动，`S2CalibrationConfiguration.schemaVersion` 保持 **7**；
`factoryPlaceholder` 登记制不变。Localizable.xcstrings 未动（本卡无用户可见文案增删）。

## CI

- 主跑 **#248**（run id `33967595635`）：625 项 0 失败、退出码 0、
  iOS 26.2 / iPhone 16、IPA 1100833 字节
  SHA-256 `90270d1c2e5b52877f8d752cc38c40ba59fd1aed27381c263aa0d172602aa1fc`
- 修复预算未动用
- 合并后 `main` 自动运行（G605）见 v2 补记
