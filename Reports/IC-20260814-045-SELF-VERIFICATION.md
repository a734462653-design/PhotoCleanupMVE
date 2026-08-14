# IC-20260814-045 自验报告

## 一、任务与当前结论

- 任务 ID：`IC-20260814-045-contract-alignment-s3-route`
- 上游证据任务：`IC-20260814-043`、`IC-20260814-044`
- 任务基线：`f962dc8e81460f897df71e370b465806e830272f`
- S3/S4 权威输入：`SPEC-S3-S4-20260813.v7.md`
- S3/S4 输入 SHA256：`BED82109BE905466FEFF2A915D290E7FE98B5179801F6F475995CBED468AD786`
- S1 权威输入：`SPEC-S1-20260813.v3.md`
- S1 输入 SHA256：`F2565629CE6E9BD1ABB7C6841C73460C3E7E8F252A21A70D6E01893B87189238`

S3 现已保存进入时收到的来源整理会话标识，并在离开确认页的瞬间形成元素唯一、允许为空的当前待删集合。`CleanupCoordinator` 是唯一调用 `SessionStore.applyS3Return` 的产品层对象；`S3StateMachine` 不引用也不改写 `SessionStore`。会话标识和子集校验通过后，协调器一次性接收 043 已实现的 `M/F/D_全部` 交集结果，并把路由切换到新增的 `.upstream` 落点。

新增路由没有接入 S1 页面：工程内仍不存在 `Features/S1/` 文件，应用入口对 `.upstream` 使用 `EmptyView`，只保留落点选择。既有 `loading`、`confirmation`、`execution`、`completion`、`finished` 五个枚举声明逐字保留。

Windows 静态自验、范围门禁与 Git blob 比对已在实现提交的干净临时工作树执行：377 项检查全部通过，0 项失败。当前机器没有 Xcode，运行态测试、Release 构建和未签名 IPA 由推送后的 macOS CI 验证。CI 结果待本次推送回填。

| 统计项 | 数量或结果 |
|---|---:|
| 基线 XCTest | 203 |
| 新增 XCTest | 5 |
| XCTest 总数 | 208 |
| 失败 | 待 CI |
| unexpected | 待 CI |

## 二、实现与契约对应

| 契约要求 | 实现位置 | 自验依据 |
|---|---|---|
| 来源整理会话标识等于进入 S3 时收到的值 | `S3StateMachine.sourceSessionID` 与 `makeUpstreamReturn()` | 构造时保存不可变值；返回时原值写入 `S3UpstreamReturn`。 |
| 返回时的当前待删集合元素唯一、允许为空 | `S3UpstreamReturn.currentPendingDeletionAssetIDs` | 类型为 `Set<String>`；返回瞬间由 `Set(assetIDs)` 形成。 |
| S3 不直接改写会话层 | `S3StateMachine.swift` | 文件中不存在 `SessionStore` 或 `applyS3Return` 引用。 |
| 由协调器调用 043 的 2c 路径 | `CleanupCoordinator.handleS3Return` | 协调器把 S3 返回值转换为 `SessionStore.S3Return`，并调用 `store.applyS3Return`。 |
| 会话标识不匹配不得更新 | `SessionStore.applyS3Return` 的既有守卫；协调器只在返回 `true` 后赋回 | 专项测试同时断言完整 `SessionStore` 不变且路由仍为 `.confirmation`。 |
| 返回上游落点 | `CleanupRoute.upstream` | 仅成功接收返回时选择；无 S1 文件或页面接入。 |
| 会话层进入 S3 | `CleanupCoordinator.enterConfirmation` | 校验提交会话、总集合和描述符唯一性后，将提交会话标识传入 S3。 |
| 会话结束清理 | `CleanupCoordinator.finishSession` | 既有结束流程附带清空进程内 `sessionStore`，`finished` 路由含义不变。 |

## 三、新增编号 XCTest

新增测试独立位于 `PhotoCleanupMVETests/S3ReturnRouteTests.swift`，没有并入或修改三个既有状态机测试文件，也没有修改 `SessionStoreTests.swift`。

