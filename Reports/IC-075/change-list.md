# IC-075 变更清单

分支 `feature/ic-075-top-bar-and-marks`，自 `feature/ic-074-parameter-layer` 尖 `11b07f3` 切出。最终被测提交 `d6de321fb82b8fbcce001319f6dff52d35d18dd3`（CI #122，428 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `681cae9` | R1 | `S2Calibration.swift`、`S2View.swift`、`Localizable.xcstrings`、`S2CalibrationHarnessTests.swift` | 顶部三帧布局与三子视图；键 −3/+1；L1/L3 更新、G104 新增 |
| `f3b5d2d` | R2 | `S2StateMachine.swift`、`S2View.swift`、`Localizable.xcstrings`、`S2StateMachineTests.swift` | `canEnterConfirmation`；徽标/禁用呈现；键 +1；G106 新增 |
| `1d0551a` | R2 修正 | `S2View.swift` | 无障碍文案显式键引用 |
| `4148654` | R4 | `S2Calibration.swift`、`S2View.swift`、`S2CalibrationHarnessTests.swift` | `bottomStripMarkSize=14`；横栏标记叠加；计数 34；G108 新增 |
| `d426d5c` | R3 | `S2Calibration.swift`、`S2View.swift`、`Localizable.xcstrings`、`S2CalibrationHarnessTests.swift` | `markPulseDurationMilliseconds=150`；主图标记浮层与脉冲；键 +1；计数 35；G107 两个测试新增 |
| `d6de321` | R5 | `S2StateMachine.swift`、`S2View.swift`、`Localizable.xcstrings`、`S2StateMachineTests.swift` | 角标与 `G(a)` 移除；键 −3；R5 断言新增 |

## 产品行为变化

- 顶部信息区：返回 / `{n}/{N}` / 确认页入口三件；不再显示范围摘要与文字状态。
- 确认页入口：会话待删总数 > 0 显示纯数字徽标；= 0 不渲染徽标且按钮禁用。
- 主图待删标记：`V=显示 ∧ c∈D` 时显示于视口右上角浮层（顶部信息区下方），Nx 下固定；已标记再上滑脉冲一次（150ms），不弹文字；`V=隐藏` 不显示、不脉冲。
- 横栏待删标记：D 中缩略图右上角 14pt `trash.circle.fill`，静止态与滑动态相同，由横栏视图自身绘制。
- 相册角标移除；加入相册后从 `D` 移除静默完成；历史相册失效只使 `H` 失效。
- `S2UndecidedItem` 去掉 `.item12`、`.item19`；`S2SemanticNotice` 只剩 `.alreadyMarked`。

## 本地化键

−6：`s2.range.summary`、`s2.status.marked`、`s2.status.unmarked`、`s2.album.badge.single/multiple/accessibility`；+3：`s2.top.position`（`{current}/{total}`）、`s2.confirm.disabled.accessibility`、`s2.mark.primary.accessibility`（后两者带"【未定项 21 占位】"前缀）。目录条目 165 → 162，与产品引用一致。

## 参数层

字段 33 → 35、导出 37 → 39 行、登记表 35 条（decided 18、placeholder 17）。新增定案参数：`bottomStripMarkSize = 14`、`markPulseDurationMilliseconds = 150`（规格状态 decided、接线 effective，出厂值来自 v15 第十一节）。IC-074 的 33 个出厂值未改。

## 未变更

操作条三按钮行为/接线/in-flight/toast/`H` 持久化；加载态/失败态/降质预览/图片请求策略/`S2TemporaryPhotoImageStrategy.swift`；`pinchMaxScale`、`debugAssetLimit`；手势分层、居中、描边、过渡动画、截图判定、捏合接管、Nx 贴边翻页；S1→S2 交接契约与 `范围显示信息` 字段；`PhotoCleanupMVEApp.stripItemContent`；既有出厂值；`Scripts/`、`ci.yml`、SPEC、Decision_log、S1、S3～S5；分支与 worktree。

## 占位值登记（本卡新增或变更的占位值）

> 格式沿用 IC-074：参数名 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡。

| 项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| 主图待删标记尺寸（占位派生，非参数） | `bottomStripMarkSize × 2` = 28pt | effective | v15 S2-1/S2-4 只定符号与位置，未定尺寸；④ 本卡取定 | IC-075 |
| 主图待删标记纵向位置（实现取定，待确认） | 顶部信息区底边下方 `horizontalPadding`（8pt），右距安全区 8pt | effective | 卡字面"距安全区上 8pt"与顶部信息区重叠；待技术负责人确认或改卡 | IC-075 |
| 横栏标记内缩量 | 0（紧贴缩略图右上角内侧） | effective | 卡未定内缩量 | IC-075 |
