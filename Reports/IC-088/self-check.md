# IC-088 自验报告（integrate-081-087）

## 结论（先行）

四条分支已按 087 → 083 → 085 → 082 顺序以 `--no-ff` 合并进 `main`，CI 第二次通过（2/3）。`main` = `origin/main` = `7cb8c9a20fc279e58edd8e0a4ecb998bb09b2c47`：4 个 merge 提交 + 1 个冲突残留修正提交（测试文件）。CI #149 success：XCTest **477 项、0 失败**（= 455 + 3 + 1 + 16 + 2，算式见 G177），9 步 success（`test_status=0`），IPA 771637 字节，SHA-256 本地复核一致。

冲突共 3 处文件级：`S2View.swift`（083 vs 085 横栏，按规则取 085 整体并弃用 083 的 `S2BottomStripItemLayout`/闭包/辅助方法）、`S2CalibrationHarnessTests.swift` 与 `S2ImageLoadingStateTests.swift`（计数断言与登记状态，按并集重算）。闸门 A 未触发：所有产品代码冲突都在第一节规则内。

CI #148（`0530aa1`）失败为编译错误：083 的 G158 测试引用被弃用的 `S2BottomStripItemLayout` / `fillContentSize(at:)`，以及 `assetAspectRatio:` 参数位置不同。按卡第二节第 3 条以普通提交 `7cb8c9a` 修正（测试改读 085 等价 API，断言意图不变），未 amend/force。

`schemaVersion` 仍为 3，未递增。四条分支远端指针未动。H 项留 Lynn。

## 第 1 步核验（①）

- `git status --porcelain` 空；`main` = `origin/main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13`。
- 分支尖（本地 = 远端，merge-base 均为 `072d82c`）：087 `e21ed18`、083 `a9a2318`、085 `510b324`、082 `dc14008`。与卡一致。
- 本地另有 `feature/ic-085-bottom-strip-parity-contaminated`（卡内称 `feature/ic-085-contaminated-local`）与 `probe/ic-067-screenshot-subtype`，未触碰，未带入。

## 合并步骤与提交

| 步 | merge 提交 | 第二父 | 自动合并 | 冲突文件 | 本地三项门禁 |
|---|---|---|---|---|---|
| 1 | `b042167` merge: IC-087 | `e21ed18` | 干净 | — | 0 / 0 / 0 |
| 2 | `38eb487` merge: IC-083 | `a9a2318` | 干净 | — | 0 / 0 / 0 |
| 3 | `931748a` merge: IC-085 | `510b324` | 冲突 | `S2View.swift`、`S2CalibrationHarnessTests.swift`、`S2ImageLoadingStateTests.swift` | 0 / 0 / 0 |
| 4 | `0530aa1` merge: IC-082 | `dc14008` | 冲突 | `S2CalibrationHarnessTests.swift` | 0 / 0 / 0 |
| 修正 | `7cb8c9a` test: G158 改读 085 等价 API | — | — | （CI #148 编译失败残留） | 0 / 0 / 0 |

`git log --first-parent --no-merges 072d82c..0530aa1` 为空（4 个 merge 之间无其他提交）。

## 冲突解决方式（按第一节规则）

### 第 3 步 `S2View.swift`（083 vs 085 横栏）

三个冲突块均为 083 的 `S2BottomStripItemLayout.fillSize` / `itemFrameSize(at:)` / `fillContentSize(at:)` / `var assetAspectRatio` 与 085 的 `S2BottomStripLayout` / `S2BottomStripMotionController` / `fillContentSize(cellSize:assetAspectRatio:)` / `let assetAspectRatio` 对撞。085 已有等价物 → **弃用 083 版本**。为保证无残留，不逐块手改，而是以 `git merge-file` 做三方合并：base = `072d82c`、ours = 087 尖、theirs = 085 尖（技术负责人预演 087+085 在该文件无冲突，实测同样 0 冲突），结果 = 085 的 `S2View.swift` + 087 的 10 行（乘数滑杆 `2...10` 与恢复出厂值注释）。`git diff feature/ic-085-bottom-strip-parity main -- S2View.swift` 仅这 10 行（①）。083 在该文件的全部 45 行新增均为横栏裁满实现，整体弃用；083 的其他改动（`CleanupCoordinator.swift` 删 `debugAssetLimit`、`selfcheck.ps1` 删两段）原样保留——合并后两文件与 083 尖逐字节相同（`diff` 空，①）。

