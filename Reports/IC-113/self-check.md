# IC-113 自验报告：视觉打磨（H49 六项反馈 + 中央指示改挂相簿）

> 本文为 **IC-113 + IC-113 v2 合并后的完整版**，整体替换首版。首版结论「C 未绿、预算用尽收口」已由 v2 收尾解决。

## 结论（先行）

**A、B、C 三项全部交付并绿。**

- **最终绿 tip（H50 完整包）** = `5c8cb3857d782052d1f7b121dc493a3d2015b8b3`，CI **#217**，**`Executed 560 tests, with 0 failures (0 unexpected)`**，真实退出码 0，IPA **970512 字节**，SHA-256 **`ce589fa51a46e1d40d21174fb2a0a0d9bd82695c4f2cdbeb004abfa405419cb8`**。**该包含 A + B + C，H50 五项清单全部可判。**
- **G281 / G286 / G287 / G288 通过**；**G282 全部达成**；**G283 通过**（`schemaVersion == 7` 未变，`S2Calibration.swift` 自本卡基线**整文件零 diff**，冻结三链、`ci.yml`、`Scripts/` 零改动）；**G284 通过**（未触碰任何手势识别器，穿透测试保持并按新语义改写）；**G285 未触发**。
- **CI 合计 6 次**：IC-113 本卡 5 次（A 1、B 1、C 3），IC-113 v2 追加 1 次。v2 卡预算 1 次，**恰好用尽、未超**。
- 时间闸门：IC-113 自 10:36 起 4 小时内收口；v2 单发小卡当日完成。
- **全程未合并 `main`。**

---

## 提交与 CI 一览

| 子项 | 提交 | CI | 结论 | XCTest | IPA 字节 |
|---|---|---|---|---|---|
| A 玻璃再透 + 描边收敛 | `b5a7577e86903f636a51e86404ba4d0ecc737c49` | **#212** | success | **565 / 0** | 963230 |
| B 中央指示改挂相簿 | `a3f86ffe53f1850015c5235f807abb274ead948b` | **#213** | success | **558 / 0** | 969172 |
| C 教程四处修正 | `db26f59820ab7b40bcb3bedc65f0cc77b8fcc097` | #214 | failure（类型检查超时） | — | — |
| C 拆分视图表达式 | `72bc58c94e22b37fefb061b4ba3e98a221f68db3` | #215 | failure（实参顺序） | — | — |
| C 修实参顺序 | `e03b12e4352ab3181320e7f4e79b55e3e0cd9962` | #216 | failure（2 处旧断言） | 560 / 2 | — |
| **C 收尾（v2）** | **`5c8cb3857d782052d1f7b121dc493a3d2015b8b3`** | **#217** | **success** | **560 / 0** | **970512** |

A 的 IPA SHA-256：`1f54b93e38905e934a6ddd408ee101a9982412c6889a9ac55d3e9441ff506632`；B 的：`5966c8591b462a1aee872dba19178b1b90188377e2bfc8acaa25474d060cb3e8`。

真实退出码：`ci.yml` 以 `exit "$test_status"` 原样退出；#212 / #213 / #217 的 check 结论均 `success`，即退出码 0（①）。三次红均为 65。

---

## 子项 A：玻璃再透 + 描边收敛

三处数值按卡内落值收敛：底色白 **6% → 3%**；内描边顶缘 **55% → 30%**、底缘 **12% → 6%**；外圈细环 **22% → 12%**。

**全部玻璃件同步一套值**：顶/底圆钮、顶/底胶囊、中央指示容器此前已走共用组件；**教程提示卡此前是单独写的 `.ultraThinMaterial` 且没有描边**，本卡并入 `s2ChromeGlassBackground`，四处至此共用同一套配方，满足卡内「不许各件各调」。

**blur 22 → 18 未实装**（登记）：SwiftUI 系统材质不暴露 blur 半径，`.ultraThinMaterial` 已是最薄一档；公开 API（`Material` / `UIBlurEffect(style:)`）只给固定档位，改半径需私有或未文档化手段，不做。卡内已预设这种情形，本卡先走**白底减半 + 描边减半**这条确定有效、零风险的路径。

