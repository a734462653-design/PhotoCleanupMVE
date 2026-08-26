# IC-094 变更清单（纯合并卡：090 + 093 → main）

本卡**不含任何内容改动**——两次 `--no-ff` 合并均零冲突，没有解冲突、没有手工编辑、没有任何产品 / 测试 / 脚本 / 文档的字节被本卡改写。下表是「合并带进 `main` 的东西」，不是「本卡写的东西」。

## 合并前后

| 项 | 完整 SHA |
|---|---|
| 合并前 `main` | `bf7bab1f8b9fea1194b57151f0beae34fa03756f` |
| 合并后 `main` | `3b838f08bf1fa927c6885cc69b1bd8cc622eccad` |
| 报告提交后 `main` | 承载本报告的 docs 提交（只含 `Reports/IC-094/`，命中 `paths-ignore`，不触发 CI） |

## 两个 merge 提交

| 步 | merge 提交 | 第一父 | 第二父（被并分支 tip） | 提交信息 |
|---|---|---|---|---|
| 1 | `78bd059dd82a8d6eca4bc8c950991865e2245f47` | `bf7bab1f8b9fea1194b57151f0beae34fa03756f` | `420e72a249dc6fba654f521cdd7f1f1d94585365`（`feature/ic-090-strip-corner-pinch-end`） | `merge: IC-090 into main (IC-094)` |
| 2 | `3b838f08bf1fa927c6885cc69b1bd8cc622eccad` | `78bd059dd82a8d6eca4bc8c950991865e2245f47` | `7525fcbe3add1dac96bc94ecdb4d0768f9929526`（`feature/ic-093-image-upgrade-mark-style`） | `merge: IC-093 into main (IC-094)` |

顺序与提交信息与卡内表格逐字一致。`git log --first-parent --no-merges bf7bab1..main`（报告提交前）**为空**——第一父链上只有这两个 merge 提交。

## 带入的提交

`git log --no-merges bf7bab1..main` 共 **17** 个：IC-090 链 13 个（`bf7bab1..420e72a`）、IC-093 链 4 个（`420e72a..7525fcb`）。093 是 090 tip 的后代，故两段不重叠。

## 累计内容变化（`git diff bf7bab1 main`）

15 个文件，2703 增 60 删：

| 文件 | 增/删 | 来自 |
|---|---|---|
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 9 | IC-090 探针接线 + IC-093 抑制回调接线 |
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | 6 | IC-090 |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 17 | IC-090（`bottomStripCornerRadius`、`schemaVersion` 3 → 4） |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 326 | IC-090 场景 C 探针 + IC-093 `图片替换被抑制` 事件 |
| `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift` | 76 | IC-090 7 行 + IC-093 只升不降判定 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 85 | IC-090 圆角裁切 + IC-093 标记双色化与抑制回调 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 929 | 两卡断言 |
| `PhotoCleanupMVETests/S2ImageLoadingStateTests.swift` | 328 | 两卡断言 |
| `PhotoCleanupMVETests/S2StateMachineTests.swift` | 3 | IC-090 |
| `Reports/IC-068/export-format.md` | 33 | IC-090 一节 + IC-093 一节，**只增不删** |
| `Reports/IC-090/*`（3 个） | 701 | IC-090 报告与阶段三分析 |
| `Reports/IC-093/*`（2 个） | 250 | IC-093 报告 |

## 产品行为净变化（相对 `bf7bab1`）

1. **横栏项目圆角** `bottomStripCornerRadius`，出厂 **8/3 pt**（= 8 px @3x），项目内容与待删标记叠层同受裁切（IC-090 R1/R3，H36 通过）。
2. **`schemaVersion` 3 → 4**（IC-090 因出厂值集合新增一项而递增）。旧包写入的 Keychain 条目在本包首次冷启动时整套丢弃取出厂值——IC-087 版本门控的既有语义。
3. **图像替换只升不降**：同一资产已有已显示图像时，像素更少的返回结果不上屏（IC-093 R1，H39 通过）。消除捏合 / 双击后的「清晰 → 糊 → 清晰」闪替。
4. **待删标记双色化**：主图与横栏两处 `trash.circle.fill` 白符号 + 黑底 0.55，固定色值不随明暗模式变化（IC-093 R2，H40 通过）。
5. **诊断埋点**：场景 C 五个逐帧字段与五类事件（IC-090）、`图片替换被抑制` 事件（IC-093）。关闭录制时零副作用。

## 标定参数与出厂值

| 参数 | 变化 | 出厂值 | 来自 |
|---|---|---|---|
| `bottomStripCornerRadius` | **新增** | 8/3 pt | IC-090 |
| `schemaVersion` | 3 → **4** | — | IC-090 |

其余出厂值零 diff。**092 链的 `schemaVersion = 5` 与两个 `nxMomentumBounce*` 参数不在本次合并内**（089/091/092 冻结在分支）。

## 未变更

089 / 091 / 092 三条链一个提交未并入，三个分支的 tip 在本卡前后逐字节未变（`b368a6c` / `6736f1e` / `a7cc1ec`）。两个被并分支 `420e72a` / `7525fcb` 同样未动、未删。`Scripts/`、`ci.yml`、`<top>/SPEC-*.md`、`<top>/Decision_log.md` 无 diff。未 rebase、未 amend、未 force push、未改写历史。
