# IC-136 变更清单

- 继承提交：`main` = `fc2bc77c7eb80671ff630c7567e7b445b4df2988`
- 分支：`feature/ic-136-h60-followups`，代码 tip `ea96a74b3ef120b3490b464a96a293970e885845`
- **合并提交：`ad41504` / `ad4150488ed38a617192ffa237dc986470f77a75`**
  - parent1 `fc2bc77c7eb80671ff630c7567e7b445b4df2988`（原 `main`）
  - parent2 `ea96a74b3ef120b3490b464a96a293970e885845`（分支 tip）
  - 标题 `merge: IC-136 H60 后三处修正（#265 绿 676 项 0 失败，iOS 26.2 / iPhone 16）`
  - `Merge made by the 'ort' strategy.`，**零冲突**；合并树对象
    `da2f8f16556e69a0554c4a8daa5a5d09c609633c` 与分支 tip 树对象相同
- 推送报文：`fc2bc77..ad41504  main -> main`（两点记法，非强推），退出码 0
- 报告提交：本卡 docs 提交（`Reports/IC-136/` 两份），随合并留在 `main`，不跨卡回填

## 提交链（5 个，未 rebase／未 amend）

| 提交 | 子项 | 内容 | 可单独 cherry-pick |
|---|---|---|---|
| `3e091c2` | A | 撤销 S3 体积明细展开与扫描侧通道 | 是 |
| `6f08eee` | B | 合计体积 < 1 MB 改一位小数四舍五入 | 是 |
| `f5c5e6e` | C | S2 中央状态指示改双色固定渲染 | 是 |
| `ea96a74` | A + C | 推 CI 前的两处类型收口（元组 key path、`CGFloat`/`Double`） | **否**——同时依赖 A 与 C，见 self-check「发现但未处理」第 8 条 |
| `ad41504` | — | **本卡合并提交**（`--no-ff`） | — |

## 文件级变更（`fc2bc77..ad41504`，10 文件 +372 −566）

| 文件 | +/− | 子项 |
|---|---|---|
| `PhotoCleanupMVE/Features/S3/S3View.swift` | +33 −182 | A |
| `PhotoCleanupMVE/Services/AssetSizeScanner.swift` | +4 −55 | A |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | +4 −23 | A |
| `PhotoCleanupMVE/Localizable.xcstrings` | +0 −44 | A |
| `PhotoCleanupMVE/Core/S3StateMachine.swift` | +16 −0 | B |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | +37 −76 | C |
| `PhotoCleanupMVETests/IC134S3VisualTests.swift` | +87 −118 | A |
| `PhotoCleanupMVETests/VolumeFormattingTests.swift` | +71 −1 | B |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | +2 −1 | B |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | +118 −66 | C |

**`PhotoCleanupMVE.xcodeproj/project.pbxproj` 未改**：本卡未新增测试文件，三子项的
新断言分别落进各自主题已登记的测试文件，故不触发 pbxproj 登记（也就不存在
IC-134 那种对象 id 撞号风险）。

## 删除成员清单

### `Services/AssetSizeScanner.swift`（A）

删除后整文件与 `39bade7`（IC-134 之前）**逐字节相同**。

| 成员 | 类别 |
|---|---|
| `enum AssetResourceKind`（含 `init(_:PHAssetResourceType)`） | 类型 |
| `struct AssetSizeBreakdownItem` | 类型 |
| `struct AssetScanOutcome` | 类型 |
| `func scanWithBreakdown(_:)` | 方法 |

`func scan(_:)` 改回直接实现，结论口径与总数算法一字未动。
`AssetResourceKind` 卡内未点名，删拆分项后全仓零消费者，按「不留死代码」一并删除。

### `App/CleanupCoordinator.swift`（A）

| 成员 | 处置 |
|---|---|
| `private var scanBreakdownsByAssetID` | 删除 |
| `func scanBreakdown(for:)` | 删除 |
| `func scanBreakdownItemCount(for:)` | 删除 |
| `private func beginPendingScans()` | 改动——回到 `await sizeScanner.scan(asset)` 单路径 |

删除后该文件与 `39bade7` 的差异只剩 IC-134 F（L3 撤销）的四处。

### `Features/S3/S3View.swift`（A）

| 成员 | 处置 |
|---|---|
| `S3CellBadgeMetrics.detailChevronPointSize` | 删除 |
| `S3CellBadgeModel.showsDetailChevron` | 删除 |
| `S3CellBadgeModel.isDetailExpanded` | 删除 |
| `enum S3VolumeDetailText`（`kindLabel(_:)`、`value(_:)`） | 删除 |
| `struct S3DetailExpansion`（`isExpandable`／`isExpanded`／`toggle`／`expandedAssetID`） | 删除 |
| `S3GridRows.rowIndex(ofAssetID:in:)` | 删除（撤销后零消费者） |
| `S3View.detailExpansion` 状态 | 删除 |
| `S3View.volumeDetailRow(_:)` | 删除 |
| `S3VolumeDetailMetrics` 的 `cornerRadius`／`verticalPadding`／`horizontalPadding`／`fontSize`／`itemSpacing` | 删除（5 个成员） |
| `S3CellBadgeModel.make(asset:conclusion:)` | 改动——去掉两个参数 |
| `grid(_:machine:cellWidth:)` | 改动——去掉展开行的行号计算与插入点 |
| `cell(_:machine:cellWidth:)` | 改动——去掉侧通道读取 |
| `volumeBadge(_:)` | 改动——**不再是 `Button`**，不接点击、不占命中区 |
| `volumeBadgeLabel(_:)` | 改动——去掉 chevron 分支 |

