import Photos
import XCTest
@testable import PhotoCleanupMVE

/// IC-134 A～D：S3 确认页视觉层。
///
/// 视觉断言走展示口径模型（S3ChromeBarModel、S3CellBadgeModel、S3ActionBarModel 等），
/// 不驱动 SwiftUI 渲染——渲染观感由 H60 真机判定兜底（陷阱 1）。
final class IC134S3VisualTests: XCTestCase {
    // MARK: - A：顶排 chrome、三态骨架、副行

    // 断言 1：chrome 取值是对 S1 已登记常量的**引用**，不是「碰巧相等的字面量」。
    // 比对对象一律是 S1 的常量本身，测试里不出现 44／16／15 这类数值。
    func testIC134A_ChromeMetricsReferenceS1RegisteredConstants() {
        XCTAssertEqual(S3ChromeMetrics.rowHeight, S1ChromeLayout.rowHeight)
        XCTAssertEqual(
            S3ChromeMetrics.topRowTopInset,
            S1ChromeLayout.topRowTopInset
        )
        XCTAssertEqual(
            S3ChromeMetrics.horizontalMargin,
            S1ChromeLayout.horizontalMargin
        )
        XCTAssertEqual(S3ChromeMetrics.itemSpacing, S1ChromeLayout.itemSpacing)
        XCTAssertEqual(
            S3ChromeMetrics.titleFontSize,
            S1ChromeTypography.titleFontSize
        )
        XCTAssertEqual(
            S3ChromeMetrics.subtitleFontSize,
            S1ChromeTypography.subtitleFontSize
        )
        XCTAssertEqual(
            S3ChromeMetrics.circleIconPointSize,
            S1ChromeTypography.circleIconPointSize
        )
        // 空态版式同样引用 S1 的四态常量。
        XCTAssertEqual(
            S3EmptyStateMetrics.iconPointSize,
            S1StatePlaceholderStyle.iconPointSize
        )
        XCTAssertEqual(
            S3EmptyStateMetrics.titleFontSize,
            S1StatePlaceholderStyle.titleFontSize
        )
        // 操作条底距引用 S2 已登记的底距，不另起一个 8。
        XCTAssertEqual(
            S3PageLayout.listBottomClearance,
            S3ActionBarMetrics.height
                + S2OverlayLayout.bottomRowBottomInset
                + S3PageLayout.listToActionBarSpacing
        )
        // 移除角标命中区引用 S2 已登记的最小触控带。
        XCTAssertEqual(
            S3CellBadgeMetrics.removeHitTarget,
            S2OverlayLayout.minimumTouchTarget
        )
    }

    // 断言 2：三态元素清单。S3-4 无操作条、无提示句；S3-1／S3-2 四件齐。
    func testIC134A_StateElementsFollowThreeStateLayout() {
        XCTAssertEqual(
            S3StatePresentation.elements(for: .scanning),
            [.chrome, .recentlyDeletedNotice, .groupCards, .actionBar]
        )
        XCTAssertEqual(
            S3StatePresentation.elements(for: .ready),
            [.chrome, .recentlyDeletedNotice, .groupCards, .actionBar]
        )
        XCTAssertEqual(
            S3StatePresentation.elements(for: .empty),
            [.chrome, .emptyIcon, .emptyTitle]
        )
        XCTAssertTrue(S3StatePresentation.showsActionBar(for: .scanning))
        XCTAssertTrue(S3StatePresentation.showsActionBar(for: .ready))
        XCTAssertFalse(S3StatePresentation.showsActionBar(for: .empty))
        XCTAssertFalse(
            S3StatePresentation.showsRecentlyDeletedNotice(for: .empty)
        )
    }

    // 断言 3：副行**只**取 IC-133 的格式串类型，不另起一个格式串。
    func testIC134A_ChromeSubtitleComesFromIC133HeaderSubtitle() {
        let model = S3ChromeBarModel.make(assetCount: 7, rangeCount: 3)
        XCTAssertEqual(
            model.subtitle,
            S3HeaderSubtitle.text(assetCount: 7, rangeCount: 3)
        )
        XCTAssertEqual(model.title, L10n.text("s3.chrome.title"))
        // 空集时副行是「0 张 · 来自 0 个范围」，仍走同一格式串。
        XCTAssertEqual(
            S3ChromeBarModel.make(assetCount: 0, rangeCount: 0).subtitle,
            S3HeaderSubtitle.text(assetCount: 0, rangeCount: 0)
        )
    }

    // MARK: - B：分组网格、角标、移除

