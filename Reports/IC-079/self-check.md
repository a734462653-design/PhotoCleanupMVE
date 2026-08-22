# IC-079 自验报告（fast-paging-window）

## 结论（先行）

R1 探针与 R2 修复完成，CI 三次（探针 1 次 + 修复 2 次，均在上限内）。分支 `feature/ic-079-fast-paging-window` 自 `feature/ic-078-dynamic-pinch-max-scale` 尖 `5691767763348db275b63d7b32bdd9351bc157ee`（`git rev-parse origin/...` 实测；IC-078 已交付，CI #127 success）切出。最终被测 `42be5411992eb456d228a7bc5f0823fbd5e74c6d`，CI #130 success：XCTest **455 项、0 失败**（= 452 + 3 新增 − 0 删除），9 步 success（`test_status=0`），IPA 753701 字节。

**归因确认（①夹具数据，CI #128 探针）**：生产页窗口（当前页 ±1）下，第一次滚停后、SwiftUI 刷新前开始第二次滚动到 i+2 时，`pageIndicesPresent=[0,1,2]`、目标页 3 **不存在**，直到重新 `apply` 才创建（探针第 3～5 步）。这正是卡第一节第 4 条的③推测，现已由数据确认为"页不存在"而非"页存在但图像未请求"——闸门 C 未触发。数据同时显示滚停时 `synchronizeNativeStateToMachine` 与刷新后 `apply` 各写一次非动画偏移（值与结算位相同）。

**修复**：分页控制器持有页内容提供者，在外层 `scrollViewDidScroll` 按偏移覆盖的页区间向两侧各扩一页按需创建缺失页；翻页刷新时只移除 `currentIndex ± 2` 之外的页；滚停时偏移已等于结算位则不再写入。CI #130 下探针复跑（探针夹具未传 `pageContentProvider`，故仍复现"刷新前目标页不存在"的原状；带提供者的证据是 G141）：第 5 步 `pageIndicesPresent=[1,2,3,4]`（页 0 在 ±2 之外被移除、页 4 随列表创建），第 6～7 步越界滑动无越界页创建（`[3,4,5]`）。

**闸门 B 形式上触发、按授权处理（需技术负责人确认）**：CI #129 唯一失败为 IC-077 `testIC077G127…` 的"离开窗口的页应取消旧请求"——翻页 1→2 后页 0 现落在保留半径 ±2 内不再被移除，请求自然未取消。这是本卡第二节显式解除"页窗口与页创建时机"限制的直接后果；G127 的语义（离开窗口即取消）在新窗口下不变，因此把该测试改为再翻一页到索引 3 后断言取消（并新增"仍在保留半径内的页不取消"断言），产品代码未动（`42be541` 仅测试）。若技术负责人认为应按闸门 B 字面停下，本处理可撤回。

探针测试 `testIC079R1FastPagingWindowProbe` 按卡保留在仓库（仅打印）。H29 与场景 D 真机录制留给 Lynn；H24～H28 顺延。

## 输入、继承与范围

- 任务卡 IC-20260822-079；SPEC-S2 v15 第二节、第四节"左右滑主图"、第六节；`Reports/IC-068/export-format.md`、`Reports/IC-070/self-check.md`；IC-078 报告。
- 开工前 `git status --porcelain` 为空。
- 范围边界：改动 `S2NativePhotoPager.swift`、`S2View.swift`、`App/PhotoCleanupMVEApp.swift`（仅把既有 `onLoadStateChange` 回调接入）、`Localizable.xcstrings`（+1 键）、`Reports/IC-068/export-format.md`（只追加）与 `S2CalibrationHarnessTests.swift`。未改图片请求策略与 `S2TemporaryPhotoImageStrategy.swift` 的请求逻辑（只消费其既有加载态回调）；未改 Nx 贴边翻页阈值与投影动画、横栏/顶部信息区/操作条/标记、捏合接管/居中（`prepareNativeZoomGeometry`、`applyJointCentering`、`bounds.didSet` 未动）/描边/过渡动画/截图判定/`pinchMaxScale`、任何出厂值；未新增参数、XCUITest；未改 SPEC、Decision_log、S1、S3～S5、`Scripts/`、`ci.yml`；未合并主干。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `241cb6f` | R1 探针 | 场景 D `fastPaging`；逐帧字段 +7、事件 +3；外层偏移写入收敛到 `writePagingContentOffset(_:animated:source:)`；`S2ImageLoadStateRegistry` 加载态登记（`S2ImageContentContext.onLoadStateChange` → App → `S2TemporaryPhotoImageView.onLoadStateChange`）；`settledIndex` 可读；`export-format.md` 追加小节；G139、探针测试 |
| `40b51c4` | R2 修复 | `pageContentProvider`（`S2View.pageContent(index:viewportSize:)` 抽出）；`ensurePagesExistAroundPagingOffset()` 于外层 `scrollViewDidScroll`；`apply` 移除策略改为保留半径 ±2 并同步列表外既有页；`synchronizeNativeStateToMachine(animatedPaging:false)` 偏移已在结算位（±0.5pt）不写；创建/移除抽为 `makePageController(for:)` / `removePageController(at:)`；G141 |
| `42be541` | R2 测试适配 | `testIC077G127…` 按保留半径再翻一页后断言取消（产品未动） |

