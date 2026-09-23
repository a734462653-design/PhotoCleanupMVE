import Foundation

/// IC-162 A：「卡片叠」首页的呈现口径。**纯函数，可直接断言**——哪几张卡、
/// 每张占多少、哪张默认展开、快照变了展开的那张怎么回落，都不经视图层判断。
///
/// 不 import SwiftUI／Photos：本层只把状态机给的快照折成一摞卡。
enum S0DeckHomeModel {

    /// 一张卡。标识取类别的 `rawValue`；IC-166 起「其余照片」也是类别（`.rest`），与其他类别卡同制。
    struct Card: Equatable, Identifiable {
        let id: String
        let category: S0CategoryIdentifier
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
    /// - `libraryTotalByteCount ≤ 0`（扫描早期取不到 `LIB`）时占比一律 0，不崩、不除零。
    static func cards(
        categories: [S0CategorySnapshot],
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

    // MARK: - IC-163 C：类别页排序与按月分节（裁定 四）

    /// 类别页的排序态。`size` 是入参顺序（数据源已按体积降序给出）；IC-167 C 加 `sizeAscending`
    /// （按体积升序，在本层重排）；另两个按拍摄日期。
    enum SortOrder {
        case size
        case sizeAscending
        case newestFirst
        case oldestFirst
    }

    /// 时间排序下的一节：某年某月的全部项，`monthStart` 为该月 1 日 0 点；无日期的一节为 nil。
    struct MonthSection: Equatable {
        let monthStart: Date?
        let items: [S0CategoryAsset]
    }

    /// 按排序态排列网格项。
    ///
    /// - `.size`：原样返回入参顺序；
    /// - `.sizeAscending`（IC-167 C，SPEC-S0 v4 第六节）：按字节升序，同体积按标识升序；与日期无关；
    /// - `.newestFirst`／`.oldestFirst`：有日期的按日期降序／升序，同日期按标识升序；
    ///   **无日期的一律排最后**，相互之间保持入参顺序。
    static func sorted(
        _ items: [S0CategoryAsset],
        by order: SortOrder,
        dates: [String: Date]
    ) -> [S0CategoryAsset] {
        if order == .sizeAscending {
            return items.sorted { lhs, rhs in
                lhs.byteCount != rhs.byteCount
                    ? lhs.byteCount < rhs.byteCount
                    : lhs.id < rhs.id
            }
        }
        guard order != .size else {
            return items
        }
        var dated: [(item: S0CategoryAsset, date: Date)] = []
        var undated: [S0CategoryAsset] = []
        for item in items {
            if let date = dates[item.id] {
                dated.append((item: item, date: date))
            } else {
                undated.append(item)
            }
        }
        dated.sort { lhs, rhs in
            guard lhs.date != rhs.date else {
                return lhs.item.id < rhs.item.id
            }
            return order == .newestFirst
                ? lhs.date > rhs.date
                : lhs.date < rhs.date
        }
        return dated.map { $0.item } + undated
    }

    /// 把排好的网格项按年月归节。节的次序与节内次序都随入参（各节按首次出现排）；
    /// 无日期的项归最后一节，`monthStart = nil`。空入参得空数组。
    static func monthSections(
        _ sorted: [S0CategoryAsset],
        dates: [String: Date],
        calendar: Calendar
    ) -> [MonthSection] {
        var monthOrder: [DateComponents] = []
        var itemsByMonth: [DateComponents: [S0CategoryAsset]] = [:]
        var undated: [S0CategoryAsset] = []
        for item in sorted {
            guard let date = dates[item.id] else {
                undated.append(item)
                continue
            }
            let month = calendar.dateComponents([.year, .month], from: date)
            if itemsByMonth[month] == nil {
                monthOrder.append(month)
            }
            itemsByMonth[month, default: []].append(item)
        }
        var result = monthOrder.map { month in
            MonthSection(
                monthStart: calendar.date(from: month),
                items: itemsByMonth[month] ?? []
            )
        }
        if !undated.isEmpty {
            result.append(MonthSection(monthStart: nil, items: undated))
        }
        return result
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
