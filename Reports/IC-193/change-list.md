# IC-193 变更清单

- 任务标识：`IC-20261009-193-v1-deck`（S1 重设计批 ③c＋③d：「逐张整理」V1 卡片叠与年页标题区；有界面变化）
- 基线：`main` = `387efda74c0873333186094905bafc3e07b24018`；分支 `feature/ic-193-v1-deck`；合并提交 `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76`。

## 一、提交（各自独立、按卡顺序 A → B）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `eef0a70dcd64ee48febab156ba5a3ee94ac4ca19` | V1 卡片叠与年页标题区、`S1View` 两处接线、目录 +6／−1、`IC178`／`IC192` 两个既有测试随改（6 个文件） | 可单独摘 |
| B | `01aa3e618b62415689ca22f9ca8efc44dc0bf49a` | 新测试 `IC193V1DeckTests` 四条 + pbx 测试登记（2 个文件） | 只能 A→B |
| 合并 | `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76` | `merge(IC-193): 「逐张整理」V1 卡片叠（年卡、相册卡、年页月卡同一套）与年页标题区——收起一行／恰一张展开、首页同一 spring、一只封面不重取；旧卡口径退役` | — |

## 二、逐文件（白名单 8 路径，`git diff --name-only 387efda74c0873333186094905bafc3e07b24018..01aa3e618b62415689ca22f9ca8efc44dc0bf49a` 恰 8 行；增删行取自 `git diff --numstat`，合计 1281 增 536 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | B | 4 | 0 | `IC193V1DeckTests.swift` 四行（fileRef `100000000000000000000095`、buildFile `200000000000000000000092`、测试组 children、测试源码阶段） |
| `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | A | 624 | 242 | 整文件重写（838 行）：`S1DeckMetrics` 旧五十值整族换成 V1 登记值 98 个（`static let`，含两处字面色 `#080A09` 收起压暗、`#141615` 占比胶囊底）；`S1DeckSymbol` 退 `done`、留 `back`／`organizeAll`；`S1DeckCardKind` 保留；新 `S1DeckOpenSlot`（`.list`／`.yearPage`）；`S1DeckCardPresentation` 退 `step`／`titleFontSize`／`showsMonthCount`／旧 `cardHeight`／旧 `stackHeight`，新增 `visibleHeight`／`cardHeight(index:count:isOpen:)`／`openIndex`／`offset`／`stackHeight(count:openIndex:)`／`coverOffset(isOpen:)`／`stripScrimRowLocation`／`showsNewPill`／`seenText`／`openSubtitle`／`actionTitle`／`yearSummary`／`expandAnimation`／`openContentTransition`，保留 `seenPercent`／`isComplete`／`opensYearPage`／`showsPendingPill`；`S1DeckProgressBar` 取值换 V1；新 `S1DeckSeenRing`（已看小圆环）；`S1DeckCardView` 改为整卡一个按钮、一只 `S0DeckCoverView`（卡宽 × `openCardHeight`、`.id(coverAssetID)`、不挂 `.id(isOpen)`、收起上移 `coverOffset`）+ 收起行／展开内容层；`S1DeckStack` 带 `openIndex`；`S1DeckListView` 改为 `@ObservedObject var openCards: S1OpenCardState` + `slot` + `onOpen`／`onEnter` 两只回调 |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | A | 13 | 4 | 仅 `rangeList`（给 `S1DeckListView` 传 `openCards: machine.openCards`、`slot: .list`，`onTap` 换 `onOpen`（`_ = machine.openListCard(row.id)`）／`onEnter`（原进年页或 S2 的判断）两只回调）与年页构造（`S1YearPageView` 加 `openCards: machine.openCards` 与 `onOpenMonth`（`_ = machine.openYearPageCard(row.id)`））及两处注释；玻璃 helper、徽标层、四态占位、页头接线逐字节不变；`S1ChromeForeground.` 17、`S0DeckMetrics.` 7、`enterRange(` 4 不变 |
| `PhotoCleanupMVE/Features/S1/S1YearPageView.swift` | A | 94 | 88 | 整文件重写（163 行）：V1 标题区（`ZStack(alignment: .topLeading)` 三段按距顶排底缘 12／92／116 落位，块高 142：大号年份、「X GB」+「占全部 N%」（体积或占比未知整行「统计中」）、「整理整年」维度胶囊同式按钮、汇总行、年进度条）；月卡叠改走同一只 `S1DeckListView`（`slot: .yearPage`）；新增构造形参 `openCards`（在 `basketCount` 之后）、`onOpenMonth`（在 `onEnterMonth` 之前）；顶排（返回 + 待删篮入口）照旧钉在页面上方；退 `S1DeckStack` 直接引用、`GeometryReader` |
| `PhotoCleanupMVE/Localizable.xcstrings` | A | 59 | 4 | +6 键：`s1.deck.new`「新增 {count}」、`s1.deck.new.open`「新增 {count} 张」、`s1.deck.share`「占 {percent}%」、`s1.deck.action.yearPage`「去清理」、`s1.deck.action.organize`「去整理」、`s1.yearPage.share`「占全部 {percent}%」；−1 键：`s1.yearPage.summary`；284 → 289；`s0.` 41 不变 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | A | 5 | 196 | 整删 `testIC178A`／`testIC178C`／`testIC178E`；`testIC178D` 精简（删两张新文件计数表与 key 检查，移入新测试 D）；删 `catalogPath`／`newKeyValues`；头注释改写 |
| `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | A | 3 | 2 | `testIC192D` 的 `S1DeckListView` 切片：叠高调用换签名（`stackHeight(count: rows.count, openIndex: openIndex)`）、`stackBottomPadding` 1 → 0 |
| `PhotoCleanupMVETests/IC193V1DeckTests.swift` | B | 479 | 0 | 新文件：四条新测试 |

## 三、新增符号与行为变化

- **`S1DeckListView`（重写）**：卡叠本体，列表页一级范围与年页月卡同用；自己观察 `S1OpenCardState`（`@ObservedObject`，槽位 `.list`／`.yearPage` 决定读 `listRangeID` 还是 `yearPageRangeID`），点卡只重画卡叠、不让观察状态机的整页重算（IC-191 设计）。点收起的卡 → `withAnimation(S1DeckCardPresentation.expandAnimation)` 里调 `onOpen`（`openListCard`／`openYearPageCard`，守卫在状态机）；点展开的卡 → `onEnter`（有月范围的年卡进年页、其余进 S2）。滚动仍由页面那只 `ScrollView` 承担，本视图按 `stackHeight(count:openIndex:)` 占位。
- **`S1DeckCardView`（重写）**：整卡一个按钮，命中区 = 圆角矩形（28），后画的卡 `zIndex` 高。封面一只 `S0DeckCoverView`、尺寸恒为卡宽 × `openCardHeight`（260）、其下垫 `S0DeckMetrics.cardBase`，保留 `.id(coverAssetID)`、**不挂 `.id(isOpen)`**（展开收起同一视图身份、不重新取图）；收起时封面上移 `coverOffset(isOpen: false)` = −78 露出居中带，展开归零，随 spring 移动。收起行：已看小圆环 · 名（600 字重、最先压缩）· 「待删 N」「新增 N」胶囊 · 占比 · GB（`S0ByteCountText` 拆值与单位，nil 写「统计中」）· 箭头。展开内容：左上「占 N%」与胶囊、左下名／大号 GB／副文／已看条、右下「去清理 ›」或「去整理 ›」标签（不是另一只按钮）。展开内容过渡 = 淡入 + 上升 `S0DeckMetrics.expandContentRise`。
- **卡几何**：可见高 展开 226／收起 70；卡高 = 可见高 +（末卡 320，其余 34）；第 i 张上偏移 = 前 i 张可见高之和；叠高 = 全部可见高之和 + 320（空叠 0）。旧 `stackBottomPadding` 24 退役（末卡延伸即底部留白）。
- **文案拼接**：展开卡副文与年页汇总行由既有 key 拼接（`s1.deck.year.subtitle`／`s1.range.total_count` + `s1.deck.seen`／`s1.deck.done` + `s1.deck.pending` + `s1.deck.new`，分隔「 · 」）；汇总行的待删、新增两段各自为零不显示。
- **年页标题区**：大号年份 40／900、「X GB」700 + 左距 8 的「占全部 N%」500（两段之间无「·」）、「整理整年」（高 40、圆角 16、胶囊值引 `S1PageHeaderMetrics`）、汇总行、年进度条；块高 142，不依赖字体行高。
- **行为变化（用户可见）**：列表页与年页的卡片叠整体换成 V1：收起时一行、恰一张展开，点收起的卡展开它（一次弹簧）、点展开卡进入；旧年卡的整卡点击即进年页行为随之改变（先展开、再点才进）。观感待 H101 九条真机判定。

## 四、没有改动的东西（范围外，逐项核过）

- 状态机 `S1StateMachine.swift`（展开态与年页身份 IC-191 已就绪）、`S1OpenCardState`、协调器 `CleanupCoordinator.swift`、App 入口、页头 `S1PageHeader.swift`、S0 各页与 `S0DeckCoverView`、扫描服务、数据源协议与桩、`Scripts/`、`.github/` 一字未动（`git diff --name-only` 8 路径，不含它们）。
- `S1View.swift` 列表与年页接线之外的一切（玻璃 helper 与徽标层、四态占位、页头接线）逐字节不变（`IC156CategoryPageTests`、`IC171CategoryPageTrioTests`、`IC172GlassAlwaysDarkTests`、`IC177UnifiedBackgroundTests`、`IC183RetireRenderChainTests`、`IC184RetireCaliberEnumsTests` 在 CI 全绿）。
- 白名单之外的测试文件、SPEC 与 Decision_log 未动。

## 五、占位值登记

- 卡内暂登（规格欠账，见自验报告第十三节）：`S1DeckMetrics` V1 登记值 98 个（取值出处 R3 画布与规格 2d 段）及其推导；「统计中」字号取值；年页体积行两段写法。
- `S2CalibrationConfiguration.schemaVersion` 仍为 7（本卡不改出厂值）。

## 六、摘取关系

A 单独可摘；B 用到 A 新加的类型与成员（`S1DeckMetrics` V1 值、`S1DeckCardPresentation` 新函数、`S1DeckOpenSlot`）与目录 key，只能 A→B（卡面声明：B 单独文本可摘但编译依赖 A）。克隆实测（`git clone --no-hardlinks`，`git -C <克隆>`）：A 单独 `cherry-pick -x` 退出码 0、树 `6107e11aeb6d297e21a783cc35d957c1b23e02f4`；A→B 连续退出码 0、树 `05103758f075e9aafcf7a9272fd729534b790166`（= 合并提交的树）。只证文本无冲突，绿由 CI 证。

## 七、CI 与产物

| 项 | 分支 #390 | 合并后 `main` #391 |
|---|---|---|
| run id | `37950521036` | `37952568535` |
| 被测提交 | `01aa3e618b62415689ca22f9ca8efc44dc0bf49a` | `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76` |
| 结果 | 绿，972 项 0 失败，真实退出码 0，`OS:26.2, name:iPhone 16` | 绿，972 项 0 失败，真实退出码 0，`OS:26.2, name:iPhone 16` |
| IPA | 2030459 字节，SHA-256 `1bfbec8c6926c1bfe319ca4ea8ea5759a79710dbe08a027637c29d83ee781780` | 2030459 字节，SHA-256 `33299dd5a2cf6765ddfc9ce9164c1dc988432d7d852dc589b7fc457274513f17` |
| 分段耗时 | 模拟器启动 97 s；xcodebuild test 399 s；总 497 s | 模拟器启动 104 s；xcodebuild test 425 s；总 531 s |
| artifact | `PhotoCleanupMVE-unsigned-01aa3e618b62`，id `11626520907`，有效期至 2027-01-07T15:16:43Z | `PhotoCleanupMVE-unsigned-52e977e1af5c`，id `11627960149`，有效期至 2027-01-07T15:33:02Z |
| 四条 `testIC193*` 耗时 | A 0.002 s；B 0.015 s；C 0.002 s；D 0.218 s | A 0.002 s；B 0.013 s；C 0.003 s；D 0.217 s |

项数对账：`971 − 3 + 4 = 972`。

## 八、核验结果（`git cat-file -e`）

docs 提交前对本报告与 `self-check.md` 内出现的全部 40 位 SHA（22 个，含提交、树与 blob）逐个跑 `git cat-file -t <sha>` 取类型、再 `git cat-file -e <sha>^{<类型>}`，结果如下（22／22 退出码 0，缺失 0）：

| SHA | 类型 | `cat-file -e <sha>^{类型}` 退出码 |
|---|---|---|
| `00f117f0189155b81bc10d1683e3a014d0b55dfb` | blob | 0 |
| `01aa3e618b62415689ca22f9ca8efc44dc0bf49a` | commit | 0 |
| `0402ea5fb043101a9ca38f296293399827a6422a` | blob | 0 |
| `05103758f075e9aafcf7a9272fd729534b790166` | tree | 0 |
| `09caecb79813ae1bafa9ac2608bb353d4575aaa0` | blob | 0 |
| `0cdb6c0df6eda43e2ff4f4d91cc63ebcd4bf6d1b` | blob | 0 |
| `387efda74c0873333186094905bafc3e07b24018` | commit | 0 |
| `414f05a9bb883551185f2da78cd0b2569f8992c1` | blob | 0 |
| `45f115fe4bb6fd4a5398f9def3c89e7bfde7cca2` | blob | 0 |
| `4d0cc41734542555bfbb0171c43eb338c72db093` | blob | 0 |
| `52e977e1af5c2ca7ccd98d4d088b8e8501cb6b76` | commit | 0 |
| `5eb8dccd513ca3e1f8318b06b68e6f5b0de22280` | blob | 0 |
| `6107e11aeb6d297e21a783cc35d957c1b23e02f4` | tree | 0 |
| `855e9d34764d1465f242d68a6a5cae7b1825c4b2` | blob | 0 |
| `a5ffe00d94eb1dc7c28581679a82774e3ebd0ba4` | blob | 0 |
| `b8261fa8d28014290f4852aa6ae3155debc3917c` | blob | 0 |
| `ba9ac874cd5f89ee4481271731151a1120c7ca76` | blob | 0 |
| `bcc865086086041815dbfca19a2117b0d93cf32e` | blob | 0 |
| `c26011857d2c7788a2300dc12754fe61cc8bf0e4` | blob | 0 |
| `d8c10e312f700ac35defb5c8d7efecc363b2785b` | commit | 0 |
| `dad2c343364f5e89a32851c10408352aee3b4606` | blob | 0 |
| `eef0a70dcd64ee48febab156ba5a3ee94ac4ca19` | commit | 0 |
