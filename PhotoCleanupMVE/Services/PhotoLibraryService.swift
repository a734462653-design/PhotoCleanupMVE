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
                groupingDimension: groupingDimension
            )
        case .year:
            return chronologicalRanges(
                groupedBy: .year,
                groupingDimension: groupingDimension
            )
        case .album:
            return albumRanges(from: albumCollections)
        case .unclassified:
            return unclassifiedRanges(excluding: albumCollections)
        }
    }

    private struct DatedAsset {
        let identifier: String
        let creationDate: Date
    }

    private func s1AuthorizationFailure(
        for groupingDimension: S1GroupingDimension
    ) -> S1RangeReadFailure? {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
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
                reason: .unknownAuthorizationStatus(
                    PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue
                )
            )
        }
    }

    private func chronologicalRanges(
        groupedBy component: Calendar.Component,
        groupingDimension: S1GroupingDimension
    ) -> Result<[S1Range], S1RangeReadFailure> {
        let fetchResult = PHAsset.fetchAssets(with: nil)
        switch datedAssets(
            in: fetchResult,
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
        from albumCollections: [PHAssetCollection]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        var seenRangeIDs = Set<String>()
        var ranges: [S1Range] = []

        for collection in albumCollections {
            let rangeID = collection.localIdentifier
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

            let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            switch datedAssets(in: fetchResult, groupingDimension: .album) {
            case let .failure(failure):
                return .failure(failure)
            case let .success(assets) where !assets.isEmpty:
                ranges.append(
                    S1Range(
                        id: rangeID,
                        displayName: displayName,
                        assetIDsNewestFirst: assets.map(\.identifier)
                    )
                )
            case .success:
                break
            }
        }

        return .success(ranges)
    }

    private func unclassifiedRanges(
        excluding albumCollections: [PHAssetCollection]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        var seenRangeIDs = Set<String>()
        var classifiedAssetIDs = Set<String>()

        for collection in albumCollections {
            let rangeID = collection.localIdentifier
            guard seenRangeIDs.insert(rangeID).inserted else {
                return .failure(
                    S1RangeReadFailure(
                        groupingDimension: .unclassified,
                        reason: .duplicateRangeID(rangeID)
                    )
                )
            }
            let result = PHAsset.fetchAssets(in: collection, options: nil)
            result.enumerateObjects { asset, _, _ in
                classifiedAssetIDs.insert(asset.localIdentifier)
            }
        }

        let allAssets = PHAsset.fetchAssets(with: nil)
        var unclassifiedAssets: [PHAsset] = []
        allAssets.enumerateObjects { asset, _, _ in
            if !classifiedAssetIDs.contains(asset.localIdentifier) {
                unclassifiedAssets.append(asset)
            }
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
        in fetchResult: PHFetchResult<PHAsset>,
        groupingDimension: S1GroupingDimension
    ) -> Result<[DatedAsset], S1RangeReadFailure> {
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return datedAssets(in: assets, groupingDimension: groupingDimension)
    }

    private func datedAssets(
        in assets: [PHAsset],
        groupingDimension: S1GroupingDimension
    ) -> Result<[DatedAsset], S1RangeReadFailure> {
        var datedAssets: [DatedAsset] = []
        var seenAssetIDs = Set<String>()

        for asset in assets {
            let assetID = asset.localIdentifier
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
