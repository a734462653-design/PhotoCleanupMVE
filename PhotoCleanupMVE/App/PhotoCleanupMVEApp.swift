import Foundation
import SwiftUI

@main
struct PhotoCleanupMVEApp: App {
    @StateObject private var coordinator = CleanupCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                switch coordinator.route {
                case .loading:
                    ProgressView("正在读取测试资产")
                case .confirmation:
                    S3View(coordinator: coordinator)
                case .execution:
                    S4View(coordinator: coordinator)
                case .completion:
                    S5View(coordinator: coordinator)
                case .finished:
                    Text("本次清理会话已结束")
                }
            }
            .onAppear {
                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                    coordinator.start()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    coordinator.setApplicationActive(true)
                case .inactive, .background:
                    coordinator.setApplicationActive(false)
                @unknown default:
                    coordinator.setApplicationActive(false)
                }
            }
        }
    }
}
