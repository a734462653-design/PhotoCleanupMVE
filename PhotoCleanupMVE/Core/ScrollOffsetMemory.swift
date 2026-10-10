import CoreGraphics
import Foundation

/// IC-200（SPEC-S1 v12 `:220`／`:284`、SPEC-S0 v6 第十二节第 12 条）：一个滚动容器「内容顶部到视口顶部」的距离。
///
/// 路由往返（进 S2／S3 再回来）时 tab 容器整棵重建、视图 `@State` 全丢；这份记忆由活过往返的对象持有
/// （S1 的 `S1OpenCardState`、S0 的 `S0CleanupFlowModel`），容器重建后按它恢复（`OffsetRestoringScrollView`）。
/// **不发布**：滚动时每帧都写，发布会引发重绘。不入档：打开 App 从顶部开始。
final class ScrollOffsetMemory {
    var offset: CGFloat = 0

    /// 记录件读到的是内容顶部在滚动容器坐标系里的 `minY`（向下滚为负）；偏移取其相反数、不小于 0（顶部回弹不记）。
    static func offset(forContentMinY minY: CGFloat) -> CGFloat {
        max(0, -minY)
    }
}
