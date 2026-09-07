# IC-134 变更清单

分支：`feature/ic-134-s345-visual`（自 `main` = `39bade7` 切出）
被测提交：**`af4e55793b9e648f275fa4115205998e04cdf5f5`**
**本卡不合并（G745）**——停在报告，等 H60。

## 提交链（七个子项各自独立 commit；本卡以整组为 cherry-pick 单位）

| 提交 | 内容 |
|---|---|
| `d3775c7` | 前置：S1 玻璃 helper 由 `private extension View` 放宽为 internal（④ Lynn 授权） |
| `0af8f39` | **A**：S3 顶排 chrome、提示句、三态骨架、S3-4 空态 |
| `2370eba` | **B**：S3 分组网格、格子三件角标、移除；`ThumbnailView` 加三个参数 |
| `4ea4ea1` | **C**：扫描侧通道与跨三列体积明细展开行 |
| `a732d8d` | **D**：S3 底部操作条、全部取消接线、S3 文案收口 |
| `874fede` | **E**：S4 执行中页整层重写 |
| `ce1758e` | **F**：L3「设备可用空间变化」整层撤销 |
| `5187bda` | **G**：S5 完成页四态视觉 |
| `47ea220` | 测试：二十四条断言两个文件 |
| `af4e557` | fix：`IC134S3VisualTests` 的 pbxproj id 与 IC-133 撞号（#262 漏编译归因） |

## 文件级变更（`39bade7..af4e557`，20 文件 +2850 −1130）

| 文件 | +/− | 子项 | 变更 |
|---|---|---|---|
| `Features/S3/S3View.swift` | +888 −130 | A～D | 整层重写；保留 IC-133 的 `S3GroupPresentation`／`S3HeaderSubtitle`／`S3CancelAllAction` 原样。新增登记制常量 6 个容器与口径模型 `S3ChromeBarModel`／`S3StateElement`／`S3StatePresentation`／`S3CellBadgeModel`／`S3RemoveButtonAction`／`S3DetailExpansion`／`S3GridRows`／`S3VolumeDetailText`／`S3VolumeDetailMetrics`／`S3ActionBarModel`／`S3SubmitButtonAction` |
| `Features/S5/S5View.swift` | +588 −108 | F、G | 整层重写；新增 `S5ChromeMetrics`／`S5PageLayout`／`S5HeroMetrics`／`S5TileMetrics`／`S5CardMetrics`／`S5ButtonMetrics`／`S5HeroPalette` 与口径 `S5StateElement`／`S5PrimaryAction`／`S5ResultTileCounts`／`S5VolumePrefix`／`S5VolumeCardModel`／`S5StatePresentation` |
| `Features/S4/S4View.swift` | +127 −68 | E | 整层重写；新增 `S4ChromeMetrics`／`S4StatusMetrics`／`S4StatusPresentation` |
| `Localizable.xcstrings` | +105 −105 | A～G | 见「文案增删改」 |
| `App/CleanupCoordinator.swift` | +25 −34 | C、F | 见「协调器改动」 |
| `Core/S5StateMachine.swift` | +10 −115 | F | 见「S5 状态机删除清单」 |
| `Services/AssetSizeScanner.swift` | +55 −4 | C | 见「扫描器改动」 |
| `Features/Shared/ThumbnailView.swift` | +23 −2 | B | 加 `sideLength`／`displayScale`／`cornerRadius` 三个参数（默认值与既有调用点行为一致）；请求像素改走 `targetPixelSize(sideLength:displayScale:)` |
| `Core/SessionPersistence.swift` | +3 −12 | F | `PersistedSession` 去掉四个 L3 字段；旧档多余键由合成解码忽略 |
| `Features/S1/S1View.swift` | +5 −1 | 前置 | **白名单外，④ Lynn 授权**：`private extension View` → `extension View` + 四行说明注释。取值与行为一字未动 |
| `Scripts/selfcheck.ps1` | +1 −80 | F | **白名单外，④ Lynn 授权**：见「selfcheck.ps1 删除清单」 |
| `Services/FreeDiskSpaceReader.swift` | −13 | F | 整个文件删除 |
| `Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/*` | −24 + PNG | F | 占位图资源删除 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +8 −4 | B、F、测试 | 删 `FreeDiskSpaceReader.swift` 四处登记；加两个测试文件各四处登记 |
| `PhotoCleanupMVETests/IC134S3VisualTests.swift` | +495 | 测试 | 断言 1～14 共 14 项 |
| `PhotoCleanupMVETests/IC134S4S5VisualTests.swift` | +497 | 测试 | 断言 15～24 共 10 项 |
| `PhotoCleanupMVETests/S5StateMachineTests.swift` | +1 −241 | F | 删 11 个纯 L3 用例（45 → 34）、改 2 个混合用例 |
| `PhotoCleanupMVETests/CoverageGapTests.swift` | +15 −185 | F | 删 4 个纯 L3 用例（36 → 32）、改 6 处 |
| `PhotoCleanupMVETests/TransitionTableGuardTests.swift` | +4 −4 | F | 「我已清空最近删除」分支改为「事件已不存在 ⇒ 恒不可达」 |

