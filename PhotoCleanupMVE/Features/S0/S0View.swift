import Foundation
import SwiftUI

/// S0 首页的数据源协议（**消费侧定义**，照 `S2AssetSizeProbing` 的既有样板：
/// 协议在消费侧、实现在 `Services/`、由 App 入口注入、测试注入桩）。
///
/// 本协议是 S0 与扫描实现之间的唯一接缝：首页只认识这三个问题，不认识
/// PhotoKit。真实扫描服务排批次 5.1（等 H68 真机数据），落地后只换实现。
protocol S0CleanupDataProviding: AnyObject {
    /// 扫没扫完、失败没失败。调用方据此决定发哪个迁移事件。
    func currentScanOutcome() -> S0ScanOutcome
    /// 当前一次取数结果：进度、可清理去重字节、类别列表、照片库总占用、账本。
    func currentSnapshot() -> S0CleanupSnapshot
    /// 推进扫描。桩按剧本走下一步；真实现按增量缓存续扫。
    func advanceScan()
}

/// 字节量文本。SPEC-S0 v1 第十四节第 3 部分末句：字节量一律用系统
/// `ByteCountFormatter` 的 `.file` 口径，不自造单位字样拼接，格式化不进目录。
enum S0ByteCountText {
    static func string(forByteCount byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: max(0, byteCount))
    }
}

/// 类别显示名。取值以 SPEC-S0 v1 第十四节第 3 部分为唯一来源。
enum S0CategoryText {
    static func displayName(for identifier: S0CategoryIdentifier) -> String {
        switch identifier {
        case .bigVideo:
            return L10n.text("s0.category.bigVideo")
        case .screenshot:
            return L10n.text("s0.category.screenshot")
        case .screenRecording:
            return L10n.text("s0.category.screenRecording")
        case .duplicate:
            return L10n.text("s0.category.duplicate")
        case .similar:
            return L10n.text("s0.category.similar")
        }
    }
}

/// IC-147 C：S0 首页的**骨架视图**。
///
/// 本卡只做行为层：每个态显示其状态标识与关键数值的纯文字呈现，加上可点
/// 入口。**不做视觉层**——氛围底、玻璃卡、分段条、类别行版式、hero 大字
/// 全部属 IC-148（本项目既有分层惯例：IC-133 S3 行为层 → IC-134 视觉层）。
/// 观感不是最终态，这是已知的临时状态。
struct S0View: View {
    @ObservedObject var machine: S0StateMachine
    /// 只摄入一次。`TabView` 的 tab 每次被选中都会重发 `onAppear`，而
    /// `.applicationOpened` 会清 `VF` 与 `cat` 并把 `SC` 打回扫描中——
    /// 没有这道闸，来回切 tab 就会反复重置 S0 的状态（H70 第 2 条正是切十次）。
    @State private var hasBootstrapped = false

    private let dataProvider: (any S0CleanupDataProviding)?
    private let onEnterCategoryPage: (S0CategoryIdentifier) -> Void
    private let onEnterConfirmation: () -> Void
    private let onOpenAccountSheet: () -> Void
    private let onSwitchToOrganizeTab: () -> Void
    private let onOpenSystemSettings: () -> Void
    private let onRetry: () -> Void

    init(
        machine: S0StateMachine,
        dataProvider: (any S0CleanupDataProviding)? = nil,
        onEnterCategoryPage: @escaping (S0CategoryIdentifier) -> Void = { _ in },
        onEnterConfirmation: @escaping () -> Void = {},
        onOpenAccountSheet: @escaping () -> Void = {},
        onSwitchToOrganizeTab: @escaping () -> Void = {},
        onOpenSystemSettings: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {}
    ) {
        self.machine = machine
        self.dataProvider = dataProvider
        self.onEnterCategoryPage = onEnterCategoryPage
        self.onEnterConfirmation = onEnterConfirmation
        self.onOpenAccountSheet = onOpenAccountSheet
        self.onSwitchToOrganizeTab = onSwitchToOrganizeTab
        self.onOpenSystemSettings = onOpenSystemSettings
        self.onRetry = onRetry
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                topRow
                heroSection
                pendingRow
                categorySection
                failureSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .onAppear(perform: bootstrapIfNeeded)
    }

