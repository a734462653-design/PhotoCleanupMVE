# IC-079 变更清单

分支 `feature/ic-079-fast-paging-window`，自 `feature/ic-078-dynamic-pinch-max-scale` 尖 `5691767`（`git rev-parse origin/...` 实测值；产品代码 = CI #127 被测 `503380c`）切出。R1 探针被测 `241cb6f70d640771477422839a6d037631d590c5`（CI #128，454 项 0 失败）；R2 产品代码提交 `40b51c4`（CI #129：455 项 1 失败——IC-077 G127 按旧窗口语义断言"翻页一次即取消"，见自验报告）；最终被测 `42be5411992eb456d228a7bc5f0823fbd5e74c6d`（CI #130，产品代码与 `40b51c4` 相同，仅测试适配）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `241cb6f` | R1 探针 | `S2NativePhotoPager.swift`、`S2View.swift`、`App/PhotoCleanupMVEApp.swift`、`Localizable.xcstrings`、`Reports/IC-068/export-format.md`（只追加）、`S2CalibrationHarnessTests.swift` | 场景 D `fastPaging`（面板标题键 `scenario_d`）；逐帧字段 +7（`pagingContentOffsetX`、`pagingIsDragging`、`pagingIsDecelerating`、`currentIndex`、`settledIndex`、`pageIndicesPresent`、`pageLoadStates`）；事件 +3（页创建/页移除、外层 `setContentOffset`（含 animated 与来源）、`handleNativePageChange`）；外层偏移写入收敛到 `writePagingContentOffset(_:animated:source:)`（`layoutNativePages` 的直接赋值保留并单独记事件）；`S2ImageLoadStateRegistry`（`S2View` `@StateObject`，经 `S2ImageContentContext.onLoadStateChange` → App 接到 `S2TemporaryPhotoImageView.onLoadStateChange`）；`settledIndex` 改 `private(set)`；G139 与探针测试 |
| `40b51c4` | R2 修复 | `S2NativePhotoPager.swift`、`S2View.swift`、`S2CalibrationHarnessTests.swift` | `S2NativePhotoPager.pageContentProvider`（`S2View.pageContent(index:viewportSize:)` 抽出供窗口与提供者共用）；`apply(... pageContentProvider:)`（默认 nil）；分页控制器 `scrollViewDidScroll` → `ensurePagesExistAroundPagingOffset()`：按偏移覆盖的页区间向两侧各扩一页按需创建（越界不创建，只创建与布局，不写外层偏移、不改当前页原生状态）；`apply` 的移除策略改为"不在列表且不在 `currentIndex ± retainedPageRadius(2)` 内"，列表外既有页用提供者最新内容同步；`synchronizeNativeStateToMachine(animatedPaging: false)` 在偏移已等于结算位（±0.5pt）时不再写入；创建/移除抽为 `makePageController(for:)` / `removePageController(at:)`；G141 |

| `42be541` | R2 测试适配 | `S2CalibrationHarnessTests.swift` | `testIC077G127…`：翻到索引 2 时 asset-1 仍在保留半径内（断言不取消），再翻到索引 3 后断言旧请求取消；视口变化断言改对当前页 asset-4 |

`pbxproj` 未改。

## 产品行为变化

- 快速连续翻页：滚动经过的页在进入视口前已由分页控制器按当前偏移创建（当前覆盖页区间 ±1），不再依赖 SwiftUI 刷新后的三页窗口；翻页刷新时保留 `currentIndex ± 2` 内的页，超出才移除。
- 滚停：`finishNativePaging` 仍调用 `handleNativePageChange` 并对齐各页原生状态，但外层偏移已在原生分页结算位时不再 `setContentOffset(animated: false)`；竖向手势接管等偏移确实偏离的情况仍对齐（既有行为）。
- 既有语义不变：翻页后新照片 `s = 1`、非当前页 `scale = 1`、`V` 不变、`c` 只在结算时更新；Nx 贴边翻页、捏合接管、居中、双击/显隐过渡路径未改。
- 诊断录制：新增场景 D 与上述字段/事件；关闭录制零副作用（只在 `isRecording` 为真时追加）。`S2View.mainPhoto` 的页窗口仍为当前页 ±1。

## 本地化键

+1：`s2.calibration.transition_diagnostics.scenario_d`（值 "D 快速连续翻页"，与既有 A/B/C 标题同格式，未加"【未定项 21 占位】"前缀——既有三项亦无前缀，本卡未要求）。目录条目 169 → 170，与产品引用一致。

## 参数层

无变化（字段 37、出厂值逐项不变、未新增参数）。`retainedPageRadius = 2` 为分页控制器内部常量（页窗口大小不是规格量，卡第二节），不入参数层。

## 测试

- 新增 3 个（均 `S2CalibrationHarnessTests`）：`testIC079G139FastPagingScenarioExportsWindowFieldsAndEvents`、`testIC079R1FastPagingWindowProbe`（仅打印）、`testIC079G141FastPagingKeepsPagesPresentWithoutOffsetWrites`。
- 修改 1 个：`testIC077G127RequestThrottlingAcrossPinchDoubleTapPagingAndViewport`（按保留半径 ±2 再翻一页后断言取消；取消语义不变）。删除 0 个。计数 452 + 3 = 455。

## 未变更

图片请求策略与 `S2TemporaryPhotoImageStrategy.swift` 的请求逻辑（只消费其既有 `onLoadStateChange`）；Nx 贴边翻页阈值与投影动画；横栏、顶部信息区、操作条、标记；捏合接管、居中（`prepareNativeZoomGeometry`、`applyJointCentering`、`bounds.didSet`）、描边、过渡动画、截图判定、`pinchMaxScale`；出厂值与参数；S1、S3～S5、`SessionStore`、交接契约；`Scripts/`、`ci.yml`、SPEC、Decision_log；分支与 worktree；未新增 XCUITest。

## 占位值登记（本卡新增或变更的占位值）

无新增参数或文案占位（`scenario_d` 为诊断面板标题，沿用 A/B/C 格式）。
