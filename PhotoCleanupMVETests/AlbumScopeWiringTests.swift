import Photos
import XCTest
@testable import PhotoCleanupMVE

final class AlbumScopeWiringTests: XCTestCase {
    // T1：相册范围只保留用户自建普通相册。
    @MainActor
    func testIC051_T1AlbumRangesContainOnlyUserCreatedRegularAlbums() throws {
        let commonAsset = makeAsset("资产-普通", year: 2026, month: 8, day: 15)
        let albums = [
            makeAlbum(id: "普通-B", assets: [commonAsset]),
            makeAlbum(
                id: "智能",
                collectionType: .smartAlbum,
                collectionSubtype: .smartAlbumFavorites,
                assets: [commonAsset]
            ),
            makeAlbum(
                id: "共享",
                collectionSubtype: .albumCloudShared,
                assets: [commonAsset]
            ),
            makeAlbum(id: "隐藏", isHidden: true, assets: [commonAsset]),
            makeAlbum(id: "普通-A", assets: [commonAsset])
        ]
        var requestedTypes: [Int] = []
        var requestedSubtypes: [Int] = []
        let service = PhotoLibraryService(
            s1Source: makeSource(albums: albums) { type, subtype in
                requestedTypes.append(type.rawValue)
                requestedSubtypes.append(subtype.rawValue)
            }
        )

        let ranges = try service.s1Ranges(groupedBy: .album).get()

        XCTAssertEqual(ranges.map(\.id), ["普通-B", "普通-A"])
        XCTAssertEqual(requestedTypes, [PHAssetCollectionType.album.rawValue])
        XCTAssertEqual(
            requestedSubtypes,
            [PHAssetCollectionSubtype.albumRegular.rawValue]
        )
        XCTAssertTrue(Set(ranges.map(\.id)).isDisjoint(with: ["智能", "共享", "隐藏"]))
    }

    // T2：相册范围保持抓取顺序，切换 O 不改变范围列表顺序。
    @MainActor
    func testIC051_T2AlbumRangeOrderMatchesFetchOrderAndIgnoresSortFlip() throws {
        let asset = makeAsset("资产-顺序", year: 2026, month: 8, day: 15)
        let service = PhotoLibraryService(
            s1Source: makeSource(
                albums: [
                    makeAlbum(id: "相册-三", assets: [asset]),
                    makeAlbum(id: "相册-一", assets: [asset]),
                    makeAlbum(id: "相册-二", assets: [asset])
                ]
            )
        )
        let ranges = try service.s1Ranges(groupedBy: .album).get()
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-T2"),
            initialGroupingDimension: .album,
            initialSortOrder: .newestFirst
        )
        let request = try XCTUnwrap(machine.currentReadRequest)

