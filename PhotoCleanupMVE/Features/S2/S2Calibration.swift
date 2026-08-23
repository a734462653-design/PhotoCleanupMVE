import Combine
import CoreGraphics
import Foundation
import Security

/// IC-074：规格状态。`decided` 为 SPEC-S2 v15 第十一节第 1、2 部分承认的定案参数；
/// `placeholder` 为登记占位，非定案，其去留由后续任务卡按 v15 对应条款处理。
enum S2CalibrationParameterSpecStatus: Equatable {
    case decided
    case placeholder

    var title: String {
        switch self {
        case .decided:
            return L10n.text("s2.calibration.spec.decided")
        case .placeholder:
            return L10n.text("s2.calibration.spec.placeholder")
        }
    }
}

enum S2CalibrationParameterConnectionStatus: Equatable {
    case effective
    case unwired

    var title: String {
        switch self {
        case .effective:
            return L10n.text("s2.calibration.connection.effective")
        case .unwired:
            return L10n.text("s2.calibration.connection.unwired")
        }
    }
}

struct S2CalibrationParameterConnection: Identifiable, Equatable {
    let name: String
    let specStatus: S2CalibrationParameterSpecStatus
    let wiringStatus: S2CalibrationParameterConnectionStatus

    var id: String { name }
}

/// IC-078（v15 回写决策 26、第十一节第 1 部分）：`pinchMaxScale` 按当前资产像素尺寸动态取值。
/// 令 `F` 为资产在 `s > 1` 几何基准（全视口 aspectFit）下的显示尺寸（pt），
/// `s_1to1 = 像素宽 ÷ (F.width × displayScale)`，结果钳在 `[floor, ceiling]`；
/// 像素尺寸未解析（任一维 ≤ 0）、基准尺寸为零或倍率非法时取 `floor`。
enum S2PinchMaxScaleRule {
    static func pinchMaxScale(
        assetPixelSize: CGSize,
        fitSize: CGSize,
        displayScale: CGFloat,
        floor: CGFloat,
        ceiling: CGFloat
    ) -> CGFloat {
        let floorValue = max(1, floor)
        let ceilingValue = max(floorValue, ceiling)
        guard assetPixelSize.width > 0,
              assetPixelSize.height > 0,
              fitSize.width > 0,
              fitSize.height > 0,
              displayScale > 0 else {
            return floorValue
        }
        let oneToOne = assetPixelSize.width / (fitSize.width * displayScale)
        guard oneToOne.isFinite else {
            return floorValue
        }
        return min(ceilingValue, max(floorValue, oneToOne))
    }

    /// 全视口 aspectFit 显示尺寸（pt）。
    static func aspectFitSize(
        assetPixelSize: CGSize,
        in viewportSize: CGSize
    ) -> CGSize {
        guard assetPixelSize.width > 0,
              assetPixelSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return .zero
        }
        let ratio = min(
            viewportSize.width / assetPixelSize.width,
            viewportSize.height / assetPixelSize.height
        )
        return CGSize(
            width: assetPixelSize.width * ratio,
            height: assetPixelSize.height * ratio
        )
    }
}

extension S2ResolvedParameters {
    /// IC-078：按资产像素尺寸与 `s > 1` 几何基准求该资产的最大倍率。
    func pinchMaxScale(
        assetPixelSize: CGSize,
        fitSize: CGSize,
        displayScale: CGFloat
    ) -> CGFloat {
        S2PinchMaxScaleRule.pinchMaxScale(
            assetPixelSize: assetPixelSize,
            fitSize: fitSize,
            displayScale: displayScale,
            floor: pinchMaxScaleFloor,
            ceiling: pinchMaxScaleCeiling
        )
    }
}

struct S2CalibrationConfiguration: Codable, Equatable {
    static let schemaVersion = 2

    var pinchMaxScaleFloor: Double
    var pinchMaxScaleCeiling: Double
    var zoomSnapBackThreshold: Double
    var minDoubleTapScale: Double
    var doubleTapAnchorStrategy: S2DoubleTapAnchorStrategy
    var edgePagingTriggerDistance: Double
    var edgePagingTriggerVelocity: Double
    var verticalSwipeDistance: Double
    var verticalSwipeVelocity: Double
    var doubleTapDecisionWindowMilliseconds: Double
    var singleTapTouchCount: Int
    var doubleTapTouchCount: Int
    var singleDragTouchCount: Int
    var pinchTouchCount: Int
    var scaleChangeRequestPolicy: S2ScaleChangeImageRequestPolicy
    var degradedPreviewPolicy: S2DegradedPreviewPolicy
    var animationsEnabled: Bool
    var animationDurationMilliseconds: Double
    var presentationToggleDuration: Double
    var presentationToggleDamping: Double
    var fitInsetRatio: Double
    var fitCornerRadius: Double
    var fitBorderWidth: Double
    var fitBorderDarkAlpha: Double
    var fitBorderLightAlpha: Double
    var pageSpacing: Double
    var hapticOnPhotoSwitch: Bool
    var bottomStripCurrentItemSize: Double
    var bottomStripNeighborItemWidth: Double
    var bottomStripNeighborItemHeight: Double
    var bottomStripItemSpacing: Double
    var bottomStripCurrentItemGap: Double
    var bottomStripEdgeFadeWidth: Double
    var bottomStripLeadingInset: Double
    var bottomStripSwitchDistance: Double
    var bottomStripDecelerationRate: Double
    var bottomStripExpandDurationMilliseconds: Double
    var bottomStripCollapseDurationMilliseconds: Double
    /// IC-085 R3：④技术负责人取定的占位值，松手速度低于此值无惯性（pt/s）。
    var bottomStripFlickVelocityThreshold: Double
    var bottomStripMarkSize: Double
    var markPulseDurationMilliseconds: Double
    var feedbackToastDurationMilliseconds: Double

