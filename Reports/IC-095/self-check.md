# IC-095 自验报告（apply-reentry-root-fix / apply-idempotent-writes）

## 结论（先行）

`apply` 及其下游的几何写入已全部条件化。**静止态零几何写入、Nx 平移期间 `apply` 来源的外层写入归零，两项都在夹具里实测成立。**

**CI 结果：CI #167 success。** 被测提交 `47858f47805460e4155a721843bf5bb6a545bfba`，XCTest **497 项、0 失败**，9 步全 success，被测命令真实退出码 **0**（工作流 `set -o pipefail` + `exit "$test_status"`）；IPA **793993 字节**、SHA-256 `e2b39571c609893b8a122f2ce9ecfa4ca3a458e5bd9084c0e72fec6a4f990d04`，本地重下复核逐字节一致。**CI 只用了 1 次**（上限 3 次）。

计数算式：**492 + 5 − 0 = 497**。新增 5 项即 F1 / F1b / F2 / F3 / F4，IC-063～IC-093 既有门禁 492 项**一条未改、全过**。

本地三项门禁真实退出码全为 **0**。

**未定项未触碰，`schemaVersion` 仍为 4，`S2CalibrationConfiguration` 未加任何字段，出厂值一个未改。** 四道闸门（A 手势路径 / B 既有门禁 / C `@Published` 语义冲突 / D 新增参数）均未触发。

**H41 三段真机录制留给 Lynn，本报告不代为下结论。**

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空（无其他会话残留） |
| 继承提交（开工时 `git rev-parse main`） | `3cc1e227d17b80f2fd44fa8478cda698652d275d` |
| 目标分支 | `feature/ic-095-apply-idempotent-writes` |
| 分支 tip（本报告代码部分） | `47858f47805460e4155a721843bf5bb6a545bfba` |
| 触发 CI 的推送 | 一次，run #167 |
| 合并动作 | **无**。未合并 `main`，未 force push，未改写历史 |

范围边界：只动了 `S2NativePhotoPager.swift`（`apply` / `layoutNativePages` / `applyPage` → `controller.update` → `applyNativeState` 链，以及诊断埋点）、`S2StateMachine.reportNativeViewport`（等值不发布）、`S2CalibrationHarnessTests.swift`（新增 5 项断言）、`Reports/IC-068/export-format.md`（只追加一节）。SPEC、`Decision_log.md`、`Scripts/`、`ci.yml`、089/091/092 冻结分支一字未动。

## 三处写入条件化的判定条件（原文）

### 一、外层静止偏移写回（`apply` 与 `layoutNativePages` 共用的唯一判定入口）

`S2NativePagerViewController.pendingSettledPagingOffset()`，三条件同时成立才返回目标偏移，任一不成立即返回 `nil`、一个字节都不写：

```swift
guard !pagingScrollView.isTracking,
      !pagingScrollView.isDragging,
      !pagingScrollView.isDecelerating,
      !pageControllers.values.contains(
          where: \.isInteractionOrTransitionActive
      ) else {
    return nil
}
let settledOffset = pagingScrollView.contentOffsetForPage(at: settledIndex)
guard abs(pagingScrollView.contentOffset.x - settledOffset.x) > 0.000_001 ||
    abs(pagingScrollView.contentOffset.y - settledOffset.y) > 0.000_001 else {
    return nil
}
return settledOffset
```

其中「任何页的交互或过渡在途」定义为（`S2NativeZoomPageController.isInteractionOrTransitionActive`）：

```swift
pinchIsActive ||
    isDoubleTapTransitionActive ||
    isPresentationTransitionActive ||
    zoomScrollView.isTracking ||
    zoomScrollView.isDragging ||
    zoomScrollView.isDecelerating ||
    zoomScrollView.isZooming
```

改前：`apply` 里的写回**只看外层自身三个标志**且**不比较偏移**，条件成立就无条件写一次；`layoutNativePages` 里的写回看同样三个标志、比较用精确 `!=`。改后二者共用上述判定，ε 沿用项目既有的 `0.000_001`。**收紧的部分就是「内层手势 / 缩放 / 减速 / 双击过渡 / 呈现过渡在途时不写」这一条**——`Q2.txt` 里外层被带动 +7 pt 后被逐帧钉回，钉回的正是这条原先缺失的守卫。

