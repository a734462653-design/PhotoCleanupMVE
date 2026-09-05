import Combine
import Foundation

enum S1State: String, Equatable, Sendable {
    case loading = "S1-1"
    case ready = "S1-2"
    case empty = "S1-3"
    case failed = "S1-4"
}

enum S1LoadingState: Equatable, Sendable {
    case loading
    case ready
    case failed
}

/// IC-127 A（Decision_log 140 漂移 A，SPEC-S1 第二节）：分组维度回到三类。
/// `date` 内部以年／月两级呈现，年与月都是范围项，不另增 `T` 的取值。
enum S1GroupingDimension: String, CaseIterable, Equatable, Hashable, Sendable {
    case date
    case album
    case unclassified
}

enum S1SortOrder: String, CaseIterable, Equatable, Hashable, Sendable {
    case newestFirst
    case oldestFirst

    var sessionSortOrder: SessionStore.SortOrder {
        switch self {
        case .newestFirst:
            return .newestFirst
        case .oldestFirst:
            return .oldestFirst
        }
    }
}

/// 范围项。IC-127 A：`parentRangeID` 非空表示这是某个年节点下的月节点；
/// 年节点与其他维度的范围 `parentRangeID == nil`。两级都是范围，都可独立进入 S2。
struct S1Range: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let assetIDsNewestFirst: [String]
    let parentRangeID: String?

    init(
        id: String,
        displayName: String,
        assetIDsNewestFirst: [String],
        parentRangeID: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.assetIDsNewestFirst = assetIDsNewestFirst
        self.parentRangeID = parentRangeID
    }

    var totalAssetCount: Int {
        assetIDsNewestFirst.count
    }

    func orderedAssetIDs(for sortOrder: S1SortOrder) -> [String] {
        switch sortOrder {
        case .newestFirst:
            return assetIDsNewestFirst
        case .oldestFirst:
            return Array(assetIDsNewestFirst.reversed())
        }
    }
}

struct S1RangeReadRequest: Equatable, Sendable {
    let generation: Int
    let groupingDimension: S1GroupingDimension
}

/// IC-127 D（未定项 9）：失败分类。授权类给「打开系统设置」，读取类给「重试」；
/// 两类都不自动重试。
enum S1FailureCategory: Equatable, Sendable {
    case authorization
    case read
}

/// IC-127 D（未定项 2）：照片库授权状态的数据层表达，与 PhotoKit 类型解耦。
enum S1AuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
    case unknown(Int)
}

/// IC-127 D：授权态分派结果。界面层据此决定弹系统授权、进 S1-2（可带受限提示条）
/// 或落 S1-4 并给「打开系统设置」。本卡只做分派，不做界面。
enum S1AuthorizationDispatch: Equatable, Sendable {
    case requestSystemAuthorization
    case proceed(isLimited: Bool)
    case fail(S1FailureCategory)

    static func dispatch(for state: S1AuthorizationState) -> S1AuthorizationDispatch {
        switch state {
        case .notDetermined:
            return .requestSystemAuthorization
        case .authorized:
            return .proceed(isLimited: false)
        case .limited:
            // 受限授权按已授权处理：正常读取可见资产、正常进入 S1-2，
            // 只多一个「受限」标志供界面层挂提示条。
            return .proceed(isLimited: true)
        case .denied, .restricted, .unknown:
            return .fail(.authorization)
        }
    }
}

struct S1RangeReadFailure: Error, Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case authorizationNotDetermined
        case authorizationDenied
        case authorizationRestricted
        case unknownAuthorizationStatus(Int)
        case missingCreationDate(assetID: String)
        case missingDisplayName(rangeID: String)
        case duplicateRangeID(String)
        case duplicateAssetID(rangeID: String, assetID: String)
        case invalidResponse

        /// IC-127 D：失败分类。上层展示只应消费本分类，不消费具体原因字段。
        var category: S1FailureCategory {
            switch self {
            case .authorizationNotDetermined,
                 .authorizationDenied,
                 .authorizationRestricted,
                 .unknownAuthorizationStatus:
                return .authorization
            case .missingCreationDate,
                 .missingDisplayName,
                 .duplicateRangeID,
                 .duplicateAssetID,
                 .invalidResponse:
                return .read
            }
        }
    }

    let groupingDimension: S1GroupingDimension
    let reason: Reason

    var category: S1FailureCategory {
        reason.category
    }
}

