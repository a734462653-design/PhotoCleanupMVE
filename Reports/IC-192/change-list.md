# IC-192 变更清单

- 任务标识：`IC-20261009-192-v1-header`（S1 重设计批 ③b：「逐张整理」V1 页头 + 系统 `Menu`；有界面变化）
- 基线：`main` = `bb2dee9e1abca32397e2db514eb2c2e084e7095d`；分支 `feature/ic-192-v1-header`；合并提交 `d8c10e312f700ac35defb5c8d7efecc363b2785b`。

## 一、提交（各自独立、按卡顺序 A → B）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `d68c65f923655af8bf4502acfa51c7afb15ec81d` | V1 页头与系统 `Menu`、旧顶排与自绘菜单退役、目录与随改测试（11 个文件） | 可单独摘 |
| B | `c56110df32ea23821d50206891d36a8236966c01` | 新测试 `IC192PageHeaderTests` 四条 + pbx 测试登记（2 个文件） | 只能 A→B |
| 合并 | `d8c10e312f700ac35defb5c8d7efecc363b2785b` | `merge(IC-192): 「逐张整理」V1 页头 + 系统 Menu——行内标题、排序 Menu、待删篮入口与人像圆钮、大数字区、副行、维度胶囊；就绪时整页滚动；旧顶排与自绘菜单退役` | — |

