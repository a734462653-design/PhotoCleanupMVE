# IC-076 变更清单

分支 `feature/ic-076-action-bar-wiring`，自 `feature/ic-075-top-bar-and-marks` 尖 `c99b0da` 切出（产品代码 = CI #122 被测 `d6de321`）。最终被测提交 `eb7a43bc411cfa84575842415ec1ed72da010c62`（CI #123，442 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `f789473` | R4 | `Services/S2RecentAlbumStore.swift`（新）、`S2ActionBarWiringTests.swift`（新）、`pbxproj` | `S2RecentAlbumStoring` 协议 + `UserDefaults` 实现；测试用内存实现随测试文件；G118 存储断言 |
| `e783b7d` | R2 | `Core/S2StateMachine.swift`、`S2View.swift`（仅适配编译：`S2AlbumPickerActions` 去掉 `reportFailure`、select 改走 `onAlbumPickerSelection`）、`S2StateMachineTests.swift` | in-flight 集合与查询；`begin*` 三个登记入口；相簿选择三段；`S2FeedbackEvent` 发布与消费；`recentAlbumDidChange` 回调；删 `.item11`；G116×4、G117×2 新增，IC047-017/018 改写 |
| `dcb5d84` | R2 修正 | `Core/S2StateMachine.swift` | 一行注释的中文引号改「」——字符串目录扫描器把注释里的 `"…"` 当字面量（本地扫描暴露，与 IC-075 `1d0551a` 同类） |
| `50d4e2c` | R3 | `S2Calibration.swift`、`S2View.swift`、`Localizable.xcstrings`、`S2ActionBarWiringTests.swift`、`S2CalibrationHarnessTests.swift` | `feedbackToastDurationMilliseconds = 2000`（字段/出厂/校验/导出/登记/编解码）；`S2FeedbackToastPresenter`、`S2ActionBarPresentation`、`S2AlbumPickerListPresentation/View`；按钮 `disabled` 绑定；toast 浮层（主视图与 sheet 各一处）；sheet 写入中 `.disabled`；键 +4；L7/G96/G97 计数更新；R3×3、G114 新增 |
| `eb7a43b` | R1 | `Services/PhotoAssetActionService.swift`（新）、`App/CleanupCoordinator.swift`、`App/PhotoCleanupMVEApp.swift`、`pbxproj`、`S2ActionBarWiringTests.swift` | `PhotoAssetActionServicing` 协议与 `PhotoKitAssetActionService`；`PhotoAlbumAdditionPlan` 同步判定；协调器持有服务与存储，三个 `requestS2*` 方法，`enterS2` 校验 `H`；App 传入三个非默认回调与 `S2AlbumPickerListView`；G115、G118（协调器）、R1 新增 |

提交顺序 R4 → R2 → R3 → R1：R2 的状态机 API 是 R3 视图与 R1 协调器的前提；R4 独立。`pbxproj` 只因三个新文件改动（两处产品源码、一处测试源码）。

## 产品行为变化

- 收藏按钮：点击 → 状态机登记进行中并绑定 `x` → `PhotoKitAssetActionService.toggleFavorite`（`performChanges` 写 `isFavorite`）→ 成功切换 `favorite(x)` 无提示；失败显示底部 toast。进行中该按钮禁用，其余按钮、主图手势、横栏、返回与确认页入口照常。
- 「加入"<相册名>"」：同上流程，`addAsset(toAlbumWithID:)`；成功更新 `H`（持久化）并在 `x ∈ D` 时静默移出；失败 toast；目标相册已不存在 → `H` 清除（含持久化）、按钮消失、无提示。
- 「加入相簿」sheet：内容为用户相册列表（`.album`/`.albumRegular`，系统返回顺序，每项显示相册名），空列表显示占位文案，含「取消」。选中 → sheet 进入写入中（整块内容 `.disabled`，交互关闭亦禁用）→ 成功：更新 `H`、`x ∈ D` 静默移出、关闭 sheet；失败：sheet 保持打开、列表恢复、toast（toast 同时叠加在 sheet 底部以保证可见）；目标相册已不存在：与之相同的 `H` 清除 + 按失败处理（④ 实现取定，卡未写明 sheet 路径该结果的 sheet 行为）。
- 写入前同步判定"已包含"：`PHAsset.fetchAssets(in:options:).contains(asset)`（本地元数据），已包含时不调用 `performChanges`，返回 `success(alreadyContained: true)`，与首次加入走同一成功路径、无提示。
- `H` 持久化：`UserDefaults` 键 `com.iphonephotomanagement.PhotoCleanupMVE.s2.recent-album`，值为 `[id, name]` 字典；`enterS2` 读取并用 `albumExists` 同步校验，不存在则清除。
- toast：底部短 toast，`feedbackToastDurationMilliseconds`（出厂 2000）；不接收点击（`allowsHitTesting(false)`）；同一时刻一条，新事件替换旧事件，旧事件到期不清除新事件。
- 结果作用于 `x`：写入期间翻页，结果仍作用于点击时的资产；离开 S2 后到达的结果被丢弃（协调器校验 `s2Machine === machine`）。
- 删除：`S2UndecidedItem.item11`、`S2UndecidedItems.item11WriteFailureFeedback`、`S2StateMachine.reportAlbumPickerFailure`、`S2AlbumPickerActions.reportFailure`；`pendingUndecidedItem` 其余条目不动。

## 状态机 API 变化（供下游卡参考）

