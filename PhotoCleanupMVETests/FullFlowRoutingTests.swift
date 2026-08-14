import Foundation
import XCTest
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
        XCTAssertEqual(
            coordinator.s3Machine?.assets.map(\.identifier),
            ["资产-A", "资产-B", "资产-S"],
            file: file,
            line: line
        )
        XCTAssertEqual(
            coordinator.s3Groups,
            [
                SessionStore.S3Submission.Group(
                    sourceRangeID: "范围-1",
                    name: "月份范围",
                    orderedAssetIDs: ["资产-A", "资产-S"]
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
