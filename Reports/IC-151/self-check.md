# IC-151 自验报告

## 一、结论（先行）

- **四个子项都已交付**，顺序 A → B → C → D 各自独立 commit。
- **CI #302（run id `35066348388`）：attempt 1 判红、attempt 2 对同一提交原样复跑全绿。** attempt 2 十一个步骤全 success、真实退出码 **0**、**805 项 0 失败、1 个 launch**、目的地 `OS:26.2, name:iPhone 16`。
- **attempt 1 的红与本卡无关**：唯一失败用例是 `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`，落在本卡 diff 之外的 `S2CalibrationHarnessTests.swift`，是已登记在案的 runner 负载敏感用例（#292a1／#295／#298 三次判红互证），唯一有效落点在本卡**不得触碰**的 `S2NativePhotoPager.swift`，已排进「诊断路径卡」。两侧 SHA-256 实证相同，见第七节。**没有为了让它变绿而改任何代码或放宽任何断言。**
- **子项 A 的 ③ 假设：证实（机制层面）。** 实测 `sizeThatFits`：同一张 160×160 图、同一个 361×120 提案，**复刻甲（无框无裁）回报 361.00×361.00，复刻乙（有框有裁）回报 361.00×120.00**。无框的 `scaledToFill` 确实按填满提案的尺寸回报，溢出 241 pt。
- **但这不是「H71 修好了」的证据**（陷阱 13）。断言 1 钉的是 SwiftUI 的布局机制，不是摆放结果；**修好与否只有 H73 第 1 条真机能判**，执行端不代为下结论。
- **项数对账吻合**：798 − 1 + 8 = **805**，与执行摘要一致。
- **人工判定项 H73 六条原样保留给 Lynn**，前言按卡要求原样抄录。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260915-151-ambient-fixed-color-and-s0-layout.md` |
| 基线 `main` | `1fd6ed0525fde06ce710da4daa2f383d75d2d818` |
| 开工核对 1 | `git merge-base --is-ancestor 53bc9ed main` 退出码 **0** ✔（IC-150 已合并） |
| 开工核对 2 | `git rev-parse main` = `1fd6ed05…` ✔ 以 `1fd6ed0` 开头 |
| 开工核对 3 | `git status --porcelain` **空** ✔（纪律 8，无他人在同一仓库作业） |
| 分支 | `feature/ic-151-ambient-fixed-color-and-s0-layout` |
| 分支 tip（代码） | `35f4e29476d3cec60df40a19e3a2bcdd2aef0ab2` |
| 现状基数 | 798 项（CI #301）→ 本卡 **805** 项 |
| `schemaVersion` | **7，未动**；`S2Calibration.swift` 不在 diff 内 |

范围边界：10 个路径，逐个落在卡内白名单表内。零改动实证与两个未动 S2 文件的 SHA-256 见 `change-list.md` 第二节与本报告第七节。

---

## 三、子项 A：H71 版式塌陷的归因

### 3.1 实测数据（G864 要求的尺寸）

测试函数 `testIC151A_UnframedScaledToFillOverflowsItsProposal`，日志行（CI #302 attempt 2）：

```
IC151A-MEASURED proposal=361.00x120.00 unframed=361.00x361.00 framed=361.00x120.00
```

| 复刻 | 修饰符组合 | 提案 | `UIHostingController.sizeThatFits(in:)` 回报 |
|---|---|---|---|
| 甲（S10，`S0GlassSurface.frost`） | `.resizable().scaledToFill().blur(radius:opaque:).saturation().clipShape()` | 361 × 120 | **361.00 × 361.00** |
| 乙（M9，`S2AmbientBackdropView`） | `.resizable().scaledToFill().frame(width:height:).clipped().blur(…).saturation().clipShape()` | 361 × 120 | **361.00 × 120.00** |

两者同一张 160×160 纯色图、同一个提案，**只差 `.frame(width:height:)` 与 `.clipped()` 两个修饰符**。

### 3.2 归因结论：**证实**（机制层面，①）

- `aspectRatio(contentMode: .fill)` 让子视图按**填满提案**的尺寸布局并**回报那个更大的尺寸**。正方形源图在 361 宽的提案下缩放成 361×361；`.clipShape(shape)` 裁的是这个更大视图**自己**的边界，不是卡的边界。
- 溢出量 **361 − 120 = 241 pt**，以卡中心为中心向上下**各溢出 120.5 pt**。任务卡按 hero 卡高 120～200 估「各约 100 pt」——方向一致、量级吻合（卡高取下限 120 时溢出最大，实测即该情形）。
- 该层 `blur(opaque: true)` **完全不透明**，VStack 里后画的卡盖先画的卡，于是每张卡的磨砂副本都从上一张的「中间」压过来——与第 175 条第三节截图描述（hero 卡被第二张从中间压住、「照片库共 48 GB」只露半行、「正在核对…」被卡下沿切掉）逐句吻合。

### 3.3 为什么模拟器一直是绿的（陷阱 1 的本卡实例，②）

测试宿主下 `ambientReadout.image` 恒为 nil——`requestAmbientImageIfNeeded()` 有 `XCTestConfigurationFilePath` 闸（E4 口径），CI 模拟器的照片库也是空的。`frost` 因此**一帧都没画过**，全部既有断言都扫不到它。这正是「模拟器全绿、真机不过」在本卡的成因。

### 3.4 边界（不得越读）

- **断言 1 是机制断言，不是「修好了」的证据**（陷阱 13：尺寸断言不等于摆放断言）。它证明「无框的 `scaledToFill` 会溢出」这件事在 iOS 26.2 / iPhone 16 上成立，并证明产品侧那条链条确实缺框缺裁；它**不能**证明删掉那一层之后三张卡就竖排了。
- **H73 第 1 条是唯一判据**。若重判仍叠，第 175 条留的第二个嫌疑（每卡一层 `radius 40 / y 14 / opacity 0.42` 的大投影）就是下一个嫌疑——它保留在新配方里未动。
- **「tab bar 压住最后一行」本卡未修**，按卡要求单独记，见第十节第 1 条。

### 3.5 断言 2 的落地方式

`testIC151A_S0GlassSurfaceHasNoImageLayer` 在子项 A 的提交里以 `throw XCTSkip(...)` 落地（那时产品侧那一层还在，正式断言必红），**子项 D 的提交转为正式断言**并补三条针对 needle 自身的正对照。change-list 第六节已记明。

---

## 四、CI 与项数对账

### 4.1 两次 attempt 的完整事实

| 项 | attempt 1 | attempt 2 |
|---|---|---|
| 运行编号 | #302 | #302 |
| run id | `35066348388` | `35066348388`（同一 run，`run_attempt` 由 1 变 2） |
| 被测提交 | `35f4e29476d3cec60df40a19e3a2bcdd2aef0ab2` | **同一提交，代码一字未改** |
| 结论 | **failure** | **success** |
| 步骤 | 11 步中第 8 步「运行 XCTest」failure，9／10 skipped | 11 步**全 success** |
| 真实退出码 | **65** | **0** |
| 执行摘要 notice | `Executed 805 tests, 1 failing test case(s), across 1 launch(es)` | `Executed 805 tests, 0 failing test case(s), across 1 launch(es)` |
| 唯一用例身份去重计数 | — | **805** ✔（与摘要一致，无分段） |
| 失败用例 | `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 一条 | 无 |
| check-run id | `104697398739` | `104703485964` |

