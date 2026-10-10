import Combine
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-200：路由往返后的滚动位置与展开卡恢复（SPEC-S1 v12 `:220`／`:284`、SPEC-S0 v6 第三节 `OPEN` 与第十二节第 12 条；
/// 取定 `Tasks/PLAN-NAVR-scroll-restore-rulings-20261009.md`）。
/// A 记忆：偏移换算（`minY` → `max(0, -minY)`）；`S1OpenCardState` 的两只记忆——年页的只在展开态变成 nil 时归 0
///   （点月卡换展开不归 0、同值不写），列表页的不受影响。
/// B 流程模型：两只记忆与首页展开卡都不发布（写它们不发 `objectWillChange`），初值为 0／nil。
/// C 源码落位：容器（读写器、锚点在 1 pt 那一层、`.task` 一次、恢复目标按新建时播种）、四处调用点、首页播种与回报、
///   类别页长按锚点优先、流程容器两处归 0 与经待删篮进 S3 清锚点。
/// D 机制探针（只打印、不断言）：窗口宿主里「1 pt 锚 + padding + 新建时 scrollTo」能否把内容滚到记下的偏移、外层
///   `ScrollViewReader` 能否穿过容器内层的 reader 滚动（类别页长按那条路）——给真机之前一个模拟器读数，打印 `IC200_PROBE`。
///
/// **夹具驱动**：真实滚动、`scrollTo` 的时机与恢复后的观感模拟器测不到（陷阱 2），归 H105 真机判定。
final class IC200ScrollRestoreTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let wrapperPath = "PhotoCleanupMVE/Features/Shared/OffsetRestoringScrollView.swift"
    private static let memoryPath = "PhotoCleanupMVE/Core/ScrollOffsetMemory.swift"
    private static let openPath = "PhotoCleanupMVE/Core/S1OpenCardState.swift"
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let yearPath = "PhotoCleanupMVE/Features/S1/S1YearPageView.swift"
    private static let homePath = "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift"
    private static let categoryPath = "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift"
    private static let flowPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift"
    private static let flowModelPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift"

    // MARK: - A 记忆

    func testIC200A_OffsetMathAndYearPageResetRule() {
        XCTAssertEqual(ScrollOffsetMemory.offset(forContentMinY: 0), 0)
        XCTAssertEqual(ScrollOffsetMemory.offset(forContentMinY: -120), 120)
        XCTAssertEqual(ScrollOffsetMemory.offset(forContentMinY: 35), 0, "顶部回弹不记")
        XCTAssertEqual(ScrollOffsetMemory().offset, 0)

        let open = S1OpenCardState()
        XCTAssertFalse(open.listScroll === open.yearPageScroll)
        open.listScroll.offset = 500
        open.setYearPageRangeID("m2026-09")
        open.yearPageScroll.offset = 300
        // 点月卡换展开：不归 0。
        open.setYearPageRangeID("m2026-08")
        XCTAssertEqual(open.yearPageRangeID, "m2026-08")
        XCTAssertEqual(open.yearPageScroll.offset, 300)
        // 同值：不写、不归 0。
        open.setYearPageRangeID("m2026-08")
        XCTAssertEqual(open.yearPageScroll.offset, 300)
        // 离开年页（展开态清成 nil）：归 0；列表页记忆不受影响。
        open.setYearPageRangeID(nil)
        XCTAssertNil(open.yearPageRangeID)
        XCTAssertEqual(open.yearPageScroll.offset, 0)
        XCTAssertEqual(open.listScroll.offset, 500)
        // 已是 nil 再置 nil：同值不写。
        open.yearPageScroll.offset = 40
        open.setYearPageRangeID(nil)
        XCTAssertEqual(open.yearPageScroll.offset, 40)
        // 列表页展开卡怎么变都不碰两只记忆。
        open.setListRangeID("y2026")
        open.setListRangeID("y2025")
        XCTAssertEqual(open.listScroll.offset, 500)
        XCTAssertEqual(open.yearPageScroll.offset, 40)
    }

    // MARK: - B 流程模型

    func testIC200B_FlowModelMemoriesAreUnpublished() {
        let model = S0CleanupFlowModel()
        XCTAssertEqual(model.homeScroll.offset, 0)
        XCTAssertEqual(model.categoryScroll.offset, 0)
        XCTAssertNil(model.preservedOpenCardID)
        XCTAssertFalse(model.homeScroll === model.categoryScroll)
        var willChangeCount = 0
        let subscription = model.objectWillChange.sink { _ in willChangeCount += 1 }
        defer { subscription.cancel() }
        model.homeScroll.offset = 640
        model.categoryScroll.offset = 1280
        model.preservedOpenCardID = "screenshot"
        XCTAssertEqual(willChangeCount, 0, "滚动时每帧都写，不能引发重绘")
        // 正对照：发布的那一项照常发。
        model.presentedCategory = .screenshot
        XCTAssertEqual(willChangeCount, 1)
    }

    // MARK: - C 源码落位

    func testIC200C_SourceWiring() throws {
        let wrapper = try XCTUnwrap(strippedSource(Self.wrapperPath))
        let wrapperRaw = try XCTUnwrap(sourceText(Self.wrapperPath))
        for (needle, expected) in [
            ("struct OffsetRestoringScrollView<Content: View>: View {", 1),
            ("ScrollViewReader { proxy in", 1),
            ("ScrollView {", 1),
            (".coordinateSpace(.named(OffsetRestoringScrollMetrics.coordinateSpaceName))", 1),
            ("geometry.frame(in: .named(OffsetRestoringScrollMetrics.coordinateSpaceName)).minY", 1),
            ("memory.offset = ScrollOffsetMemory.offset(forContentMinY: minY)", 1),
            ("_restoreTarget = State(initialValue: restores ? memory.offset : 0)", 1),
            (".task {", 1),
            ("guard restoreTarget > 0 else {", 1),
            ("@State private var hasRestored = false", 1),
            ("guard !hasRestored else {", 1),
            ("hasRestored = true", 1),
            ("initial: true", 1),
            ("proxy.scrollTo(OffsetRestoringScrollMetrics.anchorID, anchor: .top)", 1),
            (".padding(.top, restoreTarget)", 1),
            (".id(OffsetRestoringScrollMetrics.anchorID)", 1),
            ("@Published", 0),
            ("@MainActor", 0),
            ("L10n.", 0),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: wrapper), expected, "wrapper " + needle)
        }
        // 锚点：`.id` 挂在 1 pt 那一层上、`padding` 在它外面（反过来带 id 的帧从内容顶部起算，`scrollTo` 会滚回 0）。
        let anchor = try XCTUnwrap(slice(wrapper, from: "private var anchor: some View {", to: ".accessibilityHidden(true)"))
        try assertOrder([".frame(height: OffsetRestoringScrollMetrics.anchorHeight)", ".id(OffsetRestoringScrollMetrics.anchorID)", ".padding(.top, restoreTarget)"], in: anchor)
        // 每个实例只恢复一次：闸在 `scrollTo` 之前（`.task` 每次重新出现都会再跑）。
        try assertOrder([".task {", "guard !hasRestored else {", "hasRestored = true", "guard restoreTarget > 0 else {", "proxy.scrollTo(OffsetRestoringScrollMetrics.anchorID, anchor: .top)"], in: wrapper)
        XCTAssertEqual(occurrences(of: "import ", in: wrapperRaw), 1)
        XCTAssertEqual(occurrences(of: "Text(\"", in: wrapperRaw), 0)
        XCTAssertEqual(occurrences(of: "return \"", in: wrapperRaw), 0)
        let memory = try XCTUnwrap(strippedSource(Self.memoryPath))
        let memoryRaw = try XCTUnwrap(sourceText(Self.memoryPath))
        XCTAssertEqual(occurrences(of: "final class ScrollOffsetMemory {", in: memory), 1)
        XCTAssertEqual(occurrences(of: "var offset: CGFloat = 0", in: memory), 1)
        XCTAssertEqual(occurrences(of: "import ", in: memoryRaw), 2)
        XCTAssertEqual(occurrences(of: "import CoreGraphics", in: memoryRaw), 1, "先例 Core/S2StateMachine.swift")
        XCTAssertEqual(occurrences(of: "import Foundation", in: memoryRaw), 1)
        for needle in ["ObservableObject", "@Published", "SwiftUI", "@MainActor", "L10n."] {
            XCTAssertEqual(occurrences(of: needle, in: memory), 0, "memory " + needle)
        }

        let open = try XCTUnwrap(strippedSource(Self.openPath))
        XCTAssertEqual(occurrences(of: "let listScroll = ScrollOffsetMemory()", in: open), 1)
        XCTAssertEqual(occurrences(of: "let yearPageScroll = ScrollOffsetMemory()", in: open), 1)
        XCTAssertEqual(occurrences(of: "yearPageScroll.offset = 0", in: open), 1)
        XCTAssertEqual(occurrences(of: "@Published private(set) var", in: open), 2)
        let setYear = try XCTUnwrap(slice(open, from: "func setYearPageRangeID(", to: "static func resolved("))
        try assertOrder(["guard yearPageRangeID != rangeID else {", "yearPageRangeID = rangeID", "if rangeID == nil {", "yearPageScroll.offset = 0"], in: setYear)

        let s1 = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        XCTAssertEqual(occurrences(of: "OffsetRestoringScrollView(memory: machine.openCards.listScroll) {", in: s1), 1)
        XCTAssertEqual(occurrences(of: "ScrollView {", in: s1), 0)
        XCTAssertEqual(occurrences(of: "ScrollViewReader", in: s1), 0)
        XCTAssertEqual(occurrences(of: "machine.openCards.listScroll.offset = 0", in: s1), 1, "换维度从顶部开始")
        let dimension = try XCTUnwrap(slice(s1, from: "private func selectDimension(", to: "readCurrentRequestIfPossible()"))
        try assertOrder(["guard machine.switchGroupingDimension(to: dimension) else {", "machine.openCards.listScroll.offset = 0"], in: dimension)
        let year = try XCTUnwrap(strippedSource(Self.yearPath))
        XCTAssertEqual(occurrences(of: "OffsetRestoringScrollView(memory: openCards.yearPageScroll) {", in: year), 1)
        XCTAssertEqual(occurrences(of: "ScrollView {", in: year), 0)

        let home = try XCTUnwrap(strippedSource(Self.homePath))
        for (needle, expected) in [
            ("OffsetRestoringScrollView(memory: scrollMemory) {", 1),
            ("ScrollView {", 0),
            ("@State private var openedCardID: String?", 1),
            ("_openedCardID = State(initialValue: initialOpenedCardID)", 1),
            ("initialOpenedCardID: String? = nil", 1),
            ("onOpenedCardChange: @escaping (String?) -> Void = { _ in }", 1),
            ("scrollMemory: ScrollOffsetMemory = ScrollOffsetMemory()", 1),
            ("onOpenedCardChange(identifier)", 1),
            ("openedCardID = identifier", 1),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: home), expected, "home " + needle)
        }
        try assertOrder(["openedCardID = identifier", "onOpenedCardChange(identifier)"], in: home)

        let category = try XCTUnwrap(strippedSource(Self.categoryPath))
        XCTAssertEqual(occurrences(of: "memory: flowModel.categoryScroll,", in: category), 1)
        XCTAssertEqual(occurrences(of: "restores: flowModel.preservedScrollAnchor == nil", in: category), 1)
        XCTAssertEqual(occurrences(of: "ScrollView {", in: category), 0)
        XCTAssertEqual(occurrences(of: "ScrollViewReader { proxy in", in: category), 1, "长按锚点那条路的外层 reader 照旧")
        XCTAssertEqual(occurrences(of: "restoreScrollAnchor(using: proxy)", in: category), 1)
        XCTAssertEqual(occurrences(of: "flowModel.categoryScroll.offset = 0", in: category), 1, "页头未收起的长按回来从顶部开始")
        try assertOrder(["flowModel.preservedScrollAnchor = isHeaderCollapsed ? item.id : nil", "if !isHeaderCollapsed {", "flowModel.categoryScroll.offset = 0"], in: category)
        let content = try XCTUnwrap(slice(category, from: "private func scrollContent(width: CGFloat) -> some View {", to: ".coordinateSpace(.named(Self.scrollSpaceName))"))
        try assertOrder(["OffsetRestoringScrollView(", "scrollOffsetReader", "header(width: width)", "gridContent(width: width)"], in: content)

        let flow = try XCTUnwrap(strippedSource(Self.flowPath))
        for (needle, expected) in [
            ("initialOpenedCardID: flowModel.preservedOpenCardID", 1),
            ("flowModel.preservedOpenCardID = identifier", 1),
            ("scrollMemory: flowModel.homeScroll", 1),
            ("flowModel.categoryScroll.offset = 0", 2),
            ("flowModel.preservedScrollAnchor = nil", 3),
            ("onEnterConfirmation()", 1),
        ] {
            XCTAssertEqual(occurrences(of: needle, in: flow), expected, "flow " + needle)
        }
        for name in ["private func enterCategory(", "private func leaveCategory()"] {
            let body = try XCTUnwrap(slice(flow, from: name, to: "flowModel.presentedCategory ="))
            XCTAssertEqual(occurrences(of: "flowModel.categoryScroll.offset = 0", in: body), 1, name)
        }

        let flowModel = try XCTUnwrap(strippedSource(Self.flowModelPath))
        XCTAssertEqual(occurrences(of: "let homeScroll = ScrollOffsetMemory()", in: flowModel), 1)
        XCTAssertEqual(occurrences(of: "let categoryScroll = ScrollOffsetMemory()", in: flowModel), 1)
        XCTAssertEqual(occurrences(of: "var preservedOpenCardID: String? = nil", in: flowModel), 1)
        XCTAssertEqual(occurrences(of: "@Published", in: flowModel), 1)

        // 产品里：构造记忆的只有两个持有者与首页的形参默认值；用容器的恰是四个页面。
        let sources = try productSources()
        XCTAssertEqual(
            Set(sources.filter { $0.value.contains("ScrollOffsetMemory()") }.keys),
            Set(["S1OpenCardState.swift", "S0CleanupFlowModel.swift", "S0DeckHomeView.swift"])
        )
        XCTAssertEqual(
            Set(sources.filter { $0.value.contains("OffsetRestoringScrollView(") }.keys),
            Set(["S1View.swift", "S1YearPageView.swift", "S0DeckHomeView.swift", "S0DeckCategoryPageView.swift"])
        )
    }

    // MARK: - D 机制探针（只打印、不断言）

    /// IC-201：IC-200 第一版探针（`UIWindow(frame:)` + `isHidden = false`）两行读数都停在静止位置，分不清是宿主不驱动
    /// `scrollTo` 还是机制不工作。宿主改照 `S2CalibrationHarnessTests` 的写法（取已连接的窗口场景、`makeKeyAndVisible()`），
    /// 并加两个正对照（普通 `ScrollViewReader` + `ScrollView`）。读法：正对照动了而被测不动 → 机制问题；正对照也不动 → 宿主问题。
    /// 每行 `before`／`after` 是 `contentOffset.y`／顶部内距／内容高；第 30 格顶部在内容里的 y = 1500。
    @MainActor
    func testIC200D_ProbeRestoreAndNestedReaderInWindow() {
        let controlTask = IC200ProxyBox()
        runProbe("control-task", IC200ControlView(scrollsOnAppear: true, box: controlTask), box: nil, memory: nil)
        let controlOuter = IC200ProxyBox()
        runProbe("control-outer", IC200ControlView(scrollsOnAppear: false, box: controlOuter), box: controlOuter, memory: nil)
        let restoreMemory = ScrollOffsetMemory()
        restoreMemory.offset = 600
        runProbe("restore-600", IC200RestoreProbeView(memory: restoreMemory), box: nil, memory: restoreMemory)
        let nestedMemory = ScrollOffsetMemory()
        let nested = IC200ProxyBox()
        runProbe("nested-reader", IC200ProbeView(memory: nestedMemory, box: nested), box: nested, memory: nestedMemory)
    }

    /// 宿主：已连接的窗口场景（没有才退回无场景窗口，并在行里标出），393 × 852；出现后等 1 秒读一次，
    /// 有 `box` 时再经它存下的 proxy 滚到第 30 格、等 0.5 秒读第二次。
    @MainActor
    private func runProbe<Root: View>(_ name: String, _ root: Root, box: IC200ProxyBox?, memory: ScrollOffsetMemory?) {
        let host = UIHostingController(rootView: root)
        let bounds = CGRect(x: 0, y: 0, width: 393, height: 852)
        let window: UIWindow
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            window = UIWindow(windowScene: windowScene)
            window.frame = bounds
        } else {
            window = UIWindow(frame: bounds)
        }
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        var line = "IC200_PROBE " + name
            + " scene=" + String(window.windowScene != nil)
            + " key=" + String(window.isKeyWindow)
            + " before=" + describe(scrollView(in: host.view))
        if let box = box {
            box.proxy?.scrollTo("probe-cell-30", anchor: .top)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
            line += " after=" + describe(scrollView(in: host.view)) + " proxy=" + String(box.proxy != nil)
        }
        if let memory = memory {
            line += " memory=" + String(Double(memory.offset))
        }
        print(line)
    }

    @MainActor
    private func describe(_ scroll: UIScrollView?) -> String {
        guard let scroll = scroll else {
            return "none"
        }
        return String(Double(scroll.contentOffset.y)) + "/" + String(Double(scroll.adjustedContentInset.top))
            + "/" + String(Double(scroll.contentSize.height))
    }

    @MainActor
    private func scrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView {
            return scroll
        }
        for subview in view.subviews {
            if let scroll = scrollView(in: subview) {
                return scroll
            }
        }
        return nil
    }

    // MARK: - 夹具

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

