# IC-085 自验报告（v2 卡：R1 测量 + R2 实装）

## 结论（先行）

- **R1 与 R2 全部完成。** 分支 `feature/ic-085-bottom-strip-parity` 自 `main` = `072d82cce9d1d0f0b3187b0439d87ee29db80b13` 切出（与 081/082/083/086 并行，不基于它们）。最终被测提交 `c659087aa553b5964be39896c6b4098bb527d715`，**CI #142 success**：XCTest **467 项、0 失败**（= 455 + 12 新增 − 0 删除），9 步全部 success（"运行 XCTest" 步按 `exit "$test_status"` 退出，真实退出码 0），未签名 IPA **768 522 字节，SHA-256 `b9fef811cdfcc5c2a24ac87c93647a94c483573bb20e9742e0b0f0a7f54b9e2f`**（CI 日志原文与本地 `gh run download` 后 `sha256sum` 一致）。
- **R1（v1 卡）触发闸门 A**：系统 Photos 录屏静止态当前张是 **90×90 px（30×30 pt）方形放大**，不是"同尺寸 + 留空"；技术负责人据此下发 v2 卡，决策 9 维持。R1 完整测量表在第三节。
- **R2 CI 次数：2 次（上限 2 次，已用满）**。#141（`995fe6e`）失败 1 项，是新测试自身的断言时序错误（减速结束那一帧后状态机已正常转 idle，测试仍断言 dragging），产品代码未改；修正后 #142 通过。
- 横栏实现改为：`S2BottomStripLayout` 单一几何入口 + `S2BottomStripMotionController` 运动控制器（闭式惯性 `k = 0.998`、停止后 600 ms 吸附展开、拖动开始 100 ms 收缩、可注入时钟），SwiftUI `DragGesture` 取 iOS 17 `velocity`；对外接口（`onPhotoSwitch`、`itemContent`、标记叠加）与 `bottomStripState` 语义不变。未用 `UIScrollView`，因此按卡保留 `bottomStripSwitchDistance = 23`（节距），废止 `bottomStripDragMinimumDistance`。
- 闸门 B、C 未触发。H33 保留给 Lynn 真机判定。

## 一、输入、继承、范围边界

- 任务卡 IC-20260823-085（v2）；上游 H24-1、H32；录屏 `IMG_6743.MP4`（25 106 740 B，只读）；SPEC-S2 v15 第六节、决策 9。
- 继承提交 `072d82c`。开工前 `git status --porcelain` 为空。
- 提交链（均可单独 cherry-pick）：`10dd8b4` R1 报告（v1 阶段）→ `e8a2d72` R2-1 参数 → `19f7acc` R2-2 横栏实装 → `995fe6e` R2-3 断言 → `c659087` R2-3 断言修正 → 本 docs 提交。
- 范围外未触碰：主图手势/翻页/捏合/居中/描边/过渡/图片请求、顶部信息区、操作条、主图标记、横栏标记参数（`bottomStripMarkSize` 不变）、其他参数出厂值、XCUITest、SPEC、Decision_log、`Scripts/`、`ci.yml`。未合并 main，未 force push。
- 本机 Windows 无 Xcode，所有实跑证据来自 CI #141/#142。

## 二、并发事故记录（已处置）

R1 阶段另一会话（IC-082）于 12:11 把其报告提交 `52b8fc8` 提交到了本分支上。处置：`52b8fc8` 以 `-X theirs` cherry-pick 到 `feature/ic-082-nx-edge-paging`（→ `dc14008`，内容与 `52b8fc8` 逐字节一致）；污染分支改名 `feature/ic-085-bottom-strip-parity-contaminated`（本地保留，未推送）；从 `072d82c` 重建本分支并 cherry-pick R1 报告（`706761a` → `10dd8b4`）。未 reset/rebase/force push。

## 三、R1 测量表（G161）

录屏 1206×2622，**59.99 fps**（卡写 30 fps），HEVC，11.38 s。几何用 `fps=30` 抽帧 341 张（帧号"30 fps 帧"）；减速跟踪用 `fps=60` 抽帧 682 张（"60 fps 帧"），原因：快速段每帧位移 > 节距一半，30 fps 无法无歧义跟踪。横栏带 y = 2247～2336 px；列最大亮度 > 40 分段，≤ 3 px 暗缝合并；px→pt = 1/3。

