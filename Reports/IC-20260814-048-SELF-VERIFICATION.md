# IC-20260814-048 自验报告

## 一、任务、输入与结论

- 任务 ID：`IC-20260814-048-full-flow-wiring`
- 上游证据任务：`IC-20260814-043`、`IC-20260814-045`、`IC-20260814-046`、`IC-20260814-047`
- 任务基线：`2d1097e99ddc4b5c5aedca3281edf5d8664d0272`
- `SPEC-S1-20260814.v4.md`：`9AAE723EBB565FD631C8E904EB1FC5598799AD9B132C4244C6198E64C0A1CB5D`
- `SPEC-S2-20260813.v13.md`：`25741959F965B8D9438F7265745D70EE60339A6865E1763BDE71912782BED1D8`
- `SPEC-S3-S4-20260813.v7.md`：`BED82109BE905466FEFF2A915D290E7FE98B5179801F6F475995CBED468AD786`
- `SPEC-S5-20260812.v5.md`：`10CD2B7829126ABBD8FB66091B21169E698868CA67E345D0EABBA39D8D6221B7`

四份仓库外只读输入的 SHA256 均已逐项核对，与任务卡一致。当前实现已把 S1、S2 接入应用路由，并完成 S1 → S2 → S3 → S4 → S5 → S1 的页面接线。旧 `.upstream` 与 `.finished` 枚举仍作为兼容事件落点保留，但应用对两者均实际渲染 S1；这样既落实 S3／S5 返回 S1，也不破坏既有路由事件语义。

最终结论：六条路径、契约传递、S3 来源分组、S2 临时图像策略与全部静态门禁均已接通并通过验证。受验提交 `12b20b80469b03bdc8b6172c4a7af85122dd7734` 的 macOS CI #32 为 `completed / success`；273 项 XCTest 全部通过，Release 未签名构建成功，并产出可下载 IPA。

| 统计项 | 数量或结果 |
|---|---:|
| 基线 XCTest | 267 |
| 本卡新增 XCTest | 6 |
| 静态 XCTest 总数 | 273 |
| 失败 | 0 |
| unexpected | 0 |

## 二、六条路径与契约传递

### IC048-001：启动 → S1

授权请求完成后，`CleanupCoordinator` 调用与专项测试相同的 `enterS1(sessionID:)` 路由入口，建立新的非空 `sessionID`、空 `M`、空 `K`、空 `F`，并迁至 `.s1`。未完成的 S4／S5 持久化会话仍优先按既有规则恢复，不被启动落点改写。

### IC048-002：S1 → S2

`S1View` 点击范围项后交出 `S1ToS2Handoff`，协调器逐项传给 `S2EntryContext`：

1. 整理会话标识；
2. 范围显示信息（范围标识、显示名、资产总数）；
3. 有序资产标识列表 `A`；
4. 当前资产标识 `c`；
5. 待删集合 `D`；
6. 会话级合并待删总数的只读刷新来源。

第六字段没有复制成整数快照。S2 内 `D` 变化时，协调器立即同步 S1 会话层的范围集合与首次归属映射，徽标随后从同一会话层重新读取去重总数。

### IC048-003：S2 返回 → S1

S2 返回按钮先形成 `S2ExitPayload`。协调器校验本地续接快照与五字段返回载荷属于同一个 `A`、范围和瞬时 `D/c`，再调用既有 `SessionStore.applyS2Return` 原子写回：

1. 来源整理会话标识；
2. 来源范围标识；
3. 待删集合 `D` → `M[r]`；
4. 当前资产标识 `c` → `K[r].c`；
5. 最远到达资产标识 → `K[r].p`，并写入当前排序。

任一校验失败时不迁出 S2。成功后清理 S2 路由暂存并迁至 `.s1`。

### IC048-004：S1 或 S2 垃圾桶 → S3

S1 垃圾桶直接使用 `S1StateMachine.makeS3Submission()`。S2 垃圾桶先执行与返回按钮相同的五字段写回，再由 S1／会话层形成同一份 S3 提交。`enterConfirmation` 新增分组契约守卫，逐项校验：来源会话、总表唯一性、描述符全集、范围标识唯一性、组名非空、组内唯一且非空、各组互斥并完整覆盖总表、组计数之和等于待删总数。

