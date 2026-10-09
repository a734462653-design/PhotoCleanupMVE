import SwiftUI
import XCTest
@testable import PhotoCleanupMVE

/// IC-195：S2 教学引导 D 的逻辑层（SPEC-S2 v24 第二节第 6 部分 J1～J12、L1～L4；拆卡与取定
/// `Tasks/PLAN-S2D-guide-rulings-20261009.md`）。本卡不接视图——运行中的引导仍是 v23 三句就地提示。
/// A 进入（J2）；B 标记与停留（J3、J4、L1、L3）；C 撤标与第 3 步（J5、J6）；D 计数与顶掉（J7，两种顺序结果相同）；
/// E 进确认页、跳过、完成提示、离开、重看教程（J8～J12）；F 六标志的 `UserDefaults` 存储与 v23 三键沿用；
/// G 状态机两个一次性信号；H 源码落位。
///
/// **夹具驱动**：事件由测试直接调协调器，内存存储；接线、视图与真机观感归界面层卡。
final class IC195GuideDLogicTests: XCTestCase {
    private static let machinePath = "PhotoCleanupMVE/Core/S2StateMachine.swift"
    private static let guidePath = "PhotoCleanupMVE/Features/S2/S2GuideD.swift"
    private static let s2ViewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let hintsPath = "PhotoCleanupMVE/Features/S2/S2InlineHints.swift"

    // MARK: - A 进入（J2）

    func testIC195A_EntryRules() {
        // 新装：第 1 步 + 进门压暗，压暗出现即记「压暗已出」。
        let store = IC195MemoryGuideStore()
        let guide = S2GuideCoordinator(store: store)
        guide.start(mergedCount: 0)
        XCTAssertEqual(guide.display, .step(.swipeUp))
        XCTAssertTrue(guide.showsIntroDim)
        XCTAssertTrue(store.hasDimmedIntro)
        XCTAssertTrue(guide.holdsPageOnNextMark)
        // 离开再进：第 1 步照出、压暗不再出。
        guide.leaveScreen()
        XCTAssertNil(guide.display)
        XCTAssertFalse(guide.showsIntroDim)
        guide.start(mergedCount: 0)
        XCTAssertEqual(guide.display, .step(.swipeUp))
        XCTAssertFalse(guide.showsIntroDim)

        // 第 1 步已会、篮内已 5 张、第 4 步未会：出第 4 步；4 张不出。
        let five = S2GuideCoordinator(store: IC195MemoryGuideStore(learned: [.swipeUp]))
        five.start(mergedCount: 5)
        XCTAssertEqual(five.display, .step(.confirmEntry))
        XCTAssertFalse(five.showsIntroDim)
        let four = S2GuideCoordinator(store: IC195MemoryGuideStore(learned: [.swipeUp]))
        four.start(mergedCount: 4)
        XCTAssertNil(four.display)

        // 四步都已会、「完成已出」为假：出完成提示，出现即记；到点收起；再进不再出。
        let allStore = IC195MemoryGuideStore(learned: Set(S2GuideStep.allCases))
        let done = S2GuideCoordinator(store: allStore)
        done.start(mergedCount: 0)
        XCTAssertEqual(done.display, .completion)
        XCTAssertTrue(allStore.hasShownCompletion)
        done.completionDidTimeOut()
        XCTAssertNil(done.display)
        done.leaveScreen()
        done.start(mergedCount: 0)
        XCTAssertNil(done.display)

        // 只学会 v23 三句（第 1、2、4 步）的设备：进入不出——第 3 步只由撤标触发。
        let legacy = S2GuideCoordinator(store: IC195MemoryGuideStore(learned: [.swipeUp, .markedOnce, .confirmEntry]))
        legacy.start(mergedCount: 6)
        XCTAssertNil(legacy.display)
        XCTAssertFalse(legacy.holdsPageOnNextMark)
    }

    // MARK: - B 标记与停留（J3、J4、L1、L3）