### 1. 静止段几何（px）

| 量 | 帧 97–136 | 帧 218–236 | 帧 325–341 | 定值 |
|---|---|---|---|---|
| 邻居宽 | 59.41（53–60，深色图缩边） | 60.00（59–61） | 59.98（59–60） | **60 = 20 pt** |
| 高（邻居/当前张） | 90 | 89.92 / 90 | 89.55 / 90 | **90 = 30 pt** |
| 常规间距 | 9.64（9–13） | 8.98（8–9） | 9.01（9–11） | **9 = 3 pt** |
| 当前张宽 × 高 | 54（深色边缘误判，按间隙反推 90） | **90 × 90**（极差 0） | **90 × 90**（极差 0） | **90 × 90 = 30 × 30 pt 方形** |
| 当前张两侧间隙 | 39/39（反推） | 39/39 | 39/38.94 | **39 = 13 pt** |
| 当前张中心 x | 602.5 | 602.5 | 602.5 | 屏幕中心 603 |

帧 1–13 为录屏起始偏暗段（带内均亮 57 vs 109），分割缩边，排除。滑动态（帧 33–57、137–199、240–305）所有项目 60 宽、9 间距、高 90，无放大无留空。

### 2. 内边距与渐隐（帧 76 左缘、帧 166 右缘列亮度剖面）

可见起点 x ≈ 61–62 px，线性升至 x ≈ 117 px 达 255；右侧对称（1090 → 1145）。定值 **leadingInset = 61 px = 20.3 pt，edgeFadeWidth = 56 px = 18.7 pt**。

### 3. 减速曲线（60 fps，v(t) = v0·k^(1000 t)，5 帧中值滤波，拟合区 2 ≤ v ≤ 34 px/帧）

| 段 | 帧 | 点数 | k（/ms） | v0（px/帧） | RMS 残差 | 相对 RMS | 累计位移 |
|---|---|---|---|---|---|---|---|
| run1 | 53–159 | 90 | 0.99805 | 41.2 | 5.01 px | 16.1% | 1265 px |
| run2 | 291–397 | 90 | 0.99799 | 42.5 | 4.20 px | 13.6% | 1262 px |
| run3 | 503–609 | 86 | 0.99796 | 41.9 | 3.23 px | 14.6% | 1227 px |

定值 **k = 0.9980**（= `UIScrollView.DecelerationRate.normal`）。单帧相对残差受 1 px 量化与快速段分割抖动影响；累计位移检查点（run1，v0 = 845.3 pt/s）与公式误差 ≤ 3%：t = 0.25/0.5/0.75/1.0/1.25/1.5/1.75 s → 162.0/274.3/340.7/379.3/402.3/415.0/421.3 pt（已写入 `S2BottomStripSystemReference`）。30 fps 尾段交叉核对：帧 184–195 每帧比 ≈ 0.93 ≈ 0.998^33.3。减速持续约 1.75 s 至 v < 1 px/帧自然停止。

### 4. 吸附 + 展开（30 fps 帧 199–217、305–323，两段逐帧一致）

减速停止后（偏最近项 +28 px）一条动画同时完成平移 −28 px、当前张 60→90、间隙 9→39；左邻 −73 px、右邻 +17 px。左邻逐帧位移 13,15,12,8,5,4,2,2,2,1,2,1,1,1,1,1,1,1（18 帧 = 600 ms，ease-out 长尾：100 ms 完成 55%、200 ms 80%、300 ms 86%）。吸附终点 = 最近项（28 < 34.5）。

### 5. 拖动起始收缩（60 fps 帧 26–38）

触下后约 6 帧（100 ms）内 90→60、39→9。

## 四、R2 实装要点

