# IC-099 变更清单（阶段二：顶部信息区实装，v2）

> v1 在 R0 触发闸门 A、零代码变更；本清单覆盖 v1，记录 v2 的实际改动。

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交 | `3b7d50e46b78184b0f2b18d34b7e6ebb0a95930c`（IC-101 交付，CI #171、508/0） |
| 分支 | `feature/ic-099-top-bar-date-index-size`（未重切） |
| 分支 tip（代码部分，CI #173 被测提交） | `968998579306fc1a4be861f783a49a3211987114` |
| 报告提交 | 只含 `Reports/IC-099/`，命中 `paths-ignore`，**不触发 CI** |

四个提交，各自可单独 cherry-pick：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `c926214…` | `feat(s2): 顶部信息区文本纯函数、取数路线分派与会话级缓存（IC-099 阶段二 R1/R4）` |
| 2 | `714c87b…` | `feat(s2): 占用空间取数的 PhotoKit 分派实现（IC-099 阶段二 R4）` |
| 3 | `545d870…` | `feat(s2): 顶部中部信息区实装为两行并接线取数（IC-099 阶段二 R2/R3）` |
| 4 | `968998579306fc1a4be861f783a49a3211987114` | `test(s2): IC-099 阶段二 C1~C4 断言（IC-099 v2）` |

## 文件变化（`git diff --numstat 3b7d50e..HEAD`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2TopBarInfoPresentation.swift` | 149 | 0（新文件） |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | 158 | 0（只追加） |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 52 | 9 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 33 | 0 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 10 | 0 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 4 | 0 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 4 | 0 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 278 | 0 |

**测试文件零删除**；`S2View.swift` 的 9 行删除即被替换掉的序号单件 `Text`。

## 逐项改动

### R1 / R4（提交 1）——新文件 `S2TopBarInfoPresentation.swift`

| 类型 | 作用 |
|---|---|
| `S2AssetVolumeRoute` | 三条取数路线（`videoAssetURL` / `contentEditingInputURL` / `fullSizePhotoResource`） |
| `S2AssetVolumeRouter` | 类型 × 是否已编辑 → 路线，纯函数，无数值阈值 |
| `S2AssetVolumeProviding` | 取数接口，失败一律 `nil` |
| `S2AssetVolumeStore` | 会话级缓存 + 异步管线；已解析（含失败）与在途中都不重复发起；按 `assetID` 索引 |
| `S2TopBarInfoPresentation` | 日期主行与副行的文本拼装，纯函数 |

`project.pbxproj` 注册四处：`PBXBuildFile`（`200000000000000000000030`）、`PBXFileReference`（`100000000000000000000033`）、`S2` 组 `children`、`Sources` 构建阶段。id 取各段最大值 +1，写入前已断言唯一。

**String Catalog 追加 3 个 key**（全部被产品源码引用）：`s2.top.date_format.current_year` = `M月d日`、`s2.top.date_format.other_year` = `yyyy年M月d日`、`s2.top.position_with_volume` = `{current}/{total} · {volume}`（分隔为空格 + U+00B7 + 空格）。既有 `s2.top.position` **复用**为无大小分支，值未改。

### R4（提交 2）——`Services/AssetSizeScanner.swift` 追加 `AssetVolumeService`

按路线走三条实现之一，全部 `isNetworkAccessAllowed = false`；失败、`.fullSizePhoto` 缺失、iCloud 不可得一律 `nil`。回调经 `ContinuationResumer` 保证 `CheckedContinuation` 只 resume 一次。**不用 KVC 私有键**；**`AssetSizeScanner`（S3 用）一字未动**。

### R2 / R3（提交 3）——`S2View` 与接线

- 顶部中部由 `Text(序号)` 单件替换为 `topInfoArea`（主行 + 副行）。**返回按钮、确认页入口、`S2OverlayLayout.topElementFrames` 一字未动。**
- 取数由 `.task(id: machine.currentAssetID)` 触发；副行取值走 `assetVolumeStore.byteCount(for: machine.currentAssetID)`。
- `S2View.init` 新增两个默认参数 `assetCreationDate` / `assetVolumeProvider`，插在 `assetPixelSize` 之后、`assetSizeProber` 之前；**九处 `S2View(` 调用点的标签顺序已用脚本逐一核对通过**。
- `CleanupCoordinator` 新增 `s2AssetCreationDate(for:)` 与 `makeS2AssetVolumeProvider()`（构造时快照 `loadedAssets`）；`PhotoCleanupMVEApp` 接线。

