import SwiftUI

struct S4View: View {
    @ObservedObject var coordinator: CleanupCoordinator

    var body: some View {
        NavigationStack {
            List {
                if let message = coordinator.message {
                    Section {
                        Text(message)
                    }
                }
                if let machine = coordinator.s4Machine {
                    content(machine)
                }
            }
            .navigationTitle(L10n.text("s4.navigation.title"))
        }
    }

    @ViewBuilder
    private func content(_ machine: S4StateMachine) -> some View {
        switch machine.state {
        case .submitted:
            Section(L10n.text("s4.section.submitted")) {
                ProgressView()
                Text(submissionCountText(machine.snapshot.assetCount))
                Text(L10n.text("s4.status.waiting_for_system_result_active"))
            }
        case .resumedInteraction:
            Section(L10n.text("s4.section.confirming_result")) {
                ProgressView()
                Text(submissionCountText(machine.snapshot.assetCount))
                Text(L10n.text("s4.status.waiting_for_system_result"))
            }
        case let .allSucceeded(result):
            Section(L10n.text("s4.section.all_succeeded")) {
                Text(L10n.text(
                    "s4.summary.submitted_count",
                    replacing: ["count": String(machine.snapshot.assetCount)]
                ))
                Text(successCountText(result.successfulAssetIDs.count))
            }
        case let .batchFailed(callback):
            Section(L10n.text("s4.section.batch_failed")) {
                Text(successCountText(callback.successfulAssetIDs.count))
                Text(L10n.text(
                    "s4.summary.failure_count",
                    replacing: ["count": String(callback.failedAssetIDs.count)]
                ))
                Text(L10n.text(
                    "s4.summary.unprocessed_count",
                    replacing: ["count": String(callback.unprocessedAssetIDs.count)]
                ))
                Text(callback.reason.message)
            }
        case let .resultUnknown(reason):
            Section(L10n.text("s4.section.result_unknown")) {
                Text(submissionCountText(machine.snapshot.assetCount))
                Text(unknownReasonText(reason))
            }
        }
    }

    private func submissionCountText(_ count: Int) -> String {
        L10n.text(
            "submission.asset_count",
            replacing: ["count": String(count)]
        )
    }

    private func successCountText(_ count: Int) -> String {
        L10n.text(
            "s4.summary.success_count",
            replacing: ["count": String(count)]
        )
    }

    private func unknownReasonText(_ reason: S4UnknownReason) -> String {
        switch reason {
        case .activeWaitTimedOut:
            return L10n.text("submission.unknown_reason.callback_timeout")
        case .processTerminatedBeforeTerminalResult:
            return L10n.text("submission.unknown_reason.process_terminated")
        }
    }
}
