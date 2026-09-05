# IC-128 变更清单

分支：`feature/ic-128-s1-visual`（自 `main` = `ded235b` 切出，**不合并**，等 H57）
被测提交：`f58b5c48f808fdab7c0c93d4767f2821aef4c73c`（CI #252 绿，640 项 0 失败）

提交链（cherry-pick 单位 = 整组，决策会话预先声明）：

| 提交 | 内容 |
|---|---|
| `00e32f8` | A：视觉常量容器 + 顶排 chrome 三件（含徽标与禁用态）+ 测试文件登记 |
| `655fe70` | B：范围卡（封面缩略图、进度线、待删红点、两级树、年垫卡） |
| `9022fc1` | C：两个互斥菜单 + 受限提示条 |
| `f2b86c0` | D：四态版式 + 文案落 String Catalog + 清登记项 |
| `2fb504e` | fix（C）：补 `import PhotosUI`（#250 编译红归因） |
| `f58b5c4` | fix（D）：清除说明注释避开占位 key 字面量（#251 单断言红归因） |

## 文件级变更（5 文件，+2201 −215 对 `main`）

| 文件 | 变更 | 白名单对应 |
|---|---|---|
| `Features/S1/S1View.swift` | 整层重写（330 → 1721 行）：常量容器 10 个、玻璃族 View 扩展、封面缩略图组件、chrome 三件、范围卡、双菜单、受限提示条、四态版式；展示口径模型（`S1ChromeBarModel` 等 8 个）供测试钉住 | 视图层 |
| `Core/S1StateMachine.swift` | **仅子项 D 显式指令**：删除 `S1UndecidedItems` 的 item05/06/07/10/12/15 六个登记项与 `LocalizedCopy`／`localizedCopy` 占位文案通道（item16/17 保留）；−43 行，无任何行为改动 | 范围内 D「清掉剩余的视觉／文案登记项」 |
| `Localizable.xcstrings` | +14 −7 key（199 → 206）：新增 `s1.chrome.subtitle_format`、`s1.menu.dimension.{date_hint,album_hint,unclassified_hint}`、`s1.limited.{banner,manage}`、`s1.state.*` 八条；改值 `s1.range.total_count`（→`{count} 张`）、`s1.sort.{newest,oldest}_first`（→最新在前／最旧在前）；删除 `s1.placeholder.*` 七条 | S1 文案 |
| `PhotoCleanupMVETests/IC128S1VisualTests.swift` | 新文件 +554：15 项测试（A4/B6/C3/D2） | 测试 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4：新测试文件四处登记（buildFile `2000…0033`、fileRef `1000…0036`） | 仅测试文件登记 |

`CleanupCoordinator.swift` 零改动（白名单第 4 条「只读透传成员」未用到——受限标志
与范围树取自状态机公开成员，维度提示经 S1View 既有 `rangeReader` 只读读取）。

## 取值登记（G512 溯源，逐条）

### 来源一：v18 §11.2 转录（`testIC128A_ChromeMetricsMatchSpecSection11Part2` 钉住）

行高/圆钮直径/胶囊高 44（`chromeRowHeight`）、顶排上缘距安全区顶 3
（`topRowTopInset`）、左右边距 16（`chromeHorizontalMargin`）、玻璃配方
0.03/0.30/0.06/1/0.12/0.5（`glass*`，含 iOS 26 glassEffect 分支与 S2 同语汇）、
主行 15（`titleFontSize`）、副行 11.5（`subtitleFontSize`）、圆钮图标 17
（`circleIconPointSize`）、徽标 18/12/5/1.5（`badge*`，描边取系统底色）、
前景具体动态色 `Color.primary/.secondary`（回写决策 42）、受限条内水平边距 14
取 `capsuleHorizontalPadding` 同值。

### 来源二：本卡取值表转录（④卡）

