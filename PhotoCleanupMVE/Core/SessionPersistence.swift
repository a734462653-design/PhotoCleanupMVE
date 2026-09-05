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

/// IC-127 B（未定项 11）：S1 会话档。与 S3→S4 提交快照 `session.json` **分文件**
/// （`s1-session.json`），互不干扰——`claim` / `clear` 的既有语义原样保留。
/// 集合以升序数组编码，保证同一状态的字节稳定。
struct PersistedS1Session: Codable, Equatable {
    struct Continuation: Codable, Equatable {
        let currentAssetID: String
        let farthestAssetID: String
        let recordedSortOrder: String
    }

    let sessionID: String
    let groupingDimension: String
    let sortOrder: String
    let pendingDeletionAssetIDsByRangeID: [String: [String]]
    let continuationsByRangeID: [String: Continuation]
    let firstMarkedRangeIDByAssetID: [String: String]

    init(_ snapshot: S1SessionSnapshot) {
        sessionID = snapshot.sessionID
        groupingDimension = snapshot.groupingDimension.rawValue
        sortOrder = snapshot.sortOrder.rawValue
        pendingDeletionAssetIDsByRangeID = snapshot.pendingDeletionAssetIDsByRangeID
            .mapValues { $0.sorted() }
        continuationsByRangeID = snapshot.continuationsByRangeID.mapValues {
            Continuation(
                currentAssetID: $0.currentAssetID,
                farthestAssetID: $0.farthestAssetID,
                recordedSortOrder: $0.recordedSortOrder.rawValue
            )
        }
        firstMarkedRangeIDByAssetID = snapshot.firstMarkedRangeIDByAssetID
    }

    /// 解码回值快照；字段非法（未知维度／排序、重复资产）时返回 nil，视为坏档。
    var snapshot: S1SessionSnapshot? {
        guard !sessionID.isEmpty,
              let dimension = S1GroupingDimension(rawValue: groupingDimension),
              let order = S1SortOrder(rawValue: sortOrder) else {
            return nil
        }
        var pending: [String: Set<String>] = [:]
        for (rangeID, assetIDs) in pendingDeletionAssetIDsByRangeID {
            let set = Set(assetIDs)
            guard set.count == assetIDs.count else {
                return nil
            }
            pending[rangeID] = set
        }
        var continuations: [String: SessionStore.Continuation] = [:]
        for (rangeID, continuation) in continuationsByRangeID {
            guard let recorded = SessionStore.SortOrder(
                rawValue: continuation.recordedSortOrder
            ) else {
                return nil
            }
            continuations[rangeID] = SessionStore.Continuation(
                currentAssetID: continuation.currentAssetID,
                farthestAssetID: continuation.farthestAssetID,
                recordedSortOrder: recorded
            )
        }
        return S1SessionSnapshot(
            sessionID: sessionID,
            groupingDimension: dimension,
            sortOrder: order,
            pendingDeletionAssetIDsByRangeID: pending,
            continuationsByRangeID: continuations,
            firstMarkedRangeIDByAssetID: firstMarkedRangeIDByAssetID
        )
    }
}

final class SessionPersistence {
    private let fileURL: URL
    private let s1FileURL: URL
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
        s1FileURL = directory.appendingPathComponent("s1-session.json")
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - IC-127 B：S1 会话档（独立文件）

    func saveS1Session(_ snapshot: S1SessionSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        let data = try encoder.encode(PersistedS1Session(snapshot))
        try data.write(to: s1FileURL, options: .atomic)
    }

    func loadS1Session() -> S1SessionSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: s1FileURL),
              let persisted = try? decoder.decode(PersistedS1Session.self, from: data) else {
            return nil
        }
        return persisted.snapshot
    }

    func clearS1Session() throws {
        lock.lock()
        defer { lock.unlock() }
        guard fileManager.fileExists(atPath: s1FileURL.path) else {
            return
        }
        try fileManager.removeItem(at: s1FileURL)
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
