# IC-134 自验报告

> 报告提交方式说明（执行纪律第 7 条）：报告须引用推送后才产生的 CI 运行编号与
> IPA 校验，故在同一张卡、同一分支内追加一个 docs 提交，不跨卡回填。
> **本卡不合并**（G745），报告写完即停，等 H60。

## 结论（先行）

**七个子项全部交付，CI 绿。** 分支 `feature/ic-134-s345-visual`，tip
`af4e55793b9e648f275fa4115205998e04cdf5f5`。CI **#263** 通过：XCTest
**674 项 0 失败**，真实退出码 0，「XCTest 执行摘要」notice 在位，目的地
`OS:26.2, name:iPhone 16`。二十四条断言逐条落实、逐条 passed。
G741～G744 全部满足；**G745 = 不合并，已停在报告**。本地三条门禁退出码均为 0。
CI 预算 4 次用 2 次。

**必须先看的三件事：**

1. **#262 是「绿但漏跑」，我没有把它当成通过。** 首推的 #262 conclusion=success、
   660 项 0 失败，但 `IC134S3VisualTests` 因 pbxproj **对象 id 与 IC-133 撞号**
   而从未进入编译列表——十四条 S3 断言一条都没跑，且不报错、不判红。
   我按「断言 → 测试函数名」逐条核对才发现（详见「CI」节）。修复后 #263 为
   674 项，与 665 − 15 + 24 精确对上。
2. **两处白名单外改动，均因卡内前提有误，均经 ④ Lynn 显式授权**（详见下节）。
3. **断言 8 的端到端部分夹具未覆盖**，如实标注，留给 H60 第 3 项。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260906-134-s345-visual.md`
- 继承提交：`main` = `39bade77dea68dd8b7b09b6a309d39ad54ae050f` ①，标题逐字比对一致
  （`docs: IC-133 自验与变更清单（#260 绿 665 项，合并入 main be77fd0，#261 绿）`）
- 开工检查：`git status --porcelain` 空；`git fetch` 后 `origin/main` 同为 `39bade7` ①
- 分支：`feature/ic-134-s345-visual`；**被测提交（完整 SHA）**
  `af4e55793b9e648f275fa4115205998e04cdf5f5`
- 基数 665 项 → 本卡后 **674 项**（子项 F 删 15 项，本卡新增 24 项）

## 白名单外改动（两处，均经 ④ Lynn 授权）

### 一、`Features/S1/S1View.swift` 一行

卡内写「直接引用 S1 视觉层已登记的常量与 helper（…`.s1ChromeGlassBackground(...)`、
`.s1ChromeCircleGlass()`），同 target 内可见」。**该前提对常量成立、对这两个
helper 不成立**（①源码可核验）：六个常量容器（`S1ChromeLayout`／`S1ChromeGlass`／
`S1ChromeForeground`／`S1ChromeTypography`／`S1NotificationBadgeStyle`／
`S1StatePlaceholderStyle`）都是 internal，可见；而两个 helper 声明在
`S1View.swift:536` 的 `private extension View` 内，是**文件私有**，S3／S4／S5
引用不到，全仓也没有第二处声明。

按 G742「缺必需项即停下报告」停下询问后，Lynn 授权把白名单扩到这一行：
`private extension View` → `extension View`。**取值与行为一字未动**，
`IC128S1VisualTests` 15 项原样通过（#263 实证）。玻璃配方因此保持单一来源——
H60 第 1 项「五页 chrome 是否同一套」正是要看这个；若改为三页各自重造 modifier，
日后 S1 改配方这三页不会跟着变。

### 二、`Scripts/selfcheck.ps1`

子项 F 授权删除 `FreeDiskSpaceReader.swift` 与占位图资源，但这两个产物被
`selfcheck.ps1` 硬编码在交付清单与专项校验里，**不改它本地门禁永远不绿**。
经 Lynn 两次授权（第一次我漏报了 L3 专项门禁，第二次补齐），删除范围逐条如下：