    func testIC195B_MarkHoldAndCollapse() {
        let store = IC195MemoryGuideStore()
        let guide = S2GuideCoordinator(store: store)
        guide.start(mergedCount: 0)
        XCTAssertTrue(guide.holdsPageOnNextMark)
        // 停在刚标记那张：第 1 步已会，出第 2 步，压暗随第 1 步消失；不再停。
        guide.assetDidBecomeMarked(stayedOnMarkedAsset: true)
        XCTAssertEqual(guide.display, .step(.markedOnce))
        XCTAssertFalse(guide.showsIntroDim)
        XCTAssertEqual(store.learned, Set([.swipeUp]))
        XCTAssertFalse(guide.holdsPageOnNextMark)
        // J4：翻看收起第 2 步，不记已会，本次不再出。
        guide.currentAssetDidChange(cause: .browse)
        XCTAssertNil(guide.display)
        XCTAssertEqual(store.learned, Set([.swipeUp]))
        XCTAssertEqual(guide.collapsedThisVisit, Set([.markedOnce]))
        guide.assetDidBecomeMarked(stayedOnMarkedAsset: true)
        XCTAssertNil(guide.display)
        XCTAssertFalse(guide.holdsPageOnNextMark)
        // 下次进入：仍停一次（L2）。
        guide.leaveScreen()
        guide.start(mergedCount: 0)
        XCTAssertNil(guide.display)
        XCTAssertTrue(guide.holdsPageOnNextMark)
        // J4：标记后自动进下一张同样收起。
        guide.assetDidBecomeMarked(stayedOnMarkedAsset: true)
        XCTAssertEqual(guide.display, .step(.markedOnce))
        guide.currentAssetDidChange(cause: .markAdvance)
        XCTAssertNil(guide.display)
        XCTAssertEqual(guide.collapsedThisVisit, Set([.markedOnce]))

        // L3：没停住（放大态）——不出第 2 步、也不记收起，留给下一次停住的标记；两个回调谁先到结果相同。
        for currentFirst in [false, true] {
            let zoomed = S2GuideCoordinator(store: IC195MemoryGuideStore(learned: [.swipeUp]))
            zoomed.start(mergedCount: 0)
            if currentFirst {
                zoomed.currentAssetDidChange(cause: .markAdvance)
                zoomed.assetDidBecomeMarked(stayedOnMarkedAsset: false)
            } else {
                zoomed.assetDidBecomeMarked(stayedOnMarkedAsset: false)
                zoomed.currentAssetDidChange(cause: .markAdvance)
            }
            XCTAssertNil(zoomed.display)
            XCTAssertTrue(zoomed.collapsedThisVisit.isEmpty)
            XCTAssertTrue(zoomed.holdsPageOnNextMark)
            zoomed.assetDidBecomeMarked(stayedOnMarkedAsset: true)
            XCTAssertEqual(zoomed.display, .step(.markedOnce))
        }
    }

    // MARK: - C 撤标与第 3 步（J5、J6）

