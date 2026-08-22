import Photos
import SwiftUI
import UIKit

/// IC-077（v15 回写决策 28）：一次图片请求的可区分结果。`cancelled` 由翻页取消产生，
/// 不算失败；`assetUnavailable` 为资产失效（`fetchAssets` 为空），与失败同态呈现。
enum S2ImageRequestResult: Equatable {
    case degradedPreview(UIImage)
    case finalImage(UIImage)
    case failure
    case cancelled
    case assetUnavailable

    var image: UIImage? {
        switch self {
        case let .degradedPreview(image), let .finalImage(image):
            return image
        case .failure, .cancelled, .assetUnavailable:
            return nil
        }
    }

    var isDegraded: Bool {
        if case .degradedPreview = self {
            return true
        }
        return false
    }
}

protocol S2PhotoImageRequesting: AnyObject {
    @discardableResult
    func requestImage(
        assetID: String,
        targetSize: CGSize,
        requestStrategy: S2ImageRequestStrategy,
        resultHandler: @escaping (S2ImageRequestResult) -> Void
    ) -> PHImageRequestID

    func cancelImageRequest(_ requestID: PHImageRequestID)
}

// 类型名与文件名沿用 IC-048 临时接线时的命名（改名留给后续清理卡）；
// 行为自 IC-077 起按 SPEC-S2 v15 回写决策 28 实装：允许网络访问（iCloud 按需下载）、
// 降质预览先显示、最终图原位替换、失败与资产失效可区分。
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
        resultHandler: @escaping (S2ImageRequestResult) -> Void
    ) -> PHImageRequestID {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        )
        guard let asset = result.firstObject else {
            resultHandler(.assetUnavailable)
            return PHInvalidImageRequestID
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        // ④ Lynn 2026-08-22：允许从 iCloud 按需下载；下载期间按加载中处理。
        options.isNetworkAccessAllowed = true
        // v15 决策 28：降质预览先显示，最终图到达后原位替换。
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.version = .current

        return manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, information in
            resultHandler(
                Self.result(image: image, information: information)
            )
        }
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        guard requestID != PHInvalidImageRequestID else {
            return
        }
        manager.cancelImageRequest(requestID)
    }

    /// PhotoKit 回调到可区分结果的映射：取消 → `cancelled`；无图像（含错误）→ `failure`；
    /// 降质标记 → `degradedPreview`；其余 → `finalImage`。
    static func result(
        image: UIImage?,
        information: [AnyHashable: Any]?
    ) -> S2ImageRequestResult {
        if information?[PHImageCancelledKey] as? Bool == true {
            return .cancelled
        }
        guard let image else {
            return .failure
        }
        let isDegraded = information?[PHImageResultIsDegradedKey] as? Bool ?? false
        return isDegraded ? .degradedPreview(image) : .finalImage(image)
    }
}

struct S2TemporaryPhotoImageView: View {
    let strategy: any S2PhotoImageRequesting
    let assetID: String
    var requestBaseSize: CGSize? = nil
    let requestedScale: CGFloat
    let requestStrategy: S2ImageRequestStrategy?
    let requestRevision: Int
    var contentMode: ContentMode = .fit
    let showsOpaqueLoadingBackground: Bool
    let onReading: (S2ImageRequestReading) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var displayedAssetID: String?
    @State private var requestID = PHInvalidImageRequestID
    @State private var requestGeneration = 0

    var body: some View {
        GeometryReader { geometry in
            let key = requestKey(for: requestBaseSize ?? geometry.size)
            ZStack {
                if showsOpaqueLoadingBackground {
                    Color.black
                }
                if let image, displayedAssetID == assetID {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
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
            .onChange(of: requestRevision) { oldRevision, newRevision in
                guard newRevision > oldRevision else {
                    return
                }
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
        ) { result in
            DispatchQueue.main.async {
                guard requestGeneration == generation,
                      result != .cancelled else {
                    return
                }
                let nextImage = result.image
                let isDegraded = result.isDegraded
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
