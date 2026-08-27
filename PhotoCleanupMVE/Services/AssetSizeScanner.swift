import AVFoundation
import Foundation
import Photos
import QuartzCore

struct AssetSizeScanner {
    func scan(_ asset: PHAsset) async -> AssetScanConclusion {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else {
            return .unavailable
        }

        var total: Int64 = 0
        for resource in resources {
            guard let bytes = await bytes(of: resource) else {
                return .unavailable
            }
            let addition = total.addingReportingOverflow(bytes)
            guard !addition.overflow else {
                return .unavailable
            }
            total = addition.partialValue
        }
        return .knownBytes(total)
    }

    private func bytes(of resource: PHAssetResource) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            let accumulator = ByteAccumulator()

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    accumulator.append(data.count)
                },
                completionHandler: { error in
                    continuation.resume(
                        returning: error == nil ? accumulator.result : nil
                    )
                }
            )
        }
    }
}
private final class ByteAccumulator {
    private let lock = NSLock()
    private var bytes: Int64 = 0
    private var overflowed = false

    var result: Int64? {
        lock.lock()
        defer { lock.unlock() }
        return overflowed ? nil : bytes
    }

    func append(_ count: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard !overflowed else {
            return
        }
        let addition = bytes.addingReportingOverflow(Int64(count))
        bytes = addition.partialValue
        overflowed = addition.overflow
    }
}

/// IC-099b R2：字节数探针的 PhotoKit 实现。
///
/// 只由 S2 调试面板的按钮触发，**不参与任何产品图片请求路径**——
/// `S2TemporaryPhotoImageStrategy` 与 `PHImageManager.requestImage*` 的产品调用点一字未动。
/// **不使用任何 KVC 私有键**（卡内明令，探针内同样禁止）。
///
/// 两条途径都禁网络（`isNetworkAccessAllowed = false`），只量本地可得的字节数：
/// - **URL 途径**：照片 `requestContentEditingInput` → `fullSizeImageURL` 的文件属性；
///   视频 `requestAVAsset` → `AVURLAsset.url` 的文件属性。语义是**当前版本**。
/// - **数据途径**：主资源 `requestData` 流式累加，只累加 `data.count`、不留数据。
///   主资源优先取**原始**类型（`.photo` / `.video`），因此已编辑资产上
///   两途径的差值即「当前版本 vs 原资源」的语义差实测值。
final class AssetSizeProbeService: S2AssetSizeProbing {
    private enum Outcome {
        case bytes(Int64)
        case failure(S2AssetSizeProbeFailure)
    }

    private let assets: [String: PHAsset]

    init(assets: [String: PHAsset]) {
        self.assets = assets
    }

    func measure(assetID: String) async -> S2AssetSizeProbeMeasurement {
        guard let asset = assets[assetID] else {
            return S2AssetSizeProbeMeasurement(
                assetID: assetID,
                mediaKind: .photo,
                isEdited: false,
                urlByteCount: nil,
                urlFailure: .assetUnavailable,
                urlElapsedMilliseconds: 0,
                dataByteCount: nil,
                dataFailure: .assetUnavailable,
                dataElapsedMilliseconds: 0
            )
        }

        let mediaKind = Self.mediaKind(of: asset)
        let resources = PHAssetResource.assetResources(for: asset)
        let isEdited = resources.contains { $0.type == .adjustmentData }

        let urlStartedAt = CACurrentMediaTime()
        let urlResult = await measureURLRoute(for: asset, mediaKind: mediaKind)
        let urlElapsed = (CACurrentMediaTime() - urlStartedAt) * 1_000

        let dataStartedAt = CACurrentMediaTime()
        let dataResult = await measureDataRoute(
            resources: resources,
            mediaKind: mediaKind
        )
        let dataElapsed = (CACurrentMediaTime() - dataStartedAt) * 1_000

        return S2AssetSizeProbeMeasurement(
            assetID: assetID,
            mediaKind: mediaKind,
            isEdited: isEdited,
            urlByteCount: Self.byteCount(of: urlResult),
            urlFailure: Self.failure(of: urlResult),
            urlElapsedMilliseconds: urlElapsed,
            dataByteCount: Self.byteCount(of: dataResult),
            dataFailure: Self.failure(of: dataResult),
            dataElapsedMilliseconds: dataElapsed
        )
    }

