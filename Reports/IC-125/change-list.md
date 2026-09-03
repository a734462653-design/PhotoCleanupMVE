# IC-125 变更清单：CI 绿判定哨兵

## 结论

**已合并入 `main`。** 合并提交 `b07660e`（`b07660e00df88ee6b2377777e685f2f1c6fe6b62`），G405 运行 **#242** 绿（593/0，退出码 0）。正向 #240 绿、反向 #241 预期红（退出码 1、哨兵 `::error`、后两步 skipped），哨兵两向实证。runner bash 实证为 `/bin/bash` GNU bash 3.2.57。`schemaVersion` 仍为 7。CI 预算用 2/3。

## 提交清单

| # | 分支 | 提交 | 类型 | 说明 |
|---|---|---|---|---|
| 1 | feature/ic-125-ci-green-sentinel | `de96f6d` | ci | A：「运行 XCTest」步骤加零测试执行哨兵（`test_status == 0` 且日志无 `Executed N tests`(N>0) → `::error title=XCTest 哨兵::…` + `exit 1`；非 0 路径退出码不变）；`Executed [0-9]+ tests?` 容单数；步骤开头输出 `command -v bash` 与 `bash --version` |
| 2 | feature/ic-125-ci-green-sentinel | `93c4322` | ci | B：`selfcheck.ps1` 新增规则——扫 `Scripts/*.sh` 与 `.github/workflows/*.yml`，`\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]` 命中即失败并报 `文件:行号` |
| 3 | probe/ic-125-sentinel-negative | `402cb6e` | probe | 负对照：`Scripts/test-xcode.sh` 在 `xcodebuild test` 前 `exit 0`。**不合并、不删除** |
| 4 | main | `b07660e` | merge | `--no-ff` 合并 feature 入 `main`（G404 全满足后） |
| 5 | main | 本次 docs 提交 | docs | `Reports/IC-125/`（沿 IC-124 先例，合并后以 docs 提交落在 `main`，因需引用合并 SHA 与 G405 运行编号） |

## 文件变更（feature 分支对 `main`）

| 文件 | 变更 |
|---|---|
| `.github/workflows/ci.yml` | 仅「运行 XCTest」步骤：+3 行 bash 诊断；1 处正则 `tests` → `tests?`；+12 行哨兵块（含 2 行注释）。其余步骤零改动 |
| `Scripts/selfcheck.ps1` | +23 行：一条新扫描规则（含 2 行注释），插在测试数量门禁之后、硬编码扫描调用之前；既有规则与输出文案未动；UTF-8 BOM 保留 |

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `Scripts/test-xcode.sh`（feature 分支） | 一字未动；目的地选择逻辑属 IC-122／后续卡 |
| 产品代码、测试代码 | 零改动 |
| `S2CalibrationConfiguration` 字段与出厂值 | 零 diff；`schemaVersion` 仍为 **7** |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，`rev-parse` 未变 |
| `probe/ic-067-screenshot-subtype` 与其余 `feature/ic-0xx-*` | 未触碰 |
| SPEC、Decision_log | 未修改 |
| rebase / amend / force push / 删分支 / stash 操作 | 未执行 |
| 哨兵「测试数地板值」、步骤 `shell: bash` | 未做（卡内范围外，决策会话已否决/裁定无效） |

## 占位值登记

无出厂值/登记值变更，`schemaVersion` 不递增。

## CI 运行登记

| 运行 | 分支 | 被测提交 | 结论 | 真实退出码 |
|---|---|---|---|---|
| #240（run 33796035696） | feature | `93c4322ed777c6faaaab3a7f2838ac7e6dcc2809` | success | 0（步骤 success；`exit "$test_status"`） |
| #241（run 33796133239） | probe | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | failure（预期） | **1**（`Process completed with exit code 1.`） |
| #242（run 33797496062，合并后自动触发） | main | `b07660e00df88ee6b2377777e685f2f1c6fe6b62` | success（593 项 0 失败；IPA 1060791 字节，SHA-256 `61e26edf761e1419302beddeb543836ac798c4dd6c7fde15bdf468772ab7141d`） | 0 |

## 附录：CLAUDE.md 第七节更新（交 Lynn 执行，占位符已按实测填）

「当前阶段」首行替换为：

```
- `main` = `b07660e00df88ee6b2377777e685f2f1c6fe6b62`（IC-125 merge 提交，CI #242，XCTest 593 项 0 失败，Xcode 26.3 工具链），含 IC-054～IC-125 全部交付（IC-125：CI「零测试执行也判绿」哨兵——`Executed N tests`(N>0) 缺失时即使退出码为 0 也判红，负对照 `probe/ic-125-sentinel-negative` 实证）。
```

注：本次 docs 提交落在 `b07660e` 之后，`main` tip 将是该 docs 提交而非 `b07660e`；首行按卡内模板写合并提交 SHA，与 IC-124 那行的写法一致（IC-124 行写的也是合并提交 `0287e9c` 而非其后的 docs 提交 `2018dd5`）。

第八节「常见陷阱」末尾追加：

```
20. **CI 绿不等于测试跑过。** #238 实例：`test-xcode.sh` 在 `xcodebuild test` 之前崩溃、退出码却为 0，job 判绿并上传了一个未经测试验证的 IPA。IC-125 已加哨兵（日志无 `Executed N tests`(N>0) 即判红）；写卡引用任何一次「绿」之前，先确认该次有「XCTest 执行摘要」notice。
21. **shell 变量名后紧邻非 ASCII 字符会被 runner 的旧版 bash 吞进变量名。** `"$name（id=$id）"` 在 macOS 系统 bash 下报 `name（: unbound variable`。一律写 `${name}` 并用半角括号；`selfcheck.ps1` 已常设扫描该模式（IC-125 子项 B）。
```

可顺带补一句实测（①，#240 与 #241 两次日志一致；#242 日志未逐行核对）：runner 上 `command -v bash` = `/bin/bash`，`bash --version` = `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin24)`。
