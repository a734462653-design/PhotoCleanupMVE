# IC-068 变更清单

继承提交：`b453b68afa340aa14823b4d6b3172720f57b75f6`

代码与测试提交：`868f8b6f9ff323496b50dbe8a4a40e50cdd70705`

## 产品源码

1. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
   - 新增最长五秒、至少 60Hz 的手动诊断录制协调器。
   - 逐帧记录照片动画键、模型层与 presentation frame、仿射六元组、原生缩放/偏移/内容尺寸、`V` 与 `s`。
   - 将 SwiftUI 状态发布、桥更新、内外层布局、照片几何写入、动画移除、事务提交和 IC-067 抑制事件汇入同一单调时钟事件流。
   - 用带 `reason` 的同步闭包入口收敛照片 frame/transform 相关赋值；闭包内保留原赋值值和顺序。
2. `PhotoCleanupMVE/Features/S2/S2View.swift`
   - 在既有调试参数面板增加场景选择、开始录制、停止录制、导出文本、可选择文本和系统分享入口。
3. `PhotoCleanupMVE/Localizable.xcstrings`
   - 增加诊断录制区所需的简体中文界面文案。

## 测试

4. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
   - 新增 IC-068 G47～G50 四项 XCTest：关闭态零记录、统一入口零容差等价、导出字段完整、统一时钟严格递增。
   - 未新增 XCUITest、真实手势模拟或生产宿主尺寸调整。

## 报告

5. `Reports/IC-068/self-check.md`
6. `Reports/IC-068/change-list.md`
7. `Reports/IC-068/export-format.md`
8. `Reports/IC-068/simulator-sample.txt`

## 明确未改

未修改规格、Decision Log、S1、S3～S5、图片请求策略、`S2TemporaryPhotoImageStrategy.swift`、生产视图层级、几何参数和动画参数；未修复任何已知现象。
