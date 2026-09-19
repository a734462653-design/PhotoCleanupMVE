import Foundation

/// IC-162 A：「卡片叠」首页的呈现口径。**纯函数，可直接断言**——哪几张卡、
/// 每张占多少、哪张默认展开、快照变了展开的那张怎么回落，都不经视图层判断。
///
/// 不 import SwiftUI／Photos：本层只把状态机给的快照折成一摞卡。
enum S0DeckHomeModel {

    /// 「其余照片」卡的标识。类别卡取 `S0CategoryIdentifier` 的 `rawValue`，
    /// 与之不可能重名（五个 rawValue 都不含下划线）。
    static let restCardID = "__rest__"

    /// 一张卡。`category` 为 nil 即「其余照片」卡。
    struct Card: Equatable, Identifiable {
        let id: String
        let category: S0CategoryIdentifier?
        let byteCount: Int64
        /// 占照片库总占用的比例，夹在 `[0, 1]`。
        let fraction: Double
        /// `fraction` 的百分数读数（四舍五入）。
        let percent: Int
        /// 能不能点：与 `S0CategoryRowPresentation.showsDisclosure` 同式
        /// （第 170 条裁定 1：扫描期 `.counting` 可点、`.awaitingScanCompletion` 不可点）。
        /// 最终进不进类别页仍由 `S0StateMachine.handle(.categoryRowTapped)` 判定。
        let isEnterable: Bool
    }

    /// 摞出卡片。入参顺序即卡的上下次序（调用方给 `machine.orderedCategories`）。
    ///
    /// - 只保留 `hasItems` 的类别；
    /// - `restByteCount > 0` 时末尾追加一张「其余照片」卡，不可点；
    /// - `libraryTotalByteCount ≤ 0`（扫描早期取不到 `LIB`）时占比一律 0，不崩、不除零。
    static func cards(
        categories: [S0CategorySnapshot],
        restByteCount: Int64,
        libraryTotalByteCount: Int64
    ) -> [Card] {
        var result: [Card] = []
        for category in categories where category.hasItems {
            result.append(
                Card(
                    id: category.id.rawValue,
                    category: category.id,
                    byteCount: category.candidateByteCount,
                    fraction: fraction(
                        of: category.candidateByteCount,
                        in: libraryTotalByteCount
                    ),
                    percent: percent(
                        of: category.candidateByteCount,
                        in: libraryTotalByteCount
                    ),
                    isEnterable: category.hasItems
                        && category.recognition != .awaitingScanCompletion
                )
            )
        }
        guard restByteCount > 0 else {
            return result
        }
        result.append(
            Card(
                id: restCardID,
                category: nil,
                byteCount: restByteCount,
                fraction: fraction(of: restByteCount, in: libraryTotalByteCount),
                percent: percent(of: restByteCount, in: libraryTotalByteCount),
                isEnterable: false
            )
        )
        return result
    }

    /// 默认展开哪一张：第一张可点的卡。一张可点的都没有时不展开。
    static func defaultOpenID(_ cards: [Card]) -> String? {
        cards.first { $0.isEnterable }?.id
    }

    /// 快照变化后展开的那张怎么落：仍在且仍可点就原样留着，否则回落到默认那张。
    static func resolvedOpenID(current: String?, cards: [Card]) -> String? {
        if let current,
           cards.contains(where: { $0.id == current && $0.isEnterable }) {
            return current
        }
        return defaultOpenID(cards)
    }

    /// 前 `limit` 项的项数与字节和（不足 `limit` 时取全部）。供「建议先清」角标与
    /// 类别页「最大的 N 个」一节共用。
    static func topSum(
        _ items: [S0CategoryAsset],
        limit: Int
    ) -> (count: Int, byteCount: Int64) {
        let count = max(0, min(limit, items.count))
        let total = items.prefix(count).reduce(into: Int64(0)) { sum, item in
            sum += item.byteCount
        }
        return (count, total)
    }

    /// IC-162 B：类别页的两节切分。前 `topLimit` 项为「最大的 N 个」，其余为「其余 M 个」；
    /// 总数 ≤ `topLimit` 时第二节为空（页面据此不画第二节）。两节都保持入参顺序。
    static func sections(
        _ items: [S0CategoryAsset],
        topLimit: Int
    ) -> (top: [S0CategoryAsset], rest: [S0CategoryAsset]) {
        let count = max(0, min(topLimit, items.count))
        return (Array(items.prefix(count)), Array(items.dropFirst(count)))
    }

    // MARK: - 私有

    private static func fraction(of byteCount: Int64, in library: Int64) -> Double {
        guard library > 0 else {
            return 0
        }
        return min(1, max(0, Double(byteCount) / Double(library)))
    }

    private static func percent(of byteCount: Int64, in library: Int64) -> Int {
        Int((fraction(of: byteCount, in: library) * 100).rounded())
    }
}
