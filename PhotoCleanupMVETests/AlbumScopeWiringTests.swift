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
        let albumRanges = try coordinator.readS1Ranges(groupedBy: .album).result.get()
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

// MARK: - IC-127 C（并入本文件：工程文件未在授权范围内）

/// IC-127 C（未定项 13 对账）。
final class S1ReconciliationTests: XCTestCase {
    // MARK: - C

    // 资产被外部删除后，M 剔除该资产、F 同步删键，总数正确。
    func testIC127C_ExternallyDeletedAssetIsPrunedFromMAndF() {
        let machine = makeReadyMachine(assets: ["a3", "a2", "a1"])
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["a2", "a1"],
                entryContext: entryContext(["a3", "a2", "a1"])
            )
        )
        XCTAssertEqual(machine.badgeCount, 2)

        XCTAssertTrue(
            machine.reconcile(with: .success([range(["a3", "a1"])]))
        )

        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID["r"],
            ["a1"]
        )
        XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["a2"])
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["a1"], "r")
        XCTAssertEqual(machine.sessionStore.allPendingDeletionAssetIDs, ["a1"])
        XCTAssertEqual(machine.badgeCount, 1)
        XCTAssertEqual(machine.ranges.map(\.assetIDsNewestFirst), [["a3", "a1"]])
        XCTAssertEqual(machine.rangeRows.first?.totalAssetCount, 2)
        XCTAssertEqual(machine.rangeRows.first?.pendingDeletionCount, 1)
    }

    // K 越界（c／p 所指资产已不存在）被钳到新序列在 O_记录 下的末位。
    func testIC127C_ContinuationIsClampedToLastAvailableAsset() {
        var store = SessionStore(sessionID: "session-clamp")
        XCTAssertTrue(
            store.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: "session-clamp",
                    sourceRangeID: "r",
                    pendingDeletionAssetIDs: [],
                    currentAssetID: "a1",
                    farthestAssetID: "a1"
                ),
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "r",
                    orderedAssetIDs: ["a3", "a2", "a1"],
                    sortOrder: .newestFirst
                )
            )
        )

        var newestClamped = store
        XCTAssertTrue(
            newestClamped.reconcileRange("r", availableAssetIDsNewestFirst: ["a3", "a2"])
        )
        XCTAssertEqual(
            newestClamped.continuationsByRangeID["r"],
            SessionStore.Continuation(
                currentAssetID: "a2",
                farthestAssetID: "a2",
                recordedSortOrder: .newestFirst
            )
        )

        // O_记录 = 旧到新时，末位是新到旧序列的首元素。
        var oldestStore = SessionStore(sessionID: "session-clamp-oldest")
        XCTAssertTrue(
            oldestStore.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: "session-clamp-oldest",
                    sourceRangeID: "r",
                    pendingDeletionAssetIDs: [],
                    currentAssetID: "a3",
                    farthestAssetID: "a3"
                ),
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "r",
                    orderedAssetIDs: ["a1", "a2", "a3"],
                    sortOrder: .oldestFirst
                )
            )
        )
        XCTAssertTrue(
            oldestStore.reconcileRange("r", availableAssetIDsNewestFirst: ["a2", "a1"])
        )
        XCTAssertEqual(
            oldestStore.continuationsByRangeID["r"],
            SessionStore.Continuation(
                currentAssetID: "a2",
                farthestAssetID: "a2",
                recordedSortOrder: .oldestFirst
            )
        )

        // 仍在序列中的续接不动。
        var untouched = store
        XCTAssertFalse(
            untouched.reconcileRange("r", availableAssetIDsNewestFirst: ["a3", "a2", "a1"])
        )
        XCTAssertEqual(untouched, store)
    }

    // 对账静默：不改加载态、不写 readFailure、协调器 message 为空；重读失败时原样保留。
    func testIC127C_ReconciliationIsSilentAndKeepsReadyState() async {
        await MainActor.run {
            let box = IC127LibraryBox(
                assets: [
                    makeAsset("资产-3", day: 3),
                    makeAsset("资产-2", day: 2),
                    makeAsset("资产-1", day: 1)
                ]
            )
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-静默"))
            let machine = tryUnwrap(coordinator.s1Machine)
            readThroughCoordinator(coordinator)
            XCTAssertEqual(machine.state, .ready)

            box.assets.removeFirst()
            XCTAssertTrue(coordinator.reconcileS1WithPhotoLibrary())
            XCTAssertEqual(machine.state, .ready)
            XCTAssertNil(machine.readFailure)
            XCTAssertNil(coordinator.message)
            XCTAssertEqual(machine.ranges.first?.totalAssetCount, 2)

            box.status = .denied
            let before = machine.ranges
            let storeBefore = machine.sessionStore
            XCTAssertFalse(coordinator.reconcileS1WithPhotoLibrary())
            XCTAssertEqual(machine.state, .ready)
            XCTAssertNil(machine.readFailure)
            XCTAssertNil(coordinator.message)
            XCTAssertEqual(machine.ranges, before)
            XCTAssertEqual(machine.sessionStore, storeBefore)
        }
    }

    // 对账幂等：同一结果连调两次，M／K／F 与范围列表相同；每次调用计数 +1。
    func testIC127C_ReconciliationIsIdempotent() {
        let machine = makeReadyMachine(assets: ["a3", "a2", "a1"])
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["a2"],
                entryContext: entryContext(["a3", "a2", "a1"])
            )
        )
        XCTAssertTrue(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: "session-reconcile",
                    sourceRangeID: "r",
                    pendingDeletionAssetIDs: ["a2"],
                    currentAssetID: "a2",
                    farthestAssetID: "a1"
                ),
                entryContext: entryContext(["a3", "a2", "a1"])
            )
        )
        let countBefore = machine.reconciliationCount
        let newRanges = [range(["a3"])]

        XCTAssertTrue(machine.reconcile(with: .success(newRanges)))
        let firstStore = machine.sessionStore
        let firstRanges = machine.ranges
        XCTAssertTrue(machine.reconcile(with: .success(newRanges)))

        XCTAssertEqual(machine.sessionStore, firstStore)
        XCTAssertEqual(machine.ranges, firstRanges)
        XCTAssertEqual(machine.reconciliationCount, countBefore + 2)
        XCTAssertTrue(machine.sessionStore.allPendingDeletionAssetIDs.isEmpty)
        XCTAssertEqual(
            machine.sessionStore.continuationsByRangeID["r"],
            SessionStore.Continuation(
                currentAssetID: "a3",
                farthestAssetID: "a3",
                recordedSortOrder: .newestFirst
            )
        )
    }

    // 进入 S1（首次读取）与从 S2 返回各经对账入口一次；返回前被外部删除的已标记资产
    // 不进入 M；之后提交不走任何兜底分支（计数为 0）。
    func testIC127C_EntryAndS2ReturnEachReconcileOnceAndSubmissionUsesNoFallback() async {
        await MainActor.run {
            let box = IC127LibraryBox(
                assets: [
                    makeAsset("资产-3", day: 3),
                    makeAsset("资产-2", day: 2),
                    makeAsset("资产-1", day: 1)
                ]
            )
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-对账"))
            let machine = tryUnwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.reconciliationCount, 0)
            readThroughCoordinator(coordinator)
            XCTAssertEqual(machine.reconciliationCount, 1)
            XCTAssertEqual(machine.state, .ready)

            let yearID = tryUnwrap(machine.topLevelRanges.first?.id)
            let yearAssets = tryUnwrap(
                machine.ranges.first { $0.id == yearID }?.assetIDsNewestFirst
            )
            XCTAssertEqual(yearAssets, ["资产-3", "资产-2", "资产-1"])
            XCTAssertTrue(
                machine.applyS2PendingDeletionChange(
                    ["资产-2", "资产-1"],
                    entryContext: SessionStore.S2EntryContext(
                        rangeID: yearID,
                        orderedAssetIDs: yearAssets,
                        sortOrder: .newestFirst
                    )
                )
            )
            let handoff = tryUnwrap(machine.makeS2Handoff(for: yearID))
            XCTAssertTrue(coordinator.enterS2(from: handoff))
            let payload = tryUnwrap(coordinator.s2Machine?.makeExitPayload())

            // 外部删除 资产-2，然后从 S2 返回。
            box.assets.removeAll { $0.identifier == "资产-2" }
            let fallbackBeforeReturn = machine.s3SubmissionOrderingFallback()
            XCTAssertTrue(coordinator.leaveS2(with: payload))

            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertEqual(machine.reconciliationCount, 2)
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID[yearID],
                ["资产-1"]
            )
            XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["资产-2"])
            XCTAssertEqual(machine.sessionStore.allPendingDeletionAssetIDs, ["资产-1"])
            XCTAssertEqual(coordinator.sessionStore, machine.sessionStore)
            XCTAssertNil(coordinator.message)

            // 对账之后提交：无范围、无资产走进兜底分支（计数断言）。
            let fallback = machine.s3SubmissionOrderingFallback()
            XCTAssertEqual(fallback.rangesOutsideOrder, 0)
            XCTAssertEqual(fallback.assetsOutsideOrder, 0)
            XCTAssertEqual(fallbackBeforeReturn.rangesOutsideOrder, 0)
            let submission = tryUnwrap(machine.makeS3Submission())
            XCTAssertEqual(submission.orderedAssetIDs, ["资产-1"])
            XCTAssertEqual(
                submission.groups.reduce(0) { $0 + $1.assetCount },
                machine.sessionStore.allPendingDeletionAssetIDs.count
            )
        }
    }

    // 兜底分支的计数器本身可测：对账前若 M 含已不在 A 中的资产，assetsOutsideOrder > 0。
    func testIC127C_FallbackCounterDetectsStaleAssetsBeforeReconciliation() {
        let machine = makeReadyMachine(assets: ["a3", "a2", "a1"])
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["a2"],
                entryContext: entryContext(["a3", "a2", "a1"])
            )
        )
        // 直接把范围换成不含 a2 的新列表但不走对账入口（模拟「对账前」状态）：
        // 通过 reconcile 之前先读一次兜底计数——此时 a2 仍在 A 中，计数为 0；
        // 再用 SessionStore 层直接构造「a2 不在 A」的提交请求验证计数器。
        XCTAssertEqual(machine.s3SubmissionOrderingFallback().assetsOutsideOrder, 0)
        let stale = machine.sessionStore.s3SubmissionOrderingFallback(
            rangeOrder: ["r"],
            orderedAssetIDsForRangeID: { _ in ["a3", "a1"] }
        )
        XCTAssertEqual(stale.assetsOutsideOrder, 1)
        XCTAssertEqual(stale.rangesOutsideOrder, 0)
        let outsideOrder = machine.sessionStore.s3SubmissionOrderingFallback(
            rangeOrder: [],
            orderedAssetIDsForRangeID: { _ in [] }
        )
        XCTAssertEqual(outsideOrder.rangesOutsideOrder, 1)
        XCTAssertEqual(outsideOrder.assetsOutsideOrder, 1)
    }

    // MARK: - Fixtures

    private func makeReadyMachine(assets: [String]) -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-reconcile"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(.success([range(assets)]), for: request)
        )
        return machine
    }

    private func range(_ assets: [String]) -> S1Range {
        S1Range(id: "r", displayName: "2026", assetIDsNewestFirst: assets)
    }

    private func entryContext(_ assets: [String]) -> SessionStore.S2EntryContext {
        SessionStore.S2EntryContext(
            rangeID: "r",
            orderedAssetIDs: assets,
            sortOrder: .newestFirst
        )
    }

    @MainActor
    private func readThroughCoordinator(_ coordinator: CleanupCoordinator) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        let response = coordinator.readS1Ranges(groupedBy: request.groupingDimension)
        XCTAssertTrue(
            machine.completeRangeRead(
                response.result,
                for: request,
                isLimitedAuthorization: response.isLimitedAuthorization
            )
        )
    }

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
