# IC-068 导出格式与真机录制步骤

## 录制入口

在 S2 长按主图打开调试入口，进入参数面板的“诊断录制”区。先选择场景，再依次使用“开始录制”“停止录制”“导出文本”。导出后，面板会显示可选择文本，并提供系统分享入口。

单次录制最多五秒；到时会自动停止并保留已有记录。录制器不触发单击、捏合或任何产品交互。

## 三个真机场景

| 场景 | 起始状态 | 人工动作 |
|---|---|---|
| A 单击显示（问题方向） | 裁切窄截图，`V=隐藏`，`s=1` | 开始录制 → 单击一次 → 等一秒 → 停止录制 → 导出文本 |
| B 单击隐藏（对照组） | 同一张图，`V=显示`，`s=1` | 开始录制 → 单击一次 → 等一秒 → 停止录制 → 导出文本 |
| C 捏合起始 | 同一张图，`V=显示`，`s=1` | 开始录制 → 双指缓慢放大少许后松手 → 停止录制 → 导出文本 |

## 文本结构

头部固定包含格式版本、场景、统一时钟、采样频率下限、五秒上限、起止绝对时间、记录总数和字段声明。所有记录均由 `CACurrentMediaTime()` 计时；正文 `time` 是相对本次开始时刻的秒数，保留十五位小数，记录严格递增。

逐帧记录以 `kind=frame` 标识，固定包含：

- `animationKeys`：`photoLayer.animationKeys()` 的完整数组；为空时仍输出 `[]`。
- `modelFrame`：照片模型层 frame。
- `presentationFrame`：照片 presentation layer frame；不存在时输出 `nil`。
- `transform`：照片层仿射变换六元组 `a,b,c,d,tx,ty`。
- `zoomScale`、`contentOffset`、`contentSize`。
- `V` 与 `s`。

离散记录以 `kind=event` 标识，固定包含 `event`、`source`、`details`。事件族覆盖 SwiftUI 的 `V` 状态发布、`updateUIViewController`（导出名为 `updateUIView`，并标明本次是否写照片几何）、内外层布局回调、照片几何写入、照片动画调用、显式 `CATransaction.commit()` 边界，以及 IC-067 外层布局写入抑制生效。

当前产品源码没有显式 `add(animation:)` 或 `removeAnimation(forKey:)` 调用，因此不会伪造对应记录；现有两处 `removeAllAnimations()` 均通过带来源的入口记录。若未来录制文本中出现照片动画调用，`details` 会同时给出 operation 与 key；`removeAllAnimations()` 的 key 记为 `*`。

### 自 IC-070 起的字段追加（格式版本仍为 1）

- 逐帧记录新增 `contentInset` 与 `adjustedContentInset` 两个字段，均为 `(top=…,left=…,bottom=…,right=…)` 四元组，取自 `UIScrollView` 当前值，缺失时输出 `nil`。
  头部字段声明行同步为 `time,animationKeys,modelFrame,presentationFrame,transform,zoomScale,contentOffset,contentSize,contentInset,adjustedContentInset,V,s`。
- 照片动画调用事件新增一类 key：`fitBorderLayer.*`，来源为 `S2NativeZoomPageController.applyPageImmediately` 与 `S2NativeZoomPageController.applyCornerMask`，对应描边层的 `removeAllAnimations()`。因此上文「现有两处 `removeAllAnimations()`」的描述自 IC-070 起不再精确，以本小节为准。
- 头部「格式版本=1」未递增；递增留待下一张修改诊断埋点代码的任务卡。

## 模拟器样例边界

同目录的 `simulator-sample.txt` 是由 300×600 模拟器测试夹具值整理的格式样例，仅用于检查字段、空数组、来源和统一排序是否完整。它不是三个真机场景的实测结果，不能用于判断根因。

### 自 IC-079 起的字段追加（格式版本仍为 1）

