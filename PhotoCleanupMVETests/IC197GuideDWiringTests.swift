import SwiftUI
import XCTest
@testable import PhotoCleanupMVE

/// IC-197：S2 教学引导 D 的接线与 v23 三句退役（SPEC-S2 v24 第二节第 6 部分；取定 `Tasks/PLAN-S2D-guide-rulings-20261009.md`
/// 第六节）。D1（IC-195）的协调器与状态机信号、D2a（IC-196）的视图在本卡接进 `S2View`；`S2InlineHints.swift` 与七条
/// `s2.hint.*` 删除。
/// A／B 接线镜像：把 `S2View` 的进入、待删集合、当前张、合并计数、在显一项五处回调体按同一写法搬进测试（源码断言 C 钉住视图里
///   就是这一写法），驱动真实 `S2StateMachine` + 引导协调器——A 走完四步与完成，B 放大态不停与跳过。
/// C 源码落位：S2View 接线、三层的层序与 builder、旧名退役、六步教程停用不删的既有接线、目录。
///
/// **夹具驱动**：回调先后由镜像固定（引导协调器对同一次更新里的先后不敏感，IC-195 已枚举证明）；观感、动画、层级、命中
/// 与真实手势时序归 H 真机判定。
final class IC197GuideDWiringTests: XCTestCase {
    private static let s2ViewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let retiredHintsPath = "PhotoCleanupMVE/Features/S2/S2InlineHints.swift"
    private static let retiredTestPath = "PhotoCleanupMVETests/IC179InlineHintsTests.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let productRoot = "PhotoCleanupMVE"

    // MARK: - A 接线镜像

    func testIC197A_WiringMirrorWalksTheFourStepsOnTheRealStateMachine() {
        let store = IC197InMemoryGuideStore()
        let machine = makeMachine()
        let view = IC197ViewMirror(machine: machine, guide: S2GuideCoordinator(store: store))
        // 进门：第 1 步 + 进门压暗；开关同步为真（第 2 步会在下一次标记时出现）。
        view.appear()
        XCTAssertEqual(view.guide.display, .step(.swipeUp))
        XCTAssertTrue(view.guide.showsIntroDim)
        XCTAssertTrue(machine.holdsPageAfterNextMark)
        // 真实上滑：停在刚标记的那张，出第 2 步，压暗消失，开关被吃掉且不再打开。
        XCTAssertTrue(machine.handleSwipeUp())
        view.pump()
        XCTAssertEqual(machine.currentAssetID, "asset-2")
        XCTAssertEqual(view.guide.display, .step(.markedOnce))
        XCTAssertFalse(view.guide.showsIntroDim)
        XCTAssertFalse(machine.holdsPageAfterNextMark)
        // 真实下滑撤标（来源 `.undo`）：第 2 步学会，出第 3 步。
        XCTAssertTrue(machine.handleSwipeDown())
        view.pump()
        XCTAssertEqual(machine.lastPendingDeletionChangeSource, .undo)
        XCTAssertEqual(view.guide.display, .step(.undone))
        // 左右滑翻看（原因 `.browse`）：第 3 步学会、收起。
        XCTAssertTrue(machine.handleHorizontalSwipe(direction: .next, startedAtPagingEdge: false, distance: 0, velocity: 0))
        view.pump()
        XCTAssertEqual(machine.currentAssetID, "asset-3")
        XCTAssertNil(view.guide.display)
        XCTAssertEqual(store.learned, Set([S2GuideStep.swipeUp, .markedOnce, .undone]))
        XCTAssertFalse(machine.holdsPageAfterNextMark)
        // 连标五张：合并计数上升到 5 时出第 4 步（标记后自动进下一张，不停）。
        for expected in ["asset-4", "asset-5", "asset-6", "asset-7"] {
            XCTAssertTrue(machine.handleSwipeUp())
            view.pump()
            XCTAssertEqual(machine.currentAssetID, expected)
            XCTAssertNil(view.guide.display, expected)
        }
        XCTAssertTrue(machine.handleSwipeUp())
        view.pump()
        XCTAssertEqual(machine.sessionMergedPendingDeletionCount, 5)
        XCTAssertEqual(view.guide.display, .step(.confirmEntry))
        // 真进确认页：第 4 步学会；完成提示留到下一次进入（J8／J10）。
        view.guide.confirmEntryTapped()
        XCTAssertNil(view.guide.display)
        XCTAssertFalse(store.hasShownCompletion)
        view.leave()
        let again = IC197ViewMirror(machine: makeMachine(), guide: S2GuideCoordinator(store: store))
        again.appear()
        XCTAssertEqual(again.guide.display, .completion)
        XCTAssertTrue(store.hasShownCompletion)
        again.guide.completionDidTimeOut()
        XCTAssertNil(again.guide.display)
    }

