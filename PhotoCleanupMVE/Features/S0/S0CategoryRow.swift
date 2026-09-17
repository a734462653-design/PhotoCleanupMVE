import SwiftUI

/// IC-148 D：类别行的**呈现口径**。纯函数，可直接断言——排序、灰显、可点外观
/// 都不经视图层判断。
///
/// 可点性一律与 `S0StateMachine.accepts(_:)` 同口径（第 170 条裁定 1：S0-1 下
/// `.counting` **可点**、`.awaitingScanCompletion` 不可点）。本层只决定
/// **外观**，不决定能不能点——那是行为层的事，`IC147S0BehaviorTests` 的
/// 点击矩阵已经钉住。
enum S0CategoryRowPresentation {

    /// 行的暗度。
    /// - 「无项目」：`categoryDisabledOpacity`（登记值 0.45）。
    /// - 「尚未开始识别」：0.55（SPEC-S0 v1 第三节第 1 部分「整行降为 55%
    ///   不透明」——该值写在**第三节正文**而非第十四节登记表，见
    ///   `S0CategoryRowProse`）。
    /// - 其余：不压暗。
    static func rowOpacity(for category: S0CategorySnapshot) -> Double {
        if category.recognition == .awaitingScanCompletion {
            return S0CategoryRowProse.awaitingRecognitionOpacity
        }
        if !category.hasItems {
            return S0HomeMetrics.categoryDisabledOpacity
        }
        return 1
    }

    /// 数值位是否显示「—」：尚未开始识别的类别没有可信读数
    /// （SPEC-S0 v1 第三节第 1 部分「数值位显示「—」」）。
    static func showsUnavailableValue(
        for category: S0CategorySnapshot
    ) -> Bool {
        category.recognition == .awaitingScanCompletion
    }

    /// 是否画进入指示：只有能进类别页的行才画。
    static func showsDisclosure(for category: S0CategorySnapshot) -> Bool {
        category.hasItems && category.recognition != .awaitingScanCompletion
    }

