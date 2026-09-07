import SwiftUI

// MARK: - IC-134 E：S4 视觉登记制常量
//
// chrome 取值一律引用 S1 已登记常量，S4 不自造语汇；中央版式的量为④卡取值表转录。

enum S4ChromeMetrics {
    static let rowHeight = S1ChromeLayout.rowHeight
    static let topRowTopInset = S1ChromeLayout.topRowTopInset
    static let horizontalMargin = S1ChromeLayout.horizontalMargin
    static let titleFontSize = S1ChromeTypography.titleFontSize
    static let subtitleFontSize = S1ChromeTypography.subtitleFontSize
}

enum S4StatusMetrics {
    /// 不确定活动指示的视觉尺寸（④卡）。
    static let indicatorPointSize: CGFloat = 36
    /// 活动指示 → 标题。
    static let indicatorToTitleSpacing: CGFloat = 16
    /// 标题 → 正文。
    static let titleToBodySpacing: CGFloat = 8
    static let titleFontSize: CGFloat = 17
    static let bodyFontSize: CGFloat = 15
    /// 中央区左右留白（④取定：卡未给，取与 chrome 同值 16，长句不顶边）。
    static let horizontalMargin: CGFloat = 16
}

// MARK: - IC-134 E：S4 版式口径（测试钉住）

/// S4 只有一个停留态 S4-1；S4-2 版式相同、只换标题。
///
/// 三个终态**不画自己的版式**：持久化后立即交接 S5；若交接被生命周期推迟，
/// 界面保持 S4-1 版式而活动指示停止（④取定——状态机没有现成的活动指示口径，
/// 此处以 `S4State.isTerminal` 反解，不新增状态机成员）。
///
/// 页面没有任何应用内操作（规格第二节第 1 部分），故元素清单里没有按钮。
struct S4StatusPresentation: Equatable {
    let subtitle: String
    let title: String
    let body: String
    let isActivityIndicatorAnimating: Bool

    static func make(state: S4State, assetCount: Int) -> S4StatusPresentation {
        let title: String
        switch state {
        case .resumedInteraction:
            title = L10n.text("s4.status.confirming_title")
        case .submitted, .allSucceeded, .batchFailed, .resultUnknown:
            title = L10n.text("s4.status.submitted_title")
        }
        return S4StatusPresentation(
            subtitle: L10n.text(
                "s4.chrome.subtitle_format",
                replacing: ["count": String(assetCount)]
            ),
            title: title,
            body: L10n.text("s4.status.submitted_body"),
            isActivityIndicatorAnimating: !state.isTerminal
        )
    }
}

// MARK: - S4View

struct S4View: View {
    @ObservedObject var coordinator: CleanupCoordinator

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            if let machine = coordinator.s4Machine {
                content(machine)
            } else {
                ProgressView()
                    .id("s4-loading")
            }
        }
    }

    @ViewBuilder
    private func content(_ machine: S4StateMachine) -> some View {
        let presentation = S4StatusPresentation.make(
            state: machine.state,
            assetCount: machine.snapshot.assetCount
        )
        ZStack(alignment: .top) {
            statusColumn(presentation)
            chromeBar(presentation)
        }
    }

    /// 顶排只有中胶囊，没有圆钮——S4 不提供任何应用内操作。
    private func chromeBar(_ presentation: S4StatusPresentation) -> some View {
        VStack(spacing: 0) {
            Text(L10n.text("s4.chrome.title"))
                .font(
                    .system(
                        size: S4ChromeMetrics.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
            Text(presentation.subtitle)
                .font(.system(size: S4ChromeMetrics.subtitleFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .frame(height: S4ChromeMetrics.rowHeight)
        .s1ChromeGlassBackground(in: Capsule())
        .padding(.top, S4ChromeMetrics.topRowTopInset)
        .padding(.horizontal, S4ChromeMetrics.horizontalMargin)
    }

    /// 安全区顶到底居中：活动指示 → 标题 → 正文。不显示比例，也不显示预计时间。
    private func statusColumn(
        _ presentation: S4StatusPresentation
    ) -> some View {
        VStack(spacing: 0) {
            ProgressView()
                .controlSize(.large)
                .frame(
                    width: S4StatusMetrics.indicatorPointSize,
                    height: S4StatusMetrics.indicatorPointSize
                )
                .opacity(presentation.isActivityIndicatorAnimating ? 1 : 0)
                .id("s4-activity")
            Spacer().frame(height: S4StatusMetrics.indicatorToTitleSpacing)
            Text(presentation.title)
                .font(
                    .system(
                        size: S4StatusMetrics.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
            Spacer().frame(height: S4StatusMetrics.titleToBodySpacing)
            Text(presentation.body)
                .font(.system(size: S4StatusMetrics.bodyFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, S4StatusMetrics.horizontalMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
