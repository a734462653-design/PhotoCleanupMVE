import Combine
import SwiftUI

/// 两个 tab。**不设第三个 tab**（Decision_log 第 159 条、SPEC-S0 v1 第二节）。
/// 顺序即声明顺序：空间清理在左、逐张整理在右。
enum S0Tab: String, CaseIterable, Equatable, Sendable {
    case cleanup
    case organize
}

/// tab 选择态。
///
/// 切 tab **不改变任何会话层数据**（`sessionID`、`M`、`K`、`F`、`D_全部`）、
/// 不改变 S1 的 `T`／`O`、不触发任何重读——本类型因而只持有一个枚举，
/// 不引用会话层、不引用任何状态机，也不做任何副作用。
final class S0TabSelectionModel: ObservableObject {
    /// 开屏后落在「空间清理」（Decision_log 第 159 条⑤）。
    @Published private(set) var selectedTab: S0Tab = .cleanup
    /// 切换次数，供「切若干次后数据逐个不变」的夹具断言钉住确实切过。
    private(set) var selectionCount = 0

    init() {}

    func select(_ tab: S0Tab) {
        selectionCount += 1
        selectedTab = tab
    }
}

/// tab 图标符号名。
///
/// **登记制缺口（IC-147 实测）**：任务卡写「图标取 SPEC-S0 v1 第十四节
/// 登记」，但第十四节第 2 部分只登记了氛围底、分段条、类别行三族，
/// **没有 tab 图标条目**；第 3 部分只登记了两个 tab 名。此处两枚符号按任务卡
/// 的语义描述（容量条／卡片上下滑）取最接近的系统符号，属实现自填，已在
/// IC-147 自验报告登记为待决策会话补登记项，由 IC-148 视觉层按登记值替换。
enum S0TabSymbol {
    static let cleanup = "internaldrive"
    static let organize = "rectangle.stack"
}

/// 两 tab 容器。
///
/// 只承载路由的 `.s1, .upstream, .finished` 一个分支；`.s2`、`.confirmation`、
/// `.execution`、`.completion` 仍是全屏页，从 tab 推进去，不在 tab 内。
///
/// 两侧内容由调用方以 builder 传入（陷阱 16：构造点一律外提），容器本身不
/// 认识 S0 与 S1 的任何类型。
struct S0TabContainer<CleanupContent: View, OrganizeContent: View>: View {
    @ObservedObject var selection: S0TabSelectionModel

    private let cleanupContent: () -> CleanupContent
    private let organizeContent: () -> OrganizeContent

    init(
        selection: S0TabSelectionModel,
        @ViewBuilder cleanupContent: @escaping () -> CleanupContent,
        @ViewBuilder organizeContent: @escaping () -> OrganizeContent
    ) {
        self.selection = selection
        self.cleanupContent = cleanupContent
        self.organizeContent = organizeContent
    }

    var body: some View {
        TabView(selection: selectionBinding) {
            cleanupContent()
                .tabItem {
                    Label {
                        Text(L10n.text("s0.tab.cleanup"))
                    } icon: {
                        Image(systemName: S0TabSymbol.cleanup)
                    }
                }
                .tag(S0Tab.cleanup)
            organizeContent()
                .tabItem {
                    Label {
                        Text(L10n.text("s0.tab.organize"))
                    } icon: {
                        Image(systemName: S0TabSymbol.organize)
                    }
                }
                .tag(S0Tab.organize)
        }
    }

    private var selectionBinding: Binding<S0Tab> {
        Binding(
            get: { selection.selectedTab },
            set: { selection.select($0) }
        )
    }
}