- 新增：`inFlightActions`、`isActionInFlight(_:)`、`albumPickerSelectionInFlight`、`beginFavoriteToggle(_:)`、`beginRecentAlbumAddition(_:)`、`beginAlbumPickerSelection(_:album:)`、`completeAlbumPickerSelection(_:album:outcome:)`、`feedbackEvent`、`feedbackEventCount`、`consumeFeedbackEvent()`、init 参数 `recentAlbumDidChange`（默认空闭包）。
- 改变：`makeFavoriteToggleRequest()` / `makeRecentAlbumAdditionRequest()` 在对应按钮进行中时返回 nil；`completeFavoriteToggle` 失败时发 `.favoriteWriteFailed`；`completeRecentAlbumAddition(.failure)` 发 `.albumAdditionFailed` 而非写 `.item11`。
- 删除：`completeAlbumPickerSelection(_:album:)`（两参）、`reportAlbumPickerFailure(_:)`。

## 本地化键

+4（全部带"【未定项 21 占位】"前缀）：`s2.album_picker.title`、`s2.album_picker.empty`、`s2.feedback.favorite_failed`、`s2.feedback.album_addition_failed`。目录条目 162 → 166，与产品引用一致（无孤儿键）。`s2.action.cancel` 复用。

## 参数层

字段 35 → 36、导出 39 → 40 行、登记表 36 条（decided 19、placeholder 17）。新增定案参数 `feedbackToastDurationMilliseconds = 2000`（规格状态 decided、接线 effective，值来自 Decision_log 第 121 条④）。IC-075 的 35 个出厂值未改（L7 字面值断言只追加一行）。

## 测试

- 新增 14 个：`S2StateMachineTests` 6 个（`testIC076G116FavoriteInFlightDisablesOnlyItself`、`testIC076G116RecentAlbumInFlightDisablesOnlyItself`、`testIC076G116AlbumPickerInFlightDisablesOnlyItself`、`testIC076G116ResultAppliesToOriginalAssetAfterPaging`、`testIC076G117AlbumPickerOutcomesAndRecentAlbumCallback`、`testIC076G117RecentAlbumUnavailableClearsRecentAlbumWithoutFeedback`）；`S2ActionBarWiringTests`（新文件）8 个（`testIC076G118RecentAlbumStoreRoundTripsAndClears`、`testIC076R3ToastPresenterAppearsThenExpiresWithoutRealClock`、`testIC076R3ActionBarPresentationDisablesOnlyInFlightButton`、`testIC076R3HostedViewPresentsToastFromFeedbackEvent`、`testIC076G114AlbumPickerListPresentation`、`testIC076G115AdditionPlanSkipsWriteWhenAlreadyContained`、`testIC076G118EnterS2ClearsPersistedRecentAlbumWhenAlbumMissing`、`testIC076R1CoordinatorWiresThreeActionsThroughServiceAndStore`）。
- 修改 5 个：`testIC047_017TransitionRowAlbumSheetSuccess`（改走 begin/complete 三段）、`testIC047_018TransitionRowAlbumSheetFailure`（断言反馈事件而非 `.item11`）、`testL7FactoryDefaultsMatchSystemParityDecision`（期望构造 +1 参数）、`testIC074G96…`/`testIC074G97…`（36/40/36、decided 19）。
- 删除 0 个。计数 428 + 14 = 442。

## 未变更

加载态/失败态/降质预览/图片请求策略/`S2TemporaryPhotoImageStrategy.swift`；`pinchMaxScale`、`debugAssetLimit`；顶部信息区、徽标、主图与横栏标记、脉冲；手势分层、居中、描边、过渡动画、截图判定、捏合接管、Nx 贴边翻页、sheet 呈现期间的底层输入规则（`P=呈现` 仍阻断底层全部输入）；S1 ↔ S2 交接契约与 `SessionStore`（`H` 未进入）；`Info.plist` 与 `.readWrite` 授权级别；既有 35 个出厂值；`Scripts/`、`ci.yml`、SPEC、Decision_log、S1、S3～S5；分支与 worktree；未新增 XCUITest。

## 占位值登记（本卡新增或变更的占位值）

> 格式沿用 IC-074/075：项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡。

| 项 | 当前值 | 接线状态 | v15 对应条款 / 去向 | 登记来源卡 |
|---|---|---|---|---|
| `feedbackToastDurationMilliseconds`（定案参数，非占位） | 2000 | effective | v15 回写决策 29；Decision_log 第 121 条④可修订 | IC-076 |
| toast 文案 ×2、sheet 标题、列表空态文案 | 见本地化键，带"【未定项 21 占位】"前缀 | effective | 未定项 21，待 Lynn 一次给齐 | IC-076 |
| toast 视觉（字号 `.subheadline`、胶囊 `.regularMaterial` 背景、距底部安全区 8pt） | 实现取定 | effective | 未定项 7/21 视觉稿范围 | IC-076 |
| sheet 路径 `albumUnavailable` 的 sheet 行为 | 与 `.failure` 相同：sheet 保持打开 + toast，并清除相同的 `H` | effective | 卡只写"albumUnavailable 结果也清除 H"；④待技术负责人确认 | IC-076 |
| sheet 写入中禁用范围 | 整个 sheet 内容（含「取消」）+ 禁止交互关闭 | effective | 卡写"列表禁用"；取消一并禁用以避免写入中关闭 sheet 的竞态，④待确认 | IC-076 |
| `UserDefaults` 键名 | `com.iphonephotomanagement.PhotoCleanupMVE.s2.recent-album` | effective | 卡要求"键名由实现定并写入报告" | IC-076 |
