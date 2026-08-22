# IC-076 自验报告（action-bar-wiring）

## 结论（先行）

R1～R4 完成，CI 一次通过（1/3）。分支 `feature/ic-076-action-bar-wiring` 自 `feature/ic-075-top-bar-and-marks` 尖 `c99b0da`（产品代码 = CI #122 被测 `d6de321`）切出，五个代码提交（R4、R2、R2 修正、R3、R1），最终被测 `eb7a43bc411cfa84575842415ec1ed72da010c62`。CI #123 success：XCTest **442 项、0 失败**（= 428 + 14 新增 − 0 删除），9 步全部 success（`test_status=0`，真实退出码 0），IPA 732531 字节。三个按钮在生产路径真正经 `PHPhotoLibrary.performChanges` 写入；in-flight 只禁用发起按钮；失败 toast 由状态机一次性事件驱动、时长 `feedbackToastDurationMilliseconds = 2000`；`H` 持久化到 `UserDefaults` 并在 `enterS2` 同步校验；相簿 sheet 为真实用户相册列表并按「选中 → 写入中 → 结果」处理；`.item11` 已删除。参数层 35 → 36，既有出厂值不变。闸门 A、B 均未触发。

**三处④实现取定，需技术负责人确认**（详见变更清单「占位值登记」）：(a) sheet 路径收到 `albumUnavailable` 时按失败处理（sheet 保持打开 + toast）并清除相同的 `H`；(b) sheet 写入中禁用整个 sheet 内容（含「取消」）并禁止交互关闭，而非只禁列表；(c) toast 在 `P=呈现` 时同时叠加在 sheet 底部，否则被 sheet 遮挡不可见。

H26 留给 Lynn 真机判定；H24/H25 顺延。

## 输入、继承与范围

- 任务卡 IC-20260822-076；SPEC-S2 v15 第二节第 2～4 部分、回写决策 29；Decision_log 第 121（`feedbackToastDurationMilliseconds=2000` ④）、122 条；IC-075 change-list 占位值登记格式；`PhotoDeletionService.swift` 写入模式参照。
- 开工前 `git status --porcelain` 为空；`git rev-parse origin/feature/ic-075-top-bar-and-marks` = `c99b0da1738c91757816d1ffc376d5fd44d340a3`，与卡一致。
- 范围边界：改动 `Services/`（两个新文件）、`App/CleanupCoordinator.swift`、`App/PhotoCleanupMVEApp.swift`、`Core/S2StateMachine.swift`、`Features/S2/S2View.swift`、`Features/S2/S2Calibration.swift`、`Localizable.xcstrings`、`pbxproj`（仅新增三个文件）与三个测试文件（一个新建）。未改加载态/图片请求策略/`S2TemporaryPhotoImageStrategy.swift`、`pinchMaxScale`/`debugAssetLimit`、顶部信息区/标记/脉冲、手势分层/居中/描边/过渡/截图判定/捏合接管/Nx 贴边翻页、sheet 呈现期间的底层输入规则、S1↔S2 契约与 `SessionStore`、`Info.plist` 与 `.readWrite`、既有出厂值、`Scripts/`、`ci.yml`、SPEC、Decision_log、S1、S3～S5、分支与 worktree；未新增 XCUITest；toast 不可交互、不承载成功反馈。

## 提交清单（按时间序）

| 提交 | 归属 | 内容 |
|---|---|---|
| `f789473` | R4 | `S2RecentAlbumStoring` + `S2UserDefaultsRecentAlbumStore`（键 `com.iphonephotomanagement.PhotoCleanupMVE.s2.recent-album`，值 `[id, name]`）；新测试文件 `S2ActionBarWiringTests.swift`（内含 `S2InMemoryRecentAlbumStore`）；`pbxproj` +2 文件 |
| `e783b7d` | R2 | `inFlightActions` / `isActionInFlight` / `beginFavoriteToggle` / `beginRecentAlbumAddition` / `beginAlbumPickerSelection` / `completeAlbumPickerSelection(_:album:outcome:)` / `S2FeedbackEvent` / `consumeFeedbackEvent` / init 参数 `recentAlbumDidChange`；删 `.item11`、`item11WriteFailureFeedback`、`reportAlbumPickerFailure`；`S2View` 仅做编译适配（`S2AlbumPickerActions` 去 `reportFailure`，select 改走新回调）；G116×4、G117×2 新增，IC047-017/018 改写 |
| `dcb5d84` | R2 修正 | 一行注释中文引号改「」——本地扫描把注释中的 `"…"` 判为字面量（同 IC-075 `1d0551a` 类型） |
| `50d4e2c` | R3 | 参数 `feedbackToastDurationMilliseconds = 2000`（decided/effective）；`S2FeedbackToastPresenter`（注入计时器）、`S2ActionBarPresentation`、`S2AlbumPickerListPresentation/View`；按钮 `.disabled` 绑定；toast 浮层（主视图 + sheet 底部）；sheet 写入中 `.disabled` 与禁止交互关闭；键 +4；L7/G96/G97 计数更新；R3×3、G114 新增 |
| `eb7a43b` | R1 | `PhotoAssetActionServicing` + `PhotoKitAssetActionService`（`performChanges` ×2；`PhotoAlbumAdditionPlan` 同步判定）；协调器持有服务与存储，`requestS2FavoriteToggle` / `requestS2RecentAlbumAddition` / `requestS2AlbumPickerSelection`、`s2UserAlbums`、`enterS2` 内 `validatedRecentAlbum()`；App 传入三个非默认回调与 `S2AlbumPickerListView`；`pbxproj` +1 文件；G115、G118（协调器）、R1 新增 |

