import Combine
import SwiftUI
import XCTest
@testable import PhotoCleanupMVE

/// IC-199：S2 排序系统 `Menu` 的界面层（SPEC-S2 v24 决策 59；取定 `Tasks/PLAN-S2S-sort-menu-rulings-20261009.md` 第四之二节）。
/// A 协调器 `makeS2SortMenu()`：真实范围给菜单（取值现读会话级 `O`、选择走 `changeS2SortOrder(to:)`），类别范围与不在看图页给 nil。
/// B 横栏重同步镜像：`S2BottomStripView` 两个回调体按同一写法搬进测试（源码断言 C 钉住视图里就是这一写法），驱动真实
///   `S2StateMachine` 与 `S2BottomStripMotionController`——列表重排那次直接跳到新格位（两个回调先后任意），翻页照旧带动画，
///   横栏重建后第一次翻页照旧带动画；对照：重排时一律带动画会进入滑行。
/// C 源码落位：菜单与下箭头、形参与接线、横栏两个回调体、IC-198 的「不接视图」钉子随改。
///
/// **夹具驱动**：菜单弹出、系统勾选、长按与菜单共存、分页器换页与重新取图、横栏实际观感归 H104 真机判定。
final class IC199S2SortMenuWiringTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let s2ViewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"

    private static let assets = ["asset-1", "asset-2", "asset-3", "asset-4", "asset-5", "asset-6", "asset-7"]
    private static let monthID = "范围-月"
    private static let monthAssets = ["资产-D", "资产-C", "资产-B", "资产-A"]

    // MARK: - A 协调器给的菜单

    @MainActor
    func testIC199A_CoordinatorMenuOnlyForRealRangesAndRoutesTheChoice() throws {
        let coordinator = makeCoordinator()
        XCTAssertNil(coordinator.makeS2SortMenu(), "还没有会话")
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-199A"))
        completeRead(coordinator, ranges: [Self.monthRange(Self.monthAssets)])
        let s1 = try XCTUnwrap(coordinator.s1Machine)
        XCTAssertNil(coordinator.makeS2SortMenu(), "在 S1")

        XCTAssertTrue(coordinator.enterS2(from: try XCTUnwrap(s1.makeS2Handoff(for: Self.monthID))))
        let s2 = try XCTUnwrap(coordinator.s2Machine)
        let menu = try XCTUnwrap(coordinator.makeS2SortMenu())
        XCTAssertEqual(menu.currentOrder(), .newestFirst)
        // 选择走协调器：S1 的 `O` 改了、看图页按新顺序重排，菜单取值随之现读。
        XCTAssertTrue(menu.changeOrder(.oldestFirst))
        XCTAssertEqual(s1.sortOrder, .oldestFirst)
        XCTAssertEqual(s2.orderedAssetIDs, ["资产-A", "资产-B", "资产-C", "资产-D"])
        XCTAssertEqual(s2.currentAssetID, "资产-D")
        XCTAssertEqual(s2.orderedListRevision, 1)
        XCTAssertEqual(menu.currentOrder(), .oldestFirst)
        // 再选当前项：协调器拒绝，什么都不动。
        XCTAssertFalse(menu.changeOrder(.oldestFirst))
        XCTAssertEqual(s2.orderedListRevision, 1)
        XCTAssertTrue(coordinator.leaveS2(with: try XCTUnwrap(s2.makeExitPayload())))
        XCTAssertNil(coordinator.makeS2SortMenu(), "回到 S1")

        // 类别范围：不给菜单。
        let shots = ["截图-大", "截图-中", "截图-小"]
        XCTAssertTrue(coordinator.enterS2(from: try XCTUnwrap(
            s1.makeS2Handoff(virtualRangeID: "cat:screenshot",
                             displayName: "屏幕截图",
                             orderedAssetIDs: shots,
                             currentAssetID: shots[1])
        )))
        XCTAssertNil(coordinator.makeS2SortMenu(), "类别范围")
    }

    // MARK: - B 横栏重同步

    func testIC199B_StripJumpsOnReorderAndStillAnimatesPaging() throws {
        let reversed = Array(Self.assets.reversed())

        // 一、先 `currentIndex` 回调、后版本号回调：直接跳到新格位，不起帧驱动。
        let first = try makeStripFixture()
        XCTAssertEqual(first.motion.phase, .idle)
        XCTAssertEqual(first.motion.trackedIndex, 1)
        XCTAssertTrue(first.machine.reorderAssets(reversed))
        XCTAssertEqual(first.machine.currentIndex, 5)
        first.mirror.currentIndexChanged()
        first.mirror.revisionChanged()
        assertJumped(first, to: 5)

        // 之后的翻页照旧带动画（版本号已记过）。
        XCTAssertTrue(first.machine.handleHorizontalSwipe(direction: .next, startedAtPagingEdge: false, distance: 0, velocity: 0))
        XCTAssertEqual(first.machine.currentIndex, 6)
        first.mirror.currentIndexChanged()
        XCTAssertEqual(first.motion.phase, .settling)
        XCTAssertEqual(first.driver.startCount, 1)
        XCTAssertEqual(first.motion.trackedIndex, 6)

        // 二、先版本号回调、后 `currentIndex` 回调：结果相同。
        let second = try makeStripFixture()
        XCTAssertTrue(second.machine.reorderAssets(reversed))
        second.mirror.revisionChanged()
        second.mirror.currentIndexChanged()
        assertJumped(second, to: 5)

        // 三、横栏重建（镜像按构造时的版本号起算）：第一次翻页照旧带动画。
        let rebuilt = IC199StripSyncMirror(machine: second.machine, motion: second.motion)
        XCTAssertEqual(rebuilt.stripSyncedRevision, 1)
        XCTAssertTrue(second.machine.handleHorizontalSwipe(direction: .next, startedAtPagingEdge: false, distance: 0, velocity: 0))
        rebuilt.currentIndexChanged()
        XCTAssertEqual(second.motion.phase, .settling)
        XCTAssertEqual(second.driver.startCount, 1)

        // 对照：重排那次若照旧带动画，横栏会从旧格位滑行到新格位（本卡要避免的观感）。
        let control = try makeStripFixture()
        XCTAssertTrue(control.machine.reorderAssets(reversed))
        control.motion.synchronize(count: Self.assets.count, currentIndex: control.machine.currentIndex, animated: true)
        XCTAssertEqual(control.motion.phase, .settling)
        XCTAssertEqual(control.driver.startCount, 1)
    }

    // MARK: - C 源码落位

    func testIC199C_SourceWiring() throws {
        let view = try XCTUnwrap(strippedSource(Self.s2ViewPath))
        for (needle, expected) in [
            ("struct S2SortMenu {", 1),
            ("let currentOrder: () -> S1SortOrder", 1),
            ("let changeOrder: (S1SortOrder) -> Bool", 1),
            ("enum S2SortMenuMetrics {", 1),
            ("private let sortMenu: S2SortMenu?", 1),
            ("sortMenu: S2SortMenu? = nil", 1),
            ("self.sortMenu = sortMenu", 1),
            ("topCenterCapsule", 2),
            ("S2SortMenuMetrics.chevronSymbol", 1),
            ("S2SortMenuMetrics.chevronPointSize", 1),
            ("S2SortMenuMetrics.chevronSpacing", 1),
            ("@State private var stripSyncedRevision: Int", 1),
            ("_stripSyncedRevision = State(initialValue: machine.orderedListRevision)", 1),
            ("let reordered = machine.orderedListRevision != stripSyncedRevision", 1),
            ("animated: !reordered", 1),
            (".onChange(of: machine.orderedListRevision) { _, revision in", 1),
            ("machine.orderedListRevision", 4),
            (".onChange(of: machine.currentIndex) {", 1),
            (".onChange(of: machine.orderedAssetIDs.count) {", 1),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: view), expected, needle)
        }
        // 中胶囊：顶排里只经 builder，长按进标定面板仍挂在外层。
        let topBar = try XCTUnwrap(slice(view, from: "private var topBarRow: some View {", to: "private var topCenterCapsule: some View {"))
        XCTAssertEqual(occurrences(of: "topCenterCapsule\n", in: topBar), 1)
        XCTAssertEqual(occurrences(of: "topInfoArea", in: topBar), 0)
        XCTAssertEqual(occurrences(of: ".onLongPressGesture(", in: topBar), 1)
        try assertOrder(["topCenterCapsule", ".frame(maxWidth: .infinity, maxHeight: .infinity)", ".onLongPressGesture("], in: topBar)
        let capsule = try XCTUnwrap(slice(view, from: "private var topCenterCapsule: some View {", to: "private var topInfoArea: some View {"))
        for (needle, expected) in [
            ("if let sortMenu {", 1),
            (" Menu {", 1),
            ("Picker(", 1),
            ("get: { sortMenu.currentOrder() }", 1),
            ("set: { _ = sortMenu.changeOrder($0) }", 1),
            ("S1PageHeaderPresentation.sortTitle(", 2),
            (".tag(S1SortOrder.newestFirst)", 1),
            (".tag(S1SortOrder.oldestFirst)", 1),
            ("topInfoArea\n", 2),
            (".s2ChromeCapsuleGlass()", 2),
            (".accessibilityHint(", 1),
            ("onLongPressGesture", 0),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: capsule), expected, "topCenterCapsule: " + needle)
        }
        let info = try XCTUnwrap(slice(view, from: "private var topInfoArea: some View {", to: "private var confirmationEntry"))
        XCTAssertEqual(occurrences(of: "if sortMenu != nil {", in: info), 1)
        // 主行日期放进 `Menu` 的 label：用具体动态色，不用层级 `.primary`（启用态按钮标签里会解析成 tint，IC-121 A）。
        XCTAssertEqual(occurrences(of: ".foregroundStyle(S2ChromeForeground.onGlassPrimary)", in: info), 1)
        XCTAssertEqual(occurrences(of: ".foregroundStyle(.primary)", in: info), 0)
        XCTAssertEqual(occurrences(of: "HStack(spacing: S2SortMenuMetrics.chevronSpacing) {", in: info), 1)
        try assertOrder(["Text(verbatim: dateText)", "if sortMenu != nil {", "Text(verbatim: S2TopBarInfoPresentation.subtitleText("], in: info)
        // 横栏两个回调：先判版本号再记、再同步；版本号回调不带动画参数（默认不滑行）。
        let indexBody = try XCTUnwrap(slice(view, from: ".onChange(of: machine.currentIndex) {", to: ".onChange(of: machine.orderedListRevision) {"))
        try assertOrder(["let reordered = ", "stripSyncedRevision = machine.orderedListRevision", "motion.synchronize(", "animated: !reordered"], in: indexBody)
        let revisionBody = try XCTUnwrap(slice(view, from: ".onChange(of: machine.orderedListRevision) {", to: ".onChange(of: machine.orderedAssetIDs.count) {"))
        XCTAssertEqual(occurrences(of: "stripSyncedRevision = revision", in: revisionBody), 1)
        XCTAssertEqual(occurrences(of: "motion.synchronize(", in: revisionBody), 1)
        XCTAssertEqual(occurrences(of: "animated:", in: revisionBody), 0)

        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "func makeS2SortMenu() -> S2SortMenu? {", in: coordinator), 1)
        let make = try XCTUnwrap(slice(coordinator, from: "func makeS2SortMenu() -> S2SortMenu? {", to: "func changeS2SortOrder(to newValue: S1SortOrder) -> Bool {"))
        for (needle, expected) in [
            ("guard route == .s2,", 1),
            ("!s1Machine.activeVirtualRangeIDs.contains(entryContext.rangeID)", 1),
            ("[weak self]", 2),
            ("self?.s1Machine?.sortOrder ?? .newestFirst", 1),
            ("self?.changeS2SortOrder(to: newValue) ?? false", 1),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: make), expected, "makeS2SortMenu: " + needle)
        }
        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "sortMenu: coordinator.makeS2SortMenu()", in: app), 1)
        XCTAssertEqual(occurrences(of: "changeS2SortOrder(", in: app), 0)

        // 产品里：只有协调器构造菜单（`return S2SortMenu(`；`makeS2SortMenu(` 本身含 `S2SortMenu(` 子串，故带 `return`）、
        // 只有协调器与 App 提到 `makeS2SortMenu(`、只有状态机与看图页提到 `orderedListRevision`。
        let sources = try productSources()
        XCTAssertEqual(Set(sources.filter { $0.value.contains("return S2SortMenu(") }.keys), Set(["CleanupCoordinator.swift"]))
        XCTAssertEqual(
            Set(sources.filter { $0.value.contains("makeS2SortMenu(") }.keys),
            Set(["CleanupCoordinator.swift", "PhotoCleanupMVEApp.swift"])
        )
        XCTAssertEqual(
            Set(sources.filter { $0.value.contains("orderedListRevision") }.keys),
            Set(["S2StateMachine.swift", "S2View.swift"])
        )
        XCTAssertEqual(Set(sources.filter { $0.value.contains("changeS2SortOrder(") }.keys), Set(["CleanupCoordinator.swift"]))
    }

    // MARK: - 夹具

    private func assertJumped(_ fixture: IC199StripFixture, to index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let layout = fixture.motion.layout
        XCTAssertEqual(fixture.motion.phase, .idle, file: file, line: line)
        XCTAssertEqual(fixture.motion.trackedIndex, index, file: file, line: line)
        XCTAssertEqual(
            fixture.motion.contentX,
            layout.clampedContentX(layout.contentCenterX(of: index), count: Self.assets.count),
            accuracy: 0.001,
            file: file,
            line: line
        )
        XCTAssertEqual(fixture.motion.expansion, 1, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(fixture.driver.startCount, 0, file: file, line: line)
        XCTAssertEqual(fixture.mirror.stripSyncedRevision, fixture.machine.orderedListRevision, file: file, line: line)
    }

    private func makeStripFixture() throws -> IC199StripFixture {
        let parameters = try XCTUnwrap(S2CalibrationConfiguration.factoryPlaceholder.resolvedParameters)
        let entry = S2EntryContext(
            sessionID: "session-199",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "range-199",
                displayName: "测试范围",
                totalAssetCount: Self.assets.count
            ),
            orderedAssetIDs: Self.assets,
            currentAssetID: "asset-2",
            pendingDeletionAssetIDs: [],
            sessionMergedPendingDeletionCountProvider: { 0 }
        )
        let machine = try XCTUnwrap(S2StateMachine(
            entry: entry,
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            ),
            parameters: parameters,
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in }
        ))
        let driver = S2BottomStripManualFrameDriver()
        let clock = S2StripTestClock()
        let motion = S2BottomStripMotionController(
            layout: S2BottomStripLayout(metrics: parameters.bottomStripMetrics),
            hooks: S2BottomStripMotionController.hooks(machine: machine, onPhotoSwitch: {}),
            clock: { clock.now },
            frameDriver: driver
        )
        // 与 `S2BottomStripView.init` 同：首帧即居中当前张。
        motion.synchronize(count: machine.orderedAssetIDs.count, currentIndex: machine.currentIndex)
        return IC199StripFixture(
            machine: machine,
            motion: motion,
            driver: driver,
            mirror: IC199StripSyncMirror(machine: machine, motion: motion)
        )
    }

    private static func monthRange(_ assetIDs: [String]) -> S1Range {
        S1Range(id: monthID, displayName: "2026 年 8 月", assetIDsNewestFirst: assetIDs)
    }

    /// 授权按拒绝：从 S2 返回的对账读不到 `R(T)`、静默不改；存在性一律在库。
    @MainActor
    private func makeCoordinator() -> CleanupCoordinator {
        let source = S1PhotoLibrarySource(
            authorizationStatus: { .denied },
            fetchAssets: { [] },
            fetchAssetCollections: { _, _ in [] },
            fetchExistingAssetIdentifiers: { identifiers in Set(identifiers) }
        )
        return CleanupCoordinator(
            photoLibrary: PhotoLibraryService(s1Source: source),
            persistence: TestPersistenceIsolation.makePersistence()
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

private struct IC199StripFixture {
    let machine: S2StateMachine
    let motion: S2BottomStripMotionController
    let driver: S2BottomStripManualFrameDriver
    let mirror: IC199StripSyncMirror
}

/// `S2BottomStripView` 两个回调体的镜像：写法与视图里逐句相同（源码断言 C 钉住视图侧）；初值同视图的 `State(initialValue:)`。
private final class IC199StripSyncMirror {
    let machine: S2StateMachine
    let motion: S2BottomStripMotionController
    var stripSyncedRevision: Int

    init(machine: S2StateMachine, motion: S2BottomStripMotionController) {
        self.machine = machine
        self.motion = motion
        stripSyncedRevision = machine.orderedListRevision
    }

    func currentIndexChanged() {
        let currentIndex = machine.currentIndex
        let reordered = machine.orderedListRevision != stripSyncedRevision
        stripSyncedRevision = machine.orderedListRevision
        motion.synchronize(
            count: machine.orderedAssetIDs.count,
            currentIndex: currentIndex,
            animated: !reordered
        )
    }

    func revisionChanged() {
        stripSyncedRevision = machine.orderedListRevision
        motion.synchronize(
            count: machine.orderedAssetIDs.count,
            currentIndex: machine.currentIndex
        )
    }
}
