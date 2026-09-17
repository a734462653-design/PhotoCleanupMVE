import SwiftUI

/// IC-156 D：「空间清理」tab 的承载容器（裁定 二）。
///
/// `S0View` 原样构造在这里——`S0View.swift`、`S0TabContainer.swift` 与 `Core/` 一字不动。
/// 本容器只做三件事：给首页的 `onEnterCategoryPage` 一个真闭包；用 `NavigationStack` 的
/// `navigationDestination(item:)` 推出类别页；在重算点把新快照喂给状态机。
///
/// - 进篮成功后立刻重算（第 180 条第四节第 4 条那处 `D_全部` 写入点）：真实服务的快照按
///   「修订 + 待删集合」记忆化，待删集合变了 `currentSnapshot()` 会重算，但快照变化钩子
///   不会触发，只能由写入这一侧主动摄入——hero、分段条、类别行随之同步减。
/// - 返回首页（迁移表第 7 行）：`presentedCategory` 由非 nil 变 nil 时先摄入再发返回事件，
///   可清理量降为零时四态判定自然落到 S0-3。返回不重排类别行。
/// - IC-157 C：从 S2 回到类别页（裁定 一）。进 S2 时本容器随 tab 容器整棵销毁，类别页身份在
///   App 持有的 `S0CleanupFlowModel` 里存活；回来时容器重建、直接推出类别页，出现时若类别页
///   在前就摄入一次——S2 内标记的资产已在 `D_全部`，类别页重取列表时自然消失，首页数字同步减。
///   不发返回事件（没回首页），不重排。
///
/// 协调器与会话层不进本文件：进篮写入与进 S2 都经 App 入口传入的闭包完成。
///
/// 两层都隐藏系统导航栏：类别页的顶排是自绘 chrome（卡面要求）；首页的顶排同样自绘，
/// 根页若留着空导航栏，它会占去顶部安全区、把首页整体下推一个导航栏高度（改变 H76
/// 已判过的首页几何，③ 真机 H77 第 1、7 条兜底）。
struct S0CleanupFlowView: View {
    private let machine: S0StateMachine
    private let dataProvider: any S0CleanupDataProviding
    private let onSwitchToOrganizeTab: () -> Void
    private let onMoveToBasket: (Set<String>, S0CategoryIdentifier) -> Bool
    /// IC-157 C：长按进 S2。实参为类别、类别页当前顺序、被长按那张；返回是否进入成功。
    private let onEnterS2: (S0CategoryIdentifier, [String], String) -> Bool
    private let toastDurationMilliseconds: Double

    /// 类别页身份的单一来源：推出与返回都只改它（不用系统返回栏、不用 `dismiss`）。
    /// IC-157 C：上提到 App 持有的模型，跨进出 S2 存活（裁定 一）。
    @ObservedObject var flowModel: S0CleanupFlowModel

    init(
        machine: S0StateMachine,
        dataProvider: any S0CleanupDataProviding,
        flowModel: S0CleanupFlowModel,
        onSwitchToOrganizeTab: @escaping () -> Void,
        onMoveToBasket: @escaping (Set<String>, S0CategoryIdentifier) -> Bool,
        onEnterS2: @escaping (S0CategoryIdentifier, [String], String) -> Bool,
        toastDurationMilliseconds: Double
    ) {
        self.machine = machine
        self.dataProvider = dataProvider
        self.flowModel = flowModel
        self.onSwitchToOrganizeTab = onSwitchToOrganizeTab
        self.onMoveToBasket = onMoveToBasket
        self.onEnterS2 = onEnterS2
        self.toastDurationMilliseconds = toastDurationMilliseconds
    }

    /// IC-157 C：容器出现时是否重算——类别页在前（从 S2 回来重建、或切走再切回本 tab）即摄入一次。
    /// 摄入幂等且不重排类别行；首次推出类别页不触发容器的出现回调。
    static func shouldRecomputeOnAppear(presentedCategory: S0CategoryIdentifier?) -> Bool {
        presentedCategory != nil
    }

    var body: some View {
        NavigationStack {
            homeScreen
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $flowModel.presentedCategory) { identifier in
                    page(for: identifier)
                }
        }
        .onChange(of: flowModel.presentedCategory) { previous, current in
            guard previous != nil, current == nil else {
                return
            }
            machine.ingest(dataProvider.currentSnapshot())
            machine.handle(.returnedFromCategoryPage)
        }
        .onAppear {
            if Self.shouldRecomputeOnAppear(presentedCategory: flowModel.presentedCategory) {
                machine.ingest(dataProvider.currentSnapshot())
            }
        }
    }

    /// 首页原样构造（陷阱 16：构造点外提）。
    private var homeScreen: some View {
        S0View(
            machine: machine,
            dataProvider: dataProvider,
            onEnterCategoryPage: { identifier in
                flowModel.presentedCategory = identifier
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
                    flowModel.presentedCategory = nil
                },
                onLongPress: { orderedAssetIDs, currentAssetID in
                    _ = onEnterS2(identifier, orderedAssetIDs, currentAssetID)
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
