# IC-160 自验报告

## 一、结论（先行）

1. 子项 A、B 各一个独立 commit（`6c3cecd`、`59a4496`），落在分支 `feature/ic-160-category-selection-survives-s2`，基线 `main` = `d64b7f28286374099143c18565a326fc9f05d762`。
2. 类别页勾选的保留集改由 App 持有的 `S0CleanupFlowModel.preservedSelection`（**不 `@Published`**）承载；页面每次勾选变化与每次出现都回报，重建时按「保留集 ∩ 当前列表」播种；返回首页与从首页进类别各清空一次（裁定 一～三全部照卡实装）。
3. CI：见第七节。
4. G905／G906：见第六节，全部满足；产品目录除三个白名单文件外两侧 SHA-256 相同，既有测试文件一个未改。
5. **人工判定项 H79 四条保留给 Lynn 真机判定**（第十一节原样列出），执行端不代为下结论——「重建后 `@State` 取新初值」这件事模拟器夹具钉不住（陷阱 1）。
6. 发现但未处理的问题见第十节。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260919-160-category-selection-survives-s2.md` |
| 基线 `main` | `d64b7f28286374099143c18565a326fc9f05d762` |
| 继承（IC-159 合并提交） | `4d7c98e84837dda82e6f1a0068cc324b8ec90085`，`git merge-base --is-ancestor 4d7c98e main` 退出码 **0** |
| 远端核对 | `git ls-remote origin refs/heads/main` → `d64b7f28286374099143c18565a326fc9f05d762`，与本地一致 |
| 分支 | `feature/ic-160-category-selection-survives-s2` |
| 子项 A 提交 | `6c3cecd7bb76ea8d2ac31c97c1e6191970db94f2` |
| 子项 B 提交 | `59a449670bd68866ab87e4067e77e2ff287336ba` |
| 范围边界 | 白名单：`S0CategoryPageView.swift`（A1／B1／B2）、`S0CleanupFlowModel.swift`（A2）、`S0CleanupFlowView.swift`（仅 B3）、新测试文件、`project.pbxproj` 一处登记、`Reports/IC-160/`。`App/`、`Core/`、`Services/`、`Features/S1`～`S5`／`Shared`、`Features/S0/` 其余六文件、`Localizable.xcstrings`、`.github/`、`Scripts/`、既有测试文件全未触碰 |

### 开工四步（纪律 8 + 卡首口径）

| 步 | 命令 | 结果 |
|---|---|---|
| 1 | `git status --porcelain` | **空** |
| 2 | `git merge-base --is-ancestor 4d7c98e main` | 退出码 **0** |
| 3 | `git ls-remote origin refs/heads/main` | `d64b7f2…`，与本地相同 |
| 4 | `git switch -c feature/ic-160-category-selection-survives-s2 main` | **先切分支再改文件** |

## 三、逐条验收门禁与测试函数名

| 断言 | 测试函数 | 内容 | 结果（#320） |
|---|---|---|---|
| 1 | `testIC160A_PreselectIsIntersectedWithItems` | 默认值路径仍空选；`{a,c}` 原样播种；`{a,z}` 丢掉不在网格的 `z`；空网格交集为空；播种后字节和 1 400、`count` = `"2"`、主按钮可用；`toggle`／`remove` 既有行为不变 | 待填 |
| 2 | `testIC160A_RoundTripKeepsSurvivingSelection` | 进 S2 前 `{a,b,c}`、S2 里标记 b → 回来列表 `[a,c,d]`、`selected == {a,c}`、`count` = `"2"`、字节和 1 400、副行 `count` = `"3"` | 待填 |
| 3 | `testIC160A_FlowModelCarriesUnpublishedSelection` | 新模型保留集为空；`objectWillChange` 计数：写保留集 **0**、写类别页身份 **1**（正对照）；读回一致；模型文件 `@Published` 恰 1、`var preservedSelection: Set<String> = []` 恰 1、`import` ⊆ {Combine, Foundation} | 待填 |
| 4 | `testIC160B_WiringAndExistingPinsHold` | 页面与流程文件的 16 条源码计数（第六节表） | 待填 |

## 四、本机预验证

### ① 断言 1／2 的集合与字节运算（Python 复算）

夹具 a=900、b=700、c=500、d=300：

| 场景 | 复算结果 |
|---|---|
| 默认（无 `preselected`） | `selected = []` |
| `preselected = {a,c}` | `selected = [a,c]`，bytes = **1400**，count = **2** |
| `preselected = {a,z}` | `selected = [a]` |
| `items = []`, `preselected = {a}` | `selected = []` |
| 播种后 `toggle(c)` → `remove(a)` | `selected = []`，`items = [b,c,d]` |
| 往返：survivors `[a,c,d]`、`preselected = {a,b,c}` | `selected = [a,c]`，count = **2**，bytes = **1400**，副行 count = **3** |

### ② 断言 3／4 的 needle 对改后源码逐个重算

见第六节 G906 表（全部 OK）。口径与测试里的 `strippedSource` 一致：剔 `//` 注释、清空字符串字面量内容。

