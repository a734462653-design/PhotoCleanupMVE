# IC-113 变更清单：视觉打磨

> 本文为 **IC-113 + IC-113 v2 合并后的完整版**，整体替换首版。

## 结论

A、B、C 三项全部交付并绿。**未合并 `main`**，分支保留。
登记值/出厂值零改动，`schemaVersion` 仍为 **7**。

- **最终绿 tip（H50 完整包）** = `5c8cb3857d782052d1f7b121dc493a3d2015b8b3`（CI **#217**，560 / 0，IPA 970512 字节，SHA-256 `ce589fa51a46e1d40d21174fb2a0a0d9bd82695c4f2cdbeb004abfa405419cb8`）

---

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `b5a7577e86903f636a51e86404ba4d0ecc737c49` | feat | ✅ #212 | A：玻璃再透 + 描边收敛 |
| 2 | `a3f86ffe53f1850015c5235f807abb274ead948b` | feat | ✅ #213 | B：中央指示改挂加入相簿、标记块改圆形 |
| 3 | `db26f59820ab7b40bcb3bedc65f0cc77b8fcc097` | feat | ❌ #214 | C：教程四处修正 |
| 4 | `72bc58c94e22b37fefb061b4ba3e98a221f68db3` | fix | ❌ #215 | C：拆分过大的视图表达式 |
| 5 | `e03b12e4352ab3181320e7f4e79b55e3e0cd9962` | fix | ❌ #216 | C：修正实参顺序（编译已过，余 2 处旧断言） |
| 6 | `c4b27c9b7c7c55848643368e9dd25aef8fcfea57` | docs | — | IC-113 首版报告（预算用尽收口） |
| 7 | **`5c8cb3857d782052d1f7b121dc493a3d2015b8b3`** | test | ✅ **#217** | **v2：步 2 聚光期望按新推导式改造，C 转绿** |
| 8 | 本次 docs 提交 | docs | — | 完整替换 `Reports/IC-113/` |

---

## 文件变更

### 产品代码

| 文件 | 子项 | 变更 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A/B/C | **A**：`S2ChromeGlass` 三处数值收敛；教程提示卡并入 `s2ChromeGlassBackground`。**B**：`S2CenterIndicatorAction.favorite` → `.album`；`S2CenterIndicatorState.favorited` → `.addedToAlbum`；resolver 改按 `addedAlbumName` 解析；标记块方形 → 圆形；`undoAlbumAdditionFromCenterIndicator` 接真实移除；新增 `addedAlbumNameForCurrentAsset`、`onAlbumRemovalRequest` 入参、`albumIndicatorDelaySeconds`；移除 ♡ → 指示接线。**C**：`favoriteGuide` → `albumGuide` 及其聚光两分支；`seeStripMark` 聚光收紧 + `stripItemMagnification` / `magnified`；新增 `S2TutorialHintAnchor`；`S2TutorialGestureHint` 收紧 + 投影 + `unitHeight`；`S2TutorialOverlay` 增 `photoCenterY` 与 `badgeArrow`；教程浮层抽成 `tutorialOverlay(metrics:viewportSize:)` |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | B | 新增 `S2AlbumAdditionRecord`、`@Published lastAlbumAddition`、`isAlbumRemovalInFlight`、`makeAlbumRemovalRequest` / `beginAlbumRemoval` / `completeAlbumRemoval` / `publishAlbumAddition`；两条 `.success` 分支各登记一次 |
| `PhotoCleanupMVE/Services/PhotoAssetActionService.swift` | B | 协议与 PhotoKit 实装新增 `removeAsset(assetID:fromAlbumWithID:completion:)` |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | B | 新增 `requestS2AlbumRemoval` |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | B | 接线 `onAlbumRemovalRequest` |
| `PhotoCleanupMVE/Localizable.xcstrings` | B/C | `s2.center.favorited` → `added_to_album`（含改值）；删除 `s2.center.favorites_album`；改写 `s2.tutorial.step5` 为加入相簿引导。均为纯文本编辑 |

**v2 提交（#7）产品目录零 diff**（G286 已核）。

### 测试

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A：1 项改写；B：4 项改写 + 3 项新增；C：3 项改写/新增 + 手势图示用例补断言；`FakeAssetActionService` 补 `removeAsset`、`containedPairs` 由 `let` 改 `var`、新增 `containsPair`；`targetRect` 的 3 处调用同步补参。**v2**：`testIC111DSpotlightTargetsPerStep` 步 2 两条几何期望改为新推导式（尺寸 / 摆放各一条 + 收紧断言 + 旧口径不再成立断言） |

---

## 占位值登记

**本卡无出厂值变更，`schemaVersion` 仍为 `7`**；`S2Calibration.swift` 自本卡基线 `c2c1e29` 起**整文件零 diff**。

| 常量 | 旧 → 新 | 子项 | 来源 |
|---|---|---|---|
| `S2ChromeGlass.tintOpacity` | 0.06 → **0.03** | A | 卡内「约 3%」 |
| `S2ChromeGlass.innerHighlightTop / Bottom` | 0.55/0.12 → **0.30/0.06** | A | 卡内「约 30%」+ 同比收敛 |
| `S2ChromeGlass.outerRingOpacity` | 0.22 → **0.12** | A | 卡内「约 12%」 |
| `S2CenterIndicatorResolver.albumIndicatorDelaySeconds` | 新增 **0.42** | B | 卡内「残影落点回弹后」，取飞行 0.3 + 回弹余量 |
| `S2TutorialSpotlight.stripItemMagnification` | 新增 **1.6** | C | 卡内「放大…1.6 倍」 |
| `S2TutorialGestureHint.unitSpacing` | 10 → **2** | C | 卡内「合成一个单元」 |
| `S2TutorialGestureHint.contrastShadowOpacity / Radius` | 新增 **0.35 / 3** | C | 卡内「约 35% 黑…投影」 |
| `S2TutorialHintAnchor.indicatorClearance` | 新增 **16** | C | 卡内取定（步 4 避让净空） |
| `S2TutorialOverlay.badgeArrowLength` | 新增 **28** | C | 卡内取定（角标小箭头） |

新增 `UserDefaults` 键：无。

---

## 未变更 / 未触碰（范围边界核对）

| 对象 | 状态 |
|---|---|
| `main` | **未合并**，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| `S2Calibration.swift` | **整文件零 diff** |
| `schemaVersion` | 仍为 7 |
| 冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` | 未触碰（已逐个 `rev-parse` 核对） |
| `.github/`、`Scripts/` | 自基线零 diff（已 `git diff --name-only` 核对） |
| 手势识别器 | 未触碰（G284） |
| 相簿选择器与新建相簿 | 未动（下一张卡） |
| ♡ 收藏残影动画 | 未加（范围外） |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |
| v2 提交的产品目录 | 零 diff（G286） |

---

## 报告提交

`Reports/IC-113/self-check.md` 与 `change-list.md` 随本 docs 提交推送，**整体替换首版**（纪律第 6 条：完整替换而非增量）。

按 CLAUDE.md 第五节，`Reports/**` 与 `**.md` 命中 `ci.yml` 的 `paths-ignore`，**该 docs 提交不触发 CI，属预期行为**；本报告指向的验证运行为 **#212 / #213 / #217**（三个子项各自的绿），以及 **#214 / #215 / #216**（C 的三次红，成因逐条登记于自验报告）。

按纪律第 7 条，报告与代码同分支，未跨卡回填。
