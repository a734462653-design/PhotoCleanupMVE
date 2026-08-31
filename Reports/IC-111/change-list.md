# IC-111 变更清单：视觉批次 v2

## 结论

四个子项各自独立 commit（A 因 #200 补一个 fix 提交），均可单独 cherry-pick。
**未合并 `main`**，分支 `feature/ic-110-visual-batch` 保留。
`schemaVersion` 随 A 由 6 升 **7**（全仓唯一）；冻结三链、`ci.yml`、`Scripts/`、`export-format.md` 零改动；未碰任何手势识别器。

---

## 提交清单

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `9fd9d5432aa9df5134895ce02d0f31a8ac4bd815` | feat | 子项 A：chrome 几何对齐 v18 画布，`schemaVersion` 6→7 |
| 2 | `12cf289158b692169a02ce019ad644ef4d84609a` | fix | 子项 A：补改 IC-100 B1 漏掉的旧中心硬编码（#200 的修正，只改测试） |
| 3 | `86b46eb22dc582e32cc5164d42bb1d84bb7a8f7d` | feat | 子项 B：标记残影改飞右上垃圾桶，CAAnimation 驱动 |
| 4 | `a9399343e473971ecfc11eab841ab7c9f95076e4` | feat | 子项 C：新增加入相簿残影飞入底部中胶囊 |
| 5 | `eea617a3482dec47a28e5226851871ebb52dd5e3` | feat | 子项 D：教程动效重做（聚光挖孔 + 手势图示 + 玻璃提示卡） |
| 6 | 本次 docs 提交 | docs | `Reports/IC-111/` 自验与变更清单 |

---

## 文件变更

### 产品代码

| 文件 | 子项 | 变更 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | A | `S2OverlayLayout` 常量整组按画布重定（新增 5 个、废止 3 个、`topBarHeight` 改推导）；底排三个推导式改锚；`topElementFrames` 与 `snapshot` 的顶/底排改「圆钮 + 胶囊 + 圆钮」；`schemaVersion` 6→7；等距带公式**未动**（只随 `topBarHeight` 重推） |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | B / C | 新增 `S2MarkAfterimageFlight`、`S2AlbumAfterimageFlight`、`S2AlbumCapsuleEntrance`、`S2MarkAfterimageCoordinator`、`S2MarkAfterimagePresenter`（泛化后两种残影共用）；页级 `makeMarkAfterimageSnapshot`；`finishVerticalSwipe` 内的预拍与起飞；`launchAlbumAfterimage` 与其协调器挂钩 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A / B / C / D | A：`S2ChromePillMetrics` 改画布取值、材质改 `.ultraThinMaterial`、图标与字号按画布、底排边距 16 与胶囊居中。B：协调器持有、角标显示值与垃圾桶回弹。C：`S2AlbumAfterimageGate`、中胶囊入场与回弹、两条触发路径。D：删除 IC-110 D 的浮层与箭头，新增 `S2TutorialGestureDirection`、`S2TutorialSpotlight`、`S2TutorialGestureHint`、重写 `S2TutorialOverlay`；教程态禁用确认入口。另删除 IC-110 C 的整套飞缩略栏实现 |
| `PhotoCleanupMVE/Localizable.xcstrings` | D | **纯文本插入** 1 条 `s2.tutorial.done`（未重排全文件）。目录 189 = 产品源码引用 189 |

### 测试

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 按推导式改写既有几何断言：`97.7→110`、`82→90`、`56→64`、`30.7→24`、`88→chromeRowHeight`、「触控带底缘 = 安全区底」→「+ 8」、可见带自洽断言改 chrome 行高自洽；`schemaVersion` 断言全量 6→7（`3` 的旧版不匹配用例原样保留） |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | IC-110 B 三项锚点用例 → IC-111 A 五项；删除 IC-110 C 五项；新增 IC-111 B 四项、C 五项、D 四项 |

测试总数：544 →（A）546 →（B）545 →（C）550 →（D）**554**。

---

## 占位值登记

