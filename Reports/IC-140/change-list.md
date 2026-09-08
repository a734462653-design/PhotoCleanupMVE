# IC-140 变更清单：实况播放（到页短动效、长按全段、手势挂起）

- 基线：`main` = `8eebac1280cb9d697a88a5c7b62368c36bb864e1`（IC-142 报告提交）
- 分支：`feature/ic-140-live-photo-playback`
- 范围：只做实况（LivePhoto）。不引 `AVPlayer`，视频页零行为改动（IC-141）。

---

## 一、提交清单

| 序 | SHA | 子项 | 触及文件 |
|---|---|---|---|
| 1 | `921ea1e` | A · reducer 与协调器骨架 | `Features/S2/S2LivePhotoPlayback.swift`（新）、`Features/S2/S2View.swift` |
| 2 | `ae44b79` | B · 宿主视图与页内包装 | `Features/S2/S2LivePhotoPlayback.swift` |
| 3 | `8ce30b5` | C · 分页器四处 | `Features/S2/S2NativePhotoPager.swift`、`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` |
| 4 | `a998a9e` | D · S2View 接线 | `Features/S2/S2View.swift`、`PhotoCleanupMVETests/IC139MediaBadgesTests.swift` |
| 5 | `12268a4` | E · 断言测试、pbxproj 登记与收尾 | `PhotoCleanupMVETests/IC140LivePhotoPlaybackTests.swift`（新）、`PhotoCleanupMVE.xcodeproj/project.pbxproj`、上述两个 S2 文件 |
| 6 | `5bfdd91` | 修 #275 红（编译） | `Features/S2/S2LivePhotoPlayback.swift`、`PhotoCleanupMVETests/IC140LivePhotoPlaybackTests.swift` |
| 7 | `4ca8770` | 修 #276 红（夹具） | `PhotoCleanupMVETests/IC140LivePhotoPlaybackTests.swift` |

**与卡内「五个子项各自独立 commit」的两处偏离（如实登记）**

1. **A 的提交同时改了 `S2View.swift`**：`S2MediaMetrics` 的两个新登记常量落在那里，而 A 的 reducer（`retentionSet`）编译期就要读 `livePhotoInstanceCap`。取值表属 A 的交付物，故与新文件同提交。
2. **第 6、7 个提交**是两次 CI 红的修正（#275 编译、#276 夹具），卡内未预留；按「三次 CI 上限」的两次修复计，产品代码在第 7 次提交里未动。C 的提交同时改了 `S2CalibrationHarnessTests.swift` 的 T1 四处（机械跟随，不跟随则整棵测试树编不过）。

卡内已注明「B～E 消费 A 的类型，不许诺可单独 cherry-pick」；A～D 各自单独不含 pbxproj 登记，单独 checkout 不构成可编译树，符合卡内约定。

---

## 二、新增文件

### `PhotoCleanupMVE/Features/S2/S2LivePhotoPlayback.swift`（新，769 行）

| 类型 | 角色 |
|---|---|
| `S2LivePhotoPlaybackState` | 单张资产播放态：`idle` / `requesting` / `ready` / `playingHint` / `playingFull` / `failed` |
| `S2LivePhotoPlaybackStyle` | 播放口径两态，`isMuted` 为模型字段（hint = true、full = false） |
| `S2LivePhotoPlaybackEvent` | `entered` / `becameCurrent` / `pagingSettled` / `requestSucceeded` / `requestFailed` / `longPressBegan` / `longPressEnded` / `playbackEnded` |
| `S2LivePhotoPlaybackEffect` | `request` / `cancelRequest` / `playHint` / `playFull` / `stop` / `unload` |
| `S2LivePhotoPlaybackMachine` | 纯值类型 reducer，按 assetID 记键 |
| `S2LivePhotoPlaybackSurface` | 协调器与播放层之间的唯一接口（4 个方法） |
| `S2LivePhotoPlaybackCoordinator` | 效果执行与 `PHImageManager` 接线；`ObservableObject`，**无 `@Published`**，不触发视图刷新 |
| `S2LivePhotoHostView` | 承载 `PHLivePhotoView`，做 `PHLivePhotoViewDelegate` |
| `S2LivePhotoPlaybackContentView` | `UIViewRepresentable`，页内容树里的播放层 |
| `S2LivePhotoLayerPresentation` | 挂载口径，`make(mediaKind:)` 仅 `.live` 非 nil |

