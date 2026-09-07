# IC-136 自验报告

> 报告提交方式说明（执行纪律第 7 条）：本卡含合并授权，报告必须引用推送后才产生的
> CI 运行编号、IPA 校验与合并 SHA，故采用「同一张卡、同一分支内追加一个 docs 提交」
> 的方式，随合并一并留在 `main` 上，不跨卡回填。

## 结论（先行）

**三个子项全部交付，两次 CI 均一次绿，已合并入 `main`。**
分支 `feature/ic-136-h60-followups`，代码 tip `ea96a74b3ef120b3490b464a96a293970e885845`。
CI **#265** 通过：XCTest **676 项 0 失败**，真实退出码 0，「XCTest 执行摘要」notice
在位，目的地 `OS:26.2, name:iPhone 16`。九条断言逐条落实、逐条按测试函数名核对
日志并对账项数增减（674 → 676）。G761～G764 全部满足，`--no-ff` 合并提交
**`ad41504`**（完整 SHA `ad4150488ed38a617192ffa237dc986470f77a75`）；
**G765**：合并后 `main` 自动运行 **#266** 同为 676 项 0 失败。
本地三条门禁退出码均为 0。CI 预算 3 次**用 1 次**（子项侧主跑即绿），合并后 `main`
自动运行 1 次不计入子项预算。人工判定项 H61 三项保留给 Lynn 真机验证。

**必须先看的三件事：**

1. **任务卡两处坐标与仓库实际不符**（均为③级坐标，不影响定案本身，详见「卡内前提
   与实测的出入」节）：既有 formatter 断言不在卡说的两个文件里；断言 9 点名的
   `centerIndicatorTransitionMs` 全仓不存在。我按实际位置施工并如实登记，未硬套。
2. **本卡有第 4 个提交 `ea96a74`**（推 CI 前的两处类型收口）。它同时改到 A 与 C 的
   测试文件，**单独 cherry-pick 到没有 A／C 的树上不成立**——这一条不符合交付物
   格式第 1 条，原因与取舍见「发现但未处理的问题」第 8 条。
3. **`S3VolumeDetailMetrics` 撤销后名不副实**：容器只剩 `pairSpacing`，而它的消费者
   在操作条扫描行，与「体积明细」无关。改名属卡外，按纪律只登记不修。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260907-136-h60-followups.md`
- 继承提交：`main` = `fc2bc77c7eb80671ff630c7567e7b445b4df2988` ①
  标题 `docs: IC-135 自验与变更清单（合并 IC-134 入 main 17736e3，#264 绿 674 项）`，
  以 `docs: IC-135` 开头，与卡相符
- `git rev-parse main~1^2` = `54ac69e10d38c65092cc08ba8b32790b1e53dbf7` ①，与卡逐字相符
- 开工检查：`git status --porcelain` 空；`git fetch` 后 `origin/main` 同为 `fc2bc77` ①
- 现状基数：`main` 上 XCTest **674 项**（IC-135 报告登记的 #264；本地
  `git grep -c "    func test"` 在该提交上同为 674，与 CI 读数一致 ①）
- 分支：`feature/ic-136-h60-followups`，自该 `main` 切出
- 依据：H60 真机判定（④ Lynn 2026-09-07），Decision_log 第 147 条

## 子项 A：撤销 S3 体积明细展开（提交 `3e091c2`）

### 改动函数与删除成员（G761 要求逐一列出）

**`Services/AssetSizeScanner.swift`**——删除后**整文件与 `39bade7`（IC-134 之前）
逐字节相同**（`diff` 无输出 ①）。这是「`scan(_:)` 结论口径不变」最强的证据形式，
不是 diff 观察：

| 删除 | 类别 |
|---|---|
| `enum AssetResourceKind`（含 `init(_:PHAssetResourceType)`） | 类型 |
| `struct AssetSizeBreakdownItem` | 类型 |
| `struct AssetScanOutcome` | 类型 |
| `func scanWithBreakdown(_:)` | 方法 |

