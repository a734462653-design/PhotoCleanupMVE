import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-139：媒体标识层（实况胶囊、视频浮框骨架、视频页几何、长按分派）。
///
/// **本卡不接任何播放器**，故这里没有一条断言涉及播放状态。
/// 真机落点由 H63a 三项兜底，见 `Reports/IC-139/self-check.md`。
final class IC139MediaBadgesTests: XCTestCase {
    private let safeAreaTop: CGFloat = 59
    private let safeAreaBottom: CGFloat = 34


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

    /// IC-141 C 改口径：三件自本卡起接点击、符号与进度随播放状态走。
    /// 「只在视频页显示态构造」这一条不变，仍在这里守。
    func testIC139B_VideoBarExistsOnlyOnVisibleVideoPage() {
        let idle = S2VideoPlaybackSnapshot.idle
        guard let model = S2VideoBarPresentation.make(
            mediaKind: .video,
            interfaceVisibility: .visible,
            playback: idle
        ) else {
            return XCTFail("视频页未构造浮框")
        }
        // 未起播时是「播放」+「静音」两个符号，进度 0。
        XCTAssertEqual(model.playSymbolName, "play.fill")
        XCTAssertEqual(model.muteSymbolName, "speaker.slash.fill")
        XCTAssertEqual(model.progress, 0)
        XCTAssertTrue(model.acceptsHits)

        XCTAssertNil(
            S2VideoBarPresentation.make(
                mediaKind: .photo,
                interfaceVisibility: .visible,
                playback: idle
            )
        )
        XCTAssertNil(
            S2VideoBarPresentation.make(
                mediaKind: .live,
                interfaceVisibility: .visible,
                playback: idle
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
                    interfaceVisibility: .hidden,
                    playback: .idle
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

    // MARK: - 断言 8、9：长按分派

    func testIC139D_LongPressGoesToLivePlaybackOnlyOnLivePages() {
        XCTAssertEqual(
            S2MainPhotoLongPressAction.resolve(mediaKind: .live),
            .livePhotoPlayback
        )
        XCTAssertEqual(
            S2MainPhotoLongPressAction.resolve(mediaKind: .photo),
            .unbound
        )
        XCTAssertEqual(
            S2MainPhotoLongPressAction.resolve(mediaKind: .video),
            .unbound
        )
    }

    // IC-140 D：`testIC139D_LivePhotoLongPressRecordsOncePerPress` 随
    // `S2LivePhotoLongPressRecorder` 一并删除——长按落点已改为实况播放协调器，
    // 事件记录器不再存在。替代覆盖见 `IC140LivePhotoPlaybackTests` 断言 5。

    func testIC139D_CalibrationPanelToggleLeavesTheMainPhotoLongPressPath() {
        // 面板本身的开关语义未改：一次调用翻转一次。
        var state = S2CalibrationOverlayState.initial
        XCTAssertFalse(state.controlsVisible)
        state.toggleAccessControls()
        XCTAssertTrue(state.controlsVisible)
        state.toggleAccessControls()
        XCTAssertFalse(state.controlsVisible)

        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }
        // 断言 9：产品源码里 `toggleAccessControls()` 恰一处调用点，
        // 且它挂在中胶囊长按上，不在主图长按闭包里。
        let callSites = text.components(
            separatedBy: "calibrationOverlayState.toggleAccessControls()"
        ).count - 1
        XCTAssertEqual(callSites, 1, "标定面板入口不再恰为一处")
        XCTAssertTrue(
            text.contains("onLongPressGesture("),
            "中胶囊长按未接线"
        )
        XCTAssertTrue(
            text.contains("handleMainPhotoLongPress()"),
            "主图长按未改派"
        )
    }

    // MARK: - IC-142 断言 1：撤销钉住（带正对照）

    /// 决策 57 作废（④ Lynn 2026-09-08 H63a 第 2 项改判）：视频页两态几何
    /// 与照片页相同，浮框如 chrome 一样压在主图之上。
    ///
    /// 正对照取 IC-139 之前的基线 `db318fc`：那时三处赋值恰是 2 + 1。
    /// 只断言「符号消失」会在赋值被误删时同样通过，故两侧一起钉。
    func testIC142_VideoPageSharesPhotoPageGeometryInBothVisibilityStates() {
        guard let view = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }

        // 正对照：逐页几何回到基线的两个入口。
        XCTAssertEqual(
            occurrences(of: "fittedSize: pageMetrics.oneXDisplaySize", in: view),
            2,
            "逐页 fittedSize 未回到基线口径"
        )
        XCTAssertEqual(
            occurrences(
                of: "fittedCenterY: pageMetrics.oneXDisplayCenterY",
                in: view
            ),
            1,
            "逐页 fittedCenterY 未回到基线口径"
        )

        // 撤销：三个串在**产品源码全目录**归零。名字拼接构造，
        // 否则本断言会抓到自己所在文件之外的注释。
        let removed = [
            "S2MediaPage" + "Geometry",
            "videoPage" + "Fit(",
            "videoPageFit" + "BottomInset",
        ]
        for relativePath in [
            "PhotoCleanupMVE/Features/S2/S2View.swift",
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift",
            "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
            "PhotoCleanupMVE/App/CleanupCoordinator.swift",
        ] {
            guard let text = sourceText(relativePath) else {
                return XCTFail("读不到 \(relativePath)")
            }
            for symbol in removed {
                XCTAssertEqual(
                    occurrences(of: symbol, in: text),
                    0,
                    "\(relativePath) 仍引用 \(symbol)"
                )
            }
        }

        // B 的两个常量必须**留着**——浮框本身没撤，只撤几何。
        XCTAssertEqual(S2MediaMetrics.videoBarHeight, 44)
        XCTAssertEqual(
            S2MediaMetrics.videoBarBottomToStripTop,
            S2OverlayLayout.stripToBottomRowSpacing
        )
    }

    // MARK: - 夹具

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
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
