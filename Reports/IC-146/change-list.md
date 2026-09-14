# IC-146 变更清单 · S2 chrome 二轮

- **卡**：`IC-20260914-146-s2-chrome-round-two.md`
- **分支**：`feature/ic-146-s2-chrome-round-two`（已按 G841 授权 `--no-ff` 合并入 `main`）
- **基线**：`main` = `98e76c90e42d52817e1f59f818412a5f0688127b`
- **合并提交**：`d753fc5a31f5e7e2760b88d1ab842949de5a80bc`

---

## 一、提交清单

| # | 完整 SHA | 子项 | 标题 |
|---|---|---|---|
| 1 | `4375e3e25263aec25244472122e3d1a9d1dd5df3` | A | `feat(IC-146 A): 底排改组——收藏 ｜ 相簿跑道圆 ｜ 分享（决策 60）` |
| 2 | `b46af86a6203a4337af5e474546ee5b7786879c7` | B | `feat(IC-146 B): 氛围底——主图之外改当前照片的强模糊底（决策 61）` |
| 3 | `5326cb49b28c9204c50bcf5616a7bc279de3c740` | C | `feat(IC-146 C): 「已标记 · 撤销」胶囊，撤销走下滑取消的同一入口（决策 62）` |
| 4 | `92b061d6c14a5665fdae13d24ac003f857055655` | D | `feat(IC-146 D): 退后台停用音频会话，回 active 不自动重新激活（第 161 条 ③）` |
| 5 | `2ccd595e6ba0c38ab8363324be47ff8c0b35f0f3` | C 附 | `test(IC-146 C): 改既有断言口径——「已标记」态现在有撤销钮（决策 62）` |
| 6 | `f72a7f4bc542ba7162c5c11b2ce586fc2d1626d6` | 修 | `fix(IC-146): 修 #289 的 5 项失败（7 次失败事件），四处根因` |
| — | `d753fc5a31f5e7e2760b88d1ab842949de5a80bc` | 合并 | `Merge branch 'feature/ic-146-s2-chrome-round-two' (IC-146)` |

### 与「四项各自独立 commit、每个可单独 cherry-pick」的偏差（如实登记）

- **提交 5、6 是计划外的第五、六个提交。** 5 是子项 C 引起的既有测试口径变更；6 是 #289 红后的修正，跨 A（无）／B（有）／既有测试（有）。两者发现时前四个提交均已落地，CLAUDE.md 第三节禁止 `amend` / `rebase` / 改写历史，故不回填而另起提交。
- **后果**：提交 3（C）单独 cherry-pick 会让 `testIC113BOnlyUndoControlIsHittable` 红，须连提交 5 一起取；提交 2（B）单独 cherry-pick 会让 `testIC067G39…` 与 IC-141／IC-143 两条源码扫描断言红，须连提交 6 一起取。A 与 D 两项可单独 cherry-pick。

---

## 二、文件变更

| 文件 | 动作 | 涉及提交 | 说明 |
|---|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 修改 | 1、2、3、4、6 | 底排改组、分享接线、氛围底层与取图触发、中央指示两条撤销路径、音频收口接线 |
| `PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift` | **新增** | 2、6 | 氛围底登记常量、取图接口与实现、协调器／读数、视图、噪点贴图 |
| `PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift` | 修改 | 4 | 新增 `applicationDidResignActive` 事件、reducer 分支与协调器入口 |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 修改 | 1 | **仅** `S2AlbumAfterimageFlight.bottomCapsuleCenter`（补充授权，见第六节） |
| `PhotoCleanupMVE/Localizable.xcstrings` | 修改 | 1、3 | 新增 2 个 key，既有条目零改动 |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 修改 | 1、2 | 两个新文件登记 |
| `PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift` | **新增** | 1、2、3、4、6 | 20 个测试，覆盖断言 1～17 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | 修改 | 5 | 一条既有断言随决策 62 改口径 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 修改 | 6 | 一条既有测试随决策 61 改口径并改名 |

`git diff --name-only main...HEAD`（合并前）的完整结果就是上表 9 个文件，白名单外 **0** 个。

---

## 三、既有测试改口径（旧 → 新，逐条）

### 3.1 `S2ActionBarWiringTests.testIC113BOnlyUndoControlIsHittable`

**原因**：SPEC-S2 v20 回写决策 62——「已标记」由正圆单图标改为「已标记 · 撤销」胶囊，故该态**有**一个可点元素。原断言的事实被决策反转。

