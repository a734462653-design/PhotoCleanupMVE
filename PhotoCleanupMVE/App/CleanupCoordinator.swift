import Combine
import Foundation
import Photos

enum CleanupRoute: Equatable {
    case loading
    case s1
    case s2
    case confirmation
    case execution
    case completion
    case finished
    case upstream
}

struct CleanupRouteConfiguration {
    let initialGroupingDimension: S1GroupingDimension
    let initialSortOrder: S1SortOrder
    let s2InitialPresentation: S2InitialPresentation

    static func ic048TemporaryWiringFixture() -> CleanupRouteConfiguration {
        return CleanupRouteConfiguration(
            initialGroupingDimension: .month,
            initialSortOrder: .newestFirst,
            s2InitialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            )
        )
    }
}

@MainActor
final class CleanupCoordinator: ObservableObject {
    @Published private(set) var route: CleanupRoute = .loading
    @Published private(set) var s1Machine: S1StateMachine?
    @Published private(set) var s2Machine: S2StateMachine?
    @Published private(set) var s3Machine: S3StateMachine?
    @Published private(set) var s3Groups: [SessionStore.S3Submission.Group] = []
    @Published private(set) var s4Machine: S4StateMachine?
    @Published private(set) var s5Machine: S5StateMachine?
    @Published private(set) var message: String?
    private(set) var sessionStore: SessionStore?
    let s2Calibration: S2CalibrationModel

    private let photoLibrary: PhotoLibraryService
    private let sizeScanner: AssetSizeScanner
    private let deletionService: any PhotoDeletionServicing
    private let assetActionService: any PhotoAssetActionServicing
    private let recentAlbumStore: any S2RecentAlbumStoring
    private let freeDiskSpaceReader: FreeDiskSpaceReader
    private let persistence: SessionPersistence
    private let routeConfiguration: CleanupRouteConfiguration

    private var loadedAssets: [String: PHAsset] = [:]
    private var sessionDescriptors: [String: AssetDescriptor] = [:]
    private var s2EntryContext: SessionStore.S2EntryContext?
    private var scanTasks: [String: Task<Void, Never>] = [:]
    private var s4TimerTask: Task<Void, Never>?
    private var s4LastUptime: TimeInterval?
    private var didStart = false