`AssetResourceKind` 卡内未点名，但删掉拆分项后它全仓零消费者，按「不留死代码」
一并删除（②判断，已实测确认删前删后全仓引用数分别为 4 与 0）。

**`App/CleanupCoordinator.swift`**：

| 处置 | 成员 |
|---|---|
| 删除 | `private var scanBreakdownsByAssetID`（拆分字典） |
| 删除 | `func scanBreakdown(for:)` |
| 删除 | `func scanBreakdownItemCount(for:)` |
| 改动 | `private func beginPendingScans()`——回到 `await sizeScanner.scan(asset)` 一条路径，删掉侧通道接住点 |

删除后该文件与 `39bade7` 的差异**只剩 IC-134 F（L3 撤销）的四处** ①，
即协调器只碰了点名处，未越界。

**`Features/S3/S3View.swift`**：

| 处置 | 成员 |
|---|---|
| 删除 | `S3CellBadgeMetrics.detailChevronPointSize` |
| 删除 | `S3CellBadgeModel.showsDetailChevron`、`S3CellBadgeModel.isDetailExpanded` |
| 删除 | `enum S3VolumeDetailText`（`kindLabel(_:)`、`value(_:)`） |
| 删除 | `struct S3DetailExpansion`（`isExpandable`／`isExpanded`／`toggle`／`expandedAssetID`） |
| 删除 | `S3GridRows.rowIndex(ofAssetID:in:)`（撤销后零消费者） |
| 删除 | `S3View.detailExpansion` 状态 |
| 删除 | `S3View.volumeDetailRow(_:)` |
| 删除 | `S3VolumeDetailMetrics` 的 5 个成员：`cornerRadius`／`verticalPadding`／`horizontalPadding`／`fontSize`／`itemSpacing` |
| 改动 | `S3CellBadgeModel.make(asset:conclusion:)`——去掉 `breakdownItemCount` 与 `isDetailExpanded` 两个参数 |
| 改动 | `grid(_:machine:cellWidth:)`——去掉展开行的行号计算与插入点 |
| 改动 | `cell(_:machine:cellWidth:)`——去掉侧通道读取 |
| 改动 | `volumeBadge(_:)`——**不再是 `Button`**，不接点击、不占命中区 |
| 改动 | `volumeBadgeLabel(_:)`——去掉 chevron 分支，只剩一个 `Text` |

**保留未动**：`S3GridRows.rows(_:)` 与手工分行本身。撤销的是明细那一行，不是分行；
改成 `LazyVGrid` 会动版式，属卡内「其余版式不动」的禁区。
`S3VolumeDetailMetrics.pairSpacing` 保留——它另有消费者（操作条扫描行的
「转圈 ↔ 文案」间距，`S3View.swift` 内），删掉会连带改到 D 的版式。

**`Localizable.xcstrings`**：删 4 键，目录 **210 → 206** ①，与产品源码引用一致
（`selfcheck.ps1` 实测「目录 key 与产品源码引用一致」）：

- `s3.detail.kind.photo`
- `s3.detail.kind.video`
- `s3.detail.kind.live_video`
- `s3.detail.kind.other`

### 断言 1～4 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 1 | 角标模型不再有 chevron／展开字段；标签文本只三种来源 | `testIC136A_CellBadgeModelHasNoChevronOrExpansionFields`（`Mirror` 逐字段列出，实测 `["showsFavorite", "volumeText"]`）＋ `testIC134B_CellBadgeModelCoversFavoriteVolumeTextAndChevron`（三种来源） | **passed** ① |
| 2 | 产品源码不再引用 5 个符号 | `testIC136A_ProductSourceNoLongerReferencesRemovedSymbols`（扫 4 个产品文件；名字在测试里**拼接构造**，不写全，免得断言抓到自己） | **passed** ① |
| 3 | `scan(_:)` 结论口径回归 | 无新测试——`S3StateMachineTests` **22 项**、`IC133S3BehaviorTests` **9 项**原样通过（#265 日志逐条读数，与卡给的 22／9 精确相符） | **passed** ① |
| 4 | 目录无孤儿 key、无缺 key | `testIC136A_DetailKindKeysRemovedFromCatalogAndSource`（目录与产品源码双向扫该前缀）＋ `testIC134D_EveryS3KeyResolvesInCatalog`（剩余 19 键逐条可解析）＋ `selfcheck.ps1` 全局一致性 | **passed** ① |

