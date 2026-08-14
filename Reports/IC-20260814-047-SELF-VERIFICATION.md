# IC-20260814-047 自验报告

## 一、任务与结论

- 任务 ID：`IC-20260814-047-s2-viewer-impl`
- 上游证据任务：`IC-20260814-043`、`IC-20260814-045`、`IC-20260814-046`
- 任务基线：`480ef52b7c9fb4bf34077d00f2ff2f4edad923e4`
- 权威输入：`SPEC-S2-20260813.v13.md`
- 输入 SHA256：`25741959F965B8D9438F7265745D70EE60339A6865E1763BDE71912782BED1D8`

已在 MVE 中新增 S2 六状态状态机、六状态照片查看页、底部横栏、五个 Demo 几何函数及 41 个专项 XCTest。状态与手势层为本卡重写，没有复制 `CalibrationModel` 的状态管理；S2 没有接入现有导航，没有修改 `SessionStore`、S1/S3/S4/S5 状态机或其测试，也没有引入动画、调参面板、联网或账号能力。

任务正文同时出现“CI 全绿方可完成”和末尾“完成即停，不触发 CI”。本次按最后的完成后动作执行：**CI 未触发**，本地也未提交、未推送。因当前 Windows 主机没有 Xcode，本报告不把静态检查冒充为 XCTest 运行、Release 构建或未签名 IPA 产出；这三项保持“未执行”，不写成通过。

## 二、输入与来源审查

| 输入 | 核对结果 |
|---|---|
| `SPEC-S2-20260813.v13.md` | SHA256 与任务卡完全一致。 |
| `GestureViewport.swift` | SHA256 `E49B74D50CC1119CAE340BC7666E44904D19E95491291D607DB5A52853874379`。 |
| `CalibrationModel.swift` | SHA256 `DD179BE2D81C68437F21C2C42B467CF31C83271962D88FF95DB56A0A836F7BB8`。 |

两个 Demo 文件均已全文审查。`GestureViewport.swift` 只含本地 SwiftUI 手势和几何运算；`CalibrationModel.swift` 另含 Demo 状态、照片库读取入口、延迟点击裁决及本地 JSON 导出。没有发现向外部地址发送数据的代码。本卡只移植纯几何函数，不执行 Demo，不复制其状态、调参、照片请求或导出逻辑；两个来源文件摘要在专项脚本中冻结。

## 三、实现对应

### 1. 六状态、连续倍数与迁移表

`S2StateMachine.swift` 定义：

| 状态 | 正交变量 |
|---|---|
| S2-1 | 界面显示、`s = 1`、横栏静止 |
| S2-2 | 界面显示、`s = 1`、横栏滑动 |
| S2-3 | 界面隐藏、`s = 1` |
| S2-4 | 界面显示、`s > 1`、横栏静止 |
| S2-5 | 界面显示、`s > 1`、横栏滑动 |
| S2-6 | 界面隐藏、`s > 1` |

`s` 是唯一存储的缩放状态，`S2ZoomState` 每次由 `s == 1` 或 `s > 1` 派生。`transitionRule(for:from:)` 穷举 v13 第四节 21 个事件行和页面外加六状态共七列；动态条件用 `conditional` 或 `dynamic` 明示，不把未定边界反馈伪装成已决策值。

### 2. 手势矩阵与完整捏合链路

`gestureRule(for:context:)` 穷举第五节 12 个输入行和 `1x`、`Nx`、sheet 三列，共 36 格。实际输入顺序落实为：sheet 遮挡优先，其次横栏独占，再次捏合独占，最后按由 `s` 派生的 `Z` 分层。

捏合链路包含：

- `beginPinch()` 取得当前触摸序列所有权；
- `updatePinch` 按捏合起始倍数连续计算 `s`，硬钳到 `[1, pinchMaxScale]`；
- 捏合期间单击、双击、主图上滑、下滑、左右翻页、操作条和横栏起始均被状态机拒绝；
- `endPinch` 对严格低于 `zoomSnapBackThreshold` 的 `s` 归位到严格等于 `1`，否则保留并钳制视口；
- 全链路不写 `V`，所以捏合造成的 `1x/Nx` 变化保持当前界面显隐；
- SwiftUI 手势组合使用独占关系，未使用并发触发同一触摸序列的实现。

