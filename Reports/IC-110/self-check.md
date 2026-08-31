# IC-110 自验报告：视觉批次（双击曲线 / chrome 换装 / 残影动画 / 首次教程）

## 结论（先行）

**A、B、C、D 四项全部交付，最终绿 tip `351cc6e0588eb2b233fdfb3494e527b659947975`。**

- **G267 通过**：分支自 `main` 基线 `a013098…` 切出，开工工作树净。
- **G268 通过**：四项各自 CI 绿、按实计数 0 失败、真实退出码 0。最终绿 tip CI **#199**，**`Executed 544 tests, with 0 failures (0 unexpected)`**，IPA **902461 字节**、SHA-256 **`23b50a400b4ee03f163244c0ed6eb36a549fe4461b9f8d91f09faf0a871fa798`**。**该 IPA 即 Lynn 的 H47 包。**
- **G269 通过**：`schemaVersion == 6` 未动；冻结三链未触碰；**布局锚零 diff**——`S2Calibration.swift`（持有全部布局锚）自分支基线起**整文件零 diff**；`ci.yml` 与 `Scripts/` 零改动。
- **G270 未触发**：唯一一次红（#196）是编译错误（退出码 65，测试插错了类导致 `makeMachine` 不在作用域），失败项不含布局几何断言族、也不含 `testIC100B2`。
- **CI 预算 5/7**（A 1、B 2、C 1、D 1），**未超**。时间闸门自开工 2026-08-29 00:06 起 6 小时，收口于 01:5x，**未超时**。
- **全程未合并 `main`。**

**三项须决策会话裁定的发现**见「发现但未处理的问题」：卡内引用的 SPEC v18 与 Decision_log 137 在盘上不存在；子项 A 的实现前提与代码不符（已按目标实装）；子项 B 换装后有两处模型/渲染背离。

---

## 输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260830-110-visual-batch.md` |
| 分支 | `feature/ic-110-visual-batch`（自 `a013098341f36b1f0b8542055ac698a7569c9d61` 切出） |
| 最终绿 tip | `351cc6e0588eb2b233fdfb3494e527b659947975` |
| 范围边界 | 未合并 `main`；未动布局锚与任何出厂值；未动 SPEC、Decision_log、`ci.yml`、`Scripts/`；未 rebase / revert / amend / force push；未新增任何可调参数 |

开工检查（纪律第 8 条）：`git status --porcelain` 空（①）。

---

## 提交与 CI 一览

| 子项 | 提交 | CI | 结论 | XCTest | IPA 字节 |
|---|---|---|---|---|---|
| A 双击曲线 | `5f7d60dbca0452bbe47a28f0ba25c242d3b64c60` | **#195** | success | **530 / 0** | 857300 |
| B chrome 换装 | `cb76192465e72735f34f62e1ebd567dc3e3668ab` | #196 | **failure**（编译，退出码 65） | — | — |
| B 测试搬位 | `27e83f46a44fa347d65f75a51be4d9ca9b5d3a5a` | **#197** | success | **534 / 0** | 865032 |
| C 标记残影 | `36496a147816e7df3b991a13b6924834debe42c8` | **#198** | success | **539 / 0** | 878655 |
| D 首次教程 | `351cc6e0588eb2b233fdfb3494e527b659947975` | **#199** | success | **544 / 0** | 902461 |

最终绿 tip IPA SHA-256：`23b50a400b4ee03f163244c0ed6eb36a549fe4461b9f8d91f09faf0a871fa798`（CI 内「未签名 IPA 校验」步骤实算，①）。

真实退出码：`ci.yml` 以 `exit "$test_status"` 原样退出，四次绿运行步骤 6 均 `success`，即退出码 0（①）。

---

## 子项 A：双击缩放过渡时长与曲线

**行为**：双击进 `Nx` 与回 `1x` 的过渡时长由 180 ms 改为**常量 300 ms**（60 fps 约 18 帧），缓动由**线性**改为 UIKit `curveEaseInOut` 的三次贝塞尔（控制点 0.42/0 与 0.58/1，牛顿迭代 + 二分反解）。

