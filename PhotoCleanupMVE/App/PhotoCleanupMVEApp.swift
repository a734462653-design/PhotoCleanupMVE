import Foundation
import Photos
import SwiftUI
import UIKit

@main
struct PhotoCleanupMVEApp: App {
    @StateObject private var coordinator = CleanupCoordinator()
    @Environment(\.scenePhase) private var scenePhase
#if DEBUG
    @State private var ic067ScreenshotSubtypeProbeResult =
        "IC067_G38_PENDING"
#endif
    private let s2PhotoImageStrategy = S2TemporaryPhotoKitImageStrategy()
    private let isIC067ScreenshotSubtypeProbe = ProcessInfo.processInfo
        .arguments
        .contains("--ic067-screenshot-subtype-probe")
    private let isIC067RealInteractionProbe = ProcessInfo.processInfo
        .arguments
        .contains("--ic067-real-interaction-probe")

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
                            assetIsScreenshot:
                                coordinator.s2AssetIsScreenshot,
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
            }
#if DEBUG
            .overlay {
                if isIC067RealInteractionProbe {
                    IC067RealInteractionProbeView()
                }
            }
            .overlay(alignment: .topLeading) {
                if isIC067ScreenshotSubtypeProbe {
                    Text(ic067ScreenshotSubtypeProbeResult)
                        .font(.caption2)
                        .accessibilityIdentifier("ic067.g38.probe.result")
                }
            }
#endif
            .onAppear {
#if DEBUG
                if isIC067ScreenshotSubtypeProbe {
                    IC067ScreenshotSubtypeProbe.runAndPersist { value in
                        DispatchQueue.main.async {
                            ic067ScreenshotSubtypeProbeResult = value
                        }
                    }
                } else if !isIC067RealInteractionProbe &&
                    ProcessInfo.processInfo.environment[
                    "XCTestConfigurationFilePath"
                   ] == nil {
                    coordinator.start()
                }
#else
                if ProcessInfo.processInfo.environment[
                    "XCTestConfigurationFilePath"
                ] == nil {
                    coordinator.start()
                }
#endif
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
private struct IC067RealInteractionProbeView: View {
    @StateObject private var machine: S2StateMachine
    @StateObject private var calibration: S2CalibrationModel
    @StateObject private var diagnostics: S2GeometryDiagnosticsCoordinator

    init() {
        _machine = StateObject(
            wrappedValue: S2PreviewData.machine(for: .visibleOneXIdle)
        )
        _calibration = StateObject(
            wrappedValue: S2CalibrationModel(
                persistence: S2DiscardingCalibrationPersistence()
            )
        )
        _diagnostics = StateObject(
            wrappedValue: S2GeometryDiagnosticsCoordinator(
                capturesRealInteractions: true
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let aspectRatio = geometry.size.height > 0
                ? geometry.size.width / geometry.size.height
                : 1
            ZStack(alignment: .topLeading) {
                S2View(
                    machine: machine,
                    calibration: calibration,
                    assetAspectRatio: { _ in aspectRatio },
                    assetIsScreenshot: { _ in true },
                    assetPixelSize: { _ in
                        CGSize(
                            width: geometry.size.width * 3,
                            height: geometry.size.height * 3
                        )
                    },
                    photoContent: { _ in AnyView(Color.gray) },
                    stripItemContent: { _ in AnyView(Color.clear) },
                    albumPickerContent: { _, _ in AnyView(EmptyView()) },
                    geometryDiagnostics: diagnostics
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("ic067.interaction.viewport")

                Text(verbatim: diagnostics.realInteractionReportText)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(.black.opacity(0.8))
                    .accessibilityIdentifier("ic067.interaction.result")
                    .allowsHitTesting(false)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea()
    }
}

private enum IC067ScreenshotSubtypeProbe {
    static func runAndPersist(
        completion: @escaping (String) -> Void
    ) {
        run { value in
            persist(value)
            completion(value)
        }
    }

    private static func persist(_ value: String) {
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
    }

    static func run(completion: @escaping (String) -> Void) {
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(
            for: .readWrite
        )
        if authorizationStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                guard status != .notDetermined else {
                    completion(
                        "IC067_G38_ERROR stage=authorization " +
                            "status=\(status.rawValue)"
                    )
                    return
                }
                run(completion: completion)
            }
            return
        }
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
