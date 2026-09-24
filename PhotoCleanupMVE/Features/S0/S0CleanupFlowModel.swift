import Combine

/// IC-157 C：「空间清理」tab 类别页身份的单一来源（裁定 一）。
///
/// 由 App 入口与 tab 选择态同层持有、跨路由存活：长按进 S2 时 tab 容器整棵销毁，回来时容器
/// 重建，这里的类别仍在，承载容器的 `NavigationStack` 重建时直接推出类别页。非 nil 即类别页在前；
/// 推出与返回都只改它。不引用会话层与任何状态机。
final class S0CleanupFlowModel: ObservableObject {
    @Published var presentedCategory: S0CategoryIdentifier? = nil

    /// IC-160 A（裁定 二）：类别页勾选跨 S2 往返的保留集。**不发布**——它只在类别页
    /// 重建时被读一次用于播种，发布变化只会引发多余的重绘。返回首页时由容器清空。
    var preservedSelection: Set<String> = []

    /// IC-171 C（④ 第 200 条第三节第 5 条）：长按进 S2 往返后类别页回到哪一格——长按那一刻记下
    /// 被长按的那一格的资产标识（页头未收起时记 nil，回来从顶部开始）。**不发布**，理由同上；
    /// 进类别与返回首页时由容器清空。
    var preservedScrollAnchor: String? = nil
}

/// 类别页「移入待删篮」写入会话层时的虚拟范围标识前缀：范围标识为前缀加类别标识。
/// 字符串登记，不是视觉值，不计入上面的 42 个。
enum S0CategoryPageRange {
    static let prefix = "cat:"
}