**两次 attempt 的 check-run id 分别现取**，未沿用上一次的 id（该陷阱在 IC-146 取 #291 注解时撞过）。

### 4.2 attempt 2 的实证行

- 目的地实证：`{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }`
- 机型钉死实证：`使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)`
- xcodebuild 摘要：`Executed 805 tests, with 0 failures (0 unexpected) in 45.174 (53.131) seconds`；`TEST SUCCEEDED`；`XCTest 已全部通过`
- IC-125 哨兵：执行摘要 notice 存在且 N = 805 > 0 ✔
- IPA 校验 notice：`文件=PhotoCleanupMVE-unsigned.ipa，字节数=1555514，SHA-256=3db9d8f1913ee9ad382c3c8f5e652e2464218b2c14a12df4364b48ed1c1f48ba`
- artifact：`PhotoCleanupMVE-unsigned-35f4e29476d3`，id `10435516617`，zip 大小 1555684 字节

### 4.3 项数对账

```
798   main，CI #301 执行摘要
 − 1   删 testIC146B_AmbientFallsBackToBaseColorWhenLoadFails（取图失败回落，机制已不存在）
 + 8   本卡新增（断言 1、2、3、4、9、11、12、14 各一条）
= 805  ← CI #302 attempt 2 执行摘要实测 805，唯一用例身份去重亦为 805
```

