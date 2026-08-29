# IC-109 变更清单（含 v2 重跑，完整替换版）

## 结论

本卡**无任何产品代码改动**。仓库侧变更只有合并提交与报告提交；v2 段除重跑 CI 外无任何仓库写入。`<top>/CLAUDE.md` 基线行更新发生在**仓库之外**（`<top>/` 非 git 仓库）。

---

## 提交清单

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e` | merge | `merge: IC-108 follow + zoom probe into main (IC-109)`；`--no-ff`，双亲 `e08f7de…` + `be8179e…`，ort 策略零冲突 |
| 2 | `bf29deecaf36ebacc2a8dd6e4ac77b0de6b2fe34` | docs | IC-109 v1 报告（记录 attempt 1 红与按卡停止） |
| 3 | 本次 docs 提交 | docs | `Reports/IC-109/` 完整替换，补记 attempt 2 绿 |

三个提交均可单独 cherry-pick。

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

## v2 段的操作（无仓库写入）

| 操作 | 值 |
|---|---|
| `gh run rerun 33236538218` | 执行 1 次，真实退出码 0（G264 预算 1 次） |
| 结果 | #194 **attempt 2** `success`，9/9 步全绿 |
| XCTest | `Executed 525 tests, with 0 failures (0 unexpected) in 24.504 (37.557) seconds` |
| 真实退出码 | 0 |
| IPA | `PhotoCleanupMVE-unsigned.ipa`，**854930** 字节，SHA-256 `76e46e89ee073ddc557aab621c111517d9672d1d6bca4b0c2fc47e50c446724e` |
| artifact | `PhotoCleanupMVE-unsigned-43a89a4bf387`（id `9710774363`，zip **855100** 字节） |

零代码改动，未碰 `ci.yml`、`Scripts/`、`test-xcode.sh`。

---

## 占位值登记

**本卡无出厂值变更，`S2CalibrationConfiguration.schemaVersion` 不递增，合并后 `main` 上仍为 `6`**（`PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`，全仓唯一定义点，①核对）。

IC-108 两个子项均未入 `S2CalibrationConfiguration`：子项 B 的诊断开关为运行态（`S2NativePhotoPager.swift:5358` 注释明载「不入 `S2CalibrationConfiguration`、`schemaVersion` 不动」），同 IC-091 `edgeTolerance` 先例。

冻结链 `feature/ic-092-nx-window-follow` 仍自带 `schemaVersion = 5`，与 `main` 的 6 不冲突（日后解冻按「所有链已用值 + 1」重定）。

---

## `<top>/CLAUDE.md` 变更（仓库外，不进 git）

第七节「当前阶段」**首行一处 hunk**：

- `main` 基线 SHA → 本次报告提交
- merge 提交 → `43a89a4bf3870ebe3c71ba07a7061acfc4f96f1e`
- CI 编号 → **#194（attempt 2）**；XCTest 520 → **525** 项 0 失败
- 交付列表追加「IC-108（A 跟随即时化 / B 双击诊断探针）、IC-109」
- 链内 merge 提交清单追加「IC-109 的 1 个（`43a89a4…`）」

第七节其余小节与「未定项」小节未动。措辞偏离（补注 attempt 2）说明见 `self-check.md`「基线行更新」。

---

## 未变更 / 未触碰（范围边界核对）

| 对象 | 状态 |
|---|---|
| `<top>/SPEC-S2-20260829_v17.md` | 未读写 |
| `<top>/Decision_log.md` | 未读写 |
| `<repo>/.github/workflows/ci.yml` | 只读，未改 |
| `<repo>/Scripts/**`（含 `test-xcode.sh`） | 只读，未改 |
| 产品代码与测试 | **零改动** |
| 冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` | SHA 未变，未合并、未删除 |
| `probe/ic-067-screenshot-subtype` | 未触碰 |
| `feature/ic-108-follow-and-zoom-probe` | 保留不删，tip 仍为 `be8179e…` |
| rebase / force push / 改写历史 / revert / 再次合并 | 未执行 |
| rerun 之外的 gh 写操作 | 未执行 |

---

## 报告提交

`Reports/IC-109/self-check.md` 与 `Reports/IC-109/change-list.md` 为**完整替换版**（纪律第 6 条），随本 docs 提交推送。

按 CLAUDE.md 第五节，`Reports/**` 与 `**.md` 命中 `ci.yml` 的 `paths-ignore`，**该 docs 提交不触发 CI，属预期行为**；本报告指向的验证运行为 **#194 attempt 2**（绿）。

按纪律第 7 条例外条款，本次补记为**同一张卡、同一分支内**的追加 docs 提交（引用的 attempt 2 run 结果、IPA 校验值只在重跑后才产生），未跨卡回填。
