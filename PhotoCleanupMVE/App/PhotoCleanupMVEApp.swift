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
                    ProgressView(L10n.text("app.loading.test_assets"))
                case .confirmation:
                    S3View(coordinator: coordinator)
                case .execution:
                    S4View(coordinator: coordinator)
                case .completion:
                    S5View(coordinator: coordinator)
                case .finished:
                    Text(L10n.text("app.session.finished"))
                case .upstream:
                    EmptyView()
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
