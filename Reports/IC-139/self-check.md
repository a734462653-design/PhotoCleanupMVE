# IC-139 自验报告

> 报告提交方式说明（执行纪律第 7 条）：本卡含合并授权，报告需引用推送后才产生的
> CI 运行编号、IPA 校验与合并 SHA，故采用「同一张卡、同一分支内追加一个 docs 提交」
> 的方式，随合并一并留在 `main` 上，不跨卡回填。

## 结论（先行）

**四个子项全部交付，CI 一次通过，已合并入 `main`。本卡不接任何播放器。**

- 基线：`main` = `db318fc7f9cb9e94c4ead6a5edbb4ab493eb0bef`
  （标题以 `docs: IC-138` 开头；`ad41504` 是其祖先——`git merge-base --is-ancestor` 为真）
- 分支 `feature/ic-139-media-badges`，代码 tip `564a5f39bbec7bc8b9fb1f82f7e4a9f5e20d6885`
- CI **#271** 一次绿：XCTest **694 项 0 失败**，真实退出码 0，摘要 notice 在位，
  目的地 `OS:26.2, name:iPhone 16`；**预算 3 次用 1 次**
- 合并提交 **`fd7c983`** / `fd7c9831dfb8f5febc101f287fa587c92ce6259f`，零冲突
- **G795**：合并后 `main` 自动运行 **#272** 同为 694 项 0 失败
- G791 ✓ G792 ✓ G793 ✓ G794 ✓ G795 ✓
- 本地三条门禁退出码均为 0；九条断言对应的 **17 个测试函数逐个在日志里查到 `passed`**

**最重要的实现结论：卡内为子项 C 预留的「停卡」条件没有触发。**
卡说「若既有参数不足以表达『下缘上移 68』而必须改分页器，停下报告」。
实测**足够**：`S2NativePageContent` 本来就带逐页的 `fittedSize` 与 `fittedCenterY`
两个入口（IC-104 C v3 为截图适配带建的同一套机制），几何链正是读这两个值落笔。
因此 `S2NativePhotoPager.swift` **逐字节不变**（两侧 SHA-256 同为
`344cfcd5…`），`S2Calibration.swift` 也不在 diff 中。

**必须先看的四件事：**

1. **卡内断言 6 的措辞只对一类资产成立**。「视频页显示态 `maxY` 比照片页小 68、
   `minY` 相同」仅在资产**竖向受限**（高度吃满适配区）时精确成立；横向受限资产
   的适配尺寸不变，整帧在缩短后的区里重新居中，两缘各上移 34。我按决策 57
   的字面实装，并把**两类各写一条断言**，没有只挑让卡内措辞成立的那一类来写。
2. **B／C／D 无法脱离 A 单独 cherry-pick**，这是卡内分解方式的固有约束
   （三者都消费 A 定义的 `m`；C 还要用 B 的两个常量算 68），不是拆分手法所致。
   四个提交仍按子项顺序拆开，每阶段单独验过。
3. **「照片页摆放不变」这次是真的零改动**，且有断言：照片页与实况页在两个
   可见性下的渲染帧与基线逐值相同（`testIC139C_PhotoAndLivePagesKeepBaselineGeometry`）。
4. **陷阱 14 在本卡是活的**：横栏顶缘的既有推导式里含触控带下限
   `max(最小触控边长, 横栏高)`，浮框是**视觉**锚不能用它。已改用视觉带高，
   并写了一条在横栏高 < 44 时把两条推导式钉开的断言。

---

## 子项 A：媒体类别与实况胶囊（提交 `90832bc`）

### 判别谓词零重写

`CleanupCoordinator.s2AssetMediaKind(for:)` 只做**映射**，判别本身走
`AssetSizeProbeService.mediaKind(of:)`（`Services/AssetSizeScanner.swift:286`，
全仓唯一判别处，IC-137 探针已核实）。协调器里不出现
`mediaType == .video` / `mediaSubtypes.contains(.photoLive)` 任何一句——
这一点有源码扫描断言钉住，防止日后长出第三份分类实现。

`Services/AssetSizeScanner.swift` 不在本卡白名单，本卡也**没有改它**。

### 挂载方式与「摆放不变」

