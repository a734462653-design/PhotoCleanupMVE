import Foundation
import XCTest
import Photos
@testable import PhotoCleanupMVE

final class FullFlowRoutingTests: XCTestCase {
    private final class IsolatedFileManager: FileManager {
        private let applicationSupportRoot: URL

        init(applicationSupportRoot: URL) {
            self.applicationSupportRoot = applicationSupportRoot
            super.init()
        }

        override func urls(
            for directory: FileManager.SearchPathDirectory,
            in domainMask: FileManager.SearchPathDomainMask
        ) -> [URL] {
            if directory == .applicationSupportDirectory,
               domainMask.contains(.userDomainMask) {
                return [applicationSupportRoot]
            }
            return super.urls(for: directory, in: domainMask)
        }
    }

    // IC048-001：授权完成后的启动落点为 S1，并建立空白新会话。
    func testIC048_001AuthorizedStartupEntersS1WithFreshSession() async {
        await MainActor.run {
            let coordinator = CleanupCoordinator()

            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-启动"))
            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertEqual(coordinator.s1Machine?.state, .loading)
            XCTAssertEqual(
                coordinator.s1Machine?.sessionStore.sessionID,
                "会话-启动"
            )
            XCTAssertTrue(
                coordinator.s1Machine?.sessionStore
                    .pendingDeletionAssetIDsByRangeID.isEmpty == true
            )
            XCTAssertTrue(
                coordinator.s1Machine?.sessionStore
                    .continuationsByRangeID.isEmpty == true
            )
            XCTAssertTrue(
                coordinator.s1Machine?.sessionStore
                    .firstMarkedRangeIDByAssetID.isEmpty == true
            )
        }
    }

    // IC048-002：S1 点范围项后，六字段完整传入 S2，合并总数保持可刷新。
    func testIC048_002S1RangeTapPassesAllSixFieldsToS2() async {
        await MainActor.run {
            let coordinator = makeReadyCoordinator(
                sessionID: "会话-六字段",
                ranges: [
                    S1Range(
                        id: "范围-月",
                        displayName: "2026 年 8 月",
                        assetIDsNewestFirst: ["资产-C", "资产-B", "资产-A"]
                    )
                ]
            )
            mark(
                ["资产-B"],
                in: "范围-月",
                coordinator: coordinator
            )
            guard let handoff = coordinator.s1Machine?.makeS2Handoff(
                for: "范围-月"
            ) else {
                return XCTFail("应形成 S1 到 S2 的交接")
            }

            XCTAssertEqual(handoff.sessionID, "会话-六字段")
            XCTAssertEqual(handoff.rangeDisplayInformation.rangeID, "范围-月")
            XCTAssertEqual(
                handoff.rangeDisplayInformation.displayName,
                "2026 年 8 月"
            )
            XCTAssertEqual(handoff.rangeDisplayInformation.totalAssetCount, 3)
            XCTAssertEqual(
                handoff.orderedAssetIDs,
                ["资产-C", "资产-B", "资产-A"]
            )
            XCTAssertEqual(handoff.currentAssetID, "资产-C")
            XCTAssertEqual(handoff.pendingDeletionAssetIDs, ["资产-B"])
            XCTAssertEqual(handoff.sessionMergedPendingDeletionCount, 1)

            XCTAssertTrue(coordinator.enterS2(from: handoff))
            XCTAssertEqual(coordinator.route, .s2)
            XCTAssertEqual(coordinator.s2Machine?.entry.sessionID, handoff.sessionID)
            XCTAssertEqual(
                coordinator.s2Machine?.entry.rangeDisplayInformation,
                S2RangeDisplayInformation(
                    rangeID: "范围-月",
                    displayName: "2026 年 8 月",
                    totalAssetCount: 3
                )
            )
            XCTAssertEqual(
                coordinator.s2Machine?.entry.orderedAssetIDs,
                handoff.orderedAssetIDs
            )
            XCTAssertEqual(
                coordinator.s2Machine?.entry.currentAssetID,
                handoff.currentAssetID
            )
            XCTAssertEqual(
                coordinator.s2Machine?.entry.pendingDeletionAssetIDs,
                handoff.pendingDeletionAssetIDs
            )

            XCTAssertTrue(coordinator.s2Machine?.handleSwipeUp() == true)
            XCTAssertEqual(
                coordinator.s2Machine?.sessionMergedPendingDeletionCount,
                2
            )
        }
    }