## 子项 B：KB 级体积写法（提交 `6f08eee`）

### 改动

`Core/S3StateMachine.swift` **仅** `DecimalVolumeFormatter`（diff 的两个 hunk 都落在
该 `enum` 的文档注释与函数体内 ①）：

| 处置 | 成员 |
|---|---|
| 新增 | `private static let bytesPerTenthOfMegabyte: Int64 = 100_000` |
| 改动 | `string(forByteCount:)`——新增 `< 1 MB` 分支：`(byteCount + 半个十分位) / 十分位` 整除取四舍五入，再 `max(1, …)` 抬底 |

整数运算，不引入浮点；渲染沿用 GB 档同一套「十分位 → x.y」写法。
`≥ 1 MB` 与 `≥ 1 GB` 两支一字未动。

**硬编码扫描器未改**：豁免规则按「`S3StateMachine.swift` 内、以 ` MB`／` GB` 结尾」
匹配（`scan-hardcoded-user-visible-strings.ps1:156`），新行自动落在豁免内——
实测规格锁定格式豁免由 5 条增至 6 条，扫描器退出码仍为 0 ①。

### 断言 5～6 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 5 | 档位表 12 个取值 | `testIC136B_ByteCountTableFollowsRoundedSubMegabyteTier` | **passed** ①，12 行逐值比对，与卡内表逐字相同 |
| 6 | 三处同一 formatter，无第二个 MB 换算实现 | `testIC136B_SingleFormatterServesS3CellBarAndS5`（S3View 调用点 = 2、S5View = 1、声明点 = 1；两个视图内无 ` MB"`／` GB"` 字面量、无 `1_000_000`） | **passed** ① |

既有断言按新口径改期望值 **2 处**（详见「卡内前提与实测的出入」第 1 条）：

| 文件 | 用例 | 旧 → 新 |
|---|---|---|
| `VolumeFormattingTests.swift` | `testZeroBytesDisplaysAsZeroDecimalMegabytes` | `0 MB` → `0.1 MB` |
| `S2CalibrationHarnessTests.swift` | `testIC099bP1SingleAssetTierDoesNotChangeAggregateTier` | `0 MB` → `0.3 MB`（324 846 字节） |

后者同一用例里 S2 单张口径的 `324 KB` 与 `2.4 MB` 未动——「两套口径互不影响」
这条结论照旧成立，且现在两套在同一字节数下给出 `324 KB` 与 `0.3 MB`，
仍是各自档位。

## 子项 C：S2 中央指示改双色固定（提交 `f5c5e6e`）

### 改动函数与删除成员

`Features/S2/S2View.swift` **仅** `S2CenterIndicatorView`：7 个 hunk，
逐个核对落点均在该 `struct` 内（首个 hunk 是紧贴 struct 之上的类型文档注释，
`git diff` 的 hunk 头把上一个声明名带出来是它的就近启发式，不是越界）①。