**端点语义零变化**（①）：缓动端点恒等；`S2DoubleTapTransition` 的 `frame(at:)` / `cornerRadius(at:)` / `transform(at:)` **一字未动**，仍是进度的线性插值。决策 19 目标倍率规则、决策 20 基准与截图跳变契约、记录的显隐恢复均不受影响；`testIC063G4DoubleTapSynchronizationPreservesWindowFrameBothWays` 直接以显式进度调用 `frame(at:)`，本次改动后仍绿。

**时长与曲线均为常量**：`S2DoubleTapTransitionTiming`，不入 `S2CalibrationConfiguration`、不上参数面板、`schemaVersion` 不动。未新增可调参数。

**`setZoomScale` 统一记录点未被绕过**（IC-090 R2）：本次未新增任何 `setZoomScale` 调用点，原有调用全部照旧经 `S2NativeZoomScrollView.setZoomScale` 记录。

**IC-108 双击探针仍能采样**：探针埋点位于 `startDoubleTapTransition` 与 `advanceDoubleTapTransition`，两处均保留；时长变长后 60 fps 下应采到约 18 帧（H47 复测项）。

**几何诊断中间帧保证不变**：诊断原先靠临时改大 `animationDurationMilliseconds` 来保证 `(n+2)×50 ms`；时长改常量后该手法失效，故新增 `durationOverrideSeconds` 显式入参，取值与改动前逐位相同，产品路径永远走常量。

**停线 A1 未触发**：本次未引入新的自驱动画——双击**早已是** `CADisplayLink` 驱动的叠加层过渡（见下方前提更正），本次只改时长取值与进度映射，未新增与原生捏合/双击竞争的属性写入。

| 验收点 | 测试函数 |
|---|---|
| 时长为 300 ms 常量且与可调参数解耦 | `testIC110ADoubleTapDurationIsThreeHundredMillisecondConstant` |
| 缓动端点恒等与越界钳制 | `testIC110AEasingPreservesEndpoints` |
| 缓动严格单调 | `testIC110AEasingIsStrictlyMonotonic` |
| 对称 S 形（中点 0.5、前半慢后半快、`eased(x)+eased(1-x)=1`） | `testIC110AEasingIsSymmetricEaseInOutCurve` |
| 有界且不退化为 smoothstep | `testIC110AEasingStaysBoundedAndDoesNotDegenerateToSmoothstep` |

### 前提更正（③ → ①，须决策会话知悉）

卡内写「**现为 `setZoomScale(_:animated: true)` 的 UIKit 内置动画（`:448` 族）——改时长需自驱动画**」。**实测与代码不符**（①）：

- 双击真实路径为 `handleDoubleTap(on:at:)` → `page.startDoubleTapTransition(...)` → `CADisplayLink` 驱动的 `S2DoubleTapTransitionView` 叠加层，**早已是自驱动画**；
- 时长取自**可调参数** `animationDurationMilliseconds`（出厂 **180**，非卡内所称 ~194），曲线为**线性**；
- `:448` 的 `animateToMinimumZoomScale()` 是**捏合结束归位**路径（`returnToMinimumZoomScale`），不是双击。

目标（≈300 ms、近系统缓动）不受该更正影响，且实现比卡内预估更简单，故按目标实装并在此登记，未硬套原前提。

---

## 子项 B：chrome 换装

**结构**：整条不再铺满玻璃，改由三枚药丸各自承载 `.regularMaterial`。顶部＝左圆（返回 `chevron.left`）+ 中胶囊（日期主行 + 序号·大小副行）+ 右圆（删除确认 `trash`，角标叠在圆钮之上）；底部＝左圆（收藏 `heart`/`heart.fill`）+ 中胶囊（加入最近相簿 `clock`）+ 右圆（加入相簿 `rectangle.stack.badge.plus`）。