### 第 3 步测试计数（087 的 38/42/23/15 vs 085 的 42/46/34/8）

按合并后 `S2Calibration.swift` 实测重算（①，`grep -c` / `Mirror`）：

- 配置字段 = 085 的 42 + 081 的 `pinchMaxScaleOneToOneMultiplier` 1 = **43**（`var` 行实测 43）
- 导出行 = 43 + 4 头部 = **47**（`exportText` 元组实测 47）
- 登记表 = **43**（`.init(name:` 实测 43）
- decided = **34**（085 值；081 乘数为 placeholder，不增）；placeholder = 085 的 8 + 乘数 1 = **9**；34 + 9 = 43 ✓
- `schemaVersion` = 3（087），导出含 `schemaVersion=3`
- G97 的 decided 名单集合与源码实测集合相等（脚本比对，对称差为空）

落到 `testIC074G96…`（43、47、3）、`testIC074G97…`（43、43、34、9，保留 085 的 `bottomStripFlickVelocityThreshold ∈ placeholder` 断言）、`S2ImageLoadingStateTests` 同名断言（43、34、9）。

### 第 4 步 `S2CalibrationHarnessTests.swift`（087 vs 082 接线状态）

087 新增 `pinchMaxScaleOneToOneMultiplier == .effective` 与 082 把 `edgePagingTriggerDistance/Velocity` 改为 `.unwired` 对撞 → **并集**：三条断言都保留。产品侧 `S2Calibration.swift` 自动合并，两项 `wiringStatus: .unwired`（①）。

### 修正提交 `7cb8c9a`（CI #148 编译失败）

