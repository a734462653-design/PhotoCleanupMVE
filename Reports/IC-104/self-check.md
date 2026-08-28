# IC-104 自验报告（A + B 已交付；C v3 绿于 #187，C v4 于描边探针歧义处停线）

覆盖 IC-104 全程：首轮停线（#178）、子项 A 收官（#180）、子项 B 收官（#181）、子项 C v1 规格冲突停线（#182）、子项 C v2 交付（#183 → #184）、子项 C v3 旧位锚定返工（#185 → #186 → **#187 绿**）。

## 结论（先行）

**A、B 已交付；C v3 已绿（#187）但复测第 ② 点不通过；C v4 按视觉锚实装后 CI #188 红，唯一失败测试的失败原因存在两种互斥读法且无法就地区分，按纪律 5 停线，未动用最后一次 CI 预算。**

- **C v4 状态**：实装已提交并推送（`4996873e8e102096e5de07913b035bab34a450d1`），CI **#188 failure**，`Executed 520 tests, with 8 failures`
- **C v4 CI 预算**：**1 / 2 次已用**，剩 1 次**未动用**
- **Cv4-3 判定**：失败**不含** `testIC100B2`，8 项全部集中在**单个**测试 `testIC070G77FitBorderIsConcentricAtCornersBeforeAndAfterToggle`
- **当时最新绿 tip 与 run**：`0d461ccd6a7aa54a869d6494e9265785cb2a51b9` / **CI #187**（C v3 的包；Lynn 已判其第 ② 点不通过，本轮**未产出改进包**）
- **IC-107（合并入 main）**：因六点复测未通过，**本卡作废、未执行**；`main` 保持 `e6bd5aa890bff15b18c4569da4ae73c75f622578`

**C v3 的交付事实（#187，仍是当前最新绿）：**

- **最终绿 tip**①：`0d461ccd6a7aa54a869d6494e9265785cb2a51b9`
- **最终 CI**①：**#187 success**，9/9 步全绿，**真实退出码 0**，`Executed 520 tests, with 0 failures (0 unexpected) in 36.084 (52.830) seconds`
- **IPA**①：**837925 字节**，SHA-256 **`747a8b6e15ff7443632d6afebb6863bec63b58ba850d8f7d3ed55eabe9c41991`**
- **闸门**：A1、B1、C1、C2 评估后均未触发；Cv2-1、Cv2-2、**Cv3-1、Cv3-2** 通过；Cv2-3 与 **Cv3-3** 的停线信号（`testIC100B2`）全程未触发；`g ≤ 0` 未触发
- **CI 预算**：本卡（v7）2 次，**已用 2 次**（#186、#187）
- **时间闸门**：C v3 收官开工 2026-08-28T13:50:56Z，到期 16:50:56Z，**完成于 14:11:11Z，未到期**
- **`main` 全程未被触碰**（停在 `e6bd5aa`），分支独立；`schemaVersion == 6`；冻结三链未动

**Lynn 复测清单 6 项全部可测**（第 6 项为本次新增的捏合/双击瞬间跳变观感）。

## 子项 C v4：带底缘改锚横栏视觉顶缘（复测第 ② 点返工）

### 开工检查（通过）

工作树净；分支 tip = `c09e5c915a672ba1a8b1fc5aff78dd9b849c66d5`。开工 2026-08-28T15:11:36Z，2 小时闸门到期 17:11:36Z（**未到期**，停线非超时）。

### 一、根因（本会话只读复核，独立印证卡内定位）①

| 锚 | 推导 | 出厂值下取值 |
|---|---|---|
| **触控锚** `S2OverlayLayout.stripTopFromViewportBottom` | `stripBottomFromViewportBottom + resolvedStripHeight`，而 `resolvedStripHeight = max(minimumTouchTarget 44, 横栏高)`（`S2Calibration.swift:949`、`:964`） | 用 **44** |
| **视觉锚** 渲染容器 | `S2View.swift:766` `.frame(height: viewportMetrics.bottomStripHeight)`，用**原始横栏高** | 用 **30** |

**两者差 `44 − 30 = 14` pt。** C v3 用触控锚取带底缘，视觉底距因此比顶距多 14 —— 与 Lynn 真机截屏像素测量（视觉横栏顶 ≈724、底距 ≈35、顶距 ≈21）逐项吻合。照片顶缘实测 128 ≈ 理论 127.8，确认 C v3 的顶部锚定与摆放正确，仅底缘锚点选错。

### 二、产品侧实装（唯一行为差，相对 #187）

- 新增 `S2ViewportLayout.stripVisualTopFromViewportBottom` = `stripBottomFromViewportBottom + 原始横栏高`（与渲染同源，**不做 44 下限**）
- `screenshotBandHeight` 的横栏顶缘由触控锚改为视觉锚
- 带顶缘（`0.15 × 视口高`）、`g`、摆放、过渡 position 分量、隐藏态、圆角、chrome 布局、触控带语义（命中区域、toast 等既有消费方）**一律不变**

**Cv4-2 核验**：产品 diff 仅 `S2Calibration.swift` 一个文件；`stripTopFromViewportBottom` / `resolvedStripHeight` 本体、渲染层、`S2View.swift`、`S2NativePhotoPager.swift`、chrome 布局**全部零 diff**；未新增可调参数；`schemaVersion == 6`；冻结三链未动。

### 三、卡内要求的带常量硬编码全量扫描：**0 处**

逐个扫描 `382.9`、`191.45`、`289.9`、`270.15`、`29.85`、`450.3`、`561.7`、`17.35`（另加 `360.3`、`127.8`、`20.8`）——**全部 0 处**。C v3 时代已把带常量一律写成推导式（`screenshotBandTop`、`expectedScreenshotBandHeight()`、`expectedScreenshotBandCenterY()`、`expectedOneXToNxCenterJump()`、`metrics(...).oneXDisplayCenterY`），故「逐处换数」这一项无事可做。

测试侧实际只需改两处**触控锚 → 视觉锚**：`testIC104C…AnchorsLegacyTopWithEqualGaps` 的带几何、`testIC104CScreenshotRenderedFrameSitsAtLegacyTopAnchor` 的渲染帧摆放。另在前者新增一条断言把差值本身锁住：`视觉锚 − 触控锚 == max(44, 横栏高) − 横栏高`。`testIC100B6`（toast，范围外）的触控锚原样未动，且其 `stripHeight = 72 > 44` 本就无差。

