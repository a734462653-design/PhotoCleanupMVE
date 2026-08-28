# IC-108 自验报告：跟随者立即逐张跟随（A）+ 双击丝滑度诊断探针（B）

## 结论（先行）

**A、B 两个子项全部交付，各自 CI 绿。Lynn 的 H46 包 = CI #193。**

- **最终绿 tip**①：`f450566f5d1d79b49e74de664031357dea1843ad`
- **最终 CI**①：**#193 success**，9/9 步全绿，**真实退出码 0**，`Executed 525 tests, with 0 failures (0 unexpected) in 23.031 (25.415) seconds`
- **IPA**①：**854930 字节**，SHA-256 **`3555045749d8979372830812ee37e70ed5e548d2bbe324f85fc242e7a3bc541c`**
- **闸门**：**G256、G257、G258、G259、G260 全部通过**
- **CI 预算**：A 2 次用 1 次（#191）；B 2 次用 2 次（#192 红、#193 绿）
- **时间闸门**：开工 2026-08-28T17:55:37Z，到期 23:55:37Z，**完成于 19:21:28Z，未到期**
- **`main` 全程未被触碰**（停在 `e08f7de`）；`schemaVersion == 6`；冻结三链未动；`export-format.md` 未动

## 输入与边界

| 项 | 值 |
|---|---|
| 开工 `git status --porcelain` | 空（纪律 8 检查通过） |
| 开工时 `main` | `e08f7de665d51cfdb5be029865a691c7c4152c6b`（与卡内规定值相符 ✓） |
| 分支 | `feature/ic-108-follow-and-zoom-probe`，**自 `main` 切出**，全程未合并 |
| 规格基线 | `SPEC-S2-20260829_v17.md`，实测 SHA-256 与 CLAUDE.md 基线行**吻合**① |

## 子项 A：跟随者立即逐张跟随

### 一、勘查结论（G257）：③假设的**结论方向成立，机制措辞需更正**

③ 原文：「跟随者（缩略栏 `isCurrent`、顶部信息）疑似挂在 settled 侧或等价的停稳时机」。

实测①：

| 项 | 实测 |
|---|---|
| 底部横栏当前项 | `S2View.swift:2474` `isCurrent: machine.bottomStripState == .idle && index == machine.currentIndex`；布局亦用 `:2461` 的 `currentIndex` |
| 顶部日期/序号 | `S2View.swift:900` 的 `assetCreationDate(machine.currentAssetID)`、`:909` 的 `subtitleText(currentIndex: machine.currentIndex, ...)` |
| **两者的索引来源** | **都是 `machine.currentIndex`，都不挂在 `settledIndex` 上** |
| `settledIndex` 实际用途 | 仅 pager 内部：静止偏移判定（`:3127-3146`）与诊断导出字段 |
| `machine.currentIndex` 的原生翻页写入点 | `handleNativePageChange(to:)`（`S2StateMachine.swift:1232`） |
| 其唯一调用者 | `finishNativePaging()`（`S2NativePhotoPager.swift:3268`） |
| `finishNativePaging` 的调用时机 | 仅 `scrollViewDidEndDragging(_:willDecelerate:)`（且仅 `handledVerticalGesture \|\| !decelerate`）与 `scrollViewDidEndDecelerating(_:)` |
| 外层 `scrollViewDidScroll`（`:2643`） | 改前只做 `ensurePagesExistAroundPagingOffset()`，**不碰索引** |

**结论**：③ 的「**等价的停稳时机**」成立——跟随者确实只在停稳后才更新；但「挂在 settled 侧」不准确——**是 `currentIndex` 自身只在停稳时更新**。二者不构成矛盾，故未触发 G257 停线；但这一区分直接决定了实装位置：**改索引更新时机，而不是改跟随者**。

### 二、规格核对（卡内要求，v17）：未发现冲突条款①

