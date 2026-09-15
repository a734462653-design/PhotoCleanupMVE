import Combine
import Foundation

/// 四态标识（SPEC-S0 v1 第二节第 1 部分）。S0-2 与 S0-3 的 `SC` 同为
/// 已完成，分列只因可用操作清单不同：S0-3 没有可进入的类别页。
enum S0State: String, Equatable, Sendable {
    case scanning = "S0-1"
    case ready = "S0-2"
    case empty = "S0-3"
    case failed = "S0-4"
}

/// 扫描态 `SC`。**不设「未开始」**——首次进入即开始扫描，再次进入按增量
/// 缓存续扫或直接就绪（SPEC-S0 v1 第二节第 1 部分）。
enum S0ScanState: String, Equatable, Sendable {
    case scanning
    case completed
    case failed
}

/// 账本态 `LG`。只影响等待清空行与分段条斜纹的显隐，不改变 `SC`。
enum S0LedgerState: String, Equatable, Sendable {
    case empty
    case nonEmpty
}

/// 核对态 `VF`。呈现态，不新增基础状态。
///
/// SPEC-S0 v1 第二节第 1 部分写「`VF≠无` 只在 `LG=非空` 时可达」，第四节
/// 核对通过一行又写「账本清零、`LG=空`」。二者只在一种读法下自洽：**进入**
/// `VF≠无` 需要 `LG=非空`，通过之后账本清零而已通过的读数仍要显示
/// （文案 key `s0.home.pending.passed`）。本实现按该读法落实——③推测，
/// 已在 IC-147 自验报告登记，待决策会话裁定。
enum S0VerificationState: String, Equatable, Sendable {
    case none
    case checking
    case passed
    case failed
}

/// 读取失败类别 `cat`。只分两种版式，不分列为两个状态。
enum S0FailureCategory: String, Equatable, Sendable {
    case authorization
    case read
}

/// 遮挡变量 `Q`。`呈现` 不新增基础状态；被覆盖的基础状态与全部数据均保留。
enum S0Obscuring: String, Equatable, Sendable {
    case closed
    case presented
}

/// v1 纳入的类别标识（SPEC-S0 v1 第二节第 2 部分）。未实装的类别不出现在
/// `CAT` 中，首页不显示，不做「即将推出」占位（第 165 条第 1 条）。
enum S0CategoryIdentifier: String, CaseIterable, Equatable, Hashable, Sendable {
    case bigVideo
    case screenshot
    case screenRecording
    case duplicate
    case similar
}

/// 类别的识别进度。重复与相似需全库扫描完成后才起算，扫描中整行降透明、
/// 数值位显示占位、副行「扫描完成后开始识别」，且不可点。
enum S0CategoryRecognition: String, Equatable, Sendable {
    case awaitingScanCompletion
    case counting
    case settled
}

/// 扫描进度（已扫 / 总数）。
struct S0ScanProgress: Equatable, Sendable {
    let scannedAssetCount: Int
    let totalAssetCount: Int

    init(scannedAssetCount: Int = 0, totalAssetCount: Int = 0) {
        self.scannedAssetCount = max(0, scannedAssetCount)
        self.totalAssetCount = max(0, totalAssetCount)
    }
}

/// 单个类别的快照。`candidateByteCount` 是 `c.bytes`（全量，不去重）；
/// 首页 hero 的可清理约另按去重口径给出，二者不可互推。
struct S0CategorySnapshot: Equatable, Sendable, Identifiable {
    let id: S0CategoryIdentifier
    let candidateCount: Int
    let candidateByteCount: Int64
    let recognition: S0CategoryRecognition

    init(
        id: S0CategoryIdentifier,
        candidateCount: Int,
        candidateByteCount: Int64,
        recognition: S0CategoryRecognition
    ) {
        self.id = id
        self.candidateCount = max(0, candidateCount)
        self.candidateByteCount = max(0, candidateByteCount)
        self.recognition = recognition
    }

    /// 「无项目」的类别灰显并沉底、不可点。
    var hasItems: Bool {
        candidateCount > 0
    }
}