### ③ 本地门禁

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0**（A 后、B 后各跑一次） |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** |
| `git diff --check` | **0** |

### ④ pbxproj 撞号扫描

登记前重扫：文件引用最大 `100000000000000000000060`、构建文件最大 `20000000000000000000005D`（与卡内一致）。新登记 **`100000000000000000000061`**（`PBXFileReference`）与 **`20000000000000000000005E`**（`PBXBuildFile`）。登记后全表扫描：**187 个声明对象 id，唯一 187，重复 0**（`PBXBuildFile` 92 + `PBXFileReference` 95）。四处登记齐全（build file 声明、file reference 声明、测试组 children、测试 target 的 sources build phase）。

### ⑤ 项数对账

| 树 | 本机 `func test` grep | CI 口径推算 |
|---|---|---|
| 基线 `d64b7f2` | 853 | 852（陷阱 22：`TransitionTableGuardTests.swift` 注释里那行多数 1） |
| A 单独 | 856 | **855** = 852 + 3 |
| A→B（CI 跑的） | 857 | **856** = 852 + 4 |

## 五、摘取关系实测（惯例 40／42）

克隆仓库 `scratchpad/ic160-clone`（`git clone --no-hardlinks`）：

| 单元 | 结果 |
|---|---|
| **A 单独** | `git checkout d64b7f2 -B probe-A` → `git cherry-pick 6c3cecd` **退出码 0**，4 文件 +213／−1 |
| **A→B** | 接着 `git cherry-pick 59a4496` **退出码 0**，3 文件 +65／−1 |
| **B 单独（负对照）** | `git checkout d64b7f2 -B probe-B-alone` → `git cherry-pick 59a4496` **退出码 1**，`CONFLICT (modify/delete): PhotoCleanupMVETests/IC160SelectionSurvivesS2Tests.swift deleted in HEAD and modified in 59a4496` |

与卡内「可摘取单元：A 单独、A→B；B 不能脱离 A」完全一致。

## 六、G905／G906

### G905：diff 限于白名单 + 零改动清单

`git diff --name-only d64b7f2 59a4496` 共 5 条，全在白名单内（清单见 `change-list.md` 第二节）。`PhotoCleanupMVETests/` 下只有新文件一条。

聚合 SHA-256（逐 blob 内容 SHA-256 → 按路径升序行表 → 整体 SHA-256）：

