# IC-20260812-023 不可达单元格断言强度分类

## 结论

| 分类 | 数量 | 判定口径 |
|---|---:|---|
| 强断言 | 26 | 测试把该单元格的事件提交给状态机 API，并断言状态机拒绝该事件。 |
| 弱断言 | 37 | 测试未把该单元格的事件提交给状态机并断言拒绝，只证明该事件与起始状态组合无法按现有入口构造。 |
| 合计 | 63 | 与追溯矩阵中的 63 个“断言型条款”一一对应。 |

## 判定口径与证据边界

- 单元格坐标严格采用守卫测试第 13–15 行的定义：`规格文件|事件|起始状态`；表中同时保留追溯矩阵条款号。
- 守卫测试第 24–53 行负责加载、遍历和分派单元格；强弱判定引用分派后的具体断言分支。
- 仅调用初始化、夹具构造或入场辅助方法，不等于对该单元格事件作强断言；必须实际提交该事件并断言拒绝，才归为强断言。
- 所有测试代码行号均指 `PhotoCleanupMVETests/TransitionTableGuardTests.swift`，对应任务基线提交 `45716ff71376a12667f2e105935fd5aeaee81c64`。
- 本报告只做静态分类，没有修改任何断言，也不包含对弱断言的改动方案。

## 逐单元格分类

