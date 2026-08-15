import Foundation
import Photos

struct S1PhotoAssetSnapshot {
    let identifier: String
    let creationDate: Date?
}

struct S1AlbumCollectionSnapshot {
    let identifier: String
    let localizedTitle: String?
    let collectionType: PHAssetCollectionType
    let collectionSubtype: PHAssetCollectionSubtype
    let isHidden: Bool
    let assets: [S1PhotoAssetSnapshot]
}

struct S1PhotoLibrarySource {
    let authorizationStatus: () -> PHAuthorizationStatus
    let fetchAssets: () -> [S1PhotoAssetSnapshot]
    let fetchAssetCollections: (
        PHAssetCollectionType,
        PHAssetCollectionSubtype
    ) -> [S1AlbumCollectionSnapshot]

    static let production = S1PhotoLibrarySource(
        authorizationStatus: {
            PHPhotoLibrary.authorizationStatus(for: .readWrite)
        },
        fetchAssets: {
            s1AssetSnapshots(from: PHAsset.fetchAssets(with: nil))
        },
        fetchAssetCollections: { collectionType, collectionSubtype in
            let result = PHAssetCollection.fetchAssetCollections(
                with: collectionType,
                subtype: collectionSubtype,
                options: nil
            )
            var snapshots: [S1AlbumCollectionSnapshot] = []
            result.enumerateObjects { collection, _, _ in
                snapshots.append(s1AlbumSnapshot(from: collection))
            }
            return snapshots
        }
    )
}

private func s1AssetSnapshots(
    from result: PHFetchResult<PHAsset>
) -> [S1PhotoAssetSnapshot] {
    var snapshots: [S1PhotoAssetSnapshot] = []
    result.enumerateObjects { asset, _, _ in
        snapshots.append(
            S1PhotoAssetSnapshot(
                identifier: asset.localIdentifier,
                creationDate: asset.creationDate
            )
        )
    }
    return snapshots
}

private func s1AlbumSnapshot(
    from collection: PHAssetCollection
) -> S1AlbumCollectionSnapshot {
    S1AlbumCollectionSnapshot(
        identifier: collection.localIdentifier,
        localizedTitle: collection.localizedTitle,
        collectionType: collection.assetCollectionType,
        collectionSubtype: collection.assetCollectionSubtype,
        isHidden: collection.assetCollectionSubtype == .smartAlbumAllHidden,
        assets: s1AssetSnapshots(
            from: PHAsset.fetchAssets(in: collection, options: nil)
        )
    )
}

@MainActor
final class PhotoLibraryService {
    private let s1Source: S1PhotoLibrarySource

    init(s1Source: S1PhotoLibrarySource = .production) {
        self.s1Source = s1Source
    }

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

    func s1Ranges(
        groupedBy groupingDimension: S1GroupingDimension
    ) -> Result<[S1Range], S1RangeReadFailure> {
        if let authorizationFailure = s1AuthorizationFailure(
            for: groupingDimension
        ) {
            return .failure(authorizationFailure)
        }

        switch groupingDimension {
        case .month:
            return chronologicalRanges(
                groupedBy: .month,
                groupingDimension: groupingDimension,
                assets: s1Source.fetchAssets()
            )
        case .year:
            return chronologicalRanges(
                groupedBy: .year,
                groupingDimension: groupingDimension,
                assets: s1Source.fetchAssets()
            )
        case .album:
            return albumRanges(from: fetchedUserAlbumCandidates())
        case .unclassified:
            return unclassifiedRanges(
                allAssets: s1Source.fetchAssets(),
                excluding: fetchedUserAlbumCandidates()
            )
        }
    }