### IC048-005：S3 返回 → S1

S3 仍只交回来源整理会话标识和返回瞬间的当前待删集合。协调器先在局部 `SessionStore` 副本执行全范围交集与 `F` 清理；存在 S1 页面状态机时，再通过新增的路由接收方法对其会话副本执行同一原子更新。两份结果逐值一致后才选择 `.upstream`。应用把 `.upstream` 固定渲染为 S1，因此所有 S3 返回都实际回到 S1。

### IC048-006：S5-EXIT → S1

S5-T0 或 S5-U 的既有 `.exitCleanup` 效果仍由 `leaveCompletion()` 接收。持久化记录清除成功后，协调器使旧页面对象、扫描任务、描述符、`M`、`K`、`F` 与旧 `sessionID` 整体失效，生成不等于旧值的新 UUID 会话，重建 S1，并选择兼容落点 `.finished`。应用把 `.finished` 固定渲染为新 S1；不会自动提交、扫描或进入 S2。

## 三、S3 来源分组展示

`CleanupCoordinator.s3Groups` 保存本次 S3 提交中的分组划分。`S3View` 按 `sourceRangeID` 逐组展示，每组标题通过 String Catalog 显示范围名与当前组内资产数，组内资产顺序来自提交契约；资产从 S3 移除后，显示数量由当前 S3 资产集合即时重算。

头部使用 `s3.scope.source_summary.placeholder` 填充 v7 具名的“当前范围说明”位置，明确显示本轮来源范围数。该目录键和值均显式保留“文案待定”标记，不把 SPEC-S3 的最终文案未定项伪装成定案。分组名称和组内计数是 SPEC-S1 v4 决策 9 的确定内容。

## 四、S2 图像策略临时实现

文件 `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift` 在源码中逐字标注：这是 **SPEC-S2 v13 未定项 8 的临时占位实现，仅用于 IC-048 真机接线，不是定案**。

- 注入边界：`S2PhotoImageRequesting` 协议定义可替换对象；应用层建立 `S2TemporaryPhotoKitImageStrategy`，再通过 S2 的 `photoContent`／`stripItemContent` 闭包注入。`S2View.swift` 没有 `PHImageManager`、`PHImageRequestOptions` 或直接 `requestImage` 调用。
- 请求方式：使用 `PHImageManager.requestImage(for:targetSize:contentMode:options:)`；目标像素由实际视图尺寸 × 屏幕比例 × 当前 S2 缩放倍数形成；`contentMode = .aspectFit`、`deliveryMode = .highQualityFormat`、`resizeMode = .fast`、`version = .current`。
- 缩放请求：临时接线选择上游已有枚举值 `.everyScaleChange`，视图请求键随资产、目标尺寸或缩放倍数改变而更新；这只描述本次占位行为，不解决未定项 8。
- 降质预览图：本次 **不显示降质预览图**。临时配置为 `.finalImageOnly`，即使 PhotoKit 回调被标为 degraded 也不替换画面，只接收最终图。
- 网络边界：`isNetworkAccessAllowed = false`，不会为 iCloud 原件发起网络下载；仅显示设备本地可由 PhotoKit 返回的真实图像。

S2 的其他未定项没有新参数。运行时只引用 IC-047 已存在并明确标为“合成预览夹具”的 `S2PreviewData.parameters`；本卡未新增、修改或标定任何手势、缩放、横栏尺寸或阈值。`S2UndecidedItems` 全部仍为 `.unresolved`。

## 五、debugAssetLimit

`CleanupCoordinator.debugAssetLimit` 当前值仍为 **300**。S1 接管启动后，产品源码中 `limit: Self.debugAssetLimit` 调用数为 0；范围读取由 S1 的 PhotoKit 范围服务执行。因此该常量目前是保留的旧调试入口值，**不限制也不影响本卡 S1 → S2 → S3 → S4 → S5 → S1 的全流程真机测试**。通用 `selfcheck.ps1` 已同步把旧的“必须调用一次调试取样”门禁改为“S1 接管后调用数必须为 0”。