五个提交各自可独立 cherry-pick；R2 的 `S2View` 编译适配是为了该提交自身可编译。

## 被删除 / 被修改的测试

- **删除：0 个**。
- **修改 5 个**：`testIC047_017TransitionRowAlbumSheetSuccess`（两参 complete → begin + 三参 complete）、`testIC047_018TransitionRowAlbumSheetFailure`（`.item11` → 反馈事件 1 次，`pendingUndecidedItem` 为 nil）、`testL7FactoryDefaultsMatchSystemParityDecision`（期望构造 +1）、`testIC074G96ConfigurationHasThirtyThreeFieldsAndV15Export`（36 / 40）、`testIC074G97ParameterRegistryDecidedSetMatchesV15`（36、decided +1 = 19）。
- **新增 14 个**（CI 日志逐一 passed）：`testIC076G116FavoriteInFlightDisablesOnlyItself`、`testIC076G116RecentAlbumInFlightDisablesOnlyItself`、`testIC076G116AlbumPickerInFlightDisablesOnlyItself`、`testIC076G116ResultAppliesToOriginalAssetAfterPaging`、`testIC076G117AlbumPickerOutcomesAndRecentAlbumCallback`、`testIC076G117RecentAlbumUnavailableClearsRecentAlbumWithoutFeedback`、`testIC076G118RecentAlbumStoreRoundTripsAndClears`、`testIC076R3ToastPresenterAppearsThenExpiresWithoutRealClock`、`testIC076R3ActionBarPresentationDisablesOnlyInFlightButton`、`testIC076R3HostedViewPresentsToastFromFeedbackEvent`、`testIC076G114AlbumPickerListPresentation`、`testIC076G115AdditionPlanSkipsWriteWhenAlreadyContained`、`testIC076G118EnterS2ClearsPersistedRecentAlbumWhenAlbumMissing`、`testIC076R1CoordinatorWiresThreeActionsThroughServiceAndStore`。
- 计数：428 + 14 = **442**，与 CI 一致。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G114 | 满足① | `git grep`：`PhotoCleanupMVEApp.swift` 第 90/93/98 行传入 `onFavoriteRequest`、`onRecentAlbumRequest`、`onAlbumPickerSelection` 非默认闭包；第 76 行 `albumPickerContent` 渲染 `S2AlbumPickerListView(albums: coordinator.s2UserAlbums())`。`testIC076G114AlbumPickerListPresentation`：两相册按给定顺序出行、空列表显示占位、标题/占位带前缀；列表视图可宿主并回调 select/cancel |
| G115 | 满足①（判定）/②（假服务） | `PhotoAssetActionService.swift` 含 `performChanges` 2 处（收藏、加入相册）；加入前 `PHAsset.fetchAssets(in:options:).contains(asset)` 同步判定。`testIC076G115…`：`PhotoAlbumAdditionPlan` 四分支；假服务（复用同一判定）已包含时 `writeCount == 0` 且返回 `success(alreadyContained: true)`；相册缺失 → `albumUnavailable`；资产缺失 → `failure`。**生产实现对 PhotoKit 的实际不重复写入未在 CI 覆盖，由 H26 判定** |
| G116 | 满足① | 四个 `testIC076G116…`：每个按钮进行中时自身 `make*Request` 为 nil、重复 `begin` 为 false；其余两个可请求；`makeExitPayload` 非 nil；单击/横栏拖动/双击可用；结果返回后标志清除。相簿选择进行中：底层仍按 `P=呈现` 规则阻断（卡明示"底层输入规则不变"），结果返回后 sheet 关闭、底层恢复。翻页后：收藏作用于 `asset-2` 而非当前 `asset-3`；历史相册把 `asset-2` 移出 `D`、`asset-3` 仍在 |
| G117 | 满足① | `testIC076G117AlbumPickerOutcomesAndRecentAlbumCallback`：failure → `H` nil、`D` 不变、sheet 仍开、事件 1、无持久化回调；同一 sheet 重选 success → `H` 更新（回调 1 次）、`x ∈ D` 移出、sheet 关闭、事件计数不变；albumUnavailable → `H` 清除（回调 nil）。`testIC076G117RecentAlbumUnavailable…`：历史相册路径 albumUnavailable 清除 `H`、不发事件、`D` 不变 |
| G118 | 满足① | `testIC076G118RecentAlbumStoreRoundTripsAndClears`：写入 → 同 suite 重建 → 读回一致；清除后读回为空；空 id 视为清除。`testIC076G118EnterS2ClearsPersistedRecentAlbumWhenAlbumMissing`：存储有值且服务 `albumExists=false` → `enterS2` 后 `s2Machine.recentAlbum` nil、存储被清（`saveCount 1`）、校验查询了该 id；存在 → 注入且存储未动；无值 → 不查询 |
| G119 | 满足① | `grep -rn item11` 在 `S2StateMachine.swift`、`Features/S2`、`App`、`PhotoCleanupMVETests` 命中 0（S1 的 `item11SessionPersistenceAndEnd` 为 S1 内部标识，S1 禁改，未动）；字段 36、导出 40 行、登记表 36、decided 19（`testIC074G96…`/`G97…`）；IC-075 的 35 个出厂值逐项未改（L7 字面值断言只追加一行；`git diff` 只有追加行） |
| G120 | 满足① | 本分支新增 4 个用户可见字符串均以"【未定项 21 占位】"开头（`git diff c99b0da -- Localizable.xcstrings` 的 4 行 `value`）；扫描：目录 166 = 引用 166，无孤儿键；`selfcheck.ps1` 退出码 0、`scan-hardcoded-user-visible-strings.ps1` 退出码 0、`git diff --check` 退出码 0 |
| G121 | 满足① | CI #123 日志中 `testIC063…` 10、`IC064` 6、`IC065` 7、`IC067` 8、`IC069` 6、`IC070` 6、`IC074` 4、`IC075` 6 个测试均 passed、0 failed（日志计数为双份，已折半） |
| G122 | 满足① | CI #123（id `32551590511`）success；被测 `eb7a43bc411cfa84575842415ec1ed72da010c62`；`Executed 442 tests, with 0 failures (0 unexpected) in 15.383 (36.783) seconds`；`test_status=0`、9 步全部 success；IPA `PhotoCleanupMVE-unsigned.ipa` 732531 字节，SHA-256 `5216d3cec6fb0a06c4d34cdcb5ee0bffb4de27ad85b01632d6342e04710fa964`（CI `::notice` 报告值），artifact `PhotoCleanupMVE-unsigned-eb7a43bc411c` 经 `gh run download` 本地 `sha256sum` 复核一致；被删测试 0 个 |
| 闸门 A | 未触发① | 未改 `SessionStore`、S1 契约、`Info.plist` |
| 闸门 B | 未触发① | "已包含"判定用 `PHFetchResult.contains`，同步、本地元数据查询；③ 成本随相册资产数线性但不涉及 I/O 加载，真机可在 H26 观察大相册的点击延迟 |
| H26 | 保留给 Lynn | — |