### 四、与卡内数值的一处不符（按语义实装，如实登记）

卡写「夹具 300×600/`.zero`：带高 **382.9 → 396.9**」。但 `382.9` 是 **C v2** 的夹具带高；**C v3 的夹具带高是 360.3**（带顶缘 90、带底缘 450.3），+14 后应为 **374.3**。卡内其余数字与本报告推导**逐个吻合**：带底缘 450.3 → 464.3 ✓、带中心 270.15 → 277.15 ✓、跳变量 29.85 → 22.85 ✓、393×852 的 561.7 → 575.7 ✓（皆为 +14 / −7）。仅这一对带高沿用了 C v2 旧值。因测试全部走推导式，该笔误不影响实装。

### 五、CI #188

| 项 | 值 |
|---|---|
| run 编号 / id | **#188** / `33184560783` |
| 被测提交 | `4996873e8e102096e5de07913b035bab34a450d1` |
| 起止 | 2026-08-28T15:19:21Z → 15:24:47Z |
| 结论 | **failure**，失败步骤 6「运行 XCTest」（步骤 1–5 全 success） |
| XCTest | `Executed 520 tests, with 8 failures (0 unexpected) in 46.477 (56.502) seconds` |
| 真实退出码 | **65**① |
| 步骤 7/8 | skipped，**无 IPA** |

**8 项失败全部集中在单个测试** `testIC070G77FitBorderIsConcentricAtCornersBeforeAndAfterToggle`（IC-070 的描边同心性像素探针），`initial` 与 `after_hide_show` 两个阶段各 4 项：

```
:6745 / :6768  角=bottomLeft ：首个非背景像素不是描边  first=241，要求 <234
:6745 / :6768  角=bottomRight：同上
:6745 / :6768  角序号=2 / 3：圆角与直边宽度差  0.0 vs 1.0163398692810457 (±0.5)
```

### 六、已确定的事实与停线理由

**已确定（①）**：
- 失败**只在底部两角**；**顶部两角通过**
- 四条**边**扫描全部量到描边，`edgeWidth = 1.0163` ≈ 1pt 出厂线宽 → **描边本身渲染正确**
- 角扫描的 `coverage = 0`，因为 `borderScanReading` 在 `first = 241` 时即命中 `gray >= photoGray - 3`（234）而 `break`
- 对角射线与圆角弧的几何在两版下**完全相同**（射线过弧心、径向穿越；解析解 `t ≈ 30.6 → 32.7` 落在描边带内），差别只在子像素落点：C v3 角 `(59.925, 450.3)` → @3x `(179.775, 1350.9)`；C v4 角 `(56.425, 464.3)` → `(169.275, 1392.9)`

**探针的判定窗口**（`borderScanReading`，`:9076`）：`gray >= 250` 记为背景；首个 `< 250` 记为 `firstNonBackground`；只要它 `>= photoGray − 3 = 234` 立即 `break`。**234–249 是一个 16 级宽的死区**，任何落在其中的抗锯齿像素都会让扫描提前中止。

**两种互斥读法，导向相反处置**：

| 读法 | `241` 的来源 | 含义 | 正确处置 |
|---|---|---|---|
| **A. 探针死区** | 白 255 与描边（黑）按 5.5% 覆盖混合 | 探针缺陷，与产品无关；C v3 只是子像素落点侥幸避开 | 抬高背景阈值（如 250 → 243），属修探针，**不改产品、不放宽 `first < 234`** |
| **B. 同心性亚像素偏差** | 白 255 与照片 237 按 78% 覆盖混合 | **真实伪影**：底部两角有一缕未被描边覆盖的照片边缘 | **不得掩盖**，须报告并另行定位 |

两种混合都能得出 241，**单凭该值无法区分**。而这条测试的名字就是 *Concentric*——读法 B 恰是它设计来防的情形。若按 A 抬阈值而真相是 B，等于把真实伪影登记为正确行为，触犯**纪律 5「不伪造通过」**。故**不动用最后一次 CI 预算**，停线报告。

### 七、区分两种读法所需的数据（已存在，本机取不到）

该探针每次扫描都会打印

```
IC070_G77 phase=<阶段> path=diag_<角> first=<值> width=<值> grays=[<60 个采样>]
```

**这些行已在 CI #188 的 job 日志里**（job id `98894082654`）。看 `grays` 数组在 241 之后的走向即可一锤定音：**随后转黑（趋近 0）= 读法 A**（描边就在后面，探针提前中止）；**随后维持 ~237 = 读法 B**（先撞上的是照片边缘，描边未覆盖到该处）。

本机 `actions/jobs/{id}/logs` 端点全会话不可用（多次代理与直连重试均失败，与 #182 / #185 同一现象），**但决策会话在浏览器里打开该 run 的日志即可直接读到**。

### 八、需要决策会话裁定的问题（一条）

**依 `grays` 实际走向确认是 A 还是 B，并授权对应处置**：

- 若为 **A**：授权把 `borderScanReading` 的背景阈值由 `250` 抬到能吞掉抗锯齿薄边的值（`241 < 阈值 ≤ 250`，且须 `> photoGray = 237`，故窗口为 `238…250`；建议 `243`），`first < photoGray − 3` 的断言原样保留。此路径下剩余 1 次预算足以收口。
- 若为 **B**：属新发现的产品级亚像素伪影，需单独定位描边层与照片层在底部圆角处的取整差，不在本卡范围内。

## 子项 C v3：等距带改旧位锚定（H45 第 5 项返工）

### 上游裁定的落实

Lynn 的 ④：**截图顶缘必须保持旧版（v15 比例内缩）位置不动**，上下两段间距按旧顶距等距、只缩截图；**「横栏—操作条」30.7 不参与等距**。决策会话另裁定两条：显隐过渡的 morph 含平移属几何必然（v6 选项 A）；捏合/双击进入瞬间的位置跳变同属 SPEC 决策 20「跳到该基准」与 ④ 组合后的几何必然，**不修订规格、不加中途过渡**（v7 选项 A）。

### 一、摆放勘查结论（勘查轮产出，本轮采信并已修复）