保留：`S3GridRows.rows(_:)` 与手工分行（撤销的是明细行，不是分行；改 `LazyVGrid`
会动版式）、`S3VolumeDetailMetrics.pairSpacing`（另有消费者：操作条扫描行的
「转圈 ↔ 文案」间距）。

### `Features/S2/S2View.swift`（C，仅 `S2CenterIndicatorView`）

| 成员 | 处置 |
|---|---|
| `@Environment(\.colorScheme) private var colorScheme` | 删除 |
| `static func resolvedForeground(for:)` | 删除 |
| `private var glassContentForeground` | 删除 |
| `static func resolvedSeparator(for:)` | 删除 |
| `private var glassContentSeparator` | 删除 |
| `static let backgroundColor = S2PendingDeletionMark.circleColor` | 新增 |
| `static let foregroundColor = S2PendingDeletionMark.symbolColor` | 新增 |
| `static let separatorColor = Color.white.opacity(0.3)` | 新增 |
| `private func glassCircle(systemName:)` | 改名为 `solidCircle(systemName:)`，底改实心填充 |
| `var body` | 改动——撤回钮前景改 `Self.foregroundColor` |
| `private var content` | 改动——三形态底改 `Circle()`／`Capsule().fill(Self.backgroundColor)`，前景改 `Self.foregroundColor`，分隔线改 `Self.separatorColor` |

未动：`showsUndoControl(for:)`、`separator(color:)`（落笔机制与几何）、
`containerHeight`（46）、`horizontalPadding`（12）、`allowsHitTesting(false)` 与撤回钮
overlay 结构、`S2CenterIndicatorResolver` 全部成员、`S2PendingDeletionMark` 本身、
chrome 与 chrome 前景、`s2ChromeGlassBackground` 本体（其余 3 个调用点照旧）。

### `Core/S3StateMachine.swift`（B，仅 `DecimalVolumeFormatter`）

| 成员 | 处置 |
|---|---|
| `private static let bytesPerTenthOfMegabyte: Int64 = 100_000` | 新增 |
| `string(forByteCount:)` | 改动——新增 `< 1 MB` 分支，整数四舍五入 + `max(1, …)` 抬底 |

## xcstrings 删键清单

目录条目 **210 → 206**，与产品源码引用一致（`selfcheck.ps1` 实测）。

| key | 原值（简）|
|---|---|
| `s3.detail.kind.photo` | 照片 |
| `s3.detail.kind.video` | 视频 |
| `s3.detail.kind.live_video` | 实况视频 |
| `s3.detail.kind.other` | 其他 |

B／C 两子项**无文案变更**。

## 测试增删改

### 删除（3 条，均属 IC-134 C）

- `testIC134C_ResourceKindMappingAndBreakdownSumInvariant`
- `testIC134C_DetailExpansionKeepsAtMostOneRow`
- `testIC134C_DetailTextComesFromCatalogAndFormatter`

三条在 #265 日志中零出现（逐个 grep 各 0 次）。

### 新增（5 条）

| 函数 | 文件 | 断言 |
|---|---|---|
| `testIC136A_CellBadgeModelHasNoChevronOrExpansionFields` | `IC134S3VisualTests.swift` | 1 |
| `testIC136A_ProductSourceNoLongerReferencesRemovedSymbols` | `IC134S3VisualTests.swift` | 2 |
| `testIC136A_DetailKindKeysRemovedFromCatalogAndSource` | `IC134S3VisualTests.swift` | 4 |
| `testIC136B_ByteCountTableFollowsRoundedSubMegabyteTier` | `VolumeFormattingTests.swift` | 5 |
| `testIC136B_SingleFormatterServesS3CellBarAndS5` | `VolumeFormattingTests.swift` | 6 |

### 改写（4 条 IC-123，原地不增减）

- `testIC123AIndicatorForegroundIsResolvedPerColorScheme`
- `testIC123AIndicatorGlassContentFollowsInPlaceAppearanceSwitch`
- `testIC123AppendixIndicatorSeparatorIsResolvedPerColorScheme`
- `testIC123AppendixIndicatorSeparatorLineDrawsWithGivenColor`

### 改期望值（2 处）