    // IC048-003：S2 返回先交回五字段，再原子写回 M 与 K 并回到 S1。
    func testIC048_003S2BackWritesAllFiveFieldsIntoMAndK() async {
        await MainActor.run {
            let coordinator = makeReadyCoordinator(
                sessionID: "会话-返回",
                ranges: [
                    S1Range(
                        id: "范围-月",
                        displayName: "2026 年 8 月",
                        assetIDsNewestFirst: ["资产-C", "资产-B", "资产-A"]
                    )
                ]
            )
            openRange("范围-月", coordinator: coordinator)
            guard let machine = coordinator.s2Machine else {
                return XCTFail("应进入 S2")
            }
            XCTAssertTrue(machine.handleSwipeUp())
            XCTAssertTrue(machine.beginBottomStripDrag())
            XCTAssertTrue(machine.changeCurrentPhotoDuringBottomStripDrag(by: 1))
            XCTAssertTrue(machine.endBottomStripDrag())
            XCTAssertTrue(machine.handleSwipeUp())
            XCTAssertTrue(machine.beginBottomStripDrag())
            XCTAssertTrue(machine.changeCurrentPhotoDuringBottomStripDrag(by: -1))
            XCTAssertTrue(machine.endBottomStripDrag())
            guard let payload = machine.makeExitPayload() else {
                return XCTFail("应形成 S2 返回载荷")
            }

            XCTAssertEqual(payload.upstreamReturn.sourceSessionID, "会话-返回")
            XCTAssertEqual(payload.upstreamReturn.sourceRangeID, "范围-月")
            XCTAssertEqual(
                payload.upstreamReturn.pendingDeletionAssetIDs,
                ["资产-A", "资产-C"]
            )
            XCTAssertEqual(payload.upstreamReturn.currentAssetID, "资产-B")
            XCTAssertEqual(payload.upstreamReturn.farthestAssetID, "资产-A")

            XCTAssertTrue(coordinator.leaveS2(with: payload))
            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertEqual(
                coordinator.s1Machine?.sessionStore
                    .pendingDeletionAssetIDsByRangeID["范围-月"],
                ["资产-A", "资产-C"]
            )
            XCTAssertEqual(
                coordinator.s1Machine?.sessionStore
                    .continuationsByRangeID["范围-月"],
                SessionStore.Continuation(
                    currentAssetID: "资产-B",
                    farthestAssetID: "资产-A",
                    recordedSortOrder: .newestFirst
                )
            )
        }
    }

    // IC048-004：S1 与 S2 的垃圾桶都向 S3 交付同一总集、分组和组计数。
    func testIC048_004S1AndS2TrashPassMergedSetAndGroupsToS3() async {
        await MainActor.run {
            let fromS1 = makeGroupedCoordinator(sessionID: "会话-S1-提交")
            guard let s1Submission = fromS1.s1Machine?.makeS3Submission() else {
                return XCTFail("S1 应形成 S3 提交")
            }
            XCTAssertTrue(fromS1.enterConfirmationFromS1(s1Submission))
            assertS3Contract(
                coordinator: fromS1,
                expectedSessionID: "会话-S1-提交"
            )

            let fromS2 = makeGroupedCoordinator(sessionID: "会话-S2-提交")
            openRange("范围-2", coordinator: fromS2)
            guard let payload = fromS2.s2Machine?.makeExitPayload() else {
                return XCTFail("S2 应先形成五字段返回载荷")
            }
            XCTAssertEqual(payload.upstreamReturn.sourceSessionID, "会话-S2-提交")
            XCTAssertEqual(payload.upstreamReturn.sourceRangeID, "范围-2")
            XCTAssertEqual(
                payload.upstreamReturn.pendingDeletionAssetIDs,
                ["资产-B", "资产-S"]
            )
            XCTAssertEqual(payload.upstreamReturn.currentAssetID, "资产-B")
            XCTAssertEqual(payload.upstreamReturn.farthestAssetID, "资产-B")
            XCTAssertTrue(fromS2.enterConfirmationFromS2(with: payload))
            assertS3Contract(
                coordinator: fromS2,
                expectedSessionID: "会话-S2-提交"
            )
        }
    }