| 范围 | 文件数 | 两侧 | 聚合 SHA-256 |
|---|---|---|---|
| `PhotoCleanupMVE/App/` | 2 | **相同** | `541CEA3C6E823359DCC7286DAC036B4B26F3C498FA89D4D797E1625ECD273BE3` |
| `PhotoCleanupMVE/Core/` | 10 | **相同** | `CB77DAFB9456DD47D3E9E9AC5AC8F24C36E8212C016B4E18922BF632B9001701` |
| `PhotoCleanupMVE/Services/` | 11 | **相同** | `3DABF804CA7E9D246EB599BDE05D6B242785E61EFBC57DD45A5B2350F3CE7596` |
| `PhotoCleanupMVE/Features/S1/` | 1 | **相同** | `6BF25D0634B1B5FAE3B664E4A82DD4332AD156D181F9E2328A9336C48D509AC9` |
| `PhotoCleanupMVE/Features/S2/` | 9 | **相同** | `681C408B2F6C92CAFC2F2B62BADC02AF0CA3EB8A58D609414945780AB58FD0A8` |
| `PhotoCleanupMVE/Features/S3/` | 1 | **相同** | `5522F8E374805CC4BB0C19885FED42D324A3AA2E57D243CA56234DC202BEC91C` |
| `PhotoCleanupMVE/Features/S4/` | 1 | **相同** | `79862B10FB0CC215D930C0D69CEC53DF419AA6F592E82EF3022F37025DC11809` |
| `PhotoCleanupMVE/Features/S5/` | 1 | **相同** | `7F4D20A65AE63F3B9681EF76EB50F312E9F2A2E30491551A49474B9859DC2C13` |
| `PhotoCleanupMVE/Features/Shared/` | 1 | **相同** | `4995602414EF5F4F8A0204FCAD4C0E5D11BB04D225B870A3C3EA608425D4E12A` |
| `PhotoCleanupMVE/Localizable.xcstrings` | 1 | **相同** | `DF3D49224EC4F0DDCC582AA23B4D7D78810619DB920C5126385DFBD8BD7D3E11` |
| `.github/` | 1 | **相同** | `2022FBAA506432073C51577FD830090451B27B222B281EE5F5E66F0412558142` |
| `Scripts/` | 33 | **相同** | `BAD7AAD07B5387F618A9615329C9AA323D1CDEB1178F25CC0E6FEB9DC39A8BC9` |

`Features/S0/` 九个文件中只有白名单那三个变：

| 文件 | 两侧 SHA-256 |
|---|---|
| `S0CategoryPageMetrics.swift` | **相同** `F7BB7BB65317BCDCB9811955E328E52779BF802E2D89A5949E95B60F9DD40BB2` |
| `S0CategoryRow.swift` | **相同** `DF67A0FCAFA50C009ACEE6A0EE6884CC2019E86F48EFDACDB7839FAE301FB1FB` |
| `S0HomeMetrics.swift` | **相同** `2D88A10213B067EE5F62865F2968ECA2F0F207B884BF01BB8EFD28CA52B5A267` |
| `S0SegmentBar.swift` | **相同** `B1261C79714CEB3BD4363CE78B1CD59012F439FB69698599B1F8E92F26B4D1EF` |
| `S0TabContainer.swift` | **相同** `2F914CFAA30BAB29B3F3A5FCFA9B3262914597976994EF0FD11409EE2FFD2F34` |
| `S0View.swift` | **相同** `4A81D3FA72CCF6F522265C202608E967AD8E7102712CFB37D165FDEF6FCD558F` |
| `S0CategoryPageView.swift` | 改：`ABF7E1B76B35740B…` → `3529C5FC43B6B23A…` |
| `S0CleanupFlowModel.swift` | 改：`3760FE6D68D73DD6…` → `24830037467E919D…` |
| `S0CleanupFlowView.swift` | 改：`809298F405AE7FC3…` → `9175FEA436F04669…` |

两段切块 diff（卡内要求）：

| 切块 | 命令 | 结果 |
|---|---|---|
| 流程容器 `init` 与存储属性段 | `diff <(git show d64b7f2:…S0CleanupFlowView.swift \| sed -n '25,53p') <(sed -n '25,53p' …)` | **空**（退出码 0） |
| 页面长按处（**内容锚切**，不按行号） | `diff <(git show d64b7f2:…S0CategoryPageView.swift \| sed -n '/\.simultaneousGesture(/,/^        )$/p') <(sed -n '…' …)` | **空**（退出码 0）；切出的五行为 `.simultaneousGesture(` / `LongPressGesture().onEnded { _ in` / `onLongPress(selection.items.map(\.id), item.id)` / `}` / `)` |