    // MARK: - 顶部两件

    @ViewBuilder
    private var topRow: some View {
        HStack {
            Text(L10n.text("s0.home.title"))
            Spacer()
            if showsBasketCapsule {
                Button(action: onEnterConfirmation) {
                    Text(basketCapsuleText)
                }
            }
            Button(action: onOpenAccountSheet) {
                Text(L10n.text("s0.account.title"))
            }
        }
    }

    /// 待删篮胶囊 V1 的显隐：**只按 SPEC-S0 v1 第三节「`D_全部` 为空时不
    /// 显示」与第五节矩阵第 3 行**，不加规格没有的与项。
    ///
    /// 体积位的真实来源要等批次 5.1 的扫描服务；在那之前本卡注入的桩回报零，
    /// 胶囊会读出「N · 零字节」。这是数据欠账、不是措辞越界（口径仍是
    /// 「待删篮 N 项 · X GB」那一条），已在 IC-147 自验报告登记。
    private var showsBasketCapsule: Bool {
        machine.accepts(.basketCapsule)
    }

    private var basketCapsuleText: String {
        L10n.text(
            "s0.basket.capsule",
            replacing: [
                "count": String(machine.mergedPendingDeletionCount),
                "volume": S0ByteCountText.string(
                    forByteCount: machine.pendingDeletionByteCount
                )
            ]
        )
    }

    // MARK: - hero

    @ViewBuilder
    private var heroSection: some View {
        switch machine.state {
        case .scanning:
            scanningHero
        case .ready:
            readyHero
        case .empty:
            emptyHero
        case .failed:
            EmptyView()
        }
    }

    /// 首帧数据到达前显示「正在扫描…」，不显示零字节大数字（第 165 条第 3 条）。
    ///
    /// 判据取**可清理字节是否为零**而不是已扫张数：扫描早期「已扫几千张、
    /// 一个大视频都还没命中」是常态，此时按张数判会画出「零字节」，正是该条
    /// 要避免的读数。
    @ViewBuilder
    private var scanningHero: some View {
        Text(L10n.text("s0.home.hero.label"))
        if machine.snapshot.cleanableByteCount == 0 {
            Text(L10n.text("s0.home.hero.scanning"))
        } else {
            Text(
                S0ByteCountText.string(
                    forByteCount: machine.snapshot.cleanableByteCount
                )
            )
        }
        Text(scanProgressText)
        Text(L10n.text("s0.home.hero.growing"))
    }

    @ViewBuilder
    private var readyHero: some View {
        Text(L10n.text("s0.home.hero.label"))
        Text(
            S0ByteCountText.string(
                forByteCount: machine.snapshot.cleanableByteCount
            )
        )
        Text(
            L10n.text(
                "s0.home.hero.library",
                replacing: [
                    "total": S0ByteCountText.string(
                        forByteCount: machine.snapshot.libraryTotalByteCount
                    )
                ]
            )
        )
        Text(L10n.text("s0.home.hero.overlap"))
    }

    /// 空态：主句 + 已扫描资产总数的副句 + 指向「逐张整理」tab 的入口
    /// （第 165 条第 17 条）。副句取已登记的进度文案，不自造措辞。
    @ViewBuilder
    private var emptyHero: some View {
        Text(L10n.text("s0.home.hero.empty.title"))
        Text(scanProgressText)
        Button(action: onSwitchToOrganizeTab) {
            Text(L10n.text("s0.home.hero.empty.action"))
        }
    }

    private var scanProgressText: String {
        L10n.text(
            "s0.home.hero.progress",
            replacing: [
                "scanned": String(machine.snapshot.progress.scannedAssetCount),
                "total": String(machine.snapshot.progress.totalAssetCount)
            ]
        )
    }

