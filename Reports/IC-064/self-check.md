# IC-20260817-064 v3 自验报告

## 当前结论

本地静态门禁与获准的 GitHub CI 均已通过。CI #68 在继承提交上取得改造前真实曲线并证明 384 项基线 XCTest 全部通过；CI #72 在最终产品与测试代码提交 `d1318c4bb2c0d937bd5ce9213d474516cd8a6c85` 上执行 389 项 XCTest、0 失败，真实退出码 0，并成功生成与上传未签名 IPA。H3～H6 仍按任务边界保留给负责人真机并排判定。

## 输入与边界

- 输入规格：`SPEC-S2-20260816_v14.md`
- SHA-256：`CEAE2A0FA830C26E3C6E2B70C2308081C8336720B20770E776E3F3091F80AD45`
- 继承提交：`3bb744f4b462d670dce07185ce143f1a59064997`
- 目标分支：`feature/ic-064-toggle-animation`
- 未改动 `S2StateMachine.swift`、`S2TemporaryPhotoImageStrategy.swift`、`CleanupCoordinator.swift`、规格、决策日志、图片请求策略、双击过渡、Nx 手势门控及 `debugAssetLimit`。
- `fitInsetRatio=0.300000`、`fitCornerRadius=28.000000`、`minDoubleTapScale=2.000000`、`pinchMaxScale=4.000000` 的出厂值保持不变。

## 改造前过渡曲线

### 真实测量状态

已取得。测量提交 `2dda2ffd63ac7b5b670d76a7bcbd40c83ed3a5f0` 直接基于继承提交 `3bb744f4`，只在 XCTest 靶加入 `IC064BaselinePresentationSampler`；CI #68 使用 iPhone 16、iOS 18.5 模拟器，以 60Hz `CADisplayLink` 读取 `layer.presentation()`。以下数值全部来自该次实跑，不来自录屏、任务卡数值或源码插值。

### 内缩→铺满实测序列

所有 frame 的中心均为视口中心 `(150, 300)`。

| 时间（ms） | frame（x, y, w, h） | bounds（w, h） | 圆角（pt） |
|---:|---|---|---:|
| 0.000 | `(45, 90, 210, 420)` | `(210, 420)` | 28 |
| 4.478、21.144、37.811、54.478、71.144、87.811、104.478、121.144、137.811、154.478、182.214 | `(0, 0, 300, 600)` | `(300, 600)` | 0 |

### 铺满→内缩实测序列

所有 frame 的中心均为视口中心 `(150, 300)`。

| 时间（ms） | frame（x, y, w, h） | bounds（w, h） | 圆角（pt） |
|---:|---|---|---:|
| 0.000 | `(0, 0, 300, 600)` | `(300, 600)` | 0 |
| 3.358、20.024、36.691、53.358、70.024、86.691、103.358、120.024、136.691、153.358、170.024、182.380 | `(45, 90, 210, 420)` | `(210, 420)` | 28 |

### 测量结论

两个方向都在首个显示帧（分别为 4.478ms 与 3.358ms）直接到达终态，随后仅等待约 182ms 才结束转场状态；中间没有任何连续几何帧。问题不是单一方向缺失动画，而是基线的两方向视觉几何都瞬间跳到终点，通用 180ms 时长只延迟完成提交。

## 实现结果

- 单击显隐使用独立的 `presentationToggleDuration=220.000000` 毫秒；既有双击动画仍使用 `animationDurationMilliseconds=180.000000`。
- 动画开始前一次性提交终态布局；照片层从源态的中心等比 transform 连续收敛到 identity，完成后不再提交第二份几何。
- 两个方向共用同一条线性动画路径，锚点固定为照片层中心和视口中心。
- 圆角和描边与 transform 共用同一条 220ms 线性显示刷新进度；中断重入时从当前 presentation 层的视觉 frame、圆角和描边继续。
- 内缩态描边使用照片内容之上的专用内层描边层，不增加照片总尺寸且不会与窗口底色错误合成；深色模式为白色 0.09，浅色模式为黑色 0.055。
- 描边仅在 `s=1`、`V=显示`、框显且命中屏幕比例时出现；Nx 下宽度为 0；trait 明暗切换时原地刷新颜色。
- `fitBorderWidth`、`fitBorderDarkAlpha`、`fitBorderLightAlpha` 与 `presentationToggleDuration` 已接入 debug 面板并支持实时持久化与导出。

## 改造后过渡曲线

CI #72 使用同一 60Hz `CADisplayLink` 与 `layer.presentation()` 夹具实测。产品线性进度的标定时长为 220ms；下列采样窗口从点击前源态帧开始，到结束回调后的最终捕获为止，因此包含下一次显示刷新，实测总窗口为 232.640～237.756ms。两个方向总窗口相差 5.116ms，且均包含 13 个以上不同的中间宽度，不再出现首帧跳终点。

- 内缩→铺满：16 帧，237.756ms；宽度序列 `210.000, 210.000, 217.844, 224.675, 231.492, 238.315, 245.085, 251.904, 258.730, 265.534, 272.353, 279.176, 286.031, 292.821, 299.653, 300.000`。
- 铺满→内缩：15 帧，232.640ms；宽度序列 `300.000, 300.000, 287.290, 280.497, 273.712, 266.895, 260.095, 253.281, 246.460, 239.626, 232.759, 225.990, 219.187, 212.319, 210.000`。
- 所有中间帧保持视口中心锚、等比 transform 与完整 `contentsRect`；点击后的动画帧使用一次性提交的固定目标 bounds。双向结束回调后的 300ms 稳定窗口内 frame 变化均为 0。

## G13～G25 状态

