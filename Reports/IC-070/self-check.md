# IC-070 自验报告（s2-centering-handoff-and-border-corner，v2）

## 结论（先行）

R5、R6、R7 已在分支 `feature/ic-070-centering-handoff` 交付。继承提交 `143cd32ca3c17715d4a1d2f493685b9c2890ec39`（`main`；分支实际从 `main` 当时的 tip `1643c4e` 切出，它只比 `143cd32` 多一个 IC-071 报告提交，产品代码完全相同）。最终被测代码提交 `9bffcd31399bcd47bbada60f59f655b9f2138246`，CI #119 success：XCTest 420 项、0 失败，"运行 XCTest"步骤及全部 9 个步骤 success（工作流 `set -o pipefail` + `exit "$test_status"`，真实退出码 0），IPA 697297 字节。

机器判定门禁 G75～G81 全部通过（夹具驱动项已标注）。**R5 的卡内归因被部分推翻**：空档确实源于居中机制切换，但"接管前靠 `contentInset` 居中"与实测相反——接管前 `contentInset = 0`、`contentSize = 视口`，居中靠 `zoomContentView` 几何；接管后切换为 inset 居中，其唯一合法偏移是 `-inset`，而一次不经布局的过期偏移写入会把照片推到视口顶部、直到下一次缩放步进才被钳回。修复据此改为"任何来源的偏移写入在写入瞬间钳回 `-inset`，且布局提交内 inset 与 offset 一并写入"。**R6 的卡内归因亦被修正**：静态初始态下描边与照片同心（模拟器像素实测）；源码层面的确定缺陷是显隐过渡给描边层挂的 `isRemovedOnCompletion = false` 动画组在过渡收口时只清照片层、不清描边层，描边层因此停留在过渡末帧的层内半径与线宽（28/0.7、1/0.7），与已复位为 28 的照片圆角不同心——与 H16"直边贴合、拐角向内收"一致。该视觉后果为③，由 H22 真机判定。

H21、H22、H23 为真机人工判定，保留给 Lynn；CI 次数：R7 1/3、R5 2/3、R6 1/3。

## 输入、继承与范围

