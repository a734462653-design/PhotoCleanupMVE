# IC-092 自验报告（nx-window-follow，阶段一）

## 结论（先行）

R1（跟随写入器 + y 抑制 + 让位保险）、R2（结算）、R3（探针扩展）已实装，各自独立提交，另有一个测试修正提交。分支 `feature/ic-092-nx-window-follow` 自 `feature/ic-091-nx-midgesture-handoff` = `6736f1e` 切出，最终被测 `c6708d0d7b2df9a244c56f9755a4718f76716df7`。

**CI 结果：CI #160 success。** 被测 `c6708d0d7b2df9a244c56f9755a4718f76716df7`，XCTest **491 项、0 失败**（= 485 + 6 − 0），9 步全 success，真实退出码 `test_status=0`；IPA 785358 字节、SHA-256 `626d3cbd…2833`，本地重下复核一致。**CI 用了 2 次，正好是卡内给阶段一的上限（2/2，未超）。**

**阶段一到此停下，等 Lynn 的场景 E 三段真机录制。** 本卡把 IC-091 的路线整个换掉：不再指望 UIKit 交接，改由 App 在交接窗口内自己写外层偏移。夹具能验证的是**映射、钳制、抑制、结算判定、收口与守卫**；**跟手观感、回弹曲线、相邻页露出、无闪烁全部零覆盖**，只能由 H38 判。

闸门 A、B、D 未触发；C'、E 的真机判据未取到（夹具层面 E 已满足）。

## 实装路线与依据

IC-091 的 H37 三段录制（①）把两条候选手段一起否掉了：

- **M1（方向锁 + 等 UIKit 交接）否**：`091-a` 里方向锁确实生效（y 恒 574.3），但 x 到边（t=1.076，`nxHandoffPoint` 正常产生）之后 y 立刻以约 1 px/帧爬动到 586.0（0.8 s）——UIKit 在锁定轴被边界耗尽后**把位移改道给自由轴**，而不是交给外层。交接点后 0.8 s 外层 `isTracking` / `isDragging` 均未变真、偏移恒 0，闸门 C 判据成立。
- **M2（取消内层 pan 让外层接）否**：`091-a` t=0.937 外层 `pagingIsTracking=true`（触摸落下）→ t=0.966 内层 pan 开始，外层立刻变 false 且整个手势不再变真。**外层已无触摸可接**，取消内层 pan 也没有接手方。

所以本卡的写法是唯一剩下的：窗口内 App 自己把内层 pan 的横向增量映射到外层偏移。E1 时代「自定义投影写外层偏移会闪烁」的旧账归因于**双写者并存**；本方案是单写者——`apply` / `layoutNativePages` 已被 IC-091 R3 守卫排除，外层原生拖动经①证明不会出现，另有让位保险兜底。

IC-091 的方向锁按卡内第二节 2 保留：它管的是**到边之前**别让内层把位移吃到竖向去；到边之后的竖向爬动由本卡的 y 抑制接手。

## 跟随写入的单一入口

**`S2NativePagerViewController.followNxHandoffWindow(on:translation:)`**（`PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`）。

交接窗口内**所有**几何写入都在这一个方法里，且两次写入在同一个 `CATransaction`（`setDisableActions(true)`）提交边界内：

1. 外层偏移 —— 经既有 `writePagingContentOffset(_:animated:source:)`，`animated: false`，来源 `S2NativePagerViewController.nxWindowFollow`。
2. 内层竖向回写 —— `inner.setContentOffset(…, animated: false)`，仅当 `|y − 交接点 y| ≥ 1 pt`。

各自记录事件（`nxWindowFollow` / `nxWindowVerticalSuppression`），都带来源、页索引、资产标识（陷阱 4）。守卫顺序：窗口开 → 跟随未让位 → 是窗口页 → 外层未自行拖动；任一不满足即原样返回、一个字节不写。

**驱动源是内层 `panGestureRecognizer` 的 `.changed` 回调**（`S2NativeZoomPageController.handleInnerPanForHandoff`），不是 `scrollViewDidScroll`。理由是①：内层到边后不再滚动，`didScroll` 在交接点之后立刻断流，用它当驱动一帧都写不出来。

## 结算规则数值