件间距 8；「距屏顶」114/122/174 登记为距安全区顶推导量 55/63/115（卡内
122 = 62 + 44 + 16 自证推导式，随机型安全区自适应——登记解释）；卡片圆角 14、
左右边距 16、卡片间距 16；缩略图 56×56 圆角 12；进度线 6/6/3/2、白 34%/95%、
比例 = 已处理/总数、不在 `K` 不画；红点 top −5/right −5、徽标同值、描边取卡片
底色、零待删不画；显示名 17／年 19 半粗、张数 13 次级等宽、行高 76（年行 min 76
含 10 上下内边距）、右端 13pt 次级箭头；年垫卡层一 8,5/56×46、层二 4,2/56×50、
圆角 10、四色 #D8D8DE/#CACAD1（浅）与 #3A3A3C/#2F2F31（深）；展开区宽 40 +
0.5 分隔线、月行左内边距 52；封面策略（当前 `O` 首张、年递归首子范围、
56pt×scale、降质先上原位替换、中性占位、不做预取/缓存/后台队列）；排序菜单
left 16/宽 200/两项/选中 tint+半粗+16 宽对勾位；维度菜单左右 68/三项/行高 50/
提示 12.5 次级色；菜单共通圆角 14、近白+模糊、外圈 0.5 黑 6%、投影 0 12 32
黑 18%、0.5 分隔线、列表压黑 14%；四态版式（40% 禁用、中央 ProgressView、
图标 52、按钮 44/22/24 tint 文字玻璃底、受限条 44/22/图标 17/文案 13.5/
管理 30/15/12/tint 10% 底）；文案 12 条逐字转录。

### 来源三：④取定并登记（卡未给的微观值与解释，H57 观感兜底）

| 取定 | 值 |
|---|---|
| 胶囊主行下箭头字号 | 11 半粗（`capsuleChevronPointSize`） |
| 副行口径 | 总数 = `R(T)` 资产**并集**数、范围数 = 范围项总数（`S1ChromeSubtitle`） |
| 行内元素间距／顶层行左右内边距 | 12（`contentSpacing`） |
| 垫卡 top/left 解释 | 相对主图原点向右下的 x/y 位移（层高小于主图，横向位移露层叠边） |
| 菜单背景不透明度 | 0.93（卡给 92～94% 区间取中；深色随 `systemBackground` 自适应） |
| 菜单投影 32 | 直接用作 SwiftUI shadow radius（画布投影第三参的换算未定，按字面转录） |
| 菜单行字号 15、排序行高 44、对勾字号 12 | 卡未给排序菜单行几何 |
| 维度菜单选中样式 | tint + 半粗（卡只给排序菜单的选中样式；未加对勾） |
| 受限条图标 | `info.circle`（卡只给 17pt 未指明符号）；「管理」动作 = 系统受限照片管理入口（PhotosUI `presentLimitedLibraryPicker`，卡未指明动作语义） |
| 受限条显隐 | 就绪／空态挂条（受限不进失败态；加载/失败态不挂） |
| 四态字号 | 主句 17 半粗、副句 13.5 次级、加载文案 15 次级、元素间距 12 |
| 状态图标符号 | 空态 `photo.on.rectangle`、授权 `lock`、读取 `exclamationmark.triangle`、封面占位 `photo`（线条图标语义来自卡，具体 symbol 为取定） |
| 页面/卡片/占位底色 | `systemGroupedBackground` / `secondarySystemGroupedBackground` / `secondarySystemFill` |
| S1-4 失败态 chrome | 保持可交互（卡未规定；垃圾桶按徽标通用口径） |

## 占位值登记

出厂值集合无变更，`S2CalibrationConfiguration.schemaVersion` 保持 **7**；
`factoryPlaceholder` 登记制不变（本卡常量走登记制容器，不进配置、不上标定面板）。

## CI

- #250 红（编译，缺 PhotosUI 导入）→ #251 红（640 项 1 失败，自建断言抓自身
  注释字面量）→ **#252 绿（run id 33978995850）：640 项 0 失败、退出码 0、
  iOS 26.2 / iPhone 16**
- IPA（H57 用）：1199412 字节，SHA-256
  `49fce55d2c40f12a246b91ab20861c9fc931d5b5d8767a3e110ead202d7b3d89`
- **G514：未合并，分支停在 `f58b5c4` 等 H57。**
