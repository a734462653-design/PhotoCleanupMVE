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
        ceiling: CGFloat,
        multiplier: CGFloat
    ) -> CGFloat {
        let floorValue = max(1, floor)
        let ceilingValue = max(floorValue, ceiling)
        guard assetPixelSize.width > 0,
              assetPixelSize.height > 0,
              fitSize.width > 0,
              fitSize.height > 0,
              displayScale > 0,
              multiplier > 0 else {
            return floorValue
        }
        // IC-081（Decision_log 第 123 条）：1:1 像素倍率乘以标定乘数后再钳制。
        let oneToOne = multiplier * assetPixelSize.width / (fitSize.width * displayScale)
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
            ceiling: pinchMaxScaleCeiling,
            multiplier: pinchMaxScaleOneToOneMultiplier
        )
    }
}

struct S2CalibrationConfiguration: Codable, Equatable {
    /// IC-087：出厂值版本。持久化数据顶层写入 `schemaVersion`；加载时与本值不等即整套丢弃并删除条目。
    /// **纪律：任何改动 `factoryPlaceholder` 出厂值的卡必须同时递增本值。**
    static let schemaVersion = 6

    var pinchMaxScaleFloor: Double
    var pinchMaxScaleCeiling: Double
    var pinchMaxScaleOneToOneMultiplier: Double
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
    /// IC-090 R1 / R3（v2）：横栏项目圆角半径（pt，decided）。出厂值 = 系统 Photos 录屏
    /// 静止段四角实测半径对齐到 @3x 像素栅格：实测 8.1～8.4 px，取整像素 8 px = 8/3 pt。
    /// 邻居与当前张同值；与项目尺寸无关，展开／收缩全程为常量。
    var bottomStripCornerRadius: Double
    var bottomStripMarkSize: Double
    var markPulseDurationMilliseconds: Double
    var feedbackToastDurationMilliseconds: Double

    // IC-064 显隐过渡与描边项目判断默认值；既有数值延续 IC-063。
    static let factoryPlaceholder = S2CalibrationConfiguration(
        pinchMaxScaleFloor: 4,
        pinchMaxScaleCeiling: 40,
        pinchMaxScaleOneToOneMultiplier: 6,
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
        bottomStripCornerRadius: 8.0 / 3.0,
        bottomStripMarkSize: 14,
        markPulseDurationMilliseconds: 150,
        feedbackToastDurationMilliseconds: 2000
    )

    var resolvedParameters: S2ResolvedParameters? {
        S2ResolvedParameters(
            pinchMaxScaleFloor: CGFloat(pinchMaxScaleFloor),
            pinchMaxScaleCeiling: CGFloat(pinchMaxScaleCeiling),
            pinchMaxScaleOneToOneMultiplier: CGFloat(pinchMaxScaleOneToOneMultiplier),
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
                ),
                cornerRadius: CGFloat(bottomStripCornerRadius)
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
            fitCornerRadius >= 0 &&
            fitBorderWidth >= 0 &&
            fitBorderDarkAlpha >= 0 && fitBorderDarkAlpha <= 1 &&
            fitBorderLightAlpha >= 0 && fitBorderLightAlpha <= 1 &&
            pageSpacing >= 0 &&
            bottomStripCornerRadius >= 0 &&
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
            ("pinchMaxScaleOneToOneMultiplier", formatted(pinchMaxScaleOneToOneMultiplier)),
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
            ("bottomStripCornerRadius", formatted(bottomStripCornerRadius)),
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
        .init(name: "pinchMaxScaleOneToOneMultiplier", specStatus: .placeholder, wiringStatus: .effective),
        .init(name: "zoomSnapBackThreshold", specStatus: .decided, wiringStatus: .effective),
        .init(name: "minDoubleTapScale", specStatus: .decided, wiringStatus: .effective),
        .init(name: "doubleTapAnchorStrategy", specStatus: .placeholder, wiringStatus: .effective),
        // IC-082 R3：Nx 贴边翻页改由 UIKit 嵌套滚动交接，两项阈值不再接线；规格状态保持 decided，去留由 Decision_log 另记。
        .init(name: "edgePagingTriggerDistance", specStatus: .decided, wiringStatus: .unwired),
        .init(name: "edgePagingTriggerVelocity", specStatus: .decided, wiringStatus: .unwired),
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
        // IC-090 R1：圆角半径同为系统录屏测量值。
        .init(name: "bottomStripCornerRadius", specStatus: .decided, wiringStatus: .effective),
        .init(name: "bottomStripMarkSize", specStatus: .decided, wiringStatus: .effective),
        .init(name: "markPulseDurationMilliseconds", specStatus: .decided, wiringStatus: .effective),
        .init(name: "feedbackToastDurationMilliseconds", specStatus: .decided, wiringStatus: .effective)
    ]
}

