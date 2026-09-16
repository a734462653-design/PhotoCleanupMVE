import Foundation

/// 桩数据源的剧本。四个态与两种失败类别各有一条，供开发与 CI 驱动。
enum S0CleanupDataStubScenario: String, CaseIterable, Equatable, Sendable {
    case scanning
    case readyWithItems
    case readyWithoutItems
    case authorizationFailure
    case readFailure
}

/// IC-147 D：S0 数据源协议的桩实现。
///
/// **不发起任何 PhotoKit 请求，不读照片库，不写任何持久化**，也不起任何
/// 后台活动——因而天然满足 E4 口径（测试宿主下不自动启动）。真实扫描服务
/// 排批次 5.1（等 H68 真机数据），落地后只换实现、不动协议。
///
/// 确定性：同一剧本与同一步数恒给出逐字段相同的结果，`advanceScan()` 是
/// 唯一能改变输出的入口。账本条目的时刻取固定时间戳，不取当前时间。
final class S0CleanupDataStub: S0CleanupDataProviding {
    /// 扫描剧本走完全程需要的步数。
    static let scanStepCount = 4
    private static let totalAssetCount = 12_000
    /// 账本条目的固定提交时刻（2026-09-14T00:00:00Z），保证确定性。
    private static let ledgerCommittedAt = Date(timeIntervalSince1970: 1_789_344_000)
    private static let ledgerBaseline: Int64 = 6_000_000_000

    let scenario: S0CleanupDataStubScenario
    private let includesLedgerEntry: Bool
    private let pendingDeletionByteCount: Int64
    private(set) var scanStep: Int
    /// IC-153 D：协议要求的快照变化钩子。桩的数据只随 `advanceScan()` 同步改变，
    /// 调用方推进后自行取数，因而**从不调用**本钩子。
    var onSnapshotDidChange: (() -> Void)?

    init(
        scenario: S0CleanupDataStubScenario,
        includesLedgerEntry: Bool = false,
        pendingDeletionByteCount: Int64 = 0,
        scanStep: Int = 0
    ) {
        self.scenario = scenario
        self.includesLedgerEntry = includesLedgerEntry
        self.pendingDeletionByteCount = max(0, pendingDeletionByteCount)
        self.scanStep = min(max(0, scanStep), Self.scanStepCount)
    }

    // MARK: - S0CleanupDataProviding

    func currentScanOutcome() -> S0ScanOutcome {
        switch scenario {
        case .scanning:
            return scanStep >= Self.scanStepCount ? .completed : .scanning
        case .readyWithItems, .readyWithoutItems:
            return .completed
        case .authorizationFailure:
            return .failed(.authorization)
        case .readFailure:
            return .failed(.read)
        }
    }

    func currentSnapshot() -> S0CleanupSnapshot {
        switch scenario {
        case .scanning:
            return scanningSnapshot()
        case .readyWithItems:
            return readySnapshot(hasItems: true)
        case .readyWithoutItems:
            return readySnapshot(hasItems: false)
        case .authorizationFailure, .readFailure:
            return failureSnapshot()
        }
    }

    /// 推进一步扫描。失败与就绪剧本不推进——它们没有进度可走。
    func advanceScan() {
        guard scenario == .scanning, scanStep < Self.scanStepCount else {
            return
        }
        scanStep += 1
    }

    // MARK: - 剧本

    /// 扫描中：已扫部分随步数线性增长；重复与相似要等全库扫完才起算，
    /// 因而恒为 `awaitingScanCompletion` 且数值为零。
    private func scanningSnapshot() -> S0CleanupSnapshot {
        let step = Int64(scanStep)
        let scanned = Self.totalAssetCount * scanStep / Self.scanStepCount
        let categories = [
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: 3 * scanStep,
                candidateByteCount: 1_200_000_000 * step,
                recognition: .counting
            ),
            S0CategorySnapshot(
                id: .screenshot,
                candidateCount: 21 * scanStep,
                candidateByteCount: 140_000_000 * step,
                recognition: .counting
            ),
            S0CategorySnapshot(
                id: .screenRecording,
                candidateCount: 2 * scanStep,
                candidateByteCount: 480_000_000 * step,
                recognition: .counting
            ),
            S0CategorySnapshot(
                id: .duplicate,
                candidateCount: 0,
                candidateByteCount: 0,
                recognition: .awaitingScanCompletion
            ),
            S0CategorySnapshot(
                id: .similar,
                candidateCount: 0,
                candidateByteCount: 0,
                recognition: .awaitingScanCompletion
            )
        ]
        return S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: scanned,
                totalAssetCount: Self.totalAssetCount
            ),
            cleanableAssetCount: 26 * scanStep,
            // 去重求和：比各类别 `c.bytes` 之和少一截，正是重合项只计一次。
            cleanableByteCount: 1_700_000_000 * step,
            libraryTotalByteCount: 48_000_000_000,
            categories: categories,
            ledgerEntries: ledgerEntries(),
            pendingDeletionByteCount: pendingDeletionByteCount,
            isLimitedAuthorization: false
        )
    }

    /// 就绪：`hasItems` 为假时全部类别归零，四态判定因而落到 S0-3。
    private func readySnapshot(hasItems: Bool) -> S0CleanupSnapshot {
        let categories = [
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: hasItems ? 12 : 0,
                candidateByteCount: hasItems ? 4_800_000_000 : 0,
                recognition: .settled
            ),
            S0CategorySnapshot(
                id: .screenshot,
                candidateCount: hasItems ? 84 : 0,
                candidateByteCount: hasItems ? 560_000_000 : 0,
                recognition: .settled
            ),
            S0CategorySnapshot(
                id: .screenRecording,
                candidateCount: hasItems ? 9 : 0,
                candidateByteCount: hasItems ? 1_920_000_000 : 0,
                recognition: .settled
            ),
            S0CategorySnapshot(
                id: .duplicate,
                candidateCount: hasItems ? 46 : 0,
                candidateByteCount: hasItems ? 730_000_000 : 0,
                recognition: .settled
            ),
            S0CategorySnapshot(
                id: .similar,
                candidateCount: hasItems ? 118 : 0,
                candidateByteCount: hasItems ? 1_150_000_000 : 0,
                recognition: .settled
            )
        ]
        return S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: Self.totalAssetCount,
                totalAssetCount: Self.totalAssetCount
            ),
            cleanableAssetCount: hasItems ? 269 : 0,
            cleanableByteCount: hasItems ? 7_900_000_000 : 0,
            libraryTotalByteCount: 48_000_000_000,
            categories: categories,
            ledgerEntries: ledgerEntries(),
            pendingDeletionByteCount: pendingDeletionByteCount,
            isLimitedAuthorization: false
        )
    }

    /// 失败：不给 hero 数值、不给类别，`D_全部` 不可信因而也不给账本。
    private func failureSnapshot() -> S0CleanupSnapshot {
        S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: 0,
                totalAssetCount: Self.totalAssetCount
            ),
            cleanableAssetCount: 0,
            cleanableByteCount: 0,
            libraryTotalByteCount: 0,
            categories: [],
            ledgerEntries: [],
            pendingDeletionByteCount: 0,
            isLimitedAuthorization: false
        )
    }

    private func ledgerEntries() -> [S0LedgerEntry] {
        guard includesLedgerEntry else {
            return []
        }
        return [
            S0LedgerEntry(
                categoryID: .bigVideo,
                byteCount: 2_400_000_000,
                committedAt: Self.ledgerCommittedAt,
                availableCapacityBaseline: Self.ledgerBaseline
            )
        ]
    }
}
