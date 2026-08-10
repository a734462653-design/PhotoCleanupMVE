import Foundation
import Photos

@MainActor
final class PhotoLibraryService {
    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func firstImageAssets(limit: Int) -> [PHAsset] {
        precondition(limit >= 0)
        let result = PHAsset.fetchAssets(with: .image, options: nil)
        let count = min(limit, result.count)
        return (0..<count).map { result.object(at: $0) }
    }

    func assets(orderedBy identifiers: [String]) -> [PHAsset]? {
        let byIdentifier = assetsByIdentifier(identifiers)
        let ordered = identifiers.compactMap { byIdentifier[$0] }
        return ordered.count == identifiers.count ? ordered : nil
    }

    func assetsByIdentifier(_ identifiers: [String]) -> [String: PHAsset] {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: identifiers,
            options: nil
        )
        var byIdentifier: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in
            byIdentifier[asset.localIdentifier] = asset
        }
        return byIdentifier
    }
}
