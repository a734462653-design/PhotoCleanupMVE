import Foundation

enum PersistedSessionPhase: String, Codable, Equatable {
    case submissionWaiting
    case submissionSucceeded
    case submissionFailed
    case submissionUnknown
    case completionSuccess
    case completionCancelled
    case completionFailure
    case completionUnknown
}

struct PersistedSnapshot: Codable {
    let submissionID: String
    let assetIDs: [String]
    let assetCount: Int
    let knownTotalBytes: Int64
    let unavailableCount: Int
    let volumeDisplayMode: String
    let favoriteAssetIDs: [String]
    let frozenAt: Date

    init(_ snapshot: SubmissionSnapshot) {
        submissionID = snapshot.submissionID
        assetIDs = snapshot.assetIDs
        assetCount = snapshot.assetCount
        knownTotalBytes = snapshot.knownTotalBytes
        unavailableCount = snapshot.unavailableCount
        volumeDisplayMode = snapshot.volumeDisplayMode == .exact
            ? "exact"
            : "lowerBound"
        favoriteAssetIDs = snapshot.favoriteAssetIDs.sorted()
        frozenAt = snapshot.frozenAt
    }

    var snapshot: SubmissionSnapshot? {
        let mode: VolumeDisplayMode
        switch volumeDisplayMode {
        case "exact":
            mode = .exact
        case "lowerBound":
            mode = .lowerBound
        default:
            return nil
        }
        guard assetCount == assetIDs.count,
              Set(assetIDs).count == assetIDs.count,
              assetCount >= 1,
              knownTotalBytes >= 0,
              (0...assetCount).contains(unavailableCount),
              Set(favoriteAssetIDs).isSubset(of: Set(assetIDs)),
              (mode == .exact && unavailableCount == 0)
                || (mode == .lowerBound && unavailableCount > 0) else {
            return nil
        }
        return SubmissionSnapshot(
            submissionID: submissionID,
            assetIDs: assetIDs,
            assetCount: assetCount,
            knownTotalBytes: knownTotalBytes,
            unavailableCount: unavailableCount,
            volumeDisplayMode: mode,
            favoriteAssetIDs: Set(favoriteAssetIDs),
            frozenAt: frozenAt
        )
    }
}

struct PersistedFailure: Codable {
    let submissionID: String
    let successfulAssetIDs: [String]
    let failedAssetIDs: [String]
    let unprocessedAssetIDs: [String]
    let category: String
    let message: String
    let systemDomain: String?
    let systemCode: Int?
    let receivedAt: Date

    init(_ callback: S4FailureCallback) {
        submissionID = callback.submissionID
        successfulAssetIDs = callback.successfulAssetIDs.sorted()
        failedAssetIDs = callback.failedAssetIDs.sorted()
        unprocessedAssetIDs = callback.unprocessedAssetIDs.sorted()
        category = callback.reason.category.rawValue
        message = callback.reason.message
        systemDomain = callback.reason.systemDomain
        systemCode = callback.reason.systemCode
        receivedAt = callback.receivedAt
    }

    var callback: S4FailureCallback? {
        guard let parsedCategory = S4FailureCategory(rawValue: category) else {
            return nil
        }
        return S4FailureCallback(
            submissionID: submissionID,
            successfulAssetIDs: Set(successfulAssetIDs),
            failedAssetIDs: Set(failedAssetIDs),
            unprocessedAssetIDs: Set(unprocessedAssetIDs),
            reason: S4FailureReason(
                category: parsedCategory,
                message: message,
                systemDomain: systemDomain,
                systemCode: systemCode
            ),
            receivedAt: receivedAt
        )
    }
}

struct PersistedSession: Codable {
    let phase: PersistedSessionPhase
    let snapshot: PersistedSnapshot
    let activeElapsedSeconds: TimeInterval
    let successReceivedAt: Date?
    let failure: PersistedFailure?
    let unknownReason: String?
    let downstreamTargetState: String?
    let l3BaselineReading: S5DiskReading?
    let l3CompletionReading: S5DiskReading?
    let l3DeltaGB: Double?
    let recentlyDeletedClearedAt: Date?

    init(s4 state: S4PersistentState) {
        let phase: PersistedSessionPhase
        let successReceivedAt: Date?
        let failure: PersistedFailure?
        let unknownReason: String?
        switch state.state {
        case .submitted, .resumedInteraction:
            phase = .submissionWaiting
            successReceivedAt = nil
            failure = nil
            unknownReason = nil
        case let .allSucceeded(result):
            phase = .submissionSucceeded
            successReceivedAt = result.receivedAt
            failure = nil
            unknownReason = nil
        case let .batchFailed(callback):
            phase = .submissionFailed
            successReceivedAt = nil
            failure = PersistedFailure(callback)
            unknownReason = nil
        case let .resultUnknown(reason):
            phase = .submissionUnknown
            successReceivedAt = nil
            failure = nil
            unknownReason = reason.rawValue
        }
        self.phase = phase
        snapshot = PersistedSnapshot(state.snapshot)
        activeElapsedSeconds = state.activeElapsedSeconds
        self.successReceivedAt = successReceivedAt
        self.failure = failure
        self.unknownReason = unknownReason
        downstreamTargetState = state.downstreamTargetState?.rawValue
        l3BaselineReading = nil
        l3CompletionReading = nil
        l3DeltaGB = nil
        recentlyDeletedClearedAt = nil
    }

    init(s5 state: S5PersistentState) {
        let phase: PersistedSessionPhase
        let failure: PersistedFailure?
        let unknownReason: String?
        switch state.state {
        case .movedToRecentlyDeleted:
            phase = .completionSuccess
            failure = nil
            unknownReason = nil
        case let .cancelled(context):
            phase = .completionCancelled
            failure = PersistedFailure(context.callback)
            unknownReason = nil
        case let .failed(context):
            phase = .completionFailure
            failure = PersistedFailure(context.callback)
            unknownReason = nil
        case let .unknown(context):
            phase = .completionUnknown
            failure = nil
            unknownReason = context.reason.rawValue
        }
        self.phase = phase
        snapshot = PersistedSnapshot(state.state.snapshot)
        activeElapsedSeconds = 0
        successReceivedAt = nil
        self.failure = failure
        self.unknownReason = unknownReason
        downstreamTargetState = state.state.downstreamTargetState.rawValue
        l3BaselineReading = state.l3BaselineReading
        l3CompletionReading = state.l3CompletionReading
        l3DeltaGB = state.l3DeltaGB
        recentlyDeletedClearedAt = state.recentlyDeletedClearedAt
    }
}

final class SessionPersistence {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let lock = NSLock()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = root.appendingPathComponent(
            "PhotoCleanupMVE",
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("session.json")
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ session: PersistedSession) throws {
        lock.lock()
        defer { lock.unlock() }
        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: .atomic)
    }

    func claim(_ session: PersistedSession) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if fileManager.fileExists(atPath: fileURL.path) {
            let existingData = try Data(contentsOf: fileURL)
            _ = try decoder.decode(PersistedSession.self, from: existingData)
            return false
        }
        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: .atomic)
        return true
    }

    func load() -> PersistedSession? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? decoder.decode(PersistedSession.self, from: data)
    }

    func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        try fileManager.removeItem(at: fileURL)
    }
}