### G906：被钉住的计数（改后本机实测，口径同测试里的 `strippedSource`）

页面文件 `S0CategoryPageView.swift`：

| needle | 期望 | 实测 |
|---|---|---|
| `.onChange(of: selection.selected)` | 1 | **1** |
| `.onAppear` | 1 | **1** |
| `onSelectionChange(` | 2 | **2** |
| `onSelectionChange(selection.selected)` | 1 | **1** |
| `initialSelection: Set<String> = []` | 1 | **1** |
| `preselected: initialSelection` | 1 | **1** |
| `LongPressGesture()` | 1 | **1** |
| `.simultaneousGesture(` | 1 | **1** |
| `Button {` | 2 | **2** |
| `onLongPress(` | 1 | **1** |
| `onTapGesture`／`onLongPressGesture`／`minimumDuration`／`maximumDistance` | 0 | **0／0／0／0** |
| `Image(systemName: ` | 3 | **3** |
| `S0CategoryPageMetrics.` | 59 | **59** |
| `S1ChromeTypography.titleFontSize` | 1 | **1** |
| `machine.handle(`／`beginVerification` | 0 | **0／0** |
| `onLongPress:` | ≥1 | **2** |
| `selection.items.map(` | ≥1 | **1** |
| 裸数集合 | ⊆ {0,1,2} | **{0,1,2}**，越界 0 项 |
| `Text("`（**未剔注释的原文**） | 0 | **0** |
| PhotoKit 七 needle、动态外观四 needle | 各 0 | **全 0** |

流程文件 `S0CleanupFlowView.swift`：

| needle | 期望 | 实测 |
|---|---|---|
| `flowModel.preservedSelection` | 4 | **4** |
| `initialSelection: flowModel.preservedSelection` | 1 | **1** |
| `flowModel.preservedSelection = $0` | 1 | **1** |
| `flowModel.preservedSelection = []` | 2 | **2** |
| `@State ` | 0 | **0** |
| `@StateObject` | 0 | **0** |
| `@ObservedObject` | 1 | **1** |
| `machine.ingest(` | 3 | **3** |
| `S0CategoryPageView(` | 1 | **1** |
| `.returnedFromCategoryPage` | 1 | **1** |
| `navigationDestination(item:` | 1 | **1** |
| `.toolbar(.hidden, for: .navigationBar)` | 2 | **2** |
| `.toolbar(.hidden, for: .tabBar)` | 1 | **1** |
| `static func shouldRecomputeOnAppear(presentedCategory:` | 1 | **1** |
| `CleanupCoordinator`／`SessionStore`／`S1StateMachine` | 0 | **0／0／0** |
| `flowModel.presentedCategory` | ≥3 | **5** |
| `.onAppear` | ≥1 | **1** |
| `onEnterS2` | ≥2 | **5** |
| 裸数集合 | ⊆ {0,1,2} | **{0}**（唯一来源是 `$0`，提取器按「前一字符非字母非下划线」取成 `"0"`，在白名单内） |
| `Text("`（原文） | 0 | **0** |
| PhotoKit 七 needle、动态外观四 needle | 各 0 | **全 0** |

模型文件 `S0CleanupFlowModel.swift`：`@Published` **1**、`@Published var presentedCategory: S0CategoryIdentifier?` **1**、`ObservableObject` **1**、`var preservedSelection: Set<String> = []` **1**、`import` = {Combine} ⊆ {Combine, Foundation}。

其它 G906 项：`schemaVersion` **7**、`S0HomeMetrics` **52** 值、`S0CategoryPageMetrics` **42** 值、目录 `s0.` **38** 条（三者文件两侧 SHA-256 相同即未变，见上表）；冻结三链与四条探针、`feature/ic-158-diagnostic-progress-clamp` tip 见第九节。

