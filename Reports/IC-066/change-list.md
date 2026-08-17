# IC-066 变更清单

1. `.github/workflows/ci.yml`
   - 仅为 `push` 新增 `paths-ignore`：`Reports/**` 与 `**.md`。
   - 保留 `workflow_dispatch` 及工作流其他全部内容。
2. `Reports/IC-066/branch-topology.md`
   - 记录十一条实际未合并远端跟踪引用的头提交、merge-base、ahead/behind、依赖、完整变更文件集与只读试合结果。
   - 给出冲突热点前十与推荐合并顺序；没有执行合并。
3. `Reports/IC-066/open-items-actual-values.md`
   - 逐项记录 SPEC-S2 v14 与 SPEC-S1 v7 未定项的生产实际值、定义位置、来源性质和 debug 可调性。
   - 单独汇总“实现自行填值（违反第 157 行）”清单，并核对 S2 第十一节出厂值与第六节豁免项。
4. `Reports/IC-066/self-check.md`
   - 记录路径过滤语义、既有提交路径样本、结构门禁、XCTest 证据引用与本卡自验报告口径。

未修改产品源码、测试源码、SPEC、Decision_log 或工作流其他逻辑。
