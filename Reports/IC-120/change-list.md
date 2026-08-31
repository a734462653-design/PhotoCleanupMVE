# IC-120 变更清单：chrome 前景自适应配色 + 角标 z 序修复

## 结论

**两子项全绿。** 最终绿 tip（代码）= `b769067`（CI **#230**，584 / 0，真实退出码 0）。
**未合并 `main`，执行完即停。** 登记值/出厂值零改动，`schemaVersion` 仍为 **7**。CI 用 1/2。

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `ad49af7` | feat | ✅ #230 | A：chrome 前景系统自适应（浅色黑/深色白），118 C 一刀切黑与 117 回落定值废止 |
| 2 | `b769067` | fix | ✅ #230 | B：角标提升到 GlassEffectContainer 之外 + 锚点结构断言 |
| 3 | 本次 docs 提交 | docs | — | `Reports/IC-120/` |

## 文件变更

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2View.swift` | A：`S2ChromeForeground` 两分支统一 `.primary`/`.secondary`；点名六件显式自适应（返回/垃圾桶/爱心/加相簿/最近相簿胶囊/副行）；中央指示撤回钮与提示文字纠偏回自适应、分隔线去写死白；教程完成钮反相配对（底 primary/字 systemBackground）；sheet 提示条、「新建相簿…」行、`.tint(.primary)`；`subtitleOpacity` 常量删除。B：`topBar` 两分支在容器外挂 `confirmationBadge` overlay（锚点边距取 `S2OverlayLayout` 顶排几何，恒红、不吃点击），角标从垃圾桶标签链移除 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | A：`subtitleOpacity == 0.62` 断言随常量删除（注明缘由）。B：新增 `testIC120BBadgeAnchorMatchesTrailingCircleTopCorner` 锚点几何断言 |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| 玻璃材质配方（`S2ChromeGlass`、`s2ChromeGlassBackground` 族）与布局几何（`S2OverlayLayout`） | 零改动（范围外遵守；B 只读取既有几何常量） |
| 角标数字红色 | 保持（A 例外条款） |
| 教程步 6 高亮态白底黑图标、缩略栏待删标记 `S2PendingDeletionMark` | 保留定值并登记（非常规 chrome 前景） |
| 曲线时长、手势识别器 | 未动 |
| `S2Calibration.swift`、`.github/`、`Scripts/` | 零 diff；`schemaVersion` 仍为 7 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增（仍为 7）。删除的 `subtitleOpacity`（0.62）
为视图字面常量（非标定参数），xcstrings 无引用（已扫描）。新增取定（登记）：副行系统
次级色、教程完成钮反相配对、分隔线交系统色。

## 报告提交

`Reports/IC-120/` 随本 docs 提交推送（同卡同分支追加，需引用推送后才产生的 #230 编号
与 IPA 哈希）。命中 `paths-ignore` 不触发 CI，属预期；验证产品代码的运行为 **#230**
（H54 包，被测提交 `b769067`）。