### 断言（提交 4）——新增 6 项

| 测试函数 | 覆盖 |
|---|---|
| `testIC099v2C1VolumeRouteDispatchCoversAllFourRows` | C1 分派四行全覆盖 + 枚举恰三条 |
| `testIC099v2C1FailureDegradesToPositionOnly` | C1 失败与负值降级为只显序号 |
| `testIC099v2C2StoreFetchesEachAssetAtMostOnce` | C2 缓存命中不重复取数（含失败结论） |
| `testIC099v2C3SubtitleReflectsPendingFailureAndAssetSwitch` | C3 未就绪 / 就绪 / 切资产三态 |
| `testIC099v2C4DateTextCoversYearBoundaryAndNil` | C4 当年 / 元旦 / 跨年 / 老照片 / nil |
| `testIC099v2C4SubtitleTextUsesSlashAndMiddleDot` | C4 副行原文、分隔符、三档口径六用例 |

## 未改动清单

| 项 | 状态 |
|---|---|
| `AssetSizeScanner`（S3 多资源求和） | **一字未动**（闸门 A） |
| `S2TemporaryPhotoImageStrategy` / 产品图片请求策略与节流 | **一字未动**（闸门 A） |
| `PhotoCleanupMVE/Core/S3StateMachine.swift`、`S3StateMachineTests.swift`、`VolumeFormattingTests.swift` | **相对 `main` 零 diff** |
| 确认页入口、返回按钮、标记、横栏、操作条、手势 | 未动 |
| 底部布局（IC-100 分支的改动） | 未动——本分支不含 IC-100 |
| `S2OverlayLayout` 顶部三帧几何模型 | 未动 |
| `Reports/IC-068/export-format.md` | 未动 |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md`、`Scripts/`、`ci.yml` | 未动 |
| `feature/ic-089/091/092` 冻结三链 | 未触碰 |

未新增 XCUITest；未合并 `main`；未 rebase / amend / force push / 改写历史 / 删分支。

## 占位值登记

**本卡未新增标定参数、未修改出厂值。** `S2CalibrationConfiguration.schemaVersion` 仍为 **4**（闸门 C 未触发）。

视觉稿前的**占位样式**（系统字体 + 语义色，不进标定参数、不进规格，④ 可改）：

| 元素 | 样式 |
|---|---|
| 主行（拍摄日期） | `.font(.caption)` + `.foregroundStyle(.primary)` + `.lineLimit(1)` |
| 副行（序号 · 占用空间） | `.font(.caption2)` + `.foregroundStyle(.secondary)` + `.lineLimit(1)` |
| 两行间距 | `VStack(spacing: 0)` |

未定项 7（顶部各元素字体、字号与精确位置属视觉稿范围）**未触碰**。

三个 String Catalog 新键中的两个日期格式串属**规格锁定的显示格式**（v16 决策 35 原文），不是可自由改动的文案。

## 产品行为净变化（相对 `3b7d50e`）

1. **顶部中部信息区由「序号」单件变为两行**：主行当前资产拍摄日期（当年 `M月d日` / 非当年 `yyyy年M月d日`；无拍摄日期时整行不显示），副行 `{序号}/{总数} · {占用空间}`。
2. **副行新增占用空间**：按资产类型分派取当前版本字节数，口径 KB / 一位小数 MB / 一位小数 GB（IC-099b 已交付的 `S2AssetVolumeFormatter`）。未就绪或取数失败时副行退化为 `{序号}/{总数}`，不显示占位符。
3. **新增一次异步取数**：每个资产在成为当前资产时至多取一次，结果进会话级内存缓存，随 S2 退出释放。全部禁网络，不改图片请求策略与节流。

返回按钮、确认页入口、顶部三件的几何、主图视口与几何、底部布局、手势、S3 行为**零变化**。