        XCTAssertEqual(ranges.map(\.id), ["相册-三", "相册-一", "相册-二"])
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
        XCTAssertEqual(machine.visibleRanges.map(\.id), ranges.map(\.id))
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(machine.visibleRanges.map(\.id), ranges.map(\.id))
    }

    // T3：同一相册的 A 在两个 O 下元素相同且顺序互逆。
    @MainActor
    func testIC051_T3AlbumAssetsUseCurrentSortOrderAndReverseExactly() throws {
        let service = PhotoLibraryService(
            s1Source: makeSource(
                albums: [
                    makeAlbum(
                        id: "相册-T3",
                        assets: [
                            makeAsset("资产-旧", year: 2024, month: 1, day: 1),
                            makeAsset("资产-新", year: 2026, month: 8, day: 15),
                            makeAsset("资产-中", year: 2025, month: 6, day: 1)
                        ]
                    )
                ]
            )
        )
        let ranges = try service.s1Ranges(groupedBy: .album).get()
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-T3"),
            initialGroupingDimension: .album,
            initialSortOrder: .newestFirst
        )
        let request = try XCTUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))

        let newest = try XCTUnwrap(machine.makeS2Handoff(for: "相册-T3"))
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        let oldest = try XCTUnwrap(machine.makeS2Handoff(for: "相册-T3"))

        XCTAssertEqual(Set(newest.orderedAssetIDs), Set(oldest.orderedAssetIDs))
        XCTAssertEqual(oldest.orderedAssetIDs, Array(newest.orderedAssetIDs.reversed()))
        XCTAssertEqual(newest.orderedAssetIDs, ["资产-新", "资产-中", "资产-旧"])
    }

    // T4：未分类恰为全库减去全部用户自建普通相册资产的并集。
    @MainActor
    func testIC051_T4UnclassifiedIsExactComplementOfUserAlbumUnion() throws {
        let assets = (1...5).map {
            makeAsset("资产-\($0)", year: 2026, month: 8, day: $0)
        }
        let albums = [
            makeAlbum(id: "普通-一", assets: [assets[0], assets[1]]),
            makeAlbum(id: "普通-二", assets: [assets[1], assets[2]]),
            makeAlbum(
                id: "智能",
                collectionType: .smartAlbum,
                collectionSubtype: .smartAlbumFavorites,
                assets: [assets[3]]
            ),
            makeAlbum(
                id: "共享",
                collectionSubtype: .albumCloudShared,
                assets: [assets[4]]
            )
        ]
        let service = PhotoLibraryService(
            s1Source: makeSource(allAssets: assets, albums: albums)
        )

        let ranges = try service.s1Ranges(groupedBy: .unclassified).get()

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first?.id, "s1-unclassified")
        XCTAssertEqual(Set(ranges[0].assetIDsNewestFirst), ["资产-4", "资产-5"])
    }

    // T5：空相册以及时间轴中的空月份、空年份均不形成范围项。
    @MainActor
    func testIC051_T5ZeroTotalAlbumMonthAndYearRangesAreExcluded() throws {
        let assets = [
            makeAsset("资产-2024", year: 2024, month: 1, day: 1),
            makeAsset("资产-2026-一月", year: 2026, month: 1, day: 1),
            makeAsset("资产-2026-三月", year: 2026, month: 3, day: 1)
        ]
        let service = PhotoLibraryService(
            s1Source: makeSource(
                allAssets: assets,
                albums: [
                    makeAlbum(id: "空相册", assets: []),
                    makeAlbum(id: "非空相册", assets: [assets[0]])
                ]
            )
        )

        let albumRanges = try service.s1Ranges(groupedBy: .album).get()
        let monthRanges = try service.s1Ranges(groupedBy: .month).get()
        let yearRanges = try service.s1Ranges(groupedBy: .year).get()

        XCTAssertEqual(albumRanges.map(\.id), ["非空相册"])
        XCTAssertEqual(monthRanges.count, 3)
        XCTAssertEqual(yearRanges.count, 2)
        XCTAssertTrue(albumRanges.allSatisfy { $0.totalAssetCount > 0 })
        XCTAssertTrue(monthRanges.allSatisfy { $0.totalAssetCount > 0 })
        XCTAssertTrue(yearRanges.allSatisfy { $0.totalAssetCount > 0 })
    }

    // T6：跨范围的局部 D 独立，全局 D 去重，F 保留首次标记范围。
    func testIC051_T6CrossRangeDeletionSetsDeduplicateAndKeepFirstOwner() {
        var store = SessionStore(sessionID: "会话-T6")

        store.setMarked(true, assetID: "资产-共享", rangeID: "月份-2026-08")
        store.setMarked(true, assetID: "资产-共享", rangeID: "相册-假期")

        XCTAssertEqual(
            store.pendingDeletionAssetIDsByRangeID["月份-2026-08"],
            ["资产-共享"]
        )
        XCTAssertEqual(
            store.pendingDeletionAssetIDsByRangeID["相册-假期"],
            ["资产-共享"]
        )
        XCTAssertEqual(store.allPendingDeletionAssetIDs, ["资产-共享"])
        XCTAssertEqual(
            store.firstMarkedRangeIDByAssetID["资产-共享"],
            "月份-2026-08"
        )
    }

    // T7：相册范围可进入 S2，交接 D 为 A 子集且 c 属于 A；其余三维度同样可形成交接。
    @MainActor
    func testIC051_T7AlbumHandoffSatisfiesContractAndAllDimensionsAreEnterable() throws {
        let assets = [
            makeAsset("资产-旧", year: 2024, month: 1, day: 1),
            makeAsset("资产-新", year: 2026, month: 8, day: 15),
            makeAsset("资产-未分类", year: 2025, month: 6, day: 1)
        ]
        let service = PhotoLibraryService(
            s1Source: makeSource(
                allAssets: assets,
                albums: [
                    makeAlbum(id: "相册-T7", assets: [assets[0], assets[1]])
                ]
            )
        )

        for dimension in S1GroupingDimension.allCases {
            let ranges = try service.s1Ranges(groupedBy: dimension).get()
            let machine = S1StateMachine(
                sessionStore: SessionStore(sessionID: "会话-\(dimension)"),
                initialGroupingDimension: dimension,
                initialSortOrder: .newestFirst
            )
            let request = try XCTUnwrap(machine.currentReadRequest)
            XCTAssertFalse(ranges.isEmpty, "\(dimension) 应至少形成一个范围")
            XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
            XCTAssertNotNil(machine.makeS2Handoff(for: ranges[0].id))
        }

        let coordinator = CleanupCoordinator(photoLibrary: service)
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-T7-相册"))
        let machine = try XCTUnwrap(coordinator.s1Machine)
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        let request = try XCTUnwrap(machine.currentReadRequest)
        let albumRanges = try coordinator.readS1Ranges(groupedBy: .album).get()
        XCTAssertTrue(machine.completeRangeRead(.success(albumRanges), for: request))
        let range = try XCTUnwrap(albumRanges.first)
        let entryContext = SessionStore.S2EntryContext(
            rangeID: range.id,
            orderedAssetIDs: range.orderedAssetIDs(for: machine.sortOrder),
            sortOrder: machine.sortOrder.sessionSortOrder
        )
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["资产-旧"],
                entryContext: entryContext
            )
        )
        let handoff = try XCTUnwrap(machine.makeS2Handoff(for: range.id))

        XCTAssertTrue(
            handoff.pendingDeletionAssetIDs.isSubset(of: Set(handoff.orderedAssetIDs))
        )
        XCTAssertTrue(handoff.orderedAssetIDs.contains(handoff.currentAssetID))
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        XCTAssertEqual(coordinator.route, .s2)
    }

    private func makeSource(
        allAssets: [S1PhotoAssetSnapshot] = [],
        albums: [S1AlbumCollectionSnapshot],
        onFetch: @escaping (
            PHAssetCollectionType,
            PHAssetCollectionSubtype
        ) -> Void = { _, _ in }
    ) -> S1PhotoLibrarySource {
        S1PhotoLibrarySource(
            authorizationStatus: { .authorized },
            fetchAssets: { allAssets },
            fetchAssetCollections: { type, subtype in
                onFetch(type, subtype)
                return albums
            }
        )
    }

    private func makeAlbum(
        id: String,
        collectionType: PHAssetCollectionType = .album,
        collectionSubtype: PHAssetCollectionSubtype = .albumRegular,
        isHidden: Bool = false,
        assets: [S1PhotoAssetSnapshot]
    ) -> S1AlbumCollectionSnapshot {
        S1AlbumCollectionSnapshot(
            identifier: id,
            localizedTitle: "名称-\(id)",
            collectionType: collectionType,
            collectionSubtype: collectionSubtype,
            isHidden: isHidden,
            assets: assets
        )
    }

    private func makeAsset(
        _ identifier: String,
        year: Int,
        month: Int,
        day: Int
    ) -> S1PhotoAssetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: 12
            )
        )!
        return S1PhotoAssetSnapshot(identifier: identifier, creationDate: date)
    }
}