**`S2CalibrationConfiguration.schemaVersion` 由 6 升 `7`**（`S2Calibration.swift:118`，全仓唯一定义点，①核对）。
**注**：本卡未增删任何 `S2CalibrationConfiguration` 字段（`fieldNames.count` 仍 43），配置字段值集合未变；升版系卡内指定，详见 self-check 的「schemaVersion 说明」。

### 布局常量（`S2OverlayLayout`，登记制占位常量，不进配置、不上面板）

| 常量 | 值 | 变化 |
|---|---|---|
| `chromeRowHeight` | 44 | 新增 |
| `topRowTopInset` | 3 | 新增 |
| `bottomRowBottomInset` | 8 | 新增 |
| `chromeHorizontalMargin` | 16 | 新增 |
| `stripToBottomRowSpacing` | 24 | 新增（取代 30.7） |
| `topBarHeight` | 47 | 由裸 48 改为 `topRowTopInset + chromeRowHeight` 推导 |
| `actionBarVisibleBandHeight` | — | **废止**（原 22） |
| `stripToActionVisibleBandSpacing` | — | **废止**（原 30.7） |
| `topLeadingControlWidth` | — | **废止**（原 88） |
| `minimumTouchTarget` / `minimumSpacing` / `horizontalPadding` / `calibrationTopClearance` | 44 / 8 / 8 / 108 | 未动 |

### 视觉与动效常量（视图层常量，不进配置、不上面板）

| 常量 | 值 | 子项 |
|---|---|---|
| `S2ChromePillMetrics.pillHeight` | = `chromeRowHeight` 44 | A |
| `…capsuleHorizontalPadding` / `circleIconPointSize` | 14 / 17 | A |
| `…titleFontSize` / `subtitleFontSize` / `subtitleOpacity` | 15 / 11.5 / 0.62 | A |
| `…bottomCapsuleIconPointSize` / `bottomCapsuleTextFontSize` | 17 / 15 | A |
| `S2MarkAfterimageFlight.durationSeconds` / `endScale` / `startOpacity` / `controlOvershoot` | 0.32 / 0.18 / 0.85 / 28 | B |
| `S2AlbumAfterimageFlight.durationSeconds` / `endScale` / `arcDropRatio` | 0.30 / 0.15 / 0.28 | C |
| `S2AlbumCapsuleEntrance.durationSeconds` / `rise` | 0.12 / 8 | C |
| `S2TutorialOverlay.dimOpacity` | 0.55 | D |
| `S2TutorialGestureHint.travel` / `cycleSeconds` / `ringDiameter` / `coreDiameter` | 40 / 0.9 / 26 / 14 | D |
| `S2TutorialSpotlight.padding` / `cornerRadius` | 8 / 18 | D |

**未新增任何可调参数。**

---

## 未变更 / 未触碰（范围边界核对）

| 对象 | 状态 |
|---|---|
| `main` | **未合并**，仍为 `a013098…` |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md` | 未读写（只读检索过，未修改） |
| 冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` | 未触碰 |
| `.github/workflows/ci.yml`、`Scripts/**`、`Reports/IC-068/export-format.md` | 零改动（diff 为空） |
| 手势识别器与产品手势语义 | 零改动（`GestureRecognizer` 等逐条 grep 为空） |
| 双击时长曲线（IC-110 A） | 未动 |
| ♡ 收藏残影 | 未加（卡内标注未定） |
| 未定项 22 跟随规则语义 | 未动 |
| 新增可调参数 | 无 |
| rebase / amend / force push / 删分支 | 未执行 |

---

## 报告提交

`Reports/IC-111/self-check.md` 与 `Reports/IC-111/change-list.md` 随本 docs 提交推送。

按 CLAUDE.md 第五节，`Reports/**` 与 `**.md` 命中 `ci.yml` 的 `paths-ignore`，**该 docs 提交不触发 CI，属预期行为**；本报告指向的验证运行为 **#201 / #202 / #203 / #204**，H48 包为 **#204**（最终绿 tip `eea617a`）。

按纪律第 7 条，报告与代码同卡同分支，未跨卡回填。
