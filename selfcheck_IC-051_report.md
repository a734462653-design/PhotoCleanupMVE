# IC-20260815-051 自验报告

## 1. 结论

IC-20260815-051 已完成。S1 相册维度现由 PhotoKit 的
`PHAssetCollectionType.album + PHAssetCollectionSubtype.albumRegular` 提供数据，
智能相册、共享相册与隐藏相册被排除；相册列表保持
`fetchAssetCollections` 默认顺序。未分类维度取全库资产减去全部用户自建普通相册
资产并集的补集。四个维度均不输出 `r.total = 0` 的范围，并均可形成进入 S2 的
有效交接。

CI 终态为 `completed / success`。全量 XCTest 共 280 项，0 失败、
0 unexpected；达到既有 273 项加本卡新增 7 项的门槛。Release 未签名 IPA 已生成
并上传为可下载 artifact。

## 2. T1～T7 专项 XCTest

| 项目 | 测试名 | 状态 | 独立断言覆盖 |
|---|---|---|---|
| T1 | `testIC051_T1AlbumRangesContainOnlyUserCreatedRegularAlbums` | 通过 | 只保留用户自建普通相册；智能、共享、隐藏候选均排除；抓取参数固定为 `.album/.albumRegular` |
| T2 | `testIC051_T2AlbumRangeOrderMatchesFetchOrderAndIgnoresSortFlip` | 通过 | `R(T)` 等于注入抓取顺序，翻转 `O` 后范围顺序不变 |
| T3 | `testIC051_T3AlbumAssetsUseCurrentSortOrderAndReverseExactly` | 通过 | 两个 `O` 下 `A` 元素集合相同且顺序互逆 |
| T4 | `testIC051_T4UnclassifiedIsExactComplementOfUserAlbumUnion` | 通过 | 未分类恰含一个范围，资产集合为全库减用户相册并集 |
| T5 | `testIC051_T5ZeroTotalAlbumMonthAndYearRangesAreExcluded` | 通过 | 空相册、空月份与空年份均不进入 `R(T)` |
| T6 | `testIC051_T6CrossRangeDeletionSetsDeduplicateAndKeepFirstOwner` | 通过 | 两个 `D_范围` 独立、`D_全部` 去重、`F` 不改写首次范围键 |
| T7 | `testIC051_T7AlbumHandoffSatisfiesContractAndAllDimensionsAreEnterable` | 通过 | 相册交接满足 `D ⊆ A`、`c ∈ A` 并实际进入 S2；同时核对四维度均可形成非空交接 |

CI 日志逐项记录以上七个测试均为 `passed`。

## 3. 全量测试与自验

- 新增 XCTest：7 项。
- 测试总数：280。
- CI 运行时结果：`Executed 280 tests, with 0 failures (0 unexpected)`。
- 总套件结果：`Test Suite 'All tests' passed`。
- 专项自验脚本：`Scripts/verify-IC-20260815-051.ps1`。
- 最终专项自验：通过，共执行 96 项检查，0 项失败。
- 通用结构自验：通过。
- 用户可见硬编码扫描：通过，残留 0。
- `git diff --check`：通过。

## 4. CI 与 IPA artifact

- CI run：[iOS 构建与自验 #33](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31874101958)
- Job：[构建、XCTest 与未签名产物](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31874101958/job/94987099502)
- CI 对应提交：`3914f0acec7d42108586d3f3a273d3f79b8fc48b`
- 终态：`completed / success`
- 结构自验、硬编码扫描、XCTest、Release 构建、IPA 上传步骤：全部 `success`
- Artifact：[PhotoCleanupMVE-unsigned-3914f0acec7d](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31874101958/artifacts/9244300741)
- Artifact 状态：存在、未过期；到期时间 `2026-11-13T08:17:10Z`
- Artifact 归档大小：433,517 字节
- 内含 IPA：`PhotoCleanupMVE-unsigned.ipa`，433,347 字节
- IPA SHA-256：`ea3825dcb51aed113bbac14c5580971e72d5cecea824d4fef631c7024d3698e7`
- IPA 性质：Release 未签名包，可下载后交由 Sideloadly 完成个人签名与侧载。

## 5. 变更文件清单

以下行数均相对任务基线 `3ef578074e44dfc9e2fb0820b41e3730a0bb2071`：

| 路径 | 新增 | 删除 | 说明 |
|---|---:|---:|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 4 | 0 | 将新增 XCTest 文件加入测试目标 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 1 | 5 | 移除空相册占位，接入服务数据源 |
| `PhotoCleanupMVE/Services/PhotoLibraryService.swift` | 176 | 53 | PhotoKit 相册抓取、过滤、未分类补集及可注入测试边界 |
| `PhotoCleanupMVETests/AlbumScopeWiringTests.swift` | 305 | 0 | T1～T7 七项独立 XCTest |
| `Scripts/verify-IC-20260815-051.ps1` | 205 | 0 | 本卡可复现自验脚本 |
| `selfcheck_IC-051_report.md` | 82 | 0 | 本报告 |

清单不含任何 `SPEC-*.md` 或 `Decision_log.md`，也不含 S1 视觉呈现层及 S2、S3、
S4、S5 行为逻辑文件。`debugAssetLimit` 保持原值 300。

## 6. 执行边界声明

- 任务基线：`main` 与 `origin/main` 均为 `3ef578074e44dfc9e2fb0820b41e3730a0bb2071`。
- 本卡 commit 数：2（1 个实现与测试提交，1 个 CI 结果报告提交）。
- 实现提交：`3914f0acec7d42108586d3f3a273d3f79b8fc48b`。
- push 分支：`feature/ic-051-album-scope`。
- 成功 push 均只指向上述独立分支。
- 未合并主干；本卡未在 `main` 创建提交。
- 未执行 force push。
- 未操作账号，未创建或合并 Pull Request。
- 未修改规格、决策日志、视觉呈现、S2～S5 行为逻辑或任何未定参数。
