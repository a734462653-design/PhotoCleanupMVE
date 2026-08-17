import Foundation
import Photos
import SwiftUI
import UIKit

@main
struct PhotoCleanupMVEApp: App {
    @StateObject private var coordinator = CleanupCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    private let s2PhotoImageStrategy = S2TemporaryPhotoKitImageStrategy()
    private let isIC067ScreenshotSubtypeProbe = ProcessInfo.processInfo
        .arguments
        .contains("--ic067-screenshot-subtype-probe")

    var body: some Scene {
        WindowGroup {
            Group {
#if DEBUG
                if isIC067ScreenshotSubtypeProbe {
                    IC067ScreenshotSubtypeProbeView()
                } else {
#endif
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
                                        requestBaseSize:
                                            context.requestBaseSize,
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
#if DEBUG
                }
#endif
            }
            .onAppear {
                if !isIC067ScreenshotSubtypeProbe,
                   ProcessInfo.processInfo.environment[
                    "XCTestConfigurationFilePath"
                   ] == nil {
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

#if DEBUG
private struct IC067ScreenshotSubtypeProbeView: View {
    @State private var didStart = false
    @State private var result = "IC067_G38_RUNNING"

    var body: some View {
        Text(verbatim: result)
            .onAppear {
                guard !didStart else {
                    return
                }
                didStart = true
                IC067ScreenshotSubtypeProbe.run { value in
                    persist(value)
                }
            }
    }

    private func persist(_ value: String) {
        guard let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return
        }
        let url = directory.appendingPathComponent(
            "ic067-g38-probe.txt"
        )
        try? value.write(to: url, atomically: true, encoding: .utf8)
        DispatchQueue.main.async {
            result = value
        }
    }
}

private enum IC067ScreenshotSubtypeProbe {
    static func run(completion: @escaping (String) -> Void) {
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(
            for: .readWrite
        )
        guard authorizationStatus == .authorized else {
            completion(
                "IC067_G38_ERROR stage=authorization " +
                    "status=\(authorizationStatus.rawValue)"
            )
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var screenshot: PHAsset?
        assets.enumerateObjects { asset, _, stop in
            guard asset.mediaSubtypes.contains(.photoScreenshot) else {
                return
            }
            screenshot = asset
            stop.pointee = true
        }
        guard let original = screenshot else {
            completion("IC067_G38_ERROR stage=fetch-screenshot")
            return
        }
        let beforeSubtypes = original.mediaSubtypes.rawValue

        let inputOptions = PHContentEditingInputRequestOptions()
        inputOptions.isNetworkAccessAllowed = false
        original.requestContentEditingInput(with: inputOptions) { input, _ in
            guard let input,
                  let sourceURL = input.fullSizeImageURL,
                  let sourceImage = UIImage(contentsOfFile: sourceURL.path)
            else {
                completion("IC067_G38_ERROR stage=editing-input")
                return
            }

            let cropSize = CGSize(
                width: max(1, floor(sourceImage.size.width * 0.2)),
                height: sourceImage.size.height
            )
            let cropOrigin = CGPoint(
                x: floor((sourceImage.size.width - cropSize.width) / 2),
                y: 0
            )
            let rendered = UIGraphicsImageRenderer(size: cropSize).image {
                _ in
                sourceImage.draw(
                    at: CGPoint(x: -cropOrigin.x, y: -cropOrigin.y)
                )
            }
            guard let renderedData = rendered.jpegData(
                compressionQuality: 1
            ) else {
                completion("IC067_G38_ERROR stage=render")
                return
            }

            let output = PHContentEditingOutput(contentEditingInput: input)
            do {
                try renderedData.write(
                    to: output.renderedContentURL,
                    options: .atomic
                )
            } catch {
                completion("IC067_G38_ERROR stage=write-rendered")
                return
            }
            output.adjustmentData = PHAdjustmentData(
                formatIdentifier:
                    "com.iphonephotomanagement.ic067-probe",
                formatVersion: "1",
                data: Data("{\"cropWidthRatio\":0.2}".utf8)
            )

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: original).contentEditingOutput =
                    output
            } completionHandler: { success, _ in
                guard success,
                      let edited = PHAsset.fetchAssets(
                        withLocalIdentifiers: [original.localIdentifier],
                        options: nil
                      ).firstObject
                else {
                    completion("IC067_G38_ERROR stage=apply-edit")
                    return
                }
                completion(
                    "IC067_G38_PROBE " +
                        "authorizationStatus=" +
                        "\(authorizationStatus.rawValue) " +
                        "beforeSubtypes=\(beforeSubtypes) " +
                        "afterSubtypes=\(edited.mediaSubtypes.rawValue) " +
                        "renderedSize=\(Int(cropSize.width))x" +
                        "\(Int(cropSize.height)) " +
                        "afterIsScreenshot=" +
                        "\(edited.mediaSubtypes.contains(.photoScreenshot))"
                )
            }
        }
    }
}
#endif