口径按陷阱 22 与记忆 `ci-test-count-chunked-runs`：以 `Executed N tests` 执行摘要为准，并另数唯一 `Test Case` 身份行核对；`across 1 launch(es)` 表明宿主未重启、日志未分段。

### 4.4 CI 预算

卡内预算 3 次。**实际用 2 次**（attempt 1 主跑 + attempt 2 同提交原样复跑）。第二次不是「修」——**一行代码都没改**，它是记忆 `testic063-gate-is-frame-count` 明写的处置：「该用例对 runner 负载敏感：红了先对同一提交原样复跑做对照，别先改代码。」对照结果本身就是「attempt 1 的红是抖动不是回归」的 ① 证据。

---

## 五、逐条验收门禁与测试函数名

| 断言 | 测试函数名 | 所在文件 | CI 日志 |
|---|---|---|---|
| 1 | `testIC151A_UnframedScaledToFillOverflowsItsProposal` | `IC151AmbientFixedColorTests.swift` | `passed (0.015 s)` |
| 2 | `testIC151A_S0GlassSurfaceHasNoImageLayer` | 同上 | `passed (0.041 s)` |
| 3 | `testIC151B_AmbientRegistryMatchesDecision175And176` | 同上 | `passed (0.005 s)` |
| 4 | `testIC151B_AmbientChainHasNoPhotoKitAndNoPublisher` | 同上 | `passed (0.005 s)` |
| 5 | `testIC146B_AmbientMetricsMatchS0AmbientRegistry`（裸数部分） | `IC146ChromeRoundTwoTests.swift` | `passed (0.011 s)` |
| 6 | `testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes` | 同上 | `passed (0.005 s)` |
| 7 | `testIC146B_AmbientSitsBelowPhotoAndTakesNoTouches` | 同上 | `passed (0.026 s)` |
| 8 | `testIC146B_AmbientAddsNoGeometryWrite` | 同上 | `passed (0.009 s)` |
| 9 | `testIC151C_S2ViewNoLongerLoadsAmbientImages` | `IC151AmbientFixedColorTests.swift` | `passed (0.049 s)` |
| 10 | `testIC148AAssertion01RegistryMatchesSpecSection14` | `IC148S0VisualTests.swift` | `passed (0.008 s)` |
| 11 | `testIC151D_S0DropsAmbientImageSourceEntirely` | `IC151AmbientFixedColorTests.swift` | `passed (0.013 s)` |
| 12 | `testIC151D_GlassSurfaceIsTranslucentFillWithoutBaseColor` | 同上 | `passed (0.003 s)` |
| 13 | `testIC148AAssertion04ReusesAmbientWithoutCopyingOrTouchingPhotoKit` | `IC148S0VisualTests.swift` | `passed (0.019 s)` |
| 14 | `testIC151D_S0BehaviorCallSitesUnchanged` | `IC151AmbientFixedColorTests.swift` | `passed (0.005 s)` |

十四条逐条在 attempt 2 日志内核到 `passed`。

**卡内点名必须逐条通过的既有用例**：`IC147S0BehaviorTests` **16 项全部 `passed`**（日志计数 16）；`IC150ShareTests` + `IC150AudioSessionTests` **7 项全部 `passed`**（日志计数 7）；两者源文件均不在 diff 内。`IC146ChromeRoundTwoTests` 19 项（20 − 1）全部 `passed`，`IC148S0VisualTests` 14 项全部 `passed`。attempt 2 日志内 `' failed (` 命中 **0**。

---

## 六、根因假设之外：三条既有断言的「没动」实证

子项 C 只删了 `.onChange(of: machine.currentAssetID)` 回调体内的一行（加只解释那一行的四行注释），**未另起 `.onChange`**。IC-141／IC-143 三条既有断言在改后源码上的命中数（本机用同口径 Python 复算，CI 亦全绿）：