R2 未分多步（两处改动同属一次设计，同文件）。

## 探针数据（G140，①夹具，CI #128 日志原文节选）

```
[IC-079 探针] 0 初始（窗口 i±1）：currentIndex=1 settledIndex=1 contentOffsetX=320.0 偏移所在页=1 pageIndicesPresent=[0, 1, 2] 目标页存在=true
[IC-079 探针] 1 第一次滚动到 i+1（滚停前）：currentIndex=1 settledIndex=1 contentOffsetX=640.0 偏移所在页=2 pageIndicesPresent=[0, 1, 2] 目标页存在=true
[IC-079 探针] 2 第一次滚停（finishNativePaging 后，SwiftUI 尚未刷新）：currentIndex=2 settledIndex=2 contentOffsetX=640.0 偏移所在页=2 pageIndicesPresent=[0, 1, 2] 目标页存在=true
[IC-079 探针] 3 第二次滚动到 i+2（刷新前）：currentIndex=2 settledIndex=2 contentOffsetX=960.0 偏移所在页=3 pageIndicesPresent=[0, 1, 2] 目标页存在=false
[IC-079 探针] 4 第二次滚停（finishNativePaging 后）：currentIndex=3 settledIndex=3 contentOffsetX=960.0 偏移所在页=3 pageIndicesPresent=[0, 1, 2] 目标页存在=false
[IC-079 探针] 5 SwiftUI 刷新（重新 apply 窗口）后：currentIndex=3 settledIndex=3 contentOffsetX=960.0 偏移所在页=3 pageIndicesPresent=[2, 3, 4] 目标页存在=true
[IC-079 探针] 6 最后一页再滑 80pt（越界）：currentIndex=5 settledIndex=5 contentOffsetX=1680.0 偏移所在页=5 pageIndicesPresent=[4, 5] 目标页存在=true
[IC-079 探针] 7 越界滚停：currentIndex=5 settledIndex=5 contentOffsetX=1600.0 偏移所在页=5 pageIndicesPresent=[4, 5] 目标页存在=true
```

事件（节选）：`handleNativePageChange from=1 to=2`、`from=2 to=3` 均在刷新前；`外层setContentOffset source=synchronizeNativeStateToMachine x=640/960 animated=false`（滚停时各一次，值等于结算位）；刷新后 `页移除 pageIndex=0,1`、`页创建 pageIndex=3,4`、`apply x=960 animated=false`。

CI #130（修复后）同一探针：第 3～4 步仍为 `pageIndicesPresent=[0, 1, 2]`、目标页 3 不存在——探针夹具的 `apply` 未传 `pageContentProvider`（保留为原状对照，见"发现但未处理"第 1 条），按需创建路径因此不工作；带提供者的 G141 在第二次滚动半页处与到达 i+2 时页 3、页 4 均已存在。第 5 步 `[1, 2, 3, 4]`（保留半径生效）、第 6～7 步 `[3, 4, 5]`（无越界页）。

## 被删除 / 被修改的测试

