# IC-115 自验报告（v2 终版）：放大自动隐藏续做——**已转绿**

## 结论（先行）

**IC-115 绿。** 分支 tip = `d1fbad6234c792149b53dafca8c5ddd15596d32a`（IC-115 v2 唯一改动），
CI **#223**（run 33306565181）success，**XCTest 575 项 0 失败**，真实退出码 0，
IPA 991043 字节，SHA-256 `7bfce132468cf9d18efe5752845efdd595f2ffebdc2d58e8c34ee8c40ea1bb92`。

- v1 停线成因（⑤a 与截图沉浸推迟应用在 Nx 截图上判据互斥）已由决策会话裁定：
  推迟应用属规格时序（v17 决策 20/40），**被推翻的是诊断判据"V 变化时双侧须即时一致"的隐含假设**。
  按 `DISPATCH-20260830-115v2-117.md` 把该用例的稳定判据按规格时序分段改写，一个 commit，测试/诊断侧。
- 三条否决全部维持：`applyDeferredPresentationIfPossible` 的 `zoomScale ≤ 1` 守卫未动、
  未改成只看机器侧的半判据、⑤a 未修订。
- **卡面第 3 条核查：Nx 期间无可见几何异常**（①实测，见下节），"无可见效应"裁定未被推翻。
- v2 预算 CI 用 **1/2**（#223）。绿后按联动单进 IC-116。

## 输入与范围

- 输入：`DISPATCH-20260830-115v2-117.md`（IC-115 v2 条款）+ 原单 `DISPATCH-20260830-115-117.md`。
- 继承提交：`e3bbfc2`（IC-115 v1 停线报告；工作树开工时净，短 SHA 与提交身份比对通过）。
- 目标分支：`feature/ic-110-visual-batch`。
- 范围边界：唯一改动为诊断稳定判据分段（`S2NativePhotoPager.swift` 诊断侧）；
  产品行为路径、守卫、⑤a、132 条隐藏态断言、冻结三链、`ci.yml`、`Scripts/` 零改动。

## v2 唯一改动（commit `d1fbad6`，测试/诊断侧）

1. 新增诊断只读访问器 `diagnosticDeferredInterfaceVisibility`：暴露
   `pendingPresentationPage?.interfaceVisibility`（推迟记录携带的目标 V），产品不读。
2. `waitForDiagnosticStableState` 稳定判据按规格时序分段：
   - `zoomState == .nX`（`s > 1` 窗口）：页面侧条件 = `diagnosticInterfaceVisibility == 期望`
     **或** `diagnosticDeferredInterfaceVisibility == 期望`（推迟记录在案且携带目标态）。
     机器侧 V/缩放态、`!isPresentationTransitionActive`、`!isDoubleTapTransitionActive`、
     原生缩放匹配等其余条件原样，**不要求双侧相等**。
   - `zoomState == .oneX`（退出回 `s = 1`）：判据一字未改，双侧收敛照旧。
   - 非截图资产路径零改动：无推迟记录时访问器为 nil，页面侧仍须即时一致。
3. `stabilityDescription` 失败描述镜像同一分段逻辑，补印页面 V 与推迟目标 V。

## 验收门禁逐条

| 门禁 | 结果 | 依据 |
|---|---|---|
| `s > 1` 窗口：机器侧 `V == .hidden` 且页面侧推迟记录在案携带目标态 | ✅ | `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 于 #223 绿；诊断样本"双击进入 Nx：动画结束稳定态"显示 V=隐藏、s=2 已达成稳定（判据放行即推迟记录在案） |
| 退出回 `s = 1`：双侧收敛到记录恢复值 | ✅ | 同用例"双击退出 Nx：动画结束稳定态"样本 V=显示、s=1、zoomScale=1（收敛判据原样复用） |
| 非截图资产路径零改动 | ✅ | 代码路径上仅当推迟记录非空才放宽；#223 全量 575 项 0 失败，无其他用例受扰 |
| 三条否决未触碰 | ✅ | `git show d1fbad6` 仅改诊断判据与访问器；守卫、半判据、⑤a 零 diff |

## 卡面第 3 条：Nx 期间可见几何核查（①实测，#223 诊断样本）

"双击进入 Nx：动画结束稳定态"（V=隐藏、s=2、截图资产强制）：

- 内层照片 `window.frame=(x=-196.67, y=-426, w=786, h=1704)` = 全视口 393×852 的 2x 基准；
- `layer.cornerRadius=0`、`masksToBounds=false`；
- 内层 transform 恒等，`contentSize=(786,1704)`，`zoomScale=2.000000`；
- 中间帧门禁：通过；Q2 `s>1` 全部样本内层 transform 恒等=true；Q3 动画帧 contentOffset 无跳变=true。

与裁定"`s > 1` 期间截图可见几何恒为全视口基准、圆角为 0、与 V 无关"逐项一致，**无异常，不触发停线**。
退出后样本回到带框几何（`w=259.42,h=562.40`、圆角 28）且 V=显示，与"退出落到记录恢复值的 1x 几何"一致。

## CI 与本地门禁（①）

- **CI #223**（run 33306565181，job "构建、XCTest 与未签名产物" success）：
  被测提交 `d1fbad6234c792149b53dafca8c5ddd15596d32a`，**Executed 575 tests, with 0 failures (0 unexpected)**，
  工作流以 `exit "$test_status"` 原样退出、job success ⇒ 真实退出码 0。
  IPA 991043 字节，SHA-256 `7bfce132468cf9d18efe5752845efdd595f2ffebdc2d58e8c34ee8c40ea1bb92`；
  artifact `PhotoCleanupMVE-unsigned-d1fbad6234c7`（id 9730778426）。
  工具链仍为 Xcode 16.4（Build 16F6）——IC-116 待切。
- 本地门禁（提交前，均退出码 0）：`git diff --check`、`Scripts/selfcheck.ps1`、
  `Scripts/scan-hardcoded-user-visible-strings.ps1`（用户可见硬编码残留 0）。

## v1 停线历史（保留备查）

#221 八用例逐一归类与 #222 的 21 失败根因分析见本报告 v1 版（git 历史 `e3bbfc2`）。
六条旧契约门禁改写与两处 D 修复（`ba3213b`）在 #223 下继续全绿，无需再动。
v1 报告中"连带产品影响"（Nx 期间 chrome 隐藏但截图页面几何不变）已被裁定收编为规格时序：
`s > 1` 期间页面侧显示态变量不落地**无可见效应**（本次实测印证），推迟应用决定的是退出时落到哪套 1x 几何。

## 人工判定项（保留给 Lynn 真机）

- 截图资产放大回归（联动单 H52 新增第 6 项）：进入放大瞬间跳基准、Nx 期间无异常残留、
  退出后 chrome 与截图几何按恢复的 V 一致落地。夹具与诊断样本均为模拟器证据，真机未覆盖。
- IC-114 遗留两项待补核仍有效（A3 静止态是否影响玻璃透光；Nx 期间手动切 V 后退出按记录值恢复的观感）。

## 发现但未处理的问题

- 无新增。测试计数由 #220 的 570 → #223 的 575（+5 为 v1 `ba3213b` 改写/新增所致，#222 红时未能登记绿计数）。