## 二、逐文件（白名单 12 路径，`git diff --name-only bb2dee9e1abca32397e2db514eb2c2e084e7095d..c56110df32ea23821d50206891d36a8236966c01` 恰 12 行；增删行取自 `git diff --numstat`，合计 936 增 714 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | A、B | 8 | 0 | 两个新文件各四行（fileRef、buildFile、组 children、源码／测试阶段）：`S1PageHeader.swift`（`100000000000000000000093`／`200000000000000000000090`）、`IC192PageHeaderTests.swift`（`100000000000000000000094`／`200000000000000000000091`） |
| `PhotoCleanupMVE/Features/S1/S1DeckCards.swift` | A | 12 | 13 | 仅 `S1DeckListView`：去掉自带 `ScrollView`，`GeometryReader` 取宽后按 `S1DeckCardPresentation.stackHeight(count:kind:)` 占位并留底距；注释改写 |
| `PhotoCleanupMVE/Features/S1/S1PageHeader.swift` | A | 410 | 0 | 新文件：`S1PageHeaderMetrics`（41 值 + 两个推导量）、`S1PageHeaderSymbol`、`S1PageHeaderValueMode`、`S1PageHeaderPresentation`、`S1PageHeader` 视图（行内标题、系统 `Menu` + `Picker` 排序钮、`S0BasketEntryView(style: .glass)` 待删篮入口、人像圆钮、大数字区、副行、三只维度胶囊、S1-1 骨架） |
| `PhotoCleanupMVE/Features/S1/S1View.swift` | A | 71 | 512 | `rootPage` 改 `pageContainer { VStack { pageHeader; limitedBannerRow; stateContent } }`（就绪时整页 `ScrollView`）；新 `pageHeader`／`sortOrderBinding`／`openBasket()`／`limitedBannerRow`；`.ready` 分支给卡叠加 `deckTopSpacing`；退役 `chromeColumn`／`chromeBar`／`chromeItems`／`sortButton`／`dimensionCapsule` 及其四个子视图／`trashButton`／`trashBadge`／`menuScrim`／`menuOverlay`／`sortMenu*`／`dimensionMenu*`／`dimensionHintText`／`menuContainer`／`menuSeparator`／`refreshDimensionHints`／`groupingTitle`／`sortTitle`；退役类型 `S1ChromeSubtitle`／`S1ActiveMenu`／`S1MenuStyle`／`S1DimensionMenuHintModel`；`S1ChromeLayout` 三个推导偏移与 `bannerToListSpacing`、`S1ChromeTypography.capsuleChevronPointSize`、`S1LimitedBannerPresentation.listTopOffset` 退役；三个视图 `@State`（`activeMenu`／`albumHintRangeCount`／`unclassifiedHintAssetCount`）退役 |
| `PhotoCleanupMVE/Localizable.xcstrings` | A | 53 | 20 | +8 键（`s1.header.title`／`total_label`／`seen_label`／`subtitle.date`／`subtitle.album`／`basket`／`confirm`、`s1.volume.counting`）、−5 键（`s1.chrome.subtitle_format`、`s1.dimension.accessibility`、三条 `s1.menu.dimension.*`），281 → 284 |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | A | 5 | 118 | 整删三个只测退役符号的函数、`testIC128C_LimitedBannerVisibilityAndListTopOffset` 改名 `testIC128C_LimitedBannerVisibility` 并删偏移半段、`ChromeMetrics` 删偏移恒等式 |
| `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift` | A | 5 | 36 | 删菜单配方探针（三种材质配方 → 两种）；S1 深色覆盖 7 → 5；十三处 → 十一处；切片名单删 `chromeBar`／`menuContainer` |
| `PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift` | A | 5 | 4 | `testIC177C`：S1 元组 28 → 17；`colorScheme, .dark)` 7 → 5；`s1ChromeGlassBackground(` 4 → 3 |
| `PhotoCleanupMVETests/IC178DeckListTests.swift` | A | 9 | 5 | `testIC178D`：计数表 28 → 17、7 → 5、4 → 3；`rootPage` 切片名单换为 `pageHeader`／`limitedBannerRow`／`pageContainer {`，另加旧三名各 0 |
| `PhotoCleanupMVETests/IC183RetireRenderChainTests.swift` | A | 3 | 3 | `testIC183A`：`S1ChromeForeground.` 28 → 17、`s1ChromeGlassBackground(` 4 → 3 |
| `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | A | 3 | 3 | `testIC184B`：同上 28 → 17、4 → 3 |
| `PhotoCleanupMVETests/IC192PageHeaderTests.swift` | B | 352 | 0 | 新文件：四条新测试 |

## 三、新增符号与行为变化

- **`S1PageHeader`（新视图）**：只收值（`state`／`summary: S1HeaderSummary`／`groupingDimension`／`badgeCount`／`chromeModel`）与回调（`sortOrder: Binding<S1SortOrder>`／`onBasket`／`onSelectDimension`／`onOpenAccount`），不认识状态机。顶排一行：行内标题「逐张整理」、排序钮（系统 `Menu { Picker … }`，两项，当前项系统勾选，不加 `.tint`、不加深色覆盖）、待删篮入口（首页同款 `S0BasketEntryView(style: .glass)`）、人像圆钮（照首页先例，回调为空闭包，点了无动作，读屏借 `s0.account.title`）；其下大数字区（`总占用` 大数字 + 右块「已看 N%」，取不到写「统计中」）、副行（前段「N 张 · M 年／个相册」「N 张」；待删篮段「待删篮 N 张 · 去确认」）、三只维度胶囊（选中态、`controlsEnabled` 判可触发）。
- **`S1PageHeaderPresentation`／`S1PageHeaderValueMode`**：四态数值位口径——S1-1 骨架（大数字、已看、副行前段画骨架；副行待删篮段照常，「去确认」按 `trashEnabled` 不可触发）、S1-2／S1-3 照常、S1-4 大数字区与已看位同尺寸透明占位且副行前段不画（待删篮段自左缘起）；顶排件按 `controlsEnabled`／`controlsOpacity`（S1-1 降 40% 不可触发），维度胶囊只按 `controlsEnabled`（不降暗）。
- **`S1View.rootPage`**：就绪时页头、受限条、卡叠同在一个 `ScrollView` 里滚；加载中／空态／失败不滚动，页头之下仍是居中占位。受限提示条位于维度胶囊下方、卡叠上方（上距 14，卡内暂登）。待删篮入口与副行「去确认」同一动作（`openBasket()` → `S1TrashButtonAction.perform`）；排序选择写 `machine.switchSortOrder(to:)`（同值或遮挡由状态机拒收）。
- **`S1DeckListView`**：不再自带 `ScrollView`，按叠高占位；年页（`S1YearPageView`）本卡不动，仍自带滚动与钉住的顶排。
- **行为变化（用户可见）**：「逐张整理」tab 的页头与列表页结构整体换成 V1；旧中胶囊、两只自绘菜单、三条维度提示随之消失；排序改系统菜单；人像圆钮新增但点了无动作。观感待 H100 八条真机判定。

## 四、没有改动的东西（范围外，逐项核过）

- 状态机 `S1StateMachine.swift`、协调器 `CleanupCoordinator.swift`、App 入口、`S1YearPageView.swift`、S0 各页、扫描服务、数据源协议与桩、`Scripts/`、`.github/` 一字未动（`git diff --name-only` 12 路径，不含它们）。
- `S1View.swift` 的玻璃 helper 与徽标层（IC156C／IC171B 切片所在段）逐字节不变（`IC156CategoryPageTests`、`IC171CategoryPageTrioTests` 在 CI 全绿）；四态占位与年页构造未动。
- `S1ChromeBarModel` 字段与 `make` 签名不动（九个测试构造点存活）。
- 白名单之外的测试文件、SPEC 与 Decision_log 未动。

## 五、占位值登记

- 卡内暂登（规格欠账，见自验报告第十三节）：S1-1 骨架 `skeleton*` 七值、受限提示条上距 `bannerTopSpacing` 14。
- `S2CalibrationConfiguration.schemaVersion` 仍为 7（本卡不改出厂值）。

## 六、摘取关系

A 单独可摘；B 用到 A 新加的类型（`S1PageHeaderPresentation` 等）与目录 key，只能 A→B（卡面声明：B 单独文本可摘但编译依赖 A）。克隆实测（`git clone --no-hardlinks`，`git -C <克隆>`）：A 单独 `cherry-pick -x` 退出码 0、树 `f3606d0aef6c00b94f92b8d2e2d3f31aca664f26`；A→B 连续退出码 0、树 `cce7f8c6e3451ddaaa89d3dd89bf396c02c94e7c`（= 合并提交的树）。只证文本无冲突，绿由 CI 证。

## 七、CI 与产物

| 项 | 分支 #388 | 合并后 `main` #389 |
|---|---|---|
| run id | `37934749742` | `37936737759` |
| 被测提交 | `c56110df32ea23821d50206891d36a8236966c01` | `d8c10e312f700ac35defb5c8d7efecc363b2785b` |
| 结果 | 绿，971 项 0 失败，真实退出码 0，`OS:26.2, name:iPhone 16` | 绿，971 项 0 失败，真实退出码 0，`OS:26.2, name:iPhone 16` |
| IPA | 1998525 字节，SHA-256 `57580c9634ef440d4f2e473ed06e14dbc62d2542c44a08385816a045c674216f` | 1998525 字节，SHA-256 `34a7638c615766cf44d2de7a9dd06df917010cd2d308500a3fbfbc09238d330a` |
| 分段耗时 | 模拟器启动 85 s；xcodebuild test 367 s；总 454 s | 模拟器启动 99 s；xcodebuild test 517 s；总 618 s |
| artifact | `PhotoCleanupMVE-unsigned-c56110df32ea`，id `11618077548`，有效期至 2027-01-07T13:08:35Z | `PhotoCleanupMVE-unsigned-d8c10e312f70`，id `11619411238`，有效期至 2027-01-07T13:25:30Z |
| 四条 `testIC192*` 耗时 | A 0.003 s；B 0.001 s；C 0.007 s；D 0.268 s | A 0.006 s；B 0.001 s；C 0.004 s；D 0.383 s |

项数对账：`970 − 3 + 4 = 971`。

## 八、核验结果（`git cat-file -e`）

docs 提交前对本报告与 `self-check.md` 内出现的全部 40 位 SHA（30 个，含提交、树与 blob）逐个跑 `git cat-file -t <sha>` 取类型、再 `git cat-file -e <sha>^{<类型>}`，结果如下（30／30 退出码 0，缺失 0）：

| SHA | 类型 | `cat-file -e <sha>^{类型}` 退出码 |
|---|---|---|
| `09caecb79813ae1bafa9ac2608bb353d4575aaa0` | blob | 0 |
| `13a6c6fe0a2c69ed59124e11a146b1d8ddaf8960` | blob | 0 |
| `36b8952e54cb0b1254f692134740f44d246b4db3` | blob | 0 |
| `45f115fe4bb6fd4a5398f9def3c89e7bfde7cca2` | blob | 0 |
| `4a379bc4f6afca4ff87b32e5c51e1edeab5cdb1d` | blob | 0 |
| `734c3c897e443a8559033de583e9b8b75303616e` | blob | 0 |
| `78983887aeaee2a239d07a29bb9efc37f2472056` | commit | 0 |
| `855e9d34764d1465f242d68a6a5cae7b1825c4b2` | blob | 0 |
| `911848e37193b1491b60274549db5ec1c0425a33` | blob | 0 |
| `9e6055f6ed325f31d3721aff9c62c5a5b3667606` | blob | 0 |
| `a806db44f9867ee6f44a59b3645e1479b6b0f14b` | blob | 0 |
| `ae88645f582b8c6d7af113e03f59be900df4e20c` | blob | 0 |
| `b8261fa8d28014290f4852aa6ae3155debc3917c` | blob | 0 |
| `ba9ac874cd5f89ee4481271731151a1120c7ca76` | blob | 0 |
| `bb2dee9e1abca32397e2db514eb2c2e084e7095d` | commit | 0 |
| `be813c91c3e471e7997e27be1be24f60cf4b919b` | blob | 0 |
| `c26011857d2c7788a2300dc12754fe61cc8bf0e4` | blob | 0 |
| `c3534e4febc66e8ef17fd8e5f0fec17df1c45d7f` | blob | 0 |
| `c56110df32ea23821d50206891d36a8236966c01` | commit | 0 |
| `c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2` | blob | 0 |
| `cce7f8c6e3451ddaaa89d3dd89bf396c02c94e7c` | tree | 0 |
| `d275cd75204107cb4fdbf65a5441078be79b5aea` | blob | 0 |
| `d68c65f923655af8bf4502acfa51c7afb15ec81d` | commit | 0 |
| `d8c10e312f700ac35defb5c8d7efecc363b2785b` | commit | 0 |
| `db7f7a63c6d54b1a04abb9043d99ef7dcc9326b0` | blob | 0 |
| `ded3661611e7cfc5f714b66a57ee34f5f58219cd` | blob | 0 |
| `e42933e2484b40739c58a987f2ed48a19d484d66` | blob | 0 |
| `e9ec888342b5312f6168fccfa3c24bf3c783ecd5` | blob | 0 |
| `ee6960429c947b7d0cd64bdca6cbb55af22c4ea7` | blob | 0 |
| `f3606d0aef6c00b94f92b8d2e2d3f31aca664f26` | tree | 0 |
