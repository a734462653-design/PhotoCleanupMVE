import SwiftUI

// MARK: - IC-134 G：S5 视觉登记制常量
//
// chrome 取值引用 S1 已登记常量；正文区与卡片为④卡取值表转录。

enum S5ChromeMetrics {
    static let rowHeight = S1ChromeLayout.rowHeight
    static let topRowTopInset = S1ChromeLayout.topRowTopInset
    static let horizontalMargin = S1ChromeLayout.horizontalMargin
    static let titleFontSize = S1ChromeTypography.titleFontSize
    static let subtitleFontSize = S1ChromeTypography.subtitleFontSize
}

enum S5PageLayout {
    /// 正文区上缘距安全区顶。
    static let contentTopInset: CGFloat = 63
    static let horizontalMargin: CGFloat = 16
    /// 卡间距。
    static let cardSpacing: CGFloat = 12
    /// 主按钮下缘距安全区底（引用 S2 已登记的底距）。
    static let buttonBottomInset = S2OverlayLayout.bottomRowBottomInset
    /// 正文区底部为主按钮预留的净空（④取定：卡未给，取按钮高 + 底距 + 一个卡间距）。
    static var contentBottomClearance: CGFloat {
        S5ButtonMetrics.height + buttonBottomInset + cardSpacing
    }
}

enum S5HeroMetrics {
    static let iconPointSize: CGFloat = 44
    static let iconToTitleSpacing: CGFloat = 8
    static let titleToBodySpacing: CGFloat = 8
    static let titleFontSize: CGFloat = 22
    static let bodyFontSize: CGFloat = 15
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 2
}

enum S5TileMetrics {
    static let columnCount = 3
    static let spacing: CGFloat = 8
    static let cornerRadius: CGFloat = 14
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 10
    static let numberFontSize: CGFloat = 24
    static let labelFontSize: CGFloat = 12
}

enum S5CardMetrics {
    static let cornerRadius: CGFloat = 14
    static let verticalPadding: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let keyFontSize: CGFloat = 13
    static let valueFontSize: CGFloat = 17
    static let noteFontSize: CGFloat = 12
    static let noteLineSpacing: CGFloat = 16
    /// 引导卡正文 13 / 行高 18。
    static let guidanceFontSize: CGFloat = 13
    static let guidanceLineSpacing: CGFloat = 18
    /// 键与值、值与旁注之间的间距（④取定：卡未给，取与卡间距同族的一半 6）。
    static let rowSpacing: CGFloat = 6
}

enum S5ButtonMetrics {
    static let height: CGFloat = 50
    static let cornerRadius: CGFloat = 25
    static let fontSize: CGFloat = 17
}

/// hero 图标用色。
///
/// ④取定：卡给的是 `#34C759` 与 `#FF9F0A` 两个十六进制值——前者是 systemGreen 的
/// 浅色取值，后者是 systemOrange 的**深色**取值。此处取系统动态色而不是把某一侧的
/// 字面值钉死，以保证明暗两套都正确；H60 第 5／6 项按观感复核。
enum S5HeroPalette {
    static var success: Color { Color(uiColor: .systemGreen) }
    static var warning: Color { Color(uiColor: .systemOrange) }
    static var neutral: Color { Color(uiColor: .tertiaryLabel) }
}

// MARK: - IC-134 G：四态展示口径（测试钉住）

enum S5StateElement: Equatable {
    case hero
    /// L1 结果三格——**只在 T0 与 F 出现**。
    case resultTiles
    case submittedCard
    case reasonCard
    case resultCard
    case volumeCard
    /// 引导卡——**只在 T0 与 U 出现**；不加截图（④ Lynn 2026-09-06）。
    case guidanceCard
    case primaryButton
}

/// 主按钮的动作口径。
enum S5PrimaryAction: Equatable {
    case leaveCompletion
    case returnToConfirmation
}

/// L1 三格的数值——一律取自 S4 交接的三个集合，视图不自己算。
struct S5ResultTileCounts: Equatable {
    let success: Int
    let failure: Int
    let unprocessed: Int
}

/// L2 体积卡口径：键 = 前缀，值 = 精确值或「至少 X」，旁注只在下界时出现。
enum S5VolumePrefix: Equatable {
    /// T0：本次移入最近删除的照片共。
    case movedToRecentlyDeleted
    /// C／F／U：本次清理的照片共。
    case cleaned

    /// 取文案的调用点必须是字面 key——扫描器不认变量传进来的 key。
    var text: String {
        switch self {
        case .movedToRecentlyDeleted:
            return L10n.text("s5.t0.volume_prefix")
        case .cleaned:
            return L10n.text("s5.volume.prefix")
        }
    }
}

struct S5VolumeCardModel: Equatable {
    let key: String
    let value: String
    let note: String?

