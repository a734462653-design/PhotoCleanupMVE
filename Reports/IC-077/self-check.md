# IC-077 自验报告（image-loading-states）

## 结论（先行）

R1～R4 完成，CI 两次通过（2/3）。分支 `feature/ic-077-image-loading-states` 自 `feature/ic-076-action-bar-wiring` 尖 `10ff08b`（产品代码 = CI #123 被测 `eb7a43b`）切出，五个代码提交（R1、R2、R3、R4、R3 测试修正），最终被测 `03bd062fcd3fc2296559cc1ce8d893615f8a2a01`。CI #125 success：XCTest **449 项、0 失败**（= 442 + 7 新增 − 0 删除），9 步全部 success（`test_status=0`，真实退出码 0），IPA 738730 字节。未定项 8 的定案已落到生产图片路径：允许网络访问、`.opportunistic` 降质先显示、失败态/资产失效态浮层、取消不计失败、交接校验失败停留 S1（现状已满足，补断言）、按 `s` 的请求节流（双击路径原状为 0 次请求，本卡补齐）。加载背景的硬编码黑色移除，视口背景收敛到 `S2ViewportBackground` 单一定义。闸门 A 未触发：IC-063～IC-070 全部几何门禁在 CI #125 通过。

**第一次 CI（#124，被测 `14c8c80`）失败**：唯一失败项为 G127 夹具——宿主整张 `S2View` 时图片视图 0 次请求（12 条计数断言全为 0），其余 448 项通过。本机无 Xcode 无法定位，改用既有已验证的原生分页控制器夹具并按 `S2View.mainPhoto` 的页窗口规则自建页列表后通过。"宿主整张 S2View 时 `S2TemporaryPhotoImageView` 不发起请求"记为发现未处理项（③ 可能是 SwiftUI 宿主内 Representable 页内容的 `onAppear` 时机，需真机或模拟器调试确认；生产路径由 H27 判定）。

**三处④实现取定，需技术负责人确认**：(a) 失败态浮层位于照片内容区（随 `Nx` 缩放一起放大），`s=1` 时即视口中心；未放在 `S2View` 浮层是因为相邻页预加载失败时读数不经状态机，页内状态才能正确显示；(b) 已有可显示图像时更高分辨率请求失败不进入失败态（保留已显示图像）；(c) 双击到达目标倍率的请求信号复用 `pinchEnded` 触发器标签（读数面板把双击请求记为 `pinchEnded`），改名需新增触发器与键。

H27 留给 Lynn 真机判定；H24/H25/H26 顺延。

## 输入、继承与范围

- 任务卡 IC-20260822-077；SPEC-S2 v15 第二节共同不变量末两条、回写决策 24、28；Decision_log 第 121、122 条；IC-076 change-list 占位值登记格式。`Reports/IC-066/open-items-actual-values.md` 第 8 项：本地 grep 未命中相应条目（以卡内"问题证据"六条为准）。
- 开工前 `git status --porcelain` 为空；`git rev-parse origin/feature/ic-076-action-bar-wiring` = `10ff08b1eb63f1ed9110ce4d0f4a32b204ffa300`，与卡一致。
- 范围边界：改动 `S2TemporaryPhotoImageStrategy.swift`（类型名与文件名未改）、`S2Calibration.swift`、`S2View.swift`、`Core/S2StateMachine.swift`（仅双击请求信号）、`Localizable.xcstrings`、`pbxproj`（仅新增一个测试文件）与三个测试文件（一个新建）。`CleanupCoordinator.swift` 未改。未改 `pinchMaxScale`/`debugAssetLimit`、操作条/toast/`H`/sheet、顶部信息区/徽标/标记、手势分层/居中/描边/过渡/截图判定/捏合接管/Nx 贴边翻页、S1→S2 契约/`SessionStore`/`Info.plist`、`S2ImageRequestStrategy` 以外的出厂值；未新增参数、XCUITest、重试控件；未改 SPEC、Decision_log、S1、S3～S5、`Scripts/`、`ci.yml`。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `890b5cf` | R1 | `S2ImageRequestResult`（degradedPreview / finalImage / failure / cancelled / assetUnavailable）；协议 `resultHandler: (S2ImageRequestResult) -> Void`；`isNetworkAccessAllowed = true`、`deliveryMode = .opportunistic`；`fetchAssets` 为空 → `.assetUnavailable`；`PHImageCancelledKey` → `.cancelled`；`static result(image:information:)` 映射；出厂 `degradedPreviewPolicy = .display`；两项请求策略 placeholder → decided；文件头注释改指 v15 决策 28；新测试文件 + `pbxproj`；`S2ImageRequestCounter`/L7/G97/R2 测试适配 |
| `8035ffe` | R2 | `S2ImageLoadState` 与 `onLoadStateChange`；加载中背景 `S2ViewportBackground.color`（`S2View` 同一定义）；失败态浮层（`photo.badge.exclamationmark` + `s2.image.load_failed`，`allowsHitTesting(false)`）；`S2ImageReturnType` + `cancelled`、`assetUnavailable` 与读数标题；预览描边 `Color.white → Color.primary`；键 +3 |
| `7d3b3ef` | R3 | `S2StateMachine.requestImageAfterScaleSettled()`：双击进入/退出到达目标倍率时（`pinchEnded` 策略）递增一次 `imageRequestRevision`；G127（首版）、R3 测试 |
| `14c8c80` | R4 | G128 协调器断言（产品侧现状已满足，未改产品） |
| `03bd062` | R3 修正 | G127 改到 `S2CalibrationHarnessTests` 的原生分页控制器夹具，按 `S2View.mainPhoto` 页窗口规则（当前页 ±1）自建页列表 |