**硬约束达成——布局锚零改动**（①）：`S2Calibration.swift` 自分支基线起**整文件零 diff**。`topBarHeight` 48、`topLeadingControlWidth` 88、`minimumTouchTarget` 44、`minimumSpacing` 8、`horizontalPadding` 8、`actionBarVisibleBandHeight` 22、`stripToActionVisibleBandSpacing` 30.7、安全区推导、截图等距带推导全部未动；顶栏仍 `.frame(height: topBarHeight)`，操作条仍 `.frame(minHeight: 44)`，底缘锚点表达式原样保留。既有几何断言在零改动下全绿。

**`S2ActionBarPresentation` 零语义变化**：启用/禁用规则一字未动，`testIC076R3ActionBarPresentationDisablesOnlyInFlightButton` 原样绿。原 `Label(标题, systemImage:)` 改纯图标后，标题文案原样转为 `.accessibilityLabel`，**未新增 xcstrings key**（复用 `s2.action.back` / `favorite` / `unfavorite` / `add_album` / `add_recent_album`）。

**视觉微观取定**（卡内取定 + 登记，`S2ChromePillMetrics`，常量、不入标定、`schemaVersion` 不动）：圆钮直径 **36**、胶囊最小高 **36**（与圆钮同高以对齐视觉带）、胶囊水平留白 **12**、图标字号 **16**。

| 验收点 | 测试函数 |
|---|---|
| 布局锚零改动 | `testIC110BLayoutAnchorsAreUnchangedByChromeRestyle` |
| 药丸取值自洽且不超 44 触控带 | `testIC110BChromePillMetricsFitInsideTouchTarget` |
| 顶栏三槽几何不变 | `testIC110BTopElementFramesUnchangedByChromeRestyle` |
| 中胶囊沿用最近相簿条件显示与启用规则 | `testIC110BCenterCapsuleFollowsExistingRecentAlbumVisibility` |

### 底部中胶囊：卡内 ④「加入微信」与代码不符，已由 ④ 定案改占位

卡内 ④ 写底部中胶囊为「**加入微信**」。**逐处核查后，微信在三处均不存在**（①）：代码库全仓零命中；`SPEC-S2-20260829_v17.md` 零命中；`Decision_log.md` 零命中。现有底部三按钮为 收藏 / 加入「{album}」最近相簿（**条件显示**）/ 加入相簿——左圆与右圆和卡内一致，只有中位对不上。

新增「加入微信」属**按钮增删**，卡内明令「语义级偏离（按钮增删、位置调换）不得自定」，故就地停下询问。**④ 2026-08-29 定案：用现有最近相簿占中胶囊**，微信另行立项。已按该定案实装：中胶囊承载现有「加入最近相簿」按钮，沿用原条件显示语义（`recentAlbum` 为 `nil` 时不显示，中位以 `Spacer` 留空、只余左右圆钮）。

---

## 子项 C：标记残影飞入

**行为**（决策 32 ④）：上滑标记成功瞬间生成缩小半透明残影，沿二次贝塞尔弧线飞入横栏对应格位；落点淡出后由格位角标接手。

**触发不旁路手势分派**（同 IC-104 B1 纪律）：以已发布状态 `pendingDeletionAssetIDs` 的**新增**判定「上滑标记成功」。由此三条自然成立——下滑取消是**移除**、不进该分支，故无残影也无反向飞出（卡内取定，角标随集合变化淡出）；隐藏态与 `Nx` 无标记手势（第 132 条），不产生新增，残影路径**结构上不存在**。

**并存与收尾**：`S2MarkAfterimageCoordinator` 只管在途集合，上限 **3**（卡内取定），快速连续标记时并行互不阻塞；越界时**最旧者立即收尾**并登记进 `forcedCompletions`。角标由 `pendingDeletionAssetIDs` 驱动、与动画无关，故提前收尾不丢角标。

**收口（陷阱 8）**：动画只挂在 `S2MarkAfterimageView` 这一层，收尾即整体移出 `ForEach`，不留残余层。

