import SwiftUI

struct S3View: View {
    @ObservedObject var coordinator: CleanupCoordinator

    var body: some View {
        NavigationStack {
            if let machine = coordinator.s3Machine {
                List {
                    if let message = coordinator.message {
                        Section {
                            Text(message)
                        }
                    }

                    Section(L10n.text("s3.section.status")) {
                        Text(stateTitle(machine.state))
                        Text(L10n.text(
                            "s3.asset.pending_count",
                            replacing: ["count": String(machine.assetCount)]
                        ))
                        Text(L10n.text(
                            "s3.scope.source_summary.placeholder",
                            replacing: [
                                "count": String(coordinator.s3Groups.count)
                            ]
                        ))
                        Text(volumeText(machine))
                        if machine.state == .ready {
                            Text(L10n.text("s3.confirmation.recently_deleted_notice"))
                        }
                        if machine.state == .scanning {
                            ProgressView()
                        }
                    }

                    ForEach(
                        coordinator.s3Groups,
                        id: \.sourceRangeID
                    ) { group in
                        let assets = currentAssets(in: group, machine: machine)
                        Section(groupTitle(group, assetCount: assets.count)) {
                            ForEach(assets, id: \.identifier) { asset in
                                assetRow(asset, machine: machine)
                            }
                        }
                    }

                    Section(L10n.text("s3.section.actions")) {
                        Button(L10n.text("s3.action.cancel_all"), role: .destructive) {
                            coordinator.cancelAllAssets()
                        }
                        .disabled(machine.assetCount == 0 || machine.frozenSnapshot != nil)

                        Button(L10n.text("s3.action.submit_deletion"), role: .destructive) {
                            coordinator.submitDeletion()
                        }
                        .disabled(!machine.canSubmit)

                        Button(L10n.text("s3.action.back")) {
                            coordinator.leaveConfirmation()
                        }
                    }
                }
                .navigationTitle(L10n.text("s3.navigation.title"))
            } else {
                ProgressView()
            }
        }
    }

    private func currentAssets(
        in group: SessionStore.S3Submission.Group,
        machine: S3StateMachine
    ) -> [AssetDescriptor] {
        let descriptorByID = Dictionary(
            uniqueKeysWithValues: machine.assets.map {
                ($0.identifier, $0)
            }
        )
        return group.orderedAssetIDs.compactMap { descriptorByID[$0] }
    }

    private func groupTitle(
        _ group: SessionStore.S3Submission.Group,
        assetCount: Int
    ) -> String {
        L10n.text(
            "s3.group.asset_count",
            replacing: [
                "name": group.name,
                "count": String(assetCount)
            ]
        )
    }

    private func assetRow(
        _ asset: AssetDescriptor,
        machine: S3StateMachine
    ) -> some View {
        HStack {
            ThumbnailView(assetIdentifier: asset.identifier)
            VStack(alignment: .leading) {
                Text(asset.identifier)
                    .lineLimit(2)
                if asset.isFavorite {
                    Label(
                        L10n.text("s3.asset.favorite"),
                        systemImage: "heart.fill"
                    )
                }
            }
            Spacer()
            Button(L10n.text("s3.action.remove")) {
                coordinator.removeAsset(asset.identifier)
            }
            .disabled(machine.frozenSnapshot != nil)
        }
    }

    private func stateTitle(_ state: S3State) -> String {
        switch state {
        case .scanning:
            return L10n.text("s3.state.scanning")
        case .ready:
            return L10n.text("s3.state.ready")
        case .empty:
            return L10n.text("s3.state.empty")
        }
    }

    private func volumeText(_ machine: S3StateMachine) -> String {
        let known = DecimalVolumeFormatter.string(forByteCount: machine.knownTotalBytes)
        switch machine.state {
        case .scanning:
            return L10n.text(
                "s3.volume.scanning",
                replacing: [
                    "known": known,
                    "count": String(machine.unavailableCount)
                ]
            )
        case .ready where machine.unavailableCount == 0:
            return L10n.text(
                "s3.volume.exact",
                replacing: ["known": known]
            )
        case .ready:
            return L10n.text(
                "s3.volume.lower_bound",
                replacing: [
                    "known": known,
                    "count": String(machine.unavailableCount)
                ]
            )
        case .empty:
            return L10n.text("s3.volume.empty")
        }
    }
}