### 二、`layoutNativePages` 的重排

`S2NativePagerViewController.layoutNativePages()`：

```swift
let inputs = currentLayoutInputs()
if inputs != lastLayoutInputs || pendingPresentationTapPageIndex != nil {
    layoutNativePagesUnconditionally()
    lastLayoutInputs = inputs
}
```

`currentLayoutInputs()` 比较的量（全部相等才跳过）：

- `viewportSize`
- `machine.orderedAssetIDs.count`（页数）
- `configuration.pageSpacing`
- `machine.currentIndex`、`machine.scale`、`machine.viewportOffset`
- 逐页 `(index, assetID, fittedSize, nativeZoomBaseSize)`，按 index 升序

即卡内「页集合、视口尺寸或页几何输入」加上驱动 `applyNativeState` 的状态机视口状态。**例外一条**：`pendingPresentationTapPageIndex != nil` 时强制执行，因为该页的 `presentationTapLayoutReading.callbackCount` / `photoFrameWriteCount` / `suppressedPhotoFrameWriteCount` 必须逐次落实（IC-067 / IC-076 门禁读这三个计数）。

外层偏移的偏离判定**不在跳过之列**——外层可能被 UIKit 带偏而重排输入未变，跳过它会让 F3 的归位失效。`isApplyingSnapshot` 的括起范围与改前逐字相同（仍覆盖偏移写入，`scrollViewDidScroll` 的重入抑制语义不变）。

### 三、`applyPage` → `controller.update` → `applyNativeState`

**(a) `S2NativeZoomPageController.update` 的 1x 尾段**，全部相等才跳过 `applyPageImmediately`：

```swift
let pageInputsAreUnchanged = hasAppliedPageImmediately &&
    sameAsset &&
    pendingPresentationPage == nil &&
    !isPresentationTransitionActive &&
    interfaceVisibility == page.interfaceVisibility &&
    isFramedPhoto == page.isFramedPhoto &&
    fittedSize == page.fittedSize &&
    nativeZoomBaseSize == page.nativeZoomBaseSize &&
    cornerRadius == page.cornerRadius &&
    assetPixelSize == page.assetPixelSize &&
    contentVersion == page.contentVersion &&
    previousViewportSize == latestViewportSize &&
    previousMaximumZoomScale == latestMaximumZoomScale
```

`hasAppliedPageImmediately` 是必需的：`viewDidLoad` 里的 `configure` 用的是零视口与倍率 1，未经过一次真正装配就判定「输入未变」会让新建页永远拿不到内容。`previousViewportSize` / `previousMaximumZoomScale` 也是必需的：`applyPageImmediately` 的 `configure(...)` 正是用这两个量，IC-078 的「像素尺寸后到 → `pinchMaxScale` 变大」链路只改这两者之一（`assetPixelSize` 在该链路里不变）。跳过的是 `applyPageImmediately` 一整段——代次自增、动画清除、`rootView` 重挂、`configure`、`layoutIfNeeded`。**`applyNativeState` 与 `applyCornerMask` 照常下发**，两者自身都是逐项 `!=` 守卫的幂等写入。

**(b) `S2NativeZoomScrollView.applyNativeState` 的强制布局**：

```swift
var wroteGeometry = false
if nextScale > minimumZoomScale + 0.000_001 {
    let wasAtMinimumZoomScale = abs(zoomScale - minimumZoomScale) <= 0.000_001
    if prepareNativeZoomGeometry(), wasAtMinimumZoomScale { wroteGeometry = true }
    if abs(zoomScale - nextScale) > 0.000_001 {
        setZoomScale(nextScale, animated: false); wroteGeometry = true
    }
} else {
    if abs(zoomScale - minimumZoomScale) > 0.000_001 {
        setZoomScale(minimumZoomScale, animated: false); wroteGeometry = true
    }
    if enforceOneXContentGeometry() { wroteGeometry = true }
}
if wroteGeometry { setNeedsLayout() }
layoutIfNeeded()
```

