# IC-124 自验报告：IC-123 合并入 main——**合并零冲突，#237 全绿**

## 结论（先行）

**IC-123 已合并入 `main`。** merge 提交 = `0287e9cd8347f8ebdcb7447358de6326eeb53d7c`
（`--no-ff`，信息 `merge: IC-123 s2 fixes into main (IC-124)`，卡内原文），**零冲突**；
合并 CI **#237**（run 33639912356，**attempt 1**，无 rerun）success，**XCTest 593 项 0 失败**
（0 unexpected），真实退出码 0，**Xcode 26.3 工具链**（日志行「Xcode 26.3」①），
IPA 1060792 字节，SHA-256 `41ee10c88f1ad66ce62a5e592841827559530f446f32c7144b8094571bdcd6b9`。
CLAUDE.md 第七节已更新。分支保留未删。**预算 CI 1 + rerun 1，实用 CI 1、rerun 0**
（runner 未出现偶发签名失败，未触发 rerun 授权）。

- **G317 通过**：合并零冲突；`git diff 0287e9c cd89b59` 为空（①实测，无输出、退出码 0）
  ——合并后代码树 == 分支树 == CI #236 被测树，排卡预算的结构必然成立。
- **G318 达成**：#237 success、593/0、真实退出码 0（`set -o pipefail` + `exit "$test_status"`，
  「运行 XCTest」步骤 conclusion=success 佐证）、IPA 已登记。
- **G319 通过**：冻结三链未触碰（合并只前移 `main`）——`feature/ic-089-nx-edge-bounce` 仍
  `b368a6c`、`feature/ic-091-nx-midgesture-handoff` 仍 `6736f1e`、
  `feature/ic-092-nx-window-follow` 仍 `a7cc1ec`（①实测，合并前后逐一 `git rev-parse` 比对无变化）；
  合并后 `main` 上 `S2Calibration.swift:118` 为 `schemaVersion` 唯一 `static let` 定义点，值 == **7**
  （①grep 实测，`grep -rn "schemaVersion"` 全部其余命中均为 `factoryPlaceholder` 无关的测试字面量
  或历史注释，不构成第二个定义点）。

## 输入与范围

- 输入：`IC-20260831-124-merge-123.md`（下发前提：Lynn 对 H56 真机判定通过，④，卡内声明）。
- 开工检查（①）：工作树 `git status --porcelain` 为空；`main` = `f71faae`
  （`f71faaed34a146b536a284c9066406234554cf77`，身份：IC-119 报告提交，短 SHA + 身份比对一致）；
  分支 tip = `cd89b59`（`cd89b5906d5a0b95aeaff94311cd18bbc5829ed6`，身份：IC-123 报告提交，
  commit 摘要含「#236 绿，593 项 0 失败」，与卡内声明一致）；`git merge-base main
  feature/ic-123-s2-fixes` = `f71faae`，确认 `main` 为分支祖先（①实测）。
- 范围边界遵守：零代码改动（本卡只有 merge 提交 + 报告 docs 提交）；SPEC、Decision_log、
  `Scripts/`、`ci.yml` 未动；无 rebase / force push / 删分支。

## 执行记录（顺序按卡）

1. 开工检查 ✓（上节）。
2. `git checkout main` → `git merge --no-ff feature/ic-123-s2-fixes -m "merge: IC-123 s2
   fixes into main (IC-124)"`，因 `main` 是分支祖先，快进树差异为零、`--no-ff` 结构性零冲突。
3. 推送 `main`（`f71faae..0287e9c`）。CI **#237** 见结论，一次即绿，未触发 rerun。
4. CLAUDE.md 第七节「当前阶段」首行更新为实际值（`main` = merge 提交
   `0287e9cd8347f8ebdcb7447358de6326eeb53d7c`、CI #237、593 项 0 失败、Xcode 26.3；
   合并内容登记 IC-123：指示器外观切换同拍重解析、截图缩放基准改 aspectFit 适配尺寸）。
   `<top>/CLAUDE.md` 不在 git 仓库内，本次编辑非提交对象。
5. 本报告与 change-list 随 docs 提交追加推送（同卡同分支 `main`，报告需引用推送后才产生的
   #237 编号与 IPA 哈希，属 CLAUDE.md 第二节第 7 条允许的追加 docs 提交方式）。
6. 分支 `feature/ic-123-s2-fixes` 保留未删。

## 合并带入内容（登记）

IC-123 全部提交（`01219d1` 中央指示切换外观模式滞后修复、`9b04eb6` + `15ddb1f` 横屏截图双击
比例畸变修复、`1f3a992` 附录分隔线并入同拍重解析，以及对应的 `Reports/IC-123/` 两组报告）。
`schemaVersion` 未变，仍为 **7**（IC-123 未涉及出厂值集合变更）。

## CI 与门禁数据（①）

| 项 | 值 |
|---|---|
| 运行编号 | **#237**（run 33639912356，attempt 1） |
| 被测提交 | `0287e9cd8347f8ebdcb7447358de6326eeb53d7c`（merge） |
| XCTest | **593 项 0 失败**（0 unexpected，`in 47.282 (78.538) seconds`） |
| 真实退出码 | 0（`set -o pipefail` + `exit "$test_status"`；「运行 XCTest」步骤 conclusion=success） |
| Xcode | **26.3**（`xcodebuild -version` 日志行①；XCTest 仍跑 iOS 18.5 模拟器，未变） |
| IPA | 1060792 字节，SHA-256 `41ee10c88f1ad66ce62a5e592841827559530f446f32c7144b8094571bdcd6b9` |

本地门禁：本卡零代码改动，未跑构建类门禁；合并后本地 `git diff --check` 干净（退出码 0）。

## 人工判定项

无新增。合并本身不引入行为变更（合并后树与 CI #236 被测树逐字节一致，`git diff 0287e9c
cd89b59` 为空，①）；IC-123 涉及的两项 H56 判定项由 Lynn 在下发前已完成（本卡下发前提，④），
本卡不重复代为下结论。

## 发现但未处理的问题

1. **iOS 26 运行时与玻璃渲染仍未被 CI 覆盖**（XCTest 目的地为 iOS 18.5 模拟器）；
   切换模拟器目的地属待办卡，沿用 IC-119 已登记事项，未变化。
2. IC-123 报告中登记的「发现但未处理」各条（间接消费者 `fitSize`/`requestBaseSize`、
   `assetAspectRatio` 回退比例短暂作用窗口、CI 模拟器版本挂账）随合并进入 `main`，
   处置仍留决策会话，本卡未处理。
