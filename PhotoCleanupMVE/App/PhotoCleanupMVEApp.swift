import Foundation
import SwiftUI

@main
struct PhotoCleanupMVEApp: App {
    @StateObject private var coordinator = CleanupCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    private let s2PhotoImageStrategy = S2TemporaryPhotoKitImageStrategy()

    var body: some Scene {
        WindowGroup {
            Group {
                switch coordinator.route {
                case .loading:
                    ProgressView(L10n.text("app.loading.photo_library"))
                case .s1, .upstream, .finished:
                    if let machine = coordinator.s1Machine {
                        S1View(
                            machine: machine,
                            rangeReader: coordinator.readS1Ranges,
                            onS2Handoff: { handoff in
                                _ = coordinator.enterS2(from: handoff)
                            },
                            onS3Submission: { submission in
                                _ = coordinator.enterConfirmationFromS1(
                                    submission
                                )
                            }
                        )
                    } else {
                        ProgressView()
                    }
                case .s2:
                    if let machine = coordinator.s2Machine {
                        S2View(
                            machine: machine,
                            calibration: coordinator.s2Calibration,
                            assetAspectRatio: coordinator.s2AssetAspectRatio,
                            assetPixelSize: coordinator.s2AssetPixelSize,
                            photoContent: { context in
                                AnyView(
                                    S2TemporaryPhotoImageView(
                                        strategy: s2PhotoImageStrategy,
                                        assetID: context.assetID,
                                        requestedScale: context.scale,
                                        requestStrategy:
                                            context.requestStrategy,
                                        requestRevision:
                                            context.requestRevision,
                                        contentMode: context.contentMode,
                                        showsOpaqueLoadingBackground: true,
                                        onReading:
                                            context.onRequestReading
                                    )
                                )
                            },
                            stripItemContent: { item in
                                AnyView(
                                    S2TemporaryPhotoImageView(
                                        strategy: s2PhotoImageStrategy,
                                        assetID: item.assetID,
                                        requestedScale: 1,
                                        requestStrategy: nil,
                                        requestRevision: 0,
                                        showsOpaqueLoadingBackground: false,
                                        onReading: { _ in }
                                    )
                                )
                            },
                            albumPickerContent: { _, actions in
                                AnyView(
                                    Button(L10n.text("s2.action.cancel")) {
                                        actions.cancel()
                                    }
                                )
                            },
                            onBack: { payload in
                                _ = coordinator.leaveS2(with: payload)
                            },
                            onConfirmation: { payload in
                                _ = coordinator.enterConfirmationFromS2(
                                    with: payload
                                )
                            }
                        )
                    } else {
                        ProgressView()
                    }
                case .confirmation:
                    S3View(coordinator: coordinator)
                case .execution:
                    S4View(coordinator: coordinator)
                case .completion:
                    S5View(coordinator: coordinator)
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
