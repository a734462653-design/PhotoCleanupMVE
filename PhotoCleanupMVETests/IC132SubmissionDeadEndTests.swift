import Photos
import XCTest
@testable import PhotoCleanupMVE

/// IC-132 B：提交形成失败不再卡死、不再静默。
///
/// 原实装两处后果：S2 垃圾桶写回成功但 `makeS3Submission()` 为 nil 时
/// `route` 停在 `.s2` 而 `s2Machine` 已 nil，界面落到退不出的 ProgressView；
/// S1 垃圾桶同样条件下静默 `return`，徽标显示 N 却点不动。
final class IC132SubmissionDeadEndTests: XCTestCase {
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

    // 断言 5：写回**成功**但名字表为空 → enterConfirmationFromS2 返回 false、
    // route == .s1、s2Machine == nil、M／K **已**写回（与 IC-131 断言 4 的
    // 「未写回」形成对照）、事件通道恰一条 .submissionUnavailable。
    func testIC132B_SubmissionUnavailableAfterSuccessfulWriteBackReturnsToS1() async {
        await MainActor.run {
            let coordinator = makeRestoredCoordinatorInS2WithUnknownName()
            let machine = tryUnwrap(coordinator.s1Machine)
            let s2Machine = tryUnwrap(coordinator.s2Machine)
            let payload = tryUnwrap(s2Machine.makeExitPayload())

            XCTAssertFalse(coordinator.enterConfirmationFromS2(with: payload))

            // 不再卡死：确实离开了 S2。
            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertNil(coordinator.s2Machine)
            // 不进 S3、未形成提交。
            XCTAssertNil(coordinator.s3Machine)
            XCTAssertTrue(coordinator.s3Groups.isEmpty)
            // 写回**保留**：本次在 S2 标记的那张进了 M，K 也已续接。
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["相册-9"],
                payload.upstreamReturn.pendingDeletionAssetIDs
            )
            XCTAssertEqual(
                machine.sessionStore.continuationsByRangeID["相册-9"],
                SessionStore.Continuation(
                    currentAssetID: payload.upstreamReturn.currentAssetID,
                    farthestAssetID: payload.upstreamReturn.farthestAssetID,
                    recordedSortOrder: machine.sortOrder.sessionSortOrder
                )
            )
            // 档里那张未知名字的标记也还在——它正是提交形成不了的原因。
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["相册-未知"],
                ["资产-1"]
            )
            // 恰一条事件。
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 1)
            let event = tryUnwrap(coordinator.s1FeedbackEvent)
            XCTAssertEqual(event.kind, .submissionUnavailable)
            XCTAssertNil(coordinator.message)
        }
    }

    // 断言 6：不变量——两个公开入口 × 合法／非法 payload × 名字表空／满共 8 种
    // 组合，每次调用后都不得出现 route == .s2 && s2Machine == nil。
    func testIC132B_NoEntryPointLeavesRouteInS2WithoutMachine() async {
        await MainActor.run {
            for namesKnown in [true, false] {
                for legalPayload in [true, false] {
                    for viaTrash in [true, false] {
                        let coordinator = namesKnown
                            ? makeCoordinatorInS2WithKnownNames()
                            : makeRestoredCoordinatorInS2WithUnknownName()
                        let s2Machine = tryUnwrap(coordinator.s2Machine)
                        let good = tryUnwrap(s2Machine.makeExitPayload())
                        let payload = legalPayload
                            ? good
                            : mismatchedSession(good)

                        if viaTrash {
                            _ = coordinator.enterConfirmationFromS2(with: payload)
                        } else {
                            _ = coordinator.leaveS2(with: payload)
                        }

                        let label = "names=\(namesKnown) legal=\(legalPayload) trash=\(viaTrash)"
                        XCTAssertFalse(
                            coordinator.route == .s2 && coordinator.s2Machine == nil,
                            "组合 \(label) 落在了退不出的 .s2 上"
                        )
                    }
                }
            }
        }
    }

    // 断言 7（S1 视图口径层）：名字表为空且 badgeCount > 0 时，垃圾桶动作产生
    // 一条 .submissionUnavailable、onS3Submission 未被调用；名字表齐全时
    // onS3Submission 恰调用一次、无该反馈。
    func testIC132B_TrashButtonActionFallsBackToFeedbackWhenSubmissionUnavailable() {
        // 名字表为空：由不含名字的档恢复。
        let nameless = tryUnwrap(
            S1StateMachine.restore(from: snapshotWithoutNames())
        )
        let request = tryUnwrap(nameless.currentReadRequest)
        XCTAssertTrue(nameless.completeRangeRead(.success([]), for: request))
        XCTAssertEqual(nameless.badgeCount, 1)
        XCTAssertNil(nameless.makeS3Submission())

        var submissions: [SessionStore.S3Submission] = []
        var unavailableCount = 0
        S1TrashButtonAction.perform(
            machine: nameless,
            onS3Submission: { submissions.append($0) },
            onSubmissionUnavailable: { unavailableCount += 1 }
        )
        XCTAssertTrue(submissions.isEmpty)
        XCTAssertEqual(unavailableCount, 1)

        // 名字表齐全：正常交给上游。
        let named = makeMachineWithKnownName()
        submissions = []
        unavailableCount = 0
        S1TrashButtonAction.perform(
            machine: named,
            onS3Submission: { submissions.append($0) },
            onSubmissionUnavailable: { unavailableCount += 1 }
        )
        XCTAssertEqual(submissions.count, 1)
        XCTAssertEqual(unavailableCount, 0)
        XCTAssertEqual(Set(submissions[0].orderedAssetIDs), ["资产-2"])
    }

    // 断言 8：两种 kind 的文案各自经目录取得、互不相同。
    // 「源码中不存在这两条中文字面量」由硬编码扫描器覆盖（扫描范围是产品源码）。
    func testIC132B_BothFeedbackKindsResolveDistinctCatalogText() {
        let writeBackKey = "s1.toast.writeback_failed"
        let unavailableKey = "s1.toast.submission_unavailable"
        let writeBack = L10n.text(writeBackKey)
        let unavailable = L10n.text(unavailableKey)

        // 目录里确实有这两条（NSLocalizedString 找不到时原样返回 key）。
        XCTAssertNotEqual(writeBack, writeBackKey)
        XCTAssertNotEqual(unavailable, unavailableKey)
        XCTAssertNotEqual(writeBack, unavailable)
        // 逐字等于登记原文。
        XCTAssertEqual(unavailable, "暂时无法打开确认页，请重试。")
        // 呈现器经目录取值，两个分支各自对应。
        XCTAssertEqual(
            S1FeedbackToastPresenter.text(for: .writeBackFailed),
            writeBack
        )
        XCTAssertEqual(
            S1FeedbackToastPresenter.text(for: .submissionUnavailable),
            unavailable
        )
    }

    // 断言 9（端到端，证明子项 A 修好后常见路径不再走兜底）：
    // 标记 → 编解码往返 → 恢复 → 切到另一维度读取 → 提交成功进 S3。
    func testIC132B_RestoredSessionEntersS3WithoutFallbackAfterDimensionSwitch() async {
        await MainActor.run {
            // 第一次运行：相册维度标记一张，档里带上名字。
            let service = PhotoLibraryService(s1Source: makeSource())
            let first = CleanupCoordinator(
                photoLibrary: service,
                persistence: persistence
            )
            XCTAssertTrue(first.enterS1(sessionID: "会话-132B-端到端"))
            let firstMachine = tryUnwrap(first.s1Machine)
            XCTAssertTrue(firstMachine.switchGroupingDimension(to: .album))
            readThroughCoordinator(first)
            XCTAssertTrue(
                firstMachine.applyS2PendingDeletionChange(
                    ["资产-2"],
                    entryContext: SessionStore.S2EntryContext(
                        rangeID: "相册-9",
                        orderedAssetIDs: albumOrderedAssetIDs(firstMachine),
                        sortOrder: firstMachine.sortOrder.sessionSortOrder
                    )
                )
            )
            // 档里带着名字了（子项 A）。
            XCTAssertEqual(
                persistence.loadS1Session()?.rangeNamesByID["相册-9"],
                "第九相册"
            )

            // 第二次运行：恢复 → 切到按日期维度读取（读不到相册范围）。
            let second = CleanupCoordinator(
                photoLibrary: service,
                persistence: persistence
            )
            XCTAssertTrue(second.enterS1ResumingPersistedSessionOrStartNew())
            let restored = tryUnwrap(second.s1Machine)
            XCTAssertEqual(restored.groupingDimension, .album)
            XCTAssertTrue(restored.switchGroupingDimension(to: .date))
            readThroughCoordinator(second)
            XCTAssertEqual(restored.state, .ready)
            XCTAssertEqual(restored.badgeCount, 1)

            // 常见路径：提交能形成，直接进 S3，不走兜底、不发事件。
            let submission = tryUnwrap(restored.makeS3Submission())
            XCTAssertEqual(
                submission.groups.map(\.name),
                ["第九相册"]
            )
            XCTAssertTrue(second.enterConfirmationFromS1(submission))
            // 卡内写作「route == .s3」，实际枚举例名为 `.confirmation`（S3 页）。
            XCTAssertEqual(second.route, .confirmation)
            XCTAssertEqual(second.s1FeedbackEventCount, 0)
            XCTAssertNil(second.s1FeedbackEvent)
        }
    }

    // MARK: - 夹具

    private let assetIDs = ["资产-1", "资产-2", "资产-3"]

    private func makeSource() -> S1PhotoLibrarySource {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let assets = assetIDs.enumerated().map { index, identifier in
            S1PhotoAssetSnapshot(
                identifier: identifier,
                creationDate: calendar.date(
                    from: DateComponents(
                        year: 2026,
                        month: 8,
                        day: index + 1,
                        hour: 12
                    )
                )!
            )
        }
        return S1PhotoLibrarySource(
            authorizationStatus: { .authorized },
            fetchAssets: { assets },
            fetchAssetCollections: { _, _ in
                [
                    S1AlbumCollectionSnapshot(
                        identifier: "相册-9",
                        localizedTitle: "第九相册",
                        collectionType: .album,
                        collectionSubtype: .albumRegular,
                        isHidden: false,
                        assets: assets.filter { $0.identifier != "资产-1" }
                    )
                ]
            },
            fetchExistingAssetIdentifiers: { identifiers in
                // 全部资产都还在——存在性对账不该剔除档里那张。
                Set(identifiers).intersection(Set(assets.map(\.identifier)))
            }
        )
    }

    /// 档：相册维度、`M` 里有一张属于**读不到的范围**且名字未知。
    private func snapshotWithoutNames() -> S1SessionSnapshot {
        S1SessionSnapshot(
            sessionID: "会话-132B-无名",
            groupingDimension: .album,
            sortOrder: .newestFirst,
            pendingDeletionAssetIDsByRangeID: ["相册-未知": ["资产-1"]],
            continuationsByRangeID: [:],
            firstMarkedRangeIDByAssetID: ["资产-1": "相册-未知"],
            rangeNamesByID: [:]
        )
    }

    /// 由无名档恢复的协调器，读到 `相册-9` 后进入 S2 并标记一张。
    /// 此时写回能成功，但 `M` 里 `相册-未知` 没有名字，提交形成不了。
    @MainActor
    private func makeRestoredCoordinatorInS2WithUnknownName() -> CleanupCoordinator {
        try? persistence.saveS1Session(snapshotWithoutNames())
        let coordinator = CleanupCoordinator(
            photoLibrary: PhotoLibraryService(s1Source: makeSource()),
            persistence: persistence
        )
        XCTAssertTrue(coordinator.enterS1ResumingPersistedSessionOrStartNew())
        readThroughCoordinator(coordinator)
        let machine = tryUnwrap(coordinator.s1Machine)
        XCTAssertEqual(machine.state, .ready)
        XCTAssertNil(machine.makeS3Submission())
        openRangeAndMark("相册-9", coordinator: coordinator)
        return coordinator
    }

    /// 正常协调器：名字表齐全。
    @MainActor
    private func makeCoordinatorInS2WithKnownNames() -> CleanupCoordinator {
        let coordinator = CleanupCoordinator(
            photoLibrary: PhotoLibraryService(s1Source: makeSource()),
            persistence: persistence
        )
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-132B-有名"))
        let machine = tryUnwrap(coordinator.s1Machine)
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        readThroughCoordinator(coordinator)
        openRangeAndMark("相册-9", coordinator: coordinator)
        return coordinator
    }

    /// 直接构造一个名字齐全、已标记一张的状态机（断言 7 的对照组）。
    private func makeMachineWithKnownName() -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-132B-有名机"),
            initialGroupingDimension: .album,
            initialSortOrder: .newestFirst
        )
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "相册-9",
                        displayName: "第九相册",
                        assetIDsNewestFirst: ["资产-3", "资产-2"]
                    )
                ]),
                for: request
            )
        )
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["资产-2"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "相册-9",
                    orderedAssetIDs: ["资产-3", "资产-2"],
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            )
        )
        return machine
    }

    @MainActor
    private func readThroughCoordinator(_ coordinator: CleanupCoordinator) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        let response = coordinator.readS1Ranges(
            groupedBy: request.groupingDimension
        )
        XCTAssertTrue(
            machine.completeRangeRead(
                response.result,
                for: request,
                isLimitedAuthorization: response.isLimitedAuthorization
            )
        )
    }

    @MainActor
    private func openRangeAndMark(
        _ rangeID: String,
        coordinator: CleanupCoordinator
    ) {
        guard let handoff = coordinator.s1Machine?.makeS2Handoff(for: rangeID) else {
            return XCTFail("应形成 S1 到 S2 的交接")
        }
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        XCTAssertTrue(coordinator.s2Machine?.handleSwipeUp() == true)
    }

    private func albumOrderedAssetIDs(_ machine: S1StateMachine) -> [String] {
        machine.ranges
            .first { $0.id == "相册-9" }?
            .orderedAssetIDs(for: machine.sortOrder) ?? []
    }

    private func mismatchedSession(_ payload: S2ExitPayload) -> S2ExitPayload {
        S2ExitPayload(
            upstreamReturn: SessionStore.S2Return(
                sourceSessionID: "别的会话-132B",
                sourceRangeID: payload.upstreamReturn.sourceRangeID,
                pendingDeletionAssetIDs:
                    payload.upstreamReturn.pendingDeletionAssetIDs,
                currentAssetID: payload.upstreamReturn.currentAssetID,
                farthestAssetID: payload.upstreamReturn.farthestAssetID
            ),
            continuationSnapshot: payload.continuationSnapshot
        )
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("期望非空值", file: file, line: line)
            fatalError("期望非空值")
        }
        return value
    }
}