    // IC-064 显隐过渡与描边项目判断默认值；既有数值延续 IC-063。
    static let factoryPlaceholder = S2CalibrationConfiguration(
        pinchMaxScaleFloor: 4,
        pinchMaxScaleCeiling: 10,
        zoomSnapBackThreshold: 1.1,
        minDoubleTapScale: 2,
        doubleTapAnchorStrategy: .touchPoint,
        edgePagingTriggerDistance: 40,
        edgePagingTriggerVelocity: 300,
        verticalSwipeDistance: 40,
        verticalSwipeVelocity: 100,
        doubleTapDecisionWindowMilliseconds: 200,
        singleTapTouchCount: 1,
        doubleTapTouchCount: 1,
        singleDragTouchCount: 1,
        pinchTouchCount: 2,
        scaleChangeRequestPolicy: .pinchEnded,
        degradedPreviewPolicy: .display,
        animationsEnabled: true,
        animationDurationMilliseconds: 180,
        presentationToggleDuration: 220,
        presentationToggleDamping: 0.86,
        fitInsetRatio: 0.30,
        fitCornerRadius: 28,
        fitBorderWidth: 1,
        fitBorderDarkAlpha: 0.09,
        fitBorderLightAlpha: 0.055,
        pageSpacing: 20,
        hapticOnPhotoSwitch: true,
        // IC-085：横栏出厂值 = 系统 Photos 录屏静止段与减速段测量值（decided）。
        bottomStripCurrentItemSize: 30,
        bottomStripNeighborItemWidth: 20,
        bottomStripNeighborItemHeight: 30,
        bottomStripItemSpacing: 3,
        bottomStripCurrentItemGap: 13,
        bottomStripEdgeFadeWidth: 18.7,
        bottomStripLeadingInset: 20.3,
        bottomStripSwitchDistance: 23,
        bottomStripDecelerationRate: 0.998,
        bottomStripExpandDurationMilliseconds: 600,
        bottomStripCollapseDurationMilliseconds: 100,
        bottomStripFlickVelocityThreshold: 300,
        bottomStripMarkSize: 14,
        markPulseDurationMilliseconds: 150,
        feedbackToastDurationMilliseconds: 2000
    )

    var resolvedParameters: S2ResolvedParameters? {
        S2ResolvedParameters(
            pinchMaxScaleFloor: CGFloat(pinchMaxScaleFloor),
            pinchMaxScaleCeiling: CGFloat(pinchMaxScaleCeiling),
            zoomSnapBackThreshold: CGFloat(zoomSnapBackThreshold),
            minDoubleTapScale: CGFloat(minDoubleTapScale),
            doubleTapAnchorStrategy: doubleTapAnchorStrategy,
            edgePagingTriggerDistance: CGFloat(edgePagingTriggerDistance),
            edgePagingTriggerVelocity: CGFloat(edgePagingTriggerVelocity),
            verticalSwipeDistance: CGFloat(verticalSwipeDistance),
            verticalSwipeVelocity: CGFloat(verticalSwipeVelocity),
            bottomStripMetrics: S2BottomStripMetrics(
                currentItemSize: CGFloat(bottomStripCurrentItemSize),
                neighborItemWidth: CGFloat(bottomStripNeighborItemWidth),
                neighborItemHeight: CGFloat(bottomStripNeighborItemHeight),
                itemSpacing: CGFloat(bottomStripItemSpacing),
                currentItemGap: CGFloat(bottomStripCurrentItemGap),
                edgeFadeWidth: CGFloat(bottomStripEdgeFadeWidth),
                leadingInset: CGFloat(bottomStripLeadingInset),
                switchDistance: CGFloat(bottomStripSwitchDistance),
                decelerationRate: CGFloat(bottomStripDecelerationRate),
                expandDurationMilliseconds: CGFloat(
                    bottomStripExpandDurationMilliseconds
                ),
                collapseDurationMilliseconds: CGFloat(
                    bottomStripCollapseDurationMilliseconds
                ),
                flickVelocityThreshold: CGFloat(
                    bottomStripFlickVelocityThreshold
                )
            )
        )
    }

    var imageRequestStrategy: S2ImageRequestStrategy {
        S2ImageRequestStrategy(
            scaleChangePolicy: scaleChangeRequestPolicy,
            degradedPreviewPolicy: degradedPreviewPolicy
        )
    }

    var isValid: Bool {
        resolvedParameters != nil &&
            doubleTapDecisionWindowMilliseconds >= 0 &&
            singleTapTouchCount > 0 &&
            doubleTapTouchCount > 0 &&
            singleDragTouchCount > 0 &&
            pinchTouchCount > 0 &&
            animationDurationMilliseconds >= 0 &&
            presentationToggleDuration >= 0 &&
            presentationToggleDamping >= 0.6 &&
            presentationToggleDamping <= 1 &&
            fitInsetRatio >= 0 && fitInsetRatio < 0.5 &&
            fitCornerRadius >= 0 &&
            fitBorderWidth >= 0 &&
            fitBorderDarkAlpha >= 0 && fitBorderDarkAlpha <= 1 &&
            fitBorderLightAlpha >= 0 && fitBorderLightAlpha <= 1 &&
            pageSpacing >= 0 &&
            bottomStripMarkSize >= 0 &&
            markPulseDurationMilliseconds >= 0 &&
            feedbackToastDurationMilliseconds >= 0
    }

