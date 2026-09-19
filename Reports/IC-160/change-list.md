# IC-160 变更清单

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260919-160-category-selection-survives-s2.md` |
| 基线 `main` | `d64b7f28286374099143c18565a326fc9f05d762` |
| 分支 | `feature/ic-160-category-selection-survives-s2` |
| 子项 A 提交 | `6c3cecd7bb76ea8d2ac31c97c1e6191970db94f2` `feat(IC-160 A): 选择模型加播种口、流程模型加不发布的保留集` |
| 子项 B 提交 | `59a449670bd68866ab87e4067e77e2ff287336ba` `feat(IC-160 B): 类别页回报勾选、流程容器播种与清空保留集` |
| 报告 | 本文件与 `self-check.md`，另一个 docs 提交（同一分支，纪律 7：CI 编号推送后才产生；SHA 在 `self-check.md` 第十二节实读补记） |
| 出厂值 | **无变更**。`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S0HomeMetrics` 仍 **52**；`S0CategoryPageMetrics` 仍 **42**；目录 `s0.` 仍 **38**（本卡不加常量、不加文案） |
| 占位值登记 | **无**。不新增 `factoryPlaceholder` 项、不改任何出厂值集合，故不递增 `schemaVersion` |
| 项数 | 852 + 4 = **856**（A 单独摘取时 852 + 3 = 855） |

## 二、文件清单（`git diff --numstat d64b7f2 59a4496`，全部在白名单内）

| 文件 | 增／删 | 白名单条目 | 所属提交 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift` | +25／−2 | A1、B1、B2 | A +4／−1；B +21／−1 |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift` | +4／−0 | A2 | A |
| `PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift` | +7／−0 | B3 | B |
| `PhotoCleanupMVETests/IC160SelectionSurvivesS2Tests.swift`（新） | +238／−0 | 本卡断言 | A 建 201 行（断言 1～3 + 夹具 + helper）；B +37（断言 4） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4／−0 | 一个新文件登记 | A |

合计 5 个路径，+278／−2。报告两份另计（docs 提交，`Reports/IC-160/`）。

**既有测试文件一个未改**：`git diff --name-only d64b7f2 HEAD -- PhotoCleanupMVETests/` 只输出新文件那一行。

## 三、逐项变更

### 子项 A

| 处 | 文件:改后行 | 变更 |
|---|---|---|
| A1 | `S0CategoryPageView.swift:12-17` | `init(items:)` → `init(items: [S0CategoryAsset], preselected: Set<String> = [])`，函数体加 `self.selected = preselected.intersection(Set(items.map { $0.id }))`，另两行文档注释。默认值保证既有两处构造点（页面构造点改后在 `:304-309`、`IC156CategoryPageTests.swift:24`）写法照旧可编译 |
| A2 | `S0CleanupFlowModel.swift:11-13` | `@Published var presentedCategory` 之后加 `var preservedSelection: Set<String> = []`（**不带 `@Published`**，裁定 二）与两行文档注释 |
| A3 | `IC160SelectionSurvivesS2Tests.swift`（新，201 行） | 断言 1～3；类末尾 `// MARK: - 夹具与 helper` 下放四项夹具 `fixtureAssets`（a／b／c／d，字节 900／700／500／300 严格递减）与 `newline`／`repoRoot`／`sourceText`／`strippedSource`／`occurrences`（照 `IC157LongPressIntoS2Tests.swift:745-818` 抄） |
| A4 | `project.pbxproj` | 新文件四处登记：`PBXBuildFile` `20000000000000000000005E`、`PBXFileReference` `100000000000000000000061`、测试组 children、测试 target 的 `PBXSourcesBuildPhase`。登记前重扫：改前文件引用最大 `…60`、构建文件最大 `…5D`；改后全表 187 个对象 id **无撞号** |

### 子项 B

