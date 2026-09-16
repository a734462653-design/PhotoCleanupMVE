import Foundation

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

    /// 把「快照有新版本」送出去。主线程节流回调在子项 C 接上（裁定 五）。
    private func signalSnapshotChange() {}

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