- 新增场景 **D 快速连续翻页**（`fastPaging`）：起始 `V=显示`、`s=1`，开始录制 → 快速连续左右滑 5 张 → 停止录制 → 导出文本。既有三个场景不变。
- 逐帧记录在 `s` 之后追加七个字段，头部字段声明行同步为
  `time,animationKeys,modelFrame,presentationFrame,transform,zoomScale,contentOffset,contentSize,contentInset,adjustedContentInset,V,s,pagingContentOffsetX,pagingIsDragging,pagingIsDecelerating,currentIndex,settledIndex,pageIndicesPresent,pageLoadStates`：
  - `pagingContentOffsetX`：外层分页容器 `contentOffset.x`；`pagingIsDragging` / `pagingIsDecelerating`：外层容器拖动与减速标志（`true` / `false`，无控制器时 `nil`）。
  - `currentIndex`：状态机当前索引；`settledIndex`：分页控制器已结算索引。
  - `pageIndicesPresent`：已创建页控制器的索引列表，升序，形如 `[1,2,3]`；为空输出 `[]`。
  - `pageLoadStates`：各已创建页的图像加载态，形如 `[1=displayed,2=loading,3=unknown]`；`loading` / `displayed` / `failed` 来自 `S2ImageLoadState`，`unknown` 表示该资产尚无加载态回调（横栏缩略图与非主图路径不登记）。
- 离散事件新增三类：
  - `event=页创建` / `event=页移除`，来源 `S2NativePagerViewController.apply`，`details=pageIndex=…；asset=…`。
  - `event=外层setContentOffset`，来源为写入点（`S2NativePagerViewController.apply` / `synchronizeNativeStateToMachine` / `updateNXEdgePaging` / `layoutNativePages`，最后一处为 `contentOffset` 直接赋值），`details=x=…；animated=true|false`。
  - `event=handleNativePageChange`，来源 `S2NativePagerViewController.finishNativePaging`，`details=from=…；to=…；accepted=true|false`。
- 关闭录制时以上埋点零副作用（仅在 `isRecording` 为真时追加记录）。头部「格式版本=1」未递增。

### 自 IC-082 起的字段追加（格式版本仍为 1）

- 新增场景 **E Nx 贴边翻页**（`nxEdgePaging`）：起始 `s > 1`，开始录制 → （一次）先把画面平移到贴边再向同方向快滑切页；（另一次）不贴边直接快滑 → 停止录制 → 导出文本。既有四个场景不变。
- 逐帧记录在 `pageLoadStates` 之后追加三个字段，头部字段声明行同步为
  `…,pageIndicesPresent,pageLoadStates,nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance`：
  - `nxDistanceToPreviousBoundary` / `nxDistanceToNextBoundary`：本次贴边翻页拖动**开始时**缩放后内容到视口左 / 右边界的距离（pt），来自 `beginNXEdgePaging` 建立的交互记录；非贴边拖动期间输出 `nil`。
  - `nxOverflowDistance`：当前投影的溢出量（pt，`updateNXEdgePaging` 最近一次计算）；无投影时 `nil`。
  - 内层 `contentOffset` / `contentSize` / `zoomScale`、外层 `pagingContentOffsetX`、`pagingIsDragging` / `pagingIsDecelerating`、`currentIndex` 复用既有字段。
- 离散事件新增三类：
  - `event=beginNXEdgePaging`，来源 `S2NativePagerViewController.beginNXEdgePaging`，`details=restingPagingOffsetX=…；distanceToPreviousBoundary=…；distanceToNextBoundary=…`。
  - `event=handleHorizontalSwipe`，来源 `S2NativePagerViewController.finishNXEdgePaging`，`details=direction=next|previous；startedAtPagingEdge=true|false；distance=…；velocity=…；accepted=true|false`。
  - `event=synchronizeNativeStateToMachine`，来源同名，`details=animatedPaging=true|false；currentIndex=…；s=…`。
  - 每次 `writePagingContentOffset` 仍以既有 `event=外层setContentOffset`（含来源与 `animated`）记录。
- 关闭录制时以上埋点零副作用。头部「格式版本=1」未递增。

### 自 IC-082 R3 起的说明（格式版本仍为 1）

- Nx 贴边翻页的自定义投影路径（`beginNXEdgePaging` / `updateNXEdgePaging` / `finishNXEdgePaging`）已删除，左右拖动由 UIKit 嵌套滚动在内层到边界后交接给外层分页容器。因此：
  - 逐帧字段 `nxDistanceToPreviousBoundary` / `nxDistanceToNextBoundary` / `nxOverflowDistance` **保留列位、恒为 `nil`**（不递增格式版本、不改列数）。
  - 事件 `beginNXEdgePaging` 不再产生；`外层setContentOffset` 不再出现来源 `updateNXEdgePaging`。
  - 事件 `handleHorizontalSwipe` 仅由序列边界尝试路径产生，来源为 `S2NativePagerViewController.reportSequenceBoundaryAttemptIfNeeded`，`details` 格式不变（`startedAtPagingEdge` 恒为 `true`）。
  - 贴边切页的过程在既有字段中体现：外层 `pagingIsDragging=true` 期间 `pagingContentOffsetX` 连续变化，结算为 `handleNativePageChange`（来源 `finishNativePaging`）与 `synchronizeNativeStateToMachine(animatedPaging=false)`。

