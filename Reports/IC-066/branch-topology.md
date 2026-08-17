# IC-066 分支拓扑盘点

## 结论

- 盘点基线：`main` = `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- 盘点时间：2026-08-17（Asia/Taipei）。全程未执行 `fetch`、合并、rebase、cherry-pick 或任何历史改写。
- 卡片写明交接包有八条未合并分支；实跑 `git branch -r --no-merged main` 得到十二条引用。其中 `origin/feature/ic-065-fit-centering` 是任务卡明示与本卡并行的 IC-065，不属于“IC-053 之后、IC-064 交付为止”的交接包历史范围；剔除这一条并行分支后，历史范围内实际有十一条远端跟踪引用。为满足“无遗漏”，主表覆盖这十一条，不把实际引用删减为八条。
- 本地另有 `feature/ic-057-doubletap-response`，其头与 `feature/ic-056-doubletap-scale` 完全相同，且没有对应的 `origin/*` 跟踪引用；它的完整字段在主表后单列，但不重复计入文件热点或推荐合并步骤。并行中的 IC-065 与本卡 IC-066 也不属于交接包；IC-065 的剔除是任务卡范围约束，不是遗漏。
- 十一条分支相对 `main` 的 merge-base 全部是上述 `bccc2d2…`，落后数全部为 0。按逐分支试合，全部为 0 个冲突文件、0 个冲突块。

## 命令与计数口径

逐分支实跑以下只读命令，其中 `<分支>` 实际替换为 `origin/feature/...` 跟踪引用：

```text
git rev-parse <分支>
git merge-base main <分支>
git rev-list --left-right --count main...<分支>
git diff --name-only <merge-base>..<分支>
git merge-tree <merge-base> main <分支>
```

`rev-list` 左值记为落后、右值记为领先。冲突块按 `merge-tree` 输出中的 `<<<<<<<` 块起始符计数；冲突文件按包含冲突块的文件去重。这里使用三树只读形式，没有创建临时合并提交，也没有更新索引或工作树。

## 分支总表

| 分支名 | 对应任务卡 | 分支头提交 | 分叉基点 | 领先／落后 | 依赖关系 | 变更文件集 | 冲突预测 |
|---|---|---|---|---:|---|---|---|
| `feature/ic-054-calibration-harness` | IC-054 | `16c03234f96f12af10843b1df2602214f2e71a74` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 3／落后 0 | 直接基于 `main` | F01 | 无；0 个文件，0 个块 |
| `feature/ic-055-usable-build` | IC-055（可用构建阶段） | `3bfa5f53bb7742b9dff2a6fdb12ca03f755bee93` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 5／落后 0 | 基于 `feature/ic-054-calibration-harness`；前者头是本分支祖先 | F02 | 无；0 个文件，0 个块 |
| `feature/ic-055-system-parity` | IC-055（系统对齐阶段） | `d562f1a0248b110ed5da031618a36cd3a4331c50` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 7／落后 0 | 基于 `feature/ic-055-usable-build`；前者头是本分支祖先 | F03 | 无；0 个文件，0 个块 |
| `feature/ic-056-doubletap-scale` | IC-056 | `b5d38f01cad45d903d419805ffc27e842f4f25f7` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 9／落后 0 | 基于 `feature/ic-055-system-parity`；前者头是本分支祖先 | F04 | 无；0 个文件，0 个块 |
| `feature/ic-058-native-zoom-paging` | IC-058（并继承 IC-057） | `cc951399502ed20447b34b374e63dfbcd0b7c43d` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 15／落后 0 | 基于 `feature/ic-056-doubletap-scale`；分支内提交 `5980c0b…` 明示继承 IC-057 | F05 | 无；0 个文件，0 个块 |
| `feature/ic-059-regression-and-framing` | IC-059 | `b58cb2be94953ab58cb07ea06ab34cbcc238eb46` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 22／落后 0 | 基于 `feature/ic-058-native-zoom-paging`；前者头是本分支祖先 | F06 | 无；0 个文件，0 个块 |
| `feature/ic-060-tap-and-immersive` | IC-060 | `a340928ce2a088c7fe97c0c0467054eaf2f46724` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 25／落后 0 | 基于 `feature/ic-059-regression-and-framing`；前者头是本分支祖先 | F07 | 无；0 个文件，0 个块 |
| `feature/ic-061-immersive-transition` | IC-061 | `456c93d1ccc0e8a91b8188a9322614ea0205b156` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 34／落后 0 | 基于 `feature/ic-060-tap-and-immersive`；前者头是本分支祖先 | F08 | 无；0 个文件，0 个块 |
| `feature/ic-063-immersive-fullscreen` | IC-063（第一版） | `c6938dd0c041d7c17cac0ffb461586b9c7415a2a` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 36／落后 0 | 基于 `feature/ic-061-immersive-transition`；前者头是本分支祖先 | F09 | 无；0 个文件，0 个块 |
| `feature/ic-063-immersive-transition` | IC-063（v2） | `7b17ea0b5b6f2989e02853f8d5fc7f93c11e8b9b` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 45／落后 0 | 基于 `feature/ic-063-immersive-fullscreen`；前者头是本分支祖先 | F10 | 无；0 个文件，0 个块 |
| `feature/ic-064-toggle-animation` | IC-064 | `5a603f915351791addd91c87d41bb3a5c7e04c38` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 55／落后 0 | 从 IC-063 v2 产品头 `3bb744f4b462d670dce07185ce143f1a59064997` 分叉；未包含 IC-063 v2 的最终报告提交 `7b17ea0…` | F11 | 无；0 个文件，0 个块 |

### 本地别名与并行分支边界

| 分支名 | 对应任务卡 | 分支头提交 | 分叉基点 | 领先／落后 | 依赖关系 | 变更文件集 | 冲突预测 |
|---|---|---|---|---:|---|---|---|
| `feature/ic-057-doubletap-response` | IC-057 | `b5d38f01cad45d903d419805ffc27e842f4f25f7` | `bccc2d2deadf37da470b9270f25ecb0312e6d4de` | 领先 9／落后 0 | 与 `feature/ic-056-doubletap-scale` 指向同一提交；没有独立增量 | F04（与 IC-056 完全相同） | 无；0 个文件，0 个块 |

`origin/feature/ic-065-fit-centering` 是盘点期间并行产生的 IC-065 引用，本卡任务说明明确其与 IC-066 并行且要求本卡不得基于该分支；因此不把其临时头纳入 IC-064 截止的拓扑、热点或推荐顺序。本卡自身分支同理不属于被盘点对象。

## 变更文件集

以下均为各分支相对其实际 merge-base 的完整路径列表，不是只列该任务卡自身最后一笔增量。因此下游分支会包含上游文件。

### F01：IC-054

```text
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
Scripts/verify-IC-20260815-054.ps1
selfcheck_IC-054_report.md
```

### F02：IC-055 可用构建阶段

```text
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
```

### F03：IC-055 系统对齐阶段

```text
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
```

### F04：IC-056

```text
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
```

### F05：IC-058

```text
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
Scripts/verify-IC-20260815-057.ps1
Scripts/verify-IC-20260815-058.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
selfcheck_IC-057_report.md
selfcheck_IC-058_report.md
```

### F06：IC-059

```text
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
Scripts/verify-IC-20260815-057.ps1
Scripts/verify-IC-20260815-058.ps1
Scripts/verify-IC-20260815-059.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
selfcheck_IC-057_report.md
selfcheck_IC-058_report.md
selfcheck_IC-059_report.md
```

### F07：IC-060

```text
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
Scripts/verify-IC-20260815-057.ps1
Scripts/verify-IC-20260815-058.ps1
Scripts/verify-IC-20260815-059.ps1
Scripts/verify-IC-20260815-060.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
selfcheck_IC-057_report.md
selfcheck_IC-058_report.md
selfcheck_IC-059_report.md
selfcheck_IC-060_report.md
```

### F08：IC-061

```text
.github/workflows/ci.yml
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
Scripts/verify-IC-20260815-057.ps1
Scripts/verify-IC-20260815-058.ps1
Scripts/verify-IC-20260815-059.ps1
Scripts/verify-IC-20260815-060.ps1
Scripts/verify-IC-20260815-061.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
selfcheck_IC-057_report.md
selfcheck_IC-058_report.md
selfcheck_IC-059_report.md
selfcheck_IC-060_report.md
selfcheck_IC-061_report.md
```

### F09：IC-063 第一版

```text
.github/workflows/ci.yml
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
Scripts/verify-IC-20260815-057.ps1
Scripts/verify-IC-20260815-058.ps1
Scripts/verify-IC-20260815-059.ps1
Scripts/verify-IC-20260815-060.ps1
Scripts/verify-IC-20260815-061.ps1
Scripts/verify-IC-20260816-063.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
selfcheck_IC-057_report.md
selfcheck_IC-058_report.md
selfcheck_IC-059_report.md
selfcheck_IC-060_report.md
selfcheck_IC-061_report.md
selfcheck_IC-063_report.md
```

### F10：IC-063 v2

```text
.github/workflows/ci.yml
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Reports/IC-063/diagnostics-sample.md
Reports/IC-063/self-check.md
Scripts/scan-hardcoded-user-visible-strings.ps1
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
Scripts/verify-IC-20260815-057.ps1
Scripts/verify-IC-20260815-058.ps1
Scripts/verify-IC-20260815-059.ps1
Scripts/verify-IC-20260815-060.ps1
Scripts/verify-IC-20260815-061.ps1
Scripts/verify-IC-20260816-063.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
selfcheck_IC-057_report.md
selfcheck_IC-058_report.md
selfcheck_IC-059_report.md
selfcheck_IC-060_report.md
selfcheck_IC-061_report.md
selfcheck_IC-063_report.md
```

### F11：IC-064

```text
.github/workflows/ci.yml
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/App/CleanupCoordinator.swift
PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift
PhotoCleanupMVE/Core/S2StateMachine.swift
PhotoCleanupMVE/Features/S2/S2Calibration.swift
PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift
PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVE/Localizable.xcstrings
PhotoCleanupMVETests/S2CalibrationHarnessTests.swift
PhotoCleanupMVETests/S2StateMachineTests.swift
Reports/IC-063/diagnostics-sample.md
Reports/IC-063/self-check.md
Reports/IC-064/change-list.md
Reports/IC-064/self-check.md
Scripts/scan-hardcoded-user-visible-strings.ps1
Scripts/verify-IC-20260815-054.ps1
Scripts/verify-IC-20260815-055.ps1
Scripts/verify-IC-20260815-056.ps1
Scripts/verify-IC-20260815-057.ps1
Scripts/verify-IC-20260815-058.ps1
Scripts/verify-IC-20260815-059.ps1
Scripts/verify-IC-20260815-060.ps1
Scripts/verify-IC-20260815-061.ps1
Scripts/verify-IC-20260816-063.ps1
selfcheck_IC-054_report.md
selfcheck_IC-055_report.md
selfcheck_IC-056_report.md
selfcheck_IC-057_report.md
selfcheck_IC-058_report.md
selfcheck_IC-059_report.md
selfcheck_IC-060_report.md
selfcheck_IC-061_report.md
selfcheck_IC-063_report.md
```

## 冲突热点文件前十

按“文件出现在多少条分支相对 `main` 的完整变更文件集中”降序；同数时按路径字典序取前十。由于这些分支大体是继承链，累计文件集会使上游文件在全部下游分支中重复出现，这是分支总差异口径的真实结果。

| 排名 | 文件 | 涉及分支数 |
|---:|---|---:|
| 1 | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 11 |
| 2 | `PhotoCleanupMVE/App/CleanupCoordinator.swift` | 11 |
| 3 | `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 11 |
| 4 | `PhotoCleanupMVE/Core/S2StateMachine.swift` | 11 |
| 5 | `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | 11 |
| 6 | `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift` | 11 |
| 7 | `PhotoCleanupMVE/Features/S2/S2View.swift` | 11 |
| 8 | `PhotoCleanupMVE/Localizable.xcstrings` | 11 |
| 9 | `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 11 |
| 10 | `Scripts/verify-IC-20260815-054.ps1` | 11 |

## 推荐合并顺序

若主干合并卡要求逐条关闭全部分支引用，推荐顺序是：

1. `feature/ic-054-calibration-harness`
2. `feature/ic-055-usable-build`
3. `feature/ic-055-system-parity`
4. `feature/ic-056-doubletap-scale`
5. `feature/ic-058-native-zoom-paging`
6. `feature/ic-059-regression-and-framing`
7. `feature/ic-060-tap-and-immersive`
8. `feature/ic-061-immersive-transition`
9. `feature/ic-063-immersive-fullscreen`
10. `feature/ic-063-immersive-transition`
11. `feature/ic-064-toggle-animation`

依据如下：

- 前九条是严格祖先链，按此顺序处理时，每一步都先落依赖再落增量，避免把下游累计差异反向拆回上游。
- IC-063 v2 的最终头 `7b17ea0…` 与 IC-064 的 merge-base 是 `3bb744f…`。前者相对基点只修改 `Reports/IC-063/diagnostics-sample.md` 与 `Reports/IC-063/self-check.md`；后者相对同一基点修改三份 S2 产品文件、一份测试文件并新增两份 IC-064 报告。两侧文件集不相交，实跑 `git merge-tree 3bb744f… 7b17ea0… 5a603f9…` 为 0 个冲突块，因此将 IC-064 放在最后不会引入累计冲突。
- 若负责人不要求逐条形成合并记录，只要求得到最终产品树，可直接以 IC-064 作为累计产品提交链的主候选，再单独处置 IC-063 v2 的两份最终报告；这是减少冗余合并记录的建议，不是本卡执行动作。

本卡没有执行上述任何合并。
