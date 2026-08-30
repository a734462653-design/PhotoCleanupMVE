# IC-115 变更清单：放大自动隐藏续做（停线收口）

## 结论

未绿，触发「两者都不是 → 停」；IC-116 / IC-117 未开工。**未合并 `main`**。
登记值/出厂值零改动，`schemaVersion` 仍为 **7**。

- **当时最新绿 tip** = `7fa94b1`（IC-114 子项 C，CI #220，570 / 0）
- **分支当前 tip** = `ba3213b`（IC-115，红，CI #222）

## 提交清单

| # | 提交 | 类型 | 绿 | 说明 |
|---|---|---|---|---|
| 1 | `ba3213b` | test | ❌ #222 | 六条门禁按新契约改写 + 修 D 两处 |
| 2 | 本次 docs 提交 | docs | — | `Reports/IC-115/` |

## 文件变更

| 文件 | 变更 |
|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | 转移表 `.doubleTapMainImage` 行按新契约：两条进入行落点 `hiddenNx`；两条退出行改 `conditional(.dynamic)`（落点取决于记录值，非原状态的函数） |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 诊断 `startDoubleTapEntry` 稳定态 `(V=显示, Nx)` → `(V=隐藏, Nx)`（新契约下本就该如此；但**不足以让该阶段可达**，见自验报告） |
| `PhotoCleanupMVETests/S2StateMachineTests.swift` | IC047-004 / IC047-037 / IC047-035 三条按新契约改写 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | K2 改写并更名；E2 / G3 改用隐藏态起手 |
| `PhotoCleanupMVETests/S2ActionBarWiringTests.swift` | 修本卡自己的 `testIC114DScaleChangesWithinZoomDoNotTouchVisibility`（先 `endPinch` 再单击） |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并，仍为 `a013098341f36b1f0b8542055ac698a7569c9d61` |
| `S2Calibration.swift`、`.github/`、`Scripts/` | 零 diff |
| `schemaVersion` | 仍为 7 |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰 |
| 132 条隐藏态手势断言、其他显隐断言、IC047-036 | 未改 |
| `applyDeferredPresentationIfPossible` 的 `zoomScale <= 1` 守卫 | **未动**（动它＝改 IC-104 C / 决策 40 契约，属产品决策） |
| 诊断稳定判据 | **未弱化**（弱化＝调门禁凑绿） |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 | 未执行 |

## 报告提交

`Reports/IC-115/` 随本 docs 提交推送。`Reports/**` 与 `**.md` 命中 `paths-ignore`，
**该 docs 提交不触发 CI，属预期行为**；本报告指向的运行为 **#222**（红，成因逐条登记），
并引用 **#220**（当时最新绿）与 **#217**（Xcode 版本证据）。