    static func make(
        prefix: S5VolumePrefix,
        snapshot: SubmissionSnapshot
    ) -> S5VolumeCardModel {
        let formatted = DecimalVolumeFormatter.string(
            forByteCount: snapshot.knownTotalBytes
        )
        switch snapshot.volumeDisplayMode {
        case .exact:
            return S5VolumeCardModel(
                key: prefix.text,
                value: formatted,
                note: nil
            )
        case .lowerBound:
            return S5VolumeCardModel(
                key: prefix.text,
                value: L10n.text(
                    "s5.volume.lower_bound_format",
                    replacing: ["value": formatted]
                ),
                note: L10n.text(
                    "s5.volume.unavailable_note_format",
                    replacing: ["count": String(snapshot.unavailableCount)]
                )
            )
        }
    }
}

/// 四态版式的完整展示口径。
struct S5StatePresentation: Equatable {
    let subtitle: String
    let heroTitle: String
    let heroBody: String
    let elements: [S5StateElement]
    let tileCounts: S5ResultTileCounts?
    let volume: S5VolumeCardModel
    let volumeNoteExtra: String?
    let submittedValue: String?
    let reasonValue: String?
    let reasonNote: String?
    let resultValue: String?
    let resultNote: String?
    let primaryButtonTitle: String
    let primaryAction: S5PrimaryAction

    var showsResultTiles: Bool {
        elements.contains(.resultTiles)
    }

    var showsGuidanceCard: Bool {
        elements.contains(.guidanceCard)
    }

    static func make(state: S5State) -> S5StatePresentation {
        switch state {
        case let .movedToRecentlyDeleted(context):
            let title = L10n.text("s5.t0.title")
            return S5StatePresentation(
                subtitle: title,
                heroTitle: title,
                heroBody: L10n.text("s5.t0.body"),
                elements: [.hero, .resultTiles, .volumeCard, .guidanceCard, .primaryButton],
                tileCounts: S5ResultTileCounts(
                    success: context.successfulAssetIDs.count,
                    failure: 0,
                    unprocessed: 0
                ),
                volume: S5VolumeCardModel.make(
                    prefix: .movedToRecentlyDeleted,
                    snapshot: context.snapshot
                ),
                volumeNoteExtra: nil,
                submittedValue: nil,
                reasonValue: nil,
                reasonNote: nil,
                resultValue: nil,
                resultNote: nil,
                primaryButtonTitle: L10n.text("s5.action.leave"),
                primaryAction: .leaveCompletion
            )

        case let .cancelled(context):
            let title = L10n.text("s5.c.title")
            return S5StatePresentation(
                subtitle: title,
                heroTitle: title,
                heroBody: L10n.text("s5.c.body"),
                elements: [.hero, .submittedCard, .volumeCard, .primaryButton],
                tileCounts: nil,
                volume: S5VolumeCardModel.make(
                    prefix: .cleaned,
                    snapshot: context.snapshot
                ),
                volumeNoteExtra: L10n.text(
                    "s5.volume.original_submission_disclaimer"
                ),
                submittedValue: L10n.text(
                    "s5.card.submitted_value_format",
                    replacing: ["count": String(context.snapshot.assetCount)]
                ),
                reasonValue: nil,
                reasonNote: nil,
                resultValue: nil,
                resultNote: nil,
                primaryButtonTitle: L10n.text("s5.action.return_to_confirmation"),
                primaryAction: .returnToConfirmation
            )

        case let .failed(context):
            let title = L10n.text("s5.f.title")
            return S5StatePresentation(
                subtitle: title,
                heroTitle: title,
                heroBody: L10n.text("s5.f.body"),
                elements: [.hero, .resultTiles, .reasonCard, .volumeCard, .primaryButton],
                tileCounts: S5ResultTileCounts(
                    success: context.callback.successfulAssetIDs.count,
                    failure: context.callback.failedAssetIDs.count,
                    unprocessed: context.callback.unprocessedAssetIDs.count
                ),
                volume: S5VolumeCardModel.make(
                    prefix: .cleaned,
                    snapshot: context.snapshot
                ),
                volumeNoteExtra: L10n.text(
                    "s5.volume.original_submission_disclaimer"
                ),
                submittedValue: nil,
                reasonValue: context.callback.reason.message,
                reasonNote: L10n.text("s5.failure.retry_notice"),
                resultValue: nil,
                resultNote: nil,
                primaryButtonTitle: L10n.text("s5.action.return_to_confirmation"),
                primaryAction: .returnToConfirmation
            )

        case let .unknown(context):
            let title = L10n.text("s5.u.title")
            return S5StatePresentation(
                subtitle: title,
                heroTitle: title,
                heroBody: L10n.text(
                    "s5.u.body_format",
                    replacing: [
                        "reason": Self.reasonText(context.reason),
                        "count": String(context.snapshot.assetCount)
                    ]
                ),
                elements: [.hero, .resultCard, .volumeCard, .guidanceCard, .primaryButton],
                tileCounts: nil,
                volume: S5VolumeCardModel.make(
                    prefix: .cleaned,
                    snapshot: context.snapshot
                ),
                volumeNoteExtra: L10n.text(
                    "s5.volume.original_submission_disclaimer"
                ),
                submittedValue: nil,
                reasonValue: nil,
                reasonNote: nil,
                resultValue: L10n.text("s5.card.result_unknown"),
                resultNote: L10n.text("s5.unknown.manual_verification_notice"),
                primaryButtonTitle: L10n.text("s5.action.finish"),
                primaryAction: .leaveCompletion
            )
        }
    }