三个新构造件挂在 `interfaceOverlay` 的 ZStack 里作为**第四个兄弟层**。
ZStack 子层互不影响布局，顶排、横栏、操作条三层的帧与锚点因此一字未动；
显隐过渡由外层既有的 `.s2ChromeVisibilityTransition` 统一施加，
本层不自造时长／缩放／模糊（有断言，见下）。

### 断言 1、2、3 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 1 | 三类资产映射 | `testIC139A_MediaKindMapsEveryProbeKindWithoutReimplementingPredicate`（映射对判别器三个取值全覆盖且单射；协调器源码扫描无第二份谓词） | **passed** ① |
| 2 | 胶囊口径模型：几何常量**引用**、无动作无 chevron | `testIC139A_LivePillGeometryReferencesRegisteredChromeConstants`（两个引用断言 + 7 个④取值）、`testIC139A_LivePillModelHasNoActionOrChevronField`（`Mirror` 逐字段列出，实测 `["symbolName", "text"]`） | **passed** ① |
| 3 | 照片页与视频页不构造胶囊 | `testIC139A_LivePillExistsOnlyOnVisibleLivePage` | **passed** ① |

**断言 1 的覆盖边界（如实标注）**：`PHAsset` 在夹具里造不出来，故
「`mediaType == .video` → video」这一步**谓词本身**是夹具不可达的；本断言证明的是
**映射层**全覆盖且单射，加上源码扫描证明谓词只有一处实现。
谓词的真机行为由 H63a 第 1 项（实况页有胶囊、照片／视频页无胶囊）兜底。

---

## 子项 B：视频浮框骨架（提交 `bf3d5d3`）

三件本卡恒为 `play.fill` / 进度 0（含拖动圆点）/ `speaker.slash.fill`，
整条 `allowsHitTesting(false)`。播放状态与点击接线属 IC-141。

### 陷阱 14：视觉锚不复用触控推导式

`S2OverlayLayout.stripTopFromViewportBottom` 内含
`resolvedStripHeight = max(minimumTouchTarget, 横栏高)`——**触控带**语义。
IC-104 C v3 就因为拿它锚视觉带缘，真机底距多出 14 pt。
浮框锚的是眼睛看到的横栏顶缘，故 `videoBarBottomFromViewportBottom` 直接用
传入的横栏**视觉**带高。断言在横栏高 = 34（< 44）时把两条推导式钉开。

### 断言 4、5 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 4 | 浮框只在 `m=video` 且 `V=显示` 存在；常量引用；三件无动作 | `testIC139B_VideoBarExistsOnlyOnVisibleVideoPageAndTakesNoHits`、`testIC139B_VideoBarGeometryReferencesRegisteredChromeConstants`、`testIC139B_VideoBarAnchorUsesVisualStripHeightNotTouchBandFloor` | **passed** ① |
| 5 | 隐藏态两件都不存在；显隐三量引用既有常量 | `testIC139B_HiddenInterfaceBuildsNeitherPillNorBar`（三个类别 × 隐藏态共 6 条）、`testIC139B_MediaChromeUsesExistingVisibilityTransitionConstants`（三量取值 + 媒体常量容器源码扫描确认未自造） | **passed** ① |

**范围说明**：决策 56 里 `R=拖动` 时「`V` 临时隐藏但仍显浮框读数」这一例外
**不在本卡**——本卡没有 `R`，也不显示读数（`videoBarTimeFontSize` 已登记未使用）。
该例外属 IC-141。

---

## 子项 C：视频页几何（提交 `5a3b188`）

### 为什么不用停卡

卡内预留了停卡条件。实测既有参数**足够**：

- `S2NativePageContent` 带 `fittedSize` 与 `fittedCenterY`（后者语义正是
  「`s = 1` 显示帧的竖直中心（视口坐标）」，IC-104 C v3 为截图带引入）；
- 几何链 `enforceOneXContentGeometry` 读的就是这两个值
  （`bounds = (0,0,fittedSize)`、`center.y = oneXPhotoCenterYInZoomContent`）；
- 两个值由 `S2View.pageContent` **逐页**供给。

故只需在 `pageContent` 内把这两个值换成视频页的取值，
`S2NativePhotoPager.swift` 与 `S2Calibration.swift` 都不用动。
`nativeZoomBaseSize` **未改**，Nx 基准与照片页一致——决策 57 只说 1x 适配区，
没说改 Nx 基准，故不动。

