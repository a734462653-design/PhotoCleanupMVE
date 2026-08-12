import Foundation
import XCTest
@testable import PhotoCleanupMVE

final class CoverageGapTests: XCTestCase {
    private final class SubmissionRegistry {
        private var claimedSubmissionIDs = Set<String>()

        func claim(_ state: S4PersistentState) -> Bool {
            claimedSubmissionIDs.insert(state.snapshot.submissionID).inserted
        }
    }

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

    private let fixedDate = Date(timeIntervalSince1970: 1_786_291_200)

    func testC34_114SubmittedStateRejectsEveryFullPartialAndModifiedResubmission() throws {
        let registry = SubmissionRegistry()
        let original = makeSnapshot()
        _ = try makeS4Machine(snapshot: original, registry: registry)

        for candidate in submissionVariants(of: original) {
            assertDuplicateStartIsRejected(candidate, registry: registry)
        }
    }

    func testC34_116SubmittedSnapshotCannotBeModifiedCancelledOrSplit() throws {
        let registry = SubmissionRegistry()
        let original = makeSnapshot()
        var machine = try makeS4Machine(snapshot: original, registry: registry)

        for candidate in submissionVariants(of: original) {
            assertDuplicateStartIsRejected(candidate, registry: registry)
        }
        let cancellationAttempt = try machine.handle(
            .duplicateSubmissionAttempt,
            persist: ignoreS4Persistence
        )

        XCTAssertEqual(cancellationAttempt.rejection, .duplicateSubmission)
        XCTAssertEqual(machine.snapshot, original)
    }

    func testC34_128ResumedStateRejectsEveryResultChangingAppOperation() throws {
        let registry = SubmissionRegistry()
        let original = makeSnapshot()
        var machine = try makeS4Machine(snapshot: original, registry: registry)
        _ = try machine.handle(.applicationBecameInactive, persist: ignoreS4Persistence)
        _ = try machine.handle(.applicationBecameActive, persist: ignoreS4Persistence)

        let transition = try machine.handle(
            .duplicateSubmissionAttempt,
            persist: ignoreS4Persistence
        )
        XCTAssertEqual(transition.rejection, .duplicateSubmission)
        for candidate in submissionVariants(of: original) {
            assertDuplicateStartIsRejected(candidate, registry: registry)
        }
        XCTAssertEqual(machine.snapshot, original)
    }

    func testC34_130ResumedSnapshotCannotBeModifiedCancelledOrSplit() throws {
        let registry = SubmissionRegistry()
        let original = makeSnapshot()
        var machine = try makeS4Machine(snapshot: original, registry: registry)
        _ = try machine.handle(.applicationBecameInactive, persist: ignoreS4Persistence)
        _ = try machine.handle(.applicationBecameActive, persist: ignoreS4Persistence)

        for candidate in submissionVariants(of: original) {
            assertDuplicateStartIsRejected(candidate, registry: registry)
        }
        _ = try machine.handle(.applicationBecameInactive, persist: ignoreS4Persistence)
        _ = try machine.handle(.applicationBecameActive, persist: ignoreS4Persistence)

        XCTAssertEqual(machine.snapshot, original)
    }

    func testC34_146SuccessTerminalWaitsWhileInactiveAndContinuesAfterRestart() throws {
        var inactiveMachine = try makeS4Machine()
        _ = try inactiveMachine.handle(
            .applicationBecameInactive,
            persist: ignoreS4Persistence
        )
        let terminal = try inactiveMachine.handle(
            .successCallback(
                submissionID: inactiveMachine.snapshot.submissionID,
                receivedAt: fixedDate
            ),
            persist: ignoreS4Persistence
        )
        XCTAssertEqual(terminal.effect, .none)

        let resumed = try inactiveMachine.handle(
            .applicationBecameActive,
            persist: ignoreS4Persistence
        )
        assertHandoffTarget(resumed, equals: .movedToRecentlyDeleted)

        _ = try inactiveMachine.handle(.processTerminated, persist: ignoreS4Persistence)
        var restored = try S4StateMachine.restore(
            persistentState: inactiveMachine.persistentState,
            persist: ignoreS4Persistence
        )
        let restarted = try restored.handle(
            .applicationBecameActive,
            persist: ignoreS4Persistence
        )
        assertHandoffTarget(restarted, equals: .movedToRecentlyDeleted)
    }

