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

/// IC-077（v15 回写决策 28）：单张照片内容的加载态。
/// - `loading`：无可用图像，显示视口背景，不显示进度指示；
/// - `displayed`：已有图像（降质或最终），最终图到达时原位替换；
/// - `failed`：请求以失败或资产失效结束且没有可显示的图像——视口中心显示
///   `photo.badge.exclamationmark` 与一行文案，不提供重试；取消不进入此态。
enum S2ImageLoadState: Equatable {
    case loading
    case displayed
    case failed
}

struct S2TemporaryPhotoImageView: View {
    static let failureSymbolName = "photo.badge.exclamationmark"

    let strategy: any S2PhotoImageRequesting
    let assetID: String
    var requestBaseSize: CGSize? = nil
    let requestedScale: CGFloat
    let requestStrategy: S2ImageRequestStrategy?
    let requestRevision: Int
    var contentMode: ContentMode = .fit
    /// 主图路径为 true：加载中显示视口背景、失败时显示失败态浮层；横栏缩略图为 false。
    let showsOpaqueLoadingBackground: Bool
    let onReading: (S2ImageRequestReading) -> Void
    var onLoadStateChange: (S2ImageLoadState) -> Void = { _ in }
    /// IC-090 R2：每次请求返回的原始 `S2ImageRequestResult`（含 `cancelled`），仅供诊断埋点。
    var onRequestResult: (S2ImageRequestResult) -> Void = { _ in }
    /// IC-090 R2：真正发生图片替换时回调（`shouldDisplay` 通过且有图），仅供诊断埋点。
    var onImageReplaced: (S2ImageRequestResult) -> Void = { _ in }

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var displayedAssetID: String?
    @State private var loadState = S2ImageLoadState.loading
    @State private var requestID = PHInvalidImageRequestID
    @State private var requestGeneration = 0

    var body: some View {
        GeometryReader { geometry in
            let key = requestKey(for: requestBaseSize ?? geometry.size)
            ZStack {
                if showsOpaqueLoadingBackground {
                    S2ViewportBackground.color
                }
                if let image, displayedAssetID == assetID {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
                if showsOpaqueLoadingBackground, loadState == .failed {
                    failureOverlay
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

    /// 失败态浮层：不参与照片几何、不接收点击；该照片的标记、翻页、缩放手势照常。
    private var failureOverlay: some View {
        VStack(spacing: S2OverlayLayout.minimumSpacing) {
            Image(systemName: Self.failureSymbolName)
                .font(.largeTitle)
            Text(L10n.text("s2.image.load_failed"))
                .font(.footnote)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private func setLoadState(_ nextState: S2ImageLoadState) {
        guard loadState != nextState else {
            return
        }
        loadState = nextState
        onLoadStateChange(nextState)
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
        let requestedAssetID = assetID
        let hasDisplayedImage = image != nil && displayedAssetID == assetID
        setLoadState(hasDisplayedImage ? .displayed : .loading)
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
                guard requestGeneration == generation else {
                    return
                }
                onRequestResult(result)
                let returnType: S2ImageReturnType
                switch result {
                case .cancelled:
                    // 取消（翻页导致）不算失败：不记读数、不改显示。
                    return
                case .assetUnavailable:
                    returnType = .assetUnavailable
                case .failure:
                    returnType = .failure
                case .degradedPreview:
                    returnType = .degradedPreview
                case .finalImage:
                    returnType = .finalImage
                }
                onReading(S2ImageRequestReading(
                    trigger: trigger,
                    returnType: returnType
                ))
                guard let nextImage = result.image else {
                    // 已有可显示图像时保留它（例如更高分辨率请求失败），否则进入失败态。
                    let stillDisplayed = image != nil &&
                        displayedAssetID == requestedAssetID
                    setLoadState(stillDisplayed ? .displayed : .failed)
                    return
                }
                guard S2ImageRequestDecision.shouldDisplay(
                    isDegraded: result.isDegraded,
                    strategy: activeStrategy
                ) else {
                    return
                }
                image = nextImage
                displayedAssetID = requestedAssetID
                onImageReplaced(result)
                setLoadState(.displayed)
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
