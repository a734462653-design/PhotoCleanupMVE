# IC-099b 变更清单（字节数探针 + S2 单张字节格式）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承提交 | `741a2c13f827074ee9e44a233244fe0bd8a4d655`（IC-099 R0 报告提交，基于 `main` = `ef9d46a`） |
| 分支 | `feature/ic-099-top-bar-date-index-size`（未重切） |
| 分支 tip（代码部分，CI #170 被测提交） | `8fa54d199cccd4d39abb2e3da42f7f7462440c50` |
| 报告提交 | 只含 `Reports/IC-099b/`，命中 `paths-ignore`，**不触发 CI** |

四个提交，各自可单独 cherry-pick：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `1b843ce…` | `feat(s2): S2 单张资产占用空间格式纯函数与八项断言（IC-099b R1）` |
| 2 | `9de6fda…` | `test(s2): IC-099b P1 断言改置 S2 夹具文件（G217 字面满足）` |
| 3 | `809891a…` | `feat(diag): S2 调试面板字节数探针（两途径取数，仅诊断零产品行为）（IC-099b R2）` |
| 4 | `8fa54d199cccd4d39abb2e3da42f7f7462440c50` | `fix(build): 修正 CI #169 的产品源码编译错误（IC-099b）` |

提交 2 的存在原因：R1 的八项断言最初落在 `VolumeFormattingTests.swift`（S3 的卷格式测试文件），会让该文件 +72 行；G217 要求「S3 相关测试 0 行改动」，故单独一个提交把断言原样移到 `S2CalibrationHarnessTests.swift`，断言内容一字未改。

提交 4 的存在原因见 `self-check.md`「CI #169 失败与修正」。

## 文件变化（`git diff --numstat 741a2c1..HEAD`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 340 | 0 |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | 262 | 0 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 46 | 0 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 33 | 0 |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 6 | 0 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 2 | 0 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 363 | 0 |

**全部为新增，零删除。** 既有代码与既有断言一行未改、未删。

## 逐项改动

### R1（提交 1、2）

**新增 `S2AssetVolumeFormatter`**（`S2NativePhotoPager.swift` 诊断区）：S2 单张资产占用空间的三档口径——`< 1_000_000 B` 整数 KB、`< 1_000_000_000 B` 一位小数 MB、其余一位小数 GB，全部向下截断。一位小数走整数除法，避免浮点在 `999_949_999` 这类临界值上进位。

**放置说明**：该类型本卡只被探针消费，与探针同置于诊断区。硬编码扫描器的「规格锁定格式」豁免只覆盖 `Core/S3StateMachine.swift` 且只认 ` MB` / ` GB` 结尾（`Scripts/scan-hardcoded-user-visible-strings.ps1:155`），S2 口径多了 ` KB` 档且不在那个文件里，放到常规位置会让扫描器失败；`Scripts/` 属本卡范围外。**阶段二接到顶部信息区前须由技术负责人定豁免或入目录，并把类型移到与 `DecimalVolumeFormatter` 对称的位置。** 代码里已就地写了同样的说明。

**新增断言 3 项**（`S2CalibrationHarnessTests.swift`）：卡内八用例、档位边界不进位、S2 与 S3 两套口径互不影响。

### R2（提交 3、4）

**S2 侧类型**（`S2NativePhotoPager.swift` 诊断区）：

| 类型 | 作用 |
|---|---|
| `S2AssetSizeProbeMediaKind` | 照片 / LivePhoto / 视频三类 |
| `S2AssetSizeProbeFailure` | 七个失败原因，各有独立文案 |
| `S2AssetSizeProbeMeasurement` | 一个资产上两条途径的结果（含 `byteDelta` 计算属性） |
| `S2AssetSizeProbing` | 取数接口（PhotoKit 实现在 Services 层） |
| `S2AssetSizeProbeText` | 头部 / 行 / 汇总 / 进度的全部文本拼装，纯函数 |
| `S2AssetSizeProbeCoordinator` | 运行协调器，串行取数、刷进度、生成报告 |