- 任务卡 IC-20260821-070（v2），SPEC-S2 v14（SHA-256 `CEAE2A0F…F80AD45`），`Reports/IC-069/self-check.md`
- 继承提交：`143cd32`（main）；目标分支：`feature/ic-070-centering-handoff`（从 `main`=`1643c4e` 切出）
- 范围边界：仅改 `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` 与 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`。未改任何出厂值、`S2TemporaryPhotoImageStrategy.swift`、分页复用结构、页面生命周期、`s > 1` 平移边界语义、Nx 手势分层门控、截图元数据判定、明暗背景、双击倍率、`debugAssetLimit`、SPEC、Decision_log、S1、S3～S5；未新增 XCUITest；未合并 main。
- 执行顺序按 Lynn 指示：R7 先行 → 用补齐的 inset 字段实测 → 确认/推翻归因 → 再改 R5/R6。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `029e97736ebedc250db0dbcc2b6c2ff71c66df8f` | R7 | 逐帧样本、采集与导出补入 `contentInset`、`adjustedContentInset`；G49 样本构造同步；新增 G79 |
| `78dda0c6ff0b1d174760f71264113edec18441f1` | 实测探针 | `testIC070R5TakeoverCenteringProbe`、`testIC070R6BorderConcentricityProbe`（仅打印，为"先测再改"提供数据；保留在链上） |
| `3273bb1c7f201b288cc46ace7af9a3cb028c35c6` | R5 | `applyJointCentering()`：`layoutSubviews` 与接管几何写入内 inset+offset 一并写入；新增 G75/G76 |
| `c45ac2f77232f4275991cb1e6ac7e249d2d60837` | R6 | `removeFitBorderAnimations(source:)`：过渡收口与非过渡期 `applyCornerMask` 一并清除描边层残留动画；新增 G77/G78 与扫描夹具 |
| `9bffcd31399bcd47bbada60f59f655b9f2138246` | R5 补充 | `bounds` 的 `didSet` 在写入瞬间把内容小于视口方向的偏移钳回 `-inset`（CI #118 暴露：offset 写入不触发布局，仅靠 `layoutSubviews` 覆盖不到 UIKit 直接写偏移的路径）；G75 增加"写入后不做任何布局立即断言" |

R5 分两个提交是因为 CI #118 的实测推翻了"布局钩子足够"的假设；两者可独立 cherry-pick。

## R5：实际根因——确认与推翻说明

**卡内归因（③）**：接管前靠 `contentInset` 居中（offset 恒 0），接管后改用负 `contentOffset`，切换跨了一帧：接管帧 inset 已撤销、offset 尚未设置。

**实测（①，CI #116 夹具，300×600 视口，3:4 非截图照片 300×400）**：

| 步骤 | zoomScale | contentOffset | contentInset(top) | contentSize | 可见中心 dy |
|---|---|---|---|---|---|
| one_x（接管前） | 1.000000 | (0, 0) | **0** | 300×**600** | 0 |
| takeover_sync（接管后同步读取） | 1.000000 | (0, −100) | 100 | 300×400 | 0 |
| 写回 offset=0（模拟 UIKit 同帧过期写入） | 1.000000 | (0, 0) | 100 | 300×400 | **−100** |
| setZoomScale 1.005269 | 1.005269 | (0.667, −99.0) | 98.946 | 301.58×402.11 | 0.054 |

- **推翻**：接管前 `contentInset = 0`、`contentSize = 视口`，居中由 `zoomContentView.center` 几何完成（`enforceOneXContentGeometry`），不是 inset。
- **确认**：接管确实切换了居中机制（几何居中 → inset 居中），切换后该方向唯一合法偏移是 `-inset`；接管帧若被写入 offset=0，照片中心偏离视口中心整整一个 inset（−100pt），与真机 `t=1.556414` 接管帧 `offset=(0,0)`、`contentSize=(402,536)` 贴顶、下一帧 `−167.67` 归位的序列完全同构。
- **我的归因（真机时序为③）**：`scrollViewWillBeginZooming` 内的接管把 contentSize 改为基准尺寸并建立 inset 后，UIScrollView 自身的捏合处理在同一帧用接管前的状态写入 `contentOffset = 0`；该写入不触发 `layoutSubviews`，产品代码没有任何钩子在本帧纠正它，直到下一次 `setZoomScale` 才被 UIKit 钳回 `-inset`。CI #118 用"写 offset=0 后只跑一轮 runloop"复现了"布局钩子覆盖不到"这一点（4 处断言失败，offset 仍为 0）。
- **验证方式（真机）**：用本分支按第十节重录场景 C，接管帧应读到 `contentInset.top≈169` 且 `contentOffset.y≈−169`（修复前应为 `contentInset.top≈169`、`contentOffset.y=0`）。R7 字段使其可直读，无需反推。

**修复**：`S2NativeZoomScrollView.applyJointCentering()` 在 `layoutSubviews` 与 `prepareNativeZoomGeometry` 内把 inset 与 offset 一并写入；`bounds.didSet` 对内容小于视口的方向在写入瞬间钳回 `-contentInset`，内容大于视口的方向原样放行（`s > 1` 平移边界语义不变）。修复后同一探针：写回 offset=0 后偏移立即为 (−0, −100)、dy=0；各缩放步进 offset 与 `-inset` 精确相等（如 −98.946，而 UIKit 原生钳制值为 −99.0）。

## R6：实际根因——确认与修正说明

**卡内归因（③）**：独立描边层内缩量 d 与 `cornerRadius − d` 未联动；或描边层圆角未同步 220ms 插值。

**实测（①，CI #116/#119 模拟器像素，浅色、照片灰 237、测试专用不透明描边）**：初始态四角 45° 对角线首个非背景像素均为描边（灰 211/50/49/211），直边宽度 1.00pt、圆角 0.90～0.98pt，差 ≤0.1pt——**静态初始态并无不同心**；描边层 frame 与照片 bounds 相同、radius 相同、无内缩量（d=0）。

**源码确定事实（①静态）**：`addPresentationLayerAnimations` 给 `fitBorderLayer` 挂 `CAAnimationGroup(fillMode=.both, isRemovedOnCompletion=false)`；过渡收口 `applyPageImmediately` 只调用 `removeAllPhotoAnimations`（仅照片层），仓库中不存在任何 `fitBorderLayer.removeAllAnimations()`。因此隐藏→显示过渡完成后，描边层持续呈现末帧层内值 `cornerRadius = 28 / 0.7 = 40`、`borderWidth = 1 / 0.7 ≈ 1.43`，而照片层已由 `applyCornerMask` 复位为 identity + 28。描边比照片更圆、向内收，直边仍贴合——与 H16 描述一致。该因果的视觉判定为③（无头 CI 无 presentation 层，`presentationPairs=0`，像素扫描无法复现残留动画的呈现），由 H22 兜底。

**修复**：`removeFitBorderAnimations(source:)` 在 `applyPageImmediately` 与非过渡期的 `applyCornerMask` 中一并清除描边层动画并记入诊断事件（key `fitBorderLayer.*`）。过渡期间两层本就共用同一组 `layerCornerRadii` 关键帧（G78 实测 28 帧逐帧相等）。未改 `fitBorderWidth`、`fitBorderDarkAlpha`、`fitBorderLightAlpha`、`fitCornerRadius` 出厂值，未改圆角曲线类型（决策 105 D0～D6 未规定曲线）。

## 逐条验收门禁

| 门禁 | 结果 | 证据 / 测试函数 |
|---|---|---|
| G75 | 通过（夹具驱动，真机未覆盖） | `testIC070G75AndG76TakeoverKeepsJointCenteringEveryFrame`：3:4 与窄图两样本，接管帧、过期 offset 写入（立即 / 显式布局 / 一轮 runloop / `setContentOffset`）及 1.001～3 七级缩放的每一步与下一帧，可见中心偏移 ≤0.5pt 且 `offset = -inset` |
| G76 | 通过（夹具驱动） | 同上：接管帧与接管前一帧中心差 ≤0.5pt（实测 0） |
| G77 | 通过（模拟器像素） | `testIC070G77FitBorderIsConcentricAtCornersBeforeAndAfterToggle`：初始态与隐藏→显示后，四角首个非背景像素为描边；直边 1.00pt、圆角均值 0.944pt，差 0.056pt ≤0.5pt |
| G78 | 通过 | `testIC070G78FitBorderCornerRadiusTracksPhotoThroughTransition`：两层 28 个圆角关键帧逐帧相等；收口后两层 `animationKeys()` 为空，描边层 radius=28、width=1，照片 transform 为 identity |
| G79 | 通过 | `testIC070G79FrameSamplesExportContentInsetFields`：逐帧字段声明与每条 frame 记录均含两个 inset 字段，取值与滚动视图一致 |
| G80 | 通过 | CI #119 全部既有 XCTest 通过（含 IC-063 G1～G12、IC-064 G13～G25、IC-065 G26～G35、IC-067 G36～G46、IC-069 G53～G60） |
| G81 | 通过 | 420 项 ≥ 414，0 失败 |
| H21 / H22 / H23 | 保留给 Lynn 真机判定 | 不代为下结论 |

## CI 记录

| 运行 | 被测提交 | 结论 | 用途 |
|---|---|---|---|
| #116（id 32488743467） | `78dda0c6ff0b…` | success，417 项 0 失败 | R7 第 1 次；R5/R6 实测探针数据 |
| #118（id 32490316647） | `c45ac2f77232…` | failure，420 项 4 失败（均为 G75 `stale_offset_then_runloop`） | R5 第 1 次、R6 第 1 次（R6 门禁全过） |
| **#119（id 32491023882）** | **`9bffcd31399bcd47bbada60f59f655b9f2138246`** | **success，420 项 0 失败** | R5 第 2 次，最终交付 |

最终 CI #119：创建于 2026-08-21T14:14:00Z；`Executed 420 tests, with 0 failures (0 unexpected) in 36.407 (65.342) seconds`，`** TEST SUCCEEDED **`；全部 9 步 success，真实退出码 0；IPA `PhotoCleanupMVE-unsigned.ipa` 697297 字节，SHA-256 `7e62f7e622fa202943fed21dccde878b2f2d6f25e0418999a3646541eff1006b`；artifact `PhotoCleanupMVE-unsigned-9bffcd31399b` 已下载并本地 `sha256sum` 复核一致。

## 本地门禁（①，最终提交工作树）

- `Scripts/selfcheck.ps1`：退出码 0
- `Scripts/scan-hardcoded-user-visible-strings.ps1`：退出码 0（用户可见硬编码残留 0）
- `git diff --check`：退出码 0

## 报告提交方式

采用卡内允许的第二种：拿到 CI #119 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（该提交只含 `Reports/IC-070/`，被 `paths-ignore` 过滤，不触发 CI，属预期）。

## 发现但未处理（按纪律只报告）

1. `Reports/IC-068/export-format.md` 描述的逐帧字段清单未含两个 inset 字段，本卡未改该报告；导出文本头部"格式版本=1"未递增。
2. 无头 CI 的模拟器不提供 presentation 层（G78 `presentationPairs=0`），因此 R6 残留动画的视觉后果只能由真机 H22 判定。
