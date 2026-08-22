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
