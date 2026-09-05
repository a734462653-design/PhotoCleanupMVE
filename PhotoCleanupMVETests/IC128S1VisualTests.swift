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

    // MARK: - B：范围项

    // 封面取图规则：按当前 O 的首张；O 翻转后封面跟着换；年节点递归取首个
    // 子范围的封面。
    func testIC128B_CoverFollowsCurrentSortOrderAndFlips() {
        let ranges = [
            S1Range(
                id: "year",
                displayName: "2026",
                assetIDsNewestFirst: ["a4", "a3", "a2", "a1"]
            ),
            S1Range(
                id: "month-9",
                displayName: "2026-09",
                assetIDsNewestFirst: ["a4", "a3"],
                parentRangeID: "year"
            ),
            S1Range(
                id: "month-8",
                displayName: "2026-08",
                assetIDsNewestFirst: ["a2", "a1"],
                parentRangeID: "year"
            )
        ]
        XCTAssertEqual(
            S1RangeCoverPolicy.coverAssetID(
                forRangeID: "month-8",
                in: ranges,
                sortOrder: .newestFirst
            ),
            "a2"
        )
        XCTAssertEqual(
            S1RangeCoverPolicy.coverAssetID(
                forRangeID: "month-8",
                in: ranges,
                sortOrder: .oldestFirst
            ),
            "a1"
        )
        // 年节点：O=最新在前 → 首个子范围是 9 月，其首张 a4；
        // O=最旧在前 → 首个子范围是 8 月，其首张 a1。
        XCTAssertEqual(
            S1RangeCoverPolicy.coverAssetID(
                forRangeID: "year",
                in: ranges,
                sortOrder: .newestFirst
            ),
            "a4"
        )
        XCTAssertEqual(
            S1RangeCoverPolicy.coverAssetID(
                forRangeID: "year",
                in: ranges,
                sortOrder: .oldestFirst
            ),
            "a1"
        )
        XCTAssertNil(
            S1RangeCoverPolicy.coverAssetID(
                forRangeID: "不存在",
                in: ranges,
                sortOrder: .newestFirst
            )
        )
    }

    // 请求口径：目标尺寸按 56pt × 屏幕 scale。
    func testIC128B_CoverTargetPixelSizeFollowsDisplayScale() {
        XCTAssertEqual(
            S1RangeCoverPolicy.targetPixelSize(displayScale: 2),
            CGSize(width: 112, height: 112)
        )
        XCTAssertEqual(
            S1RangeCoverPolicy.targetPixelSize(displayScale: 3),
            CGSize(width: 168, height: 168)
        )
    }

    // 只升不降：降质 → 最终允许替换；最终不被降质覆盖；nil 只在尚无图时落占位。
    func testIC128B_CoverReplacementNeverDowngrades() {
        XCTAssertTrue(
            S1CoverImagePhase.shouldReplace(
                current: .loading,
                incomingIsDegraded: true,
                incomingIsNil: false
            )
        )
        XCTAssertTrue(
            S1CoverImagePhase.shouldReplace(
                current: .degraded,
                incomingIsDegraded: false,
                incomingIsNil: false
            )
        )
        XCTAssertFalse(
            S1CoverImagePhase.shouldReplace(
                current: .final,
                incomingIsDegraded: true,
                incomingIsNil: false
            )
        )
        XCTAssertTrue(
            S1CoverImagePhase.shouldReplace(
                current: .final,
                incomingIsDegraded: false,
                incomingIsNil: false
            )
        )
        // 取不到图（nil）：无图可展示时落占位；已有图（含降质）不回退。
        XCTAssertTrue(
            S1CoverImagePhase.shouldReplace(
                current: .loading,
                incomingIsDegraded: false,
                incomingIsNil: true
            )
        )
        XCTAssertFalse(
            S1CoverImagePhase.shouldReplace(
                current: .degraded,
                incomingIsDegraded: false,
                incomingIsNil: true
            )
        )
        XCTAssertFalse(
            S1CoverImagePhase.shouldReplace(
                current: .final,
                incomingIsDegraded: false,
                incomingIsNil: true
            )
        )
    }

    // 进度线：填充比例 = 已处理 / 总数（钳到 [0,1]）；范围未开始（r.id 不在 K 中）
    // 整条不画。
    func testIC128B_ProgressLineFractionAndVisibility() {
        XCTAssertEqual(
            S1ProgressLinePresentation.fillFraction(processed: 0, total: 10),
            0
        )
        XCTAssertEqual(
            S1ProgressLinePresentation.fillFraction(processed: 5, total: 10),
            0.5
        )
        XCTAssertEqual(
            S1ProgressLinePresentation.fillFraction(processed: 10, total: 10),
            1
        )
        XCTAssertEqual(
            S1ProgressLinePresentation.fillFraction(processed: 12, total: 10),
            1
        )
        XCTAssertEqual(
            S1ProgressLinePresentation.fillFraction(processed: 3, total: 0),
            0
        )
        XCTAssertFalse(
            S1ProgressLinePresentation.isVisible(hasContinuation: false)
        )
        XCTAssertTrue(
            S1ProgressLinePresentation.isVisible(hasContinuation: true)
        )
    }

    // 待删红点显隐口径：零待删不画。
    func testIC128B_PendingBadgeHiddenAtZero() {
        XCTAssertNil(S1PendingBadgePresentation.text(count: 0))
        XCTAssertEqual(S1PendingBadgePresentation.text(count: 1), "1")
        XCTAssertEqual(S1PendingBadgePresentation.text(count: 12), "12")
    }

    // 展开区与进入区是两个不同目标：展开区仅年节点持有；月行内容左缩进 52；
    // 展开／收起不产生 S2 交接（机器侧行为复核）。
    func testIC128B_YearRowHasSeparateExpandAndEnterTargets() {
        XCTAssertTrue(S1RangeCardPresentation.hasExpandZone(childCount: 2))
        XCTAssertFalse(S1RangeCardPresentation.hasExpandZone(childCount: 0))
        XCTAssertEqual(
            S1RangeCardPresentation.leadingInset(isChildRow: true),
            52
        )
        XCTAssertEqual(
            S1RangeCardPresentation.leadingInset(isChildRow: false),
            12
        )

        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-128B"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "year",
                        displayName: "2026",
                        assetIDsNewestFirst: ["a1"]
                    ),
                    S1Range(
                        id: "month",
                        displayName: "2026-08",
                        assetIDsNewestFirst: ["a1"],
                        parentRangeID: "year"
                    )
                ]),
                for: request
            )
        )
        let yearRowBefore = tryUnwrap(
            machine.rangeRows.first { $0.id == "year" }
        )
        XCTAssertTrue(yearRowBefore.isExpanded)
        XCTAssertTrue(machine.toggleYearExpansion("year"))
        let yearRowAfter = tryUnwrap(
            machine.rangeRows.first { $0.id == "year" }
        )
        XCTAssertFalse(yearRowAfter.isExpanded)
        // 展开／收起动作本身不构成进入：交接仍须显式调用且仍可用。
        XCTAssertNotNil(machine.makeS2Handoff(for: "year"))
    }

    // MARK: - C：菜单与受限提示条

    // 两菜单互斥：同一时刻只能开一个；开一个即关另一个；再点已开的关闭。
    func testIC128C_MenusAreMutuallyExclusive() {
        XCTAssertEqual(S1ActiveMenu.none.toggling(.sort), .sort)
        XCTAssertEqual(S1ActiveMenu.none.toggling(.dimension), .dimension)
        XCTAssertEqual(S1ActiveMenu.sort.toggling(.dimension), .dimension)
        XCTAssertEqual(S1ActiveMenu.dimension.toggling(.sort), .sort)
        XCTAssertEqual(S1ActiveMenu.sort.toggling(.sort), .none)
        XCTAssertEqual(S1ActiveMenu.dimension.toggling(.dimension), .none)
    }

    // 维度菜单提示口径：按日期固定结构提示；相册 N 个、未分类 N 张；读不到即
    // 不显示提示。
    func testIC128C_DimensionMenuHintsFollowReadState() {
        XCTAssertEqual(
            S1DimensionMenuHintModel.make(
                for: .date,
                albumRangeCount: nil,
                unclassifiedAssetCount: nil
            ),
            .dateStructure
        )
        XCTAssertEqual(
            S1DimensionMenuHintModel.make(
                for: .album,
                albumRangeCount: 3,
                unclassifiedAssetCount: nil
            ),
            .albumCount(3)
        )
        XCTAssertEqual(
            S1DimensionMenuHintModel.make(
                for: .album,
                albumRangeCount: nil,
                unclassifiedAssetCount: 42
            ),
            .unavailable
        )
        XCTAssertEqual(
            S1DimensionMenuHintModel.make(
                for: .unclassified,
                albumRangeCount: nil,
                unclassifiedAssetCount: 42
            ),
            .unclassifiedCount(42)
        )
        XCTAssertEqual(
            S1DimensionMenuHintModel.make(
                for: .unclassified,
                albumRangeCount: 3,
                unclassifiedAssetCount: nil
            ),
            .unavailable
        )
    }

    // 受限提示条显隐与列表起始：受限 + 列表在场（就绪／空态）才挂条；
    // 列表起始 63 → 115（画布 122 → 174）。
    func testIC128C_LimitedBannerVisibilityAndListTopOffset() {
        XCTAssertTrue(
            S1LimitedBannerPresentation.isVisible(
                isLimitedAuthorization: true,
                state: .ready
            )
        )
        XCTAssertTrue(
            S1LimitedBannerPresentation.isVisible(
                isLimitedAuthorization: true,
                state: .empty
            )
        )
        XCTAssertFalse(
            S1LimitedBannerPresentation.isVisible(
                isLimitedAuthorization: true,
                state: .loading
            )
        )
        XCTAssertFalse(
            S1LimitedBannerPresentation.isVisible(
                isLimitedAuthorization: true,
                state: .failed
            )
        )
        XCTAssertFalse(
            S1LimitedBannerPresentation.isVisible(
                isLimitedAuthorization: false,
                state: .ready
            )
        )
        XCTAssertEqual(
            S1LimitedBannerPresentation.listTopOffset(bannerVisible: false),
            S1ChromeLayout.listTopOffset
        )
        XCTAssertEqual(
            S1LimitedBannerPresentation.listTopOffset(bannerVisible: true),
            S1ChromeLayout.limitedListTopOffset
        )
    }

    // MARK: - D：四态与文案

    // 四态各自的元素清单：S1-1 降暗禁用 chrome + 进度指示 + 一行文案；
    // S1-3 图标 + 主句、无按钮；S1-4 授权类给「打开系统设置」不给重试，
    // 读取类给「重试」。
    func testIC128D_StateLayoutsMatchElementInventory() {
        XCTAssertEqual(
            S1StateLayout.elements(state: .loading, failureCategory: nil),
            [.dimmedDisabledChrome, .progressIndicator, .loadingText]
        )
        XCTAssertEqual(
            S1StateLayout.elements(state: .ready, failureCategory: nil),
            []
        )
        XCTAssertEqual(
            S1StateLayout.elements(state: .empty, failureCategory: nil),
            [.emptyIcon, .emptyText]
        )
        let authorization = S1StateLayout.elements(
            state: .failed,
            failureCategory: .authorization
        )
        XCTAssertEqual(
            authorization,
            [
                .authorizationIcon,
                .authorizationTitle,
                .authorizationSubtitle,
                .openSettingsButton
            ]
        )
        XCTAssertFalse(authorization.contains(.retryButton))
        let read = S1StateLayout.elements(
            state: .failed,
            failureCategory: .read
        )
        XCTAssertEqual(
            read,
            [
                .readFailureIcon,
                .readFailureTitle,
                .readFailureSubtitle,
                .retryButton
            ]
        )
        XCTAssertFalse(read.contains(.openSettingsButton))
    }

    // 登记项清除：item05/06/07/10/12/15 已随本卡定案移除，item16/17 保留；
    // 产品源码不再引用 s1.placeholder.* 占位 key。
    func testIC128D_UndecidedVisualItemsAndPlaceholderKeysCleared() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let coreText = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "PhotoCleanupMVE/Core/S1StateMachine.swift"
            ),
            encoding: .utf8
        )
        for clearedItem in [
            "item05LongNameTruncation",
            "item06ZeroPendingAndProgressPresentation",
            "item07EmptyMergedDeletionTrashPresentation",
            "item10LoadingIndicator",
            "item12S2ReturnValidationFailurePresentation",
            "item15EmptyAndFailureCopy"
        ] {
            XCTAssertFalse(coreText.contains(clearedItem), clearedItem)
        }
        XCTAssertTrue(coreText.contains("item16RecommendedCleanupArea"))
        XCTAssertTrue(coreText.contains("item17FileSizeSort"))

        for productFile in [
            "PhotoCleanupMVE/Core/S1StateMachine.swift",
            "PhotoCleanupMVE/Features/S1/S1View.swift"
        ] {
            let text = try String(
                contentsOf: repoRoot.appendingPathComponent(productFile),
                encoding: .utf8
            )
            XCTAssertFalse(text.contains("s1.placeholder."), productFile)
        }
    }

    // MARK: - Fixtures

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        do {
            return try XCTUnwrap(value, file: file, line: line)
        } catch {
            XCTFail(String(describing: error), file: file, line: line)
            preconditionFailure()
        }
    }
}