## 定案落实与取定值

- 写入服务：`PhotoAssetActionServicing`（切换收藏 / 加入相册 / 用户相册列表 / 相册存在性）；生产 `PhotoKitAssetActionService`；完成回调可在任意线程，协调器 `deliverOnMain` 送回主线程（主线程上同步交付，便于断言）；结果作用于 `request` 绑定的 `x`，并校验 `s2Machine === machine`，离开 S2 后到达的结果丢弃（`testIC076R1…` 末段）。
- 授权：沿用 `.readWrite` 的 `.authorized / .limited` 判定，未授权时收藏返回失败、加入相册返回 `.failure`（真机飞行模式/拒绝权限 → toast，H26）。
- in-flight：`Set<S2ActionBarButton>`；`S2ActionBarPresentation` 把横栏拖动的整条禁用与单按钮禁用合并为每按钮启用态。
- `H`：`UserDefaults` 键见上；`enterS2` 同步校验；状态机每次 `H` 变化经 `recentAlbumDidChange` 持久化（成功加入两条路径与 `albumUnavailable` 清除）。
- toast：`S2FeedbackToastPresenter`，`generation` 计数保证旧事件到期不清除新事件；视图 `onChange(of: machine.feedbackEvent)` 消费；`allowsHitTesting(false)`。
- 相簿 sheet：`S2AlbumPickerListView`（标题、`List` 或空态一行、「取消」）；写入中整块 `.disabled` + `interactiveDismissDisabled`。

## 报告提交方式

拿到 CI #123 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-076/`，不触发 CI）。

## 发现但未处理

1. `exportText()` 的 `taskID` 仍为 IC-074（IC-075 已报告，本卡未要求更新）。
2. `S2UndecidedItems.item13～item16` 四个占位常量对应的未定项已在 v15 定案并由本卡实装，卡只要求删 `.item11`，其余未动；`item17/item18` 同 IC-075 报告。
3. `S2TransitionEvent.selectAlbumAndWriteFails` 等迁移表事件名仍为两段式语义，未按三段改名（不在卡内）。
4. 三处④取定见「结论」。
