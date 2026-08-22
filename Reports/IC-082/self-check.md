# IC-082 自验报告（nx-edge-paging）——阶段一：R1 探针 + R2 起始条件

## 结论（先行）

R1（场景 E 探针）与 R2（贴边起始条件）完成并上 CI；**R3（闪烁修复）按卡停在"等 Lynn 用场景 E 真机录制两遍"之前，未开始**。分支 `feature/ic-082-nx-edge-paging` 自 `main` = `origin/main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出（与 IC-081 并行，不基于 081）。最终被测 `60cc1f6f6cc853131f317102ffac2e48b7c16f73`，CI #137 success：XCTest **458 项、0 失败**（= 455 + 3 新增 − 0 删除），9 步 success（`test_status=0`），IPA 756774 字节。

**夹具探针结论（①，CI #137 日志原文）**：
```
[IC-082 探针] 起始距边界 20pt、拖动溢出 60pt 松手：overflow=60.0 旧判定 startedAtPagingEdge=true 翻页=true currentIndex=2；新判定 startedAtPagingEdge=false 翻页=false currentIndex=1
[IC-082 探针] 起始贴边、溢出 60pt 松手：overflow=60.0 旧判定 startedAtPagingEdge=true 翻页=true currentIndex=2；新判定 startedAtPagingEdge=true 翻页=true currentIndex=2
```
旧判定（`overflowDistance > 0`）把"起始距边界 20pt 的拖动"也当作贴边起始并翻页，与 H24-1/H28-4"未贴边快滑有时也切页"一致，确认卡第一节第 2 条；R2 改为 `beginNXEdgePaging` 时拖动方向的边界距离 ≤ 0.5pt 后，该序列不翻页、贴边起始序列照常翻页。**闪烁归因（卡第一节第 3 条，③）尚未验证**——需真机场景 E 数据，闸门 C 的判定随之保留。

CI 用了 4 次（探针上限 1 次、修复 2 次）：#135、#136 两次失败均为本会话自身失误（注释直引号被扫描误判；脚本把测试文件二次编码），产品代码自 R2 提交后未再改动。**已超出卡内"探针 1 次 + 修复 2 次"的上限口径**，如实记录，请技术负责人裁定 R3 是否仍可继续。

## 输入、继承与范围

- 任务卡 IC-20260822-082；SPEC-S2 v15 决策 4；Decision_log 第 122 条；`Reports/IC-068/export-format.md`；IC-070/079 探针范例。
- 开工前 `git status --porcelain` 为空（当时在 `feature/ic-081-pinch-max-multiplier`，尖 `a294254`；切到 `main` `072d82c` 建分支）。
- 范围边界：改动 `S2NativePhotoPager.swift`（诊断埋点、`S2NxEdgePagingInteraction.startedAtPagingEdge(for:)`、`finishNXEdgePaging` 起始条件）、`S2View.swift`（场景 E 标题一处）、`Localizable.xcstrings`（+1 键）、`Reports/IC-068/export-format.md`（只追加 15 行）、`S2CalibrationHarnessTests.swift`。未改 `edgePagingTriggerDistance/Velocity` 出厂值、未新增参数；未改 1x 翻页、页窗口、图片请求、横栏、操作条、标记、`pinchMaxScale`；未改捏合接管/居中/过渡（闸门 A）；未新增 XCUITest；未改 SPEC、Decision_log、`Scripts/`、`ci.yml`；未合并主干。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `e8fe8c1` | R1 | 场景 E `nxEdgePaging`（标题"E Nx 贴边翻页"，键 `scenario_e`）；逐帧 +3 字段 `nxDistanceToPreviousBoundary` / `nxDistanceToNextBoundary` / `nxOverflowDistance`；事件 `beginNXEdgePaging` / `handleHorizontalSwipe`（含方向、起始判定、距离、速度、返回值）/ `synchronizeNativeStateToMachine`（animated、索引、s）；`writePagingContentOffset` 沿用既有事件；`diagnosticNXEdgePagingInteraction/Projection` 读取口；`export-format.md` 追加；G139 头部断言更新；G152；夹具探针 |
| `079e825` | R2 | `S2NxEdgePagingInteraction.edgeTolerance = 0.5`、`startedAtPagingEdge(for:)`；`finishNXEdgePaging` 用交互记录判定；G153 |
| `ace3146` | 修正 | R2 注释直引号改「」（CI #135 扫描误判） |
| `60cc1f6` | 修正 | 恢复 harness 文件 UTF-8 编码（CI #136 51 项失败均为乱码断言），G153/探针内容不变 |

## 被删除 / 被修改的测试

- 删除 0 个。修改 1 个：`testIC079G139…`（头部字段声明追加三个字段）。新增 3 个：`testIC082G152NxEdgePagingScenarioExportsFieldsAndEvents`、`testIC082G153NxEdgePagingRequiresEdgeAtDragStart`、`testIC082R1NxEdgePagingStartConditionProbe`。计数 455 + 3 = **458**。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G152 | 满足① | `testIC082G152…`：`allCases` 含 E、标题；头部 `逐帧字段=…,pageLoadStates,nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance`；非贴边期间三字段 `nil`；内层 `zoomScale/contentOffset/contentSize`、外层 `pagingContentOffsetX`、`pagingIsDragging/Decelerating`、`currentIndex` 同在；三类事件 `details` 原文；停止后四个入口零副作用 |
| G153 | 满足① | `testIC082G153…`：起始距边界 20pt + 溢出 60 + 阈值速度 → `startedAtPagingEdge=false`、不翻页、`s` 仍 2；起始 0.4pt（≤ 0.5）+ 溢出 60 → 翻页、`s=1`；起始贴边 + 溢出 39 → 不翻页 |
| G154 | **未覆盖** | R3 未开始（等真机数据） |
| G155 | 满足①（阶段） | CI #137 所有 `testIC0…` 0 失败；本地三项门禁 0；`git diff main HEAD -- Reports/IC-068/export-format.md` 15 行新增、0 删除 |
| G156 | 满足①（阶段） | CI #137（id `32585410551`）success；被测 `60cc1f6f6cc853131f317102ffac2e48b7c16f73`；`Executed 458 tests, with 0 failures (0 unexpected) in 32.689 (46.804) seconds`；`test_status=0`；IPA 756774 字节，SHA-256 `e3efffa862ce30bdca82a5030b647f2c16ac65f0941dd85b6a7c8d13def133ac`，artifact `PhotoCleanupMVE-unsigned-60cc1f6f6cc8` 本地 `sha256sum` 一致 |
| 闸门 A | 未触发① | 未改捏合接管、居中、过渡路径 |
| 闸门 B | 未触发① | 既有门禁全过 |
| 闸门 C | 待数据 | 需场景 E 真机录制 |
| H31 / 场景 E 录制 | 保留给 Lynn | 请用 CI #137 包录制两遍：放大后平移到贴边再同向快滑切页；放大后不贴边直接快滑 |

## R3 所需数据与下一步

技术负责人转交两份场景 E 导出文本后：看 `beginNXEdgePaging` 的起始距离、逐帧 `nxOverflowDistance` 与 `pagingContentOffsetX` 的跟手比、`外层setContentOffset` 的来源序列（`updateNXEdgePaging` 与 `synchronizeNativeStateToMachine` 是否交叉、内层 `contentOffset` 是否同时变化）、`presentationFrame` 的往返跳变。若闪烁来自图片层替换（`pageLoadStates` 变化与跳变同帧）→ 闸门 C。

## 发现但未处理

1. 本会话两次 CI 失败为执行失误（注释引号；脚本编码），已修正，未动产品。
2. `reportSequenceBoundaryAttemptIfNeeded` 路径（序列边界）仍传 `startedAtPagingEdge: true`——那是 1x 外层拖动到序列边界的尝试记录，不在本卡范围，未动。