`s = 1` 显示态几何写入**单一入口** = `S2NativeZoomScrollView.enforceOneXContentGeometry`（`S2NativePhotoPager.swift:761`，落笔 `:805`）。C v2 的实际摆放是**视口居中**（`targetPhotoCenter.y = targetZoomBounds.midY`，而截图 `nativeZoomBaseSize = physicalSize`）——`oneXDisplaySize` 只决定尺寸，摆放另有出处。

**C v2 的测试缺口属实**：`testIC104C` 中 `photoTop` 是**被定义**为 `topBarBottom + spacing`、而非从渲染帧读出，整条断言是对计算值的算术恒等式，**从未校验过真实摆放**。本卡已补渲染帧摆放断言（见第四节）。

**H45 第 5 项不通过的完整成因为两条**：① 顶距取 30.7（已废除，改回旧位）；② 摆放是视口居中（已改为带中心）。

### 二、带几何与 `g` 核算（①，由代码常量推导）

常量：`topBarHeight = 48`、`stripToActionVisibleBandSpacing = 30.7`、`resolvedStripHeight(30) = max(44, 30) = 44`。

| 输入 | 带顶缘 `0.15 × H` | 顶部栏底缘 | **`g`** | 横栏顶缘 | 带底缘 | 带高 | 带中心 | 视口中心 | 中心差 |
|---|---|---|---|---|---|---|---|---|---|
| 夹具 300×600，`.zero` | 90 | 48 | **42** | 492.3 | 450.3 | 360.3 | 270.15 | 300 | 29.85 |
| 393×852，顶 59 / 底 34 | 127.8 | 107 | **20.8** | 710.3 | 689.5 | 561.7 | 408.65 | 426 | **17.35** |

与卡内参考数（`g = 42` / `g ≈ 20.8`、带顶缘 90 / 127.8）逐个吻合。

**`g ≤ 0` 停线检查：不触发。** 全部被支持输入下 `g > 0`：393×852/59 → **20.8（最小）**；390×844/47 → 31.6；430×932/62 → 29.8；428×926/47 → 43.9；375×812/44 → 29.8；375×667/20 → 32.05；320×568/20 → 17.2；夹具 300×600/0 → 42。

### 三、产品侧实装

| 层 | 改动 |
|---|---|
| 带几何 | 新增 `screenshotBandTop`（= `0.15 × 视口高`）与 `screenshotBandTopSpacing`（= `g`）两个纯推导式；`screenshotBandHeight` 改为 `(横栏顶缘 − g) − 带顶缘` |
| 常量 | `legacyVisibleFitTopRatio = 0.15`（`static let`，值即 `(1 − 0.70) / 2`）。**不是可调参数、不进登记表、不入 `S2CalibrationConfiguration`**，故 `schemaVersion` 不动 |
| 摆放 | `S2ViewportMetrics` 新增 `oneXDisplayCenterY`（截图 ∧ `V=显示` 取带中心，其余取视口中心）；`enforceOneXContentGeometry` 的竖直中心改按其换算（视口坐标 → `zoomContentView` 坐标）。**非截图与隐藏态换算结果恰为原值**，行为不变 |
| 管线 | `fittedCenterY` 经 `S2NativePageContent` → 页控制器 → `configure` 传递，默认 `nil` = 视口居中，既有调用点语义不变 |
| `Nx` 推迟 | position 目标与尺寸/圆角走**同一条**既有推迟机制（`s` 回 1 时经 `enforceOneXContentGeometry` 落笔），未新增独立路径或旁路 |
| 过渡 | 既有动画组内新增 `position` 关键帧，与 `scale`/`cornerRadius` **同组、同 `progressValues`、同 spring 曲线与时长**；`S2ImmersiveTransition` 的建模字段与触发条件一字未改 |
| 双击回 1x | 目标帧竖直中心同步取带中心 |

**chrome 布局函数与 30.7 登记值零 diff**（`actionBandCenterFromViewportBottom`、`stripBottomFromViewportBottom`、`stripTopFromViewportBottom`、`toastBottomFromViewportBottom` 及 `stripToActionVisibleBandSpacing` 的定义与取值全部未动）。

#### 与修订 1 字面不同的一处（已获 v7 追认）

修订 1 要求「挂该动画组的每一层（含 `fitBorderLayer`）必须同步获得该分量」。实测层级①：`fitBorderLayer` 由 `hostingController.view.layer.addSublayer(...)` 挂载，而 `presentationContentView === hostingController.view`，且 `fitBorderLayer.frame = hostingController.view.bounds`——**它是照片层的子层，不是兄弟层**，随父层 position 自动平移；再挂一份会**双重平移**。既有代码只给它动画 `cornerRadius` 与 `borderWidth` 并除以 scale 补偿，正是父子关系的写法。收口沿用既有 `photoLayer.removeAllAnimations()`（`:748`）与 `fitBorderLayer.removeAllAnimations()`（`:2159`），`removeAllAnimations` 覆盖新增分量，**每层清净**，陷阱 8 满足。v7 已追认「以无双重动画、收口每层清净为准」。

### 四、测试侧

#### 夹具伪几何修正（已获 v7 追认）

`testIC104C` / `D1` / `D2` / `F4` 把夹具 `physicalSize`（300×600）与 `overlaySafeAreaInsets`（顶 59）配对，新定义下 `g = 90 − 59 − 48 = **−17**`——该组合**不对应任何机型**（59pt 顶安全区对应 852 高视口），是夹具产生的伪几何。已改：`testIC104C` 用真实配对 `overlayPhysicalSize`（393×852）+ 顶 59 / 底 34（恰得 127.8 / 20.8），其余三个改用 `.zero`（`g = 42`）。

#### 新增（1 个）

`testIC104CScreenshotRenderedFrameSitsAtLegacyTopAnchor`——**渲染帧**摆放断言，补 C v2 缺口：显示态 `minY == 0.15 × 视口高`、底缘距横栏顶缘 `== g`、`minY − topBarHeight == g`、`g > 0`；隐藏态回视口居中且填满。

#### 按新契约改写（9 处，全部精确断言，未放宽任何容差、未删除任何断言）

**类 (i) 静态摆放**

| 测试 | 旧 | 新 |
|---|---|---|
| `testIC065G27…IsVerticallyCentered` → `…SitsAtBandCenter` | `midY == 视口中心` | `midY == 带中心`、`minY == 0.15×H`，另断言 `视口中心 − 帧中心 == 跳变量` |
| `testIC063G2…` | `minY == H − maxY`（竖直对称） | `minY == 带顶缘`、`midY == 带中心`（**横向对称断言原样保留**） |
| `testIC065G31…` | `midY == window.midY` | `midY == expected.oneXDisplayCenterY`（一条覆盖 `.visible` 带中心与 `.hidden` 视口中心两轮） |
| `testIC067G41…` | 同上 | 同上 |
| `testIC067G36…` | `midY == H / 2` | `midY == 带中心` |

