import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-185：导航维护小卡（Decision_log 第 218 条第三节第 6 项）。
/// 1 年页／类别页左缘右滑返回：全局导航控制器扩展把左缘手势的代理换成控制器自己，栈里多于一页才开始；
/// 2～4 tab 落点诊断时间线：tab 选择态每次写入回报（旧 → 新）、App 记路由变化与容器出现，接在 S2 退出诊断末尾——只记不改；
/// 5 模拟器上 tab 容器重建探针：只打印、不判（模拟器 iOS 26.2 只能证伪，真机兜底见 H98）。
final class IC185NavigationMaintenanceTests: XCTestCase {
    private static let edgeSwipePath = "PhotoCleanupMVE/Features/Shared/NavigationEdgeSwipeBack.swift"
    private static let diagnosticsPath = "PhotoCleanupMVE/App/S0TabRouteDiagnostics.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
    private static let containerPath = "PhotoCleanupMVE/Features/S0/S0TabContainer.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"

    // MARK: - 断言 1：左缘右滑

    @MainActor
    func testIC185A_EdgeSwipeBackDelegateGatesOnStackDepth() throws {
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.loadViewIfNeeded()
        let recognizer = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        XCTAssertTrue(recognizer.delegate === navigation, "左缘手势的代理换成导航控制器自己")
        XCTAssertFalse(navigation.gestureRecognizerShouldBegin(recognizer), "只有一页时不开始")
        navigation.pushViewController(UIViewController(), animated: false)
        XCTAssertTrue(navigation.gestureRecognizerShouldBegin(recognizer), "两页、无转场时开始")
        navigation.popViewController(animated: false)
        XCTAssertFalse(navigation.gestureRecognizerShouldBegin(recognizer), "回到一页又不开始")

        let source = try XCTUnwrap(strippedSource(Self.edgeSwipePath))
        for (needle, expected) in [
            ("extension UINavigationController: @retroactive UIGestureRecognizerDelegate {", 1),
            ("override open func viewDidLoad() {", 1),
            ("super.viewDidLoad()", 1),
            ("interactivePopGestureRecognizer?.delegate = self", 1),
            ("public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {", 1),
            ("viewControllers.count > 1 && transitionCoordinator == nil", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: source), expected, needle)
        }
        let raw = try XCTUnwrap(sourceText(Self.edgeSwipePath))
        XCTAssertEqual(occurrences(of: "import ", in: raw), 1)