    func testIC197B_ZoomedMarkDoesNotHoldAndSkipStopsTheVisit() {
        // 放大态上滑：照旧进下一张，不出第 2 步、也不记本次收起；回到 1x 的下一次标记才停住出第 2 步（L3）。
        let store = IC197InMemoryGuideStore()
        let machine = makeMachine(scale: 2)
        let view = IC197ViewMirror(machine: machine, guide: S2GuideCoordinator(store: store))
        view.appear()
        XCTAssertTrue(machine.holdsPageAfterNextMark)
        XCTAssertTrue(machine.handleSwipeUp())
        view.pump()
        XCTAssertEqual(machine.currentAssetID, "asset-3", "Nx 不停留")
        XCTAssertEqual(machine.lastCurrentAssetChangeCause, .markAdvance)
        XCTAssertNil(view.guide.display)
        XCTAssertTrue(view.guide.collapsedThisVisit.isEmpty)
        XCTAssertTrue(machine.holdsPageAfterNextMark, "开关留给下一次 1x 标记")
        XCTAssertTrue(machine.handleSwipeUp())
        view.pump()
        XCTAssertEqual(machine.currentAssetID, "asset-3", "1x 上那一下停住")
        XCTAssertEqual(view.guide.display, .step(.markedOnce))

        // 跳过：收起、本次不再出任何一项、开关关掉；下一次进入仍按规则出。
        let skipStore = IC197InMemoryGuideStore()
        let skipMachine = makeMachine()
        let skipView = IC197ViewMirror(machine: skipMachine, guide: S2GuideCoordinator(store: skipStore))
        skipView.appear()
        skipView.skip()
        XCTAssertNil(skipView.guide.display)
        XCTAssertFalse(skipView.guide.showsIntroDim)
        XCTAssertFalse(skipMachine.holdsPageAfterNextMark)
        XCTAssertTrue(skipMachine.handleSwipeUp())
        skipView.pump()
        XCTAssertEqual(skipMachine.currentAssetID, "asset-3", "跳过后不停留")
        XCTAssertNil(skipView.guide.display)
        skipView.leave()
        let next = IC197ViewMirror(machine: makeMachine(), guide: S2GuideCoordinator(store: skipStore))
        next.appear()
        XCTAssertNil(next.guide.display, "第 1 步已会（跳过那次进入里真标记过）")
        XCTAssertTrue(next.machine.holdsPageAfterNextMark, "第 2 步未会 → 下一次标记仍停")
    }

    // MARK: - B 源码落位