    func exportText() -> String {
        let values: [(String, String)] = [
            ("schemaVersion", String(Self.schemaVersion)),
            ("taskID", "IC-20260821-074-parameter-layer-v15-alignment"),
            ("valueStatus", L10n.text("s2.calibration.value_status")),
            ("specBaseline", "SPEC-S2-20260821_v15"),
            ("pinchMaxScaleFloor", formatted(pinchMaxScaleFloor)),
            ("pinchMaxScaleCeiling", formatted(pinchMaxScaleCeiling)),
            ("zoomSnapBackThreshold", formatted(zoomSnapBackThreshold)),
            ("minDoubleTapScale", formatted(minDoubleTapScale)),
            ("doubleTapAnchorStrategy", doubleTapAnchorStrategy.rawValue),
            ("edgePagingTriggerDistance", formatted(edgePagingTriggerDistance)),
            ("edgePagingTriggerVelocity", formatted(edgePagingTriggerVelocity)),
            ("verticalSwipeDistance", formatted(verticalSwipeDistance)),
            ("verticalSwipeVelocity", formatted(verticalSwipeVelocity)),
            ("doubleTapDecisionWindowMilliseconds", formatted(doubleTapDecisionWindowMilliseconds)),
            ("singleTapTouchCount", String(singleTapTouchCount)),
            ("doubleTapTouchCount", String(doubleTapTouchCount)),
            ("singleDragTouchCount", String(singleDragTouchCount)),
            ("pinchTouchCount", String(pinchTouchCount)),
            ("scaleChangeRequestPolicy", scaleChangeRequestPolicy.rawValue),
            ("degradedPreviewPolicy", degradedPreviewPolicy.rawValue),
            ("animationsEnabled", String(animationsEnabled)),
            ("animationDurationMilliseconds", formatted(animationDurationMilliseconds)),
            ("presentationToggleDuration", formatted(presentationToggleDuration)),
            ("presentationToggleDamping", formatted(presentationToggleDamping)),
            ("fitInsetRatio", formatted(fitInsetRatio)),
            ("fitCornerRadius", formatted(fitCornerRadius)),
            ("fitBorderWidth", formatted(fitBorderWidth)),
            ("fitBorderDarkAlpha", formatted(fitBorderDarkAlpha)),
            ("fitBorderLightAlpha", formatted(fitBorderLightAlpha)),
            ("pageSpacing", formatted(pageSpacing)),
            ("hapticOnPhotoSwitch", String(hapticOnPhotoSwitch)),
            ("bottomStripCurrentItemSize", formatted(bottomStripCurrentItemSize)),
            ("bottomStripNeighborItemWidth", formatted(bottomStripNeighborItemWidth)),
            ("bottomStripNeighborItemHeight", formatted(bottomStripNeighborItemHeight)),
            ("bottomStripItemSpacing", formatted(bottomStripItemSpacing)),
            ("bottomStripCurrentItemGap", formatted(bottomStripCurrentItemGap)),
            ("bottomStripEdgeFadeWidth", formatted(bottomStripEdgeFadeWidth)),
            ("bottomStripLeadingInset", formatted(bottomStripLeadingInset)),
            ("bottomStripSwitchDistance", formatted(bottomStripSwitchDistance)),
            ("bottomStripDecelerationRate", formatted(bottomStripDecelerationRate)),
            ("bottomStripExpandDurationMilliseconds", formatted(bottomStripExpandDurationMilliseconds)),
            ("bottomStripCollapseDurationMilliseconds", formatted(bottomStripCollapseDurationMilliseconds)),
            ("bottomStripFlickVelocityThreshold", formatted(bottomStripFlickVelocityThreshold)),
            ("bottomStripMarkSize", formatted(bottomStripMarkSize)),
            ("markPulseDurationMilliseconds", formatted(markPulseDurationMilliseconds)),
            ("feedbackToastDurationMilliseconds", formatted(feedbackToastDurationMilliseconds))
        ]
        return values.map { "\($0.0)=\($0.1)" }.joined(separator: "\n")
    }