- **参数**（`e8a2d72`）：六项既有横栏参数重设并改 `decided`（30/20/30/3/18.7/23），`bottomStripEdgeFadeWidth` 接线改 `effective`；新增 `bottomStripCurrentItemGap = 13`、`bottomStripLeadingInset = 20.3`、`bottomStripDecelerationRate = 0.998`、`bottomStripExpandDurationMilliseconds = 600`、`bottomStripCollapseDurationMilliseconds = 100`（全部 decided/effective）；废止 `bottomStripDragMinimumDistance`（全仓 grep 0，解码时忽略旧键）。字段 37 → 41，导出 41 + 4 行，登记表 41 条（decided 34 / placeholder 7）；IC-074 G96/G97、IC-067 C5、`S2ImageLoadingStateTests` 计数断言同步更新。新键缺失时按出厂值解码（G162 往返测试覆盖）。
- **横栏**（`19f7acc`）：
  - `S2BottomStripLayout`：内容坐标第 i 张中心 = i × 节距；`expansion` 0～1 控制当前张 20→30 与两侧邻居外移 15 pt（= 半边增量 5 + 间隙增量 10）；两态高度恒 30；只为视口附近索引创建内容视图（原实现对全部资产布局）；两侧遮罩停靠点按 `leadingInset`/`edgeFadeWidth` 生成线性渐隐。
  - `S2BottomStripInertia`：闭式 `x(t) = x0 + v0·(k^(1000t) − 1)/(1000 ln k)`，位置按壁钟时间直接求得，掉帧不丢位移（针对陷阱 6）；终止速度 `stopSpeed = 20 pt/s`（③ 实现常量，= 录屏尾帧 1 px/帧）；吸附展开曲线指数 ease-out，时间常数 125 ms（③ 按录屏拟合，600 ms 处归一）；收缩二次 ease-out。
  - `S2BottomStripMotionController`：`beginDrag`（`machine.beginBottomStripDrag`，启动收缩）→ `updateDrag`（跟手，跨节距中点即 `S2BottomStripPhotoSwitcher.switchPhoto`，含触感）→ `endDrag(velocity)`（低于终止速度直接吸附，否则减速；减速中持续切图，`bottomStripState` 保持 `.dragging`）→ 减速结束 `endBottomStripDrag` → 600 ms 吸附最近项 + 展开（`.idle` 下完成）→ 帧驱动停止。减速中再次触下直接接管，不重开序列。外部定位项/张数变化在静止态直接居中（不动画，沿用原行为）。帧驱动 `CADisplayLink`（生产）/ 手动（夹具）；时钟可注入。
  - 视图：`DragGesture()` 原生默认起始距离，`value.velocity.width` 作松手速度；遮罩下方内容被 `.clipped()`，手势挂在顶层透明 `contentShape`。
- **断言**（`995fe6e` + `c659087`）：见第五节。

## 五、验收门禁

| 门禁 | 结果 | 测试函数 |
|---|---|---|
| G161 | 测量表（第三节）含帧号与残差；参考常量表 `S2BottomStripSystemReference`（含帧号注释、减速检查点、吸附采样）进测试 | `testIC085G162FactoryBottomStripValuesMatchSystemReference` |
| G162 | 出厂值逐项 = 参考表（0.5 pt / 0.0005）；节距 = 邻居宽 + 间距；废止项在字段/导出/登记表为 0；新参数集导出；横栏 decided+effective 12 项（含 markSize）；登记计数 41/34/7 | 同上；`testIC085G162PersistedConfigurationRoundTripsNewStripKeys`；`testIC074G96…`、`testIC074G97…`、`testIC067C5…`、`S2ImageLoadingStateTests` |
| G163 | 静止态当前张 30×30 居中、两侧间隙 13、邻居 20×30 间距 3、左右对称；滑动态全部 20×30 等距 3（中心距 23）；两态高度 30（`S2ViewportLayout` idle/dragging 相等）；渐隐停靠点 20.3/39 对称；可见区间有界 | `testIC085G163IdleLayoutCurrentItemSquareWithGaps`、`testIC085G163DraggingLayoutEquallySpacedAndHeightUnchanged`、`testIC085G163EdgeFadeStopsAndVisibleRange` |
| G164 | 拖动开始 100 ms 内展开度 → 0、状态机 dragging；减速 1/60 s 逐帧位移与 k=0.998 曲线误差 ≤ 10%，累计位移与录屏 run1 七个检查点误差 ≤ 10%，减速中定位项变化即切主图、状态机保持 dragging、结束转 idle、终点索引 17～19；松手偏 13 pt 吸附到第 5 张且 100/200/300 ms 进度 ≈ 0.55/0.78/0.86（±0.1），600 ms 处位置 = 目标、展开度 1、帧驱动停止，再过 1 s 无几何变化；偏 8 pt 吸附回原张不切图；减速中触下接管；惯性闭式解 = 速度积分 | `testIC085G164DragStartCollapsesWithinHundredMilliseconds`、`testIC085G164DecelerationMatchesReferenceCurve`、`testIC085G164SettleSnapsToNearestItemAndExpandsWithinSixHundredMilliseconds`、`testIC085G164ReleaseBelowHalfPitchSnapsBackWithoutSwitching`、`testIC085G164TouchDuringDecelerationTakesOverAndExternalIndexRecenters`、`testIC085InertiaClosedFormMatchesIntegratedVelocity` |
| 主图随横栏 | 拖动每跨一个节距切一张、触感次数相等、末张钳制、反向回到首张 | `testIC085MainImageFollowsStripDuringDrag` |
| G165 | IC-063～IC-083 既有门禁全部通过（CI #142 467/0，含 G108 横栏标记、V2 高度相等、H1/A2 触感）；本地三项门禁退出码 0 | — |
| G166 | CI #142 success，真实退出码 0，XCTest 0 失败 | — |

