# IC-20260814-046 自验证报告

## 一、任务、输入与当前结论

- 任务 ID：`IC-20260814-046-s1-scope-entry-impl`
- 上游证据任务：`IC-20260814-043`、`IC-20260814-044`
- 权威输入：仓库外只读文件 `SPEC-S1-20260813.v3.md`
- 输入 SHA256：`F2565629CE6E9BD1ABB7C6841C73460C3E7E8F252A21A70D6E01893B87189238`
- 实际开发基线：`7fcbe9c37c66094c0c2e3c0d61315e4646fa5e3d`

已实现 S1 四状态纯状态机、按月／按年／相册／未分类范围读取服务、S1 到 S2 六字段交接结构、未接路由的 SwiftUI 入口页及四状态独立预览，并新增 18 项编号 XCTest。`S1View` 只通过回调交出数据，没有引用 `CleanupCoordinator`、`CleanupRoute`、应用入口或任何现有导航。

任务执行期间，另一张明确划分的卡 B（`IC-20260814-045`）先落地为 `7fcbe9c`，新增 5 项测试并修改本卡禁止触碰的路由相关文件。因此任务给定的 203 项是 043／044 上游基线，而本卡实际开发起点是 208 项。本报告把两者分别记录；本卡自身新增数始终为 18，最终静态总数为 226。

| 统计项 | 数量或结果 |
|---|---:|
| 任务给定上游基线 XCTest | 203 |
| 实际开发起点 XCTest | 208 |
| 本卡新增 XCTest | 18 |
| 最终 XCTest 总数 | 226 |
| 失败 | CI 结果待本次推送回填 |
| unexpected | CI 结果待本次推送回填 |

## 二、实现与规格对应

| 实现项 | 规格依据 | 实现证据 |
|---|---|---|
| 四状态 | 第二至四节 | `S1State` 明确声明 `S1-1` 加载中、`S1-2` 就绪、`S1-3` 空态、`S1-4` 失败；`L=就绪` 时按范围数派生 S1-2／S1-3。 |
| 状态变量 `L/T/O/Q` | 第二节 | `loadingState`、`groupingDimension`、`sortOrder`、`isObscured` 分别承接；`T/O` 必须由调用方显式注入，没有产品默认值。 |
| 读取迁移 | 第三、四节 | 读取成功非空、读取成功为空、读取失败分别进入 S1-2、S1-3、S1-4；重试进入 S1-1；请求代次拒绝切换 `T` 后晚到的旧结果。 |
| `T` 切换 | 第二、四节 | 任一状态切换 `T` 均清空当前范围结果并回到加载中；不改变会话层、`O` 或会话标识。 |
| `O` 切换 | 第二、四节 | 只更新排序，不改变 `L/T/M/K/O_记录/sessionID`，也不形成新读取请求。月、年范围列表翻转；相册、未分类保持读取方提供的占位顺序。 |
| 四类读取 | 第二节 | `PhotoLibraryService.s1Ranges` 对月、年、相册、未分类分别建立读取分支；按拍摄时间与稳定标识形成唯一 `A`。 |
| 相册未定边界 | 第九节 3 | 服务要求调用方显式传入 `[PHAssetCollection]`，不自行选择智能、共享、隐藏相册，也不自行规定相册顺序。 |
| 可区分失败 | 第三节 S1-4 | 失败值同时携带 `T` 与原因，区分授权未决定、拒绝、受限、有限授权策略未定、日期缺失、显示名缺失、重复标识及无效响应。页面只使用未定文案占位，不拍板失败粒度。 |
| 范围项四项信息 | 第六节 | `S1RangeRow` 同时提供显示名、精确资产总数、范围待删计数、已处理资产数；视图逐项引用四个值。 |
| 已处理方向 | 第二、六节 | 直接复用上游 `SessionStore.processedAssetIDs`；当前 `O` 与 `O_记录` 一致取前缀，不一致按当前 `A` 取后缀。 |
| 垃圾桶与徽标 | 决策 8；第六节 | 右上角入口在四状态视图结构中存在；非空时徽标只呈现 `String(badgeCount)`，其中 `badgeCount` 实时等于 `D_全部.count`。空集合使用未定项 7 的明确问号占位。 |
| S1 到 S2 六字段 | 第七节第 1 部分及 S2 v13 补充字段 | `S1ToS2Handoff` 含会话标识、范围显示信息、`A`、`c`、`D`、只读会话合并待删总数；构造前校验 `A` 非空唯一、`c ∈ A`、`D ⊆ A`。 |
| 不接导航 | 本卡范围外 | `S1View` 只接收状态机、读取闭包和数据回调；产品源码中除 `S1View.swift` 自身四个预览外没有 `S1View` 引用。 |