| # | 原门禁／清单项 | 处置 |
|---|---|---|
| 1 | 交付文件清单 `PhotoCleanupMVE/Services/FreeDiskSpaceReader.swift` | 删该行 |
| 2 | 交付文件清单 `…/RECENTLY_DELETED_PLACEHOLDER.imageset/Contents.json` | 删该行 |
| 3 | 交付文件清单 `…/RECENTLY_DELETED_PLACEHOLDER.imageset/RECENTLY_DELETED_PLACEHOLDER.png` | 删该行 |
| 4 | pbxproj 预期源文件表 `"FreeDiskSpaceReader.swift"` | 删该行 |
| 5 | 占位图 PNG 专项校验（`$pngFile` 起，签名与长度校验）整段 | 整段删除 |
| 6 | 占位图 `Contents.json` 专项校验（`$placeholderContentsFile` 起，locale 与 filename 核对）整段 | 整段删除 |
| 7 | 「产品源码疑似写死 L3 未定项」扫描（`$l3DefaultPatterns` 四条正则 + foreach）整段 | 整段删除 |
| 8 | `$forbiddenS5Patterns` 中的五个 L3 参数名（L3窗口上限／L3采样间隔／L3稳定判据／L3启动阈值／L3基线时机） | 只删这五行，**保留 `"S5-T2"`／`"S5-T3"`**（非 L3，守的是禁止的 S5 轮询实现） |
| 9 | 「缺少 L3 展示分支被未定规格阻断的显式标记」检查（`$l3GateMarker`）整段 | 整段删除 |
| 10 | 「L3 显示门槛被写入数值」检查（`$l3NumericGate`）整段 | 整段删除 |
| 11 | S5-C 必需测试名单中的 `testCancellationDoesNotReadFreeDiskStrictGB`、`testCancellationDoesNotShowL3`、`testCancellationDoesNotShowRecentlyDeletedConfirmationAction` | 删这三项，**保留 `testCancellationDoesNotShowSystemErrorDomainOrCode`**（守 S5-C 不显示错误域码，与 L3 无关） |

**其余门禁一字未动**：硬编码扫描、String Catalog 一致性、不少于 189 项测试的数量
下限、禁联网门禁、shell 变量名紧邻非 ASCII 扫描、PNG／工程配置校验、
`$removedS3Patterns`（S3 数量上限残留）。
清理后 `selfcheck.ps1` **真实退出码 0**（本地实测），`ParseFile` 无语法错误，
BOM 保留（含中文的 .ps1 必需）。

## 七个子项的交付

| 子项 | 提交 | 内容 |
|---|---|---|
| 前置 | `d3775c7` | S1 玻璃 helper 放宽为 internal（上节） |
| A | `0af8f39` | S3 顶排 chrome（左圆钮 + 中胶囊、无右件）、提示句、三态骨架、S3-4 空态 |
| B | `2370eba` | 分组卡、三列网格、⊖／♡／体积标签三件角标、移除动作；`ThumbnailView` 加边长／倍率／圆角参数 |
| C | `4ea4ea1` | 扫描器同趟返回按资源拆分、协调器只读侧通道、跨三列明细展开行 |
| D | `a732d8d` | 底部操作条、「全部取消」接 IC-133 两步动作、S3 文案收口 |
| E | `874fede` | S4 执行中页整层重写 |
| F | `ce1758e` | L3 整层撤销（13 文件） |
| G | `5187bda` | S5 完成页四态视觉 |
| 测试 | `47ea220` | 二十四条断言两个文件 |
| 修复 | `af4e557` | pbxproj id 撞号（#262 漏编译归因） |

## 三页取值表逐条落实

### 引用 S1 已登记常量（不新造数值）

`S3ChromeMetrics`／`S4ChromeMetrics`／`S5ChromeMetrics` 的
`rowHeight`／`topRowTopInset`／`horizontalMargin`／`itemSpacing`／
`titleFontSize`／`subtitleFontSize`／`circleIconPointSize` 逐项取自
`S1ChromeLayout` 与 `S1ChromeTypography`；`S3EmptyStateMetrics` 取自
`S1StatePlaceholderStyle`；玻璃与前景直接用 S1 的 helper 与
`S1ChromeForeground.primary/.secondary`（具体动态色，不用层级样式，v18 决策 42）。
**断言 1 比对的是 S1 常量本身，测试里不出现 44／16／15 这类字面量。**

### 引用 v18／S2 已登记常量

`S2OverlayLayout.bottomRowBottomInset`（S3 操作条与 S5 主按钮的底距）、
`S2OverlayLayout.minimumTouchTarget`（⊖ 命中区 44）。

### ④卡取值表转录（卡已给具体值，逐条落到登记制常量）