| | 内容 |
|---|---|
| 旧 | `XCTAssertFalse(S2CenterIndicatorView.showsUndoControl(for: .marked), "已标记态不得有任何可点元素——手势必须穿透")` |
| 新 | `XCTAssertTrue(S2CenterIndicatorView.showsUndoControl(for: .marked), "已标记态必须有撤销钮（决策 62）")` |

同族另外两条（`.addedToAlbum` 必须有撤回钮、`.removed` 不得有可点元素）**一字未改**。测试上方的口径注释同步补记本次变更的依据（陷阱 23：改既有断言前先读同族注释——本条的注释正是原口径的出处）。函数名未改。

### 3.2 `S2CalibrationHarnessTests.testIC067G39ViewportBackgroundTracksInterfaceStyle`

**原因**：SPEC-S2 v20 回写决策 61——主图之外的区域由 `systemBackground` 改为氛围底，且**恒为深色配方、不随系统外观切换**。原断言测的是已被取代的那一层。

| | 内容 |
|---|---|
| 旧函数名 | `testIC067G39ViewportBackgroundTracksInterfaceStyle` |
| 新函数名 | `testIC067G39ViewportBackgroundIsAmbientAndIgnoresInterfaceStyle` |
| 旧断言 | `XCTAssertEqual(darkGray, 0, accuracy: 3)`<br>`XCTAssertEqual(lightGray, 255, accuracy: 3)` |
| 新断言 | `XCTAssertEqual(darkGray, lightGray, accuracy: 3, "氛围底随系统外观变了，与决策 61「恒为深色配方」相悖")`<br>`XCTAssertLessThan(darkGray, 60, "氛围底不是深色")`<br>`XCTAssertLessThan(lightGray, 60, "浅色外观下氛围底不是深色")` |

**改名的理由**：原名断言的事实已被决策反转，留着会让后来人以为视口底色仍跟随外观。取值机制（渲染后采像素）与采样点一字未改，只换被断言的不变量。该函数名在仓内无其他引用（已 grep 核实）。

---

## 四、新增公开符号（同模块 internal）

### 子项 A

| 符号 | 种类 | 用途 |
|---|---|---|
| `S2AlbumTrackPresentation` | `struct` | 底排中位的口径模型：`isTrack` / `separatorCount` / `actionBarButtonCount` |
| `S2AlbumTrackIdentity` | `enum: Hashable` | 跑道圆两半与退化圆钮的视图身份（陷阱 17） |
| `S2SharePayload` | `struct: Identifiable, Equatable` | 分享面板载荷（资产标识 + 文件 URL） |
| `S2SharePreparation` | `struct: Equatable` | 分享呈现态三态机：`begin` / `resolved` / `dismiss` |
| `S2ShareItemResolving` | `protocol` | 分享取项接口 |
| `S2PhotoKitShareItemResolver` | `final class` | 生产实现（照片 `fullSizeImageURL`、视频 `AVURLAsset.url`，禁网络） |
| `S2ShareSheet` | `struct: UIViewControllerRepresentable` | `UIActivityViewController` 包装 |
| `S2ActionBarPresentation.shareEnabled` | 新增字段 | 右位分享圆钮的启用态 |
| `View.s2ChromeTrackGlass()` | 扩展方法 | 跑道圆玻璃底（同 `s2ChromeCapsuleGlass` 配方、不加水平留白） |

### 子项 B

| 符号 | 种类 | 用途 |
|---|---|---|
| `S2AmbientMetrics` | `enum` | 氛围底登记常量（十个引用 `S0Ambient` + `veilMidLocation` + `tintHue` + `sourceTargetEdge`） |
| `S2AmbientImageLoading` | `protocol` | 氛围底取图接口 |
| `S2PhotoKitAmbientImageLoader` | `final class` | 生产实现（缩略级、`.fastFormat`、禁网络） |
| `S2AmbientBackdropReadout` | `final class: ObservableObject` | **唯一**发布点，只有氛围底视图观察 |
| `S2AmbientBackdropStore` | `final class: ObservableObject` | 取图协调器，**自身不发布任何变更**（陷阱 5） |
| `S2AmbientGrain` | `enum` | 确定性噪点贴图（固定种子线性同余） |
| `S2AmbientBackdropView` | `struct: View` | 氛围底视图（幕底色 → 模糊铺底 → 渐隐幕 → 冷色光晕 → 颗粒） |

### 子项 C

