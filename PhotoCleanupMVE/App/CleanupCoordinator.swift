import Combine
import Foundation
import Photos

enum CleanupRoute: Equatable {
    case loading
    case confirmation
    case execution
    case completion
    case finished
    case upstream
}

@MainActor
final class CleanupCoordinator: ObservableObject {
    static let debugAssetLimit = 300

    @Published private(set) var route: CleanupRoute = .loading
    @Published private(set) var s3Machine: S3StateMachine?
    @Published private(set) var s4Machine: S4StateMachine?
    @Published private(set) var s5Machine: S5StateMachine?
    @Published private(set) var message: String?
    private(set) var sessionStore: SessionStore?

    private let photoLibrary: PhotoLibraryService
    private let sizeScanner: AssetSizeScanner
    private let deletionService: any PhotoDeletionServicing
    private let freeDiskSpaceReader: FreeDiskSpaceReader
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
        deletionService: any PhotoDeletionServicing = DeletionServiceDependency.production(),
        freeDiskSpaceReader: FreeDiskSpaceReader = FreeDiskSpaceReader(),
        persistence: SessionPersistence = SessionPersistence()
    ) {
        self.photoLibrary = photoLibrary ?? PhotoLibraryService()
        self.sizeScanner = sizeScanner
        self.deletionService = deletionService
        self.freeDiskSpaceReader = freeDiskSpaceReader
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
        guard let returned = s3Machine?.makeUpstreamReturn() else {
            return
        }
        _ = handleS3Return(returned)
    }

    @discardableResult
    func handleS3Return(_ returned: S3UpstreamReturn) -> Bool {
        guard route == .confirmation,
              var store = sessionStore,
              store.applyS3Return(
                  .init(
                      sourceSessionID: returned.sourceSessionID,
                      currentPendingDeletionAssetIDs:
                          returned.currentPendingDeletionAssetIDs
                  )
              ) else {
            return false
        }

        sessionStore = store
        route = .upstream
        message = nil
        return true
    }

    @discardableResult
    func enterConfirmation(
        from submission: SessionStore.S3Submission,
        sessionStore: SessionStore,
        descriptors: [AssetDescriptor],
        cachedConclusions: [String: AssetScanConclusion] = [:]
    ) -> Bool {
        let descriptorIDs = descriptors.map(\.identifier)
        guard submission.sourceSessionID == sessionStore.sessionID,
              Set(submission.orderedAssetIDs).count ==
                  submission.orderedAssetIDs.count,
              Set(submission.orderedAssetIDs) ==
                  sessionStore.allPendingDeletionAssetIDs,
              Set(descriptorIDs).count == descriptorIDs.count,
              Set(descriptorIDs) == Set(submission.orderedAssetIDs) else {
            return false
        }

        let descriptorByID = Dictionary(
            uniqueKeysWithValues: descriptors.map { ($0.identifier, $0) }
        )
        let orderedDescriptors = submission.orderedAssetIDs.compactMap {
            descriptorByID[$0]
        }
        self.sessionStore = sessionStore
        sessionDescriptors = descriptorByID
        s3Machine = S3StateMachine(
            assets: orderedDescriptors,
            cachedConclusions: cachedConclusions,
            sourceSessionID: submission.sourceSessionID
        )
        s4Machine = nil
        s5Machine = nil
        route = .confirmation
        message = nil
        beginPendingScans()
        return true
    }

    func submitDeletion() {
        guard let machine = s3Machine else {
            return
        }
        objectWillChange.send()
        do {
            guard let next = try S4StateMachine.start(
                from: machine,
                deletionService: deletionService,
                claimAndPersist: claimS4
            ) else {
                message = L10n.text("coordinator.error.invalid_submission_state")
                return
            }
            s4Machine = next
            message = nil
            let snapshot = next.snapshot
            next.startDeletion { [weak self] outcome in
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
                cachedConclusions: machine.conclusionCache,
                sourceSessionID: machine.sourceSessionID
            )
            message = L10n.text(
                "coordinator.error.persist_submission_snapshot",
                replacing: ["error": error.localizedDescription]
            )
        }
    }

    func returnToConfirmation() {
        guard var machine = s5Machine else {
            return
        }
        let snapshot: SubmissionSnapshot
        switch machine.state {
        case let .cancelled(context):
            snapshot = context.snapshot
        case let .failed(context):
            snapshot = context.snapshot
        case .movedToRecentlyDeleted, .unknown:
            return
        }
        let cached = s3Machine?.conclusionCache
        let sourceSessionID = s3Machine?.sourceSessionID ??
            sessionStore?.sessionID ?? UUID().uuidString
        let cacheExists = snapshot.assetIDs.allSatisfy { identifier in
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
                    isFavorite: snapshot.favoriteAssetIDs.contains(identifier)
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
                cachedConclusions: conclusions,
                sourceSessionID: sourceSessionID
            )
            s4Machine = nil
            s5Machine = nil
            route = .confirmation
            message = nil
            beginPendingScans()
        } catch {
            message = L10n.text(
                "coordinator.error.return_to_confirmation",
                replacing: ["error": error.localizedDescription]
            )
        }
    }

    func confirmRecentlyDeletedCleared() {
        guard var machine = s5Machine else {
            return
        }
        do {
            _ = try machine.handle(
                .confirmRecentlyDeletedCleared(declaredAt: Date()),
                persist: persistS5,
                readFreeDiskStrictGB: freeDiskSpaceReader.freeDiskStrictGB
            )
            s5Machine = machine
            message = nil
        } catch {
            message = L10n.text(
                "coordinator.error.persist_completion_state",
                replacing: ["error": error.localizedDescription]
            )
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
            message = L10n.text(
                "coordinator.error.end_session",
                replacing: ["error": error.localizedDescription]
            )
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
            message = L10n.text("coordinator.authorization.unavailable")
        case .notDetermined:
            assets = []
            message = L10n.text("coordinator.authorization.not_completed")
        @unknown default:
            assets = []
            message = L10n.text("coordinator.authorization.unknown")
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
        var store = SessionStore(sessionID: UUID().uuidString)
        for descriptor in descriptors {
            store.setMarked(
                true,
                assetID: descriptor.identifier,
                rangeID: "debug"
            )
        }
        let submission = store.makeS3Submission { $0 }
        precondition(
            enterConfirmation(
                from: submission,
                sessionStore: store,
                descriptors: descriptors
            )
        )
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
            message = L10n.text(
                "coordinator.error.persist_execution_state",
                replacing: ["error": error.localizedDescription]
            )
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
                },
                readFreeDiskStrictGB: freeDiskSpaceReader.freeDiskStrictGB
            )
            s5Machine = next
            route = .completion
            message = nil
            return true
        } catch {
            message = L10n.text(
                "coordinator.error.enter_completion",
                replacing: ["error": error.localizedDescription]
            )
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
            message = L10n.text(
                "coordinator.error.persist_completion_state",
                replacing: ["error": error.localizedDescription]
            )
        }
    }

    private func finishSession() {
        do {
            try persistence.clear()
        } catch {
            message = L10n.text(
                "coordinator.error.clear_session_record",
                replacing: ["error": error.localizedDescription]
            )
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
        sessionStore = nil
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
                        timeoutIsRunning: false,
                        downstreamTargetState: nil
                    ),
                    persist: persistS4
                )
                s4Machine = machine
                route = .execution
                applyS4Event(.applicationBecameActive)

            case .submissionSucceeded:
                guard let receivedAt = persisted.successReceivedAt,
                      let target = persisted.downstreamTargetState.flatMap(
                        S4DownstreamTargetState.init(rawValue:)
                      ) else {
                    throw RestoreError.invalidRecord
                }
                guard enterCompletion(
                    from: .success(
                        snapshot: snapshot,
                        result: S4SuccessResult(
                            submissionID: snapshot.submissionID,
                            successfulAssetIDs: Set(snapshot.assetIDs),
                            receivedAt: receivedAt
                        ),
                        downstreamTargetState: target
                    )
                ) else {
                    throw RestoreError.invalidRecord
                }

            case .submissionFailed:
                guard let callback = persisted.failure?.callback,
                      let target = persisted.downstreamTargetState.flatMap(
                        S4DownstreamTargetState.init(rawValue:)
                      ) else {
                    throw RestoreError.invalidRecord
                }
                guard enterCompletion(
                    from: .failure(
                        snapshot: snapshot,
                        callback: callback,
                        downstreamTargetState: target
                    )
                ) else {
                    throw RestoreError.invalidRecord
                }

            case .submissionUnknown:
                guard let rawReason = persisted.unknownReason,
                      let reason = S4UnknownReason(rawValue: rawReason),
                      let target = persisted.downstreamTargetState.flatMap(
                        S4DownstreamTargetState.init(rawValue:)
                      ) else {
                    throw RestoreError.invalidRecord
                }
                guard enterCompletion(
                    from: .unknown(
                        snapshot: snapshot,
                        reason: reason,
                        downstreamTargetState: target
                    )
                ) else {
                    throw RestoreError.invalidRecord
                }

            case .completionSuccess,
                 .completionCancelled,
                 .completionFailure,
                 .completionUnknown:
                let state = try restoredCompletionState(
                    from: persisted,
                    snapshot: snapshot
                )
                s5Machine = try S5StateMachine.restore(
                    persistentState: S5PersistentState(
                        state: state,
                        isApplicationActive: true,
                        l3BaselineReading: persisted.l3BaselineReading,
                        l3CompletionReading: persisted.l3CompletionReading,
                        l3DeltaGB: persisted.l3DeltaGB,
                        recentlyDeletedClearedAt: persisted.recentlyDeletedClearedAt
                    ),
                    persist: persistS5
                )
                route = .completion
            }
            return true
        } catch {
            try? persistence.clear()
            message = L10n.text("coordinator.error.restore_session")
            return false
        }
    }

    private func restoredCompletionState(
        from persisted: PersistedSession,
        snapshot: SubmissionSnapshot
    ) throws -> S5State {
        guard let target = persisted.downstreamTargetState.flatMap(
            S4DownstreamTargetState.init(rawValue:)
        ) else {
            throw RestoreError.invalidRecord
        }

        switch target {
        case .movedToRecentlyDeleted:
            guard persisted.phase == .completionSuccess else {
                throw RestoreError.invalidRecord
            }
            return .movedToRecentlyDeleted(
                S5SuccessContext(
                    snapshot: snapshot,
                    successfulAssetIDs: Set(snapshot.assetIDs)
                )
            )
        case .cancelled:
            guard persisted.phase == .completionCancelled,
                  let callback = persisted.failure?.callback else {
                throw RestoreError.invalidRecord
            }
            return .cancelled(
                S5CancellationContext(snapshot: snapshot, callback: callback)
            )
        case .failed:
            guard persisted.phase == .completionFailure,
                  let callback = persisted.failure?.callback else {
                throw RestoreError.invalidRecord
            }
            return .failed(
                S5FailureContext(snapshot: snapshot, callback: callback)
            )
        case .unknown:
            guard persisted.phase == .completionUnknown,
                  let rawReason = persisted.unknownReason,
                  let reason = S4UnknownReason(rawValue: rawReason) else {
                throw RestoreError.invalidRecord
            }
            return .unknown(
                S5UnknownContext(snapshot: snapshot, reason: reason)
            )
        }
    }
}

private enum RestoreError: Error {
    case invalidRecord
}