| 断言出处 | needle | 改前 | 改后 |
|---|---|---|---|
| `IC141VideoPlaybackTests` `:829` | 回调体内 `notifyVideoPlaybackOfCurrentPage()` | 1 | **1** |
| `IC141VideoPlaybackTests` `:838` | 回调体内 `notifyLivePlaybackOfCurrentPage()` | 1 | **1** |
| `IC143VideoPolishTests` `:319` | 回调体内 `cancelVideoScrub()` | 1 | **1** |
| `IC141VideoPlaybackTests` `:818` | `machine.interfaceVisibility` 回调体内 `videoPlayback`／`VideoPlayback` | 0 | **0** |

---

## 七、闸门核对

### G862：diff 限于白名单

`git diff --name-status 1fd6ed0..HEAD` 共 10 个路径（见 `change-list.md` 第二节），逐个在白名单内。

零改动实证（`git diff --name-only 1fd6ed0..HEAD -- <前缀> | wc -l`）：

| 前缀／文件 | 命中 |
|---|---|
| `PhotoCleanupMVE/Features/S1/` | **0** |
| `PhotoCleanupMVE/Features/S3/`、`S4/`、`S5/` | **0**、**0**、**0** |
| `PhotoCleanupMVE/Core/` | **0** |
| `PhotoCleanupMVE/Services/`（除被删的 `S0RecentPhotoAmbientLoader.swift`） | **0** |
| `PhotoCleanupMVE/Features/S2/`（除 `S2AmbientBackdrop.swift`／`S2View.swift`） | **0** |
| `.github/` | **0** |
| `Scripts/` | **0** |
| `PhotoCleanupMVE/Localizable.xcstrings` | **0** |
| `PhotoCleanupMVETests/IC147S0BehaviorTests.swift`、`IC150*Tests.swift` | **0** |

两个 S2 未动文件的两侧 SHA-256（`git show <ref>:<path> | sha256sum`）：

| 文件 | `main`=`1fd6ed0` | 分支=`35f4e29` | 相同 |
|---|---|---|---|
| `S2VideoPlayback.swift` | `e014292d33f67acf1dd49277fae41e2558d639df4634e1315659cdd4df25039c` | 同左 | ✔ |
| `S2NativePhotoPager.swift` | `17be1265994d1e4dcfcf8600e7e78db68fdafb451f0e897975077d4d22dce4f9` | 同左 | ✔ |

**G862 满足。**

### G863：标定与冻结链

- `S2Calibration.swift` **不在 diff 内**；`static let schemaVersion = 7` 未动 ✔
- 远端 tip（`git ls-remote origin`，直连不走代理）：

| 分支 | 期望 | 实读 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6c` | `b368a6caee846e664391b0620350395bfe6fbc7f` ✔ |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` ✔ |
| `feature/ic-092-nx-window-follow` | `a7cc1ec` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` ✔ |
| `probe/ic-067-screenshot-subtype` | `9db02b9` | `9db02b93eccbb87d126602901807e70823535111` ✔ |
| `probe/ic-125-sentinel-negative` | `402cb6e` | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` ✔ |
| `probe/ic-137-media-playback` | `486bcb7` | `486bcb769b59eb1146c5a231c7998847206777cc` ✔ |
| `probe/ic-145-scan-service` | `d373afc` | `d373afc7125104c01acfc296829229090e6871ce` ✔ |

**G863 满足。**

### G864：子项 A 先于 B／C／D 且只含测试目标文件

`git log 1fd6ed0..HEAD` 顺序（新→旧）：D → C → B → **A**，即 A 是第一个提交 ✔。
提交 A（`8a3f657`）的文件：`PhotoCleanupMVETests/IC151AmbientFixedColorTests.swift`（新增）+ `PhotoCleanupMVE.xcodeproj/project.pbxproj`（仅该测试文件的四行登记）——无任何产品源码 ✔。
断言 1 的实测尺寸已写入第三节 ✔。假设**证实**，归因栏不写「未定」。

**G864 满足。**

### G865：合并前置

| 条件 | 状态 |
|---|---|
| G862／G863／G864 | 满足 |
| 全部 XCTest 通过 | attempt 2：805 项 0 失败 ✔ |
| 真实退出码 0 | attempt 2：步骤 8 success、`exit "$test_status"`、`TEST SUCCEEDED` ✔ |
| 执行摘要 notice | `Executed 805 tests, 0 failing test case(s), across 1 launch(es)` ✔ |
| 目的地实证行 | `OS:26.2, name:iPhone 16` ✔ |
| IPA 字节数与 SHA-256 | 1555514 / `3db9d8f1…f48ba` ✔ |
| 断言 1～14 逐条函数名 + 日志核 `passed` | 第五节 ✔ |
| 项数对账 | 第 4.3 节 ✔ |
| 既有断言改动逐条旧→新 | `change-list.md` 第五节 ✔ |
| pbxproj 撞号扫描 | 第八节 ✔ |
| 工作树净 | 提交后 `git status --porcelain` 空 ✔ |
| `main` 未被他人推进 | `git ls-remote origin refs/heads/main` = `1fd6ed05…` ✔ |

