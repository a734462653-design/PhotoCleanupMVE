# IC-099 变更清单（闸门 A 触发，停在 R0）

## 交付物

| 文件 | 动作 |
|---|---|
| `Reports/IC-099/self-check.md` | 新建（R0 探明结论 + 闸门 A 判定） |
| `Reports/IC-099/change-list.md` | 新建（本文件） |

**产品代码零变更。** R1、R2、R3 全部未开工。

## 分支与提交

| 项 | 值 |
|---|---|
| 继承提交（`main`） | `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff` |
| 分支 | `feature/ic-099-top-bar-date-index-size`（从 `ef9d46a` 创建） |
| 产品代码提交 | **无** |
| 报告提交 | 只含 `Reports/IC-099/`，命中 `ci.yml` 的 `paths-ignore`，**不触发 CI** |
| CI 运行 | **无**（尝试次数消耗 0 / 3） |

## 未改动清单

本卡**没有修改任何文件**，只新增了报告目录。以下全部逐字节保持 `ef9d46a` 的状态：

| 项 | 状态 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift`（顶部信息区） | 未动 |
| `PhotoCleanupMVE/Core/S3StateMachine.swift`（含 `DecimalVolumeFormatter`） | 未动 |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | 未动 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 未动 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 未动（未新增任何条目） |
| `Reports/IC-068/export-format.md` | 未动（卡内即要求不动） |
| 测试文件 | 未动（未新增任何断言） |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md`、`Scripts/`、`ci.yml` | 未动 |
| `feature/ic-089/091/092` 冻结三链 | 未触碰 |

## 只读取证（未产生任何写操作）

| 来源 | 用途 |
|---|---|
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | 确认本仓库现行字节数获取做法（`requestData` 流式累加、全部资源求和） |
| `PhotoCleanupMVE/Core/S3StateMachine.swift:24` | 取 `DecimalVolumeFormatter` 原文口径 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 确认 `loadedAssets`（`PHAsset` 映射）可用、扫描只在 S3 触发 |
| `PhotoCleanupMVE/Features/S2/S2View.swift:788` | 取现顶部信息区结构 |
| `PhotoCleanupMVE/Localizable.xcstrings:1258` | 取 `s2.top.position` 现值 |
| `<top>/SPEC-S2-20260827_v16.md:102` | 取决策 35 原文 |
| `<top>/PhotoKitConstraintsProbe/probe-log.txt` | **P8 真机实测 40 行**（照片 20 + 视频 20） |
| `<top>/PhotoKitConstraintsProbe/PhotoKitConstraintsProbe/ProbeModel.swift:428,1752` | 取主资源选取规则与 `publicSizeAvailable` 字面量 |

探针仓库 `<top>/PhotoKitConstraintsProbe` **只读，未改动任何文件**（CLAUDE.md 第零节要求）。

## 占位值登记

**不适用。** 本卡未新增、未修改、未删除任何 `factoryPlaceholder` 占位值；未新增标定参数；`S2CalibrationConfiguration.schemaVersion` 仍为 **4**，一字未动（闸门 D 未触发）。

卡内取定第 3 条要求登记「视觉稿前占位样式」——**本卡未实装任何视图，无占位样式可登记**。

## 产品行为净变化

**零。** 未改动任何产品代码，用户可见行为与几何结果与 `ef9d46a` 完全一致。

## 停工点与待裁定事项

停在 **R0**。恢复开工需要技术负责人裁定三件事（详见 `self-check.md`）：

1. **字节数获取途径**三选一：A 途径 2（公开、有真机实测、要读完整资源）／B 先发探针卡实测途径 3／C 接受途径 1（KVC 未公开属性）。
2. **规格第 102 行示例 `2.4 MB` 与 S3 现行口径矛盾**——示例是笔误，还是 MB 档要加一位小数。
3. **单张 < 1 MB 显示 `0 MB`** 是否接受（P8 实测最小样本 323,846 B 即落此档）。

另有三项需一并明确：取定第 2 条「原图资源 vs 当前版本全尺寸资源」在已编辑资产上的优先级；S2 单主资源与 S3 多资源求和两套口径是否允许并存；`s2.top.position` 是复用改值还是新增 key。