    // 断言 4：网格按 IC-133 的过滤序生成，空组不生成。
    func testIC134B_GridRowsFollowIC133FilteredOrderAndSkipEmptyGroups() {
        let groups = [
            makeGroup("范围-A", ids: ["a-1", "a-2", "a-3", "a-4"]),
            makeGroup("范围-B", ids: ["b-1"]),
            makeGroup("范围-C", ids: ["c-1", "c-2"])
        ]
        let machine = S3StateMachine(assets: descriptors(groups))
        // 把 范围-B 整组移除。
        XCTAssertTrue(machine.removeAsset(identifier: "b-1"))

        let presentation = S3GroupPresentation.make(
            groups: groups,
            currentAssets: machine.assets
        )
        // 空组不生成，其余保持原序。
        XCTAssertEqual(
            presentation.groups.map(\.sourceRangeID),
            ["范围-A", "范围-C"]
        )

        // 网格按 3 列分行，行内顺序即该组过滤后的顺序。
        let rowsA = S3GridRows.rows(presentation.groups[0].orderedAssets)
        XCTAssertEqual(rowsA.count, 2)
        XCTAssertEqual(rowsA[0].map(\.identifier), ["a-1", "a-2", "a-3"])
        XCTAssertEqual(rowsA[1].map(\.identifier), ["a-4"])

        let rowsC = S3GridRows.rows(presentation.groups[1].orderedAssets)
        XCTAssertEqual(rowsC.count, 1)
        XCTAssertEqual(rowsC[0].map(\.identifier), ["c-1", "c-2"])

        // 格宽由卡宽反解：三列等宽 + 两道 3 间距 + 左右各 3 内边距。
        XCTAssertEqual(S3GridMetrics.cellWidth(cardWidth: 300), 96)
    }

    // 断言 5：角标口径——♡ 只在收藏时；标签文本三种来源。
    // IC-136 A 后标签只显示总量，展开段已随字段一并删除。
    func testIC134B_CellBadgeModelCoversFavoriteVolumeTextAndChevron() {
        let favorite = AssetDescriptor(identifier: "a", isFavorite: true)
        let plain = AssetDescriptor(identifier: "b", isFavorite: false)

        XCTAssertTrue(
            S3CellBadgeModel.make(
                asset: favorite,
                conclusion: .knownBytes(3_100_000)
            ).showsFavorite
        )
        XCTAssertFalse(
            S3CellBadgeModel.make(
                asset: plain,
                conclusion: .knownBytes(3_100_000)
            ).showsFavorite
        )

        // 已知 → DecimalVolumeFormatter。
        XCTAssertEqual(
            S3CellBadgeModel.make(
                asset: plain,
                conclusion: .knownBytes(3_100_000)
            ).volumeText,
            DecimalVolumeFormatter.string(forByteCount: 3_100_000)
        )
        // 不可用 →「—」。
        XCTAssertEqual(
            S3CellBadgeModel.make(
                asset: plain,
                conclusion: .unavailable
            ).volumeText,
            L10n.text("s3.cell.volume_unavailable")
        )
        // 未开始／进行中 →「…」。
        for conclusion in [AssetScanConclusion.notStarted, .inProgress] {
            XCTAssertEqual(
                S3CellBadgeModel.make(
                    asset: plain,
                    conclusion: conclusion
                ).volumeText,
                L10n.text("s3.cell.volume_pending")
            )
        }
    }

    // 断言 6：点 ⊖ 调 removeAsset 恰一次；冻结后不响应。
    func testIC134B_RemoveBadgeCallsRemoveOnceAndIsInertAfterFreeze() {
        var calls = 0
        S3RemoveButtonAction.perform(isFrozen: false) { calls += 1 }
        XCTAssertEqual(calls, 1)

        S3RemoveButtonAction.perform(isFrozen: true) { calls += 1 }
        XCTAssertEqual(calls, 1, "冻结快照后 ⊖ 不得再调下游")
    }

    // 断言 7：封面请求尺寸 = 格宽 × 倍率，2× 与 3× 各验一次。
    func testIC134B_CoverRequestPixelSizeFollowsDisplayScale() {
        let cellWidth = S3GridMetrics.cellWidth(cardWidth: 300)
        XCTAssertEqual(
            ThumbnailView.targetPixelSize(
                sideLength: cellWidth,
                displayScale: 2
            ),
            CGSize(width: cellWidth * 2, height: cellWidth * 2)
        )
        XCTAssertEqual(
            ThumbnailView.targetPixelSize(
                sideLength: cellWidth,
                displayScale: 3
            ),
            CGSize(width: cellWidth * 3, height: cellWidth * 3)
        )
    }

    // MARK: - D：操作条

