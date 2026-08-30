# IC-118 变更清单：H52 修复批次

## 结论

**四子项全绿。** 最终绿 tip（代码）= `cc5530d`（CI **#229**，583 / 0，真实退出码 0）。
**未合并 `main`，执行完即停。** 登记值/出厂值零改动，`schemaVersion` 仍为 **7**。
CI 用量 4/7（A 1 / B 1 / C 1 / D 1）。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `5c21f18` | fix | ✅ #226 | A：真机捏合路径经 `setScale` 分派（两处直写改道 + 回声防抖）+ 3 测试 |
| 2 | `3310315` | fix | ✅ #227 | B：退出前清算过期推迟呈现目标 + 探针退出阶段采样 + 3 测试 |
| 3 | `3bc22d9` | feat | ✅ #228 | C：角标盖钮改红、蓝改黑（4 处 + tint）、中央指示单层玻璃正圆 |
| 4 | `cc5530d` | feat | ✅ #229 | D：相簿指示按张记忆（机器按张记录 + 视图按张动作）+ 2 测试 |
| 5 | 本次 docs 提交 | docs | — | `Reports/IC-118/`（含总执行结果包与 H53 清单） |

## 文件变更

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | A：`reportNativeViewport` / `finishNativePinch` 的 scale 直写改道 `setScale`；`setScale` 增 `appliesZoomVisibilityRule`（默认 true，既有调用零变化），无捏合在途的视口回声只写倍率。D：新增 `sessionAlbumAdditionsByAsset`（会话内按张记录），`publishAlbumAddition` 登记、`completeAlbumRemoval` 成功清该张、`makeAlbumRemovalRequest` 改按当前张 |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | B：页面控制器新增 `reconcileDeferredPresentation(currentVisibility:)`（只丢弃与当前 V 不一致的过期推迟目标）；`handleDoubleTap` / `finishNativePinch` / `beginDiagnosticDoubleTap` 三个退出入口先清算；退出过渡落点注释更新。探针：`S2DoubleTapProbeEvent` 增退出阶段字段，协调器增 `recordDoubleTapExitTarget` / `recordDoubleTapExitCommit`，报告文本增两条子行（列头与格式版本不变） |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | C：角标移至垃圾桶标签链最外层 + 红字；4 处 accentColor 改黑；选择器 `NavigationStack` 加 `.tint(.black)`；`S2CenterIndicatorView` 重写为单层玻璃正圆（去内块，`blockSize`/`blockCornerRadius` 删除，`containerHeight` 46 沿用），已加入态 = 圆框 + 旁挂玻璃胶囊。D：`centerIndicatorLastActionByAsset` 按张动作记忆（全局口径废止）、翻页不清动作、`addedAlbumNameForCurrentAsset` 改读机器按张记录 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A 三条新测试；C `blockSize` 断言按 ④ 改写；D 两条新测试 + 失败保留追加断言 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | B 三条新测试（退出落点、清算语义、捏合归位清算） |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| 决策 20/40 契约语义、`applyDeferredPresentationIfPossible` 的 `zoomScale ≤ 1` 守卫 | 未动（B1 未触发） |
| 曲线时长常量（`S2DoubleTapTransitionTiming` 等） | 未动 |
| 手势识别器 | 未触碰 |
| 删除/移除路径 | 无新增（撤回沿用既有 `removeAssets`）；未查询历史相簿成员关系 |
| `S2CenterIndicatorResolver` 解析规则、命中测试语义（仅撤回钮可点） | 未动 |
| `S2Calibration.swift`、`.github/`、`Scripts/` | 零 diff；`schemaVersion` 仍为 7 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 7）。C 删除的 `blockSize` /
`blockCornerRadius` 为视图内取定常量（非标定参数），xcstrings 无引用（已扫描）。
探针新增字段不进 `export-format.md`（IC-108 既有约定，默认关闭零开销不变）。

## 报告提交

`Reports/IC-118/` 随本 docs 提交推送（同卡同分支追加，报告需引用推送后才产生的
CI #226–#229 编号与 IPA 哈希）。命中 `paths-ignore` 不触发 CI，属预期；
验证产品代码的运行为 #226 / #227 / #228 / **#229**（H53 包，被测提交 `cc5530d`）。
