import Foundation
import SwiftUI
import XCTest
@testable import PhotoCleanupMVE

/// IC-179：S2 三句就地提示 + 各自记「已会」，六步教程停用不删（Decision_log 第 207 条第五节）。
///
/// 断言 1～7 是协调器状态机夹具（内存 store），8 是 `UserDefaults` 往返，9 是源码落位与目录：
/// 旧教程只剩 `startIfNeeded`／`replay` 两处调用改接就地提示，其余接线与类型原样保留；
/// 三句的观感、出现时机与 × 行为由 H94 真机判。
final class IC179InlineHintsTests: XCTestCase {
    private static let s2ViewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let hintsPath = "PhotoCleanupMVE/Features/S2/S2InlineHints.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let hintKeys = [
        "s2.hint.swipe_up", "s2.hint.swipe_up.sub",
        "s2.hint.marked", "s2.hint.marked.sub",
        "s2.hint.confirm", "s2.hint.confirm.sub",
        "s2.hint.dismiss"
    ]

    // MARK: - 断言 1：进门就出第 1 句；已会后进门静默

    func testIC179A_EntryShowsSwipeUpUntilLearnedThenSilent() {
        let store = InMemoryHintStore()
        let hints = S2InlineHintCoordinator(store: store)
        XCTAssertNil(hints.activeHint, "构造后无提示")
        hints.startIfNeeded(mergedCount: 0)
        XCTAssertEqual(hints.activeHint, .swipeUp, "进门立即出第 1 句，不等动手")
        hints.startIfNeeded(mergedCount: 0)
        XCTAssertEqual(hints.activeHint, .swipeUp, "重复进门不换句")
        hints.leaveScreen()
        XCTAssertNil(hints.activeHint, "离开收起")
        XCTAssertEqual(store.learned, [], "离开不记已会")
        hints.startIfNeeded(mergedCount: 0)
        XCTAssertEqual(hints.activeHint, .swipeUp, "未会 → 下次进门再出")
        hints.assetDidBecomeMarked()
        hints.leaveScreen()
        hints.startIfNeeded(mergedCount: 0)
        XCTAssertNil(hints.activeHint, "第 1 句已会、篮未到阈值 → 进门静默（第 2 句只在标记后出）")
    }

    // MARK: - 断言 2：真实标记 = 第 1 句已会、第 2 句出

    func testIC179B_RealMarkLearnsSwipeUpAndShowsMarkedOnce() {
        let store = InMemoryHintStore()
        let hints = S2InlineHintCoordinator(store: store)
        hints.startIfNeeded(mergedCount: 0)
        hints.assetDidBecomeMarked()
        XCTAssertEqual(hints.activeHint, .markedOnce)
        XCTAssertEqual(store.learned, [.swipeUp])
        hints.assetDidBecomeMarked()
        XCTAssertEqual(hints.activeHint, .markedOnce, "再标记一张不换句")
        XCTAssertEqual(store.learned, [.swipeUp], "第 2 句未撤标不算已会")
    }

    // MARK: - 断言 3：真实撤标 = 第 2 句已会并收起

    func testIC179C_RealUnmarkLearnsMarkedOnceAndHides() {
        let store = InMemoryHintStore()
        let hints = S2InlineHintCoordinator(store: store)
        hints.startIfNeeded(mergedCount: 0)
        hints.assetDidBecomeMarked()
        hints.assetDidBecomeUnmarked()
        XCTAssertNil(hints.activeHint)
        XCTAssertEqual(store.learned, [.swipeUp, .markedOnce])
        hints.assetDidBecomeMarked()
        XCTAssertNil(hints.activeHint, "两句都已会 → 再标记不出提示")
        // 撤标发生在第 1 句仍在显时（进门即有篮内已标的照片）：第 2 句直接已会、第 1 句照旧。
        let fresh = InMemoryHintStore()
        let early = S2InlineHintCoordinator(store: fresh)
        early.startIfNeeded(mergedCount: 3)
        early.assetDidBecomeUnmarked()
        XCTAssertEqual(early.activeHint, .swipeUp)
        XCTAssertEqual(fresh.learned, [.markedOnce])
    }

    // MARK: - 断言 4：攒到阈值出第 3 句并顶掉在显句；点入口已会

    func testIC179D_ThresholdShowsConfirmEntryAndDisplacesActiveHint() {
        XCTAssertEqual(S2InlineHintCoordinator.confirmThreshold, 5)
        let store = InMemoryHintStore(learned: [.swipeUp, .markedOnce])
        let hints = S2InlineHintCoordinator(store: store)
        hints.startIfNeeded(mergedCount: 0)
        XCTAssertNil(hints.activeHint)
        hints.mergedCountDidChange(4)
        XCTAssertNil(hints.activeHint, "阈值之下不出")
        hints.mergedCountDidChange(5)
        XCTAssertEqual(hints.activeHint, .confirmEntry)
        hints.mergedCountDidChange(6)
        XCTAssertEqual(hints.activeHint, .confirmEntry, "在显时计数再变不重出")
        hints.confirmEntryTapped()
        XCTAssertNil(hints.activeHint)
        XCTAssertEqual(store.learned, [.swipeUp, .markedOnce, .confirmEntry])
        hints.mergedCountDidChange(7)
        XCTAssertNil(hints.activeHint, "已会后不再出")

        // 第 1 句在显时计数上升到阈值（同一次标记）：第 3 句顶掉第 1 句，第 2 句本次不再出。
        let fresh = InMemoryHintStore()
        let busy = S2InlineHintCoordinator(store: fresh)
        busy.startIfNeeded(mergedCount: 4)
        busy.mergedCountDidChange(5)
        XCTAssertEqual(busy.activeHint, .confirmEntry)
        XCTAssertEqual(busy.dismissedThisVisit, [.markedOnce])
        busy.assetDidBecomeMarked()
        XCTAssertEqual(busy.activeHint, .confirmEntry, "同一次标记的另一半回调不换句")
        XCTAssertEqual(fresh.learned, [.swipeUp])

        // 进门时篮内已到阈值且第 1 句已会：进门直接出第 3 句。
        let entry = S2InlineHintCoordinator(store: InMemoryHintStore(learned: [.swipeUp]))
        entry.startIfNeeded(mergedCount: 5)
        XCTAssertEqual(entry.activeHint, .confirmEntry)
        // 第 1 句未会时进门仍先出第 1 句，不管篮里有多少。
        let first = S2InlineHintCoordinator(store: InMemoryHintStore())
        first.startIfNeeded(mergedCount: 9)
        XCTAssertEqual(first.activeHint, .swipeUp)
    }

    // MARK: - 断言 5：× 只收本次进入期间，不记已会

    func testIC179E_DismissHidesForThisVisitWithoutLearning() {
        let store = InMemoryHintStore()
        let hints = S2InlineHintCoordinator(store: store)
        hints.dismiss()
        XCTAssertEqual(hints.dismissedThisVisit, [], "无提示时 × 是空操作")
        hints.startIfNeeded(mergedCount: 0)
        hints.dismiss()
        XCTAssertNil(hints.activeHint)
        XCTAssertEqual(store.learned, [], "× 不记已会")
        XCTAssertEqual(hints.dismissedThisVisit, [.swipeUp])
        hints.assetDidBecomeMarked()
        XCTAssertEqual(store.learned, [.swipeUp], "× 掉之后真做了一次照样记已会")
        XCTAssertEqual(hints.activeHint, .markedOnce)
        hints.dismiss()
        hints.assetDidBecomeMarked()
        XCTAssertNil(hints.activeHint, "本次进入期间 × 掉的句子不再出")
        hints.leaveScreen()
        XCTAssertEqual(hints.dismissedThisVisit, [], "离开清空「本次」")
        hints.startIfNeeded(mergedCount: 0)
        XCTAssertNil(hints.activeHint, "第 1 句已会")
        hints.assetDidBecomeMarked()
        XCTAssertEqual(hints.activeHint, .markedOnce, "下次进入再标记，第 2 句再出")
    }

    // MARK: - 断言 6：三句全会后进门静默；「重看教程」清空并当场重出第 1 句

    func testIC179F_ResetClearsAllAndReplaysFirstHint() {
        let store = InMemoryHintStore(learned: [.swipeUp, .markedOnce, .confirmEntry])
        let hints = S2InlineHintCoordinator(store: store)
        hints.startIfNeeded(mergedCount: 9)
        XCTAssertNil(hints.activeHint)
        hints.mergedCountDidChange(10)
        XCTAssertNil(hints.activeHint)
        hints.reset()
        XCTAssertEqual(store.resetCount, 1)
        XCTAssertEqual(store.learned, [])
        XCTAssertEqual(hints.activeHint, .swipeUp)
        for hint in S2InlineHint.allCases {
            XCTAssertFalse(hints.isLearned(hint), hint.rawValue)
        }
    }

    // MARK: - 断言 7：第 2 句限时收起不记已会；第 3 句只在计数上升时出、顶掉在显句、两种回调顺序同结果

    func testIC179G_MarkedOnceTimesOutAndConfirmEntryDisplacesInAnyOrder() {
        XCTAssertEqual(S2InlineHintCoordinator.markedOnceAutoDismissSeconds, 6)
        let store = InMemoryHintStore(learned: [.swipeUp])
        let hints = S2InlineHintCoordinator(store: store)
        hints.startIfNeeded(mergedCount: 0)
        hints.assetDidBecomeMarked()
        XCTAssertEqual(hints.activeHint, .markedOnce)
        hints.hintDidTimeOut(.swipeUp)
        XCTAssertEqual(hints.activeHint, .markedOnce, "限时只对第 2 句有效")
        hints.hintDidTimeOut(.markedOnce)
        XCTAssertNil(hints.activeHint)
        XCTAssertEqual(store.learned, [.swipeUp], "到点收起不记已会")
        XCTAssertEqual(hints.dismissedThisVisit, [.markedOnce])
        hints.assetDidBecomeMarked()
        XCTAssertNil(hints.activeHint, "本次进入不再出")
        hints.hintDidTimeOut(.markedOnce)
        XCTAssertNil(hints.activeHint, "无提示时到点是空操作")
        hints.leaveScreen()
        hints.startIfNeeded(mergedCount: 0)
        hints.assetDidBecomeMarked()
        XCTAssertEqual(hints.activeHint, .markedOnce, "下次进入再出")

        // 顺序 A：标记回调先于计数回调。
        let a = S2InlineHintCoordinator(store: InMemoryHintStore())
        a.startIfNeeded(mergedCount: 4)
        a.assetDidBecomeMarked()
        XCTAssertEqual(a.activeHint, .markedOnce)
        a.mergedCountDidChange(5)
        XCTAssertEqual(a.activeHint, .confirmEntry)
        XCTAssertEqual(a.dismissedThisVisit, [.markedOnce])
        // 顺序 B：计数回调先于标记回调——结果相同。
        let b = S2InlineHintCoordinator(store: InMemoryHintStore())
        b.startIfNeeded(mergedCount: 4)
        b.mergedCountDidChange(5)
        XCTAssertEqual(b.activeHint, .confirmEntry)
        b.assetDidBecomeMarked()
        XCTAssertEqual(b.activeHint, .confirmEntry)
        XCTAssertEqual(b.dismissedThisVisit, [.markedOnce])
        XCTAssertTrue(b.isLearned(.swipeUp))
        XCTAssertFalse(b.isLearned(.markedOnce))

        // 计数不上升不出：下降、持平、以及进门时的基准。
        let c = S2InlineHintCoordinator(store: InMemoryHintStore(learned: [.swipeUp, .markedOnce]))
        c.startIfNeeded(mergedCount: 3)
        XCTAssertNil(c.activeHint)
        XCTAssertEqual(c.lastMergedCount, 3)
        c.mergedCountDidChange(2)
        c.mergedCountDidChange(2)
        XCTAssertNil(c.activeHint)
        c.mergedCountDidChange(5)
        XCTAssertEqual(c.activeHint, .confirmEntry)
        c.confirmEntryTapped()
        c.mergedCountDidChange(4)
        c.mergedCountDidChange(6)
        XCTAssertNil(c.activeHint, "已会后不再出")
        // 第 3 句在显时计数再上升不重出、也不动「本次」集合。
        let d = S2InlineHintCoordinator(store: InMemoryHintStore(learned: [.swipeUp, .markedOnce]))
        d.startIfNeeded(mergedCount: 5)
        XCTAssertEqual(d.activeHint, .confirmEntry)
        d.mergedCountDidChange(6)
        XCTAssertEqual(d.activeHint, .confirmEntry)
        XCTAssertEqual(d.dismissedThisVisit, [])
        // 撤标让计数下降：第 2 句已会收起，第 3 句不冒出来（首用者、篮内已有 6 张进门：先出第 1 句）。
        let e = S2InlineHintCoordinator(store: InMemoryHintStore())
        e.startIfNeeded(mergedCount: 6)
        XCTAssertEqual(e.activeHint, .swipeUp)
        e.assetDidBecomeMarked()
        XCTAssertEqual(e.activeHint, .markedOnce)
        e.assetDidBecomeUnmarked()
        e.mergedCountDidChange(5)
        XCTAssertNil(e.activeHint)
    }

    // MARK: - 断言 8：UserDefaults 往返、键名前缀

    func testIC179H_UserDefaultsStoreRoundTripUsesPrefixedKeys() throws {
        let suiteName = "IC179InlineHintsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = S2UserDefaultsInlineHintStore(defaults: defaults)
        XCTAssertEqual(
            S2UserDefaultsInlineHintStore.defaultsKeyPrefix,
            "com.iphonephotomanagement.PhotoCleanupMVE.s2.hint."
        )
        XCTAssertEqual(S2InlineHint.allCases.map(\.rawValue), ["swipeUp", "markedOnce", "confirmEntry"])
        for hint in S2InlineHint.allCases {
            XCTAssertFalse(store.isLearned(hint), hint.rawValue)
        }
        store.markLearned(.markedOnce)
        XCTAssertTrue(store.isLearned(.markedOnce))
        XCTAssertFalse(store.isLearned(.swipeUp))
        XCTAssertFalse(store.isLearned(.confirmEntry))
        XCTAssertTrue(defaults.bool(forKey: "com.iphonephotomanagement.PhotoCleanupMVE.s2.hint.markedOnce"))
        XCTAssertNil(defaults.object(forKey: "com.iphonephotomanagement.PhotoCleanupMVE.s2.hint.swipeUp"))
        store.markLearned(.swipeUp)
        store.markLearned(.confirmEntry)
        store.reset()
        for hint in S2InlineHint.allCases {
            XCTAssertNil(defaults.object(forKey: S2UserDefaultsInlineHintStore.defaultsKey(for: hint)), hint.rawValue)
        }
        // 与旧教程的键互不相干。
        XCTAssertFalse(
            S2UserDefaultsTutorialCompletionStore.defaultsKey.hasPrefix(S2UserDefaultsInlineHintStore.defaultsKeyPrefix)
        )
        // 文案：七条 key 都在目录里；第 3 句的张数占位符被替换。
        for key in Self.hintKeys {
            XCTAssertNotEqual(L10n.text(key), key, key)
        }
        let confirm = S2InlineHint.confirmEntry.title(mergedCount: 5)
        XCTAssertTrue(confirm.contains("5"), confirm)
        XCTAssertFalse(confirm.contains("{count}"), confirm)
        XCTAssertNotEqual(S2InlineHint.swipeUp.title(mergedCount: 0), S2InlineHint.markedOnce.title(mergedCount: 0))
        XCTAssertEqual(S2InlineHint.swipeUp.gestureDirection, .up)
        XCTAssertEqual(S2InlineHint.markedOnce.gestureDirection, .down)
        XCTAssertNil(S2InlineHint.confirmEntry.gestureDirection)
    }

    // MARK: - 断言 9：源码落位（S2View 接线、新文件纪律、目录）

    func testIC179I_SourceWiringAndCatalog() throws {
        let s2 = try XCTUnwrap(strippedSource(Self.s2ViewPath))
        let s2Raw = try XCTUnwrap(sourceText(Self.s2ViewPath))
        // 协调器由视图内部构造，init 无新形参。
        XCTAssertEqual(occurrences(of: "S2InlineHintCoordinator(", in: s2), 1)
        XCTAssertEqual(occurrences(of: "S2UserDefaultsInlineHintStore()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hintStore", in: s2), 0, "不经 init 注入")
        // 旧教程：不再启动、不再重放；其余接线与类型原样保留（停用不删）。
        XCTAssertEqual(occurrences(of: "tutorial.startIfNeeded()", in: s2), 0)
        XCTAssertEqual(occurrences(of: "tutorial.replay()", in: s2), 0)
        XCTAssertEqual(occurrences(of: "tutorial.leaveScreen()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "tutorial.assetDidBecomeMarked(assetID: assetID)", in: s2), 1)
        XCTAssertEqual(occurrences(of: "tutorial.assetDidBecomeUnmarked(assetID: assetID)", in: s2), 1)
        XCTAssertEqual(occurrences(of: "tutorial.assetDidJoinAlbum(assetID: record.assetID)", in: s2), 1)
        XCTAssertEqual(occurrences(of: "tutorial.albumPickerVisibilityDidChange(", in: s2), 1)
        XCTAssertEqual(occurrences(of: "tutorialOverlay(", in: s2), 2, "教程浮层 builder 声明 + 挂载都在")
        XCTAssertEqual(occurrences(of: "final class S2TutorialCoordinator: ObservableObject {", in: s2), 1)
        XCTAssertEqual(occurrences(of: "enum S2TutorialStep: Int, CaseIterable, Equatable {", in: s2), 1)
        XCTAssertEqual(occurrences(of: "if tutorial.activeStep == .albumGuide {", in: s2), 1, "IC172 切片起点仍在")
        // 新接线各恰一处。
        XCTAssertEqual(occurrences(of: "hints.startIfNeeded(", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hints.leaveScreen()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hints.assetDidBecomeMarked()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hints.assetDidBecomeUnmarked()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hints.mergedCountDidChange(count)", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hints.confirmEntryTapped()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hints.dismiss()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "hints.reset()", in: s2), 1)
        XCTAssertEqual(occurrences(of: "inlineHintOverlay(", in: s2), 2, "声明 + 挂载")
        XCTAssertEqual(occurrences(of: "S2InlineHintLayer(", in: s2), 1)
        // 追加在既有回调体内、不新开同表达式的 .onChange（IC141／143／151 取第一处匹配）。
        for expression in [
            "machine.pendingDeletionAssetIDs",
            "machine.sessionMergedPendingDeletionCount",
            "machine.currentAssetID",
            "machine.interfaceVisibility"
        ] {
            XCTAssertEqual(occurrences(of: ".onChange(of: " + expression + ") {", in: s2), 1, expression)
        }
        let markBody = onChangeBody(of: "machine.pendingDeletionAssetIDs", in: s2)
        XCTAssertEqual(occurrences(of: "hints.assetDidBecomeMarked()", in: markBody), 1)
        XCTAssertEqual(occurrences(of: "hints.assetDidBecomeUnmarked()", in: markBody), 1)
        XCTAssertEqual(occurrences(of: "tutorial.assetDidBecomeMarked(assetID: assetID)", in: markBody), 1)
        let countBody = onChangeBody(of: "machine.sessionMergedPendingDeletionCount", in: s2)
        let hintCall = try XCTUnwrap(countBody.range(of: "hints.mergedCountDidChange(count)"))
        let afterimageGuard = try XCTUnwrap(countBody.range(of: "guard markAfterimages.inFlightCount == 0"))
        XCTAssertLessThan(hintCall.lowerBound, afterimageGuard.lowerBound, "第 3 句的喂入在残影守卫之前")
        let assetBody = onChangeBody(of: "machine.currentAssetID", in: s2)
        XCTAssertGreaterThanOrEqual(occurrences(of: "tutorial.currentAssetDidChange(to:", in: assetBody), 1, "IC151 正对照")
        XCTAssertEqual(occurrences(of: "hints", in: assetBody), 0, "翻页不喂就地提示")
        // 入口按钮：点了即已会，且不改按钮数与禁用式。
        let topRow = try XCTUnwrap(slice(s2, from: "private var topBarRow: some View {", to: "private var topInfoArea: some View {"))
        XCTAssertEqual(occurrences(of: "hints.confirmEntryTapped()", in: topRow), 1)
        let trashAction = try XCTUnwrap(slice(topRow, from: "topInfoArea", to: "} label: {"))
        let payloadGuard = try XCTUnwrap(trashAction.range(of: "guard let payload = machine.makeExitPayload()"))
        let learnCall = try XCTUnwrap(trashAction.range(of: "hints.confirmEntryTapped()"))
        XCTAssertLessThan(payloadGuard.lowerBound, learnCall.lowerBound, "取不到载荷不算已会")
        XCTAssertEqual(occurrences(of: "Button {", in: topRow), 2)
        XCTAssertEqual(occurrences(of: ".disabled(!machine.canEnterConfirmation || tutorial.isRunning)", in: topRow), 1)
        // 浮层：与教程浮层同层、随 chrome 显隐。
        let overlay = try XCTUnwrap(slice(s2, from: "private func inlineHintOverlay(", to: "private func centerIndicatorOverlay("))
        XCTAssertEqual(occurrences(of: "s2ChromeVisibilityTransition(", in: overlay), 1)
        XCTAssertEqual(occurrences(of: "S2InlineHintLayer(", in: overlay), 1)
        XCTAssertEqual(occurrences(of: "S2OverlayLayout.topBarHeight", in: overlay), 1)
        XCTAssertEqual(occurrences(of: "hints.dismiss()", in: overlay), 1)
        XCTAssertEqual(occurrences(of: "mergedCount: displayedPendingCount", in: overlay), 1, "张数与角标显示值同源")
        XCTAssertEqual(occurrences(of: "hints.hintDidTimeOut(.markedOnce)", in: overlay), 1)
        XCTAssertEqual(occurrences(of: "S2InlineHintCoordinator.markedOnceAutoDismissSeconds", in: overlay), 1)
        XCTAssertEqual(occurrences(of: "Task.isCancelled", in: overlay), 1, "限时任务被取消后不得再收起新一句")
        XCTAssertEqual(occurrences(of: ".task(id: hint)", in: overlay), 1)
        // IC172／IC168 正对照：S2View 深色覆盖仍 6、面板三处系统材质仍 3。
        XCTAssertEqual(occurrences(of: "colorScheme, .dark)", in: s2Raw), 6)
        XCTAssertEqual(occurrences(of: ".background(.regularMaterial)", in: s2), 3)
        XCTAssertEqual(occurrences(of: "\"s2.tutorial.replay\"", in: s2Raw), 1, "「重看教程」按钮与 key 都在")

        // 新文件纪律：无裸字符串文案、无系统材质、无动态外观、无 actor 标注；只有 × 一只按钮吃点击。
        let hints = try XCTUnwrap(strippedSource(Self.hintsPath))
        let hintsRaw = try XCTUnwrap(sourceText(Self.hintsPath))
        XCTAssertEqual(occurrences(of: "Text(\"", in: hintsRaw), 0)
        XCTAssertEqual(occurrences(of: "return \"", in: hintsRaw), 0)
        XCTAssertEqual(occurrences(of: "Material", in: hints), 0)
        XCTAssertEqual(occurrences(of: "colorScheme", in: hints), 0)
        XCTAssertEqual(occurrences(of: "Color(uiColor:", in: hints), 0)
        XCTAssertEqual(occurrences(of: "@MainActor", in: hints), 0)
        XCTAssertEqual(occurrences(of: "import ", in: hintsRaw), 1, "只 import SwiftUI")
        XCTAssertEqual(occurrences(of: "Button {", in: hints), 1)
        XCTAssertEqual(occurrences(of: ".allowsHitTesting(false)", in: hints), 4, "标题行、副句、气泡底、小三角")
        XCTAssertEqual(occurrences(of: "S2TutorialGestureHint(direction:", in: hints), 1, "复用教程的循环手势示意")
        XCTAssertEqual(occurrences(of: "S0DeckMetrics.", in: hints), 7, "色只引用 S0 色板")
        XCTAssertEqual(occurrences(of: "@Published private(set) var activeHint", in: hints), 1)
        XCTAssertEqual(occurrences(of: "static let confirmThreshold = 5", in: hints), 1)
        XCTAssertEqual(occurrences(of: "static let markedOnceAutoDismissSeconds: TimeInterval = 6", in: hints), 1)
        XCTAssertEqual(occurrences(of: ".frame(", in: hints), 8)
        XCTAssertEqual(occurrences(of: "alignment: .trailing", in: hints), 2, "右上句框内右对齐 + 三角列右对齐")
        let metrics = try XCTUnwrap(slice(hints, from: "enum S2InlineHintMetrics {", to: "\n}\n"))
        XCTAssertEqual(occurrences(of: "static let ", in: metrics), 30, "登记值恰三十个")
        for key in Self.hintKeys {
            XCTAssertEqual(occurrences(of: "\"" + key + "\"", in: hintsRaw), 1, key)
        }
        XCTAssertEqual(S2InlineHintMetrics.cornerRadius, 22)
        XCTAssertEqual(S2InlineHintMetrics.titleFontSize, 16)
        XCTAssertEqual(S2InlineHintMetrics.subtitleFontSize, 13.5)
        XCTAssertEqual(S2InlineHintMetrics.dismissButtonSide, 26)
        XCTAssertEqual(S2InlineHintMetrics.dismissTouchTargetSide, S2OverlayLayout.minimumTouchTarget)
        XCTAssertEqual(S2InlineHintMetrics.dismissTouchOverhang, 9)
        XCTAssertEqual(S2InlineHintMetrics.centeredUnitBottomInset, S2CenterIndicatorView.containerHeight / 2 + 16)
        XCTAssertNil(S2InlineHint.confirmEntry.symbolName, "第 3 句照画布不带符号")
        XCTAssertNotNil(S2InlineHint.swipeUp.symbolName)
        XCTAssertEqual(S2InlineHintMetrics.pointerTrailingInset + S2InlineHintMetrics.pointerSide / 2 + S2InlineHintMetrics.trailingMargin,
                       S2OverlayLayout.chromeHorizontalMargin + S2OverlayLayout.chromeRowHeight / 2,
                       "小三角中心对齐右上圆钮中心")

        // 目录：七条新 key 各一条；旧教程十条仍在。
        let catalog = try XCTUnwrap(sourceText(Self.catalogPath))
        for key in Self.hintKeys {
            XCTAssertEqual(occurrences(of: "\"" + key + "\" : {", in: catalog), 1, key)
        }
        for key in ["step1", "step2", "step3", "step4", "step5", "step6", "done", "skip", "sheet_hint", "replay"] {
            XCTAssertEqual(occurrences(of: "\"s2.tutorial." + key + "\" : {", in: catalog), 1, key)
        }
    }

    // MARK: - 夹具

    private final class InMemoryHintStore: S2InlineHintStoring {
        private(set) var learned: Set<S2InlineHint>
        private(set) var resetCount = 0

        init(learned: Set<S2InlineHint> = []) {
            self.learned = learned
        }

        func isLearned(_ hint: S2InlineHint) -> Bool {
            learned.contains(hint)
        }

        func markLearned(_ hint: S2InlineHint) {
            learned.insert(hint)
        }

        func reset() {
            learned = []
            resetCount += 1
        }
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

    /// 读源码并剔掉 `//` 注释与字符串字面量内容。
    private func strippedSource(_ relativePath: String) -> String? {
        guard let source = sourceText(relativePath) else {
            return nil
        }
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

    /// 截取某个 `.onChange(of:)` 的闭包体（截到下一个 `.onChange(` 为止），口径同 IC141。
    private func onChangeBody(of expression: String, in text: String) -> String {
        let head = ".onChange(of: " + expression + ") {"
        guard let start = text.range(of: head) else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: ".onChange(") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start) else {
            return nil
        }
        let rest = text[startRange.upperBound...]
        guard let endRange = rest.range(of: end) else {
            return nil
        }
        return String(rest[..<endRange.lowerBound])
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchStart = haystack.startIndex
        while let found = haystack.range(
            of: needle,
            range: searchStart..<haystack.endIndex
        ) {
            count += 1
            searchStart = found.upperBound
        }
        return count
    }
}