## 六、状态机与受保护文件

### 1. 未变化文件

下列产品状态机相对任务基线的 Git blob 完全一致：

- `S2StateMachine.swift`
- `S3StateMachine.swift`
- `S4StateMachine.swift`
- `S5StateMachine.swift`

下列受保护文件同样逐字未变：

- `SessionStore.swift`
- `SessionStoreTests.swift`
- S1／S2／S3／S4／S5 五个既有状态机测试文件
- `.github/workflows/ci.yml`

### 2. S1 仅新增路由调用方法

`S1StateMachine.swift` 的既有状态定义、加载判定、迁移方法、排序规则和输入语义逐字保持任务基线。专项脚本把两个新增方法区块移除后，将剩余全文与基线逐字比较：

- `applyS2PendingDeletionChange(_:entryContext:)`：只供 S2 路由在实际标记发生时同步 `M/F`，不写 `K`，不改变任何 S1 基础状态或迁移规则。
- `applyS3Return(_:)`：只供 S3 返回路由调用既有 `SessionStore.applyS3Return`，不增加 S1 状态，不改变任何既有事件语义。

`S2View.swift` 只把既有 `S2PreviewData` 的访问级别从文件私有改为模块内可见，使协调器能复用同一合成夹具；六状态、手势代码及所有数值逐字未改。

## 七、六项编号 XCTest

新增文件：`PhotoCleanupMVETests/FullFlowRoutingTests.swift`。

| 编号 | XCTest 方法 | 完整断言 |
|---|---|---|
| IC048-001 | `testIC048_001AuthorizedStartupEntersS1WithFreshSession` | 授权完成后的实际路由入口、S1 落点、非空稳定会话标识、空 `M/K/F`。 |
| IC048-002 | `testIC048_002S1RangeTapPassesAllSixFieldsToS2` | S1 → S2 六字段逐值一致；S2 标记后第六字段从 1 实时刷新为 2。 |
| IC048-003 | `testIC048_003S2BackWritesAllFiveFieldsIntoMAndK` | S2 五字段逐值、返回落点、`M[r]` 与 `K[r].c/p/O` 原子结果。 |
| IC048-004 | `testIC048_004S1AndS2TrashPassMergedSetAndGroupsToS3` | 分别走 S1 和 S2 垃圾桶；S2 先交回五字段；两路 S3 的会话、总表、组名、组内表、各组计数及计数和完全一致。 |
| IC048-005 | `testIC048_005S3BackIntersectsEveryRangeAndReturnsToS1` | S3 两字段、跨两个范围的交集结果、`F` 清理、`D_全部`、S1 实际页面对象与兼容落点。 |
| IC048-006 | `testIC048_006S5ExitEndsSessionAndRebuildsS1Session` | 通过真实持久化 S5-T0 恢复与 `leaveCompletion()` 触发 S5-EXIT；旧 `M/K/F` 非空、新 `M/K/F` 全空、sessionID 重建、持久化清除、S1 重建。 |

新测试没有 `XCTSkip`。静态方法计数为基线 267 + 新增 6 = 273。

## 八、本地化、动画与范围门禁

| 验收项 | 当前结果 |
|---|---|
| String Catalog | 106 个目录键、106 个产品源码引用键，双向一致。 |
| 用户可见硬编码 | 0。 |
| 产品源码动画 API | 0；未新增 `withAnimation`、`.animation`、转场、匹配几何、阶段或关键帧动画 API。 |
| S2View 直接图像请求 | 0。 |
| 新增网络代码 | 0；PhotoKit 临时策略显式禁止网络取图。 |
| `SessionStore.swift` 及其测试 | 未修改。 |
| SPEC 文件 | 仓库外只读；四份摘要均保持任务给定值。 |
| `git diff --check` | 通过。 |
| 未跟踪条目 | 完成态为 0。 |

本卡相对任务基线的允许改动严格限定为：工程文件、协调器、应用入口、S1 两个路由方法、S2 临时图像策略、S2 预览夹具访问级别、S3 分组视图、String Catalog、新专项测试、通用启动门禁、专项脚本和本报告。没有第三方依赖、账号操作、动画、调参面板或参数标定。

