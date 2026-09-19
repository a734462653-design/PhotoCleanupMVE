import Foundation
import SwiftUI

@main
struct PhotoCleanupMVEApp: App {
    @StateObject private var coordinator = CleanupCoordinator()
    /// IC-147 A：S0 首页的状态机与 tab 选择态。与 `coordinator` 同层持有，
    /// 切 tab 不经过协调器，因而不可能碰到会话层数据。
    @StateObject private var s0Machine = S0StateMachine()
    @StateObject private var s0TabSelection = S0TabSelectionModel()
    /// IC-157 C：类别页身份（裁定 一）。与 tab 选择态同层持有：进出 S2 时 tab 容器整棵重建而它不动，
    /// 回来时承载容器直接推出类别页。
    @StateObject private var s0FlowModel = S0CleanupFlowModel()
    @Environment(\.scenePhase) private var scenePhase
    private let s2PhotoImageStrategy = S2TemporaryPhotoKitImageStrategy()
    /// IC-153 C：S0 数据源换成真实扫描服务（批次 5.1），替换 IC-147 的桩。
    /// 构造无副作用：不发 PhotoKit 请求、不读缓存文件，第一次推进扫描才开始。
    private let s0DataProvider = S0LibraryScanService()
    /// IC-161 A：相似照片探针的取数实现（探针，不参与任何产品路径）。构造无副作用：
    /// 只建一条私有并发队列，不发 PhotoKit 请求、不碰 Vision，面板按钮触发才取数。
    private let similarPhotosProber = SimilarPhotosFeatureProbeService()
    /// IC-161 C：画质评分探针的取数实现（iOS 18+ 才有结果）。构造同样无副作用。
    private let aestheticsProber = AestheticsScoreProbeService()

    /// IC-131 B：S1 视图构造抽成 builder。加参数后仍留在 Scene body 的多层
    /// 嵌套里会把类型检查推到超时（IC-108／IC-113 三次实例），构造点一律外提。
    private func s1Screen(machine: S1StateMachine) -> some View {
        S1View(
            machine: machine,
            rangeReader: coordinator.readS1Ranges,
            onS2Handoff: { handoff in
                _ = coordinator.enterS2(from: handoff)
            },
            onS3Submission: { submission in
                _ = coordinator.enterConfirmationFromS1(submission)
            },
            feedbackEvent: coordinator.s1FeedbackEvent,
            feedbackToastDurationMilliseconds: coordinator
                .s2Calibration
                .configuration
                .feedbackToastDurationMilliseconds,
            onFeedbackEventConsumed: {
                coordinator.consumeS1FeedbackEvent()
            }
        )
    }

    /// IC-147 A：两 tab 容器的构造 builder（陷阱 16：构造点一律外提）。
    ///
    /// 「空间清理」= S0 骨架，「逐张整理」= S1 原样嵌入——**本卡不改 S1 一行**。
    /// 待删篮张数经会话层实时取数：两个 tab 的胶囊显示同一个 `D_全部` 元素数
    /// （SPEC-S1 v9 第二节）。闭包捕获的是状态机本身，不捕获协调器。
    private func tabContainer(s1Machine: S1StateMachine) -> some View {
        S0TabContainer(
            selection: s0TabSelection,
            cleanupContent: {
                s0Screen(s1Machine: s1Machine)
            },
            organizeContent: {
                s1Screen(machine: s1Machine)
            }
        )
        .onAppear {
            s0Machine.mergedPendingDeletionCountProvider = {
                s1Machine.badgeCount
            }
            // IC-153 C：待删篮体积与类别排除都按同一个 `D_全部` 取数（裁定 五）。
            s0DataProvider.pendingDeletionAssetIDs = {
                s1Machine.sessionStore.allPendingDeletionAssetIDs
            }
            // 快照每变一次（主线程、已节流）先摄入，再只在 `SC` 确实要变时发迁移。
            let machine = s0Machine
            let provider = s0DataProvider
            provider.onSnapshotDidChange = { [weak machine, weak provider] in
                guard let machine, let provider else {
                    return
                }
                machine.ingest(provider.currentSnapshot())
                for event in S0ScanOutcomeTransition.events(
                    for: provider.currentScanOutcome(),
                    scanState: machine.scanState,
                    failureCategory: machine.failureCategory
                ) {
                    machine.handle(event)
                }
            }
        }
    }

