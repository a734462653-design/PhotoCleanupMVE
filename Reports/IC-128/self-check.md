# IC-128 自验报告

## 结论（先行）

**交付合格，CI 绿，停在报告等 H57 真机判定（本卡不合并）。** S1 视觉层四个子项
（A chrome／B 范围项／C 菜单与受限提示条／D 四态与文案）全部落地。CI #252 绿：
XCTest **640 项 0 失败**（基数 625 + 本卡 15 项新测试），真实退出码 0，
目的地 iOS 26.2 / iPhone 16，「XCTest 执行摘要」notice 在位，IPA 已登记
（H57 判定用该包）。CI 预算 3 次恰好用满：#250 编译红（缺 PhotosUI 导入）、
#251 一项断言红（自建源码扫描抓到自己注释里的占位 key 字面量）、#252 绿。
本地三门禁退出码均 0。`schemaVersion` 仍为 7，S2～S5 零改动，冻结三链未动。

## 输入与基线

- 任务卡：`<top>/Tasks/IC-20260904-128-s1-visual.md`
- 继承提交：`main` = `ded235b`，`git log --oneline -1 main` 与卡内标题逐字一致 ①
- 目标分支：`feature/ic-128-s1-visual`，自该 `main` 切出
- 被测提交（完整 SHA）：`f58b5c48f808fdab7c0c93d4767f2821aef4c73c`
- 提交结构：四子项各自独立 commit（A `00e32f8`／B `655fe70`／C `9022fc1`／
  D `f2b86c0`）+ 两个修复 commit（`2fb504e` 补 PhotosUI 导入、`f58b5c4` 注释
  措辞）。**cherry-pick 单位为整组**（决策会话已预先声明）。

## CI（预算 3 次，用 3 次）①

| 运行 | 结果 | 归因 |
|---|---|---|
| #250（33978133365） | 红，退出码 65 | 编译错误：`presentLimitedLibraryPicker(from:)` 是 PhotosUI 框架对 `PHPhotoLibrary` 的扩展，仅 `import Photos` 不可见；补 `import PhotosUI`（`2fb504e`） |
| #251（33978421720） | 红，退出码 65 | 640 项仅 1 失败：`testIC128D_UndecidedVisualItemsAndPlaceholderKeysCleared` 的源码扫描断言抓到 `S1StateMachine.swift` 注释中写出的占位 key 前缀字面量（陷阱 18 同类）；改注释措辞、零行为改动（`f58b5c4`） |
| **#252（33978995850）** | **绿** | **Executed 640 tests, with 0 failures (0 unexpected)**；真实退出码 0（`set -o pipefail` + `exit "$test_status"`，job conclusion=success）；「XCTest 执行摘要」notice 在位 |

- 目的地实证行（#252 日志）：
  `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`；
  选定行：`使用 iPhone 模拟器：iPhone 16 (…runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`
- IPA 登记（**H57 判定用这个包**）：`PhotoCleanupMVE-unsigned.ipa`，
  **1199412 字节**，SHA-256
  `49fce55d2c40f12a246b91ab20861c9fc931d5b5d8767a3e110ead202d7b3d89`

## 本地门禁（真实退出码）①

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0（残留 0；目录 206 key 与产品源码引用一致） |
| `git diff --check` | 0 |

## 闸门

- **G511**：diff 共 5 文件——`Features/S1/S1View.swift`、`Core/S1StateMachine.swift`
  （仅子项 D 显式指令的登记项清除，见下）、`Localizable.xcstrings`、
  `PhotoCleanupMVETests/IC128S1VisualTests.swift`、`project.pbxproj`（仅新测试
  文件登记）。**`CleanupCoordinator.swift` 零改动，白名单第 4 条（只读透传成员）
  未用到**：受限标志与范围树均已可从状态机公开成员读到，维度菜单提示的 N 经
  S1View 既有 `rangeReader` 只读读取取得，不触碰状态机。S2～S5 产品行为零改动、
  `s2*` 成员零改动；`S2CalibrationConfiguration` 与 `schemaVersion`（7）零改动；
  冻结三链未变（`b368a6c` / `6736f1e` / `a7cc1ec`）。
- **G512**：chrome 取值全部来自 v18 §11.2 或卡内取值表转录，无新造数值；
  卡未给的微观值逐条以「④取定」登记（清单见 change-list「取值登记」节），
  未发现「v18 缺少必需取值」需停卡的情形。
- **G513**：绿（见上 CI 节，全项落实）。
- **G514**：**未合并**。分支停在 `f58b5c4`，报告写完即止，等 H57。

## 四个子项的断言清单与测试函数名（#252 全过）①

### A：视觉常量容器 + 顶排 chrome 三件

