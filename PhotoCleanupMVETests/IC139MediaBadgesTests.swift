import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-139：媒体标识层（实况胶囊、视频浮框骨架、视频页几何、长按分派）。
///
/// **本卡不接任何播放器**，故这里没有一条断言涉及播放状态。
/// 真机落点由 H63a 三项兜底，见 `Reports/IC-139/self-check.md`。
final class IC139MediaBadgesTests: XCTestCase {
    /// 画布基准视口（393×852，安全区顶 59 / 底 34）。
    private let viewport = CGSize(width: 393, height: 852)
    private let safeAreaTop: CGFloat = 59
    private let safeAreaBottom: CGFloat = 34

    /// 竖向受限（高度吃满）的资产：适配尺寸的高等于可用区高。
    private let heightBoundRatio: CGFloat = 0.4
    /// 横向受限（宽度吃满）的资产：适配尺寸的宽等于视口宽。
    private let widthBoundRatio: CGFloat = 1.5

    // MARK: - 断言 1：三类资产映射

    func testIC139A_MediaKindMapsEveryProbeKindWithoutReimplementingPredicate() {
        // 映射对判别器的三个取值必须是全的，且一一对应。
        XCTAssertEqual(S2MediaKind(probeKind: .video), .video)
        XCTAssertEqual(S2MediaKind(probeKind: .livePhoto), .live)
        XCTAssertEqual(S2MediaKind(probeKind: .photo), .photo)

        let mapped = S2AssetSizeProbeMediaKind.allCases
            .map { S2MediaKind(probeKind: $0) }
        XCTAssertEqual(
            Set(mapped).count,
            S2AssetSizeProbeMediaKind.allCases.count,
            "映射不是单射，两个判别结果落到了同一个展示类别"
        )
        XCTAssertEqual(Set(mapped), Set(S2MediaKind.allCases))

        // 判别谓词只有一处实现：协调器不得自带 mediaType / photoLive 判别。
        guard let text = sourceText(
            "PhotoCleanupMVE/App/CleanupCoordinator.swift"
        ) else {
            return XCTFail("读不到协调器源码")
        }
        XCTAssertFalse(
            text.contains("mediaSubtypes.contains(.photoLive)"),
            "协调器自带了第二份实况判别"
        )
        XCTAssertTrue(
            text.contains("AssetSizeProbeService.mediaKind(of:"),
            "协调器未走全仓唯一的判别器"
        )
    }

    // MARK: - 断言 2、3：实况胶囊口径

    func testIC139A_LivePillExistsOnlyOnVisibleLivePage() {
        XCTAssertNotNil(
            S2LivePillPresentation.make(
                mediaKind: .live,
                interfaceVisibility: .visible
            )
        )
        // 断言 3：照片页与视频页不构造胶囊。
        XCTAssertNil(
            S2LivePillPresentation.make(
                mediaKind: .photo,
                interfaceVisibility: .visible
            )
        )
        XCTAssertNil(
            S2LivePillPresentation.make(
                mediaKind: .video,
                interfaceVisibility: .visible
            )
        )
    }

    func testIC139A_LivePillGeometryReferencesRegisteredChromeConstants() {
        // 引用断言：与既有 chrome 语汇同值的两个量必须是**同一个符号**，
        // 不是碰巧相等的字面量。
        XCTAssertEqual(
            S2MediaMetrics.livePillTopFromTopBarBottom,
            S2OverlayLayout.stripToBottomRowSpacing
        )
        XCTAssertEqual(
            S2MediaMetrics.livePillLeading,
            S2OverlayLayout.chromeHorizontalMargin
        )

        // 画布定稿取值（④）。
        XCTAssertEqual(S2MediaMetrics.livePillHeight, 28)
        XCTAssertEqual(S2MediaMetrics.livePillCornerRadius, 14)
        XCTAssertEqual(S2MediaMetrics.livePillPaddingLeading, 8)
        XCTAssertEqual(S2MediaMetrics.livePillPaddingTrailing, 10)
        XCTAssertEqual(S2MediaMetrics.livePillIconPointSize, 13)
        XCTAssertEqual(S2MediaMetrics.livePillFontSize, 12)
        XCTAssertEqual(S2MediaMetrics.livePillItemSpacing, 5)

        // 视觉锚：胶囊上缘 = 安全区顶 + 顶栏帧高 + 间距。
        XCTAssertEqual(
            S2MediaMetrics.livePillTopFromViewportTop(
                safeAreaTop: safeAreaTop
            ),
            safeAreaTop + S2OverlayLayout.topBarHeight +
                S2OverlayLayout.stripToBottomRowSpacing
        )
    }

    func testIC139A_LivePillModelHasNoActionOrChevronField() {
        guard let model = S2LivePillPresentation.make(
            mediaKind: .live,
            interfaceVisibility: .visible
        ) else {
            return XCTFail("实况页未构造胶囊")
        }
        // 决策 54：无下箭头、不可点。字段表里只应有符号名与文字两项。
        let fields = Mirror(reflecting: model).children.compactMap(\.label)
        XCTAssertEqual(fields.sorted(), ["symbolName", "text"])
        XCTAssertEqual(model.symbolName, "livephoto")
        XCTAssertEqual(model.text, L10n.text("s2.media.live_badge"))
    }

    // MARK: - 断言 4：视频浮框骨架




    // MARK: - 断言 5：隐藏态与显隐过渡



    // MARK: - 断言 6：视频页几何（渲染帧）






    // MARK: - 断言 8、9：长按分派




    // MARK: - 夹具






    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