/// IC-127 D：一次范围读取的完整回应——结果 + 受限标志。
struct S1RangeReadResponse {
    let result: Result<[S1Range], S1RangeReadFailure>
    let isLimitedAuthorization: Bool

    init(
        result: Result<[S1Range], S1RangeReadFailure>,
        isLimitedAuthorization: Bool = false
    ) {
        self.result = result
        self.isLimitedAuthorization = isLimitedAuthorization
    }
}

struct S1RangeDisplayInformation: Equatable, Sendable {
    let rangeID: String
    let displayName: String
    let totalAssetCount: Int
}

struct S1ToS2Handoff {
    let sessionID: String
    let rangeDisplayInformation: S1RangeDisplayInformation
    let orderedAssetIDs: [String]
    let currentAssetID: String
    let pendingDeletionAssetIDs: Set<String>

    private let sessionMergedPendingDeletionCountProvider: () -> Int

    var sessionMergedPendingDeletionCount: Int {
        sessionMergedPendingDeletionCountProvider()
    }

    init(
        sessionID: String,
        rangeDisplayInformation: S1RangeDisplayInformation,
        orderedAssetIDs: [String],
        currentAssetID: String,
        pendingDeletionAssetIDs: Set<String>,
        sessionMergedPendingDeletionCountProvider: @escaping () -> Int
    ) {
        self.sessionID = sessionID
        self.rangeDisplayInformation = rangeDisplayInformation
        self.orderedAssetIDs = orderedAssetIDs
        self.currentAssetID = currentAssetID
        self.pendingDeletionAssetIDs = pendingDeletionAssetIDs
        self.sessionMergedPendingDeletionCountProvider =
            sessionMergedPendingDeletionCountProvider
    }
}

struct S1RangeRow: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let totalAssetCount: Int
    let pendingDeletionCount: Int
    let processedAssetCount: Int
}

enum S1UndecidedPlaceholder: Equatable, Sendable {
    case unresolved
}

enum S1UndecidedItems {
    // IC-127 F（Decision_log 第 140 条漂移 B）：item03／item04 已于 SPEC-S1 v5／v7 定案，
    // item01／02／08／09／11／13／14／14b／14c 随第 140 条定案，登记一并删除。
    // item05／06／07／10／12／15 属视觉／文案，留给 IC-128；item16／17 仍为 v1 候补。
    static let item05LongNameTruncation = S1UndecidedPlaceholder.unresolved
    static let item06ZeroPendingAndProgressPresentation = S1UndecidedPlaceholder.unresolved
    static let item07EmptyMergedDeletionTrashPresentation = S1UndecidedPlaceholder.unresolved
    static let item10LoadingIndicator = S1UndecidedPlaceholder.unresolved
    static let item12S2ReturnValidationFailurePresentation = S1UndecidedPlaceholder.unresolved
    static let item15EmptyAndFailureCopy = S1UndecidedPlaceholder.unresolved
    static let item16RecommendedCleanupArea = S1UndecidedPlaceholder.unresolved
    static let item17FileSizeSort = S1UndecidedPlaceholder.unresolved

    enum LocalizedCopy {
        case loading
        case empty
        case failure
        case retry
        case zeroPending
        case progress
        case emptyTrash
    }

