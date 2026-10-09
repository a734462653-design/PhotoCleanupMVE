# IC-191 变更清单

- 任务标识：`IC-20261009-191-v1-deck-data`（S1 重设计批 ③a：V1 卡片叠与页头的数据与接线，不做界面）
- 基线：`main` = `618f30e2387fc2618ec7c34b077007d46fcd3c43`；分支 `feature/ic-191-v1-deck-data`；合并提交 `78983887aeaee2a239d07a29bb9efc37f2472056`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `a9aa59a2d11fb72f4dc07c6b33dc29f451e2b5b0` | 体积接线与页头数据（9 个文件） | 可单独摘 |
| B | `0c6524a2c21787eb3b46cbac25b82acac9623055` | 两页展开态（5 个文件） | 只能 A→B |
| C | `6c1ab23716d09651e1e298849bba351bcabf97df` | 新测试 `IC191DeckDataTests` 四条 + pbx 测试登记（2 个文件） | 依赖 A、B |
| 合并 | `78983887aeaee2a239d07a29bb9efc37f2472056` | `merge(IC-191): V1 卡片叠与页头的数据与接线——字节表读口与刷新、行体积与占比、页头派生、两页展开态` | — |

## 二、逐文件（白名单 12 路径，`git diff --name-only 618f30e2387fc2618ec7c34b077007d46fcd3c43..6c1ab23716d09651e1e298849bba351bcabf97df` 恰 12 行；增删行取自 `git diff --numstat`，合计 691 增 15 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、B、C | 12 | 0 | 三个新文件各四行（fileRef、buildFile、组 children、源码／测试阶段） |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | A | 9 | 1 | `tabContainer` 的 `.onAppear` 里接 `s1Machine.byteCountTableProvider`、接上即刷新一次；既有 `onSnapshotDidChange` 闭包捕获列表加 `weak s1Machine`、末尾追加 `s1Machine?.noteByteCountTableChanged()`（仍只一处赋值） |
| `PhotoCleanupMVE/Core/S1HeaderSummary.swift` | A | 59 | 0 | 新文件：页头数据 `S1HeaderSummary`（`totalByteCount`／`seenPercent`／`assetCount`／`topLevelRangeCount`）、`make(...)`、`percent(seen:total:)` |
| `PhotoCleanupMVE/Core/S1OpenCardState.swift` | B | 36 | 0 | 新文件：`S1OpenCardState`（`listRangeID`／`yearPageRangeID`、两个写方法、`resolved(_:among:)`） |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | A、B | 87 | 1 | A：`S1RangeRow` 加 `byteCount`／`sharePercent`、`byteCountTableProvider`、`rangeRows` 每次求值取一次表、`headerSummary`、`noteByteCountTableChanged()`；B：`openCards`、`ranges` 的 `didSet` 改多行（先 `pruneYearPageIfNeeded()` 再 `resolveOpenCards()`）、`presentYearPage` 取年页初值、`dismissYearPage` 清年页、`listCardRangeIDs`／`yearPageCardRangeIDs(of:)`／`openListCard`／`openYearPageCard`／`resolveOpenCards()` |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | B | 4 | 2 | `testIC178D`：`presentedYearRangeID` 5 → 7、`didSet { pruneYearPageIfNeeded() }` 1 → `pruneYearPageIfNeeded()` 2 + `resolveOpenCards()` 2 |
| `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | A、B | 4 | 4 | `testIC184C`：`S1RangeRow` 切片 `let ` 8 → 10（A）、`presentedYearRangeID` 5 → 7（B） |
| `PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift` | A | 6 | 3 | `testIC186C`：读口只在服务具体类型上不进协议与桩；App 一项改 `assetByteCountTable` 1、`S1AssetByteCountTable` 0 |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | A | 2 | 2 | `testIC188F`：`seenAssetIDsProvider?() ?? []` 3 → 4 |
| `PhotoCleanupMVETests/IC189NewCountTests.swift` | A | 2 | 1 | `testIC189E`：同上 3 → 4 |
| `PhotoCleanupMVETests/IC190LegacyRetirementTests.swift` | A | 2 | 1 | `testIC190E`：同上 3 → 4 |
| `PhotoCleanupMVETests/IC191DeckDataTests.swift` | C | 468 | 0 | 新文件：四条新测试 |

## 三、新增符号与行为变化

- **`S1StateMachine.byteCountTableProvider: (() -> S1AssetByteCountTable?)?`**：库内资产字节表的读口，由 App 从扫描服务注入；未注入的夹具按 nil。`noteByteCountTableChanged()` 只 `objectWillChange.send()`，不写会话快照、不改状态。
- **`S1RangeRow.byteCount: Int64?`／`sharePercent: Int?`**（夹在 `newAssetCount` 与 `parentRangeID` 之间）：`rangeRows` 每次求值取一次表；没有表或范围里有表外资产为 nil；年体积 = 各月之和、任一月未知则年未知；占比在体积未知时为 nil。
- **`S1StateMachine.headerSummary: S1HeaderSummary`**：`总占用`（表内之和，没有表为 nil）、`页头已看`（按日期维度就绪取年范围资产之并、其余维度取表的键集、取不到为 nil）、副行前段的一级范围资产数与范围数。界面一字不读。
- **`S1StateMachine.openCards: S1OpenCardState`**（`let`，不是 `@Published`）：列表页与年页各一张展开卡的身份，值没变不写；写入只经状态机的 `openListCard(_:)`／`openYearPageCard(_:)`（带守卫）、`presentYearPage`（取年页初值）、`dismissYearPage`（清年页）与 `ranges` 的 `didSet`（按 `OPEN` 规则回落并写实）。不入档、不发会话快照、不触发读取。
- **行为变化**：对用户**不可见**——视图不读新字段；可观察到的只有扫描期多几次不可见的重算（规格欠账 (3)）。`publishSnapshotIfChanged()` 6、`didSet` 4、`setMarked(` 3、`applyPendingDeletionDiff(` 3 不变。

## 四、没有改动的东西（范围外，逐项核过）

- 视图：`S1View.swift`、`S1DeckCards.swift`、`S1YearPageView.swift`、S0 各页一字未动；目录 `Localizable.xcstrings` blob 不变（`check_ic191.py` 的 `catalog blob unchanged` 三段均 PASS）、不加文案 key。
- 协调器 `CleanupCoordinator.swift`、扫描服务、数据源协议 `S0CleanupDataProviding`（IC166 断言 6 钉住的 blob）、桩、`Scripts/`、`.github/` 一字未动；`installS1Session(` 恰 6、`s1Machine = machine` 恰 1 仍成立（测试 D 钉住）。
- 白名单之外的测试文件、SPEC 与 Decision_log 未动。

## 五、占位值登记

无新增占位值；`S2CalibrationConfiguration.schemaVersion` 仍为 7（本卡不改出厂值）。

## 六、摘取关系

A 单独可摘；B 的 pbx 四行接在 A 新加的四行之后、IC184C 两处改动相隔不到三行，**只能 A→B**；C 依赖 A、B。克隆实测（`git clone --no-hardlinks`，`git -C <克隆>`）：A 单独 `cherry-pick -x` 退出码 0、树 `cf627b9d7e3892b51ab5975474bd025ec4fc8678`；A→B 连续 0、0、树 `87acbd4d7a93665d7d50b351d71e95bf05a7fb79`；A→B→C 连续 0、0、0、树 `f6affd83e019aae69d2fc44200f5dfa31e0ca779`（= 合并提交的树）；B 单独退出码 1（冲突，与卡面声明一致）。只证文本无冲突，绿由 CI 证。

## 七、CI 与产物

| 项 | 分支 #386 | 合并后 `main` #387 |
|---|---|---|
| run id | `37918785462` | `37920144916` |
| 被测提交 | `6c1ab23716d09651e1e298849bba351bcabf97df` | `78983887aeaee2a239d07a29bb9efc37f2472056` |
| 结果 | 绿，970 项 0 失败，真实退出码 0，`OS:26.2, name:iPhone 16` | 绿，970 项 0 失败，真实退出码 0，`OS:26.2, name:iPhone 16` |
| IPA | 1998911 字节，SHA-256 `2800c198383c2b51c487d740efba730350e7b18a553459a8a6b6d7b0d6080436` | 1998911 字节，SHA-256 `82ec2ec506416befbe6fc7b04fe9e010f5670ff369da0dee2b5d5c623750ede6` |
| 分段耗时 | 模拟器启动 94 s；xcodebuild test 374 s；总 469 s | 模拟器启动 106 s；xcodebuild test 561 s；总 669 s |
| artifact | `PhotoCleanupMVE-unsigned-6c1ab23716d0`，id `11611391727`，至 2027-01-07T10:37:59Z | `PhotoCleanupMVE-unsigned-78983887aeae`，id `11611583395`，至 2027-01-07T10:51:22Z |

项数对账：`966 + 4 = 970`。CI 预算 3 次，用 1 次。

## 八、拷入文件 blob 与清单对读（提交内 blob = 清单值，逐文件；`check_ic191.py` 三段均 PASS）

| 子项 | 仓库路径 | 清单 blob |
|---|---|---|
| A | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `1a732088173928a5cbf918f626bde79081debe6e` |
| A | `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | `b2e74f33f82b436ce5845c2d3ff7345ac080ed5b` |
| A | `PhotoCleanupMVE/Core/S1HeaderSummary.swift` | `12b7cd928318bb7aa9af86376395dc15d91baeba` |
| A | `PhotoCleanupMVE/Core/S1StateMachine.swift` | `075d0914ba4d1a2a8217767136364aba7f08f4ea` |
| A | `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `5d77efb866f5eb4537403c4265aeac0c85152c6f` |
| A | `PhotoCleanupMVETests/IC186RangeVolumeInterfaceTests.swift` | `2266a7e092d65f3b95cf26646796091ffe2d6f6d` |
| A | `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | `c3183deba33c2353c4955bf6287c3a5c09d59975` |
| A | `PhotoCleanupMVETests/IC189NewCountTests.swift` | `124ce680013bb476bdc2aa5c50ab58c1fb2e3efb` |
| A | `PhotoCleanupMVETests/IC190LegacyRetirementTests.swift` | `a09a31c97bde58899583dcbd5637c6eee4914011` |
| B | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `a474b9cfa44bdc8c619dc24661db3aff844a3516` |
| B | `PhotoCleanupMVE/Core/S1OpenCardState.swift` | `20dc6b0a5df240aeefeb4af69608f7e4c0b1dc92` |
| B | `PhotoCleanupMVE/Core/S1StateMachine.swift` | `756660c8ed29bea218c02a032c5ae3510501282f` |
| B | `PhotoCleanupMVETests/IC178DeckListTests.swift` | `db7f7a63c6d54b1a04abb9043d99ef7dcc9326b0` |
| B | `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | `36b8952e54cb0b1254f692134740f44d246b4db3` |
| C | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `ee6960429c947b7d0cd64bdca6cbb55af22c4ea7` |
| C | `PhotoCleanupMVETests/IC191DeckDataTests.swift` | `14fe74ecf58a7f550628c4488113619e70377bd3` |

## 九、新测试 id

| 函数 | 文件 |
|---|---|
| `testIC191A_RowVolumesFollowTheScanTable` | `PhotoCleanupMVETests/IC191DeckDataTests.swift` |
| `testIC191B_HeaderSummaryDerivesTotalSeenAndCounts` | 同上 |
| `testIC191C_OpenCardsFollowTheOpenRule` | 同上 |
| `testIC191D_SourceWiring` | 同上 |

pbxproj 新 id：fileRef `100000000000000000000090`（`S1HeaderSummary.swift`）、`100000000000000000000091`（`S1OpenCardState.swift`）、`100000000000000000000092`（`IC191DeckDataTests.swift`）；buildFile `20000000000000000000008D`、`20000000000000000000008E`、`20000000000000000000008F`。

## 核验结果

对两份报告出现的全部 40 位 SHA（去重后 34 个）逐个跑 `git cat-file -t <sha>` 取类型，再跑 `git cat-file -e <sha>^{<类型>}`；退出码非 0 的个数：**0**。

| SHA | 类型 | `cat-file -e` 退出码 |
|---|---|---|
| `075d0914ba4d1a2a8217767136364aba7f08f4ea` | blob | 0 |
| `07989aca1e0e0f4610e033055be01f0b1f63c40b` | blob | 0 |
| `0c6524a2c21787eb3b46cbac25b82acac9623055` | commit | 0 |
| `124ce680013bb476bdc2aa5c50ab58c1fb2e3efb` | blob | 0 |
| `12b7cd928318bb7aa9af86376395dc15d91baeba` | blob | 0 |
| `13feab7d6d13d2e855ebeb590af209b32326ac66` | blob | 0 |
| `14904de5f6de651e0e6a53fd73f4ed7c991ef234` | blob | 0 |
| `14fe74ecf58a7f550628c4488113619e70377bd3` | blob | 0 |
| `1a732088173928a5cbf918f626bde79081debe6e` | blob | 0 |
| `20dc6b0a5df240aeefeb4af69608f7e4c0b1dc92` | blob | 0 |
| `2266a7e092d65f3b95cf26646796091ffe2d6f6d` | blob | 0 |
| `36b8952e54cb0b1254f692134740f44d246b4db3` | blob | 0 |
| `5d77efb866f5eb4537403c4265aeac0c85152c6f` | blob | 0 |
| `618f30e2387fc2618ec7c34b077007d46fcd3c43` | commit | 0 |
| `6c1ab23716d09651e1e298849bba351bcabf97df` | commit | 0 |
| `6fb64711861ba5d09310e0f11d252b41e21d42fd` | blob | 0 |
| `756660c8ed29bea218c02a032c5ae3510501282f` | blob | 0 |
| `78983887aeaee2a239d07a29bb9efc37f2472056` | commit | 0 |
| `87acbd4d7a93665d7d50b351d71e95bf05a7fb79` | tree | 0 |
| `890044fee1e17d865f694a11ab065bde0219053e` | blob | 0 |
| `8ce8c48a11f6ac9ad249eece4d5ac77833e71218` | commit | 0 |
| `9023acfd2c5a40d1d813a23d4d7fd358140fa0d5` | blob | 0 |
| `a09a31c97bde58899583dcbd5637c6eee4914011` | blob | 0 |
| `a474b9cfa44bdc8c619dc24661db3aff844a3516` | blob | 0 |
| `a9aa59a2d11fb72f4dc07c6b33dc29f451e2b5b0` | commit | 0 |
| `b2e74f33f82b436ce5845c2d3ff7345ac080ed5b` | blob | 0 |
| `c3183deba33c2353c4955bf6287c3a5c09d59975` | blob | 0 |
| `cf627b9d7e3892b51ab5975474bd025ec4fc8678` | tree | 0 |
| `db7f7a63c6d54b1a04abb9043d99ef7dcc9326b0` | blob | 0 |
| `ee16d563bd2ca20987b3af34a57bc154bfa74724` | blob | 0 |
| `ee6960429c947b7d0cd64bdca6cbb55af22c4ea7` | blob | 0 |
| `f0ddd930adcaf1f99b0af1808c925309622be9e4` | blob | 0 |
| `f6affd83e019aae69d2fc44200f5dfa31e0ca779` | tree | 0 |
| `fab23ebaf50bf22c12207ca739b285efbe1a405c` | blob | 0 |