/// 待清空账本条目 `e`（SPEC-S0 v1 第二节第 2 部分）。条目在 S4 提交删除成功
/// 时按来源类别写入；本卡只定义与承载，写入方在批次 5.3。
struct S0LedgerEntry: Equatable, Sendable {
    let categoryID: S0CategoryIdentifier
    let byteCount: Int64
    let committedAt: Date
    let availableCapacityBaseline: Int64
}

/// 数据源一次取数的全部结果。行为层只消费本结构，不认识扫描实现。
struct S0CleanupSnapshot: Equatable, Sendable {
    let progress: S0ScanProgress
    /// 去重后的可清理项数。SPEC-S0 v1 第二节第 1 部分把 S0-3 定义为
    /// 「全部类别均无项目」，括注「可清理量为 0」；本实现按前者的字面口径
    /// 取去重候选项数，二者在任何真实数据上同时为零。
    let cleanableAssetCount: Int
    /// `可清理约 = Σ SZ(a), a ∈ (∪ c.assets 去重)`。去重求和，不是各类别求和。
    let cleanableByteCount: Int64
    /// `LIB`：照片库总占用。
    let libraryTotalByteCount: Int64
    let categories: [S0CategorySnapshot]
    let ledgerEntries: [S0LedgerEntry]
    /// 待删篮胶囊右半的体积读数。**张数另取会话层**（见
    /// `mergedPendingDeletionCountProvider`）——S0 不另持一份待删集合；
    /// 体积是 `SZ` 的派生读数，与类别字节同出扫描服务，故随快照给出。
    let pendingDeletionByteCount: Int64
    /// `lim`：与 SPEC-S1 v9 同源同值。
    let isLimitedAuthorization: Bool

    init(
        progress: S0ScanProgress = S0ScanProgress(),
        cleanableAssetCount: Int = 0,
        cleanableByteCount: Int64 = 0,
        libraryTotalByteCount: Int64 = 0,
        categories: [S0CategorySnapshot] = [],
        ledgerEntries: [S0LedgerEntry] = [],
        pendingDeletionByteCount: Int64 = 0,
        isLimitedAuthorization: Bool = false
    ) {
        self.progress = progress
        self.cleanableAssetCount = max(0, cleanableAssetCount)
        self.cleanableByteCount = max(0, cleanableByteCount)
        self.libraryTotalByteCount = max(0, libraryTotalByteCount)
        self.categories = categories
        self.ledgerEntries = ledgerEntries
        self.pendingDeletionByteCount = max(0, pendingDeletionByteCount)
        self.isLimitedAuthorization = isLimitedAuthorization
    }

    /// 账本清零后的同一份快照。核对通过的附带效果之一是「账本清零」
    /// （SPEC-S0 v1 第四节第 9 行），只翻 `LG` 旗标不算清零——
    /// `pendingClearanceByteCount` 会继续求和出旧总量。
    func clearingLedgerEntries() -> S0CleanupSnapshot {
        S0CleanupSnapshot(
            progress: progress,
            cleanableAssetCount: cleanableAssetCount,
            cleanableByteCount: cleanableByteCount,
            libraryTotalByteCount: libraryTotalByteCount,
            categories: categories,
            ledgerEntries: [],
            pendingDeletionByteCount: pendingDeletionByteCount,
            isLimitedAuthorization: isLimitedAuthorization
        )
    }
}

/// 数据源对「扫没扫完」的回报。与 `S0CleanupSnapshot`（回报「有没有数据」）
/// 分开：摄入数据不得改 `SC`，迁移一律经 `S0StateMachine.handle(_:)`。
enum S0ScanOutcome: Equatable, Sendable {
    case scanning
    case completed
    case failed(S0FailureCategory)
}

/// 四态判定的输入三元组。
struct S0StateInput: Equatable, Sendable {
    let scanState: S0ScanState
    let cleanableAssetCount: Int
    let failureCategory: S0FailureCategory?
}

/// 纯函数解析器（照 `S1AuthorizationDispatch` 的既有写法另立 enum）。
///
/// `cat` 不参与判定：SPEC-S0 v1 第二节第 1 部分明写 S0-4 按失败类别分两种
/// **版式**、不分列。它入参只为让四态判定的输入与规格的三元组逐字对齐。
enum S0StateResolver {
    static func state(for input: S0StateInput) -> S0State {
        switch input.scanState {
        case .scanning:
            return .scanning
        case .failed:
            return .failed
        case .completed:
            return input.cleanableAssetCount == 0 ? .empty : .ready
        }
    }
}