    // IC048-005：S3 返回两个字段后，全部 M 取交集、F 清理且实际回到 S1。
    func testIC048_005S3BackIntersectsEveryRangeAndReturnsToS1() async {
        await MainActor.run {
            let coordinator = makeGroupedCoordinator(sessionID: "会话-S3-返回")
            guard let submission = coordinator.s1Machine?.makeS3Submission() else {
                return XCTFail("应形成 S3 提交")
            }
            XCTAssertTrue(coordinator.enterConfirmationFromS1(submission))
            coordinator.removeAsset("资产-S")
            guard let returned = coordinator.s3Machine?.makeUpstreamReturn() else {
                return XCTFail("应形成 S3 返回载荷")
            }

            XCTAssertEqual(returned.sourceSessionID, "会话-S3-返回")
            XCTAssertEqual(
                returned.currentPendingDeletionAssetIDs,
                ["资产-A", "资产-B"]
            )
            coordinator.leaveConfirmation()

            XCTAssertEqual(coordinator.route, .upstream)
            XCTAssertNotNil(coordinator.s1Machine)
            XCTAssertEqual(
                coordinator.s1Machine?.sessionStore
                    .pendingDeletionAssetIDsByRangeID["范围-1"],
                ["资产-A"]
            )
            XCTAssertEqual(
                coordinator.s1Machine?.sessionStore
                    .pendingDeletionAssetIDsByRangeID["范围-2"],
                ["资产-B"]
            )
            XCTAssertEqual(
                coordinator.s1Machine?.sessionStore.allPendingDeletionAssetIDs,
                ["资产-A", "资产-B"]
            )
            XCTAssertNil(
                coordinator.s1Machine?.sessionStore
                    .firstMarkedRangeIDByAssetID["资产-S"]
            )
        }
    }

    // IC048-006：S5-EXIT 清空旧 M、K、F，重建 sessionID，并以兼容落点显示 S1。
    func testIC048_006S5ExitEndsSessionAndRebuildsS1Session() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileManager = IsolatedFileManager(
            applicationSupportRoot: temporaryRoot
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        try await MainActor.run {
            let persistence = SessionPersistence(fileManager: fileManager)
            let coordinator = CleanupCoordinator(persistence: persistence)
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-已结束"))
            completeRead(
                coordinator: coordinator,
                ranges: [
                    S1Range(
                        id: "范围-旧",
                        displayName: "旧范围",
                        assetIDsNewestFirst: ["资产-旧"]
                    )
                ]
            )
            openRange("范围-旧", coordinator: coordinator)
            XCTAssertTrue(coordinator.s2Machine?.handleSwipeUp() == true)
            guard let oldPayload = coordinator.s2Machine?.makeExitPayload() else {
                return XCTFail("旧会话应形成 S2 返回载荷")
            }
            XCTAssertTrue(coordinator.leaveS2(with: oldPayload))
            XCTAssertFalse(
                coordinator.s1Machine?.sessionStore
                    .pendingDeletionAssetIDsByRangeID.isEmpty == true
            )
            XCTAssertFalse(
                coordinator.s1Machine?.sessionStore
                    .continuationsByRangeID.isEmpty == true
            )
            XCTAssertFalse(
                coordinator.s1Machine?.sessionStore
                    .firstMarkedRangeIDByAssetID.isEmpty == true
            )

            let snapshot = SubmissionSnapshot(
                submissionID: "提交-S5-EXIT",
                assetIDs: ["资产-旧"],
                assetCount: 1,
                knownTotalBytes: 1,
                unavailableCount: 0,
                volumeDisplayMode: .exact,
                favoriteAssetIDs: [],
                frozenAt: Date(timeIntervalSince1970: 1_786_291_200)
            )
            let completion = try S5StateMachine.enter(
                from: .success(
                    snapshot: snapshot,
                    result: S4SuccessResult(
                        submissionID: snapshot.submissionID,
                        successfulAssetIDs: Set(snapshot.assetIDs),
                        receivedAt: snapshot.frozenAt
                    ),
                    downstreamTargetState: .movedToRecentlyDeleted
                ),
                persist: { _ in },
                invalidateOldLists: { _ in }
            )
            try persistence.save(PersistedSession(s5: completion.persistentState))

            coordinator.start()
            XCTAssertEqual(coordinator.route, .completion)
            coordinator.leaveCompletion()

            XCTAssertEqual(coordinator.route, .finished)
            XCTAssertNotNil(coordinator.s1Machine)
            XCTAssertNotEqual(
                coordinator.s1Machine?.sessionStore.sessionID,
                "会话-已结束"
            )
            XCTAssertTrue(
                coordinator.s1Machine?.sessionStore
                    .pendingDeletionAssetIDsByRangeID.isEmpty == true
            )
            XCTAssertTrue(
                coordinator.s1Machine?.sessionStore
                    .continuationsByRangeID.isEmpty == true
            )
            XCTAssertTrue(
                coordinator.s1Machine?.sessionStore
                    .firstMarkedRangeIDByAssetID.isEmpty == true
            )
            XCTAssertNil(coordinator.s2Machine)
            XCTAssertNil(coordinator.s3Machine)
            XCTAssertNil(coordinator.s4Machine)
            XCTAssertNil(coordinator.s5Machine)
            XCTAssertNil(persistence.load())
        }
    }