## 被删除 / 被修改的测试

- **删除：0 个**。
- **修改 4 个**：`S2ImageRequestCounter`（签名适配，行为不变）、`testL7FactoryDefaultsMatchSystemParityDecision`（期望 `.display`）、`testIC074G97ParameterRegistryDecidedSetMatchesV15`（decided 21 / placeholder 15）、`testR2PinchDoesNotReplaceWithDegradedPreview`（期望 `[.degradedPreview, .finalImage]`，注释改写为 v15 决策 28 语义）。
- **新增 7 个**（CI #125 逐一 passed）：`testIC077R1RequestResultCoversFiveOutcomes`、`testIC077G124FactoryImageStrategyAndRegistry`、`testIC077G126HostedImageViewShowsDegradedThenFinalAndFailureStates`、`testIC077G126FailureStateKeepsSwipeUpMarkingAndPaging`、`testIC077R3DoubleTapBumpsImageRequestRevisionOncePerSettle`、`testIC077G128HandoffValidationFailureStaysInS1`（以上 `S2ImageLoadingStateTests`）、`testIC077G127RequestThrottlingAcrossPinchDoubleTapPagingAndViewport`（`S2CalibrationHarnessTests`）。
- 计数：442 + 7 = **449**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G123 | 满足① | `grep -c "isNetworkAccessAllowed = true"` = 1、`= false` = 0（`S2TemporaryPhotoImageStrategy.swift`） |
| G124 | 满足① | `testIC077G124…`：`factoryPlaceholder.degradedPreviewPolicy == .display`、`scaleChangeRequestPolicy == .pinchEnded`；登记表 36、decided 21、placeholder 15；`git diff eb7a43b HEAD -- S2Calibration.swift` 的出厂值变更仅 `degradedPreviewPolicy` 一行，其余 35 项逐项相等（L7 字面值断言通过） |
| G125 | 满足①（一处说明） | `grep "Color.black\|Color.white\|UIColor.black\|UIColor.white"` 在 `Features/S2/` 与 `App/`：`S2TemporaryPhotoImageStrategy.swift` 的 `Color.black` 已移除、`S2View.swift` 预览 `Color.white` 改 `.primary`；剩余 2 处在 `S2NativePhotoPager.swift:2138/2142`——内缩态描边色（v15 回写决策 22 明确列出的白/黑 + alpha），描边属本卡禁改范围，未动。视口背景唯一定义处：`S2View.swift` `enum S2ViewportBackground`（`UIColor.systemBackground`，即 v15 决策 24 的深黑/浅白两值），`S2View` 与 `S2TemporaryPhotoImageView` 均复用 |
| G126 | 满足①（夹具驱动，真机未覆盖） | `testIC077G126HostedImageViewShowsDegradedThenFinalAndFailureStates`：pending → degraded 后加载态已为 `displayed`（降质已显示）→ final 读数到达、态不变；pending → failure / assetUnavailable → `failed`；cancelled → 无读数、态不变。`testIC077G126FailureStateKeepsSwipeUpMarkingAndPaging`：失败读数存在时 `completeMainDrag` 上滑标记生效并前进、翻页与下滑取消照常 |
| G127 | 满足①（夹具驱动） | `testIC077G127…`：捏合中 10 次 `reportNativeViewport` 0 次请求；`finishNativePinch` 1 次；双击退出 1 次、双击进入 1 次；翻页后新进窗口页 1 次、成为当前页的页 0 次新增、总新增 1、离开窗口页的请求标识在 `cancelledIDs` 中；视口尺寸变化当前页 1 次。**原状**：双击路径 0 次请求（CI #124 之前以状态机层 `testIC077R3…` 与代码阅读确认——`handleNativeDoubleTap` 只改 `imageRequestScale`，视图按 `scaleChange` 触发器忽略），已修正 |
| G128 | 满足① | `testIC077G128HandoffValidationFailureStaysInS1`：`D ⊄ A` → `enterS2` 为 false、`route == .s1`、`s2Machine == nil`、`s1Machine` 同一对象、`sessionStore` 与 S1 的 `sessionStore` 相等、`message` 为 nil；随后合法交接进入 S2 |
| G129 | 满足① | 新增 3 个用户可见字符串均以"【未定项 21 占位】"开头（`git diff 10ff08b HEAD -- Localizable.xcstrings` 的 3 行 `value`）；目录 169 = 引用 169，无孤儿键；`selfcheck.ps1` 0、`scan-hardcoded-user-visible-strings.ps1` 0、`git diff --check` 0 |
| G130 | 满足① | CI #125 日志：`testIC063…` 10、`IC064` 6、`IC065` 7、`IC067` 8、`IC069` 6、`IC070` 6、`IC074` 4、`IC075` 6、`IC076` 14 均 passed、0 failed（日志双份已折半） |
| G131 | 满足① | CI #125（id `32554654578`）success；被测 `03bd062fcd3fc2296559cc1ce8d893615f8a2a01`；`Executed 449 tests, with 0 failures (0 unexpected) in 22.276 (31.768) seconds`；`test_status=0`，9 步 success；IPA `PhotoCleanupMVE-unsigned.ipa` 738730 字节，SHA-256 `9d53674b16be8323106150e85185d7fe9607198a89a273696b8c5df50c43f010`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-03bd062fcd3f` 经 `gh run download` 本地 `sha256sum` 一致；被删测试 0 个。CI #124（`14c8c80`）failure：`Executed 449 tests, with 12 failures`，全部来自 `testIC077G127…` 的计数断言（值均为 0），其余 448 项通过 |
| 闸门 A | 未触发① | IC-063～IC-070 的 G 系列几何门禁在 CI #125 全部通过；降质/最终替换只改 `Image(uiImage:)` 内容，照片几何由原生容器持有；失败态浮层 `allowsHitTesting(false)` 且不改布局 |
| H27 | 保留给 Lynn | — |