| 处置 | 成员 |
|---|---|
| 删除 | `@Environment(\.colorScheme) private var colorScheme` |
| 删除 | `static func resolvedForeground(for:)` |
| 删除 | `private var glassContentForeground` |
| 删除 | `static func resolvedSeparator(for:)` |
| 删除 | `private var glassContentSeparator` |
| 新增 | `static let backgroundColor = S2PendingDeletionMark.circleColor` |
| 新增 | `static let foregroundColor = S2PendingDeletionMark.symbolColor` |
| 新增 | `static let separatorColor = Color.white.opacity(0.3)` |
| 改名 | `private func glassCircle(systemName:)` → `private func solidCircle(systemName:)` |
| 改动 | `var body`——撤回钮前景改 `Self.foregroundColor` |
| 改动 | `private var content`——三形态的底改 `Circle()`／`Capsule().fill(Self.backgroundColor)`，前景改 `Self.foregroundColor`，分隔线改 `Self.separatorColor` |

删除的四个成员**全仓零其他消费者**（删前引用仅在本 struct 与四条 IC-123 测试内，
实测删后全仓 0 ①）。

**未动**：`showsUndoControl(for:)`、`separator(color:)`（落笔机制与几何一行未改）、
`containerHeight`（46）、`horizontalPadding`（12）、`allowsHitTesting(false)` 与撤回钮
的 overlay 结构、`S2CenterIndicatorResolver` 全部成员、`S2PendingDeletionMark` 本身、
chrome 与 chrome 前景（决策 42 不动）、`s2ChromeGlassBackground` 本体（其余 3 个
调用点照旧）。

### 断言 7～9 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 7 | 三形态底与前景为固定色；底引用同源常量；两 scheme 解析逐通道相同 | `testIC123AIndicatorForegroundIsResolvedPerColorScheme`（改写）——断言 `backgroundColor == S2PendingDeletionMark.circleColor`、`foregroundColor == S2PendingDeletionMark.symbolColor == .white`，三个色在 `.light`／`.dark` 两 trait 下 `getWhite` 逐通道相等，底为黑且 alpha == `circleOpacity` | **passed** ① |
| 8 | 四条 IC-123 测试改写；`testIC113C…` 原样通过 | `testIC123AIndicatorForegroundIsResolvedPerColorScheme`、`testIC123AIndicatorGlassContentFollowsInPlaceAppearanceSwitch`、`testIC123AppendixIndicatorSeparatorIsResolvedPerColorScheme`、`testIC123AppendixIndicatorSeparatorLineDrawsWithGivenColor`；`testIC113CHintAvoidsCenterIndicatorOnStepFour` 未动 | 五条全 **passed** ① |
| 9 | 解析规则／显隐／时长回归；出厂值零改动 | `testIC113BTransitionParametersMatchCanvas`、`testIC113BShowsExactlyOneStateAtATime`、`testIC113BHiddenInterfaceShowsNothing`、`testIC113BOnlyUndoControlIsHittable` 四条原样通过；`S2Calibration.swift` 不在 diff 中，`schemaVersion` 仍 **7** | **passed** ① |

**断言 8 的「原断言取反」具体怎么取的**（避免只改文案不改语义）：

| 原断言 | 改写后 |
|---|---|
| 前景两态不同色（浅色黑、深色白） | 前景两态**同色**，且为不透明白 |
| 原位切外观：浅色下近黑像素 > 20、深色下 = 0 | 原位切外观：三次采样的暗像素数（阈值 200）**完全相等**且 > 0；近黑像素（阈值 24）**三态皆为 0** |
| 分隔色与系统 `UIColor.separator` 两态同值、且两态应不同 | 分隔色与系统分隔色**脱钩**，两态同为白 30%；仍取系统分隔色两态不同作**对照断言** |
| 分隔线落笔机制（`hidden()` + `overlay`） | 机制断言保留（几何未动），另加「产品交给它的固定色不是全透明」 |

**夹具边界（如实标注）**：CI 模拟器已是 iOS 26.2，但「白底照片上的实际观感」
夹具给不出——三条形态压在真实照片上的可读性由 **H61 第 1 项**兜底，
执行端不代为下结论。

## 闸门逐条结论

### G761（diff 限于白名单）：**通过** ①

