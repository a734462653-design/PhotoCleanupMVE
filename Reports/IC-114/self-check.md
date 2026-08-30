# IC-114 自验报告：视觉批次 v4（原生 Liquid Glass、教程三修、相簿选择器、放大自动隐藏）

## 结论（先行）

**A3、B、C 三项交付并绿；A 的玻璃部分（A1/A2）按 A1 停线未做；D 触发 D2 停线，已停并报告。**

- **最终绿 tip（H51 包）** = `7fa94b1`（子项 C），CI **#220**，**`Executed 570 tests, with 0 failures (0 unexpected)`**，真实退出码 0，IPA **990596 字节**，SHA-256 **`3b4328024d1b4c263f609cb36991197120682fb7e055d5fcc92c64aa867deeb9`**。**该包含 A3 + B + C。**
- **分支当前 tip** = `29c01ae`（子项 D，**红**）。D 的代码在分支上但未绿，见「子项 D」。
- **G289 通过**：工作树净；分支与提交身份核对吻合（短 SHA `2362c4f` = IC-113 v2 报告提交）。
- **G290**：A3 / B / C 达成；**A 玻璃部分未做、D 未达成**。
- **G291 通过**：`schemaVersion == 7` 未变；`S2Calibration.swift`、`.github/`、`Scripts/` 自本卡基线**零 diff**；冻结三链未动（`b368a6c` / `6736f1e` / `a7cc1ec` 逐个核过）。
- **G292 通过**：未触碰任何手势识别器；**C 的写操作边界已核**——本子项 diff 新增行中 `deleteAssets` / `removeAssets` / `deleteAssetCollections` 调用数为 **0**；D 经状态机统一分派（见下）。
- **G293 未触发**：D 的失败项全部与本卡 D 的行为变更直接相关，非无关测试。
- **CI 用 4 次**（A3 1、B 1、C 1、D 1），预算 9，**未超**。时间闸门自开工 01:12 起 8 小时，收口于 02:3x，**未超时**。
- **全程未合并 `main`。**

---

## 提交与 CI 一览

| 子项 | 提交 | CI | 结论 | XCTest | IPA 字节 |
|---|---|---|---|---|---|
| A3 显隐过渡动画 | `f5e4715` | **#218** | success | **562 / 0** | 973514 |
| B 教程三修 | `186297b` | **#219** | success | **566 / 0** | 975560 |
| C 相簿选择器 + 新建 | `7fa94b1` | **#220** | success | **570 / 0** | 990596 |
| D 放大自动隐藏 | `29c01ae` | #221 | **failure** | 575 / **30**（8 个用例） | — |

A3 的 IPA SHA-256 `beece9ae5e250abff3e7e9d8ee0c698737c1ffa90e7b4dc5b39dfbfe470f2881`；B 的 `55ed359a81ec34e033cbdca6e15f96ea9df58e634836cb0ed1d1ec8cf6cd36df`。

---

## 子项 A：**A1 停线触发**，只交付第 3 项

### A1 的实证与准确成因

卡内 A1 假设的是「CI runner 的 Xcode 不含 iOS 26 SDK」。**实证后成因更具体**（①，证据来自 CI #217 的「显示 Xcode 环境」步骤日志）：

| 证据 | 值 |
|---|---|
| `xcodebuild -version` | **Xcode 16.4**（Build **16F6**） |
| 该 Xcode 的 iOS SDK | 18.5（不含 `glassEffect` / `GlassEffectContainer` 符号） |
| `xcrun simctl list devices available` 的 runtime 分组 | iOS 18.5、18.6、**26.0、26.1、26.2** |
| `ci.yml` 的 runner | `macos-15` |

关键推论：**runner 镜像上装着 iOS 26 运行时，说明存在 Xcode 26，只是 `ci.yml` 没有选它**。所以 A 不是卡在「runner 太旧」，而是卡在 **`ci.yml` 固定用了 Xcode 16.4，而 G291 明令 `ci.yml` 零改动**。

符号在 SDK 中缺失时，`#available(iOS 26.0, *)` 守卫**也救不了**——那是运行期可用性检查，编译期仍要求符号存在。故 A1/A2 在当前 CI 配置下必然编译失败。

按 A1「（真机是 iOS 26，Lynn 可判空分支无意义——此情形停 A 并报告，**不硬造**）」，**未写空分支**。

**解锁方式（供决策会话）**：一行 `ci.yml` 改动即可——在构建前设 `DEVELOPER_DIR` 指向镜像上的 Xcode 26（或 `sudo xcode-select -s`）。这属 `ci.yml` 改动，需新卡授权。