| 规格位置 | 内容 | 与「立即逐张跟随」的关系 |
|---|---|---|
| 第 519 行 | 「左右滑主图：有目标相邻照片时**切换 `c`** 并留在 S2-1」 | 只规定切换本身，**未规定时机** → 不冲突 |
| 第 297 / 407 行 | 静止态横栏 = 当前张方形放大 + 左右矩形邻居 + 间隔 + 边缘渐隐 | 主图翻页期间横栏仍是静止态（滑动态只能由横栏拖动产生，见 509 / 513 / 521），视觉定义不变 → 不冲突 |
| 第 362 / 363 / 564 行 | 横栏定位项变化 → `c` 与主图同步；横栏停止后恢复静止态强调 | 属**横栏拖动 → 主图**的反方向，本卡未动 → 不冲突 |
| 第 210 行 | 任何前后翻页只改 `c`，切新照片后 `s` 必重置为 1 | 与既有 `resetZoomAfterPhotoChange()` 一致 → 不冲突 |

### 三、实装（产品侧仅 pager 一处语义）

`scrollViewDidScroll` 新增 `advanceCurrentIndexToPagingOffsetIfNeeded()`：每越过一页边界即调 `machine.handleNativePageChange(to:)`，两个跟随者随之逐张更新。

**约束逐条落实**：

| 卡内约束 | 落实 |
|---|---|
| 索引单一来源，不得新设副本 | 未新增任何索引副本；唯一新增状态是 `didAdvanceIndexDuringScroll`——**每手势一个布尔标志**，用于边界提示门控 |
| 不得引入静止态几何写入（陷阱 5） | 新方法**不写任何 `contentOffset`、不调 `synchronizeNativeStateToMachine`**（仍归停稳路径 `finishNativePaging`）。滑动期间 `pendingSettledPagingOffset()` 已由 `isTracking / isDragging / isDecelerating` 守住，`apply` 路径不回写偏移（IC-095 R2）。测试实测滑动期间非动画外层偏移写入增量为 **0** |
| 不得风暴化图像/取数请求 | 窗口策略（`ensurePagesExistAroundPagingOffset`）与 C2 会话缓存均未改；既有 `requestCount` 契约断言群零改动、CI 全绿 |

### 四、必须处理的连带：序列边界误报

`finishNativePaging` 原先在 `targetIndex == previousIndex` 时调 `reportSequenceBoundaryAttemptIfNeeded()`。索引更新前移后，**滑到最后一张时停稳处必然落入该分支**，而 `destination` 越界 ⟹ 误报「已是最后一张」轻提示（`pendingUndecidedItem = .item03`，经 `handleHorizontalSwipe` → `switchPhoto` 产生）。

改前该场景走的是 `handleNativePageChange` 分支，不会误报。已加门控：**仅当整个滑动序列自始至终未改变索引**才报，与改前语义逐条一致。

### 五、测试（+2，均标注「夹具驱动，真机未覆盖」）

| 测试 | 断言 |
|---|---|
| `testIC108AFollowersTrackEveryPageDuringFastPaging` | 一次拖动内连续越过 4 页，**停稳前**索引 `[1,2,3,4]`、资产标识、顶部序号（4 个互不相同）、横栏当前项判定式已逐张更新；停稳后不回退；`s` 重置为 1 |
| `testIC108ANoGeometryWriteAndNoSpuriousBoundaryHintDuringFastPaging` | 滑动期间非动画外层偏移写入增量 **0**；滑到最后一张停稳后 `pendingUndecidedItem` 为 **nil** |

**陷阱 1 标注**：真实手势时序、runloop 分帧与 SwiftUI 刷新未覆盖，由 **H46 第 1 项**兜底。

## 子项 B：双击丝滑度诊断探针（观测零行为改变）

### 一、模式与开关

照 IC-099b 探针：`S2DoubleTapSmoothnessProbeCoordinator`（`ObservableObject`）+ `S2DoubleTapProbeText`（报告文本）+ 标定面板只读区与 `ShareLink` 复制入口。

**开关为运行态**：不入 `S2CalibrationConfiguration`（`schemaVersion == 6` 不动）、不进 `export-format.md`、无持久化。

**关闭态零开销（双保险）**：
1. `S2View` 只在 `doubleTapProbe.isRecording` 为真时才把引用交给 pager，否则传 `nil`；pager 与页控制器持 `weak` 引用 ⟹ 所有埋点是**可选链空调用**。
2. coordinator 每个 `record...` 内部另有 `isRecording` 守卫。