`fc2bc77..ad41504` 共 **10 个文件**，逐个对照白名单：

| 文件 | 白名单条目 | 落点核对 |
|---|---|---|
| `Features/S3/S3View.swift` | A | 见上表，只删明细与 chevron；分行与其余版式未动 |
| `Services/AssetSizeScanner.swift` | A | 整文件回到 `39bade7` 形态，逐字节相同 |
| `App/CleanupCoordinator.swift` | A | 与 `39bade7` 的差异只剩 IC-134 F 四处，即只碰点名处 |
| `Core/S3StateMachine.swift` | B（仅 `DecimalVolumeFormatter`） | 两个 hunk 均在该 enum 内 |
| `Features/S2/S2View.swift` | C（仅 `S2CenterIndicatorView` 及其私有 helper） | 7 个 hunk 均在该 struct 内 |
| `Localizable.xcstrings` | A 删四键 | 只删 4 键，B／C 无文案变更 |
| `PhotoCleanupMVETests/IC134S3VisualTests.swift` | 测试增删改 | A |
| `PhotoCleanupMVETests/VolumeFormattingTests.swift` | 测试增删改 | B |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 测试增删改 | B（一处期望值） |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | 测试增删改 | C |

**`PhotoCleanupMVE.xcodeproj/project.pbxproj` 未改**——本卡没有新增测试文件
（三子项的新断言分别落进各自主题已登记的测试文件），因此不触发 pbxproj 登记，
也就不存在 IC-134 那种对象 id 撞号风险。

### G762（S1／S4／S5 零改动；S2 只有中央指示；版本号；冻结链）：**通过** ①

- diff 文件集合中**无任何** `Features/S1`／`Features/S4`／`Features/S5`／
  `Core/S1`／`Core/S4`／`Core/S5` 路径（实测 grep 命中 0）
- S2 侧只有 `S2View.swift` 的 `S2CenterIndicatorView`；`S2Calibration.swift` 不在
  diff 中，`S2CalibrationConfiguration.schemaVersion` 仍为 **7**
  （`Features/S2/S2Calibration.swift:118`）
- 出厂值集合未变，无需递增版本号
- 冻结三链与探针／保留分支（合并前后两次实测均未变）：

| 分支 | tip | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 未变 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 未变 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 未变 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |
| `feature/ic-122-ios26-simulator` | `e7c02ab` | 未动 |
| `feature/ic-134-s345-visual` | `54ac69e` | 未动 |

### G763（子项侧 CI 绿 + 九条断言逐条核对 + 项数对账）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#265**（run id `34150622370`，attempt 1） |
| 被测提交 | `ea96a74b3ef120b3490b464a96a293970e885845` |
| 触发 | `push`，分支 `feature/ic-136-h60-followups` |
| job | `101831973744`，conclusion=**success**，18:11:33Z→18:18:02Z，10 个 step 全 success |
| XCTest | **Executed 676 tests, with 0 failures (0 unexpected) in 50.455 (91.878) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 「XCTest 执行摘要」notice | **在位**（IC-125 哨兵通过，676 > 0） |
| 真实退出码 | **0**（`exit "$test_status"` 原样退出；全日志无「Process completed with exit code」非零行；`##[error]` 0 条、`##[warning]` 0 条） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| 工具链 | Xcode 26.3 |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，**1272446 字节**，SHA-256 `cbf52c67dfab8b18d627470832b9f39d716525826935a0255eceacb5031d426e` |
| 产物 | `PhotoCleanupMVE-unsigned-ea96a74b3ef1`，zip 1272616 字节 |

**项数对账（IC-134 #262 教训，逐 suite 读日志而不是只看总数）**：

