import Foundation
import XCTest
@testable import PhotoCleanupMVE

final class S5StateMachineTests: XCTestCase {
    private enum TestError: Error {
        case persistenceFailed
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_786_291_200)

    // 可达单元格 1：成功交接进入已移入最近删除状态。
    func testCell01SuccessEntry() throws {
        var actions: [String] = []
        var invalidated: Set<String> = []
        let machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: { state in
                actions.append("持久化")
                guard case .movedToRecentlyDeleted = state.state else {
                    return XCTFail("应先持久化成功状态")
                }
            },
            invalidateOldLists: { identifiers in
                actions.append("列表失效")
                invalidated = identifiers
            }
        )

        guard case let .movedToRecentlyDeleted(context) = machine.state else {
            return XCTFail("应进入成功状态")
        }
        XCTAssertEqual(actions, ["持久化", "列表失效"])
        XCTAssertEqual(invalidated, Set(makeSnapshot().assetIDs))
        XCTAssertEqual(context.successfulAssetIDs, Set(makeSnapshot().assetIDs))
    }

    // 可达单元格 2：失败交接进入失败状态。
    func testCell02FailureEntry() throws {
        let machine = try S5StateMachine.enter(
            from: makeFailureHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )

        guard case let .failed(context) = machine.state else {
            return XCTFail("应进入失败状态")
        }
        XCTAssertEqual(context.callback, makeFailureCallback())
        XCTAssertEqual(context.snapshot, makeSnapshot())
    }

    // 可达单元格 3：未知交接进入未知状态。
    func testCell03UnknownEntry() throws {
        let machine = try S5StateMachine.enter(
            from: makeUnknownHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )

        guard case let .unknown(context) = machine.state else {
            return XCTFail("应进入未知状态")
        }
        XCTAssertEqual(context.reason, .activeWaitTimedOut)
        XCTAssertEqual(context.snapshot, makeSnapshot())
    }

    // 可达单元格 4：成功页离开后前往清理入口。
    func testCell04LeaveFromSuccess() throws {
        var machine = try makeSuccessMachine()
        let transition = try machine.handle(.leavePage, persist: ignorePersistence)

        XCTAssertEqual(transition.effect, .exitCleanup)
        XCTAssertTrue(transition.isApplied)
    }

    // 可达单元格 5 的第一条守卫路径：缓存存在时返回就绪确认页。
    func testCell05AReturnFromFailureWithCache() throws {
        var machine = try makeFailureMachine()
        let transition = try machine.handle(
            .returnToConfirmation(cacheExists: true),
            persist: ignorePersistence
        )

        XCTAssertEqual(
            transition.effect,
            .returnToConfirmation(target: .ready, assetIDs: makeSnapshot().assetIDs)
        )
    }

    // 可达单元格 5 的第二条守卫路径：缓存清空时返回扫描确认页。
    func testCell05BReturnFromFailureWithoutCache() throws {
        var machine = try makeFailureMachine()
        let transition = try machine.handle(
            .returnToConfirmation(cacheExists: false),
            persist: ignorePersistence
        )

        XCTAssertEqual(
            transition.effect,
            .returnToConfirmation(target: .scanning, assetIDs: makeSnapshot().assetIDs)
        )
    }

    // 可达单元格 6：未知页离开后前往清理入口。
    func testCell06LeaveFromUnknown() throws {
        var machine = try makeUnknownMachine()
        let transition = try machine.handle(.leavePage, persist: ignorePersistence)

        XCTAssertEqual(transition.effect, .exitCleanup)
        XCTAssertTrue(transition.isApplied)
    }

    // 可达单元格 7：成功状态进入非活动态。
    func testCell07InactiveFromSuccess() throws {
        var machine = try makeSuccessMachine()
        let before = machine.state
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, before)
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 8：失败状态进入非活动态。
    func testCell08InactiveFromFailure() throws {
        var machine = try makeFailureMachine()
        let before = machine.state
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, before)
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 9：未知状态进入非活动态。
    func testCell09InactiveFromUnknown() throws {
        var machine = try makeUnknownMachine()
        let before = machine.state
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, before)
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 10：成功状态恢复活动时保持原状态。
    func testCell10ActiveFromSuccess() throws {
        var machine = try makeSuccessMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        guard case .movedToRecentlyDeleted = transition.toState else {
            return XCTFail("应保持成功状态")
        }
        XCTAssertTrue(machine.isApplicationActive)
    }

    // 可达单元格 11：失败状态恢复活动时保持原状态。
    func testCell11ActiveFromFailure() throws {
        var machine = try makeFailureMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        guard case .failed = transition.toState else {
            return XCTFail("应保持失败状态")
        }
        XCTAssertTrue(machine.isApplicationActive)
    }

    // 可达单元格 12：未知状态恢复活动时保持原状态。
    func testCell12ActiveFromUnknown() throws {
        var machine = try makeUnknownMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        guard case .unknown = transition.toState else {
            return XCTFail("应保持未知状态")
        }
        XCTAssertTrue(machine.isApplicationActive)
    }

    // 可达单元格 13：成功状态被终止时持久化并保留。
    func testCell13TerminationFromSuccess() throws {
        var machine = try makeSuccessMachine()
        let before = machine.state
        var persisted: S5PersistentState?
        let transition = try machine.handle(.processTerminated) {
            persisted = $0
        }

        XCTAssertEqual(transition.toState, before)
        XCTAssertEqual(persisted, machine.persistentState)
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 14：失败状态被终止时持久化并保留。
    func testCell14TerminationFromFailure() throws {
        var machine = try makeFailureMachine()
        let before = machine.state
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, before)
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 15：未知状态被终止时持久化并保留。
    func testCell15TerminationFromUnknown() throws {
        var machine = try makeUnknownMachine()
        let before = machine.state
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, before)
        XCTAssertFalse(machine.isApplicationActive)
    }

    func testConfirmationButtonIsEnabledOnlyBeforeSuccessConfirmation() throws {
        var success = try makeSuccessMachine()
        XCTAssertTrue(success.isRecentlyDeletedConfirmationEnabled)
        XCTAssertFalse(try makeFailureMachine().isRecentlyDeletedConfirmationEnabled)
        XCTAssertFalse(try makeCancellationMachine().isRecentlyDeletedConfirmationEnabled)
        XCTAssertFalse(try makeUnknownMachine().isRecentlyDeletedConfirmationEnabled)

        _ = try success.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignorePersistence,
            readFreeDiskStrictGB: { 11 }
        )
        XCTAssertFalse(success.isRecentlyDeletedConfirmationEnabled)
    }

    func testCancellationEntryUsesDownstreamTargetWithoutReadingFailureCategory() throws {
        var readCount = 0
        let machine = try S5StateMachine.enter(
            from: makeCancellationHandoff(category: .unknown),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: {
                readCount += 1
                return 9
            }
        )

        guard case let .cancelled(context) = machine.state else {
            return XCTFail("应按交接字段进入取消状态")
        }
        XCTAssertEqual(context.callback.reason.category, .unknown)
        XCTAssertEqual(readCount, 0)
    }

    func testFailureEntryUsesDownstreamTargetWithoutReadingFailureCategory() throws {
        let handoff = S4Handoff.failure(
            snapshot: makeSnapshot(),
            callback: makeFailureCallback(category: .userCancelled),
            downstreamTargetState: .failed
        )
        let machine = try S5StateMachine.enter(
            from: handoff,
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )

        guard case .failed = machine.state else {
            return XCTFail("应按交接字段进入失败状态")
        }
    }

    func testCancellationReturnWithCacheCarriesOriginalSubmission() throws {
        var machine = try makeCancellationMachine()
        let transition = try machine.handle(
            .returnToConfirmation(cacheExists: true),
            persist: ignorePersistence
        )

        XCTAssertEqual(
            transition.effect,
            .returnToConfirmation(target: .ready, assetIDs: makeSnapshot().assetIDs)
        )
    }

    func testCancellationReturnWithoutCacheCarriesOriginalSubmission() throws {
        var machine = try makeCancellationMachine()
        let transition = try machine.handle(
            .returnToConfirmation(cacheExists: false),
            persist: ignorePersistence
        )

        XCTAssertEqual(
            transition.effect,
            .returnToConfirmation(target: .scanning, assetIDs: makeSnapshot().assetIDs)
        )
    }

    func testCancellationLifecycleAndTerminationKeepState() throws {
        var machine = try makeCancellationMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        XCTAssertFalse(machine.isApplicationActive)
        _ = try machine.handle(.applicationBecameActive, persist: ignorePersistence)
        XCTAssertTrue(machine.isApplicationActive)
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        guard case .cancelled = transition.toState else {
            return XCTFail("生命周期事件不得改变取消状态")
        }
        XCTAssertFalse(machine.isApplicationActive)
    }

    func testCancellationCannotLeaveThroughCompletionAction() throws {
        var machine = try makeCancellationMachine()
        let transition = try machine.handle(.leavePage, persist: ignorePersistence)

        XCTAssertEqual(transition.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(transition.effect, .none)
    }

    func testCancellationDoesNotReadFreeDiskStrictGB() throws {
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeCancellationHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: {
                readCount += 1
                return 7
            }
        )
        _ = try machine.handle(
            .applicationBecameInactive,
            persist: ignorePersistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 8
            }
        )

        XCTAssertEqual(readCount, 0)
        XCTAssertNil(machine.persistentState.l3BaselineReading)
        XCTAssertNil(machine.persistentState.l3CompletionReading)
    }

    func testCancellationDoesNotShowL3() throws {
        let capabilities = try makeCancellationMachine().state.presentationCapabilities

        XCTAssertFalse(capabilities.showsL3)
    }

    func testCancellationDoesNotShowSystemErrorDomainOrCode() throws {
        let capabilities = try makeCancellationMachine().state.presentationCapabilities

        XCTAssertFalse(capabilities.showsSystemErrorDetails)
    }

    func testCancellationDoesNotShowRecentlyDeletedConfirmationAction() throws {
        let machine = try makeCancellationMachine()

        XCTAssertFalse(
            machine.state.presentationCapabilities.showsRecentlyDeletedConfirmationAction
        )
        XCTAssertFalse(machine.isRecentlyDeletedConfirmationEnabled)
    }

    func testCancellationVisibleCopyAvoidsFailureAndIncompleteWording() {
        let visibleTexts = [
            L10n.text("s5.section.deletion_cancelled"),
            L10n.text("s5.status.assets_intact"),
            L10n.text(
                "s5.summary.cancelled_result",
                replacing: ["count": "3"]
            ),
            L10n.text("s5.action.return_to_confirmation")
        ]

        XCTAssertFalse(visibleTexts.contains { $0.contains("失败") })
        XCTAssertFalse(visibleTexts.contains { $0.contains("未完成") })
    }

    func testSuccessEntryReadsBaselineExactlyOnceAndPersistsIt() throws {
        var readCount = 0
        var persisted: S5PersistentState?
        let machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: { persisted = $0 },
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: {
                readCount += 1
                return 10.5
            }
        )

        XCTAssertEqual(readCount, 1)
        XCTAssertEqual(machine.persistentState.l3BaselineReading, .available(10.5))
        XCTAssertEqual(persisted, machine.persistentState)
        XCTAssertNil(machine.persistentState.l3CompletionReading)
        XCTAssertNil(machine.persistentState.l3DeltaGB)
    }

    func testConfirmationReadsCompletionExactlyOnceAndPersistsDelta() throws {
        let readValues = [10.5, 12.25]
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: {
                defer { readCount += 1 }
                return readValues[readCount]
            }
        )
        var persisted: S5PersistentState?

        let transition = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: { persisted = $0 },
            readFreeDiskStrictGB: {
                defer { readCount += 1 }
                return readValues[readCount]
            }
        )

        XCTAssertTrue(transition.isApplied)
        XCTAssertEqual(readCount, 2)
        XCTAssertEqual(machine.persistentState.l3CompletionReading, .available(12.25))
        XCTAssertEqual(machine.persistentState.l3DeltaGB, 1.75)
        XCTAssertEqual(machine.persistentState.recentlyDeletedClearedAt, fixedDate)
        XCTAssertEqual(persisted, machine.persistentState)
    }

    func testRepeatedConfirmationDoesNotReadAgain() throws {
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: {
                readCount += 1
                return 4
            }
        )
        _ = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignorePersistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 5
            }
        )

        let repeated = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate.addingTimeInterval(1)),
            persist: ignorePersistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 6
            }
        )

        XCTAssertEqual(repeated.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(readCount, 2)
        XCTAssertEqual(machine.persistentState.l3DeltaGB, 1)
    }

    func testLifecycleEventsDoNotReadFreeDiskAgain() throws {
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: {
                readCount += 1
                return 4
            }
        )
        let forbiddenRead: () -> Double? = {
            readCount += 1
            return 99
        }

        _ = try machine.handle(
            .applicationBecameInactive,
            persist: ignorePersistence,
            readFreeDiskStrictGB: forbiddenRead
        )
        _ = try machine.handle(
            .applicationBecameActive,
            persist: ignorePersistence,
            readFreeDiskStrictGB: forbiddenRead
        )
        _ = try machine.handle(
            .processTerminated,
            persist: ignorePersistence,
            readFreeDiskStrictGB: forbiddenRead
        )

        XCTAssertEqual(readCount, 1)
    }

    func testUnavailableReadingsArePersistedWithoutDeltaOrRetry() throws {
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: {
                readCount += 1
                return nil
            }
        )
        _ = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignorePersistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return nil
            }
        )

        XCTAssertEqual(readCount, 2)
        XCTAssertEqual(machine.persistentState.l3BaselineReading, .unavailable)
        XCTAssertEqual(machine.persistentState.l3CompletionReading, .unavailable)
        XCTAssertNil(machine.persistentState.l3DeltaGB)
    }

    func testPersistedSessionCarriesTargetReadingsDeltaAndDeclarationTime() throws {
        var machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation,
            readFreeDiskStrictGB: { 20 }
        )
        _ = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignorePersistence,
            readFreeDiskStrictGB: { 23.5 }
        )

        let persisted = PersistedSession(s5: machine.persistentState)

        XCTAssertEqual(persisted.phase, .completionSuccess)
        XCTAssertEqual(persisted.downstreamTargetState, "S5-T0")
        XCTAssertEqual(persisted.l3BaselineReading, .available(20))
        XCTAssertEqual(persisted.l3CompletionReading, .available(23.5))
        XCTAssertEqual(persisted.l3DeltaGB, 3.5)
        XCTAssertEqual(persisted.recentlyDeletedClearedAt, fixedDate)
    }

    func testL3DisplayRemainsBlockedForEveryState() throws {
        XCTAssertFalse(try makeSuccessMachine().state.presentationCapabilities.showsL3)
        XCTAssertFalse(try makeCancellationMachine().state.presentationCapabilities.showsL3)
        XCTAssertFalse(try makeFailureMachine().state.presentationCapabilities.showsL3)
        XCTAssertFalse(try makeUnknownMachine().state.presentationCapabilities.showsL3)
        XCTAssertTrue(S5L3DisplayGate.blockedByUndecidedThreshold)
    }

    func testMismatchedHandoffPayloadAndTargetIsRejected() {
        let handoff = S4Handoff.failure(
            snapshot: makeSnapshot(),
            callback: makeFailureCallback(),
            downstreamTargetState: .movedToRecentlyDeleted
        )

        XCTAssertThrowsError(
            try S5StateMachine.enter(
                from: handoff,
                persist: ignorePersistence,
                invalidateOldLists: ignoreInvalidation
            )
        ) { error in
            XCTAssertEqual(
                error as? S5StateMachineError,
                .handoffPayloadDoesNotMatchTarget
            )
        }
    }

    func testFailurePageCannotLeaveThroughCompletionAction() throws {
        var machine = try makeFailureMachine()
        let transition = try machine.handle(.leavePage, persist: ignorePersistence)

        XCTAssertEqual(transition.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(transition.effect, .none)
    }

    func testSuccessPageCannotReturnToConfirmation() throws {
        var machine = try makeSuccessMachine()
        let transition = try machine.handle(
            .returnToConfirmation(cacheExists: true),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.rejection, .actionUnavailableInCurrentState)
    }

    func testUnknownPageCannotReturnToConfirmation() throws {
        var machine = try makeUnknownMachine()
        let transition = try machine.handle(
            .returnToConfirmation(cacheExists: false),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.rejection, .actionUnavailableInCurrentState)
    }

    func testEntryPersistenceFailurePreventsListInvalidation() {
        var didInvalidate = false

        XCTAssertThrowsError(
            try S5StateMachine.enter(
                from: makeSuccessHandoff(),
                persist: { _ in throw TestError.persistenceFailed },
                invalidateOldLists: { _ in didInvalidate = true }
            )
        )
        XCTAssertFalse(didInvalidate)
    }

    func testLifecyclePersistenceFailureLeavesStateUnchanged() throws {
        var machine = try makeUnknownMachine()
        let before = machine.persistentState

        XCTAssertThrowsError(
            try machine.handle(
                .applicationBecameInactive,
                persist: { _ in throw TestError.persistenceFailed }
            )
        )
        XCTAssertEqual(machine.persistentState, before)
    }

    func testRestoreKeepsPersistedSuccessState() throws {
        var original = try makeSuccessMachine()
        _ = try original.handle(.processTerminated, persist: ignorePersistence)
        let restored = try S5StateMachine.restore(
            persistentState: original.persistentState,
            persist: ignorePersistence
        )

        XCTAssertEqual(restored.persistentState, original.persistentState)
    }

    func testRestoreKeepsPersistedFailureState() throws {
        var original = try makeFailureMachine()
        _ = try original.handle(.processTerminated, persist: ignorePersistence)
        let restored = try S5StateMachine.restore(
            persistentState: original.persistentState,
            persist: ignorePersistence
        )

        XCTAssertEqual(restored.persistentState, original.persistentState)
    }

    func testRestoreKeepsPersistedCancellationStateWithoutDiskRead() throws {
        var original = try makeCancellationMachine()
        _ = try original.handle(.processTerminated, persist: ignorePersistence)
        let restored = try S5StateMachine.restore(
            persistentState: original.persistentState,
            persist: ignorePersistence
        )

        XCTAssertEqual(restored.persistentState, original.persistentState)
        XCTAssertNil(restored.persistentState.l3BaselineReading)
        XCTAssertNil(restored.persistentState.l3CompletionReading)
    }

    func testRestoreKeepsPersistedUnknownState() throws {
        var original = try makeUnknownMachine()
        _ = try original.handle(.processTerminated, persist: ignorePersistence)
        let restored = try S5StateMachine.restore(
            persistentState: original.persistentState,
            persist: ignorePersistence
        )

        XCTAssertEqual(restored.persistentState, original.persistentState)
    }

    private func makeSnapshot() -> SubmissionSnapshot {
        SubmissionSnapshot(
            submissionID: "提交-001",
            assetIDs: ["资产-A", "资产-B", "资产-C"],
            assetCount: 3,
            knownTotalBytes: 2_000,
            unavailableCount: 1,
            volumeDisplayMode: .lowerBound,
            favoriteAssetIDs: ["资产-A"],
            frozenAt: fixedDate
        )
    }

    private func makeFailureCallback(
        category: S4FailureCategory = .assetNotDeletable
    ) -> S4FailureCallback {
        S4FailureCallback(
            submissionID: makeSnapshot().submissionID,
            successfulAssetIDs: ["资产-A"],
            failedAssetIDs: ["资产-B"],
            unprocessedAssetIDs: ["资产-C"],
            reason: S4FailureReason(
                category: category,
                message: "部分资产不可删除",
                systemDomain: "测试错误域",
                systemCode: 10
            ),
            receivedAt: fixedDate
        )
    }

    private func makeSuccessHandoff() -> S4Handoff {
        let snapshot = makeSnapshot()
        return .success(
            snapshot: snapshot,
            result: S4SuccessResult(
                submissionID: snapshot.submissionID,
                successfulAssetIDs: Set(snapshot.assetIDs),
                receivedAt: fixedDate
            ),
            downstreamTargetState: .movedToRecentlyDeleted
        )
    }

    private func makeFailureHandoff() -> S4Handoff {
        .failure(
            snapshot: makeSnapshot(),
            callback: makeFailureCallback(),
            downstreamTargetState: .failed
        )
    }

    private func makeCancellationHandoff(
        category: S4FailureCategory = .userCancelled
    ) -> S4Handoff {
        let snapshot = makeSnapshot()
        let callback = S4FailureCallback(
            submissionID: snapshot.submissionID,
            successfulAssetIDs: [],
            failedAssetIDs: [],
            unprocessedAssetIDs: Set(snapshot.assetIDs),
            reason: S4FailureReason(
                category: category,
                message: "用户已取消系统操作",
                systemDomain: "测试取消域",
                systemCode: 71
            ),
            receivedAt: fixedDate
        )
        return .failure(
            snapshot: snapshot,
            callback: callback,
            downstreamTargetState: .cancelled
        )
    }

    private func makeUnknownHandoff() -> S4Handoff {
        .unknown(
            snapshot: makeSnapshot(),
            reason: .activeWaitTimedOut,
            downstreamTargetState: .unknown
        )
    }

    private func makeSuccessMachine() throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )
    }

    private func makeFailureMachine() throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: makeFailureHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )
    }

    private func makeCancellationMachine() throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: makeCancellationHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )
    }

    private func makeUnknownMachine() throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: makeUnknownHandoff(),
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )
    }

    private func ignorePersistence(_ state: S5PersistentState) throws {
        _ = state
    }

    private func ignoreInvalidation(_ identifiers: Set<String>) {
        _ = identifiers
    }
}