**刻意仍未叠加 `.opacity()` / `.saturation()` / `.brightness()` 到材质层**：这些滤镜会把子树推进离屏合成，有打掉背景采样的风险（IC-112 A 已登记的同一顾虑），在本机无法验证的前提下不拿主诉求去赌。

| 验收点 | 测试函数 |
|---|---|
| 三处新值 + **相对旧值至少减半** + 结构性不变量 | `testIC113AGlassRecipeIsMoreTransparentAndSubtler` |

---

## 子项 B：中央指示改版

1. **已标记块：方形倒角 → 圆形。**
2. **第二态改为「已加入相簿」**：
   - 状态机新增 `S2AlbumAdditionRecord` 与 `@Published lastAlbumAddition`，在 `completeRecentAlbumAddition` / `completeAlbumPickerSelection` 的**两条 `.success` 分支**各登记一次——中胶囊与选择器两条路径都覆盖。**此前状态机只有两种失败反馈、没有任何成功信号**，无法判定「加入成功」，故必须新增；这是**加法**，未改任何既有转移语义。
   - **撤回 = 真实把资产从该相簿移除**（`PHAssetCollectionChangeRequest.removeAssets`，本卡显式授权）。服务协议新增 `removeAsset`，PhotoKit 实装与 `addAsset` 同一套前置校验，能力位换 `.removeContent`；**只动相簿成员关系，不删资产**。协调器新增 `requestS2AlbumRemoval`，App 侧接 `onAlbumRemovalRequest`。
   - 三段式与加入同构。成功清 `lastAlbumAddition`（指示随之退场）；**失败保留记录**（否则用户再也点不到撤回）并走既有反馈通道，未新增反馈分支。
   - 在途标志用独立布尔 `isAlbumRemovalInFlight`，**不进 `inFlightActions`**——那个集合驱动操作条三按钮的启用规则，撤回钮不在其列，混进去会连带改变操作条语义（G284）。
   - 相簿名取**真实相簿**（`record.album.name`），xcstrings 走格式参数。
3. **♡ 不再触发中央指示**：指示接线移除；`s2.center.favorited` 改名 `added_to_album` 并改文案，`s2.center.favorites_album` 已无引用随之删除。
4. **出现时机**：加入成功后延 `albumIndicatorDelaySeconds = 0.42 s` 再落指示，即**残影落入中胶囊（0.3 s）回弹后**（卡内取定并登记）。撤回清记录时立即复算，指示即时退场。
5. **穿透语义不变**：仅撤回钮可点，另两态无任何可点元素。

| 验收点 | 测试函数 |
|---|---|
| 只显示一种（六组合） | `testIC113BShowsExactlyOneStateAtATime` |
| `V=隐藏` 全组合不显示 | `testIC113BHiddenInterfaceShowsNothing` |
| **仅撤回钮可点**（G284） | `testIC113BOnlyUndoControlIsHittable` |
| 出现参数 + 指示不早于残影落点 | `testIC113BTransitionParametersMatchCanvas` |
| 两条加入路径都登记、撤回成功清记录、在途不可重入 | `testIC113BAlbumAdditionRecordPublishedAndClearedOnRemoval` |
| 撤回失败保留记录并发反馈 | `testIC113BFailedRemovalKeepsRecord` |
| 协调器把撤回接到服务、移除后成员关系消失 | `testIC113BCoordinatorRoutesRemovalToService` |

---

## 子项 C：教程四处修正（v2 收尾后已绿）

