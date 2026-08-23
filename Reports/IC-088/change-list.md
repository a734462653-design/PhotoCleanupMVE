# IC-088 变更清单

`main`：`072d82cce9d1d0f0b3187b0439d87ee29db80b13` → `7cb8c9a20fc279e58edd8e0a4ecb998bb09b2c47`（CI #149，477 项 0 失败）。集成 IC-081/086/087、IC-083、IC-085 v3、IC-082 v2。

## 提交（`main` 上，按时间序）

| SHA | 类型 | 第二父 / 文件 | 说明 |
|---|---|---|---|
| `b042167` | merge | `e21ed18`（087 尖，含 081、086） | 干净合并。带入 `pinchMaxScale` 乘数规则与出厂 6.0 / 天花板 40、`schemaVersion = 3` 版本门控与 Keychain 删除、恢复出厂值文案 |
| `38eb487` | merge | `a9a2318`（083 尖） | 干净合并。带入 `debugAssetLimit` 删除、`selfcheck.ps1` 删段；083 横栏裁满实现此时入库，下一步被 085 覆盖 |
| `931748a` | merge | `510b324`（085 尖） | 冲突 3 文件。`S2View.swift`：取 085 横栏整体（`S2BottomStripLayout` / `S2BottomStripMotionController` / `fillContentSize(cellSize:assetAspectRatio:)`），弃用 083 的 `S2BottomStripItemLayout`、`var assetAspectRatio`、`itemFrameSize(at:)`、`fillContentSize(at:)`；保留 087 的 10 行。测试计数断言按并集重算：字段 43、导出 47、登记 43、decided 34、placeholder 9、`schemaVersion` 3 |
| `0530aa1` | merge | `dc14008`（082 尖） | 冲突 1 文件（测试）。接线状态断言取并集：乘数 effective + `edgePagingTriggerDistance/Velocity` unwired |
| `7cb8c9a` | fix（test） | `S2CalibrationHarnessTests.swift` | CI #148 编译失败修正：`testIC083G158…` 改读 085 等价 API（`S2BottomStripLayout.itemSize(at:currentIndex:expansion:)`、`fillContentSize(cellSize:assetAspectRatio:)`），`S2BottomStripView.init` 参数顺序按 085；断言意图不变 |

## 合并后产品文件（相对 `072d82c`，不含 `Reports/`）

| 文件 | 来源分支 | 说明 |
|---|---|---|
| `App/CleanupCoordinator.swift` | 083 | 删 `debugAssetLimit`（与 083 尖逐字节相同） |
| `Core/S2StateMachine.swift` | 081/086 + 085 | `S2ResolvedParameters` 乘数字段与校验（081）；横栏参数（085） |
| `Features/S2/S2Calibration.swift` | 081/086/087 + 085 + 082 | 乘数规则与出厂值（081/086）、版本门控与 `delete()`（087）、横栏参数集与出厂值（085）、`edgePaging*` 登记 unwired（082）。自动合并，无手工改动 |
| `Features/S2/S2NativePhotoPager.swift` | 082 | Nx 贴边翻页单一机制（与 082 尖逐字节相同） |
| `Features/S2/S2View.swift` | 085 + 087 + 082 | 横栏 = 085；乘数滑杆 `2…10` 与恢复出厂值注释 = 087；082 的 4 行自动合并。083 横栏实现弃用 |
| `Localizable.xcstrings` | 087 + 082 | 087 改 1 值；082 增 11 行。自动合并 |
| `Scripts/selfcheck.ps1` | 083 | 删 `debugAssetLimit` 两段检查（与 083 尖逐字节相同） |
| 测试 3 文件 | 四分支 | 计数断言按并集重算（见自验报告算式）；G158 改读 085 API |

## 出厂值并集（`factoryPlaceholder`，43 项，逐项来源）

| 项 | 值 | 来源 |
|---|---|---|
| `pinchMaxScaleFloor` | 4 | 基线（IC-078） |
| `pinchMaxScaleCeiling` | 40 | 086 |
| `pinchMaxScaleOneToOneMultiplier` | 6 | 086 |
| `zoomSnapBackThreshold` … `hapticOnPhotoSwitch`（25 项） | 与 `072d82c` 相同 | 基线 |
| `bottomStripCurrentItemSize` 30、`bottomStripNeighborItemWidth` 20、`bottomStripNeighborItemHeight` 30、`bottomStripItemSpacing` 3、`bottomStripCurrentItemGap` 13、`bottomStripEdgeFadeWidth` 18.7、`bottomStripLeadingInset` 20.3、`bottomStripSwitchDistance` 23、`bottomStripDecelerationRate` 0.998、`bottomStripExpandDurationMilliseconds` 600、`bottomStripCollapseDurationMilliseconds` 100、`bottomStripFlickVelocityThreshold` 300 | 085（`bottomStripDragMinimumDistance` 由 085 废止） |
| `bottomStripMarkSize` 14、`markPulseDurationMilliseconds` 150、`feedbackToastDurationMilliseconds` 2000 | 与 `072d82c` 相同 | 基线 |

无任一分支都没有的值。`schemaVersion = 3`（087），本卡未递增。

## 测试

- XCTest 总数 477 = 455（基线）+ 3（087 链：G149、G171、G172）+ 1（083：G158）+ 16（085）+ 2（082）。
- 本卡修改：`testIC074G96…`、`testIC074G97…`、`S2ImageLoadingStateTests` 计数断言（并集重算）；接线状态断言（并集）；`testIC083G158…`（改读 085 API）。删除 0 个。

## 未变更 / 未带入

`probe/ic-067-screenshot-subtype`、`feature/ic-085-bottom-strip-parity-contaminated` 未带入；四条 feature 分支远端指针不变、本地未删；SPEC、Decision_log、`CLAUDE.md`、`ci.yml` 未动；`Scripts/` 仅含 083 自带的 `selfcheck.ps1` 改动（历史 `verify-IC-*.ps1` 中 `debugAssetLimit` 残留未动，见自验报告）。

## 占位值登记（本卡）

本卡不新增参数；`schemaVersion` 仍为 **3**（087 登记）。
