# IC-074 自验报告（parameter-layer-v15-alignment，v3）

## 结论（先行）

R1～R4 完成，一次 CI 通过。分支 `feature/ic-074-parameter-layer` 自 `main`（`8acf43d05d6fa0d7a74024baf78b29d775e1d820`）切出，两个代码提交：R2 `9cbe77a`、R1 `7a8a8fa75ecf6122d897a34c955e4960dd05a3bf`（最终被测）。CI #121 success：XCTest **422 项、0 失败**（= 420 − 2 删除 + 4 新增），9 步全部 success（真实退出码 0），IPA 689627 字节。`S2CalibrationConfiguration` 字段 48 → 33，15 个废止参数及两个附属枚举在产品与测试代码中命中 0；登记表 33 条双维度，decided 恰 16 项；导出 37 行、`schemaVersion=2`、含 `specBaseline=SPEC-S2-20260821_v15`；33 个保留字段出厂值与 `8acf43d` 逐项相同。本卡唯一有意的行为变化（1x 横向结束的主图拖动不再由状态机切页）已单列并有正反断言；闸门 A 按 v3 定案消化，闸门 B 未触发（除新增断言外无既有测试失败）。CI 次数 1/3。H24 留给 Lynn 真机判定。

## 输入、继承与范围

- 任务卡 v3；规格基线 SPEC-S2 v15（SHA-256 `0051DF90…C9546E`）；IC-066 盘点；v2 停线报告（`<top>/Reports/IC-074/self-check.md`，保留）
- 开工前 `git status --porcelain` 为空；`S2CalibrationConfiguration` 字段数实测 **48**（①，`var` 行计数），与 v3 一致
- 范围边界：只改 `S2Calibration.swift`、`S2View.swift`、`Localizable.xcstrings`、`S2StateMachine.swift`、`S2NativePhotoPager.swift` 与两个测试文件；未改任何保留参数出厂值；未实装 v15 新参数；未改手势分层、居中、描边、过渡动画、截图判定、图片请求策略、`S2TemporaryPhotoImageStrategy.swift`、顶部信息区/操作条/横栏/角标；未清理 `debugAssetLimit`；未改 `Scripts/`、`ci.yml`、历史报告；未新增 XCUITest；未改 SPEC、Decision_log、S1、S3～S5；未合并 main

## 提交清单

| 提交 | 归属 | 内容 |
|---|---|---|
| `9cbe77a` | R2 | `S2ResolvedParameters` 删除 `horizontalSwipeDistance`、`horizontalSwipeVelocity`、`pinchMinimumScaleDelta`、`mainDragMinimumDistance` 四项及校验；`completeMainDrag` 1x 水平分支改为直接 `return false`；`finishNativePinch` 删除捏合速度/时长过滤（恒 `accepted: true`）并删除 `durationIsAllowed`；`S2Calibration.resolvedParameters` 不再传四项；状态机测试夹具同步；新增正反断言 `testIC074R2OneXHorizontalDragEndDoesNotSwitchPhoto`、`testIC074R2NxEdgePagingThresholdsUnchanged` |
| `7a8a8fa` | R1 | 删除 15 字段及 `S2FitInsetScope`、`S2GestureExclusivityPolicy`、`S2ViewportLayout.insetApplies(scope:)`（仅测试调用）；`CodingKeys`/解码/编码/`isValid`/`factoryPlaceholder`/`exportText()` 同步；新增 `S2CalibrationParameterSpecStatus`，登记表改为 `(name, specStatus, wiringStatus)` 33 条；`schemaVersion=2`、`taskID` 改本卡、新增 `specBaseline` 行；面板删除 `fitInsetScope` Picker、`screenshotImmersiveOnHide` Toggle 与标题函数，登记列表显示两列状态；`Localizable.xcstrings` 删 `s2.calibration.option.fit_scope.*` 两键、加 `s2.calibration.spec.decided`（已定案）/`s2.calibration.spec.placeholder`（登记占位）；R2 注释去掉废止名；测试更新与新增 G96/G97 |

R2 先于 R1 提交，使两个提交各自可独立编译与 cherry-pick。

## R2：调用链核查（G99，沿用 v2 停线报告）