### 二、必采字段逐条落实（陷阱 3）

| 卡内字段 | 落实处 |
|---|---|
| 方向（进/出） | `S2DoubleTapProbeEvent.enteringNx`，`startDoubleTapTransition` 埋点 |
| 目标倍率 | `targetScale`，同上 |
| 动画起止时间戳 | `startedAt` / `endedAt`（`startDoubleTapTransition` / `finishActiveDoubleTapTransition`），另导出 `durationSeconds` |
| CADisplayLink 帧间隔序列 | `frameTimestamps`（`advanceDoubleTapTransition` 逐帧追加）→ 派生 `totalFrameCount`、`droppedFrameCount`、`maximumFrameInterval`、`p95FrameInterval` |
| `imageRequestScale` 变化时刻 | `S2View` 的 `.onChange(of: machine.imageRequestScale)` → `recordImageRequestScaleChange` |
| 图像请求发起时刻 | `S2TemporaryPhotoImageView` 新增 `onImageRequestStarted`，在 `strategy.requestImage` 之前触发 |
| 图像请求完成时刻**与回调线程** | 新增 `onImageRequestRawResult`，**在 `DispatchQueue.main.async` 之前**调用 |
| 返回图像素尺寸 | 同上闭包第二参 `result.image?.size ?? .zero` |
| 资产标识与页索引 | `assetID` / `pageIndex`，取自页控制器的 `assetID` 与 `index` |
| `s` 起止值 | `startScale` / `endScale`，取 `zoomScrollView.zoomScale` |

**回调线程为什么必须在 `main.async` 之前取**：若在之后取，恒为主线程，测不出任何东西。而 ③ 候选正是「动画期间高分辨率解码占主线程」，该量是判定核心。

**丢帧口径**：间隔 > 标称帧间隔 × 1.5 计一次；标称值取 `CADisplayLink.duration`（缺失时按 60Hz 兜底）。**口径已写入报告头部**，Lynn 贴回的报告可自解释。

### 三、采样不阻塞主线程

采样期只对时间戳数组做 **O(1) 追加**，不排序、不格式化、不算统计量。四个统计量与报告文本全部推迟到 `stop()` 时计算。

### 四、G259 产品行为零变化

相对子项 A 绿 tip `51c14b5`，B 的产品侧**删除行仅 5 行**①：

```
-            targetSize: CGSize(          ← 4 行：内联表达式提为 let requestTargetSize
-                width: CGFloat(key.width),      （同值传递的纯重构）
-                height: CGFloat(key.height)
-            ),
-                                            .onImageReplacementSuppressed   ← 1 行：App 转发闭包末尾补逗号
```

其余全部是**新增观测代码**。双击、缩放、解码路径本身未改。

### 五、放置位置的一处硬约束

探针核心置于 `S2NativePhotoPager.swift` 末尾——`Scripts/scan-hardcoded-user-visible-strings.ps1` **只豁免该文件 `final class S2GeometryDiagnosticsRun` 之后的中文字面量**（`:113-131`），IC-099b 探针同此惯例。放在新文件会令报告文本被判为「用户可见硬编码残留」，三门禁之一直接失败。

面板四条文案走 xcstrings（**177 → 181** 条）；为避免附带改动，采用**纯文本插入**：44 行纯新增、零删除、零重排，JSON 合法性已校验。

### 六、测试（+3，均标注「夹具驱动，真机未覆盖」）

| 测试 | 断言 |
|---|---|
| `testIC108BProbeRecordsAllRequiredFieldsWhenRecording` | 必采字段逐条齐全；统计口径（4 帧、1 丢帧、最大 0.05s、p95 0.05s）；报告文本含表头、事件行、`imageRequestScale变化`、`回调线程=非主线程`、`返回像素=(w=1190.000000,h=892.000000)` |
| `testIC108BProbeRecordsNothingWhenDisabled` | 关闭态六类埋点全部零记录、`reportText` 为空、`canExport` 为假 |
| `testIC108BProbeCapturesDoubleTapThroughPager` | 经 pager 接线的真实双击过渡产生一条完整事件（含页索引、资产标识、`endedAt`、`endScale`）；**未接线时同一序列零记录** |

