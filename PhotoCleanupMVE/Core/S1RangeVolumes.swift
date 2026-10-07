import Foundation

/// IC-186：「逐张整理」V1 卡面的范围体积口径（SPEC-S1 v12 第二节 `体积(r)`、`U` 与 `总占用`、`占比(r)`；
/// 规格先行，界面与接线归 V1 视图卡）。
///
/// 表由「空间清理」的扫描服务给出（`S0LibraryScanService.assetByteCountTable()`），S1 不自行扫描；
/// 当前一遍扫描未完成或失败时没有表，S1 按「未知」显示（GB 位「统计中」、占比位不显示）。
struct S1AssetByteCountTable: Equatable, Sendable {
    /// 照片库全部资产（`U`）各自的 `SZ`：含已进待删篮的；iCloud 未解析的记 0（SPEC-S0 v6 第二节第 2 部分）。
    let byteCountByAssetID: [String: Int64]
    /// `总占用 = Σ SZ(a), a ∈ U`，即 V1 页头大数字。
    let totalByteCount: Int64

    init(byteCountByAssetID: [String: Int64]) {
        self.byteCountByAssetID = byteCountByAssetID
        totalByteCount = byteCountByAssetID.values.reduce(0, +)
    }

    /// `体积(r) = Σ SZ(a), a ∈ A(r)`。范围里有任何一张不在表里（例如扫描完成之后才新增的）即「未知」、
    /// 返回 nil——不以已知部分之和代替（SPEC-S1 v12 第二节不变量）。空范围为 0。
    func volume(of range: S1Range) -> Int64? {
        var sum: Int64 = 0
        for assetID in range.assetIDsNewestFirst {
            guard let byteCount = byteCountByAssetID[assetID] else {
                return nil
            }
            sum += byteCount
        }
        return sum
    }

    /// `占比(r) = 体积(r) ÷ 总占用`，整数百分比，钳在 0～100；取整与「空间清理」卡片叠同一
    /// （四舍五入、远离零）；`总占用` 为 0 时得 0。
    func sharePercent(ofVolume volume: Int64) -> Int {
        guard totalByteCount > 0 else {
            return 0
        }
        let fraction = min(max(Double(volume) / Double(totalByteCount), 0), 1)
        return Int((fraction * 100).rounded())
    }
}
