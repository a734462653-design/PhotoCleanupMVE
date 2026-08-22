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