    /// 排序：按 `c.bytes` 降序，**全部无项目的类别沉底**。
    ///
    /// 与 `S0StateMachine.reorderCategories()` 同一口径（该处是状态机侧的
    /// 权威排序）；本函数供呈现层在拿到任意顺序输入时给出同一结果，
    /// 并供断言 12 直接验证。
    static func sorted(
        _ categories: [S0CategorySnapshot]
    ) -> [S0CategorySnapshot] {
        categories.sorted { lhs, rhs in
            if lhs.hasItems != rhs.hasItems {
                return lhs.hasItems
            }
            if lhs.candidateByteCount != rhs.candidateByteCount {
                return lhs.candidateByteCount > rhs.candidateByteCount
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }
}

/// 写在 SPEC-S0 v1 **第三节正文**而不是第十四节登记表里的两个呈现取值。
///
/// 登记表（第十四节第 2 部分）没有这两项：55% 的行暗度只在第三节第 1 部分
/// 的散文里，数值占位「—」只在同一处。两者都**不是执行端自拟**，但也确实
/// 不在登记表内——已在 IC-148 自验报告登记为登记表缺口，建议 SPEC-S0 v2 补登。
enum S0CategoryRowProse {
    /// 取值出处：SPEC-S0 v1 第三节第 1 部分「整行降为 55% 不透明度」。
    static let awaitingRecognitionOpacity: Double = 0.55

    /// 取值出处：SPEC-S0 v1 第三节第 1 部分「数值位显示「—」」。
    /// 是**占位符号**不是文案，故不进 String Catalog（与数字单位不进目录同理）。
    static let unavailableValue = "\u{2014}"
}

/// 字节量文本的「值 + 单位」拆分。
///
/// `S0ByteCountText` 走系统 `ByteCountFormatter` 的 `.file` 口径（第十四节第 3
/// 部分末句：不自造单位字样拼接），而类别行的登记表把值与单位分了两个字号
/// （`categoryValueFontSize` 24 / `categoryValueUnitFontSize` 12），因此只能
/// 在**呈现层**把格式化结果按最后一个空格拆开。拆不开（本地化输出无空格）时
/// 整串当值、单位为空——不猜、不补。
enum S0ByteCountSplit {
    static func split(_ text: String) -> (value: String, unit: String) {
        guard let separator = text.lastIndex(of: " ") else {
            return (text, "")
        }
        let value = String(text[text.startIndex..<separator])
        let unit = String(text[text.index(after: separator)...])
        return (value, unit)
    }
}

/// 类别行。高 78、圆角 24（作触控形状）、封面位 60 圆角 16、色点 8，
/// 全部取 `S0HomeMetrics`。
///
/// **封面位**（IC-155）：`coverAssetID` 的生产者是扫描聚合（该类别候选集中体积最大的
/// 一张）。占位态是一个**空槽**（只描边、不填色），照 `factoryPlaceholder` 登记制的
/// 既有做法——不显示错图、不放假图；有标识时，共享缩略图视图以同边长、同圆角盖在空槽
/// 上（真图态）。取图只发生在共享缩略图视图里，S0 的文件本身不碰照片库；该视图禁网络，
/// 本机取不到缩略图（如 iCloud 优化储存）时它留空、不画系统图标，看到的仍是空槽。
struct S0CategoryRowView: View {
    let category: S0CategorySnapshot
    /// 副行文案。为 nil 时不画副行——已就绪且有项目的类别，其体积读数在
    /// 右侧值位，登记表没有给该情形的副行文案，不重复画同一个数字。
    let subtitle: String?
    /// IC-155：封面资产标识。为 nil 时只画空槽。
    let coverAssetID: String?

    /// 封面请求像素 = 封面边长 × 屏幕倍率（IC-155 裁定 三）。
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        HStack(spacing: S0HomeMetrics.categoryRowSpacing) {
            cover
            nameColumn
            Spacer(minLength: 0)
            valueColumn
            disclosure
        }
        .frame(height: S0HomeMetrics.categoryRowHeight)
        .opacity(S0CategoryRowPresentation.rowOpacity(for: category))
        .contentShape(
            RoundedRectangle(
                cornerRadius: S0HomeMetrics.categoryRowCornerRadius,
                style: .continuous
            )
        )
    }

    /// 封面位：描边空槽垫底（只描边，取玻璃卡的外圈描边不透明度，同页同族）；有标识时
    /// 缩略图以同边长、同圆角盖在上面。缩略图视图自己先框后裁（陷阱 24），这里不再包一层。
    private var cover: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: S0HomeMetrics.categoryCoverCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                Color.white.opacity(S0HomeMetrics.cardOuterRingOpacity)
            )
            if let coverAssetID {
                ThumbnailView(
                    assetIdentifier: coverAssetID,
                    sideLength: S0HomeMetrics.categoryCoverSide,
                    displayScale: displayScale,
                    cornerRadius: S0HomeMetrics.categoryCoverCornerRadius,
                    showsPlaceholderGlyph: false
                )
            }
        }
        .frame(
            width: S0HomeMetrics.categoryCoverSide,
            height: S0HomeMetrics.categoryCoverSide
        )
        .accessibilityHidden(true)
    }

    private var nameColumn: some View {
        VStack(alignment: .leading, spacing: S0HomeMetrics.categoryRowSpacing) {
            HStack(spacing: S0HomeMetrics.categoryRowSpacing) {
                RoundedRectangle(
                    cornerRadius: S0HomeMetrics.legendDotCornerRadius,
                    style: .continuous
                )
                .fill(S0HomeMetrics.categoryColor(for: category.id))
                .frame(
                    width: S0HomeMetrics.categoryColorDotSide,
                    height: S0HomeMetrics.categoryColorDotSide
                )
                Text(S0CategoryText.displayName(for: category.id))
                    .font(.system(size: S0HomeMetrics.categoryNameFontSize))
                    .foregroundStyle(S0HomePalette.text)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: S0HomeMetrics.categorySubFontSize))
                    .foregroundStyle(
                        S0HomePalette.dimmedText(
                            opacity: S0HomeMetrics.categorySubOpacity
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private var valueColumn: some View {
        if S0CategoryRowPresentation.showsUnavailableValue(for: category) {
            Text(S0CategoryRowProse.unavailableValue)
                .font(.system(size: S0HomeMetrics.categoryValueFontSize))
                .foregroundStyle(S0HomePalette.text)
        } else {
            let parts = S0ByteCountSplit.split(
                S0ByteCountText.string(forByteCount: category.candidateByteCount)
            )
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(parts.value)
                    .font(.system(size: S0HomeMetrics.categoryValueFontSize))
                    .foregroundStyle(S0HomePalette.text)
                Text(parts.unit)
                    .font(.system(size: S0HomeMetrics.categoryValueUnitFontSize))
                    .foregroundStyle(S0HomePalette.text)
            }
        }
    }

    @ViewBuilder
    private var disclosure: some View {
        if S0CategoryRowPresentation.showsDisclosure(for: category) {
            Image(systemName: S0CategoryRowSymbol.disclosure)
                .imageScale(.small)
                .foregroundStyle(
                    S0HomePalette.dimmedText(
                        opacity: S0HomeMetrics.categorySubOpacity
                    )
                )
                .accessibilityHidden(true)
        }
    }
}

/// 进入指示的系统符号名。集中一处，不散落字面量。
enum S0CategoryRowSymbol {
    static let disclosure = "chevron.right"
}
