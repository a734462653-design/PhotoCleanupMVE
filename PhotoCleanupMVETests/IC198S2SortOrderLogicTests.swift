import Combine
import SwiftUI
import XCTest
@testable import PhotoCleanupMVE

/// IC-198：S2 排序系统 `Menu` 的逻辑层（SPEC-S2 v24 决策 59；取定 `Tasks/PLAN-S2S-sort-menu-rulings-20261009.md` 第三节）。
/// 不接视图——菜单、分页器与横栏的重同步归 E2。
/// A 看图页状态机重排：当前照片不变、下标改成它在新顺序里的位置、版本号 +1、放大态回 1x；交接里其余字段与合并计数读口原样；
///   不记看过、不改两个一次性信号、不发待删回调；退出载荷带新列表；之后的翻页按新顺序走。
/// B 看图页状态机拒绝：顺序没变、少一张、多一张、成员不同、重复一张，横栏拖动中、界面隐藏、相簿 sheet 打开——都不改任何东西。
/// C 协调器（真实范围）：改 `O` → S1 `O` 改了并写档、看图页同一台机器按新顺序、在途同步与写档照样成立、再改回、写回成功回 S1。
/// D 协调器拒绝：不在看图页、新值 = 现值、看图页拒绝（S1 的 `O` 改回原值、之后写回仍成功）、范围在看图期间被对账改过、
///   类别范围——都不改 S1 的 `O` 与看图页。
/// E 源码落位。
///
/// **夹具驱动**：照片库授权按拒绝（对账读不到 `R(T)`、静默不改）、范围由夹具直接交给 S1；菜单与重排后的画面归 E2 的 H。
final class IC198S2SortOrderLogicTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let machinePath = "PhotoCleanupMVE/Core/S2StateMachine.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let s1MachinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"

    private static let assets = ["asset-1", "asset-2", "asset-3", "asset-4", "asset-5", "asset-6", "asset-7"]
    private static let monthID = "范围-月"
    private static let monthAssets = ["资产-D", "资产-C", "资产-B", "资产-A"]

    // MARK: - A 看图页状态机重排

    func testIC198A_ReorderKeepsCurrentPhotoMovesIndexAndBumpsRevision() throws {
        let box = IC198CallbackBox(mergedCount: 3)
        let machine = makeMachine(box: box, pending: ["asset-1"])
        XCTAssertEqual(machine.currentIndex, 1)
        XCTAssertEqual(machine.orderedListRevision, 0)
        var willChangeCount = 0
        let subscription = machine.objectWillChange.sink { _ in willChangeCount += 1 }
        defer { subscription.cancel() }

        let reversed = Array(Self.assets.reversed())
        XCTAssertTrue(machine.reorderAssets(reversed))
        XCTAssertEqual(machine.orderedAssetIDs, reversed)
        XCTAssertEqual(machine.currentAssetID, "asset-2")
        XCTAssertEqual(machine.currentIndex, 5)
        XCTAssertEqual(machine.orderedListRevision, 1)
        XCTAssertGreaterThan(willChangeCount, 0)
        // 交接只换了顺序与当前张；会话、范围信息、进入时的待删集合原样，合并计数仍经原读口现取。
        XCTAssertEqual(machine.entry.orderedAssetIDs, reversed)
        XCTAssertEqual(machine.entry.currentAssetID, "asset-2")
        XCTAssertEqual(machine.entry.sessionID, "session-198")
        XCTAssertEqual(
            machine.entry.rangeDisplayInformation,
            S2RangeDisplayInformation(rangeID: "range-198", displayName: "测试范围", totalAssetCount: 7)
        )
        XCTAssertEqual(machine.entry.pendingDeletionAssetIDs, Set(["asset-1"]))
        box.mergedCount = 4
        XCTAssertEqual(machine.sessionMergedPendingDeletionCount, 4)
        // 不记看过、不改一次性信号、不发待删回调。
        XCTAssertEqual(machine.pendingDeletionAssetIDs, Set(["asset-1"]))
        XCTAssertEqual(machine.visitSeenAssetIDs, Set(["asset-2"]))
        XCTAssertNil(machine.lastCurrentAssetChangeCause)
        XCTAssertNil(machine.lastPendingDeletionChangeSource)
        XCTAssertEqual(box.pendingCallbacks, 0)
        XCTAssertTrue(box.settledAssets.isEmpty)
        // 退出载荷带新列表。
        let payload = try XCTUnwrap(machine.makeExitPayload())
        XCTAssertEqual(payload.continuationSnapshot.orderedAssetIDs, reversed)
        XCTAssertEqual(payload.continuationSnapshot.currentAssetID, "asset-2")
        XCTAssertEqual(payload.upstreamReturn.currentAssetID, "asset-2")
        // 之后的翻页按新顺序走：asset-2 的下一张是 asset-1。
        XCTAssertTrue(machine.handleHorizontalSwipe(direction: .next, startedAtPagingEdge: false, distance: 0, velocity: 0))
        XCTAssertEqual(machine.currentAssetID, "asset-1")
        XCTAssertEqual(machine.currentIndex, 6)
        // 再改回去：版本号 2。
        XCTAssertTrue(machine.reorderAssets(Self.assets))
        XCTAssertEqual(machine.currentAssetID, "asset-1")
        XCTAssertEqual(machine.currentIndex, 0)
        XCTAssertEqual(machine.orderedListRevision, 2)

        // 放大态（可见）：重排回 1x、偏移归零、界面仍可见。
        let zoomed = makeMachine(box: IC198CallbackBox(mergedCount: 0), scale: 2)
        XCTAssertEqual(zoomed.state, .visibleNxIdle)
        XCTAssertTrue(zoomed.reorderAssets(reversed))
        XCTAssertEqual(zoomed.scale, 1)
        XCTAssertEqual(zoomed.imageRequestScale, 1)
        XCTAssertEqual(zoomed.viewportOffset, .zero)
        XCTAssertEqual(zoomed.state, .visibleOneXIdle)
        XCTAssertEqual(zoomed.currentAssetID, "asset-2")
        XCTAssertEqual(zoomed.orderedListRevision, 1)
    }

    // MARK: - B 看图页状态机拒绝

    func testIC198B_ReorderRejectsUnchangedOrForeignListsAndBusyStates() {
        let box = IC198CallbackBox(mergedCount: 0)
        let machine = makeMachine(box: box)
        let reversed = Array(Self.assets.reversed())
        XCTAssertFalse(machine.reorderAssets(Self.assets), "顺序没变")
        XCTAssertFalse(machine.reorderAssets(Array(reversed.dropLast())), "少一张")
        XCTAssertFalse(machine.reorderAssets(reversed + ["asset-8"]), "多一张")
        XCTAssertFalse(machine.reorderAssets(["asset-8"] + Array(reversed.dropFirst())), "成员不同")
        XCTAssertFalse(machine.reorderAssets(["asset-2"] + Array(reversed.dropFirst())), "重复一张")
        assertUntouched(machine)

        XCTAssertTrue(machine.beginBottomStripDrag())
        XCTAssertFalse(machine.reorderAssets(reversed), "横栏拖动中")
        XCTAssertTrue(machine.endBottomStripDrag())
        assertUntouched(machine)

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertFalse(machine.reorderAssets(reversed), "界面隐藏")
        XCTAssertTrue(machine.handleSingleTap())
        assertUntouched(machine)

        XCTAssertNotNil(machine.presentAlbumPicker())
        XCTAssertEqual(machine.sheetState, .presented)
        XCTAssertFalse(machine.reorderAssets(reversed), "相簿 sheet 打开")
        assertUntouched(machine)
        XCTAssertEqual(box.pendingCallbacks, 0)
    }

    // MARK: - C 协调器（真实范围）

    @MainActor
    func testIC198C_CoordinatorReordersRealRangeAndKeepsSyncAndWriteBack() throws {
        let persistence = TestPersistenceIsolation.makePersistence()
        let coordinator = makeCoordinator(persistence: persistence)
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-198C"))
        completeRead(coordinator, ranges: [Self.monthRange(Self.monthAssets)])
        let s1 = try XCTUnwrap(coordinator.s1Machine)
        let handoff = try XCTUnwrap(s1.makeS2Handoff(for: Self.monthID))
        XCTAssertEqual(handoff.currentAssetID, "资产-D")
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        let s2 = try XCTUnwrap(coordinator.s2Machine)
        // 标 D，自动进入 C。
        XCTAssertTrue(s2.handleSwipeUp())
        XCTAssertEqual(s2.currentAssetID, "资产-C")
        XCTAssertEqual(s1.sessionStore.allPendingDeletionAssetIDs, Set(["资产-D"]))

        // 改成最旧在前：S1 的 `O` 改了并写档；看图页还是同一台机器，按新顺序、当前照片不变。
        XCTAssertTrue(coordinator.changeS2SortOrder(to: .oldestFirst))
        XCTAssertEqual(s1.sortOrder, .oldestFirst)
        XCTAssertEqual(persistence.loadS1Session()?.sortOrder, .oldestFirst)
        XCTAssertEqual(coordinator.route, .s2)
        XCTAssertTrue(coordinator.s2Machine === s2)
        XCTAssertEqual(s2.orderedAssetIDs, ["资产-A", "资产-B", "资产-C", "资产-D"])
        XCTAssertEqual(s2.currentAssetID, "资产-C")
        XCTAssertEqual(s2.currentIndex, 2)
        XCTAssertEqual(s2.orderedListRevision, 1)
        XCTAssertEqual(s2.pendingDeletionAssetIDs, Set(["资产-D"]))

        // 在途同步在新顺序下照样成立：标 C，自动进入新顺序里 C 的下一张 D，S1 的篮与档跟上。
        XCTAssertTrue(s2.handleSwipeUp())
        XCTAssertEqual(s2.currentAssetID, "资产-D")
        XCTAssertEqual(s1.sessionStore.allPendingDeletionAssetIDs, Set(["资产-D", "资产-C"]))
        XCTAssertEqual(
            persistence.loadS1Session()?.pendingDeletionAssetIDsByRangeID[Self.monthID],
            Set(["资产-D", "资产-C"])
        )

        // 再改回最新在前：D 是第一张，版本号 2。
        XCTAssertTrue(coordinator.changeS2SortOrder(to: .newestFirst))
        XCTAssertEqual(s1.sortOrder, .newestFirst)
        XCTAssertEqual(persistence.loadS1Session()?.sortOrder, .newestFirst)
        XCTAssertEqual(s2.orderedAssetIDs, Self.monthAssets)
        XCTAssertEqual(s2.currentIndex, 0)
        XCTAssertEqual(s2.orderedListRevision, 2)

        // 写回：退出守卫按换过的交接副本比对，成功回 S1；`K` 记离开时那张，篮不变。
        let payload = try XCTUnwrap(s2.makeExitPayload())
        XCTAssertTrue(coordinator.leaveS2(with: payload))
        XCTAssertEqual(coordinator.route, .s1)
        XCTAssertNil(coordinator.s2Machine)
        XCTAssertEqual(s1.sessionStore.continuationsByRangeID[Self.monthID]?.currentAssetID, "资产-D")
        XCTAssertEqual(s1.sessionStore.allPendingDeletionAssetIDs, Set(["资产-D", "资产-C"]))
    }

    // MARK: - D 协调器拒绝

    @MainActor
    func testIC198D_CoordinatorRejectsWithoutTouchingS1OrS2() throws {
        let coordinator = makeCoordinator()
        XCTAssertFalse(coordinator.changeS2SortOrder(to: .oldestFirst), "还没有会话")
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-198D"))
        completeRead(coordinator, ranges: [Self.monthRange(Self.monthAssets)])
        let s1 = try XCTUnwrap(coordinator.s1Machine)
        XCTAssertFalse(coordinator.changeS2SortOrder(to: .oldestFirst), "在 S1")
        XCTAssertEqual(s1.sortOrder, .newestFirst)

        XCTAssertTrue(coordinator.enterS2(from: try XCTUnwrap(s1.makeS2Handoff(for: Self.monthID))))
        let s2 = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertFalse(coordinator.changeS2SortOrder(to: .newestFirst), "新值 = 现值")
        XCTAssertEqual(s2.orderedListRevision, 0)

        // 看图页拒绝（界面隐藏）：S1 的 `O` 改回原值，看图页不动；之后写回仍成功（交接副本没换）。
        XCTAssertTrue(s2.handleSingleTap())
        XCTAssertFalse(coordinator.changeS2SortOrder(to: .oldestFirst), "看图页拒绝")
        XCTAssertEqual(s1.sortOrder, .newestFirst)
        XCTAssertEqual(s2.orderedAssetIDs, Self.monthAssets)
        XCTAssertEqual(s2.orderedListRevision, 0)
        XCTAssertTrue(s2.handleSingleTap())
        XCTAssertTrue(coordinator.leaveS2(with: try XCTUnwrap(s2.makeExitPayload())))
        XCTAssertEqual(coordinator.route, .s1)

        // 类别范围：列表由类别页给、与 `O` 无关——拒绝，S1 的 `O` 与看图页都不动。
        let shots = ["截图-大", "截图-中", "截图-小"]
        let virtualHandoff = try XCTUnwrap(
            s1.makeS2Handoff(virtualRangeID: "cat:screenshot",
                             displayName: "屏幕截图",
                             orderedAssetIDs: shots,
                             currentAssetID: shots[1])
        )
        XCTAssertTrue(coordinator.enterS2(from: virtualHandoff))
        let virtualS2 = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertFalse(coordinator.changeS2SortOrder(to: .oldestFirst), "类别范围")
        XCTAssertEqual(s1.sortOrder, .newestFirst)
        XCTAssertEqual(virtualS2.orderedAssetIDs, shots)
        XCTAssertEqual(virtualS2.orderedListRevision, 0)

        // 范围在看图期间被对账改过（少了一张）：新 `A(r, O)` 与看图页成员不同，拒绝。
        let other = makeCoordinator()
        XCTAssertTrue(other.enterS1(sessionID: "会话-198D2"))
        completeRead(other, ranges: [Self.monthRange(Self.monthAssets)])
        let otherS1 = try XCTUnwrap(other.s1Machine)
        XCTAssertTrue(other.enterS2(from: try XCTUnwrap(otherS1.makeS2Handoff(for: Self.monthID))))
        let otherS2 = try XCTUnwrap(other.s2Machine)
        XCTAssertTrue(otherS1.reconcile(with: .success([Self.monthRange(["资产-D", "资产-C", "资产-B"])])))
        XCTAssertFalse(other.changeS2SortOrder(to: .oldestFirst), "范围被对账改过")
        XCTAssertEqual(otherS1.sortOrder, .newestFirst)
        XCTAssertEqual(otherS2.orderedAssetIDs, Self.monthAssets)
        XCTAssertEqual(otherS2.orderedListRevision, 0)
    }

    // MARK: - E 源码落位

    func testIC198E_SourcePlacement() throws {
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        for (needle, expected) in [
            ("private(set) var entry: S2EntryContext", 1),
            ("let entry: S2EntryContext", 0),
            ("self.entry = entry", 1),
            ("@Published private(set) var orderedListRevision = 0", 1),
            ("orderedListRevision", 2),
            ("func reordered(_ orderedAssetIDs: [String], currentAssetID: String) -> S2EntryContext {", 1),
            ("func reorderAssets(_ newOrderedAssetIDs: [String]) -> Bool {", 1),
            ("entry = entry.reordered(newOrderedAssetIDs, currentAssetID: currentAssetID)", 1),
            ("markCurrentSeen()", 4),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: machine), expected, needle)
        }
        let reorder = try XCTUnwrap(slice(machine, from: "func reorderAssets(", to: "func makeExitPayload()"))
        for (needle, expected) in [
            ("guard controlsCanReceiveInput,", 1),
            ("Set(newOrderedAssetIDs) == Set(orderedAssetIDs)", 1),
            ("resetZoomAfterPhotoChange()", 1),
            ("orderedListRevision += 1", 1),
            ("markCurrentSeen()", 0),
            ("lastCurrentAssetChangeCause", 0),
            ("lastPendingDeletionChangeSource", 0),
            ("pendingDeletionDidChange", 0),
            ("seenAssetDidSettle", 0),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: reorder), expected, needle)
        }
        try assertOrder([
            "entry = entry.reordered(",
            "currentIndex = newIndex",
            "resetZoomAfterPhotoChange()",
            "orderedListRevision += 1",
        ], in: reorder)

        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        for (needle, expected) in [
            ("func changeS2SortOrder(to newValue: S1SortOrder) -> Bool {", 1),
            ("switchSortOrder(", 2),
            ("reorderAssets(", 1),
            ("s2EntryContext = ", 4),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: coordinator), expected, needle)
        }
        let change = try XCTUnwrap(
            slice(coordinator, from: "func changeS2SortOrder(", to: "func leaveS2(with payload: S2ExitPayload) -> Bool {")
        )
        for (needle, expected) in [
            ("guard route == .s2,", 1),
            ("!s1Machine.activeVirtualRangeIDs.contains(entryContext.rangeID)", 1),
            ("range.orderedAssetIDs(for: newValue)", 1),
            ("Set(reordered) == Set(entryContext.orderedAssetIDs)", 1),
            ("s1Machine.switchSortOrder(to: newValue)", 1),
            ("s1Machine.switchSortOrder(to: previousValue)", 1),
            ("s2Machine.reorderAssets(reordered)", 1),
            ("s2EntryContext = SessionStore.S2EntryContext(", 1),
            ("sortOrder: newValue.sessionSortOrder", 1),
            ("sessionStore = s1Machine.sessionStore", 1),
            ("recordSeenAssets(", 0),
            ("flushSeenArchive()", 0),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: change), expected, needle)
        }
        try assertOrder([
            "range.orderedAssetIDs(for: newValue)",
            "s1Machine.switchSortOrder(to: newValue)",
            "s2Machine.reorderAssets(reordered)",
            "s1Machine.switchSortOrder(to: previousValue)",
            "s2EntryContext = SessionStore.S2EntryContext(",
            "sessionStore = s1Machine.sessionStore",
        ], in: change)

        // S1 的排序入口不动（看图页期间 `isObscured` 恒为 false，协调器直接调它）。
        let s1Machine = try XCTUnwrap(strippedSource(Self.s1MachinePath))
        XCTAssertEqual(occurrences(of: "func switchSortOrder(to newValue: S1SortOrder) -> Bool {", in: s1Machine), 1)
        XCTAssertEqual(occurrences(of: "guard !isObscured, newValue != sortOrder else {", in: s1Machine), 1)

        // 不接视图：产品里只有协调器提到 `changeS2SortOrder(`、只有状态机提到 `orderedListRevision`、
        // 只有状态机与协调器提到 `reorderAssets(`。IC-199 接视图：横栏读 `orderedListRevision`（`S2View.swift`），
        // 菜单的选择经协调器 `makeS2SortMenu()` 转给 `changeS2SortOrder(`——仍只有协调器提到它。
        let sources = try productSources()
        XCTAssertEqual(Set(sources.filter { $0.value.contains("changeS2SortOrder(") }.keys), Set(["CleanupCoordinator.swift"]))
        XCTAssertEqual(
            Set(sources.filter { $0.value.contains("orderedListRevision") }.keys),
            Set(["S2StateMachine.swift", "S2View.swift"])
        )
        XCTAssertEqual(
            Set(sources.filter { $0.value.contains("reorderAssets(") }.keys),
            Set(["S2StateMachine.swift", "CleanupCoordinator.swift"])
        )
    }

    // MARK: - 夹具

    private func assertUntouched(_ machine: S2StateMachine, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(machine.orderedAssetIDs, Self.assets, file: file, line: line)
        XCTAssertEqual(machine.entry.orderedAssetIDs, Self.assets, file: file, line: line)
        XCTAssertEqual(machine.currentAssetID, "asset-2", file: file, line: line)
        XCTAssertEqual(machine.currentIndex, 1, file: file, line: line)
        XCTAssertEqual(machine.orderedListRevision, 0, file: file, line: line)
    }

    private func makeMachine(box: IC198CallbackBox, pending: Set<String> = [], scale: CGFloat = 1) -> S2StateMachine {
        let entry = S2EntryContext(
            sessionID: "session-198",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "range-198",
                displayName: "测试范围",
                totalAssetCount: 7
            ),
            orderedAssetIDs: Self.assets,
            currentAssetID: "asset-2",
            pendingDeletionAssetIDs: pending,
            sessionMergedPendingDeletionCountProvider: { box.mergedCount }
        )
        return S2StateMachine(
            entry: entry,
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: scale,
                viewportOffset: .zero
            ),
            parameters: parameters,
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in box.pendingCallbacks += 1 },
            recentAlbumDidChange: { _ in },
            seenAssetDidSettle: { box.settledAssets.append($0) }
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

    private static func monthRange(_ assetIDs: [String]) -> S1Range {
        S1Range(id: monthID, displayName: "2026 年 8 月", assetIDsNewestFirst: assetIDs)
    }

    /// 授权按拒绝：从 S2 返回的对账读不到 `R(T)`、静默不改；存在性一律在库。
    @MainActor
    private func makeCoordinator(
        persistence: SessionPersistence = TestPersistenceIsolation.makePersistence()
    ) -> CleanupCoordinator {
        let source = S1PhotoLibrarySource(
            authorizationStatus: { .denied },
            fetchAssets: { [] },
            fetchAssetCollections: { _, _ in [] },
            fetchExistingAssetIdentifiers: { identifiers in Set(identifiers) }
        )
        return CleanupCoordinator(
            photoLibrary: PhotoLibraryService(s1Source: source),
            persistence: persistence
        )
    }

    @MainActor
    private func completeRead(_ coordinator: CleanupCoordinator, ranges: [S1Range]) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
        XCTAssertEqual(machine.state, .ready)
    }

    private func assertOrder(_ needles: [String], in text: String, file: StaticString = #filePath, line: UInt = #line) throws {
        var searchStart = text.startIndex
        for needle in needles {
            let found = try XCTUnwrap(text.range(of: needle, range: searchStart..<text.endIndex), needle, file: file, line: line)
            searchStart = found.upperBound
        }
    }

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

    /// 产品目录下全部 `.swift`，按文件名剔注释与字符串内容（被查的文件名在产品目录里唯一）。
    private func productSources() throws -> [String: String] {
        let root = repoRoot().appendingPathComponent(Self.productRoot)
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [String: String] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            result[url.lastPathComponent] = stripped(source)
        }
        return result
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

/// 状态机回调与合并计数的夹具盒。
private final class IC198CallbackBox {
    var mergedCount: Int
    var pendingCallbacks = 0
    var settledAssets: [String] = []

    init(mergedCount: Int) {
        self.mergedCount = mergedCount
    }
}