extension S2CalibrationConfiguration {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case pinchMaxScaleFloor
        case pinchMaxScaleCeiling
        case pinchMaxScaleOneToOneMultiplier
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
        case bottomStripCornerRadius
        case bottomStripMarkSize
        case markPulseDurationMilliseconds
        case feedbackToastDurationMilliseconds
    }

    // IC-087：先做版本门控——存储的 `schemaVersion`（缺失视为 0）不等于代码版本时抛出不匹配错误，
    // 由 `S2CalibrationModel` 整套丢弃并删除条目；相等时按现行逐字段解码（旧字段缺失回退出厂值）。
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        guard storedVersion == Self.schemaVersion else {
            throw S2CalibrationPersistenceError.schemaVersionMismatch(
                stored: storedVersion,
                expected: Self.schemaVersion
            )
        }
        self.init(
            pinchMaxScaleFloor: try values.decodeIfPresent(Double.self, forKey: .pinchMaxScaleFloor) ?? 4,
            pinchMaxScaleCeiling: try values.decodeIfPresent(Double.self, forKey: .pinchMaxScaleCeiling) ?? 40,
            pinchMaxScaleOneToOneMultiplier: try values.decodeIfPresent(Double.self, forKey: .pinchMaxScaleOneToOneMultiplier) ?? 6,
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
            bottomStripCornerRadius: try values.decodeIfPresent(Double.self, forKey: .bottomStripCornerRadius) ?? 8.0 / 3.0,
            bottomStripMarkSize: try values.decodeIfPresent(Double.self, forKey: .bottomStripMarkSize) ?? 14,
            markPulseDurationMilliseconds: try values.decodeIfPresent(Double.self, forKey: .markPulseDurationMilliseconds) ?? 150,
            feedbackToastDurationMilliseconds: try values.decodeIfPresent(Double.self, forKey: .feedbackToastDurationMilliseconds) ?? 2000
        )
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(Self.schemaVersion, forKey: .schemaVersion)
        try values.encode(pinchMaxScaleFloor, forKey: .pinchMaxScaleFloor)
        try values.encode(pinchMaxScaleCeiling, forKey: .pinchMaxScaleCeiling)
        try values.encode(pinchMaxScaleOneToOneMultiplier, forKey: .pinchMaxScaleOneToOneMultiplier)
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
        try values.encode(bottomStripCornerRadius, forKey: .bottomStripCornerRadius)
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
    /// IC-087：删除持久化条目（不是覆盖）。条目不存在视为成功。
    func delete() throws
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

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw S2CalibrationPersistenceError.keychain(status)
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

    func delete() throws {}
}