### 断言 6、7 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 6 | 渲染帧断言 + 68 是推导量 | `testIC139C_VideoPageFitInsetIsDerivedNotIndependent`（恒等式 68 = 44 + 24）、`testIC139C_VisibleVideoPageRenderFrameLiftsBottomEdgeBy68`（竖向受限）、`testIC139C_WidthBoundVideoPageRecentersInsideShortenedRegion`（横向受限） | **passed** ① |
| 7 | 既有几何契约回归 | `testIC139C_HiddenVideoPageGeometryMatchesPhotoPage`（两种比例）、`testIC139C_PhotoAndLivePagesKeepBaselineGeometry`（两种可见性 × 两种比例 × 两个类别 = 8 组） | **passed** ① |

**这是真的渲染帧断言，不是尺寸断言**（陷阱 13）：夹具构造一个真实的
`S2NativeZoomScrollView`，调 `configure(...)` → `layoutIfNeeded()` →
`applyNativeState(scale: 1, viewportOffset: .zero)` 跑完几何链，再读
`oneXPresentationFrame`（视口坐标的 origin + size）。断言比的是
`minY`／`maxY`／`size`，不是只比尺寸。

**未覆盖项（如实标注）**：卡内断言 7 提到「双击过渡端点在视频页取显示态几何」，
并允许「若过渡断言可参数化则加一条，否则报告写明未覆盖」。
既有双击过渡断言绑定在 `S2CalibrationHarnessTests` 的私有夹具
（`makeNativePagerController` 等）上，参数化它需要改那个文件的既有 helper，
超出本卡「新增 `IC139MediaBadgesTests.swift`」的范围。
**故双击过渡端点在视频页的取值本卡未覆盖**，留给 IC-141
（那张卡本来就要改双击快照取封面帧，两件事同源）。跨 `s` 边界连续性同理未覆盖。

---

## 子项 D：长按分派（提交 `564a5f3`）

- 主图长按：`m=实况` → 记一次事件（IC-140 接播放）；`m≠实况` → **不再开标定面板**。
- 标定／诊断面板入口改到**顶部中胶囊**长按 0.8 s，所有页一致、与 `m` 无关。
- **分页器根视图上那只识别器一字未动**（文件逐字节不变），只改闭包语义——
  这也是为什么卡内「实况页长按改派」能在不碰分页器的前提下做到：
  识别器装在根视图、看得见所有页，按页条件化只能在闭包语义层做。

### 断言 8、9 结果

| # | 断言 | 测试函数名 | 结果 |
|---|---|---|---|
| 8 | 分派规则 + 事件记录一次 | `testIC139D_LongPressGoesToLivePlaybackOnlyOnLivePages`（三类别）、`testIC139D_LivePhotoLongPressRecordsOncePerPress` | **passed** ① |
| 9 | `toggleAccessControls()` 调用点恰一处，且不在主图长按路径 | `testIC139D_CalibrationPanelToggleLeavesTheMainPhotoLongPressPath`（面板开关语义回归 + 源码扫描：调用点计数 == 1、中胶囊已接线、主图已改派） | **passed** ① |

**夹具边界（如实标注）**：UIKit 长按识别器 → 闭包 → 分派这条**接线**
夹具驱动不到（陷阱 1，且 XCUITest 模拟手势为明令禁止）。
断言证明的是分派规则（纯函数）与记录器行为，**不证明**真机上长按真的落到这里。
真机由 H63a 第 3 项兜底。

---

## 闸门逐条结论

### G791（diff 限于白名单；分页器逐字节不变；协调器只加一个只读成员）：**通过** ①

`db318fc..fd7c983` 共 **6 个文件**，逐个对照白名单：

| 文件 | 白名单条目 | 落点核对 |
|---|---|---|
| `Features/S2/S2View.swift` | A／B／C／D + `S2MediaMetrics` | 新增容器与四个子项的构造件；既有代码只改 `pageContent` 三处赋值与 `onLongPress` 闭包 |
| `App/CleanupCoordinator.swift` | **仅**新增只读 `s2AssetMediaKind(for:)` | +13 −0，纯新增，紧邻同族三个访问器；`s1*` 与 S3～S5 路由零改动 |
| `App/PhotoCleanupMVEApp.swift` | **仅** S2 构造处加实参 | 抽 builder（陷阱 16）+ 一个实参；−113 全部是整段外提，非删除 |
| `Localizable.xcstrings` | 4 个新键 | 206 → 210 |
| `PhotoCleanupMVETests/IC139MediaBadgesTests.swift` | 新测试文件 | 17 项 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 新测试文件登记 | +4 −0 |