| 量 | 取值 |
|---|---|
| 步距 | `pagingScrollView.pageStride` = 页宽 + 页间距 |
| 进度 p | `\|外层偏移 − 静止偏移\| / 步距` |
| 速度 v | 内层 pan `velocity(in:).x`，按翻页方向取正（翻下一张时手指左移，取 `-velocity.x`） |
| 翻页判据 | `p > 0.5` **或** `v ≥ edgePagingTriggerVelocity`；否则弹回 |
| `edgePagingTriggerVelocity` | 出厂 **300 pt/s**（未改），本卡由 `unwired` 复接线为 `effective` |
| 进度阈值 | `0.5`，**严格大于**才翻页 |
| 竖向死区 | `1 pt` |
| 跟随钳制 | `[静止偏移 − 步距, 静止偏移 + 步距]` |
| 目标索引 | `currentIndex + direction.indexOffset`，钳在 `orderedAssetIDs.indices` 内；越界即退化为弹回 |

边界严格：`(0.5, 299)` 弹回、`(0.5, 300)` 翻页、`(0.6, 0)` 翻页、`(0.4, 350)` 翻页、`(0.4, 200)` 弹回。翻页走既有 `finishNativePaging → handleNativePageChange`：新页 `s=1`、旧页复位、`V` 不变。回写沿用 `synchronizeNativeStateToMachine(animatedPaging: true)` 那条路径（同曲线同时长）。

## 一处卡内没写、但结果要求逼出来的实现决定

**结算动画期间交接窗口必须保持打开。**

卡内第二节 4 写「窗口由结算完成关闭」。如果把「结算完成」理解成「结算判定做完的那一刻」，动画就活不下来：`handleNativePageChange` 一发布，SwiftUI 在一两帧内重进 `apply()`，此时 R3 守卫已放行（窗口已关、外层 `isTracking/isDragging/isDecelerating` 全假），`apply` 就用一次**非动画**写入把外层偏移直接写到同一个目标——结果是瞬移，弹回曲线与翻页曲线都消失，H38(a) 的「与系统并排观感一致（回弹曲线）」直接落空。

因此本卡把「结算完成」理解为**动画结束**：判定完成后停止跟随（`isNxWindowFollowActive = false`）但**窗口不关**，R3 守卫继续挡住 `apply`；窗口在新增的外层 `scrollViewDidEndScrollingAnimation` 里以 `reason=结算完成` 关闭，随后 `apply` 恢复写入，下一次写的就是静止偏移。这既满足卡内原文（窗口确实由结算完成关闭、原因是新增的那个），也满足「`apply` 恢复写入后一次即回到静止偏移语义」。

配套的一个坑：`setContentOffset(animated:)` 在**零位移**时未必回调 `scrollViewDidEndScrollingAnimation`，那样窗口会永远关不掉、`apply` 再也写不了外层偏移。故结算时先判 `|当前偏移 − 目标偏移| > 0.5`，不需要动画就当场关窗、走非动画分支。

若技术负责人认为「结算完成」应取判定完成那一刻，请明示，阶段二改。

## 又一处被实测推翻的假设（①，CI #159）

**`UIScrollView` 把 `contentOffset` 吸附到设备像素网格。** CI #159 的两条失败都在 B3，报错原文
`XCTAssertEqualWithAccuracy failed: ("300.6666666666667") is not equal to ("300.5")`：写入 `baseY + 0.5`（`baseY = 300.0`）读回来是 `300.666667`——CI 模拟器 `scale = 3`，偏移被吸附到 1/3 pt 的整数倍，`300.5` 落在 `300.333333` 与 `300.666667` 正中间、向上取。写入 `baseY + 3.5` 同理读回 `+3.666667`，于是事件 details 里的 `deviation=` 也不是 `3.500000`。

原断言假设「写入的 `contentOffset` 会被原样保留」，两处都因此不成立。处置（`c6708d0`，只改测试，产品零改动）：偏差一律取**读回值**再判——死区内先断言读回偏差 < 1 pt 作为前置、再断言 follow 前后 y 不变；死区外先断言读回偏差 ≥ 1 pt、再断言回写到交接点 y，事件 details 的 `deviation=` 用读回值格式化后比对。

**产品行为不受影响**：死区判据本身读的就是运行时的 `inner.contentOffset.y`，本来就是读回值。真机 `scale = 3` 下，1 pt 死区的有效粒度是 1/3 pt——这一点写进 H38(e) 的观察范围：若录制里 y 以 1/3 pt 的台阶持续爬动而每帧偏差始终不到 1 pt，抑制就压不住，阈值需要重定。

