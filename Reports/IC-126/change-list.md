# IC-126 变更清单：诊断中间帧采样与宿主帧节奏解耦 + XCTest 切 iOS 26 目的地

## 结论

**已合并入 `main`。** 合并提交 `cf2a290`（`cf2a2905a53c901d09009dacd0b2760b3e498a76`），G425 运行 **#244** 绿（593/0，退出码 0）。主跑 #243 在 **iOS 26.2 / iPhone 16** 模拟器上 593/0、退出码 0，IC-122 #239 的 2 处中间帧失败未再现。诊断双击时长改为 (n+2)×200ms（进入 1.0s、退出 1.4s），产品动画常量零改动；`schemaVersion` 仍为 7；测试代码零改动。CI 预算用 1/3。

## 提交清单（feature/ic-126-diagnostic-cadence-ios26，自 `main` `ec40bad`）

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `50b0a7a` | fix | A：新增 `S2DiagnosticDoubleTapTiming`（每阈值 200ms，(n+2)×200ms）；`beginDiagnosticDoubleTap` 的 `durationOverrideSeconds` 改取该式 |
| 2 | `0586ba2` | fix | A2：`S2GeometryDiagnosticsRun` 就地统计进度回调数 / 进度<1 回调数 / 首次回调延迟，中间帧不足消息追加数据；**同时含 A 的「删除 `animationDurationMilliseconds` 抬高两行」hunk**（拆分偏差，见自验报告） |
| 3 | `f53c568` | build（cherry-pick `97ff440`） | B：目的地改 simctl JSON + jq 选 iOS 26.x 最高 minor 的 iPhone；找不到显式失败 |
| 4 | `f4595e8` | fix（cherry-pick `51deb3a`） | B：诊断行 `${}` + 半角括号 |
| 5 | `664864c` | build | B：机型钉死 `iPhone 16`；输出 runtime；失败文案与 simctl 实证行 |
| 6 | `cf2a290` | merge | `--no-ff` 合并 feature 入 `main`（G424 全满足后；合并提交 `cf2a2905a53c901d09009dacd0b2760b3e498a76`） |
| 7 | 本次 docs 提交 | docs | `Reports/IC-126/`（沿 IC-124 / IC-125 先例，合并后以 docs 提交落在 `main`，因需引用合并 SHA 与 G425 运行编号） |

## 文件变更（对 `main`）

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | +72/−9：新 `enum S2DiagnosticDoubleTapTiming`（`S2DoubleTapTransitionEvent` 之前）；`beginDiagnosticDoubleTap` 删去对 `animationDurationMilliseconds` 的抬高、override 改取新式；`S2GeometryDiagnosticsRun` 新增 4 个统计属性、`.started`/`.progressed` 分支计数、`.completed` 失败消息追加数据、新私有 `doubleTapCadenceDescription(hits:minimumMiddleFrames:)`。产品路径（`startDoubleTapTransition` / `advanceDoubleTapTransition` / `finishActiveDoubleTapTransition`）零改动 |
| `Scripts/test-xcode.sh` | +35/−10：目的地选择改 simctl JSON / jq（iOS 26.x 最高 minor、`iPhone 16` 钉死）、失败显式退出 1 并打印列表、诊断行 `${}` 形式、新增 runtime 输出与 `xcrun simctl list devices "<runtime>" available` 实证行。`xcodebuild test` 调用与 `set -euo pipefail` / `trap` 未动 |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `S2DoubleTapTransitionTiming.durationSeconds`（产品双击时长常量）、缓动、`S2AnimationPolicy` | 零改动（④ Lynn 裁定产品动画不动） |
| `PhotoCleanupMVETests/`（含 IC-063 用例的 3/5 中间帧计数断言） | 零改动 |
| `S2DoubleTapTransitionEvent` 枚举、`S2DoubleTapSmoothnessProbeCoordinator` | 零改动（A2 就地统计，未扩探针） |
| `S2CalibrationConfiguration` 字段与出厂值 | 零 diff；`schemaVersion` 仍为 **7** |
| `.github/workflows/ci.yml`、`Scripts/selfcheck.ps1` | 零 diff（IC-125 定稿） |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，`rev-parse` 未变 |
| `feature/ic-122-ios26-simulator`、`probe/*` | 未触碰（只 cherry-pick 读取） |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 / stash 操作 | 未执行 |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增。`S2DiagnosticDoubleTapTiming.secondsPerThreshold = 0.2` 为诊断工具常量（卡内按 #239 实测指定），不属 `S2CalibrationConfiguration` 登记制。

## CI 运行登记

| 运行 | 分支 | 被测提交 | 结论 | 真实退出码 | XCTest |
|---|---|---|---|---|---|
| #243（run 33902258132） | feature | `664864c9798b4d9027ed409602cf682e70462777` | success | 0（步骤 success） | 593 项 0 失败（`Executed 593 tests, with 0 failures (0 unexpected) in 56.325 (108.361) seconds`） |
| #244（run 33903173089，合并后自动触发） | main | `cf2a2905a53c901d09009dacd0b2760b3e498a76` | success（IPA 1063045 字节，SHA-256 `26fe916c37ec2db128e9c22d93e1c30f7bb9942eb15490ce16fdb1ce7b2ef529`） | 0 | 593 项 0 失败 |

## 附录：CLAUDE.md 更新（交 Lynn 执行，占位符已按实测填）

第七节「当前阶段」首行替换为：

```
- `main` = `cf2a2905a53c901d09009dacd0b2760b3e498a76`（IC-126 merge 提交，CI #244，XCTest 593 项 0 失败，Xcode 26.3 工具链 / **iOS 26.2 模拟器**），含 IC-054～IC-126 全部交付。
```

注：本次 docs 提交落在 `cf2a290` 之后，`main` tip 将是该 docs 提交而非 `cf2a290`；首行按卡内模板写合并提交 SHA，与 IC-124 / IC-125 行的写法一致。

同节 CI 工具链行替换为：

```
- CI 工具链 = Xcode 26.3 / iPhoneOS 26.2 SDK（IC-116）；**XCTest 自 IC-126 起跑 iOS 26.2 模拟器（iPhone 16，机型钉死）**——iOS 26 运行时与玻璃渲染覆盖缺口已关闭。
```

实测补注（①，#243 日志；#244 日志未逐行核对）：runner 上 simctl 可用的 iOS 26 运行时为 26.0 / 26.1 / 26.2，脚本按最高 minor 选到 `iOS-26-2` 的 `iPhone 16`（UDID `EADC2067-4553-4FDB-8780-62A3666009F5`）。
