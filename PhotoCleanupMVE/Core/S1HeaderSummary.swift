import Foundation

/// IC-191：「逐张整理」V1 页头大数字区与副行前段的数据（SPEC-S1 v12 第二节 `U` 与 `总占用`、`页头已看`，
/// 第六节第 3 部分副行；规格先行，界面归页头卡）。
///
/// 只给值、取不到的为 nil；四态下怎么显示（S1-1 骨架、S1-4 不显示数值、未知的画法）由页头卡定。
struct S1HeaderSummary: Equatable, Sendable {
    /// `总占用`：扫描服务当前一遍未完成或失败时没有字节表，为 nil（IC-186：取表内之和）。
    let totalByteCount: Int64?
    /// `页头已看 = ⌊|W ∩ U| ÷ |U| × 100⌋`，`|U| = 0` 为 0；`U` 取不到为 nil（取法见 `make`）。
    let seenPercent: Int?
    /// 副行前段 N：当前 `R(T)` 一级范围资产之并的元素数。
    let assetCount: Int
    /// 副行前段 M：当前 `R(T)` 的一级范围数。
    let topLevelRangeCount: Int

    /// `U` 与当前维度无关：按日期维度就绪时取年范围资产之并（规格定义原样）；其余维度取扫描服务字节表的键集
    /// （两条读路径取的是同一批资产），没有表即取不到；按日期维度未就绪也取不到。
    static func make(
        topLevelRanges: [S1Range],
        groupingDimension: S1GroupingDimension,
        isReady: Bool,
        seenAssetIDs: Set<String>,
        table: S1AssetByteCountTable?
    ) -> S1HeaderSummary {
        var topLevelAssetIDs = Set<String>()
        for range in topLevelRanges {
            topLevelAssetIDs.formUnion(range.assetIDsNewestFirst)
        }
        let seenPercent: Int?
        if groupingDimension == .date {
            seenPercent = isReady
                ? Self.percent(
                    seen: seenAssetIDs.intersection(topLevelAssetIDs).count,
                    total: topLevelAssetIDs.count
                )
                : nil
        } else if let table {
            let seenInLibrary = seenAssetIDs.filter { table.byteCountByAssetID[$0] != nil }.count
            seenPercent = Self.percent(seen: seenInLibrary, total: table.byteCountByAssetID.count)
        } else {
            seenPercent = nil
        }
        return S1HeaderSummary(
            totalByteCount: table?.totalByteCount,
            seenPercent: seenPercent,
            assetCount: topLevelAssetIDs.count,
            topLevelRangeCount: topLevelRanges.count
        )
    }

    /// 整数向下取、钳在 0～100；总数为 0 得 0（与卡上「已看 N%」同一取整）。
    static func percent(seen: Int, total: Int) -> Int {
        guard total > 0 else {
            return 0
        }
        return min(max(seen * 100 / total, 0), 100)
    }
}