改前是无条件 `setNeedsLayout(); layoutIfNeeded()`——**这就是 `6.txt` 里 746 次 `layoutSubviews` 的直接来源**：非当前页每帧都被下发一次 `applyNativeState(scale: 1, viewportOffset: .zero)`，即便目标与现值完全一致也强制一次布局。改后无写入时保留 `layoutIfNeeded()`（只冲刷别处已标脏的待布局，视图干净时不触发 `layoutSubviews`），**不再自己标脏**。`enforceOneXContentGeometry` 改为返回是否确有落笔，逐项 `!=` 守卫与「吸附归位写入」事件一字未动（四个布尔全假的空转记录仍照常产生）。

**(c) `S2StateMachine.reportNativeViewport` 等值不发布**（卡内「必要时」项，本卡采纳）：

```swift
let nextScale = min(pinchMaxScale(for: currentAssetID), max(1, scale))
let nextViewportOffset = nextScale == 1 ? .zero : viewportOffset
if self.scale != nextScale { self.scale = nextScale }
if self.viewportOffset != nextViewportOffset { self.viewportOffset = nextViewportOffset }
```

钳制表达式与改前逐字相同。**`@Published` 属性集合未变、发布出去的值序列与时序未变**，非几何订阅者（徽标、横栏、工作表）读到的状态完全一致；断掉的只是「内层回报同一视口 → SwiftUI 重进 → `apply` → 几何写入 → 布局回调 → 再次回报」的自激环。`scale` / `viewportOffset` 上没有任何属性观察器，仓库内也没有任何测试读取 `S2StateMachine` 的 `objectWillChange`（已 grep 确认），故此改动不改变任何可观察行为。**闸门 C 未触发。**

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G207** F1～F5 通过；`export-format.md` 只增不删 | 满足① | 五项测试函数名与 CI 通过行见下表；`git diff main..HEAD -- Reports/IC-068/export-format.md` 为 **30 增 0 删** |
| **G208** CI success、真实退出码 0、XCTest 0 失败、计数算式、IPA 重下一致、本地三项门禁退出码 0 | 满足① | 见「CI 与本地门禁」 |

### F1～F5 逐项

| 项 | 测试函数 | CI 结果 | 断言要点 |
|---|---|---|---|
| **F1** 静止态连调 `apply` 10 次 | `testIC095G207F1IdleApplyWritesNoGeometry` | passed (0.110 s) | 录制窗口内 `geometryWriteCount` **= 0**、`pagingContentOffsetWriteCount` **= 0**、`photoGeometryWriteCount` **= 0**；逐页 `(view.frame, zoomScale, contentOffset, contentSize, contentInset, photoFrame)` 快照与外层 `contentOffset` **逐字节不变**；导出记录里**不出现**任何一条 `外层setContentOffset` / `页frame写入` / `内层setContentOffset` / `照片几何写入` / `setZoomScale`，`吸附归位写入` 的 details 里**不含 `=true`** |
| **F1b** `wroteAnyGeometry` 端到端 | `testIC095G207F1HostedUpdateUIViewReportsNoGeometryWrite` | passed (0.809 s) | 宿主 `S2View` 下由非几何状态发布（已标记资产再上滑 → 只发语义提示）触发的 SwiftUI 重进，导出里 `updateUIView` 事件**至少一条**，且**每一条**的 details 都含 `写入照片几何=false；写入任意几何=false`；窗口内 `geometryWriteCount = 0` |
| **F2** Nx 平移 20 帧后连调 `apply` | `testIC095G207F2NxViewportPanKeepsPagingOffsetWritesAtZero` | passed (0.117 s) | 逐帧 `reportNativeViewport(scale: 2, viewportOffset: (step, 0))` + `apply`，共 20 轮：`pagingContentOffsetWriteCount` **= 0**，外层 `contentOffset` 始终等于 `contentOffsetForPage(at: settledIndex)`；导出里**一条 `外层setContentOffset` 都没有**（出现即 `XCTFail`） |
| **F3** 外层被带偏 5 pt | `testIC095G207F3DeviatedPagingOffsetIsRealignedExactlyOnce` | passed (0.223 s) | 无手势 / 无动画：下一次 `apply` 后 `pagingContentOffsetWriteCount` **恰为 1**、偏移回到静止值；再连调 5 次仍为 **1**。双击过渡在途（`isDoubleTapTransitionActive == true`）：`apply` 后写入 **0**、偏移**保持偏离**（既有守卫收紧后的语义） |
| **F4** 页集合与视口尺寸变化 | `testIC095G207F4PageSetAndViewportChangesStillRelayout` | passed (0.211 s) | 视口 300×600 → 340×620：`pageStride` 跟随、逐页 `view.frame == frameForPage(at:)`、外层 `contentSize == 页数 × stride`、偏移落在静止值；`handleNativePageChange(to: 2)` 后 `settledIndex == 2`、页 2 存在、frame 正确、外层偏移 `== contentOffsetForPage(at: 2)` |
| **F5** IC-070 G75/G76、IC-069 G53～G58、IC-079、IC-085、IC-090、IC-093 既有门禁 | 既有 492 项 | 全过 | XCTest 497 项 0 失败，其中既有 492 项**一条未改、未删、未弱化**（`git diff --numstat main..HEAD` 对测试文件为 **392 增 2 删**，2 删就是 `recordUpdateUIView` 的两处调用因新增参数改为多行写法，断言体一行未动） |

