# IC-077 变更清单

分支 `feature/ic-077-image-loading-states`，自 `feature/ic-076-action-bar-wiring` 尖 `10ff08b` 切出（产品代码 = CI #123 被测 `eb7a43b`）。最终被测提交 `14c8c8057f5e4b6b9dc5c8f12717fd5237da877b`（CI #124，449 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `890b5cf` | R1 | `S2TemporaryPhotoImageStrategy.swift`、`S2Calibration.swift`、`S2CalibrationHarnessTests.swift`、`S2ImageLoadingStateTests.swift`（新）、`pbxproj` | `S2ImageRequestResult` 五态；协议 `resultHandler: (S2ImageRequestResult) -> Void`；`isNetworkAccessAllowed = true`、`deliveryMode = .opportunistic`；`fetchAssets` 为空 → `assetUnavailable`；`PHImageCancelledKey` → `cancelled`；`degradedPreviewPolicy` 出厂 `.display`；两项请求策略登记为 decided；文件头注释改指 v15 决策 28；`S2ImageRequestCounter`/L7/G97/R2 测试适配；R1、G124 新增 |
| `8035ffe` | R2 | `S2TemporaryPhotoImageStrategy.swift`、`S2View.swift`、`S2Calibration.swift`、`Localizable.xcstrings`、`S2ImageLoadingStateTests.swift` | `S2ImageLoadState`（loading / displayed / failed）与 `onLoadStateChange`；加载中背景改为 `S2ViewportBackground.color`；失败态浮层（`photo.badge.exclamationmark` + 一行占位文案，`allowsHitTesting(false)`）；`S2ImageReturnType` +`cancelled`、`assetUnavailable`；`S2ViewportBackground` 单一定义并由 `S2View` 复用；预览描边 `Color.white → Color.primary`；键 +3；G126×2 新增 |
| `7d3b3ef` | R3 | `Core/S2StateMachine.swift`、`S2ImageLoadingStateTests.swift` | `requestImageAfterScaleSettled()`：双击进入/退出到达目标倍率时在 `pinchEnded` 策略下递增一次 `imageRequestRevision`（原状：0 次请求，见下）；G127、R3 新增 |
| `14c8c80` | R4 | `S2ImageLoadingStateTests.swift` | 交接校验失败断言（产品侧现状已满足，`CleanupCoordinator.swift` 未改） |

`pbxproj` 只因新增一个测试文件改动。

## 产品行为变化

- 图片请求：允许网络访问（④ Lynn 2026-08-22，iCloud 按需下载，下载期间为加载中）；`.opportunistic` 交付——降质预览先显示，最终图到达后原位替换（同一 `Image` 视图替换 `uiImage`，照片 frame / `contentSize` / `contentOffset` / `contentInset` 由原生容器持有，不随替换改变）。
- 出厂 `degradedPreviewPolicy = .display`（本卡显式授权的唯一出厂值变更）；`scaleChangeRequestPolicy = .pinchEnded` 不变；两者规格状态 placeholder → decided。
- 加载中：主图显示 `S2ViewportBackground.color`（= `UIColor.systemBackground`，深黑／浅白语义色），不显示进度指示；`Color.black` 硬编码移除。
- 失败态 / 资产失效：请求以 `failure` 或 `assetUnavailable` 结束且该照片无可显示图像时，在照片内容区中心显示 `photo.badge.exclamationmark` 与一行文案，无重试控件；该照片的标记、取消标记、翻页、缩放照常（状态机不读取加载态）。已有图像时更高分辨率请求失败不进入失败态（保留已显示图像）。取消（翻页导致）不记读数、不进入失败态。
- 请求节流：捏合中 `s` 连续变化 0 次；捏合结束 1 次；双击到达目标倍率 1 次（**原状**：出厂 `pinchEnded` 策略下双击只改变请求 key，被当作 `scaleChange` 忽略，实测 0 次，本卡在状态机补递增）；翻页新进窗口的页 1 次、离开窗口的页旧请求取消；视口尺寸变化当前页 1 次。
- 交接校验失败：`enterS2` 返回 `false` 时 `route == .s1`、`s2Machine == nil`、S1 状态机与会话存储不变——现状已满足，只补断言。