    static func localizedCopy(
        _ copy: LocalizedCopy,
        replacing replacements: [String: String] = [:]
    ) -> String {
        switch copy {
        case .loading:
            return L10n.text("s1.placeholder.loading")
        case .empty:
            return L10n.text("s1.placeholder.empty")
        case .failure:
            return L10n.text("s1.placeholder.failure")
        case .retry:
            return L10n.text("s1.placeholder.retry")
        case .zeroPending:
            return L10n.text("s1.placeholder.pending_zero")
        case .progress:
            return L10n.text(
                "s1.placeholder.processed_progress",
                replacing: replacements
            )
        case .emptyTrash:
            return L10n.text("s1.placeholder.trash_empty")
        }
    }
}

final class S1StateMachine: ObservableObject {
    @Published private(set) var loadingState: S1LoadingState = .loading
    @Published private(set) var groupingDimension: S1GroupingDimension
    @Published private(set) var sortOrder: S1SortOrder
    @Published private(set) var isObscured = false
    @Published private(set) var ranges: [S1Range] = []
    @Published private(set) var readFailure: S1RangeReadFailure?
    @Published private(set) var sessionStore: SessionStore

    private var readGeneration = 0
    private var knownRangeNamesByID: [String: String] = [:]

    init(
        sessionStore: SessionStore,
        initialGroupingDimension: S1GroupingDimension,
        initialSortOrder: S1SortOrder
    ) {
        self.sessionStore = sessionStore
        groupingDimension = initialGroupingDimension
        sortOrder = initialSortOrder
    }

    var state: S1State {
        switch loadingState {
        case .loading:
            return .loading
        case .ready:
            return ranges.isEmpty ? .empty : .ready
        case .failed:
            return .failed
        }
    }

    var currentReadRequest: S1RangeReadRequest? {
        guard loadingState == .loading else {
            return nil
        }
        return S1RangeReadRequest(
            generation: readGeneration,
            groupingDimension: groupingDimension
        )
    }

    var badgeCount: Int {
        sessionStore.allPendingDeletionAssetIDs.count
    }

    /// 一级节点：`T=date` 时为年节点；其他维度即全部范围。
    var topLevelRanges: [S1Range] {
        ranges.filter { $0.parentRangeID == nil }
    }

    /// 某个年节点下的月节点（按读取方给出的新到旧顺序）。
    func childRanges(of rangeID: String) -> [S1Range] {
        ranges.filter { $0.parentRangeID == rangeID }
    }

    func isYearExpanded(_ rangeID: String) -> Bool {
        !collapsedYearRangeIDs.contains(rangeID)
    }

    /// IC-127 A：展开／收起与「进入年范围」是两个可区分的目标——本方法只改月节点
    /// 行是否显示，不改 `T`、`R(T)`、`M`、`K`，不触发读取，不形成交接。
    @discardableResult
    func toggleYearExpansion(_ rangeID: String) -> Bool {
        guard !isObscured,
              groupingDimension == .date,
              state == .ready,
              let range = ranges.first(where: { $0.id == rangeID }),
              range.parentRangeID == nil,
              !childRanges(of: rangeID).isEmpty else {
            return false
        }
        if collapsedYearRangeIDs.contains(rangeID) {
            collapsedYearRangeIDs.remove(rangeID)
        } else {
            collapsedYearRangeIDs.insert(rangeID)
        }
        return true
    }

    /// 范围列表的可见顺序。`T=date`：年节点按 `O` 排列，每个年节点后跟其月节点
    /// （同样按 `O`），收起的年节点不列出月节点；其余维度沿用读取方顺序。
    var visibleRanges: [S1Range] {
        guard groupingDimension == .date else {
            return ranges
        }
        let orderedYears = sortOrder == .oldestFirst
            ? Array(topLevelRanges.reversed())
            : topLevelRanges
        var visible: [S1Range] = []
        for year in orderedYears {
            visible.append(year)
            guard isYearExpanded(year.id) else {
                continue
            }
            let months = childRanges(of: year.id)
            visible.append(
                contentsOf: sortOrder == .oldestFirst
                    ? Array(months.reversed())
                    : months
            )
        }
        return visible
    }

