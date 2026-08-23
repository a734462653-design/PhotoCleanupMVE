# IC-082 自验报告（nx-edge-paging，v2 卡）

## 结论（先行）

R1（场景 E 探针）、R2（贴边起始条件）、R3（单一机制：原生嵌套滚动交接）全部完成。分支 `feature/ic-082-nx-edge-paging` 自 `main` = `origin/main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出（与 IC-081/083 并行，不基于 081）。最终被测 `cfc08bb1500c94514bf0c0fbf3a7834b3f5d1b7f`，CI #140 success：XCTest **457 项、0 失败**（= 455 + 4 新增 − 2 删除），9 步 success（`test_status=0`），IPA 753255 字节。

**归因（①真机 E1/E2 + ①夹具探针）**：
- 卡第一节第 2 条（起始条件错误）由夹具探针（CI #137）确认：旧判定把"起始距边界 20pt、溢出 60pt"当作贴边并翻页，新判定不翻页。
- 卡第一节第 3 条（两层各写偏移 → 闪烁）由 v2 卡引用的真机 E1/E2 数据确认并定向：自定义投影路径 `updateNXEdgePaging` 与外层原生分页在同一手势上并存——E1 中自定义路径以 `startedAtPagingEdge=false` 拒绝并动画写回 2110，随后外层原生拖动（`pagingIsDragging=true`，2110→2532）完成切页并经 `finishNativePaging` 结算；两份录制外层 `setContentOffset` 写入来源：`apply` 46/50、`updateNXEdgePaging` 6/3、`synchronizeNativeStateToMachine` 1/1。即切页本就由外层原生分页完成，自定义路径只贡献多余写入。闸门 C（闪烁来自图片层替换）未触发。

**R3 实现**：删除 `S2NxEdgePagingInteraction`/`S2NxEdgePagingProjection`、`beginNXEdgePaging`/`updateNXEdgePaging`/`finishNXEdgePaging`/`resetNXEdgePaging`、页控制器对内层 pan 识别器的 `handleNativePan` 目标注册，以及诊断起始事件；Nx 下左右拖动由 UIKit 嵌套滚动在内层到边界后交接给外层分页容器，结算沿用 `finishNativePaging → handleNativePageChange → synchronizeNativeStateToMachine(animatedPaging: false)`。`handleHorizontalSwipe` 保留（状态机测试与 `reportSequenceBoundaryAttemptIfNeeded`），`edgePagingTriggerDistance/Velocity` 登记改 `unwired`、规格状态 `decided`、出厂值不变。内层 `bounces=false` 保持。

**CI 次数**：阶段一 4 次（#135、#136 为本会话失误，#137 成功；v2 卡明示不计入 R3）；R3 2 次（#139 success 457/0；#140 success，仅把 G154 的否定断言字符串改为来源白名单以使全分支 grep 为 0）。

H31 与 R3 后的场景 E 录制留给 Lynn。

## 输入、继承与范围

- 任务卡 IC-20260822-082 v2；SPEC-S2 v15 决策 4；Decision_log 第 122 条；真机 E1/E2 录制（由技术负责人摘要写入卡内，原文未转交本会话）；`Reports/IC-068/export-format.md`。
- 开工前 `git status --porcelain` 为空。
- 范围边界：改动 `S2NativePhotoPager.swift`、`S2View.swift`（场景 E 标题一处）、`S2Calibration.swift`（两项登记接线状态）、`Localizable.xcstrings`（+1 键）、`Reports/IC-068/export-format.md`（只追加 23 行）、`S2CalibrationHarnessTests.swift`。未改 `edgePagingTriggerDistance/Velocity` 出厂值、未新增参数；未改 1x 翻页、页窗口、图片请求、横栏、操作条、标记、`pinchMaxScale`；未改捏合接管、居中（`prepareNativeZoomGeometry`/`applyJointCentering`/`bounds.didSet`）、双击/显隐过渡（闸门 A）；未新增 XCUITest；未改 SPEC、Decision_log、`Scripts/`、`ci.yml`；未合并主干。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `e8fe8c1` | R1 | 场景 E；逐帧 +3 字段；事件 +3；诊断读取口；`export-format.md` 追加；G139 头部更新；G152；夹具探针 |
| `079e825` | R2 | `startedAtPagingEdge(for:)`（边界距离 ≤ 0.5pt）；`finishNXEdgePaging` 改用；G153 |
| `ace3146` | 修正 | 注释引号（CI #135 扫描误判） |
| `60cc1f6` | 修正 | 恢复测试文件 UTF-8（CI #136） |
| `31172b3` | docs | 阶段一报告 |
| `ba2e0f2` | R3 | 删除自定义投影路径（`S2NativePhotoPager.swift` −232 行）；`recordHorizontalSwipe` 增 `source`，`reportSequenceBoundaryAttemptIfNeeded` 记录事件；逐帧三字段恒 nil；登记 `unwired`；`export-format.md` 追加 R3 说明；G152/G153 改写、探针与 B1 删除、G154 新增 |
| `cfc08bb` | R3 测试 | G154 外层写入来源断言改白名单（grep 清零） |

R2 的产品改动在 R3 中随结构体一并删除（起始条件由 UIKit 交接天然满足）；R2 提交保留在链上可独立 cherry-pick。

## 被删除 / 被修改的测试

- **删除 2 个**：`testB1NxBoundaryContinuationProducesPagingDisplacement`（测被删的溢出投影）、`testIC082R1NxEdgePagingStartConditionProbe`（探针，引用被删结构体；其数据已记入本报告）。
- **修改 4 个**：`testIC079G139…`（头部字段 +3）、`testIC082G152…`（去起始事件、事件来源改序列边界路径）、`testIC082G153…`（改为状态机层三条正反断言）、`testIC067C5ParameterConnectionStatusesCoverEveryFieldExactlyOnce`：`edgePagingTrigger*` 两行改 `.unwired`。
- **新增 4 个（累计）**：`testIC082G152NxEdgePagingScenarioExportsFieldsAndEvents`、`testIC082G153NxEdgePagingRequiresEdgeAtDragStart`、`testIC082G154NxPagingHandsOffToOuterNativeScrollWithoutCustomWrites`，以及阶段一的探针（后删）。净计数 455 + 3 − 1（B1）= **457**，与 CI 一致。

## 探针数据（①，CI #137）

```
[IC-082 探针] 起始距边界 20pt、拖动溢出 60pt 松手：overflow=60.0 旧判定 startedAtPagingEdge=true 翻页=true currentIndex=2；新判定 startedAtPagingEdge=false 翻页=false currentIndex=1
[IC-082 探针] 起始贴边、溢出 60pt 松手：overflow=60.0 旧判定 startedAtPagingEdge=true 翻页=true currentIndex=2；新判定 startedAtPagingEdge=true 翻页=true currentIndex=2
```

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G152 | 满足① | `testIC082G152…`：场景 E 在 `allCases`、标题；头部 `…,pageLoadStates,nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance`；三字段 `nil`；内层 `zoomScale/contentOffset/contentSize`、外层 `pagingContentOffsetX`、`pagingIsDragging/Decelerating`、`currentIndex`；事件 `handleHorizontalSwipe`（来源 `reportSequenceBoundaryAttemptIfNeeded`，含方向/起始判定/距离/速度/返回值）、`synchronizeNativeStateToMachine`；`beginNXEdgePaging` 不再出现；停止后零副作用 |
| G153 | 满足① | `testIC082G153…`：`startedAtPagingEdge=false` + 60 + 阈值速度 → 不翻页、`s` 仍 2；`true` + 60 → 翻页、`s=1`；`true` + 39 → 不翻页（状态机层；起始贴边与否在 R3 后由 UIKit 交接决定） |
| G154 | 满足①（夹具驱动，真机未覆盖） | `testIC082G154…`：Nx（`s=2`）下内层 `bounces=false`、外层 `isPagingEnabled`；内层平移到中途时外层偏移不变、`外层setContentOffset` 事件增量 0；内层贴边后外层经 pan 回调 + 偏移驱动到下一页并 `scrollViewDidEndDecelerating` → `currentIndex+1`、`machine.scale==1`、旧页 `zoomScale==1`、新页 `zoomScale==1`、`V` 不变、外层停在结算位；全程外层写入来源 ⊆ {`apply`, `layoutNativePages`, `synchronizeNativeStateToMachine`}；无 `beginNXEdgePaging`；有 `handleNativePageChange … accepted=true`；导出三字段 `nil`。`git grep -c "updateNXEdgePaging\|S2NxEdgePagingProjection" -- PhotoCleanupMVE PhotoCleanupMVETests Scripts` 无输出（0）。E1/E2 数据引用见结论 |
| G155 | 满足① | CI #140 所有 `testIC063…`～`testIC079…` 0 失败（IC-081 门禁在其自身分支，本分支基于 `main`）；本地三项门禁 0；`git diff main HEAD -- Reports/IC-068/export-format.md` 23 行新增、0 删除 |
| G156 | 满足① | CI #140（id `32592247295`）success，9 步 success；被测 `cfc08bb1500c94514bf0c0fbf3a7834b3f5d1b7f`；`Executed 457 tests, with 0 failures (0 unexpected) in 19.093 (23.185) seconds`；`test_status=0`；IPA 753255 字节，SHA-256 `09c7f88ac3e2f2c74061f33abad90f663cdb337978fa12ae2ea27e1fcbedf885`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-cfc08bb1500c` 本地 `sha256sum` 一致。CI #139（`ba2e0f2`）亦 success 457/0，IPA `90da8918…4492d3` |
| 闸门 A | 未触发① | `git diff main HEAD -- S2NativePhotoPager.swift` 未触及捏合接管、`prepareNativeZoomGeometry`、`applyJointCentering`、`bounds.didSet`、双击/显隐过渡 |
| 闸门 B | 未触发① | 既有门禁全过 |
| 闸门 C | 未触发①（真机）/ 夹具不能证明交接 | E1：`s>1` 期间外层 `pagingIsDragging=true` 并连续到 2532 → 外层在 Nx 下确实接管拖动。夹具无法模拟触摸交接，G154 用 pan 回调驱动；真机 H31 兜底 |
| H31 / 场景 E 录制 | 保留给 Lynn | 请用 CI #140 包：放大后贴边再滑应跟手并平滑切页；未贴边快滑只平移；1x 翻页、捏合接管无回归；录制一遍场景 E |