    // 断言 11：操作条口径——扫描中／精确／下界，以及 canSubmit ↔ 删除可用。
    func testIC134D_ActionBarModelCoversScanningExactAndLowerBound() {
        // 扫描中：主行「正在计算…」+ 副行「已知 X」。
        let scanning = S3StateMachine(assets: [descriptor("a"), descriptor("b")])
        XCTAssertEqual(scanning.state, .scanning)
        let scanningModel = S3ActionBarModel.make(machine: scanning)
        XCTAssertTrue(scanningModel.volume.isScanning)
        XCTAssertEqual(
            scanningModel.volume,
            .scanning(
                primary: L10n.text("s3.bar.scanning"),
                knownSoFar: L10n.text(
                    "s3.bar.known_so_far",
                    replacing: [
                        "known": DecimalVolumeFormatter.string(
                            forByteCount: scanning.knownTotalBytes
                        )
                    ]
                )
            )
        )
        XCTAssertFalse(scanningModel.submitEnabled, "扫描中不得可提交")
        XCTAssertEqual(scanningModel.submitEnabled, scanning.canSubmit)

        // 就绪且全部已知：精确值，无副行。
        let exact = S3StateMachine(
            assets: [descriptor("a"), descriptor("b")],
            cachedConclusions: [
                "a": .knownBytes(20_000_000),
                "b": .knownBytes(3_500_000)
            ]
        )
        XCTAssertEqual(exact.state, .ready)
        let exactModel = S3ActionBarModel.make(machine: exact)
        XCTAssertEqual(
            exactModel.volume,
            .exact(
                L10n.text(
                    "s3.bar.volume_exact",
                    replacing: [
                        "known": DecimalVolumeFormatter.string(
                            forByteCount: 23_500_000
                        )
                    ]
                )
            )
        )
        XCTAssertTrue(exactModel.submitEnabled)
        XCTAssertEqual(exactModel.submitEnabled, exact.canSubmit)
        XCTAssertEqual(
            exactModel.submitTitle,
            L10n.text("s3.action.delete_count", replacing: ["count": "2"])
        )

        // 就绪但有不可用项：下界值 + 旁注。
        let lowerBound = S3StateMachine(
            assets: [descriptor("a"), descriptor("b")],
            cachedConclusions: [
                "a": .knownBytes(23_500_000),
                "b": .unavailable
            ]
        )
        XCTAssertEqual(lowerBound.state, .ready)
        let lowerModel = S3ActionBarModel.make(machine: lowerBound)
        XCTAssertEqual(
            lowerModel.volume,
            .lowerBound(
                primary: L10n.text(
                    "s3.bar.volume_lower_bound",
                    replacing: [
                        "known": DecimalVolumeFormatter.string(
                            forByteCount: 23_500_000
                        )
                    ]
                ),
                unavailableNote: L10n.text(
                    "s3.bar.unavailable_count",
                    replacing: ["count": "1"]
                )
            )
        )
    }

    // 断言 12：「全部取消」走 IC-133 的两步动作类型，不另起一套状态。
    func testIC134D_CancelAllGoesThroughIC133TwoStepAction() {
        let machine = S3StateMachine(assets: [descriptor("a")])
        let model = S3ActionBarModel.make(machine: machine)
        XCTAssertEqual(
            model.cancelAllEnabled,
            S3CancelAllAction.isAvailable(
                assetCount: machine.assetCount,
                isFrozen: machine.frozenSnapshot != nil
            )
        )

        var action = S3CancelAllAction()
        XCTAssertFalse(action.isAwaitingConfirmation)
        XCTAssertTrue(action.request(assetCount: 1, isFrozen: false))
        XCTAssertTrue(action.isAwaitingConfirmation)

        var cleared = 0
        XCTAssertTrue(action.confirm { cleared += 1 })
        XCTAssertEqual(cleared, 1)
        XCTAssertFalse(action.isAwaitingConfirmation)

        // 空集不可用。
        var empty = S3CancelAllAction()
        XCTAssertFalse(empty.request(assetCount: 0, isFrozen: false))
    }

    // 断言 13：删除按钮调 submitDeletion 恰一次；禁用时不调。
    func testIC134D_SubmitButtonCallsDownstreamOnceAndNotWhenDisabled() {
        var calls = 0
        S3SubmitButtonAction.perform(isEnabled: true) { calls += 1 }
        XCTAssertEqual(calls, 1)

        S3SubmitButtonAction.perform(isEnabled: false) { calls += 1 }
        XCTAssertEqual(calls, 1, "canSubmit 为假时不得调下游")
    }