### 自 IC-091 起的字段与事件追加（格式版本仍为 1）

本节只追加，不修改上文任何既有约定。目的是给**场景 E Nx 贴边翻页**补足「起始不贴边的横向拖动在同一手势内交给外层」的逐帧判据。

- 场景 E 的真机动作在本卡改为三段（场景名与 `exportTitle` 不变，仍为 `E Nx 贴边翻页`；其余四个场景不变）：
  - (a) 放大 2～3 倍，从画面中部横拖到边后**继续沿同方向拉约 1/4 屏**再松手；
  - (b) 同上但拉过半屏或快甩；
  - (c) 贴边起手斜滑。
- 逐帧记录在 `nxOverflowDistance` 之后追加五个字段，头部字段声明行同步为
  `…,nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance,pagingIsTracking,zoomIsTracking,zoomIsDragging,zoomPanState,zoomDirectionalLock`：
  - `pagingIsTracking`：外层分页容器的 `UIScrollView.isTracking`。与既有的 `pagingIsDragging` **并列而不相同**——手指已按在外层上但外层 pan 尚未越过起始阈值时，`isTracking=true` 而 `isDragging=false`；层间交接的窗口正落在这个差里。
  - `zoomIsTracking` / `zoomIsDragging`：**内层**缩放滚动视图的 `isTracking` / `isDragging`（既有的 `isDecelerating` 字段自 IC-090 起也指内层，本卡未引入该字段）。
  - `zoomPanState`：内层 `panGestureRecognizer.state` 的 `rawValue`——`possible=0`、`began=1`、`changed=2`、`ended=3`、`cancelled=4`、`failed=5`。
  - `zoomDirectionalLock`：内层 `UIScrollView.isDirectionalLockEnabled`。IC-091 采用手段 M1，只在**本次手势**内为水平主导的内层拖动置真，手势结束、翻页结算、双击、捏合开始、复位 1x 时清零；静止态恒为 `false`。
  - 无控制器 / 无当前页时各字段输出 `nil`。
- 离散事件新增三类，另有一类既有事件的 `details` 扩充：
  - `event=nxInnerPanDecision`（判定规则复制自 IC-089 `7178de4`，`details` 末尾追加一项）：
    `details=innerShouldBegin=true|false；horizontalDominant=true|false；atEdgeInDragDirection=true|false；distanceToEdge=…|nil；translation=x,y；velocity=x,y；pageIndex=…；asset=…；engagesDirectionalLock=true|false`。
    - `innerShouldBegin=false` 表示起始贴边且水平主导，内层 pan 未开始、整个手势由外层分页容器接管（**起始贴边路径，IC-091 不改动**）；`true` 表示内层照常平移。
    - `distanceToEdge` 为拖动方向上缩放后内容边界到视口边界的距离（pt）；1x 或非水平主导时为 `nil`。
    - `engagesDirectionalLock=true` 表示本次手势启用内层方向锁（Nx、水平主导、起始不贴边）。
    - `source` 有两种取值：`S2NativeZoomScrollView.gestureRecognizerShouldBegin` 与 `S2NativeZoomScrollView.handleInnerPanStateChange`。IC-089 的两段真机录制中该事件一次都没出现，说明前一个钩子在真机上未必被调用；因此 IC-091 在内层 pan 识别器的 `.began` 回调上补一次判定，`source` 即用于区分本次判定实际由哪个钩子发出。`.began` 回调**无条件**重算一次（它一定会到，且此刻的位移是本次手势的权威起始向量，也保证上一次手势的方向锁不残留），因此一次手势最多两条：两条都出现说明两个钩子都被调用，只出现 `handleInnerPanStateChange` 一条即证实 `gestureRecognizerShouldBegin` 在真机上未被调用。
  - `event=nxHandoffPoint`，来源 `S2NativePagerViewController.noteInnerHandoffIfNeeded`，在**内层于拖动方向到边且仍受拖的第一帧**产生，每次手势至多一条：
    `details=direction=left|right；innerContentOffset=(x=…,y=…)；distanceToEdge=…；outerContentOffsetX=…；outerIsTracking=…；outerIsDragging=…；zoomDirectionalLock=…；pageIndex=…；assetLocalIdentifier=…`。
  - `event=nxHandoffWindow`，来源 `S2NativePagerViewController.setHandoffWindowOpen`：
    `details=state=open|close；reason=…；outerContentOffsetX=…；outerIsTracking=…；outerIsDragging=…；pageIndex=…；assetLocalIdentifier=…`。
    - `state=open` 由 `nxHandoffPoint` 打开，`reason=交接点`；`state=close` 的 `reason` 取值：`外层拖动结束不减速`、`外层减速结束`、`内层手势结束`、`翻页结算`、`交互状态复位`。
    - 窗口打开期间 App 不写外层 `contentOffset`（`apply` 与 `layoutNativePages` 的静止偏移写入均跳过），因此这段区间内不应出现来源为这两者的 `外层setContentOffset` 事件。
  - `event=scrollViewWillBeginDragging`，来源 `S2NativePagerViewController.scrollViewWillBeginDragging`，`details=层级=外层；contentOffsetX=…；isTracking=…；isDragging=…；currentIndex=…；settledIndex=…`。`层级=外层` 用于与内层的同名回调区分（内层该回调本卡未埋点）。
  - 既有 `event=外层setContentOffset` 的 `details` 在 `animated=…` 之后追加两项，成为
    `details=x=…；animated=true|false；outerIsTracking=true|false|nil；outerIsDragging=true|false|nil`。两个标志取自写入**发生前**的外层容器；无控制器时为 `nil`。事件名与 `source` 取值不变。