    var rangeRows: [S1RangeRow] {
        visibleRanges.map { range in
            let childCount = childRanges(of: range.id).count
            return S1RangeRow(
                id: range.id,
                displayName: range.displayName,
                totalAssetCount: range.totalAssetCount,
                pendingDeletionCount: sessionStore.pendingDeletionCount(
                    for: range.id
                ),
                processedAssetCount: processedAssetIDs(for: range.id).count,
                parentRangeID: range.parentRangeID,
                childCount: childCount,
                isExpanded: childCount > 0 && isYearExpanded(range.id)
            )
        }
    }

    func processedAssetIDs(for rangeID: String) -> Set<String> {
        guard let range = ranges.first(where: { $0.id == rangeID }) else {
            return []
        }
        return sessionStore.processedAssetIDs(
            for: range.id,
            orderedAssetIDs: range.orderedAssetIDs(for: sortOrder),
            currentSortOrder: sortOrder.sessionSortOrder
        )
    }

    @discardableResult
    func completeRangeRead(
        _ result: Result<[S1Range], S1RangeReadFailure>,
        for request: S1RangeReadRequest,
        isLimitedAuthorization: Bool = false
    ) -> Bool {
        guard request == currentReadRequest else {
            return false
        }

        switch result {
        case let .success(newRanges):
            guard Self.areValid(newRanges) else {
                ranges = []
                readFailure = S1RangeReadFailure(
                    groupingDimension: request.groupingDimension,
                    reason: .invalidResponse
                )
                loadingState = .failed
                return false
            }
            // IC-127 C：每一次读取结果都先过对账再对外可见（含 B 的恢复路径）。
            adoptRanges(newRanges, isLimitedAuthorization: isLimitedAuthorization)
            readFailure = nil
            loadingState = .ready
            return true

        case let .failure(failure):
            guard failure.groupingDimension == request.groupingDimension else {
                ranges = []
                readFailure = S1RangeReadFailure(
                    groupingDimension: request.groupingDimension,
                    reason: .invalidResponse
                )
                loadingState = .failed
                return false
            }
            ranges = []
            readFailure = failure
            loadingState = .failed
            return true
        }
    }

    /// IC-127 C（未定项 13）：外部变更对账的单一入口。就绪态下以新的 `R(T)` 为准：
    /// 替换范围列表；`M` 剔除已不存在的资产并从 `F` 删键；`K` 按新序列重新钳制。
    /// 静默完成——不改 `loadingState`、不写 `readFailure`、不产生任何提示。
    /// 重读失败时没有「新结果」可依据，原样保留（同样静默），返回 false。
    @discardableResult
    func reconcile(
        with result: Result<[S1Range], S1RangeReadFailure>,
        isLimitedAuthorization: Bool? = nil
    ) -> Bool {
        reconciliationCount += 1
        guard loadingState == .ready,
              case let .success(newRanges) = result,
              Self.areValid(newRanges) else {
            return false
        }
        adoptRanges(
            newRanges,
            isLimitedAuthorization: isLimitedAuthorization ?? self.isLimitedAuthorization,
            countsAsReconciliation: false
        )
        return true
    }

    private func adoptRanges(
        _ newRanges: [S1Range],
        isLimitedAuthorization: Bool,
        countsAsReconciliation: Bool = true
    ) {
        ranges = newRanges
        for range in newRanges {
            knownRangeNamesByID[range.id] = range.displayName
        }
        let validRangeIDs = Set(newRanges.map(\.id))
        collapsedYearRangeIDs = collapsedYearRangeIDs.intersection(validRangeIDs)
        self.isLimitedAuthorization = isLimitedAuthorization
        if countsAsReconciliation {
            reconciliationCount += 1
        }
        let reconciledStore = Self.reconciledStore(sessionStore, against: newRanges)
        if reconciledStore != sessionStore {
            sessionStore = reconciledStore
        }
    }