1. **第 5 步改为加入相簿引导**：`favoriteGuide` → `albumGuide`；聚光套底部**中胶囊**，中位为空时改套**右圆钮选择器**。文案改「把想留的照片加入相簿」族。推进条件 = 真实加入成功，由子项 B 新增的已发布 `lastAlbumAddition` 驱动（`assetDidBecomeFavorited` → `assetDidJoinAlbum`），与前四步同源、**不接触手势识别器**。教程仍六步。♡ 至此在教程与中央指示两处都无接线。
2. **图示成一个单元**：收紧到 `unitSpacing = 2`，对比处理加在整个单元上。
3. **白底可见性**：整个单元一层黑投影（35%、半径 3）。卡内给「白填充 + 约 35% 黑外描边**或**投影」，取投影分支——描边要逐形状各画一遍，投影一次覆盖圆与箭头，且不改变形状本身的白填充。
4. **步 4 路径避让**：新增 `S2TutorialHintAnchor`，步 4 把整个单元挪到中央指示块**下方**起跳（净空 16 pt）再向下平移，全程不与指示块相交。
5. **步 2 收紧**：聚光由整条横栏改为**那一枚缩略图**，用横栏渲染同一套 `S2BottomStripLayout.frame` 复算格位，再以中心为基准放大 **1.6** 倍；另加一枚小箭头直指角标。角标脉冲未动。

| 验收点 | 测试函数 |
|---|---|
| 第 5 步只被真实加入推动、点击不推进 | `testIC113CAlbumGuideAdvancesOnlyOnRealAlbumJoin` |
| 第 5 步聚光两分支（中胶囊横跨居中 / 选择器正方居右） | `testIC113CAlbumGuideSpotlightTargetsBottomCapsuleOrPicker` |
| 步 2 收紧 + 放大倍数 + 放大助手围绕中心 | `testIC113CStripSpotlightTightensToSingleItem` |
| 步 4 单元顶缘不越指示块底缘 | `testIC113CHintAvoidsCenterIndicatorOnStepFour` |
| 图示单元收紧值与投影值 | `testIC112CGestureHintEnlarged`（补断言） |
| **步 2 聚光几何按新推导式**（v2 改造） | `testIC111DSpotlightTargetsPerStep` |

### v2 收尾：最后一处旧断言的改造

#216 的两处失败是 C 第 5 项**正当作废**的旧期望（写的是「步 2 套整条横栏」）。v2 只改这一处，**产品代码零改动**（G286：`PhotoCleanupMVE/` 目录零 diff），期望全部改为推导式、不写字面量：

- **尺寸**：宽高 = 该格位尺寸 × `stripItemMagnification`；
- **摆放**：中心与该格位中心重合——尺寸断言不等于摆放断言（陷阱 13），故尺寸与摆放各断一条；
- **「收紧」本身**：宽度严格小于整条横栏宽；
- 并显式断言旧口径（横栏高 + 2×padding）**不再成立**，防止日后回退。

格位由横栏渲染同一套 `S2BottomStripLayout.frame` 复算，与产品同源、不另起真相。

**按 v2 卡第 3 项反查全部断言点，确认无第四处遗漏**（①）：
- `targetRect` 的全部 4 处调用（产品 1 + 测试 3），另两处测试是 C 新增、已按新行为；
- 测试里提及 `seeStripMark` 的 7 处，除本处外均为步进/方向/等待语义，不涉几何；
- 测试里用到 `stripBottomFromViewportBottom` 的其余各处属横栏与 chrome 自身几何（`S2CalibrationHarnessTests` 与 IC-112 C 卡底缘用例），与教程聚光无关。

### 两处前提更正（③ → ①）

- **「图示各动各的」与代码不符**（①）：圆与箭头**本就共用同一个 `.offset` 同步平移**（见 `S2TutorialGestureHint.body`）。H49 观感上的分离来自 10 pt 的空隙，故修的是观感成因（收紧 + 整体投影），不是机制。
- **「放大 1.3 → 1.6 倍」中的 1.3 不存在**（①）：全仓无该放大，聚光此前只是按原尺寸挖孔。故按目标值直接取 1.6。

---

## 本地门禁（本机 Windows，①）

每次提交前均跑满三门禁，**全部退出码 0**：`git diff --check`、`Scripts/selfcheck.ps1`、`Scripts/scan-hardcoded-user-visible-strings.ps1`。目录条目 193 = 产品源码引用 193，用户可见硬编码残留 0。

---

## H50 人工判定清单（原样列出，保留给 Lynn，不代为下结论）