        // 全部产品源码里只有这一处导航控制器扩展、只有这一处碰左缘手势。
        var product = String()
        for relativePath in try swiftFiles(inDirectory: "PhotoCleanupMVE", recursive: true) {
            product += try XCTUnwrap(strippedSource(relativePath), relativePath)
        }
        XCTAssertEqual(occurrences(of: "extension UINavigationController", in: product), 1)
        XCTAssertEqual(occurrences(of: "interactivePopGestureRecognizer", in: product), 1)
    }

    // MARK: - 断言 2：tab 选择态每次写入都回报

    func testIC185B_TabSelectionReportsEveryWrite() {
        let selection = S0TabSelectionModel()
        var writes: [String] = []
        selection.onSelect = { previous, next in
            writes.append(previous.rawValue + "->" + next.rawValue)
        }
        selection.select(.organize)
        selection.select(.organize)
        selection.select(.cleanup)
        XCTAssertEqual(writes, ["cleanup->organize", "organize->organize", "organize->cleanup"])
        XCTAssertEqual(selection.selectionCount, 3)
        XCTAssertEqual(selection.selectedTab, .cleanup)

        // 不接回报时照旧只改选中态与计数（IC-147 断言 2 的口径）。
        let bare = S0TabSelectionModel()
        bare.select(.organize)
        XCTAssertEqual(bare.selectedTab, .organize)
        XCTAssertEqual(bare.selectionCount, 1)
    }

    // MARK: - 断言 3：时间线格式、上限与拼接

    func testIC185B_TimelineFormatCapAndJoin() {
        let diagnostics = S0TabRouteDiagnostics()
        XCTAssertEqual(diagnostics.text, "format=ic185-tab-v1")
        diagnostics.note("route=s2")
        let lines = diagnostics.text.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.first, "format=ic185-tab-v1")
        XCTAssertTrue(lines[1].hasPrefix("t="), lines[1])
        XCTAssertTrue(lines[1].hasSuffix(" route=s2"), lines[1])

        for index in 0..<30 {
            diagnostics.note("e" + String(index))
        }
        XCTAssertEqual(S0TabRouteDiagnostics.maximumEvents, 24)
        XCTAssertEqual(diagnostics.events.count, S0TabRouteDiagnostics.maximumEvents)
        XCTAssertTrue(diagnostics.events.first?.hasSuffix(" e6") ?? false)
        XCTAssertTrue(diagnostics.events.last?.hasSuffix(" e29") ?? false)
        XCTAssertTrue(diagnostics.text.unicodeScalars.allSatisfy { $0.isASCII })

        let missing: String? = nil
        XCTAssertEqual(missing.withTabDiagnostics("x"), "x")
        XCTAssertEqual(Optional("a").withTabDiagnostics("x"), "a\nx")
    }

    // MARK: - 断言 4：接线只记不改，既有钉子不动

    func testIC185B_SourceWiringRecordsOnlyAndKeepsExistingPins() throws {
        let app = try XCTUnwrap(strippedSource(Self.appPath))
        let appRaw = try XCTUnwrap(sourceText(Self.appPath))
        for (needle, expected) in [
            ("@StateObject private var tabDiagnostics = S0TabRouteDiagnostics()", 1),
            ("s0TabSelection.onSelect = {", 1),
            ("tabDiagnostics.note(", 2),
            (".onChange(of: coordinator.route) {", 1),
            ("exitDiagnosticsText: coordinator.s2ExitDiagnosticsText.withTabDiagnostics(tabDiagnostics.text)", 1),
            ("S0TabRouteDiagnostics.uikitSelectedTabIndex()", 2),
            // 既有钉子（IC168 断言 5、IC147 断言 3、IC156 断言 10）计数不变。
            ("exitDiagnosticsText: coordinator.s2ExitDiagnosticsText", 1),
            ("s0TabSelection.selectedTab == .cleanup", 2),
            ("s0TabSelection.select(", 1),
            ("S0TabContainer(", 1),
            ("tabContainer(s1Machine: machine)", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: app), expected, needle)
        }
        for needle in ["diagnostics.note(\"write \"", "\"appear tab=\"", "\" uikit=\"", "\"settled uikit=\"", "\"route=\""] {
            XCTAssertEqual(occurrences(of: needle, in: appRaw), 1, needle)
        }

        let container = try XCTUnwrap(strippedSource(Self.containerPath))
        for (needle, expected) in [
            ("var onSelect: ((S0Tab, S0Tab) -> Void)?", 1),
            ("let previous = selectedTab", 1),
            ("onSelect?(previous, tab)", 1),
            ("selectedTab = tab", 1),
            ("selectionCount += 1", 1),
            ("TabView(", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: container), expected, needle)
        }

        // 协调器仍不认识 tab（IC-147 裁定：切 tab 不经协调器）。
        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        for needle in ["S0Tab", "tabDiagnostics", "S0TabRouteDiagnostics"] {
            XCTAssertEqual(occurrences(of: needle, in: coordinator), 0, needle)
        }

        let diagnostics = try XCTUnwrap(strippedSource(Self.diagnosticsPath))
        let diagnosticsRaw = try XCTUnwrap(sourceText(Self.diagnosticsPath))
        XCTAssertEqual(occurrences(of: "final class S0TabRouteDiagnostics: ObservableObject {", in: diagnostics), 1)
        XCTAssertEqual(occurrences(of: "static let maximumEvents = 24", in: diagnostics), 1)
        XCTAssertEqual(occurrences(of: "static func uikitSelectedTabIndex() -> String {", in: diagnostics), 1)
        XCTAssertEqual(occurrences(of: "@MainActor", in: diagnostics), 2)
        XCTAssertEqual(occurrences(of: "@Published", in: diagnostics), 0, "只记不发布")
        XCTAssertEqual(occurrences(of: "return \"", in: diagnosticsRaw), 0, "扫描器陷阱 18")
        XCTAssertEqual(occurrences(of: "import UIKit", in: diagnosticsRaw), 1)
        XCTAssertEqual(occurrences(of: "import Combine", in: diagnosticsRaw), 1)
        XCTAssertEqual(occurrences(of: "import ", in: diagnosticsRaw), 2)
    }

    // MARK: - 断言 5：模拟器上 tab 容器重建探针（只打印，不判）

    @MainActor
    func testIC185C_TabContainerRebuildProbe() {
        let selection = S0TabSelectionModel()
        selection.select(.organize)
        let first = hostTabContainer(selection: selection)
        let rebuilt = hostTabContainer(selection: selection)
        print("IC185_TAB_PROBE_BEGIN")
        print("first tab=" + first.tab + " n=" + String(first.count) + " uikit=" + first.uikit)
        print("rebuilt tab=" + rebuilt.tab + " n=" + String(rebuilt.count) + " uikit=" + rebuilt.uikit)
        print("hostScenes uikit=" + S0TabRouteDiagnostics.uikitSelectedTabIndex())
        print("IC185_TAB_PROBE_END")
        XCTAssertGreaterThanOrEqual(selection.selectionCount, 1)
        XCTAssertFalse(S0TabRouteDiagnostics.uikitSelectedTabIndex().isEmpty)
    }

    @MainActor
    private func hostTabContainer(selection: S0TabSelectionModel) -> (tab: String, count: Int, uikit: String) {
        let controller = UIHostingController(
            rootView: S0TabContainer(
                selection: selection,
                cleanupContent: { Color.red },
                organizeContent: { Color.blue }
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        let uikit = tabBarController(in: controller).map { String($0.selectedIndex) } ?? "na"
        let result = (tab: selection.selectedTab.rawValue, count: selection.selectionCount, uikit: uikit)
        window.rootViewController = nil
        window.isHidden = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        return result
    }

    @MainActor
    private func tabBarController(in root: UIViewController) -> UITabBarController? {
        if let tabBar = root as? UITabBarController {
            return tabBar
        }
        for child in root.children {
            if let found = tabBarController(in: child) {
                return found
            }
        }
        return nil
    }

    // MARK: - 工具（与既有测试同口径）

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

    private func swiftFiles(inDirectory relativeDirectory: String, recursive: Bool = false) throws -> [String] {
        let directory = repoRoot().appendingPathComponent(relativeDirectory)
        let names: [String]
        if recursive {
            let enumerator = try XCTUnwrap(FileManager.default.enumerator(atPath: directory.path))
            names = enumerator.compactMap { $0 as? String }
        } else {
            names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        }
        return names
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { relativeDirectory + "/" + $0 }
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