### 3. 页面、操作条与底部横栏

`S2View.swift` 提供主图视口、返回入口、范围与当前状态、会话合并待删纯数字徽标、收藏、历史相簿、加入相簿、相簿角标和底部横栏。它只接收内容构建闭包，不实现 PhotoKit 图像请求，因此没有替未定项 8 选择逐次请求、节流或降质图策略。

`S2BottomStripView` 实现：

- 静止态当前项为正方形，邻居为矩形，并使用注入的间隔和边缘渐隐尺寸；
- 滑动态全部项目为等距矩形且不使用当前项尺寸强调；
- 定位跨项时立即更新 `c` 与主图；
- 从 Nx 起拖且尚未换片时保留 `s`，首次换片立即令新照片 `s = 1` 并迁到 S2-2；
- 横栏拖动序列由横栏独占；
- 每项把 `D` 成员关系传给内容构建闭包并同步提供待删可访问性值，未替未定项 18 选择正式视觉形式。

操作条异步请求携带点击时的目标资产 `x`。测试覆盖先翻页、后完成收藏或历史相簿写入时，结果仍作用于原资产。相簿成功结果维护去重有序 `G(a)`、更新 `H`，并在目标属于 `D` 时原子移除；收藏不改变 `D`。相簿 sheet 呈现期间，状态机拒绝全部底层输入。

页面离开时 `makeExitPayload()` 同时形成五字段 `SessionStore.S2Return` 和本地续接快照 `{A, c, D, 范围显示信息}`。保存介质与时机仍由未定项 10 决定，本卡没有修改 `SessionStore` 或接线。

### 4. 几何算法来源

| 函数 | 来源任务 | 移植说明 |
|---|---|---|
| `aspectFitSize` | `IC-20260812-007-s2-gesture-calibration` | 仅把 `model.currentAsset.aspectRatio` 改为显式参数；原分支与公式保留。 |
| `aspectFillMultiplier` | `IC-20260812-022-demo-aspect-fill-zoom` | 宽高比商的较大值公式保留。 |
| `doubleTapAnchorOffset` | `IC-20260812-007`、`IC-20260813-033` | 屏幕中心、本次触点、上次触点及触点移至中心四个公式保留；策略值不设默认。 |
| `panLimits` | `IC-20260812-007-s2-gesture-calibration` | 原缩放内容边界公式保留；按 v13 删除余量参数，余量固定为零。 |
| `clampedOffset` | `IC-20260812-007-s2-gesture-calibration` | 两轴 `min(max())` 钳制公式保留。 |

源码在每个函数前分别标注来源任务号。专项测试以确定尺寸逐项断言五个函数，包括四种锚点、`s = 1` 零边界、`s = 2` 边界及双轴钳制。

### 5. 第二次补充：初始化顺序修复

CI #27 的编译错误原文为：

```text
/Users/runner/work/PhotoCleanupMVE/PhotoCleanupMVE/PhotoCleanupMVE/Core/S2StateMachine.swift:622:23: error: 'self' used in property access 'currentIndex' before all stored properties are initialized
```

修法：把既有 `firstIndex` 结果先保存到局部常量 `initialCurrentIndex`，再分别赋给 `currentIndex` 与 `farthestIndex`，避免在其他存储属性完成初始化前读取 `self.currentIndex`。索引值和后续赋值保持不变，不改变状态机语义。`S2StateMachine.swift` 相对受验提交 `9f744c57feca1f00480c98faa9620dca82a11138` 的完整 diff 如下：

