import Combine
import Foundation

// MARK: - IC-195：S2 教学引导 D 的逻辑层（SPEC-S2 v24 决策 64／65 的 v24 修订、第二节第 6 部分 J1～J12、L1～L4）
//
// 本文件只有步骤、六个持久化标志与出现／收起规则，不含任何视图与文案；视图、登记值与 `S2View` 接线归界面层卡。
// 界面层卡落地之前，运行中的引导仍是 v23 三句就地提示（`S2InlineHints.swift`），两者共用第 1、2、4 步的三个「已会」键。

/// 四步。`rawValue` 同时是落盘键名的后缀；第 1、2、4 步与 v23 三句同键（J12：已学会三句的用户不再出这三步）。
enum S2GuideStep: String, CaseIterable, Equatable {
    /// 第 1 步：进 S2 即出（未会时）；一次真实上滑标记即已会。
    case swipeUp
    /// 第 2 步：真实标记成功、停在刚标记的那张时出；一次真实撤标即已会（三种来源都算）。
    case markedOnce
    /// 第 3 步：下滑或中央「撤销」撤标成功后出；在显时翻到另一张即已会。
    case undone
    /// 第 4 步：会话合并待删总数上升到阈值时出；一次真进确认页即已会。
    case confirmEntry
}

/// 当前在显的一项：四步之一，或「都学会了」完成提示（J1：同一时刻至多一项）。
enum S2GuideDisplay: Equatable {
    case step(S2GuideStep)
    case completion
}

// MARK: - 持久化

/// 六个持久化标志：四步各一「已会」、「完成已出」、「压暗已出」（J12）。本地、跨启动保留；
/// **不入 `S2CalibrationConfiguration`**，`schemaVersion` 不动。协议化以便夹具注入内存实现。
protocol S2GuideStoring {
    func isLearned(_ step: S2GuideStep) -> Bool
    func markLearned(_ step: S2GuideStep)
    var hasShownCompletion: Bool { get }
    func markCompletionShown()
    var hasDimmedIntro: Bool { get }
    func markIntroDimmed()
    /// 标定面板「重看教程」：清掉六个标志。
    func reset()
}

struct S2UserDefaultsGuideStore: S2GuideStoring {
    /// 与 v23 `S2UserDefaultsInlineHintStore` 同一前缀：第 1、2、4 步的键与三句的键逐字相同，即「原样沿用」。
    static let defaultsKeyPrefix =
        "com.iphonephotomanagement.PhotoCleanupMVE.s2.hint."
    static let completionKeySuffix = "completed"
    static let introDimmedKeySuffix = "introDimmed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func defaultsKey(for step: S2GuideStep) -> String {
        defaultsKeyPrefix + step.rawValue
    }

    static var completionKey: String {
        defaultsKeyPrefix + completionKeySuffix
    }

    static var introDimmedKey: String {
        defaultsKeyPrefix + introDimmedKeySuffix
    }

    func isLearned(_ step: S2GuideStep) -> Bool {
        defaults.bool(forKey: Self.defaultsKey(for: step))
    }

    func markLearned(_ step: S2GuideStep) {
        defaults.set(true, forKey: Self.defaultsKey(for: step))
    }

    var hasShownCompletion: Bool {
        defaults.bool(forKey: Self.completionKey)
    }

    func markCompletionShown() {
        defaults.set(true, forKey: Self.completionKey)
    }

    var hasDimmedIntro: Bool {
        defaults.bool(forKey: Self.introDimmedKey)
    }

    func markIntroDimmed() {
        defaults.set(true, forKey: Self.introDimmedKey)
    }

    func reset() {
        for step in S2GuideStep.allCases {
            defaults.removeObject(forKey: Self.defaultsKey(for: step))
        }
        defaults.removeObject(forKey: Self.completionKey)
        defaults.removeObject(forKey: Self.introDimmedKey)
    }
}

// MARK: - 协调器

