# IC-119 自验报告：视觉链整体合并入 main（IC-110～121）——**合并零冲突，#232 全绿**

## 结论（先行）

**视觉链已合并入 `main`。** merge 提交 = `4808a3e163fdb9300ccf6f356fd7d1da53336d54`
（`--no-ff`，信息按卡原文），**零冲突**；合并 CI **#232**（run 33350515586，**attempt 1**，
无 rerun）success，**XCTest 586 项 0 失败**，真实退出码 0，**Xcode 26.3 工具链**
（日志行「Xcode 26.3」①），IPA 1057426 字节，
SHA-256 `f045f86e8384545c9aee09fcd33bd3dde30d39be649b0276cdb5b0c0e54fd2fe`。
CLAUDE.md 已按附录 A 更新。分支保留未删。**预算 CI 1 + rerun 1，实用 CI 1、rerun 0。**

- **G299 通过**：合并零冲突；`git diff 4808a3e 6e43847` 为空（①实测，无输出退出码 0）
  ——合并后代码树 == 分支树 == CI #231 被测树，排卡预算的结构必然成立。
- **G300 达成**：#232 success、586/0、退出码 0、IPA 已登记；runner 偶发签名未出现，未用 rerun。
- **G301 通过**：冻结三链未触碰（合并只前移 `main`）；合并后 `main` 上
  `S2Calibration.swift:118` 为 `schemaVersion` 唯一定义点，值 == **7**（①grep 实测）。

## 输入与范围

- 输入：`IC-20260830-119-merge-visual-chain.md`（下发即含 Lynn H55 通过前提，④）。
- 开工检查（①）：工作树净；`main` = `a013098`（身份：IC-109 报告提交 ✓）；
  分支 tip = `6e43847`（身份：IC-121 报告提交 ✓）；`git merge-base --is-ancestor` 确认
  `main` 为分支祖先。
- 范围边界遵守：零代码改动（本卡只有 merge 提交 + 报告 docs 提交）；SPEC、Decision_log、
  `Scripts/` 未动；无 rebase / force push / 删分支。

## 执行记录（顺序按卡）

1. 开工检查 ✓（上节）。
2. `git checkout main` → `git merge --no-ff feature/ic-110-visual-batch`，
   ort 策略零冲突，36 文件 +7980/−348。
3. 推送 `main`（`a013098..4808a3e`，直连第 2 次成功——git 直连/gh 代理规律再次成立）。
   CI #232 见结论。
4. CLAUDE.md 按附录 A 更新（A1 当前阶段四行增改 + A2 第八节追加 15～19 条），
   占位符已用实际值替换；冻结三链、分支保留、未定项等行原文保留。
5. 本报告与 change-list 随 docs 提交追加推送（同卡同分支，报告需引用 #232 编号与
   merge SHA，属 CLAUDE.md 第二节第 7 条允许的方式）。
6. 分支 `feature/ic-110-visual-batch` 保留未删。

## 合并带入内容（登记）

IC-110～121 全部提交（IC-110/111/112/113/114/115/116/117/118/120/121 十一张卡的代码与
报告，含 IC-116 的 `ci.yml` Xcode 26 选择步——**合并后 `main` 的 CI 也走 Xcode 26.3，
#232 即为实证，属卡内预告的预期**）。`schemaVersion` 6→7 随 IC-110 子项 A 进入 `main`。

## CI 与门禁数据（①）

| 项 | 值 |
|---|---|
| 运行编号 | **#232**（run 33350515586，attempt 1） |
| 被测提交 | `4808a3e163fdb9300ccf6f356fd7d1da53336d54`（merge） |
| XCTest | **586 项 0 失败**（0 unexpected） |
| 真实退出码 | 0（`set -o pipefail` + `exit "$test_status"`） |
| Xcode | **26.3**（选择步日志行①；XCTest 仍跑 iOS 18.5 模拟器） |
| IPA | 1057426 字节，SHA-256 `f045f86e8384545c9aee09fcd33bd3dde30d39be649b0276cdb5b0c0e54fd2fe` |

本地门禁：本卡零代码改动，未跑构建类门禁；`git diff --check` 于 merge 后干净（退出码 0）。

## 人工判定项

无新增——H55 已由 Lynn 判定通过（本卡下发即前提，④）。合并本身不引入行为变更
（树与 #231 被测树逐字节一致，①）。

## 发现但未处理的问题

1. **iOS 26 运行时与玻璃渲染仍未被 CI 覆盖**（XCTest 目的地为 iOS 18.5 模拟器）；
   切换模拟器目的地属待办卡（CLAUDE.md 已按附录 A 记入）。
2. IC-120 登记的两处保留定值（教程步 6 高亮态、缩略栏待删标记）与 alert 按钮 tint
   问题随链进入 `main`，处置仍留决策会话。