**类 (ii) 边界连续性**

`testIC065G28ToG29PinchTrackHasNoCenterJump` → **`…PinchTrackCentersPerZoomState`**：契约改述为「捏合全程每一帧的中心恒等于其所处 `s` 态的**规定中心**」。
- `s = 1` 帧 `midY == 带中心`；接管首帧 `midY == 视口中心`（两条精确断言）
- **跳变本身写成契约**：`pinchBegan.midY − oneX.midY == 两中心之差`（精确值）
- 接管之后各帧之间不再有跳变（原断言保留）；逐采样循环按 `sample.phase` 取该帧的规定中心
- **横向 `midX` 全程无跳变的断言原样保留**

**过渡端点（`testIC064G13ToG18…`）**：逐采样 `midY` 改区间断言（含 spring 过冲余量），两端点为精确断言（显示端 = 带中心、隐藏端 = 视口中心）；新增 position 关键帧断言（与 scale 同长度、端点覆盖两个中心）；**曲线/时长类断言不动**。

**`testX1…`（#186 唯一失败，即 #185 未定位的第 12 项）**：`reverseAnchor.y == metrics(visibility: .visible).oneXDisplayCenterY`，另加精确契约 `transition.viewportAnchor.y − reverseAnchor.y == 跳变量`；`transition.viewportAnchor`、`layer.anchorPoint == (0.5, 0.5)`、`targetScale` 各条**原样保留且全部通过**——证明 `S2ImmersiveTransition` 建模字段与变换锚点未被改动。

**隐藏态、圆角断言零改动。**

#### 收敛过程中更正的三处②推定

#185 停线报告中我按断言内容推定 `testIC067G40`、`testIC070G75`、`testIC070R5` 等也会失败，复核后**推定有误**，如实更正：`IC067G40` 断言的是 `prepareForNativeZoom` 之后的 **`s > 1` 基准**（照片填满视口，仍居中于视口）；`IC070G75` 与 `R5` 用 `isScreenshot: false`；`assertFitBorderConcentric`、`IC063G4`、`IC070R6` 中的 `midY` 是**以帧自身为基准的扫描坐标**而非对视口中心的断言。四者均不受影响，实测全部通过。

### 五、行为变更登记（须 Lynn 真机判定）

| # | 变更 | 幅度（393×852） | 依据 |
|---|---|---|---|
| 1 | 显示态截图顶缘回到 `0.15 × 视口高` | 顶缘 127.8（旧位） | ④ Lynn |
| 2 | 底距 = 顶距 = `g` | `g = 20.8` | ④ Lynn |
| 3 | 显隐切换时照片随缩放**竖向平移** | ≈ 17.35 pt，走同一 spring 曲线与时长 | 决策会话 v6 选项 A |
| 4 | 捏合/双击进入 `s > 1` 的**瞬间位置跳变** | ≈ 17.35 pt，无过渡（尺寸跳变旧已有） | 决策会话 v7 选项 A（SPEC 决策 20「跳到该基准」+ ④ 的几何必然） |

### 六、CI 记录（C v3 三轮）

| run | id | 被测提交 | 结论 | XCTest | 说明 |
|---|---|---|---|---|---|
| #185 | `33175294331` | `efca050` | failure | 520 / 12 | 摆放契约变更引发，含捏合连续性冲突 → 停线报告 |
| #186 | `33177682658` | `eb28f22` | failure | 520 / 1 | 八处断言改写后，仅余 `testX1:4158` |
| **#187** | **`33178302985`** | **`0d461cc`** | **success** | **520 / 0** | 9/9 步全绿，退出码 0，IPA 已产出 |

## 输入与边界

| 项 | 值 |
|---|---|
| C v3 开工 `git status --porcelain` | 空（纪律 8 检查通过） |
| C v3 开工时分支 tip | `d9dd55a770002f42fe19e9f395d3342a563c397f`（与下发单 v5 规定值相符） |
| C v3 开工时刻 / 时间闸门 | 2026-08-28T11:59:00Z / 14:59:00Z（**未到期**，停线非超时） |
| C v2 开工 `git status --porcelain` | 空（纪律 8 检查通过） |
| C v2 开工时分支 tip | `44ca59f4c0dfced6b96a3b2cb67d3427d7136301`（与下发单 v4 规定值相符） |
| 分支 | `feature/ic-104-single-build-batch`（**全程未合并进 `main`**） |
| 分支当前 tip | `2d3d7894e4b2f1c66e889974a8ad5997f4870463` |
| `main` | `e6bd5aa890bff15b18c4569da4ae73c75f622578`（本卡全程未改） |
| C v2 开工时刻 / 时间闸门 | 2026-08-28T03:34:51Z / 06:34:51Z |

## 子项 C v2：三等距限显示态，保留隐藏态沉浸

### 裁定的落实

决策会话废除卡 C1「几何与 `V` 无关（隐藏态尺寸不变）」一句。本卡按修订语义实装：**唯一行为差**是截图资产在 `V=显示` 且 `s=1` 的适配框改为 chrome 锚定带；隐藏态填满、显隐过渡、圆角描边、非截图资产、`s>1` 基准与绿 tip `1e77e6a` 逐条一致。

### 产品侧（相对 `1e77e6a`，逐条对照）

| 项 | `1e77e6a`（绿） | `3fbe8cb`（C v1，红） | **`2d3d789`（C v2）** |
|---|---|---|---|
| 尺寸门控 | `keepsFrame = isScreenshot && V==.visible` | **无门控**（恒用带） | **`keepsFrame` 原样恢复** |
| 门内尺寸 | `fitSize × (1 − fitInsetRatio)` | 带内等比适配 | **带内等比适配** |
| 门外尺寸 | `fitSize`（填满视口） | — | **`fitSize`（填满视口）** |
| 圆角 | `keepsFrame ? fitCornerRadius : 0` | 同条件展开式 | **`keepsFrame ? fitCornerRadius : 0`** |
| `fitInsetRatio` | 在位 | 已删 | **维持已删** |
| `schemaVersion` | 4 | 6 | **维持 6** |

