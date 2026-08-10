import Foundation

enum S4FailureCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case insufficientPermission
    case assetNotDeletable
    case userCancelled
    case unknown
}

struct S4FailureReason: Equatable, Codable, Sendable {
    let category: S4FailureCategory
    let message: String
    let systemDomain: String?
    let systemCode: Int?

    var isValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct S4FailureCallback: Equatable, Codable, Sendable {
    let submissionID: String
    let successfulAssetIDs: Set<String>
    let failedAssetIDs: Set<String>
    let unprocessedAssetIDs: Set<String>
    let reason: S4FailureReason
    let receivedAt: Date
}

struct S4SuccessResult: Equatable, Codable, Sendable {
    let submissionID: String
    let successfulAssetIDs: Set<String>
    let receivedAt: Date
}

enum S4UnknownReason: String, Codable, Equatable, Sendable {
    case activeWaitTimedOut
    case processTerminatedBeforeTerminalResult
}

enum S4State: Equatable, Sendable {
    case submitted
    case resumedInteraction
    case allSucceeded(S4SuccessResult)
    case batchFailed(S4FailureCallback)
    case resultUnknown(S4UnknownReason)

    var isTerminal: Bool {
        switch self {
        case .submitted, .resumedInteraction:
            return false
        case .allSucceeded, .batchFailed, .resultUnknown:
            return true
        }
    }
}

enum S4Handoff: Equatable, Sendable {
    case success(snapshot: SubmissionSnapshot, result: S4SuccessResult)
    case failure(snapshot: SubmissionSnapshot, callback: S4FailureCallback)
    case unknown(snapshot: SubmissionSnapshot, reason: S4UnknownReason)
}

enum S4TransitionEffect: Equatable, Sendable {
    case none
    case handoff(S4Handoff)
}

enum S4RejectionReason: Equatable, Sendable {
    case duplicateSubmission
    case terminalAlreadyClosed
    case callbackSubmissionMismatch
    case resultSetsOverlap
    case resultSetContainsForeignAsset
    case resultSetOmitsAsset
    case emptyFailureReason
    case invalidActiveDuration
    case activeTimerPaused
}

struct S4Transition: Equatable, Sendable {
    let fromState: S4State
    let toState: S4State
    let effect: S4TransitionEffect
    let rejection: S4RejectionReason?

    var isApplied: Bool {
        rejection == nil
    }
}

enum S4Event: Equatable, Sendable {
    case duplicateSubmissionAttempt
    case applicationBecameInactive
    case applicationBecameActive
    case successCallback(submissionID: String, receivedAt: Date)
    case failureCallback(S4FailureCallback)
    case activeTimeAdvanced(TimeInterval)
    case processTerminated
}

enum S4StateMachineError: Error, Equatable {
    case invalidSnapshot
    case invalidPersistentState
    case duplicateSubmission
}

struct S4PersistentState: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    var state: S4State
    var activeElapsedSeconds: TimeInterval
    var isApplicationActive: Bool
    var timeoutIsRunning: Bool
}

struct S4StateMachine: Sendable {
    static let timeoutLimitSeconds: TimeInterval = 60

    private(set) var persistentState: S4PersistentState

    var snapshot: SubmissionSnapshot {
        persistentState.snapshot
    }

    var state: S4State {
        persistentState.state
    }

    var activeElapsedSeconds: TimeInterval {
        persistentState.activeElapsedSeconds
    }

    var isApplicationActive: Bool {
        persistentState.isApplicationActive
    }

    var timeoutIsRunning: Bool {
        persistentState.timeoutIsRunning
    }