    func testC34_152FailureTerminalResultSetsRemainImmutableForEveryLaterEvent() throws {
        var machine = try makeFailureMachine()
        guard case let .batchFailed(original) = machine.state else {
            return XCTFail("应先形成失败终态")
        }

        let events: [S4Event] = [
            .duplicateSubmissionAttempt,
            .applicationBecameInactive,
            .applicationBecameActive,
            .successCallback(
                submissionID: machine.snapshot.submissionID,
                receivedAt: fixedDate.addingTimeInterval(1)
            ),
            .failureCallback(makeFailureCallback(message: "迟到回调")),
            .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
            .processTerminated
        ]
        for event in events {
            _ = try machine.handle(event, persist: ignoreS4Persistence)
            guard case let .batchFailed(current) = machine.state else {
                return XCTFail("后续事件不得改写失败终态")
            }
            XCTAssertEqual(current.successfulAssetIDs, original.successfulAssetIDs)
            XCTAssertEqual(current.failedAssetIDs, original.failedAssetIDs)
            XCTAssertEqual(current.unprocessedAssetIDs, original.unprocessedAssetIDs)
        }
    }

    func testC34_153FailureTerminalRejectsWholeAndPartialResubmission() throws {
        let registry = SubmissionRegistry()
        let original = makeSnapshot()
        var machine = try makeS4Machine(snapshot: original, registry: registry)
        _ = try machine.handle(
            .failureCallback(makeFailureCallback()),
            persist: ignoreS4Persistence
        )

        for candidate in submissionVariants(of: original) {
            assertDuplicateStartIsRejected(candidate, registry: registry)
        }
        let transition = try machine.handle(
            .duplicateSubmissionAttempt,
            persist: ignoreS4Persistence
        )
        XCTAssertEqual(transition.rejection, .duplicateSubmission)
    }