    func testIC197C_SourceWiringLayersAndRetirement() throws {
        let s2 = try XCTUnwrap(strippedSource(Self.s2ViewPath))
        let s2Raw = try XCTUnwrap(sourceText(Self.s2ViewPath))
        // 协调器：视图内部构造、默认存储，每次进入只开一次。
        for (needle, expected) in [
            ("S2GuideCoordinator()", 1),
            ("@State private var guideStarted = false", 1),
            ("guide.start(mergedCount: machine.sessionMergedPendingDeletionCount)", 1),
            ("guide.leaveScreen()", 1),
            ("guide.confirmEntryTapped()", 1),
            ("guide.reset()", 1),
            ("guide.skip()", 1),
            ("guide.completionDidTimeOut()", 1),
            ("guide.mergedCountDidChange(count)", 1),
            ("guide.isInterfaceVisible = machine.interfaceVisibility == .visible", 4),
            ("guide.isInterfaceVisible = visibility == .visible", 1),
            ("stayedOnMarkedAsset: inserted.contains(machine.currentAssetID)", 1),
            ("source: machine.lastPendingDeletionChangeSource ?? .undo", 1),
            ("cause: machine.lastCurrentAssetChangeCause ?? .browse", 1),
            ("machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark", 6),
            (".onChange(of: guide.display) {", 1),
            ("guideIntroScrimOverlay(", 2),
            ("guideGestureOverlay(", 2),
            ("guideCardOverlay(", 2),
            ("hints.", 0),
            ("S2InlineHint", 0),
            ("inlineHintOverlay", 0),
            ("tutorial.startIfNeeded()", 0),
            ("tutorial.replay()", 0),
            ("tutorial.leaveScreen()", 1),
            ("tutorial.assetDidBecomeMarked(assetID: assetID)", 1),
            ("tutorial.assetDidBecomeUnmarked(assetID: assetID)", 1),
            ("tutorial.assetDidJoinAlbum(assetID: record.assetID)", 1),
            ("tutorial.albumPickerVisibilityDidChange(", 1),
            ("tutorialOverlay(", 2),
            ("final class S2TutorialCoordinator: ObservableObject {", 1),
            ("if tutorial.activeStep == .albumGuide {", 1),
            (".background(.regularMaterial)", 3)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: s2), expected, needle)
        }
        XCTAssertEqual(occurrences(of: "colorScheme, .dark)", in: s2Raw), 6)
        XCTAssertEqual(occurrences(of: "\"s2.tutorial.replay\"", in: s2Raw), 1)

        // 只开一次：先写可见、再 start，都在同一个守卫里。
        let entry = try XCTUnwrap(slice(s2, from: "if !guideStarted {", to: "machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark"))
        try assertOrder(["guideStarted = true", "guide.isInterfaceVisible = machine.interfaceVisibility == .visible", "guide.start(mergedCount:"], in: entry)

        // 回调体：追加在既有体内、不新开同表达式的 `.onChange`（第一处匹配陷阱）。
        for expression in [
            "machine.pendingDeletionAssetIDs",
            "machine.sessionMergedPendingDeletionCount",
            "machine.currentAssetID",
            "machine.interfaceVisibility"
        ] {
            XCTAssertEqual(occurrences(of: ".onChange(of: " + expression + ") {", in: s2), 1, expression)
        }
        let markBody = onChangeBody(of: "machine.pendingDeletionAssetIDs", in: s2)
        try assertOrder([
            "tutorial.assetDidBecomeUnmarked(assetID: assetID)",
            "guide.isInterfaceVisible = machine.interfaceVisibility == .visible",
            "guide.assetDidBecomeMarked(",
            "stayedOnMarkedAsset: inserted.contains(machine.currentAssetID)",
            "guide.assetDidBecomeUnmarked(",
            "source: machine.lastPendingDeletionChangeSource ?? .undo",
            "machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark",
            "refreshCenterIndicator(animated: true)"
        ], in: markBody)
        let assetBody = onChangeBody(of: "machine.currentAssetID", in: s2)
        try assertOrder([
            "tutorial.currentAssetDidChange(to: assetID)",
            "guide.isInterfaceVisible = machine.interfaceVisibility == .visible",
            "guide.currentAssetDidChange(",
            "cause: machine.lastCurrentAssetChangeCause ?? .browse",
            "machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark",
            "centerIndicatorState = nil"
        ], in: assetBody)
        let countBody = onChangeBody(of: "machine.sessionMergedPendingDeletionCount", in: s2)
        try assertOrder([
            "guide.isInterfaceVisible = machine.interfaceVisibility == .visible",
            "guide.mergedCountDidChange(count)",
            "guard markAfterimages.inFlightCount == 0"
        ], in: countBody)
        let visibilityBody = onChangeBody(of: "machine.interfaceVisibility", in: s2)
        XCTAssertEqual(occurrences(of: "guide.isInterfaceVisible = visibility == .visible", in: visibilityBody), 1)

        // 确认入口：取到载荷才算学会；按钮数与禁用式不变。
        let topRow = try XCTUnwrap(slice(s2, from: "private var topBarRow: some View {", to: "private var topInfoArea: some View {"))
        try assertOrder(["guard let payload = machine.makeExitPayload()", "guide.confirmEntryTapped()", "onConfirmation(payload)"], in: topRow)
        XCTAssertEqual(occurrences(of: "Button {", in: topRow), 2)
        XCTAssertEqual(occurrences(of: ".disabled(!machine.canEnterConfirmation || tutorial.isRunning)", in: topRow), 1)

        // 层序：主图 → 压暗 → chrome → 示范 → 中央状态指示 → 教程浮层 → 教练卡层。
        let layers = try XCTUnwrap(slice(s2, from: "let viewportMetrics = S2ViewportLayout.metrics(", to: "S2SafeAreaInsetsReader(insets: $safeAreaInsets)"))
        try assertOrder([
            "mainPhoto(",
            "guideIntroScrimOverlay(",
            "interfaceOverlay(",
            "guideGestureOverlay(",
            "centerIndicatorOverlay(metrics: viewportMetrics)",
            "tutorialOverlay(",
            "guideCardOverlay(viewportSize: geometry.size)"
        ], in: layers)

        // 三个 builder。
        let scrim = try XCTUnwrap(slice(s2, from: "private func guideIntroScrimOverlay(", to: "private func guideGestureOverlay("))
        for (needle, expected) in [
            ("if guide.showsIntroDim {", 1),
            ("S2GuideIntroScrim(", 1),
            ("S2GuideDLayout.introScrimFrame(", 1),
            ("value: guide.showsIntroDim", 1),
            ("s2ChromeVisibilityTransition(", 1),
            (".allowsHitTesting(false)", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: scrim), expected, "scrim " + needle)
        }
        let gesture = try XCTUnwrap(slice(s2, from: "private func guideGestureOverlay(", to: "private func guideCardOverlay("))
        for (needle, expected) in [
            ("S2GuideDGestureLayer(", 1),
            ("display: guide.display", 1),
            ("photoCenterY: metrics.oneXDisplayCenterY", 1),
            ("s2ChromeVisibilityTransition(", 1),
            (".allowsHitTesting(false)", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: gesture), expected, "gesture " + needle)
        }
        let card = try XCTUnwrap(slice(s2, from: "private func guideCardOverlay(", to: "private var guideLearnedSteps: Set<S2GuideStep> {"))
        for (needle, expected) in [
            ("S2GuideDCardLayer(", 1),
            ("mergedCount: displayedPendingCount", 1),
            ("learnedSteps: guideLearnedSteps", 1),
            ("guide.skip()", 1),
            ("s2ChromeVisibilityTransition(", 1),
            (".task(id: guide.display)", 1),
            ("S2GuideCoordinator.completionAutoDismissSeconds", 1),
            ("Task.isCancelled", 1),
            ("guide.completionDidTimeOut()", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: card), expected, "card " + needle)
        }
        try assertOrder(["s2ChromeVisibilityTransition(", ".task(id: guide.display)"], in: card)

        // 退役：v23 三句文件与它的测试文件不在了，产品里不再有 `S2InlineHint`。
        XCTAssertNil(sourceText(Self.retiredHintsPath))
        XCTAssertNil(sourceText(Self.retiredTestPath))
        let product = try productSources()
        XCTAssertFalse(product.isEmpty)
        XCTAssertEqual(product.values.reduce(0) { $0 + occurrences(of: "S2InlineHint", in: $1) }, 0)

        // 目录：七条 `s2.hint.*` 退役，十一条 `s2.guide.*` 与十条 `s2.tutorial.*` 都在。
        let data = try XCTUnwrap(sourceText(Self.catalogPath)?.data(using: .utf8))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        XCTAssertEqual(strings.keys.filter { $0.hasPrefix("s2.hint.") }.count, 0)
        XCTAssertEqual(strings.keys.filter { $0.hasPrefix("s2.guide.") }.count, 11)
        XCTAssertEqual(strings.keys.filter { $0.hasPrefix("s2.tutorial.") }.count, 10)
    }

    // MARK: - 夹具

    private func makeMachine(scale: CGFloat = 1) -> S2StateMachine {
        let countBox = IC197CountBox(value: 0)
        let entry = S2EntryContext(
            sessionID: "session-197",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "range-197",
                displayName: "测试范围",
                totalAssetCount: 7
            ),
            orderedAssetIDs: ["asset-1", "asset-2", "asset-3", "asset-4", "asset-5", "asset-6", "asset-7"],
            currentAssetID: "asset-2",
            pendingDeletionAssetIDs: [],
            sessionMergedPendingDeletionCountProvider: { countBox.value }
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
        var searchStart = text.startIndex
        for needle in needles {
            let found = try XCTUnwrap(text.range(of: needle, range: searchStart..<text.endIndex), needle, file: file, line: line)
            searchStart = found.upperBound
        }
    }

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

