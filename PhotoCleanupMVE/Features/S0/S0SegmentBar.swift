import SwiftUI

/// IC-148 C：分段条的呈现模型。**纯函数构造，可直接断言**——宽度分配与斜纹
/// 宽度不经视图层，视图只负责把 fraction 乘成像素。
///
/// 分段条呈现的是**照片库总占用 `LIB` 的构成**，不是可清理量的构成
/// （SPEC-S0 v1 第二节第 3 部分）。
struct S0SegmentBarModel: Equatable {

    /// 一段的身份。
    enum Kind: Equatable {
        /// 某个类别段，用该类别的登记色。
        case category(S0CategoryIdentifier)
        /// 「其余照片」段：中性白 `segmentRestOpacity`，独立成段并进图例。
        case rest
        /// 「未扫描」段：只在 `SC=扫描中` 出现。**未扫段即进度呈现，
        /// 不引入独立进度条**（SPEC-S0 v1 第三节第 1 部分）。
        case unscanned
    }

    struct Segment: Equatable {
        let kind: Kind
        /// 占整条的比例，`[0, 1]`。
        let widthFraction: Double
        /// 该段内「等待清空」的斜纹宽度，同样以**整条**为分母，`≤ widthFraction`。
        let hatchFraction: Double
        /// 该段对应的字节量，供图例显示。
        let byteCount: Int64
    }

    let segments: [Segment]

    /// 全部段宽之和。构造保证恒为 1（`LIB` 为零时由「其余照片」独占）。
    var totalWidthFraction: Double {
        segments.reduce(into: 0) { total, segment in
            total += segment.widthFraction
        }
    }

    var hatchedSegmentCount: Int {
        segments.filter { $0.hatchFraction > 0 }.count
    }

    /// 构造。
    ///
    /// - 类别段宽 = `c.bytes / LIB`，按给定顺序依次取，取到预算用尽为止
    ///   （`c.bytes` 是**全量不去重**的，各类别之和可以超过 `LIB`，故必须夹住）。
    /// - 斜纹宽 = `等待清空(c) / LIB`，`等待清空(c)` 按 `categoryID` 归并账本条目。
    /// - 「未扫描」段宽 = `1 − 已扫占比`，只在扫描中出现。
    /// - 「其余照片」段补齐到 1。
    static func make(
        categories: [S0CategorySnapshot],
        ledgerEntries: [S0LedgerEntry],
        libraryTotalByteCount: Int64,
        progress: S0ScanProgress,
        isScanning: Bool
    ) -> S0SegmentBarModel {
        let library = Double(max(0, libraryTotalByteCount))
        guard library > 0 else {
            // `LIB` 取不到时整条归「其余照片」，总和仍为 1。
            return S0SegmentBarModel(
                segments: [
                    Segment(
                        kind: .rest,
                        widthFraction: 1,
                        hatchFraction: 0,
                        byteCount: 0
                    )
                ]
            )
        }

        let unscannedFraction = isScanning
            ? max(0, min(1, 1 - scannedRatio(progress)))
            : 0
        var budget = 1 - unscannedFraction

        var pendingByCategory: [S0CategoryIdentifier: Int64] = [:]
        for entry in ledgerEntries {
            pendingByCategory[entry.categoryID, default: 0] += entry.byteCount
        }

        var segments: [Segment] = []
        var restByteCount = max(0, libraryTotalByteCount)
        for category in categories where category.candidateByteCount > 0 {
            guard budget > 0 else {
                break
            }
            let raw = Double(category.candidateByteCount) / library
            let taken = max(0, min(raw, budget))
            guard taken > 0 else {
                continue
            }
            let pending = Double(pendingByCategory[category.id] ?? 0) / library
            segments.append(
                Segment(
                    kind: .category(category.id),
                    widthFraction: taken,
                    hatchFraction: max(0, min(pending, taken)),
                    byteCount: category.candidateByteCount
                )
            )
            budget -= taken
            restByteCount = max(0, restByteCount - category.candidateByteCount)
        }

        // 「其余照片」补齐；夹过之后 `budget` 不可能为负。
        segments.append(
            Segment(
                kind: .rest,
                widthFraction: max(0, budget),
                hatchFraction: 0,
                byteCount: restByteCount
            )
        )
        if unscannedFraction > 0 {
            segments.append(
                Segment(
                    kind: .unscanned,
                    widthFraction: unscannedFraction,
                    hatchFraction: 0,
                    byteCount: 0
                )
            )
        }
        return S0SegmentBarModel(segments: segments)
    }

    private static func scannedRatio(_ progress: S0ScanProgress) -> Double {
        guard progress.totalAssetCount > 0 else {
            return 0
        }
        return Double(progress.scannedAssetCount)
            / Double(progress.totalAssetCount)
    }
}

/// 分段条。高 8、圆角 4、段间隙 3，全部取 `S0HomeMetrics`。
struct S0SegmentBarView: View {
    let model: S0SegmentBarModel

    var body: some View {
        GeometryReader { geometry in
            let spacingTotal = S0HomeMetrics.segmentBarItemSpacing
                * CGFloat(max(0, model.segments.count - 1))
            let usable = max(0, geometry.size.width - spacingTotal)
            HStack(spacing: S0HomeMetrics.segmentBarItemSpacing) {
                ForEach(
                    Array(model.segments.enumerated()),
                    id: \.offset
                ) { item in
                    segment(item.element, usableWidth: usable)
                }
            }
        }
        .frame(height: S0HomeMetrics.segmentBarHeight)
        .accessibilityHidden(true)
    }