## 定案落实

- 起始条件：由 UIKit 嵌套滚动天然满足——内层在拖动方向可滚动时吃掉位移，外层不动；内层到边界（`bounces=false`）后同一手势交给外层。
- 过程：外层偏移只由原生拖动/减速改变；松手后原生分页动画结算；`finishNativePaging` 在 `scrollViewDidEndDragging(willDecelerate:false)`/`DidEndDecelerating` 结算 `c`，`synchronizeNativeStateToMachine(animatedPaging:false)` 仅在偏移偏离结算位 > 0.5pt 时写入（IC-079）。
- 语义不变：翻页后新照片 `s=1`、旧页复位、`V` 不变。
- 诊断：三个 nx 字段保留列位恒 `nil`；`handleHorizontalSwipe` 事件只来自序列边界尝试路径（`export-format.md` 已注明）。

## 报告提交方式

拿到 CI #140 结果后，以一个 docs 提交把本报告（完整替换阶段版）与变更清单追加到同一分支。

## 发现但未处理

1. `reportSequenceBoundaryAttemptIfNeeded` 仍传 `startedAtPagingEdge: true`（1x 序列边界尝试记录），不在本卡范围。
2. `S2StateMachine.handleHorizontalSwipe` 的 Nx 分支（阈值判定）在产品路径已无调用者，仅测试与序列边界路径使用；`edgePagingTriggerDistance/Velocity` 去留待 Decision_log。
3. `scenario_e` 文案未加"【未定项 21 占位】"前缀（与 A～D 一致）。
4. 阶段一两次 CI 失败为执行失误（已修正）。