读取服务只调用本地 PhotoKit 读取 API，不写入照片库、不提交删除、不改变收藏或相册归属，不新增联网、账号或第三方依赖能力。

## 三、S1 到 S2 六字段约束

| 字段 | 构造方式 | 守卫 |
|---|---|---|
| 整理会话标识 | `SessionStore.sessionID` | 上游构造时已保证非空；切换 `T/O` 不替换会话层。 |
| 范围显示信息 | 当前范围的标识、显示名、精确资产总数 | 范围标识和去空白显示名非空。 |
| 有序资产标识列表 `A` | 当前范围的拍摄时间新到旧数组；`O=旧到新` 时严格反转 | 非空；元素唯一；不在 S1 交互中改写。 |
| 当前资产标识 `c` | 有续接时取 `K[r].c`，否则取 `A.first` | 必须属于 `A`。 |
| 待删集合 `D` | `M[r]`，无键时为空集 | 必须是 `A` 的子集。 |
| 会话级合并待删总数 | `D_全部.count` | 非负只读值；S1 不自行按局部增量推算。 |

本卡只形成结构与构造逻辑，没有实际跳转 S2。S2 内如何刷新该只读总数属于后续接线卡使用会话层的责任，本卡没有扩展路由权限。

## 四、编号专项 XCTest

| 编号 | XCTest 方法 | 直接断言 |
|---|---|---|
| IC046-001 | `testIC046_001InitialEntryReachesLoading` | 首次进入到达 S1-1。 |
| IC046-002 | `testIC046_002SuccessfulNonemptyReadReachesReady` | 非空成功到达 S1-2。 |
| IC046-003 | `testIC046_003SuccessfulEmptyReadReachesEmpty` | 零范围成功到达 S1-3，且 `L=就绪`。 |
| IC046-004 | `testIC046_004FailedReadReachesFailedWithDistinctReason` | 失败到达 S1-4，并保留可区分原因。 |
| IC046-005 | `testIC046_005GroupingSwitchAlwaysReturnsToLoadingAndPreservesSession` | 四状态切换 `T` 均到 S1-1；会话与 `O/O_记录` 不变。 |
| IC046-006 | `testIC046_006SortSwitchPreservesLoadingAndSessionState` | 四状态切换 `O` 均保持 `L/T/M/K/O_记录/sessionID`。 |
| IC046-007 | `testIC046_007StaleReadCompletionIsIgnoredAfterGroupingSwitch` | `T` 切换后旧读取结果不能覆盖新请求。 |
| IC046-008 | `testIC046_008RetryFromFailureCreatesNewLoadingRequest` | 只有失败态可重试，并形成同 `T` 新请求。 |
| IC046-009 | `testIC046_009LoadingFailedAndEmptyCannotFormS2Handoff` | 加载、失败、空态均不能形成 `A` 或交接。 |
| IC046-010 | `testIC046_010ProcessedAssetsUsePrefixWhenOrdersMatch` | `O=O_记录` 时取 `p` 及之前。 |
| IC046-011 | `testIC046_011ProcessedAssetsUseSuffixWhenOrderFlips` | `O≠O_记录` 时按当前 `A` 取 `p` 及之后。 |
| IC046-012 | `testIC046_012BadgeAlwaysUsesMergedDeletionSetCount` | 徽标等于去重后的 `D_全部` 数量，与 `T/O/L` 无关。 |
| IC046-013 | `testIC046_013S2HandoffContainsSixValidFields` | 六字段逐项值及 `A/c/D` 三项约束。 |
| IC046-014 | `testIC046_014InvalidAOrDRejectsS2Handoff` | 重复 `A` 或范围外 `D` 拒绝交接；无效读取进入失败而非空态。 |
| IC046-015 | `testIC046_015SortFlipsChronologicalRangesButNotAlbumRanges` | 只翻转月、年范围列表；相册顺序不被 `O` 决定。 |
| IC046-016 | `testIC046_016ObscurationBlocksInputsAndPreservesState` | `Q=呈现` 时输入失效并保持状态、范围和会话。 |
| IC046-017 | `testIC046_017S2ReturnWritesSessionWithoutChangingS1Parameters` | S2 返回原子写回 `M/K`，不改变 `L/T/O/sessionID`。 |
| IC046-018 | `testIC046_018RangeRowContainsAllFourRequiredValues` | 范围项投影含显示名、总数、待删数、已处理进度四项。 |

## 五、未定项集中声明

