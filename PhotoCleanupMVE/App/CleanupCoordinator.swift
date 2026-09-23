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
            // IC-127 B（未定项 1）：首次安装无档时的默认值——按日期 + 最新在前。
            initialGroupingDimension: .date,
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
    /// IC-131 B：供 S1 视图观察的一次性「写回失败」事件通道。与持久型 `message`
    /// 分开——`message` 会一直挂着，与「短 toast」语义相反。事件在通道里等到
    /// S1 视图出现为止，由视图取走后经 `consumeS1FeedbackEvent()` 清空。
    @Published private(set) var s1FeedbackEvent: S1FeedbackEvent?
    /// 已发出的写回失败事件总数（测试用；`id` 亦取此序号）。
    private(set) var s1FeedbackEventCount = 0
    /// IC-168 B（裁定 一）：上一次离开 S2（返回键或右上垃圾桶）的诊断文本，全 ASCII、逐行
    /// `key=value`。每次离开都覆写，成功也写。由协调器持有而不放进 S2 视图：回落恰发生在
    /// 离开 S2 的那一刻，视图的状态对象随路由销毁；S2 标定面板末段显示并可复制。
    @Published private(set) var s2ExitDiagnosticsText: String?
    private(set) var sessionStore: SessionStore?
    let s2Calibration: S2CalibrationModel

    private let photoLibrary: PhotoLibraryService
    private let sizeScanner: AssetSizeScanner
    private let deletionService: any PhotoDeletionServicing
    private let assetActionService: any PhotoAssetActionServicing
    private let recentAlbumStore: any S2RecentAlbumStoring
    private let persistence: SessionPersistence
    private let routeConfiguration: CleanupRouteConfiguration

    private var loadedAssets: [String: PHAsset] = [:]
    private var sessionDescriptors: [String: AssetDescriptor] = [:]
    private var s2EntryContext: SessionStore.S2EntryContext?
    /// IC-168 B：`enterConfirmationFromS1` 最近一次的拒绝点（成功为 nil），供垃圾桶路径 E3 定名。
    private var lastS3EntryGuardFailure: S2ExitDiagnosticGuard?
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

    /// IC-127 B（未定项 11）：由 S1 会话档恢复进入 S1。坏档（不变量不成立）返回 false，
    /// 调用方回退到新会话。恢复出的状态机以 loading 起步，首次读取内先对账再可见。
    @discardableResult
    func enterS1(restoring snapshot: S1SessionSnapshot) -> Bool {
        guard let machine = S1StateMachine.restore(from: snapshot) else {
            return false
        }
        installS1Session(machine, route: .s1)
        return true
    }

    /// IC-127 B：启动落点。有档且可恢复 → 恢复同一 `sessionID` 与 `T`／`O`；
    /// 无档或坏档 → 清档并以默认 `T=date`、`O=newestFirst` 开新会话。
    @discardableResult
    func enterS1ResumingPersistedSessionOrStartNew() -> Bool {
        if let snapshot = persistence.loadS1Session(),
           enterS1(restoring: snapshot) {
            return true
        }
        try? persistence.clearS1Session()
        return enterS1(sessionID: UUID().uuidString)
    }

    /// IC-127 D：读取回应（结果 + 受限标志）。`S1View` 的读取方直接用本方法。
    func readS1Ranges(
        groupedBy groupingDimension: S1GroupingDimension
    ) -> S1RangeReadResponse {
        photoLibrary.s1RangeRead(groupedBy: groupingDimension)
    }

    /// IC-127 C（未定项 13）：从 S2 返回时的对账——重读 `R(T)`，交给状态机的
    /// 单一对账入口；静默完成，不改 `message`。进入 S1 那一次对账由首次读取
    /// （`S1StateMachine.completeRangeRead`）内的同一入口完成。
    @discardableResult
    func reconcileS1WithPhotoLibrary() -> Bool {
        guard let s1Machine else {
            return false
        }
        let response = photoLibrary.s1RangeRead(
            groupedBy: s1Machine.groupingDimension
        )
        let reconciled = s1Machine.reconcile(
            with: response.result,
            isLimitedAuthorization: response.isLimitedAuthorization
        )
        sessionStore = s1Machine.sessionStore
        return reconciled
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
        // IC-168 B（裁定 一）：诊断字段在写回校验之前取样——写回成功后在途登记即被移除、
        // 入口上下文随后被清空，回落之后再读活状态就读不到离开那一刻的样子了。
        let sample = sampleS2Exit(payload)
        guard applyS2ExitPayload(payload) else {
            let failure = sample.writeBackFailure
            let reconciled = returnToS1AfterFailedWriteBack()
            recordS2ExitDiagnostics(
                entry: "back",
                sample: sample,
                payload: payload,
                reconciled: reconciled,
                outcome: "writeBackFailed",
                failure: failure
            )
            return false
        }
        clearS2RouteState()
        // IC-127 C：从 S2 返回时对账一次（静默）。
        let reconciled = reconcileS1WithPhotoLibrary()
        route = .s1
        message = nil
        recordS2ExitDiagnostics(
            entry: "back",
            sample: sample,
            payload: payload,
            reconciled: reconciled,
            outcome: "ok",
            failure: nil
        )
        return true
    }

    /// IC-131 B：S1 视图取走事件后清空通道，避免下次进入 S1 重复弹出。
    func consumeS1FeedbackEvent() {
        s1FeedbackEvent = nil
    }

    /// IC-131 B（v8 回写决策 29）：写回校验失败后的收场。**不写回**——该范围的
    /// `M`、`K` 保持上一次有效值；但照常离开 S2 回到 S1 并对账一次，再发一条
    /// 一次性事件由 S1 以底部短 toast 呈现。不弹窗、不阻断：用户点了返回就该
    /// 回到 S1，原实装让 `route` 停在 `.s2` 且毫无反馈。
    ///
    /// IC-168 A（裁定 二）：虚拟范围写回失败时在途登记不再留着——先撤销，再清入口上下文
    /// （撤销要读它的范围标识）。真实范围标识不在登记里，撤销是无操作。
    ///
    /// IC-168 B（裁定 一）：回传收场里那一次对账的结果，两条入口都记进诊断文本的
    /// `reconciled`。步骤与先后不变。
    private func returnToS1AfterFailedWriteBack() -> Bool {
        if let entryContext = s2EntryContext {
            s1Machine?.cancelS2Handoff(virtualRangeID: entryContext.rangeID)
        }
        clearS2RouteState()
        let reconciled = reconcileS1WithPhotoLibrary()
        route = .s1
        message = nil
        publishS1FeedbackEvent(.writeBackFailed)
        return reconciled
    }

    /// IC-132 B：写回**已生效**、但提交形成不了时的收场。与
    /// `returnToS1AfterFailedWriteBack()` 的区别只在写回结果——那条是没写回，
    /// 这条 `M`／`K` 已更新并保留。调用方此前已 `clearS2RouteState()` 并对过账，
    /// 这里只补路由收口与反馈，避免 `route` 停在 `.s2` 而 `s2Machine` 已为 nil
    /// （App 的 `case .s2` 会落到一个退不出的 ProgressView）。
    private func returnToS1AfterUnavailableSubmission() {
        route = .s1
        message = nil
        publishS1FeedbackEvent(.submissionUnavailable)
    }

    private func publishS1FeedbackEvent(_ kind: S1FeedbackEventKind) {
        s1FeedbackEventCount += 1
        s1FeedbackEvent = S1FeedbackEvent(
            id: s1FeedbackEventCount,
            kind: kind
        )
    }

    @discardableResult
    func enterConfirmationFromS2(with payload: S2ExitPayload) -> Bool {
        // IC-168 B（裁定 一）：取样在写回校验之前，理由同 `leaveS2(with:)`。
        let sample = sampleS2Exit(payload)
        guard applyS2ExitPayload(payload) else {
            // IC-131 B：垃圾桶路径失败同样回到 S1 并发 toast，**不进入 S3**
            // （不形成提交）——④决策会话裁定，依据决策 29「不阻断」。
            let failure = sample.writeBackFailure
            let reconciled = returnToS1AfterFailedWriteBack()
            recordS2ExitDiagnostics(
                entry: "trash",
                sample: sample,
                payload: payload,
                reconciled: reconciled,
                outcome: "writeBackFailed",
                failure: failure
            )
            return false
        }
        clearS2RouteState()
        // IC-127 C：S2 经垃圾桶直入 S3 同样是「从 S2 返回」——先对账再形成提交，
        // 已被系统删除的资产不进入 D_全部。
        let reconciled = reconcileS1WithPhotoLibrary()
        guard let submission = s1Machine?.makeS3Submission() else {
            // IC-132 B：写回已生效，只是提交形成不了（典型是恢复出的名字表为空）。
            // 原实装直接 return false，`route` 停在 `.s2` 而 `s2Machine` 已 nil，
            // 界面卡在退不出的转圈上。
            recordS2ExitDiagnostics(
                entry: "trash",
                sample: sample,
                payload: payload,
                reconciled: reconciled,
                outcome: "submissionUnavailable",
                failure: sample.submissionFailure
            )
            returnToS1AfterUnavailableSubmission()
            return false
        }
        guard enterConfirmationFromS1(submission) else {
            // IC-132 B：事件已由 `enterConfirmationFromS1` 发出，这里只补路由收口，
            // 不重复发第二条。
            recordS2ExitDiagnostics(
                entry: "trash",
                sample: sample,
                payload: payload,
                reconciled: reconciled,
                outcome: "confirmationRejected",
                failure: lastS3EntryGuardFailure
            )
            route = .s1
            message = nil
            return false
        }
        recordS2ExitDiagnostics(
            entry: "trash",
            sample: sample,
            payload: payload,
            reconciled: reconciled,
            outcome: "ok",
            failure: nil
        )
        return true
    }

    @discardableResult
    func enterConfirmationFromS1(
        _ submission: SessionStore.S3Submission
    ) -> Bool {
        guard let s1Machine,
              submission == s1Machine.makeS3Submission() else {
            // IC-168 B：诊断用的拒绝点（含 `s1Machine` 为 nil），不改原有收场。
            lastS3EntryGuardFailure = .C2
            // IC-132 B：不再静默失败。S1 视图此刻已挂载，事件立即被取走显示。
            publishS1FeedbackEvent(.submissionUnavailable)
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
        guard enterConfirmation(
            from: submission,
            sessionStore: s1Machine.sessionStore,
            descriptors: descriptors,
            cachedConclusions: cachedConclusions
        ) else {
            // IC-168 B：确认页校验未过——同一份纯判定再取一次拒绝点（上面那次调用未写任何状态）。
            lastS3EntryGuardFailure = Self.s3EntryGuardFailure(
                submission: submission,
                sessionStore: s1Machine.sessionStore,
                descriptors: descriptors
            )
            publishS1FeedbackEvent(.submissionUnavailable)
            return false
        }
        lastS3EntryGuardFailure = nil
        return true
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

    /// IC-139 A（v19 回写决策 54）：当前资产的媒体类别 `m`。
    ///
    /// 判别逻辑不在这里重写——`AssetSizeProbeService.mediaKind(of:)` 已经是
    /// 全仓唯一一处「视频 / 实况 / 照片」判别（`Services/AssetSizeScanner.swift`），
    /// 本方法只做类别到 S2 展示语汇的映射。资产不在册时按 `photo` 退化，
    /// 与同族三个访问器（像素尺寸、截图、拍摄日期）的失败口径一致。
    func s2AssetMediaKind(for assetID: String) -> S2MediaKind {
        guard let asset = loadedAssets[assetID] else {
            return .photo
        }
        return S2MediaKind(probeKind: AssetSizeProbeService.mediaKind(of: asset))
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

    /// IC-114 C：相簿选择器列表项（含数量与键图）。
    func s2UserAlbumItems() -> [S2AlbumListItem] {
        assetActionService.userAlbumItems()
    }

    /// IC-114 C：新建相簿。只创建，不加成员——加成员由视图随后走既有的
    /// 选择路径完成，从而复用「最近相簿更新 + 首次入场时序 + 残影」全套。
    /// 失败走既有反馈通道。
    func requestS2AlbumCreation(
        named name: String,
        completion: @escaping (S2AlbumReference?) -> Void
    ) {
        guard route == .s2, let machine = s2Machine else {
            completion(nil)
            return
        }
        assetActionService.createAlbum(named: name) { [weak self] album in
            Self.deliverOnMain {
                guard let self, self.s2Machine === machine else {
                    completion(nil)
                    return
                }
                if album == nil {
                    machine.reportAlbumCreationFailure()
                }
                completion(album)
            }
        }
    }

    /// IC-113 B：中央指示「撤回」——把资产从相簿移除。
    /// 与加入同构：状态机登记在途 → 服务写入 → 主线程回结果。
    @discardableResult
    func requestS2AlbumRemoval(_ request: S2AlbumActionRequest) -> Bool {
        guard route == .s2,
              let machine = s2Machine,
              machine.beginAlbumRemoval(request) else {
            return false
        }
        assetActionService.removeAsset(
            assetID: request.targetAssetID,
            fromAlbumWithID: request.album.id
        ) { [weak self] succeeded in
            Self.deliverOnMain {
                guard let self, self.s2Machine === machine else {
                    return
                }
                _ = machine.completeAlbumRemoval(
                    request,
                    succeeded: succeeded
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
        // IC-168 B（裁定 一）：九条子句顺序化搬进 `s3EntryGuardFailure`，任一不成立即拒绝；
        // 判定在一切写入之前、无副作用，行为逐位不变。
        guard Self.s3EntryGuardFailure(
            submission: submission,
            sessionStore: sessionStore,
            descriptors: descriptors
        ) == nil else {
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
        // IC-127 B：启动时优先恢复 S1 会话档。
        _ = enterS1ResumingPersistedSessionOrStartNew()
    }

    private func installS1Session(
        _ store: SessionStore,
        route targetRoute: CleanupRoute
    ) {
        installS1Session(
            S1StateMachine(
                sessionStore: store,
                initialGroupingDimension:
                    routeConfiguration.initialGroupingDimension,
                initialSortOrder: routeConfiguration.initialSortOrder
            ),
            route: targetRoute
        )
    }

    /// IC-127 B：安装状态机的单一入口（新会话与档恢复共用），并把会话快照的
    /// 单一写出口接到持久层。写档失败静默忽略——持久化不得阻断整理流程。
    private func installS1Session(
        _ machine: S1StateMachine,
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
        sessionStore = machine.sessionStore
        machine.persistenceSink = { [persistence] snapshot in
            _ = try? persistence.saveS1Session(snapshot)
        }
        // IC-129：把「按资产标识批量查存在性」接到对账——进入 S1 的首次读取与
        // S2 返回两处对账共用状态机内的同一收敛点，故在安装状态机时注入。
        // 探针只在主线程的对账路径内被同步调用。
        machine.assetExistenceProbe = { [photoLibrary] identifiers in
            MainActor.assumeIsolated {
                photoLibrary.existingAssetIdentifiers(among: identifiers)
            }
        }
        s1Machine = machine
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
        // IC-168 B（裁定 一）：W1～W7 顺序化搬进 `s2ExitGuardFailure`（纯判定）；全过才调 W8
        // 写回，短路顺序与原来的八子句 `guard` 相同。
        guard s2ExitGuardFailure(payload) == nil,
              let s1Machine,
              let entryContext = s2EntryContext else {
            return false
        }
        guard s1Machine.applyS2Return(
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

    // MARK: - IC-168 B：离开 S2 的诊断（裁定 一）

    /// 回落守卫名。隐式原始值即 case 名（源码零字面量——扫描器把 `return` 后紧跟的字面量判残留）。
    /// W1～W8b = 写回校验（E1）；M0～M3 = 提交形成（E2）；C2、V1～V9 = 确认页入口校验（E3）。
    private enum S2ExitDiagnosticGuard: String {
        case W1, W2, W3, W4, W5, W6, W7, W8a, W8b, M0, M1, M2, M3, C2, V1, V2, V3, V4, V5, V6, V7, V8, V9
    }

    /// 离开 S2 那一刻（写回校验之前）的取样。依赖 S1 状态机的项在它为 nil 时取 nil，文本里打 `na`。
    private struct S2ExitSample {
        let route: CleanupRoute
        let loadingState: S1LoadingState?
        let isObscured: Bool?
        let stateIsReady: Bool?
        let rangeID: String
        let inflight: Bool?
        let inflightCount: Int?
        let ordered: Int
        let currentInList: Bool
        let snapshotPending: Int
        let returnedPending: Int
        let sessionMatch: Bool?
        let dAll: Int?
        let f: Int?
        let rangesWithPending: Int?
        /// W1～W7 第一个不成立的子句；全过为 nil。
        let preApplyFailure: S2ExitDiagnosticGuard?

        /// E1 定名：W1～W7 之一；全过而写回仍失败则是 W8——既不在途也不就绪为 W8a，
        /// 否则会话档拒绝写回为 W8b。只从取样判，不重抄 S1 状态机的活谓词。
        var writeBackFailure: S2ExitDiagnosticGuard {
            if let preApplyFailure {
                return preApplyFailure
            }
            let admitted = (inflight ?? false)
                || (!(isObscured ?? true) && (stateIsReady ?? false))
            return admitted ? .W8b : .W8a
        }

        /// E2 定名：S1 状态机缺失 M0、遮挡 M1、仍在加载 M2，其余是名字表缺名 M3。
        var submissionFailure: S2ExitDiagnosticGuard {
            if loadingState == nil {
                return .M0
            }
            if isObscured == true {
                return .M1
            }
            if loadingState == .loading {
                return .M2
            }
            return .M3
        }
    }

    /// 只读不写。在两条入口的第一句调用。
    private func sampleS2Exit(_ payload: S2ExitPayload) -> S2ExitSample {
        let snapshot = payload.continuationSnapshot
        let rangeID = s2EntryContext?.rangeID
            ?? snapshot.rangeDisplayInformation.rangeID
        let store = s1Machine?.sessionStore
        return S2ExitSample(
            route: route,
            loadingState: s1Machine?.loadingState,
            isObscured: s1Machine?.isObscured,
            stateIsReady: s1Machine.map { $0.state == .ready },
            rangeID: rangeID,
            inflight: s1Machine?.activeVirtualRangeIDs.contains(rangeID),
            inflightCount: s1Machine?.activeVirtualRangeIDs.count,
            ordered: snapshot.orderedAssetIDs.count,
            currentInList: snapshot.orderedAssetIDs.contains(snapshot.currentAssetID),
            snapshotPending: snapshot.pendingDeletionAssetIDs.count,
            returnedPending: payload.upstreamReturn.pendingDeletionAssetIDs.count,
            sessionMatch: store.map {
                payload.upstreamReturn.sourceSessionID == $0.sessionID
            },
            dAll: store?.allPendingDeletionAssetIDs.count,
            f: store?.firstMarkedRangeIDByAssetID.count,
            rangesWithPending: store?.pendingDeletionAssetIDsByRangeID.values
                .filter { !$0.isEmpty }
                .count,
            preApplyFailure: s2ExitGuardFailure(payload)
        )
    }

    /// 写回校验 W1～W7 按原 `guard` 子句顺序逐条判定，第一个不成立即返回其名；全过返回 nil。
    /// 纯判定、无副作用；W8（写回本身）不在这里。
    private func s2ExitGuardFailure(
        _ payload: S2ExitPayload
    ) -> S2ExitDiagnosticGuard? {
        if route != .s2 {
            return .W1
        }
        if s1Machine == nil {
            return .W2
        }
        guard let entryContext = s2EntryContext else {
            return .W3
        }
        if payload.continuationSnapshot.orderedAssetIDs !=
            entryContext.orderedAssetIDs {
            return .W4
        }
        if payload.continuationSnapshot.rangeDisplayInformation.rangeID !=
            entryContext.rangeID {
            return .W5
        }
        if payload.continuationSnapshot.pendingDeletionAssetIDs !=
            payload.upstreamReturn.pendingDeletionAssetIDs {
            return .W6
        }
        if payload.continuationSnapshot.currentAssetID !=
            payload.upstreamReturn.currentAssetID {
            return .W7
        }
        return nil
    }

    /// 确认页入口校验 V1～V9 按原九子句 `guard` 的顺序逐条判定，第一个不成立即返回其名；
    /// 全过返回 nil。纯判定、无副作用。返回类型是类内私有枚举，故本函数也必须私有。
    private static func s3EntryGuardFailure(
        submission: SessionStore.S3Submission,
        sessionStore: SessionStore,
        descriptors: [AssetDescriptor]
    ) -> S2ExitDiagnosticGuard? {
        let descriptorIDs = descriptors.map(\.identifier)
        let groupRangeIDs = submission.groups.map(\.sourceRangeID)
        let groupedAssetIDs = submission.groups.flatMap(\.orderedAssetIDs)
        if submission.sourceSessionID != sessionStore.sessionID {
            return .V1
        }
        if Set(submission.orderedAssetIDs).count !=
            submission.orderedAssetIDs.count {
            return .V2
        }
        if Set(submission.orderedAssetIDs) !=
            sessionStore.allPendingDeletionAssetIDs {
            return .V3
        }
        if Set(descriptorIDs).count != descriptorIDs.count {
            return .V4
        }
        if Set(descriptorIDs) != Set(submission.orderedAssetIDs) {
            return .V5
        }
        if Set(groupRangeIDs).count != groupRangeIDs.count {
            return .V6
        }
        if !submission.groups.allSatisfy({ group in
            !group.sourceRangeID.isEmpty &&
                !group.name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty &&
                !group.orderedAssetIDs.isEmpty &&
                Set(group.orderedAssetIDs).count ==
                    group.orderedAssetIDs.count
        }) {
            return .V7
        }
        if groupedAssetIDs.count != submission.orderedAssetIDs.count {
            return .V8
        }
        if Set(groupedAssetIDs) != Set(submission.orderedAssetIDs) {
            return .V9
        }
        return nil
    }

    /// 组装并覆写 `s2ExitDiagnosticsText`。只读取样与实参，不读活状态；源码字面量全 ASCII。
    private func recordS2ExitDiagnostics(
        entry: String,
        sample: S2ExitSample,
        payload: S2ExitPayload,
        reconciled: Bool,
        outcome: String,
        failure: S2ExitDiagnosticGuard?
    ) {
        let lineStart: [String] = [
            "entry=" + entry,
            "route=" + String(describing: sample.route),
            "loadingState=" + (sample.loadingState.map { String(describing: $0) } ?? "na"),
            "stateIsReady=" + (sample.stateIsReady.map { String($0) } ?? "na"),
            "isObscured=" + (sample.isObscured.map { String($0) } ?? "na")
        ]
        let lineRange: [String] = [
            "rangeID=" + sample.rangeID,
            "inflight=" + (sample.inflight.map { String($0) } ?? "na"),
            "inflightCount=" + (sample.inflightCount.map { String($0) } ?? "na")
        ]
        let lineSnapshot: [String] = [
            "ordered=" + String(sample.ordered),
            "currentInList=" + String(sample.currentInList),
            "snapshotPending=" + String(sample.snapshotPending),
            "returnedPending=" + String(sample.returnedPending)
        ]
        let lineSession: [String] = [
            "sessionMatch=" + (sample.sessionMatch.map { String($0) } ?? "na"),
            "dAll=" + (sample.dAll.map { String($0) } ?? "na"),
            "f=" + (sample.f.map { String($0) } ?? "na"),
            "rangesWithPending=" + (sample.rangesWithPending.map { String($0) } ?? "na")
        ]
        let lineOutcome: [String] = [
            "outcome=" + outcome,
            "guard=" + (failure?.rawValue ?? "none")
        ]
        var lines: [String] = []
        lines.append("format=ic168-s2-exit-v1")
        lines.append(lineStart.joined(separator: " "))
        lines.append(lineRange.joined(separator: " "))
        lines.append(lineSnapshot.joined(separator: " "))
        lines.append(lineSession.joined(separator: " "))
        lines.append("reconciled=" + String(reconciled))
        lines.append(lineOutcome.joined(separator: " "))
        s2ExitDiagnosticsText = lines.joined(separator: "\n")
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
                }
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
            // IC-127 B：sessionID 随 S4 完成／S5 离开而结束，S1 会话档一并清除。
            try persistence.clearS1Session()
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
                        isApplicationActive: true
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
