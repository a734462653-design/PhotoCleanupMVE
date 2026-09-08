# IC-139 变更清单

- 继承提交：`main` = `db318fc7f9cb9e94c4ead6a5edbb4ab493eb0bef`
- 分支：`feature/ic-139-media-badges`，代码 tip `564a5f39bbec7bc8b9fb1f82f7e4a9f5e20d6885`
- **合并提交：`fd7c983` / `fd7c9831dfb8f5febc101f287fa587c92ce6259f`**
  - parent1 `db318fc7f9cb9e94c4ead6a5edbb4ab493eb0bef`（原 `main`）
  - parent2 `564a5f39bbec7bc8b9fb1f82f7e4a9f5e20d6885`（分支 tip）
  - `Merge made by the 'ort' strategy.`，**零冲突**；合并树对象
    `192a078bd3a322386397780cdc89cba81835c909` 与分支 tip 树对象相同
- 推送报文：`db318fc..fd7c983  main -> main`（两点记法，非强推），退出码 0

## 提交链（5 个，未 rebase／未 amend）

| 提交 | 子项 | 内容 | 可单独 cherry-pick |
|---|---|---|---|
| `90832bc` | A | 媒体类别与实况胶囊 | **是** |
| `bf3d5d3` | B | 视频浮框骨架 | 否——依赖 A 的 `S2MediaKind`／`S2MediaMetrics` |
| `5a3b188` | C | 视频页几何下缘上移 68 | 否——依赖 A 的 `assetMediaKind` 与 B 的 `videoBarHeight`／`videoBarBottomToStripTop` |
| `564a5f3` | D | 长按分派改派 | 否——依赖 A 的 `currentMediaKind` |
| `fd7c983` | — | **本卡合并提交**（`--no-ff`） | — |

四个子项共用 `S2View.swift`，故按块拆分逐阶段重建；每一阶段单独校验过
括号配平、无悬空符号、`selfcheck.ps1` 与硬编码扫描退出码 0。
B／C／D 无法脱离 A 单独 cherry-pick 属卡内分解方式的固有约束（三者都消费
A 定义的 `m`），不是拆分手法所致——详见 self-check。

## 文件级变更（`db318fc..fd7c983`，6 文件 +1126 −117）

| 文件 | +/− | 子项 |
|---|---|---|
| `PhotoCleanupMVETests/IC139MediaBadgesTests.swift`（新） | +510 −0 | A／B／C／D |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | +431 −4 | A／B／C／D |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | +124 −113 | A（抽 builder + 加实参） |
| `PhotoCleanupMVE/Localizable.xcstrings` | +44 −0 | A（1 键）／B（3 键） |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | +13 −0 | A |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | +4 −0 | A（新测试文件登记） |

**`PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` 不在 diff 中**，
两侧 SHA-256 同为
`344cfcd525ad58d7ff3e80c923c37621d08833b9122116695305cb95caeb54c4`。
**`PhotoCleanupMVE/Features/S2/S2Calibration.swift` 亦不在 diff 中。**

`PhotoCleanupMVEApp.swift` 的 −113 全部是内联 S2 构造被整段外提为
`s2Screen(machine:)`（陷阱 16），不是删除。

## pbxproj 对象 id 扫描（IC-134 撞号教训）

登记前重扫（`project.pbxproj` 全表）：

| 段 | 条目数 | 当前最大 id |
|---|---:|---|
| `PBXBuildFile` | 57 | `20000000000000000000003A` |
| `PBXFileReference` | 60 | `10000000000000000000003D` |
| 两段 id 交集 | — | **无** |

本卡取下一个空号：fileRef `10000000000000000000003E`、
buildFile `20000000000000000000003B`。登记后逐 id 复查出现次数：
fileRef **3 次**（声明 + 组 children + buildFile 引用）、
buildFile **2 次**（声明 + Sources 构建阶段），与既有文件同形，无重号。

## A · 媒体类别与实况胶囊

### 新增

