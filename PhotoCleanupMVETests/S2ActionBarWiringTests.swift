import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

final class S2ActionBarWiringTests: XCTestCase {
    private let physicalSize = CGSize(width: 390, height: 844)

    // IC-076 R3：toast 以视图模型计时状态断言——事件后出现、到时消失；新事件替换旧事件，
    // 旧事件的到期不清除新事件；时长来自 feedbackToastDurationMilliseconds（出厂 2000）。
    func testIC076R3ToastPresenterAppearsThenExpiresWithoutRealClock() {
        var scheduled: [(seconds: TimeInterval, fire: () -> Void)] = []
        let presenter = S2FeedbackToastPresenter { seconds, action in
            scheduled.append((seconds, action))
        }
        let duration = S2CalibrationConfiguration.factoryPlaceholder
            .feedbackToastDurationMilliseconds
        XCTAssertEqual(duration, 2000)
        XCTAssertNil(presenter.activeEvent)

        let first = S2FeedbackEvent(id: 1, kind: .favoriteWriteFailed)
        presenter.present(first, durationMilliseconds: duration)
        XCTAssertEqual(presenter.activeEvent, first)
        XCTAssertEqual(presenter.presentedCount, 1)
        XCTAssertEqual(presenter.lastScheduledDurationSeconds, 2)
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(scheduled[0].seconds, 2)

        scheduled[0].fire()
        XCTAssertNil(presenter.activeEvent)

        let second = S2FeedbackEvent(id: 2, kind: .albumAdditionFailed)
        let third = S2FeedbackEvent(id: 3, kind: .favoriteWriteFailed)
        presenter.present(second, durationMilliseconds: duration)
        presenter.present(third, durationMilliseconds: duration)
        XCTAssertEqual(presenter.activeEvent, third)
        XCTAssertEqual(scheduled.count, 3)
        scheduled[1].fire()
        XCTAssertEqual(presenter.activeEvent, third, "旧事件到期不得清除新事件")
        scheduled[2].fire()
        XCTAssertNil(presenter.activeEvent)
        XCTAssertEqual(presenter.presentedCount, 3)

        XCTAssertTrue(
            S2FeedbackToastPresenter.text(for: .favoriteWriteFailed)
                .hasPrefix("【未定项 21 占位】")
        )
        XCTAssertTrue(
            S2FeedbackToastPresenter.text(for: .albumAdditionFailed)
                .hasPrefix("【未定项 21 占位】")
        )
    }

    // IC-076 R3（夹具驱动）：in-flight 时只有发起写入的按钮禁用；横栏拖动时整条禁用。
    func testIC076R3ActionBarPresentationDisablesOnlyInFlightButton() {
        let album = S2AlbumReference(id: "album-1", name: "相簿一")
        let machine = makeMachine(recentAlbum: album)
        let idle = S2ActionBarPresentation(machine: machine)
        XCTAssertTrue(idle.favoriteEnabled)
        XCTAssertTrue(idle.recentAlbumEnabled)
        XCTAssertTrue(idle.addAlbumEnabled)
        XCTAssertTrue(idle.showsRecentAlbum)

        let favoriteRequest = tryUnwrap(machine.makeFavoriteToggleRequest())
        XCTAssertTrue(machine.beginFavoriteToggle(favoriteRequest))
        let favoriteInFlight = S2ActionBarPresentation(machine: machine)
        XCTAssertFalse(favoriteInFlight.favoriteEnabled)
        XCTAssertTrue(favoriteInFlight.recentAlbumEnabled)
        XCTAssertTrue(favoriteInFlight.addAlbumEnabled)

        let albumRequest = tryUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertTrue(machine.beginRecentAlbumAddition(albumRequest))
        let bothInFlight = S2ActionBarPresentation(machine: machine)
        XCTAssertFalse(bothInFlight.favoriteEnabled)
        XCTAssertFalse(bothInFlight.recentAlbumEnabled)
        XCTAssertTrue(bothInFlight.addAlbumEnabled)

        XCTAssertTrue(machine.completeFavoriteToggle(favoriteRequest, succeeded: true))
        XCTAssertTrue(machine.completeRecentAlbumAddition(
            albumRequest,
            outcome: .success(alreadyContained: true)
        ))
        XCTAssertEqual(S2ActionBarPresentation(machine: machine), idle)

        XCTAssertTrue(machine.beginBottomStripDrag())
        let dragging = S2ActionBarPresentation(machine: machine)
        XCTAssertFalse(dragging.favoriteEnabled)
        XCTAssertFalse(dragging.recentAlbumEnabled)
        XCTAssertFalse(dragging.addAlbumEnabled)
        XCTAssertTrue(machine.endBottomStripDrag())

        let noHistory = S2ActionBarPresentation(machine: makeMachine())
        XCTAssertFalse(noHistory.showsRecentAlbum)
        XCTAssertTrue(noHistory.favoriteEnabled)
    }

    // IC-076 R3（宿主 S2View，夹具驱动，真机未覆盖）：状态机发出反馈事件后，视图消费事件
    // 并交给 toast 呈现器；事件被消费后状态机不再持有它。
    func testIC076R3HostedViewPresentsToastFromFeedbackEvent() {
        let machine = makeMachine()
        let calibration = S2CalibrationModel(
            persistence: S2DiscardingCalibrationPersistence()
        )
        var scheduled: [() -> Void] = []
        let presenter = S2FeedbackToastPresenter { _, action in
            scheduled.append(action)
        }
        let view = S2View(
            machine: machine,
            calibration: calibration,
            assetAspectRatio: { _ in 1 },
            photoContent: { _ in AnyView(Color.clear) },
            stripItemContent: { _ in AnyView(Color.clear) },
            albumPickerContent: { _, _ in AnyView(EmptyView()) },
            feedbackToastPresenter: presenter
        )
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let request = tryUnwrap(machine.makeFavoriteToggleRequest())
        XCTAssertTrue(machine.beginFavoriteToggle(request))
        XCTAssertFalse(machine.completeFavoriteToggle(request, succeeded: false))
        XCTAssertEqual(machine.feedbackEventCount, 1)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        XCTAssertEqual(presenter.activeEvent?.kind, .favoriteWriteFailed)
        XCTAssertEqual(presenter.presentedCount, 1)
        XCTAssertNil(machine.feedbackEvent)
        XCTAssertEqual(presenter.lastScheduledDurationSeconds, 2)
        XCTAssertEqual(scheduled.count, 1)
        scheduled[0]()
        XCTAssertNil(presenter.activeEvent)
    }

    // IC-076 G114（视图快照断言）：相簿列表呈现按系统返回顺序逐项显示相册名；
    // 空列表显示一行占位文案；文案均带未定项 21 占位前缀。
    func testIC076G114AlbumPickerListPresentation() {
        let albums = [
            S2AlbumReference(id: "album-b", name: "相簿乙"),
            S2AlbumReference(id: "album-a", name: "相簿甲")
        ]
        let presentation = S2AlbumPickerListPresentation(albums: albums)
        XCTAssertFalse(presentation.showsEmptyPlaceholder)
        XCTAssertEqual(presentation.rowTitles, ["相簿乙", "相簿甲"])
        XCTAssertTrue(presentation.title.hasPrefix("【未定项 21 占位】"))

        let empty = S2AlbumPickerListPresentation(albums: [])
        XCTAssertTrue(empty.showsEmptyPlaceholder)
        XCTAssertEqual(empty.rowTitles, [])
        XCTAssertTrue(empty.emptyPlaceholder.hasPrefix("【未定项 21 占位】"))

        var selected: [S2AlbumReference] = []
        var cancelled = 0
        let listView = S2AlbumPickerListView(
            items: albums.map {
                S2AlbumListItem(album: $0, assetCount: 0, keyAssetID: nil)
            },
            actions: S2AlbumPickerActions(
                select: { selected.append($0) },
                cancel: { cancelled += 1 },
                create: { _, completion in completion(nil) }
            ),
            thumbnail: { _ in AnyView(EmptyView()) }
        )
        let controller = UIHostingController(rootView: listView)
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        controller.view.layoutIfNeeded()
        XCTAssertTrue(controller.view.bounds.width > 0)
        listView.actions.select(albums[1])
        listView.actions.cancel()
        XCTAssertEqual(selected, [albums[1]])
        XCTAssertEqual(cancelled, 1)
    }

    // IC-076 G115：加入相册前的同步判定只有一处定义；已包含时不写入（假服务写入计数 0）、
    // 结果为 success(alreadyContained: true)；相册不存在 → albumUnavailable；资产不存在 → failure。
    func testIC076G115AdditionPlanSkipsWriteWhenAlreadyContained() {
        XCTAssertEqual(
            PhotoAlbumAdditionPlan.make(
                albumExists: false, assetExists: true, alreadyContained: true
            ),
            .albumUnavailable
        )
        XCTAssertEqual(
            PhotoAlbumAdditionPlan.make(
                albumExists: true, assetExists: false, alreadyContained: false
            ),
            .assetUnavailable
        )
        XCTAssertEqual(
            PhotoAlbumAdditionPlan.make(
                albumExists: true, assetExists: true, alreadyContained: true
            ),
            .alreadyContained
        )
        XCTAssertEqual(
            PhotoAlbumAdditionPlan.make(
                albumExists: true, assetExists: true, alreadyContained: false
            ),
            .write
        )

        let service = FakeAssetActionService(
            albums: [S2AlbumReference(id: "album-1", name: "相簿一")],
            containedPairs: [FakeAssetActionService.pair("album-1", "asset-2")]
        )
        var outcomes: [S2AlbumAdditionOutcome] = []
        service.addAsset(assetID: "asset-2", toAlbumWithID: "album-1") {
            outcomes.append($0)
        }
        XCTAssertEqual(outcomes, [.success(alreadyContained: true)])
        XCTAssertEqual(service.writeCount, 0)

        service.addAsset(assetID: "asset-2", toAlbumWithID: "album-missing") {
            outcomes.append($0)
        }
        XCTAssertEqual(outcomes.last, .albumUnavailable)
        XCTAssertEqual(service.writeCount, 0)

        service.addAsset(assetID: "", toAlbumWithID: "album-1") {
            outcomes.append($0)
        }
        XCTAssertEqual(outcomes.last, .failure)
        XCTAssertEqual(service.writeCount, 0)

        service.addAsset(assetID: "asset-1", toAlbumWithID: "album-1") {
            outcomes.append($0)
        }
        XCTAssertEqual(service.writeCount, 1)
        XCTAssertEqual(service.pendingAdditions.count, 1)
        service.completePendingAddition(with: .success(alreadyContained: false))
        XCTAssertEqual(outcomes.last, .success(alreadyContained: false))
    }

    // IC-076 G118（协调器）：enterS2 读取持久化 H 并校验存在性——不存在则清除持久化值且
    // 状态机无 H；存在则照常注入。
    @MainActor
    func testIC076G118EnterS2ClearsPersistedRecentAlbumWhenAlbumMissing() throws {
        let missing = S2AlbumReference(id: "album-missing", name: "已删除")
        let missingStore = S2InMemoryRecentAlbumStore(initial: missing)
        let missingService = FakeAssetActionService(albums: [])
        let missingCoordinator = try makeCoordinatorInS2(
            service: missingService,
            store: missingStore
        )
        XCTAssertEqual(missingCoordinator.route, .s2)
        XCTAssertNil(missingCoordinator.s2Machine?.recentAlbum)
        XCTAssertNil(missingStore.load())
        XCTAssertEqual(missingStore.saveCount, 1)
        XCTAssertEqual(missingService.albumExistsQueries, ["album-missing"])

        let existing = S2AlbumReference(id: "album-1", name: "相簿一")
        let existingStore = S2InMemoryRecentAlbumStore(initial: existing)
        let existingService = FakeAssetActionService(albums: [existing])
        let existingCoordinator = try makeCoordinatorInS2(
            service: existingService,
            store: existingStore
        )
        XCTAssertEqual(existingCoordinator.s2Machine?.recentAlbum, existing)
        XCTAssertEqual(existingStore.load(), existing)
        XCTAssertEqual(existingStore.saveCount, 0)
        XCTAssertEqual(
            existingCoordinator.s2UserAlbums(),
            [existing]
        )

        let emptyStore = S2InMemoryRecentAlbumStore()
        let emptyService = FakeAssetActionService(albums: [existing])
        let emptyCoordinator = try makeCoordinatorInS2(
            service: emptyService,
            store: emptyStore
        )
        XCTAssertNil(emptyCoordinator.s2Machine?.recentAlbum)
        XCTAssertTrue(emptyService.albumExistsQueries.isEmpty)
    }