/// `S2View` 五处回调体的镜像：写法与视图里逐句相同（源码断言 C 钉住视图侧），回调先后固定为
/// 待删集合 → 当前张 → 合并计数 → 在显一项（引导协调器对先后不敏感，IC-195 已枚举证明）。
private final class IC197ViewMirror {
    let machine: S2StateMachine
    let guide: S2GuideCoordinator
    private var guideStarted = false
    private var lastPending: Set<String>
    private var lastCurrentAssetID: String
    private var lastMergedCount: Int
    private var lastDisplay: S2GuideDisplay?

    init(machine: S2StateMachine, guide: S2GuideCoordinator) {
        self.machine = machine
        self.guide = guide
        lastPending = machine.pendingDeletionAssetIDs
        lastCurrentAssetID = machine.currentAssetID
        lastMergedCount = machine.sessionMergedPendingDeletionCount
        lastDisplay = guide.display
    }

    func appear() {
        if !guideStarted {
            guideStarted = true
            guide.isInterfaceVisible = machine.interfaceVisibility == .visible
            guide.start(mergedCount: machine.sessionMergedPendingDeletionCount)
        }
        machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark
        syncDisplay()
    }

    func leave() {
        guide.leaveScreen()
        syncDisplay()
    }

    func skip() {
        guide.skip()
        machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark
        syncDisplay()
    }