```diff
diff --git a/PhotoCleanupMVE/Core/S2StateMachine.swift b/PhotoCleanupMVE/Core/S2StateMachine.swift
index 52c4946..dfb4d21 100644
--- a/PhotoCleanupMVE/Core/S2StateMachine.swift
+++ b/PhotoCleanupMVE/Core/S2StateMachine.swift
@@ -616,10 +616,11 @@ final class S2StateMachine: ObservableObject {
         viewportOffset = initialPresentation.scale == 1
             ? .zero
             : initialPresentation.viewportOffset
-        currentIndex = entry.orderedAssetIDs.firstIndex(
+        let initialCurrentIndex = entry.orderedAssetIDs.firstIndex(
             of: entry.currentAssetID
         ) ?? 0
-        farthestIndex = currentIndex
+        currentIndex = initialCurrentIndex
+        farthestIndex = initialCurrentIndex
         pendingDeletionAssetIDs = entry.pendingDeletionAssetIDs
         favoriteAssetIDs = initialFavoriteAssetIDs
         recentAlbum = initialRecentAlbum
```

## 四、v13 第九节未定项逐项占位

全部占位集中在 `S2StateMachine.swift` 的 `S2UndecidedItems`。该枚举只保存 `.unresolved`，不含产品参数值。为使状态机可测试，`S2ResolvedParameters` 要求未来调用方显式注入已决议值，且没有默认实例；测试和 SwiftUI 预览中的数字均标注为合成夹具，不是产品值或标定结果。

| 编号 | 集中占位 | 本卡处理 |
|---:|---|---|
| 1 | `item01InitialPresentation` | 构造器要求显式传入初始 `V`、`s`、offset，不提供默认初态。 |
| 2 | `item02LastAssetMarkOutcome` | 最后一张仍完成标记，但只记录待决编号，不实现落点或反馈。 |
| 3 | `item03SequenceBoundaryFeedback` | 无相邻照片时保持数据并记录待决编号，不实现反馈。 |
| 4 | `item04aPinchMaxScale`、`item04bZoomSnapBackThreshold`、`item04cAspectFillDegeneration`、`item04dDoubleTapAnchorStrategy`、`item04eEdgePagingThresholds` | 五个子项均无默认值；必须由 `S2ResolvedParameters` 显式注入。 |
| 5 | `item05GestureRecognition` | 距离、速度和捏合最小变化量均为显式注入；不设产品默认值。 |
| 6 | `item06BottomStripMetrics` | 项目尺寸、间隔、渐隐、拖动及换片距离均为显式注入；不设产品默认值。 |
| 7 | `item07CopyLayoutAndStyle` | MVE 文案在 String Catalog 中明确标为占位；未声明正式层级或视觉样式。 |
| 8 | `item08AssetLoadingAndRecovery`、`item08ScaleChangeRequestPolicy`、`item08DegradedPreviewPolicy` | `imageRequestStrategy` 保持可空；不实现具体请求，不选择每次 `s` 变化或节流，也不选择显示降质图或只显示最终图。 |
| 9 | `item09EmptyPendingPresentation` | 只保留语义数据和占位，不决定空集合入口样式。 |
| 10 | `item10SnapshotPersistence` | 只形成续接快照，不决定保存时机、介质、期限或视口恢复。 |
| 11 | `item11WriteFailureFeedback` | 写入失败保持基础数据并记录待决编号，不决定反馈与 sheet 自动关闭行为。 |
| 12 | `item12AlbumRemovalHint` | 只产生一次性语义通知，不决定形式、位置或时长。 |
| 13 | `item13AlbumHistoryDepth` | 只暴露当前 `H` 与会话内 `G` 所需语义，不决定跨会话历史条数。 |
| 14 | `item14AlbumHistoryPersistence` | 不持久化或主动清理历史相簿引用。 |
| 15 | `item15InFlightControls` | S2 不持有写服务的进行中策略，不决定重复点击或相互禁用。 |
| 16 | `item16AlreadyContainedCopy` | 已包含与首次加入共用成功状态结果，不决定提示措辞差异。 |
| 17 | `item17AlbumBadgePresentation` | 只形成规格锁定的相册名及 `+N` 内容，不决定正式视觉形式、尺寸和截断。 |
| 18 | `item18BottomStripMarkPresentation` | 向横栏内容闭包传递 `isMarked`，不决定正式标记视觉。 |
| 19 | `item19AlreadyMarkedHint` | 重复上滑只产生一次性语义通知，不决定形式、位置或时长。 |

## 五、XCTest 静态计数与覆盖

