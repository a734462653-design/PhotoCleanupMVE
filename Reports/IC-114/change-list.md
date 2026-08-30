# IC-114 变更清单：视觉批次 v4

## 结论

A3、B、C 交付并绿；A 玻璃部分（A1/A2）按 A1 停线未做；D 触发 D2 停线已停（代码在分支上，未绿）。
**未合并 `main`**，分支保留。登记值/出厂值零改动，`schemaVersion` 仍为 **7**。

- **最终绿 tip（H51 包）** = `7fa94b1`（CI **#220**，570 / 0，IPA 990596 字节，SHA-256 `3b4328024d1b4c263f609cb36991197120682fb7e055d5fcc92c64aa867deeb9`）
- **分支当前 tip** = `29c01ae`（子项 D，**红**）

---

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `f5e4715` | feat | ✅ #218 | A3：chrome 显隐过渡动画 |
| 2 | `186297b` | feat | ✅ #219 | B：教程三处修复 |
| 3 | `7fa94b1` | feat | ✅ #220 | C：相簿选择器系统化 + 新建相簿 |
| 4 | `29c01ae` | feat | ❌ #221 | D：放大自动进入隐藏态（D2 停线） |
| 5 | 本次 docs 提交 | docs | — | `Reports/IC-114/` 自验与变更清单 |

---

## 文件变更

### 产品代码

| 文件 | 子项 | 变更 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A3/B/C | **A3**：新增 `S2ChromeVisibilityTransition` 常量与 `s2ChromeVisibilityTransition(isVisible:)` 修饰符，chrome 显隐三连并入。**B**：`S2TutorialGestureHint` 加 `.id(direction)`；步 5 方向改 nil、聚光恒定右下圆钮；`targetRect` 形参 `showsRecentAlbumCapsule` → `markedIndex`；步 2 用 `markedIndex` 取格位；协调器新增 `albumPickerVisibilityDidChange` 与 `didOpenAlbumPickerDuringGuide`；sheet 上压教程提示 + `onChange(sheetState)` 接线。**C**：`S2AlbumPickerListView` 重写为系统风格；`S2AlbumPickerActions` 增 `create`；`onAlbumCreationRequest` 入参；sheet 加 detents 与 grabber；反馈文案映射增一分支 |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | C/D | **C**：新增 `S2AlbumListItem`、`S2FeedbackEventKind.albumCreationFailed`、`reportAlbumCreationFailure()`。**D**：新增 `visibilityBeforeZoom`、**唯一写入口 `setScale(_:)`**（9 处直写全部改道）、只读 `recordedVisibilityBeforeZoom` |
| `PhotoCleanupMVE/Services/PhotoAssetActionService.swift` | C | 协议与 PhotoKit 实装新增 `userAlbumItems()` 与 `createAlbum(named:completion:)`（**只创建集合**） |
| `PhotoCleanupMVE/App/CleanupCoordinator.swift` | C | 新增 `s2UserAlbumItems()`、`requestS2AlbumCreation(named:completion:)` |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | C | 选择器改传 `items` + `thumbnail`；接线 `onAlbumCreationRequest` |
| `PhotoCleanupMVE/Localizable.xcstrings` | B/C | B：步 5 文案改写 + 新增 `s2.tutorial.sheet_hint`；C：新增 6 条（新建相簿、命名框标题/占位/存储、数量、创建失败）。均为纯文本编辑 |

### 测试

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A3 +2；B +5（含既有用例改造与 `targetRect` 全部调用补参）；C +4（含既有选择器用例改造）；D +5。`FakeAssetActionService` 补 `createAlbum` / `userAlbumItems`，`albums` 由 `let` 改 `var` |

---

## 占位值登记

**本卡无出厂值变更，`schemaVersion` 仍为 `7`**；`S2Calibration.swift` 自本卡基线 `2362c4f` 起**整文件零 diff**。

| 常量 | 值 | 子项 | 来源 |
|---|---|---|---|
| `S2ChromeVisibilityTransition.durationSeconds` | 0.2 | A3 | 卡内「约 200ms」 |
| `S2ChromeVisibilityTransition.hiddenScale` | 1.06 | A3 | 卡内 |
| `S2ChromeVisibilityTransition.hiddenBlurRadius` | 8 | A3 | 卡内「0→8pt」 |
| `S2AlbumPickerListView.thumbnailSize` | 40 | C | 卡内「40pt 键图」 |

新增 `UserDefaults` 键：无。新增 `S2CalibrationConfiguration` 字段：无。

---

## 未变更 / 未触碰（范围边界核对）

| 对象 | 状态 |
|---|---|
| `main` | **未合并**，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| `S2Calibration.swift` | **整文件零 diff** |
| `schemaVersion` | 仍为 7 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，逐个 `rev-parse` 核过，未触碰 |
| `.github/`、`Scripts/` | 自基线零 diff（`git diff --name-only` 核过）——**这也是 A1 停线的直接原因** |
| 手势识别器 | 未触碰（G292） |
| **删除/移除相簿成员的新路径** | **零新增**（C 的 diff 已逐行核过，G292 硬闸门） |
| SPEC、Decision_log | 未修改 |
| 三条冲突门禁（K2 / IC-047_004 / IC-047_037） | **未改动**（D2 停线，留给规格修订） |
| ♡ 收藏残影、未定项 22 | 未动 |
| rebase / amend / force push / 删分支 | 未执行 |

---

## 报告提交

`Reports/IC-114/self-check.md` 与 `change-list.md` 随本 docs 提交推送。

按 CLAUDE.md 第五节，`Reports/**` 与 `**.md` 命中 `ci.yml` 的 `paths-ignore`，**该 docs 提交不触发 CI，属预期行为**；本报告指向的验证运行为 **#218 / #219 / #220**（三个已绿子项），以及 **#221**（D 的红，成因逐条登记于自验报告）。另引用 **#217** 的环境日志作为 A1 的 Xcode 版本证据。

按纪律第 7 条，报告与代码同卡同分支，未跨卡回填。
