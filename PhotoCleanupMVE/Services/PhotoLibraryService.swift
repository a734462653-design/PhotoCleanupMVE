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

    /// IC-127 D：当前授权态的数据层表达（与 PhotoKit 类型解耦）。
    func s1AuthorizationState() -> S1AuthorizationState {
        Self.s1AuthorizationState(from: s1Source.authorizationStatus())
    }

    /// IC-127 D：完整读取回应——授权分派后要么读取（可带受限标志），要么落
    /// 授权类失败；`.notDetermined` 也以失败形态回传（`authorizationNotDetermined`），
    /// 由界面层据 `S1AuthorizationDispatch` 决定是否弹系统授权。
    func s1RangeRead(
        groupedBy groupingDimension: S1GroupingDimension
    ) -> S1RangeReadResponse {
        s1RangeRead(groupedBy: groupingDimension) {
            self.readRanges(
                groupedBy: groupingDimension,
                albumCandidates: self.fetchedUserAlbumCandidates()
            )
        }
    }

    func s1Ranges(
        groupedBy groupingDimension: S1GroupingDimension
    ) -> Result<[S1Range], S1RangeReadFailure> {
        s1RangeRead(groupedBy: groupingDimension).result
    }

    func s1Ranges(
        groupedBy groupingDimension: S1GroupingDimension,
        albumCollections: [PHAssetCollection]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        s1RangeRead(groupedBy: groupingDimension) {
            self.readRanges(
                groupedBy: groupingDimension,
                albumCandidates: albumCollections.map { s1AlbumSnapshot(from: $0) }
            )
        }.result
    }

    private func s1RangeRead(
        groupedBy groupingDimension: S1GroupingDimension,
        read: () -> Result<[S1Range], S1RangeReadFailure>
    ) -> S1RangeReadResponse {
        let authorizationState = s1AuthorizationState()
        switch S1AuthorizationDispatch.dispatch(for: authorizationState) {
        case let .proceed(isLimited):
            // 受限授权按已授权处理：只整理系统交付的可见资产，不落失败态。
            return S1RangeReadResponse(
                result: read(),
                isLimitedAuthorization: isLimited
            )
        case .requestSystemAuthorization, .fail:
            return S1RangeReadResponse(
                result: .failure(
                    S1RangeReadFailure(
                        groupingDimension: groupingDimension,
                        reason: Self.authorizationFailureReason(for: authorizationState)
                    )
                ),
                isLimitedAuthorization: false
            )
        }
    }

    private func readRanges(
        groupedBy groupingDimension: S1GroupingDimension,
        albumCandidates: @autoclosure () -> [S1AlbumCollectionSnapshot]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        switch groupingDimension {
        case .date:
            return dateRanges(assets: s1Source.fetchAssets())
        case .album:
            return albumRanges(from: albumCandidates())
        case .unclassified:
            return unclassifiedRanges(
                allAssets: s1Source.fetchAssets(),
                excluding: albumCandidates()
            )
        }
    }

    private struct DatedAsset {
        let identifier: String
        let creationDate: Date
    }

    private static func s1AuthorizationState(
        from status: PHAuthorizationStatus
    ) -> S1AuthorizationState {
        switch status {
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown(status.rawValue)
        }
    }

    private static func authorizationFailureReason(
        for state: S1AuthorizationState
    ) -> S1RangeReadFailure.Reason {
        switch state {
        case .notDetermined:
            return .authorizationNotDetermined
        case .denied:
            return .authorizationDenied
        case .restricted:
            return .authorizationRestricted
        case let .unknown(rawValue):
            return .unknownAuthorizationStatus(rawValue)
        case .authorized, .limited:
            // 分派为 proceed 的状态不会走到这里；保守起见按 invalidResponse 归读取类。
            return .invalidResponse
        }
    }

    /// IC-127 A（SPEC-S1 第六节、Decision_log 140 漂移 A）：`T=date` 的两级树。
    /// 年为一级节点、该年下的月为二级节点（`parentRangeID` 指向年）；年范围覆盖该年
    /// 全部资产，月范围覆盖该月全部资产。列表顺序：年新到旧，每个年后紧跟其月（新到旧）。
    private func dateRanges(
        assets: [S1PhotoAssetSnapshot]
    ) -> Result<[S1Range], S1RangeReadFailure> {
        switch datedAssets(in: assets, groupingDimension: .date) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(assets):
            let calendar = Calendar.autoupdatingCurrent
            var assetsByYearStart: [Date: [DatedAsset]] = [:]
            var assetsByMonthStart: [Date: [DatedAsset]] = [:]
            var monthStartsByYearStart: [Date: Set<Date>] = [:]
            for asset in assets {
                guard let yearInterval = calendar.dateInterval(
                    of: .year,
                    for: asset.creationDate
                ), let monthInterval = calendar.dateInterval(
                    of: .month,
                    for: asset.creationDate
                ) else {
                    return .failure(
                        S1RangeReadFailure(
                            groupingDimension: .date,
                            reason: .invalidResponse
                        )
                    )
                }
                assetsByYearStart[yearInterval.start, default: []].append(asset)
                assetsByMonthStart[monthInterval.start, default: []].append(asset)
                monthStartsByYearStart[yearInterval.start, default: []]
                    .insert(monthInterval.start)
            }

            var ranges: [S1Range] = []
            for yearStart in assetsByYearStart.keys.sorted(by: >) {
                let yearID = chronologicalRangeID(
                    for: yearStart,
                    level: .year,
                    calendar: calendar
                )
                ranges.append(
                    S1Range(
                        id: yearID,
                        displayName: chronologicalDisplayName(
                            for: yearStart,
                            level: .year,
                            calendar: calendar
                        ),
                        assetIDsNewestFirst:
                            (assetsByYearStart[yearStart] ?? []).map(\.identifier)
                    )
                )
                let monthStarts = (monthStartsByYearStart[yearStart] ?? [])
                    .sorted(by: >)
                for monthStart in monthStarts {
                    ranges.append(
                        S1Range(
                            id: chronologicalRangeID(
                                for: monthStart,
                                level: .month,
                                calendar: calendar
                            ),
                            displayName: chronologicalDisplayName(
                                for: monthStart,
                                level: .month,
                                calendar: calendar
                            ),
                            assetIDsNewestFirst:
                                (assetsByMonthStart[monthStart] ?? []).map(\.identifier),
                            parentRangeID: yearID
                        )
                    )
                }
            }
            return .success(ranges)
        }
    }

    private enum ChronologicalLevel {
        case year
        case month
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
        level: ChronologicalLevel,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.era, .year, .month],
            from: date
        )
        let prefix = level == .month ? "month" : "year"
        let values = [
            components.era ?? 0,
            components.year ?? 0,
            level == .month ? components.month ?? 0 : 0
        ]
        return ([prefix] + values.map { String($0) }).joined(separator: ":")
    }

    private func chronologicalDisplayName(
        for date: Date,
        level: ChronologicalLevel,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(
            level == .month ? "yMMMM" : "y"
        )
        return formatter.string(from: date)
    }
}
