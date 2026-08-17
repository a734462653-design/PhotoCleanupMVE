# IC-20260817-064 v3 自验报告

## 当前结论

本地代码、测试夹具与 Windows 可执行的静态门禁已完成。当前机器是 Windows，未安装 Swift、Xcode 或 iOS 模拟器，并且任务卡禁止联网，因此本报告不声称已取得改造前真实曲线、模拟器描边像素、XCTest 实跑结果、CI 编号或 IPA。上述证据必须在 macOS 模拟器或获准的 CI 上补齐后，任务才满足完整验收。

## 输入与边界

- 输入规格：`SPEC-S2-20260816_v14.md`
- SHA-256：`CEAE2A0FA830C26E3C6E2B70C2308081C8336720B20770E776E3F3091F80AD45`
- 继承提交：`3bb744f4b462d670dce07185ce143f1a59064997`
- 目标分支：`feature/ic-064-toggle-animation`
- 未改动 `S2StateMachine.swift`、`S2TemporaryPhotoImageStrategy.swift`、`CleanupCoordinator.swift`、规格、决策日志、图片请求策略、双击过渡、Nx 手势门控及 `debugAssetLimit`。
- `fitInsetRatio=0.300000`、`fitCornerRadius=28.000000`、`minDoubleTapScale=2.000000`、`pinchMaxScale=4.000000` 的出厂值保持不变。

## 改造前过渡曲线

### 真实测量状态

未取得。当前环境无法加载 UIKit 或启动 iOS 模拟器，不能执行 `layer.presentation()` 采样。为避免重复 v1 的失效测量问题，本报告不从录屏、任务卡数值或源码插值反推任何改造前曲线。

### 仅作定位的源码观察

以下内容不是量化测量证据：基线提交在 `UIView.animate` 中逐帧改变照片视图 `bounds` 与圆角，使用通用的 180 毫秒动画参数，并在完成回调或延时兜底中提交 `pendingPresentationPage`。该观察只用于定位可能的内容重排和终点二次提交，不进入 G13～G18 判定。

### 已准备的测量夹具

`IC064PresentationLayerSampler` 位于 XCTest 测试靶，使用 60Hz `CADisplayLink` 读取照片层的 `layer.presentation()`，记录时间、实际 frame、bounds、圆角与描边宽度。它不进入产品运行时代码，可同样挂到 `3bb744f4` 的基线工作树取得改造前双向曲线。

## 实现结果

- 单击显隐使用独立的 `presentationToggleDuration=220.000000` 毫秒；既有双击动画仍使用 `animationDurationMilliseconds=180.000000`。
- 动画开始前一次性提交终态布局；照片层从源态的中心等比 transform 连续收敛到 identity，完成后不再提交第二份几何。
- 两个方向共用同一条线性动画路径，锚点固定为照片层中心和视口中心。
- 圆角和描边与 transform 在同一动画事务中连续变化；中断重入时从当前 presentation 层的视觉 frame、圆角和描边继续。
- 内缩态描边使用照片层自身的 `borderWidth`，不增加照片总尺寸；深色模式为白色 0.09，浅色模式为黑色 0.055。
- 描边仅在 `s=1`、`V=显示`、框显且命中屏幕比例时出现；Nx 下宽度为 0；trait 明暗切换时原地刷新颜色。
- `fitBorderWidth`、`fitBorderDarkAlpha`、`fitBorderLightAlpha` 与 `presentationToggleDuration` 已接入 debug 面板并支持实时持久化与导出。

## G13～G25 状态