**几何为纯函数常量**（`S2MarkAfterimageFlight`，不入标定、`schemaVersion` 不动）：时长 **0.42 s**、落点缩放 **0.18**、起始透明度 **0.55**、弧线抬升系数 **0.32**。起点取主图显示帧中心（视口中心 X + `oneXDisplayCenterY`，故截图的适配带锚定同样正确）；终点用 `S2BottomStripLayout.frame` 复算格位中心，**与横栏渲染同一套推导式，不另起真相**。

| 验收点 | 测试函数 |
|---|---|
| 并存上限 3 与最旧者收尾顺序 | `testIC110CAfterimageCoordinatorCapsConcurrencyAtThree` |
| 收尾幂等 | `testIC110CAfterimageFinishIsIdempotent` |
| 飞行端点恒等与越界钳制 | `testIC110CFlightGeometryPreservesEndpoints` |
| 确为弧线（曲线中点严格高于弦中点）且零距离不产生 NaN | `testIC110CFlightIsAnArcAboveTheChord` |
| 缩放与透明度端点及单调收缩 | `testIC110CFlightScaleAndOpacityEndpoints` |

### 停线 C1 说明

**未走图层快照路径。** 残影内容复用 `stripItemContent` 渲染的**已解码图**，不存在「同步读取主图层内容」这条路径，故 C1 的前提**结构上不成立**——这正是卡内点名的替代方案（「用已有解码图直接构影」）。选择该路径是为规避风险，而非事后补救：本机无真机、无法用探针实测掉帧，因此**不以「实测未掉帧」冒充结论**。真机掉帧与观感保留给 H47 判定。

---

## 子项 D：首次引导教程

**五步脚本**（未定项 20，④ 流程 + 决策会话补充）全部实装，全程显示态、1x，用用户当前真实照片，**不发生任何真实删除**——第 5 步只指向确认入口并结束，不进入确认页。

**停线 D1 不成立，且不旁路手势分派**（参照 IC-104 B1）：三处「等真实手势」全部靠状态机已发布状态判定——上滑标记＝`pendingDeletionAssetIDs` 新增、下滑取消＝同集合移除、翻回＝`currentAssetID` 变为记下的那张。`S2TutorialCoordinator` **不接触任何手势识别器**；浮层在这三步整层 `allowsHitTesting(false)`，手势原样落到主图。

**推进规则**：第 2 步「点击任意处或 2 秒」两条分支都走同一个 `acknowledge()`；等真实手势的三步对 `acknowledge()` 无反应（`waitsForRealGesture` 守卫），有测试专盯。

**持久化**：新增 `PhotoCleanupMVE/Services/S2TutorialCompletionStore.swift`（协议 + `UserDefaults` 实现，键 `…s2.tutorial-completed`）。只存一个布尔，**不入 `S2CalibrationConfiguration`**，故不是出厂值、`schemaVersion` 仍为 6。协议化以便断言注入内存实现，与 `S2RecentAlbumStoring` 同款。工程注册按 `S2RecentAlbumStore.swift` 的四点式样补齐（`PBXBuildFile` / `PBXFileReference` / 组 `children` / `Sources` 构建阶段），ID 取未占用的 `…034` 与 `…031`。

**跳过与离开**：右上角常驻「跳过」；中途离开 S2 视为跳过、不拦截；两者都落盘，下次进入不再复现。标定面板新增「重看教程」——清持久化并当场重放。

**文案**：7 条按**纯文本插入** xcstrings（未用 json 重排全文件，IC-108 经验）。目录 188 = 产品源码引用 188。

| 验收点 | 测试函数 |
|---|---|
| 五步顺序推进，每步只认该等的事件 | `testIC110DTutorialAdvancesThroughFiveStepsInOrder` |
| 等手势三步不接受点击推进（D1 的形式保证） | `testIC110DGestureStepsIgnoreTapAdvance` |
| 跳过与中途离开均落盘且不复现 | `testIC110DSkipAndLeavePersistCompletion` |
| 重看教程清持久化并重放 | `testIC110DReplayResetsPersistenceAndRestarts` |
| 步骤目录自洽（五步文案互不相同、自动推进 2 秒） | `testIC110DStepCatalogIsWellFormed` |

