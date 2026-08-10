import SwiftUI

struct S5View: View {
    @ObservedObject var coordinator: CleanupCoordinator

    private let boundaryText = "照片已移入系统「最近删除」，仍由系统保留。App 无法读取或清空该位置。请打开系统「照片」，进入「实用工具」中的「最近删除」，由你完成清空，然后返回本页。"

    var body: some View {
        NavigationStack {
            List {
                if let message = coordinator.message {
                    Section {
                        Text(message)
                    }
                }
                if let machine = coordinator.s5Machine {
                    content(machine.state)
                }
            }
            .navigationTitle("清理结果")
        }
    }

    @ViewBuilder
    private func content(_ state: S5State) -> some View {
        switch state {
        case let .movedToRecentlyDeleted(context):
            Section("已移入最近删除") {
                Text("处理结果：成功 \(context.successfulAssetIDs.count) 张，失败 0 张，未处理 0 张")
                Text(volumeText(context.snapshot))
                Text(boundaryText)
                placeholderImage
                Text("设备可用空间仍在等待你的系统操作")
                Button("我已清空最近删除") {}
                    .disabled(true)
                Button("离开") {
                    coordinator.leaveCompletion()
                }
            }

        case let .failed(context):
            Section("本次删除未完成") {
                Text("处理结果：成功 \(context.callback.successfulAssetIDs.count) 张，失败 \(context.callback.failedAssetIDs.count) 张，未处理 \(context.callback.unprocessedAssetIDs.count) 张")
                Text(context.callback.reason.message)
                Text(volumeText(context.snapshot))
                Text("该数值只描述原提交集合的体积，不代表处理结果或设备可用空间变化")
                Text("已保留原提交集合，可返回确认页再次尝试")
                Button("返回确认页") {
                    coordinator.returnFromFailureToConfirmation()
                }
            }

        case let .unknown(context):
            Section("本次删除结果未知") {
                Text("本次提交 \(context.snapshot.assetCount) 张")
                Text("处理结果未知")
                Text(unknownReasonText(context.reason))
                Text(volumeText(context.snapshot))
                Text("该数值只描述原提交集合的体积，不代表处理结果或设备可用空间变化")
                Text("请人工核对照片原位置与系统「最近删除」")
                Text(boundaryText)
                placeholderImage
                Button("完成") {
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
            Text("系统标注截图占位图，不属于正式交付素材")
        }
    }

    private func volumeText(_ snapshot: SubmissionSnapshot) -> String {
        let value = DecimalVolumeFormatter.string(
            forByteCount: snapshot.knownTotalBytes
        )
        switch snapshot.volumeDisplayMode {
        case .exact:
            return "本次清理的照片共 \(value)"
        case .lowerBound:
            return "本次清理的照片共至少 \(value)；另有 \(snapshot.unavailableCount) 项体积不可用"
        }
    }

    private func unknownReasonText(_ reason: S4UnknownReason) -> String {
        switch reason {
        case .activeWaitTimedOut:
            return "等待系统回调超时"
        case .processTerminatedBeforeTerminalResult:
            return "应用在取得终态前被系统终止"
        }
    }
}