- 删除 0 个；修改 1 个（`testIC077G127…`，见结论）；新增 3 个：`testIC079G139FastPagingScenarioExportsWindowFieldsAndEvents`、`testIC079R1FastPagingWindowProbe`、`testIC079G141FastPagingKeepsPagesPresentWithoutOffsetWrites`。计数 452 + 3 = **455**。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G139 | 满足① | `testIC079G139…`：`fastPaging` 在 `allCases`、标题 "D 快速连续翻页"；导出头部 `逐帧字段=…,V,s,pagingContentOffsetX,pagingIsDragging,pagingIsDecelerating,currentIndex,settledIndex,pageIndicesPresent,pageLoadStates`；真实采样行含 `pagingContentOffsetX=320.000000`、`pagingIsDragging=false`、`pagingIsDecelerating=false`、`currentIndex=1`、`settledIndex=1`、`pageIndicesPresent=[0,1,2]`、`pageLoadStates=[0=unknown,1=displayed,2=loading]`；三类事件 `页创建`/`页移除`/`外层setContentOffset`（含 `animated=`）/`handleNativePageChange` 的 `details` 原文；停止后三个记录入口零副作用 |
| G140 | 满足① | 上节探针数据来自 CI #128/#130 日志原文 |
| G141 | 满足①（夹具驱动，真机未覆盖） | `testIC079G141…`：第二次滚动半页处 `pageControllers[2]`、`[3]` 存在，到达 i+2 时 `[3]`、`[4]` 存在；两次滚动期间 `外层setContentOffset … animated=false` 事件增量 0；结算后 `currentIndex == 3`、`machine.scale == 1`、各页 `zoomScale == 1`、`interfaceVisibility` 不变、偏移等于 `contentOffsetForPage(3)`；刷新后页 0 被移除、2～4 保留；最后一页再滑 80pt 无索引 ≥ count 的页、滚停 `currentIndex == 5` |
| G142 | 满足①（G127 见结论） | CI #130 所有 `testIC063…`～`testIC078…` 0 失败；本地 `selfcheck.ps1` 0、`scan-hardcoded-user-visible-strings.ps1` 0、`git diff --check` 0；`git diff 5691767 HEAD -- Reports/IC-068/export-format.md`：15 行新增、0 行删除 |
| G143 | 满足① | CI #130（id `32577134743`）success；被测 `42be5411992eb456d228a7bc5f0823fbd5e74c6d`；`Executed 455 tests, with 0 failures (0 unexpected) in 33.795 (58.217) seconds`；`test_status=0`，9 步 success；IPA `PhotoCleanupMVE-unsigned.ipa` 753701 字节，SHA-256 `ad5904d3f54a565995036762ed5657713075dd411e6c5f6fa7ab6ac193444311`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-42be5411992e` 经 `gh run download`（前两次 EOF，第三次成功）本地 `sha256sum` 一致；被删测试 0 个。CI #128（`241cb6f`，探针）success 454/0；CI #129（`40b51c4`）failure 455 项 1 失败（G127） |
| 闸门 A | 未触发① | `git diff 5691767 HEAD -- S2NativePhotoPager.swift` 未触及 `prepareNativeZoomGeometry`、`applyJointCentering`、`bounds.didSet`、捏合接管、双击/显隐过渡路径 |
| 闸门 B | 形式触发，已按授权处理① | 见结论 |
| 闸门 C | 未触发① | 探针第 3 步目标页不存在（非"存在但未请求"） |
| H29 / 场景 D 录制 | 保留给 Lynn | — |

## 定案落实

- 页存在性：`ensurePagesExistAroundPagingOffset()` 在外层 `scrollViewDidScroll`（排除快照应用期间）按 `contentOffset.x / pageStride` 的 floor−1…ceil+1 创建缺失页，越界不创建；新页 `scale=1`、`viewportOffset=.zero`、`isCurrent=false`，只设 frame，不写外层偏移。
- 页生命周期：`apply` 保留 `currentIndex ± 2`，列表外既有页用提供者最新内容 `update` 一次；页窗口（S2View 列表）仍为 ±1。
- 停止不二次写入：`synchronizeNativeStateToMachine(animatedPaging:false)` 偏移差 ≤ 0.5pt 时跳过；动画路径（Nx 贴边）与偏离情况不变。
- 既有语义：翻页后 `s=1`、非当前页 `scale=1`、`V` 不变、`c` 在 `finishNativePaging` 结算时更新——未改。

## 报告提交方式

拿到 CI #130 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-079/`，不触发 CI）。

## 发现但未处理

1. 探针测试 `testIC079R1FastPagingWindowProbe` 的 `apply` 未传 `pageContentProvider`，修复后复跑仍输出原状（目标页不存在）；它因此成为"无提供者"的对照组而非修复验证，修复验证由 G141 承担。若技术负责人希望探针也反映修复后状态，需另卡为探针加提供者。另：真机上页创建依赖每帧 `scrollViewDidScroll`，夹具用程序化写入只触发一次；若 H29 仍出现纯底色，下一步应在 `scrollViewWillBeginDragging` 预创建 `currentIndex ± 2`。
2. `layoutNativePages` 的 `contentOffset = settledOffset` 直接赋值未经 `writePagingContentOffset`（仅记事件），静止态才执行，未改。
3. `scenario_d` 未加"【未定项 21 占位】"前缀（与 A/B/C 一致，卡未要求）。
4. 闸门 B 与本卡页窗口授权的冲突处理见结论。
