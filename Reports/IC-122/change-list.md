# IC-122 变更清单：XCTest 切 iOS 26 模拟器

## 结论

**目的地选型成功、覆盖缺口关闭；但暴露真实红，按纪律停卡，`main` 未合并。**
CI 第 2 次（**#239**，真实结果）593 项、**2 失败**、真实退出码 **65**；
第 1 次（**#238**）为本卡自身脚本 bug 导致的假绿，非有效验证（详见 self-check）。
预算 2 次已用尽，不再重试。

## 提交清单

| # | 提交 | 类型 | 说明 |
|---|---|---|---|
| 1 | `97ff440` | build(ci) | `Scripts/test-xcode.sh` 目的地选择改为从 `simctl` 实存列表优先选最高 iOS 26.x 运行时的 iPhone 模拟器，不存在则显式失败 |
| 2 | `51deb3a` | fix(ci) | 修正提交 1 引入的诊断行 bug：`$destination_name` 后紧邻全角括号在 runner 系统 bash 下触发 `unbound variable` 崩溃（触发 CI #238 假绿），改用 `${}` 花括号 + ASCII 半角括号 |
| 3 | 本次 docs 提交 | docs | `Reports/IC-122/` |

**cherry-pick 提示**：提交 1、2 须成组挑取（单独 cherry-pick `97ff440` 会带入
诊断行 bug，虽不影响选型算法本身，但会在特定 runner 上重现 #238 的假绿现象）。

## 文件变更

`Scripts/test-xcode.sh`：
- 目的地选择不再用 `xcodebuild -showdestinations` 取第一条 `platform:iOS
  Simulator` + `name:iPhone` 命中（此前恰好稳定落在 iOS 18.5）；
- 改为 `xcrun simctl list devices available -j` 取实存设备列表，用 `jq` 按
  `com.apple.CoreSimulator.SimRuntime.iOS-26-<minor>` 标识筛出 iOS 26.x 运行时，
  取 minor 数值最高者，选其下 `isAvailable` 且名称含「iPhone」的第一台设备
  UDID 作为目的地；
- 找不到 iOS 26.x 运行时时，显式打印 `xcrun simctl list devices available`
  完整列表并 `exit 1`，不静默回落到其他版本；
- pipefail、退出码原样透传逻辑不变（未触碰该部分）。

未改动：产品代码、测试代码、`ci.yml`、`Scripts/selfcheck.ps1`、
`Scripts/scan-hardcoded-user-visible-strings.ps1`、任何登记值。

## 未变更 / 未触碰

| 对象 | 状态 |
|---|---|
| `main` | 未合并、未推进，仍为 `2018dd5`（IC-124） |
| 冻结三链 | `b368a6c` / `6736f1e` / `a7cc1ec`，未触碰（G312） |
| `schemaVersion` | 仍为 7，唯一定义（G312） |
| 产品代码、测试代码 | 零改动 |
| `ci.yml` | 零改动 |
| rebase / force push / amend | 未执行 |

## 占位值登记

无出厂值/登记值变更。

## CI 运行记录

| 次序 | Run | 被测提交 | 结论 | XCTest | 退出码 | 备注 |
|---|---|---|---|---|---|---|
| 1（#238） | 33659126364 | `97ff440` | success（**假绿**） | 未执行（0 项） | 0（异常） | 本卡自身脚本 bug 导致，非有效验证，见 self-check「意外发现」 |
| 2（#239） | 33660839328 | `51deb3a` | **failure** | 593 项，**2 失败**，0 unexpected | **65** | 真实结果，见 self-check「失败分类」 |

预算 2 次已用尽。第 3 次不再发起。

## 失败分类摘要（详见 self-check.md）

1 个测试函数（`S2CalibrationHarnessTests.testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`）
2 处断言失败，均与「双击进入 Nx 缩放过渡期间捕获到的动画中间帧数量不足」相关
（实测 1 < 门禁要求 3；对称的「退出 Nx」方向未失败）。分类为
**iOS 26 行为差异（运行时动画帧节奏）**，排除编译与基建原因，不适用像素探针
渲染差异。零修复，处置留给决策会话。

## 发现但未处理的问题

1. `ci.yml`「运行 XCTest」步骤在脚本于测试执行前异常崩溃时，退出码判定路径
   出现过一次「假绿」（#238）：脚本进程实际以非零状态退出、`pipefail` 已声明，
   但外层 `test_status` 最终仍取到 0，导致该步骤成功、后续构建与上传 IPA 步骤
   照常执行，job 整体标绿——而 XCTest 实际一次都没有被执行。具体是哪一层
   吞掉了非零状态未查明（超出本卡「仅动目的地选择逻辑」授权），建议决策会话
   另立卡处理，例如给该步骤加一道「必须能在测试日志里找到 `Executed [0-9]+
   tests` 行」的哨兵校验，不能只信 `test_status`。
2. iOS 26.2 模拟器下的中间帧采样断言失败（见「失败分类」），是否需要调整探针
   容差、修正产品动画时序、或改造断言使其对运行时时序更鲁棒，留决策会话裁定。
3. 目的地选择在同一 iOS 26.x 运行时内部按 `simctl` JSON 原始设备顺序取第一台
   可用 iPhone（本次结果为 `iPhone 16`），未按机型新旧排序；卡内未规定此优先级，
   如实记录供决策会话评估是否需要固定。

## 报告提交

`Reports/IC-122/` 随本 docs 提交追加推送（同卡同分支
`feature/ic-122-ios26-simulator`，报告需引用推送后才产生的 #238/#239 运行编号，
采用 CLAUDE.md 第二节第 7 条的追加 docs 提交方式）。`main` 未合并、未推进。
分支保留不删。