    static func reasonText(_ reason: S4UnknownReason) -> String {
        switch reason {
        case .activeWaitTimedOut:
            return L10n.text("submission.unknown_reason.callback_timeout")
        case .processTerminatedBeforeTerminalResult:
            return L10n.text("submission.unknown_reason.process_terminated")
        }
    }
}

// MARK: - S5View

struct S5View: View {
    @ObservedObject var coordinator: CleanupCoordinator

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            if let machine = coordinator.s5Machine {
                content(machine)
            } else {
                ProgressView()
                    .id("s5-loading")
            }
        }
    }

    @ViewBuilder
    private func content(_ machine: S5StateMachine) -> some View {
        let presentation = S5StatePresentation.make(state: machine.state)
        ZStack(alignment: .top) {
            body(presentation, state: machine.state)
            chromeBar(presentation)
            primaryButton(presentation)
        }
    }

    private func chromeBar(_ presentation: S5StatePresentation) -> some View {
        VStack(spacing: 0) {
            Text(L10n.text("s5.chrome.title"))
                .font(
                    .system(
                        size: S5ChromeMetrics.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
            Text(presentation.subtitle)
                .font(.system(size: S5ChromeMetrics.subtitleFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .frame(height: S5ChromeMetrics.rowHeight)
        .s1ChromeGlassBackground(in: Capsule())
        .padding(.top, S5ChromeMetrics.topRowTopInset)
        .padding(.horizontal, S5ChromeMetrics.horizontalMargin)
    }

    private func body(
        _ presentation: S5StatePresentation,
        state: S5State
    ) -> some View {
        ScrollView {
            VStack(spacing: S5PageLayout.cardSpacing) {
                hero(presentation, state: state)
                if let counts = presentation.tileCounts,
                   presentation.showsResultTiles {
                    resultTiles(counts)
                }
                if let submitted = presentation.submittedValue {
                    infoCard(
                        key: L10n.text("s5.card.submitted"),
                        value: submitted,
                        note: nil
                    )
                }
                if let reason = presentation.reasonValue {
                    infoCard(
                        key: L10n.text("s5.card.reason"),
                        value: reason,
                        note: presentation.reasonNote
                    )
                }
                if let result = presentation.resultValue {
                    infoCard(
                        key: L10n.text("s5.card.result"),
                        value: result,
                        note: presentation.resultNote
                    )
                }
                volumeCard(presentation)
                if presentation.showsGuidanceCard {
                    guidanceCard
                }
            }
            .padding(.horizontal, S5PageLayout.horizontalMargin)
            .padding(.top, S5PageLayout.contentTopInset)
            .padding(.bottom, S5PageLayout.contentBottomClearance)
        }
    }

    private func hero(
        _ presentation: S5StatePresentation,
        state: S5State
    ) -> some View {
        VStack(spacing: 0) {
            heroIcon(state)
            Spacer().frame(height: S5HeroMetrics.iconToTitleSpacing)
            Text(presentation.heroTitle)
                .font(
                    .system(size: S5HeroMetrics.titleFontSize, weight: .bold)
                )
                .foregroundStyle(S1ChromeForeground.primary)
            Spacer().frame(height: S5HeroMetrics.titleToBodySpacing)
            Text(presentation.heroBody)
                .font(.system(size: S5HeroMetrics.bodyFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, S5HeroMetrics.topPadding)
        .padding(.bottom, S5HeroMetrics.bottomPadding)
    }

    @ViewBuilder
    private func heroIcon(_ state: S5State) -> some View {
        let font = Font.system(size: S5HeroMetrics.iconPointSize)
        switch state {
        case .movedToRecentlyDeleted:
            Image(systemName: "checkmark.circle")
                .font(font)
                .foregroundStyle(S5HeroPalette.success)
        case .cancelled:
            Image(systemName: "arrow.uturn.backward")
                .font(font)
                .foregroundStyle(S5HeroPalette.neutral)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(font)
                .foregroundStyle(S5HeroPalette.warning)
        case .unknown:
            Image(systemName: "questionmark.circle")
                .font(font)
                .foregroundStyle(S5HeroPalette.neutral)
        }
    }

    private func resultTiles(_ counts: S5ResultTileCounts) -> some View {
        HStack(spacing: S5TileMetrics.spacing) {
            tile(
                value: counts.success,
                label: L10n.text("s5.tile.success"),
                color: S5HeroPalette.success
            )
            tile(
                value: counts.failure,
                label: L10n.text("s5.tile.failure"),
                color: counts.failure > 0
                    ? Color(uiColor: .systemRed)
                    : S1ChromeForeground.primary
            )
            tile(
                value: counts.unprocessed,
                label: L10n.text("s5.tile.unprocessed"),
                color: S1ChromeForeground.primary
            )
        }
    }

    private func tile(
        value: Int,
        label: String,
        color: Color
    ) -> some View {
        VStack(spacing: S5CardMetrics.rowSpacing) {
            Text(String(value))
                .font(
                    .system(
                        size: S5TileMetrics.numberFontSize,
                        weight: .bold,
                        design: .monospaced
                    )
                )
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: S5TileMetrics.labelFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, S5TileMetrics.topPadding)
        .padding(.bottom, S5TileMetrics.bottomPadding)
        .background(cardBackground(cornerRadius: S5TileMetrics.cornerRadius))
    }

    private func volumeCard(_ presentation: S5StatePresentation) -> some View {
        let model = presentation.volume
        let note = [model.note, presentation.volumeNoteExtra]
            .compactMap { $0 }
            .joined(separator: "\n")
        return infoCard(
            key: model.key,
            value: model.value,
            note: note.isEmpty ? nil : note
        )
    }

    private func infoCard(
        key: String,
        value: String,
        note: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: S5CardMetrics.rowSpacing) {
            Text(key)
                .font(.system(size: S5CardMetrics.keyFontSize))
                .foregroundStyle(S1ChromeForeground.secondary)
            Text(value)
                .font(
                    .system(
                        size: S5CardMetrics.valueFontSize,
                        design: .monospaced
                    )
                )
                .foregroundStyle(S1ChromeForeground.primary)
            if let note {
                Text(note)
                    .font(.system(size: S5CardMetrics.noteFontSize))
                    .lineSpacing(
                        S5CardMetrics.noteLineSpacing
                            - S5CardMetrics.noteFontSize
                    )
                    .foregroundStyle(S1ChromeForeground.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, S5CardMetrics.verticalPadding)
        .padding(.horizontal, S5CardMetrics.horizontalPadding)
        .background(cardBackground(cornerRadius: S5CardMetrics.cornerRadius))
    }

    /// 引导卡：告诉用户去系统「照片」的「最近删除」自己清空。**不加截图。**
    private var guidanceCard: some View {
        Text(L10n.text("s5.recently_deleted.boundary_notice"))
            .font(.system(size: S5CardMetrics.guidanceFontSize))
            .lineSpacing(
                S5CardMetrics.guidanceLineSpacing
                    - S5CardMetrics.guidanceFontSize
            )
            .foregroundStyle(S1ChromeForeground.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, S5CardMetrics.verticalPadding)
            .padding(.horizontal, S5CardMetrics.horizontalPadding)
            .background(cardBackground(cornerRadius: S5CardMetrics.cornerRadius))
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func primaryButton(
        _ presentation: S5StatePresentation
    ) -> some View {
        Button {
            switch presentation.primaryAction {
            case .leaveCompletion:
                coordinator.leaveCompletion()
            case .returnToConfirmation:
                coordinator.returnToConfirmation()
            }
        } label: {
            Text(presentation.primaryButtonTitle)
                .font(
                    .system(
                        size: S5ButtonMetrics.fontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(primaryButtonForeground(presentation))
                .frame(maxWidth: .infinity)
                .frame(height: S5ButtonMetrics.height)
                .background(
                    RoundedRectangle(
                        cornerRadius: S5ButtonMetrics.cornerRadius,
                        style: .continuous
                    )
                    .fill(primaryButtonFill(presentation))
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, S5PageLayout.horizontalMargin)
        .padding(.bottom, S5PageLayout.buttonBottomInset)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    /// T0「离开」与 U「完成」黑底白字（深色自动反转为白底黑字，取 primary 与页面底色）；
    /// C／F「返回确认页」tint 底白字。
    private func primaryButtonFill(
        _ presentation: S5StatePresentation
    ) -> Color {
        switch presentation.primaryAction {
        case .leaveCompletion:
            return S1ChromeForeground.primary
        case .returnToConfirmation:
            return Color.accentColor
        }
    }

    private func primaryButtonForeground(
        _ presentation: S5StatePresentation
    ) -> Color {
        switch presentation.primaryAction {
        case .leaveCompletion:
            return Color(uiColor: .systemGroupedBackground)
        case .returnToConfirmation:
            return Color.white
        }
    }
}