这条与 IC-091 那条（`bounces = false` 不钳制程序写入的越界偏移）是同一类：**`UIScrollView` 的 `contentOffset` 写入语义与直觉不符，夹具里凡是「写进去再读出来」的断言都要按读回值写。**

## 输入、继承与范围

- 任务卡 `IC-20260824-092-nx-window-follow`；上游证据 IC-091 阶段一交付（CI #158，485/0）与 H37 三段录制 `091-a/b/c.txt` 的逐帧分析（技术负责人，①）、Decision_log 第 125 条、Lynn Q1 定案。
- 开工前 `git status --porcelain` 为空；HEAD 在 `feature/ic-091-nx-midgesture-handoff`@`6736f1e`，按下发语从该提交切新分支。
- 范围边界：只改 `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift`、`PhotoCleanupMVE/Features/S2/S2Calibration.swift`（登记表一行 + 三行注释）、`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`、`Reports/IC-068/export-format.md`。`S2StateMachine.swift`、`S2View.swift`、`Localizable.xcstrings`、`Scripts/`、`ci.yml`、SPEC、Decision_log 一个未动。未新增 XCUITest，未合并主干，未 force push，未改写历史，未动 `feature/ic-089-*` / `feature/ic-091-*` 分支本体。

## 提交清单

| 提交 | 归属 | 内容 |
|---|---|---|
| `9ed826d` | R3 | 纯类型与规则、三个记录入口、两个关闭原因、`export-format.md` 追加一节。**194 增 0 删，不接线，零行为变化** |
| `e9dfbd9` | R1 | 跟随基准状态、唯一写入口、竖向抑制、让位保险、页控制器 `.changed` 驱动 |
| `4fc2522` | R2 | 松手结算、结算动画期间的窗口守护、`finishNativePaging` 参数化、外层 `scrollViewDidEndScrollingAnimation`、登记表复接线、B1～B7 断言 |
| `c6708d0` | 测试修正 | B3 的竖向偏差判据改用 `contentOffset` 读回值（CI #159 暴露），**产品代码零改动** |

依赖方向单向（R1 调 R3 的记录入口，R2 复用 R1 的窗口状态），每个提交自身可编译是③（源码推断；本机无 Xcode，只有 tip 经 CI 实测）。三个提交由「先取最终态快照 → 回到 `6736f1e` → 分三步重建 → 逐字节比对回最终态」的方式产出，最终树与本地门禁跑过的那一份**逐字节相同**（`cmp` 四个文件全 OK）。

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G193** B1～B7 + R3 事件断言 + `export-format.md` 只增不删 | 满足① | 见下表。`git diff 6736f1e..HEAD -- Reports/IC-068/export-format.md` = **22 增 0 删** |
| **G194** IC-063～IC-091 既有门禁 + 本地三项 | 满足① | CI 内既有测试全过（含 IC-091 A1～A6 与 IC-082 G154、IC-079 G141）。本地：`Scripts/selfcheck.ps1` 退出码 **0**；`Scripts/scan-hardcoded-user-visible-strings.ps1` 退出码 **0**（目录 171 / 引用 171、残留 0）；`git diff --check` 退出码 **0** |
| **G195** CI success / 计数算式 / IPA 校验 | 满足① | 计数算式：**485 + 6 − 0 = 491** |
| **G196** 阶段二逐帧表 | 未开始 | 需 Lynn 三段录制 |

### B1～B7

