# IC-075 自验报告（top-bar-badge-and-marks）

## 结论（先行）

R1～R5 完成，CI 一次通过（1/3）。分支 `feature/ic-075-top-bar-and-marks` 自 `feature/ic-074-parameter-layer` 尖 `11b07f3`（产品代码 = CI #121 被测 `7a8a8fa`）切出，六个代码提交，最终被测 `d6de321fb82b8fbcce001319f6dff52d35d18dd3`。CI #122 success：XCTest **428 项、0 失败**（= 422 + 6 新增 − 0 删除），9 步全部 success（真实退出码 0），IPA 699784 字节。顶部信息区已精简为三件；徽标/入口按会话待删总数显隐与禁用；主图与横栏待删标记按 v15 实装、脉冲由渲染层关键帧驱动；相册角标与 `G(a)` 整体移除。参数层 33 → 35（`bottomStripMarkSize = 14`、`markPulseDurationMilliseconds = 150`，均 decided/effective），IC-074 的 33 个出厂值不变。闸门 A 未触发：既有几何门禁全部通过，宿主 S2View 下标记显示与脉冲期间照片几何写入为 0。

**两处需技术负责人知悉的偏差**：(a) 主图标记的纵向位置按卡字面（距安全区上 `horizontalPadding`）会与顶部信息区（安全区下方 48pt）重叠，已改为置于顶部信息区下方（`safeTop + topBarHeight + horizontalPadding`），右距按卡；属④待确认，H25 可直接看到。(b) G105 的 `item12` 在 S1 有一个同子串标识 `S1UndecidedItems.item12S2ReturnValidationFailurePresentation`（S1 禁改，未动）；S2 的 `.item12` 已删除。

H24/H25 留给 Lynn 真机判定。

## 输入、继承与范围

- 任务卡 IC-20260822-075；SPEC-S2 v15（回写决策 29、30；S2-1～S2-6 显示元素）；IC-066 第 7/9/17/18/19 项；IC-074 change-list 占位值登记格式
- 开工前 `git status --porcelain` 为空；`11b07f3` 本地 = origin
- 范围边界：只改 `S2View.swift`、`S2Calibration.swift`、`S2StateMachine.swift`、`Localizable.xcstrings` 与两个测试文件。未改操作条三按钮行为/接线、加载态、图片请求策略、`S2TemporaryPhotoImageStrategy.swift`、`pinchMaxScale`、`debugAssetLimit`、手势分层/居中/描边/过渡/截图判定/捏合接管/Nx 贴边翻页、S1→S2 交接契约（`范围显示信息` 仍随快照保存并交回，只是不再显示）、既有出厂值、`PhotoCleanupMVEApp.stripItemContent`；未新增参数（主图标记尺寸为占位派生值）；未新增 XCUITest；未改 SPEC、Decision_log、S1、S3～S5、`Scripts/`、`ci.yml`

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `681cae9` | R1 | `topElementFrames(in:)` 返回三帧（返回 88×48 左、序号居中、入口 88×48 右，高度均 `topBarHeight`）；`snapshot` 可点击帧改取帧 0/2；`topBar` 三子视图；删 `currentStatusText`、`topTextLineHeight`；键 −3（`s2.range.summary`、`s2.status.marked/unmarked`）+1（`s2.top.position` = `{current}/{total}`）；L1 计数 3、L3 注释、新增 G104 |
| `f3b5d2d` | R2 | `S2StateMachine.canEnterConfirmation`；`S2ConfirmationEntryPresentation`（徽标/禁用/无障碍）；入口 `.disabled(!canEnterConfirmation)`，count=0 不渲染徽标；键 +1 `s2.confirm.disabled.accessibility`；新增 G106 |
| `1d0551a` | R2 修正 | 无障碍文案改为两个显式 `L10n.text("…")` 调用——字符串目录扫描器不识别三元表达式里的键（本地扫描暴露） |
| `4148654` | R4 | 参数 `bottomStripMarkSize = 14`（字段/出厂/校验/导出/登记/编解码）；`S2BottomStripMarkPresentation`；`S2BottomStripView` 自身在每项右上角叠加 `trash.circle.fill`，尺寸读参数，内容闭包不改；G96/G97/L7 计数 34；新增 G108 |
| `d426d5c` | R3 | 参数 `markPulseDurationMilliseconds = 150`；`S2PrimaryMarkPresenter`（显隐矩阵、尺寸 = `bottomStripMarkSize × 2`、通知消费与脉冲计数）；主图标记浮层（不参与命中测试，`keyframeAnimator` 1.0→1.3→1.0）；`onChange(of: machine.semanticNotice)` 消费；键 +1 `s2.mark.primary.accessibility`；G96/G97/L7 计数 35；新增 G107 两个测试 |
| `d6de321` | R5 | 删 `S2UndecidedItem.item12/.item19`、`S2UndecidedItems.item12AlbumRemovalHint/item19AlreadyMarkedHint`、`S2SemanticNotice.albumAdditionRemovedPendingDeletion`、`addedAlbumsByAssetID`、`currentAddedAlbums`、`recordAlbum`、`invalidateAlbum` 的 G 清理循环（保留 H 失效）、`handleSwipeUp` 的 `.item19`、`removeFromPendingAfterAlbumAddition` 的通知与 `.item12`；视图删角标分支与两个属性；键 −3 `s2.album.badge.*`；测试删两行 G 断言、新增 R5 H 失效断言 |