全部未定项的唯一声明位置为 `PhotoCleanupMVE/Core/S1StateMachine.swift` 的 `S1UndecidedItems`。每项值均为 `.unresolved`，没有布尔值、枚举选项、阈值或产品默认值。需要在独立预览中可见的占位文案由同一类型的 `localizedCopy` 集中路由到 String Catalog；这只是明确的未定占位，不表示产品决策。

| SPEC-S1 v3 第九节编号 | 集中常量 | 本卡处置 |
|---|---|---|
| 1 | `item01InitialGroupingAndSort` | 构造器强制显式注入 `T/O`，无默认值。 |
| 2 | `item02AuthorizationStates` | 服务区分状态并上报；有限授权返回“策略未定”原因，不定义页面恢复行为。 |
| 3 | `item03AlbumOrderingAndInclusion` | 相册集合及顺序由调用方显式提供；本卡不选智能、共享、隐藏相册。 |
| 4 | `item04EmptyChronologicalRanges` | 服务只返回实际读取到的可用范围，不将此实现事实标定为空月份／年份产品规则。 |
| 5 | `item05LongNameTruncation` | 未声明截断、行数或尺寸规则。 |
| 6 | `item06ZeroPendingAndProgressPresentation` | String Catalog 使用带编号的原始值占位，不标定进度条、比例或计数方案。 |
| 7 | `item07EmptyMergedDeletionTrashPresentation` | 空集合显示带问号的占位入口，不采用隐藏、禁用、显示 0 或可点击中的任何正式方案。 |
| 8 | `item08MergedDeletionSubmissionOrder` | 沿用上游稳定数据结构，不在 S1 赋予产品排序语义。 |
| 9 | `item09FailureDetailAndRetryPolicy` | 显示带编号的失败／重试占位；无自动重试或次数参数。 |
| 10 | `item10LoadingIndicator` | 显示带编号的读取中占位，不选择动画、进度或预计数量。 |
| 11 | `item11SessionPersistenceAndEnd` | 注入现有 `SessionStore`；不修改持久化或会话结束条件。 |
| 12 | `item12S2ReturnValidationFailurePresentation` | 返回布尔校验结果；不定义失败文案或恢复界面。 |
| 13 | `item13ExternalPhotoLibraryChanges` | 不增加外部变化监听或清理策略。 |
| 14 | `item14DuplicateRangeCountExplanation` | 不增加提示文案；数据口径保持范围分别计数、全局去重。 |
| 14b | `item14bS3GroupOrderingAndPaging` | 不修改 S3，不定义分组排列、折叠或分页。 |
| 14c | `item14cEmptyS3GroupPresentation` | 不修改 S3，不定义空组视觉行为。 |
| 15 | `item15EmptyAndFailureCopy` | 空态、失败态均使用带编号的本地化占位文案。 |
| 16 | `item16RecommendedCleanupArea` | 未实现推荐整理区。 |
| 17 | `item17FileSizeSort` | 未实现体积排序。 |

## 六、本地化与独立预览

- `Localizable.xcstrings` 新增 18 个 `s1.*` 条目，全部且仅含 `zh-Hans` 非空值。
- 产品源码引用键由 72 增至 90，目录条目同为 90，双向集合一致。
- 用户可见硬编码残留为 0。
- `S1View.swift` 内提供 `#Preview("S1-1")` 至 `#Preview("S1-4")` 四个独立预览。
- 预览直接构造状态机和样例范围，不调用应用入口、协调器、路由或账号／网络能力。

第三节与第六节对加载态垃圾桶的显示存在文字冲突：第三节未列入口且第五节称加载中不提供，第三节之后的第六节又明确写明“四个状态均显示”。本卡按更明确的第六节保持四状态结构中均有入口，但加载中不可触发，以同时满足可见性与迁移表的不可操作约束。

## 七、范围与保护证据

本卡允许改动严格限定为八项：

1. `PhotoCleanupMVE.xcodeproj/project.pbxproj`
2. `PhotoCleanupMVE/Core/S1StateMachine.swift`
3. `PhotoCleanupMVE/Features/S1/S1View.swift`
4. `PhotoCleanupMVE/Services/PhotoLibraryService.swift`
5. `PhotoCleanupMVE/Localizable.xcstrings`
6. `PhotoCleanupMVETests/S1StateMachineTests.swift`
7. `Scripts/verify-IC-20260814-046.ps1`
8. `Reports/IC-20260814-046-SELF-VERIFICATION.md`

工程文件只增加 S1 状态机、视图和测试各一个文件引用、分组引用及源码阶段引用，没有增加 target、依赖、签名、权限或构建设置。

