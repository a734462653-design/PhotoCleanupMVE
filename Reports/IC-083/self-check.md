# IC-083 自验报告（cleanup-debug-limit-and-strip-fill）

## 结论（先行）

R1、R2 完成，CI 一次通过（1/3）。分支 `feature/ic-083-cleanup-and-strip-fill` 自 `main` = `origin/main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出（与 IC-081/082 并行，互不依赖），两个提交，最终被测 `ea3825fcef77ef8d03689b62688a23a3bc74135f`。CI #138 success：XCTest **456 项、0 失败**（= 455 + 1 新增 − 0 删除），9 步 success（`test_status=0`），IPA 754245 字节。`debugAssetLimit` 与 `selfcheck.ps1` 两段检查已删除，`selfcheck.ps1` 本地与 CI 均退出码 0（闸门 A 未触发）；横栏缩略图按资产宽高比裁满项目帧并居中裁切，项目帧尺寸规则与标记位置不变，`PhotoCleanupMVEApp.stripItemContent` 未改。

**一处④实现取定需确认**：缩略图的内容闭包（`S2TemporaryPhotoImageView`，`.fit`）本身不可由横栏改成 `.fill`，因此裁满在 `S2BottomStripView` 内用"内容帧先放大到恰好覆盖项目帧（`S2BottomStripItemLayout.fillSize`，按资产宽 ÷ 高）→ 再以项目帧居中裁切"实现，结果等价于 aspectFill；为此 `S2BottomStripView` 新增 `assetAspectRatio` 闭包参数（默认 `{ _ in 1 }`），由 `S2View` 传入既有的 `assetAspectRatio`。这是对卡内"在 `S2BottomStripView` 内完成"的实现方式解释，`S2View` 的改动仅为一行传参。

H32 留给 Lynn 真机判定。

## 输入、继承与范围

- 任务卡 IC-20260822-083；IC-078 R4 停线报告；Lynn H24-1。
- 开工前 `git status --porcelain` 为空；`git rev-parse main origin/main` 均为 `072d82c…`。
- 范围边界：改动 `App/CleanupCoordinator.swift`（删 1 行 + 1 空行）、`Scripts/selfcheck.ps1`（删 13 行，0 新增）、`Features/S2/S2View.swift`（`S2BottomStripItemLayout`、`S2BottomStripView` 裁满与两个夹具读取口、构造处一行传参）、`S2CalibrationHarnessTests.swift`。未改横栏尺寸参数、间距、惯性、吸附、静止/滑动态切换；未改 `selfcheck.ps1` 其他检查、`scan-hardcoded-user-visible-strings.ps1`、`ci.yml`、历史 `verify-IC-*.ps1`；未改任何出厂值、未新增参数；未新增 XCUITest；未改 SPEC、Decision_log；未合并主干。

## 提交清单

| 提交 | 归属 | 内容 |
|---|---|---|
| `0d08ed5` | R1 | 删除 `static let debugAssetLimit = 300`；`selfcheck.ps1` 删除"调试入口常量定义数必须为 1"与"S1 接管启动后不得再调用调试入口取样"两段 |
| `ea3825f` | R2 | `S2BottomStripItemLayout.fillSize(itemSize:aspectRatio:)`；`S2BottomStripView.assetAspectRatio`、`itemFrameSize(at:)`、`fillContentSize(at:)`；项目内容 `.frame(fill).frame(item).clipped()`，标记 overlay 仍挂在项目帧上；`S2View` 传入 `assetAspectRatio`；G158 |

## 被删除 / 被修改的测试

- 删除 0、修改 0、新增 1：`testIC083G158BottomStripItemsFillAndClipToItemFrame`。计数 455 + 1 = **456**。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| G157 | 满足① | `git grep -c debugAssetLimit -- PhotoCleanupMVE PhotoCleanupMVETests Scripts/selfcheck.ps1` 无输出（0 命中）；`git diff main HEAD -- Scripts/selfcheck.ps1` 新增行 0、删除 13 行；`selfcheck.ps1` 本地退出码 0，CI 步骤"运行结构自验" success |
| G158 | 满足①（夹具驱动，真机未覆盖） | `testIC083G158…`：静止态项目帧 = 邻居 52×44 / 当前 72×72 / 邻居 52×44（尺寸规则不变）；横图 4032:3024 在 52×44 内裁满内容帧 58.67×44、竖图 3024:4032 在 72×72 内 72×96、方图 52×44——均覆盖项目帧且一维相等、宽高比保持；可见内容帧（裁切后）即项目帧；非法比值 / 零尺寸退回项目帧；滑动态三项均为邻居矩形且裁满成立；标记 `isShown`/`size` 与 G108 一致。`git diff main HEAD -- PhotoCleanupMVEApp.swift` 为空 |
| G159 | 满足① | CI #138 所有 `testIC0…` 0 失败（含 IC-081 的 G148/G149 不在本分支，本分支基于 `main`，IC-063～IC-079 全过）；本地三项门禁 0 |
| G160 | 满足① | CI #138（id `32586032920`）success，9 步 success；被测 `ea3825fcef77ef8d03689b62688a23a3bc74135f`；`Executed 456 tests, with 0 failures (0 unexpected) in 26.870 (43.647) seconds`；`test_status=0`；IPA 754245 字节，SHA-256 `993e630069b5413cc54c373130cefc77e25dee53a7843444b5218ea7244db5fc`（CI 报告值），artifact `PhotoCleanupMVE-unsigned-ea3825fcef77` 经 `gh run download`（前四次 EOF，第五次成功）本地 `sha256sum` 一致 |
| 闸门 A | 未触发① | 删除常量后 `selfcheck.ps1` 其余检查全部通过 |
| H32 | 保留给 Lynn | — |

## 报告提交方式

拿到 CI #138 结果后，以一个 docs 提交把本报告与变更清单追加到同一分支（只含 `Reports/IC-083/`，不触发 CI）。

## 发现但未处理

1. 历史 `Scripts/verify-IC-*.ps1`（048/051/054～061/063）仍断言 `debugAssetLimit = 300` 定义恰为 1，现已不成立；卡明示不动（不在 CI 路径）。
2. `Reports/IC-20260814-044/048-SELF-VERIFICATION.md` 等历史报告提及该常量，属历史记录，未动。
3. 缩略图裁满依赖内容闭包把图像以 `.fit` 铺满所给帧——`S2TemporaryPhotoImageView` 的 `Image.resizable().aspectRatio(.fit)` 在与资产同比的帧内恰好铺满；若某资产的 `assetAspectRatio` 返回 0/非法（像素尺寸未解析），退回项目帧即旧行为（③ 真机 H32 可观察未解析瞬间）。