**`S2NativePhotoPager.swift` 全程零 diff**①。显隐过渡与 `Nx` 推迟应用路径由 `metrics` 的 `V` 依赖驱动——`updatePage` 的门控条件是

```swift
let presentationChanged = sameAsset &&
    interfaceVisibility != page.interfaceVisibility &&
    isFramedPhoto && page.isFramedPhoto &&
    (fittedSize != page.fittedSize || cornerRadius != page.cornerRadius)
```

C v1 令几何与 `V` 无关 ⇒ `fittedSize` 与 `cornerRadius` 均不随 `V` 变 ⇒ 过渡不再触发（#182 中多项关键帧断言因此拿到空数组）。恢复 `keepsFrame` 即恢复过渡，**无需改动过渡代码**。

带高推导（`S2ViewportLayout.screenshotBandHeight`）：顶缘 = `safeAreaInsets.top + S2OverlayLayout.topBarHeight + 30.7`；底缘 = `physicalSize.height − stripTopFromViewportBottom(...) − 30.7`。两处 chrome 边缘都引用 IC-100 v2 既有推导式，**本卡未新增任何测量值**。

### 文案（卡内授权）

`Localizable.xcstrings` 的 `s2.calibration.reading.display_size`：「fitInsetRatio 生效后的实际显示尺寸：{width} × {height}」→「三等距适配框生效后的实际显示尺寸：{width} × {height}」。**1 增 1 删，其余字节不动**；扫描确认目录 177 条、产品引用 177、用户可见硬编码残留 0。

### 测试侧：两轮

**第一轮（`b7acd84` → CI #183，519 项 3 失败）**

卡预期「#182 失败的既有测试零改动恢复通过」对一部分测试不成立——我在推 CI 前用全量扫描（`210` / `420` / `0.70`）找出 **7 个硬编码显示态旧口径**的测试并逐个判定：

| 测试 | 判定 | 处理 |
|---|---|---|
| `testIC064G13ToG18PresentationSamplesMeetGeometryContract` | 过渡端点，**同时**含要保留的隐藏态 `physicalSize` 与要改的显示态 210/420 | 端点改由 `metrics(visibility:)` 派生 |
| `testIC069G53PresentationLayerFinishesWhileMainThreadIsBlocked` | 把 `210` 当源宽换算绝对宽度 | 同上 |
| `testF1FactoryInsetShrinksShortEdgeToSeventyPercent` | 0.70 短边 | 改名 `testF1FactoryFitBoxMatchesChromeBandHeight`，改带高推导式 |
| `testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight` | 同上 | 改名 `testS1FramedPhotoVisibleStateFitsChromeBandAndRadiusTwentyEight` |
| `testIC065G32BothDirectionsUseSameSpringCurveAndDuration` | **纯数学恒等式** `(210+90v)+(300−90v)≡510`，不调 `metrics` | **零改动**，恒成立 |
| `testIC067G42BothDirectionsAnimateWithoutOuterLayoutPhotoWrites` | `×210` 只是取整粒度，断言「关键帧 distinct 数 > 3」 | **零改动**，恢复门控即自愈 |
| `testIC063NativeBaseResizeIssuesNoImageRequestBeforePinchEnd:2632` | `CGSize(210,420)` 是**宿主视图尺寸输入**，非几何期望 | **零改动** |

同轮把 C v1 的两处「几何与 `V` 无关」断言回改为规格现行行为：`testIC104C…` 与 `testIC067G36…` 均改为 `hidden.oneXDisplaySize == hidden.aspectFitSize`（填满）+ `hidden.oneXCornerRadius == 0` + `NotEqual(hidden, visible)`。

**第二轮（`2d3d789` → CI #184，519 项 0 失败）**

#183 的 3 项失败**均未含 `testIC100B2GeometryIsIndependentOfInterfaceVisibility`**，Cv2-3 停线信号未触发，三项全部落在截图几何/沉浸/本卡改写的测试内，符合「允许用剩余预算修一次」：

| 失败项 | 实测数据 | 归因 | 处理 |
|---|---|---|---|
| `testIC065G31…` `:4985-4986` | `382.9000000000001` vs `382.90000000000003` | **浮点噪声**（差 ~1e-13） | 加 `accuracy: 0.000_001` |
| `testIC064G20…` `:5423` | `(191.45000000000005, 382.9000000000001)` vs `(191.45000000000002, 382.90000000000003)` | 同上 | 同上，**仅改渲染帧一处** |
| `testIC064G13ToG18…` `:5333` | `XCTAssertGreaterThanOrEqual failed: ("1") is less than ("2")` | **辅助函数潜在缺陷** | 加切片长度守卫 |

前两项的成因是口径变化本身：旧口径 `fitSize × 0.70` 是**单次乘法**，两侧位级相同；新带高是**多项加减**推导，经渲染层往返后产生末位噪声。**关键佐证**①：同一测试内 `XCTAssertEqual(page.fittedSize, value.oneXDisplaySize)`（`:5422`）**未失败**，只有走过 CALayer 的 `frame.size` 带噪声——确认是渲染回环伪影而非逻辑差异，故只对后者加容差，`fittedSize` 的精确断言原样保留。

第三项**不是本卡引入的错误**，而是暴露了 `assertSpringOvershootAndConvergence` 的既有缺陷：调用方已显式传 `requiresMeasuredOvershoot: false`（承认可能测不到过冲），函数却仍无条件对 `values[极值下标...]` 做单调检查；无过冲时极值即末样本，切片只剩 1 个元素，而 `assertMonotonic`（`:8549`）要求至少 2 个。**单元素本就平凡单调**，故加长度守卫，两个分支对称处理。端点断言（首 ≈0 / 末 ≈28）一字未动，**未放宽任何产品语义**。

### 零改动恢复通过的既有测试（断言的正是要保留的行为）①

`testIC063G1HiddenScreenAspectScreenshotMatchesScreenBounds`、`testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius`、`testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget`、`testY2CroppedScreenshotHiddenDisplayUsesFullViewportAspectFit`、`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`、`testIC100B2GeometryIsIndependentOfInterfaceVisibility`（该测试针对**浮层**几何，与截图主图几何无关，故 C v2 前后均通过）。

