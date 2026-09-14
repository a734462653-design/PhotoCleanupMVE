import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-146：S2 chrome 二轮——底排改组（相簿跑道圆 + 分享）、氛围底、
/// 「已标记 · 撤销」、退后台停用音频会话。
///
/// 几何断言走**布局模型** `S2OverlayLayoutSnapshot`，不走渲染帧：逐像素比对
/// 渲染结果需要给产品视图加测试专用探针，属「不为测试改产品」禁止项——
/// 该边界由 IC-100 B7 的 `testIC100B7SnapshotMatchesRenderDerivations` 注释
/// 立下并登记在案，本卡沿用同一口径（陷阱 13 的「不是对常量断言」由此满足：
/// 断言对象是布局模型算出的**帧**，不是常量本身）。
final class IC146ChromeRoundTwoTests: XCTestCase {

    // MARK: - 断言 1：底排中位的口径模型

    /// 四种情形：有最近相簿／无最近相簿 × 可用／禁用。
    func testIC146A_AlbumTrackPresentationCoversFourCases() {
        let trackEnabled = S2AlbumTrackPresentation(
            recentAlbumName: "旅行",
            recentAlbumEnabled: true,
            addAlbumEnabled: true
        )
        XCTAssertTrue(trackEnabled.isTrack)
        XCTAssertEqual(trackEnabled.separatorCount, 1)
        XCTAssertEqual(trackEnabled.actionBarButtonCount, 4)

        let trackDisabled = S2AlbumTrackPresentation(
            recentAlbumName: "旅行",
            recentAlbumEnabled: false,
            addAlbumEnabled: false
        )
        // 禁用不改变形态——仍是跑道圆、仍恰 1 条分隔线。
        XCTAssertTrue(trackDisabled.isTrack)
        XCTAssertEqual(trackDisabled.separatorCount, 1)
        XCTAssertEqual(trackDisabled.actionBarButtonCount, 4)

        let circleEnabled = S2AlbumTrackPresentation(
            recentAlbumName: nil,
            recentAlbumEnabled: true,
            addAlbumEnabled: true
        )
        // 规格第 3 条：无最近相簿 ⟹ 单一「+」圆钮，且不含分隔线。
        XCTAssertFalse(circleEnabled.isTrack)
        XCTAssertEqual(circleEnabled.separatorCount, 0)
        XCTAssertEqual(circleEnabled.actionBarButtonCount, 3)

        let circleDisabled = S2AlbumTrackPresentation(
            recentAlbumName: nil,
            recentAlbumEnabled: false,
            addAlbumEnabled: false
        )
        XCTAssertFalse(circleDisabled.isTrack)
        XCTAssertEqual(circleDisabled.separatorCount, 0)
        XCTAssertEqual(circleDisabled.actionBarButtonCount, 3)
    }

    /// 形态判定的权威仍是 `S2ActionBarPresentation.showsRecentAlbum`（A4）：
    /// 该字段为假时即便传进相簿名也退化为圆钮。
    func testIC146A_TrackFormFollowsActionBarPresentationAuthority() {
        let machine = makeStateMachine()
        let bar = S2ActionBarPresentation(machine: machine)
        XCTAssertFalse(bar.showsRecentAlbum, "夹具默认无最近相簿")

        let derived = S2AlbumTrackPresentation(
            presentation: bar,
            recentAlbumName: "不该被采纳"
        )
        XCTAssertNil(derived.recentAlbumName)
        XCTAssertFalse(derived.isTrack)

        // A4：三条既有启用规则零语义变化，新增的 shareEnabled 与整排同口径。
        XCTAssertTrue(bar.favoriteEnabled)
        XCTAssertTrue(bar.recentAlbumEnabled)
        XCTAssertTrue(bar.addAlbumEnabled)
        XCTAssertTrue(bar.shareEnabled)
    }

    // MARK: - 断言 2：命中区与按钮数

