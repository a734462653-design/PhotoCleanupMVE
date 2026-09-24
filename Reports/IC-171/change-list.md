# IC-171 变更清单

> 任务卡：`<top>/Tasks/IC-20260924-171-category-page-trio.md`。本清单与 `self-check.md` 作为本卡唯一的 docs 提交（惯例 44）落在合并后的 `main` 上。

## 一、分支、提交与合并

| 项 | 值 |
|---|---|
| 基线 | `main` = `af66a67a2b184abbad1b71a971b0ff378285123b`（IC-170 报告补记提交；IC-170 merge `ba65163db17b541e9a46ec0e82a7aab7b336e2eb` 是其祖先） |
| 分支 | `feature/ic-171-category-page-trio`（自基线切出，已推送） |
| 子项 A | `4465ab344150588fa10a49a65ac313d860eadd17` `feat(IC-171 A): 类别页收起导航条只留类别名`（6 个文件，+10／−43） |
| 子项 B | `5db0b85c1b0ad1caf699ab312eb2450c33aa58e0` `feat(IC-171 B): 待删篮徽标叠到玻璃合成边界之外`（4 个文件，+122／−9） |
| 子项 C | `e9df07ad387d3ad02cc74ced1c45295f696d1555` `feat(IC-171 C): 长按进 S2 往返后滚动位置保留`（3 个文件，+27／−1） |
| 子项 D | `0134c84cb52aea523410ee2f9e05ddd0f54f5d14` `test(IC-171 D): 新断言——标题、徽标、滚动锚点`（2 个文件，+325，新建 1 个文件） |
| 合并（已推送） | `e356aeda17da53a064892e04f39bea1032f5bf8d`，`--no-ff`，父 `af66a67a2b184abbad1b71a971b0ff378285123b` + `0134c84cb52aea523410ee2f9e05ddd0f54f5d14`；合并后 `main` 运行 #348 绿 892／0，artifact `PhotoCleanupMVE-unsigned-e356aeda17da`（id `10800478861`，1835635 字节，2026-12-23T09:25:22Z 前有效） |
| 报告 | 合并与 #348 之后作为唯一 docs 提交落 `main`（惯例 44） |

`git diff --name-only af66a67a..0134c84`：12 个文件，恰为卡面白名单 12 个路径（产品 6、工程 1、测试 5）。

## 二、子项 A · 收起导航条只留类别名（裁定一）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | `compactNavTitle` 整段替换：删体积（`S0ByteCountText.string(`）与占比（`s0.home.share`）两只 `Text`，类别名加 `.lineLimit(1)`；两侧 `Spacer(minLength: 0)` 与 `compactNavTitleItemSpacing` 不动，加一段文档注释说明动机 |
| `PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift` | 删 9 行：`compactNavValueLetterSpacing`／`compactNavShareFontSize`／`compactNavShareOpacity` 三条登记值定义及各自出处注释（`enum S0DeckMetrics` 切片 198 → 195） |
| `PhotoCleanupMVETests/IC156CategoryPageTests.swift` | `:170` `S0DeckMetrics.` in page 153→147；`:191` `registeredNames.count` 198→195；`:362` `S0ByteCountText.string(` in pageRaw 4→3，其上两行注释同步改措辞 |
| `PhotoCleanupMVETests/IC165DeckFormalTests.swift` | `:215` 登记表 `static let` 计数 198→195 |
| `PhotoCleanupMVETests/IC166RestCategoryTests.swift` | `:336` 登记表 `static let` 计数 198→195 |
| `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift` | 断言 5（`testIC167D_CategoryPageHasTwoBasketEntriesLeftOfSort`）`S0DeckMetrics.` in page 153→147 |

## 三、子项 B · 待删篮徽标叠到玻璃合成边界之外（裁定二）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | 玻璃 helper 扩展收尾之后新增：`struct S1GlassBadgeAnchorKey: PreferenceKey`（报出钮的边界）；`extension View` 新增 `s1GlassBadgeOverlay<Badge: View>(badge:)`（单只玻璃钮场景，`#available(iOS 26.0, *)` 分支包 `GlassEffectContainer` + 容器外 `overlay(alignment: .topTrailing)`，照 S1 `chromeBar`／S2 `topBar` 既有写法）与 `s1GlassBadgeHost<Badge: View>(badge:)`（钮不在容器边缘场景，经 `overlayPreferenceValue(S1GlassBadgeAnchorKey.self)` 在容器外画徽标）；新增 `struct S1GlassBadgeLayer<Badge: View>: View`（徽标放进与报出边界同尺寸同中心的框里右上对齐，`allowsHitTesting(false)`）。所有版本判定留在本文件 |
| `PhotoCleanupMVE/Features/S0/S0BasketEntryView.swift` | `body` 改 `@ViewBuilder` + `switch style`：`.glass` 分支 `button.s1GlassBadgeOverlay { if showsBadge { S0BasketBadge(count: count) } }`；`.flat` 分支 `button.anchorPreference(key: S1GlassBadgeAnchorKey.self, value: .bounds) { anchor in showsBadge ? anchor : nil }`；拆出 `showsBadge: Bool`、`button: some View`（原 `body` 内容去掉 `overlay`）；原 `private var badge` 抽成新顶层 `struct S0BasketBadge: View`（同一段修饰链原样搬）。构造点 `S0BasketEntryView(style:count:action:)` 三处实参不变 |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | `compactNav` 的玻璃背景之后插入 `.s1GlassBadgeHost { S0BasketBadge(count: machine.mergedPendingDeletionCount) }` |
| `PhotoCleanupMVETests/IC167BasketEntryAndTailTests.swift` | 断言 2（`testIC167B_BasketEntryIsCircleWithBadge`）`overlay(alignment: .topTrailing)` 1→0，加一行注释说明徽标改由 S1 helper 叠出；断言 5（`testIC167D_CategoryPageHasTwoBasketEntriesLeftOfSort`）`machine.mergedPendingDeletionCount` 2→3，加一行注释说明收起导航条多取一次 |