    // MARK: - 等待清空行

    @ViewBuilder
    private var pendingRow: some View {
        if machine.showsPendingClearanceRow {
            Text(
                L10n.text(
                    "s0.home.pending.label",
                    replacing: [
                        "total": S0ByteCountText.string(
                            forByteCount: machine.pendingClearanceByteCount
                        )
                    ]
                )
            )
            if machine.accepts(.ledgerCleared) {
                Button {
                    machine.beginVerification()
                } label: {
                    Text(L10n.text("s0.home.pending.action"))
                }
            }
        }
        verificationRow
    }

    /// `VF` 的纯文字呈现。核对本体（阈值、轮询、`FREE` 取数）属 SPEC-S0 v1
    /// 第八节第 2 部分，排批次 5.3，本卡不实装。
    @ViewBuilder
    private var verificationRow: some View {
        switch machine.verificationState {
        case .none:
            EmptyView()
        case .checking:
            Text(L10n.text("s0.home.pending.checking"))
        case .passed:
            Text(
                L10n.text(
                    "s0.home.pending.passed",
                    replacing: [
                        "released": S0ByteCountText.string(
                            forByteCount: machine.lastVerifiedReleasedByteCount
                        )
                    ]
                )
            )
        case .failed:
            Text(L10n.text("s0.home.pending.failed"))
        }
    }

    // MARK: - 类别行

    @ViewBuilder
    private var categorySection: some View {
        ForEach(machine.showsCategoryRows ? machine.orderedCategories : []) { category in
            Button {
                // 迁移由状态机判定；只有判定为「迁至类别页」才回调容器。
                if case let .categoryPage(identifier) =
                    machine.handle(.categoryRowTapped(category.id)) {
                    onEnterCategoryPage(identifier)
                }
            } label: {
                VStack(alignment: .leading) {
                    Text(S0CategoryText.displayName(for: category.id))
                    Text(categorySubtitle(for: category))
                }
            }
            .disabled(!machine.acceptsCategoryRowTap(category.id))
        }
    }

    private func categorySubtitle(for category: S0CategorySnapshot) -> String {
        switch category.recognition {
        case .awaitingScanCompletion:
            return L10n.text("s0.home.category.waiting")
        case .counting:
            return L10n.text(
                "s0.home.category.counting",
                replacing: [
                    "scanned": String(machine.snapshot.progress.scannedAssetCount),
                    "total": String(machine.snapshot.progress.totalAssetCount)
                ]
            )
        case .settled:
            guard category.hasItems else {
                return L10n.text("s0.home.category.empty")
            }
            return S0ByteCountText.string(
                forByteCount: category.candidateByteCount
            )
        }
    }

    // MARK: - 失败态

    @ViewBuilder
    private var failureSection: some View {
        if machine.state == .failed {
            if machine.failureCategory == .authorization {
                Text(L10n.text("s0.home.failed.auth.title"))
                Button(action: onOpenSystemSettings) {
                    Text(L10n.text("s0.home.failed.auth.action"))
                }
            } else {
                Text(L10n.text("s0.home.failed.read.title"))
                Button(action: onRetry) {
                    Text(L10n.text("s0.home.failed.read.action"))
                }
            }
        }
    }

    // MARK: - 取数

    /// 遵循 E4 口径：测试宿主下不自动启动任何活动。真机与模拟器上首次出现时
    /// 摄入一次数据源的当前结果，并按其回报发一次迁移事件。
    private func bootstrapIfNeeded() {
        guard !hasBootstrapped,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              let provider = dataProvider else {
            return
        }
        hasBootstrapped = true
        machine.ingest(provider.currentSnapshot())
        switch provider.currentScanOutcome() {
        case .scanning:
            machine.handle(.applicationOpened)
        case .completed:
            machine.handle(.scanCompleted)
        case let .failed(category):
            machine.handle(.scanFailed(category))
        }
    }
}
