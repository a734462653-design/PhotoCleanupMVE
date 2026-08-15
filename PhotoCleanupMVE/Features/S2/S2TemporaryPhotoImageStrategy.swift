import Photos
import SwiftUI
import UIKit

protocol S2PhotoImageRequesting: AnyObject {
    @discardableResult
    func requestImage(
        assetID: String,
        targetSize: CGSize,
        requestStrategy: S2ImageRequestStrategy,
        resultHandler: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID

    func cancelImageRequest(_ requestID: PHImageRequestID)
}

// SPEC-S2 v13 未定项 8 的临时占位实现，仅用于 IC-048 真机接线，不是定案。
final class S2TemporaryPhotoKitImageStrategy: S2PhotoImageRequesting {
    private let manager: PHImageManager

    init(manager: PHImageManager = PHImageManager.default()) {
        self.manager = manager
    }

    @discardableResult
    func requestImage(
        assetID: String,
        targetSize: CGSize,
        requestStrategy: S2ImageRequestStrategy,
        resultHandler: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        )
        guard let asset = result.firstObject else {
            resultHandler(nil, false)
            return PHInvalidImageRequestID
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false
        options.deliveryMode = requestStrategy.degradedPreviewPolicy == .display
            ? .opportunistic
            : .highQualityFormat
        options.resizeMode = .fast
        options.version = .current

        return manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, information in
            let isDegraded = information?[PHImageResultIsDegradedKey]
                as? Bool ?? false
            resultHandler(image, isDegraded)
        }
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        guard requestID != PHInvalidImageRequestID else {
            return
        }
        manager.cancelImageRequest(requestID)
    }
}

struct S2TemporaryPhotoImageView: View {
    let strategy: any S2PhotoImageRequesting
    let assetID: String
    let requestedScale: CGFloat
    let requestStrategy: S2ImageRequestStrategy?
    let requestRevision: Int
    let showsOpaqueLoadingBackground: Bool
    let onReading: (S2ImageRequestReading) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var displayedAssetID: String?
    @State private var requestID = PHInvalidImageRequestID
    @State private var requestGeneration = 0

    var body: some View {
        GeometryReader { geometry in
            let key = requestKey(for: geometry.size)
            ZStack {
                if showsOpaqueLoadingBackground {
                    Color.black
                }
                if let image, displayedAssetID == assetID {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .onAppear {
                requestImage(for: key, trigger: .initial)
            }
            .onChange(of: key) { oldKey, newKey in
                let trigger: S2ImageRequestTrigger
                if oldKey.assetID != newKey.assetID {
                    trigger = .assetChange
                } else if oldKey.viewportWidth != newKey.viewportWidth ||
                            oldKey.viewportHeight != newKey.viewportHeight {
                    trigger = .viewportChange
                } else {
                    trigger = .scaleChange
                }
                requestImageIfNeeded(for: newKey, trigger: trigger)
            }
            .onChange(of: requestRevision) { _, _ in
                requestImageIfNeeded(for: key, trigger: .pinchEnded)
            }
            .onChange(of: requestStrategy) { _, _ in
                requestImageIfNeeded(for: key, trigger: .strategyChange)
            }
            .onDisappear {
                strategy.cancelImageRequest(requestID)
                requestID = PHInvalidImageRequestID
            }
        }
    }

    private func requestKey(for size: CGSize) -> RequestKey {
        let multiplier = displayScale * max(1, requestedScale)
        return RequestKey(
            assetID: assetID,
            viewportWidth: max(1, Int((size.width * displayScale).rounded(.up))),
            viewportHeight: max(1, Int((size.height * displayScale).rounded(.up))),
            width: max(1, Int((size.width * multiplier).rounded(.up))),
            height: max(1, Int((size.height * multiplier).rounded(.up)))
        )
    }

    private var effectiveStrategy: S2ImageRequestStrategy {
        requestStrategy ??
            S2CalibrationConfiguration.factoryPlaceholder.imageRequestStrategy
    }

    private func requestImageIfNeeded(
        for key: RequestKey,
        trigger: S2ImageRequestTrigger
    ) {
        guard S2ImageRequestDecision.shouldRequest(
            for: trigger,
            strategy: effectiveStrategy
        ) else {
            return
        }
        requestImage(for: key, trigger: trigger)
    }

    private func requestImage(
        for key: RequestKey,
        trigger: S2ImageRequestTrigger
    ) {
        strategy.cancelImageRequest(requestID)
        requestGeneration += 1
        let generation = requestGeneration
        let activeStrategy = effectiveStrategy
        onReading(S2ImageRequestReading(trigger: trigger, returnType: .pending))
        requestID = strategy.requestImage(
            assetID: assetID,
            targetSize: CGSize(
                width: CGFloat(key.width),
                height: CGFloat(key.height)
            ),
            requestStrategy: activeStrategy
        ) { nextImage, isDegraded in
            DispatchQueue.main.async {
                guard requestGeneration == generation else {
                    return
                }
                let returnType: S2ImageReturnType
                if nextImage == nil {
                    returnType = .failure
                } else if isDegraded {
                    returnType = .degradedPreview
                } else {
                    returnType = .finalImage
                }
                onReading(S2ImageRequestReading(
                    trigger: trigger,
                    returnType: returnType
                ))
                guard let nextImage,
                      S2ImageRequestDecision.shouldDisplay(
                          isDegraded: isDegraded,
                          strategy: activeStrategy
                      ) else {
                    return
                }
                image = nextImage
                displayedAssetID = assetID
            }
        }
    }

    private struct RequestKey: Equatable {
        let assetID: String
        let viewportWidth: Int
        let viewportHeight: Int
        let width: Int
        let height: Int
    }
}
