# IC-189 变更清单

任务卡：`Tasks/IC-20261008-189-new-count.md`（S1 重设计批第三张——「新增 N 张」的数据与派生量：A 范围带逐张拍摄时间；B 派生量与注入；C 五条新测试 + pbx 登记；不做界面）。
基线：`main` = `17d1798a6d69d8608a3db0e10de7f8aba7c009f7`。分支：`feature/ic-189-new-count`。合并提交 `3bf92f22822ccc4850a996ae5a87bbb639c24d38`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 树 | 内容 |
|---|---|---|---|
| A | `552ae54cdb203056ab8ed55f0fa4be4798f7ee54` | `0f276ac521e9e188c2249105a80011142eb15aa8` | `S1StateMachine.swift` A1／A2、`PhotoLibraryService.swift` A3～A6；可单独摘 |
| B | `7ade7c1187d3545ded33000c42e41c9d5eebd639` | `cb1b0981f4cfaea01e710f1bc483c4f240152cbc` | `S1StateMachine.swift` B1～B4、`CleanupCoordinator.swift` B5、`IC184RetireCaliberEnumsTests.swift` B6、`IC188SeenSwitchTests.swift` B7；B 用到 A 的 `newAssetCount(after:excluding:)`，只能 A→B |
| C | `e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a` | `f1f3b19966e141d994ae016238edb5ebcfb6ba87` | 新文件 `IC189NewCountTests.swift`（逐字节拷入）+ pbx 四行（C1～C4）；依赖 A、B |

合并提交树 `f1f3b19966e141d994ae016238edb5ebcfb6ba87` = C 提交的树，双亲 `17d1798a6d69d8608a3db0e10de7f8aba7c009f7`／`e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a`。

## 二、逐文件（白名单 7 路径，`git diff --name-only 17d1798..e4e4bae` 恰 7 行；增删行取自 `git diff --numstat 17d1798 e4e4bae`）

| 路径 | 子项 | 基线 blob | C 提交 blob | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | C | `5c911bc5306162a64e26b1ac9df960ea90e56f97` | `1fc842b8290b65c6886f9f3b5e40ba97231e7650` | +4／−0：新测试文件四行（PBXBuildFile、PBXFileReference、测试组 children、测试源码阶段） |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | B | `458bc570b4ce9cbe21564d3d076b8ec9637c25b0` | `9274c11c821de5fcaa483cc89c5532e73f142645` | +6／−0：`installS1Session` 注入 `leaveTimeProvider` 闭包（B5） |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | A／B | `957d2b198e114f58f920211ff3371a3695696aed` | `94c5cee676af7e84e38dbc12b2d76f2569436fda` | +61／−0：A 18 行（`S1Range` 时间列、init 形参、`newAssetCount(after:excluding:)`）；B 43 行（`S1RangeRow.newAssetCount`、`leaveTimeProvider`、`rangeRows` 新列、`newAssetCount(for:)`／`newAssetBaseline(for:)`／私有 `newAssetCount(of:seenAssetIDs:)`） |
| `PhotoCleanupMVE/Services/PhotoLibraryService.swift` | A | `84c125327948948f2261b0c677eb5db6243da4a6` | `cdf60bffd0a1bab19bc191b2a59449ca1947b97f` | +9／−3：年、月、相册、未分类四处范围构造各加一列 `.map(\.creationDate)` |
| `PhotoCleanupMVETests/IC184RetireCaliberEnumsTests.swift` | B | `e4d76bff90b5d3ab44b13e53d80ed482065afb07` | `07989aca1e0e0f4610e033055be01f0b1f63c40b` | +2／−1：`S1RangeRow` 切片 `let ` 7 → 8 |
| `PhotoCleanupMVETests/IC188SeenSwitchTests.swift` | B | `96f157a7a6d4dbdf1ec15bea1b02f7dbf097ed77` | `95a0eee8af2750c17a30fd043cbdfae229dac514` | +2／−1：状态机 `seenAssetIDsProvider?() ?? []` 2 → 3 |
| `PhotoCleanupMVETests/IC189NewCountTests.swift` | C（新建） | — | `14904de5f6de651e0e6a53fd73f4ed7c991ef234` | +323：五条测试，逐字节拷自 `Tasks/decision-tools/ic189/` |

## 三、新增符号与行为变化

