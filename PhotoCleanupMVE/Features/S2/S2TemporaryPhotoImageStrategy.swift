import Photos
import SwiftUI
import UIKit

protocol S2PhotoImageRequesting: AnyObject {
    @discardableResult
    func requestImage(
        assetID: String,
        targetSize: CGSize,
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
        options.deliveryMode = .highQualityFormat
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

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var displayedAssetID: String?
    @State private var requestID = PHInvalidImageRequestID
    @State private var requestGeneration = 0

    var body: some View {
        GeometryReader { geometry in
            let key = requestKey(for: geometry.size)
            ZStack {
                Color.black
                if let image, displayedAssetID == assetID {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .onAppear {
                requestImage(for: key)
            }
            .onChange(of: key) { _, newKey in
                guard requestStrategy?.scaleChangePolicy ==
                        .everyScaleChange else {
                    return
                }
                requestImage(for: newKey)
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
            width: max(1, Int((size.width * multiplier).rounded(.up))),
            height: max(1, Int((size.height * multiplier).rounded(.up)))
        )
    }

    private func requestImage(for key: RequestKey) {
        strategy.cancelImageRequest(requestID)
        requestGeneration += 1
        let generation = requestGeneration
        requestID = strategy.requestImage(
            assetID: assetID,
            targetSize: CGSize(
                width: CGFloat(key.width),
                height: CGFloat(key.height)
            )
        ) { nextImage, isDegraded in
            DispatchQueue.main.async {
                guard requestGeneration == generation,
                      let nextImage,
                      !isDegraded || requestStrategy?.degradedPreviewPolicy ==
                        .display else {
                    return
                }
                image = nextImage
                displayedAssetID = assetID
            }
        }
    }

    private struct RequestKey: Equatable {
        let assetID: String
        let width: Int
        let height: Int
    }
}