**`S2NativePhotoPager.swift` 逐字节不变**：
- `db318fc` 侧 SHA-256 = `344cfcd525ad58d7ff3e80c923c37621d08833b9122116695305cb95caeb54c4`
- `fd7c983` 侧 SHA-256 = `344cfcd525ad58d7ff3e80c923c37621d08833b9122116695305cb95caeb54c4`
- 文件不在 diff 文件集合内

`Core/S2StateMachine.swift` **未改**——白名单里那条「仅当 C 需要」的授权没有用到。

### G792（`S2Calibration.swift` / `schemaVersion` / S1・S3～S5 / 冻结链）：**通过** ①

- `S2Calibration.swift` **不在 diff 中**；`schemaVersion` 仍为 **7**（:118）
- 媒体常量全部走登记制 `S2MediaMetrics`，不进标定配置、不上标定面板，
  故不构成出厂值集合变更
- diff 文件集合中**无任何** `Features/S1`／`Features/S3`／`Features/S4`／
  `Features/S5`／`Core/S1`／`Core/S3`／`Core/S4`／`Core/S5` 路径（grep 命中 0）
- 冻结三链与探针分支（本卡前后两次实测未变）：
  `feature/ic-089-nx-edge-bounce` `b368a6c`、
  `feature/ic-091-nx-midgesture-handoff` `6736f1e`、
  `feature/ic-092-nx-window-follow` `a7cc1ec`、
  `probe/ic-067-screenshot-subtype` `9db02b9`、
  `probe/ic-125-sentinel-negative` `402cb6e`、
  `probe/ic-137-media-playback` `486bcb7`（只读参照，未 cherry-pick、未合并）

### G793（绿 + 九条断言逐条落实）：**通过** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#271**（run id `34226691819`，attempt 1） |
| 被测提交 | `564a5f39bbec7bc8b9fb1f82f7e4a9f5e20d6885` |
| 触发 | `push`，分支 `feature/ic-139-media-badges` |
| job | `102062431312`，conclusion=**success**，12:32:57Z→12:43:32Z，10 个 step 全 success |
| XCTest | **Executed 694 tests, with 0 failures (0 unexpected) in 29.674 (35.739) seconds** |
| `** TEST SUCCEEDED **` | 在位 |
| 摘要 notice | 在位（IC-125 哨兵通过，694 > 0）；`##[error]` 0 条、`##[warning]` 0 条 |
| 真实退出码 | **0**（全日志无「Process completed with exit code」非零行） |
| 目的地 | `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }` |
| IPA | **1305488 字节**，SHA-256 `e8d1417ca43a9368439b34a059956b987540cd1267815972e15f76bf5befa32f` |
| 产物 | `PhotoCleanupMVE-unsigned-564a5f39bbec`，zip 1305658 字节 |

**项数对账**：基线 677 → **694**，差 **+17**，即本卡新增的 17 条断言，
既有用例零增删；`IC139MediaBadgesTests` 单套读数 `Executed 17 tests, with 0 failures`。
17 个函数名**逐个在日志里查到 `passed`**（见上方各子项表），无一条是「写了但没跑」。

**CI 预算 3 次用 1 次。**

### G794（合并前置）：**通过** ①

- G791～G793 全满足；工作树净；`git fetch` 后 `origin/main` 仍为 `db318fc`
- `git merge --no-ff`，输出 `Merge made by the 'ort' strategy.`，**零冲突**
- 合并提交 **`fd7c983`** / `fd7c9831dfb8f5febc101f287fa587c92ce6259f`
  - parent1 `db318fc7f9cb9e94c4ead6a5edbb4ab493eb0bef`（原 `main`）
  - parent2 `564a5f39bbec7bc8b9fb1f82f7e4a9f5e20d6885`（分支 tip）
  - 合并树对象 `192a078bd3a322386397780cdc89cba81835c909` 与分支 tip 树对象**相同**
