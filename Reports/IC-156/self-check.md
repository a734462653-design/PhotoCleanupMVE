# IC-156 自验报告

## 一、结论（先行）

- **四个子项都已交付**，顺序 A → B → C → D，各自独立 commit：A `55f2819`（登记表 `S0CategoryPageMetrics` 42 个常量与符号、虚拟范围前缀）、B `bf27109`（`S1StateMachine.markPendingDeletion` 会话层原子写入口）、C `0fb15af`（类别页视图、选择模型、toast、五条文案、既有断言改口径五处）、D `c92c641`（承载容器 `S0CleanupFlowView` 与 App 接线）。克隆仓库实测：A 单独、A→B、A→C、A→B→C→D 无冲突；**卡内写的「B 单独」「B→A→C→D」实测冲突**（第 7.4 条）。
- **CI #313**（run id `35189147747`，被测提交 `c92c641dae3da60d020af1ee20be67dd9d4b9b0e`）：**attempt 1 红，只红已知计时脆弱用例** `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`（`:4146` 门禁 + `:4154` 中间帧 0 < 2），844 项 843 过、退出码 65；IC-156 十一项与卡内点名的既有用例全部 passed。**同一提交原样复跑 attempt 2 绿**：12 个步骤全 success、真实退出码 **0**、**844 项 0 失败、1 个 launch**（无宿主重启）、目的地 `OS:26.2, name:iPhone 16`、IPA **1679665 字节**、SHA-256 `3621bc6c168a9e4a13e7ced6f1e7ed96bf8377fc8156c035464d44f9575ae10f`、分段耗时「模拟器启动 59 s；xcodebuild test 243 s；总 303 s」，`testIC063…` passed（3.104 s）。项数对账 **833 + 11 = 844** ✔。分支 CI 预算 3 次用 **2** 次（a1 + 原样复跑 a2，零代码改动）。
- **断言 1～11 全部 `passed`**（第五节逐条给函数名与耗时）；IC-147 16／16、IC-148 14／14、IC-155 9／9、IC-151 8／8、IC-153 13／13、IC-132 9／9、IC-127 26／26、IC-129 6／6 逐条 `passed`（a1 与 a2 各自核）。
- **G887～G889 满足，G890 满足**（第九节；G890 的「绿」取 a2，a1 的红逐条核实只属 `testIC063…`）。**已按卡内授权 `--no-ff` 合并入 `main`：合并提交 `c42edd1ded6ccd1e7ec0d17b2e3745560cdbfa78`**（父 `cc686d9` 与报告提交 `8504a7d`），合并树与 `8504a7d` 的树同一对象（`5327beb6…`）。**G891**：合并后 `main` 自动运行 **#314**（run id `35190738456`）attempt 1 **一次绿**——844 项 0 失败、1 个 launch、真实退出码 0、`OS:26.2, name:iPhone 16`、IPA 1679665 字节、分段耗时「模拟器启动 118 s；xcodebuild test 413 s；总 532 s」（第九节 G891）。
- **卡内有四处条文与正确实现冲突或自相矛盾（第 7.1～7.4 条），另有六处实现取舍、卡面留白或坐标偏差（第 7.5～7.10 条），都已按卡的意图或卡内兜底条款落实，请决策会话追认**。影响交付形态的是两处：**NavigationStack 根页同样隐藏系统导航栏**（第 7.2 条，③ 不隐藏会把首页整体下推一个导航栏高度；流程文件里该串因此 2 处，卡面断言 10 写「恰 1」）；**摘取单元 B 单独不成立**（第 7.4 条，B 往 A 新建的测试文件末尾追加，产品改动本身可单独摘取）。
- **人工判定项 H77 七条原样保留给 Lynn**（第十三节），执行端不代为下结论。版式、勾选手感、滚动时的缩略图、toast 观感、进篮后首页数字同步、S3 组头、冷启动后类别组仍在，**模拟器上一律未覆盖**（夹具驱动，陷阱 1、23）。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260916-156-category-page.md`（本机 `sha256sum` = `e7453fe880d8cbf472f8d3577f7e8b759ef85ec30e7734e0a60a1864cf6051ef`） |
| 规格 | SPEC-S0 v2（`sha256sum` = `8a8e222a7f203c6c92dc8e755338cded8673f7de76c7b6290da696d4058d6f44`）、SPEC-S1 v9（`15272907c85731bae9c076a507582539dff1999191d1b19e3d275031ea23bbd6`）、SPEC-S3-S4 v8（`ba1a911784260682a8bff14db8770616f352f5ba8219adbb43d093abaa2d38f1`），均与 CLAUDE.md 基线行一致 |
| 画布 | `<top>/Tasks/design-s0/dark.py`（`sha256sum` = `dc36cd36dcd7898df70b8c7b3343fcfd5636878ede4bf0aa801ac1e4b08f0e62`），第 15～45 行样式与第 82～93 行网格数据逐项对读 |
| 基线 `main` | `cc686d92d29ba4adcc41607983ae47a199179be7` |
| 开工核对 1 | `git status --porcelain` **空**（纪律 8），当前分支 `main`、HEAD = `cc686d9` |
| 开工核对 2 | `git merge-base --is-ancestor 07b7f76 main` 退出码 **0** ✔ |
| 开工核对 3 | `git ls-remote origin refs/heads/main` 退出码 0，= `cc686d92d29ba4adcc41607983ae47a199179be7` = 本地 ✔ |
| 分支 | `feature/ic-156-category-page`（自 `cc686d9` 切出） |
| 分支 tip（代码） | `c92c641dae3da60d020af1ee20be67dd9d4b9b0e` |
| 现状基数 | 833 项（CI #312 attempt 2）→ 本卡 **844** 项 |
| `schemaVersion` | **7，未动**；`S0ScanRules.cacheSchemaVersion` **1，未动**；`S0HomeMetrics` **52，未动** |

**惯例 13／37 复核**（卡内「事实基础」「定位坐标」两表在 `cc686d9` 上实读，`<scratchpad>/ic156/coords.py` 逐条取行号窗口找目标文本，共 52 处）：51 处一致——`S0View.swift:492-498`（点类别行 → `handle(.categoryRowTapped)` → `onEnterCategoryPage`）、`App:87-95`（`s0Screen()`）、`S0StateMachine.swift:240`／`:458-461`（`.returnedFromCategoryPage`）、`S0TabContainer.swift:65-86`、`IC147…:138-140`（容器不引用协调器／会话层）、协议 `S0View.swift:10-23`、`S0CategoryAsset` `:114-122`、服务记忆化 `:109-145`、`SessionStore` `:1`／`:3`／`:70`／`:72`／`:90`／`:148-176`、`S1StateMachine` `:284-286`／`:306`／`:516`／`:542-546`／`:635-669`／`:678-680`／`:693-695`、`IC132SubmissionDeadEndTests:118`／`:138`、`FullFlowRoutingTests:164`、`S3View:12-21`／`:725-727`、`S1View:14-35`／`:56-65`／`:542`／`:585`／`:711-761`／`:865-877`、`S0View:146-176`／`:634-636`、`S2Calibration:874`、`App:30-33`、`ThumbnailView:52-58`、`L10n:4-7`、`S0View:27-34`／`:38-52`／`:520-533`、`IC147:797`／`:822-828`／`:843`／`:851-854`／`:159-182`、`IC148:840`／`:843-845`、`IC129:271`（脚本初判 3 处未命中，其中 2 处是我写的检索串问题——`func reconcile(` 在 `:516` 是多行声明、`S0CategoryText` 的 `enum` 行在 `:37` 而卡引的 `displayName(for:)` 正在 `:38-52`——逐行人工复核后一致）。**1 处出入**：`machine.category(id)` 实在 `Core/S0StateMachine.swift:341`（卡写 `:325`），签名与卡一致、不影响落点。数值事实逐项一致：`S1ChromeLayout` 44／3／16／8、`S1ChromeTypography` 15／17、`S2OverlayLayout.minimumSpacing` 8、`feedbackToastDurationMilliseconds` 出厂 2000、`S0TabContainer.swift` 内 `.tabItem` 2／`TabView(` 1、`s0.` key 32、App 入口 `feedbackToastDurationMilliseconds` 2 处、pbxproj 最大 id `…5A`／`…57`。

**范围边界**：10 个路径全在白名单内（`change-list.md` 第二节）；不得触碰清单两侧 blob SHA-256 相同（第九节 G887）；`Scripts/`、`.github/`、`Services/`、`Features/S1～S5`、`Features/Shared/` 目录 diff 为空。

---

## 三、实现要点

### 3.1 子项 A：登记表

- `Features/S0/S0CategoryPageMetrics.swift`：42 个 `static let`，5 个注「SPEC-S0 v2 第十四节第 2 部分」、37 个注「画布 dark.py 类别页（Decision_log 第 183 条补登，SPEC-S0 v3 第十四节回写）」，值与卡内清单逐个相等（`gridColumns` 为 `Int`，7 个不透明度为 `Double`，其余 `CGFloat`）；顶排与颜色不在此登记。同文件三个符号名与 `cat:` 前缀。`S0HomeMetrics.swift` 一字未动。

### 3.2 子项 B：会话层写入口

- `markPendingDeletion(assetIDs:virtualRangeID:displayName:)`：空输入 → false、零副作用；否则副本上逐个 `setMarked(true, …)`、登记名字、最后一次赋值 `sessionStore`（持久化写出口恰 1 次）。无状态／遮挡门槛。只增 31 行、删 0 行。

### 3.3 子项 C：类别页

- **选择模型** `S0CategoryPageSelection`：常驻行与主按钮取**同一组**占位符取值（同一份 `selected` 算出），规格第六节「已选计数与主按钮数值恒相等」由结构保证；「全选」一项未选 → 全选，否则全不选；进篮成功 `remove(ids:)` 保序删项。
- **版式**：氛围底 → 顶排（S1 chrome 零新数）→ 大标题与副行 → 常驻行（右侧留空）→ 三列 `LazyVGrid`（边长经 `GeometryReader` 按登记值算，裸数只有 0／1／2）→ 底部渐隐 + toast + 主按钮。**只有网格滚动**，顶排、标题、常驻行固定；网格底部留 `ctaBottomInset + ctaHeight`，滚到底最后一行在主按钮之上；主按钮与渐隐忽略底部安全区，按钮底缘距屏底 42（登记值含安全区 34）。
- **交互**：点格切换；主按钮零选中 `.disabled` + 不透明度 0.35（不隐藏）；进篮回调返回 true 才删项、清空已选、出 toast（时长参数）。
- **toast** `S0FeedbackToastPresenter`：照 S1 形状（新替旧、按代际到期、注入调度器）；毫秒换秒走 `Measurement`（第 7.9 条）。
- **格** `S0CategoryGridCell`：`ThumbnailView(…, showsPlaceholderGlyph: false)` + 体积标签、视频时长角标（`DateComponentsFormatter`）、圆圈勾、选中白外圈；缩略图视图自己先框后裁，格内不包 `scaledToFill`（陷阱 24）。
- **文案**五条只增；**C3** 五处按裁定 六改口径。

### 3.4 子项 D：承载与接线

- `S0CleanupFlowView`：`NavigationStack` 内原样构造 `S0View`，`onEnterCategoryPage` 写 `presentedCategory`，`navigationDestination(item:)` 推类别页（隐藏 tab bar 与导航栏）；进篮成功后立刻 `ingest`；`presentedCategory` 非 nil → nil 时 `ingest` 再 `handle(.returnedFromCategoryPage)`。根页也隐藏导航栏（第 7.2 条）。
- App 入口：只改 `s0Screen` 与 `cleanupContent` 一行；虚拟范围 `S0CategoryPageRange.prefix + rawValue`、显示名 `S0CategoryText.displayName(for:)`、toast 时长与 S1 同一读法。

---

## 四、CI 与项数对账

### 4.1 #313 的完整事实

| 项 | attempt 1 | attempt 2（原样复跑） |
|---|---|---|
| run id ／编号 | `35189147747` ／ **#313**，事件 `push`，分支 `feature/ic-156-category-page` | 同左 |
| 被测提交 | `c92c641dae3da60d020af1ee20be67dd9d4b9b0e`（分支 tip，含全部四个代码提交） | 同左 |
| 复跑请求 | — | 06:23:58Z `POST repos/…/actions/runs/35189147747/rerun`，返回 `{}`、退出码 0 |
| check-run id（各自现取） | `105097625630` | `105099176228` |
| 作业 | 06:17:03Z → 06:22:06Z，**failure** | 06:24:04Z → 06:31:21Z，**success**（7 分 17 秒，作业级时限 30 分钟之内） |
| 步骤 | 1～8 success；「运行 XCTest」（步骤 9）06:17:17Z → 06:21:57Z **failure**（注解 `Process completed with exit code 65.`）；「构建未签名应用」「上传可下载的未签名 IPA」skipped；Complete job success | 12 个步骤（含 Set up job／Complete job）全 success；「运行 XCTest」06:24:55Z → 06:29:59Z（5 分 4 秒，步骤级时限 25 分钟之内），步骤以 `exit "$test_status"` 原样退出、结论 success，且日志有 `XCTest 已全部通过。`（`Scripts/test-xcode.sh:104-108`：xcodebuild 非 0 即原样退出，只有 0 才打印这一行）⟹ 真实退出码 **0**；「构建未签名应用」06:29:59Z → 06:31:09Z；「上传可下载的未签名 IPA」→ 06:31:11Z |
| 工具链 | `Xcode 26.3`，`Build version 17C529` | 同左 |
| 模拟器 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` | 同左 |
| 执行摘要 notice | `Executed 844 tests, 1 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 844 tests / 2 failures` | `Executed 844 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 844 tests / 0 failures` |
| 分段耗时 notice | `模拟器启动 62 s；xcodebuild test 214 s；总 279 s` | `模拟器启动 59 s；xcodebuild test 243 s；总 303 s` |
| IPA 校验 notice | 无（打包步骤 skipped） | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1679665，SHA-256=3621bc6c168a9e4a13e7ced6f1e7ed96bf8377fc8156c035464d44f9575ae10f`；artifact `PhotoCleanupMVE-unsigned-c92c641dae3d`，id `10484071778`，zip 1679835 字节 |
| 注解 | failure 5 条（退出码、`** TEST FAILED **`、`:4154`、`:4146`、`Test Case … failed (3.187 seconds)`）+ notice 2 条 | 仅上述 3 条 notice；error／warning **0** 条 |

### 4.2 实证行（整包日志 zip，`unzip -tq` 校验通过后解析；先剔 `##[` 注解回显与 `[36;1m` 脚本源码回显，陷阱 25；zip 内根目录的整作业日志与「运行 XCTest」步骤日志内容重复，计数按单个文件取）

**attempt 1**（zip 203 558 字节）：

- 目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- `Executed 844 tests, with 2 failures (0 unexpected) in 31.605 (33.007) seconds`；`** TEST FAILED **`
- `Test Suite 'All tests' started` 每个日志文件 **1** 次；`Restarting after unexpected exit` **0** 次（无宿主崩溃重启）
- 唯一 `Test Case` 身份 **844**：passed **843**、failed **1** = `S2CalibrationHarnessTests.testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`（3.187 s）
- `.swift:<行>: error` 形状的行 **2** 条（去重后），均属该用例：`S2CalibrationHarnessTests.swift:4146: … XCTAssertTrue failed`、`:4154: … XCTAssertGreaterThanOrEqual failed: ("0") is less than ("2")`

**attempt 2**（zip 244 998 字节）：

- 目的地：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- `Executed 844 tests, with 0 failures (0 unexpected) in 30.804 (31.343) seconds`；`** TEST SUCCEEDED **`；`XCTest 已全部通过。`
- `Test Suite 'All tests' started` 每个日志文件 **1** 次；`Restarting after unexpected exit` **0** 次
- 唯一 `Test Case` 身份 **844**：passed **844**、failed **0**，无重复身份
- `.swift:<行>: error` 形状的行 **0**
- `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` passed（3.104 s）
- `未签名 IPA 已生成：1679665 字节，SHA-256=3621bc6c168a9e4a13e7ced6f1e7ed96bf8377fc8156c035464d44f9575ae10f`

### 4.3 项数对账

| 来源 | 项数 |
|---|---|
| `main` 基数（CI #312 attempt 2） | 833 |
| 本卡新增（`IC156CategoryPageTests`，11 个 `func test`；本机 `grep -n "func test"` 11 行，无注释行干扰） | +11 |
| 期望 | **844** |
| #313 a1 唯一 Test Case 身份 | **844**（843 ／ 1） |
| #313 a2 唯一 Test Case 身份 | **844**（844 ／ 0） |

### 4.4 a1 红的归因与 CI 预算

**归因（①＋②）**：① 本卡 diff 不含 `Features/S2/` 与 `S2CalibrationHarnessTests.swift`（`change-list.md` 第二节文件清单与零改动表）；① 失败形态是 `:4146` 中间帧门禁 + `:4154` 中间帧计数不足（本次 0 < 2），与 IC-155 报告第九节记下的 IC-151 #302a1、IC-154 #310a1、IC-155 #312a1 三次同形，这是该用例在零相关改动下单独判红的**第四次**实例；② 同一提交原样复跑 a2 上该用例 passed（3.104 s），全量 844 项 0 失败。
**预算（纪律 2）**：分支上 3 次预算用 2 次——#313 a1（红于上述用例）与原样复跑 a2，两次均未改动任何代码。推 CI 前的本机预验证见第八节（Python 移植累计 258 项 0 失败）；另请一个独立会话只读核编译面与必红断言（逐个符号对声明、SwiftUI 重载、测试侧构造与期望值），结论**无确定或很可能的编译错误、无必红断言**，只标一条低风险——类别页文件只 `import SwiftUI` 却用了 Foundation／Combine 的类型（仓内无先例）；#313 a1 编译通过，该风险已由 CI 排除。

---

## 五、逐条验收门禁与测试函数名（#313 a1 与 a2 均 `passed`）

| 断言 | 子项 | 测试函数 | 耗时 a1（s） | 钉住的结果 |
|---|---|---|---|---|
| 1 | A | `testIC156A_RegistryHasFortyTwoConstantsWithProvenance` | 0.005 | 登记表切片 `\n    static let ` 42、`取值出处：` ≥ 42、v2 出处 5、画布出处 37；剔注释切片内 `S1ChromeLayout`／`rowHeight`／`horizontalMargin` 各 0 且 `static let` 仍 42（正对照）；`S0HomeMetrics` 切片 52、`gridColumns` 0 |
| 2 | A | `testIC156A_MetricsValuesMatchCanvas` | 0.001 | 42 个值逐个 `accuracy: 0.000_001`（`gridColumns` 精确）；`prefix == "cat:"`；三个符号名 = `chevron.left`／`play.fill`／`checkmark`，非空 ASCII |
| 3 | B | `testIC156B_MarkPendingDeletionWritesAtomicallyAndRegistersName` | 0.001 | `["a","b","c"]` 进 `cat:bigVideo`：`M`、三个 `F`、`D_全部`、`badgeCount == 3`；`persistenceSink` 恰 1 次且快照名字表含类别名；`makeS3Submission()` 非 nil、`cat:bigVideo` 组名「大视频」、`orderedAssetIDs` = a、b、c；空集合／空范围／空名各 false 且 sink 不再被调 |
| 4 | B | `testIC156B_FirstMarkerWinsAndExistingRangesUntouched` | 0.006 | `a` 先进 `range-x`；再 `["a","d"]` 进 `cat:screenshot`：`F[a]` 仍 `range-x`、`F[d]` = `cat:screenshot`；两组计数和 = `D_全部`；`rangesOutsideOrder` ≥ 1（已知后果）；注入存在性探针剔 `d` 后经 `reconcile(with: .success)`：`d` 出 `M`／`F`、`cat:screenshot` 组消失、`M[cat:screenshot]` = [a]、提交仍非 nil |
| 5 | C | `testIC156C_SelectionModelInvariants` | 0.001 | 六条资产（c、d 同 500 字节）：初始空、禁用、字节 0、总和 3000、零选中 `count` = `"0"`；点两次回原状、未知标识不理会；全选一次全选、再一次全空、部分选中点也全空；固定种子 20 组子集已选字节恒等于所选之和、占位符取值一致；`remove(ids:)` 保序（a、c、e、f）、已选与删除集不相交；移走全部已选后空、禁用、`count` = `"0"` |
| 6 | C（D 追加流程文件） | `testIC156C_PageFilesKeepS0Discipline` | 0.046 | 页面与流程两文件：剔注释数值字面量 ⊆ {0,1,2}、PhotoKit 七个 needle 各 0、恒深色七个 needle 各 0、原文 `Text("` 0；页面：`machine.handle(`／`beginVerification` 0、`s1ChromeCircleGlass()` ≥ 1、`s1ChromeGlassBackground(` ≥ 1、`S1ChromeLayout.` ≥ 3 且四个成员各 ≥ 1、`S1ChromeTypography.titleFontSize` 1 + helper 内 `circleIconPointSize` 1（第 7.3 条）、`S0CategoryPageMetrics.` 57 且 42 个名字各 ≥ 1（第 7.5 条）、`ThumbnailView(` 1、`showsPlaceholderGlyph: false` 1、`S2AmbientBackdropView()` 1、`DateComponentsFormatter` ≥ 1、`Image(systemName: ` 3 且全经 `S0CategoryPageSymbol.`；正对照 `S1View.swift` `Material` > 0、`ThumbnailView.swift` `PHAsset`／`import Photos` > 0 |
| 7 | C | `testIC156C_CatalogGainsFiveKeysAndBothGatesAreUpdated` | 0.009 | 目录 `s0.` 37、`s0.categoryPage.` 5；五条值逐字等于裁定 五；每条在页面原文被 `L10n.text("<key>"` 引用 ≥ 1，页面引用的 key 集合恰为这五条；`{count}`／`{bytes}` 各恰出现在副行、常驻行、主按钮三条；IC-147、IC-148 测试原文含 `S0CategoryPageView.swift` |
| 8 | C | `testIC156C_ToastPresenterReplacesAndExpiresByGeneration` | 0.002 | 注入调度器：A → B 替换；先触发 A 的到期仍为 B；触发 B 的到期 → nil；`presentedCount` 2；`lastScheduledDurationSeconds` 与两次调度延时均 = 2（±1e-6）；负时长 → 0 |
| 9 | C | `testIC156C_DurationAndByteTextsAreFormatterDriven` | 0.008 | `761 → "12:41"`、`62 → "01:02"`、`0 → "00:00"`、`-5 → "00:00"`；页面原文不含 `" GB"`／`" MB"`／`":"`；剔注释页面引用 `S0ByteCountText.string(forByteCount:` 与 `S0CategoryPageDurationText.string(for:` 各 ≥ 1 |
| 10 | D | `testIC156D_FlowHostsHomeAndPageAndAppOnlySwapsBuilder` | 0.006 | 剔注释流程文件：`S0View(` 1、`NavigationStack` ≥ 1、`navigationDestination(item:` 1、`.returnedFromCategoryPage` 1、`machine.ingest(` 2、`.toolbar(.hidden, for: .tabBar)` 1、`.toolbar(.hidden, for: .navigationBar)` **2**（第 7.2 条）、`S0CategoryPageView(` 1、`CleanupCoordinator`／`SessionStore`／`S1StateMachine` 各 0；剔注释 App：`S0CleanupFlowView(` 1、`S0View(` 0、`markPendingDeletion(` 1、`S0CategoryPageRange.prefix` 1、`S0CategoryText.displayName(for:` ≥ 1、`feedbackToastDurationMilliseconds` 3、`s0Screen(s1Machine: s1Machine)` 1、`advanceScan()` 2、`onSnapshotDidChange` 1、`S0ScanOutcomeTransition.events(` 1、`S0TabContainer(` 1、`tabContainer(s1Machine: machine)` 1；按卡面 D1 形参顺序构造一次（编译期核签名） |
| 11 | D | `testIC156D_ReturnRecomputesAndCanLandOnEmpty` | 0.001 | 真实状态机 + 桩 `.readyWithItems`：扫描完成重排 1 次、`.ready`；点大视频 → `.categoryPage(.bigVideo)`；摄入 `.readyWithoutItems` 快照后返回 → `.home(.empty)`、重排仍 1；对照：不进篮直接返回 → `.home(.ready)`、快照与进去前相等 |

**既有相关用例（a1 与 a2 逐条 `passed`）**：`IC147S0BehaviorTests` 16／16（含 C3 改口径的 `testIC147CAssertion10ForbiddenWordingNeverAppears`、`testIC147CAssertion11EveryS0StringGoesThroughTheCatalog`，以及钉 App 路由分支的 `testIC147AAssertion03RouteBranchesOtherThanS1AreByteIdentical`）；`IC148S0VisualTests` 14／14（含 C3 改口径的 `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys`，与断言 1／2／3／4／7／11／14）；`IC155CategoryDataAndCoverTests` 9／9；`IC151AmbientFixedColorTests` 8／8（含 `testIC151D_S0BehaviorCallSitesUnchanged`）；`IC153ScanServiceTests` 13／13（含 `testIC153C_AppWiringAndS0ViewUntouched`）；IC-132 会话层 `IC132S1RangeNamePersistenceTests` 4／4（含 `testIC132A_NewRangeNamesPublishExactlyOnceThroughSingleSink`）与 `IC132SubmissionDeadEndTests` 5／5；IC-127 全部 26 项（会话层 `testIC127B_*` 6、`testIC127C_*` 6、`testIC127E_*` 2，另 `testIC127A_*` 7、`testIC127D_*` 5）；`IC129ExistenceReconciliationTests` 6／6。

---

## 六、既有断言改口径（裁定 六）

| 断言 | 文件:行（`cc686d9`） | 旧 | 新 | 结果 |
|---|---|---|---|---|
| IC-147 断言 10 | `IC147S0BehaviorTests.swift:797` | `XCTAssertEqual(s0Values.count, 32)` | `37`（上方加一行注释） | a1／a2 `testIC147CAssertion10ForbiddenWordingNeverAppears` passed；五条新值不含「已释放」「已清理」「已节省」 |
| IC-147 断言 11 | `:822-828` 文件名单 | 三文件 | 加 `"PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift"`（注释写明 IC-156） | a1／a2 `testIC147CAssertion11EveryS0StringGoesThroughTheCatalog` passed；Python 重算：四文件引用的 `s0.` 集合 = 目录 37 条、跨前缀仅 `s1.limited.banner`、四文件 `Text("` 各 0 |
| IC-147 断言 11 | `:843` | `XCTAssertEqual(catalogS0Keys.count, 32)` | `37`（加一行注释） | 同上 |
| IC-148 断言 10 | `IC148S0VisualTests.swift:840` | `32` | `37`（加一行注释） | a1／a2 `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` passed |
| IC-148 断言 10 | `:843-845` 文件名单 | `viewFiles` + 容器 | 再加页面文件（注释写明 IC-156） | 同上；Python 重算五文件引用的 `s0.` 集合 = 目录 37 条 |
| 其余 | — | — | **一条未改** | `IC147S0BehaviorTests.swift` diff 恰 3 个 hunk、`IC148S0VisualTests.swift` 恰 1 个 hunk（`change-list.md` 第二节）；其余测试文件两侧相同 |

---

## 七、卡内问题与按结果落实的地方（逐条写明，请决策会话追认）

### 7.1 「C 的追加放在类首（断言 3 之后）」自相矛盾 → 放在类首、断言 1 之前

断言 3 是 B 追加在**类末尾**的；照「断言 3 之后」放，C 与 B 的追加相邻，A→C 不经 B 就会冲突，与同一句「让 A→C 不经 B 也无冲突」矛盾。落实：C 段（断言 5～9 与其 helper）插在类首、断言 1 之前；D 段紧接 C 段之后；B 在类末尾。克隆实测 A→C 无冲突（树 `361bef2ebc3772ada2a3c386c95aabd0475db4e2`，`change-list.md` 第一节）。测试执行顺序与文件内位置无关。

### 7.2 NavigationStack 根页同样隐藏系统导航栏 → 断言 10 的该串按实装写 2（卡面「恰 1」）

- 裁定 二只写了「类别页上 `.toolbar(.hidden, for: .tabBar)` 与 `.toolbar(.hidden, for: .navigationBar)`」，断言 10 钉 `.toolbar(.hidden, for: .navigationBar)` 恰 1；同一裁定要求 `S0View` 原样、首页行为与几何不变。
- ③ 推测：`NavigationStack` 的根页不隐藏导航栏时，系统为（空的）导航栏保留顶部安全区；`S0View` 的滚动内容按安全区排版（`S0View.swift:119-137` 的 `scrollingContent` 顶部只有 `.padding(.top, S1ChromeLayout.topRowTopInset)`），首页顶排与其下全部卡片会整体下移至少一个导航栏高度——H76／H71 已判过的首页几何因此改变。模拟器离屏夹具测不到（陷阱 23），**未取证**。
- 落实：根页 `homeScreen` 也加 `.toolbar(.hidden, for: .navigationBar)`（流程文件第 47 行；类别页那一处在第 90 行），断言 10 写 2 并注释理由；tab bar 只在类别页隐藏。验证：H77 第 1 条（返回首页）与第 7 条（首页四态快过）真机看首页顶排位置与改前一致。**若决策会话认为根页应保留系统导航栏，删第 47 行即回到卡面形状**，断言 10 同步改回 1。

### 7.3 断言 6「`S1ChromeTypography.` ≥ 2」在按裁定 四公式的实装上不可达 → 改钉两处实际取值点

裁定 四的公式是「返回圆钮 = `Image(systemName: S0CategoryPageSymbol.back)` + `.s1ChromeCircleGlass()`（字号 `circleIconPointSize`）」；而 `s1ChromeCircleGlass()`（`S1View.swift:585-597`）内部已 `font(.system(size: S1ChromeTypography.circleIconPointSize, weight: .semibold))`，首页人像圆钮（`S0View.swift:168-172`）也不另写字号。照公式实装，页面文件里 `S1ChromeTypography.` 只剩「全选」胶囊一处；为凑够 2 再写一遍字号属于为测试改产品（纪律 4）。落实：断言 6 改钉 `S1ChromeTypography.titleFontSize` 在页面里 1 处，并切出 S1 的圆钮 helper 钉其中 `S1ChromeTypography.circleIconPointSize` 1 处——两个字号都取自 S1 这一结果钉住，不放宽。

### 7.4 摘取单元「B 单独」「B→A→C→D」不成立 → 如实报告（惯例 40 同类）

卡内摘取关系写「可摘取单元：A 单独、B 单独、A→C、A→B→C→D（也可 B→A→C→D）」，同一段又要求「新测试文件在 A 创建，B、C、D 各自追加，B 的追加放在文件末尾」。B 的提交因此改了一个基线上不存在的文件：克隆内 `cherry-pick bf27109` 到 `cc686d9` 判 `DU PhotoCleanupMVETests/IC156CategoryPageTests.swift`（主仓库 `git merge-tree --write-tree --merge-base=55f2819 cc686d9 bf27109` 同样报 `CONFLICT (modify/delete)`），B→A→C→D 停在第一步。B 的**产品改动**（`Core/S1StateMachine.swift` 一个方法）不依赖 A，在冲突的那次摘取里就已干净暂存；按文件摘取成立，按提交整体摘取不成立。同一机制在 IC-155 的克隆实测里也出现过（该卡 B 单独、C 单独都因往 A 新建的测试文件追加而冲突，IC-155 `change-list.md` 第一节），只是那张卡没有把它们列为可摘取单元。

### 7.5 断言 6「`S0CategoryPageMetrics.` ≥ 20」→ 按实装数写死 57，并逐个核 42 个名字

卡内注明该下限是③估计、执行端按实装数写死。实测剔注释页面文件 57 处；另切出登记表取 42 个名字，逐个钉「页面里 `S0CategoryPageMetrics.<名>` ≥ 1」——登记了但没用的死值会判红。

### 7.6 选中态对勾的字号：登记表缺口 → 取同格体积标签的登记字号

裁定 四的勾：「22 圆、描边 1.5 白 0.90、未选底黑 0.25，选中白底 + 深色勾」，没有勾本身的尺寸；画布 `.chk.on::after` 是 CSS 画的 5×9 描边勾（非字形、无字号）。本卡符号登记为 SF Symbol `checkmark`，须有字号；裸数纪律下只能取登记值。落实：取同格体积标签的 `gridSizeLabelFontSize`（11）、粗体、`S2AmbientMetrics.baseColor`，代码注释写明是登记表缺口。视觉由 H77 第 2 条兜底；建议 SPEC-S0 v3 补登（例如 `gridCheckGlyphSize`）或明文规定取值。

### 7.7 定位坐标一处偏差

`machine.category(id)` 实在 `Core/S0StateMachine.swift:341`（卡写 `:325`），签名 `func category(_ identifier: S0CategoryIdentifier) -> S0CategorySnapshot?` 与卡一致。其余 51 处坐标一致（第二节）。

### 7.8 toast 的底、字色与位置：卡面只给了字号与内距

- 底：S1 叠层用 `.background(.regularMaterial, in: Capsule())`，本卡 C-c 纪律要求页面零 `Material`、玻璃只经 S1 helper → 用 `.s1ChromeGlassBackground(in: Capsule())`（与首页胶囊同一 helper）。
- 字色：S1 叠层不设前景色（跟随系统外观）；本页恒深色，改为显式 `S0HomePalette.text`。
- 位置：S1 叠层锚底部安全区；本页底部是主按钮，toast 放在主按钮正上方、间距 `S2OverlayLayout.minimumSpacing`，不压主按钮、不接触控。H77 第 4 条兜底。

### 7.9 毫秒换秒不写 1000

`S1FeedbackToastPresenter` 写 `/ 1_000`；类别页文件裸数只许 0／1／2，改用 `Measurement(value:unit: UnitDuration.milliseconds).converted(to: .seconds)`。断言 8 钉 2000 ms → 2 s（±1e-6）。

### 7.10 断言在卡面之上的加严（只加不减）

断言 5 加「未知标识不理会」「部分选中点全选 → 全空」；断言 6 加 `S1ChromeLayout` 四个成员各 ≥ 1、42 个登记名逐个被引用、符号名全经 `S0CategoryPageSymbol`、PhotoKit 正对照；断言 7 加「页面引用的 key 恰为五条」；断言 8、9 加负时长；断言 10 加 `s0Screen(s1Machine: s1Machine)` 1 与按 D1 形参构造一次；断言 11 加「不进篮直接返回」的对照路径。卡面要求的每一条原样保留。

---

## 八、Python 预验证比对清单（推 CI 前，本机）

`<scratchpad>/simscan.py`（`strippedSource`／`occurrences`／`slice`／`numericLiterals`／`localizationKeys` 手工移植）与 `ic156/sim156.py`（+ `sim156_b.py`／`_c.py`／`_d.py`）：选择模型、`SessionStore` 标记模型、S0 状态机迁移与各断言的源码扫描口径。**移植与 Swift 实现的任何分歧都是移植偏差，下表是②样本观察，不构成测试会通过的证据；权威结论只取 CI。** 分阶段累计：A 15 项、A+B 42 项、A+B+C 192 项、A+B+C+D **258 项，0 失败**。

### 8.1 断言 5（夹具 → Python → Swift 期望 → CI）

夹具：a 900（视频 761 s）、b 700（视频 62 s）、c 500、d 500、e 300（视频 5 s）、f 100。

| 情形 | Python | Swift 期望 | CI |
|---|---|---|---|
| 总字节／初始已选 | 3000／∅ | 同 | passed |
| 点 c 两次；点未知标识 | {c} → 回原状；不变 | 同 | passed |
| 全选／再点／部分选中点 | {a…f}（字节 3000）／∅／∅ | 同 | passed |
| 固定种子 156 的 20 个掩码（高 6 位） | 57、45、20、34、40、9、9、1、10、47、11、62、45、24、30、22、43、11、8、5 | 同一线性同余式 | passed |
| 掩码 → 已选与字节（节选） | 57 → {a,d,e,f} 1800；45 → {a,c,d,f} 2000；34 → {b,f} 800；1 → {a} 900；47 → {a,b,c,d,f} 2700；62 → {b,c,d,e,f} 2100；8 → {d} 500；5 → {a,c} 1400 | 同 | passed |
| 选 b、d、e 后删 {b,d} | 顺序 a、c、e、f；已选 {e} | 同 | passed |
| 再删全部已选 | 顺序 a、c、f；已选 ∅ | 同 | passed |

### 8.2 断言 9 与断言 8 的期望值

| 输入 | Python（mm:ss 补零） | Swift 期望（`DateComponentsFormatter` `.positional` + `.pad`） | CI |
|---|---|---|---|
| 761 s ／ 62 s ／ 0 s ／ −5 s | 12:41 ／ 01:02 ／ 00:00 ／ 00:00 | 同 | passed |
| 2000 ms ／ −1 ms | 2.0 s ／ 0 s（2000 × 0.001 在双精度下恰为 2.0） | 同 | passed |

### 8.3 源码扫描口径（断言 1、6、7、10 与既有断言）

| 口径 | Python 实测 |
|---|---|
| 断言 1：登记表 `static let`（原文／剔注释）、出处总数／v2／画布；`S0HomeMetrics` 52、`gridColumns` 0 | 42／42、42／5／37；52、0 |
| 断言 6：页面剔注释数值字面量 | {0, 1, 2} |
| 断言 6：页面 `S0CategoryPageMetrics.`／`S1ChromeLayout.`／`S1ChromeTypography.`／`s1ChromeGlassBackground(`／`s1ChromeCircleGlass()` | 57／6／**1**／2／1 |
| 断言 6：`ThumbnailView(`／`showsPlaceholderGlyph: false`／`S2AmbientBackdropView()`／`Image(systemName: `（经符号枚举） | 1／1／1／3（3） |
| 断言 6：42 个登记名未被页面引用的 | 无 |
| 断言 6：流程文件数值字面量、PhotoKit 与恒深色 needle、`Text("` | ∅、各 0、0 |
| 断言 7：目录 `s0.`／`s0.categoryPage.`；页面引用 key | 37／5；恰五条 |
| 断言 10：流程文件 `machine.ingest(`／`.toolbar(.hidden, for: .navigationBar)`／`.toolbar(.hidden, for: .tabBar)` | 2／**2**／1 |
| 断言 10：App `feedbackToastDurationMilliseconds`／`advanceScan()`／`S0View(` | 3／2／0 |
| IC-147 断言 3：四个路由分支逐字、`.onAppear` 守卫原文 | 各 1、1 |
| IC-147 断言 7：App 与流程文件直写 `scanState = ` 等三个状态量 | 0 |
| IC-147 断言 10／11、IC-148 断言 10：新文件名单下引用的 `s0.` 集合 = 目录；跨前缀 | 37 = 37；仅 `s1.limited.banner` |
| IC-153 断言 11／12、IC-151：App 内 `S0CleanupDataStub(` 0、`S0LibraryScanService(` ≥ 1、`value(forKey:` 0、两个退役名 0 | 全部照旧 |

`Scripts/check-scan-needle-variant.ps1` 对 41 个测试源文件（含新测试文件）的全部 needle 过审（第十节）。

---

## 九、闸门

### G887（diff 与零改动）

- diff 限于白名单：10 个路径全在表内 ✔（`change-list.md` 第二节）。
- 不得触碰清单零改动：`<scratchpad>/ic156/g887_889.py c92c641` 逐文件比较 `cc686d9` 与 `c92c641` 两侧 blob 的 SHA-256——`S0View.swift`、`S0TabContainer.swift`、`S0CategoryRow.swift`、`S0SegmentBar.swift`、`S0HomeMetrics.swift`、`Core/` 除 `S1StateMachine.swift` 外 9 个、`Services/` 11 个、`Features/S1`／`S2`（9）／`S3`／`S4`／`S5`／`Shared`、`App/CleanupCoordinator.swift`、`.github/`、`Scripts/` 33 个**全部相同** ✔（值见 `change-list.md`）。
- `S1StateMachine.swift` 只增不删 ✔：`--numstat` = `31	0`，一个 hunk `@@ -780,6 +780,37 @@`。
- `App/PhotoCleanupMVEApp.swift` 的 diff 只落在 `cleanupContent` 那一行与 `s0Screen` ✔：`@@ -46,7 +46,7 @@ struct PhotoCleanupMVEApp: App {`、`@@ -84,13 +84,28 @@ struct PhotoCleanupMVEApp: App {`；删掉的 4 行恰为 `s0Screen()`、旧函数声明行、`S0View(`、旧闭包收尾 `}`；IC-147 断言 3 的五段原文逐字仍在（Python 各 1；CI `testIC147AAssertion03…` passed）。
- `Localizable.xcstrings` 的 diff 只有五条新 key ✔：解析两侧 JSON，新增恰为五条、删除 0、改动 0、顶层字段相同；一个 hunk `@@ -221,6 +221,61 @@`、55 行 +、0 行 -。

### G888（出厂值、登记数与冻结链）

- `S2Calibration.swift` 不在 diff ✔；`schemaVersion` = **7**（`static let schemaVersion = 7`）✔；`S0ScanRules.cacheSchemaVersion` = **1** ✔；`S0HomeMetrics` **52** ✔；`S0ScanRules` `static let` 行 **7** ✔。
- 远端 tip（推送前 `git ls-remote origin`，退出码 0）：`feature/ic-089-nx-edge-bounce` `b368a6caee846e664391b0620350395bfe6fbc7f`、`feature/ic-091-nx-midgesture-handoff` `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`、`feature/ic-092-nx-window-follow` `a7cc1ec727a3a493f5263e688a316cbf4c743562`、`probe/ic-067-screenshot-subtype` `9db02b93eccbb87d126602901807e70823535111`、`probe/ic-125-sentinel-negative` `402cb6e52a11dc89ce2a8351b47314a5fe9185b8`、`probe/ic-137-media-playback` `486bcb769b59eb1146c5a231c7998847206777cc`、`probe/ic-145-scan-service` `d373afc7125104c01acfc296829229090e6871ce`——与卡内七个短 SHA 一一对应 ✔。CI 绿后、合并前（06:33:42Z）再取一次 `git ls-remote origin`（退出码 0）：七条 tip 与推送前逐字相同 ✔，远端 `main` 仍为 `cc686d92d29ba4adcc41607983ae47a199179be7` ✔，远端分支 tip = `c92c641dae3da60d020af1ee20be67dd9d4b9b0e` ✔。

### G889（「不得打红」清单逐项实证）

| 项 | 实测 | 期望 |
|---|---|---|
| `S0View.swift`、`S0TabContainer.swift`、`S0CategoryRow.swift`、`S0SegmentBar.swift`、`S0HomeMetrics.swift`、`Core/`（除 B1）、`Services/`、`Features/S3/`、`Features/Shared/`、`.github/`、`Scripts/` | 两侧 blob SHA-256 相同（G887） | 相同 |
| App 入口（剔注释）`advanceScan()`／`onSnapshotDidChange`／`S0ScanOutcomeTransition.events(`／`S0TabContainer(`／`tabContainer(s1Machine: machine)` | 2／1／1／1／1 | 2／1／1／1／1 |
| App 入口四个路由分支与 `.onAppear` 守卫逐字 | 各 1 | 各 1 |
| `S1StateMachine.swift` | 只增 31、删 0 | 只增一个方法 |
| `Localizable.xcstrings` | 只增五条 | 只增五条 |
| `S0CategoryPageMetrics` | 42；五个 v2 值 3／4.0／10.0／11.0／22.0 与 SPEC-S0 v2 第 633～637 行逐值相等（脚本从规格原文取值比较） | 42、逐字等于规格 |
| 目录 `s0.` key | 37 | 37 |
| `scan-hardcoded-user-visible-strings.ps1` | 退出码 0（目录 252 = 引用 252，残留 0；双向门禁在新文件上通过） | 0 |
| IC-148 断言 1／2／3／4／7／11／14、IC-151、IC-153、IC-155 | #313 a1 与 a2 全部 passed（第五节表后） | 照旧 |

### G890（合并前置）

| 条件 | 实证 | 结果 |
|---|---|---|
| G887～G889 | 本节上文 | ✔ |
| 绿：844 项 0 失败 | #313 a2 执行摘要 notice `Executed 844 tests, 0 failing test case(s), across 1 launch(es)`；步骤日志唯一 passed 844、failed 0（a1 的红逐条核实只属 `testIC063…`，第四节 4.4） | ✔ |
| 真实退出码 0 | a2「运行 XCTest」步骤 success（`exit "$test_status"` 原样退出）+ 日志 `XCTest 已全部通过。` | ✔ |
| 执行摘要 notice | 见上 | ✔ |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`（a1、a2 相同） | ✔ |
| IPA 字节数与 SHA-256 | 1679665 字节，`3621bc6c168a9e4a13e7ced6f1e7ed96bf8377fc8156c035464d44f9575ae10f` | ✔ |
| 分段耗时 notice | `模拟器启动 59 s；xcodebuild test 243 s；总 303 s` | ✔ |
| 断言 1～11 逐条函数名 + 日志 `passed` | 第五节 11／11（a1 与 a2 都 passed） | ✔ |
| IC-147 16 项、IC-148 14 项、IC-132 与 IC-127 的会话层用例、IC-155 九项逐条 `passed` | 16／16、14／14；IC-132 9／9、IC-127 `testIC127B_*`／`C_*`／`E_*` 14／14（全部 26／26）；9／9（a1、a2 各自核，第五节表后） | ✔ |
| pbxproj 撞号扫描 | 分支 tip 复扫：对象定义 216、重复 0；四个新文件引用 id 各 3 次（定义、构建文件的 `fileRef`、组 children），四个新构建文件 id 各 2 次（定义、Sources 阶段） | ✔ |
| 工作树净 | 合并前 `git status --porcelain` 只有本卡报告目录 `Reports/IC-156/`，随报告提交入库后为空（第十二节） | ✔ |
| `main` 未被他人推进 | 06:33:42Z 与合并前 06:38:09Z 两次 `git ls-remote origin refs/heads/main` = `cc686d92d29ba4adcc41607983ae47a199179be7` = 本地 `main` | ✔ |

### G891（合并后 `main`）

合并提交 `c42edd1ded6ccd1e7ec0d17b2e3745560cdbfa78` 推送后（`git ls-remote origin refs/heads/main` = 该 SHA）自动触发 **#314**（run id `35190738456`，事件 `push`，分支 `main`，被测提交 = 合并提交）。

| 项 | attempt 1 |
|---|---|
| check-run id（现取） | `105102524380` |
| 作业 | 06:38:49Z → 06:51:45Z，**success**（12 分 56 秒，作业级时限 30 分钟之内） |
| 步骤 | 12 步全 success；「运行 XCTest」06:39:34Z → 06:48:29Z（8 分 55 秒，步骤级时限 25 分钟之内），日志 `XCTest 已全部通过。` ⟹ 真实退出码 **0**；「构建未签名应用」→ 06:51:30Z；「上传可下载的未签名 IPA」→ 06:51:32Z |
| 执行摘要 notice | `Executed 844 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 844 tests / 0 failures` |
| 分段耗时 notice | `模拟器启动 118 s；xcodebuild test 413 s；总 532 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1679665，SHA-256=d8193ee725775c6ec1d8fc8afd8b821c9a9a5c46618dcd3873c5bb618da150ca`；artifact `PhotoCleanupMVE-unsigned-c42edd1ded6c`，id `10484291484`，zip 1679835 字节 |
| 注解 | 仅上述 3 条 notice；error／warning **0** 条 |
| 整包日志（zip 246 735 字节，剔回显后） | 目的地 `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`；`Executed 844 tests, with 0 failures (0 unexpected) in 38.689 (45.551) seconds`；`** TEST SUCCEEDED **`；`All tests` 起跑每个日志文件 1 次、无宿主重启；唯一 Test Case 844：passed **844**、failed 0；`.swift:<行>: error` 行 0；`testIC063…` passed（3.993 s） |
| IC-156 十一项与点名的既有用例 | IC-156 11／11、IC-147 16／16、IC-148 14／14、IC-155 9／9、IC-151 8／8、IC-153 13／13、IC-132 9／9、IC-127 26／26、IC-129 6／6 全部 passed |

**说明**：合并树 `5327beb6…` 与报告提交 `8504a7d` 的树同一对象，与 #313 测过的代码（`c92c641`）逐字节相同，差别只在 `Reports/`（`paths-ignore` 内、测试不读）。IPA SHA-256 与 #313 a2 不同属预期（IPA 不可复现，字节数相同）。

**CI 次数说明（纪律 2）**：分支上 2 次（#313 a1 红于 `testIC063…`、原样复跑 a2 绿，均未改代码）；合并后 `main` 自动运行 1 次（#314 一次绿）。三次均未改动任何代码。

---

## 十、本地门禁与真实退出码

每个代码提交前在工作树上以 `powershell.exe -NoProfile -ExecutionPolicy Bypass` 运行（A、B、C、D 四轮结果相同，扫描规模随新文件递增）：

| 门禁 | 退出码 | 摘要（D 提交前） |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0**（四轮） | 「结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。」 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（四轮） | 目录条目 252、产品源码引用 key 252、用户可见硬编码残留 **0**（A、B 两轮为 247／247） |
| `Scripts/check-swift-string-structure.ps1 -SelfTest`（IC-149 门禁一） | **0**（四轮） | 自对照三条 OK；扫描 86 个 .swift（A／B 84、C 85），无未闭合字符串、无括号失衡 |
| `Scripts/check-scan-needle-variant.ps1 -SelfTest`（IC-149 门禁二） | **0**（四轮） | 自对照三条 OK；扫描 41 个测试源文件，无 needle 喂错源码变体 |
| `git diff --cached --check`（每次提交前） | **0** | — |

---

## 十一、pbxproj 撞号扫描与新登记

- 登记前（`cc686d9`）：带注释的对象定义 208 条，24 位 id 去重后 0 重复；文件引用最大 `10000000000000000000005A`、构建文件最大 `200000000000000000000057`（与卡内①一致）。
- 每次登记前重扫当前最大号、候选 id 全文件 0 命中后再登（`<scratchpad>/ic156/register_pbx.py` 拒绝非「最大号 + 1」的 id 与非唯一锚点）：

| 提交 | 文件 | 文件引用 | 构建文件 | 位置 |
|---|---|---|---|---|
| A | `S0CategoryPageMetrics.swift` | `10000000000000000000005B` | `200000000000000000000058` | S0 组 children 与应用目标 Sources 阶段，紧跟 `S0CategoryRow.swift` |
| A | `IC156CategoryPageTests.swift` | `10000000000000000000005C` | `200000000000000000000059` | 测试组 children 与测试目标 Sources 阶段，紧跟 IC-155 测试文件 |
| C | `S0CategoryPageView.swift` | `10000000000000000000005D` | `20000000000000000000005A` | 紧跟 `S0CategoryPageMetrics.swift` |
| D | `S0CleanupFlowView.swift` | `10000000000000000000005E` | `20000000000000000000005B` | 紧跟 `S0CategoryPageView.swift` |

- 分支 tip 复扫：对象定义 **216** 条（208 + 本卡 8）、重复 **0**；三个应用文件只在应用目标、测试文件只在测试目标（独立复核同样核过）。CI 实证：11 个新测试函数全部出现在日志里、项数 844——没有文件静默掉出编译列表（陷阱「pbxproj 撞号不报错」）。

---

## 十二、提交、合并与 SHA 核验

| # | SHA | 内容 |
|---|---|---|
| 1 | `55f2819415c633f9ea8d2f2b7a920b7e7f6672cd` | 子项 A |
| 2 | `bf271092cb3800660f5552b1bf8255cb328dc4b8` | 子项 B |
| 3 | `0fb15af71803e8fe3554b53e3ed5d217d80f6574` | 子项 C |
| 4 | `c92c641dae3da60d020af1ee20be67dd9d4b9b0e` | 子项 D（CI #313 被测提交） |
| 5 | `8504a7d75c8bfad4b08b8f1e5fa3745f1eebfc02` | docs：自验报告与变更清单（#313 a1 红于 testIC063、原样复跑 a2 绿 844 项 0 失败） |
| 合并 | `c42edd1ded6ccd1e7ec0d17b2e3745560cdbfa78` | Merge IC-156（`--no-ff`，父 `cc686d92d29ba4adcc41607983ae47a199179be7` 与 `8504a7d75c8bfad4b08b8f1e5fa3745f1eebfc02`；树 `5327beb601f0f422fc299f012b27e1ec54c72ffc` = `8504a7d` 的树） |
| 回填 | 本回填提交（`main`） | docs：回填合并提交与 G891（本提交无法写进自身 SHA） |

**报告提交方式（纪律 7）**：采用「同一张卡、同一分支内追加一个 docs 提交」——四个代码提交先推送以触发 CI，#313 的运行编号、两次 attempt 的日志实证与 IPA 校验是推送后才产生的信息，由报告提交 `8504a7d` 补入；`Reports/**` 在 `paths-ignore` 内，报告提交不触发 CI（预期行为）。合并提交 SHA 与 G891 是合并之后才产生的信息，照 IC-155 回填提交 `cc686d92d29ba4adcc41607983ae47a199179be7` 的先例，在 `main` 上以一个回填 docs 提交写入。

**合并执行记录**：报告提交推送后 06:38:09Z `git ls-remote origin refs/heads/main` 仍为 `cc686d9`；`git switch main`（本地 `main` = `cc686d9`、与 `origin/main` 一致）→ `git merge --no-ff feature/ic-156-category-page -F <消息文件>` 退出码 0（无冲突）→ 06:38:36Z `git push origin main` 退出码 0（`cc686d9..c42edd1`）；推送后 `git ls-remote` = `c42edd1ded6ccd1e7ec0d17b2e3745560cdbfa78`。Bash 一侧未遇到 `[Merge Without Review]` 拒绝。

**40 位 SHA 核验**（回填写完、回填提交前，`<scratchpad>/ic156/verify_shas156.py` 抽出两份报告里全部独立的 40 位十六进制串，在主仓库逐个 `git cat-file -e`）：共 **21** 个；**15** 个是提交（`git cat-file -e <sha>^{commit}` 退出码 0：四个代码提交 `55f2819415c6…`／`bf271092cb38…`／`0fb15af71803…`／`c92c641dae3d…`、报告提交 `8504a7d75c8b…`、合并提交 `c42edd1ded6c…`、基线 `cc686d92d29b…`、IC-155 合并提交 `07b7f76acb14…`、七条冻结／探针 tip），**6** 个是树对象（`^{commit}` 不适用，改 `git cat-file -e <sha>^{tree}` 退出码 0：`5d5f977c…`／`d5957c36…`／`8db48585…`／`34d57720…` 分别是四个代码提交自身的树，`5327beb6…` 是报告提交与合并提交共同的树，`361bef2e…` 是 `git merge-tree --write-tree` 写入主仓库的 A→C 合成树），**缺失 0**。分支报告提交 `8504a7d` 时同一脚本核过当时的 18 个，缺失 0。

---

## 十三、人工判定项 H77（留给 Lynn 真机，执行端不代为下结论）

装合并后 `main` 的产物（同一包可连判 H72～H76）：#314 artifact `PhotoCleanupMVE-unsigned-c42edd1ded6c`（IPA 1679665 字节，SHA-256 `d8193ee725775c6ec1d8fc8afd8b821c9a9a5c46618dcd3873c5bb618da150ca`）。

1. **进得去、回得来**：首页点任一有项目的类别行进类别页（无项目的灰行点不动）；返回圆钮回首页，tab bar 回来，首页数字与进去前一致（没进篮时）。
2. **版式**：恒深色氛围底与首页同一质感；顶排返回圆钮与「全选」胶囊是 S1 同款玻璃；大标题带类别色点，副行「N 个 · X GB · 按体积从大到小」；三列网格从大到小，右下体积标签，视频左下有播放符与时长，右上圆圈勾；网格滚到底部时最后一行不被主按钮压死（渐隐 + 底距）。
3. **勾选**：点格勾上／取消；「全选」一次全勾、再点全空；常驻行「已选 N 项 · X GB」与主按钮上的数字**恒相等**；零选中时主按钮变暗但仍在。
4. **进篮**：勾几张点「移入待删篮」——toast「已移入待删篮」约 2 秒；这些格从网格**消失且其余格顺序不变**；返回首页后该类别行的项数与体积、hero 数字、分段条**同步减**；右上待删篮胶囊出现并显示张数与体积。
5. **S3 分组来源**：切到「逐张整理」tab，点右上垃圾桶进 S3——出现一组，组头就是类别名（如「大视频」），组内是刚移入的那几张；从 S3 移除一张再回清理 tab，该类别行的数字加回来、再进类别页那张回到网格。（首页待删篮胶囊点击进 S3 归 5.3，本条走 S1 的入口。）
6. **滚动**：类别页上下快滚，缩略图陆续出现、不卡顿、不串图；iCloud 优化储存下本机无缩略图的格显示空底不转圈。
7. **回归**：首页四态与 H76 六项快过；S1／S2／S3 行为不变；App 冷启动后待删篮里的类别组仍在（会话档恢复含名字表）。

执行端附注（不是判定）：第 1、7 条请顺带看首页顶排位置与改前是否一致（第 7.2 条的③）；第 2 条的对勾大小是登记表缺口下的取值（第 7.6 条）；第 4 条 toast 在主按钮正上方（第 7.8 条）。

---

## 十四、发现但未处理的问题（按纪律只报告不修）

1. **`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 第四次在零相关改动下单独判红**（#313 a1，第四节）：与本卡无关，原样复跑即绿（a2 passed，3.104 s）。第 182 条已列维护卡候选（落点在产品侧 `S2GeometryDiagnosticsRun` 中间帧门禁）；本卡不动。
2. **`testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` 名不副实**：断言值已按裁定 六改为 37，函数名仍写 ThirtyTwo。改名不在白名单内（且 G890 按函数名逐条核），未改；建议随下一次动 IC-148 文件的卡一并改名。
3. **扫描进行中停在类别页时的重复取数（③）**：流程容器不订阅状态机，但 App 根持有的 `s0Machine` 每次摄入新快照（首扫期间每秒至多 4 次）都会让 App 与 tab 容器重算视图，`navigationDestination` 的目的地闭包随之重跑、再调一次 `dataProvider.categoryAssets(id)`——真实服务每次遍历全部扫描记录并排序。页面只用首次得到的列表（`@State` 初值），多算的结果被丢弃，正确性不受影响；耗时是否可感知未测。验证：H77 第 6 条在**首扫未完成时**进类别页快滚。若卡顿，可在推出时算一次列表存进容器状态——须卡授权。
4. **`page(for:)` 在类别不在快照里时给空白目的地、没有返回钮（③ 不可达）**：真实服务的快照恒含三个元数据类别（`S0ScanClassifier.swift` 「`categories` 恒为三条」）、桩恒含五类，行能被点开即说明该类别在快照里；卡面 D1 未规定该分支，按「无类别不造页」处理。
5. **系统边缘右滑返回未验证（③）**：根页与类别页都隐藏了导航栏；隐藏导航栏后交互式返回手势是否仍可用，模拟器夹具测不到。卡只要求自绘返回圆钮（经 `presentedCategory = nil` 返回）；若右滑可用，同样经绑定置 nil、触发同一重算路径。H77 第 1 条可顺带试一下。
6. **IC-147 断言 7「视图层与容器层不直写三个状态量」的文件名单不含新流程文件**：卡未要求加；Python 实测流程文件内 `scanState = `／`ledgerState = `／`verificationState = ` 各 0。
7. **卡内写卡缺陷四处**（第 7.1 条条文自相矛盾；第 7.2、7.3 条计数闸门未把正确实现算进去，惯例 41 同类；第 7.4 条摘取单元与测试文件追加方式矛盾，惯例 40 同类），另一处坐标偏差（第 7.7 条）与一处登记表缺口（第 7.6 条）。