    func s1Ranges(
        groupedBy groupingDimension: S1GroupingDimension,
        albumCollections: [PHAssetCollection]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        if let authorizationFailure = s1AuthorizationFailure(
            for: groupingDimension
        ) {
            return .failure(authorizationFailure)
        }

        switch groupingDimension {
        case .month:
            return chronologicalRanges(
                groupedBy: .month,
                groupingDimension: groupingDimension,
                assets: s1Source.fetchAssets()
            )
        case .year:
            return chronologicalRanges(
                groupedBy: .year,
                groupingDimension: groupingDimension,
                assets: s1Source.fetchAssets()
            )
        case .album:
            return albumRanges(
                from: albumCollections.map { s1AlbumSnapshot(from: $0) }
            )
        case .unclassified:
            return unclassifiedRanges(
                allAssets: s1Source.fetchAssets(),
                excluding: albumCollections.map { s1AlbumSnapshot(from: $0) }
            )
        }
    }

    private struct DatedAsset {
        let identifier: String
        let creationDate: Date
    }

    private func s1AuthorizationFailure(
        for groupingDimension: S1GroupingDimension
    ) -> S1RangeReadFailure? {
        let status = s1Source.authorizationStatus()
        switch status {
        case .authorized:
            return nil
        case .notDetermined:
            return S1RangeReadFailure(
                groupingDimension: groupingDimension,
                reason: .authorizationNotDetermined
            )
        case .denied:
            return S1RangeReadFailure(
                groupingDimension: groupingDimension,
                reason: .authorizationDenied
            )
        case .restricted:
            return S1RangeReadFailure(
                groupingDimension: groupingDimension,
                reason: .authorizationRestricted
            )
        case .limited:
            return S1RangeReadFailure(
                groupingDimension: groupingDimension,
                reason: .limitedAuthorizationPolicyUndecided
            )
        @unknown default:
            return S1RangeReadFailure(
                groupingDimension: groupingDimension,
                reason: .unknownAuthorizationStatus(status.rawValue)
            )
        }
    }