- 推送：退出码 0，报文 **`db318fc..fd7c983  main -> main`**（两点记法，非强推）
- 未 rebase、未 amend、未强推：`git reflog main` 顶部为 merge 条目，
  其下 `db318fc` 原样保留

### G795（合并后 `main` 自动运行）：**通过（绿）** ①

| 项 | 实测 |
|---|---|
| 运行编号 | **#272**（run id `34228403858`，attempt 1） |
| 被测提交 | `fd7c9831dfb8f5febc101f287fa587c92ce6259f`（合并提交） |
| 触发 | `push`，分支 `main` |
| job | `102068117135`，conclusion=**success**，12:50:51Z→12:56:41Z，10 个 step 全 success |
| XCTest | **Executed 694 tests, with 0 failures (0 unexpected) in 74.559 (129.402) seconds** |
| 摘要 notice | 在位；真实退出码 **0** |
| IPA | **1305488 字节**，SHA-256 `eb54f631f96f8a58336ed2020891d818a619448d0eaa7beb0109bccba6cd211e` |
| 产物 | `PhotoCleanupMVE-unsigned-fd7c9831dfb8`，zip 1305658 字节 |

IPA 字节数与 #271 完全相同（同为 1305488），SHA-256 不同——与「IPA 归档不可复现」
的既往实证一致，同时反向印证合并未改变任何产品代码。

---

## 本地门禁（真实退出码）①

| 门禁 | 退出码 | 备注 |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | 在合并后的 `main` 上跑；目录条目 **210**，key 与产品源码引用一致 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | 用户可见硬编码残留 0。SF Symbol 名一律写成 `static let`（陷阱 18：**返回字符串的展示 helper 会被抓**，故没写成函数）；文案一律走 `L10n.text` |
| `git diff --check`（工作树） | **0** | — |
| `git diff --check db318fc..fd7c983` | **0** | — |

四个阶段提交**各自单独**跑过 `selfcheck.ps1` 与硬编码扫描，退出码均为 0。

---

## 卡内前提与实测的出入（纪律第 3 条：不硬套、不凑逻辑）

### 一、断言 6 的措辞只对竖向受限资产成立（①）

卡内断言 6：「视频页显示态主图 frame 的 `maxY` 比照片页小 68、`minY` 相同」。

决策 57 的定义是「**适配区**下缘上移 68，上缘不变」——即适配区 = `[0, H − 68]`，
资产等比适配后**居中于该区**。由此：

| 资产 | 照片页 | 视频页 | 与卡内措辞 |
|---|---|---|---|
| **竖向受限**（高吃满，比例 0.4） | 高 852，`minY` 0，`maxY` 852 | 高 784，`minY` 0，`maxY` 784 | **相符**：`maxY` 小 68、`minY` 相同 |
| **横向受限**（宽吃满，比例 1.5） | 高 262，`minY` 295，`maxY` 557 | 高 262，`minY` 261，`maxY` 523 | **不符**：尺寸不变，两缘各上移 34 |

原因是「上缘不变」说的是**适配区**的上缘，不是**照片**的上缘；横向受限时照片
本就上下留白，缩短适配区只会让它重新居中。

**处置**：按决策 57 字面实装，两类**各写一条断言**
（`…LiftsBottomEdgeBy68` 与 `…RecentersInsideShortenedRegion`），
不挑让卡内措辞成立的那一类来写。请决策会话确认横向受限资产上移 34
是否即为期望；若期望是「照片顶缘也不动」，那是另一套几何（顶对齐而非居中），
需要改决策 57 的措辞并重做本子项。

### 二、B／C／D 无法脱离 A 单独 cherry-pick（①）

卡要求「四个子项各自独立 commit、各自可单独 cherry-pick」。前半做到了，
后半**对 B／C／D 不成立**，且不是拆分手法的问题：

- B 的浮框模型、C 的几何、D 的分派**都消费 A 定义的 `S2MediaKind` 与
  `assetMediaKind`**；
- C 的 `videoPageFitBottomInset` 写作 `videoBarHeight + videoBarBottomToStripTop`，
  这两个常量属 B。

即卡内分解本身是**链式**的。四个提交按 A → B → C → D 顺序拆开，
每阶段单独校验过括号配平、无悬空符号、两条本地门禁退出码 0。
A 单独 cherry-pick 成立。