    func testIC195C_UnmarkAndUndoneStep() {
        // 第 2 步在显时下滑撤标：第 2 步已会，出第 3 步；翻看记第 3 步已会。
        let store = IC195MemoryGuideStore()
        let guide = S2GuideCoordinator(store: store)
        guide.start(mergedCount: 0)
        guide.assetDidBecomeMarked(stayedOnMarkedAsset: true)
        guide.assetDidBecomeUnmarked(source: .undo)
        XCTAssertEqual(guide.display, .step(.undone))
        XCTAssertEqual(store.learned, Set([.swipeUp, .markedOnce]))
        XCTAssertFalse(guide.holdsPageOnNextMark)
        guide.currentAssetDidChange(cause: .browse)
        XCTAssertNil(guide.display, "第 4 步未会，不出完成提示")
        XCTAssertEqual(store.learned, Set([.swipeUp, .markedOnce, .undone]))

        // 加入相簿后的静默移除：只记第 2 步已会，不出第 3 步。
        let albumStore = IC195MemoryGuideStore()
        let album = S2GuideCoordinator(store: albumStore)
        album.start(mergedCount: 0)
        album.assetDidBecomeMarked(stayedOnMarkedAsset: true)
        album.assetDidBecomeUnmarked(source: .albumRemoval)
        XCTAssertNil(album.display)
        XCTAssertEqual(albumStore.learned, Set([.swipeUp, .markedOnce]))
        XCTAssertTrue(album.collapsedThisVisit.isEmpty)

        // 第 1 步在显时撤标（篮里本就有的照片）：第 1 步优先，不出第 3 步，第 2 步照记已会。
        let firstStore = IC195MemoryGuideStore()
        let first = S2GuideCoordinator(store: firstStore)
        first.start(mergedCount: 1)
        first.assetDidBecomeUnmarked(source: .undo)
        XCTAssertEqual(first.display, .step(.swipeUp))
        XCTAssertTrue(first.showsIntroDim)
        XCTAssertEqual(firstStore.learned, Set([.markedOnce]))

        // 第 3 步在显时标记后自动进下一张：只收起、不记已会，本次不再出。
        let advanceStore = IC195MemoryGuideStore(learned: [.swipeUp, .markedOnce])
        let advance = S2GuideCoordinator(store: advanceStore)
        advance.start(mergedCount: 2)
        advance.assetDidBecomeUnmarked(source: .undo)
        XCTAssertEqual(advance.display, .step(.undone))
        advance.assetDidBecomeMarked(stayedOnMarkedAsset: false)
        advance.currentAssetDidChange(cause: .markAdvance)
        XCTAssertNil(advance.display)
        XCTAssertFalse(advanceStore.isLearned(.undone))
        XCTAssertEqual(advance.collapsedThisVisit, Set([.undone]))
        advance.assetDidBecomeUnmarked(source: .undo)
        XCTAssertNil(advance.display, "本次不再出")

        // 第 4 步在显时撤标：第 4 步优先，不出第 3 步。
        let confirm = S2GuideCoordinator(store: IC195MemoryGuideStore(learned: [.swipeUp]))
        confirm.start(mergedCount: 5)
        confirm.assetDidBecomeUnmarked(source: .undo)
        XCTAssertEqual(confirm.display, .step(.confirmEntry))
    }

    // MARK: - D 计数与顶掉（J7）

    func testIC195D_CountRiseShowsConfirmEntryInEitherOrder() {
        // 第 1 步在显、篮内 4 张，这一下标记（没停住）让计数到 5：两种顺序都只见第 4 步。
        var outcomes: [String] = []
        for countFirst in [false, true] {
            let store = IC195MemoryGuideStore()
            let guide = S2GuideCoordinator(store: store)
            guide.start(mergedCount: 4)
            if countFirst {
                guide.mergedCountDidChange(5)
                guide.assetDidBecomeMarked(stayedOnMarkedAsset: false)
            } else {
                guide.assetDidBecomeMarked(stayedOnMarkedAsset: false)
                guide.mergedCountDidChange(5)
            }
            XCTAssertEqual(guide.display, .step(.confirmEntry))
            XCTAssertFalse(guide.showsIntroDim)
            XCTAssertEqual(guide.collapsedThisVisit, Set([.markedOnce]))
            XCTAssertEqual(store.learned, Set([.swipeUp]))
            outcomes.append("\(String(describing: guide.display)) \(guide.collapsedThisVisit.sorted { $0.rawValue < $1.rawValue })")
        }
        XCTAssertEqual(outcomes[0], outcomes[1])

        // 停住的那一下：两种顺序同样只见第 4 步，第 2 步本次不再出。
        for countFirst in [false, true] {
            let guide = S2GuideCoordinator(store: IC195MemoryGuideStore())
            guide.start(mergedCount: 4)
            if countFirst {
                guide.mergedCountDidChange(5)
                guide.assetDidBecomeMarked(stayedOnMarkedAsset: true)
            } else {
                guide.assetDidBecomeMarked(stayedOnMarkedAsset: true)
                guide.mergedCountDidChange(5)
            }
            XCTAssertEqual(guide.display, .step(.confirmEntry))
            XCTAssertEqual(guide.collapsedThisVisit, Set([.markedOnce]))
        }

        // 只在上升且达到阈值时出；下降不触发；在显第 4 步时再上升不变。
        let rising = S2GuideCoordinator(store: IC195MemoryGuideStore(learned: [.swipeUp]))
        rising.start(mergedCount: 4)
        rising.mergedCountDidChange(3)
        XCTAssertNil(rising.display)
        rising.mergedCountDidChange(4)
        XCTAssertNil(rising.display)
        rising.mergedCountDidChange(5)
        XCTAssertEqual(rising.display, .step(.confirmEntry))
        rising.mergedCountDidChange(6)
        XCTAssertEqual(rising.display, .step(.confirmEntry))
        XCTAssertEqual(rising.lastMergedCount, 6)

        // 被顶掉的第 3 步本次不再出。
        let pushed = S2GuideCoordinator(store: IC195MemoryGuideStore(learned: [.swipeUp, .markedOnce]))
        pushed.start(mergedCount: 4)
        pushed.assetDidBecomeUnmarked(source: .undo)
        XCTAssertEqual(pushed.display, .step(.undone))
        pushed.mergedCountDidChange(5)
        XCTAssertEqual(pushed.display, .step(.confirmEntry))
        XCTAssertEqual(pushed.collapsedThisVisit, Set([.markedOnce, .undone]))
    }

