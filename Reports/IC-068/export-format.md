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

### 自 IC-090 起的字段追加（格式版本仍为 1）

本节只追加，不修改上文任何既有约定。目的是给**场景 C 捏合起始**补足「捏合松手停下时抖动一下」的逐帧判据；IC-090 只加埋点，不改产品行为。

- 场景 C 的真机动作在本卡改为：开始录制 →**双指放大到约 3 倍后松手 → 等 1 秒**→ 停止录制 → 导出文本。场景名与 `exportTitle` 不变（`C 捏合起始`），其余四个场景不变。
- 逐帧记录在 `nxOverflowDistance` 之后追加五个字段，头部字段声明行同步为
  `…,nxDistanceToPreviousBoundary,nxDistanceToNextBoundary,nxOverflowDistance,presentationZoomScale,isZoomBouncing,isDecelerating,imageRequestResult,lastImageReplacement`：
  - `presentationZoomScale`：被缩放视图（`viewForZooming` 返回的 `zoomContentView`）图层 `presentation()` 的 `transform.a`，即**呈现层实际倍率**；无 presentation（不在动画中）时为 `nil`。与既有的模型值 `zoomScale` 对照，可区分「模型已结算、呈现层仍在动」。
  - `isZoomBouncing` / `isDecelerating`：内层缩放滚动视图的 `UIScrollView.isZoomBouncing` 与 `isDecelerating`（`true` / `false`，无控制器时 `nil`）。注意 `isDecelerating` 是**内层**，与既有的外层 `pagingIsDecelerating` 并列而不相同。
  - `imageRequestResult`：当前张最近一次图片请求返回的 `S2ImageRequestResult` 分支名——`degradedPreview` / `finalImage` / `failure` / `cancelled` / `assetUnavailable`；本次会话尚无返回时 `nil`。
  - `lastImageReplacement`：全局最近一次**真正发生的图片替换**，形如 `(asset=…,result=…,w=…,h=…,t=…)`；`t` 与逐帧记录同源（`CACurrentMediaTime()` 绝对值），与头部「起始绝对时间」相减即可对齐到 `time` 相对时间轴。尚无替换时 `nil`。
- 离散事件新增五类：
  - `event=scrollViewDidEndZooming`，来源 `S2NativeZoomPageController.scrollViewDidEndZooming`，`details=scale=…；endedAtMinimum=…；pinchWasActive=…；` 后接既有的页索引／资产上下文。
  - `event=finishNativePinch`，来源 `S2NativePagerViewController.finishNativePinch`，`details=scale=…；targetScale=…|nil；displacement=…；peakVelocity=…；duration=…；path=returnToMinimum|setZoomScale|noWrite|none`。`path` 是本次实际走的分支：`returnToMinimum` 走 `animateToMinimumZoomScale()`；`setZoomScale` 走 `setZoomScale(targetScale, animated:)`；`noWrite` 为目标与当前倍率一致、不写；`none` 为状态机未返回目标倍率。
  - `event=setZoomScale`，来源 `S2NativeZoomScrollView.setZoomScale`，`details=scale=…；animated=…；from=…`。该事件由 `setZoomScale(_:animated:)` 的重写统一记录，覆盖全部调用点（含 `animateToMinimumZoomScale` 与 `applyNativeState`）；`from` 为写入前的 `zoomScale`。
  - `event=吸附归位写入`，来源 `S2NativeZoomScrollView.restoreOneXGeometry` 或 `S2NativeZoomScrollView.enforceOneXContentGeometry`，`details=contentInset=…；contentSize=…；contentOffset=…；照片几何=…；` 后接页索引／资产上下文。四个布尔表示该次归位里各项是否真的发生了写入。照片层几何本身仍另由既有的 `event=照片几何写入`（`reason=…enforceOneXContentGeometry`）记录，两者成对出现。
  - `event=图片替换`，来源 `S2TemporaryPhotoImageView.requestImage`，`details=asset=…；result=…；pixel=(w=…,h=…)`。只在 `shouldDisplay` 通过且确有图像、即真正把 `image` 换掉的那一刻记录；请求返回但未替换（降质被策略挡下、失败、取消）不产生该事件。