S3：提示句 59／32、列表 87／16／卡间 16；分组卡圆角 14、组头 12/14/8、
名 15 半粗、张数 13 次级等宽、基线间距 8；网格 3 列、间距 3、内边距 3、格子圆角 6；
⊖ 22/5/5、白横线 12×3；♡ 14pt、6/6；体积标签 18/9/6、11 半粗等宽、5/5、
chevron 9pt；明细行圆角 8、8/10、13 等宽；操作条 56/28/16、内边距 16/6、件距 10、
取消 15、主行 13、副行 11、转圈 16、删除 44/22/15/20。
S4：活动指示 36、16、17 半粗、8、15 次级。
S5：正文区 63/16/卡间 12；hero 44/8/22 粗/8/15 次级、上 8 下 2；三格间距 8、
圆角 14、上 12 下 10、数字 24 粗等宽、标签 12；信息卡圆角 14、14/16、
键 13／值 17／旁注 12 行高 16；引导卡 13 行高 18；主按钮 50/25/17 半粗。

### ④取定（卡未给的微观值，逐条登记）

| 取定 | 值与理由 |
|---|---|
| S3 末卡与操作条的间隙 | 8——卡只说「末卡不被遮」未给值，取与 chrome 件间距同值 |
| S3 列表底部净空的构成 | 操作条高 + 底距 + 间隙；**安全区底由滚动容器自身的安全区内边距承担，不重复计入**（否则末卡下方多出一个安全区高度的空白） |
| S3 明细行键值间距／项间距 | 4／8——卡未给 |
| S3 禁用态不透明度 | 0.4，与 S1 加载态同值（v18 §11.2 的 40%） |
| S3 空态图标用色 | `Color(uiColor: .tertiaryLabel)`，与 S1 空态同一写法 |
| S4 中央区左右留白 | 16，与 chrome 同值，长句不顶边 |
| S4 活动指示停止的判据 | 由 `S4State.isTerminal` 反解——**状态机没有现成的活动指示口径，本卡不新增状态机成员** |
| S5 副行「状态名」 | 取该态 hero 标题（`s5.t0.title` 等）——卡未给单独的状态名 key，四态状态名与 hero 标题同义。**副作用：胶囊副行与 hero 标题同文，H60 第 5／6 项请一并看是否读起来重复** |
| S5 正文区底部净空 | 按钮高 + 底距 + 一个卡间距 |
| S5 卡内行间距 | 6 |
| S5 hero 用色 | 取 `systemGreen`／`systemOrange` 动态色而非钉死十六进制——卡给的 `#34C759` 是 systemGreen 的**浅色**取值，`#FF9F0A` 是 systemOrange 的**深色**取值；钉死任一侧都会让另一侧不对。H60 第 5／6 项按观感复核 |

## 二十四条断言逐条结果（#263 全部 passed）①

