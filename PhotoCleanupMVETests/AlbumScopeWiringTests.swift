import Photos
import XCTest
@testable import PhotoCleanupMVE

// MARK: - IC-127 D（并入本文件：工程文件未在授权范围内）

/// 可变照片库夹具：测试中途「外部删除」资产或改授权态。
final class IC127LibraryBox {
    var assets: [S1PhotoAssetSnapshot]
    var status: PHAuthorizationStatus

    init(assets: [S1PhotoAssetSnapshot], status: PHAuthorizationStatus = .authorized) {
        self.assets = assets
        self.status = status
    }

    var source: S1PhotoLibrarySource {
        S1PhotoLibrarySource(
            authorizationStatus: { [unowned self] in self.status },
            fetchAssets: { [unowned self] in self.assets },
            fetchAssetCollections: { _, _ in [] }
        )
    }
}

/// IC-127 D（未定项 2／9 授权分派与失败分类）。
final class S1AuthorizationDispatchTests: XCTestCase {
    // 五种授权态各自落到正确的分派结果。
    func testIC127D_FiveAuthorizationStatesDispatchCorrectly() {
        XCTAssertEqual(
            S1AuthorizationDispatch.dispatch(for: .notDetermined),
            .requestSystemAuthorization
        )
        XCTAssertEqual(
            S1AuthorizationDispatch.dispatch(for: .denied),
            .fail(.authorization)
        )
        XCTAssertEqual(
            S1AuthorizationDispatch.dispatch(for: .restricted),
            .fail(.authorization)
        )
        XCTAssertEqual(
            S1AuthorizationDispatch.dispatch(for: .limited),
            .proceed(isLimited: true)
        )
        XCTAssertEqual(
            S1AuthorizationDispatch.dispatch(for: .authorized),
            .proceed(isLimited: false)
        )
        XCTAssertEqual(
            S1AuthorizationDispatch.dispatch(for: .unknown(99)),
            .fail(.authorization)
        )
    }

    // 服务层：拒绝／受限／未决定各自映射为授权类失败原因，且分类为授权类。
    @MainActor
    func testIC127D_AuthorizationFailuresAreClassifiedAsAuthorization() {
        let box = IC127LibraryBox(assets: [makeAsset("资产-1", day: 1)], status: .denied)
        let service = PhotoLibraryService(s1Source: box.source)

        let expectations: [(PHAuthorizationStatus, S1RangeReadFailure.Reason)] = [
            (.denied, .authorizationDenied),
            (.restricted, .authorizationRestricted),
            (.notDetermined, .authorizationNotDetermined)
        ]
        for (status, reason) in expectations {
            box.status = status
            let response = service.s1RangeRead(groupedBy: .date)
            XCTAssertFalse(response.isLimitedAuthorization)
            guard case let .failure(failure) = response.result else {
                return XCTFail("\(status.rawValue) 应为失败")
            }
            XCTAssertEqual(failure.reason, reason)
            XCTAssertEqual(failure.category, .authorization)
            XCTAssertEqual(service.s1AuthorizationState().isFailureState, true)
        }
    }

