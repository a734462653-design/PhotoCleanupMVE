import SwiftUI

/// IC-156 D：「空间清理」tab 的承载容器（裁定 二）。
///
/// `S0View` 原样构造在这里——`S0View.swift`、`S0TabContainer.swift` 与 `Core/` 一字不动。
/// 本容器只做三件事：给首页的 `onEnterCategoryPage` 一个真闭包；用 `NavigationStack` 的
/// `navigationDestination(item:)` 推出类别页；在两处重算点把新快照喂给状态机。
///
/// - 进篮成功后立刻重算（第 180 条第四节第 4 条那处 `D_全部` 写入点）：真实服务的快照按
///   「修订 + 待删集合」记忆化，待删集合变了 `currentSnapshot()` 会重算，但快照变化钩子
///   不会触发，只能由写入这一侧主动摄入——hero、分段条、类别行随之同步减。
/// - 返回首页（迁移表第 7 行）：`presentedCategory` 由非 nil 变 nil 时先摄入再发返回事件，
///   可清理量降为零时四态判定自然落到 S0-3。返回不重排类别行。
///
/// 协调器与会话层不进本文件：进篮写入经 App 入口传入的 `onMoveToBasket` 完成。
///
/// 两层都隐藏系统导航栏：类别页的顶排是自绘 chrome（卡面要求）；首页的顶排同样自绘，
/// 根页若留着空导航栏，它会占去顶部安全区、把首页整体下推一个导航栏高度（改变 H76
/// 已判过的首页几何，③ 真机 H77 第 1、7 条兜底）。
struct S0CleanupFlowView: View {
    private let machine: S0StateMachine
    private let dataProvider: any S0CleanupDataProviding
    private let onSwitchToOrganizeTab: () -> Void
    private let onMoveToBasket: (Set<String>, S0CategoryIdentifier) -> Bool
    private let toastDurationMilliseconds: Double

    /// 类别页身份的单一来源：推出与返回都只改它（不用系统返回栏、不用 `dismiss`）。
    @State private var presentedCategory: S0CategoryIdentifier? = nil

    init(
        machine: S0StateMachine,
        dataProvider: any S0CleanupDataProviding,
        onSwitchToOrganizeTab: @escaping () -> Void,
        onMoveToBasket: @escaping (Set<String>, S0CategoryIdentifier) -> Bool,
        toastDurationMilliseconds: Double
    ) {
        self.machine = machine
        self.dataProvider = dataProvider
        self.onSwitchToOrganizeTab = onSwitchToOrganizeTab
        self.onMoveToBasket = onMoveToBasket
        self.toastDurationMilliseconds = toastDurationMilliseconds
    }

    var body: some View {
        NavigationStack {
            homeScreen
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $presentedCategory) { identifier in
                    page(for: identifier)
                }
        }
        .onChange(of: presentedCategory) { previous, current in
            guard previous != nil, current == nil else {
                return
            }
            machine.ingest(dataProvider.currentSnapshot())
            machine.handle(.returnedFromCategoryPage)
        }
    }

    /// 首页原样构造（陷阱 16：构造点外提）。
    private var homeScreen: some View {
        S0View(
            machine: machine,
            dataProvider: dataProvider,
            onEnterCategoryPage: { identifier in
                presentedCategory = identifier
            },
            onSwitchToOrganizeTab: onSwitchToOrganizeTab
        )
    }

    /// 类别页（陷阱 16：构造点外提）。数据取自状态机当前快照的该类别与数据源的有序列表；
    /// 快照里恒有三条元数据类别，点得进来的类别在此必非 nil（③，报告登记）。
    @ViewBuilder
    private func page(for identifier: S0CategoryIdentifier) -> some View {
        if let category = machine.category(identifier) {
            S0CategoryPageView(
                category: category,
                items: dataProvider.categoryAssets(identifier),
                onMoveToBasket: { assetIDs in
                    moveToBasket(assetIDs, from: identifier)
                },
                onBack: {
                    presentedCategory = nil
                },
                toastDurationMilliseconds: toastDurationMilliseconds
            )
            .toolbar(.hidden, for: .tabBar)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// 写入成功才重算；失败时首页数据不动。
    private func moveToBasket(
        _ assetIDs: Set<String>,
        from identifier: S0CategoryIdentifier
    ) -> Bool {
        guard onMoveToBasket(assetIDs, identifier) else {
            return false
        }
        machine.ingest(dataProvider.currentSnapshot())
        return true
    }
}