    // 断言 14：本卡引用的 S3 key 全部在目录里（孤儿方向由扫描器覆盖）。
    func testIC134D_EveryS3KeyResolvesInCatalog() {
        let keys = [
            "s3.chrome.title",
            "s3.chrome.subtitle_format",
            "s3.confirmation.recently_deleted_notice",
            "s3.state.empty",
            "s3.group.count_format",
            "s3.cell.volume_unavailable",
            "s3.cell.volume_pending",
            "s3.cell.remove.accessibility",
            "s3.cell.favorite.accessibility",
            "s3.action.back",
            "s3.action.cancel_all",
            "s3.action.delete_count",
            "s3.bar.scanning",
            "s3.bar.known_so_far",
            "s3.bar.volume_exact",
            "s3.bar.volume_lower_bound",
            "s3.bar.unavailable_count",
            "s3.cancel_all.confirm.title",
            "s3.cancel_all.confirm.action"
        ]
        for key in keys {
            XCTAssertNotEqual(L10n.text(key), key, "目录里缺 \(key)")
        }
        // 空态主句已补句号。
        XCTAssertEqual(L10n.text("s3.state.empty"), "没有待删除照片。")
    }

    // MARK: - IC-136 A：撤销体积明细

    // 断言 1：角标模型只剩「是否收藏」与「体积文本」两个字段——展开与箭头字段
    // 已随本卡删除。用 Mirror 逐字段列出，避免「加了默认值仍能编译」的漏网。
    func testIC136A_CellBadgeModelHasNoChevronOrExpansionFields() {
        let model = S3CellBadgeModel.make(
            asset: AssetDescriptor(identifier: "a", isFavorite: false),
            conclusion: .knownBytes(3_100_000)
        )
        let fields = Mirror(reflecting: model).children.compactMap(\.label)
        XCTAssertEqual(fields, ["showsFavorite", "volumeText"])

        // 三种来源之外没有第四种：已知走格式化器，其余两态各自取目录文案。
        XCTAssertEqual(
            model.volumeText,
            DecimalVolumeFormatter.string(forByteCount: 3_100_000)
        )
    }

    // 断言 2：产品源码不再引用扫描侧通道与展开口径的任何一个符号。
    func testIC136A_ProductSourceNoLongerReferencesRemovedSymbols() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let productFiles = [
            "PhotoCleanupMVE/Features/S3/S3View.swift",
            "PhotoCleanupMVE/Services/AssetSizeScanner.swift",
            "PhotoCleanupMVE/App/CleanupCoordinator.swift",
            "PhotoCleanupMVE/Core/S3StateMachine.swift"
        ]
        // 拼接构造，源码里不出现完整名字（否则本断言会抓到自己的注释）。
        let removed = [
            "scan" + "WithBreakdown",
            "AssetScan" + "Outcome",
            "AssetSize" + "BreakdownItem",
            "S3Detail" + "Expansion",
            "scanBreakdown" + "ItemCount"
        ]
        for relativePath in productFiles {
            let text = try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            for symbol in removed {
                XCTAssertFalse(
                    text.contains(symbol),
                    "\(relativePath) 仍引用 \(symbol)"
                )
            }
        }
    }

    // 断言 4：四个种类 key 已从目录删除，产品源码也不再引用该前缀——
    // 既无孤儿 key，也无缺 key（剩余 key 的可解析性由
    // testIC134D_EveryS3KeyResolvesInCatalog 逐条覆盖）。
    func testIC136A_DetailKindKeysRemovedFromCatalogAndSource() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalog = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "PhotoCleanupMVE/Localizable.xcstrings"
            ),
            encoding: .utf8
        )
        let prefix = "s3." + "detail."
        XCTAssertFalse(catalog.contains(prefix), "目录里仍有该前缀的孤儿 key")

        for relativePath in [
            "PhotoCleanupMVE/Features/S3/S3View.swift",
            "PhotoCleanupMVE/App/CleanupCoordinator.swift"
        ] {
            let text = try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            XCTAssertFalse(text.contains(prefix), relativePath)
        }
    }

    // MARK: - 夹具

    private func descriptor(_ identifier: String) -> AssetDescriptor {
        AssetDescriptor(identifier: identifier, isFavorite: false)
    }

    private func makeGroup(
        _ rangeID: String,
        ids: [String]
    ) -> SessionStore.S3Submission.Group {
        SessionStore.S3Submission.Group(
            sourceRangeID: rangeID,
            name: "名称-" + rangeID,
            orderedAssetIDs: ids
        )
    }

    private func descriptors(
        _ groups: [SessionStore.S3Submission.Group]
    ) -> [AssetDescriptor] {
        groups.flatMap { $0.orderedAssetIDs.map(descriptor) }
    }
}