    private func formatted(_ value: Double) -> String {
        String(
            format: "%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}

extension S2CalibrationConfiguration {
    /// IC-074 登记表：规格状态（decided / placeholder）× 接线状态（effective / unwired）。
    /// 本表只登记，不为占位参数补接生产逻辑。
    static let parameterConnections: [S2CalibrationParameterConnection] = [
        .init(name: "pinchMaxScaleFloor", specStatus: .decided, wiringStatus: .effective),
        .init(name: "pinchMaxScaleCeiling", specStatus: .decided, wiringStatus: .effective),
        .init(name: "zoomSnapBackThreshold", specStatus: .decided, wiringStatus: .effective),
        .init(name: "minDoubleTapScale", specStatus: .decided, wiringStatus: .effective),
        .init(name: "doubleTapAnchorStrategy", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "edgePagingTriggerDistance", specStatus: .decided, wiringStatus: .effective),
        .init(name: "edgePagingTriggerVelocity", specStatus: .decided, wiringStatus: .effective),
        .init(name: "verticalSwipeDistance", specStatus: .decided, wiringStatus: .effective),
        .init(name: "verticalSwipeVelocity", specStatus: .decided, wiringStatus: .effective),
        .init(name: "doubleTapDecisionWindowMilliseconds", specStatus: .decided, wiringStatus: .unwired),
        .init(name: "singleTapTouchCount", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "doubleTapTouchCount", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "singleDragTouchCount", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "pinchTouchCount", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "scaleChangeRequestPolicy", specStatus: .decided, wiringStatus: .effective),
        .init(name: "degradedPreviewPolicy", specStatus: .decided, wiringStatus: .effective),
        .init(name: "animationsEnabled", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "animationDurationMilliseconds", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "presentationToggleDuration", specStatus: .decided, wiringStatus: .effective),
        .init(name: "presentationToggleDamping", specStatus: .decided, wiringStatus: .effective),
        .init(name: "fitInsetRatio", specStatus: .decided, wiringStatus: .effective),
        .init(name: "fitCornerRadius", specStatus: .decided, wiringStatus: .effective),
        .init(name: "fitBorderWidth", specStatus: .decided, wiringStatus: .effective),
        .init(name: "fitBorderDarkAlpha", specStatus: .decided, wiringStatus: .effective),
        .init(name: "fitBorderLightAlpha", specStatus: .decided, wiringStatus: .effective),
        .init(name: "pageSpacing", specStatus: .decided, wiringStatus: .effective),
        .init(name: "hapticOnPhotoSwitch", specStatus: .decided, wiringStatus: .effective),
        // IC-085：横栏参数全部 decided（系统录屏测量）且 effective；
        // bottomStripDragMinimumDistance 已废止。
        .init(name: "bottomStripCurrentItemSize", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripNeighborItemWidth", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripNeighborItemHeight", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripItemSpacing", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripCurrentItemGap", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripEdgeFadeWidth", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripLeadingInset", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripSwitchDistance", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripDecelerationRate", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripExpandDurationMilliseconds", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripCollapseDurationMilliseconds", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripFlickVelocityThreshold", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "bottomStripMarkSize", specStatus: .decided, wiringStatus: .effective),
        .init(name: "markPulseDurationMilliseconds", specStatus: .decided, wiringStatus: .effective),
        .init(name: "feedbackToastDurationMilliseconds", specStatus: .decided, wiringStatus: .effective)
    ]
}

extension S2CalibrationConfiguration {
    private enum CodingKeys: String, CodingKey {
        case pinchMaxScaleFloor
        case pinchMaxScaleCeiling
        case zoomSnapBackThreshold
        case minDoubleTapScale
        case doubleTapAnchorStrategy
        case edgePagingTriggerDistance
        case edgePagingTriggerVelocity
        case verticalSwipeDistance
        case verticalSwipeVelocity
        case doubleTapDecisionWindowMilliseconds
        case singleTapTouchCount
        case doubleTapTouchCount
        case singleDragTouchCount
        case pinchTouchCount
        case scaleChangeRequestPolicy
        case degradedPreviewPolicy
        case animationsEnabled
        case animationDurationMilliseconds
        case presentationToggleDuration
        case presentationToggleDamping
        case fitInsetRatio
        case fitCornerRadius
        case fitBorderWidth
        case fitBorderDarkAlpha
        case fitBorderLightAlpha
        case pageSpacing
        case hapticOnPhotoSwitch
        case bottomStripCurrentItemSize
        case bottomStripNeighborItemWidth
        case bottomStripNeighborItemHeight
        case bottomStripItemSpacing
        case bottomStripCurrentItemGap
        case bottomStripEdgeFadeWidth
        case bottomStripLeadingInset
        case bottomStripSwitchDistance
        case bottomStripDecelerationRate
        case bottomStripExpandDurationMilliseconds
        case bottomStripCollapseDurationMilliseconds
        case bottomStripFlickVelocityThreshold
        case bottomStripMarkSize
        case markPulseDurationMilliseconds
        case feedbackToastDurationMilliseconds
    }

    // 旧版持久化数据没有本卡新增字段；其余字段仍按原契约严格解码。
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pinchMaxScaleFloor: try values.decodeIfPresent(Double.self, forKey: .pinchMaxScaleFloor) ?? 4,
            pinchMaxScaleCeiling: try values.decodeIfPresent(Double.self, forKey: .pinchMaxScaleCeiling) ?? 10,
            zoomSnapBackThreshold: try values.decode(Double.self, forKey: .zoomSnapBackThreshold),
            minDoubleTapScale: try values.decode(Double.self, forKey: .minDoubleTapScale),
            doubleTapAnchorStrategy: try values.decode(S2DoubleTapAnchorStrategy.self, forKey: .doubleTapAnchorStrategy),
            edgePagingTriggerDistance: try values.decode(Double.self, forKey: .edgePagingTriggerDistance),
            edgePagingTriggerVelocity: try values.decode(Double.self, forKey: .edgePagingTriggerVelocity),
            verticalSwipeDistance: try values.decode(Double.self, forKey: .verticalSwipeDistance),
            verticalSwipeVelocity: try values.decode(Double.self, forKey: .verticalSwipeVelocity),
            doubleTapDecisionWindowMilliseconds: try values.decode(Double.self, forKey: .doubleTapDecisionWindowMilliseconds),
            singleTapTouchCount: try values.decode(Int.self, forKey: .singleTapTouchCount),
            doubleTapTouchCount: try values.decode(Int.self, forKey: .doubleTapTouchCount),
            singleDragTouchCount: try values.decode(Int.self, forKey: .singleDragTouchCount),
            pinchTouchCount: try values.decode(Int.self, forKey: .pinchTouchCount),
            scaleChangeRequestPolicy: try values.decode(S2ScaleChangeImageRequestPolicy.self, forKey: .scaleChangeRequestPolicy),
            degradedPreviewPolicy: try values.decode(S2DegradedPreviewPolicy.self, forKey: .degradedPreviewPolicy),
            animationsEnabled: try values.decode(Bool.self, forKey: .animationsEnabled),
            animationDurationMilliseconds: try values.decode(Double.self, forKey: .animationDurationMilliseconds),
            presentationToggleDuration: try values.decodeIfPresent(Double.self, forKey: .presentationToggleDuration) ?? 220,
            presentationToggleDamping: try values.decodeIfPresent(Double.self, forKey: .presentationToggleDamping) ?? 0.86,
            fitInsetRatio: try values.decode(Double.self, forKey: .fitInsetRatio),
            fitCornerRadius: try values.decodeIfPresent(Double.self, forKey: .fitCornerRadius) ?? 28,
            fitBorderWidth: try values.decodeIfPresent(Double.self, forKey: .fitBorderWidth) ?? 1,
            fitBorderDarkAlpha: try values.decodeIfPresent(Double.self, forKey: .fitBorderDarkAlpha) ?? 0.09,
            fitBorderLightAlpha: try values.decodeIfPresent(Double.self, forKey: .fitBorderLightAlpha) ?? 0.055,
            pageSpacing: try values.decodeIfPresent(Double.self, forKey: .pageSpacing) ?? 20,
            hapticOnPhotoSwitch: try values.decodeIfPresent(Bool.self, forKey: .hapticOnPhotoSwitch) ?? true,
            bottomStripCurrentItemSize: try values.decode(Double.self, forKey: .bottomStripCurrentItemSize),
            bottomStripNeighborItemWidth: try values.decode(Double.self, forKey: .bottomStripNeighborItemWidth),
            bottomStripNeighborItemHeight: try values.decode(Double.self, forKey: .bottomStripNeighborItemHeight),
            bottomStripItemSpacing: try values.decode(Double.self, forKey: .bottomStripItemSpacing),
            bottomStripCurrentItemGap: try values.decodeIfPresent(Double.self, forKey: .bottomStripCurrentItemGap) ?? 13,
            bottomStripEdgeFadeWidth: try values.decode(Double.self, forKey: .bottomStripEdgeFadeWidth),
            bottomStripLeadingInset: try values.decodeIfPresent(Double.self, forKey: .bottomStripLeadingInset) ?? 20.3,
            bottomStripSwitchDistance: try values.decode(Double.self, forKey: .bottomStripSwitchDistance),
            bottomStripDecelerationRate: try values.decodeIfPresent(Double.self, forKey: .bottomStripDecelerationRate) ?? 0.998,
            bottomStripExpandDurationMilliseconds: try values.decodeIfPresent(Double.self, forKey: .bottomStripExpandDurationMilliseconds) ?? 600,
            bottomStripCollapseDurationMilliseconds: try values.decodeIfPresent(Double.self, forKey: .bottomStripCollapseDurationMilliseconds) ?? 100,
            bottomStripFlickVelocityThreshold: try values.decodeIfPresent(Double.self, forKey: .bottomStripFlickVelocityThreshold) ?? 300,
            bottomStripMarkSize: try values.decodeIfPresent(Double.self, forKey: .bottomStripMarkSize) ?? 14,
            markPulseDurationMilliseconds: try values.decodeIfPresent(Double.self, forKey: .markPulseDurationMilliseconds) ?? 150,
            feedbackToastDurationMilliseconds: try values.decodeIfPresent(Double.self, forKey: .feedbackToastDurationMilliseconds) ?? 2000
        )
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(pinchMaxScaleFloor, forKey: .pinchMaxScaleFloor)
        try values.encode(pinchMaxScaleCeiling, forKey: .pinchMaxScaleCeiling)
        try values.encode(zoomSnapBackThreshold, forKey: .zoomSnapBackThreshold)
        try values.encode(minDoubleTapScale, forKey: .minDoubleTapScale)
        try values.encode(doubleTapAnchorStrategy, forKey: .doubleTapAnchorStrategy)
        try values.encode(edgePagingTriggerDistance, forKey: .edgePagingTriggerDistance)
        try values.encode(edgePagingTriggerVelocity, forKey: .edgePagingTriggerVelocity)
        try values.encode(verticalSwipeDistance, forKey: .verticalSwipeDistance)
        try values.encode(verticalSwipeVelocity, forKey: .verticalSwipeVelocity)
        try values.encode(doubleTapDecisionWindowMilliseconds, forKey: .doubleTapDecisionWindowMilliseconds)
        try values.encode(singleTapTouchCount, forKey: .singleTapTouchCount)
        try values.encode(doubleTapTouchCount, forKey: .doubleTapTouchCount)
        try values.encode(singleDragTouchCount, forKey: .singleDragTouchCount)
        try values.encode(pinchTouchCount, forKey: .pinchTouchCount)
        try values.encode(scaleChangeRequestPolicy, forKey: .scaleChangeRequestPolicy)
        try values.encode(degradedPreviewPolicy, forKey: .degradedPreviewPolicy)
        try values.encode(animationsEnabled, forKey: .animationsEnabled)
        try values.encode(animationDurationMilliseconds, forKey: .animationDurationMilliseconds)
        try values.encode(presentationToggleDuration, forKey: .presentationToggleDuration)
        try values.encode(presentationToggleDamping, forKey: .presentationToggleDamping)
        try values.encode(fitInsetRatio, forKey: .fitInsetRatio)
        try values.encode(fitCornerRadius, forKey: .fitCornerRadius)
        try values.encode(fitBorderWidth, forKey: .fitBorderWidth)
        try values.encode(fitBorderDarkAlpha, forKey: .fitBorderDarkAlpha)
        try values.encode(fitBorderLightAlpha, forKey: .fitBorderLightAlpha)
        try values.encode(pageSpacing, forKey: .pageSpacing)
        try values.encode(hapticOnPhotoSwitch, forKey: .hapticOnPhotoSwitch)
        try values.encode(bottomStripCurrentItemSize, forKey: .bottomStripCurrentItemSize)
        try values.encode(bottomStripNeighborItemWidth, forKey: .bottomStripNeighborItemWidth)
        try values.encode(bottomStripNeighborItemHeight, forKey: .bottomStripNeighborItemHeight)
        try values.encode(bottomStripItemSpacing, forKey: .bottomStripItemSpacing)
        try values.encode(bottomStripCurrentItemGap, forKey: .bottomStripCurrentItemGap)
        try values.encode(bottomStripEdgeFadeWidth, forKey: .bottomStripEdgeFadeWidth)
        try values.encode(bottomStripLeadingInset, forKey: .bottomStripLeadingInset)
        try values.encode(bottomStripSwitchDistance, forKey: .bottomStripSwitchDistance)
        try values.encode(bottomStripDecelerationRate, forKey: .bottomStripDecelerationRate)
        try values.encode(bottomStripExpandDurationMilliseconds, forKey: .bottomStripExpandDurationMilliseconds)
        try values.encode(bottomStripCollapseDurationMilliseconds, forKey: .bottomStripCollapseDurationMilliseconds)
        try values.encode(bottomStripFlickVelocityThreshold, forKey: .bottomStripFlickVelocityThreshold)
        try values.encode(bottomStripMarkSize, forKey: .bottomStripMarkSize)
        try values.encode(markPulseDurationMilliseconds, forKey: .markPulseDurationMilliseconds)
        try values.encode(feedbackToastDurationMilliseconds, forKey: .feedbackToastDurationMilliseconds)
    }
}

struct S2AnimationPolicy: Equatable {
    let animationsEnabled: Bool
    let durationMilliseconds: Double

    init(
        configuration: S2CalibrationConfiguration,
        durationMilliseconds: Double? = nil
    ) {
        animationsEnabled = configuration.animationsEnabled
        self.durationMilliseconds = durationMilliseconds ??
            configuration.animationDurationMilliseconds
    }

    var shouldAnimate: Bool {
        animationsEnabled && durationMilliseconds > 0
    }

    var durationSeconds: TimeInterval {
        shouldAnimate ? durationMilliseconds / 1_000 : 0
    }
}

struct S2PresentationSpringCurve: Equatable {
    let dampingRatio: Double
    private let naturalFrequency: Double = 8

    init(dampingRatio: Double) {
        self.dampingRatio = dampingRatio
    }

    func value(at normalizedTime: CGFloat) -> CGFloat {
        let time = Double(max(0, normalizedTime))
        if time >= 1 {
            return 1
        }
        if dampingRatio >= 0.999_999 {
            let decay = exp(-naturalFrequency * time)
            return CGFloat(1 - (1 + naturalFrequency * time) * decay)
        }
        let residual = sqrt(max(0.000_001, 1 - dampingRatio * dampingRatio))
        let dampedFrequency = naturalFrequency * residual
        let peakTime = Double.pi / dampedFrequency
        if peakTime < 1, time > peakTime {
            let peakOvershoot = exp(
                -dampingRatio * Double.pi / residual
            )
            let tailProgress = min(
                1,
                max(0, (time - peakTime) / (1 - peakTime))
            )
            let smoothTail = tailProgress * tailProgress *
                (3 - 2 * tailProgress)
            return CGFloat(1 + peakOvershoot * (1 - smoothTail))
        }
        let decay = exp(-dampingRatio * naturalFrequency * time)
        return CGFloat(1 - decay * (
            cos(dampedFrequency * time) +
                dampingRatio / residual * sin(dampedFrequency * time)
        ))
    }
}

struct S2StatusBarAppearance: Equatable {
    let isHidden: Bool
    let transitionDuration: TimeInterval

    init(
        interfaceVisibility: S2InterfaceVisibility,
        configuration: S2CalibrationConfiguration
    ) {
        isHidden = interfaceVisibility == .hidden
        transitionDuration = S2AnimationPolicy(
            configuration: configuration
        ).durationSeconds
    }
}

struct S2TapDecisionReading: Equatable {
    let latencyMilliseconds: Double
    let targetMilliseconds: Double
    let metConfiguredTarget: Bool
}

struct S2TapDecisionDiagnosticPolicy: Equatable {
    let targetMilliseconds: Double

    init(configuration: S2CalibrationConfiguration) {
        targetMilliseconds = max(
            0,
            configuration.doubleTapDecisionWindowMilliseconds
        )
    }

    func reading(latencyMilliseconds: Double) -> S2TapDecisionReading {
        let latency = max(0, latencyMilliseconds)
        return S2TapDecisionReading(
            latencyMilliseconds: latency,
            targetMilliseconds: targetMilliseconds,
            metConfiguredTarget: latency <= targetMilliseconds
        )
    }
}

protocol S2CalibrationPersisting {
    func load() throws -> Data?
    func save(_ data: Data) throws
}

struct S2KeychainCalibrationPersistence: S2CalibrationPersisting {
    private let service = "com.iphonephotomanagement.PhotoCleanupMVE.s2-calibration"
    private let account = "current-parameters"

    func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw S2CalibrationPersistenceError.keychain(status)
        }
        return result as? Data
    }