/// D 的格子：60 格 × 50 pt，每格带 `probe-cell-<序号>` 身份。
private struct IC200ProbeCells: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<60, id: \.self) { index in
                Color.clear
                    .frame(height: 50)
                    .id("probe-cell-" + String(index))
            }
        }
    }
}

/// D 的正对照：普通 `ScrollViewReader` + `ScrollView`（不经本卡容器）。`scrollsOnAppear` 为真时在 `.task` 里滚到第 30 格。
private struct IC200ControlView: View {
    let scrollsOnAppear: Bool
    let box: IC200ProxyBox

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                IC200ProbeCells()
            }
            .task {
                box.proxy = proxy
                if scrollsOnAppear {
                    proxy.scrollTo("probe-cell-30", anchor: .top)
                }
            }
        }
    }
}

/// D 的被测一：本卡容器单独（恢复目标 = 记忆里的偏移）。
private struct IC200RestoreProbeView: View {
    let memory: ScrollOffsetMemory

    var body: some View {
        OffsetRestoringScrollView(memory: memory) {
            IC200ProbeCells()
        }
    }
}

/// D 的被测二：外层一只 `ScrollViewReader`（照类别页长按那条路）包住本卡的容器，经存下的 proxy 滚到第 30 格。
private struct IC200ProbeView: View {
    let memory: ScrollOffsetMemory
    let box: IC200ProxyBox

    var body: some View {
        ScrollViewReader { proxy in
            OffsetRestoringScrollView(memory: memory) {
                IC200ProbeCells()
            }
            .onAppear {
                box.proxy = proxy
            }
        }
    }
}

private final class IC200ProxyBox {
    var proxy: ScrollViewProxy?
}
