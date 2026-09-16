import Foundation
import Photos

/// IC-153：一遍元数据枚举的单条结果——资产上直接可读的字段，不含字节。
struct S0AssetMetadata: Equatable, Sendable {
    let localIdentifier: String
    let modificationDate: Date?
    let creationDate: Date?
    let mediaType: S0ScannedMediaType
    let isScreenshot: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
}

/// IC-153：扫描服务的闭包式源（照 `S1PhotoLibrarySource` 的样板）。
///
/// 三个闭包**只在非主线程被调用**（C2）。测试注入夹具。
struct S0LibraryScanSource {
    let authorizationState: () -> S1AuthorizationState
    /// 一遍元数据。取数范围不含隐藏与「最近删除」的资产。
    let enumerateAssets: () throws -> [S0AssetMetadata]
    /// 一次资源枚举同时取视频文件名与字节；字节取不到为 nil（裁定 三）。
    let fetchResourcesAndBytes: (String) async -> (videoFilename: String?, byteCount: Int64?)
}

/// 一次字节取数的结果（任务组的子任务返回值）。
private struct S0ByteFetchResult: Sendable {
    let identifier: String
    let videoFilename: String?
    let byteCount: Int64?
}

/// IC-153：S0 扫描服务——全库增量扫描 + 持久缓存 + 快照聚合。
///
/// **一遍扫描**（`advanceScan()` 启动，幂等）：
/// 1. 授权分派（`S1AuthorizationDispatch`）：不可读即 `.failed(.authorization)`；
/// 2. 本进程第一遍才读缓存文件；
/// 3. 一遍元数据枚举：抛错即 `.failed(.read)`；
/// 4. 续扫判定：新增与改动回报 `.scanning`，逐项取字节、计入进度；
/// 5. 全部处理完回报 `.completed`；
/// 6. 上次未解析的资产静默重试：不回扫描中、不动进度，解出来的随快照更新。
///
/// **不变量**：构造不发任何源请求、不读缓存文件（C4）；取数全在非主线程；主线程只读
/// 最近一次聚合结果；已处理条目每 `S0ScanRules.persistEveryAssets` 项落盘一次，
/// 一遍结束或被取消时再落一次，落盘失败不中断扫描、不改回报（B3）。
final class S0LibraryScanService {
    /// `D_全部`。由 App 入口注入，在调用方线程（主线程）上读；同一集合从三个
    /// 类别的 `c.assets` 排除、其字节和即待删篮体积（裁定 五）。
    var pendingDeletionAssetIDs: () -> Set<String> = { [] }

    /// 快照变化钩子（裁定 五）。在主线程上调，每秒至多 `S0ScanRules.snapshotThrottleHz`
    /// 次；完成与失败那一次必达——节流只会把它推迟到间隔期满，不会丢掉。
    var onSnapshotDidChange: (() -> Void)?

    /// 只在主线程上碰。
    private lazy var changeThrottle: S0SnapshotChangeThrottle = S0SnapshotChangeThrottle(
        maximumDeliveriesPerSecond: S0ScanRules.snapshotThrottleHz
    ) { [weak self] in
        self?.onSnapshotDidChange?()
    }

    private let source: S0LibraryScanSource
    private let cacheStore: S0ScanCacheStore
    private let stateLock = NSLock()

    // 以下状态一律经 `stateLock` 读写。
    private var outcome: S0ScanOutcome = .scanning
    private var isLimitedAuthorization = false
    private var records: [String: S0ScanCacheEntry] = [:]
    private var libraryIdentifiers: Set<String> = []
    private var scannedAssetCount = 0
    private var totalAssetCount = 0
    private var hasLoadedCache = false
    private var isPassRunning = false
    private var passTask: Task<Void, Never>?
    /// 快照相关状态每变一次递增；回报与聚合缓存都按它判断「有没有变」。
    private var revision = 0
    private var notifiedRevision = 0
    private var processedSincePersist = 0
    private var hasUnpersistedChanges = false
    private var persistenceFailures = 0
    private var memoizedSnapshot: MemoizedSnapshot?

    private struct MemoizedSnapshot {
        let revision: Int
        let pendingDeletionAssetIDs: Set<String>
        let snapshot: S0CleanupSnapshot
    }

    init(source: S0LibraryScanSource, cacheStore: S0ScanCacheStore) {
        self.source = source
        self.cacheStore = cacheStore
    }