**G865 满足** → 执行 `--no-ff` 合并入 `main` 并推送。结果见第十二节。

### G866：合并后 `main` 自动运行

见第十二节。

---

## 八、pbxproj 撞号扫描

加登记前**重扫当前最大号**（`grep -o` 实读全文件）：

| 类别 | 现有最大号 | 本卡新号 |
|---|---|---|
| `PBXFileReference` | `100000000000000000000052` | `100000000000000000000053` |
| `PBXBuildFile` | `20000000000000000000004F` | `200000000000000000000050` |

登记脚本内置两道断言：新号**不得已存在于文件内**、且**必须严格大于**现有最大号，任一不成立即中止不写。四个插入锚点各要求**恰一处命中**。删除侧同理：`S0RecentPhotoAmbientLoader` 的四行一次删完，删后全文件该串命中 **0**，`20000000000000000000004C`／`10000000000000000000004F` 两个 id 各 **0**。

依据 IC-134 #262：pbxproj 对象 id 撞号**不报错**，后登记的测试文件会静默掉出编译列表而 CI 照绿。本卡另有一道事后核对——`IC151AmbientFixedColorTests` 的 8 个用例在 CI 日志里逐条有 `Test Case … passed` 行，证明该文件确实进了编译列表。

---

## 九、本地门禁（真实退出码）

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** |
| `Scripts/check-swift-string-structure.ps1 -SelfTest`（IC-149 门禁一） | **0**（两个负对照各判红、正对照零命中） |
| `Scripts/check-scan-needle-variant.ps1 -SelfTest`（IC-149 门禁二） | **0**（两个负对照各判红、正对照零命中） |
| `git diff --check`（工作树） | **0** |
| `git diff 1fd6ed0..HEAD --check`（整段 diff） | **0** |

**本机预验证（记忆 `local-simulation-before-ci`）**：把测试侧的 `strippedSource`／`occurrences`／`slice`／`numericLiterals`／`onChangeBody` 五个 helper 原样移植成 Python，对着**改后的源码**把断言 2、3、4、5、6、7、9、10、11、12、13、14 与 IC-148 断言 2／3 的每一个命中数逐条重算，并与期望值比对——三轮（子项 B／C／D 各一轮）共 100+ 条，**全部吻合**，无一条留到 CI 才发现。断言 3 里「视图体裸数」一条据此改扫**剔注释后**的视图体：带注释扫会把「规格第 12 条」里的 `12` 当成裸数（raw 切片实测字面量集 `{0, 1, 2, 12}`，剔注释后为 `{0, 1, 2}`）。

---

## 十、发现但未处理的问题（按纪律只报告不修）