/// 引导 D 的出现与收起规则。**不旁路手势分派**：真实事件全部来自视图已经在读的已发布状态与
/// `S2StateMachine` 的两个一次性信号（待删集合变化来源、当前张变化原因），由视图转进来。
///
/// 标记与计数、标记与当前张变化这几对事件在同一次更新里先后不定；各条规则按「两种顺序结果相同」写（J7）。
final class S2GuideCoordinator: ObservableObject {
    /// 第 4 步阈值（v23 起沿用）。
    static let confirmThreshold = 5
    /// 完成提示自动收起的秒数（J10）；计时由视图负责、不因 `V` 隐藏而暂停。
    static let completionAutoDismissSeconds: TimeInterval = 2

    /// 在显的一项；离开第 1 步的那一刻进门压暗随之消失（K4：压暗只与第 1 步同在）。
    @Published private(set) var display: S2GuideDisplay? = nil {
        didSet {
            if display != .step(.swipeUp) {
                showsIntroDim = false
            }
        }
    }

    /// 进门压暗（K4）：第一次进门（「压暗已出」为假）随第 1 步出现。
    @Published private(set) var showsIntroDim = false

    /// 本次进入不再出的步（因翻页收起、被第 4 步顶掉），**不记已会**；进入、离开、重看教程时清空。
    private(set) var collapsedThisVisit: Set<S2GuideStep> = []

    /// 本次进入点过「跳过教程」（J9）：不再出任何一项，不记已会、不落盘。
    private(set) var isSkippedThisVisit = false

    /// 上一次看到的会话合并待删总数；第 4 步只在计数上升时判（J7）。
    private(set) var lastMergedCount = 0

    /// 视图随 `interfaceVisibility` 同步；J10「当场出完成提示」只在 `V=显示` 时。
    var isInterfaceVisible = true

    private let store: S2GuideStoring

    init(store: S2GuideStoring = S2UserDefaultsGuideStore()) {
        self.store = store
    }

    func isLearned(_ step: S2GuideStep) -> Bool {
        store.isLearned(step)
    }

    /// L1（决策 65）：下一次标记成功时第 2 步会出现——此时视图让状态机停在刚标记的那张。
    var holdsPageOnNextMark: Bool {
        (display == nil || display == .step(.swipeUp)) && canShow(.markedOnce)
    }

    /// J2：进入 S2（首次、续接与 S3 返回重进同）。每次进入只调一次——再调会清掉本次的跳过与收起记录（界面层接线时守住）。
    func start(mergedCount: Int) {
        collapsedThisVisit = []
        isSkippedThisVisit = false
        lastMergedCount = mergedCount
        display = nil
        if !store.isLearned(.swipeUp) {
            display = .step(.swipeUp)
            if !store.hasDimmedIntro {
                store.markIntroDimmed()
                showsIntroDim = true
            }
        } else if mergedCount >= Self.confirmThreshold, !store.isLearned(.confirmEntry) {
            display = .step(.confirmEntry)
        } else if allStepsLearned, !store.hasShownCompletion {
            store.markCompletionShown()
            display = .completion
        }
    }

    /// J3：真实标记成功。`stayedOnMarkedAsset` = 标记后当前张仍是刚标记的那张（学习例外生效）。
    /// 没停住（放大态、或停留开关未及同步）时不出第 2 步、也不记本次收起，留给下一次停住的标记（L3）——
    /// 这样「标记」与「当前张变了」两个回调不论谁先到，结果相同。
    func assetDidBecomeMarked(stayedOnMarkedAsset: Bool) {
        learn(.swipeUp)
        if display == nil, stayedOnMarkedAsset, canShow(.markedOnce) {
            display = .step(.markedOnce)
        }
        showCompletionIfEarned()
    }

