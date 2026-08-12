import Foundation

enum S3State: String, Equatable, Sendable {
    case scanning = "S3-1"
    case ready = "S3-2"
    case empty = "S3-4"
}

enum S3FreezeRejection: Equatable, Sendable {
    case invalidState(S3State)
    case alreadyFrozen
}

enum S3SnapshotFreezeResult: Equatable, Sendable {
    case frozen(SubmissionSnapshot)
    case rejected(S3FreezeRejection)
}

enum DecimalVolumeFormatter {
    private static let bytesPerMegabyte: Int64 = 1_000_000
    private static let bytesPerGigabyte: Int64 = 1_000_000_000

    static func string(forByteCount byteCount: Int64) -> String {
        precondition(byteCount >= 0, "体积字节数不得为负")

        if byteCount >= bytesPerGigabyte {
            let tenthsOfGigabyte = byteCount / (bytesPerGigabyte / 10)
            return "\(tenthsOfGigabyte / 10).\(tenthsOfGigabyte % 10) GB"
        }

        return "\(byteCount / bytesPerMegabyte) MB"
    }
}

final class S3StateMachine {
    private(set) var assets: [AssetDescriptor]
    private(set) var conclusionCache: [String: AssetScanConclusion]
    private(set) var pendingScanAssetIDs: [String] = []
    private(set) var state: S3State = .empty
    private(set) var frozenSnapshot: SubmissionSnapshot?

    private let submissionIDGenerator: () -> String
    private let clock: () -> Date

    init(
        assets: [AssetDescriptor],
        cachedConclusions: [String: AssetScanConclusion] = [:],
        submissionIDGenerator: @escaping () -> String = { UUID().uuidString },
        clock: @escaping () -> Date = { Date() }
    ) {
        self.assets = Self.deduplicated(assets)
        self.conclusionCache = cachedConclusions
        self.submissionIDGenerator = submissionIDGenerator
        self.clock = clock

        for conclusion in cachedConclusions.values {
            if case let .knownBytes(byteCount) = conclusion {
                precondition(byteCount >= 0, "缓存中的已知字节数不得为负")
            }
        }

        for asset in self.assets where self.conclusionCache[asset.identifier] == nil {
            self.conclusionCache[asset.identifier] = .notStarted
        }

        normalizeStateAndEnqueueIfNeeded()
    }

    var assetIDs: [String] {
        assets.map(\.identifier)
    }

    var assetCount: Int {
        assets.count
    }

    var knownTotalBytes: Int64 {
        assets.reduce(into: 0) { total, asset in
            if case let .knownBytes(byteCount)? = conclusionCache[asset.identifier] {
                total += byteCount
            }
        }
    }

    var unavailableCount: Int {
        assets.reduce(into: 0) { count, asset in
            if conclusionCache[asset.identifier] == .unavailable {
                count += 1
            }
        }
    }

    var isScanComplete: Bool {
        !assets.contains { asset in
            conclusionCache[asset.identifier]?.isIncomplete ?? true
        }
    }

    var volumeDisplayMode: VolumeDisplayMode? {
        guard state == .ready else {
            return nil
        }
        return unavailableCount == 0 ? .exact : .lowerBound
    }

    var canSubmit: Bool {
        state == .ready && frozenSnapshot == nil
    }

    func cachedConclusion(for assetID: String) -> AssetScanConclusion? {
        conclusionCache[assetID]
    }

    func takePendingScanAssetIDs() -> [String] {
        let result = pendingScanAssetIDs
        pendingScanAssetIDs.removeAll(keepingCapacity: true)
        return result
    }

    @discardableResult
    func recordScanSuccess(for assetID: String, byteCount: Int64) -> Bool {
        guard byteCount >= 0, conclusionCache[assetID] != nil else {
            return false
        }

        conclusionCache[assetID] = .knownBytes(byteCount)
        normalizeStateAndEnqueueIfNeeded()
        return true
    }

    @discardableResult
    func recordScanFailure(for assetID: String) -> Bool {
        guard conclusionCache[assetID] != nil else {
            return false
        }

        conclusionCache[assetID] = .unavailable
        normalizeStateAndEnqueueIfNeeded()
        return true
    }

    @discardableResult
    func removeAsset(identifier: String) -> Bool {
        guard frozenSnapshot == nil,
              let index = assets.firstIndex(where: { $0.identifier == identifier }) else {
            return false
        }

        assets.remove(at: index)
        normalizeStateAndEnqueueIfNeeded()
        return true
    }

    @discardableResult
    func cancelAll() -> Bool {
        guard frozenSnapshot == nil, !assets.isEmpty else {
            return false
        }

        assets.removeAll(keepingCapacity: true)
        normalizeStateAndEnqueueIfNeeded()
        return true
    }

    @discardableResult
    func collectionBecameEmpty() -> Bool {
        guard frozenSnapshot == nil, !assets.isEmpty else {
            return false
        }

        assets.removeAll(keepingCapacity: true)
        normalizeStateAndEnqueueIfNeeded()
        return true
    }

    func freezeSubmissionSnapshot() -> S3SnapshotFreezeResult {
        guard frozenSnapshot == nil else {
            return .rejected(.alreadyFrozen)
        }

        normalizeStateAndEnqueueIfNeeded()

        guard !assets.isEmpty, isScanComplete else {
            return .rejected(.invalidState(state))
        }

        let frozenAssetIDs = assetIDs
        let frozenKnownTotalBytes = knownTotalBytes
        let frozenUnavailableCount = unavailableCount
        let frozenVolumeDisplayMode: VolumeDisplayMode =
            frozenUnavailableCount == 0 ? .exact : .lowerBound
        let frozenFavoriteAssetIDs = Set(
            assets.lazy.filter(\.isFavorite).map(\.identifier)
        )

        let snapshot = SubmissionSnapshot(
            submissionID: submissionIDGenerator(),
            assetIDs: frozenAssetIDs,
            assetCount: frozenAssetIDs.count,
            knownTotalBytes: frozenKnownTotalBytes,
            unavailableCount: frozenUnavailableCount,
            volumeDisplayMode: frozenVolumeDisplayMode,
            favoriteAssetIDs: frozenFavoriteAssetIDs,
            frozenAt: clock()
        )
        frozenSnapshot = snapshot
        return .frozen(snapshot)
    }

    private static func deduplicated(_ assets: [AssetDescriptor]) -> [AssetDescriptor] {
        var seen = Set<String>()
        return assets.filter { seen.insert($0.identifier).inserted }
    }

    private func normalizeStateAndEnqueueIfNeeded() {
        guard !assets.isEmpty else {
            state = .empty
            return
        }

        let notStartedAssetIDs = assets.compactMap { asset -> String? in
            conclusionCache[asset.identifier] == .notStarted ? asset.identifier : nil
        }
        for assetID in notStartedAssetIDs {
            conclusionCache[assetID] = .inProgress
            pendingScanAssetIDs.append(assetID)
        }

        state = isScanComplete ? .ready : .scanning
    }
}