其中 `testS4…` 断言 `XCTAssertNotEqual(hidden.oneXDisplaySize, visible.oneXDisplaySize)`——**要求 `V` 依赖**，C v1 下必失败、C v2 恢复后重新成立，与修订语义自洽。

## 子项 A：占用空间改原始资源字节数（第 133 条）— 完成

### 分派表变更

| mediaKind | isEdited | 改前（IC-099） | 改后（IC-104 A） |
|---|---|---|---|
| photo | false | `contentEditingInputURL` | 不变 |
| livePhoto | false | `contentEditingInputURL` | 不变 |
| video | false | `videoAssetURL` | 不变 |
| photo | true | `fullSizePhotoResource`（`.fullSizePhoto` = **当前版本**） | `originalPrimaryResource`（**原始**主资源） |
| livePhoto | true | 同上 | `originalPrimaryResource` |
| **video** | **true** | **`videoAssetURL`（URL = 当前版本）** | **`originalPrimaryResource`** |

分派由「类型优先」改为「编辑态优先」；已编辑分支的资源选择**直接复用**探针既有规则 `AssetSizeProbeService.primaryResource(in:mediaKind:)`，未新写选择逻辑。

### 闸门 A1：未触发

触发条件是「某类型的『原始主资源』选择在探针代码中无既有规则可复用」。实测①：`primaryResource(in:mediaKind:)` 三个 `mediaKind` 全覆盖，且明确回答了卡内点名的 LivePhoto 歧义——`.livePhoto` 走照片分支，只在 `.photo` / `.fullSizePhoto` 中选，**`.pairedVideo` / `.fullSizePairedVideo` 不参与、不计入**。前提不成立，本卡未自行取定任何资源选择语义。

**由此产生的口径须 Lynn 核**：LivePhoto 的占用空间只含静态图部分。已列为 **H45 第 3b 项**（若与系统「信息」页不符，只记差值、不改码）。

### 不变项核对

| 项 | 结果 |
|---|---|
| 缺失/失败降级只显序号 | 未改（`byteCount` 失败仍返回 `nil`，`subtitleText` 一字未动） |
| 会话级缓存每资产至多取一次 | 未改（`S2AssetVolumeStore` 一字未动） |
| S2 单张 KB/MB/GB 向下截断口径 | 未改（`S2AssetVolumeFormatter` 一字未动） |
| 未用任何私有 KVC（G237） | ✓ 只用 `PHAssetResource.type` 公开属性 |
| 禁网络 | ✓ 沿用 `isNetworkAccessAllowed = false` |

### 未覆盖项（如实标注）

`primaryResource(in:mediaKind:)` 的资源选择规则**无单元测试覆盖**：入参与返回值均为 `PHAssetResource`，PhotoKit 不允许在单测中构造；为可测而抽取产品函数属「为测试改产品结构」，纪律 4 禁止。正确性留给 **H45 第 1/2/3/3b 项**真机判定。

## 子项 B：隐藏态竖向手势反转（第 132 条）— 完成

### 行为变更

`V=隐藏` 且 `1x`：
- **上滑完全无效果**——不标记、不改 `D`、不翻页、**不发提示**。守卫置于 `handleSwipeUp` 的 `.alreadyMarked` 语义提示**之前**。
- **下滑迁 `V=显示`**，缩放 / 页索引 / `D` / 徽标一律不变。守卫置于 `D` 判断**之前**，迁显示与当前资产是否已标记无关。

`V=显示` 与 `Nx` 分层零变化。

### 闸门 B1：未触发

竖向手势是**单一入口、经状态机统一分派**，无旁路①：`S2NativePhotoPager.swift:2938`（主图拖动结算）与 `:3171`（`handleOneXVerticalGestureIfNeeded`）均经 `machine.completeMainDrag(...)` → `handleSwipeUp()` / `handleSwipeDown()`。产品目录内两个 handler 只有 `completeMainDrag`（`S2StateMachine.swift:1414`、`:1417`）两处调用，其余全在测试目录。

### B3 卡内取定：过渡动画复用单击同款

**实现代价为零，未改视图层、未新增任何可调参数**（`S2Calibration.swift` 在子项 B 中零 diff）。依据同上：显隐过渡由 published `interfaceVisibility` 变化驱动，状态机在下滑时置 `.visible` 即自动走同一条 `startPresentationTransition`。

### 手势矩阵的 V 维度（下发单 v3 补授权）

`gestureRule(for:context:)` 原本无 V 维度，新增 `visibility:` 形参（默认 `.visible`，使既有 11 行矩阵断言零改动）。该函数**只有测试一个调用方**（`S2StateMachineTests.swift:1299`），产品代码不调用。`S2GestureEffect` 新增 `.revealInterface`（复用 `.toggleInterface` 会错误暗示对称切换；该枚举非 `CaseIterable`，无 `.count` 断言需同步）。

## 逐条闸门结果

