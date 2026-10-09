import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-196：S2 教学引导 D 的界面层（SPEC-S2 v24 第二节第 6 部分 K1～K8、第十一节第 2 部分「教学引导 D 登记」；
/// 拆卡与取定 `Tasks/PLAN-S2D-guide-rulings-20261009.md` 第五节）。本卡只加视图、登记值与目录，**不接线**。
/// 1 登记值：「教学引导 D 登记」逐值、推导量、七个符号（CI 宿主 `UIImage(systemName:)` 非空）。
/// 2 几何与运动：教练卡与完成卡落位、确认入口中心与虚线、压暗框、手势示范落位（不压教练卡）与循环运动；
///   打印 393×852、375×667 两档下示范与中央状态指示的叠放几何（未定项 38，只打印、不判）。
/// 3 目录：新增十一条 `s2.guide.*` 与步骤的文案、符号映射。
/// 4 离屏尺寸：教练卡高 108、宽不越出卡宽，完成卡高 72；四步标题与副句在 375、393 两档卡宽下放得下（打印余量，未定项 37）；
///   两只层视图与压暗可构造、不越出提议（弹性框是否恰好吃满提议不判，打印 `IC196_LAYER`）。
/// 5 源码落位：新文件纪律、计数与「登记名都被引用」。
///
/// **夹具驱动**：只验口径、几何与源码；观感、动画、层级与命中归接线卡的真机判定。
final class IC196GuideDViewsTests: XCTestCase {
    private static let viewsPath = "PhotoCleanupMVE/Features/S2/S2GuideDViews.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let newKeyValues: [(String, String)] = [
        ("s2.guide.swipe_up", "上滑，放进待删篮"),
        ("s2.guide.swipe_up.sub", "不会删除照片。攒好了再一起确认。"),
        ("s2.guide.marked", "已放进待删篮"),
        ("s2.guide.marked.sub", "标错了？下滑放回来。"),
        ("s2.guide.undone", "已撤回，照片回来了"),
        ("s2.guide.undone.sub", "左右滑翻看，开始整理吧。"),
        ("s2.guide.confirm", "攒了 {count} 张"),
        ("s2.guide.confirm.sub", "点右上角垃圾桶，一起过目再删除。"),
        ("s2.guide.completed", "都学会了"),
        ("s2.guide.skip", "跳过教程"),
        ("s2.guide.progress", "第 {current} 步，共 {total} 步")
    ]
    /// 登记值逐值表（名字 → 期望值）；断言 5 另核表里的名字恰为 `S2GuideDMetrics` 的全部 `static let`。
    private static let metricValues: [(String, Double, Double)] = [
        ("coachTopFromChromeBottom", Double(S2GuideDMetrics.coachTopFromChromeBottom), 62),
        ("coachHorizontalInset", Double(S2GuideDMetrics.coachHorizontalInset), 16),
        ("coachCardHeight", Double(S2GuideDMetrics.coachCardHeight), 108),
        ("coachCornerRadius", Double(S2GuideDMetrics.coachCornerRadius), 28),
        ("coachPaddingTop", Double(S2GuideDMetrics.coachPaddingTop), 14),
        ("coachPaddingTrailing", Double(S2GuideDMetrics.coachPaddingTrailing), 16),
        ("coachPaddingBottom", Double(S2GuideDMetrics.coachPaddingBottom), 14),
        ("coachPaddingLeading", Double(S2GuideDMetrics.coachPaddingLeading), 14),
        ("coachRowSpacing", Double(S2GuideDMetrics.coachRowSpacing), 10),
        ("coachEdgeWidth", Double(S2GuideDMetrics.coachEdgeWidth), 0.5),
        ("coachEdgeHighlightOpacity", S2GuideDMetrics.coachEdgeHighlightOpacity, 0.16),
        ("coachEdgeRingOpacity", S2GuideDMetrics.coachEdgeRingOpacity, 0.10),
        ("coachShadowYOffset", Double(S2GuideDMetrics.coachShadowYOffset), 16),
        ("coachShadowRadius", Double(S2GuideDMetrics.coachShadowRadius), 40),
        ("coachShadowOpacity", S2GuideDMetrics.coachShadowOpacity, 0.55),
        ("stepRowHeight", Double(S2GuideDMetrics.stepRowHeight), 16),
        ("stepDotSide", Double(S2GuideDMetrics.stepDotSide), 6),
        ("stepDotCornerRadius", Double(S2GuideDMetrics.stepDotCornerRadius), 3),
        ("stepDotSpacing", Double(S2GuideDMetrics.stepDotSpacing), 5),
        ("stepDotCurrentWidth", Double(S2GuideDMetrics.stepDotCurrentWidth), 18),
        ("stepDotPendingOpacity", S2GuideDMetrics.stepDotPendingOpacity, 0.28),
        ("stepDotLearnedOpacity", S2GuideDMetrics.stepDotLearnedOpacity, 0.55),
        ("skipButtonHeight", Double(S2GuideDMetrics.skipButtonHeight), 28),
        ("skipFontSize", Double(S2GuideDMetrics.skipFontSize), 13),
        ("skipForegroundOpacity", S2GuideDMetrics.skipForegroundOpacity, 0.62),
        ("skipHorizontalPadding", Double(S2GuideDMetrics.skipHorizontalPadding), 4),
        ("skipTouchTargetSide", Double(S2GuideDMetrics.skipTouchTargetSide), 44),
        ("skipTouchOverhang", Double(S2GuideDMetrics.skipTouchOverhang), 8),
        ("coachGlyphCircleSide", Double(S2GuideDMetrics.coachGlyphCircleSide), 52),
        ("coachGlyphPointSize", Double(S2GuideDMetrics.coachGlyphPointSize), 26),
        ("coachMainRowSpacing", Double(S2GuideDMetrics.coachMainRowSpacing), 14),
        ("coachTitleFontSize", Double(S2GuideDMetrics.coachTitleFontSize), 18),
        ("coachTitleLeadPointSize", Double(S2GuideDMetrics.coachTitleLeadPointSize), 18),
        ("coachTitleLeadSpacing", Double(S2GuideDMetrics.coachTitleLeadSpacing), 6),
        ("coachSubtitleFontSize", Double(S2GuideDMetrics.coachSubtitleFontSize), 13.5),
        ("coachSubtitleLineHeight", Double(S2GuideDMetrics.coachSubtitleLineHeight), 18),
        ("coachSubtitleTopSpacing", Double(S2GuideDMetrics.coachSubtitleTopSpacing), 3),
        ("secondaryTextOpacity", S2GuideDMetrics.secondaryTextOpacity, 0.66),
        ("coachPointerSide", Double(S2GuideDMetrics.coachPointerSide), 14),
        ("coachPointerCornerRadius", Double(S2GuideDMetrics.coachPointerCornerRadius), 3),
        ("coachPointerRotationDegrees", S2GuideDMetrics.coachPointerRotationDegrees, 45),
        ("coachPointerLineWidth", Double(S2GuideDMetrics.coachPointerLineWidth), 2.5),
        ("confirmDashGapFromButton", Double(S2GuideDMetrics.confirmDashGapFromButton), 8),
        ("confirmDashLength", Double(S2GuideDMetrics.confirmDashLength), 48),
        ("confirmDashSegment", Double(S2GuideDMetrics.confirmDashSegment), 6),
        ("confirmDashSpace", Double(S2GuideDMetrics.confirmDashSpace), 4),
        ("confirmHaloInnerWidth", Double(S2GuideDMetrics.confirmHaloInnerWidth), 5),
        ("confirmHaloInnerOpacity", S2GuideDMetrics.confirmHaloInnerOpacity, 0.55),
        ("confirmHaloOuterWidth", Double(S2GuideDMetrics.confirmHaloOuterWidth), 12),
        ("confirmHaloOuterOpacity", S2GuideDMetrics.confirmHaloOuterOpacity, 0.18),
        ("introScrimOpacity", S2GuideDMetrics.introScrimOpacity, 0.42),
        ("gestureDiscSideStep1", Double(S2GuideDMetrics.gestureDiscSideStep1), 72),
        ("gestureDiscSide", Double(S2GuideDMetrics.gestureDiscSide), 60),
        ("gestureDiscFillOpacity", S2GuideDMetrics.gestureDiscFillOpacity, 0.82),
        ("gestureDiscRingWidth", Double(S2GuideDMetrics.gestureDiscRingWidth), 1.5),
        ("gestureDiscRingOpacity", S2GuideDMetrics.gestureDiscRingOpacity, 0.35),
        ("gestureDiscHaloWidth", Double(S2GuideDMetrics.gestureDiscHaloWidth), 10),
        ("gestureDiscHaloOpacity", S2GuideDMetrics.gestureDiscHaloOpacity, 0.28),
        ("gestureDiscShadowYOffset", Double(S2GuideDMetrics.gestureDiscShadowYOffset), 10),
        ("gestureDiscShadowRadius", Double(S2GuideDMetrics.gestureDiscShadowRadius), 30),
        ("gestureDiscShadowOpacity", S2GuideDMetrics.gestureDiscShadowOpacity, 0.50),
        ("gestureHandScale", Double(S2GuideDMetrics.gestureHandScale), 0.5),
        ("gestureArrowCircleSide", Double(S2GuideDMetrics.gestureArrowCircleSide), 34),
        ("gestureArrowShadowYOffset", Double(S2GuideDMetrics.gestureArrowShadowYOffset), 4),
        ("gestureArrowShadowRadius", Double(S2GuideDMetrics.gestureArrowShadowRadius), 14),
        ("gestureArrowShadowOpacity", S2GuideDMetrics.gestureArrowShadowOpacity, 0.45),
        ("gestureDiscArrowPointSize", Double(S2GuideDMetrics.gestureDiscArrowPointSize), 20),
        ("gestureArrowOffset", Double(S2GuideDMetrics.gestureArrowOffset), 40),
        ("gestureArrowOffsetHorizontal", Double(S2GuideDMetrics.gestureArrowOffsetHorizontal), 36),
        ("gestureTrailWidth", Double(S2GuideDMetrics.gestureTrailWidth), 4),
        ("gestureTrailLength", Double(S2GuideDMetrics.gestureTrailLength), 40),
        ("gestureTrailGap", Double(S2GuideDMetrics.gestureTrailGap), 2),
        ("gestureTrailStartOpacity", S2GuideDMetrics.gestureTrailStartOpacity, 0.95),
        ("gestureTrailOutlineWidth", Double(S2GuideDMetrics.gestureTrailOutlineWidth), 1.5),
        ("gestureTrailOutlineOpacity", S2GuideDMetrics.gestureTrailOutlineOpacity, 0.45),
        ("doneTopFromCoachTop", Double(S2GuideDMetrics.doneTopFromCoachTop), 14),
        ("doneCornerRadius", Double(S2GuideDMetrics.doneCornerRadius), 24),
        ("doneHorizontalPadding", Double(S2GuideDMetrics.doneHorizontalPadding), 20),
        ("doneVerticalPadding", Double(S2GuideDMetrics.doneVerticalPadding), 16),
        ("doneSpacing", Double(S2GuideDMetrics.doneSpacing), 12),
        ("doneCheckCircleSide", Double(S2GuideDMetrics.doneCheckCircleSide), 40),
        ("doneCheckPointSize", Double(S2GuideDMetrics.doneCheckPointSize), 24),
        ("doneTitleFontSize", Double(S2GuideDMetrics.doneTitleFontSize), 17),
        ("gestureUnitBottomInset", Double(S2GuideDMetrics.gestureUnitBottomInset), 39),
        ("guideGestureTravel", Double(S2GuideDMetrics.guideGestureTravel), 40),
        ("guideGestureCycleSeconds", S2GuideDMetrics.guideGestureCycleSeconds, 0.9),
        ("guideTransitionSeconds", S2GuideDMetrics.guideTransitionSeconds, 0.2)
    ]
    private static let symbolValues: [(String, String, String)] = [
        ("guideStep1Symbol", S2GuideDSymbol.guideStep1Symbol, "arrow.up"),
        ("guideStep2Symbol", S2GuideDSymbol.guideStep2Symbol, "arrow.down"),
        ("guideStep3Symbol", S2GuideDSymbol.guideStep3Symbol, "arrow.left.and.right"),
        ("guideStep4Symbol", S2GuideDSymbol.guideStep4Symbol, "trash"),
        ("leadCheck", S2GuideDSymbol.leadCheck, "checkmark"),
        ("leadUndo", S2GuideDSymbol.leadUndo, "arrow.uturn.backward"),
        ("guideHand", S2GuideDSymbol.guideHand, "hand.point.up.left")
    ]

    // MARK: - 断言 1：登记值

    func testIC196A_RegistryValuesAndSymbols() {
        for (name, value, expected) in Self.metricValues {
            XCTAssertEqual(value, expected, accuracy: 1e-9, name)
        }
        // 与 D1 协调器共用、不在本族重复登记的两值：第 4 步阈值、完成提示秒数（规格 `guideConfirmThreshold`／`doneAutoDismissSeconds`）。
        XCTAssertEqual(S2GuideCoordinator.confirmThreshold, 5)
        XCTAssertEqual(S2GuideCoordinator.completionAutoDismissSeconds, 2, accuracy: 1e-9)
        for (name, value, expected) in Self.symbolValues {
            XCTAssertEqual(value, expected, name)
            XCTAssertNotNil(UIImage(systemName: value), name)
        }
    }

    // MARK: - 断言 2：几何与运动

    func testIC196B_GeometryAndMotion() {
        let large = CGSize(width: 393, height: 852)
        let small = CGSize(width: 375, height: 667)
        // 教练卡与完成卡：顶排下缘（安全区顶 + 47）+ 62；卡宽 = 视口宽 − 32。
        XCTAssertEqual(S2GuideDLayout.coachTop(safeAreaTop: 59), 168, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.coachBottom(safeAreaTop: 59), 276, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.coachTop(safeAreaTop: 20), 129, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.coachBottom(safeAreaTop: 20), 237, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.coachWidth(viewportWidth: 393), 361, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.coachWidth(viewportWidth: 375), 343, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.doneTop(safeAreaTop: 59), 182, accuracy: 1e-9)
        // 确认入口圆钮中心 = 视口右缘 − 16 − 22、安全区顶 + 3 + 22；小三角中心在其正下方的教练卡上缘；虚线上端 = 圆钮下缘 + 8。
        let center = S2GuideDLayout.confirmEntryCenter(viewportSize: large, safeAreaTop: 59)
        XCTAssertEqual(center.x, 355, accuracy: 1e-9)
        XCTAssertEqual(center.y, 84, accuracy: 1e-9)
        let pointer = S2GuideDLayout.pointerCenter(viewportSize: large, safeAreaTop: 59)
        XCTAssertEqual(pointer.x, 355, accuracy: 1e-9)
        XCTAssertEqual(pointer.y, 168, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.dashTop(viewportSize: large, safeAreaTop: 59), 114, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.haloDiameter(ringWidth: S2GuideDMetrics.confirmHaloOuterWidth), 68, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.haloDiameter(ringWidth: S2GuideDMetrics.confirmHaloInnerWidth), 54, accuracy: 1e-9)
        // 压暗框：顶排下缘到横栏视觉顶缘（视口高 − (安全区底 + 8 + 44 + 24) − 横栏高）。
        let scrim = S2GuideDLayout.introScrimFrame(
            viewportSize: large,
            safeAreaTop: 59,
            safeAreaBottom: 34,
            bottomStripHeight: 30
        )
        XCTAssertEqual(scrim.minX, 0, accuracy: 1e-9)
        XCTAssertEqual(scrim.width, 393, accuracy: 1e-9)
        XCTAssertEqual(scrim.minY, 106, accuracy: 1e-9)
        XCTAssertEqual(scrim.maxY, 712, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.indicatorAvoidanceLineY(photoCenterY: 426), 387, accuracy: 1e-9)
        // 示范的方向、圆径与部件偏移。
        XCTAssertEqual(S2GuideStep.allCases.map { S2GuideDLayout.gestureDirection(for: $0) }, [.up, .down, .leftRight, nil])
        XCTAssertEqual(S2GuideStep.allCases.map { Double(S2GuideDLayout.gestureDiscSide(for: $0)) }, [72, 60, 60, 60])
        XCTAssertEqual(S2GuideDLayout.gestureArrowCenterOffsetY(direction: .up, discSide: 72), -59, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.gestureArrowCenterOffsetY(direction: .down, discSide: 60), 53, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.gestureArrowCenterOffsetY(direction: .leftRight, discSide: 60), -49, accuracy: 1e-9)
        XCTAssertEqual(Double(S2GuideDLayout.gestureTrailCenterOffsetY(direction: .up, discSide: 72) ?? 0), 58, accuracy: 1e-9)
        XCTAssertEqual(Double(S2GuideDLayout.gestureTrailCenterOffsetY(direction: .down, discSide: 60) ?? 0), -52, accuracy: 1e-9)
        XCTAssertNil(S2GuideDLayout.gestureTrailCenterOffsetY(direction: .leftRight, discSide: 60))
        XCTAssertEqual(S2GuideDLayout.gestureReachAboveCenter(direction: .up, discSide: 72), 116, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.gestureReachAboveCenter(direction: .down, discSide: 60), 72, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.gestureReachAboveCenter(direction: .leftRight, discSide: 60), 66, accuracy: 1e-9)
        // 落位：在主图中心；压到教练卡才整体下移（375×667、安全区顶 20 的第 1 步：237 + 116 = 353 > 333.5）。
        XCTAssertEqual(S2GuideDLayout.gestureDiscCenterY(direction: .up, discSide: 72, photoCenterY: 426, safeAreaTop: 59), 426, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.gestureDiscCenterY(direction: .up, discSide: 72, photoCenterY: 333.5, safeAreaTop: 20), 353, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.gestureDiscCenterY(direction: .down, discSide: 60, photoCenterY: 333.5, safeAreaTop: 20), 333.5, accuracy: 1e-9)
        XCTAssertEqual(S2GuideDLayout.gestureDiscCenterY(direction: .leftRight, discSide: 60, photoCenterY: 333.5, safeAreaTop: 20), 333.5, accuracy: 1e-9)
        // 运动：每周期位移 0 → 40、不透明度 1 → 0；左右滑偶数周期向右、奇数周期向左；负时刻按 0。
        let samples: [(S2GuideGestureDirection, Double, Double, Double, Double)] = [
            (.up, 0, 0, 0, 1),
            (.up, 0.45, 0, -20, 0.5),
            (.up, 1.35, 0, -20, 0.5),
            (.down, 0.225, 0, 10, 0.75),
            (.leftRight, 0.45, 20, 0, 0.5),
            (.leftRight, 1.35, -20, 0, 0.5),
            (.leftRight, 2.25, 20, 0, 0.5),
            (.leftRight, -1, 0, 0, 1)
        ]
        for (direction, elapsed, x, y, opacity) in samples {
            let motion = S2GuideDLayout.gestureMotion(direction: direction, elapsed: elapsed)
            XCTAssertEqual(Double(motion.offset.width), x, accuracy: 1e-6, "\(direction) \(elapsed)")
            XCTAssertEqual(Double(motion.offset.height), y, accuracy: 1e-6, "\(direction) \(elapsed)")
            XCTAssertEqual(motion.opacity, opacity, accuracy: 1e-6, "\(direction) \(elapsed)")
        }
        // 未定项 38：两档参考布局下（主图显示帧竖直中心取视口中心）示范运动包络与教练卡、中央状态指示的竖向几何，只打印、不判；
        // 只断言包络上缘不高于教练卡下缘（K3「任何一帧都不得压住教练卡」）。
        for (label, size, safeTop) in [("393x852", large, CGFloat(59)), ("375x667", small, CGFloat(20))] {
            let photoCenterY = size.height / 2
            let coachBottom = S2GuideDLayout.coachBottom(safeAreaTop: safeTop)
            let indicatorTop = photoCenterY - S2CenterIndicatorView.containerHeight / 2
            let indicatorBottom = photoCenterY + S2CenterIndicatorView.containerHeight / 2
            for step in [S2GuideStep.swipeUp, .markedOnce, .undone] {
                guard let direction = S2GuideDLayout.gestureDirection(for: step) else {
                    continue
                }
                let side = S2GuideDLayout.gestureDiscSide(for: step)
                let centerY = S2GuideDLayout.gestureDiscCenterY(
                    direction: direction,
                    discSide: side,
                    photoCenterY: photoCenterY,
                    safeAreaTop: safeTop
                )
                let reach = S2GuideDLayout.gestureReachAboveCenter(direction: direction, discSide: side)
                XCTAssertGreaterThanOrEqual(centerY - reach, coachBottom - 1e-9, "\(label) \(step)")
                let below: CGFloat
                switch direction {
                case .up:
                    below = side / 2 + S2GuideDMetrics.gestureTrailGap + S2GuideDMetrics.gestureTrailLength
                case .down:
                    below = side / 2 + S2GuideDMetrics.gestureArrowOffset + S2GuideDMetrics.guideGestureTravel
                case .leftRight:
                    below = side / 2 + S2GuideDMetrics.gestureDiscHaloWidth
                }
                let discTop = centerY - side / 2
                let discBottom = centerY + side / 2
                let avoidLine = S2GuideDLayout.indicatorAvoidanceLineY(photoCenterY: photoCenterY)
                let overlaps = discTop < indicatorBottom && discBottom > indicatorTop
                let fields: [String] = [
                    "IC196_GEOMETRY \(label) step=\(step.rawValue)",
                    "coachBottom=\(coachBottom) avoidLine=\(avoidLine)",
                    "discCenter=\(centerY) discTop=\(discTop) discBottom=\(discBottom)",
                    "envelopeTop=\(centerY - reach) envelopeBottom=\(centerY + below)",
                    "indicator=\(indicatorTop)...\(indicatorBottom) discOverlapsIndicator=\(overlaps)"
                ]
                print(fields.joined(separator: " "))
            }
        }
    }

    // MARK: - 断言 3：目录与步骤映射

    func testIC196C_CatalogAndStepPresentation() throws {
        let data = try XCTUnwrap(sourceText(Self.catalogPath)?.data(using: .utf8))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for (key, value) in Self.newKeyValues {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], key)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
            let zh = try XCTUnwrap(localizations["zh-Hans"] as? [String: Any], key)
            let unit = try XCTUnwrap(zh["stringUnit"] as? [String: Any], key)
            XCTAssertEqual(unit["value"] as? String, value, key)
            XCTAssertEqual(L10n.text(key), value, key)
        }
        XCTAssertEqual(strings.keys.filter { $0.hasPrefix("s2.guide.") }.count, 11)
        XCTAssertEqual(S2GuideStep.confirmEntry.title(mergedCount: 5), "攒了 5 张")
        XCTAssertEqual(
            L10n.text("s2.guide.progress", replacing: ["current": "2", "total": "4"]),
            "第 2 步，共 4 步"
        )
        XCTAssertEqual(S2GuideStep.allCases.map(\.ordinal), [1, 2, 3, 4])
        XCTAssertEqual(
            S2GuideStep.allCases.map { $0.title(mergedCount: 5) },
            ["上滑，放进待删篮", "已放进待删篮", "已撤回，照片回来了", "攒了 5 张"]
        )
        XCTAssertEqual(
            S2GuideStep.allCases.map(\.subtitle),
            ["不会删除照片。攒好了再一起确认。", "标错了？下滑放回来。", "左右滑翻看，开始整理吧。", "点右上角垃圾桶，一起过目再删除。"]
        )
        XCTAssertEqual(
            S2GuideStep.allCases.map(\.glyphSymbolName),
            ["arrow.up", "arrow.down", "arrow.left.and.right", "trash"]
        )
        XCTAssertEqual(
            S2GuideStep.allCases.map(\.leadSymbolName),
            [nil, "checkmark", "arrow.uturn.backward", "checkmark"]
        )
    }

    // MARK: - 断言 4：离屏尺寸

    @MainActor
    func testIC196D_RenderedSizes() {
        let unbounded = CGFloat.greatestFiniteMagnitude
        for viewportWidth in [CGFloat(393), CGFloat(375)] {
            let cardWidth = S2GuideDLayout.coachWidth(viewportWidth: viewportWidth)
            // 文字区宽 = 卡宽 − 左右内距 − 圆底 − 主行间距。
            let textWidth = cardWidth - S2GuideDMetrics.coachPaddingLeading - S2GuideDMetrics.coachPaddingTrailing -
                S2GuideDMetrics.coachGlyphCircleSide - S2GuideDMetrics.coachMainRowSpacing
            for step in S2GuideStep.allCases {
                let card = fittedSize(
                    S2GuideCoachCard(step: step, mergedCount: 5, learnedSteps: [.swipeUp], onSkip: {}),
                    in: CGSize(width: cardWidth, height: unbounded)
                )
                XCTAssertEqual(card.height, S2GuideDMetrics.coachCardHeight, accuracy: 0.5, "\(viewportWidth) \(step)")
                XCTAssertLessThanOrEqual(card.width, cardWidth + 0.5, "\(viewportWidth) \(step)")
                let title = fittedSize(
                    HStack(spacing: S2GuideDMetrics.coachTitleLeadSpacing) {
                        if let lead = step.leadSymbolName {
                            Image(systemName: lead)
                                .font(.system(size: S2GuideDMetrics.coachTitleLeadPointSize, weight: .bold))
                        }
                        Text(step.title(mergedCount: 5))
                            .font(.system(size: S2GuideDMetrics.coachTitleFontSize, weight: .heavy))
                    }
                    .fixedSize(),
                    in: CGSize(width: unbounded, height: unbounded)
                )
                let subtitle = fittedSize(
                    Text(step.subtitle)
                        .font(.system(size: S2GuideDMetrics.coachSubtitleFontSize))
                        .fixedSize(),
                    in: CGSize(width: unbounded, height: unbounded)
                )
                let textFields: [String] = [
                    "IC196_TEXT width=\(viewportWidth) step=\(step.rawValue) available=\(textWidth)",
                    "card=\(card.width)x\(card.height)",
                    "title=\(title.width) subtitle=\(subtitle.width) subtitleHeight=\(subtitle.height)"
                ]
                print(textFields.joined(separator: " "))
                XCTAssertLessThanOrEqual(title.width, textWidth, "\(viewportWidth) \(step) title")
                XCTAssertLessThanOrEqual(subtitle.width, textWidth, "\(viewportWidth) \(step) subtitle")
            }
        }
        let done = fittedSize(S2GuideCompletionCard(), in: CGSize(width: 393, height: unbounded))
        print("IC196_DONE size=\(done.width)x\(done.height)")
        XCTAssertEqual(
            done.height,
            S2GuideDMetrics.doneVerticalPadding * 2 + S2GuideDMetrics.doneCheckCircleSide,
            accuracy: 0.5
        )
        XCTAssertLessThanOrEqual(done.width, 393)
        // 两只层视图与压暗在四步、完成与无项下都能构造、不越出提议尺寸。
        let viewport = CGSize(width: 393, height: 852)
        var displays: [S2GuideDisplay?] = [nil, .completion]
        for step in S2GuideStep.allCases {
            displays.append(.step(step))
        }
        for display in displays {
            let cards = fittedSize(
                S2GuideDCardLayer(
                    display: display,
                    mergedCount: 5,
                    learnedSteps: [.swipeUp, .markedOnce],
                    viewportSize: viewport,
                    safeAreaTop: 59,
                    onSkip: {}
                ),
                in: viewport
            )
            let gesture = fittedSize(
                S2GuideDGestureLayer(display: display, viewportSize: viewport, safeAreaTop: 59, photoCenterY: 426),
                in: viewport
            )
            // 只核「能构造、不越出提议」；弹性框是否恰好吃满提议不在本卡判（接线后由真机看）。
            print("IC196_LAYER display=\(String(describing: display)) cards=\(cards.width)x\(cards.height) gesture=\(gesture.width)x\(gesture.height)")
            XCTAssertLessThanOrEqual(cards.width, viewport.width + 0.5, "\(String(describing: display))")
            XCTAssertLessThanOrEqual(cards.height, viewport.height + 0.5, "\(String(describing: display))")
            XCTAssertLessThanOrEqual(gesture.width, viewport.width + 0.5, "\(String(describing: display))")
            XCTAssertLessThanOrEqual(gesture.height, viewport.height + 0.5, "\(String(describing: display))")
        }
        let scrimFrame = S2GuideDLayout.introScrimFrame(
            viewportSize: viewport,
            safeAreaTop: 59,
            safeAreaBottom: 34,
            bottomStripHeight: 30
        )
        let scrim = fittedSize(S2GuideIntroScrim(scrimFrame: scrimFrame), in: viewport)
        print("IC196_LAYER scrim=\(scrim.width)x\(scrim.height)")
        XCTAssertLessThanOrEqual(scrim.width, viewport.width + 0.5)
        XCTAssertLessThanOrEqual(scrim.height, viewport.height + 0.5)
    }

    // MARK: - 断言 5：源码落位

    func testIC196E_SourceDiscipline() throws {
        let raw = try XCTUnwrap(sourceText(Self.viewsPath))
        let views = stripped(raw)
        for (needle, expected) in [
            ("import ", 1),
            ("import SwiftUI", 1),
            ("Text(\"", 0),
            ("return \"", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: raw), expected, needle)
        }
        for (needle, expected) in [
            ("@MainActor", 0),
            ("Material", 0),
            ("colorScheme", 0),
            ("GlassEffectContainer", 0),
            ("UIImage", 0),
            ("PHAsset", 0),
            ("UserDefaults", 0),
            ("S2GuideCoordinator", 0),
            ("repeatForever", 0),
            ("withAnimation", 0),
            ("stripTopFromViewportBottom", 0),
            ("L10n.text(", 11),
            ("Button {", 1),
            ("TimelineView(.animation)", 1),
            (".allowsHitTesting(false)", 9),
            (".id(step)", 2),
            (".transition(.opacity)", 4),
            (".animation(", 2),
            ("S2MarkAfterimageFlight.trashCenter(", 1),
            ("S2OverlayLayout.stripBottomFromViewportBottom(", 1),
            ("S2OverlayLayout.topBarHeight", 2),
            ("S0DeckMetrics.", 27)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: views), expected, needle)
        }
        // 每条新 key 在源码里恰写一次（含跨行调用：只数带引号的 key 本身）。
        for (key, _) in Self.newKeyValues {
            XCTAssertEqual(occurrences(of: "\"\(key)\"", in: raw), 1, key)
        }
        // 登记族：`static let` 恰为逐值表里的名字，且每个名字在声明之外至少被引用一次。
        let metrics = try XCTUnwrap(slice(views, from: "enum S2GuideDMetrics {", to: "enum S2GuideGestureDirection"))
        let symbols = try XCTUnwrap(slice(views, from: "enum S2GuideDSymbol {", to: "enum S2GuideDMetrics {"))
        XCTAssertEqual(occurrences(of: "static let ", in: metrics), Self.metricValues.count)
        XCTAssertEqual(occurrences(of: "static let ", in: symbols), Self.symbolValues.count)
        for (name, _, _) in Self.metricValues {
            XCTAssertEqual(occurrences(of: "static let \(name):", in: metrics), 1, name)
            XCTAssertGreaterThanOrEqual(occurrences(of: "S2GuideDMetrics.\(name)", in: views), 1, name)
        }
        for (name, _, _) in Self.symbolValues {
            XCTAssertEqual(occurrences(of: "static let \(name) = ", in: symbols), 1, name)
            XCTAssertGreaterThanOrEqual(occurrences(of: "S2GuideDSymbol.\(name)", in: views), 1, name)
        }
    }

    // MARK: - 工具（与既有测试同口径）

    @MainActor
    private func fittedSize<V: View>(_ view: V, in proposal: CGSize) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: proposal)
    }

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.upperBound])
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceText(_ relativePath: String) -> String? {
        try? String(
            contentsOf: repoRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    /// 剔掉 `//` 注释与字符串字面量内容。
    private func stripped(_ source: String) -> String {
        let newline = Character(UnicodeScalar(UInt8(10)))
        var output = ""
        var iterator = source.startIndex
        var inString = false
        while iterator < source.endIndex {
            let character = source[iterator]
            let next = source.index(after: iterator)
            if inString {
                if character == "\\" {
                    iterator = next < source.endIndex
                        ? source.index(after: next)
                        : source.endIndex
                    continue
                }
                if character == "\"" {
                    inString = false
                }
                iterator = next
                continue
            }
            if character == "\"" {
                inString = true
                iterator = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                while iterator < source.endIndex,
                      source[iterator] != newline {
                    iterator = source.index(after: iterator)
                }
                output.append(newline)
                continue
            }
            output.append(character)
            iterator = next
        }
        return output
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}
