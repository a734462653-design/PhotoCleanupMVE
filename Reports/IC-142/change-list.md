# IC-142 变更清单

- 继承提交：`main` = `1abecae3ef5b54fa93b3103207a4f376d43dda1e`
- 分支：`feature/ic-142-revert-video-page-fit`，代码 tip `f69db075acd24250bce520375bca8311e3318ca8`
- **合并提交：`b19f155` / `b19f1553ec28842301a318a7bfbf905f81084d01`**
  - parent1 `1abecae3ef5b54fa93b3103207a4f376d43dda1e`（原 `main`）
  - parent2 `f69db075acd24250bce520375bca8311e3318ca8`（分支 tip）
  - `Merge made by the 'ort' strategy.`，**零冲突**；合并树对象
    `751db4523b5be05f220b00cc86934ae51faebcdc` 与分支 tip 树对象相同
- 推送报文：`1abecae..b19f155  main -> main`（两点记法，非强推），退出码 0

## 提交链（2 个，未 rebase／未 amend）

| 提交 | 内容 | 可单独 cherry-pick |
|---|---|---|
| `f69db07` | `revert: IC-142 撤销视频页显示态几何上移（决策 57 作废，④ H63a 第 2 项改判）` | 是 |
| `b19f155` | **本卡合并提交**（`--no-ff`） | — |

本卡只有一个子项、一个 commit，与卡内要求一致。

## 文件级变更（`1abecae..b19f155`，2 文件 +61 −244）

| 文件 | +/− |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | +5 −57 |
| `PhotoCleanupMVETests/IC139MediaBadgesTests.swift` | +56 −187 |

**白名单外的文件全部未动**：

| 文件 | 状态 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 不在 diff；两侧 SHA-256 同为 `344cfcd525ad58d7ff3e80c923c37621d08833b9122116695305cb95caeb54c4` |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 不在 diff；`schemaVersion` 仍 **7**（:118） |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 不在 diff（无新文件） |
| `PhotoCleanupMVE/Localizable.xcstrings` | 不在 diff（无文案变化，目录仍 **210** 键） |

## S2View.swift 的 6 个 hunk（逐条对上卡内处 1～6）

| hunk | 卡内处 | 内容 |
|---|---|---|
| `@@ -941,14 +940,0 @@` | 处 1 | 删 `mediaFit` 计算与两个局部量（含上方 5 行 IC-139 C 注释），共 14 行 |
| `@@ -961 +947 @@` | 处 2 | `S2ImageContentContext(fittedSize:)` 回退为 `pageMetrics.oneXDisplaySize` |
| `@@ -1027,2 +1013,2 @@` | 处 3 | `S2NativePageContent` 的 `fittedSize` / `fittedCenterY` 两行回退 |
| `@@ -2728,7 +2713,0 @@` | 处 4 | 删「视频页几何（决策 57）」MARK 与 `videoPageFitBottomInset`，共 7 行 |
| `@@ -2806,6 +2784,0 @@` | 处 5 | 删 `struct S2MediaPageFit`，共 6 行 |
| `@@ -2841,29 +2813,0 @@` | 处 6 | 删 `enum S2MediaPageGeometry`（仅 `videoPageFit` 一个成员），共 29 行 |

**无第 7 个 hunk**——即 A／B／D 三个子项的构造件与常量一行未改。

## 三处赋值回退（与基线 `db318fc` 逐字相同）

| 处 | 改前（IC-139） | 改后（= `db318fc`） |
|---|---|---|
| `S2ImageContentContext.fittedSize` | `fittedSize` | `pageMetrics.oneXDisplaySize` |
| `S2NativePageContent.fittedSize` | `fittedSize` | `pageMetrics.oneXDisplaySize` |
| `S2NativePageContent.fittedCenterY` | `fittedCenterY` | `pageMetrics.oneXDisplayCenterY` |

## 符号残留 grep 计数（产品源码 `PhotoCleanupMVE/` 全目录）

| 符号 | 计数 |
|---|---:|
| `mediaFit` | **0** |
| `S2MediaPageFit` | **0** |
| `S2MediaPageGeometry` | **0** |
| `videoPageFitBottomInset` | **0** |
| `videoPageFit(` | **0** |

正对照（`S2View.swift` 内，与 `db318fc` 相同）：

| 串 | 计数 |
|---|---:|
| `fittedSize: pageMetrics.oneXDisplaySize` | **2** |
| `fittedCenterY: pageMetrics.oneXDisplayCenterY` | **1** |

## A／B／D 保留确认（`S2View.swift` 内出现次数）

| 符号 | 次数 |
|---|---:|
| `S2LivePillPresentation` | 5 |
| `S2VideoBarPresentation` | 5 |
| `videoBarHeight` | 3 |
| `videoBarBottomToStripTop` | 2 |
| `S2MainPhotoLongPressAction` | 4 |
| `S2LivePhotoLongPressRecorder` | 2 |