    func save(_ data: Data) throws {
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw S2CalibrationPersistenceError.keychain(updateStatus)
        }

        var insertion = baseQuery
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let insertionStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard insertionStatus == errSecSuccess else {
            throw S2CalibrationPersistenceError.keychain(insertionStatus)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct S2DiscardingCalibrationPersistence: S2CalibrationPersisting {
    func load() throws -> Data? {
        nil
    }

    func save(_ data: Data) throws {}
}

enum S2CalibrationPersistenceError: Error {
    case keychain(OSStatus)
}

final class S2CalibrationModel: ObservableObject {
    @Published private(set) var configuration: S2CalibrationConfiguration
    @Published private(set) var persistenceFailed = false

    private let persistence: any S2CalibrationPersisting

    init(
        persistence: any S2CalibrationPersisting =
            S2KeychainCalibrationPersistence()
    ) {
        self.persistence = persistence
        if let data = try? persistence.load(),
           let decoded = try? JSONDecoder().decode(
               S2CalibrationConfiguration.self,
               from: data
           ),
           decoded.isValid {
            configuration = decoded
        } else {
            configuration = .factoryPlaceholder
        }
    }

    @discardableResult
    func update(
        _ mutation: (inout S2CalibrationConfiguration) -> Void
    ) -> Bool {
        var next = configuration
        mutation(&next)
        guard next.isValid else {
            return false
        }
        configuration = next
        persist()
        return true
    }

    func restoreFactoryPlaceholder() {
        configuration = .factoryPlaceholder
        persist()
    }

    func exportText() -> String {
        configuration.exportText()
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try persistence.save(encoder.encode(configuration))
            persistenceFailed = false
        } catch {
            persistenceFailed = true
        }
    }
}

struct S2OverlaySafeAreaInsets: Equatable {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat

