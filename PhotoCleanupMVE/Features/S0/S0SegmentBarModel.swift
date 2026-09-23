import SwiftUI

/// IC-148 C：分段条的呈现模型。**纯函数构造，可直接断言**——宽度分配与斜纹
/// 宽度不经视图层，视图只负责把 fraction 乘成像素。
///
/// 分段条呈现的是**照片库总占用 `LIB` 的构成**，不是可清理量的构成
/// （SPEC-S0 v1 第二节第 3 部分）。
struct S0SegmentBarModel: Equatable {

    /// 一段的身份。
    enum Kind: Equatable {
        /// 某个类别段，用该类别的登记色。
        case category(S0CategoryIdentifier)
        /// 「其余照片」段：中性白 `segmentRestOpacity`，独立成段并进图例。
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

    /// 全部段宽之和。构造保证恒为 1（`LIB` 为零时由「其余照片」独占）。
    var totalWidthFraction: Double {
        segments.reduce(into: 0) { total, segment in
            total += segment.widthFraction
        }
    }

    var hatchedSegmentCount: Int {
        segments.filter { $0.hatchFraction > 0 }.count
    }

    /// 构造。
    ///
    /// - 类别段宽 = `c.bytes / LIB`，按给定顺序依次取，取到预算用尽为止
    ///   （`c.bytes` 是**全量不去重**的，各类别之和可以超过 `LIB`，故必须夹住）。
    /// - 斜纹宽 = `等待清空(c) / LIB`，`等待清空(c)` 按 `categoryID` 归并账本条目。
    /// - 「未扫描」段宽 = `1 − 已扫占比`，只在扫描中出现。
    /// - 「其余照片」段补齐到 1。
    static func make(
        categories: [S0CategorySnapshot],
        ledgerEntries: [S0LedgerEntry],
        libraryTotalByteCount: Int64,
        progress: S0ScanProgress,
        isScanning: Bool
    ) -> S0SegmentBarModel {
        let library = Double(max(0, libraryTotalByteCount))
        guard library > 0 else {
            // `LIB` 取不到时整条归「其余照片」，总和仍为 1。
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

        let unscannedFraction = isScanning
            ? max(0, min(1, 1 - scannedRatio(progress)))
            : 0
        var budget = 1 - unscannedFraction

        var pendingByCategory: [S0CategoryIdentifier: Int64] = [:]
        for entry in ledgerEntries {
            pendingByCategory[entry.categoryID, default: 0] += entry.byteCount
        }

        var segments: [Segment] = []
        var restByteCount = max(0, libraryTotalByteCount)
        for category in categories where category.candidateByteCount > 0 {
            guard budget > 0 else {
                break
            }
            let raw = Double(category.candidateByteCount) / library
            let taken = max(0, min(raw, budget))
            guard taken > 0 else {
                continue
            }
            let pending = Double(pendingByCategory[category.id] ?? 0) / library
            segments.append(
                Segment(
                    kind: .category(category.id),
                    widthFraction: taken,
                    hatchFraction: max(0, min(pending, taken)),
                    byteCount: category.candidateByteCount
                )
            )
            budget -= taken
            restByteCount = max(0, restByteCount - category.candidateByteCount)
        }

        // 「其余照片」补齐；夹过之后 `budget` 不可能为负。
        segments.append(
            Segment(
                kind: .rest,
                widthFraction: max(0, budget),
                hatchFraction: 0,
                byteCount: restByteCount
            )
        )
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