    // 受限授权按已授权处理：正常读取、进 S1-2，「受限」标志为真；完全授权标志为假。
    @MainActor
    func testIC127D_LimitedAuthorizationReachesReadyWithLimitedFlag() {
        let box = IC127LibraryBox(
            assets: [makeAsset("资产-2", day: 2), makeAsset("资产-1", day: 1)],
            status: .limited
        )
        let service = PhotoLibraryService(s1Source: box.source)
        XCTAssertEqual(service.s1AuthorizationState(), .limited)

        let limited = service.s1RangeRead(groupedBy: .date)
        XCTAssertTrue(limited.isLimitedAuthorization)
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-limited"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                limited.result,
                for: request,
                isLimitedAuthorization: limited.isLimitedAuthorization
            )
        )
        XCTAssertEqual(machine.state, .ready)
        XCTAssertNil(machine.readFailure)
        XCTAssertTrue(machine.isLimitedAuthorization)
        XCTAssertNotNil(machine.makeS2Handoff(for: tryUnwrap(machine.ranges.first?.id)))

        box.status = .authorized
        let full = service.s1RangeRead(groupedBy: .date)
        XCTAssertFalse(full.isLimitedAuthorization)
        XCTAssertTrue(machine.reconcile(with: full.result, isLimitedAuthorization: false))
        XCTAssertFalse(machine.isLimitedAuthorization)
    }

    // 数据／校验类原因归读取类失败；服务层实读出的缺少拍摄日期即为一例。
    @MainActor
    func testIC127D_DataAndValidationReasonsAreReadFailures() {
        let readReasons: [S1RangeReadFailure.Reason] = [
            .missingCreationDate(assetID: "a"),
            .missingDisplayName(rangeID: "r"),
            .duplicateRangeID("r"),
            .duplicateAssetID(rangeID: "r", assetID: "a"),
            .invalidResponse
        ]
        for reason in readReasons {
            XCTAssertEqual(reason.category, .read, "\(reason)")
        }
        XCTAssertEqual(
            S1RangeReadFailure.Reason.unknownAuthorizationStatus(7).category,
            .authorization
        )

        let box = IC127LibraryBox(
            assets: [S1PhotoAssetSnapshot(identifier: "资产-无日期", creationDate: nil)]
        )
        let service = PhotoLibraryService(s1Source: box.source)
        guard case let .failure(failure) = service.s1RangeRead(groupedBy: .date).result else {
            return XCTFail("缺少拍摄日期应为读取类失败")
        }
        XCTAssertEqual(failure.reason, .missingCreationDate(assetID: "资产-无日期"))
        XCTAssertEqual(failure.category, .read)
    }

    // 不存在任何自动重试路径：S1 产品源码里 `retry()` 只有一个调用点（S1View 的
    // 用户按钮），状态机的 retry 只在失败态成立一次、不自行再次触发。
    func testIC127D_NoAutomaticRetryPath() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let productFiles = [
            "PhotoCleanupMVE/Features/S1/S1View.swift",
            "PhotoCleanupMVE/Core/S1StateMachine.swift",
            "PhotoCleanupMVE/App/CleanupCoordinator.swift",
            "PhotoCleanupMVE/Services/PhotoLibraryService.swift"
        ]
        var callSitesByFile: [String: Int] = [:]
        for relativePath in productFiles {
            let text = try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            let callSites = text.components(separatedBy: ".retry()").count - 1
            callSitesByFile[relativePath] = callSites
            XCTAssertFalse(text.contains("Timer.scheduledTimer"), relativePath)
        }
        XCTAssertEqual(
            callSitesByFile,
            [
                "PhotoCleanupMVE/Features/S1/S1View.swift": 1,
                "PhotoCleanupMVE/Core/S1StateMachine.swift": 0,
                "PhotoCleanupMVE/App/CleanupCoordinator.swift": 0,
                "PhotoCleanupMVE/Services/PhotoLibraryService.swift": 0
            ]
        )

        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-retry"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        XCTAssertFalse(machine.retry())
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .failure(
                    S1RangeReadFailure(
                        groupingDimension: .date,
                        reason: .authorizationDenied
                    )
                ),
                for: request
            )
        )
        XCTAssertEqual(machine.readFailure?.category, .authorization)
        XCTAssertTrue(machine.retry())
        XCTAssertFalse(machine.retry())
        XCTAssertEqual(machine.state, .loading)
    }

    // MARK: - Fixtures

    private func makeAsset(_ identifier: String, day: Int) -> S1PhotoAssetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: 12)
        )!
        return S1PhotoAssetSnapshot(identifier: identifier, creationDate: date)
    }

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

private extension S1AuthorizationState {
    var isFailureState: Bool {
        if case .fail = S1AuthorizationDispatch.dispatch(for: self) {
            return true
        }
        if case .requestSystemAuthorization = S1AuthorizationDispatch.dispatch(for: self) {
            return true
        }
        return false
    }
}

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
        // IC-127 A：按日期为两级树——2 个年节点 + 3 个月节点，空月／空年不出现。
        let dateRanges = try service.s1Ranges(groupedBy: .date).get()
        let yearRanges = dateRanges.filter { $0.parentRangeID == nil }
        let monthRanges = dateRanges.filter { $0.parentRangeID != nil }

        XCTAssertEqual(albumRanges.map(\.id), ["非空相册"])
        XCTAssertEqual(dateRanges.count, 5)
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
