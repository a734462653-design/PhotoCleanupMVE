import SwiftUI

// MARK: - 展示口径（IC-133；IC-134 重写视图时保留这些类型与断言）

/// IC-133 A（SPEC-S1 v8 决策 31）：S3 分组的展示口径。
///
/// 输入协调器的 `s3Groups` 快照与状态机当前仍在 `D` 中的资产，输出**只含仍有
/// 资产的组**的有序列表；顺序保持 `s3Groups` 原序（不重排、不按名字排），每组
/// 带过滤后的有序资产与计数。某组最后一张被移除即从列表消失，其余组位置不变；
/// 全部为空时输出空列表（此时状态机已是 `S3-4`，视图走空态分支）。
/// `s3Groups` 本身不改，过滤在展示层每次重算。
struct S3GroupPresentation: Equatable {
    struct Group: Equatable {
        let sourceRangeID: SessionStore.RangeID
        let name: String
        let orderedAssets: [AssetDescriptor]

        var assetCount: Int {
            orderedAssets.count
        }
    }

    let groups: [Group]

    /// 非空组数——信息条副行的「来自 M 个范围」取此值，不取 `s3Groups.count`。
    var nonEmptyRangeCount: Int {
        groups.count
    }

    /// 各组输出计数之和；应恒等于状态机 `assetCount`（v8 第六节第 5 部分分组等式）。
    var assetCount: Int {
        groups.reduce(0) { $0 + $1.assetCount }
    }

    static func make(
        groups: [SessionStore.S3Submission.Group],
        currentAssets: [AssetDescriptor]
    ) -> S3GroupPresentation {
        let descriptorByID = Dictionary(
            currentAssets.map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let nonEmptyGroups = groups.compactMap { group -> Group? in
            let orderedAssets = group.orderedAssetIDs.compactMap { descriptorByID[$0] }
            guard !orderedAssets.isEmpty else {
                return nil
            }
            return Group(
                sourceRangeID: group.sourceRangeID,
                name: group.name,
                orderedAssets: orderedAssets
            )
        }
        return S3GroupPresentation(groups: nonEmptyGroups)
    }
}

// MARK: - S3View

struct S3View: View {
    @ObservedObject var coordinator: CleanupCoordinator

    var body: some View {
        NavigationStack {
            if let machine = coordinator.s3Machine {
                let presentation = S3GroupPresentation.make(
                    groups: coordinator.s3Groups,
                    currentAssets: machine.assets
                )
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
                        presentation.groups,
                        id: \.sourceRangeID
                    ) { group in
                        Section(groupTitle(group)) {
                            ForEach(group.orderedAssets, id: \.identifier) { asset in
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

    private func groupTitle(_ group: S3GroupPresentation.Group) -> String {
        L10n.text(
            "s3.group.asset_count",
            replacing: [
                "name": group.name,
                "count": String(group.assetCount)
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
