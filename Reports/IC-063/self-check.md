# IC-20260816-063 v2 自验报告

## 当前结论

代码、静态门禁、模拟器 XCTest、自动诊断与未签名 IPA 均已完成验证。GitHub Actions CI #67 在被测提交 `3bb744f4b462d670dce07185ce143f1a59064997` 上执行 383 项测试，0 失败，真实退出码为 0；人工项 H0、H1、H2 仍保留给产品负责人真机判定。

## 输入与边界

- 基线规格：`SPEC-S2-20260816_v14.md`
- SHA-256：`CEAE2A0FA830C26E3C6E2B70C2308081C8336720B20770E776E3F3091F80AD45`
- 继承版本：IC-063 v1 提交 `c6938dd0c041d7c17cac0ffb461586b9c7415a2a`
- 目标分支：`feature/ic-063-immersive-transition`
- `S2StateMachine`、规格、决策日志、35 度方向裁决、左右贴边翻页、原生捏合和 `debugAssetLimit` 均未改动。

## 第 0 项：门控条件与实际根因

门控入口位于 `S2NativeZoomPageController.gestureRecognizerShouldBegin(_:)`。该 delegate 先调用 `shouldBeginVerticalSwipe(for:)`，再由 `S2NativePagerViewController.allowsVerticalSwipeRecognition(on:)` 读取当前状态机；分层判定表达式是严格的 `machine.scale == 1`。只有通过分层门控后，才继续使用既有的竖向速度大于横向速度判定。

任务卡的根因假设得到确认：IC-059 添加每页独立 `UIPanGestureRecognizer` 及内外层 `require(toFail:)` 时，`gestureRecognizerShouldBegin` 只保留方向判定，`s == 1` 条件是完全缺失，并非表达式写错。结果是 Nx 下竖向识别器先进入竞争，内层原生 pan 被迫等待并丢失竖向平移。

第 0 项已由独立提交 `2850e99` 承载，只包含原生页控制器和对应 XCTest，可单独 cherry-pick，不依赖本卡其余改动。

## 实现结果

- 稳定 1x：`contentSize` 恒等于视口、`contentOffset` 恒为零；命中 1% 容差的照片也严格使用物理视口乘以 `(1 - fitInsetRatio)` 的布局尺寸，内层 `transform` 恒等，圆角直接写入照片层。
- 稳定 Nx：命中照片采用未内缩的物理视口作为原生缩放基准；`V` 切换只记录延迟目标，不改变倍率、偏移、内容尺寸、内层 frame 或圆角。
- 双击转场：进入和退出共用 `S2DoubleTapTransition` 与一层专用快照过渡视图；页控制器与父分页布局层共同冻结动画期间的原生 `zoomScale`；终点无动画一次性同步 `zoomScale`、`contentSize`、`contentOffset` 和照片 frame，并记录同步前后 window frame。
- 原生持续交互：捏合、Nx 平移、边界和分页仍由 `UIScrollView` 驱动；捏合吸附仍使用原生最小倍率动画。
- 状态栏与安全区：内外滚动视图运行时均为 `.never`；主图根视图及逐页照片托管根均忽略安全区；内层 `UIHostingController.additionalSafeAreaInsets` 明确为零；状态栏随 `V` 隐藏或恢复。
- 图片请求：逐页图片请求使用稳定的未内缩原生基准尺寸，布局从 1x 手机框切到 Nx 基准时不会被误判为视口变化；既有“捏合中零请求、结束一次请求”策略保持不变。
- 参数：`minDoubleTapScale=2.000000`、`fitInsetRatio=0.300000`、`pinchMaxScale=4.000000`；`fitInsetRatio` 保持实时调节。
- 自动诊断：debug 面板可一键归一状态、切换两次 `V`、执行双击进入和退出，并按不同显示帧自动采集进入至少 3 个、退出至少 5 个中间帧；Q1 的空白归因从窗口坐标实际计算并换算为像素，Q2～Q3 的恒等、恒定、单调与跳变结论均从全部对应样本计算，最后生成可选择、复制或分享的文本。

## G1～G12 断言

