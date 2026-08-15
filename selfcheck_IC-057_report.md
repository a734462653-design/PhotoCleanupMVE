# IC-20260815-057 双击倍率、锚点与响应自验报告

## 1. 结论

IC-057 的范围内实现已落位。当前分支为
`feature/ic-057-doubletap-response`，基线为 IC-056 交付提交
`b5d38f01cad45d903d419805ffc27e842f4f25f7`。

本机为 Windows 环境，没有 Xcode、`xcodebuild` 或 Swift 工具链，因此本报告不冒充
执行过新增 XCTest。仓库结构自验与 IC-057 专项静态自验结果在本报告第 6 节记录；
新增 XCTest 可在安装 Xcode 的 macOS 上由同一自验脚本选择执行。

## 2. `fitInsetRatio` 根因分类

根因属于：**`fitInsetScope` 的屏幕比例判定未命中**。

参数并非没有接到渲染层，内缩也没有被后续布局覆盖。渲染路径一直使用
`S2ViewportLayout.metrics` 产生的 `oneXDisplaySize` 作为主图 `.frame` 的宽高。旧问题
发生在进入这一步之前：屏幕比例作用域曾直接比较带方向的照片宽高比和视口宽高比。
例如同一物理比例在竖向视口是 `0.5`，横向照片是 `2.0`，直接比较会判为不匹配，
令内缩比例不生效。

IC-056 已把两边都归一为“短边／长边”后再使用原 1% 容差；IC-057 保留并复验该修复。
`fitInsetRatio=0.08` 的 1x 实际显示尺寸为纯等比适配尺寸的 `0.92`，且该尺寸继续直接
接到渲染层。该根因不是“参数未接到渲染层”“判定容差过严”或“内缩被后续布局覆盖”。

## 3. 双击倍率与触点锚定

- `aspectFillDegenerateTolerancePercent` 和
  `aspectFillDegenerateTargetScale` 不存在于配置、解析、导出或状态机路径。
- `minDoubleTapScale` 出厂值为 `2.5`，参数面板可调。
- 双击进入统一取
  `max(aspectFillMultiplier, minDoubleTapScale)`；填满倍数只由物理视口与照片宽高比
  计算，不读取 `fitInsetRatio`。
- 双击退出继续把 `s` 归一并清零偏移。
- 锚点枚举只保留触点锚定；缩放后使用内容边界的零余量平移上限逐轴钳制。
- 继承的 D6、D7 XCTest 分别断言左、右、上、下边缘附近双击后，对应内容边界与
  视口边严格重合。

## 4. 单击立即响应与双击撤销

已删除 `singleTapDecisionWindowMilliseconds`。保留
`doubleTapDecisionWindowMilliseconds=320` 并继续导出。

手指抬起后，手势协调器同步返回单击动作并立即调用状态机，不再创建
`DispatchWorkItem`，也不再使用 `DispatchQueue.main.asyncAfter`。第一击完成时间与
第二击到达时间之间不超过 320 毫秒且位移合格时，第二击裁决为双击。

协调器记录第一击是否实际改变了界面；第二击把“撤销第一击”和“双击进入 Nx”交给
一次状态机调用。状态机在同一同步调用内恢复第一击前的界面显隐值、记录该值并设置
双击倍率与锚点，因此不会先渲染一个撤销中间态。最终显隐、倍率、偏移和状态与从第一击
前状态直接执行双击一致。`animationsEnabled=false` 时，既有事务级禁动画和
`performWithoutAnimation` 路径继续覆盖单击与双击处理。

## 5. 实时读数

`S2ViewportMetrics` 现在显式提供并由面板直接读取：

- 当前照片像素宽高比；
- 当前视口宽高比；
- 当前照片 `aspectFill` 计算倍数；
- `max(aspectFillMultiplier, minDoubleTapScale)` 的实际双击目标倍数；
- `fitInsetRatio` 生效后的 1x 实际显示宽高。

打开实时读数时会关闭长参数面板，反向打开参数面板时也会关闭实时读数，避免两块面板
同时展开后把宽高比读数挤出真机可见区域。新增双击目标倍数文案已进入 String Catalog。

## 6. XCTest 与本地自验

新增 6 项 XCTest：

| 编号 | XCTest | 断言 |
|---|---|---|
| E1 | `testE1FirstTapProducesImmediateSingleTapAction` | 第一击同步产出单击动作，状态机立即切换显隐 |
| E2 | `testE2SecondTapWithinDecisionWindowRevertsAppliedSingleTap` | 第二击在 320 毫秒内到达时撤销已生效单击并裁决为双击 |
| E3 | `testE3TapAfterDecisionWindowStartsNewImmediateSingleTap` | 超窗下一击作为新的立即单击 |
| E4 | `testE4RevertedSingleTapThenDoubleTapMatchesDirectDoubleTap` | 撤销后双击与直接双击的最终状态完全一致 |
| E5 | `testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale` | 照片、视口宽高比及目标倍数均为计算值 |
| E6 | `testE6ReadingsAndParameterPanelsAreMutuallyExclusive` | 读数不会被长参数面板挤出 |

继承并继续保留 IC-056 的 D1～D8，其中 D1～D3 覆盖 1x 内缩与作用域，D4～D5
覆盖倍率取大及与内缩无关，D6～D7 覆盖四边贴齐，D8 覆盖退出归一。静态 XCTest
总数由 312 增至 318。

本地执行：

```powershell
.\Scripts\verify-IC-20260815-057.ps1
```

在安装 Xcode 且有可用 iPhone 模拟器的 macOS 上执行完整 XCTest：

```powershell
.\Scripts\verify-IC-20260815-057.ps1 -执行XCTest
```

专项脚本会检查基线和独立分支、318 项静态测试门槛、D1～D8、E1～E6、参数增删、
倍率公式、单一锚点、零余量钳制、方向归一、1x 渲染接线、立即单击路径、原子撤销、
禁动画路径、读数字段与可见性、String Catalog、变更白名单、禁止文件、
`git diff --check` 和仓库结构门禁。

本次 Windows 本地结果：**62 项检查全部通过**；静态 XCTest 总数为 **318**；
String Catalog 条目与产品源码引用均为 **149**；用户可见硬编码残留为 **0**；
`git diff --check` 与仓库结构门禁通过。未请求、也未执行 XCTest。

## 7. 变更边界

变更文件限定为：

- `PhotoCleanupMVE/Core/S2StateMachine.swift`
- `PhotoCleanupMVE/Features/S2/S2Calibration.swift`
- `PhotoCleanupMVE/Features/S2/S2View.swift`
- `PhotoCleanupMVE/Localizable.xcstrings`
- `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`
- `Scripts/verify-IC-20260815-057.ps1`
- `selfcheck_IC-057_report.md`

未修改任何 `SPEC-*.md`、`Decision_log.md`、S1、S3、S4、S5、图像请求策略、翻页、
标记或相册行为；未执行推送、合并、强制推送、PR、签名或账号操作。

## 8. 截断输入的执行假设

下发正文在第 11 条“`doubleTapDecisionWindowMilliseconds` 保留，出厂值”后截断。
本实现按既有出厂配置保留 `320` 毫秒；读数按任务目标和真机反馈补齐照片／视口宽高比、
填满倍数、实际双击目标倍数与 1x 显示尺寸。若原下发正文的后半段指定不同数值或额外
字段，应以补发正文为准调整。