| 编号 | XCTest 方法 | 覆盖内容 |
|---|---|---|
| IC045-001 | `testIC045_001ProperSubsetShrinksEveryRangeThroughCoordinator` | 直接断言 S3 返回的两个字段；真子集返回后逐个断言两个范围的 `M[r]` 与 `D_全部`。 |
| IC045-002 | `testIC045_002EmptyReturnClearsSessionSelections` | 空集返回后全部 `M[r]` 为空、`F` 清空、`D_全部` 为空。 |
| IC045-003 | `testIC045_003UnchangedReturnPreservesMAndF` | 返回集合等于进入集合时，完整 `SessionStore` 与返回前逐值相等。 |
| IC045-004 | `testIC045_004MismatchedSourceSessionDoesNotUpdateStore` | 错误来源会话返回 `false`，会话层不变且不迁出确认页。 |
| IC045-005 | `testIC045_005SharedAssetIsRemovedFromAllRanges` | 同一被移除资产横跨月、年、相册三个范围时，三个 `M[r]` 同步移除该资产，其他资产保留。 |

静态计数预期如下：

| 测试文件 | 方法数 |
|---|---:|
| `CollectionInvariantTests.swift` | 16 |
| `CoverageGapTests.swift` | 36 |
| `S3ReturnRouteTests.swift` | 5 |
| `S3StateMachineTests.swift` | 22 |
| `S4StateMachineTests.swift` | 45 |
| `S5StateMachineTests.swift` | 45 |
| `SessionStoreTests.swift` | 14 |
| `SnapshotInvariantTests.swift` | 18 |
| `TransitionTableGuardTests.swift` | 1 |
| `VolumeFormattingTests.swift` | 6 |
| **合计** | **208** |

## 四、硬验收 Git blob 基线

专项脚本同时比较任务基线、当前 `HEAD` 与工作树的 Git blob。以下文件必须保持本卡基线值：

| Git blob | 受保护路径 |
|---|---|
| `091358b6a1d198b0fec4c3709db49694cef7b3ef` | `PhotoCleanupMVETests/S3StateMachineTests.swift` |
| `54740d5a74a9f958ac2534e188e1da763e7034a6` | `PhotoCleanupMVETests/S4StateMachineTests.swift` |
| `08916b1869dc920a02fda63543ae86a78a03d834` | `PhotoCleanupMVETests/S5StateMachineTests.swift` |
| `17d36192898a3d584df37a7e3efaf9c088045789` | `PhotoCleanupMVE/Core/SessionStore.swift` |
| `7bb23d64b61a5c4b962d182f45cb26732126f571` | `PhotoCleanupMVETests/SessionStoreTests.swift` |
| `0186402740366679914fe394e4c3c35ea2819eb0` | `PhotoCleanupMVE/Services/PhotoLibraryService.swift` |
| `38508e188d8efb022c2ec9082602e5358d9cd544` | `PhotoCleanupMVE/Core/S4StateMachine.swift` |
| `4683c137b912bc1b2bc01f0fd19238d0bf091059` | `PhotoCleanupMVE/Core/S5StateMachine.swift` |
| `cc5dec866fc96f17ea7cfa9aca97fad541bad94d` | `.github/workflows/ci.yml` |
| `63e215a769effdbcc4cefb0aad52d55b0042e794` | `Scripts/selfcheck.ps1` |

七个 `Scripts/verify-IC-20260812-*.ps1` 的基线 blob：

| Git blob | 路径 |
|---|---|
| `2878c9937f28c17cfb512a1fba45e6a44dfad0a6` | `Scripts/verify-IC-20260812-010.ps1` |
| `d59ea127213bb409e840c58d28b61f34e84e4c40` | `Scripts/verify-IC-20260812-011.ps1` |
| `10ba37dce9556e4248c28f3ff391355dcb83bc43` | `Scripts/verify-IC-20260812-014.ps1` |
| `efd5fc0c687be254e8672b1c67c124c2ef54e967` | `Scripts/verify-IC-20260812-019.ps1` |
| `f191b52715f3744d1f3dbef3973b3617a6540a16` | `Scripts/verify-IC-20260812-021.ps1` |
| `480400926bbbc6e90001b9fe4044a11995204f3e` | `Scripts/verify-IC-20260812-023.ps1` |
| `20c8a7d155bf50fdac9e9bc23631c02f71357ab2` | `Scripts/verify-IC-20260812-024.ps1` |

`Features/S1/` 在任务基线和当前交付中均为 0 个 Git 路径。