- 关闭录制时以上埋点零副作用（仅在 `isRecording` 为真时追加记录）。逐帧字段所依赖的图片请求结果与替换记录登记在 `S2ImageLoadStateRegistry` 上，与录制开关无关，故录制开始时即可读到当前张已有的请求状态。
- 头部「格式版本=1」未递增；递增仍留待后续任务卡。

### 自 IC-093 起的事件追加（格式版本仍为 1）

本节只追加，不修改上文任何既有约定。**逐帧字段一个不加。**

- 离散事件新增一类 `event=图片替换被抑制`，来源 `S2TemporaryPhotoImageView.requestImage`：
  `details=asset=…；result=…；displayed=(w=…,h=…)；candidate=(w=…,h=…)`。
  - 产生条件（IC-093 R1，④ Lynn 2026-08-24 选 C）：**同一资产**已有已显示图像，且新返回结果的像素面积（宽 × 高）**低于**当前显示图像——该结果不上屏、不改变已显示加载态、**不产生 `图片替换` 事件**。
  - `displayed` 是当前在显示的图像的像素尺寸，`candidate` 是被抑制的返回结果的像素尺寸；两者都按 `点尺寸 × scale` 计算（PhotoKit 返回的图 `scale` 恒为 1，与既有 `图片替换` 事件的 `pixel=` 同口径）。
  - 与 `event=图片替换` **互斥**：同一次返回结果只会产生其中一条。
  - **资产切换不受限**：请求资产与当前显示资产不同（含首次显示）时判定不介入，降质预览照常先上屏（决策 28 行为不变），因此这种情形只会产生 `图片替换`。
  - 场景 C（捏合起始）的判读因此变为：松手后若导出里出现 `图片替换被抑制`（`candidate` 明显小于 `displayed`）而**没有**对应的降质 `图片替换`，即 IC-090 阶段三定位的闪替已被消除。
- 关闭录制时该埋点零副作用（仅在 `isRecording` 为真时追加记录）。头部「格式版本=1」未递增。

### 自 IC-095 起的字段与事件追加（格式版本仍为 1）

本节只追加，不修改上文任何既有约定。**逐帧字段一个不加。**

- 既有事件 `event=updateUIView`（来源 `S2NativePhotoPager.updateUIViewController`）的 `details` 追加一个字段，格式变为
  `写入照片几何=true|false；写入任意几何=true|false`。前一个字段的语义与取值口径不变。
  - `写入任意几何`：本次 `updateUIViewController` → `apply(...)` 期间录制窗口内**实际发生**的几何写入总数是否增加。
  - 计入「几何写入」的六类埋点（均以**确有落笔**为准，空转不计）：
    `外层setContentOffset`、`页frame写入`、`内层setContentOffset`、`setZoomScale`、
    `吸附归位写入`（`contentInset` / `contentSize` / `contentOffset` / `照片几何` 四个布尔任一为真时）、`照片几何写入`。
  - 因此 `写入照片几何=true` 必然伴随 `写入任意几何=true`；反之不然。
- 离散事件新增两类：
  - `event=页frame写入`，来源 `S2NativePagerViewController.layoutNativePages`，
    `details=frame=(x=…,y=…,w=…,h=…)；pageIndex=…；assetLocalIdentifier=…`。
    只在页控制器 `view.frame` 与目标 frame 不等、确实赋值的那一次记录。
  - `event=内层setContentOffset`，来源 `S2NativeZoomScrollView.applyNativeState`，
    `details=offset=(x=…,y=…)；pageIndex=…；assetLocalIdentifier=…`。
    只在 `applyNativeState` 求得的目标偏移与当前偏移之差超过 `0.000001`、确实写入的那一次记录。
    该写入既有的 `independentContentOffsetWriteCount` 计数口径不变。
- IC-095 R2/R3 把 `apply` / `layoutNativePages` / `applyPage` 下游的几何写入改为条件化后，
  静止态的导出中 `外层setContentOffset`、`页frame写入`、`内层setContentOffset`、`照片几何写入`
  均应为 0 条，`吸附归位写入` 四个布尔应全为 `false`，`updateUIView` 的 `写入任意几何` 应为 `false`。
  事件族本身一类不删——没有写入就没有对应记录，不是埋点缺失。
- 关闭录制时以上埋点零副作用（仅在 `isRecording` 为真时追加记录与计数）。头部「格式版本=1」未递增。