    /// IC-147 C：S0 骨架视图的构造 builder（陷阱 16）。
    ///
    /// 「去逐张整理」直接切 tab；类别页与 S3 的实际导航不在本卡——类别页属
    /// IC-148 之后，S3 的提交路径按 SPEC-S0 v1 第十节第 3 部分与 SPEC-S1 v9
    /// 第七节第 3 部分完全相同，S0 不另造一份，故此处不接线。
    ///
    /// IC-156 D：构造点换成承载容器 `S0CleanupFlowView`（裁定 二），首页原样构造在容器里、
    /// 类别页由容器推出；「移入待删篮」经 S1 状态机一次原子写入虚拟范围并登记类别名
    /// （裁定 三），toast 时长与 S1 同一读法。首页待删篮胶囊 → S3 仍不接线（批次 5.3）。
    ///
    /// IC-157 C：长按进 S2 经 S1 状态机的虚拟范围交接构造（裁定 二）交给协调器唯一的 S2 入口；
    /// 协调器一字不动（裁定 四），类别页身份由 `s0FlowModel` 跨路由保持（裁定 一）。
    private func s0Screen(s1Machine: S1StateMachine) -> some View {
        S0CleanupFlowView(
            machine: s0Machine,
            dataProvider: s0DataProvider,
            flowModel: s0FlowModel,
            onSwitchToOrganizeTab: {
                s0TabSelection.select(.organize)
            },
            onMoveToBasket: { assetIDs, identifier in
                s1Machine.markPendingDeletion(
                    assetIDs: assetIDs,
                    virtualRangeID: S0CategoryPageRange.prefix + identifier.rawValue,
                    displayName: S0CategoryText.displayName(for: identifier)
                )
            },
            onEnterS2: { identifier, orderedAssetIDs, currentAssetID in
                let virtualRangeID = S0CategoryPageRange.prefix + identifier.rawValue
                guard let handoff = s1Machine.makeS2Handoff(virtualRangeID: virtualRangeID,
                                                            displayName: S0CategoryText.displayName(for: identifier),
                                                            orderedAssetIDs: orderedAssetIDs,
                                                            currentAssetID: currentAssetID) else {
                    return false
                }
                return coordinator.enterS2(from: handoff)
            },
            toastDurationMilliseconds: coordinator
                .s2Calibration
                .configuration
                .feedbackToastDurationMilliseconds
        )
    }

