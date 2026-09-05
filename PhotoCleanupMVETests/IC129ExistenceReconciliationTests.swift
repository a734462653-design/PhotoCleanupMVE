import Photos
import XCTest
@testable import PhotoCleanupMVE

/// IC-129 夹具：可外部删除单个资产与整本相册的照片库。
/// 存在性 = 资产仍在照片库中，与相册归属无关；相册快照按当前资产表实时组装，
/// 删除资产后其相册成员资格随之消失，空相册在读取端被跳过（既有行为）。
final class IC129LibraryBox {
    struct Album {
        let id: String
        let title: String
        var memberIDs: [String]
    }

    var assets: [S1PhotoAssetSnapshot]
    var albums: [Album]
    private(set) var existenceQueries: [[String]] = []

    init(assets: [S1PhotoAssetSnapshot], albums: [Album]) {
        self.assets = assets
        self.albums = albums
    }

    func deleteAsset(_ identifier: String) {
        assets.removeAll { $0.identifier == identifier }
    }

    func deleteAlbum(_ identifier: String) {
        albums.removeAll { $0.id == identifier }
    }

    var source: S1PhotoLibrarySource {
        S1PhotoLibrarySource(
            authorizationStatus: { .authorized },
            fetchAssets: { [unowned self] in self.assets },
            fetchAssetCollections: { [unowned self] _, _ in
                self.albums.map { album in
                    S1AlbumCollectionSnapshot(
                        identifier: album.id,
                        localizedTitle: album.title,
                        collectionType: .album,
                        collectionSubtype: .albumRegular,
                        isHidden: false,
                        assets: album.memberIDs.compactMap { memberID in
                            self.assets.first { $0.identifier == memberID }
                        }
                    )
                }
            },
            fetchExistingAssetIdentifiers: { [unowned self] identifiers in
                self.existenceQueries.append(identifiers)
                return Set(identifiers).intersection(
                    Set(self.assets.map(\.identifier))
                )
            }
        )
    }
}