## 七、CI 运行 #320（分支运行）

| 项 | 值 |
|---|---|
| 运行编号 | **#320** |
| run id / attempt | `35430705274` / **1**（无重跑；CI 预算 3 次用 **1** 次） |
| 被测提交 | `59a449670bd68866ab87e4067e77e2ff287336ba` |
| 分支 | `feature/ic-160-category-selection-survives-s2` |
| 结论 | `completed` / **`success`**；十二步全 `success`（`non-success: []`） |
| 起止 | `2026-09-19T07:57:29Z` → `08:05:50Z`（作业 `07:57:36Z`→`08:05:49Z`，约 8 分 13 秒） |
| XCTest 项数 | **856 项，0 失败**（`::notice XCTest 执行摘要::Executed 856 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 856 tests / 0 failures`）。按唯一 `Test Case` 身份计（剔 `##[`／`[36;1m` 回显后）亦为 **856 起 / 856 有结果 / 0 failed**——与对账式 852 + 4 = 856 吻合 |
| 真实退出码 | **0**（步骤「运行 XCTest」`success` + `ci.yml:385` `exit "$test_status"`；日志 `** TEST SUCCEEDED **`，无 `Restarting after`、无 `TEST FAILED`） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 分段耗时 notice 原文 | `XCTest 分段耗时：模拟器启动 65 s；xcodebuild test 288 s；总 354 s` |
| IPA 校验 notice 原文 | `未签名 IPA 校验：文件=PhotoCleanupMVE-unsigned.ipa，字节数=1690601，SHA-256=81b5e42f2e3e358e19e64a61ee3a0d13bca11e1530df57901900d33675473a86` |
| artifact | `PhotoCleanupMVE-unsigned-59a449670bd6`，id `10580662661`，容器 1 690 771 字节 |

### 本卡四条断言（全部 passed）

| 断言 | 测试函数 | 结果 |
|---|---|---|
| 1 | `testIC160A_PreselectIsIntersectedWithItems` | **passed (0.001 s)** |
| 2 | `testIC160A_RoundTripKeepsSurvivingSelection` | **passed (0.001 s)** |
| 3 | `testIC160A_FlowModelCarriesUnpublishedSelection` | **passed (0.002 s)** |
| 4 | `testIC160B_WiringAndExistingPinsHold` | **passed (0.008 s)** |

### 相关既有族（逐条 passed，0 失败）

| 族 | 条数 | 结果 |
|---|---|---|
| `IC147S0BehaviorTests` | 16 | 全过 |
| `IC148S0VisualTests` | 14 | 全过 |
| `IC151AmbientFixedColorTests` | 8 | 全过 |
| `IC152DiagnosticPathTests` | 6 | 全过 |
| `IC153ScanServiceTests` | 13 | 全过 |
| `IC155CategoryDataAndCoverTests` | 9 | 全过 |
| `IC156CategoryPageTests` | 11 | 全过 |
| `IC157LongPressIntoS2Tests` | 8 | 全过 |

### `testIC063…`（卡内要求贴 `building pipeline` 与 `IC063_WARMUP_GATE_END` 的先后）

`passed (6.351 seconds)`。块内 `Invalidating cache` **2** 条、`building pipeline` **1** 条：

```
2026-09-19T08:03:10.6186400Z 2026-09-19 08:03:10.505041+0000 PhotoCleanupMVE[17244:55418] [error] building pipeline path_exterior-jba6la8feba4 took 0.682526 seconds
2026-09-19T08:03:12.1038810Z IC063_WARMUP_GATE_BEGIN
2026-09-19T08:03:12.2612070Z 采样总数：12
2026-09-19T08:03:12.2628110Z 中间帧门禁：失败
2026-09-19T08:03:12.2629460Z 错误：双击进入 Nx：动画中间帧 少于 2 帧（实际命中 0 帧；进度回调 9 次，其中进度<1 的 7 次≈CADisplayLink 回调次数；首次进度回调相对过渡起始延迟 11.1 ms；诊断时长 1000 ms；进度样本：0.08,0.10,0.11,0.13,0.15,0.17）
2026-09-19T08:03:12.2760580Z IC063_WARMUP_GATE_END
2026-09-19T08:03:15.2855580Z IC063_DIAGNOSTICS_SAMPLE_BEGIN
2026-09-19T08:03:15.3261140Z 采样总数：15
2026-09-19T08:03:15.3305520Z 中间帧门禁：通过
```