    /// 产品构造：PhotoKit 源 + Application Support 下的缓存文件。构造本身不发
    /// PhotoKit 请求、不读缓存文件（C4）；第一次 `advanceScan()` 才开始。
    convenience init() {
        self.init(source: .production, cacheStore: S0ScanCacheStore())
    }

    // MARK: - 回报（主线程可随时读，不阻塞）

    func currentScanOutcome() -> S0ScanOutcome {
        withState { outcome }
    }

    /// 最近一次聚合结果。只在修订号或 `D_全部` 变了时重算。
    func currentSnapshot() -> S0CleanupSnapshot {
        let pending = pendingDeletionAssetIDs()
        return withState { () -> S0CleanupSnapshot in
            if let memo = memoizedSnapshot,
               memo.revision == revision,
               memo.pendingDeletionAssetIDs == pending {
                return memo.snapshot
            }
            let assets = records.compactMap { element -> S0ClassifiedAsset? in
                guard libraryIdentifiers.contains(element.key) else {
                    return nil
                }
                return element.value.classified(id: element.key)
            }
            let snapshot = S0ScanAggregator.snapshot(
                of: assets,
                context: S0ScanAggregationContext(
                    progress: S0ScanProgress(
                        scannedAssetCount: scannedAssetCount,
                        totalAssetCount: totalAssetCount
                    ),
                    recognition: outcome == .completed ? .settled : .counting,
                    pendingDeletionAssetIDs: pending,
                    // 账本写入方是批次 5.3；本卡服务的账本恒为空。
                    ledgerAssetIDs: [],
                    ledgerEntries: [],
                    isLimitedAuthorization: isLimitedAuthorization
                )
            )
            memoizedSnapshot = MemoizedSnapshot(
                revision: revision,
                pendingDeletionAssetIDs: pending,
                snapshot: snapshot
            )
            return snapshot
        }
    }

    // MARK: - 推进

    /// 启动或续扫。幂等：正在扫时再调无副作用（裁定 五）。
    func advanceScan() {
        withState { () -> Void in
            guard !isPassRunning else {
                return
            }
            isPassRunning = true
            passTask = Task.detached(priority: .utility) { [weak self] in
                guard let self else {
                    return
                }
                await self.runPass()
            }
        }
    }

    /// 取消在飞的一遍（B4）。已处理的条目随之落盘；再次 `advanceScan()` 从缓存续扫。
    func cancelScan() {
        let task = withState { passTask }
        task?.cancel()
    }

    var isScanInFlight: Bool {
        withState { isPassRunning }
    }

    /// 落盘失败的累计次数（B3：记一次错误，扫描继续，回报不变）。
    var persistenceFailureCount: Int {
        withState { persistenceFailures }
    }

    /// 取字节的顺序：拍摄时间新的在前（最近的先出数），同刻按标识排，结果确定。
    static func newestFirst(
        _ identifiers: Set<String>,
        metadataByID: [String: S0AssetMetadata]
    ) -> [String] {
        identifiers.sorted { lhs, rhs in
            let lhsDate = metadataByID[lhs]?.creationDate ?? .distantPast
            let rhsDate = metadataByID[rhs]?.creationDate ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs < rhs
        }
    }

    // MARK: - 一遍扫描

