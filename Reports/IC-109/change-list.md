# IC-109 变更清单

## 结论

本卡**无任何产品代码改动**。仓库侧实际发生的变更只有两项：一次合并提交、一次报告提交。范围内第 4 项（CLAUDE.md 基线行）**未执行**，理由见 `self-check.md`「未执行项」。

---

## 提交清单

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e` | merge | `merge: IC-108 follow + zoom probe into main (IC-109)`；`--no-ff`，双亲 `e08f7de…` + `be8179e…` |
| 2 | 见下方「报告提交」 | docs | `Reports/IC-109/` 自验与变更清单 |

合并策略 `ort`，零冲突，退出码 0。

---

## 合并带入 `main` 的文件（IC-108 交付，非本卡改动）

8 files changed, 1294 insertions(+), 6 deletions(-)

| 文件 | 增/删 |
|---|---|
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 6 +/- |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 390 + |
| `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift` | 20 +/- |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 64 + |
| `PhotoCleanupMVE/Localizable.xcstrings` | 44 + |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 306 + |
| `Reports/IC-108/change-list.md` | 228 +（新建） |
| `Reports/IC-108/self-check.md` | 242 +（新建） |

对应 IC-108 的三个代码提交：`51c14b5`（子项 A 跟随即时化）、`3aea742`（子项 B 双击探针）、`f450566`（B 的编译修正），加 `be8179e`（IC-108 报告）。

---

## 占位值登记

**本卡无出厂值变更，`S2CalibrationConfiguration.schemaVersion` 不递增，合并后 `main` 上仍为 `6`**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`，全仓唯一定义点，①核对）。

IC-108 的两个子项均未入 `S2CalibrationConfiguration`：子项 B 的诊断开关为运行态（`S2NativePhotoPager.swift:5358` 注释明载「不入 `S2CalibrationConfiguration`、`schemaVersion` 不动」），同 IC-091 `edgeTolerance` 先例。

冻结链 `feature/ic-092-nx-window-follow` 仍自带 `schemaVersion = 5`，与 `main` 的 6 不冲突（日后解冻按「所有链已用值 + 1」重定）。

---

## 未变更 / 未触碰（范围边界核对）

| 对象 | 状态 |
|---|---|
| `<top>/SPEC-S2-20260829_v17.md` | 未读写 |
| `<top>/Decision_log.md` | 未读写 |
| `<top>/CLAUDE.md` | **未修改**（范围内第 4 项未执行，理由见自验报告） |
| `<repo>/.github/workflows/ci.yml` | 只读，未改 |
| `<repo>/Scripts/**` | 只读，未改 |
| 冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` | SHA 未变，未合并、未删除 |
| `probe/ic-067-screenshot-subtype` | 未触碰 |
| `feature/ic-108-follow-and-zoom-probe` | 保留不删，tip 仍为 `be8179e…` |
| rebase / force push / 改写历史 | 未执行 |

---

## 报告提交

`Reports/IC-109/self-check.md` 与 `Reports/IC-109/change-list.md` 随本 docs 提交推送。

按 CLAUDE.md 第五节，`Reports/**` 与 `**.md` 命中 `ci.yml` 的 `paths-ignore`，**该 docs 提交不触发 CI，属预期行为**；本报告指向的验证运行为 **#194**（红）与对照运行 **#193**（绿）。

按纪律第 7 条，报告与合并提交同卡同分支，未跨卡回填。