| # | 生产调用链（文件:行，均为 `8acf43d` 行号） | 触发入口 | `zoomState` | `dragDirection` / 方向约束 | 进入的分支 | v3 处置 |
|---|---|---|---|---|---|---|
| 1 | `S2NativePhotoPager.swift:1146`（`zoomScrollView.panGestureRecognizer.addTarget`）→ `:2205 handleNativePan(_:)` → `:2710 handleNativePan(on:recognizer:)`（guard `.nX`）→ `.ended` → `:2800 finishNXEdgePaging` → `:2807 machine.handleHorizontalSwipe(startedAtPagingEdge: overflow > 0, distance: overflow, velocity:)` → `S2StateMachine.swift:1269` | Nx 下原生平移到内容边界后继续拖出并松手 | `.nX`（确定） | 不经 `dragDirection`；横向溢出 `max(0, |Δx| − 到边界距离)` | `:1278-1283` nX 分支：`startedAtPagingEdge && distance ≥ edgePagingTriggerDistance(40) && velocity ≥ edgePagingTriggerVelocity(300)` → `switchPhoto` | 两参数改为 decided/effective 保留；此链**一字未改**（`testIC074R2NxEdgePagingThresholdsUnchanged` 覆盖低于距离/低于速度/未贴边 → false，达阈值 → true） |
| 2 | `:1145 addGestureRecognizer(verticalSwipeRecognizer)` → `:2092 gestureRecognizerShouldBegin` → `shouldBeginVerticalSwipe`（`:2529 allowsVerticalSwipeRecognition` ⇒ `scale == 1`，开始时 `|vy| > |vx|`）→ `:2181 handleVerticalSwipe .ended` → `:2190 finishVerticalSwipe(translation: 最终位移)` → `:2696 completeMainDrag` → `S2StateMachine.swift:1312` | 1x 下竖向起手的单指拖动松手 | `.oneX`（确定） | 识别器只在开始时要求竖向；`completeMainDrag` 用最终位移重算，可为 `.horizontal` | 原 `:1370-1378`：`|Δx| ≥ 40 && 横向速度 ≥ 100` → `handleHorizontalSwipe(startedAtPagingEdge: true)` → `switchPhoto` | **本卡唯一有意的行为变化**：该分支改为 `return false`（`testIC074R2OneXHorizontalDragEndDoesNotSwitchPhoto`：显示/隐藏两态横向结束均 false 且 `currentIndex`、`state` 不变；竖向分支上滑仍标记待删） |
| 3 | `:2841 scrollViewDidEndDragging` → `:2849 handleOneXVerticalGestureIfNeeded`（guard `.oneX` 且 `.vertical`）→ `:2960 completeMainDrag` | 外层分页容器竖向拖动 | `.oneX` | `.vertical`（确定） | 只进竖向分支 | 不受影响 |
| 4 | `:2855` / `:2851` → `finishNativePaging` → `:2984 reportSequenceBoundaryAttemptIfNeeded`（`.horizontal` 且目标越界）→ `:3029 handleHorizontalSwipe(startedAtPagingEdge: true)` | 序列首/尾继续横向拖动后回弹 | 通常 `.oneX`；nX 可达性未证实（③） | `.horizontal` | 目标越界 ⇒ `switchPhoto` 必为 false | 不受影响 |

**捏合过滤删除不改行为的证明（①出厂值）**：`8acf43d` 的 `factoryPlaceholder.pinchMinimumVelocityPerSecond = 0`、`pinchMaximumDurationMilliseconds = 0`；原判定 `peakVelocity >= 0` 恒真，`durationIsAllowed(maximumMilliseconds: 0)` 按 `maximumMilliseconds == 0 || …` 恒真，故 `accepted` 恒为 true，与现在的常量 `accepted: true` 等价。

**闸门 B**：CI #121 除新增断言外无任何既有测试失败（422 项 0 失败），未触发。

## 被删除 / 被修改的测试