### CI 与本地门禁

| 项 | 值 |
|---|---|
| 工作流 | `iOS 构建与自验`，run **#167**（`databaseId` 32922343177） |
| 被测提交 | `47858f47805460e4155a721843bf5bb6a545bfba`（完整 SHA） |
| 结论 | **success**，9 步全 success |
| XCTest | **Executed 497 tests, with 0 failures (0 unexpected)** in 31.799 (64.568) seconds |
| 计数算式 | 492（继承）+ 5（本卡新增）− 0（删除）= **497** ✅ |
| 被测命令真实退出码 | **0**。工作流第 52 行 `set -o pipefail`、第 82 行 `exit "$test_status"`，日志管道不吞退出码 |
| IPA 字节数 | **793993** |
| IPA SHA-256 | `e2b39571c609893b8a122f2ce9ecfa4ca3a458e5bd9084c0e72fec6a4f990d04` |
| 本地重下复核 | `gh run download` 取 `PhotoCleanupMVE-unsigned-47858f478054`，本地 `sha256sum` = `e2b39571…0d04`、`stat` = **793993** 字节，**与 CI 报告值逐字符一致** ✅ |
| `Scripts/selfcheck.ps1` | 退出码 **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 退出码 **0**（目录条目 171 / 产品源码引用 171、用户可见硬编码残留 **0**） |
| `git diff --check` | 退出码 **0** |
| CI 使用次数 | **1 / 3** |

### 闸门核对

| 闸门 | 触发 | 说明 |
|---|---|---|
| **A** 手势路径、捏合 / 双击、`bounds.didSet`、页窗口语义、图片请求 | 否 | 五处一字未动。`bounds.didSet`、`scrollViewDidZoom` 里的无条件 `setNeedsLayout/layoutIfNeeded`、`retainedPageRadius`、`S2TemporaryPhotoImageStrategy` 均未触碰 |
| **B** 任一既有门禁失败 | 否 | 492 项既有断言全过 |
| **C** 静止态零写入与 `@Published` 非几何语义冲突 | 否 | 达成零写入靠的是写入侧条件化，不需要改 `@Published` 属性集合；`reportNativeViewport` 的等值不发布不改变发布值序列（论证见上文三(c)） |
| **D** 新增参数、改出厂值或 `schemaVersion` | 否 | `S2CalibrationConfiguration` 未加字段、出厂值一个未改、`schemaVersion` 仍为 **4**（`S2Calibration.swift:118`） |

## 根因假设的确认与推翻

卡内 §一 的三条证据里，**源码链路部分本卡确认无误**，逐条对应到具体代码：