| 断言 | 结果 | 测试函数与要点 |
|---|---|---|
| **B1** 结算决策纯函数 + ±1 页钳制 | 满足① | `testIC092B1SettlementRuleAndClamp`：卡内四例 `(0.4,200)`→弹回、`(0.4,350)`→翻页、`(0.6,0)`→翻页、`(0.5,299)`→弹回；补两条边界 `(0.5,300)`→翻页、`(0.5,0)`→弹回；`progress` / `directionalVelocity` / `triggerVelocity` 读数逐项核对；方向取反对称（四例在 `.previous` 上结论相同、方向速度相等）；无位移时 `direction == nil`、速度再大也不翻页；钳制：`raw 680 → 600`、`raw 280 → 400`、区间内不改写且 `clampedToLimit == false` |
| **B2** 窗口内跟随映射 + apply 不写 + 关窗后不映射 | 满足① | `testIC092B2WindowFollowMapsAndClampsOuterOffset`：相对交接点左移 60 pt → 外层 `+60`；右移 40 pt → 外层 `−40`；超一页 → 钳到 `静止偏移 + 步距` 且 `clampedToLimit == true`；`nxWindowFollow` details 前缀 `translationDeltaX=-60.000000；`、含 `clamped=false；`；跟随写入以来源 `…nxWindowFollow` 记进 `外层setContentOffset`（计 1）；窗口开时 `apply` 的 `apply` / `layoutNativePages` 两来源写入增量 **0** 且跟随位置未被抹掉；关窗后 `followNxHandoffWindow` 返回 false、外层偏移不变 |
| **B3** 竖向抑制死区 | 满足①（判据经 CI #159 修正，见下节） | `testIC092B3WindowSuppressesVerticalDrift`：写入 `baseY + 0.5`、**读回**偏差断言 < 1 pt → follow 前后 y 不变、无抑制事件；写入 `baseY + 3.5`、读回偏差断言 ≥ 1 pt → 回写到交接点 y、事件计 1 且 details 的 `deviation=` 与读回值逐位相符、含 `deadband=1.000000；`；提交边界事件存在；关窗后偏差 20 pt → 不回写、事件计数不变 |
| **B4** 结算两条路径 | 满足① | `testIC092B4SettlementPagesOrSnapsBack`。翻页（p=0.6、v=0）：`currentIndex+1`、`machine.scale==1`、新页 `zoomScale==1`、旧页复位、`外层setContentOffset` 含 `x=<新页静止偏移>；animated=true；`、结算中 `isNxWindowSettling==true` 且窗口仍开、`isNxWindowFollowActive==false`、驱动收口回调后窗口以 `reason=结算完成` 关闭（计 1）、所有页的照片层与描边层 `animationKeys()` 均空（陷阱 8）、跑完 runloop 后外层落在新页静止偏移。弹回（p=0.3、v=0）：`currentIndex` 不变、`machine.scale==2`、动画写回目标是静止偏移、收口后窗口关闭、外层回静止偏移 |
| **B5** 让位保险 | 满足① | `testIC092B5NativeTakeoverStopsFollow`：外层 `scrollViewWillBeginDragging` 到来 → 窗口关闭、`isNxWindowFollowActive==false`、关闭原因 `原生接管` 计 1；此后 `followNxHandoffWindow` 返回 false 且外层偏移不变 |
| **B6** IC-091 A1～A6 与既有门禁保持 | 满足① | **不新增断言**：由 `testIC091G186A1…～A6…`、`testIC091G185…`、IC-063～IC-090 全部既有测试继续通过来覆盖。CI 全量绿即成立 |
| **B7** 登记表 | 满足① | `testIC092B7EdgePagingVelocityIsWiredAgain`：`edgePagingTriggerVelocity` = decided/**effective**、`edgePagingTriggerDistance` = decided/unwired；出厂值 300 / 40 与 `schemaVersion == 3` 未动；并用「把阈值从 300 抬到 900，同一读数由翻页变弹回」证明阈值确实被结算读到，不是空登记 |

**以上全部标注「夹具驱动，真机未覆盖」。** 夹具用 `noteInnerHandoffIfNeeded(on:dragVector:isDragActive:)`、`followNxHandoffWindow(on:translation:)`、`settleNxHandoffWindow(on:panVelocity:)`、`scrollViewDidEndScrollingAnimation(_:)` 四个以参数驱动的入口替代真实手势序列——CLAUDE.md 陷阱 1 点名的那类断言，由 H38 兜底。

## 闸门

| 闸门 | 状态 | 说明 |
|---|---|---|
| A 须改捏合接管 / 双击、显隐过渡 / `bounds.didSet` / 页窗口 | **未触发** | 四处一行未改。捏合接管、双击过渡、`bounds.didSet` 与 `applyJointCentering`、`retainedPageRadius` 与页窗口逻辑全部原样 |
| B 既有几何门禁失败 | **未触发** | CI #160 里 IC-063～IC-091 的既有几何门禁 0 失败（491 项 0 失败，全量通过）。CI #159 的两条失败都是本卡自己新增的 B3 断言，不是既有门禁 |
| C' 真机窗口内出现第二写者 | **未判定** | 判据在真机录制里。夹具层面 B2 已断言窗口内 `apply` / `layoutNativePages` 两来源写入增量为 0；真机看两条 `nxHandoffWindow` 之间的 `外层setContentOffset` 来源是否全是 `…nxWindowFollow`。让位保险已实装并由 B5 覆盖 |
| D 须新增标定参数 / 改出厂值或 `schemaVersion` | **未触发** | `factoryPlaceholder` 与 `schemaVersion` 的 `git diff` 为空；复接线不算（卡内明示） |
| E 结算后残留动画组或窗口未关 | **夹具层面未触发；真机未判定** | B4 断言收口后照片层与描边层 `animationKeys()` 均空、窗口以 `结算完成` 关闭。本卡的结算路径不创建任何 `isRemovedOnCompletion = false` 的动画组（不走双击 / 显隐过渡），故未加清除代码——真机若出现残留，说明有别的动画组与结算并存，阶段二再处理 |

## CI 与本地门禁

| 项 | 值 |
|---|---|
| 运行编号 | **CI #160**（id `32755493190`），工作流「iOS 构建与自验」 |
| 结论 | **success**，9 步全部 success |
| 被测提交（完整 SHA） | `c6708d0d7b2df9a244c56f9755a4718f76716df7` |
| XCTest 项数 / 失败数 | `Executed 491 tests, with 0 failures (0 unexpected) in 54.296 (75.538) seconds`；`** TEST SUCCEEDED **` |
| 真实退出码 | `test_status=0`；工作流以 `set -o pipefail` 采集并 `exit "$test_status"` 原样退出 |
| IPA 字节数 | **785358** |
| IPA SHA-256 | `626d3cbdb5de8223ffcedbfb95025dbdb2925f16647d268bff26870ba09b2833`（CI 报告值） |
| IPA 本地复核 | artifact `PhotoCleanupMVE-unsigned-c6708d0d7b2d` 下载解出 785358 字节，本地 `sha256sum` 与 CI 报告值**一致** |

前一次 **CI #159**（id `32754380565`，被测 `4fc2522`）：failure，`Executed 491 tests, with 1 failure` ×2 条错误行、合计 `with 2 failures`，`构建未签名应用` 与 `上传 IPA` 两步 skipped。两条失败都在 `testIC092B3WindowSuppressesVerticalDrift`，同一根因（见下节）。**该轮里 IC-091 的 8 个测试与 IC-092 的 B1／B2／B4／B5／B7 全部通过**——B6 与结算全路径的结论在 #159 就已取到。

本地门禁（Windows，本机无 Xcode，无法执行 XCTest 或构建 IPA）：

| 门禁 | 真实退出码 |
|---|---|
| `Scripts/selfcheck.ps1` | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0**（目录 171 / 引用 171、用户可见硬编码残留 **0**） |
| `git diff --check` | **0** |

## 人工判定项（保留给 Lynn，本报告不代为下结论）

**H38**：装阶段一 CI 包（CI #160 的 artifact `PhotoCleanupMVE-unsigned-c6708d0d7b2d`），开场景 E 录三段，先开录再出手。

- (a) 中部起手拖到边继续拉 1/4 屏松手：下一张露出后弹回、不翻页、**与系统并排观感一致（跟手程度、回弹曲线）**。
- (b) 拉过半屏或快甩：翻页、新页 1x、无闪烁。
- (c) 贴边起手斜滑：不退化。
- (d) 竖向主导拖动、上滑 / 下滑、1x、捏合、双击无回归。
- (e) 窗口期间照片无竖向爬动。

三段导出发技术负责人。**(a)～(e) 全部未由本卡验证。**

## 真机未覆盖项清单

1. **跟手程度与 1:1 映射的观感**——夹具只验证了数学映射，手指与画面的实际同步感零覆盖。H38(a)。
2. **相邻页是否真的露出**——依赖 `ensurePagesExistAroundPagingOffset` 在跟随写入引发的外层 `scrollViewDidScroll` 里按需建页。夹具没有渲染判据。H38(a)(b)。
3. **回弹 / 翻页动画曲线与时长**——走 `synchronizeNativeStateToMachine(animatedPaging: true)`，曲线由 UIKit 定，与系统的并排对比只能人工判。H38(a)(b)。
4. **结算动画是否真被窗口守住**（本报告「一处实现决定」那节）——夹具无法产生 SwiftUI 的 `apply` 重进时序。判据：录制里两条 `nxHandoffWindow` 之间有无来源 `apply` 的 `外层setContentOffset`。
5. **竖向爬动是否被抑制干净**——① 说 UIKit 会以约 1 px/帧改道到自由轴，死区 1 pt 是否恰好压住、会不会出现 0.9 px/帧的持续漂移，只能看录制里 `contentOffset.y` 的逐帧值。H38(e)。
6. **让位保险在真机是否触发**（闸门 C'）——① 预期不触发；若 `nxHandoffWindow` 出现 `reason=原生接管`，说明①的前提在某些手势下不成立。
7. **翻页后无闪烁**——H38(b)。本卡未碰图像请求与替换路径。
8. **贴边起手、竖向主导、1x、捏合、双击无回归**——H38(c)(d)。
9. **结算后无残留动画组**（闸门 E 真机侧）。

## 发现但未处理的问题（按纪律只报告不修）

1. **序列边界上的 ±1 页钳制会露出空背景。** 卡内第二节 1 把钳制写死为「静止偏移 ± 一页步距」，不区分相邻页是否存在。在第 0 张往回拉、或最后一张往前拉时，外层偏移会走到内容范围之外，露出背景而不是相邻页。外层 `bounces` 默认为真，原生分页在边界也会橡皮筋越界，但那是**阻尼**的，本卡的跟随是 1:1。结算会退化为弹回（目标索引钳在序列内），所以不会翻到不存在的页。按卡内原文实现，未加额外的内容边界钳制。
2. **`lastOuterTranslation` 不由跟随路径更新。** 结算走 `finishNativePaging` 时若目标等于当前页，会调 `reportSequenceBoundaryAttemptIfNeeded()`，而它读的是外层手势读数 `lastOuterTranslation`——交接窗口全程外层没拖动过，该值是上一次外层手势的残留或 `.zero`。实测后果是它几乎总在 `guard` 处提前返回，不产生 `handleHorizontalSwipe` 事件，**不影响结算结论**；但「序列边界尝试」在交接窗口这条路径上事实上不上报。IC-091 已有同一问题，卡未要求，未处理。
3. **交接窗口内 `layoutNativePages` 仍可能对内层写 `applyNativeState`**（IC-091 已报告的第 3 条）。现在多了一层：它写的是 `machine.viewportOffset`，而本卡的 y 抑制写的是「交接点 y」。两者在 `reportNativeViewport` 每帧同步下取值相同，`applyNativeState` 的 ε 比较会跳过实际写入，当前不产生冲突；但这是窗口内第二条**内层**写入路径。卡只约束外层偏移的写者数量，故未处理。真机若出现接管期间照片跳动，先查这里。
4. **方向锁现在部分冗余。** 卡内第二节 2 要求保留 M1 的手势级方向锁。它在**到边之前**仍有用（不让内层把位移吃到竖向），到边之后的竖向由本卡的 y 抑制接管。两者叠加不冲突，但真机若显示到边前也有竖向漂移，说明方向锁在真机上并未被 UIKit 采纳（IC-091 未覆盖项第 2 条仍未结）。
5. **硬编码字符串扫描脚本的豁免仍是按文件位置的**（IC-091 已报告）。本卡新增的两个关闭原因取值（`结算完成` / `原生接管`）落在 `S2NxHandoffWindowReason` 内，位置在 `final class S2GeometryDiagnosticsRun` 之后的豁免区内，因此通过。`Scripts/` 在范围外，未修改。
6. **`gestureRecognizerShouldBegin` 在真机上不被调用**（①，卡内第一节 3 与 IC-089 两段录制一致）。本卡的跟随与结算完全不依赖它——驱动源是 `.changed` / `.ended` 回调，一定会到。IC-091 的方向锁仍挂在 `.began` 上，不受影响。
7. **B4 里「动画落到目标偏移」这一条依赖 UIKit 在测试宿主里真的执行 `setContentOffset(animated:)` 动画。** 断言用了 1 pt 容差并跑了 0.8 s runloop。CI #159 与 #160 两轮 B4 均通过——**动画在宿主里确实执行**（①）。其余判据（索引、倍率、事件、窗口状态、动画组）都是同步且确定的，不依赖它。
8. **`UIScrollView` 的 `contentOffset` 吸附到设备像素网格**（本报告「又一处被实测推翻的假设」）。已升为①并写进 B3 的判据。它同时意味着：真机 `scale = 3` 下竖向死区 1 pt 的有效粒度是 1/3 pt，H38(e) 要留意「每帧偏差不到 1 pt 但持续同向累积」的形态——那样抑制不会触发。若录制里出现这种爬动，死区阈值需要重定（④，需 Lynn / 技术负责人定）。
