import Combine

/// IC-157 C：「空间清理」tab 类别页身份的单一来源（裁定 一）。
///
/// 由 App 入口与 tab 选择态同层持有、跨路由存活：长按进 S2 时 tab 容器整棵销毁，回来时容器
/// 重建，这里的类别仍在，承载容器的 `NavigationStack` 重建时直接推出类别页。非 nil 即类别页在前；
/// 推出与返回都只改它。不引用会话层与任何状态机。
final class S0CleanupFlowModel: ObservableObject {
    @Published var presentedCategory: S0CategoryIdentifier? = nil
}