**build 行落在 `IC063_WARMUP_GATE_END` 之前**（编译在预热里）。①本次是 IC-159 上线后**预热门禁第一次真的判「失败」**（0.68 s 编译吃掉整段进入动画、进入中间帧 0 帧），而计时导出照样 15 样本、门禁通过——正是 IC-159 裁定 二预料的形态（预热报告不做门禁断言、不残留到第二次）。本卡未改 `testIC063` 与产品动画，登记为旁证。

## 七之二、G908 前的项数与对账

| 项 | 值 |
|---|---|
| 基线 `main`（#319） | 852 |
| 本卡新增用例 | 4（断言 1～4） |
| 对账式 | 852 + 4 = **856** = #320 执行摘要与唯一用例身份计数 |

## 八、裁定的实装对照

| 裁定 | 卡内要求 | 实装 |
|---|---|---|
| 一 | 回来后 `SEL` = 进 S2 前的 `SEL` ∩ 回来后网格全部项；常驻行与主按钮按这份重算；返回首页才清空 | 交集在 `S0CategoryPageSelection.init(items:preselected:)` 里做；常驻行与主按钮仍由同一份 `selected` 算出（未动）；`onBack` 与 `onEnterCategoryPage` 各清空一次 |
| 二 | 保留集放 `S0CleanupFlowModel`、**不 `@Published`**；每次勾选变化都同步 | `var preservedSelection: Set<String> = []`（无属性包装器，断言 3 用 `objectWillChange` 计数钉住不发布）；页面 `.onChange(of: selection.selected)` 每次变化回报 |
| 三 | 页面与选择模型各加带默认值的口子；流程容器不加形参；出现时再回报一次 | 选择模型 `preselected: Set<String> = []`；页面 `initialSelection: Set<String> = []` 与 `onSelectionChange: … = { _ in }`（声明在 `onLongPress` 之后、`toastDurationMilliseconds` 之前）；流程容器 `init` 与存储属性段逐字未动（切块 diff 空）；`.onAppear { onSelectionChange(selection.selected) }` 已挂 |

## 九、G907 前置核对

| 项 | 结果 |
|---|---|
| G905（白名单 + 零改动 SHA 表 + 两段切块 diff 空） | 满足（第六节） |
| G906（被钉住的计数、常量数、冻结分支） | 满足（第六节 + 下表） |
| 绿：856 项 0 失败、真实退出码 0、执行摘要 notice | 满足（第七节） |
| 目的地实证行 `OS:26.2, name:iPhone 16` | 满足 |
| IPA 字节数与 SHA-256 | 满足（1 690 601 字节 / `81b5e42f…3a86`） |
| 分段耗时 notice | 满足（`65 s／288 s／354 s`） |
| 断言 1～4 逐条 passed | 满足 |
| `IC156`／`IC157`／`IC147`／`IC148` 相关用例逐条 passed | 满足（另含 IC151／IC152／IC153／IC155，共 85 条全过） |
| `testIC063…` passed + build 行相对 `IC063_WARMUP_GATE_END` 的先后 | 满足（6.351 s；build 行在 END **之前**） |
| pbxproj 撞号扫描 | 满足（187 个对象 id 唯一，新登记 `…61`／`…5E`） |
| 工作树净 | `git status --porcelain` 除未跟踪的 `Reports/IC-160/` 外为空；报告提交后再核一次 |
| `main` 未被他人推进 | 合并前 `git ls-remote origin refs/heads/main` = `d64b7f28286374099143c18565a326fc9f05d762`，与基线一致 |