| 位置 | 成员 |
|---|---|
| `CleanupCoordinator.swift` | `func s2AssetMediaKind(for:) -> S2MediaKind`（只读，形状照 `s2AssetIsScreenshot`） |
| `S2View.swift` | `enum S2MediaKind { photo, live, video }` + `init(probeKind:)` |
| `S2View.swift` | `enum S2MediaMetrics`（登记制常量容器） |
| `S2View.swift` | `struct S2LivePillPresentation` + `make(mediaKind:interfaceVisibility:)` |
| `S2View.swift` | `private let assetMediaKind: (String) -> S2MediaKind`（init 参数**带默认值** `{ _ in .photo }`） |
| `S2View.swift` | `private var currentMediaKind`、`mediaChromeLayer(bottomStripHeight:safeAreaInsets:)`、`livePill(_:)` |
| `PhotoCleanupMVEApp.swift` | `private func s2Screen(machine:) -> some View` |

**判别谓词零重写**：`s2AssetMediaKind` 映射自
`AssetSizeProbeService.mediaKind(of:)`（`Services/AssetSizeScanner.swift:286`，
全仓唯一判别处），协调器不自带 `mediaType`／`photoLive` 判断。

**挂载方式**：`mediaChromeLayer` 作为 `interfaceOverlay` 的 ZStack 第四个
兄弟层。ZStack 子层互不影响布局，顶排、横栏、操作条三层的帧与锚点一字未动；
显隐由外层 `.s2ChromeVisibilityTransition` 统一施加，本层不自造语汇。

## B · 视频浮框骨架

| 位置 | 成员 |
|---|---|
| `S2View.swift` | `struct S2VideoBarPresentation` + `make(...)` |
| `S2View.swift` | `videoBar(_:)`、`videoBarTrack(progress:)` |
| `S2View.swift` | `S2MediaMetrics.videoBarBottomFromViewportBottom(safeAreaBottom:bottomStripHeight:)` |

三件（播放图标、进度轨含拖动圆点、静音图标）本卡恒为
`play.fill` / 填充 0 / `speaker.slash.fill`，`allowsHitTesting(false)`。

**陷阱 14**：浮框底缘锚**不复用** `S2OverlayLayout.stripTopFromViewportBottom`
——那条推导式内含 `max(minimumTouchTarget, 横栏高)` 的触控带下限。
浮框锚的是眼睛看到的横栏顶缘，故直接用传入的横栏视觉带高。

## C · 视频页几何

| 位置 | 成员 |
|---|---|
| `S2View.swift` | `struct S2MediaPageFit`、`enum S2MediaPageGeometry.videoPageFit(...)` |
| `S2View.swift` | `S2MediaMetrics.videoPageFitBottomInset`（推导量 = 44 + 24） |
| `S2View.swift` | `pageContent(index:viewportSize:)` 内新增 `mediaFit` / `fittedSize` / `fittedCenterY` 三个局部量 |

**改动的三处赋值**（全部在 `pageContent` 内）：

| 处 | 改前 | 改后 |
|---|---|---|
| `S2ImageContentContext.fittedSize` | `pageMetrics.oneXDisplaySize` | `fittedSize` |
| `S2NativePageContent.fittedSize` | `pageMetrics.oneXDisplaySize` | `fittedSize` |
| `S2NativePageContent.fittedCenterY` | `pageMetrics.oneXDisplayCenterY` | `fittedCenterY` |

`nativeZoomBaseSize` **未改**，Nx 基准与照片页一致。
非视频页与隐藏态 `videoPageFit` 返回 `nil`，两个局部量退回原值，几何零改动。

## D · 长按分派

| 位置 | 成员 |
|---|---|
| `S2View.swift` | `enum S2MainPhotoLongPressAction { livePhotoPlayback, unbound }` + `resolve(mediaKind:)` |
| `S2View.swift` | `final class S2LivePhotoLongPressRecorder: ObservableObject` |
| `S2View.swift` | `@StateObject private var livePhotoLongPress` |
| `S2View.swift` | `private func handleMainPhotoLongPress()` |
| `S2View.swift` | `S2MediaMetrics.longPressMinimumDuration`（0.8） |

**改动的两处**：

| 处 | 改前 | 改后 |
|---|---|---|
| `S2NativePhotoPager` 的 `onLongPress:` 闭包 | `calibrationOverlayState.toggleAccessControls()` | `handleMainPhotoLongPress()` |
| `topInfoArea`（顶部中胶囊） | 无长按 | `.onLongPressGesture(minimumDuration:)` → `toggleAccessControls()` |

