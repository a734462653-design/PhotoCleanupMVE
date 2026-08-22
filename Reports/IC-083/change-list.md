# IC-083 变更清单

分支 `feature/ic-083-cleanup-and-strip-fill`，自 `main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出。最终被测提交 `ea3825fcef77ef8d03689b62688a23a3bc74135f`（CI #138，456 项 0 失败）。

## 提交

| SHA | 归属 | 文件 | 说明 |
|---|---|---|---|
| `0d08ed5` | R1 | `App/CleanupCoordinator.swift`、`Scripts/selfcheck.ps1` | 删 `static let debugAssetLimit = 300`（含后随空行）；`selfcheck.ps1` 删 13 行（两段检查），无新增行 |
| `ea3825f` | R2 | `Features/S2/S2View.swift`、`S2CalibrationHarnessTests.swift` | `enum S2BottomStripItemLayout { static func fillSize(itemSize:aspectRatio:) }`；`S2BottomStripView`：新增 `var assetAspectRatio: (String) -> CGFloat = { _ in 1 }`、`itemFrameSize(at:)`、`fillContentSize(at:)`；项目内容 `.frame(width: fill.width, height: fill.height).frame(width: item.width, height: item.height).clipped()`，`.overlay(alignment: .topTrailing)` 标记与 `.position` 不变；`S2View` 构造横栏时传 `assetAspectRatio: assetAspectRatio`；G158 |

## 产品行为变化

- `debugAssetLimit` 不再存在；`selfcheck.ps1` 不再检查它。
- 横栏每个缩略图：内容按资产宽 ÷ 高放大到恰好覆盖项目帧，再以项目帧居中裁切（横图裁左右、竖图裁上下），不再靠上留白。当前项 72×72 方形、邻居 52×44 矩形、间距、滑动态尺寸、标记位置与尺寸均不变。

## 测试

新增 1：`testIC083G158BottomStripItemsFillAndClipToItemFrame`；修改 0；删除 0。计数 455 → 456。

## 未变更

`bottomStrip*` 全部参数与横栏手感；`PhotoCleanupMVEApp.swift`（含 `stripItemContent`）；`S2TemporaryPhotoImageView`；`selfcheck.ps1` 其他检查、`scan-hardcoded-user-visible-strings.ps1`、`ci.yml`、历史 verify 脚本；出厂值与参数集合；SPEC、Decision_log；XCUITest。

## 占位值登记

本卡无新增占位值；`assetAspectRatio` 默认 `1` 仅为夹具构造默认，不是产品路径取值（`S2View` 始终传入真实闭包）。