    @MainActor
    private func makeReadyCoordinator(
        sessionID: String,
        ranges: [S1Range]
    ) -> CleanupCoordinator {
        let coordinator = CleanupCoordinator()
        XCTAssertTrue(coordinator.enterS1(sessionID: sessionID))
        completeRead(coordinator: coordinator, ranges: ranges)
        return coordinator
    }

    @MainActor
    private func completeRead(
        coordinator: CleanupCoordinator,
        ranges: [S1Range]
    ) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
    }

    @MainActor
    private func makeGroupedCoordinator(
        sessionID: String
    ) -> CleanupCoordinator {
        let coordinator = makeReadyCoordinator(
            sessionID: sessionID,
            ranges: [
                S1Range(
                    id: "范围-1",
                    displayName: "月份范围",
                    assetIDsNewestFirst: ["资产-S", "资产-A"]
                ),
                S1Range(
                    id: "范围-2",
                    displayName: "相册范围",
                    assetIDsNewestFirst: ["资产-B", "资产-S"]
                )
            ]
        )
        mark(
            ["资产-A", "资产-S"],
            in: "范围-1",
            coordinator: coordinator
        )
        mark(
            ["资产-B", "资产-S"],
            in: "范围-2",
            coordinator: coordinator
        )
        return coordinator
    }

    @MainActor
    private func mark(
        _ assetIDs: Set<String>,
        in rangeID: String,
        coordinator: CleanupCoordinator
    ) {
        guard let machine = coordinator.s1Machine,
              let range = machine.ranges.first(where: { $0.id == rangeID }) else {
            return XCTFail("应找到待标记范围")
        }
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                assetIDs,
                entryContext: SessionStore.S2EntryContext(
                    rangeID: rangeID,
                    orderedAssetIDs: range.orderedAssetIDs(
                        for: machine.sortOrder
                    ),
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            )
        )
    }

    @MainActor
    private func openRange(
        _ rangeID: String,
        coordinator: CleanupCoordinator
    ) {
        guard let handoff = coordinator.s1Machine?.makeS2Handoff(
            for: rangeID
        ) else {
            return XCTFail("应形成 S1 到 S2 的交接")
        }
        XCTAssertTrue(coordinator.enterS2(from: handoff))
    }

    @MainActor
    private func assertS3Contract(
        coordinator: CleanupCoordinator,
        expectedSessionID: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            coordinator.route,
            .confirmation,
            file: file,
            line: line
        )
        XCTAssertEqual(
            coordinator.s3Machine?.sourceSessionID,
            expectedSessionID,
            file: file,
            line: line
        )
        // IC-127 E（未定项 8）：总表 = 分组按 R(T) 顺序拼接，组内按当前 O（新到旧）
        // 的 A(r, O)：范围-1 = [资产-S, 资产-A]，范围-2 = [资产-B]。
        XCTAssertEqual(
            coordinator.s3Machine?.assets.map(\.identifier),
            ["资产-S", "资产-A", "资产-B"],
            file: file,
            line: line
        )
        XCTAssertEqual(
            coordinator.s3Groups,
            [
                SessionStore.S3Submission.Group(
                    sourceRangeID: "范围-1",
                    name: "月份范围",
                    orderedAssetIDs: ["资产-S", "资产-A"]
                ),
                SessionStore.S3Submission.Group(
                    sourceRangeID: "范围-2",
                    name: "相册范围",
                    orderedAssetIDs: ["资产-B"]
                )
            ],
            file: file,
            line: line
        )
        XCTAssertEqual(
            coordinator.s3Groups.map(\.assetCount),
            [2, 1],
            file: file,
            line: line
        )
        XCTAssertEqual(
            coordinator.s3Groups.reduce(0) { $0 + $1.assetCount },
            coordinator.s3Machine?.assetCount,
            file: file,
            line: line
        )
    }
}