### A3 显隐过渡动画（已绿）

第 3 项不依赖 iOS 26、iOS 17 即可实装，且是独立的 ④ 新规则 ⑤b、H51 第 2 项要判它，故经决策会话确认后单独交付。

V 显→隐：整体 scale 1 → **1.06** + 高斯模糊 0 → **8pt** + opacity → 0，**200ms easeOut**；隐→显反向进场。三项都是 Core Animation 支持的属性动画，由渲染层推进。

实装收敛到一个修饰符 `s2ChromeVisibilityTransition(isVisible:)`，取值全部来自 `S2ChromeVisibilityTransition` 常量；进出用**同一组取值按 `isVisible` 取反**，故天然对称、不会两头写岔。原先的 `.opacity` / `.allowsHitTesting` / `.accessibilityHidden` 三连整体并入该修饰符，命中测试与无障碍隐藏语义**一字未改**。

| 验收点 | 测试函数 |
|---|---|
| 两端取值落在卡内数值、静止端恒等 | `testIC114A3VisibilityTransitionEndpoints` |
| 方向自洽（隐藏端更大更模糊更透明） | `testIC114A3HiddenEndIsLargerAndBlurrier` |

**证据分级**：两项均为**夹具驱动**，真机未覆盖（陷阱 1），由 H51 第 2 项兜底。

---

## 子项 B：教程三处修复（已绿）

**B1 步 2 聚光套错张**：上滑标记成功后产品会自动翻到下一张，被标记的是**前一张**，而此前聚光取的是 `currentIndex` 的格位。`targetRect` 的 `showsRecentAlbumCapsule` 形参换成 `markedIndex`（参数数不变），步 2 改用它取格位；横栏几何仍以 `currentIndex` 为准（它决定哪一格放大、内容如何偏移）。调用点由 `tutorial.markedAssetID` 反查下标。

**B2 方向错位——先探查后修**（卡内要求）。探查结论：

- 方向向量映射**本身没错**（`.down` 一直是 `(0, +travel)`）；
- 真实成因在**视图身份**（③，机制明确、与实测描述逐条吻合）：`S2TutorialGestureHint` 跨步复用同一实例，`@State looping` 保持 `true`、`onAppear` 只在第 1 步触发过一次，`repeatForever` 动画一直带着**安装时**的方向；同时 `if direction == .down` 会重排 `VStack` 子项，箭头在步 3（`.right`）→ 步 4（`.down`）之间被销毁重建、丢掉动画而**静止**，圆点则留着步 3 的**横向**动画。两个症状同源。

修复：加 `.id(direction)`——方向一变整个单元连同 `@State` 一起重建，`onAppear` 重新触发，圆与箭头拿到同一份新动画，作为一体沿正确轴平移。

按卡内补了「每步方向向量与位移轴一致」的防回退断言；**如实登记该断言查的是映射表本身、抓不到身份类缺陷**，身份修复的效果由 H51 第 4 项真机判定。

**B3 步 5 交互重定义**：聚光改为**恒定圈住右下角相簿选择器圆钮、无箭头**（IC-113 C 的「中位为空才套选择器」分支随本卡废止）；点开选择器后教程在 sheet 之上压一条提示；关闭 sheet 即进步 6。步进只读 `sheetState` 的已发布变化，且**必须先见到打开、再见到关闭**才算数。教程态**不禁用** sheet 内真实操作——用户若真加入相簿照样推进（卡内取定）。

| 验收点 | 测试函数 |
|---|---|
| 步 5 恒圈右下圆钮且无箭头 | `testIC114B3AlbumGuideSpotlightAlwaysTargetsPickerCircle` |
| 步 2 圈被标记那张 | `testIC114B1StripSpotlightTargetsMarkedItemNotCurrent` |
| 步 5 先开后关才推进 | `testIC114B3AlbumGuideAdvancesOnPickerOpenThenClose` |
| 真实加入也推进 | `testIC114B3RealAlbumJoinAlsoAdvances` |
| 方向向量与位移轴一致 | `testIC114B2DirectionVectorMatchesAxis` |

---

## 子项 C：相簿选择器系统化 + 新建相簿（已绿）

**写操作边界（G292 硬闸门）已核**：本子项 diff 新增行中 `deleteAssets` / `removeAssets` / `deleteAssetCollections` 调用数为 **0**；唯一新增的 `performChanges` 是 `creationRequestForAssetCollection`（只创建集合）。中央指示的撤回移除是 IC-113 B 的既有代码，本卡未动。