`videoBarHeight` 与 `videoBarBottomToStripTop` 另有新断言守住取值
（44 与引用 `stripToBottomRowSpacing`）——防止日后清理时把浮框的常量
连同已撤的几何一起带走。

## 测试

### 删除（5 条，全部为 IC-139 C 类）

| 函数名 | 删除理由 |
|---|---|
| `testIC139C_VideoPageFitInsetIsDerivedNotIndependent` | 被断言对象 `videoPageFitBottomInset` 已删 |
| `testIC139C_VisibleVideoPageRenderFrameLiftsBottomEdgeBy68` | 上移行为已撤 |
| `testIC139C_WidthBoundVideoPageRecentersInsideShortenedRegion` | 同上 |
| `testIC139C_HiddenVideoPageGeometryMatchesPhotoPage` | 撤销后成为恒真式（卡内点名不留） |
| `testIC139C_PhotoAndLivePagesKeepBaselineGeometry` | 同上 |

CI #273 日志中 5 个函数名**零出现**，逐个核实。

### 随之删除的夹具与常量（无消费者）

| 成员 | 删前消费者 |
|---|---|
| `renderedOneXFrame(mediaKind:visibility:ratio:)` | 仅 C 类测试 |
| `baselineOneXFrame(visibility:ratio:)` | 仅 `testIC139C_PhotoAndLivePagesKeepBaselineGeometry` |
| `renderedFrame(fittedSize:fittedCenterY:nativeZoomBaseSize:)` | 仅上面两个夹具 |
| `baselineMetrics(visibility:ratio:)` | 仅上面两个夹具 |
| `private let viewport` | 仅上述夹具 |
| `private let heightBoundRatio` | 仅 C 类测试 |
| `private let widthBoundRatio` | 仅 C 类测试 |

删除前对每个名字做过引用计数，确认归零后才删；删后再次核验全部为 0。
`sourceText(_:)` 与 `mediaMetricsBlock(in:)` **保留**——A／B／D 与新断言仍在用。

### 新增（1 条）

`testIC142_VideoPageSharesPhotoPageGeometryInBothVisibilityStates`

### 项数对账

| 来源 | 数量 |
|---|---|
| 基线（`main`，CI #272） | 694 |
| 删除 | −5 |
| 新增 | +1 |
| **合计（CI #273）** | **690** |

`IC139MediaBadgesTests` 单套由 17 项降为 **13 项**（日志实证）。

## 占位值登记

**无变更。** `S2CalibrationConfiguration.schemaVersion` 保持 **7**。
本卡是**删除**登记制常量 `videoPageFitBottomInset`（推导量，从来不在标定配置里），
不涉及出厂值集合，故不递增版本号。

## CI

- **#273**（run id `34238005445`，attempt 1）——**绿，一次通过**
  - 被测提交 `f69db075acd24250bce520375bca8311e3318ca8`，事件 `push`
  - **Executed 690 tests, with 0 failures (0 unexpected) in 39.476 (103.754) seconds**
  - `** TEST SUCCEEDED **` 在位；`##[error]` 0 条、`##[warning]` 0 条
  - 真实退出码 **0**（job `102100631325` success，10 个 step 全 success）
  - 目的地 `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`
  - IPA `PhotoCleanupMVE-unsigned.ipa`，**1304616 字节**，
    SHA-256 `f143d9d98862a884620c4f6be549dd9d1d6c767e992281727f765d3d56632ca9`
  - 产物 `PhotoCleanupMVE-unsigned-f69db075acd2`，zip 1304786 字节
- **CI 预算 2 次用 1 次**（主跑即绿，1 次修未动用）
- **G805：合并后 `main` 自动运行 #274**（run id `34239807239`，attempt 1）——**绿**
  - 被测提交 `b19f1553ec28842301a318a7bfbf905f81084d01`，事件 `push`，分支 `main`
  - **Executed 690 tests, with 0 failures (0 unexpected) in 71.067 (144.308) seconds**
  - 真实退出码 **0**（job `102106761494` success，10 个 step 全 success）
  - IPA **1304616 字节**，
    SHA-256 `be3bc1839de837faa3d1139776857a902f236df0b001e430bbf0e2a6b342cd88`
  - 产物 `PhotoCleanupMVE-unsigned-b19f1553ec28`，zip 1304786 字节

## 分支与冻结链状态

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `b19f155` | 本卡推进（合并提交） |
| `feature/ic-142-revert-video-page-fit` | `f69db07` | 保留，未删除 |
| `feature/ic-139-media-badges` | `564a5f3` | 未动 |
| `feature/ic-138-housekeeping` | `113384a` | 未动 |
| `probe/ic-137-media-playback` | `486bcb7` | 未动 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（工作树） | 0 |
| `git diff --check 1abecae..b19f155` | 0 |
