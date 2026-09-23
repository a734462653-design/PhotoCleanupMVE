// IC-165 C（裁定 三）：类别页的选择模型与 toast 呈现器，从退役的 S0CategoryPageView.swift 原样搬出。
import Combine
import Foundation

/// IC-156 C：类别页的选择集合 `SEL`（SPEC-S0 v2 第六节）。纯模型，可直接断言。
///
/// - 全部项默认不勾选，不预勾任何项；
/// - 网格顺序在页面存续期间稳定：移入待删篮只删项、不重排其余项；
/// - 「已选」计数与主按钮数值由同一份 `selected` 算出，不分别计算。
struct S0CategoryPageSelection: Equatable {
    private(set) var items: [S0CategoryAsset]
    private(set) var selected: Set<String> = []

    /// IC-160 A（裁定 三）：`preselected` 是跨 S2 往返带回来的保留集，与当前网格求交——
    /// 在 S2 里被标记的那几张已从列表消失，不该留在已选集合里。缺省为空即旧行为。
    init(items: [S0CategoryAsset], preselected: Set<String> = []) {
        self.items = items
        self.selected = preselected.intersection(Set(items.map { $0.id }))
    }

    /// 网格全部项的字节和（副行的体积）。
    var totalByteCount: Int64 {
        items.reduce(into: Int64(0)) { total, item in
            total += item.byteCount
        }
    }

    /// 已选项的字节和（常驻行与主按钮共用）。
    var selectedByteCount: Int64 {
        items.reduce(into: Int64(0)) { total, item in
            if selected.contains(item.id) {
                total += item.byteCount
            }
        }
    }

    /// 零选中时主按钮禁用（但不隐藏）。
    var isSubmitEnabled: Bool {
        !selected.isEmpty
    }

    /// 常驻行与主按钮两条文案共用的占位符取值：项数与字节量都取已选集合。
    var selectedTextReplacements: [String: String] {
        [
            "count": String(selected.count),
            "bytes": S0ByteCountText.string(forByteCount: selectedByteCount)
        ]
    }

    /// 副行文案的占位符取值：网格当前全部项的项数与字节量。
    var subtitleTextReplacements: [String: String] {
        [
            "count": String(items.count),
            "bytes": S0ByteCountText.string(forByteCount: totalByteCount)
        ]
    }

    /// 点格：切换其勾选态。不在网格里的标识不理会。
    mutating func toggle(_ id: String) {
        guard items.contains(where: { $0.id == id }) else {
            return
        }
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    /// 点「全选」：一项未选时全选当前网格全部项，否则全不选（第六节「再点为全不选」）。
    mutating func selectAllOrNone() {
        if selected.isEmpty {
            selected = Set(items.map { $0.id })
        } else {
            selected.removeAll()
        }
    }

    /// 移入成功：这些项从网格消失，其余项相对顺序不变；已选集合同步去掉它们。
    mutating func remove(ids: Set<String>) {
        items.removeAll { ids.contains($0.id) }
        selected.subtract(ids)
    }
}

/// IC-156 C：类别页底部短 toast 的呈现器。形状照 `S1FeedbackToastPresenter`：同一时刻只
/// 显示一条、新的一条替换旧的（旧的到期不清除新的）、计时经 `scheduler` 注入，测试不依赖
/// 真实时钟。类别页只有「已移入待删篮」一种提示，事件即已取好的文案本身。
final class S0FeedbackToastPresenter: ObservableObject {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    @Published private(set) var activeText: String?
    private(set) var presentedCount = 0
    private(set) var lastScheduledDurationSeconds: TimeInterval?
    private var generation = 0
    private let scheduler: Scheduler

    init(
        scheduler: @escaping Scheduler = { delay, action in
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay,
                execute: action
            )
        }
    ) {
        self.scheduler = scheduler
    }

    func present(text: String, durationMilliseconds: Double) {
        generation += 1
        let currentGeneration = generation
        presentedCount += 1
        activeText = text
        // 毫秒换秒走 `Measurement`，不写换算裸数。
        let seconds = Measurement(
            value: max(0, durationMilliseconds),
            unit: UnitDuration.milliseconds
        )
        .converted(to: .seconds)
        .value
        lastScheduledDurationSeconds = seconds
        scheduler(seconds) { [weak self] in
            self?.expire(generation: currentGeneration)
        }
    }

    private func expire(generation expiredGeneration: Int) {
        guard expiredGeneration == generation else {
            return
        }
        activeText = nil
    }
}