| 处 | 文件:改后行 | 变更 |
|---|---|---|
| B1 | `S0CategoryPageView.swift:280-282`、`:288-310` | 存储属性 `private let onSelectionChange: (Set<String>) -> Void`（声明在 `onLongPress` 之后、`toastDurationMilliseconds` 之前）与两行文档注释；init 加 `initialSelection: Set<String> = []`、`onSelectionChange: @escaping (Set<String>) -> Void = { _ in }` 两个带默认值的形参（同一位置）；播种改为 `S0CategoryPageSelection(items: items, preselected: initialSelection)`。`initialSelection` 不做存储属性，只在 init 里用于播种 |
| B2 | `S0CategoryPageView.swift:324-332` | `body` 根 `ZStack` 上挂 `.onChange(of: selection.selected) { _, current in onSelectionChange(current) }` 与 `.onAppear { onSelectionChange(selection.selected) }`（裁定 三末条：`.onChange` 不对初值触发，出现时回报一次使模型收敛为页面真正显示的集合），另三行文档注释。**长按处一字未动**（内容锚切块 diff 为空，见 `self-check.md` 第六节） |
| B3 | `S0CleanupFlowView.swift:88-93`、`:109-119` | `onEnterCategoryPage` 闭包里先 `flowModel.preservedSelection = []` 再置 `presentedCategory`；`onBack` 闭包同样先清空再置 nil；页面构造点加 `initialSelection: flowModel.preservedSelection` 与 `onSelectionChange: { flowModel.preservedSelection = $0 }`（实参顺序照 init 声明顺序，陷阱 16）；另三行文档注释。**容器 `init` 与存储属性段（`:25-53`）逐字未动**（切块 diff 为空） |
| B4 | `IC160SelectionSurvivesS2Tests.swift`（+37 行） | 断言 4 插在断言 3 之后、类末尾 `// MARK: - 夹具与 helper` 之前 |

## 四、断言与测试函数名

| 断言 | 测试函数 | 所属提交 |
|---|---|---|
| 1 播种集与当前网格求交 | `testIC160A_PreselectIsIntersectedWithItems` | A |
| 2 一次往返的模型层演练 | `testIC160A_RoundTripKeepsSurvivingSelection` | A |
| 3 保留集挂流程模型且不发布 | `testIC160A_FlowModelCarriesUnpublishedSelection` | A |
| 4 页面回报与流程接线、既有钉子照旧 | `testIC160B_WiringAndExistingPinsHold` | B |

## 五、摘取关系（惯例 40／42，克隆仓库实测）

| 单元 | 命令 | 结果 |
|---|---|---|
| A 单独 | 克隆后 `git checkout d64b7f2 -B probe-A; git cherry-pick 6c3cecd` | **退出码 0**，干净落地（4 文件、+213／−1） |
| A→B | 接上 `git cherry-pick 59a4496` | **退出码 0**，干净落地（3 文件、+65／−1） |
| B 单独（负对照） | 克隆后 `git checkout d64b7f2 -B probe-B-alone; git cherry-pick 59a4496` | **退出码 1**，`CONFLICT (modify/delete)`：`IC160SelectionSurvivesS2Tests.swift` 在基线上不存在——与卡内「B 按提交不能脱离 A 单独摘取」一致 |

## 六、文案与登记

- `Localizable.xcstrings` **未改**（本卡不加 key、不改文案；新增汉字全在文档注释与测试文件里）。
- 登记制常量：不增不改（`S0CategoryPageMetrics.` 在页面内仍 **59** 处引用、42 个登记名不变；`S0HomeMetrics` 仍 52）。
- 硬编码扫描器：本机退出码 0（`scan-hardcoded-user-visible-strings.ps1`）。

## 七、CI 与合并

见 `self-check.md`（运行编号、被测提交、项数与失败数、真实退出码、目的地实证行、IPA 校验、分段耗时 notice、G905／G906 实测表、四条断言结果、`testIC063…` 与 `building pipeline` 的先后、合并提交与 G908、H79 四条）。