| 卡内表述 | 本卡实测 | 等级 |
|---|---|---|
| 内层 `scrollViewDidScroll` → `reportNativeViewport` → `@Published` **每帧赋值** | 确认。`S2NativeZoomPageController.scrollViewDidScroll` 与 `scrollViewDidZoom` 都无条件调 `owner?.reportNativeViewport(from:)`，改前 `reportNativeViewport` 无条件赋值两个 `@Published` | ① |
| `apply` 的外层静止偏移写回**守卫只看外层自身手势态** | 确认。改前 `apply` 的守卫是 `!isTracking && !isDragging && !isDecelerating`，**既不看内层任何标志，也不比较偏移是否已相等** | ① |
| `layoutNativePages()` 逐页重排 | 确认，且**根因比卡内写得更靠前一层**：`layoutNativePages` 的页 frame 写与外层偏移写本来就有 `!=` 守卫，真正每帧落笔的是它调用的 `applyNativeState` 里那对**无条件** `setNeedsLayout(); layoutIfNeeded()`——非当前页每帧被下发 `scale: 1, viewportOffset: .zero`（与现值恒等），仍强制一次布局。这解释了为什么 `6.txt` 里 `layoutSubviews` 746 次远多于 `updateUIView` 149 次（149 × 约 5 个受影响的内层视图） | ①（源码）＋③（次数对应关系为推测，待 H41 用实测导出核对） |

**没有被推翻的假设，但有一条补充与一条修正：**

- **补充（本卡新发现）**：`applyJointCentering()` 是布局回调里唯一的几何写入点，**改前完全没有埋点**。这意味着 `6.txt` 里「静止段 0.46 s 内 2 次写入」如果发生在这条路径上，导出文本里根本看不到写入事件、只能看到 `layoutSubviews`。本卡补了 `联合居中写入` 事件并计入 `wroteAnyGeometry`，H41 的导出才是完整的。
- **修正**：卡内 §二.3 写「既有守卫语义保留并收紧：`isTracking` 纳入跳过条件」。**外层自身的 `isTracking` 改前就已经在守卫里**；真正缺失、本卡补上的是**内层**的 `isTracking` / `isDragging` / `isDecelerating` / `isZooming` / `pinchIsActive` 与两类过渡动画标志。按结果理解（「无任何手势 / 动画在途」）实现，未按字面只加外层 `isTracking`。

**未在本卡验证的部分**：`6.txt` 的 181 / 746 / 149 与 `Q2.txt` 的 +7 pt 都是任务卡提供的真机材料，本卡**没有也无法在本机复现或复核**这些数字；F1～F4 只在夹具里证明了机制。改后这些数字变成多少，由 H41 实测给出。

## 人工判定项

**H41 三段录制定量取证，保留给 Lynn 真机判定，本报告不代为下结论。** 装本卡 CI #167 的包（IPA 793993 字节、SHA-256 `e2b39571…0d04`）。

| 场景 | 卡内判据 | 本卡可提供的对照 |
|---|---|---|
| (1) 场景 E：Nx 平移 3～4 秒（不到边） | `apply` / `layoutNativePages` 来源的外层写入 **0 次**（对照 `6.txt` 的 181 次）；`wroteAnyGeometry=false` 占比接近 100% | F2 在夹具里给出 0 次；真机的 UIKit 嵌套滚动交接行为夹具不覆盖 |
| (2) 场景 C：捏合放大松手等 1 秒 | 同上为 0；IC-093 抖动修复无回归 | 夹具未覆盖捏合松手的真实时序 |
| (3) 静止 5 秒（开录后不碰屏幕） | 几何写入 **0 次**（对照 `6.txt` 静止段 2 次） | F1 在夹具里给出 0 次 |
| 观感抽查 | 1x 翻页、双击、捏合、横栏、上滑 / 下滑、标记、圆角均无回归（兼作 IC-094 的无回归抽查） | 全部为人工判定，无夹具结论 |

**导出判读提示**：本卡后，`updateUIView` 的 details 变为 `写入照片几何=…；写入任意几何=…`；静止态应看到 `外层setContentOffset` / `页frame写入` / `内层setContentOffset` / `联合居中写入` / `照片几何写入` **一条都没有**，`吸附归位写入` 的四个布尔**全为 `false`**。事件族一类没删——**没有写入就没有记录，不是埋点缺失**。