    /// 对账的纯函数部分：只对出现在新 `R(T)` 中的范围做剔除与钳制。当前维度之外的
    /// 范围（例如在相册维度下标记、此刻 `T=date`）在切回该维度读取时经同一入口对账。
    private static func reconciledStore(
        _ store: SessionStore,
        against newRanges: [S1Range]
    ) -> SessionStore {
        var next = store
        for range in newRanges {
            next.reconcileRange(
                range.id,
                availableAssetIDsNewestFirst: range.assetIDsNewestFirst
            )
        }
        return next
    }

    @discardableResult
    func switchGroupingDimension(to newValue: S1GroupingDimension) -> Bool {
        guard !isObscured, newValue != groupingDimension else {
            return false
        }
        groupingDimension = newValue
        ranges = []
        readFailure = nil
        loadingState = .loading
        readGeneration += 1
        return true
    }

    @discardableResult
    func switchSortOrder(to newValue: S1SortOrder) -> Bool {
        guard !isObscured, newValue != sortOrder else {
            return false
        }
        sortOrder = newValue
        return true
    }

    /// 重试只能由用户动作触发（未定项 9：不自动重试、不设次数上限）。
    @discardableResult
    func retry() -> Bool {
        guard !isObscured, loadingState == .failed else {
            return false
        }
        ranges = []
        readFailure = nil
        loadingState = .loading
        readGeneration += 1
        return true
    }

    func presentObscuration() {
        isObscured = true
    }

    func dismissObscuration() {
        isObscured = false
    }

    func makeS2Handoff(for rangeID: String) -> S1ToS2Handoff? {
        guard !isObscured,
              state == .ready,
              let range = ranges.first(where: { $0.id == rangeID }) else {
            return nil
        }

        let orderedAssetIDs = range.orderedAssetIDs(for: sortOrder)
        let assetIDSet = Set(orderedAssetIDs)
        let pendingDeletionAssetIDs =
            sessionStore.pendingDeletionAssetIDsByRangeID[range.id] ?? []
        let currentAssetID = sessionStore.continuationsByRangeID[range.id]?
            .currentAssetID ?? orderedAssetIDs.first

        guard !orderedAssetIDs.isEmpty,
              assetIDSet.count == orderedAssetIDs.count,
              pendingDeletionAssetIDs.isSubset(of: assetIDSet),
              let currentAssetID,
              assetIDSet.contains(currentAssetID) else {
            return nil
        }

        return S1ToS2Handoff(
            sessionID: sessionStore.sessionID,
            rangeDisplayInformation: S1RangeDisplayInformation(
                rangeID: range.id,
                displayName: range.displayName,
                totalAssetCount: range.totalAssetCount
            ),
            orderedAssetIDs: orderedAssetIDs,
            currentAssetID: currentAssetID,
            pendingDeletionAssetIDs: pendingDeletionAssetIDs,
            sessionMergedPendingDeletionCountProvider: { self.badgeCount }
        )
    }

    func makeS3Submission() -> SessionStore.S3Submission? {
        guard !isObscured, state != .loading else {
            return nil
        }
        let groupedRangeIDs = Set(
            sessionStore.pendingDeletionGroupsByRangeID.keys
        )
        guard groupedRangeIDs.allSatisfy({ knownRangeNamesByID[$0] != nil }) else {
            return nil
        }
        let rangeNamesByID = knownRangeNamesByID
        // IC-127 E（未定项 8 定案）：分组按范围在 R(T) 中的顺序（含 O 对日期
        // 维度的翻转），组内按当前 O 的 A(r, O)；不在当前 R(T) 中的范围按
        // SessionStore 的稳定回退排在其后。
        let currentRanges = visibleRanges
        let currentSortOrder = sortOrder
        return sessionStore.makeS3Submission(
            rangeOrder: currentRanges.map(\.id),
            orderedAssetIDsForRangeID: { rangeID in
                currentRanges.first { $0.id == rangeID }?
                    .orderedAssetIDs(for: currentSortOrder) ?? []
            },
            groupNameForRangeID: { rangeID in
                rangeNamesByID[rangeID] ?? String()
            }
        )
    }