## 四、子项 C · 长按进 S2 往返后滚动位置保留（裁定三）

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift` | 新增不发布字段 `var preservedScrollAnchor: String? = nil`（长按那一刻记下被长按格的资产标识；页头未收起时记 nil） |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | `enterCategory(_:)`／`leaveCategory()` 各加一行 `flowModel.preservedScrollAnchor = nil`（换类别、返回首页都清空） |
| `PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift` | `body` 用 `ScrollViewReader { proxy in scrollContent(...).task { restoreScrollAnchor(using: proxy) } }` 包住 `scrollContent`；新增 `private func restoreScrollAnchor(using proxy: ScrollViewProxy)`（锚点非 nil 且仍在 `selection.items` 里才 `proxy.scrollTo(anchor, anchor: .center)`，否则不动）；长按手势 `LongPressGesture().onEnded` 内先写 `flowModel.preservedScrollAnchor = isHeaderCollapsed ? item.id : nil` |

## 五、子项 D · 新断言四条

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVETests/IC171CategoryPageTrioTests.swift`（新建，约 300 行） | `final class IC171CategoryPageTrioTests: XCTestCase`，四条：`testIC171A_CompactNavTitleShowsNameOnly`（标题只剩类别名、三个退役登记值不再出现）、`testIC171B_BadgeIsLaidOutsideGlassViaS1Helpers`（S1 四个新符号、`.glass`／`.flat` 分支、`compactNav` 里玻璃背景先于宿主）、`testIC171C_ScrollAnchorIsUnpublishedAndClearedOnCategoryChange`（`preservedScrollAnchor` 不发布、Combine sink 计数、`enterCategory`／`leaveCategory` 各清一次）、`testIC171C_PageRestoresLongPressedCellOnce`（`ScrollViewReader`／`restoreScrollAnchor`／`scrollTo` 逐一核对，锚点写入在 `onLongPress(` 之前）。源码扫描 helper 逐字照抄 `IC167BasketEntryAndTailTests.swift` 同名私有成员 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 登记新测试文件：PBXBuildFile `200000000000000000000071`（fileRef 指向 `100000000000000000000074`）；PBXFileReference `100000000000000000000074`；测试组文件列表插入 `100000000000000000000074`；Sources 构建阶段插入 `200000000000000000000071`。均紧跟 `IC170S1FirstReadTests.swift` 现有的四行登记之后。登记前重扫得最大号 fileRef `…073`、buildFile `…070`（均为 IC170 文件），新 id 登记前在全文件 0 命中 |

## 六、占位值登记

无出厂值变更：`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S0ScanRules.cacheSchemaVersion` 仍 **1**；`S0DeckSymbol` 仍 **8**；`S0DeckMetrics` 登记表 `enum` 切片 **198 → 195**（本卡子项 A 删三值，非出厂值变更，是登记制常量随行为一起退役）；文案目录仍 **259**，`s0.` 仍 **41**（本卡不加、不删 key）。

## 七、项数对账

888（继承）→（A）888 →（B）888 →（C）888 →（D）892，与卡面「项数：888 + 4 = 892」一致；两次分支 CI（#346、#347）与合并后运行（#348）实测数字与本对账逐项相符（见 `self-check.md` 第十节）。

## 八、未改动（「不得打红」段，① 现取 blob/tree 比对与 `check_ic171.py` 只读复算）

`App/`、`Core/`、`Services/` 全部；`Features/S0/` 除 `S0BasketEntryView.swift`／`S0DeckCategoryPageView.swift`／`S0DeckMetrics.swift`／`S0CleanupFlowModel.swift`／`S0CleanupFlowView.swift` 外全部（含 `S0DeckHomeView.swift`，blob `8b2168801c41ffcfe51e13dd0ec9620bf1e60136` 两侧相同）；`Features/S1/` 除 `S1View.swift` 外全部（该目录基线上只有这一个文件）；`Features/S2`～`S5`、`Features/Shared/`；`Localizable.xcstrings`；`.github/`、`Scripts/`；除白名单列出的五份外的全部测试文件。`schemaVersion` 7、`cacheSchemaVersion` 1、`S0DeckSymbol` 8、目录 259 均未变。

## 九、合并与推送状态

本地 `--no-ff` 合并 `e356aeda17da53a064892e04f39bea1032f5bf8d`（父 `af66a67a` + `0134c84c`）与随后的 `git push origin main`（Bash 工具）**均一次成功，未被权限分类器拦截**（与 IC-170 报告记录的两次拒绝不同，本卡未触发 `[Merge Without Review]`）。合并后 `main` 运行 #348（run `35981129494`）绿 892／0。

## 十、摘取关系（惯例 40）

克隆里实测 A 单独、C 单独、A→B 均无冲突 `git cherry-pick` 成功，与卡面摘取关系描述一致（详见 `self-check.md` 第八节，含一处额外观察：B 单独 cherry-pick 在 git 3-way 合并层面同样无冲突，供决策会话参考，不影响本卡按 A→B→C→D 顺序交付）。