### 冻结链与探针分支 tip（G906，`git ls-remote` 实读）

| 分支 | tip | 与既有记载 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 一致（`b368a6c`） |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 一致（`6736f1e`） |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 一致（`a7cc1ec`） |
| `feature/ic-158-diagnostic-progress-clamp` | `5cb67332437a446d98733ddc942e2905392d2891` | 一致（`5cb6733`），未合并、未删、未 cherry-pick |
| `probe/ic-137-media-playback` | `486bcb769b59eb1146c5a231c7998847206777cc` | 一致（`486bcb7`） |
| `probe/ic-145-scan-service` | `d373afc7125104c01acfc296829229090e6871ce` | 一致（`d373afc`） |
| `probe/ic-067-screenshot-subtype` | `9db02b93eccbb87d126602901807e70823535111` | 未进 `main`，未触碰 |

## 十、发现但未处理的问题（按纪律只报告不修）

1. **`S0CategoryPageSelection` 的类文档注释已与新行为不完全一致**①。`S0CategoryPageView.swift:5` 写着「全部项默认不勾选，不预勾任何项」——默认值路径仍然如此，但给了 `preselected` 就会预勾。该行在 `:5`，不在本卡白名单的 A1（`:12-14`）范围内，按纪律未改。建议随下一张动这个文件的卡一并订正。
2. **「切走再切回清理 tab 是否重建类别页」仍是③**。本卡按裁定 二做了持续同步，对任何重建路径都成立，但该路径本身未实证；H79 第 4 条会顺带覆盖一次（它要求切到「逐张整理」tab 再切回，且类别页还在）。
3. **保留集不区分类别**③。模型里只有一份 `preservedSelection`；跨类别的污染由「进类别时清空」与「播种时求交」两道拦住（不同类别的标识不会在另一个类别的列表里），但若日后出现同一资产同时属于两个类别的情形，勾选会跨类别带过去。本卡不改，登记备查。
4. **`.onAppear` 回报的时序依赖 SwiftUI**②。页面重建后 `.onAppear` 与 `.onChange` 的先后由框架决定；两者写的是同一份值，先后不影响最终收敛值。模拟器夹具钉不住（未装载视图层），由 H79 第 1、4 条兜底。
5. 既有 `IC156CategoryPageTests.swift:24` 仍用 `S0CategoryPageSelection(items:)` 的旧写法（默认值保证其可编译）——**本卡未改任何既有测试文件**，符合卡内要求；但这意味着「默认值路径」的正对照同时由 IC-156 断言 5 与本卡断言 1 覆盖，二者重叠。登记备查。

## 十一、人工判定项（H79 四条，留给 Lynn 真机，执行端不代为下结论）

装合并后 `main` 的产物。

1. **不标记往返**：类别页勾 3 张 → 长按另一张没勾的进 S2 → 什么都不标、直接返回 → 回到类别页，那 3 个勾仍在，常驻行与主按钮数字仍是 3 项。
2. **标记往返**：勾 3 张 → 长按进 S2 → 在 S2 里上滑标记其中一张**已勾的** → 返回 → 那一格消失，其余 2 个勾仍在，数字是 2 项；点「移入待删篮」正常。
3. **回首页即清空**：点返回圆钮回首页，再进同一类别——勾选为空（与改前一致）。
4. **移出待删篮的那张不会自动带勾**：勾 a、b 两张 → 长按进 S2 标记 b → 返回（**不碰任何格**）→ 切到「逐张整理」tab 进 S3，把 b 移出待删篮 → 切回清理 tab（类别页还在）→ 再长按任一张进 S2、直接返回 → b 重新出现在网格里，**不带勾**；a 的勾仍在。

## 十二、合并与 G908

待填。

## 十三、40 位 SHA 核验（陷阱 15）

待填。