| # | 断言 | 测试函数 |
|---|---|---|
| 1 | chrome 取值为 S1 常量的引用 | `testIC134A_ChromeMetricsReferenceS1RegisteredConstants` |
| 2 | 三态元素清单 | `testIC134A_StateElementsFollowThreeStateLayout` |
| 3 | 副行引用 IC-133 格式串类型 | `testIC134A_ChromeSubtitleComesFromIC133HeaderSubtitle` |
| 4 | 网格按 IC-133 过滤序生成、空组不生成 | `testIC134B_GridRowsFollowIC133FilteredOrderAndSkipEmptyGroups` |
| 5 | 角标口径（♡／标签文本／chevron） | `testIC134B_CellBadgeModelCoversFavoriteVolumeTextAndChevron` |
| 6 | ⊖ 调 `removeAsset` 恰一次、冻结后不响应 | `testIC134B_RemoveBadgeCallsRemoveOnceAndIsInertAfterFreeze` |
| 7 | 封面请求尺寸 2×／3× | `testIC134B_CoverRequestPixelSizeFollowsDisplayScale` |
| 8 | 拆分种类与总数 = 各项之和、单资源一项 | `testIC134C_ResourceKindMappingAndBreakdownSumInvariant`（**端到端夹具未覆盖，见下**） |
| 9 | 展开口径（至多一行／切换／收起／< 2 不可展开） | `testIC134C_DetailExpansionKeepsAtMostOneRow` |
| 10 | 明细经 `L10n` 与 `DecimalVolumeFormatter` | `testIC134C_DetailTextComesFromCatalogAndFormatter` |
| 11 | 操作条口径（扫描中／精确／下界；`canSubmit` ↔ 可用） | `testIC134D_ActionBarModelCoversScanningExactAndLowerBound` |
| 12 | 「全部取消」走 IC-133 两步动作 | `testIC134D_CancelAllGoesThroughIC133TwoStepAction` |
| 13 | 删除按钮调 `submitDeletion` 恰一次、禁用不调 | `testIC134D_SubmitButtonCallsDownstreamOnceAndNotWhenDisabled` |
| 14 | 目录无孤儿 key | `testIC134D_EveryS3KeyResolvesInCatalog` + 扫描器（210 ↔ 210，退出码 0） |
| 15 | S4 两态版式、终态不出现比例或预计时间 | `testIC134E_S4LayoutCoversBothStatesAndNeverShowsProgressOrEta` |
| 16 | `S4StateMachineTests` 45 项原样通过 | #263 实证 45 passed / 0 failed；另 `testIC134E_S4StateMachineSurfaceUntouchedByVisualLayer` |
| 17 | 产品源码不再引用 L3 三符号 | `testIC134F_L3SymbolsAreGoneFromProductSurface` + 全仓 grep（下节） |
| 18 | S5-T0 入场不触发磁盘读取 | `testIC134F_EntryTakesNoDiskReadingInjection`（注入点已不存在，能编译即为证明） |
| 19 | 含 L3 字段的旧完成态 JSON 解码成功 | `testIC134F_LegacyCompletionArchiveWithL3FieldsStillDecodes` |
| 20 | S5 四态迁移既有断言原样通过 | `testIC134F_FourStateTransitionsSurviveL3Removal`；`S5StateMachineTests` 34 passed、`TransitionTableGuardTests` passed |
| 21 | 四态元素清单、按钮、C 态文案 | `testIC134G_S5StateElementsAndButtons` |
| 22 | L2 精确／下界 + 旁注；L1 取自交接集合；S5-U 无三格 | `testIC134G_VolumeAndTileCountsComeFromHandoffSets` |
| 23 | 主按钮动作各恰一次 | `testIC134G_PrimaryButtonDispatchesExactlyOnce` |
| 24 | 目录无孤儿 key | `testIC134G_EveryS4AndS5KeyResolvesInCatalog` + 扫描器 |

### 断言 8 的覆盖边界（如实标注，纪律第 5 条）

`scanWithBreakdown(_:)` 需要真实 `PHAsset` 才能驱动，夹具层给不出（不能构造
`PHAssetResource`）。因此断言 8 只覆盖**纯口径**：`PHAssetResourceType` → 四类的
映射（photo／video／liveVideo／other 逐个取值实测），以及「总数 = 各项字节之和」
这条不变量。**「同一趟扫描」的端到端行为夹具未覆盖**，留给 H60 第 3 项
（真机上点实况照片的体积标签，看明细数字与系统「照片」信息面板量级是否对得上）。

## 闸门逐条结论

### G741（diff 限于白名单）：**通过**（两处例外已授权）①

diff 共 20 文件。除上节两处授权例外（`Features/S1/S1View.swift` 一行、
`Scripts/selfcheck.ps1`）外，全部在卡内白名单内。

**扫描器改动**：只加侧通道——新增 `AssetResourceKind`、`AssetSizeBreakdownItem`、
`AssetScanOutcome` 三个类型与 `scanWithBreakdown(_:)`；`scan(_:)` 改为取该结果的
结论部分，**逐资源取字节后求和的算法与顺序逐字未变**，只多攒一个数组。

**协调器改动**（只碰点名处）：

| 类别 | 名称 | 说明 |
|---|---|---|
| 新增成员 | `scanBreakdownsByAssetID`（private） | C：体积明细只读侧通道 |
| 新增函数 | `scanBreakdown(for:)`、`scanBreakdownItemCount(for:)` | C：只读消费口 |
| 改动函数 | `beginPendingScans()` | C：改调 `scanWithBreakdown` 并接住拆分；不重扫、不改状态机缓存、不入档 |
| 删除成员 | `freeDiskSpaceReader` 属性与 init 参数 | F |
| 删除函数 | `confirmRecentlyDeletedCleared()` | F |
| 改动函数 | `enterCompletion(from:)`、`restorePersistedSession()` 的 S5 分支 | F：去掉两处 `readFreeDiskStrictGB:` 注入与四个 L3 字段传递 |

`s1*`／`s2*` 成员与 S1／S2 路由**零改动**。