    static func restore(
        persistentState: S4PersistentState,
        persist: (S4PersistentState) throws -> Void
    ) throws -> S4StateMachine {
        guard isValid(persistentState.snapshot),
              persistentState.activeElapsedSeconds >= 0,
              persistentState.activeElapsedSeconds.isFinite,
              persistentState.activeElapsedSeconds <= Self.timeoutLimitSeconds else {
            throw S4StateMachineError.invalidPersistentState
        }

        let validator = S4StateMachine(persistentState: persistentState)
        switch persistentState.state {
        case .submitted, .resumedInteraction, .resultUnknown:
            break
        case let .allSucceeded(result):
            guard result.submissionID == persistentState.snapshot.submissionID,
                  result.successfulAssetIDs == Set(persistentState.snapshot.assetIDs) else {
                throw S4StateMachineError.invalidPersistentState
            }
        case let .batchFailed(callback):
            guard validator.validate(callback) == nil else {
                throw S4StateMachineError.invalidPersistentState
            }
        }

        var proposal = persistentState
        proposal.isApplicationActive = false
        proposal.timeoutIsRunning = false
        if !proposal.state.isTerminal {
            proposal.state = .resultUnknown(.processTerminatedBeforeTerminalResult)
        }
        try persist(proposal)
        return S4StateMachine(persistentState: proposal)
    }

    static func start(
        snapshot: SubmissionSnapshot,
        claimAndPersist: (S4PersistentState) throws -> Bool
    ) throws -> S4StateMachine {
        guard isValid(snapshot) else {
            throw S4StateMachineError.invalidSnapshot
        }

        let initialState = S4PersistentState(
            snapshot: snapshot,
            state: .submitted,
            activeElapsedSeconds: 0,
            isApplicationActive: true,
            timeoutIsRunning: true
        )
        guard try claimAndPersist(initialState) else {
            throw S4StateMachineError.duplicateSubmission
        }
        return S4StateMachine(persistentState: initialState)
    }

    mutating func handle(
        _ event: S4Event,
        persist: (S4PersistentState) throws -> Void
    ) throws -> S4Transition {
        switch event {
        case .duplicateSubmissionAttempt:
            return rejected(.duplicateSubmission)

        case .applicationBecameInactive:
            var proposal = persistentState
            proposal.isApplicationActive = false
            proposal.timeoutIsRunning = false
            return try commit(proposal, effect: .none, persist: persist)

        case .applicationBecameActive:
            var proposal = persistentState
            proposal.isApplicationActive = true

            switch proposal.state {
            case .submitted:
                proposal.state = .resumedInteraction
                proposal.timeoutIsRunning = true
                return try commit(proposal, effect: .none, persist: persist)
            case .resumedInteraction:
                proposal.timeoutIsRunning = true
                return try commit(proposal, effect: .none, persist: persist)
            case .allSucceeded, .batchFailed, .resultUnknown:
                proposal.timeoutIsRunning = false
                return try commit(
                    proposal,
                    effect: .handoff(makeHandoff(for: proposal.state)),
                    persist: persist
                )
            }

        case let .successCallback(submissionID, receivedAt):
            guard !state.isTerminal else {
                return rejected(.terminalAlreadyClosed)
            }
            guard submissionID == snapshot.submissionID else {
                return rejected(.callbackSubmissionMismatch)
            }

            let result = S4SuccessResult(
                submissionID: submissionID,
                successfulAssetIDs: Set(snapshot.assetIDs),
                receivedAt: receivedAt
            )
            var proposal = persistentState
            proposal.state = .allSucceeded(result)
            proposal.timeoutIsRunning = false
            let effect: S4TransitionEffect = proposal.isApplicationActive
                ? .handoff(.success(snapshot: snapshot, result: result))
                : .none
            return try commit(proposal, effect: effect, persist: persist)

        case let .failureCallback(callback):
            guard !state.isTerminal else {
                return rejected(.terminalAlreadyClosed)
            }
            if let rejection = validate(callback) {
                return rejected(rejection)
            }

            var proposal = persistentState
            proposal.state = .batchFailed(callback)
            proposal.timeoutIsRunning = false
            let effect: S4TransitionEffect = proposal.isApplicationActive
                ? .handoff(.failure(snapshot: snapshot, callback: callback))
                : .none
            return try commit(proposal, effect: effect, persist: persist)

        case let .activeTimeAdvanced(seconds):
            guard seconds >= 0, seconds.isFinite else {
                return rejected(.invalidActiveDuration)
            }
            guard !state.isTerminal else {
                return rejected(.terminalAlreadyClosed)
            }
            guard isApplicationActive, timeoutIsRunning else {
                return rejected(.activeTimerPaused)
            }

            var proposal = persistentState
            proposal.activeElapsedSeconds = min(
                Self.timeoutLimitSeconds,
                proposal.activeElapsedSeconds + seconds
            )

            guard proposal.activeElapsedSeconds >= Self.timeoutLimitSeconds else {
                return try commit(proposal, effect: .none, persist: persist)
            }

            let reason = S4UnknownReason.activeWaitTimedOut
            proposal.state = .resultUnknown(reason)
            proposal.timeoutIsRunning = false
            let effect: S4TransitionEffect = proposal.isApplicationActive
                ? .handoff(.unknown(snapshot: snapshot, reason: reason))
                : .none
            return try commit(proposal, effect: effect, persist: persist)

        case .processTerminated:
            var proposal = persistentState
            proposal.isApplicationActive = false
            proposal.timeoutIsRunning = false
            if !proposal.state.isTerminal {
                proposal.state = .resultUnknown(.processTerminatedBeforeTerminalResult)
            }
            return try commit(proposal, effect: .none, persist: persist)
        }
    }