**识别器本身一字未动**（装在分页器根视图，文件逐字节不变），只改闭包语义。
产品源码内 `toggleAccessControls()` 调用点仍恰为 **1 处**，已从主图长按迁到中胶囊。

## 取值表逐条落实（画布定稿 ④ / v19 §11.2）

| 常量 | 值 | 落实方式 |
|---|---:|---|
| `livePillTopFromTopBarBottom` | 24 | **引用** `S2OverlayLayout.stripToBottomRowSpacing` |
| `livePillHeight` | 28 | ④ 取定 |
| `livePillCornerRadius` | 14 | ④ 取定（表内以「圆角 14」给出） |
| `livePillLeading` | 16 | **引用** `S2OverlayLayout.chromeHorizontalMargin` |
| `livePillPaddingLeading` / `Trailing` | 8 / 10 | ④ 取定 |
| `livePillIconPointSize` | 13 | ④ 取定 |
| `livePillFontSize` | 12 | ④ 取定（半粗，`.semibold`） |
| `livePillItemSpacing` | 5 | ④ 取定 |
| `livePillSymbol` | `livephoto` | ④ 取定 |
| `videoBarHeight` | 44 | ④ 取定 |
| `videoBarCornerRadius` | 22 | ④ 取定（表内以「圆角 22」给出） |
| `videoBarHorizontalMargin` | 16 | **引用** `S2OverlayLayout.chromeHorizontalMargin` |
| `videoBarBottomToStripTop` | 24 | **引用** `S2OverlayLayout.stripToBottomRowSpacing` |
| `videoBarHorizontalPadding` | 14 | ④ 取定 |
| `videoBarItemSpacing` | 12 | ④ 取定 |
| `videoBarButtonIconPointSize` | 18 | ④ 取定 |
| `videoBarMuteIconPointSize` | 20 | ④ 取定 |
| `videoBarTrackHeight` | 4 | ④ 取定 |
| `videoBarTrackCornerRadius` | 2 | ④ 取定（表内以「圆角 2」给出） |
| `videoBarKnobDiameter` | 12 | ④ 取定，**本卡只画不接拖动** |
| `videoBarTimeFontSize` | 13 | ④ 取定，**本卡未使用**（表内注明 IC-141 用） |
| `videoBarTrackOpacity` | 0.28 | ④ 取定（表内以「轨白 28%」给出） |
| `videoPageFitBottomInset` | 68 | **推导量**，写作 `videoBarHeight + videoBarBottomToStripTop`，恒等式有断言 |

玻璃配方与前景：胶囊与浮框均用既有 `.s2ChromeGlassBackground(in:)` 与
`S2ChromeForeground.onGlassPrimary`（决策 42 自适应主色），不自造。

## xcstrings 新增键（4 条，目录 206 → 210）

| key | 值 | 子项 |
|---|---|---|
| `s2.media.live_badge` | 实况 | A |
| `s2.media.video_bar` | 视频播放控件 | B |
| `s2.media.video_mute` | 静音 | B |
| `s2.media.video_play` | 播放 | B |

阶段 A 提交时 3 条视频键尚未加入（否则成为孤儿 key，目录一致性门禁会红），
随 B 一并加入。

## 测试

新增 `PhotoCleanupMVETests/IC139MediaBadgesTests.swift`，**17 项**。