    func testIC146A_TrackHalvesAndShareCarryTouchTargets() throws {
        // 右半与整只跑道圆的高都不小于最小触控边长。
        XCTAssertGreaterThanOrEqual(
            S2MediaMetrics.albumTrackTrailingHalfWidth,
            S2OverlayLayout.minimumTouchTarget
        )
        XCTAssertGreaterThanOrEqual(
            S2ChromePillMetrics.pillHeight,
            S2OverlayLayout.minimumTouchTarget
        )

        let source = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2View.swift")
        )
        let row = try XCTUnwrap(
            slice(
                source,
                from: "    private var actionBarRow: some View {",
                to: "    private var favoriteActionTitle: String {"
            )
        )
        // 四个动作各一只 Button（收藏、跑道左半、选择器、分享）；
        // 选择器那只由 `albumPickerButton(inTrack:)` 统一提供，
        // 跑道形态与退化形态共用同一个定义，故源码计数恰 4。
        XCTAssertEqual(occurrences(of: "Button {", in: row), 4)

        // 左半给了宽度下限，极短相簿名也不会把命中区挤到 44 以下。
        XCTAssertEqual(
            occurrences(
                of: ".frame(minWidth: S2OverlayLayout.minimumTouchTarget)",
                in: row
            ),
            1
        )
        // 两半与分享各自独立命中。
        XCTAssertGreaterThanOrEqual(
            occurrences(of: ".contentShape(Rectangle())", in: row),
            2
        )
        // 正对照：四个动作的文案 key 各出现恰 1 次，没有第五个动作混进底排。
        for key in [
            "s2.action.add_recent_album",
            "s2.action.add_album",
            "s2.action.share"
        ] {
            XCTAssertEqual(
                occurrences(of: "\"" + key + "\"", in: source),
                1,
                key + " 在 S2View.swift 内不是恰 1 处"
            )
        }
    }

    // MARK: - 断言 3：底排几何不变

    /// 行高、左右边距、底缘锚、`minimumSpacing` 四项逐个核对。
    /// 断言对象是布局模型算出的**帧**（见类注释的口径说明）。
    func testIC146A_ActionBandGeometryUnchanged() {
        let snapshot = overlaySnapshot(showsRecentAlbumAction: true)
        let frames = snapshot.bottomElementFrames
        XCTAssertEqual(frames.count, 4, "三件 + 横栏")
        let leading = frames[0]
        let middle = frames[1]
        let trailing = frames[2]
        let viewportBottom = overlayPhysicalSize.height

        // 行高 44。
        for frame in [leading, middle, trailing] {
            XCTAssertEqual(
                frame.height,
                S2OverlayLayout.chromeRowHeight,
                accuracy: 0.000_001
            )
        }
        // 左右边距 16。
        XCTAssertEqual(
            leading.minX - overlaySafeAreaInsets.leading,
            S2OverlayLayout.chromeHorizontalMargin,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            overlayPhysicalSize.width - overlaySafeAreaInsets.trailing -
                trailing.maxX,
            S2OverlayLayout.chromeHorizontalMargin,
            accuracy: 0.000_001
        )
        // 底缘锚：下缘距视口底 = 安全区底 + 8。
        for frame in [leading, middle, trailing] {
            XCTAssertEqual(
                viewportBottom - frame.maxY,
                S2OverlayLayout.actionBandBottomFromViewportBottom(
                    safeAreaBottom: overlaySafeAreaInsets.bottom
                ),
                accuracy: 0.000_001
            )
        }
        // 件间距 = minimumSpacing。
        XCTAssertEqual(
            middle.minX - leading.maxX,
            S2OverlayLayout.minimumSpacing,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            trailing.minX - middle.maxX,
            S2OverlayLayout.minimumSpacing,
            accuracy: 0.000_001
        )
        // 决策 33 的底部纵向顺序：横栏在底排上方。
        XCTAssertLessThan(frames[3].maxY, leading.minY)
    }

    // MARK: - 断言 5：残影落点 = 跑道圆左半中心

    /// 落点等于左半中心；**且与相簿名长短无关**——跑道圆水平居中于可用区间，
    /// 内容驱动的左半宽在推导中约去。该恒等式不成立即说明居中前提被破坏。
    func testIC146A_AfterimageLandsOnTrackRecentHalfCenter() {
        let viewportSize = overlayPhysicalSize
        let insets = overlaySafeAreaInsets
        let landing = S2AlbumAfterimageFlight.bottomCapsuleCenter(
            viewportSize: viewportSize,
            safeAreaInsets: insets
        )

        // 可用区间 = 两圆钮之间，各留 minimumSpacing。
        let minX = insets.leading
        let maxX = viewportSize.width - insets.trailing
        let slotMinX = minX + S2OverlayLayout.chromeHorizontalMargin +
            S2OverlayLayout.chromeRowHeight + S2OverlayLayout.minimumSpacing
        let slotMaxX = maxX - S2OverlayLayout.chromeHorizontalMargin -
            S2OverlayLayout.chromeRowHeight - S2OverlayLayout.minimumSpacing
        let slotCenterX = (slotMinX + slotMaxX) / 2

        // 不变量：极短与极长相簿名给出同一个左半中心。
        let shortName = S2MediaMetrics.albumTrackRecentHalfCenterX(
            slotMinX: slotMinX,
            slotMaxX: slotMaxX,
            recentHalfWidth: S2OverlayLayout.minimumTouchTarget
        )
        let longName = S2MediaMetrics.albumTrackRecentHalfCenterX(
            slotMinX: slotMinX,
            slotMaxX: slotMaxX,
            recentHalfWidth: 300
        )
        XCTAssertEqual(
            shortName,
            longName,
            accuracy: 0.000_001,
            "落点随相簿名长短漂移 ⟹ 跑道圆的居中前提被破坏"
        )

        // 落点 = 左半中心。
        XCTAssertEqual(landing.x, shortName, accuracy: 0.000_001)
        XCTAssertEqual(
            landing.x,
            slotCenterX + S2MediaMetrics.albumTrackRecentHalfCenterOffsetX,
            accuracy: 0.000_001
        )
        // 正对照：不等于整只跑道圆中心。
        XCTAssertNotEqual(landing.x, slotCenterX, accuracy: 0.5)
        XCTAssertLessThan(landing.x, slotCenterX, "左半在整只中心之左")

        // 纵向锚不变：底排中心距视口底。
        XCTAssertEqual(
            viewportSize.height - landing.y,
            S2OverlayLayout.actionBandCenterFromViewportBottom(
                safeAreaBottom: insets.bottom
            ),
            accuracy: 0.000_001
        )
    }

    // MARK: - 断言 4：分享不改任何状态

    /// 分享呈现态是**视图层状态**，不碰状态机也不碰两台播放 reducer——
    /// 结构上就不可能改 `V`、`s`、`c`、`D` 或播放状态。本断言走完整序列
    /// （按下 → 取到 URL → 关闭）后逐项复核。
    ///
    /// 夹具驱动：真实的系统面板呈现与关闭由 H69 第 2 项兜底（陷阱 1）。
    func testIC146A_ShareLeavesEveryStateUntouched() throws {
        let machine = makeStateMachine()
        _ = machine.handleSwipeUp()
        let visibilityBefore = machine.interfaceVisibility
        let scaleBefore = machine.scale
        let indexBefore = machine.currentIndex
        let pendingBefore = machine.pendingDeletionAssetIDs
        let assetIDBefore = machine.currentAssetID

        let video = S2VideoPlaybackMachine()
        let live = S2LivePhotoPlaybackMachine()
        let videoStatesBefore = video.states
        let liveStatesBefore = live.states

        var preparation = S2SharePreparation()
        XCTAssertFalse(preparation.isResolving)
        XCTAssertFalse(preparation.isPresenting)

        XCTAssertTrue(preparation.begin(assetID: assetIDBefore))
        XCTAssertTrue(preparation.isResolving)
        // 不重入：取项途中再按一次无效。
        XCTAssertFalse(preparation.begin(assetID: assetIDBefore))

        let url = URL(fileURLWithPath: "/tmp/ic146-share-fixture.heic")
        preparation.resolved(assetID: assetIDBefore, url: url)
        XCTAssertTrue(preparation.isPresenting)
        XCTAssertEqual(preparation.payload?.url, url)
        XCTAssertEqual(preparation.payload?.assetID, assetIDBefore)

        preparation.dismiss()
        XCTAssertFalse(preparation.isPresenting)
        XCTAssertFalse(preparation.isResolving)

        // V、s、c、D 逐项不变。
        XCTAssertEqual(machine.interfaceVisibility, visibilityBefore)
        XCTAssertEqual(machine.scale, scaleBefore)
        XCTAssertEqual(machine.currentIndex, indexBefore)
        XCTAssertEqual(machine.pendingDeletionAssetIDs, pendingBefore)
        // 两台播放 reducer 无任何效果产生。
        XCTAssertEqual(video.states, videoStatesBefore)
        XCTAssertEqual(live.states, liveStatesBefore)
        XCTAssertFalse(video.isUnmutedByUser)
    }

    /// 取项失败与「期间翻了页」两条边角：一律回闲置，不呈现面板。
    func testIC146A_ShareDiscardsFailedAndStaleResolutions() {
        var failed = S2SharePreparation()
        XCTAssertTrue(failed.begin(assetID: "asset-1"))
        failed.resolved(assetID: "asset-1", url: nil)
        XCTAssertFalse(failed.isPresenting)
        XCTAssertFalse(failed.isResolving, "取不到就回闲置，可以再按")
        XCTAssertTrue(failed.begin(assetID: "asset-1"))

        var stale = S2SharePreparation()
        XCTAssertTrue(stale.begin(assetID: "asset-1"))
        // 期间翻到了别的资产：迟到的结果一律丢弃，只分享当时那一张。
        stale.resolved(
            assetID: "asset-2",
            url: URL(fileURLWithPath: "/tmp/other.heic")
        )
        XCTAssertFalse(stale.isPresenting)
        XCTAssertTrue(stale.isResolving, "仍在等 asset-1 的结果")
    }

    // MARK: - 夹具

    private let overlayPhysicalSize = CGSize(width: 393, height: 852)
    private let overlaySafeAreaInsets = S2OverlaySafeAreaInsets(
        top: 59,
        leading: 0,
        bottom: 34,
        trailing: 0
    )

    private func overlaySnapshot(
        showsRecentAlbumAction: Bool
    ) -> S2OverlayLayoutSnapshot {
        S2OverlayLayout.snapshot(
            physicalSize: overlayPhysicalSize,
            safeAreaInsets: overlaySafeAreaInsets,
            bottomStripHeight: 64,
            showsRecentAlbumAction: showsRecentAlbumAction,
            calibrationState: S2CalibrationOverlayState.initial
        )
    }

    private func makeStateMachine(
        orderedAssetIDs: [String] = ["asset-1", "asset-2", "asset-3"],
        currentIndex: Int = 1
    ) -> S2StateMachine {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let resolvedIndex = min(max(0, currentIndex), orderedAssetIDs.count - 1)
        return S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-146",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-146",
                    displayName: "IC-146",
                    totalAssetCount: orderedAssetIDs.count
                ),
                orderedAssetIDs: orderedAssetIDs,
                currentAssetID: orderedAssetIDs[resolvedIndex],
                pendingDeletionAssetIDs: [],
                sessionMergedPendingDeletionCountProvider: { 0 }
            ),
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            ),
            parameters: configuration.resolvedParameters!,
            imageRequestStrategy: configuration.imageRequestStrategy,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in }
        )!
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

    private func slice(
        _ source: String,
        from start: String,
        to end: String
    ) -> String? {
        guard let startRange = source.range(of: start),
              let endRange = source.range(
                  of: end,
                  range: startRange.upperBound..<source.endIndex
              ) else {
            return nil
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchStart = haystack.startIndex
        while let found = haystack.range(
            of: needle,
            range: searchStart..<haystack.endIndex
        ) {
            count += 1
            searchStart = found.upperBound
        }
        return count
    }
}