**陷阱 1 标注**：真实帧间隔、解码线程与 PhotoKit 回调未覆盖，由 **H46 第 3 项**兜底。

## 逐条闸门结果

| 闸门 | 判定 | 依据 |
|---|---|---|
| **G256** | **通过** | 开工工作树净；`main` = `e08f7de…2c6b`；分支自其切出 |
| **G257** | **通过（未触发停线）** | ③ 的「等价的停稳时机」成立；「挂在 settled 侧」不准确，已在报告中更正措辞并据此定位实装点。无矛盾 |
| **G258** | **通过** | A：#191 success、522/0、退出码 0；B：#193 success、525/0、退出码 0；最终绿 tip IPA 已登记 |
| **G259** | **通过** | B 段产品删除行仅 5 行（4 行同值重构 + 1 行补逗号），其余全为新增观测代码；关闭态双保险，测试实证零记录 |
| **G260** | **通过** | `schemaVersion == 6` 未动；冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` 引用未变；`Reports/IC-068/export-format.md` 零 diff |
| 时间闸门（6h） | **未到期** | 17:55:37Z 开工，19:21:28Z 完成，到期 23:55:37Z |

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 |
|---|---|---|---|
| A | **2** | 0 | 0 |
| B | **3** | 0 | 0 |

| 提交 | 本机测试函数数 | CI Executed |
|---|---|---|
| 继承（`e08f7de`） | 520 | — |
| `51c14b5`（A） | 522 | **522 / 0 失败**（#191） |
| `3aea742`（B 一轮） | 525 | 编译失败（#192） |
| **`f450566`（B 二轮）** | **525** | **525 / 0 失败**（#193） |

校验：520 + 5 − 0 = **525** ✓。**无静默删除**，无既有测试被改造。

## CI 记录

| run | id | 被测提交 | 子项 | 结论 | 退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|---|
| **#191** | `33198646075` | `51c14b5` | **A** | **success** | **0** | **522 / 0** | 838186 字节，`4f8bb4a97fa879b6253c202675ae644cee5bd45afc4bf1d2a3118d0cb1a8b323` |
| #192 | `33202113000` | `3aea742` | B | failure | 65 | 编译失败（步骤 6） | 无 |
| **#193** | **`33202731171`** | **`f450566`** | **B** | **success** | **0** | **525 / 0** | **854930 字节，`3555045749d8979372830812ee37e70ed5e548d2bbe324f85fc242e7a3bc541c`** |

**CI 预算**：A 2 次用 **1** 次；B 2 次用 **2** 次。

### #192 编译失败的成因（本会话自身错误，如实登记）

`S2View.swift:668:61: error: extra arguments at positions #12, #13 in call`。两条，都出在 B 的第一次提交：

1. **漏了中间层**。图像闭包链路是 `S2View` 造 `S2ImageContentContext` → App 的 `photoContent` 闭包 → 构造 `S2TemporaryPhotoImageView`。我只给最末端加了两个闭包参数，**未给中间的 `S2ImageContentContext` 加**，故调用点多出两个实参。
2. **顺序**。Swift 逐成员初始化器要求实参按声明顺序；我把新闭包声明在 `onImageReplacementSuppressed` **之后**，调用点却插在它**之前**。（与本会话早先在 `fittedCenterY` 上踩的是同一个坑。）

修正后逐个核对了四处顺序一致性（`S2ImageContentContext` 声明、`S2View` 调用点、App 转发、`S2TemporaryPhotoImageView` 声明），并确认 `S2ImageContentContext` 只有一个构造点、新参数均带默认值。

## 本地门禁（真实退出码）

每次提交前各跑满三项，全部 **0**：

| 门禁 | A | B 一轮 | B 二轮 |
|---|---|---|---|
| `Scripts/selfcheck.ps1` | 0 | 0 | 0 |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 0 | 0 | 0 |
| `git diff --check` | 0 | 0 | 0 |

硬编码扫描：目录 **181** 条、产品源码引用 **181**、用户可见硬编码残留 **0**，目录 key 与源码引用一致。