    // MARK: - URL 途径

    private func measureURLRoute(
        for asset: PHAsset,
        mediaKind: S2AssetSizeProbeMediaKind
    ) async -> Outcome {
        if mediaKind == .video {
            return await videoURLOutcome(for: asset)
        }
        return await photoURLOutcome(for: asset)
    }

    private func photoURLOutcome(for asset: PHAsset) async -> Outcome {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = false
            let resumer = ContinuationResumer()

            _ = asset.requestContentEditingInput(with: options) { input, info in
                guard resumer.claim() else {
                    return
                }
                if let cancelled = info[PHContentEditingInputCancelledKey]
                    as? Bool, cancelled {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                if let inCloud = info[PHContentEditingInputResultIsInCloudKey]
                    as? Bool, inCloud {
                    continuation.resume(returning: .failure(.notLocal))
                    return
                }
                if info[PHContentEditingInputErrorKey] != nil {
                    continuation.resume(returning: .failure(.requestFailed))
                    return
                }
                guard let url = input?.fullSizeImageURL else {
                    continuation.resume(returning: .failure(.noURL))
                    return
                }
                continuation.resume(returning: Self.fileOutcome(at: url))
            }
        }
    }

    private func videoURLOutcome(for asset: PHAsset) async -> Outcome {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            let resumer = ContinuationResumer()

            _ = PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, info in
                guard resumer.claim() else {
                    return
                }
                if let cancelled = info?[PHImageCancelledKey] as? Bool,
                   cancelled {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                if let inCloud = info?[PHImageResultIsInCloudKey] as? Bool,
                   inCloud {
                    continuation.resume(returning: .failure(.notLocal))
                    return
                }
                if info?[PHImageErrorKey] != nil {
                    continuation.resume(returning: .failure(.requestFailed))
                    return
                }
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(returning: .failure(.noURL))
                    return
                }
                continuation.resume(
                    returning: Self.fileOutcome(at: urlAsset.url)
                )
            }
        }
    }

    private static func fileOutcome(at url: URL) -> Outcome {
        guard let size = try? url.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize else {
            return .failure(.fileAttributeUnavailable)
        }
        return .bytes(Int64(size))
    }

    // MARK: - 数据途径（语义基准，仅探针内使用）

    private func measureDataRoute(
        resources: [PHAssetResource],
        mediaKind: S2AssetSizeProbeMediaKind
    ) async -> Outcome {
        guard let resource = Self.primaryResource(
            in: resources,
            mediaKind: mediaKind
        ) else {
            return .failure(.resourceUnavailable)
        }
        return await streamedOutcome(of: resource)
    }

    private func streamedOutcome(of resource: PHAssetResource) async -> Outcome {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            let accumulator = ByteAccumulator()
            let resumer = ContinuationResumer()

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    accumulator.append(data.count)
                },
                completionHandler: { error in
                    guard resumer.claim() else {
                        return
                    }
                    guard error == nil, let bytes = accumulator.result else {
                        continuation.resume(returning: .failure(.requestFailed))
                        return
                    }
                    continuation.resume(returning: .bytes(bytes))
                }
            )
        }
    }

    /// 主资源：优先取**原始**类型，取不到再退回全尺寸（当前版本）类型。
    static func primaryResource(
        in resources: [PHAssetResource],
        mediaKind: S2AssetSizeProbeMediaKind
    ) -> PHAssetResource? {
        if mediaKind == .video {
            return resources.first { $0.type == .video }
                ?? resources.first { $0.type == .fullSizeVideo }
        }
        return resources.first { $0.type == .photo }
            ?? resources.first { $0.type == .fullSizePhoto }
    }

    static func mediaKind(of asset: PHAsset) -> S2AssetSizeProbeMediaKind {
        if asset.mediaType == .video {
            return .video
        }
        if asset.mediaSubtypes.contains(.photoLive) {
            return .livePhoto
        }
        return .photo
    }

    private static func byteCount(of outcome: Outcome) -> Int64? {
        switch outcome {
        case let .bytes(value):
            return value
        case .failure:
            return nil
        }
    }

    private static func failure(of outcome: Outcome) -> S2AssetSizeProbeFailure? {
        switch outcome {
        case .bytes:
            return nil
        case let .failure(reason):
            return reason
        }
    }
}