| 闸门 | 判定 | 依据 |
|---|---|---|
| 恢复开工闸门（v3） | **通过** | 工作树净；tip = `65596b9`；IC-106 `844b40b` CI #179 success 519/0 |
| C v2 开工闸门（v4） | **通过** | 工作树净；tip = `44ca59f` |
| **A1** | **未触发** | 探针 `primaryResource` 三类型全覆盖，LivePhoto 歧义被明确回答 |
| **G237**（A） | **通过** | 新分派表断言齐备；缓存/降级/格式断言零语义变化；未用私有 KVC |
| **B1** | **未触发** | 两处产品调用点均经 `completeMainDrag` 统一分派 |
| **G238**（B） | **通过** | 1x 上滑/下滑按 `V` 拆分的迁移表与矩阵断言齐备；`V=显示` 与 `Nx` 零语义变化 |
| **C1 / C2**（v1） | **均未触发** | chrome 两缘均有 IC-100 v2 既有推导式；`fitInsetRatio` 无非截图消费方 |
| **Cv2-1** | **通过** | #184 success、519/0、真实退出码 0、IPA 已登记 |
| **Cv2-2** | **通过** | 产品 diff 仅 `S2Calibration.swift` / `S2View.swift` / xcstrings 一条；`schemaVersion == 6` 唯一；冻结三链未动 |
| **Cv2-3** | **未触发停线** | #183 三项失败均不含 `testIC100B2`，全部落在截图几何/沉浸/改写测试内；用剩余预算修一次后转绿 |
| **Cv3-1** | **通过** | #187 success、520 项 0 失败、真实退出码 0、IPA 已登记 |
| **Cv3-2** | **通过** | 产品 diff 仅 `S2Calibration.swift` / `S2NativePhotoPager.swift` / `S2View.swift` 三处，限于适配带推导与显示态摆放；chrome 布局与 30.7 登记值零 diff；`schemaVersion == 6` 未动；冻结三链未动 |
| **Cv3-3** | **未触发停线** | #185 / #186 的失败项全部落在两类契约内，`testIC100B2` 全程未失败 |
| `g ≤ 0` | **未触发** | 全部被支持输入下 `g > 0`，最小 20.8 @ 393×852 |
| 时间闸门（C v3，3h） | **未到期** | 13:50:56Z 开工，14:11:11Z 完成，到期 16:50:56Z |
| **G239**（C） | **达成** | `fitInsetRatio` 产品零残留、`schemaVersion == 6`、四条扫描已记入报告、几何断言 CI 绿 |
| **G240** | **通过** | 三子项**全部落在同一包内**（#184），IPA 已登记 |
| **G241** | **通过** | 每子项独立 commit；A（#180）、B（#181）、C（#184）各自 CI 绿有据；本地三项门禁全 0 |
| **G242** | **通过** | 本报告两件齐，含测试计数账本与卡内取定登记 |
| 时间闸门（C v2，3h） | **未到期** | 03:34:51Z 开工，04:01:17Z 完成，到期 06:34:51Z |

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 |
|---|---|---|---|
| A | 0 | **1** | 0 |
| B | 0 | **5** | 0 |
| C v1（`3fbe8cb`） | 0 | 6 | 0 |
| C v2 | 0 | **8**（+2 处夹具/辅助） | 0 |

C v2 改造的 8 个测试：`testIC104C…`、`testIC067G36…`（隐藏态回改沉浸）、`testF1…`、`testS1…`（改名 + 带高推导）、`testIC064G13ToG18…`、`testIC069G53…`（端点改派生）、`testIC065G31…`、`testIC064G20…`（浮点容差）。另新增私有夹具 `expectedScreenshotBandHeight()`，并给 `assertSpringOvershootAndConvergence` 的两个分支各加一处切片长度守卫。

| 提交 | 本机测试函数数 | CI Executed |
|---|---|---|
| 继承（`65596b9`） | 519 | — |
| `addae57`（A，merge） | 519 | **519 / 0 失败**（#180） |
| `1e77e6a`（B） | 519 | **519 / 0 失败**（#181） |
| `3fbe8cb`（C v1） | 519 | 519 / 37 失败（#182） |
| `b7acd84`（C v2 一轮） | 519 | 519 / 3 失败（#183） |
| **`2d3d789`（C v2 二轮）** | **519** | **519 / 0 失败**（#184） |

校验：519 + Σ新增 0 − Σ删除 0 = **519** ✓。**无静默删除**——全部改造都是同一测试函数内的重命名或断言改写，原有覆盖保留并有扩充（B、C 各新增了此前不存在的断言组）。

## CI 记录

| run | id | 被测提交 | 子项 | 结论 | 退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|---|
| #178 | `33131726380` | `209e2d5` | A（首轮） | failure | 65 | 519 / 1（范围外 `:7923`，IC-106 已修） | 无 |
| **#180** | `33134112220` | `addae57` | **A** | **success** | **0** | **519 / 0** | 836587 字节，`db4103af…3a03` |
| **#181** | `33135136401` | `1e77e6a` | **B** | **success** | **0** | **519 / 0** | 836633 字节，`778a9f8f…5f28` |
| #182 | `33137588575` | `3fbe8cb` | C v1 | failure | 非 0（数值未取到） | 519 / 37 | 无 |
| #183 | `33139876539` | `b7acd84` | C v2 | failure | **65** | 519 / 3 | 无 |
| **#184** | **`33140294919`** | **`2d3d789`** | **C v2** | **success** | **0** | **519 / 0**（44.805 / 71.379 秒） | **836375 字节，`495d93b79f1df4520ce35aa7c52edfb7ddb885da2e819288637d3f94d4bde2f1`** |

**CI 预算**：6 + C v2 追加 2 = 8 次，**已用 8 次**。

## 本地门禁（真实退出码）

每次提交前各跑满三项，全部 **0**：

| 门禁 | merge（A） | B | C v1 | C v2 一轮 | C v2 二轮 |
|---|---|---|---|---|---|
| `Scripts/selfcheck.ps1` | 0 | 0 | 0 | 0 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 0 | 0 | 0 | 0 |
| `git diff --check` | 0 | 0 | 0 | 0 | 0 |

## 陷阱 9 四条全量扫描（子项 C，推第一次 CI 前完成）

| 扫描 | 结果 |
|---|---|
| **1. 逐字段构造点**（排除 `factoryPlaceholder`） | **1 处**：`S2CalibrationHarnessTests.swift:835` |
| **2. 登记表使用点**（`parameterConnections`） | **10 处**：产品 2（`S2Calibration.swift:350`、`S2View.swift:1252`）+ 测试 8 |
| **3. 字段 / 登记 / 导出集合的字面 `.count` 断言** | **6 条需改**（44→43、44+4→43+4、connections 两文件、Set(names)、decided 两文件）+ 1 条相对式自动跟随 |
| **4. `specStatus` / `wiringStatus` 过滤计数** | **5 处**；`fitInsetRatio` 为 `decided`，故 decided 35→34、placeholder 9 不变 |

## 冻结三链与出厂值

| 项 | 值 | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 未触碰 |
| `schemaVersion`（最终绿 tip） | **6** | C 删除 `fitInsetRatio`，出厂值集合变更；按「所有链已用值 + 1」跳过被冻结 092 链占用的 5 |
| 合并进 `main` | **否** | 分支全程独立，`main` 停在 `e6bd5aa` |

## Lynn 下载什么

| 项 | 值 |
|---|---|
| **run 编号** | **#187**（`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/33178302985`） |
| 被测提交 | `0d461ccd6a7aa54a869d6494e9265785cb2a51b9` |
| artifact | `PhotoCleanupMVE-unsigned-0d461ccd6a7a`（id `9688814042`，zip 838095 字节） |
| **IPA 字节数** | **837925** |
| **IPA SHA-256** | **`747a8b6e15ff7443632d6afebb6863bec63b58ba850d8f7d3ed55eabe9c41991`** |
| 内含 | 子项 **A** + **B** + **C v3**，以及 IC-105 / IC-106 的测试侧修复；`schemaVersion == 6` |