- **删除 2 个**（唯一断言对象均为废止参数 `screenshotImmersiveOnHide`）：`testS5DisabledScreenshotImmersiveDoesNotChangeHiddenGeometry`、`testS6ScreenshotImmersiveFactoryDefaultIsTrue`。没有为 1x 水平分支删除测试——该分支此前没有任何测试覆盖。
- **修改**（只删除引用废止参数的行或按新签名迁移，其余断言保持）：`testV5ParametersSurviveProcessModelRestart`（去掉 `fitInsetScope` 赋值）、fitInsetRatio 内缩测试（去掉 `inset.fitInsetScope = .allPhotos`）、`testD1…`（去掉 `insetApplies` 断言与 scope 赋值）、`testD3…`、`testD5…`（去掉 scope 赋值）、`testL7FactoryDefaultsMatchSystemParityDecision`（期望构造去掉 15 项、`taskID` 改本卡、去掉 `screenshotImmersiveOnHide=true` 导出断言）、`testIC067C5ParameterConnectionStatusesCoverEveryFieldExactlyOnce`（`status` → `wiringStatus`，断言对象改为保留参数）、`S2StateMachineTests.parameters` 夹具（去掉四项）。
- **新增 4 个**：`testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`、`testIC074G97ParameterRegistryDecidedSetMatchesV15`、`testIC074R2OneXHorizontalDragEndDoesNotSwitchPhoto`、`testIC074R2NxEdgePagingThresholdsUnchanged`。
- 计数：420 − 2 + 4 = **422**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G95 | 满足① | 15 个废止名 + `S2FitInsetScope` + `S2GestureExclusivityPolicy`（另含 `insetApplies`）在 `PhotoCleanupMVE/` 与 `PhotoCleanupMVETests/` 的 `git grep -c` 全部为 0 |
| G96 | 满足① | 字段 33（`var` 行计数与 `Mirror` 断言）；导出 37 行；含 `schemaVersion=2`、`specBaseline=SPEC-S2-20260821_v15`——`testIC074G96…` |
| G97 | 满足① | 登记表 33 条，每条 `specStatus` + `wiringStatus`；decided 集合恰为卡内 16 项，placeholder 17——`testIC074G97…`；C5 仍断言名称集合与字段一一对应 |
| G98 | 满足① | 采用**报告逐项对照表**（见 change-list「出厂值对照」），脚本比对 `8acf43d` 与 HEAD 的 `factoryPlaceholder` 33 行逐字相同（0 行差异）；`testL7…` 以字面值再断言一次 |
| G99 | 满足① | 上表；正反断言函数名：`testIC074R2OneXHorizontalDragEndDoesNotSwitchPhoto`、`testIC074R2NxEdgePagingThresholdsUnchanged` |
| G100 | 满足① | `selfcheck.ps1` 退出码 0（目录条目 165 = 产品引用 165，无孤儿键）；`scan-hardcoded-user-visible-strings.ps1` 退出码 0；`git diff --check` 退出码 0 |
| G101 | 满足① | CI #121 全部既有测试通过（含 IC-063 G1～G12、IC-064 G13～G25、IC-065 G26～G35、IC-067 G36～G46、IC-069 G53～G60、IC-070 G75～G79；B3 与 IC047-038 的 Nx 贴边阈值断言亦通过） |
| G102 | 满足① | CI #121（id `32547367035`）success；被测 `7a8a8fa75ecf6122d897a34c955e4960dd05a3bf`；`Executed 422 tests, with 0 failures (0 unexpected) in 38.534 (67.580) seconds`；「运行 XCTest」及全部 9 步 success，真实退出码 0；IPA `PhotoCleanupMVE-unsigned.ipa` 689627 字节，SHA-256 `f4f396c08d1bdada673bcb077501cda594cf78a44cf46272f754af53acdf604a`，artifact `PhotoCleanupMVE-unsigned-7a8a8fa75ecf` 已下载并本地 `sha256sum` 复核一致 |
| G103 | 满足① | `<top>/CLAUDE.md` 第 122 行已改为 v15 基线；`grep -c 0051DF90…` = 1，`grep -c CEAE2A0F` = 0；其余 150 行未动 |
| H24 | 保留给 Lynn 真机判定 | 面板两列状态、导出可分享、既有交互无回归、Nx 贴边翻页无回归、1x 竖滑中途变横松手不再切页 |

## 报告提交方式

拿到 CI #121 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-074/`，不触发 CI）。

## 发现但未处理

1. `Scripts/verify-IC-20260815-060.ps1`、`061.ps1` 仍引用废止参数名（按卡不动，不在 CI 路径）。
2. 导出格式 `schemaVersion=2` 后，旧版 Keychain/UserDefaults 中含废止键的持久化数据在解码时会按 `CodingKeys` 忽略未知键、缺失的新键按既有 `decodeIfPresent` 默认值处理——`testV5` 覆盖的是新写新读；旧数据升级路径未实测（模拟器无旧数据），标注未覆盖。