| 统计项 | 数量 |
|---|---:|
| 基线 XCTest | 226 |
| 新增 XCTest | 41 |
| 静态 XCTest 总数 | 267 |

新增测试均位于 `PhotoCleanupMVETests/S2StateMachineTests.swift`：

| 编号范围 | 数量 | 覆盖 |
|---|---:|---|
| IC047-001 | 1 | 六状态可达性。 |
| IC047-002～022 | 21 | v13 第四节迁移表逐行；每行断言页面外加六状态七列，并对主要可达路径执行实际状态变更。 |
| IC047-023～034 | 12 | v13 第五节手势矩阵逐行；每行断言 `1x`、`Nx`、sheet 三格，共 36 格。 |
| IC047-035 | 1 | 捏合独占触摸序列。 |
| IC047-036 | 1 | 连续缩放、下限硬钳、上限钳制、松手吸附及 `V` 不变。 |
| IC047-037 | 1 | 双击从显示或隐藏进入与退出，恢复进入前显隐。 |
| IC047-038 | 1 | Nx 贴边翻页与横栏换片后 `s = 1`、offset 清零。 |
| IC047-039 | 1 | Nx 上滑、下滑标记语义失效。 |
| IC047-040 | 1 | Nx 单击对显隐、缩放、视口、`c`、`D` 均无影响。 |
| IC047-041 | 1 | 五个几何函数及零余量边界。 |

测试文件没有 `XCTSkip`。当前机器没有 `swift`、`swiftc` 或 `xcodebuild`，因此 267 是静态方法计数，不是本机运行结果。

## 六、范围保护与本地静态验收

### 1. 受保护 Git blob

以下文件的 HEAD blob 与工作树 blob 均要求等于任务基线；专项脚本逐项检查：

| Git blob | 受保护路径 |
|---|---|
| `17d36192898a3d584df37a7e3efaf9c088045789` | `PhotoCleanupMVE/Core/SessionStore.swift` |
| `2128c759f78ce69c4086cef11d4c88e800c08a24` | `PhotoCleanupMVE/Core/S1StateMachine.swift` |
| `dc85e9941b1e4d37b5b55d8dadd4c6d4732e98bc` | `PhotoCleanupMVE/Core/S3StateMachine.swift` |
| `38508e188d8efb022c2ec9082602e5358d9cd544` | `PhotoCleanupMVE/Core/S4StateMachine.swift` |
| `4683c137b912bc1b2bc01f0fd19238d0bf091059` | `PhotoCleanupMVE/Core/S5StateMachine.swift` |
| `7bb23d64b61a5c4b962d182f45cb26732126f571` | `PhotoCleanupMVETests/SessionStoreTests.swift` |
| `353db5ff045a374cf456c87d3b47de2b2c2c5155` | `PhotoCleanupMVETests/S1StateMachineTests.swift` |
| `091358b6a1d198b0fec4c3709db49694cef7b3ef` | `PhotoCleanupMVETests/S3StateMachineTests.swift` |
| `54740d5a74a9f958ac2534e188e1da763e7034a6` | `PhotoCleanupMVETests/S4StateMachineTests.swift` |
| `08916b1869dc920a02fda63543ae86a78a03d834` | `PhotoCleanupMVETests/S5StateMachineTests.swift` |
| `4256b4d3cef06ced2c0dcf8de5bc27b1ae039bb6` | `PhotoCleanupMVE/App/CleanupCoordinator.swift`，同时覆盖 `CleanupRoute`。 |

### 2. 九个交付改动路径

1. `.github/workflows/ci.yml`
2. `PhotoCleanupMVE.xcodeproj/project.pbxproj`
3. `PhotoCleanupMVE/Core/S2StateMachine.swift`
4. `PhotoCleanupMVE/Features/S2/S2View.swift`
5. `PhotoCleanupMVE/Info.plist`
6. `PhotoCleanupMVE/Localizable.xcstrings`
7. `PhotoCleanupMVETests/S2StateMachineTests.swift`
8. `Scripts/verify-IC-20260814-047.ps1`
9. `Reports/IC-20260814-047-SELF-VERIFICATION.md`