| suite | 基线 | 本卡后 | 差 | 缘由 |
|---|---|---|---|---|
| `IC134S3VisualTests` | 14 | **14** | 0 | −3（IC-134 C 三条删除）+3（IC-136 A 三条新增） |
| `VolumeFormattingTests` | 6 | **8** | +2 | B 新增两条 |
| `S2ActionBarWiringTests` | 65 | **65** | 0 | C 四条**原地改写**，不增减 |
| `S2CalibrationHarnessTests` | 224 | **224** | 0 | B 只改一处期望值 |
| 其余 suite | — | — | 0 | 未触碰 |
| **合计** | **674** | **676** | **+2** | 与 CI 读数逐字相符 |

删除的三条在 #265 日志中**零出现**（逐个 grep，各 0 次）①：

- `testIC134C_ResourceKindMappingAndBreakdownSumInvariant`
- `testIC134C_DetailExpansionKeepsAtMostOneRow`
- `testIC134C_DetailTextComesFromCatalogAndFormatter`

九条断言对应的测试函数**逐条在日志里查到 `passed`**（16 个函数名逐个核对，
含改写的四条与必须原样通过的五条）①，无一条是「写了但没跑」。

CI 预算 3 次 **用 1 次**（主跑即绿，2 次修未动用）。

### G764（合并前置）：**通过** ①

- G761～G763 全满足（见上）
- 工作树净：`git status --porcelain` 空
- `main` 未被他人推进：`git fetch` 后 `origin/main` 仍为 `fc2bc77c7eb…`
- 合并：`git merge --no-ff feature/ic-136-h60-followups`，
  输出 `Merge made by the 'ort' strategy.`，**零冲突**
- 合并提交 **`ad41504`** / `ad4150488ed38a617192ffa237dc986470f77a75`
  - parent1 `fc2bc77c7eb80671ff630c7567e7b445b4df2988`（原 `main`）
  - parent2 `ea96a74b3ef120b3490b464a96a293970e885845`（分支 tip）
  - 合并树对象 `da2f8f16556e69a0554c4a8daa5a5d09c609633c` 与分支 tip 树对象**相同**，
    `git diff ad41504 ea96a74` 输出为空——合并未引入任何自身内容
- 推送：`git push origin main` 退出码 0，报文 **`fc2bc77..ad41504  main -> main`**
  （两点记法，非强推）
- 未 rebase、未 amend、未强推：`git reflog main` 顶部为 merge 条目，
  其下 `fc2bc77` 原样保留