无新增类型。改动：`S2CenterIndicatorView.showsUndoControl` 由 `if case` 改 `switch`（`.marked` 现返回 true）、`content` 的 `.marked` 分支由正圆改胶囊、`S2View.undoMarkFromCenterIndicator()` 新增私有方法。

### 子项 D

| 符号 | 种类 | 用途 |
|---|---|---|
| `S2VideoPlaybackEvent.applicationDidResignActive` | 新增 case | 应用失活 |
| `S2VideoPlaybackCoordinator.applicationDidResignActive()` | 新增方法 | 协调器入口 |

`S2AudioSessionControlling` 的既有两个方法**语义一字未改**，也未新增协议方法。

---

## 五、取值表逐条落实

| 卡内取值 | 落点 | 实装值 | 核对 |
|---|---|---|---|
| `albumTrackSeparatorOpacity` = 0.22 | `S2MediaMetrics.albumTrackSeparatorOpacity` | `0.22` | 出处注释写明 SPEC-S2 v20 第十一节第 2 部分 |
| 氛围底十个量引用 `S0Ambient` | `S2AmbientMetrics` | `blurRadius` 34、`saturation` 1.15、`opacity` 0.62、`veilTopOpacity` 0.30、`veilMidOpacity` 0.66、`veilBottomOpacity` 0.94、`tintRadius` 0.70、`tintOpacity` 0.30、`grainOpacity` 0.90、`baseColor` `#050507` | 断言 8 逐个比对；每处定义都带「取值出处：SPEC-S0 v1 第十四节 `S0Ambient`」注释（共 11 处） |
| 中央指示胶囊全部几何沿 C1 既有值 | 未改动 | `containerHeight` 46、`horizontalPadding` 12、分隔线白 30%、底黑 55% | 断言 14 逐个核对 |
| 分享圆钮几何沿 chrome 既有值、不新增常量 | 复用 `s2ChromeCircleGlass()` | 行高 44、圆钮直径 44、`minimumSpacing` | 未新增任何分享专用几何常量 |

### 本卡新增的登记常量（全部落在 `S2MediaMetrics` 或 `S2AmbientMetrics`，不散落为裸数）

| 常量 | 值 | 出处状态 |
|---|---|---|
| `S2MediaMetrics.albumTrackSeparatorOpacity` | 0.22 | **规格已登记**（SPEC-S2 v20） |
| `S2MediaMetrics.albumTrackSeparatorWidth` | 1 | 规格只登记不透明度、未登记线宽（hairline 语义）；**执行端取定** |
| `S2MediaMetrics.albumTrackSeparatorHeight` | 22 | 与中央指示胶囊内分隔线同高（IC-136 C 既有值），**引用同族语汇** |
| `S2MediaMetrics.albumTrackTrailingHalfWidth` | `= S2OverlayLayout.chromeRowHeight`（44） | **引用既有常量**，保证右半命中区 44 × 44 |
| `S2MediaMetrics.albumTrackRecentHalfCenterOffsetX` | `−(分隔线宽 + 右半宽) / 2` | 由上两项推导；`bottomCapsuleCenter` 只消费不定义 |
| `S2AmbientMetrics.veilMidLocation` | 0.42 | **规格已登记**（`ambientVeilMidOpacity` 行的注释「42% 位置」） |
| `S2AmbientMetrics.tintHue` | (0.42, 0.52, 0.72) | 规格只登记光晕的半径与不透明度、**未登记色相**；**执行端取定**，日后决策会话若要定案改这一处即可 |
| `S2AmbientMetrics.sourceTargetEdge` | 160 | 取图目标边长，非视觉量；**执行端取定**（规格第 14 条只要求「缩略级」） |
| `S2AmbientGrain.tileEdge` / `.amplitude` | 64 / 24 | 噪点贴图的生成参数，非视觉取值；**执行端取定** |

**`S2CalibrationConfiguration.schemaVersion` 仍为 7**，本卡未新增、未修改任何出厂值；上述常量一律不入 `S2CalibrationConfiguration`、不入 Keychain、不上标定面板。

---

## 六、`S2NativePhotoPager.swift` 的补充授权（越界范围与理由）

**这是卡内白名单的疏漏补授，不是执行端自行扩权。**

