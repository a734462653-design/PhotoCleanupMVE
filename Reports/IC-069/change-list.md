# IC-069 变更清单

继承提交：`3329ea4fb104dfdc7982521343ac1bf536e66fab`

最终被测提交：`950daf4e2de683bf8d0de02bd17f2fe0e39c2d5b`

## 独立提交

1. `5b39f51`：R1，显隐动画改由 Core Animation 关键帧驱动；overlay 持久化，消除显示方向的缩略条重建路径。
2. `ab71d86`：R2，双向统一使用源态 bounds 与缩放基准，终点再提交目标几何。
3. `0c4d0a7`：R3，资产几何未解析时拒绝捏合接管的猜测尺寸写入。
4. `a1307a5`：R4，对静止几何、圆角/描边层和分页布局使用差异写入，消除反馈循环。
5. `2f48b72`：诊断事件补充页索引和资产本地标识，新增 G58。
6. `07ef7e0`、`950daf4`：按 Core Animation 架构和无头 CI 能力修正旧测试观测口径。

## 产品源码

### `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`

- 用渲染层关键帧组取代显隐转场的生产 `CADisplayLink` 逐帧写入。
- 动画期间保留源态几何，完成时一次性提交目标页。
- 将当前资产像素解析状态接入原生缩放接管，未知时保持原几何。
- 对静止照片、圆角、描边层、分页 frame/contentSize/contentOffset 做差异写入。
- 为照片几何写入与内外层布局诊断增加 `pageIndex` 和 `assetLocalIdentifier`。

### `PhotoCleanupMVE/Features/S2/S2View.swift`

- overlay 始终保留在视图树中；隐藏态只关闭透明度、交互和辅助功能可见性，避免缩略条重建及重复图片请求入口。

## 测试

### `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`

- 新增 G53～G58 自动化覆盖。
- 更新 IC-064/067 显隐测试，使其分别验证真实显示层端点、源态模型 bounds 和提交给 Core Animation 的完整 spring 关键帧。
- 完整回归在 CI #113 执行 414 项 XCTest、0 失败。

## 报告

- `Reports/IC-069/self-check.md`
- `Reports/IC-069/change-list.md`

## 明确未改

未修改 SPEC、Decision Log、S1、S3～S5、图片请求策略、所有禁止调整的出厂参数、Nx 手势门控、双击倍率、35 度裁决、左右贴边翻页、分页复用结构或页面生命周期；未合并 main，未 force push，未改写历史。