    private func runPass() async {
        defer {
            finishPass()
        }

        let authorization = source.authorizationState()
        guard case let .proceed(isLimited) = S1AuthorizationDispatch.dispatch(
            for: authorization
        ) else {
            // 未决定也落这里：服务不自己弹系统授权窗，授权变化后前台恢复再续扫。
            mutate {
                let outcomeChanged = setOutcomeLocked(.failed(.authorization))
                let limitedChanged = setLimitedLocked(false)
                return outcomeChanged || limitedChanged
            }
            notifyChange()
            return
        }

        loadCacheIfNeeded()

        let library: [S0AssetMetadata]
        do {
            library = try source.enumerateAssets()
        } catch {
            mutate {
                let outcomeChanged = setOutcomeLocked(.failed(.read))
                let limitedChanged = setLimitedLocked(isLimited)
                return outcomeChanged || limitedChanged
            }
            notifyChange()
            return
        }
        guard !Task.isCancelled else {
            return
        }

        let plan = applyPlan(library: library, isLimited: isLimited)
        notifyChange()

        let metadataByID = Dictionary(
            library.map { ($0.localIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        await fetchBytes(
            for: Self.newestFirst(plan.refetchIDs, metadataByID: metadataByID),
            metadataByID: metadataByID,
            countsTowardProgress: true
        )
        guard !Task.isCancelled else {
            persistPendingChanges()
            return
        }
        mutate {
            let outcomeChanged = setOutcomeLocked(.completed)
            let progressChanged = setProgressLocked(
                scanned: totalAssetCount,
                total: totalAssetCount
            )
            return outcomeChanged || progressChanged
        }
        persistPendingChanges()
        notifyChange()

        await fetchBytes(
            for: Self.newestFirst(plan.retryIDs, metadataByID: metadataByID),
            metadataByID: metadataByID,
            countsTowardProgress: false
        )
        persistPendingChanges()
        notifyChange()
    }

    private func applyPlan(
        library: [S0AssetMetadata],
        isLimited: Bool
    ) -> S0ScanResumePlan {
        withState { () -> S0ScanResumePlan in
            let plan = S0ScanResumePlan.make(library: library, cache: records)
            var changed = false
            for identifier in plan.discardedIDs {
                records[identifier] = nil
                hasUnpersistedChanges = true
                changed = true
            }
            let identifiers = Set(library.map { $0.localIdentifier })
            if identifiers != libraryIdentifiers {
                libraryIdentifiers = identifiers
                changed = true
            }
            if setProgressLocked(
                scanned: library.count - plan.refetchIDs.count,
                total: library.count
            ) {
                changed = true
            }
            if setLimitedLocked(isLimited) {
                changed = true
            }
            if !plan.refetchIDs.isEmpty, setOutcomeLocked(.scanning) {
                changed = true
            }
            if changed {
                revision += 1
            }
            return plan
        }
    }

    /// 并发不超过 `S0ScanRules.byteFetchConcurrency` 地取字节。被取消后在途的结果
    /// 一律丢弃、不再发起新请求。
    private func fetchBytes(
        for identifiers: [String],
        metadataByID: [String: S0AssetMetadata],
        countsTowardProgress: Bool
    ) async {
        guard !identifiers.isEmpty else {
            return
        }
        let fetch = source.fetchResourcesAndBytes
        let concurrency = max(1, S0ScanRules.byteFetchConcurrency)
        await withTaskGroup(of: S0ByteFetchResult.self) { group in
            var remaining = identifiers.makeIterator()
            var launched = 0
            while launched < concurrency, let identifier = remaining.next() {
                group.addTask {
                    let reading = await fetch(identifier)
                    return S0ByteFetchResult(
                        identifier: identifier,
                        videoFilename: reading.videoFilename,
                        byteCount: reading.byteCount
                    )
                }
                launched += 1
            }
            while let result = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    continue
                }
                if let metadata = metadataByID[result.identifier] {
                    record(
                        result,
                        metadata: metadata,
                        countsTowardProgress: countsTowardProgress
                    )
                }
                if let identifier = remaining.next() {
                    group.addTask {
                        let reading = await fetch(identifier)
                        return S0ByteFetchResult(
                            identifier: identifier,
                            videoFilename: reading.videoFilename,
                            byteCount: reading.byteCount
                        )
                    }
                }
            }
        }
    }

    private func record(
        _ result: S0ByteFetchResult,
        metadata: S0AssetMetadata,
        countsTowardProgress: Bool
    ) {
        let evidence = S0ScanClassifier.screenRecordingEvidence(
            mediaType: metadata.mediaType,
            videoFilename: result.videoFilename,
            pixelWidth: metadata.pixelWidth,
            pixelHeight: metadata.pixelHeight
        )
        let entry = S0ScanCacheEntry(
            metadata: metadata,
            byteCount: result.byteCount,
            evidence: evidence
        )
        let shouldPersist = withState { () -> Bool in
            var changed = false
            if records[metadata.localIdentifier] != entry {
                records[metadata.localIdentifier] = entry
                hasUnpersistedChanges = true
                changed = true
            }
            if countsTowardProgress,
               setProgressLocked(
                scanned: min(totalAssetCount, scannedAssetCount + 1),
                total: totalAssetCount
               ) {
                changed = true
            }
            if changed {
                revision += 1
            }
            processedSincePersist += 1
            return processedSincePersist >= S0ScanRules.persistEveryAssets
        }
        if shouldPersist {
            persistPendingChanges()
        }
        notifyChange()
    }

    private func loadCacheIfNeeded() {
        guard withState({ !hasLoadedCache }) else {
            return
        }
        let loaded = cacheStore.load()
        withState { () -> Void in
            guard !hasLoadedCache else {
                return
            }
            hasLoadedCache = true
            for (identifier, entry) in loaded where records[identifier] == nil {
                records[identifier] = entry
            }
        }
    }

    /// 落盘（B3）。缓存是加速器不是数据源：失败只记一次，下个落盘点再试。
    private func persistPendingChanges() {
        let entries = withState { () -> [String: S0ScanCacheEntry]? in
            processedSincePersist = 0
            guard hasUnpersistedChanges else {
                return nil
            }
            hasUnpersistedChanges = false
            return records
        }
        guard let entries else {
            return
        }
        do {
            try cacheStore.save(entries)
        } catch {
            withState { () -> Void in
                persistenceFailures += 1
                hasUnpersistedChanges = true
            }
        }
    }

    private func finishPass() {
        withState { () -> Void in
            isPassRunning = false
            passTask = nil
        }
    }

    // MARK: - 回报变化

    /// 修订号比上次送出时新才送出，同一版本不重复回报。
    private func notifyChange() {
        let hasNewRevision = withState { () -> Bool in
            guard notifiedRevision != revision else {
                return false
            }
            notifiedRevision = revision
            return true
        }
        if hasNewRevision {
            signalSnapshotChange()
        }
    }

    /// 把「快照有新版本」送到主线程的节流器（裁定 五）。
    private func signalSnapshotChange() {
        DispatchQueue.main.async { [weak self] in
            self?.changeThrottle.signal()
        }
    }

    // MARK: - 锁

    private func withState<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        return try body()
    }