**S5 状态机只删 L3**：删除 `S5DiskReading`、`S5L3DisplayGate`、
`S5PresentationCapabilities` 的 `allowsFreeDiskStrictRead`／`showsL3`／
`showsRecentlyDeletedConfirmationAction`（只留 `showsSystemErrorDetails`）、
`S5Event.confirmRecentlyDeletedCleared` 与其 handler、`S5PersistentState` 四个 L3
字段、`enter` 的入场读取与 `readFreeDiskStrictGB` 参数、`handle` 的同名参数、
`isValid` 的 L3 校验、`isRecentlyDeletedConfirmationEnabled`。
**保留**：四态、`A`／`B`／`C` 集合不变量、`下游目标状态` 直接落位、
返回确认页与离开出口、终态持久化与恢复——一字未动。

> 说明：`allowsFreeDiskStrictRead` 不在卡内点名的删除清单里，但它存在的唯一目的
> 是许可那次磁盘读取，读取删掉后它必为死字段，故一并删除并在此登记。

**持久化**：`PersistedSession` 去掉四个 L3 字段。旧档仍带这些键——`Codable`
合成解码**忽略多余键**，故旧档照常解码、不判坏档，**无需自定义 `init(from:)`**
（断言 19 钉住）。

### G742（取值来源）：**通过** ①

chrome 全部引用 S1 常量或 v18／S2 已登记量，未新造数值（断言 1 比对 S1 常量本身）；
取值表未给的微观值以「④取定」逐条登记（见上「④取定」表，共 11 条）。
**缺必需项时确实停下报告了**——两次，见「白名单外改动」。

### G743（S1／S2 与状态机零改动）：**通过** ①

- S1／S2 产品**行为**零改动：diff 中 S1／S2 只有 `S1View.swift` 那一行可见性放宽，
  取值与行为未动，`IC128S1VisualTests` 15 项原样通过
- S3／S4 状态机**文件级零改动**（`git diff --stat` 对两文件为空）
- `S2CalibrationConfiguration.schemaVersion` 仍为 **7**（`S2Calibration.swift:118`；
  该文件不在 diff 内，出厂值集合未变）
- 冻结三链 tip 未变：`b368a6c` / `6736f1e` / `a7cc1ec`

### G744（CI 绿）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#263**（run id `34079402643`，attempt 1） |
| 被测提交 | `af4e55793b9e648f275fa4115205998e04cdf5f5` |
| job | `101611690365`，conclusion=**success**，03:22:09Z→03:26:34Z |
| XCTest | **Executed 674 tests, with 0 failures (0 unexpected) in 51.670 (64.149) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 「XCTest 执行摘要」notice | **在位**（IC-125 哨兵通过，674 > 0） |
| 真实退出码 | **0**（job conclusion=success） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| 选定日志行 | `使用 iPhone 模拟器：iPhone 16 (id=EADC2067-…, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| **IPA（H60 用）** | `PhotoCleanupMVE-unsigned.ipa`，**1293853 字节**，SHA-256 `9d8a05f9d7ab3d50a37e4c25b78178377997afbe0a53c8bafaad48e573d01241` |
| 产物 | `PhotoCleanupMVE-unsigned-af4e55793b9e`，zip 1294023 字节 |
| 实际发出的注解 | `##[notice]` 2 条；`##[error]` **0** 条；`##[warning]` **0** 条 |

### G745（不合并）：**遵守** ①

分支停在 `af4e557` + 报告提交，**未合并入 `main`**，等 H60。

## CI 预算与 #262 的「绿但漏跑」

预算 4 次，**用 2 次**，剩 2 次未动用。

- **#262（run id `34078426805`）conclusion=success，660 项 0 失败——但不是合格的绿。**
  `IC134S3VisualTests` 从未进入编译列表，十四条 S3 断言一条没跑。
  归因：pbxproj 对象 id 撞号——我按 IC-132 的 `…0037`／`…003A` 顺推下一个空号，
  但**中间合并的 IC-133 已占用** `200000000000000000000038` 与
  `10000000000000000000003B`。两个对象重号后 Xcode 解析到 IC-133 的那条，
  我的文件被静默丢弃：**不报错、不判警、不判红**。
- **发现方式**：按「断言 → 测试函数名」逐条核对 #262 日志时，
  A／B／C／D 十四条一条都搜不到；项数也对不上
  （665 − 15 + 24 应为 674，实得 660 = 665 − 15 + 10）。