1. **`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 的 runner 抖动**（本卡外）。attempt 1 在 `S2CalibrationHarnessTests.swift:4146`（`中间帧门禁：通过`）与 `:4151`（进入 Nx 中间帧计数 2 < 3）判红，attempt 2 同提交全绿。唯一有效落点在产品侧 `S2GeometryDiagnosticsRun`（把「中间帧不足」从 `errors` 降级，或按 runner 实测分布下调 `minimumMiddleFrames`），落在本卡**不得触碰**的 `S2NativePhotoPager.swift`。已排进「诊断路径卡」（CLAUDE.md 第 174 条「中间帧门禁阈值，实测机制是进度分布而非回调次数」）。**本卡未动一行。**
2. **`PhotoCleanupMVE/Features/S0/S0View.swift` 的 `import UIKit` 现已无使用者**。它原本只为 `S0AmbientImageProviding` 的 `UIImage` 与 `S0GlassSurface.ambientImage` 而在；两者随本卡删除后，全文件再无 UIKit 专属符号（`CGFloat` 由 CoreGraphics 经 SwiftUI 转出）。未处理——卡内枚举的 S1～S11 不含 import 行，Swift 对未用 import 也不告警。
3. **`PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift` 的 `private func waitUntil(...)` 现已无调用者**。它只被删掉的那条回落测试用过。未处理——卡内白名单只列了五条断言与 `S2AmbientLoaderStub`；Swift 对未用的 private 方法不告警。
4. **「tab bar 压住最后一行」本卡未修**，按卡要求只判不修，留 H73 第 1 条单独记。子项 A 的假设不覆盖它：它可能是最后一张卡的磨砂副本向下溢出造成的错觉，也可能是 `ScrollView` 底部内边距的独立问题；删掉磨砂层之后若仍压，须另立项。
5. **`S2AmbientMetrics` 的 `S2` 前缀名实不符**（S0 也在用）——范围外，纯重构卡另开。本卡沿用 IC-148 裁定 丙，未搬家、未改名。
6. **玻璃卡「磨砂」的含义变了**，见第十一节前言。这是固定色方案的固有代价，不是缺陷。

---

## 十一、人工判定项（H73，留给 Lynn 真机，执行端不代为下结论）

**前言（按卡要求原样抄录子项 D 的观感事实，①）**：

> 底变纯色后玻璃卡后面**没有可折射的对象**，卡退化成「半透明面板 + 高光边 + 描边」；「磨砂」的含义从「隔着毛玻璃看到后面有东西」变成「有纹理的漆面」。**这不是缺陷，是固定色方案的固有代价，H73 判定时不得按缺陷记。**

装**合并后 `main`** 的产物。六条：

1. **S0 版式（H71 重判）**：「空间清理」页三张玻璃卡**竖排、互不重叠**，hero 大字、「照片库共 X GB」、分段条与图例、等待清空行、类别行各自完整可读；**tab bar 是否仍压住最后一行单独记**（本卡未修它）。
2. **S0 氛围底**：底是恒定的深绿，卡片区中上部有一层极淡的绿色光晕，有颗粒；切换系统深浅外观页面**不变**；不再有自己的照片在底下。
3. **玻璃卡观感**：卡是半透明面板 + 高光边 + 描边，能看出光晕透过卡面；**判层次是否分得开，不按「没有磨砂」记缺陷**。
4. **S2 主图外区域**：上下两条带是固定深绿，翻页**不再变色、不闪**；`V=隐藏` 时照常是深绿而不是纯黑。
5. **类别色在绿底上**：五个色点与分段条各段能分辨，尤其「相似照片」那支绿（`#3FD1B0`）与底色不混（第 175 条已知代价，判可接受与否）。
6. **回归**：H71 原第 3～6 条（四态、类别行排序与灰显、两处已知「空着」、切 tab 回归）各快过一遍；H72 六项本卡不碰、不必重测。

---

## 十二、合并与 G866

### 12.1 合并

G865 全部满足，按卡内授权执行 `--no-ff` 合并并推送。**本机权限分类器未拦截**，一次通过，未做任何命令改写。

| 项 | 值 |
|---|---|
| 合并前 `main` | `1fd6ed0525fde06ce710da4daa2f383d75d2d818` |
| 被合并分支 tip | `11e2c2b0cccca4aacb21bb00593f5a339ad9c1fe`（代码 tip `35f4e29476d3cec60df40a19e3a2bcdd2aef0ab2` + 报告提交） |
| 合并方式 | `git merge --no-ff feature/ic-151-ambient-fixed-color-and-s0-layout` |
| **合并提交** | **`f319a22471fa73cb742159bdd5ab177c7ee3a8e5`** |
| 合并后 `main` | 同上，已推送 `1fd6ed0..f319a22 main -> main` |
| 合并统计 | 12 个文件，+1537 / −560；删 1 个文件、新增 3 个文件 |

### 12.2 G866：合并后 `main` 的自动运行