1. 系统风格 sheet：`List` + `NavigationStack`，标题「添加到相簿」，**首行「新建相簿…」恒在**（无相簿时列表可空但该行仍在）；相簿行 = 40pt 键图 + 名称 + 数量。grabber 与「中等 detent 起、可拖全高」由 `.presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)` 提供；下拉即取消沿用 `albumSheetBinding` 原有 set 分支，未改语义。键图复用既有缩略管线（App 注入 `thumbnail` 闭包，内部就是横栏同一个 `S2TemporaryPhotoImageView`）。
2. 新建相簿：点首行 → 系统 alert 命名框 → `createAlbum` 建 `PHAssetCollection` → **成功后由选择器自行再走一次 `actions.select(新相簿)`**。这是关键设计：加入、最近相簿更新、IC-111 C 的首次入场时序与残影规则全部复用既有路径，**不新增第二条加入通路**。
3. 模型不动 `S2AlbumReference`（它是「最近相簿」的持久化最小模型），另立只服务于列表的 `S2AlbumListItem`。
4. 失败路径：新增 `S2FeedbackEventKind.albumCreationFailed` 一个分支 + 文案，协调器在创建回 nil 时只发反馈、不改状态。

| 验收点 | 测试函数 |
|---|---|
| 新建只创建不加成员（成员写入计数 0）、空名与失败开关回 nil | `testIC114CCreateAlbumOnlyCreates` |
| 新建失败发反馈且三种失败文案互异 | `testIC114CCreationFailurePublishesFeedback` |
| 列表项数量随成员关系走 | `testIC114CAlbumListItemsReportCounts` |
| 三个动作各司其职、创建失败不走加入 | `testIC114CPickerActionsRouteCreateThenSelect` |

---

## 子项 D：放大自动进入隐藏态——**D2 停线触发，已停**

### 实装内容（在分支上，未绿）

**经状态机统一分派，禁止旁路（G292）**：新增私有 `setScale(_:)` 作为**唯一的 `scale` 写入口**，把状态机内原先散落的 **9 处直写**全部改道（`handleDoubleTap` 进/出、`handleNativeDoubleTap` 进/出、`updatePinch`、`endPinch` 归位、`cancelPinch`、`applyCalibration` 钳制、`resetZoomAfterPhotoChange`）。改道后全文件只剩两处直写：构造时的初始赋值与 `setScale` 自身。自动隐藏的判定只写在这一个入口里，任何缩放路径都绕不过去。

### D2 停线：三条**规格契约级**门禁与本规则正面冲突（①）

#221 有 **8 个用例、30 处断言**失败。逐条归类后，其中三条不是普通旧断言，而是**规格级契约**：

| 用例 | 性质 |
|---|---|
| `testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale` | **K 系列验收门禁**，断言「双击**永不**改变界面显隐」 |
| `testIC047_004TransitionRowDoubleTap` | **状态转移表**中双击那一行 |
| `testIC047_037DoubleTapEnterAndExitRestoresVisibility` | 双击进出的显隐恢复契约 |

其余五条：`testE2ReplacementDoubleTapSuppressesSingleTapAction`、`testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap`、`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`、`testIC047_035PinchExclusivelyOwnsTouchSequence`、以及本卡自己的 `testIC114DScaleChangesWithinZoomDoNotTouchVisibility`（后者是我的用例自身有 bug——捏合期间 `touchSequenceOwner == .pinch`，`handleSingleTap` 因 `receivesUnobscuredInput` 为假而返回 false）。

**为什么这构成 D2 的「显影冲突」并须停**：

1. 卡内 D2 的预核列了五条（Nx 单击切 V、决策 20、截图沉浸推迟、S2-3、第 132 条），**这三条不在其中**——预核漏掉了规格里「双击永不改变 V」这条明文门禁与转移表行。
2. 卡内自己写明 D 是「⑤a ④，**规格修订待落 v18**」——即**规格尚未修订**。现行规格仍是「双击永不改变 V」，其门禁因此红。
3. 改写 K2 / IC-047_004 / IC-047_037 等于**在规格修订落文之前先把规格门禁掰弯**，属产品决策；且 SPEC 在本卡范围外。按纪律「不为测试改产品」的同源精神，也不应反过来为产品改规格门禁。

故按 D2「**实装或测试中任何一条显影冲突 → 停，报告**」停止，**未改动任何一条冲突门禁**。D 用 CI 1 次（预算 2，余 1 未用）。

### 一处前提更正（③ → ①）