/// 首页可接收的输入（SPEC-S0 v1 第五节点击有效性矩阵的七行）。
enum S0Input: Equatable, Sendable {
    case categoryRow(hasItems: Bool, recognition: S0CategoryRecognition)
    case basketCapsule
    case profileButton
    case ledgerCleared
    case tabSwitch
    case failureRecovery
}

/// 迁移事件。与 SPEC-S0 v1 第四节整表逐行对应，见 `IC147S0BehaviorTests`
/// 的行号对账表。
enum S0Event: Equatable, Sendable {
    case applicationOpened
    case scanCompleted
    case scanFailed(S0FailureCategory)
    case categoryRowTapped(S0CategoryIdentifier)
    case basketCapsuleTapped
    case returnedFromCategoryPage
    case returnedFromConfirmation
    case verificationPassed(releasedByteCount: Int64)
    case verificationFailed
    case foregroundRestored(hasNewAssets: Bool)
    case organizeTabSelected
    case retrySucceeded
}

/// 迁移的落点。离开首页的三种去处只由本层**判定并回报**，实际导航由容器
/// 接管——S0 不另造一份提交路径（SPEC-S0 v1 第十节第 3 部分）。
enum S0Destination: Equatable, Sendable {
    case home(S0State)
    case categoryPage(S0CategoryIdentifier)
    case confirmation
    case organizeTab
}

final class S0StateMachine: ObservableObject {
    @Published private(set) var scanState: S0ScanState = .scanning
    @Published private(set) var ledgerState: S0LedgerState = .empty
    @Published private(set) var verificationState: S0VerificationState = .none
    @Published private(set) var obscuring: S0Obscuring = .closed
    @Published private(set) var failureCategory: S0FailureCategory?
    @Published private(set) var snapshot = S0CleanupSnapshot()
    /// 类别行的当前顺序。扫描期间冻结；转已完成或前台恢复时一次性重排。
    @Published private(set) var orderedCategoryIDs: [S0CategoryIdentifier] = []
    /// `Z`：累计释放量。只累加核对通过的 `Y`，不累加 L2。本卡只承载，
    /// 骨架视图不呈现（累计释放的呈现在账户页，属批次 5.2 之后）。
    @Published private(set) var cumulativeReleasedByteCount: Int64 = 0
    /// `Y`：**本次**核对得到的释放量。
    ///
    /// 与 `Z` 分开承载：文案 key `s0.home.pending.passed`（「设备可用空间 +」）
    /// 是 `Y` 的坑位，`Z` 另有「累计释放」一条，六个数字的措辞永不混用
    /// （SPEC-S0 v1 第二节第 3 部分）。拿 `Z` 去填 `Y` 的坑位，第二次核对通过
    /// 就会把两次之和冒充成本次释放量。
    @Published private(set) var lastVerifiedReleasedByteCount: Int64 = 0
    /// 重排次数。供「扫描中不重排、转已完成恰重排一次」的断言钉住。
    private(set) var categoryReorderCount = 0

    /// `D_全部` 的元素数。会话层数据的唯一定义处在 SPEC-S1 v9 第二节，
    /// **S0 不另持一份待删集合**，只经此闭包实时取数（照 S2 的
    /// `sessionMergedPendingDeletionCountProvider` 既有写法注入）。
    var mergedPendingDeletionCountProvider: (() -> Int)?

    init() {}

    // MARK: - 派生量

    var state: S0State {
        S0StateResolver.state(for: stateInput)
    }

    var stateInput: S0StateInput {
        S0StateInput(
            scanState: scanState,
            cleanableAssetCount: snapshot.cleanableAssetCount,
            failureCategory: failureCategory
        )
    }

    var isLimitedAuthorization: Bool {
        snapshot.isLimitedAuthorization
    }

    var pendingClearanceByteCount: Int64 {
        snapshot.ledgerEntries.reduce(into: 0) { total, entry in
            total += entry.byteCount
        }
    }

    var mergedPendingDeletionCount: Int {
        mergedPendingDeletionCountProvider?() ?? 0
    }

    var pendingDeletionByteCount: Int64 {
        snapshot.pendingDeletionByteCount
    }