## 扫描器改动（只加侧通道）

**新增**：`AssetResourceKind`（`PHAssetResourceType` → photo／video／liveVideo／other）、
`AssetSizeBreakdownItem`、`AssetScanOutcome`、`scanWithBreakdown(_:)`。
**改动**：`scan(_:)` 改为 `await scanWithBreakdown(asset).conclusion`。
**未变**：结论口径与「逐资源取字节后求和 + 溢出即 `.unavailable`」的算法与顺序
逐字未动，只多攒一个数组。

## 协调器改动（只碰点名处）

| 类别 | 名称 | 子项 |
|---|---|---|
| 新增成员 | `scanBreakdownsByAssetID`（private，只读侧通道） | C |
| 新增函数 | `scanBreakdown(for:)`、`scanBreakdownItemCount(for:)` | C |
| 改动函数 | `beginPendingScans()`——改调 `scanWithBreakdown` 并接住拆分；不重扫、不改状态机缓存、不入档 | C |
| 删除成员 | `freeDiskSpaceReader` 属性与 init 参数 | F |
| 删除函数 | `confirmRecentlyDeletedCleared()` | F |
| 改动函数 | `enterCompletion(from:)`、`restorePersistedSession()` 的 S5 分支——去掉两处 `readFreeDiskStrictGB:` 注入与四个 L3 字段传递 | F |

`s1*`／`s2*` 成员与 S1／S2 路由**零改动**。

## S5 状态机删除清单（只删 L3）

`S5DiskReading`（整个类型）、`S5L3DisplayGate`、`S5PresentationCapabilities` 的
`allowsFreeDiskStrictRead`／`showsL3`／`showsRecentlyDeletedConfirmationAction`
（只留 `showsSystemErrorDetails`）、`S5Event.confirmRecentlyDeletedCleared` 与其
handler、`S5PersistentState` 的 `l3BaselineReading`／`l3CompletionReading`／
`l3DeltaGB`／`recentlyDeletedClearedAt`、`enter` 的入场读取与
`readFreeDiskStrictGB` 参数、`handle` 的同名参数、`isValid` 的全部 L3 校验、
`isRecentlyDeletedConfirmationEnabled`。

> `allowsFreeDiskStrictRead` 不在卡内点名清单里，但它存在的唯一目的是许可那次
> 磁盘读取，读取删掉后必为死字段，故一并删除并在此登记。

**保留（一字未动）**：四态、`A`／`B`／`C` 集合不变量、`下游目标状态` 直接落位、
L1／L2 口径、返回确认页与离开出口、终态持久化与恢复。

## 持久化改动与旧档兼容

`PersistedSession` 删除四个 L3 字段。旧完成态档仍带这些键——`Codable` 的合成解码
**忽略多余键**，故旧档照常解码、不判坏档，**无需自定义 `init(from:)`**。
断言 19 手工把四个 L3 字段塞回 JSON 后仍解码成功、四态恢复正确。

## `Scripts/selfcheck.ps1` 删除清单（白名单外，④ Lynn 两次授权）

| # | 原门禁／清单项 | 处置 |
|---|---|---|
| 1 | 交付清单 `Services/FreeDiskSpaceReader.swift` | 删该行 |
| 2 | 交付清单 占位图 `Contents.json` | 删该行 |
| 3 | 交付清单 占位图 `.png` | 删该行 |
| 4 | pbxproj 预期源文件表 `"FreeDiskSpaceReader.swift"` | 删该行 |
| 5 | 占位图 PNG 专项校验（`$pngFile` 起，长度与签名） | 整段删除 |
| 6 | 占位图 `Contents.json` 专项校验（`$placeholderContentsFile` 起，locale 与 filename） | 整段删除 |
| 7 | 「产品源码疑似写死 L3 未定项」扫描（`$l3DefaultPatterns` 四条正则 + foreach） | 整段删除 |
| 8 | `$forbiddenS5Patterns` 的五个 L3 参数名 | 只删五行；**保留 `"S5-T2"`／`"S5-T3"`** |
| 9 | 「缺少 L3 展示分支被未定规格阻断的显式标记」（`$l3GateMarker`） | 整段删除 |
| 10 | 「L3 显示门槛被写入数值」（`$l3NumericGate`） | 整段删除 |
| 11 | S5-C 必需测试名单的三个 L3 用例名 | 删三项；**保留 `testCancellationDoesNotShowSystemErrorDomainOrCode`** |