### G765（合并后 `main` 自动运行）：**通过（绿）** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#266**（run id `34151262768`，attempt 1） |
| 被测提交 | `ad4150488ed38a617192ffa237dc986470f77a75`（合并提交） |
| 触发 | `push`，分支 `main` |
| job | `101833869077`，conclusion=**success**，18:21:05Z→18:26:55Z，10 个 step 全 success |
| XCTest | **Executed 676 tests, with 0 failures (0 unexpected) in 58.688 (69.675) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 「XCTest 执行摘要」notice | 在位；`##[notice]` 2 条、`##[error]` 0 条、`##[warning]` 0 条 |
| 真实退出码 | **0** |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`；Xcode 26.3 |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，**1272446 字节**，SHA-256 `b57e178e626d99fdf0afe26c78be37462502998d4c79076ca212c5be4346889a` |
| 产物 | `PhotoCleanupMVE-unsigned-ad4150488ed3`，zip 1272616 字节 |

IPA 字节数与 #265 完全相同（同为 1272446），SHA-256 不同——与「IPA 归档不可复现」
的既往实证一致（②既往样本），同时反向印证合并未改变任何产品代码。

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | 目录条目 **206**；用户可见硬编码残留 0；目录 key 与产品源码引用一致；规格锁定格式豁免由 5 增至 **6**（新增的 `< 1 MB` 那行）；结构门禁与 ≥ 189 项测试数量门禁通过 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0 |
| `git diff --check`（工作树） | **0** | — |
| `git diff --check fc2bc77..ad41504` | **0** | 合并范围内无空白错误 |

## 卡内前提与实测的出入（执行纪律第 3 条：不硬套、不凑逻辑）

### 一、既有 formatter 断言不在卡说的两个文件里（①源码与日志可核验）

卡内「定位坐标 B」写：**「既有 formatter 断言（`S3StateMachineTests` 与
`IC134S4S5VisualTests` 中引用 `DecimalVolumeFormatter` 的用例）按新口径改期望值」**。

实测全仓引用点分布如下：

| 文件 | 引用形式 | 是否需要改期望值 |
|---|---|---|
| `VolumeFormattingTests.swift` | **写死字符串期望值** 6 处 | **是**——`0 MB` → `0.1 MB` 一处 |
| `S2CalibrationHarnessTests.swift` | **写死字符串期望值** 2 处 | **是**——`0 MB` → `0.3 MB` 一处 |
| `IC134S3VisualTests.swift` | 期望值即 `DecimalVolumeFormatter.string(...)` 本身（自引用） | 否，自动跟随 |
| `IC134S4S5VisualTests.swift` | 同上，自引用；且取值均 ≥ 1 MB | 否 |
| `S3StateMachineTests.swift` | **完全不引用** `DecimalVolumeFormatter` | 否 |

即：卡点名的两个文件一个不需要改、一个根本没有该引用；真正需要改的两个文件卡未
点名。两者都在白名单 `PhotoCleanupMVETests/**` 之内，故我按**实际位置**施工，
未去 `S3StateMachineTests` 里制造一个不存在的断言来凑卡。改动的两处均已在上文
子项 B 列表登记。

### 二、断言 9 点名的 `centerIndicatorTransitionMs` 全仓不存在（①）

卡内断言 9 写「`centerIndicatorTransitionMs` 等出厂值零改动（`S2Calibration.swift`
不在 diff 中）」。实测：

- `centerIndicatorTransitionMs` **全仓零匹配**（含产品与测试）
- 实际承载这些取值的是 `S2CenterIndicatorResolver` 的四个常量，
  **在 `S2View.swift` 里，从来不在 `S2Calibration.swift`**：
  `transitionSeconds = 0.2`、`hiddenScale = 0.9`、
  `removedNoticeSeconds = 1.2`、`albumIndicatorDelaySeconds = 0.42`
- 这四个常量**均不在本卡 diff 中**（逐个 grep diff 命中 0），
  且 `testIC113BTransitionParametersMatchCanvas` 原样通过并逐值断言了前两个

断言 9 的**实质**（时长与缩放零改动）成立，我按实质核验并给出上述证据；
但「出厂值」「`S2Calibration.swift` 不在 diff 中」这两个措辞对这四个常量不适用——
它们本就不是标定配置里的出厂值。这一条请决策会话在写下一张卡时更正坐标。

## 人工判定项（H61，保留给 Lynn 真机验证，执行端不代为下结论）

1. **S2 深色模式翻到白底照片（白墙、雪、文档）上滑标记**：中央「已标记」浮窗
   黑底白图标是否清晰可读；浅色模式翻到黑底照片同样；加入相簿胶囊与撤回短提示
   同看。——夹具只能证明色值固定与渲染不随外观变化，**压在真实照片上的观感
   给不出**，保留给真机。
2. **S3 里几百 KB 的照片体积标签显示「0.x MB」而非「0 MB」**；一张 1～2 MB 的
   照片显示整数 MB。——夹具已钉住纯函数档位表，**端到端的真实 `PHAsset` 字节数
   给不出**，保留给真机。
3. **S3 体积标签不再有 ▾，点它没反应。**——夹具能证明模型无该字段、视图不再是
   `Button`，**真机触摸行为**保留给 Lynn。

## 发现但未处理的问题（按纪律只报告不修）

1. **`S3VolumeDetailMetrics` 名不副实**（①）。撤销后该容器只剩 `pairSpacing`，
   而它唯一的消费者在**操作条扫描行**（`S3View.swift` 内「转圈 ↔ 文案」的间距），
   与「体积明细」再无关系。删掉容器会连带改到 D 的版式；改名或把该常量迁进
   `S3ActionBarMetrics` 属卡外的登记制变更。**按纪律只登记不修**，请决策会话
   在后续卡里决定是改名还是迁移。
2. **两个测试函数名已过时**（①）：
   - `testIC134B_CellBadgeModelCoversFavoriteVolumeTextAndChevron`——chevron 段已删，
     名字里还留着 `AndChevron`
   - `testZeroBytesDisplaysAsZeroDecimalMegabytes`——现在断言的是 `0.1 MB`，
     名字里的 `Zero…Megabytes` 已不准

   卡对前者写的是「去掉 chevron 段」、对后者写的是「按新口径改期望值」，
   都没写改名；且卡的定位坐标是按现名给的，改名会让坐标对不上。故**保留原名**，
   在此登记。
3. **`S3CellBadgeMetrics.volumeCornerRadius` 是死常量**（①）。它由 IC-134 引入
   （`39bade7` 上不存在该成员），引入时就无人引用——角标底走的是 `Capsule()`。
   本卡的删除清单不含它，未动。
4. **硬编码扫描器的豁免理由文案已部分过时**（①）。
   `Scripts/scan-hardcoded-user-visible-strings.ps1:165` 的理由写「十进制 MB/GB
   **向下截断**由规格锁定」，而 `S3StateMachine.swift:49` 那行现在是**四舍五入**分支。
   该文件**不在本卡白名单**，未改；豁免的匹配规则按文件名 + 单位后缀，功能不受影响。
5. **`AssetResourceKind` 的删除是我的判断，卡未点名**（②）。断言 2 的符号清单里
   没有它，但删掉拆分项后它全仓零消费者，留着即为死代码（卡内 A 的定案写明
   「连同其存储一并删除——不留死代码」）。删前引用 4 处、删后 0 处，已实测。
   若决策会话认为它应保留，回退只需恢复该 `enum`。
6. **一处卡未枚举、但不改就会红的测试改动**（①）：
   `testIC134D_EveryS3KeyResolvesInCatalog` 的 key 清单里列着被删的 4 个
   `s3.detail.kind.*`。不删这 4 行，该用例必然失败。已删，属白名单
   `PhotoCleanupMVETests/**` 之内，在此登记以免被当成越界改动。
7. **`separator(color:)` 的文档注释仍引用测试函数名**（①，未处理）。
   该注释写「这一条由 `testIC123AppendixIndicatorSeparatorLineDrawsWithGivenColor`
   钉住」——该测试仍存在且仍钉住这条机制，故注释依然准确，只是产品源码里写死
   测试函数名这个做法本身较脆。未动。
8. **本卡有 4 个提交而不是 3 个，且第 4 个不满足「可单独 cherry-pick」**（①，
   交付物格式第 1 条的偏差，如实登记）。推 CI 前的静态复核抓到两处会编译失败或
   可能失败的写法（`Mirror.Child` 是元组、Swift 无元组 key path；`Double` 与
   `CGFloat` 混进 `XCTAssertEqual(_:_:accuracy:)` 的泛型推导），分属 A 与 C 的测试。
   本卡范围外明列 amend，故未回改前三个提交，单列 `ea96a74`。
   **代价**：`ea96a74` 同时依赖 A 与 C，单独摘出到没有这两个提交的树上不成立；
   `3e091c2`／`6f08eee`／`f5c5e6e` 三个子项提交各自仍可单独 cherry-pick。
   更规范的做法是拆成两个各归子项的修复提交，我在动手时没有这么做。
9. **`Reports/` 与 Markdown 命中 `ci.yml` 的 `paths-ignore`**（①），故本报告提交
   **不触发 CI**，为预期行为（CLAUDE.md 第五节）。G765 指向的 #266 验证的是产品
   代码所在的合并提交 `ad41504`。