    /// 按当前顺序取出的类别快照。顺序由 `orderedCategoryIDs` 决定，
    /// 不由数据源的返回顺序决定。
    var orderedCategories: [S0CategorySnapshot] {
        orderedCategoryIDs.compactMap { identifier in
            snapshot.categories.first { $0.id == identifier }
        }
    }

    /// S0-4 的显示元素清单只有大标题、人像圆钮与中央失败说明——
    /// **不显示 hero 数值、分段条与类别行**（SPEC-S0 v1 第三节第 4 部分）。
    /// 失败不清空 `snapshot`（重试成功后要续用），因而「就绪过、随后一次
    /// 增量读取失败」这条路径下类别行仍在数据里；显隐由本判定把关，
    /// 不由数据是否为空把关。
    var showsCategoryRows: Bool {
        state != .failed
    }

    /// 等待清空行：`LG=非空` 时显示；S0-4 同样不显示（同上清单）。
    var showsPendingClearanceRow: Bool {
        state != .failed && ledgerState == .nonEmpty
    }

    func category(_ identifier: S0CategoryIdentifier) -> S0CategorySnapshot? {
        snapshot.categories.first { $0.id == identifier }
    }

    // MARK: - 数据摄入

    /// 摄入一次取数结果。**只改数据，不改 `SC`**——迁移一律走 `handle(_:)`，
    /// 数据到达本身不构成迁移。扫描期间不重排（第 165 条第 1 条）。
    func ingest(_ newSnapshot: S0CleanupSnapshot) {
        snapshot = newSnapshot
        mergeCategoryOrder(with: newSnapshot.categories)
        setLedgerState(newSnapshot.ledgerEntries.isEmpty ? .empty : .nonEmpty)
    }

    // MARK: - 遮挡

    /// `Q` 的开合。`呈现` 期间首页全部输入不接收；关闭后恢复其覆盖前的基础
    /// 状态，全部数据不变——本方法因此不触碰除 `obscuring` 外的任何状态量。
    func setObscuring(_ newValue: S0Obscuring) {
        obscuring = newValue
    }

    // MARK: - 点击有效性矩阵（SPEC-S0 v1 第五节）

    func accepts(_ input: S0Input) -> Bool {
        guard obscuring == .closed else {
            return false
        }
        let currentState = state
        switch input {
        case let .categoryRow(hasItems, recognition):
            guard hasItems else {
                return false
            }
            switch currentState {
            case .scanning:
                return recognition != .awaitingScanCompletion
            case .ready:
                return recognition == .settled
            case .empty, .failed:
                return false
            }
        case .basketCapsule:
            return currentState != .failed && mergedPendingDeletionCount > 0
        case .profileButton:
            return true
        case .ledgerCleared:
            return currentState != .failed && ledgerState == .nonEmpty
        case .tabSwitch:
            return true
        case .failureRecovery:
            return currentState == .failed
        }
    }

    func acceptsCategoryRowTap(_ identifier: S0CategoryIdentifier) -> Bool {
        guard let candidate = category(identifier) else {
            return false
        }
        return accepts(
            .categoryRow(
                hasItems: candidate.hasItems,
                recognition: candidate.recognition
            )
        )
    }

    // MARK: - 核对流程的入口

    /// 点击「我已清空」后进入核对。核对本体（阈值、轮询、`FREE` 取数）属
    /// SPEC-S0 v1 第八节第 2 部分，排批次 5.3，本卡不实装；此处只负责
    /// `VF` 的入口守卫——`VF≠无` 只在 `LG=非空` 时可达。
    @discardableResult
    func beginVerification() -> Bool {
        guard accepts(.ledgerCleared) else {
            return false
        }
        setVerificationState(.checking)
        return true
    }

    // MARK: - 迁移（SPEC-S0 v1 第四节）