    init(
        photoLibrary: PhotoLibraryService? = nil,
        sizeScanner: AssetSizeScanner = AssetSizeScanner(),
        deletionService: any PhotoDeletionServicing = DeletionServiceDependency.production(),
        assetActionService: any PhotoAssetActionServicing =
            PhotoKitAssetActionService(),
        recentAlbumStore: any S2RecentAlbumStoring =
            S2UserDefaultsRecentAlbumStore(),
        freeDiskSpaceReader: FreeDiskSpaceReader = FreeDiskSpaceReader(),
        persistence: SessionPersistence = SessionPersistence(),
        routeConfiguration: CleanupRouteConfiguration =
            .ic048TemporaryWiringFixture(),
        s2CalibrationPersistence: any S2CalibrationPersisting =
            S2KeychainCalibrationPersistence()
    ) {
        self.photoLibrary = photoLibrary ?? PhotoLibraryService()
        self.sizeScanner = sizeScanner
        self.deletionService = deletionService
        self.assetActionService = assetActionService
        self.recentAlbumStore = recentAlbumStore
        self.freeDiskSpaceReader = freeDiskSpaceReader
        self.persistence = persistence
        self.routeConfiguration = routeConfiguration
        s2Calibration = S2CalibrationModel(
            persistence: s2CalibrationPersistence
        )
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
            await self?.prepareS1AfterAuthorizationRequest()
        }
    }

    @discardableResult
    func enterS1(sessionID: String) -> Bool {
        guard !sessionID.isEmpty else {
            return false
        }
        installS1Session(
            SessionStore(sessionID: sessionID),
            route: .s1
        )
        return true
    }

    func readS1Ranges(
        groupedBy groupingDimension: S1GroupingDimension
    ) -> Result<[S1Range], S1RangeReadFailure> {
        photoLibrary.s1Ranges(groupedBy: groupingDimension)
    }

    @discardableResult
    func enterS2(from handoff: S1ToS2Handoff) -> Bool {
        guard route == .s1 || route == .upstream || route == .finished,
              let s1Machine,
              handoff.sessionID == s1Machine.sessionStore.sessionID else {
            return false
        }

        let entryContext = SessionStore.S2EntryContext(
            rangeID: handoff.rangeDisplayInformation.rangeID,
            orderedAssetIDs: handoff.orderedAssetIDs,
            sortOrder: s1Machine.sortOrder.sessionSortOrder
        )
        let fetchedAssets = photoLibrary.assetsByIdentifier(
            handoff.orderedAssetIDs
        )
        loadedAssets.merge(fetchedAssets) { _, newValue in newValue }
        let favoriteAssetIDs = Set(
            fetchedAssets.values.filter(\.isFavorite).map(\.localIdentifier)
        )
        guard let resolvedParameters =
                s2Calibration.configuration.resolvedParameters else {
            return false
        }
        let machine = S2StateMachine(
            entry: S2EntryContext(handoff: handoff),
            initialPresentation: routeConfiguration.s2InitialPresentation,
            parameters: resolvedParameters,
            imageRequestStrategy:
                s2Calibration.configuration.imageRequestStrategy,
            initialFavoriteAssetIDs: favoriteAssetIDs,
            initialRecentAlbum: validatedRecentAlbum(),
            pendingDeletionDidChange: { [weak self] pendingAssetIDs in
                self?.receiveS2PendingDeletionChange(pendingAssetIDs)
            },
            recentAlbumDidChange: { [weak self] album in
                self?.recentAlbumStore.save(album)
            }
        )
        guard let machine else {
            return false
        }

        s2EntryContext = entryContext
        s2Machine = machine
        route = .s2
        message = nil
        return true
    }

    @discardableResult
    func leaveS2(with payload: S2ExitPayload) -> Bool {
        guard applyS2ExitPayload(payload) else {
            return false
        }
        clearS2RouteState()
        route = .s1
        message = nil
        return true
    }

    @discardableResult
    func enterConfirmationFromS2(with payload: S2ExitPayload) -> Bool {
        guard applyS2ExitPayload(payload),
              let submission = s1Machine?.makeS3Submission() else {
            return false
        }
        clearS2RouteState()
        return enterConfirmationFromS1(submission)
    }

    @discardableResult
    func enterConfirmationFromS1(
        _ submission: SessionStore.S3Submission
    ) -> Bool {
        guard let s1Machine,
              submission == s1Machine.makeS3Submission() else {
            return false
        }
        let descriptors = descriptorsForS3(
            orderedAssetIDs: submission.orderedAssetIDs
        )
        let cachedConclusions: [String: AssetScanConclusion]
        if s3Machine?.sourceSessionID == submission.sourceSessionID {
            cachedConclusions = s3Machine?.conclusionCache ?? [:]
        } else {
            cachedConclusions = [:]
        }
        return enterConfirmation(
            from: submission,
            sessionStore: s1Machine.sessionStore,
            descriptors: descriptors,
            cachedConclusions: cachedConclusions
        )
    }

    func s2AssetAspectRatio(for assetID: String) -> CGFloat {
        guard let asset = loadedAssets[assetID],
              asset.pixelWidth > 0,
              asset.pixelHeight > 0 else {
            return 1
        }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    func s2AssetPixelSize(for assetID: String) -> CGSize {
        guard let asset = loadedAssets[assetID] else {
            return .zero
        }
        return CGSize(
            width: CGFloat(max(0, asset.pixelWidth)),
            height: CGFloat(max(0, asset.pixelHeight))
        )
    }

    func s2AssetIsScreenshot(for assetID: String) -> Bool {
        loadedAssets[assetID]?.mediaSubtypes.contains(.photoScreenshot) == true
    }

    /// IC-099 阶段二 R1：当前资产的拍摄日期（顶部信息区主行）。
    func s2AssetCreationDate(for assetID: String) -> Date? {
        loadedAssets[assetID]?.creationDate
    }

    /// IC-099 阶段二 R4：占用空间取数实现。构造时快照一份 `loadedAssets`。
    func makeS2AssetVolumeProvider() -> S2AssetVolumeProviding {
        AssetVolumeService(assets: loadedAssets)
    }

    /// IC-099b R2：字节数探针的取数实现。按下按钮时才现造，
    /// 构造时快照一份 `loadedAssets`，取数期间不再回到主线程读协调器状态。
    func makeS2AssetSizeProber() -> S2AssetSizeProbing {
        AssetSizeProbeService(assets: loadedAssets)
    }

    // MARK: - S2 操作条写入（IC-076）

    /// 相簿选择 sheet 的内容：用户相册（`.album` / `.albumRegular`），按系统返回顺序。
    func s2UserAlbums() -> [S2AlbumReference] {
        assetActionService.userAlbums()
    }

    /// 收藏：点击时由状态机登记进行中（`x` 已绑定在 `request` 中），结果回主线程后
    /// 作用于同一台状态机与同一 `request`；S2 已离开则丢弃结果。
    @discardableResult
    func requestS2FavoriteToggle(_ request: S2AssetActionRequest) -> Bool {
        guard route == .s2,
              let machine = s2Machine,
              machine.beginFavoriteToggle(request) else {
            return false
        }
        assetActionService.toggleFavorite(
            assetID: request.targetAssetID
        ) { [weak self] succeeded in
            Self.deliverOnMain {
                guard let self, self.s2Machine === machine else {
                    return
                }
                _ = machine.completeFavoriteToggle(
                    request,
                    succeeded: succeeded
                )
            }
        }
        return true
    }

    @discardableResult
    func requestS2RecentAlbumAddition(_ request: S2AlbumActionRequest) -> Bool {
        guard route == .s2,
              let machine = s2Machine,
              machine.beginRecentAlbumAddition(request) else {
            return false
        }
        assetActionService.addAsset(
            assetID: request.targetAssetID,
            toAlbumWithID: request.album.id
        ) { [weak self] outcome in
            Self.deliverOnMain {
                guard let self, self.s2Machine === machine else {
                    return
                }
                _ = machine.completeRecentAlbumAddition(
                    request,
                    outcome: outcome
                )
            }
        }
        return true
    }

    @discardableResult
    func requestS2AlbumPickerSelection(
        _ request: S2AlbumPickerRequest,
        album: S2AlbumReference
    ) -> Bool {
        guard route == .s2,
              let machine = s2Machine,
              machine.beginAlbumPickerSelection(request, album: album) else {
            return false
        }
        assetActionService.addAsset(
            assetID: request.targetAssetID,
            toAlbumWithID: album.id
        ) { [weak self] outcome in
            Self.deliverOnMain {
                guard let self, self.s2Machine === machine else {
                    return
                }
                _ = machine.completeAlbumPickerSelection(
                    request,
                    album: album,
                    outcome: outcome
                )
            }
        }
        return true
    }

    /// 进入 S2 时读取持久化的 `H` 并用服务校验相册仍存在；不存在则清除持久化值。
    /// 校验是本地元数据查询，在 `enterS2` 内同步完成。
    private func validatedRecentAlbum() -> S2AlbumReference? {
        guard let stored = recentAlbumStore.load() else {
            return nil
        }
        guard assetActionService.albumExists(id: stored.id) else {
            recentAlbumStore.save(nil)
            return nil
        }
        return stored
    }

    /// 服务回调可能来自任意线程：已在主线程则同步交付，否则切回主线程。
    nonisolated private static func deliverOnMain(
        _ body: @escaping @MainActor () -> Void
    ) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                body()
            }
        } else {
            Task { @MainActor in
                body()
            }
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
        let sessionReturn = SessionStore.S3Return(
            sourceSessionID: returned.sourceSessionID,
            currentPendingDeletionAssetIDs:
                returned.currentPendingDeletionAssetIDs
        )
        guard route == .confirmation,
              var store = sessionStore,
              store.applyS3Return(sessionReturn) else {
            return false
        }
        if let s1Machine {
            guard s1Machine.sessionStore == sessionStore,
                  s1Machine.applyS3Return(sessionReturn),
                  s1Machine.sessionStore == store else {
                return false
            }
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
        let groupRangeIDs = submission.groups.map(\.sourceRangeID)
        let groupedAssetIDs = submission.groups.flatMap(\.orderedAssetIDs)
        guard submission.sourceSessionID == sessionStore.sessionID,
              Set(submission.orderedAssetIDs).count ==
                  submission.orderedAssetIDs.count,
              Set(submission.orderedAssetIDs) ==
                  sessionStore.allPendingDeletionAssetIDs,
              Set(descriptorIDs).count == descriptorIDs.count,
              Set(descriptorIDs) == Set(submission.orderedAssetIDs),
              Set(groupRangeIDs).count == groupRangeIDs.count,
              submission.groups.allSatisfy({ group in
                  !group.sourceRangeID.isEmpty &&
                      !group.name.trimmingCharacters(
                          in: .whitespacesAndNewlines
                      ).isEmpty &&
                      !group.orderedAssetIDs.isEmpty &&
                      Set(group.orderedAssetIDs).count ==
                          group.orderedAssetIDs.count
              }),
              groupedAssetIDs.count == submission.orderedAssetIDs.count,
              Set(groupedAssetIDs) == Set(submission.orderedAssetIDs) else {
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
        s3Groups = submission.groups
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

    private func prepareS1AfterAuthorizationRequest() async {
        _ = await photoLibrary.requestAuthorization()
        guard route == .loading else {
            return
        }
        _ = enterS1(sessionID: UUID().uuidString)
    }

    private func installS1Session(
        _ store: SessionStore,
        route targetRoute: CleanupRoute
    ) {
        for task in scanTasks.values {
            task.cancel()
        }
        scanTasks.removeAll()
        s4TimerTask?.cancel()
        s4TimerTask = nil
        s4LastUptime = nil
        loadedAssets.removeAll()
        sessionDescriptors.removeAll()
        sessionStore = store
        s1Machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension:
                routeConfiguration.initialGroupingDimension,
            initialSortOrder: routeConfiguration.initialSortOrder
        )
        s2Machine = nil
        s2EntryContext = nil
        s3Machine = nil
        s3Groups = []
        s4Machine = nil
        s5Machine = nil
        route = targetRoute
        message = nil
    }

    private func receiveS2PendingDeletionChange(
        _ pendingDeletionAssetIDs: Set<String>
    ) {
        guard route == .s2,
              let s1Machine,
              let s2EntryContext,
              s1Machine.applyS2PendingDeletionChange(
                  pendingDeletionAssetIDs,
                  entryContext: s2EntryContext
              ) else {
            return
        }
        sessionStore = s1Machine.sessionStore
    }

    private func applyS2ExitPayload(_ payload: S2ExitPayload) -> Bool {
        guard route == .s2,
              let s1Machine,
              let entryContext = s2EntryContext,
              payload.continuationSnapshot.orderedAssetIDs ==
                  entryContext.orderedAssetIDs,
              payload.continuationSnapshot.rangeDisplayInformation.rangeID ==
                  entryContext.rangeID,
              payload.continuationSnapshot.pendingDeletionAssetIDs ==
                  payload.upstreamReturn.pendingDeletionAssetIDs,
              payload.continuationSnapshot.currentAssetID ==
                  payload.upstreamReturn.currentAssetID,
              s1Machine.applyS2Return(
                  payload.upstreamReturn,
                  entryContext: entryContext
              ) else {
            return false
        }
        sessionStore = s1Machine.sessionStore
        return true
    }

    private func clearS2RouteState() {
        s2Machine = nil
        s2EntryContext = nil
    }

    private func descriptorsForS3(
        orderedAssetIDs: [String]
    ) -> [AssetDescriptor] {
        let fetchedAssets = photoLibrary.assetsByIdentifier(orderedAssetIDs)
        loadedAssets.merge(fetchedAssets) { _, newValue in newValue }
        return orderedAssetIDs.map { identifier in
            AssetDescriptor(
                identifier: identifier,
                isFavorite: loadedAssets[identifier]?.isFavorite ??
                    sessionDescriptors[identifier]?.isFavorite ?? false
            )
        }
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
        let expiredSessionID = sessionStore?.sessionID
        var nextSessionID = UUID().uuidString
        while nextSessionID == expiredSessionID {
            nextSessionID = UUID().uuidString
        }
        installS1Session(
            SessionStore(sessionID: nextSessionID),
            route: .finished
        )
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
