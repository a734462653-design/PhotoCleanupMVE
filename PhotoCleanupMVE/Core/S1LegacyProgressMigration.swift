import Foundation

/// IC-188：v11 会话档的「最远位置」进度一次性并入看过集合 `W` 的纯计算（SPEC-S1 v12 第二节 `看过档`·迁移）。
///
/// 协调器在状态机采用新读到的范围时、`K` 钳制之前调用；按看过档的迁移标记只做一次。
enum S1LegacyProgressMigration {
    /// 虚拟范围（「空间清理」类别页长按进入）的标识前缀，与 `S0CategoryPageRange.prefix` 同值（测试钉相等）。
    /// 虚拟范围不迁。
    static let virtualRangePrefix = "cat:"
    /// 未分类维度唯一范围的标识，与照片库读取处同值（测试钉相等）。
    static let unclassifiedRangeID = "s1-unclassified"

    /// 范围标识所属的分组维度：日期维度的年与月标识以 `year:`／`month:` 开头、未分类为固定标识、其余为相册；
    /// 虚拟范围为 nil。
    static func dimension(ofRangeID rangeID: String) -> S1GroupingDimension? {
        if rangeID.hasPrefix(virtualRangePrefix) {
            return nil
        }
        if rangeID.hasPrefix("year:") || rangeID.hasPrefix("month:") {
            return .date
        }
        if rangeID == unclassifiedRangeID {
            return .unclassified
        }
        return .album
    }

    /// 除了本次采用的维度之外，还要另读哪些维度：`K` 中真实范围的所属维度去重、去掉本次维度，按 `allCases` 顺序。
    /// 本次维度里已消失的范围（`K` 有键、本次序列里没有）不触发重读——同一维度刚读过，再读也补不出序列。
    static func dimensionsToRead(
        for store: SessionStore,
        adoptedDimension: S1GroupingDimension
    ) -> [S1GroupingDimension] {
        let needed = Set(
            store.continuationsByRangeID.keys
                .compactMap { dimension(ofRangeID: $0) }
                .filter { $0 != adoptedDimension }
        )
        return S1GroupingDimension.allCases.filter { needed.contains($0) }
    }

    /// 迁移结果：`K` 中每个真实范围按 v11 决策 2 的已处理集合——`A(r, O_记录)` 中 `p_范围` 及其之前——之并。
    /// 给不出序列的范围跳过；`p_范围` 已不在序列里的范围得空集（不当作「全部看过」）。
    static func migratedAssetIDs(
        from store: SessionStore,
        sequencesNewestFirst: [String: [String]]
    ) -> Set<String> {
        var result: Set<String> = []
        for (rangeID, continuation) in store.continuationsByRangeID {
            guard dimension(ofRangeID: rangeID) != nil,
                  let newestFirst = sequencesNewestFirst[rangeID] else {
                continue
            }
            let recordedOrder: [String] = continuation.recordedSortOrder == .newestFirst
                ? newestFirst
                : Array(newestFirst.reversed())
            result.formUnion(
                store.processedAssetIDs(
                    for: rangeID,
                    orderedAssetIDs: recordedOrder,
                    currentSortOrder: continuation.recordedSortOrder
                )
            )
        }
        return result
    }
}
