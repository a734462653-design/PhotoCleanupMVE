# IC-108 变更清单：跟随者立即逐张跟随（A）+ 双击丝滑度诊断探针（B）

## 分支与提交

| 项 | 完整 SHA |
|---|---|
| 继承基线（`main`） | `e08f7de665d51cfdb5be029865a691c7c4152c6b` |
| 分支 | `feature/ic-108-follow-and-zoom-probe`（**自 `main` 切出，全程未合并**） |
| **最终绿 tip** | **`f450566f5d1d79b49e74de664031357dea1843ad`（CI #193）** |
| 报告提交 | 只含 `Reports/IC-108/`，命中 `paths-ignore`，**不触发 CI** |

代码提交（3 个，各自可单独 cherry-pick）：

| # | 子项 | 完整 SHA | 提交信息首行 | CI |
|---|---|---|---|---|
| 1 | **A** | `51c14b58f35f8f6a36aa97860e0e0699543fa06d` | `feat(s2): 跟随者逐张立即随动（IC-108 子项 A，未定项 22 定案）` | **#191 绿（522 / 0）** |
| 2 | B | `3aea742c075963765735363b56bb99907f4a83be` | `feat(s2): 双击丝滑度诊断探针（IC-108 子项 B，只测不改）` | #192 红（编译） |
| 3 | **B** | **`f450566f5d1d79b49e74de664031357dea1843ad`** | `fix(s2): 补 S2ImageContentContext 的探针闭包并对齐参数顺序（IC-108 B）` | **#193 绿（525 / 0）** |

## 文件变化

### 子项 A（`e08f7de..51c14b5`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 43 | 1 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 136 | 0 |

合计 **2 files, 179 insertions(+), 1 deletion(-)**。产品侧仅 pager 一个文件。

### 子项 B（`51c14b5..f450566`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 346 | 0 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 64 | 0 |
| `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift` | 16 | 4 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 5 | 1 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 44 | 0 |
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | 170 | 0 |

### 全卡产品侧合计（`e08f7de..f450566`）

| 文件 | 增 | 删 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift` | 389 | 1 |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 64 | 0 |
| `PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift` | 16 | 4 |
| `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` | 5 | 1 |
| `PhotoCleanupMVE/Localizable.xcstrings` | 44 | 0 |

未触碰：`ci.yml`、`Scripts/`、`.xcodeproj`、`S2Calibration.swift`、`S2StateMachine.swift`、SPEC、Decision_log、`Reports/IC-068/export-format.md`。

## 子项 A 关键差异

```diff
     func scrollViewDidScroll(_ scrollView: UIScrollView) {
         guard scrollView === pagingScrollView, !isApplyingSnapshot else {
             return
         }
         ensurePagesExistAroundPagingOffset()
+        advanceCurrentIndexToPagingOffsetIfNeeded()
     }
+
+    /// IC-108 A：主图每越过一页边界即刻更新 `machine.currentIndex`，两个跟随者
+    /// 因此逐张立即随动，不再等滑动停稳。
+    /// 只改**索引更新时机**，不碰几何：不写任何 `contentOffset`、不调
+    /// `synchronizeNativeStateToMachine`（那是停稳路径的职责）。
+    private func advanceCurrentIndexToPagingOffsetIfNeeded() {
+        guard let machine else { return }
+        let targetIndex = pagingScrollView.pageIndex(
+            forContentOffsetX: pagingScrollView.contentOffset.x
+        )
+        let previousIndex = machine.currentIndex
+        guard targetIndex != previousIndex else { return }
+        let accepted = machine.handleNativePageChange(to: targetIndex)
+        if accepted { didAdvanceIndexDuringScroll = true }
+        transitionDiagnostics?.recordNativePageChange(
+            from: previousIndex, to: targetIndex, accepted: accepted
+        )
+    }
```

```diff
-        } else if targetIndex == previousIndex {
+        } else if targetIndex == previousIndex,
+                  !didAdvanceIndexDuringScroll {
+            // IC-108 A：索引已在滑动中推进过时，停稳处的「目标 == 当前」不再表示
+            // 「这次拖动没能翻页」，故不得据此报边界。
             reportSequenceBoundaryAttemptIfNeeded()
         }
```

**唯一新增状态**：`didAdvanceIndexDuringScroll`（每手势布尔标志，`scrollViewWillBeginDragging` 置假、`finishNativePaging` 收尾复位）。**不是索引副本**。

## 子项 B 关键差异

新增类型（置于 `S2NativePhotoPager.swift` 末尾，扫描器豁免区内）：

| 类型 | 职责 |
|---|---|
| `S2DoubleTapProbeImageRequest` | 一次图像请求：资产、目标尺寸、发起/完成时刻、**真实回调线程**、返回像素尺寸 |
| `S2DoubleTapProbeScaleChange` | `imageRequestScale` 的一次变化（倍率 + 时刻） |
| `S2DoubleTapProbeEvent` | 一次双击：方向、目标倍率、资产、页索引、`s` 起止、起止时刻、帧时间戳序列；派生 `totalFrameCount` / `droppedFrameCount` / `maximumFrameInterval` / `p95FrameInterval` / `durationSeconds` |
| `S2DoubleTapSmoothnessProbeCoordinator` | `ObservableObject`；`start` / `stop` / 六个 `record...` 埋点；`canExport` |
| `S2DoubleTapProbeText` | 报告文本（表头含口径说明 + 每事件一行 + 倍率变化行 + 图像请求行） |

埋点接线：

```diff
+    weak var doubleTapProbe: S2DoubleTapSmoothnessProbeCoordinator? {
+        didSet {
+            pageControllers.values.forEach { $0.doubleTapProbe = doubleTapProbe }
+        }
+    }
```

```diff
         isDoubleTapTransitionActive = true