R4 先于 R3 提交：R3 的主图标记尺寸派生自 R4 的 `bottomStripMarkSize`。六个提交各自可独立编译与 cherry-pick。

## 被删除 / 被修改的测试

- **删除：0 个**。没有任何既有测试的唯一断言对象是 `G(a)`、角标或 `.item12/.item19`。
- **修改**：`testL1TopOverlayFramesRespectSafeAreaTop`（计数 4→3）、`testL3TopOverlayFramesDoNotIntersect`（仅注释）、`testL7FactoryDefaultsMatchSystemParityDecision`（期望构造 +2 参数）、`testIC074G96…`/`testIC074G97…`（35/39/35、decided 18）、`testIC047_014TransitionRowRecentAlbum` 与 `testIC047_017TransitionRowAlbumSheetSuccess`（各去掉一行 G 断言，其余断言不变）。
- **新增 6 个**：`testIC075G104TopBarHasThreeElementsWithClickableEnds`、`testIC075G106ConfirmationEntryFollowsSessionPendingCount`、`testIC075G107PrimaryMarkVisibilityMatrixAndPulseConsumption`、`testIC075G107HostedPrimaryMarkPulsesWithoutPhotoGeometryWrites`、`testIC075G108BottomStripMarkFollowsPendingSetAndMarkSize`、`testIC075R5AlbumUnavailableInvalidatesOnlyRecentAlbum`。
- 计数：422 + 6 = **428**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G104 | 满足① | `testIC075G104…`：3 帧、互不相交、均在顶部区域内、帧 0/2 为 88×48 ≥ 44、`clickableControlFrames` 含帧 0/2 不含帧 1；L4 的 8 个可点击帧全部 ≥ 44 |
| G105 | 满足①（一处说明） | 11 个标识在产品/测试/`.xcstrings` 命中：10 个为 0；`item12` 命中 1 = `S1StateMachine.swift` 的 `item12S2ReturnValidationFailurePresentation`（S1 内部标识、子串命中；S1 禁改）。`s2.top.position` 命中 2（定义 + 引用） |
| G106 | 满足①（夹具驱动） | `testIC075G106…`：count=0 → `canEnterConfirmation=false`、`isEnabled=false`、无徽标文本、无障碍含 0；count=1 → 相反；两者 `makeExitPayload` 均可生成 |
| G107 | 满足①（夹具驱动，真机未覆盖） | `testIC075G107PrimaryMarkVisibilityMatrixAndPulseConsumption`：四组合仅 V=显示∧c∈D 为真；尺寸 28；visible+alreadyMarked → pulse 1；hidden → 消费计数 +1、pulse 不变。`testIC075G107HostedPrimaryMarkPulsesWithoutPhotoGeometryWrites`：宿主 S2View，已标记再上滑后 `semanticNotice` 为 nil、`pulseCount`=1；隐藏态再上滑消费 +1、pulse 仍 1 |
| G108 | 满足①（夹具驱动） | `testIC075G108…`：`bottomStripMarkSize=14`；D 中项 `isShown`、尺寸 14；非 D 项无；`beginBottomStripDrag` 后呈现与静止态相等 |
| G109 | 满足① | 字段 35、导出 39 行、登记表 35 条、decided = IC-074 的 16 + 2 新参数 = 18（`testIC074G96…`/`G97…` 已按本卡计数更新）；IC-074 的 33 个出厂值逐项未改（L7 字面值断言 + 本卡只追加两行） |
| G110 | 满足① | CI #122 全部既有测试通过（IC-063 10、IC-064 6、IC-065 7、IC-067、IC-069 6、IC-070 6、IC-074 4 个 `testIC0xx…` 均 passed） |
| G111 | 满足① | `selfcheck.ps1` 退出码 0；`scan-hardcoded-user-visible-strings.ps1` 退出码 0（目录 162 = 引用 162，无孤儿键）；`git diff --check` 退出码 0 |
| G112 | 满足① | CI #122（id `32549127170`）success；被测 `d6de321fb82b8fbcce001319f6dff52d35d18dd3`；`Executed 428 tests, with 0 failures (0 unexpected) in 31.418 (35.573) seconds`；「运行 XCTest」及 9 步 success，真实退出码 0；IPA `PhotoCleanupMVE-unsigned.ipa` 699784 字节，SHA-256 `dc86acfc369338d6d09fad327ee19024ba409109ec3e129551d163824e9ff01d`，artifact `PhotoCleanupMVE-unsigned-d6de321fb82b` 已下载并本地 `sha256sum` 复核一致；被删测试 0 个 |
| G113 | 满足① | 本分支新增的用户可见字符串：`s2.confirm.disabled.accessibility`、`s2.mark.primary.accessibility` 均以"【未定项 21 占位】"开头；`s2.top.position` = `{current}/{total}` 无前缀（豁免）。`git diff` 中 `s2.confirm.accessibility` 因排序位移显示为新增行，其值为既有文本未改 |
| 闸门 A | 未触发① | 既有几何门禁全部通过；宿主 S2View 录制 0.5s 静止 + 脉冲期间 `photoGeometryWriteCount` = 0 |
| H24 / H25 | 保留给 Lynn | — |