    /// J5：真实撤标。第 2 步记已会（三种来源都算）；只有下滑或中央「撤销」、且无步在显时出第 3 步
    /// （第 1、4 步在显时不出，见规格 J5 末两句）。
    func assetDidBecomeUnmarked(source: S2PendingDeletionChangeSource) {
        learn(.markedOnce)
        if source == .undo, display == nil, canShow(.undone) {
            display = .step(.undone)
        }
        showCompletionIfEarned()
    }

    /// J4／J6：当前张变了。第 2 步在显——任何原因都收起、不记已会；第 3 步在显——翻看（左右滑、横栏）
    /// 记已会，标记后自动进下一张只收起、不记已会。被收起的步本次进入不再出。
    func currentAssetDidChange(cause: S2CurrentAssetChangeCause) {
        switch display {
        case .step(.markedOnce)?:
            collapse(.markedOnce)
        case .step(.undone)?:
            if cause == .browse {
                learn(.undone)
                showCompletionIfEarned()
            } else {
                collapse(.undone)
            }
        default:
            break
        }
    }

    /// J7：会话合并待删总数上升且达到阈值、第 4 步未会且本次未收起、未跳过、当前不在显第 4 步时出第 4 步，
    /// 顶掉在显的第 1／2／3 步。第 2 步本次一律不再出（与 v23 同：标记与计数两个回调谁先到结果都一样），
    /// 被顶掉的第 3 步本次不再出。计数下降不触发。
    func mergedCountDidChange(_ count: Int) {
        let previous = lastMergedCount
        lastMergedCount = count
        guard count > previous,
              count >= Self.confirmThreshold,
              display != .step(.confirmEntry),
              canShow(.confirmEntry) else {
            return
        }
        collapsedThisVisit.insert(.markedOnce)
        if display == .step(.undone) {
            collapsedThisVisit.insert(.undone)
        }
        display = .step(.confirmEntry)
    }

    /// J8：点确认入口且退出载荷形成之后。第 4 步是最后学会的一步时，完成提示在下一次进入时按 J2 出（J10）。
    func confirmEntryTapped() {
        learn(.confirmEntry)
    }

    /// J9：「跳过教程」——收起在显的一项与进门压暗，本次进入不再出任何一项；不记已会、不落盘。
    func skip() {
        isSkippedThisVisit = true
        display = nil
    }

    /// J10：完成提示到点收起。
    func completionDidTimeOut() {
        guard display == .completion else {
            return
        }
        display = nil
    }

    /// J11：离开 S2——收起、清空本次记录，不记已会。
    func leaveScreen() {
        display = nil
        collapsedThisVisit = []
        isSkippedThisVisit = false
    }

    /// J12：标定面板「重看教程」——清零六个标志，当场重出第 1 步与进门压暗（压暗出现的同时记「压暗已出」）。
    func reset() {
        store.reset()
        collapsedThisVisit = []
        isSkippedThisVisit = false
        display = .step(.swipeUp)
        store.markIntroDimmed()
        showsIntroDim = true
    }

    private var allStepsLearned: Bool {
        S2GuideStep.allCases.allSatisfy { store.isLearned($0) }
    }

    private func canShow(_ step: S2GuideStep) -> Bool {
        !store.isLearned(step) && !collapsedThisVisit.contains(step) && !isSkippedThisVisit
    }

    /// J10：四步都已会的那一刻若仍在本页（`V=显示`）、无项在显、本次未跳过且「完成已出」为假，当场出完成提示。
    private func showCompletionIfEarned() {
        guard display == nil,
              isInterfaceVisible,
              !isSkippedThisVisit,
              !store.hasShownCompletion,
              allStepsLearned else {
            return
        }
        store.markCompletionShown()
        display = .completion
    }

    private func learn(_ step: S2GuideStep) {
        store.markLearned(step)
        if display == .step(step) {
            display = nil
        }
    }

    private func collapse(_ step: S2GuideStep) {
        collapsedThisVisit.insert(step)
        if display == .step(step) {
            display = nil
        }
    }
}