卡内写「『进入前 V』**沿用既有双击记录机制**并扩展覆盖捏合入口」，但**全仓没有任何『进入前 V』记录机制**（已核，零命中；`interfaceVisibility` 此前只有三处写入：构造、单击切换、第 132 条下滑转显示）。故本卡是**新建**该记录（`visibilityBeforeZoom`），而非扩展既有机制；双击与捏合两条入口因为都汇入 `setScale`，天然一并覆盖。

### 下一步（供决策会话）

D 要落地需先决定两件事，都超出执行端权限：

1. **规格修订（v18）落文**：把「双击永不改变 V」改写为「放大自动隐藏 + 退出恢复」，并同步转移表中双击那一行。
2. 据此改写 K2 / IC-047_004 / IC-047_037 三条门禁，以及连带的 E2 / G3 / IC-063 诊断阶段与 IC-047_035。

我自己那条 `testIC114DScaleChangesWithinZoomDoNotTouchVisibility` 的 bug 是独立的小问题（应在 `endPinch` 之后再单击，或改用不占用触控序列的路径），可与上述一并处理。

---

## 本地门禁（本机 Windows，①）

每次提交前均跑满三门禁，**全部退出码 0**：`git diff --check`、`Scripts/selfcheck.ps1`、`Scripts/scan-hardcoded-user-visible-strings.ps1`。目录条目 200 = 产品源码引用 200，用户可见硬编码残留 0。

---

## H51 人工判定清单（原样列出，保留给 Lynn，不代为下结论）

1. 玻璃与系统 Photos 并排：透镜质感、高光、按压反馈（iOS 26 原生）。
2. 隐藏过渡：单击隐藏时 chrome 放大+模糊+淡出的小动画；显示反向。
3. 放大自动隐藏：捏合与双击进入放大即隐藏，退出恢复进入前状态。
4. 教程：步 2 聚光套对被标记那张；步 4 圆点箭头一体向下；步 5 圈右下圆钮→点入→提示→取消返回→步 6。
5. 相簿选择器：系统风格列表、新建相簿全流程（命名→创建→自动加入→中胶囊更新+残影）。
6. 回归：中央指示、两条残影、等距带、双击、132 条隐藏态手势。

**H51 包 = `7fa94b1`（CI #220）**，含 **A3 + B + C**。

**本包可判**：第 2 项（隐藏过渡）、第 4 项（教程）、第 5 项（相簿选择器）、第 6 项（回归）。
**本包不可判**：第 1 项（原生玻璃——A1 停线未做）、第 3 项（放大自动隐藏——D2 停线未做）。

---

## 停线 / 偏差 / 待补核（逐条）

### 停线

- **A1**：**已触发**。成因是 `ci.yml` 固定 Xcode 16.4 而 G291 禁改 `ci.yml`，非 runner 缺 SDK。未硬造空分支。
- **D2**：**已触发**。三条规格契约级门禁与本规则正面冲突，且规格修订尚未落文。已停，未改任何冲突门禁。
- **G293**：未触发（D 的失败项均与本卡 D 的行为变更直接相关）。
- **CI 预算**：用 4/9，未超。

### 偏差

1. **A 只交付第 3 项**：经决策会话确认后单独交付 A3（不依赖 iOS 26），A1/A2 挂起。
2. **B3 使 IC-113 C 的「中胶囊/选择器」分流失效**：步 5 现恒圈右下圆钮，该分支随本卡废止，已在测试中改写。
3. **D 的代码留在分支上但未绿**：按范围外「不得 revert」，未回滚。**分支 tip `29c01ae` 是红的**；H51 包取最后绿 tip `7fa94b1`。下一张卡的开工检查请注意这一点。

### 待补核

1. **A3 静止态是否影响玻璃透光**（③，本机无法验证）：静止显示态下三项均为恒等值（scale 1 / blur 0 / opacity 1），理论上被 SwiftUI 视作无操作而不额外插入滤镜层。**若 H51 判定玻璃透光较上一包（#217）变差**，首选回退方案是把 blur 改为仅在非显示态才挂——代价是模糊不再逐帧动、只在边界跳变。
2. **D 的一处交互取定未定案**：若用户在 Nx 期间手动单击改了 V，退出放大时按**进入前**的 V 恢复（卡内规则的字面实装）。是否应让手动切换覆盖记录值，卡内未规定。
3. **B2 的身份修复无法在本机验证**（③）：防回退断言查的是映射表，抓不到身份类缺陷；效果由 H51 第 4 项真机判定。
