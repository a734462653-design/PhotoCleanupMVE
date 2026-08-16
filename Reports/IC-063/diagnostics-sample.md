# IC-063 自动几何诊断样例

- 来源：GitHub Actions CI #67，作业 `95195885102`
- 被测提交：`3bb744f4b462d670dce07185ce143f1a59064997`
- 测试：`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`
- 处理：逐字保留 `IC063_DIAGNOSTICS_SAMPLE_BEGIN` 与 `IC063_DIAGNOSTICS_SAMPLE_END` 之间的导出文本，仅移除 GitHub 日志逐行时间戳。

````text
# S2 几何诊断

采样总数：15
中间帧门禁：通过

## V=显示、s=1 稳定态
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=58.950000,y=127.800000,w=275.100000,h=596.400000)
内层照片 bounds=(x=0.000000,y=0.000000,w=275.100000,h=596.400000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
layer.cornerRadius=28.000000, layer.masksToBounds=true
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 单击后 V=隐藏、s=1 稳定态
V=隐藏, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=true, 实际生效隐藏值=true
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 再次单击回 V=显示 稳定态
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=58.950000,y=127.800000,w=275.100000,h=596.400000)
内层照片 bounds=(x=0.000000,y=0.000000,w=275.100000,h=596.400000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
layer.cornerRadius=28.000000, layer.masksToBounds=true
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 双击进入 Nx：动画开始前一帧
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=58.950000,y=127.800000,w=275.100000,h=596.400000)
内层照片 bounds=(x=0.000000,y=0.000000,w=275.100000,h=596.400000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
layer.cornerRadius=28.000000, layer.masksToBounds=true
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 双击进入 Nx：动画中间帧 #1
V=显示, s=2.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=58.950000,y=127.800000,w=275.100000,h=596.400000)
内层照片 bounds=(x=0.000000,y=0.000000,w=275.100000,h=596.400000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.495238,b=0.000000,c=0.000000,d=1.495238,tx=0.000000,ty=0.000000)
layer.cornerRadius=28.000000, layer.masksToBounds=true
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=false;页2:state=0,begin=false

## 双击进入 Nx：动画中间帧 #2
V=显示, s=2.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=58.950000,y=127.800000,w=275.100000,h=596.400000)
内层照片 bounds=(x=0.000000,y=0.000000,w=275.100000,h=596.400000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.990476,b=0.000000,c=0.000000,d=1.990476,tx=0.000000,ty=0.000000)
layer.cornerRadius=28.000000, layer.masksToBounds=true
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=false;页2:state=0,begin=false

## 双击进入 Nx：动画中间帧 #3
V=显示, s=2.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=58.950000,y=127.800000,w=275.100000,h=596.400000)
内层照片 bounds=(x=0.000000,y=0.000000,w=275.100000,h=596.400000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=2.485714,b=0.000000,c=0.000000,d=2.485714,tx=0.000000,ty=0.000000)
layer.cornerRadius=28.000000, layer.masksToBounds=true
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=false;页2:state=0,begin=false

## 双击进入 Nx：动画结束稳定态
V=显示, s=2.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=196.666667,y=426.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=786.000000,h=1704.000000)
contentOffset=(x=196.666667,y=426.000000)
zoomScale=2.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=-196.666667,y=-426.000000,w=786.000000,h=1704.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=false;页2:state=0,begin=false

## 双击退出 Nx：动画开始前一帧
V=显示, s=2.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=196.666667,y=426.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=786.000000,h=1704.000000)
contentOffset=(x=196.666667,y=426.000000)
zoomScale=2.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=-196.666667,y=-426.000000,w=786.000000,h=1704.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=false;页2:state=0,begin=false

## 双击退出 Nx：动画中间帧 #1
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=196.666667,y=426.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=786.000000,h=1704.000000)
contentOffset=(x=196.666667,y=426.000000)
zoomScale=2.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=-196.666667,y=-426.000000,w=786.000000,h=1704.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=0.883552,b=0.000000,c=0.000000,d=0.883552,tx=0.029858,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 双击退出 Nx：动画中间帧 #2
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=196.666667,y=426.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=786.000000,h=1704.000000)
contentOffset=(x=196.666667,y=426.000000)
zoomScale=2.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=-196.666667,y=-426.000000,w=786.000000,h=1704.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=0.759743,b=0.000000,c=0.000000,d=0.759743,tx=0.061604,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 双击退出 Nx：动画中间帧 #3
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=196.666667,y=426.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=786.000000,h=1704.000000)
contentOffset=(x=196.666667,y=426.000000)
zoomScale=2.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=-196.666667,y=-426.000000,w=786.000000,h=1704.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=0.666886,b=0.000000,c=0.000000,d=0.666886,tx=0.085414,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 双击退出 Nx：动画中间帧 #4
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=196.666667,y=426.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=786.000000,h=1704.000000)
contentOffset=(x=196.666667,y=426.000000)
zoomScale=2.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=-196.666667,y=-426.000000,w=786.000000,h=1704.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=0.543076,b=0.000000,c=0.000000,d=0.543076,tx=0.117160,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 双击退出 Nx：动画中间帧 #5
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=196.666667,y=426.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=786.000000,h=1704.000000)
contentOffset=(x=196.666667,y=426.000000)
zoomScale=2.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=-196.666667,y=-426.000000,w=786.000000,h=1704.000000)
内层照片 bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=0.450219,b=0.000000,c=0.000000,d=0.450219,tx=0.140969,ty=0.000000)
layer.cornerRadius=0.000000, layer.masksToBounds=false
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