| 断言 | 测试函数名 |
|---|---|
| 1 | `testIC139A_MediaKindMapsEveryProbeKindWithoutReimplementingPredicate` |
| 2 | `testIC139A_LivePillGeometryReferencesRegisteredChromeConstants`、`testIC139A_LivePillModelHasNoActionOrChevronField` |
| 3 | `testIC139A_LivePillExistsOnlyOnVisibleLivePage` |
| 4 | `testIC139B_VideoBarExistsOnlyOnVisibleVideoPageAndTakesNoHits`、`testIC139B_VideoBarGeometryReferencesRegisteredChromeConstants`、`testIC139B_VideoBarAnchorUsesVisualStripHeightNotTouchBandFloor` |
| 5 | `testIC139B_HiddenInterfaceBuildsNeitherPillNorBar`、`testIC139B_MediaChromeUsesExistingVisibilityTransitionConstants` |
| 6 | `testIC139C_VideoPageFitInsetIsDerivedNotIndependent`、`testIC139C_VisibleVideoPageRenderFrameLiftsBottomEdgeBy68`、`testIC139C_WidthBoundVideoPageRecentersInsideShortenedRegion` |
| 7 | `testIC139C_HiddenVideoPageGeometryMatchesPhotoPage`、`testIC139C_PhotoAndLivePagesKeepBaselineGeometry` |
| 8 | `testIC139D_LongPressGoesToLivePlaybackOnlyOnLivePages`、`testIC139D_LivePhotoLongPressRecordsOncePerPress` |
| 9 | `testIC139D_CalibrationPanelToggleLeavesTheMainPhotoLongPressPath` |

### 项数对账

| 来源 | 数量 |
|---|---|
| 基线（`main`，CI #270） | 677 |
| 本卡新增 | +17 |
| **合计（CI #271）** | **694** |

既有用例零增删；`IC139MediaBadgesTests` 单套读数 `Executed 17 tests, with 0 failures`。

## 占位值登记

**无出厂值变更。** `S2CalibrationConfiguration.schemaVersion` 保持 **7**
（`Features/S2/S2Calibration.swift:118`，该文件不在 diff 内）。
本卡全部媒体常量走**登记制** `S2MediaMetrics`，不进标定配置、不上标定面板，
故不构成出厂值集合变更、不递增版本号。

## CI

- **#271**（run id `34226691819`，attempt 1）——**绿，一次通过**
  - 被测提交 `564a5f39bbec7bc8b9fb1f82f7e4a9f5e20d6885`，事件 `push`
  - **Executed 694 tests, with 0 failures (0 unexpected) in 29.674 (35.739) seconds**
  - `** TEST SUCCEEDED **` 在位；`##[error]` 0 条、`##[warning]` 0 条
  - 真实退出码 **0**（job `102062431312` success，10 个 step 全 success）
  - 目的地 `{ platform:iOS Simulator, arch:arm64, id:EADC2067-4553-4FDB-8780-62A3666009F5, OS:26.2, name:iPhone 16 }`
  - IPA `PhotoCleanupMVE-unsigned.ipa`，**1305488 字节**，
    SHA-256 `e8d1417ca43a9368439b34a059956b987540cd1267815972e15f76bf5befa32f`
  - 产物 `PhotoCleanupMVE-unsigned-564a5f39bbec`，zip 1305658 字节
- **CI 预算 3 次用 1 次**（主跑即绿，2 次修未动用）
- **G795：合并后 `main` 自动运行 #272**（run id `34228403858`，attempt 1）——**绿**
  - 被测提交 `fd7c9831dfb8f5febc101f287fa587c92ce6259f`，事件 `push`，分支 `main`
  - **Executed 694 tests, with 0 failures (0 unexpected) in 74.559 (129.402) seconds**
  - 真实退出码 **0**（job `102068117135` success，10 个 step 全 success）
  - IPA **1305488 字节**，
    SHA-256 `eb54f631f96f8a58336ed2020891d818a619448d0eaa7beb0109bccba6cd211e`
  - 产物 `PhotoCleanupMVE-unsigned-fd7c9831dfb8`，zip 1305658 字节

## 分支与冻结链状态

| 分支 | tip | 状态 |
|---|---|---|
| `main` | `fd7c983` | 本卡推进（合并提交） |
| `feature/ic-139-media-badges` | `564a5f3` | 保留，未删除 |
| `probe/ic-137-media-playback` | `486bcb7` | 未动（探针，只读参照） |
| `feature/ic-138-housekeeping` | `113384a` | 未动 |
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | 冻结，未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | 冻结，未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | 冻结，未触碰 |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | 未动 |
| `probe/ic-125-sentinel-negative` | `402cb6e` | 未动 |

## 本地门禁

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 |
| `git diff --check`（工作树） | 0 |
| `git diff --check db318fc..fd7c983` | 0 |

四个阶段提交各自单独跑过 `selfcheck.ps1` 与硬编码扫描，退出码均为 0。