**卡内事件签名的两处具体化（如实登记）**

- `entered(assetID:)` 与 `becameCurrent(assetID:neighbours:)` 的 `assetID` 取 `String?`：**nil = 当前页不是实况**。这样状态机内部不需要任何媒体类别判别（判别谓词仍只有 `AssetSizeProbeService.mediaKind(of:)` 一处），也能表达「翻到照片页 ⟹ 停前页」。
- `requestFailed` 与 `requestSucceeded` 同形带 `(assetID:generation:)`；卡内事件表只写了名字。

### `PhotoCleanupMVETests/IC140LivePhotoPlaybackTests.swift`（新，18 个测试函数）

覆盖断言 1～10、12。断言 11 在自验报告里核（两函数体 SHA-256），断言 13 由既有全量测试覆盖。

---

## 三、修改文件

### `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`（限定四处）

10 个 diff hunk，逐个对号（行号为分支 tip 上的新文件行号）：

| hunk | 新行范围 | 对应 | 内容 |
|---|---|---|---|
| 1 | `+92,7` | (b)(d) | P3 声明：`onLongPress: () -> Void` → `onLongPressBegan: () -> Bool`、`onLongPressEnded: () -> Void`、`onPagingSettled: () -> Void` |
| 2 | `+137,3` | (b)(d) | P3 透传：`updateUIViewController` 里三个实参 |
| 3 | `+2879,7` | (b)(c)(d) | P3 存储：三个可选闭包 + `isLongPressSuspending`（挂起态唯一来源） |
| 4 | `+2939,2` | (a) | P1 `minimumPressDuration` 由 `0.8` 改引用 `S2MediaMetrics.longPressMinimumDuration` |
| 5 | `+2995,3` | (b)(d) | P3 `apply(...)` init 形参 |
| 6 | `+3004,3` | (b)(d) | P3 赋值 |
| 7 | `+3213,3` | (b)(d) | P3 释放（`resetInteractionState`） |
| 8 | `+3755,37` | (b)(c) | P2 `handleLongPress` 三态分派 + `beginLongPressSuspensionIfNeeded()` |
| 9 | `+3794,13` | (c) | `endLongPressSuspension()` + `currentPageController` |
| 10 | `+4024,3` | (d) | P4 `finishNativePaging()` 末尾 `onPagingSettled?()` |

**未触碰**：P8 两个快照函数（两侧函数体 SHA-256 相同，见自验报告）、几何链 `writePhotoGeometry`（出现次数仍为 **5**）、`hostingController`（`private let` 与 3 个 `configure(contentView:)` 调用点一字未动）。

### `PhotoCleanupMVE/Features/S2/S2View.swift`

| 处 | 变更 |
|---|---|
| S3 | 删 `S2LivePhotoLongPressRecorder`（类定义 + `@StateObject`），改 `@StateObject private var livePlayback = S2LivePhotoPlaybackCoordinator()` |
| S1 | 分页器构造：`onLongPress:` → `onLongPressBegan:` / `onLongPressEnded:` / `onPagingSettled:` 三个实参 |
| S2 | `handleMainPhotoLongPress()` 改返回 `Bool`；`.livePhotoPlayback` → `livePlayback.longPressBegan()`，`.unbound` → `false` |
| S4 | `.onChange(of: machine.currentAssetID)` 末尾加 `notifyLivePlaybackOfCurrentPage()`；`.onAppear` 加 `enter` + `becameCurrent`；`.onDisappear` 加 `leave()` |
| S5 | `content: AnyView(content)` → `content: AnyView(photoContentWithPlaybackLayer(assetID:baseSize:content:))` |
| S6 | `currentMediaKind` 不变 |
| S7 | `S2MediaMetrics` 新增 `livePhotoPrefetchRadius = 1`、`livePhotoInstanceCap = 3`；`longPressMinimumDuration` 值不变（0.8），注释改为「两只识别器共用」 |
| 新增 | `liveCurrentAssetAndNeighbours()`、`notifyLivePlaybackOfCurrentPage()`、`photoContentWithPlaybackLayer(...)`（陷阱 16：新构造外提为 builder） |

