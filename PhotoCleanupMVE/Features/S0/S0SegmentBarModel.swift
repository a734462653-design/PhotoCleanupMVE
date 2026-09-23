import SwiftUI

/// IC-148 C：分段条的呈现模型。**纯函数构造，可直接断言**——宽度分配与斜纹
/// 宽度不经视图层，视图只负责把 fraction 乘成像素。
///
/// 分段条呈现的是**照片库总占用 `LIB` 的构成**，不是可清理量的构成
/// （SPEC-S0 v1 第二节第 3 部分）。
struct S0SegmentBarModel: Equatable {

    /// 一段的身份。
    enum Kind: Equatable {
        /// 某个类别段，用该类别的登记色（IC-166 起含 `.category(.rest)`「其余照片」）。
        case category(S0CategoryIdentifier)
        /// 兜底段：只在 `LIB ≤ 0` 时整条独占（IC-166 裁定 五），没有对应的卡。
        case rest
        /// 「未扫描」段：只在 `SC=扫描中` 出现。**未扫段即进度呈现，
        /// 不引入独立进度条**（SPEC-S0 v1 第三节第 1 部分）。
        case unscanned
    }

    struct Segment: Equatable {
        let kind: Kind
        /// 占整条的比例，`[0, 1]`。
        let widthFraction: Double
        /// 该段内「等待清空」的斜纹宽度，同样以**整条**为分母，`≤ widthFraction`。
        let hatchFraction: Double
        /// 该段对应的字节量，供图例显示。
        let byteCount: Int64
    }

    let segments: [Segment]

    /// 全部段宽之和。归属去重后 `Σ c.bytes = LIB`，和恒为 1（`LIB` 为零时由兜底段独占）；
    /// `Σ c.bytes ≠ LIB` 的输入不再夹断（SPEC-S0 v3 下不存在，IC-166 裁定 五）。
    var totalWidthFraction: Double {
        segments.reduce(into: 0) { total, segment in
            total += segment.widthFraction
        }
    }

    var hatchedSegmentCount: Int {
        segments.filter { $0.hatchFraction > 0 }.count
    }

    /// 构造（SPEC-S0 v3 第二节第 2 部分，IC-166 裁定 五）。
    ///
    /// - `p` = 已扫张数 / 总张数（扫描中）；不在扫描中为 1。
    /// - 每个 `c.bytes > 0` 的类别（含「其余照片」）按给定顺序出段，段宽 = `c.bytes / LIB × p`；
    ///   预算夹断与补齐段随 v3 作废。
    /// - 斜纹宽 = `等待清空(c) / LIB`，`等待清空(c)` 按 `categoryID` 归并账本条目，不超过段宽。
    /// - 「未扫描」段宽 = `1 − p`，只在扫描中出现。
    static func make(
        categories: [S0CategorySnapshot],
        ledgerEntries: [S0LedgerEntry],
        libraryTotalByteCount: Int64,
        progress: S0ScanProgress,
        isScanning: Bool
    ) -> S0SegmentBarModel {
        let library = Double(max(0, libraryTotalByteCount))
        guard library > 0 else {
            // `LIB` 取不到时整条归兜底段，总和仍为 1。
            return S0SegmentBarModel(
                segments: [
                    Segment(
                        kind: .rest,
                        widthFraction: 1,
                        hatchFraction: 0,
                        byteCount: 0
                    )
                ]
            )
        }

        let scannedFraction = isScanning
            ? max(0, min(1, scannedRatio(progress)))
            : 1
        let unscannedFraction = 1 - scannedFraction

        var pendingByCategory: [S0CategoryIdentifier: Int64] = [:]
        for entry in ledgerEntries {
            pendingByCategory[entry.categoryID, default: 0] += entry.byteCount
        }

        var segments: [Segment] = []
        for category in categories where category.candidateByteCount > 0 {
            let width = Double(category.candidateByteCount) / library * scannedFraction
            guard width > 0 else {
                continue
            }
            let pending = Double(pendingByCategory[category.id] ?? 0) / library
            segments.append(
                Segment(
                    kind: .category(category.id),
                    widthFraction: width,
                    hatchFraction: max(0, min(pending, width)),
                    byteCount: category.candidateByteCount
                )
            )
        }

        if unscannedFraction > 0 {
            segments.append(
                Segment(
                    kind: .unscanned,
                    widthFraction: unscannedFraction,
                    hatchFraction: 0,
                    byteCount: 0
                )
            )
        }
        return S0SegmentBarModel(segments: segments)
    }

    private static func scannedRatio(_ progress: S0ScanProgress) -> Double {
        guard progress.totalAssetCount > 0 else {
            return 0
        }
        return Double(progress.scannedAssetCount)
            / Double(progress.totalAssetCount)
    }
}