    /// IC-139：S2 视图构造抽成 builder（陷阱 16）。
    ///
    /// 本卡给 `S2View` 加了 `assetMediaKind` 实参。这段构造原先内联在
    /// Scene body 的多层嵌套里共 113 行，再加参数会把类型检查推到超时
    /// （IC-108 #192、IC-113 #214／#215 三次实例）。实参顺序与逐成员
    /// 声明顺序一致。
    private func s2Screen(machine: S2StateMachine) -> some View {
        S2View(
            machine: machine,
            calibration: coordinator.s2Calibration,
            assetAspectRatio: coordinator.s2AssetAspectRatio,
            assetIsScreenshot:
                coordinator.s2AssetIsScreenshot,
            assetMediaKind: coordinator.s2AssetMediaKind,
            assetPixelSize: coordinator.s2AssetPixelSize,
            assetCreationDate:
                coordinator.s2AssetCreationDate,
            assetVolumeProvider:
                coordinator.makeS2AssetVolumeProvider(),
            assetSizeProber:
                coordinator.makeS2AssetSizeProber(),
            similarPhotosProber: similarPhotosProber,
            aestheticsProber: aestheticsProber,
            photoContent: { context in
                AnyView(
                    S2TemporaryPhotoImageView(
                        strategy: s2PhotoImageStrategy,
                        assetID: context.assetID,
                        requestBaseSize:
                            context.requestBaseSize,
                        requestedScale: context.scale,
                        requestStrategy:
                            context.requestStrategy,
                        requestRevision:
                            context.requestRevision,
                        contentMode: context.contentMode,
                        showsOpaqueLoadingBackground: true,
                        onReading:
                            context.onRequestReading,
                        onLoadStateChange:
                            context.onLoadStateChange,
                        onRequestResult:
                            context.onRequestResult,
                        onImageReplaced:
                            context.onImageReplaced,
                        onImageReplacementSuppressed:
                            context
                            .onImageReplacementSuppressed,
                        onImageRequestStarted:
                            context.onImageRequestStarted,
                        onImageRequestRawResult:
                            context.onImageRequestRawResult
                    )
                )
            },
            stripItemContent: { item in
                AnyView(
                    S2TemporaryPhotoImageView(
                        strategy: s2PhotoImageStrategy,
                        assetID: item.assetID,
                        requestedScale: 1,
                        requestStrategy: nil,
                        requestRevision: 0,
                        showsOpaqueLoadingBackground: false,
                        onReading: { _ in }
                    )
                )
            },
            albumPickerContent: { _, actions in
                AnyView(
                    S2AlbumPickerListView(
                        items: coordinator.s2UserAlbumItems(),
                        actions: actions,
                        thumbnail: { assetID in
                            AnyView(
                                S2TemporaryPhotoImageView(
                                    strategy:
                                        s2PhotoImageStrategy,
                                    assetID: assetID,
                                    requestedScale: 1,
                                    requestStrategy: nil,
                                    requestRevision: 0,
                                    showsOpaqueLoadingBackground:
                                        false,
                                    onReading: { _ in }
                                )
                            )
                        }
                    )
                )
            },
            onBack: { payload in
                _ = coordinator.leaveS2(with: payload)
            },
            onConfirmation: { payload in
                _ = coordinator.enterConfirmationFromS2(
                    with: payload
                )
            },
            onFavoriteRequest: { request in
                _ = coordinator.requestS2FavoriteToggle(request)
            },
            onRecentAlbumRequest: { request in
                _ = coordinator.requestS2RecentAlbumAddition(
                    request
                )
            },
            onAlbumRemovalRequest: { request in
                _ = coordinator.requestS2AlbumRemoval(request)
            },
            onAlbumCreationRequest: { name, completion in
                coordinator.requestS2AlbumCreation(
                    named: name,
                    completion: completion
                )
            },
            onAlbumPickerSelection: { request, album in
                _ = coordinator.requestS2AlbumPickerSelection(
                    request,
                    album: album
                )
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch coordinator.route {
                case .loading:
                    ProgressView(L10n.text("app.loading.photo_library"))
                case .s1, .upstream, .finished:
                    if let machine = coordinator.s1Machine {
                        tabContainer(s1Machine: machine)
                    } else {
                        ProgressView()
                    }
                case .s2:
                    if let machine = coordinator.s2Machine {
                        s2Screen(machine: machine)
                    } else {
                        ProgressView()
                    }
                case .confirmation:
                    S3View(coordinator: coordinator)
                case .execution:
                    S4View(coordinator: coordinator)
                case .completion:
                    S5View(coordinator: coordinator)
                }
            }
            .onAppear {
                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                    coordinator.start()
                }
                // IC-153 C：同一道 E4 闸下启动扫描。另起一个 if 而不并进上一个：
                // 上一个 if 的整段文本由 IC-147 断言 3 逐字钉住。
                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                    s0DataProvider.advanceScan()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    coordinator.setApplicationActive(true)
                    restoreS0Foreground()
                case .inactive, .background:
                    coordinator.setApplicationActive(false)
                @unknown default:
                    coordinator.setApplicationActive(false)
                }
            }
        }
    }

    /// IC-147 A（E3）：前台恢复。按增量缓存续扫——数据源回报仍在扫描即视为
    /// 有新增资产，`SC` 回到扫描中（SPEC-S0 v1 第四节「任一 / 前台恢复且有
    /// 新增资产 / S0-1」）；否则留在原态并一次性重排类别行。
    /// 遵循 E4 口径：测试宿主下不自动启动任何活动。
    private func restoreS0Foreground() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        s0DataProvider.advanceScan()
        s0Machine.ingest(s0DataProvider.currentSnapshot())
        s0Machine.handle(
            .foregroundRestored(
                hasNewAssets: s0DataProvider.currentScanOutcome() == .scanning
            )
        )
    }
}
