import Foundation
import SwiftUI

@main
struct PhotoCleanupMVEApp: App {
    @StateObject private var coordinator = CleanupCoordinator()
    /// IC-147 A：S0 首页的状态机与 tab 选择态。与 `coordinator` 同层持有，
    /// 切 tab 不经过协调器，因而不可能碰到会话层数据。
    @StateObject private var s0Machine = S0StateMachine()
    @StateObject private var s0TabSelection = S0TabSelectionModel()
    @Environment(\.scenePhase) private var scenePhase
    private let s2PhotoImageStrategy = S2TemporaryPhotoKitImageStrategy()
    /// IC-147 D：S0 数据源。真实扫描服务排批次 5.1（等 H68 真机数据），
    /// 落地后只换这一处实现。桩不发起任何 PhotoKit 请求、不起后台活动。
    private let s0DataProvider: any S0CleanupDataProviding = S0CleanupDataStub(
        scenario: .readyWithItems,
        includesLedgerEntry: true
    )
    /// IC-148 A（裁定 乙）：S0 氛围底的图源——照片库中最近一张。与扫描服务
    /// 无关，因而**不被 H68 阻塞**；取不到即纯色回落，回落由氛围底读数既有
    /// 行为负责，不另造。
    private let s0AmbientImageProvider: any S0AmbientImageProviding =
        S0RecentPhotoAmbientLoader()

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
                s0Screen()
            },
            organizeContent: {
                s1Screen(machine: s1Machine)
            }
        )
        .onAppear {
            s0Machine.mergedPendingDeletionCountProvider = {
                s1Machine.badgeCount
            }
        }
    }

    /// IC-147 C：S0 骨架视图的构造 builder（陷阱 16）。
    ///
    /// 「去逐张整理」直接切 tab；类别页与 S3 的实际导航不在本卡——类别页属
    /// IC-148 之后，S3 的提交路径按 SPEC-S0 v1 第十节第 3 部分与 SPEC-S1 v9
    /// 第七节第 3 部分完全相同，S0 不另造一份，故此处不接线。
    private func s0Screen() -> some View {
        S0View(
            machine: s0Machine,
            dataProvider: s0DataProvider,
            ambientImageProvider: s0AmbientImageProvider,
            onSwitchToOrganizeTab: {
                s0TabSelection.select(.organize)
            }
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
        s0Machine.ingest(s0DataProvider.currentSnapshot())
        s0Machine.handle(
            .foregroundRestored(
                hasNewAssets: s0DataProvider.currentScanOutcome() == .scanning
            )
        )
    }
}
