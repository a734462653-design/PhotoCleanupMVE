# IC-20260817-067 自验报告

## 当前结论

IC-067 的 C1、C2、C3、C4、C5 产品实现及 IC-066 工作流路径过滤已完成。正式交付提交为 `b453b68afa340aa14823b4d6b3172720f57b75f6`，GitHub Actions [iOS 构建与自验 #109](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32049883408) 已成功验证：执行 404 项 XCTest、0 失败，测试命令真实退出码为 0，并生成未签名 IPA。

本报告执行 2026-08-18 生效的新验收规则：停止真实手势事件驱动的 XCUITest 夹具开发；所有动画与手势断言按夹具驱动覆盖计为通过，并如实标注覆盖边界。probe 分支中的探索性改动保持独立，不进入正式交付。

## 输入、分支与范围

- 继承提交：`bf25d16d7e8a7938965ffbd7d774a4630e1d9dd1`。
- 正式分支：`feature/ic-067-screenshot-detection`。
- 探针分支：`probe/ic-067-screenshot-subtype`，仅保留截图子类型实测及已停止的探索历史。
- 未合并主干，未强制推送，未改写历史。
- 未修改 S1、S3～S5、规格、决策日志、图片请求策略、`S2TemporaryPhotoImageStrategy.swift`、`debugAssetLimit`、Nx 手势分层、双击目标倍率、35 度方向裁决或左右贴边翻页。
- 正式分支未加入 XCUITest 靶、真实手势宿主或为命中测试而改造的生产视图层级。

## C1 前提实测：裁切编辑后仍是截图资产

该前提不是源码推断。探针提交 `7d49daa` 在 GitHub Actions [探针运行 #94](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32040849050) 中，经 PhotoKit 资产创建、编辑/裁切并重新读取后得到：

`authorizationStatus=3 beforeSubtypes=4 afterSubtypes=4 renderedSize=235x2556 afterIsScreenshot=true`

结论：该实测样本编辑前后的 `mediaSubtypes` 原始值均为 4，编辑后的资产仍包含 `.photoScreenshot`，因此 C1 的元数据判定前提成立。该探针运行成功，但探针实现未进入正式交付分支。

## 产品实现结果

### C1 截图资产判定

- `CleanupCoordinator` 通过 `PHAsset.mediaSubtypes.contains(.photoScreenshot)` 产生截图标志并传入 S2。
- 截图显示态在 `0.70 × 视口` 框内做 aspectFit 并居中，带圆角和描边；隐藏态在全视口内做 aspectFit 并居中。
- 非截图两种 V 状态均在全视口内做 aspectFit，照片 frame 不随单击变化，圆角和描边均为 0。
- 屏幕比例判定只保留给双击目标倍率，不再控制内缩、圆角或描边。
- 普通照片是否应有圆角仍是产品待复核项；本卡按“非截图无圆角、无描边”实现。

### C2 明暗模式背景

- S2 根背景改为系统背景色，跟随 trait 原地切换。
- 托管页面像素夹具测得深色为 0、浅色为 255，均满足目标值 ±3。
- 未在产品代码设置 `overrideUserInterfaceStyle`；测试仅用该属性切换夹具 trait。

### C3 捏合接管与一倍归位

- `prepareForNativeZoom` 把铺满基准切换、居中补偿、蒙版更新及一次布局提交放入同一个禁动画 `CATransaction`。
- 严格回到 `s=1` 时恢复当前 V 对应的一倍几何：显示态回到截图内缩 aspectFit，隐藏态回到全视口 aspectFit。
- 覆盖标注：**夹具驱动，真机未覆盖，由 H12 人工判定兜底**。G41 的归位观感同时留给 H13 人工判定。

### C4 双向动画、根因采样与弹簧曲线

根因采样按新规则使用夹具。夹具先发布已识别的单击，再显式触发一次外层 `viewDidLayoutSubviews`，最后才让控制器应用新状态，复现“chrome 插入后、照片转场提交前”的布局窗口。两个方向均取得以下结果：

- 外层布局回调次数 `callbackCount ≥ 1`；首个回调延迟已记录且非空。
- 有资格写照片 frame 的外层回调被命中并抑制，`suppressedPhotoFrameWriteCount ≥ 1`。
- 动画期间实际照片 frame 写入为 `photoFrameWriteCount = 0`。
- 两个方向均不少于 3 帧，且各自有超过 3 个不同宽度。

因此在夹具覆盖范围内，根因假设得到确认：状态发布到页面开始转场之间的外层布局回调会尝试把当前照片写到终态，从而可能冲掉缩小方向动画。产品修复在发布单击前记录待处理页，外层布局跳过该页照片写入，并在页面开始提交转场后清除标记。该结论不声称已经在真机复现，H10、H11 仍需人工判定。

显隐动画采用 `presentationToggleDamping=0.860000`、初速度 0 的同一条弹簧曲线；阻尼允许范围为 0.6～1。曲线首个峰值后使用单调尾段收敛，并在归一化时间 1 精确到达终点。数学夹具覆盖阻尼 0.6、0.86、1.0，最大过冲均不超过 10%。

### C5 参数接线状态

- debug 面板对 48 个配置字段各显示一次“生效”或“未接线”，测试验证无遗漏、无重复。
- 共 15 项标记为未接线：`verticalSwipeMaximumDurationMilliseconds`、`horizontalSwipeDistance`、`horizontalSwipeVelocity`、`horizontalSwipeMaximumDurationMilliseconds`、`pinchMinimumScaleDelta`、`mainDragMinimumDistance`、`mainDragMinimumVelocity`、`mainDragMaximumDurationMilliseconds`、`singleTapMaximumMovement`、`singleTapMaximumDurationMilliseconds`、`doubleTapDecisionWindowMilliseconds`、`gestureExclusivityPolicy`、`fitInsetScope`、`screenshotImmersiveOnHide`、`bottomStripEdgeFadeWidth`。
- 其余 33 项标记为生效；未为了改变标记而接入任何死手势参数。

## G36～G46 验收结果

| 编号 | 结果 | 覆盖范围与证据 |
|---|---|---|
| G36 | 通过 | 夹具驱动。裁切截图比例 0.1823，验证截图元数据触发、显示态 0.70 框内 aspectFit、居中、圆角与描边，隐藏态全视口 aspectFit。 |
| G37 | 通过 | 夹具驱动。9:16 非截图两种 V 使用相同全视口 aspectFit，单击前后 frame 相同，圆角与描边均为 0。 |
| G38 | 通过 | PhotoKit 资产实测。探针 #94 的编辑前后子类型均为 4，`afterIsScreenshot=true`。 |
| G39 | 通过 | 托管渲染夹具。同一页面 trait 切换后像素为深色 0、浅色 255，容差 ±3；真机未覆盖。 |
| G40 | 通过 | **夹具驱动，真机未覆盖，由 H12 人工判定兜底**。接管同步闭包位于禁动画事务内，接管帧中心偏移不超过 0.5pt。 |
| G41 | 通过 | 夹具驱动。显示、隐藏两种 V 均验证严格回到 1 后的尺寸、中心和倍率；真机由 H13 复核。 |
| G42 | 通过 | 夹具驱动。两个方向均 ≥3 帧；外层布局回调 ≥1，抑制写入 ≥1，实际照片 frame 写入 0；真机由 H10、H11 复核。 |
| G43 | 通过 | 数学与显示层夹具。阻尼范围内过冲 ≤10%，首峰后单调收敛，双向使用同一曲线。 |
| G44 | 通过 | CI #109 全量 404 项 XCTest、0 失败；语义变化的旧断言均改写而未删除，清单见下节。 |
| G45 | 通过 | CI #109 实跑 404 项，不低于 396；测试步骤真实退出码 0。 |
| G46 | 待报告推送实证 | 代码提交 `b453b68` 已触发 CI #109；首份纯 `Reports/**` 报告提交推送后补记“不触发 CI”的运行列表实证。 |

## G44 改写断言清单与理由

### C1 判定条件变化

| 原断言 | 改写后 | 理由 |
|---|---|---|
| `testV8FitInsetRatioGeometryAndScopeAreCorrect` | `testV8FitInsetRatioAppliesOnlyToScreenshotMetadata` | 内缩范围从屏幕比例/范围参数改为截图元数据。 |
| `testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent` | `testD1ScreenshotAspectFitShrinksToSeventyPercentViewport` | 0.70 aspectFit 的触发者改为截图资产。 |
| `testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged` | `testD3AllPhotosScopeLeavesNonScreenshotUnchanged` | 非截图不再由屏幕比例区分，V 两态几何均不变。 |
| `testIC063G1HiddenMatchedPhotoWindowFrameEqualsScreenBounds` | `testIC063G1HiddenScreenAspectScreenshotMatchesScreenBounds` | 补入截图元数据前提，保留隐藏态全视口契约。 |
| `testIC063G2VisibleMatchedPhotoUsesInsetLayoutAndIsCentered` | `testIC063G2VisibleCroppedScreenshotUsesAspectFitInsetAndIsCentered` | 用裁切截图覆盖比例远离屏幕但仍内缩的情形。 |
| `testIC063G3DoubleTapTargetUsesTwoOnlyForMatchedPhotos` | `testIC063G3DoubleTapTargetStillUsesScreenAspectClassification` | 双击目标倍率仍按屏幕比例，本卡只改变内缩判定。 |
| `testF2CornerRadiusAppliesOnlyToInsetPhotos` | `testF2CornerRadiusAppliesOnlyToScreenshots` | 圆角跟随截图元数据。 |
| `testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden` | `testS5DisabledScreenshotImmersiveDoesNotChangeHiddenGeometry` | 旧开关不再控制截图隐藏态几何。 |
| `testY2MatchedPhotoHiddenDisplayStrictlyEqualsViewportAndHasZeroRadius` | `testY2CroppedScreenshotHiddenDisplayUsesFullViewportAspectFit` | 隐藏态明确为全视口框内 aspectFit，而非假设照片铺满。 |
| `testIC065G31MatchedPhotoKeepsIC063Geometry` | `testIC065G31ScreenshotMetadataKeepsIC063Geometry` | 回归入口从比例命中改为截图元数据。 |

### C8 弹簧曲线变化

| 原断言 | 改写后 | 理由 |
|---|---|---|
| `testIC064G13ToG18PresentationSamplesMeetGeometryContract` | 同名改写 | 以双向弹簧过冲/收敛替代全程线性单调，同时保留帧数、中心、等比、时长和稳定终点契约。 |
| `testIC064G21FitBorderTracksScaleAndPresentationProgress` | 同名改写 | 显示方向描边允许随弹簧轻微过冲后收敛；隐藏方向仍保持非负衰减。 |
| `testIC065G32IC064DeliveredWidthSequenceRemainsExact` | `testIC065G32BothDirectionsUseSameSpringCurveAndDuration` | 旧线性冻结宽度序列已失效，改验双向曲线对称及 220ms 时长。 |

## 本地自验

- `Scripts/selfcheck.ps1`：通过，真实退出码 0。
- `git diff --check`：通过，真实退出码 0。
- String Catalog JSON：解析通过；目录 155 项，产品引用 155 项，用户可见硬编码残留 0。
- XCTest 静态测试函数总数：404。
- 正式差异文件共 8 个，均在预期产品、测试与工作流范围内；禁止范围文件差异为 0。
- 当前 Windows 环境不能执行 Xcode/iOS 测试，实跑证据来自获准的 GitHub Actions。

## CI、真实退出码与 IPA

| 运行 | 被测提交 | 结果 | 测试/产物 |
|---|---|---|---|
| [#97](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32042853156) | `a056126` | 成功 | C1 阶段，398 项测试通过。 |
| [#99](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32043338754) | `da34e98` | 成功 | C2 阶段，399 项测试通过。 |
| [#108](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32049184649) | `b84b3b9` | 失败 | 第 1 次正式收尾；旧诊断夹具在控制器挂载前导出，执行到 284 项时 1 项失败，未生成 IPA。 |
| [#109](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32049883408) | `b453b68` | 成功 | 第 2 次正式收尾；404 项、0 失败，真实退出码 0，IPA 上传成功。 |

CI 的 XCTest 步骤保存被测命令状态并以 `exit "$test_status"` 原样退出。#109 的测试步骤成功且随后完成应用构建、IPA 校验和上传，因此测试命令真实退出码为 0；不是仅凭日志文字推断。

- IPA 文件：`PhotoCleanupMVE-unsigned.ipa`。
- IPA 字节数：655115。
- IPA SHA-256：`90ea9fc62009d2316557d2b47dfff753db3252f5c77e87630cf319bb573b5afc`。
- Actions Artifact：`PhotoCleanupMVE-unsigned-b453b68afa34`，640 KB。
- Artifact digest：`sha256:676867a9857396066e1213d2179df10cdcfc5033e0730efc57b28ffe4a2e36e6`。
- CI 尝试次数：2；未达到“三次内无法完成即停止”的上限。

## 真机人工项

H10、H11、H12、H13、H14、H15、H16 均未执行真机人工判定，本报告不将其标记为通过。H12 是 C3 夹具断言的人工兜底；其余项目分别按任务卡保留给产品负责人复核。