下表以实际开发基线 `7fcbe9c` 为准。专项脚本同时比较基线、当前 HEAD 与工作树；三者必须逐文件相同。

| Git blob | 受保护路径 |
|---|---|
| `4256b4d3cef06ced2c0dcf8de5bc27b1ae039bb6` | `PhotoCleanupMVE/App/CleanupCoordinator.swift` |
| `7804ae89ebb32b25df8833fe2f8c61bf0ee735a6` | `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` |
| `17d36192898a3d584df37a7e3efaf9c088045789` | `PhotoCleanupMVE/Core/SessionStore.swift` |
| `7bb23d64b61a5c4b962d182f45cb26732126f571` | `PhotoCleanupMVETests/SessionStoreTests.swift` |
| `dc85e9941b1e4d37b5b55d8dadd4c6d4732e98bc` | `PhotoCleanupMVE/Core/S3StateMachine.swift` |
| `38508e188d8efb022c2ec9082602e5358d9cd544` | `PhotoCleanupMVE/Core/S4StateMachine.swift` |
| `4683c137b912bc1b2bc01f0fd19238d0bf091059` | `PhotoCleanupMVE/Core/S5StateMachine.swift` |
| `091358b6a1d198b0fec4c3709db49694cef7b3ef` | `PhotoCleanupMVETests/S3StateMachineTests.swift` |
| `54740d5a74a9f958ac2534e188e1da763e7034a6` | `PhotoCleanupMVETests/S4StateMachineTests.swift` |
| `08916b1869dc920a02fda63543ae86a78a03d834` | `PhotoCleanupMVETests/S5StateMachineTests.swift` |
| `97a1c86badd4588c0ef24e71528ba5322ea24986` | `PhotoCleanupMVETests/S3ReturnRouteTests.swift` |
| `8f307bca389563c9cb1815108ec1b739b8c6f782` | `PhotoCleanupMVE/Features/S3/S3View.swift` |
| `19572baf98e53bd49f347945562010a15ba68e51` | `PhotoCleanupMVE/Features/S4/S4View.swift` |
| `67186fc95740365ed29cb27863b3ed8472514a33` | `PhotoCleanupMVE/Features/S5/S5View.swift` |
| `cc5dec866fc96f17ea7cfa9aca97fad541bad94d` | `.github/workflows/ci.yml` |
| `63e215a769effdbcc4cefb0aad52d55b0042e794` | `Scripts/selfcheck.ps1` |

源码引用检查结果：除 `S1View.swift` 自身的声明与四个预览外，其他产品 Swift 文件中 `S1View` 命中为 0，因此没有接入现有导航或启动路径。

## 八、自验脚本与执行方式

提交前在 Windows 执行：

```powershell
& ./Scripts/verify-IC-20260814-046.ps1 -允许未提交交付物 -允许待回填CI
```

CI 回填后在干净工作树执行：

```powershell
& ./Scripts/verify-IC-20260814-046.ps1
```

脚本验证 SPEC 哈希、实际基线测试数、本卡 18 个编号测试、四状态与迁移结构、六字段、未定项集中声明、四类服务分支、四状态预览、工程引用、导航隔离、受保护 blob、八路径白名单、硬编码残留、String Catalog 双向一致、通用 `selfcheck.ps1`、工作树与未跟踪条目。装有 Xcode 时还会调用现有 `Scripts/test-xcode.sh` 运行全量 XCTest。

## 九、执行结果与 CI 证据

| 验收项 | 当前结果 |
|---|---|
| SPEC SHA256 | 已核对，与任务卡一致。 |
| Windows 通用 selfcheck | 通过。 |
| String Catalog | 90 个目录条目、90 个产品源码引用，双向一致。 |
| 用户可见硬编码残留 | 0。 |
| 本卡专项静态自验 | CI 结果待本次推送回填。 |
| 全量 XCTest | CI 结果待本次推送回填。 |
| 失败 | CI 结果待本次推送回填。 |
| unexpected | CI 结果待本次推送回填。 |
| Release 构建 | CI 结果待本次推送回填。 |
| 未签名 IPA | CI 结果待本次推送回填。 |
| 受验提交 | CI 结果待本次推送回填。 |
| CI 运行 | CI 结果待本次推送回填。 |
| CI 链接 | CI 结果待本次推送回填。 |

当前 Windows 环境没有 Xcode，因此不能在本机伪造运行态结果。完成态必须以本次推送触发的 macOS CI 为准，回填 226 项 XCTest、0 失败、0 unexpected、Release 构建与未签名 IPA 证据后，再运行脚本最终模式。