## 双击退出 Nx：动画结束稳定态
V=显示, s=1.000000
UIScreen.main.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
UIScreen.main.scale=3.000000
window.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.frame=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
scrollView.bounds=(x=0.000000,y=0.000000,w=393.000000,h=852.000000)
view.safeAreaInsets=(top=59.000000,left=0.000000,bottom=34.000000,right=0.000000)
hosting.view.safeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
hosting.additionalSafeAreaInsets=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentInsetAdjustmentBehavior.rawValue=2
contentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
adjustedContentInset=(top=0.000000,left=0.000000,bottom=0.000000,right=0.000000)
contentSize=(w=393.000000,h=852.000000)
contentOffset=(x=0.000000,y=0.000000)
zoomScale=1.000000, minimumZoomScale=1.000000, maximumZoomScale=4.000000
内层照片 window.frame=(x=58.950000,y=127.800000,w=275.100000,h=596.400000)
内层照片 bounds=(x=0.000000,y=0.000000,w=275.100000,h=596.400000)
内层照片 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
专用过渡层 transform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)
layer.cornerRadius=28.000000, layer.masksToBounds=true
资产 pixelWidth=1384, pixelHeight=3000
方向归一照片宽高比=0.461333, 方向归一视口宽高比=0.461268, 差值百分比=0.014249%, 屏幕比例判定=true
状态栏链路=UIHostingController<S2View>=false, 实际生效隐藏值=false
竖向识别器=页0:state=0,begin=false;页1:state=0,begin=true;页2:state=0,begin=false

# 逐题回答
Q1：顶部空白 0.000000px；contentInset=0.000000px，safeAreaInsets=0.000000px，aspectFit=0.000000px；加和=0.000000px。
Q2：s>1 全部样本内层 transform 恒等=true；稳定 Nx zoomScale=2.000000，内层 transform 承载=1.000000 倍，专用过渡层样本倍率=1.495238→1.990476→2.485714→1.000000→1.000000；进入动画原生 zoomScale 恒定=true，退出动画原生 zoomScale 恒定=true；zoomScale 与内层 transform 同时非默认=false。
Q3：双击退出 Nx：动画开始前一帧:offset=(x=196.666667,y=426.000000),innerTransform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000),transitionTransform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000)；双击退出 Nx：动画中间帧 #1:offset=(x=196.666667,y=426.000000),innerTransform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000),transitionTransform=(a=0.883552,b=0.000000,c=0.000000,d=0.883552,tx=0.029858,ty=0.000000)；双击退出 Nx：动画中间帧 #2:offset=(x=196.666667,y=426.000000),innerTransform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000),transitionTransform=(a=0.759743,b=0.000000,c=0.000000,d=0.759743,tx=0.061604,ty=0.000000)；双击退出 Nx：动画中间帧 #3:offset=(x=196.666667,y=426.000000),innerTransform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000),transitionTransform=(a=0.666886,b=0.000000,c=0.000000,d=0.666886,tx=0.085414,ty=0.000000)；双击退出 Nx：动画中间帧 #4:offset=(x=196.666667,y=426.000000),innerTransform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000),transitionTransform=(a=0.543076,b=0.000000,c=0.000000,d=0.543076,tx=0.117160,ty=0.000000)；双击退出 Nx：动画中间帧 #5:offset=(x=196.666667,y=426.000000),innerTransform=(a=1.000000,b=0.000000,c=0.000000,d=1.000000,tx=0.000000,ty=0.000000),transitionTransform=(a=0.450219,b=0.000000,c=0.000000,d=0.450219,tx=0.140969,ty=0.000000)。动画帧内层 transform 恒等=true，专用过渡层 transform 全部六元组分量单调=true，动画帧 contentOffset 无跳变=true；终点只执行一次无动画原生同步。
Q4：V=显示时状态栏隐藏=false；V=隐藏时状态栏隐藏=true。
````