`testIC083G158BottomStripItemsFillAndClipToItemFrame` 原测 083 实现：`S2BottomStripView.itemFrameSize(at:)`、`fillContentSize(at:)`、`S2BottomStripItemLayout.fillSize`，且 `S2BottomStripView.init` 参数顺序为 `onPhotoSwitch:` 在 `assetAspectRatio:` 前。改为读 085 等价物：`S2BottomStripLayout(metrics:).itemSize(at:currentIndex:expansion:)`（静止态 expansion 1、滑动态 0）与 `S2BottomStripLayout.fillContentSize(cellSize:assetAspectRatio:)`；参数顺序按 085。断言逐条保留（项目帧尺寸规则、裁满覆盖且一维相等、宽高比、横图限高/竖图限宽、非法比例/零尺寸回退、滑动态全邻居矩形、标记显隐与尺寸）。注释写明改动依据。这属"冲突残留"（083 测试依赖被弃用实现）。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G175 | 满足① | `git log --merges 072d82c..main`：`b042167`(087) → `38eb487`(083) → `931748a`(085) → `0530aa1`(082) 恰 4 个，信息均为 `merge: IC-0xx into main (IC-088)`；第二父分别 `e21ed18`、`a9a2318`、`510b324`、`dc14008` |
| G176 | 满足①（`debugAssetLimit` 有说明） | 脚本逐分支比对"分支相对 `072d82c` 新增行是否在 main、删除行是否仍在 main"：087 缺 8 行 = 被重算的计数断言（38/42/15）；083 缺 30 行 = 按规则弃用的 `S2BottomStripItemLayout`/闭包/辅助方法，其余（`CleanupCoordinator.swift`、`selfcheck.ps1`、G 测试）全在；085 缺 7 行 = 被重算的计数断言（42/46/8）；082 缺 0 行，`S2NativePhotoPager.swift` 与 082 尖逐字节相同。`S2NxEdgePagingProjection` 全仓 0；`S2BottomStripMotionController` 存在（`S2View.swift` 5 处）。**`debugAssetLimit`**：产品代码与 `selfcheck.ps1`/`ci.yml` 为 0；历史卡脚本 `Scripts/verify-IC-20260814-048.ps1`、`…-051/054/055/056/058/059/060/061/063.ps1` 仍含 20 处——083 分支尖本身如此（083 只清产品代码与 `selfcheck.ps1`），本卡禁止改 `Scripts/`，未动 |
| G177 | 满足① | 算式见上；CI #149 `testIC074G96…`、`testIC074G97…`、`S2ImageLoadingStateTests` 相关断言 passed；`schemaVersion == 3`；出厂值并集见变更清单表（逐项来源分支） |
| G178 | 满足① | CI #149（id `32632822787`）success，9 步 success；被测 `7cb8c9a20fc279e58edd8e0a4ecb998bb09b2c47`；`Executed 477 tests, with 0 failures (0 unexpected) in 36.385 (64.020) seconds`；`test_status=0`；IPA `PhotoCleanupMVE-unsigned.ipa` 771637 字节，SHA-256 `8035bb904fd4b559a816222bae391f70304fb6ff1831392bef2a870d385d307f`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-7cb8c9a20fc2` 本地 `sha256sum` 一致。XCTest 总数算式：基线 455（IC-080，#129）+ 087 链 3（456→458）+ 083 1（456）+ 085 16（471）+ 082 2（457）= 477 ✓。CI #148（`0530aa1`，id `32632650936`）：XCTest 步编译失败（6 条 error，均在 G158），后续步 skipped |
| G179 | 满足① | 合并后 `git fetch` 复核：`origin/feature/ic-087-…` = `e21ed18`、`…083…` = `a9a2318`、`…085…` = `510b324`、`…082…` = `dc14008`，与合并前一致；本地分支一个未删；每步合并后及修正后本地 `selfcheck.ps1` / 字符串扫描 / `git diff --check` 退出码均 0（字符串目录 171 / 引用 171，残留 0） |
| 闸门 A | 未触发① | 产品代码冲突仅 `S2View.swift` 横栏（规则 1），`S2Calibration.swift` 三次均自动合并且结果符合规则 2（并集、出厂值各取其分支） |
| H33 / H34 / H35 / H31(v2) / H24 / H32 | 保留给 Lynn | 装 CI #149 的 `main` 包 |

## 本地门禁真实退出码

每步（5 次）：`selfcheck.ps1` 0、`scan-hardcoded-user-visible-strings.ps1` 0、`git diff --check` 0。

## 报告提交方式

拿到 CI #149 结果后，以一个 docs 提交把本报告与变更清单推到 `main`（只含 `Reports/IC-088/`，不触发 CI）。

## 发现但未处理

1. `debugAssetLimit` 在 10 个历史卡验证脚本中仍有 20 处引用（083 遗留，`Scripts/` 本卡范围外）。G176"全仓 0"按字面未达成，按产品代码 + 当前门禁脚本为 0。
2. 083 的 G158 测试在修正后改测 085 实现，083 的 `S2BottomStripItemLayout` 纯函数边界断言改为对 `S2BottomStripLayout.fillContentSize` 断言（语义相同：非法比例/零尺寸回退项目帧）。083 独有的产品实现在 `main` 上已无测试覆盖对象（实现已弃用），属预期。
3. `Reports/IC-068/export-format.md` 随 082 合入有改动（082 分支内容，非本卡产生）。
4. 技术负责人预演称"087+082 冲突仅在测试文件"，实测一致；"083+085 冲突在 `S2View.swift`"实测还波及两个测试文件的计数断言（087 也参与），均按规则解决。