| 项 | 值 |
|---|---|
| 运行编号 | **#303** |
| run id | `35069638579`，`run_attempt` **1** |
| check-run id | `104707843037`（现取，未沿用上一次） |
| 被测提交 | `f319a22471fa73cb742159bdd5ab177c7ee3a8e5` |
| 结论 | **success**，11 个步骤全 success |
| 真实退出码 | **0** |
| 执行摘要 notice | `Executed 805 tests, 0 failing test case(s), across 1 launch(es)` |
| xcodebuild 摘要 | `Executed 805 tests, with 0 failures (0 unexpected)` |
| 唯一用例身份去重计数 | **805** ✔；日志内 `' failed (` 命中 **0** |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 机型钉死实证 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1555514，SHA-256=6980f56b1d68c836bc63f6281a8438c1411185d515a089c0006ce1798b0d2e52` |

**关于两次 IPA 的 SHA-256 不同**：#302 attempt 2 为 `3db9d8f1…f48ba`、#303 为 `6980f56b…2e52`，而**字节数完全相同（1555514）**。这是既有结论（IC-094／IC-097：IPA 归档不可复现，相同源码树给出相同字节数但不同 SHA-256），不是内容差异；跨运行的同一性判据用树 diff 不用 IPA 哈希。

**G866 满足。**

### 12.3 合并后的 `main` 与人工判定

H73 六条（第十一节）应装**合并后 `main`**（`f319a22`）的产物——即 #303 的 artifact `PhotoCleanupMVE-unsigned`。

---

## 十三、报告内 40 位 SHA 的实读核验

陷阱 15：报告内每个 40 位 SHA 必须来自实读命令的输出，不得凭短前缀补全。
核验命令：`grep -ohE '\b[0-9a-f]{40}\b' Reports/IC-151/*.md | sort -u`，逐个 `git cat-file -e <sha>^{commit}`。

| SHA | 存在 | 提交标题（首行截断） |
|---|---|---|
| `0659e3ac0aab1c322cb1c2db077ff84c12c46b9a` | ✔ | `feat(IC-151 B): 氛围底改固定色——12 个 v2 登记值…` |
| `11e2c2b0cccca4aacb21bb00593f5a339ad9c1fe` | ✔ | `docs(IC-151): 自验报告与变更清单` |
| `1fd6ed0525fde06ce710da4daa2f383d75d2d818` | ✔ | `docs(IC-150): 回填合并提交与 G861…` |
| `35f4e29476d3cec60df40a19e3a2bcdd2aef0ab2` | ✔ | `feat(IC-151 D): S0 侧删图源链、玻璃卡改半透明填充…` |
| `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | ✔ | `probe: IC-125 负对照——test-xcode.sh 在 xcodebuild test…` |
| `486bcb769b59eb1146c5a231c7998847206777cc` | ✔ | `probe: IC-137 媒体播放探针…` |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | ✔ | `docs: 完成 IC-091 阶段一…` |
| `8a3f6572e7cc5cce07bee440588c478fd549299f` | ✔ | `test(IC-151 A): H71 版式塌陷的归因——无框 scaledToFill…` |
| `9db02b93eccbb87d126602901807e70823535111` | ✔ | `test: 等待首个真实捏合完整结束` |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | ✔ | `docs: IC-092 自验报告与变更清单 v2 完整替换…` |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | ✔ | `docs: 完成 IC-089（IC-082 v3 R4）贴边回弹与交接…` |
| `b5474fa759e52eb07dcbf7e510b7c1b56be5a150` | ✔ | `feat(IC-151 C): S2 侧删取图链、氛围底视图改无参` |
| `d373afc7125104c01acfc296829229090e6871ce` | ✔ | `docs(IC-145): 自验报告与变更清单（#288 一次绿…）` |
| `f319a22471fa73cb742159bdd5ab177c7ee3a8e5` | ✔ | `Merge IC-151：氛围底改固定色（S2 与 S0 两处）…` |

**14 个 40 位 SHA 全部 `git cat-file -e` 通过。** 其中七个冻结／探针链的 SHA 另由 `git ls-remote origin` 的输出实读取得（第七节 G863 表），本机对象与远端 tip 一致。

报告内出现的 64 位十六进制串是 **SHA-256**（文件哈希与 IPA 哈希），不是 git 对象，不在本节核验范围。

---

## 十四、本次回填方式说明（纪律 7）

代码四个提交与两份报告已随分支一起推送（`11e2c2b`），随后合并入 `main`。第十二、十三节引用的**合并提交 SHA** 与**合并后 `main` 的运行编号**是推送后才产生的信息，按纪律 7 允许在**同一张卡**内追加一个 docs 提交回填——本次回填直接落在 `main` 上（与 IC-150 的 `1fd6ed0` 同一做法），**不等下一张卡分叉之后再补**。