    // MARK: - E 进确认页、跳过、完成提示、离开、重看教程（J8～J12）

    func testIC195E_ConfirmSkipCompletionLeaveReset() {
        // J8：第 4 步是最后学会的一步——不当场出完成提示，下一次进入出。
        let lastStore = IC195MemoryGuideStore(learned: [.swipeUp, .markedOnce, .undone])
        let last = S2GuideCoordinator(store: lastStore)
        last.start(mergedCount: 5)
        XCTAssertEqual(last.display, .step(.confirmEntry))
        last.confirmEntryTapped()
        XCTAssertNil(last.display)
        XCTAssertEqual(lastStore.learned, Set(S2GuideStep.allCases))
        XCTAssertFalse(lastStore.hasShownCompletion)
        last.leaveScreen()
        last.start(mergedCount: 5)
        XCTAssertEqual(last.display, .completion)
        XCTAssertTrue(lastStore.hasShownCompletion)

        // J10：当场学会最后一步（第 3 步翻看）且 V=显示——当场出完成提示。
        let inPlaceStore = IC195MemoryGuideStore(learned: [.swipeUp, .markedOnce, .confirmEntry])
        let inPlace = S2GuideCoordinator(store: inPlaceStore)
        inPlace.start(mergedCount: 0)
        inPlace.assetDidBecomeUnmarked(source: .undo)
        XCTAssertEqual(inPlace.display, .step(.undone))
        inPlace.currentAssetDidChange(cause: .browse)
        XCTAssertEqual(inPlace.display, .completion)
        XCTAssertTrue(inPlaceStore.hasShownCompletion)

        // 同上但 V=隐藏：不当场出，下一次进入出。
        let hiddenStore = IC195MemoryGuideStore(learned: [.swipeUp, .markedOnce, .confirmEntry])
        let hidden = S2GuideCoordinator(store: hiddenStore)
        hidden.start(mergedCount: 0)
        hidden.assetDidBecomeUnmarked(source: .undo)
        hidden.isInterfaceVisible = false
        hidden.currentAssetDidChange(cause: .browse)
        XCTAssertNil(hidden.display)
        XCTAssertFalse(hiddenStore.hasShownCompletion)
        hidden.leaveScreen()
        hidden.start(mergedCount: 0)
        XCTAssertEqual(hidden.display, .completion)

        // J9：跳过——收起与压暗，本次不再出任何一项、不停留，不记已会；动作本身照常学会。
        let skipStore = IC195MemoryGuideStore()
        let skip = S2GuideCoordinator(store: skipStore)
        skip.start(mergedCount: 4)
        skip.skip()
        XCTAssertNil(skip.display)
        XCTAssertFalse(skip.showsIntroDim)
        XCTAssertTrue(skip.isSkippedThisVisit)
        XCTAssertFalse(skip.holdsPageOnNextMark)
        skip.assetDidBecomeMarked(stayedOnMarkedAsset: true)
        skip.mergedCountDidChange(5)
        XCTAssertNil(skip.display)
        XCTAssertEqual(skipStore.learned, Set([.swipeUp]))
        // J11：离开清空本次记录，下次进入照规则出。
        skip.leaveScreen()
        XCTAssertFalse(skip.isSkippedThisVisit)
        skip.start(mergedCount: 5)
        XCTAssertEqual(skip.display, .step(.confirmEntry))

        // J12：重看教程——清零六个标志，当场重出第 1 步与压暗（并记「压暗已出」）。
        let resetStore = IC195MemoryGuideStore(learned: Set(S2GuideStep.allCases))
        resetStore.hasShownCompletion = true
        resetStore.hasDimmedIntro = true
        let reset = S2GuideCoordinator(store: resetStore)
        reset.start(mergedCount: 0)
        XCTAssertNil(reset.display)
        reset.reset()
        XCTAssertEqual(resetStore.resetCount, 1)
        XCTAssertEqual(reset.display, .step(.swipeUp))
        XCTAssertTrue(reset.showsIntroDim)
        XCTAssertTrue(resetStore.learned.isEmpty)
        XCTAssertFalse(resetStore.hasShownCompletion)
        XCTAssertTrue(resetStore.hasDimmedIntro)
        XCTAssertTrue(reset.holdsPageOnNextMark)

        XCTAssertEqual(S2GuideCoordinator.confirmThreshold, 5)
        XCTAssertEqual(S2GuideCoordinator.completionAutoDismissSeconds, 2)
    }

