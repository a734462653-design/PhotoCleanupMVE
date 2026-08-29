# IC-110 变更清单：视觉批次

## 结论

四个子项各自独立 commit，均可单独 cherry-pick。**未合并 `main`**，分支保留。
布局锚与一切出厂值零改动；`schemaVersion` 仍为 6；`ci.yml`、`Scripts/`、SPEC、Decision_log 均未触碰。

---

## 提交清单

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `5f7d60dbca0452bbe47a28f0ba25c242d3b64c60` | feat | 子项 A：双击过渡改 300 ms 常量 + 系统 easeInOut 曲线 |
| 2 | `cb76192465e72735f34f62e1ebd567dc3e3668ab` | feat | 子项 B：顶/底 chrome 换装为玻璃圆钮 + 跑道胶囊 |
| 3 | `27e83f46a44fa347d65f75a51be4d9ca9b5d3a5a` | fix | 子项 B：把四项测试移回测试类内（#196 编译失败的修正，只搬位置） |
| 4 | `36496a147816e7df3b991a13b6924834debe42c8` | feat | 子项 C：标记残影沿弧线飞入横栏格位 |
| 5 | `351cc6e0588eb2b233fdfb3494e527b659947975` | feat | 子项 D：首次引导教程五步脚本 |
| 6 | 本次 docs 提交 | docs | `Reports/IC-110/` 自验与变更清单 |

---

## 文件变更

### 产品代码

| 文件 | 子项 | 变更 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | A | 新增 `S2DoubleTapTransitionTiming`（时长常量 + 三次贝塞尔缓动求解）；`startDoubleTapTransition` 加 `durationOverrideSeconds` 可选入参、时长改取常量；`advanceDoubleTapTransition` 对进度施加缓动；`beginDiagnosticDoubleTap` 改为显式传时长 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | B / C / D | B：新增 `S2ChromePillMetrics` 与两个玻璃药丸修饰符，重排 `topBar` 与 `actionBar`，移除两处整条 `.regularMaterial` 铺底。C：新增 `S2MarkAfterimage`、`S2MarkAfterimageCoordinator`、`S2MarkAfterimageFlight`、`S2MarkAfterimageView`、`markAfterimageOverlay`，并接入待删集合变化。D：新增 `S2TutorialStep`、`S2TutorialOutcome`、`S2TutorialCoordinator`、`S2TutorialOverlay`、`S2TutorialArrow`，接入 `onAppear`/`onDisappear`/待删集合/当前资产变化，标定面板加「重看教程」 |
| `PhotoCleanupMVE/Services/S2TutorialCompletionStore.swift` | D | **新建**。`S2TutorialCompletionStoring` 协议 + `S2UserDefaultsTutorialCompletionStore` 实现 |
| `PhotoCleanupMVE/Localizable.xcstrings` | D | **纯文本插入** 7 条 `s2.tutorial.*`（replay / skip / step1–step5）。未用 json 重排全文件 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | D | 新文件的四点注册（`PBXBuildFile` / `PBXFileReference` / 组 `children` / `Sources` 构建阶段），ID 取未占用的 `100000000000000000000034` 与 `200000000000000000000031`，式样照抄 `S2RecentAlbumStore.swift` |

### 测试

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | +5 项（子项 A，纯函数） |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | +4 项（B）、+5 项（C）、+5 项（D），并新增 `S2InMemoryTutorialCompletionStore` |

测试总数：525 →（A）530 →（B）534 →（C）539 →（D）**544**，各阶段 0 失败。

---

## 占位值登记

**本卡无出厂值变更，`S2CalibrationConfiguration.schemaVersion` 不递增，仍为 `6`**（`S2Calibration.swift:118`，全仓唯一定义点，①核对）。

新增的三组视觉取值**全部是常量**，不进 `S2CalibrationConfiguration`、不上参数面板、不动 `schemaVersion`（同 IC-091 `edgeTolerance`、IC-108 B 探针开关先例）：

| 常量 | 值 | 子项 | 来源 |
|---|---|---|---|
| `S2DoubleTapTransitionTiming.durationSeconds` | 0.3 | A | ④「≈300 ms」 |
| `S2DoubleTapTransitionTiming.controlPoint1 / controlPoint2` | (0.42, 0) / (0.58, 1) | A | ④「缓动接近系统」→ 取 UIKit `curveEaseInOut` 控制点 |
| `S2ChromePillMetrics.circleDiameter` | 36 | B | 卡内取定（视觉微观） |
| `S2ChromePillMetrics.capsuleMinHeight` | 36 | B | 卡内取定，与圆钮同高 |
| `S2ChromePillMetrics.capsuleHorizontalPadding` | 12 | B | 卡内取定 |
| `S2ChromePillMetrics.iconPointSize` | 16 | B | 卡内取定 |
| `S2MarkAfterimageCoordinator.maximumConcurrent` | 3 | C | 卡内取定「并存上限 3」 |
| `S2MarkAfterimageFlight.durationSeconds` | 0.42 | C | 卡内取定 |
| `S2MarkAfterimageFlight.endScale` | 0.18 | C | 卡内取定（「缩小」落值） |
| `S2MarkAfterimageFlight.startOpacity` | 0.55 | C | 卡内取定（「半透明」起值） |
| `S2MarkAfterimageFlight.arcLiftRatio` | 0.32 | C | 卡内取定（弧线抬升） |
| `S2TutorialCoordinator.autoAdvanceSeconds` | 2 | D | ④「2 秒后推进」 |
| `S2TutorialArrow.travel` / `halfCycleSeconds` | 18 / 0.6 | D | 卡内取定（手势示意往复） |

`UserDefaults` 键 `com.iphonephotomanagement.PhotoCleanupMVE.s2.tutorial-completed`：教程完成/跳过标记，**不是出厂值**。

---

## 未变更 / 未触碰（范围边界核对）

| 对象 | 状态 |
|---|---|
| `main` | **未合并**，未触碰 |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | **整文件零 diff**（持有全部布局锚与出厂值） |
| `topBarHeight` / 横栏高 / `stripToActionVisibleBandSpacing` / 安全区推导 / 截图等距带推导 | 全部未动 |
| `schemaVersion` | 仍为 6 |
| `<top>/SPEC-S2-20260829_v17.md`、`<top>/Decision_log.md` | 未读写（只读检索过，未修改） |
| `<repo>/.github/workflows/ci.yml`、`<repo>/Scripts/**` | 只读，未改 |
| 冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` | 未触碰 |
| Nx 贴边回弹、双击目标倍率规则（决策 19） | 未动（范围外） |
| 新增可调参数 | 无 |
| rebase / revert / amend / force push | 未执行 |

---

## 报告提交

`Reports/IC-110/self-check.md` 与 `Reports/IC-110/change-list.md` 随本 docs 提交推送。

按 CLAUDE.md 第五节，`Reports/**` 与 `**.md` 命中 `ci.yml` 的 `paths-ignore`，**该 docs 提交不触发 CI，属预期行为**；本报告指向的验证运行为 **#195 / #197 / #198 / #199**（四项各自的绿），最终绿 tip 为 `351cc6e`（#199）。

按纪律第 7 条，报告与代码同卡同分支，未跨卡回填。