## 定案落实与取定值

- 主图标记：`trash.circle.fill`，尺寸 `bottomStripMarkSize × 2 = 28`（④ 占位派生，不新增参数），`allowsHitTesting(false)`，Nx 下固定于视口；位置见上文偏差 (a)。
- 脉冲：`keyframeAnimator(trigger: pulseID)`，`CubicKeyframe(1.3, d/2)` + `CubicKeyframe(1.0, d/2)`，`d = markPulseDurationMilliseconds`；由渲染层驱动，不依赖主线程逐帧推进。
- 横栏标记：`trash.circle.fill`，尺寸 `bottomStripMarkSize`，叠加在缩略图右上角内侧（紧贴角，无额外内缩——卡未定内缩量，按 0 处理并在此登记）。
- 徽标：`S2ConfirmationEntryPresentation`；无障碍：启用态沿用既有 `s2.confirm.accessibility`，禁用态新键。
- 序号：`s2.top.position` = `{current}/{total}`，系统默认字体字号。

## 报告提交方式

拿到 CI #122 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-075/`，不触发 CI）。

## 发现但未处理

1. `exportText()` 的 `taskID` 仍为 IC-074（本卡未要求更新）。
2. `S2UndecidedItems.item17AlbumBadgePresentation`、`item18BottomStripMarkPresentation` 两个占位常量仍在（卡只要求删 `.item12/.item19`；它们对应的角标已移除、横栏标记已实装）。
3. 主图标记与顶部信息区的纵向关系（偏差 a）需要你确认或改卡。