以上横栏动态断言均为**夹具驱动**（手动帧驱动 + 注入时钟调用控制器），未覆盖真实触摸事件序列、`CADisplayLink` 回调时序与 SwiftUI 重绘；真机表现由 H33 兜底。

## 六、CI 与本地门禁

| 项 | 值 |
|---|---|
| CI 运行 | #141 `995fe6e9e83921f2b62751b945c0b684532434f6` failure（1/467 失败，测试时序错误）；**#142 `c659087aa553b5964be39896c6b4098bb527d715` success** |
| #142 XCTest | Executed 467 tests, with 0 failures (0 unexpected)；IC-085 新增 12 项全部 passed |
| #142 退出码 | 9 步 success；XCTest 步 `exit "$test_status"` = 0 |
| IPA | 768 522 字节，SHA-256 `b9fef811cdfcc5c2a24ac87c93647a94c483573bb20e9742e0b0f0a7f54b9e2f`（日志原文 = 本地下载校验） |
| 本地 `selfcheck.ps1` / `scan-hardcoded-user-visible-strings.ps1` / `git diff --check` | 三个代码提交前各跑一次，退出码均 0 |

报告提交方式：按纪律 7，在同卡同分支追加本 docs 提交（不触发 CI，预期）。

## 七、人工判定（真机，保留给 Lynn）

- **H33**：与系统 Photos 并排同一相册——当前张方形放大、两侧间隙、邻居大小与间距、一屏张数；拖动瞬间收缩为矩形；甩动有惯性、停下后吸附并展开；拖动时主图跟切；待删标记仍在。
- 注意：若 Lynn 设备上保存过旧标定（IC-074 起 Keychain 持久化），横栏六项旧值会被解码沿用（72/52/44/8/24/44），新五项按出厂补齐；对比前需"恢复出厂占位"一次。

## 八、发现但未处理的问题（只报告）

1. **持久化旧值覆盖出厂值**（见七）：`S2CalibrationModel` 严格解码六项旧横栏键，schemaVersion 仍为 2（IC-074 G96 锁定）。是否随本卡迁移由技术负责人定。
2. **横栏触摸区高 30 pt**：`S2ViewportMetrics.bottomStripHeight = max(30, 30)`，`interfaceOverlay` 以此作 frame；系统触摸区高度未测。
3. **三个③实现常量**未登记为参数：`stopSpeed = 20 pt/s`、吸附时间常数 125 ms、收缩二次 ease-out；卡未列，按卡未新增参数。
4. **外部定位项变化时横栏不动画**（主图翻页时横栏瞬移居中），沿用原行为；卡未规定。
5. **减速期间 `touchSequenceOwner = .bottomStrip` 持续最长约 1.9 s**（v0 ≈ 850 pt/s 时），期间捏合/主图手势按既有规则被拒；与系统"减速中可被触摸打断"一致，但未测系统对主图手势的处理。
6. 卡写录屏 30 fps，实际 59.99 fps；R1 报告已说明。
7. 两个并行会话共用一个工作树导致的分支污染（第二节），建议各卡独立 worktree。

## 九、尝试计数

R1：1 次。R2：2 次（#141 失败、#142 成功），已达上限。
