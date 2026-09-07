import Foundation

struct S5SuccessContext: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    let successfulAssetIDs: Set<String>
}

struct S5CancellationContext: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    let callback: S4FailureCallback
}

struct S5FailureContext: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    let callback: S4FailureCallback
}

struct S5UnknownContext: Equatable, Sendable {
    let snapshot: SubmissionSnapshot
    let reason: S4UnknownReason
}

/// IC-134 F：L3「设备可用空间变化」整层撤销（④ Lynn 2026-09-06）后，
/// 本结构只剩「是否展示系统错误详情」一项。
struct S5PresentationCapabilities: Equatable, Sendable {
    let showsSystemErrorDetails: Bool
}

enum S5State: Equatable, Sendable {
    case movedToRecentlyDeleted(S5SuccessContext)
    case cancelled(S5CancellationContext)
    case failed(S5FailureContext)
    case unknown(S5UnknownContext)

    var snapshot: SubmissionSnapshot {
        switch self {
        case let .movedToRecentlyDeleted(context):
            return context.snapshot
        case let .cancelled(context):
            return context.snapshot
        case let .failed(context):
            return context.snapshot
        case let .unknown(context):
            return context.snapshot
        }
    }

    var downstreamTargetState: S4DownstreamTargetState {
        switch self {
        case .movedToRecentlyDeleted:
            return .movedToRecentlyDeleted
        case .cancelled:
            return .cancelled
        case .failed:
            return .failed
        case .unknown:
            return .unknown
        }
    }

    var presentationCapabilities: S5PresentationCapabilities {
        switch self {
        case .movedToRecentlyDeleted, .cancelled, .unknown:
            return S5PresentationCapabilities(showsSystemErrorDetails: false)
        case .failed:
            return S5PresentationCapabilities(showsSystemErrorDetails: true)
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
    case handoffPayloadDoesNotMatchTarget
    case invalidSuccessHandoff
    case invalidCancellationHandoff
    case invalidFailureHandoff
    case invalidPersistentState
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

    static func restore(
        persistentState: S5PersistentState,
        persist: (S5PersistentState) throws -> Void
    ) throws -> S5StateMachine {
        guard isValid(persistentState) else {
            throw S5StateMachineError.invalidPersistentState
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

        // S5 只读 S4 已写入的交接字段，绝不根据失败详情重新分流。
        switch handoff.downstreamTargetState {
        case .movedToRecentlyDeleted:
            guard case let .success(snapshot, result, _) = handoff else {
                throw S5StateMachineError.handoffPayloadDoesNotMatchTarget
            }
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

        case .cancelled:
            guard case let .failure(snapshot, callback, _) = handoff else {
                throw S5StateMachineError.handoffPayloadDoesNotMatchTarget
            }
            let submitted = Set(snapshot.assetIDs)
            guard isValid(callback, for: snapshot),
                  callback.successfulAssetIDs.isEmpty,
                  callback.failedAssetIDs.isEmpty,
                  callback.unprocessedAssetIDs == submitted else {
                throw S5StateMachineError.invalidCancellationHandoff
            }
            state = .cancelled(
                S5CancellationContext(snapshot: snapshot, callback: callback)
            )
            identifiersToInvalidate = nil

        case .failed:
            guard case let .failure(snapshot, callback, _) = handoff else {
                throw S5StateMachineError.handoffPayloadDoesNotMatchTarget
            }
            guard isValid(callback, for: snapshot) else {
                throw S5StateMachineError.invalidFailureHandoff
            }
            state = .failed(
                S5FailureContext(snapshot: snapshot, callback: callback)
            )
            identifiersToInvalidate = nil

        case .unknown:
            guard case let .unknown(snapshot, reason, _) = handoff else {
                throw S5StateMachineError.handoffPayloadDoesNotMatchTarget
            }
            state = .unknown(
                S5UnknownContext(snapshot: snapshot, reason: reason)
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
            let snapshot: SubmissionSnapshot
            switch state {
            case let .cancelled(context):
                snapshot = context.snapshot
            case let .failed(context):
                snapshot = context.snapshot
            case .movedToRecentlyDeleted, .unknown:
                return rejected(.actionUnavailableInCurrentState)
            }
            let target: S5ReturnTarget = cacheExists ? .ready : .scanning
            return applied(
                effect: .returnToConfirmation(
                    target: target,
                    assetIDs: snapshot.assetIDs
                )
            )

        case .leavePage:
            switch state {
            case .movedToRecentlyDeleted, .unknown:
                return applied(effect: .exitCleanup)
            case .cancelled, .failed:
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

    private static func isValid(_ persistentState: S5PersistentState) -> Bool {
        switch persistentState.state {
        case let .movedToRecentlyDeleted(context):
            guard context.successfulAssetIDs == Set(context.snapshot.assetIDs) else {
                return false
            }
        case let .cancelled(context):
            let submitted = Set(context.snapshot.assetIDs)
            guard isValid(context.callback, for: context.snapshot),
                  context.callback.successfulAssetIDs.isEmpty,
                  context.callback.failedAssetIDs.isEmpty,
                  context.callback.unprocessedAssetIDs == submitted else {
                return false
            }
        case let .failed(context):
            guard isValid(context.callback, for: context.snapshot) else {
                return false
            }
        case .unknown:
            break
        }

        return true
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
