# IC-069 自验报告

## 结论

IC-069 已在分支 `feature/ic-069-transition-rootcause` 完成代码、自动化测试与 CI 交付。继承提交为 `3329ea4fb104dfdc7982521343ac1bf536e66fab`，最终被测代码提交为 `950daf4e2de683bf8d0de02bd17f2fe0e39c2d5b`。

GitHub Actions [iOS 构建与自验 #113](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32153848807) 成功：测试命令真实退出码为 0，执行 414 项 XCTest、0 失败、0 unexpected；Release 未签名 IPA 构建、校验及上传均成功。CI 共使用 3/3 次尝试。

本环境是 Windows，没有连接 iPhone，无法执行 H17～H20 或重录 IC-068 的 A、B、C 三个真机场景。本文不会用模拟器数据冒充真机回传；三份诊断文本仍须在真机安装本分支后补录。

## 根因结论

### R1a：动画推进依赖主线程

原显隐过渡用生产 `CADisplayLink` 在主线程逐帧计算并写入照片 transform、圆角和描边。场景 A 的主线程停摆会同时冻结动画推进与 IC-068 诊断采样，因此停摆后只能由主线程直接提交终态。

修复后，220ms、阻尼 0.86 的 spring 曲线预计算为 28 个关键帧，一次性交给 `CAKeyframeAnimation`/`CAAnimationGroup`。照片缩放、视觉圆角与描边均由渲染层计时；主线程只负责启动和最终模型态提交，不再负责逐帧推进。测试将主线程人为阻塞 500ms，确认动画键在阻塞期间持续存在、完整曲线已提交且终点几何命中目标；有 presentation 层的运行环境直接读取 presentation 终态，无头 CI 缺少 presentation 副本时读取同一图层的模型终态。

### R1b：727ms 阻塞的方向不对称来源

主图内容本身已有 `contentVersion` 门控，仅改变 `V` 不会重建主图请求。真正不对称的路径在 `S2View`：原代码只在 `V=显示` 时把整个 `interfaceOverlay` 插入视图树。由隐藏切回显示时，底部缩略条及全部缩略图视图重新出现，重新进入各缩略项的 `onAppear` 图片请求/解码路径；反方向只是移除视图，因此与场景 A 有阻塞、场景 B 无阻塞的时序一致。

修复改为让 overlay 在两个状态下持续存在，只切换透明度、命中测试和辅助功能可见性。`testIC069R1bPresentationToggleKeepsThumbnailViewsAlive` 验证显示→隐藏→显示期间缩略项出现次数不增加。本卡没有修改图片请求策略或未定项 8。

### R2：首帧比例重复应用

原实现先把页面立即提交到目标 bounds，再用“源视觉 frame ÷ 目标 bounds”求源缩放；诊断中已经含缩放系数的 frame 又乘一次 transform，因而 0.7 或 1.428571 被重复应用，两个方向还分别落在不同的 bounds 基准。

修复后，整个动画期间保留源态 bounds/center，以同一源态为唯一基准，只让 Core Animation 的 scale 从源值插值到“目标尺寸 ÷ 源尺寸”；动画完成后才一次性提交目标 bounds。300×600 测试视口的关键帧视觉尺寸为：

| 方向 | 首帧 | 中间帧（第 15/28 帧） | 末帧 |
|---|---:|---:|---:|
| 内缩→铺满 | 210×420 | 297.660×595.320 | 300×600 |
| 铺满→内缩 | 300×600 | 212.340×424.680 | 210×420 |

首末帧误差门限为 0.5pt；两个方向都使用源态 bounds 与单一 transform 基准。

### R3：`402×301.5` 错误尺寸来源

捏合接管原来无条件把照片从既有 `fittedSize` 改写成 `nativeZoomBaseSize`。资产像素尺寸尚未解析时，`nativeZoomBaseSize` 可来自 4:3 fallback；402 宽视口据此得到 `402×301.5`，随后 `prepareNativeZoomGeometry` 又把它写到左上原点。这不是 IC-065 居中补偿方向错误，而是补偿前的内容尺寸本身未解析。

修复将当前页的 `assetPixelSize` 传入原生缩放视图，建立 `hasResolvedAssetGeometry` 门禁：尺寸已解析时使用当前资产的真实适配几何；尺寸为零或未知时，接管返回 false，不开启事务、不写 bounds/center/transform/contentSize，保留接管前视觉几何。G56 同时覆盖比例约 0.1823 的窄图和带 4:3 假基准的未知资产。

### R4：静止写入循环成因

IC-068 未记录页与资产，多个页面各自合法的静止布局写入被混在同一事件流中，看起来像一个 layer 在三套比例间跳变。代码层面的反馈源是三组无条件赋值：`enforceOneXContentGeometry` 每次重写几何后主动触发布局，`applyCornerMask` 每次重写 transform/图层属性并重排描边层，外层分页布局每次重写相同 frame/contentSize/contentOffset。布局回调因此反复唤起等值写入。

修复为逐字段比较，只在目标值变化时写入并触发布局；描边层仅在层级确实不正确时重排；分页几何和稳定偏移也只在变化时赋值。没有重构分页复用结构或页面生命周期。G57 在无输入的一秒窗口内反复请求布局，照片几何写入计数为 0。

## 诊断补强

`S2NativeZoomScrollView` 保存所属 `pageIndex` 与 `assetLocalIdentifier`，照片几何写入、内层 `layoutSubviews`、外层 `viewDidLayoutSubviews` 及外层抑制事件均输出这两个字段。资产更新时上下文同步刷新。原录制开关、时钟、采样字段和关闭态零副作用行为未变；IC-068 G47 继续通过。

## 验收门禁

| 门禁 | 结果 | 自动化证据 |
|---|---|---|
| G53 | 通过 | `testIC069G53PresentationLayerFinishesWhileMainThreadIsBlocked`：500ms 主线程阻塞期间 CA 动画仍挂载，28 帧曲线与终点几何正确。 |
| G54 | 通过 | `testIC069G54AndG55BothDirectionsUseSourceGeometryBaseline`：双向首帧等于源态、末帧等于目标态，容差 0.5pt。 |
| G55 | 通过 | 同一测试验证双向均保留源态 bounds，并以源态 scale→目标 scale 作为唯一组合基准。 |
| G56 | 通过 | `testIC069G56PinchTakeoverRequiresResolvedAssetGeometry`：窄图接管前后完全一致；未知尺寸时零几何写入。 |
| G57 | 通过 | `testIC069G57StableLayoutWritesNoPhotoGeometryForOneSecond`：无输入一秒，照片几何写入 0 次。 |
| G58 | 通过 | `testIC069G58GeometryDiagnosticsIdentifyPageAndAsset`：几何写入与内外层布局事件均匹配正确页和资产。 |
| G59 | 通过 | IC-063 G1～G12、IC-064 G13～G25、IC-065 G26～G35、IC-067 G36～G46 在 #113 全部通过。 |
| G60 | 通过 | #113 执行 414 项 XCTest、0 失败，高于 IC-068 的 408 项基线。 |

## CI 与产物

| 项目 | 结果 |
|---|---|
| 最终 CI | #113，运行 ID `32153848807` |
| 被测提交 | `950daf4e2de683bf8d0de02bd17f2fe0e39c2d5b` |
| 尝试次数 | 3/3 |
| XCTest 步骤 | success；被测命令真实退出码 0 |
| XCTest | 414 项，0 失败，0 unexpected |
| XCTest 摘要耗时 | 12.740 秒；括号总时长 13.781 秒 |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，696344 字节 |
| IPA SHA-256 | `388200ff7b0da93bda3c4ff7979c4024c49ae1314bff468b49b60aa01dd2a5d6` |
| Artifact | `PhotoCleanupMVE-unsigned-950daf4e2de6`，归档摘要 `08a2c66936fa489fba41c2f753099f7cb58cba4b88c912a5a823bd78988e2fe3` |

尝试记录：#111 暴露旧 IC-064/067 测试仍以生产 display link 的 presentation 中间采样为判据；#112 暴露无头模拟器偶发不提供 presentation 副本时测试夹具会致命解包；#113 修正观测口径后全部通过。生产动画实现未因这两次测试修正退回主线程逐帧驱动。

## 本地与范围检查

- `Scripts/selfcheck.ps1`：退出码 0。
- `Scripts/scan-hardcoded-user-visible-strings.ps1`：退出码 0；165 个目录 key、165 个产品源码引用，用户可见硬编码残留 0。
- `git diff --check`：退出码 0。
- 相对继承提交，只修改 S2 原生照片分页、S2 overlay 生命周期及 S2 校准测试；未修改 SPEC、Decision Log、S1、S3～S5、出厂参数、图片请求策略、分页复用结构或页面生命周期。

## 真机回传待办

使用本分支的 IC-068 诊断面板分别重录：A 单击显示、B 单击隐藏、C 捏合起始，并执行 H17～H20。回传时应提供三份原始诊断文本；本地与 CI 无法替代这一步。