enum S2CalibrationPersistenceError: Error, Equatable {
    case keychain(OSStatus)
    case schemaVersionMismatch(stored: Int, expected: Int)
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
        guard let data = try? persistence.load() else {
            configuration = .factoryPlaceholder
            return
        }
        do {
            let decoded = try JSONDecoder().decode(
                S2CalibrationConfiguration.self,
                from: data
            )
            configuration = decoded.isValid ? decoded : .factoryPlaceholder
        } catch S2CalibrationPersistenceError.schemaVersionMismatch {
            // IC-087：出厂值版本变化，整套丢弃并删除条目，避免旧值永久覆盖新出厂值。
            configuration = .factoryPlaceholder
            do {
                try persistence.delete()
                persistenceFailed = false
            } catch {
                persistenceFailed = true
            }
        } catch {
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

    /// IC-087：恢复出厂值——重置为 `factoryPlaceholder` 并删除持久化条目（不是覆盖写入）。
    func restoreFactoryPlaceholder() {
        configuration = .factoryPlaceholder
        do {
            try persistence.delete()
            persistenceFailed = false
        } catch {
            persistenceFailed = true
        }
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

    // MARK: - IC-100 v2 R1/R2：底部竖向排布（自下而上 安全区 → 操作条 → 横栏）
    //
    // 以下三个是**登记制占位常量**（视觉稿前 ④ 可修订）：按 v16 回写决策 33 与
    // 技术负责人 2026-08-28 系统录屏实测表落值，**不进 `S2CalibrationConfiguration`、
    // 不上参数面板、`schemaVersion` 不动**（同 IC-091 `edgeTolerance` 先例）。

    /// 操作条**可见图标带**高。现行按钮是 `Label(标题, systemImage:)`、字体走 `.body`，
    /// 可见带高由该文本样式的行高决定；默认动态字体（Large）下
    /// `UIFont.preferredFont(forTextStyle: .body).lineHeight == 22`。
    /// 本文件不引入 UIKit，故取该值为常量；真机观感由 H44 判。
    /// 注意与系统工具条的纯图标带 24.3 pt 不同——我们的按钮是图标 + 文字。
    static let actionBarVisibleBandHeight: CGFloat = 22

    /// 横栏底缘 → 操作条**可见图标带**顶缘的间距（系统实测 92 px @3x）。
    static let stripToActionVisibleBandSpacing: CGFloat = 30.7

    /// 反馈 toast 底缘 → 底部横栏顶缘的间距（IC-100 v2 R2）。
    static let toastToStripSpacing: CGFloat = 8

    /// 操作条 **44 pt 触控带**中心距视口底。
    ///
    /// IC-100 v1 实测①：把系统的「可见图标带中心距屏底 52.7 pt」直接套到我们的
    /// 44 pt 触控带上，会让触控带 `maxY` 越过安全区 3.3 pt，与既有门禁 L2 冲突。
    /// v2 定案（④）改锚安全区：中心 = 安全区底 + 半个触控带（常规机型 34 + 22 = 56.0），
    /// L2 与 L4 同时满足，且安全区变化时自适应。与系统的 3.3 pt 观感差为有意为之。
    static func actionBandCenterFromViewportBottom(
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        max(0, safeAreaBottom) + minimumTouchTarget / 2
    }

    /// 操作条触控带顶缘距视口底（常规机型 78.0）。
    static func actionBandTopFromViewportBottom(
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        actionBandCenterFromViewportBottom(safeAreaBottom: safeAreaBottom) +
            minimumTouchTarget / 2
    }

    /// 操作条触控带底缘距视口底（= 安全区底，即「避让安全区贴近底缘」）。
    static func actionBandBottomFromViewportBottom(
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        actionBandCenterFromViewportBottom(safeAreaBottom: safeAreaBottom) -
            minimumTouchTarget / 2
    }

    /// 操作条**可见图标带**顶缘距视口底（常规机型 56.0 + 11 = 67.0）。
    static func actionVisibleBandTopFromViewportBottom(
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        actionBandCenterFromViewportBottom(safeAreaBottom: safeAreaBottom) +
            actionBarVisibleBandHeight / 2
    }

    /// 横栏底缘距视口底 = 可见图标带顶缘 + 30.7（常规机型 67.0 + 30.7 = 97.7）。
    static func stripBottomFromViewportBottom(
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        actionVisibleBandTopFromViewportBottom(safeAreaBottom: safeAreaBottom) +
            stripToActionVisibleBandSpacing
    }

    /// 横栏顶缘距视口底 = 横栏底缘 + 横栏带高。
    static func stripTopFromViewportBottom(
        safeAreaBottom: CGFloat,
        bottomStripHeight: CGFloat
    ) -> CGFloat {
        stripBottomFromViewportBottom(safeAreaBottom: safeAreaBottom) +
            resolvedStripHeight(bottomStripHeight)
    }

    /// 反馈 toast 底缘距视口底 = 横栏顶缘 + 8（IC-100 v2 R2）。
    static func toastBottomFromViewportBottom(
        safeAreaBottom: CGFloat,
        bottomStripHeight: CGFloat
    ) -> CGFloat {
        stripTopFromViewportBottom(
            safeAreaBottom: safeAreaBottom,
            bottomStripHeight: bottomStripHeight
        ) + toastToStripSpacing
    }

    /// 横栏带高不小于最小触控边长——既有语义，抽出来供推导式与快照共用。
    static func resolvedStripHeight(_ bottomStripHeight: CGFloat) -> CGFloat {
        max(minimumTouchTarget, bottomStripHeight)
    }

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

        // IC-100 v2 R1：自下而上 安全区 → 操作条 → 横栏。两者不再套在同一个竖直
        // 堆叠里，而是各自按上文推导式独立锚定**视口**底缘；渲染侧
        // （`S2View.interfaceOverlay`）调用的是同一组推导式，两侧不会各算各的。
        let stripHeight = resolvedStripHeight(bottomStripHeight)
        let stripFrame = CGRect(
            x: safeFrame.minX,
            y: physicalSize.height - stripBottomFromViewportBottom(
                safeAreaBottom: safeAreaInsets.bottom
            ) - stripHeight,
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
        let actionY = physicalSize.height - actionBandTopFromViewportBottom(
            safeAreaBottom: safeAreaInsets.bottom
        )
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
    /// IC-104 C v3：`s = 1` 显示帧的**竖直中心**（视口坐标）。
    /// 截图且 `V=显示` 时为适配带中心；其余一切情形为视口中心（与改前一致）。
    let oneXDisplayCenterY: CGFloat
    let oneXCornerRadius: CGFloat
    let aspectFillMultiplier: CGFloat
    let doubleTapTargetScale: CGFloat
    let bottomStripHeight: CGFloat
}

enum S2ViewportLayout {
    /// IC-104 C（④ 2026-08-29，待入 Decision_log 第 134 条）：截图内缩改锚上下
    /// chrome，三段间距相等，等距值 = `S2OverlayLayout.stripToActionVisibleBandSpacing`
    /// （30.7 pt）。`safeAreaInsets` 是为此新增的输入，默认 `.zero`——既有调用点
    /// 语义不变，只有需要真实 chrome 几何的调用方才传。
    static func metrics(
        physicalSize: CGSize,
        presentationState: S2ViewportPresentationState,
        assetAspectRatio: CGFloat,
        isScreenshot: Bool = false,
        configuration: S2CalibrationConfiguration,
        safeAreaInsets: S2OverlaySafeAreaInsets = .zero
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
        let stripHeight = max(
            CGFloat(configuration.bottomStripCurrentItemSize),
            CGFloat(configuration.bottomStripNeighborItemHeight)
        )
        // IC-104 C v3：截图适配带**仅限 V=显示**。隐藏态仍按规格 v16 第 121/177
        // 行填满视口（截图沉浸，行为恒开），故 `keepsFrame` 与尺寸、摆放、圆角
        // 三者的门控条件完全一致。
        // 带顶缘 = 0.15 × 视口高（还原 v15 顶缘位置）；带底缘 = 横栏顶缘 − g。
        // 水平方向仍走等比适配与居中：把带高连同视口宽交给 `aspectFitSize`。
        let keepsFrame = isScreenshot &&
            presentationState.interfaceVisibility == .visible
        let bandTop = screenshotBandTop(physicalSize: physicalSize)
        let bandHeight = screenshotBandHeight(
            physicalSize: physicalSize,
            safeAreaInsets: safeAreaInsets,
            bottomStripHeight: stripHeight
        )
        let displaySize = keepsFrame
            ? S2Geometry.aspectFitSize(
                viewportSize: CGSize(
                    width: physicalSize.width,
                    height: bandHeight
                ),
                assetAspectRatio: assetAspectRatio
            )
            : fitSize
        // 摆放：显示态截图居中于**带**，其余一切情形居中于视口（与改前一致）。
        let displayCenterY = keepsFrame
            ? bandTop + bandHeight / 2
            : physicalSize.height / 2
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
            oneXDisplayCenterY: displayCenterY,
            // 圆角沿用既有规则（截图且 V=显示），与尺寸同一门控。
            oneXCornerRadius: keepsFrame
                ? CGFloat(configuration.fitCornerRadius)
                : 0,
            aspectFillMultiplier: fillMultiplier,
            doubleTapTargetScale: matchesScreenAspect
                ? CGFloat(configuration.minDoubleTapScale)
                : fillMultiplier,
            bottomStripHeight: stripHeight
        )
    }

    /// IC-104 C v3（④ Lynn，H45 第 5 项返工）：截图显示态适配带的顶缘比例。
    ///
    /// 旧版（v15 比例内缩）显示态截图 = `fitSize × 0.70` 后全视口垂直居中，
    /// 与视口同比例的截图顶缘恒为 `(1 − 0.70) / 2 = 0.15` 倍视口高。本卡以该
    /// 比例还原顶缘位置，各机型一致。**不是可调参数，不进登记表。**
    static let legacyVisibleFitTopRatio: CGFloat = 0.15

    /// 带顶缘（视口坐标）＝ `0.15 × 视口高`。
    static func screenshotBandTop(physicalSize: CGSize) -> CGFloat {
        physicalSize.height * legacyVisibleFitTopRatio
    }

    /// 顶距 `g` ＝ 带顶缘 − 顶部栏底缘（安全区顶 + `topBarHeight`）。纯推导值。
    static func screenshotBandTopSpacing(
        physicalSize: CGSize,
        safeAreaInsets: S2OverlaySafeAreaInsets
    ) -> CGFloat {
        screenshotBandTop(physicalSize: physicalSize) -
            (safeAreaInsets.top + S2OverlayLayout.topBarHeight)
    }

    /// IC-104 C v4：底部横栏的**视觉**顶缘距视口底。
    ///
    /// `S2OverlayLayout.stripTopFromViewportBottom` 内含
    /// `resolvedStripHeight = max(minimumTouchTarget 44, 横栏高)` 的**触控带下限**，
    /// 是给手指的**触控锚**；渲染容器（`S2View` 的
    /// `.frame(height: viewportMetrics.bottomStripHeight)`）用的是**原始横栏高**，
    /// 是给眼睛的**视觉锚**。出厂值下两者差 `44 − 30 = 14` pt。
    /// 截图适配带的底缘要对齐眼睛看到的横栏，故取后者、与渲染同源。
    /// **触控带语义（命中区域、toast 等既有消费方）一律不变。**
    static func stripVisualTopFromViewportBottom(
        safeAreaBottom: CGFloat,
        bottomStripHeight: CGFloat
    ) -> CGFloat {
        S2OverlayLayout.stripBottomFromViewportBottom(
            safeAreaBottom: safeAreaBottom
        ) + bottomStripHeight
    }

    /// IC-104 C v3 / v4：截图适配带的可用带高。
    ///
    /// 带顶缘 = `0.15 × 视口高`（旧位，v3 不变）；带底缘 = 横栏**视觉**顶缘 − `g`
    /// （v4 由触控锚改为视觉锚），即视觉底距 = 顶距。
    /// 「横栏—操作条」间距（`stripToActionVisibleBandSpacing` = 30.7）
    /// **不参与等距**（④ Lynn 明确选定），本卡对 chrome 布局零改动。
    static func screenshotBandHeight(
        physicalSize: CGSize,
        safeAreaInsets: S2OverlaySafeAreaInsets,
        bottomStripHeight: CGFloat
    ) -> CGFloat {
        let bandTop = screenshotBandTop(physicalSize: physicalSize)
        let spacing = screenshotBandTopSpacing(
            physicalSize: physicalSize,
            safeAreaInsets: safeAreaInsets
        )
        let stripTop = physicalSize.height -
            stripVisualTopFromViewportBottom(
                safeAreaBottom: safeAreaInsets.bottom,
                bottomStripHeight: bottomStripHeight
            )
        return max(0, (stripTop - spacing) - bandTop)
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