    @discardableResult
    func handle(_ event: S0Event) -> S0Destination {
        switch event {
        case .applicationOpened:
            failureCategory = nil
            setVerificationState(.none)
            setScanState(.scanning)
            return .home(state)

        case .scanCompleted:
            let wasScanning = scanState == .scanning
            setScanState(.completed)
            if wasScanning {
                reorderCategories()
            }
            return .home(state)

        case let .scanFailed(category):
            failureCategory = category
            setScanState(.failed)
            return .home(state)

        case let .categoryRowTapped(identifier):
            guard acceptsCategoryRowTap(identifier) else {
                return .home(state)
            }
            return .categoryPage(identifier)

        case .basketCapsuleTapped:
            guard accepts(.basketCapsule) else {
                return .home(state)
            }
            return .confirmation

        case .returnedFromCategoryPage, .returnedFromConfirmation:
            // 重算由调用方先 `ingest` 新快照完成；返回本身不改 `SC`，
            // 因而可清理量降为零时四态判定自然落到 S0-3。
            return .home(state)

        case let .verificationPassed(releasedByteCount):
            guard verificationState == .checking else {
                return .home(state)
            }
            let released = max(0, releasedByteCount)
            lastVerifiedReleasedByteCount = released
            cumulativeReleasedByteCount += released
            // 「账本清零」是状态机自己的事实，不只是翻一个旗标：条目一并清掉，
            // `pendingClearanceByteCount` 因而同步归零。**清零的持久化**属
            // SPEC-S0 v1 第八节第 2 部分，排批次 5.3；在那之前数据源若仍回报
            // 同一条账本，下一次 `ingest` 会把它重新算作非空，这是数据源侧的
            // 欠账，不是本层的判定错误。
            snapshot = snapshot.clearingLedgerEntries()
            setLedgerState(.empty)
            setVerificationState(.passed)
            return .home(state)

        case .verificationFailed:
            guard verificationState == .checking else {
                return .home(state)
            }
            setVerificationState(.failed)
            return .home(state)

        case let .foregroundRestored(hasNewAssets):
            if hasNewAssets {
                failureCategory = nil
                setScanState(.scanning)
            } else if scanState != .scanning {
                // 「扫描期间类别行顺序冻结」优先于「前台恢复时一次性重排」
                // （SPEC-S0 v1 第二节第 3 部分与第三节第 2 部分并置时的唯一
                // 自洽读法）：扫描中回到前台不得打乱正在增长的列表。
                reorderCategories()
            }
            return .home(state)

        case .organizeTabSelected:
            guard accepts(.tabSwitch) else {
                return .home(state)
            }
            return .organizeTab

        case .retrySucceeded:
            guard scanState == .failed else {
                return .home(state)
            }
            failureCategory = nil
            setScanState(.scanning)
            return .home(state)
        }
    }

    // MARK: - 状态量汇集口（陷阱 19）

    /// **唯一的 `SC` 写入口。** 除声明处的初值外，状态机内全部扫描态写入都
    /// 经此分派；`IC147S0BehaviorTests` 的直写点断言按「恰一处」钉住。
    private func setScanState(_ newValue: S0ScanState) {
        scanState = newValue
    }

    /// **唯一的 `LG` 写入口。** 两条路径（摄入账本条目、核对通过后清零）
    /// 都汇入本函数。
    private func setLedgerState(_ newValue: S0LedgerState) {
        ledgerState = newValue
    }

    /// **唯一的 `VF` 写入口。**
    private func setVerificationState(_ newValue: S0VerificationState) {
        verificationState = newValue
    }

    // MARK: - 类别顺序

    /// 扫描期间类别行顺序冻结：新到的类别按到达顺序缀在尾部，既有类别的
    /// 位置一律不动。重排只在 `reorderCategories()` 内发生。
    private func mergeCategoryOrder(with categories: [S0CategorySnapshot]) {
        let arrived = categories.map(\.id)
        var merged = orderedCategoryIDs.filter { arrived.contains($0) }
        for identifier in arrived where !merged.contains(identifier) {
            merged.append(identifier)
        }
        orderedCategoryIDs = merged
    }

    /// 一次性按 `c.bytes` 降序重排；无项目的类别沉底。
    private func reorderCategories() {
        categoryReorderCount += 1
        let ranked = snapshot.categories.sorted { lhs, rhs in
            if lhs.hasItems != rhs.hasItems {
                return lhs.hasItems
            }
            if lhs.candidateByteCount != rhs.candidateByteCount {
                return lhs.candidateByteCount > rhs.candidateByteCount
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
        orderedCategoryIDs = ranked.map(\.id)
    }
}