## Lynn 下载什么

| 项 | 值 |
|---|---|
| **run 编号** | **#193**（`https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/33202731171`） |
| 被测提交 | `f450566f5d1d79b49e74de664031357dea1843ad` |
| artifact | `PhotoCleanupMVE-unsigned-f450566f5d1d`（id `9698691488`，zip 855100 字节） |
| **IPA 字节数** | **854930** |
| **IPA SHA-256** | **`3555045749d8979372830812ee37e70ed5e548d2bbe324f85fc242e7a3bc541c`** |
| 内含 | 子项 **A**（跟随者逐张随动）+ 子项 **B**（双击探针，默认关闭）；`schemaVersion == 6` |

**IPA 复核说明**：字节数与 SHA-256 取自 CI 内「未签名 IPA 校验」步骤注解（CI 侧实算，①）。本机未重下复核——G258 只要求登记，且 IPA 归档不可复现（IC-094/097 证据①）。

## H46 人工判定清单（真机，Lynn，原样列出）

1. 快速连续翻页 5～10 张：缩略栏逐张带动画跟随、顶部三项逐张刷新、无新增卡顿。
2. 慢速翻页与横栏拖动切换：现行为不变。
3. 双击诊断：面板开启 → 对 3～5 张大图各做双击进/出 2 次 → **复制诊断报告全文贴回决策会话**。
4. 回归抽查：截图等距带、隐藏态手势、标记流程。

**四项全部可测。** 第 3 项的报告头部自带口径说明（帧间隔取 CADisplayLink 相邻时间戳之差；丢帧 = 超过标称间隔 1.5 倍；回调线程在切回主线程之前捕获）。

## 卡内取定登记

| # | 子项 | 取定 | 说明 |
|---|---|---|---|
| 1 | A | 新增 `didAdvanceIndexDuringScroll` 每手势布尔标志 | 用于边界提示门控；**不是索引副本**，索引单一来源不变 |
| 2 | A | 边界提示改为「整个滑动序列未改变索引才报」 | 复刻改前语义；不改则滑到最后一张必然误报 |
| 3 | B | 丢帧判定阈值取标称间隔 × 1.5 | 卡只要求「丢帧数」未定口径；阈值与口径均写入报告头部，可由决策会话按实测调整 |
| 4 | B | p95 取升序后第 `ceil(0.95n)` 位 | 同上，口径写入报告 |
| 5 | B | 探针核心置于 `S2NativePhotoPager.swift` 末尾 | 扫描器豁免区的硬约束，非风格选择（见第五节） |
| 6 | B | 面板四条文案新增 xcstrings 键 | 用户可见文案必须过目录；纯文本插入，零重排 |

## 发现但未处理的问题（只报告不修）

1. **Nx → 翻页交接时的 `s` 重置时刻前移**：`handleNativePageChange` 会调 `resetZoomAfterPhotoChange()`（`scale`/`imageRequestScale`/`viewportOffset` 归位）。索引更新前移后，若从 `Nx` 贴边交接到翻页，该重置比改前更早发生（滑动中 vs 停稳时）。1x 快速翻页无影响（本就都是 1x）。规格 v17 第 519 行「Nx 左右滑：已贴边且原生分页判定翻页并有目标时 → S2-1」只规定终态、未规定时机，故不构成冲突；但真机观感差异请在 **H46 第 2 项**顺带留意。
2. **`S2ImageContentContext` 与 `S2TemporaryPhotoImageView` 的参数已达 15 个**，且两处顺序必须手工保持一致——本卡的 #192 即栽在此。属结构性隐患，不在本卡范围。
3. **`Localizable.xcstrings` 的转义风格不统一**：部分值以 `\uXXXX` 转义、部分直接存汉字。本卡用纯文本插入回避了该问题，未做规范化（规范化会产生大面积无关 diff）。
4. **探针面板无录制时长上限**：既有过渡诊断有 `recordingLimitSeconds = 5`，本探针为手动起停、无上限。H46 第 3 项只做 3～5 张各 2 次双击，事件量可控；若日后长时间开启需补上限。
