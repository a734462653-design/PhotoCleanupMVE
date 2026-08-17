# IC-068 自验报告

## 结论

IC-068 真机过渡诊断录制已在分支 `feature/ic-068-ondevice-diagnostic` 完成。代码与测试提交为 `868f8b6f9ff323496b50dbe8a4a40e50cdd70705`，继承提交为 `b453b68afa340aa14823b4d6b3172720f57b75f6`。

GitHub Actions [iOS 构建与自验 #110](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/32054123710) 第一次尝试即成功：执行 408 项 XCTest、0 失败，测试步骤真实退出码为 0，Release 未签名 IPA 构建并上传成功。尝试次数为 1/3。

本卡只交付诊断能力和格式样例，没有执行三个真机场景，也没有对根因下结论，更没有修复动画或闪烁问题。

## 埋点覆盖清单

### 逐帧采样

| 要求 | 实现与检查 |
|---|---|
| 同一单调时钟 | 所有帧和离散事件均通过同一录制协调器读取 `CACurrentMediaTime()`；导出时统一换算为相对开始时刻。 |
| 不低于 60Hz | `CADisplayLink.preferredFrameRateRange` 的 minimum 固定为 60，preferred 使用设备最大刷新率；导出头部写明下限。 |
| 最长五秒 | 主队列五秒停止任务与 display link 时间检查双重停止；停止后保留记录。 |
| 动画键 | 每帧输出 `photoLayer.animationKeys()` 完整数组；`nil` 归一为空数组并显式输出 `[]`。 |
| 模型与 presentation frame | 每帧分别输出 `modelFrame`、`presentationFrame`，后者不存在时仍输出字段和值 `nil`。 |
| transform 六元组 | 每帧输出 `a,b,c,d,tx,ty`。 |
| 原生滚动几何 | 每帧输出 `zoomScale`、`contentOffset`、`contentSize`。 |
| 状态 | 每帧输出当前 `V` 与当前 `s`。 |

### 离散事件

| 事件 | 来源标识与覆盖方式 |
|---|---|
| SwiftUI 状态发布 | `S2StateMachine.handleSingleTap @Published(V)`；在状态变更后、SwiftUI 桥更新前记录前后值。 |
| `updateUIView` | 实际桥方法为 `S2NativePhotoPager.updateUIViewController`；记录本次调用前后照片几何写入计数差。 |
| 内层 `layoutSubviews` | `S2NativeZoomScrollView.layoutSubviews`。 |
| 外层 `viewDidLayoutSubviews` | `S2NativePagerViewController.viewDidLayoutSubviews`。 |
| 照片 frame/transform 写入 | 产品源码中的照片 transform，以及通过 bounds/center 形成 frame 的写入，均经过 `writePhotoGeometry(reason:mutation:)`；事件含最终 frame、六元组和具体 reason。 |
| 动画增删调用 | 当前 S2 产品源码没有显式 `add(animation:)` 或 `removeAnimation(forKey:)`；现有两处 `removeAllAnimations()` 均经统一入口记录，operation 与 `key=*` 不省略。 |
| `CATransaction` 提交 | 唯一显式 `CATransaction.commit()` 在捏合起始准备路径提交后记录边界。 |
| IC-067 抑制生效 | 外层布局因 `pendingPresentationTapPageIndex` 跳过当前页照片写入时，每次记录页索引。 |

## 行为不变证明

1. 录制关闭时，协调器的事件方法均在首个 guard 返回；不会创建 display link、计时任务或导出内容。`testIC068G47RecorderOffHasNoDiagnosticSideEffect` 断言关闭态记录数、几何写入计数和导出文本均为零，同时统一入口内的原几何赋值仍生效。
2. 统一入口只同步执行原赋值闭包，再读取最终 layer 值用于记录；没有改赋值值、顺序、事务或动画参数。`testIC068G48UnifiedPhotoGeometryWriteIsExactlyEquivalent` 以零容差比较收敛前直接赋值和统一入口的 bounds、center、frame、UIView transform 与 layer affineTransform，结果完全相等。
3. IC-067 的 CI #109 在 `b453b68` 执行原有 404 项 XCTest、0 失败；本卡只新增四项测试，CI #110 执行 408 项、0 失败。因此原 404 项断言结果仍全部通过。
4. 相对继承提交，禁改范围中的 `S2TemporaryPhotoImageStrategy.swift`、S1、S3～S5 均为 0 差异；未修改规格、Decision Log、图片请求策略、生产视图层级、宿主尺寸、几何参数或动画参数。

## 验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G47 | 通过 | 新增关闭态零副作用断言；原 404 项 XCTest 在 #110 全部继续通过。 |
| G48 | 通过 | 新增统一入口零容差等价断言；frame 与 transform 精确相等。 |
| G49 | 通过 | `testIC068G49ExportContainsCompleteUnifiedSchema` 检查全部逐帧字段、来源/详情字段、空 `animationKeys=[]` 及全部离散事件族。 |
| G50 | 通过 | `testIC068G50UnifiedClockRecordsAreStrictlyOrdered` 以相同和回退的测试时钟读数验证记录时间仍严格递增；导出头部固定声明 `CACurrentMediaTime()`。 |
| G51 | 通过 | IC-063 G1～G12、IC-064 G13～G25、IC-065 G26～G35、IC-067 G36～G46 所在的原 404 项测试未删除或改名，并在 #110 全部通过。 |
| G52 | 通过 | CI #110：`Executed 408 tests, with 0 failures (0 unexpected)`，高于 404 项下限。 |

说明：仓库中的 `verify-IC-20260816-063.ps1` 是 IC-063 v2 的分支与 v14 规格专用交付脚本，会拒绝本卡分支和本卡报告路径，不能作为 IC-068 的 G51 执行器；其前置结构/本地化自验通过。G51 采用 #109 与 #110 的完整 XCTest 集合对比判定。

## CI 与产物

| 项目 | 结果 |
|---|---|
| CI | #110，运行 ID `32054123710` |
| 代码提交 | `868f8b6f9ff323496b50dbe8a4a40e50cdd70705` |
| 尝试次数 | 1/3 |
| 总结论 | success |
| XCTest 步骤 | success；真实退出码 0 |
| XCTest | 408 项，0 失败，0 unexpected |
| XCTest 摘要耗时 | 20.655 秒；括号总时长 37.724 秒 |
| IPA 文件校验 | `PhotoCleanupMVE-unsigned.ipa`，689582 字节，SHA-256 `bd3b08e507c07f34549ba777829bd6db377fe19d102bb49c93af44a40c144f3e` |
| Actions Artifact | `PhotoCleanupMVE-unsigned-868f8b6f9ff3`，工件归档 689752 字节 |

工作流测试步骤先保存 `test_status`，最后执行 `exit "$test_status"`；该步骤 conclusion 为 success，故真实退出码为 0，而不是管道或报告命令的替代状态。

## 本地检查

- `Scripts/selfcheck.ps1`：退出码 0。
- `Scripts/scan-hardcoded-user-visible-strings.ps1`：退出码 0；165 个目录 key 与 165 个产品源码引用完全一致，硬编码残留为 0。
- `git diff --check`：退出码 0。
- XCTest 静态方法数：408。

## 人工回传待办

产品负责人仍需按 `export-format.md` 的 A、B、C 三个场景各录一次并回传导出文本。只有这些真机数据可用于判断动画从未创建、创建后被覆盖，或是否来自其他通道。本报告不预设 IC-068 的待验证假设为真。
