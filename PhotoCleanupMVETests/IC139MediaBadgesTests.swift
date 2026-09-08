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

    func testIC139B_VideoBarExistsOnlyOnVisibleVideoPageAndTakesNoHits() {
        guard let model = S2VideoBarPresentation.make(
            mediaKind: .video,
            interfaceVisibility: .visible
        ) else {
            return XCTFail("视频页未构造浮框")
        }
        XCTAssertEqual(model.playSymbolName, "play.fill")
        XCTAssertEqual(model.muteSymbolName, "speaker.slash.fill")
        XCTAssertEqual(model.progress, 0)
        // 本卡三件不接点击，IC-141 接线。
        XCTAssertFalse(model.acceptsHits)

        XCTAssertNil(
            S2VideoBarPresentation.make(
                mediaKind: .photo,
                interfaceVisibility: .visible
            )
        )
        XCTAssertNil(
            S2VideoBarPresentation.make(
                mediaKind: .live,
                interfaceVisibility: .visible
            )
        )
    }

    func testIC139B_VideoBarGeometryReferencesRegisteredChromeConstants() {
        XCTAssertEqual(
            S2MediaMetrics.videoBarHorizontalMargin,
            S2OverlayLayout.chromeHorizontalMargin
        )
        XCTAssertEqual(
            S2MediaMetrics.videoBarBottomToStripTop,
            S2OverlayLayout.stripToBottomRowSpacing
        )

        XCTAssertEqual(S2MediaMetrics.videoBarHeight, 44)
        XCTAssertEqual(S2MediaMetrics.videoBarCornerRadius, 22)
        XCTAssertEqual(S2MediaMetrics.videoBarHorizontalPadding, 14)
        XCTAssertEqual(S2MediaMetrics.videoBarItemSpacing, 12)
        XCTAssertEqual(S2MediaMetrics.videoBarButtonIconPointSize, 18)
        XCTAssertEqual(S2MediaMetrics.videoBarMuteIconPointSize, 20)
        XCTAssertEqual(S2MediaMetrics.videoBarTrackHeight, 4)
        XCTAssertEqual(S2MediaMetrics.videoBarTrackCornerRadius, 2)
        XCTAssertEqual(S2MediaMetrics.videoBarKnobDiameter, 12)
        XCTAssertEqual(S2MediaMetrics.videoBarTimeFontSize, 13)
        XCTAssertEqual(S2MediaMetrics.videoBarTrackOpacity, 0.28)
    }

    /// 陷阱 14：浮框是**视觉**锚，不得复用含触控带下限的推导式。
    func testIC139B_VideoBarAnchorUsesVisualStripHeightNotTouchBandFloor() {
        // 取一个小于最小触控边长的横栏高：两条推导式此时必然分叉。
        let visualStripHeight = S2OverlayLayout.minimumTouchTarget - 10
        let anchored = S2MediaMetrics.videoBarBottomFromViewportBottom(
            safeAreaBottom: safeAreaBottom,
            bottomStripHeight: visualStripHeight
        )
        let expected = S2OverlayLayout.stripBottomFromViewportBottom(
            safeAreaBottom: safeAreaBottom
        ) + visualStripHeight + S2OverlayLayout.stripToBottomRowSpacing
        XCTAssertEqual(anchored, expected)

        let touchBandAnchor = S2OverlayLayout.stripTopFromViewportBottom(
            safeAreaBottom: safeAreaBottom,
            bottomStripHeight: visualStripHeight
        ) + S2OverlayLayout.stripToBottomRowSpacing
        XCTAssertNotEqual(
            anchored,
            touchBandAnchor,
            "浮框锚复用了含 max(最小触控边长, 横栏高) 的触控带推导式"
        )
    }

    // MARK: - 断言 5：隐藏态与显隐过渡

    func testIC139B_HiddenInterfaceBuildsNeitherPillNorBar() {
        for kind in S2MediaKind.allCases {
            XCTAssertNil(
                S2LivePillPresentation.make(
                    mediaKind: kind,
                    interfaceVisibility: .hidden
                ),
                "\(kind) 在隐藏态仍构造了胶囊"
            )
            XCTAssertNil(
                S2VideoBarPresentation.make(
                    mediaKind: kind,
                    interfaceVisibility: .hidden
                ),
                "\(kind) 在隐藏态仍构造了浮框"
            )
        }
    }

    /// 显隐过渡不自造语汇：三个量必须落在既有 chrome 过渡常量上。
    func testIC139B_MediaChromeUsesExistingVisibilityTransitionConstants() {
        XCTAssertEqual(S2ChromeVisibilityTransition.durationSeconds, 0.2)
        XCTAssertEqual(S2ChromeVisibilityTransition.hiddenScale, 1.06)
        XCTAssertEqual(S2ChromeVisibilityTransition.hiddenBlurRadius, 8)

        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }
        // 媒体常量容器里不得出现自造的时长／缩放／模糊。
        let container = mediaMetricsBlock(in: text)
        XCTAssertFalse(container.isEmpty, "未截取到媒体常量容器")
        for banned in ["durationSeconds", "hiddenScale", "hiddenBlurRadius"] {
            XCTAssertFalse(
                container.contains(banned),
                "媒体常量容器自造了显隐过渡量 \(banned)"
            )
        }
    }

    // MARK: - 断言 6：视频页几何（渲染帧）

    func testIC139C_VideoPageFitInsetIsDerivedNotIndependent() {
        // 推导量恒等式：68 = 44 + 24。
        XCTAssertEqual(
            S2MediaMetrics.videoPageFitBottomInset,
            S2MediaMetrics.videoBarHeight +
                S2MediaMetrics.videoBarBottomToStripTop
        )
        XCTAssertEqual(S2MediaMetrics.videoPageFitBottomInset, 68)
    }

    /// 竖向受限资产：视频页显示态渲染帧 `maxY` 比照片页小 68、`minY` 相同。
    func testIC139C_VisibleVideoPageRenderFrameLiftsBottomEdgeBy68() {
        let photo = renderedOneXFrame(
            mediaKind: .photo,
            visibility: .visible,
            ratio: heightBoundRatio
        )
        let video = renderedOneXFrame(
            mediaKind: .video,
            visibility: .visible,
            ratio: heightBoundRatio
        )

        XCTAssertEqual(photo.minY, video.minY, accuracy: 0.001)
        XCTAssertEqual(
            photo.maxY - video.maxY,
            S2MediaMetrics.videoPageFitBottomInset,
            accuracy: 0.001
        )
        // 上缘不变：该资产竖向吃满，两页顶缘都贴视口顶。
        XCTAssertEqual(video.minY, 0, accuracy: 0.001)
        XCTAssertEqual(
            video.height,
            viewport.height - S2MediaMetrics.videoPageFitBottomInset,
            accuracy: 0.001
        )
    }

    /// 横向受限资产：适配尺寸不变，整帧在缩短后的适配区里重新居中（上移 34）。
    ///
    /// 卡内断言 6 的措辞（`maxY` 小 68、`minY` 相同）只对竖向受限资产成立，
    /// 见 self-check「卡内前提与实测的出入」。这里把真实行为一并钉住。
    func testIC139C_WidthBoundVideoPageRecentersInsideShortenedRegion() {
        let photo = renderedOneXFrame(
            mediaKind: .photo,
            visibility: .visible,
            ratio: widthBoundRatio
        )
        let video = renderedOneXFrame(
            mediaKind: .video,
            visibility: .visible,
            ratio: widthBoundRatio
        )

        XCTAssertEqual(photo.size.width, video.size.width, accuracy: 0.001)
        XCTAssertEqual(photo.size.height, video.size.height, accuracy: 0.001)
        let lift = S2MediaMetrics.videoPageFitBottomInset / 2
        XCTAssertEqual(photo.minY - video.minY, lift, accuracy: 0.001)
        XCTAssertEqual(photo.maxY - video.maxY, lift, accuracy: 0.001)
    }

    /// 断言 7 的一半：隐藏态视频页与照片页渲染帧逐值相同（几何回满）。
    func testIC139C_HiddenVideoPageGeometryMatchesPhotoPage() {
        for ratio in [heightBoundRatio, widthBoundRatio] {
            let photo = renderedOneXFrame(
                mediaKind: .photo,
                visibility: .hidden,
                ratio: ratio
            )
            let video = renderedOneXFrame(
                mediaKind: .video,
                visibility: .hidden,
                ratio: ratio
            )
            XCTAssertEqual(photo, video, "比例 \(ratio) 的隐藏态几何发生了变化")
        }
    }

    /// 断言 7 的另一半：照片页与实况页几何零改动（两个可见性都核）。
    func testIC139C_PhotoAndLivePagesKeepBaselineGeometry() {
        for visibility in [S2InterfaceVisibility.visible, .hidden] {
            for ratio in [heightBoundRatio, widthBoundRatio] {
                let baseline = baselineOneXFrame(
                    visibility: visibility,
                    ratio: ratio
                )
                for kind in [S2MediaKind.photo, .live] {
                    let actual = renderedOneXFrame(
                        mediaKind: kind,
                        visibility: visibility,
                        ratio: ratio
                    )
                    XCTAssertEqual(
                        actual,
                        baseline,
                        "\(kind) 页 \(visibility) 态几何偏离基线"
                    )
                }
            }
        }
    }

    // MARK: - 断言 8、9：长按分派




    // MARK: - 夹具

    /// 用真实的 `S2NativeZoomScrollView` 跑一遍几何链，读**渲染帧**
    /// （视口坐标）。这条路径与产品完全同源：`configure` → 几何链写入 →
    /// `oneXPresentationFrame`。
    ///
    /// **夹具驱动**：它证明的是几何链在给定输入下的落点，不证明真机上
    /// 手势与分帧时序（陷阱 1），后者由 H63a 兜底。
    private func renderedOneXFrame(
        mediaKind: S2MediaKind,
        visibility: S2InterfaceVisibility,
        ratio: CGFloat
    ) -> CGRect {
        let base = baselineMetrics(visibility: visibility, ratio: ratio)
        let fit = S2MediaPageGeometry.videoPageFit(
            viewportSize: viewport,
            assetAspectRatio: ratio,
            mediaKind: mediaKind,
            interfaceVisibility: visibility
        )
        return renderedFrame(
            fittedSize: fit?.size ?? base.oneXDisplaySize,
            fittedCenterY: fit?.centerY ?? base.oneXDisplayCenterY,
            nativeZoomBaseSize: base.nativeZoomBaseSize
        )
    }

    /// 本卡改动前的几何：直接取 `S2ViewportLayout.metrics` 的输出。
    private func baselineOneXFrame(
        visibility: S2InterfaceVisibility,
        ratio: CGFloat
    ) -> CGRect {
        let base = baselineMetrics(visibility: visibility, ratio: ratio)
        return renderedFrame(
            fittedSize: base.oneXDisplaySize,
            fittedCenterY: base.oneXDisplayCenterY,
            nativeZoomBaseSize: base.nativeZoomBaseSize
        )
    }

    private func renderedFrame(
        fittedSize: CGSize,
        fittedCenterY: CGFloat,
        nativeZoomBaseSize: CGSize
    ) -> CGRect {
        let scrollView = S2NativeZoomScrollView(
            frame: CGRect(origin: .zero, size: viewport)
        )
        let contentView = UIView()
        scrollView.configure(
            contentView: contentView,
            fittedSize: fittedSize,
            nativeZoomBaseSize: nativeZoomBaseSize,
            viewportSize: viewport,
            maximumZoomScale: 1,
            fittedCenterY: fittedCenterY
        )
        scrollView.layoutIfNeeded()
        scrollView.applyNativeState(scale: 1, viewportOffset: .zero)
        return scrollView.oneXPresentationFrame
    }

    private func baselineMetrics(
        visibility: S2InterfaceVisibility,
        ratio: CGFloat
    ) -> S2ViewportMetrics {
        S2ViewportLayout.metrics(
            physicalSize: viewport,
            presentationState: S2ViewportPresentationState(
                interfaceVisibility: visibility,
                bottomStripState: .idle,
                sheetState: .closed
            ),
            assetAspectRatio: ratio,
            isScreenshot: false,
            configuration: .factoryPlaceholder,
            safeAreaInsets: S2OverlaySafeAreaInsets(
                top: safeAreaTop,
                leading: 0,
                bottom: safeAreaBottom,
                trailing: 0
            )
        )
    }

    /// 截取 `S2MediaMetrics` 容器正文，供「不自造语汇」的源码扫描用。
    private func mediaMetricsBlock(in text: String) -> String {
        guard let start = text.range(of: "enum S2MediaMetrics {") else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: "\n}\n") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
