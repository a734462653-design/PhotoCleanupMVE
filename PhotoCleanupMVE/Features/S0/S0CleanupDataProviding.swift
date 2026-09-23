// IC-165 C（裁定 三）：S0 首页的数据源协议，从退役的 S0View.swift 原样搬出（类型体与文档注释逐字）。
import Foundation

/// S0 首页的数据源协议（**消费侧定义**，照 `S2AssetSizeProbing` 的既有样板：
/// 协议在消费侧、实现在 `Services/`、由 App 入口注入、测试注入桩）。
///
/// 本协议是 S0 与扫描实现之间的唯一接缝：首页只认识这三个问题，不认识
/// PhotoKit。真实扫描服务排批次 5.1（等 H68 真机数据），落地后只换实现。
protocol S0CleanupDataProviding: AnyObject {
    /// 扫没扫完、失败没失败。调用方据此决定发哪个迁移事件。
    func currentScanOutcome() -> S0ScanOutcome
    /// 当前一次取数结果：进度、可清理去重字节、类别列表、照片库总占用、账本。
    func currentSnapshot() -> S0CleanupSnapshot
    /// 推进扫描。桩按剧本走下一步；真实现按增量缓存续扫。
    func advanceScan()
    /// IC-155：某类别的候选资产，体积从大到小、同体积按标识升序。与当前快照同源：
    /// 集合即该类别的候选集，项数即其候选数，首项即其封面。
    func categoryAssets(_ id: S0CategoryIdentifier) -> [S0CategoryAsset]
    /// IC-153：快照变化钩子。真实现每次快照变化在主线程上调、每秒至多四次，
    /// 完成与失败那一次必达；桩从不调用。
    var onSnapshotDidChange: (() -> Void)? { get set }
}
