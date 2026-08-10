import Combine
import Foundation
import Photos

enum CleanupRoute: Equatable {
    case loading
    case confirmation
    case execution
    case completion
    case finished
}

@MainActor
final class CleanupCoordinator: ObservableObject {
    static let debugAssetLimit = 20

    @Published private(set) var route: CleanupRoute = .loading
    @Published private(set) var s3Machine: S3StateMachine?
    @Published private(set) var s4Machine: S4StateMachine?
    @Published private(set) var s5Machine: S5StateMachine?
    @Published private(set) var message: String?

    private let photoLibrary: PhotoLibraryService
    private let sizeScanner: AssetSizeScanner
    private let deletionService: PhotoDeletionService
    private let persistence: SessionPersistence

    private var loadedAssets: [String: PHAsset] = [:]
    private var sessionDescriptors: [String: AssetDescriptor] = [:]
    private var scanTasks: [String: Task<Void, Never>] = [:]
    private var s4TimerTask: Task<Void, Never>?
    private var s4LastUptime: TimeInterval?
    private var didStart = false

    init(
        photoLibrary: PhotoLibraryService? = nil,
        sizeScanner: AssetSizeScanner = AssetSizeScanner(),
        deletionService: PhotoDeletionService = PhotoDeletionService(),
        persistence: SessionPersistence = SessionPersistence()
    ) {
        self.photoLibrary = photoLibrary ?? PhotoLibraryService()
        self.sizeScanner = sizeScanner
        self.deletionService = deletionService
        self.persistence = persistence
    }

    func start() {
        guard !didStart else {
            return
        }
        didStart = true

        if restorePersistedSession() {
            return
        }
        Task { [weak self] in
            await self?.loadDebugAssets()
        }
    }

    func removeAsset(_ identifier: String) {
        guard let machine = s3Machine else {
            return
        }
        objectWillChange.send()
        if machine.removeAsset(identifier: identifier) {
            beginPendingScans()
        }
    }

    func cancelAllAssets() {
        guard let machine = s3Machine else {
            return
        }
        objectWillChange.send()
        _ = machine.cancelAll()
    }

    func leaveConfirmation() {
        finishSession()
    }

    func submitDeletion() {
        guard let machine = s3Machine else {
            return
        }
        objectWillChange.send()
        switch machine.freezeSubmissionSnapshot() {
        case let .frozen(snapshot):
            do {
                let next = try S4StateMachine.start(
                    snapshot: snapshot,
                    claimAndPersist: claimS4
                )
                s4Machine = next
                message = nil
                deletionService.startDeletion(snapshot: snapshot) { [weak self] outcome in
                    Task { @MainActor [weak self] in
                        self?.receiveDeletionOutcome(
                            outcome,
                            submissionID: snapshot.submissionID
                        )
                    }
                }
                route = .execution
                startS4TimerIfNeeded()
            } catch {
                s3Machine = S3StateMachine(
                    assets: machine.assets,
                    cachedConclusions: machine.conclusionCache
                )
                message = "无法持久化提交快照：\(error.localizedDescription)"
            }

        case .rejected:
            message = "当前状态不能提交删除"
        }
    }

    func returnFromFailureToConfirmation() {
        guard var machine = s5Machine,
              case let .failed(context) = machine.state else {
            return
        }
        let cached = s3Machine?.conclusionCache
        let cacheExists = context.snapshot.assetIDs.allSatisfy { identifier in
            guard let conclusion = cached?[identifier] else {
                return false
            }
            return !conclusion.isIncomplete
        }

        do {
            let transition = try machine.handle(
                .returnToConfirmation(cacheExists: cacheExists),
                persist: persistS5
            )
            s5Machine = machine
            guard case let .returnToConfirmation(target, assetIDs) = transition.effect else {
                return
            }
            try persistence.clear()

            let descriptors = assetIDs.map { identifier in
                AssetDescriptor(
                    identifier: identifier,
                    isFavorite: context.snapshot.favoriteAssetIDs.contains(identifier)
                )
            }
            loadedAssets = photoLibrary.assetsByIdentifier(assetIDs)
            sessionDescriptors = Dictionary(
                uniqueKeysWithValues: descriptors.map { ($0.identifier, $0) }
            )
            let conclusions: [String: AssetScanConclusion]
            switch target {
            case .ready:
                conclusions = cached ?? [:]
            case .scanning:
                conclusions = [:]
            }
            s3Machine = S3StateMachine(
                assets: descriptors,
                cachedConclusions: conclusions
            )
            s4Machine = nil
            s5Machine = nil
            route = .confirmation
            message = nil
            beginPendingScans()
        } catch {
            message = "无法返回确认页：\(error.localizedDescription)"
        }
    }

    func leaveCompletion() {
        guard var machine = s5Machine else {
            return
        }
        do {
            let transition = try machine.handle(.leavePage, persist: persistS5)
            s5Machine = machine
            guard transition.effect == .exitCleanup else {
                return
            }
            finishSession()
        } catch {
            message = "无法结束清理会话：\(error.localizedDescription)"
        }
    }