- 关闭录制时以上埋点零副作用（仅在 `isRecording` 为真时追加记录）。头部「格式版本=1」未递增；递增仍留待后续任务卡。

### 自 IC-092 起的事件追加（格式版本仍为 1）

本节只追加，不修改上文任何既有约定。**逐帧字段一个不加**——IC-091 的五个字段够用。

背景（①，IC-091 H37 三段录制）：内层到边后 UIKit 并不把同一手势交给外层，而是把位移改道给自由轴（方向锁下 y 以约 1 px/帧爬动）；外层在内层 pan 开始的瞬间就停止跟踪触摸，已无触摸可接。因此交接窗口内改由 App 把内层 pan 的横向增量映射到外层偏移。窗口内 App 是**唯一写者**（`apply` 与 `layoutNativePages` 由 IC-091 R3 守卫排除，外层原生拖动经①证明不会出现，另有让位保险兜底）。

- 离散事件新增三类：
  - `event=nxWindowFollow`，来源 `S2NativePagerViewController.followNxHandoffWindow`，交接窗口内每次跟随写入产生一条：
    `details=translationDeltaX=…；outerContentOffsetX=…；clamped=true|false；restingOffsetX=…；pageStride=…；pageIndex=…；assetLocalIdentifier=…`。
    - `translationDeltaX` 是内层 pan 相对**交接点**的横向增量（手指左移为负）；映射为 `outerContentOffsetX = 交接点外层偏移 − translationDeltaX`，1:1。
    - `clamped=true` 表示本帧被 ±1 页步距的钳制改写。
    - 每条 `nxWindowFollow` 之后紧跟一条 `event=外层setContentOffset`，来源 `S2NativePagerViewController.nxWindowFollow`、`animated=false`。**窗口开与关之间出现来源不是 `…nxWindowFollow` 的 `外层setContentOffset`，即第二写者，是闸门 C' 的判据。**
  - `event=nxWindowVerticalSuppression`，来源同上，只在内层 y 相对交接点值偏差达到死区（1 pt）时产生：
    `details=deviation=…；restoredOffsetY=…；deadband=1.000000；pageIndex=…；assetLocalIdentifier=…`。回写与同帧的跟随写入在**同一个 `CATransaction` 提交边界**内，边界本身由既有 `event=CATransaction提交边界`（来源 `S2NativePagerViewController.followNxHandoffWindow`）记录。
  - `event=nxWindowSettlement`，来源 `S2NativePagerViewController.settleNxHandoffWindow`，松手 / 取消时产生一条：
    `details=progress=…；directionalVelocity=…；triggerVelocity=…；progressThreshold=0.500000；shouldPage=true|false；direction=next|previous|none；from=…；to=…；pageIndex=…；assetLocalIdentifier=…`。
    - `progress` = |外层偏移 − 静止偏移| / 步距；`directionalVelocity` 是内层 pan `velocity(in:).x` 按翻页方向取正后的值；`triggerVelocity` 取标定参数 `edgePagingTriggerVelocity`（出厂 300 pt/s，IC-092 复接线）。
    - 判据：`progress > 0.5` **或** `directionalVelocity >= triggerVelocity` → 翻页；两者皆不满足 → 弹回。边界严格（`0.5` 与 `299` 都判弹回）。
    - `to` 是钳到序列范围内的目标索引；`from == to` 即本次为弹回。
