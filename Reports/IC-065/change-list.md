# IC-20260817-065 v2 变更清单

## 产品代码

- `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
  - 删除 `S2NativeZoomScrollView.layoutSubviews()` 在最小倍率时清零 inset 并提前返回的六行分支。
  - 复用原有对称 `contentInset` 计算，使完整适配照片在捏合接管的 1x 首帧及后续小尺寸方向保持居中。
  - 未改变大尺寸方向的原生内容边界，未定义或修改捏合锚点。

## 测试代码

- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
  - 增加改造前 60Hz `CADisplayLink` 与 `layer.presentation()` frame 轨迹采样夹具。
  - 增加 G26～G31、G32 和 G34 防回归测试，覆盖两类未命中样本、命中屏幕比例样本、1 到 1.001 连续性、捏合全程居中、原生钳制边界及 IC-064 宽度序列。
  - 将 G30 的图片比例样本显式标注为 `[CGFloat]`，修正 CI #76 暴露的测试编译类型推断问题。

## 报告

- `Reports/IC-065/self-check.md`
  - 记录改造前捏合起始帧真实轨迹、根因、断言清单、本地与 CI 结果、测试总数和 IPA 证据。
- `Reports/IC-065/change-list.md`
  - 记录本卡精准变更范围。

## 禁止项核对

- 未修改 `S2TemporaryPhotoImageStrategy.swift`、`S2Calibration.swift`、规格文件、决策日志或图片请求策略。
- 未修改 `pinchMaxScale`、`zoomSnapBackThreshold`、IC-064 过渡动画、缓动、时长或描边。
- 未修改 Nx 手势分层门控、双击过渡、35 度方向裁决、左右贴边翻页或 `debugAssetLimit`。
- 未增加捏合锚点相关常量、参数或语义。