| 符号 | 位置 | 说明 |
|---|---|---|
| `S1Range.creationDatesNewestFirst: [Date]` | `Core/S1StateMachine.swift` | 与 `assetIDsNewestFirst` 逐张对应的拍摄时间；构造形参带默认值 `[]`，排在 `assetIDsNewestFirst` 之后、`parentRangeID` 之前，现有全部构造点（服务 4、预览 2、测试 63 行）一个都不用改 |
| `S1Range.newAssetCount(after:excluding:)` | 同上 | 拍摄时间严格晚于基线、且不在看过集合里的张数；整列扫描、不依赖存储顺序；时间列与资产列不等长（含没有时间列）返回 0 |
| `PhotoLibraryService` 四处范围构造 | `Services/PhotoLibraryService.swift` | 年、月、相册、未分类各多填 `creationDatesNewestFirst:`（`DatedAsset.creationDate` 非可选，无新失败路径） |
| `S1RangeRow.newAssetCount: Int` | `Core/S1StateMachine.swift` | 行投影多一个字段；零即不显示；卡片叠与年页不读它（界面接线归 ③ V1 视图卡） |
| `S1StateMachine.leaveTimeProvider: ((String) -> Date?)?` | 同上 | `t_离开[r]` 读口；协调器注入，未注入的夹具按「从未离开」 |
| `S1StateMachine.newAssetCount(for:)` | 同上 | 有月的年取各月之和；其余范围按自己的基线算；不存在的范围 0 |
| `S1StateMachine.newAssetBaseline(for:)` | 同上 | 有 `parentRangeID` 的月取自己与所属年较晚的离开时刻；其余取自己的；都没有为 nil |
| `CleanupCoordinator.installS1Session` 注入 | `App/CleanupCoordinator.swift` | `machine.leaveTimeProvider = { [weak self] … MainActor.assumeIsolated { self?.currentSeenArchive().leaveTimeByRangeID[rangeID] } }`，三条创建路径都经它 |

## 四、没有改动的东西（范围外，逐项核过）

`Core/SessionStore.swift`、`Core/SessionPersistence.swift`、`Core/S1SeenArchive.swift`、`areValid`、`Core/S2StateMachine.swift` 与 S2 全部文件、任何视图（含 `S1View.swift` 预览的两处 `S1Range(`）、App 入口、`Localizable.xcstrings`、`Scripts/`、`.github/`、SPEC 与 Decision_log。`schemaVersion` 仍 7；没有出厂值变更。会话档、快照、持久化不涉及（`S1Range` 不入档）。

## 五、占位值登记

无（无出厂值变更）。

## 六、摘取关系

可摘单元：A；A→B；全部（A→B→C）。B 用到 A 的计数函数，不单独摘；C 依赖 A、B。克隆实测（`--no-hardlinks`，A 单独、A→B 连续、A→B→C 连续）`cherry-pick -x` 退出码均 0，结果树分别为 `0f276ac521e9e188c2249105a80011142eb15aa8`、`cb1b0981f4cfaea01e710f1bc483c4f240152cbc`、`f1f3b19966e141d994ae016238edb5ebcfb6ba87`（各等于 A、B、C 提交的树；只证文本无冲突）。

## 七、CI 与产物

| 运行 | run id | 被测提交 | 结果 |
|---|---|---|---|
| 分支 #382 | `37884495677` | `e4e4bae06dc54eebb6dc2dfe3e865c2b6c32a90a` | success，963／0，IPA 1993773 字节，SHA-256 `ece623d48aaff195e39f510ec913f86d487698225eeba0ab8ca73d8af6cb338a` |
| 合并后 `main` #383 | `37885424916` | `3bf92f22822ccc4850a996ae5a87bbb639c24d38` | success，963／0，IPA 1993773 字节，SHA-256 `2e983b8ee1444bf2686af1cac3509be27817bbf4dc9e47605528488eaf9d0730`；artifact `PhotoCleanupMVE-unsigned-3bf92f22822c`，id `11596069276`，2027-01-07T04:46:14Z 前有效 |

项数对账：`958 + 5 = 963`。

## 八、保留给 Lynn 的人工判定

无（本卡无界面变化；「新增 N」胶囊的真机观感随 ③ V1 视图卡判）。

## 九、核验结果

docs 提交前对本清单与 `self-check.md` 中出现的全部 40 位 SHA 跑 `git cat-file -t <sha>` 与 `git cat-file -e <sha>^{<类型>}`：**共 23 个不同的 40 位 SHA，23 个在原仓全部命中、0 个缺失**——commit 7 个：`552ae54c…`、`7ade7c11…`、`e4e4bae0…`、`3bf92f22…`、`17d1798a…`、`c3ae531e…`、`24b3cbd0…`；tree 3 个：`f1f3b199…`、`0f276ac5…`、`cb1b0981…`；blob 13 个（基线与 C 提交的文件 blob、拷入文件 blob）。克隆里 cherry-pick 产生的新提交 SHA 未写进任何报告。docs 提交自身的 SHA 不在核验范围内。