- 既有 `event=nxHandoffWindow` 的 `reason` 新增两种取值：`结算完成`（松手结算路径关窗）、`原生接管`（让位保险：窗口内外层自身 `isDragging` 变真，或外层 `scrollViewWillBeginDragging` 到来）。上文列出的五种取值仍然有效。
- 关闭录制时以上埋点零副作用。逐帧字段与头部「格式版本=1」均未变。

### 自 IC-092 阶段二起的事件追加（格式版本仍为 1）

本节只追加，不修改上文任何既有约定。**逐帧字段仍然一个不加。**

背景（①，H38 录制 `#160a.txt` / `#160b.txt`）：(a) 弹回动画被自家关窗路径上的第二次非动画写抹成瞬移；(b) 快甩时手指在到边**之前**就离开，内层靠减速滑到边界后死停，交接点条件「到边且仍受拖」不成立，整段没有任何表现。

- 离散事件新增三类：
  - `event=外层setContentOffset被抑制`，来源为被拦下的那次写入的原来源，`details=x=…；animated=false；reason=结算动画进行中`。结算动画（含动量露出回弹）发出后到收口之间，**任何路径**的非动画外层写都会被唯一写入口拦下并记这一条。**窗口开与关之间出现来源不是 `…nxWindowFollow` / `…nxMomentumBounce*` 的成功写入，仍是闸门 C' 的判据；本事件则是「拦住了」的正面证据。**
  - `event=nxSettlementCloseSuppressed`，来源 `S2NativePagerViewController.scrollViewDidEndDragging` 或 `…scrollViewDidEndDecelerating`，`details=suppressedReason=外层拖动结束不减速|外层减速结束；state=结算动画进行中`。`#160a.txt` 里那次 0.4 ms 后的「外层减速结束」是误触发——外层从未拖动、从未减速；结算动画期间这类回调一律忽略，本事件把忽略记下来。
  - `event=nxMomentumBounce`，来源 `S2NativePagerViewController.beginNxMomentumBounce`，`details=edgeVelocityX=…；peakOffset=…；durationSeconds=…；direction=left|right；restingOffsetX=…；outwardOffsetX=…；pageIndex=…；assetLocalIdentifier=…`。
    - `edgeVelocityX` 是**到边瞬间**的横向速度（pt/s，内层偏移空间，正值表示偏移增大 = 手指曾向左甩），由减速段最后两帧的偏移差分求得——`velocity(in:)` 在手指离开后不再更新，只能走几何差分。
    - `peakOffset = min(|edgeVelocityX| × nxMomentumBouncePeakVelocityFactor, 0.5 × 页步距)`；`durationSeconds` 取 `nxMomentumBounceDurationMilliseconds / 1000`，出、回各占一半，分别为缓出 / 缓入。
    - 露出与回位两段的外层写各记一条既有 `event=外层setContentOffset`，来源分别是 `S2NativePagerViewController.nxMomentumBounceOut` 与 `…nxMomentumBounceBack`，`animated=false`（模型值在 `UIView` 动画块内一次到位，呈现层由渲染层驱动）。
- 既有 `event=nxHandoffWindow` 的 `reason` 再新增一种打开取值：`动量到边`（手指已离开、内层靠减速滑到边界时打开窗口做露出回弹）。关闭取值不变，动量路径同样以 `结算完成` 收口。
- 两个新标定参数进导出文本：`nxMomentumBouncePeakVelocityFactor`（出厂 0.05）、`nxMomentumBounceDurationMilliseconds`（出厂 350）；`schemaVersion` 随出厂值集合变更递增为 **5**。
- 关闭录制时以上埋点零副作用。逐帧字段与头部「格式版本=1」均未变。