    private func chronologicalRanges(
        groupedBy component: Calendar.Component,
        groupingDimension: S1GroupingDimension,
        assets: [S1PhotoAssetSnapshot]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        switch datedAssets(
            in: assets,
            groupingDimension: groupingDimension
        ) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(assets):
            let calendar = Calendar.autoupdatingCurrent
            var assetsByStartDate: [Date: [DatedAsset]] = [:]
            for asset in assets {
                guard let interval = calendar.dateInterval(
                    of: component,
                    for: asset.creationDate
                ) else {
                    return .failure(
                        S1RangeReadFailure(
                            groupingDimension: groupingDimension,
                            reason: .invalidResponse
                        )
                    )
                }
                assetsByStartDate[interval.start, default: []].append(asset)
            }

            let ranges = assetsByStartDate.keys.sorted(by: >).map { startDate in
                let groupedAssets = assetsByStartDate[startDate] ?? []
                return S1Range(
                    id: chronologicalRangeID(
                        for: startDate,
                        groupingDimension: groupingDimension,
                        calendar: calendar
                    ),
                    displayName: chronologicalDisplayName(
                        for: startDate,
                        groupingDimension: groupingDimension,
                        calendar: calendar
                    ),
                    assetIDsNewestFirst: groupedAssets.map(\.identifier)
                )
            }
            return .success(ranges)
        }
    }

    private func albumRanges(
        from albumCollections: [S1AlbumCollectionSnapshot]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        var seenRangeIDs = Set<String>()
        var ranges: [S1Range] = []

        for collection in userCreatedAlbums(from: albumCollections) {
            let assetResult = datedAssets(
                in: collection.assets,
                groupingDimension: .album
            )
            let assets: [DatedAsset]
            switch assetResult {
            case let .failure(failure):
                return .failure(failure)
            case let .success(value) where value.isEmpty:
                continue
            case let .success(value):
                assets = value
            }

            let rangeID = collection.identifier
            guard seenRangeIDs.insert(rangeID).inserted else {
                return .failure(
                    S1RangeReadFailure(
                        groupingDimension: .album,
                        reason: .duplicateRangeID(rangeID)
                    )
                )
            }
            let displayName = collection.localizedTitle?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? String()
            guard !displayName.isEmpty else {
                return .failure(
                    S1RangeReadFailure(
                        groupingDimension: .album,
                        reason: .missingDisplayName(rangeID: rangeID)
                    )
                )
            }

            ranges.append(
                S1Range(
                    id: rangeID,
                    displayName: displayName,
                    assetIDsNewestFirst: assets.map(\.identifier)
                )
            )
        }

        return .success(ranges)
    }

    private func unclassifiedRanges(
        allAssets: [S1PhotoAssetSnapshot],
        excluding albumCollections: [S1AlbumCollectionSnapshot]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        var seenRangeIDs = Set<String>()
        var classifiedAssetIDs = Set<String>()

        for collection in userCreatedAlbums(from: albumCollections) {
            let rangeID = collection.identifier
            guard seenRangeIDs.insert(rangeID).inserted else {
                return .failure(
                    S1RangeReadFailure(
                        groupingDimension: .unclassified,
                        reason: .duplicateRangeID(rangeID)
                    )
                )
            }
            for asset in collection.assets {
                classifiedAssetIDs.insert(asset.identifier)
            }
        }

        let unclassifiedAssets = allAssets.filter { asset in
            !classifiedAssetIDs.contains(asset.identifier)
        }

        switch datedAssets(
            in: unclassifiedAssets,
            groupingDimension: .unclassified
        ) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(assets) where assets.isEmpty:
            return .success([])
        case let .success(assets):
            return .success([
                S1Range(
                    id: "s1-unclassified",
                    displayName: L10n.text("s1.dimension.unclassified"),
                    assetIDsNewestFirst: assets.map(\.identifier)
                )
            ])
        }
    }

    private func datedAssets(
        in assets: [S1PhotoAssetSnapshot],
        groupingDimension: S1GroupingDimension
    ) -> Result<[DatedAsset], S1RangeReadFailure> {
        var datedAssets: [DatedAsset] = []
        var seenAssetIDs = Set<String>()

        for asset in assets {
            let assetID = asset.identifier
            guard seenAssetIDs.insert(assetID).inserted else {
                return .failure(
                    S1RangeReadFailure(
                        groupingDimension: groupingDimension,
                        reason: .duplicateAssetID(
                            rangeID: String(),
                            assetID: assetID
                        )
                    )
                )
            }
            guard let creationDate = asset.creationDate else {
                return .failure(
                    S1RangeReadFailure(
                        groupingDimension: groupingDimension,
                        reason: .missingCreationDate(assetID: assetID)
                    )
                )
            }
            datedAssets.append(
                DatedAsset(
                    identifier: assetID,
                    creationDate: creationDate
                )
            )
        }

        datedAssets.sort {
            if $0.creationDate != $1.creationDate {
                return $0.creationDate > $1.creationDate
            }
            return $0.identifier < $1.identifier
        }
        return .success(datedAssets)
    }

    private func fetchedUserAlbumCandidates() -> [S1AlbumCollectionSnapshot] {
        s1Source.fetchAssetCollections(.album, .albumRegular)
    }

    private func userCreatedAlbums(
        from candidates: [S1AlbumCollectionSnapshot]
    ) -> [S1AlbumCollectionSnapshot] {
        candidates.filter { collection in
            collection.collectionType == .album &&
                collection.collectionSubtype == .albumRegular &&
                !collection.isHidden
        }
    }

    private func chronologicalRangeID(
        for date: Date,
        groupingDimension: S1GroupingDimension,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.era, .year, .month],
            from: date
        )
        let prefix = groupingDimension == .month ? "month" : "year"
        let values = [
            components.era ?? 0,
            components.year ?? 0,
            groupingDimension == .month ? components.month ?? 0 : 0
        ]
        return ([prefix] + values.map { String($0) }).joined(separator: ":")
    }

    private func chronologicalDisplayName(
        for date: Date,
        groupingDimension: S1GroupingDimension,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(
            groupingDimension == .month ? "yMMMM" : "y"
        )
        return formatter.string(from: date)
    }
}