**证据分级**：D 的五项均为**夹具驱动**的状态机断言，**真机未覆盖**（陷阱 1），由 H47 兜底。

---

## 本地门禁（本机 Windows，①）

四个子项每次提交前均跑满三门禁，**全部退出码 0**：

| 门禁 | 真实退出码 |
|---|---|
| `git diff --check` | 0 |
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |

---

## H47 人工判定清单（原样列出，保留给 Lynn，不代为下结论）

1. 双击进/出观感：时长与缓动是否接近系统；探针复测一轮（帧数 ≈18、零丢帧）。
2. 顶/底 chrome：对照系统 Photos 观感（玻璃、胶囊、圆钮）；**等距带回归**——截图顶缘/底距不变。
3. 标记残影：单张与快速连标多张（≥5 张）都不卡、不叠爆；角标与格位脉冲正确。
4. 教程：完整走一遍五步；跳过路径；面板重看入口；全程无真删除。
5. 回归抽查：翻页跟随、隐藏态手势、占用空间、标记→确认页流程。

**H47 包** = 最终绿 tip `351cc6e` 的 IPA（CI #199，902461 字节，SHA-256 `23b50a40…`）。

---

## 发现但未处理的问题（按纪律只报告不修）

1. **卡内引用的两份上游文档在盘上不存在**（①）：卡内写「落文入 Decision_log 137 与 v18」，但 `Decision_log.md` 止于第 **136** 条，`<top>/` 下最高规格为 **v17**（无 v18）。卡本身已完整载明四项 ④ 决策内容，且两份文件对执行端只读，故按卡执行并在此登记；**上游落文与本卡实装的一致性需决策会话复核**。

2. **子项 A 的实现前提与代码不符**（详见 A 节「前提更正」）：双击早已是自驱动画、时长取自可调参数 180 ms、`:448` 是捏合归位路径。目标未受影响，已按目标实装。

3. **子项 B 换装后两处模型/渲染背离**（本卡不改锚值，按卡停在「只报告」）：
   - `actionBarVisibleBandHeight = 22` 的语义是「图标 + 文字的可见带高」；换装后真实可见带为 **36**，该常量就此**过时**。横栏位置仍由常量推导，故几何不动、断言全绿，但**肉眼可见的「横栏 ↔ 操作条」间距由 30.7 变为约 23.7**。这正是 H47 第 2 项要对照的地方。
   - 快照模型 `S2OverlayLayout.snapshot` 把底部三件算作**等宽三列**；换装后真实渲染为圆-胶囊-圆**不等宽**。模型未改故既有断言全绿，但模型不再逐一描述渲染实况（「双真相」隐患，与陷阱 13 同源）。

   两者都属视觉稿阶段应由决策会话裁定的锚值问题。

4. **三组视觉常量目前散落在视图层**（`S2ChromePillMetrics` / `S2MarkAfterimageFlight` / `S2DoubleTapTransitionTiming`），不进标定登记制。若日后要纳入参数面板或规格，需要一次统一归置。本卡按「禁止新增可调参数」保持常量形态。

5. **硬编码扫描器的两个陷阱**（本卡各踩一次，已在提交信息与代码注释中登记，建议补进 CLAUDE.md 第八节）：
   - **key 不能用插值拼**。扫描器只认取文案调用里写死的字面量；用 `rawValue` 拼出来的 key 会被判成「目录有条目、源码无引用」。
   - **注释里出现取文案调用的样子会被当成真 key 抓走**。本次因注释里写了示例，凭空多出 2 个不存在的 key，门禁直接红。注释里不要写出该调用的形状。

6. **#196 编译失败成因如实登记**：四项新测试被插到了 `FakeAssetActionService` 里而非测试类内，`makeMachine` 不在作用域（退出码 65）。根因是插入锚点用了「类尾花括号 + 后随注释」这种在多类文件里不唯一的模式。后续两次插入改为**先定位类边界行号、插完再核对边界**，未再复现。
