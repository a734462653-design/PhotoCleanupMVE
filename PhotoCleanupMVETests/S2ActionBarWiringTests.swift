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
            albums: albums,
            actions: S2AlbumPickerActions(
                select: { selected.append($0) },
                cancel: { cancelled += 1 }
            )
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
        XCTAssertEqual(S2ChromePillMetrics.subtitleOpacity, 0.62, accuracy: 0.000_001)
        XCTAssertEqual(S2ChromePillMetrics.bottomCapsuleIconPointSize, 17)
        XCTAssertEqual(S2ChromePillMetrics.bottomCapsuleTextFontSize, 15)
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

    // MARK: - IC-111 B：标记残影飞入右上垃圾桶

    // IC-111 B：飞行参数落在卡内区间——总时长 300–340ms、
    // scale 1 → 0.18、opacity 0.85 → 0。
    func testIC111BFlightParametersMatchCard() {
        XCTAssertGreaterThanOrEqual(
            S2MarkAfterimageFlight.durationSeconds,
            0.30
        )
        XCTAssertLessThanOrEqual(
            S2MarkAfterimageFlight.durationSeconds,
            0.34
        )
        XCTAssertEqual(S2MarkAfterimageFlight.startScale, 1)
        XCTAssertEqual(S2MarkAfterimageFlight.endScale, 0.18)
        XCTAssertEqual(S2MarkAfterimageFlight.startOpacity, 0.85)
        XCTAssertEqual(S2MarkAfterimageFlight.endOpacity, 0)
        XCTAssertLessThan(
            S2MarkAfterimageFlight.endScale,
            S2MarkAfterimageFlight.startScale,
            "必须是缩小"
        )
    }

    // IC-111 B：落点 = 右上垃圾桶圆钮中心，且与 chrome 渲染共用
    // topElementFrames——换句话说，改了 chrome 几何，落点自动跟着走。
    func testIC111BTrashCenterSharesChromeDerivation() {
        let viewport = CGSize(width: 393, height: 852)
        let safeTop: CGFloat = 59
        let center = S2MarkAfterimageFlight.trashCenter(
            viewportSize: viewport,
            safeAreaTop: safeTop
        )
        let frames = S2OverlayLayout.topElementFrames(
            in: CGRect(
                x: 0,
                y: safeTop,
                width: viewport.width,
                height: S2OverlayLayout.topBarHeight
            )
        )
        XCTAssertEqual(center.x, frames[2].midX, accuracy: 0.000_001)
        XCTAssertEqual(center.y, frames[2].midY, accuracy: 0.000_001)
        // 画布落值：右圆钮贴 16 边距、Ø44 ⟹ 中心 x = 393 − 16 − 22 = 355
        XCTAssertEqual(center.x, 355, accuracy: 0.000_001)
        // 中心 y = 安全区顶 59 + 上留白 3 + 22 = 84
        XCTAssertEqual(center.y, 84, accuracy: 0.000_001)
    }

    // IC-111 B：弧线端点恒等，且控制点在**右外侧、起点高度**——
    // 由此得「先横后纵」的甩入感。
    func testIC111BFlightIsRightSideQuadraticWithExactEndpoints() {
        let from = CGPoint(x: 196, y: 430)
        let to = CGPoint(x: 355, y: 84)
        let photoMaxX: CGFloat = 360

        let start = S2MarkAfterimageFlight.point(
            from: from, to: to, photoMaxX: photoMaxX, progress: 0
        )
        XCTAssertEqual(start.x, from.x, accuracy: 0.000_001)
        XCTAssertEqual(start.y, from.y, accuracy: 0.000_001)
        let end = S2MarkAfterimageFlight.point(
            from: from, to: to, photoMaxX: photoMaxX, progress: 1
        )
        XCTAssertEqual(end.x, to.x, accuracy: 0.000_001)
        XCTAssertEqual(end.y, to.y, accuracy: 0.000_001)

        // 控制点：x 推到 max(落点, 主图右缘) 之外，y 取起点高度
        let control = S2MarkAfterimageFlight.controlPoint(
            from: from, to: to, photoMaxX: photoMaxX
        )
        XCTAssertEqual(control.y, from.y, accuracy: 0.000_001)
        XCTAssertGreaterThan(control.x, to.x)
        XCTAssertGreaterThan(control.x, photoMaxX)

        // 先横后纵：早段几乎只走横向，纵向位移占比很小
        let early = S2MarkAfterimageFlight.point(
            from: from, to: to, photoMaxX: photoMaxX, progress: 0.2
        )
        let horizontal = abs(early.x - from.x)
        let vertical = abs(early.y - from.y)
        XCTAssertGreaterThan(
            horizontal,
            vertical,
            "早段应以横向甩出为主，否则不是「先横后纵」"
        )

        // 曲线整体鼓向右外侧：中点比弦中点更靠右
        let mid = S2MarkAfterimageFlight.point(
            from: from, to: to, photoMaxX: photoMaxX, progress: 0.5
        )
        XCTAssertGreaterThan(mid.x, (from.x + to.x) / 2)

        // 越界钳制
        XCTAssertEqual(
            S2MarkAfterimageFlight.point(
                from: from, to: to, photoMaxX: photoMaxX, progress: -1
            ).x,
            from.x,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2MarkAfterimageFlight.point(
                from: from, to: to, photoMaxX: photoMaxX, progress: 2
            ).x,
            to.x,
            accuracy: 0.000_001
        )
    }

    // IC-111 B：协调器只做在途计数与落点通知；允许多枚并发，无上限。
    func testIC111BCoordinatorTracksConcurrentFlightsAndLandings() {
        let coordinator = S2MarkAfterimageCoordinator()
        XCTAssertEqual(coordinator.inFlightCount, 0)
        XCTAssertEqual(coordinator.landedTick, 0)

        // 连续标记 5 张：五枚同时在途，互不阻塞、不设上限
        for _ in 0..<5 {
            coordinator.willLaunch()
        }
        XCTAssertEqual(coordinator.inFlightCount, 5)
        XCTAssertEqual(coordinator.landedTick, 0)

        coordinator.didLand()
        XCTAssertEqual(coordinator.inFlightCount, 4)
        XCTAssertEqual(coordinator.landedTick, 1)

        for _ in 0..<4 {
            coordinator.didLand()
        }
        XCTAssertEqual(coordinator.inFlightCount, 0)
        XCTAssertEqual(coordinator.landedTick, 5)

        // 多余的落点通知不把在途数压成负数
        coordinator.didLand()
        XCTAssertEqual(coordinator.inFlightCount, 0)
        XCTAssertEqual(coordinator.landedTick, 6)
    }

    // MARK: - IC-111 C：加入相簿残影飞入底部中胶囊

    // IC-111 C：飞行参数落在卡内区间——280–320ms、scale 1 → 0.15、
    // opacity 0.85 → 0；且与 B 共用同一套参数形状。
    func testIC111CAlbumFlightParametersMatchCard() {
        XCTAssertGreaterThanOrEqual(
            S2AlbumAfterimageFlight.durationSeconds,
            0.28
        )
        XCTAssertLessThanOrEqual(
            S2AlbumAfterimageFlight.durationSeconds,
            0.32
        )
        XCTAssertEqual(S2AlbumAfterimageFlight.endScale, 0.15)
        XCTAssertEqual(S2AlbumAfterimageFlight.startOpacity, 0.85)
        XCTAssertEqual(S2AlbumAfterimageFlight.endOpacity, 0)
        // 入场参数（④）：120ms、上浮 8pt
        XCTAssertEqual(
            S2AlbumCapsuleEntrance.durationSeconds,
            0.12,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S2AlbumCapsuleEntrance.rise, 8)
    }

    // IC-111 C：路径是**向下**弧线——曲线中点低于弦中点（屏幕坐标 y 更大），
    // 与 B 的右鼓弧线方向不同。端点恒等、越界钳制。
    func testIC111CAlbumFlightIsDownwardArc() {
        let from = CGPoint(x: 196, y: 420)
        let to = CGPoint(x: 196, y: 788)

        let start = S2AlbumAfterimageFlight.point(
            from: from, to: to, progress: 0
        )
        XCTAssertEqual(start.y, from.y, accuracy: 0.000_001)
        let end = S2AlbumAfterimageFlight.point(
            from: from, to: to, progress: 1
        )
        XCTAssertEqual(end.y, to.y, accuracy: 0.000_001)

        let chordMid = CGPoint(
            x: (from.x + to.x) / 2,
            y: (from.y + to.y) / 2
        )
        let control = S2AlbumAfterimageFlight.controlPoint(
            from: from, to: to
        )
        XCTAssertGreaterThan(
            control.y,
            chordMid.y,
            "控制点必须在弦中点下方，否则不是向下弧线"
        )
        let curveMid = S2AlbumAfterimageFlight.point(
            from: from, to: to, progress: 0.5
        )
        XCTAssertGreaterThan(curveMid.y, chordMid.y)

        // 零距离不产生 NaN
        let degenerate = S2AlbumAfterimageFlight.controlPoint(
            from: from, to: from
        )
        XCTAssertEqual(degenerate.x, from.x, accuracy: 0.000_001)
        XCTAssertEqual(degenerate.y, from.y, accuracy: 0.000_001)

        // 越界钳制
        XCTAssertEqual(
            S2AlbumAfterimageFlight.point(
                from: from, to: to, progress: -1
            ).y,
            from.y,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2AlbumAfterimageFlight.point(
                from: from, to: to, progress: 2
            ).y,
            to.y,
            accuracy: 0.000_001
        )
    }

    // IC-111 C：落点 = 底部中胶囊中心，与 chrome 底排同一套表达式；
    // 左右边距对称 ⟹ 落点水平居中。
    func testIC111CBottomCapsuleCenterSharesChromeDerivation() {
        let viewport = CGSize(width: 393, height: 852)
        let insets = S2OverlaySafeAreaInsets(
            top: 59,
            leading: 0,
            bottom: 34,
            trailing: 0
        )
        let center = S2AlbumAfterimageFlight.bottomCapsuleCenter(
            viewportSize: viewport,
            safeAreaInsets: insets
        )
        // 水平居中
        XCTAssertEqual(center.x, viewport.width / 2, accuracy: 0.000_001)
        // 竖向 = 视口高 − 底排中心距视口底（常规机型 852 − 64 = 788）
        XCTAssertEqual(
            center.y,
            viewport.height -
                S2OverlayLayout.actionBandCenterFromViewportBottom(
                    safeAreaBottom: insets.bottom
                ),
            accuracy: 0.000_001
        )
        XCTAssertEqual(center.y, 788, accuracy: 0.000_001)
    }

    // IC-111 C（④ 时序）：首次经选择器换新相簿要先入场、残影推迟；
    // 同一相簿再来立即起飞；直接点中胶囊也是立即。
    func testIC111CEntranceGateSequencing() {
        var gate = S2AlbumAfterimageGate()

        // 直接点：立即放行
        XCTAssertTrue(gate.requestDirectLaunch())

        // 首次选中相簿 A：需要先入场，且此刻不放行
        XCTAssertTrue(gate.albumSelected(id: "album-A"))
        XCTAssertTrue(gate.isEntering)
        XCTAssertTrue(gate.hasDeferredLaunch)
        XCTAssertFalse(
            gate.requestDirectLaunch(),
            "入场中不得放飞残影"
        )

        // 入场完成：把推迟的那一枚放飞
        XCTAssertTrue(gate.entranceDidFinish())
        XCTAssertFalse(gate.isEntering)
        XCTAssertFalse(gate.hasDeferredLaunch)
        XCTAssertTrue(gate.requestDirectLaunch())

        // 再次选中同一相簿 A：不再入场，走立即路径
        XCTAssertFalse(gate.albumSelected(id: "album-A"))
        XCTAssertFalse(gate.isEntering)

        // 换到新相簿 B：又要入场一次
        XCTAssertTrue(gate.albumSelected(id: "album-B"))
        XCTAssertTrue(gate.isEntering)
        XCTAssertTrue(gate.entranceDidFinish())

        // 没有待放飞时，入场完成不凭空放飞
        XCTAssertFalse(gate.entranceDidFinish())
    }

    // IC-111 C：两种残影的落点计数各自独立——同屏并存、互不阻塞。
    func testIC111CAlbumAndMarkLandingsAreIndependent() {
        let coordinator = S2MarkAfterimageCoordinator()
        XCTAssertEqual(coordinator.landedTick, 0)
        XCTAssertEqual(coordinator.albumLandedTick, 0)

        coordinator.willLaunch()
        coordinator.didLand()
        XCTAssertEqual(coordinator.landedTick, 1)
        XCTAssertEqual(
            coordinator.albumLandedTick,
            0,
            "标记残影落点不得触发中胶囊回弹"
        )

        coordinator.albumDidLand()
        coordinator.albumDidLand()
        XCTAssertEqual(coordinator.albumLandedTick, 2)
        XCTAssertEqual(
            coordinator.landedTick,
            1,
            "相簿残影落点不得触发垃圾桶回弹"
        )
    }

    // MARK: - IC-110 D：首次引导教程
    //
    // 以下均为**夹具驱动**的状态机断言，真机走查由 H47 兜底（陷阱 1）。

    // IC-110 D：五步顺序推进——每一步只被它该等的那个真实事件推动。
    func testIC110DTutorialAdvancesThroughFiveStepsInOrder() {
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
        XCTAssertEqual(tutorial.activeStep, .confirmEntry)

        // 第 5 步点击任意处结束——完成，并落盘。
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
    func testIC110DStepCatalogIsWellFormed() {
        XCTAssertEqual(S2TutorialStep.allCases.count, 5)
        XCTAssertEqual(
            S2TutorialStep.allCases.map(\.rawValue),
            [1, 2, 3, 4, 5]
        )
        let texts = S2TutorialStep.allCases.map(\.text)
        XCTAssertEqual(
            Set(texts).count,
            5,
            "五步文案必须互不相同"
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
    struct AdditionRequest: Equatable {
        let assetID: String
        let albumID: String
    }

    private let albums: [S2AlbumReference]
    private let containedPairs: Set<String>
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

    func toggleFavorite(
        assetID: String,
        completion: @escaping (Bool) -> Void
    ) {
        favoriteRequests.append(assetID)
        pendingFavorites.append(completion)
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
