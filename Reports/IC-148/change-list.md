# IC-148 变更清单 · S0 视觉层

- 任务卡：`<top>/Tasks/IC-20260914-148-s0-visual-layer.md`
- 分支：`feature/ic-148-s0-visual-layer`
- 继承提交：`main` = `6400666ec9cea250bfbf3a48d52f82db1fcfcba1`（IC-147 merge 提交；`git log --oneline -1 main` 标题以 `Merge branch 'feature/ic-147-s0-behavior-layer'` 开头；`git merge-base --is-ancestor f41add9cdd16b9402e6cb2a7df7b5f96f9b45713 main` 退出码 0）
- 提交顺序：A → B → C → D，另加**两个**修正提交（#294 编译错误、#295 断言口径错），见第一节末

---

## 一、提交清单

| 序 | 子项 | 提交 SHA | 标题 | 触及文件 |
|---|---|---|---|---|
| 1 | A | `c3e3b80…` | `feat(IC-148 A): 视觉登记表与氛围底底座` | `Features/S0/S0HomeMetrics.swift`（新）、`Services/S0RecentPhotoAmbientLoader.swift`（新）、`App/PhotoCleanupMVEApp.swift`、`project.pbxproj` |
| 2 | B | `8aa67e7…` | `feat(IC-148 B): 氛围底层、玻璃卡与 hero／顶排／四态版式` | `Features/S0/S0View.swift` |
| 3 | C | `7eed138…` | `feat(IC-148 C): 分段条 S0SegmentBar 与图例` | `Features/S0/S0SegmentBar.swift`（新）、`Localizable.xcstrings`（2 key）、`project.pbxproj` |
| 4 | D | `45a59ca…` | `feat(IC-148 D): 类别行 S0CategoryRow 与十四条视觉断言` | `Features/S0/S0CategoryRow.swift`（新）、`PhotoCleanupMVETests/IC148S0VisualTests.swift`（新）、`PhotoCleanupMVETests/IC147S0BehaviorTests.swift`、`project.pbxproj` |
| 5 | 修 | `dc0dfe0…` | `fix(IC-148 D): 修 #294 的编译错误——被 heredoc 吞掉的转义` | `PhotoCleanupMVETests/IC148S0VisualTests.swift`、`Features/S0/S0View.swift` |
| 6 | 修 | `3d65978…` | `fix(IC-148 D): 修 #295 的三条假红与一条空转（剔注释源码 vs 原文）` | `PhotoCleanupMVETests/IC148S0VisualTests.swift` |

完整 40 位 SHA 与存在性核验见自验报告第十一节。

**关于第 5 个提交**：#294 判红在**编译期**，原因是用 Git Bash heredoc 往测试文件里打补丁时反斜杠被吞、`"\n}\n"` 落成一个真换行。按纪律 2（三次尝试上限内）在同一张卡、同一分支内追加一个修正提交，不改任何断言语义。详见自验报告第五节第 2 部分。

**关于 cherry-pick 与中间提交可构建性**：六个提交触及的文件两两基本不重叠（`project.pbxproj` 与 `Localizable.xcstrings` 各自只被追加不同区段的行），逐个 `git cherry-pick` 均可干净应用。但**中间提交不可单独构建**：B 的 `S0View.swift` 同时消费 C 的 `S0SegmentBar` 与 D 的 `S0CategoryRow`——任务卡 V1 坐标把「六个 builder 的版式」定为一个改动单元，而这六个 builder 在同一个文件里，无法按子项切成四份且各自编译。可构建且全绿的只有最后一个提交（tip）。与 IC-147 同一形态，如实登记。

---

## 二、新增文件

