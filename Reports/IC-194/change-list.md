# IC-194 变更清单

- 任务标识：`IC-20261009-194-s3-return-landing`（S3 返回落点：从 S2 待删篮进的确认页，返回回到那次 S2；冷启动恢复后返回装上 S1 会话；有行为变化）
- 基线：`main` = `b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066`；分支 `feature/ic-194-s3-return-landing`；合并提交 `3920cd74279b76cca3f4b912f48513a616fe0a76`。

## 一、提交（各自独立、按卡顺序 A → B → C）

| 子项 | 提交 | 摘要 | 摘取 |
|---|---|---|---|
| A | `366a6a50dacf2377ee63a2ae637a1613f884c5d1` | 协调器记录／清除／重进（`S3ReturnTarget`、`s3ReturnTarget`、`reenterS2(returningTo:)`）+ S1 状态机 `makeS2ReentryHandoff(for:)`（2 个文件） | 可单独摘（单独摘走须同带 C 里 IC168 那一行，否则 `testIC168BCD_NewSymbolsAreWired` 红；绿以 A→B→C 为准） |
| B | `a9877cde51e1600bfb002d28c5fabc3e12214e21` | `handleS3Return` 开头：冷启动恢复后没有会话 → `enterS1ResumingPersistedSessionOrStartNew()`（1 个文件） | 可单独摘（与 A 改同一文件的不同块，两种顺序得同一棵树） |
| C | `da09a9435ab7085fd60a3a54ee327b0fea02885a` | 新测试 `IC194S3ReturnLandingTests` 六条 + `IC168FallbackDiagnosticsTests` 一项 1 → 2 + pbx 测试登记（3 个文件） | 只能 A→B→C |
| 合并 | `3920cd74279b76cca3f4b912f48513a616fe0a76` | `merge(IC-194): S3 返回落点——从 S2 待删篮进的确认页返回回到那次 S2（同一范围、离开时那张）；经 S5 中转照旧；冷启动恢复后返回装上 S1 会话` | — |

可摘单元：A；B；A→B；A→B→C（克隆里 `cherry-pick -x` 全部干净，见 `self-check.md` 第五节）。

## 二、逐文件（白名单 5 路径，`git diff --name-only b3ebd43e6ad7e6ff88e88421c0c07b78d6a4e066..da09a9435ab7085fd60a3a54ee327b0fea02885a` 恰 5 行；增删行取自 `git diff --numstat`，合计 769 增 1 删）

| 路径 | 子项 | 增 | 删 | 改动 |
|---|---|---|---|---|
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | C | 4 | 0 | `IC194S3ReturnLandingTests.swift` 四行（fileRef `100000000000000000000096`、buildFile `200000000000000000000093`、测试组 children、测试源码阶段） |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | A、B | 87 | 0 | A（+82）：嵌套 `struct S3ReturnTarget: Equatable`（`rangeID`／`displayName`／`orderedAssetIDs`／`isVirtual`）与 `private(set) var s3ReturnTarget`；`enterConfirmationFromS2` 在 `applyS2ExitPayload` 之前取落点（`isVirtual` 按 `s1Machine.activeVirtualRangeIDs` 判）、进 S3 成功后记下；`enterConfirmationFromS1` 成功即 `s3ReturnTarget = nil`；`handleS3Return` 落 `.upstream` 后若有记录则清掉并调新私有 `reenterS2(returningTo:)`（真实范围：`reconcileS1WithPhotoLibrary()` 后 `makeS2ReentryHandoff(for:)`；`cat:` 范围：沿用原列表剔除已不在库中的、起点 `K` → 第一张没看过的 → 第一张，走 `makeS2Handoff(virtualRangeID:…)`；`enterS2` 失败撤销在途登记；重进不成留在上游、不提示）；`installS1Session` 清。B（+5）：`handleS3Return` 第一句 `if route == .confirmation, sessionStore == nil, s1Machine == nil { return enterS1ResumingPersistedSessionOrStartNew() }` |
| `PhotoCleanupMVE/Core/S1StateMachine.swift` | A | 21 | 0 | `cancelS2Handoff` 之后、`makeS3Submission` 之前新增 `makeS2ReentryHandoff(for:)`：复用 `makeS2Handoff(for:)` 的 `A(r, O)`、`D = D_全部 ∩ A` 与全部守卫，只把起点换成 `K[r].c_范围`（不在 `A` 中保留前者的起点）；`makeS2Handoff(for:)` 本体一字不动 |
| `PhotoCleanupMVETests/IC168FallbackDiagnosticsTests.swift` | C | 2 | 1 | 协调器表 `("cancelS2Handoff(virtualRangeID:", 1)` → `2`，加一行注释 |
| `PhotoCleanupMVETests/IC194S3ReturnLandingTests.swift` | C | 655 | 0 | 新文件，六条 `testIC194A`～`testIC194F`，逐字节拷入 |

## 三、测试

- XCTest 972 → **978**（+6，`IC194S3ReturnLandingTests`）。
- 随改的既有断言 1 处：`IC168FallbackDiagnosticsTests.testIC168BCD_NewSymbolsAreWired` 协调器 `cancelS2Handoff(virtualRangeID:` 1 → 2（App 表不动）。
- CI：分支 #392（run `37964461543`）绿 978／0；合并后 `main` #393（run `37966179688`）绿 978／0；artifact `PhotoCleanupMVE-unsigned-3920cd74279b`（id `11633209923`，有效期至 2027-01-07T17:25:37Z）。

## 四、占位值登记

无。本卡不改 `S2CalibrationConfiguration`（`schemaVersion` 仍 7）、不加字段、不改出厂值。

## 五、范围外（本卡未动）

App 入口与全部视图（S3 返回仍只经 `S3View` 的 `coordinator.leaveConfirmation()`）；`makeS2Handoff(for:)`／`makeS2Handoff(virtualRangeID:…)` 本体；`returnToConfirmation()`；`enterS2(from:)` 守卫；`SessionStore`；S2／S3／S4／S5 状态机；tab 落点（H98 第 5 条之后的修法卡）；S1 列表页与年页的滚动位置、S0 首页展开卡；S1 列表页／年页待删篮入口进 S3 前不对账（调研附带发现，维护卡候选）；`Scripts/`、`.github/`；SPEC 与 Decision_log。

## 六、人工判定项

H102 八条保留给 Lynn 真机判定（原文见 `self-check.md` 第十四节），装合并后 `main` 运行 #393 的包 `PhotoCleanupMVE-unsigned-3920cd74279b`。执行端不代为下结论。