    func setApplicationActive(_ isActive: Bool) {
        if route == .execution {
            if !isActive {
                advanceS4Clock()
                s4TimerTask?.cancel()
                s4TimerTask = nil
                s4LastUptime = nil
                guard route == .execution else {
                    return
                }
            }
            applyS4Event(
                isActive ? .applicationBecameActive : .applicationBecameInactive
            )
            if isActive, route == .execution {
                startS4TimerIfNeeded()
            }
        } else if route == .completion {
            applyS5LifecycleEvent(
                isActive ? .applicationBecameActive : .applicationBecameInactive
            )
        }
    }

    private var persistS4: (S4PersistentState) throws -> Void {
        { [persistence] state in
            try persistence.save(PersistedSession(s4: state))
        }
    }

    private var claimS4: (S4PersistentState) throws -> Bool {
        { [persistence] state in
            try persistence.claim(PersistedSession(s4: state))
        }
    }

    private var persistS5: (S5PersistentState) throws -> Void {
        { [persistence] state in
            try persistence.save(PersistedSession(s5: state))
        }
    }

    private func loadDebugAssets() async {
        let authorization = await photoLibrary.requestAuthorization()
        let assets: [PHAsset]
        switch authorization {
        case .authorized, .limited:
            assets = photoLibrary.firstImageAssets(limit: Self.debugAssetLimit)
            message = nil
        case .denied, .restricted:
            assets = []
            message = "照片库权限不可用"
        case .notDetermined:
            assets = []
            message = "照片库授权尚未完成"
        @unknown default:
            assets = []
            message = "无法识别照片库授权状态"
        }

        loadedAssets = Dictionary(
            uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) }
        )
        let descriptors = assets.map {
            AssetDescriptor(
                identifier: $0.localIdentifier,
                isFavorite: $0.isFavorite
            )
        }
        sessionDescriptors = Dictionary(
            uniqueKeysWithValues: descriptors.map { ($0.identifier, $0) }
        )
        s3Machine = S3StateMachine(assets: descriptors)
        s4Machine = nil
        s5Machine = nil
        route = .confirmation
        beginPendingScans()
    }

    private func beginPendingScans() {
        guard let machine = s3Machine else {
            return
        }
        let identifiers = machine.takePendingScanAssetIDs()
        for identifier in identifiers where scanTasks[identifier] == nil {
            scanTasks[identifier] = Task { [weak self] in
                guard let self else {
                    return
                }
                let conclusion: AssetScanConclusion
                if let asset = loadedAssets[identifier] {
                    conclusion = await sizeScanner.scan(asset)
                } else {
                    conclusion = .unavailable
                }
                applyScanConclusion(conclusion, to: identifier)
                scanTasks[identifier] = nil
            }
        }
    }

    private func applyScanConclusion(
        _ conclusion: AssetScanConclusion,
        to identifier: String
    ) {
        guard let machine = s3Machine else {
            return
        }
        objectWillChange.send()
        switch conclusion {
        case let .knownBytes(bytes):
            _ = machine.recordScanSuccess(for: identifier, byteCount: bytes)
        case .unavailable:
            _ = machine.recordScanFailure(for: identifier)
        case .notStarted, .inProgress:
            preconditionFailure("扫描服务只能返回终态结论")
        }
    }

    private func receiveDeletionOutcome(
        _ outcome: PhotoDeletionOutcome,
        submissionID: String
    ) {
        advanceS4Clock()
        guard s4Machine?.snapshot.submissionID == submissionID else {
            return
        }
        switch outcome {
        case let .success(receivedAt):
            applyS4Event(
                .successCallback(
                    submissionID: submissionID,
                    receivedAt: receivedAt
                )
            )
        case let .failure(callback):
            applyS4Event(.failureCallback(callback))
        }
    }

    private func applyS4Event(_ event: S4Event) {
        guard var machine = s4Machine else {
            return
        }
        do {
            let transition = try machine.handle(event, persist: persistS4)
            s4Machine = machine
            if case let .handoff(handoff) = transition.effect {
                enterCompletion(from: handoff)
            }
        } catch {
            message = "无法保存执行状态：\(error.localizedDescription)"
        }
    }

    @discardableResult
    private func enterCompletion(from handoff: S4Handoff) -> Bool {
        s4TimerTask?.cancel()
        s4TimerTask = nil
        s4LastUptime = nil
        do {
            let next = try S5StateMachine.enter(
                from: handoff,
                persist: persistS5,
                invalidateOldLists: { [weak self] identifiers in
                    guard let self else {
                        return
                    }
                    for identifier in identifiers {
                        loadedAssets.removeValue(forKey: identifier)
                        sessionDescriptors.removeValue(forKey: identifier)
                    }
                    s3Machine = nil
                }
            )
            s5Machine = next
            route = .completion
            message = nil
            return true
        } catch {
            message = "无法交接完成页：\(error.localizedDescription)"
            return false
        }
    }

    private func startS4TimerIfNeeded() {
        guard s4TimerTask == nil,
              let machine = s4Machine,
              machine.timeoutIsRunning,
              machine.isApplicationActive else {
            return
        }
        s4LastUptime = ProcessInfo.processInfo.systemUptime
        s4TimerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                guard let self else {
                    return
                }
                advanceS4Clock()
                if route != .execution || s4Machine?.timeoutIsRunning != true {
                    s4TimerTask = nil
                    s4LastUptime = nil
                    return
                }
            }
        }
    }

    private func advanceS4Clock() {
        guard route == .execution,
              s4Machine?.isApplicationActive == true,
              s4Machine?.timeoutIsRunning == true,
              let previous = s4LastUptime else {
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        s4LastUptime = now
        applyS4Event(.activeTimeAdvanced(max(0, now - previous)))
    }

    private func applyS5LifecycleEvent(_ event: S5Event) {
        guard var machine = s5Machine else {
            return
        }
        do {
            _ = try machine.handle(event, persist: persistS5)
            s5Machine = machine
        } catch {
            message = "无法保存完成页状态：\(error.localizedDescription)"
        }
    }

    private func finishSession() {
        do {
            try persistence.clear()
        } catch {
            message = "无法清理会话记录：\(error.localizedDescription)"
            return
        }
        s4TimerTask?.cancel()
        s4TimerTask = nil
        s4LastUptime = nil
        for task in scanTasks.values {
            task.cancel()
        }
        scanTasks.removeAll()
        loadedAssets.removeAll()
        sessionDescriptors.removeAll()
        s3Machine = nil
        s4Machine = nil
        s5Machine = nil
        route = .finished
        message = nil
    }

    private func restorePersistedSession() -> Bool {
        guard let persisted = persistence.load() else {
            try? persistence.clear()
            return false
        }
        guard let snapshot = persisted.snapshot.snapshot else {
            try? persistence.clear()
            return false
        }

        do {
            switch persisted.phase {
            case .submissionWaiting:
                let machine = try S4StateMachine.restore(
                    persistentState: S4PersistentState(
                        snapshot: snapshot,
                        state: .submitted,
                        activeElapsedSeconds: persisted.activeElapsedSeconds,
                        isApplicationActive: false,
                        timeoutIsRunning: false
                    ),
                    persist: persistS4
                )
                s4Machine = machine
                route = .execution
                applyS4Event(.applicationBecameActive)

            case .submissionSucceeded:
                guard let receivedAt = persisted.successReceivedAt else {
                    throw RestoreError.invalidRecord
                }
                guard enterCompletion(
                    from: .success(
                        snapshot: snapshot,
                        result: S4SuccessResult(
                            submissionID: snapshot.submissionID,
                            successfulAssetIDs: Set(snapshot.assetIDs),
                            receivedAt: receivedAt
                        )
                    )
                ) else {
                    throw RestoreError.invalidRecord
                }

            case .submissionFailed:
                guard let callback = persisted.failure?.callback else {
                    throw RestoreError.invalidRecord
                }
                guard enterCompletion(
                    from: .failure(snapshot: snapshot, callback: callback)
                ) else {
                    throw RestoreError.invalidRecord
                }

            case .submissionUnknown:
                guard let rawReason = persisted.unknownReason,
                      let reason = S4UnknownReason(rawValue: rawReason) else {
                    throw RestoreError.invalidRecord
                }
                guard enterCompletion(
                    from: .unknown(snapshot: snapshot, reason: reason)
                ) else {
                    throw RestoreError.invalidRecord
                }

            case .completionSuccess, .completionFailure, .completionUnknown:
                let state = try restoredCompletionState(
                    from: persisted,
                    snapshot: snapshot
                )
                s5Machine = try S5StateMachine.restore(
                    persistentState: S5PersistentState(
                        state: state,
                        isApplicationActive: true
                    ),
                    persist: persistS5
                )
                route = .completion
            }
            return true
        } catch {
            try? persistence.clear()
            message = "会话记录无法恢复，已重新载入测试资产"
            return false
        }
    }

    private func restoredCompletionState(
        from persisted: PersistedSession,
        snapshot: SubmissionSnapshot
    ) throws -> S5State {
        switch persisted.phase {
        case .completionSuccess:
            return .movedToRecentlyDeleted(
                S5SuccessContext(
                    snapshot: snapshot,
                    successfulAssetIDs: Set(snapshot.assetIDs)
                )
            )
        case .completionFailure:
            guard let callback = persisted.failure?.callback else {
                throw RestoreError.invalidRecord
            }
            return .failed(
                S5FailureContext(snapshot: snapshot, callback: callback)
            )
        case .completionUnknown:
            guard let rawReason = persisted.unknownReason,
                  let reason = S4UnknownReason(rawValue: rawReason) else {
                throw RestoreError.invalidRecord
            }
            return .unknown(
                S5UnknownContext(snapshot: snapshot, reason: reason)
            )
        default:
            throw RestoreError.invalidRecord
        }
    }
}

private enum RestoreError: Error {
    case invalidRecord
}