## 九、自验脚本与当前结果

提交前执行：

```powershell
& ./Scripts/verify-IC-20260814-048.ps1 -允许未提交交付物 -允许待回填CI
```

CI 回填并提交后，在干净工作树执行：

```powershell
& ./Scripts/verify-IC-20260814-048.ps1
```

脚本核验四份 SPEC 摘要、十二路径改动白名单、受保护 Git blob、S1 基线全文减新增方法后的逐字一致、六条接线路由、分组覆盖、图像策略注入、禁止联网、动画命中、`debugAssetLimit` 影响、273 项静态计数、六个编号、工程引用、String Catalog、用户可见硬编码、通用 selfcheck、diff 与完成态工作树。

本地结果：CI 回填前的提交前模式执行 100 项检查，0 项失败；受验提交的干净树以“允许待回填 CI”模式执行 102 项检查，0 项失败；报告回填提交后的完成态模式执行 106 项检查，0 项失败。三次退出码均为 0；通用 `selfcheck.ps1` 与用户可见硬编码扫描均通过。

## 十、启动落点探针

探针条件是“若接入 S1 作为启动落点导致任何既有测试失败，立即停止”。首轮 CI #31 在 273 项中出现 5 条失败断言，全部集中于本卡新增的 `IC048-003` 一个测试方法；267 项既有测试全部通过。日志证明失败原因是新增夹具错误地假设“上滑标记后停留当前资产”，而既有 S2 语义会自动前进，因此不属于启动落点影响，也未触发探针。

修正提交 `12b20b80469b03bdc8b6172c4a7af85122dd7734` 只调整该新增测试的手势序列和预期：先到达最远资产 A，再通过底栏返回当前资产 B，以分别断言 `c=B`、`p=A`；没有修改产品代码、既有测试或任何状态机。随后 CI #32 的 273 项全部通过，确认启动落点变更未造成既有测试失败。

## 十一、CI、提交与 IPA 证据

- 受验提交：`12b20b80469b03bdc8b6172c4a7af85122dd7734`；实现主提交为 `dd203c8b7a0fe83e46455bab7cf59b85686aab0a`。
- Git push：两次提交均已成功推送至 `origin/main`。
- CI 运行：[`iOS 构建与自验 #32`](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31825190791)，运行 ID `31825190791`；作业 [`构建、XCTest 与未签名产物`](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31825190791/job/94847548272)，作业 ID `94847548272`。
- CI 终态：`completed / success`；运行总耗时 8 分 41 秒，作业耗时 8 分 37 秒。
- 全量 XCTest：273 项，0 失败、0 unexpected；基线 267 + 本卡新增 6；日志终行 `** TEST SUCCEEDED **`。测试套件汇总为 `Executed 273 tests, with 0 failures (0 unexpected)`。
- Release 构建：成功；使用 Xcode 16.4、`Release`、`iphoneos`、arm64，关闭签名要求；日志终行 `** BUILD SUCCEEDED **`，步骤耗时 41 秒。
- 未签名 IPA：产出成功；CI 还执行压缩包完整性检查，结果为无压缩数据错误，并用 1 秒上传为 Actions 产物。
- IPA 原文件：`PhotoCleanupMVE-unsigned.ipa`，429435 字节，SHA-256 `45b7f3e455abdc7342dee6523b7c6df78089143ee35af3f7780094c74903028d`。
- Actions 产物：[`PhotoCleanupMVE-unsigned-12b20b80469b`](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31825190791/artifacts/9228757120)，产物 ID `9228757120`，页面显示 420 KB，Actions 包装产物摘要 `sha256:414230279a89d029e143cfadd7b0e702a8013eca2bde60b6985edb684d8341fa`。该摘要是 Actions 包装产物的摘要，不是上一项 IPA 原文件的 SHA-256。

## 十二、完成边界

本卡完成后立即停止。未实现调参面板，未引入动画，未标定任何参数，未把任何 unresolved 占位改成产品定案。