+        doubleTapProbe?.recordDoubleTapBegan(
+            enteringNx: enteringNx, targetScale: targetScale,
+            assetID: assetID, pageIndex: index,
+            startScale: zoomScrollView.zoomScale,
+            timestamp: CACurrentMediaTime()
+        )
```

```diff
         ) { result in
+            // IC-108 B：在 `DispatchQueue.main.async` 之前捕获真实回调线程。
+            onImageRequestRawResult(
+                Thread.isMainThread,
+                result.image?.size ?? .zero
+            )
             DispatchQueue.main.async {
```

**产品侧删除行合计 5 行**（G259）：

```diff
-            targetSize: CGSize(            ← 4 行：内联表达式提为 let requestTargetSize
-                width: CGFloat(key.width),       （同值传递的纯重构）
-                height: CGFloat(key.height)
-            ),
-                                            .onImageReplacementSuppressed   ← 1 行：转发闭包末尾补逗号
```

其余全部为新增观测代码。

## 文案

| 项 | 值 |
|---|---|
| 新增 key | `s2.calibration.double_tap_probe.title` / `.start` / `.stop` / `.share` |
| 目录条目 | 177 → **181** |
| 方式 | **纯文本插入**：44 行纯新增、零删除、零重排；JSON 合法性已校验 |
| 扫描确认 | 目录 181、产品源码引用 181、用户可见硬编码残留 **0** |

## 测试计数账本

| 子项 | 新增 | 改造 | 删除 |
|---|---|---|---|
| A | **2** | 0 | 0 |
| B | **3** | 0 | 0 |

| 提交 | 本机计数 | CI Executed |
|---|---|---|
| 继承 `e08f7de` | 520 | — |
| `51c14b5`（A） | 522 | **522 / 0 失败** |
| `3aea742`（B 一轮） | 525 | 编译失败 |
| **`f450566`（B 二轮）** | **525** | **525 / 0 失败** |

校验：520 + 5 − 0 = **525** ✓。**无静默删除，无既有测试被改造。**

### 新增测试逐条

| 测试 | 子项 | 断言要点 |
|---|---|---|
| `testIC108AFollowersTrackEveryPageDuringFastPaging` | A | 停稳前索引/资产/顶部序号/横栏当前项已逐张更新；停稳后不回退 |
| `testIC108ANoGeometryWriteAndNoSpuriousBoundaryHintDuringFastPaging` | A | 滑动期间非动画外层偏移写入增量 0；滑到最后一张后 `pendingUndecidedItem` 为 nil |
| `testIC108BProbeRecordsAllRequiredFieldsWhenRecording` | B | 必采字段逐条齐全 + 统计口径 + 报告文本 |
| `testIC108BProbeRecordsNothingWhenDisabled` | B | 关闭态零记录、报告空、不可导出 |
| `testIC108BProbeCapturesDoubleTapThroughPager` | B | 经 pager 的真实双击产生完整事件；未接线零记录 |

五项**全部标注「夹具驱动，真机未覆盖」**（陷阱 1），由 H46 兜底。

## CI 记录

| run | id | 被测提交 | 子项 | 结论 | 退出码 | XCTest | IPA |
|---|---|---|---|---|---|---|---|
| **#191** | `33198646075` | `51c14b5` | **A** | **success** | **0** | **522 / 0** | 838186 字节，`4f8bb4a9…b323` |
| #192 | `33202113000` | `3aea742` | B | failure | 65 | 编译失败 | 无 |
| **#193** | **`33202731171`** | **`f450566`** | **B** | **success** | **0** | **525 / 0** | **854930 字节，`3555045749d8979372830812ee37e70ed5e548d2bbe324f85fc242e7a3bc541c`** |

**CI 预算**：A 2 次用 **1**；B 2 次用 **2**。

## 占位值登记

| 项 | 值 |
|---|---|
| `schemaVersion` | **6，未动**（探针开关为运行态，不入 `S2CalibrationConfiguration`） |
| `export-format.md` | **零 diff** |
| 新增可调参数 | **无** |

## 卡内取定登记

| # | 子项 | 取定 |
|---|---|---|
| 1 | A | `didAdvanceIndexDuringScroll` 每手势布尔标志（非索引副本） |
| 2 | A | 边界提示改为「整个滑动序列未改变索引才报」，复刻改前语义 |
| 3 | B | 丢帧阈值 = 标称帧间隔 × 1.5，标称取 `CADisplayLink.duration` |
| 4 | B | p95 取升序第 `ceil(0.95n)` 位 |
| 5 | B | 探针核心置于 `S2NativePhotoPager.swift` 末尾（扫描器豁免区硬约束） |
| 6 | B | 面板四条文案新增 xcstrings 键 |

第 3、4 两项的口径均写入报告头部，Lynn 贴回的报告可自解释，决策会话可按实测调整。

## 范围核对

| 项 | 结果 |
|---|---|
| 是否合并进 `main` | **否**（`main` 停在 `e08f7de`） |
| 是否对双击丝滑度做任何「修复」 | **否**（B 只测不改，G259 已验） |
| 是否 rebase / amend / force push / 删分支 | **否** |
| 是否修改 SPEC / Decision_log / `ci.yml` / `Scripts/` / `export-format.md` | **否** |
| 是否触碰冻结三链 | **否**（`b368a6c` / `6736f1e` / `a7cc1ec` 引用未变） |
| 是否新增可调参数或改 `schemaVersion` | **否** |
| 是否触碰视觉稿各项 | **否** |
