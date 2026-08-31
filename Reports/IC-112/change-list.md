# IC-112 变更清单：视觉批次 v3

## 结论

四个子项各自独立 commit（其中 B、C、D 各带一个修正提交），均可单独 cherry-pick。
**未合并 `main`**，分支保留。登记值/出厂值零改动，`schemaVersion` 仍为 **7**。

---

## 提交清单

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `233b94501bde2f8b308df1b8e6cb27f3de31aef8` | feat | A：chrome 玻璃透光配方 + 高光描边（含勘查结论） |
| 2 | `885aab63b7ddb5e344e6172cca7a93d9990f2e43` | feat | B：中央状态指示替换右上角角标 |
| 3 | `75589ed708a577d0d603d744bad25441a4fc7ada` | fix | B：删掉替换旧角标时残留的 `@ViewBuilder` 与旧注释 |
| 4 | `c58a30aeef3a351ceef73a2e791763ad30a8a4e2` | feat | C：教程 v3——六步、卡底对齐、手势放大、入口高亮 |
| 5 | `5a6421a6b29c4383f26b98686d571566233c623f` | fix | C：教程走查测试跟随六步序列 |
| 6 | `06453c80c7298e5f1c5884acbcb8901e17c69963` | feat | D：缩略横栏去底色 |
| 7 | `f65afce945d3b839ae0da01be86f1edb216a78d8` | fix | D：修正横栏带高断言（`resolvedStripHeight` 含触控带下限） |
| 8 | 本次 docs 提交 | docs | `Reports/IC-112/` 自验与变更清单 |

---

## 文件变更

### 产品代码

| 文件 | 子项 | 变更 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A/B/C/D | **A**：新增 `S2ChromeGlass` 配方常量与 `s2ChromeGlassBackground(in:)`，`s2ChromeCircleGlass` / `s2ChromeCapsuleGlass` 改走统一玻璃底 + 高光描边。**B**：新增 `S2CenterIndicatorAction` / `S2CenterIndicatorState` / `S2CenterIndicatorResolver` / `S2CenterIndicatorView` / `centerIndicatorOverlay` / `refreshCenterIndicator` / `undoFavoriteFromCenterIndicator` / `favoritesAlbumName`；**删除** `primaryMarkOverlay`；合并两处重复 `onChange`（`currentAssetID` / `interfaceVisibility`）。**C**：`S2TutorialStep` 增 `favoriteGuide = 5`、`confirmEntry` 顺延为 6；`S2TutorialCoordinator` 增 `assetDidBecomeFavorited`；`S2TutorialSpotlight` 增 `favoriteGuide` 目标与正圆挖孔分支；新增 `S2TutorialCardLayout`、`S2TutorialArrowShape`、`S2TutorialArcArrowShape`；`S2TutorialGestureHint` 放大并改自绘箭头；`S2TutorialOverlay` 增 `cardBottomInset` 与弧形箭头；垃圾桶圆钮第 6 步高亮。**D**：删除横栏容器的 `.background(.ultraThinMaterial)` 一行 |
| `PhotoCleanupMVE/Localizable.xcstrings` | B/C | **纯文本插入** 5 条新 key（`s2.center.favorited` / `favorites_album` / `removed` / `undo`、`s2.tutorial.step6`）；改写 3 条既有值（`s2.tutorial.step3` / `step4` / `step5`）。未用 json 重排全文件 |

### 测试

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | +1 项（A）、+4 项（B）、+5 项（C）、+1 项（D）；跟随改写 3 项既有用例（`testIC110DStepCatalogIsWellFormed` 五步→六步、`testIC111DAnimationParametersMatchCard` 触点圆 26/14→38/21、`testIC110DTutorialAdvancesThroughFiveStepsInOrder` 改名并补第 5 步） |

测试总数：554 →（A）555 →（B）559 →（C）564 →（D）**565**，最终 0 失败。

---

## 占位值登记

**本卡无出厂值变更，`S2CalibrationConfiguration.schemaVersion` 不递增，仍为 `7`**（`S2Calibration.swift:118`，全仓唯一定义点，①核对）。`S2Calibration.swift` 自本卡基线 `10ba354` 起**整文件零 diff**。

新增的视觉取值**全部是常量**，不进 `S2CalibrationConfiguration`、不上参数面板：

| 常量 | 值 | 子项 | 来源 |
|---|---|---|---|
| `S2ChromeGlass.tintOpacity` | 0.06 | A | 画布「底色白 ~6%」 |
| `S2ChromeGlass.innerHighlightTop / Bottom` | 0.55 / 0.12 | A | 画布「顶缘内侧白 55% 渐弱至底缘 12%」 |
| `S2ChromeGlass.innerStrokeWidth` | 1 | A | 卡内取定 |
| `S2ChromeGlass.outerRingOpacity / outerStrokeWidth` | 0.22 / 0.5 | A | 画布「外圈白 ~22% 细环」 |
| `S2CenterIndicatorResolver.transitionSeconds` | 0.2 | B | 画布「200 ms」 |
| `S2CenterIndicatorResolver.hiddenScale` | 0.9 | B | 画布「scale 0.9→1 / 1→0.9」 |
| `S2CenterIndicatorResolver.removedNoticeSeconds` | 1.2 | B | **卡内取定**（短提示停留时长，画布未给） |
| `S2CenterIndicatorView.blockSize / blockCornerRadius` | 30 / 9 | B | 卡内取定（内部方形倒角块） |
| `S2CenterIndicatorView.containerHeight / horizontalPadding` | 46 / 12 | B | 卡内取定 |
| `S2TutorialCardLayout.stripClearance` | 8 | C | 画布「横栏顶缘 − 8 pt」 |
| `S2TutorialGestureHint.ringDiameter / ringLineWidth / coreDiameter` | 38 / 2 / 21 | C | 画布「触点圆 Ø38（环 2pt、芯 Ø21）」 |
| `S2TutorialGestureHint.arrowLength / arrowLineWidth` | 64 / 2.6 | C | 画布「箭头长度 ~64pt / 线宽 2.6」 |
| `S2TutorialArrowShape.headLength` | 16 | C | 卡内取定（自绘箭头头部边长） |
| `S2TutorialArcArrowShape.headLength / bulge` | 14 / 56 | C | 卡内取定（弧形箭头） |

未变动的既有常量：`S2TutorialGestureHint.cycleSeconds` 0.9、`travel` 40（卡内「循环 0.9 s/次不变」）。

---

## 未变更 / 未触碰（范围边界核对）

| 对象 | 状态 |
|---|---|
| `main` | **未合并**，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | **整文件零 diff**（持有全部登记值与出厂值） |
| `schemaVersion` | 仍为 7 |
| 冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` | 未触碰（已逐个 `rev-parse` 核对） |
| `.github/`、`Scripts/`、`Reports/export-format.md` | 自基线零 diff（已 `git diff --name-only` 核对） |
| 手势识别器与产品手势语义 | 未触碰（G274/G279） |
| 相簿选择器与新建相簿 | 未动（下一张卡） |
| ♡ 收藏残影动画 | 未加（范围外） |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

---

## 报告提交

`Reports/IC-112/self-check.md` 与 `change-list.md` 随本 docs 提交推送。

按 CLAUDE.md 第五节，`Reports/**` 与 `**.md` 命中 `ci.yml` 的 `paths-ignore`，**该 docs 提交不触发 CI，属预期行为**；本报告指向的验证运行为 **#205 / #207 / #209 / #211**，最终绿 tip 为 `f65afce`（#211）。

按纪律第 7 条，报告与代码同卡同分支，未跨卡回填。