## 真机未覆盖项清单

1. **F1～F4 全部是夹具驱动**。夹具直接调 `controller.apply(...)`，绕过了真实事件序列（手势回调时序、runloop 分帧、`CATransaction` 提交边界、chrome 插入引起的外层布局重算）——CLAUDE.md 陷阱 1 明列的失效场景。真机结论只能由 H41 给出。
2. **F1b 虽然走宿主 `S2View` + `UIHostingController` + `UIWindow`，但仍是模拟器 300×600 尺寸、无真实触摸**。它证明的是「非几何状态发布引起的重进不写几何」，不证明手势期间的行为。
3. **UIKit 嵌套滚动的交接行为（内层到边界后带动外层）无夹具覆盖**。`Q2.txt` 里外层被带动 +7 pt 就发生在这条路径上；本卡改的是「带动之后不再被钉回」，带动本身是 UIKit 行为，只有真机能看。
4. **`isDecelerating` / `isZooming` / `isTracking` 在真机上的置位时序**与夹具不同。F3 只能用 `isDoubleTapTransitionActive` 代表「动画在途」，手势标志的那一半没有夹具覆盖。
5. **性能与观感变化未测**。写入次数下降是否带来可感知的流畅度变化、是否引入任何视觉延迟（例如某次本该归位的偏移晚了一帧），只有真机能判。
6. **场景 C 的捏合松手抖动（IC-093 修复）是否回归**，无夹具覆盖。

## 发现但未处理的问题（按纪律只报告不修）

1. **`apply` 里的外层写回点在当前调用序下实际不会命中**。`apply` 先调 `layoutNativePages()`，后者已按同一判定写过，回到 `apply` 时偏移已归位、判定返回 `nil`。保留该写入点是因为 `layoutNativePages` 的重排会改 `pagingScrollView.contentSize`，UIKit 可能就此反钳偏移，此时 `apply` 的二次判定是唯一兜底。**副作用**：导出里来源 `S2NativePagerViewController.apply` 的 `外层setContentOffset` 事件预计不再出现，改由来源 `…layoutNativePages` 承担。两者在 H41 的判据里同属「`apply`/`layoutNativePages` 来源」，不影响判读，但 `export-format.md` 里 IC-079 那节列的来源清单从此有一项成为理论分支。**本卡未改那节文字**（只追加原则）。
2. **`applyCornerMask()` 每次调用都重建并赋值 `fitBorderLayer.borderColor`**（`resolvedFitBorderColor()` 每次新建 `CGColor`），没有等值守卫；`photoLayer.cornerCurve` / `fitBorderLayer.cornerCurve` 也是无条件赋值。都不是几何写入，本卡未动。
3. **`applyPageImmediately` 内部仍是「要么整段跑、要么整段跳」**。真正需要重建时（例如只有 `contentVersion` 变了），代次自增、两处动画清除、`configure`、`layoutIfNeeded` 仍全部执行。细化到分支级条件化超出本卡「三处写入条件化」的范围。
4. **`scrollViewDidZoom` 里的 `zoomScrollView.setNeedsLayout(); layoutIfNeeded()` 仍是无条件的**（`S2NativePhotoPager.swift` 手势回调段）。属闸门 A 的手势路径，本卡按纪律未动。
5. **`S2NativePagingScrollView.configure` 的 `pageSpacing` / `pageWidth` / `viewportHeight` / `itemCount` 是无条件赋值**（`frame` 与 `contentSize` 有 `!=` 守卫）。纯属性写入，不触发布局，本卡未动。
6. **`bounds.didSet` 里的联合居中纠偏没有埋点**（本卡只给 `applyJointCentering()` 加了）。`bounds.didSet` 走的是 `bounds = CGRect(...)` 直接赋值，不经过 `applyJointCentering`，因此 `wroteAnyGeometry` 仍看不到这一类写入。它属闸门 A 的 `bounds.didSet`，本卡未动——**H41 判读时需要知道这条盲区**。

## 完成后动作

**完成即停。** 不合并主干，等次日 Lynn 的 H41 真机判定。
