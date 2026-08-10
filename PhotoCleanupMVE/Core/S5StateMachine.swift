import Foundation

struct S5SuccessContext: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    let successfulAssetIDs: Set<String>
}

struct S5FailureContext: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    let callback: S4FailureCallback
}

struct S5UnknownContext: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    let reason: S4UnknownReason
}

enum S5State: Equatable, Sendable {
    case movedToRecentlyDeleted(S5SuccessContext)
    case failed(S5FailureContext)
    case unknown(S5UnknownContext)

    var snapshot: SubmissionSnapshot {
        switch self {
        case let .movedToRecentlyDeleted(context):
            return context.snapshot
        case let .failed(context):
            return context.snapshot
        case let .unknown(context):
            return context.snapshot
        }
    }
}

enum S5ReturnTarget: Equatable, Sendable {
    case ready
    case scanning
}

enum S5TransitionEffect: Equatable, Sendable {
    case none
    case exitCleanup
    case returnToConfirmation(target: S5ReturnTarget, assetIDs: [String])
}

enum S5RejectionReason: Equatable, Sendable {
    case actionUnavailableInCurrentState
}

struct S5Transition: Equatable, Sendable {
    let fromState: S5State
    let toState: S5State
    let effect: S5TransitionEffect
    let rejection: S5RejectionReason?

    var isApplied: Bool {
        rejection == nil
    }
}

enum S5Event: Equatable, Sendable {
    case returnToConfirmation(cacheExists: Bool)
    case leavePage
    case applicationBecameInactive
    case applicationBecameActive
    case processTerminated
}

enum S5StateMachineError: Error, Equatable {
    case invalidSuccessHandoff
    case invalidFailureHandoff
}

struct S5PersistentState: Equatable, Sendable {
    var state: S5State
    var isApplicationActive: Bool
}

struct S5StateMachine: Sendable {
    private(set) var persistentState: S5PersistentState

    var state: S5State {
        persistentState.state
    }

    var isApplicationActive: Bool {
        persistentState.isApplicationActive
    }

    // 本轮按钮必须保持禁用，且状态机不提供对应事件。
    var isRecentlyDeletedConfirmationEnabled: Bool {
        false
    }

    static func restore(
        persistentState: S5PersistentState,
        persist: (S5PersistentState) throws -> Void
    ) throws -> S5StateMachine {
        switch persistentState.state {
        case let .movedToRecentlyDeleted(context):
            guard context.successfulAssetIDs == Set(context.snapshot.assetIDs) else {
                throw S5StateMachineError.invalidSuccessHandoff
            }
        case let .failed(context):
            guard isValid(context.callback, for: context.snapshot) else {
                throw S5StateMachineError.invalidFailureHandoff
            }
        case .unknown:
            break
        }
        try persist(persistentState)
        return S5StateMachine(persistentState: persistentState)
    }

    static func enter(
        from handoff: S4Handoff,
        persist: (S5PersistentState) throws -> Void,
        invalidateOldLists: (Set<String>) -> Void
    ) throws -> S5StateMachine {
        let state: S5State
        let identifiersToInvalidate: Set<String>?

        switch handoff {
        case let .success(snapshot, result):
            let submitted = Set(snapshot.assetIDs)
            guard result.submissionID == snapshot.submissionID,
                  result.successfulAssetIDs == submitted else {
                throw S5StateMachineError.invalidSuccessHandoff
            }
            state = .movedToRecentlyDeleted(
                S5SuccessContext(
                    snapshot: snapshot,
                    successfulAssetIDs: submitted
                )
            )
            identifiersToInvalidate = submitted

        case let .failure(snapshot, callback):
            guard isValid(callback, for: snapshot) else {
                throw S5StateMachineError.invalidFailureHandoff
            }
            state = .failed(
                S5FailureContext(
                    snapshot: snapshot,
                    callback: callback
                )
            )
            identifiersToInvalidate = nil

        case let .unknown(snapshot, reason):
            state = .unknown(
                S5UnknownContext(
                    snapshot: snapshot,
                    reason: reason
                )
            )
            identifiersToInvalidate = nil
        }

        let initialState = S5PersistentState(
            state: state,
            isApplicationActive: true
        )
        try persist(initialState)
        if let identifiersToInvalidate {
            invalidateOldLists(identifiersToInvalidate)
        }
        return S5StateMachine(persistentState: initialState)
    }

    mutating func handle(
        _ event: S5Event,
        persist: (S5PersistentState) throws -> Void
    ) throws -> S5Transition {
        switch event {
        case let .returnToConfirmation(cacheExists):
            guard case let .failed(context) = state else {
                return rejected(.actionUnavailableInCurrentState)
            }
            let target: S5ReturnTarget = cacheExists ? .ready : .scanning
            return applied(
                effect: .returnToConfirmation(
                    target: target,
                    assetIDs: context.snapshot.assetIDs
                )
            )

        case .leavePage:
            switch state {
            case .movedToRecentlyDeleted, .unknown:
                return applied(effect: .exitCleanup)
            case .failed:
                return rejected(.actionUnavailableInCurrentState)
            }

        case .applicationBecameInactive:
            var proposal = persistentState
            proposal.isApplicationActive = false
            return try commit(proposal, persist: persist)

        case .applicationBecameActive:
            var proposal = persistentState
            proposal.isApplicationActive = true
            return try commit(proposal, persist: persist)

        case .processTerminated:
            var proposal = persistentState
            proposal.isApplicationActive = false
            return try commit(proposal, persist: persist)
        }
    }

    private static func isValid(
        _ callback: S4FailureCallback,
        for snapshot: SubmissionSnapshot
    ) -> Bool {
        guard callback.submissionID == snapshot.submissionID,
              callback.reason.isValid,
              callback.successfulAssetIDs.isDisjoint(with: callback.failedAssetIDs),
              callback.successfulAssetIDs.isDisjoint(with: callback.unprocessedAssetIDs),
              callback.failedAssetIDs.isDisjoint(with: callback.unprocessedAssetIDs) else {
            return false
        }

        let classified = callback.successfulAssetIDs
            .union(callback.failedAssetIDs)
            .union(callback.unprocessedAssetIDs)
        return classified == Set(snapshot.assetIDs)
    }

    private mutating func commit(
        _ proposal: S5PersistentState,
        persist: (S5PersistentState) throws -> Void
    ) throws -> S5Transition {
        let previous = state
        try persist(proposal)
        persistentState = proposal
        return S5Transition(
            fromState: previous,
            toState: proposal.state,
            effect: .none,
            rejection: nil
        )
    }

    private func applied(effect: S5TransitionEffect) -> S5Transition {
        S5Transition(
            fromState: state,
            toState: state,
            effect: effect,
            rejection: nil
        )
    }

    private func rejected(_ reason: S5RejectionReason) -> S5Transition {
        S5Transition(
            fromState: state,
            toState: state,
            effect: .none,
            rejection: reason
        )
    }
}