    // IC-076 R1（协调器接线）：三条请求路径——点击时登记进行中、服务结果回到同一台状态机
    // 与同一 request；成功的相簿加入经 H 回调持久化；历史相册不存在时清除持久化值。
    @MainActor
    func testIC076R1CoordinatorWiresThreeActionsThroughServiceAndStore() throws {
        let album = S2AlbumReference(id: "album-1", name: "相簿一")
        let other = S2AlbumReference(id: "album-2", name: "相簿二")
        let store = S2InMemoryRecentAlbumStore(initial: album)
        let service = FakeAssetActionService(albums: [album, other])
        let coordinator = try makeCoordinatorInS2(service: service, store: store)
        let machine = try XCTUnwrap(coordinator.s2Machine)
        let targetAssetID = machine.currentAssetID

        // 收藏：失败 → 反馈事件 1 次、标志清除、favorite(x) 不变。
        let favoriteRequest = try XCTUnwrap(machine.makeFavoriteToggleRequest())
        XCTAssertTrue(coordinator.requestS2FavoriteToggle(favoriteRequest))
        XCTAssertTrue(machine.isActionInFlight(.favorite))
        XCTAssertFalse(coordinator.requestS2FavoriteToggle(favoriteRequest))
        XCTAssertEqual(service.favoriteRequests, [targetAssetID])
        service.completePendingFavorite(succeeded: false)
        XCTAssertFalse(machine.isActionInFlight(.favorite))
        XCTAssertEqual(machine.feedbackEventCount, 1)
        XCTAssertFalse(machine.favoriteAssetIDs.contains(targetAssetID))

        // 收藏：成功 → favorite(x) 切换、无新反馈。
        let secondFavorite = try XCTUnwrap(machine.makeFavoriteToggleRequest())
        XCTAssertTrue(coordinator.requestS2FavoriteToggle(secondFavorite))
        service.completePendingFavorite(succeeded: true)
        XCTAssertTrue(machine.favoriteAssetIDs.contains(targetAssetID))
        XCTAssertEqual(machine.feedbackEventCount, 1)

        // 相簿选择：成功 → H 更新并持久化、sheet 关闭。
        let pickerRequest = try XCTUnwrap(machine.presentAlbumPicker())
        XCTAssertTrue(coordinator.requestS2AlbumPickerSelection(
            pickerRequest,
            album: other
        ))
        XCTAssertTrue(machine.isActionInFlight(.albumPicker))
        XCTAssertEqual(
            service.additionRequests.last.map { [$0.assetID, $0.albumID] },
            [targetAssetID, "album-2"]
        )
        service.completePendingAddition(with: .success(alreadyContained: false))
        XCTAssertEqual(machine.recentAlbum, other)
        XCTAssertEqual(store.load(), other)
        XCTAssertEqual(machine.sheetState, .closed)
        XCTAssertFalse(machine.isActionInFlight(.albumPicker))

        // 历史相册：目标相册已不存在 → H 清除并清除持久化值、无反馈事件。
        let recentRequest = try XCTUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertEqual(recentRequest.album, other)
        XCTAssertTrue(coordinator.requestS2RecentAlbumAddition(recentRequest))
        XCTAssertTrue(machine.isActionInFlight(.recentAlbum))
        service.completePendingAddition(with: .albumUnavailable)
        XCTAssertNil(machine.recentAlbum)
        XCTAssertNil(store.load())
        XCTAssertFalse(machine.isActionInFlight(.recentAlbum))
        XCTAssertEqual(machine.feedbackEventCount, 1)
        XCTAssertNil(machine.makeRecentAlbumAdditionRequest())

        // 离开 S2 后到达的结果被丢弃，不作用于新状态机。
        let lateFavorite = try XCTUnwrap(machine.makeFavoriteToggleRequest())
        XCTAssertTrue(coordinator.requestS2FavoriteToggle(lateFavorite))
        let payload = try XCTUnwrap(machine.makeExitPayload())
        XCTAssertTrue(coordinator.leaveS2(with: payload))
        XCTAssertEqual(coordinator.route, .s1)
        service.completePendingFavorite(succeeded: false)
        XCTAssertEqual(machine.feedbackEventCount, 1)
        XCTAssertTrue(machine.isActionInFlight(.favorite))
    }

    @MainActor
    private func makeCoordinatorInS2(
        service: FakeAssetActionService,
        store: S2InMemoryRecentAlbumStore
    ) throws -> CleanupCoordinator {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let assets = (1...3).map { day in
            S1PhotoAssetSnapshot(
                identifier: "资产-\(day)",
                creationDate: calendar.date(
                    from: DateComponents(year: 2026, month: 8, day: day, hour: 12)
                )
            )
        }
        let photoLibrary = PhotoLibraryService(
            s1Source: S1PhotoLibrarySource(
                authorizationStatus: { .authorized },
                fetchAssets: { assets },
                fetchAssetCollections: { _, _ in [] }
            )
        )
        let coordinator = CleanupCoordinator(
            photoLibrary: photoLibrary,
            assetActionService: service,
            recentAlbumStore: store
        )
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-076"))
        let s1Machine = try XCTUnwrap(coordinator.s1Machine)
        let request = try XCTUnwrap(s1Machine.currentReadRequest)
        let ranges = try coordinator.readS1Ranges(groupedBy: .month).get()
        XCTAssertTrue(s1Machine.completeRangeRead(.success(ranges), for: request))
        let range = try XCTUnwrap(ranges.first)
        let handoff = try XCTUnwrap(s1Machine.makeS2Handoff(for: range.id))
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        return coordinator
    }