- 修复 `af4e557`：改用真正空闲的 `20000000000000000000003A` ／
  `10000000000000000000003D`，并对全表做 id 出现次数复查
  （buildFile 应 2 次、fileRef 应 3 次），除 `Info.plist`（只进 group 不进编译，
  2 次，与 `main` 一致）外无异常。→ **#263 绿，674 项**。

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1`（已按授权清理） | **0** | String Catalog **210 条目 ↔ 210 源码引用**；用户可见硬编码残留 0；不少于 189 项测试的数量门禁、禁联网门禁均通过 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 残留 0，无孤儿 key |
| `git diff --check`（`39bade7..af4e557`） | **0** | |

## 人工判定项（H60，原样列出，**留给 Lynn，执行端不代为下结论**）

1. S1 → S2 → S3 → S4 → S5 走一遍，五页顶排 chrome 是否同一套（明暗各一遍）。
2. S3 真实照片上 ⊖、♡、体积标签是否看得清、是否吵；三列网格误触 ⊖ 的频率。
3. S3 实况照片点体积标签展开明细，数字与系统「照片」信息面板量级对得上
   （口径不同只看量级）。
4. S3 扫描中 → 就绪的操作条切换与「全部取消」二次确认措辞。
5. S4 提交后到 S5 的过渡是否顺（提交约 20 张）；S5 成功页读起来是否清楚该去哪清空。
6. 取消路径（系统弹窗点「不允许」）落到 S5-C 的观感与措辞。

**执行端能说明的边界**：二十四条断言全部走展示口径模型，**不驱动 SwiftUI 渲染**
（陷阱 1）；三页的实际像素落位、明暗两套的观感、误触频率、过渡顺滑度**全部没有
自动化覆盖**。另有三处请在真机上一并留意：
第 1 项——玻璃 helper 现已是三页共用的同一份，若观感仍有差异说明问题不在配方；
第 5／6 项——S5 胶囊副行取的是 hero 标题，两处同文，请判断是否读起来重复；
hero 图标取的是系统动态色而非卡内十六进制，明暗两套都请看。

## 发现但未处理的问题（按纪律只报告不修）

1. **`TransitionTableGuardTests` 仍在遍历已不存在事件的四行矩阵**（①）。
   L3 撤销后 `S5Event` 没有「我已清空最近删除」，但
   `Reports/TRACEABILITY-S3-S5.md` 里仍有该事件的 4 个单元格，且该测试断言
   **硬计数**（115 单元格、63 不可达标记）。`Reports/` 不在本卡白名单，改表会
   同时破坏计数，故我把该分支改为「事件已删除 ⇒ 恒不可达」直接判过并注明。
   **建议另开一卡同步矩阵与计数。**
2. **`Reports/GUARD-ASSERTION-STRENGTH.md` 与 `TRACEABILITY-S3-S5.md` 中引用了
   本卡删除的 11 个 L3 测试函数名**（①，如 C5-025／C5-028／C5-030／C5-035 各行）。
   同属 `Reports/`，未动，随第 1 条一并处理。
3. **卡内点名 `S2CalibrationHarnessTests.swift` 含 L3 引用，实测没有**（①）。
   全仓扫描确认 L3 只出现在 `S5StateMachineTests`、`CoverageGapTests`、
   `TransitionTableGuardTests` 三个测试文件，故只改了这三个。
4. **`selfcheck.ps1` 的 S5-C 必需测试名单现在只剩一项**（①）。删掉三个 L3 用例后
   该名单只余 `testCancellationDoesNotShowSystemErrorDomainOrCode`，
   门禁强度随之下降。是否需要为 S5-C 补充新的禁用项测试，属规格与门禁设计范畴，
   本卡未擅自增补。
5. **S5 胶囊副行与 hero 标题同文**（①）。卡未给单独的状态名 key，④取定复用 hero
   标题，屏幕上会出现两处相同文字。若 H60 判定读起来重复，需要新增四条状态名 key。
6. **`AssetScanOutcome` 的拆分在「缓存复用」路径下恒为空**（①，设计如此）。
   S3 若从 `conclusionCache` 直接拿到已知字节而未走本次扫描，侧通道没有拆分，
   体积标签因此不显箭头、不可展开。符合卡内「拆分为空（缓存复用／未扫描／单资源）
   不显 chevron」的规定，登记备查——真机上「同一张照片第二次进 S3 不能展开明细」
   是预期行为，不是缺陷。
