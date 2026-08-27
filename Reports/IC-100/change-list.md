# IC-100 变更清单（闸门 B 触发，停在实装前）

## 交付物

| 文件 | 动作 |
|---|---|
| `Reports/IC-100/self-check.md` | 新建（冲突的算术证明 + 两案裁定请求 + 已探明的实装方案） |
| `Reports/IC-100/change-list.md` | 新建（本文件） |

**产品代码零变更。** 互换未实装，两个占位常量未落地，断言 B1～B5 未新增。

## 分支与提交

| 项 | 值 |
|---|---|
| 继承提交（`main`） | `ef9d46aaaf6c6f0e2bae29712e751d39994f59ff` |
| 分支 | `feature/ic-100-bottom-layout-swap`（从 `ef9d46a` 创建，卡内显式授权） |
| 产品代码提交 | **无** |
| 报告提交 | 只含 `Reports/IC-100/`，命中 `ci.yml` 的 `paths-ignore`，**不触发 CI** |
| CI 运行 | **无**（尝试次数消耗 0 / 3） |

## 未改动清单

本卡**没有修改任何已有文件**，只新增了报告目录。以下全部逐字节保持 `ef9d46a` 的状态：

| 项 | 状态 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift`（含 `S2OverlayLayout.snapshot`） | 未动 |
| `PhotoCleanupMVE/Features/S2/S2View.swift`（含 `interfaceOverlay`、`actionBar`、toast 落位） | 未动 |
| `S2BottomStripView` 与横栏全部几何 / 运动参数 | 未动 |
| 顶部信息区、主图待删标记、手势、图片请求 | 未动 |
| 全部测试文件 | 未动（B1～B5 一条未加） |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md`、`Scripts/`、`ci.yml` | 未动 |
| `feature/ic-089/091/092` 冻结三链 | 未触碰 |

未合并 `main`；未 rebase / amend / force push / 改写历史 / 删分支。

## 只读取证（未产生任何写操作）

| 来源 | 用途 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift:880-978` | `S2OverlayLayout` 常量与 `snapshot` 的现行几何模型（横栏贴安全区底、操作条在其上方） |
| `PhotoCleanupMVE/Features/S2/S2View.swift:696-739` | `interfaceOverlay` 的现行 `VStack` 子视图顺序 |
| `PhotoCleanupMVE/Features/S2/S2View.swift:544-550` | 反馈 toast 的现行落位（`safeAreaInsets.bottom + minimumSpacing`） |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift:701-710` | 门禁 L2 的判据与上限 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift:770-793` | 门禁 L4 的 44×44 判据与帧集合 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift:7468-7474, 7929-7939` | 测试视口 393×852、安全区底 34、横栏高 72 |

## 占位值登记

**本卡未落地任何占位值。** 卡内两个登记制占位常量原样记录，待裁定后随实装登记：

| 常量 | 卡内值 | 状态 |
|---|---|---|
| 操作条按钮带中心 → 屏幕底 | 52.7 pt（158 px @3x） | **与门禁 L2 冲突 3.3 pt，待技术负责人在方案 A / B 之间裁定** |
| 横栏底缘 → 操作条按钮带顶缘 | 30.7 pt（92 px @3x） | 无冲突，可原样落地 |

两者按卡内要求不进 `S2CalibrationConfiguration`、不上面板。`schemaVersion` 仍为 **4**，未加字段、未改出厂值（闸门 C 未触发）。

## 产品行为净变化

**零。** 未改动任何产品代码，用户可见行为与几何结果与 `ef9d46a` 完全一致。

## 停工点与待裁定事项

停在**实装前**（互换的两处改法已探明，未落笔）。恢复开工需要技术负责人在两案之间裁定一项：

- **方案 A**：保 L2，把「操作条按钮带中心距屏幕底」由 52.7 改为 `safeAreaInsets.bottom + minimumTouchTarget / 2`（常规机型 = **56.0 pt**）。零门禁改动，本卡可直接续做，与系统观感差 3.3 pt（交 H44 判方向）。
- **方案 B**：保 52.7，把 L2 的判据由「44 pt 触控带」改为「可见带」，并显式允许触控带越过安全区。与系统逐像素对齐，但要改既有门禁判据，须先发一张门禁改造卡。

另有一项实装前需一并明确：**反馈 toast 的新落位**——现行落位（距视口底 42 pt）在互换后会与操作条按钮带纵向重叠，卡内未提及，执行端不自行决定。