// MARK: - IC-127（并入本文件：工程文件未在授权范围内，新增测试文件无法登记）

/// IC-127 B（未定项 11）：S1 会话跨启动持久化。
final class S1SessionPersistenceTests: XCTestCase {
    private final class IsolatedFileManager: FileManager {
        private let applicationSupportRoot: URL

        init(applicationSupportRoot: URL) {
            self.applicationSupportRoot = applicationSupportRoot
            super.init()
        }

        override func urls(
            for directory: FileManager.SearchPathDirectory,
            in domainMask: FileManager.SearchPathDomainMask
        ) -> [URL] {
            if directory == .applicationSupportDirectory,
               domainMask.contains(.userDomainMask) {
                return [applicationSupportRoot]
            }
            return super.urls(for: directory, in: domainMask)
        }
    }

    private var temporaryRoot: URL!
    private var persistence: SessionPersistence!

    override func setUp() {
        super.setUp()
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        persistence = SessionPersistence(
            fileManager: IsolatedFileManager(applicationSupportRoot: temporaryRoot)
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryRoot)
        persistence = nil
        temporaryRoot = nil
        super.tearDown()
    }

    // 写入—重启—恢复往返后 M／K／F／T／O 逐项相等，sessionID 相同。
    func testIC127B_ArchiveRoundTripRestoresMKFTAndO() throws {
        let machine = makeMachine(sessionID: "会话-往返", sortOrder: .oldestFirst)
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["资产-B", "资产-A"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "范围-年",
                    orderedAssetIDs: ["资产-A", "资产-B", "资产-C"],
                    sortOrder: .oldestFirst
                )
            )
        )
        XCTAssertTrue(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: "会话-往返",
                    sourceRangeID: "范围-年",
                    pendingDeletionAssetIDs: ["资产-B"],
                    currentAssetID: "资产-B",
                    farthestAssetID: "资产-C"
                ),
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "范围-年",
                    orderedAssetIDs: ["资产-A", "资产-B", "资产-C"],
                    sortOrder: .oldestFirst
                )
            )
        )
        let snapshot = machine.sessionSnapshot

        try persistence.saveS1Session(snapshot)
        let loaded = try XCTUnwrap(persistence.loadS1Session())
        XCTAssertEqual(loaded, snapshot)

        let restored = try XCTUnwrap(S1StateMachine.restore(from: loaded))
        XCTAssertEqual(restored.sessionStore.sessionID, "会话-往返")
        XCTAssertEqual(
            restored.sessionStore.pendingDeletionAssetIDsByRangeID,
            machine.sessionStore.pendingDeletionAssetIDsByRangeID
        )
        XCTAssertEqual(
            restored.sessionStore.continuationsByRangeID,
            machine.sessionStore.continuationsByRangeID
        )
        XCTAssertEqual(
            restored.sessionStore.firstMarkedRangeIDByAssetID,
            machine.sessionStore.firstMarkedRangeIDByAssetID
        )
        XCTAssertEqual(restored.sessionStore, machine.sessionStore)
        XCTAssertEqual(restored.groupingDimension, .date)
        XCTAssertEqual(restored.sortOrder, .oldestFirst)
        XCTAssertEqual(restored.state, .loading)
        XCTAssertEqual(restored.sessionSnapshot, snapshot)
    }

    // 会话快照只经单一出口写出：M／T／O 每次变化各写一次，无变化的赋值不写。
    func testIC127B_SnapshotIsPublishedThroughSingleSinkOnEveryChange() {
        let machine = makeMachine(sessionID: "会话-出口", sortOrder: .newestFirst)
        var published: [S1SessionSnapshot] = []
        machine.persistenceSink = { published.append($0) }

        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["资产-A"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "范围-年",
                    orderedAssetIDs: ["资产-C", "资产-B", "资产-A"],
                    sortOrder: .newestFirst
                )
            )
        )
        XCTAssertEqual(published.count, 1)
        XCTAssertEqual(
            published.last?.pendingDeletionAssetIDsByRangeID["范围-年"],
            ["资产-A"]
        )

        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(published.count, 2)
        XCTAssertEqual(published.last?.sortOrder, .oldestFirst)

        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        XCTAssertEqual(published.count, 3)
        XCTAssertEqual(published.last?.groupingDimension, .album)

        XCTAssertFalse(machine.switchGroupingDimension(to: .album))
        XCTAssertFalse(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(published.count, 3)
        XCTAssertEqual(published.last, machine.sessionSnapshot)
    }

    // 坏档（违反 F 单值／子集不变量、未知维度）不恢复。
    func testIC127B_CorruptArchiveIsRejected() throws {
        XCTAssertNil(
            SessionStore(
                sessionID: "会话-坏档",
                pendingDeletionAssetIDsByRangeID: ["r": ["a"]],
                continuationsByRangeID: [:],
                firstMarkedRangeIDByAssetID: [:]
            )
        )
        XCTAssertNil(
            SessionStore(
                sessionID: "会话-坏档",
                pendingDeletionAssetIDsByRangeID: ["r": ["a"]],
                continuationsByRangeID: [:],
                firstMarkedRangeIDByAssetID: ["a": "other"]
            )
        )
        XCTAssertNotNil(
            SessionStore(
                sessionID: "会话-好档",
                pendingDeletionAssetIDsByRangeID: ["r": ["a"]],
                continuationsByRangeID: [:],
                firstMarkedRangeIDByAssetID: ["a": "r"]
            )
        )
        let unknownDimension = PersistedS1Session(
            S1SessionSnapshot(
                sessionID: "会话-坏档",
                groupingDimension: .date,
                sortOrder: .newestFirst,
                pendingDeletionAssetIDsByRangeID: [:],
                continuationsByRangeID: [:],
                firstMarkedRangeIDByAssetID: [:]
            )
        )
        var json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(unknownDimension)
        ) as? [String: Any] ?? [:]
        json["groupingDimension"] = "month"
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(PersistedS1Session.self, from: data)
        XCTAssertNil(decoded.snapshot)
    }

    // 协调器层往返：A 写档，B 从档恢复同一 sessionID 与 T／O；恢复后先过对账再就绪。
    func testIC127B_CoordinatorRestoresArchivedSessionAndReconcilesBeforeReady() async {
        await MainActor.run {
            let service = PhotoLibraryService(s1Source: makeSource())
            let first = CleanupCoordinator(
                photoLibrary: service,
                persistence: persistence
            )
            XCTAssertTrue(first.enterS1(sessionID: "会话-恢复"))
            readThroughCoordinator(first)
            let firstMachine = tryUnwrap(first.s1Machine)
            let yearID = tryUnwrap(firstMachine.topLevelRanges.first?.id)
            let yearAssets = tryUnwrap(
                firstMachine.ranges.first { $0.id == yearID }?.assetIDsNewestFirst
            )
            XCTAssertTrue(firstMachine.switchSortOrder(to: .oldestFirst))
            XCTAssertTrue(
                firstMachine.applyS2PendingDeletionChange(
                    ["资产-1"],
                    entryContext: SessionStore.S2EntryContext(
                        rangeID: yearID,
                        orderedAssetIDs: Array(yearAssets.reversed()),
                        sortOrder: .oldestFirst
                    )
                )
            )
            XCTAssertEqual(persistence.loadS1Session()?.sessionID, "会话-恢复")

            let second = CleanupCoordinator(
                photoLibrary: service,
                persistence: persistence
            )
            XCTAssertTrue(second.enterS1ResumingPersistedSessionOrStartNew())
            let restored = tryUnwrap(second.s1Machine)
            XCTAssertEqual(second.route, .s1)
            XCTAssertEqual(restored.sessionStore.sessionID, "会话-恢复")
            XCTAssertEqual(restored.groupingDimension, .date)
            XCTAssertEqual(restored.sortOrder, .oldestFirst)
            XCTAssertEqual(restored.sessionStore, firstMachine.sessionStore)
            XCTAssertEqual(restored.state, .loading)
            XCTAssertEqual(restored.reconciliationCount, 0)

            readThroughCoordinator(second)
            XCTAssertEqual(restored.reconciliationCount, 1)
            XCTAssertEqual(restored.state, .ready)
            XCTAssertEqual(
                restored.sessionStore.pendingDeletionAssetIDsByRangeID[yearID],
                ["资产-1"]
            )
        }
    }

    // sessionID 结束（S5 离开）后档被清除，下一次进入取默认 T=date、O=newestFirst 与新 sessionID。
    func testIC127B_EndedSessionClearsArchiveAndNextEntryUsesDefaults() async throws {
        try await MainActor.run {
            let coordinator = CleanupCoordinator(persistence: persistence)
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-已结束"))
            let machine = tryUnwrap(coordinator.s1Machine)
            let request = tryUnwrap(machine.currentReadRequest)
            XCTAssertTrue(
                machine.completeRangeRead(
                    .success([
                        S1Range(
                            id: "范围-旧",
                            displayName: "旧范围",
                            assetIDsNewestFirst: ["资产-旧"]
                        )
                    ]),
                    for: request
                )
            )
            XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
            XCTAssertTrue(
                machine.applyS2PendingDeletionChange(
                    ["资产-旧"],
                    entryContext: SessionStore.S2EntryContext(
                        rangeID: "范围-旧",
                        orderedAssetIDs: ["资产-旧"],
                        sortOrder: .oldestFirst
                    )
                )
            )
            XCTAssertEqual(persistence.loadS1Session()?.sessionID, "会话-已结束")
            XCTAssertEqual(persistence.loadS1Session()?.sortOrder, .oldestFirst)

            // 与 IC048-006 同一条路径：S5 成功记录 → 启动恢复 S5 → 离开 → finishSession。
            let snapshot = SubmissionSnapshot(
                submissionID: "提交-IC127B",
                assetIDs: ["资产-旧"],
                assetCount: 1,
                knownTotalBytes: 1,
                unavailableCount: 0,
                volumeDisplayMode: .exact,
                favoriteAssetIDs: [],
                frozenAt: Date(timeIntervalSince1970: 1_786_291_200)
            )
            let completion = try S5StateMachine.enter(
                from: .success(
                    snapshot: snapshot,
                    result: S4SuccessResult(
                        submissionID: snapshot.submissionID,
                        successfulAssetIDs: Set(snapshot.assetIDs),
                        receivedAt: snapshot.frozenAt
                    ),
                    downstreamTargetState: .movedToRecentlyDeleted
                ),
                persist: { _ in },
                invalidateOldLists: { _ in }
            )
            try persistence.save(PersistedSession(s5: completion.persistentState))
            coordinator.start()
            XCTAssertEqual(coordinator.route, .completion)
            coordinator.leaveCompletion()

            XCTAssertEqual(coordinator.route, .finished)
            XCTAssertNil(persistence.loadS1Session())
            XCTAssertNil(persistence.load())
            let next = tryUnwrap(coordinator.s1Machine)
            XCTAssertNotEqual(next.sessionStore.sessionID, "会话-已结束")
            XCTAssertEqual(next.groupingDimension, .date)
            XCTAssertEqual(next.sortOrder, .newestFirst)
            XCTAssertTrue(next.sessionStore.pendingDeletionAssetIDsByRangeID.isEmpty)

            // 再次启动：无档 → 默认值 + 新 sessionID。
            let fresh = CleanupCoordinator(persistence: persistence)
            XCTAssertTrue(fresh.enterS1ResumingPersistedSessionOrStartNew())
            let freshMachine = tryUnwrap(fresh.s1Machine)
            XCTAssertNotEqual(freshMachine.sessionStore.sessionID, "会话-已结束")
            XCTAssertEqual(freshMachine.groupingDimension, .date)
            XCTAssertEqual(freshMachine.sortOrder, .newestFirst)
            XCTAssertTrue(freshMachine.sessionStore.firstMarkedRangeIDByAssetID.isEmpty)
        }
    }

    // 回归：S3→S4 提交快照档（session.json）与 S1 档分文件，互不影响存取与清除。
    func testIC127B_LegacySubmissionRecordStillRoundTripsAlongsideS1Archive() throws {
        let s1Snapshot = S1SessionSnapshot(
            sessionID: "会话-并存",
            groupingDimension: .album,
            sortOrder: .newestFirst,
            pendingDeletionAssetIDsByRangeID: ["相册": ["资产-A"]],
            continuationsByRangeID: [:],
            firstMarkedRangeIDByAssetID: ["资产-A": "相册"]
        )
        try persistence.saveS1Session(s1Snapshot)
        XCTAssertNil(persistence.load())

        let snapshot = SubmissionSnapshot(
            submissionID: "提交-并存",
            assetIDs: ["资产-A"],
            assetCount: 1,
            knownTotalBytes: 1,
            unavailableCount: 0,
            volumeDisplayMode: .exact,
            favoriteAssetIDs: [],
            frozenAt: Date(timeIntervalSince1970: 1_786_291_200)
        )
        let completion = try S5StateMachine.enter(
            from: .success(
                snapshot: snapshot,
                result: S4SuccessResult(
                    submissionID: snapshot.submissionID,
                    successfulAssetIDs: Set(snapshot.assetIDs),
                    receivedAt: snapshot.frozenAt
                ),
                downstreamTargetState: .movedToRecentlyDeleted
            ),
            persist: { _ in },
            invalidateOldLists: { _ in }
        )
        let record = PersistedSession(s5: completion.persistentState)
        try persistence.save(record)

        let loaded = try XCTUnwrap(persistence.load())
        XCTAssertEqual(loaded.phase, .completionSuccess)
        XCTAssertEqual(loaded.snapshot.submissionID, "提交-并存")
        XCTAssertEqual(persistence.loadS1Session(), s1Snapshot)
        XCTAssertFalse(try persistence.claim(record))

        try persistence.clear()
        XCTAssertNil(persistence.load())
        XCTAssertEqual(persistence.loadS1Session(), s1Snapshot)

        try persistence.clearS1Session()
        XCTAssertNil(persistence.loadS1Session())
        try persistence.clearS1Session()
    }

    // MARK: - Fixtures

    private func makeMachine(
        sessionID: String,
        sortOrder: S1SortOrder
    ) -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: sessionID),
            initialGroupingDimension: .date,
            initialSortOrder: sortOrder
        )
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "范围-年",
                        displayName: "2026",
                        assetIDsNewestFirst: ["资产-C", "资产-B", "资产-A"]
                    )
                ]),
                for: request
            )
        )
        return machine
    }

    private func makeSource() -> S1PhotoLibrarySource {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let assets = [3, 2, 1].map { day -> S1PhotoAssetSnapshot in
            let date = calendar.date(
                from: DateComponents(year: 2026, month: 8, day: day, hour: 12)
            )!
            return S1PhotoAssetSnapshot(identifier: "资产-\(day)", creationDate: date)
        }
        return S1PhotoLibrarySource(
            authorizationStatus: { .authorized },
            fetchAssets: { assets },
            fetchAssetCollections: { _, _ in [] }
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