| 编号 | 断言或证据 | 当前状态 |
|---|---|---|
| G13～G18 | `testIC064G13ToG18PresentationSamplesMeetGeometryContract`，60Hz presentation 层双向采样、等比缩放、中心、恒定完整 bounds/contentsRect、时长差、圆角单调与两方向结束后 300ms 稳定性 | 已编写，未在模拟器实跑 |
| G19 | `testIC064G19FitBorderPixelsMatchDarkAndLightSamples`，三种构造样本、左右边界、@3x 像素取样 | 已编写，未在模拟器实跑 |
| G20 | `testIC064G20FitBorderKeepsPhotoGeometryUnchanged` | 已编写，未在模拟器实跑 |
| G21 | `testIC064G21FitBorderTracksScaleAndPresentationProgress`，Nx 归零及显隐双向视觉线宽连续性 | 已编写，未在模拟器实跑 |
| G22 | `testIC064G22FitBorderUpdatesWithInterfaceStyle` | 已编写，未在模拟器实跑 |
| G23 | 全工程搜索 `overrideUserInterfaceStyle` 赋值 | 通过，0 处 |
| G24 | IC-063 G1～G12 测试仍存在；三个禁止改动文件相对基线均无差异 | 静态通过，未实跑 XCTest |
| G25 | XCTest 静态函数总数 | 389，未实跑 XCTest |

## 描边像素比对

模拟器实测尚未取得，不填写虚构像素值。测试已按以下目标编写：

| 场景 | 左侧目标 | 右侧目标 | 当前结果 |
|---|---:|---:|---|
| 深色模式、边缘灰度 2 | 25±6 | 25±6 | 未实跑 |
| 浅色模式、边缘灰度 2 | 2±4 | 2±4 | 未实跑 |
| 浅色模式、边缘灰度 237 | 224±6 | 224±6 | 未实跑 |

## 本地自验

- `Scripts/selfcheck.ps1`：通过，真实退出码 0。
- `git diff --check`：通过，真实退出码 0。
- 用户可见硬编码残留：0。
- 产品源码网络与账号能力门禁：通过。
- `overrideUserInterfaceStyle` 赋值：0 处。
- XCTest 静态函数总数：389，不低于要求的 383。
- 当前环境未提供 `swift`、`swiftc` 或 `xcodebuild`，因此没有编译或 XCTest 真实退出码。

## CI 与真实退出码

- CI：未触发；任务卡禁止联网，本地也未获得推送授权。
- 被测提交：无。
- XCTest 实跑总数：未取得。
- XCTest 真实退出码：未取得。
- 构建与 IPA：未取得。

## IC-063 遗留说明

### `Localizable.xcstrings` 与硬编码扫描脚本

IC-063 新增了“导出几何诊断”“正在自动采样几何数据”“复制或分享几何诊断”三个 debug 面板可见文案，因此这些交互文案进入 `Localizable.xcstrings` 是必要且正确的。`scan-hardcoded-user-visible-strings.ps1` 同时增加了几何诊断导出协议范围识别，把报告字段与诊断说明归类为非用户界面的诊断协议文本，避免把整套机器诊断输出误当成产品界面文案。

debug 面板中面向人的按钮、状态和说明应进入本地化目录；参数键名、导出字段名和诊断协议字段属于技术标识，需保持逐字稳定，不应翻译。本卡新增的是参数键名，未新增面向人的产品文案，因此没有修改 `Localizable.xcstrings` 或扫描脚本。

### `S2TemporaryPhotoImageStrategy.swift` 影响面

IC-063 对该文件做了两类修改：加入 `contentMode`，使框显照片按 fill、普通照片按 fit 显示；加入可选 `requestBaseSize`，让请求键使用未内缩的原生缩放基准尺寸，而不是随显隐变化的视图几何尺寸。

它没有改变 `PHImageRequestOptions`、网络访问开关、请求决策表、捏合结束策略或降级图策略；但稳定请求基准会消除仅由 `V` 显隐布局变化触发的重复 viewport-change 请求，因此相对更早实现确实可能减少请求次数并改变这类请求的时机。该行为压在未定项 8 上，只能视为 IC-063 为防止显隐/缩放几何误触发请求所做的临时接线，不能作为未定项 8 的正式结论；未来定案仍可替换请求基准、时机和数量。本卡没有继续修改该文件或请求链路。

## 人工项

H3～H6 保留给产品负责人真机并排判定。本报告不把静态检查、模拟器计划或源码推断冒充真机观感结论。