    /// 在锁内改状态；闭包返回「有没有变」，有变就递增修订号。
    private func mutate(_ body: () -> Bool) {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        if body() {
            revision += 1
        }
    }

    /// 以下三个只能在持锁时调用。
    private func setOutcomeLocked(_ newValue: S0ScanOutcome) -> Bool {
        guard outcome != newValue else {
            return false
        }
        outcome = newValue
        return true
    }

    private func setLimitedLocked(_ newValue: Bool) -> Bool {
        guard isLimitedAuthorization != newValue else {
            return false
        }
        isLimitedAuthorization = newValue
        return true
    }

    private func setProgressLocked(scanned: Int, total: Int) -> Bool {
        guard scannedAssetCount != scanned || totalAssetCount != total else {
            return false
        }
        scannedAssetCount = scanned
        totalAssetCount = total
        return true
    }
}

/// IC-153 C1：S0 首页数据源协议的真实实现（批次 5.1），替换 IC-147 的桩。
extension S0LibraryScanService: S0CleanupDataProviding {}

extension S0LibraryScanSource {
    /// PhotoKit 实现。
    ///
    /// - 元数据：库的默认取数（不带取数选项）。默认选项不含隐藏资产，「最近删除」
    ///   只经它自己的智能相簿可达，本源不取任何相簿（③ PhotoKit 文档口径，真机由
    ///   H75 第 3 条的项数对照核）；
    /// - 资源：每个资产只做一次资源枚举，同时给出视频主资源的原始文件名与字节
    ///   （裁定 三：不为文件名再枚举一遍；只对视频取文件名）；
    /// - 字节：`AssetSizeScanner` 的现行 data 途径，禁网络，iCloud 未下载的记未解析。
    static var production: S0LibraryScanSource {
        let library = S0PhotoKitScanLibrary()
        return S0LibraryScanSource(
            authorizationState: {
                S0PhotoKitScanLibrary.authorizationState()
            },
            enumerateAssets: {
                library.enumerateAssets()
            },
            fetchResourcesAndBytes: { identifier in
                await library.resourcesAndBytes(for: identifier)
            }
        )
    }
}

/// PhotoKit 一侧的取数实现。最近一次元数据枚举拿到的资产对象按标识留存，取字节时
/// 直接复用，不按标识再查一遍库；查不到的一律记未解析。
final class S0PhotoKitScanLibrary {
    private let lock = NSLock()
    private var assetsByIdentifier: [String: PHAsset] = [:]

    /// 授权映射与 `PhotoLibraryService` 的那一份逐 case 相同。那一份是 `@MainActor`
    /// 类型上的私有静态函数，而本源的每次调用都在非主线程上（C2），只能在此复写；
    /// 分派仍一律经 `S1AuthorizationDispatch.dispatch(for:)`。
    static func authorizationState() -> S1AuthorizationState {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
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

    func enumerateAssets() -> [S0AssetMetadata] {
        let result = PHAsset.fetchAssets(with: nil)
        var metadata: [S0AssetMetadata] = []
        var assets: [String: PHAsset] = [:]
        metadata.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            let identifier = asset.localIdentifier
            assets[identifier] = asset
            metadata.append(
                S0AssetMetadata(
                    localIdentifier: identifier,
                    modificationDate: asset.modificationDate,
                    creationDate: asset.creationDate,
                    mediaType: asset.mediaType == .video ? .video : .photo,
                    isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.duration
                )
            )
        }
        replaceAssets(assets)
        return metadata
    }

