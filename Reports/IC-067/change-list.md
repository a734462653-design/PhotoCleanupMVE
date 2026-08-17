# IC-20260817-067 变更清单

## 提交顺序

1. `a056126343b2a7d018875da2f7880e403b176f33`：C1，以截图资产元数据驱动 S2 内缩。
2. `da34e985f3eec7c1552f36d0377d111804a6c140`：C2，让 S2 背景跟随系统明暗模式。
3. `4022852b0251e87d8367deb52b3c708024c453cd`：C3，同步完成捏合接管与一倍归位。
4. `4ebfccd72602afbb06993af06e46f3cc5b4d04c2`：C4、C5，恢复双向显隐动画并标注参数接线状态。
5. `b84b3b97bae322f06a070595de774f19fc30c280`：IC-066 工作流路径过滤。
6. `b453b68afa340aa14823b4d6b3172720f57b75f6`：稳定旧几何诊断夹具的挂载等待；不涉及 XCUITest 或产品视图结构。

前四个产品提交保持独立，可按顺序单独拣选；工作流及夹具稳定性修正各自独立。

## 产品代码

1. `PhotoCleanupMVE/App/CleanupCoordinator.swift`
   - 从 `PHAsset.mediaSubtypes` 读取 `.photoScreenshot` 并提供给 S2。
2. `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`
   - 把当前资产的截图标志接入 S2 页面。
3. `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
   - 将内缩触发范围收敛为截图元数据。
   - 新增并持久化 `presentationToggleDamping=0.860000`，允许范围 0.6～1。
   - 建立 48 项参数接线审计表；33 项生效、15 项未接线。
4. `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`
   - 截图显示态在 0.70 视口框内 aspectFit；隐藏态使用全视口 aspectFit。
   - 非截图两种 V 状态保持相同全视口 aspectFit，移除圆角和描边。
   - 在同一个禁动画事务中完成捏合接管几何、居中和蒙版同步；严格一倍时恢复当前 V 几何。
   - 显隐切换期间抑制外层布局对当前照片 frame 的覆盖，保留双向过渡。
   - 使用双向一致的弹簧曲线并限制过冲后单调收敛。
5. `PhotoCleanupMVE/Features/S2/S2View.swift`
   - 主图背景改为跟随系统明暗模式。
   - 在 debug 面板接入弹簧阻尼和每项参数的“生效／未接线”标注。
6. `PhotoCleanupMVE/Localizable.xcstrings`
   - 增加参数接线状态与说明所需的中文本地化条目。

## 测试代码

7. `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
   - 增加 G36～G43 的截图几何、非截图稳定性、背景像素、捏合同步、一倍归位、双向过渡及弹簧收敛夹具。
   - 增加 48 项参数接线状态的完整性与唯一性断言。
   - 按 C1/C8 新语义改写 G44 列出的旧断言，未删除回归覆盖。
   - 将旧几何诊断从一次固定导出改为最长 2 秒等待协调器挂载后导出，消除 CI #108 的挂载竞态。

所有手势与动画测试均按新规则标记为夹具驱动；正式分支未加入 XCUITest 真实事件夹具。

## 工作流

8. `.github/workflows/ci.yml`
   - `push.paths-ignore` 新增 `Reports/**` 与 `**.md`。
   - 保留代码推送和手动触发；`b453b68` 的代码/测试提交已触发并通过 CI #109。

## 报告

9. `Reports/IC-067/self-check.md`
   - 记录 C1 前提实测、C4 根因夹具采样、G36～G46、G44 改写理由、CI 退出码及 IPA 校验。
10. `Reports/IC-067/change-list.md`
   - 本变更清单。

## 明确未改动

- 未改 S1、S3～S5、规格、决策日志、图片请求策略或 `S2TemporaryPhotoImageStrategy.swift`。
- 未接入 15 个死参数，未改变任何手势识别语义。
- 未调整任务卡禁止修改的出厂值、Nx 分层、双击锚点或翻页裁决。
- 未把 probe/XCUITest 探索历史带入正式分支。
- 未合并主干、未强制推送、未改写历史。

