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
            .navigationTitle("执行删除")
        }
    }

    @ViewBuilder
    private func content(_ machine: S4StateMachine) -> some View {
        switch machine.state {
        case .submitted:
            Section("删除请求已提交") {
                ProgressView()
                Text("本次提交 \(machine.snapshot.assetCount) 张")
                Text("正在等待系统返回结果")
            }
        case .resumedInteraction:
            Section("正在确认删除结果") {
                ProgressView()
                Text("本次提交 \(machine.snapshot.assetCount) 张")
                Text("等待系统返回结果")
            }
        case let .allSucceeded(result):
            Section("全批成功") {
                Text("提交 \(machine.snapshot.assetCount) 张")
                Text("成功 \(result.successfulAssetIDs.count) 张")
            }
        case let .batchFailed(callback):
            Section("整批失败") {
                Text("成功 \(callback.successfulAssetIDs.count) 张")
                Text("失败 \(callback.failedAssetIDs.count) 张")
                Text("未处理 \(callback.unprocessedAssetIDs.count) 张")
                Text(callback.reason.message)
            }
        case let .resultUnknown(reason):
            Section("结果未知") {
                Text("本次提交 \(machine.snapshot.assetCount) 张")
                Text(unknownReasonText(reason))
            }
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