| 断言 | 测试函数 |
|---|---|
| 三件 chrome 存在与禁用态：S1-1 三件 40% 禁用（垃圾桶与徽标照常显示不可触发）、S1-3 垃圾桶禁用徽标不显示、失败态保持可交互 | `testIC128A_ChromeBarStatesFollowLoadingEmptyReady` |
| 徽标显隐口径：数值 = `D_全部`（跨范围并集），为 0 不显示且入口禁用 | `testIC128A_BadgeValueEqualsMergedPendingCount`（并集）+ 上一条（0 值口径） |
| 中胶囊副行口径：资产并集数 · 范围项总数 | `testIC128A_CapsuleSubtitleCountsUnionAndRangeCount` |
| v18 §11.2 转录钉住 + 距屏顶值的推导量恒等式（114/122/174） | `testIC128A_ChromeMetricsMatchSpecSection11Part2` |

### B：范围项

| 断言 | 测试函数 |
|---|---|
| 封面取图规则：按当前 `O` 首张、`O` 翻转封面跟着换、年节点递归首个子范围 | `testIC128B_CoverFollowsCurrentSortOrderAndFlips` |
| 请求口径 56pt × scale（2×→112、3×→168） | `testIC128B_CoverTargetPixelSizeFollowsDisplayScale` |
| 降质先上、只升不降、取不到图走中性占位（nil 不回退已有图） | `testIC128B_CoverReplacementNeverDowngrades` |
| 进度线填充比例映射（含钳制与 0 总数）与「不在 `K` 不画」 | `testIC128B_ProgressLineFractionAndVisibility` |
| 待删红点显隐口径（零待删不画） | `testIC128B_PendingBadgeHiddenAtZero` |
| 展开区与进入区是两个不同目标（展开区仅年节点、月行缩进 52、展开不产生交接） | `testIC128B_YearRowHasSeparateExpandAndEnterTargets` |

### C：菜单与受限提示条

| 断言 | 测试函数 |
|---|---|
| 两菜单互斥（开一关一、再点关闭） | `testIC128C_MenusAreMutuallyExclusive` |
| 维度菜单提示口径（日期结构提示、相册 N 个、未分类 N 张、读不到不显示） | `testIC128C_DimensionMenuHintsFollowReadState` |
| 受限提示条显隐 + 列表起始 122→174（推导量 63→115） | `testIC128C_LimitedBannerVisibilityAndListTopOffset` |

### D：四态与文案

| 断言 | 测试函数 |
|---|---|
| 四态各自的元素清单（授权类有「打开系统设置」无重试；读取类有「重试」；空态无按钮；加载态无进度数字） | `testIC128D_StateLayoutsMatchElementInventory` |
| item05/06/07/10/12/15 已清、item16/17 保留、产品源码无占位 key 引用 | `testIC128D_UndecidedVisualItemsAndPlaceholderKeysCleared` |
| 文案 key 与目录一致 | 扫描器（退出码 0）；`retry()` 调用点恰一处由既有 `testIC127D_NoAutomaticRetryPath` 继续钉住（#252 通过） |

## 人工判定项（H57，原样列出，**留给 Lynn，执行端不代为下结论**）

1. 深／浅两种外观下 chrome 的玻璃观感与前景配色是否与 S2 一致（同一台设备上来回切 S1／S2 对比）。
2. 缩略图上的进度线与待删红点在**真实照片**背景上是否看得清、是否吵；封面取「首张」这条规则在你自己的照片库里看着是否合理。
3. 年节点的展开区与进入区在真机上是否**手指可分**（不误触）。
4. 受限授权提示条、四态版式的观感与文案语气。

## 发现但未处理的问题（按纪律只报告不修）

1. **维度菜单提示的读取是同步全库读**（②样本观察）：打开维度菜单时经
   `rangeReader` 同步读相册与未分类两个维度以取 N；大照片库下菜单打开可能有
   可感延迟。卡内不许缓存与后台化，未优化。
2. **封面加载的资产解析在滚动路径上同步执行**（③推测）：
   `PHAsset.fetchAssets(withLocalIdentifiers:)` 逐卡在主线程取单个资产（图像
   请求本身异步）。单 ID 取回很快，但大列表快速滚动的流畅性只能真机判定——
   卡内明示「真机若发现滚动卡顿，报告里记下，不要顺手优化」。
3. **`O` 翻转瞬间封面会短暂回到灰底**（②）：封面资产变更时清图重请求，
   降质图到达前显示占位底；未做交叉淡入（超出本卡范围）。
4. **进度线白系配色在浅色封面上的对比度**属 H57 第 2 条判定范围，测试只钉
   数值不判观感。
5. **S1-4 失败态的顶排 chrome 行为卡内未规定**：实装保持可交互（可切维度触发
   重读；垃圾桶按徽标通用口径），作为登记解释而非定案；如与决策会话意图不符
   请指正。