    static let zero = S2OverlaySafeAreaInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )
}

struct S2CalibrationOverlayState: Equatable {
    var controlsVisible: Bool
    var parameterPanelVisible: Bool
    var readingsVisible: Bool

    static let initial = S2CalibrationOverlayState(
        controlsVisible: false,
        parameterPanelVisible: false,
        readingsVisible: false
    )

    mutating func toggleAccessControls() {
        if controlsVisible {
            self = .initial
        } else {
            controlsVisible = true
        }
    }

    mutating func toggleParameterPanel() {
        guard controlsVisible else {
            return
        }
        parameterPanelVisible.toggle()
        if parameterPanelVisible {
            readingsVisible = false
        }
    }

    mutating func toggleReadings() {
        guard controlsVisible else {
            return
        }
        readingsVisible.toggle()
        if readingsVisible {
            parameterPanelVisible = false
        }
    }
}

struct S2OverlayLayoutSnapshot: Equatable {
    let viewportFrame: CGRect
    let topElementFrames: [CGRect]
    let bottomElementFrames: [CGRect]
    let clickableControlFrames: [CGRect]
    let calibrationEntryFrame: CGRect?
}

enum S2OverlayLayout {
    static let minimumTouchTarget: CGFloat = 44
    static let minimumSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 8
    static let topBarHeight: CGFloat = 48
    static let topLeadingControlWidth: CGFloat = 88
    static let calibrationTopClearance: CGFloat = 108