| 文件 | 行数 | SHA-256 | 作用 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift` | 268 | `9642d50ca3b293eb51c07092a4b00b25d5dea12ceeeb328eabc88f5a5e981fdb` | 52 个视觉登记常量的唯一落点 + `S0HomePalette` 前景色派生 |
| `PhotoCleanupMVE/Features/S0/S0SegmentBar.swift` | 409 | `b1261c79714ceb3bd4363ce78b1cd59012f439fb69698599b1f8e92f26b4d1ef` | `S0SegmentBarModel`（纯函数宽度／斜纹分配）、分段条、斜纹 `Canvas`、图例与流式布局 |
| `PhotoCleanupMVE/Features/S0/S0CategoryRow.swift` | 207 | `b4ca39374bda2fb26f4ecb42b8912023df394c815a00312a5d283ba677f09736` | `S0CategoryRowPresentation`（排序／暗度／占位／进入指示）、`S0CategoryRowProse`、`S0ByteCountSplit`、类别行视图 |
| `PhotoCleanupMVE/Services/S0RecentPhotoAmbientLoader.swift` | 88 | `a69f523f83c3653a39257e2e32d88cc415fdceb9f34b135a2420a399b04154f7` | 裁定 乙 的图源实现（最近一张，缩略级、禁网络） |
| `PhotoCleanupMVETests/IC148S0VisualTests.swift` | 1310 | `efbff220da5eeb70f3ce34f0778f0ef1c7014363d427d80ace22244f4ca978e9` | 十四条视觉断言 |

## 三、修改文件

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/Features/S0/S0View.swift` | 六个 builder 换版式 + 氛围底层 + 玻璃卡 + 图源协议；564 增 / 94 删（相对 `main`） |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 两个 hunk，共 6 增 0 删（见第四节） |
| `PhotoCleanupMVE/Localizable.xcstrings` | 新增 2 条 `s0.home.legend.*`（245 → 247 总条目，`s0.` 30 → 32） |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | 改口径 4 处（见第六节），27 增 / 部分删 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 五个新文件登记，20 增（见第五节） |

---

## 四、`App/PhotoCleanupMVEApp.swift` 的两个 hunk

| hunk | 内容 |
|---|---|
| `@@ -18,0 +19,5 @@` | E1：新增 `private let s0AmbientImageProvider: any S0AmbientImageProviding = S0RecentPhotoAmbientLoader()`（含三行注释），照 `s0DataProvider` 同制 |
| `@@ -73,0 +79 @@` | E2：`s0Screen()` 的实参表加一行 `ambientImageProvider: s0AmbientImageProvider,`，位置在 `dataProvider` 之后——**与 `S0View` 的逐成员声明顺序一致**（陷阱 16） |

两个 hunk 都是纯增行，无删行。`tabContainer`、`s1Screen`、`s2Screen`、路由 switch 的五个分支、`.onAppear`、`restoreS0Foreground` **一字未动**（`git diff -U0` 只输出这两个 `@@`）。

---

## 五、`project.pbxproj` 登记

**加登记前重扫的各族最大对象 id**（陷阱：撞号不报错、后登记的文件静默掉出编译列表，IC-134 #262 实例）：

| 族 | isa | 扫描所得最大 id | 本卡新占用 |
|---|---|---|---|
| `1000…` | `PBXFileReference` | `10000000000000000000004B` | `…04C`／`…04D`／`…04E`／`…04F`／`…050` |
| `2000…` | `PBXBuildFile` | `200000000000000000000048` | `…049`／`…04A`／`…04B`／`…04C`／`…04D` |
| `3000…` | `PBXGroup` | `30000000000000000000000E` | **不新增**（`Features/S0` 组 IC-147 已建） |

登记前对五个 fileRef id、五个 buildFile id 逐个断言「文件中尚不存在」；登记后复核**对象定义行无重复 id**（`grep -oE "^\t\t[0-9A-F]{24} /\*" | uniq -d` 为空）。

**每个新文件的四处登记**（`grep -c <文件名>` 行计，五个文件各恰 **4** 次）：

| 文件 | PBXBuildFile | PBXFileReference | 所属 PBXGroup | PBXSourcesBuildPhase |
|---|---|---|---|---|
| `S0HomeMetrics.swift` | `…049` | `…04C` | `Features/S0`（`3000…000E`） | 应用源码阶段 `400000000000000000000001` |
| `S0SegmentBar.swift` | `…04A` | `…04D` | `Features/S0` | 应用源码阶段 |
| `S0CategoryRow.swift` | `…04B` | `…04E` | `Features/S0` | 应用源码阶段 |
| `S0RecentPhotoAmbientLoader.swift` | `…04C` | `…04F` | `Services`（`3000…0004`） | 应用源码阶段 |
| `IC148S0VisualTests.swift` | `…04D` | `…050` | `PhotoCleanupMVETests`（`3000…0009`） | 测试源码阶段 `400000000000000000000004` |

行尾与 BOM：本卡触及的全部文件均为 **LF、无 BOM**（以字节计数核验，`CR=0`）。①本机注记：Bash 工具下 `grep -c $'\r'` 不按转义解释，行尾一律以字节计数为准。