    func pump() {
        let pending = machine.pendingDeletionAssetIDs
        if pending != lastPending {
            let inserted = pending.subtracting(lastPending)
            let removed = lastPending.subtracting(pending)
            lastPending = pending
            guide.isInterfaceVisible = machine.interfaceVisibility == .visible
            if !inserted.isEmpty {
                guide.assetDidBecomeMarked(
                    stayedOnMarkedAsset: inserted.contains(machine.currentAssetID)
                )
            }
            if !removed.isEmpty {
                guide.assetDidBecomeUnmarked(
                    source: machine.lastPendingDeletionChangeSource ?? .undo
                )
            }
            machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark
        }
        if machine.currentAssetID != lastCurrentAssetID {
            lastCurrentAssetID = machine.currentAssetID
            guide.isInterfaceVisible = machine.interfaceVisibility == .visible
            guide.currentAssetDidChange(
                cause: machine.lastCurrentAssetChangeCause ?? .browse
            )
            machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark
        }
        let count = machine.sessionMergedPendingDeletionCount
        if count != lastMergedCount {
            lastMergedCount = count
            guide.isInterfaceVisible = machine.interfaceVisibility == .visible
            guide.mergedCountDidChange(count)
        }
        syncDisplay()
    }

    private func syncDisplay() {
        if guide.display != lastDisplay {
            lastDisplay = guide.display
            machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark
        }
    }
}

private final class IC197CountBox {
    var value: Int

    init(value: Int) {
        self.value = value
    }
}

/// 内存版六标志存储（照 IC-195 的夹具；该类型为文件私有，不能跨文件调用）。
private final class IC197InMemoryGuideStore: S2GuideStoring {
    var learned: Set<S2GuideStep> = []
    var hasShownCompletion = false
    var hasDimmedIntro = false

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
    }
}
