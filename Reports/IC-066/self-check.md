# IC-066 自验说明

## 结论

本卡在独立分支 `feature/ic-066-preclose-audit` 上完成，基线为 IC-064 最终交付头 `5a603f915351791addd91c87d41bb3a5c7e04c38`。改动只包含 `.github/workflows/ci.yml` 的 `push.paths-ignore` 与 `Reports/IC-066/` 报告；产品源码、测试源码、SPEC 和 Decision_log 均未修改。

当前环境为 Windows，不能执行 Xcode／iOS 模拟器 XCTest。本卡也没有产品或测试代码变化；最终产品与测试代码继续引用 [iOS 构建与自验 #72](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31994638427)：被测提交 `d1318c4bb2c0d937bd5ce9213d474516cd8a6c85`，结论 `success`，实跑 `389` 项 XCTest、`0` 失败。该口径符合本卡确立的规则：自验报告不需要验证自身所在提交，只需准确指向验证产品代码的那次 CI；后续不得为纯报告提交追加 CI 闭环。

## 路径过滤改动

`workflow_dispatch` 仍保持原样；工作流的权限、Runner、测试命令、`pipefail`、退出码传递、IPA 打包与上传逻辑均无改动。唯一工作流差异是：

```yaml
on:
  push:
    paths-ignore:
      - 'Reports/**'
      - '**.md'
  workflow_dispatch:
```

## 触发语义验证

GitHub Actions 的 `paths-ignore` 只在本次 push 的全部变更路径都命中忽略模式时跳过工作流；只要存在一个未命中的路径，push 仍触发。依此逐项验证：

| 变更集合 | 匹配结果 | push 是否触发 |
|---|---|---|
| 只有 `Reports/**` 文件 | 全部命中 `Reports/**` | 否 |
| 只有 Markdown 文件，包括仓库根级 `**.md` | 全部命中 `**.md` | 否 |
| 只有产品或测试源码 | 至少一个路径未命中 | 是 |
| 产品／测试源码与报告同时改动 | 至少一个源码路径未命中 | 是 |
| 工作流与报告同时改动 | `.github/workflows/ci.yml` 未命中 | 是 |
| 手动 `workflow_dispatch` | 不受 `paths-ignore` 约束 | 可手动触发 |

已有提交的路径集合也用只读命令核对：`26d37f4e0967292c83e7d0098bab721338951d4f` 只含两份 `Reports/IC-064/*.md`，`5a603f915351791addd91c87d41bb3a5c7e04c38` 只含一份 `Reports/IC-064/self-check.md`；应用新过滤后，这两类 push 都会被跳过。`8494c79a00bb054dca815da163638b8db83e34dd` 含产品 Swift 与测试 Swift，`d1318c4bb2c0d937bd5ce9213d474516cd8a6c85` 含测试 Swift，均存在未忽略路径，仍会触发。

本卡遵守“禁止联网、禁止操作账号”，因此没有用实际 push 制造一次远端触发记录；上述结论来自工作流配置语义与提交路径集合的本地核对。若负责人需要对纯文档树主动运行一次，保留的 `workflow_dispatch` 可直接使用。

## 盘点核验

- `main` 与 `origin/main` 均为 `bccc2d2deadf37da470b9270f25ecb0312e6d4de`。
- `git branch -r --no-merged main` 实跑得到十二条引用；按任务卡明示范围剔除并行 IC-065 后，对交接包历史范围内十一条远端跟踪引用逐条实跑 `rev-parse`、`merge-base`、`rev-list --left-right --count`、`diff --name-only` 与三树 `merge-tree`；报告中的 SHA、分叉基点和 ahead/behind 与复跑结果一致。无远端引用、与 IC-056 同 SHA 的 IC-057 本地别名也已单列完整字段。
- 十一条逐分支试合均为 `0` 个冲突文件、`0` 个冲突块；没有执行真实合并，也没有更新索引或工作树。
- S2 v14 第九节的仍未定编号、已关闭编号、第十一节七项出厂值与第 157 行覆盖范围均已落表；S1 v7 第九节仍未定编号和已关闭编号也已落表。违规项另表汇总，无“待补”“约”或“大致”结论。

## 本地门禁

| 检查 | 结果 |
|---|---|
| `Scripts/selfcheck.ps1` | 通过；结构、String Catalog、PNG、禁联网门禁与硬编码扫描均通过 |
| XCTest 静态函数数 | `389`，不低于 `389` |
| 工作流差异 | 仅新增上述三行 `paths-ignore` |
| `git diff --check` | 通过 |
| 范围检查 | 仅 `.github/workflows/ci.yml` 与 `Reports/IC-066/*` |

## 执行边界

本卡未执行合并、rebase、cherry-pick、force push、历史改写、联网或账号操作；未修改主干。由于禁止联网，本地分支不会推送，交付停在本地提交。