    func testC34_157FailureTargetSurvivesTerminationWithoutReclassification() throws {
        let callback = makeCancellationCallback(category: .unknown)
        let state = S4PersistentState(
            snapshot: makeSnapshot(),
            state: .batchFailed(callback),
            activeElapsedSeconds: 9,
            isApplicationActive: false,
            timeoutIsRunning: false,
            downstreamTargetState: .cancelled
        )
        var restored = try S4StateMachine.restore(
            persistentState: state,
            persist: ignoreS4Persistence
        )

        let transition = try restored.handle(
            .applicationBecameActive,
            persist: ignoreS4Persistence
        )
        assertHandoffTarget(transition, equals: .cancelled)
        guard case let .handoff(handoff) = transition.effect else {
            return XCTFail("恢复 active 后应交接")
        }
        let completion = try S5StateMachine.enter(
            from: handoff,
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in }
        )
        guard case .cancelled = completion.state else {
            return XCTFail("必须沿用已持久化的取消目标")
        }
    }

    func testC34_163UnknownTerminalRejectsSuccessAndFailureInference() throws {
        var machine = try makeUnknownMachine()
        let originalState = machine.state

        let success = try machine.handle(
            .successCallback(
                submissionID: machine.snapshot.submissionID,
                receivedAt: fixedDate
            ),
            persist: ignoreS4Persistence
        )
        let failure = try machine.handle(
            .failureCallback(makeFailureCallback()),
            persist: ignoreS4Persistence
        )

        XCTAssertEqual(success.rejection, .terminalAlreadyClosed)
        XCTAssertEqual(failure.rejection, .terminalAlreadyClosed)
        XCTAssertEqual(machine.state, originalState)
        XCTAssertNil(PersistedSession(s4: machine.persistentState).failure)
    }

    func testC34_165UnknownTerminalRejectsWholeAndPartialResubmission() throws {
        let registry = SubmissionRegistry()
        let original = makeSnapshot()
        var machine = try makeS4Machine(snapshot: original, registry: registry)
        _ = try machine.handle(
            .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
            persist: ignoreS4Persistence
        )

        for candidate in submissionVariants(of: original) {
            assertDuplicateStartIsRejected(candidate, registry: registry)
        }
        let transition = try machine.handle(
            .duplicateSubmissionAttempt,
            persist: ignoreS4Persistence
        )
        XCTAssertEqual(transition.rejection, .duplicateSubmission)
        XCTAssertEqual(machine.snapshot, original)
    }

    func testC34_166LateFailureCannotOverwriteUnknownTerminal() throws {
        var machine = try makeUnknownMachine()
        let originalState = machine.state

        let transition = try machine.handle(
            .failureCallback(makeFailureCallback(message: "迟到失败")),
            persist: ignoreS4Persistence
        )

        XCTAssertEqual(transition.rejection, .terminalAlreadyClosed)
        XCTAssertEqual(transition.effect, .none)
        XCTAssertEqual(machine.state, originalState)
        XCTAssertEqual(machine.persistentState.downstreamTargetState, .unknown)
    }

    func testC34_186RestoredCancellationTerminalUsesPersistedTargetOnActive() throws {
        let state = S4PersistentState(
            snapshot: makeSnapshot(),
            state: .batchFailed(makeCancellationCallback()),
            activeElapsedSeconds: 12,
            isApplicationActive: false,
            timeoutIsRunning: false,
            downstreamTargetState: .cancelled
        )
        var restored = try S4StateMachine.restore(
            persistentState: state,
            persist: ignoreS4Persistence
        )

        let transition = try restored.handle(
            .applicationBecameActive,
            persist: ignoreS4Persistence
        )

        assertHandoffTarget(transition, equals: .cancelled)
        XCTAssertEqual(restored.persistentState.downstreamTargetState, .cancelled)
    }

    func testC34_209SuccessTerminalContinuesHandoffAfterTerminationAndRestart() throws {
        var machine = try makeSuccessMachine()
        _ = try machine.handle(.processTerminated, persist: ignoreS4Persistence)

        let transition = try restoreAndActivate(machine.persistentState)

        assertHandoffTarget(transition, equals: .movedToRecentlyDeleted)
    }

    func testC34_210FailureTerminalContinuesHandoffAfterTerminationAndRestart() throws {
        var machine = try makeFailureMachine()
        _ = try machine.handle(.processTerminated, persist: ignoreS4Persistence)

        let transition = try restoreAndActivate(machine.persistentState)

        assertHandoffTarget(transition, equals: .failed)
    }

    func testC34_211UnknownTerminalContinuesHandoffAfterTerminationAndRestart() throws {
        var machine = try makeUnknownMachine()
        _ = try machine.handle(.processTerminated, persist: ignoreS4Persistence)

        let transition = try restoreAndActivate(machine.persistentState)

        assertHandoffTarget(transition, equals: .unknown)
    }

    func testC5_006SuccessAndUnknownExitDoNotSubmitOrStartScanning() throws {
        var readCount = 0
        var success = try makeSuccessS5Machine {
            readCount += 1
            return 5
        }
        var unknown = try makeUnknownS5Machine()
        let countBeforeExit = readCount

        let successExit = try success.handle(
            .leavePage,
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 6
            }
        )
        let unknownExit = try unknown.handle(
            .leavePage,
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 7
            }
        )

        XCTAssertEqual(successExit.effect, .exitCleanup)
        XCTAssertEqual(unknownExit.effect, .exitCleanup)
        XCTAssertEqual(readCount, countBeforeExit)
        XCTAssertEqual(success.state.snapshot.submissionID, makeSnapshot().submissionID)
        XCTAssertEqual(unknown.state.snapshot.submissionID, makeSnapshot().submissionID)
    }

    func testC5_031RepeatedLifecycleTicksNeverPollFreeDisk() throws {
        var readCount = 0
        var machine = try makeSuccessS5Machine {
            readCount += 1
            return 10
        }
        _ = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 12
            }
        )
        let forbiddenRead: () -> Double? = {
            readCount += 1
            return 99
        }

        for _ in 0..<20 {
            _ = try machine.handle(
                .applicationBecameActive,
                persist: ignoreS5Persistence,
                readFreeDiskStrictGB: forbiddenRead
            )
        }

        XCTAssertEqual(readCount, 2)
    }

    func testC5_034SuccessOnlyLeavesThroughExitAndCannotModifySubmission() throws {
        var machine = try makeSuccessS5Machine()
        let originalSnapshot = machine.state.snapshot

        let returnAttempt = try machine.handle(
            .returnToConfirmation(cacheExists: true),
            persist: ignoreS5Persistence
        )
        XCTAssertEqual(returnAttempt.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(machine.state.snapshot, originalSnapshot)

        let exit = try machine.handle(.leavePage, persist: ignoreS5Persistence)
        XCTAssertEqual(exit.effect, .exitCleanup)
        XCTAssertEqual(machine.state.snapshot, originalSnapshot)
    }

    func testC5_039CompletedReadingsSurviveTerminationAndRestoreWithoutNewRead() throws {
        var readCount = 0
        var machine = try makeSuccessS5Machine {
            readCount += 1
            return 10
        }
        _ = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 13.5
            }
        )
        _ = try machine.handle(.processTerminated, persist: ignoreS5Persistence)

        let restored = try S5StateMachine.restore(
            persistentState: machine.persistentState,
            persist: ignoreS5Persistence
        )

        XCTAssertEqual(readCount, 2)
        XCTAssertEqual(restored.persistentState.l3BaselineReading, .available(10))
        XCTAssertEqual(restored.persistentState.l3CompletionReading, .available(13.5))
        XCTAssertEqual(restored.persistentState.l3DeltaGB, 3.5)
        XCTAssertEqual(restored.persistentState.recentlyDeletedClearedAt, fixedDate)
        guard case .movedToRecentlyDeleted = restored.state else {
            return XCTFail("重启后应恢复 S5-T0")
        }
    }

    func testC5_069FailureNeverReadsFreeDiskOrDisplaysL3() throws {
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeFailureHandoff(),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in },
            readFreeDiskStrictGB: {
                readCount += 1
                return 8
            }
        )

        let confirmation = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 9
            }
        )
        _ = try machine.handle(
            .applicationBecameActive,
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 10
            }
        )

        XCTAssertEqual(confirmation.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(readCount, 0)
        XCTAssertFalse(machine.state.presentationCapabilities.showsL3)
        XCTAssertNil(machine.persistentState.l3BaselineReading)
    }

    func testC5_086UnknownCannotReadConfirmOrWriteBackManualResult() throws {
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeUnknownHandoff(),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in },
            readFreeDiskStrictGB: {
                readCount += 1
                return 8
            }
        )

        let confirmation = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 9
            }
        )

        XCTAssertEqual(confirmation.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(readCount, 0)
        XCTAssertFalse(
            machine.state.presentationCapabilities.showsRecentlyDeletedConfirmationAction
        )
        XCTAssertNil(PersistedSession(s5: machine.persistentState).failure)
    }

    func testC5_087UnknownCannotResubmitModifyPOrReturnToConfirmation() throws {
        var machine = try makeUnknownS5Machine()
        let originalSnapshot = machine.state.snapshot

        let returnAttempt = try machine.handle(
            .returnToConfirmation(cacheExists: true),
            persist: ignoreS5Persistence
        )
        let confirmationAttempt = try machine.handle(
            .confirmRecentlyDeletedCleared(declaredAt: fixedDate),
            persist: ignoreS5Persistence
        )

        XCTAssertEqual(returnAttempt.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(confirmationAttempt.rejection, .actionUnavailableInCurrentState)
        XCTAssertEqual(machine.state.snapshot, originalSnapshot)
    }

    func testC5_101UnknownEntryPersistsReasonAndSnapshotBeforeReturning() throws {
        var persistedStates: [S5PersistentState] = []

        let machine = try S5StateMachine.enter(
            from: makeUnknownHandoff(),
            persist: { persistedStates.append($0) },
            invalidateOldLists: { _ in }
        )

        XCTAssertEqual(persistedStates, [machine.persistentState])
        guard case let .unknown(context) = persistedStates[0].state else {
            return XCTFail("持久化状态应为 S5-U")
        }
        XCTAssertEqual(context.reason, .activeWaitTimedOut)
        XCTAssertEqual(context.snapshot, makeSnapshot())
    }

    func testC5_143NewDeletionMustReturnToS3AndFreezeNewSnapshot() throws {
        var completion = try makeFailureS5Machine()
        let transition = try completion.handle(
            .returnToConfirmation(cacheExists: true),
            persist: ignoreS5Persistence
        )
        XCTAssertEqual(
            transition.effect,
            .returnToConfirmation(
                target: .ready,
                assetIDs: makeSnapshot().assetIDs
            )
        )

        let assets = makeSnapshot().assetIDs.map {
            AssetDescriptor(identifier: $0, isFavorite: false)
        }
        let cache = Dictionary(
            uniqueKeysWithValues: makeSnapshot().assetIDs.map { ($0, AssetScanConclusion.knownBytes(1)) }
        )
        let confirmation = S3StateMachine(
            assets: assets,
            cachedConclusions: cache,
            submissionIDGenerator: { "提交-002" },
            clock: { self.fixedDate.addingTimeInterval(1) }
        )

        guard case let .frozen(nextSnapshot) = confirmation.freezeSubmissionSnapshot() else {
            return XCTFail("后续提交必须由 S3 冻结新快照")
        }
        XCTAssertEqual(nextSnapshot.submissionID, "提交-002")
        XCTAssertNotEqual(nextSnapshot.submissionID, makeSnapshot().submissionID)
    }

    func testC5_144SuccessExitClearsPersistedL3Session() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let fileManager = IsolatedFileManager(applicationSupportRoot: temporaryRoot)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        try await MainActor.run {
            var machine = try self.makeSuccessS5Machine { 20 }
            _ = try machine.handle(
                .confirmRecentlyDeletedCleared(declaredAt: self.fixedDate),
                persist: self.ignoreS5Persistence,
                readFreeDiskStrictGB: { 23 }
            )
            let persistence = SessionPersistence(fileManager: fileManager)
            try persistence.save(PersistedSession(s5: machine.persistentState))
            XCTAssertEqual(persistence.load()?.l3DeltaGB, 3)

            let coordinator = CleanupCoordinator(persistence: persistence)
            coordinator.start()
            XCTAssertEqual(coordinator.route, .completion)
            coordinator.leaveCompletion()

            XCTAssertEqual(coordinator.route, .finished)
            XCTAssertNil(persistence.load())
            XCTAssertNil(coordinator.s5Machine)
        }
    }

    func testC5_145UnknownExitDoesNotInferResultOrResubmit() throws {
        var readCount = 0
        var machine = try S5StateMachine.enter(
            from: makeUnknownHandoff(),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in },
            readFreeDiskStrictGB: {
                readCount += 1
                return 7
            }
        )
        let before = PersistedSession(s5: machine.persistentState)

        let transition = try machine.handle(
            .leavePage,
            persist: ignoreS5Persistence,
            readFreeDiskStrictGB: {
                readCount += 1
                return 8
            }
        )

        XCTAssertEqual(transition.effect, .exitCleanup)
        XCTAssertEqual(readCount, 0)
        XCTAssertNil(before.failure)
        XCTAssertEqual(before.phase, .completionUnknown)
        guard case .unknown = machine.state else {
            return XCTFail("离开不得推断未知结果")
        }
    }

    private func makeSnapshot(
        submissionID: String = "提交-001",
        assetIDs: [String] = ["资产-A", "资产-B", "资产-C"]
    ) -> SubmissionSnapshot {
        SubmissionSnapshot(
            submissionID: submissionID,
            assetIDs: assetIDs,
            assetCount: assetIDs.count,
            knownTotalBytes: Int64(assetIDs.count * 1_000),
            unavailableCount: 0,
            volumeDisplayMode: .exact,
            favoriteAssetIDs: [],
            frozenAt: fixedDate
        )
    }

    private func submissionVariants(of snapshot: SubmissionSnapshot) -> [SubmissionSnapshot] {
        [
            snapshot,
            makeSnapshot(submissionID: snapshot.submissionID, assetIDs: ["资产-A", "资产-B"]),
            makeSnapshot(submissionID: snapshot.submissionID, assetIDs: ["资产-C"])
        ]
    }

    private func makeFailureCallback(
        message: String = "整批请求失败",
        category: S4FailureCategory = .assetNotDeletable
    ) -> S4FailureCallback {
        S4FailureCallback(
            submissionID: makeSnapshot().submissionID,
            successfulAssetIDs: ["资产-A"],
            failedAssetIDs: ["资产-B"],
            unprocessedAssetIDs: ["资产-C"],
            reason: S4FailureReason(
                category: category,
                message: message,
                systemDomain: "测试域",
                systemCode: 10
            ),
            receivedAt: fixedDate
        )
    }

    private func makeCancellationCallback(
        category: S4FailureCategory = .userCancelled
    ) -> S4FailureCallback {
        S4FailureCallback(
            submissionID: makeSnapshot().submissionID,
            successfulAssetIDs: [],
            failedAssetIDs: [],
            unprocessedAssetIDs: Set(makeSnapshot().assetIDs),
            reason: S4FailureReason(
                category: category,
                message: "系统操作已取消",
                systemDomain: "测试取消域",
                systemCode: 71
            ),
            receivedAt: fixedDate
        )
    }

    private func makeS4Machine(
        snapshot: SubmissionSnapshot? = nil,
        registry: SubmissionRegistry? = nil
    ) throws -> S4StateMachine {
        let input = snapshot ?? makeSnapshot()
        if let registry {
            return try S4StateMachine.start(
                snapshot: input,
                claimAndPersist: registry.claim
            )
        }
        return try S4StateMachine.start(snapshot: input, claimAndPersist: { _ in true })
    }

    private func makeSuccessMachine() throws -> S4StateMachine {
        var machine = try makeS4Machine()
        _ = try machine.handle(
            .successCallback(
                submissionID: machine.snapshot.submissionID,
                receivedAt: fixedDate
            ),
            persist: ignoreS4Persistence
        )
        return machine
    }

    private func makeFailureMachine() throws -> S4StateMachine {
        var machine = try makeS4Machine()
        _ = try machine.handle(
            .failureCallback(makeFailureCallback()),
            persist: ignoreS4Persistence
        )
        return machine
    }

    private func makeUnknownMachine() throws -> S4StateMachine {
        var machine = try makeS4Machine()
        _ = try machine.handle(
            .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
            persist: ignoreS4Persistence
        )
        return machine
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

    private func makeUnknownHandoff() -> S4Handoff {
        .unknown(
            snapshot: makeSnapshot(),
            reason: .activeWaitTimedOut,
            downstreamTargetState: .unknown
        )
    }

    private func makeSuccessS5Machine(
        read: @escaping () -> Double? = { 10 }
    ) throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in },
            readFreeDiskStrictGB: read
        )
    }

    private func makeFailureS5Machine() throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: makeFailureHandoff(),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in }
        )
    }

    private func makeUnknownS5Machine() throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: makeUnknownHandoff(),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in }
        )
    }

    private func assertDuplicateStartIsRejected(
        _ snapshot: SubmissionSnapshot,
        registry: SubmissionRegistry,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try S4StateMachine.start(
                snapshot: snapshot,
                claimAndPersist: registry.claim
            ),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? S4StateMachineError,
                .duplicateSubmission,
                file: file,
                line: line
            )
        }
    }

    private func assertHandoffTarget(
        _ transition: S4Transition,
        equals expected: S4DownstreamTargetState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .handoff(handoff) = transition.effect else {
            return XCTFail("应产生页面交接", file: file, line: line)
        }
        XCTAssertEqual(handoff.downstreamTargetState, expected, file: file, line: line)
    }

    private func restoreAndActivate(_ state: S4PersistentState) throws -> S4Transition {
        var restored = try S4StateMachine.restore(
            persistentState: state,
            persist: ignoreS4Persistence
        )
        return try restored.handle(
            .applicationBecameActive,
            persist: ignoreS4Persistence
        )
    }

    private func ignoreS4Persistence(_ state: S4PersistentState) throws {
        _ = state
    }

    private func ignoreS5Persistence(_ state: S5PersistentState) throws {
        _ = state
    }
}
