import SwiftUI

struct S5View: View {
    @ObservedObject var coordinator: CleanupCoordinator

    private let boundaryText = L10n.text("s5.recently_deleted.boundary_notice")

    var body: some View {
        NavigationStack {
            List {
                if let message = coordinator.message {
                    Section {
                        Text(message)
                    }
                }
                if let machine = coordinator.s5Machine {
                    content(machine)
                }
            }
            .navigationTitle(L10n.text("s5.navigation.title"))
        }
    }

    @ViewBuilder
    private func content(_ machine: S5StateMachine) -> some View {
        switch machine.state {
        case let .movedToRecentlyDeleted(context):
            Section(L10n.text("s5.section.moved_to_recently_deleted")) {
                Text(L10n.text(
                    "s5.summary.success_result",
                    replacing: [
                        "success": String(context.successfulAssetIDs.count)
                    ]
                ))
                Text(volumeText(context.snapshot))
                Text(boundaryText)
                placeholderImage
                if machine.isRecentlyDeletedConfirmationEnabled {
                    Text(L10n.text("s5.status.device_space_waiting"))
                    Button(L10n.text("s5.action.confirm_recently_deleted_cleared")) {
                        coordinator.confirmRecentlyDeletedCleared()
                    }
                }
                Button(L10n.text("s5.action.leave")) {
                    coordinator.leaveCompletion()
                }
            }

        case let .cancelled(context):
            Section(L10n.text("s5.section.deletion_cancelled")) {
                Text(L10n.text("s5.status.assets_intact"))
                Text(L10n.text(
                    "s5.summary.cancelled_result",
                    replacing: ["count": String(context.snapshot.assetCount)]
                ))
                Text(volumeText(context.snapshot))
                Text(L10n.text("s5.volume.original_submission_disclaimer"))
                Button(L10n.text("s5.action.return_to_confirmation")) {
                    coordinator.returnToConfirmation()
                }
            }

        case let .failed(context):
            Section(L10n.text("s5.section.deletion_incomplete")) {
                Text(L10n.text(
                    "s5.summary.failure_result",
                    replacing: [
                        "success": String(context.callback.successfulAssetIDs.count),
                        "failure": String(context.callback.failedAssetIDs.count),
                        "unprocessed": String(context.callback.unprocessedAssetIDs.count)
                    ]
                ))
                Text(context.callback.reason.message)
                Text(volumeText(context.snapshot))
                Text(L10n.text("s5.volume.original_submission_disclaimer"))
                Text(L10n.text("s5.failure.retry_notice"))
                Button(L10n.text("s5.action.return_to_confirmation")) {
                    coordinator.returnToConfirmation()
                }
            }

        case let .unknown(context):
            Section(L10n.text("s5.section.deletion_result_unknown")) {
                Text(L10n.text(
                    "submission.asset_count",
                    replacing: ["count": String(context.snapshot.assetCount)]
                ))
                Text(L10n.text("s5.status.result_unknown"))
                Text(unknownReasonText(context.reason))
                Text(volumeText(context.snapshot))
                Text(L10n.text("s5.volume.original_submission_disclaimer"))
                Text(L10n.text("s5.unknown.manual_verification_notice"))
                Text(boundaryText)
                placeholderImage
                Button(L10n.text("s5.action.finish")) {
                    coordinator.leaveCompletion()
                }
            }
        }
    }

    private var placeholderImage: some View {
        VStack(alignment: .leading) {
            Image("RECENTLY_DELETED_PLACEHOLDER")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
            Text(L10n.text("s5.placeholder.disclaimer"))
        }
    }

    private func volumeText(_ snapshot: SubmissionSnapshot) -> String {
        let value = DecimalVolumeFormatter.string(
            forByteCount: snapshot.knownTotalBytes
        )
        switch snapshot.volumeDisplayMode {
        case .exact:
            return L10n.text(
                "s5.volume.exact",
                replacing: ["value": value]
            )
        case .lowerBound:
            return L10n.text(
                "s5.volume.lower_bound",
                replacing: [
                    "value": value,
                    "count": String(snapshot.unavailableCount)
                ]
            )
        }
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