    /// IC-127 E／C：提交排序走了兜底分支的范围数与资产数。对账之后再提交，
    /// 同维度内两者都应为 0（由测试以计数断言钉住）。
    func s3SubmissionOrderingFallback() -> SessionStore.S3SubmissionOrderingFallback {
        let currentRanges = visibleRanges
        let currentSortOrder = sortOrder
        return sessionStore.s3SubmissionOrderingFallback(
            rangeOrder: currentRanges.map(\.id),
            orderedAssetIDsForRangeID: { rangeID in
                currentRanges.first { $0.id == rangeID }?
                    .orderedAssetIDs(for: currentSortOrder) ?? []
            }
        )
    }

    @discardableResult
    func applyS2Return(
        _ returned: SessionStore.S2Return,
        entryContext: SessionStore.S2EntryContext
    ) -> Bool {
        guard !isObscured, state == .ready else {
            return false
        }
        var nextStore = sessionStore
        guard nextStore.applyS2Return(
            returned,
            entryContext: entryContext
        ) else {
            return false
        }
        sessionStore = nextStore
        return true
    }

    @discardableResult
    func applyS2PendingDeletionChange(
        _ pendingDeletionAssetIDs: Set<String>,
        entryContext: SessionStore.S2EntryContext
    ) -> Bool {
        guard !isObscured,
              state == .ready,
              let range = ranges.first(where: { $0.id == entryContext.rangeID }),
              entryContext.sortOrder == sortOrder.sessionSortOrder,
              entryContext.orderedAssetIDs == range.orderedAssetIDs(for: sortOrder),
              pendingDeletionAssetIDs.isSubset(
                  of: Set(entryContext.orderedAssetIDs)
              ) else {
            return false
        }

        var nextStore = sessionStore
        let previous = nextStore.pendingDeletionAssetIDsByRangeID[
            entryContext.rangeID
        ] ?? []
        for assetID in previous.subtracting(pendingDeletionAssetIDs).sorted() {
            nextStore.setMarked(
                false,
                assetID: assetID,
                rangeID: entryContext.rangeID
            )
        }
        for assetID in pendingDeletionAssetIDs.subtracting(previous).sorted() {
            nextStore.setMarked(
                true,
                assetID: assetID,
                rangeID: entryContext.rangeID
            )
        }
        sessionStore = nextStore
        return true
    }

    @discardableResult
    func applyS3Return(_ returned: SessionStore.S3Return) -> Bool {
        guard !isObscured else {
            return false
        }
        var nextStore = sessionStore
        guard nextStore.applyS3Return(returned) else {
            return false
        }
        sessionStore = nextStore
        return true
    }

    private static func areValid(_ ranges: [S1Range]) -> Bool {
        var rangeIDs = Set<String>()
        for range in ranges {
            let trimmedName = range.displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let assetIDs = Set(range.assetIDsNewestFirst)
            guard !range.id.isEmpty,
                  rangeIDs.insert(range.id).inserted,
                  !trimmedName.isEmpty,
                  !range.assetIDsNewestFirst.isEmpty,
                  assetIDs.count == range.assetIDsNewestFirst.count,
                  !assetIDs.contains(String()) else {
                return false
            }
        }

        let rangesByID = Dictionary(
            uniqueKeysWithValues: ranges.map { ($0.id, $0) }
        )
        var childAssetIDsByParent: [String: [String]] = [:]
        for range in ranges {
            guard let parentID = range.parentRangeID else {
                continue
            }
            guard let parent = rangesByID[parentID],
                  parent.parentRangeID == nil,
                  parentID != range.id else {
                return false
            }
            childAssetIDsByParent[parentID, default: []]
                .append(contentsOf: range.assetIDsNewestFirst)
        }
        for (parentID, childAssetIDs) in childAssetIDsByParent {
            guard let parent = rangesByID[parentID],
                  childAssetIDs.count == parent.assetIDsNewestFirst.count,
                  Set(childAssetIDs) == Set(parent.assetIDsNewestFirst) else {
                return false
            }
        }
        return true
    }
}
