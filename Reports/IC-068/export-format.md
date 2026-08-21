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