1. 玻璃更透、描边不抢眼（白/彩色照片各看一张）。
2. 中央指示：标记块为圆形；加入相簿后出现 已加入"<名>"，点撤回从相簿移除并消失；♡ 不再出中央指示；手势穿透正常。
3. 教程：第 5 步引导加入相簿且真实加入才过；图示单元整体移动、白底可见、步 4 不穿指示块；步 2 一眼看到角标。
4. 缩略栏无底色观感（IC-112 D 交付，本包沿用）。
5. 回归：等距带、隐藏态、两条残影、双击。

**H50 包 = `5c8cb38`（CI #217）**，含 **A + B + C**，五项**全部可判**。

---

## 停线 / 偏差 / 待补核（逐条）

### 停线

- **A1（透光需产品结构性调整且影响几何契约）**：**未触发**。勘查确认层级正确，只改配方。
- **「必须改登记值 → 停，不得自行升版」**：**未触发**。`S2Calibration.swift` 全卡零 diff，`schemaVersion` 仍为 7。
- **G285 / G288（失败即停）**：**未触发**。四次红（#214/#215/#216 及其归因）逐条核对，全部是本卡自身改动引入的编译错误或被本卡正当作废的旧断言，无一项与本卡无关；v2 的 #217 一次绿。
- **CI 预算**：IC-113 本卡 5 次用尽（已按卡写全报告停止）；v2 卡 1 次预算恰好用尽。

### 偏差

1. **A 的 blur 未降**（见 A 节）。观感目标靠白底与描边双双减半达成。
2. **C 单项 CI 超出分配**：IC-113 内 C 分配 2 次、实用 3 次；该卡总额 5 次未超（B 分配 2 次只用了 1 次）。
3. **C 的白底可见性取「投影」而非「描边」分支**——卡内二选一，已说明理由。
4. **v2 卡描述与实装的一处出入**：v2 卡写「收紧到单枚缩略图（**含放大 1.6 与 padding**）」，但产品侧步 2 分支实际是 `magnified(item, by:)`、**不叠 padding**（放大本身已取代它，与套主图/圆钮的几步不同）。G286 与范围外都禁止改产品，故按实装写断言，并在测试注释里点明这一差异。**若决策会话本意是步 2 也应叠 padding，那是一处产品改动，需新卡授权。**

### 待补核

1. **A 的透光实效本机无法验证**（③）。若 H50 第 1 项仍判不够透，下一步建议按序试：①改用自定义 `UIVisualEffectView` 包装以取得更薄的档位；②把 chrome 的 `.opacity()` 显隐机制从容器下移到药丸内层，排除过渡期合成组影响（**属结构性改动，需新卡授权**）。
2. **三次红的成因与教训**（均属本卡自身）：
   - **#214**（类型检查超时）：子项 C 给教程浮层加了四个新参，而构造点**内联在 `body` 的 `ZStack` 里**，整个 body 表达式超出类型检查预算。教训：**给 SwiftUI 视图加参数时，若构造点内联在 body 的容器里，应同时把它抽成 builder**；本机无 Xcode 无法预先发现，只能靠这条习惯规避。已抽出 `tutorialOverlay(metrics:viewportSize:)` 与 `badgeArrow`。
   - **#215**（实参顺序）：抽 builder 时把新参写在了声明顺序之前。此后改为**程序化核对**全卡改过签名的四处，不再靠肉眼。
   - **#216**（2 处旧断言）：扫漏原因是我按「取值型」与「走查序列型」两条线索扫过，但这两条属**第三类——几何期望值型**，且藏在一个覆盖全部六步的通用用例里。**教训已在 v2 落实为做法**：改几何时直接以被改函数名（`targetRect`）反查全部断言点，v2 据此确认无第四处遗漏。
3. **教程第 5 步的完成判定依赖 `lastAlbumAddition`**：该记录在撤回成功后被清空。若用户在教程第 5 步加入相簿后**立即撤回**，记录清空但教程已推进到第 6 步（推进是一次性事件，不回退）——这是预期行为，H50 走查时可留意观感是否突兀。