## 本地化键

+3（均带"【未定项 21 占位】"前缀）：`s2.image.load_failed`（失败/失效一行文案）、`s2.calibration.reading.return.cancelled`、`s2.calibration.reading.return.asset_unavailable`（标定面板读数标题）。目录条目 166 → 169，与产品引用一致。

## 参数层

字段 36、导出 40 行、登记表 36 条不变；decided 19 → 21、placeholder 17 → 15。出厂值仅 `degradedPreviewPolicy` 变更；其余 35 项与 `eb7a43b` 逐项相等（`git diff eb7a43b HEAD -- S2Calibration.swift` 只含该行与登记表两行及 `S2ImageReturnType` 两个新 case）。

## 测试

- 新增 7 个（`S2ImageLoadingStateTests.swift`）：`testIC077R1RequestResultCoversFiveOutcomes`、`testIC077G124FactoryImageStrategyAndRegistry`、`testIC077G126HostedImageViewShowsDegradedThenFinalAndFailureStates`、`testIC077G126FailureStateKeepsSwipeUpMarkingAndPaging`、`testIC077G127RequestThrottlingAcrossPinchDoubleTapPagingAndViewport`、`testIC077R3DoubleTapBumpsImageRequestRevisionOncePerSettle`、`testIC077G128HandoffValidationFailureStaysInS1`。
- 修改 4 个：`S2ImageRequestCounter`（协议签名适配）、`testL7FactoryDefaultsMatchSystemParityDecision`（`.display`）、`testIC074G97ParameterRegistryDecidedSetMatchesV15`（decided 21 / placeholder 15）、`testR2PinchDoesNotReplaceWithDegradedPreview`（期望 `[.degradedPreview, .finalImage]`，注释改写）。
- 删除 0 个。计数 442 + 7 = 449。

## 未变更

`pinchMaxScale`、`debugAssetLimit`；操作条、toast、`H`、sheet；顶部信息区、徽标、标记；手势分层、居中、描边、过渡动画、截图判定、捏合接管、Nx 贴边翻页；S1 → S2 契约、`SessionStore`、`Info.plist`；类型名与文件名；`S2ImageRequestStrategy` 以外的出厂值；`Scripts/`、`ci.yml`、SPEC、Decision_log、S1、S3～S5；分支与 worktree；未新增 XCUITest、未新增参数。

## 占位值登记（本卡新增或变更的占位值）

> 格式沿用 IC-074～076：项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡。

| 项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| `degradedPreviewPolicy`（placeholder → decided） | `.display` | effective | v15 回写决策 28 | IC-077 |
| `scaleChangeRequestPolicy`（placeholder → decided） | `.pinchEnded` | effective | v15 回写决策 28 | IC-077 |
| 失败态文案 | `s2.image.load_failed`，带前缀 | effective | 未定项 8 残项 / 21 | IC-077 |
| 失败态视觉（`.largeTitle` 符号、`.footnote` 文案、`.secondary` 色、间距 8pt、置于照片内容区中心） | 实现取定 | effective | 未定项 7/21 视觉稿范围；失败态随照片内容区一起缩放（④ 实现取定，见自验报告） | IC-077 |
| 标定面板读数标题 ×2（`cancelled`、`asset_unavailable`） | 带前缀 | effective | 诊断面板文案，未定项 21 | IC-077 |
| 双击请求信号复用 `pinchEnded` 触发器标签 | 读数面板把双击请求记为 `pinchEnded` | effective | 实现取定；改名需新增触发器与键，留后续清理卡 | IC-077 |