    // MARK: - F 六标志的存储与 v23 三键沿用（J12）

    func testIC195F_UserDefaultsStoreReusesV23Keys() throws {
        let suite = "IC195GuideStore-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = S2UserDefaultsGuideStore(defaults: defaults)

        XCTAssertEqual(S2GuideStep.allCases.map(\.rawValue), ["swipeUp", "markedOnce", "undone", "confirmEntry"])
        XCTAssertEqual(S2UserDefaultsGuideStore.defaultsKeyPrefix, S2UserDefaultsInlineHintStore.defaultsKeyPrefix)
        XCTAssertEqual(S2UserDefaultsGuideStore.defaultsKey(for: .swipeUp), S2UserDefaultsInlineHintStore.defaultsKey(for: .swipeUp))
        XCTAssertEqual(S2UserDefaultsGuideStore.defaultsKey(for: .markedOnce), S2UserDefaultsInlineHintStore.defaultsKey(for: .markedOnce))
        XCTAssertEqual(S2UserDefaultsGuideStore.defaultsKey(for: .confirmEntry), S2UserDefaultsInlineHintStore.defaultsKey(for: .confirmEntry))
        XCTAssertEqual(S2UserDefaultsGuideStore.defaultsKey(for: .undone), S2UserDefaultsGuideStore.defaultsKeyPrefix + "undone")
        XCTAssertEqual(S2UserDefaultsGuideStore.completionKey, S2UserDefaultsGuideStore.defaultsKeyPrefix + "completed")
        XCTAssertEqual(S2UserDefaultsGuideStore.introDimmedKey, S2UserDefaultsGuideStore.defaultsKeyPrefix + "introDimmed")

        // v23 三句记下的「已会」，引导 D 原样读到（J12）。
        let legacy = S2UserDefaultsInlineHintStore(defaults: defaults)
        legacy.markLearned(.markedOnce)
        XCTAssertTrue(store.isLearned(.markedOnce))
        XCTAssertFalse(store.isLearned(.undone))
        XCTAssertFalse(store.hasShownCompletion)
        XCTAssertFalse(store.hasDimmedIntro)

        for step in S2GuideStep.allCases {
            store.markLearned(step)
        }
        store.markCompletionShown()
        store.markIntroDimmed()
        XCTAssertTrue(S2GuideStep.allCases.allSatisfy { store.isLearned($0) })
        XCTAssertTrue(store.hasShownCompletion)
        XCTAssertTrue(store.hasDimmedIntro)

        // 换一只实例读回（跨启动保留的本地近似）。
        let reread = S2UserDefaultsGuideStore(defaults: defaults)
        XCTAssertTrue(reread.isLearned(.undone))
        XCTAssertTrue(reread.hasShownCompletion)

        store.reset()
        XCTAssertFalse(S2GuideStep.allCases.contains { store.isLearned($0) })
        XCTAssertFalse(store.hasShownCompletion)
        XCTAssertFalse(store.hasDimmedIntro)
        XCTAssertNil(defaults.object(forKey: S2UserDefaultsGuideStore.completionKey))
        XCTAssertNil(defaults.object(forKey: S2UserDefaultsGuideStore.introDimmedKey))
    }