专项脚本要求改动集合与上述九项完全相同，且九项全部进入 Git 索引、`git ls-files --others --exclude-standard` 为零。本卡没有修改第三方依赖。

### 3. 静态验收结果

| 验收项 | 结果 |
|---|---|
| `Scripts/verify-IC-20260814-047.ps1` | 通过；236 项检查，0 项失败，退出码 0。 |
| 通用 `Scripts/selfcheck.ps1` | 通过。 |
| 用户可见硬编码残留 | 0。 |
| String Catalog 双向一致 | 109 个目录键与 109 个产品源码引用键一致；其中 S2 新增 19 个。 |
| 产品源码动画 API 命中 | 0。 |
| S2 具体图像请求 API 命中 | 0。 |
| S2View 外部产品源码引用 | 0；只存在同文件内六个预览引用。 |
| `ci.yml` | `timeout-minutes: 15`；还原该行后与基线逐字一致，`push` 触发保持。 |
| 未跟踪条目 | 0；九个交付路径均已加入 Git 索引。 |
| `git diff --check` | 通过。 |

## 七、权限、本地化与禁止项

- `NSPhotoLibraryUsageDescription` 已改为“用于读取和整理照片，并将你确认删除的照片移入系统‘最近删除’。”，明确覆盖删除用途；不存在 Demo 的“不修改照片库”表述。
- 所有 S2 用户可见文案均通过 `L10n.text` 引用 `Localizable.xcstrings`；通用扫描结果为用户可见硬编码残留 0。
- 产品源码中未引入动画 API，也没有调参面板。
- S2 没有调用 `PHImageManager`、`requestImage` 或 `PHImageRequestOptions`，未替未定项 8 作选择。
- 除 `S2View.swift` 内六个自身预览外，其他产品源码没有 `S2View` 引用；没有导航接线。
- `ci.yml` 只把作业 `timeout-minutes` 从 45 改为 15；`on: push:` 与其余工作流内容不变。

## 八、CI、提交与完成边界

| 项目 | 结果 |
|---|---|
| 受验修复提交 | `4d564832c57a1f199a1c5b4420e09e091a93a3dd`。 |
| Git commit | 已提交初始化顺序修复与报告第三节，提交说明为 `fix: 修复 S2 初始化顺序`。 |
| Git push | 已推送到 `origin/main`。 |
| CI | GitHub Actions 运行 [#29](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31818453530)，运行 ID `31818453530`，尝试次数 1；终态为 `completed / success`。 |
| 全量 XCTest | 实际执行 267 项，0 失败、0 unexpected；日志以 `** TEST SUCCEEDED **` 和“XCTest 已全部通过。”结束。 |
| 同类初始化顺序错误 | 修复后未再出现。 |
| Release 构建 | 成功；日志包含 `** BUILD SUCCEEDED **`，并通过无代码签名、无 `_CodeSignature`、无 `embedded.mobileprovision` 检查。 |
| 未签名 IPA | `PhotoCleanupMVE-unsigned.ipa` 生成成功，280845 字节，SHA-256 `c4702c7e2a2958c9de66391eeffab2bb10e9fe540210a86abb063755235923e3`；压缩完整性检查通过。 |
| GitHub 产物 | [PhotoCleanupMVE-unsigned-4d564832c57a](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31818453530/artifacts/9226047792)，产物 ID `9226047792`，上传归档 281015 字节，上传摘要 SHA-256 `6ea77708aec84824d4dbeb7bb94ddab65526ea198dd7990ec212366538d03e74`。 |
| 完整日志 | [运行与完整日志](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31818453530)；[作业日志](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31818453530/job/94825665184)。 |

CI 于 `2026-08-14T16:15:15Z` 创建，于 `2026-08-14T16:18:39Z` 更新为成功终态。第三节记录的初始化顺序修复是唯一 Swift 变更；XCTest 文件未变，静态与实际总数均为 267。除本次显式允许修改的 `S2StateMachine.swift` 与本报告外，其余七个原始交付路径的 Git blob 均与 `9f744c57feca1f00480c98faa9620dca82a11138` 一致；报告因第三节与本节的强制回填而必然不可能同时保持该基线 blob。