**其余门禁一字未动**（硬编码扫描、String Catalog 一致性、≥189 项测试数量下限、
禁联网、shell 变量名紧邻非 ASCII 扫描、PNG／工程配置、`$removedS3Patterns`）。
清理后**真实退出码 0**，`ParseFile` 无错，BOM 保留。

## 文案增删改（`s3.*`／`s4.*`／`s5.*`／`submission.*`）

**合计 210 → 210**：新增 42、删除 42、改值 4。

**新增 42**：`s3.chrome.title`、`s3.group.count_format`、`s3.cell.*`（4）、
`s3.detail.kind.*`（4）、`s3.action.delete_count`、`s3.bar.*`（5）；
`s4.chrome.*`（2）、`s4.status.*`（3）；
`s5.chrome.title`、`s5.t0.*`（3）、`s5.c.*`（2）、`s5.f.*`（2）、`s5.u.*`（2）、
`s5.tile.*`（3）、`s5.card.*`（5）、`s5.volume.prefix`／`lower_bound_format`／
`unavailable_note_format`。

**删除 42**：S3 旧 `List` 版 14 条、S4 旧版 12 条、S5 旧版 15 条
（含 L3 的 `s5.action.confirm_recently_deleted_cleared`、
`s5.status.device_space_waiting`、`s5.placeholder.disclaimer`），
另 `submission.asset_count`（S4／S5 重写后无引用）。

**改值 4**：

| key | 新值 | 依据 |
|---|---|---|
| `s3.state.empty` | 没有待删除照片。 | 卡内「改值补句号」 |
| `s5.failure.retry_notice` | 已保留原提交集合，可返回确认页再次尝试。 | 卡内「末尾补句号」 |
| `s5.unknown.manual_verification_notice` | 请人工核对照片原位置与系统「最近删除」。 | 卡内「末尾补句号」 |
| `s5.recently_deleted.boundary_notice` | 照片已移入系统「最近删除」，仍由系统保留。应用无法读取或清空该位置。请打开系统「照片」，进入「实用工具」中的「最近删除」，由你完成清空，然后返回本页。 | 卡内引导卡正文逐字（原值作「App 无法读取」，卡作「应用无法读取」，按卡改） |

扫描器实测 **210 目录条目 ↔ 210 源码引用**，无孤儿 key，退出码 0。

## 断言 → 测试函数（二十四条，#263 逐条 passed）

1 `testIC134A_ChromeMetricsReferenceS1RegisteredConstants`／
2 `testIC134A_StateElementsFollowThreeStateLayout`／
3 `testIC134A_ChromeSubtitleComesFromIC133HeaderSubtitle`／
4 `testIC134B_GridRowsFollowIC133FilteredOrderAndSkipEmptyGroups`／
5 `testIC134B_CellBadgeModelCoversFavoriteVolumeTextAndChevron`／
6 `testIC134B_RemoveBadgeCallsRemoveOnceAndIsInertAfterFreeze`／
7 `testIC134B_CoverRequestPixelSizeFollowsDisplayScale`／
8 `testIC134C_ResourceKindMappingAndBreakdownSumInvariant`（端到端夹具未覆盖）／
9 `testIC134C_DetailExpansionKeepsAtMostOneRow`／
10 `testIC134C_DetailTextComesFromCatalogAndFormatter`／
11 `testIC134D_ActionBarModelCoversScanningExactAndLowerBound`／
12 `testIC134D_CancelAllGoesThroughIC133TwoStepAction`／
13 `testIC134D_SubmitButtonCallsDownstreamOnceAndNotWhenDisabled`／
14 `testIC134D_EveryS3KeyResolvesInCatalog`／
15 `testIC134E_S4LayoutCoversBothStatesAndNeverShowsProgressOrEta`／
16 `S4StateMachineTests` 45 项 + `testIC134E_S4StateMachineSurfaceUntouchedByVisualLayer`／
17 `testIC134F_L3SymbolsAreGoneFromProductSurface`／
18 `testIC134F_EntryTakesNoDiskReadingInjection`／
19 `testIC134F_LegacyCompletionArchiveWithL3FieldsStillDecodes`／
20 `testIC134F_FourStateTransitionsSurviveL3Removal`／
21 `testIC134G_S5StateElementsAndButtons`／
22 `testIC134G_VolumeAndTileCountsComeFromHandoffSets`／
23 `testIC134G_PrimaryButtonDispatchesExactlyOnce`／
24 `testIC134G_EveryS4AndS5KeyResolvesInCatalog`

