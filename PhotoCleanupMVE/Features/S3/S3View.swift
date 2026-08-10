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

                    Section("状态") {
                        Text(stateTitle(machine.state))
                        Text("待删除 \(machine.assetCount) 张")
                        Text(volumeText(machine))
                        if machine.state == .scanning {
                            ProgressView()
                        }
                    }

                    Section("待删除资产") {
                        ForEach(machine.assets, id: \.identifier) { asset in
                            HStack {
                                ThumbnailView(assetIdentifier: asset.identifier)
                                VStack(alignment: .leading) {
                                    Text(asset.identifier)
                                        .lineLimit(2)
                                    if asset.isFavorite {
                                        Label("已收藏", systemImage: "heart.fill")
                                    }
                                }
                                Spacer()
                                Button("移除") {
                                    coordinator.removeAsset(asset.identifier)
                                }
                                .disabled(machine.frozenSnapshot != nil)
                            }
                        }
                    }

                    Section("操作") {
                        if machine.state == .overLimit {
                            Text("单次最多提交 200 张，请分批处理")
                        }
                        Button("全部取消", role: .destructive) {
                            coordinator.cancelAllAssets()
                        }
                        .disabled(machine.assetCount == 0 || machine.frozenSnapshot != nil)

                        Button("提交删除", role: .destructive) {
                            coordinator.submitDeletion()
                        }
                        .disabled(!machine.canSubmit)

                        Button("返回") {
                            coordinator.leaveConfirmation()
                        }
                    }
                }
                .navigationTitle("确认删除")
            } else {
                ProgressView()
            }
        }
    }

    private func stateTitle(_ state: S3State) -> String {
        switch state {
        case .scanning:
            return "正在计算照片体积"
        case .ready:
            return "可以提交删除"
        case .overLimit:
            return "待删除数量超过上限"
        case .empty:
            return "没有待删除照片"
        }
    }

    private func volumeText(_ machine: S3StateMachine) -> String {
        let known = DecimalVolumeFormatter.string(forByteCount: machine.knownTotalBytes)
        switch machine.state {
        case .scanning:
            return "正在计算；当前已知 \(known)，不可用 \(machine.unavailableCount) 项（未完成）"
        case .ready where machine.unavailableCount == 0:
            return "照片体积 \(known)"
        case .ready:
            return "照片体积至少 \(known)；另有 \(machine.unavailableCount) 项体积不可用"
        case .overLimit:
            return "减至 200 张以内后显示或计算体积"
        case .empty:
            return "没有可计算的照片体积"
        }
    }
}