    // MARK: - G 状态机两个一次性信号

    func testIC195G_StateMachineChangeSignals() throws {
        let machine = makeMachine()
        XCTAssertNil(machine.lastPendingDeletionChangeSource)
        XCTAssertNil(machine.lastCurrentAssetChangeCause)
        // 上滑标记并自动进下一张。
        XCTAssertTrue(machine.handleSwipeUp())
        XCTAssertEqual(machine.lastPendingDeletionChangeSource, .mark)
        XCTAssertEqual(machine.lastCurrentAssetChangeCause, .markAdvance)
        XCTAssertEqual(machine.currentAssetID, "asset-3")
        // 左右滑回到上一张。
        XCTAssertTrue(machine.handleHorizontalSwipe(direction: .previous, startedAtPagingEdge: false, distance: 0, velocity: 0))
        XCTAssertEqual(machine.currentAssetID, "asset-2")
        XCTAssertEqual(machine.lastCurrentAssetChangeCause, .browse)
        // 下滑撤标（中央「撤销」调的也是它）。
        XCTAssertTrue(machine.handleSwipeDown())
        XCTAssertEqual(machine.lastPendingDeletionChangeSource, .undo)
        XCTAssertFalse(machine.pendingDeletionAssetIDs.contains("asset-2"))
        // 原生分页器换页。
        XCTAssertTrue(machine.handleNativePageChange(to: 0))
        XCTAssertEqual(machine.currentAssetID, "asset-1")
        XCTAssertEqual(machine.lastCurrentAssetChangeCause, .browse)

        // 学习例外停住：原因照记 `.markAdvance`，但当前张不变（视图只在当前张变了时才读）。
        let held = makeMachine()
        held.holdsPageAfterNextMark = true
        XCTAssertTrue(held.handleSwipeUp())
        XCTAssertEqual(held.currentAssetID, "asset-2")
        XCTAssertEqual(held.lastPendingDeletionChangeSource, .mark)
        XCTAssertEqual(held.lastCurrentAssetChangeCause, .markAdvance)

        // 横栏拖动切换。
        let strip = makeMachine()
        XCTAssertTrue(strip.beginBottomStripDrag())
        XCTAssertTrue(strip.changeCurrentPhotoDuringBottomStripDrag(by: 1))
        XCTAssertEqual(strip.currentAssetID, "asset-3")
        XCTAssertEqual(strip.lastCurrentAssetChangeCause, .browse)
        XCTAssertTrue(strip.endBottomStripDrag())

        // 加入相簿后的静默移除。
        let album = makeMachine(
            pendingDeletionAssetIDs: ["asset-1", "asset-2"],
            recentAlbum: S2AlbumReference(id: "album-195", name: "相簿")
        )
        let request = try XCTUnwrap(album.makeRecentAlbumAdditionRequest())
        XCTAssertEqual(request.targetAssetID, "asset-2")
        XCTAssertTrue(album.beginRecentAlbumAddition(request))
        XCTAssertTrue(album.completeRecentAlbumAddition(request, outcome: .success(alreadyContained: false)))
        XCTAssertFalse(album.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(album.lastPendingDeletionChangeSource, .albumRemoval)
    }

    // MARK: - H 源码落位

    func testIC195H_SourceWiring() throws {
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        for (needle, expected) in [
            ("enum S2PendingDeletionChangeSource: Equatable {", 1),
            ("enum S2CurrentAssetChangeCause: Equatable {", 1),
            ("private(set) var lastPendingDeletionChangeSource: S2PendingDeletionChangeSource?", 1),
            ("private(set) var lastCurrentAssetChangeCause: S2CurrentAssetChangeCause?", 1),
            ("lastPendingDeletionChangeSource = .mark", 1),
            ("lastPendingDeletionChangeSource = .undo", 1),
            ("lastPendingDeletionChangeSource = .albumRemoval", 1),
            ("lastCurrentAssetChangeCause = .markAdvance", 1),
            ("lastCurrentAssetChangeCause = .browse", 4),
            // 既有钉子不变（IC-182、IC-146、IC-187）。
            ("holdsPageAfterNextMark", 3),
            ("? handleSwipeDown()", 1),
            ("func handleSwipeDown()", 1),
            ("markCurrentSeen()", 4),
            ("replacePendingDeletionAssetIDs(", 4)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: machine), expected, needle)
        }
        let swipeUp = try XCTUnwrap(slice(machine, from: "func handleSwipeUp() -> Bool {", to: "func handleSwipeDown() -> Bool {"))
        try assertOrder(["lastPendingDeletionChangeSource = .mark", "replacePendingDeletionAssetIDs(with: nextPending)",
                         "lastCurrentAssetChangeCause = .markAdvance", "if holdsPageAfterNextMark && zoomState == .oneX {",
                         "switchPhoto(by: 1)"], in: swipeUp)
        XCTAssertEqual(occurrences(of: "switchPhoto(by: 1)", in: swipeUp), 1)
        let switchBody = try XCTUnwrap(slice(machine, from: "private func switchPhoto(by offset: Int) -> Bool {", to: "return true"))
        XCTAssertEqual(occurrences(of: "lastCurrentAssetChangeCause", in: switchBody), 0, "switchPhoto 签名与本体不动")

