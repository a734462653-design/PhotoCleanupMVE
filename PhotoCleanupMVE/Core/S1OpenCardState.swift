import Combine
import Foundation

/// IC-191（SPEC-S1 v12 第二节 `open`；规格先行，界面归 V1 卡片叠卡）：列表页与年页各一张展开卡的身份。
///
/// 会话内视图态——不入档、不发会话快照、不触发读取。由状态机持有：进 S2 时 tab 容器整棵重建，视图 `@State`
/// 活不过一次往返（IC-157／IC-178 同一教训），状态机跨路由保留。单独成一个可观察对象：点卡只让观察它的卡叠
/// 重画，不让观察状态机的整页（含每次全量重算的 `rangeRows`）重算。只经状态机写入；值没变不写（陷阱 5）。
final class S1OpenCardState: ObservableObject {
    /// 列表页展开的那张卡（一级范围标识）；没有卡为 nil。
    @Published private(set) var listRangeID: String?
    /// 年页展开的那张月卡；年页不在前为 nil。
    @Published private(set) var yearPageRangeID: String?
    /// IC-200：列表页与年页的滚动偏移（路由往返重建后按它恢复；不发布、不入档）。
    let listScroll = ScrollOffsetMemory()
    let yearPageScroll = ScrollOffsetMemory()

    func setListRangeID(_ rangeID: String?) {
        guard listRangeID != rangeID else {
            return
        }
        listRangeID = rangeID
    }

    func setYearPageRangeID(_ rangeID: String?) {
        guard yearPageRangeID != rangeID else {
            return
        }
        yearPageRangeID = rangeID
        // IC-200：离开年页（展开态清成 nil）即归 0——再推入任何年都从顶部开始；点月卡换展开不归 0。
        if rangeID == nil {
            yearPageScroll.offset = 0
        }
    }

    /// `OPEN` 规则（SPEC-S0 v6 第三节第 2 部分）：所指的卡仍在即不变，否则回落到当前次序的第一张；没有卡为 nil。
    static func resolved(_ current: String?, among orderedRangeIDs: [String]) -> String? {
        if let current, orderedRangeIDs.contains(current) {
            return current
        }
        return orderedRangeIDs.first
    }
}