    static func snapshot(
        physicalSize: CGSize,
        safeAreaInsets: S2OverlaySafeAreaInsets,
        bottomStripHeight: CGFloat,
        showsRecentAlbumAction: Bool,
        calibrationState: S2CalibrationOverlayState
    ) -> S2OverlayLayoutSnapshot {
        let viewportFrame = CGRect(origin: .zero, size: physicalSize)
        let safeFrame = CGRect(
            x: safeAreaInsets.leading,
            y: safeAreaInsets.top,
            width: max(
                0,
                physicalSize.width - safeAreaInsets.leading -
                    safeAreaInsets.trailing
            ),
            height: max(
                0,
                physicalSize.height - safeAreaInsets.top -
                    safeAreaInsets.bottom
            )
        )
        let topBounds = CGRect(
            x: safeFrame.minX,
            y: safeFrame.minY,
            width: safeFrame.width,
            height: topBarHeight
        )
        let topFrames = topElementFrames(in: topBounds)

        let stripHeight = max(minimumTouchTarget, bottomStripHeight)
        let stripFrame = CGRect(
            x: safeFrame.minX,
            y: safeFrame.maxY - stripHeight,
            width: safeFrame.width,
            height: stripHeight
        )
        let actionCount = showsRecentAlbumAction ? 3 : 2
        let actionContentWidth = max(
            0,
            safeFrame.width - 2 * horizontalPadding
        )
        let actionWidth = max(
            minimumTouchTarget,
            (actionContentWidth -
                CGFloat(actionCount - 1) * minimumSpacing) /
                CGFloat(actionCount)
        )
        let actionY = stripFrame.minY - minimumSpacing - minimumTouchTarget
        let actionFrames = (0..<actionCount).map { index in
            CGRect(
                x: safeFrame.minX + horizontalPadding +
                    CGFloat(index) * (actionWidth + minimumSpacing),
                y: actionY,
                width: actionWidth,
                height: minimumTouchTarget
            )
        }
        let bottomFrames = actionFrames + [stripFrame]

        var clickableFrames = [topFrames[0], topFrames[2]] +
            actionFrames + [stripFrame]
        if calibrationState.controlsVisible {
            let secondX = safeFrame.maxX - horizontalPadding -
                minimumTouchTarget
            let firstX = secondX - minimumSpacing - minimumTouchTarget
            let controlY = safeFrame.minY + calibrationTopClearance
            clickableFrames.append(contentsOf: [
                CGRect(
                    x: firstX,
                    y: controlY,
                    width: minimumTouchTarget,
                    height: minimumTouchTarget
                ),
                CGRect(
                    x: secondX,
                    y: controlY,
                    width: minimumTouchTarget,
                    height: minimumTouchTarget
                )
            ])
        }

        return S2OverlayLayoutSnapshot(
            viewportFrame: viewportFrame,
            topElementFrames: topFrames,
            bottomElementFrames: bottomFrames,
            clickableControlFrames: clickableFrames,
            calibrationEntryFrame: nil
        )
    }

    /// IC-075（v15 回写决策 30）：顶部信息区只有三件——返回、序号、确认页入口。
    /// 返回占左侧 `topLeadingControlWidth`，确认页入口占右侧同宽，序号居中占剩余
    /// 宽度；三者高度均为 `topBarHeight`。返回值顺序：[返回, 序号, 确认页入口]。
    static func topElementFrames(in bounds: CGRect) -> [CGRect] {
        let leadingFrame = CGRect(
            x: bounds.minX + horizontalPadding,
            y: bounds.minY,
            width: topLeadingControlWidth,
            height: topBarHeight
        )
        let trailingFrame = CGRect(
            x: bounds.maxX - horizontalPadding - topLeadingControlWidth,
            y: bounds.minY,
            width: topLeadingControlWidth,
            height: topBarHeight
        )
        let positionX = leadingFrame.maxX + minimumSpacing
        let positionWidth = max(
            0,
            trailingFrame.minX - minimumSpacing - positionX
        )
        let positionFrame = CGRect(
            x: positionX,
            y: bounds.minY,
            width: positionWidth,
            height: topBarHeight
        )
        return [leadingFrame, positionFrame, trailingFrame]
    }
}

struct S2ViewportPresentationState: Equatable {
    let interfaceVisibility: S2InterfaceVisibility
    let bottomStripState: S2BottomStripState
    let sheetState: S2SheetState
    let calibrationState: S2CalibrationOverlayState

    init(
        interfaceVisibility: S2InterfaceVisibility,
        bottomStripState: S2BottomStripState,
        sheetState: S2SheetState,
        calibrationState: S2CalibrationOverlayState = .initial
    ) {
        self.interfaceVisibility = interfaceVisibility
        self.bottomStripState = bottomStripState
        self.sheetState = sheetState
        self.calibrationState = calibrationState
    }
}