/// IC-129：对账依据由「当前维度本次读到的范围集合」改为资产存在性。
final class IC129ExistenceReconciliationTests: XCTestCase {
    // 断言 1（跨维度场景）：在相册维度的范围里标记 → 切到按日期维度 →
    // 其中一张被外部删除 → 对账后 D_全部 与徽标数收敛到正确值，F 中该键已删。
    func testIC129A_CrossDimensionStaleAssetIsPrunedByExistence() async {
        await MainActor.run {
            let box = makeAlbumBox()
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-129A"))
            let machine = tryUnwrap(coordinator.s1Machine)
            XCTAssertTrue(machine.switchGroupingDimension(to: .album))
            readThroughCoordinator(coordinator)
            XCTAssertEqual(machine.state, .ready)
            markInRange(
                "相册-1",
                assetIDs: ["资产-2", "资产-1"],
                machine: machine
            )
            XCTAssertEqual(machine.badgeCount, 2)

            // 切到按日期维度并读取——此刻资产都在，不应有任何剔除。
            XCTAssertTrue(machine.switchGroupingDimension(to: .date))
            readThroughCoordinator(coordinator)
            XCTAssertEqual(machine.badgeCount, 2)

            // 外部删除 资产-2，然后对账（时机同 S2 返回）。相册范围不在
            // R(date) 中，按范围收敛够不到它，收敛只能来自存在性。
            box.deleteAsset("资产-2")
            XCTAssertTrue(coordinator.reconcileS1WithPhotoLibrary())

            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["相册-1"],
                ["资产-1"]
            )
            XCTAssertNil(
                machine.sessionStore.firstMarkedRangeIDByAssetID["资产-2"]
            )
            XCTAssertEqual(
                machine.sessionStore.allPendingDeletionAssetIDs,
                ["资产-1"]
            )
            XCTAssertEqual(machine.badgeCount, 1)
            XCTAssertEqual(coordinator.sessionStore, machine.sessionStore)
        }
    }

    // 断言 2：同一资产同时落在两个维度的范围内（日期年范围 + 相册范围），
    // 外部删除后一次对账两侧都被剔除，D_全部 无残留。
    func testIC129B_AssetMarkedInTwoDimensionsIsPrunedFromBothRanges() async {
        await MainActor.run {
            let box = makeAlbumBox()
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-129B"))
            let machine = tryUnwrap(coordinator.s1Machine)
            readThroughCoordinator(coordinator)
            let yearID = tryUnwrap(machine.topLevelRanges.first?.id)
            markInRange(yearID, assetIDs: ["资产-1"], machine: machine)

            XCTAssertTrue(machine.switchGroupingDimension(to: .album))
            readThroughCoordinator(coordinator)
            markInRange("相册-1", assetIDs: ["资产-1"], machine: machine)

            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID[yearID],
                ["资产-1"]
            )
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["相册-1"],
                ["资产-1"]
            )
            XCTAssertEqual(machine.badgeCount, 1)

            box.deleteAsset("资产-1")
            XCTAssertTrue(coordinator.reconcileS1WithPhotoLibrary())

            XCTAssertEqual(
                machine.sessionStore
                    .pendingDeletionAssetIDsByRangeID[yearID] ?? [],
                []
            )
            XCTAssertEqual(
                machine.sessionStore
                    .pendingDeletionAssetIDsByRangeID["相册-1"] ?? [],
                []
            )
            XCTAssertNil(
                machine.sessionStore.firstMarkedRangeIDByAssetID["资产-1"]
            )
            XCTAssertTrue(
                machine.sessionStore.allPendingDeletionAssetIDs.isEmpty
            )
            XCTAssertEqual(machine.badgeCount, 0)
        }
    }

    // 断言 3：范围失效（整本相册被删）与资产失效同时发生时都被正确收敛——
    // 已删资产即使其范围不再出现在 R(T) 中也被剔除；仍存在的资产保持标记
    // （范围失效不清 M 的既有收敛逻辑保留，两者叠加而不是替换）。
    func testIC129C_RangeAndAssetInvalidationConvergeTogether() async {
        await MainActor.run {
            let box = IC129LibraryBox(
                assets: [
                    makeAsset("资产-A1", day: 4),
                    makeAsset("资产-A2", day: 3),
                    makeAsset("资产-B1", day: 2),
                    makeAsset("资产-B2", day: 1)
                ],
                albums: [
                    IC129LibraryBox.Album(
                        id: "相册-A",
                        title: "名称-相册-A",
                        memberIDs: ["资产-A1", "资产-A2"]
                    ),
                    IC129LibraryBox.Album(
                        id: "相册-B",
                        title: "名称-相册-B",
                        memberIDs: ["资产-B1", "资产-B2"]
                    )
                ]
            )
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-129C"))
            let machine = tryUnwrap(coordinator.s1Machine)
            XCTAssertTrue(machine.switchGroupingDimension(to: .album))
            readThroughCoordinator(coordinator)
            markInRange("相册-A", assetIDs: ["资产-A2"], machine: machine)
            markInRange(
                "相册-B",
                assetIDs: ["资产-B1", "资产-B2"],
                machine: machine
            )
            XCTAssertEqual(machine.badgeCount, 3)

            // 同时发生：整本相册 B 被删（范围失效），且其中已标记的
            // 资产-B1 被删（资产失效）；资产-B2 仍存在于照片库。
            box.deleteAlbum("相册-B")
            box.deleteAsset("资产-B1")
            XCTAssertTrue(coordinator.reconcileS1WithPhotoLibrary())

            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["相册-B"],
                ["资产-B2"]
            )
            XCTAssertNil(
                machine.sessionStore.firstMarkedRangeIDByAssetID["资产-B1"]
            )
            XCTAssertEqual(
                machine.sessionStore.firstMarkedRangeIDByAssetID["资产-B2"],
                "相册-B"
            )
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["相册-A"],
                ["资产-A2"]
            )
            XCTAssertEqual(
                machine.sessionStore.allPendingDeletionAssetIDs,
                ["资产-A2", "资产-B2"]
            )
            XCTAssertEqual(machine.badgeCount, 2)
        }
    }

    // 断言 4：幂等——连续两次对账结果相同，且第二次不产生任何写入（持久化
    // 写入计数钉住）；每次对账对存在性只发起一次批量查询，入参为 M 全范围并集；
    // M 为空时不查询。
    func testIC129D_ReconciliationIsIdempotentAndSecondPassWritesNothing() {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-129D"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        var probeQueries: [Set<String>] = []
        var deadAssetIDs: Set<String> = []
        machine.assetExistenceProbe = { identifiers in
            probeQueries.append(identifiers)
            return identifiers.subtracting(deadAssetIDs)
        }
        var persistedSnapshotCount = 0
        machine.persistenceSink = { _ in persistedSnapshotCount += 1 }

        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([makeRange("范围-A", assets: ["a3", "a2", "a1"])]),
                for: request
            )
        )
        // M 为空的对账不发起存在性查询。
        XCTAssertEqual(probeQueries, [])

        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["a2", "a1"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "范围-A",
                    orderedAssetIDs: ["a3", "a2", "a1"],
                    sortOrder: .newestFirst
                )
            )
        )
        deadAssetIDs = ["a2"]
        let writesBeforeReconciliation = persistedSnapshotCount

        // 新读取结果不含范围-A（范围整个失效），a2 只能由存在性收敛剔除。
        let newRanges = [makeRange("范围-B", assets: ["b1"])]
        XCTAssertTrue(machine.reconcile(with: .success(newRanges)))
        XCTAssertEqual(probeQueries, [["a2", "a1"]])
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID["范围-A"],
            ["a1"]
        )
        XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["a2"])
        XCTAssertEqual(machine.sessionStore.allPendingDeletionAssetIDs, ["a1"])
        XCTAssertEqual(persistedSnapshotCount, writesBeforeReconciliation + 1)

        let firstStore = machine.sessionStore
        let firstRanges = machine.ranges
        XCTAssertTrue(machine.reconcile(with: .success(newRanges)))
        XCTAssertEqual(machine.sessionStore, firstStore)
        XCTAssertEqual(machine.ranges, firstRanges)
        XCTAssertEqual(probeQueries, [["a2", "a1"], ["a1"]])
        // 第二次对账不产生任何写入。
        XCTAssertEqual(persistedSnapshotCount, writesBeforeReconciliation + 1)
    }

    // 断言 5：存在性收敛静默完成——不改加载态、不写 readFailure、
    // 协调器 message 为空。
    func testIC129E_ExistenceReconciliationIsSilent() async {
        await MainActor.run {
            let box = makeAlbumBox()
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-129E"))
            let machine = tryUnwrap(coordinator.s1Machine)
            XCTAssertTrue(machine.switchGroupingDimension(to: .album))
            readThroughCoordinator(coordinator)
            markInRange(
                "相册-1",
                assetIDs: ["资产-2", "资产-1"],
                machine: machine
            )
            XCTAssertTrue(machine.switchGroupingDimension(to: .date))
            readThroughCoordinator(coordinator)

            box.deleteAsset("资产-2")
            XCTAssertTrue(coordinator.reconcileS1WithPhotoLibrary())

            XCTAssertEqual(machine.state, .ready)
            XCTAssertNil(machine.readFailure)
            XCTAssertNil(coordinator.message)
            XCTAssertEqual(machine.badgeCount, 1)
        }
    }

    // 服务层新 API：一次批量查询、只返回入参子集、空入参不发起查询；
    // 夹具默认源（未显式提供存在性实现）视全部入参为仍存在。
    func testIC129F_ServiceExistenceQueryIsSingleBatchAndReturnsSubset() async {
        await MainActor.run {
            var queries: [[String]] = []
            let source = S1PhotoLibrarySource(
                authorizationStatus: { .authorized },
                fetchAssets: { [] },
                fetchAssetCollections: { _, _ in [] },
                fetchExistingAssetIdentifiers: { identifiers in
                    queries.append(identifiers)
                    return ["a1", "x-入参之外"]
                }
            )
            let service = PhotoLibraryService(s1Source: source)

            XCTAssertEqual(service.existingAssetIdentifiers(among: []), [])
            XCTAssertEqual(queries.count, 0)

            let existing = service.existingAssetIdentifiers(among: ["a2", "a1"])
            XCTAssertEqual(existing, ["a1"])
            XCTAssertEqual(queries, [["a1", "a2"]])

            let defaulted = S1PhotoLibrarySource(
                authorizationStatus: { .authorized },
                fetchAssets: { [] },
                fetchAssetCollections: { _, _ in [] }
            )
            XCTAssertEqual(
                defaulted.fetchExistingAssetIdentifiers(["a2", "a1"]),
                ["a2", "a1"]
            )
        }
    }

    // MARK: - Fixtures

    /// 三张日期资产 + 一本含其中两张的相册。
    private func makeAlbumBox() -> IC129LibraryBox {
        IC129LibraryBox(
            assets: [
                makeAsset("资产-3", day: 3),
                makeAsset("资产-2", day: 2),
                makeAsset("资产-1", day: 1)
            ],
            albums: [
                IC129LibraryBox.Album(
                    id: "相册-1",
                    title: "名称-相册-1",
                    memberIDs: ["资产-2", "资产-1"]
                )
            ]
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

    private func makeRange(_ id: String, assets: [String]) -> S1Range {
        S1Range(id: id, displayName: "名称-\(id)", assetIDsNewestFirst: assets)
    }

    private func markInRange(
        _ rangeID: String,
        assetIDs: Set<String>,
        machine: S1StateMachine,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let range = machine.ranges.first(where: { $0.id == rangeID }) else {
            return XCTFail("范围 \(rangeID) 应存在", file: file, line: line)
        }
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                assetIDs,
                entryContext: SessionStore.S2EntryContext(
                    rangeID: rangeID,
                    orderedAssetIDs: range.orderedAssetIDs(for: machine.sortOrder),
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            ),
            file: file,
            line: line
        )
    }

    @MainActor
    private func readThroughCoordinator(
        _ coordinator: CleanupCoordinator,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求", file: file, line: line)
        }
        let response = coordinator.readS1Ranges(groupedBy: request.groupingDimension)
        XCTAssertTrue(
            machine.completeRangeRead(
                response.result,
                for: request,
                isLimitedAuthorization: response.isLimitedAuthorization
            ),
            file: file,
            line: line
        )
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