| 单元格坐标 | 事件 | 起始状态 | 强/弱 | 判定依据 |
|---|---|---|---|---|
| C34-065<br><code>SPEC-S3-S4-20260812.v6.md&#124;进入页面&#124;S3-1 扫描中</code> | 进入页面 | S3-1 扫描中 | 弱 | `TransitionTableGuardTests.swift:124-127`：只构造既有起始状态并核对当前状态值，未提交进入页面事件。 |
| C34-066<br><code>SPEC-S3-S4-20260812.v6.md&#124;进入页面&#124;S3-2 就绪</code> | 进入页面 | S3-2 就绪 | 弱 | `TransitionTableGuardTests.swift:124-127`：只构造既有起始状态并核对当前状态值，未提交进入页面事件。 |
| C34-067<br><code>SPEC-S3-S4-20260812.v6.md&#124;进入页面&#124;S3-4 空集</code> | 进入页面 | S3-4 空集 | 弱 | `TransitionTableGuardTests.swift:124-127`：只构造既有起始状态并核对当前状态值，未提交进入页面事件。 |
| C34-068<br><code>SPEC-S3-S4-20260812.v6.md&#124;扫描完成&#124;页面外</code> | 扫描完成 | 页面外 | 弱 | `TransitionTableGuardTests.swift:115-121`：仅检查页面外不属于 S3 状态集合后返回，未构造状态机或提交事件。 |
| C34-070<br><code>SPEC-S3-S4-20260812.v6.md&#124;扫描完成&#124;S3-2 就绪</code> | 扫描完成 | S3-2 就绪 | 弱 | `TransitionTableGuardTests.swift:124,128-130`：只检查既有状态与待扫描集合，未提交该单元格事件。 |
| C34-071<br><code>SPEC-S3-S4-20260812.v6.md&#124;扫描完成&#124;S3-4 空集</code> | 扫描完成 | S3-4 空集 | 弱 | `TransitionTableGuardTests.swift:124,128-130`：只检查既有状态与待扫描集合，未提交该单元格事件。 |
| C34-072<br><code>SPEC-S3-S4-20260812.v6.md&#124;扫描中移除项&#124;页面外</code> | 扫描中移除项 | 页面外 | 弱 | `TransitionTableGuardTests.swift:115-121`：仅检查页面外不属于 S3 状态集合后返回，未构造状态机或提交事件。 |
| C34-074<br><code>SPEC-S3-S4-20260812.v6.md&#124;扫描中移除项&#124;S3-2 就绪</code> | 扫描中移除项 | S3-2 就绪 | 弱 | `TransitionTableGuardTests.swift:124,128-130`：只检查既有状态与待扫描集合，未提交该单元格事件。 |
| C34-075<br><code>SPEC-S3-S4-20260812.v6.md&#124;扫描中移除项&#124;S3-4 空集</code> | 扫描中移除项 | S3-4 空集 | 弱 | `TransitionTableGuardTests.swift:124,128-130`：只检查既有状态与待扫描集合，未提交该单元格事件。 |
| C34-076<br><code>SPEC-S3-S4-20260812.v6.md&#124;移除单项&#124;页面外</code> | 移除单项 | 页面外 | 弱 | `TransitionTableGuardTests.swift:115-121`：仅检查页面外不属于 S3 状态集合后返回，未构造状态机或提交事件。 |
| C34-079<br><code>SPEC-S3-S4-20260812.v6.md&#124;移除单项&#124;S3-4 空集</code> | 移除单项 | S3-4 空集 | 强 | `TransitionTableGuardTests.swift:124,131-132`：调用 `removeAsset`，并断言返回拒绝值。 |
| C34-080<br><code>SPEC-S3-S4-20260812.v6.md&#124;全部取消&#124;页面外</code> | 全部取消 | 页面外 | 弱 | `TransitionTableGuardTests.swift:115-121`：仅检查页面外不属于 S3 状态集合后返回，未构造状态机或提交事件。 |
| C34-083<br><code>SPEC-S3-S4-20260812.v6.md&#124;全部取消&#124;S3-4 空集</code> | 全部取消 | S3-4 空集 | 强 | `TransitionTableGuardTests.swift:124,133-134`：调用 `cancelAll`，并断言返回拒绝值。 |
| C34-084<br><code>SPEC-S3-S4-20260812.v6.md&#124;集合变为空&#124;页面外</code> | 集合变为空 | 页面外 | 弱 | `TransitionTableGuardTests.swift:115-121`：仅检查页面外不属于 S3 状态集合后返回，未构造状态机或提交事件。 |
| C34-087<br><code>SPEC-S3-S4-20260812.v6.md&#124;集合变为空&#124;S3-4 空集</code> | 集合变为空 | S3-4 空集 | 强 | `TransitionTableGuardTests.swift:124,135-136`：调用 `collectionBecameEmpty`，并断言返回拒绝值。 |
| C34-088<br><code>SPEC-S3-S4-20260812.v6.md&#124;点击提交&#124;页面外</code> | 点击提交 | 页面外 | 弱 | `TransitionTableGuardTests.swift:115-121`：仅检查页面外不属于 S3 状态集合后返回，未构造状态机或提交事件。 |
| C34-089<br><code>SPEC-S3-S4-20260812.v6.md&#124;点击提交&#124;S3-1 扫描中</code> | 点击提交 | S3-1 扫描中 | 强 | `TransitionTableGuardTests.swift:124,137-142`：调用 `freezeSubmissionSnapshot`，并断言拒绝及被拒状态。 |
| C34-091<br><code>SPEC-S3-S4-20260812.v6.md&#124;点击提交&#124;S3-4 空集</code> | 点击提交 | S3-4 空集 | 强 | `TransitionTableGuardTests.swift:124,137-142`：调用 `freezeSubmissionSnapshot`，并断言拒绝及被拒状态。 |
| C34-171<br><code>SPEC-S3-S4-20260812.v6.md&#124;提交发起&#124;S4-1 已提交</code> | 提交发起 | S4-1 已提交 | 强 | `TransitionTableGuardTests.swift:163-171`：调用 `handle` 提交事件，并断言重复提交拒绝。 |
| C34-172<br><code>SPEC-S3-S4-20260812.v6.md&#124;提交发起&#124;S4-2 已恢复交互</code> | 提交发起 | S4-2 已恢复交互 | 强 | `TransitionTableGuardTests.swift:163-171`：调用 `handle` 提交事件，并断言重复提交拒绝。 |
| C34-173<br><code>SPEC-S3-S4-20260812.v6.md&#124;提交发起&#124;S4-E1 全批成功</code> | 提交发起 | S4-E1 全批成功 | 强 | `TransitionTableGuardTests.swift:163-171`：调用 `handle` 提交事件，并断言重复提交拒绝。 |
| C34-174<br><code>SPEC-S3-S4-20260812.v6.md&#124;提交发起&#124;S4-E2 整批失败</code> | 提交发起 | S4-E2 整批失败 | 强 | `TransitionTableGuardTests.swift:163-171`：调用 `handle` 提交事件，并断言重复提交拒绝。 |
| C34-175<br><code>SPEC-S3-S4-20260812.v6.md&#124;提交发起&#124;S4-E3 结果未知</code> | 提交发起 | S4-E3 结果未知 | 强 | `TransitionTableGuardTests.swift:163-171`：调用 `handle` 提交事件，并断言重复提交拒绝。 |
| C34-176<br><code>SPEC-S3-S4-20260812.v6.md&#124;应用进入非 active&#124;S3-2 外部源</code> | 应用进入非 active | S3-2 外部源 | 弱 | `TransitionTableGuardTests.swift:149-160`：仅检查外部源不属于 S4 状态集合后返回，未构造状态机或提交事件。 |
| C34-182<br><code>SPEC-S3-S4-20260812.v6.md&#124;应用恢复 active&#124;S3-2 外部源</code> | 应用恢复 active | S3-2 外部源 | 弱 | `TransitionTableGuardTests.swift:149-160`：仅检查外部源不属于 S4 状态集合后返回，未构造状态机或提交事件。 |
| C34-188<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到成功回调&#124;S3-2 外部源</code> | 收到成功回调 | S3-2 外部源 | 弱 | `TransitionTableGuardTests.swift:149-160`：仅检查外部源不属于 S4 状态集合后返回，未构造状态机或提交事件。 |
| C34-191<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到成功回调&#124;S4-E1 全批成功</code> | 收到成功回调 | S4-E1 全批成功 | 强 | `TransitionTableGuardTests.swift:163,172-180`：调用 `handle` 成功回调，并断言终态已关闭拒绝。 |
| C34-192<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到成功回调&#124;S4-E2 整批失败</code> | 收到成功回调 | S4-E2 整批失败 | 强 | `TransitionTableGuardTests.swift:163,172-180`：调用 `handle` 成功回调，并断言终态已关闭拒绝。 |
| C34-193<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到成功回调&#124;S4-E3 结果未知</code> | 收到成功回调 | S4-E3 结果未知 | 强 | `TransitionTableGuardTests.swift:163,172-180`：调用 `handle` 成功回调，并断言终态已关闭拒绝。 |
| C34-194<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到失败回调&#124;S3-2 外部源</code> | 收到失败回调 | S3-2 外部源 | 弱 | `TransitionTableGuardTests.swift:149-160`：仅检查外部源不属于 S4 状态集合后返回，未构造状态机或提交事件。 |
| C34-197<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到失败回调&#124;S4-E1 全批成功</code> | 收到失败回调 | S4-E1 全批成功 | 强 | `TransitionTableGuardTests.swift:163,181-186`：调用 `handle` 失败回调，并断言终态已关闭拒绝。 |
| C34-198<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到失败回调&#124;S4-E2 整批失败</code> | 收到失败回调 | S4-E2 整批失败 | 强 | `TransitionTableGuardTests.swift:163,181-186`：调用 `handle` 失败回调，并断言终态已关闭拒绝。 |
| C34-199<br><code>SPEC-S3-S4-20260812.v6.md&#124;收到失败回调&#124;S4-E3 结果未知</code> | 收到失败回调 | S4-E3 结果未知 | 强 | `TransitionTableGuardTests.swift:163,181-186`：调用 `handle` 失败回调，并断言终态已关闭拒绝。 |
| C34-200<br><code>SPEC-S3-S4-20260812.v6.md&#124;超时触发&#124;S3-2 外部源</code> | 超时触发 | S3-2 外部源 | 弱 | `TransitionTableGuardTests.swift:149-160`：仅检查外部源不属于 S4 状态集合后返回，未构造状态机或提交事件。 |
| C34-203<br><code>SPEC-S3-S4-20260812.v6.md&#124;超时触发&#124;S4-E1 全批成功</code> | 超时触发 | S4-E1 全批成功 | 强 | `TransitionTableGuardTests.swift:163,187-192`：调用 `handle` 超时事件，并断言终态已关闭拒绝。 |
| C34-204<br><code>SPEC-S3-S4-20260812.v6.md&#124;超时触发&#124;S4-E2 整批失败</code> | 超时触发 | S4-E2 整批失败 | 强 | `TransitionTableGuardTests.swift:163,187-192`：调用 `handle` 超时事件，并断言终态已关闭拒绝。 |
| C34-205<br><code>SPEC-S3-S4-20260812.v6.md&#124;超时触发&#124;S4-E3 结果未知</code> | 超时触发 | S4-E3 结果未知 | 强 | `TransitionTableGuardTests.swift:163,187-192`：调用 `handle` 超时事件，并断言终态已关闭拒绝。 |
| C34-206<br><code>SPEC-S3-S4-20260812.v6.md&#124;应用在此期间被系统终止&#124;S3-2 外部源</code> | 应用在此期间被系统终止 | S3-2 外部源 | 弱 | `TransitionTableGuardTests.swift:149-160`：仅检查外部源不属于 S4 状态集合后返回，未构造状态机或提交事件。 |
| C5-092<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E1 进入&#124;S5-T0</code> | 从 S4-E1 进入 | S5-T0 | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-093<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E1 进入&#124;S5-C</code> | 从 S4-E1 进入 | S5-C | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-094<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E1 进入&#124;S5-F</code> | 从 S4-E1 进入 | S5-F | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-095<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E1 进入&#124;S5-U</code> | 从 S4-E1 进入 | S5-U | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-097<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E2 进入&#124;S5-T0</code> | 从 S4-E2 进入 | S5-T0 | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-098<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E2 进入&#124;S5-C</code> | 从 S4-E2 进入 | S5-C | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-099<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E2 进入&#124;S5-F</code> | 从 S4-E2 进入 | S5-F | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-100<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E2 进入&#124;S5-U</code> | 从 S4-E2 进入 | S5-U | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-102<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E3 进入&#124;S5-T0</code> | 从 S4-E3 进入 | S5-T0 | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-103<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E3 进入&#124;S5-C</code> | 从 S4-E3 进入 | S5-C | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-104<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E3 进入&#124;S5-F</code> | 从 S4-E3 进入 | S5-F | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-105<br><code>SPEC-S5-20260812.v5.md&#124;从 S4-E3 进入&#124;S5-U</code> | 从 S4-E3 进入 | S5-U | 弱 | `TransitionTableGuardTests.swift:207-210`：只构造既有 S5 状态并核对其目标状态，未提交该单元格的入场事件或断言拒绝。 |
| C5-106<br><code>SPEC-S5-20260812.v5.md&#124;用户点击“我已清空最近删除”&#124;外部源</code> | 用户点击“我已清空最近删除” | 外部源 | 弱 | `TransitionTableGuardTests.swift:199-205`：仅检查外部源不属于 S5 状态集合后返回，未构造状态机或提交事件。 |
| C5-108<br><code>SPEC-S5-20260812.v5.md&#124;用户点击“我已清空最近删除”&#124;S5-C</code> | 用户点击“我已清空最近删除” | S5-C | 强 | `TransitionTableGuardTests.swift:213-220,232-237`：调用 `handle` 清空确认事件，并断言当前状态拒绝且无副作用。 |
| C5-109<br><code>SPEC-S5-20260812.v5.md&#124;用户点击“我已清空最近删除”&#124;S5-F</code> | 用户点击“我已清空最近删除” | S5-F | 强 | `TransitionTableGuardTests.swift:213-220,232-237`：调用 `handle` 清空确认事件，并断言当前状态拒绝且无副作用。 |
| C5-110<br><code>SPEC-S5-20260812.v5.md&#124;用户点击“我已清空最近删除”&#124;S5-U</code> | 用户点击“我已清空最近删除” | S5-U | 强 | `TransitionTableGuardTests.swift:213-220,232-237`：调用 `handle` 清空确认事件，并断言当前状态拒绝且无副作用。 |
| C5-111<br><code>SPEC-S5-20260812.v5.md&#124;用户点击“返回确认页”&#124;外部源</code> | 用户点击“返回确认页” | 外部源 | 弱 | `TransitionTableGuardTests.swift:199-205`：仅检查外部源不属于 S5 状态集合后返回，未构造状态机或提交事件。 |
| C5-112<br><code>SPEC-S5-20260812.v5.md&#124;用户点击“返回确认页”&#124;S5-T0</code> | 用户点击“返回确认页” | S5-T0 | 强 | `TransitionTableGuardTests.swift:213,221-225,232-237`：调用 `handle` 返回确认页事件，并断言当前状态拒绝且无副作用。 |
| C5-115<br><code>SPEC-S5-20260812.v5.md&#124;用户点击“返回确认页”&#124;S5-U</code> | 用户点击“返回确认页” | S5-U | 强 | `TransitionTableGuardTests.swift:213,221-225,232-237`：调用 `handle` 返回确认页事件，并断言当前状态拒绝且无副作用。 |
| C5-116<br><code>SPEC-S5-20260812.v5.md&#124;用户离开页面&#124;外部源</code> | 用户离开页面 | 外部源 | 弱 | `TransitionTableGuardTests.swift:199-205`：仅检查外部源不属于 S5 状态集合后返回，未构造状态机或提交事件。 |
| C5-118<br><code>SPEC-S5-20260812.v5.md&#124;用户离开页面&#124;S5-C</code> | 用户离开页面 | S5-C | 强 | `TransitionTableGuardTests.swift:213,226-227,232-237`：调用 `handle` 离开事件，并断言当前状态拒绝且无副作用。 |
| C5-119<br><code>SPEC-S5-20260812.v5.md&#124;用户离开页面&#124;S5-F</code> | 用户离开页面 | S5-F | 强 | `TransitionTableGuardTests.swift:213,226-227,232-237`：调用 `handle` 离开事件，并断言当前状态拒绝且无副作用。 |
| C5-121<br><code>SPEC-S5-20260812.v5.md&#124;应用进入非 active&#124;外部源</code> | 应用进入非 active | 外部源 | 弱 | `TransitionTableGuardTests.swift:199-205`：仅检查外部源不属于 S5 状态集合后返回，未构造状态机或提交事件。 |
| C5-126<br><code>SPEC-S5-20260812.v5.md&#124;应用恢复 active&#124;外部源</code> | 应用恢复 active | 外部源 | 弱 | `TransitionTableGuardTests.swift:199-205`：仅检查外部源不属于 S5 状态集合后返回，未构造状态机或提交事件。 |
| C5-131<br><code>SPEC-S5-20260812.v5.md&#124;应用被系统终止&#124;外部源</code> | 应用被系统终止 | 外部源 | 弱 | `TransitionTableGuardTests.swift:199-205`：仅检查外部源不属于 S5 状态集合后返回，未构造状态机或提交事件。 |

## 完整性摘要

| 检查项 | 结果 |
|---|---:|
| 追溯矩阵不可达坐标 | 63 |
| 分类表坐标 | 63 |
| 唯一坐标 | 63 |
| 强断言 | 26 |
| 弱断言 | 37 |

自验入口：`Scripts/verify-IC-20260812-023.ps1`。
