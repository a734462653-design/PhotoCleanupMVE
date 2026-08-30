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

    /// IC-113 B：把资产从相簿移除（中央指示的「撤回」）。
    /// **本卡显式授权该写操作**。只动相簿成员关系，不删除资产本身。
    func removeAsset(
        assetID: String,
        fromAlbumWithID albumID: String,
        completion: @escaping (Bool) -> Void
    )

    func userAlbums() -> [S2AlbumReference]

    /// IC-114 C：相簿选择器列表用——在 `userAlbums` 基础上补数量与键图。
    func userAlbumItems() -> [S2AlbumListItem]

    /// IC-114 C：新建相簿。**本卡显式授权该写操作**。
    /// 只创建集合，不动任何成员关系；失败时回 nil。
    func createAlbum(
        named name: String,
        completion: @escaping (S2AlbumReference?) -> Void
    )

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

    /// IC-113 B：从相簿移除。与 `addAsset` 同一套前置校验，
    /// 只是把 `addAssets` 换成 `removeAssets`、能力位换成 `.removeContent`。
    /// 资产本身不受影响——这不是删除。
    func removeAsset(
        assetID: String,
        fromAlbumWithID albumID: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard isAuthorizedForWriting,
              let album = fetchAlbum(albumID),
              let asset = fetchAsset(assetID),
              album.canPerform(.removeContent) else {
            completion(false)
            return
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest(for: album)?
                .removeAssets([asset] as NSArray)
        } completionHandler: { succeeded, _ in
            completion(succeeded)
        }
    }

    /// IC-114 C：列表项。数量取相簿内资产数，键图取第一张；空相簿键图为 nil。
    func userAlbumItems() -> [S2AlbumListItem] {
        userAlbums().compactMap { reference in
            guard let album = fetchAlbum(reference.id) else {
                return nil
            }
            let assets = PHAsset.fetchAssets(in: album, options: nil)
            return S2AlbumListItem(
                album: reference,
                assetCount: assets.count,
                keyAssetID: assets.firstObject?.localIdentifier
            )
        }
    }

    /// IC-114 C：新建相簿。只创建集合——**不加成员、不移除任何东西**；
    /// 加成员由调用方随后走既有的加入路径完成，故写操作边界清晰。
    func createAlbum(
        named name: String,
        completion: @escaping (S2AlbumReference?) -> Void
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAuthorizedForWriting, !trimmed.isEmpty else {
            completion(nil)
            return
        }
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest
                .creationRequestForAssetCollection(withTitle: trimmed)
            placeholder = request.placeholderForCreatedAssetCollection
        } completionHandler: { succeeded, _ in
            guard succeeded,
                  let identifier = placeholder?.localIdentifier else {
                completion(nil)
                return
            }
            completion(S2AlbumReference(id: identifier, name: trimmed))
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