| 编号 | 断言或证据 | 当前状态 |
|---|---|---|
| G13～G18 | `testIC064G13ToG18PresentationSamplesMeetGeometryContract`，60Hz presentation 层双向采样、等比缩放、中心、点击后固定完整 bounds/contentsRect、时长差、多个不同中间帧、圆角单调与两方向结束后 300ms 稳定性 | CI #72 通过 |
| G19 | `testIC064G19FitBorderPixelsMatchDarkAndLightSamples`，三种构造样本、左右边界、@3x 真实视图层级像素取样 | CI #72 通过 |
| G20 | `testIC064G20FitBorderKeepsPhotoGeometryUnchanged` | CI #72 通过 |
| G21 | `testIC064G21FitBorderTracksScaleAndPresentationProgress`，Nx 归零及显隐双向视觉线宽连续性 | CI #72 通过 |
| G22 | `testIC064G22FitBorderUpdatesWithInterfaceStyle` | CI #72 通过 |
| G23 | 全工程搜索 `overrideUserInterfaceStyle` 赋值 | 通过，0 处 |
| G24 | IC-063 G1～G12 测试仍存在；三个禁止改动文件相对基线均无差异 | CI #72 全量回归通过 |
| G25 | XCTest 静态函数总数与实跑总数 | 389；CI #72 实跑 389，0 失败 |

## 描边像素比对

以下数值来自 CI #72 的 iPhone 16、iOS 18.5 模拟器，使用 @3x `drawHierarchy` 真实视图层级截图读取照片左右边界：

| 场景 | 左侧目标 | 右侧目标 | 实测结果 |
|---|---:|---:|---|
| 深色模式、边缘灰度 2 | 25±6 | 25±6 | 左 25、右 25，通过 |
| 浅色模式、边缘灰度 2 | 2±4 | 2±4 | 左 2、右 2，通过 |
| 浅色模式、边缘灰度 237 | 224±6 | 224±6 | 左 224、右 224，通过 |

## 本地自验

- `Scripts/selfcheck.ps1`：通过，真实退出码 0。
- `git diff --check`：通过，真实退出码 0。
- 用户可见硬编码残留：0。
- 产品源码网络与账号能力门禁：通过。
- `overrideUserInterfaceStyle` 赋值：0 处。
- XCTest 静态函数总数：389，不低于要求的 383。
- 当前 Windows 环境未提供 `swift`、`swiftc` 或 `xcodebuild`；模拟器实跑证据来自下述获准 CI。

## CI 与真实退出码

- 基线 CI：[iOS 构建与自验 #68](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31992220332)，结论 `success`。
- 基线被测提交：`2dda2ffd63ac7b5b670d76a7bcbd40c83ed3a5f0`。
- 基线 XCTest：执行 384 项，0 失败；“运行 XCTest”步骤结论 `success`，脚本把被测命令真实状态原样作为步骤退出码，因此真实退出码为 0。
- 基线未签名 IPA：639678 字节，SHA-256 `fb53da36bbecb33e6de55d35fa8c860d783948719c6c67c029954c28d336ed68`；Actions Artifact 上传成功。
- 最终实现 CI：[iOS 构建与自验 #72](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31994638427)，结论 `success`；被测提交 `d1318c4bb2c0d937bd5ce9213d474516cd8a6c85`。
- 最终 XCTest 原文：`Executed 389 tests, with 0 failures (0 unexpected) in 28.557 (49.329) seconds`；“运行 XCTest”步骤结论 `success`，脚本真实退出码为 0。
- 最终未签名 IPA：646902 字节，SHA-256 `617474a14d0d75dfe6bef1978a5c9bae37fe5a956ac42aeea6e50d7787a028ca`。
- Actions Artifact：`PhotoCleanupMVE-unsigned-d1318c4bb2c0`，Artifact ID `9276486248`，上传成功；归档摘要显示 632KB，Artifact digest 为 `sha256:7828dcc006f2807e7bdc6c3fe628d0d71adf7203920ef2b3d0848498c82980ef`。

## IC-063 遗留说明

### `Localizable.xcstrings` 与硬编码扫描脚本

IC-063 新增了“导出几何诊断”“正在自动采样几何数据”“复制或分享几何诊断”三个 debug 面板可见文案，因此这些交互文案进入 `Localizable.xcstrings` 是必要且正确的。`scan-hardcoded-user-visible-strings.ps1` 同时增加了几何诊断导出协议范围识别，把报告字段与诊断说明归类为非用户界面的诊断协议文本，避免把整套机器诊断输出误当成产品界面文案。

debug 面板中面向人的按钮、状态和说明应进入本地化目录；参数键名、导出字段名和诊断协议字段属于技术标识，需保持逐字稳定，不应翻译。本卡新增的是参数键名，未新增面向人的产品文案，因此没有修改 `Localizable.xcstrings` 或扫描脚本。

### `S2TemporaryPhotoImageStrategy.swift` 影响面

IC-063 对该文件做了两类修改：加入 `contentMode`，使框显照片按 fill、普通照片按 fit 显示；加入可选 `requestBaseSize`，让请求键使用未内缩的原生缩放基准尺寸，而不是随显隐变化的视图几何尺寸。

它没有改变 `PHImageRequestOptions`、网络访问开关、请求决策表、捏合结束策略或降级图策略；但稳定请求基准会消除仅由 `V` 显隐布局变化触发的重复 viewport-change 请求，因此相对更早实现确实可能减少请求次数并改变这类请求的时机。该行为压在未定项 8 上，只能视为 IC-063 为防止显隐/缩放几何误触发请求所做的临时接线，不能作为未定项 8 的正式结论；未来定案仍可替换请求基准、时机和数量。本卡没有继续修改该文件或请求链路。

## 人工项

H3～H6 保留给产品负责人真机并排判定。本报告不把静态检查、模拟器计划或源码推断冒充真机观感结论。
