import XCTest
@testable import PhotoCleanupMVE

final class S4StateMachineTests: XCTestCase {
    private enum TestError: Error {
        case persistenceFailed
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_786_291_200)

    // 可达单元格 1：外部提交进入已提交状态。
    func testReachable01SubmissionFromExternalSource() throws {
        var persisted: S4PersistentState?
        let machine = try S4StateMachine.start(snapshot: makeSnapshot()) {
            persisted = $0
            return true
        }

        XCTAssertEqual(machine.state, .submitted)
        XCTAssertEqual(persisted, machine.persistentState)
        XCTAssertEqual(machine.activeElapsedSeconds, 0)
        XCTAssertTrue(machine.timeoutIsRunning)
    }

    // 可达单元格 2：已提交时进入非活动态。
    func testReachable02InactiveFromSubmitted() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, .submitted)
        XCTAssertFalse(machine.isApplicationActive)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 3：已恢复交互时进入非活动态。
    func testReachable03InactiveFromResumedInteraction() throws {
        var machine = try makeResumedMachine()
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, .resumedInteraction)
        XCTAssertFalse(machine.isApplicationActive)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 4：成功终态进入非活动态时保持封闭。
    func testReachable04InactiveFromSuccessTerminal() throws {
        var machine = try makeSuccessMachine()
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        assertSuccess(transition.toState)
        XCTAssertEqual(transition.effect, .none)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 5：失败终态进入非活动态时保持封闭。
    func testReachable05InactiveFromFailureTerminal() throws {
        var machine = try makeFailureMachine()
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        assertFailure(transition.toState)
        XCTAssertEqual(transition.effect, .none)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 6：未知终态进入非活动态时保持封闭。
    func testReachable06InactiveFromUnknownTerminal() throws {
        var machine = try makeUnknownMachine()
        let transition = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, .resultUnknown(.activeWaitTimedOut))
        XCTAssertEqual(transition.effect, .none)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 7：已提交状态恢复活动后进入已恢复交互。
    func testReachable07ActiveFromSubmitted() throws {
        var machine = try makeMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, .resumedInteraction)
        XCTAssertTrue(machine.isApplicationActive)
        XCTAssertTrue(machine.timeoutIsRunning)
    }

    // 可达单元格 8：已恢复交互状态再次恢复活动时保持原状态。
    func testReachable08ActiveFromResumedInteraction() throws {
        var machine = try makeResumedMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, .resumedInteraction)
        XCTAssertTrue(machine.timeoutIsRunning)
    }

    // 可达单元格 9：成功终态恢复活动后交接成功结果。
    func testReachable09ActiveFromSuccessTerminal() throws {
        var machine = try makeMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        _ = try machine.handle(
            .successCallback(submissionID: makeSnapshot().submissionID, receivedAt: fixedDate),
            persist: ignorePersistence
        )
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        guard case let .handoff(.success(snapshot, result)) = transition.effect else {
            return XCTFail("应交接成功结果")
        }
        XCTAssertEqual(snapshot, makeSnapshot())
        XCTAssertEqual(result.successfulAssetIDs, Set(makeSnapshot().assetIDs))
    }

    // 可达单元格 10：失败终态恢复活动后交接失败结果。
    func testReachable10ActiveFromFailureTerminal() throws {
        var machine = try makeMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        _ = try machine.handle(.failureCallback(makeFailureCallback()), persist: ignorePersistence)
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        guard case let .handoff(.failure(snapshot, callback)) = transition.effect else {
            return XCTFail("应交接失败结果")
        }
        XCTAssertEqual(snapshot, makeSnapshot())
        XCTAssertEqual(callback, makeFailureCallback())
    }

    // 可达单元格 11：未知终态恢复活动后交接未知结果。
    func testReachable11ActiveFromUnknownTerminal() throws {
        var machine = try makeMachine()
        _ = try machine.handle(.processTerminated, persist: ignorePersistence)
        let transition = try machine.handle(.applicationBecameActive, persist: ignorePersistence)

        guard case let .handoff(.unknown(snapshot, reason)) = transition.effect else {
            return XCTFail("应交接未知结果")
        }
        XCTAssertEqual(snapshot, makeSnapshot())
        XCTAssertEqual(reason, .processTerminatedBeforeTerminalResult)
    }

    // 可达单元格 12：已提交状态收到成功回调。
    func testReachable12SuccessCallbackFromSubmitted() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(
            .successCallback(submissionID: makeSnapshot().submissionID, receivedAt: fixedDate),
            persist: ignorePersistence
        )

        assertSuccess(transition.toState)
        XCTAssertFalse(machine.timeoutIsRunning)
        guard case .handoff(.success(_, _)) = transition.effect else {
            return XCTFail("活动态收到回调后应立即交接")
        }
    }

    // 可达单元格 13：已恢复交互状态收到成功回调。
    func testReachable13SuccessCallbackFromResumedInteraction() throws {
        var machine = try makeResumedMachine()
        let transition = try machine.handle(
            .successCallback(submissionID: makeSnapshot().submissionID, receivedAt: fixedDate),
            persist: ignorePersistence
        )

        assertSuccess(transition.toState)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 14：已提交状态收到失败回调。
    func testReachable14FailureCallbackFromSubmitted() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(
            .failureCallback(makeFailureCallback()),
            persist: ignorePersistence
        )

        assertFailure(transition.toState)
        XCTAssertFalse(machine.timeoutIsRunning)
        guard case .handoff(.failure(_, _)) = transition.effect else {
            return XCTFail("活动态收到回调后应立即交接")
        }
    }

    // 可达单元格 15：已恢复交互状态收到失败回调。
    func testReachable15FailureCallbackFromResumedInteraction() throws {
        var machine = try makeResumedMachine()
        let transition = try machine.handle(
            .failureCallback(makeFailureCallback()),
            persist: ignorePersistence
        )

        assertFailure(transition.toState)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 16：已提交状态累计满六十秒进入未知终态。
    func testReachable16TimeoutFromSubmitted() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(
            .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.toState, .resultUnknown(.activeWaitTimedOut))
        XCTAssertEqual(machine.activeElapsedSeconds, S4StateMachine.timeoutLimitSeconds)
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 17：已恢复交互状态累计满六十秒进入未知终态。
    func testReachable17TimeoutFromResumedInteraction() throws {
        var machine = try makeResumedMachine()
        let transition = try machine.handle(
            .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.toState, .resultUnknown(.activeWaitTimedOut))
        XCTAssertFalse(machine.timeoutIsRunning)
    }

    // 可达单元格 18：已提交期间被终止后进入未知终态。
    func testReachable18TerminationFromSubmitted() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        XCTAssertEqual(
            transition.toState,
            .resultUnknown(.processTerminatedBeforeTerminalResult)
        )
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 19：已恢复交互期间被终止后进入未知终态。
    func testReachable19TerminationFromResumedInteraction() throws {
        var machine = try makeResumedMachine()
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        XCTAssertEqual(
            transition.toState,
            .resultUnknown(.processTerminatedBeforeTerminalResult)
        )
    }

    // 可达单元格 20：成功终态被终止后仍保留成功终态。
    func testReachable20TerminationFromSuccessTerminal() throws {
        var machine = try makeSuccessMachine()
        let before = machine.state
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, before)
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 21：失败终态被终止后仍保留失败终态。
    func testReachable21TerminationFromFailureTerminal() throws {
        var machine = try makeFailureMachine()
        let before = machine.state
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, before)
        XCTAssertFalse(machine.isApplicationActive)
    }

    // 可达单元格 22：未知终态被终止后仍保留未知终态。
    func testReachable22TerminationFromUnknownTerminal() throws {
        var machine = try makeUnknownMachine()
        let transition = try machine.handle(.processTerminated, persist: ignorePersistence)

        XCTAssertEqual(transition.toState, .resultUnknown(.activeWaitTimedOut))
        XCTAssertFalse(machine.isApplicationActive)
    }

    func testDuplicateSubmissionIsRejected() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(.duplicateSubmissionAttempt, persist: ignorePersistence)

        XCTAssertEqual(transition.rejection, .duplicateSubmission)
        XCTAssertEqual(machine.state, .submitted)
    }

    func testElapsedTimeBelowLimitKeepsPendingState() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(.activeTimeAdvanced(59.999), persist: ignorePersistence)

        XCTAssertEqual(transition.toState, .submitted)
        XCTAssertEqual(machine.activeElapsedSeconds, 59.999, accuracy: 0.000_1)
        XCTAssertTrue(machine.timeoutIsRunning)
    }

    func testInactiveDurationDoesNotAccumulate() throws {
        var machine = try makeMachine()
        _ = try machine.handle(.activeTimeAdvanced(20), persist: ignorePersistence)
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        let transition = try machine.handle(.activeTimeAdvanced(100), persist: ignorePersistence)

        XCTAssertEqual(transition.rejection, .activeTimerPaused)
        XCTAssertEqual(machine.activeElapsedSeconds, 20)
        XCTAssertEqual(machine.state, .submitted)
    }

    func testResumeContinuesRemainingActiveTime() throws {
        var machine = try makeMachine()
        _ = try machine.handle(.activeTimeAdvanced(25), persist: ignorePersistence)
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        _ = try machine.handle(.applicationBecameActive, persist: ignorePersistence)
        _ = try machine.handle(.activeTimeAdvanced(35), persist: ignorePersistence)

        XCTAssertEqual(machine.activeElapsedSeconds, 60)
        XCTAssertEqual(machine.state, .resultUnknown(.activeWaitTimedOut))
    }

    func testMismatchedSuccessCallbackIsRejected() throws {
        var machine = try makeMachine()
        let transition = try machine.handle(
            .successCallback(submissionID: "其他提交", receivedAt: fixedDate),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.rejection, .callbackSubmissionMismatch)
        XCTAssertEqual(machine.state, .submitted)
    }

    func testMismatchedFailureCallbackIsRejected() throws {
        var machine = try makeMachine()
        let callback = makeFailureCallback(submissionID: "其他提交")
        let transition = try machine.handle(.failureCallback(callback), persist: ignorePersistence)

        XCTAssertEqual(transition.rejection, .callbackSubmissionMismatch)
        XCTAssertEqual(machine.state, .submitted)
    }

    func testLateFailureCannotOverwriteSuccess() throws {
        var machine = try makeSuccessMachine()
        let before = machine.state
        let transition = try machine.handle(
            .failureCallback(makeFailureCallback()),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.rejection, .terminalAlreadyClosed)
        XCTAssertEqual(machine.state, before)
    }

    func testLateSuccessCannotOverwriteFailure() throws {
        var machine = try makeFailureMachine()
        let before = machine.state
        let transition = try machine.handle(
            .successCallback(submissionID: makeSnapshot().submissionID, receivedAt: fixedDate),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.rejection, .terminalAlreadyClosed)
        XCTAssertEqual(machine.state, before)
    }

    func testLateCallbackCannotOverwriteUnknown() throws {
        var machine = try makeUnknownMachine()
        let transition = try machine.handle(
            .successCallback(submissionID: makeSnapshot().submissionID, receivedAt: fixedDate),
            persist: ignorePersistence
        )

        XCTAssertEqual(transition.rejection, .terminalAlreadyClosed)
        XCTAssertEqual(machine.state, .resultUnknown(.activeWaitTimedOut))
    }

    func testPersistenceFailureLeavesCallbackStateUnchanged() throws {
        var machine = try makeMachine()

        XCTAssertThrowsError(
            try machine.handle(
                .failureCallback(makeFailureCallback()),
                persist: { _ in throw TestError.persistenceFailed }
            )
        )
        XCTAssertEqual(machine.state, .submitted)
        XCTAssertTrue(machine.timeoutIsRunning)
    }

    func testSnapshotNeverChangesInsideExecutionState() throws {
        var machine = try makeMachine()
        let original = machine.snapshot
        _ = try machine.handle(.activeTimeAdvanced(15), persist: ignorePersistence)
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        _ = try machine.handle(.applicationBecameActive, persist: ignorePersistence)
        _ = try machine.handle(
            .successCallback(submissionID: original.submissionID, receivedAt: fixedDate),
            persist: ignorePersistence
        )

        XCTAssertEqual(machine.snapshot, original)
    }

    func testRestoreConvertsSubmittedStateToUnknown() throws {
        let original = try makeMachine()
        let restored = try S4StateMachine.restore(
            persistentState: original.persistentState,
            persist: ignorePersistence
        )

        XCTAssertEqual(
            restored.state,
            .resultUnknown(.processTerminatedBeforeTerminalResult)
        )
        XCTAssertFalse(restored.isApplicationActive)
        XCTAssertFalse(restored.timeoutIsRunning)
    }

    func testRestoreConvertsResumedStateToUnknown() throws {
        let original = try makeResumedMachine()
        let restored = try S4StateMachine.restore(
            persistentState: original.persistentState,
            persist: ignorePersistence
        )

        XCTAssertEqual(
            restored.state,
            .resultUnknown(.processTerminatedBeforeTerminalResult)
        )
    }

    func testRestoreKeepsClosedTerminalState() throws {
        let original = try makeFailureMachine()
        let restored = try S4StateMachine.restore(
            persistentState: original.persistentState,
            persist: ignorePersistence
        )

        XCTAssertEqual(restored.state, original.state)
        XCTAssertFalse(restored.timeoutIsRunning)
    }

    func testStartPersistenceFailurePreventsMachineCreation() {
        XCTAssertThrowsError(
            try S4StateMachine.start(
                snapshot: makeSnapshot(),
                claimAndPersist: { _ in throw TestError.persistenceFailed }
            )
        )
    }

    func testSecondStartWithSameSubmissionIdentifierIsRejected() throws {
        var claimedIdentifiers: Set<String> = []
        let claim: (S4PersistentState) throws -> Bool = { state in
            claimedIdentifiers.insert(state.snapshot.submissionID).inserted
        }

        _ = try S4StateMachine.start(
            snapshot: makeSnapshot(),
            claimAndPersist: claim
        )
        XCTAssertThrowsError(
            try S4StateMachine.start(
                snapshot: makeSnapshot(),
                claimAndPersist: claim
            )
        ) { error in
            XCTAssertEqual(error as? S4StateMachineError, .duplicateSubmission)
        }
    }

    private func makeSnapshot() -> SubmissionSnapshot {
        SubmissionSnapshot(
            submissionID: "提交-001",
            assetIDs: ["资产-A", "资产-B", "资产-C"],
            assetCount: 3,
            knownTotalBytes: 3_000,
            unavailableCount: 0,
            volumeDisplayMode: .exact,
            favoriteAssetIDs: ["资产-B"],
            frozenAt: fixedDate
        )
    }

    private func makeFailureCallback(
        submissionID: String = "提交-001",
        successful: Set<String> = ["资产-A"],
        failed: Set<String> = ["资产-B"],
        unprocessed: Set<String> = ["资产-C"],
        message: String = "系统未能完成整批请求"
    ) -> S4FailureCallback {
        S4FailureCallback(
            submissionID: submissionID,
            successfulAssetIDs: successful,
            failedAssetIDs: failed,
            unprocessedAssetIDs: unprocessed,
            reason: S4FailureReason(
                category: .unknown,
                message: message,
                systemDomain: "测试错误域",
                systemCode: 7
            ),
            receivedAt: fixedDate
        )
    }

    private func makeMachine() throws -> S4StateMachine {
        try S4StateMachine.start(
            snapshot: makeSnapshot(),
            claimAndPersist: acceptInitialPersistence
        )
    }

    private func makeResumedMachine() throws -> S4StateMachine {
        var machine = try makeMachine()
        _ = try machine.handle(.applicationBecameInactive, persist: ignorePersistence)
        _ = try machine.handle(.applicationBecameActive, persist: ignorePersistence)
        return machine
    }

    private func makeSuccessMachine() throws -> S4StateMachine {
        var machine = try makeMachine()
        _ = try machine.handle(
            .successCallback(submissionID: makeSnapshot().submissionID, receivedAt: fixedDate),
            persist: ignorePersistence
        )
        return machine
    }

    private func makeFailureMachine() throws -> S4StateMachine {
        var machine = try makeMachine()
        _ = try machine.handle(.failureCallback(makeFailureCallback()), persist: ignorePersistence)
        return machine
    }

    private func makeUnknownMachine() throws -> S4StateMachine {
        var machine = try makeMachine()
        _ = try machine.handle(
            .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
            persist: ignorePersistence
        )
        return machine
    }

    private func assertSuccess(
        _ state: S4State,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .allSucceeded = state else {
            return XCTFail("预期成功终态", file: file, line: line)
        }
    }

    private func assertFailure(
        _ state: S4State,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .batchFailed = state else {
            return XCTFail("预期失败终态", file: file, line: line)
        }
    }

    private func ignorePersistence(_ state: S4PersistentState) throws {
        _ = state
    }

    private func acceptInitialPersistence(_ state: S4PersistentState) throws -> Bool {
        _ = state
        return true
    }
}