## 五、仓库外 SPEC 保护

任务开始时对仓库外、项目目录之外全部 `SPEC*.md` 形成确定性清单，算法为“相对路径、制表符、文件 SHA256、LF”，按完整路径排序后再计算清单 SHA256：

| 项目 | 基线值 |
|---|---|
| SPEC 文件数 | 39 |
| 清单 SHA256 | `060383EF4F6BE7D6853FEB1223CB263A3B52463D9F1342ECFA55206004A40B48` |

专项脚本会复算该清单，因此除了两份权威输入的独立摘要检查外，也会拒绝任意其他 SPEC 文件的新增、删除、改名或内容变化。

## 六、TRACEABILITY 更新

`Reports/TRACEABILITY-S3-S5.md` 已完成以下同步：

1. 文件内所有 S3/S4 实现基线引用从 `SPEC-S3-S4-20260812.v6.md` 切换为 `SPEC-S3-S4-20260813.v7.md`，旧名命中数应为 0。
2. 因 v7 在文件头增加两行版本说明、并在共同规则插入一条，230 条既有 S3/S4 追踪行的规格行号均同步校正。
3. 新增 `C34-231`，逐字记录 v7 第 29 行返回条款，并映射本卡五个专项测试。
4. 脚本逐行比较 231 条 S3/S4 正向追踪原文与 v7 指定行；任何行号或原文不一致都会失败。

矩阵使用 `C34-231` 承载增量条款，没有重编号既有 `C34-001` 至 `C34-230`，从而不破坏既有测试和反向映射中的稳定编号。

## 七、改动范围

本卡完成态只允许以下九个路径相对任务基线发生变化：

1. `PhotoCleanupMVE.xcodeproj/project.pbxproj`
2. `PhotoCleanupMVE/App/CleanupCoordinator.swift`
3. `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift`
4. `PhotoCleanupMVE/Core/S3StateMachine.swift`
5. `PhotoCleanupMVETests/S3ReturnRouteTests.swift`
6. `PhotoCleanupMVETests/TransitionTableGuardTests.swift`（仅把运行时追踪规格名的两处 v6 固定断言同步为 v7）
7. `Reports/TRACEABILITY-S3-S5.md`
8. `Scripts/verify-IC-20260814-045.ps1`
9. `Reports/IC-20260814-045-SELF-VERIFICATION.md`

脚本要求改动集合与上述九项完全相同；完成态还要求工作树干净、所有九项均被 Git 追踪、未跟踪条目为 0。

## 八、自验脚本与当前结果

提交前执行：

```powershell
& ./Scripts/verify-IC-20260814-045.ps1 -允许未提交交付物 -允许待回填CI
```

CI 回填后在干净工作树执行：

```powershell
& ./Scripts/verify-IC-20260814-045.ps1
```

专项脚本除本卡契约与测试断言外，还执行通用 `selfcheck.ps1`、用户可见硬编码扫描、全量 SPEC 清单摘要、允许改动白名单、受保护 blob、XCTest 静态计数、工程源码阶段引用、追踪矩阵逐行原文比对及 `git diff --check`。若本机存在 Xcode，还会调用 `Scripts/test-xcode.sh` 执行全量 XCTest。

| 本地检查 | 当前结果 |
|---|---|
| 专项静态自验 | 377 项检查通过，0 项失败 |
| 通用结构自验 | 通过 |
| 用户可见硬编码残留 | 0 |
| 当前 XCTest 静态计数 | 208 |
| 追踪矩阵 v7 正向行原文比对 | 231/231 一致 |
| `git diff --check` | 通过 |

## 九、CI 证据

| 项目 | 结果 |
|---|---|
| 全量 XCTest | CI 结果待本次推送回填。 |
| 失败 | 待 CI |
| unexpected | 待 CI |
| Release 构建 | CI 结果待本次推送回填。 |
| 未签名 IPA | CI 结果待本次推送回填。 |
| 受验提交 | CI 结果待本次推送回填。 |
| CI 运行 | CI 结果待本次推送回填。 |
| CI 链接 | CI 结果待本次推送回填。 |

## 十、完成边界

本卡到 `.upstream` 落点选择即止。未创建 S1 文件、未实现 S1 页面、未把 `.upstream` 接到 S1 视图，也未扩展到 S1 内部路由。
