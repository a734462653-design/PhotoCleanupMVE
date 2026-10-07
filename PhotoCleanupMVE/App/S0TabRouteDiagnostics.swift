import Combine
import UIKit

/// IC-185 B：tab 落点诊断（Decision_log 第 218 条：从「逐张整理」进 S2 再左上退出，有时落到「空间清理」tab，根因 ③ 未定位）。
///
/// 记三类事件的时间线：路由变化、tab 容器出现（连同当时模型的选中态、写入计数与 UIKit 层 `UITabBarController` 的选中下标）、
/// tab 选择态的每次写入（旧 → 新）。只记、不改任何行为。文本全 ASCII，接在 S2 标定面板「S2 退出诊断」末尾（进 S2 那一刻取一次）：
/// 复现之后再进一次 S2、长按顶部中胶囊复制即可。两种形状：(i) 容器出现前后紧跟一条 `write organize->cleanup`——系统经
/// binding 回写；(ii) 没有这条写入、`appear tab=organize`，而 `uikit=0`（第一个 tab）——系统没按 binding 初值选中。
final class S0TabRouteDiagnostics: ObservableObject {
    static let format = "format=ic185-tab-v1"
    static let maximumEvents = 24
    static let unavailable = "na"

    private(set) var events: [String] = []
    private let startUptime = ProcessInfo.processInfo.systemUptime

    func note(_ event: String) {
        let milliseconds = Int((ProcessInfo.processInfo.systemUptime - startUptime) * 1000)
        events.append("t=" + String(milliseconds) + " " + event)
        if events.count > Self.maximumEvents {
            events.removeFirst(events.count - Self.maximumEvents)
        }
    }

    var text: String {
        ([Self.format] + events).joined(separator: "\n")
    }

    /// 当前各窗口里第一个 `UITabBarController` 的选中下标；取不到给 `unavailable`（SwiftUI `TabView` 在 iOS 26 是否仍由它承载 ③）。
    @MainActor
    static func uikitSelectedTabIndex() -> String {
        let roots = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .compactMap { $0.rootViewController }
        for root in roots {
            if let tabBar = tabBarController(in: root) {
                return String(tabBar.selectedIndex)
            }
        }
        return unavailable
    }

    @MainActor
    private static func tabBarController(in root: UIViewController) -> UITabBarController? {
        if let tabBar = root as? UITabBarController {
            return tabBar
        }
        for child in root.children {
            if let found = tabBarController(in: child) {
                return found
            }
        }
        return nil
    }
}

extension Optional where Wrapped == String {
    /// IC-185 B：把 tab 时间线接在 S2 退出诊断之后（退出诊断为空时只给时间线）。
    func withTabDiagnostics(_ tabText: String) -> String {
        guard let exitText = self else {
            return tabText
        }
        return exitText + "\n" + tabText
    }
}