**IPA 复核说明**：字节数与 SHA-256 取自 CI 内「未签名 IPA 校验」步骤注解（CI 侧实算，①）。本机未重下复核——Cv3-1 只要求登记，且 IPA 归档不可复现（IC-094/097 证据①），重下哈希不能作跨运行同一性判据。

## H45 人工判定：已通过项与本轮复测清单

### 已由 Lynn 判定**通过**的七项（④，下发单 v5 确认，本卡未改动其相关代码）

1. 已编辑照片：S2 占用空间 = 系统「信息」页原始大小 ✓
2. 已编辑视频：同上 ✓
3. 未编辑照片/视频各抽一张：数值与此前一致 ✓
3b. 已编辑 LivePhoto：只计静态图原始主资源（配对视频不计入）✓
4. 隐藏态：1x 上滑无反应；下滑回显示态且缩放/页码/标记不变；显示态与 Nx 照旧 ✓
6. 回归抽查：顶部信息区、底部布局、翻页、双击/捏合、标记→确认页流程 ✓
7. 顺带核查（无代码，第 76 条挂账）：徽标 88 跨会话残留是否复现 ✓

### 第 5 项返工后的复测清单（决策会话 v7 确认为六点，原样列出）

① 顶缘与旧版一致；
② 底距 = 顶距；
③ 第三段 30.7 不变；
④ 隐藏态仍填满；
⑤ 显隐切换过渡观感（缩放伴随竖移）；
⑥ **捏合起手 / 双击进入的瞬间跳变观感（尺寸跳变旧已有，新增约 17 pt 位移分量）**。

**六点全部可测**（CI #187 的包已含全部 C v3 实装）。第 ⑤ ⑥ 两点是本轮新增的观感判定，对应「行为变更登记」第 3、4 条；若 Lynn 不接受第 ⑥ 点，按 v7 裁定作为新产品输入另行修订 SPEC 决策 20。

## 卡内取定登记

| # | 子项 | 取定 | 说明 |
|---|---|---|---|
| 1 | A | `fullSizePhotoResource` → `originalPrimaryResource` | 纯改名随语义扩展；全仓 5 处引用已更新，`allCases.count` 仍为 3 |
| 2 | A | 已编辑分支复用 `AssetSizeProbeService.primaryResource(in:mediaKind:)` | 卡内明文，未新写逻辑 |
| 3 | B | **B3**：过渡动画复用现行单击显隐同款 | 实现代价为零，未改视图层、未新增可调参数 |
| 4 | B | `S2GestureEffect` 新增 `.revealInterface` | 复用 `.toggleInterface` 会错误暗示对称切换 |
| 5 | B | `gestureRule` 的 `visibility:` 取默认值 `.visible` | 使既有 11 行矩阵断言零改动 |
| 6 | C | 圆角规则维持既有（截图且 `V=显示`），与尺寸同一门控 | 卡只改尺寸口径，未提圆角，按「卡未写的不改」处理 |
| 7 | C v2 | 两处浮点噪声按 `accuracy: 0.000_001` 比较 | 仅对经渲染层往返的 `frame`；`fittedSize` 精确断言保留 |
| 8 | C v2 | `assertSpringOvershootAndConvergence` 加切片长度守卫 | 修正既有缺陷（单元素平凡单调），未放宽任何产品语义 |

## 发现但未处理的问题（只报告不修）

0. **两处新的用户可见行为，须真机判定**（不是缺陷，是两条已锁定决策的几何必然，均已由决策会话裁定并入复测清单）：显隐切换的竖向平移（≈ 17.35 pt，有曲线）与捏合/双击进入 `s > 1` 的瞬时位置跳变（≈ 17.35 pt，无过渡）。见「行为变更登记」第 3、4 条与复测清单第 ⑤ ⑥ 点。
0b. **与修订 1 字面不同的一处（已获 v7 追认）**：`fitBorderLayer` 是照片层的**子层**而非兄弟层，随父层自动平移，故未另加 position 分量（再加会双重平移）；收口由既有 `removeAllAnimations()` 覆盖，每层清净。
0c. **#185 停线报告中三处②推定已更正**：`IC067G40`（断言的是 `s > 1` 基准）、`IC070G75` / `R5`（`isScreenshot: false`）、`assertFitBorderConcentric` / `IC063G4` / `IC070R6`（`midY` 为帧自身扫描坐标）均不受影响，实测全部通过。见第四节。
1. **`S2CalibrationHarnessTests.swift:9909` 有一条过期注释**：IC-090 的历史叙述仍写「`schemaVersion == 4`（v2 保持不变）」，而同函数末尾的实际断言已是 `XCTAssertEqual(S2CalibrationConfiguration.schemaVersion, 6)`。**仅注释不一致，不影响断言**；该注释属 IC-090 测试，不在本卡范围内。
2. **`Scripts/verify-IC-20260815-05x.ps1` 系列引用已重命名的测试名**（如 `testV8FitInsetRatioGeometryAndScopeAreCorrect`、`testD2ZeroFitInsetMatchesPureAspectFit`、`testF1FactoryInsetShrinksShortEdgeToSeventyPercent`）。这些是各卡历史验证脚本，**不在 CI 门禁之列**（`ci.yml` 只跑 `selfcheck.ps1` 与硬编码扫描），且其中部分自 IC-067 起就已过期，非本卡引入。`Scripts/` 在本卡范围外，未动。
3. **`primaryResource` 无单元覆盖**（PhotoKit 类型不可构造），正确性只能由 H45 第 1/2/3/3b 项兜底。
4. **LivePhoto 占用空间只含静态图部分**——复用探针既有规则的直接后果，已列为 H45 第 3b 项。
5. **CI #182 的真实退出码数值未取到**：注解 10 条上限被失败行占满；job 日志端点在该轮网络下经 8 次以上重试全部失败，37 项失败无法逐条枚举。已如实标注，未以推断值代替。（#183 的退出码 65 取到了。）
6. **本机网络**：`git push` 需在带代理与直连之间轮换重试（本轮两种都出现过连续失败，最终一次是直连成功）；`gh api` 的 annotations 端点需 2～6 次重试；**job 日志端点本轮完全不可用**。
