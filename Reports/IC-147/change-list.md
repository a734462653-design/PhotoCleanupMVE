# IC-147 变更清单 · S0 行为层

- 任务卡：`<top>/Tasks/IC-20260914-147-s0-behavior-layer.md`
- 分支：`feature/ic-147-s0-behavior-layer`
- 继承提交：`main` = `dc1d0f0f9f7d59f5617b2b857f52520a2a43e98a`（IC-146 报告提交，标题以 `docs(IC-146)` 开头；`git merge-base --is-ancestor d753fc5a31f5e7e2760b88d1ab842949de5a80bc main` 退出码 0）
- 提交顺序：A → B → C → D，四项各自独立 commit

---

## 一、提交清单

| 序 | 子项 | 提交 SHA | 标题 | 触及文件 |
|---|---|---|---|---|
| 1 | A | `de9de132e521c7d4c6dbe8c96ec5d61f316fad7f` | `feat(IC-147 A): 两 tab 容器与 App 入口接线` | `Features/S0/S0TabContainer.swift`（新）、`App/PhotoCleanupMVEApp.swift`、`Localizable.xcstrings`（2 key）、`project.pbxproj` |
| 2 | B | `31d91bc32018d72bb41095b3b0d70312c805a744` | `feat(IC-147 B): S0 状态机与四态迁移` | `Core/S0StateMachine.swift`（新）、`project.pbxproj` |
| 3 | C | `2c7e6ad8bbfc498d22e0c3e96423de34706448c4` | `feat(IC-147 C): 数据源协议与 S0 骨架视图` | `Features/S0/S0View.swift`（新）、`Localizable.xcstrings`（28 key）、`project.pbxproj` |
| 4 | D | `f41add9cdd16b9402e6cb2a7df7b5f96f9b45713` | `feat(IC-147 D): 扫描数据源桩实现与行为层测试` | `Services/S0CleanupDataStub.swift`（新）、`PhotoCleanupMVETests/IC147S0BehaviorTests.swift`（新）、`project.pbxproj` |

**关于 cherry-pick**：四个提交触及的文件两两不重叠（`project.pbxproj` 与 `Localizable.xcstrings` 各自只被追加不同区段的行），逐个 `git cherry-pick` 均可干净应用。但**按任务卡指定的 A→B→C→D 顺序，中间提交不可单独构建**：A 的 App 入口引用 C 的 `S0View` 与 D 的 `S0CleanupDataStub`，C 的视图引用 B 的类型。可构建的只有第四个提交之后的 tip。这是卡内「A→B→C→D 顺序」与「各自独立 commit」两条要求叠加后的必然结果，执行端未自行改序，如实登记。

---

## 二、新增文件

