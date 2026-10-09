import Foundation
import Photos
import XCTest
@testable import PhotoCleanupMVE

/// IC-194：S3 返回落点（SPEC-S1 v12 决策 47、第二节 `src3`、第七节第 4 部分；SPEC-S3-S4 v10 第一节；
/// SPEC-S0 v6 第十节第 6 部分）。
/// A 真实范围：S2 经待删篮进 S3，返回重进那次 S2——起点是离开时那张 `K[r]`（不是第一张没看过的）、`D` 随 S3 移除更新；
///   再从 S2 返回回到 S1。
/// B 类别范围（`cat:`）：沿用进 S3 前的列表、剔除已不在库中的；`K` 被删回退到第一张没看过的、`K` 在则从 `K` 开始；
///   全被删则留在上游、不留在途登记。
/// C 其余来源：S1 提交路径进 S3 不记落点、返回落上游；S2 记下的落点被随后 S1 侧进 S3 抹掉；重进交接的守卫与回退。
/// D 经 S5「返回确认页」中转：删除被取消 → 返回确认页 → 返回，仍重进原 S2。
/// E 冷启动恢复「已取消」完成页 → 返回确认页 → 返回：没有会话，有 S1 会话档就恢复、无档开新，落「逐张整理」。
/// F 源码落位。
///
/// **夹具驱动**：照片库存在性与删除结果是注入的夹具；手势、界面过渡与 tab 落点真机未覆盖（H102）。
final class IC194S3ReturnLandingTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"

    private static let monthAssets = ["资产-D", "资产-C", "资产-B", "资产-A"]
    private static let screenshotAssets = ["截图-大", "截图-中", "截图-小", "截图-微"]

    // MARK: - A 真实范围

    @MainActor
    func testIC194A_RealRangeReturnReentersS2AtLeftAsset() throws {
        let coordinator = makeCoordinator()
        try enterS3FromMonthRange(coordinator, sessionID: "会话-194A")
        XCTAssertEqual(
            coordinator.s3ReturnTarget,
            CleanupCoordinator.S3ReturnTarget(
                rangeID: "范围-月",
                displayName: "2026 年 8 月",
                orderedAssetIDs: Self.monthAssets,
                isVirtual: false
            )
        )
        XCTAssertEqual(
            coordinator.s1Machine?.sessionStore.continuationsByRangeID["范围-月"]?.currentAssetID,
            "资产-B"
        )

        coordinator.removeAsset("资产-D")
        coordinator.leaveConfirmation()

        XCTAssertEqual(coordinator.route, .s2)
        XCTAssertNil(coordinator.s3ReturnTarget)
        let s2 = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertEqual(s2.entry.rangeDisplayInformation.rangeID, "范围-月")
        XCTAssertEqual(s2.orderedAssetIDs, Self.monthAssets)
        // 第一张没看过的是 A；落位取离开时那张 B。
        XCTAssertEqual(s2.currentAssetID, "资产-B")
        XCTAssertEqual(s2.pendingDeletionAssetIDs, Set(["资产-C"]))
        XCTAssertEqual(coordinator.s1Machine?.sessionStore.allPendingDeletionAssetIDs, Set(["资产-C"]))

        let payload = try XCTUnwrap(s2.makeExitPayload())
        XCTAssertTrue(coordinator.leaveS2(with: payload))
        XCTAssertEqual(coordinator.route, .s1)
        XCTAssertNil(coordinator.s3ReturnTarget)
        XCTAssertNil(coordinator.s2Machine)
    }

    // MARK: - B 类别范围

    @MainActor
    func testIC194B_CategoryRangeReentryKeepsListDropsDeletedAndFallsBack() throws {
        let existence = IC194ExistenceBox()
        let coordinator = makeCoordinator(existence: existence)
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-194B"))
        completeRead(coordinator, ranges: [
            S1Range(id: "范围-月", displayName: "2026 年 8 月", assetIDsNewestFirst: ["资产-A"])
        ])
        let machine = try XCTUnwrap(coordinator.s1Machine)
        let assets = Self.screenshotAssets
        let handoff = try XCTUnwrap(
            machine.makeS2Handoff(virtualRangeID: "cat:screenshot",
                                  displayName: "屏幕截图",
                                  orderedAssetIDs: assets,
                                  currentAssetID: assets[1])
        )
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        // 标记「中」并自动进入「小」：看过 = {中, 小}，离开时那张 = 小。
        XCTAssertTrue(try XCTUnwrap(coordinator.s2Machine).handleSwipeUp())
        XCTAssertEqual(coordinator.s2Machine?.currentAssetID, "截图-小")
        try trash(coordinator)
        XCTAssertEqual(
            coordinator.s3ReturnTarget,
            CleanupCoordinator.S3ReturnTarget(
                rangeID: "cat:screenshot",
                displayName: "屏幕截图",
                orderedAssetIDs: assets,
                isVirtual: true
            )
        )
        XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)

        // 一、离开时那张「小」已被删：列表剔除它，起点回退到第一张没看过的「大」。
        existence.missing = ["截图-小"]
        coordinator.leaveConfirmation()
        XCTAssertEqual(coordinator.route, .s2)
        var s2 = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertEqual(s2.entry.rangeDisplayInformation.rangeID, "cat:screenshot")
        XCTAssertEqual(s2.entry.rangeDisplayInformation.displayName, "屏幕截图")
        XCTAssertEqual(s2.orderedAssetIDs, ["截图-大", "截图-中", "截图-微"])
        XCTAssertEqual(s2.currentAssetID, "截图-大")
        XCTAssertEqual(s2.pendingDeletionAssetIDs, Set(["截图-中"]))
        XCTAssertEqual(machine.activeVirtualRangeIDs, Set(["cat:screenshot"]))
        XCTAssertNil(coordinator.s3ReturnTarget)

        // 二、标记「大」并自动进入「中」，再进 S3、返回：离开时那张「中」还在，从它开始。
        XCTAssertTrue(s2.handleSwipeUp())
        XCTAssertEqual(coordinator.s2Machine?.currentAssetID, "截图-中")
        try trash(coordinator)
        XCTAssertEqual(coordinator.s3ReturnTarget?.orderedAssetIDs, ["截图-大", "截图-中", "截图-微"])
        XCTAssertEqual(coordinator.s3ReturnTarget?.isVirtual, true)
        coordinator.leaveConfirmation()
        XCTAssertEqual(coordinator.route, .s2)
        s2 = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertEqual(s2.currentAssetID, "截图-中")
        XCTAssertEqual(s2.pendingDeletionAssetIDs, Set(["截图-大", "截图-中"]))

        // 三、列表里的照片全被删：不进 S2、留在上游，不留在途登记。
        try trash(coordinator)
        existence.missing = Set(assets)
        coordinator.leaveConfirmation()
        XCTAssertEqual(coordinator.route, .upstream)
        XCTAssertNil(coordinator.s2Machine)
        XCTAssertNil(coordinator.s3ReturnTarget)
        XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)
    }

    // MARK: - C 其余来源与守卫

    @MainActor
    func testIC194C_OtherSourcesLandUpstreamAndReentryHandoffGuards() throws {
        // 一、S1 提交路径：不记落点，返回落上游。
        let fromS1 = makeCoordinator()
        XCTAssertTrue(fromS1.enterS1(sessionID: "会话-194C1"))
        completeRead(fromS1, ranges: [Self.monthRange(Self.monthAssets)])
        let opened = try XCTUnwrap(fromS1.s1Machine?.makeS2Handoff(for: "范围-月"))
        XCTAssertTrue(fromS1.enterS2(from: opened))
        XCTAssertTrue(try XCTUnwrap(fromS1.s2Machine).handleSwipeUp())
        XCTAssertTrue(fromS1.leaveS2(with: try XCTUnwrap(fromS1.s2Machine?.makeExitPayload())))
        let submission = try XCTUnwrap(fromS1.s1Machine?.makeS3Submission())
        XCTAssertTrue(fromS1.enterConfirmationFromS1(submission))
        XCTAssertNil(fromS1.s3ReturnTarget)
        fromS1.leaveConfirmation()
        XCTAssertEqual(fromS1.route, .upstream)
        XCTAssertNil(fromS1.s2Machine)

        // 二、S2 记下落点后又经 S1 侧入口进 S3：旧值被抹掉，返回落上游。
        let overridden = makeCoordinator()
        try enterS3FromMonthRange(overridden, sessionID: "会话-194C2")
        XCTAssertNotNil(overridden.s3ReturnTarget)
        let again = try XCTUnwrap(overridden.s1Machine?.makeS3Submission())
        XCTAssertTrue(overridden.enterConfirmationFromS1(again))
        XCTAssertNil(overridden.s3ReturnTarget)
        overridden.leaveConfirmation()
        XCTAssertEqual(overridden.route, .upstream)
        XCTAssertNil(overridden.s2Machine)

        // 三、重进交接：与进入交接同一份列表、待删与显示信息，只换起点；`c` 不在列表或遮挡时回退／拒绝。
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-194C3"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = try XCTUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success([Self.monthRange(Self.monthAssets)]), for: request))
        XCTAssertNil(machine.makeS2ReentryHandoff(for: "范围-无"))
        XCTAssertEqual(machine.makeS2ReentryHandoff(for: "范围-月")?.currentAssetID, "资产-D")
        // 写回要求新标已经逐张镜像写过 `F`（IC-169），先镜像再写回，`K` 记下离开时那张 B。
        let context = SessionStore.S2EntryContext(
            rangeID: "范围-月",
            orderedAssetIDs: Self.monthAssets,
            sortOrder: machine.sortOrder.sessionSortOrder
        )
        XCTAssertTrue(machine.applyS2PendingDeletionChange(["资产-C"], entryContext: context))
        XCTAssertTrue(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: "会话-194C3",
                    sourceRangeID: "范围-月",
                    pendingDeletionAssetIDs: ["资产-C"],
                    currentAssetID: "资产-B",
                    seenAssetIDs: ["资产-D"]
                ),
                entryContext: context
            )
        )
        let entry = try XCTUnwrap(machine.makeS2Handoff(for: "范围-月"))
        let reentry = try XCTUnwrap(machine.makeS2ReentryHandoff(for: "范围-月"))
        XCTAssertEqual(entry.currentAssetID, "资产-D")
        XCTAssertEqual(reentry.currentAssetID, "资产-B")
        XCTAssertEqual(reentry.sessionID, entry.sessionID)
        XCTAssertEqual(reentry.rangeDisplayInformation, entry.rangeDisplayInformation)
        XCTAssertEqual(reentry.orderedAssetIDs, entry.orderedAssetIDs)
        XCTAssertEqual(reentry.pendingDeletionAssetIDs, Set(["资产-C"]))
        XCTAssertEqual(reentry.pendingDeletionAssetIDs, entry.pendingDeletionAssetIDs)
        XCTAssertEqual(reentry.sessionMergedPendingDeletionCount, 1)

        // 「B」已不在范围里：`K` 不钳（IC-190），重进回退到第一张没看过的。
        XCTAssertTrue(machine.reconcile(with: .success([Self.monthRange(["资产-D", "资产-C", "资产-A"])])))
        XCTAssertEqual(machine.sessionStore.continuationsByRangeID["范围-月"]?.currentAssetID, "资产-B")
        XCTAssertEqual(machine.makeS2ReentryHandoff(for: "范围-月")?.currentAssetID, "资产-D")

        machine.presentObscuration()
        XCTAssertNil(machine.makeS2ReentryHandoff(for: "范围-月"))
        machine.dismissObscuration()
        XCTAssertNotNil(machine.makeS2ReentryHandoff(for: "范围-月"))
    }

    // MARK: - D 经 S5「返回确认页」中转

    @MainActor
    func testIC194D_ReturnThroughS5ConfirmationStillReentersOriginalS2() throws {
        let deletion = IC194CancellingDeletionService()
        let coordinator = makeCoordinator(deletionService: deletion)
        try enterS3FromMonthRange(coordinator, sessionID: "会话-194D")
        let target = try XCTUnwrap(coordinator.s3ReturnTarget)

        XCTAssertTrue(waitUntil { coordinator.s3Machine?.isScanComplete == true })
        coordinator.submitDeletion()
        XCTAssertEqual(deletion.startCount, 1)
        XCTAssertTrue(waitUntil { coordinator.route == .completion })
        XCTAssertEqual(coordinator.route, .completion)
        let state = try XCTUnwrap(coordinator.s5Machine?.state)
        guard case .cancelled = state else {
            return XCTFail("删除被取消应落 S5 已取消态")
        }
        XCTAssertEqual(coordinator.s3ReturnTarget, target)

        coordinator.returnToConfirmation()
        XCTAssertEqual(coordinator.route, .confirmation)
        XCTAssertEqual(coordinator.s3ReturnTarget, target)

        coordinator.leaveConfirmation()
        XCTAssertEqual(coordinator.route, .s2)
        XCTAssertNil(coordinator.s3ReturnTarget)
        XCTAssertEqual(coordinator.s2Machine?.entry.rangeDisplayInformation.rangeID, "范围-月")
        XCTAssertEqual(coordinator.s2Machine?.currentAssetID, "资产-B")
        XCTAssertEqual(coordinator.s2Machine?.pendingDeletionAssetIDs, Set(["资产-D", "资产-C"]))
    }

    // MARK: - E 冷启动恢复后无会话

    @MainActor
    func testIC194E_ColdStartRestoredS5ReturnResumesS1() throws {
        // 有 S1 会话档：恢复同一会话与 `T`／`O`。
        let persistence = TestPersistenceIsolation.makePersistence()
        try persistence.saveS1Session(
            S1SessionSnapshot(
                sessionID: "会话-194E",
                groupingDimension: .album,
                sortOrder: .oldestFirst,
                pendingDeletionAssetIDsByRangeID: [:],
                continuationsByRangeID: [:],
                firstMarkedRangeIDByAssetID: [:]
            )
        )
        try persistence.save(try cancelledCompletionRecord())
        let restored = makeCoordinator(persistence: persistence)
        restored.start()
        XCTAssertEqual(restored.route, .completion)
        XCTAssertNil(restored.s1Machine)
        XCTAssertNil(restored.sessionStore)

        restored.returnToConfirmation()
        XCTAssertEqual(restored.route, .confirmation)
        XCTAssertNil(restored.s3ReturnTarget)
        restored.leaveConfirmation()

        XCTAssertEqual(restored.route, .s1)
        let machine = try XCTUnwrap(restored.s1Machine)
        XCTAssertEqual(machine.sessionStore.sessionID, "会话-194E")
        XCTAssertEqual(machine.groupingDimension, .album)
        XCTAssertEqual(machine.sortOrder, .oldestFirst)
        XCTAssertEqual(restored.sessionStore?.sessionID, "会话-194E")
        XCTAssertNil(restored.s3Machine)
        XCTAssertNil(restored.s2Machine)
        XCTAssertNil(persistence.load())

        // 无 S1 会话档：开新会话，默认 `T`／`O`。
        let bare = TestPersistenceIsolation.makePersistence()
        try bare.save(try cancelledCompletionRecord())
        let fresh = makeCoordinator(persistence: bare)
        fresh.start()
        XCTAssertEqual(fresh.route, .completion)
        fresh.returnToConfirmation()
        fresh.leaveConfirmation()
        XCTAssertEqual(fresh.route, .s1)
        let freshMachine = try XCTUnwrap(fresh.s1Machine)
        XCTAssertFalse(freshMachine.sessionStore.sessionID.isEmpty)
        XCTAssertNotEqual(freshMachine.sessionStore.sessionID, "会话-194E")
        XCTAssertEqual(freshMachine.groupingDimension, .date)
        XCTAssertEqual(freshMachine.sortOrder, .newestFirst)
    }

    // MARK: - F 源码落位

    func testIC194F_SourceWiring() throws {
        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        for (needle, expected) in [
            ("struct S3ReturnTarget: Equatable {", 1),
            ("private(set) var s3ReturnTarget: S3ReturnTarget?", 1),
            ("s3ReturnTarget", 6),
            ("s3ReturnTarget = returnTarget", 1),
            ("s3ReturnTarget = nil", 3),
            ("let returnTarget = S3ReturnTarget(", 1),
            // 诊断取样一处 + 返回落点一处。
            ("s1Machine?.activeVirtualRangeIDs.contains(", 2),
            ("private func reenterS2(returningTo target: S3ReturnTarget) -> Bool {", 1),
            ("reenterS2(returningTo", 2),
            ("s1Machine.makeS2ReentryHandoff(for: target.rangeID)", 1),
            ("cancelS2Handoff(virtualRangeID:", 2),
            ("photoLibrary.existingAssetIdentifiers(", 2),
            ("enterS1ResumingPersistedSessionOrStartNew()", 3),
            ("if route == .confirmation, sessionStore == nil, s1Machine == nil {", 1),
            ("s3Groups = []\n        s3ReturnTarget = nil", 1),
            // 既有钉子不变。
            ("installS1Session(", 6),
            ("recordSeenAssets(", 4),
            ("flushSeenArchive()", 4),
            ("photoLibrary.s1RangeRead(", 2),
            ("publishS1FeedbackEvent(.submissionUnavailable)", 4),
            ("S0Tab", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: coordinator), expected, needle)
        }
        let coordinatorRaw = try XCTUnwrap(sourceText(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "return \"", in: coordinatorRaw), 0)

        let fromS2 = try XCTUnwrap(slice(coordinator, from: "func enterConfirmationFromS2(", to: "func enterConfirmationFromS1("))
        try assertOrder(["let returnTarget = S3ReturnTarget(", "guard applyS2ExitPayload(payload) else {",
                         "guard enterConfirmationFromS1(submission) else {", "s3ReturnTarget = returnTarget"], in: fromS2)
        let landing = try XCTUnwrap(slice(coordinator, from: "func handleS3Return(", to: "private func reenterS2("))
        try assertOrder(["if route == .confirmation, sessionStore == nil, s1Machine == nil {",
                         "return enterS1ResumingPersistedSessionOrStartNew()", "let sessionReturn = SessionStore.S3Return(",
                         "route = .upstream", "s3ReturnTarget = nil", "reenterS2(returningTo: target)"], in: landing)
        let reentry = try XCTUnwrap(slice(coordinator, from: "private func reenterS2(", to: "func enterConfirmation("))
        for (needle, expected) in [
            ("reconcileS1WithPhotoLibrary()", 1),
            ("photoLibrary.existingAssetIdentifiers(", 1),
            ("currentSeenArchive().seenAssetIDs", 1),
            ("continuationsByRangeID[target.rangeID]?.currentAssetID", 1),
            ("s1Machine.makeS2Handoff(", 1),
            ("s1Machine.makeS2ReentryHandoff(for: target.rangeID)", 1),
            ("enterS2(from: handoff)", 1),
            ("s1Machine.cancelS2Handoff(virtualRangeID: target.rangeID)", 1),
            ("seenAssetIDsProvider", 0),
            ("publishS1FeedbackEvent(", 0),
            ("message", 0),
            ("route", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: reentry), expected, "reenterS2: " + needle)
        }
        let backToConfirmation = try XCTUnwrap(slice(coordinator, from: "func returnToConfirmation() {", to: "func leaveCompletion() {"))
        XCTAssertEqual(occurrences(of: "s3ReturnTarget", in: backToConfirmation), 0)

        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        for (needle, expected) in [
            ("func makeS2ReentryHandoff(for rangeID: String) -> S1ToS2Handoff? {", 1),
            ("makeS2ReentryHandoff(", 1),
            ("publishSnapshotIfChanged()", 6),
            ("seenAssetIDsProvider?() ?? []", 4),
            ("didSet", 4),
            ("setMarked(", 3),
            ("applyPendingDeletionDiff(", 3),
            ("presentedYearRangeID", 7)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: machine), expected, needle)
        }
        try assertOrder(["func cancelS2Handoff(virtualRangeID: String) {", "func makeS2ReentryHandoff(for rangeID: String)",
                         "func makeS3Submission()"], in: machine)
        let reentryHandoff = try XCTUnwrap(slice(machine, from: "func makeS2ReentryHandoff(", to: "func makeS3Submission()"))
        for (needle, expected) in [
            ("makeS2Handoff(for: rangeID)", 1),
            ("sessionStore.continuationsByRangeID[rangeID]?.currentAssetID", 1),
            ("handoff.orderedAssetIDs.contains(resumedAssetID)", 1),
            ("currentAssetID: resumedAssetID", 1),
            ("seenAssetIDsProvider", 0),
            ("publishSnapshotIfChanged()", 0),
            ("activeVirtualRangeIDs", 0),
            ("knownRangeNamesByID", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: reentryHandoff), expected, "makeS2ReentryHandoff: " + needle)
        }

        // 只有协调器调重进交接；S3 返回仍只经协调器一个入口（视图不改）。
        let sources = try productSources()
        XCTAssertEqual(
            sources.filter { occurrences(of: "makeS2ReentryHandoff(", in: $0.value) > 0 }.keys.sorted(),
            ["CleanupCoordinator.swift", "S1StateMachine.swift"]
        )
        XCTAssertEqual(
            sources.filter { occurrences(of: "s3ReturnTarget", in: $0.value) > 0 }.keys.sorted(),
            ["CleanupCoordinator.swift"]
        )
        XCTAssertEqual(
            sources.filter { occurrences(of: "coordinator.leaveConfirmation()", in: $0.value) > 0 }.keys.sorted(),
            ["S3View.swift"]
        )
    }

    // MARK: - 夹具

    private static func monthRange(_ assetIDs: [String]) -> S1Range {
        S1Range(id: "范围-月", displayName: "2026 年 8 月", assetIDsNewestFirst: assetIDs)
    }

    /// 授权按拒绝：从 S2 返回的对账读不到 `R(T)`、静默不改（与测试宿主无授权同口径，但不依赖宿主）；
    /// 存在性按夹具给。
    @MainActor
    private func makeCoordinator(
        existence: IC194ExistenceBox = IC194ExistenceBox(),
        deletionService: any PhotoDeletionServicing = IC194CancellingDeletionService(),
        persistence: SessionPersistence = TestPersistenceIsolation.makePersistence()
    ) -> CleanupCoordinator {
        let source = S1PhotoLibrarySource(
            authorizationStatus: { .denied },
            fetchAssets: { [] },
            fetchAssetCollections: { _, _ in [] },
            fetchExistingAssetIdentifiers: { identifiers in
                Set(identifiers).subtracting(existence.missing)
            }
        )
        return CleanupCoordinator(
            photoLibrary: PhotoLibraryService(s1Source: source),
            deletionService: deletionService,
            persistence: persistence
        )
    }

    @MainActor
    private func completeRead(_ coordinator: CleanupCoordinator, ranges: [S1Range]) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
        XCTAssertEqual(machine.state, .ready)
    }

    /// S1 就绪 → 进「范围-月」（第一张没看过的 D）→ 上滑两次（标 D、C，停在 B）→ 待删篮进 S3。
    @MainActor
    private func enterS3FromMonthRange(_ coordinator: CleanupCoordinator, sessionID: String) throws {
        XCTAssertTrue(coordinator.enterS1(sessionID: sessionID))
        completeRead(coordinator, ranges: [Self.monthRange(Self.monthAssets)])
        let handoff = try XCTUnwrap(coordinator.s1Machine?.makeS2Handoff(for: "范围-月"))
        XCTAssertEqual(handoff.currentAssetID, "资产-D")
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        let s2 = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertTrue(s2.handleSwipeUp())
        XCTAssertTrue(s2.handleSwipeUp())
        XCTAssertEqual(s2.currentAssetID, "资产-B")
        XCTAssertEqual(s2.pendingDeletionAssetIDs, Set(["资产-D", "资产-C"]))
        try trash(coordinator)
    }

    @MainActor
    private func trash(_ coordinator: CleanupCoordinator) throws {
        let payload = try XCTUnwrap(coordinator.s2Machine?.makeExitPayload())
        XCTAssertTrue(coordinator.enterConfirmationFromS2(with: payload))
        XCTAssertEqual(coordinator.route, .confirmation)
    }

    private func cancelledCompletionRecord() throws -> PersistedSession {
        let snapshot = SubmissionSnapshot(
            submissionID: "提交-194E",
            assetIDs: ["资产-甲", "资产-乙"],
            assetCount: 2,
            knownTotalBytes: 2,
            unavailableCount: 0,
            volumeDisplayMode: .exact,
            favoriteAssetIDs: [],
            frozenAt: Date(timeIntervalSince1970: 1_786_291_200)
        )
        let completion = try S5StateMachine.enter(
            from: .failure(
                snapshot: snapshot,
                callback: IC194CancellingDeletionService.cancellation(for: snapshot, at: snapshot.frozenAt),
                downstreamTargetState: .cancelled
            ),
            persist: { _ in },
            invalidateOldLists: { _ in }
        )
        return PersistedSession(s5: completion.persistentState)
    }

    /// 转主线程 run loop 直到条件成立或超时（扫描结论与删除回调都经主 actor 排队送达；照 IC-186 的同名 helper）。
    /// 标 `@MainActor`：调用方测试与闭包里读的协调器都在主 actor 上，不跨隔离。
    @MainActor
    @discardableResult
    private func waitUntil(
        timeout: TimeInterval = 10,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            if Date() >= deadline {
                return false
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        return true
    }

    private func assertOrder(_ needles: [String], in text: String, file: StaticString = #filePath, line: UInt = #line) throws {
        var cursor = text.startIndex
        for needle in needles {
            let found = try XCTUnwrap(text.range(of: needle, range: cursor..<text.endIndex), needle, file: file, line: line)
            cursor = found.upperBound
        }
    }

    // MARK: - 工具（与既有测试同口径）

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.upperBound])
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceText(_ relativePath: String) -> String? {
        try? String(
            contentsOf: repoRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    /// 产品目录下全部 `.swift`，按文件名剔注释与字符串内容（被查的文件名在产品目录里唯一）。
    private func productSources() throws -> [String: String] {
        let root = repoRoot().appendingPathComponent(Self.productRoot)
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [String: String] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            result[url.lastPathComponent] = stripped(source)
        }
        return result
    }

    private func strippedSource(_ relativePath: String) -> String? {
        sourceText(relativePath).map { stripped($0) }
    }

    /// 剔掉 `//` 注释与字符串字面量内容。
    private func stripped(_ source: String) -> String {
        let newline = Character(UnicodeScalar(UInt8(10)))
        var output = ""
        var iterator = source.startIndex
        var inString = false
        while iterator < source.endIndex {
            let character = source[iterator]
            let next = source.index(after: iterator)
            if inString {
                if character == "\\" {
                    iterator = next < source.endIndex
                        ? source.index(after: next)
                        : source.endIndex
                    continue
                }
                if character == "\"" {
                    inString = false
                }
                iterator = next
                continue
            }
            if character == "\"" {
                inString = true
                iterator = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                while iterator < source.endIndex,
                      source[iterator] != newline {
                    iterator = source.index(after: iterator)
                }
                output.append(newline)
                continue
            }
            output.append(character)
            iterator = next
        }
        return output
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}

/// 照片库存在性夹具：`missing` 里的标识按「已不在库中」回报。
private final class IC194ExistenceBox {
    var missing: Set<String> = []
}

/// 删除服务夹具：一律按用户取消回报（S4 → S5 已取消态），不碰系统照片库。
private final class IC194CancellingDeletionService: PhotoDeletionServicing, @unchecked Sendable {
    private(set) var startCount = 0

    static func cancellation(for snapshot: SubmissionSnapshot, at receivedAt: Date) -> S4FailureCallback {
        S4FailureCallback(
            submissionID: snapshot.submissionID,
            successfulAssetIDs: [],
            failedAssetIDs: [],
            unprocessedAssetIDs: Set(snapshot.assetIDs),
            reason: S4FailureReason(
                category: .userCancelled,
                message: "测试替身：用户取消",
                systemDomain: nil,
                systemCode: nil
            ),
            receivedAt: receivedAt
        )
    }

    func startDeletion(
        snapshot: SubmissionSnapshot,
        completion: @escaping (PhotoDeletionOutcome) -> Void
    ) {
        startCount += 1
        completion(.failure(Self.cancellation(for: snapshot, at: Date())))
    }

    func systemFailureCallback(
        snapshot: SubmissionSnapshot,
        error: NSError?,
        receivedAt: Date
    ) -> S4FailureCallback {
        Self.cancellation(for: snapshot, at: receivedAt)
    }
}