### 三、`Core/S2StateMachine.swift` 的授权未用到（①）

白名单写「**仅当** C 需要把『视频页显示态下缘 inset』纳入既有几何输入」。
实测不需要——逐页 `fittedSize`／`fittedCenterY` 已够表达，故该文件零改动。

---

## 人工判定项（H63a，留给 Lynn 合并后真机，**执行端不代为下结论**）

1. **实况页左上胶囊**：位置（顶排下方 24）、大小、玻璃质感与顶排同套；
   照片页与视频页无胶囊。
2. **视频页浮框骨架**：横栏上方 24，三件可见、点了无反应（预期）；
   主图下缘上移不遮浮框；隐藏态浮框与胶囊一起消失。
3. **长按**：实况页长按无反应（预期，IC-140 接）、照片页长按不再出标定面板；
   长按顶部中胶囊出标定面板。

**装机包**：CI #271 产物 `PhotoCleanupMVE-unsigned-564a5f39bbec`
（IPA 1305488 字节，SHA-256 见 G793 表）；合并后 `main` 的产物见 G795 节。

**看第 2 项时请留意**：浮框底缘按视觉带高锚定，而反馈 toast 用的是含触控带
下限的旧推导式——若横栏视觉高小于 44，浮框与 toast 的竖直基准会差
`44 − 横栏高`。常规机型两者相同，看不出来；已在下节登记。

---

## 发现但未处理的问题（按纪律只报告不修）

1. **长按 0.8 s 在两处各写各的**（①）。分页器根视图那只识别器的
   `minimumPressDuration = 0.8` 是字面量（`S2NativePhotoPager.swift:2925`，
   自 IC-113 起），本卡的中胶囊长按用新登记的
   `S2MediaMetrics.longPressMinimumDuration`。**两个 0.8 无共同来源**，
   日后改一个不会带另一个。本卡不得改分页器文件，故未合并；
   建议 IC-141（或任一有分页器授权的卡）把识别器那处改为引用同一常量。
2. **`videoBarTimeFontSize` 已登记但未使用**（①）。卡内取值表注明「本卡不显示，
   IC-141 用」，故登记而不消费。若 IC-141 改用别的方案，这条会变成死常量
   （IC-138 刚清理过一个同类的 `volumeCornerRadius`），届时应一并处置。
3. **浮框与反馈 toast 的竖直基准来源不一致**（①）。
   `S2OverlayLayout.toastBottomFromViewportBottom` 走
   `stripTopFromViewportBottom`（含 `max(44, 横栏高)` 触控带下限），
   本卡的浮框走横栏**视觉**带高。两者在横栏视觉高 < 44 时会差
   `44 − 横栏高`。常规出厂值下两者相等，故当前无可见差异。
   toast 那条不在本卡白名单，未动；建议与陷阱 14 一并做一次统一。
4. **双击过渡端点与跨 `s` 边界连续性在视频页未覆盖**（①）。
   决策 57 明写这两项「一并核对」，但既有过渡断言绑在
   `S2CalibrationHarnessTests` 的私有夹具上，参数化需改该文件的既有 helper，
   超出本卡新增测试文件的范围。**如实标注未覆盖**，建议并入 IC-141
   （该卡本就要改双击快照取封面帧）。
5. **`m` 的判别谓词本身夹具不可达**（①）。`PHAsset` 造不出来，
   「`mediaType == .video` → video」这一步只能靠源码扫描 + H63a 真机兜底。
   若日后要在夹具里覆盖，需要给协调器加一个可注入的资产源，属结构改动。
6. **`CLAUDE.md` 第七节仍落后仓库多张卡**（①）。文中 `main` 写 IC-130 的
   `0bf5ebda`，规格基线行仍写 v18；实际 `main` 已到 `fd7c983`，
   规格已出 v19（`<top>/SPEC-S2-20260908_v19.md`，SHA-256
   `45f00e0f7e4549ba1ec44e14af73132fed34e47e5f65c62c3c3c14c8a75281b7`，本机实测）。
   `<top>/Tasks/` 下 `update-claude-ic135.ps1`、`update-claude-ic136.ps1`
   两个脚本仍待执行，现还要再加 IC-137／138／139 三笔。执行端无权改该文件，仅登记。