- **缘由**：规格 A6 与断言 5 要求相簿残影落点改为「跑道圆左半中心」，而算落点的 `S2AlbumAfterimageFlight.bottomCapsuleCenter` 在 `S2NativePhotoPager.swift` 内，该文件不在卡内白名单表。执行端就此停下发问。
- **裁定**（2026-09-14 决策会话）：白名单漏列该文件系写卡疏漏；决策 60 明写「相簿残影的落点仍为中位跑道圆的左半中心」，落点不改即规格未落实，不得判受阻。**授权范围仅限 `enum S2AlbumAfterimageFlight`（`:1137` 起）内的 `bottomCapsuleCenter(viewportSize:safeAreaInsets:)`**；该文件其余任何一行不得改动。
- **实际改动**：两个 hunk，合计 +12 / −1 行。

```
@@ -1187,3 +1187,12 @@ enum S2AlbumAfterimageFlight {
@@ -1207 +1216,2 @@ enum S2AlbumAfterimageFlight {
```

两个 hunk 的 git hunk header 均为 `enum S2AlbumAfterimageFlight`，即全部落在该 enum 内。内容为：函数文档注释改写（说明落点语义由「整只中心」改为「左半中心」及其推导），与返回值加一项 `+ S2MediaMetrics.albumTrackRecentHalfCenterOffsetX`。

- **右半宽与分隔线宽登记在 `S2MediaMetrics`（白名单内），`bottomCapsuleCenter` 只消费不定义** —— 分页器那侧只多了几行算术。
- **零改动实证**：`.clear` 8、`backgroundColor = .clear` 7、`writePhotoGeometry` 5，三项与改前逐一相同（见 self-check.md G839 节）。`writePhotoGeometry` 及其调用点、各层 `.clear` 背景、双击过渡、两个快照函数一律原样。

---

## 七、新增目录 key（2 个）

| key | 值 | 子项 |
|---|---|---|
| `s2.action.share` | 分享 | A（分享圆钮无障碍名） |
| `s2.center.marked` | 已标记 | C（胶囊左段文案） |

`s2.center.undo`（撤销钮）与 `s2.mark.primary.accessibility`（已标记无障碍名）**复用既有 key**，未新增。目录条目数 213 → **215**；扫描器报「产品源码引用 key = 215」，与条目数一致，无孤儿 key、无缺失 key。

---

## 八、pbxproj 登记

加登记前重扫各族最大对象 id（陷阱：撞号不报错，IC-134 #262 实例）。本卡自 `main` 切分支，故各族最大值与 `main` 一致：

```
100000 族最大 = 100000000000000000000044
200000 族最大 = 200000000000000000000041
300000 族最大 = 30000000000000000000000D
```

| 对象 | id | 写入前命中数 | 子项 |
|---|---|---|---|
| `IC146ChromeRoundTwoTests.swift` PBXFileReference | `100000000000000000000045` | 0 | A |
| `IC146ChromeRoundTwoTests.swift` PBXBuildFile | `200000000000000000000042` | 0 | A |
| `S2AmbientBackdrop.swift` PBXFileReference | `100000000000000000000046` | 0 | B |
| `S2AmbientBackdrop.swift` PBXBuildFile | `200000000000000000000043` | 0 | B |

每个文件 4 处登记：PBXBuildFile、PBXFileReference、所属 PBXGroup 的 children、对应 target 的 Sources 构建阶段。`S2AmbientBackdrop.swift` 进 `Features/S2` 组与**应用** target；`IC146ChromeRoundTwoTests.swift` 进 `PhotoCleanupMVETests` 组与**测试** target。

---

## 九、范围边界自查

| 项 | 结果 |
|---|---|
| 顶排三件 | **零改动**（`topBar` / `topBarRow` 两块的分块 SHA-256 两侧相同） |
| 决策 59（排序入口内移 S2） | **未做**，按卡挂批次 5.4 |
| `S2LivePhotoPlayback.swift` | **零改动**（整文件 SHA-256 两侧相同） |
| `S2Calibration.swift` | 不在 diff；`schemaVersion` 仍 7 |
| `Services/` | 零改动 |
| S1 / S3 / S4 / S5 | 零改动 |
| `writePhotoGeometry` 及其调用点与几何链 | 零改动（计数 5） |
| `S2NativePhotoPager.swift` 的任何 `.clear` 背景 | 零改动（8 / 7） |
| 决策 46／53 的时长、缩放、解析规则、短提示停留 | 零改动（断言 14 逐个核对） |
| `seek` 容差、`actionAtItemEnd`、`videoBarScrubMinimumDistance` | 零改动 |
| 冻结三链与两条探针分支 | 远端 tip 未变 |
| SPEC / `Decision_log.md` | 未触碰 |
| `rebase` / `amend` / `force push` | 未执行 |