## 定案落实与取定值

- 网络：`isNetworkAccessAllowed = true`（④ Lynn 2026-08-22）；`deliveryMode = .opportunistic`；`resizeMode .fast`、`version .current` 不变。
- 结果区分：`S2ImageRequestResult` 五态；生产映射 `PHImageCancelledKey` → cancelled、无图像 → failure、`PHImageResultIsDegradedKey` → degradedPreview、其余 → finalImage；`fetchAssets` 为空 → assetUnavailable。
- 三态：`S2ImageLoadState`；请求开始时若该资产已有图像保持 `displayed`，否则 `loading`；结果无图像 → 已有图像则保留、否则 `failed`；取消不改态。
- 失败态浮层：`photo.badge.exclamationmark`（`.largeTitle`）+ `s2.image.load_failed`（`.footnote`、单行），`.secondary` 色，居中于照片内容区，`allowsHitTesting(false)`；仅主图路径（`showsOpaqueLoadingBackground == true`）显示，横栏缩略图不显示。
- 视口背景：`S2ViewportBackground.uiColor = UIColor.systemBackground`；主图与加载中背景共用。
- 节流：状态机 `requestImageAfterScaleSettled()` 在 `pinchEnded` 策略下于双击进入/退出时递增 `imageRequestRevision`；`everyScaleChange` 策略下不递增（由倍率变化本身触发）。

## 报告提交方式

拿到 CI #125 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-077/`，不触发 CI）。

## 发现但未处理

1. 宿主整张 `S2View` 的测试中 `S2TemporaryPhotoImageView` 0 次请求（CI #124）；既有 IC-063/075/076 的 S2View 宿主测试均不依赖图片请求，因此此前未暴露。③ 需在模拟器/真机定位；若生产路径同样不请求，H27 会直接暴露。
2. `S2NativePhotoPager.swift:2138/2142` 描边色仍以 `UIColor.white/black + alpha` 写出（v15 决策 22 明确值，描边禁改）。
3. 双击请求信号的读数触发器标签为 `pinchEnded`（取定 c）。
4. `exportText()` 的 `taskID` 仍为 IC-074；`S2UndecidedItems.item08*` 三个占位常量对应的未定项已由本卡实装，未删（卡未要求）。
5. `S2ImageRequestDecision.shouldDisplay` 与 `degradedPreviewPolicy = .finalImageOnly` 分支仍可经标定面板切换，本卡未删除该选项（卡未要求）。