    private func segment(
        _ segment: S0SegmentBarModel.Segment,
        usableWidth: CGFloat
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: S0HomeMetrics.segmentBarCornerRadius,
            style: .continuous
        )
        return shape
            .fill(S0SegmentPalette.color(for: segment.kind))
            .overlay {
                // 段内高光：上缘一道白，下缘收到零。
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(
                                S0HomeMetrics.segmentBarInnerHighlightOpacity
                            ),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay(alignment: .leading) {
                hatch(segment, usableWidth: usableWidth)
            }
            .clipShape(shape)
            .frame(width: usableWidth * CGFloat(segment.widthFraction))
    }

    /// 等待清空斜纹：只画在 `等待清空(c) > 0` 的段上，宽度以整条为分母。
    @ViewBuilder
    private func hatch(
        _ segment: S0SegmentBarModel.Segment,
        usableWidth: CGFloat
    ) -> some View {
        if segment.hatchFraction > 0 {
            S0SegmentHatch(color: S0SegmentPalette.color(for: segment.kind))
                .frame(width: usableWidth * CGFloat(segment.hatchFraction))
        }
    }
}

/// 斜纹贴片。角度、纹宽、间隔全部取登记值；**不用任何系统材质**
/// （IC-148 裁定 甲：恒深色，系统材质随 trait 变）。
struct S0SegmentHatch: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let stripe = S0HomeMetrics.segmentHatchStripeWidth
            let step = stripe + S0HomeMetrics.segmentHatchGapWidth
            let span = size.width + size.height
            context.clip(to: Path(CGRect(origin: .zero, size: size)))
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(
                by: .degrees(S0HomeMetrics.segmentHatchAngleDegrees)
            )
            var offset = -span
            while offset < span {
                context.fill(
                    Path(
                        CGRect(
                            x: offset,
                            y: -span,
                            width: stripe,
                            height: span * 2
                        )
                    ),
                    with: .color(color)
                )
                offset += step
            }
        }
        .accessibilityHidden(true)
    }
}

/// 段色。类别段取类别登记色；其余照片与未扫描取中性白 + 各自登记不透明度。
enum S0SegmentPalette {
    static func color(for kind: S0SegmentBarModel.Kind) -> Color {
        switch kind {
        case let .category(identifier):
            return S0HomeMetrics.categoryColor(for: identifier)
        case .rest:
            return Color.white.opacity(S0HomeMetrics.segmentRestOpacity)
        case .unscanned:
            return Color.white.opacity(S0HomeMetrics.segmentUnscannedOpacity)
        }
    }
}

/// 图例。各类别名与字节数 + 「其余照片」；扫描中末项为「未扫描」。
struct S0SegmentLegendView: View {
    let model: S0SegmentBarModel

    var body: some View {
        S0LegendFlowLayout(
            horizontalSpacing: S0HomeMetrics.legendItemSpacingH,
            verticalSpacing: S0HomeMetrics.legendItemSpacingV
        ) {
            ForEach(Array(model.segments.enumerated()), id: \.offset) { item in
                legendItem(item.element)
            }
        }
    }

    /// 一项 = 色点 + 名 + 字节数。**不拼分隔符**——分隔用间距表达，
    /// 避免自造一个第十四节第 3 部分没登记的格式串。
    ///
    /// 项内两处间隙取 `legendItemSpacingV`：登记表只给了项**间**横向间隙
    /// （`legendItemSpacingH`）与行间纵向间隙（`legendItemSpacingV`），
    /// **没有项内间隙**；取同族里唯一的小间隙，已在 IC-148 自验报告登记为
    /// 登记表缺口。
    private func legendItem(
        _ segment: S0SegmentBarModel.Segment
    ) -> some View {
        HStack(spacing: S0HomeMetrics.legendItemSpacingV) {
            RoundedRectangle(
                cornerRadius: S0HomeMetrics.legendDotCornerRadius,
                style: .continuous
            )
            .fill(S0SegmentPalette.color(for: segment.kind))
            .frame(
                width: S0HomeMetrics.legendDotSide,
                height: S0HomeMetrics.legendDotSide
            )
            Text(S0SegmentLegendText.name(for: segment.kind))
                .font(.system(size: S0HomeMetrics.legendFontSize))
                .foregroundStyle(S0HomePalette.text)
            if let bytes = S0SegmentLegendText.byteCountText(for: segment) {
                Text(bytes)
                    .font(.system(size: S0HomeMetrics.legendFontSize))
                    .foregroundStyle(S0HomePalette.text)
            }
        }
    }
}

/// 图例文案。类别名取 `S0CategoryText`，其余两段取新登记的两个 key。
enum S0SegmentLegendText {
    static func name(for kind: S0SegmentBarModel.Kind) -> String {
        switch kind {
        case let .category(identifier):
            return S0CategoryText.displayName(for: identifier)
        case .rest:
            return L10n.text("s0.home.legend.rest")
        case .unscanned:
            return L10n.text("s0.home.legend.unscanned")
        }
    }

    /// 「未扫描」不带字节数——它表示的是还没扫到的部分，没有可信读数。
    static func byteCountText(
        for segment: S0SegmentBarModel.Segment
    ) -> String? {
        switch segment.kind {
        case .category, .rest:
            return S0ByteCountText.string(forByteCount: segment.byteCount)
        case .unscanned:
            return nil
        }
    }
}

/// 图例的流式布局：一行排不下就换行，横纵间隙取登记值。
struct S0LegendFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layoutRows(subviews: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(into: 0) { total, row in
            total += row.height
        } + verticalSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(
            width: proposal.width ?? width,
            height: height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = layoutRows(
            subviews: subviews,
            maxWidth: proposal.width ?? bounds.width
        )
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(
        subviews: Subviews,
        maxWidth: CGFloat
    ) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = current.indices.isEmpty
                ? size.width
                : size.width + horizontalSpacing
            if !current.indices.isEmpty, current.width + advance > maxWidth {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width += advance
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