    private static func isValid(_ snapshot: SubmissionSnapshot) -> Bool {
        let identifiers = Set(snapshot.assetIDs)
        guard !snapshot.submissionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...200).contains(snapshot.assetCount),
              snapshot.assetCount == snapshot.assetIDs.count,
              identifiers.count == snapshot.assetIDs.count,
              snapshot.knownTotalBytes >= 0,
              (0...snapshot.assetCount).contains(snapshot.unavailableCount),
              snapshot.favoriteAssetIDs.isSubset(of: identifiers) else {
            return false
        }

        switch snapshot.volumeDisplayMode {
        case .exact:
            return snapshot.unavailableCount == 0
        case .lowerBound:
            return snapshot.unavailableCount > 0
        }
    }

    private func validate(_ callback: S4FailureCallback) -> S4RejectionReason? {
        guard callback.submissionID == snapshot.submissionID else {
            return .callbackSubmissionMismatch
        }
        guard callback.reason.isValid else {
            return .emptyFailureReason
        }
        guard callback.successfulAssetIDs.isDisjoint(with: callback.failedAssetIDs),
              callback.successfulAssetIDs.isDisjoint(with: callback.unprocessedAssetIDs),
              callback.failedAssetIDs.isDisjoint(with: callback.unprocessedAssetIDs) else {
            return .resultSetsOverlap
        }

        let submitted = Set(snapshot.assetIDs)
        let classified = callback.successfulAssetIDs
            .union(callback.failedAssetIDs)
            .union(callback.unprocessedAssetIDs)
        guard classified.isSubset(of: submitted) else {
            return .resultSetContainsForeignAsset
        }
        guard classified == submitted else {
            return .resultSetOmitsAsset
        }
        return nil
    }

    private mutating func commit(
        _ proposal: S4PersistentState,
        effect: S4TransitionEffect,
        persist: (S4PersistentState) throws -> Void
    ) throws -> S4Transition {
        let previous = state
        try persist(proposal)
        persistentState = proposal
        return S4Transition(
            fromState: previous,
            toState: proposal.state,
            effect: effect,
            rejection: nil
        )
    }

    private func rejected(_ reason: S4RejectionReason) -> S4Transition {
        S4Transition(
            fromState: state,
            toState: state,
            effect: .none,
            rejection: reason
        )
    }

    private func makeHandoff(for state: S4State) -> S4Handoff {
        switch state {
        case let .allSucceeded(result):
            return .success(snapshot: snapshot, result: result)
        case let .batchFailed(callback):
            return .failure(snapshot: snapshot, callback: callback)
        case let .resultUnknown(reason):
            return .unknown(snapshot: snapshot, reason: reason)
        case .submitted, .resumedInteraction:
            preconditionFailure("非终态不能交接")
        }
    }
}
