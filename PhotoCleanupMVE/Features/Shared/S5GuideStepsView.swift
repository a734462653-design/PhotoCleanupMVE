import SwiftUI

// MARK: - IC-180：S5 五步竖排引导（SPEC-S5 v6 第三节第 2 部分；Decision_log 第 205 条第二节「S5 五步」）
//
// 放在 `Features/Shared/`：SPEC-S5 v6 `:129` 与 SPEC-S0 v4 `:404` 要求首页「未通过」提示复用**同一份**
// 引导（5.3 首页闭环实装时直接取用本视图，两处只维护一份文案）。纯说明，不带任何可点击跳转（`:123`）。

/// 五步，顺序固定（SPEC-S5 v6 `:117-121`）。`rawValue` = 步骤序号。
enum S5GuideStep: Int, CaseIterable, Equatable {
    case openPhotos = 1
    case openCollections = 2
    case openRecentlyDeleted = 3
    case tapSelect = 4
    case tapMoreDeleteAll = 5

    /// 每步一句。每个分支各自整句取文案、不拼 key——硬编码扫描器只认写死的字面量 key。
    var text: String {
        switch self {
        case .openPhotos:
            return L10n.text("s5.guide.step1")
        case .openCollections:
            return L10n.text("s5.guide.step2")
        case .openRecentlyDeleted:
            return L10n.text("s5.guide.step3")
        case .tapSelect:
            return L10n.text("s5.guide.step4")
        case .tapMoreDeleteAll:
            return L10n.text("s5.guide.step5")
        }
    }

    /// 每步一枚 SF Symbol（照 `S2InlineHintSymbol` 的写法：登记为常量，不经 helper 返回字面量）。
    var symbolName: String {
        switch self {
        case .openPhotos:
            return S5GuideSymbol.openPhotos
        case .openCollections:
            return S5GuideSymbol.openCollections
        case .openRecentlyDeleted:
            return S5GuideSymbol.openRecentlyDeleted
        case .tapSelect:
            return S5GuideSymbol.tapSelect
        case .tapMoreDeleteAll:
            return S5GuideSymbol.tapMoreDeleteAll
        }
    }
}

/// SF Symbol 名登记（规格与画布都未给名，决策会话卡内取定、S5 v7 回填；存在性由 CI 断言 `UIImage(systemName:)` 非空核）。
enum S5GuideSymbol {
    static let openPhotos = "photo.on.rectangle"
    static let openCollections = "rectangle.stack"
    static let openRecentlyDeleted = "trash"
    static let tapSelect = "checkmark.circle"
    static let tapMoreDeleteAll = "ellipsis.circle"
}

/// 视觉登记（卡内暂登，SPEC-S5 v7 补视觉登记节回填）。取值出处：R2 画布 `Tasks/design-s1-r2/gen.py`
/// `steps_list("num")`（`:414-426`）与 `a_s5()`（`:436`），CSS px 即 pt。色一律引用 `S1ChromeForeground`
/// （即 `S0DeckMetrics` 色板），不复制、不随系统外观；两个不透明度 0.4／0.8 是画布新值，前景表无对应成员。
enum S5GuideMetrics {
    /// 文字说明与五步之间（`margin-bottom: 12px`）。
    static let introBottomSpacing: CGFloat = 12
    /// 行间 `gap: 6px`；每行 `min-height: 44px`；编号圆与文字 `gap: 14px`。
    static let rowSpacing: CGFloat = 6
    static let rowMinHeight: CGFloat = 44
    static let leadSpacing: CGFloat = 14
    /// 编号圆 28、字 14/800；五步统一 1.5 描边 40%、字 80%（IC-182，④ 第 210／211 条：第 1 步实心退役）。
    static let numberCircleSide: CGFloat = 28
    static let numberFontSize: CGFloat = 14
    static let numberRingWidth: CGFloat = 1.5
    static let numberRingOpacity: Double = 0.4
    static let numberTextOpacity: Double = 0.8
    /// 正文 15/600、行高 21。
    static let textFontSize: CGFloat = 15
    static let textLineSpacing: CGFloat = 21
    /// 行尾符号 18，色取三级前景（`.dim2` 0.45）。
    static let symbolPointSize: CGFloat = 18
    /// IC-182（④ 第 211 条「五步不分行」）：正文单行，放不下时按需缩到最小 0.8 倍（375 宽下第 2 步 18 字需 ≤ 0.87）。
    static let textMinimumScaleFactor: CGFloat = 0.8
}

/// 五步竖排：编号圆 + 一句 + 行尾符号。不吃点击、无按钮；恒深色（色全部来自前景表）。
struct S5GuideStepsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: S5GuideMetrics.rowSpacing) {
            ForEach(S5GuideStep.allCases, id: \.rawValue) { step in
                row(step)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func row(_ step: S5GuideStep) -> some View {
        HStack(spacing: S5GuideMetrics.leadSpacing) {
            numberCircle(step)
            Text(step.text)
                .font(.system(
                    size: S5GuideMetrics.textFontSize,
                    weight: .semibold
                ))
                .lineSpacing(
                    S5GuideMetrics.textLineSpacing - S5GuideMetrics.textFontSize
                )
                .foregroundStyle(S1ChromeForeground.primary)
                // IC-182：不分行，长句按需缩字（只缩放不下的那一行）。
                .lineLimit(1)
                .minimumScaleFactor(S5GuideMetrics.textMinimumScaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: step.symbolName)
                .font(.system(size: S5GuideMetrics.symbolPointSize))
                .foregroundStyle(S1ChromeForeground.tertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: S5GuideMetrics.rowMinHeight)
        // 编号与句子合成一个 VoiceOver 焦点（行尾符号已隐藏）。
        .accessibilityElement(children: .combine)
    }

    /// 五步统一描边（IC-182；第 209 条裁定 三的「第 1 步实心」退役）。
    private func numberCircle(_ step: S5GuideStep) -> some View {
        Text(String(step.rawValue))
            .font(.system(
                size: S5GuideMetrics.numberFontSize,
                weight: .heavy
            ))
            .monospacedDigit()
            .foregroundStyle(
                S1ChromeForeground.primary
                    .opacity(S5GuideMetrics.numberTextOpacity)
            )
            .frame(
                width: S5GuideMetrics.numberCircleSide,
                height: S5GuideMetrics.numberCircleSide
            )
            .overlay {
                Circle().strokeBorder(
                    S1ChromeForeground.primary
                        .opacity(S5GuideMetrics.numberRingOpacity),
                    lineWidth: S5GuideMetrics.numberRingWidth
                )
            }
    }
}