## 子项 F 删除的测试用例清单（共 15 项）

**`S5StateMachineTests`（45 → 34），删 11**：
`testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation`、
`testCancellationDoesNotReadFreeDiskStrictGB`、
`testCancellationDoesNotShowL3`、
`testCancellationDoesNotShowRecentlyDeletedConfirmationAction`、
`testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt`、
`testConfirmationReadsCompletionExactlyOnceAndPersistsDelta`、
`testRepeatedConfirmationDoesNotReadAgain`、
`testLifecycleEventsDoNotReadFreeDiskAgain`、
`testUnavailableReadingsArePersistedWithoutDeltaOrRetry`、
`testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime`、
`testL3DisplayRemainsBlockedForEveryState`。
**改 2**（保留非 L3 断言）：
`testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory`、
`testRestoreKeepsPersistedCancellationStateWithoutDiskRead`。

**`CoverageGapTests`（36 → 32），删 4**：
`testC5_031RepeatedLifecycleTicksNeverPollFreeDisk`、
`testC5_039CompletedReadingsSurviveTerminationAndRestoreWithoutNewRead`、
`testC5_069FailureNeverReadsFreeDiskOrDisplaysL3`、
`testC5_144SuccessExitClearsPersistedL3Session`。
**改 6**：`testC5_006`、`testC5_086`（更名为
`testC5_086UnknownCannotWriteBackManualResult`）、`testC5_087`、`testC5_145`、
`testC34_101`、`makeSuccessS5Machine` 夹具。

**`TransitionTableGuardTests`**：「我已清空最近删除」分支改为直接判过。

净变化：665 − 15 + 24 = **674**。

## CI（预算 4 次，用 2 次）

- **#262 红判（虽然 conclusion=success）**（run id `34078426805`）：660 项 0 失败，
  但 `IC134S3VisualTests` 因 pbxproj 对象 id 与 IC-133 撞号
  （`200000000000000000000038`／`10000000000000000000003B`）**从未进入编译列表**，
  十四条 S3 断言一条未跑，且不报错不判红。修复见 `af4e557`。
- **#263 绿**（run id `34079402643`，job `101611690365`）：被测提交
  `af4e55793b9e648f275fa4115205998e04cdf5f5`，**674 项 0 失败**、退出码 0、
  `** TEST SUCCEEDED **`、摘要 notice 在位、`##[error]` 0 条、`##[warning]` 0 条，
  目的地 `{ platform:iOS Simulator, arch:arm64, id:EADC2067-…, OS:26.2, name:iPhone 16 }`，
  **IPA（H60 用）`PhotoCleanupMVE-unsigned.ipa` 1293853 字节，
  SHA-256 `9d8a05f9d7ab3d50a37e4c25b78178377997afbe0a53c8bafaad48e573d01241`**，
  产物 `PhotoCleanupMVE-unsigned-af4e55793b9e` zip 1294023 字节。
- 剩 2 次未动用。

## 回归（#263 实证，全部 0 失败）

`IC133S3BehaviorTests` 9、`S3StateMachineTests` 22、`S4StateMachineTests` 45、
`S5StateMachineTests` 34、`CoverageGapTests` 32、`TransitionTableGuardTests` 1、
`IC128S1VisualTests` 15。

## 占位值登记

出厂值集合未动，`S2CalibrationConfiguration.schemaVersion` 保持 **7**
（`S2Calibration.swift:118`，该文件不在 diff 内）；`factoryPlaceholder` 登记制不变。
三页视觉常量走各自文件内的登记制容器，**不进标定配置、不上标定面板**。

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1`（已按授权清理） | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（`39bade7..af4e557`） | 0 |

## 分支与冻结链状态（本地＝远端）

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `39bade7` | **未推进——本卡不合并** |
| `feature/ic-134-s345-visual` | `af4e557` + 报告提交 | 停在报告，等 H60 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |
