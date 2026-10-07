import UIKit

/// IC-185 A：隐藏系统导航栏的页面（「逐张整理」年页、「空间清理」类别页）恢复屏幕左缘右滑返回。
///
/// 两页都用 `.toolbar(.hidden, for: .navigationBar)` 隐藏系统导航栏、自绘返回钮；系统导航栏隐藏后
/// `UINavigationController` 自带的左缘右滑手势不再开始（H96 第 3 条，Decision_log 第 218 条）。这里把那只
/// 手势的代理换成导航控制器自己：栈里多于一页、且没有进行中的转场时才允许开始。作用于进程内全部
/// `UINavigationController`；只有一页的栈（两个 tab 的根页、相簿 sheet）条件恒假，不受影响。
/// 右滑返回把 `navigationDestination(item:)` 的 item 置空：年页走 `S1StateMachine.dismissYearPage()`，
/// 类别页走流程容器 `.onChange(of: flowModel.presentedCategory)` 的同一段收尾。
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && transitionCoordinator == nil
    }
}
