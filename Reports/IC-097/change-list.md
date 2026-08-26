# IC-097 变更清单（纯合并卡：IC-095 → main）

本卡**不含任何内容改动**——一次 `--no-ff` 合并零冲突，没有解冲突、没有手工编辑、没有任何产品 / 测试 / 脚本 / 文档的字节被本卡改写。下表是「合并带进 `main` 的东西」，不是「本卡写的东西」。

## 合并前后

| 项 | 完整 SHA |
|---|---|
| 合并前 `main` | `3cc1e227d17b80f2fd44fa8478cda698652d275d` |
| 合并后 `main` | `8e000fc48f305de929a34ef7d301483461a3b509` |
| 报告提交后 `main` | 承载本报告的 docs 提交（只含 `Reports/IC-097/`，命中 `paths-ignore`，**不触发 CI**） |

## merge 提交

| merge 提交 | 第一父 | 第二父（被并分支 tip） | 提交信息 |
|---|---|---|---|
| `8e000fc48f305de929a34ef7d301483461a3b509` | `3cc1e227d17b80f2fd44fa8478cda698652d275d` | `dae29026ddb7051566f52d62bcc832735445e939`（`feature/ic-095-apply-idempotent-writes`） | `merge: IC-095 into main (IC-097)` |

`git log --merges 3cc1e22..main` **恰一行**；`git log --first-parent --no-merges 3cc1e22..main`（报告提交前）**为空**——第一父链上只有这一个 merge 提交。

## 带入的提交

`git log --no-merges 3cc1e22..main` 共 **7** 个，即 IC-095 分支全部提交：

| # | 完整 SHA | 提交信息首行 |
|---|---|---|
| 1 | `f173d52d0b15d51e1924bd5e094c1773b7985bf3` | `feat(diag): updateUIView 事件追加 wroteAnyGeometry 字段与两类几何写入埋点（IC-095 R1）` |
| 2 | `e43d00d2b2d35b7f60fe752bd55a131b409053f4` | `fix(s2): apply 外层写回与 layoutNativePages 重排条件化（IC-095 R2）` |
| 3 | `7496ad983003e1f90a52d4f2fc31948340c85ace` | `fix(s2): applyPage 下游写入条件化——applyNativeState 幂等、页输入未变不重建（IC-095 R3）` |
| 4 | `013ceeb9b8f5615d8e3d622be98fcf376b2c4225` | `fix(s2): reportNativeViewport 等值不发布（IC-095 R4）` |
| 5 | `685666c5808e2aeb256d6d0f797879c697ea7776` | `feat(diag): 联合居中写入补埋点并计入几何写入总数（IC-095 R1 补）` |
| 6 | `47858f47805460e4155a721843bf5bb6a545bfba` | `test(s2): IC-095 G207 F1~F4 写入条件化断言（夹具驱动）` |
| 7 | `dae29026ddb7051566f52d62bcc832735445e939` | `docs: 完成 IC-095（apply 重进根因修复：写入条件化与幂等）自验与变更清单` |

## 累计内容变化（`git diff 3cc1e22 main`）

6 个文件，1092 增 40 删：

| 文件 | 增 / 删 | 来自 |
|---|---|---|
| `PhotoCleanupMVE/Core/S2StateMachine.swift` | 12 / 2 | IC-095 R4：`reportNativeViewport` 等值不发布 |
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 301 / 36 | IC-095 R1 / R1 补 / R2 / R3：诊断埋点 + `apply` 链写入条件化 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 392 / 2 | IC-095 F1 / F1b / F2 / F3 / F4 五项断言（2 处删除是 `recordUpdateUIView` 调用因新增参数改多行写法） |
| `Reports/IC-068/export-format.md` | 30 / 0 | IC-095 追加一节，**只增不删** |
| `Reports/IC-095/change-list.md` | 116 / 0 | IC-095 报告 |
| `Reports/IC-095/self-check.md` | 241 / 0 | IC-095 报告 |

**合并后 `main` 树与 `dae2902` 树零 diff**（`git diff --stat dae2902 main` 无输出）——上表即 `dae2902` 相对 `3cc1e22` 的全部差异，合并没有引入任何额外改写。

## 产品行为净变化（相对 `3cc1e22`）

**用户可见行为与几何结果：零变化。** IC-095 的全部改动形式都是「条件不成立时写入的值与现值完全相同，因此不写」——写入的值、条件成立时的写入时机、最终几何全部与改前一致。

不可见的变化三项（真机由 H41 定量取证，Lynn 2026-08-26 判定通过）：

1. **静止态与「输入未变」的重进不再产生几何写入、不再强制布局**——`layoutSubviews` 回调次数大幅下降；H41 场景三（静止 5 秒）实测几何写入 **2 → 0**。
2. **内层手势 / 缩放 / 减速 / 过渡动画在途时，外层偏移不再被逐帧写回静止值**——UIKit 自身的嵌套滚动交接行为不再被掩盖；H41 场景一（Nx 平移）实测 `apply` / `layoutNativePages` 来源的外层写入 **181 → 0**。
3. **`reportNativeViewport` 收到与当前值相同的视口时不再触发一次 `objectWillChange`**，SwiftUI 重进次数随之下降。`@Published` 属性集合未变、发布出去的值序列与时序未变。

诊断导出格式的追加（`Reports/IC-068/export-format.md` IC-095 节）：`updateUIView` 事件 `details` 追加 `写入任意几何=true|false`；新增 `页frame写入`、`内层setContentOffset`、`联合居中写入` 三类事件；头部「格式版本=1」未递增，逐帧字段一个未加。

## 占位值登记

**本卡未新增、未修改、未删除任何 `factoryPlaceholder` 占位值。** 合并带入的 IC-095 链同样未加字段、未改出厂值。

`S2CalibrationConfiguration.schemaVersion` **仍为 4**（合并后 `PhotoCleanupMVE/Features/S2/S2Calibration.swift:118`），与卡内预期核对值一致。三条冻结分支的出厂值集合与版本号（089 = 3、091 = 3、092 = 5）不受本次合并影响。

## 未触碰

| 项 | 状态 |
|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f`，**冻结未动** |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`，**冻结未动** |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562`，**冻结未动** |
| `probe/ic-067-screenshot-subtype` | `9db02b93eccbb87d126602901807e70823535111`，未动未删 |
| `feature/ic-095-apply-idempotent-writes` | `dae29026ddb7051566f52d62bcc832735445e939`，源分支保留、tip 未动 |
| `<top>/SPEC-*.md`、`<top>/Decision_log.md`、`Scripts/`、`ci.yml` | 一字未改 |

未 rebase、未 amend、未 force push、未改写历史、未删任何分支。
