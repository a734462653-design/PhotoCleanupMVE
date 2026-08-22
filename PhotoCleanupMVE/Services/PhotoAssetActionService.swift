import Foundation
import Photos

/// IC-076：加入相册前的同步判定。生产实现与测试假实现共用同一判定，
/// 保证「已包含时不重复写入」的规则只有一处定义。
enum PhotoAlbumAdditionPlan: Equatable {
    case albumUnavailable
    case assetUnavailable
    case alreadyContained
    case write

    static func make(
        albumExists: Bool,
        assetExists: Bool,
        alreadyContained: Bool
    ) -> PhotoAlbumAdditionPlan {
        guard albumExists else {
            return .albumUnavailable
        }
        guard assetExists else {
            return .assetUnavailable
        }
        return alreadyContained ? .alreadyContained : .write
    }
}

/// IC-076（v15 第二节第 4 部分、回写决策 29）：操作条写入服务。
/// 四件事：切换收藏、把资产加入相册、列出用户相册、校验相册存在。
/// 写入是异步的；`completion` 可能在任意线程回调，由协调器送回主线程后再交给状态机。
/// 相册列表与存在性校验是本地元数据查询，同步返回。
protocol PhotoAssetActionServicing {
    func toggleFavorite(
        assetID: String,
        completion: @escaping (Bool) -> Void
    )

    func addAsset(
        assetID: String,
        toAlbumWithID albumID: String,
        completion: @escaping (S2AlbumAdditionOutcome) -> Void
    )

    func userAlbums() -> [S2AlbumReference]

    func albumExists(id: String) -> Bool
}

struct PhotoKitAssetActionService: PhotoAssetActionServicing {
    func toggleFavorite(
        assetID: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard isAuthorizedForWriting,
              let asset = fetchAsset(assetID),
              asset.canPerform(.properties) else {
            completion(false)
            return
        }
        let targetValue = !asset.isFavorite
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest(for: asset).isFavorite = targetValue
        } completionHandler: { succeeded, _ in
            completion(succeeded)
        }
    }

    func addAsset(
        assetID: String,
        toAlbumWithID albumID: String,
        completion: @escaping (S2AlbumAdditionOutcome) -> Void
    ) {
        guard isAuthorizedForWriting else {
            completion(.failure)
            return
        }
        let album = fetchAlbum(albumID)
        let asset = fetchAsset(assetID)
        // 写入前同步判定是否已包含：`PHFetchResult.contains` 是本地元数据查询。
        let alreadyContained: Bool
        if let album, let asset {
            alreadyContained = PHAsset.fetchAssets(in: album, options: nil)
                .contains(asset)
        } else {
            alreadyContained = false
        }
        let plan = PhotoAlbumAdditionPlan.make(
            albumExists: album != nil,
            assetExists: asset != nil,
            alreadyContained: alreadyContained
        )
        switch plan {
        case .albumUnavailable:
            completion(.albumUnavailable)
        case .assetUnavailable:
            completion(.failure)
        case .alreadyContained:
            completion(.success(alreadyContained: true))
        case .write:
            guard let album, let asset, album.canPerform(.addContent) else {
                completion(.failure)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest(for: album)?
                    .addAssets([asset] as NSArray)
            } completionHandler: { succeeded, _ in
                completion(
                    succeeded ? .success(alreadyContained: false) : .failure
                )
            }
        }
    }

    func userAlbums() -> [S2AlbumReference] {
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: nil
        )
        var albums: [S2AlbumReference] = []
        result.enumerateObjects { collection, _, _ in
            albums.append(
                S2AlbumReference(
                    id: collection.localIdentifier,
                    name: collection.localizedTitle ?? String()
                )
            )
        }
        return albums
    }

    func albumExists(id: String) -> Bool {
        fetchAlbum(id) != nil
    }

    private var isAuthorizedForWriting: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    private func fetchAsset(_ assetID: String) -> PHAsset? {
        guard !assetID.isEmpty else {
            return nil
        }
        return PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        ).firstObject
    }

    private func fetchAlbum(_ albumID: String) -> PHAssetCollection? {
        guard !albumID.isEmpty else {
            return nil
        }
        return PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumID],
            options: nil
        ).firstObject
    }
}
