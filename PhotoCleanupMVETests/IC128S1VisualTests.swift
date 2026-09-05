import XCTest
@testable import PhotoCleanupMVE

/// IC-128：S1 视觉层（chrome、缩略图范围项、菜单与受限提示条、四态）。
/// 视觉断言走展示口径模型（S1ChromeBarModel 等），不驱动 SwiftUI 渲染——
/// 渲染观感由 H57 真机判定兜底。
final class IC128S1VisualTests: XCTestCase {
    // MARK: - A：顶排 chrome

    // 三件 chrome 的存在与禁用态：S1-1 全部降 40% 并禁用（垃圾桶与徽标照常
    // 显示、不可触发）；S1-3 垃圾桶禁用且徽标不显示；就绪态徽标为 0 时不显示
    // 且入口禁用。
    func testIC128A_ChromeBarStatesFollowLoadingEmptyReady() {
        let loading = S1ChromeBarModel.make(state: .loading, badgeCount: 2)
        XCTAssertFalse(loading.controlsEnabled)
        XCTAssertEqual(loading.controlsOpacity, 0.4)
        XCTAssertFalse(loading.trashEnabled)
        XCTAssertEqual(loading.badgeText, "2")

        let readyZero = S1ChromeBarModel.make(state: .ready, badgeCount: 0)
        XCTAssertTrue(readyZero.controlsEnabled)
        XCTAssertEqual(readyZero.controlsOpacity, 1)
        XCTAssertFalse(readyZero.trashEnabled)
        XCTAssertNil(readyZero.badgeText)

        let readyMarked = S1ChromeBarModel.make(state: .ready, badgeCount: 3)
        XCTAssertTrue(readyMarked.trashEnabled)
        XCTAssertEqual(readyMarked.badgeText, "3")

        let empty = S1ChromeBarModel.make(state: .empty, badgeCount: 2)
        XCTAssertTrue(empty.controlsEnabled)
        XCTAssertFalse(empty.trashEnabled)
        XCTAssertNil(empty.badgeText)

        let failed = S1ChromeBarModel.make(state: .failed, badgeCount: 2)
        XCTAssertTrue(failed.controlsEnabled)
        XCTAssertTrue(failed.trashEnabled)
        XCTAssertEqual(failed.badgeText, "2")
    }

    // 徽标数值 = D_全部（跨范围并集），与状态机 badgeCount 同源。
    func testIC128A_BadgeValueEqualsMergedPendingCount() {
        var store = SessionStore(sessionID: "会话-128A")
        store.setMarked(true, assetID: "a1", rangeID: "r1")
        store.setMarked(true, assetID: "a2", rangeID: "r1")
        store.setMarked(true, assetID: "a2", rangeID: "r2")
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        XCTAssertEqual(machine.badgeCount, 2)
        let model = S1ChromeBarModel.make(
            state: .ready,
            badgeCount: machine.badgeCount
        )
        XCTAssertEqual(model.badgeText, "2")
    }

    // 中胶囊副行口径：总数 = 范围资产并集（重叠不重复计），范围数 = 范围项总数。
    func testIC128A_CapsuleSubtitleCountsUnionAndRangeCount() {
        let ranges = [
            S1Range(
                id: "year",
                displayName: "2026",
                assetIDsNewestFirst: ["a3", "a2", "a1"]
            ),
            S1Range(
                id: "month",
                displayName: "2026-08",
                assetIDsNewestFirst: ["a3", "a2", "a1"],
                parentRangeID: "year"
            ),
            S1Range(
                id: "相册-1",
                displayName: "名称-相册-1",
                assetIDsNewestFirst: ["a1", "b1"]
            )
        ]
        let counts = S1ChromeSubtitle.counts(for: ranges)
        XCTAssertEqual(counts.assetCount, 4)
        XCTAssertEqual(counts.rangeCount, 3)
        let emptyCounts = S1ChromeSubtitle.counts(for: [])
        XCTAssertEqual(emptyCounts.assetCount, 0)
        XCTAssertEqual(emptyCounts.rangeCount, 0)
    }

    // 取值表转录钉住：v18 §11.2 的 chrome 取值与推导量恒等式。
    func testIC128A_ChromeMetricsMatchSpecSection11Part2() {
        XCTAssertEqual(S1ChromeLayout.rowHeight, 44)
        XCTAssertEqual(S1ChromeLayout.topRowTopInset, 3)
        XCTAssertEqual(S1ChromeLayout.horizontalMargin, 16)
        XCTAssertEqual(S1ChromeLayout.itemSpacing, 8)
        XCTAssertEqual(S1ChromeGlass.tintOpacity, 0.03)
        XCTAssertEqual(S1ChromeGlass.innerHighlightTop, 0.30)
        XCTAssertEqual(S1ChromeGlass.innerHighlightBottom, 0.06)
        XCTAssertEqual(S1ChromeGlass.innerStrokeWidth, 1)
        XCTAssertEqual(S1ChromeGlass.outerRingOpacity, 0.12)
        XCTAssertEqual(S1ChromeGlass.outerStrokeWidth, 0.5)
        XCTAssertEqual(S1ChromeTypography.titleFontSize, 15)
        XCTAssertEqual(S1ChromeTypography.subtitleFontSize, 11.5)
        XCTAssertEqual(S1ChromeTypography.circleIconPointSize, 17)
        XCTAssertEqual(S1NotificationBadgeStyle.fontSize, 12)
        XCTAssertEqual(S1NotificationBadgeStyle.minDiameter, 18)
        XCTAssertEqual(S1NotificationBadgeStyle.horizontalPadding, 5)
        XCTAssertEqual(S1NotificationBadgeStyle.ringWidth, 1.5)

        // 画布「距屏顶」值的推导量恒等式（安全区顶 59 基准）：
        // 114 = 59 + 3 + 44 + 8；122 = 59 + 3 + 44 + 16；174 = 59 + 55 + 44 + 16。
        XCTAssertEqual(
            S1ChromeLayout.overlayTopOffset,
            S1ChromeLayout.topRowTopInset
                + S1ChromeLayout.rowHeight
                + S1ChromeLayout.chromeToOverlaySpacing
        )
        XCTAssertEqual(
            S1ChromeLayout.listTopOffset,
            S1ChromeLayout.topRowTopInset
                + S1ChromeLayout.rowHeight
                + S1ChromeLayout.chromeToListSpacing
        )
        XCTAssertEqual(
            S1ChromeLayout.limitedListTopOffset,
            S1ChromeLayout.overlayTopOffset
                + S1ChromeLayout.rowHeight
                + S1ChromeLayout.bannerToListSpacing
        )
        XCTAssertEqual(S1ChromeLayout.overlayTopOffset + 59, 114)
        XCTAssertEqual(S1ChromeLayout.listTopOffset + 59, 122)
        XCTAssertEqual(S1ChromeLayout.limitedListTopOffset + 59, 174)
    }
}