### `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`

T1 四处（1767、2210、2360、10354）`onLongPress: {}` → `onLongPressBegan: { false }` + `onLongPressEnded: {}` + `onPagingSettled: {}`。机械替换，无语义变化。

### `PhotoCleanupMVETests/IC139MediaBadgesTests.swift`

删 `testIC139D_LivePhotoLongPressRecordsOncePerPress`（记录器已不存在），原位留注释指向替代覆盖。IC-139 断言 9（`testIC139D_CalibrationPanelToggleLeavesTheMainPhotoLongPressPath`）原样保留并继续通过。

---

## 四、占位值登记

**本卡不新增、不修改任何 `S2CalibrationConfiguration` 字段，`schemaVersion` 仍为 7。**

新增两个常量落在**视觉登记制容器 `S2MediaMetrics`**（`S2View.swift`），与 IC-139 同一容器，不进标定面板、不进出厂值集合：

| 常量 | 值 | 依据 |
|---|---|---|
| `S2MediaMetrics.livePhotoPrefetchRadius` | `1` | 卡内取值表（③ 决策会话取定，非视觉量，H64b 后可调） |
| `S2MediaMetrics.livePhotoInstanceCap` | `3` | 同上 |
| `S2MediaMetrics.longPressMinimumDuration` | `0.8`（**值未变**） | 既有；本卡只把分页器那只识别器改为引用它，两处 0.8 归一 |

---

## 五、范围边界确认（G812）

以下文件在 `8eebac1..HEAD` 的 diff 中**零命中**：

`Features/S2/S2Calibration.swift`、`Core/S2StateMachine.swift`、`Services/AssetSizeScanner.swift`、`Features/S1/S1View.swift`、`Features/S3/S3View.swift`、`Features/S4/S4View.swift`、`Features/S5/S5View.swift`、`Localizable.xcstrings`、`App/PhotoCleanupMVEApp.swift`、`App/CleanupCoordinator.swift`。

`App/PhotoCleanupMVEApp.swift` 未改，印证卡内预期：播放层挂在 `S2View.pageContent` 内，App 侧 `photoContent:` 闭包不需要新实参。

冻结三链与探针分支 tip 未变：`feature/ic-089-nx-edge-bounce` = `b368a6c`、`feature/ic-091-nx-midgesture-handoff` = `6736f1e`、`feature/ic-092-nx-window-follow` = `a7cc1ec`、`probe/ic-067-screenshot-subtype` = `9db02b9`。**未 cherry-pick、未合并 IC-137 探针分支。**

---

## 六、pbxproj 登记

加登记前重扫最大对象 id（IC-134 撞号教训）：`PBXFileReference` 前缀 `1…` 最大 `10000000000000000000003E`；`PBXBuildFile` 前缀 `2…` 最大 `20000000000000000000003B`。四个新号在全文件的出现次数均为 0（登记前扫描），登记后各出现应有次数。

| 对象 | id | 落位 |
|---|---|---|
| `S2LivePhotoPlayback.swift` fileRef | `10000000000000000000003F` | `PBXFileReference` 区段第 116 行；S2 组第 253 行 |
| `S2LivePhotoPlayback.swift` buildFile | `20000000000000000000003C` | `PBXBuildFile` 区段第 40 行；**应用源码阶段**（`400000000000000000000001`）第 461 行 |
| `IC140LivePhotoPlaybackTests.swift` fileRef | `100000000000000000000040` | `PBXFileReference` 区段第 117 行；测试组第 316 行 |
| `IC140LivePhotoPlaybackTests.swift` buildFile | `20000000000000000000003D` | `PBXBuildFile` 区段第 41 行；**测试源码阶段**（`400000000000000000000004`）第 496 行 |

两段 `files = (` 的命中行原文见自验报告第七节。