/// 回调可能被系统调用多次时，保证 `CheckedContinuation` 只 resume 一次。
private final class ContinuationResumer {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else {
            return false
        }
        claimed = true
        return true
    }
}

/// IC-099 阶段二 R4：顶部信息区「占用空间」的取数实现。
///
/// 按 `S2AssetVolumeRouter` 的类型分派走三条路线之一（④ 技术负责人 2026-08-28，
/// 依 H43 真机 `099.txt`①）。全部禁网络；任一路失败、`.fullSizePhoto` 缺失、
/// iCloud 不可得，一律返回 `nil`（副行退化为只显示序号，不显示占位符）。
///
/// **不使用任何 KVC 私有键**；**不碰产品图片请求策略与节流**
/// （`S2TemporaryPhotoImageStrategy` 与 `PHImageManager.requestImage*` 的产品调用点一字未动）；
/// **不改 `AssetSizeScanner` 的 S3 语义**（那条链仍是多资源求和，本类型与它无调用关系）。
///
/// 与 IC-099b 探针 `AssetSizeProbeService` 的取数辅助没有共用：探针要的是
/// 「两条路线各自的字节数 + 失败原因分类」用于取证，本类型要的是
/// 「当前版本的一个 `Int64?`」，返回契约不同；且探针的数据路线取的是**原始**
/// 主资源，本类型取的是 `.fullSizePhoto`（当前版本），语义相反。
final class AssetVolumeService: S2AssetVolumeProviding {
    private let assets: [String: PHAsset]

    init(assets: [String: PHAsset]) {
        self.assets = assets
    }

    func byteCount(assetID: String) async -> Int64? {
        guard let asset = assets[assetID] else {
            return nil
        }
        let resources = PHAssetResource.assetResources(for: asset)
        let route = S2AssetVolumeRouter.route(
            mediaKind: AssetSizeProbeService.mediaKind(of: asset),
            isEdited: resources.contains { $0.type == .adjustmentData }
        )
        switch route {
        case .videoAssetURL:
            return await videoURLByteCount(for: asset)
        case .contentEditingInputURL:
            return await contentEditingInputByteCount(for: asset)
        case .fullSizePhotoResource:
            guard let resource = resources.first(
                where: { $0.type == .fullSizePhoto }
            ) else {
                return nil
            }
            return await streamedByteCount(of: resource)
        }
    }

    private func contentEditingInputByteCount(
        for asset: PHAsset
    ) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = false
            let resumer = ContinuationResumer()

            _ = asset.requestContentEditingInput(with: options) { input, info in
                guard resumer.claim() else {
                    return
                }
                if let cancelled = info[PHContentEditingInputCancelledKey]
                    as? Bool, cancelled {
                    continuation.resume(returning: nil)
                    return
                }
                if let inCloud = info[PHContentEditingInputResultIsInCloudKey]
                    as? Bool, inCloud {
                    continuation.resume(returning: nil)
                    return
                }
                if info[PHContentEditingInputErrorKey] != nil {
                    continuation.resume(returning: nil)
                    return
                }
                guard let url = input?.fullSizeImageURL else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Self.fileByteCount(at: url))
            }
        }
    }

    private func videoURLByteCount(for asset: PHAsset) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            let resumer = ContinuationResumer()

            _ = PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, info in
                guard resumer.claim() else {
                    return
                }
                if let cancelled = info?[PHImageCancelledKey] as? Bool,
                   cancelled {
                    continuation.resume(returning: nil)
                    return
                }
                if let inCloud = info?[PHImageResultIsInCloudKey] as? Bool,
                   inCloud {
                    continuation.resume(returning: nil)
                    return
                }
                if info?[PHImageErrorKey] != nil {
                    continuation.resume(returning: nil)
                    return
                }
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(
                    returning: Self.fileByteCount(at: urlAsset.url)
                )
            }
        }
    }

    private func streamedByteCount(
        of resource: PHAssetResource
    ) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            let accumulator = ByteAccumulator()
            let resumer = ContinuationResumer()

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    accumulator.append(data.count)
                },
                completionHandler: { error in
                    guard resumer.claim() else {
                        return
                    }
                    guard error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: accumulator.result)
                }
            )
        }
    }

    private static func fileByteCount(at url: URL) -> Int64? {
        guard let size = try? url.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize else {
            return nil
        }
        return Int64(size)
    }
}