    func resourcesAndBytes(
        for identifier: String
    ) async -> (videoFilename: String?, byteCount: Int64?) {
        guard let asset = cachedAsset(for: identifier) else {
            return (videoFilename: nil, byteCount: nil)
        }
        let resources = PHAssetResource.assetResources(for: asset)
        let videoFilename: String?
        if asset.mediaType == .video {
            videoFilename = resources.first(where: { $0.type == .video })?.originalFilename
        } else {
            videoFilename = nil
        }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false
        let conclusion = await AssetSizeScanner().scan(
            resources: resources,
            options: options
        )
        switch conclusion {
        case let .knownBytes(byteCount):
            return (videoFilename: videoFilename, byteCount: byteCount)
        case .notStarted, .inProgress, .unavailable:
            return (videoFilename: videoFilename, byteCount: nil)
        }
    }

    private func replaceAssets(_ assets: [String: PHAsset]) {
        lock.lock()
        defer {
            lock.unlock()
        }
        assetsByIdentifier = assets
    }

    private func cachedAsset(for identifier: String) -> PHAsset? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return assetsByIdentifier[identifier]
    }
}

/// IC-153 C1：快照变化回调的主线程节流器。
///
/// 相邻两次送达的间隔不短于 1 ÷ `maximumDeliveriesPerSecond` 秒，即任意这么长的窗口
/// 里至多一次。间隔内到达的信号排到间隔期满时送出，**不丢**：回调读的是送达那一刻的
/// 最新状态，完成与失败那一次因而必达。间隔从上一次回调**返回之后**起算。只在主线程上用。
final class S0SnapshotChangeThrottle {
    let minimumIntervalNanoseconds: UInt64
    private let deliver: () -> Void
    private var lastDeliveryUptimeNanoseconds: UInt64?
    private var hasPendingSignal = false
    private var isFlushScheduled = false

    init(maximumDeliveriesPerSecond: Int, deliver: @escaping () -> Void) {
        minimumIntervalNanoseconds = 1_000_000_000
            / UInt64(max(1, maximumDeliveriesPerSecond))
        self.deliver = deliver
    }

    func signal() {
        hasPendingSignal = true
        guard !isFlushScheduled else {
            return
        }
        let now = DispatchTime.now().uptimeNanoseconds
        guard let last = lastDeliveryUptimeNanoseconds,
              now < last + minimumIntervalNanoseconds else {
            flush()
            return
        }
        isFlushScheduled = true
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime(uptimeNanoseconds: last + minimumIntervalNanoseconds)
        ) { [weak self] in
            guard let self else {
                return
            }
            self.isFlushScheduled = false
            self.flush()
        }
    }

    private func flush() {
        guard hasPendingSignal else {
            return
        }
        hasPendingSignal = false
        deliver()
        lastDeliveryUptimeNanoseconds = DispatchTime.now().uptimeNanoseconds
    }
}

/// IC-153 C3：数据源回报 → 状态机迁移事件。只在 `SC` 确实要变时给出事件，扫描中
/// 每次进度不发迁移。
///
/// 任务卡裁定 五点名的是 `.scanCompleted`／`.scanFailed(_:)`；回到扫描中的方向另需
/// 一个事件，取 SPEC-S0 v2 第四节「任一／前台恢复且有新增资产／S0-1」那一行——服务
/// 只在 `advanceScan()`（打开应用、前台恢复）之后才会从已完成或失败回到扫描中。
/// 从失败直接到已完成时先过扫描中，扫描完成那一次重排才会发生。
enum S0ScanOutcomeTransition {
    static func events(
        for outcome: S0ScanOutcome,
        scanState: S0ScanState,
        failureCategory: S0FailureCategory?
    ) -> [S0Event] {
        switch outcome {
        case .scanning:
            if scanState == .scanning {
                return []
            }
            return [.foregroundRestored(hasNewAssets: true)]
        case .completed:
            switch scanState {
            case .completed:
                return []
            case .scanning:
                return [.scanCompleted]
            case .failed:
                return [.foregroundRestored(hasNewAssets: true), .scanCompleted]
            }
        case let .failed(category):
            if scanState == .failed, failureCategory == category {
                return []
            }
            return [.scanFailed(category)]
        }
    }
}