| 编号 | XCTest | CI 状态 |
|---|---|---|
| G1 | `testIC063G1HiddenMatchedPhotoWindowFrameEqualsScreenBounds` | CI #67：通过 |
| G2 | `testIC063G2VisibleMatchedPhotoUsesInsetLayoutAndIsCentered` | CI #67：通过 |
| G3 | `testIC063G3DoubleTapTargetUsesTwoOnlyForMatchedPhotos` | CI #67：通过 |
| G4 | `testIC063G4DoubleTapSynchronizationPreservesWindowFrameBothWays` | CI #67：通过 |
| G5 | `testIC063G5NxVisibilityTogglePreservesNativeGeometryAndCorner` | CI #67：通过 |
| G6 | `testIC063G6NxDeferredPresentationCommitsExactlyOnceOnExit` | CI #67：通过 |
| G7 | `testIC063G7AllPhotoScrollViewsReadBackNeverAdjustment` | CI #67：通过 |
| G8 | 完整 XCTest 与数量门禁 | CI #67：383 项，0 失败，通过 |
| G9 | `testG9NxSwipeUpLeavesDeletionSetAndCurrentIndexUnchanged` | CI #67：通过 |
| G10 | `testG10NxSwipeDownLeavesDeletionSetAndCurrentIndexUnchanged` | CI #67：通过 |
| G11 | `testG11NxVerticalPanChangesContentOffsetWithinNativeBounds` | CI #67：通过 |
| G12 | `testG12PinchSnapBackImmediatelyRestoresSwipeUpMarking` | CI #67：通过 |

自动诊断另由 `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 实跑并把完整样例写入 XCTest 日志。

## 本地自验

- Windows 静态 XCTest 数量：383（要求不少于 363）。
- `Scripts/selfcheck.ps1`：通过。
- `git diff --check`：通过。
- `pwsh -NoProfile -File Scripts/verify-IC-20260816-063.ps1`：通过，共 70 项检查，未使用待回填开关。
- Windows 没有 Xcode，因此本地不声称执行 UIKit XCTest。

## CI 与真实退出码

- CI：[GitHub Actions #67](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31959782992)，作业 `95195885102`
- 被测提交：`3bb744f4b462d670dce07185ce143f1a59064997`
- XCTest 总数：383
- 真实退出码：0。工作流启用 `pipefail`，保存测试命令状态并以该状态退出；XCTest 步骤结论为成功，因此日志管道未吞掉失败码。
- 原文：`Executed 383 tests, with 0 failures (0 unexpected) in 23.543 (43.890) seconds`
- 测试结论：`TEST SUCCEEDED`
- 构建：`BUILD SUCCEEDED`
- IPA：产物 `PhotoCleanupMVE-unsigned-3bb744f4b462`（产物编号 `9266983632`）上传成功，并绑定运行 `31959782992` 与上述被测提交。

### IPA 下载复核

- 外层产物压缩包：639848 字节，SHA-256 `55C2689A1935C3FDD45412DEC2EC1F66949F5CE318BA99154A2EAD30242B5D04`。
- 内层 `PhotoCleanupMVE-unsigned.ipa`：639678 字节，SHA-256 `47CB3BA5BCFF83F90F3C6CC4B07E418A1084258A021957CC499281357252FD99`，与 CI 生成日志一致。
- IPA 共 8 个条目，全部可读取；仅有一个 `Payload/PhotoCleanupMVE.app/` 根目录，`Info.plist` 与 64 位 Mach-O 可执行文件均存在。
- 未发现 `_CodeSignature`、嵌入式描述文件或不安全路径，符合未签名 IPA 预期。

## 诊断假设核对

- Nx 竖向识别器缺少分层门控：源码与 G9～G12 确认根因假设成立；IC-059 的条件是缺失，不是存在但写错。
- Q1：`V=隐藏`、`s=1` 时顶部空白为 `0.000000px`；`contentInset`、安全区与 aspectFit 贡献均为 `0.000000px`，加和与实测一致。
- Q2：全部 Nx 样本的内层 `transform` 恒等，稳定态原生 `zoomScale=2.000000`；动画期间原生倍率恒定，缩放仅由专用过渡层承载，不存在原生倍率与内层变换同时非默认。
- Q3：退出动画 5 个中间帧的原生 `contentOffset` 均为 `(196.666667, 426.000000)`，内层变换恒等；专用过渡层六元组分量单调，无偏移跳变，终点仅执行一次无动画同步。
- Q4：`V=显示` 时状态栏实际隐藏值为 `false`，`V=隐藏` 时为 `true`。
- 15 组完整采样见 `diagnostics-sample.md`；诊断数据没有推翻任务卡中的根因假设。

## 变更清单

1. `PhotoCleanupMVE/App/CleanupCoordinator.swift`
2. `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`
3. `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
4. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
5. `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift`
6. `PhotoCleanupMVE/Features/S2/S2View.swift`
7. `PhotoCleanupMVE/Localizable.xcstrings`
8. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
9. `Scripts/scan-hardcoded-user-visible-strings.ps1`
10. `Scripts/verify-IC-20260816-063.ps1`
11. `Reports/IC-063/self-check.md`
12. `Reports/IC-063/diagnostics-sample.md`

## 人工项

H0、H1、H2 均保留为产品负责人真机判定，本报告不把模拟器或静态断言冒充真机观感结论。