---

## 六、既有断言改口径（旧 → 新）

只改 `IC147S0BehaviorTests.swift`，共 **4 处**，全部集中在断言 10 与断言 11 的文案门禁；**其余断言与另外 14 个测试函数一字未动**。

| # | 位置 | 旧 | 新 | 理由 |
|---|---|---|---|---|
| 1 | 断言 10 | `XCTAssertEqual(s0Values.count, 30)` | `XCTAssertEqual(s0Values.count, 32)` | 本卡新增两条图例 key |
| 2 | 断言 11 | `XCTAssertEqual(catalogS0Keys.count, 30)` | `XCTAssertEqual(catalogS0Keys.count, 32)` | 同上 |
| 3 | 断言 11 | 扫描文件表为 `S0View.swift`、`S0TabContainer.swift` 两项 | 加入第三项 `S0SegmentBar.swift` | 两条新 key 的引用点在分段条文件里。**任务卡只写了「key 计数 30→32」，但只改计数会让「不多不少」那条假红**——目录有 32 条而扫描面只看得到 30 条。这一处是卡内指示不足、必须补的改动 |
| 4 | 断言 11 | `XCTAssertEqual(referenced, catalogS0Keys)` + `XCTAssertTrue(referenced.allSatisfy { $0.hasPrefix("s0.") })` | `XCTAssertEqual(referenced.filter { $0.hasPrefix("s0.") }, catalogS0Keys)` + `XCTAssertEqual(referenced.filter { !$0.hasPrefix("s0.") }, ["s1.limited.banner"])` | 子项 B 第 6 条要求画受限提示条，而 SPEC-S0 v1 第十四节第 3 部分**没有登记任何 `s0.` 受限提示条文案**（该缺口 IC-147 报告已登记）。复用 SPEC-S1 v9 已登记的同义文案后，原「全部以 `s0.` 为前缀」必然为假；改为把这**唯一一条**跨前缀引用钉死，再多一条即判红——比原断言更严，不是放宽 |

---

## 七、占位值登记

**本卡未新增任何 `S2CalibrationConfiguration` 字段，`schemaVersion` 保持 `7`**；`S2Calibration.swift` 不在 diff（两侧 SHA-256 相同，见自验报告 G848）。

**新增的 52 个登记常量**：全部一一对应 SPEC-S0 v1 第十四节第 2 部分的字段，**常量名与字段名逐个同名**，逐条对账表见自验报告**第三节**（52 : 52，零未匹配、零未登记、零改名）。

**实现自填／跨族复用的取值（登记表缺口，待 SPEC-S0 v2 补登）**：

| 取值 | 落点 | 出处与理由 |
|---|---|---|
| `awaitingRecognitionOpacity = 0.55` | `S0CategoryRowProse` | 写在 SPEC-S0 v1 **第三节第 1 部分正文**（「整行降为 55% 不透明度」），不在第十四节登记表 |
| `unavailableValue = "—"` | `S0CategoryRowProse` | 同上（「数值位显示「—」」）；是占位符号不是文案，故不进 String Catalog |
| 主文字 = 纯白；副文字 = 纯白 × 该族登记的副行不透明度 | `S0HomePalette` | 登记表**未登记任何前景色**，而裁定 甲 又禁用随 trait 解析的色源 |
| 玻璃卡圆角取 `categoryRowCornerRadius`、内边距取 `S1ChromeLayout.horizontalMargin` | `S0View.glassCard` | 登记表给了玻璃卡的模糊／饱和／三层高光／投影共 8 值，**没给圆角与内边距** |
| 图例项内间隙取 `legendItemSpacingV` | `S0SegmentLegendView` | 登记表只有项**间**横向与行间纵向两个间隙，**没有项内间隙** |
| 「正在扫描…」与空态主句、失败说明主句字号取 `heroUnitFontSize` | `S0View` | 登记表只给了 hero 的标签／值／单位／副行四个字号，**没给这三句的字号** |
| 封面空槽描边取 `cardOuterRingOpacity` | `S0CategoryRowView.cover` | 登记表给了封面边长与圆角，**没给占位态的描边取值** |

以上七项全部集中在少数几处、每处都写明出处与理由；无一处是凭印象填的数字。详见自验报告第十节。
