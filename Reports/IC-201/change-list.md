# IC-201 变更清单

- 任务：IC-200 探针宿主补强——测试 D 改用窗口场景宿主 + 两个正对照（只改测试、只打印）
- 基线：`main` = `50aec33642ed8c1e733a154fd1cd3467862bacef`；分支 `feature/ic-201-probe-host`；合并提交 `f78dc7a5e4b8fd7284daa0a62ce152f4bc645645`

## 一、提交

| 提交 | SHA | 内容 | 可单独 cherry-pick |
|---|---|---|---|
| A | `a1e903ae5189ab3e37a1af33f27ad5050bd6a833` | 只改 `PhotoCleanupMVETests/IC200ScrollRestoreTests.swift`（105 增 29 删，`git diff --numstat`） | 是（克隆里自基线 `cherry-pick -x` 退出码 0，摘取后 blob 不变） |

仓库内只有这一个产品相关提交；合并提交 `f78dc7a5e4b8fd7284daa0a62ce152f4bc645645` 的树 `d2744e97747baebde2889db36c6a8d4e03b5f0de` 与 A 提交的树相同。

## 二、逐文件（白名单 1 路径，`git diff --name-only 50aec33642ed8c1e733a154fd1cd3467862bacef..f78dc7a5e4b8fd7284daa0a62ce152f4bc645645` 恰 1 行）

| 路径 | 基线 blob | 新 blob | 改动 |
|---|---|---|---|
| `PhotoCleanupMVETests/IC200ScrollRestoreTests.swift` | `e7cd9252c6c7283d5ca867252c1c90f53efa86b8` | `6e7ee80d0646d03621b0d6a22c0934b362171c7f` | 测试 D `testIC200D_ProbeRestoreAndNestedReaderInWindow` 函数体换成四次 `runProbe`（`control-task`／`control-outer`／`restore-600`／`nested-reader`）；新增 `@MainActor` 私有 helper `runProbe<Root: View>`（取已连接的窗口场景、没有才退回无场景窗口，393 × 852，`makeKeyAndVisible()`，出现后等 1 秒读一次，有 `box` 时经 proxy 滚到第 30 格再等 0.5 秒读第二次，输出一行 `IC200_PROBE …`）、`describe(_:)`（`contentOffset.y／adjustedContentInset.top／contentSize.height`）、`scrollView(in:)`（取代原 `scrollOffsetY(in:)`）；文件末新增 `IC200ProbeCells`（60 格 × 50 pt）、`IC200ControlView`（普通 `ScrollViewReader` + `ScrollView` 正对照）、`IC200RestoreProbeView`（被测一：容器单独），`IC200ProbeView`（被测二）内格子抽成 `IC200ProbeCells()` |

## 三、测试

- 不新增、不删除测试函数：`IC200ScrollRestoreTests` 里 `func test` 仍 4 条（`testIC200A`～`D`），`testIC200A`～`C` 函数体逐字不变（`sim_ic201.py` 核过）。
- `testIC200D` 仍只打印、不断言（零 `XCTAssert`／`XCTUnwrap`）。
- XCTest 总数 995 → 995（#406、#407 均 995 项 0 失败）。

## 四、占位值登记

无。本卡不改任何产品常量、不改 `S2CalibrationConfiguration`、不改 `schemaVersion`（仍 7）、不改目录。

## 五、范围外（本卡未动）

全部产品文件、pbx（`project.pbxproj` 不动，没有新文件）、`Localizable.xcstrings`、其它测试、SPEC 与 Decision_log、`CLAUDE.md`；没有 rebase／amend／force push／删分支；两个更早的 stash（`feature/ic-067-screenshot-detection`）与 `D:/Amazon analysis/` 下两个 worktree 未动。

## 六、人工判定项

无。本卡无界面变化；产出是 CI 日志里 `testIC200D` 打印的四行 `IC200_PROBE`（原文见 `self-check.md` 第九节），读法表的判定留给决策会话。

## 七、后续卡须知的钉子

- 本卡之后 `IC200ScrollRestoreTests.swift` 的测试 D 里不再有 `scrollOffsetY(in:)`，改为 `scrollView(in:)` + `describe(_:)`；若后续卡（IC-200 恢复机制修正卡或把探针转成断言的卡）要引用测试 D 的 helper，以 blob `6e7ee80d0646d03621b0d6a22c0934b362171c7f` 为准。
- 文件末现有 4 个 `private struct`：`IC200ProbeCells`、`IC200ControlView`、`IC200RestoreProbeView`、`IC200ProbeView`（与既有 `IC200ProxyBox`）；新增同名视图前先扫测试目标。
- 窗口宿主写法（`UIApplication.shared.connectedScenes` 取场景 + `UIWindow(windowScene:)` + `makeKeyAndVisible()`）在 CI 的 iOS 26.2 模拟器上 `scene=true key=true`（#406、#407 日志）；后续需要在测试里跑真实 `scrollTo`／布局的卡可沿用，不必再用无场景的 `UIWindow(frame:)`。