struct S2ViewportMetrics: Equatable {
    let viewportSize: CGSize
    let assetAspectRatio: CGFloat
    let viewportAspectRatio: CGFloat
    let aspectFitSize: CGSize
    let nativeZoomBaseSize: CGSize
    let isFramedPhoto: Bool
    let oneXDisplaySize: CGSize
    let oneXCornerRadius: CGFloat
    let aspectFillMultiplier: CGFloat
    let doubleTapTargetScale: CGFloat
    let bottomStripHeight: CGFloat
}

enum S2ViewportLayout {
    static func metrics(
        physicalSize: CGSize,
        presentationState: S2ViewportPresentationState,
        assetAspectRatio: CGFloat,
        isScreenshot: Bool = false,
        configuration: S2CalibrationConfiguration
    ) -> S2ViewportMetrics {
        let viewportAspectRatio = physicalSize.height > 0
            ? physicalSize.width / physicalSize.height
            : 0
        let fitSize = S2Geometry.aspectFitSize(
            viewportSize: physicalSize,
            assetAspectRatio: assetAspectRatio
        )
        let matchesScreenAspect = S2Geometry.isScreenAspectMatch(
            assetAspectRatio: assetAspectRatio,
            viewportAspectRatio: viewportAspectRatio
        )
        let keepsFrame = isScreenshot &&
            presentationState.interfaceVisibility == .visible
        let insetScale = keepsFrame
            ? max(0, 1 - CGFloat(configuration.fitInsetRatio))
            : 1
        let displaySize = CGSize(
            width: fitSize.width * insetScale,
            height: fitSize.height * insetScale
        )
        let fillMultiplier = S2Geometry.aspectFillMultiplier(
            viewportSize: physicalSize,
            assetAspectRatio: assetAspectRatio
        ) ?? 1
        return S2ViewportMetrics(
            viewportSize: physicalSize,
            assetAspectRatio: assetAspectRatio,
            viewportAspectRatio: viewportAspectRatio,
            aspectFitSize: fitSize,
            nativeZoomBaseSize: isScreenshot ? physicalSize : fitSize,
            isFramedPhoto: isScreenshot,
            oneXDisplaySize: displaySize,
            oneXCornerRadius: keepsFrame
                ? CGFloat(configuration.fitCornerRadius)
                : 0,
            aspectFillMultiplier: fillMultiplier,
            doubleTapTargetScale: matchesScreenAspect
                ? CGFloat(configuration.minDoubleTapScale)
                : fillMultiplier,
            bottomStripHeight: max(
                CGFloat(configuration.bottomStripCurrentItemSize),
                CGFloat(configuration.bottomStripNeighborItemHeight)
            )
        )
    }

}

enum S2AssetAspectCategory: String, CaseIterable, Codable, Equatable {
    case screenAspect
    case portrait
    case landscape
    case square
    case extreme

    func matches(
        assetAspectRatio: CGFloat,
        viewportAspectRatio: CGFloat
    ) -> Bool {
        guard assetAspectRatio > 0, viewportAspectRatio > 0 else {
            return false
        }
        let screenDifference = abs(assetAspectRatio - viewportAspectRatio) /
            viewportAspectRatio
        switch self {
        case .screenAspect:
            return screenDifference <= 0.01
        case .portrait:
            return assetAspectRatio < 1 && screenDifference > 0.01
        case .landscape:
            return assetAspectRatio > 1
        case .square:
            return abs(assetAspectRatio - 1) <= 0.01
        case .extreme:
            return max(assetAspectRatio, 1 / assetAspectRatio) >= 2.5
        }
    }
}

enum S2AssetNavigationResult: Equatable {
    case found(index: Int, assetID: String)
    case empty
}

enum S2AssetAspectNavigator {
    static func next(
        in orderedAssetIDs: [String],
        after currentIndex: Int,
        category: S2AssetAspectCategory,
        viewportAspectRatio: CGFloat,
        assetAspectRatio: (String) -> CGFloat
    ) -> S2AssetNavigationResult {
        guard !orderedAssetIDs.isEmpty,
              orderedAssetIDs.indices.contains(currentIndex) else {
            return .empty
        }
        for distance in 1...orderedAssetIDs.count {
            let index = (currentIndex + distance) % orderedAssetIDs.count
            let assetID = orderedAssetIDs[index]
            if category.matches(
                assetAspectRatio: assetAspectRatio(assetID),
                viewportAspectRatio: viewportAspectRatio
            ) {
                return .found(index: index, assetID: assetID)
            }
        }
        return .empty
    }
}

struct S2GestureReading: Equatable {
    let displacementDistance: CGFloat
    let peakVelocity: CGFloat
    let duration: TimeInterval
}

enum S2ImageRequestTrigger: String, Equatable {
    case initial
    case assetChange
    case viewportChange
    case scaleChange
    case pinchEnded
    case strategyChange
}

enum S2ImageReturnType: String, Equatable {
    case pending
    case degradedPreview
    case finalImage
    case failure
    /// IC-077：翻页等导致的取消，不算失败，不进入失败态。
    case cancelled
    /// IC-077：资产失效（`fetchAssets` 为空），与失败同态呈现。
    case assetUnavailable
}

struct S2ImageRequestReading: Equatable {
    let trigger: S2ImageRequestTrigger
    let returnType: S2ImageReturnType
}

enum S2ImageRequestDecision {
    static func shouldRequest(
        for trigger: S2ImageRequestTrigger,
        strategy: S2ImageRequestStrategy
    ) -> Bool {
        switch trigger {
        case .scaleChange:
            return strategy.scaleChangePolicy == .everyScaleChange
        case .pinchEnded:
            return strategy.scaleChangePolicy == .pinchEnded
        case .initial, .assetChange, .viewportChange, .strategyChange:
            return true
        }
    }

    static func shouldDisplay(
        isDegraded: Bool,
        strategy: S2ImageRequestStrategy
    ) -> Bool {
        !isDegraded || strategy.degradedPreviewPolicy == .display
    }
}