| 文件 | 行数 | SHA-256 | 作用 |
|---|---|---|---|
| `PhotoCleanupMVE/Core/S0StateMachine.swift` | 545 | `45cec85bca12aa271fc1ef6db200c212d89207e04c2e9e1ac906b065d1c0b374` | 状态变量 `SC`／`LG`／`VF`／`Q`、四态纯函数解析器、13 行迁移、点击有效性矩阵、类别顺序 |
| `PhotoCleanupMVE/Features/S0/S0TabContainer.swift` | 94 | `2f914cfaa30bab29b3f3a5fcfa9b3262914597976994ef0fd11409ee2ffd2f34` | `S0Tab`、`S0TabSelectionModel`、泛型两 tab 容器、tab 图标符号名 |
| `PhotoCleanupMVE/Features/S0/S0View.swift` | 356 | `f297c75e6f5e3fb9b2d1201aa7072cb0493e45a3267fc5bcfd11ca64df1ac82a` | `S0CleanupDataProviding` 协议（消费侧）、字节量文本、类别名、四态骨架视图 |
| `PhotoCleanupMVE/Services/S0CleanupDataStub.swift` | 215 | `53ea990b26835e81413e4123cf59897a744cd3f8b5539cd5198c91ddb176acc4` | 五条剧本的确定性桩，不碰 PhotoKit、不持久化、不起后台活动 |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift` | 1322 | `c8d6bdb095c718582f9bbe8e06151ae91380dddd6b23299b41ad885a3a6d26da` | 十六个测试函数：十三条断言（断言 6 拆为矩阵与遮挡两个函数）+ 两条补充断言 |

## 三、修改文件

| 文件 | 改动 |
|---|---|
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 见第四节 hunk 清单 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 新增 30 条 `s0.` 条目（215 → 245）；插入位置在 `deletion.*` 与 `s1.*` 之间，保持既有 ASCII 升序；格式沿用 2 空格缩进、` : ` 分隔、单一 `zh-Hans` 本地化、`extractionState: manual`；LF、无 BOM |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 见第五节 |

---

## 四、`App/PhotoCleanupMVEApp.swift` 的 diff hunk 清单

| hunk | 改前行 | 内容 |
|---|---|---|
| `@@ -5,6 +5,16 @@` | 5～10 | 新增 `@StateObject s0Machine`、`@StateObject s0TabSelection`、`private let s0DataProvider`（注入桩） |
| `@@ -31,4 +41,41 @@` | 31～34 | 新增两个 builder：`tabContainer(s1Machine:)`、`s0Screen()`（陷阱 16：构造点一律外提） |
| `@@ -162,5 +209,5 @@` | 164 | `.s1, .upstream, .finished` 分支由 `s1Screen(machine: machine)` 改为 `tabContainer(s1Machine: machine)`——**本卡对路由 switch 的唯一改动行** |
| `@@ -189,4 +236,5 @@` | 190 | `.onChange(of: scenePhase)` 的 `.active` 分支追加一行 `restoreS0Foreground()`（E3） |
| `@@ -197,3 +245,19 @@` | 结构末 | 新增 `restoreS0Foreground()` 私有方法 |

合计 65 增 1 删。`s2Screen(machine:)`、`s1Screen(machine:)`、`.onAppear` 的启动守卫、`.s2`／`.confirmation`／`.execution`／`.completion` 四个路由分支**一字未动**（断言 3 以逐字串源码扫描钉住，本机模拟实测各命中 1 次）。

---

## 五、`project.pbxproj` 登记

**加登记前重扫的各族最大对象 id**（惯例 14 / 陷阱「撞号不报错」，IC-134 #262）：

| 族 | isa | 扫描所得最大 id | 本卡新占用 |
|---|---|---|---|
| `1000…` | `PBXFileReference` | `100000000000000000000046` | `…047`、`…048`、`…049`、`…04A`、`…04B` |
| `2000…` | `PBXBuildFile` | `200000000000000000000043` | `…044`、`…045`、`…046`、`…047`、`…048` |
| `3000…` | `PBXGroup` | `30000000000000000000000D` | `…00E`（新建 `Features/S0` 组） |

登记前已对五个 fileRef id、五个 buildFile id、一个 group id 逐个断言「文件中尚不存在」，登记后复核**对象定义行无重复 id**。

**每个新文件的四处登记**（`files = (` 命中行以 `grep -c <文件名>` 计，五个文件各恰 4 次）：

| 文件 | PBXBuildFile | PBXFileReference | 所属 PBXGroup | PBXSourcesBuildPhase |
|---|---|---|---|---|
| `S0StateMachine.swift` | `…044` | `…047` | `Core`（`3000…0003`） | 应用源码阶段 `400000000000000000000001` |
| `S0TabContainer.swift` | `…045` | `…048` | **新建 `S0`**（`3000…000E`） | 应用源码阶段 |
| `S0View.swift` | `…046` | `…049` | **新建 `S0`**（`3000…000E`） | 应用源码阶段 |
| `S0CleanupDataStub.swift` | `…047` | `…04A` | `Services`（`3000…0004`） | 应用源码阶段 |
| `IC147S0BehaviorTests.swift` | `…048` | `…04B` | `PhotoCleanupMVETests`（`3000…0009`） | 测试源码阶段 `400000000000000000000004` |

新建的 `S0` 组已加入 `Features` 组（`3000…0005`）children 首位（S0 在 S1 之前）。缩进沿用 TAB（对象定义 2 层、块成员 3 层、列表项 4 层）。

**行尾与 BOM 核验**：本卡触及与新增的全部九个文件均为 **LF、无 BOM**，以字节计数核验（`CR=0`）：`S0StateMachine.swift` LF=545、`S0TabContainer.swift` LF=94、`S0View.swift` LF=356、`S0CleanupDataStub.swift` LF=215、`IC147S0BehaviorTests.swift` LF=1322、`PhotoCleanupMVEApp.swift` LF=263、`Localizable.xcstrings` LF=2701、`project.pbxproj` LF=816（以上为提交后 tip 的实测值，`git show HEAD:<path>` 的 blob 亦均 CR=0）。

> 本机注记（①实测）：Bash 工具下 `grep -c $'\r' <file>` **不按转义解释**，会退化成匹配字母 `r`，给出与行数相同的假读数。行尾核验一律以字节计数为准，不用该写法。

---

## 六、占位值登记

**本卡未新增任何 `S2CalibrationConfiguration` 字段，`S2CalibrationConfiguration.schemaVersion` 保持 `7` 不变**；`S2Calibration.swift` 不在 diff（两侧 SHA-256 相同，见自验报告 G844）。

**实现自填、待补登记的取值（登记制缺口）**：

| 符号 | 取值 | 说明 |
|---|---|---|
| `S0TabSymbol.cleanup` | `internaldrive` | SPEC-S0 v1 第十四节**未登记 tab 图标**；按任务卡语义描述「容量条符号」取最接近的系统符号 |
| `S0TabSymbol.organize` | `rectangle.stack` | 同上，对应「卡片上下滑符号」 |

两枚符号集中在 `S0TabSymbol` 一个 enum 内，IC-148 视觉层按补登记值替换时只改这两行。详见自验报告「发现但未处理的问题」第 1 条。

---

## 七、文案 key 与 SPEC-S0 v1 第十四节第 3 部分的逐条对账

见自验报告第七节（30 条全表）。摘要：新增 30 条，**全部出自第十四节第 3 部分，无自造 key**；其中 23 条取值与规格逐字相同，7 条仅因本工程 `L10n.text(_:replacing:)` 用 `{name}` 而非 `%N$@` 作占位符而写法不同，渲染文本一致。第十四节第 3 部分共登记 82 条 `s0.` key，本卡只登记骨架用到的 30 条——**未被产品源码引用的 key 会被 `scan-hardcoded-user-visible-strings.ps1` 判失败**（双向 bijection 门禁），故其余 52 条留给 IC-148 及之后各卡按需登记。

---

## 八、既有测试的改口径

**无。** 本卡未修改任何既有测试文件（`git diff --stat main` 中 `PhotoCleanupMVETests/` 下只有新增文件，无修改）。既有 761 项一字未动。