        let guideRaw = try XCTUnwrap(sourceText(Self.guidePath))
        let guide = stripped(guideRaw)
        for (needle, expected) in [
            ("enum S2GuideStep: String, CaseIterable, Equatable {", 1),
            ("enum S2GuideDisplay: Equatable {", 1),
            ("protocol S2GuideStoring {", 1),
            ("struct S2UserDefaultsGuideStore: S2GuideStoring {", 1),
            ("final class S2GuideCoordinator: ObservableObject {", 1),
            ("@Published private(set) var display: S2GuideDisplay?", 1),
            ("@Published private(set) var showsIntroDim = false", 1),
            ("static let confirmThreshold = 5", 1),
            ("static let completionAutoDismissSeconds: TimeInterval = 2", 1),
            ("init(store: S2GuideStoring = S2UserDefaultsGuideStore())", 1),
            ("@MainActor", 0),
            ("L10n.", 0),
            ("View", 0),
            ("Text(", 0),
            ("S2InlineHint", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: guide), expected, needle)
        }
        XCTAssertEqual(occurrences(of: "import ", in: guideRaw), 2)
        XCTAssertEqual(occurrences(of: "return \"", in: guideRaw), 0)

        // 不接视图：S2View 与 v23 三句文件里没有引导 D 的名字。
        for path in [Self.s2ViewPath, Self.hintsPath] {
            let text = try XCTUnwrap(strippedSource(path))
            for needle in ["S2GuideCoordinator", "S2GuideStep", "S2UserDefaultsGuideStore", "lastPendingDeletionChangeSource", "lastCurrentAssetChangeCause"] {
                XCTAssertEqual(occurrences(of: needle, in: text), 0, path + " " + needle)
            }
        }
    }

    // MARK: - 夹具

    private func makeMachine(
        pendingDeletionAssetIDs: Set<String> = ["asset-1"],
        currentAssetID: String = "asset-2",
        recentAlbum: S2AlbumReference? = nil
    ) -> S2StateMachine {
        let countBox = IC195CountBox(value: pendingDeletionAssetIDs.count)
        let entry = S2EntryContext(
            sessionID: "session-195",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "range-195",
                displayName: "测试范围",
                totalAssetCount: 3
            ),
            orderedAssetIDs: ["asset-1", "asset-2", "asset-3"],
            currentAssetID: currentAssetID,
            pendingDeletionAssetIDs: pendingDeletionAssetIDs,
            sessionMergedPendingDeletionCountProvider: { countBox.value }
        )
        return S2StateMachine(
            entry: entry,
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            ),
            parameters: parameters,
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: recentAlbum,
            pendingDeletionDidChange: { countBox.value = $0.count },
            recentAlbumDidChange: { _ in }
        )!
    }

    private var parameters: S2ResolvedParameters {
        S2ResolvedParameters(
            pinchMaxScaleFloor: 4,
            pinchMaxScaleCeiling: 40,
            pinchMaxScaleOneToOneMultiplier: 6,
            zoomSnapBackThreshold: 1.2,
            minDoubleTapScale: 2.5,
            doubleTapAnchorStrategy: .touchPoint,
            edgePagingTriggerDistance: 40,
            edgePagingTriggerVelocity: 300,
            verticalSwipeDistance: 40,
            verticalSwipeVelocity: 100,
            bottomStripMetrics: S2BottomStripMetrics(
                currentItemSize: 30,
                neighborItemWidth: 20,
                neighborItemHeight: 30,
                itemSpacing: 3,
                currentItemGap: 13,
                edgeFadeWidth: 18.7,
                leadingInset: 20.3,
                switchDistance: 23,
                decelerationRate: 0.998,
                expandDurationMilliseconds: 600,
                collapseDurationMilliseconds: 100,
                flickVelocityThreshold: 300,
                cornerRadius: 8.0 / 3.0
            )
        )!
    }

    private func assertOrder(_ needles: [String], in text: String, file: StaticString = #filePath, line: UInt = #line) throws {
        var cursor = text.startIndex
        for needle in needles {
            let found = try XCTUnwrap(text.range(of: needle, range: cursor..<text.endIndex), needle, file: file, line: line)
            cursor = found.upperBound
        }
    }

    // MARK: - 工具（与既有测试同口径）

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.upperBound])
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceText(_ relativePath: String) -> String? {
        try? String(
            contentsOf: repoRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func strippedSource(_ relativePath: String) -> String? {
        sourceText(relativePath).map { stripped($0) }
    }

    /// 剔掉 `//` 注释与字符串字面量内容。
    private func stripped(_ source: String) -> String {
        let newline = Character(UnicodeScalar(UInt8(10)))
        var output = ""
        var iterator = source.startIndex
        var inString = false
        while iterator < source.endIndex {
            let character = source[iterator]
            let next = source.index(after: iterator)
            if inString {
                if character == "\\" {
                    iterator = next < source.endIndex
                        ? source.index(after: next)
                        : source.endIndex
                    continue
                }
                if character == "\"" {
                    inString = false
                }
                iterator = next
                continue
            }
            if character == "\"" {
                inString = true
                iterator = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                while iterator < source.endIndex,
                      source[iterator] != newline {
                    iterator = source.index(after: iterator)
                }
                output.append(newline)
                continue
            }
            output.append(character)
            iterator = next
        }
        return output
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}

/// 六标志的内存存储夹具。
private final class IC195MemoryGuideStore: S2GuideStoring {
    var learned: Set<S2GuideStep>
    var hasShownCompletion = false
    var hasDimmedIntro = false
    private(set) var resetCount = 0

    init(learned: Set<S2GuideStep> = []) {
        self.learned = learned
    }

    func isLearned(_ step: S2GuideStep) -> Bool {
        learned.contains(step)
    }

    func markLearned(_ step: S2GuideStep) {
        learned.insert(step)
    }

    func markCompletionShown() {
        hasShownCompletion = true
    }

    func markIntroDimmed() {
        hasDimmedIntro = true
    }

    func reset() {
        learned = []
        hasShownCompletion = false
        hasDimmedIntro = false
        resetCount += 1
    }
}

private final class IC195CountBox {
    var value: Int

    init(value: Int) {
        self.value = value
    }
}