    private func makeMachine(
        recentAlbum: S2AlbumReference? = nil,
        pendingDeletionAssetIDs: Set<String> = []
    ) -> S2StateMachine {
        S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-076",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-076",
                    displayName: "测试范围",
                    totalAssetCount: 3
                ),
                orderedAssetIDs: ["asset-1", "asset-2", "asset-3"],
                currentAssetID: "asset-2",
                pendingDeletionAssetIDs: pendingDeletionAssetIDs,
                sessionMergedPendingDeletionCountProvider: { 0 }
            ),
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            ),
            parameters: tryUnwrap(
                S2CalibrationConfiguration.factoryPlaceholder.resolvedParameters
            ),
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: recentAlbum,
            pendingDeletionDidChange: { _ in }
        )!
    }
    // IC-076 G118（R4）：`H` 写入 → 以同一 suite 重建存储 → 读回一致；清除后读回为空。
    func testIC076G118RecentAlbumStoreRoundTripsAndClears() {
        let suiteName = "IC076-recent-album-\(UUID().uuidString)"
        let defaults = tryUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let album = S2AlbumReference(id: "album-076", name: "相簿 076")
        let first = S2UserDefaultsRecentAlbumStore(defaults: defaults)
        XCTAssertNil(first.load())
        first.save(album)
        XCTAssertEqual(first.load(), album)

        let rebuilt = S2UserDefaultsRecentAlbumStore(defaults: defaults)
        XCTAssertEqual(rebuilt.load(), album)
        XCTAssertEqual(
            defaults.dictionary(
                forKey: S2UserDefaultsRecentAlbumStore.defaultsKey
            )?[S2UserDefaultsRecentAlbumStore.idField] as? String,
            "album-076"
        )

        rebuilt.save(nil)
        XCTAssertNil(rebuilt.load())
        XCTAssertNil(
            defaults.object(forKey: S2UserDefaultsRecentAlbumStore.defaultsKey)
        )
        XCTAssertNil(S2UserDefaultsRecentAlbumStore(defaults: defaults).load())

        // 空标识不构成有效 `H`：写入视为清除。
        rebuilt.save(S2AlbumReference(id: "", name: "无效"))
        XCTAssertNil(rebuilt.load())

        let memory = S2InMemoryRecentAlbumStore()
        XCTAssertNil(memory.load())
        memory.save(album)
        XCTAssertEqual(memory.load(), album)
        memory.save(nil)
        XCTAssertNil(memory.load())
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("预期值不应为空", file: file, line: line)
            fatalError("测试无法继续")
        }
        return value
    }

    // MARK: - IC-111 A：chrome 几何对齐 v18 画布

    // IC-111 A：画布常量逐条落值；v17 的三个量已废止（编译期即可证——
    // 引用它们的断言本卡一并改写，符号不复存在）。
    func testIC111ALayoutAnchorsMatchCanvas() {
        XCTAssertEqual(S2OverlayLayout.chromeRowHeight, 44)
        XCTAssertEqual(S2OverlayLayout.topRowTopInset, 3)
        XCTAssertEqual(S2OverlayLayout.bottomRowBottomInset, 8)
        XCTAssertEqual(S2OverlayLayout.chromeHorizontalMargin, 16)
        XCTAssertEqual(S2OverlayLayout.stripToBottomRowSpacing, 24)
        // 顶栏底缘 = 3 + 44 = 47（由画布两量推导，不是裸值）
        XCTAssertEqual(S2OverlayLayout.topBarHeight, 47)
        XCTAssertEqual(
            S2OverlayLayout.topBarHeight,
            S2OverlayLayout.topRowTopInset + S2OverlayLayout.chromeRowHeight,
            accuracy: 0.000_001
        )
        // 未被本卡改动的量维持原值
        XCTAssertEqual(S2OverlayLayout.minimumTouchTarget, 44)
        XCTAssertEqual(S2OverlayLayout.minimumSpacing, 8)
        XCTAssertEqual(S2OverlayLayout.horizontalPadding, 8)
    }

    // IC-111 A：底排竖向逐层落在画布上（393×852、安全区底 34）——
    // 下缘距视口底 42、上缘 86（画布 y=766）、横栏底缘 110（画布 y=742）。
    func testIC111ABottomRowMatchesCanvasVerticalPositions() {
        let safeBottom: CGFloat = 34
        XCTAssertEqual(
            S2OverlayLayout.actionBandBottomFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            42,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2OverlayLayout.actionBandTopFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            86,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2OverlayLayout.actionBandCenterFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            64,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            110,
            accuracy: 0.000_001
        )
        // 画布坐标核对：视口高 852 ⟹ 底排上缘 y = 766、横栏底缘 y = 742
        XCTAssertEqual(
            852 - S2OverlayLayout.actionBandTopFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            766,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            852 - S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: safeBottom
            ),
            742,
            accuracy: 0.000_001
        )
        // 「横栏底缘 ↔ 底排上缘」恰为 24
        XCTAssertEqual(
            S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: safeBottom
            ) -
                S2OverlayLayout.actionBandTopFromViewportBottom(
                    safeAreaBottom: safeBottom
                ),
            S2OverlayLayout.stripToBottomRowSpacing,
            accuracy: 0.000_001
        )
    }

    // IC-111 A：底排随安全区自适应——锚的是安全区底而非视口底。
    func testIC111ABottomRowFollowsSafeArea() {
        for safeBottom in [CGFloat(0), 20, 34, 60] {
            XCTAssertEqual(
                S2OverlayLayout.actionBandBottomFromViewportBottom(
                    safeAreaBottom: safeBottom
                ),
                safeBottom + S2OverlayLayout.bottomRowBottomInset,
                accuracy: 0.000_001
            )
            // L2：底排下缘严格高于安全区底，不进主屏幕指示条区域
            XCTAssertGreaterThan(
                S2OverlayLayout.actionBandBottomFromViewportBottom(
                    safeAreaBottom: safeBottom
                ),
                safeBottom
            )
        }
    }

    // IC-111 A：药丸取值自洽——圆钮与胶囊同高且等于 chrome 行高；
    // 可见带自此就是触控带本身（v17 的「可见带高 22」概念已废止）。
    func testIC111AChromePillMetricsEqualChromeRow() {
        XCTAssertEqual(
            S2ChromePillMetrics.pillHeight,
            S2OverlayLayout.chromeRowHeight,
            "圆钮/胶囊高必须与 chrome 行高同源，否则可见带又会与模型脱节"
        )
        XCTAssertEqual(
            S2ChromePillMetrics.pillHeight,
            S2OverlayLayout.minimumTouchTarget,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(S2ChromePillMetrics.capsuleHorizontalPadding, 0)
        XCTAssertLessThan(
            S2ChromePillMetrics.circleIconPointSize,
            S2ChromePillMetrics.pillHeight,
            "图标必须小于圆钮直径"
        )
        // 画布字号
        XCTAssertEqual(S2ChromePillMetrics.titleFontSize, 15)
        XCTAssertEqual(S2ChromePillMetrics.subtitleFontSize, 11.5)
        // IC-120 A：副行白 62% 定值随自适应规则废止（subtitleOpacity 已删），
        // 副行改系统次级色，无可断言的固定不透明度。
        XCTAssertEqual(S2ChromePillMetrics.bottomCapsuleIconPointSize, 17)
        XCTAssertEqual(S2ChromePillMetrics.bottomCapsuleTextFontSize, 15)
    }

    // IC-121 A：chrome 前景必须是**具体动态色**（Color.primary/.secondary），
    // 不得回退为层级样式——层级 .primary 在启用态 Button 标签内解析为
    // tint（accent 蓝），即 H54 蓝色泄漏的真因；具体色不参与 tint/层级
    // 解析。启用/禁用态下的运行时解析行为夹具无法覆盖，真机 H55 兜底。
    func testIC121AChromeForegroundIsConcreteAdaptiveColor() {
        XCTAssertEqual(S2ChromeForeground.onGlassPrimary, Color.primary)
        XCTAssertEqual(S2ChromeForeground.onGlassSecondary, Color.secondary)
    }

    // IC-123 A：中央指示玻璃内前景按 colorScheme **显式解析为定值色**——
    // 浅色 = label 黑、深色 = label 白，与 `Color.primary`（IC-121 A 规则）
    // 同源，两态取值不同；撤回钮不改，仍走具体动态色。
    func testIC123AIndicatorForegroundIsResolvedPerColorScheme() {
        func white(_ color: UIColor, line: UInt = #line) -> CGFloat {
            var value: CGFloat = -1
            var alpha: CGFloat = -1
            XCTAssertTrue(color.getWhite(&value, alpha: &alpha), line: line)
            XCTAssertEqual(alpha, 1, accuracy: 0.001, line: line)
            return value
        }
        let light = UIColor(S2CenterIndicatorView.resolvedForeground(for: .light))
        let dark = UIColor(S2CenterIndicatorView.resolvedForeground(for: .dark))
        let labelLight = UIColor.label.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        )
        let labelDark = UIColor.label.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .dark)
        )

        XCTAssertEqual(white(light), white(labelLight), accuracy: 0.001)
        XCTAssertEqual(white(dark), white(labelDark), accuracy: 0.001)
        XCTAssertEqual(white(light), 0, accuracy: 0.001, "浅色前景应为黑")
        XCTAssertEqual(white(dark), 1, accuracy: 0.001, "深色前景应为白")
        XCTAssertEqual(S2ChromeForeground.onGlassPrimary, Color.primary)
    }

    // IC-123 A（夹具驱动；CI 模拟器为 iOS 18.5，玻璃走回落配方，iOS 26
    // `glassEffect` 合成层未覆盖，真机 H56 第 1 项兜底）：**同一实例**、不
    // 重建、不翻页——只把宿主外观 override 在深/浅间来回切，玻璃内图标与
    // 文字必须随之改色：浅色下出现近黑像素（label 黑），深色下没有。
    @MainActor
    func testIC123AIndicatorGlassContentFollowsInPlaceAppearanceSwitch() throws {
        let view = ZStack {
            Color.white
            S2CenterIndicatorView(
                state: .addedToAlbum(albumName: "旅行"),
                onUndo: {}
            )
        }
        .ignoresSafeArea()
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .white
        let window = UIWindow(
            frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 200))
        )
        window.backgroundColor = .white
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }

        controller.overrideUserInterfaceStyle = .dark
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let darkFirst = try ic123NearBlackPixelCount(in: controller)

        controller.overrideUserInterfaceStyle = .light
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let light = try ic123NearBlackPixelCount(in: controller)

        controller.overrideUserInterfaceStyle = .dark
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let darkAgain = try ic123NearBlackPixelCount(in: controller)

        XCTAssertEqual(darkFirst, 0, "深色下玻璃内前景应为白，不应有近黑像素")
        XCTAssertGreaterThan(light, 20, "原位切到浅色后图标与文字应即时变黑")
        XCTAssertEqual(darkAgain, 0, "原位切回深色后应即时变回白")
    }

    /// IC-123 A：把宿主视图按 @2x 截屏，数亮度 < 24 的像素（label 黑的实体
    /// 像素；深色回落材质即便按不透明回退色渲染也在 40 以上，不会误计）。
    @MainActor
    private func ic123NearBlackPixelCount(
        in controller: UIViewController
    ) throws -> Int {
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            bounds: controller.view.bounds,
            format: format
        ).image { _ in
            _ = controller.view.drawHierarchy(
                in: controller.view.bounds,
                afterScreenUpdates: true
            )
        }
        let bitmap = try S2StripBitmap(cgImage: XCTUnwrap(image.cgImage))
        var count = 0
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width where bitmap.luminance(x: x, y: y) < 24 {
                count += 1
            }
        }
        return count
    }

    // IC-121 B：角标通知徽标样式取值——红底白字恒定（深浅同款）、
    // 1.5pt 协调描边、单数字正圆最小径容得下数字。渲染观感真机未覆盖，
    // H55 第 2 项兜底。
    func testIC121BBadgeMatchesNotificationStyle() {
        XCTAssertEqual(S2ConfirmationBadgeStyle.fill, Color.red)
        XCTAssertEqual(S2ConfirmationBadgeStyle.digitColor, Color.white)
        XCTAssertEqual(
            S2ConfirmationBadgeStyle.ringWidth,
            1.5,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            S2ConfirmationBadgeStyle.minDiameter,
            S2ConfirmationBadgeStyle.fontSize,
            "正圆最小径必须容得下数字"
        )
        XCTAssertGreaterThan(S2ConfirmationBadgeStyle.horizontalPadding, 0)
    }

    // IC-120 B：角标锚点几何与顶排右上圆钮同源——badge overlay 的
    // 顶/右内边距（topRowTopInset / chromeHorizontalMargin）恰为
    // 圆钮 topTrailing 角在顶排坐标系里的两侧留白。渲染层序
    // （容器外 overlay 恒在玻璃之上）SwiftUI 无法直接断言，真机未覆盖，
    // H54 第 1 项兜底。
    func testIC120BBadgeAnchorMatchesTrailingCircleTopCorner() {
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: 393,
            height: S2OverlayLayout.topBarHeight
        )
        let trailing = S2OverlayLayout.topElementFrames(in: bounds)[2]
        XCTAssertEqual(
            trailing.minY,
            S2OverlayLayout.topRowTopInset,
            accuracy: 0.000_001,
            "角标顶内边距必须等于圆钮顶缘位置"
        )
        XCTAssertEqual(
            bounds.maxX - trailing.maxX,
            S2OverlayLayout.chromeHorizontalMargin,
            accuracy: 0.000_001,
            "角标右内边距必须等于圆钮右缘留白"
        )
    }

    // IC-111 A：顶排三槽改画布几何——左右 Ø44 圆钮、边距 16、行内下移 3。
    func testIC111ATopElementFramesMatchCanvas() {
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: 393,
            height: S2OverlayLayout.topBarHeight
        )
        let frames = S2OverlayLayout.topElementFrames(in: bounds)
        XCTAssertEqual(frames.count, 3)

        // 左右为 Ø44 圆钮，贴 16 边距
        XCTAssertEqual(frames[0].minX, 16, accuracy: 0.000_001)
        XCTAssertEqual(frames[0].width, 44, accuracy: 0.000_001)
        XCTAssertEqual(frames[2].maxX, 393 - 16, accuracy: 0.000_001)
        XCTAssertEqual(frames[2].width, 44, accuracy: 0.000_001)

        // 行整体下移 3，行高 44（不是 47——47 是含上留白的顶栏帧高）
        for frame in frames {
            XCTAssertEqual(
                frame.minY,
                S2OverlayLayout.topRowTopInset,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                frame.height,
                S2OverlayLayout.chromeRowHeight,
                accuracy: 0.000_001
            )
            XCTAssertLessThanOrEqual(
                frame.maxY,
                S2OverlayLayout.topBarHeight
            )
        }

        // 中槽夹在两圆之间、各留 8 pt；且左右对称 ⟹ 居中
        XCTAssertEqual(
            frames[1].minX,
            frames[0].maxX + S2OverlayLayout.minimumSpacing,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            frames[1].maxX,
            frames[2].minX - S2OverlayLayout.minimumSpacing,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            frames[1].midX,
            bounds.width / 2,
            accuracy: 0.000_001,
            "中槽必须水平居中，胶囊居中于它即居中于屏"
        )
    }

    // IC-110 B：中胶囊承载现有「加入最近相簿」按钮，沿用原条件显示语义——
    // 有最近相簿才显示；启用/禁用规则零变化（另见 IC-076 R3 用例）。
    func testIC110BCenterCapsuleFollowsExistingRecentAlbumVisibility() {
        let withoutHistory = S2ActionBarPresentation(machine: makeMachine())
        XCTAssertFalse(
            withoutHistory.showsRecentAlbum,
            "无最近相簿时中胶囊缺席，只余左右圆钮"
        )

        let album = S2AlbumReference(id: "album-110", name: "旅行")
        let withHistory = S2ActionBarPresentation(
            machine: makeMachine(recentAlbum: album)
        )
        XCTAssertTrue(withHistory.showsRecentAlbum)
        // 换装不改启用规则：三者在空闲态均可用。
        XCTAssertTrue(withHistory.favoriteEnabled)
        XCTAssertTrue(withHistory.recentAlbumEnabled)
        XCTAssertTrue(withHistory.addAlbumEnabled)
    }

    // MARK: - IC-112 A：玻璃配方与高光描边

    // IC-113 A：玻璃再透 + 描边收敛（H49 第 1 条）。
    // 底色白 6%→3%、内描边 55%/12%→30%/6%、外环 22%→12%。
    func testIC113AGlassRecipeIsMoreTransparentAndSubtler() {
        XCTAssertEqual(S2ChromeGlass.tintOpacity, 0.03, accuracy: 0.000_001)
        XCTAssertEqual(
            S2ChromeGlass.innerHighlightTop,
            0.30,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2ChromeGlass.innerHighlightBottom,
            0.06,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2ChromeGlass.outerRingOpacity,
            0.12,
            accuracy: 0.000_001
        )

        // 相对 IC-112 的旧值，三者都**至少减半**——这正是 H49 的诉求，
        // 把「更透 / 存在感减半」钉成可回归的不变量，而不是只钉绝对值。
        XCTAssertLessThanOrEqual(S2ChromeGlass.tintOpacity, 0.06 / 2)
        XCTAssertLessThanOrEqual(S2ChromeGlass.innerHighlightTop, 0.55 / 1.8)
        XCTAssertLessThanOrEqual(S2ChromeGlass.outerRingOpacity, 0.22 / 1.8)

        // 结构性不变量保持：顶缘仍亮于底缘（渐弱方向不能反）、白底仍够薄。
        XCTAssertGreaterThan(
            S2ChromeGlass.innerHighlightTop,
            S2ChromeGlass.innerHighlightBottom
        )
        XCTAssertLessThan(
            S2ChromeGlass.tintOpacity,
            0.2,
            "底色过实会把透光盖死，正是本卡要修的毛病"
        )
        XCTAssertGreaterThan(S2ChromeGlass.innerStrokeWidth, 0)
        XCTAssertGreaterThan(S2ChromeGlass.outerStrokeWidth, 0)
    }

    // MARK: - IC-114 D：放大自动进入隐藏态

    // IC-114 D（⑤a ④）：双击进入放大 → 自动隐藏；退出 → 恢复进入前 V。
    func testIC114DDoubleTapZoomAutoHidesAndRestores() {
        let machine = makeMachine()
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertNil(machine.recordedVisibilityBeforeZoom)

        // 进入放大：自动隐藏，并记下进入前的显示态
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.zoomState, .nX)
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.recordedVisibilityBeforeZoom, .visible)

        // 退出放大：恢复进入前 V，并清空记录
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertNil(machine.recordedVisibilityBeforeZoom)
    }

    // IC-114 D：进入时 V 已是隐藏 → 记录隐藏、无动作；退出后仍是隐藏。
    func testIC114DZoomFromHiddenKeepsHidden() {
        let machine = makeMachine()
        // 单击切到隐藏
        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)

        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(
            machine.recordedVisibilityBeforeZoom,
            .hidden,
            "进入时已隐藏应记录隐藏"
        )

        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(
            machine.interfaceVisibility,
            .hidden,
            "记录的是隐藏，恢复后仍应隐藏"
        )
        XCTAssertNil(machine.recordedVisibilityBeforeZoom)
    }

    // IC-114 D：捏合入口同样覆盖——卡内要求把双击的记录机制扩展到捏合。
    func testIC114DPinchZoomAutoHidesAndRestores() {
        let machine = makeMachine()
        XCTAssertEqual(machine.interfaceVisibility, .visible)

        let viewportSize = CGSize(width: 393, height: 852)
        let fittedSize = CGSize(width: 393, height: 562)
        XCTAssertTrue(machine.beginPinch())
        XCTAssertTrue(machine.updatePinch(
            magnification: 2,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.zoomState, .nX)
        XCTAssertEqual(
            machine.interfaceVisibility,
            .hidden,
            "捏合放大同样自动隐藏"
        )
        XCTAssertEqual(machine.recordedVisibilityBeforeZoom, .visible)

        // 捏回 1x（低于回弹阈值即归位）
        XCTAssertTrue(machine.updatePinch(
            magnification: 0.1,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertTrue(machine.endPinch(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertNil(machine.recordedVisibilityBeforeZoom)
    }

    // IC-114 D：放大中的倍率变化（>1 → >1）不触碰 V——
    // 否则捏合过程中会反复改显隐。
    func testIC114DScaleChangesWithinZoomDoNotTouchVisibility() {
        let machine = makeMachine()
        let viewportSize = CGSize(width: 393, height: 852)
        let fittedSize = CGSize(width: 393, height: 562)
        XCTAssertTrue(machine.beginPinch())
        XCTAssertTrue(machine.updatePinch(
            magnification: 2,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.interfaceVisibility, .hidden)

        // IC-115 修 D：捏合期间 touchSequenceOwner == .pinch，
        // handleSingleTap 会被 receivesUnobscuredInput 挡下（这是 IC047-035
        // 的既有语义，非缺陷）。原用例在捏合未结束时就单击，故必然失败。
        // 改为先结束捏合再单击。
        XCTAssertTrue(machine.endPinch(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.zoomState, .nX)

        // Nx 下单击仍切 V（既有语义不变，新契约第 4 条）
        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(
            machine.recordedVisibilityBeforeZoom,
            .visible,
            "Nx 期间的单击不得改写记录值"
        )

        // 再捏一次继续放大：V 不因倍率变化而变
        XCTAssertTrue(machine.beginPinch())
        XCTAssertTrue(machine.updatePinch(
            magnification: 3,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(
            machine.interfaceVisibility,
            .visible,
            "放大中的倍率变化不得触碰 V"
        )
        XCTAssertEqual(machine.zoomState, .nX)
    }

    // IC-114 D：翻页复位到 1x 也走同一分派——恢复进入前 V 并清记录。
    func testIC114DPhotoChangeResetRestoresVisibility() {
        let machine = makeMachine()
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.recordedVisibilityBeforeZoom, .visible)

        // 翻页会把缩放复位（Nx 下贴边横滑即翻页，公开路径）
        XCTAssertTrue(machine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: 400,
            velocity: 4000
        ))
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertNil(machine.recordedVisibilityBeforeZoom)
    }

    // MARK: - IC-118 A：真机捏合路径的自动隐藏

    // IC-118 A：真机捏合的 `s` 走 beginPinch → reportNativeViewport（逐帧）→
    // finishNativePinch，此前后两者直写 scale 绕过 setScale，⑤a 在该路径失效。
    // 本组测试按真机调用序列在状态机层复刻；scroll view 接线本身仍为
    // 夹具未覆盖，由 H53 第 1 项真机兜底。
    func testIC118ANativePinchViewportReportAutoHidesAndRestores() {
        let machine = makeMachine()
        XCTAssertEqual(machine.interfaceVisibility, .visible)

        XCTAssertTrue(machine.beginPinch())
        machine.reportNativeViewport(scale: 2, viewportOffset: .zero)
        XCTAssertEqual(machine.zoomState, .nX)
        XCTAssertEqual(
            machine.interfaceVisibility,
            .hidden,
            "真机捏合进入放大须自动隐藏"
        )
        XCTAssertEqual(machine.recordedVisibilityBeforeZoom, .visible)

        // 捏回 1 后松手：finishNativePinch 内部回报 + 回弹归位
        XCTAssertEqual(
            machine.finishNativePinch(
                scale: 1,
                viewportOffset: .zero,
                accepted: true
            ),
            1
        )
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertNil(machine.recordedVisibilityBeforeZoom)
    }

    // IC-118 A：松手时低于回弹阈值（出厂 1.1）→ finishNativePinch 归位到 1，
    // 同样恢复进入前 V。
    func testIC118AFinishNativePinchSnapBackRestoresVisibility() {
        let machine = makeMachine()
        XCTAssertTrue(machine.beginPinch())
        machine.reportNativeViewport(scale: 1.5, viewportOffset: .zero)
        XCTAssertEqual(machine.interfaceVisibility, .hidden)

        XCTAssertEqual(
            machine.finishNativePinch(
                scale: 1.05,
                viewportOffset: .zero,
                accepted: true
            ),
            1
        )
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertNil(machine.recordedVisibilityBeforeZoom)
    }

    // IC-118 A：无捏合在途的视口回声（回弹动画帧经 scrollViewDidZoom 回报）
    // 只写倍率、不触碰 V——否则恢复后会被瞬时重隐藏一次（闪烁）。
    func testIC118AViewportEchoWithoutPinchDoesNotTouchVisibility() {
        let machine = makeMachine()
        // 先经捏合进出一轮，回到 V=显示、s=1、记录已清
        XCTAssertTrue(machine.beginPinch())
        machine.reportNativeViewport(scale: 2, viewportOffset: .zero)
        XCTAssertEqual(
            machine.finishNativePinch(
                scale: 1.05,
                viewportOffset: .zero,
                accepted: true
            ),
            1
        )
        XCTAssertEqual(machine.interfaceVisibility, .visible)

        // 回弹动画帧的回声：owner 已是 .none
        machine.reportNativeViewport(
            scale: 1.04,
            viewportOffset: .zero
        )
        XCTAssertEqual(
            machine.interfaceVisibility,
            .visible,
            "回声不得重新触发自动隐藏"
        )
        XCTAssertNil(
            machine.recordedVisibilityBeforeZoom,
            "回声不得改写记录"
        )
        machine.reportNativeViewport(scale: 1, viewportOffset: .zero)
        XCTAssertEqual(machine.zoomState, .oneX)
        XCTAssertEqual(machine.interfaceVisibility, .visible)
    }

    // MARK: - IC-114 C：相簿选择器 + 新建相簿

    // IC-114 C：新建相簿只创建、不加成员；成功后并入列表、可被随后的
    // 「选择」路径加入。空名与失败开关都回 nil。
    func testIC114CCreateAlbumOnlyCreates() {
        let service = FakeAssetActionService(albums: [])
        XCTAssertTrue(service.userAlbumItems().isEmpty)

        var created: S2AlbumReference?
        service.createAlbum(named: "旅行") { created = $0 }
        let album = tryUnwrap(created)
        XCTAssertEqual(album.name, "旅行")
        XCTAssertEqual(service.creationRequests, ["旅行"])
        // 只创建——**没有任何成员写入**
        XCTAssertTrue(service.additionRequests.isEmpty)
        XCTAssertEqual(service.writeCount, 0)
        // 新相簿已并入列表，且数量为 0
        let items = service.userAlbumItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.album, album)
        XCTAssertEqual(items.first?.assetCount, 0)

        // 空名不创建
        var blank: S2AlbumReference? = album
        service.createAlbum(named: "   ") { blank = $0 }
        XCTAssertNil(blank)

        // 失败开关
        service.creationSucceeds = false
        var failed: S2AlbumReference? = album
        service.createAlbum(named: "另一个") { failed = $0 }
        XCTAssertNil(failed)
    }

    // IC-114 C：新建失败走既有反馈通道，只多一个分支，不改任何状态。
    func testIC114CCreationFailurePublishesFeedback() {
        let machine = makeMachine()
        XCTAssertNil(machine.feedbackEvent)
        let beforeRecent = machine.recentAlbum

        machine.reportAlbumCreationFailure()

        let event = tryUnwrap(machine.feedbackEvent)
        XCTAssertEqual(event.kind, .albumCreationFailed)
        // 状态不受影响
        XCTAssertEqual(machine.recentAlbum, beforeRecent)
        XCTAssertNil(machine.lastAlbumAddition)
        // 文案接上了（三种失败各有各的）
        XCTAssertFalse(
            S2FeedbackToastPresenter.text(for: .albumCreationFailed).isEmpty
        )
        XCTAssertNotEqual(
            S2FeedbackToastPresenter.text(for: .albumCreationFailed),
            S2FeedbackToastPresenter.text(for: .albumAdditionFailed)
        )
    }

    // IC-114 C：列表项模型——数量随成员关系走，键图可为空。
    func testIC114CAlbumListItemsReportCounts() {
        let album = S2AlbumReference(id: "album-1", name: "旅行")
        let other = S2AlbumReference(id: "album-2", name: "家人")
        let service = FakeAssetActionService(
            albums: [album, other],
            containedPairs: [
                FakeAssetActionService.pair(album.id, "asset-1"),
                FakeAssetActionService.pair(album.id, "asset-2")
            ]
        )
        let items = service.userAlbumItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(
            items.first(where: { $0.album == album })?.assetCount,
            2
        )
        XCTAssertEqual(
            items.first(where: { $0.album == other })?.assetCount,
            0
        )
        // Identifiable 用相簿 id
        XCTAssertEqual(items.first?.id, items.first?.album.id)
    }

    // IC-114 C：选择器的三个动作齐备且各司其职——
    // 新建回调带回相簿后由选择器再走 select，故加入路径只有一条。
    func testIC114CPickerActionsRouteCreateThenSelect() {
        var selected: [S2AlbumReference] = []
        var cancelled = 0
        var createNames: [String] = []
        let created = S2AlbumReference(id: "created-新建", name: "新建")

        let actions = S2AlbumPickerActions(
            select: { selected.append($0) },
            cancel: { cancelled += 1 },
            create: { name, completion in
                createNames.append(name)
                completion(created)
            }
        )

        // 模拟选择器在创建成功后自行再走一次 select
        actions.create("新建") { album in
            if let album {
                actions.select(album)
            }
        }
        XCTAssertEqual(createNames, ["新建"])
        XCTAssertEqual(selected, [created])
        XCTAssertEqual(cancelled, 0)

        // 创建失败则不加入
        let failing = S2AlbumPickerActions(
            select: { selected.append($0) },
            cancel: { cancelled += 1 },
            create: { _, completion in completion(nil) }
        )
        failing.create("失败") { album in
            if let album {
                failing.select(album)
            }
        }
        XCTAssertEqual(selected, [created], "创建失败时不得走加入")
    }

    // MARK: - IC-114 B2：手势图示方向

    // IC-114 B2 防回退：**每步的方向向量必须与位移轴一致**。
    //
    // 竖直方向只许动 y、水平方向只许动 x，且符号与语义一致
    // （上滑为负 y、下滑为正 y、右拖为正 x）。
    //
    // 注意：H50 那个「箭头固定、圆点从左往右」的真实成因是**视图身份**
    // （图示跨步复用实例、动画不重装），本断言查的是映射表本身，
    // **抓不到那类缺陷**——身份修复的效果由 H51 第 4 项真机判定。
    func testIC114B2DirectionVectorMatchesAxis() {
        let up = S2TutorialGestureDirection.up.offset
        XCTAssertEqual(up.width, 0, accuracy: 0.000_001, "上滑不得有水平分量")
        XCTAssertLessThan(up.height, 0, "上滑应为负 y")

        let down = S2TutorialGestureDirection.down.offset
        XCTAssertEqual(down.width, 0, accuracy: 0.000_001, "下滑不得有水平分量")
        XCTAssertGreaterThan(down.height, 0, "下滑应为正 y")

        let right = S2TutorialGestureDirection.right.offset
        XCTAssertEqual(right.height, 0, accuracy: 0.000_001, "右拖不得有竖直分量")
        XCTAssertGreaterThan(right.width, 0, "右拖应为正 x")

        // 位移幅度统一取 travel
        XCTAssertEqual(
            abs(up.height),
            S2TutorialGestureHint.travel,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            abs(down.height),
            S2TutorialGestureHint.travel,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            abs(right.width),
            S2TutorialGestureHint.travel,
            accuracy: 0.000_001
        )

        // 逐步核对方向语义
        XCTAssertEqual(S2TutorialStep.swipeUpToMark.gestureDirection, .up)
        XCTAssertEqual(S2TutorialStep.returnToMarked.gestureDirection, .right)
        XCTAssertEqual(S2TutorialStep.swipeDownToCancel.gestureDirection, .down)
        // 观察/点击类步骤无图示
        XCTAssertNil(S2TutorialStep.seeStripMark.gestureDirection)
        XCTAssertNil(S2TutorialStep.albumGuide.gestureDirection)
        XCTAssertNil(S2TutorialStep.confirmEntry.gestureDirection)
    }

    // MARK: - IC-114 A3：chrome 显隐过渡

    // IC-114 A3（⑤b ④）：显→隐 scale 1→1.06、模糊 0→8pt、淡出；隐→显反向。
    // **夹具驱动，真机未覆盖**（陷阱 1）——真机观感由 H51 第 2 项判。
    func testIC114A3VisibilityTransitionEndpoints() {
        // 显示端：三项均为恒等值，静止态不产生任何视觉偏移
        XCTAssertEqual(
            S2ChromeVisibilityTransition.scale(isVisible: true),
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2ChromeVisibilityTransition.blurRadius(isVisible: true),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2ChromeVisibilityTransition.opacity(isVisible: true),
            1,
            accuracy: 0.000_001
        )

        // 隐藏端：按卡内落值
        XCTAssertEqual(
            S2ChromeVisibilityTransition.scale(isVisible: false),
            1.06,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2ChromeVisibilityTransition.blurRadius(isVisible: false),
            8,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2ChromeVisibilityTransition.opacity(isVisible: false),
            0,
            accuracy: 0.000_001
        )

        XCTAssertEqual(
            S2ChromeVisibilityTransition.durationSeconds,
            0.2,
            accuracy: 0.000_001
        )
    }

    // IC-114 A3：方向自洽——隐藏端必须是**放大**且**更模糊**，
    // 写反了观感就成了「缩回去」，这条断言把方向钉死。
    func testIC114A3HiddenEndIsLargerAndBlurrier() {
        XCTAssertGreaterThan(
            S2ChromeVisibilityTransition.scale(isVisible: false),
            S2ChromeVisibilityTransition.scale(isVisible: true),
            "隐藏端应放大，不是缩小"
        )
        XCTAssertGreaterThan(
            S2ChromeVisibilityTransition.blurRadius(isVisible: false),
            S2ChromeVisibilityTransition.blurRadius(isVisible: true)
        )
        XCTAssertLessThan(
            S2ChromeVisibilityTransition.opacity(isVisible: false),
            S2ChromeVisibilityTransition.opacity(isVisible: true)
        )
        // 进出对称：同一组取值按 isVisible 取反，故隐→显即显→隐的逆
        XCTAssertEqual(
            S2ChromeVisibilityTransition.scale(isVisible: true),
            1,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(S2ChromeVisibilityTransition.durationSeconds, 0)
    }

    // MARK: - IC-112 B / IC-113 B：中央状态指示

    // IC-113 B：同一时刻只显示一种；两态并存时取最近一次动作对应的那种。
    // 第二态由 ♡ 改挂**加入相簿**（④ 产品输入更新）。
    func testIC113BShowsExactlyOneStateAtATime() {
        func resolve(
            marked: Bool,
            album: String?,
            last: S2CenterIndicatorAction?
        ) -> S2CenterIndicatorState? {
            S2CenterIndicatorResolver.state(
                interfaceVisibility: .visible,
                isMarked: marked,
                addedAlbumName: album,
                lastAction: last
            )
        }

        XCTAssertNil(resolve(marked: false, album: nil, last: nil))
        XCTAssertEqual(resolve(marked: true, album: nil, last: nil), .marked)
        XCTAssertEqual(
            resolve(marked: false, album: "旅行", last: nil),
            .addedToAlbum(albumName: "旅行")
        )
        // 并存 → 看最近一次动作
        XCTAssertEqual(
            resolve(marked: true, album: "旅行", last: .mark),
            .marked
        )
        XCTAssertEqual(
            resolve(marked: true, album: "旅行", last: .album),
            .addedToAlbum(albumName: "旅行")
        )
        // 并存但无最近动作 → 取 marked（沿用 IC-112 取定）
        XCTAssertEqual(
            resolve(marked: true, album: "旅行", last: nil),
            .marked
        )
    }

    // IC-113 B：指示随 chrome 同显隐——V=隐藏 时一律不显示。
    func testIC113BHiddenInterfaceShowsNothing() {
        for marked in [true, false] {
            for album in ["旅行", nil] as [String?] {
                for last in [
                    S2CenterIndicatorAction.mark,
                    .album,
                    nil
                ] as [S2CenterIndicatorAction?] {
                    XCTAssertNil(
                        S2CenterIndicatorResolver.state(
                            interfaceVisibility: .hidden,
                            isMarked: marked,
                            addedAlbumName: album,
                            lastAction: last
                        ),
                        "V=隐藏 时不得显示（marked=\(marked)）"
                    )
                }
            }
        }
    }

    // IC-113 B G284（硬闸门，语义不变）：命中测试——**仅撤回钮可点**。
    // 撤回钮只在「已加入相簿」态存在；「已标记」与撤回后的短提示态
    // 都没有任何可点元素，整块纯展示、手势全部穿透。
    func testIC113BOnlyUndoControlIsHittable() {
        XCTAssertTrue(
            S2CenterIndicatorView.showsUndoControl(
                for: .addedToAlbum(albumName: "旅行")
            ),
            "已加入相簿态必须有撤回钮"
        )
        XCTAssertFalse(
            S2CenterIndicatorView.showsUndoControl(for: .marked),
            "已标记态不得有任何可点元素——手势必须穿透"
        )
        XCTAssertFalse(
            S2CenterIndicatorView.showsUndoControl(
                for: .removed(albumName: "旅行")
            ),
            "撤回后的短提示态不得有任何可点元素——手势必须穿透"
        )
    }

    // IC-113 B：出现/消失参数不变；新增「残影落点后才出指示」的时机常量。
    func testIC113BTransitionParametersMatchCanvas() {
        XCTAssertEqual(
            S2CenterIndicatorResolver.transitionSeconds,
            0.2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2CenterIndicatorResolver.hiddenScale,
            0.9,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            S2CenterIndicatorResolver.removedNoticeSeconds,
            S2CenterIndicatorResolver.transitionSeconds
        )
        // 指示必须**晚于**残影落点才出现（卡内时序）
        XCTAssertGreaterThanOrEqual(
            S2CenterIndicatorResolver.albumIndicatorDelaySeconds,
            S2AlbumAfterimageFlight.durationSeconds,
            "指示不得早于残影落点出现"
        )
        // IC-118 C（④）：内层小方块删除，单层玻璃正圆直接承载图标——
        // 容器高度即圆直径，取值沿用 46，教程步 4 的避让锚点因此不变。
        XCTAssertEqual(S2CenterIndicatorView.containerHeight, 46)
    }

    // IC-113 B：加入相簿成功后登记记录；撤回成功后清掉。
    // 两条加入路径（中胶囊 / 选择器）都登记。
    func testIC113BAlbumAdditionRecordPublishedAndClearedOnRemoval() {
        let album = S2AlbumReference(id: "album-113", name: "旅行")
        let machine = makeMachine(recentAlbum: album)
        XCTAssertNil(machine.lastAlbumAddition)

        // 路径一：中胶囊
        let request = tryUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertTrue(machine.beginRecentAlbumAddition(request))
        XCTAssertTrue(machine.completeRecentAlbumAddition(
            request,
            outcome: .success(alreadyContained: false)
        ))
        let record = tryUnwrap(machine.lastAlbumAddition)
        XCTAssertEqual(record.assetID, request.targetAssetID)
        XCTAssertEqual(record.album, album)

        // 撤回：取请求 → 在途 → 成功即清记录
        let removal = tryUnwrap(machine.makeAlbumRemovalRequest())
        XCTAssertEqual(removal.targetAssetID, record.assetID)
        XCTAssertEqual(removal.album, album)
        XCTAssertTrue(machine.beginAlbumRemoval(removal))
        XCTAssertTrue(machine.isAlbumRemovalInFlight)
        // 在途时不得再取一次撤回请求
        XCTAssertNil(machine.makeAlbumRemovalRequest())
        XCTAssertTrue(machine.completeAlbumRemoval(removal, succeeded: true))
        XCTAssertFalse(machine.isAlbumRemovalInFlight)
        XCTAssertNil(machine.lastAlbumAddition)
    }

    // IC-113 B：撤回失败不清记录（指示应留着让用户重试），并发一次反馈。
    func testIC113BFailedRemovalKeepsRecord() {
        let album = S2AlbumReference(id: "album-113", name: "旅行")
        let machine = makeMachine(recentAlbum: album)
        let request = tryUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertTrue(machine.beginRecentAlbumAddition(request))
        XCTAssertTrue(machine.completeRecentAlbumAddition(
            request,
            outcome: .success(alreadyContained: false)
        ))
        let removal = tryUnwrap(machine.makeAlbumRemovalRequest())
        XCTAssertTrue(machine.beginAlbumRemoval(removal))
        XCTAssertFalse(machine.completeAlbumRemoval(removal, succeeded: false))
        XCTAssertNotNil(
            machine.lastAlbumAddition,
            "撤回失败必须保留记录，否则用户再也点不到撤回"
        )
        XCTAssertNotNil(machine.feedbackEvent)
        // IC-118 D：按张记录同样保留。
        XCTAssertNotNil(
            machine.sessionAlbumAdditionsByAsset[machine.currentAssetID]
        )
    }

    // MARK: - IC-118 D：相簿指示按张记忆（⑤9 ④，会话内口径）

    // IC-118 D：每张各自记住本会话加入的相簿，翻页来回不丢。
    func testIC118DSessionAlbumAdditionsRememberPerAsset() {
        let album = S2AlbumReference(id: "album-118", name: "旅行")
        let machine = makeMachine(recentAlbum: album)
        XCTAssertTrue(machine.sessionAlbumAdditionsByAsset.isEmpty)

        // 当前张（asset-2）加入
        let first = tryUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertTrue(machine.beginRecentAlbumAddition(first))
        XCTAssertTrue(machine.completeRecentAlbumAddition(
            first,
            outcome: .success(alreadyContained: false)
        ))
        XCTAssertEqual(machine.sessionAlbumAdditionsByAsset["asset-2"], album)

        // 翻到 asset-3 再加一张
        XCTAssertTrue(machine.handleNativePageChange(to: 2))
        let second = tryUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertTrue(machine.beginRecentAlbumAddition(second))
        XCTAssertTrue(machine.completeRecentAlbumAddition(
            second,
            outcome: .success(alreadyContained: false)
        ))
        XCTAssertEqual(machine.sessionAlbumAdditionsByAsset["asset-3"], album)

        // 翻回 asset-2：记录仍在，撤回请求跟随当前张
        XCTAssertTrue(machine.handleNativePageChange(to: 1))
        XCTAssertEqual(machine.sessionAlbumAdditionsByAsset["asset-2"], album)
        let removal = tryUnwrap(machine.makeAlbumRemovalRequest())
        XCTAssertEqual(removal.targetAssetID, "asset-2")
        XCTAssertEqual(removal.album, album)
    }

    // IC-118 D：撤回请求按当前张出——本会话没加过的张取不到请求
    // （旧全局口径会把最近一次加入的请求错发到别张）；撤回成功只清该张。
    func testIC118DRemovalFollowsCurrentAssetAndClearsOnlyIt() {
        let album = S2AlbumReference(id: "album-118", name: "旅行")
        let machine = makeMachine(recentAlbum: album)
        let addition = tryUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertTrue(machine.beginRecentAlbumAddition(addition))
        XCTAssertTrue(machine.completeRecentAlbumAddition(
            addition,
            outcome: .success(alreadyContained: false)
        ))

        // asset-3 本会话没加过 → 无撤回请求（全局记录仍存也不给）
        XCTAssertTrue(machine.handleNativePageChange(to: 2))
        XCTAssertNil(machine.makeAlbumRemovalRequest())

        // 翻回撤回：成功后该张记录清空，撤回请求也随之取不到
        XCTAssertTrue(machine.handleNativePageChange(to: 1))
        let removal = tryUnwrap(machine.makeAlbumRemovalRequest())
        XCTAssertTrue(machine.beginAlbumRemoval(removal))
        XCTAssertTrue(machine.completeAlbumRemoval(removal, succeeded: true))
        XCTAssertNil(machine.sessionAlbumAdditionsByAsset["asset-2"])
        XCTAssertNil(machine.makeAlbumRemovalRequest())
    }

    // IC-113 B：协调器把撤回接到服务的 removeAsset 上，成功即从相簿移除。
    func testIC113BCoordinatorRoutesRemovalToService() {
        let album = S2AlbumReference(id: "album-113", name: "旅行")
        let service = FakeAssetActionService(
            albums: [album],
            containedPairs: [FakeAssetActionService.pair(album.id, "asset-2")]
        )
        let machine = makeMachine(recentAlbum: album)
        let request = S2AlbumActionRequest(
            targetAssetID: "asset-2",
            album: album
        )
        XCTAssertTrue(machine.beginAlbumRemoval(request))
        service.removeAsset(
            assetID: request.targetAssetID,
            fromAlbumWithID: request.album.id
        ) { succeeded in
            XCTAssertTrue(succeeded)
        }
        XCTAssertEqual(service.removalRequests.count, 1)
        XCTAssertEqual(
            service.removalRequests.first?.assetID,
            "asset-2"
        )
        XCTAssertEqual(
            service.removalRequests.first?.albumID,
            album.id
        )
        XCTAssertFalse(
            service.containsPair(albumID: album.id, assetID: "asset-2"),
            "移除成功后该资产不应再属于该相簿"
        )
    }

    // MARK: - IC-112 C：教程 v3

    // IC-112 C：六步且顺序不变；新第 5 步是收藏引导，原第 5 步顺延为第 6 步。
    func testIC112CTutorialHasSixStepsInOrder() {
        XCTAssertEqual(S2TutorialStep.allCases.count, 6)
        XCTAssertEqual(
            S2TutorialStep.allCases.map(\.rawValue),
            [1, 2, 3, 4, 5, 6]
        )
        XCTAssertEqual(S2TutorialStep.albumGuide.rawValue, 5)
        XCTAssertEqual(S2TutorialStep.confirmEntry.rawValue, 6)
        // 六步文案互不相同且非空
        let texts = S2TutorialStep.allCases.map(\.text)
        XCTAssertEqual(Set(texts).count, 6)
        for text in texts {
            XCTAssertFalse(text.isEmpty)
        }
    }

    // IC-112 C：第 5 步只被**真实收藏成功**推动；点击任意处不推进。
    func testIC114B3AlbumGuideAdvancesOnPickerOpenThenClose() {
        let tutorial = S2TutorialCoordinator(
            store: S2InMemoryTutorialCompletionStore()
        )
        tutorial.startIfNeeded()
        tutorial.assetDidBecomeMarked(assetID: "asset-2")
        tutorial.acknowledge()
        tutorial.currentAssetDidChange(to: "asset-2")
        tutorial.assetDidBecomeUnmarked(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .albumGuide)

        // 只见到「关」不算——教程刚进步 5 时 sheet 本就是关的
        tutorial.albumPickerVisibilityDidChange(isPresented: false)
        XCTAssertEqual(tutorial.activeStep, .albumGuide)

        // 点击也不推进（等真实交互）
        tutorial.acknowledge()
        XCTAssertEqual(tutorial.activeStep, .albumGuide)

        // 先开
        tutorial.albumPickerVisibilityDidChange(isPresented: true)
        XCTAssertEqual(tutorial.activeStep, .albumGuide)
        XCTAssertTrue(tutorial.didOpenAlbumPickerDuringGuide)

        // 再关 → 进步 6
        tutorial.albumPickerVisibilityDidChange(isPresented: false)
        XCTAssertEqual(tutorial.activeStep, .confirmEntry)
    }

    // IC-114 B3（④ 取定）：教程态**不禁用** sheet 内真实操作——
    // 用户若真加入了相簿，照样推进。
    func testIC114B3RealAlbumJoinAlsoAdvances() {
        let tutorial = S2TutorialCoordinator(
            store: S2InMemoryTutorialCompletionStore()
        )
        tutorial.startIfNeeded()
        tutorial.assetDidBecomeMarked(assetID: "asset-2")
        tutorial.acknowledge()
        tutorial.currentAssetDidChange(to: "asset-2")
        tutorial.assetDidBecomeUnmarked(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .albumGuide)

        tutorial.assetDidJoinAlbum(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .confirmEntry)
    }

    func testIC113CAlbumGuideAdvancesOnlyOnRealAlbumJoin() {
        let tutorial = S2TutorialCoordinator(
            store: S2InMemoryTutorialCompletionStore()
        )
        tutorial.startIfNeeded()
        tutorial.assetDidBecomeMarked(assetID: "asset-2")
        tutorial.acknowledge()
        tutorial.currentAssetDidChange(to: "asset-2")
        tutorial.assetDidBecomeUnmarked(assetID: "asset-2")
        // 第 4 步完成后进入新的第 5 步（收藏引导），而不是直接到确认入口
        XCTAssertEqual(tutorial.activeStep, .albumGuide)
        XCTAssertTrue(S2TutorialStep.albumGuide.waitsForRealGesture)

        // 点击不推进
        for _ in 0..<3 {
            tutorial.acknowledge()
        }
        XCTAssertEqual(tutorial.activeStep, .albumGuide)

        // 真实收藏成功才推进
        tutorial.assetDidJoinAlbum(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .confirmEntry)

        // 第 6 步点击任意处结束
        tutorial.acknowledge()
        XCTAssertNil(tutorial.activeStep)
        XCTAssertEqual(tutorial.outcome, .completed)
    }

    // IC-112 C：提示卡底缘 = 横栏顶缘 − 8，**六步同值**（对齐同一水平线），
    // 且严格高于横栏顶缘——永不遮挡横栏。
    func testIC112CCardBottomAlignsAboveStrip() {
        let safeBottom: CGFloat = 34
        let stripHeight: CGFloat = 30
        let inset = S2TutorialCardLayout.bottomInset(
            safeAreaBottom: safeBottom,
            bottomStripHeight: stripHeight
        )
        // 横栏视觉顶缘距视口底
        let stripVisualTop = S2OverlayLayout.stripBottomFromViewportBottom(
            safeAreaBottom: safeBottom
        ) + stripHeight
        XCTAssertEqual(
            inset - stripVisualTop,
            S2TutorialCardLayout.stripClearance,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S2TutorialCardLayout.stripClearance, 8)
        // 卡底缘比横栏顶缘更高（距视口底更远）⟹ 不压横栏
        XCTAssertGreaterThan(inset, stripVisualTop)
        // 常规机型落值：110 + 30 + 8 = 148
        XCTAssertEqual(inset, 148, accuracy: 0.000_001)
    }

    // IC-112 C：第 5 步聚光套**左下 ♡ 圆钮**，与 chrome 底排同一套表达式；
    // IC-114 B3（④）：步 5 改为**恒定圈住右下角相簿选择器圆钮、无箭头**。
    // IC-113 C 的「中位为空才套选择器」分支随本卡废止。
    func testIC114B3AlbumGuideSpotlightAlwaysTargetsPickerCircle() {
        let viewport = CGSize(width: 393, height: 852)
        let insets = S2OverlaySafeAreaInsets(
            top: 59,
            leading: 0,
            bottom: 34,
            trailing: 0
        )
        let stripMetrics = makeMachine().parameters.bottomStripMetrics

        func rect(_ step: S2TutorialStep, markedIndex: Int?) -> CGRect {
            S2TutorialSpotlight.targetRect(
                step: step,
                viewportSize: viewport,
                safeAreaInsets: insets,
                photoSize: CGSize(width: 393, height: 562),
                photoCenterY: 409,
                bottomStripHeight: 30,
                stripMetrics: stripMetrics,
                currentIndex: 1,
                markedIndex: markedIndex
            )
        }

        // 有无最近相簿都圈同一个目标——不再分流
        let withCapsule = rect(.albumGuide, markedIndex: 0)
        let withoutCapsule = rect(.albumGuide, markedIndex: nil)
        XCTAssertEqual(
            withCapsule,
            withoutCapsule,
            "步 5 聚光恒定圈右下圆钮，不随中位状态变化"
        )

        // 正方（圆钮）、居右下
        XCTAssertEqual(
            withCapsule.width,
            withCapsule.height,
            accuracy: 0.000_001,
            "选择器是圆钮，聚光应为正方"
        )
        XCTAssertGreaterThan(withCapsule.midX, viewport.width / 2, "在右侧")
        XCTAssertGreaterThan(
            withCapsule.midY,
            viewport.height / 2,
            "在下方"
        )

        // 与右上确认入口不是同一个目标
        XCTAssertNotEqual(withCapsule, rect(.confirmEntry, markedIndex: nil))

        // **无箭头**
        XCTAssertNil(
            S2TutorialStep.albumGuide.gestureDirection,
            "步 5 不给方向图示（④：无箭头）"
        )

        // 仍用正圆挖孔
        XCTAssertEqual(
            S2TutorialSpotlight.cornerRadius(for: .albumGuide),
            S2TutorialSpotlight.circleCornerRadius
        )
    }

    // IC-114 B1：步 2 聚光圈的是**被标记那张**的格位，不是当前张。
    // 上滑标记成功后产品自动翻下一张，被标记的是前一张（H50 实测套错张）。
    func testIC114B1StripSpotlightTargetsMarkedItemNotCurrent() {
        let viewport = CGSize(width: 393, height: 852)
        let insets = S2OverlaySafeAreaInsets(
            top: 59,
            leading: 0,
            bottom: 34,
            trailing: 0
        )
        let stripMetrics = makeMachine().parameters.bottomStripMetrics

        func rect(markedIndex: Int?) -> CGRect {
            S2TutorialSpotlight.targetRect(
                step: .seeStripMark,
                viewportSize: viewport,
                safeAreaInsets: insets,
                photoSize: CGSize(width: 393, height: 562),
                photoCenterY: 409,
                bottomStripHeight: 30,
                stripMetrics: stripMetrics,
                currentIndex: 1,
                markedIndex: markedIndex
            )
        }

        // 被标记的是前一张（下标 0），当前张是 1
        let marked = rect(markedIndex: 0)
        let current = rect(markedIndex: nil)
        XCTAssertNotEqual(
            marked,
            current,
            "圈被标记那张与圈当前张必须落在不同格位"
        )
        // 前一张在当前张**左侧**
        XCTAssertLessThan(
            marked.midX,
            current.midX,
            "被标记的是前一张，应在当前张左边"
        )
        // 竖直位置相同——同一条横栏
        XCTAssertEqual(marked.midY, current.midY, accuracy: 0.000_001)
        // 未知时退回当前张
        XCTAssertEqual(rect(markedIndex: 1), current)
    }

    // IC-113 C 步 2：聚光收紧到**那一枚缩略图**并放大 1.6 倍，不再套整条横栏。
    func testIC113CStripSpotlightTightensToSingleItem() {
        let viewport = CGSize(width: 393, height: 852)
        let insets = S2OverlaySafeAreaInsets(
            top: 59,
            leading: 0,
            bottom: 34,
            trailing: 0
        )
        let rect = S2TutorialSpotlight.targetRect(
            step: .seeStripMark,
            viewportSize: viewport,
            safeAreaInsets: insets,
            photoSize: CGSize(width: 393, height: 562),
            photoCenterY: 409,
            bottomStripHeight: 30,
            stripMetrics: makeMachine().parameters.bottomStripMetrics,
            currentIndex: 1,
            markedIndex: nil
        )
        // 远窄于整条横栏——这正是「收紧」
        XCTAssertLessThan(
            rect.width,
            viewport.width / 2,
            "聚光不该再横跨整条横栏"
        )
        // 横栏把当前张摆在视口水平中心
        XCTAssertEqual(rect.midX, viewport.width / 2, accuracy: 1)
        XCTAssertEqual(
            S2TutorialSpotlight.stripItemMagnification,
            1.6,
            accuracy: 0.000_001
        )
        // 放大助手围绕中心：中心不动、尺寸按倍数走
        let base = CGRect(x: 10, y: 20, width: 30, height: 40)
        let scaled = S2TutorialSpotlight.magnified(base, by: 2)
        XCTAssertEqual(scaled.midX, base.midX, accuracy: 0.000_001)
        XCTAssertEqual(scaled.midY, base.midY, accuracy: 0.000_001)
        XCTAssertEqual(scaled.width, 60, accuracy: 0.000_001)
        XCTAssertEqual(scaled.height, 80, accuracy: 0.000_001)
    }

    // IC-113 C 步 4：图示单元整体落在中央指示块**下方**，全程不穿过它。
    func testIC113CHintAvoidsCenterIndicatorOnStepFour() {
        let photoCenterY: CGFloat = 409
        let spotlight = CGRect(x: 0, y: 148, width: 393, height: 522)
        let indicatorBottom = photoCenterY +
            S2CenterIndicatorView.containerHeight / 2

        let top = S2TutorialHintAnchor.unitTop(
            step: .swipeDownToCancel,
            spotlight: spotlight,
            photoCenterY: photoCenterY
        )
        XCTAssertGreaterThanOrEqual(
            top,
            indicatorBottom,
            "步 4 的图示单元顶缘必须在指示块底缘之下，否则会穿过它"
        )
        XCTAssertEqual(
            top - indicatorBottom,
            S2TutorialHintAnchor.indicatorClearance,
            accuracy: 0.000_001
        )
        // 方向仍向下——自指示块下方向下平移，不会回头穿过
        XCTAssertEqual(
            S2TutorialStep.swipeDownToCancel.gestureDirection,
            .down
        )
        // 其余步骤仍以聚光中心为锚
        let other = S2TutorialHintAnchor.point(
            step: .swipeUpToMark,
            spotlight: spotlight,
            photoCenterY: photoCenterY
        )
        XCTAssertEqual(other.x, spotlight.midX, accuracy: 0.000_001)
        XCTAssertEqual(other.y, spotlight.midY, accuracy: 0.000_001)
    }

    // IC-112 C：手势图示按第三轮画布放大，循环周期不变。
    func testIC112CGestureHintEnlarged() {
        XCTAssertEqual(S2TutorialGestureHint.ringDiameter, 38)
        XCTAssertEqual(S2TutorialGestureHint.ringLineWidth, 2)
        XCTAssertEqual(S2TutorialGestureHint.coreDiameter, 21)
        XCTAssertEqual(S2TutorialGestureHint.arrowLength, 64)
        XCTAssertEqual(
            S2TutorialGestureHint.arrowLineWidth,
            2.6,
            accuracy: 0.000_001
        )
        // 循环 0.9s/次不变、位移 40pt 不变
        XCTAssertEqual(
            S2TutorialGestureHint.cycleSeconds,
            0.9,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S2TutorialGestureHint.travel, 40)
        // 芯必须小于环
        XCTAssertLessThan(
            S2TutorialGestureHint.coreDiameter,
            S2TutorialGestureHint.ringDiameter
        )
        // 第 5 步给向下箭头（指向左下角的 ♡）
        // IC-113 C：圆与箭头收紧成一个单元，并统一加投影保证白底可辨。
        XCTAssertEqual(S2TutorialGestureHint.unitSpacing, 2)
        XCTAssertLessThan(
            S2TutorialGestureHint.unitSpacing,
            10,
            "间距过大会读成两个各动各的物件——H49 的观感问题就在这里"
        )
        XCTAssertEqual(
            S2TutorialGestureHint.contrastShadowOpacity,
            0.35,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(S2TutorialGestureHint.contrastShadowRadius, 0)
        XCTAssertEqual(
            S2TutorialGestureHint.unitHeight,
            S2TutorialGestureHint.arrowLength +
                S2TutorialGestureHint.unitSpacing +
                S2TutorialGestureHint.ringDiameter,
            accuracy: 0.000_001
        )
        // IC-114 B3：步 5 改为无箭头
        XCTAssertNil(S2TutorialStep.albumGuide.gestureDirection)
        // 第 6 步只指向、无循环手势图示
        XCTAssertNil(S2TutorialStep.confirmEntry.gestureDirection)
    }

    // MARK: - IC-111 D：教程动效

    // IC-111 D：聚光挖孔按步套目标——步 1/3/4 套主图、步 5 套右上垃圾桶圆钮；
    // 两者与 chrome 自己的推导式同源。
    // IC-113 C 起步 2 不再套整条横栏，改**收紧到单枚缩略图并放大**，
    // 故这一步的期望改按新推导式写（见下）。
    func testIC111DSpotlightTargetsPerStep() {
        let viewport = CGSize(width: 393, height: 852)
        let insets = S2OverlaySafeAreaInsets(
            top: 59,
            leading: 0,
            bottom: 34,
            trailing: 0
        )
        let photoSize = CGSize(width: 393, height: 562)
        let photoCenterY: CGFloat = 409
        let stripHeight: CGFloat = 30

        let stripMetrics = makeMachine().parameters.bottomStripMetrics

        func rect(_ step: S2TutorialStep) -> CGRect {
            S2TutorialSpotlight.targetRect(
                step: step,
                viewportSize: viewport,
                safeAreaInsets: insets,
                photoSize: photoSize,
                photoCenterY: photoCenterY,
                bottomStripHeight: stripHeight,
                stripMetrics: stripMetrics,
                currentIndex: 1,
                markedIndex: nil
            )
        }

        // 步 1/3/4 同套主图，三者逐值相同
        let photoRect = rect(.swipeUpToMark)
        XCTAssertEqual(rect(.returnToMarked), photoRect)
        XCTAssertEqual(rect(.swipeDownToCancel), photoRect)
        XCTAssertEqual(photoRect.midY, photoCenterY, accuracy: 0.000_001)
        XCTAssertEqual(
            photoRect.height,
            photoSize.height + 2 * S2TutorialSpotlight.padding,
            accuracy: 0.000_001
        )

        // IC-113 C 步 2：收紧到**单枚缩略图**并以中心为基准放大。
        // 期望值全部由推导式算出——格位取横栏渲染同一套
        // `S2BottomStripLayout.frame`，倍数取 `stripItemMagnification`，
        // 不写字面量。
        //
        // 注意：步 2 分支**不叠 padding**（放大本身已取代它），
        // 与套主图/圆钮的几步不同。
        let stripRect = rect(.seeStripMark)
        let stripLayout = S2BottomStripLayout(metrics: stripMetrics)
        let stripWidth = viewport.width - insets.leading - insets.trailing
        let stripOriginY = viewport.height -
            S2OverlayLayout.stripBottomFromViewportBottom(
                safeAreaBottom: insets.bottom
            ) - stripHeight
        let cell = stripLayout.frame(
            at: 1,
            currentIndex: 1,
            expansion: 1,
            contentX: stripLayout.contentCenterX(of: 1),
            viewportSize: CGSize(width: stripWidth, height: stripHeight)
        )

        // 尺寸：按倍数放大单枚格位
        XCTAssertEqual(
            stripRect.width,
            cell.width * S2TutorialSpotlight.stripItemMagnification,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            stripRect.height,
            cell.height * S2TutorialSpotlight.stripItemMagnification,
            accuracy: 0.000_001
        )
        // 摆放：中心与该格位中心重合（尺寸断言不等于摆放断言，陷阱 13）
        XCTAssertEqual(
            stripRect.midX,
            insets.leading + cell.midX,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            stripRect.midY,
            stripOriginY + cell.midY,
            accuracy: 0.000_001
        )
        // 「收紧」本身：确实比整条横栏窄
        XCTAssertLessThan(
            stripRect.width,
            stripWidth,
            "步 2 聚光应收紧到单枚缩略图，不再横跨整条横栏"
        )
        // 旧行为（套整条横栏 + padding）已被 IC-113 C 正当作废
        XCTAssertNotEqual(
            stripRect.height,
            stripHeight + 2 * S2TutorialSpotlight.padding,
            accuracy: 0.000_001
        )

        // 步 5 套右上圆钮：与 topElementFrames 的右槽同源
        let trashRect = rect(.confirmEntry)
        let frames = S2OverlayLayout.topElementFrames(
            in: CGRect(
                x: 0,
                y: insets.top,
                width: viewport.width,
                height: S2OverlayLayout.topBarHeight
            )
        )
        XCTAssertEqual(trashRect.midX, frames[2].midX, accuracy: 0.000_001)
        XCTAssertEqual(trashRect.midY, frames[2].midY, accuracy: 0.000_001)
        // 圆钮那一步用正圆挖孔
        XCTAssertGreaterThan(
            S2TutorialSpotlight.cornerRadius(for: .confirmEntry),
            S2TutorialSpotlight.cornerRadius(for: .swipeUpToMark)
        )

        // 三个目标互不相同——挖孔确实在步骤间移动
        XCTAssertNotEqual(photoRect, stripRect)
        XCTAssertNotEqual(stripRect, trashRect)
        XCTAssertNotEqual(photoRect, trashRect)
    }

    // IC-111 D：手势图示只出现在有手势的步；方向与该步语义一致。
    func testIC111DGestureDirectionPerStep() {
        XCTAssertEqual(S2TutorialStep.swipeUpToMark.gestureDirection, .up)
        XCTAssertEqual(S2TutorialStep.swipeDownToCancel.gestureDirection, .down)
        // 标记会前进一张，故「回到刚才那张」是向右拖回
        XCTAssertEqual(S2TutorialStep.returnToMarked.gestureDirection, .right)
        // 观察/点击步没有手势图示
        XCTAssertNil(S2TutorialStep.seeStripMark.gestureDirection)
        XCTAssertNil(S2TutorialStep.confirmEntry.gestureDirection)

        // 位移向量沿方向、幅度为卡内的 40pt
        XCTAssertEqual(
            S2TutorialGestureDirection.up.offset.height,
            -S2TutorialGestureHint.travel,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2TutorialGestureDirection.down.offset.height,
            S2TutorialGestureHint.travel,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2TutorialGestureDirection.right.offset.width,
            S2TutorialGestureHint.travel,
            accuracy: 0.000_001
        )
    }

    // IC-111 D：动效参数落在卡内取值——遮罩 55%、触点圆 Ø26 环 + Ø14 实心、
    // 循环 0.9s、位移 40pt。
    func testIC111DAnimationParametersMatchCard() {
        XCTAssertEqual(S2TutorialOverlay.dimOpacity, 0.55, accuracy: 0.000_001)
        // IC-112 C：触点圆按第三轮画布放大（原 Ø26 / Ø14）。
        XCTAssertEqual(S2TutorialGestureHint.ringDiameter, 38)
        XCTAssertEqual(S2TutorialGestureHint.coreDiameter, 21)
        XCTAssertLessThan(
            S2TutorialGestureHint.coreDiameter,
            S2TutorialGestureHint.ringDiameter
        )
        XCTAssertEqual(
            S2TutorialGestureHint.cycleSeconds,
            0.9,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S2TutorialGestureHint.travel, 40)
    }

    // IC-111 D：步进逻辑沿用 IC-110 D，一字未改——本卡只重做表现层。
    // 这里复核「等真实手势的三步不接受点击推进」这条不变量仍然成立。
    func testIC111DStepAdvanceLogicUnchanged() {
        let tutorial = S2TutorialCoordinator(
            store: S2InMemoryTutorialCompletionStore()
        )
        tutorial.startIfNeeded()
        XCTAssertEqual(tutorial.activeStep, .swipeUpToMark)
        for _ in 0..<3 {
            tutorial.acknowledge()
        }
        XCTAssertEqual(
            tutorial.activeStep,
            .swipeUpToMark,
            "表现层重做不得改变步进条件"
        )
        tutorial.assetDidBecomeMarked(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .seeStripMark)
        // 步 2 不等手势，点击即进
        tutorial.acknowledge()
        XCTAssertEqual(tutorial.activeStep, .returnToMarked)
    }

    // MARK: - IC-110 D：首次引导教程
    //
    // 以下均为**夹具驱动**的状态机断言，真机走查由 H47 兜底（陷阱 1）。

    // IC-110 D：顺序推进——每一步只被它该等的那个真实事件推动。
    // IC-112 C：由五步扩为六步（第 4 步之后插入收藏引导）。
    func testIC110DTutorialAdvancesThroughAllStepsInOrder() {
        let store = S2InMemoryTutorialCompletionStore()
        let tutorial = S2TutorialCoordinator(store: store)

        tutorial.startIfNeeded()
        XCTAssertEqual(tutorial.activeStep, .swipeUpToMark)

        // 第 1 步只认「标记」；点击无效（等真实手势）。
        tutorial.acknowledge()
        XCTAssertEqual(tutorial.activeStep, .swipeUpToMark)
        tutorial.assetDidBecomeMarked(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .seeStripMark)

        // 第 2 步不等手势：点击（或 2 秒计时）推进。
        tutorial.acknowledge()
        XCTAssertEqual(tutorial.activeStep, .returnToMarked)

        // 第 3 步只认「翻回刚标记那张」；翻到别张无效。
        tutorial.currentAssetDidChange(to: "asset-3")
        XCTAssertEqual(tutorial.activeStep, .returnToMarked)
        tutorial.currentAssetDidChange(to: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .swipeDownToCancel)

        // 第 4 步只认「取消刚标记那张」；取消别张无效。
        tutorial.assetDidBecomeUnmarked(assetID: "asset-9")
        XCTAssertEqual(tutorial.activeStep, .swipeDownToCancel)
        tutorial.assetDidBecomeUnmarked(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .albumGuide)

        // IC-112 C 第 5 步只认「真实收藏成功」；点击无效。
        tutorial.acknowledge()
        XCTAssertEqual(tutorial.activeStep, .albumGuide)
        tutorial.assetDidJoinAlbum(assetID: "asset-2")
        XCTAssertEqual(tutorial.activeStep, .confirmEntry)

        // 第 6 步点击任意处结束——完成，并落盘。
        XCTAssertFalse(store.completed)
        tutorial.acknowledge()
        XCTAssertNil(tutorial.activeStep)
        XCTAssertEqual(tutorial.outcome, .completed)
        XCTAssertTrue(store.completed)
    }

    // IC-110 D：等真实手势的三步（1/3/4）不接受点击推进——
    // 这正是「不旁路手势分派」的形式保证。
    func testIC110DGestureStepsIgnoreTapAdvance() {
        XCTAssertTrue(S2TutorialStep.swipeUpToMark.waitsForRealGesture)
        XCTAssertTrue(S2TutorialStep.returnToMarked.waitsForRealGesture)
        XCTAssertTrue(S2TutorialStep.swipeDownToCancel.waitsForRealGesture)
        XCTAssertFalse(S2TutorialStep.seeStripMark.waitsForRealGesture)
        XCTAssertFalse(S2TutorialStep.confirmEntry.waitsForRealGesture)

        let tutorial = S2TutorialCoordinator(
            store: S2InMemoryTutorialCompletionStore()
        )
        tutorial.startIfNeeded()
        for _ in 0..<5 {
            tutorial.acknowledge()
        }
        XCTAssertEqual(
            tutorial.activeStep,
            .swipeUpToMark,
            "第 1 步必须一直等真实上滑，点击不得推进"
        )
    }

    // IC-110 D：跳过与中途离开都算走完，落盘后不再复现。
    func testIC110DSkipAndLeavePersistCompletion() {
        let store = S2InMemoryTutorialCompletionStore()
        let tutorial = S2TutorialCoordinator(store: store)
        tutorial.startIfNeeded()
        tutorial.skip()
        XCTAssertNil(tutorial.activeStep)
        XCTAssertEqual(tutorial.outcome, .skipped)
        XCTAssertTrue(store.completed)

        // 已落盘：同一实例再 start 不复现
        tutorial.startIfNeeded()
        XCTAssertNil(tutorial.activeStep)

        // 新实例读到同一存储，同样不复现
        let reopened = S2TutorialCoordinator(store: store)
        reopened.startIfNeeded()
        XCTAssertNil(reopened.activeStep)

        // 中途离开 S2 视为跳过
        let leaveStore = S2InMemoryTutorialCompletionStore()
        let leaving = S2TutorialCoordinator(store: leaveStore)
        leaving.startIfNeeded()
        leaving.assetDidBecomeMarked(assetID: "asset-2")
        XCTAssertEqual(leaving.activeStep, .seeStripMark)
        leaving.leaveScreen()
        XCTAssertNil(leaving.activeStep)
        XCTAssertEqual(leaving.outcome, .skipped)
        XCTAssertTrue(leaveStore.completed)
    }

    // IC-110 D：标定面板「重看教程」——清持久化并当场从第 1 步重放。
    func testIC110DReplayResetsPersistenceAndRestarts() {
        let store = S2InMemoryTutorialCompletionStore()
        store.completed = true
        let tutorial = S2TutorialCoordinator(store: store)

        // 已完成过：首次进入不放
        tutorial.startIfNeeded()
        XCTAssertNil(tutorial.activeStep)

        tutorial.replay()
        XCTAssertEqual(tutorial.activeStep, .swipeUpToMark)
        XCTAssertNil(tutorial.outcome)
        XCTAssertFalse(store.completed, "重看必须先清掉已完成标记")
        XCTAssertEqual(store.resetCount, 1)
    }

    // IC-110 D：未完成时才放；步骤原始值与文案一一对应且互不相同。
    // IC-112 C：由五步扩为六步（新增收藏引导）。
    func testIC110DStepCatalogIsWellFormed() {
        XCTAssertEqual(S2TutorialStep.allCases.count, 6)
        XCTAssertEqual(
            S2TutorialStep.allCases.map(\.rawValue),
            [1, 2, 3, 4, 5, 6]
        )
        let texts = S2TutorialStep.allCases.map(\.text)
        XCTAssertEqual(
            Set(texts).count,
            6,
            "六步文案必须互不相同"
        )
        for text in texts {
            XCTAssertFalse(text.isEmpty)
        }
        XCTAssertEqual(S2TutorialCoordinator.autoAdvanceSeconds, 2)
    }
}

/// IC-110 D：教程持久化的测试用内存实现，与 `UserDefaults` 实现遵循同一协议。
final class S2InMemoryTutorialCompletionStore: S2TutorialCompletionStoring {
    var completed = false
    private(set) var resetCount = 0

    func isCompleted() -> Bool {
        completed
    }

    func markCompleted() {
        completed = true
    }

    func reset() {
        resetCount += 1
        completed = false
    }
}

/// 测试用假写入服务：记录请求、延迟完成；加入相册沿用生产的 `PhotoAlbumAdditionPlan`，
/// 已包含时不计写入。完成回调在调用方线程（主线程）同步触发。
final class FakeAssetActionService: PhotoAssetActionServicing {
    /// IC-113 B：移除请求记录与结果开关。
    var removalRequests: [AdditionRequest] = []
    var removalSucceeds = true
    /// IC-114 C：新建相簿的请求记录与结果开关。
    var creationRequests: [String] = []
    var creationSucceeds = true
    private(set) var createdAlbums: [S2AlbumReference] = []

    struct AdditionRequest: Equatable {
        let assetID: String
        let albumID: String
    }

    /// IC-114 C：新建相簿会并入，故由 `let` 改 `var`。
    private var albums: [S2AlbumReference]
    /// IC-113 B：移除会改变成员关系，故由 `let` 改 `var`。
    private var containedPairs: Set<String>
    private(set) var favoriteRequests: [String] = []
    private(set) var additionRequests: [AdditionRequest] = []
    private(set) var albumExistsQueries: [String] = []
    private(set) var writeCount = 0
    private var pendingFavorites: [(Bool) -> Void] = []
    private(set) var pendingAdditions: [(S2AlbumAdditionOutcome) -> Void] = []

    init(
        albums: [S2AlbumReference],
        containedPairs: Set<String> = []
    ) {
        self.albums = albums
        self.containedPairs = containedPairs
    }

    static func pair(_ albumID: String, _ assetID: String) -> String {
        "\(albumID)|\(assetID)"
    }

    /// IC-113 B：断言用的成员关系查询。
    func containsPair(albumID: String, assetID: String) -> Bool {
        containedPairs.contains(Self.pair(albumID, assetID))
    }

    func toggleFavorite(
        assetID: String,
        completion: @escaping (Bool) -> Void
    ) {
        favoriteRequests.append(assetID)
        pendingFavorites.append(completion)
    }

    /// IC-114 C：新建相簿。记录请求并按 `creationSucceeds` 回结果；
    /// 成功时把新相簿并入 `albums`，与真实语义一致。
    func createAlbum(
        named name: String,
        completion: @escaping (S2AlbumReference?) -> Void
    ) {
        creationRequests.append(name)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard creationSucceeds, !trimmed.isEmpty else {
            completion(nil)
            return
        }
        let album = S2AlbumReference(
            id: "created-\(trimmed)",
            name: trimmed
        )
        createdAlbums.append(album)
        albums.append(album)
        completion(album)
    }

    /// IC-114 C：列表项。数量取已登记的成员对数，键图一律 nil（测试无需真图）。
    func userAlbumItems() -> [S2AlbumListItem] {
        userAlbums().map { album in
            S2AlbumListItem(
                album: album,
                assetCount: containedPairs.filter {
                    $0.hasPrefix("\(album.id)|")
                }.count,
                keyAssetID: nil
            )
        }
    }

    /// IC-113 B：从相簿移除。记录请求并按 `removalSucceeds` 回结果；
    /// 成功时把该对从 `containedPairs` 里去掉，与真实语义一致。
    func removeAsset(
        assetID: String,
        fromAlbumWithID albumID: String,
        completion: @escaping (Bool) -> Void
    ) {
        removalRequests.append(
            AdditionRequest(assetID: assetID, albumID: albumID)
        )
        if removalSucceeds {
            containedPairs.remove(Self.pair(albumID, assetID))
        }
        completion(removalSucceeds)
    }

    func addAsset(
        assetID: String,
        toAlbumWithID albumID: String,
        completion: @escaping (S2AlbumAdditionOutcome) -> Void
    ) {
        additionRequests.append(
            AdditionRequest(assetID: assetID, albumID: albumID)
        )
        let plan = PhotoAlbumAdditionPlan.make(
            albumExists: albums.contains { $0.id == albumID },
            assetExists: !assetID.isEmpty,
            alreadyContained: containedPairs.contains(
                Self.pair(albumID, assetID)
            )
        )
        switch plan {
        case .albumUnavailable:
            completion(.albumUnavailable)
        case .assetUnavailable:
            completion(.failure)
        case .alreadyContained:
            completion(.success(alreadyContained: true))
        case .write:
            writeCount += 1
            pendingAdditions.append(completion)
        }
    }

    func userAlbums() -> [S2AlbumReference] {
        albums
    }

    func albumExists(id: String) -> Bool {
        albumExistsQueries.append(id)
        return albums.contains { $0.id == id }
    }

    func completePendingFavorite(succeeded: Bool) {
        guard !pendingFavorites.isEmpty else {
            return XCTFail("没有进行中的收藏写入")
        }
        pendingFavorites.removeFirst()(succeeded)
    }

    func completePendingAddition(with outcome: S2AlbumAdditionOutcome) {
        guard !pendingAdditions.isEmpty else {
            return XCTFail("没有进行中的相册写入")
        }
        pendingAdditions.removeFirst()(outcome)
    }
}

/// 测试用内存实现：与 `UserDefaults` 实现遵循同一协议，供协调器断言注入。
final class S2InMemoryRecentAlbumStore: S2RecentAlbumStoring {
    private(set) var stored: S2AlbumReference?
    private(set) var saveCount = 0

    init(initial: S2AlbumReference? = nil) {
        stored = initial
    }

    func load() -> S2AlbumReference? {
        stored
    }

    func save(_ album: S2AlbumReference?) {
        saveCount += 1
        stored = album
    }
}