| 文件 | 用例 | 旧 → 新 |
|---|---|---|
| `VolumeFormattingTests.swift` | `testZeroBytesDisplaysAsZeroDecimalMegabytes` | `0 MB` → `0.1 MB` |
| `S2CalibrationHarnessTests.swift` | `testIC099bP1SingleAssetTierDoesNotChangeAggregateTier` | `0 MB` → `0.3 MB` |

### 其他必要改动（1 处，卡未枚举）

`testIC134D_EveryS3KeyResolvesInCatalog` 的 key 清单去掉被删的 4 个
`s3.detail.kind.*`——不删该用例必然失败。

### 项数对账

| suite | 基线 | 本卡后 | 差 |
|---|---|---|---|
| `IC134S3VisualTests` | 14 | 14 | 0（−3 +3） |
| `VolumeFormattingTests` | 6 | 8 | +2 |
| `S2ActionBarWiringTests` | 65 | 65 | 0（原地改写） |
| `S2CalibrationHarnessTests` | 224 | 224 | 0（只改期望值） |
| **合计** | **674** | **676** | **+2** |

与 CI 读数逐字相符。

## 占位值登记

**无变更。** 出厂值集合未动，`S2CalibrationConfiguration.schemaVersion` 保持 **7**
（`Features/S2/S2Calibration.swift:118`，该文件不在 diff 文件集合内）；
`factoryPlaceholder` 登记制不变。

C 新增的三个固定色常量走 `S2CenterIndicatorView` 自身的登记制容器，且
`backgroundColor`／`foregroundColor` 是对 `S2PendingDeletionMark` 的**同源引用**
（不是另写一份相等字面量），`separatorColor` 为④卡取定的白 30%；三者均不进标定
配置、不上标定面板，不构成出厂值集合变更。

`S2CenterIndicatorResolver` 的 `transitionSeconds`（0.2）、`hiddenScale`（0.9）、
`removedNoticeSeconds`（1.2）、`albumIndicatorDelaySeconds`（0.42）**均不在 diff 中**。
（卡内断言 9 点名的 `centerIndicatorTransitionMs` 全仓不存在，见 self-check
「卡内前提与实测的出入」第 2 条。）

## 分支与冻结链状态（合并前后两次实测，本地＝远端）

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `ad41504` | 本卡推进（合并提交） |
| `feature/ic-136-h60-followups` | `ea96a74` | 保留在原 tip，未删除 |
| `feature/ic-134-s345-visual` | `54ac69e` | 未动 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |
| `feature/ic-122-ios26-simulator` | `e7c02ab` | 未动 |

## CI

- **G763：子项侧 #265**（run id `34150622370`，attempt 1）——**绿**
  - 被测提交 `ea96a74b3ef120b3490b464a96a293970e885845`，事件 `push`
  - **Executed 676 tests, with 0 failures (0 unexpected) in 50.455 (91.878) seconds**；
    `** TEST SUCCEEDED **` 在位
  - 「XCTest 执行摘要」notice 在位；`##[notice]` 2 条、`##[error]` 0 条、`##[warning]` 0 条
  - 真实退出码 **0**（job `101831973744` conclusion=success，10 个 step 全 success）
  - 目的地 `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`；Xcode 26.3
  - IPA `PhotoCleanupMVE-unsigned.ipa`，**1272446 字节**，
    SHA-256 `cbf52c67dfab8b18d627470832b9f39d716525826935a0255eceacb5031d426e`
  - 产物 `PhotoCleanupMVE-unsigned-ea96a74b3ef1`，zip 1272616 字节
- **G765：合并后 `main` 自动运行 #266**（run id `34151262768`，attempt 1）——**绿**
  - 被测提交 `ad4150488ed38a617192ffa237dc986470f77a75`，事件 `push`，分支 `main`
  - **Executed 676 tests, with 0 failures (0 unexpected) in 58.688 (69.675) seconds**；
    `** TEST SUCCEEDED **` 在位
  - 「XCTest 执行摘要」notice 在位；`##[notice]` 2 条、`##[error]` 0 条、`##[warning]` 0 条
  - 真实退出码 **0**（job `101833869077` conclusion=success，10 个 step 全 success）
  - 目的地同上；Xcode 26.3
  - IPA `PhotoCleanupMVE-unsigned.ipa`，**1272446 字节**，
    SHA-256 `b57e178e626d99fdf0afe26c78be37462502998d4c79076ca212c5be4346889a`
  - 产物 `PhotoCleanupMVE-unsigned-ad4150488ed3`，zip 1272616 字节
- 两次 IPA 字节数相同、SHA-256 不同——符合「IPA 归档不可复现」的既往结论，
  同时反向印证合并未改变任何产品代码
- **CI 预算 3 次用 1 次**（子项侧主跑即绿，2 次修未动用）；合并后 `main` 的自动
  运行不计入子项预算
- 本报告提交命中 `ci.yml` 的 `paths-ignore`（`Reports/**`、`**.md`），**不触发 CI**，
  为预期行为

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（工作树） | 0 |
| `git diff --check fc2bc77..ad41504` | 0 |