**PhotoKit 实现 `AssetSizeProbeService`**（追加进 `Services/AssetSizeScanner.swift`，既有 `AssetSizeScanner` 一字未动）：

- URL 途径：照片 `requestContentEditingInput` → `fullSizeImageURL` → `URLResourceValues.fileSize`；视频 `requestAVAsset` → `AVURLAsset.url` → 同上。均 `isNetworkAccessAllowed = false`。
- 数据途径：主资源 `requestData` 流式累加，主资源优先取**原始**类型（`.photo` / `.video`），使已编辑资产上两途径差值成为语义差实测值。
- `notLocal` 由 `PHContentEditingInputResultIsInCloudKey` / `PHImageResultIsInCloudKey` 判定。
- 回调经 `ContinuationResumer` 保证 `CheckedContinuation` 只 resume 一次。
- **不使用任何 KVC 私有键。**

**面板**（`S2View.swift`）：参数面板追加 `assetSizeProbeSection`（独立 `@ViewBuilder` 属性）——标题、运行按钮、进度行、分享入口与可全选复制的报告文本。`S2View.init` 增一个 `assetSizeProber: S2AssetSizeProbing? = nil`（位置在 `assetPixelSize` 之后），未接线时按钮禁用。

**接线**：`CleanupCoordinator.makeS2AssetSizeProber()` 快照 `loadedAssets` 造实现；`PhotoCleanupMVEApp` 在自身主线程上下文里调用后传入。

**新增断言 8 项**：P2 五项（行九列、失败与 nil 列、失败原因枚举齐全、汇总统计、头部与上限注明）、P3 三项（未触发零副作用、显式运行逐资产恰一次、上限 60 截断并注明）。

### String Catalog（提交 3）

新增 3 个 key，全部被产品源码引用（扫描器要求 key ↔ 引用双向齐全）：

| key | zh-Hans |
|---|---|
| `s2.calibration.asset_size_probe.title` | 字节数探针（IC-099b） |
| `s2.calibration.asset_size_probe.start` | 运行字节数探针 |
| `s2.calibration.asset_size_probe.share` | 分享字节数探针报告 |

## 未改动清单

| 项 | 状态 |
|---|---|
| 顶部信息区（`topBar`） | **未动**（实装归 IC-099 阶段二） |
| `PhotoCleanupMVE/Core/S3StateMachine.swift`（含 `DecimalVolumeFormatter`） | **零 diff** |
| `PhotoCleanupMVETests/S3StateMachineTests.swift` | **零 diff** |
| `PhotoCleanupMVETests/VolumeFormattingTests.swift` | **零 diff**（相对 `main`） |
| `AssetSizeScanner`（S3 用的多资源求和扫描器） | 既有类型一字未动，仅在同文件追加新类型 |
| `S2TemporaryPhotoImageStrategy` / 产品图片请求路径 | **未动**（闸门 A 未触发） |
| 手势、横栏、操作条、标记 | 未动 |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md`、`Scripts/`、`ci.yml` | 未动 |
| `Reports/IC-068/export-format.md` | 未动（卡内即要求不动） |
| `feature/ic-089/091/092` 冻结三链 | 未触碰 |

未新增 XCUITest；未合并 `main`；未 rebase / amend / force push / 改写历史 / 删分支。

## 占位值登记

**本卡未新增、未修改、未删除任何 `factoryPlaceholder` 占位值；未新增标定参数。**

`S2CalibrationConfiguration.schemaVersion` **仍为 4**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`），一字未动——闸门 C 未触发。

新增的常量只有 `S2AssetSizeProbeCoordinator.assetLimit = 60`（卡内明写的探针样本上限）与 `S2AssetVolumeFormatter` 的三个进制常量（1e3 / 1e6 / 1e9，④ 定案 2 给定），均非标定参数、非规格量、不入登记表。

## 产品行为净变化

**零。** 探针只在调试面板按钮触发时运行；顶部信息区、图片请求、手势、横栏与所有产品路径的行为与几何结果与 `741a2c1` 完全一致。

新增的用户可见文本三条全部在调试面板内（长按主图才能进入），不出现在正常使用路径上。
